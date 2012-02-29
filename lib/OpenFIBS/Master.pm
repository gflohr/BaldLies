#! /bin/false

# This file is part of OpenFIBS.
# Copyright (C) 2012 Guido Flohr, http://guido-flohr.net/.
#
# OpenFIBS is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# OpenFIBS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with OpenFIBS.  If not, see <http://www.gnu.org/licenses/>.

package OpenFIBS::Master;

use strict;

use IO::Socket::UNIX qw (SOCK_STREAM SOMAXCONN);
use Time::HiRes qw (usleep);
use File::Spec;
use Fcntl qw (:flock);
use Storable qw (nfreeze);
use MIME::Base64 qw (encode_base64);

use OpenFIBS::Util qw (empty format_time);
use OpenFIBS::Database;
use OpenFIBS::User;
use OpenFIBS::Const qw (:comm);

# The index into this array are the COMM constants from OpenFIBS::Const.
# They are mapped into method names, for example name_check is mapped
# to __handleNameCheck.
my @handlers = (
    'welcome',
    'name_check',
    'create_user',
    'authenticate',
);

sub new {
    my ($class, $server) = @_;
    
    my $config = $server->getConfig;
    my $logger = $server->getLogger;
    
    my $self = {
        __server  => $server,
        __config  => $config,
        __logger  => $logger,
        __sockets => {},
        __rsel    => IO::Select->new,
        __users   => {},
    };

    bless $self, $class;

    my $socket_name = $config->{socket_name};
    if (-e $socket_name) {
        unlink $socket_name
            or $logger->fatal ("Error unlink stale socket"
                               . " `$socket_name': $!!\n");
    }
    
    my $listener = IO::Socket::UNIX->new (
        Type => SOCK_STREAM,
        Local => $socket_name,
        Listen => SOMAXCONN,
    ) or $logger->fatal ("Error creating master socket"
                           . "  `$socket_name': $!!\n");
    $listener->blocking (0);
    
    $self->{__listener} = $listener;
    
    $self->{__database} = $server->getDatabase;
    $self->{__database}->prepareStatements;
    
    return $self;
}

sub close {
    my ($self) = @_;
    
    $self->{__logger}->debug ("Closing master socket.");
        
    $self->{__listener}->close;
    undef $self->{__database};
    
    return $self;
}

sub broadcast {
    my ($self, $opcode, $sender, @args) = @_;
    
    while (my ($fd, $rec) = each %{$self->{__sockets}}) {
        next unless $rec->{user};
        my $user = $rec->{user};
        next unless $user->{notify};
        next if $sender eq $user->{name};
        $self->__queueResponse ($fd, $opcode, join ' ', @args);
    }
    
    return $self;
}

sub checkInput {
    my ($self) = @_;

    my $logger = $self->{__logger};
    my $config = $self->{__config};

    my $rsel = $self->{__rsel};
    my $sockets = $self->{__sockets};
    my $users = $self->{__users};
    my $listener = $self->{__listener};

    while (my $socket = $listener->accept) {
        $logger->debug ("Master accepted connection.");
        $rsel->add ($socket);
        $sockets->{$socket} = {
            # Attention! This creates a circular reference.
            socket => $socket,
            out_queue => '',
            in_queue => ''
        };
        $socket->blocking (0);
    }

    my $wsel = IO::Select->new;
    while (my ($key, $rec) = each %$sockets) {
        $wsel->add ($rec->{socket}) if !empty $rec->{out_queue};
    }

    my ($rout, $wout, undef) = IO::Select->select ($rsel, $wsel, undef, 1.0);
    foreach my $fd (@$rout) {
        if (!exists $sockets->{$fd}) {
            $logger->debug ("Client socket $fd already removed.");
            return $self;
        }
            
        my $rec = $sockets->{$fd};
        my $user = $rec->{user};
        my $ident = $user ? "`$user->{name}'" : 'unknown user';
        my $bytes_read = sysread $fd, $rec->{in_queue}, 4096;
        if (!defined $bytes_read) {
            if ($!{EAGAIN} || $!{EWOUDBLOCK}) {
                next;
            }
            $self->__dropConnection ($fd, "Read error for $ident: $!!");
        } elsif (0 == $bytes_read) {
            $self->__dropConnection ($fd, "End-of-file reading from $ident.");
        }
        
        if ($rec->{in_queue} =~ s/(.*?)\n//) {
            my $line = $1;
            my ($opcode, $msg) = split / /, $line, 2;
            if ($opcode !~ /^0|[1-9][0-9]*$/) {
                $self->__dropConnection ($fd, "Received garbage from $ident: $line");
                next;
            }
            
            if ($opcode > $#handlers || !defined $handlers[$opcode]) {
                $self->__dropConnection ($fd, "Unknown opcode $opcode from $ident.");
                next;
            }
            
            if (!$rec->{welcome} && $opcode) {
                $self->__dropConnection ($fd, "Got opcode $opcode from $fd"
                                              . " before welcome message from"
                                              . " child.");
                next;
            }
            my $handler = $handlers[$opcode];
            $handler =~ s/_(.)/uc $1/eg;
            my $method = '__handle' . ucfirst $handler;
            my $result = eval { $self->$method ($fd, $msg) };
            if ($@) {
                $self->__dropConnection ($fd, $@);
                next;
            } elsif (!$result) {
                $self->__dropConnection ($fd, "$method ($msg) did not return.");
                next;
            }
        }
    }
            
    foreach my $fd (@$wout) {
        if (!exists $sockets->{$fd}) {
            $logger->debug ("Client socket $fd already removed.");
            return $self;
        }

        my $rec = $sockets->{$fd};
        my $user = $rec->{user};
        my $ident = $user ? "`$user->{name}'" : 'unknown user';

        if (empty $rec->{out_queue}) {
            $logger->warning ("Client socket $fd has no pending data.");
            next;
        }
                
        my $bytes_written = syswrite $fd, $rec->{out_queue};
        if (!defined $bytes_written) {
            if ($!{EAGAIN} || $!{EWOUDBLOCK}) {
                $logger->debug ("Writing to socket $fd would block.");
                next;
            }
            $self->__dropConnection ($fd, "Error writing to $ident: $!!");
            next;
        } elsif (0 == $bytes_written) {
            $self->__dropConnection ($fd, "End-of-file from $ident.");
            next;
        }
        
        # This is not really inefficient because we will normally
        # send the entire string at once.
        substr $rec->{out_queue}, 0, $bytes_written, '';
    }
    
    return $self;
}

sub getMottoOfTheDay {
    shift->{__motd};
}

sub __dropConnection {
    my ($self, $fd, $msg) = @_;

    my $logger = $self->{__logger};

    my $rec = $self->{__sockets}->{$fd};
    my $user = $rec->{user};
    delete $self->{__users}->{$user->{name}} if $user;
    $self->{__rsel}->remove ($fd);
    
    # This will break the cyclic reference.
    delete $rec->{socket};
    delete $self->{__sockets}->{$fd};
    
    $logger->info ($msg);
    
    if ($user) {
        my $name = $user->{name};
        return $self->broadcast (MSG_LOGOUT, $name, $name);
    }
    
    return $self;
}

sub __queueResponse {
    my ($self, $fd, $opcode, @msg) = @_;
    
    my $sockets = $self->{__sockets};
    
    my $logger = $self->{__logger};
    
    unless (exists $sockets->{$fd}) {
        $logger->info ("Message for vanished connection $fd.");
        return $self;
    }
    
    my $rec = $sockets->{$fd};
    
    my $msg = join ' ', @msg;
    # $logger->debug ("Queue message `$opcode $msg'.");
    $rec->{out_queue} .= "$opcode $msg\n";
    
    return $self;
}

sub __handleWelcome {
    my ($self, $fd, $msg) = @_;
    
    my ($seqno, $secret, $pid) = split / /, $msg, 4;
    
    my $logger = $self->{__logger};
    $logger->debug ("Got welcome from pid $pid.");

    unless ($secret eq $self->{__server}->getSecret) {
        $logger->error ("Child pid $pid sent wrong secret.");
        return;
    }
    
    $self->{__sockets}->{$fd}->{welcome} = 1;
    
    $self->__queueResponse ($fd, MSG_ACK, $seqno);

    return $self;
}

sub __handleNameCheck {
    my ($self, $fd, $msg) = @_;
        
    my ($seqno, $name) = split / /, $msg, 3;
    
    my $logger = $self->{__logger};
    $logger->debug ("Check availability of name `$name'.");

    my $available = $self->{__database}->existsUser ($name) ? 0 : 1;

    $self->__queueResponse ($fd, MSG_ACK, $seqno, $name, $available);

    return $self;
}

sub __handleCreateUser {
    my ($self, $fd, $msg) = @_;
    
    # Password may contain spaces.
    my ($seqno, $name, $ip, $password) = split / /, $msg, 4;
    
    my $logger = $self->{__logger};
    
    my $status;
    if ($self->{__database}->createUser ($name, $password, $ip)) {
        $logger->notice ("Created user `$name', connected from $ip.");
        $status = 1;
    } else {
        $logger->notice ("Creating user `$name', connected from $ip, failed.");
        $status = 0;
    }
    
    $self->__queueResponse ($fd, MSG_ACK, $seqno, $name, $status);
        
    return $self;
}

sub __handleAuthenticate {
    my ($self, $fd, $msg) = @_;
    
    # Password may contain spaces.
    my ($seqno, $name, $ip, $client, $password) = split / /, $msg, 5;
    
    my $logger = $self->{__logger};
    
    my $data = $self->{__database}->getUser ($name, $password, $ip);
    if (!$data) {
        $self->__queueResponse ($fd, MSG_ACK, $seqno, 0);
        return $self;
    }

    if (exists $self->{__users}->{$name}) {
        # Kick out users that log in twice.  FIBS allows parallel logins
        # but this would be hard to implement for us.  Maybe, FIBS does
        # this only to allow parallel registrations.  The warning
        # "You are already logged in" for guest logins kind of suggests
        # that.
        my $other_fd = $self->{__users}->{$name};
        my $other_rec = $self->{__sockets}->{$other_fd};
        my $other_host = $other_rec->{user}->{last_host};

        $self->__queueResponse ($other_fd, MSG_KICK_OUT,
                                "You just logged in a second time from"
                                . " $other_host, terminating this session.");
    }
    
    my $user = OpenFIBS::User->new (@$data);
    $user->{client} = $client;
    $user->{login} = time;
    $user->{ip} = $ip;
    $self->{__sockets}->{$fd}->{user} = $user;
    $self->{__users}->{$name} = $fd; 
    
    my %users;
    foreach my $login (keys %{$self->{__users}}) {
        my $rec = $self->{__sockets}->{$self->{__users}->{$login}};
        my $user = $rec->{user};
        $users{$user->{name}} = $user;
    }
    my $payload = encode_base64 nfreeze \%users;
    $payload =~ s/[^A-Za-z0-9\/+=]//g;
    
    $self->__queueResponse ($fd, MSG_ACK, $seqno, 1, $payload);
    
    $self->broadcast (MSG_LOGIN, $name, @$data);
    
    return $self;
}

1;

=head1 NAME

OpenFIBS::Master - OpenFIBS Master Process/Thread

=head1 SYNOPSIS

  use OpenFIBS::Master;
  
  my $master = OpenFIBS::Session->new ($server);
  $master->run;

=head1 DESCRIPTION

B<OpenFIBS::Master> is the glue thread for all running clients.  It
receives messages from all running sessions, forwards them over the network,
and delivers messages to individual clients.

The class is internal to OpenFIBS.

=head1 SEE ALSO

OpenFIBS::Server(3pm), OpenFIBS::Session(3pm), openfibs(1), perl(1)

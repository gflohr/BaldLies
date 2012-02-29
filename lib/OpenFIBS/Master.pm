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

use OpenFIBS::Util qw (empty format_time);
use OpenFIBS::Database;
use OpenFIBS::User;
use OpenFIBS::Master::CommandDispatcher;

# FIXME! Get rid of this!
use OpenFIBS::Const qw (:comm);

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
    
    $self->__loadDispatcher;
    
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
        $self->queueResponse ($fd, $opcode, join ' ', @args);
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
            $self->dropConnection ($fd, "Read error for $ident: $!!");
        } elsif (0 == $bytes_read) {
            $self->dropConnection ($fd, "End-of-file reading from $ident.");
        }
        
        if ($rec->{in_queue} =~ s/(.*?)\n//) {
            my $line = $1;
            my ($command, $payload) = split / /, $line, 2;
            
            if (!$rec->{welcome} && 'welcome' ne $command) {
                $self->dropConnection ($fd, "Got command $command from $fd"
                                              . " before welcome message from"
                                              . " child.");
                next;
            }
            
            $self->{__dispatcher}->execute ($fd, $command, $payload);
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
            $self->dropConnection ($fd, "Error writing to $ident: $!!");
            next;
        } elsif (0 == $bytes_written) {
            $self->dropConnection ($fd, "End-of-file from $ident.");
            next;
        }
        
        # This is not really inefficient because we will normally
        # send the entire string at once.
        substr $rec->{out_queue}, 0, $bytes_written, '';
    }
    
    return $self;
}

sub getLogger {
    shift->{__logger};
}

sub getSecret {
    shift->{__server}->getSecret;
}

sub getSessionRecord {
    my ($self, $fd) = @_;
    
    return $self->{__sockets}->{$fd};
}

sub getUsers {
    shift->{__users};
}

sub getDatabase {
    shift->{__database};
}

sub __loadDispatcher {
    my ($self) = @_;
    
    my $logger = $self->{__logger};
    
    $logger->debug ("Loading master command plug-ins in \@INC.");
    
    $self->{__dispatcher} = 
        OpenFIBS::Master::CommandDispatcher->new ($self, $logger, @INC);
    
    return $self;
}

sub dropConnection {
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

sub queueResponse {
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
    
    $self->queueResponse ($fd, MSG_ACK, $seqno);

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

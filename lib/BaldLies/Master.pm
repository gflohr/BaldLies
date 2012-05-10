#! /bin/false

# This file is part of BaldLies.
# Copyright (C) 2012 Guido Flohr, http://guido-flohr.net/.
#
# BaldLies is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# BaldLies is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with BaldLies.  If not, see <http://www.gnu.org/licenses/>.

package BaldLies::Master;

use strict;

use IO::Socket::UNIX qw (SOCK_STREAM SOMAXCONN);
use Time::HiRes qw (usleep);
use File::Spec;
use Fcntl qw (:flock);

use BaldLies::Util qw (empty format_time);
use BaldLies::Database;
use BaldLies::User;
use BaldLies::Master::CommandDispatcher;

sub new {
    my ($class, $server) = @_;
    
    my $config = $server->getConfig;
    my $logger = $server->getLogger;
    
    my $self = {
        __server      => $server,
        __config      => $config,
        __logger      => $logger,
        __sockets     => {},
        __rsel        => IO::Select->new,
        __users       => {},
        __inviters    => {},
        __invitees    => {},
        __watched     => {},
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

# FIXME! This must be split into methods broadcast() and notify().
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
        my $bytes_read = sysread $fd, $rec->{in_queue}, 4096, 
                                 length $rec->{in_queue};
        if (!defined $bytes_read) {
            if ($!{EAGAIN} || $!{EWOUDBLOCK}) {
                next;
            }
            $self->dropConnection ($fd, "Read error for $ident: $!!");
        } elsif (0 == $bytes_read) {
            $self->dropConnection ($fd, "End-of-file reading from $ident.");
        }

        while ($rec->{in_queue} =~ s/(.*?)\n//) {
            my $line = $1;
            my ($command, $payload) = split / /, $line, 2;
            
            if (!$rec->{hello} && 'hello' ne $command) {
                $self->dropConnection ($fd, "Got command $command from $fd"
                                            . " before hello message from"
                                            . " child.");
                next;
            }            
            $self->{__dispatcher}->execute ($fd, $command, $payload);
            $rec->{hello} = 1;
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

sub getDatabase {
    shift->{__database};
}

sub setClientUser {
    my ($self, $fd, $user) = @_;
    
    my $rec = $self->{__sockets}->{$fd} or return;
    $rec->{user} = $user;
    $self->{__users}->{$user->{name}} = $fd;
    
    return $self;
}

sub getLoggedIn {
    my ($self) = @_;
    
    return keys %{$self->{__users}};
}

sub getUser {
    my ($self, $name) = @_;
    
    return if empty $name;
    
    my $fd = $self->{__users}->{$name} or return;
    my $rec = $self->{__sockets}->{$fd} or return;
    
    return $rec->{user};
}

sub getUserFromDescriptor {
    my ($self, $fd) = @_;
    
    return $self->{__sockets}->{$fd}->{user};
}

sub tell {
    my ($self, $name, $opcode, @payload) = @_;
    
    my $fd = $self->{__users}->{$name} or return;
    
    $self->queueResponse ($fd, $opcode, @payload);
    
    return $self;
}

sub getInviters {
    shift->{__inviters};
}

sub getInvitees {
    shift->{__invitees};
}

sub __loadDispatcher {
    my ($self) = @_;
    
    my $logger = $self->{__logger};
    
    $logger->debug ("Loading master command plug-ins in \@INC.");
    
    my $reload = $self->{__config}->{auto_recompile};
    
    my $realm = 'BaldLies::Master::Command';
    $self->{__dispatcher} = 
        BaldLies::Master::CommandDispatcher->new (realm => $realm,
                                                  inc => \@INC,
                                                  logger => $logger,
                                                  master => $self,
                                                  reload => $reload);
    
    return $self;
}

sub dropConnection {
    my ($self, $fd, $msg) = @_;

    my $logger = $self->{__logger};

    my $rec = $self->{__sockets}->{$fd};
    my $dropper = $rec->{user};
    if ($dropper) {
        my $name = $dropper->{name};
        my $opponent = $self->getUser ($dropper->{playing});
        if ($opponent && $name eq $opponent->{playing}) {
            delete $opponent->{playing};
            $self->broadcastUserStatus ($opponent->{name});
        }
        if (exists $self->{__watched}->{$name}) {
            my @names = keys %{$self->{__watched}->{$name}};
            foreach my $n (@names) {
                my $watcher = $self->getUser ($n) or next;
                $self->removeWatching ($watcher, $name);
            }
        }
        
        delete $self->{__users}->{$name};
        delete $self->{__inviters}->{$name};
        delete $self->{__invitees}->{$name};
        delete $self->{__watched}->{$name};
        $self->broadcast (logout => $name, $name);    
    }
        
    $self->{__rsel}->remove ($fd);
    
    # This will break the cyclic reference.
    delete $rec->{socket};
    delete $self->{__sockets}->{$fd};
    
    $logger->info ($msg);
    
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

sub queueResponseForUser {
    my ($self, $name, $opcode, @msg) = @_;

    my $users = $self->{__users};    
    my $logger = $self->{__logger};
    
    unless (exists $users->{$name}) {
        $logger->info ("Message for vanished user `$name'.");
        return $self;
    }
    my $fd = $users->{$name};
    return $self->queueResponse ($fd, $opcode, @msg);
}

sub broadcastUserStatus {
    my ($self, $name) = @_;
    
    my $user = $self->getUser ($name) or return;
    my $rawwho = $user->rawwho;

    foreach my $login ($self->getLoggedIn) {
        $self->queueResponseForUser ($login, status => $rawwho);
    }
    
    return $self;
}

sub addWatching {
    my ($self, $user, $who) = @_;
    
    $user->{watching} = $who;
    
    my $name = $user->{name};
    
    $self->{__watched}->{$who}->{$name} = 1;
    
    $self->{__logger}->debug ("$who starts watching $name.");
    
    $self->broadcastUserStatus ($user->{name});

    return $self;
}

sub removeWatching {
    my ($self, $user, $who) = @_;
    
    delete $user->{watching};
    
    my $name = $user->{name};
    
    delete $self->{__watched}->{$who}->{$name};
    
    $self->{__logger}->debug ("$who stops watching $name.");
    
    $self->broadcastUserStatus ($user->{name});

    return $self;
}

sub getWatchers {
    my ($self, $who) = @_;
    
    return unless exists $self->{__watched}->{$who};
    
    return keys %{$self->{__watched}->{$who}};
}

1;

=head1 NAME

BaldLies::Master - BaldLies Master Process/Thread

=head1 SYNOPSIS

  use BaldLies::Master;
  
  my $master = BaldLies::Session->new ($server);
  $master->run;

=head1 DESCRIPTION

B<BaldLies::Master> is the glue thread for all running clients.  It
receives messages from all running sessions, forwards them over the network,
and delivers messages to individual clients.

The class is internal to BaldLies.

=head1 SEE ALSO

BaldLies::Server(3pm), BaldLies::Session(3pm), baldlies(1), perl(1)

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

package OpenFIBS::Server::Master;

use strict;

use IO::Socket::UNIX qw (SOCK_STREAM SOMAXCONN);
use Time::HiRes qw (usleep);
use File::Spec;
use Fcntl qw (:flock);

use OpenFIBS::Util qw (empty);
use OpenFIBS::Const qw (:comm);

my @handlers = (
    'welcome'
);

sub new {
    my ($class, $server) = @_;
    
    my $config = $server->getConfig;
    my $logger = $server->getLogger;
    
    my $self = {
        __server => $server,
        __config => $config,
        __logger => $logger,
        __sockets => {},
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
    
    return $self;
}

sub close {
    my ($self) = @_;
    
    my $sockets = $self->{__sockets};
    
    foreach my $ref (keys %$sockets) {
        $sockets->{$ref}->{socket}->close;
    }
    
    return $self;
}

sub checkInput {
    my ($self) = @_;

    my $logger = $self->{__logger};
    my $config = $self->{__config};

    my $rsel = IO::Select->new;
    my $esel = IO::Select->new;
    my $sockets = $self->{__sockets};
    my $listener = $self->{__listener};
    
    while (my $socket = $listener->accept) {
        $logger->debug ("Master accepted connection.");
        $rsel->add ($socket);
        $esel->add ($socket);
        $sockets->{ref $socket} = {
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
        
    my ($rout, $wout, $eout) = IO::Select->select ($rsel, $wsel, $esel, 
                                                   1.0);
    foreach my $fd (@$eout) {
        $logger->error ("Exception on client socket $fd.");
        my $key = ref $fd;
        $rsel->remove ($fd);
        $esel->remove ($fd);
        delete $sockets->{$key};
    }
    
    foreach my $fd (@$rout) {
        $logger->debug ("Client socket $fd ready for reading.");
        my $key = ref $fd;
        if (!exists $sockets->{$key}) {
            $logger->debug ("Client socket $fd already removed.");
            next;
        }
            
        my $rec = $sockets->{$key};
        my $bytes_read = sysread $fd, $rec->{in_queue}, 4096;
        if (!defined $bytes_read) {
            if ($!{EAGAIN} || $!{EWOUDBLOCK}) {
                $logger->debug ("Reading from socket $fd would block.");
                next;
            }
            $logger->error ("Error reading from socket $fd: $!!");
        } elsif (0 == $bytes_read) {
            $logger->debug ("End-of-file while reading from socket $fd: $!!");
        }
        
        if (!$bytes_read) {
            $rsel->remove ($fd);
            $esel->remove ($fd);
            delete $sockets->{$key};
            next;                                
        }
        if ($rec->{in_queue} =~ s/(.*?)\n//) {
            my $line = $1;
            $logger->debug ("Got message `$line'.\n");
            my ($opcode, $msg) = split / /, $line, 2;
            if ($opcode !~ /^0|[1-9][0-9]*$/) {
                $logger->error ("Received garbage from $fd: $line");
                next;
            }
            if ($opcode > $#handlers) {
                $logger->error ("Unknown opcode $opcode from $fd.");
                next;
            }
            if (!$self->{__welcome_seen} && $opcode) {
                $logger->error ("Got opcode $opcode from $fd before"
                                . " welcome message from child.");
                next;
            }
            my $method = '__handle' . ucfirst $handlers[$opcode];
            eval { $self->$method ($fd, $msg) };
            if ($@) {
                $logger->error ($@);
            }
        }
    }
            
    foreach my $fd (@$wout) {
        $logger->debug ("Client socket $fd ready for writing.");
        my $key = ref $fd;
        if (!exists $sockets->{$key}) {
            $logger->debug ("Client socket $fd already removed.");
            next;
        }
            
        my $rec = $sockets->{$key};
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
            $logger->error ("Error writing to socket $fd: $!!");
        } elsif (0 == $bytes_written) {
            $logger->debug ("End-of-file while writing to socket"
                            . " $fd: $!!");
        }
        
        if (!$bytes_written) {
            $rsel->remove ($fd);
            $esel->remove ($fd);
            delete $sockets->{$key};
            next;                                
        }
                
        # This is not really inefficient because we will normally
        # send the entire string at once.
        substr $rec->{out_queue}, 0, $bytes_written, '';
    }
    
    return $self;
}

sub __queueResponse {
    my ($self, $fd, $opcode, $msg) = @_;
    
    my $key = ref $fd;
    my $sockets = $self->{__sockets};
    
    my $logger = $self->{__logger};
    
    unless (exists $sockets->{$key}) {
        $logger->info ("Message for vanished connection $fd.");
        return $self;
    }
    
    my $rec = $sockets->{$key};
    
    $logger->debug ("Queue message `$opcode $msg'."); 
    $rec->{out_queue} .= "$opcode $msg\n";
    
    return $self;
}

sub __handleWelcome {
    my ($self, $fd, $pid) = @_;
    
    $pid ||= 0;
    my $ppid = getppid;

    my $logger = $self->{__logger};

    if ($pid != $ppid) {
        $logger->warning ("Got welcome from unknown pid $pid");
        return $self;
    }
    
    $self->__queueResponse ($fd, COMM_ACK_WELCOME, $$);

    return $self;
}

1;

=head1 NAME

OpenFIBS::Server::Master - OpenFIBS Master Process/Thread

=head1 SYNOPSIS

  use OpenFIBS::Server::Master;
  
  my $master = OpenFIBS::Server::Session->new ($server);
  $master->run;

=head1 DESCRIPTION

B<OpenFIBS::Server::Master> is the glue thread for all running clients.  It
receives messages from all running sessions, forwards them over the network,
and delivers messages to individual clients.

The class is internal to OpenFIBS.

=head1 SEE ALSO

OpenFIBS::Server(3pm), OpenFIBS::Server::Session(3pm), openfibs(1), perl(1)

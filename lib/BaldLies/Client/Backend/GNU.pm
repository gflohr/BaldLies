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

package BaldLies::Client::Backend::GNU;

use strict;

use IPC::Open3;
use POSIX qw (:sys_wait_h);

use BaldLies::Util qw (empty);
use IO::Socket::INET;

sub new {
    my ($class, $client) = @_;

    bless {
        __client    => $client,
        __config    => $client->getConfig,
        __logger    => $client->getLogger,
        __child_pid => 0,
    }, $class;
}

sub run {
    my ($self) = @_;

    my $config = $self->{__config};
    my $logger = $self->{__logger};
    
    my $port = $config->{backend_port} || 8642;
    
    my $path = $config->{backend_path};
    $path = 'gnubg' if empty $path;
    
    $SIG{CHLD} = sub {
        while (1) {
            my $pid = waitpid -1, WNOHANG or last;
            if ($pid == $self->{__child_pid}) {
                my $client = $self->{__client};
                $logger->error ("Child process `$path'"
                                . " terminated unexpectedly.");
                $client->queueServerOutput ("kibitz Sorry, internal error!");
                $client->queueServerOutput ("leavel");
                $client->terminate;
                last;
            }
        }
    };
    
    my @cmd = ($path, '--tty', '--quiet', '--lang', 'POSIX');
 
    my ($child_out, $child_in, $child_error);
    my $pid = open3 $child_out, $child_in, $child_error, @cmd;
    $self->{__child_pid} = $pid;
    close $child_error if $child_error;

    $self->{__child_in} = $child_in;
    $self->{__child_out} = $child_out;
        
    $logger->info ("Started backgammon engine $path with pid $pid.");
 
    # This will block but that's okay.
    $logger->debug ("Send gnubg command: set variation standard");
    $child_out->print ("set variation standard\n");
    
    $logger->debug ("Send gnubg command: set clockwise off");
    $child_out->print ("set clockwise off\n");
    
    my $settings = $config->{backend_setting};
    if (!defined $settings) {
        $settings = [];
    } elsif (!ref $settings) {
        $settings = [$settings];
    }
    foreach my $cmd (@$settings) {
        $logger->debug ("Send gnubg command: $cmd");
        $child_out->print ("$cmd\n");
    }
    
    $child_out->print ("external localhost:$port\n");
    
    my $try = 0;
    my $socket = $self->{__socket} = IO::Socket::INET->new (
            PeerHost => 'localhost',
            PeerPort => $port,
            Timeout => 3,
            Proto => 'tcp',
        );
    while (!$socket) {
        $socket = $self->{__socket} = IO::Socket::INET->new (
            PeerHost => 'localhost',
            PeerPort => $port,
            Timeout => 3,
            Proto => 'tcp',
        ) and last;
        last if ++$try > 30;
        select undef, undef, undef, 0.1;
    }
    unless ($socket) {
        kill 3, $pid;
        $logger->fatal ("Could not connect to gnubg external socket: $!!");
    }
    
    $logger->info ("Connected to gnubg external interface on localhost:$port.");
    $self->{__socket} = $socket;
         
    my $client = $self->{__client};
    
    # Slurp current output.
    my $output;
    my $bytes_read = sysread $child_in, $output, 100000;
    $logger->debug ("Replies from GNU backgammon so far:\n", $output);
    $logger->debug ("Backend GNU backgammon ready.\n");
    
    return $self;
}

sub controlInput {
    shift->{__socket};
}

sub controlOutput {
    shift->{__socket};
}

sub __processLine {
    my ($self, $line) = @_;
    
    chomp $line;
    
    my $logger = $self->{__logger};
    
    $logger->debug ("GNUBG: $line");
    
    return $self;
}

sub processInput {
    my ($self, $dataref) = @_;
    
    while ($$dataref =~ s/(.*?\n|\AEnter dice: \z)//) {
        my $line = $1;
        next unless length $line;
        $self->__processLine ($line);
    }
    
    return $self;
}

sub move {
    my ($self, $match, $color) = @_;
    
    return $self;
}

1;

=head1 NAME

BaldLies::Client::Backend::GNU - A BaldLies Client for GNU Backgammon

=head1 SYNOPSIS

  die "Internal class, do not use"
  
=head1 SEE ALSO

baldlies(1), perl(1)

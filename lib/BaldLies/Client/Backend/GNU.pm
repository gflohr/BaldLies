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

use IPC::Open2;
use POSIX qw (:sys_wait_h);

use BaldLies::Util qw (empty);

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
    my $pid = open2 $child_out, $child_in, @cmd;
    $self->{__child_pid} = $pid;
    close $child_error if $child_error;
    
    $self->{__child_out} = $child_out;
    $self->{__child_in} = $child_in;
        
    $logger->info ("Started backgammon engine $path with pid $pid.");
    
    my $client = $self->{__client};
    
    $logger->debug ("Send gnubg command: set confirm new off");
    $client->queueClientOutput ("set confirm new off");
    
    return $self;
}

sub stdin {
    shift->{__child_in};
}

sub stdout {
    shift->{__child_out};
}

sub processLine {
    my ($self, $line) = @_;
    
    my $logger = $self->{__logger};
    
    $logger->debug ("GNUBG: $line");
    
    return $self;
}

1;

=head1 NAME

BaldLies::Client::Backend::GNU - A BaldLies Client for GNU Backgammon

=head1 SYNOPSIS

  die "Internal class, do not use"
  
=head1 SEE ALSO

baldlies(1), perl(1)

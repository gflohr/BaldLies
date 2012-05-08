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

our $from_re = qr/[1-9]|1[0-9]|2[0-5]/;
our $to_re = qr/[0-9]|1[0-9]|2[0-4]/;
our $movement_re = qr{$from_re/$to_re};
our $move_re = qr/^$movement_re\*?(?: +$movement_re\*?){0,3}?$/;

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
    
    my @cmd = ($path, '--tty', '--quiet', '--no-rc', '--lang', 'POSIX');
 
    my ($child_out, $child_in, $child_error);
    my $pid = open3 $child_out, $child_in, $child_error, @cmd;
    $self->{__child_pid} = $pid;
    close $child_error if $child_error;

    $self->{__child_in} = $child_in;
    $self->{__child_out} = $child_out;
        
    $logger->info ("Started backgammon engine $path with pid $pid.");
 
    my $settings = $config->{backend_setting};
    if (!defined $settings) {
        $settings = [];
    } elsif (!ref $settings) {
        $settings = [$settings];
    }

    # Printing will block but that's okay.
    foreach my $cmd (@$settings) {
        $logger->debug ("Send gnubg command: $cmd");
        $child_out->print ("$cmd\n");
    }
    
    $logger->debug ("Send gnubg command: set variation standard");
    $child_out->print ("set variation standard\n");
    $logger->debug ("Send gnubg command: external localhost:$port");
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
    my $bytes_read = sysread $child_in, $output, 1000000;
    $logger->debug ("Replies from GNU backgammon so far:\n", $output);
    $logger->debug ("Backend GNU backgammon ready.\n");
    
    return $self;
}

sub readHandle {
    shift->{__socket};
}

sub writeHandle {
    shift->{__socket};
}

sub __processLine {
    my ($self, $line) = @_;

    my $logger = $self->{__logger};
    $logger->debug ("GNUBG: $line");
    
    $line =~ s/^[ \t\r\n]+//;
    $line =~ s/[ \t\r\n]+$//;
    
    if ($line eq 'roll') {
        $self->{__client}->queueServerOutput ('roll');
    } elsif ($line eq 'double') {
        $self->{__client}->queueServerOutput ('double');
    } elsif ($line eq 'drop') {
        $self->{__client}->queueServerOutput ('reject');
    } elsif ($line eq 'take') {
        $self->{__client}->queueServerOutput ('accept');
    } elsif ($line eq 'beaver') {
        $self->{__client}->queueServerOutput ('redouble');
    } elsif ($line =~ $move_re) {
        $self->__processMove ($line);
    } else {
        $logger->error ("Got invalid reply from gnubg: >>>$line<<<");
    }
    
    return $self;
}

sub __processMove {
    my ($self, $move) = @_;
    
    $move =~ s/\*//g;
    my @movements = split / +/, $move;
    
    my $reply = 'move';
    
    # GNU backgammon always moves from 24 to 1.  We have to translate the move
    # to FIBS' notion of a move if we play from 1 to 24.  The explicit flag
    # for that in the board state is item #42.  Alternatively, we could
    # use the color or our representation (O or X).
    my @board = split /:/, $self->{__last_board};    
    if ($board[42] == 1) {
        foreach my $movement (@movements) {
            my ($from, $to) = split /\//, $movement;
            $from = 25 - $from;
            $from ||= 'bar';
            $to = 25 - $to;
            $to = 'home' if 25 == $to;
            $reply .= " $from-$to";
        }
    } else {
        foreach my $movement (@movements) {
            my ($from, $to) = split /\//, $movement;
            $from = 'bar' if 25 == $from;
            $to ||= 'home';
            $reply .= " $from-$to";
        }
    }
    $reply .= "\n";
    
    $self->{__client}->queueServerOutput ($reply);
    
    return $self;
}

sub processInput {
    my ($self, $dataref) = @_;
    
    while ($$dataref =~ s/(.*?)\n//) {
        my $line = $1;
        next unless length $line;
        $self->__processLine ($line);
    }
    
    return $self;
}

sub handleBoard {
    my ($self, $board) = @_;

    # When we receive a hint from GNU backgammon we do not know for which
    # board state it was sent.  It can happen that we send a board state,
    # and while waiting for a reply from GNU backgammon, our opponent
    # drops, and we accept a new invitation.  In that case we might
    # try to execute an action from the last match.
    #
    # Trying to fix that is nearly impossible.  It is not completely
    # clear, when FIBS will send us a board state.  And gnubg, for example
    # does not bother sending a reply at all, if there is no move in the
    # current board state.
    $self->{__client}->queueClientOutput ($board . "\n");
    
    # Remember the last board state.  It is sometimes needed.
    $self->{__last_board} = $board;
    
    return $self;
}

sub handleYouRoll {
    my ($self, @dice) = @_;
    
    # Ignore.  Instead we wait for "Please move $n pieces'.  This will
    # make us skip "You cannot move".
    return $self;
}

sub handlePleaseMove {
    my ($self, @dice) = @_;

    # We need a new board from the server.    
    $self->{__client}->queueServerOutput ('board');

    return $self;
}
sub handleAction {
    my ($self, $action, @args) = @_;
    
    my $logger = $self->{__logger};
    $logger->debug ("Handle match action `$action @args'.");
    
    if ('double' eq $action) {
        # Get a new board from the server.
        $self->{__client}->queueServerOutput ('board');
    } elsif ('resign' eq $action) {
        # FIXME! How can we ask GNU backgammon whether it is correct to
        # resign?
        $self->{__client}->queueServerOutput ('reject');
    } else {
        $logger->error ("Invalid action `$action @args'.");
    }
    
    return $self;
}

1;

=head1 NAME

BaldLies::Client::Backend::GNU - A BaldLies Client for GNU Backgammon

=head1 SYNOPSIS

  die "Internal class, do not use"
  
=head1 SEE ALSO

baldlies(1), perl(1)

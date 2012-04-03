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

package BaldLies::Session::Message::play;

use strict;

use base qw (BaldLies::Session::Message);
use BaldLies::Const qw (:colors);
use BaldLies::User;
use BaldLies::Util qw (equals);

sub execute {
    my ($self, $session, $payload) = @_;
    
    my $logger = $session->getLogger;

    $logger->debug ("Match play action: $payload");
    my ($action, @data) = split / /, $payload;
    
    $self->{__session} = $session;
    my $user = $session->getUser;
    
    my $method = '__handle' . ucfirst $action;
    
    my $match = $self->{__match} = $user->{match};
    die "No match!\n" unless $match;
    
    if (equals $user->{name}, $match->player1) {
        $self->{__color} = WHITE;
        $self->{__me} = $user->{name};
        $self->{__other} = $user->{playing};
    } elsif (equals $user->{name}, $match->player2) {
        $self->{__color} = BLACK;
        $self->{__me} = $user->{name};
        $self->{__other} = $match->player1;
    } else {
        $self->{__color} = 0;
        $self->{__me} = $user->{watching};
        if (equals $user->{watching}, $match->player1) {
            $self->{__other} = $match->{player2};
        } elsif (equals $user->{watching}, $match->player2) {
            $self->{__other} = $match->{player1};
        } else {
            die "Orphaned play message";
        }
    }
    
    return $self->$method (@data);
}

sub __handleStart {
    my ($self) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};
    
    my $opponent = $self->{__other};
    $session->reply ("Starting a new game with $opponent.\n", 1);
    
    $self->__checkMatch if $self->{__color} == WHITE;
    
    return $self;
}

sub __handleOpening {
    my ($self, $die1, $die2) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};

    if ($self->{__color}) {
        $logger->debug ("Match action ($self->{name}):"
                        . " roll 0 $die1 $die2");
        $match->do (roll => 0, $die1, $die2);
    }
    
    my $me = $self->{__color} > 1 ? 'You' : $self->{__me};
    my $opponent = $self->{__other};

    if ($self->{__color} == BLACK) {
        ($die1, $die2) = ($die2, $die1);
    }
    $session->reply ("$me rolled $die1, $opponent rolled $die2.\n", 1);
    
    if ($die1 == $die2) {
        if ($match->getAutodouble) {
            my $cube = $match->getCube;
            $session->reply ("The number on the doubling cube is now $cube", 1);
        }
        if ($self->{__color} == WHITE) {
            $self->__checkMatch;
        }
        return $self;
    }
    
    if ($die1 > $die2) {
        if ($self->{__color}) {
            $session->reply ("It's your turn to move.\n", 1);
        } else {
            $session->reply ("$me makes the first move.\n", 1);
        }
    } elsif ($die1 < $die2) {
        $session->reply ("$opponent makes the first move.\n", 1);
    }
    
    $session->reply ($user->{match}->board ($user->{boardstyle}, 
                                            $self->{__color} == BLACK));
   
    return $self;
}

sub __handleMove {
    my ($self, $color, @points) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};

    my $msg = '';
    
    if ($self->{__color} == $color) {
        # This is our own move which is already applied to the match.
    } else {
        $logger->debug ("Match action ($self->{__me}:"
                        . " move $color @points");
        $match->do (move => $color, @points);
        my $who = $color == BLACK ? $match->player2 : $match->player1;
        $msg .= "$who moves";
        my ($home, $bar);
        if ($color == BLACK) {
            ($home, $bar) = (25, 0);
        } else {
            ($home, $bar) = (0, 25);
        }
        while (@points) {
            my $from = shift @points;
            my $to = shift @points;
            $from = 'bar' if $from == $bar;
            $to = 'home' if $to == $home;
            $msg .= " $from-$to";
        }
    }
    
    $msg .= $user->{match}->board ($user->{boardstyle}, 
                                   $self->{__color} == BLACK);
    
    if ($color == -$self->{__color}) {
        $msg .= "It's your turn. Please roll or double.\n";
    }
    
    $session->reply ($msg);
    
    return $self;
}

sub __checkMatch {
    my ($self) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};
    
    my $state = $match->getState;
    if ('opening' eq $state) {
        my $die1 = 1 + int rand 6;
        my $die2 = 1 + int rand 6;
        $session->sendMaster (play => "opening $die1 $die2");
        return $self;
    }
    
    die "cannot handle state `$state'";
}

1;

=head1 NAME

BaldLies::Session::Message::play - BaldLies Message `play'

=head1 SYNOPSIS

  use BaldLies::Session::Message::play->new;
  
=head1 DESCRIPTION

This plug-in handles the master message `play'.

=head1 SEE ALSO

BaldLies::Session::Message(3pm), baldlies(1), perl(1)

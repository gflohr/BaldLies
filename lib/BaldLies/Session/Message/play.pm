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

use BaldLies::User;

# Everybody has one of three possible roles.
# 3 is the currently active player, the one responsible for forwarding the
# state machine.  2 is the opponent, and 1 is a watcher.

sub execute {
    my ($self, $session, $payload) = @_;
    
    my $logger = $session->getLogger;

    my ($player1, $player2, $action, @data) = split / /, $payload;
    
    $self->{__session} = $session;
    my $user = $session->getUser;
    $self->{__user} = $user;
    
    my $users = $session->getUsers;
    
    $self->{__player1} = $users->{$player1};
    if (!$self->{__player1}) {
        $logger->error ("Player `$player1' has vanished.");
        return $self;
    }
    $self->{__player2} = $users->{$player2};
    if (!$self->{__player2}) {
        $logger->error ("Player `$player2' has vanished.");
        return $self;
    }
    
    my $name = $user->{name};
    my $method = '__handle' . ucfirst $action;

    if ($player1 eq $name) {
        $self->{__role} = 3;
        $self->{__me} = $self->{__player1};
        $self->{__other} = $self->{__player2};
    } elsif ($player2 eq $name) {
        $self->{__role} = 2;
        $self->{__me} = $self->{__player2};
        $self->{__other} = $self->{__player1};
    } else {
        $self->{__role} = 1;
        $self->{__me} = $self->{__player1};
        $self->{__other} = $self->{__player2};
    }
    
    return $self->$method (@data);
}

sub __handleStart {
    my ($self) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};
    
    my $opponent = $self->{__other}->{name};
    $session->reply ("Starting a new game with $opponent.\n", 1);
    
    $self->__checkMatch if $self->{__role} > 2;
    
    return $self;
}

sub __handleOpening {
    my ($self, $die1, $die2) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};

    if ($self->{__role} > 1) {
        $match->do (roll => 0, $die1, $die2);
    }
    
    my $me = $self->{__role} > 1 ? 'You' : $self->{__me}->{name};
    my $opponent = $self->{__other}->{name};

    if ($self->{__role} != 2) {
        ($die1, $die2) = ($die2, $die1);
    }
    $session->reply ("$me rolled $die1, $opponent rolled $die2.\n", 1);
    
    if ($die1 == $die2) {
        if ($match->getAutodouble) {
            my $cube = $match->getCube;
            $session->reply ("The number on the doubling cube is now $cube", 1);
        }
        if ($self->{__role} > 1) {
            $self->__checkMatch;
        }
    } elsif ($die1 > $die2) {
        if ($self->{__role} > 1) {
            $session->reply ("It's your turn to move.\n");
        } else {
            $session->reply ("$me makes the first move.\n");
        }
    } elsif ($die1 < $die2) {
        $session->reply ("$opponent makes the first move.\n");
    }
   
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
        if ($self->{__role} > 2) {
            my $die1 = 1 + int rand 6;
            my $die2 = 1 + int rand 6;
            $session->sendMaster (play => "opening $die1 $die2");
            return $self;
        }
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

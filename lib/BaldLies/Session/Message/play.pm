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
    my $method;
    if ($player1 eq $name) {
        $method = '__handleMy' . ucfirst $action;
        $self->{__role} = 'inviter';
    } elsif ($player2 eq $name) {
        $method = '__handleHer' . ucfirst $action;
        $self->{__role} = 'invitee';
    } else {
        $method = '__handleTheir' . ucfirst $action;
        $self->{__role} = 'watcher';
    }
    
    return $self->$method (@data);
}

sub __handleMyStart {
    my ($self) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};
    
    my $opponent = $match->player2;
    $session->reply ("Starting a new game with $opponent.\n");
    
    $self->__checkMatch;
    
    return $self;
}

sub __handleMyOpening {
    my ($self, $die1, $die2) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};

    $match->do (roll => 0, $die1, $die2);
    
    my $opponent = $self->{__player2}->{name};
    $session->reply ("You rolled $die1, $opponent rolled $die2\n", 1);

    if ($die1 > $die2) {
        $session->reply ("It's your turn to move.\n");
    } elsif ($die1 < $die2) {
        $session->reply ("$opponent makes the first move.\n");
    } else {
        if ($match->getAutodouble) {
            my $cube = $match->getCube;
            $session->reply ("The number on the doubling cube is now $cube", 1);
        }
        $self->__checkMatch;
    }
   
    return $self;
}

sub __handleHerStart {
    my ($self) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};
    
    my $opponent = $match->player1;
    $session->reply ("Starting a new game with $opponent.\n");

    # The inviter is responsible for the opening roll.
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
        if ('inviter' eq $self->{__role}) {
            while (1) {
                my $die1 = 1 + int rand 6;
                my $die2 = 1 + int rand 6;
                next if $die1 == $die2 && !$match->getAutodouble;
                $session->sendMaster (play => "opening $die1 $die2");
                return;
            }
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

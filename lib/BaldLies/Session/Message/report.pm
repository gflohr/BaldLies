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

package BaldLies::Session::Message::report;

use strict;

use base qw (BaldLies::Session::Message);

use MIME::Base64 qw (decode_base64);
use Storable qw (thaw);

use BaldLies::User;
use BaldLies::Backgammon::Match;
use BaldLies::Const qw (:colors);

sub execute {
    my ($self, $session, $payload) = @_;

    my ($action, $data) = split / /, $payload, 2;
    my $method = '__handle' . ucfirst $action;
    
    return $self->$method ($session, $data);
}

sub __handleJoined {
    my ($self, $session, $payload) = @_;

    my ($opponent, $data) = split / /, $payload;

    my $user = $session->getUser;
    $user->{playing} = $opponent;
    delete $user->{watching};
    
    my $other = $session->getUsers->{$opponent};
    $other->{playing} = $user->{name};
    delete $other->{watching};
    
    if ($session->getClip) {
        my $rawwho = $user->rawwho;
        $session->reply ("5 $rawwho\n6\n");
        $rawwho = $other->rawwho;
        $session->reply ("5 $rawwho\n6\n");
    }

    my $options = thaw decode_base64 $data;
    my $old_moves = delete $options->{old_moves};
    
    my $length = $options->{length};
    my $resumed = @$old_moves || $options->{score1} || $options->{score2};
    
    if ($resumed) {
        $session->reply ("$opponent has joined you."
                         . " Your running match was loaded.\n", 1);
    } elsif ($length > 0) {
        $session->reply ("\n** $opponent has joined you for a $length"
                         . " point match.\n", 1);
    } else {
        $session->reply ("\nPlayer $opponent has joined you for an unlimited"
                         . " match.\n", 1);
    }

    my $match = $user->{match} = BaldLies::Backgammon::Match->new (%$options);
    $self->__replayMoves ($user->{match}, $old_moves);
    $user->startGame;
    
    my $color = 0;
    if ($user->{name} eq $match->player1) {
        $color = WHITE;
    } elsif ($opponent eq $match->player1) {
        $color = BLACK;
    } else {
        $color = BLACK;
    }
    
    my $msg_dispatcher = $session->getMessageDispatcher;
    if ($resumed) {
        $msg_dispatcher->execute ($session, play => "resume $color");
    } else {
        $msg_dispatcher->execute ($session, play => "start $color");
    }
    
    return $self;
}

sub __handleInvited {
    my ($self, $session, $payload) = @_;

    my ($opponent, $data) = split / /, $payload;

    my $options = thaw decode_base64 $data;
    my $old_moves = delete $options->{old_moves};
    
    my $length = $options->{length};
    
    my $resumed = @$old_moves || $options->{score1} || $options->{score2};
    
    if ($resumed) {
        $session->reply ("You are now playing with $opponent."
                         . " Your running match was loaded.\n", 1);
    } elsif ($length > 0) {
        $session->reply ("** You are now playing a $length"
                         . " point match with $opponent\n", 1);
    } else {
        $session->reply ("** You are now playing an unlimited match with"
                         . " $opponent\n", 1);
    }
    
    my $user = $session->getUser;
    $user->{playing} = $opponent;
    delete $user->{watching};
    
    my $other = $session->getUsers->{$opponent};
    $other->{playing} = $user->{name};
    delete $other->{watching};
    
    if ($session->getClip) {
        my $rawwho = $user->rawwho;
        $session->reply ("5 $rawwho\n6\n");
        $rawwho = $other->rawwho;
        $session->reply ("5 $rawwho\n6\n");
    }
    
    my $match = $user->{match} = BaldLies::Backgammon::Match->new (%$options);
    $self->__replayMoves ($user->{match}, $old_moves);    
    $user->startGame;

    my $color = 0;
    if ($user->{name} eq $match->player1) {
        $color = WHITE;
    } elsif ($opponent eq $match->player1) {
        $color = BLACK;
    } else {
        $color = BLACK;
    }
    
    my $msg_dispatcher = $session->getMessageDispatcher;
    if ($resumed) {
        $msg_dispatcher->execute ($session, play => "resume $color");
    } else {
        $msg_dispatcher->execute ($session, play => "start $color");
    }
    
    return $self;
}

sub __handleStart {
    my ($self, $session, $payload) = @_;

    my ($player1, $player2, $length) = split / /, $payload;
    
    my $user = $session->getUser;
    if ($user->{report}) {
        if ($length > 0) {
            $session->reply ("\n$player1 and $player2 start a $length point"
                             . " match.\n");
        } else {
            $session->reply ("\n$player1 and $player2 start an unlimited"
                             . " match.\n");
        }
    }
    
    my $player = $session->getUsers->{$player1};
    $player->{playing} = $player2;
    delete $player->{watching};
    
    if ($session->getClip) {
        my $rawwho = $player->rawwho;
        $session->reply ("5 $rawwho\n6\n");
    }
    
    $player = $session->getUsers->{$player2};
    $player->{playing} = $player1;
    delete $player->{watching};
    
    if ($session->getClip) {
        my $rawwho = $player->rawwho;
        $session->reply ("5 $rawwho\n6\n");
    }
    
    return $self;
}

sub __replayMoves {
    my ($self, $match, $moves) = @_;

    foreach my $move (@$moves) {
        $match->do (@$move);
    }
        
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Message::report - BaldLies Message `report'

=head1 SYNOPSIS

  use BaldLies::Session::Message::report->new;
  
=head1 DESCRIPTION

This plug-in handles the master message `report'.

=head1 SEE ALSO

BaldLies::Session::Message(3pm), baldlies(1), perl(1)

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

use BaldLies::User;
use BaldLies::Backgammon::Match;

sub execute {
    my ($self, $session, $payload) = @_;

    my ($action, $data) = split / /, $payload, 2;
    my $method = '__handle' . ucfirst $action;
    
    return $self->$method ($session, $data);
}

sub __handleJoined {
    my ($self, $session, $payload) = @_;

    my ($opponent, $length) = split / /, $payload;
    
    if ($length > 0) {
        $session->reply ("\n** $opponent has joined you for a $length"
                         . " point match.\n", 1);
    } else {
        $session->reply ("\n** $opponent has joined you for an unlimited"
                         . " match.\n", 1);
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

    my %args = (
        player1 => $user->{name},
        player2 => $other->{name},
        crawford => 0,
        autodouble => 0,
    );

    $args{crawford} = 1 
        if $length > 0 && $user->{crawford} && $other->{crawford};
    $args{autodouble} = 1 if $user->{autodouble} && $other->{autodouble};
    
    $user->{match} = BaldLies::Backgammon::Match->new (%args);
    
    my $action = "$user->{name} $other->{name} start";

    my $msg_dispatcher = $session->getMessageDispatcher;
    $msg_dispatcher->execute ($session, play => $action);
    
    return $self;
}

sub __handleInvited {
    my ($self, $session, $payload) = @_;

    my ($opponent, $length) = split / /, $payload;
    
    if ($length > 0) {
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
    
    my %args = (
        player1 => $other->{name},
        player2 => $user->{name},
        crawford => 0,
        autodouble => 0,
    );

    $args{crawford} = 1 
        if $length > 0 && $user->{crawford} && $other->{crawford};
    $args{autodouble} = 1 if $user->{autodouble} && $other->{autodouble};
    
    $user->{match} = BaldLies::Backgammon::Match->new (%args);
    
    my $action = "$other->{name} $user->{name} start";

    my $msg_dispatcher = $session->getMessageDispatcher;
    $msg_dispatcher->execute ($session, play => $action);
    
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

1;

=head1 NAME

BaldLies::Session::Message::report - BaldLies Message `report'

=head1 SYNOPSIS

  use BaldLies::Session::Message::report->new;
  
=head1 DESCRIPTION

This plug-in handles the master message `report'.

=head1 SEE ALSO

BaldLies::Session::Message(3pm), baldlies(1), perl(1)

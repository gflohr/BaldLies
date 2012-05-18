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

package BaldLies::Session::Message::watch;

use strict;

use base qw (BaldLies::Session::Message);
use BaldLies::Const qw (:colors);
use BaldLies::User;
use BaldLies::Util qw (equals empty);

use BaldLies::Backgammon::Match;

sub execute {
    my ($self, $session, $payload) = @_;
    
    my $logger = $session->getLogger;

    my ($dump, $action, $color, @data) = split / /, $payload;
    
    $self->{__session} = $session;
    my $user = $session->getUser;
    
    if (defined $color && $color == 0 && 'roll' eq $action) {
        $action = 'opening';
    }
    
    my $method = '__handle' . ucfirst $action;

    my $match = BaldLies::Backgammon::Match->newFromDump ($dump);

    $self->{__reverse} = $user->{watching} eq $match->player2;
    
    return $self->$method ($match, $color, @data);
}

sub __handleStart {
    my ($self, $match, $color) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    
    return $self if empty $user->{watching};
    
    my ($player1, $player2) = ($match->player1, $match->player2);
    my $opponent;

    if ($player1 eq $user->{watching}) {
        $opponent = $player2;
    } elsif ($player2 eq $user->{watching}) {
        $opponent = $player1;
    } else {
        return $self;
    }
    
    $session->reply ("\nStarting a new game with $opponent.\n", 1);
    
    return $self;
}

sub __handleOpening {
    my ($self, $match, $color, $die1, $die2) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    
    my $player1 = $match->player1;
    my $player2 = $match->player2;

    my $msg = "$player1 rolls $die1, $player2 rolls $die2.\n";
    if ($die1 > $die2) {
        $msg .= "$player1 makes the first move.\n";
    } elsif ($die1 < $die2) {
        $msg .= "$player2 makes the first move.\n";
    } elsif ($die1 == $die2 && $match->getAutodouble) {
        my $cube = 2 * $match->getCube;
        $msg .= "The number on the doubling cube is now $cube\n";
    }
    
    $msg .= $match->board ($user->{boardstyle}, 1, $self->{__reverse})
        if $die1 != $die2;
    $session->reply ($msg);
    
    return $self;
}

sub __handleMove {
    my ($self, $match, $color, @points) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    
    my $who = $color == BLACK ? $match->player2 : $match->player1;
    my $formatted = $self->__formatMove ($color, @points);

    my $msg = "\n$who moves$formatted .\n";
    $msg .= $match->board ($user->{boardstyle}, $self->{__reverse});
    $session->reply ($msg);
    
    if ($match->gameOver) {
        my $value = $match->getLastWin;
        my $points = $value == 1 ? "1 point" : "$value points";
        
        if ($color > 0) {
            my $winner = $match->player1;
            $msg = "$winner wins the game and gets $points.\n";
        } else {
            my $winner = $match->player2;
            $msg = "$winner wins the game and gets $points.\n";
        }
        return $self->__endOfGame ($match, $msg);
    }
    
    return $self;
}

sub __handleRoll {
    my ($self, $match, $color, $die1, $die2) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;

    my $who;
    
    if ($color < 0) {
        $who = $match->player2;
    } else {
        $who = $match->player1;
    }
    
    $session->reply ("\n$who rolls $die1 and $die2\n");
    
    return $self;
}

sub __handleDouble {
    my ($self, $match, $color) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;

    my $who = $color == BLACK ? $match->player2 : $match->player1;

    $session->reply ("\n$who doubles.\n");
        
    return $self;
}

sub __handleResign {
    my ($self, $match, $color, $value) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;

    my ($resigner, $other);
    if ($color == BLACK) {
        $resigner = $match->player2;
        $other = $match->player1;
    } else {
        $resigner = $match->player1;
        $other = $match->player2;
    }
    
    my $points = $value == 1 ? "1 point" : "$value points";

    $session->reply ("\n$resigner wants to resign. $other will win $points.\n");
    
    return $self;
}

sub __handleAccept {
    my ($self, $match, $color) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;

    my $player;
    if ($color == BLACK) {
        $player = $match->player2;
    } else {
        $player = $match->player1;
    }
    
    my $value = $match->getLastWin;
    my $points = $value == 1 ? "1 point" : "$value points";
    my $msg = "\n$player accepts and wins $points.\n";
        
    $self->__endOfGame ($match, $msg);
    
    return $self;
}

sub __handleTake {
    my ($self, $match, $color) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;

    my $who = $color == BLACK ? $match->player2 : $match->player1;

    $session->reply ("\n$who accepts the double.", 1);
        
    return $self;
}

sub __handleReject {
    my ($self, $match, $color) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;

    my $player;
    if ($color == BLACK) {
        $player = $match->player2;
    } else {
        $player = $match->player1;
    }
    
    $session->reply ("\n$player rejects. The game continues.\n");
    
    return $self;
}

sub __handleDrop {
    my ($self, $match, $color) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;

    my $dropper = $color == BLACK ? $match->player1 : $match->player2;
    my $opp = $color == WHITE ? $match->player1 : $match->player2;

    my $cube = $match->getCube;
    my $points = $cube == 1 ? "1 point" : "$cube points";
    my $msg = "\n$opp gives up. $dropper wins $points.\n";
    
    $self->__endOfGame ($match, $msg);

    return $self;
}

sub __formatMove {
    my ($self, $color, @points) = @_;
    
    my $move = '';
    
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
        $move .= " $from-$to";
    }

    return $move;
}

sub __endOfGame {
    my ($self, $match, $msg) = @_;

    my $session = $self->{__session};
    my $user = $session->getUser;

    return $self->__endOfMatch ($match, $msg) if $match->over;
    
    my $logger = $session->getLogger;
    
    my ($score1, $score2) = $match->score;
    my $points = $match->getLength;
    if ($points < 0) {
        $points = 'unlimited';
    } else {
        $points = "$points point";
    }
    my $score;
    
    my ($player1, $player2) = ($match->player1, $match->player2);
    if ($user->{name} eq $match->player1) {
        my $opp = $match->player2;
        $score = "$user->{name}-$score1 $opp-$score2";
    } else {
        my $opp = $match->player1;
        $score = "$user->{name}-$score2 $opp-$score1";
    }
    
    $msg .= "score in $points match: $player1-$score1 $player2-$score2\n";

    $session->reply ($msg);
    
    return $self;
}

sub __endOfMatch {
    my ($self, $match, $msg) = @_;
    
    my $session = $self->{__session};
    
    my @score = $match->score;
    my $winner;
    
    if ($score[0] > $score[1]) {
        $winner = $match->player1;
    } else {
        $winner = $match->player2;
    }    
    my $points = $match->getLength;
    if ($points < 0) {
        $points = 'unlimited';
    } else {
        $points = "$points point";
    }
    $msg .= "$winner wins the $points match $score[0]-$score[1] .\n";
    
    $session->reply ($msg);
        
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Message::watch - BaldLies Message `watch'

=head1 SYNOPSIS

  use BaldLies::Session::Message::watch->new;
  
=head1 DESCRIPTION

This plug-in handles the master message `watch'.

=head1 SEE ALSO

BaldLies::Session::Message(3pm), baldlies(1), perl(1)

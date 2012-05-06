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
use BaldLies::Util qw (equals);

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

    my $match = BaldLies::Backgammon::Match->new ($dump);
    
    return $self->$method ($match, $color, @data);
}

sub __handleStart {
    my ($self, $match, $color) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;

    $session->reply (__LINE__ . ": $color\n");
    
    return $self;
}

sub __handleResume {
    my ($self, $match, $color) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;

    $session->reply (__LINE__ . ": $color\n");
    
    return $self;
}

sub __handleOpening {
    my ($self, $match, $color, $die1, $die2) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;

    $session->reply (__LINE__ . ": $color\n");
    
    return $self;
}

sub __handleMove {
    my ($self, $match, $color, @points) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;

    $session->reply (__LINE__ . ": $color\n");
    
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

    $session->reply (__LINE__ . ": $color\n");
    
    return $self;
}

sub __handleResign {
    my ($self, $color, $value) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;

    $session->reply (__LINE__ . ": $color\n");
    
    return $self;
}

sub __handleAccept {
    my ($self, $match, $color) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;

    $session->reply (__LINE__ . ": $color\n");
    
    return $self;
}

sub __handleTake {
    my ($self, $match, $color) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;

    $session->reply (__LINE__ . ": $color\n");
    
    return $self;
}

sub __handleReject {
    my ($self, $match, $color) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;

    $session->reply (__LINE__ . ": $color\n");
    
    return $self;
}

sub __handleDrop {
    my ($self, $match, $color) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;

    $session->reply (__LINE__ . ": $color\n");
    
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

1;

=head1 NAME

BaldLies::Session::Message::watch - BaldLies Message `watch'

=head1 SYNOPSIS

  use BaldLies::Session::Message::watch->new;
  
=head1 DESCRIPTION

This plug-in handles the master message `watch'.

=head1 SEE ALSO

BaldLies::Session::Message(3pm), baldlies(1), perl(1)

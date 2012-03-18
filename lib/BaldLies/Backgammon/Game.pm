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

package BaldLies::Backgammon::Game;

use strict;

use BaldLies::Backgammon::Board;
use BaldLies::Const qw (:colors);

# States.
use constant OPENING_ROLL => 0;
use constant ROLL_OR_DOUBLE => 1;
use constant MOVE => 2;
use constant TAKE_OR_DROP => 3;
use constant ACCEPT_OR_REJECT => 4;

sub new {
    my ($class, %args) = @_;

    my $self = {
        __player1 => $args{player1} || 'WHITE',
        __player2 => $args{player2} || 'BLACK',
        __crawford => $args{crawford},
        __cube => 1,
        __score => 0,
        __board => BaldLies::Backgammon::Board->new->init,
        __actions => [],
        __turn => 0,
        __state => OPENING_ROLL,
        __roll => [],
    };

    bless $self, $class;
}

sub isCrawford {
    shift->{__crawford};
}

sub over {
    shift->{__score}
}

sub generateMoves {
    my ($self, $die1, $die2, $color) = @_;

    return [] if $self->over;
    return [] if $self->{__state} != MOVE;
    return $self->{__board}->generateMoves ($die1, $die2, $color);
}

sub roll {
    my ($self, $color, $die1, $die2) = @_;

    if ($die1 < 1 || $die1 > 6 || $die2 < 1 || $die2 > 6) {
        die "Dice must be in range 1-6";
    }
    my $state = $self->{__state};
    if ($color) {
        die "It's not your turn to roll the dice.\n" if $color != $self->{__turn};
        if ($state != ROLL_OR_DOUBLE) {
            my $opponent = $self->{__turn} < 0 
                ? $self->{__player1} : $self->{__player2};
            die "You did already roll the dice.\n" if $state == MOVE;
            die "$opponent hasn't responded to your double yet.\n"
                if $state == ACCEPT_OR_REJECT;
            die "$opponent hasn't accepted or rejected your resign yet.\n"
                if $state == ACCEPT_OR_REJECT;
            die "The opening roll must be done by both players.\n"
                if $state == OPENING_ROLL;
            die "unknown error in state $state";
        }
    } elsif ($state == OPENING_ROLL) {
        # Opening roll.
        if ($die1 > $die2) {
            $self->{__turn} = WHITE;
            $self->{__state} = MOVE;
        } elsif ($die1 < $die2) {
            $self->{__turn} = BLACK;
            $self->{__state} = MOVE;
        } elsif ($self->{__autodouble}) {
            $self->{__cube} <<= 1;
        }
    } else {
            die "Usage: roll COLOR, die1, die2";
    }

    $self->{__roll} = [$die1, $die2];
    push @{$self->{__actions}}, roll => $color, $die1, $die2;
    if ($self->{__state}) {
        # Calculate legal moves.
        $self->{__moves} = $self->{__board}->generateMoves ($die1, $die2, 
                                                            $color);
    }
    
    return $self;
}

sub move {
    my ($self, $color, @pairs) = @_;

    die "Odd number of points in move" if @pairs % 2;
    die "No color given in move" if !$color;

    if ($self->{__state} != MOVE) {
        my $state = $self->{__state};
        my $opponent = $self->{__turn} < 0 
            ? $self->{__player1} : $self->{__player2};
        die "You have to roll the dice before moving.\n" 
            if $state == ROLL_OR_DOUBLE;
        die "$opponent hasn't responded to your double yet.\n"
            if $state == ACCEPT_OR_REJECT;
        die "$opponent hasn't accepted or rejected your resign yet.\n"
            if $state == ACCEPT_OR_REJECT;
        die "The opening roll must be done by both players.\n"
            if $state == OPENING_ROLL;
        die "unknown error in state $state";
    } elsif ($self->{__turn} != $color) {
        die "It's not your turn to move.\n";
    }

    my $legal = $self->{__moves};
    my $move = BaldLies::Backgammon::Move->new (@{$self->{__roll}}, @pairs);
    if ($self->{__board}->move ($move, $color, $legal)) {
        push @{$self->{__actions}}, move => $color, @pairs;
        $self->{__turn} = -$self->{__turn};
        $self->{__state} = ROLL_OR_DOUBLE;
        my $borne_off = $self->{__board}->borneOff ($color);
        if (!$borne_off) {
            if ($color < 0) {
                $self->{__score} = -$self->{__cube};
            } else {
                $self->{__score} = $self->{__cube};
            }
        }
        return $self;
    }
    
    # Illegal move.  Find exact error according to FIBS.
    
    # Last resort.
    die "Illegal move (unknown error, this should not happen)";
    
    return $self;
}

1;

=head1 NAME

BaldLies::Backgammon::Game - Representation of a single backgammon game

=head1 SYNOPSIS

  use BaldLies::Backgammon::Game;
  
  my $game = BaldLies::Backgammon::Game->new (crawford => 1);

  my $score = $game->over;
  my $boolean = $game->isCrawford;

=head1 DESCRIPTION

B<BaldLies::Backgammon::Game> represents a single backgammon game.

=head1 METHODS

=over 4

=item B<new ARGS>

Creates a new B<BaldLies::Backgammon::Game> object.  The following named 
arguments are supported:

=over 8

=item B<crawford>

If true, the crawford rule applies, and this is the crawford game.

=back

=item B<over>

If the game is over, the score is returned.  A positive number is used for a
white victory, a negative one for a black victory.

=item B<isCrawford>

Returns false if this is not the crawford game, otherwise returns the object
itself.

=back

=head1 SEE ALSO

perl(1)

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

package BaldLies::Backgammon::Match;

use strict;

use BaldLies::Const qw (:match :colors);
use BaldLies::Util qw (empty);
use BaldLies::Backgammon::Game;

sub new {
    my ($class, %args) = @_;

    my $self = {};
    while (my ($key, $value) = each %args) {
        $self->{'__' . $key} = $value;
    }
    $self->{__length} ||= -1;
    $self->{__player1} = 'Black' if empty $self->{__player1};
    $self->{__score1} ||= 0;
    $self->{__player2} = 'White' if empty $self->{__player2};
    $self->{__score2} ||= 0;
    
    if ($self->{__length} > 0) {
        if ($self->{__score1} >= $self->{__length}) {
            $self->{__over} = WHITE;
        } elsif ($self->{__score2} >= $self->{__length}) {
            $self->{__over} = BLACK;
        } else {
            $self->{__over} = 0;
        }
    } else {
        $self->{__over} = 0;
    }
    $self->{__crawford} = 0 if $self->{__length} < 0;
    
    bless $self, $class;

    $self->__newGame unless $self->{__game};
    
    return $self;    
}

sub do {
    my ($self, $action, @payload) = @_;

    die "The match is already over.\n" if $self->{__over};
    
    my $game = $self->{__game};
    $game->$action (@payload);

    $self->__newGame if $game->over;
    
    return $self;
}

sub over {
    shift->{__over};
}

sub __newGame {
    my ($self) = @_;
 
    my $old_game = $self->{__game};
    my $is_crawford;
    if ($old_game) {
        my $score = $old_game->over;
        # Check, whether this will be the crawford game.  We first set it to
        # true, and then reset it, when necessary.
        if ($self->{__crawford}) {
            $is_crawford = 1;
            if ($self->{__score1} == $self->{__length} - 1
               || $self->{__score2} == $self->{__length} - 1) {
                   undef $is_crawford;
            }
        }
        if ($score > 0) {
            $self->{__score1} += $score;
            if ($self->{__length} > 0 
                && $self->{__score1} >= $self->{__length}) {
                $self->{__over} = WHITE;
            }
        } elsif ($score < 0) {
            $self->{__score2} -= $score;
            if ($self->{__length} > 0 
                && $self->{__score1} >= $self->{__length}) {
                $self->{__over} = BLACK;
            }
        }
        if ($is_crawford) {
            if ($self->{__score1} != $self->{__length} - 1
               && $self->{__score2} != $self->{__length} - 1) {
                   undef $is_crawford;
            }
        }
    }
    
    my %options = (
        crawford => $is_crawford,
    );
    $self->{__game} = BaldLies::Backgammon::Game->new (%options);
    
    return $self;   
}

1;

=head1 NAME

BaldLies::Backgammon::Match - Representation of a backgammon match

=head1 SYNOPSIS

  use BaldLies::Backgammon::Match;

=head1 DESCRIPTION

B<BaldLies::Backgammon::Match> represents a backgammon match.

=head1 SEE ALSO

perl(1)

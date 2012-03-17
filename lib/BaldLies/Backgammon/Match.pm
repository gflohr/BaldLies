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
    $self->{__state} ||= MATCH_GAME_START;
    $self->{__game} ||= BaldLies::Backgammon::Game->new;    
    
    bless $self, $class;
}

sub proceed {
    my ($self) = @_;
    
    my $state = $self->{__state};
    if (!$state) {
        $self->{__state} = MATCH_GAME_START;
        return tell => 'start', 'game';
    }
    
    my $game = $self->{__game};
    return $game->proceed;
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

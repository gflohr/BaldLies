#! /bin/false

# This file is part of OpenFIBS.
# Copyright (C) 2012 Guido Flohr, http://guido-flohr.net/.
#
# OpenFIBS is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# OpenFIBS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with OpenFIBS.  If not, see <http://www.gnu.org/licenses/>.

package OpenFIBS::Backgammon::Game;

use strict;

use OpenFIBS::Backgammon::Board;

sub new {
    my ($class, %args) = @_;

    my $self = {
        __crawford => $args{crawford},
        __score => 0,
        __board => OpenFIBS::Backgammon::Board->new->init, 
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

    return $self->{__board}->generateMoves ($die1, $die2, $color);
}

1;

=head1 NAME

OpenFIBS::Backgammon::Game - Representation of a single backgammon game

=head1 SYNOPSIS

  use OpenFIBS::Backgammon::Game;
  
  my $game = OpenFIBS::Backgammon::Game->new (crawford => 1);

  my $score = $game->over;
  my $boolean = $game->isCrawford;

=head1 DESCRIPTION

B<OpenFIBS::Backgammon::Game> represents a single backgammon game.

=head1 METHODS

=over 4

=item B<new ARGS>

Creates a new B<OpenFIBS::Backgammon::Game> object.  The following named 
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

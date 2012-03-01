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

package BaldLies::Backgammon::Move;

use strict;

sub new {
    my ($class, $die1, $die2, @points) = @_;

    bless [$die1, $die2, @points], $class;
}

sub copy {
    my ($proto, $arg) = @_;

    if (ref $proto) {
        my $class = ref $proto;
        return bless [@$proto], $class;
    }

    bless [@$arg], $proto;
}

sub equals {
    my ($self, $other) = @_;

    return if @$self != @$other;
    if ($self->[0] != $other->[0]) {
        return if ($self->[0] != $other->[1] || $self->[1] != $other->[0]);
    } else {
        return if $self->[1] != $other->[1];
    }

    for (my $i = 2; $i < @$self; ++$i) {
        return if $self->[$i] != $other->[$i];
    }

    return $self;
}

sub swap {
    my ($self) = @_;

    for (my $i = 2; $i < @$self; ++$i) {
        $self->[$i] = 25 - $self->[$i];
    }

    return $self;
}

1;

=head1 NAME

BaldLies::Backgammon::Move - Backgammon move representation

=head1 SYNOPSIS

  use BaldLies::Backgammon::Move;

  my $move = BaldLies::Backgammon::Move->new (3, 1, 8, 5, 6, 5);

=head1 DESCRIPTION

B<BaldLies::Backgammon::Move> represents one backgammon move.

=head1 CONSTRUCTORS

=over 4

=item B<new DIE1, DIE2, ...>

Create a new move.   The first two arguments are the values of the dice
in the range of 1-6.  Following are 0 to 4 pairs of start and landing
points in the range of 0-25.

=item B<copy OTHER>

As a class method, creates a deep copy of B<OTHER>.

=back

=head1 METHODS

=over 4 

=item B<copy>

Returns a deep copy of the object.

=item B<equals OTHER>

Returns the object itself, if B<OTHER> is an identical move, false otherwise.

=item B<swap>

Swaps the direction of the move.

=back

=head1 SEE ALSO

perl(1)

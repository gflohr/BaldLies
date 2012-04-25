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

package BaldLies::Backgammon::Board;

use strict;

use BaldLies::Const qw (:colors);

my @initial = (
    0,
    -2, 0, 0, 0, 0, +5,
    0, +3, 0, 0, 0, -5,
    +5, 0, 0, 0, -3, 0,
    -5, 0, 0, 0, 0, +2,
    0
);

sub new {
    bless [(0) x 26], shift;
}

sub copy {
    my ($proto, $arg) = @_;

    if (ref $proto) {
        my $class = ref $proto;
        return bless [@$proto], $class;
    }

    bless [@$arg], $proto;
}

sub init {
    my ($proto) = @_;

    if (ref $proto) {
        @$proto = @initial;
        return $proto;
    }

    bless [@initial], $proto;
}

sub set {
    my ($self, $set) = @_;

    foreach (@$self) {
        $_ = shift @$set;
    }

    return $self;
}

sub equals {
    my ($self, $other) = @_;

    for (my $i = 0; $i < 26; ++$i) {
        return unless $self->[$i] == $other->[$i];
    }

    return $self;
}

sub __applyMovement {
    my ($self, $from, $to) = @_;

    --$self->[$from];
    if ($to > 0) {
        if ($self->[$to] == -1) {
            $self->[$to] = 1;
            --$self->[0];
        } else {
            ++$self->[$to];
        }
    }
    
    return $self;
}

sub applyMove {
    my ($self, $move, $color) = @_;

    for (my $i = 2; $i < @$move; $i += 2) {
        my $from = $move->[$i];
        my $to = $move->[$i + 1];
        if ($color < 0) {
            return if $self->[$from] >= 0;
            ++$self->[$from];
            if ($to < 25) {
                if ($self->[$to] == 1) {
                    $self->[$to] = -1;
                    ++$self->[25];
                } elsif ($self->[$to] > 1) {
                    return;
                } else {
                    --$self->[$to];
                }
            }
        } else {
            return if $self->[$from] <= 0;
            --$self->[$from];
            if ($to > 0) {
                if ($self->[$to] == -1) {
                    $self->[$to] = 1;
                    --$self->[0];
                } elsif ($self->[$to] < -1) {
                    return;
                } else {
                    ++$self->[$to];
                }
            }
        }
    }

    return $self;
}

sub swap {
    my ($self) = @_;

    for (my $i = 0; $i < 13; ++$i) {
        ($self->[$i], $self->[25 - $i]) = (-$self->[25 - $i], -$self->[$i]);
    }

    return $self;
}

sub borneOff {
    my ($self, $color) = @_;

    my $borne_off = 15;
    if ($color < 0) {
        map { $borne_off += $_ if $_ < 0 } @$self;
    } else {
        map { $borne_off -= $_ if $_ > 0 } @$self;
    }

    return $borne_off;
}

sub generateMoves {
    my ($self, $die1, $die2, $color) = @_;

    # Normalize board.  We always calculate moves for white.
    my $board = $color < 0 ? $self->copy->swap : $self;

    my @dice;
    if ($die1 < $die2) {
        @dice = ($die2, $die1);
    } elsif ($die1 > $die2) {
        @dice = ($die1, $die2);
    } else {
        @dice = ($die1, $die1, $die1, $die1);
    }

    for (my $i = @dice; $i > 0; --$i) {
        my $moves = $board->__generateNMoves ($i, {}, @dice);
        if (@$moves) {
            # Make sure that the higher die is preferred!  Since we know that
            # our move generator always tries to use the higher die, we can
            # simply cut the list as soon as the point difference becomes
            # lower.
            if (@$moves > 1 && 2 == @dice && 1 == $i) {
                my $max_diff = $moves->[0]->[0] - $moves->[0]->[1];
                for (my $j = 1; $j < @$moves; ++$j) {
                    my $move = $moves->[$j];
                    my $diff = $move->[0] - $move->[1];
                    if ($diff < $max_diff) {
                        $#{$moves} = $j - 1;
                        last;
                    }
                }
            }
            return $moves if @$moves;
        }
    }

    return [];
}

sub move {
    my ($self, $move, $color, $moves) = @_;

    $moves ||= $self->generateMoves ($move->[0], $move->[1], $color);
    if (!@$moves) {
        return if 2 != @$move;
        return $self;
    }

    my $target = $self->copy;
    my $use_move = $move;
    if ($color < 0) {
        $target->swap;
        $use_move = $move->copy->swap;
    }
    my $copy = $target->copy;
    return if !$target->applyMove ($use_move, WHITE);
    my $wanted = pack 'c26', @$target;

    my $legal;
    foreach my $m (@$moves) {
        my $result = $copy->copy;
        for (my $i = 0; $i < @$m; $i += 2) {
            $result->__applyMovement ($m->[$i], $m->[$i + 1]);
        }
        my $got = pack 'c26', @$result;
        if ($got eq $wanted) {
             $legal = 1;
             last;
        }
    }

    return if !$legal;

    $self->applyMove ($move, $color);

    return $self;
}

sub __generateNMoves {
    my ($self, $n, $seen, @dice) = @_;

    my @moves;

    my $die = shift @dice;

    # On the bar?
    my $min_from;
    if ($self->[25] > 0) {
        $min_from = 24;
    } else {
        $min_from = $die;
    }

    my $may_bear_off = 1;
    for (my $from = 25; $from > $min_from; --$from) {
        # Checker?
        next if $self->[$from] <= 0;

        $may_bear_off = 0 if $from > 6;
        
        my $to = $from - $die;
        $to = 0 if $to < 0;
        # Occupied?
        next if $self->[$to] < -1;

        my $new_board = $self->copy;
        $new_board->__applyMovement ($from, $to);
        my $digest = pack 'c*', @$new_board, @dice;
        next if $seen->{$digest};
        $seen->{$digest} = 1;

        if ($n == 1) {
            push @moves, [$from, $to];
            next;
        }

        my $new_moves = $new_board->__generateNMoves ($n - 1, $seen, @dice);
        foreach my $move (@$new_moves) {
            push @moves, [$from, $to, @$move];
        }
    }

    if ($may_bear_off) {
        my $from;
        if ($self->[$die] > 0) {
            $from = $die;
        } else {
            my $highest;
            for ($highest = 6; $highest > 0; --$highest) {
                last if $self->[$highest] > 0;
            }
            $from = $highest if $highest < $die
        }
        # A gratuitous while loop is the poor man's goto ...
        while ($from) {
            my $new_board = $self->copy;
            $new_board->__applyMovement ($from, 0);
            # Why do we have to add the dice that are left to the board, when
            # building the digest? Say we have one chequer on the 5 point, all
            # others on the deuce and on the ace point, and we roll 51.  Under
            # normal circumstances, we would bear-off from the five and the
            # ace point.
            #
            # But it is perfectly legal to move 5/4 4/off instead.  However,
            # after that move, the position is exactly the same like the one
            # we have after bearing off from the five point with one die,
            # and having the 1 left to use.
            my $digest = pack 'c*', @$new_board, @dice;
            last if $seen->{$digest};
            $seen->{$digest} = 1;

            if ($n == 1) {
                push @moves, [$from, 0];
                last;
            }

            my $new_moves = $new_board->__generateNMoves ($n - 1, $seen, @dice);
            foreach my $move (@$new_moves) {
                push @moves, [$from, 0, @$move];
            }
            last;
        }
    }

    if (@dice == 1 && $die > $dice[0]) {
        push @moves, @{$self->__generateNMoves ($n, $seen, 
                                                $dice[0], $die)};
    }

    return \@moves;
}

sub dump {
    my ($self) = @_;
    
    my $white = 'O';
    my $black = 'X';
    
    my $output = <<EOF;
   +-1--2--3--4--5--6--------7--8--9-10-11-12-+
EOF

    $output .= '   |';
    foreach my $p (1, 2, 3, 4, 5, 6, 25, 7, 8, 9, 10, 11, 12) {
        if ($self->[$p] <= -10) {
            $output .= -$self->[$p];
        } elsif ($self->[$p] < -5) {
            $output .= ' ' . -$self->[$p];
        } elsif ($self->[$p] < 0) {
            $output .= ' ' . $black;
        } elsif ($self->[$p] >= 10) {
            $output .= $self->[$p];
        } elsif ($self->[$p] > 5) {
            $output .= ' ' . $self->[$p];
        } elsif ($self->[$p] > 0) {
            $output .= ' ' . $white;
        } else {
            $output .= '  ';
        }
        $output .= ' ';
        if ($p == 6) {
            $output .= '|';
        } elsif ($p == 25) {
            $output .= '| ';
        }
    }
    $output .= "|\n";

    foreach my $i (2, 3, 4, 5) {
        $output .= '   |';
        foreach my $p (1, 2, 3, 4, 5, 6, 25, 7, 8, 9, 10, 11, 12) {
            if ($self->[$p] <= -$i) {
                $output .= ' ' . $black;
            } elsif ($self->[$p] >= $i) {
                $output .= ' ' . $white;
            } else {
                $output .= '  ';
            }
            $output .= ' ';
            if ($p == 6) {
                $output .= '|';
            } elsif ($p == 25) {
                $output .= '| ';
            }
        }
        $output .= "|\n";
    }
            
    $output .= <<EOF;
   |                  |BAR|                   |
EOF

    foreach my $i (5, 4, 3, 2) {
        $output .= '   |';
        foreach my $p (24, 23, 22, 21, 20, 19, 0, 18, 17, 16, 15, 14, 13) {
            if ($self->[$p] <= -$i) {
                $output .= ' ' . $black;
            } elsif ($self->[$p] >= $i) {
                $output .= ' ' . $white;
            } else {
                $output .= '  ';
            }
            $output .= ' ';
            if ($p == 19) {
                $output .= '|';
            } elsif ($p == 0) {
                $output .= '| ';
            }
        }
        $output .= "|\n";
    }

    $output .= '   |';
    foreach my $p (24, 23, 22, 21, 20, 19, 0, 18, 17, 16, 15, 14, 13) {
        if ($self->[$p] <= -10) {
            $output .= -$self->[$p];
        } elsif ($self->[$p] < -5) {
            $output .= ' ' . -$self->[$p];
        } elsif ($self->[$p] < 0) {
            $output .= ' ' . $black;
        } elsif ($self->[$p] >= 10) {
            $output .= $self->[$p];
        } elsif ($self->[$p] > 5) {
            $output .= ' ' . $self->[$p];
        } elsif ($self->[$p] > 0) {
            $output .= ' ' . $white;
        } else {
            $output .= '  ';
        }
        $output .= ' ';
        if ($p == 19) {
            $output .= '|';
        } elsif ($p == 0) {
            $output .= '| ';
        }
    }
    $output .= "|\n";

    my $white_off = $self->borneOff (WHITE);
    my $black_off = $self->borneOff (BLACK);
    my $cube = 1;
    my $turn = '';
    
    $output .= <<EOF;
   +24-23-22-21-20-19-------18-17-16-15-14-13-+
   
   BAR: O-$self->[25] X-$self->[0]   OFF: O-$white_off X-$black_off   Cube: $cube  turn: $turn
EOF

    return $output;    
}

=head1 NAME

BaldLies::Backgammon::Board - Backgammon board representation

=head1 SYNOPSIS

  use BaldLies::Backgammon::Board;

  my $board = BaldLies::Backgammon::Board->new;
  my $copy = $board->copy;

=head1 DESCRIPTION

B<BaldLies::Backgammon::Board> is a dumb representation of the distribution
of checkers on a backgammon board.  It is actually a blessed array, and you
can safely access all members.

The array has 26 elements.  Element #0 is black's bar, #1 is white's
ace point, #24 is black's ace point, and #25 is white's bar.  There is no
bear-off tray!

The number of checkers on each point is encoded with a number in the range
of -15 to +15 (inclusively).  White's checkers are represented by negative
counts, black's checkers by positive counts.

=head1 CONSTRUCTORS

=over 4

=item B<new>

Creates a new, empty(!) board.

=item B<copy OTHER>

As a class method, creates a copy of B<OTHER>.

=item B<init>

As a class method, returns a board with the initial position.

=back

=head1 METHODS

=item B<copy>

Returns a deep copy of the object.

=item B<init>

Fills the object with the initial position and returns it.

=item B<equals OTHER>

Returns the object itself if B<OTHER> is identical, a false value otherwise.

=item B<applyMove MOVE, COLOR>

Applies B<MOVE> (see BaldLies::Backgammon::Move(3pm)) for B<COLOR> to the
position.  Returns the object itself in case of success or false in case
of failure.

The method will fail if the move implies moving non-existing checkers or
landing on occupied fields.  However, B<MOVE> is not completely checked
for legality.

=item B<swap>

Swaps the colors and returns itself.

=item B<borneOff COLOR>

Returns the number of borne-off checkers for B<COLOR>.

=item B<generateMoves DIE1, DIE2, COLOR>

Generates all legal moves for B<COLOR> in the current position when the
dice rolled are B<DIE2> and B<DIE2>.  The moves are returned as a a reference
to an array of arrays of point pairs.

The function cannot fail.

=item B<move MOVE, COLOR>

Checks whether the the BaldLies::Backgammon::Move(3pm) is legal provided
B<COLOR> is on move.  Returns false in case of failure.  In case of success,
the move is applied to the current position, and the object itself is
returned.

=item B<dump>

Returns a crude ASCII art representation of the board.

=back

=head1 SEE ALSO

BaldLies::Backgammon::Move(3pm), BaldLies::Const(3pm), perl(1)

1;


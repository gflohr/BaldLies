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

sub board {
    my ($self, $style) = @_;
    
    if ($style == 1 || $style == 2) {
        return $self->__graphicalBoard ($style - 1);
    }
    die "Unsupported board style $style";
}

sub __graphicalBoard {
    my ($self, $extra) = @_;

    my $game = $self->{__game};
    my $board = $game->getBoard;

    my $white = 'O';
    my $black = 'X';
    
    my $output;
    if ($extra) {
        $output = <<EOF;
     1  2  3  4  5  6        7  8  9 10 11 12
   +------------------------------------------+ O: $self->{__player1}
EOF
    } else {
        $output = <<EOF;
   +-1--2--3--4--5--6--------7--8--9-10-11-12-+ O: $self->{__player1}
EOF
    }
    
    $output .= '   |';
    foreach my $p (1, 2, 3, 4, 5, 6, 25, 7, 8, 9, 10, 11, 12) {
        if ($board->[$p] <= -10) {
            $output .= -$board->[$p];
        } elsif ($board->[$p] < -5) {
            $output .= ' ' . -$board->[$p];
        } elsif ($board->[$p] < 0) {
            $output .= ' ' . $black;
        } elsif ($board->[$p] >= 10) {
            $output .= $board->[$p];
        } elsif ($board->[$p] > 5) {
            $output .= ' ' . $board->[$p];
        } elsif ($board->[$p] > 0) {
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
            if ($board->[$p] <= -$i) {
                $output .= ' ' . $black;
            } elsif ($board->[$p] >= $i) {
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
            if ($board->[$p] <= -$i) {
                $output .= ' ' . $black;
            } elsif ($board->[$p] >= $i) {
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
        if ($board->[$p] <= -10) {
            $output .= -$board->[$p];
        } elsif ($board->[$p] < -5) {
            $output .= ' ' . -$board->[$p];
        } elsif ($board->[$p] < 0) {
            $output .= ' ' . $black;
        } elsif ($board->[$p] >= 10) {
            $output .= $board->[$p];
        } elsif ($board->[$p] > 5) {
            $output .= ' ' . $board->[$p];
        } elsif ($board->[$p] > 0) {
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

    my $white_off = $board->borneOff (WHITE);
    my $black_off = $board->borneOff (BLACK);
    my $cube = 1;
    my $turn = '';

    if ($extra) {
        $output .= <<EOF;
   +------------------------------------------+ X: $self->{__player2}
    24 23 22 21 20 19       18 17 16 15 14 13
EOF
    } else {
        $output .= <<EOF;
   +24-23-22-21-20-19-------18-17-16-15-14-13-+ X: $self->{__player2}
EOF
    }
    $output .= <<EOF;

   BAR: O-$board->[25] X-$board->[0]   OFF: O-$white_off X-$black_off   Cube: $cube  turn: $turn
EOF

    return $output;    
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

=cut

__END__

> set boardstyle 1
Value of 'boardstyle' set to 1.
> board
   +-1--2--3--4--5--6--------7--8--9-10-11-12-+ O: GibbonTestD - score: 0
   | X              O |   |     O     O     X |
   | X              O |   |     O           X |
   |                O |   |     O           X |
   |                O |   |                 X |
   |                O |   |                   |
   |                  |BAR|                   |v    unlimited match
   |                X |   |                   |     No redoubles
   |                X |   |                 O |
   |                X |   |                 O |
   |                X |   |  X  X           O |
   | O              X |   |  X  X        O  O |
   +24-23-22-21-20-19-------18-17-16-15-14-13-+ X: GibbonTestA - score: 0

   BAR: O-0 X-0   OFF: O-0 X-0   Cube: 2 (owned by GibbonTestD)  You rolled 5 6.
> set boardstyle 2
Value of 'boardstyle' set to 2.
> board
     1  2  3  4  5  6        7  8  9 10 11 12
   +------------------------------------------+ O: GibbonTestD - score: 0
   | X              O |   |     O     O     X |
   | X              O |   |     O           X |
   |                O |   |     O           X |
   |                O |   |                 X |
   |                O |   |                   |
   |                  |BAR|                   |v    unlimited match
   |                X |   |                   |     No redoubles
   |                X |   |                 O |
   |                X |   |                 O |
   |                X |   |  X  X           O |
   | O              X |   |  X  X        O  O |
   +------------------------------------------+ X: GibbonTestA - score: 0
    24 23 22 21 20 19       18 17 16 15 14 13

   BAR: O-0 X-0   OFF: O-0 X-0   Cube: 2 (owned by GibbonTestD)  You rolled 5 6.
> set boardstyle 3
Value of 'boardstyle' set to 3.
> board
board:You:GibbonTestD:9999:0:0:0:-2:0:0:0:0:5:0:3:0:1:0:-4:4:1:0:0:-2:-2:-5:0:0:0:0:1:0:-1:5:6:0:0:2:0:1:0:-1:1:25:0:0:0:0:0:2:0:0:0

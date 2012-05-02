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

use BaldLies::Const qw (:colors);
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
    $self->{__redoubles} ||= 0;
    $self->{__old_games} ||= [];
    $self->{__pending} = {};
        
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
    
    delete $self->{__fresh_game};

    if (keys %{$self->{__pending}}) {
        if ('roll' eq $action) {
            die "It's not your turn to roll the dice.\n";
        } elsif ('move' eq $action) {
            die "It's not your turn to move.\n";
        } elsif ('beaver' eq $action || 'redouble' eq $action) {
            die "You are not allowed to redouble.\n";
        } elsif ('resign' eq $action) {
            die "The game is already over.\n";
        }
        
        my $color = $payload[0];
        my $opponent;
        if ($color == BLACK) {
            $opponent = $self->{__player1};
        } else {
            $opponent = $self->{__player2};
        }
        if ('accept' eq $action || 'reject' eq $action) {
            die "$opponent didn't double or resign.\n";
        }     
       
        die "The match is paused.\n";
    }
    
    my $game = $self->{__game};
    $game->$action (@payload);

    if ($game->over) {
        $self->__newGame;
        $self->{__fresh_game} = 1;
    }
    
    return $self;
}

sub over {
    shift->{__over};
}

sub board {
    my ($self, $style, $turn) = @_;
    
    if (1 == $style || 2 == $style) {
        return $self->__graphicalBoard ($style - 1, $turn);
    } elsif (3 == $style) {
        return $self->__clipBoard ($turn);
    }
    die "Unsupported board style $style";
}

sub score {
    my ($self) = @_;
    
    return $self->{__score1}, $self->{__score2};
}

sub getCurrentGame {
    shift->{__game};
}

sub getPostCrawford {
    my ($self) = @_;
    
    return if !$self->{__crawford};
    
    my $white_away = $self->{__length} - $self->{__score1};
    my $black_away = $self->{__length} - $self->{__score2};
    
    return $self if ($white_away == 1 && $black_away == 1);
    return if ($white_away != 1 && $black_away != 1);
    
    return $self if !$self->{__game}->isCrawford;
    
    return;
}

sub legalMoves {
    shift->{__game}->legalMoves;
}

sub forcedMove {
    my ($self) = @_;
    
    return if $self->{__over};

    return $self->{__game}->forcedMove;    
}

sub gameOver {
    my ($self) = @_;
    
    return $self if $self->{__fresh_game};
    
    return;
}

sub getAutodouble {
    shift->{__autodouble};
}

sub getCube {
    shift->{__game}->cube;
}

sub getCubeOwner {
    shift->{__game}->cubeOwner;
}

sub cubeTurned {
    shift->{__game}->cubeTurned;
}

sub getTurn {
    shift->{__game}->getTurn;
}

sub getLength {
    shift->{__length};
}

sub getResignation {
    shift->{__game}->getResignation;
}

sub getLastWin {
    my ($self) = @_;
    
    return 0 if !@{$self->{__old_games}};

    return abs $self->{__old_games}->[-1]->over;
}

sub getMoves {
    my ($self) = @_;
    
    my $points = $self->{__length} < 0 ?
         'an unlimited' : "a $self->{__length} point";
    
    my $game = $self->{__fresh_game} ? 
        $self->{__old_games}->[-1] : $self->{__game};
    
    my $score1 = $self->{__score1};
    my $score2 = $self->{__score2};
    my $over = $self->{__game}->over;
    if ($over > 0) {
        $score1 -= $over;
    } elsif ($over < 0) {
        $score2 += $over;
    }
    my $retval = "Score is $score1-$score2 in $points match.\n";
    
    $retval .= $game->getMoves;
    
    return $retval;
}

sub player1 {
    shift->{__player1};
}

sub player2 {
    shift->{__player2};
}

sub setScore {
    my ($self, $score1, $score2) = @_;
    
    $self->{__score1} = $score1;
    $self->{__score2} = $score2;
    
    return $self;
}

# This currently only works at the beginning of a new game!  To make it
# fully work, the corresponding method of BaldLies::Backgammon::Game has
# to be improved;
sub turnBoard {
    my ($self) = @_;
    
    ($self->{__score1}, $self->{__score2}) 
        = ($self->{__score2}, $self->{__score1});
    ($self->{__player1}, $self->{__player2}) 
        = ($self->{__player2}, $self->{__player1});
    
    $self->{__game}->turnBoard;
    
    return $self;
}

sub resetGame {
    my ($self) = @_;
    
    $self->{__game}->reset;
    
    return $self;
}

sub setCrawford {
    my ($self, $value) = @_;
    
    if ($self->{__crawford} && $value) {
        $self->{__game}->setCrawford (1);
    } else {
        $self->{__game}->setCrawford (0);
    }
    
    return $self;
}

sub setPending {
    my ($self, $name, $value) = @_;
    
    if ($value) {
        $self->{__pending}->{$name} = 1;
    } else {
        delete $self->{__pending}->{$name};
    }
    
    return;
}

sub getPending {
    my ($self, $name) = @_;
    
    if (exists $self->{__pending}->{$name}) {
        return $self->{__pending}->{$name};    
    }
    
    return;
}

# Board between games:
#board:You:GibbonTestD:9999:7:9:0:-2:0:0:0:0:5:0:3:0:0:0:-5:5:0:0:0:-3:0:-5:0:0:0:0:2:0:0:0:0:0:0:1:1:1:0:1:-1:0:25:0:0:0:0:2:0:0:0
sub __clipBoard {
    my ($self, $x) = @_;
    
    my $game = $self->{__game};
    my $board = $game->getBoard;
    
    my $output = 'board';
    
    $output .= ':You';
    
    if ($x) {
        $output .= ':' . $self->{__player1};
    } else {
        $output .= ':' . $self->{__player2};
    }
 
    my $l = $self->{__length};
    $l = 9999 if $l < 0;
    $output .= ':' . $l;
    
    if ($x) {
        $output .= ":$self->{__score2}:$self->{__score1}";
    } else {
        $output .= ":$self->{__score1}:$self->{__score2}";
    }

    foreach my $i (0 .. 25) {
        $output .= ':' . $board->[$i];
    }
    
    my $turn = $game->getTurn;
    
    if ($game->over) {
        $turn = '0';
    } elsif ($game->cubeTurned) {
        # This is FIBS' behavior when the cube is turned.
        $turn = -$turn;
        
    }
    $output .= ":$turn";
    
    my @dice = (0, 0, 0, 0);
    my @roll = @{$game->getRoll};
    if (@roll) {
        if ((WHITE == $turn && !$x) || (BLACK == $turn && $x)) {
            @dice[0, 1] = @roll;
        } else {
            @dice[2, 3] = @roll;
        }
    }
    $output .= ":$dice[0]:$dice[1]:$dice[2]:$dice[3]";
    
    $output .= ':' . $game->cube;
    
    # FIBS sets these to 1 even in the crawford game!
    my @may_double = (1, 1);
    my $cube_owner = $game->cubeOwner;
    if ($cube_owner == WHITE) {
        @may_double = (1, 0);
    } elsif ($cube_owner == BLACK) {
        @may_double = (0, 1);
    }
    
    # But it sets it to all zero, if the cube is currently turned.
    @may_double = (0, 0) if $game->cubeTurned;
    
    @may_double = reverse @may_double if $x;
    $output .= ":$may_double[0]:$may_double[1]:";

    if ($game->cubeTurned
        && (BLACK == $game->cubeTurned && !$x
            || WHITE == $game->cubeTurned && $x)) {
        $output .= '1';
    } else {
        $output .= '0';
    }

    # There are only two possible options.    
    if ($x) {
        $output .= ':-1:1:25:0';
    } else {
        $output .= ':1:-1:0:25';
    }
    
    my $home1 = $game->borneOff (WHITE);
    my $home2 = $game->borneOff (BLACK);
    ($home1, $home2) = ($home2, $home1) if $x;
    $output .= ":$home1:$home2";

    my $bar1 = $board->[25];
    my $bar2 = -$board->[0];
    ($bar1, $bar2) = ($bar2, $bar1) if $x;
    $output .= ":$bar1:$bar2";

    # This field is completely bogs on FIBS.  It is initially 0, and has
    # then a value with no real meaning because it is not reset, when it
    # should be.
    # We implement it correctly here.
    my $num_pieces = 0;    
    if (@roll && ($turn == WHITE && !$x || $turn == BLACK && $x)) {
        my $moves = $game->legalMoves;
        if (@$moves) {
            $num_pieces = @{$moves->[0]};
            $num_pieces >>= 1;
        }
    }
    $output .= ":$num_pieces";
    
    # The next field is documented as 'Did Crawford'.  But that is wrong.
    # It is always 0, when the crawford rule applies.  When the crawford rule
    # is not in use, then it is 3 for all games which would otherwise be
    # the Crawford or a post-Crawford game.
    my $no_crawford = 0;
    my $post_crawford = 0;

    if ($self->{__length} > 0 &&
        ($self->{__length} - $self->{__score1} == 1)
        || ($self->{__length} - $self->{__score2} == 1)) {
        if ($self->{__crawford}) {
            $post_crawford = 1 if !$game->isCrawford;
        } else {
            $no_crawford = '3';
        }
    }

    $output .= ":$no_crawford:$post_crawford";
    
    $output .= ":$self->{__redoubles}";
    
    $output .= "\n";
    
    return $output;
}

sub __graphicalBoard {
    my ($self, $extra, $x) = @_;

    my $game = $self->{__game};
    my $board = $game->getBoard;

    my $white = 'O';
    my $black = 'X';
    my $upper = $x ? 'O' : 'X';
    my $lower = $x ? 'X' : 'O';
    my ($player1, $player2) = $x ? ($self->{__player2}, $self->{__player1})
                                 : ($self->{__player1}, $self->{__player2});
    
    my $output = "\n";
    if ($extra) {
        if ($x) {
            $output .= <<EOF;
     1  2  3  4  5  6        7  8  9 10 11 12
   +------------------------------------------+ $upper: $player2
EOF
        } else {
            $output .= <<EOF;
    13 14 15 16 17 18       19 20 21 22 23 24
   +------------------------------------------+ $upper: $player2
EOF
        }
    } else {
        if ($x) {
            $output .= <<EOF;
   +-1--2--3--4--5--6--------7--8--9-10-11-12-+ $upper: $player2
EOF
        } else {
            $output .= <<EOF;
   +13-14-15-16-17-18-------19-20-21-22-23-24-+ $upper: $player2
EOF
        }
    }
    
    my @points;

    if ($x) {
        @points = (1 .. 6, 25, 7 .. 12);
    } else {
        @points = (13 .. 18, 0, 19 .. 24);
    }
    $output .= '   |';
    foreach my $p (@points) {
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
        if ($p == $points[5]) {
            $output .= '|';
        } elsif ($p == $points[6]) {
            $output .= '| ';
        }
    }
    $output .= "|\n";

    foreach my $i (2, 3, 4, 5) {
        $output .= '   |';
        foreach my $p (@points) {
            if ($board->[$p] <= -$i) {
                $output .= ' ' . $black;
            } elsif ($board->[$p] >= $i) {
                $output .= ' ' . $white;
            } else {
                $output .= '  ';
            }
            $output .= ' ';
            if ($p == $points[5]) {
                $output .= '|';
            } elsif ($p == $points[6]) {
                $output .= '| ';
            }
        }
        $output .= "|\n";
    }

    my $lv = $x ? ' ' : 'v';
    my $rv = $x ? 'v' : '';
    my $match;
    my $redoubles = $self->{__redoubles};
    if ($self->{__length} < 0) {
        $match = 'unlimited match';
        $redoubles ||= 'No';
        $redoubles .= ' redoubles'
    } else {
        $match = "$self->{__length}-point match";
        $redoubles = '';
    }
    
    $output .= <<EOF;
  $lv|                  |BAR|                   |$rv    $match
EOF

    if ($x) {
        @points = (24, 23, 22, 21, 20, 19, 0, 18, 17, 16, 15, 14, 13);
    } else {
        @points = (12, 11, 10, 9, 8, 7, 25, 6, 5, 4, 3, 2, 1);
    }
    foreach my $i (5, 4, 3, 2) {
        $output .= '   |';
        foreach my $p (@points) {
            if ($board->[$p] <= -$i) {
                $output .= ' ' . $black;
            } elsif ($board->[$p] >= $i) {
                $output .= ' ' . $white;
            } else {
                $output .= '  ';
            }
            $output .= ' ';
            if ($p == $points[5]) {
                $output .= '|';
            } elsif ($p == $points[6]) {
                $output .= '| ';
            }
        }
        if ($i == 5) {
            $output .= "|     $redoubles\n";
        } else {
            $output .= "|\n";
        }
    }

    $output .= '   |';
    foreach my $p (@points) {
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
        if ($p == $points[5]) {
            $output .= '|';
        } elsif ($p == $points[6]) {
            $output .= '| ';
        }
    }
    $output .= "|\n";

    my $white_off = $board->borneOff (WHITE);
    my $black_off = $board->borneOff (BLACK);
    my $cube = $game->cube;
    my $cube_owner = $game->cubeOwner;
    if ($cube_owner) {
        if ($cube_owner < 0) {
            $cube .= " (owned by $self->{__player2})";
        } elsif ($cube_owner > 0) {
            $cube .= " (owned by $self->{__player1})";
        }
    }

    my $roll = $game->getRoll;
    
    # FIXME! There are more possible messages here:
    # - user doubled.
    # - ...
    my $turn = '';
    if (@$roll) {
        if ($game->getTurn < 0) {
            $turn = "$self->{__player2} rolled";
        } elsif ($game->getTurn > 0) {
            $turn = "$self->{__player1} rolled";
        } else {
            $turn = "Opening roll";
        }
        $turn .= " $roll->[0] $roll->[1]";
    } elsif ($game->getTurn) {
        if ($game->getTurn < 0) {
            $turn = "turn: $self->{__player2}";
        } else {
            $turn = "turn: $self->{__player1}";
        }
    }
    
    if ($extra) {
        if ($x) {
            $output .= <<EOF;
   +------------------------------------------+ $lower: $player1
    24 23 22 21 20 19       18 17 16 15 14 13
EOF
        } else {
            $output .= <<EOF;
   +------------------------------------------+ $lower: $player1
    12 11 10  9  8  7        6  5  4  3  2  1
EOF
        }
    } else {
        if ($x) {
            $output .= <<EOF;
   +24-23-22-21-20-19-------18-17-16-15-14-13-+ $lower: $player1
EOF
        } else {
            $output .= <<EOF;
   +12-11-10--9--8--7--------6--5--4--3--2--1-+ $lower: $player1
EOF
        }
    }
    
    my $bar_o = $board->[25];
    my $bar_x = -$board->[0];
    
    $output .= <<EOF;

   BAR: O-$bar_o X-$bar_x   OFF: O-$white_off X-$black_off   Cube: $cube  $turn
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
                && $self->{__score2} >= $self->{__length}) {
                $self->{__over} = BLACK;
            }
        }
        if ($is_crawford) {
            if ($self->{__score1} != $self->{__length} - 1
               && $self->{__score2} != $self->{__length} - 1) {
                   undef $is_crawford;
            }
        }
        push @{$self->{__old_games}}, $old_game;
    }

    if ($self->{__over}) {
        return $self;
    }
    
    my %options = (
        crawford => $is_crawford,
        player1 => $self->{__player1},
        player2 => $self->{__player2},
        autodouble => $self->{__autodouble},
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

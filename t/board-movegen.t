#! /usr/bin/env perl

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

use strict;

use Test;

BEGIN { plan tests => 12 }

use BaldLies::Const qw (:colors);
use BaldLies::Backgammon::Board;
use BaldLies::Backgammon::Move;

my $board = BaldLies::Backgammon::Board->new;
$board->init;

my $moves = $board->generateMoves (3, 1, WHITE);
ok $#{$moves}, 15;

$moves = $board->generateMoves (1, 1, BLACK);
ok $#{$moves}, 41;

my $move = BaldLies::Backgammon::Move->new (3, 4, 24, 20, 13, 10);
ok $board->move ($move, WHITE);

$move = BaldLies::Backgammon::Move->new (3, 3, 19, 22, 19, 22, 17, 20, 17, 20);
ok $board->move ($move, BLACK);

# Illegal move: White dances.
$move = BaldLies::Backgammon::Move->new (3, 5, 13, 8, 13, 10);
ok !$board->move ($move, WHITE);

$board->set ([
  0,
 15, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 
  0, 0, 0, 0, 0,-1,
 -5, 0,-2,-3,-4, 0,
  0
]);

# Illegal move: Black cannot bear off two checkers.
$move = BaldLies::Backgammon::Move->new (6, 4, 19, 25, 21, 25);
ok !$board->move ($move, BLACK);

# This is legal.
$move = BaldLies::Backgammon::Move->new (6, 4, 18, 22, 19, 25);
ok $board->move ($move, BLACK);

$move = BaldLies::Backgammon::Move->new (6, 6, 19, 25, 19, 25, 19, 25, 19, 25);
ok $board->move ($move, BLACK);

# Bear-off with waste.
$move = BaldLies::Backgammon::Move->new (6, 5, 21, 25, 21, 25);
ok $board->move ($move, BLACK);

# White would love to hit here ...
$board->set ([
  0,
 -2, 4, 3, 3, 4, 0,
  0, 0, 0, 0, 0, 0, 
 -2, 0, 0, 0, 0, 0,
 -1, 0, 0, 0, 1,-2,
  0
]);
$move = BaldLies::Backgammon::Move->new (4, 6, 23, 19);
ok !$board->move ($move, WHITE);

# ... but has to run and leave a direct shot.
$board->set ([
  0,
 -2, 4, 3, 3, 4, 0,
  0, 0, 0, 0, 0, 0, 
 -2, 0, 0, 0, 0, 0,
 -1, 0, 0, 0, 1,-2,
  0
]);
$move = BaldLies::Backgammon::Move->new (4, 6, 23, 17);
ok $board->move ($move, WHITE);

# Black could bear-off two checkers but choses to bear-off only one.
$board->set ([
  0,
 11, 3, 0, 0, 1, 0,
  0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0,
  0,-3, 0, 0, 0, 0,
  0
]);
$move = BaldLies::Backgammon::Move->new (5, 1, 5, 4, 4, 0);
ok $board->move ($move, WHITE);

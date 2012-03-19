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

BEGIN { plan tests => 109 }

use BaldLies::Backgammon::Match;
use BaldLies::Const qw (:colors);

my $match = BaldLies::Backgammon::Match->new (player1 => 'Snow White',
                                              player2 => 'Joe Black',
                                              length => 7,
                                              crawford => 1,
                                              autodouble => 1);

ok $match;
ok !$match->over;
my @score = $match->score;
ok $score[0], 0;
ok $score[1], 0;

ok $match->getCurrentGame->cube, 1;
ok $match->do (roll => 0, 3, 3);
ok $match->getCurrentGame->cube, 2;
ok $match->do (roll => 0, 2, 5);
ok !$match->forcedMove;
ok $match->do (move => BLACK, 12, 14, 12, 17);
ok !$match->forcedMove;
ok $match->do (roll => WHITE, 4, 4);
ok $match->do (move => WHITE, 24, 20, 24, 20, 13, 9, 13, 9);
ok $match->do (roll => BLACK, 2, 4);
ok $match->do (move => BLACK, 1, 5, 12, 14);
ok $match->do (roll => WHITE, 3, 1);
ok $match->do (move => WHITE, 8, 5, 6, 5);
ok $match->do (roll => BLACK, 4, 2);
ok $match->do (move => BLACK, 0, 4, 19, 21);
ok $match->do (double => WHITE);
ok $match->getCurrentGame->cube, 2;
ok $match->do (accept => BLACK);
ok $match->getCurrentGame->cube, 4;
ok $match->do (roll => WHITE, 3, 2);
ok $match->do (move => WHITE, 6, 4, 4, 1);
ok $match->do (roll => BLACK, 6, 3);
ok $match->do (move => BLACK, 0, 3);
ok $match->do (roll => WHITE, 6, 5);
ok $match->do (move => WHITE, 9, 3, 8, 3);
ok $match->do (roll => BLACK, 4, 3);
ok $match->do (move => BLACK, 0, 4);
ok $match->do (roll => WHITE, 5, 4);
ok $match->do (move => WHITE, 9, 4, 8, 4);
ok $match->do (roll => BLACK, 4, 1);
ok $match->do (move => BLACK, 0, 1);
ok $match->do (roll => WHITE, 6, 1);
ok $match->do (move => WHITE, 25, 24, 13, 7);
ok $match->do (roll => BLACK, 3, 3);
my $forced_move = $match->forcedMove;
ok $forced_move;
ok $forced_move->isa ('BaldLies::Backgammon::Move');
ok $forced_move->[0], 3;
ok $forced_move->[1], 3;
ok ((scalar @$forced_move), 2);
ok $match->do (move => BLACK);
ok $match->do (roll => WHITE, 4, 4);
ok $match->do (move => WHITE, 13, 9, 13, 9, 9, 5, 5, 1);
ok $match->do (roll => BLACK, 3, 2);
ok $match->do (move => BLACK, 0, 2);
ok $match->do (roll => WHITE, 4, 1);
ok $match->do (move => WHITE, 6, 2, 2, 1);
ok $match->do (roll => BLACK, 5, 6);
ok $match->do (move => BLACK);
ok $match->do (roll => WHITE, 3, 2);
ok $match->do (move => WHITE, 9, 6, 20, 18); 
ok $match->do (roll => BLACK, 5, 6);
ok $match->do (move => BLACK);
ok $match->do (roll => WHITE, 5, 5);
ok $match->do (move => WHITE, 18, 13, 20, 15, 15, 10, 13, 8);
ok $match->do (roll => BLACK, 5, 2);
ok $match->do (move => BLACK, 0, 2);
ok $match->do (roll => WHITE, 3, 1);
ok $match->do (move => WHITE, 6, 5, 5, 2);
ok $match->do (roll => BLACK, 1, 5);
ok $match->do (move => BLACK);
ok $match->do (roll => WHITE, 6, 4);
ok $match->do (move => WHITE, 8, 2, 24, 20);
ok $match->do (roll => BLACK, 5, 2);
ok $match->do (move => BLACK);
ok $match->do (roll => WHITE, 6, 6);
ok $match->do (move => WHITE, 10, 4, 7, 1);
ok $match->do (roll => BLACK, 6, 5);
ok $match->do (move => BLACK);
ok $match->do (roll => WHITE, 4, 1);
ok $match->do (move => WHITE, 20, 16, 16, 15);
ok $match->do (roll => BLACK, 1, 1);
ok $match->do (move => BLACK);
ok $match->do (roll => WHITE, 3, 4);
ok $match->do (move => WHITE, 15, 11, 11, 8);
ok $match->do (roll => BLACK, 2, 5);
ok $match->do (move => BLACK);
ok $match->do (roll => WHITE, 6, 1);
ok $match->do (move => WHITE, 8, 2, 4, 3);
ok $match->do (roll => BLACK, 6, 2);
ok $match->do (move => BLACK);
ok $match->do (roll => WHITE, 6, 6);
ok $match->do (move => WHITE, 5, 0, 6, 0, 5, 0, 6, 0);
ok $match->do (roll => BLACK, 2, 3);
ok $match->do (move => BLACK);
ok $match->do (roll => WHITE, 6, 4);
ok $match->do (move => WHITE, 4, 0, 4, 0);
ok $match->do (roll => BLACK, 2, 2);
ok $match->do (move => BLACK);
ok $match->do (roll => WHITE, 6, 2);
ok $match->do (move => WHITE, 2, 0, 3, 0);
ok $match->do (roll => BLACK, 1, 3);
ok $match->do (move => BLACK);
ok $match->do (roll => WHITE, 1, 3);
ok $match->do (move => WHITE, 3, 0, 3, 2);
ok $match->do (roll => BLACK, 2, 3);
ok $match->do (move => BLACK, 0, 3);
ok $match->do (roll => WHITE, 4, 4);
ok $match->do (move => WHITE, 2, 0, 2, 0, 2, 0, 1, 0);
ok $match->do (roll => BLACK, 2, 2);
ok $match->do (move => BLACK, 3, 5, 5, 7, 0, 2, 2, 4);
ok $match->do (roll => WHITE, 1, 2);
ok $match->do (move => WHITE, 1, 0, 1, 0);
ok $match->over;
@score = $match->score;
ok $score[0], 12;
ok $score[1], 0;

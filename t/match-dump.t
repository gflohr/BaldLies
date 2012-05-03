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

BEGIN { plan tests => 3 }

use BaldLies::Backgammon::Match;
use BaldLies::Const qw (:colors);

my $match = BaldLies::Backgammon::Match->new (player1 => 'Snow White',
                                              player2 => 'Joe Black',
                                              length => 7,
                                              crawford => 1,
                                              autodouble => 1);

$match->do (roll => 0, 3, 3);
$match->do (roll => 0, 2, 5);
$match->do (move => BLACK, 12, 14, 12, 17);
$match->do (roll => WHITE, 4, 4);
$match->do (move => WHITE, 24, 20, 24, 20, 13, 9, 13, 9);
$match->do (roll => BLACK, 2, 4);
$match->do (move => BLACK, 1, 5, 12, 14);
$match->do (roll => WHITE, 3, 1);
$match->do (move => WHITE, 8, 5, 6, 5);
$match->do (roll => BLACK, 4, 2);
$match->do (move => BLACK, 0, 4, 19, 21);
$match->do (double => WHITE);
$match->do (accept => BLACK);
$match->do (roll => WHITE, 3, 2);
$match->do (move => WHITE, 6, 4, 4, 1);
$match->do (roll => BLACK, 6, 3);
$match->do (move => BLACK, 0, 3);
$match->do (roll => WHITE, 6, 5);
$match->do (move => WHITE, 9, 3, 8, 3);
$match->do (roll => BLACK, 4, 3);
$match->do (move => BLACK, 0, 4);
$match->do (roll => WHITE, 5, 4);
$match->do (move => WHITE, 9, 4, 8, 4);
$match->do (roll => BLACK, 4, 1);
$match->do (move => BLACK, 0, 1);
$match->do (roll => WHITE, 6, 1);
$match->do (move => WHITE, 25, 24, 13, 7);
$match->do (roll => BLACK, 3, 3);
$match->do (move => BLACK);
$match->do (roll => WHITE, 4, 4);
$match->do (move => WHITE, 13, 9, 13, 9, 9, 5, 5, 1);
$match->do (roll => BLACK, 3, 2);
$match->do (move => BLACK, 0, 2);
$match->do (roll => WHITE, 4, 1);
$match->do (move => WHITE, 6, 2, 2, 1);
$match->do (roll => BLACK, 5, 6);
$match->do (move => BLACK);
$match->do (roll => WHITE, 3, 2);
$match->do (move => WHITE, 9, 6, 20, 18); 
$match->do (roll => BLACK, 5, 6);
$match->do (move => BLACK);
$match->do (roll => WHITE, 5, 5);
$match->do (move => WHITE, 18, 13, 20, 15, 15, 10, 13, 8);
$match->do (roll => BLACK, 5, 2);
$match->do (move => BLACK, 0, 2);
$match->do (roll => WHITE, 3, 1);
$match->do (move => WHITE, 6, 5, 5, 2);
$match->do (roll => BLACK, 1, 5);
$match->do (move => BLACK);
$match->do (roll => WHITE, 6, 4);
$match->do (move => WHITE, 8, 2, 24, 20);
$match->do (roll => BLACK, 5, 2);
$match->do (move => BLACK);
$match->do (roll => WHITE, 6, 6);
$match->do (move => WHITE, 10, 4, 7, 1);
$match->do (roll => BLACK, 6, 5);
$match->do (move => BLACK);
$match->do (roll => WHITE, 4, 1);
$match->do (move => WHITE, 20, 16, 16, 15);
$match->do (roll => BLACK, 1, 1);
$match->do (move => BLACK);
$match->do (roll => WHITE, 3, 4);
$match->do (move => WHITE, 15, 11, 11, 8);
$match->do (roll => BLACK, 2, 5);
$match->do (move => BLACK);
$match->do (roll => WHITE, 6, 1);
$match->do (move => WHITE, 8, 2, 4, 3);
$match->do (roll => BLACK, 6, 2);
$match->do (move => BLACK);
$match->do (roll => WHITE, 6, 6);
$match->do (move => WHITE, 5, 0, 6, 0, 5, 0, 6, 0);
$match->do (roll => BLACK, 2, 3);
$match->do (move => BLACK);
$match->do (roll => WHITE, 6, 4);
$match->do (move => WHITE, 4, 0, 4, 0);
$match->do (roll => BLACK, 2, 2);
$match->do (move => BLACK);
$match->do (roll => WHITE, 6, 2);
$match->do (move => WHITE, 2, 0, 3, 0);
$match->do (roll => BLACK, 1, 3);
$match->do (move => BLACK);
$match->do (roll => WHITE, 1, 3);
$match->do (move => WHITE, 3, 0, 3, 2);
$match->do (roll => BLACK, 2, 3);
$match->do (move => BLACK, 0, 3);
$match->do (roll => WHITE, 4, 4);
$match->do (move => WHITE, 2, 0, 2, 0, 2, 0, 1, 0);
$match->do (roll => BLACK, 2, 2);
$match->do (move => BLACK, 3, 5, 5, 7, 0, 2, 2, 4);
$match->do (roll => WHITE, 1, 2);

my $copy = BaldLies::Backgammon::Match->newFromDump ($match->dump);

foreach my $style (1 .. 3) {
        my $wanted = $match->board (1);
        my $got = $copy->board (1);
        ok $got, $wanted;
}

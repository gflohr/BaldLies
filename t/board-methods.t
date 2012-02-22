#! /usr/bin/env perl

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

use strict;

use Test;

BEGIN { plan tests => 16 }

use OpenFIBS::Backgammon::Board;
use OpenFIBS::Const qw (:colors);
use OpenFIBS::Backgammon::Move;

my $empty = OpenFIBS::Backgammon::Board->new;
ok 15, $empty->borneOff (BLACK);
ok 15, $empty->borneOff (WHITE);

my $initial = OpenFIBS::Backgammon::Board->init;
ok 0, $initial->borneOff (BLACK);
ok 0, $initial->borneOff (WHITE);

ok $empty->equals ($empty->copy);
ok $initial->equals ($initial->copy);
ok !$empty->equals ($initial);
ok !$initial->equals ($empty);

my $see = $initial->copy;
$see->[6] = -3;
$see->[19] = 2;

ok 2, $see->borneOff (BLACK);
ok 3, $see->borneOff (WHITE);

my $saw = $see->copy->swap;
ok !$see->equals ($saw);
ok 3, $saw->borneOff (BLACK);
ok 2, $saw->borneOff (WHITE);
ok -2, $saw->[6];
ok +3, $saw->[19];

my $move = OpenFIBS::Backgammon::Move->new (4, 3, 
                                            24, 21, 
                                            13, 9);
my $copy = $initial->copy;
$copy->applyMove ($move, WHITE);
my @expect = (
    0,
   -2, 0, 0, 0, 0, +5,
    0, +3, +1, 0, 0, -5,
   +4, 0, 0, 0, -3, 0,
   -5, 0, +1, 0, 0, +1,
    0
);
my $expect = $copy->copy;
@$expect = @expect;
ok $copy->equals ($expect);

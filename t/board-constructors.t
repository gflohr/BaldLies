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

BEGIN { plan tests => 10 }

use BaldLies::Backgammon::Board;

my $empty = BaldLies::Backgammon::Board->new;

ok $empty;
ok 'BaldLies::Backgammon::Board', ref $empty;

my $initial = BaldLies::Backgammon::Board->init;
ok $initial;
ok 'BaldLies::Backgammon::Board', ref $initial;

$initial = BaldLies::Backgammon::Board->new->init;
ok $initial;
ok 'BaldLies::Backgammon::Board', ref $initial;

my $copy = BaldLies::Backgammon::Board->copy ($initial);
ok $copy;
ok 'BaldLies::Backgammon::Board', ref $copy;

$copy = $initial->copy;
ok $copy;
ok 'BaldLies::Backgammon::Board', ref $copy;

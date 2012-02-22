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

BEGIN { plan tests => 10 }

use OpenFIBS::Backgammon::Board;

my $empty = OpenFIBS::Backgammon::Board->new;

ok $empty;
ok 'OpenFIBS::Backgammon::Board', ref $empty;

my $initial = OpenFIBS::Backgammon::Board->init;
ok $initial;
ok 'OpenFIBS::Backgammon::Board', ref $initial;

$initial = OpenFIBS::Backgammon::Board->new->init;
ok $initial;
ok 'OpenFIBS::Backgammon::Board', ref $initial;

my $copy = OpenFIBS::Backgammon::Board->copy ($initial);
ok $copy;
ok 'OpenFIBS::Backgammon::Board', ref $copy;

$copy = $initial->copy;
ok $copy;
ok 'OpenFIBS::Backgammon::Board', ref $copy;

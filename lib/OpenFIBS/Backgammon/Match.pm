#! /bin/false

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

package OpenFIBS::Backgammon::Match;

use strict;

sub new {
    bless {}, shift;
}

1;

=head1 NAME

OpenFIBS::Backgammon::Match - Representation of a backgammon match

=head1 SYNOPSIS

  use OpenFIBS::Backgammon::Match;

=head1 DESCRIPTION

B<OpenFIBS::Backgammon::Match> represents a backgammon match.

=head1 SEE ALSO

perl(1)

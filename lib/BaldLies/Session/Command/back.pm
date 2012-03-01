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

package BaldLies::Session::Command::back;

use strict;

use base qw (BaldLies::Session::Command);

1;

=head1 NAME

BaldLies::Session::Command::back - BaldLies Command `back'

=head1 SYNOPSIS

  use BaldLies::Session::Command::back->new (back => $session, $call);
  
=head1 DESCRIPTION

This plug-in handles the ommand `back'.

=head1 SEE ALSO

BaldLies::Session::Command(3pm), baldlies(1), perl(1)

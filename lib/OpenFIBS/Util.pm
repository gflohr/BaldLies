#! /usr/local/bin/perl -w

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

package OpenFIBS::Util;

use strict;

use base qw (Exporter);

our @EXPORT_OK = qw (empty untaint);

sub empty ($);
sub untaint ($);

sub empty ($) {
    return if defined $_[0] && length $_[0];
    return 1;
}

sub untaint ($) {
    unless ($_[0] =~ /(.*)/) {
        require Carp;
        Carp::croak ("Variable cannot be untainted");
    } else {
        $_[0] = $1;
    }
    
    return $_[0];
}

1;

=head1 NAME

OpenFIBS::Util - Utility Functions for OpenFIBS 

=head1 SYNOPSIS

  use OpenFIBS::Util;

  empty $scalar;

=head1 DESCRIPTION

B<OpenFIBS::Util> defines various utility functions for OpenFIBS.

=head1 FUNCTIONS

=over 4

=item B<empty SCALAR>

Returns true if the B<SCALAR> is undefined or the empty string.

=item B<untaint SCALAR>

Unconditionally launders B<SCALAR> so that it passes Perl's taint checks.

=back

=head1 SEE ALSO

perl(1)


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

our @EXPORT_OK = qw (empty untaint format_time serialize deserialize);

use POSIX qw (strftime);
use MIME::Base64 qw (decode_base64);
use Storable qw (nfreeze thaw);

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

sub format_time {
    my ($when) = @_;
    
    $when ||= time;
    
    return strftime '%a %b %d %H:%M:%S %Y', gmtime $when;
}

sub serialize {
    my ($object) = @_;
    
    my $retval = encode_base64 $object;
    
    $retval =~ s/[^A-Za-z0-9\/+=]//;
    
    return $retval;
}

sub deserialize {
    &MIME::Base64::decode_base64 ();
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

=item B<format_time TIMESTAMP>

Formats B<TIMESTAMP>, expressed as seconds since the epoch, in a way
defined by OpenFIBS.  Example:

    Sat Feb 25 04:59:02 2012

=item B<serialize OBJECT>

Serializes B<OBJECT> into a base-64 encoded string with all whitespace
stripped.

=item B<deserialize SCALAR>

Deserializes B<SCALAR> into a Perl object.  It undoes serialize() and is
currently just a wrapper around MIME::Base64::decode_base64().

=back

=head1 SEE ALSO

perl(1)


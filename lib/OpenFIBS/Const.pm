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

package OpenFIBS::Const;

use strict;

use base qw (Exporter);

our %EXPORT_TAGS = (colors => [qw (BLACK WHITE)],
                    log_levels => [qw (LOG_ERROR LOG_WARN LOG_NOTICE
                                       LOG_INFO LOG_DEBUG)],
                    comm => [qw (
                        COMM_WELCOME
                        COMM_ACK
                        COMM_NAME_AVAILABLE
                        COMM_CREATE_USER
                        COMM_AUTHENTICATE
                        MSG_ACK
                        MSG_LOGIN
                        MSG_LOGOUT
                        MSG_KICK_OUT
                        )]
                    );
our @EXPORT_OK = (
    @{$EXPORT_TAGS{colors}},
    @{$EXPORT_TAGS{log_levels}},
    @{$EXPORT_TAGS{comm}},
);

use constant BLACK => -1;
use constant WHITE => +1;

use constant LOG_ERROR  => 0;
use constant LOG_WARN   => 1;
use constant LOG_NOTICE => 2;
use constant LOG_INFO   => 3;
use constant LOG_DEBUG  => 4;

use constant COMM_WELCOME        => 0;
use constant COMM_NAME_AVAILABLE => 1;
use constant COMM_CREATE_USER    => 2;
use constant COMM_AUTHENTICATE   => 3;

use constant MSG_ACK             => 0;
use constant MSG_LOGIN           => 1;
use constant MSG_LOGOUT          => 2;
use constant MSG_KICK_OUT        => 3;

1;

=head1 NAME

OpenFIBS::Const - Constants for OpenFIBS 

=head1 SYNOPSIS

  use OpenFIBS::Const;

=head1 DESCRIPTION

B<OpenFIBS::Const> defines various constants used in OpenFIBS.

=head1 CONSTANTS

All constants are grouped into export tags.  You can, for example, import
constants for backgammon colors like this:

    use OpenFIBS::Const qw (:colors)

=head2 :colors

=over 4

=item B<OpenFIBS::BLACK()>

Black.  This constant is defined as -1.  Instead of the constant you can use
any negative value for black throughout this application.

=item B<OpenFIBS::WHITE()>

White.  This constant is defined as +1.  Instead of the constant you can use
any positive value for white throughout this application.

=back

=head2 :log_levels

=over 4

=item B<OpenFIBS::LOG_ERROR()>

Defined as 0.

=item B<OpenFIBS::LOG_WARN()>

Defined as 1.

=item B<OpenFIBS::LOG_NOTICE()>

Defined as 2.

=item B<OpenFIBS::LOG_INFO()>

Defined as 3.

=item B<OpenFIBS::LOG_DEBUG()>

Defined as 4.

=back

=head1 SEE ALSO

perl(1)


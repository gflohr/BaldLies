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

package BaldLies::Const;

use strict;

use base qw (Exporter);

our %EXPORT_TAGS = (colors => [qw (BLACK WHITE)],
                    log_levels => [qw (LOG_ERROR LOG_WARN LOG_NOTICE
                                       LOG_INFO LOG_DEBUG)],
                    telnet => [qw (TELNET_ECHO_DO   TELNET_ECHO_DONT
                                   TELNET_ECHO_WILL TELNET_ECHO_WONT)],
                    );
our @EXPORT_OK = (
    @{$EXPORT_TAGS{colors}},
    @{$EXPORT_TAGS{log_levels}},
    @{$EXPORT_TAGS{telnet}},
);

use constant BLACK => -1;
use constant WHITE => +1;

use constant LOG_ERROR  => 0;
use constant LOG_WARN   => 1;
use constant LOG_NOTICE => 2;
use constant LOG_INFO   => 3;
use constant LOG_DEBUG  => 4;

use constant TELNET_ECHO_WILL => "\xff\xfb\x01";
use constant TELNET_ECHO_WONT => "\xff\xfc\x01";
use constant TELNET_ECHO_DO   => "\xff\xfd\x01";
use constant TELNET_ECHO_DONT => "\xff\xfe\x01";

1;

=head1 NAME

BaldLies::Const - Constants for BaldLies 

=head1 SYNOPSIS

  use BaldLies::Const;

=head1 DESCRIPTION

B<BaldLies::Const> defines various constants used in BaldLies.

=head1 CONSTANTS

All constants are grouped into export tags.  You can, for example, import
constants for backgammon colors like this:

    use BaldLies::Const qw (:colors)

=head2 :colors

=over 4

=item B<BaldLies::BLACK()>

Black.  This constant is defined as -1.  Instead of the constant you can use
any negative value for black throughout this application.

=item B<BaldLies::WHITE()>

White.  This constant is defined as +1.  Instead of the constant you can use
any positive value for white throughout this application.

=back

=head2 :log_levels

=over 4

=item B<BaldLies::LOG_ERROR()>

Defined as 0.

=item B<BaldLies::LOG_WARN()>

Defined as 1.

=item B<BaldLies::LOG_NOTICE()>

Defined as 2.

=item B<BaldLies::LOG_INFO()>

Defined as 3.

=item B<BaldLies::LOG_DEBUG()>

Defined as 4.

=back

=head1 SEE ALSO

perl(1)


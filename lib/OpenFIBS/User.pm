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

package OpenFIBS::User;

use strict;

use OpenFIBS::Util qw (empty);

sub new {
    my ($class, @args) = @_;

    my %self;
    @self{qw (id name password address admin last_login last_logout 
              last_host experience rating boardstyle linelength pagelength
              redoubles sortwho timezone allowpip autoboard autodouble 
              automove bell crawford double greedy moreboards moves notify
              ratings ready report silent telnet wrap)}
        = @args;
    
    # The first user is automatically superuser.

    bless \%self, $class;
}

1;

=head1 NAME

OpenFIBS::User - OpenFIBS User Abstraction Class

=head1 SYNOPSIS

  use OpenFIBS::User;
  
  OpenFIBS::User->new (@properties);
  
=head1 DESCRIPTION

B<OpenFIBS::User> is the abstraction for a user currently logged in.
The class is internal.

=head1 SEE ALSO

OpenFIBS::Server(3pm), openfibs(1), perl(1)

###! /bin/false

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

package OpenFIBS::Database::SQLite;

use strict;

use base qw (OpenFIBS::Database);

sub _initBackend {
    my ($self) = @_;
    
    my $dbh = $self->{_dbh};
    
    $dbh->do ("PRAGMA foreign_keys = ON");
    
    return $self;
}

1;

=head1 NAME

OpenFIBS::Database::SQLite - SQLite Backend

=head1 SYNOPSIS

  use OpenFIBS::Database::SQLite;
  
  OpenFIBS::Database::SQLite->new ($dsn);

=head1 DESCRIPTION

B<OpenFIBS::Database::SQLite> is the default database backend for OpenFIBS.

The class is only for internal use.

=head1 SEE ALSO

OpenFIBS::SQLite(3pm), openfibs(1), perl(1)


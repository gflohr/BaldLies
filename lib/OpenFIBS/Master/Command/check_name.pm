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

package OpenFIBS::Master::Command::check_name;

use strict;

use base qw (OpenFIBS::Master::Command);

sub execute {
    my ($self, $fd, $name) = @_;
    
    my $master = $self->{_master};
    
    my $logger = $master->getLogger;
    $logger->debug ("Check availability of name `$name'.");

    my $available = $master->getDatabase->existsUser ($name) ? 0 : 1;

    $master->queueResponse ($fd, name_available => $available);

    return $self;    
}
    
1;

=head1 NAME

OpenFIBS::Master::Command::check_name - OpenFIBS Command `check_name'

=head1 SYNOPSIS

  use OpenFIBS::Master::Command::check_name->new ($master);
  
=head1 DESCRIPTION

This plug-in handles the command `check_name'.

=head1 SEE ALSO

OpenFIBS::Master::Command(3pm), openfibs(1), perl(1)

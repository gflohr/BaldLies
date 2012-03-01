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

package OpenFIBS::Master::Command::hello;

use strict;

use base qw (OpenFIBS::Master::Command);

sub execute {
    my ($self, $fd, $payload) = @_;
    
    my $master = $self->{_master};
    
    my ($secret, $pid) = split / /, $payload, 3;
    
    my $logger = $master->getLogger;
    $logger->debug ("Got welcome from pid $pid.");

    unless ($secret eq $master->getSecret) {
        return $master->dropConnection ("Child pid $pid sent wrong secret.");
    }

    $master->queueResponse ($fd, 'welcome');

    return $self;
}

1;

=head1 NAME

OpenFIBS::Master::Command::welcome - OpenFIBS Command `welcome'

=head1 SYNOPSIS

  use OpenFIBS::Master::Command::welcome->new ($master);
  
=head1 DESCRIPTION

This plug-in handles the master command `welcome'.

=head1 SEE ALSO

OpenFIBS::Master::Command(3pm), openfibs(1), perl(1)

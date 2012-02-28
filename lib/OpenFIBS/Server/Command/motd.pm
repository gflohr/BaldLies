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

package OpenFIBS::Server::Command::motd;

use strict;

use base qw (OpenFIBS::Server::Command);

sub execute {
    my ($self) = @_;
    
    my $session = $self->{_session};
    
    my $motd = $session->getMottoOfTheDay;
    my $clip = $session->getClip;
    
    $session->reply ("3\n") if $clip;
    $session->reply ($motd);
    $session->reply ("4\n") if $clip;
    
    return $self;
}

1;

=head1 NAME

OpenFIBS::Server::Command::motd - OpenFIBS Command `motd'

=head1 SYNOPSIS

  use OpenFIBS::Server::Command::motd->new (motd => $session, $call);
  
=head1 DESCRIPTION

This plug-in handles the ommand `motd'.

=head1 SEE ALSO

OpenFIBS::Server::Command(3pm), openfibs(1), perl(1)

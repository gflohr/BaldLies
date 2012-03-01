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

package OpenFIBS::Session::Message::welcome;

use strict;

use base qw (OpenFIBS::Session::Message);

sub execute {
    my ($self, $session, $payload) = @_;
    
    my $logger = $session->getLogger;
    $logger->debug ("Got welcome back from master.");
    
    $session->setReady (1);

    return $self;
}

1;

=head1 NAME

OpenFIBS::Session::Message::welcome - OpenFIBS Message `welcome'

=head1 SYNOPSIS

  use OpenFIBS::Session::Message::welcome->new;
  
=head1 DESCRIPTION

This plug-in handles the master message `welcome'.

=head1 SEE ALSO

OpenFIBS::Session::Message(3pm), openfibs(1), perl(1)

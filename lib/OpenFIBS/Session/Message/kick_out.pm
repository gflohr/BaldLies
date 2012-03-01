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

package OpenFIBS::Session::Message::kick_out;

use strict;

use base qw (OpenFIBS::Session::Message);

use OpenFIBS::User;

sub execute {
    my ($self, $session, $msg) = @_;
    
    my $logger = $session->getLogger;

    $session->quit (1);    
    $session->reply ("\n** $msg\n", 1);
    
    $logger->info ("Kicked out: $msg");
    
    return $self;
}

1;

=head1 NAME

OpenFIBS::Session::Message::kick_out - OpenFIBS Message `kick_out'

=head1 SYNOPSIS

  use OpenFIBS::Session::Message::kick_out->new;
  
=head1 DESCRIPTION

This plug-in handles the master message `kick_out'.

=head1 SEE ALSO

OpenFIBS::Session::Message(3pm), openfibs(1), perl(1)

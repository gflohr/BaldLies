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

package OpenFIBS::Session::Message::logout;

use strict;

use base qw (OpenFIBS::Session::Message);

use OpenFIBS::User;

sub execute {
    my ($self, $session, $name) = @_;
    
    $session->removeUser ($name);
    
    my $user = $session->getUser;
        
    if ($user->{notify}) {
        my $prefix;
        
        if ($self->{__clip}) {
            $prefix = "8 $name ";
        } else {
            $prefix = "\n";
        }
        $session->reply ("$prefix$name drops connection.\n");
    }
        
    return $self;
}

1;

=head1 NAME

OpenFIBS::Session::Message::logout - OpenFIBS Message `logout'

=head1 SYNOPSIS

  use OpenFIBS::Session::Message::logout->new;
  
=head1 DESCRIPTION

This plug-in handles the master message `logout'.

=head1 SEE ALSO

OpenFIBS::Session::Message(3pm), openfibs(1), perl(1)

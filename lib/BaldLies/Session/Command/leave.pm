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

package BaldLies::Session::Command::leave;

use strict;

use base qw (BaldLies::Session::Command);

sub execute {
    my ($self, $payload) = @_;
    
    my $session = $self->{_session};

    my $user = $session->getUser;
    
    if (!$user->{match}) {
        $session->reply ("** Error: No one to leave.\n");
        return $self;
    }
    
    delete $user->{match};
    
    $session->reply ("** You terminated the game. The game was saved.\n");
    $session->sendMaster ('leave');
    
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Command::leave - BaldLies Command `leave'

=head1 SYNOPSIS

  use BaldLies::Session::Command::leave->new (leave => $session, $call);
  
=head1 DESCRIPTION

This plug-in handles the ommand `leave'.

=head1 SEE ALSO

BaldLies::Session::Command(3pm), baldlies(1), perl(1)

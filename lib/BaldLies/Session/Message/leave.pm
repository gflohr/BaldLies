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

package BaldLies::Session::Message::leave;

use strict;

use base qw (BaldLies::Session::Message);

use BaldLies::User;

sub execute {
    my ($self, $session, $payload) = @_;    

    my ($quitter, $victim) = split / /, $payload;
    
    my $user = $session->getUser;
    if ($victim eq $user->{name}) {
        $session->reply ("\n** Player $quitter has left the game. The game was"
                         . " saved.\n");
        delete $user->{playing} 
            if exists $user->{playing} && $quitter eq $user->{playing};
    } elsif ($user->{notify}) {
        $session->reply ("$quitter has left the game with $victim.\n");
    }

    my $users = $session->getUsers;
    $user = $users->{$quitter};
    if ($user && $user->{playing} && $victim eq $user->{playing}) {
        delete $user->{playing};
    }
    $user = $users->{$victim};
    if ($user && $user->{playing} && $quitter eq $user->{playing}) {
        delete $user->{playing};
    }
    
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Message::leave - BaldLies Message `leave'

=head1 SYNOPSIS

  use BaldLies::Session::Message::leave->new;
  
=head1 DESCRIPTION

This plug-in handles the master message `leave'.

=head1 SEE ALSO

BaldLies::Session::Message(3pm), baldlies(1), perl(1)

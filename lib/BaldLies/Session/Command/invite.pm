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

package BaldLies::Session::Command::invite;

use strict;

use base qw (BaldLies::Session::Command);

use BaldLies::Util qw (empty);

sub execute {
    my ($self, $payload) = @_;
    
    my $session = $self->{_session};
    
    my ($who, $length) = split / /, $payload, 2;
    
    if (empty $who) {
        $session->reply ("** invite who?\n");
        return $self;
    }
    
    my $users = $session->getUsers;
    if (!exists $users->{$who}) {
        $session->reply ("** There is no one called $who\n");
        return $self;        
    }
    
    my $invitee = $users->{$who};
    if (!$invitee->{ready}) {
        $session->reply ("** $who is refusing games.\n");
        return $self;        
    }
    
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Command::invite - BaldLies Command `invite'

=head1 SYNOPSIS

  use BaldLies::Session::Command::invite->new (invite => $session, $call);
  
=head1 DESCRIPTION

This plug-in handles the ommand `invite'.

=head1 SEE ALSO

BaldLies::Session::Command(3pm), baldlies(1), perl(1)

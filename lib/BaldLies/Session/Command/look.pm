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

package BaldLies::Session::Command::look;

use strict;

use base qw (BaldLies::Session::Command);

use BaldLies::Util qw (empty);

sub execute {
    my ($self, $who) = @_;
    
    my $session = $self->{_session};
    my $user = $session->getUser;

    if (empty $who) {
        $session->reply ("** Look at who?\n");
        return $self;
    } elsif ($user->{name} eq $who) {
        $session->reply ("You look great.\n");
        return $self;
    }
    
    my $users = $session->getUsers;
    if (!exists $users->{$who}) {
        $session->reply ("** There is no one called $who.\n");
        return $self;
    }
    
    my $watchee = $users->{$who};
    if (0) {
        # Blinded?
        $session->reply ("$who doesn't want you to look.\n");
        return $self;
    }
    
    if (empty $watchee->{playing}) {
        $session->reply ("$who is not playing.\n");
        return $self;
    }
    
    if (!exists $users->{$watchee->{playing}}) {
        $session->reply ("$who is not playing.\n");
        return $self;
    }
    my $opponent = $users->{$watchee->{playing}};
    if (0) {
        # Blinded?
        $session->reply ("$watchee->{playing} doesn't want you to look.\n");
        return $self;
    }

    $session->sendMaster (look => $who);
    
    return $self;    
}

1;

=head1 NAME

BaldLies::Session::Command::look - BaldLies Command `look'

=head1 SYNOPSIS

  use BaldLies::Session::Command::look->new (look => $session, $call);
  
=head1 DESCRIPTION

This plug-in handles the ommand `look'.

=head1 SEE ALSO

BaldLies::Session::Command(3pm), baldlies(1), perl(1)

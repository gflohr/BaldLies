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

package BaldLies::Session::Command::join;

use strict;

use base qw (BaldLies::Session::Command);

use BaldLies::Util qw (empty);

# There is no point in checking, whether we have a valid invitation.  The
# inviter may already have issued another invitation.
#
# In order to do a check for necessary but still not sufficient prerequisites,
# the master server would have to send us an additional message for cancelling
# the invitation.  The optimistic/pessimistic approach saves us communication.
# We either hope that our user will never reply to the invitation or that
# it is still valid.
#
# We therefore only do checks, that we can do for free because we have all
# required information, and we are sure that the information is still valid.
sub execute {
    my ($self, $payload) = @_;
    
    my $session = $self->{_session};
    
    my $user = $session->getUser;
    my $match = $user->{match};

    if ($match) {
        $session->sendMaster ('rejoin');
        return $self;
    }
    
    $payload = '' if !defined $payload;
    my ($opponent) = split / /, $payload;

    if (empty $opponent) {
        $session->reply ("** Error: Join who?\n");
        return $self;
    }
    
    # It does NOT matter whether we toggled our ready state to unavailable
    # if we want to join.  But we can check whether our user is already
    # playing with somebody else.
    # FIXME! What would FIBS reply here?
    if ($user->{playing}) {
        $session->reply ("** $opponent didn't invite you.\n");
        return $self;
    }

    # This is what FIBS replies, when you try to join yourself.
    if ($opponent eq $user->{name}) {
        $session->reply ("** $opponent didn't invite you.\n");
        return $self;
    }

    my $users = $session->getUsers;
    if (!exists $users->{$opponent}) {
        $session->reply ("** Error: can't find player $opponent\n");
        return $self;
    }
    
    # FIXME! What happens if a user issues an invitation, then toggles the
    # ready state, and then the invitee accepts the invitation?  We ignore
    # the state change.
    
    $session->sendMaster (join => $opponent);
    
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Command::join - BaldLies Command `join'

=head1 SYNOPSIS

  use BaldLies::Session::Command::join->new (join => $session, $call);
  
=head1 DESCRIPTION

This plug-in handles the ommand `join'.

=head1 SEE ALSO

BaldLies::Session::Command(3pm), baldlies(1), perl(1)

=cut

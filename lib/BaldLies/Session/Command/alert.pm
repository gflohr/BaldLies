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

package BaldLies::Session::Command::alert;

use strict;

use base qw (BaldLies::Session::Command);

use BaldLies::Util qw (empty);

sub execute {
    my ($self, $payload) = @_;
    
    my $session = $self->{_session};
    
    my ($recipient, $message) = split / /, $payload, 2;

    if (empty $recipient) {
        $session->reply ("** Tell whom?\n");
        return $self;
    }
    if (empty $message) {
        $session->reply ("** Tell $recipient what?\n");
        return $self;
    }
    
    my $users = $session->getUsers;
    if (!exists $users->{$recipient}) {
        # Try to match.
        my @candidates;
        my $l = length $recipient;
        foreach my $name (keys %$users) {
            push @candidates, $name if $recipient eq substr $name, 0, $l;
        }
        if (!@candidates) {
            $session->reply ("** There is no one called $recipient\n");
            return $self;
        }
        if (@candidates != 1) {
            my $reply = "Ambigous name: Try one of: ";
            $reply .= join ', ', @candidates;
            $reply .= "\n** There is no one called $recipient\n";
            $session->reply ($reply);
            return $self;
        }
        $recipient = $candidates[0];
    }
    
    # TODO! Check whether we have gagged recipient or recipient has gagged us.
    
    my $user = $session->getUser;
    if ($recipient eq $user->{name}) {
        $session->reply ("You say to yourself: $message\n");
        return $self;
    }
    
    $session->clipTell ($recipient, 20, $user->{name}, $message);
    $session->clipReply (16, $recipient, $message);
    
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Command::alert - BaldLies Command `alert'

=head1 SYNOPSIS

  use BaldLies::Session::Command::alert->new (alert => $session, $call);
  
=head1 DESCRIPTION

This plug-in handles the ommand `alert'.

=head1 SEE ALSO

BaldLies::Session::Command(3pm), baldlies(1), perl(1)

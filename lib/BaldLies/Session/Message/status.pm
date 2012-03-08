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

package BaldLies::Session::Message::status;

use strict;

use base qw (BaldLies::Session::Message);

sub execute {
    my ($self, $session, $payload) = @_;

    my $logger = $session->getLogger;
    
    my ($name, $opponent, $watching, $ready, $away, $rating, $experience,
        $idle, $login, $hostname, $client, $email) = split / /, $payload;
    $logger->debug ("Got status change for user `$name'\n");

    my $users = $session->getUsers;
    if (!exists $users->{$name}) {
        $logger->warning ("Status change for unknown user `$name'.\n");
        return $self;
    }

    my $user = $users->{$name};
    if ('-' ne $opponent) {
        $user->{opponent} = $opponent;
    } else {
        delete $user->{opponent};
    }
    if ('-' ne $watching) {
        $user->{watching} = $watching;
    } else {
        delete $user->{watching};
    }
    $user->{ready} = $ready;
    
    if ($session->getClip) {
        $session->reply ("5 $payload\n6\n");
    }
        
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Message::status - BaldLies Message `status'

=head1 SYNOPSIS

  use BaldLies::Session::Message::status->new;
  
=head1 DESCRIPTION

This plug-in handles the master message `status'.

=head1 SEE ALSO

BaldLies::Session::Message(3pm), baldlies(1), perl(1)

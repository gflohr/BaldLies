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

use BaldLies::Util qw (empty);

sub execute {
    my ($self, $session, $payload) = @_;

    my $logger = $session->getLogger;
    
    my ($name, $playing, $watching, $ready, $away, $rating, $experience,
        $idle, $login, $hostname, $client, $email) = split / /, $payload;
    $logger->debug ("Got status change for user `$name'\n");

    my $users = $session->getUsers;
    if (!exists $users->{$name}) {
        $logger->warning ("Status change for unknown user `$name'.\n");
        return $self;
    }

    my $user = $users->{$name};
    my $myself = $session->getUser;
    
    my $is_about_me = $user == $myself;

    my $start_playing;
    my $stop_playing;
    if ('-' ne $playing) {
        if (empty $user->{playing}
            || $user->{playing} ne $playing) {
            $start_playing = $playing;
        }
        $user->{playing} = $playing;
    } else {
        $stop_playing = delete $user->{playing};
        delete $user->{match};
    }

    my $start_watching;
    my $stop_watching;
    if ('-' ne $watching) {
        if (empty $user->{watching}
            || $user->{watching} ne $watching) {
            $start_watching = $watching;
        }
        $user->{watching} = $watching;
    } else {
        $stop_watching = delete $user->{watching};
    }
    
    $user->{ready} = $ready;
    $user->{rating} = $rating;
    $user->{experience} = $experience;
    
    if ($session->getClip) {
        $session->reply ("5 $payload\n6\n");
    }
     
    if ($is_about_me && !empty $stop_watching) {
        $session->reply ("You stop watching $stop_watching.\n");
    } elsif ($is_about_me && !empty $start_watching) {
        my $message = "You are now watching $start_watching.\n";
        my $other = $session->getUsers->{$start_watching};
        if (empty $other->{playing}) {
            $message .= "$watching is not doing anything interesting.\n";
        }
        $session->reply ($message);
    }
    
    if (!empty $start_watching && $start_watching eq $myself->{name}) {
        $session->reply ("$name is watching you.\n");
    }
    if (!empty $stop_watching && $stop_watching eq $myself->{name}) {
        $session->reply ("$name stops watching you.\n");
    }
    if (!empty $start_watching && !empty $myself->{playing}
             && $start_watching eq $myself->{playing}) {
        $session->reply ("$name starts watching $watching.\n");
    }
    if (!empty $stop_watching && !empty $myself->{playing}
             && $stop_watching eq $myself->{playing}) {
        $session->reply ("$name stops watching $stop_watching.\n");
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

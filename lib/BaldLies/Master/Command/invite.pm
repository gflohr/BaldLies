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

package BaldLies::Master::Command::invite;

use strict;

use base qw (BaldLies::Master::Command);

use BaldLies::Util qw (empty);

sub execute {
    my ($self, $fd, $payload) = @_;
    
    my $master = $self->{_master};
    
    my ($who, $length) = split / /, $payload;
    
    my $logger = $master->getLogger;
    my $invitee = $master->getUser ($who);
    if (!$invitee) {
        $logger->warning ("Got invite update for non-existing user `$who'.");
        return $self;
    }

    if (!empty $invitee->{playing}) {
        $master->queueResponse ($fd, reply =>
                                "$who is already playing with someone else.");
        return $self;
    }

    my $inviter = $master->getUserFromDescriptor ($fd);
    if (!$inviter) {
        $logger->warning ("Inviter has vanished.");
        return $self;
    }

    # Add more checks here for example if the user in question has too many
    # saved games.

    $length ||= 0;
    
    # Record this invitation both ways.  This is necessary for cleaning up,
    # when one of the two parties drops connection.
    my $inviters = $master->getInviters;
    $inviters->{$inviter->{name}} = [$who => $length];

    my $invitees = $master->getInvitees;
    $invitees->{$who}->{$inviter->{name}} = 1;

    my $db = $master->getDatabase;
    my $saved = $db->loadMatch ($inviter->{id}, $invitee->{id});

    if ($length > 0) {
        # FIXME! Return an error, when these users already have a saved match.
        $master->queueResponseForUser ($inviter->{name}, 'reply',
                                       "** You invited $who to a $length"
                                       . " point match.");
        $master->queueResponseForUser ($who, 'echo_e',
                                       "$inviter->{name} wants to play a"
                                       . " $length point match with you.\\n"
                                       . "Type 'join $inviter->{name}'"
                                       . " to accept.");
    } elsif ($length < 0) {
        $master->queueResponseForUser ($inviter->{name}, 'reply',
                                       "** You invited $who to an unlimited"
                                       . " match.");
        $master->queueResponseForUser ($who, 'echo_e',
                                       "$inviter->{name} wants to play an"
                                       . " unlimited match with you.\\n"
                                       . "Type 'join $inviter->{name}'"
                                       . " to accept.");
        # FIXME! If there is a saved match with that user, warn that it will
        # be deleted.
    } else {
        if (!$saved) {
            $master->queueResponseForUser ($inviter->{name}, 'reply',
                                           "** There is no saved match with"
                                           . " $invitee->{name}. Please give"
                                           . " a match length.");
            return;
        }
        $master->queueResponseForUser ($inviter->{name}, 'reply',
                                       "** You invited $who to resume a saved"
                                       . " match.");
        $master->queueResponseForUser ($who, 'echo_e',
                                       "$inviter->{name} wants to resume a"
                                       . " saved match with you.\\n"
                                       . "Type 'join $inviter->{name}'"
                                       . " to accept.");
    }
    
    # FIXME! Will we get the rawwho before or after the confirmations?
    if (!$inviter->{ready}) {
        my $db = $master->getDatabase;
        $db->toggleReady ($inviter->{name});
        $inviter->{ready} = 1;
        # FIXME! Will the user get a message about the toggle change?
        # $master->queueResponse ($fd, toggle => 'ready');
        my $rawwho = $inviter->rawwho;
        foreach my $login ($master->getLoggedIn) {
            $master->queueResponseForUser ($login, status => $rawwho);
        }
    }
    
    return $self;
}

1;

=head1 NAME

BaldLies::Master::Command::invite - BaldLies Command `invite'

=head1 SYNOPSIS

  use BaldLies::Master::Command::invite->new ($master);
  
=head1 DESCRIPTION

This plug-in handles the master command `invite'.

=head1 SEE ALSO

BaldLies::Master::Command(3pm), baldlies(1), perl(1)

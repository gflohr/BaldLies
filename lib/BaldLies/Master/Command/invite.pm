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
    
    my $inviter = $master->getUserFromDescriptor ($fd);
    if (!$inviter) {
        $logger->warning ("Inviter has vanished.");
        return $self;
    }
    
    # TODO: Additional checks!

    my $match_spec = $length > 0 ? "a $length point" : "an unlimited";
    
    $master->queueResponseForUser ($inviter->{name}, 'echo',
                                   "** You invited $who to $match_spec match.");
    $master->queueResponseForUser ($who, 'echo',
                                   "$inviter->{name} wants to  play"
                                   . " $match_spec match with you.\nType join"
                                   . " '$inviter->{name} to accept.");
    $master->queueResponseForUser ($who, 'echo',
                                   "$inviter->{name} wants to  play"
                                   . " $match_spec match with you.");
    $master->queueResponseForUser ($who, 'echo',
                                   "Type join '$inviter->{name} to accept.");
    $master->queueResponseForUser ($who, 'echo',
                                   "** FIXME! Telnet prompt is wrong here!");
    
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

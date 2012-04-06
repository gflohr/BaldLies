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

package BaldLies::Master::Command::join;

use strict;

use base qw (BaldLies::Master::Command);

use MIME::Base64 qw (encode_base64);
use Storable qw (nfreeze);

sub execute {
    my ($self, $fd, $who) = @_;
    
    my $master = $self->{_master};
    
    my $logger = $master->getLogger;

    $logger->debug ("Checking invitation from `$who'.");
    
    my $inviter = $master->getUser ($who);
    if (!$inviter) {
        $master->queueResponse ($fd, reply => 
                                "** Error: can't find player $who");
        return $self;
    }
    
    my $inviters = $master->getInviters;
    my $invitation = $inviters->{$who};
    if (!$invitation) {
        $master->queueResponse ($fd, reply => 
                                "** $who didn't invite you.");
        return $self;
    }
    
    my $invitee = $master->getUserFromDescriptor ($fd);
    my ($other_invitee, $length) = @$invitation;
    if ($other_invitee ne $invitee->{name}) {
        $master->queueResponse ($fd, reply => 
                                "** $who didn't invite you.");
        return $self;
    }

    if ($inviter->{playing}) {
        $master->queueResponse ($fd, reply => 
                                "** $who is already playing with someone else.");
        return $self;
    }

    if (!$inviter->{ready}) {
        $master->queueResponse ($fd, reply => 
                                "** $who is refusing games.");
        return $self;
    }

    if ($invitee->{playing}) {
        $master->queueResponse ($fd, reply => 
                                "** $who didn't invite you.");
        return $self;
    }

    delete $inviters->{$who};

    my $invitees = $master->getInvitees;
    delete $invitees->{$invitee->{name}};

    my $database = $master->getDatabase;

    if ($length) {
        $database->createMatch ($inviter->{id}, $invitee->{id}, $length)
            or return;
    }
    my $options = $database->loadMatch ($inviter->{id},
                                        $invitee->{id});
    unless ($options) {
        $logger->error ("Freshly created match vanished!");
    }
    
    my $old_moves = $database->loadMoves ($inviter->{id}, $invitee->{id});
    $options->{old_moves} = $old_moves;

    my $data = encode_base64 nfreeze $options;
    $data =~ s/[^A-Za-z0-9\/+=]//g;
    
    $inviter->{playing} = $invitee->{name};
    $invitee->{playing} = $inviter->{name};

    my $report = 'start';
    if (@$old_moves || $options->{score1} || $options->{score2}) {
        $report = 'resume';
    }
    
    foreach my $name ($master->getLoggedIn) {
        if ($name eq $inviter->{name}) {
            $logger->debug ("report joined $invitee->{name}");
            $master->queueResponseForUser ($name, report =>
                                           'joined', $invitee->{name}, $data);
        } elsif ($name eq $invitee->{name}) {
            $logger->debug ("report invited $inviter->{name}");
            $master->queueResponseForUser ($name, report =>
                                           'invited', $inviter->{name}, $data);
        } else {
            $master->queueResponseForUser ($name, report =>
                                           $report, $inviter->{name},
                                           $invitee->{name},
                                           $options->{length});
        }
    }
    
    return $self;
}

1;

=head1 NAME

BaldLies::Master::Command::join - BaldLies Command `join'

=head1 SYNOPSIS

  use BaldLies::Master::Command::join->new ($master);
  
=head1 DESCRIPTION

This plug-in handles the master command `join'.

=head1 SEE ALSO

BaldLies::Master::Command(3pm), baldlies(1), perl(1)

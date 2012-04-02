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
    
    my %options = (
        crawford => 0,
        autodouble => 0
    );
    $options{crawford} = 0
        if $length > 0 && $inviter->{crawford} && $invitee->{crawford};
    $options{autodouble} = 1
        if $inviter->{autodouble} && $invitee->{autodouble};
    
    my $database = $master->getDatabase;
# TODO! Create match in database, but after rest is done.
#    $database->createMatch ($who, $invitee->{name}, $length, %options);
    
    $inviter->{playing} = $invitee->{name};
    $invitee->{playing} = $inviter->{name};
    
    foreach my $name ($master->getLoggedIn) {
        if ($name eq $inviter->{name}) {
            $master->queueResponseForUser ($name, report =>
                                           'joined', $invitee->{name},
                                           $length,
                                           $options{crawford},
                                           $options{redoubles});
        } elsif ($name eq $invitee->{name}) {
            $master->queueResponseForUser ($name, report =>
                                           'invited', $inviter->{name},
                                           $length,
                                           $options{crawford},
                                           $options{redoubles});
        } else {
            $master->queueResponseForUser ($name, report =>
                                           'start', $inviter->{name},
                                           $invitee->{name},
                                           $length);
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

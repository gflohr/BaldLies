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
    
    my $opponent = $master->getUser ($who);
    if (!$opponent) {
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
    
    my $this_invitee = $master->getUserFromDescriptor ($fd);
    my ($other_invitee, $length) = @$invitation;
    if ($other_invitee ne $this_invitee->{name}) {
        $master->queueResponse ($fd, reply => 
                                "** $who didn't invite you.");
        return $self;
    }

    my $this_inviter = $master->getUser ($who);
    if ($this_inviter) {
        $logger->debug ("Inviter `$who' has vanished.");
        return $self;
    }

    if ($this_inviter->{playing}) {
        $master->queueResponse ($fd, reply => 
                                "** $who is already playing with someone else.");
        return $self;
    }

    if (!$this_inviter->{ready}) {
        $master->queueResponse ($fd, reply => 
                                "** $who is refusing games.");
        return $self;
    }

    if ($this_invitee->{playing}) {
        $master->queueResponse ($fd, reply => 
                                "** $who didn't invite you.");
        return $self;
    }

    if (!$this_inviter->{ready}) {
        $master->queueResponse ($fd, reply => 
                                "** $who didn't in invite you.");
        return $self;
    }

    delete $inviters->{$who};

    my $invitees = $master->getInvitees;
    delete $invitees->{$this_invitee->{name}};
    
    my %options = (
        crawford => 0,
        autodouble => 0
    );
    $options{crawford} = 0
        if $length > 0 && $this_inviter->{crawford} && $this_invitee->{crawford};
    $options{autodouble} = 1
        if $this_inviter->{autodouble} && $this_invitee->{autodouble};
    
    my $database = $master->getDatabase;
    $database->createMatch ($who, $this_invitee->{name}, $length, %options);
    
    $this_inviter->{playing} = $this_invitee->{name};
    $this_invitee->{playing} = $this_inviter->{name};
    
    foreach my $name ($master->getLoggedIn) {
        if ($name eq $this_inviter->{name}) {
            $master->queueResponseForUser ($name, report =>
                                           'joined', $this_invitee->{name},
                                           length);
        } elsif ($name eq $this_invitee->{name}) {
            $master->queueResponseForUser ($name, report =>
                                           'invited', $this_inviter->{name},
                                           length);
        } else {
            $master->queueResponseForUser ($name, report =>
                                           'start', $this_inviter->{name},
                                           $this_invitee->{name},
                                           length);
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

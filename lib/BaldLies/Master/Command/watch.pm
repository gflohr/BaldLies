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

package BaldLies::Master::Command::watch;

use strict;

use base qw (BaldLies::Master::Command);

use BaldLies::Util qw (empty);

sub execute {
    my ($self, $fd, $who) = @_;
    
    my $master = $self->{_master};
    
    my $logger = $master->getLogger;
    
    my $dirty;
    
    my $user = $master->getUserFromDescriptor ($fd);
    
    if (!empty $user->{watching}) {
        delete $user->{watching};
        $dirty = 1;
    }
    
    my $other = $master->getUser ($who);
    if (!$other) {
        $master->queueResponse ($fd, reply => 
                                "** There is no one called $who.");
        $master->broadcastUserStatus ($user->{name}) if $dirty;

        return $self;
    }

    # Prepare for blinding.
    if (0) {
        $master->queueResponse ($fd, reply => 
                                "** $who doesn't want you to watch.");
        $master->broadcastUserStatus ($user->{name}) if $dirty;

        return $self;
    }
    
    if (!empty $other->{playing} && 0) {
        $master->queueResponse ($fd, reply => 
                                "** $other->{playing} doesn't want you to"
                                . " watch.");
        $master->broadcastUserStatus ($user->{name}) if $dirty;

        return $self;
    }

    $master->addWatching ($user, $who);
        
    return $self;    
}

1;

=head1 NAME

BaldLies::Master::Command::watch - BaldLies Command `watch'

=head1 SYNOPSIS

  use BaldLies::Master::Command::watch->new ($master);
  
=head1 DESCRIPTION

This plug-in handles the command `watch'.

=head1 SEE ALSO

BaldLies::Master::Command(3pm), baldlies(1), perl(1)

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

package BaldLies::Master::Command::play;

use strict;

use base qw (BaldLies::Master::Command);

use BaldLies::Util qw (empty);

sub execute {
    my ($self, $fd, $payload) = @_;
    
    my $master = $self->{_master};
    
    my $logger = $master->getLogger;

    my $user = $master->getUserFromDescriptor ($fd);
    if (!$user) {
        $logger->info ("Match play action from unknown descriptor $fd.");
        return $self;
    }
    
    $logger->debug ("Match play action from `$user->{name}': $payload.");

    my $opponent = $user->{playing};
    if (empty $opponent) {
        $logger->info ("$user->{name}'s opponent has vanished.");
        return $self;
    }

    my $user2 = $master->getUser ($opponent);
    if (!$user2) {
        $logger->error ("$user->{name}'s opponent $opponent has vanished.");
        return $self;
    }

    my ($position, $action, $color, @arguments) = split / /, $payload;
    my $db_action;
    if ('take' eq $action) {
        $db_action = 'accept';
    } elsif ('drop' eq $action) {
        $db_action = 'reject';
    } else {
        $db_action = $action;
    }
    
    my $db = $master->getDatabase;
    $logger->debug ("Adding move to database: $color $action @arguments");
    unless ($db->addMove ($user->{id}, $user2->{id},
                          $position, $db_action, $color, @arguments)) {
        $logger->error ("Error adding move $color $action @arguments");
        return $self;
    }
    
    $master->queueResponse ($fd, play => $action, $color, @arguments);
    $master->queueResponseForUser ($opponent, play => $action, $color, 
                                   @arguments);

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

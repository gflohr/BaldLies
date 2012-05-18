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

package BaldLies::Master::Command::leave;

use strict;

use base qw (BaldLies::Master::Command);

use BaldLies::Util qw (empty);

sub execute {
    my ($self, $fd, $payload) = @_;
    
    my $master = $self->{_master};
    
    my $logger = $master->getLogger;

    my $user = $master->getUserFromDescriptor ($fd);
    if (!$user) {
        $logger->info ("Leave message from unknown descriptor $fd.");
        return $self;
    }
    $logger->debug ("Leave message from `$user->{name}'.");
    
    my $playing = delete $user->{playing};
    my $opponent = $master->getUser ($playing) if !empty $playing;
    if (!$opponent) {
        $logger->info ("Opponent `$user->{playing}' has vanished before leave.");
        return $self;
    }
    delete $opponent->{playing};
    $master->removePending ($user->{name});
    $master->removePending ($user->{playing});
    
    $master->getDatabase->activateMatch ($user->{id}, $opponent->{id}, 0);
    
    my $user_info = $user->rawwho;
    my $opponent_info = $opponent->rawwho;
    
    foreach my $login ($master->getLoggedIn) {
        $master->queueResponseForUser ($login, status => $user_info);
        $master->queueResponseForUser ($login, status => $opponent_info);
        if ($login ne $user->{name}) {
            $master->queueResponseForUser ($login, leave => $user->{name},
                                           $opponent->{name});
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

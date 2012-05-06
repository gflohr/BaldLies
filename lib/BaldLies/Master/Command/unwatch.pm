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

package BaldLies::Master::Command::unwatch;

use strict;

use base qw (BaldLies::Master::Command);

use BaldLies::Util qw (empty);

sub execute {
    my ($self, $fd) = @_;
    
    my $master = $self->{_master};
    
    my $logger = $master->getLogger;
    
    my $dirty;
    
    my $user = $master->getUserFromDescriptor ($fd);
    if (empty $user->{watching}) {
        $master->queueResponse ($fd, reply =>
                                "** You're not watching.");
        return $self;
    }
    
    $master->queueResponse ($fd, reply =>
                            "You stop watching $user->{watching}.");
    $master->removeWatching ($user, $user->{watching});
        
    return $self;    
}

1;

=head1 NAME

BaldLies::Master::Command::unwatch - BaldLies Command `unwatch'

=head1 SYNOPSIS

  use BaldLies::Master::Command::unwatch->new ($master);
  
=head1 DESCRIPTION

This plug-in handles the command `unwatch'.

=head1 SEE ALSO

BaldLies::Master::Command(3pm), baldlies(1), perl(1)

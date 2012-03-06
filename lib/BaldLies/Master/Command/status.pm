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

package BaldLies::Master::Command::status;

use strict;

use base qw (BaldLies::Master::Command);

sub execute {
    my ($self, $fd, $payload) = @_;
    
    my $master = $self->{_master};
    
    my ($name, $opponent, $watching, $ready, $away, $rating, $experience,
        $idle, $login, $hostname, $client, $email) = split / /, $payload;
    
    my $logger = $master->getLogger;
    my $user = $master->getUser ($name);
    if (!$user) {
        $logger->warning ("Got status update for non-existing user `$name'.");
        return $self;
    }
    
    if ('-' ne $opponent) {
        $user->{opponent} = $opponent;
    } else {
        delete $user->{opponent};
    }
    if ('-' ne $watching) {
        $user->{watching} = $watching;
    } else {
        delete $user->{watching};
    }
    foreach my $login ($master->getLoggedIn) {
        $master->queueResponseForUser ($login, clip_tell => "5 $payload");
        $master->queueResponseForUser ($login, clip_tell => "6");
    }
    
    return $self;
}

1;

=head1 NAME

BaldLies::Master::Command::welcome - BaldLies Command `welcome'

=head1 SYNOPSIS

  use BaldLies::Master::Command::welcome->new ($master);
  
=head1 DESCRIPTION

This plug-in handles the master command `welcome'.

=head1 SEE ALSO

BaldLies::Master::Command(3pm), baldlies(1), perl(1)

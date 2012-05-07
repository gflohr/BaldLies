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

package BaldLies::Master::Command::rejoin;

use strict;

use base qw (BaldLies::Master::Command);

use MIME::Base64 qw (encode_base64);
use Storable qw (nfreeze);

use BaldLies::Backgammon::Match;

sub execute {
    my ($self, $fd, $payload) = @_;
    
    my $master = $self->{_master};
    
    my $logger = $master->getLogger;

    my @players = split / /, $payload;
    
    $logger->debug ("$players[0] and $players[1] continue their match.");
    
    $logger->debug ("report continue $players[0]");
    $master->queueResponseForUser ($players[0], report =>
                                   'continue', @players);
    $logger->debug ("report continue $players[1]");
    $master->queueResponseForUser ($players[1], report =>
                                   'continue', @players);
    
    my $user1 = $master->getUser ($players[0]);
    my $user2 = $master->getUser ($players[1]);
    
    my @watchers;
    push @watchers, $master->getWatchers ($user1->{name});
    push @watchers, $master->getWatchers ($user2->{name});
    
    return $self unless @watchers;
    
    # Our internal API requires a dummy match.
    my $match = BaldLies::Backgammon::Match->new (player1 => $players[0],
                                                  player2 => $players[1]);
    my $dump = $match->dump;

    foreach my $watcher (@watchers) {
        $master->queueResponseForUser ($watcher, watch => $dump, 'start');
    }

    return $self;
}

1;

=head1 NAME

BaldLies::Master::Command::rejoin - BaldLies Command `rejoin'

=head1 SYNOPSIS

  use BaldLies::Master::Command::rejoin->new ($master);
  
=head1 DESCRIPTION

This plug-in handles the master command `rejoin'.

=head1 SEE ALSO

BaldLies::Master::Command(3pm), baldlies(1), perl(1)

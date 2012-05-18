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

package BaldLies::Master::Command::end_of_game;

use strict;

use base qw (BaldLies::Master::Command);

use BaldLies::Util qw (empty);

sub execute {
    my ($self, $fd, $payload) = @_;
    
    my $master = $self->{_master};
    
    my $logger = $master->getLogger;

    my ($score1, $score2, $post_crawford) = split / /, $payload;
    
    my $white_user = $master->getUserFromDescriptor ($fd);
    unless ($white_user) {
        $logger->error ("Got end-of-match from vanished user ($fd).");
        return $self;
    }
    
    my $player1 = $white_user->{name};
    my $player2 = $white_user->{playing};
    if (empty $player2) {
        $logger->error ("end_of_game from user `$player1' but no match.");
        return $self;
    }
    
    my $black_user = $master->getUser ($player2);
    if (!$black_user) {
        $logger->error ("Opponent `$player2' of `$player1' has vanished.");
        return $self;
    }
    
    $logger->debug ("End of game $player1-$player2, score: $score1-$score2.");
    $master->addPending ($player1, $player2);
    
    my $database = $master->getDatabase;
    my $id1 = $white_user->{id};
    my $id2 = $black_user->{id};

    $database->nextGame ($id1, $id2, $score1, $score2, $post_crawford);
    
    return $self;
}

1;

=head1 NAME

BaldLies::Master::Command::end_of_game - BaldLies Command `end_of_game'

=head1 SYNOPSIS

  use BaldLies::Master::Command::end_of_game->new ($master);
  
=head1 DESCRIPTION

This plug-in handles the master command `end_of_game'.

=head1 SEE ALSO

BaldLies::Master::Command(3pm), baldlies(1), perl(1)

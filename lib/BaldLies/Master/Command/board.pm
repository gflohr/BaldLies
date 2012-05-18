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

package BaldLies::Master::Command::board;

use strict;

use base qw (BaldLies::Master::Command);

use BaldLies::Backgammon::Match;

use BaldLies::Util qw (empty);

sub execute {
    my ($self, $fd) = @_;
    
    my $master = $self->{_master};
    
    my $logger = $master->getLogger;

    my $user = $master->getUserFromDescriptor ($fd);
    unless ($user) {
        $logger->error ("Board request from vanished user $fd.");
        return $self;
    }
    my $who = $user->{watching};
    if (empty $who) {
        $logger->error ("Board request for not watching user `$user->{name}'.");
        return $self;
    }

    my $watchee = $master->getUser ($who);
    if (!$watchee) {
        $logger->error ("User `$watchee' watched by `$user->{name}' has"
                        . " vanished.");
        return $self;
    }
   
    if (empty $watchee->{playing}) {
        $master->queueResponse ($fd, reply => "$who is not playing.");
        return $self;
    }
    
    my $opponent = $master->getUser ($watchee->{playing});
    if (!$opponent) {
        $master->queueResponse ($fd, reply => "$who is not playing.");
        return $self;
    }

    my $database = $master->getDatabase;
    
    my $dump = $database->loadPosition ($watchee->{id}, $opponent->{id});
    unless ($dump) {
        # This is not correct.  Actually, we have hit a race condition, and
        # we are at the start of a game.  But it is unlikely if not
        # impossible that this can ever happen.
        $master->queueResponse ($fd, reply => "$who is not playing.");
        return $self;
    }
    
    my $match = BaldLies::Backgammon::Match->newFromDump ($dump);
    my $reverse = $who ne $match->player1;
    my $reply = $match->board ($user->{boardstyle}, $reverse);
    $reply =~ s/^[ \t\r\n]+//;
    $reply =~ s/[ \t\r\n]+$//;
    $reply =~ s/\n/\\n/g;
    $master->queueResponse ($fd, echo_e => $reply);
    
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

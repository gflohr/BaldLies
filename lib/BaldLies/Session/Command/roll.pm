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

package BaldLies::Session::Command::roll;

use strict;

use base qw (BaldLies::Session::Command);

use BaldLies::Const qw (:colors);
use BaldLies::Util qw (empty);

sub execute {
    my ($self, $payload) = @_;
    
    my $session = $self->{_session};
    my $user = $session->getUser;

    if (!empty $user->{watching} || !$user->{match}) {
        $session->reply ("** You're not playing.\n");
        return $self;
    }

    my $die1 = 1 + int rand 6;
    my $die2 = 1 + int rand 6;
    
    my $match = $user->{match};
    my $color;
    if ($user->{name} eq $match->player2) {
        $color = BLACK;
    } else {
        $color = WHITE;
    }    
    
    my $logger = $session->getLogger;
    $logger->debug ("Match action ($user->{name}): move $color $die1 $die2");
    eval { $match->do (roll => $color, $die1, $die2) };
    if ($@) {
        chomp $@;
        $session->reply ("** $@\n");
        return $self;
    }
    
    $session->reply ("You roll $die1 and $die2.\n", 1);
    
    my $board = $match->dump;
    $session->sendMaster (play => $board, roll => $color, $die1, $die2);
    
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Command::roll - BaldLies Command `roll'

=head1 SYNOPSIS

  use BaldLies::Session::Command::roll->new (roll => $session, $call);
  
=head1 DESCRIPTION

This plug-in handles the ommand `roll'.

=head1 SEE ALSO

BaldLies::Session::Command(3pm), baldlies(1), perl(1)

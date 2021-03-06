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

package BaldLies::Session::Command::accept;

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
    
    my $match = $user->{match};
    if (!$match->getTurn) {
        $session->reply ("** $user->{playing} didn't double or resign.\n");
        return $self;
    }

    my $color;
    if ($user->{name} eq $match->player2) {
        $color = BLACK;
    } else {
        $color = WHITE;
    }    
    
    my $logger = $session->getLogger;
    $logger->debug ("Match action ($user->{name}): accept $color");
    my $action = $match->getResignation * $color < 0 ? 'accept' : 'take';
    eval { $match->do (accept => $color) };
    if ($@) {
        chomp $@;
        $session->reply ("** $@\n");
        return $self;
    }
    
    my $board = $match->dump;
    $session->sendMaster (play => $board, $action, $color);
    
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Command::accept - BaldLies Command `accept'

=head1 SYNOPSIS

  use BaldLies::Session::Command::accept->new (accept => $session, $call);
  
=head1 DESCRIPTION

This plug-in handles the ommand `accept'.

=head1 SEE ALSO

BaldLies::Session::Command(3pm), baldlies(1), perl(1)

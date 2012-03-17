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

package BaldLies::Session::Message::play;

use strict;

use base qw (BaldLies::Session::Message);

use BaldLies::User;

sub execute {
    my ($self, $session, $payload) = @_;
    
    my $logger = $session->getLogger;
    my ($player1, $player2, $action, @data) = split / /, $payload;
    
    $self->{__session} = $session;
    my $user = $session->getUser;
    $self->{__user} = $user;
    my $name = $user->{name};
    my $method;
    if ($player1 eq $name) {
        $method = '__handleMy' . ucfirst $action;
    } elsif ($player2 eq $name) {
        $method = '__handleHer' . ucfirst $action;
    } else {
        $method = '__handleTheir' . ucfirst $action;
    }
    
    return $self->$method (@data);
}

sub __handleMyTell {
    my ($self, $what, @data) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};
    
    if ('start' eq $what && 'game' eq $data[0]) {
        my $opponent = $match->player2;
        $session->reply ("\nStarting a new game with $opponent.\n");
        return $self;
    } 
    
    $logger->fatal ("Unknown play message $what.");
    
    return $self;
}

sub __handleHerTell {
    my ($self, $what, @data) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};
    
    if ('start' eq $what && 'game' eq $data[0]) {
        my $opponent = $match->player1;
        $session->reply ("\nStarting a new game with $opponent.\n");
        return $self;
    } 
    
    $logger->fatal ("Unknown play message $what.");
    
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Message::play - BaldLies Message `play'

=head1 SYNOPSIS

  use BaldLies::Session::Message::play->new;
  
=head1 DESCRIPTION

This plug-in handles the master message `play'.

=head1 SEE ALSO

BaldLies::Session::Message(3pm), baldlies(1), perl(1)

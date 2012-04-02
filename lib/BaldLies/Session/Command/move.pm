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

package BaldLies::Session::Command::move;

use strict;

use base qw (BaldLies::Session::Command);

use BaldLies::Util qw (empty);
use BaldLies::Const qw (:colors);

sub execute {
    my ($self, $payload) = @_;
    
    my $session = $self->{_session};
    my $user = $session->getUser;
    
    if (!empty $user->{watching} || !$user->{match}) {
        $session->reply ("** You're not playing.\n");
        return $self;
    }
    
    my $match = $user->{match};
    my $color;
    if ($user->{name} eq $match->player2) {
        $color = BLACK;
    } else {
        $color = WHITE;
    }    
    
    my $home = $color > 0 ? 0 : 25;
    my $bar = 25 - $home;
    
    my @pairs = split /[ \t]+/, $payload;
    my @points;
    foreach my $pair (@pairs) {
        my ($from, $to) = split /-/, $pair;
        return $self->__invalidMove if !defined $to;

        if ('bar' eq $from) {
            $from = $bar;
        } elsif ('home' eq $from) {
            $from = $home;
        } elsif ('off' eq $from) {
            $from = $home;
        } elsif ($from !~ /^(?:[1-9]|1[0-9]|2[0-4])$/) {
            return $self->__invalidMove;
        }
        if ('bar' eq $to) {
            $to = $bar;
        } elsif ('home' eq $to) {
            $to = $home;
        } elsif ('off' eq $to) {
            $to = $home;
        } elsif ($to !~ /^(?:[1-9]|1[0-9]|2[0-4])$/) {
            return $self->__invalidMove;
        }
        push @points, $from, $to;
    }
    
    my $logger = $session->getLogger;
    $logger->debug ("Match action ($user->{name}: move $color @points");
    eval { $match->do (move => $color, @points) };
    if ($@) {
        chomp $@;
        $session->reply ("** $@\n");
    }
    
    $session->sendMaster (play => 'move', $color, @points);
    
    return $self;
}

sub __invalidMove {
    my ($self) = @_;
    
    $self->{_session}->reply ("** first move: legal words are 'bar', 'home',"
                              . " 'off', 'b', 'h' and 'o'.\n");
    
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Command::move - BaldLies Command `move'

=head1 SYNOPSIS

  use BaldLies::Session::Command::move->new (move => $session, $call);
  
=head1 DESCRIPTION

This plug-in handles the ommand `move'.

=head1 SEE ALSO

BaldLies::Session::Command(3pm), baldlies(1), perl(1)

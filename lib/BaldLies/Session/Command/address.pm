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

package BaldLies::Session::Command::address;

use strict;

use base qw (BaldLies::Session::Command);

use BaldLies::Util qw (empty);

sub execute {
    my ($self, $payload) = @_;
    
    my $session = $self->{_session};
    my $clip = $session->getClip;

    # FIBS allows trailing garbage.
    my ($address) = split / /, $payload;
    
    if (empty $address) {
        $session->reply ("** You didn't give your address.\n");
        return $self;
    }
    
    if (60 < length $address) {
        $session->reply ("** Your address is too long.\n");
        return $self;
    }
    
    # Hard to tell what is actually allowed by FIBS.
    if ($address !~ /^[-_a-zA-Z0-9@\/\.]+$/) {
        $session->reply ("** '$address' is not an email address.\n");
        return $self;
    }
    
    $session->sendMaster ("address $address\n");
    
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Command::address - BaldLies Command `address'

=head1 SYNOPSIS

  use BaldLies::Session::Command::address->new (address => $session, $call);
  
=head1 DESCRIPTION

This plug-in handles the ommand `address'.

=head1 SEE ALSO

BaldLies::Session::Command(3pm), baldlies(1), perl(1)

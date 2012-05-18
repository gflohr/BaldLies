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

package BaldLies::Session::Command::shout;

use strict;

use base qw (BaldLies::Session::Command);

sub execute {
    my ($self, $payload) = @_;
    
    my $session = $self->{_session};

    my $user = $session->getUser;
    if ($user->{silent}) {
        $session->reply ("** Please type 'toggle silent' again before you"
                         . " shout.\n");
        return $self;
    }
 
    $session->clipBroadcast ($user->{name}, 13, $user->{name}, $payload);
    $session->clipReply (17, "$payload\n");
 
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Command::shout - BaldLies Command `shout'

=head1 SYNOPSIS

  use BaldLies::Session::Command::shout->new (shout => $session, $call);
  
=head1 DESCRIPTION

This plug-in handles the ommand `shout'.

=head1 SEE ALSO

BaldLies::Session::Command(3pm), baldlies(1), perl(1)

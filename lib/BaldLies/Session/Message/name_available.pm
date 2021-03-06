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

package BaldLies::Session::Message::name_available;

use strict;

use base qw (BaldLies::Session::Message);

use BaldLies::Const qw (:telnet);

sub execute {
    my ($self, $session, $available) = @_;
    
    my $logger = $session->getLogger;
    my $name = $session->getLogin;
    
    if (!$available) {
        $logger->debug ("Name `$name' is not available.");
        $session->setState ('name');
        $session->reply ("** Please use another name. '$name' is already"
                         . " used by someone else.\n");
        return $self;
    }
    
    $logger->debug ("Name `$name' is available.");
    $session->reply (<<EOF, 1);
Your name will be $name
Type in no password and hit Enter/Return if you want to change it now.
EOF

    $session->reply (TELNET_ECHO_WILL, 1);
    $session->reply ("Please give your password: ", 1);
    
    $session->setState ('password1');
    
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Message::authenticate - BaldLies Message `authenticate'

=head1 SYNOPSIS

  use BaldLies::Session::Message::authenticate->new;
  
=head1 DESCRIPTION

This plug-in handles the master message `authenticate'.

=head1 SEE ALSO

BaldLies::Session::Message(3pm), baldlies(1), perl(1)

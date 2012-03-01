#! /bin/false

# This file is part of OpenFIBS.
# Copyright (C) 2012 Guido Flohr, http://guido-flohr.net/.
#
# OpenFIBS is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# OpenFIBS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with OpenFIBS.  If not, see <http://www.gnu.org/licenses/>.

package OpenFIBS::Session::Message::user_created;

use strict;

use base qw (OpenFIBS::Session::Message);

sub execute {
    my ($self, $session, $created) = @_;

    my $logger = $session->getLogger;

    my $name = $session->getLogin;
            
    if (!$created) {
        $logger->debug ("Name `$name' is not available.");
        $session->setState ('name');
        $session->reply ("** Please use another name. '$name' is already"
                         . " used by someone else.\n");
        return $self;
    }
    
    $logger->notice ("User `$name' account created.");
    my $welcome = <<EOF;
You are registered.
Type 'help beginner' to get started.
EOF
    chomp $welcome;
    $session->reply ($welcome, 1);

    my $password = $session->stealPassword;
    $session->login ($name, $password);
    
    return $self;
}

1;

=head1 NAME

OpenFIBS::Session::Message::user_created - OpenFIBS Message `user_created'

=head1 SYNOPSIS

  use OpenFIBS::Session::Message::user_created->new;
  
=head1 DESCRIPTION

This plug-in handles the master message `user_created'.

=head1 SEE ALSO

OpenFIBS::Session::Message(3pm), openfibs(1), perl(1)

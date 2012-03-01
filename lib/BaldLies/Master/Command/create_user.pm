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

package BaldLies::Master::Command::create_user;

use strict;

use base qw (BaldLies::Master::Command);

use Storable qw (nfreeze);
use MIME::Base64 qw (encode_base64);

sub execute {
    my ($self, $fd, $payload) = @_;
    
    my $master = $self->{_master};
    
    # Password may contain spaces.
    my ($name, $ip, $password) = split / /, $payload, 4;
    
    my $logger = $master->getLogger;
    
    my $status;
    if ($master->getDatabase->createUser ($name, $password, $ip)) {
        $logger->notice ("Created user `$name', connected from $ip.");
        $status = 1;
    } else {
        $logger->notice ("Creating user `$name', connected from $ip, failed.");
        $status = 0;
    }
    
    $master->queueResponse ($fd, user_created => $name, $status);

    return $self;
}
    
1;

=head1 NAME

BaldLies::Master::Command::create_user - BaldLies Command `create_user'

=head1 SYNOPSIS

  use BaldLies::Master::Command::create_user->new ($master);
  
=head1 DESCRIPTION

This plug-in handles the command `create_user'.

=head1 SEE ALSO

BaldLies::Master::Command(3pm), baldlies(1), perl(1)

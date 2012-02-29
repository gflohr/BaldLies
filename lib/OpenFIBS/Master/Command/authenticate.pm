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

package OpenFIBS::Master::Command::authenticate;

use strict;

use base qw (OpenFIBS::Master::Command);

use Storable qw (nfreeze);
use MIME::Base64 qw (encode_base64);

use OpenFIBS::Const qw (:comm);

sub execute {
    my ($self, $fd, $payload) = @_;
    
    my $master = $self->{_master};
    
    # Password may contain spaces.
    my ($seqno, $name, $ip, $client, $password) = split / /, $payload, 5;
    
    my $logger = $master->getLogger;
    $logger->debug ("Authenticating `$name' from $ip.");
    
    my $data = $master->getDatabase->getUser ($name, $password, $ip);
    if (!$data) {
        $master->queueResponse ($fd, MSG_ACK, $seqno, 0);
        return $self;
    }

    my $users = $master->getUsers;
    if (exists $users->{$name}) {
        # Kick out users that log in twice.  FIBS allows parallel logins
        # but this would be hard to implement for us.  Maybe, FIBS does
        # this only to allow parallel registrations.  The warning
        # "You are already logged in" for guest logins kind of suggests
        # that.
        my $other_fd = $users->{$name};
        my $other_rec = $master->getClientRecord ($other_fd);
        my $other_host = $other_rec->{user}->{last_host};

        $master->queueResponse ($other_fd, MSG_KICK_OUT,
                                "You just logged in a second time from"
                                . " $other_host, terminating this session.");
    }
    
    my $user = OpenFIBS::User->new (@$data);
    $user->{client} = $client;
    $user->{login} = time;
    $user->{ip} = $ip;
    $self->{__sockets}->{$fd}->{user} = $user;
    $self->{__users}->{$name} = $fd; 
    
    my %users;
    foreach my $login (keys %{$self->{__users}}) {
        my $rec = $self->{__sockets}->{$self->{__users}->{$login}};
        my $user = $rec->{user};
        $users{$user->{name}} = $user;
    }
    $payload = encode_base64 nfreeze \%users;
    $payload =~ s/[^A-Za-z0-9\/+=]//g;
        
    $master->queueResponse ($fd, MSG_ACK, $seqno, 1, $payload);
    
    $master->broadcast (MSG_LOGIN, $name, @$data);
    
    return $self;    
}
    
1;

=head1 NAME

OpenFIBS::Master::Command::authenticate - OpenFIBS Command `authenticate'

=head1 SYNOPSIS

  use OpenFIBS::Master::Command::authenticate->new ($master);
  
=head1 DESCRIPTION

This plug-in handles the command `authenticate'.

=head1 SEE ALSO

OpenFIBS::Master::Command(3pm), openfibs(1), perl(1)

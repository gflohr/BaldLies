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

package BaldLies::Master::Command::authenticate;

use strict;

use base qw (BaldLies::Master::Command);

use Storable qw (nfreeze);
use MIME::Base64 qw (encode_base64);

sub execute {
    my ($self, $fd, $payload) = @_;
    
    my $master = $self->{_master};
    
    # Password may contain spaces.
    my ($name, $ip, $client, $password) = split / /, $payload, 4;
    
    my $logger = $master->getLogger;
    $logger->debug ("Authenticating `$name' from $ip.");
    
    my $data = $master->getDatabase->getUser ($name, $password, $ip);
    if (!$data) {
        $master->queueResponse ($fd, authenticated => 0);
        return $self;
    }

    my %logins = map { $_ => 1 } $master->getLoggedIn;
    if (exists $logins{$name}) {
        # Kick out users that log in twice.  FIBS allows parallel logins
        # but this would be hard to implement for us.  Maybe, FIBS does
        # this only to allow parallel registrations.  The warning
        # "You are already logged in" for guest logins kind of suggests
        # that.
        my $other_user = $master->getUser ($name);
        my $other_host = $other_user->{last_host};

        $master->tell ($name, kick_out =>
                              "You just logged in a second time from"
                              . " $other_host, terminating this session.");
    }
    
    my $user = BaldLies::User->new (@$data);
    $user->{client} = $client;
    $user->{login} = time;
    $user->{ip} = $ip;
    $master->setClientUser ($fd, $user);
    
    my %users = ($user->{name} => $user);
    foreach my $login (keys %logins) {
        my $user = $master->getUser ($login);
        $users{$user->{name}} = $user;
    }
    $payload = encode_base64 nfreeze \%users;
    $payload =~ s/[^A-Za-z0-9\/+=]//g;
        
    $master->queueResponse ($fd, authenticated => 1, $payload);
    
    $master->broadcast (login => $name, @$data);
    
    return $self;    
}
    
1;

=head1 NAME

BaldLies::Master::Command::authenticate - BaldLies Command `authenticate'

=head1 SYNOPSIS

  use BaldLies::Master::Command::authenticate->new ($master);
  
=head1 DESCRIPTION

This plug-in handles the command `authenticate'.

=head1 SEE ALSO

BaldLies::Master::Command(3pm), baldlies(1), perl(1)

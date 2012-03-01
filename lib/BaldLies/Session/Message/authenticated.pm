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

package BaldLies::Session::Message::authenticated;

use strict;

use base qw (BaldLies::Session::Message);

use MIME::Base64 qw (decode_base64);
use Storable qw (thaw);

use BaldLies::Const qw (:telnet);
use BaldLies::Util qw (format_time);

sub execute {
    my ($self, $session, $payload) = @_;
    
    my $logger = $session->getLogger;
    
    my ($status, $packed) = split / /, $payload;
    
    if (!$status) {
        $session->reinit;
        $logger->debug ("Authentication failed");
        $session->reply (TELNET_ECHO_WONT, 1);
        $session->reply ("\nlogin: ", 1);
        
        return $self;
    }
    
    my $last_state = $session->getState;
    $session->setState ('logged_in');
    
    # No error checking here.  This will fail if the data is not transmitted
    # correctly.
    my $users = thaw decode_base64 $packed;
    $session->setUsers ($users);
    my $user = $users->{$session->getLogin}->copy;
    $session->setUser ($user);
    
    my $ip = $session->getIP;
    $logger->debug ("User $user->{name} logged in from $ip.");
    
    my $last_host = $user->{last_host} 
        ? "  from $user->{last_host}" : '';
    
    if ($session->getClip) {
        $session->reply ("1 $user->{name} $user->{last_host}\n");
        my $own_info = join ' ', @{$user}{
            qw (allowpip autoboard autodouble automove away bell crawford 
                double experience greedy moreboards moves notify rating ratings 
                ready redoubles report silent timezone)
        };
        $session->reply ("2 $own_info\n");
        $session->motd;
    } else {
        my $last_login = format_time ($user->{last_login} ?
                                      $user->{last_login} : time);
        if ('pwprompt' eq $last_state) {
            $session->reply (<<EOF, 1);
** User $user->{name} authenticated.
** Last login: $last_login$last_host
EOF
            $session->reply ("@{[TELNET_ECHO_WONT]}");
            $session->motd;
        } else {
            $session->reply ("@{[TELNET_ECHO_WONT]}\n");
        }
    }
    
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

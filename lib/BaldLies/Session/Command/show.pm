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

package BaldLies::Session::Command::show;

use strict;

use base qw (BaldLies::Session::Command);

use BaldLies::Util qw (empty);

sub execute {
    my ($self, $payload) = @_;
    
    my $session = $self->{_session};

    if (empty $payload) {
        $session->reply ("** show what?\n");
        return $self;
    }
    
    my ($what, $argument) = split / +/, $payload;
    
    if ('saved' eq $what || 'games' eq $what) {
        $session->sendMaster (show => $what);
    } elsif ('savedcount' eq $what) {
        if (empty $argument) {
            $session->sendMaster (show => 'savedcount');
        } else {
            $session->sendMaster (show => 'savedcount', $argument);
        }
    } elsif ('watchers' eq $what) {
        return $self->__showWatchers;
    } elsif ('max' eq $what) {
        $session->reply ("max_logins is 999999 (maximum: 999999)\n");
        return $self;
    } else {
        $session->reply ("** Don't know how to show $what\n");
        return $self;
    }

    return $self;
}

sub __showWatchers {
    my ($self) = @_;
    
    my $session = $self->{_session};

    my $users = $session->getUsers;

    my %watchers;
    while (my ($name, $user) = each %$users) {
        next if empty $user->{watching};
        
        $watchers{$name} = $user->{watching};
    }
    
    if (!%watchers) {
        $session->reply ("Watching players: none.\n");
        return $self;
    }
    
    my $msg = "Watching players:\n";
    while (my ($watcher, $watchee) = each %watchers) {
        $msg .= "$watcher is watching $watchee.\n";
    }
    
    $session->reply ($msg);
    
    return $self;    
}

1;

=head1 NAME

BaldLies::Session::Command::show - BaldLies Command `show'

=head1 SYNOPSIS

  use BaldLies::Session::Command::show->new (show => $session, $call);
  
=head1 DESCRIPTION

This plug-in handles the ommand `show'.

=head1 SEE ALSO

BaldLies::Session::Command(3pm), baldlies(1), perl(1)

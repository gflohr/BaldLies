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

package BaldLies::Session::Message::toggle;

use strict;

use base qw (BaldLies::Session::Message);

my @toggles = qw (allowpip autoboard automove bell crawford
                  moreboards notify ratings ready
                  report silent telnet wrap);
my %toggles = map { $_ => 1 } @toggles;

sub execute {
    my ($self, $session, $variable) = @_;

    my $logger = $session->getLogger;

    if (!exists $toggles{$variable}) {
        $logger->error ("Got unknown toggle `$variable' from master.");
        return $self;
    }
    
    my $user = $session->getUser;
    if ($user->{$variable}) {
        $user->{$variable} = 0;
    } else {
        $user->{$variable} = 1;
    }
    
    my $method = '__showToggle' . ucfirst $variable;
    my $reply = '** ' . $self->$method ($user->{$variable}) . "\n";
    $session->reply ($reply);
 
    if ('ready' eq $variable) {
        my $rawwho = $user->rawwho;
        $session->sendMaster (status => $rawwho);
    }
        
    return $self;
}

sub __showToggleAllowpip {
    my ($self, $value) = @_;

    my $dont = $value ? '' : " don't";
    
    return "You$dont allow the use of the server's 'pip' command.";
}

sub __showToggleAutoboard {
    my ($self, $value) = @_;

    my $wont = $value ? " will be" : " won't";
    
    return "The board$wont be refreshed after every move.";
}

sub __showToggleAutodouble {
    my ($self, $value) = @_;

    my $dont = $value ? '' : " don't";
    
    return "You$dont agree that doublets during opening double the cube.";
}

sub __showToggleAutomove {
    my ($self, $value) = @_;

    my $wont = $value ? " will" : " won't";
    
    return "Forced moves$wont be done automatically.";
}

sub __showToggleBell {
    my ($self, $value) = @_;

    my $wont = $value ? " will" : " won't";
    
    return "Your terminal won't ring the bell if someone talks to you or invites you";
}

sub __showToggleCrawford {
    my ($self, $value) = @_;

    if ($value) {
        return "You insist on playing with the Crawford rule.";
    } else {
        return "You would like to play without using the Crawford rule.";
    }
}

sub __showToggleMoreboards {
    my ($self, $value) = @_;

    my $wont = $value ? "Will" : " Won't";
    
    return "$wont send rawboards after rolling.";
}

sub __showToggleNotify {
    my ($self, $value) = @_;

    my $wont = $value ? "'ll" : " won't";
    
    return "You$wont be notified when new users log in.";
}

sub __showToggleRatings {
    my ($self, $value) = @_;

    my $wont = $value ? "'ll" : " won't";
    
    return "You$wont see how the rating changes are calculated.";
}

sub __showToggleReady {
    my ($self, $value) = @_;

    if ($value) {
        return "You're now ready to invite or join someone.";
    } else {
        return "You're now refusing to play with someone.";
    }
}

sub __showToggleReport {
    my ($self, $value) = @_;

    my $wont = $value ? "will" : "won't";
    
    return "You $wont be informed about starting and ending matches.";
}

sub __showToggleSilent {
    my ($self, $value) = @_;

    my $wont = $value ? "will" : "won't";
    
    return "You $wont hear what other players shout.";
}

sub __showToggleWrap {
    my ($self, $value) = @_;

    if ($value) {
        return "The server will wrap long lines.";
    } else {
        return "Your terminal knows how to wrap long lines.";
    }
}

1;

=head1 NAME

BaldLies::Session::Message::toggle - BaldLies Message `toggle'

=head1 SYNOPSIS

  use BaldLies::Session::Message::toggle->new;
  
=head1 DESCRIPTION

This plug-in handles the master message `toggle'.

=head1 SEE ALSO

BaldLies::Session::Message(3pm), baldlies(1), perl(1)

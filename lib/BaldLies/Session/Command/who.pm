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

package BaldLies::Session::Command::who;

use strict;

use base qw (BaldLies::Session::Command);

use POSIX qw (strftime);
use BaldLies::Util qw (empty equals);

sub execute {
    my ($self, $payload) = @_;
    
    my $session = $self->{_session};
    my $clip = $session->getClip;
    my $users = $session->getUsers;
    
    if (!$clip && equals 'count', $payload) {
        my $count = keys %$users;
        $session->reply ("There are $count users logged on.\n");
        return $self;
    }
    
    my %users;
    my $count = 0;
    foreach my $name (keys %$users) {
        $users{++$count} = $users->{$name};
    }
    
    if (equals 'ready', $payload) {
        foreach my $i (keys %users) {
            my $user = $users{$i};
            if (!(empty $user->{playing} && $user->{ready})) {
                delete $users{$i};
            }
        }
    } elsif (equals 'playing', $payload) {
        foreach my $i (keys %users) {
            my $user = $users{$i};
            if (empty $user->{playing}) {
                delete $users{$i};
            }
        }
    } elsif (equals 'away', $payload) {
        # Away is not implemented.
    } elsif (!empty $payload && $payload =~ /^from[ \t]+(.+)$/) {
        my $where = $1;
        foreach my $i (keys %users) {
            my $user = $users{$i};
            if (0 > index $user->{ip}, $where) {
                delete $users{$i};
            }
        }
    }
    
    if ($clip) {
        $self->__showClipWho (\%users, equals 'count', $payload);
    } else {
        $self->__showTelnetWho (\%users);
    }
    
    return $self;
}

sub __showClipWho {
    my ($self, $users, $funny_clip) = @_;
    
    my $session = $self->{_session};
    
    my $output = '';
    foreach my $count (sort { $a <=> $b } keys %$users) {
        my $user = $users->{$count};
        $output .= '5 ' . $user->rawwho . "\n";
    }
    
    if ($funny_clip) {
        # Yes, this is what FIBS gives you for the argument `count' in
        # CLIP mode.
        $output .= "There are 0 users logged on.\n";
    }
    
    $session->reply ($output);
    
    return $self;
}

sub __showTelnetWho {
    my ($self, $users) = @_;

    my $session = $self->{_session};
    
    my $output = <<EOF;
No  S  username        rating   exp login  idle from
EOF

    foreach my $count (sort { $a <=> $b } keys %$users) {
        my $user = $users->{$count};
        my $s;
        if (!empty $user->{playing}) {
            $s = 'P';
        } elsif ($user->{ready}) {
            $s = 'R';
        } else {
            $s = '-';
        }
        my $w;
        if (!empty $user->{watching}) {
            $w = 'W';
        } else {
            $w = ' ';
        }
        # Away is not implemented.
        my $a = ' ';
        my $login = strftime '%H:%M', gmtime $user->{login};
        my $ip = $user->{ip};
        $output .= sprintf "\%2d $s$w$a\%-15s \%6.2f %5d $login  00:00 $ip\n",
                           $count, $user->{name}, $user->{rating}, 
                           $user->{experience};
    }

    $session->reply ($output);
    
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Command::who - BaldLies Command `who'

=head1 SYNOPSIS

  use BaldLies::Session::Command::who->new (who => $session, $call);
  
=head1 DESCRIPTION

This plug-in handles the ommand `who'.

=head1 SEE ALSO

BaldLies::Session::Command(3pm), baldlies(1), perl(1)

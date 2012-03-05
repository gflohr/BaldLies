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

sub execute {
    my ($self, $payload) = @_;
    
    my $session = $self->{_session};
    my $clip = $session->getClip;
    
    if ($clip) {
        $self->__showClipWho ($payload);
    } else {
        $self->__showTelnetWho ($payload);
    }
    
    return $self;
}

sub __showClipWho {
    my ($self) = @_;
    
    my $session = $self->{_session};
    my $users = $session->getUsers;
    
    my $output = '';
    while (my ($name, $user) = each %$users) {
        $output .= '5 ' . $user->rawwho;
    }
    
    $session->reply ($output);
    
    return $self;
}

sub __showTelnetWho {
    my ($self) = @_;

    my $session = $self->{_session};
    my $users = $session->getUsers;
    
    my $output = <<EOF;
No  S  username        rating   exp login  idle from
EOF

    my $count = 0;
    while (my ($name, $user) = each %$users) {
        my $status = '-';
        my $login = strftime '%H:%M', gmtime $user->{login};
        my $ip = $user->{ip};
        $output .= sprintf "\%2d $status  \%-15s \%6.2f %5d $login  00:00 $ip\n",
                           ++$count, $name, $user->{rating}, $user->{experience};
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

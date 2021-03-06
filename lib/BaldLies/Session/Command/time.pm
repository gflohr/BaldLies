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

package BaldLies::Session::Command::time;

use strict;

use base qw (BaldLies::Session::Command);

use POSIX qw (strftime);

use BaldLies::Util qw (format_time);

sub execute {
    my ($self, $payload) = @_;
    
    my $session = $self->{_session};
    
    my $now = time;

    my $client = strftime '%A, %B %d %H:%M:%S UTC', gmtime $now;
    my $server = format_time $now;
    
    # FIBS does that funny formatting of parentheses.
    $session->reply ("$client  ( $server UTC )\n");
    
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Command::time - BaldLies Command `time'

=head1 SYNOPSIS

  use BaldLies::Session::Command::time->new (time => $session, $call);
  
=head1 DESCRIPTION

This plug-in handles the ommand `time'.

=head1 SEE ALSO

BaldLies::Session::Command(3pm), baldlies(1), perl(1)

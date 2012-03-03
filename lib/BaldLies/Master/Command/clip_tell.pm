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

package BaldLies::Master::Command::clip_tell;

use strict;

use base qw (BaldLies::Master::Command);

sub execute {
    my ($self, $fd, $payload) = @_;
    
    my $master = $self->{_master};
    my $logger = $master->getLogger;

    my ($recipient, $other) = split / /, $payload, 2;
    
    my %logins = map { $_ => 1 } $master->getLoggedIn;
    
    # No point handling this error;
    if (!exists $logins{$recipient}) {
        $logger->debug ("No such recipient `$recipient' for tell from $fd.");
        return $self;
    }
    
    $master->queueResponseForUser ($recipient, clip_tell => $other);
    
    return $self;
}

1;

=head1 NAME

BaldLies::Master::Command::clip_tell - BaldLies Command `clip_tell'

=head1 SYNOPSIS

  use BaldLies::Master::Command::clip_tell->new ($master);
  
=head1 DESCRIPTION

This plug-in handles the master command `clip_tell'.

=head1 SEE ALSO

BaldLies::Master::Command(3pm), baldlies(1), perl(1)

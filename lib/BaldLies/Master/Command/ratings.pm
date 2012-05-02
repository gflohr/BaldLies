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

package BaldLies::Master::Command::ratings;

use strict;

use base qw (BaldLies::Master::Command);

sub execute {
    my ($self, $fd, $payload) = @_;
    
    my $master = $self->{_master};
    my $logger = $master->getLogger;

    my ($type, @args) = split / /, $payload;
    
    # Always get the rating for the current user.
    my @names = ($master->getUserFromDescriptor ($fd)->{name}); 
    my ($from, $to) = (0, 0);
    
    if ($type eq 'range') {
        ($from, $to) = @args;
    } elsif ($type eq 'user') {
        push @names, $args[0] unless $args[0] eq $names[0];
    } else {
        $logger->error ("Unknown ratings type `$type' received.");
        return;
    }

    my $database = $master->getDatabase;
    my $rows = $database->getRatings (50, $from, $to, @names);
    
    my $reply = <<EOF;
 rank name            rating    Experience
EOF
    
    my %names = map { $_ => 1 } @names;
    
    foreach my $row (@$rows) {
        my $line = sprintf "\% 5d \%-15s \%.2f     \%u\n", @$row;
        if ($names{$row->[1]}) {
            $line =~ s/^( *)/$1*/ if $names{$row->[1]};
            $line =~ s/^ //;
        }
        $reply .= $line;
    }
    
    chomp $reply;    
    $reply =~ s/\n/\\n/g;
    
    $master->queueResponse ($fd, echo_e => $reply);

    return $self;
}

1;

=head1 NAME

BaldLies::Master::Command::ratings - BaldLies Command `ratings'

=head1 SYNOPSIS

  use BaldLies::Master::Command::ratings->new ($master);
  
=head1 DESCRIPTION

This plug-in handles the master command `ratings'.

=head1 SEE ALSO

BaldLies::Master::Command(3pm), baldlies(1), perl(1)

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

package BaldLies::Session::Command::toggle;

use strict;

use base qw (BaldLies::Session::Command);

use BaldLies::Util qw (empty);

sub execute {
    my ($self, $variable) = @_;
    
    my $session = $self->{_session};
    
    if (empty $variable) {
        return $self->__showAll;
    }
    
    return $self->__invalidArgument;
}


sub __showAll {
    my ($self) = @_;
    
    my $session = $self->{_session};
    my $user = $session->getUser;

    my $output = "The current settings are:\n";
    
    foreach my $variable (qw (allowpip autoboard automove bell crawford double
                              greedy moreboard moves notify ratings ready
                              report silent telnet wrap)) {
        $output .= sprintf "\%-15s \%s\n", $variable, 
                                          $user->{$variable} ? 'YES' : 'NO';
    }

    $session->reply ($output);
    
    return $self;
}

sub __invalidArgument {
    my ($self, $arg) = @_;
    
    $self->{_session}->reply ("** Don't know how to toggle arg\n");
    
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Command::toggle - BaldLies Command `toggle'

=head1 SYNOPSIS

  use BaldLies::Session::Command::toggle->new (toggle => $session, $call);
  
=head1 DESCRIPTION

This plug-in handles the ommand `toggle'.

=head1 SEE ALSO

BaldLies::Session::Command(3pm), baldlies(1), perl(1)

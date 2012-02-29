#! /bin/false

# This file is part of OpenFIBS.
# Copyright (C) 2012 Guido Flohr, http://guido-flohr.net/.
#
# OpenFIBS is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# OpenFIBS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with OpenFIBS.  If not, see <http://www.gnu.org/licenses/>.

package OpenFIBS::Master::Command;

use strict;

use OpenFIBS::Util qw (empty);

sub new {
    my ($class, $master) = @_;

    my $name = $class;
    $name =~ s/.*:://;
    bless { _name => $name, _master => $master }, $class;
}

sub execute {
    my ($self, $fd, $payload) = @_;
    
    my $master = $self->{_master};
    my $name = $self->{_name};
    
    $master->dropConnection ($fd, "The master command `$self->{_name}'"
                                  . " did not implement the execute"
                                  . " method.");
    
    return $self;
}

1;

=head1 NAME

OpenFIBS::Session::Command - OpenFIBS Stub Command Handler

=head1 SYNOPSIS

  use OpenFIBS::Session::Command;
  
  my $cmd = OpenFIBS::Session::Command->new ('help', $session);
  
=head1 DESCRIPTION

B<OpenFIBS::Server::Stub::Command> is the base class for all OpenFIBS
command handlers.

It should not be instantiated directly.  Instantiate one of the subclasses
instead.

=head1 SEE ALSO

OpenFIBS::Server(3pm), openfibs(1), perl(1)

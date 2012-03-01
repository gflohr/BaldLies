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

package BaldLies::Master::CommandDispatcher;

use strict;

use base qw (BaldLies::Dispatcher);

sub execute {
    my ($self, $fd, $cmd, $payload) = @_;
  
    my $logger = $self->{__logger};

    $logger->debug ("Master handling command `$cmd'.");
        
    if (!exists $self->{__names}->{$cmd}) {
        $logger->error ("Got unknown command `$cmd' from `$fd'.");
        return $self->{__master}->dropConnection ($fd);
    }

    my $module = $self->{__names}->{$cmd};
    my $plug_in = $module->new ($self->{__master});
    $plug_in->execute ($fd, $payload);
    
    return $self;
}

1;

=head1 NAME

BaldLies::Master::Command - BaldLies Master Command Dispatcher

=head1 SYNOPSIS

  use BaldLies::Session::CommandDispatcher;
  
  my $cmd = BaldLies::Session::CommandDispatcher->new (%args);
  
=head1 DESCRIPTION

B<BaldLies::Master::CommandDispatcher> loads all master command plug-ins and 
dispatches them.  It is the receiving end of the client to server
communication.

=head1 SEE ALSO

BaldLies::Master::Command(3pm), BaldLies::Master(3pm), baldlies(1), perl(1)

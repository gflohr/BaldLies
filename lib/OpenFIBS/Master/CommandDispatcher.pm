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

package OpenFIBS::Master::CommandDispatcher;

use strict;

use File::Spec;

sub new {
    my ($class, $master, $logger, @inc) = @_;

    my $self = bless { 
        __logger => $logger,
        __names => {},
        __master => $master,
    }, $class;

    foreach my $inc (@inc) {
        my $dir = File::Spec->catdir ($inc, 'OpenFIBS', 'Master', 'Command');
        next unless -d $dir;
        
        $logger->debug ("Searching command plug-ins in `$dir'.");

        local *DIR;
        opendir DIR, $dir
            or $logger->fatal ("Cannot open command directory `$dir': $!!");

        my @modules = grep /^[a-z_][a-z_0-9]*\.pm$/, readdir DIR;
        foreach my $module (@modules) {
            next unless $module =~ /^(.*)\.pm$/;
            my $cmd = $1;
            my $plug_in = 'OpenFIBS::Master::Command::' . $cmd;
            $logger->debug ("Initializing plug-in `$plug_in'.");
            eval "use $plug_in ()";
            $logger->fatal ($@) if $@;
            eval {
                $self->__registerCommands ($cmd);
            };
            $logger->fatal ($@) if $@;
        }
    }
    
    return $self;
}

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

sub __registerCommands {
    my ($self, $cmd) = @_;

    my $plug_in = 'OpenFIBS::Master::Command::' . $cmd;
    
    $self->{__names}->{$cmd} = $plug_in;
    
    return $self;
}

1;

=head1 NAME

OpenFIBS::Master::Command - OpenFIBS Master Command Dispatcher

=head1 SYNOPSIS

  use OpenFIBS::Session::CommandDispatcher;
  
  my $cmd = OpenFIBS::Session::CommandDispatcher->new ($master, $logger, @INC);
  
=head1 DESCRIPTION

B<OpenFIBS::Master::CommandDispatcher> loads all master command plug-ins and 
dispatches them.  It is the receiving end of the client to server
communication.

=head1 SEE ALSO

OpenFIBS::Master::Command(3pm), OpenFIBS::Master(3pm), openfibs(1), perl(1)

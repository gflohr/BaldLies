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

package OpenFIBS::Session::Dispatcher;

use strict;

use File::Spec;

sub new {
    my ($class, $logger, @inc) = @_;

    my $self = bless { 
        __logger => $logger,
        __names => {},
        __aliases => {},
    }, $class;

    foreach my $inc (@inc) {
        my $dir = File::Spec->catdir ($inc, 'OpenFIBS', 'Session', 'Command');
        next unless -d $dir;
        
        $logger->debug ("Searching command plug-ins in `$dir'.");

        local *DIR;
        opendir DIR, $dir
            or $logger->fatal ("Cannot open command directory `$dir': $!!");

        my @modules = grep /^[a-z_][a-z_0-9]*\.pm$/, readdir DIR;
        foreach my $module (@modules) {
            next unless $module =~ /^(.*)\.pm$/;
            my $cmd = $1;
            my $plug_in = 'OpenFIBS::Session::Command::' . $cmd;
            $logger->debug ("Initializing plug-in `$plug_in'.");
            eval "use $plug_in ()";
            $logger->fatal ($@) if $@;
            eval {
                $self->__registerCommands ($cmd, $plug_in->aliases);
            };
            $logger->fatal ($@) if $@;
        }
    }
    
    my %specials = (
        b => 'board',
        k => 'kibitz', 
        m => 'move', 
        r => 'roll', 
        s => 'say', 
        t => 'tell', 
        w => 'who',
        wh => 'whisper'
    );
    while (my ($alias, $name) = each %specials) {
        $self->{__aliases}->{$alias} = "OpenFIBS::Session::Command::$name"
            if exists $self->{__names}->{$name};
    }
    
    return $self;
}

sub execute {
    my ($self, $session, $call, $payload) = @_;
    
    my $cmd = lc $call;
    
    if (!exists $self->{__aliases}->{$cmd}) {
        $session->reply ("** Unknown command: '$call'\n");
    } else {
        my $module = $self->{__aliases}->{$cmd};
        my $plug_in = $module->new ($session, $call);
        $plug_in->execute ($payload);
    }
    
    return $self;
}

sub all {
    my ($self) = @_;
    
    return keys %{$self->{__names}};
}

sub module {
    my ($self, $cmd) = @_;
    
    # This is compatible to FIBS but not very clever.  Actually, aliases
    # should also be possible for the cmd attribute.  But FIBS does not
    # display help, when the topic is an alias.  Maybe this should be made
    # configurable.
    return $self->{__names}->{$cmd} if exists $self->{__names}->{$cmd};

    return;
}

sub __registerCommands {
    my ($self, $cmd, @aliases) = @_;

    my $plug_in = 'OpenFIBS::Session::Command::' . $cmd;
    
    my $logger = $self->{__logger};

    # Check for conflicts.
    foreach my $name ($cmd, map { lc $_ } @aliases) {
        if (exists $self->{__names}->{$name}) {
            my $other = $self->{__names}->{$name};
            $logger->error (<<EOF);
The alias `$name' was already registered by plug-in `$other'.
All definitions from `$plug_in' will be ignored.
EOF
            return;
        }
    }

    $self->{__names}->{$cmd} = $plug_in;
    foreach my $name ($cmd, map { lc $_ } @aliases) {
        my @chars = split //, $name;
        
        # Standard aliases are at least two characters long.  We shift the
        # first one, before entering the loop.
        my $alias = shift @chars;        
        while (@chars) {
            $alias .= shift @chars;
            if (exists $self->{__aliases}->{$alias}) {
                delete $self->{__aliases}->{$alias};
            } else {
                $self->{__aliases}->{$alias} = $plug_in;
            }
        }
        $self->{__aliases}->{$name} = $plug_in;
    }
    
    return $self;
}

1;

=head1 NAME

OpenFIBS::Session::Command - OpenFIBS Command Dispatcher

=head1 SYNOPSIS

  use OpenFIBS::Session::Dispatcher;
  
  my $cmd = OpenFIBS::Session::Dispatcher->new ($logger, @INC);
  
=head1 DESCRIPTION

B<OpenFIBS::Session::Dispatcher> loads all commands plug-ins, and dispatches
them.

=head1 SEE ALSO

OpenFIBS::Session::Command(3pm), OpenFIBS::Session(3pm), openfibs(1), perl(1)

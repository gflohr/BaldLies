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

package BaldLies::Session::CommandDispatcher;

use strict;

use base qw (BaldLies::Dispatcher);

sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new (%args);
    
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
        $self->{__names}->{$alias} = "BaldLies::Session::Command::$name"
            if exists $self->{__real_names}->{$name};
    }
    
    return $self;
}

sub execute {
    my ($self, $session, $call, $payload) = @_;
    
    my $cmd = lc $call;
    my $module = eval { $self->_loadModule ($cmd) };
    if ($@) {
        my $exception = $@;
        
        $exception =~ s/[ \t\r\n]+/ /g;
        return $session->reply ("** $exception\n");
    }
    if (!$module) {
        return $session->reply ("** Unknown command: '$call'\n");
    }
    
    my $plug_in = $module->new ($session, $call);
    $plug_in->execute ($payload);
    
    return $self;
}

sub all {
    my ($self) = @_;
    
    return keys %{$self->{__real_names}};
}

sub module {
    my ($self, $cmd) = @_;
    
    # This is compatible to FIBS but not very clever.  Actually, aliases
    # should also be possible for the cmd attribute.  But FIBS does not
    # display help, when the topic is an alias.  Maybe this should be made
    # configurable.
    return $self->{__real_names}->{$cmd} 
        if exists $self->{__real_names}->{$cmd};

    return;
}

sub _registerCommands {
    my ($self, $cmd, $plug_in, $no_resolve) = @_;

    my @aliases = $plug_in->aliases;
    
    my $module = 'BaldLies::Session::Command::' . $cmd;
    
    my $logger = $self->{__logger};

    if (!$no_resolve) {
        # Check for conflicts.
        foreach my $name ($cmd, map { lc $_ } @aliases) {
            if (exists $self->{__real_names}->{$name}) {
                my $other = $self->{__real_names}->{$name};
                $logger->error (<<EOF);
The alias `$name' was already registered by plug-in `$other'.
All definitions from `$module' will be ignored.
EOF
                return;
            }
        }
    }
    
    $self->{__real_names}->{$cmd} = $plug_in;
    
    if (!$no_resolve) {
        foreach my $name ($cmd, map { lc $_ } @aliases) {
            my @chars = split //, $name;
            
            # Standard aliases are at least two characters long.  We shift the
            # first one, before entering the loop.
            my $alias = shift @chars;        
            while (@chars) {
                $alias .= shift @chars;
                if (exists $self->{__names}->{$alias}) {
                    delete $self->{__names}->{$alias};
                } else {
                    $self->{__names}->{$alias} = $plug_in;
                }
            }
            $self->{__names}->{$name} = $plug_in;
        }
    } else {
        $self->{__names}->{$cmd} = $plug_in;
    }
    
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Command - BaldLies Command Dispatcher

=head1 SYNOPSIS

  use BaldLies::Session::CommandDispatcher;
  
  my $cmd = BaldLies::Session::CommandDispatcher->new ($logger, @INC);
  
=head1 DESCRIPTION

B<BaldLies::Session::CommandDispatcher> loads all commands plug-ins, and 
dispatches them.

=head1 SEE ALSO

BaldLies::Session::Command(3pm), BaldLies::Session(3pm), baldlies(1), perl(1)

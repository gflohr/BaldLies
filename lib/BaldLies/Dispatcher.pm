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

package BaldLies::Dispatcher;

use strict;

use File::Spec;

use BaldLies::Util qw (empty);

sub new {
    my ($class, %args) = @_;

    my $self = {};
    while (my ($key, $value) = each %args) {
        $self->{'__' . $key} = $value;
    }
    bless $self, $class;
    $self->{_names} = {};
    $self->{__realms} = [split '::', $self->{__realm}];
    
    my $logger = $self->{__logger};
    foreach my $inc (@{$self->{__inc}}) {
        my $dir = File::Spec->catdir ($inc, @{$self->{__realms}});
        next unless -d $dir;
        
        $logger->debug ("Searching command plug-ins in `$dir'.");

        local *DIR;
        opendir DIR, $dir
            or $logger->fatal ("Cannot open command directory `$dir': $!!");

        my @modules = grep /^[a-z_][a-z_0-9]*\.pm$/, readdir DIR;
        foreach my $module (@modules) {
            next unless $module =~ /^(.*)\.pm$/;
            my $cmd = $1;
            my $plug_in = $self->{__realm} . '::' . $cmd;
            $logger->debug ("Initializing plug-in `$plug_in'.");
            eval "use $plug_in ()";
            $logger->fatal ($@) if $@;
            eval {
                $self->_registerCommands ($cmd, $plug_in);
            };
            $logger->fatal ($@) if $@;
            
            next if !$self->{__reload};
            
            my $inc_path = join '/', @{$self->{__realms}}, "$cmd.pm";
            my $full_path = File::Spec->catfile ($inc, @{$self->{__realms}}, 
                                                 "$cmd.pm");            
            my @sb = stat $full_path 
                or $logger->fatal ("Cannot stat `$full_path': $!!");
            $self->{__module_info}->{$plug_in} = {
                inc_path => $inc_path,
                mtime => $sb[9],
                path => $full_path,
            };
        }
    }
    
    return $self;
}

sub _getLogger {
    shift->{__logger};
}

sub _registerCommands {
    my ($self, $cmd) = @_;

    my $module = $self->{__realm} . '::' . $cmd;
    
    $self->{_names}->{$cmd} = $module;
    
    return $self;
}

sub _loadModule {
    my ($self, $cmd) = @_;

    my $logger = $self->_getLogger;
    
    if (exists $self->{_names}->{$cmd}) {
        my $module = $self->{_names}->{$cmd};
        
        if ($self->{__reload}) {
            my $modinfo = $self->{__module_info}->{$module};
            my @sb = stat $modinfo->{path};
            if (!@sb) {
                $logger->warning ("Plug-in `$modinfo->{path}' has vanished:"
                                  . " $!!");
                return;
            }
            my $mtime = $sb[9];
            if ($mtime != $modinfo->{mtime}) {
                $logger->info ("Must re-compile $module.");
                $logger->info (delete $INC{$modinfo->{inc_path}});
                eval "use $module";
                die $@ if $@;
                return $module;
            }
        }
        
        return $module;
    }
    
    return if !$self->{__reload};
    
    # Try to find the module again.
    my $path;
    foreach my $inc (@{$self->{__inc}}) {
        my $dir = File::Spec->catdir ($inc, @{$self->{__realms}});
        next unless -d $dir;
        
        my $filename = lc "$cmd.pm";
        my $try_path = File::Spec->catfile ($dir, $filename);

        next unless -e $try_path;
        
        $path = $try_path;
        last;
    }

    return if empty $path;

    my $module = $self->{__realm} . '::' . $cmd;
    eval "use $module";
    die $@ if ($@);

    $self->_registerCommands ($cmd, $module, 1);
    
    return $self->_loadModule ($cmd);
}

1;

=head1 NAME

BaldLies::Dispatcher - BaldLies Plug-In Dispatcher

=head1 SYNOPSIS

  die "BaldLies::Dispatcher is an abstract base class";
  
=head1 DESCRIPTION

B<BaldLies::Dispatcher> is the base class for all BaldLies plug-in
dispatchers.

=head1 SEE ALSO

baldlies(1), perl(1)

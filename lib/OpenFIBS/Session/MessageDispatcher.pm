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

package OpenFIBS::Session::MessageDispatcher;

use strict;

use File::Spec;

sub new {
    my ($class, $session, $logger, @inc) = @_;

    my $self = bless { 
        __logger => $logger,
        __names => {},
        __session => $session,
    }, $class;

    foreach my $inc (@inc) {
        my $dir = File::Spec->catdir ($inc, 'OpenFIBS', 'Session', 'Message');
        next unless -d $dir;
        
        $logger->debug ("Searching message plug-ins in `$dir'.");

        local *DIR;
        opendir DIR, $dir
            or $logger->fatal ("Cannot open message directory `$dir': $!!");

        my @modules = grep /^[a-z_][a-z_0-9]*\.pm$/, readdir DIR;
        foreach my $module (@modules) {
            next unless $module =~ /^(.*)\.pm$/;
            my $cmd = $1;
            my $plug_in = 'OpenFIBS::Session::Message::' . $cmd;
            $logger->debug ("Initializing plug-in `$plug_in'.");
            eval "use $plug_in ()";
            $logger->fatal ($@) if $@;
            eval {
                $self->__registerHandlers ($cmd);
            };
            $logger->fatal ($@) if $@;
        }
    }
    
    return $self;
}

sub execute {
    my ($self, $msg, $payload) = @_;
    
    my $logger = $self->{__logger};

    $logger->debug ("Session handling command `$msg'.");
        
    if (!exists $self->{__names}->{$msg}) {
        $logger->fatal ("Got unknown msg `$msg' from master.");
    }

    my $module = $self->{__names}->{$msg};
    my $plug_in = $module->new ($self->{__master});
    $plug_in->execute ($payload);
    
    return $self;
}

sub __registerHandlers {
    my ($self, $msg) = @_;

    my $plug_in = 'OpenFIBS::Session::Message::' . $msg;
    
    $self->{__names}->{$msg} = $plug_in;
    
    return $self;
}

1;

=head1 NAME

OpenFIBS::Session::Message - OpenFIBS Session Message Dispatcher

=head1 SYNOPSIS

  use OpenFIBS::Session::MessageDispatcher;
  
  my $msg = OpenFIBS::Session::MessageDispatcher->new ($session, $logger, @INC);
  
=head1 DESCRIPTION

B<OpenFIBS::Session::MessageDispatcher> loads all session message plug-ins and 
dispatches them.  It is the receiving end of the server to client 
communication.

=head1 SEE ALSO

OpenFIBS::Session::Message(3pm), OpenFIBS::Session(3pm), openfibs(1), perl(1)

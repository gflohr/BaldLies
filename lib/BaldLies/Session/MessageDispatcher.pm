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

package BaldLies::Session::MessageDispatcher;

use strict;

use File::Spec;

sub new {
    my ($class, $logger, @inc) = @_;

    my $self = bless { 
        __names => {},
    }, $class;

    foreach my $inc (@inc) {
        my $dir = File::Spec->catdir ($inc, 'BaldLies', 'Session', 'Message');
        next unless -d $dir;
        
        $logger->debug ("Searching message plug-ins in `$dir'.");

        local *DIR;
        opendir DIR, $dir
            or $logger->fatal ("Cannot open message directory `$dir': $!!");

        my @modules = grep /^[a-z_][a-z_0-9]*\.pm$/, readdir DIR;
        foreach my $module (@modules) {
            next unless $module =~ /^(.*)\.pm$/;
            my $cmd = $1;
            my $plug_in = 'BaldLies::Session::Message::' . $cmd;
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
    my ($self, $session, $msg, $payload) = @_;
    
    my $logger = $session->getLogger;

    $logger->debug ("Session handling command `$msg'.");
        
    if (!exists $self->{__names}->{$msg}) {
        $logger->fatal ("Got unknown msg `$msg' from master.");
    }

    my $module = $self->{__names}->{$msg};
    $module->new->execute ($session, $payload);
    
    return $self;
}

sub __registerHandlers {
    my ($self, $msg) = @_;

    my $plug_in = 'BaldLies::Session::Message::' . $msg;
    
    $self->{__names}->{$msg} = $plug_in;
    
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Message - BaldLies Session Message Dispatcher

=head1 SYNOPSIS

  use BaldLies::Session::MessageDispatcher;
  
  my $msg = BaldLies::Session::MessageDispatcher->new ($session, $logger, @INC);
  
=head1 DESCRIPTION

B<BaldLies::Session::MessageDispatcher> loads all session message plug-ins and 
dispatches them.  It is the receiving end of the server to client 
communication.

=head1 SEE ALSO

BaldLies::Session::Message(3pm), BaldLies::Session(3pm), baldlies(1), perl(1)

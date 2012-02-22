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

package OpenFIBS::Server::Listener;

use strict;

use OpenFIBS::Util qw (empty);
use IO::Socket::INET;
use Errno;

sub new {
    my ($class, $address, $logger) = @_;

    my ($host, $service) = split /:/, $address, 2;
    
    my $port;
    if (defined $service && $service =~ /^0|[1-9][0-9]*$/) {
        die "Port number out of range in address `$address'.\n"
            if (!$service || $service > 0xffff);
        $port = $service;
    } elsif (!empty $port) {
        my @port = getservbyname $service, 'tcp'
            or die "Invalid service name `$service' in `$address'.\n";
        $port = $port[2];
    } else {
        $port = 4321;
    }
        
    # Numerical IP (v4)?
    my @ips;
    my $octet_re = qr /[0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5]/;
    if ($host =~ /^(?:$octet_re\.){3}$octet_re$/) {
        @ips = ($host);
    } elsif ('*' eq $host) {
        @ips = ('*');
    } else {
        my @hostent = gethostbyname $host
            or die "Cannot resolve hostname `$host'.\n";
        my @addr = @hostent[4, $#hostent];
        foreach my $addr (@addr) {
            push @ips, join '.', unpack 'C4', $addr;
        }
    }
    
    my @objs;
    foreach my $ip (@ips) {
        $logger->warning ("IP: $ip");
        push @objs, bless { 
            __ip => $ip, 
            __port => $port,
            __address => $address,
            __logger => $logger,
        }, $class;
    }
    
    return @objs;
}

sub ip {
    shift->{__ip};
}

sub port {
    shift->{__port};
}

sub address {
    shift->{__address};
}

sub listen {
    my ($self) = @_;
    
    my $logger = $self->{__logger};
    
    my %args = (
        LocalPort => $self->{__port},
        Listen => 5,
        Proto => 'tcp',
    );
    $args{LocalHost} = $self->{__ip} unless '*' eq $self->{__ip};
    
    my $ip = $self->{__ip};
    $ip = 'all interfaces on' if '*' eq $ip;
    $logger->notice ("Start listening on $ip port $self->{__port}.");
    
    $self->{__socket} = IO::Socket::INET->new (%args)
        or $logger->fatal ("Cannot listen on $ip port $self->{__port}: $!!");
    $self->{__socket}->blocking (0);
    
    return $self;
}

sub accept {
    my ($self) = @_;
    
    my $logger = $self->{__logger};
    
    my $address = "$self->{__ip}:$self->{__port}";
    
    my $peer = $self->{__socket}->accept;
    
    if (!$peer) {
        return if $!{EAGAIN}; 
        return if $!{EWOULDBLOCK};
        $logger->fatal ("Error accepting connection on $address: $!!");
    }
    
    $logger->debug ("Incoming connection on $address.");

    return $peer;
}

sub checkAccess {
    my ($self, $address) = @_;
    
    return if '127.0.0.1' ne $address;
    
    return $self;
}

sub close {
    my ($self) = @_;
    
    my $socket = $self->{__socket} or return;
    
    $socket->close or return;
    
    return $self;
}

1;

=head1 NAME

OpenFIBS::Server::Listener - OpenFIBS Listening Socket

=head1 SYNOPSIS

  use OpenFIBS::Server::Listener->new ($address_spec);
  
=head1 DESCRIPTION

B<OpenFIBS::Server::Listener> is an internal class.

=head1 SEE ALSO

OpenFIBS::Server(3pm), openfibs(1), perl(1)

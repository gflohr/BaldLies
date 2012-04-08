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

package BaldLies::Client;

use strict;

use POSIX qw (setlocale LC_ALL);

use IO::Socket::INET;
use IO::Select;
use Errno;

use BaldLies::Util qw (empty);
use BaldLies::Const qw (:log_levels);
use BaldLies::Logger;

my $singleton;

sub new {
    my ($class, %options) = @_;

    if ($singleton) {
        require Carp;
        Carp::croak (__PACKAGE__ . " was already instantiated");
    }
    
    POSIX::setlocale (LC_ALL, "POSIX");
 
    my $self = $singleton = {};
    
    # Preliminary logger.
    my $stderr = IO::Handle->new;
    $stderr->fdopen (fileno (STDERR), 'w');
    my $logger = BaldLies::Logger->new (level => 0,
                                        stderr => $stderr);
    $self->{__logger} = $logger;
    
    # Defaults.
    my $defaults = {
        host => 'localhost',
        port => '4321',
        backend => 'GNU',
        verbose => LOG_NOTICE,
        reconnect => 30,
        timeout => 10,
        ping => 600,
    };
    
    my %config = Config::General->new (-ConfigFile => $options{config_file},
                                       -DefaultConfig => $defaults)
                                ->getall;

    # Override with command-line options.
    while (my ($key, $value) = each %options) {
        $config{$key} = $value if !empty $value;
    }
    
    # Santize all general options.
    foreach my $key ((keys %options), (keys %$defaults)) {
        if (exists $config{$key} && ref $config{$key} 
            && 'ARRAY' eq ref $config{$key}) {
            $config{$key} = $config{$key}->[-1];
        }
    };
    
    $self->{__config} = \%config;
    
    die "No username given!\n" if empty $config{user};
    die "No password specified!\n" if empty $config{pass};

    # Reopen logger.
    $self->{__logger} = BaldLies::Logger->new (level => $config{verbose},
                                               stderr => $stderr,
                                               logfile => $config{logfile},
                                               hires => $config{hires});

    $logger = $self->{__logger};
    $logger->info ("Loading client backend $config{backend}.");    
    my $backend_file = 'BaldLies/Client/Backend/' . $config{backend} . '.pm';
    eval { require $backend_file };
    $logger->fatal ($@) if $@;
    
    $self->{__backend_class} = 'BaldLies::Client::Backend::' . $config{backend};
        
    bless $self, $class;
}

sub run {
    my ($self) = @_;
    
    my $config = $self->{__config};
    my $logger = $self->{__logger};
    
    while (1) {
        eval {
            $self->__runSession;
        };
        if ($@) {
            $logger->error ($@);
        }
        $logger->notice ("Waiting $config->{reconnect} seconds for another"
                         . " connection attempt.");
        sleep $config->{reconnect};
    }
    
    die "Should never get here";
}

sub __runSession {
    my ($self) = @_;
    
    my $config = $self->{__config};
    my $logger = $self->{__logger};

    # Clean up.
    delete $self->{__backend};
    
    my $socket = $self->__connectToServer or return;
    my $state = 'login';
    my $last_ping = time;
    $self->{__server_out} = '';
    $self->{__server_in} = '';
    
    while (1) {
        my $rsel = IO::Select->new;
        my $wsel = IO::Select->new;
        
        $rsel->add ($socket);
        $wsel->add ($socket) if !empty $self->{__server_out};
        
        my ($rout, $wout, undef) = IO::Select->select ($rsel, $wsel, undef,
                                                       $config->{ping});
        foreach my $fd (@$rout) {
            if ($fd == $socket) {
                my $bytes_read = sysread $socket, $self->{__server_in},
                                         4096, length $self->{__server_in};
                if (!defined $bytes_read) {
                    if ($!{EAGAIN} || $!{EWOUDBLOCK}) {
                        next;
                    }
                    die "Error reading from server: $!!\n";
                } elsif (0 == $bytes_read) {
                    die "End-of-file reading from server!\n";
                }
                if ('login' eq $state) {
                    while ($self->{__server_in} =~ s/.*\015?\012//) {};
                    if ($self->{__server_in} =~ s/^login: +//s) {
                        $self->queueServerOutput ('login',
                                                  $BaldLies::Server::VERSION,
                                                  1008,
                                                  $config->{user},
                                                  $config->{pass});
                        $state = 'authenticate';
                        $logger->debug ("Waiting for welcome from server.");
                        next;
                    }
                }
                while ($self->{__server_in} =~ s/(.*?)\015?\012//) {
                    my $line = $1;
                    next unless length $line;
                    if ('authenticate' eq $state) {
                        if ($line !~ /^1/) {
                            die "Authentication failed!\n";
                        }
                        $self->{state} = 'logged_in';
                    }
                    $last_ping = time;
                    $self->__handleFIBSInput ($line);
                }
            }
        }

        # Check for authentication timeout.
        my $now = time;
        if ($now - $self->{last_ping} < 0) {
            die "Clock skew detected!";
        } elsif ($now - $last_ping > $config->{timeout}) {
            die "Authentication timeout!\n";
        }
        
        foreach my $fd (@$wout) {
            my $out_ref;
            my $out_target;
            
            if ($fd == $socket) {
                $out_ref = \$self->{__server_out};
                $out_target = 'server';
            } else {
                next;
            }
            
            my $bytes_written = syswrite $fd, $$out_ref;
            if (!defined $bytes_written) {
                if ($!{EAGAIN} || $!{EWOUDBLOCK}) {
                    $logger->debug ("Writing to $out_target would block.");
                    next;
                }
                die "Error writing to $out_target: $!!\n";
            } elsif (0 == $bytes_written) {
                die "End-of-file writing to $out_target!\n";
            }
            substr $$out_ref, 0, $bytes_written, '';
        }
    }
    
    return $self;
}

sub queueServerOutput {
    my ($self, @payload) = @_;
    
    my $payload = join ' ', @payload;
    chomp $payload;
    $self->{__server_out} .= "$payload\012\015";
    
    return $self;
}

sub __handleFIBSInput {
    my ($self, $line) = @_;
    
    my $logger = $self->{__logger};

    my ($code, $data) = split /[ \t]+/, $line;
    
    # Recognized clip message?
    if ($code == 1) {
        return $self->__handleClipWelcome ($line);
    }
    
    return $self;
}

sub __handleClipWelcome {
    my ($self, $data) = @_;
    
    my ($name, $last_login, $last_host) = @_;
    
    die "Invalid CLIP welcome message `$data' received!\n"
        if !defined $last_host;
    die "Got CLIP welcome for foreign user `$name'!\n"
        if $name ne $self->{__config}->{user};
        
    return $self;
}

sub __connectToServer {
    my ($self) = @_;

    my $config = $self->{__config};
    my $logger = $self->{__logger};

    $logger->notice ("Connecting to `$config->{host}' on port"
                     . " `$config->{port}'.");
    
    my $socket = $self->{__socket} = IO::Socket::INET->new (
        PeerHost => $config->{host},
        PeerPort => $config->{port},
        Timeout => $config->{timeout},
        Proto => 'tcp',
        MultiHomed => 1,
    ) or die "Cannot create socket: $!!\n";

    # Once we are connected, put the socket into non-blocking mode.
    $socket->blocking (1);
    
    return $socket;
}

1;

=head1 NAME

BaldLies::Client - A BaldLies Client

=head1 SYNOPSIS

  use BaldLies::Client;
  
  my $client = BaldLies::Client (OPTIONS);
  
  $client->run;

=head1 DESCRIPTION

B<BaldLies::Client> implements a client for a B<BaldLies::Server>.  It is used
internally for testing.

The client is a singleton, and can only be instantiated once!

=head1 CONSTRUCTOR

The constructor new() accepts named options.  They will be merged into the
configuration read from an optional config file.

=head1 SEE ALSO

baldlies(1), perl(1)

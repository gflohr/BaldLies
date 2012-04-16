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
use BaldLies::Backgammon::Match;

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
    my @default_keys = keys %$defaults;
    
    my %config = Config::General->new (-ConfigFile => $options{config_file},
                                       -DefaultConfig => $defaults,
                                       -AllowMultiOptions => 'yes')
                                ->getall;

    # Override with command-line options.
    while (my ($key, $value) = each %options) {
        $config{$key} = $value if !empty $value;
    }
    
    # Sanitize all general options.
    foreach my $key (@default_keys, keys %options) {
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

sub getConfig {
    shift->{__config}
}

sub getLogger {
    shift->{__logger}
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
    delete $self->{__terminate};
    
    my $state = 'login';
    my $last_ping = time;
    $self->{__server_out} = '';
    $self->{__server_in} = '';
    $self->{__control_out} = '';
    $self->{__control_in} = '';
    
    my $socket = $self->__connectToServer or return;
    my $backend = $self->{__backend} = $self->__startBackend or return;
    
    while (1) {
        my $rsel = IO::Select->new;
        my $wsel = IO::Select->new;
        
        $rsel->add ($socket);
        $rsel->add ($backend->controlOutput);
        $wsel->add ($socket) if !empty $self->{__server_out};
        $wsel->add ($backend->controlInput) if !empty $self->{__control_out};
        
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
                        $state = 'logged_in';
                    }
                    $last_ping = time;
                    $self->__handleFIBSInput ($line);
                }
            }

            if ($fd == $backend->controlOutput) {
                my $bytes_read = sysread $fd, $self->{__control_in},
                                         4096, length $self->{__control_in};
                if (!defined $bytes_read) {
                    if ($!{EAGAIN} || $!{EWOUDBLOCK}) {
                        next;
                    }
                    die "Error reading from backend: $!!\n";
                } elsif (0 == $bytes_read) {
                    die "End-of-file reading from backend!\n";
                }

                $backend->processInput (\$self->{__control_in});
            }
        }

        # Check for authentication timeout.
        my $now = time;
        if ($now - $last_ping < 0) {
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
                $logger->debug ("Client ready for receiving input");
                $out_ref = \$self->{__control_out};
                $out_target = 'backend';
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
            my $out = $$out_ref;
            
            my $written = substr $$out_ref, 0, $bytes_written, '';
            $logger->debug (">>>$out_target>>> $written");
        }
        
        if ($self->{__terminate}) {
            $logger->notice ("Terminating on request.");
            exit 0;
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

sub queueControlOutput {
    my ($self, @payload) = @_;
    
    my $payload = join ' ', @payload;
    chomp $payload;
    $self->{__control_out} .= "$payload\n";
    
    return $self;
}

sub terminate {
    my ($self) = @_;
    
    $self->{__terminate} = 1;
    
    exit 0 if empty $self->{__server_out};
    
    return $self;
}

sub __handleFIBSInput {
    my ($self, $line) = @_;
    
    my $logger = $self->{__logger};

    my ($code, $data) = split /[ \t]+/, $line;
    return unless defined $code;
    
    # Recognized clip message?
    if ($code eq '1') {
        return $self->__handleClipWelcome ($line);
    } elsif ($code eq '2') {
        return $self->__handleClipOwnInfo ($line);
    } elsif ($code eq '12') {
        return $self->__handleClipTell ($line);
    }
    
    # Invitation?
    if ($line =~ /^Type[ \t]+'join[ \t]+(.+?)'/) {
        $logger->info ("Got invitation from `$1'");
        $self->queueServerOutput ("join $1");
    } elsif ($line =~ /^board:You:/) {
        return $self->__handleClipBoard ($line);
    }
    
    return $self;
}

sub __handleClipWelcome {
    my ($self, $line) = @_;
    
    my ($one, $name, $last_login, $last_host) = split /[ \t]+/, $line;
    
    die "Invalid CLIP welcome message `$line' received!\n"
        if !defined $last_host;
    die "Got CLIP welcome for foreign user `$name'!\n"
        if $name ne $self->{__config}->{user};
        
    return $self;
}

sub __handleClipOwnInfo {
    my ($self, $line) = @_;
    
    my ($two, $name, $allowpip, $autoboard, $autodouble, $automove,
        $away, $bell, $crawford, $double, $experience, $greedy,
        $moreboards, $moves, $notify, $rating, $ratings, $ready,
        $redoubles, $report, $silent, $timezone) = split /[ \t]+/, $line;
    
    die "Invalid CLIP own info `$line' received!\n"
        if !defined $timezone;
    die "Got CLIP welcome for foreign user `$name'!\n"
        if $name ne $self->{__config}->{user};
    
    my $logger = $self->{__logger};
    
    # Check essential settings.
    if (!$autoboard) {
        $logger->notice ("Must toggle autoboard on.");
        $self->queueServerOutput (toggle => 'autoboard');
    }
    
    if ($autodouble) {
        $logger->notice ("Must toggle autodouble off.");
        $self->queueServerOutput (toggle => 'autodouble');
    }
    
    if ($away) {
        $logger->notice ("Must come back.");
        $self->queueServerOutput ('back');
    }
    
    if ($bell) {
        $logger->notice ("Must turn off bell.");
        $self->queueServerOutput (toggle => 'bell');
    }
    
    if (!$crawford) {
        $logger->notice ("Must toggle Crawford on.");
        $self->queueServerOutput (toggle => 'crawford');
    }
    
    if (!$moreboards) {
        $logger->notice ("Must toggle moreboards on.");
        $self->queueServerOutput (toggle => 'moreboards');
    }
    
    if ($redoubles) {
        $logger->notice ("Must switch redoubles from $redoubles to none.");
        $self->queueServerOutput (set => 'redoubles none');
    }
    
    $self->queueServerOutput (set => 'boardstyle 3');
    
    return $self;
}

sub __handleClipTell {
    my ($self, $line) = @_;
    
    my $logger = $self->{__logger};
    my $config = $self->{__config};

    my ($twelve, $sender, $command, $data) = split /[ \t]/, $line, 4;
    
    if (defined $command && 'control' eq $command) {
        
        if (defined $config->{admin} && $sender eq $config->{admin}) {
            $self->queueServerOutput ($data);
            $self->queueServerOutput (tellx => $sender,
                                      "Command executed: $data");
            $logger->info ("Send command on behalf of `$sender': $data");
        } else {
            $self->queueServerOutput (tellx => $sender,
                                      "What do you think I am?",
                                      "A human???");
            $logger->notice ("Unauthorized attempt to control me: $data");
        }
    } else {
        $self->queueServerOutput (tellx => $sender,
                                  "What do you think I am?",
                                  "A human???");
    }
    
    return $self;
}

sub __handleClipBoard {
    my ($self, $line) = @_;

    my $logger = $self->{__logger};
    my $config = $self->{__config};
    my $client = $self->{__client};
    
    $logger->debug ("Got board: $line");

    my $match = BaldLies::Backgammon::Match->newFromFIBSBoard ($line);
    
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

sub __startBackend {
    my ($self) = @_;
    
    return $self->{__backend_class}->new($self)->run;
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

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

package OpenFIBS::Server::Session;

use strict;

use Fcntl qw (F_GETFL F_SETFL O_NONBLOCK);
use IO::Select;
use IO::Socket::UNIX;

use OpenFIBS::Util qw (empty);
use OpenFIBS::Const qw (:comm);
use OpenFIBS::User;

use constant MASTER_HANDLERS => {
    COMM_ACK, 'ack',
};

use constant TELNET_ECHO_OFF => "\xff\xfb\x01";
use constant TELNET_ECHO_ON => "\xff\xfd\x01";

sub new {
    my ($class, $server, $ip, $peer) = @_;

    my $self = {
        __server => $server,
        __peer => $peer,
        __ip => $ip,
        __client_in => '',
        __client_out => '',
        __master_sock => undef,
        __master_in => '',
        __master_out => '',
        __state => 'login',
        __telnet => 1,
        __seqno => 0,
        __expect => {}
    };

    my $logger = $self->{__logger} = $server->getLogger;
    $logger->ip ($ip . ':' . $$);
    my $config = $self->{__config} = $server->getConfig;
    $self->{__banner} = <<EOF;
                           ************************
                           * Welcome to OpenFIBS! *
                           ************************

Please login as guest if you do not have an account on this server.
EOF

    my $socket_name = $config->{socket_name};
    $logger->debug ("Connecting to master socket `$socket_name'.");
    $self->{__master_sock} = IO::Socket::UNIX->new (Type => SOCK_STREAM,
                                                    Peer => $socket_name)
        or $logger->fatal ("Cannot connect to master socket `$socket_name'.");
        
    bless $self, $class;
}

sub DESTROY {
    my ($self) = @_;
    
    $self->{__peer}->shutdown (2) if $self->{__peer};
}

sub run {
    my ($self) = @_;
    
    my $logger = $self->{__logger};
    my $config = $self->{__config};
    my $server = $self->{__server};
    
    my $seqno = $self->{__seqno}++;
    my $secret = $server->getSecret;
    my $code = COMM_WELCOME;
    $self->__queueMasterExpect ($seqno, 'welcome');
    $self->__queueMasterOutput ($code, $seqno, $secret, $$);
    
    $self->__queueClientOutput ($self->{__banner} . "\nlogin: ", 1);

    my $peer = $self->{__peer};
    my $master = $self->{__master_sock};

    my $rsel = IO::Select->new ($peer, $master);
    my $esel = IO::Select->new ($peer, $master);
                
    while (1) {
        my $wsel = IO::Select->new;
        
        $wsel->add ($peer) 
            if !empty $self->{__client_out};
        $wsel->add ($master) 
            if !empty $self->{__master_out};
        
        my ($rout, $wout, $eout) = IO::Select->select ($rsel, $wsel, $esel,
                                                       0.1);

        foreach my $fh (@$eout) {
            my $fileno = fileno $fh;
            $logger->error ("Exception on socket!\n");
            exit 1;
        }

        foreach my $fh (@$wout) {
            if ($fh == $peer && !empty $self->{__client_out}) {
                my $l = length $self->{__client_out};
                my $bytes_written = syswrite ($peer, $self->{__client_out});
                if (!defined $bytes_written) {
                    if (!$!{EAGAIN} && !$!{EWOULDBLOCK}) {
                        $logger->info ("$self->{__ip} dropped connection.");
                        return $self;
                    }
                } else {
                    if (0 == $bytes_written) {
                        $logger->info ("$self->{__ip} dropped connection.");
                        return $self;
                    }
                    substr $self->{__client_out}, 0, $bytes_written, '';
                }
            } elsif ($fh == $master && !empty $self->{__master_out}) {
                my $l = length $self->{__master_out};
                my $bytes_written = syswrite ($master, $self->{__master_out});
                if (!defined $bytes_written) {
                    if (!$!{EAGAIN} && !$!{EWOULDBLOCK}) {
                        $logger->fatal ("Lost connection to master.");
                    }
                    next;
                } else {
                    if (0 == $bytes_written) {
                        $logger->fatal ("Lost connection to master.");
                        return $self;
                    }
                    substr $self->{__master_out}, 0, $bytes_written, '';
                }
            }
        }

        foreach my $fh (@$rout) {
            if ($fh == $peer) {
                my $offset = length $self->{__client_in};
                my $bytes_read = sysread ($peer, $self->{__client_in}, 4096, 
                                          $offset);
                if (!defined $bytes_read) {
                    if (!$!{EAGAIN} && !$!{EWOULDBLOCK}) {
                        $logger->info ("$self->{__ip} dropped connection.");
                        return $self;
                    }
                } else {
                    if (0 == $bytes_read) {
                        $logger->info ("$self->{__ip} dropped connection.");
                        return $self;
                    }
                    if (length $self->{__client_in} 
                        > $config->{max_chunk_size}) {
                        $logger->warning ("Too much data from $self->{__ip}.");
                        return $self;
                    }
                    $self->__checkClientInput;
                }
            } elsif ($fh == $master) {
                my $offset = length $self->{__master_in};
                my $bytes_read = sysread ($master, $self->{__master_in}, 4096, 
                                          $offset);
                if (!defined $bytes_read) {
                    if (!$!{EAGAIN} && !$!{EWOULDBLOCK}) {
                        $logger->fatal ("Lost connection to master.");
                        return $self;
                    }
                    next;
                } else {
                    if (0 == $bytes_read) {
                        $logger->info ("Lost connection to master.");
                        return $self;
                    }
                    $self->__checkMasterInput;
                }
            }
        }                
    }
    
    return $self;
}

sub __checkClientInput {
    my ($self) = @_;

    return if $self->{__client_in} !~ s/(.*?)\012?\015//;
    
    my $input = $1;
    
    # Strip-off possible echo on request.
    # FIXME: Handle other telnet options as well?
    $input =~ s/^@{[TELNET_ECHO_ON]}//;
    
    # FIBS is seven-bit only.
    $input =~ s/[\x80-\xff]/?/g;
    
    $input =~ s/^[ \t\r]+//;
    $input =~ s/[ \t\r]+$//;
    
    my $state = $self->{__state};
    if ('login' eq $state) {
        if ('guest' eq $input) {
            return $self->__guestLogin;
        } else {
            $self->{__state} = 'pwprompt';
            $self->{__name} = $input;
            $self->__queueClientOutput ("password: ", 1);
            $self->__queueClientOutput (TELNET_ECHO_OFF, 1);
            return $self;
        }
    } elsif ('pwprompt' eq $state) {
        return $self->__login ($self->{__name}, $input);
    } elsif ('password1' eq $state) {
        return $self->__checkPassword1 ($input);
    } elsif ('password2' eq $state) {
        return $self->__checkPassword2 ($input);
    }
    
    return if empty $input;
    
    my @tokens = split /[ \t\r]+/, $input, 2;

    if ('name' eq $self->{__state} && 'name' eq $tokens[0]) {
        return $self->__checkName ($tokens[1]);
    }
    
    $self->__queueClientOutput ("** Unknown command: '$tokens[0]'\n");
    
    return $self;
}

sub __queueMasterExpect {
    my ($self, $seqno, $handler) = @_;
    
    $self->{__logger}->debug ("Queing response handler `$handler' for"
                              . " sequence number $seqno.");
    $self->{__expect}->{$seqno} = $handler;
    
    return $self;
}

sub __checkMasterInput {
    my ($self) = @_;

    my $logger = $self->{__logger};

    return if $self->{__master_in} !~ s/(.*?)\n//;
    
    my $input = $1;

    $logger->debug ("Got master input $input.");
    
    my ($code, $payload) = split / /, $input, 2;
    if (!exists MASTER_HANDLERS->{$code}) {
        $logger->fatal ("Unknown opcode $code from master.");
    }
    
    my $handler = ucfirst MASTER_HANDLERS->{$code};
    $handler =~ s/(_.)/uc $1/eg;
    my $method = '__handleMaster' . ucfirst MASTER_HANDLERS->{$code};
    
    return $self->$method ($payload);
}

sub __login {
    my ($self, $name, $password) = @_;
    
    my $logger = $self->{__logger};
    
    $logger->debug ("Checking credentials for `$name'.");
    
    $self->{state} = 'logging_in';
    
    my $seqno = $self->{__seqno}++;
    $self->__queueMasterExpect ($seqno, 'login');
    $self->__queueMasterOutput (COMM_AUTHENTICATE, $seqno, $name, $self->{__ip},
                                $password);
    
    return $self;
}

sub __handleMasterAck {
    my ($self, $payload) = @_;
    
    my ($seqno, $rest) = split / /, $payload, 2;
    
    my $logger = $self->{__logger};
    
    $logger->fatal ("Unexpected ack from master with sequence number $seqno.")
        if !exists $self->{__expect}->{$seqno};
    
    my $handler = ucfirst $self->{__expect}->{$seqno};
    $handler =~ s/_(.)/uc $1/eg;
    my $method = '__handleMasterAck' . $handler;
    
    return $self->$method ($rest);
}

sub __handleMasterAckWelcome {
    my ($self) = @_;
    
    $self->{__logger}->debug ("Client received ack welcome.");
    
    return $self;
}

sub __handleMasterAckNameAvailable {
    my ($self, $msg) = @_;

    my $logger = $self->{__logger};
        
    my ($name, $available) = split / /, $msg;
    if (!$available) {
        $logger->debug ("Name `$name' is not available.");
        $self->{__state} = 'name';
        return $self->__queueClientOutput ("** Please use another name. '$name'"
                                           . " is already used by someone"
                                           . " else.\n");
    }
    
    $logger->debug ("Name `$name' is available.");
    $self->__queueClientOutput (<<EOF, 1);
Your name will be $name
Type in no password and hit Enter/Return if you want to change it now.
EOF

    $self->__queueClientOutput ("Please give your password: ", 1);
    $self->__queueClientOutput (TELNET_ECHO_OFF, 1);
    
    $self->{__state} = 'password1';
    
    return $self;
}

sub __handleMasterAckUserCreated {
    my ($self, $msg) = @_;

    my $logger = $self->{__logger};
        
    my ($name, $created) = split / /, $msg;
    if (!$created) {
        $logger->debug ("Name `$name' is not available.");
        $self->{__state} = 'name';
        return $self->__queueClientOutput ("** Please use another name. '$name'"
                                           . " is already used by someone"
                                           . " else.\n");
    }
    
    $logger->notice ("User `$name' account created.");
    $self->__queueClientOutput (<<EOF);
You are registered.
Type 'help beginner' to get started.
EOF

    $self->__login ($name, $self->{__password});
    
    return $self;
}

sub __handleMasterAckLogin {
    my ($self, $msg) = @_;

    my $logger = $self->{__logger};

    my ($status, @props) = split / /, $msg;
    
    if (!$status) {
        $self->{__status} = 'login';
        $logger->debug ("Authentication failed");
        return $self;
    }
    
    $logger->debug ("Somebody ??? logged in.");
    
    return $self;
}

sub __queueClientOutput {
    my ($self, $text, $no_prompt) = @_;
    
    $text =~ s/\n/\012\015/g;
    
    $self->{__client_out} .= $text;
    if ($self->{__telnet} && !$no_prompt && "\012\015" eq substr $text, -2, 2) {
        $self->{__client_out} .= "> ";
    }

    return $self;
}

sub __queueMasterOutput {
    my ($self, $code, @args) = @_;
    
    $self->{__master_out} .= (join ' ', $code, @args) . "\n";
    
    return $self;
}

sub __guestLogin {
    my ($self) = @_;
    
    $self->{__state} = 'name';
    
    $self->__queueClientOutput (<<EOF);
Welcome to OpenFIBS. You just logged in as guest.
Please register before using this server:

Type 'name username' where name is the word 'name' and 
username is the login name you want to use.
The username may not contain blanks ' ' or colons ':'.
The system will then ask you for your password twice.
Please make sure that you don't forget your password. All
passwords are encrypted before they are saved. If you forget
your password there is no way to find out what it was.
Please type 'bye' if you don't want to register now.

ONE USERNAME PER PERSON ONLY!!!
EOF

    return $self;
}

sub __checkName {
    my ($self, $name) = @_;
    
    $self->{__logger}->debug ("Check new username `$name'.");

    return $self->__queueClientOutput ("** Your name may only contain letters"
                                       . " and the underscore character _ .\n")
        if empty $name;

    return $self->__queueClientOutput ("** Your name may only contain letters"
                                       . " and the underscore character _ .\n")
        if $name =~ /[^A-Za-z_]/;
    
    return $self->__queueClientOutput ("** Please use another name. '$name'"
                                       . " is already used by someone else.\n")
        if $name eq 'guest';
        
    my $seqno = $self->{__seqno}++;
    $self->__queueMasterExpect ($seqno, 'name_available');
    $self->__queueMasterOutput (COMM_NAME_AVAILABLE, $seqno, $name);
    
    $self->{__state} = 'name_check';
    $self->{__name} = $name;
        
    return $self;
}

sub __checkPassword1 {
    my ($self, $password) = @_;
    
    my $logger = $self->{__logger};
    
    $self->__queueClientOutput ("\n", 1);
    
    if (empty $password) {
        $logger->debug ("Password was empty.");
        $self->__queueClientOutput ("** No password given. Please choose a"
                                    . " new name\n");
        $self->{__state} = 'name';
    } elsif (4 > length $password) {
        $logger->debug ("Password too short.");
        $self->__queueClientOutput ("Minimal password length is 4 characters.\n",
                                    1);
    } elsif (-1 != index $password, ':') {
        $logger->debug ("Password contains a colon.");
        $self->__queueClientOutput ("Your password may not contain ':'\n",
                                    1);
    } else {
        $logger->debug ("Password is acceptable.");
        $self->__queueClientOutput ("Please retype your password: ", 1);
        $self->__queueClientOutput (TELNET_ECHO_OFF, 1);
        $self->{__state} = 'password2';
        $self->{__password} = $password;
    }
    
    return $self;
}

sub __checkPassword2 {
    my ($self, $password) = @_;
    
    my $logger = $self->{__logger};
    
    $self->__queueClientOutput ("\n", 1);
    
    if (empty $password || $password ne $self->{__password}) {
        $logger->debug ("Password mismatch.");
        $self->__queueClientOutput ("** The two passwords were not identical."
                                    . " Please give them again. Password: ", 1);
        $self->__queueClientOutput (TELNET_ECHO_OFF, 1);
        $self->{__state} = 'password1';
    } else {
        my $seqno = $self->{__seqno}++;
        # Password must come last because it may contain spaces!
        $self->__queueMasterExpect ($seqno, 'user_created');
        $self->__queueMasterOutput (COMM_CREATE_USER, $seqno, 
                                    $self->{__name}, $self->{__ip},
                                    $password);
    }

    delete $self->{__password};
    
    return $self;
}

1;

=head1 NAME

OpenFIBS::Server::Session - Connection to one client

=head1 SYNOPSIS

  use OpenFIBS::Server::Session;
  
  my $session = OpenFIBS::Server::Session->new ($server, $ip);
  $session->run;

=head1 DESCRIPTION

B<OpenFIBS::Server::Session> encapsulates one client connection.  It handles
all the communication with the peer and the OpenFIBS master.

The class is internal to OpenFIBS.

=head1 SEE ALSO

OpenFIBS::Server(3pm), openfibs(1), perl(1)

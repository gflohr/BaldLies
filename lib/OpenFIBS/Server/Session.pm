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
use MIME::Base64 qw (decode_base64);
use Storable qw (thaw);

use OpenFIBS::Util qw (empty format_time);
use OpenFIBS::Const qw (:comm);
use OpenFIBS::User;

use constant MASTER_HANDLERS => {
    MSG_ACK, 'ack',
    MSG_LOGIN, 'login',
    MSG_LOGOUT, 'logout',
    MSG_KICK_OUT, 'kick_out',
};

use constant TELNET_ECHO_WILL => "\xff\xfb\x01";
use constant TELNET_ECHO_WONT => "\xff\xfc\x01";
use constant TELNET_ECHO_DO => "\xff\xfd\x01";
use constant TELNET_ECHO_DONT => "\xff\xfe\x01";

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
        __clip => 0,
        __seqno => 0,
        __expect => {},
        __dispatcher => $server->getDispatcher,
        __users => {},
        __client => '-',
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

    $self->{__motd} = <<EOF;
+--------------------------------------------------------------------+
|                                                                    |
|  Welcome to OpenFIBS!                                              |
|                                                                    |
|  If you have 8 or more unfinished games, you will be unable to     |
|  start new games.                                                  |
|                                                                    |
|  Remember: you are only allowed to have one account.               |
|                                                                    |
+--------------------------------------------------------------------+
EOF

    $self->{__bye_msg} = <<EOF;
Thanks for using this server!
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
                
    while (1) {
        my $wsel = IO::Select->new;
        
        $wsel->add ($peer) 
            if !empty $self->{__client_out};
        $wsel->add ($master) 
            if !empty $self->{__master_out};
        
        my ($rout, $wout, undef) = IO::Select->select ($rsel, $wsel, undef,
                                                       0.1);
        
        my $user = $self->{__user};
        my $ident = $user ? "`$user->{name}'" : "unauthenticated user";
        foreach my $fh (@$wout) {
            if ($fh == $peer && !empty $self->{__client_out}) {
                my $l = length $self->{__client_out};
                my $bytes_written = syswrite ($peer, $self->{__client_out});
                if (!defined $bytes_written) {
                    if (!$!{EAGAIN} && !$!{EWOULDBLOCK}) {
                        $logger->info ("$ident dropped connection.");
                        return $self;
                    }
                } else {
                    if (0 == $bytes_written) {
                        $logger->info ("$ident dropped connection.");
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

        if ($self->{__quit}) {
            $logger->info ("$ident logging out.");
            return $self;
        }
        
        foreach my $fh (@$rout) {
            if ($self->{__ready} && $fh == $peer) {
                my $offset = length $self->{__client_in};
                my $bytes_read = sysread ($peer, $self->{__client_in}, 4096, 
                                          $offset);
                if (!defined $bytes_read) {
                    if (!$!{EAGAIN} && !$!{EWOULDBLOCK}) {
                        $logger->info ("$ident dropped connection.");
                        return $self;
                    }
                } else {
                    if (0 == $bytes_read) {
                        $logger->info ("$ident dropped connection.");
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

sub getLogger {
    shift->{__logger};
}

sub getDispatcher {
    shift->{__dispatcher};
}

sub reply {
    my ($self, $what, $no_prompt) = @_;
    
    $what = '' if empty $what;
    chomp $what;
    $what .= "\n";
    
    $self->__queueClientOutput ($what, $no_prompt);
    
    return $self;
}

sub broadcast {
    my ($self, $msg) = @_;
    
    my $logger = $self->{__logger};
    $logger->error ("Broadcast not yet implemented: $msg");
    
    return $self;
}

sub quit {
    my ($self) = @_;
    
    $self->__queueClientOutput ($self->{__bye_msg}, 1);
    $self->{__quit} = 1;
    
    return $self;
}

sub getClip {
    shift->{__clip};
}

sub getMottoOfTheDay {
    shift->{__motd}
}

sub getUsers {
    shift->{__users}
}

sub __checkClientInput {
    my ($self) = @_;

    return if $self->{__client_in} !~ s/(.*?)\015?\012//;

    my $logger = $self->{__logger};
    
    my $input = $1;
    
    # Strip-off possible echo on request.
    # FIXME: Handle other telnet options as well?
    $input =~ s/\xff.\x01//;
    
    # FIBS is seven-bit only.
    $input =~ s/[\x80-\xff]/?/g;
    
    $input =~ s/^[ \t\r]+//;
    $input =~ s/[ \t\r]+$//;
    
    my $state = $self->{__state};
    if ('login' eq $state) {
        return $self->__parseLogin ($input);
    } elsif ('pwprompt' eq $state) {
        return $self->__login ($self->{__name}, $input);
    } elsif ('password1' eq $state) {
        return $self->__checkPassword1 ($input);
    } elsif ('password2' eq $state) {
        return $self->__checkPassword2 ($input);
    }
    
    if (empty $input) {
        if (!$self->{__clip}) {
            $self->__queueClientOutput ('> ', 1);
        }
        return $self;
    }
    
    my @tokens = split /[ \t\r]+/, $input, 2;

    if ('name' eq $self->{__state}) {
        # FIBS is NOT case-insensitive in this state.  It also does not
        # support auto-completion.
        return $self->__checkName ($tokens[1])
            if 'name' eq $tokens[0];
        return $self->quit if 'bye' eq $tokens[0];
        return $self->__guestLogin;
    }

    eval { $self->{__dispatcher}->execute ($self, @tokens) };
    $logger->fatal ($@) if $@;

    return $self;
}

sub __parseLogin {
    my ($self, $input) = @_;
    
    return $self->__guestLogin if 'guest' eq $input;

    # CLIP login?
    my ($magic, $client, $clip, $name, $password) = split /[ \t]+/, $input;
    if ('login' eq $magic && !empty $password) {
        $self->{__clip} = $clip;
        $self->{__name} = $name;
        $self->{__password} = $password;
        $self->{__client} = $client;
        return $self->__login ($name, $password);
    }

    $self->{__state} = 'pwprompt';
    $self->{__name} = $input;
    $self->__queueClientOutput (TELNET_ECHO_WILL, 1);
    $self->__queueClientOutput ("password: ", 1);
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

    # $logger->debug ("Got master input $input.");
    
    my ($code, $payload) = split / /, $input, 2;
    if (!exists MASTER_HANDLERS->{$code}) {
        $logger->fatal ("Unknown opcode $code from master.");
    }
    
    my $handler = ucfirst MASTER_HANDLERS->{$code};
    $handler =~ s/_(.)/uc $1/eg;
    my $method = '__handleMaster' . $handler;
    
    return $self->$method ($payload);
}

sub __login {
    my ($self, $name, $password) = @_;
    
    $self->__queueClientOutput ("\n", 1) if !$self->{__clip};
    
    my $logger = $self->{__logger};
    
    $logger->debug ("Checking credentials for `$name'.");
    
    $self->{state} = 'logging_in';
    
    my $seqno = $self->{__seqno}++;
    $self->__queueMasterExpect ($seqno, 'login');
    $self->__queueMasterOutput (COMM_AUTHENTICATE, $seqno, $name, $self->{__ip},
                                $self->{__client}, $password);
    
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
    $self->{__ready} = 1;
    
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

    $self->__queueClientOutput (TELNET_ECHO_WILL, 1);
    $self->__queueClientOutput ("Please give your password: ", 1);
    
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
    my $welcome = <<EOF;
You are registered.
Type 'help beginner' to get started.
EOF
    chomp $welcome;
    $self->__queueClientOutput ($welcome, 1);

    $self->{__first_login} = 1;
    $self->__login ($name, delete $self->{__password});
    
    return $self;
}

sub __handleMasterAckLogin {
    my ($self, $msg) = @_;

    my $logger = $self->{__logger};

    my ($status, $payload) = split / /, $msg;
    
    if (!$status) {
        $self->{__state} = 'login';
        delete $self->{__name};
        delete $self->{__password};
        $self->{__clip} = 0;
        $self->{__client} = '-';
        $logger->debug ("Authentication failed");
        $self->__queueClientOutput (TELNET_ECHO_WONT, 1);
        $self->__queueClientOutput ("\nlogin: ", 1);
        
        return $self;
    }
    
    $self->{__state} = 'logged_in';
    
    # No error checking here.  This will fail if the data is not transmitted
    # correctly.
    $self->{__users} = thaw decode_base64 $payload;
    my $user = $self->{__users}->{$self->{__name}}->copy;

    $logger->debug ("User $user->{name} logged in from $self->{__ip}.");
    
    my $last_host = $user->{last_host} 
        ? "  from $user->{last_host}" : '';
    
    if ($self->{__clip}) {
        $self->__queueClientOutput ("1 $user->{name} $user->{last_host}\n");
        my $own_info = join ' ', @{$user}{
            qw (allowpip autoboard autodouble automove away bell crawford 
                double experience greedy moreboards moves notify rating ratings 
                ready redoubles report silent timezone)
        };
        $self->__queueClientOutput ("2 $own_info\n");
        $self->__motd;
    } else {
        my $last_login = format_time ($user->{last_login} ?
                                      $user->{last_login} : time);
        if (!$self->{__quiet_login}) {
            $self->__queueClientOutput (<<EOF, 1);
** User $user->{name} authenticated.
** Last login: $last_login$last_host
EOF
            $self->__queueClientOutput ("@{[TELNET_ECHO_WONT]}");
            $self->__motd;
        } else {
            $self->__queueClientOutput ("@{[TELNET_ECHO_WONT]}\n");
        }
    }
    
    return $self;
}

sub __motd {
    my ($self) = @_;

    eval { $self->{__dispatcher}->execute ($self, 'motd') };
    $self->{_logger}->fatal ($@) if $@;
    
    return $self;
}

sub __handleMasterLogin {
    my ($self, $data) = @_;
 
    my (@props) = split / /, $data;
    
    my $user = OpenFIBS::User->new (@props);
    my $name = $user->{name};
    $self->{__users}->{$name} = $user;

    if ($self->{__user}->{notify}) {
        my $prefix;
        
        if ($self->{__clip}) {
            $prefix = "7 $name ";
        } else {
            $prefix = "\n";
        }
        $self->__queueClientOutput ("$prefix$name logs in.\n");
    }
    
    return $self;
}

sub __handleMasterLogout {
    my ($self, $name) = @_;
    
    delete $self->{__users}->{$name};
    
    if ($self->{__user}->{notify}) {
        my $prefix;
        
        if ($self->{__clip}) {
            $prefix = "8 $name ";
        } else {
            $prefix = "\n";
        }
        $self->__queueClientOutput ("$prefix$name drops connection.\n");
    }
    
    return $self;
}

sub __handleMasterKickOut {
    my ($self, $msg) = @_;
    
    $self->{__quit} = 1;
    $self->__queueClientOutput ("\n** $msg\n", 1);
    
    $self->{__logger}->info ("Kicked out: $msg");
    
    return $self;
}

sub __queueClientOutput {
    my ($self, $text, $no_prompt) = @_;
    
    $text =~ s/\n/\015\012/g;
    
    $self->{__client_out} .= $text;
    if (!$self->{__clip} && !$no_prompt && "\015\012" eq substr $text, -2, 2) {
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
        $self->__queueClientOutput (TELNET_ECHO_WONT, 1);
        $self->{__state} = 'name';
    } elsif (4 > length $password) {
        $logger->debug ("Password too short.");
        $self->__queueClientOutput ("Minimal password length is 4 characters.\n",
                                    1);
        $self->__queueClientOutput ("Please give your password: ", 1);
    } elsif (-1 != index $password, ':') {
        $logger->debug ("Password contains a colon.");
        $self->__queueClientOutput ("Your password may not contain ':'\n",
                                    1);
        $self->__queueClientOutput ("Please give your password: ", 1);
    } else {
        $logger->debug ("Password is acceptable.");
        $self->__queueClientOutput ("Please retype your password: ", 1);
        $self->__queueClientOutput (TELNET_ECHO_WILL, 1);
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
        $self->__queueClientOutput (TELNET_ECHO_WILL, 1);
        $self->{__state} = 'password1';
    } else {
        my $seqno = $self->{__seqno}++;
        # Password must come last because it may contain spaces!
        $self->__queueMasterExpect ($seqno, 'user_created');
        $self->__queueMasterOutput (COMM_CREATE_USER, $seqno, 
                                    $self->{__name}, $self->{__ip},
                                    $password);
    }

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

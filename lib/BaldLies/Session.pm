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

package BaldLies::Session;

use strict;

use Fcntl qw (F_GETFL F_SETFL O_NONBLOCK);
use IO::Select;
use IO::Socket::UNIX;

use BaldLies::Util qw (empty);
use BaldLies::User;
use BaldLies::Const qw (:telnet);

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
        __cmd_dispatcher => $server->getCommandDispatcher,
        __msg_dispatcher => $server->getMessageDispatcher,
        __users => {},
        __client => '-',
    };

    my $logger = $self->{__logger} = $server->getLogger;
    $logger->ip ($ip . ':' . $$);
    my $config = $self->{__config} = $server->getConfig;
    $self->{__banner} = <<EOF;
                           ************************
                           * Welcome to BaldLies! *
                           ************************

Please login as guest if you do not have an account on this server.
EOF

    $self->{__motd} = <<EOF;
+--------------------------------------------------------------------+
|                                                                    |
|  Welcome to BaldLies!                                              |
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
    
    my $secret = $server->getSecret;
    my $code = 'welcome';
    $self->sendMaster (hello => $secret, $$);
    
    $self->reply ($self->{__banner} . "\nlogin: ", 1);

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
                    while ($self->{__client_in} =~ /\n/) {
                        $self->__checkClientInput;
                    }
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
                    while ($self->{__master_in} =~ /\n/) {
                        $self->__checkMasterInput;
                    }
                }
            }
        }      
    }
    
    return $self;
}

sub reinit {
    my ($self) = @_;
    
    $self->setState ('login');
    delete $self->{__name};
    delete $self->{__password};
    $self->{__clip} = 0;
    $self->{__client} = '-';

    return $self;
}

sub getLogger {
    shift->{__logger};
}

sub getCommandDispatcher {
    shift->{__cmd_dispatcher};
}

sub getMessageDispatcher {
    shift->{__msg_dispatcher};
}

sub broadcast {
    my ($self, @payload) = @_;
    
    $self->sendMaster (broadcast => @payload);
    
    return $self;
}

sub clipBroadcast {
    my ($self, $sender, $code, @payload) = @_;
    
    $self->sendMaster (clip_broadcast => $sender, $code, @payload);
    
    return $self;
}

sub clipTell {
    my ($self, $recipient, $code, @payload) = @_;
    
    $self->sendMaster (clip_tell => $recipient, $code, @payload);
    
    return $self;
}

sub quit {
    my ($self, $silent) = @_;
    
    $self->reply ($self->{__bye_msg}, 1) unless $silent;
    $self->{__quit} = 1;
    
    return $self;
}

sub getClip {
    shift->{__clip};
}

sub getMottoOfTheDay {
    shift->{__motd};
}

sub getUsers {
    shift->{__users};
}

sub addUser {
    my ($self, $user) = @_;
    
    $self->{__users}->{$user->{name}} = $user;
    
    return $self;
}

sub removeUser {
    my ($self, $name) = @_;
    
    delete $self->{__users}->{$name};
    
    return $self;
}

sub getUser {
    shift->{__user};
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
    $input =~ s/\t/        /g;
    
    my $state = $self->{__state};
    if ('login' eq $state) {
        return $self->__parseLogin ($input);
    } elsif ('pwprompt' eq $state) {
        return $self->login ($self->{__name}, $input);
    } elsif ('password1' eq $state) {
        return $self->__checkPassword1 ($input);
    } elsif ('password2' eq $state) {
        return $self->__checkPassword2 ($input);
    }
    
    if (empty $input) {
        if (!$self->{__clip}) {
            $self->reply ('> ', 1);
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

    eval { $self->{__cmd_dispatcher}->execute ($self, @tokens) };
    $logger->error ($@) if $@;

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
        return $self->login ($name, $password);
    }

    $self->{__state} = 'pwprompt';
    $self->{__name} = $input;
    $self->reply (TELNET_ECHO_WILL, 1);
    $self->reply ("password: ", 1);
    return $self;
}

sub __checkMasterInput {
    my ($self) = @_;

    my $logger = $self->{__logger};

    return if $self->{__master_in} !~ s/(.*?)\n//;
    
    my $input = $1;

    my ($msg, $payload) = split / /, $input, 2;
    
    eval { $self->{__msg_dispatcher}->execute ($self, $msg, $payload) };
    $logger->error ($@) if $@;
    
    return $self;
}

sub login {
    my ($self, $name, $password) = @_;
    
    $self->reply ("\n", 1) if !$self->{__clip};
    
    my $logger = $self->{__logger};
    
    $logger->debug ("Checking credentials for `$name'.");
    
    $self->{state} = 'logging_in';
    
    $self->sendMaster ('authenticate', $name, $self->{__ip},
                                $self->{__client}, $password);
    
    return $self;
}

sub setReady {
    my ($self, $ready) = @_;
    
    $self->{__ready} = $ready;
    
    return $self;
}

sub setState {
    my ($self, $state) = @_;
    
    $self->{__state} = $state;
    
    return $self;
}

sub getState {
    shift->{__state};
}

sub getLogin {
    shift->{__name};
}

sub setUsers {
    my ($self, $users) = @_;
    
    $self->{__users} = $users;
    
    return $self;
}

sub setUser {
    my ($self, $user) = @_;
    
    $self->{__user} = $user;
    
    return $self;
}

sub getIP {
    shift->{__ip};
}

sub stealPassword {
    delete shift->{__password};
}

sub motd {
    my ($self) = @_;

    $self->{__cmd_dispatcher}->execute ($self, 'motd');
    
    return $self;
}

sub reply {
    my ($self, $text, $no_prompt) = @_;
    
    $text = '' if empty $text;
    
    $text =~ s/\n/\015\012/g;
    
    $self->{__client_out} .= $text;
    if (!$self->{__clip} && !$no_prompt && "\015\012" eq substr $text, -2, 2) {
        $self->{__client_out} .= "> ";
    }

    return $self;
}

my @non_clip_handlers = (
    # 0 is unused.
    undef,
    # 1 (welcome), not used in this context.
    undef,
    # 2 (owninfo), not used in this context.
    undef,
    # 3 and 4 (motd), not used in this context.
    undef,
    undef,
    # 5 and 6 (who info), discarded in telnet mode.
    sub {
        $_[0] = '',
    },
    sub {
        $_[0] = '',
    },
    # 7 (login) someplayer someplayer logs in.
    sub {
        $_[0] =~ s/[^ ]+ //;
    },
    # 8 (logout) someplayer someplayer drops connection.
    sub {
        $_[0] =~ s/[^ ]+ //;
    },
    # 9 (message) from time message
    sub {
        $_[0] =~ s/([^ ]+) [1-9]|[0-9]*/Message from $1:/;
    },
    # 10 (message delivered) recipient, not used in this context.
    undef,
    # 11 (message saved) recipient, not used in this context.
    undef,
    # 12 (says) name message
    sub {
        $_[0] =~ s/([^ ]+)/$1 says:/;
    },
    # 13 (shouts) name message
    sub {
        $_[0] =~ s/([^ ]+)/$1 shouts:/;
    },
    # 14 (shouts) name message
    sub {
        $_[0] =~ s/([^ ]+)/$1 whispers:/;
    },
    # 15 (kibitzes) name message
    sub {
        $_[0] =~ s/([^ ]+)/$1 kibitzes:/;
    },
    # 16 (you tell) recipient message
    sub {
        $_[0] =~ s/([^ ]+)/** You tell $1:/;
    },
    # 17 (you shout) recipient message
    sub {
        $_[0] =~ s/([^ ]+)/** You shout $1:/;
    },
    # 18 (you whisper) recipient message
    sub {
        $_[0] =~ s/([^ ]+)/** You whisper $1:/;
    },
    # 19 (you kibitz) recipient message
    sub {
        $_[0] =~ s/([^ ]+)/** You kibitz $1:/;
    },
);

sub clipReply {
    my ($self, $opcode, @text) = @_;
    
    my $text = join ' ', @text;
    if (!$self->getClip && $opcode < @non_clip_handlers) {
        $non_clip_handlers[$opcode]->($text);
        return $self->reply ("\n$text") if !empty $text;
    } else {
        return $self->reply (join ' ', $opcode, $text);
    }
}

sub sendMaster {
    my ($self, $code, @args) = @_;
    
    $self->{__master_out} .= (join ' ', $code, @args) . "\n";
    
    return $self;
}

sub __guestLogin {
    my ($self) = @_;
    
    $self->{__state} = 'name';
    
    $self->reply (<<EOF);
Welcome to BaldLies. You just logged in as guest.
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

    return $self->reply ("** Your name may only contain letters"
                         . " and the underscore character _ .\n")
        if empty $name;

    return $self->reply ("** Your name may only contain letters"
                         . " and the underscore character _ .\n")
        if $name =~ /[^A-Za-z_]/;
    
    return $self->reply ("** Please use another name. '$name'"
                         . " is already used by someone else.\n")
        if $name eq 'guest';
        
    $self->sendMaster (check_name => $name);
    
    $self->{__state} = 'name_check';
    $self->{__name} = $name;
        
    return $self;
}

sub __checkPassword1 {
    my ($self, $password) = @_;
    
    my $logger = $self->{__logger};
    
    $self->reply ("\n", 1);
    
    if (empty $password) {
        $logger->debug ("Password was empty.");
        $self->reply ("** No password given. Please choose a"
                      . " new name\n");
        $self->reply (TELNET_ECHO_WONT, 1);
        $self->{__state} = 'name';
    } elsif (4 > length $password) {
        $logger->debug ("Password too short.");
        $self->reply ("Minimal password length is 4 characters.\n",
                      1);
        $self->reply ("Please give your password: ", 1);
    } elsif (-1 != index $password, ':') {
        $logger->debug ("Password contains a colon.");
        $self->reply ("Your password may not contain ':'\n", 1);
        $self->reply ("Please give your password: ", 1);
    } else {
        $logger->debug ("Password is acceptable.");
        $self->reply ("Please retype your password: ", 1);
        $self->reply (TELNET_ECHO_WILL, 1);
        $self->{__state} = 'password2';
        $self->{__password} = $password;
    }
    
    return $self;
}

sub __checkPassword2 {
    my ($self, $password) = @_;
    
    my $logger = $self->{__logger};
    
    $self->reply ("\n", 1);
    
    if (empty $password || $password ne $self->{__password}) {
        $logger->debug ("Password mismatch.");
        $self->reply ("** The two passwords were not identical."
                                    . " Please give them again. Password: ", 1);
        $self->reply (TELNET_ECHO_WILL, 1);
        $self->{__state} = 'password1';
    } else {
        # Password must come last because it may contain spaces!
        $self->sendMaster (create_user => $self->{__name}, 
                                    $self->{__ip}, $password);
    }

    return $self;
}

1;

=head1 NAME

BaldLies::Server::Session - Connection to one client

=head1 SYNOPSIS

  use BaldLies::Server::Session;
  
  my $session = BaldLies::Server::Session->new ($server, $ip);
  $session->run;

=head1 DESCRIPTION

B<BaldLies::Server::Session> encapsulates one client connection.  It handles
all the communication with the peer and the BaldLies master.

The class is internal to BaldLies.

=head1 SEE ALSO

BaldLies::Server(3pm), baldlies(1), perl(1)

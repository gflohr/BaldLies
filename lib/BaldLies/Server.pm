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

package BaldLies::Server;

use strict;

use File::Spec;
use File::Path;
use IO::Handle;
use IO::File;
use Fcntl qw (:DEFAULT :flock F_GETFL F_SETFL O_NONBLOCK :mode);
use Socket qw (AF_INET);
use Time::HiRes qw (usleep tv_interval gettimeofday);
use POSIX qw (:sys_wait_h setsid setlocale LC_ALL);

use BaldLies::Util qw (empty untaint);
use BaldLies::Const qw (:log_levels);
use BaldLies::Logger;
use BaldLies::Master;
use BaldLies::Session;
use BaldLies::Server::Listener;
use BaldLies::Session::CommandDispatcher;
use BaldLies::Session::MessageDispatcher;

use version 0.77;
our $VERSION = version->declare("0.1.0");

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
    $self->{__config} = { %options };
    $self->{__children} = {};
           
    bless $self, $class;
}

sub __reopenLogger {
    my ($self) = @_;

    my $config = $self->{__config};
    my $logfile = $config->{logfile};
    
    my %options = (
        level => $config->{verbose},
        logfile => $logfile
    );
    
    if ($config->{debug}) {
        my $stderr = IO::Handle->new;
        $stderr->fdopen (fileno (STDERR), 'w');
        $options{stderr} = $stderr;
    }
    my $logger = BaldLies::Logger->new (%options);
    $self->{__logger} = $logger;
    
    # For the rest, make sure that our logfile exists.  This leaves plenty
    # of room for race conditions but we completely ignore that.  The only
    # protection against parallel execution comes from the pid file.
    # But apart from that, we give every user a fair chance to mess things up.
    if (!-e $logfile) {
        local *HANDLE;
        open HANDLE, ">>$logfile"
            or $logger->fatal ("Cannot open logfile `$logfile' for"
                               . " writing: $!!");
    }
    
    my @stat = stat $logfile
        or $logger->fatal ("Cannot stat logfile `$logfile': $!!");
    
    my $mode = $stat[2];
    if (!($mode & S_IWUSR)) {
        $mode |= S_IWUSR;
        chmod $mode, $logfile
            or $logger->fatal ("Cannot user write permissions to logfile"
                               . " `$logfile': $!!");
    }
            
    # Change ownership of our log file but only, when we are root and are
    # told to switch persona to non-root.
    if (!$>) {
        my ($uid, $gid) = @stat[4, 5];
       
        if ($config->{uid} && $config->{uid} != $uid) {
            chown $config->{uid}, $gid, $logfile
                or $logger->fatal ("Cannot change ownership of logfile"
                                   . " `$logfile': $!!");
        }
    }

    $logger->debug ("Logfile `$logfile' initialized.\n");
    
    return $self;
}

sub run {
    my ($self) = @_;
    
    $self->__readConfiguration;
    my $config = $self->{__config};
    $self->__lockDaemon ($$);
    $self->__reopenLogger;
    my $logger = $self->{__logger};
    $self->__openPorts;
    $self->__changePersona;
    $self->__upgradeDatabaseSchema;
    $self->__absolutizeINC if !$config->{debug};
    $self->__loadMessageDispatcher;
    $self->__loadCommandDispatcher;
    $self->__daemonize if !$config->{debug};
    eval {
        $self->__generateSecret;    
        $self->__setupSignals;
        $self->__startMaster;
        $self->__createACLs;    
    
        $logger->notice ("BaldLies server $VERSION starting.");
        $logger->notice ("Running as $self->{__user}:$self->{__group}.\n");
    };
    if ($@) {
        return $self->shutdownServer ($@);
    };
    

    my $listeners = $self->{__listeners};
    eval {
        while (1) {
            foreach my $listener (@$listeners) {
                my $sock = $listener->accept;
                next if !$sock;
                eval { $self->__handleConnection ($listener, $sock) };
                $logger->error ($@) if $@;
            }
            $self->{__master}->checkInput;
        }
    };
    while ($@) {
        my $exception = $@;
        eval { $self->shutdownServer ($exception) };
    }
}

sub shutdownServer {
    my ($self, @messages) = @_;
    
    my $exit_code = @messages ? 1 : 0;
    
    my $logger = $self->{__logger};
    
    $logger->error (@messages);
    $logger->notice ("Server starting shutdown sequence.");

    while (@{$self->{__listeners}}) {
        my $listener = shift @{$self->{__listeners}};
        my $address = $listener->ip . ':' . $listener->port;
        $logger->debug ("Shutting down listener on $address.");
        $listener->shutdown (2);
        $logger->debug ("Closing listener on $address.");
        $listener->close;
    }
    
    foreach my $pid (keys %{$self->{__children}}) {
        $logger->debug ("Killing child $pid.");
        kill 15 => $pid;
    }

    $self->{__master}->close if $self->{__master};

    $logger->notice ("Shutdown complete, server exiting with code $exit_code.");
    
    # ptkdb overloads exit().
    CORE::exit ($exit_code);
}

sub __absolutizeINC {
    my ($self) = @_;

    # Weed out '.'.
    @INC = grep {! /^\.\.?$/ } @INC;

    foreach my $path (@INC) {
        next if File::Spec->file_name_is_absolute ($path);
        $path = File::Spec->rel2abs ($path);
        $path =~ /^(.*)$/;
	$path = $1;
    }

    return $self;
}

sub __loadMessageDispatcher {
    my ($self) = @_;
    
    my $logger = $self->{__logger};
    
    $logger->debug ("Loading message plug-ins in \@INC.");
    
    my $reload = $self->{__config}->{auto_recompile};
    
    my $realm = 'BaldLies::Session::Message';
    $self->{__msg_dispatcher} = 
        BaldLies::Session::MessageDispatcher->new (realm => $realm,
                                                   logger => $logger, 
                                                   inc => \@INC,
                                                   reload => $reload);
    
    return $self;
}

sub __loadCommandDispatcher {
    my ($self) = @_;
    
    my $logger = $self->{__logger};
    
    $logger->debug ("Loading command plug-ins in \@INC.");
    
    my $reload = $self->{__config}->{auto_recompile};
    
    my $realm = 'BaldLies::Session::Command';
    $self->{__cmd_dispatcher} = 
        BaldLies::Session::CommandDispatcher->new (realm => $realm,
                                                   logger => $logger, 
                                                   inc => \@INC,
                                                   reload => $reload);
    
    return $self;
}

sub __generateSecret {
    my ($self) = @_;
    
    my $secret = '';
    
    my @chars = ('A' .. 'Z', 'a' .. 'z', '/', '+');
    
    foreach (1 .. 683) {
        $secret .= $chars[int rand @chars];
    }
    
    $self->{__secret} = $secret;
    
    return $self;
}

sub __handleConnection {
    my ($self, $listener, $sock) = @_;
    
    my $logger = $self->{__logger};
    
    my $sockhost = $sock->sockhost;
    
    $logger->info ("Incoming connection from $sockhost.\n");
    
    $self->__checkAccess ($sock) or return;
    
    my $pid = fork;
    $logger->error ("Cannot fork: $!!") if !defined $pid;
    if (!$pid) {
        eval {
            # Restore signal handlers.
            $SIG{INT} = 'DEFAULT';
            $SIG{TERM} = 'DEFAULT';
            $SIG{HUP} = 'DEFAULT';
            $SIG{QUIT} = 'DEFAULT';
            $SIG{CHLD} = 'DEFAULT';
        
            $self->__unlockDaemon;
            foreach my $l (@{$self->{__listeners}}) {
                $l->close;
            }
            $self->{__master}->close;
            delete $self->{__master};

            my $session = BaldLies::Session->new ($self, $sockhost, $sock);
            $session->run;
        };
        if ($@) {
            $logger->error ($@);
            exit 1;
        }
        exit 0;
    }
    $self->{__children}->{$pid} = 1;
    
    return $self;    
}

sub __checkAccess {
    my ($self, $sock) = @_;
    
    my $remote = $sock->sockhost;

    my $logger = $self->{__logger};    
    $logger->debug ("Checking access from $remote.");

    if ($self->{__ACLs}) {
        my $sockaddr = $sock->sockaddr;
        foreach my $mask (@{$self->{__ACLs}}) {
            return $self if $mask eq ($mask & $sockaddr);
        }
        $logger->warning ("Connection attempt from $remote refused.");
        return;
    } else {
        my $local = $self->{__socket}->sockhost;
    
        return $self if '127.0.0.1' eq $remote;
        return $self if $local eq $remote;
    }
    
    return;
}

sub __startMaster {
    my ($self) = @_;
    
    $self->{__master} = BaldLies::Master->new ($self);
    
    return $self;    
}

sub __sig_fatal {
    my ($signal) = @_;

    die "Received fatal signal SIG$signal.\n";
}

sub __sig_chld {
    my $self = $singleton;
    
    my $logger = $self->{__logger};
    
    while (my $pid = waitpid -1, WNOHANG) {
        last if $pid < 0;
        delete $self->{__children}->{$pid};
        
        my $status = $self->__decodeStatus ($?);
        
        $logger->debug ("Reaped child $pid: $status");
    }
}

sub checkChildPID {
    my ($self, $pid) = @_;
    
    return if !exists $self->{__children}->{$pid};
    
    return $self;
}

sub __daemonize {
    my ($self) = @_;
    
    my $logger = $self->{__logger};
    my $config = $self->{__config};
    
    $logger->notice ("Forking to background.");
    my $pid = fork;
    $logger->fatal ("Cannot fork: $!!") if !defined $pid;

    if (!$pid) {
        # Child code.
        
        $logger->debug ("Changing directory to `/'.");
        chdir '/' or $logger->fatal ("Cannot change directory to `/': $!!");
        
        $logger->debug ("Clearing umask.");
        umask 0;
        
        $logger->debug ("Detaching from controlling tty.");
        $logger->fatal ("Cannot detach from controlling tty: $!!")
            if 0 > setsid;
        
        $logger->debug ("Forking once more.");
        $pid = fork;
        
        $logger->fatal ("Cannot fork: $!!") if !defined $pid;
        
        if (!$pid) {
            # Grand-child code.  This is our actual process.  Both parent
            # and grand-parent will exit soon.
            if (!empty $config->{user}) {
                $logger->debug ("Changing user id to $self->{__uid}.");
                setuid $self->{__uid}
                    or $logger->fatal ("Cannot change user id to"
                                       . " `$self->{__uid}: $!!");
            }
            
            if (!empty $config->{group}) {
                $logger->debug ("Changing group id to $self->{__gid}.");
                setgid $self->{__gid}
                    or $logger->fatal ("Cannot change group id to"
                                       . " `$self->{__gid}: $!!");
            }
        
            $logger->debug ("Redirecting standard input to /dev/null.");
            open STDIN,  "</dev/null"
                or $logger->fatal ("Cannot redirect standard input to"
                                   . " `/dev/null': $!!");
            $logger->debug ("Redirecting standard output to /dev/null.");
            open STDOUT, "+>/dev/null"
                or $logger->fatal ("Cannot redirect standard output to"
                                   . " `/dev/null': $!!");
            $logger->debug ("Redirecting standard error to /dev/null.");
            open STDERR, "+>/dev/null"
                or $logger->fatal ("Cannot redirect standard error to"
                                   . " `/dev/null': $!!");

            return $self;
        }
        
        # Child again.
        $self->__lockDaemon ($pid);
        
        exit;
    }

    $logger->debug ("Child forked with pid $pid.");
       
    # Reap first child.
    if (waitpid $pid, 0) {
        my $status = $self->__decodeStatus ($?);
        $logger->debug ("Reaped child with pid $pid: $status");
    }
    
    exit;
}

sub __setupSignals {
    my ($self) = @_;
    
    $self->{__logger}->debug ("Setting up signal handlers.");

    $SIG{HUP} = \&__sig_fatal;
    $SIG{TERM} = \&__sig_fatal;
    $SIG{QUIT} = \&__sig_fatal;
    $SIG{INT} = \&__sig_fatal;
    $SIG{CHLD} = \&__sig_chld;

    return $self;        
}

sub __decodeStatus {
    my ($self, $status) = @_;
    
    return "Failed to execute." if $status == -1;
    
    if ($status & 127) {
        my $retval = sprintf "Terminated by signal %d, %s coredump.",
            ($status & 127),  ($status & 128) ? 'with' : 'without';
        return $retval;
    }

    $status >>= 8;
    return "Terminated with exit code $status.";
}

sub __openPorts {
    my ($self) = @_;

    my @interfaces;

    my $logger = $self->{__logger};
    my $config = $self->{__config};

    eval {
        my @listeners;     
        foreach my $address (@{$config->{listen}}) {
            # Note that the constructor may return a list for multi-homed
            # addresses.
            push @listeners, BaldLies::Server::Listener->new ($address, $logger);
        }
    
        foreach my $listener (@listeners) {
            $listener->listen;
        }
        $self->{__listeners} = \@listeners;
    };
    $logger->fatal ($@) if $@;
    
    return $self;
}

sub __changePersona {
    my ($self) = @_;
    
    # TODO.
    
    return $self;
}

sub getLogger {
    shift->{__logger};
}

sub getConfig {
    shift->{__config};
}

sub getSecret {
    shift->{__secret};
}

sub getCommandDispatcher {
    shift->{__cmd_dispatcher};
}

sub getMessageDispatcher {
    shift->{__msg_dispatcher};
}

sub __readConfiguration {
    my ($self) = @_;
    
    my $config = $self->{__config};
    my $logger = $self->{__logger};

    my $dump = delete $config->{dump_configuration};
        
    # TODO: Read configuration file, and merge it into our options.

    my $user = $config->{user};
    $user = $> if empty $user;
    my @pwd;
    if ($user =~ /^[0-9]+$/) {
        @pwd = getpwuid $user
            or $logger->fatal ("Cannot determine user name of user"
                               . " id `$user: $!!");
    } else {
        @pwd = getpwnam $user
            or $logger->fatal ("Cannot determine user id of user"
                               . " `$user: $!!");
            
        # This is important for user duplicates:
        $pwd[0] = $user;
    }
    $self->{__user} = $pwd[0];
    $self->{__uid} = $pwd[2];

    my $group = $config->{group};
    ($group) = split / /, $) if empty $config->{group};
    my @grp;
    if ($group =~ /^[0-9]+$/) {
        @grp = getgrgid $group
            or $logger->fatal ("Cannot determine group name of group"
                               . " id `$group: $!!");
    } else {
        @grp = getgrnam $group
            or $logger->fatal ("Cannot determine group id of group"
                               . " `$group: $!!");
            
        # This is important for group duplicates:
        $grp[0] = $config->{group};
    }
    $self->{__group} = $grp[0];
    $self->{__gid} = $grp[2];

    $config->{data_dir} = $self->__getDataDir if empty $config->{data_dir};
    my $data_dir = $config->{data_dir};
    untaint $config->{data_dir};
            
    # Set default options:
    if (empty $config->{dsn}) {
        if (!$dump && !-e $data_dir) {
            $logger->warning ("Creating data directory `$data_dir'.");
            File::Path::make_path($data_dir, { mode => 0700 });
        }
        
        my $db_file = File::Spec->catfile ($data_dir, 'baldlies.sqlite');
        $config->{dsn} = "dbi:SQLite:$db_file";
    }
    untaint $config->{dsn};
    
    if (empty $config->{pid_file}) {
        if (!$dump && !-e $data_dir) {
            $logger->warning ("Creating data directory `$data_dir'.");
            File::Path::make_path($data_dir, { mode => 0700 });
        }

        my $pid_file = File::Spec->catfile ($data_dir, 'baldlies.pid');
        $config->{pid_file} = $pid_file;
    }
    untaint $config->{pid_file};
    
    if (empty $config->{logfile}) {
        if (!$dump && !-e $data_dir) {
            $logger->warning ("Creating data directory `$data_dir'.");
            File::Path::make_path($data_dir, { mode => 0700 });
        }

        my $logfile = File::Spec->catfile ($data_dir, 'baldlies.log');
        $config->{logfile} = $logfile;
    }
    untaint $config->{logfile};
    
    $config->{db_backend} = 'SQLite' if empty $config->{db_backend};
    $config->{verbose} = LOG_NOTICE if empty $config->{verbose};
    $config->{listen} = ['127.0.0.1:4321'] if !@{$config->{listen} || []};
    $config->{max_chunk_size} = 10_000 if empty $config->{max_chunk_size};
    $config->{socket_name} = File::Spec->catdir ($data_dir, 'master.sock');
    
    if ($dump) {
        foreach my $key (sort keys %$config) {
            my $value = $config->{$key};
            $value = '' if empty $value;
            $value = join ', ', @$value if ref $value;
            print "$key: $value\n";
        }
        exit;
    }
    
    return $self;    
}

sub __upgradeDatabaseSchema {
    my ($self) = @_;
    
    my $config = $self->{__config};
    
    return $self if ($config->{db_backend} ne 'SQLite'
                     && empty $config->{upgrade});
    
    if ($config->{upgrade} && $config->{verbose} < LOG_INFO) {
        $config->{verbose} = LOG_INFO;
        $self->{__logger}->level (LOG_INFO);
    }
    my $db = $self->getDatabase ($config->{verbose} < LOG_INFO);
    
    $db->upgrade if !$db->check;
    
    exit 0 if $config->{upgrade};
    
    delete $config->{upgrade};
}

sub getDatabase {
    my ($self, $quiet) = @_;
    
    my $logger = $self->{__logger};
    my $config = $self->{__config};

    my $log = $quiet ? 'debug' : 'info';        
    my $backend = "BaldLies::Database::$config->{db_backend}";
    $logger->$log ("Initializing database backend `$backend'.");
    eval "use $backend";
    $logger->fatal ($@) if $@;

    return $backend->new (config => $config, 
                          logger => $logger, 
                          quiet => $quiet);
}

sub __getDataDir {
    my ($self) = @_;
    
    return $self->{__data_dir} if exists $self->{__data_dir};
    
    my $config = $self->{__config};
    my $logger = $self->{__logger};
    my $home_dir;
    eval { $home_dir = File::HomeDir->users_home ($self->{__user}) };
    
    $logger->fatal ($@) if $@;
    if (!defined $home_dir) {
            $logger->fatal ("Cannot determine home directory of user"
                            . " `$self->{__user}'!");
    };
    if (!-d $home_dir) {
        $logger->fatal ("Home directory `$home_dir' of user"
                        . " `$self->{__user}' does not exist!");
    };

    $self->{__data_dir} = File::Spec->catdir ($home_dir, 'baldlies');
    
    # Untaint:
    untaint $self->{__data_dir};
    
    return $self->{__data_dir};
}

sub __unlockDaemon {
    my ($self) = @_;
    
    if ($self->{__pid_fd}) {
        $self->{__logger}->debug ("Child $$ closing pid file.");
        $self->{__pid_fd}->close;
        delete $self->{__pid_fd};
    }
    
    return $self;
}

sub __lockDaemon {
    my ($self, $pid) = @_;
    
    my $logger = $self->{__logger};
    my $config = $self->{__config};
    
    my $pid_file = $config->{pid_file};

    if (!$self->{__pid_fd}) {
        $self->{__pid_fd} = IO::File->new ($pid_file, O_RDWR | O_CREAT, 
                                           0644)
            or $logger->fatal ("Cannot open pid file `$pid_file': $!!");
        my $fd = $self->{__pid_fd};
        
        unless (flock $fd, LOCK_EX | LOCK_NB) {
        my $line = $fd->getline;
        my $other_pid;
        if (!empty $line) {
            chomp $line;
            $other_pid = 1 * $line;
        }
        $other_pid ||= 'unknown';

        my $error = $!;
        $error ||= 'locked by another process';
                        
        $logger->fatal (<<EOF);
Cannot flock pid file '$pid_file': $error!
$0 seems to be already running with process id $other_pid.
EOF
        }
        
        fcntl $fd, F_SETFD, 1;
    }
    
    # No error checking here.
    $self->{__pid_fd}->seek (0, Fcntl::SEEK_SET());
    my $version_string = "$pid\n";
    if ($self->{__pid_fd}->print ($version_string)) {
        $self->{__pid_fd}->truncate (length $version_string);
    }
    $self->{__pid_fd}->flush;
    
    return $self;
}

sub __createACLs {
    my ($self) = @_;
    
    my $logger = $self->{__logger};
    
    eval { require Net::Interface };
    if ($@) {
        $logger->warning (<<EOF);
Perl module Net::Interface not found.
Server will only accept connections from 
127.0.0.1/8 or addresses explicitely 
specified with --listen (i. e. not `*').
EOF
    }

    my @interfaces = Net::Interface->interfaces;
    foreach my $if (@interfaces) {
        $self->{__ACLs} ||= [];
        my $name = $if->name;
        $logger->debug ("Creating ACLs from network interface `$name';");
        my @addresses = $if->address (AF_INET);
        my @netmasks = $if->netmask (AF_INET);
        for (my $i = 0; $i < @addresses; ++$i) {
            my $mask = $netmasks[$i];
            my $addr = $addresses[$i];
            my $bits = unpack '%b32', $mask;
            my $dotted = join '.', unpack 'C4', $addr & $mask;
            $logger->notice ("Allowing connections from $dotted/$bits.");
            push @{$self->{__ACLs}}, $mask & $addr;
        }
    }
    
    return $self;
}

1;

=head1 NAME

BaldLies::Server - The BaldLies Server Module 

=head1 SYNOPSIS

  use BaldLies::Server;
  
  my $server = BaldLies::Server (OPTIONS);
  
  $server->run;

=head1 DESCRIPTION

B<BaldLies::Server> is the heart of baldlies(1).  You should normally not
call this class, but execute baldlies(1) instead.

The server is a singleton, and can only be instantiated once!

=head1 CONSTRUCTOR

The constructor new() accepts the following named options:

=over 4

=item B<debug BOOLEAN>

If set to a truth value, do not fork into background.

=item B<port PORTNUMBER>

Listen on B<PORTNUMBER> instead of port 4321.  If B<PORTNUMBER> is an array
reference, listens on all ports in that list.

=item B<interface INTERFACE>

Listen on B<INTERFACE> instead of just localhost.  B<INTERFACE> can either be
a numeric IP address or a symbolic hostname which will be resolved, or the
special string `*' which stands for all interfaces.

If B<INTERFACE> is an array reference, listens on all interfaces specified
in that list.

=item B<verbose LEVEL>

Set verbosity level to B<LEVEL>.  The default is 1.  In level 0, you will
only see errors, in level 1 warnings, in level 2 informative output, and in
level 3 or higher debugging information.

=item B<upgrade BOOLEAN>

If set to a truth value, instead of firing up a server, the database schema
will be upgraded.  In this mode of operation, the program never forks into
the background and will return after the database is successfully upgraded.

=back

=head1 RUNNING

The server is run by calling the method run().  This method will never return.

The steps for starting the server are as follows:

=head2 Configuration

First, the configuration file will be written.  This happens while the process
is still running with the original user and group id.  That means that the
configuration file has to be readable by the user that starts the server.

=head2 PID File

Check and write a pid file.  If another BaldLies process is currently running, 
the program terminates with an error message.

=head2 Upgrade Database Schema

If the server uses the SQLite backend or if the option `upgrade' was given, 
the database schema is upgraded to the latest version.  If the upgrade
option was explicitely specified, the server will terminate after the
upgrade.

=head2 Detach

Unless running in the foreground, the process detaches from the controlling
tty and will run in the background.

=head2 Listen

The program will then listen on the specified interfaces and ports.

=head2 Change Persona

If a user and group id was specified, the process changes persona.

=head2 Change Directory

Unless running in the foreground, the process changes directory to `/'.

=head2 Wait Connection

The program then waits for incominng connections until the process is 
terminated by the operating system or an adminstrator logs in and issues the 
`shutdown' command.

=head1 SEE ALSO

baldlies(1), perl(1)

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

package OpenFIBS::Database;

use strict;

use DBI;
use Digest::SHA qw (sha512_base64);
use OpenFIBS::Const qw (:log_levels);

use constant SCHEMA_VERSION => 0;

my $versions = [
    'initial',
];

sub new {
    my ($class, %args) = @_;
    
    my $self = {};
    foreach my $key (keys %args) {
        $self->{'__' . $key} = $args{$key};
    }    
    my $package = __PACKAGE__;
    
    my $logger = $self->{__logger};
    if ($package eq $class) {
        my ($package, $filename, $lineno) = caller;
        my $prefix = '';
        $prefix = "$filename:$lineno: " if defined $filename;
        $logger->fatal ("${prefix}$package is an abstract base class!"); 
    }
    
    my $config = $self->{__config};
    my $log = $self->{__quiet} ? 'debug' : 'info';
    $logger->$log ("Connecting to data source `$config->{dsn}'");
    my $dbh = DBI->connect ($config->{dsn}, 
                            $config->{db_user}, $config->{db_pass},
                            {
                                AutoCommit => 0,
                                RaiseError => 1,
                                PrintError => 0,
                            });
    
    $self->{_dbh} = $dbh;
    $self->{__schema_version} = 0;
    $self->{__sths} = {};
    $self->{__statements} = {};
    
    bless $self, $class;
    
    $self->_initBackend;
    
    return $self;
}

sub DESTROY {
    my ($self) = @_;
    
    return if !$self;
    return if !$self->{_dbh};

    foreach my $name (keys %{$self->{__sths}}) {
        my $sth = $self->{__sths}->{$name};
        $sth->finish;
    }
    
    $self->{_dbh}->disconnect;
    
    return $self;
}

sub _initBackend {
    shift;
}

sub check {
    my ($self) = @_;
    
    my $logger = $self->{__logger};
    
    $logger->info ("Checking database schema version.");
    
    my $dbh = $self->{_dbh};
    
    my $sql = "SELECT schema_version FROM version";
    my $sth = eval { $dbh->prepare ($sql) };
    return unless $sth;
    
    $sth->execute;
    
    my ($wanted) = SCHEMA_VERSION;
    my ($got) = $sth->fetchrow_array;
    if ($wanted < $got) {
        $logger->fatal ("Cannot downgrade database schema from version "
                        . " $got to $wanted.");
    } elsif ($wanted > $got) {
        return;
    }
        
    return $self;
}

sub upgrade {
    my ($self) = @_;
    
    for (my $i = $self->{__schema_version}; $i <= SCHEMA_VERSION; ++$i) {
        my $method = '_upgradeStep' . ucfirst $versions->[$i];
        $self->$method;
    }
    
    my $logger = $self->{__logger};
    
    $logger->info ("Storing new schema version @{[SCHEMA_VERSION]}.");
    my $sql = "UPDATE version SET schema_version = ?";
    my $dbh = $self->{_dbh};
    my $sth = $dbh->prepare ($sql);
    $sth->execute (SCHEMA_VERSION);
    $dbh->commit;
    
    return $self;
}

sub prepareStatements {
    my ($self) = @_;
    
    my $statements = $self->{__statements} = {};
    my $sths = $self->{__sths} = {};

    my $dbh = $self->{_dbh};
    
    $self->{__logger}->info ("Preparing database statements");
    
    $statements->{SELECT_EXISTS_USER} = <<EOF;
SELECT id FROM users WHERE name = ?
EOF
    $sths->{SELECT_EXISTS_USER} = 
        $dbh->prepare ($statements->{SELECT_EXISTS_USER});
    
    $statements->{CREATE_USER} = <<EOF;
INSERT INTO users (name, password, last_login, last_host)
    VALUES (?, ?, ?, ?)
EOF
    $sths->{CREATE_USER} = 
        $dbh->prepare ($statements->{CREATE_USER});
    
    # We fill in the defaults for the game-specific settings so that the order
    # is always the same.  We cannot know whether the user has telnet turned
    # on or off but we can safely ignore that setting in the master process.
    $statements->{SELECT_USER} = <<EOF;
SELECT DISTINCT id, name, password, address, permissions, last_login, last_host,
    experience, rating,
    boardstyle, linelength, pagelength, redoubles, sortwho, timezone,
    allowpip, autoboard, autodouble, automove, bell, crawford, 1, 0, 
    moreboards, moves, notify, ratings, ready, report, silent, 1, wrap
FROM users WHERE name = ?
EOF
    $sths->{SELECT_USER} = 
        $dbh->prepare ($statements->{SELECT_USER});
    
    $statements->{TOUCH_USER} = <<EOF;
UPDATE users 
    SET last_login = ?, last_host = ? 
    WHERE id = ?
EOF
    $sths->{TOUCH_USER} = 
        $dbh->prepare ($statements->{TOUCH_USER});

    return $self;
}

# Upgrade steps.
sub _upgradeStepInitial {
    my ($self) = @_;
    
    my $auto_increment = $self->_getAutoIncrement;
    
    $self->{_dbh}->do (<<EOF);
CREATE TABLE version (schema_version INTEGER)
EOF

    $self->{_dbh}->do (<<EOF);
CREATE TABLE users (
    id $auto_increment,
    name TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL,
    address TEXT,
    permissions INTEGER NOT NULL DEFAULT 0,
    last_login BIGINT NOT NULL,
    last_logout BIGINT,
    last_host TEXT,
    experience INTEGER NOT NULL DEFAULT 0,
    rating DOUBLE NOT NULL DEFAULT 1500,
    
    -- Settings.
    boardstyle INTEGER NOT NULL DEFAULT 2,
    linelength INTEGER NOT NULL DEFAULT 0,
    pagelength INTEGER NOT NULL DEFAULT 0,
    redoubles TEXT NOT NULL DEFAULT 0,
    sortwho TEXT NOT NULL DEFAULT 'login',
    timezone TEXT NOT NULL DEFAULT 'UTC',
    
    -- Toggles.
    allowpip BOOLEAN NOT NULL DEFAULT 1,
    autoboard BOOLEAN NOT NULL DEFAULT 1,
    autodouble BOOLEAN NOT NULL DEFAULT 1,
    automove BOOLEAN NOT NULL DEFAULT 1,
    bell BOOLEAN NOT NULL DEFAULT 1,
    crawford BOOLEAN NOT NULL DEFAULT 1,
    -- Per-game settings.
    --double BOOLEAN NOT NULL DEFAULT 1,
    --greedy BOOLEAN NOT NULL DEFAULT 1,
    moreboards BOOLEAN NOT NULL DEFAULT 1,
    moves BOOLEAN NOT NULL DEFAULT 1,
    notify BOOLEAN NOT NULL DEFAULT 1,
    ratings BOOLEAN NOT NULL DEFAULT 1,
    ready BOOLEAN NOT NULL DEFAULT 1,
    report BOOLEAN NOT NULL DEFAULT 1,
    silent BOOLEAN NOT NULL DEFAULT 1,
    -- No need to store that in the database, determined on login.
    -- telnet BOOLEAN,
    wrap BOOLEAN NOT NULL DEFAULT 1
)
EOF

    $self->{_dbh}->do (<<EOF, {}, 0);
INSERT INTO version (schema_version) VALUES (?)
EOF

    return $self;
}

sub _encryptPassword {
    my ($self, $password) = @_;

    my @salt_chars = ('.', '/', '0' .. '9', 'a' .. 'z', 'A' .. 'Z');
    my $salt = '!6!';

    foreach (1 .. 16) {
        $salt .= $salt_chars[int rand @salt_chars];
    }
    $salt .= '!';

    return $salt . sha512_base64 $password . $salt;
}

sub _checkPassword {
    my ($self, $password, $digest) = @_;

    my $retval;

    if ($digest =~ m{^(!6![./0-9a-zA-Z]{4,16}!)([a-zA-Z0-9+/]{22})}) {
        my ($salt, $other) = ($1, $2);
        return $salt . sha512_base64 $password . $salt;
    } else {
        return sha512_base64 $password;
    }
}

sub __prettyPrint {
    my ($self, $statement, @args) = @_;
    
    my $dbh = $self->{_dbh};
    my $sql = $self->{__statements}->{$statement};
    
    $sql =~ s/[ \t\r\n]+/ /g;
    $sql =~ s/\?/$dbh->quote (shift @args)/eg;
    
    return $sql;
}

sub _doStatement {
    my ($self, $statement, @args) = @_;
    
    my $logger = $self->{__logger};
    
    die "No such statement handle `$statement'.\n" 
        if !exists $self->{__sths}->{$statement}; 
    die "No such statement `$statement'.\n" 
        if !exists $self->{__statements}->{$statement}; 
    
    my $pretty_statement;
    if (LOG_DEBUG <= $logger->level) {
        $pretty_statement = $self->__prettyPrint ($statement, @args);
        $logger->debug ("[SQL] $pretty_statement");
    }
    my $sth = $self->{__sths}->{$statement};
    my $result = 1;
    eval {
        $sth->execute (@args);
    
        if ($statement =~ /^SELECT_/) {
            $result = $sth->fetchall_arrayref;
            $sth->finish;
        }
    };
    if ($@) {
        $pretty_statement = $self->__prettyPrint ($statement, @args)
            if !defined $pretty_statement;
        $logger->error ("$@.  SQL: $pretty_statement");
        return;
    }

    return $result;
}

sub _commit {
    my ($self) = @_;
    
    my $logger = $self->{__logger};
    eval {
        $logger->debug ("Commiting transaction.");
        $self->{_dbh}->commit;
    };
    if ($@) {
        my $exception = $@;
        $logger->error ("Transaction failed: $@");
        $logger->notice ("Issuing rollback.");
        eval { $self->{_dbh}->rollback };
        if ($@) {
            $logger->error ("Rollback failed: $@");
        }
        return;
    }
    
    return $self;
}

sub existsUser {
    my ($self, $name) = @_;
    
    my $records = $self->_doStatement (SELECT_EXISTS_USER => $name);
    
    return unless $records && @$records;
    
    return $self;
}

sub createUser {
    my ($self, $name, $password, $host) = @_;

    my $now = time;
    
    my $digest = $self->_encryptPassword ($password);
    return if !$self->_doStatement (CREATE_USER => $name, $digest, 
                                                   $now, $host);
    return if !$self->_commit;
    
    return $self;
}

sub getUser {
    my ($self, $name, $password, $host) = @_;
    
    my $logger = $self->{__logger};
    
    # id, name, password, address, permissions, last_login, last_host,
    # experience, rating,
    # boardstyle, linelength, pagelength, redoubles, sortwho, timezone,
    # allowpip, autoboard, autodouble, automove, bell, crawford, 1, 0, 
    # moreboards, moves, notify, ratings, ready, report, silent, 1, wrap

    my $rows = $self->_doStatement (SELECT_USER => $name);
    unless ($rows && @$rows) {
        $logger->info ("User `$name': no such user.");
        return;
    }
    
    my $row = $rows->[0];
    my $digest = $row->[2];
    unless ($self->_checkPassword ($password, $digest)) {
        $logger->info ("User `$name': password error.");
        return;
    }
    
    my $id = $row->[0];
    my $now = time;
    return if !$self->_doStatement (TOUCH_USER => $now, $host, $id);
    return if !$self->_commit;

    return $row;
}

1;

=head1 NAME

OpenFIBS::Database - SQLite Database Abstraction

=head1 SYNOPSIS

  use OpenFIBS::Database;
  
=head1 DESCRIPTION

Database routines for OpenFIBS.  Note that the class is an abstract base class.
You have to call the constructor of one of the backends.

This class is of internal use only.

=back

=head1 SEE ALSO

DBI(3pm), OpenFIBS::Database::SQLite(3pm), openfibs(1), perl(1)


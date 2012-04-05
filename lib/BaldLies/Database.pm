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

package BaldLies::Database;

use strict;

use DBI;
use Digest::SHA qw (sha512_base64);
use BaldLies::Const qw (:log_levels);

my $versions = [qw (
    users matches redoubles rating_change rating_change2
)];

my $schema_version = $#$versions;

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
    
    my ($wanted) = $schema_version;
    my ($got) = $sth->fetchrow_array;
    $self->{__schema_version} = $got;
    $logger->debug ("Need version $wanted, have version $got.");
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
    
    my $logger = $self->{__logger};
    $logger->debug ("Upgrade database schema from version"
                    . " $self->{__schema_version} to $schema_version.");
    for (my $i = $self->{__schema_version} + 1; $i <= $schema_version; ++$i) {
        my $version = ucfirst $versions->[$i];
        $version =~ s/_(.)/uc $1/ge;
        my $method = '_upgradeStep' . $version;
        $self->$method ($i);
    }
    
    $logger->info ("Storing new schema version $schema_version.");
    my $sql = "UPDATE version SET schema_version = ?";
    my $dbh = $self->{_dbh};
    my $sth = $dbh->prepare ($sql);
    $sth->execute ($schema_version);
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
SELECT DISTINCT id, name, password, address, admin, last_login, 
    last_logout, last_host, experience, rating,
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

    $statements->{SET_BOARDSTYLE} = <<EOF;
UPDATE users SET boardstyle = ? WHERE name = ?
EOF
    $sths->{SET_BOARDSTYLE} = 
        $dbh->prepare ($statements->{SET_BOARDSTYLE});

    $statements->{SET_LINELENGTH} = <<EOF;
UPDATE users SET linelength = ? WHERE name = ?
EOF
    $sths->{SET_LINELENGTH} = 
        $dbh->prepare ($statements->{SET_LINELENGTH});

    $statements->{SET_PAGELENGTH} = <<EOF;
UPDATE users SET pagelength = ? WHERE name = ?
EOF
    $sths->{SET_PAGELENGTH} = 
        $dbh->prepare ($statements->{SET_PAGELENGTH});

    $statements->{SET_REDOUBLES} = <<EOF;
UPDATE users SET redoubles = ? WHERE name = ?
EOF
    $sths->{SET_REDOUBLES} = 
        $dbh->prepare ($statements->{SET_REDOUBLES});

    $statements->{SET_SORTWHO} = <<EOF;
UPDATE users SET sortwho = ? WHERE name = ?
EOF
    $sths->{SET_SORTWHO} = 
        $dbh->prepare ($statements->{SET_SORTWHO});

    $statements->{SET_TIMEZONE} = <<EOF;
UPDATE users SET timezone = ? WHERE name = ?
EOF
    $sths->{SET_TIMEZONE} = 
        $dbh->prepare ($statements->{SET_TIMEZONE});

    $statements->{TOGGLE_ALLOWPIP} = <<EOF;
UPDATE users SET allowpip = NOT allowpip WHERE name = ?
EOF
    $sths->{TOGGLE_ALLOWPIP} = 
        $dbh->prepare ($statements->{TOGGLE_ALLOWPIP});

    $statements->{TOGGLE_AUTOBOARD} = <<EOF;
UPDATE users SET autoboard = NOT autoboard WHERE name = ?
EOF
    $sths->{TOGGLE_AUTOBOARD} = 
        $dbh->prepare ($statements->{TOGGLE_AUTOBOARD});

    $statements->{TOGGLE_AUTODOUBLE} = <<EOF;
UPDATE users SET autodouble = NOT autodouble WHERE name = ?
EOF
    $sths->{TOGGLE_AUTODOUBLE} = 
        $dbh->prepare ($statements->{TOGGLE_AUTODOUBLE});

    $statements->{TOGGLE_AUTOMOVE} = <<EOF;
UPDATE users SET automove = NOT automove WHERE name = ?
EOF
    $sths->{TOGGLE_AUTOMOVE} = 
        $dbh->prepare ($statements->{TOGGLE_AUTOMOVE});

    $statements->{TOGGLE_BELL} = <<EOF;
UPDATE users SET bell = NOT bell WHERE name = ?
EOF
    $sths->{TOGGLE_BELL} = 
        $dbh->prepare ($statements->{TOGGLE_BELL});

    $statements->{TOGGLE_CRAWFORD} = <<EOF;
UPDATE users SET crawford = NOT crawford WHERE name = ?
EOF
    $sths->{TOGGLE_CRAWFORD} = 
        $dbh->prepare ($statements->{TOGGLE_CRAWFORD});

    $statements->{TOGGLE_MOREBOARDS} = <<EOF;
UPDATE users SET moreboards = NOT moreboards WHERE name = ?
EOF
    $sths->{TOGGLE_MOREBOARDS} = 
        $dbh->prepare ($statements->{TOGGLE_MOREBOARDS});

    $statements->{TOGGLE_MOVES} = <<EOF;
UPDATE users SET moves = NOT moves WHERE name = ?
EOF
    $sths->{TOGGLE_MOVES} = 
        $dbh->prepare ($statements->{TOGGLE_MOVES});

    $statements->{TOGGLE_NOTIFY} = <<EOF;
UPDATE users SET notify = NOT notify WHERE name = ?
EOF
    $sths->{TOGGLE_NOTIFY} = 
        $dbh->prepare ($statements->{TOGGLE_NOTIFY});

    $statements->{TOGGLE_RATINGS} = <<EOF;
UPDATE users SET ratings = NOT ratings WHERE name = ?
EOF
    $sths->{TOGGLE_RATINGS} = 
        $dbh->prepare ($statements->{TOGGLE_RATINGS});

    $statements->{TOGGLE_READY} = <<EOF;
UPDATE users SET ready = NOT ready WHERE name = ?
EOF
    $sths->{TOGGLE_READY} = 
        $dbh->prepare ($statements->{TOGGLE_READY});

    $statements->{TOGGLE_REPORT} = <<EOF;
UPDATE users SET report = NOT ready WHERE name = ?
EOF
    $sths->{TOGGLE_REPORT} = 
        $dbh->prepare ($statements->{TOGGLE_REPORT});

    $statements->{TOGGLE_SILENT} = <<EOF;
UPDATE users SET ready = NOT silent WHERE name = ?
EOF
    $sths->{TOGGLE_SILENT} = 
        $dbh->prepare ($statements->{TOGGLE_SILENT});

    $statements->{TOGGLE_WRAP} = <<EOF;
UPDATE users SET wrap = NOT ready WHERE name = ?
EOF
    $sths->{TOGGLE_WRAP} = 
        $dbh->prepare ($statements->{TOGGLE_WRAP});

    $statements->{SET_ADDRESS} = <<EOF;
UPDATE users SET address = ? WHERE name = ?
EOF
    $sths->{SET_ADDRESS} = 
        $dbh->prepare ($statements->{SET_ADDRESS});

    $statements->{CREATE_MATCH} = <<EOF;
INSERT INTO matches (player1, player2, match_length, last_action,
                     crawford, autodouble, redoubles, r1, e1, r2, e2)
    VALUES (?, ?, ?, ?,
            (SELECT MAX (
                (SELECT (CASE WHEN crawford THEN 1 ELSE 0 END) 
                    FROM users WHERE id = ?), 
                (SELECT (CASE WHEN crawford THEN 1 ELSE 0 END) 
                    FROM users WHERE id = ?))), 
            (SELECT MIN (
                (SELECT (CASE WHEN autodouble THEN 1 ELSE 0 END) 
                    FROM users WHERE id = ?), 
                (SELECT (CASE WHEN autodouble THEN 1 ELSE 0 END) 
                    FROM users WHERE id = ?))), 
            (SELECT MAX (
                (SELECT redoubles FROM users WHERE id = ?), 
                (SELECT redoubles FROM users WHERE id = ?))), 
            (SELECT rating FROM users WHERE id = ?),
            (SELECT rating FROM users WHERE id = ?),
            (SELECT experience FROM users WHERE id = ?),
            (SELECT experience FROM users WHERE id = ?))
EOF
    $sths->{CREATE_MATCH} = 
        $dbh->prepare ($statements->{CREATE_MATCH});

    $statements->{SELECT_MATCH} = <<EOF;
SELECT u1.name, u2.name, m.match_length, m.points1, m.points2,
       m.crawford, m.post_crawford, m.autodouble, m.redoubles,
       m.r1, m.r2, m.e1, m.e2
    FROM matches m, USERS u1, USERS u2 
    WHERE m.player1 == ? AND m.player2 == ?
      AND u1.id = m.player1 AND u2.id = m.player2
EOF
    $sths->{SELECT_MATCH} = 
        $dbh->prepare ($statements->{SELECT_MATCH});

    return $self;
}

# Upgrade steps.
sub _upgradeStepUsers {
    my ($self, $version) = @_;
    
    my $auto_increment = $self->_getAutoIncrement;
    
    $self->{_dbh}->do (<<EOF);
CREATE TABLE version (schema_version INTEGER)
EOF

    $self->{_dbh}->do (<<EOF);
CREATE TABLE users (
    id $auto_increment,
    name TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL,
    address TEXT NOT NULL DEFAULT '-',
    admin INTEGER NOT NULL DEFAULT 0,
    last_login BIGINT NOT NULL,
    last_logout BIGINT NOT NULL DEFAULT 0,
    last_host TEXT NOT NULL DEFAULT '-',
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
    autodouble BOOLEAN NOT NULL DEFAULT 0,
    automove BOOLEAN NOT NULL DEFAULT 0,
    bell BOOLEAN NOT NULL DEFAULT 0,
    crawford BOOLEAN NOT NULL DEFAULT 1,
    -- Per-game settings.
    --double BOOLEAN NOT NULL DEFAULT 1,
    --greedy BOOLEAN NOT NULL DEFAULT 0,
    moreboards BOOLEAN NOT NULL DEFAULT 0,
    moves BOOLEAN NOT NULL DEFAULT 0,
    notify BOOLEAN NOT NULL DEFAULT 1,
    ratings BOOLEAN NOT NULL DEFAULT 0,
    ready BOOLEAN NOT NULL DEFAULT 0,
    report BOOLEAN NOT NULL DEFAULT 1,
    silent BOOLEAN NOT NULL DEFAULT 0,
    -- No need to store that in the database, determined on login.
    -- telnet BOOLEAN,
    wrap BOOLEAN NOT NULL DEFAULT 0
)
EOF

    $self->{_dbh}->do (<<EOF, {}, $version);
INSERT INTO version (schema_version) VALUES (?)
EOF

    return $self;
}

sub _upgradeStepMatches {
    my ($self, $version) = @_;
    
    my $auto_increment = $self->_getAutoIncrement;
    
    $self->{_dbh}->do (<<EOF);
CREATE TABLE matches (
    id $auto_increment,
    player1 INTEGER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    player2 INTEGER NOT NULL CHECK (player1 != player2)
        REFERENCES users (id) ON DELETE CASCADE,
    match_length INTEGER NOT NULL CHECK (match_length != 0),
    points1 INTEGER NOT NULL DEFAULT 0 
        CHECK (match_length < 0 OR points1 < match_length),
    points2 INTEGER NOT NULL DEFAULT 0 
        CHECK (match_length < 0 OR points2 < match_length),
    last_action BIGINT NOT NULL,
    crawford BOOLEAN NOT NULL DEFAULT 1,
    post_crawford BOOLEAN NOT NULL DEFAULT 0,
    autodouble BOOLEAN NOT NULL DEFAULT 0,
    UNIQUE (player1, player2)
)
EOF

    $self->{_dbh}->do (<<EOF, {}, $version);
UPDATE version SET schema_version = ?
EOF

    return $self;
}

sub _upgradeStepRedoubles {
    my ($self, $version) = @_;
    
    $self->{_dbh}->do (<<EOF);
ALTER TABLE matches ADD COLUMN redoubles INTEGER NOT NULL
EOF

    $self->{_dbh}->do (<<EOF, {}, $version);
UPDATE version SET schema_version = ?
EOF

    return $self;
}

sub _upgradeStepRatingChange {
    my ($self, $version) = @_;
    
    $self->{_dbh}->do (<<EOF);
ALTER TABLE matches ADD COLUMN change1 DOUBLE NOT NULL DEFAULT 0.0
EOF

    $self->{_dbh}->do (<<EOF);
ALTER TABLE matches ADD COLUMN change2 DOUBLE NOT NULL DEFAULT 0.0
EOF

    $self->{_dbh}->do (<<EOF, {}, $version);
UPDATE version SET schema_version = ?
EOF

    return $self;
}

sub _upgradeStepRatingChange2 {
    my ($self, $version) = @_;

    my $auto_increment = $self->_getAutoIncrement;
    
    $self->{_dbh}->do (<<EOF);
DROP TABLE IF EXISTS matches
EOF

    $self->{_dbh}->do (<<EOF);
CREATE TABLE matches (
    id $auto_increment,
    player1 INTEGER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    player2 INTEGER NOT NULL CHECK (player1 < player2)
        REFERENCES users (id) ON DELETE CASCADE,
    match_length INTEGER NOT NULL CHECK (match_length != 0),
    points1 INTEGER NOT NULL DEFAULT 0 
        CHECK (match_length < 0 OR points1 < match_length),
    points2 INTEGER NOT NULL DEFAULT 0 
        CHECK (match_length < 0 OR points2 < match_length),
    last_action BIGINT NOT NULL,
    crawford BOOLEAN NOT NULL DEFAULT 1,
    post_crawford BOOLEAN NOT NULL DEFAULT 0,
    autodouble BOOLEAN NOT NULL DEFAULT 0,
    redoubles INTEGER NOT NULL,
    r1 DOUBLE NOT NULL,
    r2 DOUBLE NOT NULL,
    e1 INTEGER NOT NULL,
    e2 INTEGER NOT NULL,
    UNIQUE (player1, player2)
)
EOF

    $self->{_dbh}->do (<<EOF, {}, $version);
UPDATE version SET schema_version = ?
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
    my ($self, $password, $wanted) = @_;

    my $retval;

    return if $wanted !~ m{^(!6![./0-9a-zA-Z]{4,16}!)([a-zA-Z0-9+/]{22})};
    my ($salt, $other) = ($1, $2);
    my $got = $salt . sha512_base64 $password . $salt;
    
    return if $got ne $wanted;
    
    return $self;
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

sub setBoardstyle {
    my ($self, $name, $style) = @_;
    
    return if !$self->_doStatement (SET_BOARDSTYLE => $style, $name);
    return if !$self->_commit;
    
    return $self;
    
}

sub setLinelength {
    my ($self, $name, $value) = @_;
    
    return if !$self->_doStatement (SET_LINELENGTH => $value, $name);
    return if !$self->_commit;
    
    return $self;
    
}

sub setPagelength {
    my ($self, $name, $value) = @_;
    
    return if !$self->_doStatement (SET_PAGELENGTH => $value, $name);
    return if !$self->_commit;
    
    return $self;
    
}

sub setRedoubles {
    my ($self, $name, $value) = @_;
    
    return if !$self->_doStatement (SET_REDOUBLES => $value, $name);
    return if !$self->_commit;
    
    return $self;
    
}

sub setSortwho {
    my ($self, $name, $value) = @_;
    
    return if !$self->_doStatement (SET_SORTWHO => $value, $name);
    return if !$self->_commit;
    
    return $self;
    
}

sub setTimezone {
    my ($self, $name, $value) = @_;
    
    return if !$self->_doStatement (SET_TIMEZONE => $value, $name);
    return if !$self->_commit;
    
    return $self;
    
}

sub setAddress {
    my ($self, $name, $value) = @_;
    
    return if !$self->_doStatement (SET_ADDRESS => $value, $name);
    return if !$self->_commit;
    
    return $self;
    
}

sub toggleAllowpip {
    my ($self, $name) = @_;
    
    return if !$self->_doStatement (TOGGLE_ALLOWPIP => $name);
    return if !$self->_commit;
    
    return $self;    
}

sub toggleAutoboard {
    my ($self, $name) = @_;
    
    return if !$self->_doStatement (TOGGLE_AUTOBOARD => $name);
    return if !$self->_commit;
    
    return $self;    
}

sub toggleAutomove {
    my ($self, $name) = @_;
    
    return if !$self->_doStatement (TOGGLE_AUTOMOVE => $name);
    return if !$self->_commit;
    
    return $self;    
}

sub toggleAutodouble {
    my ($self, $name) = @_;
    
    return if !$self->_doStatement (TOGGLE_AUTODOUBLE => $name);
    return if !$self->_commit;
    
    return $self;    
}

sub toggleBell {
    my ($self, $name) = @_;
    
    return if !$self->_doStatement (TOGGLE_BELL => $name);
    return if !$self->_commit;
    
    return $self;    
}

sub toggleCrawford {
    my ($self, $name) = @_;
    
    return if !$self->_doStatement (TOGGLE_CRAWFORD => $name);
    return if !$self->_commit;
    
    return $self;    
}

sub toggleMoreboards {
    my ($self, $name) = @_;
    
    return if !$self->_doStatement (TOGGLE_MOREBOARDS => $name);
    return if !$self->_commit;
    
    return $self;    
}

sub toggleMoves {
    my ($self, $name) = @_;
    
    return if !$self->_doStatement (TOGGLE_MOVES => $name);
    return if !$self->_commit;
    
    return $self;    
}

sub toggleNotify {
    my ($self, $name) = @_;
    
    return if !$self->_doStatement (TOGGLE_NOTIFY => $name);
    return if !$self->_commit;
    
    return $self;    
}

sub toggleRatings {
    my ($self, $name) = @_;
    
    return if !$self->_doStatement (TOGGLE_RATINGS => $name);
    return if !$self->_commit;
    
    return $self;    
}

sub toggleReady {
    my ($self, $name) = @_;
    
    return if !$self->_doStatement (TOGGLE_READY => $name);
    return if !$self->_commit;
    
    return $self;    
}

sub toggleReport {
    my ($self, $name) = @_;
    
    return if !$self->_doStatement (TOGGLE_REPORT => $name);
    return if !$self->_commit;
    
    return $self;    
}

sub toggleSilent {
    my ($self, $name) = @_;
    
    return if !$self->_doStatement (TOGGLE_SILENT => $name);
    return if !$self->_commit;
    
    return $self;    
}

sub toggleWrap {
    my ($self, $name) = @_;
    
    return if !$self->_doStatement (TOGGLE_WRAP => $name);
    return if !$self->_commit;
    
    return $self;    
}

sub createMatch {
    my ($self, $player1, $player2, $length) = @_;
    
    ($player1, $player2) = ($player2, $player1) if $player2 < $player1;
    
    return if !$self->_doStatement (CREATE_MATCH => $player1, $player2,
                                    $length, time,
                                    $player1, $player2,
                                    $player1, $player2,
                                    $player1, $player2,
                                    $player1, $player2,
                                    $player1, $player2);
                                    
    return if !$self->_commit;
    
    return $self;
}

sub loadMatch {
    my ($self, $id1, $id2) = @_;

    ($id1, $id2) = ($id2, $id1) if $id2 < $id1;

    my $logger = $self->{__logger};

    my $rows = $self->_doStatement (SELECT_MATCH => $id1, $id2);
    unless ($rows && @$rows) {
        $logger->info ("No match between user ids $id1 and $id2.");
        return;
    }

    my $row = $rows->[0];
    # The keys in the hash slice must match the properties of 
    # BaldLies::Backgammon::Match.
    my %retval;
    @retval{qw (player1 player2 length score1 score2
                crawford post_crawford autodouble redoubles
                rating1 rating2 experience1 experience2)} = @$row;
    
    return \%retval;
}

1;

=head1 NAME

BaldLies::Database - SQLite Database Abstraction

=head1 SYNOPSIS

  use BaldLies::Database;
  
=head1 DESCRIPTION

Database routines for BaldLies.  Note that the class is an abstract base class.
You have to call the constructor of one of the backends.

This class is of internal use only.

=back

=head1 SEE ALSO

DBI(3pm), BaldLies::Database::SQLite(3pm), baldlies(1), perl(1)


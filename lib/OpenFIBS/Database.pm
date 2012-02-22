###! /bin/false

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

use DBI;

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
    $self->{__statements} = {};
    
    bless $self, $class;
    
    $self->_initBackend;
    
    return $self;
}

sub DESTROY {
    my ($self) = @_;
    
    return if !$self;
    return if !$self->{_dbh};
    
    while (my ($name, $sth) = %{$self->{__statements}}) {
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
    
    my $statements = {};
    my $dbh = $self->{_dbh};
    
    $self->{__logger}->info ("Preparing database statements");
    
    $statements->{SELECT_EXISTS_USER} = $dbh->prepare (<<EOF);
SELECT id FROM users WHERE name = ?
EOF
    
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
    permissions INTEGER NOT NULL
)
EOF

    $self->{_dbh}->do (<<EOF, {}, 0);
INSERT INTO version (schema_version) VALUES (?)
EOF

    return $self;
}

sub __doStatement {
    my ($self, $statement, @args) = @_;
    
    my $statements = $self->{__statements};

    die "No such statement `$statement'.\n" 
        if !exists $statements->{$statement}; 
        
    $statement->execute (@args);    
    
    return $statement->fetchall_arrayref;
}

sub existsUser {
    my ($self, $name) = @_;
    
    my $records = $self->_doStatement (SELECT_EXISTS_USER => $name);
    
    use Data::Dumper;
    die Dumper $records;
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


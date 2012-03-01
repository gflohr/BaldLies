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

package BaldLies::Session::Command;

use strict;

use BaldLies::Util qw (empty);

sub new {
    my ($class, $session, $call) = @_;

    my $name = $class;
    $name =~ s/.*:://;
    bless { _name => $name, _call => $call, _session => $session }, $class;
}

sub aliases {
    return;
}

sub _helpName {
    return "Undocumented command";
}

sub _helpSynopsis {
    my ($self) = @_;
    
    return join "\n", $self->{_name}, $self->aliases;
}

sub _helpDescription {
    return "No description available for this command.";
}

sub _helpSeeAlso {
    return '';
}

sub help {
    my ($self) = @_;

    my $name_help = $self->_helpName;
    $name_help =~ s/^[ \t\r]+//;
    $name_help =~ s/[ \t\r]+$//;
    
    my $synopsis = $self->_helpSynopsis;
    $synopsis =~ s/^/  /gm;
    $synopsis =~ s/[ \t\r\n]+$//g;
    
    my $description = $self->_helpDescription;
    $description =~ s/^/  /gm;
    $description =~ s/[ \t\r\n]+$//g;
    
    my $retval = <<EOF;
NAME
  $self->{_name} - $name_help

SYNOPSIS
$synopsis

DESCRIPTION
$description
EOF

    my $see_also = $self->_helpSeeAlso;
    if (!empty $see_also) {
        $see_also =~ s/^/  /gm;
        $see_also =~ s/[ \t\r\n]+$//gs;
        $retval .= <<EOF;

SEE ALSO
$see_also
EOF
    }
    
    return $retval;
}

sub execute {
    my ($self, $payload) = @_;
    
    $self->{_session}->reply ("The command `$self->{_name}' is not yet"
                              . " implemented.\n");
    
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Command - BaldLies Stub Command Handler

=head1 SYNOPSIS

  use BaldLies::Session::Command;
  
  my $cmd = BaldLies::Session::Command->new ('help', $session);
  
=head1 DESCRIPTION

B<BaldLies::Server::Stub::Command> is the base class for all BaldLies
command handlers.

It should not be instantiated directly.  Instantiate one of the subclasses
instead.

=head1 SEE ALSO

BaldLies::Server(3pm), baldlies(1), perl(1)

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

package OpenFIBS::Session::Command::help;

use strict;

use base qw (OpenFIBS::Session::Command);

use OpenFIBS::Util qw (empty);

sub execute {
    my ($self, $payload) = @_;
    
    my $session = $self->{_session};
    
    my $help;
    
    if (!empty $payload) {
        my ($topic) = split /[ \t]+/, $payload;
        
        my $dispatcher = $session->getCommandDispatcher;
        my $class = $dispatcher->module ($payload) if !empty $topic;
        if (!empty $class) {
            my $obj = $class->new ($self->{_session}, $topic);
            $help = $obj->help;
        } else {
            return $session->reply ("** No help available on $payload");
        }
    }
    
    if (empty $help) {
        $help = $self->help;
    }
    
    chomp $help;
    return $session->reply ("$help\n.\n");
}

sub _helpName {
    return "Online help for OpenFIBS";
}

sub _helpSynopsis {
    return <<EOF;
help[, TOPIC]
EOF
}

sub _helpDescription {
    my ($self) = @_;

    my $session = $self->{_session};
    my $dispatcher = $session->getCommandDispatcher;
    my @topics = $dispatcher->all;
    
    my $topics = '';
    my $pos = 0;
    
    foreach my $topic (sort @topics) {
        $topics .= $topic;
        $pos += length $topic;
        if ($pos > 60) {
            $topics .= "\n";
            $pos = 0;
        } else {
            my $pad = 15 - $pos % 15;
            $topics .= ' ' x $pad;
            $pos += $pad;
        }
    }
    chomp $topics;
    
    return <<EOF
Without an argument, this page is displayed.

With an argument TOPIC, help for that TOPIC is displayed.  Valid topics
are:

$topics
EOF
}

1;

=head1 NAME

OpenFIBS::Session::Command::help - OpenFIBS Command `help'

=head1 SYNOPSIS

  use OpenFIBS::Session::Command::help->new (help => $session, $call);
  
=head1 DESCRIPTION

This plug-in handles the command `help'.

=head1 SEE ALSO

OpenFIBS::Session::Command(3pm), openfibs(1), perl(1)

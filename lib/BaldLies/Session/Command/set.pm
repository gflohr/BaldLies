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

package BaldLies::Session::Command::set;

use strict;

use base qw (BaldLies::Session::Command);

use File::Find;

use BaldLies::Util qw (empty);

sub execute {
    my ($self, $payload) = @_;
    
    my $session = $self->{_session};
    
    my ($variable, $value) = split / /, $payload, 2 if defined $payload;
        
    if (empty $variable) {
        return $self->__showAll;
    } elsif (empty $value) {
        return $self->__showValue ($variable);
    } elsif ('boardstyle' eq $variable) {
        return $self->__setBoardstyle ($value);
    } elsif ('linelength' eq $variable) {
        return $self->__setLinelength ($value);
    } elsif ('pagelength' eq $variable) {
        return $self->__setPagelength ($value);
    } elsif ('redoubles' eq $variable) {
        return $self->__setRedoubles ($value);
    } elsif ('sortwho' eq $variable) {
        return $self->__setSortwho ($value);
    } elsif ('timezone' eq $variable) {
        return $self->__setTimezone ($value);
    }
    
    return $self->__invalidArgument;
}

sub __setBoardstyle {
    my ($self, $value) = @_;
    
    my $session = $self->{_session};
    my $user = $session->getUser;
    my $current = $user->{boardstyle};
    
    if ($value ne '1' && $value ne '2' && $value ne '3') {
        $session->reply ("** Valid arguments are the numbers 1 to 3.\n");
    } elsif ($value eq $current) {
        # Silently bypass database.
        my $msg_dispatcher = $session->getMessageDispatcher;
        $msg_dispatcher->execute ($session, set => "boardstyle $value");
    } else {
        $session->sendMaster (set => "boardstyle $value");
    }
    
    return $self;
}

sub __setLinelength {
    my ($self, $value) = @_;
    
    my $session = $self->{_session};
    my $user = $session->getUser;
    my $current = $user->{linelength};
    
    if ($value !~ /^0|[1-9][0-9]{0,2}$/) {
        $session->reply ("** Valid arguments are the numbers 0 to 999. Use 0"
                         . " for no linelength.\n");
    } elsif ($value eq $current) {
        # Silently bypass database.
        my $msg_dispatcher = $session->getMessageDispatcher;
        $msg_dispatcher->execute ($session, set => "linelength $value");
    } else {
        $session->sendMaster (set => "linelength $value");
    }
    
    return $self;
}

sub __setPagelength {
    my ($self, $value) = @_;
    
    my $session = $self->{_session};
    my $user = $session->getUser;
    my $current = $user->{pagelength};
    
    if ($value !~ /^0|[1-9][0-9]{0,2}$/) {
        $session->reply ("** Valid arguments are the numbers 0 to 999. Use 0"
                         . " for no pagelength.\n");
    } elsif ($value eq $current) {
        # Silently bypass database.
        my $msg_dispatcher = $session->getMessageDispatcher;
        $msg_dispatcher->execute ($session, set => "pagelength $value");
    } else {
        $session->sendMaster (set => "pagelength $value");
    }
    
    return $self;
}

sub __setSortwho {
    my ($self, $value) = @_;
    
    my $session = $self->{_session};
    my $user = $session->getUser;
    my $current = $user->{sortwho};
    
    if ('login' ne $value && 'name' ne $value
        && 'rating' ne $value && 'rrating' ne $value) {
        $session->reply ("** Unknown value '$value'. Try 'login', 'name',"
                         . " 'rating' or 'rrating'.\n");
    } elsif ($value eq $current) {
        # Silently bypass database.
        my $msg_dispatcher = $session->getMessageDispatcher;
        $msg_dispatcher->execute ($session, set => "sortwho $value");
    } else {
        $session->sendMaster (set => "sortwho $value");
    }
    
    return $self;
}

sub __setRedoubles {
    my ($self, $value) = @_;
    
    my $session = $self->{_session};
    my $user = $session->getUser;
    my $current = $user->{sortwho};
    
    if ('none' eq $value) {
        $value = 0;
    } elsif ('unlimited' eq $value) {
        $value = -1;
    } elsif ($value !~ /^[1-9][0-9]?$/) {
        $session->reply ("** Valid arguments are 'none', 'unlimited' and the"
                         . " numbers 1 to 99.\n");
        return $self;
    }
    
    if ($value eq $current) {
        # Silently bypass database.
        my $msg_dispatcher = $session->getMessageDispatcher;
        $msg_dispatcher->execute ($session, set => "redoubles $value");
    } else {
        $session->sendMaster (set => "redoubles $value");
    }
    
    return $self;
}

sub __setTimezone {
    my ($self, $value) = @_;
    
    my $session = $self->{_session};
    my $user = $session->getUser;
    my $current = $user->{sortwho};
    
    if ('UTC' ne $value) {
        $session->reply ("** Can't find timezone '$value'. Try one of:\n"
                         . "UTC\n");
    } elsif ($value eq $current) {
        # Silently bypass database.
        my $msg_dispatcher = $session->getMessageDispatcher;
        $msg_dispatcher->execute ($session, set => "timezone $value");
    } else {
        $session->sendMaster (set => "timezone $value");
    }
    
    return $self;
}

sub __showAll {
    my ($self) = @_;
    
    my $session = $self->{_session};
    my $user = $session->getUser;
    
    my $redoubles = $user->{redoubles} ? $user->{redoubles} : 'none';
    $redoubles = 'unlimited' if $redoubles eq '-1';
    
    my $output = <<EOF;
Settings of variables:
boardstyle: $user->{boardstyle}
linelength: $user->{linelength}
pagelength: $user->{pagelength}
redoubles:  $redoubles
sortwho:    $user->{sortwho}
timezone:   $user->{timezone}
EOF

    $session->reply ($output);
    
    return $self;
}

sub __invalidArgument {
    my ($self) = @_;
    
    $self->{_session}->reply ("** Invalid argument. Type 'help set'.\n");
    
    return $self;
}

sub __showValue {
    my ($self, $variable) = @_;
    
    my $session = $self->{_session};
    
    my %valid = map { $_ => 1 } qw (boardstyle linelength pagelength
                                    redoubles sortwho timezone);
    if (!$valid{$variable}) {
        return $self->__invalidArgument ("Invalid argument. Type 'help set'.\n");
    }
    
    my $value = $session->getUser->{$variable};
    if ('redoubles' eq $variable) {
        $value = $value ? $value : 'none';
        $value = 'unlimited' if $value eq '-1';
    }
    
    $session->reply ("Value of '$variable' is $value\n");
    
    return $self;
}

1;

=head1 NAME

BaldLies::Session::Command::set - BaldLies Command `set'

=head1 SYNOPSIS

  use BaldLies::Session::Command::set->new (set => $session, $call);
  
=head1 DESCRIPTION

This plug-in handles the ommand `set'.

=head1 SEE ALSO

BaldLies::Session::Command(3pm), baldlies(1), perl(1)

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

package BaldLies::Master::Command::show;

use strict;

use base qw (BaldLies::Master::Command);
use BaldLies::Util qw (empty equals);

sub execute {
    my ($self, $fd, $payload) = @_;
    
    my $master = $self->{_master};
    my $logger = $master->getLogger;

    my ($what, $argument) = split / /, $payload;
        
    if ('games' eq $what) {
        $self->__showGames ($fd);
    } elsif ('saved' eq $what) {
        $self->__showSaved ($fd);
    } elsif ('savedcount' eq $what) {
        $self->__showSavedCount ($fd, $argument);
    } else {
        $master->queueResponse ($fd, 
                                reply => "** Don't know how to show $what");
    }

    return $self;
}

sub __showGames {
    my ($self, $fd) = @_;
    
    my $master = $self->{_master};
    my $database = $master->getDatabase;
    
    my $matches = $database->getActiveMatches;
    unless ($matches) {
        $master->queueResponse ($fd,
                                reply => "** Database error, no games");
        return $self;
    }
    
    my $reply = "List of games:\\n";
    foreach my $record (@$matches) {
        my ($p1, $p2, $l, $s1, $s2) = @$record;
        $reply .= sprintf "%-15s - %15s (%s match %u-%u)\\n",
                          $p1, $p2, $l < 0 ? "unlimited" : "$l point", $s1, $s2;
    }
    $master->queueResponse ($fd, echo_e => $reply);
    
    return $self;
}

sub __showSaved {
    my ($self, $fd) = @_;
    
    my $master = $self->{_master};
    my $database = $master->getDatabase;
    
    my $user = $master->getUserFromDescriptor ($fd);
    
    my $matches = $database->getSavedMatches ($user->{id});
    unless ($matches) {
        $master->queueResponse ($fd,
                                reply => "** Database error, no matches");
        return $self;
    }
    
    unless (@$matches) {
        $master->queueResponse ($fd,
                                reply => "no saved games.");
        return $self;
    }

    my $msg = "  opponent          matchlength   score (your points first)\\n";
    foreach my $info (@$matches) {
        my ($opponent, $other, $l, $s1, $s2) = @$info;
        if ($opponent eq $user->{name}) {
            $opponent = $other;
            ($s1, $s2) = ($s2, $s1);
        }
        my $lformat;
        if ($l < 0) {
            $l = 'unlimited';
            $lformat = '%s';
        } else {
            $lformat = '    % 2d   ';
        }
        my $marker = '  ';
        if ($master->getUser ($opponent)) {
            if (equals $opponent, $user->{playing}) {
                $marker = '**';
            } else {
                $marker = ' *';
            }
        }
        $msg .= sprintf "$marker%-19s$lformat            % 2d - % 2d\\n",
                        $opponent, $l, $s2, $s1;
    }
    
    $master->queueResponse ($fd, echo_e => $msg);
    return $self;
}

sub __showSavedCount {
    my ($self, $fd, $who) = @_;
    
    my $master = $self->{_master};
    my $database = $master->getDatabase;
    
    if (empty $who) {
        my $user = $master->getUserFromDescriptor ($fd);
        $who = $user->{name};
    }
    
    my $count = $database->getSavedCount ($who);
    if (0 == $count) {
        $master->queueResponse ($fd,
                                reply => "$who has no saved games.");
    } elsif (1 == $count) {
        $master->queueResponse ($fd,
                                reply => "$who has 1 saved game.");
    } else {
        $master->queueResponse ($fd,
                                reply => "$who has $count saved games.");
    }

    return $self;
}

1;

=head1 NAME

BaldLies::Master::Command::show - BaldLies Command `show'

=head1 SYNOPSIS

  use BaldLies::Master::Command::show->new ($master);
  
=head1 DESCRIPTION

This plug-in handles the master command `show'.

=head1 SEE ALSO

BaldLies::Master::Command(3pm), baldlies(1), perl(1)

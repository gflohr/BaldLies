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

package BaldLies::Session::Command::ratings;

use strict;

use base qw (BaldLies::Session::Command);

use BaldLies::Util qw (empty);
use BaldLies::Const qw (:colors);

sub execute {
    my ($self, $payload) = @_;
    
    my $session = $self->{_session};
    my $user = $session->getUser;
    
    $payload = '' if empty $payload;
    
    my @tokens = split / +/, $payload;
    my $params;
    if (!@tokens) {
        $params = 'range 1 20';
    } elsif (@tokens >= 4 && 'from' eq $tokens[0] && 'to' eq $tokens[2]) {
        if (@tokens > 4) {
            splice @tokens, 0, 4;
        } else {
            my ($from, $to) = @tokens[1, 3];
            if ($from !~ /^[1-9][0-9]+$/) {
                $session->reply ("** Please give a positive number after"
                                 . " 'from'.\n");
                return $self;
            }
            if ($to !~ /^[1-9][0-9]+$/) {
                $session->reply ("** Please give a positive number after"
                                 . " 'to'.\n");
                return $self;
            }
            if ($to <= $from) {
                $session->reply ("** Invalid range from $from to $to\n");
                return $self;
            }
            if ($to - $from > 100) {
                $session->reply ("** range currently limited to 100.\n");
                return $self;
            }
            $params = "range $from $to";
        }
    }
    
    if (empty $params) {
        if (@tokens > 1) {
            $session->reply ("** Please use only one of the given names"
                             . " '$tokens[0]' and '$tokens[1]'.\n");
            return $self;
        }
        if (!@tokens) {
            # Cannot actually not happen.
            $params = 'range 1 20';
        } else {
            $params = "user $tokens[0]";
        }
    }
    
    $session->sendMaster (ratings => $params);
    
    return $self;    
}

1;

=head1 NAME

BaldLies::Session::Command::ratings - BaldLies Command `ratings'

=head1 SYNOPSIS

  use BaldLies::Session::Command::ratings->new (ratings => $session, $call);
  
=head1 DESCRIPTION

This plug-in handles the ommand `ratings'.

=head1 SEE ALSO

BaldLies::Session::Command(3pm), baldlies(1), perl(1)

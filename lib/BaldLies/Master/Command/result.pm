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

package BaldLies::Master::Command::result;

use strict;

use base qw (BaldLies::Master::Command);

use BaldLies::Util qw (empty);

sub execute {
    my ($self, $fd, $payload) = @_;
    
    my $master = $self->{_master};
    
    my $logger = $master->getLogger;

    my ($score1, $score2) = split / /, $payload;
    $logger->debug ("End of match, score $score1-$score2.");
    
    my $white_user = $master->getUserFromDescriptor ($fd);
    unless ($white_user) {
        $logger->error ("Got end-of-match from vanished user ($fd).");
        return $self;
    }
    
    my $player1 = $white_user->{name};
    my $player2 = $white_user->{playing};
    if (empty $player2) {
        $logger->error ("Result from user `$player1' but no match.");
        return $self;
    }
    
    if ($score1 == $score2) {
        $logger->error ("Match between `$player1' and `$player2' was a draw.");
        return $self;
    }
    
    my $black_user = $master->getUser ($player2);
    if (!$black_user) {
        $logger->error ("Opponent `$player2' of `$player1' has vanished.");
        return $self;
    }
    
    my $database = $master->getDatabase;
    my $id1 = $white_user->{id};
    my $id2 = $black_user->{id};
    my $match_info = $database->loadMatch ($id1, $id2);
    unless ($match_info && %$match_info) {
        $logger->error ("Match `$player1' vs `$player2' has vanished.");
        return $self;
    }
    
    # Calculate the rating change.
    my $r1 = $match_info->{rating1};
    my $r2 = $match_info->{rating2};    
    my $e1 = $match_info->{experience1};
    my $e2 = $match_info->{experience2};
    my $D = abs ($r1 - $r2);
    my $N = $match_info->{length};
    my $Pu = 1 / (10 ** ($D * sqrt ($N) / 2000) + 1);
    my $P;
    if ($r1 > $r2) {
        if ($score1 > $score2) {
            $P = $Pu;
        } else {
            $P = 1 - $Pu;
        }
    } else {
        if ($score1 > $score2) {
            $P = 1 - $Pu;
        } else {
            $P = $Pu;
        }
    }
    my $K1 = -$e1 / 100 + 5;
    $K1 = 1 if $K1 < 1;
    my $K2 = -$e2 / 100 + 5;
    $K2 = 1 if $K2 < 1;
    my $c1 = 4 * $K1 * sqrt ($N) * $P;
    $c1 = -$c1 if $score1 < $score2;
    my $c2 = 4 * $K2 * sqrt ($N) * $P;
    $c2 = -$c2 if $score2 < $score1;   
    
    $database->endOfMatch ($id1, $id2, $N, $c1, $c2);
    $white_user->{rating} += $c1;
    $white_user->{experience} += $N;
    $black_user->{rating} += $c2;
    $black_user->{experience} += $N;

    # Format numbers.
    $D = sprintf '%.6f', $D;
    $Pu = sprintf '%.6f', $Pu;
    $P = sprintf '%.6f', $P;
    $K1 = sprintf '%.6f', $K1;
    $K2 = sprintf '%.6f', $K2;
    $c1 = sprintf '%.6f', $c1;
    $c2 = sprintf '%.6f', $c2;
    my $sign1 = $score1 < $score2 ? '-' : '';
    my $sign2 = $score2 < $score2 ? '-' : '';
    
    my $ratings = <<EOF;
rating calculation:
rating difference D=$D
match length      N=$N
Experience: $player1 $e1 - $player2 $e2
Probability that underdog wins: Pu=1/(10^(D*sqrt(N)/2000)+1)=$Pu
P=$P is 1-Pu if underdog wins and Pu if favorite wins
K=max(1 , -Experience/100+5) for $player1: $K1
change for $player1: ${sign1}4*K*sqrt(N)*P=$c1
K=max(1 , -Experience/100+5) for $player2: $K2
change for $player2: ${sign2}4*K*sqrt(N)*P=$c2
EOF
    $logger->debug ($ratings);
    
    my $report = '';
    if ($score1 > $score2) {
        $report = "$player1 wins a $N point match against $player2"
                  . "  $score1-$score2 .";
    } else {
        $report = "$player2 wins a $N point match against $player1"
                  . "  $score2-$score1 .";
    }
    
    delete $white_user->{playing};
    my $info1 = $white_user->rawwho;
    delete $black_user->{playing};
    my $info2 = $black_user->rawwho;

    foreach my $name ($master->getLoggedIn) {
        if ($name eq $white_user->{name}) {
            my $reply = '';
            if ($white_user->{ratings}) {
                $reply = $ratings . "\n";
            }
            if ($score1 > $score2) {
                $reply .= "You win the $N point match $score1-$score2 .";
            } else {
                $reply .= "$player2 wins the $N point match"
                          . " $score2-$score1 .";
            }
            $reply =~ s/\n/\\n/g;
            $master->queueResponseForUser ($name, echo_e => $reply);
        } elsif ($name eq $black_user->{name}) {
            my $reply = '';
            if ($black_user->{ratings}) {
                $reply = $ratings . "\n";
            }
            if ($score1 > $score2) {
                $reply .= "$player1 wins the $N point match"
                          . " $score1-$score2 .";
            } else {
                $reply .= "You win the $N point match $score2-$score1 .";
            }
            $reply =~ s/\n/\\n/g;
            $master->queueResponseForUser ($name, echo_e => $reply);
        } else {
            my $user = $master->getUser ($name);
            if ($user->{report}) {
                $master->queueResponseForUser ($name, echo =>
                                               $report);
            }
        }
        $master->queueResponseForUser ($name, status => $info1);
        $master->queueResponseForUser ($name, status => $info2);
    }
    
    return $self;
}

1;

=head1 NAME

BaldLies::Master::Command::result - BaldLies Command `result'

=head1 SYNOPSIS

  use BaldLies::Master::Command::result->new ($master);
  
=head1 DESCRIPTION

This plug-in handles the master command `result'.

=head1 SEE ALSO

BaldLies::Master::Command(3pm), baldlies(1), perl(1)

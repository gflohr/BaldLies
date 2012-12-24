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

package BaldLies::Session::Message::play;

use strict;

use base qw (BaldLies::Session::Message);
use BaldLies::Const qw (:colors);
use BaldLies::User;
use BaldLies::Util qw (equals);

sub execute {
    my ($self, $session, $payload) = @_;
    
    my $logger = $session->getLogger;

    $logger->debug ("Match play action: $payload");
    my ($action, $color, @data) = split / /, $payload;
    
    $self->{__session} = $session;
    my $user = $session->getUser;
    
    if (defined $color && $color == 0 && 'roll' eq $action) {
        $action = 'opening';
    }
    
    my $method = '__handle' . ucfirst $action;
    
    my $match = $self->{__match} = $user->{match};
    die "No match!\n" unless $match;
    
    if (equals $user->{name}, $match->player1) {
        $self->{__color} = WHITE;
        $self->{__me} = $user->{name};
        $self->{__other} = $user->{playing};
    } elsif (equals $user->{name}, $match->player2) {
        $self->{__color} = BLACK;
        $self->{__me} = $user->{name};
        $self->{__other} = $match->player1;
    } else {
        die "Orphaned play message";
    }
    
    return $self->$method ($color, @data);
}

sub __handleStart {
    my ($self, $color) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};
    
    my $opponent = $self->{__other};
    
    $session->reply ("Starting a new game with $opponent.\n", 1);
    
    if ($self->{__color} == WHITE) {
        my $die1 = 1 + int rand 6;
        my $die2 = 1 + int rand 6;
        eval { $match->do (roll => 0, $die1, $die2) };
        if ($@) {
            chomp $@;
            $session->reply ("** $@\n");
            return $self;
        }
    
        my $board = $match->dump;
        $session->sendMaster (play => $board, roll => 0, $die1, $die2);

        return $self;
    }
    
    return $self;
}

sub __handleResume {
    my ($self, $color) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};
    
    my ($player1, $player2) = ($match->player1, $match->player2);    
    my ($score1, $score2) = $match->score;    

    my $turn = $match->getTurn;
    
    my $reply = '';
    if ($turn == WHITE) {
        $reply .= "turn: $player1\n";
    } elsif ($turn == BLACK) {
        $reply .= "turn: $player2\n";
    } else {
        # Nothing.
    }
    
    my $length = $match->getLength;
    if ($length < 0) {
        $reply .= "unlimited matchlength\n";
    } else {
        $reply .= "match length: $length\n";
    }
    
    $reply .= <<EOF;
points for user $player1: $score1
points for user $player2: $score2
EOF

    if (!$turn && $color == WHITE) {
        my $die1 = 1 + int rand 6;
        my $die2 = 1 + int rand 6;
        eval { $match->do (roll => 0, $die1, $die2) };
        if ($@) {
            chomp $@;
            $session->reply ("** $@\n");
            return $self;
        }
    
        my $board = $match->dump;
        $session->sendMaster (play => $board, roll => 0, $die1, $die2);
    } else {
        $reply .= $user->{match}->board ($user->{boardstyle}, 
                                         $self->{__color} == BLACK);
    }
    
    $session->reply ($reply);
    
    return $self;
}

sub __handleOpening {
    my ($self, $color, $die1, $die2) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};

    if ($self->{__color} == BLACK) {
        $logger->debug ("Match action ($user->{name}): roll 0 $die1 $die2");
        $match->do (roll => 0, $die1, $die2);
    }
    
    my $opponent = $self->{__other};

    if ($self->{__color} == BLACK) {
        ($die1, $die2) = ($die2, $die1);
    }
    $session->reply ("You rolled $die1, $opponent rolled $die2.\n", 1);
    
    if ($die1 == $die2) {
        if ($match->getAutodouble) {
            my $cube = $match->getCube;
            $session->reply ("The number on the doubling cube is now $cube", 1);
        }
        if ($self->{__color} == WHITE) {
            my $die1 = 1 + int rand 6;
            my $die2 = 1 + int rand 6;
            eval { $match->do (roll => 0, $die1, $die2) };
            if ($@) {
                chomp $@;
                $session->reply ("** $@\n");
                return $self;
            }
    
            my $board = $match->dump;
            $session->sendMaster (play => $board, roll => 0, $die1, $die2);
            
            return $self;
        }
        return $self;
    }
    
    if ($die1 > $die2) {
        if ($self->{__color}) {
            $session->reply ("It's your turn to move.\n", 1);
        } else {
            $session->reply ("You make the first move.\n", 1);
        }
    } elsif ($die1 < $die2) {
        $session->reply ("$opponent makes the first move.\n", 1);
    }
    
    $session->reply ($user->{match}->board ($user->{boardstyle}, 
                                            $self->{__color} == BLACK));
   
    return $self;
}

sub __handleMove {
    my ($self, $color, @points) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};
    my $no_prompt;

    my $msg = '';
    
    if ($self->{__color} == $color) {
        # This is our own move which is already applied to the match.
    } else {
        $logger->debug ("Match action ($self->{__me}):"
                        . " move $color @points");
        $match->do (move => $color, @points);
        my $who = $color == BLACK ? $match->player2 : $match->player1;
        if (@points) {
            my $formatted = $self->__formatMove ($color, @points);
            $msg .= "\n$who moves$formatted .\n";
        } else {
            $msg .= "\n$who can't move.\n";
        }
    }
    
    if ($match->gameOver) {
        my $value = $match->getLastWin;

        if ($self->{__color} == $color) {
            my $points = $value == 1 ? "1 point" : "$value points";
            $msg = "You win the game and get $points. Congratulations!\n";
        } else {
            my $points = $value == 1 ? "1 point" : "$value points";
            my $opp = $self->{__color} == BLACK ? $match->player1 : $match->player2;
            $msg = "$opp wins the game and gets $points. Sorry.\n";
        }
        return $self->__endOfGame ($msg);
    }
    
    
    my $cube_owner = $match->getCubeOwner;
    if ($color != $self->{__color}) {
        # Send feedback to opponent.
        if ($user->{autoboard}) {
            $msg .= $user->{match}->board ($user->{boardstyle}, 
                                           $self->{__color} == BLACK);
        }
        my $game = $match->getCurrentGame;
        my $is_crawford = $game->isCrawford;
        if ($is_crawford
            || ($cube_owner && $cube_owner != $self->{__color})) {
            $no_prompt = 1;
        } else {
            $msg .= "It's your turn. Please roll or double.\n";
        }
    } else {
        # Send feedback to player.
        if ($user->{autoboard}) {
            $msg .= $user->{match}->board ($user->{boardstyle}, 
                                           $self->{__color} == BLACK);
        } elsif (@points) {
            # Only, when we can actually move.
            $msg .= "Done.\n";
        } 
    }
    
    $session->reply ($msg, $no_prompt);
    
    if ($color != $self->{__color} && $cube_owner
        && $cube_owner != $self->{__color}) {
        my $dispatcher = $session->getCommandDispatcher;
        $dispatcher->execute ($session, 'roll');
    }

    return $self;
}

sub __handleRoll {
    my ($self, $color, $die1, $die2) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};

    my $msg = '';
    
    if ($self->{__color} == $color) {
        # This is our own roll which is already applied to the match.
    } else {
        $logger->debug ("Match action ($self->{__me}:"
                        . " roll $color $die1 $die2");
        $match->do (roll => $color, $die1, $die2);
        my $who = $color == BLACK ? $match->player2 : $match->player1;
        $msg .= "\n$who rolls $die1 and $die2.\n";
    }
    
    if ($color == $self->{__color}) {
        my $moves = $match->legalMoves;
        my $num_moves = @$moves;
        if ($num_moves) {
            if (1 == $num_moves && $user->{automove}) {
                my @points = @{$moves->[0]};
                my $formatted = $self->__formatMove ($color, @points);
                $msg .= "The only possible move is$formatted .\n";
                eval { $match->do (move => $color, @points) };
                if ($@) {
                    chomp $@;
                    $session->reply ("$msg** $@\n");
                    return $self;
                }
	        if ($user->{autoboard}) {
	            $msg .= $user->{match}->board ($user->{boardstyle}, 
	                                           $self->{__color} == BLACK);
	        }
                my $board = $match->dump;
                $session->sendMaster (play => $board, move => $color, @points);
            } else {
	        if ($user->{autoboard}) {
	            $msg .= $user->{match}->board ($user->{boardstyle}, 
	                                           $self->{__color} == BLACK);
	        }
                my $num_pieces = @{$moves->[0]} >> 1;
                $msg .= "Please move $num_pieces pieces.\n";
            }
        } else {
            $msg .= "You can't move.\n";
            eval { $match->do (move => $color) };
            if ($@) {
                chomp $@;
                $session->reply ("$msg** $@\n");
                return $self;
            }
            my $board = $match->dump;
            $session->sendMaster (play => $board, move => $color);
        }
    }
    
    $session->reply ($msg);
    
    return $self;
}

sub __handleDouble {
    my ($self, $color) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};

    my $msg = '';
    
    if ($self->{__color} == $color) {
        my $opp = $color == BLACK ? $match->player1 : $match->player2;
        $msg = "You double. Please wait for $opp to accept or reject.\n";
    } else {
        $logger->debug ("Match action ($self->{__me}:"
                        . " double $color");
        $match->do (double => $color);
        my $who = $color == BLACK ? $match->player2 : $match->player1;
        $msg .= "$who doubles. Type 'accept' or 'reject'.\n";
    }
    
    $session->reply ($msg);
    
    return $self;
}

sub __handleResign {
    my ($self, $color, $value) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};

    my $msg = '';
    
    my $points = $value == 1 ? "1 point" : "$value points";
    
    if ($self->{__color} == $color) {
        my $opp = $color == BLACK ? $match->player1 : $match->player2;
        $msg = "You want to resign. $opp will win $points.\n";
    } else {
        $logger->debug ("Match action ($self->{__me}:"
                        . " resign $color $value");
        $match->do (resign => $color, $value);
        my $who = $color == BLACK ? $match->player2 : $match->player1;
        $msg .= "$who wants to resign. You will win $points."
                . " Type 'accept' or 'reject'.\n";
    }
    
    $session->reply ($msg);
    
    return $self;
}

sub __handleAccept {
    my ($self, $color) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};

    my $msg = '';
    if ($self->{__color} == $color) {
        my $value = $match->getLastWin;
        my $points = $value == 1 ? "1 point" : "$value points";
        $msg = "You accept and win $points.\n";
    } else {
        my $value = abs $match->getResignation;
        my $points = $value == 1 ? "1 point" : "$value points";
        $match->do (accept => $color);
        my $opp = $self->{__color} == BLACK ? $match->player1 : $match->player2;
        $msg = "$opp accepts and wins $points.\n";
    }
    
    $self->__endOfGame ($msg);
    
    return $self;
}

sub __handleTake {
    my ($self, $color) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};
    my $no_prompt;
    
    my $msg = '';
    if ($self->{__color} == $color) {
        my $cube = $match->getCube;
        $msg = "You accept the double. The cube shows $cube.\n";
    } else {
        $match->do (accept => $color);
        my $cube = $match->getCube;
        my $opp = $color == WHITE ? $match->player1 : $match->player2;
        $msg = "$opp accepts the double. The cube shows $cube.\n";
        $no_prompt = 1;
    }
    
    $session->reply ($msg, $no_prompt);

    if ($self->{__color} != $color) {
        my $dispatcher = $session->getCommandDispatcher;
        $dispatcher->execute ($session, 'roll');
    }
    
    return $self;
}

sub __handleReject {
    my ($self, $color) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};
    
    if ($self->{__color} == $color) {
        $session->reply ("You reject. The game continues.\n");
    } else {
        $match->do (reject => $color);
        my $opp = $color == WHITE ? $match->player1 : $match->player2;
        $session->reply ("$opp rejects. The game continues.\n");
    }
    
    return $self;
}

sub __handleDrop {
    my ($self, $color) = @_;
    
    my $session = $self->{__session};
    my $logger = $session->getLogger;
    my $user = $session->getUser;
    my $match = $user->{match};

    my $msg = '';
    my $cube = $match->getCube;
    my $points = $cube == 1 ? "1 point" : "$cube points";
    if ($self->{__color} == $color) {
        $msg = "You give up. $user->{playing} wins $points.\n";
    } else {
        $match->do (reject => $color);
        $msg = "\n$user->{playing} gives up. You win $points.\n";
    }
    
    $self->__endOfGame ($msg);

    return $self;
}

sub __endOfGame {
    my ($self, $msg) = @_;

    my $session = $self->{__session};
    my $user = $session->getUser;
    $user->startGame;
    my $match = $user->{match};
    
    if ($user->{moves}) {
        chomp $msg;
        $msg .= $match->getMoves;
    }
    
    return $self->__endOfMatch ($msg) if $match->over;
    
    my $logger = $session->getLogger;
    
    my ($score1, $score2) = $match->score;
    my $points = $match->getLength;
    if ($points < 0) {
        $points = 'unlimited';
    } else {
        $points = "$points point";
    }
    my $score;
    
    if ($user->{name} eq $match->player1) {
        my $opp = $match->player2;
        $score = "$user->{name}-$score1 $opp-$score2";
        my $post_crawford = $match->getPostCrawford ? 1 : 0;
        $session->sendMaster (end_of_game => $score1, $score2, $post_crawford);
    } else {
        my $opp = $match->player1;
        $score = "$user->{name}-$score2 $opp-$score1";
    }
    
    $msg .= "score in $points match: $score\n";
    $msg .= <<EOF;
Type 'join' if you want to play the next game, type 'leave' if you don't.
EOF

    $session->reply ($msg);
    
    return $self;
}

sub __endOfMatch {
    my ($self, $msg) = @_;
    
    my $session = $self->{__session};
    
    $session->reply ($msg, 1);
    
    my $user = $session->getUser;
    my $match = $user->{match};

    my @score = $match->score;
    
    $session->sendMaster (result => "@score")
        if $user->{name} eq $match->player1;
    my $opponent = delete $user->{playing};
    delete $user->{match};
    
    my $users = $session->getUsers ($opponent);
    if ($opponent && exists $users->{$opponent}) {
        delete $users->{$opponent}->{playing};
    }
    
    return $self;
}

sub __formatMove {
    my ($self, $color, @points) = @_;
    
    my $move = '';
    
    my ($home, $bar);
    if ($color == BLACK) {
        ($home, $bar) = (25, 0);
    } else {
        ($home, $bar) = (0, 25);
    }
    while (@points) {
        my $from = shift @points;
        my $to = shift @points;
        $from = 'bar' if $from == $bar;
        $to = 'home' if $to == $home;
        $move .= " $from-$to";
    }

    return $move;
}

1;

=head1 NAME

BaldLies::Session::Message::play - BaldLies Message `play'

=head1 SYNOPSIS

  use BaldLies::Session::Message::play->new;
  
=head1 DESCRIPTION

This plug-in handles the master message `play'.

=head1 SEE ALSO

BaldLies::Session::Message(3pm), baldlies(1), perl(1)

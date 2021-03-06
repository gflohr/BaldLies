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

package BaldLies::User;

use strict;

use BaldLies::Util qw (empty);

my @properties = qw (id name password address admin last_login last_logout 
                     last_host experience rating boardstyle linelength 
                     pagelength redoubles sortwho timezone allowpip autoboard 
                     autodouble automove bell crawford double greedy 
                     moreboards moves notify ratings ready report silent 
                     telnet wrap client ip login);
                      
sub new {
    my ($class, @args) = @_;

    my %self;
    @self{@properties} = @args;
    
    # The first user is automatically superuser.
    $self{admin} = 1 if !$self{id};
    $self{away} = '';

    bless \%self, $class;
}

sub copy {
    my ($self) = @_;
    
    bless {%$self}, ref $self;
}

sub startGame {
    my ($self) = @_;
    
    $self->{double} = 1;
    $self->{greedy} = 0;
    $self->{moves} = 0;
    
    return $self;
}

sub rawwho {
    my ($self) = @_;
    
    my $playing = $self->{playing} || '-';
    my $watching = $self->{watching} || '-';
    my $away = $self->{away} || 0;
    my $rating = sprintf '%.2f', $self->{rating};
    my $address = $self->{address} || '-';
    
    return "$self->{name} $playing $watching $self->{ready}"
           . " $away $rating $self->{experience} 0 $self->{login} $self->{ip}"
           . " $self->{client} $address";
}

1;

=head1 NAME

BaldLies::User - BaldLies User Abstraction Class

=head1 SYNOPSIS

  use BaldLies::User;
  
  BaldLies::User->new (@properties);
  
=head1 DESCRIPTION

B<BaldLies::User> is the abstraction for a user currently logged in.
The class is internal.

=head1 SEE ALSO

BaldLies::Server(3pm), baldlies(1), perl(1)

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

package OpenFIBS::Logger;

use strict;

use POSIX qw (strftime);
use Time::HiRes qw (gettimeofday);
use IO::File;
use Fcntl qw (:DEFAULT :flock);

use OpenFIBS::Const qw (:log_levels);
use OpenFIBS::Util qw (empty);

sub new {
    my ($class, %args) = @_;

    my $self = {
        __level => $args{level},
        __prefix => $args{prefix},
        __timefmt => $args{timefmt},
        __logfile => $args{logfile},
        __stderr => $args{stderr},
        __hires => $args{hires},
        __ip => $args{ip},
    };

    $self->{__level} = LOG_NOTICE if empty $self->{__level};

    $self->{__timefmt} = '%a %b %d %H:%M:%S %Y' if empty $self->{__timefmt};

    bless $self, $class;
}

sub __logFunc {
    my ($self, $type, @msg) = @_;
    
    my $msg = $self->__makeMessage($type, @msg);
    
    if ($self->{__stderr}) {
        $self->{__stderr}->print($msg);
    };
    
    if (!empty $self->{__logfile}) {
        my $fd = IO::File->new ($self->{__logfile}, 
                                O_RDWR | O_CREAT | O_APPEND, 0644)
            or die "Cannot open logfile `$self->{__logfile} for writing: $!!\n";
        
        flock $fd, LOCK_EX
            or die "Cannot lock logfile `$self->{__logfile}: $!!\n";

        $fd->print ($msg)
            or die "Cannot write to logfile `$self->{__logfile}: $!!\n";
        $fd->close or die "Cannot close logfile `$self->{__logfile}: $!!\n";
    }
    
    return $self;
}

sub __makeMessage {
    my ($self, $type, @msgs) = @_;
    
    my $prefix = $self->{__prefix};
    $prefix = '' unless $prefix;
    
    my $timestamp = strftime $self->{__timefmt}, localtime;
    
    my $hires = '';
    if ($self->{__hires}) {
        my ($whole, $trailing) = split(/[^0-9]/, scalar gettimeofday());
        $trailing ||= '';
        $trailing .= length($trailing) < 5
                   ? '0' x (5 - length($trailing))
                   : '';
        $hires = "$whole.$trailing";
    }
    
    my $ip = $self->{__ip} || '';
    
    my $pre = join ' ',
              map { "[$_]" }
              grep { $_ } $timestamp, $hires, $ip, $type, $prefix;
    $pre .= ' ';
    
    my @chomped = map { $pre . $_ } 
                  grep { $_ ne '' }
                  map { $self->__trim($_) } @msgs;

    my $msg = join "\n", @chomped, '';
    
    return $msg;
}

sub error {
    my ($self, @msgs) = @_;

    $self->__logFunc (error => @msgs);

    return 1;
}

sub warning {
    my ($self, @msgs) = @_;

    return if $self->{__level} < LOG_WARN;

    $self->__logFunc (warning => @msgs);

    return 1;
}

sub notice {
    my ($self, @msgs) = @_;

    return if $self->{__level} < LOG_NOTICE;

    $self->__logFunc(notice => @msgs);
    
    return 1;
}

sub info {
    my ($self, @msgs) = @_;

    return if $self->{__level} < LOG_INFO;

    $self->__logFunc(info => @msgs);
    
    return 1;
}

sub debug {
    my ($self, @msgs) = @_;

    return if $self->{__level} < LOG_DEBUG;

    $self->__logFunc(debug => @msgs);

    return 1;
}

sub fatal {
    my ($self, @msgs) = @_;

    $self->__logFunc (fatal => @msgs);

    exit 1;
}

sub level {
    my ($self, $level) = @_;
    
    $self->{__level} = $level unless empty $level;
    
    return $self->{__level};
}

sub ip {
    my ($self, $ip) = @_;
    
    $self->{__ip} = $ip unless empty $ip;
    
    return $self->{__ip};
}

sub __trim {
    my ($self, $line) = @_;
    return '' unless defined $line;
    $line =~ s/\s+$//mg;
    return split /\n/, $line;
}

1;

=head1 NAME

OpenFIBS::Logger - OpenFIBS Logging Class

=head1 SYNOPSIS

  use OpenFIBS::Logger->new;
  
  OpenFIBS::Logger->new (level => LOG_INFO);

=head1 DESCRIPTION

B<OpenFIBS::Logger> formats and prints log messages.

=head1 CONSTRUCTOR

The constructor accepts the following named arguments:

=over 4

=item B<level LOG_LEVEL>

B<LOG_LEVEL> should be one of LOG_ERROR, LOG_WARN, LOG_INFO, or LOG_DEBUG.
Defaults to B<LOG_NOTICE>.

=item B<stderr HANDLE>

If true, log (also) to file handle B<HANDLE>.

=item B<timefmt FORMAT>

Set time format to B<FORMAT> instead of '%a %b %d %H:%M:%S %Y'.  See
strftime() in POSIX(3pm) or strftime(3) for details.

=item B<prefix PREFIX>

Prefix all messages with B<PREFIX>.

=item B<ip IP>

Insert B<IP> address in output.

=item B<hires BOOLEAN>

Use a high-resolution timestamp.

=back 

=head1 METHODS

=over 4

=item B<error MSG, ...>

Log error messages B<MSG>.

=item B<warning MSG, ...>

Log warning messages B<MSG> if log level at least LOG_WARN.

=item B<warning MSG, ...>

Log notification messages B<MSG> if log level at least LOG_NOTICE.

=item B<info MSG, ...>

Log messages B<MSG> if log level at least LOG_INFO.

=item B<debug MSG, ...>

Log debugging messages B<MSG> if log level at least LOG_DEBUG.

=item B<fatal MSG, ...>

Log fatal error messages B<MSG> and exit immediately.

=item B<level LEVEL>

If B<LEVEL> is specified, set log level to B<LEVEL>.  Returns the now valid
level.

=item B<ip IP>

If B<IP> is specified, set IP address to B<IP>.  Returns the now used IP.

=back

=head1 SEE ALSO

OpenFIBS::Const (3pm), POSIX(3pm), OpenFIBS::Server(3pm), openfibs(1), perl(1)

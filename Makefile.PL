#! /usr/local/bin/perl -w

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
# along with Gibbon.  If not, see <http://www.gnu.org/licenses/>.

use ExtUtils::MakeMaker;

use strict;

WriteMakefile (
    NAME		    => 'BaldLies',
    VERSION_FROM	    => 'lib/BaldLies/Server.pm',
    ($] >= 5.005 ?
        (ABSTRACT	    => 'Open-Source Internet Backgammon Server',
         AUTHOR		    => 'Guido Flohr <guido@imperia.net>',
        ) : (),
    ),
    EXE_FILES               => [ 'bin/baldlies' ],
    PREREQ_PM	            => { 
        'Config::General' => 2.49,
        'File::HomeDir'   => 0.98,
        'File::Spec'      => 3.31,
        'DBD::SQLite'     => 0,
        'Digest::SHA'     => 5.47,
        'MIME::Base64'    => 0,
        'Storable'        => 0,
    },
);

eval "require Net::Interface";
if ($@) {
    warn <<EOF;
Prerequisite Net::Interface not found.  Your server will therefore
reject connections from your local network except from your local
machine!
$@
EOF
    sleep 2;
}

sub MY::postamble {
	return <<EOF;
all :: ReleaseNotes 

ReleaseNotes: NEWS
\tcat NEWS >\$\@
EOF
}

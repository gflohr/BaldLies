#! /usr/local/bin/perl -w

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
# along with Gibbon.  If not, see <http://www.gnu.org/licenses/>.

use ExtUtils::MakeMaker;

use strict;

WriteMakefile (
    NAME		    => 'OpenFIBS',
    VERSION_FROM	    => 'lib/OpenFIBS/Server.pm',
    ($] >= 5.005 ?
        (ABSTRACT	    => 'Open-Source Internet Backgammon Server',
         AUTHOR		    => 'Guido Flohr <guido@imperia.net>',
        ) : (),
    ),
    EXE_FILES               => [ 'bin/openfibs' ],
    PREREQ_PM	            => { 
        'Config::General' => 2.49,
        'File::HomeDir'   => 0.98,
        'File::Spec'      => 3.31,
        'DBI'             => 1.616,
        'Digest::SHA'     => 5.47,
    },
);

sub MY::postamble {
	return <<EOF;
all :: ReleaseNotes 

ReleaseNotes: NEWS
\tcat NEWS >\$\@
EOF
}

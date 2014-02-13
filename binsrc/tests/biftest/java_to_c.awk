BEGIN {
#
#  $Id$
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2014 OpenLink Software
#
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#
#

        in_file=0
	filename = FILENAME
	system ("rm -f " out_file);
}


/begin-base64.*/ {
	   in_file = 1
	   print "Added "FILENAME
	   print "char *"$3"=" > out_file
	   next
        }

/====/ {
	   print ";\n" > out_file
	   next
        }

#/"`"/ { next }

	{
	   in_file=0
	   print "\""$0"\"" > out_file
	   next
        }
END {close (out_file)}

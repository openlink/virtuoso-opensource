#!/bin/sh -x
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2017 OpenLink Software
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
# Installs the Admin pages

# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL



TARGETDIR=$1
FILELIST=`egrep -e '^binsrc/vsp' $TOP/bin/installer/enterprise.list | cut -f 1 -d ' ' | cut -b12-`


test ! -d "$TARGETDIR" && mkdir "$TARGETDIR"

for f in $FILELIST
do
    dstdir=`dirname $f`
    test ! -d $TARGETDIR/$dstdir && mkdir -p $TARGETDIR/$dstdir
    test -d "$f" && echo "$f" | grep -v CVS > /dev/null && test ! -d "$TARGETDIR/$f" && mkdir -p "$TARGETDIR/$f" 
    if test -d "$f" 
    then
	for sf in `find "$f" -type f | grep -v CVS`
	do
	   dstdir=`dirname $sf` 
	   test ! -d $TARGETDIR/$dstdir && mkdir -p $TARGETDIR/$dstdir
	   $INSTALL_DATA "$sf" "$TARGETDIR/$sf"
	done
    fi
    test ! -d "$f" && $INSTALL_DATA "$f" "$TARGETDIR/$f"
done

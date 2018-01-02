#!/bin/sh
#
#  $Id$
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2018 OpenLink Software
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

# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL

isql $PORT dba dba .dav_load.sql > .dav_load.log 2>&1
cat .dav_load.log | sed 's/^\(in lines .*\)$//g' | sed 's/^\([#]line .*\)$//g' | sed 's/Virtuoso Driver//g' | sed 's/Virtuoso Server//g' > .dav_load.log.tmp
diff -i -u .dav_load.etalon .dav_load.log.tmp > .dav_load.diff
if grep 'Error' .dav_load.diff > /dev/null
then
mcedit .dav_load.diff
else
echo OK
fi

#!/bin/sh
#
#  $Id$
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2012 OpenLink Software
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

# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL


USR=dav
PWD=dav
URLPUT="../urlsimu -u $USR -p $PWD "

COMPDOC ()
{
  CMP=`diff Resource.pdf get_resource | wc -l`
  if test $CMP -eq 0
  then
    echo "PASSED: NO DIFFERENCE BETWEEN SRC AND DST"
  else
    echo "*** FAILED: SRC AND DST NOT THE SAME"
  fi
}

LOCKTOKEN ()
{
  LT=`grep Lock-Token: $1`
}

CHEKLOG ()
{
  RC=`grep "^HTTP/1.1 $2" $3 | wc -l`
  if test $RC -eq 0
  then
    echo "PASSED: $1"
  else
    echo "*** FAILED: $1"
    grep "HTTP/1.1 $2" $3
  fi
}

echo "STARTED: DAV METHODS TEST"
rm dav.log errors.log err.log get_resource lock.log > /dev/null 2> /dev/null

$URLPUT opt.url > dav.log
CHEKLOG "OPTIONS" 4 dav.log

$URLPUT eopt.url | tee err.log > errors.log
CHEKLOG "OPTIONS OVER NOT-DAV ENABLED URL" "DAV: 1,2" err.log

$URLPUT prop.url >> dav.log
CHEKLOG "PROPFIND" 4 dav.log

$URLPUT mkcol.url >> dav.log
CHEKLOG "MKCOL" 4 dav.log

$URLPUT emkcol.url | tee err.log >> errors.log
CHEKLOG "DUPLICATE COLLECTION NAME" 2 err.log

$URLPUT put.url >> dav.log
CHEKLOG "PUT" 4 dav.log

$URLPUT -t get_resource get.url >> dav.log
CHEKLOG "GET" 4 dav.log
COMPDOC

$URLPUT -l "Timeout: Second-60" lock.url >> dav.log
CHEKLOG "LOCK" 4 dav.log

$URLPUT -l "Timeout: Second-60" lock.url | tee err.log >> errors.log
CHEKLOG "LOCKING OVER ALREADY LOCKED COLLECTION" 2 err.log

LOCKTOKEN dav.log
$URLPUT -l "$LT" unlock.url >> dav.log
CHEKLOG "UNLOCK" 4 dav.log

$URLPUT -l "$LT" unlock.url | tee err.log >> errors.log
CHEKLOG "UNLOCKING NONEXISTING LOCK" 2 err.log

$URLPUT -l "Destination: http://localhost%3a6666/DAV/Dav_Coll_Moved/" move.url >> dav.log
CHEKLOG "MOVE" 4 dav.log

$URLPUT -l "Destination: http://localhost:6666/DAV/Dav%20Coll%20Moved/" lmove.url >> dav.log
CHEKLOG "MOVE WITH LONGNAME" 4 dav.log

$URLPUT -l "Destination: http://localhost:6666/DAV/Dav_Coll_Copied/" copy.url >> dav.log
CHEKLOG "COPY" 4 dav.log

$URLPUT nlock.url > lock.log
CHEKLOG "LOCK AGAIN" 4 lock.log

$URLPUT ermcol.url | tee err.log >> errors.log
CHEKLOG "DELETE FORBIDDEN" 204 err.log

LOCKTOKEN lock.log
$URLPUT -l "$LT" nunlock.url >> lock.log
CHEKLOG "UNLOCK AGAIN" 4 lock.log

$URLPUT rmcol.url >> dav.log
CHEKLOG "DELETE" 4 dav.log

$URLPUT eprop.url | tee err.log >> errors.log
CHEKLOG "PROPFIND OVER NONEXISTING COLLECTION" 2 err.log

$URLPUT -t get_test eget.url | tee err.log >> errors.log
CHEKLOG "GET NONEXISTING RESOURCE" 2 err.log

echo "FINISHED: DAV METHODS TEST"

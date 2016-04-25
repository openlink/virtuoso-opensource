#!/bin/sh
#  tsql.sh
#
#  $Id$
#
#  SQL conformance tests
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2016 OpenLink Software
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

LOGFILE=tsql.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh
BANNER "STARTED SERIES OF DATETIME TESTS (tdatetime.sh)"

SHUTDOWN_SERVER

for TIMEZONELESS in 0 1 2 3 4 ; do
LOG + running sql script datetime, timezoneless $TIMEZONELESS
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
START_SERVER $PORT 1000
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tdatetime.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tdatetime.sql, timezoneless $TIMEZONELESS"
    exit 1
fi
SHUTDOWN_SERVER
mv -f $DBLOGFILE $DBLOGFILE.$TIMEZONELESS
mv -f $DBFILE $DBFILE.$TIMEZONELESS
done

CHECK_LOG
BANNER "COMPLETED SERIES OF SQL TESTS (tsql.sh)"

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

LOGFILE=tsqllite.output
export LOGFILE
. ./test_fn.sh

CLEAN_DBLOGFILE
CLEAN_DBFILE
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

STOP_SERVER
#START_SERVER $PORT 1000

BANNER "STARTED SERIES OF SQL TESTS (tsqllite.sh)"

#SHUTDOWN_SERVER

START_SERVER $PORT 1000

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < twords.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: Wordtest -- twords.sql"
    exit 1
fi
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tupdate.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tupdate.sql"
    exit 1
fi

RUN date


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tdelete.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tdelete.sql"
    exit 1
fi

SHUTDOWN_SERVER

CHECK_LOG
BANNER "COMPLETED SERIES OF SQL TESTS (tsql.sh)"

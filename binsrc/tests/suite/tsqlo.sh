#!/bin/sh
#
#  $Id: tsqlo.sh,v 1.25.4.2.4.13 2013/01/02 16:15:28 source Exp $
#
#  SQL Optimizer tests
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2013 OpenLink Software
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

LOGFILE=tsqlo.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

BANNER "STARTED SQL OPTIMIZER TESTS (tsqlo.sh)"

########################### LOCAL part #######################
LINE
LOG "Local SQL optimizer tests"
LINE
STOP_SERVER
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

START_SERVER $PORT 1000

LOG "Loading base tables"
RUN $INS $DSN 1000 20 dba dba
if test $STATUS -ne 0
then
    LOG "***ABORTED: tsqlo.sh: loading base tables"
    exit 1
else
    LOG "PASSED: tsqlo.sh: loading base tables"
fi

LOG + running sql script $VIRTUOSO_TEST/sqlo.sql
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/sqlo.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: tsqlo.sql: SQL optimizer functions"
    exit 3
fi

LOG + running sql script $VIRTUOSO_TEST/sqlo2.sql
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/sqlo2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tsqlo2.sql: SQL optimizer functions part 2"
    exit 3
fi

LOG + running sql script $VIRTUOSO_TEST/tiso.sql
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tiso.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tiso.sql: Isolation tests"
    exit 3
fi

#TODO: until fixed to run OK
LOG + running sql script $VIRTUOSO_TEST/uaggr_test.sql
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/uaggr_test.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tsqlo.sql: User aggrregates tests"
    exit 3
fi

LOG + running sql script $VIRTUOSO_TEST/cube.sql
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/cube.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tsqlo.sql: User aggrregates tests"
    exit 3
fi

SHUTDOWN_SERVER

CHECK_LOG
BANNER "COMPLETED SQL OPTIMIZER TESTS (tsqlo.sh)"

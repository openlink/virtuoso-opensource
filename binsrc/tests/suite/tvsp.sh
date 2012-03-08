#!/bin/sh
#
#  $Id$
#
#  Database recovery tests
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

LOGFILE=tvsp.output
export LOGFILE
. ./test_fn.sh


BANNER "STARTED VSP TEST (tvsp.sh)"

NOLITE

rm -f $DBLOGFILE
rm -f $DBFILE
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

SHUTDOWN_SERVER
START_SERVER $PORT 1000

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tvsp.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: tvsp.sql: VSP functions "
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < texcept.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: texcept.sql: Error handlers "
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tplscroll.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: tplscroll.sql: PL Scrollable cursors "
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tplinverse.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: tplinverse.sql: PL inverse suite "
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < udttest.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: udttest.sql: SQL200n user defined types "
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u '"UDTKIND=\"temporary self as ref\""' TYPE=temp < udtsec.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: udtsec.sql: SQL200n user defined types sequrity - temp types"
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'UDTKIND="\"--\""' TYPE=persistent < udtsec.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: udtsec.sql: SQL200n user defined types sequrity - persistent types"
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tdcascade.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: tdcascade.sql: Drop user cascade option tests"
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u N=\\\'\\\' michigan_park=michigan_park michigan_park_c=michigan_park_c < tregexp.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: tregexp.sql: oracle style regexp API check"
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u N=N michigan_park=michigan_parkN michigan_park_c=michigan_park_cN < tregexp.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: tregexp.sql: wide oracle style regexp API check"
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u N=N michigan_park=michigan_parkN2 michigan_park_c=michigan_park_cN2 < tregexpN.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: tregexpN.sql: wide oracle style regexp API check w/ some cyrillic"
    exit 3
fi

grep VDB ident.txt
if test $? -eq 0
then 
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tsnaprepl.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tsnaprepl.sh: snapshot local replication"
    exit 3
else
    LOG "PASSED: tsnaprepl.sh: snapshot local replication"
fi
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < dbev_login.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: dbev_login.sql: login hook "
    exit 3
else
    LOG "PASSED: dbev_login.sql: login hook "
fi

RUN $ISQL $DSN masterdba masterdbapwd PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT "'EXEC=drop procedure DB.DBA.DBEV_LOGIN'"
if test $STATUS -ne 0
then
    LOG "***ABORTED: login hook - logging in as masterdba"
    exit 3
else
    LOG "PASSED: login hook - logging in as masterdba"
fi

SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED VSP TEST (tvsp.sh)"

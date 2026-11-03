#!/bin/sh
#
#  Graph analytics tests
#
#  Runs the graph analytics SQL scripts against a fresh server.  The server
#  listens on HTTP too, because test_graph_security checks that a transient
#  graph does not survive from one /sparql request into the next.
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2026 OpenLink Software
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

TEST_NAME="Graph analytics"
LOGFILE=`basename $0 .sh`.output
export LOGFILE
CFGFILE=virtuoso.ini
DBFILE=virtuoso.db
DBLOGFILE=virtuoso.trx
DELETEMASK="virtuoso.log virtuoso.lck $DBLOGFILE $DBFILE virtuoso.tdb virtuoso.ttr"
SRVMSGLOGFILE=virtuoso.log
TESTCFGFILE=virtuoso-1111.ini
LOCKFILE=virtuoso.lck
export CFGFILE DBFILE DBLOGFILE DELETEMASK SRVMSGLOGFILE TESTCFGFILE LOCKFILE
. $VIRTUOSO_TEST/testlib.sh

BANNER "STARTED: $TEST_NAME TESTS"
NOLITE
rm -f $DBLOGFILE $DBFILE virtuoso.log virtuoso.lck virtuoso.tdb virtuoso.ttr
MAKECFG_FILE_WITH_HTTP "$VIRTUOSO_TEST/$TESTCFGFILE" $PORT $HTTPPORT $CFGFILE
SHUTDOWN_SERVER
START_SERVER $PORT 1000

for t in tgraphalgo test_graph_data test_graph test_graph_security test_graph_scale \
    test_graph_cache test_graph_limits test_graph_concurrency test_graph_conformance \
    test_graph_reference
do
    LOG + running sql script $t
    RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/$t.sql
    if test $STATUS -ne 0
    then
        LOG "***ABORTED: $t"
        exit 1
    fi
done

SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED $TEST_NAME TESTS"

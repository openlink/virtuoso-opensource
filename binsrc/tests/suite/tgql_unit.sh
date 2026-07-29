#!/bin/sh
#
#  $Id$
#
#  openGQL: GQL for Virtuoso - unit test harness
#
#  Runs the standalone GQL unit-test SQL scripts that live in binsrc/gql/
#  (translation, runtime, observability and end-to-end tests) against a fresh
#  server.  The GQL modules are compiled into the binary (sql_code_sparql.c)
#  and bootstrapped on database creation, so no VAD install or load step is
#  needed here.
#
#  Each script prints its per-assertion results via dbg_obj_print (server
#  console) and, if anything fails, signals SQLSTATE 23000 with a failure
#  count.  isql does NOT propagate that as a non-zero exit code, so this
#  harness scans the captured isql output for error markers and emits a
#  ***FAILED line (which the suite summary in summary.sh counts).
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

TEST_NAME="GQL Unit"
LOGFILE=`basename $0 .sh`.output
export LOGFILE
export CASE_MODE=2
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

# The canonical GQL unit-test scripts live in binsrc/gql/, not in this suite dir.
GQLDIR=$VIRTDEV_HOME/binsrc/gql

rm -f $DBLOGFILE
rm -f $DBFILE
rm -f virtuoso.log virtuoso.lck virtuoso.tdb virtuoso.ttr
MAKECFG_FILE "$VIRTUOSO_TEST/$TESTCFGFILE" $PORT $CFGFILE

# The translation tests assert the ontology/data namespace host, which GQL
# derives from the URIQA default host.  Pin it to the stock localhost:8890 so
# the generated IRIs match the tests regardless of this run's dynamic ports.
cat >> $CFGFILE <<END_URIQA

[URIQA]
DefaultHost = localhost:8890
END_URIQA

SHUTDOWN_SERVER
START_SERVER $PORT 1000

# GQL is compiled into the binary and bootstrapped on database creation.
# Verify it is available before running the scripts.
LOG "Verifying GQL modules are bootstrapped"
_ver=`$ISQL $DSN dba dba "EXEC=select DB.DBA.GQL_VERSION();" ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF 2>&1`
echo "$_ver" >> $LOGFILE
if echo "$_ver" | grep openGQL >/dev/null
then
    LOG "GQL modules bootstrapped: `echo "$_ver" | grep openGQL | head -1`"
else
    LOG "***FAILED: GQL modules not bootstrapped (GQL_VERSION unavailable)"
    SHUTDOWN_SERVER
    BANNER "COMPLETED: $TEST_NAME TESTS"
    exit 3
fi

# Run one GQL unit-test script.  A script is run in its own isql session via the
# positional-file form (with explicit dba/dba, since the file would otherwise be
# taken as the user name).  Because isql exits 0 even when a script signals
# 23000, we flag failure by scanning the output for a suite failure summary:
#   * "N test(s) failed"          -- scripts that signal 23000 with a count
#   * "<N> FAILED" (N > 0)        -- the observability script's ISQL counter
# Individual "*** Error" lines are NOT treated as failures on their own: some
# scripts deliberately run erroring queries to exercise error handling/counters.
RUN_GQL_UNIT()
{
    _script=$1
    if test ! -f "$GQLDIR/$_script"
    then
        LOG "***FAILED: $_script not found under $GQLDIR"
        return
    fi
    LOG "Running $_script"
    _out=`$ISQL $DSN dba dba $GQLDIR/$_script PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT 2>&1`
    echo "$_out" >> $LOGFILE
    if echo "$_out" | egrep 'test\(s\) failed|[1-9][0-9]* FAILED' >/dev/null
    then
        LOG "***FAILED: $_script"
    else
        LOG "PASSED: $_script"
    fi
}

RUN_GQL_UNIT test_gql_lexer.sql
RUN_GQL_UNIT test_gql_expr.sql
RUN_GQL_UNIT test_gql_parser.sql
RUN_GQL_UNIT test_gql_translate.sql
RUN_GQL_UNIT test_gql_runtime.sql
RUN_GQL_UNIT test_gql_stats.sql
RUN_GQL_UNIT test_gql_e2e.sql

SHUTDOWN_SERVER
BANNER "COMPLETED: $TEST_NAME TESTS"

#!/bin/sh
#
#  $Id$
#
#  openGQL: GQL for Virtuoso - RDF Equivalence Test Harness
#
#  Runs the GQL RDF equivalence test suites that mirror the SPARQL/RDF
#  test suites in binsrc/tests/suite/.
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

TEST_NAME="GQL RDF Equivalence"
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

rm -f $DBLOGFILE
rm -f $DBFILE
rm -f virtuoso.log virtuoso.lck virtuoso.tdb virtuoso.ttr
MAKECFG_FILE "$VIRTUOSO_TEST/$TESTCFGFILE" $PORT $CFGFILE
sed -e 's/^Load[1-6][	 ]*=.*/;&/' $CFGFILE > tmp.ini
mv -f tmp.ini $CFGFILE
cat >> $CFGFILE <<END_HTTP_COMPAT
[HTTPServer]
HTTPLogFile = http.log
ServerPort = $HTTPPORT
ServerRoot = .
ServerThreads = 3
MaxKeepAlives = 6
KeepAliveTimeout = 15
MaxCachedProxyConnections = 10
ProxyConnectionCacheTimeout = 15

[URIQA]
DynamicLocal = 1
DefaultHost = localhost:$HTTPPORT
END_HTTP_COMPAT

# Copy N-Quads test files needed by test_gql_rdf_load.sql
cp $VIRTUOSO_TEST/tst.nq .
cp $VIRTUOSO_TEST/tst2.nq .

SHUTDOWN_SERVER
START_SERVER $PORT 1000

# Load GQL modules (must run from build root so relative paths in gql_load.sql resolve)
LOG "Loading GQL modules"
_save_dir=`pwd`
_save_logfile="$LOGFILE"
cd $VIRTUOSO_BUILD
LOGFILE="$_save_dir/$_save_logfile"
export LOGFILE
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_BUILD/binsrc/gql/gql_load.sql
cd $_save_dir
LOGFILE="$_save_logfile"
export LOGFILE
if test $STATUS -ne 0
then
    LOG "***ABORTED: gql_load.sql: loading GQL modules"
    exit 3
fi

# Run the RDF API equivalence tests (mirrors trdfapi.sql)
LOG "Running GQL RDF API equivalence tests"
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_BUILD/binsrc/gql/test_gql_rdf_api.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: test_gql_rdf_api.sql"
    exit 3
fi

# Run the RDF inference equivalence tests (mirrors trdfinf.sql)
LOG "Running GQL RDF inference equivalence tests"
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_BUILD/binsrc/gql/test_gql_rdf_inference.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: test_gql_rdf_inference.sql"
    exit 3
fi

# Run the RDF loading equivalence tests (mirrors trdfld.sql)
LOG "Running GQL RDF loading equivalence tests"
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_BUILD/binsrc/gql/test_gql_rdf_load.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: test_gql_rdf_load.sql"
    exit 3
fi

# Run the ACID transaction equivalence tests (mirrors tsparql_acid.sql)
LOG "Running GQL ACID transaction equivalence tests"
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_BUILD/binsrc/gql/test_gql_rdf_acid.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: test_gql_rdf_acid.sql"
    exit 3
fi

SHUTDOWN_SERVER
BANNER "COMPLETED: $TEST_NAME TESTS"

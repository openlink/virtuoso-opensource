#!/bin/sh
#
#  $Id$
#
#  Database recovery tests
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2023 OpenLink Software
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

TEST_NAME="GraphQL/SPARQL"
LOGFILE=`basename -s .sh $0`.output
export LOGFILE
export CASE_MODE=2
. $VIRTUOSO_TEST/testlib.sh

if [ ! -f "$VIRTUOSO_BUILD/binsrc/graphql/.libs//graphql.so" ]
then
    BANNER "*** SKIPPED: $TEST_NAME TESTS"
    exit 1
else
    cp "$VIRTUOSO_BUILD/binsrc/graphql/.libs/graphql.so" .
fi

BANNER "STARTED: $TEST_NAME TESTS"

NOLITE

rm -f $DBLOGFILE
rm -f $DBFILE
MAKECFG_FILE_WITH_HTTP $TESTCFGFILE $PORT $HTTPPORT $CFGFILE
cat $CFGFILE | sed 's/;Load7/Load7/g' > tmp.ini
mv -f tmp.ini $CFGFILE

cp -R $VIRTUOSO_BUILD/binsrc/graphql/examples ./examples
cp -R $VIRTUOSO_BUILD/binsrc/graphql/introspection ./introspection
cp $VIRTUOSO_TEST/nwgschema.ttl .
cp $VIRTUOSO_TEST/tgql_intro.ql .

SHUTDOWN_SERVER
START_SERVER $PORT 1000

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u XENC=$XENCRYPT < $VIRTUOSO_TEST/nwdemo.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: nwdemo.sql: loading northwind data"
    exit 3
fi

LOG "Runing definition of NW demo quad mappings"
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u XENC=$XENCRYPT < $VIRTUOSO_TEST/nwgqmap.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: nwdemo.sql: loading northwind data"
    exit 3
fi

LOG "loading country iso codes example"
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u XENC=$XENCRYPT < $VIRTUOSO_BUILD/binsrc/graphql/examples/cciso.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: cciso.sql"
    exit 3
fi

LOG "loading introspection schemas"
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u XENC=$XENCRYPT < $VIRTUOSO_BUILD/binsrc/graphql/introspection/graphql-intro.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: graphql-intro.sql"
    exit 3
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tgraphql.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: tgraphql.sql: GraphQL/SPARQL bridge functions "
    exit 3
fi

SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED $TEST_NAME TESTS (`basename $0`)"

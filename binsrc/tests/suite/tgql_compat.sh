#!/bin/sh
#
#  $Id$
#
#  GQL for Virtuoso - what the GQL build must leave alone
#
#  GQL is compiled into the server, and it touches shared code: the SQL
#  scanner and grammar, the SPARQL endpoint, the procedure namespace.  This
#  driver checks that SQL, SPARQL and the other bundled features behave as
#  they do without GQL.  Section K checks the source; the others run on a
#  server.
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

TEST_NAME="GQL Compatibility"
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

SRCTOP=${TOP-$VIRTUOSO_TEST/../../..}

# ----------------------------------------------------------------------
# K: source checks
# ----------------------------------------------------------------------

# K1: a keyword token's value is a mempool box, as for every other token
# (upstream "Fixed tokens from scanner should be MP box").  A static C
# string where the grammar expects a box is read as one by any code that
# takes its box length or tag.
SCN3=$SRCTOP/libsrc/Wi/scn3.l
if test ! -f "$SCN3"
then
    LOG "***FAILED: K1 libsrc/Wi/scn3.l not found under $SRCTOP"
elif test "`grep -c 'yylval->strval = t_sym_string (k->kwd);' $SCN3`" = 1 \
    -a "`grep -c 'yylval->strval = k->kwd;' $SCN3`" = 0
then
    LOG "PASSED: K1 the scanner boxes a keyword token's value"
else
    LOG "***FAILED: K1 the scanner returns a keyword token's value as a C string (k->kwd)"
fi

# K2: the suite harness stops only the servers the tests started (from
# their virtuoso.lck), never a process it finds listening on the test
# port: the port defaults to 1111, where a developer's own server listens.
TESTLIB=$VIRTUOSO_TEST/testlib.sh
if test ! -f "$TESTLIB"
then
    LOG "***FAILED: K2 testlib.sh not found under $VIRTUOSO_TEST"
elif grep -E 'sTCP:LISTEN|KILL_VIRTUOSO_LISTENERS' "$TESTLIB" >/dev/null
then
    LOG "***FAILED: K2 the suite harness kills Virtuoso processes by the port they listen on"
else
    LOG "PASSED: K2 the suite harness stops only the servers the tests started"
fi

# N1: the procedures the GQL bootstrap defines and the ones the GraphQL
# plugin defines are disjoint.  Both live in DB.DBA (GraphQL's are
# unqualified, created as DBA); a shared name is one definition replacing
# the other at every start -- a 2-argument DB.DBA.GQL_EXEC made every
# GraphQL request fail with SR180.
GQLSRC=`ls $SRCTOP/libsrc/Wi/gql_*.sql 2>/dev/null`
GRAPHQLSRC=$SRCTOP/binsrc/graphql/graphql.sql
if test -z "$GQLSRC" -o ! -f "$GRAPHQLSRC"
then
    LOG "***FAILED: N1 libsrc/Wi/gql_*.sql or binsrc/graphql/graphql.sql not found under $SRCTOP"
else
    _procnames()
    {
        cat "$@" | tr '\n' ' ' | grep -o -i -E 'create (procedure|function) +[A-Za-z_."]+' \
          | awk '{print toupper($3)}' | sed -e 's/"//g' -e 's/^DB\.DBA\.//' | sort -u
    }
    _procnames $GQLSRC > gql_procs.txt
    _procnames $GRAPHQLSRC > graphql_procs.txt
    _shared=`comm -12 gql_procs.txt graphql_procs.txt | tr '\n' ' '`
    if test ! -s gql_procs.txt -o ! -s graphql_procs.txt
    then
        LOG "***FAILED: N1 no procedure names read from the GQL or GraphQL sources"
    elif test -z "$_shared"
    then
        LOG "PASSED: N1 GQL and GraphQL define no procedure of the same name (`wc -l < gql_procs.txt | tr -d ' '` and `wc -l < graphql_procs.txt | tr -d ' '` names)"
    else
        LOG "***FAILED: N1 GQL and GraphQL both define DB.DBA.$_shared"
    fi
fi

# ----------------------------------------------------------------------
# The server sections
# ----------------------------------------------------------------------

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

[URIQA]
DynamicLocal = 1
DefaultHost = localhost:$HTTPPORT
END_HTTP_COMPAT

SHUTDOWN_SERVER
START_SERVER $PORT 1000

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tgql_compat.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tgql_compat.sql"
fi

SHUTDOWN_SERVER
BANNER "COMPLETED: $TEST_NAME TESTS"

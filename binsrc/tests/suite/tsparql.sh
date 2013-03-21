#!/bin/sh
#
#  $Id$
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

LOGFILE=tsparql.output
export LOGFILE
. ./test_fn.sh

DSN=$PORT
HTTPPORT1=`expr $HTTPPORT + 1`
HTTPPORT2=`expr $HTTPPORT + 2`

BANNER "STARTED SPARQL TESTS"
NOLITE

curl -V | grep curl
if test $? -ne 0
then 
   LOG "curl not available, skipping this test"
   exit 1
fi

STOP_SERVER
rm -f $DELETEMASK
MAKECFG_FILE_WITH_HTTP $TESTCFGFILE $PORT $HTTPPORT $CFGFILE
START_SERVER $DSN 1000
sleep 5

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT" -u "HTTPPORT1=$HTTPPORT1" < tsparql.sql
if test $STATUS -ne 0
then
   LOG "***ABORTED: tsparql.sql"
   exit 1
fi





lcount=` ( curl --form-string 'format=application/sparql-results+json' --form-string 'query=select distinct (bif:sprintf ("%{WSHostPort}U")) as ?f1, (bif:aref (bif:sprintf_inverse (bif:sprintf ("%{WSHostName}U:%{WSHostPort}U%s","/DAV/sample"), "%{WSHostName}U:%{WSHostPort}U%s", 0), 0)) as ?f2 WHERE {?s a ?o}' localhost:${HTTPPORT}/sparql/ 2>/dev/null ; echo '' ) | grep "${HTTPPORT}.*/DAV/sample" | wc -l `
echo lcount=$lcount
if test 1 -eq $lcount
then
  LOG 'PASSED: SPARQL query with connection variables in bif:sprintf'
else
  LOG '***FAILED: SPARQL query with connection variables in bif:sprintf'
fi

lcount=` ( curl --form-string 'format=application/sparql-results+json' --form-string 'query=define input:storage virtrdf:sys select ?s ?p ?o (isliteral(?o)) as ?o_is_lit from <http://example.com/sys> where { ?s ?p ?o ; <http://rdfs.org/sioc/ns#login> "dba" } order by ?s ?p ?o' localhost:${HTTPPORT}/sparql/ 2>/dev/null ; echo '' ) | grep "localhost:${HTTPPORT}/sys/user?id=0" | wc -l `
if test 7 -eq $lcount
then
  LOG "PASSED: Mappings about localhost:${HTTPPORT}/sys/user?id=0 are visible at localhost:${HTTPPORT}/sparql/"
else
  LOG "***FAILED: $lcount Mappings about localhost:${HTTPPORT}/sys/user?id=0 are visible at localhost:${HTTPPORT}/sparql/"
fi

lcount=` ( curl --form-string 'format=application/sparql-results+json' --form-string 'query=define input:storage virtrdf:sys select ?s ?p ?o (isliteral(?o)) as ?o_is_lit from <http://example.com/sys> where { ?s ?p ?o ; <http://rdfs.org/sioc/ns#login> "dba" } order by ?s ?p ?o' localhost:${HTTPPORT1}/sparql/ 2>/dev/null ; echo '' ) | grep "localhost:${HTTPPORT1}/sys/user?id=0" | wc -l `
if test 7 -eq $lcount
then
  LOG "PASSED: Mappings about localhost:${HTTPPORT1}/sys/user?id=0 are visible at localhost:${HTTPPORT1}/sparql/"
else
  LOG "***FAILED: $lcount Mappings about localhost:${HTTPPORT1}/sys/user?id=0 are visible at localhost:${HTTPPORT1}/sparql/"
fi

lcount=` ( curl --form-string 'format=application/sparql-results+json' --form-string 'query=define input:storage virtrdf:sys select ?s ?p ?o (isliteral(?o)) as ?o_is_lit from <http://example.com/sys> where { ?s ?p ?o ; <http://rdfs.org/sioc/ns#login> "dba" } order by ?s ?p ?o' localhost:${HTTPPORT1}/sparql/ 2>/dev/null ; echo '' ) | grep "localhost:${HTTPPORT}/sys/user?id=0" | wc -l `
if test 0 -eq $lcount
then
  LOG "PASSED: Mappings about localhost:${HTTPPORT}/sys/user?id=0 are not visible at localhost:${HTTPPORT1}/sparql/"
else
  LOG "***FAILED: $lcount Mappings about localhost:${HTTPPORT}/sys/user?id=0 are not visible at localhost:${HTTPPORT1}/sparql/"
fi

lcount=` ( curl --form-string 'format=application/sparql-results+json' --form-string 'query=define input:storage virtrdf:sys select ?s ?p ?o (isliteral(?o)) as ?o_is_lit from <http://example.com/sys> where { ?s ?p ?o ; <http://rdfs.org/sioc/ns#login> "dba" } order by ?s ?p ?o' localhost:${HTTPPORT}/sparql/ 2>/dev/null ; echo '' ) | grep "localhost:${HTTPPORT1}/sys/user?id=0" | wc -l `
if test 0 -eq $lcount
then
  LOG "PASSED: Mappings about localhost:${HTTPPORT1}/sys/user?id=0 are not visible at localhost:${HTTPPORT}/sparql/"
else
  LOG "***FAILED: $lcount Mappings about localhost:${HTTPPORT1}/sys/user?id=0 are not visible at localhost:${HTTPPORT}/sparql/"
fi

SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED SPARQL TESTS"

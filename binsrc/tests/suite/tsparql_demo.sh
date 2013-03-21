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

LOGFILE=tsparql_demo.output
export LOGFILE
CASE_MODE=2
export CASE_MODE
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
rm -f $DBLOGFILE
rm -f $DBFILE
MAKECFG_FILE_WITH_HTTP $TESTCFGFILE $PORT $HTTPPORT $CFGFILE
START_SERVER $DSN 1000
sleep 5

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < nwdemo.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tsparql_demo.sh: nwdemo.sql"
    exit 3
else
    LOG "DONE: tsparql_demo.sh: nwdemo.sql"
fi

$ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $HOME/binsrc/samples/demo/countries.sql > /dev/null 2>&1

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $HOME/binsrc/samples/demo/nwdynamic.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tsparql_demo.sh: nwdynamic.sql RDF View"
    exit 3
else
    LOG "DONE: tsparql_demo.sh: nwdynamic.sql RDF View"
fi

lcount=` ( curl --form-string 'format=text/rdf+n3' --form-string 'query=select distinct ?t ?g where { graph ?g { ?s a ?t } . filter (bif:strstr(str(?g), "Northwind"))}' localhost:${HTTPPORT}/sparql/ 2>/dev/null ) | grep "variable .t" | wc -l `
if test 16 -eq $lcount
then
  LOG "PASSED: $lcount types in Northwind graph"
else
  LOG "***FAILED: $lcount types in Northwind graph, should be 16"
fi

wget --header "Accept: text/rdf+n3" --output-document tsparql_demo_wget1.log "http://localhost:$HTTPPORT/Northwind/Customer/ALFKI#this"
lcount=` cat tsparql_demo_wget1.log | grep 'Alfreds Futterkiste' | wc -l`
if test 2 -eq $lcount
then
  LOG "PASSED: ALFKI is about Alfreds Futterkiste in TTL"
else
  LOG "***FAILED: ALFKI is about Alfreds Futterkiste in TTL"
fi

wget --header "Accept: application/rdf+xml" --output-document tsparql_demo_wget2.log "http://localhost:$HTTPPORT/Northwind/Customer/ALFKI#this"
lcount=` cat tsparql_demo_wget2.log | grep 'Maria Anders' | wc -l`
if test 1 -eq $lcount
then
  LOG "PASSED: ALFKI is represented by Maria Anders"
else
  LOG "***FAILED: ALFKI is represented by Maria Anders"
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $HOME/binsrc/samples/demo/tpc-h/tpch.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tsparql_demo.sh: tpch data and RDF View"
    exit 3
else
    LOG "DONE: tsparql_demo.sh: tpch data and RDF View"
fi

lcount=` ( curl --form-string 'format=text/rdf+n3' --form-string 'query=select distinct ?t ?g where { graph ?g { ?s a ?t } . filter (bif:strstr(str(?g), "tpch"))}' localhost:${HTTPPORT}/sparql/ 2>/dev/null ) | grep "variable .t" | wc -l `
if test 9 -eq $lcount
then
  LOG "PASSED: $lcount types in TPC-H graph"
else
  LOG "***FAILED: $lcount types in TPC-H, should be 9"
fi

wget --header "Accept: text/rdf+n3" --output-document tsparql_demo_wget11.log "http://localhost:$HTTPPORT/tpch/customer/1#this"
lcount=` cat tsparql_demo_wget11.log | grep '18-252-186-6265' | wc -l`
if test 2 -eq $lcount
then
  LOG "PASSED: Phone of customer 1 is 18-252-186-6265 in TTL"
else
  LOG "***FAILED: Phone of customer 1 is 18-252-186-6265 in TTL"
fi

wget --header "Accept: text/rdf+n3" --output-document tsparql_demo_wget12.log "http://localhost:$HTTPPORT/Northwind/Customer/ALFKI#this"
lcount=` cat tsparql_demo_wget12.log | grep 'Alfreds Futterkiste' | wc -l`
if test 2 -eq $lcount
then
  LOG "PASSED: ALFKI is still about Alfreds Futterkiste in TTL after loading second view"
else
  LOG "***FAILED: ALFKI is still about Alfreds Futterkiste in TTL after loading second view"
fi


SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED SPARQL TESTS"

#wget --header "Accept: text/rdf+n3" "http://localhost:8234/Northwind/Customer/ALFKI#this"

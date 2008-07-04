#!/bin/sh
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2006 OpenLink Software
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
LOGFILE=tsparql_demo.output
export LOGFILE
CASE_MODE=2
export CASE_MODE
. ./test_fn.sh

DSN=$PORT
HTTPPORT1=`expr $HTTPPORT + 1`
HTTPPORT2=`expr $HTTPPORT + 2`

BANNER "STARTED SPARQL TESTS"

curl -V | grep curl
if test $? -ne 0
then 
   LOG "curl not available, skipping this test"
   exit 1
fi

STOP_SERVER
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

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $HOME/binsrc/samples/demo/nwdynamic.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tsparql_demo.sh: nwdynamic.sql RDF View"
    exit 3
else
    LOG "DONE: tsparql_demo.sh: nwdynamic.sql RDF View"
fi

lcount=` ( curl --form-string 'format=text/rdf+n3' --form-string 'query=select distinct ?t ?g where { graph ?g { ?s a ?t } . filter (bif:strstr(str(?g), "Northwind"))}' localhost:${HTTPPORT}/sparql/ 2>/dev/null ) | grep "name \"t\" | wc -l `
if test 13 -eq $lcount
then
  LOG "PASSED: $lcount types in Northwind graph"
else
  LOG "***FAILED: $lcount types in Northwind graph, should be 13"
fi


SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED SPARQL TESTS"

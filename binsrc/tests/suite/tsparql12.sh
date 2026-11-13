#!/bin/sh
#
# SPARQL 1.2 manifest compiler/evaluation smoke tests.
#

LOGFILE=tsparql12.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

BANNER "STARTED SPARQL 1.2 MANIFEST TESTS (tsparql12.sh)"
STOP_SERVER
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
START_SERVER $PORT 1000

LOG + running sql script $VIRTUOSO_TEST/tsparql12.sql
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tsparql12.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tsparql12.sql"
    exit 3
fi

SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED SPARQL 1.2 MANIFEST TESTS (tsparql12.sh)"

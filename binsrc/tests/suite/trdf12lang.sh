#!/bin/sh
#
# RDF 1.2 language-tag compatibility tests.
#

LOGFILE=trdf12lang.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

BANNER "STARTED RDF 1.2 LANGUAGE-TAG TESTS (trdf12lang.sh)"
STOP_SERVER
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
START_SERVER $PORT 1000

LOG + running sql script $VIRTUOSO_TEST/trdf12lang.sql
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/trdf12lang.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: trdf12lang.sql"
    exit 3
fi

SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED RDF 1.2 LANGUAGE-TAG TESTS (trdf12lang.sh)"

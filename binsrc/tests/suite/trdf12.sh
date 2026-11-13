#!/bin/sh
#
# RDF 1.2 manifest parser smoke tests.
#

LOGFILE=trdf12.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

BANNER "STARTED RDF 1.2 MANIFEST TESTS (trdf12.sh)"

RDF_TESTS_REPO=https://github.com/w3c/rdf-tests
RDF_TESTS_REV=ff99189d24aeab411787f4fbf3036a0915eca744

if [ -z "${RDF_TESTS_ROOT:-}" ]
then
    RDF_TESTS_ROOT=$(pwd)/rdf-tests
    if [ -d "$RDF_TESTS_ROOT/.git" ]
    then
        LOG "+ using existing checkout of rdf-tests at $RDF_TESTS_ROOT"
    else
        RUN "git clone -q $RDF_TESTS_REPO '$RDF_TESTS_ROOT' && (cd '$RDF_TESTS_ROOT' && git checkout -q $RDF_TESTS_REV)"
        if test $STATUS -ne 0
        then
            rm -rf "$RDF_TESTS_ROOT"
            LOG "***ABORTED: could not get $RDF_TESTS_REPO at $RDF_TESTS_REV"
            exit 3
        fi
    fi
fi
export RDF_TESTS_ROOT

LOG "+ regenerating trdf12.sql/tsparql12.sql from $RDF_TESTS_ROOT"
RUN RDF_TESTS_ROOT=$RDF_TESTS_ROOT OUT_DIR=$VIRTUOSO_TEST $VIRTUOSO_TEST/generate-rdf12-tests.sh
if test $STATUS -ne 0
then
    LOG "***ABORTED: generate-rdf12-tests.sh"
    exit 3
fi

STOP_SERVER
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
START_SERVER $PORT 1000

LOG + running sql script $VIRTUOSO_TEST/trdf12.sql
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/trdf12.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: trdf12.sql"
    exit 3
fi

SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED RDF 1.2 MANIFEST TESTS (trdf12.sh)"

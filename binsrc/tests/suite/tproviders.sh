#!/bin/sh
#
#  $Id: tproviders.sh,v 1.4.2.2.4.3 2013/01/02 16:15:18 source Exp $
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2017 OpenLink Software
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

LOGFILE=`pwd`/tproviders.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh
 
CURRDIR=`pwd`
JENADIR="$TOP/binsrc/jena"
JENA2DIR="$TOP/binsrc/jena2"
JENA3DIR="$TOP/binsrc/jena3"
SESAME2DIR="$TOP/binsrc/sesame2"
SESAME3DIR="$TOP/binsrc/sesame3"
SESAME4DIR="$TOP/binsrc/sesame4"

BANNER "STARTED JENA & SESAME2 PROVIDERS TESTS (tproviders.sh)"

SHUTDOWN_SERVER

# INITIAL CHECKS
#if [ ! -x lib/arq.jar ]
#then
#  BANNER "No jars form JENA_CLASSPATH.  Exiting ..."
#  CHECK_LOG
#  BANNER "COMPLETED JENA & SESAME2 PROVIDERS TESTS (tproviders.sh)"
#  exit 0
#fi
# FIXME


rm -f $DELETEMASK

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

NIGHTLY_PORT=$PORT
export NIGHTLY_PORT

START_SERVER $PORT 1000 

#
#   Run Jena 2 tests
#
cd $JENA2DIR

RUN $MAKE
if test $STATUS -ne 0
then
    LOG "***FAILED: Jena 2 compile"
else
    LOG "PASSED: Jena 2 compile"
fi

RUN $MAKE run-tests
if test $STATUS -ne 0
then
    LOG "***FAILED: Jena 2 provider JUnit tests"
else
    LOG "PASSED: Jena 2 provider JUnit tests"
fi

cd $CURRDIR


#
#   Run Jena3 tests
#
cd $JENA3DIR

RUN $MAKE
if test $STATUS -ne 0
then
    LOG "***FAILED: Jena 3 compile"
else
    LOG "PASSED: Jena 3 compile"
fi

RUN $MAKE run-tests
if test $STATUS -ne 0
then
    LOG "***FAILED: Jena 3 provider JUnit tests"
else
    LOG "PASSED: Jena 3 provider JUnit tests"
fi

cd $CURRDIR




#
#   Run Sesame2 tests
#
cd $SESAME2DIR

RUN $MAKE
if test $STATUS -ne 0
then
    LOG "***FAILED: Sesame 2 compile"
else
    LOG "PASSED: Sesame 2 compile"
fi

RUN $MAKE run-tests
if test $STATUS -ne 0
then
    LOG "***FAILED: Sesame 2 suite"
else
    LOG "PASSED: Sesame 2 suite"
fi

cd $CURRDIR


#
#   Run Sesame4 tests
#
cd $SESAME4DIR

RUN $MAKE
if test $STATUS -ne 0
then
    LOG "***FAILED: Sesame 4 compile"
else
    LOG "PASSED: Sesame 4 compile"
fi

RUN $MAKE run-tests
if test $STATUS -ne 0
then
    LOG "***FAILED: Sesame 4 suite"
else
    LOG "PASSED: Sesameo 4 suite"
fi

cd $CURRDIR

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED JENA & SESAME PROVIDERS TESTS (tproviders.sh)"

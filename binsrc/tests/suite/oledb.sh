#!/bin/sh
#
#  $Id$
#
#  OLE DB tests
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2012 OpenLink Software
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

LOGFILE=oledb.output
export LOGFILE
. ./test_fn.sh

VIRTOLEDB_PATH=../virtoledb.dll
MOVENEXT=../movenext.exe

rm -f oledb.bad

CHECK_LOG()
{
    passed=`grep "PASSED:" $LOGFILE | wc -l`
    failed=`grep "\*\*\*.*FAILED:" $LOGFILE | wc -l`
    aborted=`grep "\*\*\*.*ABORTED:" $LOGFILE | wc -l`

    ECHO ""
    LINE
    ECHO "=  Checking log file $LOGFILE for statistics:"
    ECHO "="
    ECHO "=  Total number of tests PASSED  : $passed"
    ECHO "=  Total number of tests FAILED  : $failed"
    ECHO "=  Total number of tests ABORTED : $aborted"
    LINE
    ECHO ""

    if (expr $failed + $aborted \> 0 > /dev/null)
    then
       ECHO "*** Not all tests completed successfully"
       ECHO "*** Check the file $LOGFILE for more information"
       cp $LOGFILE oledb.bad 
    fi
}


REGISTER_PROVIDER()
{
    if [ "x$HOST_OS" != "x" ]; then
    	regsvr32.exe -s $VIRTOLEDB_PATH
    fi
}

UNREGISTER_PROVIDER()
{
    if [ "x$HOST_OS" != "x" ]; then
    	regsvr32.exe -u -s $VIRTOLEDB_PATH
    fi
}

# This functions runs a VB program that has to output its results into vbtest.output file.
# The results file has to contain the usual "PASSED" or "***FAILED"
RUN_VB()
{
    echo "+ $*"		>> $LOGFILE

    # create empty output file
    echo >vbtest.output

    eval $*
    STATUS=$?

    if [ $SILENT -eq 1 ]; then
	cat vbtest.output >> $LOGFILE
    else
	cat vbtest.output | tee -a $LOGFILE
    fi
    rm -f vbtest.output
}


BANNER "STARTED OLE DB TEST (oledb.sh)"

if [ "x$HOST_OS" = "x" ]; then
    LOG "SKIPPED: The test is Windows specific"
    CHECK_LOG
    BANNER "COMPLETED OLEDB TEST (oledb.sh)"
    exit 0
fi

if [ ! -x $MOVENEXT ]; then
    LOG "No $MOVENEXT executable compiled. Exiting"
    CHECK_LOG
    BANNER "COMPLETED OLEDB TEST (oledb.sh)"
    exit 0
fi

SHUTDOWN_SERVER

rm -f $DELETEMASK
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

#REGISTER_PROVIDER

START_SERVER $PORT 1000

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < nwdemo.sql
if [ $STATUS -ne 0 ]; then
    LOG "***ABORTED: oledb.sh: loading northwind data"
    exit 3
fi

RUN_VB $MOVENEXT
if [ $STATUS -ne 0 ]; then
    LOG "***ABORTED: oledb.sh: $MOVENEXT"
    exit 1
fi

SHUTDOWN_SERVER
#UNREGISTER_PROVIDER
CHECK_LOG
BANNER "COMPLETED OLE DB TESTS (oledb.sh)"

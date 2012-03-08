#!/bin/sh
#
#  $Id$
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

CLIENT=$2
if [ x$CLIENT = x ] ; then
    CLIENT=Virtuoso.dll
fi

RUNTIME=$3
if [ x$RUNTIME = x ] ; then
    RUNTIME=MS
fi

LOGFILE="`pwd`/dotnet.output"
export LOGFILE
. ../suite/test_fn.sh
BANNER "STARTED $CLIENT .NET CLIENT TEST"

DS1=$PORT
HTTPPORT1=$HTTPPORT

case $RUNTIME in
    MS)
	MAKEFILE=Makefile
	RUNT=../harness/ConsoleTestRunner.exe
	;;
    MSDTC)
	MAKEFILE=Makefile
	RUNT=../harness/ConsoleTestRunner.exe
        DTC_TEST=/DTC_TEST+
	;;
    MONO)
	MAKEFILE=Makefile.mono
	RUNT="mono ../harness/ConsoleTestRunner.exe"
	;;
    *)
	echo "***FAILED: Unknown runtime. Exiting" | tee -a $LOGFILE
	exit 3;
	;;
esac

cd harness
make -f $MAKEFILE clean
make -f $MAKEFILE
cd ..

cd VirtuosoClientSuite
make -f $MAKEFILE clean
make -f $MAKEFILE
cd ..

# Make INI 
MAKE_CFG ()
{
  file=$1
  port=$2
  httpport=$3
  cat $file | sed -e "s/HTTPPORT/$httpport/g" -e "s/PORT/$port/g" -e "s/SQLOPTIMIZE/$SQLOPTIMIZE/g" -e "s/PLDBG/$PLDBG/g" -e "s/CASE_MODE/$CASE_MODE/g" > $CFGFILE
}

# decide witch server options set to use based on the server's name
SERVER=$1
case $SERVER in

  *virtuoso*)
	  echo Using virtuoso configuration | tee -a $LOGFILE
	  CFGFILE=virtuoso.ini
	  DBFILE=virtuoso.db
	  DBLOGFILE=virtuoso.trx
	  DELETEMASK="virtuoso.log virtuoso.lck $DBLOGFILE $DBFILE"
	  TESTCFGFILE=virtuoso-1111.ini
	  TESTCFGFILEDS1=virtuoso-1111.ini
	  TESTCFGFILEDS2=virtuoso-1112.ini
	  BACKUP_DUMP_OPTION=+backup-dump
	  CRASH_DUMP_OPTION=+crash-dump


# only in that case
	  FOREGROUND_OPTION=+foreground
	  LOCKFILE=virtuoso.lck
	  export FOREGROUND_OPTION LOCKFILE
	  ;;
  *[Mm]2*)
	  echo Using M2 configuration | tee -a $LOGFILE
	  CFGFILE=wi.cfg
	  DBFILE=wi.db
	  DBLOGFILE=wi.log
	  DELETEMASK="wi.*"
	  TESTCFGFILE=witest.cfg
	  TESTCFGFILEDS1=witest.cfg
	  TESTCFGFILEDS2=witest.cfg
	  BACKUP_DUMP_OPTION=-d
	  CRASH_DUMP_OPTION=-D
	  unset FOREGROUND_OPTION
	  unset LOCKFILE
	  ;;

   *)
	  echo "***FAILED: Unknown server. Exiting" | tee -a $LOGFILE
	  exit 3;
	  ;;
esac

case $CLIENT in
    VirtuosoOdbcClient.dll)
	TEST_SUITE=VirtuosoOdbcClientSuite.dll
	TEST_DTC_SUITE=VirtuosoDtcOdbcClientSuite.dll
	;;
    VirtuosoClient.dll)
	TEST_SUITE=VirtuosoClientSuite.dll
	TEST_DTC_SUITE=VirtuosoDtcClientSuite.dll
	;;
    Virtuoso.dll)
	TEST_SUITE=VirtuosoSuite.dll
	TEST_DTC_SUITE=VirtuosoDtcSuite.dll
	;;
    *)
	echo "***FAILED: Unknown client. Exiting" | tee -a $LOGFILE
	exit 3;
	;;
esac

export CFGFILE DBFILE DBLOGFILE DELETEMASK TESTCFGFILEDS1 TESTCFGFILEDS2
export BACKUP_DUMP_OPTION CRASH_DUMP_OPTION TESTCFGFILE SERVER

# Start the server
rm -f $DELETEMASK
MAKE_CFG ../suite/$TESTCFGFILE $DS1 $HTTPPORT1

if [ -f VirtuosoClientSuite/OpenLink.Data.$CLIENT ] ; then

START_SERVER $PORT 10000

cd VirtuosoClientSuite
if [ "x$DTC_TEST" != "x" ]
then
  $RUNT /host:localhost:$PORT $DTC_TEST $TEST_DTC_SUITE 2>&1| tee -a $LOGFILE
else
  $RUNT /host:localhost:$PORT $TEST_SUITE 2>&1| tee -a $LOGFILE
fi
cd ..

# Stop The server
SHUTDOWN_SERVER

# Check results
CHECK_LOG
BANNER "COMPLETED $CLIENT .NET CLIENT TEST"

else

BANNER "SKIPPED $CLIENT .NET CLIENT TEST"

fi

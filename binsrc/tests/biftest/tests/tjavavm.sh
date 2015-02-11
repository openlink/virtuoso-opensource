#!/bin/sh
#
#  $Id$
#
#  Database recovery tests
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2015 OpenLink Software
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

LOGFILE=tjavavm.output
export LOGFILE

HOST_OS=`uname -s | grep WIN`
if [ "x$HOST_OS" = "x" ]
then
SRV=../virtuoso-iodbc-javavm-t
else
SRV=virtuoso-odbc-clr-php-javavm-t.exe
fi

SERVER=${SERVER-$SRV}

echo "Using $SERVER"
case $SERVER in

  *java*)
	  echo Using java configuration | tee -a $LOGFILE
	  CFGFILE=virtuoso.ini
	  DBFILE=virtuoso.db
	  DBLOGFILE=virtuoso.trx
	  DELETEMASK="virtuoso.log virtuoso.lck $DBLOGFILE $DBFILE virtuoso.tdb virtuoso.ttr"
	  TESTCFGFILE=virtuoso-1111.ini
          #TESTCFGFILEDS1=virtuoso-1111.ini
          #TESTCFGFILEDS2=virtuoso-1112.ini
	  BACKUP_DUMP_OPTION=+backup-dump
	  CRASH_DUMP_OPTION=+crash-dump

# only in that case
	  FOREGROUND_OPTION=+foreground
	  LOCKFILE=virtuoso.lck
	  export FOREGROUND_OPTION LOCKFILE
	  ;;

   *)
	  echo "***FAILED: Unknown server. Exiting" | tee -a $LOGFILE
	  exit 3;
	  ;;
esac

export CFGFILE DBFILE DBLOGFILE DELETEMASK #TESTCFGFILEDS1 TESTCFGFILEDS2
export BACKUP_DUMP_OPTION CRASH_DUMP_OPTION TESTCFGFILE SERVER


. ../../suite/test_fn.sh

BANNER "STARTED JAVAVM TEST (tjavavm.sh)"


if [ "x" != "x$JDK2" ]
then
INTEG_JDK=$JDK2
fi
if [ "x" != "x$JDK3" ]
then
INTEG_JDK=$JDK3
fi

JAVAC=$INTEG_JDK/bin/javac
host_os=`uname -s`
if [ "x$host_os" = "xDarwin" ]
then
JAVAC=$INTEG_JDK/Commands/javac
fi


rm -f *.class
$JAVAC *.java

#if [ "x$HOST_OS" = "x" ]
#then
#  export CLASSPATH=`pwd`
#  export LD_LIBRARY_PATH=$INTEG_JDK/jre/lib/i386:$INTEG_JDK/jre/lib/i386/client:$LD_LIBRARY_PATH
#fi
rm -f $DBLOGFILE
rm -f $DBFILE
MAKECFG_FILE ../../suite/$TESTCFGFILE $PORT $CFGFILE

SHUTDOWN_SERVER
START_SERVER $PORT 1000

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < java_ts.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: java_ts.sql: JAVA ts init "
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < java_ts2.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: java_ts2.sql: JAVA ts "
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < java_ts3.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: java_ts3.sql: JAVA Restriction test "
    exit 3
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < test_tax_java.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: java_ts2.sql: JAVA samples "
    exit 3
fi


SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED JAVAVM TEST (tjavavm.sh)"

#!/bin/sh
#
#  $Id$
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

OUTPUT=thook.output
ISQL=../isql
TIMEOUT=1000
HOST_OS=`uname -s | grep WIN`
SERVER=./virtuoso-iodbc-sample-t
PORT=${PORT-1111}
HOST=${HOST-localhost}
DSN=$HOST:$PORT
HTTPPORT=`expr $PORT + 10`
SQLOPTIMIZE=${SQLOPTIMIZE-0}
LOCKFILE=virtuoso.lck
#DSN=1111

cat virtuoso-sample.ini | sed -e "s/PORT/$PORT/g" -e "s/SQLOPTIMIZE/$SQLOPTIMIZE/g" -e "s/HTTP_LISTEN/$HTTPPORT/g" > virtuoso.ini
rm -f thook.bad
rm -f $OUTPUT
rm -f virtuoso.db
rm -f virtuoso.trx
rm -f virtuoso.log
rm -f virtuoso.lck

export LD_LIBRARY_PATH
if [ "x$HOST_OS" != "x" ]
then
  SERVER=../virtuoso-odbc-sample-t.exe
fi

ECHO()
{
    echo "$*"           | tee -a $OUTPUT
}

LOG ()
{
  echo $* >> $OUTPUT
  echo $*
}

RUN ()
{
  echo >> $OUTPUT
  echo "+ " $* >> $OUTPUT
  $* >> $OUTPUT
  if test $? -ne 0
  then
    LOG "***ABORTED: thook.sh: " $*
    exit 1
  fi
}

LINE()
{
    ECHO "====================================================================="
}

CHECK_LOG()
{
    passed=`grep "PASSED:" $OUTPUT | wc -l`
    failed=`grep "\*\*\*.*FAILED:" $OUTPUT | wc -l`
    aborted=`grep "\*\*\*.*ABORTED:" $OUTPUT | wc -l`

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
       cp $OUTPUT thook.bad
    fi
}


START_SERVER()
{
    if test "$HOST" != "localhost"
    then
	return
    fi
    port=$1
    timeout=$2

    if test $# -lt 2
    then
	LOG "***FAILED: START_SERVER Missing parameters"
	LOG "Usage: START_SERVER: port timeout"
	exit 1
    fi

    shift
    shift

    stat="true"
    while [ "z$stat" != "z" ]
    do
	sleep 5
	stat=`netstat -an | grep "[\.\:]$port " | grep LISTEN`
    done

	ddate=`date`
	starth=`date | cut -f 2 -d :`
	starts=`date | cut -f 3 -d :|cut -f 1 -d " "`
	if test -f "$LOCKFILE"
	  then
	      echo Removing $LOCKFILE >> $LOGFILE
	      rm $LOCKFILE
          fi
	RUN $SERVER +foreground $* &
	while true
	do
            sleep 5
	    stat=`netstat -an | grep "[\.\:]$port " | grep LISTEN`
	    if [ "z$stat" != "z" ]
	    then
		LOG "PASSED: Virtuoso Server successfully started on port $port"
		return 0
	    fi
	    nowh=`date | cut -f 2 -d :`
	    nows=`date | cut -f 3 -d : | cut -f 1 -d " "`

	    nowh=`expr $nowh - $starth`
	    nows=`expr $nows - $starts`

	    nows=`expr $nows + $nowh \*  60`
	    if test $nows -ge $timeout
	    then
		LOG "***FAILED: Could not start Virtuoso Server within $timeout seconds"
		exit 1
	    fi
	done
}
echo "STARTED : thook.sh"
echo "STARTED : thook.sh" > $OUTPUT

if [ -x $SERVER ]
  then

echo
echo $ISQL $DSN dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT "EXEC=raw_exit()" >> $OUTPUT
$ISQL $DSN dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT "EXEC=raw_exit()" >> $OUTPUT
rm -rf virtuoso.db virtuoso.log virtuoso.lck virtuoso.trx core
START_SERVER $PORT 1000
RUN $ISQL $DSN dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT thook.sql

RUN $ISQL $DSN MANAGER MANAGER PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT thook1.sql
RUN $ISQL $DSN U U PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT thook1.sql
RUN $ISQL $DSN OUTSIDER OUTSIDER PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT thook1.sql
echo >> $OUTPUT
echo "+ " $ISQL $DSN NOGO NOGO PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT thook1.sql >> $OUTPUT
$ISQL $DSN NOGO NOGO PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT thook1.sql >> $OUTPUT
if test $? -eq 0
then
  LOG "***ABORTED: thook.sh: thook1.sql for NOGO"
  exit 1
else
  LOG "PASSED: thook.sh: denied thook1.sql for NOGO"
fi

echo
echo  $ISQL $DSN dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT thook2.sql >> $OUTPUT
$ISQL $DSN dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT thook2.sql >> $OUTPUT
 else
  LOG "No $SERVER executable compiled. Exiting"
 fi
LOG "FINISHED : thook.sh"

CHECK_LOG


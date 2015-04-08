#!/bin/sh
#
#  $Id$
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

LOGFILE=tpcd.output
export LOGFILE


if [ "$#" -gt 0 ]
  then
    echo "Begin"
else
    echo
    echo "      Usage:"
    echo "      tpcd.sh (load | run)"
    echo
   exit
fi

rm -f $LOGFILE

if [ z$1 = zload ]
then
  rm -f tpcd.db
  rm -f tpcd.trx
  rm -f tpcd.log
fi

rm -f tpcd.bad 
rm -f tpcd.lck
rm -f virtuoso.lck

SRV=./virtuoso-t
SRV=virtuoso-t
export SRV

HOST_OS=`uname -s | grep WIN`
SILENT=${SILENT-0}
ISQL=${ISQL-isql}
PORT=${PORT-1111}
HOST=${HOST-localhost}
HOST_OS=`uname -s | grep WIN`
DSN=$HOST:$PORT

if [ "x$HOST_OS" != "x" ] 
then
  SRV=../virtuoso-odbc-t.exe
fi

SERVER=$SRV
export SERVER

LOGIN="$PORT dba dba"

echo "
[Database]
DatabaseFile    = tpcd.db
TransactionFile = tpcd.trx
ErrorLogFile    = tpcd.log
ErrorLogLevel   = 7
FileExtend      = 200
Striping        = 0
LogSegments     = 0
Syslog		= 0

;
;  Server parameters
;
[Parameters]
ServerPort           = $PORT
ServerThreads        = 1000
CheckpointInterval   = 0
NumberOfBuffers      = 2000
MaxDirtyBuffers      = 1200
MaxCheckpointRemap   = 2000
UnremapQuota         = 0
AtomicDive           = 1
PrefixResultNames    = 0
CaseMode             = 2
DisableMtWrite       = 0
MaxStaticCursorRows  = 5000
AllowOSCalls         = 0
SQLOptimizer	     = 1

[Client]
SQL_QUERY_TIMEOUT  = 0
SQL_TXN_TIMEOUT    = 0
SQL_PREFETCH_ROWS  = 100
SQL_PREFETCH_BYTES = 16000

[AutoRepair]
BadParentLinks = 0
BadDTP         = 0

[Replication]
ServerName   = the_big_server
ServerEnable = 1
QueueMax     = 50000

" > tpcd.ini

LINE()
{
    ECHO "====================================================================="
}

ECHO()
{
    echo "$*"           | tee -a $LOGFILE
}

LOG ()
{
  echo $* >> $LOGFILE 
  echo $*
}

BANNER()
{
    ECHO ""
    LINE
    ECHO "=  $*"
    ECHO "= " `date`
    LINE
    ECHO ""
}

CHECK_LOG()
{
    passed=`grep "PASSED:" $LOGFILE | wc -l`
    failed=`grep "^\*\*\*.*FAILED:" $LOGFILE | wc -l`
    aborted=`grep "^\*\*\*.*ABORTED:" $LOGFILE | wc -l`

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
       cp $LOGFILE tpcd.bad
       #
       # UP LINE FOR TEST SUITE
       # 
    fi
}


RUN()
{
    echo "+ $*"         >> $LOGFILE

    STATUS=1
        if test $SILENT -eq 1
        then
            eval $*             >> $LOGFILE 2>>/dev/null
        else
            eval $*             >> $LOGFILE
        fi
    STATUS=$?
}


BANNER "STARTED TPC-D TEST - (tpcd.sh)"

#if [ ! -x $SRV ]
#then
#  LOG "No executable compiled. Exiting"
#  CHECK_LOG
#  BANNER "COMPLETED TPC-D TEST - (tpcd.sh)"
#  exit 0
#fi


START_SERVER ()
{
      LD_LIBRARY_PATH=`pwd`/lib:$LD_LIBRARY_PATH
      ddate=`date`
      starth=`date | cut -f 2 -d :`
      starts=`date | cut -f 3 -d :|cut -f 1 -d " "`
      rm -f *.lck
      $SERVER +foreground -c tpcd.ini $* 1>/dev/null & 
      stat="true"
      while true 
	do
	  sleep 4
	      stat=`netstat -an | grep "[\.\:]$PORT " | grep LISTEN` 
	      if [ "z$stat" != "z" ] 
		then 
		    sleep 7 
		    LOG "PASSED: Virtuoso Server successfully started on port $port"
		    return 0
	      fi
        done
}


RUN $ISQL $PORT dba dba '"EXEC=shutdown"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT

START_SERVER

curdir=`pwd`
cd "${srcdir}" || {
	LOG "***ABORTED: cannot change to source directory (${srcdir})"
	exit 1
}

if [ z$1 = zload ]
then
  ${srcdir}/LOAD.sh $PORT dba dba tables
  ${srcdir}/LOAD.sh $PORT dba dba indexes
  ${srcdir}/LOAD.sh $PORT dba dba procedures
  ${srcdir}/LOAD.sh $PORT dba dba load 1

  LOG "Begin load MS SQL Server Data"
  RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < all_ms.sql

  if test $STATUS -ne 0
  then
      LOG "***ABORTED: tpcd test -- all_ms.sql"
      exit 1
  fi
  LOG "PASSED: load MS SQL Server Data"

  RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < test_ms.sql 

  if test $STATUS -ne 0
  then
      LOG "***ABORTED: tpcd test -- test_ms.sql"
      exit 1
  fi

  RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < test_tbl.sql  

  if test $STATUS -ne 0
  then
      LOG "***ABORTED: tpcd test -- test_tbl.sql"
      exit 1
  fi
#
else

#
#  QUERY
#

  RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < load_query.sql  

  if test $STATUS -ne 0
  then
      LOG "***ABORTED: tpcd test -- load_query.sql"
      exit 1
  fi
  RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < sql_rdf.sql

  if test $STATUS -ne 0
  then
      LOG "***ABORTED: tpcd test -- sql_rdf.sql"
      exit 1
  fi
  RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < Q_sparql_map_cmp.sql

  if test $STATUS -ne 0
  then
      LOG "***ABORTED: tpcd test -- Q_sparql_map_cmp.sql"
      exit 1
  fi
fi

#
#  CLEAN UP
#

#rm -rf tpcd.ini
cd "${curdir}"

RUN $ISQL $PORT dba dba '"EXEC=shutdown"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
CHECK_LOG
BANNER "COMPLETED TPC-D TEST - (tpcd.sh)"

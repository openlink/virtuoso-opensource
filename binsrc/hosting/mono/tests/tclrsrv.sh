#!/bin/sh
#  
#  $Id$
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2013 OpenLink Software
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

LOGFILE=tclrsrv.output
export LOGFILE

PATH=".:../../../../mono/lib/1.0:../../../..//mono/bin:../../../tests/:$PATH"
export PATH

mcs -target:library sample.cs 
mcs -target:library tax.cs 
mcs -target:library Point.cs 
mcs -target:library Point_ho_s_10.cs

rm -f $LOGFILE
rm -f clrsrv.db
rm -f clrsrv.trx
rm -f clrsrv.log
rm -f tclr.ini
rm -f virtuoso.lck

HOST_OS=`uname -s | grep WIN`
CLRSRV=virtuoso-mono-cli-t
SERVER=../$CLRSRV

if [ $# -gt 0 ]
then
  CLRSRV=$1
  SERVER=$CLRSRV
fi

export CLRSRV
export SERVER

SILENT=${SILENT-0}
ISQL=${ISQL-isql}
INS=${INS-ins}
PORT=${PORT-1111}
HTTPPORT=`expr $PORT + 10`
HOST=${HOST-localhost}
DSN=$HOST:$PORT
HITS=${HITS-5}

LOGIN="$PORT dba dba"

echo "
[Database]
DatabaseFile    = clrsrv.db
TransactionFile = clrsrv.trx
ErrorLogFile    = clrsrv.log
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
ServerThreads        = 10
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
DirsAllowed          = .

;
; HTTP server parameters
;
; Timeout values are seconds
;

[HTTPServer]
ServerPort = $HTTPPORT 
ServerRoot = ../../../
ServerThreads = 5
MaxKeepAlives = 10
EnabledDavVSP = 1

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
" > tclr.ini

#append the Mono section only if Mono on Windows
APPEND_MONO_SECT=0
case $SERVER in
    *mono*)
    if [ "x$HOST_OS" = "x" ] 
    then
      	APPEND_MONO_SECT=0
    else	
      	APPEND_MONO_SECT=1
    fi
    ;;
esac

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


BANNER "STARTED CLR TEST - (tclrsrv.sh)"

if [ ! -x $SERVER ]
then
  LOG "No server executable [$SEREVER] compiled. Exiting"
  CHECK_LOG
  BANNER "COMPLETED CLR TEST (tclrsrv.sh)"
  exit 0
fi


START_SERVER ()
{
      LD_LIBRARY_PATH=`pwd`/lib:$LD_LIBRARY_PATH
      ddate=`date`
      starth=`date | cut -f 2 -d :`
      starts=`date | cut -f 3 -d :|cut -f 1 -d " "`
      timeout=600
      rm -f *.lck
      $SERVER +foreground -c tclr.ini $* 1>/dev/null & 
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

WAITALL ()
{
   clients=1
   while [ "$clients" -gt "0" ]
     do
       sleep 5
       clients=`ps -e | grep urlsimu | grep -v grep | wc -l`
     done 
}


RUN $ISQL $PORT dba dba '"EXEC=shutdown"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT

START_SERVER

RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < clr_suite_types.sql 
if test $STATUS -ne 0
then
    LOG "***ABORTED: clr test -- clr_suite_types.sql"
    exit 1
fi

RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < test_tax_clr.sql 
if test $STATUS -ne 0
then
    LOG "***ABORTED: clr test -- test_tax_clr.sql"
    exit 1
fi

RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < test_point_clr.sql 
if test $STATUS -ne 0
then
    LOG "***ABORTED: clr test -- test_point_clr.sql"
    exit 1
fi

RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < test_point_clr.sql 
if test $STATUS -ne 0
then
    LOG "***ABORTED: clr test -- test_point_clr.sql"
    exit 1
fi

RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < test_tax_clr.sql 
if test $STATUS -ne 0
then
    LOG "***ABORTED: clr test -- test_tax_clr.sql"
    exit 1
fi

ECHO "CREATE LIBRARY Test suite"

rm -rf temp_dll_stor
mkdir temp_dll_stor
cp Point_ho_s_10.dll temp_dll_stor

RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "WINUSER=$WINUSER" -u "WINPASS=$WINPASS" < clr_test2.sql 
if test $STATUS -ne 0
then
   LOG "***ABORTED: clr test -- clr_test2.sql"
exit 1
fi

#
#  CLEAN UP
#

rm -rf tmp*.dll temp_dll_stor
rm -rf bin 

RUN $ISQL $DSN dba dba '"EXEC=shutdown"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
CHECK_LOG
BANNER "COMPLETED CLR TEST (tclrsrv.sh)"

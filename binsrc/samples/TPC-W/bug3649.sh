#!/bin/sh
#
#  $Id$
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2009 OpenLink Software
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

LOGFILE=tpcw.output
export LOGFILE

SRV=./virtuoso-t
SRV=virtuoso-t
export SRV

if [ z$1 = zhelp ]
then
    echo 
    echo "	Usage:"
    echo "	tpcw.sh [http_port] [number_of_items] [number_of_ebs]"
    echo
    exit
fi

HOST_OS=`uname -s | grep WIN`
SILENT=${SILENT-0}
ISQL=${ISQL-isql}
PORT=${PORT-1111}
HOST=${HOST-localhost}
HOST_OS=`uname -s | grep WIN`
DSN=$HOST:$PORT
HTTP_SERVER=localhost

[ "$HTTP_PORT" != "" ] || HTTP_PORT=$1
[ "$HTTP_PORT" != "" ] || HTTP_PORT=9301

[ "$NUMBER_EBS" != "" ] || NUMBER_EBS=$3
[ "$NUMBER_EBS" != "" ] || NUMBER_EBS=3

[ "$NUMBER_ITEMS" != "" ] || NUMBER_ITEMS=$2
[ "$NUMBER_ITEMS" != "" ] || NUMBER_ITEMS=1000

if [ "x$HOST_OS" != "x" ] 
then
  SRV=../virtuoso-odbc-t.exe
fi

SERVER=$SRV
export SERVER

LOGIN="$PORT dba dba"
PATH1=`pwd`

echo "
[Database]
DatabaseFile    = tpcw.db
TransactionFile = tpcw.trx
ErrorLogFile    = tpcw.log
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
ServerThreads        = 20
CheckpointInterval   = 60
NumberOfBuffers      = 2000
MaxDirtyBuffers      = 1200
MaxCheckpointRemap   = 2000
UnremapQuota         = 0
AtomicDive           = 1
PrefixResultNames    = 0
CaseMode             = 2
DisableMtWrite       = 0
MaxStaticCursorRows  = 5000
AllowOSCalls         = 1
SQLOptimizer	     = 1
DirsAllowed	     = /

[HTTPServer]
ServerPort = $HTTP_PORT
ServerThread = 1
ServerRoot = .

[Client]
SQL_QUERY_TIMEOUT  = 0
SQL_TXN_TIMEOUT    = 0
SQL_PREFETCH_ROWS  = 100
SQL_PREFETCH_BYTES = 16000
SQL_NO_CHAR_C_ESCAPE = 0

[AutoRepair]
BadParentLinks = 0
BadDTP         = 0

[Replication]
ServerName   = the_big_server
ServerEnable = 1
QueueMax     = 50000

" > tpcw.ini

echo "
load tpcwdrop.sql;

load tpcwddk.sql;
load tpcw.sql;

DB.DBA.VHOST_REMOVE(lpath=>'/tpcw');
DB.DBA.VHOST_DEFINE(lpath=>'/tpcw', ppath=>'/', vsp_user=>'DBA');

create procedure get_path() returns varchar
{
    declare path varchar;
    path := '$PATH1/';
    return path;
}

create procedure init_shop()
{
    declare NUM_ITEMS numeric(10);
    declare NUM_EBs integer;
    
    declare LOG_LINE varchar;
    result_names (LOG_LINE);
    NUM_ITEMS:=$NUMBER_ITEMS;
    NUM_EBs:=$NUMBER_EBS;
    ini_base(NUM_ITEMS, NUM_EBs);
}

init_shop();

ECHO BOTH \$IF \$EQU \$STATE OK  \"PASSED\" \"***FAILED\";
ECHO BOTH \": TPC-W http server database is populated: STATE=\" \$STATE \" MESSAGE=\" \$MESSAGE \"\n\";

" > setup.isql

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
    ECHO "=  http port:$HTTP_PORT, items:$NUMBER_ITEMS, emulated browsers:$NUMBER_EBS" 
    LINE
    ECHO ""
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

LOAD_CLIENTS()
{
    n=1    
    while true
	sleep 1
	do	
	    . ./tpcw_eb.sh run $n &
	    n=`expr $n + 1`
	    if [ $n = $NUMBER_EBS ]
		then
		    return
	    fi
	done
}

START_SERVER ()
{
      LD_LIBRARY_PATH=`pwd`/lib:$LD_LIBRARY_PATH
      ddate=`date`
      starth=`date | cut -f 2 -d :`
      starts=`date | cut -f 3 -d :|cut -f 1 -d " "`
      rm -f *.lck
      $SERVER -c tpcw.ini $* 1>/dev/null
      stat="true"
      while true 
	do
	  sleep 4
	      stat=`netstat -an | grep "[\.\:]$PORT " | grep LISTEN` 
	      if [ "z$stat" != "z" ] 
		then 
		    sleep 7 
		    LOG "PASSED: Virtuoso Server successfully started on port $PORT"
		    return 0
	      fi
        done
}

BANNER "STARTED TPC-W TEST"

RUN $ISQL $PORT dba dba '"EXEC=shutdown"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT

rm -f $LOGFILE
rm -f tpcw.db
rm -f tpcw.trx
rm -f tpcw.log
rm -f tpcw.bad 
rm -f tpcw.lck
mkdir ./html >> $LOGFILE
mkdir ./html/imagegen >> $LOGFILE

( cd WGEN >> $LOGFILE ; gmake all >> $LOGFILE ; cd .. >> $LOGFILE ; cp WGEN/tpcw . )
[ -x ./tpcw ] && LOG 'PASSED: TPCW random word generator is compiled' || LOG '***FAILED: TPCW random word generator is not compiled'
( cd IMAGEGEN/ImgFiles >> $LOGFILE ; gmake all >> $LOGFILE ; cd ../.. >> $LOGFILE ; cp IMAGEGEN/ImgFiles/tpcwIMG . )
[ -x ./tpcwIMG ] && LOG 'PASSED: TPCW random image generator is compiled' || LOG '***FAILED: TPCW random image generator is not compiled'

START_SERVER
. ./LOAD.sh
BANNER "LOAD TPCW-W COMPLETE"

#!/bin/sh
#
#  $Id$
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2016 OpenLink Software
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

# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL



LOGFILE=`pwd`
LOGFILE="${LOGFILE}/vspx_test_suite.output"
SERVER=${SERVER-virtuoso}
CLICKS=10
THOST=${THOST-localhost}
TPORT=${TPORT-8340}
PORT=${PORT-1340}

. $HOME/binsrc/tests/suite/test_fn.sh

virtuoso_start() {
  ddate=`date`
  starth=`date | cut -f 2 -d :`
  starts=`date | cut -f 3 -d :|cut -f 1 -d " "`
  timeout=600
  rm -f *.lck
  $SERVER
  stat="true"
  while true
  do
    sleep 4
    LOG "CHECKING: Is Virtuoso Server successfully started on port $PORT?"
    stat=`netstat -an | grep "[\.\:]$PORT " | grep LISTEN`
    if [ "z$stat" != "z" ]
		then
      sleep 7
      LOG "PASSED: Virtuoso Server successfully started on port $PORT"
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

do_command() {
  _dsn=$1
  command=$2
  shift
  shift
  echo "+ " $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*		>> $LOGFILE
  $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $* >> $LOGFILE
  if test $? -ne 0
  then
    LOG "***FAILED: $command"
  else
    LOG "PASSED: $command"
  fi
}

virtuoso_shutdown() {
  LOG "Shutdown Virtuoso Server..."
  RUN $ISQL $DSN dba dba "EXEC=shutdown" 2>/dev/null
  sleep 5
}

clean() {
  virtuoso_shutdown
  rm -rf vspx
  rm *.error
}

init() {
  LOG "Working directory initializing..."
  mkdir vspx
  cd vspx > /dev/null
  cp $HOME/binsrc/vspx/* . 2>/dev/null
  cp $HOME/binsrc/samples/demo/demo.db ./vspx_suite.db 2>/dev/null
  echo "
[Database]
DatabaseFile    = vspx_suite.db
TransactionFile = vspx_suite.trx
ErrorLogFile    = vspx_suite.log
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
ServerThreads        = 100
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
CallstackOnException = 1

;
; HTTP server parameters
;
; Timeout values are seconds
;

[HTTPServer]
ServerPort = $TPORT
ServerRoot = ../
ServerThreads = 5
MaxKeepAlives = 10
EnabledDavVSP = 1

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

" > virtuoso.ini
  virtuoso_start
  do_command $DSN "DB.DBA.VHOST_DEFINE ('*ini*', '*ini*', '/', '/', 0, 0, NULL,  NULL, NULL, NULL, 'dba', NULL, NULL, 0);"
  do_command $DSN "load $HOME/binsrc/vspx/vspx_demo_init.sql;"
  do_command $DSN "load $HOME/binsrc/vspx/vdir_helper.sql;"
  if [ "$VSPX_DEBUG" = "1" ]
  then
    do_command $DSN "registry_set ('__external_vspx_xslt', '1');"
    do_command $DSN "registry_set ('__no_vspx_temp', '1');"
  fi
  do_command $DSN "delete from DB.DBA.VSPX_SESSION;"
  cd ..
}

BANNER "STARTED SERIES OF VSPX SUITE TESTS"
clean
init
SUITE_LISTFILE=./run_tests.list
. ./run_tests.sh
virtuoso_shutdown
BANNER "SERIES OF VSPX SUITE TESTS DONE"



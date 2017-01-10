#!/bin/sh
#
# $Id:$
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
#  


# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL

LOGDIR=`pwd`
LOGFILE="${LOGDIR}/make_rdb2rdf_vad.output"
STICKER_DAV="vad_dav.xml"

SERVER=${SERVER-}
THOST=${THOST-localhost}
TPORT=${TPORT-8440}
PORT=${PORT-1940}
ISQL=${ISQL-isql}
DSN="$HOST:$PORT"
HOST_OS=`uname -s | grep WIN`
NEED_VERSION=06.02.3130
VERSION=1.00.0000  # see automatic versioning below

BUILDDATE=`date +"%Y-%m-%d"`

if [ "x$1" = "xdev" ]
then
  DEV="1"
fi

if [ "x$HOST_OS" != "x" ]
then
  TEMPFILE="`cygpath -m $TMP/isql.$$`"
  STICKER_DAV="`cygpath -m $STICKER_DAV`"
  if [ "x$SRC" != "x" ]
  then
    HOME=$SRC
  else
    HOME="`cygpath -m $HOME`"
  fi
  LN="cp -rf"
  RM="rm -rf"
else
  TEMPFILE=/tmp/isql.$$
  LN="ln -fs"
  RM="rm -rf"
fi
VOS=0
if [ -f ../../autogen.sh ]
then
    VOS=1
fi

if [ "z$SERVER" = "z" ]
then
    if [ "x$HOST_OS" != "x" ]
    then
        SERVER=virtuoso-odbc-t.exe
    else
        SERVER=virtuoso
    fi
fi

. $HOME/binsrc/tests/suite/test_fn.sh

if [ -f /usr/xpg4/bin/rm ]
then
  myrm=/usr/xpg4/bin/rm
else
  myrm=$RM
fi

VERSION_INIT()
{
  if [ $VOS -eq 1 ]
  then
      if [ -f vad_version ]
      then
          VERSION=`cat vad_version`
      else
        LOG "The vad_version does not exist, please verify your checkout"
        exit 1
      fi
  else
      rm -f version.tmp
      for i in `find . -name 'Entries'`; do
          cat "$i" | grep "^[^D].*" | cut -f 3 -d "/" | sed -e "s/1\.//g" >> version.tmp
      done
      LANG=POSIX
      export LANG
      VERSION=`cat version.tmp | awk ' BEGIN { cnt=180 } { cnt = cnt + $1 } END { printf "1.0%01.04f", cnt/10000 }'`
      rm -f version.tmp
      echo "$VERSION" > vad_version
  fi
}

virtuoso_start() {
  echo "Starting $SERVER"
  echo $BUILD
  ddate=`date`
  starth=`date | cut -f 2 -d :`
  starts=`date | cut -f 3 -d :|cut -f 1 -d " "`
  timeout=600
  $myrm -f *.lck
  if [ "z$HOST_OS" != "z" ]
  then
      "$SERVER" +foreground &
  else
      "$SERVER" +wait
  fi
  stat="true"
  while true
  do
    sleep 4
    echo "Waiting $SERVER start on port $PORT..."
    stat=`netstat -an | grep "[\.\:]$PORT " | grep LISTEN`
    if [ "z$stat" != "z" ]
                then
      sleep 7
      LOG "PASSED: $SERVER successfully started on port $PORT"
      return 0
    fi
    nowh=`date | cut -f 2 -d :`
    nows=`date | cut -f 3 -d : | cut -f 1 -d " "`
    nowh=`expr $nowh - $starth`
    nows=`expr $nows - $starts`
    nows=`expr $nows + $nowh \*  60`
    if test $nows -ge $timeout
    then
      LOG "***FAILED: Could not start $SERVER within $timeout seconds"
      exit 1
    fi
  done
}

do_command_safe () {
  _dsn=$1
  command=$2
  shift
  shift
  echo "+ " $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $* >> $LOGFILE
  if [ "x$HOST_OS" != "x" -a "z$BUILD" != "z" ]
        then
          $BUILD/../bin/isql.exe $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $* > "${LOGFILE}.tmp"
        else
          $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $* > "${LOGFILE}.tmp"
        fi
  if test $? -ne 0
  then
    LOG "***FAILED: starting $command"
  else
    if grep '^\*\*\*' "${LOGFILE}.tmp" > /dev/null
    then
      LOG "***FAILED: execution of $command"
      msg=`cat ${LOGFILE}.tmp`
      echo "------------ SQL ERROR -------------"
      echo "$msg"
      echo "------------------------------------"
      echo "------------ SQL ERROR -------------"       >> $LOGFILE
      echo "$msg"       >> $LOGFILE
      echo "------------------------------------"       >> $LOGFILE
    else
      LOG "PASSED: $command"
    fi
  fi
  rm "${LOGFILE}.tmp" 2>/dev/null
}

do_command() {
  _dsn=$1
  command=$2
  shift
  shift
  echo "+ " $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $* >> $LOGFILE
  $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $* >> $LOGFILE
  if test $? -ne 0
  then
    LOG "***FAILED: $command"
  else
    LOG "PASSED: $command"
  fi
}

directory_clean() {

  $myrm vad_files 2>/dev/null
  $myrm *.db 2>/dev/null
  $myrm *.trx 2>/dev/null
  $myrm *.tdb 2>/dev/null
  $myrm *.pxa 2>/dev/null
  $myrm *.log 2>/dev/null
  $myrm *.ini 2>/dev/null
}

directory_init() {
  mkdir vad_files
  mkdir vad_files/vsp
  mkdir vad_files/vsp/rdb2rdf
  cp ovl.sql vad_files/vsp/rdb2rdf/
  cp r2rml.sql vad_files/vsp/rdb2rdf/
  cp r2rml_validation_metas.sql vad_files/vsp/rdb2rdf/
  cp northwind_r2rml.ttl vad_files/vsp/rdb2rdf/
  cd $LOGDIR
}

virtuoso_shutdown() {
  LOG "Shutdown $DSN ..."
  do_command_safe $DSN "shutdown" 2>/dev/null
  sleep 5
}

sticker_init() {
  ISDAV=$1
  BASE_PATH_DAV="/DAV/VAD"
  BASE_PATH_FS="/vad/vsp"
}

virtuoso_init() {
  LOG "Virtuoso.ini creation..."
  echo "
[Database]
DatabaseFile    = virtuoso.db
TransactionFile = virtuoso.trx
ErrorLogFile    = virtuoso.log
ErrorLogLevel   = 7
FileExtend      = 200
Striping        = 0
LogSegments     = 0
Syslog          = 0

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
DirsAllowed          = $HOME
CallstackOnException = 1

;
; HTTP server parameters
;
; Timeout values are seconds
;

[!HTTPServer]
ServerPort = $TPORT
ServerRoot = .
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
}

vad_create() {
  if [ ! -d vad ];then
    mkdir vad
  fi
  mv vad_files/vsp vad
  do_command_safe $DSN "DB.DBA.VAD_PACK('$STICKER_DAV', '.', 'rdb2rdf_dav.vad')"
  do_command_safe $DSN "commit work"
  do_command_safe $DSN "checkpoint"
  mv vad/vsp vad_files
}

generate_files() {
  echo "No extra targets to generate"
}

$myrm "$LOGFILE" 2>/dev/null
BANNER 'RDB2RDF VAD create'

$ISQL -? 2>/dev/null 1>/dev/null
if [ $? -eq 127 ] ; then
    LOG "***ABORTED: rdb2rdf PACKAGING, isql is not available"
    exit 1
fi
$SERVER -? 2>/dev/null 1>/dev/null
if [ $? -eq 127 ] ; then
    LOG "***ABORTED: rdb2rdf PACKAGING, server is not available"
    exit 1
fi

if [ "x$DEV" = "x1" ]
then
        directory_clean
        directory_init
        generate_files
else
        STOP_SERVER
        directory_clean
        VERSION_INIT
        directory_init
        virtuoso_init
        generate_files
        sticker_init 0
#        sticker_init 1
        vad_create
        virtuoso_shutdown
        STOP_SERVER
        chmod 644 rdb2rdf_dav.vad
fi

CHECK_LOG
RUN egrep  '"\*\*.*FAILED:|\*\*.*ABORTED:"' "$LOGFILE"
if test $STATUS -eq 0
then
	$myrm -f *.vad
	exit 1
fi

directory_clean

BANNER "COMPLETED VAD PACKAGING"
exit 0

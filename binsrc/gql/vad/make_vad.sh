#!/bin/sh
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2026 OpenLink Software
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
#
#  openGQL (ISO/IEC 39075:2024 GQL for Virtuoso) - VAD package builder.
#
#  Builds opengql_dav.vad from the SQL modules in binsrc/gql/ and the
#  installer/uninstaller scripts in this directory.  Follows the same
#  pattern as binsrc/cypher/vad/make_vad.sh: bring up a throwaway Virtuoso
#  instance, stage the source files into ./vad/data/, call DB.DBA.VAD_PACK,
#  then tear the instance down and leave opengql_dav.vad in the current
#  directory.
#
#  Usage:
#     cd binsrc/gql/vad
#     SERVER=/path/to/virtuoso-t  ISQL=/path/to/isql  PORT=1940  TPORT=8440 \
#         sh make_vad.sh
#

LANG=C
LC_ALL=POSIX
export LANG LC_ALL

case "$0" in
  */*) SCRIPT_DIR=`dirname "$0"` ;;
  *) SCRIPT_DIR=. ;;
esac
SCRIPT_DIR=`(cd "$SCRIPT_DIR" && pwd)`
cd "$SCRIPT_DIR" || exit 1

VERSION="0.6.0"
LOGDIR=`pwd`
LOGFILE="${LOGDIR}/make_opengql_vad.log"
STICKER_NAME="make_opengql_vad.xml"

# Resolve VOS_ROOT (binsrc/gql/vad -> ../../../).
VOS_ROOT=${VOS_ROOT-`(cd ../../.. && pwd)`}

if [ -z "$SERVER" ] && [ -x "$VOS_ROOT/binsrc/virtuoso/virtuoso-t" ]
then
  SERVER="$VOS_ROOT/binsrc/virtuoso/virtuoso-t"
else
  SERVER=${SERVER-virtuoso}
fi
THOST=${THOST-localhost}
TPORT=${TPORT-8440}
PORT=${PORT-1940}
PORT=`expr $PORT '+' 10`
if [ -z "$ISQL" ] && [ -x "$VOS_ROOT/binsrc/tests/isql" ]
then
  ISQL="$VOS_ROOT/binsrc/tests/isql"
else
  ISQL=${ISQL-isql}
fi
DSN="$THOST:$PORT"
case "`uname -s`" in
  CYGWIN*|MINGW*|MSYS*) HOST_OS=WIN ;;
  *) HOST_OS= ;;
esac
NEED_VERSION=07.20.3200

if [ "x$HOST_OS" != "x" ]
then
  if [ "x$SRC" != "x" ]
  then
    HOME=$SRC
  else
    HOME="`cygpath -m $HOME`"
  fi
  LN="cp -rf"
  RM="rm -rf"
else
  LN="ln -fs"
  RM="rm -f"
fi

if [ -f /usr/xpg4/bin/rm ]
then
  myrm=/usr/xpg4/bin/rm
else
  myrm=rm
fi

LOG () { echo "$@"; echo "$@" >> "$LOGFILE"; }
ECHO () { LOG "$@"; }

SERVER_PID=

cleanup_server () {
  if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null
  then
    ECHO "Shutting down Virtuoso ..."
    $ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF \
          "EXEC=shutdown" >/dev/null 2>&1 || kill "$SERVER_PID" 2>/dev/null || true
    sleep 5
  fi
}

trap cleanup_server EXIT HUP INT TERM

sql_ping () {
  $ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF \
        "EXEC=select 1" >/dev/null 2>&1
}

do_command_safe () {
  _dsn=$1
  command=$2
  shift; shift
  echo "+ $ISQL $_dsn dba dba EXEC=\"$command\" $*" >> "$LOGFILE"
  $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF \
        "EXEC=$command" $* > "${LOGFILE}.tmp" 2>&1
  if test $? -ne 0
  then
    LOG "***FAILED: $command"
    cat "${LOGFILE}.tmp" | tee -a "$LOGFILE"
    exit 1
  else
    if egrep '^\*\*\*' "${LOGFILE}.tmp" > /dev/null
    then
      LOG "***FAILED execution of: $command"
      cat "${LOGFILE}.tmp" | tee -a "$LOGFILE"
      exit 1
    else
      LOG "PASSED: $command"
    fi
  fi
  $myrm -f "${LOGFILE}.tmp" 2>/dev/null
}

directory_clean () {
  $myrm -rf vad 2>/dev/null
  $myrm -rf vad.* 2>/dev/null
  $myrm -f make_opengql_vad.log 2>/dev/null
  $myrm -f vad.db vad.trx vad.tdb vad.lck vad.log virtuoso.tdb virtuoso.ini 2>/dev/null
}

directory_init () {
  mkdir -p vad/data
  for f in gql_runtime.sql gql_lexer.sql gql_parser.sql \
           gql_expr.sql gql_plan.sql gql_var_pass.sql \
           gql_translate.sql gql_sparql_gen.sql gql_main.sql \
           gql_endpoint.sql gql_bootstrap.sql
  do
    cp -f "$VOS_ROOT/binsrc/gql/$f" vad/data/
  done
  cp -f opengql_install.sql   vad/data/
  cp -f opengql_uninstall.sql vad/data/
}

virtuoso_start () {
  # Kill any process still holding this port
  if command -v lsof >/dev/null 2>&1; then
    local old_pid
    old_pid=`lsof -ti "TCP:$PORT" -sTCP:LISTEN 2>/dev/null`
    if [ -n "$old_pid" ]; then
      ECHO "Killing existing process $old_pid on port $PORT ..."
      kill "$old_pid" 2>/dev/null || true
      sleep 2
    fi
  fi
  ECHO "Starting Virtuoso server on port $PORT ..."
  "$SERVER" +foreground +configfile virtuoso.ini >> "$LOGFILE" 2>&1 &
  SERVER_PID=$!
  i=0
  while [ $i -lt 60 ]
  do
    sleep 2
    if ! kill -0 $SERVER_PID 2>/dev/null
    then
      ECHO "***FAILED: Virtuoso exited during startup; see $LOGFILE"
      exit 1
    fi
    if (netstat -an 2>/dev/null | grep "[\.\:]$PORT" | grep -i LISTEN > /dev/null) && sql_ping
    then
      ECHO "Virtuoso started (pid $SERVER_PID)"
      return 0
    fi
    i=`expr $i + 1`
  done
  ECHO "***FAILED: Virtuoso did not accept SQL connections within 120 seconds"
  exit 1
}

virtuoso_shutdown () {
  cleanup_server
  SERVER_PID=
}

virtuoso_init () {
  ECHO "Writing virtuoso.ini ..."
  cat > virtuoso.ini <<EOF
[Database]
DatabaseFile    = vad.db
TransactionFile = vad.trx
ErrorLogFile    = vad.log
ErrorLogLevel   = 7
FileExtend      = 200
Striping        = 0
LogSegments     = 0
Syslog          = 0

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
CallstackOnException = 2

[HTTPServer]
ServerPort    = $TPORT
ServerRoot    = .
ServerThreads = 5
MaxKeepAlives = 10
EnabledDavVSP = 1

[Client]
SQL_QUERY_TIMEOUT  = 0
SQL_TXN_TIMEOUT    = 0
SQL_PREFETCH_ROWS  = 100
SQL_PREFETCH_BYTES = 16000
EOF
  virtuoso_start
}

vad_create () {
  mydir=`pwd`
  cd "$VOS_ROOT/binsrc/vad"
  do_command_safe "$DSN" "load vad_make.sql"
  cd "$mydir"
  do_command_safe "$DSN" "DB.DBA.VAD_PACK ('$STICKER_NAME', '.', 'opengql_dav.vad')"
  do_command_safe "$DSN" "commit work"
  do_command_safe "$DSN" "checkpoint"
}

vad_check () {
  ECHO "VAD installation check ..."
  do_command_safe "$DSN" "VAD_INSTALL ('opengql_dav.vad', 0);"
  ECHO "VAD openGQL translation check ..."
  do_command_safe "$DSN" "select case when strstr (cast (DB.DBA.GQL_TO_SPARQL ('MATCH (p) RETURN p LIMIT 10', null) as varchar), 'SELECT') is not null then 1 else 1/0 end"
  ECHO "VAD openGQL param translation check ..."
  do_command_safe "$DSN" "select case when strstr (cast (DB.DBA.GQL_TO_SPARQL_PARAMS ('MATCH (p) RETURN p LIMIT 10', null, null) as varchar), 'SELECT') is not null then 1 else 1/0 end"
  ECHO "VAD openGQL execution check ..."
  do_command_safe "$DSN" "DB.DBA.OPENGQL ('MATCH (p) RETURN p LIMIT 10')"
  ECHO "VAD uninstallation check ..."
  do_command_safe "$DSN" "VAD_UNINSTALL ('opengql/$VERSION');"
}

# --- main ---------------------------------------------------------------
directory_clean
directory_init
virtuoso_init
vad_create
vad_check
virtuoso_shutdown
chmod 644 opengql_dav.vad 2>/dev/null

if [ -f opengql_dav.vad ]
then
  ECHO "COMPLETED: opengql_dav.vad"
  exit 0
else
  ECHO "***FAILED: opengql_dav.vad was not produced; see $LOGFILE"
  exit 1
fi

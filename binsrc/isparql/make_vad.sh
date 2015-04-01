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

# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL


VERSION="1.0.0"
LOGDIR=`pwd`
LOGFILE="${LOGDIR}/make_isparql_vad.log"
STICKER="make_isparql_vad.xml"
PACKDATE=`date +"%Y-%m-%d %H:%M"`
SERVER=${SERVER-virtuoso}
THOST=${THOST-localhost}
TPORT=${TPORT-8440}
PORT=${PORT-1940}
ISQL=${ISQL-isql}
DSN="$HOST:$PORT"
HOST_OS=`uname -s | grep WIN`
NEED_VERSION=04.50.2911
if [ "x$HOST_OS" != "x" ]
then
TEMPFILE="`cygpath -m $TMP/isql.$$`"
STICKER="`cygpath -m $STICKER`"
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
RM="rm -f"
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
  myrm=rm
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
      for i in `find $HOME/binsrc/isparql/ -name 'Entries' | grep -v "vad/" | grep -v "toolkit[a-z\-_]*/"`; do
	  cat $i | grep "^[^D].*" | cut -f 3 -d "/" | sed -e "s/1\.//g" >> version.tmp
      done
      # Also reflect changes in oat
      for i in `find $HOME/binsrc/oat -name 'Entries' `; do
	  cat "$i" | grep -v "version\."| grep "^[^D].*" | cut -f 3 -d "/" | sed -e "s/1\.//g" >> version.tmp
      done
      VERSION=`cat version.tmp | awk ' BEGIN { cnt=0 } { cnt = cnt + $1 } END { printf "1.%02.02f", cnt/100 }'`
      rm -f version.tmp
      echo "$VERSION" > vad_version
  fi
  echo "$VERSION/$PACKDATE" > $TOP/binsrc/isparql/version
}


virtuoso_start() {
  echo "Starting $SERVER..."
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
    if egrep '^\*\*\*' "${LOGFILE}.tmp" > /dev/null
    then
      LOG "***FAILED: execution of $command"
      msg=`cat ${LOGFILE}.tmp`
      echo "------------ SQL ERROR -------------"
      echo "$msg"
      echo "------------------------------------"
      echo "------------ SQL ERROR -------------" >> $LOGFILE
      echo "$msg" >> $LOGFILE
      echo "------------------------------------" >> $LOGFILE
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
  LOG "Cleaning the vad directory"
  chmod 644 *.trx *.tdb *.ini *.pxa *.db vad.* 2>/dev/null 1>/dev/null
  $myrm -rf vad 2>/dev/null
  $myrm -f vad.* 2>/dev/null
  $myrm -f *.db 2>/dev/null
  $myrm -f *.trx 2>/dev/null
  $myrm -f *.tdb 2>/dev/null
  $myrm -f virtuoso.log 2>/dev/null
  $myrm -f *.ini 2>/dev/null
  $myrm -f *.pxa 2>/dev/null
  $myrm -f *.lic 2>/dev/null
}

directory_init() {
  LOG "Creating the vad directory"
  mkdir vad
  mkdir vad/data
  mkdir vad/data/iSPARQL

  for dir in `find . -type d -print | LC_ALL=C sort | grep -v "^\.$" | grep -v CVS | grep -v vad | grep -v toolkit`
#  for dir in `find . -type d -print | LC_ALL=C sort | grep -v "^\.$" | grep -v CVS | grep -v vad`
  do
    mkdir vad/data/iSPARQL/$dir
  done

  mkdir vad/data/iSPARQL/toolkit
  mkdir vad/data/iSPARQL/toolkit/images
  mkdir vad/data/iSPARQL/toolkit/images/markers
  mkdir vad/data/iSPARQL/toolkit/styles
  TOOLKIT_DIR=$HOME/binsrc/oat/toolkit
  if [ -d toolkit ]; then
    TOOLKIT_DIR=toolkit
  fi
  TOOLKIT_IMG_DIR=$HOME/binsrc/oat/images
  if [ -d toolkit/images ]; then
    TOOLKIT_IMG_DIR=toolkit/images
  fi
  TOOLKIT_CSS_DIR=$HOME/binsrc/oat/styles
  if [ -d toolkit/styles ]; then
    TOOLKIT_CSS_DIR=toolkit/styles
  fi
  cp -p $TOOLKIT_DIR/*.js vad/data/iSPARQL/toolkit/
  cp -p $TOOLKIT_IMG_DIR/*.png vad/data/iSPARQL/toolkit/images/
  cp -p $TOOLKIT_IMG_DIR/*.gif vad/data/iSPARQL/toolkit/images/
  cp -p $TOOLKIT_IMG_DIR/markers/*.png vad/data/iSPARQL/toolkit/images/markers/
  cp -p $TOOLKIT_CSS_DIR/*.css vad/data/iSPARQL/toolkit/styles/
  cp -p $TOOLKIT_CSS_DIR/*.htc vad/data/iSPARQL/toolkit/styles/

  for dir in `find . -type d | grep "\\./[^/]*$"  | grep -v CVS | grep -v vad | grep -v toolkit`
#  for dir in `find . -type d | grep "\\./[^/]*$"  | grep -v CVS | grep -v vad`
  do
	  for file in `find $dir -type f -print | LC_ALL=C sort | grep -v CVS`
	  do
	    cp -p $file vad/data/iSPARQL/$file
	  done
	done

  cp $HOME/binsrc/isparql/*.html vad/data/iSPARQL
  cp $HOME/binsrc/isparql/*.vsp vad/data/iSPARQL
  #cp $HOME/binsrc/isparql/*.sql vad/data/iSPARQL
  cp $HOME/binsrc/isparql/*.js vad/data/iSPARQL
  #cp $HOME/binsrc/isparql/*.css vad/data/iSPARQL
  #cp $HOME/binsrc/isparql/hover.htc vad/data/iSPARQL
  cp $TOP/binsrc/isparql/version vad/data/iSPARQL
}

virtuoso_shutdown() {
  LOG "Shutdown $DSN ..."
  $ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=shutdown" $* >/dev/null
  sleep 10
}

sticker_init() {
  LOG "iSPARQL VAD sticker creation..."
  echo "<?xml version=\"1.0\" encoding=\"ASCII\"?>" > $STICKER
  echo "<!DOCTYPE sticker SYSTEM \"vad_sticker.dtd\">" >> $STICKER
  echo "<sticker version=\"1.0.010505A\" xml:lang=\"en-UK\">" >> $STICKER
  echo "<caption>" >> $STICKER
  echo "  <name package=\"iSPARQL\">" >> $STICKER
  echo "    <prop name=\"Title\" value=\"iSPARQL\"/>" >> $STICKER
  echo "    <prop name=\"Developer\" value=\"OpenLink Software\"/>" >> $STICKER
  echo "    <prop name=\"Copyright\" value=\"(C) 1998-2015 OpenLink Software\"/>" >> $STICKER
  echo "    <prop name=\"Download\" value=\"http://www.openlinksw.com/virtuoso\"/>" >> $STICKER
  echo "    <prop name=\"Download\" value=\"http://www.openlinksw.co.uk/virtuoso\"/>" >> $STICKER
  echo "  </name>" >> $STICKER
  echo "  <version package=\"$VERSION\">" >> $STICKER
  echo "    <prop name=\"Release Date\" value=\"$PACKDATE\" />" >> $STICKER
  echo "    <prop name=\"Build\" value=\"Release, optimized\"/>" >> $STICKER
  echo "  </version>" >> $STICKER
  echo "</caption>" >> $STICKER
  echo "<dependencies>" >> $STICKER
  echo "</dependencies>" >> $STICKER
  echo "<procedures uninstallation=\"supported\">" >> $STICKER
  echo "  <sql purpose=\"pre-install\"></sql>" >> $STICKER
  echo "  <sql purpose=\"post-install\"></sql>" >> $STICKER
  echo "</procedures>" >> $STICKER
  echo "<ddls>" >> $STICKER
  echo "    <sql purpose=\"pre-install\"><![CDATA[ " >> $STICKER
  echo "    if (lt (sys_stat ('st_dbms_ver'), '$NEED_VERSION')) " >> $STICKER
  echo "      { " >> $STICKER
  echo "         result ('ERROR', 'The iSPARQL package requires server version $NEED_VERSION or greater'); " >> $STICKER
  echo "	 signal ('FATAL', 'The iSPARQL package requires server version $NEED_VERSION or greater'); " >> $STICKER
  echo "      } " >> $STICKER
  echo "  ]]></sql>" >> $STICKER
  echo "  <sql purpose=\"post-install\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
	echo "" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/iSPARQL/sql/setup.sql',1,'report',1);" >> $STICKER
	echo "      DB.DBA.VHOST_REMOVE (lpath=>'/isparql/');" >> $STICKER
  echo "      DB.DBA.VHOST_DEFINE (lpath=>'/isparql/', ppath=>'/DAV/VAD/iSPARQL/', vsp_user=>'dba', is_dav=>1, def_page=>'index.html');" >> $STICKER
  echo "      DB.DBA.VHOST_REMOVE (lpath=>'/isparql/view/');" >> $STICKER
  echo "      DB.DBA.VHOST_DEFINE (lpath=>'/isparql/view/', ppath=>'/DAV/VAD/iSPARQL/', vsp_user=>'dba', is_dav=>1, is_brws=>0, def_page=>'execute.html');" >> $STICKER
  echo "      DB.DBA.VHOST_REMOVE (lpath=>'/isparql/defaults/');" >> $STICKER
  echo "      DB.DBA.VHOST_DEFINE (lpath=>'/isparql/defaults/', ppath=>'/DAV/VAD/iSPARQL/', vsp_user=>'dba', is_dav=>1, is_brws=>0, def_page=>'defaults.vsp');" >> $STICKER
#  echo "      registry_set ('iSPARQL_VERSION','$VERSION');" >> $STICKER
#  echo "      registry_set ('iSPARQL_DATE','$PACKDATE');" >> $STICKER
  echo "" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "  <sql purpose=\"pre-uninstall\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/iSPARQL/sql/drop.sql',1,'report',1);" >> $STICKER
	echo "      DB.DBA.VHOST_REMOVE (lpath=>'/isparql/');" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "</ddls>" >> $STICKER
  echo "<resources>" >> $STICKER
  oldIFS="$IFS"
  IFS='
'
  for file in `find vad -type f | grep -v '/CVS'`
  do
    name=`echo "$file" | cut -b18-`
#    if [ $name = 'index.html' ]; then
#      perm=111101000NN
#    else
      perm=111101101NN
#    fi
    echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"iSPARQL/$name\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"$perm\" makepath=\"yes\"/>" >> $STICKER
  done
  IFS="$oldIFS"
  echo "</resources>" >> $STICKER
  echo "<registry>" >> $STICKER
  echo "</registry>" >> $STICKER
  echo "</sticker>" >> $STICKER
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
Syslog    = 0

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
  do_command_safe $DSN "DB.DBA.VAD_PACK('$STICKER', '.', 'isparql_dav.vad')"
  do_command_safe $DSN "commit work"
  do_command_safe $DSN "checkpoint"
}

BANNER "STARTED PACKAGING iSPARQL VAD"
STOP_SERVER
$myrm $LOGFILE 2>/dev/null
directory_clean
VERSION_INIT
directory_init
virtuoso_init
sticker_init
vad_create
virtuoso_shutdown
chmod 644 isparql_dav.vad
chmod 644 virtuoso.trx
directory_clean

CHECK_LOG
RUN egrep  '"\*\*.*FAILED:|\*\*.*ABORTED:"' "$LOGFILE"
if test $STATUS -eq 0
then
	$myrm -f *.vad
	exit 1
fi

BANNER "COMPLETED VAD PACKAGING"
exit 0

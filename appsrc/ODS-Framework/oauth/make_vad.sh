#!/bin/sh
#
#  $Id$
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2019 OpenLink Software
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

# check version_init procedure below

# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL

VERSION="1.00.00"
LOGDIR=`pwd`
STICKER_DAV="vad_dav.xml"
STICKER_FS="vad_fs.xml"
PACKDATE=`date +"%Y-%m-%d %H:%M"`
SERVER=${SERVER-}
THOST=${THOST-localhost}
TPORT=${TPORT-8445}
PORT=${PORT-1940}
ISQL=${ISQL-isql}
VAD_NAME="policy_manager"
VAD_PKG_NAME="policy_manager"
VAD_DESC="Policy Manager"
LOGFILE="${LOGDIR}/make_"$VAD_PKG_NAME"_vad.log"
VAD_NAME_DEVEL="$VAD_PKG_NAME"_filesystem.vad
VAD_NAME_RELEASE="$VAD_PKG_NAME"_dav.vad
NEED_VERSION=05.00.3028
HOST=localhost
DSN="$PORT"
HOST_OS=`uname -s | grep WIN`
if [ "x$HOST_OS" != "x" ]
then
TEMPFILE="`cygpath -m $TMP/isql.$$`"
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
if [ -f $HOME/autogen.sh ]
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

version_init() 
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
      for i in `find . -name 'Entries' | grep -v "vad/"`; do
      cat $i | grep "^[^D].*" | cut -f 3 -d "/" | sed -e "s/1\.//g" >> version.tmp
      done
      VERSION=`cat version.tmp | awk ' BEGIN { cnt=1 } { cnt = cnt + $1 } END { printf "1.%02.02f", cnt/100 }'`
      rm -f version.tmp
      echo "$VERSION" > vad_version
  fi
}

do_command_safe () {
  _dsn=$1
  command=$2
  shift
  shift
  echo "+ " $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $* >> $LOGFILE
  $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $* 2>&1 > "${LOGFILE}.tmp"
  if test $? -ne 0
  then
    cat "${LOGFILE}.tmp" >> ${LOGFILE}
    LOG "***FAILED: starting $command"
  else
    if egrep '^\*\*\*' "${LOGFILE}.tmp" > /dev/null
    then
      LOG "***FAILED: execution of $command"
      msg=`cat ${LOGFILE}.tmp`
      echo "------------ SQL ERROR -------------"
      echo "$msg"
      echo "------------------------------------"
      echo "------------ SQL ERROR -------------"   >> $LOGFILE
      echo "$msg"   >> $LOGFILE
      echo "------------------------------------"   >> $LOGFILE
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
  $myrm -rf vad 2>/dev/null
  $myrm -rf vad.* 2>/dev/null
  $myrm -rf make_vad.log 2>/dev/null
  $myrm -rf virtuoso.db 2>/dev/null
  $myrm -rf virtuoso.trx 2>/dev/null
  $myrm -rf virtuoso.tdb 2>/dev/null
  $myrm -rf virtuoso.log 2>/dev/null
  $myrm -rf virtuoso.ini 2>/dev/null
}

directory_init() {
  mkdir vad
  mkdir vad/code
  mkdir vad/code/$VAD_NAME
  mkdir vad/vsp
  mkdir vad/vsp/$VAD_NAME
  mkdir vad/vsp/$VAD_NAME/images

  cp *.sql vad/code/$VAD_NAME/.
  cp *.vsp vad/vsp/$VAD_NAME/.
  cp images/* vad/vsp/$VAD_NAME/images/.
  cp *.vspx vad/vsp/$VAD_NAME/.
  cp *.css vad/vsp/$VAD_NAME/.

}

virtuoso_start() {
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
    echo "Waiting Virtuoso Server start on port $PORT..."
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

virtuoso_shutdown() {
  LOG "Shutdown Virtuoso Server..."
  $ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=raw_exit();" $* >/dev/null
  #sleep 10
}

sticker_init() {
  ISDAV=$1
  if [ "$ISDAV" = "1" ] ; then
    BASE_PATH_HTTP="/DAV/VAD/"
    BASE_PATH_CODE="/DAV/VAD/"
    TYPE="dav"
    STICKER=$STICKER_DAV
    PPATH="/DAV/VAD/$VAD_NAME/"
    DPPATH="/DAV/VAD"
  else
    BASE_PATH_HTTP="./vad/vsp/"
    BASE_PATH_CODE="./vad/vsp/"
    TYPE="http"
    STICKER=$STICKER_FS
    PPATH="/vad/vsp/$VAD_NAME/"
    DPPATH="/vad/vsp"
  fi
  LOG "VAD Sticker $STICKER creation..."
  echo "<?xml version=\"1.0\" encoding=\"ASCII\"?>" > $STICKER
  echo "<!DOCTYPE sticker SYSTEM \"vad_sticker.dtd\">" >> $STICKER
  echo "<sticker version=\"1.0.010505A\" xml:lang=\"en-UK\">" >> $STICKER
  echo "<caption>" >> $STICKER
  echo "  <name package=\"$VAD_NAME\">" >> $STICKER
  echo "    <prop name=\"Title\" value=\"$VAD_DESC\"/>" >> $STICKER
  echo "    <prop name=\"Developer\" value=\"OpenLink Software\"/>" >> $STICKER
  echo "    <prop name=\"Copyright\" value=\"(C) 1998-2019 OpenLink Software\"/>" >> $STICKER
  echo "    <prop name=\"Download\" value=\"http://www.openlinksw.com/virtuoso\"/>" >> $STICKER
  echo "    <prop name=\"Download\" value=\"http://www.openlinksw.co.uk/virtuoso\"/>" >> $STICKER
  echo "  </name>" >> $STICKER
  echo "  <version package=\"$VERSION\">" >> $STICKER
  echo "    <prop name=\"Release Date\" value=\"$PACKDATE\"/>" >> $STICKER
  echo "    <prop name=\"Build\" value=\"Release, optimized\"/>" >> $STICKER
  echo "  </version>" >> $STICKER
  echo "</caption>" >> $STICKER
  echo "<dependencies>" >> $STICKER
  echo "</dependencies>" >> $STICKER
  echo "<procedures uninstallation=\"supported\">" >> $STICKER
  echo "  <sql purpose=\"pre-install\"><![CDATA[" >> $STICKER
  echo "    if (lt (sys_stat ('st_dbms_ver'), '$NEED_VERSION')) " >> $STICKER
  echo "      { " >> $STICKER
  echo "         result ('ERROR', 'The $VAD_DESC package requires server version $NEED_VERSION or greater'); " >> $STICKER
  echo "     signal ('FATAL', 'The $VAD_DESC package requires server version $NEED_VERSION or greater'); " >> $STICKER
  echo "      } " >> $STICKER
  echo "     if (VAD_CHECK_VERSION ('auth_policy') is not null and VAD_CHECK_VERSION ('$VAD_NAME') is null) " >> $STICKER
  echo "       {" >> $STICKER
  echo "          DB.DBA.VAD_RENAME ('auth_policy', '$VAD_NAME');" >> $STICKER
  echo "       }" >> $STICKER
  echo "  ]]></sql>" >> $STICKER
  echo "  <sql purpose=\"post-install\">" >> $STICKER
  echo "    ; " >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "</procedures>" >> $STICKER
  echo "<ddls>" >> $STICKER
  echo "  <sql purpose=\"post-install\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "        declare _ppath any;" >> $STICKER
  echo "        set_qualifier ('DB');" >> $STICKER
if [ "$ISDAV" = "1" ] ; then
  echo "    registry_set('_"$VAD_NAME"_path_', '/DAV/VAD/$VAD_NAME/');" >> $STICKER
else
  echo "    registry_set('_"$VAD_NAME"_path_', '/vad/vsp/$VAD_NAME/');" >> $STICKER
fi
  echo "    registry_set('_"$VAD_NAME"_dav_', '$ISDAV');" >> $STICKER
  echo "    _ppath := registry_get('_"$VAD_NAME"_path_');" >> $STICKER
  # OAuth server endpoint
  echo "    DB.DBA.VHOST_REMOVE (lpath=>'/oauth');" >> $STICKER
  echo "    DB.DBA.VHOST_DEFINE (lpath=>'/oauth', ppath=>_ppath, vsp_user=>'dba', is_dav=>$ISDAV, is_brws=>0, def_page=>'index.vsp');" >> $STICKER
  # UI for settings etc.
  echo "    DB.DBA.VHOST_REMOVE (lpath=>'/$VAD_NAME');" >> $STICKER
  echo "    DB.DBA.VHOST_DEFINE (lpath=>'/$VAD_NAME', ppath=>_ppath, vsp_user=>'dba', is_dav=>$ISDAV, is_brws=>0, def_page=>'index.vsp');" >> $STICKER
  echo "    DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH_CODE"$VAD_NAME/oauth.sql', 0, 'report', $ISDAV);" >> $STICKER
  echo "    DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH_CODE"$VAD_NAME/foaf_ssl.sql', 0, 'report', $ISDAV);" >> $STICKER
  # SPARQL + OAUTH 
  echo "    DB.DBA.VHOST_REMOVE (lpath=>'/sparql-oauth');" >> $STICKER
  echo "    DB.DBA.VHOST_DEFINE (lpath=>'/sparql-oauth', ppath=>_ppath, vsp_user=>'dba', is_dav=>$ISDAV, is_brws=>0, def_page=>'sparql.vsp');" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "  <sql purpose='pre-uninstall'>" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "    ;" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
#  echo "  <sql purpose='post-uninstall'>" >> $STICKER
#  echo "  </sql>" >> $STICKER
  echo "</ddls>" >> $STICKER
  echo "<resources>" >> $STICKER

  echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"$VAD_NAME/oauth.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"$VAD_NAME/foaf_ssl.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER


  cd vad/vsp/$VAD_NAME
  for file in `find . -type f -print | grep -v CVS | grep -v ".sql" | sort | cut -b3-`
  do
      echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"$VAD_NAME/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> ../../../$STICKER
  done
  cd ../../..

  echo "</resources>" >> $STICKER
  echo "<registry>" >> $STICKER
  echo "</registry>" >> $STICKER
  echo "</sticker>" >> $STICKER
}

virtuoso_init() {
  LOG "Virtuoso.ini creation..."
  echo "
[Database]
DatabaseFile    = vad.db
TransactionFile = vad.trx
ErrorLogFile    = vad.log
ErrorLogLevel   = 7
FileExtend      = 200
Striping        = 0
LogSegments     = 0
Syslog      = 0
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
QueueMax     = 50000" > virtuoso.ini

  virtuoso_start
}

vad_create() {
  STICKER=$1
  V_NAME=$2
  mydir=`pwd`
  do_command_safe $DSN "DB.DBA.VAD_PACK('$STICKER', '.', '$V_NAME')"
  do_command_safe $DSN "commit work"
  do_command_safe $DSN "checkpoint"
}

BANNER "STARTED $VAD_DESC PACKAGING"

$ISQL -? 2>/dev/null 1>/dev/null 
if [ $? -eq 127 ] ; then
    LOG "***ABORTED: $VAD_DESC PACKAGING, isql is not available"
    exit 1
fi
$SERVER -? 2>/dev/null 1>/dev/null 
if [ $? -eq 127 ] ; then
    LOG "***ABORTED: $VAD_DESC PACKAGING, server is not available"
    exit 1
fi
    

virtuoso_shutdown
directory_clean
directory_init
version_init
sticker_init 1
sticker_init 0
virtuoso_init
vad_create $STICKER_FS $VAD_NAME_DEVEL
vad_create $STICKER_DAV $VAD_NAME_RELEASE
virtuoso_shutdown
chmod 644 $VAD_NAME_DEVEL
chmod 644 $VAD_NAME_RELEASE
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

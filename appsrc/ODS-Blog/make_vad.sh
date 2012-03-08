#!/bin/sh
#
#  $Id$
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2012 OpenLink Software
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
LOGFILE="${LOGDIR}/make_ods_blog_vad.log"
STICKER_NAME="make_ods_blog_vad.xml"
STICKER="${LOGDIR}/$STICKER_NAME"
PACKDATE=`date +"%Y-%m-%d %H:%M"`
SERVER=${SERVER-virtuoso}
THOST=${THOST-localhost}
TPORT=${TPORT-8440}
PORT=${PORT-1940}
ISQL=${ISQL-isql}
DSN="$HOST:$PORT"
HOST_OS=`uname -s | grep WIN`
NEED_VERSION=04.50.2914
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
      VERSION=`cat version.tmp | awk ' BEGIN { cnt=290 } { cnt = cnt + $1 } END { printf "1.%02.02f", cnt/100 }'`
      rm -f version.tmp
      echo "$VERSION" > vad_version
  fi
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
  mkdir vad/data/blog2
  mkdir vad/data/blog2/public
  mkdir vad/data/blog2/templates
  mkdir vad/data/blog2/templates/default
  mkdir vad/data/blog2/templates/modern
  mkdir vad/data/blog2/templates/autumn
  mkdir vad/data/blog2/templates/blue_left
  mkdir vad/data/blog2/templates/openlink
  mkdir vad/data/blog2/templates/openlink_classic
  mkdir vad/data/blog2/templates/round_wheat
  mkdir vad/data/blog2/templates/seattle
  mkdir vad/data/blog2/templates/spring
  mkdir vad/data/blog2/templates/atlantis
  mkdir vad/data/blog2/templates/thin_clean
  mkdir vad/data/blog2/templates/thin_pastel
  mkdir vad/data/blog2/templates/squeaky_clean
  mkdir vad/data/blog2/templates/columns_clean
  mkdir vad/data/blog2/templates/digital_bazaar
  mkdir vad/data/blog2/templates/digital_bazaar/images
  mkdir vad/data/blog2/templates/newspaper_view
  mkdir vad/data/blog2/templates/newspaper_view/images
  mkdir vad/data/blog2/templates/micro
  mkdir vad/data/blog2/widgets
  cp index.vspx vad/data/blog2
  cp *.sql vad/data/blog2
  cp $HOME/binsrc/dav/DET_Blog.sql vad/data/blog2
  cp -rf public/* vad/data/blog2/public
  cp -f templates/openlink/default.css vad/data/blog2/public/css/default.css
  cp -f templates/default/* vad/data/blog2/templates/default 2>/dev/null
  cp -f templates/modern/* vad/data/blog2/templates/modern 2>/dev/null
  cp -f templates/autumn/* vad/data/blog2/templates/autumn 2>/dev/null
  cp -f templates/blue_left/* vad/data/blog2/templates/blue_left 2>/dev/null

  cp -f templates/openlink/* vad/data/blog2/templates/openlink 2>/dev/null
  cp -f templates/openlink/* vad/data/blog2/templates/openlink_classic 2>/dev/null
  cp -f templates/openlink_classic/default.css vad/data/blog2/templates/openlink_classic/default.css

  cp -f templates/round_wheat/* vad/data/blog2/templates/round_wheat 2>/dev/null
  cp -f templates/spring/* vad/data/blog2/templates/spring 2>/dev/null
  cp -f templates/seattle/* vad/data/blog2/templates/seattle 2>/dev/null
  cp -f templates/atlantis/* vad/data/blog2/templates/atlantis 2>/dev/null
  cp -f templates/thin_clean/* vad/data/blog2/templates/thin_clean 2>/dev/null
  cp -f templates/thin_pastel/* vad/data/blog2/templates/thin_pastel 2>/dev/null
  cp -f templates/squeaky_clean/* vad/data/blog2/templates/squeaky_clean 2>/dev/null
  cp -f templates/columns_clean/* vad/data/blog2/templates/columns_clean 2>/dev/null
  cp -f templates/digital_bazaar/* vad/data/blog2/templates/digital_bazaar 2>/dev/null
  cp -f templates/digital_bazaar/images/* vad/data/blog2/templates/digital_bazaar/images 2>/dev/null
  cp -f templates/newspaper_view/* vad/data/blog2/templates/newspaper_view 2>/dev/null
  cp -f templates/newspaper_view/images/* vad/data/blog2/templates/newspaper_view/images 2>/dev/null
  cp -f templates/micro/* vad/data/blog2/templates/micro 2>/dev/null

  cp -f templates/main.vspx vad/data/blog2/templates/main.vspx
  cp -rf widgets/* vad/data/blog2/widgets
}

virtuoso_shutdown() {
  LOG "Shutdown $DSN ..."
  $ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=shutdown" $* >/dev/null
  sleep 10
}

sticker_init() {
  LOG "Weblog VAD sticker creation..."
  echo "<?xml version=\"1.0\" encoding=\"ASCII\"?>" > $STICKER
  echo "<!DOCTYPE sticker SYSTEM \"vad_sticker.dtd\">" >> $STICKER
  echo "<sticker version=\"1.0.010505A\" xml:lang=\"en-UK\">" >> $STICKER
  echo "<caption>" >> $STICKER
  echo "  <name package=\"Weblog\">" >> $STICKER
  echo "    <prop name=\"Title\" value=\"ODS Weblog\"/>" >> $STICKER
  echo "    <prop name=\"Developer\" value=\"OpenLink Software\"/>" >> $STICKER
  echo "    <prop name=\"Copyright\" value=\"(C) 1998-2012 OpenLink Software\"/>" >> $STICKER
  echo "    <prop name=\"Download\" value=\"http://www.openlinksw.com/virtuoso/blog2/download\"/>" >> $STICKER
  echo "    <prop name=\"Download\" value=\"http://www.openlinksw.co.uk/virtuoso/blog2/download\"/>" >> $STICKER
  echo "  </name>" >> $STICKER
  echo "  <version package=\"$VERSION\">" >> $STICKER
  echo "    <prop name=\"Release Date\" value=\"$PACKDATE\" />" >> $STICKER
  echo "    <prop name=\"Build\" value=\"Release, optimized\"/>" >> $STICKER
  echo "  </version>" >> $STICKER
  echo "</caption>" >> $STICKER
  echo "<dependencies>" >> $STICKER
  echo "  <require>" >> $STICKER
  echo "    <name package=\"Framework\"/>" >> $STICKER
  echo "    <versions_later package=\"1.77.31\">" >> $STICKER
  echo "      <prop name=\"Date\" value=\"2010-10-20 00:00\" />" >> $STICKER
  echo "      <prop name=\"Comment\" value=\"An incompatible version of the ODS Framework\" />" >> $STICKER
  echo "    </versions_later>" >> $STICKER
  echo "  </require>" >> $STICKER
  echo "</dependencies>" >> $STICKER
  echo "<procedures uninstallation=\"supported\">" >> $STICKER
  echo "  <sql purpose=\"pre-install\"></sql>" >> $STICKER
  echo "  <sql purpose=\"post-install\"></sql>" >> $STICKER
  echo "</procedures>" >> $STICKER
  echo "<ddls>" >> $STICKER
  echo "    <sql purpose=\"pre-install\"><![CDATA[ " >> $STICKER
  echo "    if (lt (sys_stat ('st_dbms_ver'), '$NEED_VERSION')) " >> $STICKER
  echo "      { " >> $STICKER
  echo "         result ('ERROR', 'The blog package requires server version $NEED_VERSION or greater'); " >> $STICKER
  echo "	 signal ('FATAL', 'The blog package requires server version $NEED_VERSION or greater'); " >> $STICKER
  echo "      } " >> $STICKER
  echo "     if (VAD_CHECK_VERSION ('blog2') is not null and VAD_CHECK_VERSION ('Weblog') is null) " >> $STICKER
  echo "       {" >> $STICKER
  echo "          DB.DBA.VAD_RENAME ('blog2', 'Weblog');" >> $STICKER
  echo "       }" >> $STICKER
  echo "  ]]></sql>" >> $STICKER
  echo "  <sql purpose=\"post-install\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "      registry_set('_blog2_path_', '/DAV/VAD/blog2/');" >> $STICKER
  echo "      registry_set('_blog2_version_', '$VERSION');" >> $STICKER
  echo "      registry_set('_blog2_build_', '$PACKDATE');" >> $STICKER
  echo "      registry_set('WeblogServerID', uuid ());" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/blog2/blog.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/blog2/trackback.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/blog2/atom_pub.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/blog2/gdata.sql', 1, 'report', 1);" >> $STICKER
  echo "      if (VAD_CHECK_VERSION ('conductor') is null) " >> $STICKER
  echo "        DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/blog2/dav_browser.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/blog2/install.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/blog2/template.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.BLOG2_MAKE_RESOURCES(registry_get('_blog2_path_'));" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/blog2/wa_integration.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.BLOG2_UPGRADE_FROM_BLOG2();" >> $STICKER
  echo "      BLOG2_UPDATE_SYS_BLOG_INFO_DEL ();" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/blog2/DET_Blog.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/blog2/wa_search_blog.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/blog2/conv.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/blog2/blog_api.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/blog2/sioc_blog.sql', 1, 'report', 1);" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "  <sql purpose=\"pre-uninstall\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/blog2/uninst.sql', 1, 'report', 1);" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "</ddls>" >> $STICKER
  echo "<resources>" >> $STICKER
  echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"blog2/index.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"blog2/blog.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"blog2/dav_browser.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"blog2/trackback.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110101001NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"blog2/atom_pub.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110101001NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"blog2/gdata.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110101001NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"blog2/install.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"blog2/wa_integration.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"blog2/template.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"blog2/uninst.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"blog2/DET_Blog.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"blog2/wa_search_blog.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"blog2/conv.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"blog2/sioc_blog.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"blog2/blog_api.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  cd vad/data/blog2 2>/dev/null
  oldIFS="$IFS"
  IFS='
'
  for file in `find public/* -type f | grep -v '/CVS'`
  do
    echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"blog2/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  done
  for file in `find templates/* -type f | grep -v '/CVS'`
  do
    echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"blog2/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  done
  for file in `find widgets/* -type f -o -type l | grep -v '/CVS'`
  do
    echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"blog2/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  done
  cd ../../..
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
  do_command_safe $DSN "DB.DBA.VAD_PACK('$STICKER_NAME', '.', 'ods_blog_dav.vad')"
  do_command_safe $DSN "commit work"
  do_command_safe $DSN "checkpoint"
}

BANNER "STARTED PACKAGING BLOG VAD"
STOP_SERVER
$myrm $LOGFILE 2>/dev/null
directory_clean
version_init
directory_init
virtuoso_init
sticker_init
vad_create
virtuoso_shutdown
chmod 644 ods_blog_dav.vad
#chmod 644 virtuoso.trx

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

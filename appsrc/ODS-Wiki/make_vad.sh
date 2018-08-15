#!/bin/sh
#
#  $Id$
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2018 OpenLink Software
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

VERSION="1.0"
LOGDIR=`pwd`
LOGFILE="${LOGDIR}/make_wiki_vad.log"
STICKER=`pwd`"/make_wiki_vad.xml"
STICKER_NAME="make_wiki_vad.xml"
SERVER=${SERVER-virtuoso}
THOST=${THOST-localhost}
TPORT=${TPORT-8440}
PORT=${PORT-1940}
PORT=`expr $PORT '+' 20`
ISQL=${ISQL-isql}
DSN="$HOST:$PORT"
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


VOS=0
if [ -f ../../autogen.sh ]
then
    VOS=1
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
      for i in `find . -name 'Entries' | grep -v "vad/" | grep -v "/tests/"`; do
	  cat "$i" | grep -v "version\."| grep "^[^D].*" | cut -f 3 -d "/" | sed -e "s/1\.//g" >> version.tmp
      done
      LANG=POSIX
      export LANG

      BASE="0"
#      echo $BASE
      if [ -f version.base ] ; then
	  BASE=`cat version.base`
      fi

      VERSION=`cat version.tmp | awk ' BEGIN { cnt=10 } { cnt = cnt + $1 } END { print cnt }'`

      VERSION=`expr $BASE + $VERSION`
      CURR_VERSION=$VERSION
      if [ -f version.curr ] ; then
	  CURR_VERSION=`cat version.curr`
      fi
      if [ $CURR_VERSION -gt $VERSION ] ; then
	  BASE=`expr $CURR_VERSION - $VERSION + 1`
	  echo $BASE > version.base
	  VERSION=$CURR_VERSION
      fi
      echo $VERSION > version.curr
      VERSION=`echo $VERSION | awk ' { printf "1.%02.02f", $1/100 }'`
      rm -f version.tmp
      echo "$VERSION" > vad_version
  fi
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
  $myrm -r vad 2>/dev/null
  $myrm -rf vad.* 2>/dev/null
  $myrm -f make_vad.log 2>/dev/null
  $myrm -f virtuoso.db 2>/dev/null
  $myrm -f virtuoso.trx 2>/dev/null
  $myrm -f virtuoso.tdb 2>/dev/null
  $myrm -f virtuoso.log 2>/dev/null
  $myrm -f virtuoso.ini 2>/dev/null
}

directory_init() {
  mkdir vad
  mkdir vad/data
  mkdir vad/data/wiki
  mkdir vad/data/wiki/Root
  mkdir vad/data/wiki/Main
  mkdir vad/data/wiki/Doc
  mkdir vad/data/wiki/Template
  cp *.sql vad/data/wiki
  cp -r http/* vad/data/wiki/Root
  cp -r Skins  vad/data/wiki/Root
  cp -r js  vad/data/wiki/Root
  cp -r initial/Main/* vad/data/wiki/Main
  cp -r initial/Wiki/* vad/data/wiki/Doc
  cp -r Template/* vad/data/wiki/Template
}

virtuoso_shutdown() {
  LOG "Shutdown Virtuoso Server..."
  $ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=shutdown" $* >/dev/null
  sleep 10
}

sticker_init() {
  LOG "VAD Sticker creation..."
  echo "<?xml version=\"1.0\" encoding=\"ASCII\"?>" > $STICKER
  echo "<!DOCTYPE sticker SYSTEM \"vad_sticker.dtd\">" >> $STICKER
  echo "<sticker version=\"1.0.010505A\" xml:lang=\"en-UK\">" >> $STICKER
  echo "<caption>" >> $STICKER
  echo "  <name package=\"Wiki\">" >> $STICKER
  echo "    <prop name=\"Title\" value=\"ODS Wiki\"/>" >> $STICKER
  echo "    <prop name=\"Developer\" value=\"OpenLink Software\"/>" >> $STICKER
  echo "    <prop name=\"Copyright\" value=\"(C) 1998-2018 OpenLink Software\"/>" >> $STICKER
  echo "    <prop name=\"Download\" value=\"http://www.openlinksw.com/\"/>" >> $STICKER
  echo "    <prop name=\"Download\" value=\"http://www.openlinksw.co.uk/\"/>" >> $STICKER
  echo "  </name>" >> $STICKER
  echo "  <version package=\"$VERSION\">" >> $STICKER
  echo "    <prop name=\"Release Date\" value=\""`date +"%Y-%m-%d %H:%M"`"\"/>" >> $STICKER
  echo "    <prop name=\"Build\" value=\"Release, optimized\"/>" >> $STICKER
  echo "  </version>" >> $STICKER
  echo "</caption>" >> $STICKER
  echo "<dependencies>" >> $STICKER
  echo "  <require>" >> $STICKER
  echo "    <name package=\"Framework\"/>" >> $STICKER
  echo "    <versions_later package=\"1.83.00\">" >> $STICKER
  echo "      <prop name=\"Date\" value=\"2011-07-27 12:00\" />" >> $STICKER
  echo "      <prop name=\"Comment\" value=\"An incompatible version of the ODS Framework\" />" >> $STICKER
  echo "    </versions_later>" >> $STICKER
  echo "  </require>" >> $STICKER
  echo "</dependencies>" >> $STICKER
  echo "<procedures uninstallation=\"supported\">" >> $STICKER
  echo "  <sql purpose=\"pre-install\">" >> $STICKER
  echo "    whenever sqlstate '22003' goto passed;" >> $STICKER
  echo "        whenever sqlstate '42001' goto failed;" >> $STICKER
  echo "        \"WikiV lexer\" ();" >> $STICKER
  echo "        if (1 = 0) {" >> $STICKER
  echo "    failed:" >> $STICKER
  echo "         \"VAD\".\"DBA\".\"VAD_FAIL_CHECK\"('wikiv.dll (wikiv.so) plugin is not loaded, make sure you have something like this in ini file for loading oWiki plugin:" >> $STICKER
  echo "[Plugins]" >> $STICKER
  echo "LoadPath = ./plugin" >> $STICKER
  echo "Load1    = plain, wikiv" >> $STICKER
  echo "');" >> $STICKER
  echo "        }" >> $STICKER
  echo "    passed:" >> $STICKER
  echo "    whenever sqlstate '22003' default;" >> $STICKER
  echo "    whenever sqlstate '42001' default;" >> $STICKER

  echo "    if (lt (sys_stat ('st_dbms_ver'), '$NEED_VERSION')) " >> $STICKER
  echo "      { " >> $STICKER
  echo "        result ('ERROR', 'The Wiki package requires server version $NEED_VERSION or greater'); " >> $STICKER
  echo "	      signal ('FATAL', 'The Wiki package requires server version $NEED_VERSION or greater'); " >> $STICKER
  echo "      } " >> $STICKER
  echo "    if ((VAD_CHECK_VERSION ('wiki') is not null) and (VAD_CHECK_VERSION ('Wiki') is null)) " >> $STICKER
  echo "      {" >> $STICKER
  echo "        DB.DBA.VAD_RENAME ('wiki', 'Wiki');" >> $STICKER
  echo "      }" >> $STICKER

  echo "  </sql>" >> $STICKER
  echo "  <sql purpose=\"post-install\"></sql>" >> $STICKER
  echo "</procedures>" >> $STICKER
  echo "<ddls>" >> $STICKER
  echo "  <sql purpose=\"pre-install\"></sql>" >> $STICKER
  echo "  <sql purpose=\"post-install\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/setup_vad.sql', 0, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/schema_on.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/wa_integration.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/wa_search_wiki.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/sioc.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/proc_on.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/proc_on_vsp.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/proc_on_macro.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/proc_on_api.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/semantics.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/proc_tmp.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/webmail.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/export.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/conv.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/atom.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/upstream.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/plugins.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/errors.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/api.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/postinstall.sql', 1, 'report', 1);" >> $STICKER
  echo "      " >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "  <sql purpose=\"pre-uninstall\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/drop.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.DAV_DELETE_INT ('/DAV/VAD/wiki/', 0, null, null, 0, 0);" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "  <sql purpose=\"post-uninstall\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "</ddls>" >> $STICKER
  echo "<resources>" >> $STICKER
  oldIFS="$IFS"
  IFS='
' 
  for file in *.sql
  do
    if echo "$file" | grep -v "/CVS/" >/dev/null
    then
      echo "  <file type=\"dav\" source=\"data\" target_uri=\"wiki/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
    fi
  done
  cd http
  for file in `find . -type f | sed 's/^..//'`
  do
    if echo "$file" | grep -v "CVS" >/dev/null
    then
      echo "  <file type=\"dav\" source=\"data\" target_uri=\"wiki/Root/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
    fi
  done
  cd ..
  cd initial/Main
  for file in `find . -type f | sed 's/^..//'` 
  do
    if echo "$file" | grep -v "CVS" >/dev/null
    then
      echo "  <file type=\"dav\" source=\"data\" target_uri=\"wiki/Main/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101R\" makepath=\"yes\"/>" >> $STICKER
    fi
  done
  cd ..
  cd ..
  cd initial/Wiki
  for file in `find . -type f | sed 's/^..//'` 
  do
    if echo "$file" | grep -v "CVS" >/dev/null
    then
      echo "  <file type=\"dav\" source=\"data\" target_uri=\"wiki/Doc/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101R\" makepath=\"yes\"/>" >> $STICKER
    fi
  done
  cd ..
  cd ..
  cd Template
  for file in `find . -type f | sed 's/^..//'`
  do
    if echo "$file" | grep -v "CVS" >/dev/null
    then
      echo "  <file type=\"dav\" source=\"data\" target_uri=\"wiki/Template/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
    fi
  done
  cd ..
  cd Skins
  for file in `find . -type f | sed 's/^..//'`
  do
    if echo "$file" | grep -v "CVS" >/dev/null
    then
      echo "  <file type=\"dav\" source=\"data\" target_uri=\"wiki/Root/Skins/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
    fi
  done
  cd ..
  cd js
  for file in `find . -type f | sed 's/^..//'`
  do
    if echo "$file" | grep -v "CVS" >/dev/null
    then
      echo "  <file type=\"dav\" source=\"data\" target_uri=\"wiki/Root/js/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
    fi
  done
  cd ..
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
DatabaseFile    = vad.db
TransactionFile = vad.trx
ErrorLogFile    = vad.log
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
DirsAllowed          = .
CallstackOnException = 2

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

;[Plugins]
;LoadPath = ./plugin
;Load1 = plain, wikiv

" > virtuoso.ini
  virtuoso_start
}

vad_create() {
  mydir=`pwd`
  cd $HOME/binsrc/vad
  do_command_safe $DSN "load vad_make.sql"
  cd $mydir
  do_command_safe $DSN "DB.DBA.VAD_PACK('$STICKER_NAME', '.', 'ods_wiki_dav.vad')"
  do_command_safe $DSN "commit work"
  do_command_safe $DSN "checkpoint"
}

vad_check() {
  LOG "VAD installation check..."
  do_command_safe $DSN "VAD_INSTALL('ods_wiki_dav.vad', 0);"    
  LOG "VAD uninstallation check..."
  do_command_safe $DSN "VAD_UNINSTALL('wiki/$VERSION');"    
}

virtuoso_shutdown
directory_clean
version_init
directory_init
virtuoso_init
sticker_init
vad_create
virtuoso_shutdown
echo `pwd`
chmod 644 ods_wiki_dav.vad

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

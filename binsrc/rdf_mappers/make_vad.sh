#!/bin/sh
#
#  $Id$
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



# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL


# check version_init procedure below
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
VAD_NAME="rdf_mappers"
VAD_PKG_NAME="rdf_mappers"
VAD_DESC="RDF Mappers"
LOGFILE="${LOGDIR}/make_"$VAD_PKG_NAME"_vad.log"
VAD_NAME_DEVEL="$VAD_PKG_NAME"_filesystem.vad
VAD_NAME_RELEASE="$VAD_PKG_NAME"_dav.vad
NEED_VERSION=05.10.3038
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
      VERSION=`cat version.tmp | awk ' BEGIN { cnt=583 } { cnt = cnt + $1 } END { printf "1.%02.02f", cnt/100 }'`
      rm -f version.tmp
      echo "$VERSION" > vad_version
  fi
}

do_command_safe () {
  _dsn=$1
  command=$2
  shift
  shift
  echo "+ " $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*	>> $LOGFILE
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
      echo "------------ SQL ERROR -------------"	>> $LOGFILE
      echo "$msg"	>> $LOGFILE
      echo "------------------------------------"	>> $LOGFILE
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
  echo "+ " $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*	>> $LOGFILE
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
  mkdir vad/code/rdf_mappers
  mkdir vad/vsp
  mkdir vad/vsp/rdf_mappers
  mkdir vad/vsp/rdf_mappers/xslt/
  mkdir vad/vsp/rdf_mappers/xslt/main/
  mkdir vad/vsp/rdf_mappers/ontologies/
  mkdir vad/vsp/rdf_mappers/ontologies/xbrl/
  mkdir vad/vsp/rdf_mappers/ontologies/owl/

  mkdir vad/vsp/rdf_mappers/rdfdesc
  mkdir vad/vsp/rdf_mappers/rdfdesc/images
  mkdir vad/vsp/rdf_mappers/rdfdesc/statics
  mkdir vad/vsp/rdf_mappers/rdfdesc/style

  mkdir vad/vsp/rdf_mappers/rdfdesc/oat
  mkdir vad/vsp/rdf_mappers/rdfdesc/oat/images
  mkdir vad/vsp/rdf_mappers/rdfdesc/oat/styles
  mkdir vad/vsp/rdf_mappers/rdfdesc/oat/xslt

  mkdir vad/vsp/rdf_mappers/sponger_front_page
  mkdir vad/vsp/rdf_mappers/sponger_front_page/skin
  mkdir vad/vsp/rdf_mappers/sponger_front_page/skin/i
  mkdir vad/vsp/rdf_mappers/sponger_front_page/skin/ss

  for f in `find rdfdesc -type f | grep -v "/CVS/" | grep -v "\.sql"`
  do
     cp $f vad/vsp/rdf_mappers/$f  
  done


  #cp *.sql vad/code/rdf_mappers

  cp rdf_mappers.sql vad/code/rdf_mappers
  cp rdf_mappers_drop.sql vad/code/rdf_mappers
  cp sponger_coref_post_process.sql vad/code/rdf_mappers
  cp virt_rdf_label.sql vad/code/rdf_mappers

  cp data/*.sql vad/code/rdf_mappers
  cp data/*.gz vad/code/rdf_mappers
  cp rdfdesc/*.sql vad/code/rdf_mappers
  cp xslt/main/*.xsl vad/vsp/rdf_mappers/xslt/main/
  cp ontologies/xbrl/*.owl vad/vsp/rdf_mappers/ontologies/xbrl/
  cp ontologies/owl/*.owl vad/vsp/rdf_mappers/ontologies/owl/

  cp sponger_front_page/* vad/vsp/rdf_mappers/sponger_front_page/

  cp sponger_front_page/skin/i/* vad/vsp/rdf_mappers/sponger_front_page/skin/i/
  cp sponger_front_page/skin/ss/* vad/vsp/rdf_mappers/sponger_front_page/skin/ss/

  #
  #  GZip the ontologies sources to save space
  #
  gzip -V 2>/dev/null 1>/dev/null
  if test $? -eq 0
  then
      gzip vad/vsp/rdf_mappers/ontologies/xbrl/*.owl
      gzip vad/vsp/rdf_mappers/ontologies/owl/*.owl
  else
      echo "GZip must be installed" 
      exit 1
  fi

  #
  #  Install minimal OAT toolkit
  #
  for i in loader.js animation.js slidebar.js resize.js ajax.js json.js
  do
      cp ../oat/toolkit/$i vad/vsp/rdf_mappers/rdfdesc/oat/
  done
  cp ../oat/images/*.png vad/vsp/rdf_mappers/rdfdesc/oat/images/
  cp ../oat/images/*.gif vad/vsp/rdf_mappers/rdfdesc/oat/images/
  cp ../oat/styles/*.css vad/vsp/rdf_mappers/rdfdesc/oat/styles/
  cp ../oat/xslt/*.xsl vad/vsp/rdf_mappers/rdfdesc/oat/xslt/
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
  echo "    <prop name=\"Copyright\" value=\"(C) 1998-2017 OpenLink Software\"/>" >> $STICKER
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
  echo "	 signal ('FATAL', 'The $VAD_DESC package requires server version $NEED_VERSION or greater'); " >> $STICKER
  echo "      } " >> $STICKER
  echo "    if (__proc_exists ('__PROC_PARAMS_NUM', 2) is null) " >> $STICKER
  echo "      { " >> $STICKER
  echo "         result ('ERROR', 'The $VAD_DESC package requires new server version'); " >> $STICKER
  echo "         signal ('FATAL', 'The $VAD_DESC package requires new server version'); " >> $STICKER
  echo "      } " >> $STICKER
  echo "  ]]></sql>" >> $STICKER
  echo "  <sql purpose=\"post-install\">" >> $STICKER
  echo "	; " >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "</procedures>" >> $STICKER
  echo "<ddls>" >> $STICKER
  echo "  <sql purpose=\"post-install\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "        set_qualifier ('DB');" >> $STICKER
if [ "$ISDAV" = "1" ] ; then
  echo "	registry_set('_"$VAD_NAME"_path_', 'virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:/DAV/VAD/$VAD_NAME/');" >> $STICKER
else
  echo "	registry_set('_"$VAD_NAME"_path_', 'file://vad/vsp/$VAD_NAME/');" >> $STICKER
fi
  echo "    DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH_CODE"$VAD_NAME/virt_rdf_label.sql', 0, 'report', $ISDAV);" >> $STICKER
  echo "    DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH_CODE"$VAD_NAME/description.sql', 0, 'report', $ISDAV);" >> $STICKER
  echo "    DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH_CODE"$VAD_NAME/yelp_categories.sql', 0, 'report', $ISDAV);" >> $STICKER
  echo "	DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH_CODE"$VAD_NAME/rdf_mappers.sql', 0, 'report', $ISDAV);" >> $STICKER
  echo "    DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH_CODE"$VAD_NAME/sponger_coref_post_process.sql', 0, 'report', $ISDAV);" >> $STICKER
  echo "	DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH_CODE"$VAD_NAME/oai_servers.sql', 0, 'report', $ISDAV);" >> $STICKER
  echo "    DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH_CODE"$VAD_NAME/iso_country_codes.sql', 0, 'report', $ISDAV);" >> $STICKER
  echo "    DB.DBA.VHOST_REMOVE (lpath=>'/rdfdesc');" >> $STICKER
if [ "$ISDAV" = "1" ] ; then
  echo "    DB.DBA.VHOST_DEFINE (lpath=>'/rdfdesc', ppath=>'/DAV/VAD/$VAD_NAME/rdfdesc/', is_dav=>1, vsp_user=>'dba');" >> $STICKER
else
  echo "    DB.DBA.VHOST_DEFINE (lpath=>'/rdfdesc', ppath=>'/vad/vsp/$VAD_NAME/rdfdesc/', is_dav=>0, vsp_user=>'dba');" >> $STICKER
fi  
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "  <sql purpose='pre-uninstall'>" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "	DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH_CODE"$VAD_NAME/rdf_mappers_drop.sql', 0, 'report', $ISDAV);" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
#  echo "  <sql purpose='post-uninstall'>" >> $STICKER
#  echo "  </sql>" >> $STICKER
  echo "</ddls>" >> $STICKER
  echo "<resources>" >> $STICKER

  echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"$VAD_NAME/rdf_mappers.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"$VAD_NAME/sponger_coref_post_process.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"$VAD_NAME/oai_servers.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"$VAD_NAME/yelp_categories.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"$VAD_NAME/iso_country_codes.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"$VAD_NAME/rdf_mappers_drop.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"$VAD_NAME/description.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"$VAD_NAME/virt_rdf_label.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"$VAD_NAME/nyt_people.nt.gz\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER

  for file in `find xslt/main -type f -print | grep -v CVS | sort`
  do
      echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"$VAD_NAME/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  done

  for file in `find ontologies/xbrl -type f -print | grep -v CVS | sort`
  do
      echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"$VAD_NAME/$file.gz\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  done

  for file in `find ontologies/owl -type f -print | grep -v CVS | grep -v '.n3' | grep -v '.ttl'| sort`
  do
      echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"$VAD_NAME/$file.gz\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  done

  for file in `find rdfdesc -type f -print | grep -v CVS | grep -v ".sql" | sort`
  do
      echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"$VAD_NAME/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  done

  for file in `find vad/vsp/rdf_mappers/rdfdesc/oat -type f -print | grep -v CVS | sort`
  do
      name=`echo $file | cut -b21-`
      echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"$VAD_NAME/$name\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  done

  for file in `find sponger_front_page -type f -print | grep -v CVS | sort`
  do
      echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"$VAD_NAME/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  done

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

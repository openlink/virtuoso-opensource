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


# check version_init procedure below
VERSION="1.05.05"
LOGDIR=`pwd`
LOGFILE="${LOGDIR}/make_bpel_vad.log"
STICKER_DAV="vad_dav.xml"
STICKER_FS="vad_fs.xml"
PACKDATE=`date +"%Y-%m-%d %H:%M"`
SERVER=${SERVER-}
THOST=${THOST-localhost}
TPORT=${TPORT-8445}
PORT=${PORT-1940}
ISQL=${ISQL-isql}
VAD_NAME="bpel4ws"
VAD_PKG_NAME="bpel"
VAD_NAME_DEVEL="$VAD_PKG_NAME"_filesystem.vad
VAD_NAME_RELEASE="$VAD_PKG_NAME"_dav.vad
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
  VERSION=`cat version.tmp | awk ' BEGIN { cnt=9 } { cnt = cnt + $1 } END { printf "1.%02.02f", cnt/100 }'`
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
  mkdir vad/code/bpel4ws/
  mkdir vad/code/bpel4ws/1.0/
  cp *.sql vad/code/bpel4ws/1.0/

  mkdir vad/vsp
  mkdir vad/vsp/bpel4ws/
  mkdir vad/vsp/bpel4ws/1.0/
  mkdir vad/vsp/bpel4ws/1.0/help/
  mkdir vad/vsp/bpel4ws/1.0/i/
  mkdir vad/vsp/bpeldemo/
  mkdir vad/vsp/bpeldemo/echo
  mkdir vad/vsp/bpeldemo/fi
  mkdir vad/vsp/bpeldemo/LoanFlow
  mkdir vad/vsp/bpeldemo/SecLoan
  mkdir vad/vsp/bpeldemo/RMLoan
  mkdir vad/vsp/bpeldemo/SecRMLoan
  mkdir vad/vsp/bpeldemo/sqlexec
  mkdir vad/vsp/bpeldemo/UseCases
  mkdir vad/vsp/bpeldemo/java_exec
  mkdir vad/vsp/bpeldemo/clr_exec
  mkdir vad/vsp/bpeldemo/processXSLT
  mkdir vad/vsp/bpeldemo/processXSQL
  mkdir vad/vsp/bpeldemo/processXQuery

  # APPLICATION
  cp *.vspx vad/vsp/bpel4ws/1.0/
  cp *.vsp vad/vsp/bpel4ws/1.0/
  cp *.xsd vad/vsp/bpel4ws/1.0/
  cp *.xsl vad/vsp/bpel4ws/1.0/
  cp *.gif vad/vsp/bpel4ws/1.0/
  cp *.jpg vad/vsp/bpel4ws/1.0/
  cp *.css vad/vsp/bpel4ws/1.0/

  # HELP
  cp help/* vad/vsp/bpel4ws/1.0/help/

  # Icons
  cp i/* vad/vsp/bpel4ws/1.0/i/

  # SAMPLES
  cp tests/echo/echo.* vad/vsp/bpeldemo/echo
  cp tests/echo/bpel.xml vad/vsp/bpeldemo/echo
  cp tests/echo/options.xml vad/vsp/bpeldemo/echo

  cp tests/fi/fi.* vad/vsp/bpeldemo/fi
  cp tests/fi/fi_wsdl.vsp vad/vsp/bpeldemo/fi
  cp tests/fi/service.vsp vad/vsp/bpeldemo/fi
  cp tests/fi/options.xml vad/vsp/bpeldemo/fi
  cp tests/fi/bpel.xml vad/vsp/bpeldemo/fi

  cp -f tests/LoanFlow/* vad/vsp/bpeldemo/LoanFlow 2>/dev/null
  cp -f tests/interop/site/SecLoan/* vad/vsp/bpeldemo/SecLoan 2>/dev/null
  cp -f tests/interop/site/RMLoan/* vad/vsp/bpeldemo/RMLoan 2>/dev/null
  cp -f tests/interop/site/SecRMLoan/* vad/vsp/bpeldemo/SecRMLoan 2>/dev/null
  cp -f tests/sqlexec/* vad/vsp/bpeldemo/sqlexec 2>/dev/null
  cp tests/index.xml vad/vsp/bpeldemo
  cp tests/index.vsp vad/vsp/bpeldemo
  cp -f tests/interop/UseCases/* vad/vsp/bpeldemo/UseCases 2>/dev/null
  cp tests/processXSLT/* vad/vsp/bpeldemo/processXSLT 2>/dev/null
  cp tests/processXSQL/* vad/vsp/bpeldemo/processXSQL 2>/dev/null
  cp tests/processXQuery/* vad/vsp/bpeldemo/processXQuery 2>/dev/null

  cp tests/fault1/java* vad/vsp/bpeldemo/java_exec
  cd vad/vsp/bpeldemo/java_exec
  mv java_exec_bpel.xml bpel.xml
  mv java_exec.xml options.xml
  mv java_exec_desc.xml java_exec.xml
  cd ../../../../

  cp tests/fault1/clr* vad/vsp/bpeldemo/clr_exec
  cd vad/vsp/bpeldemo/clr_exec
  mv clr_exec_bpel.xml bpel.xml
  mv clr_exec.xml options.xml
  mv clr_exec_desc.xml clr_exec.xml
  cd ../../../../


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
    PPATH="/DAV/VAD/bpel4ws/1.0/"
    DPPATH="/DAV/VAD"
  else
    BASE_PATH_HTTP="./vad/vsp/"
    BASE_PATH_CODE="./vad/vsp/"
    TYPE="http"
    STICKER=$STICKER_FS
    PPATH="/vad/vsp/bpel4ws/1.0/"
    DPPATH="/vad/vsp"
  fi
  LOG "VAD Sticker $STICKER creation..."
  echo "<?xml version=\"1.0\" encoding=\"ASCII\"?>" > $STICKER
  echo "<!DOCTYPE sticker SYSTEM \"vad_sticker.dtd\">" >> $STICKER
  echo "<sticker version=\"1.0.010505A\" xml:lang=\"en-UK\">" >> $STICKER
  echo "<caption>" >> $STICKER
  echo "  <name package=\"bpel4ws\">" >> $STICKER
  echo "    <prop name=\"Title\" value=\"BPEL4WS\"/>" >> $STICKER
  echo "    <prop name=\"Developer\" value=\"OpenLink Software\"/>" >> $STICKER
  echo "    <prop name=\"Copyright\" value=\"(C) 1998-2018 OpenLink Software\"/>" >> $STICKER
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
  echo "  <sql purpose=\"post-install\">" >> $STICKER
  #echo "	DB.DBA.VAD_LOAD_SQL_FILE('./vad/code/bpel4ws/1.0/postinstall.sql', 0, 'report', 0);" >> $STICKER
  #  echo " 	BPEL.BPEL.upload_script ('file://vad/vsp/bpel4ws/1.0/samples/echo/','echo.bpel','echo.wsdl');" >> $STICKER
  echo "	; " >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "</procedures>" >> $STICKER
  echo "<ddls>" >> $STICKER
  echo "  <sql purpose=\"post-install\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "  	DB.DBA.USER_CREATE ('BPEL', uuid(), vector ('DISABLED', 1));" >> $STICKER
  echo "  	EXEC ('grant all privileges to BPEL');" >> $STICKER
  echo "  	EXEC ('grant execute on DB.DBA.WSRMSequence to BPEL');" >> $STICKER
  echo "  	EXEC ('grant execute on DB.DBA.WSRMSequenceTerminate to BPEL');" >> $STICKER
  echo "  	EXEC ('grant execute on DB.DBA.WSRMAckRequested to BPEL');" >> $STICKER
  echo "	user_set_qualifier ('BPEL', 'BPEL');" >> $STICKER
  echo "	VHOST_REMOVE (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/BPEL');" >> $STICKER
  echo "	vhost_define (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/BPEL',ppath=>'/SOAP/',soap_user=>'BPEL');" >> $STICKER
  echo "	VHOST_REMOVE (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/BPELGUI');" >> $STICKER
  echo "	vhost_define (vhost=>'*ini*', lhost=>'*ini*', lpath=>'/BPELGUI/', ppath=>'"$PPATH"', vsp_user=>'BPEL', def_page=>'main_tabs.vspx', is_dav=>$ISDAV);" >> $STICKER
  echo "	VHOST_REMOVE (lpath=>'/BPELDemo');" >> $STICKER
  echo "	vhost_define (lpath=>'/BPELDemo', ppath=>'"$DPPATH/bpeldemo/"', vsp_user=>'dba', def_page=>'index.vsp', is_dav=>$ISDAV);" >> $STICKER
  echo "        registry_set('_"$VAD_NAME"_path_', 'file:/vad/vsp/bpel4ws/1.0/');" >> $STICKER
  echo "        registry_set('_"$VAD_NAME"_version_', '$VERSION');" >> $STICKER
  echo "        registry_set('_"$VAD_NAME"_build_', '$PACKDATE');" >> $STICKER
  echo "        registry_set('__external_xsql_xslt', '1');" >> $STICKER
  echo "        set_qualifier ('DB');" >> $STICKER
#  echo "	DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH_CODE"bpel4ws/1.0/drop.sql', 0, 'report', $ISDAV);" >> $STICKER
  echo "	DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH_CODE"bpel4ws/1.0/bpel_ddl.sql', 0, 'report', $ISDAV);" >> $STICKER
  echo "	DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH_CODE"bpel4ws/1.0/bpel_eng.sql', 1, 'report', $ISDAV);" >> $STICKER
  echo "	DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH_CODE"bpel4ws/1.0/xsql.sql', 1, 'report', $ISDAV);" >> $STICKER
  echo "	DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH_CODE"bpel4ws/1.0/filesystem.sql', 1, 'report', $ISDAV);" >> $STICKER
if [ "$ISDAV" = "1" ] ; then
  echo "	EXEC ('create procedure BPEL.BPEL.res_base_uri () { return \'virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:/DAV/VAD/\'; }' );" >> $STICKER
else
  echo "	EXEC ('create procedure BPEL.BPEL.res_base_uri () { return \'file://vad/vsp/\'; }' );" >> $STICKER
fi
  echo "        set_qualifier ('BPEL');" >> $STICKER
  echo "	DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH_CODE"bpel4ws/1.0/bpel_intrp.sql', 1, 'report', $ISDAV);" >> $STICKER
  echo "        set_qualifier ('DB');" >> $STICKER
  echo "	DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH_CODE"bpel4ws/1.0/install.sql', 1, 'report', $ISDAV);" >> $STICKER
  echo "	DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH_CODE"bpel4ws/1.0/process.sql', 1, 'report', $ISDAV);" >> $STICKER
  echo "	BPEL.BPEL.java_init ();" >> $STICKER
  echo "        result ('00000', 'GUI is accesible via http://host:port/BPELGUI');" >> $STICKER
  echo "        result ('00000', 'Quick Start is available from http://host:port/BPELGUI/start.vsp');" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "  <sql purpose='pre-uninstall'>" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "        set_qualifier ('DB');" >> $STICKER
  echo "	VHOST_REMOVE (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/BPEL');" >> $STICKER
  echo "	VHOST_REMOVE (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/BPELGUI');" >> $STICKER
  echo "	VHOST_REMOVE (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/BPELDemo');" >> $STICKER
  echo "	DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH_CODE"bpel4ws/1.0/drop_prc.sql', 1, 'report', $ISDAV);" >> $STICKER
  echo "	DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH_CODE"bpel4ws/1.0/drop.sql', 1, 'report', $ISDAV);" >> $STICKER
# echo "  	DB.DBA.USER_DROP ('BPEL');" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "  <sql purpose='post-uninstall'>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "</ddls>" >> $STICKER
  echo "<resources>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"bpel4ws/1.0/bpel_ddl.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"bpel4ws/1.0/bpel_eng.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"bpel4ws/1.0/bpel_intrp.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"bpel4ws/1.0/install.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER
  #echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"bpel4ws/1.0/postinstall.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"bpel4ws/1.0/process.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"bpel4ws/1.0/drop.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"bpel4ws/1.0/filesystem.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"bpel4ws/1.0/xsql.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"code\" target_uri=\"bpel4ws/1.0/drop_prc.sql\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER

  for css in `ls *.css`; do
    echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/$css\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>"  >> $STICKER
  done
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpelstatus.xsl\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/raw.xsl\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpelcomp.xsl\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpelwsdl.xsl\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpelexpn.xsl\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpeloper.xsl\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpelmsg.xsl\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpelmsgen.xsl\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/genwsdl.xsl\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/xsql2virtPL.xsl\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpel.vsp\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpel.xsd\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpelv.xsd\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpelx.xsd\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/wsdl.xsd\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/xsql.xsd\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/debug.vsp\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/asyncall.vsp\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/time.vsp\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/script.xsl\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/process.xsl\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/common.xsl\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpel_style.xsl\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/activity.xsl\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/virtuoso_splash.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/script.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/process.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/message.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/main_tabs.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/instances.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/configure.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpel_navigation_bar.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpel_login.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpel_decor.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/activity.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/view.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpel_confirm.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/browser.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/upload_new.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/incoming.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/imsgpr.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/omsgpr.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/rmsgpr.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/plus.gif\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/minus.gif\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/status.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/plinks.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/plinks_props.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/wss_keys.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpel_banner.jpg\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpel_style_new.xsl\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpel_plinks.xsl\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/reports.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/statendp.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/statproc.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpel_ui_bpelwsdl_edit.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpel_ui_bpelwsdl_register.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpel_ui_import2.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpel_ui_import.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpelimport.xsl\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/bpel_login_new.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help.xsl\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/error.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/process_activity.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/process_audit.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/process_graph.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/process_list.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/process_redef.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/process_redefine.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/process_status.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/process_upload.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/processes_list.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/configure.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/instances.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/confirm.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/imsgpr.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/incoming.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/message.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/omsgpr.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/rmsgpr.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/plinks_props.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/plinks.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/reports.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/statendp.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/statproc.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/wss_keys.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/help/browser.xml\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/help_24.gif\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/ref_24.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/first_16.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/last_16.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/next_16.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/previous_16.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/cancl_16.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/save_16.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/close_16.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/ref_16.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/del_16.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/back_16.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/edit_record_16.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/import_data_16.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/prefs_16.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/sinfo_16.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/find_16.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/tools_16.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/1pixdot.gif\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/blnav.jpg\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/blunav2.gif\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/blunav2.jpg\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/blunav3.jpg\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/bpelheader350.jpg\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/brnznavlv2.jpg\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/brnznavlv3.jpg\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/bronznav.jpg\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/oplbpel350.jpg\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/slnav2.jpg\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/slvnav.jpg\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/slvnav2.jpg\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/user_16.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/home.vspx\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/about_24.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/confg_24.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/favs_24.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/open_24.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/opts_24.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/srch_24.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/web_24.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/PoweredByVirtuoso.gif\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/stop_32.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/i/vglobe_16.png\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER

  echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpel4ws/1.0/start.vsp\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  for file in `find vad/vsp/bpeldemo -type f -print | sort`
  do
      name=`echo "$file" | cut -b18-`
      echo "  <file type=\"$TYPE\" source=\"http\" target_uri=\"bpeldemo/$name\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
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

BPELGRANTS="DB.DBA.WSDL_EXPAND
DB.DBA.XML_URI_RESOLVE_LIKE_GET
DB.DBA.XML_URI_GET
BPEL.BPEL.schedule_request
DB.DBA.XML_URI_GET_STRING
DB.DBA.FILE_TO_STRING"


grant_exec_to_all() {
	grep 'procedure BPEL.BPEL.' vad/code/bpel4ws/1.0/*.sql | awk ' { print "grant execute on "$3" to BPEL;" } ' > vad/code/bpel4ws/1.0/postinstall.sql
	for gr in $BPELGRANTS; do
		echo "grant execute on $gr to BPEL;" >> vad/code/bpel4ws/1.0/postinstall.sql
	done
	cat >> vad/code/bpel4ws/1.0/postinstall.sql <<END_PROC
create procedure BPEL.BPEL._encode_base64 (in str varchar) {return encode_base64 (str);	};
grant execute on BPEL.BPEL._encode_base64 to public;
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:encode_base64','BPEL.BPEL._encode_base64');
grant execute on DB.DBA.TRANSFORM_XML_TO_TEXT to public;
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:transform_xml_to_text','DB.DBA.TRANSFORM_XML_TO_TEXT');
END_PROC
}

vad_create() {
  STICKER=$1
  V_NAME=$2
  mydir=`pwd`
  grant_exec_to_all
  do_command_safe $DSN "DB.DBA.VAD_PACK('$STICKER', '.', '$V_NAME')"
  do_command_safe $DSN "commit work"
  do_command_safe $DSN "checkpoint"
}

vad_check() {
  LOG "VAD installation check..."
  do_command_safe $DSN "VAD_INSTALL('bpel_dav.vad', 0);"
  LOG "VAD uninstallation check..."
  do_command_safe $DSN "VAD_UNINSTALL('bpel4ws/$VERSION');"
}
#sticker_init 1
#sticker_init 0
#vad_create $STICKER_FS $VAD_NAME_DEVEL
#vad_create $STICKER_DAV $VAD_NAME_RELEASE
#exit
BANNER "STARTED BPEL4WS PACKAGING"

$ISQL -? 2>/dev/null 1>/dev/null 
if [ $? -eq 127 ] ; then
    LOG "***ABORTED: BPEL4WS PACKAGING, isql is not available"
    exit 1
fi
$SERVER -? 2>/dev/null 1>/dev/null 
if [ $? -eq 127 ] ; then
    LOG "***ABORTED: BPEL4WS PACKAGING, server is not available"
    exit 1
fi
    

virtuoso_shutdown
directory_clean
directory_init
virtuoso_init
version_init
sticker_init 1
sticker_init 0
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

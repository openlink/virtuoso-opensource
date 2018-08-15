#!/bin/sh
# $Id$

# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL


LOGDIR=`pwd`
LOGFILE="${LOGDIR}/make_tutorial_vad.output"
STICKER_DAV="make_tutorial_dav_vad.xml"
STICKER_FS="make_tutorial_fs_vad.xml"

SERVER=${SERVER-}
THOST=${THOST-localhost}
TPORT=${TPORT-8440}
PORT=${PORT-1940}
ISQL=${ISQL-isql}
DSN="$HOST:$PORT"
HOST_OS=`uname -s | grep WIN`
NEED_VERSION=04.00.2803
VERSION=1.00.0007  # see automatic versioning bellow 

BUILDDATE=`date +"%Y-%m-%d"`

if [ "x$1" = "xdev" ]
then
  DEV="1"
fi

if [ "x$HOST_OS" != "x" ]
then
  TEMPFILE="`cygpath -m $TMP/isql.$$`"
  STICKER_DAV="`cygpath -m $STICKER_DAV`"
  STICKER_FS="`cygpath -m $STICKER_FS`"
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
  echo "+ " $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*	>> $LOGFILE
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
  mkdir vad_files/vsp/tutorial

  for file in `cat root_filelist`
  do
    cp $file vad_files/vsp/tutorial/$file
  done

  for dir in `find . -type d -print | LC_ALL=C sort | grep -v "^\.$" | grep -v CVS | grep -v vad_files | grep -v bpeldemo`
  do
    mkdir vad_files/vsp/tutorial/$dir
  done

  for dir in `find . -type d | grep "\\./[^/]*$"  | grep -v CVS | grep -v vad_files | grep -v bpeldemo`
  do
	  for file in `find $dir -type f -print | LC_ALL=C sort | grep -v CVS`
	  do
	    cp $file vad_files/vsp/tutorial/$file
	  done
	done

#get bpeldemo
  #
  # XXX: this is true only if bpel vad is done before running this script.
  # must be fixed to do not depend of bpel's make_vad script run
  mkdir vad_files/vsp/tutorial/bpeldemo
  mkdir vad_files/vsp/tutorial/bpeldemo/echo
  mkdir vad_files/vsp/tutorial/bpeldemo/fi
  mkdir vad_files/vsp/tutorial/bpeldemo/LoanFlow 		
  mkdir vad_files/vsp/tutorial/bpeldemo/SecLoan
  mkdir vad_files/vsp/tutorial/bpeldemo/RMLoan
  mkdir vad_files/vsp/tutorial/bpeldemo/SecRMLoan
  mkdir vad_files/vsp/tutorial/bpeldemo/sqlexec
  mkdir vad_files/vsp/tutorial/bpeldemo/UseCases
  mkdir vad_files/vsp/tutorial/bpeldemo/java_exec
  mkdir vad_files/vsp/tutorial/bpeldemo/clr_exec
  mkdir vad_files/vsp/tutorial/bpeldemo/processXSLT
  mkdir vad_files/vsp/tutorial/bpeldemo/processXQuery
  mkdir vad_files/vsp/tutorial/bpeldemo/processXSQL

  cp ../bpel/tests/echo/echo.* vad_files/vsp/tutorial/bpeldemo/echo
  cp ../bpel/tests/echo/bpel.xml vad_files/vsp/tutorial/bpeldemo/echo
  cp ../bpel/tests/echo/options.xml vad_files/vsp/tutorial/bpeldemo/echo

  cp -f ../dav/DET_RDFData.sql vad_files/vsp/tutorial


  cp ../bpel/tests/fi/fi.* vad_files/vsp/tutorial/bpeldemo/fi
  cp ../bpel/tests/fi/fi_wsdl.vsp vad_files/vsp/tutorial/bpeldemo/fi
  cp ../bpel/tests/fi/service.vsp vad_files/vsp/tutorial/bpeldemo/fi
  cp ../bpel/tests/fi/options.xml vad_files/vsp/tutorial/bpeldemo/fi
  cp ../bpel/tests/fi/bpel.xml vad_files/vsp/tutorial/bpeldemo/fi

  cp -f ../bpel/tests/LoanFlow/* vad_files/vsp/tutorial/bpeldemo/LoanFlow 2>/dev/null
  cp -f ../bpel/tests/interop/site/SecLoan/* vad_files/vsp/tutorial/bpeldemo/SecLoan 2>/dev/null
  cp -f ../bpel/tests/interop/site/RMLoan/* vad_files/vsp/tutorial/bpeldemo/RMLoan 2>/dev/null
  cp -f ../bpel/tests/interop/site/SecRMLoan/* vad_files/vsp/tutorial/bpeldemo/SecRMLoan 2>/dev/null
  cp -f ../bpel/tests/sqlexec/* vad_files/vsp/tutorial/bpeldemo/sqlexec 2>/dev/null
  cp ../bpel/tests/index.xml vad_files/vsp/tutorial/bpeldemo
  cp -f ../bpel/tests/interop/UseCases/* vad_files/vsp/tutorial/bpeldemo/UseCases 2>/dev/null
  cp ../bpel/tests/processXSLT/* vad_files/vsp/tutorial/bpeldemo/processXSLT 2>/dev/null
  cp ../bpel/tests/processXSQL/* vad_files/vsp/tutorial/bpeldemo/processXSQL 2>/dev/null
  cp ../bpel/tests/processXQuery/* vad_files/vsp/tutorial/bpeldemo/processXQuery 2>/dev/null

  cp ../bpel/tests/fault1/java* vad_files/vsp/tutorial/bpeldemo/java_exec
  cd vad_files/vsp/tutorial/bpeldemo/java_exec
  mv java_exec_bpel.xml bpel.xml
  mv java_exec.xml options.xml
  mv java_exec_desc.xml java_exec.xml
  cd $LOGDIR

  cp ../bpel/tests/fault1/clr* vad_files/vsp/tutorial/bpeldemo/clr_exec
  cd vad_files/vsp/tutorial/bpeldemo/clr_exec
  mv clr_exec_bpel.xml bpel.xml
  mv clr_exec.xml options.xml
  mv clr_exec_desc.xml clr_exec.xml
  cd $LOGDIR
#  cd ../bpel/vad/vsp/bpeldemo
#  for dir in `find . -type d -print | LC_ALL=C sort | grep -v "^\.$" | grep -v CVS`
#  do
#    mkdir $LOGDIR/vad_files/vsp/tutorial/bpeldemo/$dir
#  done

#  for file in `find . -type f -print | LC_ALL=C sort | grep -v CVS`
#  do
#    cp $file $LOGDIR/vad_files/vsp/tutorial/bpeldemo/$file
#  done
  cd $LOGDIR

#get xqdemo
  mkdir vad_files/vsp/tutorial/xml/xq_s_1/xqdemo
  mkdir vad_files/vsp/tutorial/xml/xq_s_1/xqdemo/data

  cd $HOME/binsrc/samples/xquery
  for file in `find . -type f -print | LC_ALL=C sort | grep -v CVS`
  do
    cp $file $LOGDIR/vad_files/vsp/tutorial/xml/xq_s_1/xqdemo/$file
  done

  cd $HOME/binsrc/tests/wb/inputs/XqW3cUseCases
  for file in `find . -type f -print | LC_ALL=C sort | grep -v CVS`
  do
    cp $file $LOGDIR/vad_files/vsp/tutorial/xml/xq_s_1/xqdemo/data/$file
  done

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
  if [ "$ISDAV" = "1" ] ; then
    BASE_PATH="/DAV/VAD"
    TYPE="dav"
    XDDLSQL="xddl_dav.sql"
    STICKER=$STICKER_DAV
  else
    BASE_PATH="/vad/vsp"
    TYPE="http"
    STICKER=$STICKER_FS
    XDDLSQL="xddl_filesystem.sql"
  fi
  LOG "VAD Tutorial sticker $STICKER creation..."
  echo "<?xml version=\"1.0\" encoding=\"ASCII\"?>" > $STICKER
  echo "<!DOCTYPE sticker SYSTEM \"vad_sticker.dtd\">" >> $STICKER
  echo "<sticker version=\"1.0.010505A\" xml:lang=\"en-UK\">" >> $STICKER
  echo "<caption>" >> $STICKER
  echo "  <name package=\"tutorial\">" >> $STICKER
  echo "    <prop name=\"Title\" value=\"Virtuoso Developer Tutorial\"/>" >> $STICKER
  echo "    <prop name=\"Developer\" value=\"OpenLink Software\"/>" >> $STICKER
  echo "    <prop name=\"Copyright\" value=\"(C) 1998-2018 OpenLink Software\"/>" >> $STICKER
  echo "    <prop name=\"Download\" value=\"http://www.openlinksw.com/virtuoso\"/>" >> $STICKER
  echo "    <prop name=\"Download\" value=\"http://www.openlinksw.co.uk/virtuoso\"/>" >> $STICKER
  echo "  </name>" >> $STICKER
  echo "  <version package=\"$VERSION\">" >> $STICKER
  echo "    <prop name=\"Release Date\" value=\""`date +"%Y-%m-%d %H:%M"`"\"/>" >> $STICKER
  echo "    <prop name=\"Build\" value=\"Release\"/>" >> $STICKER
  echo "  </version>" >> $STICKER
  echo "</caption>" >> $STICKER
#  echo "<dependencies>" >> $STICKER
#  echo "  <require>" >> $STICKER
#  echo "    <name package=\"Demo\"/>" >> $STICKER
#  echo "    <versions_later package=\"1.00.00\"/>" >> $STICKER
#  echo "  </require>" >> $STICKER
#  echo "</dependencies>" >> $STICKER
  echo "<ddls>" >> $STICKER
  echo "  <sql purpose=\"pre-install\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "    update WS.WS.SYS_DAV_COL set COL_DET=null where COL_ID = DAV_SEARCH_ID('/DAV/VAD/tutorial/rdfview/rd_v_1/', 'C');" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "  <sql purpose=\"post-install\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "    DB.DBA.VAD_LOAD_SQL_FILE ('$BASE_PATH/tutorial/setup_tutorial.sql', 1, 'report', $ISDAV);" >> $STICKER
  echo "    -- Add a virtual directory -------------------" >> $STICKER
  echo "    DB.DBA.VHOST_REMOVE(lpath=>'/tutorial',del_vsps => 1);" >> $STICKER
  echo "    DB.DBA.VHOST_DEFINE(" >> $STICKER
  echo "        lpath    => '/tutorial'," >> $STICKER
  echo "        ppath    => '$BASE_PATH/tutorial/'," >> $STICKER
  echo "        is_dav   => $ISDAV," >> $STICKER
  echo "        vsp_user => 'dba'," >> $STICKER
  echo "        is_brws  => 1," >> $STICKER
  echo "        def_page => 'index.vsp'" >> $STICKER
  echo "    )" >> $STICKER
  echo "    ;" >> $STICKER
  echo "    DB.DBA.VHOST_REMOVE (lhost=>'*sslini*', vhost=>'*sslini*', lpath=>'/tutorial', del_vsps => 1);" >> $STICKER
  echo "    DB.DBA.VHOST_DEFINE(" >> $STICKER
  echo "        lhost    => '*sslini*'," >> $STICKER
  echo "        vhost    => '*sslini*'," >> $STICKER
  echo "        lpath    => '/tutorial'," >> $STICKER
  echo "        ppath    => '$BASE_PATH/tutorial/'," >> $STICKER
  echo "        is_dav   => $ISDAV," >> $STICKER
  echo "        vsp_user => 'dba'," >> $STICKER
  echo "        is_brws  => 1," >> $STICKER
  echo "        def_page => 'index.vsp'" >> $STICKER
  echo "    )" >> $STICKER
  echo "    ;" >> $STICKER
  echo "    DB.DBA.VHOST_REMOVE(lpath=>'/tutorial/webid',del_vsps => 1);" >> $STICKER
  echo "    DB.DBA.VHOST_DEFINE(" >> $STICKER
  echo "        lpath    => '/tutorial/webid'," >> $STICKER
  echo "        ppath    => '$BASE_PATH_FS/tutorial/webid'," >> $STICKER
  echo "        is_dav   => 0," >> $STICKER
  echo "        vsp_user => 'dba'," >> $STICKER
  echo "        is_brws  => 1" >> $STICKER
  echo "    )" >> $STICKER
  echo "    ;" >> $STICKER
  echo "    DB.DBA.VHOST_REMOVE (lhost=>'*sslini*', vhost=>'*sslini*', lpath=>'/tutorial/webid', del_vsps => 1);" >> $STICKER
  echo "    DB.DBA.VHOST_DEFINE (" >> $STICKER
  echo "        lhost    => '*sslini*'," >> $STICKER
  echo "        vhost    => '*sslini*'," >> $STICKER
  echo "        lpath    => '/tutorial/webid'," >> $STICKER
  echo "        ppath    => '$BASE_PATH_FS/tutorial/webid'," >> $STICKER
  echo "        is_dav   => 0," >> $STICKER
  echo "        vsp_user => 'dba'," >> $STICKER
  echo "        is_brws  => 1" >> $STICKER
  echo "    )" >> $STICKER
  echo "    ;" >> $STICKER
  echo "    DB.DBA.VAD_LOAD_SQL_FILE ('$BASE_PATH/tutorial/setup_search.sql', 1, 'report', $ISDAV);" >> $STICKER
  #echo "    DB.DBA.VAD_LOAD_SQL_FILE ('$BASE_PATH/tutorial/DET_RDFData.sql', 1, 'report', $ISDAV);" >> $STICKER
  echo "    DB.DBA.VAD_LOAD_SQL_FILE ('$BASE_PATH/tutorial/fill_search.sql', 1, 'report', $ISDAV);" >> $STICKER
  echo "    DB.DBA.VAD_LOAD_SQL_FILE ('$BASE_PATH/tutorial/sql_rdf.sql', 1, 'report', $ISDAV);" >> $STICKER
	echo "    exec('UPDATE DB.DBA.TUT_SEARCH set TS_PHPATH  = ''$BASE_PATH/tutorial/'' || TS_PATH');" >> $STICKER
  echo "    -- xqdemo -------------------" >> $STICKER
  echo "    DB.DBA.VAD_LOAD_SQL_FILE('$BASE_PATH/tutorial/xml/xq_s_1/xqdemo/presetup.sql', 1, 'report', $ISDAV);" >> $STICKER
  echo "    DB.DBA.VHOST_REMOVE(lpath=>'/xqdemo',del_vsps => 1);" >> $STICKER
  echo "    DB.DBA.VHOST_DEFINE(" >> $STICKER
  echo "        lpath    => '/xqdemo'," >> $STICKER
  echo "        ppath    => '$BASE_PATH/tutorial/xml/xq_s_1/xqdemo/'," >> $STICKER
  echo "        is_dav   => $ISDAV," >> $STICKER
  echo "        vsp_user => 'XQ'," >> $STICKER
  echo "        is_brws  => 1," >> $STICKER
  echo "        def_page => 'demo.vsp'" >> $STICKER
  echo "    )" >> $STICKER
  echo "    ;" >> $STICKER
  echo "    DB.DBA.VAD_LOAD_SQL_FILE ('$BASE_PATH/tutorial/xml/xq_s_1/xqdemo/desk.sql', 1, 'report', $ISDAV);" >> $STICKER
  echo "    DB.DBA.VAD_LOAD_SQL_FILE ('$BASE_PATH/tutorial/xml/xq_s_1/xqdemo/metadata.sql', 1, 'report', $ISDAV);" >> $STICKER
  echo "    DB.DBA.VAD_LOAD_SQL_FILE ('$BASE_PATH/tutorial/xml/xq_s_1/xqdemo/R-tables.sql', 1, 'report', $ISDAV);" >> $STICKER
  echo "    DB.DBA.DAV_COL_CREATE ('/DAV/xqdemo/', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', (SELECT pwd_magic_calc (U_NAME, U_PASSWORD, 1) FROM DB.DBA.SYS_USERS WHERE U_NAME = 'dav'));" >> $STICKER
  cd vad_files/vsp/tutorial/xml/xq_s_1/xqdemo/data > /dev/null 2>&1
  for file in `find . -type f -print | LC_ALL=C sort`
  do
    name=`echo "$file" | cut -b3-`
    if [ "$ISDAV" = "1" ] ; then
      echo "    \"DB\".\"DBA\".\"DAV_COPY\"('$BASE_PATH/tutorial/xml/xq_s_1/xqdemo/data/$name','/DAV/xqdemo/$name',1,'110100100',http_dav_uid(),http_dav_uid() + 1,'dav',(SELECT pwd_magic_calc (U_NAME, U_PASSWORD, 1) FROM DB.DBA.SYS_USERS WHERE U_NAME = 'dav'));" >> $STICKER
    else
      echo "    \"DB\".\"DBA\".\"DAV_RES_UPLOAD\"('/DAV/xqdemo/$name', file_to_string (http_root()||'$BASE_PATH/tutorial/xml/xq_s_1/xqdemo/data/$name'), '', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', (SELECT pwd_magic_calc (U_NAME, U_PASSWORD, 1) FROM DB.DBA.SYS_USERS WHERE U_NAME = 'dav'));" >> $STICKER
    fi
  done
  cd $LOGDIR
  echo "    declare _sql_state,_sql_message varchar;" >> $STICKER
  echo "    exec('drop table XQ.XQ.TEST_FILES',_sql_state,_sql_message);" >> $STICKER
  echo "    exec('drop table XQ.XQ.TEST_CASES',_sql_state,_sql_message);" >> $STICKER
  echo "    DB.DBA.VAD_LOAD_SQL_FILE ('$BASE_PATH/tutorial/xml/xq_s_1/xqdemo/postsetup.sql', 1, 'report', $ISDAV);" >> $STICKER
	echo "" >> $STICKER
	echo "" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "  <sql purpose=\"pre-uninstall\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "    \"DB\".\"DBA\".\"VAD_LOAD_SQL_FILE\"('$BASE_PATH/tutorial/uninst.sql', 1, 'report', $ISDAV);" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
	echo "  <sql purpose=\"post-uninstall\">" >> $STICKER
  echo "    DB.DBA.VHOST_REMOVE (lpath=>'/tutorial', del_vsps => 1);" >> $STICKER
  echo "    DB.DBA.VHOST_REMOVE (lhost=>'*sslini*', vhost=>'*sslini*', lpath=>'/tutorial', del_vsps => 1);" >> $STICKER
  echo "    DB.DBA.VHOST_REMOVE (lpath=>'/tutorial/webid', del_vsps => 1);" >> $STICKER
  echo "    DB.DBA.VHOST_REMOVE (lhost=>'*sslini*', vhost=>'*sslini*', lpath=>'/tutorial/webid', del_vsps => 1);" >> $STICKER
	echo "  </sql>" >> $STICKER
  echo "</ddls>" >> $STICKER
	echo "<procedures uninstallation=\"supported\">" >> $STICKER
	echo "  <sql purpose=\"pre-install\"></sql>" >> $STICKER
	echo "  <sql purpose=\"post-install\">" >> $STICKER
  echo "" >> $STICKER
  echo "    exec('create procedure TUTORIAL_IS_DAV(){" >> $STICKER
  echo "         return $ISDAV;" >> $STICKER
  echo "    }');" >> $STICKER
  echo "" >> $STICKER
  echo "    exec('create procedure TUTORIAL_ROOT_DIR(){" >> $STICKER
  if [ "$ISDAV" = "1" ] ; then
    echo "         return \\'$BASE_PATH\\';" >> $STICKER
  else
    echo "         return http_root()||\\'$BASE_PATH\\';" >> $STICKER
  fi
  echo "    }');" >> $STICKER
  echo "" >> $STICKER
  echo "    exec('create procedure TUTORIAL_XSL_DIR(){" >> $STICKER
  if [ "$ISDAV" = "1" ] ; then
    echo "         return \\'virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:$BASE_PATH\\';" >> $STICKER
  else
    echo "         return \\'file:/$BASE_PATH\\';" >> $STICKER
  fi
  echo "    }');" >> $STICKER
  echo "" >> $STICKER
  echo "    exec('create procedure TUTORIAL_VDIR_DIR(){" >> $STICKER
  echo "       return \\'$BASE_PATH\\';" >> $STICKER
  echo "    }');" >> $STICKER
  echo "" >> $STICKER
  echo "    t_populate_sioc(TUTORIAL_XSL_DIR() || '/tutorial/sioc.vsp');" >> $STICKER
  echo "" >> $STICKER
  echo "" >> $STICKER
	echo "  </sql>" >> $STICKER
	echo "</procedures>" >> $STICKER
  echo "<resources>" >> $STICKER

  for file in `find vad_files -type f -print | LC_ALL=C sort`
  do
     name=`echo "$file" | cut -b15-`
     if echo "$file" | grep -v "/webid/" >/dev/null
     then
 	     TYPE2=$TYPE
     else
	     TYPE2="http"
     fi
     echo "  <file overwrite=\"yes\" type=\"$TYPE2\" source=\"http\" target_uri=\"$name\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
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
DatabaseFile    = virtuoso.db
TransactionFile = virtuoso.trx
ErrorLogFile    = virtuoso.log
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
  do_command_safe $DSN "DB.DBA.VAD_PACK('$STICKER_FS', '.', 'tutorial_filesystem.vad')"
  do_command_safe $DSN "DB.DBA.VAD_PACK('$STICKER_DAV', '.', 'tutorial_dav.vad')"
  do_command_safe $DSN "commit work"
  do_command_safe $DSN "checkpoint"
  mv vad/vsp vad_files
}

generate_files() {
  do_command_safe $DSN "load dev.sql"
  do_command_safe $DSN "TUT_generate_files('/vad_files/vsp/tutorial')"
    #if [ "x$HOST_OS" = "x" ]
    #then
      #tar xzf $HOME/binsrc/samples/IBuySpy/ibuyspy_mono_virtuoso_client.tar.gz
      #mv PortalCS $LOGDIR/vad_files/vsp 
    #fi
}

$myrm "$LOGFILE" 2>/dev/null
BANNER 'TUTORIAL VAD create'

$ISQL -? 2>/dev/null 1>/dev/null 
if [ $? -eq 127 ] ; then
    LOG "***ABORTED: tutorial PACKAGING, isql is not available"
    exit 1
fi
$SERVER -? 2>/dev/null 1>/dev/null 
if [ $? -eq 127 ] ; then
    LOG "***ABORTED: tutorial PACKAGING, server is not available"
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
	sticker_init 1
	vad_create
	virtuoso_shutdown
	STOP_SERVER
	chmod 644 tutorial_filesystem.vad
	chmod 644 tutorial_dav.vad
#        directory_clean
fi

CHECK_LOG
RUN egrep  '"\*\*.*FAILED:|\*\*.*ABORTED:"' "$LOGFILE"
if test $STATUS -eq 0
then
	$myrm -f *.vad
	exit 1
fi

BANNER "COMPLETED VAD PACKAGING"
exit 0

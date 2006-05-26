#!/bin/sh

LOGDIR=`pwd`
VERSION="1.00.00"  # see automatic versioning bellow "1.02.69"
LOGFILE="${LOGDIR}/make_ods_vad.log"
STICKER="${LOGDIR}/make_ods_vad.xml"
PACKDATE=`date +"%Y-%m-%d %H:%M"`
SERVER=${SERVER-virtuoso}
THOST=${THOST-localhost}
TPORT=${TPORT-8440}
PORT=${PORT-1940}
ISQL=${ISQL-isql}
DSN="$HOST:$PORT"
NEED_VERSION=04.50.2905
HOST_OS=`uname -s | grep WIN`
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
if [ -f ../../../autogen.sh ]
then
    VOS=1
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
      for i in `find . -name 'Entries' | grep -v "vad/" | grep -v "/tests/"`; do
	  cat "$i" | grep "^[^D].*" | cut -f 3 -d "/" | sed -e "s/1\.//g" >> version.tmp
      done
      LANG=POSIX
      export LANG
      VERSION=`cat version.tmp | awk ' BEGIN { cnt=450 } { cnt = cnt + $1 } END { printf "1.%02.02f", cnt/100 }'`
      rm -f version.tmp
      echo "$VERSION" > vad_version
  fi
}

virtuoso_start() {
  echo "Starting $SERVER"
  ddate=`date`
  starth=`date | cut -f 2 -d :`
  starts=`date | cut -f 3 -d :|cut -f 1 -d " "`
  timeout=600
  $myrm -f *.lck
  if [ "x$HOST_OS" != "x" ]
  then
    $BUILD/../bin/virtuoso-odbc-t +foreground &
  else
    virtuoso #+wait
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
  if [ "x$HOST_OS" != "x" ]
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
  $myrm vad.* 2>/dev/null
  $myrm *.db 2>/dev/null
  $myrm *.trx 2>/dev/null
  $myrm *.tdb 2>/dev/null
  $myrm *.pxa 2>/dev/null
  $myrm virtuoso.log 2>/dev/null
  $myrm *.ini 2>/dev/null
  $myrm *.lic 2>/dev/null
}

directory_init() {
  mkdir vad
  mkdir vad/data
  mkdir vad/data/wa
  mkdir vad/data/wa/comp
  mkdir vad/data/wa/images
  mkdir vad/data/wa/images/dav_browser
  mkdir vad/data/wa/images/icons
  mkdir vad/data/wa/images/buttons
  mkdir vad/data/wa/tmpl
  mkdir vad/data/wa/templates
  mkdir vad/data/wa/templates/default
  cp *.vspx vad/data/wa
  cp *.vsp vad/data/wa
  cp *.xsl vad/data/wa
  cp trs*.xml vad/data/wa
  cp foa*.xml vad/data/wa
  cp ufoa*.xml vad/data/wa
  cp sfoa*.xml vad/data/wa
  cp *.css vad/data/wa
  cp *.html vad/data/wa
  cp *.sql vad/data/wa
  cp *.js vad/data/wa
  cp $HOME/binsrc/tags/phrasematch.sql vad/data/wa
  cp comp/*.xsl vad/data/wa/comp
  cp comp/*.js vad/data/wa/comp
  #cp images/dav_browser/*.gif vad/data/wa/images/dav_browser
  #cp images/dav_browser/*.jpg vad/data/wa/images/dav_browser
  cp images/dav_browser/*.png vad/data/wa/images/dav_browser
  cp images/*.gif vad/data/wa/images
  cp images/*.jpg vad/data/wa/images
  cp images/*.png vad/data/wa/images
  cp $HOME/binsrc/weblog2/public/images/foaf.gif vad/data/wa/images
  cp icons/*.gif vad/data/wa/images/icons
  #cp icons/*.jpg vad/data/wa/images/icons
  cp icons/*.png vad/data/wa/images/icons
  #cp buttons/*.gif vad/data/wa/images/buttons
  #cp buttons/*.jpg vad/data/wa/images/buttons
  #cp buttons/*.png vad/data/wa/images/buttons
  cp comp/*.xml vad/data/wa/comp
  cp tmpl/* vad/data/wa/tmpl
  cat home.vspx | sed -e "s/home\.xsl/\/DAV\/VAD\/wa\/home\.xsl/g" >  vad/data/wa/templates/default/home.vspx
  cp default.css vad/data/wa/templates/default
}

virtuoso_shutdown() {
  LOG "Shutdown $DSN ..."
  do_command_safe $DSN "shutdown" 2>/dev/null
  sleep 5
}

sticker_init() {
  LOG "VAD ODS sticker creation..."
  echo "<?xml version=\"1.0\" encoding=\"ASCII\"?>" > $STICKER
  echo "<!DOCTYPE sticker SYSTEM \"vad_sticker.dtd\">" >> $STICKER
  echo "<sticker version=\"1.0.010505A\" xml:lang=\"en-UK\">" >> $STICKER
  echo "<caption>" >> $STICKER
  echo "  <name package=\"Framework\">" >> $STICKER
  echo "    <prop name=\"Title\" value=\"ODS Framework\"/>" >> $STICKER
  echo "    <prop name=\"Developer\" value=\"OpenLink Software\"/>" >> $STICKER
  echo "    <prop name=\"Copyright\" value=\"(C) 1999-2006 OpenLink Software\"/>" >> $STICKER
  echo "    <prop name=\"Download\" value=\"http://www.openlinksw.com/virtuoso\"/>" >> $STICKER
  echo "    <prop name=\"Download\" value=\"http://www.openlinksw.co.uk/virtuoso\"/>" >> $STICKER
  echo "  </name>" >> $STICKER
  echo "  <version package=\"$VERSION\">" >> $STICKER
  echo "    <prop name=\"Release Date\" value=\"$PACKDATE\"/>" >> $STICKER
  echo "    <prop name=\"Build\" value=\"Release, optimized\"/>" >> $STICKER
  echo "  </version>" >> $STICKER
  echo "</caption>" >> $STICKER
  echo "<dependencies/>" >> $STICKER
  echo "<procedures uninstallation=\"supported\">" >> $STICKER
  echo "  <sql purpose=\"pre-install\"><![CDATA[" >> $STICKER
  echo "    if (lt (sys_stat ('st_dbms_ver'), '$NEED_VERSION')) " >> $STICKER
  echo "      { " >> $STICKER
  echo "         result ('ERROR', 'The ods package requires server version $NEED_VERSION or greater'); " >> $STICKER
  echo "	 signal ('FATAL', 'The ods package requires server version $NEED_VERSION or greater'); " >> $STICKER
  echo "      } " >> $STICKER
  echo "     if (VAD_CHECK_VERSION ('wa') is not null and VAD_CHECK_VERSION ('Framework') is null) " >> $STICKER
  echo "       {" >> $STICKER
  echo "          DB.DBA.VAD_RENAME ('wa', 'Framework');" >> $STICKER
  echo "       }" >> $STICKER
  echo "  ]]></sql>" >> $STICKER
  echo "  <sql purpose=\"post-install\"></sql>" >> $STICKER
  echo "</procedures>" >> $STICKER
  echo "<ddls>" >> $STICKER
  echo "  <sql purpose=\"pre-install\"></sql>" >> $STICKER
  echo "  <sql purpose=\"post-install\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "      registry_set('_wa_path_', '/DAV/VAD/wa/');" >> $STICKER
  echo "      registry_set('_wa_version_', '$VERSION');" >> $STICKER
  echo "      registry_set('_wa_build_', '$PACKDATE');" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/sn.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/hosted_services.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/registration_xml.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/phrasematch.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/tags.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/dashboard.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/wa_search_procs.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/wa_maps.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/provinces.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/wa_template.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/gdata.sql', 1, 'report', 1);" >> $STICKER

  echo "      DB.DBA.DAV_PROP_SET_INT ('/DAV/VAD/wa/trs_export.xml', 'xml-template', 'execute', http_dav_uid (), null, 0, 0, 1);" >> $STICKER
  echo "      DB.DBA.DAV_PROP_SET_INT ('/DAV/VAD/wa/foaf.xml', 'xml-template', 'execute', http_dav_uid (), null, 0, 0, 1);" >> $STICKER
  echo "      DB.DBA.DAV_PROP_SET_INT ('/DAV/VAD/wa/ufoaf.xml', 'xml-template', 'execute', http_dav_uid (), null, 0, 0, 1);" >> $STICKER
  echo "      DB.DBA.DAV_PROP_SET_INT ('/DAV/VAD/wa/sfoaf.xml', 'xml-template', 'execute', http_dav_uid (), null, 0, 0, 1);" >> $STICKER
  echo "      vhost_remove (lpath=>'/wa');" >> $STICKER
  echo "      vhost_remove (lpath=>'/ods');" >> $STICKER
  #echo "      vhost_define (lpath=>'/wa',ppath=>'/DAV/VAD/wa/', is_dav=>1, vsp_user=>'dba', def_page=>'index.vspx');" >> $STICKER
  echo "      vhost_define (lpath=>'/ods',ppath=>'/DAV/VAD/wa/', is_dav=>1, vsp_user=>'dba', def_page=>'sfront.vspx');" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "  <sql purpose=\"pre-uninstall\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/drop.sql', 1, 'report', 1);" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "</ddls>" >> $STICKER
  echo "<resources>" >> $STICKER

  for file in `find vad/data/wa -type f -print | sort`
  do
     if echo "$file" | grep -v ".vsp" >/dev/null
     then
	 if echo "$file" | grep -v "trs_export.xml" | grep -v "foaf.xml" >/dev/null
	 then
	     perms="110100100NN"
	 else
	     perms="111101101NN"
	 fi
     else
	 perms="111101101NN"
     fi
     name=`echo "$file" | cut -b10-`
     echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"$name\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"$perms\" makepath=\"yes\"/>" >> $STICKER
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
  if [ -f virtuoso.lic ]
  then
    echo "virtuoso.lic found"
  else
    cp $HOME/binsrc/tests/suite/virtuoso.lic virtuoso.lic 2>/dev/null
  fi
  virtuoso_start
}

vad_create() {
  do_command_safe $DSN "DB.DBA.VAD_PACK('$STICKER', '.', 'ods_dav.vad')"
  do_command_safe $DSN "commit work"
  do_command_safe $DSN "checkpoint"
}

STOP_SERVER
$myrm $LOGFILE 2>/dev/null
directory_clean
VERSION_INIT
directory_init
virtuoso_init
sticker_init
vad_create
virtuoso_shutdown
chmod 644 ods_dav.vad
#chmod 644 virtuoso.trx
#directory_clean

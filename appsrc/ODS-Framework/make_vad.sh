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


LOGDIR=`pwd`
VERSION="1.00.00"  # see automatic versioning below "1.02.69"
LOGFILE="${LOGDIR}/make_ods_vad.log"
STICKER="make_ods_vad.xml"
PACKDATE=`date +"%Y-%m-%d %H:%M"`
SERVER=${SERVER-virtuoso}
THOST=${THOST-localhost}
PORT=${PORT-1970}
PORT=`expr $PORT + 10`
TPORT=`expr $PORT + 7000`
ISQL=${ISQL-isql}
DSN="$HOST:$PORT"
NEED_VERSION=05.00.3028
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
      # Also reflect changes in oat
      for i in `find ../../oat -name 'Entries' `; do
	  cat "$i" | grep -v "version\."| grep "^[^D].*" | cut -f 3 -d "/" | sed -e "s/1\.//g" >> version.tmp
      done
      LANG=POSIX
      export LANG

      BASE="0"
#      echo $BASE
      if [ -f version.base ] ; then
	  BASE=`cat version.base`
      fi

      VERSION=`cat version.tmp | awk ' BEGIN { cnt=0 } { cnt = cnt + $1 } END { print cnt }'`

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
  echo "Starting $SERVER"
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
  mkdir vad/data/wa/oat
  mkdir vad/data/wa/oat/styles
  mkdir vad/data/wa/oat/xslt
  mkdir vad/data/wa/images
  mkdir vad/data/wa/images/app_ads
  mkdir vad/data/wa/images/dav_browser
  mkdir vad/data/wa/images/icons
  mkdir vad/data/wa/images/buttons
  mkdir vad/data/wa/images/oat
  mkdir vad/data/wa/images/oat/markers
  mkdir vad/data/wa/images/services
  mkdir vad/data/wa/images/skin
  mkdir vad/data/wa/images/skin/default
  mkdir vad/data/wa/images/skin/pager
  mkdir vad/data/wa/tmpl
  mkdir vad/data/wa/templates
  mkdir vad/data/wa/templates/default
  mkdir vad/data/wa/users
  mkdir vad/data/wa/users/css
  mkdir vad/data/wa/users/js
  mkdir vad/data/wa/webid
  for dir in `find ckeditor -type d -print | LC_ALL=C sort | grep -v CVS`
  do
    mkdir vad/data/wa/$dir
  done
  mkdir vad/data/wa/oauth
  mkdir vad/data/wa/oauth/images
  cp *.vspx vad/data/wa
  cp *.vsp vad/data/wa
  cp *.xsl vad/data/wa
  cp trs*.xml vad/data/wa
  cp href*.xml vad/data/wa
  cp foa*.xml vad/data/wa
  cp afoa*.xml vad/data/wa
  cp ufoa*.xml vad/data/wa
  cp sfoa*.xml vad/data/wa
  cp *.css vad/data/wa
  cp *.html vad/data/wa
  cp *.sql vad/data/wa
  #cp $HOME/binsrc/dav/DET_RDFData.sql vad/data/wa
  cp *.js vad/data/wa
  cp comp/*.xsl vad/data/wa/comp
  cp comp/*.js vad/data/wa/comp
  cp $HOME/binsrc/oat/toolkit/*.js vad/data/wa/oat/.
  cp $HOME/binsrc/oat/images/*.png vad/data/wa/images/oat/.
  cp $HOME/binsrc/oat/images/*.gif vad/data/wa/images/oat/.
  cp $HOME/binsrc/oat/images/markers/*.png vad/data/wa/images/oat/markers/.
  cp $HOME/binsrc/oat/styles/*.css vad/data/wa/oat/styles/.
  cp $HOME/binsrc/oat/xslt/*.xsl vad/data/wa/oat/xslt/.
# cp $HOME/binsrc/oat/styles/winrect.css vad/data/wa/.
# cp $HOME/binsrc/oat/toolkit/ajax.js vad/data/wa/oat/.
# cp $HOME/binsrc/oat/toolkit/dom.js vad/data/wa/oat/.
# cp $HOME/binsrc/oat/toolkit/loader.js vad/data/wa/oat/.
# cp $HOME/binsrc/oat/toolkit/xml.js vad/data/wa/oat/.
# cp images/dav_browser/*.gif vad/data/wa/images/dav_browser
# cp images/dav_browser/*.jpg vad/data/wa/images/dav_browser
  cp images/dav_browser/*.png vad/data/wa/images/dav_browser
  cp images/*.gif vad/data/wa/images
  cp images/*.jpg vad/data/wa/images
  cp images/*.png vad/data/wa/images
  cp images/app_ads/*.jpg vad/data/wa/images/app_ads
# cp $HOME/binsrc/weblog2/public/images/foaf.gif vad/data/wa/images
  cp icons/*.gif vad/data/wa/images/icons
# cp icons/*.jpg vad/data/wa/images/icons
  cp icons/*.png vad/data/wa/images/icons
  cp images/services/*.jpg vad/data/wa/images/services
#  cp images/skin/default/*.jpg vad/data/wa/images/skin/default
  cp images/skin/default/*.png vad/data/wa/images/skin/default
  cp images/skin/pager/*.png vad/data/wa/images/skin/pager
# cp buttons/*.gif vad/data/wa/images/buttons
# cp buttons/*.jpg vad/data/wa/images/buttons
# cp buttons/*.png vad/data/wa/images/buttons
  cp comp/*.xml vad/data/wa/comp
  cp tmpl/* vad/data/wa/tmpl
  cat home.vspx | sed -e "s/home\.xsl/\/DAV\/VAD\/wa\/home\.xsl/g" >  vad/data/wa/templates/default/home.vspx
  cp default.css vad/data/wa/templates/default
  cp users/* vad/data/wa/users
  cp users/css/* vad/data/wa/users/css
  cp users/js/* vad/data/wa/users/js
  for file in `find ckeditor -type f -print | LC_ALL=C sort | grep -v CVS | grep -v '.vspx-m' | grep -v '.vspx-sql'`
  do
    cp $file vad/data/wa/$file
  done
  cp webid_demo.php vad/data/wa/webid
  cp vad/data/wa/webid_demo.* vad/data/wa/webid
  cp vad/data/wa/webid_check.* vad/data/wa/webid
  cp vad/data/wa/webid_verify.* vad/data/wa/webid
  cp oauth/* vad/data/wa/oauth
  cp oauth/images/* vad/data/wa/oauth/images
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
  echo "    <prop name=\"Copyright\" value=\"(C) 1998-2018 OpenLink Software\"/>" >> $STICKER
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
  echo "    declare ini, case_mode, cname, dyn, is_api varchar; " >> $STICKER
  echo "    ini := virtuoso_ini_path (); " >> $STICKER
  echo "    case_mode := cfg_item_value (ini, 'Parameters', 'CaseMode'); " >> $STICKER
  echo "    cname := cfg_item_value (ini, 'URIQA', 'DefaultHost'); " >> $STICKER
  echo "    dyn := cfg_item_value (ini, 'URIQA', 'DynamicLocal'); " >> $STICKER
  echo "    is_api := registry_get ('__blog_api_tests__'); " >> $STICKER
  echo "    if (lt (sys_stat ('st_dbms_ver'), '$NEED_VERSION') or __proc_exists ('HTTP_STATUS_SET',2) is null) " >> $STICKER
  echo "      { " >> $STICKER
  echo "         result ('ERROR', 'The ods package requires server version $NEED_VERSION or greater'); " >> $STICKER
  echo "	 signal ('FATAL', 'The ods package requires server version $NEED_VERSION or greater'); " >> $STICKER
  echo "      } " >> $STICKER
  echo "     if (VAD_CHECK_VERSION ('wa') is not null and VAD_CHECK_VERSION ('Framework') is null) " >> $STICKER
  echo "       {" >> $STICKER
  echo "          DB.DBA.VAD_RENAME ('wa', 'Framework');" >> $STICKER
  echo "       }" >> $STICKER
  echo "      if (not isstring (is_api) and case_mode <> '2') { " >> $STICKER
  echo "	  result ('ERROR', 'The ODS Framework needs server to run in CaseMode 2, please check your INI file.'); " >> $STICKER
  echo "	  signal ('FATAL', 'The ODS Framework needs server to run in CaseMode 2, please check your INI file.'); " >> $STICKER
  echo "	}" >> $STICKER
  echo "      if (not isstring (is_api) and length (cname) = 0) { " >> $STICKER
  echo "	  result ('ERROR', 'The ODS Framework needs DefaultHost to be specified in URIQA INI section.'); " >> $STICKER
  echo "	  signal ('FATAL', 'The ODS Framework needs DefaultHost to be specified in URIQA INI section.'); " >> $STICKER
  echo " 	}" >> $STICKER
  #echo "      if (isstring (dyn) and dyn <> '0') { " >> $STICKER
  #echo "	  result ('00000', 'The ODS Framework needs DynamicLocal = 0 to be specified in URIQA INI section.'); " >> $STICKER
  #echo " 	}" >> $STICKER
  echo "  ]]></sql>" >> $STICKER
  echo "  <sql purpose=\"post-install\"></sql>" >> $STICKER
  echo "</procedures>" >> $STICKER
  echo "<ddls>" >> $STICKER
  echo "  <sql purpose=\"pre-install\"></sql>" >> $STICKER
  echo "  <sql purpose=\"post-install\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "      declare rc any; " >> $STICKER
  echo "      registry_set('_wa_path_', '/DAV/VAD/wa/');" >> $STICKER
  echo "      registry_set('_wa_version_', '$VERSION');" >> $STICKER
  echo "      registry_set('_wa_build_', '$PACKDATE');" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/sn.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/hosted_services.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/registration_xml.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/tags.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/dashboard.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/wa_search_procs.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/wa_maps.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/provinces.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/wa_template.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/url_rew.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/gdata.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/openid.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/ldap.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/oauth/oauth.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/facebook.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/nav_framework_api.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/semping.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.DAV_PROP_SET_INT ('/DAV/VAD/wa/trs_export.xml', 'xml-template', 'execute', http_dav_uid (), null, 0, 0, 1);" >> $STICKER
  echo "      DB.DBA.DAV_PROP_SET_INT ('/DAV/VAD/wa/trs_export_all.xml', 'xml-template', 'execute', http_dav_uid (), null, 0, 0, 1);" >> $STICKER
  echo "      DB.DBA.DAV_PROP_SET_INT ('/DAV/VAD/wa/href_export.xml', 'xml-template', 'execute', http_dav_uid (), null, 0, 0, 1);" >> $STICKER
  echo "      DB.DBA.DAV_PROP_SET_INT ('/DAV/VAD/wa/foaf.xml', 'xml-template', 'execute', http_dav_uid (), null, 0, 0, 1);" >> $STICKER
  echo "      DB.DBA.DAV_PROP_SET_INT ('/DAV/VAD/wa/ufoaf.xml', 'xml-template', 'execute', http_dav_uid (), null, 0, 0, 1);" >> $STICKER
  echo "      rc := DB.DBA.DAV_PROP_SET_INT ('/DAV/VAD/wa/ufoaf.xml', 'xml-sql-encoding', 'UTF-8', 'dav', null, 0, 0, 1);" >> $STICKER
  echo "      DB.DBA.DAV_PROP_SET_INT ('/DAV/VAD/wa/afoaf.xml', 'xml-template', 'execute', http_dav_uid (), null, 0, 0, 1);" >> $STICKER
  echo "      DB.DBA.DAV_PROP_SET_INT ('/DAV/VAD/wa/sfoaf.xml', 'xml-template', 'execute', http_dav_uid (), null, 0, 0, 1);" >> $STICKER
  echo "      vhost_remove (lpath=>'/wa');" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/web_svc.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/ods_api.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/ods_api_users.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/ods_controllers.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/sioc.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/scot.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/sql_rdf.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/user_rdf.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/sioc_priv.sql', 1, 'report', 1);" >> $STICKER
  #echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/DET_RDFData.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.\"RDFData_MAKE_DET_COL\" ('/DAV/VAD/wa/RDFData/', sioc..get_graph (), NULL);" >> $STICKER
  echo "      DB.DBA.wa_users_rdf_data_det_upgrade ();" >> $STICKER
  echo "      DB.DBA.VHOST_REMOVE (lpath=>'/ods/data/rdf');" >> $STICKER
  echo "      DB.DBA.VHOST_DEFINE (lpath=>'/ods/data/rdf', ppath=>'/DAV/VAD/wa/RDFData/All/', is_dav=>1, vsp_user=>'dba');" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/opensocial.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/oauth/foaf_ssl.sql', 0, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/webfinger.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/salmon.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/SWD.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/ods_upstream.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VHOST_REMOVE (lpath=>'/oauth');" >> $STICKER
  echo "      DB.DBA.VHOST_DEFINE (lpath=>'/oauth', ppath=>'/DAV/VAD/wa/oauth/', vsp_user=>'dba', is_dav=>1, is_brws=>0, def_page=>'index.vsp');" >> $STICKER
  echo "      if (ODS.ODS_API.getDefaultHttps () is not null) " >> $STICKER
  echo "	DB.DBA.wa_redefine_vhosts (); " >> $STICKER
  echo "	    DB.DBA.WA_USER_OL_ACCOUNTS_SET_UP (); " >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "  <sql purpose=\"pre-uninstall\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
#  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/drop_sioc_proc.sql', 1, 'report', 1);" >> $STICKER
#  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/drop_sioc_trig.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wa/drop.sql', 1, 'report', 1);" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "</ddls>" >> $STICKER
  echo "<resources>" >> $STICKER

  for file in `find vad/data/wa -type f -print | sort`
  do
     if echo "$file" | grep -v ".vsp" | grep -v ".php" >/dev/null
     then
    	 if echo "$file" | grep -v "trs_export.xml" | grep -v "trs_export_all.xml" | grep -v "href_export.xml" | grep -v "foaf.xml" >/dev/null
	 then
	     perms="110100100NN"
	 else
	     perms="111101101NN"
	 fi
     else
	 perms="111101101NN"
     fi
     if echo "$file" | grep -v "/users/" > /dev/null
     then
       if echo "$file" | grep -v "/webid/" > /dev/null
       then
   	     TYPE="dav"
       else
  	     TYPE="http"
       fi
     else
	     TYPE="http"
     fi
     name=`echo "$file" | cut -b10-`
     echo "  <file overwrite=\"yes\" type=\"$TYPE\" source=\"data\" target_uri=\"$name\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"$perms\" makepath=\"yes\"/>" >> $STICKER
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
DirsAllowed          = /
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
  do_command_safe $DSN "DB.DBA.VAD_PACK('$STICKER', '.', 'ods_framework_dav.vad')"
  do_command_safe $DSN "commit work"
  do_command_safe $DSN "checkpoint"
}

STOP_SERVER
$myrm $LOGFILE 2>/dev/null
directory_clean
version_init
directory_init
virtuoso_init
sticker_init
vad_create
virtuoso_shutdown
chmod 644 ods_framework_dav.vad
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

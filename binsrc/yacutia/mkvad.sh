#!/bin/sh
#
#  mkvad.sh
#
#  Creates a vad package for Virtuoso Conductor
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2014 OpenLink Software
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

# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL


PORT=${PORT-1112}
_HTTPPORT=`expr $PORT + 10`
HTTPPORT=${HTTPPORT-$_HTTPPORT}
#PORT=1311
#HTTPPORT=8311
PACKDATE=`date +"%Y-%m-%d %H:%M"`
SERVER=${SERVER-}
HOST=${HOST-localhost}
STICKER_DAV="vad_dav.xml"
STICKER_FS="vad_fs.xml"
NEED_VERSION=05.09.3037
ISQL=${ISQL-isql}

DSN="$HOST:$PORT"
LOGFILE=mkvad.output
DEMO=`pwd`
export DEMO LOGFILE
SILENT=${SILENT-0}
MAKEDOCS=${MAKEDOCS-0}
HTMLDOCS=${HTMLDOCS-1}
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

#==============================================================================
#  Standard functions
#==============================================================================

ECHO()
{
    echo "$*"   | tee -a $DEMO/$LOGFILE
}


RUN()
{
    echo "+ $*"   >> $DEMO/$LOGFILE

    STATUS=1
    if test $SILENT -eq 1
    then
  eval $*   >> $DEMO/$LOGFILE 2>/dev/null
    else
  eval $*   >> $DEMO/$LOGFILE
    fi
    STATUS=$?
}


LINE()
{
    ECHO "====================================================================="
}


BREAK()
{
    ECHO ""
    ECHO "---------------------------------------------------------------------"
    ECHO ""
}


BANNER()
{
    ECHO ""
    LINE
    ECHO "=  $*"
    ECHO "= " `date`
    LINE
    ECHO ""
}

LOG()
{
    if test $SILENT -eq 1
    then
  echo "$*" >> $LOGFILE
    else
  echo "$*" | tee -a $LOGFILE
    fi
}

START_SERVER()
{
  timeout=120

  ECHO "Starting Virtuoso server ..."
  if [ "z$HOST_OS" != "z" ]
  then
      "$SERVER" +foreground &
      else
      "$SERVER" +wait
      fi

  starth=`date | cut -f 2 -d :`
  starts=`date | cut -f 3 -d :|cut -f 1 -d " "`

  while true
    do
      sleep 6
      if (netstat -an | grep "$PORT" | grep LISTEN > /dev/null)
        then
    ECHO "Virtuoso server started"
    return 0
  fi
      nowh=`date | cut -f 2 -d :`
      nows=`date | cut -f 3 -d : | cut -f 1 -d " "`

      nowh=`expr $nowh - $starth`
      nows=`expr $nows - $starts`

      nows=`expr $nows + $nowh \*  60`
      if test $nows -ge $timeout
        then
    ECHO "***FAILED: Could not start Virtuoso Server within $timeout seconds"
    exit 1
  fi
  done
}

STOP_SERVER()
{
   $ISQL $DSN dba dba '"EXEC=raw_exit();"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT >> $LOGFILE
}


DO_COMMAND()
{
  command=$1
  uid=${2-dba}
  passwd=${3-dba}
  $ISQL $DSN $uid $passwd ERRORS=stdout VERBOSE=OFF PROMPT=OFF "EXEC=$command" >> "${LOGFILE}.tmp"
  if test $? -ne 0
  then
    cat "${LOGFILE}.tmp" >> $LOGFILE
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


CHECK_LOG()
{
    passed=`cat $DEMO/$LOGFILE | cut -b -200 | grep "PASSED:" | wc -l`
    failed=`cat $DEMO/$LOGFILE | cut -b -200 | grep "\*\*\*.*FAILED:" | wc -l`
    aborted=`cat $DEMO/$LOGFILE | cut -b -200 | grep "\*\*\*.*ABORTED:" | wc -l`

    ECHO ""
    LINE
    ECHO "=  Checking log file $LOGFILE for statistics:"
    ECHO "="
    ECHO "=  Total number of tests PASSED  : $passed"
    ECHO "=  Total number of tests FAILED  : $failed"
    ECHO "=  Total number of tests ABORTED : $aborted"
    LINE
    ECHO ""

    if (expr $failed + $aborted \> 0 > /dev/null)
    then
       ECHO "*** Not all tests completed successfully"
       ECHO "*** Check the file $LOGFILE for more information"
    fi
}


LOAD_SQL()
{
  sql=$1
  uid=${2-dba}
  passwd=${3-dba}

  RUN $ISQL $DSN $uid $passwd ERRORS=stdout VERBOSE=OFF PROMPT=OFF $sql
  if test $? -ne 0
  then
    ECHO "***FAILED: LOAD $sql"
  else
    ECHO "PASSED: LOAD $sql"
  fi
}

VERSION_INIT()
{
      if [ -f vad_version ]
      then
	  VERSION=`cat vad_version`
      else
        LOG "The vad_version does not exist, please verify your checkout"
	exit 1
      fi
}

CREATE_STICKER()
{
  ISDAV=$1
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
LOG "VAD Sticker $STICKER creation..."
echo "<?xml version=\"1.0\" encoding=\"ASCII\"?>" > $STICKER
echo "<!DOCTYPE sticker SYSTEM \"vad_sticker.dtd\">" >> $STICKER
echo "<sticker version=\"1.0.010505A\" xml:lang=\"en-UK\">" >> $STICKER
echo "  <caption>" >> $STICKER
echo "    <name package=\"conductor\">" >> $STICKER
echo "      <prop name=\"Title\" value=\"Virtuoso Conductor\"/>" >> $STICKER
echo "      <prop name=\"Developer\" value=\"OpenLink Software\"/>" >> $STICKER
echo "      <prop name=\"Copyright\" value=\"(C) 1998-2014 OpenLink Software\"/>" >> $STICKER
echo "      <prop name=\"Download\" value=\"http://www.openlinksw.com/virtuoso/conductor/download\"/>" >> $STICKER
echo "      <prop name=\"Download\" value=\"http://www.openlinksw.co.uk/virtuoso/conductor/download\"/>" >> $STICKER
echo "    </name>" >> $STICKER
echo "    <version package=\"$VERSION\">" >> $STICKER
echo "      <prop name=\"Release Date\" value=\"$PACKDATE\"/>" >> $STICKER
echo "      <prop name=\"Build\" value=\"Release, optimized\"/>" >> $STICKER
echo "    </version>" >> $STICKER
echo "  </caption>" >> $STICKER
echo "  <dependencies/>" >> $STICKER
echo "  <procedures uninstallation=\"supported\">" >> $STICKER
echo "    <sql purpose=\"pre-install\"></sql>" >> $STICKER
echo "    <sql purpose=\"post-install\"></sql>" >> $STICKER
echo "  </procedures>" >> $STICKER
echo "  <ddls>" >> $STICKER
echo "    <sql purpose=\"pre-install\">" >> $STICKER
echo "      if (lt (sys_stat ('st_dbms_ver'), '$NEED_VERSION'))" >> $STICKER
echo "        {" >> $STICKER
echo "          result ('ERROR', 'The conductor package requires server version $NEED_VERSION or greater');" >> $STICKER
echo "          signal ('FATAL', 'The conductor package requires server version $NEED_VERSION or greater');" >> $STICKER
echo "        }" >> $STICKER
echo "      if (__proc_exists ('VALIDATE.DBA.validate') is null)" >> $STICKER
echo "        {" >> $STICKER
echo "          result ('ERROR', 'Please update server version');" >> $STICKER
echo "          signal ('FATAL', 'Please update server version');" >> $STICKER
echo "        }" >> $STICKER
echo "      if ((__proc_exists ('DB.DBA.WebDAV_DAV_AUTHENTICATE') is not null) and (__proc_exists ('DB.DBA.WebDAV_VERIFY') is null))" >> $STICKER
echo "        {" >> $STICKER
echo "          result ('ERROR', 'Please install the last Briefcase VAD packages');" >> $STICKER
echo "          signal ('FATAL', 'Please install the last Briefcase VAD packages');" >> $STICKER
echo "        }" >> $STICKER
echo "      if ((__proc_exists ('DB.DBA.oMail_DAV_AUTHENTICATE') is not null) and (__proc_exists ('DB.DBA.oMail_CONFIGURE') is null))" >> $STICKER
echo "       {" >> $STICKER
echo "          result ('ERROR', 'Please install the last WebMail VAD packages');" >> $STICKER
echo "          signal ('FATAL', 'Please install the last WebMail VAD packages');" >> $STICKER
echo "       }" >> $STICKER
echo "      if (equ ($ISDAV, 0) and isinteger (file_stat (http_root ())))" >> $STICKER
echo "        {" >> $STICKER
echo "          result ('ERROR', 'Please setup [HTTPServer] ServerRoot INI setting properly');" >> $STICKER
echo "          signal ('FATAL', 'Please setup [HTTPServer] ServerRoot INI setting properly');" >> $STICKER
echo "        }" >> $STICKER
echo "    </sql>" >> $STICKER
echo "    <sql purpose=\"post-install\">" >> $STICKER
echo "      registry_set('__no_vspx_temp', '1');" >> $STICKER
#echo "      \"DB\".\"DBA\".\"VAD_LOAD_SQL_FILE\"('$BASE_PATH/conductor/admin_dav_browser.sql', 1, 'report', $ISDAV);" >> $STICKER
echo "      \"DB\".\"DBA\".\"VAD_LOAD_SQL_FILE\"('$BASE_PATH/conductor/vdir_helper.sql', 1, 'report', $ISDAV);" >> $STICKER
echo "      \"DB\".\"DBA\".\"VAD_LOAD_SQL_FILE\"('$BASE_PATH/conductor/yacutia.sql', 1, 'report', $ISDAV);" >> $STICKER
echo "      \"DB\".\"DBA\".\"VAD_LOAD_SQL_FILE\"('$BASE_PATH/conductor/dav/dav_browser.sql', 1, 'report', $ISDAV);" >> $STICKER
echo "      \"WEBDAV\".\"DBA\".\"xsl_upload\"($ISDAV);" >> $STICKER
echo "      vhost_remove (lpath=>'/conductor');" >> $STICKER
echo "      vhost_remove (lpath=>'/vspx');" >> $STICKER
echo "      vhost_remove (lhost=>'*sslini*', vhost=>'*sslini*', lpath=>'/conductor');" >> $STICKER
echo "      vhost_define (lpath=>'/conductor',ppath=>'$BASE_PATH/conductor/', is_dav=>$ISDAV, vsp_user=>'dba', is_brws=>1, def_page=>'main_tabs.vspx');" >> $STICKER
echo "      vhost_define (lhost=>'*sslini*', vhost=>'*sslini*', lpath=>'/conductor',ppath=>'$BASE_PATH/conductor/', is_dav=>$ISDAV, vsp_user=>'dba', is_brws=>1, def_page=>'main_tabs.vspx');" >> $STICKER
echo "      \"DB\".\"DBA\".\"VAD_LOAD_SQL_FILE\"('$BASE_PATH/conductor/xddl.sql', 1, 'report', $ISDAV);" >> $STICKER
echo "      \"DB\".\"DBA\".\"VAD_LOAD_SQL_FILE\"('$BASE_PATH/conductor/$XDDLSQL', 1, 'report', $ISDAV);" >> $STICKER
echo "    </sql>" >> $STICKER
echo "    <sql purpose=\"post-uninstall\">" >> $STICKER
echo "      vhost_remove (lpath=>'/conductor');" >> $STICKER
echo "      vhost_remove (lpath=>'/vspx');" >> $STICKER
echo "      vhost_remove (lhost=>'*sslini*', vhost=>'*sslini*', lpath=>'/conductor');" >> $STICKER
echo "      vhost_remove (lhost=>'*sslini*', vhost=>'*sslini*', lpath=>'/vspx');" >> $STICKER
echo "    </sql>" >> $STICKER
echo "  </ddls>" >> $STICKER
echo "  <resources>" >> $STICKER

  if [ "$ISDAV" = "1" ]
  then
      FLIST=`cat conductor.list | grep -v '\.\.'`
  else
      FLIST=`cat conductor.list`
  fi

for file in $FLIST
do
    name=$file
echo "    <file type=\"$TYPE\" source=\"http\" target_uri=\"$name\" dav_owner='dav' dav_grp='administrators' dav_perm='111101101NN' makepath=\"yes\"/>" >> $STICKER
done

for file in `find vad/vsp/conductor/toolkit -type f -print | grep -v CVS | sort | cut -b9- `
do
    name=$file
echo "    <file type=\"$TYPE\" source=\"http\" target_uri=\"$name\" dav_owner='dav' dav_grp='administrators' dav_perm='110100100NN' makepath=\"yes\"/>" >> $STICKER
done

echo "  </resources>" >> $STICKER
echo "  <registry>" >> $STICKER
echo "  </registry>" >> $STICKER
echo "</sticker>" >> $STICKER

}

#==============================================================================
#  MAIN ROUTINE
#==============================================================================
rm -f conductor_dav.vad
rm -f conductor_filesystem.vad
rm -rf vad
rm -f $LOGFILE
rm -f vad.db vad.trx vad.log virtuoso.ini virtuoso.tdb

BANNER "CREATING VAD PACKAGE FOR VIRTUOSO CONDUCTOR (mkvad.sh)"

$ISQL -? 2>/dev/null 1>/dev/null
if [ $? -eq 127 ] ; then
    LOG "***ABORTED: CONDUCTOR PACKAGING, isql is not available"
    exit 1
fi
$SERVER -? 2>/dev/null 1>/dev/null
if [ $? -eq 127 ] ; then
    LOG "***ABORTED: CONDUCTOR PACKAGING, server is not available"
    exit 1
fi

curpwd=`pwd`
cd $curpwd

mkdir vad
mkdir vad/code
mkdir vad/vsp
mkdir vad/vsp/vspx
mkdir vad/vsp/vspx/browser
mkdir vad/vsp/vspx/browser/images
mkdir vad/vsp/vspx/browser/images/16x16
mkdir vad/code/conductor
mkdir vad/vsp/conductor
mkdir vad/vsp/conductor/dav
mkdir vad/vsp/conductor/dav/image
mkdir vad/vsp/conductor/dav/image/dav
mkdir vad/vsp/conductor/help
mkdir vad/vsp/conductor/images
mkdir vad/vsp/conductor/images/icons
mkdir vad/vsp/conductor/syntax
mkdir vad/vsp/conductor/toolkit
mkdir vad/vsp/conductor/toolkit/images
mkdir vad/vsp/conductor/toolkit/styles

cp -f $HOME/binsrc/xddl/xddl.xsd .
cp -f $HOME/binsrc/xddl/xddl_diff.xsl .
cp -f $HOME/binsrc/xddl/xddl_exec.xsl .
cp -f $HOME/binsrc/xddl/xddl_procs.xsd .
cp -f $HOME/binsrc/xddl/xddl_views.xsd .
cp -f $HOME/binsrc/xddl/xddl_tables.xsd .
cp -f $HOME/binsrc/xddl/xddl.sql vad/vsp/conductor
cp -f $HOME/binsrc/xddl/xddl_dav.sql vad/vsp/conductor
cp -f $HOME/binsrc/xddl/xddl_filesystem.sql vad/vsp/conductor

cp -f * vad/vsp/conductor
cp -f dav/* vad/vsp/conductor/dav
cp -f dav/image/* vad/vsp/conductor/dav/image
cp -f dav/image/dav/* vad/vsp/conductor/dav/image/dav
cp -f images/* vad/vsp/conductor/images
cp -f images/icons/* vad/vsp/conductor/images/icons
cp -f syntax/* vad/vsp/conductor/syntax
cp -f $HOME/binsrc/oat/toolkit/*.js vad/vsp/conductor/toolkit/.
cp -f $HOME/binsrc/oat/images/* vad/vsp/conductor/toolkit/images
cp -f $HOME/binsrc/oat/styles/* vad/vsp/conductor/toolkit/styles
cp -f $HOME/binsrc/vspx/vdir_helper.sql vad/vsp/conductor
cp -f help/*.xml vad/vsp/conductor/help

VERSION_INIT

CREATE_STICKER 0
CREATE_STICKER 1

cat mkvad.ini | sed -e "s/1112/$PORT/g" | sed -e "s/1113/$HTTPPORT/g" > virtuoso.ini
STOP_SERVER
START_SERVER

#cd $HOME/binsrc/vad
#
#  Load the VAD
#
#LOAD_SQL $HOME/binsrc/vad/vad.isql dba dba
cd $curpwd
DO_COMMAND "DB.DBA.VAD_PACK('$STICKER_DAV', '.', 'conductor_dav.vad')" dba dba
DO_COMMAND "DB.DBA.VAD_PACK('$STICKER_FS', '.', 'conductor_filesystem.vad')" dba dba

#
#  Checkpoint and shutdown the demo database
#
DO_COMMAND checkpoint
DO_COMMAND shutdown

chmod 644 conductor_dav.vad
chmod 644 conductor_filesystem.vad

#
#  Show final results of run
#
CHECK_LOG
RUN egrep  '"\*\*.*FAILED:|\*\*.*ABORTED:"' "$LOGFILE"
if test $STATUS -eq 0
then
	rm -f *.vad
	exit 1
fi

#
#  Clean ups
#
rm -f vad.db vad.trx vad.log virtuoso.ini virtuoso.tdb
rm -f xddl.xsd xddl_diff.xsl xddl_exec.xsl xddl_procs.xsd xddl_views.xsd xddl_tables.xsd
rm -rf vad


BANNER "COMPLETED VAD PACKAGING"
exit 0

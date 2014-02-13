#!/bin/sh
#
#  $Id$
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

# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL


VERSION="1.00.00"
LOGDIR=`pwd`
LOGFILE="${LOGDIR}/make__demo_vad.log"
STICKER_NAME="make__demo_vad.xml"
STICKER="${LOGDIR}/${STICKER_NAME}"
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
if [ -f ../../../autogen.sh ]
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
      for i in `find . -name 'Entries' | grep -v "vad/"`; do
          cat $i | grep "^[^D].*" | cut -f 3 -d "/" | sed -e "s/1\.//g" >> version.tmp
      done
      VERSION=`cat version.tmp | awk ' BEGIN { cnt=10250 } { cnt = cnt + $1 } END { printf "1.%02.02f", cnt/100 }'`
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
  $myrm -f virtuoso.ini 2>/dev/null
  $myrm -f *.pxa 2>/dev/null
}

directory_init() {
  LOG "Creating the VAD directory"
  mkdir vad
  mkdir vad/data
  mkdir vad/data/demo
  mkdir vad/data/demo/Thalia
  mkdir vad/data/demo/interop3
  mkdir vad/data/demo/interop3/wsdl
  mkdir vad/data/demo/interop3/wsdl/r4
  mkdir vad/data/demo/sql
  mkdir vad/data/demo/docsrc
  mkdir vad/data/demo/docsrc/DocBook
  mkdir vad/data/demo/docsrc/DocBook/ent
  mkdir vad/data/demo/docsrc/funcref
  mkdir vad/data/demo/images
  mkdir vad/data/demo/images/tree
  mkdir vad/data/demo/images/misc
  mkdir vad/data/demo/stylesheets
  mkdir vad/data/demo/stylesheets/sections
  mkdir vad/data/demo/releasenotes
  mkdir vad/data/demo/sample_data
  mkdir vad/data/demo/sample_data/images
  mkdir vad/data/demo/sample_data/images/art
  mkdir vad/data/demo/sample_data/images/flags
  mkdir vad/data/demo/xmlsql
  $RM -r flags flags.tar
  cat flags.tar.gz | gunzip - > flags.tar
  tar -xf flags.tar
  $RM -r art art.tar
  cat art.tar.gz | gunzip - > art.tar
  tar -xf art.tar
  cp -rf flags/* vad/data/demo/sample_data/images/flags
  cp -rf art/* vad/data/demo/sample_data/images/art
  $RM -r flags flags.tar
  $RM -r art art.tar
  cp -f CAT1                                                    vad/data/demo/sql
  cp -f CAT2                                                    vad/data/demo/sql
  cp -f CAT3                                                    vad/data/demo/sql
  cp -f CAT4                                                    vad/data/demo/sql
  cp -f CAT5                                                    vad/data/demo/sql
  cp -f CAT6                                                    vad/data/demo/sql
  cp -f CAT7                                                    vad/data/demo/sql
  cp -f CAT8                                                    vad/data/demo/sql
  cp -f EMP1                                                    vad/data/demo/sql
  cp -f EMP2                                                    vad/data/demo/sql
  cp -f EMP3                                                    vad/data/demo/sql
  cp -f EMP4                                                    vad/data/demo/sql
  cp -f EMP5                                                    vad/data/demo/sql
  cp -f EMP6                                                    vad/data/demo/sql
  cp -f EMP7                                                    vad/data/demo/sql
  cp -f EMP8                                                    vad/data/demo/sql
  cp -f EMP9                                                    vad/data/demo/sql
  cp -f thalia_test/* 											vad/data/demo/Thalia
  cp -f $HOME/docsrc/xmlsource/*                                vad/data/demo/docsrc
  cp -f $HOME/docsrc/xmlsource/DocBook/*                        vad/data/demo/docsrc/DocBook
  cp -f $HOME/docsrc/xmlsource/DocBook/ent/*                    vad/data/demo/docsrc/DocBook/ent
  cp -f $HOME/docsrc/xmlsource/funcref/*                        vad/data/demo/docsrc/funcref
  cp -f $HOME/docsrc/xmlsource/funcref/*                        vad/data/demo/docsrc/funcref
  cp -f $HOME/docsrc/images/*                                   vad/data/demo/images
  cp -f $HOME/docsrc/images/tree/*                              vad/data/demo/images/misc
  cp -f $HOME/docsrc/images/misc/*                              vad/data/demo/images/tree
  cp -f $HOME/docsrc/stylesheets/*                              vad/data/demo/stylesheets
  cp -f $HOME/docsrc/stylesheets/sections/doc.css               vad/data/demo/docsrc
  cp -f $HOME/docsrc/stylesheets/sections/openlink.css          vad/data/demo/docsrc
  cp -f $HOME/docsrc/releasenotes/*                             vad/data/demo/releasenotes
  cp -f grant_select.sql                                        vad/data/demo/sql
  cp -f nw.owl                                                  vad/data/demo/sql
  cp -f load_ontology_dav.sql                                   vad/data/demo/sql
  cp -f mkdemo_vad.sql                                          vad/data/demo/sql
  cp -f $HOME/binsrc/tutorial/rdfview/rd_v_1/rd_v_1.sql         vad/data/demo/sql
  cp -f sql_rdf.sql                                             vad/data/demo/sql
  cp -f tpc-h/tpch.sql	                                        vad/data/demo/sql
  cp -f countries_vad.sql                                       vad/data/demo/sql
  cp -f art_vad.sql                                             vad/data/demo/sql
  cp -f uninst.sql                                              vad/data/demo/sql
  cp -f uninst.sql                                              vad/data/demo/sql
  #cp -f $HOME/binsrc/dav/DET_RDFData.sql                        vad/data/demo/sql
  cp -f $HOME/binsrc/vsp/soapdemo/fishselect.sql                vad/data/demo/sql
  cp -f $HOME/binsrc/vsp/soapdemo/soap_validator.sql            vad/data/demo/sql
  cp -f $HOME/binsrc/vsp/soapdemo/interop-xsd.sql               vad/data/demo/sql
  cp -f $HOME/binsrc/vsp/soapdemo/round2.sql                    vad/data/demo/sql
  cp -f $HOME/binsrc/vsp/soapdemo/round3-D.sql                  vad/data/demo/sql
  cp -f $HOME/binsrc/vsp/soapdemo/extensions.wsdl.vsp           vad/data/demo/interop3/wsdl
  cp -f $HOME/binsrc/vsp/soapdemo/extensions_required.wsdl.vsp  vad/data/demo/interop3/wsdl

  cp -f $HOME/binsrc/vsp/soapdemo/r4/dime-doc.xsd               vad/data/demo/interop3/wsdl/r4
  cp -f $HOME/binsrc/vsp/soapdemo/r4/dime-rpc.xsd               vad/data/demo/interop3/wsdl/r4
  cp -f $HOME/binsrc/vsp/soapdemo/r4/simple-rpc-encoded.xsd     vad/data/demo/interop3/wsdl/r4  
  cp -f $HOME/binsrc/vsp/soapdemo/r4/simple-doc-literal-1.xsd   vad/data/demo/interop3/wsdl/r4  
  cp -f $HOME/binsrc/vsp/soapdemo/r4/simple-doc-literal-2.xsd   vad/data/demo/interop3/wsdl/r4  
  cp -f $HOME/binsrc/vsp/soapdemo/r4/simple-doc-literal-3.xsd   vad/data/demo/interop3/wsdl/r4  
  cp -f $HOME/binsrc/vsp/soapdemo/r4/complex-rpc-encoded.xsd    vad/data/demo/interop3/wsdl/r4  
  cp -f $HOME/binsrc/vsp/soapdemo/r4/round4xsd-1.xsd            vad/data/demo/interop3/wsdl/r4  
  cp -f $HOME/binsrc/vsp/soapdemo/r4/round4xsd-2.xsd            vad/data/demo/interop3/wsdl/r4  
  cp -f $HOME/binsrc/vsp/soapdemo/r4/round4xsd-3.xsd            vad/data/demo/interop3/wsdl/r4  
  cp -f $HOME/binsrc/vsp/soapdemo/r4/round4xsd-3.xsd            vad/data/demo/interop3/wsdl/r4  
  cp -f $HOME/binsrc/vsp/soapdemo/r4/round4xsd-4.xsd            vad/data/demo/interop3/wsdl/r4  
  cp -f $HOME/binsrc/vsp/soapdemo/r4/complex-doc-1.xsd          vad/data/demo/interop3/wsdl/r4  
  cp -f $HOME/binsrc/vsp/soapdemo/r4/complex-doc-2.xsd          vad/data/demo/interop3/wsdl/r4  
  cp -f $HOME/binsrc/vsp/soapdemo/r4/complex-doc-3.xsd          vad/data/demo/interop3/wsdl/r4  

  cp -f $HOME/binsrc/vsp/soapdemo/round3-E.sql                  vad/data/demo/sql
  cp -f $HOME/binsrc/vsp/soapdemo/round3-F_vad.sql              vad/data/demo/sql
  cp -f $HOME/binsrc/vsp/soapdemo/r4/dime-doc.sql               vad/data/demo/sql   
  cp -f $HOME/binsrc/vsp/soapdemo/r4/dime-rpc.sql               vad/data/demo/sql   
  cp -f $HOME/binsrc/vsp/soapdemo/r4/mime-doc.sql               vad/data/demo/sql
  cp -f $HOME/binsrc/vsp/soapdemo/r4/mime-rpc.sql               vad/data/demo/sql
  cp -f $HOME/binsrc/vsp/soapdemo/r4/simple-doc-literal.sql     vad/data/demo/sql
  cp -f $HOME/binsrc/vsp/soapdemo/r4/simple-rpc-encoded.sql     vad/data/demo/sql
  cp -f $HOME/binsrc/vsp/soapdemo/r4/complex-rpc-encoded_vad.sql    vad/data/demo/sql
  cp -f $HOME/binsrc/vsp/soapdemo/r4/complex-doc-literal_vad.sql    vad/data/demo/sql
  cp -f $HOME/binsrc/vsp/soapdemo/r4/xsd.sql                    vad/data/demo/sql
  cp -f $HOME/binsrc/vsp/soapdemo/r4/load_xsd_vad.sql           vad/data/demo/sql
  cp -f $HOME/binsrc/vsp/soapdemo/interop_client.sql            vad/data/demo/sql
  cp -f $HOME/binsrc/tests/suite/emp.xsl                        vad/data/demo/xmlsql/emp_orig.xsl
  cp -f $HOME/binsrc/tests/suite/emp_my.xsl                     vad/data/demo/xmlsql/emp.xsl
  cp -f $HOME/binsrc/tests/suite/docsrc/html_v.xsl              vad/data/demo/xmlsql/xtml_v.xsl
  cp -f $HOME/binsrc/tests/suite/docsrc/html_common_v.xsl       vad/data/demo/xmlsql/xtml_common_v.xsl

  cp -f $HOME/binsrc/tests/suite/xmlsql_vad.sql                 vad/data/demo/sql
  cp -f $HOME/binsrc/tests/suite/nwxml_vad.sql                  vad/data/demo/sql
  cp -f $HOME/binsrc/tests/suite/nwxml2_vad.sql                 vad/data/demo/sql
  cp -f $HOME/binsrc/tutorial/setup_tutorial.sql                vad/data/demo/sql
  cp -f $HOME/binsrc/tutorial/xml/usecases/usecases_vad.sql     vad/data/demo/sql
  cp -f $HOME/binsrc/samples/webapp/eNews/stylesheets/*         vad/data/demo/sql
  cp -f $HOME/binsrc/samples/webapp/eNews/css/*                 vad/data/demo/sql
  cp -f $HOME/binsrc/samples/webapp/eNews/eNews_vad.sql             vad/data/demo/sql
  cp -f $HOME/binsrc/samples/webapp/forums/def_vad.sql              vad/data/demo/sql
  cp -f $HOME/binsrc/samples/webapp/forums/func_vad.sql             vad/data/demo/sql

  cp -f check_demo.sql                                          vad/data/demo/sql
}

virtuoso_shutdown() {
  LOG "Shutdown $DSN ..."
  $ISQL $DSN dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=shutdown" $* >/dev/null
  sleep 10
}

sticker_init() {
  LOG "Demo Database VAD sticker creation..."
  echo "<?xml version=\"1.0\" encoding=\"ASCII\"?>" > $STICKER
  echo "<!DOCTYPE sticker SYSTEM \"vad_sticker.dtd\">" >> $STICKER
  echo "<sticker version=\"1.0.010505A\" xml:lang=\"en-UK\">" >> $STICKER
  echo "<caption>" >> $STICKER
  echo "  <name package=\"Demo\">" >> $STICKER
  echo "    <prop name=\"Title\" value=\"Demo Database\"/>" >> $STICKER
  echo "    <prop name=\"Developer\" value=\"OpenLink Software\"/>" >> $STICKER
  echo "    <prop name=\"Copyright\" value=\"(C) 1998-2014 OpenLink Software\"/>" >> $STICKER
  echo "    <prop name=\"Download\" value=\"http://www.openlinksw.com/virtuoso/demo/download\"/>" >> $STICKER
  echo "    <prop name=\"Download\" value=\"http://www.openlinksw.co.uk/virtuoso/demo/download\"/>" >> $STICKER
  echo "  </name>" >> $STICKER
  echo "  <version package=\"$VERSION\">" >> $STICKER
  echo "    <prop name=\"Release Date\" value=\"$PACKDATE\" />" >> $STICKER
  echo "    <prop name=\"Build\" value=\"Release, optimized\"/>" >> $STICKER
  echo "  </version>" >> $STICKER
  echo "</caption>" >> $STICKER
  echo "<procedures uninstallation=\"supported\">" >> $STICKER
  echo "  <sql purpose=\"pre-install\"></sql>" >> $STICKER
  echo "  <sql purpose=\"post-install\"></sql>" >> $STICKER
  echo "</procedures>" >> $STICKER
  echo "<ddls>" >> $STICKER
  echo "    <sql purpose=\"uninstall-check\"><![CDATA[ " >> $STICKER
  echo "     if (VAD_CHECK_VERSION ('tutorial') is not null) " >> $STICKER
  echo "       {" >> $STICKER
  echo "         VAD.DBA.VAD_FAIL_CHECK ('The tutorial package is not uninstalled. Please uninstall Tutorial first.'); " >> $STICKER
  echo "         result ('ERROR', 'The tutorial package is not uninstalled. Please uninstall Tutorial first.'); " >> $STICKER
  echo "         signal ('FATAL', 'The tutorial package is not uninstalled. Please uninstall Tutorial first.'); " >> $STICKER
  echo "       }" >> $STICKER
  echo "  ]]></sql>" >> $STICKER
  echo "    <sql purpose=\"pre-install\"><![CDATA[ " >> $STICKER
  echo "    if (lt (sys_stat ('st_dbms_ver'), '$NEED_VERSION')) " >> $STICKER
  echo "      { " >> $STICKER
  echo "         result ('ERROR', 'The demo package requires server version $NEED_VERSION or greater'); " >> $STICKER
  echo "         signal ('FATAL', 'The demo package requires server version $NEED_VERSION or greater'); " >> $STICKER
  echo "      } " >> $STICKER
  echo "     if (VAD_CHECK_VERSION ('demo') is not null and VAD_CHECK_VERSION ('Demo') is null) " >> $STICKER
  echo "       {" >> $STICKER
  echo "          DB.DBA.VAD_RENAME ('demo', 'Demo');" >> $STICKER
  echo "       }" >> $STICKER
  echo "  ]]></sql>" >> $STICKER
  echo "  <sql purpose=\"post-install\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/mkdemo_vad.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/countries_vad.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/art_vad.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/grant_select.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/fishselect.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/soap_validator.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/interop-xsd.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/round2.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/round3-D.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/round3-E.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/round3-F_vad.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/dime-doc.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/dime-rpc.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/mime-doc.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/mime-rpc.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/simple-doc-literal.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/simple-rpc-encoded.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/complex-rpc-encoded_vad.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/complex-doc-literal_vad.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/xsd.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/load_xsd_vad.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/interop_client.sql', 1, 'report', 1);" >> $STICKER
  echo "      VAD.DBA.VAD_DAV_MOVE('/DAV/VAD/demo/docsrc/', '/DAV/docsrc/');" >> $STICKER
  echo "      VAD.DBA.VAD_DAV_MOVE('/DAV/VAD/demo/images/', '/DAV/images/');" >> $STICKER
  echo "      VAD.DBA.VAD_DAV_MOVE('/DAV/VAD/demo/interop3/', '/DAV/interop3/');" >> $STICKER
  echo "      VAD.DBA.VAD_DAV_MOVE('/DAV/VAD/demo/Thalia/', '/DAV/Thalia/');" >> $STICKER
  echo "      VAD.DBA.VAD_DAV_MOVE('/DAV/VAD/demo/releasenotes/', '/DAV/releasenotes/');" >> $STICKER
  echo "      VAD.DBA.VAD_DAV_MOVE('/DAV/VAD/demo/sample_data/', '/DAV/sample_data/');" >> $STICKER
  echo "      VAD.DBA.VAD_DAV_MOVE('/DAV/VAD/demo/stylesheets/', '/DAV/stylesheets/');" >> $STICKER
  echo "      VAD.DBA.VAD_DAV_MOVE('/DAV/VAD/demo/xmlsql/', '/DAV/xmlsql/');" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/xmlsql_vad.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/nwxml_vad.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/nwxml2_vad.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/setup_tutorial.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/usecases_vad.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/eNews_vad.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/def_vad.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/func_vad.sql', 1, 'report', 1);" >> $STICKER
  #echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/DET_RDFData.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/sql_rdf.sql', 1, 'report', 1);" >> $STICKER
  #echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/tpch.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/rd_v_1.sql', 1, 'report', 1);" >> $STICKER  
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/Thalia/virtuoso_sql_schema_generation.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/Thalia/thalia_sql_to_rdf_views_generation.sql', 1, 'report', 1);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/load_ontology_dav.sql', 1, 'report', 1);" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "  <sql purpose=\"pre-uninstall\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "      VAD.DBA.VAD_DAV_MOVE('/DAV/docsrc/', '/DAV/VAD/demo/docsrc/');" >> $STICKER
  echo "      VAD.DBA.VAD_DAV_MOVE('/DAV/images/', '/DAV/VAD/demo/images/');" >> $STICKER
  echo "      VAD.DBA.VAD_DAV_MOVE('/DAV/interop3/', '/DAV/VAD/demo/interop3/');" >> $STICKER
  echo "      VAD.DBA.VAD_DAV_MOVE('/DAV/releasenotes/', '/DAV/VAD/demo/releasenotes/');" >> $STICKER
  echo "      VAD.DBA.VAD_DAV_MOVE('/DAV/sample_data/', '/DAV/VAD/demo/sample_data/');" >> $STICKER
  echo "      VAD.DBA.VAD_DAV_MOVE('/DAV/stylesheets/', '/DAV/VAD/demo/stylesheets/');" >> $STICKER
  echo "      VAD.DBA.VAD_DAV_MOVE('/DAV/xmlsql/', '/DAV/VAD/demo/xmlsql/');" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/demo/sql/uninst.sql', 1, 'report', 1);" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "</ddls>" >> $STICKER
  echo "<resources>" >> $STICKER
  cd vad/data/demo 2>/dev/null
  oldIFS="$IFS"
  IFS='
'
  for file in `find docsrc/* -type f | grep -v '/CVS'`
  do
    echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"demo/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
  done
  for file in `find images/* -type f | grep -v '/CVS'`
  do
    echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"demo/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  done
  for file in `find releasenotes/* -type f -o -type l | grep -v '/CVS'`
  do
    echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"demo/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  done
  for file in `find sample_data/* -type f -o -type l | grep -v '/CVS'`
  do
    echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"demo/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  done
  for file in `find stylesheets/* -type f -o -type l | grep -v '/CVS'`
  do
    echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"demo/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  done
  for file in `find xmlsql/* -type f -o -type l | grep -v '/CVS'`
  do
    echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"demo/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  done
  for file in `find sql/* -type f -o -type l | grep -v '/CVS'`
  do
    echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"demo/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  done
  for file in `find interop3/* -type f -o -type l | grep -v '/CVS'`
  do
    echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"demo/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"110100100NN\" makepath=\"yes\"/>" >> $STICKER
  done
  for file in `find Thalia/* -type f | grep -v '/CVS'`
  do
    echo "  <file overwrite=\"yes\" type=\"dav\" source=\"data\" target_uri=\"demo/$file\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"111101101NN\" makepath=\"yes\"/>" >> $STICKER
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
  do_command_safe $DSN "DB.DBA.VAD_PACK('$STICKER_NAME', '.', 'demo_dav.vad')"
  do_command_safe $DSN "commit work"
  do_command_safe $DSN "checkpoint"
}

BANNER "STARTED PACKAGING DEMO VAD"
STOP_SERVER
$myrm $LOGFILE 2>/dev/null
directory_clean
VERSION_INIT
directory_init
virtuoso_init
sticker_init
vad_create
virtuoso_shutdown
chmod 644 demo_dav.vad
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

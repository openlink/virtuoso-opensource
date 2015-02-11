#!/bin/sh
#
#  mkdoc.sh
#
#  $Id$
#
#  Creates Virtuoso Documentation
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2015 OpenLink Software
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
HOST=${HOST-localhost}
SERVER=${SERVER-}

DSN=$HOST:$PORT
SILENT=${SILENT-0}
MAKEDOCS=${MAKEDOCS-0}
HTMLDOCS=${HTMLDOCS-1}
DEMODB=${DEMODB}
LOGFILE=mkdoc.output
LOGDIR=`pwd`
ININAME=mkdemo.ini
ISQL=${ISQL-isql}

FEEDS_ADDRESS=$1

#echo "log file is: $LOGFILE";

STICKER_DAV="doc_vad_dav.xml"
STICKER_FS="doc_vad_filesystem.xml"
VAD_NAME="doc"
VAD_NAME_DEVEL="$VAD_NAME"_filesystem.vad
VAD_NAME_RELEASE="$VAD_NAME"_dav.vad
VERSION="1.1.18"
PACKDATE=`date +"%Y-%m-%d %H:%M"`

HOST_OS=`uname -s | grep WIN`
if [ "x$HOST_OS" != "x" ]
then
  TEMPFILE="`cygpath -m $TMP/isql.$$`"
  HOME="`cygpath -m $HOME`"
  LN="cp -rf"
  RM="rm -rf"
else
  TEMPFILE=/tmp/isql.$$
  LN="ln -f -s"
  RM="rm -f"
fi

CP="cp -f"

if [ "z$SERVER" = "z" ]  
then
    if [ "x$HOST_OS" != "x" ]
    then
	SERVER=virtuoso-odbc-t.exe
    else
	SERVER=virtuoso
    fi
fi

#. $HOME/binsrc/tests/suite/test_fn.sh

if [ -f /usr/xpg4/bin/rm ]
then
  myrm=/usr/xpg4/bin/rm
else
  myrm=$RM
fi

#==============================================================================
#  Standard functions
#==============================================================================
LOG()
{
    if test $SILENT -eq 1
    then
	echo "$*"	>> $LOGFILE
    else
	echo "$*"	| tee -a $LOGFILE
    fi
}

ECHO()
{
    echo "$*"		| tee -a $LOGDIR/$LOGFILE
}


RUN()
{
    echo "+ $*"		>> $LOGDIR/$LOGFILE

    STATUS=1
    if test $SILENT -eq 1
    then
	eval $*		>> $LOGDIR/$LOGFILE 2>/dev/null
    else
	eval $*		>> $LOGDIR/$LOGFILE
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


START_SERVER()
{
   if [ "z$DEMODB" = "z" ]
   then
       timeout=180

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
       	ECHO "***FAILED: Could not start Virtuoso DOC Server within $timeout seconds"
       	exit 1
           fi
       done
   fi
}

STOP_SERVER()
{
    if [ "z$DEMODB" = "z" ]
    then
	RUN $ISQL $DSN dba dba '"EXEC=raw_exit();"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
    fi
}


DO_COMMAND()
{
  command=$1
  uid=${2-dba}
  passwd=${3-dba}
  $ISQL $DSN $uid $passwd ERRORS=stdout VERBOSE=OFF PROMPT=OFF "EXEC=$command" 	>> $LOGDIR/$LOGFILE
  if test $? -ne 0
  then
    ECHO "***FAILED: $command"
  else
    ECHO "PASSED: $command"
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

CHECK_LOG()
{
    passed=`cat $LOGDIR/$LOGFILE | cut -b -200 | grep "PASSED:" | wc -l`
    failed=`cat $LOGDIR/$LOGFILE | cut -b -200 | grep "\*\*\*.*FAILED:" | wc -l`
    aborted=`cat $LOGDIR/$LOGFILE | cut -b -200 | grep "\*\*\*.*ABORTED:" | wc -l`

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

#
# make the whole documentation into an XPER
#


directory_clean () 
{
    LOG "Directory clean..."
    $myrm -rf vad 2>/dev/null
    $myrm -rf vad.* 2>/dev/null

    if [ "z$DEMODB" = "z" ]  
    then
	$myrm -rf mkdoc.log 2>/dev/null
	$myrm -rf doc.db 2>/dev/null
	$myrm -rf doc.trx 2>/dev/null
	$myrm -rf doc.tdb 2>/dev/null
	$myrm -rf doc.log 2>/dev/null
    fi
    # $myrm -rf virtuoso.ini 2>/dev/null
}

directory_init() {
LOG "Directory init..."
  mkdir vad
  mkdir vad/data
  mkdir vad/data/doc
#  mkdir vad/data/doc/html
  mkdir vad/data/doc/code
  mkdir vad/data/doc/images
  mkdir vad/data/doc/images/inst
  mkdir vad/data/doc/images/rth
  mkdir vad/data/doc/images/mac
  mkdir vad/data/doc/images/misc
  mkdir vad/data/doc/images/tree
  mkdir vad/data/doc/images/ui

  #mkdir vad/data/doc/pdf
  #$LN docsrc/pdf/*.html vad/data/doc/pdf/.

  $CP -f $HOME/binsrc/vsp/doc/* vad/data/doc/.
  $CP -f $HOME/docsrc/vsp/doc/* vad/data/doc/.
  # the later has latest stuff in and should be used.

#  $CP docsrc/html_virt/*.html vad/data/doc/html/.
#  $CP docsrc/html_virt/*.css vad/data/doc/html/.
#  $CP docsrc/html_virt/*.ico vad/data/doc/html/.
#  $CP docsrc/html_virt/*.rdf vad/data/doc/html/.
  $CP -R docsrc/html_virt vad/data/doc/html
  $CP docsrc/html_virt/*.css vad/data/doc/.

  $CP docsrc/images/*.jpg vad/data/doc/images/.
  $CP docsrc/images/*.gif vad/data/doc/images/.
  $CP docsrc/images/*.png vad/data/doc/images/.

  $CP docsrc/images/inst/*.png vad/data/doc/images/inst/.

  $CP docsrc/images/rth/*.jpg vad/data/doc/images/rth/.
  $CP docsrc/images/rth/*.png vad/data/doc/images/rth/.

  $CP docsrc/images/mac/*.jpg vad/data/doc/images/mac/.
  $CP docsrc/images/mac/*.gif vad/data/doc/images/mac/.
  $CP docsrc/images/mac/*.png vad/data/doc/images/mac/.

  $CP docsrc/images/misc/*.jpg vad/data/doc/images/misc/.
  $CP docsrc/images/misc/*.gif vad/data/doc/images/misc/.

  $CP docsrc/images/tree/*.gif vad/data/doc/images/tree/.

  $CP docsrc/images/ui/*.jpg vad/data/doc/images/ui/.
  $CP docsrc/images/ui/*.gif vad/data/doc/images/ui/.
  $CP docsrc/images/ui/*.png vad/data/doc/images/ui/.

  cp mksearch.sql vad/data/doc/code/.
  cp drop.sql vad/data/doc/code/.
  cp doc_sql_rdf.sql vad/data/doc/code/.
  #cp -f $HOME/binsrc/dav/DET_RDFData.sql vad/data/doc/code/.
}

sticker_init() {
  ISDAV=$1
  if [ "$ISDAV" = "1" ] ; then
    BASE_PATH="/DAV/VAD"
    TYPE="dav"
    STICKER=$STICKER_DAV
  else
    BASE_PATH="/vad/vsp"
    TYPE="http"
    STICKER=$STICKER_FS
  fi
  LOG "VAD Documentation sticker $STICKER creation..."
  echo "<?xml version=\"1.0\" encoding=\"ASCII\"?>" > $STICKER
  echo "<!DOCTYPE sticker SYSTEM \"vad_sticker.dtd\">" >> $STICKER
  echo "<sticker version=\"1.0.010505A\" xml:lang=\"en-UK\">" >> $STICKER
  echo "<caption>" >> $STICKER
  echo "  <name package=\"doc\">" >> $STICKER
  echo "    <prop name=\"Title\" value=\"Virtuoso Documentation\"/>" >> $STICKER
  echo "    <prop name=\"Developer\" value=\"OpenLink Software\"/>" >> $STICKER
  echo "    <prop name=\"Copyright\" value=\"(C) 1998-2015 OpenLink Software\"/>" >> $STICKER
  echo "    <prop name=\"Download\" value=\"http://www.openlinksw.com/virtuoso\"/>" >> $STICKER
  echo "    <prop name=\"Download\" value=\"http://www.openlinksw.co.uk/virtuoso\"/>" >> $STICKER
  echo "  </name>" >> $STICKER
  echo "  <version package=\"$VERSION\">" >> $STICKER
  echo "    <prop name=\"Release Date\" value=\""`date +"%Y-%m-%d %H:%M"`"\"/>" >> $STICKER
  echo "    <prop name=\"Build\" value=\"Release\"/>" >> $STICKER
  echo "  </version>" >> $STICKER
  echo "</caption>" >> $STICKER
  echo "<dependencies/>" >> $STICKER
  echo "<procedures uninstallation=\"supported\">" >> $STICKER
  echo "  <sql purpose=\"pre-install\"></sql>" >> $STICKER
  echo "  <sql purpose=\"post-install\"></sql>" >> $STICKER
  echo "</procedures>" >> $STICKER
  echo "<ddls>" >> $STICKER
  echo "  <sql purpose=\"pre-install\"></sql>" >> $STICKER
  echo "  <sql purpose=\"post-install\">" >> $STICKER
  echo "    <![CDATA[" >> $STICKER
  echo "      registry_set('_doc_path_', '"$BASE_PATH"/doc/');" >> $STICKER
  echo "      registry_set('_doc_version_', '$VERSION');" >> $STICKER
  echo "      registry_set('_doc_build_', '$PACKDATE');" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH"/doc/code/drop.sql', 1, 'report', $ISDAV);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH"/doc/code/mksearch.sql', 1, 'report', $ISDAV);" >> $STICKER
  #echo "      DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH"/doc/code/DET_RDFData.sql', 1, 'report', $ISDAV);" >> $STICKER
  echo "      DB.DBA.VAD_LOAD_SQL_FILE('"$BASE_PATH"/doc/code/doc_sql_rdf.sql', 1, 'report', $ISDAV);" >> $STICKER
  echo "      DB.DBA.VHOST_REMOVE(lpath=>'/doc',del_vsps => 1);" >> $STICKER
  echo "      DB.DBA.VHOST_REMOVE(lpath=>'/doc/html',del_vsps => 1);" >> $STICKER
  echo "      DB.DBA.VHOST_REMOVE(lpath=>'/doc/pdf');" >> $STICKER
  echo "      DB.DBA.VHOST_REMOVE(lpath=>'/doc/images',del_vsps => 1);" >> $STICKER
  echo "      DB.DBA.VHOST_DEFINE(" >> $STICKER
  echo "        lpath    => '/doc'," >> $STICKER
  echo "        ppath    => '$BASE_PATH/doc/'," >> $STICKER
  echo "        is_dav   => $ISDAV," >> $STICKER
  echo "        vsp_user => 'dba'," >> $STICKER
  echo "        is_brws  => 0," >> $STICKER
  echo "        def_page => 'index.html'" >> $STICKER
  echo "      )" >> $STICKER
  echo "      ;" >> $STICKER
  echo "      DB.DBA.VHOST_DEFINE(lpath=>'/doc/pdf',ppath=>'/doc/pdf/');" >> $STICKER
#  echo "      DB.DBA.VHOST_DEFINE(" >> $STICKER
#  echo "        lpath    => '/doc/images'," >> $STICKER
#  echo "        ppath    => '$BASE_PATH/doc/images/'," >> $STICKER
#  echo "        is_dav   => $ISDAV," >> $STICKER
#  echo "        vsp_user => 'dba'," >> $STICKER
#  echo "        is_brws  => 0" >> $STICKER
#  echo "      )" >> $STICKER
#  echo "      ;" >> $STICKER
  echo "" >> $STICKER
  if [ "x$FEEDS_ADDRESS" != "x" ]
  then

    echo "  DELETE FROM DB.DBA.RDF_QUAD WHERE G = DB.DBA.RDF_MAKE_IID_OF_QNAME ('$FEEDS_ADDRESS');" >> $STICKER
    for file in `find vad -type f -name "*siocrdf.vsp" -print | LC_ALL=C sort`
    do
      name=`echo "$file" | cut -b10-`
      if [ "$TYPE" = "dav" ]
      then
        echo " SIOC_REMOVE_CHARS_MAIN('http://local.virt$BASE_PATH/$name','$FEEDS_ADDRESS');" >> $STICKER
      else
        echo " SIOC_REMOVE_CHARS_MAIN('file:/$BASE_PATH/$name','$FEEDS_ADDRESS');" >> $STICKER
      fi
    done

  fi
  echo "" >> $STICKER
  echo "    ]]>" >> $STICKER
  echo "  </sql>" >> $STICKER
  echo "  <sql purpose=\"pre-uninstall\"></sql>" >> $STICKER
  echo "</ddls>" >> $STICKER

  echo "<resources>" >> $STICKER

  for file in `find vad -type f -print | LC_ALL=C sort`
  do
    name=`echo "$file" | cut -b10-`
    perms='110100100NN'
    echo "$name" | egrep -e '.vspx$' > /dev/null && perms='111101101NN'
    echo "$name" | egrep -e '.vsp$' > /dev/null && perms='111101101NN'
    
    echo "  <file type=\"$TYPE\" overwrite=\"yes\" source=\"data\" target_uri=\"$name\" dav_owner=\"dav\" dav_grp=\"administrators\" dav_perm=\"$perms\" makepath=\"yes\"/>" >> $STICKER
  done

  echo "</resources>" >> $STICKER
  echo "<registry>" >> $STICKER
  echo "</registry>" >> $STICKER
  echo "</sticker>" >> $STICKER
}


vad_create() {
  STICKER=$1
  V_NAME=$2
  do_command_safe $DSN "DB.DBA.VAD_PACK('$STICKER', '.', '$V_NAME')"
  do_command_safe $DSN "commit work"
  do_command_safe $DSN "checkpoint"
}

#==============================================================================
#  MAIN ROUTINE
#==============================================================================

if [ "z$DEMODB" = "z" ] ; then
  rm -f doc.db doc.trx doc.log doc.lck mkdoc.output
  #virtuoso.ini
fi

BANNER "CREATING DOC DATABASE (mkdoc.sh)"

$ISQL -? 2>/dev/null 1>/dev/null 
if [ $? -eq 127 ] ; then
    LOG "***ABORTED: DOCUMENTATION PACKAGING, isql is not available"
    exit 1
fi
$SERVER -? 2>/dev/null 1>/dev/null 
if [ $? -eq 127 ] ; then
    LOG "***ABORTED: DOCUMENTATION PACKAGING, server is not available"
    exit 1
fi

curpwd=`pwd`
cd $HOME/binsrc/sqldoc
sh vspx_doc.sh
cd "$curpwd"

cat $ININAME | sed -e "s/1112/$PORT/g" | sed -e "s/1113/$HTTPPORT/g" | sed -e "s/demo\./doc\./g" > virtuoso.ini

STOP_SERVER
directory_clean
START_SERVER

BREAK

$RM vspx
$RM docsrc

ECHO "Copying from docsrc.."
$LN $HOME/docsrc docsrc
ECHO "Copying from vspx.."
$LN $HOME/binsrc/vspx vspx

if [ "x$HOST_OS" != "x" ]
then
    if [ -d docsrc/html_virt ]
    then 
      # too long arg list error under Cygwin, therefore go to the dir and erase with mask.  
      # rm -rf docsrc/html_virt/*.html
      cd docsrc/html_virt
      rm -f *.html
      cd "$curpwd"       
    else   
  mkdir docsrc/html_virt
    fi	
  cp $HOME/docsrc/stylesheets/sections/*.css docsrc/html_virt
else
  rm -rf $HOME/docsrc/html_virt/*html
  mkdir $HOME/docsrc/html_virt/
  cp $HOME/docsrc/stylesheets/sections/*.css $HOME/docsrc/html_virt
fi


if test $HTMLDOCS -eq 1
then
  ECHO "Producing vspx.."
  LOAD_SQL mkvspxdoc.sql dba dba
  ECHO "Producing html.."
  LOAD_SQL mkdoc_new.sql dba dba
  
  # Building routines - we make a temp sql and load it depending if we are making with/without feeds
  TEMP_SQL=temp.sql
  echo "" > $TEMP_SQL
  if [ "x$FEEDS_ADDRESS" = "x" ]
  then
    echo "MKDOC_DO_ALL('docsrc/xmlsource/virtdocs.xml', 'docsrc/html_virt', vector());" >> $TEMP_SQL
  else
    # We are going to need xsl files from binsrc/vsp/doc
    mkdir docsrc/doc
    cp $HOME/binsrc/vsp/doc/*.xsl docsrc/doc
    echo "MKDOC_DO_FEEDS('docsrc/xmlsource/virtdocs.xml', 'docsrc/html_virt', vector('serveraddr', '$FEEDS_ADDRESS'));" >> $TEMP_SQL
    echo "ECHO BOTH \$IF \$EQU \$STATE OK  \"PASSED\" \"***FAILED\";" >> $TEMP_SQL
    echo "ECHO BOTH \": Rendering FEEDS docs: STATE=\" \$STATE \" MESSAGE=\" \$MESSAGE \"\\n\";" >> $TEMP_SQL
    echo "MKDOC_DO_ALL('docsrc/xmlsource/virtdocs.xml', 'docsrc/html_virt', vector('rss', 'yes','serveraddr', '$FEEDS_ADDRESS'));" >> $TEMP_SQL
  fi
  echo "ECHO BOTH \$IF \$EQU \$STATE OK  \"PASSED\" \"***FAILED\";" >> $TEMP_SQL
  echo "ECHO BOTH \": Rendering HTML docs: STATE=\" \$STATE \" MESSAGE=\" \$MESSAGE \"\\n\";" >> $TEMP_SQL
  
  echo "MKDOC_PDF('docsrc/xmlsource/virtdocs.xml', 'docsrc/pdf', vector());" >> $TEMP_SQL
  echo "ECHO BOTH \$IF \$EQU \$STATE OK  \"PASSED\" \"***FAILED\";" >> $TEMP_SQL
  echo "ECHO BOTH \": Rendering PDF HTML source: STATE=\" \$STATE \" MESSAGE=\" \$MESSAGE \"\\n\";" >> $TEMP_SQL
  LOAD_SQL $TEMP_SQL dba dba
  rm -rf docsrc/doc
  rm -f $TEMP_SQL

  # under cygwin html_virt is a copy (see above LN)
  if [ "x$HOST_OS" != "x" ]
  then
    for _fil in `ls docsrc/html_virt`
    do
      chmod 644 docsrc/html_virt/$_fil
    done
    rm -rf $HOME/docsrc/html_virt
    cp -a docsrc/html_virt $HOME/docsrc/.
    cp docsrc/pdf/*.html $HOME/docsrc/pdf/.
  fi
fi

# Build the PDF docs if HTMLDOC is installed
if [ "z$VOS" = "z1" -a "z$HTMLDOC" != "z" -a -x "$HTMLDOC" ]
then
  ECHO "Building the PDF version"  
  cd $HOME/docsrc/pdf
  $HTMLDOC --batch htmldoc_pdf.book 2> /dev/null 1> /dev/null
  cd "$curpwd"
fi

ECHO '----------------------'
ECHO 'Documentation Application VAD create'
ECHO '----------------------'


directory_init
sticker_init 1
vad_create $STICKER_DAV $VAD_NAME_RELEASE

DO_COMMAND checkpoint
if [ "z$DEMODB" = "z" ]  
then
    DO_COMMAND shutdown
fi
STOP_SERVER

chmod 644 $VAD_NAME_RELEASE
$RM vspx
$RM docsrc
#
#  Checkpoint and shutdown the demo database
#

BREAK

BANNER "COMPLETED DOCUMENTATION demo (mkdoc.sh)"
CHECK_LOG
RUN egrep  '"\*\*.*FAILED:|\*\*.*ABORTED:"' "$LOGFILE"
if test $STATUS -eq 0
then
	$myrm -f "$VAD_NAME_RELEASE"
	exit 1
fi

BANNER "COMPLETED VAD PACKAGING"
directory_clean

exit 0

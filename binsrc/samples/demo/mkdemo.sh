#!/bin/sh
#
#  mkdemo.sh
#
#  $Id$
#
#  Creates a demo database
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

DSN="$HOST:$PORT"
LOGFILE=mkdemo.output
DEMO=`pwd`
export DEMO LOGFILE
SILENT=${SILENT-0}
MAKEDOCS=${MAKEDOCS-0}
HTMLDOCS=${HTMLDOCS-1}
ISQL=${ISQL-isql}
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
    RM="rm -rf"
fi

VOS=0
if [ "z$SERVER" = "z" ]  
then
    if [ "x$HOST_OS" != "x" ]
    then
	SERVER=virtuoso-odbc-t.exe
    else
	SERVER=virtuoso
    fi
fi

if [ -f ../../../autogen.sh ]
then
    VOS=1
fi

# Default ports
DBSQLPORT=1111
DBHTTPPORT=8889
DEMOSQLPORT=1112
DEMOHTTPPORT=8890

export DEMODB

#==============================================================================
#  Standard functions
#==============================================================================

ECHO()
{
    echo "$*"		| tee -a $DEMO/$LOGFILE
}


RUN()
{
    echo "+ $*"		>> $DEMO/$LOGFILE

    STATUS=1
    if test $SILENT -eq 1
    then
	eval $*		>> $DEMO/$LOGFILE 2>/dev/null
    else
	eval $*		>> $DEMO/$LOGFILE
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
  timeout=180

  ECHO "Starting Virtuoso DEMO server ..."
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
	  ECHO "***FAILED: Could not start Virtuoso DEMO Server within $timeout seconds"
	  exit 1
	fi
  done
}

STOP_SERVER()
{
    RUN $ISQL $DSN dba dba '"EXEC=raw_exit();"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
}


DO_COMMAND()
{
  command=$1
  uid=${2-dba}
  passwd=${3-dba}
  $ISQL $DSN $uid $passwd ERRORS=stdout VERBOSE=OFF PROMPT=OFF "EXEC=$command" 	>> $DEMO/$LOGFILE
  if test $? -ne 0
  then
    ECHO "***FAILED: $command"
  else
    ECHO "PASSED: $command"
  fi
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


#==============================================================================
#  MAIN ROUTINE
#==============================================================================
rm -f demo.db demo.trx demo.log demo.lck mkdemo.output virtuoso.ini

if [ $VOS -eq 1 ]
then
    if [ "x$HOST_OS" = "x" ]
    then
	(cd $HOME/appsrc ; make)
	(cd $HOME/binsrc/b3s ; make)
	(cd $HOME/binsrc/bpel; make)
	(cd $HOME/binsrc/isparql ; make)
	(cd $HOME/binsrc/rdf_mappers ; make)
	(cd $HOME/binsrc/rdb2rdf ; make)
	(cd $HOME/binsrc/samples/image_magick ; make)
	(cd $HOME/binsrc/samples/sparql_demo ; make)
	(cd $HOME/binsrc/tutorial ; make)
	(cd $HOME/binsrc/yacutia ; make)
    fi
else
    (cd $HOME/binsrc/bpel; make )
    [ -f doc_dav.vad ] || (chmod +x mkdoc.sh ; ./mkdoc.sh)
fi


BANNER "CREATING DEMO DATABASE (mkdemo.sh)"

$ISQL -? 2>/dev/null 1>/dev/null 
if [ $? -eq 127 ] ; then
    ECHO "***ABORTED: CREATING DEMO DATABASE, isql is not available"
    exit 1
fi
$SERVER -? 2>/dev/null 1>/dev/null 
if [ $? -eq 127 ] ; then
    ECHO "***ABORTED: CREATING DEMO DATABASE, server is not available"
    exit 1
fi

cat mkdemo.ini | sed -e "s/1112/$PORT/g" | sed -e "s/1113/$HTTPPORT/g" > virtuoso.ini

# MAKE the demo.ini

if [ $VOS -eq 1 ]
then

    cat >> virtuoso.ini <<-END_CFG
	[Plugins]
	LoadPath = ./plugin
	Load1    = plain, wikiv
	Load2    = plain, mediawiki
	Load3    = plain, creolewiki
	Load4    = plain, im
END_CFG

    if [ ! -d plugin ] 
    then
	mkdir plugin
    fi

    if [ "x$HOST_OS" != "x" ]
    then
	cp -f $BINDIR/im.dll plugin
	cp -f $BINDIR/wikiv.dll plugin
	cp -f $BINDIR/mediawiki.dll plugin
	cp -f $BINDIR/creolewiki.dll plugin
    else
	cp -f $HOME/binsrc/samples/image_magick/.libs/im.so plugin
	cp -f $HOME/appsrc/ODS-Wiki/plugin/.libs/wikiv.so plugin
	cp -f $HOME/appsrc/ODS-Wiki/plugin/.libs/mediawiki.so plugin
	cp -f $HOME/appsrc/ODS-Wiki/plugin/.libs/creolewiki.so plugin
    fi

    HOSTNAME=`uname -n`
    if [ $VOS -eq 1 -a "x$HOST_OS" != "x" ]
    then
	BINDIR=`cygpath -m "$BINDIR"`    
	PLUGINDIR=`echo "$BINDIR" | sed -e 's#/#\\\/#g; s# #\\ #g; s#-#\\-#g'` 
    else
	PLUGINDIR=`echo "$prefix/lib"| sed -e 's#/#\\\/#g; s# #\\ #g; s#-#\\-#g'` 
    fi
fi

STOP_SERVER
START_SERVER

#
#  Check status
#
RUN $ISQL $DSN dba dba '"EXEC=status();"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
  ECHO "***FAILED: status()"
  rm -f demo.db demo.trx demo.log demo.lck virtuoso.pxa
  exit 1
else
  ECHO "PASSED: status()"
fi

BREAK
ECHO "Collecting and installing VAD packages"

$LN $HOME/binsrc/b3s/fct_dav.vad .
$LN $HOME/binsrc/bpel/bpel_dav.vad .
$LN $HOME/binsrc/isparql/isparql_dav.vad .
$LN $HOME/binsrc/rdf_mappers/rdf_mappers_dav.vad .
$LN $HOME/binsrc/rdb2rdf/rdb2rdf_dav.vad .
$LN $HOME/binsrc/samples/sparql_demo/sparql_demo_dav.vad .
$LN $HOME/binsrc/tutorial/tutorial_dav.vad .
$LN $HOME/binsrc/yacutia/conductor_dav.vad .

[ -f conductor_dav.vad ] && DO_COMMAND "vad_install ('conductor_dav.vad')" dba dba
[ -f fct_dav.vad ] && DO_COMMAND "vad_install ('fct_dav.vad')" dba dba
[ -f doc_dav.vad ] && DO_COMMAND "vad_install ('doc_dav.vad')" dba dba
[ -f rdf_mappers_dav.vad ] && DO_COMMAND "vad_install ('rdf_mappers_dav.vad')" dba dba
[ -f rdb2rdf_dav.vad ] && DO_COMMAND "vad_install ('rdb2rdf_dav.vad')" dba dba
[ -f isparql_dav.vad ] && DO_COMMAND "vad_install ('isparql_dav.vad')" dba dba
[ -f bpel_dav.vad ] && DO_COMMAND "vad_install ('bpel_dav.vad')" dba dba
[ -f sparql_demo_dav.vad ] && DO_COMMAND "vad_install ('sparql_demo_dav.vad')" dba dba


#
#  OpenLink Data Spaces
#
if [ $VOS -eq 1 ]
then
    for f in `find $HOME/appsrc -name '*_dav.vad' -print`
    do
	$LN $f .
    done
    [ -f ods_framework_dav.vad ] && DO_COMMAND "vad_install ('ods_framework_dav.vad')" dba dba
    [ -f ods_addressbook_dav.vad ] && DO_COMMAND "vad_install ('ods_addressbook_dav.vad')" dba dba
    [ -f ods_blog_dav.vad ] && DO_COMMAND "vad_install ('ods_blog_dav.vad')" dba dba
    [ -f ods_bookmark_dav.vad ] && DO_COMMAND "vad_install ('ods_bookmark_dav.vad')" dba dba
    [ -f ods_briefcase_dav.vad ] && DO_COMMAND "vad_install ('ods_briefcase_dav.vad')" dba dba
    [ -f ods_calendar_dav.vad ] && DO_COMMAND "vad_install ('ods_calendar_dav.vad')" dba dba
    [ -f ods_community_dav.vad ] && DO_COMMAND "vad_install ('ods_community_dav.vad')" dba dba
    [ -f ods_discussion_dav.vad ] && DO_COMMAND "vad_install ('ods_discussion_dav.vad')" dba dba
    [ -f ods_feedmanager_dav.vad ] && DO_COMMAND "vad_install ('ods_feedmanager_dav.vad')" dba dba
    [ -f ods_gallery_dav.vad ] && DO_COMMAND "vad_install ('ods_gallery_dav.vad')" dba dba
    [ -f ods_polls_dav.vad ] && DO_COMMAND "vad_install ('ods_polls_dav.vad')" dba dba
    [ -f ods_webmail_dav.vad ] && DO_COMMAND "vad_install ('ods_webmail_dav.vad')" dba dba
    [ -f ods_wiki_dav.vad ] && DO_COMMAND "vad_install ('ods_wiki_dav.vad')" dba dba
fi

[ -f tutorial_dav.vad ] && DO_COMMAND "vad_install ('tutorial_dav.vad')" dba dba
[ -f demo_dav.vad ] && DO_COMMAND "vad_install ('demo_dav.vad')" dba dba

DO_COMMAND "delete from wa_domains where WD_DOMAIN = 'localhost'" dba dba

DO_COMMAND checkpoint
DO_COMMAND shutdown

BREAK

RUN egrep  '"\*\*.*FAILED:|\*\*.*ABORTED:"' "$LOGFILE"
if test $STATUS -eq 0
then
	exit 1
fi

ECHO "Dump and restore the db to remove the free pages"

rm -f demo.trx 
chmod 644 demo.db

sleep 10

RUN "$SERVER" -b -f
if test $STATUS -ne 0
then
  ECHO "***FAILED: dump demo.db"
  rm -f demo.db demo.trx demo.log demo.lck virtuoso.pxa
  exit 1
else
  ECHO "PASSED: dump demo.db"
fi

rm -f demo.db 

RUN "$SERVER" -R -f
if test $STATUS -ne 0
then
  ECHO "***FAILED: restore demo.db"
  rm -f demo.db demo.trx demo.log demo.lck virtuoso.pxa
  exit 1
else
  ECHO "PASSED: restore demo.db"
fi



#
#  Show final results of run
#
CHECK_LOG
RUN egrep  '"\*\*.*FAILED:|\*\*.*ABORTED:"' "$LOGFILE"
if test $STATUS -eq 0
then
	exit 1
fi

ECHO "Cleanups"
chmod 644 demo.db
rm -f demo.trx demo.log virtuoso.ini

BANNER "COMPLETED DEMO DATABASE (mkdemo.sh)"

exit 0

#!/bin/sh
#
#  $Id$
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2013 OpenLink Software
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

. ./test_fn.sh

DSN=$PORT
PLUGINDIR=${PLUGINDIR-$HOME/lib/}

THOST=localhost
TPORT=$HTTPPORT
LOGFILE=`pwd`/twiki.output
export LOGFILE
. ./test_fn.sh
DSN=$PORT


# SQL command 
DoCommand()
{
  _dsn=$1
  command=$2
  shift 
  shift
  echo "+ " $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*		>> $LOGFILE	
  $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $* >> $LOGFILE
  if test $? -ne 0 
  then
    LOG "***FAILED: $command"
  else
    LOG "PASSED: $command"
  fi
}

MakeIni ()
{
    echo $SERVER
   case $SERVER in
       *virtuoso*)
	   MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
	   echo $CFGFILE
	   cat >> $CFGFILE <<END_ADDONS
[HTTPServer]
HTTPLogFile = http.log
ServerPort = $HTTPPORT
ServerRoot = .
ServerThreads = 3 
MaxKeepAlives = 6
KeepAliveTimeout = 15
MaxCachedProxyConnections = 10
ProxyConnectionCacheTimeout = 15

[Plugins]
LoadPath = $PLUGINDIR
Load1 = plain, wikiv
Load2 = Hosting,hosting_python.so
Load3 = Hosting,hosting_perl.so
END_ADDONS
;;
esac
}
BANNER "STARTED SERIES OF HTTP SERVER TESTS"
ECHO "Wiki test"

case $SERVER in
    *[Mm]2*)
	LOG "wiki is not supported on M2"
	;;
    *virtuoso*)
	STOP_SERVER
	rm -f $DBLOGFILE $DBFILE
	rm -rf wiki
	mkdir wiki

	if [ "x$HOST_OS" = "x" ]; then
	    cp -r ../../samples/wikiv/initial wiki
	    cp -r ../../samples/wikiv/test wiki
	elif [ "x$SRC" != "x" ] ;  then
	    cp -r $SRC/binsrc/samples/wikiv/initial wiki
	    cp -r $SRC/binsrc/samples/wikiv/test wiki
	elif [ ! -f ../../../autogen.sh ];    then
	    LOG "***ABORTED: Cannot build ODS & Blog2 VAD packages"
	    exit 1
	fi


	MakeIni
	CHECK_PORT $TPORT
	if [ "x$HOST_OS" = "x" ]
	    then
	    LOG "Create ODS VAD Package"
	    (cd ../../samples/wa/; $MAKE)
	    cp ../../samples/wa/ods_framework_dav.vad ./
	    LOG "Create WIKI VAD Package"
	    (cd ../../samples/wikiv/; $MAKE)
	    cp ../../samples/wikiv/ods_wiki_dav.vad ./
	elif [ "x$SRC" != "x" ]
	    then
	    LOG "Create ODS VAD Package"
	    (cd "$SRC/binsrc/samples/wa/" ; $MAKE)
	    cp "$SRC/binsrc/samples/wa/ods_framework_dav.vad" .
	    LOG "Create WIKI VAD Package"
	    (cd "$SRC/binsrc/samples/wikiv/" ; $MAKE)
	    cp "$SRC/binsrc/samples/wikiv/ods_wiki_dav.vad" .
	elif [ ! -f ../../../autogen.sh ]
	    then
	    LOG "***ABORTED: Cannot build ODS & Blog2 VAD packages"
	    exit 1
	fi

	if [ ! -f ods_framework_dav.vad -o ! -f ods_wiki_dav.vad ] ; then
	    BLOG_TEST=0  
	    LOG "ODS & Blog2 VAD packages are not built"
	fi

	START_SERVER $DSN 1000
	sleep 1


	RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "HTTPPORT=$HTTPPORT" < twiki.sql
	if test $STATUS -ne 0;   then
	    LOG "***ABORTED: twiki.sql"
	    exit 1
	fi

	SHUTDOWN_SERVER
	;;
esac

CHECK_LOG
BANNER "COMPLETED SERIES OF WIKI SERVER TESTS"

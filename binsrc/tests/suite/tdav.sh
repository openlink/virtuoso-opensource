#!/bin/sh
#
#  $Id$
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2012 OpenLink Software
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

LOGFILE=./tdav.output
export LOGFILE
. ./test_fn.sh

DS1=$PORT

MakeIni ()
{
   MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
   case $SERVER in
   *[Mm]2*)
   cat >> $CFGFILE <<END_HTTP
http_port: $HTTPPORT
http_threads: 7 
http_keep_alive_timeout: 15 
http_max_keep_alives: 100
http_max_cached_proxy_connections: 100
http_proxy_connection_cache_timeout: 15
dav_root: DAV
END_HTTP
   ;;
   *virtuoso*)
   cat >> $CFGFILE <<END_HTTP1
[HTTPServer]
ServerPort = $HTTPPORT
ServerRoot = .
ServerThreads = 7 
MaxKeepAlives = 100
KeepAliveTimeout = 15
MaxCachedProxyConnections = 100
ProxyConnectionCacheTimeout = 15
DavRoot 		= DAV
END_HTTP1
;;
esac
}

CHECK_HTTP_PORT()
{
  port=$1
  stat=`netstat -an | grep "[\.\:]$port " | grep LISTEN`
  while [ "z$stat" = "z" ]
  do
    sleep 1
    stat=`netstat -an | grep "[\.\:]$port " | grep LISTEN`
  done
  LOG "PASSED: Virtuoso HTTP/WebDAV Server successfully started on port $port"
}

BANNER "STARTED WebDAV TEST (tdav.sh)"
NOLITE

rm -f $DELETEMASK
rm -rf sptmp

MakeIni

_dsn=$DSN
DSN=$DS1
SHUTDOWN_SERVER
START_SERVER $DS1 1000
CHECK_HTTP_PORT $HTTPPORT


RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u "HOST=$HOST:$HTTPPORT" < tdav.sql 
if test $STATUS -ne 0
then
    LOG "***ABORTED: webDAV methods tests tdav.sql"
    exit 1
fi
# concurrency tests 
RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF < tdav_conc.sql  
if test $STATUS -ne 0
then
    LOG "***ABORTED: webDAV concurency tests tdav_conc.sql"
    exit 1
fi

CHECKPOINT_SERVER

#RUN $ISQL $DS1 '"EXEC=prof_enable (1);"' ERRORS=STDOUT >> $LOGFILE 
 
#RUN $ISQL $DS1 '"EXEC=c_test_1 (1);"' ERRORS=STDOUT >> $LOGFILE &
#sleep 1
#RUN $ISQL $DS1 '"EXEC=c_test_1 (2);"' ERRORS=STDOUT >> $LOGFILE &
#sleep 1
#RUN $ISQL $DS1 '"EXEC=c_test_1 (3);"' ERRORS=STDOUT >> $LOGFILE &
#sleep 1
#RUN $ISQL $DS1 '"EXEC=c_test_1 (4);"' ERRORS=STDOUT >> $LOGFILE 

#RUN $ISQL $DS1 '"EXEC=prof_enable (0);"' ERRORS=STDOUT >> $LOGFILE 

#run_t="true"
#while [ "z$run_t" != "z" ]
#do
#    run_t=`ps -ef | grep "c_test_1" | grep $ISQL`
#done

#CHECKPOINT_SERVER


RUN $ISQL $DS1 ERRORS=STDOUT  VERBOSE=OFF BANNER=OFF PROMPT=OFF -u "HOST=$HOST:$HTTPPORT" < tdav1.sql 
if test $STATUS -ne 0
then
    LOG "***ABORTED: webDAV repository status tdav1.sql"
    exit 1
fi

lcs=`grep 'Lock Status:' $LOGFILE` 

echo "$lcs"

LOG "SPOTLIGHT TEST"
if [ "x`uname -s`" = "xDarwin" ]
then
  gzip -c -d spotlight_test.tar.gz | tar xf -
  RUN $ISQL $DS1 ERRORS=STDOUT  VERBOSE=OFF BANNER=OFF PROMPT=OFF -u "HOST=$HOST:$HTTPPORT" < tspotlight.sql 
  if test $STATUS -ne 0
  then
      LOG "***ABORTED: webDAV repository status tspotlight.sql"
      exit 1
  fi
  rm Image.jpg 
  rm Goro.jpg
  rm ring\ ring\ ring.mp3 
  rm -rf sptmp
else
  LOG "SKIP SPOTLIGHT TEST FOR THIS PLATFORM"
fi


SHUTDOWN_SERVER
CHECK_LOG
DSN=$_dsn
BANNER "COMPLETED WebDAV TEST (tdav.sh)"

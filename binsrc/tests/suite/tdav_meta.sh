#!/bin/sh
#  
#  $Id$
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

LOGFILE=./tdav_meta.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

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
DavRoot                 = DAV
[URIQA]
DefaultHost = localhost:$HTTPPORT
LocalHostMasks = localhost%
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

BANNER "STARTED WebDAV METADATA TEST (tdav.sh)"
NOLITE

rm -f $DELETEMASK

MakeIni

rm -rf tdav_meta
mkdir tdav_meta
cd tdav_meta
for x in `ls $VIRTUOSO_TEST/tdav_meta_*.zip` ; do unzip "$x" ; done
cd ..

_dsn=$DSN
DSN=$DS1
SHUTDOWN_SERVER
START_SERVER $DS1 1000
CHECK_HTTP_PORT $HTTPPORT

LOG "test1"

#RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF < $VIRTUOSO_TEST/../../dav/davddk.sql
#RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF < $VIRTUOSO_TEST/../../dav/dav_api.sql
#RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF < $VIRTUOSO_TEST/../../dav/dav.sql
#RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF < $VIRTUOSO_TEST/../../dav/DET_HostFs.sql
#RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF < $VIRTUOSO_TEST/../../dav/DET_ResFilter.sql
#RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF < $VIRTUOSO_TEST/../../dav/DET_PropFilter.sql
#RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF < $VIRTUOSO_TEST/../../dav/DET_CatFilter.sql
#RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF < $VIRTUOSO_TEST/../../dav/dav_rdf_quad.sql

LOG "test2"

RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u "HOST=$HOST:$HTTPPORT" < $VIRTUOSO_TEST/tdav_meta.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: webDAV metadata test loading tdav_meta.sql"
    exit 1
fi

LOG "test3"
        
RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u "HOST=$HOST:$HTTPPORT" < $VIRTUOSO_TEST/tdav_meta_checks.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: webDAV metadata test checks tdav_meta.sql"
    exit 1
fi

LOG "test4"

cat $VIRTUOSO_TEST/tdav_meta_checks.sql | sed 's/^TDAV_META_CHECK/TDAV_RDF_QUAD_CHECK/g' > tdav_meta_rdf_checks.sql
RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u "HOST=$HOST:$HTTPPORT" < $VIRTUOSO_TEST/tdav_meta_rdf.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: webDAV rdf quads test loading tdav_rdf.sql"
    exit 1
fi

SHUTDOWN_SERVER
CHECK_LOG
DSN=$_dsn
BANNER "COMPLETED WebDAV METADATA TEST (tdav_meta.sh)"

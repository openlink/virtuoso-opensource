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

USR=dba
PWD=dba

#PARAMETERS FOR HTTP TEST
LOGFILE=tdrop.output
CLI_LOG=tdrop.cli
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

_dsn=$DSN
DS1=$PORT

MakeIni ()
{
   MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
   case $SERVER in
   *[Mm]2*)
   cat >> $CFGFILE <<END_HTTP
http_port: $HTTPPORT
http_threads: 3
http_keep_alive_timeout: 15 
http_max_keep_alives: 6
http_max_cached_proxy_connections: 10
http_proxy_connection_cache_timeout: 15
END_HTTP
   ;;
   *virtuoso*)
   cat >> $CFGFILE <<END_HTTP1
[HTTPServer]
ServerPort = $HTTPPORT
ServerRoot = .
ServerThreads = 3 
MaxKeepAlives = 6
KeepAliveTimeout = 15
MaxCachedProxyConnections = 10
ProxyConnectionCacheTimeout = 15
END_HTTP1
;;
esac
}


BANNER "STARTED DROP TABLE/ALTER PRIMARY KEY TESTS"

#CLEANUP
STOP_SERVER
rm -f $LOGFILE
rm -f $CLI_LOG
rm -f $DBLOGFILE
rm -f $DBFILE
MakeIni

START_SERVER $DS1 1000


LOG "FILLING TPC-C DB"
RUN $ISQL $DS1 ERRORS=stdout < $VIRTUOSO_TEST/../tpccddk.sql
if test $STATUS -ne 0
then 
    LOG "***ABORTED: TPC-C DB TABLES DEFINITION (../tpccddk.sql)" 
    exit 1
fi
$VIRTUOSO_TEST/../tpcc "localhost:$DS1" $USR $PWD i 1 

SHUTDOWN_SERVER
START_SERVER $DS1 1000

#RUN $ISQL $DS1 '"EXEC=load tdrop1.sql;"' ERRORS=stdout >> $LOGFILE 

#$ISQL $DS1 $USR $PWD '"EXEC=c_cli();"' ERRORS=stdout >> $CLI_LOG &
#$ISQL $DS1 $USR $PWD '"EXEC=c_cli();"' ERRORS=stdout >> $CLI_LOG &
#$ISQL $DS1 $USR $PWD '"EXEC=c_cli();"' ERRORS=stdout >> $CLI_LOG &
#$ISQL $DS1 $USR $PWD '"EXEC=c_cli();"' ERRORS=stdout >> $CLI_LOG &

#sleep 4 

LOG "DROP TABLES IN ATOMIC MODE"
#RUN $ISQL $DS1 '"EXEC=load tdrop.sql;"' ERRORS=stdout  >> $LOGFILE
RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tdrop.sql
if test $STATUS -ne 0
then 
    LOG "***ABORTED: DROP TABLES IN ATOMIC MODE & PRIMARY KEY MODIFICATION (tdrop.sql)" 
    exit 1
fi

SHUTDOWN_SERVER

START_SERVER $DS1 1000
RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tdrop1.sql
# Kill the server with raw_exit
RUN $ISQL $DS1 '"EXEC=raw_exit();"' ERRORS=stdout

# check dropped table
START_SERVER $DS1 1000
RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tdrop2.sql

SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED DROP TABLE/ALTER PRIMARY KEY TESTS"

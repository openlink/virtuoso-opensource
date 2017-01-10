#!/bin/sh
#
#  $Id$
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2017 OpenLink Software
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

LOGFILE=timsg.output
export LOGFILE
. ./test_fn.sh
 

BANNER "STARTED POP3, NNTP & FTP TESTS (timsg.sh)"
NOLITE

SHUTDOWN_SERVER

rm -f $DELETEMASK

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

case $SERVER in
   *virtuoso*)
cat >> $CFGFILE <<END_CFG

[HTTPServer]
ServerPort = $HTTPPORT
POP3Port    = $POP3PORT
NewsServerPort   = $NNTPPORT 
FTPServerPort   = $FTPPORT 
FTPServerAnonymousLogin     = 1
FTPServerTimeout = 1200
ServerRoot = ../vsp
ServerThreads = 10
MaxKeepAlives = 10
KeepAliveTimeout = 10
MaxCachedProxyConnections = 10
ProxyConnectionCacheTimeout = 15

END_CFG
   ;;
   *[Mm]2*)
cat >> $CFGFILE <<END_CFG
http_port: $HTTPPORT
http_threads: 10
http_keep_alive_timeout: 15 
http_max_keep_alives: 10
http_max_cached_proxy_connections: 10
http_proxy_connection_cache_timeout: 15
pop3_port: $POP3PORT
news_port: $NNTPPORT
ftp_port: $FTPPORT

[HTTPServer]
FTPServerAnonymousLogin = 1
END_CFG
   ;;
esac   

START_SERVER $PORT 1000 

#make another test file, the original text_1947.db.test is no longer in the db
cp words.esp test_1947.db.test
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "FTPPORT=$FTPPORT"   < tftp.sql 
rm test_1947.db.test

if test $STATUS -ne 0
then
    LOG "***ABORTED: tftp.sql:  " 
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "POP3PORT=$POP3PORT" < mail.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: mail.sql:  " 
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "NNTPPORT=$NNTPPORT" < nntp_suite.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: nntp_suite.sql:  " 
    exit 3
fi

rm -f ftp_test_file

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED POP3, NNTP & FTP TESTS (timsg.sh)"

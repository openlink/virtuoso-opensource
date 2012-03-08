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

#PAGES FOR HTTP/1.0
H1=2 
#PAGES FOR HTTP/1.1
H2=2 
#PAGES FOR HTTP/1.0 & HTTP/1.1
H3=4

LOGFILE=`pwd`/tproxy.output
export LOGFILE
. ./test_fn.sh

DSN=$PORT

#PARAMETERS FOR HTTP TEST
USERS=1
nreq=100
THOST=localhost
TPORT=$HTTPPORT
CLICKS=1000
#SERVER=M2	# OVERRIDE

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


#URI files 
GenURI10 () 
{
    ECHO "Creating uri file for PROXY HTTP/1.0 test"
    file=http10.uri
    cat > $file <<END_URI
$THOST $TPORT
$CLICKS GET http://$THOST:$TPORT/test.html HTTP/1.0
$CLICKS GET http://$THOST:$TPORT/test.vsp HTTP/1.0
END_URI
    chmod 644 $file
}

GenURI11 () 
{
    ECHO "Creating uri file for PROXY HTTP/1.1 test"
    file=http11.uri
    cat > $file <<END_URI
$THOST $TPORT
$CLICKS GET http://$THOST:$TPORT/test.html HTTP/1.1
$CLICKS GET http://$THOST:$TPORT/test.vsp HTTP/1.1
END_URI
    chmod 644 $file
}

GenURI1011 () 
{
    ECHO "Creating uri file for PROXY HTTP/1.0 & HTTP/1.1 test "
    file=http1011.uri
    cat > $file <<END_URI
$THOST $TPORT
$CLICKS GET http://$THOST:$TPORT/test.html HTTP/1.0
$CLICKS GET http://$THOST:$TPORT/test.vsp HTTP/1.0
$CLICKS GET http://$THOST:$TPORT/test.html HTTP/1.1
$CLICKS GET http://$THOST:$TPORT/test.vsp HTTP/1.1
END_URI
    chmod 644 $file
}

GenHTML () 
{
    ECHO "Creating HTML page for PROXY HTTP test"
    file=test.html
    cat > $file <<END_HTML
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">

<html>
  <head>
    <title>OpenLink Virtuoso Server</title>
    <meta name="description" content="OpenLink Virtuoso Server">
  </head>
  <P>
  <A href=mime/mime_plain.vsp>MIME Messages</A>
  </P>
  <P>
  <A href=mime/mime_compose.vsp>MIME Composition</A>
  </P>
  <P>
  <A href=admin/admin_main.vsp>Virtuoso Administrator</A>
  </P>
  <P>
  <A href=soapdemo/SOAP.html>Sample SOAP page</A>
  </P>
  <P>
  <A href=vfs/vfs.html>Web copy</A>
  </P>
</html>
END_HTML
    chmod 644 $file
}

GenVSP () 
{
    ECHO "Creating  VSP page for PROXY HTTP test"
    file=test.vsp
    cat > $file <<END_VSP
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">

<html>
  <head>
    <title>OpenLink Virtuoso Server</title>
    <meta name="description" content="OpenLink Virtuoso Server">
  </head>
  <body>
<?vsp
http (cast (now () as varchar));
?>
  </body>
</html>
END_VSP
    chmod 644 $file
}

httpGet ()
{
  file=$1
  if [ "$2" -gt "0" ] 
    then
      pipeline="-P -c $2"
    else
      pipeline=""      
    fi
  user=${3-dba}
  pass=${4-dba}
  ../urlsimu $file $pipeline -u $user -p $pass 
}

waitAll ()
{
   clients=1
   while [ "$clients" -gt "0" ]
     do
       sleep 1
       clients=`ps -e | grep urlsimu | grep -v grep | wc -l`
#     echo -e "Running clients $clients\r" 
     done 
}

MakeIni ()
{
   MAKECFG_FILE ../$TESTCFGFILE $PORT $CFGFILE
   case $SERVER in
   *[Mm]2*)
   cat >> $CFGFILE <<END_HTTP
HTTPLogFile: http.log
http_port: $HTTPPORT
http_threads: 3
http_keep_alive_timeout: 15 
http_max_keep_alives: 6
http_max_cached_proxy_connections: 10
http_proxy_connection_cache_timeout: 15
http_proxy_enabled: 1
END_HTTP
   ;;
   *virtuoso*)
   MAKECFG_FILE ../$TESTCFGFILE $PORT $CFGFILE
   cat >> $CFGFILE <<END_HTTP1
[HTTPServer]
HTTPLogFile = http.log
ServerPort = $HTTPPORT
ServerRoot = .
ServerThreads = 3 
MaxKeepAlives = 6
KeepAliveTimeout = 15
MaxCachedProxyConnections = 10
HTTPProxyEnabled	  = 1
ProxyConnectionCacheTimeout = 15
END_HTTP1
;;
esac
}

checkRes ()
{
  result=0
  result=`grep '200 OK' $1 | wc -l`
  if [ "$result" -lt "$2" ]
    then
     ECHO "*** FAILED: $3 $result clicks" 	
  else
     ECHO "PASSED: PROXY $3 $result clicks"    
  fi
}

BANNER "STARTED SERIES OF HTTP PROXY SERVER TESTS"
NOLITE
ECHO "HTTP Proxy Server test ($CLICKS per page)"
ECHO "Two pages (html&vsp)"

case $1 in 
   *) #run test

   #CLEANUP
   rm -rf tproxy 
   mkdir tproxy 
   cd tproxy
   GenURI11
   GenURI10
   GenURI1011
   MakeIni
   GenHTML
   GenVSP
   STOP_SERVER
   START_SERVER $DSN 1000
   sleep 1
   cd ..

   DoCommand $DSN "DB.DBA.VHOST_DEFINE ('*ini*', '*ini*', '/test.vsp', '/test.vsp', 0, 0, NULL,  NULL, NULL, NULL, 'dba', NULL, NULL, 0);"   
   DoCommand $DSN "insert into HTTP_ACL (HA_LIST,HA_ORDER,HA_CLIENT_IP,HA_FLAG,HA_DEST_IP) values ('PROXY',1,'*',0,'*');"   
  if [ "x$HOST_OS" = "x" -a "x$NO_PERF" = "x" ]
  then
   # HTTP/1.0   
   ECHO "STARTED: test with $USERS HTTP/1.0 clients" "`date +%H:%M:%S`"
   count=1
   while [ "$count" -le "$USERS" ]
     do
       httpGet tproxy/http10.uri 0 > tproxy/result1.$count &
       count=`expr $count + 1`   
     done
   waitAll 
   checkRes 'tproxy/result1.*' `expr $CLICKS \* $H1 \* $USERS` 'HTTP/1.0 test'
   
   # HTTP/1.1  
   ECHO "STARTED: test with $USERS HTTP/1.1 clients" "`date +%H:%M:%S`" 
   count=1
   while [ "$count" -le "$USERS" ]
     do
       httpGet tproxy/http11.uri $nreq > tproxy/result2.$count &
       count=`expr $count + 1`   
     done
   waitAll 
   checkRes 'tproxy/result2.*'  `expr $CLICKS \* $H2 \* $USERS` 'HTTP/1.1 test'
   
   # HTTP/1.0 & HTTP/1.1 
   ECHO "STARTED: test with $USERS HTTP/1.0/1.1 clients" "`date +%H:%M:%S`"
   count=1
   while [ "$count" -le "$USERS" ]
     do
       httpGet tproxy/http1011.uri $nreq > tproxy/result3.$count &
       count=`expr $count + 1`   
     done
   waitAll
   checkRes 'tproxy/result3.*' `expr $CLICKS \* $H3 \* $USERS` 'HTTP/1.0 & HTTP/1.1 test'
  fi 
   ECHO "END OF SERIES:" "`date +%H:%M:%S`"
   SHUTDOWN_SERVER

   # 
   #  CLEANUP
   #
#rm -rf tproxy 
   ;;

esac
CHECK_LOG
BANNER "COMPLETED SERIES OF HTTP PROXY SERVER TESTS"

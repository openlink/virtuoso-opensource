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

. $VIRTUOSO_TEST/testlib.sh

DSN=$PORT

#PARAMETERS FOR HTTP TEST
USERS=10
nreq=1
CLICKS=10
THOST=localhost
TPORT=$HTTPPORT
HTTPPORT1=`expr $HTTPPORT + 1`
HTTPPORT2=`expr $HTTPPORT + 2`
#SERVER=M2		# OVERRIDE

LOGFILE=`pwd`/thttp.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

DSN=$PORT
GenURIall () 
{
	ECHO "Creating uri file for VSPX test"
	file=allVSPX.uri
	echo "$THOST $TPORT" > $file
	for vspxfile in `grep -l brief *.vspx` ; do
		echo "$CLICKS GET /$vspxfile HTTP/1.0" >> $file
		echo "$CLICKS GET /$vspxfile HTTP/1.1" >> $file
	done
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
  $VIRTUOSO_TEST/../urlsimu $file $pipeline -u $user -p $pass 
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

checkRes ()
{
  result=0
  result=`grep '200 OK' $1 | wc -l`
  if [ "$result" -eq "$2" ]
    then
     ECHO "PASSED: $3 $result clicks"    
  else
     ECHO "*** FAILED: $3 $result clicks, $2 expected."
  fi
}

checkHTTPLog ()
{
  log_lines=0
  log_lines=`grep '["]GET' vspx/http*.log | wc -l`

  temp=`grep -l brief vspx/*.vspx | wc -l`

  expected_log_lines=`expr $CLICKS \* $temp \* 2 \* $USERS`
  log_lines=`expr $log_lines`

  if [ "$log_lines" -eq "$expected_log_lines" ]
    then
     ECHO "PASSED: HTTP Log test"
  else
     ECHO "*** FAILED: HTTP Log test, $expected_log_lines expected $log_lines actual"
  fi
}

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

# For CASE MODE 2 until all VSPX code is managed to run under 1
MakeConfig ()
{
#echo "CREATING CONFIGURATION FOR SERVER '$1'"
    case $SERVER in
      *[Mm2]*)
    file=wi.cfg
    cat > $file <<END_CFG
database_file: wi.db
log_file: wi.trx
number_of_buffers: 2000
max_dirty_buffers: 1200
max_checkpoint_remap: 20000
file_extend: 200
threads: 100
atomic_dive: 1
case_mode: 2
db_name: vspxtest
replication_server: 1
replication_queue: 1000000
autocheckpoint: 10
scheduler_period: 0
dirs_allowed: /, c:\\, d:\\, e:\\
sql_optimizer: $SQLOPTIMIZE
pl_debug: $PLDBG
test_coverage: cov.xml

SQL_ROWSET_SIZE: 100
SQL_PREFETCH_BYTES: 12000


callstack_on_exception: 1
HTTPLogFile: http.log
http_port: $HTTPPORT
http_threads: 3
http_keep_alive_timeout: 15 
http_max_keep_alives: 6
http_max_cached_proxy_connections: 10
http_proxy_connection_cache_timeout: 15
END_CFG
;;
    *virtuoso*)
    file=virtuoso.ini
    cat > $file <<END_CFG
[Database]
DatabaseFile		= virtuoso.db
TransactionFile		= virtuoso.trx
ErrorLogFile		= virtuoso.log
ErrorLogLevel   	= 7
FileExtend      	= 200
Striping        	= 0
Syslog			= 0

;
;  Server parameters
;
[Parameters]
ServerPort         	= $PORT
ServerThreads      	= 100
CheckpointInterval 	= 60
NumberOfBuffers    	= 2000
MaxDirtyBuffers    	= 1200
MaxCheckpointRemap 	= 20000
UnremapQuota       	= 0
AtomicDive         	= 1
PrefixResultNames	= 0
CaseMode           	= 2
DisableMtWrite		= 0
SchedulerInterval      = 0
DirsAllowed		= /, c:\\, d:\\, e:\\
PLDebug              	= $PLDBG
TestCoverage         	= cov.xml
SQLOptimizer		= $SQLOPTIMIZE

[HTTPServer]
HTTPLogFile = http.log
ServerPort = $HTTPPORT
ServerRoot = .
ServerThreads = 3 
MaxKeepAlives = 6
KeepAliveTimeout = 15
MaxCachedProxyConnections = 10
ProxyConnectionCacheTimeout = 15
CallstackOnException: 1

[Client]
SQL_ROWSET_SIZE		= 100
SQL_PREFETCH_BYTES	= 12000

[Replication]
ServerName	= vspxtest
ServerEnable	= 1
QueueMax 	= 1000000
END_CFG
;;
esac
    chmod 644 $file
}

MakeIni ()
{
   MAKECFG_FILE $VIRTUOSO_TEST/../$TESTCFGFILE $PORT $CFGFILE
   case $SERVER in
   *[Mm]2*)
   cat >> $CFGFILE <<END_HTTP
callstack_on_exception: 1
HTTPLogFile: http.log
http_port: $HTTPPORT
http_threads: 3
http_keep_alive_timeout: 15 
http_max_keep_alives: 6
http_max_cached_proxy_connections: 10
http_proxy_connection_cache_timeout: 15
END_HTTP
   ;;
   *virtuoso*)
   MAKECFG_FILE $VIRTUOSO_TEST/../$TESTCFGFILE $PORT $CFGFILE
   cat >> $CFGFILE <<END_HTTP1
[HTTPServer]
HTTPLogFile = http.log
ServerPort = $HTTPPORT
ServerRoot = .
ServerThreads = 3 
MaxKeepAlives = 6
KeepAliveTimeout = 15
MaxCachedProxyConnections = 10
ProxyConnectionCacheTimeout = 15
CallstackOnException: 1
END_HTTP1
;;
esac
}
BANNER "STARTED SERIES OF VSPX TESTS"
NOLITE
ECHO "VSPX Server test ($CLICKS per page)"

#CLEANUP
STOP_SERVER
rm -f $DBLOGFILE $DBFILE
rm -rf vspx
mkdir vspx
cd vspx
cp -f $HOME/binsrc/vspx/examples/*.vspx .
cp -f $HOME/binsrc/vspx/examples/*.xml .
cp -f $HOME/binsrc/vspx/examples/*.xsl .
cp -f $HOME/binsrc/vspx/vspx_demo_init.sql .

# code file for code behind example
cat >> code_file__0.sql <<END_COD
drop type my_page_subclass
;

create type my_page_subclass under DB.dba.page__code__file____0_vspx
temporary self as ref
overriding method vc_post_b1 (control vspx_button, e vspx_event) returns any,
method button_change (control vspx_button) returns any
;

create method vc_post_b1 (inout control vspx_button, inout e vspx_event) for my_page_subclass
 {
   if (not control.vc_focus) return;
   dbg_vspx_control (control);
   self.button_change (control);
   return;
 }
;

create method button_change (inout control vspx_button) for my_page_subclass
 {
   self.var1 := self.var1 + 1;
   control.ufl_value := 'Activated';
 }
;
END_COD

GenURIall
#MakeIni
MakeConfig 
CHECK_PORT $TPORT
START_SERVER $DSN 1000
sleep 1
cd ..
DoCommand $DSN "DB.DBA.VHOST_DEFINE ('*ini*', '*ini*', '/', '/', 0, 0, NULL,  NULL, NULL, NULL, 'dba', NULL, NULL, 0);"

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwdemo.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvspx.sh: loading northwind data"
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/vspx/vspx_demo_init.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvspx.sh: loading vspx_demo_init.sql"
    exit 3
fi

if [ "x$HOST_OS" = "x" -a "x$NO_PERF" = "x" ] ; then
	ECHO "STARTED: test with $USERS clients"
	count=1
	while [ "$count" -le "$USERS" ] ; do
		httpGet vspx/allVSPX.uri 0 > vspx/allVSPXres.$count &
		count=`expr $count + 1`
	done
	waitAll 
	temp=`grep -l brief vspx/*.vspx | wc -l`
	expected_OK_lines=`expr $CLICKS \* $temp \* 2 \* $USERS`
	checkRes 'vspx/allVSPXres.*' $expected_OK_lines 'VSPX test'
	checkHTTPLog
fi 
SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED SERIES OF VSPX TESTS"

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

LOGFILE=`pwd`/bpel.output
BINARIESDIR="$BINDIR"
export LOGFILE
. ./test_fn.sh
echo $BINDIR

find ./ -name 'bpel.output' -exec rm -f '{}' ';'


if [ "yes" = "yes" ] ; then
MAKE_VAD=yes
TEST_ECHO=yes
BS2_TEST=no
FAULT1_TEST=yes
else
MAKE_VAD=yes
TEST_ECHO=yes
BS2_TEST=yes
FAULT1_TEST=yes
fi

BANNER "STARTED BPEL TEST (bpel.sh)"
NOLITE

HOST_OS=`uname -s | grep WIN`
case $SERVER in
          *java*)
	  if [ "x$HOST_OS" = "x" ] ; then
	  	export CLASSPATH="$CLASSPATH:classlib"
	  else
	  	export CLASSPATH="$CLASSPATH;classlib"
	  fi
	  echo "CLASSPATH: $CLASSPATH"
;;
esac
	  	

rm -f $DBLOGFILE
rm -f $LOGFILE
rm -f $LOGFILE.tmp
rm -f $DBFILE

DS1=$PORT
DS2=`expr $PORT + 1`
DS3=`expr $PORT + 2`

HP1=$HTTPPORT
HP2=`expr $HTTPPORT + 1`
HP3=`expr $HTTPPORT + 2`

CNT=1

#LOG ">>>> $HTTPPORT $DS1 $DS2  $HP1 $HP2 $1 $2"

## CASE MODE 2 until all VSPX code is managed to run under 1
MakeConfig ()
{
echo "CREATING CONFIGURATION FOR SERVER '$SERVER' '$1' in '`pwd`'"
    case $SERVER in
          *[Mm]2*)
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


callstack_on_exception: 0
HTTPLogFile: http.log
http_port: $2
http_threads: 15
http_keep_alive_timeout: 15
http_max_keep_alives: 20
http_max_cached_proxy_connections: 0
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
ServerPort         	= $1
ServerThreads      	= 10
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
DirsAllowed		= /, c:\\, d:\\, e:\\, l:\\
PLDebug              	= $PLDBG
TestCoverage         	= cov$CNT.xml
SQLOptimizer		= $SQLOPTIMIZE
;the following causes win32 to fail, because of isql bug
;CallstackOnException	= 2
AllowOSCalls		= 1

[HTTPServer]
HTTPLogFile = http.log
ServerPort = $2
ServerRoot = .
ServerThreads = 10
MaxKeepAlives = 20
KeepAliveTimeout = 15
MaxCachedProxyConnections = 0
ProxyConnectionCacheTimeout = 15
CallstackOnException = 2

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

DoCommand()
{
  _dsn=$1
  command=$2
  comment=$3
  file='bpel_temp.sql'
  shift
  shift
  shift
  echo $command > $file
  cat >> $file <<END_SQL
ECHO BOTH \$IF \$EQU \$STATE 'OK' "PASSED" "***FAILED";
SET ARGV[\$LIF] \$+ \$ARGV[\$LIF] 1;
END_SQL

  comment="ECHO BOTH \": "$comment" STATE=\" \$STATE \" MESSAGE=\" \$MESSAGE \"\n\";"
  echo $comment >> $file
  echo "+ " ${ISQL} ${_dsn} dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*             >> $LOGFILE
  RUN ${ISQL} ${_dsn} dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $file
}

SetPort ()
{
  rm -f tmp.wsdl  
  if [ -f "$1" ]  
  then
    cat "$1" | sed -e "s/:6666/:$HP1/g" > tmp.wsdl
    cp tmp.wsdl "$1"
  else  
    LOG "***FAILED: Setting the port in WSDL '$1'"
  fi  
}

SHUTDOWN_SERVER

if [ "$MAKE_VAD" = "yes" ] ; then
LOG "Create VAD BPEL4WS Package"

(cd ../../bpel; $MAKE)
fi

cp ../../bpel/bpel_filesystem.vad ./

MakeConfig $DS1 $HP1

if [ "$TEST_ECHO" = "yes" ] ; then

CNT=`expr $CNT + 1`
START_SERVER $DS1 1000

LOG "ECHO BPEL script test"
DoCommand $DS1 "vad_install ('bpel_filesystem.vad', 0, 1);" "bpel_filesystem.vad install"
DoCommand $DS1 "create user BPELTEST;" "create user BPELTEST"
DoCommand $DS1 "user_set_qualifier ('BPELTEST', 'BPEL');" "user_set_qualifier ('BPELTEST', 'BPEL')"
DoCommand $DS1 "grant ALL PRIVILEGES to BPELTEST;" "grant to BPELTEST"
DoCommand $DS1 "vhost_define (vhost=>'*ini*', lhost=>'*ini*', lpath=>'/SRC/', ppath=>'/', vsp_user=>'BPEL');" "source vhost"
#DoCommand $DS1 "trace_on();" "TRACE ON"

ECHO "Echo BPEL script test"
rm -rf echo
cp -r ../../bpel/tests/echo ./

RUN $ISQL $DS1 BPELTEST BPELTEST PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < echo/ini.sql


SHUTDOWN_SERVER

fi

if [ "$BS2_TEST" = "yes" ] ; then

LOG "Buyer/Seller BPEL script test"
LOG "Seller instance"

rm -rf t1
cp -r ../../bpel/tests/t1 ./

#LOGFILE=../../bpel.output
cd t1
MakeConfig $DS1 $HP1
DSN=$DS1
SHUTDOWN_SERVER
CNT=`expr $CNT + 1`
START_SERVER $DS1 1000
cp ../bpel_filesystem.vad ./
DoCommand $DS1 "vad_install ('bpel_filesystem.vad', 0, 1);" "bpel_filesystem.vad install"
#DoCommand $DS1 "trace_on('soap');" "TRACE ON"
RUN $ISQL $DS1 BPEL BPEL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'buyer_http_port=$HP1' < seller/ini.sql

LOG "buyer instance"

RUN $ISQL $DS1 BPEL BPEL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'seller_http_port=$HP1' < buyer/ini.sql

sleep 60


cd ../

# LOGFILE=bpel.output

DSN=$DS1
SHUTDOWN_SERVER

DSN=$DS2
SHUTDOWN_SERVER

fi

if [ $FAULT1_TEST = "yes" ] ; then

rm -rf fault1
cp -r ../../bpel/tests/fault1 ./
cd fault1
cp -r ../../../bpel/tests/mix .
cp -r ../../../bpel/tests/order .
cp -r "../../../bpel/tests/fi" .
cp -r "../../../bpel/tests/pick" .
cp -r "../../../bpel/tests/wss" .
cp -r "../../../bpel/tests/wsrm" .
cp -r "../../../bpel/tests/pick1" .
cp -r "../../../bpel/tests/post" .
cp -r "../../../bpel/tests/echovirt" .
cp -r "../../../bpel/tests/echo" .
cp -r "../../../bpel/tests/tver" .
cp -r "../../../bpel/tests/tevent" .
cp -r "../../../bpel/tests/processXSLT" .
cp -r "../../../bpel/tests/processXSQL" .
cp -r "../../../bpel/tests/processXQuery" .
cp -r "../../../bpel/tests/LoanFlow" .
if [ "x$HOST_OS" = "x" ]
then
mkdir tutorial
mkdir tutorial/services
cp -r ../../../tutorial/services/bp_s_1 tutorial/services
cp ../../../bpel/tests/Flow/test_tutorial.sql .
fi

SetPort "fi/fi.wsdl"
SetPort "fi/fia.wsdl"
SetPort "fi/fib.wsdl"

SetPort "mix/olservice.wsdl"
SetPort "mix/timesvc.wsdl"
SetPort "mix/tsvc.wsdl"
SetPort "pick/service.wsdl"
SetPort "wss/secsvc.wsdl"
SetPort "wsrm/wsrmsvc.wsdl"
SetPort "tver/service.wsdl"
SetPort "tevent/AsyncBPELService.wsdl"

cd ..
rm -rf fault1_req
mkdir fault1_req
cd fault1_req
cp -r ../../../bpel/tests/fault1/*.vsp .
#LOGFILE=../../bpel.output
MakeConfig $DS2 $HP2
DSN=$DS2
SHUTDOWN_SERVER
START_SERVER $DS2 1000
RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < ../fault1/ini2.sql
#DoCommand $DS2 "vhost_define (lpath=>'/BPELREQ/', ppath=>'/SOAP/', soap_user=>'DBA');" "Request vhost"
cd ../fault1

MakeConfig $DS1 $HP1
DSN=$DS1
SHUTDOWN_SERVER
CNT=`expr $CNT + 1`
START_SERVER $DS1 1000
cp ../bpel_filesystem.vad ./
DoCommand $DS1 "vad_install ('bpel_filesystem.vad', 0, 1);" "bpel_filesystem.vad install"
DoCommand $DS1 "create user BPELTEST;" "create user BPELTEST"
DoCommand $DS1 "user_set_qualifier ('BPELTEST', 'BPEL');" "user_set_qualifier ('BPELTEST', 'BPEL')"
DoCommand $DS1 "grant ALL PRIVILEGES to BPELTEST;" "grant to BPELTEST"
DoCommand $DS1 "vhost_define (vhost=>'*ini*', lhost=>'*ini*', lpath=>'/SRC/', ppath=>'/', vsp_user=>'BPEL');" "source vhost"
#DoCommand $DS1 "trace_on('soap');" "TRACE ON"
RUN $ISQL $DS1 BPELTEST BPELTEST PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < ini.sql
SHUTDOWN_SERVER
CNT=`expr $CNT + 1`
START_SERVER $DS1 1000
RUN $ISQL $DS1 BPELTEST BPELTEST PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < check.sql
DSN=$DS2
SHUTDOWN_SERVER
RUN $ISQL $DS1 BPELTEST BPELTEST PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < inv.sql
cd ../fault1_req
START_SERVER $DS2 1000
cd ../fault1
DSN=$DS1
RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < processXQuery/ini.sql

RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < processXSLT/processXSLT.sql
RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < processXSLT/ini.sql

RUN $ISQL $DS1 BPELTEST BPELTEST PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < processXSQL/ini.sql
RUN $ISQL $DS1 BPELTEST BPELTEST PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < check2.sql
RUN $ISQL $DS1 BPELTEST BPELTEST PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < mix/ini.sql
RUN $ISQL $DS1 BPELTEST BPELTEST PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < order/order_svc.sql
RUN $ISQL $DS1 BPELTEST BPELTEST PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < order/order.sql
RUN $ISQL $DS1 BPELTEST BPELTEST PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < order/invoke.sql
RUN $ISQL $DS1 BPELTEST BPELTEST PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < fi/ini.sql
RUN $ISQL $DS1 BPELTEST BPELTEST PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < pick/ini.sql
RUN $ISQL $DS1 BPELTEST BPELTEST PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < pick/async_svc.sql
RUN $ISQL $DS1 BPELTEST BPELTEST PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < pick/inv.sql
RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < wss/secdoc.sql
RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < wsrm/wsrmdoc.sql
RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < pick1/ini.sql
RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < post/ini.sql
RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < echovirt/ini.sql
RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < tver/tver.sql
RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < mix/comp.sql
RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < tevent/tevent.sql
RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < mix/comp2.sql
RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < mix/testsvc.sql

case $SERVER in
          *java*)
		RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'http_port_two=$HP2' < java.sql
;;
esac

case $SERVER in
          *clr*)
		RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'bin_dir=$BINARIESDIR' < clr.sql
;;
esac

if [ "x$HOST_OS" = "x" ]
then
#RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < ../../../tutorial/setup_tutorial.sql
RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < LoanFlow/LoanFlow.sql
RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < test_tutorial.sql
else
    LOG "Skiping LoanFlow test on this platform."
fi

sleep 2

DoCommand $DS1 "vad_uninstall ('bpel4ws/'||registry_get('_bpel4ws_version_'));" "bpel_filesystem.vad uninstalled"
DoCommand $DS1 "vad_install ('bpel_filesystem.vad', 0);" "bpel_filesystem.vad re-installed"
sleep 1
if $ISQL $DS1 "EXEC=status();" VERBOSE=OFF ERRORS=STDOUT > ident.txt
then
    if test -s ident.txt
    then
	LOG "PASSED: Inquiring database status"
    else
	LOG "***FAILED: Inquiring database status, ident.txt missing or empty"
    fi
else
    LOG "***ABORTED: Inquiring database status"
fi

# recovery test
RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < mix/recovery_test.sql

RUN $ISQL $DS1 '"EXEC=shutdown;"' ERRORS=STDOUT
RUN $ISQL $DS2 '"EXEC=shutdown;"' ERRORS=STDOUT
cd ../

pwd

#sleep 30

fi

DSN=$DS1
STOP_SERVER
DSN=$DS2
STOP_SERVER
DSN=$DS3
STOP_SERVER

#find ./ -name 'bpel.output' -exec cat '{}' >> $LOGFILE.tmp ';'

#mv $LOGFILE.tmp $LOGFILE

CHECK_LOG

BANNER "COMPLETED BPEL TEST (bpel.sh)"
  # cat bpel.output | mail ruslan@openlinksw.com


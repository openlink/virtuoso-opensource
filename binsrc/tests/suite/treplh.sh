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

. ./test_fn.sh

# TEST PARAMETERS
DS1=$PORT
DS3=`expr $PORT + 2`
http1=$HTTPPORT
http3=`expr $http1 + 2`
DBNAME1=rep1
DBNAME3=rep3

iswin=`uname | grep WIN`
if [ -z "$iswin" ]; then
  ISQL=isql-iodbc
else
  ISQL=isqlo
fi
ISQL_ARGS="PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT"
DSNFILE=treplh-dsn-odbc.cfg
TESTFILE=treplh-test-odbc.cfg

LOGFILE=./treplh.output
export LOGFILE
. ./test_fn.sh

# Configuration file creation
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
db_name: $1
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


http_port: $2
http_threads: 5
http_keep_alive_timeout: 15
http_max_keep_alives: 10
http_max_cached_proxy_connections: 10
http_proxy_connection_cache_timeout: 15
dav_root: DAV
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
ServerPort         	= $3
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
ServerPort		= $2
ServerRoot		= .
ServerThreads		= 5
MaxKeepAlives 		= 10
KeepAliveTimeout 	= 15
MaxCachedProxyConnections = 10
ProxyConnectionCacheTimeout = 15
DavRoot 		= DAV

[Client]
SQL_ROWSET_SIZE		= 100
SQL_PREFETCH_BYTES	= 12000

[Replication]
ServerName	= $1
ServerEnable	= 1
QueueMax 	= 1000000
END_CFG
;;
esac
    chmod 644 $file
}

GET_DSN_DATA()
{
  dsn_owner=$1

  line=`grep -h "^$dsn_owner" $DSNFILE`
  if test -z "$line"; then
    LOG "***FAILED: couldn't find the DSN with owner $dsn_owner in the config file $DSNFILE"
    unset dsn_owner
  else
    dsn_name=`echo $line | cut -f 2 -d:`
    dsn_uid=`echo $line | cut -f 3 -d:`
    dsn_pwd=`echo $line | cut -f 4 -d:`
  fi
}

Line ()
{
  ECHO "--------------------------------------------------------------------"
}

REPLHETER ()
{
rm -rf rep1 rep2 rep3

mkdir rep1 rep3

# First replication server configuration
#Line
SILENT=0
cd rep1
MakeConfig $DBNAME1 $http1 $DS1
CHECK_PORT $http1
ECHO "Starting server 'rep1'"
START_SERVER $DS1 1000
cd ..

cd rep3
MakeConfig $DBNAME3 $http3 $DS3
CHECK_PORT $http3
ECHO "Starting server 'rep3'"
START_SERVER $DS3 1000
cd ..

SILENT=0

LINE
LOG "STARTED: Heterogeneous snapshot replication test"
LINE

#
# bi-directional snapshot test
testdir=../repl_trx/hbs-regress
for DBNAME2 in `cat treplh-test-odbc.cfg | sed '/^#/d'`; do
  Line
  LOG "STARTED: Bidirectional snapshot replication test ($DBNAME2)"
  Line

  GET_DSN_DATA $DBNAME2

  # initialize
  RUN $ISQL $DS1 dba dba $ISQL_ARGS -u "DBNAME1=$DBNAME1" "DBNAME2=$DBNAME2" "DS2=$DS2" "DBNAME3=$DBNAME3" "DS3=$DS3" < "$testdir/publish.sql"
  RUN $ISQL $dsn_name $dsn_uid $dsn_pwd $ISQL_ARGS -u "DBNAME=$DBNAME1" "DS=$DS1" "TARGET_DBNAME=$DBNAME2" "TARGET_DS=$dsn_name" "TARGET_UID=$dsn_uid" "TARGET_PWD=$dsn_pwd" < "$testdir/subscribe.sql"
  RUN $ISQL $DS3 dba dba $ISQL_ARGS -u "DBNAME=$DBNAME1" "DS=$DS1" "TARGET_DBNAME=$DBNAME3" "TARGET_DS=$DS3" "TARGET_UID=dba" "TARGET_PWD=dba" < "$testdir/subscribe.sql"

  # run
  RUN $ISQL $DS1 dba dba $ISQL_ARGS -u "DBNAME1=$DBNAME1" "DS1=$DS1" "DBNAME2=$DBNAME2" "DS2=$dsn_name" "DBNAME3=$DBNAME3" "DS3=$DS3" < "$testdir/regress.sql"
done

# shutdown
_dsn=$DSN
DSN=$DS1
SHUTDOWN_SERVER
DSN=$DS3
SHUTDOWN_SERVER
DSN=$_dsn
}

BANNER "STARTED SERIES OF HETEROGENEOUS REPLICATION TESTS"
REPLHETER
CHECK_LOG

echo ""
echo "============ HETEROGENEOUS REPLICATION TEST FINISHED ============="
echo ""

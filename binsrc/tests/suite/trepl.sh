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

LOGFILE=./trepl.output
export LOGFILE


. ./test_fn.sh



# TEST PARAMETERS
DS1=$PORT
DS2=`expr $PORT + 1`
DS3=`expr $PORT + 2`
http1=$HTTPPORT
http2=`expr $HTTPPORT + 1`
http3=`expr $HTTPPORT + 2`
DBNAME1=rep1
DBNAME2=rep2
DBNAME3=rep3
size0=500000
size1=1000000
two=""
mixed=""

. ./test_fn.sh


grep VDB ident.txt
if test $? -ne 0
then 
    LOG "No VDB in trepl.sh"
    echo "trepl.sh: The present build is not set up for VDB."
    exit
fi



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
dirs_allowed: /, c:\\, d:\\, e:\\, f:\\, g:\\, h:\\, i:\\, j:\\, k:\\, l:\\, m:\\, n:\\, o:\\, p:\\, q:\\, r:\\, s:\\, t:\\, u:\\, v:\\, w:\\, x:\\, y:\\, z:\\
sql_optimizer: $SQLOPTIMIZE
pl_debug: $PLDBG
test_coverage: cov.xml
pl_debug: 1
callstack_on_exception: 2

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
DirsAllowed		= /, c:\\, d:\\, e:\\, f:\\, g:\\, h:\\, i:\\, j:\\, k:\\, l:\\, m:\\, n:\\, o:\\, p:\\, q:\\, r:\\, s:\\, t:\\, u:\\, v:\\, w:\\, x:\\, y:\\, z:\\
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

# HTTP status line check
CheckLog ()
{
  RC=`grep "HTTP/1.1 $2" $3 | wc -l`
  if test $RC -eq 0
  then
    LOG "PASSED: $1"
  else
    LOG "*** FAILED: $1"
  fi
}

# WebDAV command using urlsimu executable
DAVcommand()
{
  host=$1
  port=$2
  line=$3
  dst=$4
  file=url.url
echo $port $line >> $LOGFILE
  cat > $file <<END_URL
$host $port
1 $line HTTP/1.0
END_URL
    chmod 644 $file
  if test -z "$dst"
    then
      ../urlsimu -u dav -p dav $file  > ./dav_stat.log >> $LOGFILE
    else
      hdr="Destination: http://$host$dst"
      ../urlsimu -u dav -p dav $file -l "$hdr" > ./dav_stat.log >> $LOGFILE
  fi
CheckLog "$line" 4 ./dav_stat.log
rm -f $file
rm -f ./dav_stat.log
}


Line ()
{
  ECHO ""
  ECHO "--------------------------------------------------------------------"
  ECHO ""
}

#
# Start state on publisher
#
#     	1 /DAV/repl/res1.txt
#     	2 /DAV/repl/1/res1.txt
#     	3 /DAV/repl/1/11/res1.txt
#     	4 /DAV/repl/1/11/res3.txt
#     	5 /DAV/repl/1/12/res1.txt
#     	6 /DAV/repl/1/12/res3.txt
#     	7 /DAV/repl/2/21/res1.txt
#       8 /DAV/repl/2/22/res1.txt
#     	9 /DAV/repl/large/res2.txt
#
# End state on both
#
#	1 /DAV/repl/res3.txt
#	2 /DAV/repl/3/res1.txt
#	3 /DAV/repl/3/11/res1.txt
#	4 /DAV/repl/3/11/res3.txt
#	5 /DAV/repl/3/12/res1.txt
#	6 /DAV/repl/3/12/res3.txt
#	7 /DAV/repl/4/21/res1.txt
#	8 /DAV/repl/4/22/res1.txt
#	9 /DAV/repl/large/res2.txt
#

CLEANUP_DIRS ()
{
# CLEANUP DB
rm -f ./trepl.log
cat rep1/wi.err >> wierr.rep1 2>/dev/null
cat rep2/wi.err >> wierr.rep2 2>/dev/null
cat rep3/wi.err >> wierr.rep3 2>/dev/null
rm -rf rep1/* rep2/* rep3/*
}

STOP_SERVERS ()
{
_nservers=$1    
_dsn=$DSN
DSN=$DS1
SHUTDOWN_SERVER
DSN=$DS2
SHUTDOWN_SERVER
if [ $_nservers -gt 2 ]
then
 DSN=$DS3
 SHUTDOWN_SERVER
fi
DSN=$_dsn
}

START_SERVERS ()
{
_nservers=$1    
mkdir rep1
mkdir rep2
mkdir rep3
# First replication server configuration
#Line
SILENT=0
cd rep1
MakeConfig $DBNAME1 $http1 $DS1
CHECK_PORT $http1
ECHO "Starting server 'rep1'"
START_SERVER $DS1 1000
cd ..

# Second replication server configuration
#Line
cd rep2
MakeConfig $DBNAME2 $http2 $DS2
CHECK_PORT $http2
ECHO "Starting server 'rep2'"
START_SERVER $DS2 1000
cd ..

if [ $_nservers -gt 2 ]
then
 cd rep3
 MakeConfig $DBNAME3 $http3 $DS3
 CHECK_PORT $http3
 ECHO "Starting server 'rep3'"
 START_SERVER $DS3 1000
 cd ..
 fi
}



REPLDAV ()
{
# First replication server configuration
STOP_SERVERS 2
CLEANUP_DIRS
START_SERVERS 2 

RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'DS1=$DS1' 'DS2=$DS2' 'HTTP1=$http1' 'HTTP2=$http2' 'SIZE0=$size0' 'SIZE1=$size1' < trepl.sql
if test $? -ne 0
then
    LOG "***ABORTED: replication test -- trepl.sql"
    exit 1
fi

Line
STOP_SERVERS 2
}

REPLMIXED ()
{

for i in `find rep?/ -name 'core*'`
  do
    echo "***ABORTED: trepll.sh: The WebDAV repilcation test dumped a core file"
    exit 3
  done

CLEANUP_DIRS
START_SERVERS 3

SILENT=0
Line
LOG "STARTED: Mixed transactional replication test"
Line

DAVcommand localhost $http1 "MKCOL /DAV/repl/"
# WebDAV & table replication
RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u 'DS1=$DS1' 'DS2=$DS2' < trepl_t1.sql
# Procedure replication
RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u 'DS1=$DS1' 'DS2=$DS2' < trepl_p1.sql

#XXX: disabled - it hangs the trepl.sh (something to do with FT indexes & replication)
RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u 'DS1=$DS1' 'DS2=$DS2' < ftirepl.sql

# DDL repl
RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u 'DS1=$DS1' 'DS2=$DS2' < trepl_ddl.sql

STOP_SERVERS 3
CLEANUP_DIRS
START_SERVERS 3
#
# bi-directional replication test
Line
LOG "STARTED: Bi-directional transactional replication test"
Line

# initialize
RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u "DBNAME1=$DBNAME1" "DBNAME2=$DBNAME2" "DS2=$DS2" "DBNAME3=$DBNAME3" "DS3=$DS3" < ../repl_trx/regress/publish.sql
RUN $ISQL $DS2 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u "DBNAME=$DBNAME1" "DS=$DS1" "TARGET_DBNAME=$DBNAME2" "TARGET_DS=$DS2" < ../repl_trx/regress/subscribe.sql
RUN $ISQL $DS3 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u "DBNAME=$DBNAME1" "DS=$DS1" "TARGET_DBNAME=$DBNAME3" "TARGET_DS=$DS3" < ../repl_trx/regress/subscribe.sql

# run
RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u "DBNAME1=$DBNAME1" "DS1=$DS1" "DBNAME2=$DBNAME2" "DS2=$DS2" "DBNAME3=$DBNAME3" "DS3=$DS3" < ../repl_trx/regress/regress.sql

# post-checks
if grep foo.log rep1/repl.cfg >/dev/null; then
	ECHO "***FAILED: foo.log entry deleted from repl.cfg"
else
	ECHO "PASSED: foo.log entry deleted from repl.cfg"
fi
if [ -f rep1/foo.log ]; then
	ECHO "***FAILED: foo.log deleted"
else
	ECHO "PASSED: foo.log deleted"
fi

STOP_SERVERS 3
CLEANUP_DIRS
START_SERVERS 3
#
# bi-directional snapshot test
Line
LOG "STARTED: Bi-directional snapshot replication test"
Line

# initialize
RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u "DBNAME1=$DBNAME1" "DBNAME2=$DBNAME2" "DS2=$DS2" "DBNAME3=$DBNAME3" "DS3=$DS3" < ../repl_trx/bidir-regress/publish.sql
RUN $ISQL $DS2 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u "DBNAME=$DBNAME1" "DS=$DS1" "TARGET_DBNAME=$DBNAME2" "TARGET_DS=$DS2" < ../repl_trx/bidir-regress/subscribe.sql
RUN $ISQL $DS3 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u "DBNAME=$DBNAME1" "DS=$DS1" "TARGET_DBNAME=$DBNAME3" "TARGET_DS=$DS3" < ../repl_trx/bidir-regress/subscribe.sql

# run
RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u "DBNAME1=$DBNAME1" "DS1=$DS1" "DBNAME2=$DBNAME2" "DS2=$DS2" "DBNAME3=$DBNAME3" "DS3=$DS3" < ../repl_trx/bidir-regress/regress.sql

#
# bi-directional snapshot DAV test
Line
LOG "STARTED: Bi-directional snapshot DAV replication test"
Line

STOP_SERVERS 3
CLEANUP_DIRS
START_SERVERS 3
# initialize
RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u "DBNAME1=$DBNAME1" "DBNAME2=$DBNAME2" "DS2=$DS2" "DBNAME3=$DBNAME3" "DS3=$DS3" < ../repl_trx/bidir-dav/publish.sql
RUN $ISQL $DS2 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u "DBNAME=$DBNAME1" "DS=$DS1" "TARGET_DBNAME=$DBNAME2" "TARGET_DS=$DS2" < ../repl_trx/bidir-dav/subscribe.sql
RUN $ISQL $DS3 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u "DBNAME=$DBNAME1" "DS=$DS1" "TARGET_DBNAME=$DBNAME3" "TARGET_DS=$DS3" < ../repl_trx/bidir-dav/subscribe.sql

# run
RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u "DBNAME1=$DBNAME1" "DS1=$DS1" "DBNAME2=$DBNAME2" "DS2=$DS2" "DBNAME3=$DBNAME3" "DS3=$DS3" < ../repl_trx/bidir-dav/regress.sql

STOP_SERVERS 3
}

REPLDAV2 ()
{
# First replication server configuration
STOP_SERVERS 2

CLEANUP_DIRS

START_SERVERS 2

RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < ../repl_trx/bidir-dav/sub_init.sql 
if test $? -ne 0
then
    LOG "***ABORTED: DAV2 replication test -- sub_init"
    exit 1
fi

RUN $ISQL $DS2 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'DS1=$DS1' < ../repl_trx/bidir-dav/pub_init.sql 
if test $? -ne 0
then
    LOG "***ABORTED: DAV2 replication test -- pub_init.sql"
    exit 1
fi

RUN $ISQL $DS2 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < ../repl_trx/bidir-dav/repl_proc.sql
if test $? -ne 0
then
    LOG "***ABORTED: DAV2 replication test -- repl_proc.sql"
    exit 1
fi

Line
STOP_SERVERS 2
Line
}

BANNER "STARTED SERIES OF TRANSACTIONAL REPLICATION TESTS"
NOLITE
rm -f wierr.rep1 wierr.rep2  wierr.rep3
if test $mixed
  then
    REPLMIXED
  else
    REPLDAV
    REPLMIXED
fi

LOG "============ BEGIN REPLDAV2 ============"
#REPLDAV2
CHECK_LOG

echo ""
echo "============ REPLICATION TEST FINISHED ============="
echo ""

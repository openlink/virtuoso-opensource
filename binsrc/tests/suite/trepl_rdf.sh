#!/bin/sh
#  
#  $Id: trepl_rdf.sh,v 1.1.2.2.4.4 2013/01/02 16:15:21 source Exp $
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2019 OpenLink Software
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

LOGFILE=./trepl_rdf.output
export LOGFILE


. $VIRTUOSO_TEST/testlib.sh



# TEST PARAMETERS
DS1=$PORT
DS2=`expr $PORT + 1`
DS3=`expr $PORT + 2`
http1=$HTTPPORT
http2=`expr $HTTPPORT + 1`
http3=`expr $HTTPPORT + 2`
DBNAME1=trepl_rdf_1
DBNAME2=trepl_rdf_2
DBNAME3=trepl_rdf_3
size0=500000
size1=1000000
two=""
mixed=""

. $VIRTUOSO_TEST/testlib.sh


if [ "$VIRTUOSO_VDB" = "0" ]
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

Line ()
{
  ECHO ""
  ECHO "--------------------------------------------------------------------"
  ECHO ""
}

CLEANUP_DIRS ()
{
# CLEANUP DB
rm -f ./trepl_rdf.log
cat trepl_rdf_1/wi.err >> wierr.rep1 2>/dev/null
cat trepl_rdf_2/wi.err >> wierr.rep2 2>/dev/null
cat trepl_rdf_3/wi.err >> wierr.rep3 2>/dev/null
rm -rf trepl_rdf_1/* trepl_rdf_2/* trepl_rdf_3/*
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
mkdir trepl_rdf_1
mkdir trepl_rdf_2
mkdir trepl_rdf_3
# First replication server configuration
#Line
SILENT=0
cd trepl_rdf_1
MakeConfig $DBNAME1 $http1 $DS1
CHECK_PORT $http1
ECHO "Starting server 'trepl_rdf_1'"
START_SERVER $DS1 1000
cd ..

# Second replication server configuration
#Line
cd trepl_rdf_2
MakeConfig $DBNAME2 $http2 $DS2
CHECK_PORT $http2
ECHO "Starting server 'trepl_rdf_2'"
START_SERVER $DS2 1000
cd ..

if [ $_nservers -gt 2 ]
then
 cd trepl_rdf_3
 MakeConfig $DBNAME3 $http3 $DS3
 CHECK_PORT $http3
 ECHO "Starting server 'trepl_rdf_3'"
 START_SERVER $DS3 1000
 cd ..
 fi
}

rm $LOGFILE
STOP_SERVERS 3
CLEANUP_DIRS
START_SERVERS 2

SILENT=0
Line
LOG "STARTED: RDF replication test"
Line

RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF BANNER=OFF PROMPT=OFF -u 'DS1=$DS1' 'DS2=$DS2' < $VIRTUOSO_TEST/trepl_rdf.sql

STOP_SERVERS 2

echo ""
echo "============ REPLICATION TEST FINISHED ============="
echo ""

#!/bin/sh
#
#  testlib.sh
#
#  $Id: testlib.sh,v 1.1.2.7 2013/01/02 16:15:07 source Exp $
#
#  Generic test functions which should be read at the beginning of the
#  shell script.
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
#  

. $VIRTUOSO_TEST/go_functions.sh

# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL


#===========================================================================
#  Set global environment variables for test suite
#===========================================================================
DEBUG=${DEBUG-0}
SERVER=${SERVER-M2}
ISQL=${ISQL-isql}
BLOBS=${BLOBS-blobs}
SCROLL=${SCROLL-scroll}
INS=${INS-ins}
PORT=${PORT-1111}
HTTPPORT=`expr $PORT + 7000`
POP3PORT=`expr $PORT + 6000`
NNTPPORT=`expr $PORT + 5000`
FTPPORT=`expr $PORT + 4000`
HOST=${HOST-localhost}
SQLOPTIMIZE=${SQLOPTIMIZE-0}
PLDBG=${PLDBG-0}
LITEMODE=${LITEMODE-0}
CASE_MODE=${CASE_MODE-1}

MAKE=${MAKE-make}
export MAKE

DELETEMASK=${DELETEMASK-'wi.* witemp.*'}
SRVMSGLOGFILE=${SRVMSGLOGFILE-'wi.err'}
TESTCFGFILE=${TESTCFGFILE-witest.cfg}
#TESTCFGFILEDS1=${TESTCFGFILEDS1-witest.cfg}
#TESTCFGFILEDS2=${TESTCFGFILEDS2-witest.cfg}
CFGFILE=${CFGFILE-wi.cfg}
DBLOGFILE=${DBLOGFILE-wi.trx}
DBFILE=${DBFILE-wi.db}
BACKUP_DUMP_OPTION=${BACKUP_DUMP_OPTION--d}
CRASH_DUMP_OPTION=${CRASH_DUMP_OPTION--D}
OBACKUP_REP_OPTION=${OBACKUP_REP_OPTION--r}
OBACKUP_DIRS_OPTION=${OBACKUP_DIRS_OPTION--B}
HOST_OS=`uname -s | grep WIN`

if [ "x$HOST_OS" != "x" ]
then
    #
    #  Running on Windows NT
    #
    DSN=$HOST:$PORT
    SERVICE=
    BINDIR=../
    PATH=$BINDIR:..:.:../..:$PATH
#    case $SERVER in
#    	*[Mm]2*)
#	  SERVER=virtuoso-odbc-t.exe
#	  CFGFILE=virtuoso.ini
#	  DBFILE=virtuoso.db
#	  DBLOGFILE=virtuoso.trx
#	  DELETEMASK="virtuoso.log virtuoso.lck $DBLOGFILE $DBFILE"
#	  TESTCFGFILE=virtuoso-1111.ini
#          #TESTCFGFILEDS1=virtuoso-1111.ini
#          #TESTCFGFILEDS2=virtuoso-1112.ini
#	  BACKUP_DUMP_OPTION=+backup-dump
#	  CRASH_DUMP_OPTION=+crash-dump
#	  ;;
#    esac
# only in that case
#	  FOREGROUND_OPTION=+foreground
#	  LOCKFILE=virtuoso.lck
#	  export FOREGROUND_OPTION LOCKFILE
# also we need to export some of parameters
#	  export CFGFILE DBFILE DBLOGFILE DELETEMASK TESTCFGFILE
#	  export TESTCFGFILEDS1 TESTCFGFILEDS2 BACKUP_DUMP_OPTION CRASH_DUMP_OPTION
else
    #
    #  We are on UNIX
    #
    DSN=$HOST:$PORT
    BINDIR=$HOME/bin
    PATH=$BINDIR:.:..:../..:$PATH:/usr/etc:/usr/sbin:/etc
fi

if [ "x`uname -s`" = "xDarwin" ]
then
HOST=localhost
export HOST
fi

export SERVER ISQL PORT DSN SERVICE BINDIR PATH DEBUG

#===========================================================================
#  Standard functions
#===========================================================================
NOLITE()
{
    grep "Lite Mode" ident.txt
    if test $? -eq 0
    then
	echo "This test is not used in LITE mode"
	exit
    fi
}

ECHO()
{
    echo "$*"		| tee -a $LOGFILE
}

LOG()
{
    silent=${SILENT-1}    
    if test $silent -eq 1
    then
	echo "$*"	>> $LOGFILE
    else
	echo "$*"	| tee -a $LOGFILE
    fi
}

GET_TEST_DIR_SUFFIX()
{
    if [ $# -lt 2 ]
    then
        LOG "***ABORTED: GET_TEST_DIR_SUFFIX has wrong number of parameters: GET_TEST_DIR_SUFFIX virtuoso_capacity default_table_scheme"
        return
    fi
    virtuoso_capacity=$1
    default_table_scheme=$2
    shift
    shift
    
    GET_TEST_DIR_SUFFIX_RESULT=".test"
    #TEST_DIR_SUFFIXES="ro co clro clco"
    #export TEST_DIR_SUFFIXES
    
    if [ "$virtuoso_capacity" = "single" ] # single config
    then
        if [ "$default_table_scheme" = "col" ]
        then
           GET_TEST_DIR_SUFFIX_RESULT="co"
        else
           GET_TEST_DIR_SUFFIX_RESULT="ro"
        fi
    else  # cluster config
        if [ "$default_table_scheme" = "col" ]
        then
           GET_TEST_DIR_SUFFIX_RESULT="clco"
        else
           GET_TEST_DIR_SUFFIX_RESULT="clro"
        fi
    fi
}

RUN()
{
    silent=${SILENT-1}
    echo "# $*"
    echo "+ $*"		>> $LOGFILE

    STATUS=1
    if test $silent -eq 1
    then
	eval $*		>> $LOGFILE 2>>/dev/null
    else
	eval $*		>> $LOGFILE
    fi
    STATUS=$?
}

RUNSQL()
{
    sql=$1
    RUN $ISQL $DSN dba dba '"EXEC=$sql"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
}


RUNSERVER()
{
    if test "$M2DDD"
    then
      echo "Now we have to run DDD with $*"
      srv=$1
      shift
      echo "run $*" > .gdbcmd
      ddd --command=.gdbcmd `which $srv` &
    elif test -d "$VALGRIND"
    then
      xx=`ls "$VALGRIND"/vg*.* | wc -l 2>/dev/null | sed -e 's/\ //g'`
      valgrind -v --suppressions="$VALGRIND/suppress_suite.valgrind" --logfile-fd=9 --leak-check=yes --num-callers=50 --leak-resolution=high --error-limit=no $* 9>"$VALGRIND/vg$xx.vg"
    elif test -d "$PURIFY"
    then
      xx=`ls /cygdrive/d/O12/bin/suite/pfy | wc -l | sed -e 's/\ //g'`
      datafile="d:\o12\bin\suite\pfy\'$xx'.pfy"
      echo "Now we have to run purify with [$datafile] $*"
      purify.exe /AllocCallStackLength=50 /ErrorCallStackLength=50 /SaveData=$datafile $* &
    else
      echo "Now we have to start $*"
      # Here we switch log file to prevent server debug output 
      # (like dbg_obj_print ..) to be printed in same log as for test
      SAVE_LOG=$LOGFILE
      LOGFILE=$SAVE_LOG.svr
      RUN $*
      LOGFILE=$SAVE_LOG
    fi
}

LINE()
{
    ECHO "====================================================================="
}


BANNER()
{
    ECHO ""
    LINE
    ECHO "=  $*"
    ECHO "= " `date`
    LINE
    ECHO ""
}


START_SERVER()
{
    if [ "$CURRENT_VIRTUOSO_CAPACITY" = "multiple" ]
    then
      CL_START_SERVER $*
      return $?
    fi        
    if test "$HOST" != "localhost"
    then
	return
    fi

    if [ $# -lt 2 ]
    then
        LOG "***FAILED: START_SERVER Missing parameters"
        LOG "Usage: START_SERVER: port timeout"
        exit 1
    fi

    port=$1
    timeout=$2
    title=${SERVER_TITLE-test}
    shift
    shift

    stat="true"
    ddate=`date`
    starth=`date | cut -f 2 -d :`
    starts=`date | cut -f 3 -d :|cut -f 1 -d " "`
    while [ "z$stat" != "z" -a $timeout -gt 0 ]
    do
	sleep 1
	stat=`netstat -an | grep "[\.\:]$port " | grep LISTEN`

	nowh=`date | cut -f 2 -d :`
	nows=`date | cut -f 3 -d : | cut -f 1 -d " "`

	nowh=`expr $nowh - $starth`
	nows=`expr $nows - $starts`

	nows=`expr $nows + $nowh \*  60`
	if test $nows -ge $timeout
	then
	    LOG "***FAILED: The Listener on port $port didn't stop within $timeout seconds"
	    exit 1
	fi
    done

    ddate=`date`
    starth=`date | cut -f 2 -d :`
    starts=`date | cut -f 3 -d :|cut -f 1 -d " "`
    
    if test -f "$LOCKFILE"
    then
        echo Removing $LOCKFILE >> $LOGFILE
        rm $LOCKFILE
    fi
    
    if [ $timeout -eq 0 ]
    then
        RUNSERVER $SERVER $port $*
    else 
        RUNSERVER $SERVER $port $* &
    fi
    
    if [ $timeout -gt 0 ]
    then
        while true
        do
            stat=`netstat -an | grep "[\.\:]$port " | grep LISTEN`
            if [ "z$stat" != "z" ]
            then
        	LOG "PASSED: Virtuoso Server successfully started on port $port"
        	break
            fi
            sleep 1
            nowh=`date | cut -f 2 -d :`
            nows=`date | cut -f 3 -d : | cut -f 1 -d " "`
            
            nowh=`expr $nowh - $starth`
            nows=`expr $nows - $starts`
            
            nows=`expr $nows + $nowh \*  60`
            if test $nows -ge $timeout
            then
        	LOG "***FAILED: Could not start Virtuoso Server within $timeout seconds"
        	exit 1
            fi
        done
    fi

#        if [ "$CURRENT_VIRTUOSO_CAPACITY" = "multiple" -a ! -f virtuoso-cluster-inited ]
#        then
#	  this_host=`grep "ThisHost\s*=" cluster.ini | cut -d "=" -f 2`
#	  master_host=`grep "Master\s*=" cluster.ini | cut -d "=" -f 2`
#	  if [ "$this_host" = "$master_host" ]
#	  then 
#              LOG "RDF storage will be reconfigured for elastic cluster now ..."
#              RUN $ISQL $port dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/../../../libsrc/Wi/rdfela.sql
#              if test $STATUS -ne 0
#              then
#		  LOG "***ABORTED: RDF storage cannot be reconfigured for elastic cluster. "
#		  exit 3
#              else 
#		  echo "virtuoso and RDF storage inited on port $port" > virtuoso-cluster-inited
#              fi
#	  fi
#        fi
        
    if [ "$DEBUG" = "1" ]
    then
	echo USE DEBUGGER NOW TO ATTACH TO $title VIRTUOSO PROCESS \#`cat virtuoso.lck|cut -d "=" -f 2`, THEN PRESS ENTER.
	read REPLY
    fi

    return 0
}

CHECK_PORT()
{
  port=$1
  while true
  do
    stat=`netstat -an | grep "[\.\:]$port " | grep LISTEN`
    if [ "z$stat" = "z" ]
    then
	LOG "PASSED: Port $port is not listened by any process"
	return 0
    fi
    sleep 1
    nowh=`date | cut -f 2 -d :`
    nows=`date | cut -f 3 -d : | cut -f 1 -d " "`

    nowh=`expr $nowh - $starth`
    nows=`expr $nows - $starts`

    nows=`expr $nows + $nowh \*  60`
    if test $nows -ge $timeout
    then
	LOG "***FAILED: Port $port is not freed during $timeout seconds"
	exit 1
    fi
  done  
}

STOP_SERVER()
{
    if [ "$CURRENT_VIRTUOSO_CAPACITY" = "multiple" ]
    then
        CL_STOP_SERVER $*
        return $?
    fi      
    srvdsn=${1-$DSN}
    if test "$HOST" = "localhost"
    then
	LOG "Stop database with raw_exit"
	RUN $ISQL $srvdsn dba dba '"EXEC=raw_exit();"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
    fi
}

SHUTDOWN_SERVER()
{
    if [ "$CURRENT_VIRTUOSO_CAPACITY" = "multiple" ]
    then
      CL_SHUTDOWN_SERVER $*
      return $?
    fi       
    srvdsn=${1-$DSN}
    if test "$HOST" = "localhost"
    then
	    RUN $ISQL $srvdsn dba dba '"EXEC=shutdown"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
    fi
}

KILL_TEST_INSTANCES()
{
    #
    #  Killing virtuoso instances left, if any.
    #
    for f in `find . -type f -name virtuoso.lck`; do . $f ; kill $VIRT_PID ; done
}


CHECKPOINT_SERVER()
{
    if [ "$CURRENT_VIRTUOSO_CAPACITY" = "multiple" ]
    then
      CL_CHECKPOINT_SERVER $*
      return $?
    fi       
    srvdsn=${1-$DSN}
    RUN $ISQL $srvdsn dba dba '"EXEC=checkpoint"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
}

GENERATE_RELEASE_IDENT()
{
  port=$1
  ident_file=${2-ident.txt}

  LOG "Getting the status of database into file $ident_file"
  if $ISQL $port "EXEC=status();" VERBOSE=OFF ERRORS=STDOUT > $ident_file
  then
    # ident.txt created and longer than zero bytes?
    if test -s $ident_file
    then
        LOG "PASSED: Inquiring database status"
    else
        LOG "***FAILED: Inquiring database status, $ident_file missing or empty"
        exit 3
    fi
  else
    LOG "***ABORTED: Inquiring database status"
    exit 3
  fi
}

CHECK_LOG()
{
#   I've modified these grep patterns to ignore ':' which may be forgoten easily.
    passed=`find . -type f -name "*.output" -print0 | xargs -0 grep -E "^PASSED" | wc -l`
    failed=`find . -type f -name "*.output" -print0 | xargs -0 grep -E "^\*\*\* ?FAILED" | wc -l`
    aborted=`find . -type f -name "*.output" -print0 | xargs -0 grep -E "^\*\*\* ?ABORTED" | wc -l`

    ECHO ""
    LINE
    ECHO "=  Checking log files \*.output for statistics:"
    ECHO "="
    ECHO "=  Total number of tests PASSED  : $passed"
    ECHO "=  Total number of tests FAILED  : $failed"
    ECHO "=  Total number of tests ABORTED : $aborted"
    LINE
    ECHO ""

    if (expr $failed + $aborted \> 0 > /dev/null)
    then
       ECHO "*** Not all tests completed successfully"
       ECHO "*** Check the file $LOGFILE for more information"
       echo "Failed tests:" >> $LOGFILE
       find . -type f -name "*.output" -print0 | xargs -0 grep -El "^\*\*\* ?FAILED" >> $LOGFILE
       echo "Aborted tests:" >> $LOGFILE
       find . -type f -name "*.output" -print0 | xargs -0 grep -El "^\*\*\* ?ABORTED" >> $LOGFILE
    fi
}

GENERATE_PORTS()
{
  n_ports=${1-1}
  virtuoso_port_range_start=${2-1112}
  virtuoso_port_range_end=${3-1999}
  http_port_range_start=${4-2000}
  http_port_range_end=${5-2200}
  run_tests_in_parallel=0

if [ $run_tests_in_parallel -ne 0 ]
then
  ROUND_ROBIN_LOCK_INDEX=""
  create_round_robin_lock_file $VIRTUOSO_TEST/PORTS/port $virtuoso_port_range_start $virtuoso_port_range_end "port locked by test $test"
  GENERATED_PORT=$ROUND_ROBIN_LOCK_INDEX

  if [ $n_ports -gt 1 ]
  then
    ROUND_ROBIN_LOCK_INDEX=""
    create_round_robin_lock_file $VIRTUOSO_TEST/PORTS/port $http_port_range_start $http_port_range_end "port locked by test $test for HTTP"
    GENERATED_HTTPPORT=$ROUND_ROBIN_LOCK_INDEX  
  fi
else
	GENERATED_PORT=$PORT
	GENERATED_HTTPPORT=`expr $PORT + 7000`
fi
}

RUN_TEST()
{
  cfg=$1
  test=$2
  silent=${SILENT-1}
  if [ $# -gt 2 ]
  then
      silent=$3
      shift
  fi
  shift
  shift
  if [ "$DEBUG" = "1" ]
  then
      silent=0
  fi
  test_exe=${test}.sh
  GET_TEST_DIR_SUFFIX $CURRENT_VIRTUOSO_CAPACITY $CURRENT_VIRTUOSO_TABLE_SCHEME
  test_dir_suffix=$GET_TEST_DIR_SUFFIX_RESULT
  test_dir=${test}.$test_dir_suffix
  rm -rf $VIRTUOSO_TEST/$test_dir
  mkdir $VIRTUOSO_TEST/$test_dir
  LOGFILE=$test.output
  export LOGFILE
  
  cp $CFGFILE $VIRTUOSO_TEST/$test_dir
  cp $TESTCFGFILE $VIRTUOSO_TEST/$test_dir

  if [ -s $VIRTUOSO_TEST/ident.txt ]
  then
    cp $VIRTUOSO_TEST/ident.txt $VIRTUOSO_TEST/$test_dir
  else
    MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
    START_SERVER $PORT 1000
    GENERATE_RELEASE_IDENT $PORT $VIRTUOSO_TEST/ident.txt
    STOP_SERVER
    cp $VIRTUOSO_TEST/ident.txt $VIRTUOSO_TEST/$test_dir
  fi
  
  GENERATE_PORTS 2
  PORT=$GENERATED_PORT
  HTTPPORT=$GENERATED_HTTPPORT
  echo "test started: $test, Virtuoso port $PORT, HTTP port $HTTPPORT"
  cd $VIRTUOSO_TEST/$test_dir
  export SILENT=$silent
  if [ "$silent" = "1" ]
  then
      $VIRTUOSO_TEST/$test_exe $* > $VIRTUOSO_TEST/$test_dir/stdout 2>&1
  else
      $VIRTUOSO_TEST/$test_exe $* 
  fi
  echo "test finished: $test"
}

RUN_SQL_TEST()
{
  cfg=$1
  test=$2
  silent=1
  if [ $# -gt 2 ]
  then
      silent=$3
      shift
  fi
  shift
  shift
  if [ "$DEBUG" = "1" ]
  then
      silent=0
  fi
  GET_TEST_DIR_SUFFIX $CURRENT_VIRTUOSO_CAPACITY $CURRENT_VIRTUOSO_TABLE_SCHEME
  test_dir_suffix=$GET_TEST_DIR_SUFFIX_RESULT
  test_dir=${test}.$test_dir_suffix  
  rm -rf $VIRTUOSO_TEST/$test_dir
  mkdir $VIRTUOSO_TEST/$test_dir
  LOGFILE=$test.output
  export LOGFILE
  export SILENT=$silent

  cp $CFGFILE $VIRTUOSO_TEST/$test_dir
  cp $TESTCFGFILE $VIRTUOSO_TEST/$test_dir
  cp $VIRTUOSO_TEST/words.esp $VIRTUOSO_TEST/$test_dir
  cp $VIRTUOSO_TEST/spanish.coll $VIRTUOSO_TEST/$test_dir

  if [ -s $VIRTUOSO_TEST/ident.txt ]
  then
    cp $VIRTUOSO_TEST/ident.txt $VIRTUOSO_TEST/$test_dir
  else
    MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
    START_SERVER $PORT 1000
    GENERATE_RELEASE_IDENT $PORT $VIRTUOSO_TEST/ident.txt
    STOP_SERVER
    cp $VIRTUOSO_TEST/ident.txt $VIRTUOSO_TEST/$test_dir
  fi
  
  GENERATE_PORTS 2
  PORT=$GENERATED_PORT
  DSN=$PORT
  HTTPPORT=$GENERATED_HTTPPORT

  echo "test started: $test, Virtuoso port $PORT, HTTP port $HTTPPORT"
  cd $VIRTUOSO_TEST/$test_dir
  
  BANNER "STARTED TEST " $test
  MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
  START_SERVER $PORT 1000
        
  LOG + running sql script $test.sql
  RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/$test.sql
  if test $STATUS -ne 0
  then
    LOG "***ABORTED: $test.sql."
    exit 3
  fi
       
  SHUTDOWN_SERVER
  CHECK_LOG
  
  echo "test finished: $test"
}

RUN_DIFF()
{
    if test $# -lt 3
    then
	LOG "***FAILED: DIFF Missing parameters"
	LOG "Usage: DIFF: file1 file2 file3"
	LOG "file1 and file2 are compared with diff, whose output is written to file3 "
	exit 1;
    fi

    if test \! -r $1
    then
	LOG "***FAILED: The file $1 is missing"
	exit 1;
    fi

    if test \! -r $2
    then
	LOG "***FAILED: The file $2 is missing"
	exit 1;
    fi

    # The diff coming with CygWin32 is so wretched that we use the ancient
    # COMP command of MS-DOS instead:
#    if test "x$OSTYPE" = "xwin32"
#    then
	# Avoid the localization problems by creating comp.ok first time
	# by comparing that shell file to itself, to get the message
	# 	"Files compare OK"
	# in whatever language it might be:
#	if test \! -r comp.ok
#	then
#	    echo n | comp testall.sh testall.sh | head -2 | tail -1 > comp.ok
#	    if test \! -s comp.ok
#	    then
#		LOG "***FAILED: DIFF $1 $2 Could not create file comp.ok"
#		exit 1;
#	    fi
#	fi
	# Okay, then compare the files 1 and 2 with comp.
#	echo n | comp $1 $2 | head -2 | tail -1 > comp.tmp
#	diff -uN comp.tmp comp.ok > $3

#   else # Else, it's normal sane Unix platform:
	diff  $1 $2 > $3
#    fi

    # Common for NT and Unix platforms:

    # $3 exists and is readable?
    if test -r $3
    then
	# $3 longer than zero bytes?
	if test -s $3
	then
	    LOG "***FAILED: The files $1 and $2 differ. See file $3"
	    #XXX exit 1;
	else
	    LOG "PASSED: The files $1 and $2 are identical"
	fi
    else
	LOG "***FAILED: No $3 file produced. Check files $1 and $2"
	exit 1;
    fi
}

MAKECFG_FILE ()
{
  if [ "$CURRENT_VIRTUOSO_CAPACITY" = "multiple" ]
  then
    CL_MAKECFG_FILE $*
    return $?
  fi
  _testcfgfile=$1
  _port=$2
  _cfgfile=$3
  column_store=0
  if [ "$CURRENT_VIRTUOSO_TABLE_SCHEME" = "row" ]
  then
      column_store=0
  else
      column_store=1
  fi
  cat $_testcfgfile | sed -e "s/PORT/$_port/g" -e "s/SQLOPTIMIZE/$SQLOPTIMIZE/g" -e "s/PLDBG/$PLDBG/g" -e "s/CASE_MODE/$CASE_MODE/g" -e "s/LITEMODE/$LITEMODE/g" -e "s/COLUMN_STORE/$column_store/g" > $_cfgfile
}

MAKECFG_FILE_WITH_HTTP()
{
  template=$1
  port=$2
  httpport=$3
  cfgfile=$4
  MAKECFG_FILE $template $port $cfgfile
  case $SERVER in
   *[Mm]2*)
   cat >> $cfgfile <<END_HTTP
HTTPLogFile: http.log
http_port: $httpport
http_threads: 3
http_keep_alive_timeout: 15 
http_max_keep_alives: 6
http_max_cached_proxy_connections: 10
http_proxy_connection_cache_timeout: 15
END_HTTP
   ;;
   *virtuoso*)
   cat >> $cfgfile <<END_HTTP1
[HTTPServer]
HTTPLogFile = http.log
ServerPort = $httpport
ServerRoot = .
ServerThreads = 3 
MaxKeepAlives = 6
KeepAliveTimeout = 15
MaxCachedProxyConnections = 10
ProxyConnectionCacheTimeout = 15

[Plugins]
LoadPath = $PLUGINDIR
Load1 = plain, wbxml2

[URIQA]
DynamicLocal = 1
DefaultHost = localhost:$httpport
END_HTTP1
;;
esac
}

CHECK_IF_SERVER_STARTABLE()
{
  #  Make sure the database is not running
  STOP_SERVER
  rm -f $DELETEMASK
  MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
  START_SERVER $PORT 1000
  GENERATE_RELEASE_IDENT $PORT ident.txt
  #  And kill it immediately afterwards 
  STOP_SERVER
}

CHECK_IF_DB_FILES_DELETABLE()
{
  #
  #  Make sure that the log file (wi.trx) and the database file (wi.db) are deletable in Windows NT
  #
  RUN rm -f $DELETEMASK
  if test -f "$DBFILE"
  then
    LOG "***ABORTED: Could not delete old $DBFILE file. "
    LOG "Check that it has not been left locked by Virtuoso!"
    exit 1;
  else
    LOG "PASSED: File $DBFILE successfully deleted."
  fi

  if test -f "$DBLOGFILE"
  then
    LOG "***ABORTED: Could not delete old $DBLOGFILE file."
    LOG "Check that it has not been left locked by Virtuoso!"
    exit 1;
  else
    LOG "PASSED: File $DBLOGFILE successfully deleted."
  fi
}

#===========================================================================
#  Make sure the logfile is cleared before running the tests
#===========================================================================

CLEAN_DBLOGFILE ()
{
  rm -f $DBLOGFILE
}

CLEAN_DBFILE ()
{
  rm -f $DBFILE
}

#===========================================================================
#  Set environment for test cluster suite
#===========================================================================

MAKE_CL_CFG () 
{
   if [ $# -lt 6 ]
   then
     LOG "***FAILED: MAKE_CL_CFG Missing parameters"
     LOG "Usage: MAKE_CL_CFG: cl_no db_port cl_port1 cl_port2 cl_port3 cl_port4"
     exit 1
   fi
   cl_no=$1  
   db_port=$2
   cl_port1=$3
   cl_port2=$4
   cl_port3=$5
   cl_port4=$6
   column_store=0
   if [ "$CURRENT_VIRTUOSO_TABLE_SCHEME" = "row" ]
   then
       column_store=0
   else
       column_store=1
   fi
   
   if [ ! -d "cl$cl_no" ]
   then
       mkdir "cl$cl_no"
   fi
   cat $VIRTUOSO_TEST/cluster-test.ini | 
        sed -e "s/PORT1/$cl_port1/g" -e "s/PORT2/$cl_port2/g" -e "s/PORT3/$cl_port3/g" | 
        sed -e "s/PORT4/$cl_port4/g" -e "s/THISHOST/Host$cl_no/g" > "cl$cl_no/cluster.ini"

   cat $VIRTUOSO_TEST/virtuoso-cl.ini | 
        sed -e "s/PORT/$db_port/g" -e "s/SQLOPTIMIZE/$SQLOPTIMIZE/g" -e "s/PLDBG/$PLDBG/g" -e "s/CASE_MODE/$CASE_MODE/g" -e "s/LITEMODE/$LITEMODE/g" -e "s/COLUMN_STORE/$column_store/g" > "cl$cl_no/virtuoso.ini"

   cat $VIRTUOSO_TEST/../../../binsrc/samples/demo/noise.txt > "cl$cl_no/noise.txt"
}

CL_MAKECFG_FILE ()
{
    ini_src=$1 # not used 
    db_port=$2
    ini_dst=$3 # not used

    # db_port should be already locked
    db_port1=$db_port

    GENERATE_PORTS 1
    db_port2=$GENERATED_PORT
    GENERATE_PORTS 1
    db_port3=$GENERATED_PORT
    GENERATE_PORTS 1
    db_port4=$GENERATED_PORT
   
    # generate port for cluster interconnect 
    GENERATE_PORTS 1 2500 2700
    cl_port1=$GENERATED_PORT
    GENERATE_PORTS 1 2500 2700
    cl_port2=$GENERATED_PORT
    GENERATE_PORTS 1 2500 2700
    cl_port3=$GENERATED_PORT
    GENERATE_PORTS 1 2500 2700
    cl_port4=$GENERATED_PORT

    echo "db_ports: from $db_port ($db_port1,$db_port2,$db_port3,$db_port4)' cl_ports: ($cl_port1,$cl_port2,$cl_port3,$cl_port4)"
# db_ports: from 1111 (1111,1311,1312,1313)' cl_port: 1321

    MAKE_CL_CFG 1 $db_port1 $cl_port1 $cl_port2 $cl_port3 $cl_port4 
    MAKE_CL_CFG 2 $db_port2 $cl_port1 $cl_port2 $cl_port3 $cl_port4 
    MAKE_CL_CFG 3 $db_port3 $cl_port1 $cl_port2 $cl_port3 $cl_port4 
    MAKE_CL_CFG 4 $db_port4 $cl_port1 $cl_port2 $cl_port3 $cl_port4 
    cp cl1/cluster.ini .
    cp cl1/virtuoso.ini .
}

WAIT_CLUSTER_PORT_UP ()
{
    if test $# -lt 3
    then
        LOG "***FAILED: WAIT_CLUSTER_PORT_UP Missing parameters"
        LOG "Usage: WAIT_CLUSTER_PORT_UP: port timeout"
        exit 1
    fi
    port=$1
    timeout=$2

    if [ $timeout -eq 0 ]
    then
        return
    fi

    stat="true"
    ddate=`date`
    starth=`date | cut -f 2 -d :`
    starts=`date | cut -f 3 -d :|cut -f 1 -d " "`

    while true
    do
        stat=`netstat -an | grep "[\.\:]$port " | grep LISTEN`
        if [ "z$stat" != "z" ]
        then
            LOG "PASSED: $3 listen on port $port"
            return 0
        fi
        sleep 1
        nowh=`date | cut -f 2 -d :`
        nows=`date | cut -f 3 -d : | cut -f 1 -d " "`

        nowh=`expr $nowh - $starth`
        nows=`expr $nows - $starts`

        nows=`expr $nows + $nowh \*  60`
        if test $nows -ge $timeout
        then
            LOG "***FAILED: Could not start Virtuoso cluster within $timeout seconds"
            exit 1
        fi
    done
}

WAIT_CLUSTERS_TO_STOP ()
{
    WAIT_CLUSTER_TO_STOP $LOCKFILE 100
    WAIT_CLUSTER_TO_STOP cl2/$LOCKFILE 100
    WAIT_CLUSTER_TO_STOP cl3/$LOCKFILE 100
    WAIT_CLUSTER_TO_STOP cl4/$LOCKFILE 100
}

WAIT_CLUSTER_TO_STOP ()
{
  file=$1 
  timeout=$2 
  ddate=`date`
  starth=`date | cut -f 2 -d :`
  starts=`date | cut -f 3 -d :|cut -f 1 -d " "`
  while true
  do
      if [ -f $file ]
      then
          eval `cat $file`
          stat=`ps -p $VIRT_PID | grep $VIRT_PID` 
          if [ "z$stat" = "z" ]
          then
              LOG "PASSED: cluster with lock-file $file stopped."
              return 0;
          fi
          sleep 1
          nowh=`date | cut -f 2 -d :`
          nows=`date | cut -f 3 -d : | cut -f 1 -d " "`
          nowh=`expr $nowh - $starth`
          nows=`expr $nows - $starts`
          nows=`expr $nows + $nowh \*  60`
          if test $nows -ge $timeout
          then
              LOG "***FAILED: Could not stop cluster within $timeout seconds"
              exit 1
          fi
      else
          LOG "PASSED: no lock file $file, this node of cluster is stopped."
          return 0;
      fi
  done  
}

CL_SHUTDOWN_SERVER()
{   
    srvdsn=${1-$DSN}
    if test "$HOST" = "localhost"
    then
        LOG "If the database engine is already running, we kill it with raw_exit()"
        LOG "and then we should get a Lost Connection to Server -error."
        $ISQL $srvdsn dba dba "EXEC=cl_exec ('shutdown')" VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT >> $LOGFILE
        WAIT_CLUSTERS_TO_STOP
    fi 
} 

CL_CHECKPOINT_SERVER()
{
    srvdsn=${1-$DSN}
    $ISQL $srvdsn dba dba "EXEC=cl_exec ('checkpoint')" VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT >> $LOGFILE
}


CL_STOP_SERVER()
{   
    srvdsn=${1-$DSN}
    if test "$HOST" = "localhost"
    then
        LOG "If the database engine is already running, we kill it with raw_exit()"
        LOG "and then we should get a Lost Connection to Server -error."
        $ISQL $srvdsn dba dba "EXEC=cl_exec ('raw_exit()')" VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT >> $LOGFILE
        if test $? -ne 0 
        then
            nodes="2 3 4"
            for i in $nodes
            do
                # db_port=`cat cluster.ini | egrep "Host$i\s*=\s*[[:alpha:]]+:[[:digit:]]+" | sed -e "s/Host.\s*=\s*localhost://g"`
                db_port=`cat cl$i/virtuoso.ini | egrep "ServerPort\s*=\s*[[:digit:]]+" | sed -e "s/ServerPort\s*=\s*//g"`
                RUN $ISQL $db_port dba dba '"EXEC=raw_exit()"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
            done
        fi
        WAIT_CLUSTERS_TO_STOP
    fi 
} 

CL_START_SERVER ()
{
    db_port=$1
    timeout=$2

    if [ -z $timeout ]
    then
	timeout=600
    fi

    db_port1=$db_port
    db_port2=`cat cl2/virtuoso.ini | grep "ServerPort" | sed -e "s/ServerPort.*=//g"`
    db_port3=`cat cl3/virtuoso.ini | grep "ServerPort" | sed -e "s/ServerPort.*=//g"`
    db_port4=`cat cl4/virtuoso.ini | grep "ServerPort" | sed -e "s/ServerPort.*=//g"`
    
    cl_port1=`cat cl1/cluster.ini | egrep "Host1 *= *[[:alpha:]]+[:][[:digit:]]+" | sed -e "s/Host.*localhost://g"`
    cl_port2=`cat cl2/cluster.ini | egrep "Host2 *= *[[:alpha:]]+[:][[:digit:]]+" | sed -e "s/Host.*localhost://g"`
    cl_port3=`cat cl3/cluster.ini | egrep "Host3 *= *[[:alpha:]]+[:][[:digit:]]+" | sed -e "s/Host.*localhost://g"`
    cl_port4=`cat cl4/cluster.ini | egrep "Host4 *= *[[:alpha:]]+[:][[:digit:]]+" | sed -e "s/Host.*localhost://g"`

    p_range="$db_port2 $db_port3 $db_port4 $cl_port1 $cl_port2 $cl_port3 $cl_port4"
    echo PORTS $p_range

    if test ! -z "`echo $p_range | grep $HTTPPORT`"
    then
        LOG "The cluster port range overlaps with HTTPPORT"
        exit 1
    fi

    if test ! -z "`echo $p_range | grep $POP3PORT`"
    then
        LOG "The cluster port range overlaps with POP3PORT"
        exit 1
    fi

    if test ! -z "`echo $p_range | grep $NNTPPORT`"
    then
        LOG "The cluster port range overlaps with NNTPPORT"
        exit 1
    fi

    if test ! -z "`echo $p_range | grep $FTPPORT`"
    then
        LOG "The cluster port range overlaps with FTPPORT"
        exit 1
    fi

    if test $# -lt 2
    then
        LOG "***FAILED: START_SERVER Missing parameters"
        LOG "Usage: START_SERVER: port timeout"
        exit 1
    fi

    shift
    shift

    echo "db_ports: from $db_port ($db_port1,$db_port2,$db_port3,$db_port4)' cl_ports: ($cl_port1,$cl_port2,$cl_port3,$cl_port4)"

    if [ ! -f $DBFILE ]
    then  
        rm -f cl?/$DBFILE
        rm -f cl?/$LOCKFILE
        rm -f cl?/$_2PCFILE
        rm -f $_2PCFILE
    fi 
    if [ ! -f $DBLOGFILE ]
    then
        rm -f cl?/$DBLOGFILE
        rm -f cl?/$LOCKFILE
        rm -f cl?/$_2PCFILE
        rm -f $_2PCFILE
    fi
    LOG "STARTING CLUSTER"
    FOPT=`echo $* | grep +foreground`
    if test -z "$FOPT"
    then
        (cd cl2; virtuoso-t $* & )
        (cd cl3; virtuoso-t $* & )
        (cd cl4; virtuoso-t $* & )
    else
        (cd cl2; virtuoso-t -f $* )
        (cd cl3; virtuoso-t -f $* )
        (cd cl4; virtuoso-t -f $* )
    fi
    WAIT_CLUSTER_PORT_UP $cl_port2 $timeout cluster
    WAIT_CLUSTER_PORT_UP $db_port2 $timeout sql
    WAIT_CLUSTER_PORT_UP $cl_port3 $timeout cluster
    WAIT_CLUSTER_PORT_UP $db_port3 $timeout sql
    WAIT_CLUSTER_PORT_UP $cl_port4 $timeout cluster
    WAIT_CLUSTER_PORT_UP $db_port4 $timeout sql
    if test -z "$FOPT" # start master last as it anyway would wait for other nodes to be up
    then
        (virtuoso-t -f $* & ) 
    else
        (virtuoso-t -f $* ) 
    fi
    STATUS=$?
    WAIT_CLUSTER_PORT_UP $cl_port1 $timeout cluster
    WAIT_CLUSTER_PORT_UP $db_port1 $timeout sql
    
    if [ ! -f virtuoso-cluster-inited ]
        then
          this_host=`grep "ThisHost\s*=" cluster.ini | cut -d "=" -f 2`
          master_host=`grep "Master\s*=" cluster.ini | cut -d "=" -f 2`
          if [ "$this_host" = "$master_host" ]
          then 
              LOG "Checking coordinator"
              RUN $ISQL $db_port1 dba dba 'exec="select 1"'
              if test $STATUS -ne 0
              then
                      LOG "***ABORTED: coordinator is not available"
                      exit 3
              else 
                      echo "virtuoso storage inited on port $db_port1" > virtuoso-cluster-inited
              fi
          fi
        fi
        
        if [ "$DEBUG" = "1" ]
        then
            echo USE DEBUGGER NOW TO ATTACH TO THE PROCESS \#`cat virtuoso.lck|cut -d "=" -f 2`, THEN PRESS ENTER.
            read REPLY
        fi
}


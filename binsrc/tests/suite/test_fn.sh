#!/bin/sh
set -x
#
#  Generic test functions which should be read at the beginning of the
#  shell script.
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
#  

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
SILENT=${SILENT-0}
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
LOGFILE=${LOGFILE-output.output}
SQLOPTIMIZE=${SQLOPTIMIZE-0}
PLDBG=${PLDBG-0}
LITEMODE=${LITEMODE-0}
CASE_MODE=${CASE_MODE-1}

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
    if test $SILENT -eq 1
    then
	echo "$*"	>> $LOGFILE
    else
	echo "$*"	| tee -a $LOGFILE
    fi
}

RUN()
{
    echo "# $*"
    echo "+ $*"		>> $LOGFILE

    STATUS=1
#    if [ "x$HOST_OS" != "x" -a "$1" = "$SERVER" ]
#    then
#       $*
#    else
	if test $SILENT -eq 1
	then
	    eval $*		>> $LOGFILE 2>>/dev/null
	else
	    eval $*		>> $LOGFILE
	fi
#    fi
    STATUS=$?
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
    if test "$HOST" != "localhost"
    then
	return
    fi
    port=$1
    timeout=$2

    if test $# -lt 2
    then
	LOG "***FAILED: START_SERVER Missing parameters"
	LOG "Usage: START_SERVER: port timeout"
	exit 1
    fi

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

	nows=`expr 1 + $nows + $nowh \*  60`
	if test $nows -ge $timeout
	then
	    LOG "***FAILED: The Listener on port $port didn't stop within $timeout seconds"
	    exit 1
	fi
    done

#    if test "x$HOST_OS" != "x"
#    then
	#
	#  With Windows NT we start the service preinstalled in testall.sh
	#  with -S option, which will wait until the service has done the
	#  roll forward of the log.
#	ddate=`date`
#	starth=`date | cut -f 2 -d :`
#	starts=`date | cut -f 3 -d :|cut -f 1 -d " "`
#	RUN $SERVER -I$SERVICE$port +service create $*
#	if test $? -eq 0
#	then
#	    LOG "PASSED: Virtuoso Server successfully registered as a service instance $SERVICE$port"
#	else
#	    LOG "***FAILED: Could not register Virtuoso Server as a service instance $SERVICE$port"
#	    exit 1
#	fi
#	RUN $SERVER -I$port +service start $*
#	if test $? -eq 0
#	then
#	    LOG "PASSED: Virtuoso Server successfully started as a service instance $SERVICE$port"
#	else
#	    LOG "***FAILED: Could not start Virtuoso Server as a service instance $SERVICE$port"
#	    exit 1
#	fi
#    else
	#
	#  The rest is for Unix.
	#
	ddate=`date`
	starth=`date | cut -f 2 -d :`
	starts=`date | cut -f 3 -d :|cut -f 1 -d " "`

	if [ $timeout -eq 0 ]
	then
	    RUNSERVER $SERVER $port $*
	elif test -z "$FOREGROUND_OPTION"
	then
#	    if test x$HOST_OS = x -o x$SERVER != xM2 -o x$SERVER != xM2.EXE
#	    then
		RUNSERVER $SERVER $port $* &
#	    else
#	        ECHO "Not starting the $SERVER in Windows, assuming it's running"
#	    fi
	else
	  if test -f "$LOCKFILE"
	  then
	    echo Removing $LOCKFILE >> $LOGFILE
	    rm $LOCKFILE
	  fi
#	    if test x$HOST_OS = x -o x$SERVER != xM2 -o x$SERVER != xM2.EXE
#	    then
		RUNSERVER $SERVER +foreground $* &
#	    else
#	        ECHO "Not starting the $SERVER in Windows, assuming it's running"
#	    fi
	fi
#    fi
	if [ $timeout -eq 0 ]
	then
	    return
	fi
	while true
	do
	    stat=`netstat -an | grep "[\.\:]$port " | grep LISTEN`
	    if [ "z$stat" != "z" ]
	    then
		LOG "PASSED: Virtuoso Server successfully started on port $port"
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
		LOG "***FAILED: Could not start Virtuoso Server within $timeout seconds"
		exit 1
	    fi
	done
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
    if test "$HOST" = "localhost"
    then
	LOG "Stop database with raw_exit"
	RUN $ISQL $DSN dba dba '"EXEC=raw_exit();"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
    fi
}

SHUTDOWN_SERVER()
{
    if test "$HOST" = "localhost"
    then
#	if test "x$HOST_OS" != "x"
#	then
#	    $SERVER -I$PORT +service stop
#	    $SERVER -I$PORT +service delete
#	else
	    RUN $ISQL $DSN dba dba '"EXEC=shutdown"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
#	fi
    fi
}

CHECKPOINT_SERVER()
{
    RUN $ISQL $DSN dba dba '"EXEC=checkpoint"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
}


CHECK_LOG()
{
#   I've modified these grep patterns to ignore ':' which may be forgoten easily.
    passed=`grep "^PASSED" $LOGFILE | wc -l`
    failed=`grep "^\*\*\*.*FAILED" $LOGFILE | wc -l`
    aborted=`grep "^\*\*\*.*ABORTED" $LOGFILE | wc -l`

    ECHO ""
    LINE
    ECHO "=  Checking log file $LOGFILE for statistics:"
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
    fi
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
	    exit 1;
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
  _testcfgfile=$1
  _port=$2
  _cfgfile=$3
  cat $_testcfgfile | sed -e "s/PORT/$_port/g" -e "s/SQLOPTIMIZE/$SQLOPTIMIZE/g" -e "s/PLDBG/$PLDBG/g" -e "s/CASE_MODE/$CASE_MODE/g" -e "s/LITEMODE/$LITEMODE/g" > $_cfgfile
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

#===========================================================================
#  Make sure the logfile is cleared before running the tests
#===========================================================================
rm -f $LOGFILE
rm -f cluster.ini

CLEAN_DBLOGFILE ()
{
  rm -f $DBLOGFILE
}

CLEAN_DBFILE ()
{
  rm -f $DBFILE
}

if [ "x$CLUSTER" != "x" ]
then
    . $HOME/binsrc/tests/suite/cl_test_fn.sh
fi

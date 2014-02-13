#!/bin/sh
#
#  $Id$
#
#  Running the TPC benchmark
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

#

rm -f *.output* core* *.log *.trx

# TPC C Test Script
#
TPCC=${TPCC-tpcc}
DB1=${DB1-wi1.db}
DB2=${DB2-wi2.db}
SEGSIZE=${SEGSIZE-25000}
NUM_RUNS=${NUM_RUNS-200}
PORT=${PORT-1111}

LOGFILE=tpc_run.output
export LOGFILE

#
#  Rest testsuite functions
#
. ../suite/test_fn.sh

gen_wicfg(){
  case $SERVER in
      [Mm]2*)
    cat > wi.cfg <<-END_WICFG
	#
	#  TPCC benchmark
	#
	database_file: wi.db
	log_file: wi.log
	file_extend: 200
	number_of_buffers: 7000
	max_dirty_buffers: 4000
	max_checkpoint_remap: 3000
	autocheckpoint: 0
	case_mode: 1
	sql_optimizer: 1
	atomic_dive: 1
	null_bad_dtp: 0
	unremap_quota: 0
	prefix_in_result_col_names: 0
	no_mt_write: 0
	threads: 100
	db_name: pub
	replication_server: 1
	sql_optimizer: 1

	#replication_queue: 50000

	#segment $SEGSIZE pages 1 stripes
	#stripe $DB1
	#segment $SEGSIZE pages 1 stripes
	#stripe $DB2
END_WICFG
  ;;
  *virtuoso*)
      cat > virtuoso.ini <<-END_VIRTUOSO_INI
[Database]
DatabaseFile		= wi.db
TransactionFile		= wi.log
ErrorLogFile		= wi.err
ErrorLogLevel   	= 7
FileExtend      	= 200
Striping        	= 0
Syslog			= 0

[Parameters]
ServerPort         	= $PORT
ServerThreads      	= 100
CheckpointInterval 	= 0
NumberOfBuffers    	= 7000
MaxDirtyBuffers    	= 4000
MaxCheckpointRemap 	= 3000
UnremapQuota       	= 0
AtomicDive         	= 1
PrefixResultNames	= 0
CaseMode           	= 1
DisableMtWrite		= 0
MaxStaticCursorRows     = 5000
CheckpointAuditTrail    = 0
AllowOSCalls		= 0
SchedulerInterval      = 0
FreeTextBatchSize       = 100000
SQLOptimizer		= 1

[Replication]
ServerName	= tpcrun
END_VIRTUOSO_INI
;;
  esac
}


CHECK_LOG_INIT_S()
{
    passed=`grep "PASSED:" $LOGFILE | wc -l`
    failed=`grep "\*\*\*.*FAILED:" $LOGFILE | wc -l`
    aborted=`grep "\*\*\*.*ABORTED:" $LOGFILE | wc -l`

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
       cp $LOGFILE tpc_run_init_s.bad
    fi
}

CHECK_LOG_RUN_S()
{
    passed=`grep "PASSED:" $LOGFILE | wc -l`
    failed=`grep "\*\*\*.*FAILED:" $LOGFILE | wc -l`
    aborted=`grep "\*\*\*.*ABORTED:" $LOGFILE | wc -l`

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
       cp $LOGFILE tpc_run_s.bad
    fi
}

cleanup() {
    if [ -f "$CFGFILE" ]
    then
	rm -f `egrep "^stripe " $CFGFILE | sed -e 's/stripe //'`
    fi

    rm -f *.db *.log *.txt *.out core wi.err *.output *.bad *.lck virtuoso.tdb *.bp
    rm -f $CFGFILE $LOGFILE 
    ECHO "PASSED: cleaned up for server $SERVER"
}


initialize() {
    LOGFILE=tpc_run_init.output
    export LOGFILE

    BANNER "INITIALIZE TPC BENCHMARK DATABASE"

    STOP_SERVER
    START_SERVER $PORT 1000

    RUN $ISQL $PORT dba dba ../tpccddk.sql
    if test $STATUS -ne 0
    then
       LOG "***ABORTED: Unable to load dictionary"
    else
       LOG "PASSED: loading dictionary"
    fi

    RUN $ISQL $PORT dba dba ../tpcc.sql
    if test $STATUS -ne 0
    then
       LOG "***ABORTED: Unable to load stored procedures"
    else
       LOG "PASSED: loading stored procedures"
    fi

    RUN $TPCC $PORT dba dba i 1
    if test $STATUS -ne 0
    then
       LOG "***ABORTED: Unable to load data"
    else
       LOG "PASSED: loaded data"
    fi

    SHUTDOWN_SERVER

    CHECK_LOG_INIT_S

    BANNER "COMPLETED DATABASE INITIALIZATION"
}


run_tpcc() {
    LOGFILE=tpc_run.output
    export LOGFILE

    BANNER "STARTING TPC BENCHMARK DATABASE TEST"

#    STOP_SERVER
    START_SERVER $PORT 1000

    #
    #  Start manual checkpointing (XXX is this really necessary)
    #
    $ISQL $PORT ERRORS=STDOUT < tpc_cpts.sql > tpc_cpts.log &

    #
    #  Run a couple of benchmark sessions in the background
    #
    $TPCC $PORT dba dba r $NUM_RUNS &
    sleep 1
    $TPCC $PORT dba dba r $NUM_RUNS &
    sleep 1
    $TPCC $PORT dba dba r $NUM_RUNS &
    sleep 1
    $TPCC $PORT dba dba r $NUM_RUNS &
    sleep 1
    $TPCC $PORT dba dba r $NUM_RUNS &
    sleep 1
    $TPCC $PORT dba dba r $NUM_RUNS &
    sleep 1
    $TPCC $PORT dba dba r $NUM_RUNS &
    sleep 1

    $TPCC $PORT dba dba r $NUM_RUNS &
    sleep 1
    $TPCC $PORT dba dba r $NUM_RUNS &
    sleep 1
    $TPCC $PORT dba dba r $NUM_RUNS &
    sleep 1
    $TPCC $PORT dba dba r $NUM_RUNS &
    sleep 1
    $TPCC $PORT dba dba r $NUM_RUNS &
    sleep 1
    $TPCC $PORT dba dba r $NUM_RUNS &
    sleep 1
    $TPCC $PORT dba dba r $NUM_RUNS &
    sleep 1
    $TPCC $PORT dba dba r $NUM_RUNS &
    sleep 1


    #
    #  Run one session in the foreground
    #
    RUN $TPCC $PORT dba dba r $NUM_RUNS
    if test $STATUS -ne 0
    then
       LOG "***ABORTED: Unable to run tpcc benchmark"
    else
       LOG "PASSED: running tpcc benchmark"
    fi

    #
    #  Wait other clients to finish
    #
    ncli=1
    while [ "$ncli" -gt "0" ]
    do
	sleep 10
        ncli=`ps -e | grep -w $TPCC | grep -v grep | wc -l`
    done

    kill_pid=`ps | grep -w $ISQL | grep -v grep | sed -e 's/^[ ]*[^0-9]//g' | cut -f 1 -d ' '`
    echo "The $ISQL pid ($kill_pid) will be killed."
    kill -9 $kill_pid

    #
    #  Read through all database pages with a backup to /dev/null
    #
    RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF  < tpc_back.sql
    if test $STATUS -ne 0
    then
       LOG "***ABORTED: Unable to run backup"
    else
       LOG "PASSED: backup and test database"
    fi

    SHUTDOWN_SERVER
    rm -f *.db *.trx
    RUN $SERVER $FOREGROUND_OPTION $OBACKUP_REP_OPTION "tpcc-" 
    START_SERVER $PORT 1000
    RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF  < tpc_back.sql
    if test $STATUS -ne 0
    then
       LOG "***ABORTED: Unable to check database after restore from inc backup"
    else
       LOG "PASSED: backup and test database after recov from inc backup"
    fi
    SHUTDOWN_SERVER

    CHECK_LOG_RUN_S

    BANNER "COMPLETED TPC BENCHMARK DATABASE TEST"
}


#
#  MAIN
#
STOP_SERVER
case $1 in
  clean)
  	cleanup
	exit 0
	;;

  init)
	if [ ! -f $CFGFILE ]
	then
	   gen_wicfg
	   initialize
	   exit 0;
	else
	   echo "Initialization already complete."
	   echo "If you want to start a clean run please do:"
	   echo ""
	   echo "    $0 clean"
	   echo "    $0 init"
	   echo ""
	   exit 1
	fi
	;;

  run)
 	run_tpcc
	;;
  *)
  	echo "Usage: tpcrun.sh { clean | init | run }"
	exit 1
esac

#
#  Check if the tests logged any failures
#
RUN egrep '"\*\*\*FAILED|\*\*\*ABORTED"' *.output
if test $STATUS -eq 0
then
    ECHO ""
    LINE
    ECHO "=  WARNING: Some tests failed. See *.output in this directory" `pwd`
    LINE
    rm -f audit.txt
    exit 3;
else
    ECHO ""
    LINE
    ECHO "=  TPCC TESTS PASSED."
    ECHO "="
    ECHO "=  See audit.txt and " *.output
    ECHO "=  in the directory" `pwd`;
    LINE

    #
    #  Audit.txt contains the build information
    #
    echo "Virtuoso tpcc check passed " > audit.txt
    date >> audit.txt
    uname -a >> audit.txt
fi

ECHO ""
LINE
ECHO "=  To see what is left in the database, start $SERVER in the same "
ECHO "=  directory, and connect to it with isql"
LINE

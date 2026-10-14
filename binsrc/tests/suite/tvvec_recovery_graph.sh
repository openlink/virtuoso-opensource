#!/bin/sh
#
#  tvvec_recovery_graph.sh
#
#  Driver asserting that a native vector index's HNSW graph survives recovery
#  -- both a logical restore and a crash roll-forward -- without an operator
#  having to run __VEC_INDEX_REBUILD by hand.
#
#  The graph lives in DPF_VEC pages that reach disk only through
#  itc_delta_this_buffer (), i.e. the checkpoint dirty set (vvec.c:1173).
#  vvec.c has no log_* call site anywhere, so nothing about the graph is in
#  the transaction log; and walk_db () skips vector trees outright
#  (recovery.c:227), so nothing about the graph is in a logical dump either.
#  The base table and the hidden embeddings table are ordinary logged tables
#  and do come back.  The result is an index pointing at data that moved on
#  without it, and every search raising:
#
#    VEC80: vector index ... is inconsistent with its stored embeddings
#
#  which is the epoch machinery correctly reporting a graph that recovery
#  never restored.
#
#  Two existing drivers assert the CURRENT behaviour as if it were the
#  contract: tvvec_backup.sh asserts only that a rebuild can put the index
#  back together after a +backup-dump replay, and
#  tvvec_crash_recovery_reopen.sql asserts consistent = 0 / needs_rebuild
#  after a crash.  This driver asserts what the engine has to do instead.  It
#  is expected to FAIL until the LOG_VEC_PAGE work lands; see
#  lace2/plans/vvec-recovery-page-logging/plan.md.
#
#  Sequence:
#    1. build the fixture, checkpoint, assert the index answers
#    2. stop cleanly; +backup-dump; remove the database; replay the dump;
#       restart and assert the index answers WITH NO REBUILD
#    3. rebuild + checkpoint, insert four more rows and embed them, so the
#       graph has mutations that exist only after the last checkpoint
#    4. stop uncleanly with raw_exit (); restart and assert the index answers
#       WITH NO REBUILD and that the four post-checkpoint rows are in it
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2026 OpenLink Software
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

LOGFILE=`pwd`/tvvec_recovery_graph.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

case $SERVER in
  *virtuoso*)
	  NO_CP_OPT=+no-checkpoint
	  RESTORE_DUMP_OPTION=+restore-crash-dump
	  ;;
  *)
	  RESTORE_DUMP_OPTION=-R
	  ;;
esac

rm -f $LOGFILE
rm -f vrg2_

BANNER "STARTED vector index recovery graph test (tvvec_recovery_graph.sh)"

#  SHUTDOWN_SERVER only asks; the lock file is what says the process is gone,
#  and every step below reuses the same database directory.
WAIT_FOR_STOP()
{
    n=0
    while test -f "$LOCKFILE" -a $n -lt 60
    do
	sleep 2
	n=`expr $n + 1`
    done
    if test -f "$LOCKFILE"
    then
	LOG "***FAILED: server still holding $LOCKFILE after 120s"
    fi
}

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

START_SERVER $PORT 1000

#
#  1. Fixture: table, rows, vector index, checkpoint, and the baseline
#     assertions that the index answers at all.
#
LOG + run tvvec_recovery_graph.sql
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_recovery_graph.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_recovery_graph.sql"
    exit 3
fi

SHUTDOWN_SERVER
WAIT_FOR_STOP

#
#  2. Logical dump and restore.  The dump goes into the transaction log, so
#     the database file is removed and the log is rolled forward into a fresh
#     one.
#
LOG + $SERVER $FOREGROUND_OPTION $BACKUP_DUMP_OPTION
RUN $SERVER $FOREGROUND_OPTION $BACKUP_DUMP_OPTION
DUMP_STATUS=$STATUS
if test $DUMP_STATUS -eq 0
then
    LOG "PASSED: +backup-dump of a database with a vector index exited 0"
else
    LOG "***FAILED: +backup-dump exited $DUMP_STATUS (139 = SIGSEGV)"
fi

if test $DUMP_STATUS -eq 0
then
    rm -f $DBFILE virtuoso.tdb virtuoso.pxa virtuoso-temp.db

    LOG + $SERVER $FOREGROUND_OPTION $RESTORE_DUMP_OPTION
    RUN $SERVER $FOREGROUND_OPTION $RESTORE_DUMP_OPTION
    if test $STATUS -eq 0
    then
	LOG "PASSED: replay of the +backup-dump log exited 0"
    else
	LOG "***FAILED: replay of the +backup-dump log exited $STATUS"
    fi

    START_SERVER $PORT 1000 $NO_CP_OPT

    LOG + run tvvec_recovery_graph_restore.sql "(after +backup-dump replay)"
    RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_recovery_graph_restore.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
    if test $STATUS -ne 0
    then
	LOG "***FAILED: tvvec_recovery_graph_restore.sql after +backup-dump replay"
    fi
else
    LOG "***FAILED: skipping the restore assertions, the dump did not complete"
    START_SERVER $PORT 1000 $NO_CP_OPT
fi

#
#  3. Post-checkpoint graph mutations, ready for the crash.
#
LOG + run tvvec_recovery_graph_crash.sql
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_recovery_graph_crash.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_recovery_graph_crash.sql"
    exit 3
fi

#
#  4. Unclean stop.  raw_exit () does not checkpoint, so the graph on disk is
#     as of step 3's checkpoint while the log carries the rows and embeddings
#     inserted after it.
#
LOG + stopping the server uncleanly with raw_exit -- no checkpoint
STOP_SERVER
sleep 5

LOG + restarting and rolling the log forward
START_SERVER $PORT 1000

LOG + run tvvec_recovery_graph_reopen.sql
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_recovery_graph_reopen.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_recovery_graph_reopen.sql"
    exit 3
fi

SHUTDOWN_SERVER
WAIT_FOR_STOP

CHECK_LOG

BANNER "COMPLETED vector index recovery graph test (tvvec_recovery_graph.sh)"

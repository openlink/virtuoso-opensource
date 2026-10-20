#!/bin/sh
#
#  tvvec_crash_recovery.sh
#
#  Vector-index durability test driver.
#
#  This test is two-phase because the condition it checks -- an HNSW graph left
#  behind by an unclean shutdown -- cannot be produced inside one server
#  lifetime.  The sequence is:
#
#    1. run tvvec_crash_recovery.sql, which exercises detection, the read
#       guard, rebuild and rollback undo, then checkpoints and commits three
#       further rows WITHOUT checkpointing;
#    2. stop the server uncleanly with raw_exit(), so those graph pages never
#       reach disk while the log keeps the embedding rows;
#    3. restart, and run tvvec_crash_recovery_reopen.sql, which asserts the
#       divergence is detected, that searches are refused rather than answered
#       from a half-populated graph, and that a rebuild restores the index.
#
#  STOP_SERVER uses raw_exit(), which exits without checkpointing -- that is
#  what makes this a real crash test rather than a simulated one.
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

LOGFILE=`pwd`/tvvec_crash_recovery.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector index crash recovery / durability test"

#  Generate this run's virtuoso.ini.  The suite-level copy is produced only by
#  testall.sh's prologue and is deleted by clean.sh (so `make clean` removes it),
#  while testlib.sh's RUN_TEST copies it into every test directory -- which means
#  `make test T=<this>` after a clean would otherwise start with no config and
#  hang in START_SERVER waiting for a server that can never come up.  tvvec.sh and
#  tvvec_onnx_lifecycle.sh already do this; the rest of the vvec drivers did not.
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

#
#  Phase 1: exercise everything testable in one server lifetime, then leave the
#  index with committed-but-uncheckpointed graph mutations.
#
START_SERVER $PORT 1000

LOG + phase 1: detection, read guard, rebuild, rollback undo
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_crash_recovery.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_crash_recovery.sql"
    exit 3
fi

#
#  Phase 2: unclean stop.  raw_exit() does not checkpoint, so every graph
#  mutation since the checkpoint in phase 1 is lost while the transaction log
#  retains the embedding rows.  That asymmetry is the whole point of the test.
#
LOG + stopping the server uncleanly with raw_exit -- no checkpoint
STOP_SERVER
sleep 5

LOG + restarting: the log replays the rows, the graph stays at the checkpoint
START_SERVER $PORT 1000

LOG + phase 2: assert the divergence is caught and repairable
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_crash_recovery_reopen.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_crash_recovery_reopen.sql"
    exit 3
fi

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED vector index crash recovery / durability test"

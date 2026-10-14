#!/bin/sh
#
#  tvvec_chunked_replay_crash.sh
#
#  Deterministic crash IN THE MIDDLE of a chunked replay rebuild.
#
#  Unlike tvvec_chunked_replay.sh (which crashes after a rebuild, via a
#  post-checkpoint mutation), this drives the crash inside the rebuild loop using
#  the VVEC_TEST_CRASH_AFTER_CHUNK fault hook in vvec_replay_rebuild_chunked.  The
#  hook is inert unless that environment variable is set, so it only fires here.
#
#    1. Start the server WITH VVEC_TEST_CRASH_AFTER_CHUNK=1.  Run
#       tvvec_chunked_replay_crash.sql: it fills a >4000-row index, checkpoints
#       the healthy pre-rebuild graph, then launches a replay rebuild.  After the
#       first chunk commits, the hook checkpoints the PARTIAL graph and exits
#       uncleanly -- so isql loses the server mid-statement (expected).
#    2. Restart WITHOUT the env var.  The durable graph is the partial one; its
#       epoch is ahead of the never-synced catalog epoch.
#    3. tvvec_chunked_replay_crash_reopen.sql asserts the index reconciles
#       needs_rebuild, refuses searches (VEC80), keeps all embedding rows, and is
#       repaired by a rebuild.  This is the case the vvec_graph_reset epoch bump
#       exists to make safe: a checkpointed half-built graph is never trusted.
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

LOGFILE=`pwd`/tvvec_chunked_replay_crash.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector index mid-chunk crash test"

#  Generate this run's virtuoso.ini.  The suite-level copy is produced only by
#  testall.sh's prologue and is deleted by clean.sh (so `make clean` removes it),
#  while testlib.sh's RUN_TEST copies it into every test directory -- which means
#  `make test T=<this>` after a clean would otherwise start with no config and
#  hang in START_SERVER waiting for a server that can never come up.  tvvec.sh and
#  tvvec_onnx_lifecycle.sh already do this; the rest of the vvec drivers did not.
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

#
#  Phase 1: server armed with the fault hook.  The rebuild crashes it mid-flight,
#  so phase-1 isql is EXPECTED to abort with a lost connection -- we do not treat
#  a non-zero status as a test failure here.
#
VVEC_TEST_CRASH_AFTER_CHUNK=1
export VVEC_TEST_CRASH_AFTER_CHUNK
LOG + phase 1: build, checkpoint, launch rebuild that self-crashes after chunk 1
START_SERVER $PORT 1000
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_chunked_replay_crash.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
LOG "+ phase 1 isql returned status $STATUS (a lost connection here is expected)"

#
#  The fault hook already exited the server uncleanly.  Make sure nothing is left
#  and clear the fault env so the restart is a normal server.
#
STOP_SERVER 2>/dev/null
sleep 5
unset VVEC_TEST_CRASH_AFTER_CHUNK

LOG + restarting WITHOUT the fault hook
START_SERVER $PORT 1000

LOG + phase 2: assert the mid-rebuild crash is caught and repairable
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_chunked_replay_crash_reopen.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_chunked_replay_crash_reopen.sql"
    exit 3
fi

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED vector index mid-chunk crash test"

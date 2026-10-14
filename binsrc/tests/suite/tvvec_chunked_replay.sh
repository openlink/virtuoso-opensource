#!/bin/sh
#
#  tvvec_chunked_replay.sh
#
#  Durability driver for the chunked-commit replay rebuild
#  (vvec_replay_rebuild_chunked).  Replay now commits every
#  VVEC_REPLAY_CHUNK_SIZE (4000) inserts instead of running the whole rebuild in
#  one transaction, so this test builds an index whose rebuild crosses a chunk
#  boundary and proves the result is durable and crash-safe.
#
#  Two-phase, like tvvec_crash_recovery.sh, because a graph left behind by an
#  unclean shutdown cannot be produced in one server lifetime:
#
#    1. tvvec_chunked_replay.sql builds a >4000-row index via chunked replay
#       (TCR_CLEAN_IDX), asserts the rebuild covers every row and advances the
#       graph epoch by rebuilt+1 (the vvec_graph_reset bump that keeps an
#       emptied/partial graph from reconciling as healthy), checkpoints, then
#       commits rows to a second index (TCR_ARMED_IDX) WITHOUT checkpointing;
#    2. stop uncleanly with raw_exit(), so the post-checkpoint graph pages never
#       reach disk while the log keeps the embedding rows;
#    3. restart, and tvvec_chunked_replay_reopen.sql asserts the checkpointed
#       chunked-replay graph survived (TCR_CLEAN_IDX consistent), and that the
#       post-checkpoint mutations survived too (TCR_ARMED_IDX consistent, every
#       armed node back) because LOG_VEC_PAGE replays their pages with the rows.
#
#  Self-contained: the in-core 'test_embedding' model, indexes on empty tables
#  filled with __VEC_INDEX_INSERT_TEST_EMBEDDING -- no ONNX plugin, no SPARQL
#  backfill bootstrap.
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

LOGFILE=`pwd`/tvvec_chunked_replay.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector index chunked replay rebuild durability test"

#  Generate this run's virtuoso.ini.  The suite-level copy is produced only by
#  testall.sh's prologue and is deleted by clean.sh (so `make clean` removes it),
#  while testlib.sh's RUN_TEST copies it into every test directory -- which means
#  `make test T=<this>` after a clean would otherwise start with no config and
#  hang in START_SERVER waiting for a server that can never come up.  tvvec.sh and
#  tvvec_onnx_lifecycle.sh already do this; the rest of the vvec drivers did not.
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

#
#  Phase 1: build via chunked replay, check the rebuild + epoch bump, then leave
#  an index with committed-but-uncheckpointed graph mutations.
#
START_SERVER $PORT 1000

LOG + phase 1: chunked replay rebuild, epoch bump, mutate past the checkpoint
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_chunked_replay.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_chunked_replay.sql"
    exit 3
fi

#
#  Phase 2: unclean stop.  raw_exit() does not checkpoint, so the post-checkpoint
#  graph mutations are lost while the log retains the embedding rows.
#
LOG + stopping the server uncleanly with raw_exit -- no checkpoint
STOP_SERVER
sleep 5

LOG + restarting: the log replays the rows, the graph stays at the checkpoint
START_SERVER $PORT 1000

LOG + phase 2: assert the checkpointed graph survived and the divergence is caught
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_chunked_replay_reopen.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_chunked_replay_reopen.sql"
    exit 3
fi

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED vector index chunked replay rebuild durability test"

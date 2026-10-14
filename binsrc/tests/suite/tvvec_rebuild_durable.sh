#!/bin/sh
#
#  tvvec_rebuild_durable.sh
#
#  Vector-index REBUILD durability test driver.
#
#  Unlike tvvec_crash_recovery (which arms an unclean kill), this test verifies
#  the ordinary, expected case: a __VEC_INDEX_REBUILD that is checkpointed and
#  then followed by a CLEAN shutdown must survive a restart with its graph
#  intact.  The sequence is:
#
#    1. run tvvec_rebuild_durable.sql, which builds two indexes, rebuilds one,
#       checkpoints, and records the post-rebuild epochs;
#    2. stop the server CLEANLY with shutdown (SHUTDOWN_SERVER), which
#       checkpoints -- so every rebuilt graph page reaches disk;
#    3. restart, and run tvvec_rebuild_durable_reopen.sql, which asserts the
#       rebuilt graph is still consistent (graph_epoch == data_epoch), answers
#       every row, and that the never-rebuilt control is equally intact.
#
#  The distinction from tvvec_crash_recovery matters: that test's reopen only
#  asserts graph_epoch < data_epoch, which holds regardless of whether the
#  rebuild's checkpoint persisted.  This test asserts the strict equality that
#  only a durably-checkpointed rebuild produces, so it is the one that would
#  catch a rebuild whose pages never reached the checkpoint.
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

LOGFILE=`pwd`/tvvec_rebuild_durable.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector index rebuild durability test"

#  Generate this run's virtuoso.ini.  The suite-level copy is produced only by
#  testall.sh's prologue and is deleted by clean.sh (so `make clean` removes it),
#  while testlib.sh's RUN_TEST copies it into every test directory -- which means
#  `make test T=<this>` after a clean would otherwise start with no config and
#  hang in START_SERVER waiting for a server that can never come up.  tvvec.sh and
#  tvvec_onnx_lifecycle.sh already do this; the rest of the vvec drivers did not.
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

#
#  Phase 1: build two indexes, rebuild one, checkpoint, record expectations.
#
START_SERVER $PORT 1000

LOG + phase 1: build, rebuild, checkpoint
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_rebuild_durable.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_rebuild_durable.sql"
    exit 3
fi

#
#  Phase 2: clean stop -- shutdown checkpoints, so the rebuilt graph is durable.
#
LOG + stopping the server cleanly with shutdown -- checkpoints on the way out
SHUTDOWN_SERVER
sleep 5

LOG + restarting: the rebuilt graph must come back in full
START_SERVER $PORT 1000

LOG + phase 2: assert the rebuilt graph is durable and consistent
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_rebuild_durable_reopen.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_rebuild_durable_reopen.sql"
    exit 3
fi

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED vector index rebuild durability test"

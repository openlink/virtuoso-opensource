#!/bin/sh
#
#  tvvec_concurrency.sh
#
#  Vector-index concurrent-writer safety test driver (prompt 06).
#
#  Runs tvvec_concurrency.sql, which uses async_queue / aq_request to drive
#  several background workers inserting into ONE shared HNSW index at the same
#  time, then asserts the merged graph is consistent (node count == stored
#  embeddings) and still has high recall -- the structural check that catches a
#  concurrent build which interleaved neighbour-list rewrites.  A second phase
#  searches an index while it is being built concurrently and asserts searches
#  never crash and never return a key with no committed hidden-table row.
#
#  Like the durability driver, this is a separate single-phase driver rather than
#  part of tvvec.sh: the suite is self-contained and uses the in-core
#  'test_embedding' model, so it needs neither the ONNX plugin nor python and can
#  run unconditionally on a default build.  It needs no restart, so it is one
#  ISQL invocation against a single server.
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

LOGFILE=`pwd`/tvvec_concurrency.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector index concurrent-writer safety test"

#  Generate this run's virtuoso.ini.  The suite-level copy is produced only by
#  testall.sh's prologue and is deleted by clean.sh (so `make clean` removes it),
#  while testlib.sh's RUN_TEST copies it into every test directory -- which means
#  `make test T=<this>` after a clean would otherwise start with no config and
#  hang in START_SERVER waiting for a server that can never come up.  tvvec.sh and
#  tvvec_onnx_lifecycle.sh already do this; the rest of the vvec drivers did not.
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

#  Vector indexes are single-server only (see prompt 07); nothing to do on a
#  cluster build.
if [ "$CURRENT_VIRTUOSO_CAPACITY" != "single" ]
then
    LOG "SKIPPED: vector index is single-server only"
    BANNER "COMPLETED vector index concurrent-writer test (skipped: not single-server)"
    exit 0
fi

START_SERVER $PORT 1000

LOG + concurrent-writer safety and concurrent-reader safety
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_concurrency.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_concurrency.sql did not run to completion"
    SHUTDOWN_SERVER
    exit 3
fi

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED vector index concurrent-writer safety test"

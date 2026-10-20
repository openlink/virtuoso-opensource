#!/bin/sh
#
#  tvvec_passthrough_column.sh
#
#  Driver for the precomputed-vector ("bring your own vectors") passthrough
#  column mode: CREATE VECTOR INDEX ... WITH (source_kind = 'vector').
#
#  Two phases, mirroring tvvec_rebuild_durable:
#    1. run tvvec_passthrough_column.sql (gate, create, DML upsert, by-vector
#       query, VEC88 text rejection, VEC82 guard, backfill, bad-row policy,
#       column-type check, SPARQL SET_OPTIONS, fast rebuild + checkpoint);
#    2. stop the server CLEANLY (SHUTDOWN_SERVER checkpoints), restart, and run
#       tvvec_passthrough_column_reopen.sql to assert the passthrough graph is
#       durable and still answers by-vector queries / rejects text queries.
#
#  Self-contained: the passthrough path needs no ONNX plugin, and the SPARQL
#  coverage exercises only VEC_INDEX_SET_OPTIONS (no model / backfill bootstrap).
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

LOGFILE=`pwd`/tvvec_passthrough_column.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector index passthrough-column test"

#  Generate this run's virtuoso.ini.  The suite-level copy is produced only by
#  testall.sh's prologue and is deleted by clean.sh (so `make clean` removes it),
#  while testlib.sh's RUN_TEST copies it into every test directory -- which means
#  `make test T=<this>` after a clean would otherwise start with no config and
#  hang in START_SERVER waiting for a server that can never come up.  tvvec.sh and
#  tvvec_onnx_lifecycle.sh already do this; the rest of the vvec drivers did not.
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

#
#  Phase 1: gate, create, upsert, query, guard, backfill, bad-row, rebuild.
#
START_SERVER $PORT 1000

LOG + phase 1: passthrough create / upsert / query / rebuild
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_passthrough_column.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_passthrough_column.sql did not run to completion"
    SHUTDOWN_SERVER
    exit 3
fi

#
#  Phase 2: clean stop -- shutdown checkpoints, so the passthrough graph is durable.
#
LOG + stopping the server cleanly with shutdown
SHUTDOWN_SERVER
sleep 5

LOG + restarting: the passthrough graph must come back in full
START_SERVER $PORT 1000

LOG + phase 2: assert the passthrough graph is durable
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_passthrough_column_reopen.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_passthrough_column_reopen.sql did not run to completion"
    SHUTDOWN_SERVER
    exit 3
fi

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED vector index passthrough-column test"

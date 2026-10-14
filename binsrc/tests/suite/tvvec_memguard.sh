#!/bin/sh
#
#  tvvec_memguard.sh
#
#  Driver for the fast-rebuild memory-guard test.
#
#  Sets VVEC_FAST_REBUILD_MAX_BYTES=1000 before server start so the guard's
#  estimated footprint (~2.2 MB for 10001 dim-8 vectors) exceeds the cap.  Then
#  populates the index with 10001 vectors (above the AUTO_MIN threshold) by
#  piping generated select statements, and runs tvvec_memguard.sql which
#  rebuilds and asserts.  Finally greps the server log for:
#    - auto-rebuild falling back to replay (guard fired)
#    - explicit fast rebuild proceeding with a warning
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

LOGFILE=`pwd`/tvvec_memguard.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector index fast-rebuild memory guard test"

#  Generate this run's virtuoso.ini.  The suite-level copy is produced only by
#  testall.sh's prologue and is deleted by clean.sh (so `make clean` removes it),
#  while testlib.sh's RUN_TEST copies it into every test directory -- which means
#  `make test T=<this>` after a clean would otherwise start with no config and
#  hang in START_SERVER waiting for a server that can never come up.  tvvec.sh and
#  tvvec_onnx_lifecycle.sh already do this; the rest of the vvec drivers did not.
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

# Set the memory cap to 1 KB so the guard fires for any non-trivial index.
VVEC_FAST_REBUILD_MAX_BYTES=1000
export VVEC_FAST_REBUILD_MAX_BYTES

START_SERVER $PORT 1000

# Phase 1: register the model and create the index (first part of the SQL file,
# up to the index creation).  We split the SQL so we can populate between setup
# and rebuild.
LOG + setup: register model and create index
RUN $ISQL $DSN dba dba ERRORS=STDOUT PROMPT=OFF VERBOSE=OFF <<'EOSQL'
select DB.DBA.ONNX_REGISTRY_INIT ();
delete from DB.DBA.ONNX_MODELS where model_name = 'vmg-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
  values ('vmg-8', 'memguard test model', 'internal:vmg-8',
          'test_embedding', 'embedding', '1,8', now (), now ());
create table DB.DBA.VMG_T (id integer not null primary key, content varchar);
CREATE VECTOR INDEX VMG_AUTOX ON DB.DBA.VMG_T (content) USING 'vmg-8'
  WITH (dimensions=8, distance_metric='cosine', hnsw_m=8, ef_construction=24, rebuild='auto');
EOSQL
if test $STATUS -ne 0
then
    LOG "***ABORTED: setup phase"
    exit 3
fi

# Phase 2: populate 10001 vectors by piping generated select statements.
# 10001 is above VVEC_REBUILD_AUTO_MIN (10000) so 'auto' would choose fast.
LOG + populate 10001 test embeddings
i=1
while [ $i -le 10001 ]; do
  echo "select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VMG_AUTOX', $i, $i, $i);"
  i=`expr $i + 1`
done | $ISQL $DSN dba dba ERRORS=STDOUT PROMPT=OFF VERBOSE=OFF > /dev/null 2>&1
LOG "PASSED: populated 10001 vectors"

# Phase 3: rebuild and assert (the rest of tvvec_memguard.sql).
LOG + run rebuild and assertions
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_memguard.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_memguard.sql"
    exit 3
fi

# Assert the guard fired for auto and warned for explicit fast.
SRVLOG="$SRVMSGLOGFILE"
if test ! -f "$SRVLOG"; then SRVLOG=`ls -1 wi.err virtuoso*.log 2>/dev/null | head -1`; fi

LOG + assert memory guard messages from the server log \($SRVLOG\)

if grep -E "VMG_AUTOX.*falling back to replay.*exceeds cap" "$SRVLOG" >/dev/null 2>&1
then
    LOG "PASSED: auto-rebuild fell back to replay (guard fired)"
else
    LOG "***FAILED: auto-rebuild did not log fallback-to-replay"
fi

if grep -E "VMG_AUTOX.*WARNING.*explicit fast rebuild.*exceeds recommended cap" "$SRVLOG" >/dev/null 2>&1
then
    LOG "PASSED: explicit fast rebuild logged OOM warning"
else
    LOG "***FAILED: explicit fast rebuild did not log warning"
fi

if grep -E "VMG_AUTOX rebuilt: .* via incremental replay" "$SRVLOG" >/dev/null 2>&1
then
    LOG "PASSED: auto-rebuild used replay"
else
    LOG "***FAILED: auto-rebuild did not use replay"
fi

if grep -E "VMG_AUTOX rebuilt: .* via fast bulk build" "$SRVLOG" >/dev/null 2>&1
then
    LOG "PASSED: explicit fast rebuild used fast"
else
    LOG "***FAILED: explicit fast rebuild did not use fast"
fi

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED vector index fast-rebuild memory guard test"

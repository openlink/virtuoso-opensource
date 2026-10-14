#!/bin/sh
#
#  tvvec_rebuild_option.sh
#
#  Driver for the vector-index rebuild-method option test.
#
#  Runs tvvec_rebuild_option.sql (which asserts everything observable in SQL:
#  option accepted and stored on both DDL surfaces, invalid values rejected with
#  VEC81, plain rebuild honors the stored default, per-call argument overrides it,
#  rebuilt index still answers), then reads the server message log to assert which
#  implementation actually ran for each rebuild -- the one fact SQL cannot see.
#
#  __VEC_INDEX_REBUILD logs one line per rebuild naming the implementation
#  ("via fast bulk build" / "via incremental replay"); this driver greps for the
#  expected line per index.
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

LOGFILE=`pwd`/tvvec_rebuild_option.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector index rebuild-method option test"

#  Generate this run's virtuoso.ini.  The suite-level copy is produced only by
#  testall.sh's prologue and is deleted by clean.sh (so `make clean` removes it),
#  while testlib.sh's RUN_TEST copies it into every test directory -- which means
#  `make test T=<this>` after a clean would otherwise start with no config and
#  hang in START_SERVER waiting for a server that can never come up.  tvvec.sh and
#  tvvec_onnx_lifecycle.sh already do this; the rest of the vvec drivers did not.
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

START_SERVER $PORT 1000

LOG + run tvvec_rebuild_option.sql
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_rebuild_option.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_rebuild_option.sql"
    exit 3
fi

#
#  Assert the implementation each rebuild actually used, from the server log.
#  SRVMSGLOGFILE defaults to wi.err; fall back to any virtuoso*.log in cwd.
#
SRVLOG="$SRVMSGLOGFILE"
if test ! -f "$SRVLOG"; then SRVLOG=`ls -1 wi.err virtuoso*.log 2>/dev/null | head -1`; fi

CHECK_METHOD()
{
    idx="$1"; want="$2"; label="$3"
    if grep -E "Vector index $idx rebuilt: .* via $want" "$SRVLOG" >/dev/null 2>&1
    then
        LOG "PASSED: $label ($idx via $want)"
    else
        LOG "***FAILED: $label ($idx did not log 'via $want')"
    fi
}

LOG + assert rebuild implementation from the server log \($SRVLOG\)
CHECK_METHOD VRO_FASTX "fast bulk build"   "stored default fast -> fast"
CHECK_METHOD VRO_REPX  "incremental replay" "stored default replay -> replay"
CHECK_METHOD VRO_DEFX  "incremental replay" "no option -> auto default (3 rows < AUTO_MIN -> replay)"
CHECK_METHOD VRO_AUTOX "incremental replay" "auto below threshold -> replay"
CHECK_METHOD VRO_REPX  "fast bulk build"    "override replay-index with fast"
CHECK_METHOD VRO_FASTX "incremental replay" "override fast-index with replay"

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED vector index rebuild-method option test"

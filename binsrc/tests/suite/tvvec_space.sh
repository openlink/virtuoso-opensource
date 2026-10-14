#!/bin/sh
#
#  tvvec_space.sh
#
#  Driver for the vector-index page accounting test.
#
#  Two things are asserted, independently so that a failure in one does not
#  hide the other:
#
#    * SYS_INDEX_SPACE_STATS reports the HNSW graph's pages while the index
#      exists.  They are DPF_VEC pages and used to match neither arm of the
#      collector's DP_FLAGS dispatch, so the graph -- the largest of the three
#      objects a vector index owns -- was read off disk and then skipped.
#    * dropping the index gives those pages back.  vvec_key_dropped () freed
#      the root and nothing else, and nothing else ever reclaimed the rest.
#
#  The database has to be a fresh one, which is what this driver's own working
#  directory gives it: pages leaked before the fix are never handed back, so a
#  reused database has no baseline to return to.
#
#  No ONNX dependency.  The fixture registers the in-core 'test_embedding'
#  model, as tvvec_crash_recovery.sql does, so this runs on a default build.
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

LOGFILE=`pwd`/tvvec_space.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector index space accounting test (tvvec_space.sh)"

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

START_SERVER $PORT 1000

LOG + run tvvec_space.sql
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_space.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_space.sql"
    exit 3
fi

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED vector index space accounting test (tvvec_space.sh)"

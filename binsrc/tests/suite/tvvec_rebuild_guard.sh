#!/bin/sh
#
#  tvvec_rebuild_guard.sh
#
#  A logged fast rebuild that cannot fit under TransactionAfterImageLimit is
#  refused before it resets the graph, and the fast builder's memory cap and
#  thread count follow the registry at runtime.  See tvvec_rebuild_guard.sql.
#
#  The rebuild thread count appears only in the server log, so it is checked
#  here after the SQL phase.
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

LOGFILE=`pwd`/tvvec_rebuild_guard.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector index fast-rebuild guard test (tvvec_rebuild_guard.sh)"

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

START_SERVER $PORT 1000

LOG + run tvvec_rebuild_guard.sql
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_rebuild_guard.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_rebuild_guard.sql"
    exit 3
fi

#  The SQL ran two rebuilds for this: one with __vec_rebuild_threads = 3 and no
#  thread argument, then one with an explicit 5 -- a count no other rebuild in
#  the run uses.
three=`LC_ALL=C grep -a -c "TRG_IDX rebuilt: .* via fast bulk build, 3 thread(s)" virtuoso.log`
five=`LC_ALL=C grep -a -c "TRG_IDX rebuilt: .* via fast bulk build, 5 thread(s)" virtuoso.log`
if [ "$three" -ge 1 ]
then
    LOG "PASSED: __vec_rebuild_threads = 3 gave a 3-thread fast rebuild ($three)"
else
    LOG "***FAILED: __vec_rebuild_threads = 3 was ignored -- no 3-thread fast rebuild in the log"
fi
if [ "$five" -ge 1 ]
then
    LOG "PASSED: an explicit thread argument still wins over the registry ($five)"
else
    LOG "***FAILED: the explicit 5-thread rebuild is not in the log"
fi

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED vector index fast-rebuild guard test (tvvec_rebuild_guard.sh)"

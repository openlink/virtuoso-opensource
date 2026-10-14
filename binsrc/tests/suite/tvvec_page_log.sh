#!/bin/sh
#
#  tvvec_page_log.sh
#
#  A read must stay a read: running searches against a vector index must not
#  append anything to the transaction log.
#
#  LOG_VEC_PAGE gave the HNSW graph a WAL record, which is what makes the graph
#  survive a crash.  The hazard it introduces is on the other side: a DPF_VEC
#  page stays dirty from the write that touched it until the next checkpoint,
#  so a rule of the form "log this page if it is dirty" cannot tell a page THIS
#  transaction wrote from a page it merely read after someone else wrote it.
#  Under such a rule every search emits a full 8KB page image per graph page it
#  visits, log volume becomes proportional to reads rather than writes, and a
#  read-only transaction acquires log content it should never have had.
#
#  Method: build the index, dirty its pages without a checkpoint, warm up (so
#  that a one-shot epoch sync or health recheck is not charged to the result),
#  stat the log, run a batch of searches, stat it again.  The threshold is one
#  page image -- a build with the defect exceeds it on the first search, and a
#  correct build adds nothing at all.
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

LOGFILE=`pwd`/tvvec_page_log.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector index page logging test (tvvec_page_log.sh)"

#  One page image.  Not a tuned number: it is the smallest record the defect
#  can possibly produce, so anything at or above it is the defect and anything
#  below it cannot be.
PAGE_IMAGE_BYTES=8192

LOG_BYTES()
{
    if test -f "$DBLOGFILE"
    then
	wc -c < "$DBLOGFILE" | tr -d ' '
    else
	echo 0
    fi
}

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

START_SERVER $PORT 1000

LOG + run tvvec_page_log.sql
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_page_log.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_page_log.sql"
    exit 3
fi

BEFORE=`LOG_BYTES`
if test "$BEFORE" -eq 0
then
    LOG "***FAILED: transaction log $DBLOGFILE is empty or missing before the measured window"
fi

LOG + run tvvec_page_log_search.sql "(measured window)"
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_page_log_search.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_page_log_search.sql"
    exit 3
fi

AFTER=`LOG_BYTES`
GROWTH=`expr $AFTER - $BEFORE`

LOG "transaction log: before=$BEFORE after=$AFTER growth=$GROWTH bytes (limit $PAGE_IMAGE_BYTES)"

#  A shrinking log would mean a checkpoint ran and truncated it, which would
#  make the measurement meaningless rather than good news.
if test "$GROWTH" -lt 0
then
    LOG "***FAILED: the transaction log shrank during the measured window -- a checkpoint ran, the result is not meaningful"
else
    if test "$GROWTH" -lt "$PAGE_IMAGE_BYTES"
    then
	LOG "PASSED: searching a vector index added $GROWTH bytes to the transaction log"
    else
	LOG "***FAILED: searching a vector index added $GROWTH bytes to the transaction log, expected less than $PAGE_IMAGE_BYTES"
    fi
fi

#  The memory side, after the measured window so that its own writes cannot be
#  charged to the log measurement above.
LOG + run tvvec_page_log_memory.sql
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_page_log_memory.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_page_log_memory.sql"
    exit 3
fi

#  Last, because it adds rows: many sequential write transactions on one
#  connection, which is the path a transaction object is cleared and reused on.
LOG + run tvvec_page_log_reuse.sql
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_page_log_reuse.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_page_log_reuse.sql"
    exit 3
fi

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED vector index page logging test (tvvec_page_log.sh)"

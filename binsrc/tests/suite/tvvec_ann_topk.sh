#!/bin/sh
#
#  tvvec_ann_topk.sh
#
#  Driver for the ANN candidate-bound (top-k) test.
#
#  Runs tvvec_ann_topk.sql, which asserts that the leading ANN path asks the
#  index for as many candidates as the query actually needs -- k from the
#  enclosing TOP, or no leading ANN at all when the query gives no bound --
#  rather than the hardcoded 10 that silently truncated every X_SIMILAR
#  threshold query written without an explicit k argument.
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

LOGFILE=`pwd`/tvvec_ann_topk.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector ANN top-k bound test (tvvec_ann_topk.sh)"

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

START_SERVER $PORT 1000

LOG + run tvvec_ann_topk.sql
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_ann_topk.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_ann_topk.sql"
    exit 3
fi

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED vector ANN top-k bound test (tvvec_ann_topk.sh)"

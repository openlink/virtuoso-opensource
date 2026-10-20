#!/bin/sh
#
#  tvvec_rollback_undo.sh
#
#  A rolled-back transaction's graph changes are undone by the next write,
#  and roll forward after an unclean stop reproduces the graph without a
#  rebuild: that write logs the rolled-back nodes' pages again.  A crash between
#  the rollback and that write rebuilds the index instead.
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

LOGFILE=`pwd`/tvvec_rollback_undo.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector index rollback undo test (tvvec_rollback_undo.sh)"

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
START_SERVER $PORT 1000

RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_rollback_undo.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_rollback_undo.sql"
    exit 3
fi

LOG + stopping the server uncleanly with raw_exit -- no checkpoint
STOP_SERVER
sleep 5

LOG + restarting and rolling the log forward
START_SERVER $PORT 1000

RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_rollback_undo_reopen.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_rollback_undo_reopen.sql"
    exit 3
fi

RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_rollback_undo_crash.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_rollback_undo_crash.sql"
    exit 3
fi

LOG + stopping uncleanly right after a rollback, before any other graph write
STOP_SERVER
sleep 5

LOG + restarting and rolling the log forward
START_SERVER $PORT 1000

RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_rollback_undo_rebuilt.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_rollback_undo_rebuilt.sql"
    exit 3
fi

SHUTDOWN_SERVER
CHECK_LOG

BANNER "COMPLETED vector index rollback undo test (tvvec_rollback_undo.sh)"

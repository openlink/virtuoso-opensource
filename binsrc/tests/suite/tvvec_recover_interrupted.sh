#!/bin/sh
#
#  tvvec_recover_interrupted.sh
#
#  Vector index operations interrupted by a crash must be recovered at the next
#  start.  REFRESH, DROP and DRAIN commit SVI_STATE = 'refreshing' / 'dropping'
#  / 'draining' when they start and clear it when they end; an RDF_OBJ vector
#  index build does the same with RVI_STATE = 'building' / 'embedding'.  When
#  the server dies in between, the next start must put such an index in
#  'error', which REFRESH can retry -- not leave it busy for ever.  The state
#  is usually in the transaction log only, so the recovery has to run after
#  roll forward.  The sequence is:
#
#    1. run tvvec_recover_interrupted.sql: create the indexes, checkpoint, then
#       commit the in-flight states WITHOUT checkpointing;
#    2. stop the server uncleanly with raw_exit();
#    3. restart, and run tvvec_recover_interrupted_reopen.sql, which asserts
#       the states were recovered and that REFRESH works again.
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

LOGFILE=`pwd`/tvvec_recover_interrupted.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector index recovery of operations interrupted by a crash"

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
START_SERVER $PORT 1000

LOG + phase 1: indexes caught mid-operation, committed after the last checkpoint
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_recover_interrupted.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_recover_interrupted.sql"
    exit 3
fi

LOG + stopping the server uncleanly with raw_exit -- no checkpoint
STOP_SERVER
sleep 5

LOG + restarting: roll forward brings the in-flight states back
START_SERVER $PORT 1000

LOG + phase 2: the states were recovered and REFRESH works
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_recover_interrupted_reopen.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_recover_interrupted_reopen.sql"
    exit 3
fi

SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED vector index recovery of operations interrupted by a crash"

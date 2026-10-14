#!/bin/sh
#
#  tvvec_refresh_log_limit.sh
#
#  A logged vector index refresh keeps each of its transactions under
#  TransactionAfterImageLimit: a parallel wave larger than the limit, a serial
#  batch larger than the limit, and a bulk build whose fast builder would log
#  more than the limit all complete.  See tvvec_refresh_log_limit.sql.
#
#  That 'auto' chose the replay rebuild for the bulk build because of the log,
#  and not for another reason, shows only in the server log, so it is checked
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

LOGFILE=`pwd`/tvvec_refresh_log_limit.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector index refresh log-limit test (tvvec_refresh_log_limit.sh)"

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

START_SERVER $PORT 1000

LOG + run tvvec_refresh_log_limit.sql
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_refresh_log_limit.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_refresh_log_limit.sql"
    exit 3
fi

fallback=`LC_ALL=C grep -a -c "auto-rebuild falling back to replay -- a logged fast build" virtuoso.log`
if [ "$fallback" -ge 1 ]
then
    LOG "PASSED: the server log says why 'auto' chose the replay rebuild ($fallback)"
else
    LOG "***FAILED: no 'auto-rebuild falling back to replay -- a logged fast build' line in the server log"
fi

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED vector index refresh log-limit test (tvvec_refresh_log_limit.sh)"

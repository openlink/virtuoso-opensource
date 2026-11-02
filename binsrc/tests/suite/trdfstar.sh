#!/bin/sh
#
#  trdfstar.sh
#
#  $Id$
#
#  RDF 1.2 (RDF-star) triple term and reifier tests, run at CaseMode 2.
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
#

LOGFILE=trdfstar.output
export LOGFILE
#  The RDF 1.2 helper functions read DB.DBA.RDF_QUAD through quoted lower case
#  column names, which only resolve under CaseMode 2, so this driver pins it.
export CASE_MODE=2
. $VIRTUOSO_TEST/testlib.sh

BANNER "STARTED: RDF 1.2 triple term tests (trdfstar.sh)"

SHUTDOWN_SERVER

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
START_SERVER $PORT 1000

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/trdfstar.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: trdfstar.sql"
    exit 1
fi

SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED: RDF 1.2 triple term tests (trdfstar.sh)"

#!/bin/sh
#
#  inprocess.sh
#
#  $Id$
#
#  inprocess client tests
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2014 OpenLink Software
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

LOGFILE=inprocess.output
export LOGFILE
. ./test_fn.sh

BANNER "STARTED SERIES OF INPROCESS CLIENT TESTS (inprocess.sh)"

SHUTDOWN_SERVER
rm -f $DBLOGFILE
rm -f $DBFILE
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
START_SERVER $PORT 1000

RUN $INS $DSN 1000 100 dba dba usedt
if test $STATUS -ne 0
then
    LOG "***ABORTED: inprocess.sh: loading the base table"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u LOCALPORT=$PORT < inprocess.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: inprocess client tests -- inprocess.sql"
    exit 1
fi

SHUTDOWN_SERVER

CHECK_LOG
BANNER "COMPLETED SERIES OF INPROCESS CLIENT TESTS (inprocess.sh)"

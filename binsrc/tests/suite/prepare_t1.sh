#!/bin/sh
#
#  $Id: prepare_t1.sh,v 1.1.2.3 2013/01/02 16:14:51 source Exp $
#
#  SQL Optimizer tests
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2019 OpenLink Software
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

LOGFILE=prepare_t1.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

BANNER "STARTED T1"

LINE
LOG "Server startup in SQL optimizer mode"
LINE
STOP_SERVER

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

START_SERVER $PORT 1000

LOG "Loading base tables"
RUN $INS $DSN 1000 20 dba dba
if test $STATUS -ne 0
then
        LOG "***ABORTED: tsqlo.sh: loading base tables"
        exit 1
else
        LOG "PASSED: tsqlo.sh: loading base tables"
fi

SHUTDOWN_SERVER

CHECK_LOG
BANNER "COMPLETED T1"

#!/bin/sh
#
#  $Id: tlubm.sh,v 1.1.2.4 2013/01/02 16:15:13 source Exp $
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2015 OpenLink Software
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

LOGFILE=tlubm.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh
#cp -r $VIRTUOSO_TEST/../lubm/* .
cp -r $VIRTUOSO_TEST/../lubm/inf.nt .

BANNER "STARTED LUBM tests"

rm -f $DBLOGFILE
rm -f $DBFILE
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

if [ ! -d lubm_8000 ]
then
 gunzip -c $VIRTUOSO_TEST/../lubm/lubm-data.tar.gz | tar xf -
fi

SHUTDOWN_SERVER
START_SERVER $PORT 1000

BANNER "LUBM LOAD"

RUN $ISQL $DSN PROMPT=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/../lubm/lubm-load.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: lubm-load.sql"
    exit 3
fi

BANNER "LUBM with union"
RUN $ISQL $DSN PROMPT=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/../lubm/lubm.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: lubm.sql"
    exit 3
fi

BANNER "LUBM with inference"
RUN $ISQL $DSN PROMPT=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/../lubm/lubm-inf.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: lubm-inf.sql"
    exit 3
fi

# NO RUN ON v5 -- need to check if this is fine on V7
BANNER "LUBM RDF range conds and full text"
RUN $ISQL $DSN PROMPT=OFF   ERRORS=STDOUT < $VIRTUOSO_TEST/../lubm/trdfrng.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: trdfrng.sql"
    exit 3
fi

BANNER "LUBM with materialized data"
RUN $ISQL $DSN PROMPT=OFF   ERRORS=STDOUT < $VIRTUOSO_TEST/../lubm/lubm-cp.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: lubm-cp.sql"
    exit 3
fi

BANNER "LUBM phys"
RUN $ISQL $DSN PROMPT=OFF   ERRORS=STDOUT < $VIRTUOSO_TEST/../lubm/lubm-phys.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: lubm-phys.sql"
    exit 3
fi

SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED LUBM tests"

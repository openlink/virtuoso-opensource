#!/bin/sh
#
#  $Id$
#
#  Database recovery tests
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2018 OpenLink Software
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
. $HOME/binsrc/tests/suite/test_fn.sh


BANNER "STARTED LUBM tests"

rm -f $DBLOGFILE
rm -f $DBFILE
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
if [ ! -d lubm_8000 ]
then
 gunzip -c lubm-data.tar.gz | tar xf -
fi

SHUTDOWN_SERVER
START_SERVER $PORT 1000

BANNER "LUBM LOAD"

RUN $ISQL $DSN PROMPT=OFF   ERRORS=STDOUT < lubm-load.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: lubm-load.sql"
    exit 3
fi

BANNER "LUBM with union"
RUN $ISQL $DSN PROMPT=OFF   ERRORS=STDOUT < lubm.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: lubm.sql"
    exit 3
fi

BANNER "LUBM with inference"
RUN $ISQL $DSN PROMPT=OFF   ERRORS=STDOUT < lubm-inf.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: lubm-inf.sql"
    exit 3
fi


BANNER "RDF range conds and full text"
RUN $ISQL $DSN PROMPT=OFF   ERRORS=STDOUT < trdfrng.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: trdfrng.sql"
    exit 3
fi


BANNER "LUBM with materialized data"
RUN $ISQL $DSN PROMPT=OFF   ERRORS=STDOUT < lubm-cp.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: lubm-cp.sql"
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF   ERRORS=STDOUT < lubm-phys.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: lubm-phys.sql"
    exit 3
fi

SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED LUBM tests"

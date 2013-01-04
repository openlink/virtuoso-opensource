#!/bin/sh
#
#  tpcd.sh
#
#  $Id$
#
#  TPC-D tests
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2013 OpenLink Software
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

LOGFILE=`pwd`/tpcd.output
export LOGFILE
. ./test_fn.sh

DS1=$PORT
DS2=`expr $PORT + 1`


echo "Server=" $SERVER

BANNER "STARTED SERIES OF TPC-D TESTS (tpcd.sh)"

grep VDB ident.txt
if test $? -ne 0
then 
    echo "The present build is not set up for VDB."
    exit
fi

LOG "Starting the server on $DS1"
LOG

RUN $ISQL $DS1 dba dba '"EXEC=raw_exit();"' ERRORS=STDOUT
RUN $ISQL $DS2 dba dba '"EXEC=raw_exit();"' ERRORS=STDOUT

#
#  Create temp directories for the two remote databases
#
rm -rf tpcdremote1
mkdir tpcdremote1
cd tpcdremote1
MAKECFG_FILE ../$TESTCFGFILE $DS1 $CFGFILE
START_SERVER $DS1 1000
cd ..

LOG
LOG "Loading the TPC-D tables into $DS1"
LOG

cd tpc-d
. ./LOAD.sh $DS1 dba dba tables
. ./LOAD.sh $DS1 dba dba indexes
. ./LOAD.sh $DS1 dba dba procedures
. ./LOAD.sh $DS1 dba dba load
cd ..

LOG
LOG "Running a subset of TPC-D queries against $DS1"
LOG

RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tpc-d/Q.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tpcd.sh: Q.sql"
    exit 1
fi

LOG
LOG "Starting the server on $DS2"
LOG

rm -rf tpcdremote2
mkdir tpcdremote2
cd tpcdremote2
MAKECFG_FILE ../$TESTCFGFILE $DS2 $CFGFILE
START_SERVER $DS2 1000
cd ..

LOG
LOG "Attaching the TPC-D tables from $DS1 into $DS2"
LOG

cd tpc-d
. ./LOAD.sh $DS2 dba dba attach $DS1 dba dba
cd ..

LOG
LOG "Running a subset of TPC-D queries against attached table in $DS2 from $DS1"
LOG

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tpc-d/Q.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tpcd.sh: tpc-d/Q.sql"
    exit 1
fi
RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tpc-d/sql_rdf.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tpcd.sh test -- tpc-d/sql_rdf.sql"
    exit 1
fi
RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tpc-d/all_ms.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tpcd.sh test -- tpc-d/all_ms.sql"
    exit 1
fi
RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tpc-d/test_tbl.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tpcd.sh test -- tpc-d/test_tbl.sql"
    exit 1
fi
RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tpc-d/Q_sparql_map_cmp.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tpcd.sh test -- tpc-d/Q_sparql_map_cmp.sql"
    exit 1
fi

LOG
LOG "Shutdown databases"

RUN $ISQL $DS1 '"EXEC=shutdown;"' ERRORS=STDOUT
RUN $ISQL $DS2 '"EXEC=shutdown;"' ERRORS=STDOUT

#
#  Cleanup
#
# rm -rf repl1 repl2

CHECK_LOG
BANNER "COMPLETED SERIES OF TPC-D TESTS (tpc-d.sh)"

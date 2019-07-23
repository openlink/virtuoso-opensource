#!/bin/sh
#
#  tpcd.sh
#
#  $Id: tpcd.sh,v 1.9.2.2.4.8 2013/01/02 16:15:16 source Exp $
#
#  TPC-D tests
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

mode=${TPCDMODE-local}
if [ $# -ge 1 ]
then
    mode=$1
fi

LOGFILE=`pwd`/tpcd.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh
. $VIRTUOSO_TEST/tpc-d/LOAD.sh
SQLPATH=$SQLPATH:$VIRTUOSO_TEST/tpc-d

DS1=$PORT
DS2=`expr $PORT + 1`

skip_local=0
skip_remote=0
if [ "$mode" = 'local' ]
then
  skip_remote=1
fi

echo "Server=" $SERVER

BANNER "STARTED SERIES OF TPC-D TESTS (tpcd.sh)"

if [ "$VIRTUOSO_VDB" = "0" ]
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

LOAD_TPCD $DS1 dba dba tables
LOAD_TPCD $DS1 dba dba indexes
LOAD_TPCD $DS1 dba dba procedures
LOAD_TPCD $DS1 dba dba load

LOG
LOG "Running a subset of TPC-D queries against $DS1"
LOG

RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tpc-d/Q.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tpcd.sh: Q.sql"
    exit 1
fi

if [ $skip_remote -eq 0 ]
then
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

. $VIRTUOSO_TEST/tpc-d/LOAD.sh $DS2 dba dba attach $DS1 dba dba

LOG
LOG "Running a subset of TPC-D queries against attached table in $DS2 from $DS1"
LOG

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tpc-d/Q.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tpcd.sh: tpc-d/Q.sql"
    exit 1
fi
RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tpc-d/sql_rdf.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tpcd.sh test -- tpc-d/sql_rdf.sql"
    exit 1
fi
RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tpc-d/all_ms.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tpcd.sh test -- tpc-d/all_ms.sql"
    exit 1
fi
RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tpc-d/test_tbl.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tpcd.sh test -- tpc-d/test_tbl.sql"
    exit 1
fi
RUN $ISQL $PORT PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tpc-d/Q_sparql_map_cmp.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tpcd.sh test -- tpc-d/Q_sparql_map_cmp.sql"
    exit 1
fi
fi #end skip

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

#!/bin/sh
#
#  $Id: toptitpcd.sh,v 1.1.2.3 2013/01/02 16:15:15 source Exp $
#
#  SQL Optimizer tests
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

LOGFILE=toptitpcd.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh
SQLPATH=$SQLPATH:$VIRTUOSO_TEST/tpc-d
DS1=$PORT
DS2=`expr $PORT + 1`

if [ "$VIRTUOSO_VDB" = "0" ]
then
    LOG "VDB is not enabled by test suite."
    exit
fi

if [ "$VIRTUOSO_VDB" = "1" ]
then
        PORT=$DS2
	GENERATE_PORTS 1
	DS2=$GENERATED_PORT
        PORT=$DS1
else
    DS2=$DS1
fi

HOST_OS=`uname -s | grep WIN`

if [ "x$HOST_OS" != "x" ]
then
    ISQLO=${ISQLO-isqlo}
    INSO=${INSO-inso}
else
    ISQLO=${ISQLO-../../isql-iodbc}
    INSO=${INSO-../../ins-iodbc}
fi

BANNER "STARTED SQL OPTIMIZER TPCD TESTS"

#if [ "$VIRTUOSO_VDB" = "1" ]

STOP_SERVER $DS1
STOP_SERVER $DS2

MAKECFG_FILE ../$TESTCFGFILE $DS1 $CFGFILE
START_SERVER $DS1 1000

if [ "$VIRTUOSO_VDB" = "1" ]
then
	rm -rf oremote2
	mkdir oremote2
	cd oremote2
	MAKECFG_FILE ../$TESTCFGFILE $DS2 $CFGFILE
	START_SERVER $DS2 1000
	cd ..
fi

#
#	Begin TPC-D VDB Suite
#

LOG "Loading TPC-D tables"

$VIRTUOSO_TEST/tpc-d/LOAD.sh $DS1 dba dba tables
$VIRTUOSO_TEST/tpc-d/LOAD.sh $DS1 dba dba indexes
$VIRTUOSO_TEST/tpc-d/LOAD.sh $DS1 dba dba procedures
$VIRTUOSO_TEST/tpc-d/LOAD.sh $DS1 dba dba load 1

if [ "$VIRTUOSO_VDB" = "1" ]
then
	LOG + running sql script $VIRTUOSO_TEST/tpc-d/all_ms.sql
	RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tpc-d/all_ms.sql
	if test $STATUS -ne 0
	then
	    LOG "***ABORTED: tpcd test -- all_ms.sql"
	    exit 1
	fi
	LOG "PASSED: load MS SQL Server Data"
	
	LOG + running sql script $VIRTUOSO_TEST/tpc-d/test_ms.sql
	RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tpc-d/test_ms.sql
	if test $STATUS -ne 0
	then
	    LOG "***ABORTED: TPC-D vdb test -- test_ms.sql"
	    exit 1
	fi
	LOG "PASSED: Test MS SQL Server Data"
	
	LOG + running sql script $VIRTUOSO_TEST/tpc-d/test_tbl.sql
	RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tpc-d/test_tbl.sql
	if test $STATUS -ne 0
	then
	    LOG "***ABORTED: TPC-D vdb test -- test_tbl.sql"
	    exit 1
	fi
	LOG "PASSED: Create test tables"

	RUN $ISQL $DS2 dba dba $VIRTUOSO_TEST/tpc-d/attach_tpcd.sql -u DSN=$DS1
	if test $STATUS -ne 0
	then
	    LOG "***ABORTED: TPC-D vdb test -- attach_tpcd.sql"
	    exit 1
	fi
	LOG "PASSED: Attach remote tables"
fi

LOG "check local tables..."
LOG + running sql script $VIRTUOSO_TEST/stat.sql
RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/stat.sql

if [ "$VIRTUOSO_VDB" = "1" ]
then
	LOG "check remote tables..."
	LOG + running sql script $VIRTUOSO_TEST/stat.sql
	RUN $ISQL $DS2 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/stat.sql
fi

LOG + running sql script $VIRTUOSO_TEST/tpc-d/all_ms.sql
RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tpc-d/all_ms.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tpcd test -- all_ms.sql"
    exit 1
fi
LOG "PASSED: load MS SQL Server Data"

LOG + running sql script $VIRTUOSO_TEST/tpc-d/test_ms.sql
RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tpc-d/test_ms.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: TPC-D vdb test -- test_ms.sql"
    exit 1
fi
LOG "PASSED: Test MS SQL Server Data"

LOG + running sql script $VIRTUOSO_TEST/tpc-d/test_tbl.sql
RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tpc-d/test_tbl.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: TPC-D vdb test -- test_tbl.sql"
    exit 1
fi
LOG "PASSED: Create test tables"

LOG + running sql script $VIRTUOSO_TEST/tpc-d/load_query.sql
RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tpc-d/load_query.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: TPC-D vdb test -- load_query.sql"
    exit 1
fi

# pass-through VDB tests

if [ "$VIRTUOSO_VDB" = "1" -a -f tpc-d.remotes ]
then
    for line in `cat tpc-d.remotes`
    do
	dsn=`echo $line | cut -f1 -d';'`
	uid=`echo $line | cut -f2 -d';'`
	pwd=`echo $line | cut -f3 -d';'`
	type=`echo $line | cut -f4 -d';'`
	qual=`echo $line | cut -f5 -d';'`
	if [ "z$qual" != "z" ]
        then
	    qual="$qual."
	else
	    qual=\"''\"
	fi
	ECHO BOTH "Testing TPC-D against $dsn as ($uid/$pwd)"
	RUN $ISQL $DS2 dba dba deattach_tpcd.sql
	RUN $ISQL $DS2 dba dba attach_tpcd_vdb.sql -u "DSN=$dsn" "UID=$uid" "PWD=$pwd" "QUAL=$qual"

	echo 'drop table T1;' | RUN $ISQLO $dsn $uid $pwd PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
	echo 'drop table PUPD_TEST;' | RUN $ISQLO $dsn $uid $pwd PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT

        #RUN $INSO $dsn 1000 100 $uid $pwd $type
	RUN $ISQLO $dsn $uid $pwd PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $type

	echo 'update T1 set FI3 = ROW_NO;' | RUN $ISQLO $dsn $uid $pwd PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
	echo 'create table PUPD_TEST (ID integer primary key, DATA varchar (20));' | RUN $ISQLO $dsn $uid $pwd PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
	echo 'create unique index FI3 on T1 (FI3);' | RUN $ISQLO $dsn $uid $pwd PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT

	echo "drop table R1..T1;" | RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
	echo "drop table R1..PUPD_TEST;" | RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT

	echo "attach table T1 as R1..T1 from '$dsn' user '$uid' password '$pwd';" | RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
	echo "attach table PUPD_TEST as R1..PUPD_TEST from '$dsn';" | RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT

	if test $STATUS -ne 0
	then
	    LOG "***ABORTED: TPC-D vdb test -- attach_tpcd_vdb.sql"
	    exit 1
	fi
	LOG "PASSED: Attach remote tables"
        LOG + running sql script $VIRTUOSO_TEST/sqlovdb.sql
	RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$dsn" "LOCALPORT=$DS2" < $VIRTUOSO_TEST/sqlovdb.sql
        LOG + running sql script $VIRTUOSO_TEST/tinl.sql
	RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$dsn" "LOCALPORT=$DS2" < $VIRTUOSO_TEST/tinl.sql
        LOG + running sql script $VIRTUOSO_TEST/tpc-d/load_query.sql
	RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tpc-d/load_query.sql
    done
else
    ECHO "No remote targets configured"
fi

#
#	End TPC-D VDB Suite
#

LOG "Shutdown databases"
SHUTDOWN_SERVER $DS1
SHUTDOWN_SERVER $DS2

CHECK_LOG
BANNER "COMPLETED SQL OPTIMIZER TESTS (tsqlo.sh)"

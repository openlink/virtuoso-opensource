#!/bin/sh
#
#  $Id$
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

LOGFILE=tsqlo.output
export LOGFILE
. ./test_fn.sh
HOST_OS=`uname -s | grep WIN`

if [ "x$HOST_OS" != "x" ]
then
ISQLO=${ISQLO-isqlo}
INSO=${INSO-inso}
else
ISQLO=${ISQLO-../../isql-iodbc}
INSO=${INSO-../../ins-iodbc}
fi

skip_local=0
skip_remote=0
skip_opti=0
skip_tpcd=0

BANNER "STARTED SQL OPTIMIZER TESTS (tsqlo.sh)"

if [ $# -ge 1 ]
then
  if [ "$1" = 'remote' ]
  then
    skip_local=1
    skip_opti=1
    skip_tpcd=1
  elif [ "$1" = 'local' ]
  then
    skip_remote=1
    skip_opti=1
    skip_tpcd=1
  elif [ "$1" = 'opti' ]
  then
    skip_remote=1
    skip_local=1
    skip_tpcd=1
  elif [ "$1" = 'tpcd' ]
  then
    skip_remote=1
    skip_local=1
    skip_opti=1
  fi
fi


grep VDB ident.txt
if test $? -ne 0
then 
    skip_remote=1
    skip_tpcd=1
fi


########################### LOCAL part #######################
if [ $skip_local -eq 0 ]
then

LINE
LOG "Local SQL optimizer tests"
LINE
STOP_SERVER
rm -f $DBLOGFILE
rm -f $DBFILE
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

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < sqlo.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: tsqlo.sql: SQL optimizer functions"
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < sqlo2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tsqlo2.sql: SQL optimizer functions part 2"
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tiso.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tiso.sql: Isolation tests"
    exit 3
fi

#TODO: until fixed to run OK
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < uaggr_test.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tsqlo.sql: User aggrregates tests"
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < cube.sql
if test $STATUS -ne 0
then
     LOG "***ABORTED: tsqlo.sql: User aggrregates tests"
     exit 3
fi


SHUTDOWN_SERVER

fi

########################### optimized startup part #######################
if [ $skip_opti -eq 0 ]
then

LINE
LOG "Server startup in SQL optimizer mode"
LINE
STOP_SERVER
rm -f $DBLOGFILE
rm -f $DBFILE
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

fi


########################### VDB part #######################
if [ $skip_remote -eq 0 -o $skip_tpcd -eq 0 ]
then

DS1=$PORT
DS2=`expr $PORT + 1`

LINE
LOG "Remote database access test"
LINE

DSN=$DS1
STOP_SERVER
DSN=$DS2
STOP_SERVER
DSN=$DS1

rm -rf oremote1
mkdir oremote1
cd oremote1
MAKECFG_FILE ../$TESTCFGFILE $DS1 $CFGFILE
START_SERVER $DS1 1000
cd ..

rm -rf oremote2
mkdir oremote2
cd oremote2
MAKECFG_FILE ../$TESTCFGFILE $DS2 $CFGFILE
START_SERVER $DS2 1000
cd ..

fi
if [ $skip_remote -eq 0 ]
then
LOG "Loading base tables"

RUN $INS $DS1 1000 100 dba dba usedt
if test $STATUS -ne 0
then
    LOG "***ABORTED: tsqlo.sh: loading base tables DS1"
    exit 1
fi

RUN $INS $DS2 1000 100 dba dba usedt
if test $STATUS -ne 0
then
    LOG "***ABORTED: tsqlo.sh: loading base tables DS2"
    exit 1
fi

echo 'update T1 set FI3 = ROW_NO;' | RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
echo 'create table PUPD_TEST (ID integer primary key, DATA varchar (20));' | RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
echo 'create unique index FI3 on T1 (FI3);' | RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
echo 'update T1 set FI3 = ROW_NO;' | RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
echo 'create unique index FI3 on T1 (FI3);' | RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
echo "attach table T1 as R1..T1 from '$DS1' user 'dba' password 'dba';" | RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
echo "attach table PUPD_TEST as R1..PUPD_TEST from '$DS1';" | RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
#echo 'sqlo_enable (1);' | RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
#echo 'sqlo_enable (1);' | RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$DS1" "LOCALPORT=$DS2" < sqlovdb.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tsqlo.sh: SQLO remote tests (sqlovdb.sql)"
    exit 1
fi
RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$DS1" "LOCALPORT=$DS2" < tinl.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tsqlo.sh: SQLO remote tests (tinl.sql)"
    exit 1
fi


fi
#
#	Begin TPC-D VDB Suite
#

if [ $skip_tpcd -eq 0 ]
then
LOG "Loading TPC-D tables"
cd tpc-d
./LOAD.sh $DS1 dba dba tables
./LOAD.sh $DS1 dba dba indexes
./LOAD.sh $DS1 dba dba procedures
./LOAD.sh $DS1 dba dba load 1

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < all_ms.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: tpcd test -- all_ms.sql"
    exit 1
fi
LOG "PASSED: load MS SQL Server Data"

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < test_ms.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: TPC-D vdb test -- test_ms.sql"
    exit 1
fi
LOG "PASSED: Test MS SQL Server Data"

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < test_tbl.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: TPC-D vdb test -- test_tbl.sql"
    exit 1
fi
LOG "PASSED: Create test tables"


RUN $ISQL $DS2 dba dba attach_tpcd.sql -u DSN=$DS1

if test $STATUS -ne 0
then
    LOG "***ABORTED: TPC-D vdb test -- attach_tpcd.sql"
    exit 1
fi
LOG "PASSED: Attach remote tables"

LOG "check local tables..."
RUN $ISQL $DS1 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < ../stat.sql
LOG "check remote tables..."
RUN $ISQL $DS2 dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < ../stat.sql


RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < all_ms.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: tpcd test -- all_ms.sql"
    exit 1
fi
LOG "PASSED: load MS SQL Server Data"

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < test_ms.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: TPC-D vdb test -- test_ms.sql"
    exit 1
fi
LOG "PASSED: Test MS SQL Server Data"

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < test_tbl.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: TPC-D vdb test -- test_tbl.sql"
    exit 1
fi
LOG "PASSED: Create test tables"



RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < load_query.sql

if test $STATUS -ne 0
then
    LOG "***ABORTED: TPC-D vdb test -- load_query.sql"
    exit 1
fi

# pass-through VDB tests

if [ ! -f tpc-d.remotes ]
then
   ECHO "No remote targets configured"
else
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
       RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$dsn" "LOCALPORT=$DS2" < ../sqlovdb.sql
       RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$dsn" "LOCALPORT=$DS2" < ../tinl.sql
       RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < load_query.sql
     done
fi

cd ..

cat tpc-d/$LOGFILE >> $LOGFILE

#
#	End TPC-D VDB Suite
#
fi


if [ $skip_remote -eq 0 -o $skip_tpcd -eq 0 ]
then
LOG "Shutdown databases"
DSN=$DS1
SHUTDOWN_SERVER
DSN=$DS2
SHUTDOWN_SERVER

fi
CHECK_LOG
BANNER "COMPLETED SQL OPTIMIZER TESTS (tsqlo.sh)"

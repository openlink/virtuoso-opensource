#!/bin/sh
#
#  $Id: toptiremote.sh,v 1.1.2.4 2013/01/02 16:15:15 source Exp $
#
#  SQL Optimizer tests
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

LOGFILE=toptiremote.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

BANNER "STARTED SQL OPTIMIZER VDB TESTS"

if [ "$VIRTUOSO_VDB" = "0" ]
then
    LOG "VDB is not enabled by test suite."  
    exit
fi

SQLPATH=$SQLPATH:$VIRTUOSO_TEST/tpc-d
DS1=$PORT
DS2=$PORT
GENERATE_PORTS 1
DS2=$GENERATED_PORT

HOST_OS=`uname -s | grep WIN`

if [ "x$HOST_OS" != "x" ]
then
    ISQLO=${ISQLO-isqlo}
    INSO=${INSO-inso}
else
    ISQLO=${ISQLO-../../isql-iodbc}
    INSO=${INSO-../../ins-iodbc}
fi

LINE
LOG "Remote database access test"
LINE

STOP_SERVER $DS1
STOP_SERVER $DS2

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

LOG "Loading base tables"

RUN $INS $DS1 1000 100 dba dba usedt
if test $STATUS -ne 0
then
    LOG "***ABORTED: toptiremote.sh: loading base tables DS1"
    exit 1
fi

RUN $INS $DS2 1000 100 dba dba usedt
if test $STATUS -ne 0
then
    LOG "***ABORTED: toptiremote.sh: loading base tables DS2"
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

LOG + running sql script $VIRTUOSO_TEST/sqlovdb.sql
RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$DS1" "LOCALPORT=$DS2" < $VIRTUOSO_TEST/sqlovdb.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: toptiremote.sh: SQLO remote tests (sqlovdb.sql)"
    exit 1
fi
LOG + running sql script $VIRTUOSO_TEST/tinl.sql
RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$DS1" "LOCALPORT=$DS2" < $VIRTUOSO_TEST/tinl.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: toptiremote.sh: SQLO remote tests (tinl.sql)"
    exit 1
fi

LOG "Shutdown databases"
SHUTDOWN_SERVER $DS1
SHUTDOWN_SERVER $DS2

CHECK_LOG
BANNER "COMPLETED SQL OPTIMIZER TESTS for VDB (toptiremote.sh)"

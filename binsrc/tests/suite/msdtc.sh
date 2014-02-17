#!/bin/sh
#
#  $Id: msdtc.sh,v 1.13.8.4 2013/01/02 16:14:42 source Exp $
#
#  MS DTC tests
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

LOGFILE=msdtc.output
export LOGFILE
rm -f $LOGFILE
. $VIRTUOSO_TEST/testlib.sh
HOST_OS=`uname -s | grep WIN`

if [ "x$HOST_OS" = "x" ]
then
    LOG "This test is for Windows Virtuoso server only"
    exit 0
fi

if [ "x$HOST_OS" != "x" ]
then
ISQLO=${ISQLO-isqlo}
INSO=${INSO-inso}
else
ISQLO=${ISQLO-../../isql-iodbc}
INSO=${INSO-../../ins-iodbc}
fi

DSN_FILE=virt.odbc
MTSTEST=${MTSTEST-mtstest.exe}
MTSTCONF="-f $DSN_FILE -d $VIRTUOSO_TEST/../mts/"
VOLEDBT=${VOLEDBTEST-$VIRTUOSO_TEST/../mts/voledbtest.exe}

PLUGIN=../msdtc_sample.dll

rm -rf plugins
mkdir plugins
cp $PLUGIN plugins

mkINI ()
{
file=$1
    cat > $file <<END_CFG
[Database]
DatabaseFile            = virtuoso.db
TransactionFile         = virtuoso.trx
ErrorLogFile            = virtuoso.log
ErrorLogLevel           = 7
FileExtend              = 200
Striping                = 0
Syslog                  = 0

;
;  Server parameters
;
[Parameters]
ServerPort              = $2
ServerThreads           = 100
CheckpointInterval      = 60
NumberOfBuffers         = 2000
MaxDirtyBuffers         = 1200
MaxCheckpointRemap      = 20000
UnremapQuota            = 0
AtomicDive              = 1
PrefixResultNames       = 0
CaseMode                = 2
DisableMtWrite          = 0
SchedulerInterval      = 0
DirsAllowed             = /, c:\\, d:\\, e:\\
PLDebug                 = $PLDBG
TestCoverage            = cov.xml
SQLOptimizer            = $SQLOPTIMIZE

[Client]
SQL_ROWSET_SIZE         = 100
SQL_PREFETCH_BYTES      = 12000

[Replication]
ServerName      = vspxtest
ServerEnable    = 1
QueueMax        = 1000000

[Plugins]
LoadPath = plugins
Load1 = msdtc, msdtc_sample
END_CFG


}

DS1=$PORT
DS2=`expr $PORT + 1`
DS3=`expr $PORT + 2`

cat > $DSN_FILE << END_FILE
$DS1 dba dba 00.sql
$DS2 dba dba 01.sql
END_FILE

case $SERVER in

  *virtuoso*)
	if [ -z "$ENABLE_MTS_TEST" -o "$ENABLE_MTS_TEST" -eq 0 ]
	then 
		LOG "MTS test is skiped"
		exit 0
	fi
	;;
  *)
    LOG "This test is for Virtuoso server only"
    exit 0
    ;;
esac

BANNER "STARTED MS DTC SUPPORT TESTS (msdtc.sh)"

LOG	"MS DTC throw ODBC test"

RUN $ISQL $DS1 dba dba '"EXEC=raw_exit();"' ERRORS=STDOUT
RUN $ISQL $DS2 dba dba '"EXEC=raw_exit();"' ERRORS=STDOUT

rm -rf msdtc1
mkdir msdtc1
cd msdtc1

mkINI "virtuoso.ini" $DS1

LOGFILE=../msdtc.output
cp -r $VIRTUOSO_TEST/plugins ./
START_SERVER $DS1 1000
cd ..

rm -rf msdtc2
mkdir msdtc2
cd msdtc2

mkINI "virtuoso.ini" $DS2

cp -r $VIRTUOSO_TEST/plugins ./
START_SERVER $DS2 1000
cd ..

LOGFILE=msdtc.output

RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/msdtc_conn_check.sql
RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/msdtc_conn_check.sql

RUN $MTSTEST $MTSTCONF +load
if test $STATUS -eq 0
then
    LOG "PASSED: msdtc.sh: loading base tables"

	RUN $MTSTEST $MTSTCONF +exec 100
	if test $STATUS -eq 0
	then
		LOG "PASSED: msdtc.sh: executing 100 calls"
		
		RUN $MTSTEST $MTSTCONF +exec 0
		if test $STATUS -eq 0
		then
			LOG "PASSED: msdtc.sh: check tables"
		else
			LOG "***FAILED: msdtc.sh: check tables STATUS=$STATUS"
		fi
	else
		LOG "***FAILED: msdtc.sh: executing 100 calls STATUS=$STATUS"
	fi
else
    LOG "***FAILED: msdtc.sh: loading base tables STATUS=$STATUS"
fi

LOG	"MS DTC recovery test"

RUN $MTSTEST $MTSTCONF +load
if test $STATUS -eq 0
then
    LOG "PASSED: msdtc.sh: loading base tables"
else
    LOG "***FAILED: msdtc.sh: loading base tables STATUS=$STATUS"
fi

RUN $MTSTEST $MTSTCONF +exec 100 +crash
if test $STATUS -eq 0
then
	LOG "PASSED: msdtc.sh: exec 100, crash"
else
	LOG "***FAILED: msdtc.sh: exec 100, crash STATUS=$STATUS"
fi


RUN $ISQL $DS2 '"EXEC=shutdown;"' ERRORS=STDOUT
if test $STATUS -eq 0
then
        LOG "PASSED: server shutdowned STATUS=$STATUS"
fi

cd msdtc2
RUN $ISQL $DS2 dba dba '"EXEC=shutdown;"' ERRORS=STDOUT
sleep 10


START_SERVER $DS2 1000
cd ..

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/msdtc_conn_check.sql

RUN $MTSTEST $MTSTCONF +exec 0
if test $STATUS -eq 0
then
	LOG "PASSED: msdtc.sh: check tables"
else
	LOG "***FAILED: msdtc.sh: check tables STATUS=$STATUS"
fi

# LOG "Shutdown databases"
# RUN $ISQL $DS1 '"EXEC=shutdown;"' ERRORS=STDOUT
# RUN $ISQL $DS2 '"EXEC=shutdown;"' ERRORS=STDOUT

rm -rf msdtc3
mkdir msdtc3
cd msdtc3


mkINI "virtuoso.ini" $DS3

LOGFILE=../msdtc.output
cp -r $VIRTUOSO_TEST/plugins ./
START_SERVER $DS3 1000
cd ..

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/msdtc_conn_check.sql

RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/../virttp/SQL/00common/00ddl.sql
if test $STATUS -eq 0
then
        LOG "PASSED: msdtc.sh: DDL 1"
else
        LOG "***FAILED: msdtc.sh: DDL 1 STATUS=$STATUS"
fi

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/../virttp/SQL/00common/00ddl.sql
if test $STATUS -eq 0
then
        LOG "PASSED: msdtc.sh: DDL 2"
else
        LOG "***FAILED: msdtc.sh: DDL 2 STATUS=$STATUS"
fi

RUN $ISQL $DS3 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/../virttp/SQL/00common/00ddl.sql
if test $STATUS -eq 0
then
        LOG "PASSED: msdtc.sh: DDL 3"
else
        LOG "***FAILED: msdtc.sh: DDL 3 STATUS=$STATUS"
fi


RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/../virttp/SQL/00common/05utils.sql
if test $STATUS -eq 0
then
        LOG "PASSED: msdtc.sh: UTILS 1"
else
        LOG "***FAILED: msdtc.sh: UTILS 1 STATUS=$STATUS"
fi

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/../virttp/SQL/00common/05utils.sql
if test $STATUS -eq 0
then
        LOG "PASSED: msdtc.sh: UTILS 2"
else
        LOG "***FAILED: msdtc.sh: UTILS 2 STATUS=$STATUS"
fi

RUN $ISQL $DS3 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/../virttp/SQL/00common/05utils.sql
if test $STATUS -eq 0
then
        LOG "PASSED: msdtc.sh: UTILS 3"
else
        LOG "***FAILED: msdtc.sh: UTILS 3 STATUS=$STATUS"
fi



RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/../virttp/SQL/00common/10tran.sql
if test $STATUS -eq 0
then
        LOG "PASSED: msdtc.sh: TRAN 1"
else
        LOG "***FAILED: msdtc.sh: TRAN 1 STATUS=$STATUS"
fi

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/../virttp/SQL/00common/10tran.sql
if test $STATUS -eq 0
then
        LOG "PASSED: msdtc.sh: TRAN 2"
else
        LOG "***FAILED: msdtc.sh: TRAN 2 STATUS=$STATUS"
fi

RUN $ISQL $DS3 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/../virttp/SQL/00common/10tran.sql
if test $STATUS -eq 0
then
        LOG "PASSED: msdtc.sh: TRAN 3"
else
        LOG "***FAILED: msdtc.sh: TRAN 3 STATUS=$STATUS"
fi



RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/../virttp/SQL/00common/20fill.sql
if test $STATUS -eq 0
then
        LOG "PASSED: msdtc.sh: FILL 1"
else
        LOG "***FAILED: msdtc.sh: FILL 1 STATUS=$STATUS"
fi

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/../virttp/SQL/00common/20fill.sql
if test $STATUS -eq 0
then
        LOG "PASSED: msdtc.sh: FILL 2"
else
        LOG "***FAILED: msdtc.sh: FILL 2 STATUS=$STATUS"
fi

RUN $ISQL $DS3 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/../virttp/SQL/00common/20fill.sql
if test $STATUS -eq 0
then
        LOG "PASSED: msdtc.sh: FILL 3"
else
        LOG "***FAILED: msdtc.sh: FILL 3 STATUS=$STATUS"
fi


RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "DS3=$DS3" "DS2=$DS2" < $VIRTUOSO_TEST/../virttp/SQL/r1/remotes.sql
if test $STATUS -eq 0
then
        LOG "PASSED: msdtc.sh: REMOTES 1"
else
        LOG "***FAILED: msdtc.sh: REMOTES 1 STATUS=$STATUS"
fi

RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/../virttp/TEST/00test.sql
if test $STATUS -eq 0
then
        LOG "PASSED: msdtc.sh: TEST 1"
else
        LOG "***FAILED: msdtc.sh: TEST 1 STATUS=$STATUS"
fi

echo "select test_succ()" ';' | RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -eq 0
then
  echo "PASSED: test_succ()"
else
  echo "***FAILED: test_succ()"
fi


LOG     "MS DTC throw OLE DB test"

RUN $VOLEDBT
if test $STATUS -eq 0
then
        LOG "PASSED: msdtc.sh: virt OLE DB test"
else
        LOG "***FAILED: msdtc.sh: virt OLE DB test STATUS=$STATUS"
fi

echo "select test_succ()" ';' | RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT

if test $STATUS -eq 0
then
  echo "PASSED: test_succ()"
else
  echo "***FAILED: test_succ()"
fi



# LOG "virt TP test"
# LOGFILE=../msdtc.output
# cd $VIRTUOSO_TEST/../virttp
# . ./virttp.sh
# cd $VIRTUOSO_TEST/../suite

LOGFILE=msdtc.output

LOG "Shutdown databases"
RUN $ISQL $DS1 '"EXEC=shutdown;"' ERRORS=STDOUT
RUN $ISQL $DS2 '"EXEC=shutdown;"' ERRORS=STDOUT
RUN $ISQL $DS3 '"EXEC=shutdown;"' ERRORS=STDOUT

CHECK_LOG
BANNER "COMPLETED MS DTC SUPPORT TESTS (msdtc.sh)"

#!/bin/sh
#
#  $Id: trecov_schema.sh,v 1.5.6.4.4.5 2013/01/02 16:15:19 source Exp $
#
#  Database recovery tests
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

LOGFILE=trecov_schema.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh
cp $VIRTUOSO_TEST/spanish.coll .
cp $VIRTUOSO_TEST/words.esp .

BANNER "STARTED SCHEMA RECOVERY TEST (trecov_schema.sh)"

if [ "$SERVER" -ne "virtuoso" -o "$SERVER" -ne "virtuoso-t" ]
  echo "SKIPPED: Unknown server. Exiting" | tee -a $LOGFILE
  exit
fi

rm -f $DELETEMASK
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

SHUTDOWN_SERVER
START_SERVER $PORT 1000

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/treg1.sql

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tblob.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: trecov_schema.sh: Inline Blobs "
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tconcur2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: trecov_schema.sh: Concurrent inserts with timestamp key"
    exit 3
fi

RUN $ISQL $DSN '"EXEC=status();"' ERRORS=STDOUT

RUN $BLOBS $DSN
if test $STATUS -eq 0
then
    LOG "PASSED: trecov_schema.sh: creating blobs"
else
    LOG "***ABORTED: trecov_schema.sh: creating blobs"
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/blobs.sql
if test $STATUS -eq 0
then
    LOG "PASSED: trecov_schema.sh: blobs 1st round"
else
    LOG "***ABORTED: trecov_schema.sh: blobs 1st round"
    exit 3
fi

RUN $BLOBS $DSN
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/blobs.sql
if test $STATUS -eq 0
then
    LOG "PASSED: trecov_schema.sh: blobs 2nd round"
else
    LOG "***ABORTED: trecov_schema.sh: blobs 2nd round"
    exit 3
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tschema1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: trecov_schema.sh: Schema test"
    exit 3
fi

SHUTDOWN_SERVER
START_SERVER $PORT 3000
LOG "Next we do a checkpoint third time and then kill database server with"
LOG "raw_exit() after which we should get Lost Connection to Server -error."
#RUN $ISQL $DSN '"EXEC=checkpoint; raw_exit();"' ERRORS=STDOUT
CHECKPOINT_SERVER
STOP_SERVER
sleep 5

### schema recovery test

rm -rf new.*
ECHO cat $CFGFILE | sed -e 's/virtuoso\./new./g' > new.ini
cat $CFGFILE | sed -e 's/virtuoso\./new./g' > new.ini
rm $DBLOGFILE

RUN $SERVER $FOREGROUND_OPTION $CRASH_DUMP_OPTION +mode oa +dumpkeys schema
cp $DBLOGFILE $DBLOGFILE.sr1
cp $DBFILE $DBFILE.sr1
cp $SRVMSGLOGFILE $SRVMSGLOGFILE.sr1

RUN ls -la *.trx
RUN mv $DBLOGFILE new.trx

RUN $SERVER $FOREGROUND_OPTION -c new -R
cp new.db new.db.sr2
cp new.log new.log.sr2
RUN $SERVER $FOREGROUND_OPTION -c new $CRASH_DUMP_OPTION +crash-dump-data-ini $CFGFILE +mode o
cp $DBLOGFILE $DBLOGFILE.sr2
cp $SRVMSGLOGFILE $SRVMSGLOGFILE.sr2

RUN ls -la *.trx
RUN mv $DBLOGFILE new.trx

RUN $SERVER $FOREGROUND_OPTION -c new -R
cp new.db new.db.sr3

rm new.trx
RUN $SERVER $FOREGROUND_OPTION -c new $CRASH_DUMP_OPTION

RUN rm -f $DELETEMASK
RUN ls -la *.trx
RUN mv new.trx $DBLOGFILE
cp $DBLOGFILE $DBLOGFILE.sr3

RUN ls -la virtuoso.*
RUN $SERVER $FOREGROUND_OPTION -R
cp $DBFILE $DBFILE.sr4

### end schema recovery test
## now check for results

RUN ls -la virtuoso.*
START_SERVER $PORT 3000

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/recovck1_noreg.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: trecov_schema.sh: Connect failed after -d roll forward"
    exit 3
fi

RUN $ISQL $DSN USR3 USR3PASS PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT EXEC="'select USER'"
if test $STATUS -ne 0
then
    LOG "***ABORTED: trecov_schema.sh: Connect for USR3 failed after -d roll forward"
    exit 3
fi

SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED SCHEMA RECOVERY TEST (trecov_schema.sh)"

#!/bin/sh
#
#  $Id: trecov.sh,v 1.22.6.8.4.8 2013/01/02 16:15:19 source Exp $
#
#  Database recovery tests
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

LOGFILE=trecov.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh
cp $VIRTUOSO_TEST/words.esp .
cp $VIRTUOSO_TEST/spanish.coll .
cp $VIRTUOSO_TEST/tst.nq .
cp $VIRTUOSO_TEST/tst2.nq .

BANNER "STARTED RECOVERY TEST (trecov.sh)"
if [ "$CURRENT_VIRTUOSO_CAPACITY" != "single" ]
then
    exit 0
fi

rm -f $DBLOGFILE
rm -f $DBFILE
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

SHUTDOWN_SERVER
START_SERVER $PORT 1000

LOG + running sql script treg1
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/treg1.sql

LOG + running sql script tblob
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tblob.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: trecov.sh: Inline Blobs "
    exit 3
fi

LOG + running sql script trdfld
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/trdfld.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: trecov.sh: rdf ld "
    exit 3
fi



LOG + running sql script tconcur2
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tconcur2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: trecov.sh: Concurrent inserts with timestamp key"
    exit 3
fi

RUN $ISQL $DSN '"EXEC=status();"' ERRORS=STDOUT

#RUN $BLOBS $DSN
#if test $STATUS -eq 0
#then
#    LOG "PASSED: trecov.sh: creating blobs"
#else
#    LOG "***ABORTED: trecov.sh: creating blobs"
#    exit 3
#fi

#LOG + running sql script blobs
#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/blobs.sql
#if test $STATUS -eq 0
#then
#    LOG "PASSED: trecov.sh: blobs 1st round"
#else
#    LOG "***ABORTED: trecov.sh: blobs 1st round"
#    exit 3
#fi

#RUN $BLOBS $DSN
#LOG + running sql script blobs
#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/blobs.sql
#if test $STATUS -eq 0
#then
#    LOG "PASSED: trecov.sh: blobs 2nd round"
#else
#    LOG "***ABORTED: trecov.sh: blobs 2nd round"
#    exit 3
#fi


LOG + running sql script tschema1
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tschema1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: trecov.sh: Schema test"
    exit 3
fi

STOP_SERVER

rm -f $DBFILE.r1 $DBLOGFILE.r1 $SRVMSGLOGFILE.r1
cp $DBFILE $DBFILE.r1
cp $DBLOGFILE $DBLOGFILE.r1
cp $SRVMSGLOGFILE $SRVMSGLOGFILE.r1
START_SERVER $PORT 2000


LOG + running sql script recovck1
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/recovck1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: trecov.sh: Connect failed after log roll forward"
    exit 3
fi

RUN $ISQL $DSN USR3 USR3PASS PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT EXEC='"select USER"'
if test $STATUS -ne 0
then
    LOG "***ABORTED: trecov.sh: Connect for USR3 failed after log roll forward"
#    exit 3
fi

if test "x$HOST" != "xlocalhost"
then
    BANNER "COMPLETED RECOVERY TEST (trecov.sh)"
    exit 0
fi

LOG "Next we do a checkpoint and kill the database server with raw_exit()"
LOG "after which we should get Lost Connection to Server -error."
CHECKPOINT_SERVER
STOP_SERVER

# The following might need a change later if the implementation changes:
if test -r "$DBLOGFILE"
then
    if test -s "$DBLOGFILE"
    then
	ECHO "The file $DBLOGFILE is longer than zero bytes after checkpoint"
	ls -la $DBLOGFILE | tee -a $LOGFILE
	ECHO "Log file $DBLOGFILE is removed manually"
	rm $DBLOGFILE
    else
	LOG "PASSED: The file $DBLOGFILE is empty after checkpoint"
    fi
else
    LOG "***FAILED: No $DBLOGFILE file exists after checkpoint."
fi

if test -f "$LOCKFILE"
then
  echo Removing $LOCKFILE >> $LOGFILE
  rm $LOCKFILE
fi

START_SERVER $PORT 0 $FOREGROUND_OPTION $BACKUP_DUMP_OPTION
if test $STATUS -eq 0
then
    LOG "PASSED: DUMPING the database with -d option"
else
    LOG "***FAILED AND ABORTED: DUMPING the database with -d option"
    exit 3
fi

rm -f $DBFILE.r2 $DBLOGFILE.r2 $SRVMSGLOGFILE.r2
cp $DBFILE $DBFILE.r2
cp $DBLOGFILE $DBLOGFILE.r2
cp $SRVMSGLOGFILE $SRVMSGLOGFILE.r2
rm -f $DBFILE

LOG "restoring the database 1st time with -R option..."
START_SERVER $PORT 0 $FOREGROUND_OPTION -R
if test $STATUS -eq 0
then
    LOG "PASSED: restoring the database with -R option"
else
    LOG "***FAILED AND ABORTED: restoring the database with -R option"
    exit 3
fi

START_SERVER $PORT 3000

LOG + running sql script recovck1
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/recovck1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: trecov.sh: Connect failed after -d roll forward"
    exit 3
fi
RUN $ISQL $DSN USR3 USR3PASS PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT EXEC="'select USER'"
if test $STATUS -ne 0
then
    LOG "***ABORTED: trecov.sh: Connect for USR3 failed after -d roll forward"
    exit 3
fi

LOG + running sql script backup
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/backup.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: trecov.sh: Connect failed for backup"
    cp $DBFILE $DBFILE.r3_1
    exit 3
fi

LOG "Next, we kill database server with raw_exit()"
LOG "after which we should get Lost Connection to Server -error."
STOP_SERVER

rm -f $DBLOGFILE
mv backup.log $DBLOGFILE
rm -f $DBFILE.r3 $DBLOGFILE.r3 $SRVMSGLOGFILE.r1
cp $DBFILE $DBFILE.r3
cp $DBLOGFILE $DBLOGFILE.r3
cp $SRVMSGLOGFILE $SRVMSGLOGFILE.r3
rm -f $DBFILE

if [ "$CURRENT_VIRTUOSO_CAPACITY" != "single" ]
then
   rm -f cl?/$DBFILE
   mv cl2/backup.log cl2/$DBLOGFILE
   mv cl3/backup.log cl3/$DBLOGFILE
   mv cl4/backup.log cl4/$DBLOGFILE
fi

LOG "restoring the database 2nd time with -R option..."
START_SERVER $PORT 0 $FOREGROUND_OPTION -R
if test $STATUS -eq 0
then
    LOG "PASSED: restoring the database with -R option"
else
    LOG "***FAILED AND ABORTED: restoring the database with -R option"
    exit 3
fi

START_SERVER $PORT 3000
LOG + running sql script recovck1
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/recovck1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: trecov.sh: Connect failed after backup restore 1"
    exit 3
fi
RUN $ISQL $DSN USR3 USR3PASS PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT EXEC="'select USER'"
if test $STATUS -ne 0
then
    LOG "***ABORTED: trecov.sh: Connect for USR3 failed after backup restore"
    exit 3
fi

LOG "Again we do a checkpoint and then kill database server with raw_exit()"
LOG "after which we should get Lost Connection to Server -error."
CHECKPOINT_SERVER
STOP_SERVER

if test -f "$LOCKFILE"
then
  echo Removing $LOCKFILE >> $LOGFILE
  rm $LOCKFILE
fi
ls -la $DBLOGFILE
rm -f $DBLOGFILE
START_SERVER $PORT 0 $FOREGROUND_OPTION $CRASH_DUMP_OPTION
if test $STATUS -eq 0
then
    LOG "PASSED: DUMPING the database with -D option"
else
    LOG "***FAILED AND ABORTED: DUMPING the database with -D option"
    exit 3
fi

rm -f $DBFILE.r4 $DBLOGFILE.r4 $SRVMSGLOGFILE.r4
cp $DBFILE $DBFILE.r4
cp $DBLOGFILE $DBLOGFILE.r4
cp $SRVMSGLOGFILE $SRVMSGLOGFILE.r4
rm -f $DBFILE

LOG "restoring the database 3rd time with -R option..."
START_SERVER $PORT 0 $FOREGROUND_OPTION -R
if test $STATUS -eq 0
then
    LOG "PASSED: restoring the database with -R option"
else
    LOG "***FAILED AND ABORTED: restoring the database with -R option"
    exit 3
fi

START_SERVER $PORT 3000

LOG + running sql script recovck1
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/recovck1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: trecov.sh: Connect failed after backup restore 2"
    exit 3
fi
RUN $ISQL $DSN USR3 USR3PASS PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT EXEC="'select user'"
if test $STATUS -ne 0
then
    LOG "***ABORTED: trecov.sh: Connect for USR3 failed after backup restore"
    exit 3
fi

#LOG + running sql script tbfree
#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tbfree.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: trecov.sh: doing tbfree.sql"
    exit 3
fi

LOG "Next we do a checkpoint third time and then kill database server with"
LOG "raw_exit() after which we should get Lost Connection to Server -error."
CHECKPOINT_SERVER
STOP_SERVER

if [ "x$ENABLE_TRECOV_SCH" != "x" ]
then # GK: disabled for now : fails blobs check
### schema recovery test

rm -rf new.*
ECHO cat $CFGFILE | sed -e 's/virtuoso\./new./g' > new.ini
cat $CFGFILE | sed -e 's/virtuoso\./new./g' > new.ini

START_SERVER $PORT 0 $FOREGROUND_OPTION $CRASH_DUMP_OPTION +mode oa +dumpkeys schema

RUN ls -la *.trx
RUN mv $DBLOGFILE new.trx

START_SERVER $PORT 0 $FOREGROUND_OPTION -c new -R
START_SERVER $PORT 0 $FOREGROUND_OPTION -c new $CRASH_DUMP_OPTION +crash-dump-data-ini $CFGFILE +mode o

RUN ls -la *.trx
RUN mv $DBLOGFILE new.trx

START_SERVER $PORT 0 $FOREGROUND_OPTION -c new -R

START_SERVER $PORT 0 $FOREGROUND_OPTION -c new $CRASH_DUMP_OPTION

RUN rm -f $DELETEMASK
RUN ls -la *.trx
RUN mv new.trx $DBLOGFILE

RUN ls -la virtuoso.*
START_SERVER $PORT 0 $FOREGROUND_OPTION -R

### end schema recovery test
## now check for results

RUN ls -la virtuoso.*
START_SERVER $PORT 3000

LOG + running sql script recovck1_noreg
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

fi # GK: disabled for now : fails blobs check

SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED RECOVERY TEST (trecov.sh)"

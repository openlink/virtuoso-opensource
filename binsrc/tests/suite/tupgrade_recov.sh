#!/bin/sh
#
#  $Id$
#
#  Database recovery tests afer database upgrade
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

LOGFILE=tupgrade_recov.output
export LOGFILE
. ./test_fn.sh

BANNER "STARTED UPGRADE & RECOVERY TEST (tupgrade_recov.sh)"

rm -f $DBLOGFILE
rm -f $DBFILE
cp test_1947.db.test $DBFILE
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

SHUTDOWN_SERVER
START_SERVER $PORT 1000

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < treg1.sql

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tblob.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tupgrade_recov.sh: Inline Blobs "
    exit 3
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tconcur2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tupgrade_recov.sh: Concurrent inserts with timestamp key"
    exit 3
fi

RUN $ISQL $DSN '"EXEC=status();"' ERRORS=STDOUT

RUN $BLOBS $DSN
if test $STATUS -eq 0
then
    LOG "PASSED: tupgrade_recov.sh: creating blobs"
else
    LOG "***ABORTED: tupgrade_recov.sh: creating blobs"
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < blobs.sql
if test $STATUS -eq 0
then
    LOG "PASSED: tupgrade_recov.sh: blobs 1st round"
else
    LOG "***ABORTED: tupgrade_recov.sh: blobs 1st round"
    exit 3
fi

RUN $BLOBS $DSN
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < blobs.sql
if test $STATUS -eq 0
then
    LOG "PASSED: tupgrade_recov.sh: blobs 2nd round"
else
    LOG "***ABORTED: tupgrade_recov.sh: blobs 2nd round"
    exit 3
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tschema1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tupgrade_recov.sh: Schema test"
    exit 3
fi


#LOG "Next, we kill the database server with raw_exit()"
#LOG "after which we should get Lost Connection to Server -error."
#RUN $ISQL $DSN '"EXEC=raw_exit();"' VERBOSE=OFF ERRORS=STDOUT
STOP_SERVER

sleep 5
START_SERVER $PORT 2000


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < recovck1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tupgrade_recov.sh: Connect failed after log roll forward"
    exit 3
fi

if test "x$HOST" != "xlocalhost"
then
    BANNER "COMPLETED UPGRADE & RECOVERY TEST (tupgrade_recov.sh)"
    exit 0
fi

LOG "Next we do a checkpoint and kill the database server with raw_exit()"
LOG "after which we should get Lost Connection to Server -error."
RUN $ISQL $DSN '"EXEC=checkpoint; raw_exit();"' ERRORS=STDOUT
sleep 5

# The following might need a change later if the implementation changes:
if test -r "$DBLOGFILE"
then
    if test -s "$DBLOGFILE"
    then
	LOG "***FAILED: The file $DBLOGFILE is longer than zero bytes after checkpoint"
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
RUN $SERVER $FOREGROUND_OPTION $BACKUP_DUMP_OPTION
if test $STATUS -eq 0
then
    LOG "PASSED: DUMPING the database with -d option"
else
    LOG "***FAILED AND ABORTED: DUMPING the database with -d option"
    exit 3
fi

rm -f $DBFILE
START_SERVER $PORT 3000 -R

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < recovck1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tupgrade_recov.sh: Connect failed after -d roll forward"
    exit 3
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < backup.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tupgrade_recov.sh: Connect failed for backup"
    exit 3
fi

LOG "Next, we kill database server with raw_exit()"
LOG "after which we should get Lost Connection to Server -error."
RUN $ISQL $DSN '"EXEC=raw_exit();"' VERBOSE=OFF ERRORS=STDOUT
sleep 5

rm -f $DBLOGFILE
mv backup.log $DBLOGFILE
rm -f $DBFILE

START_SERVER $PORT 3000 -R
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < recovck1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tupgrade_recov.sh: Connect failed after backup restore"
    exit 3
fi

LOG "Again we do a checkpoint and then kill database server with raw_exit()"
LOG "after which we should get Lost Connection to Server -error."
RUN $ISQL $DSN ERRORS=STDOUT '"EXEC=checkpoint; raw_exit();"'

if test -f "$LOCKFILE"
then
  echo Removing $LOCKFILE >> $LOGFILE
  rm $LOCKFILE
fi
RUN $SERVER $FOREGROUND_OPTION $CRASH_DUMP_OPTION
if test $STATUS -eq 0
then
    LOG "PASSED: DUMPING the database with -D option"
else
    LOG "***FAILED AND ABORTED: DUMPING the database with -D option"
    exit 3
fi

rm -f $DBFILE
START_SERVER $PORT 3000 -R

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < recovck1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tupgrade_recov.sh: Connect failed after backup restore"
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tbfree.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tupgrade_recov.sh: doing tbfree.sql"
    exit 3
fi

LOG "Next we do a checkpoint third time and then kill database server with"
LOG "raw_exit() after which we should get Lost Connection to Server -error."
RUN $ISQL $DSN '"EXEC=checkpoint; raw_exit();"' ERRORS=STDOUT
sleep 5


SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED UPGRADE & RECOVERY TEST (tupgrade_recov.sh)"

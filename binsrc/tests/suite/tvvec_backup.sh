#!/bin/sh
#
#  tvvec_backup.sh
#
#  Driver for backing up a database that contains native vector indexes.
#
#  The backup statement and virtuoso-t +backup-dump both reach walk_db (),
#  which walked every index tree in dbs_trees.  A native vector index is not a
#  B-tree -- its root is a DPF_VEC page with no content map -- so itc_reset ()
#  reached it_new_root_image (), dereferenced NULL, and the process died.  Any
#  database that had ever had a vector index created in it could not be backed
#  up at all:
#
#    backup '<file>'           killed the running server
#    virtuoso-t +backup-dump   died with signal 11 after "Dumping the schema done"
#
#  db_check () takes the same walk and is fixed by the same guard, but it is
#  unreachable today (it demands lt_mode == TM_SNAPSHOT, and nothing in the
#  tree ever assigns lt_mode), so there is nothing here to drive it with.
#
#  Those two are *logical* dumps -- walk_db () emits rows through log_page (),
#  not page images -- and a vector graph has no rows.  It used to be left out
#  and rebuilt from the index's embeddings table after a restore; it is now
#  dumped alongside them as whole-page LOG_VEC_PAGE records that the restore
#  relocates into the rebuilt database.  So this driver does not stop at "did
#  not crash": it replays the dump into a fresh database and asserts the source
#  rows, the embeddings and the graph itself all came back.
#
#  backup_online () is the third surface.  It copies page images (obackup.c),
#  never went through walk_db (), and so never crashed -- but it is the form
#  that carries the graph itself, and its restore is asserted here too, to
#  keep both halves of that distinction honest.
#
#  Sequence:
#    1. build the fixture; backup '<file>'; backup_online
#    2. +backup-dump, which must exit 0
#    3. remove the database file, replay the dump log with +restore-crash-dump,
#       restart and verify (graph restored, no rebuild needed)
#    4. wipe, restore the page-image backup with -r, restart and verify
#       (no rebuild needed, then rebuild anyway)
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2026 OpenLink Software
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

LOGFILE=`pwd`/tvvec_backup.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

case $SERVER in
  *virtuoso*)
	  NO_CP_OPT=+no-checkpoint
	  RESTORE_DUMP_OPTION=+restore-crash-dump
	  ;;
  *)
	  RESTORE_DUMP_OPTION=-R
	  ;;
esac

rm -f $LOGFILE
rm -f vbk_ "vbk_o_#"*.bp

BANNER "STARTED vector index backup test (tvvec_backup.sh)"

#  SHUTDOWN_SERVER only asks; the lock file is what says the process is gone,
#  and every step below reuses the same database directory.
WAIT_FOR_STOP()
{
    n=0
    while test -f "$LOCKFILE" -a $n -lt 60
    do
	sleep 2
	n=`expr $n + 1`
    done
    if test -f "$LOCKFILE"
    then
	LOG "***FAILED: server still holding $LOCKFILE after 120s"
    fi
}

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

START_SERVER $PORT 1000

#
#  1. Fixture, pre-backup assertions, and both backup statements.
#
LOG + run tvvec_backup.sql
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_backup.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_backup.sql"
    exit 3
fi

if test -s vbk_
then
    LOG "PASSED: the backup statement produced vbk_ (`wc -c < vbk_ | tr -d ' '` bytes)"
else
    LOG "***FAILED: the backup statement produced no vbk_ file"
fi

NBP=`ls -1 "vbk_o_#"*.bp 2>/dev/null | wc -l | tr -d ' '`
if test "$NBP" -gt 0
then
    LOG "PASSED: backup_online produced $NBP page-image file(s)"
else
    LOG "***FAILED: backup_online produced no .bp files"
fi

SHUTDOWN_SERVER
WAIT_FOR_STOP

#
#  2. +backup-dump.  It used to die with signal 11; a signal shows up here as
#     an exit status of 128 + n.
#
LOG + $SERVER $FOREGROUND_OPTION $BACKUP_DUMP_OPTION
RUN $SERVER $FOREGROUND_OPTION $BACKUP_DUMP_OPTION
DUMP_STATUS=$STATUS
if test $DUMP_STATUS -eq 0
then
    LOG "PASSED: +backup-dump of a database with vector indexes exited 0"
else
    LOG "***FAILED: +backup-dump exited $DUMP_STATUS (139 = SIGSEGV)"
fi

if grep "Database dump complete" $SRVMSGLOGFILE >/dev/null 2>&1
then
    LOG "PASSED: +backup-dump logged \"Database dump complete\""
else
    LOG "***FAILED: +backup-dump never logged \"Database dump complete\""
fi

#  The graph used to be skipped here and rebuilt from the embeddings after a
#  restore.  It is now dumped as whole-page records that the restore relocates,
#  so this asserts the dump, not the skip.
if grep "page(s) of vector index BK_IDX" $SRVMSGLOGFILE >/dev/null 2>&1
then
    LOG "PASSED: +backup-dump named the vector index whose graph it dumped"
else
    LOG "***FAILED: +backup-dump did not report dumping the vector index graph"
fi

if grep "page(s) of vector index BK_P_IDX" $SRVMSGLOGFILE >/dev/null 2>&1
then
    LOG "PASSED: +backup-dump named the packed vector index whose graph it dumped"
else
    LOG "***FAILED: +backup-dump did not report dumping the packed vector index graph"
fi

#
#  3. Replay the dump.  It went into the transaction log, so the database file
#     is removed and the log rolled forward into a fresh one.
#
if test $DUMP_STATUS -eq 0
then
    rm -f $DBFILE virtuoso.tdb virtuoso.pxa virtuoso-temp.db

    LOG + $SERVER $FOREGROUND_OPTION $RESTORE_DUMP_OPTION
    RUN $SERVER $FOREGROUND_OPTION $RESTORE_DUMP_OPTION
    if test $STATUS -eq 0
    then
	LOG "PASSED: replay of the +backup-dump log exited 0"
    else
	LOG "***FAILED: replay of the +backup-dump log exited $STATUS"
    fi

    START_SERVER $PORT 1000 $NO_CP_OPT

    LOG + run tvvec_backup_verify.sql "(after +backup-dump replay)"
    RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_backup_verify.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
    if test $STATUS -ne 0
    then
	LOG "***FAILED: tvvec_backup_verify.sql after +backup-dump replay"
    fi

    SHUTDOWN_SERVER
    WAIT_FOR_STOP
else
    LOG "***FAILED: skipping the +backup-dump replay, the dump did not complete"
fi

#
#  4. Restore the page-image backup taken in step 1 into a fresh database.
#
rm -f $DBFILE $DBLOGFILE virtuoso.tdb virtuoso.pxa virtuoso-temp.db

LOG + $SERVER $FOREGROUND_OPTION $OBACKUP_REP_OPTION vbk_o_#
RUN $SERVER $FOREGROUND_OPTION $OBACKUP_REP_OPTION "vbk_o_#"
if test $STATUS -eq 0
then
    LOG "PASSED: -r restore of the page-image backup exited 0"
else
    LOG "***FAILED: -r restore of the page-image backup exited $STATUS"
fi

START_SERVER $PORT 1000 $NO_CP_OPT

LOG + run tvvec_backup_pages.sql "(after -r restore)"
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_backup_pages.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***FAILED: tvvec_backup_pages.sql after -r restore"
fi

LOG + run tvvec_backup_verify.sql "(after -r restore)"
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_backup_verify.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***FAILED: tvvec_backup_verify.sql after -r restore"
fi

SHUTDOWN_SERVER
WAIT_FOR_STOP

CHECK_LOG

BANNER "COMPLETED vector index backup test (tvvec_backup.sh)"

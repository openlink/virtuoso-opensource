#!/bin/sh
#
#  tlongany.sh
#
#  LONG ANY (DV_BLOB + the DB.DBA.__ANY class) stores an anified value, so every
#  write must leave exactly one serialization layer behind and every read must
#  give back what went in.  The vectored write path splits that cast in two --
#  ssl_insert_cast (sqlvrun.c) anifies, rd_vec_blob (vecins.c) then clears
#  sqt_class -- and the two halves disagree, so:
#
#    * INSERT of a string stores zero layers (ssl_insert_cast passes a DV_STRING
#      through live, rd_vec_blob stores it raw) and reads back as garbage;
#    * a vectored UPDATE stores two (ssl_insert_cast anifies, then
#      upd_recompose_row casts again with the class still on).
#
#  Roll forward is the other half of the test, and the reason a fix here is not
#  free: log_insert () records rd_values, i.e. the row image, and the async
#  batched replayer (log_replay_entry_async -> get_vec_query ->
#  log_key_ins_del_qr) feeds those images back through an ordinary
#  "INSERT REPLACING ... OPTION (VECTORED)" -- so the insert cast has to be
#  idempotent on its own output.  Stock code is, by accident, because of the
#  DV_STRING pass-through; a fix that removes the pass-through without telling
#  replay corrupts every post-checkpoint row instead.
#
#  Two phases, because a log that has not been checkpointed cannot be produced
#  in one server lifetime:
#
#    1. tlongany.sql inserts and updates a string, an fvector, a vector and an
#       integer, checking __tag and the value round trip for each; then
#       checkpoints and does the whole set again plus a delete, so the second
#       half lives only in the log; then snapshots every row's tag and digest
#       into plain INTEGER/VARCHAR columns that the bug cannot itself corrupt;
#    2. stop uncleanly with raw_exit(), so nothing below the checkpoint reached
#       disk;
#    3. restart, and tlongany_reopen.sql asks two separate questions -- did roll
#       forward reproduce the rows byte for byte (LA vs LA_EXPECT), and are the
#       rows it reproduced actually correct.  Stock code passes the first and
#       fails the second; a fix that forgets replay does the reverse.
#
#  Self-contained: one table, no plugins, no bootstrap.
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

LOGFILE=`pwd`/tlongany.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED LONG ANY insert/update and roll forward test"

#  Generate this run's virtuoso.ini.  The suite-level copy is produced only by
#  testall.sh's prologue and is deleted by clean.sh, while testlib.sh's RUN_TEST
#  copies it into every test directory -- so `make test T=tlongany` after a clean
#  would otherwise hang in START_SERVER waiting for a server that cannot come up.
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

#
#  Phase 1: insert/update every value shape, then leave committed but
#  uncheckpointed rows behind for roll forward to bring back.
#
START_SERVER $PORT 1000

LOG + phase 1: LONG ANY insert and update, then mutate past the checkpoint
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tlongany.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tlongany.sql"
    exit 3
fi

#
#  Phase 2: unclean stop.  raw_exit() does not checkpoint, so everything after
#  the checkpoint above exists only in the transaction log.
#
LOG + stopping the server uncleanly with raw_exit -- no checkpoint
STOP_SERVER
sleep 5

LOG + restarting: the post-checkpoint rows come back through roll forward
START_SERVER $PORT 1000

LOG + phase 2: assert roll forward was faithful and what it replayed is correct
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tlongany_reopen.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tlongany_reopen.sql"
    exit 3
fi

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED LONG ANY insert/update and roll forward test"

#!/bin/sh
#  
#  $Id$
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

LOGFILE=obackup.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

case $SERVER in

  *virtuoso*)
          NO_CP_OPT=+no-checkpoint
	  ;;
  *[Mm]2*)
	  ;;

esac

BANNER "STARTED Online-Backup TEST (obackup.sh)"

rm -f $DBLOGFILE
rm -f $DBFILE
rm -f *.bp
rm -rf nw?
mkdir nw1 nw2 nw3 nw4 nw5

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

SHUTDOWN_SERVER
START_SERVER $PORT 1000 $NO_CP_OPT

RUN $INS $DSN 100000  100
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwdemo_norefs.sql

# Put a vector index into the database before the first backup_online () below.
# backup_online copies page images, so unlike the logical dumps the HNSW graph
# travels verbatim and has to come back from each of the three restores without
# a rebuild.  The fixture checkpoints itself.
LOG + running sql script tvvec_recov
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tvvec_recov.sql
if test $STATUS -ne 0
then
    LOG "***FAILED: obackup.sh: vector index fixture"
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/obackup0.sql

RUN $ISQL $DSN '"EXEC=shutdown();"' ERRORS=STDOUT

START_SERVER $PORT 1000 $NO_CP_OPT

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwdemo_update.sql
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/obackup.sql

LOG "Next we kill the database server with raw_exit()"
LOG "after which we should get Lost Connection to Server -error."
RUN $ISQL $DSN '"EXEC=raw_exit();"' ERRORS=STDOUT
    
rm -f $DBLOGFILE $DBFILE

echo "Staring server with  $OBACKUP_REP_OPTION nwdemo_i_#"
RUN $SERVER $FOREGROUND_OPTION $OBACKUP_REP_OPTION "nwdemo_i_#" $OBACKUP_DIRS_OPTION nw1,nw2,nw3,nw4,nw5

START_SERVER $PORT 1000 $NO_CP_OPT

# After the 1st restore.  Safe to run before obackup1.sql's backup_pages () = 0
# assertion: reading a healthy index writes nothing -- vvec_epoch_reconcile only
# sets in-memory health when the epochs already agree.
LOG + running sql script recovck_vec "(after 1st restore)"
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/recovck_vec.sql
if test $STATUS -ne 0
then
    LOG "***FAILED: obackup.sh: vector index check after 1st restore"
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/obackup1.sql

while test -f "$LOCKFILE" 
do
	sleep 5
done

rm -f $DBLOGFILE $DBFILE

echo "Staring server with  $OBACKUP_REP_OPTION nwdemo_i_#"
RUN $SERVER $FOREGROUND_OPTION $OBACKUP_REP_OPTION "nwdemo_i_#" $OBACKUP_DIRS_OPTION nw1,nw2,nw3,nw4,nw5

START_SERVER $PORT 1000 $NO_CP_OPT

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/obackupck.sql

# After the 2nd restore, and after obackupck.sql so its backup_pages () = 0
# assertion still sees an untouched database.
LOG + running sql script recovck_vec "(after 2nd restore)"
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/recovck_vec.sql
if test $STATUS -ne 0
then
    LOG "***FAILED: obackup.sh: vector index check after 2nd restore"
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/obackup_userck.sql

RUN $ISQL $DSN '"EXEC=shutdown();"' ERRORS=STDOUT

while test -f "$LOCKFILE" 
do
	sleep 5
done

rm -f $DBLOGFILE
rm -f $DBFILE

echo "Staring server with  $OBACKUP_REP_OPTION vvv"
RUN $SERVER $FOREGROUND_OPTION $OBACKUP_REP_OPTION "vvv"

START_SERVER $PORT 1000 $NO_CP_OPT

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/obackup_userck2.sql

# After the 3rd restore, from the separate 'vvv' backup set.
LOG + running sql script recovck_vec "(after 3rd restore)"
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/recovck_vec.sql
if test $STATUS -ne 0
then
    LOG "***FAILED: obackup.sh: vector index check after 3rd restore"
fi

# comment these to enable huge tpcc test.
SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED Online-Backup TEST (obackup.sh)"
exit 1


BANNER "Using tpcc test..."
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/../tpccddk.sql
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/../tpcc.sql

../tpcc $DSN dba dba  i 10
../tpcc $DSN dba dba  r 2

echo "Loading tpcc complete"

echo "Updating tpcc table, stage 0"
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tpcc_update.sql

RUN $ISQL $DSN '"EXEC=shutdown();"' ERRORS=STDOUT

START_SERVER $PORT 1000

echo "Updating tpcc table, stage 1"
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tpcc_update1.sql

RUN $ISQL $DSN '"EXEC=shutdown();"' ERRORS=STDOUT
rm -f $DBLOGFILE
rm -f $DBFILE

echo "Staring server with  $OBACKUP_REP_OPTION tpcc_k_#"
RUN $SERVER $FOREGROUND_OPTION $OBACKUP_REP_OPTION "tpcc_k_#"

START_SERVER $PORT 1000

echo "Checking tpcc database"
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/ob_tpcc_check.sql

echo "Updating and dumping after backup_context_clear()"
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tpcc_update2.sql

RUN $ISQL $DSN '"EXEC=shutdown();"' ERRORS=STDOUT
rm -f $DBLOGFILE
rm -f $DBFILE

echo "Staring server with  $OBACKUP_REP_OPTION tpcc_i_#"
RUN $SERVER $FOREGROUND_OPTION $OBACKUP_REP_OPTION "tpcc_i_#"

START_SERVER $PORT 1000

echo "Checking tpcc database..."
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/ob_tpcc_check.sql

SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED Online-Backup TEST (obackup.sh)"







#!/bin/sh
#
#  $Id$
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2009 OpenLink Software
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

TEST_DIR=`pwd`
LOGFILE=$TEST_DIR/tstriping.output
export LOGFILE RESULT_FILE
. ./test_fn.sh

DS1=$PORT

echo "CREATING CONFIGURATION FOR SERVER"

# MAIN
BANNER "STARTED SERIES OF DATABASE STRIPING TESTS"
NOLITE

DSN=$DS1
STOP_SERVER
rm -f $LOGFILE db-1.seg db-2.seg tmp-1.tdb $DELETEMASK "bkp_1.bp"

# run server & insert 100k rows, do OL backup
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
START_SERVER $DS1 1000

RUN $INS $DSN 100000 1 dba dba
cat >> bkpcmd.sql <<END_BKP
backup_online ('bkp_', 1000000);
END_BKP
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < bkpcmd.sql
STOP_SERVER
rm -f $LOGFILE db-1.seg db-2.seg tmp-1.tdb $DELETEMASK bkpcmd.sql

# start server with stripes & restore backup
case $SERVER in
      *[Mm2]*)
    cat >> witemp.cfg <<END_CFG
;database_file: witemp.db
file_extend: 200

segment 60 pages 1 stripes
stripe tmp-1.tdb
END_CFG
    chmod 644 witemp.cfg
TESTCFGFILE=wi-striping.cfg
;;    
    *virtuoso*)
TESTCFGFILE=virtuoso-striping.ini
;;
esac

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

RUN $SERVER $FOREGROUND_OPTION $OBACKUP_REP_OPTION "bkp_"
if test $STATUS -ne 0
then 
    LOG "***ABORTED: tstriping.sh: backup restore on smaller stripes" 
    exit 3
fi

STOP_SERVER
rm -f $LOGFILE db-1.seg db-2.seg tmp-1.tdb $DELETEMASK "ts_#1.bp" "ts_#2.bp" "bkp_1.bp"
START_SERVER $DS1 1000

RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF < toutdsk.sql 
if test $STATUS -ne 0
then
  LOG "***ABORTED: toutdsk.sql out of disk tests"
else
  LOG "FINISHED toutdsk.sql out of disk tests"
fi
SHUTDOWN_SERVER

START_SERVER $DS1 1000
RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF < toutdskck.sql 
if test $STATUS -ne 0
then
  LOG "***ABORTED: toutdskck.sql out of disk tests"
else
  LOG "FINISHED toutdskck.sql out of disk tests"
fi
SHUTDOWN_SERVER


rm -f $DBFILE db-1.seg db-2.seg tmp-1.tdb
case $SERVER in
      *[Mm2]*)
TESTCFGFILE=witest.cfg
;;    
    *virtuoso*)
TESTCFGFILE=virtuoso-1111.ini
;;
esac

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
RUN $SERVER $FOREGROUND_OPTION $OBACKUP_REP_OPTION "ts_#"
if test $STATUS -eq 0
then
    LOG "PASSED: restoring the database from online backup"
else
    LOG "***FAILED AND ABORTED: restoring the database from online backup"
    exit 3
fi

START_SERVER $DS1 1000

RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF < toutdskck.sql 
if test $STATUS -ne 0
then
  LOG "***ABORTED: toutdsk.sql out of disk tests"
else
  LOG "FINISHED toutdsk.sql out of disk tests"
fi
SHUTDOWN_SERVER

rm -f witemp.cfg db-1.seg db-2.seg tmp-1.tdb "ts_#1.bp" "ts_#2.bp" "bkp_1.bp"

CHECK_LOG
BANNER "COMPLETED DATABASE STRIPING TEST ($0)"

exit 0

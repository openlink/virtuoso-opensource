#!/bin/sh
#  large_db.sh
#
#  $Id: large_db.sh,v 1.3.10.3 2013/01/02 16:14:40 source Exp $
#
#  Large (>2Gb) database file support tests
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

LOGFILE=large_db.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh


skip_5g=0
skip_stripe=0
skip_stripe_5g=0

BANNER "STARTED SERIES OF LARGE_DB TESTS (large_db.sh)"

SHUTDOWN_SERVER
rm -f $DBLOGFILE
rm -f $DBFILE

if [ $skip_5g -eq 0 ]
then

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
START_SERVER $PORT 1000

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/large_db_5g.sql

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/large_db_check.sql

rm *.bp


echo "backup_online ('large_', 50000);" | RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: BACKUP LARGE DB -- large_db.sh"
    exit 1
fi


SHUTDOWN_SERVER

rm -f $DBLOGFILE
rm -f $DBFILE

LOG "Staring server with  $OBACKUP_REP_OPTION large_"
RUN $SERVER $FOREGROUND_OPTION $OBACKUP_REP_OPTION "large_"

START_SERVER $PORT 1000
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/large_db_check.sql

SHUTDOWN_SERVER


fi

if [ $skip_stripe -eq 0 ]
then

LOG "LARGE STRIPING DB TESTS"

rm -f $DBLOGFILE
rm -f $DBFILE

case $SERVER in
    *[Mm2]*)
	cat >> witemp.cfg <<END_CFG
;database_file: witemp.db
file_extend: 200

segment 60 pages 1 stripes
stripe tmp-1.tdb
END_CFG
	chmod 644 witemp.cfg
	TESTCFGFILE=wi-striping-large.cfg
	;;
    *virtuoso*)
	TESTCFGFILE=virtuoso-striping-large.ini
	;;
esac

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

START_SERVER $PORT 1000

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/large_db_3g.sql

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/large_db_3g_check.sql

rm *.bp

echo "backup_online ('large_', 50000);" | RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: BACKUP LARGE (3G) DB -- large_db.sh"
    exit 1
fi

SHUTDOWN_SERVER

rm -f witemp.cfg db-1.seg db-2.seg tmp-1.tdb 

LOG "Staring server with  $OBACKUP_REP_OPTION large_"
RUN $SERVER $FOREGROUND_OPTION $OBACKUP_REP_OPTION "large_"

START_SERVER $PORT 1000
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/large_db_3g_check.sql

SHUTDOWN_SERVER

rm -f witemp.cfg db-1.seg db-2.seg tmp-1.tdb

fi


if [ $skip_stripe_5g -eq 0 ]
then

rm -f $DBLOGFILE
rm -f $DBFILE

case $SERVER in
    *[Mm2]*)
        cat >> witemp.cfg <<END_CFG
;database_file: witemp.db
file_extend: 200

segment 60 pages 1 stripes
stripe tmp-1.tdb
END_CFG
        chmod 644 witemp.cfg
        TESTCFGFILE=wi-striping-1-large.cfg
        ;;
    *virtuoso*)
        TESTCFGFILE=virtuoso-striping-1-large.ini
        ;;
esac


MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

START_SERVER $PORT 1000

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/large_db_5g.sql

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/large_db_check.sql

SHUTDOWN_SERVER

rm -f witemp.cfg db-1.seg db-2.seg tmp-1.tdb

fi

CHECK_LOG
BANNER "COMPLETED LARGE DB TESTS (large_db.sh)"

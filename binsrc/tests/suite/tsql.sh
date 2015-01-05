#!/bin/sh
#  tsql.sh
#
#  $Id: tsql.sh,v 1.55.4.8.4.16 2013/01/02 16:15:27 source Exp $
#
#  SQL conformance tests
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

LOGFILE=tsql.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh
BANNER "STARTED SERIES OF SQL TESTS (tsql.sh)"

SHUTDOWN_SERVER
rm -f $DBLOGFILE
rm -f $DBFILE
cp $VIRTUOSO_TEST/words.esp .

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE


START_SERVER $PORT 1000
RUN $INS $DSN 100000  100



LOG + running sql script tgroupc
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tgroupc.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tgroupc.sql"
    exit 1
fi


LOG + running sql script tclrec
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tclrec.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tcldfg.sql"
    exit 1
fi

LOG + running sql script tcptrb3
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tcptrb3.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: cpt rb  -- tcptrb3.sql"
    exit 1
fi


LOG + running sql script tcptrb
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tcptrb.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: cpt rb  -- tcptrb.sql"
    exit 1
fi

STOP_SERVER

START_SERVER $PORT 1000

LOG + running sql script tcptrb2
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tcptrb2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: cpt rb -- tcptrb2.sql"
    exit 1
fi




START_SERVER $PORT 1000

LOG + running sql script twords
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/twords.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: Wordtest -- twords.sql"
    exit 1
fi

LOG + running sql script tnwords_create
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tnwords_create.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: nvarchar Wordtest -- tnwords_create.sql"
    exit 1
fi


LOG + running sql script tnwords
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tnwords.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: nvarchar Wordtest -- tnwords.sql"
    exit 1
fi

# Check that blob is dumped out identically as it was inserted into table:
# Note that in Windows NT isql seems to add the CR's there before every
# NL (although nobody asked it to do that!), both under bash GNUWIN32
# and ordinary COMMAND.COM. So the resulting words.out file will
# be 921167 bytes long, which is 86061 bytes (count of lines) longer
# than the original 835106. However, with current settings the diff
# will claim the files identical even without any special options.
# (Probably because text!=binary in mount settings?)
# This has been now solved with a new option BINARY_OUTPUT=ON,
# which will switch stdout to _O_BINARY mode in Windows NT.
# On Unix platforms it is NO-OP, so you don't need to worry about it.
#

RUN date
$ISQL $DSN VERBOSE=OFF BANNER=OFF PROMPT=OFF TRAILING_NEWLINES=0 BINARY_OUTPUT=ON BLOBS=ON EXEC="select wholefile from wordcounts" > words.out
if test $? -eq 0
then
    LOG "COMPLETED: Dumping of wholefile blob column from words"
else
    LOG "***ABORTED: Dumping of wholefile blob column from words"
    exit 1
fi
RUN date
RUN_DIFF $VIRTUOSO_TEST/words.esp words.out worddiff.out
RUN date


LOG + running sql script tbitmap
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tbitmap.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tbitmap.sql"
    exit 1
fi

LOG + running sql script tac
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tac.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: autocompact tac.sql "
    exit 1
fi


RUN $ISQL $DSN '"EXEC=drop table T1;"' ERRORS=STDOUT
RUN $INS $DSN 10000  100
LOG + running sql script tinxint
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tinxint.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tinxint.sql"
    exit 1
fi

RUN $INS $DSN 10000  100
LOG + running sql script tinxintbm
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tinxintbm.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tinxintbm.sql"
    exit 1
fi


LOG + running sql script taq
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/taq.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: taq.sql"
    exit 1
fi



LOG + running sql script tcast
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tcast.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tcast.sql"
    exit 1
fi



RUN $INS $DSN 20 100
LOG + running sql script tjoin
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tjoin.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tjoin.sql"
    exit 1
fi

LOG + running sql script tjoin2
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tjoin2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tjoin2.sql"
    exit 1
fi


LOG + running sql script tiri
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tiri.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tiri.sql"
    exit 1
fi



LOG + running sql script tany
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tany.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tany.sql"
    exit 1
fi


LOG + running sql script tany2
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tany2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tany2.sql"
    exit 1
fi


LOG + running sql script ttrigt
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/ttrigt.sql
LOG + running sql script ttrigtrig
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/ttrigtrig.sql
LOG + running sql script ttrig1
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/ttrig1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: ttrig1.sql"
    exit 1
fi

LOG + running sql script ttrig2
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/ttrig2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: ttrig2.sql"
    exit 1
fi



RUN date

LOG + running sql script tgroup
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tgroup.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tgroup.sql"
    exit 1
fi


LOG + running sql script tview
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tview.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tview.sql"
    exit 1
fi

#LOG + running sql script tpview
#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tpview.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tpview.sql"
    exit 1
fi


LOG + running sql script tdatefun
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tdatefun.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tdatefun.sql"
    exit 1
fi

LOG + running sql script tdate
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tdate.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tdate.sql"
    exit 1
fi

# XXX
LOG + running sql script tpkopt
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tpkopt.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tpkopt.sql"
    exit 1
fi

LOG + running sql script tinx
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tinx.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tinx.sql"
    exit 1
fi

# XXX
LOG + running sql script ttrans
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/ttrans.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: ttrans.sql"
    exit 1
fi

LOG + running sql script tclins
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tclins.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tclins.sql"
    exit 1
fi


RUN $ISQL $DSN '"EXEC=drop table T1;"' ERRORS=STDOUT
RUN $INS $DSN 100 20


LOG + running sql script tcljoin
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tcljoin.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tcljoin.sql"
    exit 1
fi



LOG + running sql script tcldt
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tcldt.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tcldt.sql"
    exit 1
fi

LOG + running sql script tcldfg
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tcldfg.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tcldfg.sql"
    exit 1
fi


LOG + running sql script tcllock
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tcllock.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tcllock.sql"
    exit 1
fi


LOG + running sql script tanytime
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tanytime.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tanytime.sql"
    exit 1
fi


LOG + running sql script tclparts
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tclparts.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tclparts.sql"
    exit 1
fi

LOG + running sql script tclcast
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tclcast.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tclcast.sql"
    exit 1
fi


RUN $ISQL $DSN '"EXEC=drop table T1;"' ERRORS=STDOUT
RUN $INS $DSN 200000 100

RUN_BG_CHECK()
{
    _script=$1
    _timeout=$2
    ECHO "RUNNING $_script"
    RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $_script &
    ECHO "WAITING $_script for $_timeout secs"
    sleep $_timeout
    ECHO "DONE WAITING $_script"
    RUN $ISQL $DSN '"EXEC=checkpoint;"' ERRORS=STDOUT
    ECHO "WAITNING $_script to terminate"
    jobs | tee LOGFILE
    wait %2
    ECHO "DONE $_script"
}

#RUN_BG_CHECK $VIRTUOSO_TEST/selt1.sql 12
#RUN_BG_CHECK $VIRTUOSO_TEST/selt2.sql 1
#RUN_BG_CHECK $VIRTUOSO_TEST/selt3.sql 12
#RUN_BG_CHECK $VIRTUOSO_TEST/selt4.sql 15
#RUN_BG_CHECK $VIRTUOSO_TEST/selt5.sql 21

SHUTDOWN_SERVER

if [ "x$SQLOPTIMIZE" = "x" ]
then
    rm -f $CFGFILE
    mv BACK_$CFGFILE $CFGFILE
fi

CHECK_LOG
BANNER "COMPLETED SERIES OF SQL TESTS (tsql.sh)"

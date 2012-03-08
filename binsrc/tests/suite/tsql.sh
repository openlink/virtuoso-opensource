#!/bin/sh
#  tsql.sh
#
#  $Id$
#
#  SQL conformance tests
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2012 OpenLink Software
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
. ./test_fn.sh

BANNER "STARTED SERIES OF SQL TESTS (tsql.sh)"

SHUTDOWN_SERVER
rm -f $DBLOGFILE
rm -f $DBFILE
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE


START_SERVER $PORT 1000
RUN $INS $DSN 100000  100
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tcptrb3.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: cpt rb  -- tcptrb3.sql"
    exit 1
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tcptrb.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: cpt rb  -- tcptrb.sql"
    exit 1
fi
RUN $ISQL $DSN '"EXEC=raw_exit();"' ERRORS=STDOUT


START_SERVER $PORT 1000

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tcptrb2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: cpt rb -- tcptrb2.sql"
    exit 1
fi




START_SERVER $PORT 1000

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < twords.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: Wordtest -- twords.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tnwords_create.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: nvarchar Wordtest -- tnwords_create.sql"
    exit 1
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tnwords.sql
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
RUN_DIFF words.esp words.out worddiff.out
RUN date


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tbitmap.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tbitmap.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tac.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: autocompact tac.sql "
    exit 1
fi

RUN $INS $DSN 10000  100
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tinxint.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tinxint.sql"
    exit 1
fi

RUN $INS $DSN 10000  100
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tinxintbm.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tinxintbm.sql"
    exit 1
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < taq.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: taq.sql"
    exit 1
fi



RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tcast.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tcast.sql"
    exit 1
fi



RUN $INS $DSN 20 100
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tjoin.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tjoin.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tjoin2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tjoin2.sql"
    exit 1
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tiri.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tiri.sql"
    exit 1
fi



RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tany.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tany.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tany2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tany2.sql"
    exit 1
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < ttrigt.sql
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < ttrigtrig.sql
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < ttrig1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: ttrig1.sql"
    exit 1
fi
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < ttrig2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: ttrig2.sql"
    exit 1
fi



RUN date
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tgroup.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tgroup.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tview.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tview.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tpview.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tpview.sql"
    exit 1
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tdatefun.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tdatefun.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tdate.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tdate.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tpkopt.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tpkopt.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tinx.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tinx.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < ttrans.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: ttrans.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tclins.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tclins.sql"
    exit 1
fi


RUN $ISQL $DSN '"EXEC=drop table T1;"' ERRORS=STDOUT
RUN $INS $DSN 100 20


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tcljoin.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tcljoin.sql"
    exit 1
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tcldt.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tcldt.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tcldfg.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tcldfg.sql"
    exit 1
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tcllock.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tcllock.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tanytime.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tanytime.sql"
    exit 1
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tclparts.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tclparts.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tclcast.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tclcast.sql"
    exit 1
fi


RUN $ISQL $DS1 '"EXEC=drop table T1;"' ERRORS=STDOUT
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

#RUN_BG_CHECK selt1.sql 12
#RUN_BG_CHECK selt2.sql 1
#RUN_BG_CHECK selt3.sql 12
#RUN_BG_CHECK selt4.sql 15
#RUN_BG_CHECK selt5.sql 21

SHUTDOWN_SERVER

if [ "x$SQLOPTIMIZE" = "x" ]
then
    rm -f $CFGFILE
    mv BACK_$CFGFILE $CFGFILE
fi

CHECK_LOG
BANNER "COMPLETED SERIES OF SQL TESTS (tsql.sh)"

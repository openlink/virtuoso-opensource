#!/bin/sh
#  tsql2.sh
#
#  $Id: tsql2.sh,v 1.14.4.1.4.9 2013/01/02 16:15:28 source Exp $
#
#  SQL conformance tests
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2019 OpenLink Software
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

SCROLL=${SCROLL-$VIRTUOSO_TEST/../scroll}
GETDATA=${GETDATA-$VIRTUOSO_TEST/../getdata}
LOGFILE=tsql2.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh
cp $VIRTUOSO_TEST/spanish.coll .
cp $VIRTUOSO_TEST/words.esp .

BANNER "STARTED SERIES OF SQL TESTS (tsql2.sh)"

rm -f $DBLOGFILE
rm -f $DBFILE
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

SHUTDOWN_SERVER
START_SERVER $PORT 1000

RUN $INS $DSN 20 100

LOG + running sql script tschema1
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tschema1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tschema1.sql"
    exit 1
fi
# XXX: under tables not supported
#LOG + running sql script tunder1
#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tunder1.sql
#if test $STATUS -ne 0
#then
#    LOG "***ABORTED: tunder1.sql"
#    exit 1
#fi

#LOG + running sql script tunder2
#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tunder2.sql
#if test $STATUS -ne 0
#then
#    LOG "***ABORTED: tunder2.sql"
#    exit 1
#fi

#LOG + running sql script tbak
#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tbak.sql
#if test $STATUS -ne 0
#then
#    LOG "***ABORTED: tbak.sql"
#    exit 1
#fi


RUN date

LOG + running sql script tbin
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tbin.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tbin.sql"
    exit 1
fi

$VIRTUOSO_TEST/../blobs $PORT

LOG + running sql script terror
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/terror.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: terror.sql"
    exit 1
fi

RUN date

#LOG + running sql script tobject
#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tobject.sql
#if test $STATUS -ne 0
#then
#    LOG "***ABORTED: tobject.sql"
#    exit 1
#fi

LOG + running sql script tfref
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tfref.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tfref.sql"
    exit 1
fi

LOG + running sql script tlock
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tlock.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tlock.sql"
    exit 1
fi

RUN date

LOG + running sql script tupdate
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tupdate.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tupdate.sql"
    exit 1
fi

RUN date


LOG + running sql script tdelete
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tdelete.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tdelete.sql"
    exit 1
fi

# collation not supported in v7
#LOG + running sql script tcoll
#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tcoll.sql
#if test $STATUS -ne 0
#then
#    LOG "***ABORTED: tcoll.sql"
#    exit 1
#fi

LOG + running sql script tschema2
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tschema2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tschema2.sql"
    exit 1
fi

# LOG + running sql script tschema3
#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tschema3.sql
# if test $STATUS -ne 0
# then
#    LOG "***ABORTED: tschema3.sql"
#     exit 1
# fi

LOG + running sql script tschema4
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tschema4.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tschema4.sql"
    exit 1
fi

RUN $SCROLL $DSN
if test $STATUS -ne 0
then
    LOG "***ABORTED: tsql2.sh: scroll"
    exit 1
fi


#RUN $GETDATA $DSN dba dba
if test $STATUS -ne 0
then
    LOG "***ABORTED: tsql2.sh: getdata"
    #exit 1
fi


# XXX
#LOG + running sql script tbunion
#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tbunion.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: TOP & BEST & UNION tests -- tbunion.sql"
    exit 1
fi

LOG + running sql script tinlist
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tinlist.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: in list predicate -- tinlist.sql"
    exit 1
fi




#LOG + running sql script txml
#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/txml.sql
#if test $STATUS -ne 0
#then
#    LOG "***ABORTED: XMLtest -- txml.sql"
#    exit 1
#fi



# suite for bug #1092 - commented out for now

SHUTDOWN_SERVER

if [ "x$SQLOPTIMIZE" = "x" ]
then
    rm -f $CFGFILE
    mv BACK_$CFGFILE $CFGFILE
fi

CHECK_LOG
BANNER "COMPLETED SERIES OF SQL TESTS (tsql2.sh)"

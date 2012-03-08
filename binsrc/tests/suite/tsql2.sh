#!/bin/sh
#  tsql2.sh
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

SCROLL=${SCROLL-../scroll}
GETDATA=${GETDATA-../getdata}
LOGFILE=tsql2.output
export LOGFILE
. ./test_fn.sh

BANNER "STARTED SERIES OF SQL TESTS (tsql2.sh)"

rm -f $DBLOGFILE
rm -f $DBFILE
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

SHUTDOWN_SERVER
START_SERVER $PORT 1000

RUN $INS $DSN 20 100
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tschema1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tschema1.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tunder1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tunder1.sql"
    exit 1
fi
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tunder2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tunder2.sql"
    exit 1
fi

#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tbak.sql
#if test $STATUS -ne 0
#then
#    LOG "***ABORTED: tbak.sql"
#    exit 1
#fi


RUN date

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tbin.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tbin.sql"
    exit 1
fi

../blobs $PORT

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < terror.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: terror.sql"
    exit 1
fi

RUN date

#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tobject.sql
#if test $STATUS -ne 0
#then
#    LOG "***ABORTED: tobject.sql"
#    exit 1
#fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tfref.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tfref.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tlock.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tlock.sql"
    exit 1
fi

RUN date

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tupdate.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tupdate.sql"
    exit 1
fi

RUN date


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tdelete.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tdelete.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tcoll.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tcoll.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tschema2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tschema2.sql"
    exit 1
fi

# RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tschema3.sql
# if test $STATUS -ne 0
# then
#    LOG "***ABORTED: tschema3.sql"
#     exit 1
# fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tschema4.sql
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


RUN $GETDATA $DSN dba dba
if test $STATUS -ne 0
then
    LOG "***ABORTED: tsql2.sh: getdata"
    #exit 1
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tbunion.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: TOP & BEST & UNION tests -- tbunion.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tinlist.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: in list predicate -- tinlist.sql"
    exit 1
fi




#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < txml.sql
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

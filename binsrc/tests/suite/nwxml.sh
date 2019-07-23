#!/bin/sh
#
#  $Id: nwxml.sh,v 1.20.2.2.4.4 2013/01/02 16:14:45 source Exp $
#
#  XML tests
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

LOGFILE=nwxml.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh
cp -r $VIRTUOSO_TEST/docsrc .

BANNER "STARTED NorthWind XML TEST (nwxml.sh)"

SHUTDOWN_SERVER
cp "${HOME}/binsrc/samples/demo/noise.txt" .
rm -f $DELETEMASK
MAKECFG_FILE_WITH_HTTP $TESTCFGFILE $PORT $HTTPPORT $CFGFILE
START_SERVER $PORT 1000

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tlogft1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: nwxml.sh: free text log check init"
    exit 3
fi

STOP_SERVER
START_SERVER $PORT 1000

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tlogft2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: nwxml.sh: free text log check tests"
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwdemo.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: nwxml.sh: loading northwind data"
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwxml.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: nwxml.sh: nwxml.sql functions "
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwxmla.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: nwxml.sh: nwxmla.sql functions "
    exit 3
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwxml2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: nwxml.sh: nwxml2.sql functions "
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwxml3.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: nwxml.sh: nwxml3.sql functions "
    exit 3
fi

#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwxml3a.sql
#if test $STATUS -ne 0
#then
#    LOG "***ABORTED: nwxml.sh: XPER and LONG XML log check init"
#    exit 3
#fi

STOP_SERVER
START_SERVER $PORT 1000

#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwxml3b.sql
#if test $STATUS -ne 0
#then
#    LOG "***ABORTED: nwxml.sh: XPER and LONG XML log check tests"
#    exit 3
#fi

#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwxml3c.sql
#if test $STATUS -ne 0
#then
#    LOG "***ABORTED: nwxml.sh: XPER text search on attributes"
#    exit 3
#fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwxml4.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: nwxml.sh: nwxml4.sql functions "
    exit 3
fi

# only if the SQL optimizer is on
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwxmlo.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: nwxml.sh: nwxmlo.sql functions "
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwxmltype3.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: nwxml.sh: nwxmltype3.sql functions "
    exit 3
fi

#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwxmltype3a.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: nwxml.sh: XMLType log check init"
    exit 3
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwxmlb.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: nwxml.sh: nwxmlb.sql functions "
    exit 3
fi

STOP_SERVER
START_SERVER $PORT 1000

#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwxmltype3b.sql
#if test $STATUS -ne 0
#then
#    LOG "***ABORTED: nwxml.sh: XMLType log check tests"
#    exit 3
#fi

#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/nwxmltype3c.sql
#if test $STATUS -ne 0
#then
#    LOG "***ABORTED: nwxml.sh: XMLType text search on attributes"
#    exit 3
#fi


SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED NorthWind XML TEST (nwxml.sh)"

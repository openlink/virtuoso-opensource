#!/bin/sh
#  tsql3.sh
#
#  $Id$
#
#  SQL conformance tests
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2014 OpenLink Software
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

LOGFILE=tsql3.output
export LOGFILE
. ./test_fn.sh

BANNER "STARTED SERIES OF SQL TESTS (tsql3.sh)"

rm -f $DBLOGFILE
rm -f $DBFILE
rm -f noise.txt
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

SHUTDOWN_SERVER
START_SERVER $PORT 1000

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tnull.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tnull.sql"
    exit 1
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tarray.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tarray.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tarith.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tarith.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tnumt.sql
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tnum.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tnum.sql"
    exit 1
fi

RUN date

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < testgz.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: Compression test -- testgz.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'table=TTEST1' 'idtype=integer' 'haspk=yes' < testtext.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: freetext test integer primary key -- testtext.sql"
    exit 1
fi
if [ "z$CLUSTER" != "zyes" ] # explicit with key option is required for partitioned table
then
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'table=TTEST2' 'idtype=integer' 'haspk=no' < testtext.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: freetext test integer -- testtext.sql"
    exit 1
fi
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'table=TTEST3' 'idtype=varchar' 'haspk=yes' < testtext.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: freetext test varchar primary key -- testtext.sql"
    exit 1
fi
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tftt.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: freetext triggers test -- tftt.sql"
    exit 1
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tescape.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: C escaping tests -- tescape.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < texecute.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: EXEC & company tests -- texecute.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tidxksize.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: Index key sizes test -- tidxksize.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tfk.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: FK tests -- tfk.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tunq.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: UNIQUE constraint tests -- tunq.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tcheck.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: CHECK constraint tests -- tcheck.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tft_offband.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: freetext offband data tests -- tft_offband.sql"
    exit 1
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tplmodule.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: PL modules tests -- tplmodule.sql"
    exit 1
fi

# disabled 
#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tldap.sql
#if test $STATUS -ne 0
#then
#    LOG "***ABORTED: LDAP tests -- tldap.sql"
#    exit 1
#fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tchars.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: Varchar restrictions test -- tchars.sql"
    exit 1
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tstrses.sql 
if test $STATUS -ne 0
then
    LOG "***ABORTED: Limited string session test -- tstrses.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < trdfinf.sql 
if test $STATUS -ne 0
then
    LOG "***ABORTED: rdf inference -- trdfinf.sql"
    exit 1
fi


RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < trdfinfifp.sql 
if test $STATUS -ne 0
then
    LOG "***ABORTED: rdf inference -- trdfinfifp.sql"
    exit 1
fi

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < ttrans2.sql 
if test $STATUS -ne 0
then
    LOG "***ABORTED: rdf inference -- ttrans2.sql"
    exit 1
fi



# suite for bug #1092 - commented out for now
if [ "x$SQLOPTIMIZE" = "x" ]
then
    cat $CFGFILE >> $LOGFILE
    RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u follow_std=1 < tviewqual.sql
    if test $STATUS -ne 0
    then
	LOG "***ABORTED: view qualifier expansion (off part)"
	exit 1
    fi
    SHUTDOWN_SERVER

    rm -f BACK_$CFGFILE
    mv $CFGFILE BACK_$CFGFILE
    cat BACK_$CFGFILE | sed -e "s/ADD_VIEWS/1/g" > $CFGFILE
    cat $CFGFILE >> $LOGFILE
    START_SERVER $PORT 1000

    RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u follow_std=0 < tviewqual.sql
    if test $STATUS -ne 0
    then
	LOG "***ABORTED: view qualifier expansion (on part)"
	exit 1
    fi
fi

SHUTDOWN_SERVER

if [ "x$SQLOPTIMIZE" = "x" ]
then
    rm -f $CFGFILE
    mv BACK_$CFGFILE $CFGFILE
fi

rm -f test_file

CHECK_LOG
BANNER "COMPLETED SERIES OF SQL TESTS (tsql3.sh)"

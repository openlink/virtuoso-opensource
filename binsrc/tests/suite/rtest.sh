#!/bin/sh
#
#  rtest.sh
#
#  $Id$
#
#  SQL conformance tests
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2017 OpenLink Software
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

LOGFILE=rtest.output
export LOGFILE
. ./test_fn.sh



DS1=$PORT
DS2=`expr $PORT + 1`




BANNER "STARTED SERIES OF REMOTE SQL TESTS (rtest.sh)"

LOG "Remote database access test"


grep VDB ident.txt
if test $? -ne 0
then 
    echo "The present build is not set up for VDB."
    exit
fi

DSN = $DS1
STOP_SERVER
DSN = $DS2
STOP_SERVER



#
#  Create temp directories for the two remote databases
#
rm -rf remote1
mkdir remote1
cd remote1
MAKECFG_FILE ../$TESTCFGFILE $DS1 $CFGFILE
ln -s ../words.esp words.esp
START_SERVER $DS1 1000
cd ..

rm -rf remote2
mkdir remote2
cd remote2
MAKECFG_FILE ../$TESTCFGFILE $DS2 $CFGFILE
ln -s ../words.esp words.esp
START_SERVER $DS2 1000
cd ..

LOG "Loading base tables"

RUN $INS $DS1 1000 100 dba dba usedt
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: loading base tables DS1"
    exit 1
fi

RUN $INS $DS2 1000 3000 dba dba usedt
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: loading base tables DS2"
    exit 1
fi

RUN $BLOBS $DS1

RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < rtest1-1.sql

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$DS1" "LOCALPORT=$DS2" < rtest1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: Schema test"
    exit 1
fi

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < rtest2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rtest2"
    exit 1
fi

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < rtesta.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rtesta"
    exit 1
fi


RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < rpjoin.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rpjoin"
    exit 1
fi


RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tnumt.sql
RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tnumt.sql
RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$DS1" < tnumr.sql


echo "VDB BLOBS\n";
../blobs $DS2 R1 R1

RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < ttrigt.sql
RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$DS1" < ttrigr.sql
RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < ttrigtrig.sql
RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < ttrig1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: ttrig1"
    exit 1
fi

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$DS1" < rtest3.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rtest3"
    exit 1
fi

DSN = $DS1
SHUTDOWN_SERVER

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < rtest4.sql
if test $STATUS -ne 0
then
  LOG "***ABORTED: rtest.sh: rtest4"
  exit 1
fi

cd remote1
START_SERVER $DS1 1000
cd ..

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < rtest5.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rtest5"
    exit 1
fi

RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < rls_create.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rls_create"
    exit 1
fi

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$DS1" < rls_attach.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rls_attach"
    exit 1
fi

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < rls.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rls"
    exit 1
fi


RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tnwords_create.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: tnwords_create"
    exit 1
fi

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$DS1" < tnwords_remote.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: tnwords_remote"
    exit 1
fi

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < rproc1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rproc1"
    exit 1
fi

RUN $ISQL $DS1 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "LOCALPORT=$DS2" "DO_RPROC=YES" < rproc2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rproc2"
    exit 1
fi

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$DS1" < rexecute.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rexecute"
    exit 1
fi

RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$DS1" "LOCALPORT=$DS2" < pass.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: pass.sql"
    exit 1
fi

LOG "Inserted 3000 rows through VDB."
RUN $INS $DS2 4000 1100 R1 R1 dba dba usedt
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: Inserted 3000 rows through VDB"
    exit 1
fi

# NOT AVAILABLE
# echo VDB Read timing tests
# ../batread $DS2 100 2100 1 R1 R1 >> ../vdt/rtest.log
# ../ranread $DS2 100 3100 10 R1 R1  >> ../vdt/rtest.log
# NOT AVAILABLE

LOG "Scrolling through the VDB."
RUN $SCROLL $DS2 100 R1 R1
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: scroll"
    exit 1
fi



RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tbreakup.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rtbreakup.sql"
    exit 1
fi


RUN $ISQL $DS2 PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < rtrxdead.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rtrxdead.sql"
    exit 1
fi


LOG "Shutdown databases"

DSN=$DS1
SHUTDOWN_SERVER
DSN=$DS2
SHUTDOWN_SERVER



#
#  Cleanup
#
# rm -rf remote1 remote2

CHECK_LOG
BANNER "COMPLETED SERIES OF REMOTE SQL TESTS (rtest.sh)"


#!/bin/sh
#
#  rtest.sh
#
#  $Id: rtest.sh,v 1.37.4.3.4.11 2013/01/02 16:14:54 source Exp $
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

LOGFILE=rtest.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

LOCAL=$PORT
GENERATE_PORTS 1
REMOTE=$GENERATED_PORT
if [ $LOCAL -eq $REMOTE ]
then
  REMOTE=`expr $LOCAL + 1`
fi

BANNER "STARTED SERIES OF REMOTE SQL TESTS (rtest.sh)"

LOG "Remote database access test"

if [ "$VIRTUOSO_VDB" = "0" ]
then 
    echo "The present build is not set up for VDB."
    exit
fi

STOP_SERVER $REMOTE
STOP_SERVER $LOCAL

#
#  Create temp directories for the two remote databases
#
rm -rf remote
mkdir remote
cd remote
MAKECFG_FILE $VIRTUOSO_TEST/$TESTCFGFILE $REMOTE $CFGFILE
ln -s $VIRTUOSO_TEST/words.esp words.esp
SERVER_TITLE="REMOTE"
START_SERVER $REMOTE 1000
cd ..

MAKECFG_FILE $VIRTUOSO_TEST/$TESTCFGFILE $LOCAL $CFGFILE
ln -s $VIRTUOSO_TEST/words.esp words.esp
SERVER_TITLE="LOCAL"
START_SERVER $LOCAL 1000

LOG "Loading base tables"

RUN $INS $REMOTE 1000 100 dba dba usedt
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: loading base tables REMOTE"
    exit 1
fi

RUN $INS $LOCAL 1000 3000 dba dba usedt
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: loading base tables LOCAL"
    exit 1
fi

RUN $BLOBS $REMOTE
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: Can't populate blobs on remote."
    exit 1
fi

CHECKPOINT_SERVER $REMOTE
CHECKPOINT_SERVER $LOCAL

LOG + running sql script rtest1-1.sql
RUN $ISQL $REMOTE PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/rtest1-1.sql
if [ $STATUS -ne 0 ]
then
    LOG "***ABORTED: rtest1-1.sql"
    exit 1
fi

LOG + running sql script rtest1.sql
RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$REMOTE" "LOCALPORT=$LOCAL" < $VIRTUOSO_TEST/rtest1.sql
if [ $STATUS -ne 0 ]
then
    LOG "***ABORTED: rtest.sh: Schema test"
    exit 1
fi

CHECKPOINT_SERVER $REMOTE
CHECKPOINT_SERVER $LOCAL

LOG + running sql script rtest0.sql
RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/rtest0.sql
if [ $STATUS -ne 0 ]
then
    LOG "***ABORTED: rtest.sh: rtest0"
    exit 1
fi

LOG + running sql script rtest2.sql
RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/rtest2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rtest2"
    exit 1
fi

#LOG + running sql script rtesta.sql
#RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/rtesta.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rtesta"
    exit 1
fi


#LOG + running sql script rpjoin.sql
#RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/rpjoin.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rpjoin"
    exit 1
fi


LOG + running sql script tnumt.sql on remote
RUN $ISQL $REMOTE PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tnumt.sql
LOG + running sql script tnumt.sql on local
RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tnumt.sql
LOG + running sql script tnumr.sql
RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$REMOTE" < $VIRTUOSO_TEST/tnumr.sql


echo "VDB BLOBS\n";
RUN $BLOBS $LOCAL R1 R1
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: Can't populate blobs on local."
    exit 1
fi

LOG + running sql script ttrigt.sql on remote
RUN $ISQL $REMOTE PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/ttrigt.sql
LOG + running sql script ttrigt.sql on local
RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$REMOTE" < $VIRTUOSO_TEST/ttrigr.sql
LOG + running sql script ttrigtrig.sql
RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/ttrigtrig.sql
LOG + running sql script ttrig1.sql
#RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/ttrig1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: ttrig1"
    exit 1
fi

LOG + running sql script rtest3.sql
RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$REMOTE" < $VIRTUOSO_TEST/rtest3.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rtest3"
    exit 1
fi

SHUTDOWN_SERVER $REMOTE

LOG + running sql script rtest4.sql
RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/rtest4.sql
if test $STATUS -ne 0
then
  LOG "***ABORTED: rtest.sh: rtest4"
  exit 1
fi

cd remote
SERVER_TITLE="REMOTE (restarted)"
START_SERVER $REMOTE 1000
cd ..

LOG + running sql script rtest5.sql
RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/rtest5.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rtest5"
    exit 1
fi

LOG + running sql script rls_create.sql
RUN $ISQL $REMOTE PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/rls_create.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rls_create"
    exit 1
fi

LOG + running sql script rls_attach.sql
RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$REMOTE" < $VIRTUOSO_TEST/rls_attach.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rls_attach"
    exit 1
fi

LOG + running sql script rls.sql
RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/rls.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rls"
    exit 1
fi


LOG + running sql script tnwords_create.sql
RUN $ISQL $REMOTE PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tnwords_create.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: tnwords_create"
    exit 1
fi

LOG + running sql script tnwords_remote.sql
RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$REMOTE" < $VIRTUOSO_TEST/tnwords_remote.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: tnwords_remote"
    exit 1
fi

#LOG + running sql script rproc1.sql
#RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/rproc1.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rproc1"
    exit 1
fi

#LOG + running sql script rproc2.sql
#RUN $ISQL $REMOTE PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "LOCALPORT=$LOCAL" "DO_RPROC=YES" < $VIRTUOSO_TEST/rproc2.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rproc2"
    exit 1
fi

#LOG + running sql script rexecute.sql
#RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$REMOTE" < $VIRTUOSO_TEST/rexecute.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rexecute"
    exit 1
fi

LOG + running sql script pass.sql
RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u "PORT=$REMOTE" "LOCALPORT=$LOCAL" < $VIRTUOSO_TEST/pass.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: pass.sql"
    exit 1
fi

LOG "Inserted 3000 rows through VDB."
RUN $INS $LOCAL 4000 1100 R1 R1 dba dba usedt
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: Inserted 3000 rows through VDB"
    exit 1
fi

# NOT AVAILABLE
# echo VDB Read timing tests
# $VIRTUOSO_TEST/../batread $LOCAL 100 2100 1 R1 R1 >> $VIRTUOSO_TEST/../vdt/rtest.log
# $VIRTUOSO_TEST/../ranread $LOCAL 100 3100 10 R1 R1  >> $VIRTUOSO_TEST/../vdt/rtest.log
# NOT AVAILABLE

LOG "Scrolling through the VDB."
RUN $SCROLL $LOCAL 100 R1 R1
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: scroll"
    exit 1
fi



LOG + running sql script tbreakup.sql
RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tbreakup.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rtbreakup.sql"
    exit 1
fi


#LOG + running sql script rtrxdead.sql
#RUN $ISQL $LOCAL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/rtrxdead.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: rtest.sh: rtrxdead.sql"
    exit 1
fi


LOG "Shutdown databases"

SHUTDOWN_SERVER $REMOTE
SHUTDOWN_SERVER $LOCAL

#
#  Cleanup
#
# rm -rf remote 

CHECK_LOG
BANNER "COMPLETED SERIES OF REMOTE SQL TESTS (rtest.sh)"


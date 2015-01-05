#!/bin/sh
#  
#  $Id$
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

# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL


TEST_DIR=`pwd`
LOGFILE=$TEST_DIR/bpeltpcc.output
SUITE=$HOME/binsrc/tests/suite
TPCC=$HOME/binsrc/tests/tpcc

# Using virtuoso 
SERVER=virtuoso-t
CFGFILE=virtuoso.ini
DBFILE=virtuoso.db
DBLOGFILE=virtuoso.trx
DELETEMASK="virtuoso.lck $DBLOGFILE $DBFILE virtuoso.tdb virtuoso.ttr"
SRVMSGLOGFILE="virtuoso.log"
TESTCFGFILE=virtuoso-1111.ini
BACKUP_DUMP_OPTION=+backup-dump
CRASH_DUMP_OPTION=+crash-dump
FOREGROUND_OPTION=+foreground
LOCKFILE=virtuoso.lck
export FOREGROUND_OPTION LOCKFILE
export CFGFILE DBFILE DBLOGFILE DELETEMASK SRVMSGLOGFILE 
export BACKUP_DUMP_OPTION CRASH_DUMP_OPTION TESTCFGFILE SERVER
#	  

export LOGFILE
. $HOME/binsrc/tests/suite/test_fn.sh

DS1=$PORT
DS2=`expr $PORT + 1`
DS3=`expr $PORT + 2`
DSBP=$DS1
DSDB=$DS2
DSTD=$DS3
HTTPPORTBP=$HTTPPORT
HTTPPORTDB=`expr $HTTPPORT + 1`
HTTPPORTTD=`expr $HTTPPORT + 2`
TPINIT=$1

# SQL command
DoCommand()
{
  _dsn=$1
  command=$2
  txt=$3
  shift
  shift
  shift
#echo "+ " $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*		>> $LOGFILE
  $ISQL ${_dsn} dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $* >> $LOGFILE
  if test $? -ne 0
  then
    LOG "***FAILED: $txt"
  else
    LOG "$txt"
  fi
}


# Configuration file creation
MakeConfig ()
{
    echo "CREATING CONFIGURATION FOR SERVER"
    MAKECFG_FILE $SUITE/$TESTCFGFILE $1 $CFGFILE
    case $SERVER in
      *[Mm2]*)
    file=wi.cfg
    cat >> $file <<END_CFG
http_port: $2
http_threads: 15
http_keep_alive_timeout: 15
http_max_keep_alives: 10
http_max_cached_proxy_connections: 10
http_proxy_connection_cache_timeout: 15
dav_root: DAV
enabled_dav_vsp: 1
END_CFG
;;
    *virtuoso*)
    file=virtuoso.ini
    cat >> $file <<END_CFG
[HTTPServer]
ServerPort		= $2
ServerRoot		= .
ServerThreads		= 15
MaxKeepAlives 		= 10
KeepAliveTimeout 	= 15
MaxCachedProxyConnections = 10
ProxyConnectionCacheTimeout = 15
DavRoot 		= DAV
EnabledDavVSP = 1
END_CFG
;;
esac
    mv $file $file.tmp
    cat $file.tmp | sed -e "s/CaseMode.*/CaseMode=2/g" > $file 
    chmod 644 $file
}


# MAIN
BANNER "STARTED SERIES OF BPEL ENGINE TESTS"

DSN=$DS1
STOP_SERVER
DSN=$DS2
STOP_SERVER
DSN=$DS3
STOP_SERVER

for p in $DS1 $DS2 $DS3 $HTTPPORTBP $HTTPPORTDB $HTTPPORTTD 
do
  ns=`netstat -an | grep "[\.\:]$p " | grep LISTEN`  
  if [ ! -z "$ns" ]
  then
      LOG "***ABORTED: Some of ports used by the test is occupied"
      exit 1
  fi   
done

rm -f $LOGFILE
rm -rf bp db td 

# Make VAD 
(cd ../../; make)

mkdir bp # BPEL engine
mkdir db # TPCC DB 
mkdir td # Test driver

# RUN 3 servers

cd bp
cp ../../../bpel_filesystem.vad .
# Put WSDL & BPEL
mkdir bpeltpcc
cp ../Sut.* bpeltpcc
cat ../dbservices.wsdl | sed -e "s/HTTPPORTDB/$HTTPPORTDB/g" > bpeltpcc/dbservices.wsdl
cat ../tdservices.wsdl | sed -e "s/HTTPPORTTD/$HTTPPORTTD/g" > bpeltpcc/tdservices.wsdl
MakeConfig $DS1 $HTTPPORTBP
START_SERVER $DS1 1000
cd ..

cd db
MakeConfig $DS2 $HTTPPORTDB
START_SERVER $DS2 1000
cd ..

cd td
MakeConfig $DS3 $HTTPPORTTD
START_SERVER $DS3 1000
cd ..

# Configure endpoint hosts

RUN $ISQL $DS1 ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF -u "HTTPPORTBP=$HTTPPORTBP" "HTTPPORTTD=$HTTPPORTTD" "HTTPPORTDB=$HTTPPORTDB"  < endp.sql
if test $STATUS -ne 0
then
  LOG "***ABORTED: endp.sql SCRIPT"
else
  LOG "FINISHED endp.sql SCRIPT"
fi
RUN $ISQL $DS2 ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF -u "HTTPPORTBP=$HTTPPORTBP" "HTTPPORTTD=$HTTPPORTTD" "HTTPPORTDB=$HTTPPORTDB"  < endp.sql
if test $STATUS -ne 0
then
  LOG "***ABORTED: endp.sql SCRIPT"
else
  LOG "FINISHED endp.sql SCRIPT"
fi
RUN $ISQL $DS3 ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF -u "HTTPPORTBP=$HTTPPORTBP" "HTTPPORTTD=$HTTPPORTTD" "HTTPPORTDB=$HTTPPORTDB"  < endp.sql
if test $STATUS -ne 0
then
  LOG "***ABORTED: endp.sql SCRIPT"
else
  LOG "FINISHED endp.sql SCRIPT"
fi

# LOAD TPCC data

RUN $ISQL $DSDB ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF  < $HOME/binsrc/tests/tpccddk.sql
if test $STATUS -ne 0
then
  LOG "***ABORTED: tpccddk.sql SCRIPT"
else
  LOG "FINISHED tpccddk.sql SCRIPT"
fi
RUN $ISQL $DSDB ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF  < $HOME/binsrc/tests/tpcc.sql
if test $STATUS -ne 0
then
  LOG "***ABORTED: tpcc.sql SCRIPT"
else
  LOG "FINISHED tpcc.sql SCRIPT"
fi
$TPCC $DSDB dba dba i 1

# Load DB procedures
RUN $ISQL $DSDB ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF  < procedures-list-DB.sql
if test $STATUS -ne 0
then
  LOG "***ABORTED: procedures-list-DB.sql SCRIPT"
else
  LOG "FINISHED procedures-list-DB.sql SCRIPT"
fi

# Load test driver procedures
RUN $ISQL $DSTD ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF  < procedures-list-TD.sql
if test $STATUS -ne 0
then
  LOG "***ABORTED: procedures-list-TD.sql SCRIPT"
else
  LOG "FINISHED procedures-list-TD.sql SCRIPT"
fi

# Load VAD
DoCommand $DSBP "vad_install ('bpel_filesystem.vad', 0);" "Installing vad package"

# Load BPEL script
RUN $ISQL $DSBP ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF  < load.sql
if test $STATUS -ne 0
then
  LOG "***ABORTED: load.sql SCRIPT"
else
  LOG "FINISHED load.sql SCRIPT"
fi

# Load the test procedure
RUN $ISQL $DSTD ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF -u "DSDB=$DSDB"  < test.sql
if test $STATUS -ne 0
then
  LOG "***ABORTED: test.sql SCRIPT"
else
  LOG "FINISHED test.sql SCRIPT"
fi

if [ "z$TPINIT" = "z" ]
then
    # Do the test
    DoCommand $DSTD "do_test (100,20);" "Test RUN"
else  
    RUN $ISQL $DSTD ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF -u "DSDB=$DSDB"  < test1.sql
    if test $STATUS -ne 0
    then
	LOG "***ABORTED: test1.sql SCRIPT"
    else
	LOG "FINISHED test1.sql SCRIPT"
    fi
fi

#RUN $ISQL $DSTD ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF -u "DSDB=$DSDB"  < chk.sql
#if test $STATUS -ne 0
#then
#  LOG "***ABORTED: chk.sql SCRIPT"
#else
#  LOG "FINISHED chk.sql SCRIPT"
#fi

DSN=$DS1
SHUTDOWN_SERVER
DSN=$DS2
SHUTDOWN_SERVER
DSN=$DS3
SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED BPEL ENGINE TEST ($0)"

exit 0

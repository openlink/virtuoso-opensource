#!/bin/sh 
#
#  $Id$
#
#  VAD tests
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

LOGFILE=tvad.output
export LOGFILE
. ./test_fn.sh


DoCommand()
{
  _dsn=$1
  command=$2
  comment=$3
  file='tvadtest.sql'
  shift 
  shift 
  shift
  echo $command > $file
  cat >> $file <<"END_SQL"
ECHO BOTH $IF $EQU $LAST[1] 'OK' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
END_SQL

  comment="ECHO BOTH \": "$comment" STATE=\" \$STATE \" MESSAGE=\" \$MESSAGE \"\n\";"
  echo $comment >> $file 

  echo "+ " $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*   >> $LOGFILE 
  RUN $ISQL $DSN dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tvadtest.sql 
}

DoBadCommand()
{
  _dsn=$1
  command=$2
  comment=$3
  file='tvadbtest.sql'
  shift 
  shift 
  shift
  echo $command > $file
  cat >> $file <<"END_SQL"
ECHO BOTH $IF $EQU $LAST[1] 'OK' "***FAILED" "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
END_SQL

  comment="ECHO BOTH \": "$comment" STATE=\" \$STATE \" MESSAGE=\" \$MESSAGE \"\n\";"
  echo $comment >> $file 

  echo "+ " $ISQL $_dsn dba dba ERRORS=STDOUT VERBOSE=OFF PROMPT=OFF "EXEC=$command" $*   >> $LOGFILE 

  SHUTDOWN_SERVER
  START_SERVER $PORT 1000 

  RUN $ISQL $DSN dba dba PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < tvadbtest.sql 

  STOP_SERVER
  rm -f $DBLOGFILE
  START_SERVER $PORT 1000 
}

 

BANNER "STARTED VAD TEST2 (tvad2.sh)"

mkdir vad
mkdir vad/vsp
mkdir vad/vsp/vad_test1
mkdir vad/vsp/vad_test2
cp -f $HOME/binsrc/tests/suite/vad_test/vsp/vad_test2/* vad/vsp/vad_test2
cp -f $HOME/binsrc/tests/suite/vad_test/vsp/vad_test1/* vad/vsp/vad_test1

SHUTDOWN_SERVER
rm -f $DBLOGFILE $DBFILE
START_SERVER $PORT 1000 

DoCommand  $DSN "select \"DB\".\"DBA\".\"VAD_PACK\" ('vad_test1.xml', '', 'vad_test1.vad');" "VAD_PACK 1"
DoCommand  $DSN "select \"DB\".\"DBA\".\"VAD_PACK\" ('vad_test2.xml', '', 'vad_test2.vad');" "VAD_PACK 2"

DoCommand  $DSN "select \"DB\".\"DBA\".\"VAD_CHECK_INSTALLABILITY\" ('vad_test1.vad', 0);" "VAD_CHECK_INSTALL 1"
DoCommand  $DSN "select \"DB\".\"DBA\".\"VAD_INSTALL\" ('vad_test1.vad', 0);" "VAD_INSTALL 1"
DoBadCommand  $DSN "select \"DB\".\"DBA\".\"VAD_INSTALL\" ('vad_test1.vad', 0);" "TWICE VAD_INSTALL 1"
DoCommand  $DSN "select  \"DB\".\"DBA\".\"VAD_CHECK_UNINSTALLABILITY\" ('test1/1.00');" "VAD_CHECK_UNINSTALL 1"
DoCommand  $DSN "select  \"DB\".\"DBA\".\"VAD_UNINSTALL\" ('test1/1.00');" "VAD_UNINSTALL 1"
DoBadCommand  $DSN "select \"DB\".\"DBA\".\"VAD_INSTALL\" ('t1_qq.vad', 0);" "INVALID VAD_INSTALL "
DoBadCommand  $DSN "select \"DB\".\"DBA\".\"VAD_INSTALL\" ('vad_test2.vad', 0);" "INVALID VAD_INSTALL 2"
DoCommand  $DSN "select \"DB\".\"DBA\".\"VAD_INSTALL\" ('vad_test1.vad', 0);" "VAD_INSTALL 1"
DoCommand  $DSN "select \"DB\".\"DBA\".\"VAD_INSTALL\" ('vad_test2.vad', 0);" "VAD_INSTALL 2"
DoCommand  $DSN "select  \"DB\".\"DBA\".\"VAD_UNINSTALL\" ('test1/1.00');" "VAD_UNINSTALL 1"
DoCommand  $DSN "select  \"DB\".\"DBA\".\"VAD_UNINSTALL\" ('test2/1.00');" "VAD_UNINSTALL 2"

SHUTDOWN_SERVER
rm -f $DBLOGFILE $DBFILE

rm -f t1.xml vad_test1.vad
rm -f t2.xml vad_test2.vad
rm -rf vad

CHECK_LOG
BANNER "COMPLETED VAD TEST2 (tvad2.sh)"

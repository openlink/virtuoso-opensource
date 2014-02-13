#!/bin/sh
#
#  $Id$
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

LOGFILE=`pwd`/ttutorial.output
LOGFILE_SUITE=$LOGFILE
STARTED_FROM_SUITE=1
export LOGFILE LOGFILE_SUITE STARTED_FROM_SUITE
. ./test_fn.sh
 
rm -f $DELETEMASK

#BOX_NAME=`eval uname -n`
BOX_NAME=localhost
export BOX_NAME

BANNER "STARTED TUTORIAL TESTS (ttutorial.sh)"
NOLITE

HOST_OS=`uname -s | grep WIN`

# disabled until tests are fixed 
exit 0

if [ "x$HOST_OS" != "x" ]
then
    LOG "This test is for Unix only"
    exit 0
fi

SHUTDOWN_SERVER

# PREPARE

case $SERVER in
   *[Mm]2*)
   LOG "This test is for Virtuoso server only"
   exit 0
   ;;
esac

ECHO "COPYNG NEEDED FILES"

rm -rf tutorial_test
mkdir tutorial_test
cd tutorial_test

rm -rf vsp
mkdir vsp

# UNIX

rm -f $DELETEMASK
cp -R ../../../tutorial vsp 
cp -R ../../../samples/xquery vsp/xqdemo 
cp -R ../../tutorial_test/xml/* . 
rm -rf suppfiles
cp -R ../../tutorial_test/suppfiles .
cp -f ../../urlsimu suppfiles
cp -f ../../isql suppfiles

cp -f ../$TESTCFGFILE $TESTCFGFILE 

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

case $SERVER in
   *virtuoso*)
   if test \! -f ../../../samples/demo/demo.db 
#  if test $STATUS -eq 0
   then
       LOG "***FAILED: ttutorial.sh needed demo.db to run tests."
       exit 0
   else
       cp ../../../samples/demo/demo.db virtuoso.db
       LOG "PASSED: Copy demo.db"
   fi
   
   ;;
esac   

# ALL

case $SERVER in
   *virtuoso*)
cat >> $CFGFILE <<END_CFG

[HTTPServer]
ServerPort = $HTTPPORT
ServerRoot = vsp
ServerThreads = 10

END_CFG
   ;;
esac   

# CNANGE CaseMode 

cat $CFGFILE | sed -e "s/CaseMode = 1/CaseMode = 2/g" > tmp.ini 
cp tmp.ini $CFGFILE
rm tmp.ini

START_SERVER $PORT 1000 
sleep 1
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT EXEC="'status()'"
if test $STATUS -ne 0
then
    LOG "***ABORTED: server startup check "
    exit 3
fi

./run_all.sh $BOX_NAME $PORT $HTTPPORT
cat tutorial_test.output >> $LOGFILE_SUITE
LOGFILE=$LOGFILE_SUITE
SHUTDOWN_SERVER

cd ..

CHECK_LOG

BANNER "COMPLETED TUTORIAL TESTS (ttutorial.sh)"

#!/bin/sh
#
#  $Id: testall.sh,v 1.69.2.5.4.31 2013/01/02 16:15:07 source Exp $
#
#  Call all tests in succession
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2018 OpenLink Software
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


#  This test suite can be also run under Windows NT if you have GNU WIN32
#  package.
#  See URL http://www.cygnus.com/misc/gnu-win32/ where you can download
#  it from. This has been tested with version b18. It is enough
#  to download usertools.exe, which is about four and half megabytes long
#  self-extracting archive.  Remember also to do the post-installation
#  settings mentioned in http://www.cygnus.com/misc/gnu-win32/readme.html
#  (E.g. you have to configure your Windows NT PATH).
#
#  If you unzip this package with an old PKUNZIP that converts
#  the filenames to uppercase, you should first run the script
#  lowerall.sh that will reconvert them back to lowercase, before
#  starting this one.
#
#  Note that in when running in Windows NT the environment variable
#  OSTYPE should be defined as win32 (done automatically by the shell)
#  that this worked correctly.
#  (Similarly, on Unix platforms it should be anything else except win32)
#
#  Keep the PORT as 1111 unless you want problems. In Windows NT this
#  assumes that there exists a previously defined Virtuoso datasource
#  with the name 'Virtuoso' whose host:port is set to localhost:1111
#
#
#  Yet needs to be done:
#
#  A) Exhaustive testing of all SQL syntactic features. (E.g. string literals
#     with various escape characters and conventions for single quotes,
#     empty strings, etc.)
#
#  B) Of all SQL statement features (e.g. inserts, updates, deletes, select,
#     where-expressions and joins not encountered in twords.sql)
#     Could be added to twords.sql or twords2.sql, using the existing
#     words data.
#
#  C) Of all built-in bif SQL-functions (documented in funrefs.doc)
#
#  D) Test of procedures written with Virtuoso/PL SQL Procedure language
#
#  E) ODBC/SAG CLI API-calls, e.g. various catalog calls. (Tables, Procedures,
#     TablePrivileges and ColumnPrivileges have already been partly tested in
#     tsec*.sql)
#
#  F) Singular cases. E.g. empty tables (tested in tdbdump.sql),
#     empty whatevers, etc.
#
#  G) Testing the functionality of isql itself.
#
#  H) On Win32 platforms, running some of the tests also with isqlodbc,
#     not only with isql, thus testing also the ODBC driver functionality.
#     (The DBDUMP used in tdbdump.sh is compiled as an ODBC application
#     in Win NT, so that script partly tests also the ODBC driver.)
#
#
#  If you add your own tests, see the test suites run from tsec.sh (tsec.bat),
#  i.e. tsec*.sql as they are the most pedantically written, checking almost
#  everything.
#

# **********************************************************************************
# **********************************************************************************
# **********************************************************************************

#
#  Read the standard functions
#
cfg=$1
shift
LOGFILE=testall.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh
# some OS-es print line even not found
#run_tests_in_parallel=`which parallel | wc -l`
#parallel 2> /dev/null
#if [ $? -ne 0 ]
#then
    #run_tests_in_parallel=0
#else
    #run_tests_in_parallel=1
#fi
run_tests_in_parallel=0

#
#  Setup the environment for the rest of the testsuite
#
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

test_set="tsql tsql2 tsql3 \
nwxml \
obackup \
tdav \
tdav_meta \
thttp \
msdtc \
timsg \
tpcd \
tproxy \
trecov_schema \
trepl \
tsec \
tsqlo \
toptitpcd \
tvad \
tvsp \
twcopy \
txslt \
trecov \
tlubm \
rtest"

QUICKTEST=1
TPCDMODE=local

# if [ "X$IN_NIGHTLY" != "X" ]
if [ "X$EXTENDED_TESTING" != "X" ]
then
  QUICKTEST=0
  test_set="$test_set bpel tdbp tdrop tjdbc treplh tsoap12 ttutorial tvspxex gtkbench"
fi

# outdated tests:
# tupgrade_recov

export QUICKTEST TSQLOMODE TPCDMODE

tstexe=""
for tst in $test_set 
do 
  tstexe="$tstexe $tst.sh"
done

if [ $run_tests_in_parallel -ne 0 ]
then
    # parallel test execution
    parallel test_run.sh $cfg -- $test_set
else
    # serial test execution (for debug only)
    for tst in $test_set
    do
	#tstexe=$tst.sh
	RUN_TEST $cfg $tst
	cd $VIRTUOSO_TEST
    done
fi

#
# kill all virtuoso instances started by tests and possibly left
#

KILL_TEST_INSTANCES

#
#  Check if the tests left us any log files to examine
#

for test in $test_set
do
  for testdir in $VIRTUOSO_TEST/$test.{test,ro,co,clro,clco}
  do
     if [ -d $testdir ]
     then
	  n=`ls -1 $testdir/$test.output 2>/dev/null | wc -l`
	  if [ $n -eq 0 ] 
	  then
	    ECHO "***ABORTED: No $test output (file $testdir/$test.output)"
	    exit 3
          fi
     fi
  done
done

##################################################################################
##################################################################################

#!/bin/sh
#
#  $Id$
#
#  Call all tests in succession
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


#
#  Read the standard functions
#
LOGFILE=testall.output
export LOGFILE
. ./test_fn.sh

#
#  Clean up the mess from the last run
#
./clean.sh
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE


ECHO ""
ECHO "THIS TAKES AT LEAST 350 MEGABYTES OF DISK SPACE AND SOME AMOUNT"
ECHO "OF TIME (could be hours). BE PATIENT."

BANNER "STARTED TESTSUITE (testall.sh)"

#if test "x$OSTYPE" = "xwin32"
#then
    #
    #  Running on Windows
    #
#    RUN cp ../../$BUILD_MODE/M2.exe M2.exe
#    if test $STATUS -eq 0
#    then
#	LOG "PASSED: M2.exe copied from ../../$BUILD_MODE/M2.exe"
#    else
#	LOG "***ABORTED: M2.exe could not be copied from ../../$BUILD_MODE/M2.exe"
#	exit 1
#    fi

    #
    #  First make sure that there are no service named $SERVICE already
    #  installed:
    #
#    RUN $SERVER -U$SERVICE

    #
    #  The following may generate an error message if it is already installed:
    #  M2 has to be a real executable M2.exe (copied from ../../WinDebug/M2.exe)
    #  in this same directory, NOT a symbolic link.
#    RUN $SERVER -I$SERVICE $PORT

#    if test $STATUS -eq 0
#    then
#	LOG "PASSED: Virtuoso Server successfully installed as a service $SERVICE"

#   else
#	LOG "***ABORTED: Could not install Virtuoso Server as a service $SERVICE"

#	exit 1
#    fi
#fi

#
#  Make sure the database is not running
#
STOP_SERVER

#
#  Start the server once:
#
START_SERVER $PORT 1000



LOG "Getting the status of database into file ident.txt"
if $ISQL $DSN "EXEC=status();" VERBOSE=OFF ERRORS=STDOUT > ident.txt
then
    # ident.txt created and longer than zero bytes?
    if test -s ident.txt
    then
	LOG "PASSED: Inquiring database status"
    else
	LOG "***FAILED: Inquiring database status, ident.txt missing or empty"
	exit 3
    fi
else
    LOG "***ABORTED: Inquiring database status"
    exit 3
fi



#
#  And kill it immediately afterwards
#
STOP_SERVER


#
#  Make sure that the log file (wi.trx) and the database file (wi.db) are deletable in Windows NT
#
RUN rm -f $DELETEMASK
if test -f "$DBFILE"
then
    LOG "***ABORTED: Could not delete old $DBFILE file. "
    LOG "Check that it has not been left locked by Virtuoso!"
    exit 1;
else
    LOG "PASSED: File $DBFILE successfully deleted."
fi

if test -f "$DBLOGFILE"
then
    LOG "***ABORTED: Could not delete old $DBLOGFILE file."
    LOG "Check that it has not been left locked by Virtuoso!"
    exit 1;
else
    LOG "PASSED: File $DBLOGFILE successfully deleted."
fi

#
#  Setup the environment for the rest of the testsuite
#
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
rm -f audit.txt core debug.txt

#
#  Run the test scripts
#
./tvsp.sh
#./tupgrade_recov.sh

./trecov.sh
./trecov_schema.sh

./tsql.sh
./tsql2.sh
./tsql3.sh
./tsec.sh
STOP_SERVER
./rtest.sh
./nwxml.sh
./gtkbench.sh quicktest
./thttp.sh
./tproxy.sh
./trepl.sh
./txslt.sh
./tdav.sh
# ./tdrop.sh	# Not for a regular test suite
./timsg.sh
./twcopy.sh
./tvad.sh
#if [ "X$SQLOPTIMIZE" != "X" ]
#then
./tsqlo.sh
#fi
./obackup.sh
if [ "X$IN_NIGHTLY" != "X" ]
then
#./tdbp.sh
touch tdbp.output
fi
./tjdbc.sh
./msdtc.sh
./ttutorial.sh
./bpel.sh
./tdav_meta.sh
./tpcd.sh

#XXX: not tested yet on Win32
if [ "x$HOST_OS" != "x" ]
then
  touch inprocess.output
  touch tvspxex.output
  touch tsoap12.output
  if [ ! -f ../../../autogen.sh ]
  then
  ./treplh.sh
  fi
else  
    # XXX: until is fixed to enter and leave vdb properly  
  #./inprocess.sh
  touch inprocess.output
  ./tsoap12.sh
  ./tvspxex.sh
  (cd ../lubm; ./tlubm.sh)
fi  

#
#  Start the server again
#
rm -f $DELETEMASK
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
START_SERVER $PORT 1000

LOG "Getting the status of database into file ident.txt"
if $ISQL $DSN "EXEC=status();" VERBOSE=OFF ERRORS=STDOUT > ident.txt
then
    # ident.txt created and longer than zero bytes?
    if test -s ident.txt
    then
	LOG "PASSED: Inquiring database status"
    else
	LOG "***FAILED: Inquiring database status, ident.txt missing or empty"
	exit 3
    fi
else
    LOG "***ABORTED: Inquiring database status"
    exit 3
fi

#LOG "Next we do a checkpoint and then kill the database server with raw_exit()"
#LOG "after which we should get Lost Connection to Server -error."
#RUN $ISQL $DSN ERRORS=STDOUT '"EXEC=shutdown wi2.log;"'
STOP_SERVER

#if test "x$OSTYPE" = "xwin32"
#then
#    RUN $SERVER -U$SERVICE
#    if test $STATUS -eq 0
#    then
#	LOG "PASSED: Service $SERVICE successfully uninstalled."
#    else
#	LOG "***FAILED: Could not uninstall service $SERVICE."
#    fi
#fi

CHECK_LOG
BANNER "COMPLETED testall.sh (almost)"


#
#  Check if the tests left us any log files to examine
#
if test \! -f tvsp.output
then
    ECHO "***ABORTED: No tvsp.output"
    exit 3
fi

if test \! -f tsec.output
then
    ECHO "***ABORTED: No tsec.output"
    exit 3
fi

if test \! -f trecov.output
then
    ECHO "***ABORTED: No trecov.output"
    exit 3
fi

if test \! -f trecov_schema.output
then
    ECHO "***ABORTED: No trecov_schema.output"
    exit 3
fi

if test \! -f tsql.output
then
    ECHO "***ABORTED: No tsql.output"
    exit 3
fi

if test \! -f tsql2.output
then
    ECHO "***ABORTED: No tsql2.output"
    exit 3
fi

if test \! -f tsql3.output
then
    ECHO "***ABORTED: No tsql3.output"
    exit 3
fi

if test \! -f rtest.output
then
    ECHO "***ABORTED: No rtest.output"
    exit 3
fi

if test \! -f nwxml.output
then
    ECHO "***ABORTED: No nwxml.output"
    exit 3
fi


if test \! -f gtkbench.output
then
    ECHO "***ABORTED: No gtkbench.output"
    exit 3
fi


if test \! -f thttp.output
then
    ECHO "***ABORTED: No thttp.output"
    exit 3
fi

if test \! -f tproxy.output
then
    ECHO "***ABORTED: No tproxy.output"
    exit 3
fi

if test \! -f trepl.output
then
    ECHO "***ABORTED: No trepl.output"
    exit 3
fi


if test \! -f txslt.output
then
    ECHO "***ABORTED: No txslt.output"
    exit 3
fi


if test \! -f tdav.output
then
    ECHO "***ABORTED: No tdav.output"
    exit 3
fi

if test \! -f tdav_meta.output
then
    ECHO "***ABORTED: No tdav_meta.output"
    exit 3
fi


if test \! -f timsg.output
then
    ECHO "***ABORTED: No timsg.output"
    exit 3
fi

if test \! -f tvad.output
then
    ECHO "***ABORTED: No tvad.output"
    exit 3
fi

if test \! -f twcopy.output
then
    ECHO "***ABORTED: No twcopy.output"
    exit 3
fi

if test \! -f obackup.output
then
    ECHO "***ABORTED: No obackup.output"
    exit 3
fi

if test \! -f tjdbc.output
then
    ECHO "***ABORTED: No tjdbc.output"
    exit 3
fi

if test \! -f msdtc.output
then
    ECHO "***ABORTED: No msdtc.output"
    exit 3
fi

if test \! -f ttutorial.output
then
    ECHO "***ABORTED: No ttutorial.output"
    exit 3
fi

if test \! -f bpel.output
then
    ECHO "***ABORTED: No bpel.output"
    exit 3
fi

#if test \! -f inprocess.output
#then
#    ECHO "***ABORTED: No inprocess.output"
#    exit 3
#fi


#if [ "X$SQLOPTIMIZE" != "X" ]
#then
sqlo_outputs=tsqlo.output
    if test \! -f tsqlo.output
    then
	ECHO "***ABORTED: No tsqlo.output"
	exit 3
    fi
#fi
#
#  Check if the tests logged any failures
#
RUN egrep '"\*\*\*.*FAILED|\*\*\*.*ABORTED"' tvsp.output trecov.output tsql.output tsql2.output tsql3.output tsec.output rtest.output gtkbench.output thttp.output tproxy.output tdav.output twcopy.output $sqlo_outputs timsg.output tvad.output trepl.output nwxml.output txslt.output obackup.output tjdbc.output inprocess.output tvspxex.output tsoap12.output trecov_schema.output msdtc.output ttutorial.output bpel.output tdav_meta.output # tupgrade_recov.output 
if test $STATUS -eq 0
then
    ECHO ""
    LINE
    ECHO "=  WARNING: Some tests failed. See *.output in this directory" `pwd`
    egrep '\*\*\*.*FAILED|\*\*\*.*ABORTED' tvsp.output trecov.output tsql.output tsql2.output tsql3.output tsec.output rtest.output gtkbench.output thttp.output tproxy.output tdav.output twcopy.output $sqlo_outputs timsg.output tvad.output trepl.output nwxml.output txslt.output obackup.output tjdbc.output inprocess.output tvspxex.output tsoap12.output trecov_schema.output msdtc.output ttutorial.output bpel.output tdav_meta.output # tupgrade_recov.output 
    LINE
    rm -f audit.txt
 
    #grail error
    RUN egrep '"\*\*\*.*FAILED|\*\*\*.*ABORTED"' trecov.output 
    if test $STATUS -eq 0
    then
	rm -rf grail_backup
	mkdir grail_backup
	cp *.r* grail_backup
	cp trecov.output grail_backup/trecov.out.err
    fi	
    #grail error part2
    RUN egrep '"\*\*\*.*FAILED|\*\*\*.*ABORTED"' trecov_schema.output 
    if test $STATUS -eq 0
    then
	rm -rf grail_backup2
	mkdir grail_backup2
	cp *.sr* grail_backup2
	cp trecov_schema.output grail_backup2/trecov_schema.out.err
    fi	
    exit 3;
else
    ECHO ""
    LINE
    ECHO "=  RELEASE TESTS PASSED."
    ECHO "="
    ECHO "=  See audit.txt and " *.output
    ECHO "=  in the directory" `pwd`;
    LINE

    #
    #  Audit.txt contains the build information
    #
    echo "Virtuoso release check passed " > audit.txt
    date >> audit.txt
    fgrep "DBMS" ident.txt >> audit.txt
    uname -a >> audit.txt
fi

ECHO ""
LINE
ECHO "=  To see what is left in the database, start $SERVER in the same "
ECHO "=  directory, and connect to it with isql"
LINE

#!/bin/sh
#
#  $Id: tjdbc.sh,v 1.6.6.1.4.4 2013/01/02 16:15:12 source Exp $
#
#  JDBC tests
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

LOGFILE=tjdbc.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

JDBCDIR=${JDBCDIR-$VIRTUOSO_TEST/../../../libsrc/JDBCDriverType4}
CURRDIR=`pwd`

BANNER "STARTED JDBC Driver TEST (tjdbc.sh)"

if [ "x$JDK2" != "x" -a -f $JDBCDIR/virtjdbc2.jar -a -f  $JDBCDIR/testsuite2.jar ]
then
    STOP_SERVER
    rm -f $DBLOGFILE
    rm -f $DBFILE
    MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

    START_SERVER $PORT 1000

    ECHO "STARTED: JDBC 2 Test suite"
    cd $JDBCDIR
    sh $JDBCDIR/test2.sh "jdbc:virtuoso://localhost:$PORT/" > $CURRDIR/jdbc.out 2>&1
    cd $CURRDIR

    passed=`egrep "PASSED\$" jdbc.out`
    passed_cnt=`egrep "PASSED\$" jdbc.out | wc -l`
    failed=`egrep "FAILED\$" jdbc.out`
    failed_cnt=`egrep "FAILED\$" jdbc.out | wc -l`

    errors=0
    if [ $failed_cnt -gt 0 ]
    then
	errors=1
	ECHO "*** FAILED: $failed_cnt JDBC 2 Tests failed (check jdbc.out): $failed"
    fi
    if [ $passed_cnt -eq 0 ]
    then
	errors=1
	ECHO "*** FAILED: no JDBC 2 Tests passed! (check jdbc.out)"
    fi
    if [ $errors -eq 0 ]
    then
	ECHO "PASSED: JDBC 2 Test suite"
    fi

    SHUTDOWN_SERVER
fi # JDK2

if [ "x$JDK3" != "x" -a -f $JDBCDIR/virtjdbc3ssl.jar -a -f  $JDBCDIR/testsuite3.jar ]
then
    STOP_SERVER
    rm -f $DBLOGFILE
    rm -f $DBFILE
    MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

    START_SERVER $PORT 1000

    ECHO "STARTED: JDBC 3 Test suite"
    cd $JDBCDIR
    sh $JDBCDIR/test3.sh "jdbc:virtuoso://localhost:$PORT/" > $CURRDIR/jdbc3.out 2>&1
    cd $CURRDIR

    passed=`egrep "PASSED\$" jdbc3.out`
    passed_cnt=`egrep "PASSED\$" jdbc3.out | wc -l`
    failed=`egrep "FAILED\$" jdbc3.out`
    failed_cnt=`egrep "FAILED\$" jdbc3.out | wc -l`

    errors=0
    if [ $failed_cnt -gt 0 ]
    then
	errors=1
	ECHO "*** FAILED: $failed_cnt JDBC 3 Tests failed (check jdbc3.out): $failed"
    fi
    if [ $passed_cnt -eq 0 ]
    then
	errors=1
	ECHO "*** FAILED: no JDBC 3 Tests passed! (check jdbc3.out)"
    fi
    if [ $errors -eq 0 ]
    then
	ECHO "PASSED: JDBC 3 Test suite"
    fi

    SHUTDOWN_SERVER
fi # JDK3

if [ "x$JDK4" != "x" -a -f $JDBCDIR/virtjdbc4ssl.jar -a -f  $JDBCDIR/testsuite4.jar ]
then
    STOP_SERVER
    rm -f $DBLOGFILE
    rm -f $DBFILE
    MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

    START_SERVER $PORT 1000

    ECHO "STARTED: JDBC 4 Test suite"
    cd $JDBCDIR
    sh $JDBCDIR/test4.sh "jdbc:virtuoso://localhost:$PORT/" > $CURRDIR/jdbc4.out 2>&1
    cd $CURRDIR

    passed=`egrep "PASSED\$" jdbc4.out`
    passed_cnt=`egrep "PASSED\$" jdbc4.out | wc -l`
    failed=`egrep "FAILED\$" jdbc4.out`
    failed_cnt=`egrep "FAILED\$" jdbc4.out | wc -l`

    errors=0
    if [ $failed_cnt -gt 0 ]
    then
	errors=1
	ECHO "*** FAILED: $failed_cnt JDBC 4 Tests failed (check jdbc4.out): $failed"
    fi
    if [ $passed_cnt -eq 0 ]
    then
	errors=1
	ECHO "*** FAILED: no JDBC 4 Tests passed! (check jdbc4.out)"
    fi
    if [ $errors -eq 0 ]
    then
	ECHO "PASSED: JDBC 4 Test suite"
    fi

    SHUTDOWN_SERVER
fi # JDK4

if [ "x$JDK4_1" != "x" -a -f $JDBCDIR/virtjdbc4_1ssl.jar -a -f  $JDBCDIR/testsuite4.jar ]
then
    STOP_SERVER
    rm -f $DBLOGFILE
    rm -f $DBFILE
    MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

    START_SERVER $PORT 1000

    ECHO "STARTED: JDBC 4_1 Test suite"
    cd $JDBCDIR
    sh $JDBCDIR/test4_1.sh "jdbc:virtuoso://localhost:$PORT/" > $CURRDIR/jdbc4_1.out 2>&1
    cd $CURRDIR

    passed=`egrep "PASSED\$" jdbc4_1.out`
    passed_cnt=`egrep "PASSED\$" jdbc4_1.out | wc -l`
    failed=`egrep "FAILED\$" jdbc4_1.out`
    failed_cnt=`egrep "FAILED\$" jdbc4_1.out | wc -l`

    errors=0
    if [ $failed_cnt -gt 0 ]
    then
	errors=1
	ECHO "*** FAILED: $failed_cnt JDBC 4_1 Tests failed (check jdbc4_1.out): $failed"
    fi
    if [ $passed_cnt -eq 0 ]
    then
	errors=1
	ECHO "*** FAILED: no JDBC 4_1 Tests passed! (check jdbc4_1.out)"
    fi
    if [ $errors -eq 0 ]
    then
	ECHO "PASSED: JDBC 4_1 Test suite"
    fi

    SHUTDOWN_SERVER
fi # JDK4_1

CHECK_LOG

BANNER "COMPLETED JDBC Driver TEST (tjdbc.sh)"

#!/bin/sh
#
#  $Id: epilog.sh,v 1.1.2.4 2013/01/02 16:14:39 source Exp $
#
#  Call all tests in succession
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

#  Start the server again
if [ -z "$test_to_run" ]
then
    CURRENT_VIRTUOSO_CAPACITY="single"
    CURRENT_VIRTUOSO_TABLE_SCHEME="row"
    MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
    CHECK_IF_SERVER_STARTABLE
fi

CHECK_LOG
BANNER "COMPLETED test"

#
# kill all virtuoso instances started by tests and possibly left
#

KILL_TEST_INSTANCES

#
#  Check if the tests logged any failures
#
logs=`find . -type f -name "*.output" | grep -v testall`
#logs=`ls *.{test,ro,co,clro,clco}/*.output | grep -v testall`
if egrep "^(\*\*\*.*FAILED|\*\*\*.*ABORTED)" $logs >/dev/null
then
    ECHO ""
    LINE
    ECHO "=  WARNING: Some tests failed. See *.output in test directories under " `pwd`
    ECHO "="
    ECHO "=  ABORTED tests:"
    egrep "^(\*\*\*.*ABORTED)" $logs
    ECHO "="
    ECHO "=  FAILED tests:"
    egrep "^(\*\*\*.*FAILED)" $logs
    LINE
    rm -f audit.txt
    exit 3;
else
    if [ -z "$test_to_run" ]
    then
	ECHO ""
	LINE
	ECHO "=  RELEASE TESTS PASSED."
	ECHO "="
	ECHO "=  See audit.txt and " $logs
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
fi

ECHO ""
LINE
ECHO "=  To see what is left in the database, start $SERVER in the test "
ECHO "=  directory, and connect to it with isql"
LINE

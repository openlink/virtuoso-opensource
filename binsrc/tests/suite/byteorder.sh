#!/bin/sh
#  tsql.sh
#
#  $Id: byteorder.sh,v 1.3.10.3 2013/01/02 16:14:38 source Exp $
#
#  VARIOUS MACHINE BYTEORDER support 
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

LOGFILE=byteorder.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

DSN=$PORT
www_server=bugzilla.openlinksw.com
www_port=7780
www_location=resources
demo_sol_db=demo-sol.db

BANNER "STARTED SERIES OF BYTEORDER TEST (byteorder.sh)"

SHUTDOWN_SERVER
rm -f $DBLOGFILE
rm -f $DBFILE
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

if [ -f "$demo_sol_db" ]
then
  ECHO "File '$demo_sol_db found, no need to download it."
else
  if [ "${OSTYPE}" = "solaris2.7" ]
  then
    ping "${www_server}" 128 3
  else
    ping -c 3 "${www_server}"
  fi
  pingres=$?
  if [ $? = "0" ]
  then
    wget -t 10 -N "${www_server}:${www_port}/${www_location}/${demo_sol_db}.bz2" ./

    if [ -f "${demo_sol_db}.bz2" ]
    then
	bzip2 -cd "${demo_sol_db}.bz2" > "${demo_sol_db}"
    fi
  else
    ECHO "Unable to ping '${www_server}'"
  fi    
fi


if [ ! -f "$demo_sol_db" ]
then
	LOG "***FAILED: could not get $demo_sol_db database"
	exit 1
else
	LOG "PASSED: $demo_sol_db"
fi


cp $demo_sol_db $DBFILE

if [ -f "${demo_sol_db}.bz2" ] 
then
	rm -f "${demo_sol_db}"
fi

RUN $SERVER $FOREGROUND_OPTION

SHUTDOWN_SERVER

START_SERVER $PORT 1000

RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/byteorder.sql

rm -f fc.xml

SHUTDOWN_SERVER

CHECK_LOG
BANNER "COMPLETED SERIES OF BYTEORDER TESTS"

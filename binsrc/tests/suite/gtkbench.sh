#!/bin/sh
#
#  $Id$
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

LOGFILE=gtkbench.output
export LOGFILE
. ./test_fn.sh

GTKBENCH=../../samples/GTK/gtkbench/gtk-bench
if [ "x$HOST_OS" != "x" ] 
then
GTKBENCH=../gtk-odbc-bench
fi
LOGIN="-d $PORT -u dba -p dba"

#
#  Determine whether to we want to do a quick test or do a more elaborate
#  and slow test. 
#
#  The test scripts will invoke this script with the "quicktest" option
#  to run it with a reduced set of arguments. 
#  
#  When run from the commandline it will do the full set of tests
#
ARG=${1-full}
case $ARG in
  quicktest)
	T=5
	M=1
	MODE=quick
	;;
  *)
	T=15
	M=3
	MODE=full
	;;
esac

BANNER "STARTED GTKBENCH TEST - $MODE (gtkbench.sh)"

if [ ! -x $GTKBENCH ]
then
  LOG "No gtk-bench executable compiled. Exiting"
  CHECK_LOG
  BANNER "COMPLETED GTKBENCH TEST (gtkbench.sh)"
  exit 0
fi

rm -f $DBLOGFILE
rm -f $DBFILE
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

SHUTDOWN_SERVER
START_SERVER $PORT 1000 

LOG "Creating the schema"
RUN $GTKBENCH $LOGIN -C
if test $STATUS -ne 0
then 
    LOG "***ABORTED: gtkbench.sh: doing schema" 
    exit 3
fi

if [ "x$MODE" = "xquick" ]
then	# Run the tests quickly
  for cursor_type in forward static keyset dynamic mixed
  do
    for method in prepare
    do
      LOG "Running $T threads/$M min/100 row $method, $cursor_type cursor"

      RUN $GTKBENCH $LOGIN -t$T -v -m$M -1 -S40 -K40 -s $method -c $cursor_type
      if test $STATUS -ne 0
      then 
        LOG "***ABORTED: gtkbench.sh: gtkbench" 
        exit 3
      fi
      LOG "PASSED: $T threads/$M min/100 row $method, $cursor_type cursor"
    done
  done
else	# RUN THE FULL SET OF TESTS
  for isolation in uncommitted committed repeatable serializable
  do
    for cursor_type in forward static keyset dynamic mixed
    do
      for method in prepare
      do
        LOG "Running $T threads/$M min/100 row $method, $cursor_type cursor, $isolation"
  
        RUN $GTKBENCH $LOGIN -t$T -v -m$M -1 -S40 -K40 -s $method -c $cursor_type -i $isolation
        if test $STATUS -ne 0
        then 
          LOG "***ABORTED: gtkbench.sh: gtkbench" 
          exit 3
        fi
        LOG "PASSED: $T threads/$M min/100 row $method, $cursor_type cursor, $isolation"
      done
    done  
  done
fi

SHUTDOWN_SERVER
CHECK_LOG
BANNER "COMPLETED GTKBENCH TEST (gtkbench.sh)"

#!/bin/sh
#
#  choose a server to run with
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

# ----------------------------------------------------------------------
#  Fix issues with LOCALE
# ----------------------------------------------------------------------
LANG=C
LC_ALL=POSIX
export LANG LC_ALL

if test "x$TOP" = "x"
then
    echo ""
    echo "***"
    echo "*** ERROR: \$TOP "
    echo "***"
    exit 1
fi
export TOP

VIRTUOSO_BUILD=$TOP
VIRTDEV_HOME=${VIRTDEV_HOME-$VIRTUOSO_BUILD}
VIRTUOSO_TEST=${VIRTUOSO_TEST-$VIRTDEV_HOME/binsrc/tests/suite}
export VIRTDEV_HOME VIRTUOSO_TEST VIRTUOSO_BUILD

SQLPATH=$VIRTUOSO_TEST
export SQLPATH

if test \! -f "$VIRTUOSO_BUILD/binsrc/virtuoso/virtuoso-t"
then
    echo ""
    echo "***"
    echo "*** ERROR: \$VIRTUOSO_BUILD does not appear to contain standard virtuoso binary"
    echo "***" 
    exit 1
fi

VIRTUOSO_CAPACITY="default"
VIRTUOSO_TABLE_SCHEME="default"
VIRTUOSO_VDB="default"
SERVER=virtuoso
TEST_DIR_MASK=""
APPENDMODE=0

#
# VOS
#
SERVER=virtuoso
VIRTUOSO_VDB=0
VIRTUOSO_TABLE_SCHEME="row"
VIRTUOSO_CAPACITY="single"

while getopts ":smrcvwV" optname
  do
    case "$optname" in
      "v")
        SERVER=virtuoso
        ;;
      "w")
        SERVER=M2
        ;;
      "i")
	SERVER=virtuoso-iodbc
	;;
      "V") # no VDB
        VIRTUOSO_VDB=0
        ;;
      "s")
        if [ "$VIRTUOSO_CAPACITY" = "default" ]
        then
            VIRTUOSO_CAPACITY="single"
        else
            VIRTUOSO_CAPACITY="$VIRTUOSO_CAPACITY single"
        fi
        ;;
      "m")
        if [ "$VIRTUOSO_CAPACITY" = "default" ]
        then
            VIRTUOSO_CAPACITY="multiple"
        else
            VIRTUOSO_CAPACITY="$VIRTUOSO_CAPACITY multiple"
        fi
        ;;
      "r")
        if [ "$VIRTUOSO_TABLE_SCHEME" = "default" ]
        then
            VIRTUOSO_TABLE_SCHEME="row"
        else
            VIRTUOSO_TABLE_SCHEME="$VIRTUOSO_TABLE_SCHEME row"
        fi
        ;;
      "c")
        if [ "$VIRTUOSO_TABLE_SCHEME" = "default" ]
        then
            VIRTUOSO_TABLE_SCHEME="col"
        else
            VIRTUOSO_TABLE_SCHEME="$VIRTUOSO_TABLE_SCHEME col"
        fi
        ;;
      "A")
	APPENDMODE=1
	;;
      *)
      # other parameters -- passed to the scripts
        otherparams="$otherparams $optname"
        ;;
    esac
  done
shift `expr $OPTIND - 1`

if [ "$VIRTUOSO_CAPACITY" = "default" ]
then
    VIRTUOSO_CAPACITY="single multiple"
fi

if [ "$VIRTUOSO_TABLE_SCHEME" = "default" ]
then
    VIRTUOSO_TABLE_SCHEME="row col"
fi

. $VIRTUOSO_TEST/testlib.sh

# decide witch server options set to use based on the server's name

case $SERVER in
  *virtuoso*)
	  echo Using virtuoso configuration | tee -a $LOGFILE
	  CFGFILE=virtuoso.ini
	  DBFILE=virtuoso.db
	  DBLOGFILE=virtuoso.trx
	  DELETEMASK="virtuoso.lck $DBLOGFILE $DBFILE virtuoso.tdb virtuoso.ttr"
	  SRVMSGLOGFILE="virtuoso.log"
	  TESTCFGFILE=virtuoso-1111.ini
	  BACKUP_DUMP_OPTION=+backup-dump
	  CRASH_DUMP_OPTION=+crash-dump
	  FOREGROUND_OPTION=-f
	  LOCKFILE=virtuoso.lck
	  _2PCFILE=virtuoso.2pc
	  export FOREGROUND_OPTION LOCKFILE _2PCFILE
	  ;;
  *[Mm]2*)
	  echo Using M2 configuration | tee -a $LOGFILE
	  CFGFILE=wi.cfg
	  DBFILE=wi.db
	  DBLOGFILE=wi.trx
	  DELETEMASK="`ls wi.* witemp.* | grep -v wi.err`"
	  SRVMSGLOGFILE="wi.err"
	  TESTCFGFILE=witest.cfg
	  BACKUP_DUMP_OPTION=-d
	  CRASH_DUMP_OPTION=-D
	  _2PCFILE=virtuoso.2pc
	  unset FOREGROUND_OPTION
	  unset LOCKFILE
	  export _2PCFILE
	  ;;
   *)
	  echo "***FAILED: Unknown server. Exiting" | tee -a $LOGFILE
	  exit 3;
	  ;;
esac

tst=$1
if [ -n "$tst" ]
then
    if [ "`basename $tst ".sh"`.sh" = "$tst" ]
    then	
	test_to_run=`basename $tst ".sh"`
	test_type=sh
    elif [ "`basename $tst ".sql"`.sql" = "$tst" ]
    then
	test_to_run=`basename $tst ".sql"`
	test_type=sql
    else
        # default test type is SH
	test_type=sh
	test_to_run=`basename $tst ".sh"`
    fi
fi

if [ "$test_to_run" = "debug" ]
then
  set | egrep "^(PORT|CFGFILE|DBFILE|DBLOGFILE|DELETEMASK|SRVMSGLOGFILE|TESTCFGFILE|BACKUP_DUMP_OPTION|CRASH_DUMP_OPTION|VIRTUOSO_CAPACITY|VIRTUOSO_TABLE_SCHEME|TEST_DIR_MASK)="
  exit 42
fi  

CURRENT_VIRTUOSO_CAPACITY="single"
CURRENT_VIRTUOSO_TABLE_SCHEME="row"
export CFGFILE DBFILE DBLOGFILE DELETEMASK SRVMSGLOGFILE BACKUP_DUMP_OPTION CRASH_DUMP_OPTION TESTCFGFILE SERVER CURRENT_VIRTUOSO_CAPACITY CURRENT_VIRTUOSO_TABLE_SCHEME VIRTUOSO_VDB TEST_DIR_MASK

rm -rf $VIRTUOSO_TEST/PORTS
mkdir $VIRTUOSO_TEST/PORTS

# do the prolog
if [ -z "$test_to_run" ]
then
#  Clean up the mess from the last run
    if [ "$APPENDMODE" = "0" ]
    then
	rm -rf $VIRTUOSO_TEST/*.test $VIRTUOSO_TEST/*.ro $VIRTUOSO_TEST/*.co $VIRTUOSO_TEST/*.clro $VIRTUOSO_TEST/*.clco
	$VIRTUOSO_TEST/clean.sh
    fi

    LOGFILE=$VIRTUOSO_TEST/testall.output
    export LOGFILE
    . prolog.sh
else
    shift
fi
if [ "$VIRTUOSO_VDB" = "default" ]
then
    if grep VDB $VIRTUOSO_TEST/ident.txt >/dev/null
    then 
        VIRTUOSO_VDB=1
    else
        VIRTUOSO_VDB=0
    fi
fi

TEST_DIR_MASK=""
for CURRENT_VIRTUOSO_CAPACITY in $VIRTUOSO_CAPACITY
do
    for CURRENT_VIRTUOSO_TABLE_SCHEME in $VIRTUOSO_TABLE_SCHEME
    do
	BANNER "configuration $CURRENT_VIRTUOSO_CAPACITY, $CURRENT_VIRTUOSO_TABLE_SCHEME"
	
	GET_TEST_DIR_SUFFIX $CURRENT_VIRTUOSO_CAPACITY $CURRENT_VIRTUOSO_TABLE_SCHEME
	TEST_DIR_MASK="$TEST_DIR_MASK *.$GET_TEST_DIR_SUFFIX_RESULT"
	cfg=$GET_TEST_DIR_SUFFIX_RESULT
	
 	if [ -z "$test_to_run" ]
	then
	  $VIRTUOSO_TEST/testall.sh "$cfg"
	else
	  if [ "$test_type" = "sql" ]
	  then
	    RUN_SQL_TEST "$cfg" $test_to_run
	    KILL_TEST_INSTANCES
	  else
	    RUN_TEST "$cfg" $test_to_run
	    KILL_TEST_INSTANCES
	  fi
	fi

    done
done

# do the epilog
. epilog.sh

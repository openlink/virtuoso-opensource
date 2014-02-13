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

. ../test_fn.sh
LOGFILE=tpcd.output

CHECKPOINTS=OFF
DIVISOR=100
MULTIPLIER=1

LOAD_SUPPLIER ()
{
  n=0
  endval=`expr $MULTIPLIER \* 10000 / $DIVISOR`
  step=100

  while [ $n -lt $endval ]
    do
      remaining=`expr $endval - $n`
      if [ $remaining -gt 0 ]
	then
	  if [ $remaining -lt $step ]
	  then
            step=$remaining
	  fi
        fi
      pack_start=`expr $n + 1`
      pack_end=`expr $n + $step`
      echo $_ISQL PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT "EXEC=fill_supplier ($pack_start, $pack_end)" >> $LOGFILE
      $_ISQL "EXEC=fill_supplier ($pack_start, $pack_end)" >> $LOGFILE
      if test $? -ne 0
	then
	    LOG "***ABORTED: LOAD.sh -- fill_supplier"
	    exit 1
	fi
      n=`expr $n + $step`
      if [ z$CHECKPOINTS = zON ]
	then
	  echo $_ISQL "EXEC=checkpoint" >> $LOGFILE
	  $_ISQL "EXEC=checkpoint" >> $LOGFILE
	  if test $? -ne 0
	    then
		LOG "***ABORTED: LOAD.sh -- checkpoint"
		exit 1
	    fi
	 fi
      LOG "PASSED: Adding suppliers from $pack_start to $pack_end (from $endval)"
    done
  echo $_ISQL "EXEC=supplier_add_random ($MULTIPLIER.0 / $DIVISOR, $endval)" >> $LOGFILE
  $_ISQL "EXEC=supplier_add_random ($MULTIPLIER.0 / $DIVISOR, $endval)" >> $LOGFILE
  if test $? -ne 0
    then
	LOG "***ABORTED: LOAD.sh -- supplier_add_random"
	exit 1
    fi
  LOG "PASSED: Adding random Customer complaints"
}


LOAD_PART ()
{
  n=0
  endval=`expr $MULTIPLIER \* 200000 / $DIVISOR`
  step=1000

  while [ $n -lt $endval ]
    do
      remaining=`expr $endval - $n`
      if [ $remaining -gt 0 ]
	then
	  if [ $remaining -lt $step ]
	  then
            step=$remaining
	  fi
        fi
      pack_start=`expr $n + 1`
      pack_end=`expr $n + $step`
      echo $_ISQL "EXEC=fill_part ($pack_start, $pack_end)" >> $LOGFILE
      $_ISQL "EXEC=fill_part ($pack_start, $pack_end)" >> $LOGFILE
      if test $? -ne 0
	then
	    LOG "***ABORTED: LOAD.sh -- fill_part"
	    exit 1
	fi
      n=`expr $n + $step`
      if [ z$CHECKPOINTS = zON ]
	then
	  echo $_ISQL "EXEC=checkpoint" >> $LOGFILE
	  $_ISQL "EXEC=checkpoint" >> $LOGFILE
	  if test $? -ne 0
	    then
		LOG "***ABORTED: LOAD.sh -- checkpoint"
		exit 1
	    fi
	fi
      LOG "PASSED: Adding parts from $pack_start to $pack_end (from $endval)"
    done
}


LOAD_PARTSUPP ()
{
  n=0
  endval=`expr $MULTIPLIER \* 200000 / $DIVISOR`
  step=1000

  while [ $n -lt $endval ]
    do
      remaining=`expr $endval - $n`
      if [ $remaining -gt 0 ]
	then
	  if [ $remaining -lt $step ]
	  then
            step=$remaining
	  fi
        fi
      pack_start=`expr $n + 1`
      pack_end=`expr $n + $step`
      echo $_ISQL "EXEC=fill_partsupp ($MULTIPLIER.0 / $DIVISOR, $pack_start, $pack_end)" >> $LOGFILE
      $_ISQL "EXEC=fill_partsupp ($MULTIPLIER.0 / $DIVISOR, $pack_start, $pack_end)" >> $LOGFILE
      if test $? -ne 0
	then
	    LOG "***ABORTED: LOAD.sh -- fill_partsupp"
	    exit 1
	fi
      n=`expr $n + $step`
      if [ z$CHECKPOINTS = zON ]
	then
	  echo $_ISQL "EXEC=checkpoint" >> $LOGFILE
	  $_ISQL "EXEC=checkpoint" >> $LOGFILE
	  if test $? -ne 0
	    then
		LOG "***ABORTED: LOAD.sh -- checkpoint"
		exit 1
	    fi
	fi
      LOG "PASSED: Adding partsupps for part from $pack_start to $pack_end (from $endval)"
    done
}


LOAD_CUSTOMER ()
{
  n=0
  endval=`expr $MULTIPLIER \* 150000 / $DIVISOR`
  step=1000

  while [ $n -lt $endval ]
    do
      remaining=`expr $endval - $n`
      if [ $remaining -gt 0 ]
	then
	  if [ $remaining -lt $step ]
	  then
            step=$remaining
	  fi
        fi
      pack_start=`expr $n + 1`
      pack_end=`expr $n + $step`
      echo $_ISQL "EXEC=fill_customer ($pack_start, $pack_end)" >> $LOGFILE
      $_ISQL "EXEC=fill_customer ($pack_start, $pack_end)" >> $LOGFILE
      if test $? -ne 0
	then
	    LOG "***ABORTED: LOAD.sh -- fill_customer"
	    exit 1
	fi
      n=`expr $n + $step`
      if [ z$CHECKPOINTS = zON ]
	then
	  echo $_ISQL "EXEC=checkpoint" >> $LOGFILE
	  $_ISQL "EXEC=checkpoint" >> $LOGFILE
	  if test $? -ne 0
	    then
		LOG "***ABORTED: LOAD.sh -- checkpoint"
		exit 1
	    fi
	fi
      LOG "PASSED: Adding customers from $pack_start to $pack_end (from $endval)"
    done
}


LOAD_ORDERS ()
{
  n=0
  endval=`expr $MULTIPLIER \* 187500 / $DIVISOR`
  step=100

  while [ $n -lt $endval ]
    do
      remaining=`expr $endval - $n`
      if [ $remaining -gt 0 ]
	then
	  if [ $remaining -lt $step ]
	  then
            step=$remaining
	  fi
        fi
      pack_start=`expr $n + 1`
      pack_end=`expr $n + $step`
      echo $_ISQL "EXEC=fill_orders ($MULTIPLIER.0 / $DIVISOR, $pack_start, $pack_end)" >> $LOGFILE
      $_ISQL "EXEC=fill_orders ($MULTIPLIER.0 / $DIVISOR, $pack_start, $pack_end)" >> $LOGFILE
      if test $? -ne 0
	then
	    LOG "***ABORTED: LOAD.sh -- fill_orders"
	    exit 1
	fi
      n=`expr $n + $step`
      if [ z$CHECKPOINTS = zON ]
	then
	  echo $_ISQL "EXEC=checkpoint" >> $LOGFILE
	  $_ISQL "EXEC=checkpoint" >> $LOGFILE
	  if test $? -ne 0
	    then
		LOG "***ABORTED: LOAD.sh -- checkpoint"
		exit 1
	    fi
	fi
      LOG "PASSED: Adding order&lineitem groups from $pack_start to $pack_end (from $endval)"
    done
}

_DATABASE=$1
shift
_USER=$1
shift
_PASSWORD=$1
shift
_ISQL="$ISQL $_DATABASE $_USER $_PASSWORD VERBOSE=OFF ERRORS=STDOUT PROMPT=OFF"
action=$1
shift
DEFAULTPARAMS='integer=integer smallmoney="numeric(3,2)" largemoney="numeric(20,2)" datetime=datetime date=date'

case z$action
in
	ztables)
	    echo $_ISQL ./create_tables.sql -u $DEFAULTPARAMS $* >> $LOGFILE
	    $_ISQL ./create_tables.sql -u $DEFAULTPARAMS $* >> $LOGFILE
	    if test $? -ne 0
	      then
	        LOG "***ABORTED: LOAD.sh -- create_tables.sql"
	        exit 1
	      fi
	    LOG "PASSED: creating TPC-D tables"
	    ;;

	zindexes)
            echo $_ISQL ./create_indexes.sql $* >> $LOGFILE
            $_ISQL ./create_indexes.sql $* >> $LOGFILE
            echo $_ISQL ./create_partitions.sql $* >> $LOGFILE
            $_ISQL ./create_partitions.sql $* >> $LOGFILE
	    if test $? -ne 0
	      then
	        LOG "*** ABORTED: LOAD.sh -- create_indexes.sql"
	        exit 1
	      fi
	    LOG "PASSED: creating TPC-D indices"
	    ;;

	zprocedures)
	    echo $_ISQL create_procedures.sql >> $LOGFILE
	    $_ISQL create_procedures.sql >> $LOGFILE
	    if test $? -ne 0
	      then
	        LOG "*** ABORTED: LOAD.sh -- procedures.sql"
	        exit 1
	      fi
	    LOG "PASSED: creating TPC-D procedures"
	    ;;

	zcleantables)
	    own=$1
	    if [ z$own = z ]
            then
	      own=DBA
	    fi
	    echo $_ISQL "EXEC=drop table $own.CUSTOMER" "EXEC=drop table $own.HISTORY" "EXEC=drop table $own.LINEITEM" "EXEC=drop table $own.NATION" "EXEC=drop table $own.ORDERS" "EXEC=drop table $own.PART" "EXEC=drop table $own.PARTSUPP" "EXEC=drop table $own.REGION" "EXEC=drop table $own.SUPPLIER" >> $LOGFILE
	    $_ISQL "EXEC=drop table $own.CUSTOMER" "EXEC=drop table $own.HISTORY" "EXEC=drop table $own.LINEITEM" "EXEC=drop table $own.NATION" "EXEC=drop table $own.ORDERS" "EXEC=drop table $own.PART" "EXEC=drop table $own.PARTSUPP" "EXEC=drop table $own.REGION" "EXEC=drop table $own.SUPPLIER" >> $LOGFILE
	    if test $? -ne 0
	      then
	        LOG "***ABORTED: LOAD.sh -- clean tables"
	        exit 1
	      fi
	    LOG "PASSED: dropping TPC-D tables"
	    ;;

	zcleandata)
	    echo $_ISQL "EXEC=delete from CUSTOMER" "EXEC=delete from HISTORY" "EXEC=delete from LINEITEM" "EXEC=delete from NATION" "EXEC=delete from ORDERS" "EXEC=delete from PART" "EXEC=delete from PARTSUPP" "EXEC=delete from REGION" "EXEC=delete from SUPPLIER" >> $LOGFILE
	    $_ISQL "EXEC=delete from CUSTOMER" "EXEC=delete from HISTORY" "EXEC=delete from LINEITEM" "EXEC=delete from NATION" "EXEC=delete from ORDERS" "EXEC=delete from PART" "EXEC=delete from PARTSUPP" "EXEC=delete from REGION" "EXEC=delete from SUPPLIER" >> $LOGFILE
	    if test $? -ne 0
	      then
	        LOG "***ABORTED: LOAD.sh -- clean data"
	        exit 1
	      fi
	    LOG "PASSED: deleting TPC-D data"
	    ;;

	zcleanprocedures)
	    echo $_ISQL "EXEC=drop procedure fill_customer" "EXEC=drop procedure fill_lineitems_for_order" "EXEC=drop procedure fill_nation" "EXEC=drop procedure fill_orders" "EXEC=drop procedure fill_part" "EXEC=drop procedure fill_partsupp" "EXEC=drop procedure fill_region" "EXEC=drop procedure fill_supplier" "EXEC=drop procedure randomContainer" "EXEC=drop procedure randomInstruction" "EXEC=drop procedure randomMode" "EXEC=drop procedure randomNumber" "EXEC=drop procedure randomNumeric" "EXEC=drop procedure randomPhone" "EXEC=drop procedure randomPrioprity" "EXEC=drop procedure randomSegment" "EXEC=drop procedure random_aString" "EXEC=drop procedure random_vString" "EXEC=drop procedure randomText" "EXEC=drop procedure randomType" "EXEC=drop procedure supplier_add_random" >> $LOGFILE
	    $_ISQL "EXEC=drop procedure fill_customer" "EXEC=drop procedure fill_lineitems_for_order" "EXEC=drop procedure fill_nation" "EXEC=drop procedure fill_orders" "EXEC=drop procedure fill_part" "EXEC=drop procedure fill_partsupp" "EXEC=drop procedure fill_region" "EXEC=drop procedure fill_supplier" "EXEC=drop procedure randomContainer" "EXEC=drop procedure randomInstruction" "EXEC=drop procedure randomMode" "EXEC=drop procedure randomNumber" "EXEC=drop procedure randomNumeric" "EXEC=drop procedure randomPhone" "EXEC=drop procedure randomPrioprity" "EXEC=drop procedure randomSegment" "EXEC=drop procedure random_aString" "EXEC=drop procedure random_vString" "EXEC=drop procedure randomText" "EXEC=drop procedure randomType" "EXEC=drop procedure supplier_add_random" >> $LOGFILE
	    if test $? -ne 0
	      then
	        LOG "***ABORTED: LOAD.sh -- clean procedures"
	        exit 1
	      fi
	    LOG "PASSED: dropping TPC-D procedures"
	    ;;

	zload)
	    multiplier=$1
	    if [ z$multiplier != z ]
	    then
	      MULTIPLIER=$multiplier
	    fi
	    divisor=$2
	    if [ z$divisor != z ]
	    then
	      DIVISOR=$divisor
	    fi

	    echo $_ISQL "EXEC=randomize(1)" >> $LOGFILE
	    $_ISQL "EXEC=randomize(1)" >> $LOGFILE
	    if test $? -ne 0
	      then
	        LOG "***ABORTED: LOAD.sh -- randomize"
	        exit 1
	      fi
	    LOAD_SUPPLIER
	    LOAD_PART
	    LOAD_PARTSUPP
	    LOAD_CUSTOMER
	    LOAD_ORDERS
	    echo $_ISQL "EXEC=fill_nation(0)" >> $LOGFILE
	    $_ISQL "EXEC=fill_nation(0)" >> $LOGFILE
	    if test $? -ne 0
	      then
	        LOG "***ABORTED: LOAD.sh -- fill_nation"
	        exit 1
	      fi
	    LOG "PASSED: loading nation"
	    echo $_ISQL "EXEC=fill_region(0)" >> $LOGFILE
	    $_ISQL "EXEC=fill_region(0)" >> $LOGFILE
	    if test $? -ne 0
	      then
	        LOG "***ABORTED: LOAD.sh -- fill_region"
	        exit 1
	      fi
	    LOG "PASSED: loading region"
	    ;;

	zattach)
	    dsn=$1
	    uid=$2
	    pass=$3
	    if [ z$dsn != z ]
	    then
	       if [ z$uid != z ]
               then
	         echo $_ISQL "EXEC=attach table CUSTOMER from '$dsn' user '$uid' password '$pass'" >> $LOGFILE
	         $_ISQL "EXEC=attach table CUSTOMER from '$dsn' user '$uid' password '$pass'" >> $LOGFILE
		 if test $? -ne 0
		   then
		     LOG "***ABORTED: LOAD.sh -- attach CUSTOMER table"
		     exit 1
		   fi
		 LOG "PASSED: attaching the customer table from $dsn"
	       else
	         echo $_ISQL "EXEC=attach table CUSTOMER from '$dsn'" >> $LOGFILE
	         $_ISQL "EXEC=attach table CUSTOMER from '$dsn'" >> $LOGFILE
		 if test $? -ne 0
		   then
		     LOG "***ABORTED: LOAD.sh -- attach CUSTOMER table"
		     exit 1
		   fi
		 LOG "PASSED: attaching the customer table from $dsn"
	       fi

	       echo $_ISQL "EXEC=attach table HISTORY from '$dsn'" "EXEC=attach table LINEITEM from '$dsn'" "EXEC=attach table NATION from '$dsn'" "EXEC=attach table ORDERS from '$dsn'" "EXEC=attach table PART from '$dsn'" "EXEC=attach table PARTSUPP from '$dsn'" "EXEC=attach table REGION from '$dsn'" "EXEC=attach table SUPPLIER from '$dsn'" >> $LOGFILE
	       $_ISQL "EXEC=attach table HISTORY from '$dsn'" "EXEC=attach table LINEITEM from '$dsn'" "EXEC=attach table NATION from '$dsn'" "EXEC=attach table ORDERS from '$dsn'" "EXEC=attach table PART from '$dsn'" "EXEC=attach table PARTSUPP from '$dsn'" "EXEC=attach table REGION from '$dsn'" "EXEC=attach table SUPPLIER from '$dsn'" >> $LOGFILE
		if test $? -ne 0
		  then
		    LOG "***ABORTED: LOAD.sh -- attach tables"
		    exit 1
		  fi
		 LOG "PASSED: attaching other TPC-D tables from $dsn"
	    else
	       LOG "No DSN specified for attach"
	    fi
	    ;;

	zcopy)
	    dsn=$1
	    if [ z$dsn != z ]
	    then
	       echo $_ISQL "EXEC=insert into $dsn.CUSTOMER select * from DBA.CUSTOMER" "EXEC=insert into $dsn.HISTORY select * from DBA.HISTORY" "EXEC=insert into $dsn.LINEITEM select * from DBA.LINEITEM" "EXEC=insert into $dsn.NATION select * from DBA.NATION" "EXEC=insert into $dsn.ORDERS select * from DBA.ORDERS" "EXEC=insert into $dsn.PART select * from DBA.PART" "EXEC=insert into $dsn.PARTSUPP select * from DBA.PARTSUPP" "EXEC=insert into $dsn.REGION select * from DBA.REGION" "EXEC=insert into $dsn.SUPPLIER select * from DBA.SUPPLIER" >> $LOGFILE
	       $_ISQL "EXEC=insert into $dsn.CUSTOMER select * from DBA.CUSTOMER" "EXEC=insert into $dsn.HISTORY select * from DBA.HISTORY" "EXEC=insert into $dsn.LINEITEM select * from DBA.LINEITEM" "EXEC=insert into $dsn.NATION select * from DBA.NATION" "EXEC=insert into $dsn.ORDERS select * from DBA.ORDERS" "EXEC=insert into $dsn.PART select * from DBA.PART" "EXEC=insert into $dsn.PARTSUPP select * from DBA.PARTSUPP" "EXEC=insert into $dsn.REGION select * from DBA.REGION" "EXEC=insert into $dsn.SUPPLIER select * from DBA.SUPPLIER" >> $LOGFILE
		if test $? -ne 0
		  then
		    LOG "***ABORTED: LOAD.sh -- copy tables"
		    exit 1
		  fi
	       LOG "PASSED: copying tables into $dsn"
	    else
	       LOG "No DSN specified for copy"
	    fi
	    ;;

	z*)
    	    LOG "usage $0 database username password (tables | indexes | procedures | cleanprocedures | cleantables | cleandata | load | attach )"
	    ;;
esac

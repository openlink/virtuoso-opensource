#!/bin/sh
#  
#  $Id$
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2009 OpenLink Software
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

usage() {
  echo "Usage:" 
  echo  "run n transactions: -r <database> <user> <password> <num_clients> <num_transactions>"
}

case $1 in 
   -r) #run tests
	count=1
	while [ "$count" -lt "$5" ]
	  do
	    tpcc $2 $3 $4 r $6  > tpcc-client.$count &
	     count=`expr $count + 1`   
	  done
	tpcc $2 $3 $4 r $6 | tee tpcc-client.$5 
	tpcc $2 $3 $4 d $6 | tee tpcc-client.del
	echo "===== RESULTS ====="
	for index in tpcc-client.*
	  do
	    echo $index
	    grep "#" $index
	    echo "-------------------"
	  done
	;;

   *) usage
	;;

esac

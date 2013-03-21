#!/bin/sh
#
#  $Id$
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2013 OpenLink Software
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
isql 1111 < ./tpminit.sql >tpm.out 

 
../tpcc 1111 dba dba r 1000000 1 40 &
../tpcc 1111 dba dba r 1000000 2 40 &
../tpcc 1111 dba dba r 1000000 3 40 &
../tpcc 1111 dba dba r 1000000 4 40 &
../tpcc 1111 dba dba r 1000000 5 40 &
../tpcc 1111 dba dba r 1000000 6 40 &
../tpcc 1111 dba dba r 1000000 7 40 &
../tpcc 1111 dba dba r 1000000 8 40 &
../tpcc 1111 dba dba r 1000000 9 40 &
../tpcc 1111 dba dba r 1000000 10 40 &

sleep 1


../tpcc 1111 dba dba r 1000000 11 40 &
../tpcc 1111 dba dba r 1000000 12 40 &
../tpcc 1111 dba dba r 1000000 13 40 &
../tpcc 1111 dba dba r 1000000 14 40 &
../tpcc 1111 dba dba r 1000000 15 40 &
../tpcc 1111 dba dba r 1000000 16 40 &
../tpcc 1111 dba dba r 1000000 17 40 &
../tpcc 1111 dba dba r 1000000 18 40 &
../tpcc 1111 dba dba r 1000000 19 40 &
../tpcc 1111 dba dba r 1000000 20 40 &

sleep 1


../tpcc 1111 dba dba r 1000000 21 40 &
../tpcc 1111 dba dba r 1000000 22 40 &
../tpcc 1111 dba dba r 1000000 23 40 &
../tpcc 1111 dba dba r 1000000 24 40 &
../tpcc 1111 dba dba r 1000000 25 40 &
../tpcc 1111 dba dba r 1000000 26 40 &
../tpcc 1111 dba dba r 1000000 27 40 &
../tpcc 1111 dba dba r 1000000 28 40 &
../tpcc 1111 dba dba r 1000000 29 40 &
../tpcc 1111 dba dba r 1000000 30 40 &

sleep 1


../tpcc 1111 dba dba r 1000000 31 40 &
../tpcc 1111 dba dba r 1000000 32 40 &
../tpcc 1111 dba dba r 1000000 33 40 &
../tpcc 1111 dba dba r 1000000 34 40 &
../tpcc 1111 dba dba r 1000000 35 40 &
../tpcc 1111 dba dba r 1000000 36 40 &
../tpcc 1111 dba dba r 1000000 37 40 &
../tpcc 1111 dba dba r 1000000 38 40 &
../tpcc 1111 dba dba r 1000000 39 40 &
../tpcc 1111 dba dba r 1000000 40 40 &

sleep 



../tpcc 1111 dba dba r 1000000 1 40 &
../tpcc 1111 dba dba r 1000000 2 40 &
../tpcc 1111 dba dba r 1000000 3 40 &
../tpcc 1111 dba dba r 1000000 4 40 &
../tpcc 1111 dba dba r 1000000 5 40 &
../tpcc 1111 dba dba r 1000000 6 40 &
../tpcc 1111 dba dba r 1000000 7 40 &
../tpcc 1111 dba dba r 1000000 8 40 &
../tpcc 1111 dba dba r 1000000 9 40 &
../tpcc 1111 dba dba r 1000000 10 40 &

sleep 1


../tpcc 1111 dba dba r 1000000 11 40 &
../tpcc 1111 dba dba r 1000000 12 40 &
../tpcc 1111 dba dba r 1000000 13 40 &
../tpcc 1111 dba dba r 1000000 14 40 &
../tpcc 1111 dba dba r 1000000 15 40 &
../tpcc 1111 dba dba r 1000000 16 40 &
../tpcc 1111 dba dba r 1000000 17 40 &
../tpcc 1111 dba dba r 1000000 18 40 &
../tpcc 1111 dba dba r 1000000 19 40 &
../tpcc 1111 dba dba r 1000000 20 40 &

sleep 1


../tpcc 1111 dba dba r 1000000 21 40 &
../tpcc 1111 dba dba r 1000000 22 40 &
../tpcc 1111 dba dba r 1000000 23 40 &
../tpcc 1111 dba dba r 1000000 24 40 &
../tpcc 1111 dba dba r 1000000 25 40 &
../tpcc 1111 dba dba r 1000000 26 40 &
../tpcc 1111 dba dba r 1000000 27 40 &
../tpcc 1111 dba dba r 1000000 28 40 &
../tpcc 1111 dba dba r 1000000 29 40 &
../tpcc 1111 dba dba r 1000000 30 40 &

sleep 1


../tpcc 1111 dba dba r 1000000 31 40 &
../tpcc 1111 dba dba r 1000000 32 40 &
../tpcc 1111 dba dba r 1000000 33 40 &
../tpcc 1111 dba dba r 1000000 34 40 &
../tpcc 1111 dba dba r 1000000 35 40 &
../tpcc 1111 dba dba r 1000000 36 40 &
../tpcc 1111 dba dba r 1000000 37 40 &
../tpcc 1111 dba dba r 1000000 38 40 &
../tpcc 1111 dba dba r 1000000 39 40 &
../tpcc 1111 dba dba r 1000000 40 40 &

sleep 
isql 1111 errors=stdout < tpm.sql >>tpm.out 
isql 1111 errors=stdout < tpmfinal.sql >>tpm.out 




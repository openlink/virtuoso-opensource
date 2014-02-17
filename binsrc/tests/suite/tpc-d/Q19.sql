--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2014 OpenLink Software
--  
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--  
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--  
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--  
--  
delete from OUT_Q19;

insert into OUT_Q19 select
	sum(l_extendedprice * (1 - l_discount) ) as revenue
from
	part,
	lineitem
where
	(
	 p_partkey = l_partkey
	 and p_brand = 'Brand#12'
	 and p_container in ( 'SM CASE', 'SM BOX', 'SM PACK', 'SM PKG')
	 and l_quantity >= 1 and l_quantity <= 1 + 10
	 and p_size between 1 and 5
	 and l_shipmode in ('AIR', 'AIR REG')
	 and l_shipinstruct = 'DELIVER IN PERSON'
	 )
	or
	(
	 p_partkey = l_partkey
	 and p_brand = 'Brand#23'
	 and p_container in ('MED BAG', 'MED BOX', 'MED PKG', 'MED PACK')
	 and l_quantity >= 10 and l_quantity <= 10 + 10
	 and p_size between 1 and 10
	 and l_shipmode in ('AIR', 'AIR REG')
	 and l_shipinstruct = 'DELIVER IN PERSON'
	 )
	or
	(
	 p_partkey = l_partkey
	 and p_brand = 'Brand#34'
	 and p_container in ( 'LG CASE', 'LG BOX', 'LG PACK', 'LG PKG')
	 and l_quantity >= 20 and l_quantity <= 20 + 10
	 and p_size between 1 and 15
	 and l_shipmode in ('AIR', 'AIR REG')
	 and l_shipinstruct = 'DELIVER IN PERSON'
	 );

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q19\n";

select cmp ('MS_OUT_Q19', 'OUT_Q19');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  Result from Q19 \n";


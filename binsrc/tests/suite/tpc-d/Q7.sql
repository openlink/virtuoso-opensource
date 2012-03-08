--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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
delete from OUT_Q7;

insert into OUT_Q7 select
	supp_nation,
	cust_nation,
	l_year,
	sum(volume) as revenue
from (
	select
		n1.n_name as supp_nation,
		n2.n_name as cust_nation,
		{fn year (l_shipdate)} as l_year,
		l_extendedprice * (1 - l_discount) as volume
	from
		nation n2,
		nation n1,
		customer,
		orders,
		lineitem,
		supplier
	where
		s_suppkey = l_suppkey
		and o_orderkey = l_orderkey
		and c_custkey = o_custkey
		and s_nationkey = n1.n_nationkey
		and c_nationkey = n2.n_nationkey
		and (
			(n1.n_name = 'FRANCE' and n2.n_name = 'GERMANY')
			or (n1.n_name = 'GERMANY' and n2.n_name = 'FRANCE')
			)
		and l_shipdate between {d '1995-01-01'} and {d '1996-12-31'}
		) shipping
	group by
		supp_nation,
		cust_nation,
		l_year
	order by
		supp_nation,
		cust_nation,
		l_year;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q7\n";

select cmp ('MS_OUT_Q7', 'OUT_Q7');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  Result from Q7 \n";


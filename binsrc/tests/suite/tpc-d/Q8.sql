--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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
delete from OUT_Q8;

insert into OUT_Q8 select
        o_year,
	sum1 / sum2 as mkt_share
  from (
        select
	o_year,
	sum(case
		when nation = 'BRAZIL'
			then volume
		else 0
		end) as sum1 ,
   	sum(volume) as sum2
            from (
		select
		        {fn year (o_orderdate)} as o_year,
			l_extendedprice * (1-l_discount) as volume,
			n2.n_name as nation
		from
			region,
			nation n2,
			nation n1,
			customer,
			orders,
			lineitem,
			supplier,
			part
		where
			p_partkey = l_partkey
			and s_suppkey = l_suppkey
			and l_orderkey = o_orderkey
			and o_custkey = c_custkey
			and c_nationkey = n1.n_nationkey
			and n1.n_regionkey = r_regionkey
			and r_name = 'AMERICA'
			and s_nationkey = n2.n_nationkey
			and o_orderdate between {d '1995-01-01'} and {d '1996-12-31'}
			and p_type = 'ECONOMY ANODIZED STEEL'
	) all_nations
group by
	o_year
	) test
order by
	o_year
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q8\n";

select cmp ('MS_OUT_Q8', 'OUT_Q8');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  Result from Q8 \n";


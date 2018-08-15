--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2018 OpenLink Software
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
delete from OUT_Q12;

-- insert into OUT_Q12 
select
	l_shipmode,
	sum(case
			when o_orderpriority ='1-URGENT'
			or o_orderpriority ='2-HIGH'
			then 1
			else 0
	end) as high_line_count,
	sum(case
			when o_orderpriority <> '1-URGENT'
			and o_orderpriority <> '2-HIGH'
			then 1
			else 0
	end) as low_line_count
from
	lineitem,
	orders
where
	o_orderkey = l_orderkey
	and l_shipmode in ('MAIL', 'SHIP')
	and l_commitdate < l_receiptdate
	and l_shipdate < l_commitdate
	and l_receiptdate >= {d '1994-01-01'}
	and l_receiptdate < {fn timestampadd (SQL_TSI_YEAR, 1, {d '1994-01-01'})}
group by
	l_shipmode
order by
	l_shipmode;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q12\n";

select cmp ('MS_OUT_Q12', 'OUT_Q12');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  Result from Q12 \n";


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
delete from OUT_Q11;

--insert into OUT_Q11 
select
	ps_partkey,
	sum(ps_supplycost * ps_availqty) as value
from
	nation,
	supplier,
	partsupp
where
	ps_suppkey = s_suppkey
	and s_nationkey = n_nationkey
	and n_name = 'GERMANY'
group by
	ps_partkey
having
	sum(ps_supplycost * ps_availqty) > (
		select
			sum(ps_supplycost * ps_availqty) * 0.0001
		from
			nation,
			supplier,
			partsupp
		where
			ps_suppkey = s_suppkey
			and s_nationkey = n_nationkey
			and n_name = 'GERMANY'
		)
order by
	value desc;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q11\n";

select cmp ('MS_OUT_Q11', 'OUT_Q11');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  Result from Q11 \n";


--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2017 OpenLink Software
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
delete from OUT_Q14;

--insert into OUT_Q14 
select
	100 * sum(case
		when p_type like 'PROMO%'
			then l_extendedprice*(1-l_discount)
		else 0.0
	end) /
	sum(l_extendedprice * (1 - l_discount)) as promo_revenue
from
	part,
	lineitem
where
	l_partkey = p_partkey
	and l_shipdate >= {d '1995-09-01'}
	and l_shipdate < {fn timestampadd (SQL_TSI_MONTH, 1, {d '1995-09-01'})};

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q14\n";

select cmp ('MS_OUT_Q14', 'OUT_Q14');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  Result from Q14 \n";


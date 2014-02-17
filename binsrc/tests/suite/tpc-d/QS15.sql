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
delete from OUT_Q15;

--insert into OUT_Q15 
select
  s_suppkey,
  s_name,
  s_address,
  s_phone,
  total_revenue
from
  supplier,
  (
    select
      l_suppkey as supplier_no,
      sum(l_extendedprice * (1 - l_discount)) as total_revenue
    from
      lineitem
    where
      l_shipdate >= {d '1996-01-01'} and
      l_shipdate < {fn timestampadd (SQL_TSI_MONTH, 3, {d '1996-01-01'})}
    group by
      l_suppkey
  ) as revenue
where
  s_suppkey = supplier_no and
  total_revenue =
  (
    select
      max(total_revenue)
    from
      (
        select
          l_suppkey as supplier_no,
          sum(l_extendedprice * (1 - l_discount)) as total_revenue
        from
          lineitem
        where
          l_shipdate >= {d '1996-01-01'} and
	  l_shipdate < {fn timestampadd (SQL_TSI_MONTH, 3, {d '1996-01-01'})}
	group by
          l_suppkey
      ) as revenue
  )
order by
  s_suppkey;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q15\n";

select cmp ('MS_OUT_Q15', 'OUT_Q15');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  Result from Q15 \n";


--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2015 OpenLink Software
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
delete from OUT_Q22;

--insert into OUT_Q22 
select
  cntrycode,
  count (*) as numcust,
  sum (c_acctbal) as totacctbal
from
  (
    select
      {fn substring (c_phone, 1, 2)} as cntrycode,
      c_acctbal
    from
      customer
    where
      {fn substring (c_phone, 1, 2)} in
        ('13', '35', '31', '23', '29', '30', '17', '18') and
      c_acctbal >
        (
	  select
	    avg (c_acctbal)
	  from
	    customer
	  where
	    c_acctbal > 0.00 and
	    {fn substring (c_phone, 1, 2)} in
	      ('13', '35', '31', '23', '29', '30', '17', '18')
	) and
      not exists
        (
          select
	    *
	  from
	    orders
	  where
	    o_custkey = c_custkey
	)
  ) as custsale
group by
  cntrycode
order by
  cntrycode;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Q22\n";

select cmp ('MS_OUT_Q22', 'OUT_Q22');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  Result from Q22 \n";


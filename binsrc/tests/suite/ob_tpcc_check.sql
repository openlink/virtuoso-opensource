--
--  $Id: ob_tpcc_check.sql,v 1.5.10.1 2013/01/02 16:14:49 source Exp $
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
select backup_pages();
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH " pages changed since last backup (in checkpoint space) = " $LAST[1] "\n";

create procedure xcheck (in xname varchar, in xval any)
{
  for select val from xvals where name = xname do {
	if (xval = val)
	{
	  dbg_printf ('val = %ld\n', xval);
	  return 'EQUALS';
	}
  }
  return 'NOTEQUAL';
}
;

select count (*) from xvals;


select xcheck('tax', common_tax());
ECHO BOTH $IF $EQU $LAST[1] "EQUALS" "PASSED" "***FAILED";
ECHO BOTH " tax is " $LAST[1] "\n";

select xcheck('tax2', common_tax_2());
ECHO BOTH $IF $EQU $LAST[1] "EQUALS" "PASSED" "***FAILED";
ECHO BOTH " tax2 is " $LAST[1] "\n";

select xcheck('bal', common_bal());
ECHO BOTH $IF $EQU $LAST[1] "EQUALS" "PASSED" "***FAILED";
ECHO BOTH " bal is " $LAST[1] "\n";

--select xcheck('amnt', common_amnt());
--ECHO BOTH $IF $EQU $LAST[1] "EQUALS" "PASSED" "***FAILED";
--ECHO BOTH " amnt is " $LAST[1] "\n";

--select xcheck('bal2', common_bal2());
--ECHO BOTH $IF $EQU $LAST[1] "EQUALS" "PASSED" "***FAILED";
--ECHO BOTH " bal2 is " $LAST[1] "\n";

--select xcheck('quant', common_quant());
--ECHO BOTH $IF $EQU $LAST[1] "EQUALS" "PASSED" "***FAILED";
--ECHO BOTH " quant is " $LAST[1] "\n";

select count (*) from warehouse;
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
ECHO BOTH " count (warehouse) = " $LAST[1] "\n";


create procedure check_orders (in cc integer)
{
  for select val from xvals where name = 'orders' do {
	if (val = cc)
	{
	  return 'EQUAL';
	}
  }
  return 'NOT EQUAL';
}
;
select check_orders (count_orders());
ECHO BOTH $IF $EQU $LAST[1] "EQUAL" "PASSED" "***FAILED";
ECHO BOTH " count (orders) = " $LAST[1] "\n";

select count (*) from item;
ECHO BOTH $IF $EQU $LAST[1] 100000 "PASSED" "***FAILED";
ECHO BOTH " count (item) = " $LAST[1] "\n";

select count (*) from stock;
ECHO BOTH $IF $EQU $LAST[1] 1000000 "PASSED" "***FAILED";
ECHO BOTH " count (stock) = " $LAST[1] "\n";


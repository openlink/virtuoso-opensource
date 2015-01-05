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

select sum (c_balance) from customer;
ECHO BOTH $IF $EQU $LAST[1] "60623096.869332973743172" "PASSED" "***FAILED";
ECHO BOTH " Customers balances sum " $LAST[1] "\n";

select sum (c_balance*c_balance) from customer;
ECHO BOTH $IF $EQU $LAST[1] "3408067652546.685722996340458" "PASSED" "***FAILED";
ECHO BOTH " Customers sqr(balances) sum " $LAST[1] "\n";


select sum (s_quantity) from stock;
ECHO BOTH $IF $EQU $LAST[1] "5386485" "PASSED" "***FAILED";
ECHO BOTH " Stock quantity sum " $LAST[1] "\n";

select sum (s_quantity*s_quantity) from stock;
ECHO BOTH $IF $EQU $LAST[1] "360123821" "PASSED" "***FAILED";
ECHO BOTH " Stock sqr(quantity) sum " $LAST[1] "\n";

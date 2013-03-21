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
echo BOTH "second update tpcc database\n";

update warehouse set w_tax = notrandom_tax (w_id, 31);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " UPDATE WAREHOUSE STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update district set d_tax = notrandom_tax_2 (d_id, d_w_id , 31);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " UPDATE DISTRICT STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update customer set c_balance = notrandom_bal (c_id, 29);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " UPDATE CUSTOMER STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- update order_line set ol_amount = notrandom_amount (ol_o_id, 23);
-- update item set i_price = notrandom_amount (i_id, 17);
-- update stock set s_quantity = notrandom_quantity (s_i_id, s_w_id, 13);


update xvals set val = common_tax() where name = 'tax';
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " CALCULATE COMMON TAX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update xvals set val = common_tax_2() where name = 'tax2';
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " CALCULATE COMMON TAX 2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update xvals set val = common_bal() where name = 'bal';
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " CALCULATE COMMON BAL STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- update xvals set val = common_amnt() where name = 'amnt';
-- update xvals set val = common_bal2() where name = 'bal2';
-- update xvals set val = common_quant() where name = 'quant';


backup_context_clear();
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " BACKUP_CONTEXT_CLEAR STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select backup_pages();
echo BOTH " pages to be backed up = " $LAST[1] "\n";

backup_online ('tpcc_i_#', 7000);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " BACKUP_ONLINE STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select (*) from xvals;

echo BOTH "done...\n";

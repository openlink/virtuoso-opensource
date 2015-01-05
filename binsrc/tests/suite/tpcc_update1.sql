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
update customer set c_balance = notrandom_bal (c_id, 23);
ECHO BOTH $IF $EQU $STATE "OK"  "PASSED" "***FAILED";
ECHO BOTH " UPDATE CUSTOMER STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- update order_line set ol_amount = notrandom_amount (ol_w_id, ol_d_id, ol_o_id, ol_number, 29);
-- update item set i_price = notrandom_bal (i_id, 31);
-- update stock set s_quantity = notrandom_quantity (s_i_id, s_w_id, 37);

insert into xvals values ('tax', common_tax());
ECHO BOTH $IF $EQU $STATE "OK"  "PASSED" "***FAILED";
ECHO BOTH " CALCULATE COMMON TAX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


checkpoint;
ECHO BOTH $IF $EQU $STATE "OK"  "PASSED" "***FAILED";
ECHO BOTH " CHECKPOINT STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

backup_online ('tpcc_k_#', 5000);
ECHO BOTH $IF $EQU $STATE "OK"  "PASSED" "***FAILED";
ECHO BOTH " BACKUP ONLINE STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into xvals values ('tax2', common_tax_2());
ECHO BOTH $IF $EQU $STATE "OK"  "PASSED" "***FAILED";
ECHO BOTH " CALCULATE COMMON TAX 2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into xvals values ('bal', common_bal());
ECHO BOTH $IF $EQU $STATE "OK"  "PASSED" "***FAILED";
ECHO BOTH " CALCULATE COMMON BAL STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into xvals values ('orders', count_orders());
ECHO BOTH $IF $EQU $STATE "OK"  "PASSED" "***FAILED";
ECHO BOTH " CALCULATE COUNT OF ORDERS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;
ECHO BOTH $IF $EQU $STATE "OK"  "PASSED" "***FAILED";
ECHO BOTH " CHECKPOINT STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


drop table item;
delete from customer;

select (*) from xvals;

-- insert into xvals values ('amnt', common_amnt());
-- insert into xvals values ('bal2', common_bal2());
-- insert into xvals values ('quant', common_quant());

backup_online ('tpcc_k_#', 5000);
ECHO BOTH $IF $EQU $STATE "OK"  "PASSED" "***FAILED";
ECHO BOTH " BACKUP ONLINE STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

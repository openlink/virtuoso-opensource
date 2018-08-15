--
--  $Id: tpcc_update.sql,v 1.5.10.1 2013/01/02 16:15:16 source Exp $
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

create procedure notrandom_tax (in id integer, in seed integer)
{
  return ((id*13) - ((id*13) / seed) * seed) / 100.0;
}
;

create procedure notrandom_tax_2 (in id integer, in id2 integer, in seed integer)
{
  return ( (id*id2) - ((id*id2) / seed ) * seed) / 100.0;
}
;

create procedure notrandom_bal (in id integer, in seed integer)
{
  return (id*31) - ((id*31) / seed ) * seed;
}
;

create procedure notrandom_amount (in w_id ineger, in d_id integer, in o_id integer,
	in number integer, in seed integer)
{
  return ( w_id + d_id + o_id + number + seed ) / 10;
}
;

create procedure notrandom_quantity (in id integer, in id2 integer, in seed integer)
{
  return ( id + id2 ) - ((id+id2)*seed)/seed;
}
;

create procedure common_tax ()
{
  declare commontx number;
  commontx := 0.00;
  for select w_tax from warehouse do {
	commontx := commontx + w_tax;
  }
  return commontx;
}
;

create procedure common_tax_2 ()
{
  declare commontx number;
  commontx := 0.00;
  for select d_tax from district do {
	commontx := commontx + d_tax;
  }
  return commontx;
}
;

create procedure common_bal ()
{
  declare commonb integer;
  commonb := 0;
  for select c_balance from customer do {
	commonb := commonb + c_balance;
  }
  return commonb;
}
;
create procedure common_bal2 ()
{
  declare commonb integer;
  commonb := 0;
  for select i_price from item do {
	commonb := commonb + i_price;
  }
  return commonb;
}
;

create procedure common_quant ()
{
  declare commonq integer;
  commonq := 0;
  for select s_quantity from stock do {
	commonq := commonq + s_quantity;
  }
  return commonq;
}
;
create procedure common_amnt ()
{
  declare commonq integer;
  commonq := 0;
  for select ol_amount from order_line do {
	commonq := commonq + ol_amount;
  }
  return commonq;
}
;

create procedure count_orders()
{
  for select count (*) as c from orders do {
	return c;
  }
  return 0;
}
;

backup_context_clear();
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH " BACKUP_CONTEXT_CLEAR() STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table xvals;
create table xvals (name varchar, val any);

update warehouse set w_tax = notrandom_tax (w_id, 13);
ECHO BOTH $IF $EQU $STATE "OK"  "PASSED" "***FAILED";
ECHO BOTH " UPDATE WAREHOUSE STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update district set d_tax = notrandom_tax_2 (d_id, d_w_id , 17);
ECHO BOTH $IF $EQU $STATE "OK"  "PASSED" "***FAILED";
ECHO BOTH " UPDATE DISTRICT STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

checkpoint;
ECHO BOTH $IF $EQU $STATE "OK"  "PASSED" "***FAILED";
ECHO BOTH " CHECKPOINT STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

backup_online ('tpcc_k_#', 5000);
ECHO BOTH $IF $EQU $STATE "OK"  "PASSED" "***FAILED";
ECHO BOTH " BACKUP ONLINE STATE=" $STATE " MESSAGE=" $MESSAGE "\n";






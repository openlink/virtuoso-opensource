--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2016 OpenLink Software
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

drop table DB.DSDB.orders;
attach table DB.DBA.orders as DB.DSDB.orders from '$U{DSDB}' user 'dba' password 'dba';

delete from td_orders;
delete from DB.DSDB.orders where o_id > 3000;

sequence_set ('BPELTPCC_OID', 3001, 1);


create procedure make_new_order ()
{
  declare x, y numeric;
  declare did, oid, cid numeric;
  did := rnd (10) + 1;
  oid := sequence_next ('BPELTPCC_OID');
  cid := rnd (3000) + 1;
  x := (1000000000.0 * did) + oid;
  y := (1000000 * did) + cid;
  --dbg_printf ('%.0f %.0f', x, y);
  order_begin (x, y);
  return x;
}
;

create procedure do_test (in l int := 1000, in l2 int := 100)
{
  declare i, cnt, fcnt int;
  registry_set ('BPELTPCC_st', 'fill');
  dbg_printf ('Filling set of new orders');
  update td_state set td_oorders_ok = 0, td_orders_failed = 0, td_receipts = 0;
  for (i := 0; i < l; i := i + 1)
   {
     make_new_order ();
   }
  select top 1 td_oorders_ok, td_orders_failed into cnt, fcnt from td_state;
  registry_set ('BPELTPCC_st', 'go');
  dbg_printf ('Process new orders');
  --update td_state set td_oorders_ok = 0, td_orders_failed = 0, td_receipts = 0;
  for (i := 0; i < l2; i := i + 1)
   {
     make_new_order ();
     --if (0 = mod (i, 10))
     --  asyncDelivery ();
   }
  dbg_printf ('Finished, starting delivery');
  while (1)
   {
     declare ok, fail, rec int;
     select top 1 td_oorders_ok, td_orders_failed, td_receipts into ok, fail, rec from td_state;
     dbg_obj_print ('ok=',ok, ' fail=',fail, ' rec=', rec);
     if (rec+(fail-fcnt) >= l2)
       return;
     commit work;
     asyncDelivery ();
     delay (1);
   }
}
;


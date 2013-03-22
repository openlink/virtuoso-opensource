--
--  ttrigtrig.sql
--
--  $Id: ttrigtrig.sql,v 1.3.10.1 2013/01/02 16:15:31 source Exp $
--
--  Trigger testing
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

create trigger AMT_INS after insert on T_ORDER_LINE
{
  dbg_obj_print ('ins ol ', OL_O_ID, OL_MODIFIED, OL_QTY, OL_I_PRICE);
  update T_ORDER set O_VALUE = O_VALUE + OL_QTY * OL_I_PRICE
    where O_ID = OL_O_ID;
}

create trigger AMT_DEL after delete on T_ORDER_LINE
{
  dbg_obj_print ('ol del ', OL_O_ID, OL_I_ID);
  update T_ORDER set O_VALUE = O_VALUE - OL_QTY * OL_I_PRICE
    where O_ID = OL_O_ID;
}

create trigger AMT before update on T_ORDER_LINE referencing old as O
{
  dbg_obj_print ('old ', O.OL_QTY, ' ', datestring (O.OL_MODIFIED), O.OL_I_PRICE);
  dbg_obj_print ('new ', OL_QTY, ' ', datestring (OL_MODIFIED), OL_I_PRICE);
  update T_ORDER set O_VALUE = O_VALUE - O.OL_QTY * O.OL_I_PRICE + OL_QTY * OL_I_PRICE where O_ID = OL_O_ID;
}

create trigger W_VALUE before update (O_VALUE) on T_ORDER
     referencing old as O, new as N
{
  dbg_obj_print ('O_VALUE from ', O.O_VALUE, ' to ', N.O_VALUE);
  update T_WAREHOUSE set W_ORDER_VALUE = W_ORDER_VALUE - O.O_VALUE + N.O_VALUE
    where W_ID = O.O_W_ID;
}

create trigger O_DEL_OL  after delete on T_ORDER order 2
{
  dbg_obj_print ('order deleted, delete order lines');
  set triggers off;
  delete from T_ORDER_LINE where OL_O_ID = O_ID;
}

create trigger O_DEL_W  after delete on T_ORDER order 1
{
  dbg_obj_print ('order deleted, update W_ORDER_VALUE');
  update T_WAREHOUSE set W_ORDER_VALUE = W_ORDER_VALUE - O_VALUE
    where W_ID = O_W_ID;
}

create procedure ol_reprice_1 (in i_id integer, in i_price float)
{
  declare id integer;
  declare cr cursor for
    select OL_I_ID from T_ORDER_LINE;
  whenever not found goto done;
  open cr;
  while (1) {
    fetch cr into id;
    if (id = i_id)
      update T_ORDER_LINE set OL_I_PRICE = i_price where current of cr;
  }
 done:
  return;
}

create procedure ol_reprice_2 (in i_id integer, in i_price float)
{
  declare id integer;
  declare cr cursor for
    select OL_I_ID from T_ORDER_LINE order by OL_I_ID;
  whenever not found goto done;
  open cr;
  while (1) {
    fetch cr into id;
    if (id = i_id)
      update T_ORDER_LINE set OL_I_PRICE = i_price where current of cr;
  }
 done:
  return;
}

create procedure ol_del_i_id_2 (in i_id integer)
{
  declare id integer;
  declare cr cursor for
    select OL_I_ID from T_ORDER_LINE order by OL_I_ID;
  whenever not found goto done;
  open cr;
  while (1) {
    fetch cr into id;
    if (id = i_id)
      delete from T_ORDER_LINE where current of cr;
  }
 done:
  return;
}

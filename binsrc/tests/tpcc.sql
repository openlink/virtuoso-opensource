--
--  tpcc.sql
--
--  $Id$
--
--  TPC-C Benchmark transactions as stored procedures.
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


--
-- slevel - The transaction procedure for the Stock Level transaction.
-- This is executed as an autocommitting history read transaction. The number
-- of STOCK rows where quantity is below th threshold.  The rows are taken from
-- the last 20 orders on a warehouse / district combination.

-- use tpcc;

create procedure slevel (
    in w_id integer,
    in _d_id integer,
    in threshold integer)
{
  declare last_o, n_items integer;

  set isolation = 'committed';
  select d_next_o_id into last_o
    from district
    where d_w_id = w_id and d_id = _d_id;

  select count ( s_i_id) into n_items
    from order_line, stock
    where ol_w_id = w_id
      and ol_d_id = _d_id
      and ol_o_id < last_o
      and ol_o_id >= last_o - 20
      and s_w_id = w_id
      and s_i_id = ol_i_id
      and s_quantity < threshold option (loop, order);

  result_names (n_items);
  result (n_items);
}


--
-- Alternate slevel implementation. Theoretically 10& less
-- random access on stock but in practice marginally slower due
-- to more complex query graph.

create procedure slevel2 (
    in w_id integer,
    in _d_id integer,
    in threshold integer)
{
  declare last_o, n_items integer;

  select d_next_o_id into last_o
    from district
    where d_w_id = w_id and d_id = _d_id;

  select count (*) into n_items
    from (select distinct ol_i_id from order_line
	  where ol_w_id = w_id
	  and ol_d_id = _d_id
	  and ol_o_id < last_o
	  and ol_o_id >= last_o - 20) O,
        stock
      where
	s_w_id = w_id
	  and s_i_id = ol_i_id
	    and s_quantity < threshold;

  result_names (n_items);
  result (n_items);
}


--
-- c_by_name, call_c_by_name
-- Examples on retrieving CUSTOMER by last name.
-- Functionality open coded in actual transaction procedures.
create procedure c_by_name (
    in w_id integer,
    in d_id integer,
    in name varchar,
    out id integer)
{
  declare n, c_count integer;
  declare c_cur cursor for
    select c_id
      from customer
      where c_w_id = w_id
       and c_d_id = d_id
       and c_last = name
      order by c_w_id, c_d_id, c_last, c_first;

  select count (*) into c_count
    from customer
    where c_w_id = w_id
      and c_d_id = d_id
      and c_last = name;

  n := 0;
  open c_cur;
  whenever not found goto notfound;
  while (n <= c_count / 2)
    {
      fetch c_cur into id;
      n := n + 1;
    }
  return;

notfound:
  signal ('cnf', 'customer not found by name');
  return;
}


create procedure call_c_by_name (
    in w_id integer,
    in d_id integer,
    in c_last varchar)
{
  declare c_id integer;

  c_by_name (w_id, d_id, c_last, c_id);
}


-- [ Omission - don't generate new value of c_data if 'bad credit' case ]


--
-- payment - This procedure implements the Payment transaction.
create procedure bc_c_data (
    inout c_new varchar,
    inout c_data varchar)
{
  return concatenate (c_new, subseq (c_data, length (c_new), length (c_data)));
}


create procedure payment (
    in _w_id integer,
    in _c_w_id integer,
    in h_amount float,
    in _d_id integer,
    in _c_d_id integer,
    in _c_id integer,
    in _c_last varchar)
{
  declare _c_id1, namecnt2 integer;
  declare n, _w_ytd, _d_ytd, _c_cnt_payment integer;
  declare
    _c_data, _c_first, _c_middle,
    _c_street_1,  _c_street_2, _c_city, _c_state, _c_zip,
    _c_phone, _c_credit, _c_credit_lim,
    _c_discount, _c_balance, _c_since, _c_data_1, _c_data_2,
    _d_street_1, _d_street_2, _d_city, _d_state, _d_zip, _d_name,
    _w_street_1, _w_street_2, _w_city, _w_state, _w_zip, _w_name,
    screen_data varchar;
  declare namecnt integer;

  set isolation = 'repeatable';
  _d_street_1 := 'no_d_str';
  _w_street_1 := 'no_w_str';
  _c_first := 'no-c_first';
  _c_id1 := _c_id;
  if (_c_id = 0)
    {
      whenever not found goto no_customer;

      select count(C_ID) into namecnt
        from customer
	where c_last = _c_last
	  and c_d_id = _d_id
	  and c_w_id = _w_id;



      select count(C_ID) into namecnt2
        from customer
	where c_last = _c_last
	  and c_d_id = _d_id
	  and c_w_id = _w_id;


	if (namecnt <> namecnt2)
	  dbg_printf ('Bad count for last %s d %d c1 %d c2 %d', _c_last, _d_id, namecnt, namecnt2);
	      declare c_byname cursor for
	select c_id
	  from customer
	  where c_w_id = _c_w_id
	    and c_d_id = _c_d_id
	    and c_last = _c_last
	  order by c_w_id, c_d_id, c_last, c_first;

      open c_byname (exclusive);

      n := 0;
      while (n <= namecnt / 2)
        {
	  fetch c_byname   into _c_id;
	  n := n + 1;
	}

      close c_byname;
    }

  declare c_cr cursor for
    select
      c_first, c_middle, c_last,
      c_street_1, c_street_2, c_city, c_state, c_zip,
      c_phone, c_credit, c_credit_lim,
      c_discount, c_balance, c_since, c_data_1, c_data_2, c_cnt_payment
    from customer
    where c_w_id = _c_w_id
      and c_d_id = _c_d_id
      and c_id = _c_id;

  open c_cr (exclusive);

  fetch c_cr into
    _c_first, _c_middle, _c_last,
    _c_street_1, _c_street_2, _c_city, _c_state, _c_zip,
    _c_phone, _c_credit, _c_credit_lim,
    _c_discount, _c_balance, _c_since, _c_data_1, _c_data_2, _c_cnt_payment;

  _c_balance := _c_balance + h_amount;

  if (_c_credit = 'BC')
    {
      update customer set
        c_balance = _c_balance,
	c_data_1 = bc_c_data (
	  sprintf ('%5d%5d%5d%5d%5d%9f', _c_id, _c_d_id, _c_w_id, _d_id,
	    _w_id, h_amount), _c_data_1),
	c_cnt_payment = _c_cnt_payment + 1
	where current of c_cr;

      screen_data := subseq (_c_data_1, 1, 200);
    }
  else
    {
      update customer set
        c_balance = _c_balance,
	c_cnt_payment = _c_cnt_payment + 1
	where current of c_cr;

      screen_data := ' ';
    }


  declare d_cur cursor for
    select d_street_1, d_street_2, d_city, d_state, d_zip, d_name, d_ytd
    from district
    where d_w_id = _w_id
      and d_id = _d_id;

  open d_cur (exclusive);

  fetch d_cur into _d_street_1, _d_street_2, _d_city, _d_state, _d_zip,
      _d_name, _d_ytd;

  update district set
    d_ytd = _d_ytd + h_amount
    where current of d_cur;

  close d_cur;

  declare w_cur cursor for
    select  w_street_1, w_street_2, w_city, w_state, w_zip, w_name, w_ytd
    from warehouse
    where w_id = _w_id;

  open w_cur (exclusive);

  fetch	 w_cur into _w_street_1, _w_street_2, _w_city, _w_state, _w_zip,
      _w_name, _w_ytd;

  update warehouse set w_ytd = _w_ytd + h_amount where current of w_cur;
  declare h_data varchar;
  h_data := _w_name;
  insert into history (
      h_c_d_id, h_c_w_id, h_c_id, h_d_id, h_w_id, h_date, h_amount, h_data)
    values (_c_d_id, _c_w_id, _c_id, _d_id, _w_id, now (), h_amount, h_data);

  commit work;

  result ( _c_id,
           _c_last,
           now (),
           _w_street_1,
           _w_street_2,
           _w_city,
           _w_state,
           _w_zip,
           _d_street_1,
           _d_street_2,
           _d_city,
           _d_state,
           _d_zip,
           _c_first,
           _c_middle,
           _c_street_1,
           _c_street_2,
           _c_city,
           _c_state,
           _c_zip,
           _c_phone,
           _c_since,
           _c_credit,
           _c_credit_lim,
           _c_discount,
           _c_balance,
           screen_data);
  return;

no_customer:
  dbg_printf ('No customer %s d %d id %d first %s id1 %d n_with_last %d, counted %d. d_str %s w_str %s\n',
	      _c_last, _d_id, _c_id, _c_first, _c_id1, namecnt, n, _d_street_1, _w_street_1);
  signal ('NOCUS', 'No customer in payment.');
}


--
-- ol_stock - Part of the New Order transaction - Set the stock level for
-- an order line.  Compute the price and return it in amount.
--
-- Note - Open the cursor on STOCK as exclusive to avoid deadlocks.
-- Use positioned update on STOCK for speed.
--
-- Fetch the s_dist_01 - 10 columns from STOCK even though they are not used.
-- The test specification requires this. The operation is measurably faster
-- if these are omitted.
-- The ORDER LINE is inserted later for better lock concurrency.
create procedure ol_stock (
    in _w_id integer,
    in d_id integer,
    inout _ol_i_id integer,
    in _ol_supply_w_id integer,
    in qty integer,
    out amount float,
    inout s_dist_01 varchar,
    inout s_dist_02 varchar,
    inout s_dist_03 varchar,
    inout s_dist_04 varchar,
    inout s_dist_05 varchar,
    inout s_dist_06 varchar,
    inout s_dist_07 varchar,
    inout s_dist_08 varchar,
    inout s_dist_09 varchar,
    inout s_dist_10 varchar,
    inout dist_info varchar)
{
  declare _s_data varchar;
  declare _s_quantity, _s_cnt_order, _s_cnt_remote integer;
  declare _i_name varchar;

  if (_ol_i_id = 0) return;

  whenever not found goto no_item;
  select i_price, i_name into amount, _i_name
    from item table option (isolation read committed)
    where i_id = _ol_i_id;

  declare s_cur cursor for
    select s_quantity, s_data, s_cnt_order, s_cnt_remote,
        s_dist_01, s_dist_02, s_dist_03, s_dist_04, s_dist_05,
	s_dist_06, s_dist_07, s_dist_08, s_dist_09, s_dist_10
    from stock
    where s_i_id = _ol_i_id
      and s_w_id = _ol_supply_w_id for update;

  whenever not found goto no_stock;

  open s_cur (exclusive);
  fetch s_cur into
      _s_quantity, _s_data, _s_cnt_order, _s_cnt_remote,
      s_dist_01, s_dist_02, s_dist_03, s_dist_04, s_dist_05,
      s_dist_06, s_dist_07, s_dist_08, s_dist_09, s_dist_10;

  if (_s_quantity < qty)
    _s_quantity := _s_quantity - qty + 91;
  else
    _s_quantity := _s_quantity - qty;

  if (_w_id <> _ol_supply_w_id)
    _s_cnt_remote := _s_cnt_remote + 1;

  update stock set
    s_quantity = _s_quantity,
    s_cnt_order = _s_cnt_order + 1,
    s_cnt_remote = _s_cnt_remote
    where current of s_cur;

       if (d_id = 1) dist_info := s_dist_01;
  else if (d_id = 2) dist_info := s_dist_02;
  else if (d_id = 3) dist_info := s_dist_03;
  else if (d_id = 4) dist_info := s_dist_04;
  else if (d_id = 5) dist_info := s_dist_05;
  else if (d_id = 6) dist_info := s_dist_06;
  else if (d_id = 7) dist_info := s_dist_07;
  else if (d_id = 8) dist_info := s_dist_08;
  else if (d_id = 9) dist_info := s_dist_09;
  else if (d_id = 10) dist_info := s_dist_10;

  result (_i_name, _s_quantity, 'G', amount, amount * qty);

  amount := qty * amount;

  return;
no_stock:
  signal ('NOSTK', 'No stock row found.');

no_item:
  signal ('NOITM', 'No item row found.');
}


--
-- ol_insert - Pasrt of New Order transaction. Insert an ORDER LINE.
--
-- Note the use of inout parameters, even though they are not modified here.
-- This saves copying the values.
create procedure ol_insert (
    inout w_id integer,
    inout d_id integer,
    inout o_id integer,
    in ol_number integer,
    inout ol_i_id integer,
    inout ol_qty integer,
    inout ol_amount float,
    inout ol_supply_w_id integer,
    inout ol_dist_info varchar,
    inout tax_and_discount float)
{
  if (ol_i_id = -1) return;
  ol_amount := ol_amount * tax_and_discount;

  insert into order_line (
      ol_o_id, ol_d_id, ol_w_id, ol_number, ol_i_id, ol_supply_w_id,
      ol_quantity, ol_amount, ol_dist_info)
    values (
      o_id, d_id, w_id, ol_number, ol_i_id, ol_supply_w_id,
      ol_qty, ol_amount, ol_dist_info);
}


-- cust_info - part of New Order transaction. Return customer info.
create procedure cust_info (
    in w_id integer,
    in d_id integer,
    inout _c_id integer,
    inout _c_last varchar,
    out _c_discount float,
    out _c_credit varchar)
{
  whenever not found goto err;
  select c_last, c_discount, c_credit into _c_last, _c_discount, _c_credit
    from customer
    where c_w_id = w_id
      and c_d_id = d_id
      and c_id = _c_id;
  return;

err:
  signal ('NOCUS', 'No customer');
}


-- new_order - Top level procedure of New Order transaction.
-- Take a fixed 10 order lines as individually named parameters
-- to stay easily portable.
create procedure new_order (
    in _w_id integer, in _d_id integer, in _c_id integer,
    in o_ol_cnt integer, in o_all_local integer,
    in i_id_1 integer, in s_w_id_1 integer, in qty_1 integer,
    in i_id_2 integer, in s_w_id_2 integer, in qty_2 integer,
    in i_id_3 integer, in s_w_id_3 integer, in qty_3 integer,
    in i_id_4 integer, in s_w_id_4 integer, in qty_4 integer,
    in i_id_5 integer, in s_w_id_5 integer, in qty_5 integer,
    in i_id_6 integer, in s_w_id_6 integer, in qty_6 integer,
    in i_id_7 integer, in s_w_id_7 integer, in qty_7 integer,
    in i_id_8 integer, in s_w_id_8 integer, in qty_8 integer,
    in i_id_9 integer, in s_w_id_9 integer, in qty_9 integer,
    in i_id_10 integer, in s_w_id_10 integer, in qty_10 integer
    )
{
  declare
    ol_a_1, ol_a_2, ol_a_3, ol_a_4, ol_a_5,
    ol_a_6, ol_a_7, ol_a_8, ol_a_9, ol_a_10 integer;
  declare _c_discount, _d_tax, _w_tax, tax_and_discount float;
  declare _datetime timestamp;
  declare _c_last, _c_credit varchar;
  declare _o_id integer;
  declare
    i_name, s_dist_01, s_dist_02, s_dist_03, s_dist_04, s_dist_05, s_dist_06,
    s_dist_07, s_dist_08, s_dist_09, s_dist_10,
    disti_1, disti_2, disti_3, disti_4, disti_5, disti_6, disti_7, disti_8,
    disti_9, disti_10 varchar;

  _datetime := now ();

  result_names (i_name, qty_1, disti_1, ol_a_1, ol_a_2);
  set isolation = 'repeatable';
  ol_stock (
      _w_id, _d_id, i_id_1, s_w_id_1, qty_1, ol_a_1,
      s_dist_01, s_dist_02, s_dist_03, s_dist_04, s_dist_05,
      s_dist_06, s_dist_07, s_dist_08, s_dist_09, s_dist_10, disti_1);

  ol_stock (
      _w_id, _d_id, i_id_2, s_w_id_2, qty_2, ol_a_2,
      s_dist_01, s_dist_02, s_dist_03, s_dist_04, s_dist_05,
      s_dist_06, s_dist_07, s_dist_08, s_dist_09, s_dist_10, disti_2);

  ol_stock (
      _w_id, _d_id, i_id_3, s_w_id_3, qty_3, ol_a_3,
      s_dist_01, s_dist_02, s_dist_03, s_dist_04, s_dist_05,
      s_dist_06, s_dist_07, s_dist_08, s_dist_09, s_dist_10, disti_3);

  ol_stock (
      _w_id, _d_id, i_id_4, s_w_id_4, qty_4, ol_a_4,
      s_dist_01, s_dist_02, s_dist_03, s_dist_04, s_dist_05,
      s_dist_06, s_dist_07, s_dist_08, s_dist_09, s_dist_10, disti_4);

  ol_stock (
      _w_id, _d_id, i_id_5, s_w_id_5, qty_5, ol_a_5,
      s_dist_01, s_dist_02, s_dist_03, s_dist_04, s_dist_05,
      s_dist_06, s_dist_07, s_dist_08, s_dist_09, s_dist_10, disti_5);

  ol_stock (
      _w_id, _d_id, i_id_6, s_w_id_6, qty_6, ol_a_6,
      s_dist_01, s_dist_02, s_dist_03, s_dist_04, s_dist_05,
      s_dist_06, s_dist_07, s_dist_08, s_dist_09, s_dist_10, disti_6);

  ol_stock (
      _w_id, _d_id, i_id_7, s_w_id_7, qty_7, ol_a_7,
      s_dist_01, s_dist_02, s_dist_03, s_dist_04, s_dist_05,
      s_dist_06, s_dist_07, s_dist_08, s_dist_09, s_dist_10, disti_7);

  ol_stock (
      _w_id, _d_id, i_id_8, s_w_id_8, qty_8, ol_a_8,
      s_dist_01, s_dist_02, s_dist_03, s_dist_04, s_dist_05,
      s_dist_06, s_dist_07, s_dist_08, s_dist_09, s_dist_10, disti_8);

  ol_stock (
      _w_id, _d_id, i_id_9, s_w_id_9, qty_8, ol_a_9,
      s_dist_01, s_dist_02, s_dist_03, s_dist_04, s_dist_05,
      s_dist_06, s_dist_07, s_dist_08, s_dist_09, s_dist_10, disti_9);

  ol_stock (
      _w_id, _d_id, i_id_10, s_w_id_10, qty_10, ol_a_10,
      s_dist_01, s_dist_02, s_dist_03, s_dist_04, s_dist_05,
      s_dist_06, s_dist_07, s_dist_08, s_dist_09, s_dist_10, disti_10);

  cust_info (_w_id, _d_id, _c_id, _c_last, _c_discount, _c_credit);

  declare  d_cur cursor for
    select d_tax, d_next_o_id
      from district
      where d_w_id = _w_id
        and d_id = _d_id for update;

  whenever not found goto noware;
  open d_cur (exclusive);
  fetch d_cur into _d_tax, _o_id;
  -- dbg_obj_print ('read next o_id ', _d_id, ' ', _o_id);
  update district set
    d_next_o_id = _o_id + 1
    where current of d_cur;
  close d_cur;

  insert into orders (
      o_id, o_d_id, o_w_id, o_c_id, o_entry_d, o_ol_cnt, o_all_local)
    values (
      _o_id, _d_id, _w_id, _c_id, _datetime, o_ol_cnt, o_all_local);

  insert into new_order (no_o_id, no_d_id, no_w_id)
    values (_o_id, _d_id, _w_id);

  set isolation = 'uncommitted';
  select w_tax into _w_tax
    from warehouse
    where w_id = _w_id;

  set isolation = 'repeatable';
  tax_and_discount := (1 + _d_tax + _w_tax) * (1 - _c_discount);

  ol_insert (_w_id, _d_id, _o_id,
      1, i_id_1, qty_1, ol_a_1,  s_w_id_1, disti_1, tax_and_discount);

  ol_insert (_w_id, _d_id, _o_id,
      2, i_id_2, qty_2, ol_a_2,  s_w_id_2, disti_2, tax_and_discount);

  ol_insert (_w_id, _d_id, _o_id,
      3, i_id_3, qty_3, ol_a_3,  s_w_id_3, disti_3, tax_and_discount);

  ol_insert (_w_id, _d_id, _o_id,
      4, i_id_4, qty_4, ol_a_4,  s_w_id_4, disti_4, tax_and_discount);

  ol_insert (_w_id, _d_id, _o_id,
      5, i_id_5, qty_5, ol_a_5,  s_w_id_5, disti_5, tax_and_discount);

  ol_insert (_w_id, _d_id, _o_id,
      6, i_id_6, qty_6, ol_a_6,  s_w_id_6, disti_6, tax_and_discount);

  ol_insert (_w_id, _d_id, _o_id,
      7, i_id_7, qty_7, ol_a_7,  s_w_id_7, disti_7, tax_and_discount);

  ol_insert (_w_id, _d_id, _o_id,
      8, i_id_6, qty_8, ol_a_8,  s_w_id_8, disti_8, tax_and_discount);

  ol_insert (_w_id, _d_id, _o_id,
      9, i_id_9, qty_9, ol_a_9,  s_w_id_9, disti_9, tax_and_discount);

  ol_insert (_w_id, _d_id, _o_id,
      10, i_id_10, qty_10, ol_a_10,  s_w_id_10, disti_10, tax_and_discount);

  commit work;
  end_result ();
  result (_w_tax, _d_tax, _o_id, _c_last, _c_discount, _c_credit);
  -- dbg_obj_print ('inserted next o_id ', _d_id, ' ', _o_id);
  return;

noware:
  signal ('NOWRE', 'Warehouse or districtnot found.');
}


-- delivery_1 - Top level procedure for the Delivery transaction
--
-- This is called 10 times by the client in each delivery transaction.
-- The rules allow Delivery to be implemented as up to 10 separately committed
-- transactions. This is done to minimize lock duration.
create procedure delivery_1 (
    in w_id integer,
    in carrier_id integer,
    in d_id integer)
{
  declare no_cur cursor for
    select no_o_id
      from new_order
      where no_w_id = w_id
        and no_d_id = d_id for update;

  declare _datetime timestamp;
  declare _o_id, _c_id integer;
  declare ol_total float;
  declare exit handler for not found { signal ('delnf', sprintf ('delivery not found d %d o %d', d_id, _o_id)); };

  set isolation = 'repeatable';
  _datetime := now ();
  open no_cur (exclusive, prefetch 1);
  fetch no_cur into _o_id;
  delete from NEW_ORDER where current of no_cur;
  close no_cur;

  declare o_cur cursor for
    select o_c_id
      from orders
      where o_w_id = w_id
        and o_d_id = d_id
	and o_id = _o_id for update;

  open o_cur (exclusive);
  fetch o_cur into _c_id;
  update orders set
    o_carrier_id = carrier_id
    where current of o_cur;
  close o_cur;

  declare ol_cur cursor for
    select ol_amount
      from order_line
      where ol_w_id = w_id
        and ol_d_id = d_id
	and ol_o_id = _o_id for update;

  ol_total := 0.0;
  whenever not found goto lines_done;
  open ol_cur (exclusive);
  while (1)
    {
      declare tmp integer;
      fetch ol_cur into tmp;
      ol_total := ol_total + tmp;
      update order_line set
        ol_delivery_d = _datetime
	where current of ol_cur;
    }

lines_done:
  update customer set
    c_balance = c_balance + ol_total,
    c_cnt_delivery = c_cnt_delivery + 1
    where c_w_id = w_id and c_d_id = d_id and c_id = _c_id;

  return _o_id;
}



-- ostat - Top level procedure for the Order Status transaction.
create procedure ostat (
    in _w_id integer,
    in _d_id integer,
    in _c_id integer,
    in _c_last varchar)
{
  set isolation = 'serializable';
  declare _c_first, _c_middle, _c_balance varchar;
  declare
    _o_id, _ol_i_id, _ol_supply_w_id, _ol_quantity, _o_carrier_id, n integer;
  declare _ol_amount float;
  declare _ol_delivery_d, _o_entry_d varchar;

  if (_c_id = 0)
    {
      declare namecnt integer;

      whenever not found goto no_customer;
      select count (*) into namecnt
	from customer
	where c_last = _c_last
	  and c_d_id = _d_id
	  and c_w_id = _w_id;

      declare c_byname cursor for
	select c_balance, c_last, c_middle, c_id
	  from customer
	  where c_w_id = _w_id
	    and c_d_id = _d_id
	    and c_last = _c_last
	  order by c_w_id, c_d_id, c_last, c_first;

      open c_byname;

      n := 0;
      while (n <= namecnt / 2)
        {
	  fetch c_byname into _c_balance, _c_first, _c_middle, _c_id;
	  n := n + 1;
	}

      close c_byname;
    }
  else
    {
      select c_balance, c_first, c_middle, c_last
	into _c_balance, _c_first, _c_middle, _c_last
	from customer
	where c_w_id = _w_id
	  and c_d_id = _d_id
	  and c_id = _c_id;
    }

  whenever not found goto no_order;
  select o_id, o_carrier_id, o_entry_d
    into _o_id, _o_carrier_id, _o_entry_d
    from orders
    where o_w_id = _w_id
      and o_d_id = _d_id
      and o_c_id = _c_id
    order by o_w_id desc, o_d_id desc, o_c_id desc, o_id desc;

  declare o_line cursor for
    select ol_i_id, ol_supply_w_id, ol_quantity, ol_amount, ol_delivery_d
      from order_line
      where ol_w_id = _w_id
        and ol_d_id = _d_id
	and ol_o_id = _o_id;

  whenever not found goto lines_done;
  open o_line;
  result_names (_ol_supply_w_id, _ol_i_id, _ol_quantity, _ol_amount,
      _ol_delivery_d);

  while (1)
    {
      fetch o_line into _ol_i_id, _ol_supply_w_id, _ol_quantity, _ol_amount,
          _ol_delivery_d;

      result (_ol_supply_w_id, _ol_i_id, _ol_quantity, _ol_amount,
          _ol_delivery_d);
    }

lines_done:
  end_result ();
  result_names  (_c_id, _c_last, _c_first, _c_middle, _o_entry_d,
      _o_carrier_id, _c_balance, _o_id);

  result (_c_id, _c_last, _c_first, _c_middle, _o_entry_d,
      _o_carrier_id, _c_balance, _o_id);

  return;

no_customer:
  dbg_printf ('Nocustomer %s %d.\n', _c_last, _c_id);
  signal ('NOCUS', 'No customer in order status');

no_order:
  return 0;
}



create procedure order_check (in _w_id integer, in _d_id integer)
{
  declare last_o, ol_max, ol_ct, o_max, o_ct, nolines integer;
  select d_next_o_id into last_o from district where d_id = _d_id and d_w_id = _w_id;
  select count (*), max (ol_o_id) into ol_ct, ol_max from order_line
    where ol_w_id = _w_id and ol_d_id = _d_id;
  select count (*), max (o_id) into o_ct, o_max from orders
    where o_w_id = _w_id and o_d_id = _d_id;
  select count (*) into nolines from orders where o_w_id = _w_id and o_d_id = _d_id and
    not exists
      (select 1 from order_line where ol_w_id = _w_id and ol_d_id = _d_id and ol_o_id = o_id);
  result_names (last_o, o_max, o_ct, ol_max, ol_ct, nolines);
  result (last_o, o_max, o_ct, ol_max, ol_ct, nolines);
  if (o_ct <> last_o-1 or o_max <> ol_max or o_max <> last_o-1 or nolines <> 0)
    signal ('tpinc', 'inconsistent order counts');
}



create procedure w_order_check (in q integer)
{
  declare d, w integer;
  declare cr cursor for select d_w_id, d_id from district;
  whenever not found goto done;
  set isolation = 'committed';
  open cr;
  while (1) {
    fetch cr into w, d;
    order_check (w, d);
    end_result ();
  }
 done:
  return;
}

create procedure seq_read ()
{
  declare r, d, t, tb any;
  declare REPORT float;
  set isolation = 'committed';
  result_names (tb, REPORT);

  d := msec_time ();
  exec ('select sum (c_balance) from customer');
  t := msec_time () - d;
  t := t / 1000.00;
  select sum(READS) into r from SYS_D_STAT where KEY_TABLE = 'DB.DBA.customer';
  REPORT := ((r * 8192.00) / 1048576.00) / t;
  result ('customer', REPORT);

  d := msec_time ();
  exec ('select sum (ol_quantity) from order_line');
  t := msec_time () - d;
  t := t / 1000.00;
  select sum(READS) into r from SYS_D_STAT where KEY_TABLE = 'DB.DBA.order_line';
  REPORT := ((r * 8192.00) / 1048576.00) / t;
  result ('order_line', REPORT);
};


create procedure o_trim (in keep_n int, in w1 int := 0, in w2 int := null)
{
  declare d, w integer;
  if (w2 is null) w2 := (select max (w_id) from warehouse);
  declare cr cursor for select d_w_id, d_id from district where d_w_id between w1 and w2;
  whenever not found goto done;
  set isolation = 'committed';
  open cr;
  while (1) {
    fetch cr into w, d;
    declare first_o, last_o int;
    first_o := (select top 1 o_id from orders where o_w_id = w and o_d_id = d order by o_id);
    last_o := (select top 1 o_id from orders where o_w_id = w and o_d_id = d order by o_id desc);
    if (last_o - first_o > keep_n)
      {
	delete from orders where o_w_id = w and o_d_id = d and o_id < last_o - keep_n;
	commit work;
	delete from order_line where ol_w_id = w and ol_d_id = d and ol_o_id < last_o - keep_n;
	commit work;
      }
  }
 done: return;
}


create procedure o_trim_loop (in keep_n int)
{
  while (1)
    {
      o_trim (keep_n);
      commit work;
      delay (120);
    }
}

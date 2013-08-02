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
-- Database Endpoints procedures --

-- define vhost
create user TBPOINT;
user_set_qualifier ('TBPOINT','WS');
VHOST_REMOVE (lpath=>'/TBPOINT');
VHOST_DEFINE (lpath=>'/TBPOINT', ppath=>'/SOAP/', soap_user=>'TBPOINT', soap_opts=>vector( 'Namespace','http://soapdb.org/','SchemaNS', 'http://soapdb.org/', 'ServiceName', 'DatabaseService', 'CR-escape', 'yes', 'Use', 'literal'));

-- procedures
create procedure DB.DBA.num_truncate (in n numeric)
{
  return cast (cast (n as numeric) - 0.5 as numeric (40, 0));
};

create procedure DB.DBA.num_mod (in x numeric, in y numeric)
{
  return (x - DB.DBA.num_truncate (cast (x as numeric) / y) * y);
};


create procedure DB.DBA.get_values(
  inout w_id integer,
  inout d_id integer,
  inout o_id int,
  in    _o_id numeric,
  inout s_id integer)
{
  declare temp,_dev numeric;

  _dev := 1000000000;
  s_id := 1;
  w_id := 1;

  temp := _o_id/_dev;
  temp := cast(temp as integer);
  d_id :=  temp;
  o_id := DB.DBA.num_mod(_o_id, _dev);

};

create procedure DB.DBA.get_values_custm(
  inout d_id integer,
  inout c_id int,
  in _c_id int)
{
  declare _dev integer;

  _dev := 1000000;
  c_id := DB.DBA.num_mod(_c_id,_dev);
};

create procedure DB.DBA.ol_stock (
  in o_id numeric,
  in _c_id numeric,
  in _ol_i_id integer,
  in qty integer,
  in ol_n integer)
{
  declare _w_id,
    _d_id,
    _ol_supply_w_id,
    _dev integer;
  declare _o_id int;
  declare _d_tax,
    _w_tax,
    _c_discount,
    tax_and_discount float;
  declare _s_quantity,
    _s_cnt_order integer;
  declare amount, _w_tax float;

  DECLARE EXIT HANDLER FOR SQLSTATE '40001' GOTO DEADLOCK;

start:
  if (_ol_i_id = 0) return;

  DB.DBA.get_values(_w_id, _d_id, _o_id, o_id, _ol_supply_w_id);

  select i_price into amount
    from item
   where i_id = _ol_i_id;

  declare s_cur cursor for
   select s_quantity, s_cnt_order
     from stock
    where s_i_id = _ol_i_id
      and s_w_id = _ol_supply_w_id;

  declare d_cur cursor for
   select d_tax
     from district
    where d_w_id = _w_id
      and d_id = _d_id;

  open d_cur (exclusive);
  fetch d_cur into _d_tax;

  select w_tax into _w_tax
    from warehouse
   where w_id = _w_id;

  declare _d_id1, c_id integer;

  DB.DBA.get_values_custm(_d_id1, c_id, _c_id);

  DB.DBA.cust_info(_w_id, _d_id, c_id, _c_discount);

  open s_cur (exclusive);
  fetch s_cur into _s_quantity, _s_cnt_order;

  if (_s_quantity < qty)
    _s_quantity := _s_quantity - qty + 91;
  else
    _s_quantity := _s_quantity - qty;

  update stock set
    s_quantity = _s_quantity,
    s_cnt_order = _s_cnt_order + 1
    where current of s_cur;

  amount := qty * amount;

  tax_and_discount := (1 + _d_tax + _w_tax) * (1 - _c_discount);

  DB.DBA.ol_insert (_w_id, _d_id, _o_id,c_id, ol_n, _ol_i_id, qty, amount, _ol_supply_w_id, tax_and_discount);

  return;

DEADLOCK:
  {
    --dbg_obj_print('DEADLOCK');
    rollback work;
    goto start;
  };

};

create procedure DB.DBA.ol_insert (
    inout _w_id integer,
    inout _d_id integer,
    inout _o_id int,
    inout _c_id integer,
    in _ol_number integer,
    inout _ol_i_id integer,
    inout _ol_qty integer,
    inout _ol_amount float,
    inout _ol_supply_w_id integer,
    inout tax_and_discount float)
{
  if (_ol_i_id = -1) return;
  _ol_amount := _ol_amount * tax_and_discount;
  insert into order_line (
      ol_o_id, ol_d_id, ol_w_id, ol_number, ol_i_id, ol_supply_w_id,
      ol_quantity, ol_amount)
    values (
      _o_id, _d_id, _w_id, _ol_number, _ol_i_id, _ol_supply_w_id,
      _ol_qty, _ol_amount);

  commit work;

  return;

};

create procedure DB.DBA.cust_info (
  inout _w_id integer,
  inout _d_id integer,
  inout _c_id integer,
  out _c_discount float)
{

  DECLARE EXIT HANDLER FOR SQLSTATE '40001' GOTO DEADLOCK;

  start:
   select c_discount into _c_discount
     from customer
    where c_w_id = _w_id
      and c_d_id = _d_id
      and c_id = _c_id;
  return;

DEADLOCK:
  {
    rollback work;
    goto start;
  };

};

create procedure DB.DBA.order_final (
   in o1 numeric,
   in c1 numeric,
   in ln integer)
{
  declare _w_id,
    _d_id,
    _d_id1,
    _c_id,
    _ol_supply_w_id integer;
  declare _o_id int;
  declare _datetime timestamp;

  DECLARE EXIT HANDLER FOR SQLSTATE '40001' GOTO DEADLOCK;

  start:
  if (o1 is null) return;

  --dbg_obj_print('----------------------ORDERFINALIZE-----------------------');
  _datetime := now ();

  DB.DBA.get_values(_w_id, _d_id, _o_id, o1, _ol_supply_w_id);
  DB.DBA.get_values_custm(_d_id1, _c_id, c1);

  insert into DB.DBA.orders ( o_id, o_d_id, o_w_id, o_c_id, o_entry_d, o_ol_cnt,o_all_local)
                     values ( _o_id, _d_id, _w_id, _c_id, _datetime, ln, 1);

  insert into new_order (no_o_id, no_d_id, no_w_id)
                 values (_o_id, _d_id, _w_id);

  return;

  DEADLOCK:
    {
      rollback work;
      goto start;
    };

};

create procedure WS.TBPOINT.orderLine
  ( in orderId numeric,
    in customerID numeric,
    in itemID integer,
    in quantity integer,
    in orderLineID integer) returns any
{

  if (rnd(40)=1){
    --dbg_obj_print('--------line is canceled------');
    --return XMLELEMENT( 'parameters', XMLELEMENT('result','-1'));
    return '-1';
   }
  else
   {
    DB.DBA.ol_stock (orderId, customerID, itemID, quantity, orderLineID);
    --dbg_obj_print('--------line is successfully entered------');
    --return XMLELEMENT('parameters', XMLELEMENT('result','1'));
    return '1';
  };
};
grant execute on WS.TBPOINT.orderLine to TBPOINT;

create procedure WS.TBPOINT.orderCancel (
   in orderId numeric,
   in customerID numeric,
   in itemID integer,
   in quantity integer,
   in orderLineID integer)
   returns nvarchar
{
  declare _w_id,
    _d_id,
    _dev,
    _ol_supply_w_id,
    _s_cnt_order,
    _s_quantity integer;
  declare _o_id int;

  DECLARE EXIT HANDLER FOR SQLSTATE '40001' GOTO DEADLOCK;

  start:
  if (orderId is null) return;

  --dbg_obj_print('----------------------orderCanceled-----------------------');
  DB.DBA.get_values(_w_id, _d_id, _o_id, orderId, _ol_supply_w_id);

  if (not (exists ( select * from order_line
                     where ol_w_id = _w_id
                       and ol_d_id = _d_id
                       and ol_o_id = _o_id
                       and ol_number = orderLineID
                       and ol_i_id = itemID
                       and ol_supply_w_id = _ol_supply_w_id)))
     return;

  declare s_cur cursor for
   select s_quantity, s_cnt_order
     from stock
    where s_i_id = itemID
      and s_w_id = _ol_supply_w_id;

  open s_cur (exclusive);
  fetch s_cur into _s_quantity, _s_cnt_order;

  _s_quantity := _s_quantity + quantity;

  update stock set
    s_quantity = _s_quantity,
    s_cnt_order = _s_cnt_order - 1
    where current of s_cur;

  delete from order_line
   where ol_w_id = _w_id
     and ol_d_id = _d_id
     and ol_o_id = _o_id
     and ol_i_id = itemID
     and ol_number = orderLineID;

  return '1';
  DEADLOCK:
    {
      rollback work;
      goto start;
    };
};
grant execute on WS.TBPOINT.orderCancel to TBPOINT;

create procedure WS.TBPOINT.deliveryStart ( in entr integer ) returns integer
{
  declare _d1,_d2,_d3,_d4,_d5,_d6,_d7,_d8,_d8,_d9,_d10 integer;

dbg_obj_print('begin');
  http_request_status ('HTTP/1.1 202 Accepted');
  dbg_obj_print('2');
  http_flush();
  dbg_obj_print('3');

  _d1 := DB.DBA.delivery(1);
  _d2 := DB.DBA.delivery(2);
  _d3 := DB.DBA.delivery(3);
  _d4 := DB.DBA.delivery(4);
  _d5 := DB.DBA.delivery(5);
  _d6 := DB.DBA.delivery(6);
  _d7 := DB.DBA.delivery(7);
  _d8 := DB.DBA.delivery(8);
  _d9 := DB.DBA.delivery(9);
  _d10 := DB.DBA.delivery(10);
dbg_obj_print('end-delivery-transaction');
  if ( _d1 = 0 and _d2 = 0 and _d3 = 0 and _d4 = 0 and _d5 = 0 and _d6 = 0 and _d7 = 0 and _d8 = 0 and _d9 = 0 and _d10 = 0)
    return 0;
  else
    return 1;
};
grant execute on WS.TBPOINT.deliveryStart to TBPOINT;

create procedure WS.TBPOINT.sDelivery(
  in orderID int,
  in districtID int,
  in cost float,
  in cID int ) returns any
{
  declare aXML any;
  declare newOrderID, newCustomerID numeric;

  newOrderID :=  cast(districtID as numeric) * 1000000000 + orderID;
  newCustomerID :=  cast(districtID as numeric) * 1000000 + cID;


  --dbg_obj_print('----------------SDELIVERY---------');
  aXML:=  XMLELEMENT('onDelivery',
                      XMLELEMENT('ID',cast(newOrderID as numeric)),
                      XMLELEMENT('price',cost),
                      XMLELEMENT('cID', cast( newCustomerID as numeric))
                    );

  commit work;
  declare retr int;
  retr := 0;
  declare exit handler for sqlstate 'HTCLI'
    {
       rollback work;
       if (retr > 6)
	 resignal;
       goto again;
    };
  again:;
  db.dba.soap_client (direction=>1,
                       url=>'http://'|| bp_host() || '/BPELGUI/bpel.vsp?script=file:/bpeltpcc/Sut.bpel',
                       operation=> 'delv',
                       style=>128+1,
                       parameters =>  vector ('par1', aXML));
};
grant execute on WS.TBPOINT.sDelivery to TBPOINT;


create procedure WS.TBPOINT.orderFinal (
   in orderId numeric,
   in customerID numeric,
   in lineTotal integer)

{
  DB.DBA.order_final(orderId,customerID,lineTotal);
  return '1';
};
grant execute on WS.TBPOINT.orderFinal to TBPOINT;

create procedure WS.TBPOINT.payment (
    in orderID numeric,
    in amount float,
    in customerID numeric)
{
  declare _w_id,
    _c_w_id,
   _c_d_id,
    _c_id,
    districtID,
    namecnt2,
    _w_ytd,
    _d_ytd,
    _c_cnt_payment,
    namecnt,
    _d_id1 integer;
  declare
    _c_credit,
    _c_credit_lim,
    _c_discount,
    _c_balance,
    _c_data_1,
    _w_name varchar;

  DECLARE EXIT HANDLER FOR SQLSTATE '40001' GOTO DEADLOCK;

  start:

  --dbg_obj_print('------START PAYMENT------------');
  _w_id := 1;
  _c_w_id := 1;
  districtID:=  cast( orderID / 1000000000 as integer);
  DB.DBA.get_values_custm(_d_id1, _c_id, customerID);
  _c_d_id := districtID;

  declare c_cr cursor for
   select c_credit, c_credit_lim, c_discount, c_balance, c_data_1, c_cnt_payment
     from customer
    where c_w_id = _c_w_id
      and c_d_id = _c_d_id
      and c_id = _c_id;

  whenever not found goto no_payment;
  open c_cr (exclusive);
  fetch c_cr into
    _c_credit, _c_credit_lim,
    _c_discount, _c_balance,  _c_data_1, _c_cnt_payment;

  _c_balance := _c_balance + amount;

  if (_c_credit = 'BC')
    {
      update customer set
        c_balance = _c_balance,
	c_data_1 = DB.DBA.bc_c_data (
	  sprintf ('%5d%5d%5d%5d%5d%9f', _c_id, _c_d_id, _c_w_id, districtID,
	    _w_id, amount), _c_data_1),
	c_cnt_payment = _c_cnt_payment + 1
	where current of c_cr;

    }
  else
    {
      update customer set
        c_balance = _c_balance,
	c_cnt_payment = _c_cnt_payment + 1
	where current of c_cr;

    }


  declare d_cur cursor for
   select d_ytd
     from district
    where d_w_id = _w_id
      and d_id = districtID;

  open d_cur (exclusive);
  fetch d_cur into _d_ytd;

  update district set
    d_ytd = _d_ytd + amount
    where current of d_cur;

  close d_cur;

  declare w_cur cursor for
   select w_name, w_ytd
     from warehouse
    where w_id = _w_id;

  open w_cur (exclusive);
  fetch	 w_cur into  _w_name, _w_ytd;

  update warehouse set w_ytd = _w_ytd + amount where current of w_cur;

  declare h_data varchar;
  h_data := _w_name;
  insert into history ( h_c_d_id, h_c_w_id, h_c_id, h_d_id, h_w_id, h_date, h_amount, h_data)
               values (_c_d_id, _c_w_id, _c_id, districtID, _w_id, now (), amount, h_data);

  commit work;

  return 1;

DEADLOCK:
  {
    --dbg_obj_print('DEADLOCK');
    rollback work;
    goto start;
  };

no_payment:
  {
    return 0;
  };
};


grant execute on WS.TBPOINT.payment to TBPOINT;

create procedure DB.DBA.bc_c_data (
    inout c_new varchar,
    inout c_data varchar)
{
  return concatenate (c_new, subseq (c_data, length (c_new), length (c_data)));
};

create procedure DB.DBA.delivery (in _d_id integer)
{
  declare _w_id, carrier_id, n integer;

  DECLARE EXIT HANDLER FOR SQLSTATE '40001' GOTO DEADLOCK;

  start:
  _w_id := 1;
  carrier_id := 13;

  declare no_cur cursor for
    select no_o_id
      from new_order
     where no_w_id = _w_id
       and no_d_id = _d_id
       and no_o_id > 3000;

  declare _datetime timestamp;
  declare _o_id, _c_id integer;
  declare ol_total float;

  _datetime := now ();
  whenever not found goto lines_empty;
  open no_cur (exclusive, prefetch 1);
  fetch no_cur into _o_id;

  delete from new_order where current of no_cur;
  close no_cur;

  declare o_cur cursor for
   select o_c_id
     from orders
    where o_w_id = _w_id
      and o_d_id = _d_id
      and o_id = _o_id;

  open o_cur (exclusive);
  fetch o_cur into _c_id;
  update orders
     set o_carrier_id = carrier_id
   where current of o_cur;
  close o_cur;

  declare ol_cur cursor for
    select ol_amount
      from order_line
     where ol_w_id = _w_id
       and ol_d_id = _d_id
       and ol_o_id = _o_id;

  ol_total := 0.0;

  whenever not found goto lines_done;
  open ol_cur (exclusive);
  while (1)
    {
      declare tmp integer;
      fetch ol_cur into tmp;
      ol_total := ol_total + tmp;

      update order_line
         set ol_delivery_d = _datetime
	where current of ol_cur;
    }

lines_done:
  {
  update customer set
    c_balance = c_balance + ol_total,
    c_cnt_delivery = c_cnt_delivery + 1
    where c_w_id = _w_id and c_d_id = _d_id and c_id = _c_id;

   commit work;
   WS.TBPOINT.sDelivery(_o_id, _d_id, ol_total, _c_id);
   return 1;
  };

lines_empty:
   {
   --dbg_obj_print('lines_empty');
   return 0;
   };
DEADLOCK:
  {
    --dbg_obj_print('DEADLOCK');
    rollback work;
    goto start;
  };

  return 1;
};

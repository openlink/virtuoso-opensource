--  
--  $Id$
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
-- TestDriver Endpoints procedures --

-- define vhost
create user TDPOINT;
user_set_qualifier ('TDPOINT','WS');
VHOST_REMOVE (lpath=>'/TDPOINT');
VHOST_DEFINE (lpath=>'/TDPOINT', ppath=>'/SOAP/', soap_user=>'TDPOINT', soap_opts=>vector( 'Namespace','http://soaptd.org/','SchemaNS', 'http://soaptd.org/', 'ServiceName', 'TestDriverService', 'CR-escape', 'yes', 'Use', 'literal'));

-- procedures

create table td_state (
  td_oorders_ok int,
  td_orders_failed int,
  td_receipts int );

create table td_orders
	(
	o_id		integer,
	o_d_id		integer,
	o_w_id		integer,
	o_c_id		integer,
	o_entry_d		date,
	o_carrier_id	integer,
	o_ol_cnt		integer,
	o_all_local		integer,
	primary key (o_w_id, o_d_id, o_id)
	)
;

create table td_order_line (
    ol_o_id		integer,
    ol_d_id		integer,
    ol_w_id		integer,
    ol_number		integer,
    ol_i_id		integer,
    ol_supply_w_id	integer,
    ol_delivery_d	date,
    ol_quantity		integer,
    ol_amount		numeric,
    ol_dist_info	character (24),
    primary key (ol_w_id, ol_d_id, ol_o_id, ol_number)
);

select count(*) from td_state;

create procedure init_td_state ()
{
  if (exists (select 1 from td_state))
    return;
  insert into td_state ( td_oorders_ok, td_orders_failed , td_receipts ) values ( 0, 0 ,0 );
};

init_td_state ();

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

create procedure td_order_register (in o1 int, in c1 int, in nl int)
{
  declare _w_id, _d_id, _d_id1, _c_id, _ol_supply_w_id integer;
  declare _o_id int;
  declare _datetime timestamp;
  _datetime := now ();

  DB.DBA.get_values(_w_id, _d_id, _o_id, o1, _ol_supply_w_id);
  DB.DBA.get_values_custm(_d_id1, _c_id, c1);

  insert into DB.DBA.td_orders ( o_id, o_d_id, o_w_id, o_c_id, o_entry_d, o_ol_cnt,o_all_local)
                     values ( _o_id, _d_id, _w_id, _c_id, _datetime, nl, 1);
}
;

create procedure td_order_unregister (in o1 int, in c1 int)
{
  declare _w_id, _d_id, _d_id1, _c_id, _ol_supply_w_id integer;
  declare _o_id int;

  DB.DBA.get_values(_w_id, _d_id, _o_id, o1, _ol_supply_w_id);
  DB.DBA.get_values_custm(_d_id1, _c_id, c1);

  delete from DB.DBA.td_orders  where o_id = _o_id and o_d_id = _d_id and o_w_id = _w_id;
}
;

create procedure td_order_conf (in o1 int, in c1 int)
{
  declare _w_id, _d_id, _d_id1, _c_id, _ol_supply_w_id integer;
  declare _o_id int;

  DB.DBA.get_values(_w_id, _d_id, _o_id, o1, _ol_supply_w_id);
  DB.DBA.get_values_custm(_d_id1, _c_id, c1);

  update DB.DBA.td_orders set o_carrier_id = 1 where o_id = _o_id and o_d_id = _d_id and o_w_id = _w_id;
}
;

create procedure td_order_delv (in o1 int, in c1 int)
{
  declare _w_id, _d_id, _d_id1, _c_id, _ol_supply_w_id integer;
  declare _o_id int;

  DB.DBA.get_values(_w_id, _d_id, _o_id, o1, _ol_supply_w_id);
  DB.DBA.get_values_custm(_d_id1, _c_id, c1);

  update DB.DBA.td_orders set o_carrier_id = 13 where o_id = _o_id and o_d_id = _d_id and o_w_id = _w_id;
}
;

-- XML for order line
create procedure DB.DBA.ol_xml( in i_id int, in qty integer, in ol_n integer )
{
  declare aXML any;

  aXML := XMLELEMENT( 'line',
                       XMLELEMENT( 'orderLineID', ol_n ),
                       XMLELEMENT( 'itemID', i_id ),
                       XMLELEMENT( 'quantity', qty )
                    );
  return aXML;
};

-- XML for order and runs the orderInitate
create procedure DB.DBA.order_begin (
  in o_id int,
  in c_id int)
{
  declare aXML, nl any;

  aXML := XMLELEMENT('Initate',
                      XMLELEMENT('orderID',o_id),
                      XMLELEMENT('customerID',c_id),
                      XMLELEMENT('lines', random_lines (nl)
			)
                    );

  declare dl int;

  dl := 0;
  declare exit handler for sqlstate '40001'
    {
      rollback work;
      if (dl > 6)
	resignal;

      dl := dl + 1;
      goto again;
    };
  again:;
  td_order_register (o_id, c_id, nl);
  WS.TDPOINT.orderInitiate(aXML);
  return;

};

-- Send request to SUT for initiate Order
create procedure WS.TDPOINT.orderInitiate ( in aXML any ) returns any
{
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
  db.dba.soap_client ( direction=> 1,
		       style=>1,
                       url=> 'http://' || bp_host() || '/BPELGUI/bpel.vsp?script=file:/bpeltpcc/Sut.bpel',
                       operation=> 'order_initiate',
                       parameters => vector ('par1', aXML));

};
grant execute on WS.TDPOINT.orderInitiate to TDPOINT;

-- call the Service deliveryStartTD
create procedure DB.DBA.asyncDelivery()
{
  WS.TDPOINT.deliveryStartTD();
  return;
};

-- send request to Database Driver to start the delivery transaction
create procedure WS.TDPOINT.deliveryStartTD()
{
   declare res any;
   dbg_obj_print('begin-deliveryStartTD');
   commit work;
   dbg_obj_print('1');
   db.dba.soap_client ( direction=> 1,
                        url=> 'http://' || db_host() || '/TBPOINT',
                        operation=> 'deliveryStart',
                        parameters => vector('entr',1));
   dbg_obj_print('2');
};
grant execute on WS.TDPOINT.deliveryStartTD to TDPOINT;

-- Service called by the SUT and replies with payment request to the SUT
create procedure WS.TDPOINT.orderDelivered(
  in orderID numeric,
  in cost float,
  in customerID numeric) returns any
{
  --dbg_obj_print('======orderDelivered================', orderID, customerID);
  declare aXML any;

  declare dl int;

  dl := 0;
  declare exit handler for sqlstate '40001'
    {
      rollback work;
      if (dl > 6)
	resignal;

      dl := dl + 1;
      goto again;
    };
  again:;
  td_order_delv (orderID, customerID);
  aXML := XMLELEMENT('payment',
                      XMLELEMENT('orderID',orderID),
                      XMLELEMENT('amount',cost),
                      XMLELEMENT('customerID',customerID)
                    );
  return aXML;
};
grant execute on WS.TDPOINT.orderDelivered to TDPOINT;


-- Service for Order Success confirmation
create procedure WS.TDPOINT.orderSuccess(in result int, in orderId decimal, in customerID int)
{
  --dbg_obj_print('================orderSucces======================', orderId, customerID);
  --td_order_conf (orderId, customerID);

  http_request_status ('HTTP/1.1 202 Accepted');
  http_flush();

  declare cnt int;
  declare dl int;

  dl := 0;
  declare exit handler for sqlstate '40001'
    {
      rollback work;
      if (dl > 6)
	resignal;

      dl := dl + 1;
      goto again;
    };

again:;
  update DB.DBA.td_state
     set td_oorders_ok = td_oorders_ok + 1;

  if (registry_get ('BPELTPCC_st') = 'fill')
    return;

  whenever not found goto nf;
  select td_oorders_ok into cnt from DB.DBA.td_state;
  if (not mod(cnt, 10))
    {
      commit work;
      asyncDelivery ();
    }
  nf:
  return 1;

};
grant execute on WS.TDPOINT.orderSuccess to TDPOINT;

create procedure random_lines(out nl int)
{
  declare cnt, i integer;
  declare aXML any;

  cnt := rnd(11)+5;

  aXML := DB.DBA.ol_xml( rnd(3000)+1, rnd(100)+1, 1);
  i := 2;
  while (i <= cnt)
  {
    aXML := XMLCONCAT(aXML, DB.DBA.ol_xml( rnd(3000)+1, rnd(100)+1, i));
    i := i + 1;
   };
  nl := i - 1;
  return aXML;

};

-- Order Fault Message
create procedure WS.TDPOINT.orderFault(in result int, in orderId decimal, in customerID int)
{
  --dbg_obj_print('================orderFault======================', orderId, customerID);
  declare dl int;

  dl := 0;
  declare exit handler for sqlstate '40001'
    {
      rollback work;
      if (dl > 6)
	resignal;

      dl := dl + 1;
      goto again;
    };
  again:;
  td_order_unregister (orderId, customerID);
  update DB.DBA.td_state
     set td_orders_failed = td_orders_failed + 1;

};
grant execute on WS.TDPOINT.orderFault to TDPOINT;

-- Payment receipt message
create procedure WS.TDPOINT.orderReceipt(in result int)
{
  --dbg_obj_print('============order is receipt ==================');
  declare dl int;

  dl := 0;
  declare exit handler for sqlstate '40001'
    {
      rollback work;
      if (dl > 6)
	resignal;

      dl := dl + 1;
      goto again;
    };
  again:;
  update DB.DBA.td_state
     set td_receipts = td_receipts + 1;

};
grant execute on WS.TDPOINT.orderReceipt to TDPOINT;

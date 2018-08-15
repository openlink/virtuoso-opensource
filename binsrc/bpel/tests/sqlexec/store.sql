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
use DB;


create table Demo.demo.Wholesalers
	 (
	   SellerID 	integer,
	   CompanyName 	varchar,
	   primary key (SellerID)
	 );

create table Demo.demo.EmailNotification (Addr varchar primary key, Subject varchar);

insert soft Demo.demo.Wholesalers (SellerID, CompanyName) values (0, 'Base Store');
insert soft Demo.demo.Wholesalers (SellerID, CompanyName) values (1, 'Star Store');
insert soft Demo.demo.Wholesalers (SellerID, CompanyName) values (2, 'Sea Store');
insert soft Demo.demo.Wholesalers (SellerID, CompanyName) values (3, 'World Store');
insert soft Demo.demo.Wholesalers (SellerID, CompanyName) values (4, 'Speedy Store');

insert soft Demo.demo.EmailNotification (Addr, Subject) values ('type_your_address_here', 'BPEL Inventory notification');

vhost_remove (lpath=>'/StoreSvc');

create user STORE;

vhost_define (lpath=>'/StoreSvc', ppath=>'/SOAP/', soap_user=>'STORE', soap_opts=>vector ('Use', 'literal', 'GeneratePartnerLink', 'yes', 'Namespace', 'http://samples.openlinksw.com/bpel', 'SchemaNS', 'http://samples.openlinksw.com/bpel', 'ServiceName', 'StoreService'));

drop type STORE..LineItem;
drop type STORE..Quote;

create type STORE..LineItem as
 (
   ItemID int,
   Quantity int,
   Price numeric
 )
;

create type STORE..Quote as
  (
   SellerID int,
   Price numeric
  )
  constructor method Quote (in s_id int, in prc numeric)
;

create constructor method Quote (in s_id int, in prc numeric) for STORE..Quote
{
  self.SellerID := s_id;
  self.Price := prc;
}
;

grant execute on STORE..LineItem to STORE;
grant execute on STORE..Quote to STORE;

sequence_set ('STOCK_OID', 3001, 1);

create procedure STORE..NewOrder (in Customer varchar, in Line STORE..LineItem) returns int
{
  declare o_id, s_id int;
  --# NewOrder operation : simulates a multiple service endpoints.

  s_id := http_param ('id');
  o_id := sequence_next ('STOCK_OID');

  return o_id;
}
;

create procedure STORE..GetQuote (in ItemID int) returns STORE..Quote array
{
  declare ret, prc, f any;
  whenever not found goto nf;
  select UnitPrice into prc from Demo.demo.Products where ProductID = ItemID;

  ret := vector (new STORE..Quote (0, cast (prc as decimal)));

  for select SellerID from Demo.demo.Wholesalers where SellerID > 0 do
    {
      f := rnd (10);
      if (f > 0)
	{
	  ret := vector_concat (ret, vector (new STORE..Quote (SellerID, prc - (f / 10.0))));
	}
    }

  return ret;
  nf:
  return vector ();
}
;

create procedure STORE..SendMail (in MsgText varchar)
    __soap_options (__soap_type:='__VOID__', OneWay:=1)
{
  declare msg any;
  for select Addr, Subject from Demo.demo.EmailNotification do
    {
      msg := concat ('Subject: ', Subject, '\r\n\r\n', MsgText, '\r\n');
      smtp_send (null, Addr, Addr, msg);
    }
  return;
}
;

grant execute on STORE..GetQuote to STORE;
grant execute on STORE..NewOrder to STORE;
grant execute on STORE..SendMail to STORE;

create procedure upload_inventory_process ()
{
  declare id any;
  bpel..import_script ('http://localhost:'||server_http_port ()||'/BPELDemo/sqlexec/bpel.xml', 'Inventory', id);
  bpel..compile_script (id, '/InventorySvc');
  update BPEL..partner_link_init set bpl_opts =
  '<wsOptions><addressing version="http://schemas.xmlsoap.org/ws/2004/03/addressing"/></wsOptions>'
  where bpl_script = id  and bpl_name = 'store';
};

--upload_dealer ();

create procedure DB..update_inventory ()
{
  declare req any;
  whenever not found goto nf;
  select xmlelement(Items,
  		xmlattributes ('http://temp.org' as xmlns),
		xmlagg (
		  xmlelement (item,
		    xmlelement (ProductID, ProductID),
		    xmlelement (Quantity, UnitsInStock + 10)
		    ))) into req
      from Demo..Products where UnitsInStock < 10 and Discontinued = 0;

  soap_client (	url=>'http://localhost:'|| server_http_port () ||'/InventorySvc',
      		operation=>'initiate',
		parameters=>vector ('par0', req),
		soap_action=>'initiate',
		style=>1
      );

  nf:
  return;
}
;

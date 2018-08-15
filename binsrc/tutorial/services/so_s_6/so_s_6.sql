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
vhost_remove (lpath=>'/ord');

vhost_define (lpath=>'/ord',ppath=>'/SOAP/', soap_user=>'demo');

create procedure 
Demo.demo.new_order (
    in _CustomerID varchar,
    in _EmployeeID integer,
    in _ShipVia integer,
    in _RequiredDate datetime,
    in _ProductID integer,
    in _Quantity integer,
    in _Discount double precision 
    )
{
  declare _oid, e integer;
  declare sn, sa, ac, ar, ap, ac , s, m varchar;
  declare up double precision;
  _oid := coalesce ((select max (OrderID) from Demo.demo.Orders), 0);
  _oid := _oid + 1;	
  e := 0;	
  declare exit handler for not found { s := __SQL_STATE; m := __SQL_MESSAGE; e := 1; };
  {  
    select ContactName, Address, City, Region, PostalCode, Country 
	into sn, sa, ac, ar, ap, ac
	from Demo.demo.Customers where CustomerID = _CustomerID;	
    select UnitPrice into up from Demo.demo.Products where ProductID = _ProductID;
    INSERT INTO Demo.demo.Orders (OrderID,CustomerID,EmployeeID,OrderDate,RequiredDate,ShippedDate,ShipVia,Freight,ShipName,ShipAddress,ShipCity,ShipRegion,ShipPostalCode,ShipCountry) 
	VALUES 
	(_oid, _CustomerID, _EmployeeID, now(), _RequiredDate, null, _ShipVia, 0, sn, sa, ac, ar, ap, ac); 
    INSERT INTO Demo.demo.Order_Details(OrderID,ProductID,UnitPrice,Quantity,Discount) VALUES
	(_oid, _ProductID, up, _Quantity, _Discount);
  }
  if (e)
    signal (s, m);
  return _oid;
}
;

create procedure Demo.demo.get_order (in id integer)
{
  declare ses any;
  ses := string_output ();
  xml_auto ('select * from Demo.demo.Orders "Order", Demo.demo.Order_Details OrderLine where  "Order".OrderID = ? and "Order".OrderID=OrderLine.OrderID for xml auto', vector (id), ses);
  ses := string_output_string (ses);
  return (ses);  
}
;

create procedure Demo.demo.get_customer_info (in search_mask varchar)
{
  declare ses any;
  ses := string_output ();
  xml_auto ('select CustomerID, CompanyName from Demo.demo.Customers where CompanyName like ? for xml auto', vector (concat (search_mask, '%')), ses);
  ses := string_output_string (ses);
  return (ses);  
}
;

grant execute on Demo.demo.new_order to demo;

grant execute on Demo.demo.get_order to demo;

grant execute on Demo.demo.get_customer_info to demo;

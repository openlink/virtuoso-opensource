--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2017 OpenLink Software
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
drop table ord;

drop table oline;

create table ord (oid varchar primary key, ocid varchar);

create table oline (olid varchar, olq integer, olp double precision);

create procedure
ord_sum ()
{
  declare ses, res any;
  ses := string_output ();
  http ('<doc>', ses);
  xml_auto ('SELECT  1 as Tag, NULL as Parent, OrderID as [id!1!OrderID], CustomerID as [cust!1!CustomerID], NULL as [oid!2!OrderID], NULL as [qty!2!Quantity], NULL as [prc!2!UnitPrice] from demo..orders where OrderId > 11010 and OrderID < 11021 union all select 2,1, o.orderid, NULL, ol.OrderID, ol.quantity, ol.unitprice from demo..orders o, demo..order_details ol where ol.OrderId > 11010 and ol.OrderID < 11021 and ol.Orderid = o.orderid order by [id!1!OrderID] for xml explicit'
      , vector (), ses);
  http ('</doc>', ses);
  ses := string_output_string (ses);
  res := xslt (TUTORIAL_XSL_DIR () || '/tutorial/xmlsql/xs_u_1/xs_u_1.xsl', xml_tree_doc (ses));
  xmlsql_update (res);
}
;

ord_sum ();


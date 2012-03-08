--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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
create procedure ord_root_node (in path any)
{
  declare node any;
  node := (select xmlelement ('Products',
	xmlagg (xmlelement ('Product',
		xmlelement('ID', od.ProductID), xmlelement ('Name', p.ProductName),
		xmlelement('UnitPrice', od.UnitPrice), xmlelement ('Quantity', od.Quantity)
		)))
	from demo.demo.order_details od, demo.demo.products p
	where  od.orderid = path and p.productid = od.productid);
  return xpath_eval ('//Products',node, 0);
}
;

create procedure ord_child_node (in path any, in node any)
{
  return xpath_eval ('./Product',node,0);
}
;

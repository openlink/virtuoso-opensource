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
drop procedure ms_remote;

create procedure ms_remote
        @mask varchar(15)
as

select c.CustomerID,
       c.CompanyName,
       o.OrderDate,
       o.ShippedDate,
       ol.ProductID,
       ol.Quantity,
       ol.Discount
       from Northwind..Customers c
       inner join Northwind..Orders o on c.CustomerID = o.CustomerID
       inner join Northwind.."Order Details" ol on o.OrderID = ol.OrderID
       where c.CustomerID like @mask
;

--  
--  $Id$
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
create user NWSVC;

DB.DBA.VHOST_REMOVE (lpath=>'/NorthwindSvc');

DB.DBA.VHOST_DEFINE (lpath=>'/NorthwindSvc', ppath=>'/SOAP/', soap_user=>'NWSVC',
    soap_opts => vector (
      'Namespace','http://demo.openlinksw.com/tutorial/services', 'SchemaNS', 'http://demo.openlinksw.com/tutorial/services',
      'MethodInSoapAction','yes',
      'ServiceName', 'NorthwindService', 'elementFormDefault', 'qualified', 'Use', 'literal'
      )
    )
;

use Demo;

drop type Demo.demo.CategoryVolume;

create type Demo.demo.CategoryVolume as (Name varchar, Volume numeric);

create procedure Demo.demo.SalesByCategory () returns Demo.demo.CategoryVolume array
{
  --## Sales by category
  declare dta any;
  declare item Demo.demo.CategoryVolume;
  dta := vector ();
  for select CategoryName, sum (od.UnitPrice*od.Quantity) as volume
    from Demo.demo.Products p, Demo.demo.Categories cat, Demo.demo.Order_details od
	where od.ProductId = p.ProductId and p.CategoryId = cat.CategoryId group by 1
	do
    {
      item := new Demo.demo.CategoryVolume ();
      item.Name := CategoryName;
      item.Volume := cast (volume as numeric);
      dta := vector_concat (dta, vector (item));
    }
  return dta;
}
;

create procedure Demo.demo.SalesByCategoryDate (in startDate datetime, in endDate datetime) returns Demo.demo.CategoryVolume array
{
  --## Sales by category for period
  declare dta any;
  declare item Demo.demo.CategoryVolume;
  dta := vector ();
  if (__tag (startDate) <> 211 or __tag (endDate) <> 211)
    signal ('22023', 'Invalid data is supplied');

  if (startDate > endDate)
    signal ('22023', 'The start date must be before end date');

  for select CategoryName, sum (od.UnitPrice*od.Quantity) as volume
    from Demo.demo.Products p, Demo.demo.Categories cat, Demo.demo.Orders o, Demo.demo.Order_details od
	where o.OrderId = od.OrderId and o.OrderDate >= startDate and o.OrderDate <= endDate
	and od.ProductId = p.ProductId and p.CategoryId = cat.CategoryId group by 1
	do
    {
      item := new Demo.demo.CategoryVolume ();
      item.Name := CategoryName;
      item.Volume := cast (volume as numeric);
      dta := vector_concat (dta, vector (item));
    }
  return dta;
}
;

grant execute on Demo.demo.CategoryVolume to NWSVC;
grant execute on Demo.demo.SalesByCategory to NWSVC;
grant execute on Demo.demo.SalesByCategoryDate to NWSVC;

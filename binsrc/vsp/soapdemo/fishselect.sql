--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2016 OpenLink Software
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
create procedure WS.SOAP.fishselect (in companymask varchar)
{
  --##Returns the order info for a company subset
  declare cr cursor for
        select cu."CompanyName", cast (o."OrderDate" as varchar), p."ProductName"
	from "Demo"."demo"."Order_Details" od, "Demo"."demo"."Orders" o, "Demo"."demo"."Products" p,
		"Demo"."demo"."Categories" ca, "Demo"."demo"."Customers" cu
	where cu."CompanyName" like companymask
	and ca."CategoryName" like '%eafood%'
	and cu."CustomerID" = o."CustomerID"
	and o."OrderID" = od."OrderID"
	and p."ProductID" = od."ProductID"
	and ca."CategoryID" = p."CategoryID";
  declare outp, cn, od, pn varchar;

  open cr;
  outp := '';
  whenever not found goto done;
  while (1)
    {
      fetch cr into cn, od, pn;
      if (isnull(cn)) cn := '<NULL>';
      if (isnull(od)) od := '<NULL>';
      if (isnull(pn)) pn := '<NULL>';
      outp := concat (outp, cn, '\t', od, '\t', pn, '\t');
    }
done:
  close cr;
  return outp;
};

grant execute on WS.SOAP.fishselect to SOAP;

call WS.SOAP.fishselect ('G%');

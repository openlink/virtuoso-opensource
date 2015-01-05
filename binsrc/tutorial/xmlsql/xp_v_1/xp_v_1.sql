--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2015 OpenLink Software
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
create xml view "cat" as
{
  "Demo"."demo"."Categories" c as "category" ("CategoryID", "Description" as "description")
    {
      "Demo"."demo"."Products" p as "product"  ("ProductName")
	on (p."CategoryID" = c."CategoryID")
    }
}
;

create xml view "product" as
{
  "Demo"."demo"."Products" p as "product" 
      ("ProductID", "ProductName" as "product_name", "UnitPrice" as "price", "SupplierID", "CategoryID")
    {
      "Demo"."demo"."Suppliers" s as "supplier"  ("CompanyName")
	on (s."SupplierID" = p."SupplierID")
       ,
      "Demo"."demo"."Categories" c as "category"  ("Description")
	on (c."CategoryID" = p."CategoryID")
    }
}
;

--
--  obackupck.sql
--
--  $Id: obackupck.sql,v 1.9.10.1 2013/01/02 16:14:51 source Exp $
--
--  Concurrency test #2
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

create procedure beautify (in num double precision)
{
  declare ceil integer;
  declare ceil2 integer;
  declare ceil3 integer;


  ceil := num;

  ceil2 := (cast (num*100 as integer)) - 100 * cast (num as integer);

  return sprintf ('%d.%02d', ceil, ceil2);
}
;

select cpt_remap_pages();
ECHO BOTH $LAST[1] " checkpoint remap pages\n";

select backup_pages();
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH " pages changed since last backup (in checkpoint space) = " $LAST[1] "\n";


select count (*) from "Demo.demo.Categories";
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH " Categoriess table has " $LAST[1] " entries\n";

select count (*) from "Demo.demo.Shippers";
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH " Shippers table has " $LAST[1] " entries\n";

select count (*) from "Demo.demo.Suppliers";
ECHO BOTH $IF $EQU $LAST[1] 29 "PASSED" "***FAILED";
ECHO BOTH " Suppliers table has " $LAST[1] " entries\n";

select count (*) from "Demo.demo.Products";
ECHO BOTH $IF $EQU $LAST[1] 77 "PASSED" "***FAILED";
ECHO BOTH " Products table has " $LAST[1] " entries\n";

select count (*) from "Demo.demo.Customers";
ECHO BOTH $IF $EQU $LAST[1] 91 "PASSED" "***FAILED";
ECHO BOTH " Customers table has " $LAST[1] " entries\n";

select count (*) from "Demo.demo.Employees";
ECHO BOTH $IF $EQU $LAST[1] 9 "PASSED" "***FAILED";
ECHO BOTH " Employees table has " $LAST[1] " entries\n";

select count (*) from "Demo.demo.Orders";
ECHO BOTH $IF $EQU $LAST[1] 830 "PASSED" "***FAILED";
ECHO BOTH " Orders table has " $LAST[1] " entries\n";

select count (*) from "Demo.demo.Order_Details";
ECHO BOTH $IF $EQU $LAST[1] 2155 "PASSED" "***FAILED";
ECHO BOTH " Ordre_Details table has " $LAST[1] " entries\n";

select count (*) from "Demo"."demo"."Categories" where cast ("Description" as varchar) = 'updated';
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH " Categories table has " $LAST[1] " updated entries\n";
select count (*) from "Demo"."demo"."Shippers" where "Phone" = 'updated';
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH " Shippers table has " $LAST[1] " updated entries\n";
select count (*) from "Demo"."demo"."Suppliers" where "City" = 'updated';
ECHO BOTH $IF $EQU $LAST[1] 29 "PASSED" "***FAILED";
ECHO BOTH " Suppliers table has " $LAST[1] " updated entries\n";
select count (*) from "Demo"."demo"."Products" where "ProductName" = 'updated';
ECHO BOTH $IF $EQU $LAST[1] 77 "PASSED" "***FAILED";
ECHO BOTH " Products table has " $LAST[1] " updated entries\n";
select count (*) from "Demo"."demo"."Customers" where "ContactTitle" = 'updated';
ECHO BOTH $IF $EQU $LAST[1] 91 "PASSED" "***FAILED";
ECHO BOTH " Customers table has " $LAST[1] " updated entries\n";
select count (*) from "Demo"."demo"."Employees" where "Address" = 'updated';
ECHO BOTH $IF $EQU $LAST[1] 9 "PASSED" "***FAILED";
ECHO BOTH " Employees table has " $LAST[1] " updated entries\n";
select count (*) from "Demo"."demo"."Orders" where "ShipName" = 'updated';
ECHO BOTH $IF $EQU $LAST[1] 830 "PASSED" "***FAILED";
ECHO BOTH " Orders table has " $LAST[1] " updated entries\n";
select count (*) from "Demo"."demo"."Order_Details" where "Quantity" = -1;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH " Order_Details table has " $LAST[1] " updated entries\n";

select beautify (sum ("Freight")) from "Demo"."demo"."Orders";
ECHO BOTH $IF $EQU $LAST[1] 65772.69 "PASSED" "***FAILED";
ECHO BOTH " Common freight " $LAST[1] "\n";

select beautify (sum ("UnitPrice" * "Quantity")) from "Demo"."demo"."Order_Details";
ECHO BOTH $IF $EQU $LAST[1] 102634.00 "PASSED" "***FAILED";
ECHO BOTH " Price of all goods " $LAST[1] "\n";


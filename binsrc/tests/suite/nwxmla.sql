--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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


create procedure xmla (in q varchar)
{
  declare st any;
  declare len integer;
  st := string_output ();
  xml_auto (q, vector (), st);
  result_names (q, len);
  q := string_output_string (st);
  len := length (q);
  result (q, strchr (q, '>'));
}



xmla ('  select "category"."CategoryID", "CategoryName",
    "ProductName", "ProductID"
    from "Demo".."Categories" "category", "Demo".."Products" as "product"
    where "product"."CategoryID" = "category"."CategoryID" for xml auto element');
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": for XML auto element returned " $ROWCNT " rows\n";


xmla ('  select "category"."CategoryID", "CategoryName",
    "ProductName", "ProductID"
    from "Demo".."Categories" "category", "Demo".."Products" as "product"
    where "product"."CategoryID" = "category"."CategoryID" for xml raw element');
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": for XML raw element returned " $ROWCNT " rows\n";

xmla ('
select 1 as tag, null as parent,
       "CategoryID" as ["category"!1!"cid"],
       "CategoryName" as ["category"!1!"name"],
       NULL as ["product"!2!"pid"],
       NULL as ["product"!2!"name"!"element"]
from "Demo".."Categories"
union all
select 2, 1, "category" ."CategoryID", NULL, "ProductID", "ProductName"
    from "Demo".."Categories" "category", "Demo".."Products" as "product"
    where "product"."CategoryID" = "category"."CategoryID"
order by ["category"!1!"cid"], 5
for xml explicit');
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": for XML explicit 1 returned " $ROWCNT " rows\n";

xmla ('
 SELECT  1 as Tag, NULL as Parent, "CustomerID" as ["Customer"!1!"CustomerID"], NULL as ["Order"!2!"OrderID"] FROM "Demo".."Customers" UNION ALL SELECT  2, 1, "customers"."CustomerID", "orders"."OrderID" FROM "Demo".."Customers" "customers" , "Demo".."Orders" "orders" WHERE  "customers"."CustomerID" = "orders"."CustomerID" ORDER BY ["Customer"!1!"CustomerID"] FOR XML EXPLICIT');
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": for XML explicit 2 returned " $ROWCNT " rows\n";

 xmla ('
 SELECT 1 as Tag, NULL as Parent, "Demo".."Customers"."CustomerID" as ["Customer"!1!"CustomerID"], NULL as ["Order"!2!"OrderID"!hide], NULL as ["Order"!2!"OrderDate"] FROM    "Demo".."Customers" UNION   ALL SELECT  2, 1, "Demo".."Customers"."CustomerID", "Demo".."Orders"."OrderID", "Demo".."Orders"."OrderDate" FROM    "Demo".."Customers", "Demo".."Orders" WHERE   "Demo".."Customers"."CustomerID" = "Demo".."Orders"."CustomerID" ORDER BY ["Customer"!1!"CustomerID"] FOR XML EXPLICIT');

ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": for XML explicit 3 returned " $ROWCNT " rows\n";

drop table "son_billing";
create table "son_billing"
(
 "ticket_id" integer,
 "batch_in" integer,
 "batch_in_file" varchar(50),
 "batch_out" integer,
 "md2_timestamp" varchar(20),
 "platform_ticket_id" varchar(50),
 "operator_code" varchar(20),
 "rate_category" integer,
 "billing_flag" varchar(5),
 "service_parameter_1" varchar(50),
 "service_parameter_2" varchar(50),
 "terminal_type" varchar(20),
 "currency" varchar(5),
 "user_msisdn" varchar(20),
 "user_id" varchar(20),
 "service_address" varchar(30),
 "service_name" varchar(30),
 "service_quantity" varchar(20),
 "service_subject" varchar(30),
 "service_target" varchar(50),
 "service_type" integer,
 "service_status" integer,
 "platform_status" varchar(30),
 "content_provider" varchar(30),
 "content_address" varchar(1024),
 "ticket_info" varchar(50),
 "service_start_time" varchar(20),
 "service_end_time" varchar(20),
 "sms_sp_ms" integer,
 "sms_ms_sp" integer,
 "bytes_sp_ms" integer,
 "bytes_ms_sp" integer,
 "bytes_sp_cp" integer,
 "bytes_cp_sp" integer,
 primary key ("ticket_id")
);
insert into "son_billing" ("ticket_id") values (1);

drop table "son_tickets";
create table "son_tickets" (
 "ticket_id" integer,
 primary key ("ticket_id")
);
insert into "son_tickets" values (1);

drop xml view "pay";
create xml view "pay" as
{
"son_tickets" "t" as "ticket" ("ticket_id") {
  "son_billing" "b" as "ticket_id" ("ticket_id"),
  "son_billing" "b" as "batch_in" ("batch_in"),
  "son_billing" "b" as "batch_in_file" ("batch_in_file"),
  "son_billing" "b" as "batch_out" ("batch_out"),
  "son_billing" "b" as "md2_timestamp" ("md2_timestamp"),
  "son_billing" "b" as "platform_ticket_id" ("platform_ticket_id"),
  "son_billing" "b" as "operator_code" ("operator_code"),
  "son_billing" "b" as "rate_category" ("rate_category"),
  "son_billing" "b" as "billing_flag" ("billing_flag"),
  "son_billing" "b" as "service_parameter_1" ("service_parameter_1"),
  "son_billing" "b" as "service_parameter_2" ("service_parameter_2"),
  "son_billing" "b" as "terminal_type" ("terminal_type"),
  "son_billing" "b" as "currency" ("currency"),
  "son_billing" "b" as "user_msisdn" ("user_msisdn"),
  "son_billing" "b" as "user_id" ("user_id"),
  "son_billing" "b" as "service_address" ("service_address"),
  "son_billing" "b" as "service_name" ("service_name"),
  "son_billing" "b" as "service_quantity" ("service_quantity"),
  "son_billing" "b" as "service_subject" ("service_subject"),
  "son_billing" "b" as "service_target" ("service_target"),
  "son_billing" "b" as "service_type" ("service_type"),
  "son_billing" "b" as "service_status" ("service_status"),
  "son_billing" "b" as "platform_status" ("platform_status"),
  "son_billing" "b" as "content_provider" ("content_provider"),
  "son_billing" "b" as "content_address" ("content_address"),
  "son_billing" "b" as "ticket_info" ("ticket_info"),
  "son_billing" "b" as "service_start_time" ("service_start_time"),
  "son_billing" "b" as "service_end_time" ("service_end_time"),
  "son_billing" "b" as "sms_sp_ms" ("sms_sp_ms"),
  "son_billing" "b" as "sms_ms_sp" ("sms_ms_sp"),
  "son_billing" "b" as "bytes_sp_ms" ("bytes_sp_ms"),
  "son_billing" "b" as "bytes_ms_sp" ("bytes_ms_sp"),
  "son_billing" "b" as "bytes_sp_cp" ("bytes_sp_cp"),
  "son_billing" "b" as "bytes_cp_sp" ("bytes_cp_sp")
  on ("b"."ticket_id" = "t"."ticket_id")
  }
};

xmla ('SELECT "FirstName" as "firstname", "LastName" as "lastname" FROM "Demo".."Employees" "Employees" FOR XML AUTO');
ECHO BOTH $IF $NEQ $LAST[2] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": for XML auto with AS statements returned " $ROWCNT " rows\n";

drop view xmla_view;
create procedure view xmla_view as xmla (par) (q varchar, q2 integer);
select xpath_eval (
    '/Customers/Orders/Order_Details/@UnitPrice'
    , xml_tree_doc (q)) from
xmla_view where par =
'SELECT "Demo"."demo"."Customers"."CompanyName", "Demo"."demo"."Orders"."OrderDate", "Demo"."demo"."Order_Details"."UnitPrice" FROM "Demo"."demo"."Customers" INNER  JOIN ("Demo"."demo"."Order_Details" INNER  JOIN "Demo"."demo"."Orders" ON "Demo"."demo"."Order_Details"."OrderID" = "Demo"."demo"."Orders"."OrderID") ON "Demo"."demo"."Customers"."CustomerID" = "Demo"."demo"."Orders"."CustomerID" where "Demo"."demo"."Customers"."CompanyName" = ''Alfreds Futterkiste'' and "Demo"."demo"."Order_Details"."UnitPrice" = 10
FOR XML AUTO';
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 2443-1: xml auto names returned UnitPrice=" $LAST[1] "\n";

select xpath_eval (
'/x1/x2/x3/@UnitPrice'
    , xml_tree_doc (q)) from
xmla_view where par =
'SELECT "x1"."CompanyName", "x2"."OrderDate", "x3"."UnitPrice" FROM "Demo"."demo"."Customers" "x1" INNER  JOIN ("Demo"."demo"."Order_Details" "x3" INNER  JOIN "Demo"."demo"."Orders" "x2" ON "x2"."OrderID" = "x3"."OrderID") ON "x1"."CustomerID" = "x2"."CustomerID" where "x1"."CompanyName" = ''Alfreds Futterkiste'' and "x3"."UnitPrice" = 10 FOR XML AUTO';
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 2443-2: xml auto names w/aliases returned UnitPrice=" $LAST[1] "\n";

select xpath_eval (
    '/Customers/Orders/Order_Details/@UnitPrice'
    , xml_tree_doc (q)) from
xmla_view where par =
'SELECT "Demo"."demo"."Customers"."CompanyName", "Demo"."demo"."Orders"."OrderDate", "Demo"."demo"."Order_Details"."UnitPrice" FROM "Demo"."demo"."Customers" , "Demo"."demo"."Order_Details" , "Demo"."demo"."Orders" WHERE "Demo"."demo"."Order_Details"."OrderID" = "Demo"."demo"."Orders"."OrderID" AND "Demo"."demo"."Customers"."CustomerID" = "Demo"."demo"."Orders"."CustomerID" and "Demo"."demo"."Customers"."CompanyName" = ''Alfreds Futterkiste'' and "Demo"."demo"."Order_Details"."UnitPrice" = 10 FOR XML AUTO';
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 2443-3: xml auto names w/o JOIN returned UnitPrice=" $LAST[1] "\n";



XPATH [__view 'pay'] //*;
-- */
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": xml view with a large number of columns STATE=" $STATE " MESSAGE=" $MESSAGE " rows\n";

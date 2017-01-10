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
use Demo;

DB.DBA.exec_no_error('create view Demo.demo.OrdersPeriods as
        select distinct year(OrderDate) as year, month(OrderDate) as month,
        sprintf (\'%d-%d\', year(OrderDate),month(OrderDate)) as yearmonth
        from Demo.demo.Orders');

DB.DBA.exec_no_error('create view Demo.demo.OrderCategoryPeriod as
        select sprintf (\'%d-%d\', year(o1.OrderDate), month(o1.OrderDate)) as yearmonth,
        cat.CategoryName as CategoryName, sum (od.Quantity*od.UnitPrice*(1-od.Discount)) as volume
        from Demo.demo.Orders o1, Demo.demo.Order_Details od, Demo.demo.Products p, Demo.demo.Categories cat
        where od.OrderID = o1.OrderID and od.ProductID = p.ProductID and p.CategoryID = cat.CategoryID group by 1,2');

use DB;

xml_load_mapping_schema_decl ('file:/tutorial/xml/usecases/', 'map01.xsd', 'UTF-8', 'x-any');
xml_load_mapping_schema_decl ('file:/tutorial/xml/usecases/', 'map02.xsd', 'UTF-8', 'x-any');

create procedure load_xml_usecase (in name varchar, in descr any)
{
  declare cnt any;
  --cnt := db.dba.xml_uri_get ('', 'file:/tutorial/xml/usecases/'||name);
  --DB.DBA.DAV_RES_UPLOAD ('/DAV/xmlsql/'||name, cnt, '', '111101101N', http_dav_uid(), http_dav_uid() + 1, 'dav', 'dav');
  DB.DBA.DAV_PROP_SET ('/DAV/xmlsql/'||name, 'xml-template', 'execute', 'dav', 'dav');
  DB.DBA.DAV_PROP_SET ('/DAV/xmlsql/'||name, 'xml-sql-description', descr, 'dav', 'dav');
}
;

load_xml_usecase ('sqlx01.xml', 'Q1: Orders for Customer');
load_xml_usecase ('sqlx03.xml', 'Q3: Orders for Customer after 1995');
load_xml_usecase ('sqlx04.xml', 'Q4: Orders for Customer for 1995');
load_xml_usecase ('sqlx02.xml', 'Q2: Sales by Month using SQLX');
load_xml_usecase ('map02.xml' , 'Q9: Sales by Month using XMLSchema mapping');
load_xml_usecase ('map03.xml' , 'Q8: Orders for Customers having a name starting with "A"');
load_xml_usecase ('xq04.xml' ,  'Q5: Sales by month, ordered by sales');
load_xml_usecase ('xq05.xml' ,  'Q6: Sales by month with category either desserts or beverages');
load_xml_usecase ('xq06.xml' ,  'Q7: Sales by month for 1995 and category either desserts or beverages');

load_xml_usecase ('xqr01.xml' ,  'XQ1: All articles');
load_xml_usecase ('xqr02.xml' ,  'XQ1: Articles about Indigo');
load_xml_usecase ('xqr03.xml' ,  'XQ1: Articles for ASP.NET technology');

load_xml_usecase ('sq01.xml' ,  'SQ1: All bib documents');
load_xml_usecase ('sq02.xml' ,  'SQ2: Basic FLWR expression');
load_xml_usecase ('sq03.xml' ,  'SQ3: All book titles');
load_xml_usecase ('sq04.xml' ,  'SQ4: Query with WHERE clause filtering');
load_xml_usecase ('sq05.xml' ,  'SQ5: Query with XPath filtering');
load_xml_usecase ('sq06.xml' ,  'SQ6: Query with WHERE clause combined with XPath');

load_xml_usecase ('slash.xml' ,  'Transforming an RSS feed to HTML');


--
--  $Id: xmlsql.sql,v 1.8.10.1 2013/01/02 16:15:40 source Exp $
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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
create procedure INSERT_RESOURCE (in _stmt varchar, in _name varchar, in _root varchar, in _sty varchar, in _refresh integer)
{
  declare _col_id, _r_id integer;
  declare ses any;
  declare _res varchar;

  _name := concat (_name, '.xml');
  _res := concat ('/DAV/xmlsql/', _name);
  _sty := coalesce (_sty, '');
  _root := coalesce (_root, 'root');

  if (_refresh = -1)
    {
      ses := '';
    }
  else
    {
      ses := string_output ();
      xml_auto (_stmt, vector(), ses);
      ses := string_output_string ();
      if (_root <> '')
        ses := concat ('<', _root, '>\n', ses, '</', _root, '>\n');
      if (_refresh > 0)
        insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
             values (_res, now (), sprintf ('WS.WS.XML_AUTO_SCHED (''%s'')', _res), _refresh);
      else
	delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = _res;
    }

  delete from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _res;
  WS.WS.FINDCOL (vector ('DAV', 'xmlsql'), _col_id);
  _r_id := WS.WS.GETID ('R');
	insert into WS.WS.SYS_DAV_RES
		    (RES_ID,
		     RES_NAME,
		     RES_COL,
		     RES_TYPE,
		     RES_CONTENT,
		     RES_CR_TIME,
		     RES_MOD_TIME,
		     RES_OWNER,
		     RES_GROUP,
		     RES_PERMS)
	       values (_r_id,
		       _name,
		       _col_id,
		       'text/xml',
		       ses,
		       now (),
		       now (),
		       http_dav_uid(),
		       http_dav_uid()+1,
		       '110100100N');
	if (_sty <> '' and exists (select 1 from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _sty))
	  insert replacing WS.WS.SYS_DAV_PROP (PROP_ID, PROP_NAME, PROP_TYPE, PROP_PARENT_ID, PROP_VALUE)
	       values (WS.WS.GETID ('P'), 'xml-stylesheet', 'R', _r_id,
		   concat ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:', _sty));
	if (_stmt <> '')
	  insert replacing WS.WS.SYS_DAV_PROP (PROP_ID, PROP_NAME, PROP_TYPE, PROP_PARENT_ID, PROP_VALUE)
	      values (WS.WS.GETID ('P'), 'xml-sql', 'R', _r_id, _stmt);
	if (_root <> '')
	  insert replacing WS.WS.SYS_DAV_PROP (PROP_ID, PROP_NAME, PROP_TYPE, PROP_PARENT_ID, PROP_VALUE)
	       values (WS.WS.GETID ('P'), 'xml-sql-root', 'R', _r_id, _root);
}

create procedure INSERT_XSLT_REF (in _name varchar, in _sty varchar)
{
  declare _col_id, _r_id integer;
  declare _res varchar;

  _name := concat (_name, '.xml');
  _res := concat ('/DAV/docsrc/', _name);
  _sty := coalesce (_sty, '');

  delete from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _res;
  WS.WS.FINDCOL (vector ('DAV', 'docsrc'), _col_id);
  _r_id := WS.WS.GETID ('R');
	insert into WS.WS.SYS_DAV_RES
		    (RES_ID,
		     RES_NAME,
		     RES_COL,
		     RES_TYPE,
		     RES_CONTENT,
		     RES_CR_TIME,
		     RES_MOD_TIME,
		     RES_OWNER,
		     RES_GROUP,
		     RES_PERMS)

	       values (_r_id,
		       _name,
		       _col_id,
		       'text/xml',
		       (select RES_CONTENT from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/docsrc/virtdocs.xml'),
		       now (),
		       now (),
		       http_dav_uid(),
		       http_dav_uid() + 1,
		       '110100100N');
	if (_sty <> '' and exists (select 1 from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _sty))
	  insert replacing WS.WS.SYS_DAV_PROP (PROP_ID, PROP_NAME, PROP_TYPE, PROP_PARENT_ID, PROP_VALUE)
	       values (WS.WS.GETID ('P'), 'xml-stylesheet', 'R', _r_id,
		   concat ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:', _sty));
}


create procedure PUTFILE (in _file varchar, in _name varchar)
{
  declare _col_id, _r_id integer;
  declare _res varchar;
  _res := concat ('/DAV/xmlsql/', _name);
  delete from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _res;
  WS.WS.FINDCOL (vector ('DAV', 'xmlsql'), _col_id);
  _r_id := WS.WS.GETID ('R');
	insert into WS.WS.SYS_DAV_RES
		    (RES_ID,
		     RES_NAME,
		     RES_COL,
		     RES_TYPE,
		     RES_CONTENT,
		     RES_CR_TIME,
		     RES_MOD_TIME,
		     RES_OWNER,
		     RES_GROUP,
		     RES_PERMS)
	       values (_r_id,
		       _name,
		       _col_id,
		       'text/xsl',
		       file_to_string (_file),
		       now (),
		       now (),
		       http_dav_uid(),
		       http_dav_uid()+1,
		       '110100100N');
}
;


delete from WS.WS.SYS_DAV_COL where COL_NAME = 'xmlsql';
insert into WS.WS.SYS_DAV_COL (COL_ID, COL_NAME, COL_PARENT, COL_CR_TIME, COL_MOD_TIME, COL_OWNER, COL_GROUP, COL_PERMS) values (WS.WS.GETID ('C'), 'xmlsql', 1, now(), now(),http_dav_uid(),http_dav_uid()+1, '110100100N');

INSERT_RESOURCE ('SELECT CustomerID,ContactName FROM Demo.demo.Customers FOR XML RAW', 'URLSimpleQuery', NULL, NULL, -1);
--select xml_uri_get ('http://localhost:6666/DAV/xmlsql', 'URLSimpleQuery.xml');

INSERT_RESOURCE ('SELECT Customers.CustomerID,OrderID,OrderDate FROM Demo..Customers Customers, Demo..Orders Orders WHERE Customers.CustomerID=Orders.CustomerID Order by Customers.CustomerID,OrderID FOR XML AUTO', 'URLMultiTable', NULL, NULL, -1);
--select xml_uri_get ('http://localhost:6666/DAV/xmlsql', 'URLMultiTable.xml');

INSERT_RESOURCE ('SELECT DISTINCT ContactTitle FROM Demo..Customers WHERE ContactTitle LIKE ''Sa%'' ORDER bY ContactTitle FOR XML AUTO', 'URLSpecialChars', NULL, NULL, -1);
--select xml_uri_get ('http://localhost:6666/DAV/xmlsql', 'URLSpecialChars.xml');


-- Original : INSERT_RESOURCE ('SELECT FirstName FROM Demo..Employees Employees WHERE EmployeeID=1', 'URLSingleVal', NULL, NULL, -1);
INSERT_RESOURCE ('SELECT FirstName FROM Demo..Employees Employees WHERE EmployeeID=1 FOR XML AUTO', 'URLSingleVal', NULL, NULL, -1);
--select xml_uri_get ('http://localhost:6666/DAV/xmlsql', 'URLSingleVal.xml');

PUTFILE ('emp_my.xsl', 'emp.xsl');
PUTFILE ('emp.xsl', 'emp_orig.xsl');
INSERT_RESOURCE ('SELECT FirstName as "firstname", LastName as "lastname" FROM Demo..Employees Employees FOR XML AUTO', 'URLXsl', NULL, '/DAV/xmlsql/emp.xsl', -1);
--select xml_uri_get ('http://localhost:6666/DAV/xmlsql', 'URLXsl.xml');

create procedure CATEGORY_INFO ()
{
  declare CategoryName varchar;

  result_names (CategoryName);
  for select CategoryName from Demo..Categories do
    result (CategoryName);
};

--- NOT SUPPORTED : INSERT_RESOURCE ('CATEGORY_INFO() FOR XML AUTO', 'URLProc', NULL, NULL, -1);

INSERT_RESOURCE ('select * from Demo..Customers for xml auto', 'TemplateSimple', NULL, NULL, -1);
--select xml_uri_get ('http://localhost:6666/DAV/xmlsql', 'TemplateSimple.xml');
INSERT_RESOURCE ('SELECT Customers.CustomerID, Orders.OrderID, Orders.OrderDate FROM Demo..Customers Customers, Demo..Orders Orders WHERE Customers.CustomerID = Orders.CustomerID ORDER BY Customers.CustomerID FOR XML RAW', 'ModeRaw', NULL, NULL, -1);
--select xml_uri_get ('http://localhost:6666/DAV/xmlsql', 'ModeRaw.xml');
INSERT_RESOURCE ('SELECT C.CustomerID, O.OrderID, O.OrderDate FROM Demo..Customers C LEFT OUTER JOIN Demo..Orders O ON C.CustomerID = O.CustomerID ORDER BY C.CustomerID FOR XML RAW', 'ModeRawJoin', NULL, NULL, -1);
--select xml_uri_get ('http://localhost:6666/DAV/xmlsql', 'ModeRawJoin.xml');
--- NOT SUPPORTED : INSERT_RESOURCE ('SELECT Customers.CustomerID, Orders.OrderID, Orders.OrderDate FROM Demo..Customers Customers, Demo..Orders Orders WHERE Customers.CustomerID = Orders.CustomerID ORDER BY Customers.CustomerID FOR XML RAW, DTD', 'ModeRawDtd', NULL, NULL, -1);


INSERT_RESOURCE ('SELECT Customers.CustomerID, OrderID, LastName AS EmpLastName FROM Demo..Customers Customers, Demo..Orders Orders, Demo..Employees Employees WHERE Customers.CustomerID = Orders.CustomerID AND Orders.EmployeeID = Employees.EmployeeID FOR XML AUTO', 'ModeAutoTriple', NULL, NULL, -1);
--select xml_uri_get ('http://localhost:6666/DAV/xmlsql', 'ModeAutoTripple.xml');

INSERT_RESOURCE ('SELECT LastName AS EmpLastName, OrderID, Customers.CustomerID FROM Demo..Customers Customers, Demo..Orders Orders, Demo..Employees Employees WHERE Customers.CustomerID = Orders.CustomerID AND Orders.EmployeeID = Employees.EmployeeID FOR XML AUTO', 'ModeAutoTripleColChanged', NULL, NULL, -1);
--select xml_uri_get ('http://localhost:6666/DAV/xmlsql', 'ModeAutoTrippleColChanged.xml');

INSERT_RESOURCE ('SELECT  1 as Tag, NULL as Parent, "CustomerID" as [Customer!1!CustomerID], NULL as ["Order"!2!OrderID] FROM "Demo".."Customers" UNION ALL SELECT  2, 1, "customers"."CustomerID", "orders"."OrderID" FROM "Demo".."Customers" "customers" , "Demo".."Orders" "orders" WHERE  "customers".CustomerID = "orders"."CustomerID" ORDER BY [Customer!1!CustomerID], ["Order"!2!OrderID] FOR XML EXPLICIT', 'ModeExplicit', NULL, NULL, -1);

INSERT_RESOURCE ('SELECT 1 as Tag, NULL as Parent, Demo..Customers.CustomerID as [Customer!1!CustomerID], NULL as ["Order"!2!OrderID!hide], NULL as ["Order"!2!OrderDate] FROM    Demo..Customers UNION   ALL SELECT  2, 1, Demo..Customers.CustomerID, Demo..Orders.OrderID, Demo..Orders.OrderDate FROM    Demo..Customers, Demo..Orders WHERE   Demo..Customers.CustomerID = Demo..Orders.CustomerID ORDER BY [Customer!1!CustomerID], ["Order"!2!OrderID!hide] FOR XML EXPLICIT', 'ModeExplicitHide', NULL, NULL, -1);
PUTFILE ('html_v.xsl', 'xtml_v.xsl');
PUTFILE ('html_common_v.xsl', 'xtml_common_v.xsl');

INSERT_XSLT_REF ('docs_html', '/DAV/stylesheets/html_xt.xsl');
INSERT_XSLT_REF ('docs_txt', '/DAV/stylesheets/txt_xt.xsl');

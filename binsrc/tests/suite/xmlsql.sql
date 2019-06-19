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

create procedure INSERT_RESOURCE (
  in _stmt varchar,
  in _name varchar,
  in _root varchar,
  in _sty varchar,
  in _refresh integer)
{
  declare _ses any;
  declare _res varchar;

  _name := concat (_name, '.xml');
  _res := concat ('/DAV/xmlsql/', _name);
  _sty := coalesce (_sty, '');
  _root := coalesce (_root, 'root');

  if (_refresh = -1)
    {
      _ses := '';
    }
  else
    {
      _ses := string_output ();
      xml_auto (_stmt, vector(), _ses);
      _ses := string_output_string ();
      if (_root <> '')
        _ses := concat ('<', _root, '>\n', _ses, '</', _root, '>\n');

      if (_refresh > 0)
        insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
             values (_res, now (), sprintf ('WS.WS.XML_AUTO_SCHED (''%s'')', _res), _refresh);
      else
	delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = _res;
    }

  DB.DBA.DAV_DELETE_INT (_res, 1, null, null, 1);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (_res, _ses, 'text/xml', '110100100N', http_dav_uid (), http_dav_uid () + 1, null, null, 0);

	if (_sty <> '' and exists (select 1 from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _sty))
    DB.DBA.DAV_PROP_SET_INT (_res, 'xml-stylesheet', 'virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:' || _sty, null, null, 0, 0, 1, http_dav_uid ());

	if (_stmt <> '')
    DB.DBA.DAV_PROP_SET_INT (_res, 'xml-sql', _stmt, null, null, 0, 0, 1, http_dav_uid ());

	if (_root <> '')
    DB.DBA.DAV_PROP_SET_INT (_res, 'xml-sql-root', _root, null, null, 0, 0, 1, http_dav_uid ());
}
;

create procedure INSERT_XSLT_REF (
  in _name varchar,
  in _sty varchar)
{
  declare _res varchar;
  declare _ses any;

  _name := concat (_name, '.xml');
  _res := concat ('/DAV/docsrc/', _name);
  _sty := coalesce (_sty, '');
  _ses := (select RES_CONTENT from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/docsrc/virtdocs.xml');

  DB.DBA.DAV_DELETE_INT (_res, 1, null, null, 1);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (_res, _ses, 'text/xml', '110100100N', http_dav_uid (), http_dav_uid () + 1, null, null, 0);

	if (_sty <> '' and exists (select 1 from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _sty))
    DB.DBA.DAV_PROP_SET_INT (_res, 'xml-stylesheet', 'virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:' || _sty, null, null, 0, 0, 1, http_dav_uid ());
}
;

create procedure PUTFILE (
  in _file varchar,
  in _name varchar)
{
  declare _res varchar;
  declare _ses any;

  _res := concat ('/DAV/xmlsql/', _name);
  _ses := file_to_string (_file);

  DB.DBA.DAV_DELETE_INT (_res, 1, null, null, 1);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (_res, _ses, 'text/xsl', '110100100N', http_dav_uid (), http_dav_uid () + 1, null, null, 0);
}
;

create procedure DELETE_FOLDER (
  in _res varchar)
{
  declare N integer;
  declare _ret any;

  _ret := DB.DBA.DAV_DIR_LIST (_res, 0, auth_uname=>'dav', auth_pwd=>DB.DBA.DAV_DET_PASSWORD (http_dav_uid ()));
  if (not isnull (DB.DBA.DAV_HIDE_ERROR (_ret)))
  {
    for (N := 0; N < length (_ret); N := N + 1)
    {
      if (_ret[N][1] = 'R')
      {
        DB.DBA.DAV_DELETE_INT (_ret[N][0], 1, null, null, 0, 0);
        commit work;
      }
      else
      {
        DELETE_FOLDER (_ret[N][0]);
      }
    }
  }
  DB.DBA.DAV_DELETE_INT (_res, 1, null, null, 0, 0);
}
;

DELETE_FOLDER ('/DAV/xmlsql/');
DB.DBA.DAV_COL_CREATE ('/DAV/xmlsql/', '110100100N', auth_uid=>'dav', auth_pwd=>DB.DBA.DAV_DET_PASSWORD (http_dav_uid ()));

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
}
;

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

--
--  $Id: nwxp.sql,v 1.3.10.1 2013/01/02 16:14:49 source Exp $
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
drop table XML_TEXT_XML_TEXT_WORDS;
drop table XML_TEXT;

create table XML_TEXT (XT_ID integer, XT_FILE varchar, XT_TEXT long varchar identified by XT_FILE, primary key (XT_ID));
create index XT_FILE on XML_TEXT (XT_FILE);
create text index on XML_TEXT (XT_TEXT) with key XT_ID;

vt_batch_update ('XML_TEXT', 'ON', NULL);

sequence_set ('XML_TEXT', 1, 0);


DB.DBA.vt_index_DB_DBA_XML_TEXT (0);

create procedure xml_view_string (in _view varchar)
{
  declare _body any;
  declare _pf varchar;
  _body := string_output ();
  http ('<document>', _body);
  _pf := concat ('DB.DBA.http_view_', _view);
  call (_pf) (_body);
  http ('</document>', _body);

  return (string_output_string (_body));
}


create procedure xml_view_doc (in _view varchar, in _f varchar)
{
  declare _body any;
  declare _pf varchar;
  _body := string_output ();
--  The bug is left here intentionally, the commented variant is more correct :)
--  http ('<?xml version="1.0" encoding="LATIN-1" ?><document>', _body);
  http ('<document>', _body);
  _pf := concat ('DB.DBA.http_view_', _view);
  call (_pf) (_body);
  http ('</document>', _body);

  if (exists (select 1 from XML_TEXT where XT_FILE = _f))
    update XML_TEXT set XT_TEXT = _body where XT_FILE = _f;
  else
    insert into XML_TEXT (XT_ID, XT_FILE, XT_TEXT)
      values (sequence_next ('XML_TEXT'), _f, _body);
}

-- The following opt is disabled due to removal from demo DB
-- public '/cat_persist' owner 'dav' persistent interval 5;
create xml view "product" as
{
  "Demo"."demo"."Products" p as "product"
      ("ProductID", "ProductName" as "product_name","UnitPrice" as "price", "SupplierID","CategoryID")
--      on (p."ProductID">7)
    {
      "Demo"."demo"."Suppliers" s as "supplier"  ("CompanyName")
	on (s."SupplierID" = p."SupplierID")
       ,
      "Demo"."demo"."Categories" c as "category"  ("Description")
-- if use the next line instead the previous we get segmentation fault on the test
--      "Demo"."demo"."Categories" c as "category"  ("Description" as "description")
	on (c."CategoryID" = p."CategoryID")
--     , p as "price" ("UnitPrice") are not compiled

    }
};

xml_view_doc ('product', 'product1');

select xml_view_string ('product');

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

DB.DBA.exec_no_error('drop index XT_FILE');
DB.DBA.exec_no_error('drop table XML_TEXT_XML_TEXT_WORDS');
DB.DBA.exec_no_error('drop table XML_TEXT');

create table XML_TEXT (XT_ID integer, XT_FILE varchar, XT_TEXT long varchar identified by XT_FILE, primary key (XT_ID));
create index XT_FILE on XML_TEXT (XT_FILE);
create text index on XML_TEXT (XT_TEXT) with key XT_ID;

DB.DBA.vt_batch_update ('XML_TEXT', 'ON', NULL);

sequence_set ('XML_TEXT', 1, 0);


DB.DBA.vt_index_DB_DBA_XML_TEXT (0);

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
;
-- The following opt is disabled due to removal from demo DB
-- public '/cat_persist' owner 'dav' persistent interval 5;
create xml view "cat" as
{
  "Demo"."demo"."Categories" c as "category" ("CategoryID", "Description" as "description")
    {
      "Demo"."demo"."Products" p as "product"  ("ProductName")
        on (p."CategoryID" = c."CategoryID")
    }
};
xml_view_doc ('cat', 'cat1');
xml_view_doc ('cat', 'cat2');


create xml view "ord" as
{
  "Demo"."demo"."Customers" c as "customer" ("CompanyName" as "company_name",
  "Phone" as "phone",
  "Fax" as "fax", "CustomerID" as "customer_id")
  {
  "Demo"."demo"."Orders" o as "order" ("OrderID" as "order_id", "ShippedDate" as "shipped_date")
    on (o."CustomerID" = c."CustomerID")
    {
      "Demo"."demo"."Order_Details" od as "order_line"
        ("ProductID" as "product_id", "Quantity" as "quantity")
        on (od."OrderID" = o."OrderID")
        {
          "Demo"."demo"."Products" p as "product"
            ("ProductName" as "product_name",
             "UnitPrice" as "unit_price")
            on (p."ProductID" = od."ProductID")
        }
    }
}
}
;


xml_view_doc ('ord', 'ord1');

DB.DBA.exec_no_error('drop view KEY_COLS');
create view KEY_COLS as select KP_KEY_ID, KP_NTH, C.* from SYS_KEY_PARTS, SYS_COLS C where COL_ID = KP_COL;

create xml view "schema" as
{
  DB.DBA.SYS_KEYS k as "table" ("KEY_TABLE" as "name", KEY_ID as "key_id", KEY_TABLE as "table")
        on (k.KEY_IS_MAIN = 1 and k.KEY_MIGRATE_TO is null)
        { DB.DBA.KEY_COLS  c as "column" (\COLUMN as name)
                on (k.KEY_ID = c.KP_KEY_ID)
                primary key (COL_ID),
        DB.DBA.SYS_KEYS i as "index" (KEY_NAME as "name", KEY_ID as "key_id", KEY_N_SIGNIFICANT as "n_parts")
            on (i.KEY_TABLE = k.KEY_TABLE and i.KEY_IS_MAIN = 0 and i.KEY_MIGRATE_TO is null)
          {
            DB.DBA.KEY_COLS ic as "column" (\COLUMN as "name")
              on (ic.KP_NTH < i.KEY_N_SIGNIFICANT and ic.KP_KEY_ID = i.KEY_ID)
              primary key (COL_ID)
              }
        }
};

DB.DBA.exec_no_error('drop table xte');
create table xte (id integer primary key, dt long varchar);
sequence_set ('xte', 1, 0);
insert into xte values (sequence_next ('xte'), '<div/>');
insert into xte values (sequence_next ('xte'), '<mod/>');
insert into xte values (sequence_next ('xte'), '<not/>');
insert into xte values (sequence_next ('xte'), '<or/>');
insert into xte values (sequence_next ('xte'), '<and/>');
insert into xte values (sequence_next ('xte'), '<ancestor/>');
insert into xte values (sequence_next ('xte'), '<ancestor-or-self/>');
insert into xte values (sequence_next ('xte'), '<attribute/>');
insert into xte values (sequence_next ('xte'), '<child/>');
insert into xte values (sequence_next ('xte'), '<descendant/>');
insert into xte values (sequence_next ('xte'), '<descendant-or-self/>');
insert into xte values (sequence_next ('xte'), '<following/>');
insert into xte values (sequence_next ('xte'), '<following-sibling/>');
insert into xte values (sequence_next ('xte'), '<node/>');
insert into xte values (sequence_next ('xte'), '<text/>');
insert into xte values (sequence_next ('xte'), '<processing-instruction/>');
insert into xte values (sequence_next ('xte'), '<comment/>');
insert into xte values (sequence_next ('xte'), '<namespace/>');
insert into xte values (sequence_next ('xte'), '<parent/>');
insert into xte values (sequence_next ('xte'), '<preceding/>');
insert into xte values (sequence_next ('xte'), '<preceding-sibling/>');
insert into xte values (sequence_next ('xte'), '<self/>');
insert into xte values (sequence_next ('xte'), '<near/>');
insert into xte values (sequence_next ('xte'), '<like/>');
insert into xte values (sequence_next ('xte'), '<DiV/>');
insert into xte values (sequence_next ('xte'), '<Ancestor/>');
insert into xte values (sequence_next ('xte'), '<a><not>and</not></a>');

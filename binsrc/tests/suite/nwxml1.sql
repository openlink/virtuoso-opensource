--  
--  $Id: nwxml1.sql,v 1.3.10.1 2013/01/02 16:14:45 source Exp $
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
-- This is temporary set of tests while XPER is incomplete.

drop table XML_TEXT_XML_TEXT_WORDS;
drop table XML_TEXT;

create table XML_TEXT (XT_ID integer, XT_FILE varchar, XT_TEXT long varchar identified by XT_FILE, primary key (XT_ID));
create index XT_FILE on XML_TEXT (XT_FILE);
create text index on XML_TEXT (XT_TEXT) with key XT_ID;

vt_batch_update ('XML_TEXT', 'ON', NULL);

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
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": Creating a persistent view cat : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";



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
};


xml_view_doc ('ord', 'ord1');





select count (n) from XML_TEXT where xpath_contains (XT_TEXT, '/*/*', n);

echo both $if $equ $last[1] 107 "PASSED" "*** FAILED";
echo both ": " $last[1] " top level entities\n";



select count (n) from XML_TEXT where xpath_contains (XT_TEXT, '/document/category/@description', n);
echo both $if $equ $last[1] 16 "PASSED" "*** FAILED";
echo both ": " $last[1] " top level category entities\n";


select n from XML_TEXT where xpath_contains (XT_TEXT, '/document/category/product/@ProductName', n);
echo both $if $equ $rowcnt 154 "PASSED" "*** FAILED";
echo both ": " $rowcnt  " products under categories \n";

select count(n) from XML_TEXT where xpath_contains (XT_TEXT, '//product', n);
echo both $if $equ $last[1] 2309  "PASSED" "*** FAILED";
echo both ": " $last[1] " products under //  \n";


select n from XML_TEXT where xpath_contains (XT_TEXT, '/document/category [@description like ''%Bread%''] /product/@ProductName', n) and XT_FILE = 'cat1';
echo both $if $equ $rowcnt 7  "PASSED" "*** FAILED";
echo both ": " $rowcnt " products under bread category in cat1  \n";


select n from XML_TEXT where xpath_contains (XT_TEXT, '//product[../@description like ''Sea%'']', n);
echo both $if $equ $rowcnt 24 "PASSED" "*** FAILED";
echo both ": " $rowcnt  " products under seafood parent  \n";




select n from XML_TEXT where xpath_contains (XT_TEXT, '/*/category', n) and XT_FILE = 'cat1';


select count (n) from XML_TEXT where xpath_contains (XT_TEXT, '//product', n) and XT_FILE = 'ord1';
echo both $if $equ $last[1] 2155  "PASSED" "*** FAILED";
echo both ": " $last[1] " in //* in view ord \n";




drop view KEY_COLS;
create view KEY_COLS as select KP_KEY_ID, KP_NTH, C.* from SYS_KEY_PARTS, SYS_COLS C where COL_ID = KP_COL;



create xml view "schema" as
{
  DB.DBA.SYS_KEYS k as "table" ("KEY_TABLE" as "name", KEY_ID as "key_id", KEY_TABLE as "table")
	on (k.KEY_IS_MAIN = 1 and k.KEY_MIGRATE_TO is null)
	{ DB.DBA.KEY_COLS  c as "column" (COLUMN as name)
		on (k.KEY_ID = c.KP_KEY_ID)
		primary key (COL_ID),
	DB.DBA.SYS_KEYS i as "index" (KEY_NAME as "name", KEY_ID as "key_id", KEY_N_SIGNIFICANT as "n_parts")
	    on (i.KEY_TABLE = k.KEY_TABLE and i.KEY_IS_MAIN = 0 and i.KEY_MIGRATE_TO is null)
	  {
	    DB.DBA.KEY_COLS ic as "column" (COLUMN as "name")
	      on (ic.KP_NTH < i.KEY_N_SIGNIFICANT and ic.KP_KEY_ID = i.KEY_ID)
	      primary key (COL_ID)
	      }
	}
};









select n from XML_TEXT where xpath_contains (XT_TEXT, '//product[ProductName = ''Inlagd Sill'']/ancestor::*', n);

select n from XML_TEXT where xpath_contains (XT_TEXT, '//product[@ProductName = ''Inlagd Sill'']/ancestor::*', n);
select n from XML_TEXT where xpath_contains (XT_TEXT, '//product[@ProductName = ''Inlagd Sill'']/ancestor::document', n);
select n from XML_TEXT where xpath_contains (XT_TEXT, '//product[@ProductName = ''Inlagd Sill'']/ancestor-or-self::*', n);


select n from XML_TEXT where xpath_contains (XT_TEXT, '//product[@ProductName = ''Inlagd Sill'']/following-sibling::*', n);

select n from XML_TEXT where xpath_contains (XT_TEXT, '//product[@ProductName = ''Inlagd Sill'']/preceding-sibling::*', n) and XT_FILE = 'cat1';
echo both $if $equ $rowcnt 4 "PASSED" "*** FAILED";
echo both ": " $rowcnt " siblings before Sill   \n";


select n from XML_TEXT where xpath_contains (XT_TEXT, '//product[@ProductName = ''Inlagd Sill'']/following-sibling::*', n) and XT_FILE = 'cat1';
echo both $if $equ $rowcnt 7 "PASSED" "*** FAILED";
echo both ": " $rowcnt " siblings after Sill   \n";




select n from XML_TEXT where xpath_contains (XT_TEXT, '/document/category[@description like ''**fish'']/descendant-or-self::*', n) and XT_FILE = 'cat1';
echo both $if $equ $rowcnt 13 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in seafood and descendants \n";


-- test of XPATH reserved words
drop table xte;
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


select id,p from xte where xpath_contains (dt,'/div', p);
echo both $if $equ $last[1] 1  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/mod', p);
echo both $if $equ $last[1] 2  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/not',p);
echo both $if $equ $last[1] 3  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/or',p);
echo both $if $equ $last[1] 4  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/and',p);
echo both $if $equ $last[1] 5  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/ancestor',p);
echo both $if $equ $last[1] 6  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/ancestor-or-self',p);
echo both $if $equ $last[1] 7  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/attribute',p);
echo both $if $equ $last[1] 8  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/child',p);
echo both $if $equ $last[1] 9  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/descendant',p);
echo both $if $equ $last[1] 10 "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/descendant-or-self',p);
echo both $if $equ $last[1] 11  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/following',p);
echo both $if $equ $last[1] 12  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/following-sibling',p);
echo both $if $equ $last[1] 13  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/node',p);
echo both $if $equ $last[1] 14  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/text',p);
echo both $if $equ $last[1] 15  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/processing-instruction',p);
echo both $if $equ $last[1] 16  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/comment',p);
echo both $if $equ $last[1] 17  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/namespace',p);
echo both $if $equ $last[1] 18  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/parent',p);
echo both $if $equ $last[1] 19  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/preceding',p);
echo both $if $equ $last[1] 20  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/preceding-sibling',p);
echo both $if $equ $last[1] 21  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/self',p);
echo both $if $equ $last[1] 22  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
--select id,p from xte where xpath_contains (dt,'/near',p);
--echo both $if $equ $last[1] 23  "PASSED" "*** FAILED";
--echo both ": " $last[2] " keyword as path expression \n";
--select id,p from xte where xpath_contains (dt,'/like',p);
--echo both $if $equ $last[1] 24  "PASSED" "*** FAILED";
--echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/DiV',p);
echo both $if $equ $last[1] 25  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/Ancestor',p);
echo both $if $equ $last[1] 26  "PASSED" "*** FAILED";
echo both ": " $last[2] " keyword as path expression \n";
select id,p from xte where xpath_contains (dt,'/Div',p);
echo both $if $equ $rowcnt 0  "PASSED" "*** FAILED";
echo both ": " $rowcnt " row(s) on /Div expression \n";

insert into xte values (sequence_next ('xte'), '<a><not>and</not></a>');

select id from xte where xpath_contains(dt,'//not[not . = ''and'']');
echo both $if $equ $last[1] 3  "PASSED" "*** FAILED";
echo both ": " $last[1] " id on row contains //not[not . = 'and'] \n";

select * from xte where xpath_contains(dt,'//*[not substring(not,1,2) = ''not'']');
echo both $if $equ $rowcnt 27  "PASSED" "*** FAILED";
echo both ": " $rowcnt " row(s) contains //*[not substring(not,1,2) = 'not'] \n";

select * from xte where xpath_contains(dt,'//*[not div = div]');
echo both $if $equ $rowcnt 27  "PASSED" "*** FAILED";
echo both ": " $rowcnt " row(s) contains //*[not div = div] \n";


select * from xte where xpath_contains(dt,'//*[not not = not]');
echo both $if $equ $rowcnt 27  "PASSED" "*** FAILED";
echo both ": " $rowcnt " row(s) contains //*[not not = not] \n";




--
--  $Id: nwxmlb.sql,v 1.2.6.1 2013/01/02 16:14:47 source Exp $
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
echo BOTH "\nSTARTED: nwml bigint suite (nwxmlb.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

drop table XML_TEXT_XML_TEXT_WORDS;
drop table XML_TEXT;

create table XML_TEXT (XT_ID bigint, XT_FILE varchar, XT_TEXT long varchar identified by XT_FILE, primary key (XT_ID));
create index XT_FILE on XML_TEXT (XT_FILE);
create text index on XML_TEXT (XT_TEXT) with key XT_ID;

vt_batch_update ('XML_TEXT', 'ON', NULL);

sequence_set ('XML_TEXT', 10000000000, 0);


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

explain ('select count (n) from XML_TEXT where xpath_contains (XT_TEXT, ''/*/*'', n)',  2);
echo both $if $equ $state OK  "PASSED" "*** FAILED";
echo both ": BUG 5796: scrollable cursor over xpath_contains STATE=" $state " MESSAGE=" $message "\n";



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

-- compares BLOB colum
--XPATH [__view 'cat'] //product[../@description like 'Sea%' ];
--echo both $if $equ $rowcnt 12 "PASSED" "*** FAILED";
--echo both ": " $rowcnt  " products in cat view  under seafood parent  \n";


select count (*) from (XPATH '[__key __view "cat"] //*') n;
echo both $if $equ $last[1] 85  "PASSED" "*** FAILED";
echo both ": " $last[1] " in //* in view cat \n";

select count (*) from (XPATH '[ __view "ord"] //*') n;
echo both $if $equ $last[1] 5231  "PASSED" "*** FAILED";
echo both ": " $last[1] " in //* in view ord \n";





XPATH [__view 'cat'] //product[@ProductName like '%' ];

XPATH [__view 'cat'] /category/@description;
echo both $if $equ $rowcnt 8 "PASSED" "*** FAILED";
echo both ": " $rowcnt  " categories in cat view\n";



--select count (*) from (XPATH '[__* __doc "ord1"] //product') n;
select count (n) from XML_TEXT where xpath_contains (XT_TEXT, '//product', n) and XT_FILE = 'ord1';
echo both $if $equ $last[1] 2155  "PASSED" "*** FAILED";
echo both ": " $last[1] " in //* in view ord \n";


select count (*) from (XPATH '[__* __view "ord"] //product') n;
echo both $if $equ $last[1] 2155  "PASSED" "*** FAILED";
echo both ": " $last[1] " in //* in view ord \n";


XPATH [__key __view 'cat'] //product[@ProductName like '%nla%' ]/@ProductName;
echo both $if $equ $last[1] "Inlagd Sill"  "PASSED" "*** FAILED";
echo both ": " $last[1] " is the name of %nla% in cat view\n";


XPATH [__view 'cat'] /category[@description like 'Sea%'];

XPATH [__view 'cat'] /category[@description like 'Sea%']/@description;

XPATH [__view 'cat'] /category [product/@ProductName like '%nla%' ];

XPATH [__view 'cat'] //product [@* like '%nla%'];

XPATH [__view 'cat'] /category/../..;

XPATH [__view 'cat'] /category/../..;

XPATH [__view 'cat'] //*/../@description;

XPATH [__view 'cat'] /category[@* = 1];

-- compares BLOB column
--XPATH [__view 'cat'] //*[@* = 1];
--echo both $if $equ $rowcnt 1 "PASSED" "*** FAILED";
--echo both ": " $rowcnt " entities in cat with * = 1 \n";




XPATH [__view 'cat'] length (category/@description);

--XPATH [__view 'cat'] /category[@description like 'Sea%']/product | /category[@description like '%Bread%']/product;
--echo both $if $equ $rowcnt 19 "PASSED" "*** FAILED";
--echo both ": " $rowcnt " rows in seafood union breads \n";


XPATH [__view 'cat'] /category [.//product [@ProductName like 'L%']];
echo both $if $equ $rowcnt 3 "PASSED" "*** FAILED";
echo both ": " $rowcnt " categories with a product like L% \n";




drop view KEY_COLS;
create view KEY_COLS as select KP_KEY_ID, KP_NTH, C.* from SYS_KEY_PARTS, SYS_COLS C where COL_ID = KP_COL;



create xml view "schema" as
{
  DB.DBA.SYS_KEYS k as "table" ("KEY_TABLE" as "name", KEY_ID as "key_id", KEY_TABLE as "table")
	on (k.KEY_IS_MAIN = 1 and k.KEY_MIGRATE_TO is null)
	{ DB.DBA.KEY_COLS  c as "column" (\\COLUMN as name)
		on (k.KEY_ID = c.KP_KEY_ID)
		primary key (COL_ID),
	DB.DBA.SYS_KEYS i as "index" (KEY_NAME as "name", KEY_ID as "key_id", KEY_N_SIGNIFICANT as "n_parts")
	    on (i.KEY_TABLE = k.KEY_TABLE and i.KEY_IS_MAIN = 0 and i.KEY_MIGRATE_TO is null)
	  {
	    DB.DBA.KEY_COLS ic as "column" (\\COLUMN as "name")
	      on (ic.KP_NTH < i.KEY_N_SIGNIFICANT and ic.KP_KEY_ID = i.KEY_ID)
	      primary key (COL_ID)
	      }
	}
};






XPATH  [__view 'schema'] /table[@name = 'DB.DBA.VXML_DOCUMENT'];

XPATH [__view 'schema'] //column;



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

select cat from XML_TEXT where xpath_contains (XT_TEXT, 'document/category', cat);
select count (*) from XML_TEXT where xpath_contains (XT_TEXT, 'document/category', cat);

select count (*) from (select cat from XML_TEXT where xpath_contains (XT_TEXT, 'document/category', cat)) f;
select count (*) from (select 1 as d from XML_TEXT where xpath_contains (XT_TEXT, 'document/category')) f;


select p from XML_TEXT where xpath_contains (XT_TEXT, '/document/category[@description like ''Sea%'']/product | /document/category[@description like ''Chee%'']/product', p);


select count (*) from XML_TEXT where xpath_contains (XT_TEXT, '//*', p);
echo both $if $equ $last[1] 5404 "PASSED" "*** FAILED";
echo both ": " $last[1] " in xpath_contains '//*'\n";

select count (*) from XML_TEXT where xpath_contains (XT_TEXT, '//*/*', p);
echo both $if $equ $last[1] 5401 "PASSED" "*** FAILED";
echo both ": " $last[1] " in xpath_contains '//*/*'\n";

select count (*) from XML_TEXT where xpath_contains (XT_TEXT, '//*[@* = ''Inlagd Sill'']', p);
echo both $if $equ $last[1] 33 "PASSED" "*** FAILED";
echo both ": " $last[1] " in xpath_contains //*[@* = 'Inlagd Sill']\n";

select xpath_eval ('@product_name', p) from XML_TEXT where xpath_contains (XT_TEXT, '//*[@* = ''Inlagd Sill'']', p);
echo both $if $equ $rowcnt 33 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_eval (@product_name) of xpath_contains //*[@* = 'Inlagd Sill']\n";

select p from XML_TEXT where xpath_contains (XT_TEXT, '//*[@* = ''Inlagd Sill'' and @unit_price > 100]', p);

select p from XML_TEXT where xpath_contains (XT_TEXT, '//product[@* = ''Inlagd Sill'' or  @unit_price > 100]', p);

select p from XML_TEXT where xpath_contains (XT_TEXT, '/document/*[position() = 6]/*[position() = 2]', p);



create procedure xml_text_load (in f varchar)
{
  if (exists (select 1 from XML_TEXT where XT_FILE = f))
    update XML_TEXT set XT_TEXT = file_to_string (f) where XT_FILE = f;
  else
    insert into XML_TEXT (XT_ID, XT_FILE, XT_TEXT)
      values (sequence_next ('XML_TEXT'), f, file_to_string (f));
}

create procedure xml_text_load_r (in f varchar)
{
  declare str any;
  declare ni int;
  str := file_to_string (f);
  if (exists (select 1 from XML_TEXT where XT_FILE = f))
    update XML_TEXT set XT_TEXT = file_to_string (f) where XT_FILE = f;
  else
    {
      ni := coalesce ((select xt_id + 1 from xml_text order by xt_id desc), 1);
      insert into XML_TEXT (XT_ID, XT_FILE, XT_TEXT)
	values (ni, f, str);
    }
}


create procedure xml_text_insert (in f varchar)
{
	    insert into XML_TEXT (XT_ID, XT_FILE, XT_TEXT)
      values (sequence_next ('XML_TEXT'), NULL,  f);
}

create procedure xml_html_load (in f varchar)
{
  declare text, tree, s any;
  whenever sqlstate '40001' goto deadl;
 again:
  text := file_to_string (f);
  tree := xml_tree (text, 1, '', 'LATIN-1');
  if (not (isarray (tree)))
      signal ('XML00', 'Malformed html file');
  s := string_output ();
  http_value (xml_tree_doc (tree), null, s);
  if (exists (select 1 from XML_TEXT where XT_FILE = f))
    update XML_TEXT set XT_TEXT = s where XT_FILE = f;
  else
    insert into XML_TEXT (XT_ID, XT_FILE, XT_TEXT)
      values (sequence_next ('XML_TEXT'), f, s);
  return;
 deadl:
  rollback work;
  goto again;
}



create procedure pxml_html_load (in f varchar)
{
  declare text, tree, s, xper any;
  whenever sqlstate '40001' goto deadl;
 again:
  text := file_to_string (f);
  tree := xml_tree (text, 1, '', 'LATIN-1');
  if (not (isarray (tree)))
      signal ('XML00', 'Malformed html file');
  s := string_output ();
  http_value (xml_tree_doc (tree), null, s);
  xper := xml_persistent (string_output_string (s));
  if (exists (select 1 from XML_TEXT where XT_FILE = f))
    update XML_TEXT set XT_TEXT = xper where XT_FILE = f;
  else
    insert into XML_TEXT (XT_ID, XT_FILE, XT_TEXT)
      values (sequence_next ('XML_TEXT'), f, xper);
  return;
 deadl:
  rollback work;
  goto again;
}

xml_text_load ('docsrc/dbconcepts.xml');
xml_text_load ('docsrc/intl.xml');
xml_text_load ('docsrc/odbcimplementation.xml');
xml_text_load ('docsrc/ptune.xml');
xml_text_load ('docsrc/repl.xml');
xml_text_load ('docsrc/server.xml');
xml_text_load ('docsrc/sqlfunctions.xml');
xml_text_load ('docsrc/sqlprocedures.xml');
xml_text_load ('docsrc/sqlreference.xml');
xml_text_load ('docsrc/vdbconcepts.xml');
xml_text_load ('docsrc/virtdocs.xml');
xml_text_load ('ce.xml');

DB.DBA.vt_inc_index_DB_DBA_XML_TEXT ();


select t from XML_TEXT where xpath_contains (XT_TEXT, '//title', t);
echo both $if $equ $rowcnt 792 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title\n";

select t from XML_TEXT where xpath_contains (XT_TEXT, '//title [. like ''%ISOLATION%'' ]', t);
echo both $if $equ $rowcnt 4 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title [. like '%ISOLATION%' ]\n";
echo both $if $equ $last[1]  "<title>SQL_TXN_ISOLATION</title>" "PASSED" "*** FAILED";
echo both ": " $last[1] " last row in xpath_contains //title [. like '%ISOLATION%' ]\n";

select t from XML_TEXT where xpath_contains (XT_TEXT, '//title [.=''ISOLATION'' ]', t);
echo both $if $equ $rowcnt 2 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title [.='ISOLATION' ]\n";

select t from XML_TEXT where xpath_contains (XT_TEXT, '//title [. like ''%ISOLATION%'' ]/ancestor::*/title', t);
echo both $if $equ $rowcnt 16 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title [. like '%ISOLATION%' ]/ancestor::*/title\n";

select t from XML_TEXT where xpath_contains (XT_TEXT, '//title [.=''ISOLATION'' ]/ancestor::*/title', t);
echo both $if $equ $rowcnt 7 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //title [.='ISOLATION' ]/ancestor::*/title\n";
-- echo both $if $equ $last[1] "<title>SQL Reference</title>" "PASSED" "*** FAILED";
-- echo both ": " $last[1] " last row in xpath_contains //title [. like '%ISOLATION%' ]/ancestor::*/title\n";

select t from XML_TEXT where xpath_contains (XT_TEXT, '//chapter/title', t);
echo both $if $equ $rowcnt 20 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //chapter/title\n";
--echo both $if $equ $last[1] "<title>Virtual Database Concepts</title>" "PASSED" "*** FAILED";
--echo both ": " $last[1] " last row in xpath_contains //chapter/title\n";

select t from XML_TEXT where xpath_contains (XT_TEXT, '//chapter/title[position () = 1]', t);
echo both $if $equ $rowcnt 20 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xpath_contains //chapter/title[position () = 1]\n";
-- echo both $if $equ $last[1] "<title>International character support and compatibility</title>" "PASSED" "*** FAILED";
-- echo both ": " $last[1] " last row in xpath_contains //chapter/title[position () = 1]\n";

select count (*) from XML_TEXT where xpath_contains (XT_TEXT, '//chapter//para[position () > 10]', t);
echo both $if $equ $last[1] 6 "PASSED" "*** FAILED";
echo both ": " $last[1] " rows in xpath_contains //chapter//para[position () > 10]\n";

select count (*) from XML_TEXT where xpath_contains (XT_TEXT, '//chapter/descendant::para[position () > 10]', t);
echo both $if $equ $last[1] 1630 "PASSED" "*** FAILED";
echo both ": " $last[1] " rows in xpath_contains //chapter/descendant::para[position () > 10]\n";

select c from XML_TEXT where xpath_contains (XT_TEXT, '//customer[.//product/@unit_price > 20]/@name', c);


select p from XML_TEXT where xpath_contains (XT_TEXT, 'document/*[3]/product[2]', p);
select p from XML_TEXT where xpath_contains (XT_TEXT, '(document/category/product)[22]', p);
select p from XML_TEXT where xpath_contains (XT_TEXT, '(document/category/product)[position () > 22 and position() < 33]', p);

select count (*) from XML_TEXT where XT_ID = 10000000000 and xpath_contains (XT_TEXT, '1 > 2 != 2 > 1');
echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
echo both ": " $last[1] " rows in xpath_contains 1 > 2 != 2 > 1\n";


select p from XML_TEXT where xpath_contains (XT_TEXT, '[xmlns:r="http://www.w3.org/TR/RDF/"]//*[@r:id = "Top"]', p);



select SCORE, XT_FILE from XML_TEXT where contains (XT_TEXT, '"case sensitive"');
echo both $if $equ $rowcnt 3 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in contains case sensitive\n";
echo both $if $equ $last[1] 120 "PASSED" "*** FAILED";
echo both ": " $last[1] " last score in contains case sensitive\n";

explain ('select SCORE, XT_FILE from XML_TEXT where contains (XT_TEXT, ''"case sensitive"'')', 2);
echo both $if $equ $state OK "PASSED" "*** FAILED";
echo both ": BUG 5796: scrollable cursor over contains STATE=" $state " MESSAGE=" $message "\n";

select SCORE, XT_FILE from XML_TEXT where contains (XT_TEXT, '"case sensitive"') order by XT_ID desc;

select SCORE, XT_FILE, dbg_obj_print (ranges) from XML_TEXT where contains (XT_TEXT, '"case sensitive"', 0, ranges) order by XT_ID desc;

select SCORE, XT_FILE, dbg_obj_print (ranges) from XML_TEXT where contains (XT_TEXT, '"cas* sensitiv*"', 0, ranges);

select SCORE, XT_FILE from XML_TEXT where contains (XT_TEXT, 'crash near recovery');
select XT_FILE from XML_TEXT where contains (XT_TEXT, 'virtuoso');

select XT_FILE from XML_TEXT where contains (XT_TEXT, 'virtuoso and not database');


select XT_FILE, t from XML_TEXT where contains (XT_TEXT, 'virtuoso and not database') and xpath_contains (XT_TEXT, '//title', t);

select t from XML_TEXT where xpath_contains (XT_TEXT, '/document/category[last ()]', t);

select XT_ID, c  from XML_TEXT where xpath_contains (XT_TEXT, 'count (/document/category/product)', c);

select n from XML_TEXT where xpath_contains (XT_TEXT, 'string (/document/category)', n);

select n from XML_TEXT where xpath_contains (XT_TEXT, 'local-name (/*/*)', n);

select n from XML_TEXT where xpath_contains (XT_TEXT, 'namespace-uri (/*/*)', n);

select n from XML_TEXT where xpath_contains (XT_TEXT, 'concat ("111", //product/@ProductName, "222")', n);

select n from XML_TEXT where xpath_contains (XT_TEXT, 'substring-before ("11122", "2")', n);

select n from XML_TEXT where xpath_contains (XT_TEXT, 'sum (/document/category )', n);

select xpath_eval ('sum (/a/b)', xml_tree_doc (xml_tree ('<a><b>11</b><b>33</b></a>')), 1);


select n from XML_TEXT where xpath_contains (XT_TEXT, '//product [contains (@ProductName, "Sill")]', n);
select n from XML_TEXT where xpath_contains (XT_TEXT, '//product [contains (@ProductName, "Inla")]', n);


select n from XML_TEXT where xpath_contains (XT_TEXT, '//product [string-length (@ProductName) > 25]', n);

select xpath_eval ('normalize-space ("  1  2  \n\r3\t4  \r\n")', xml_tree_doc (xml_tree ('<a><b>11</b><b>33</b></a>')), 1);

select xpath_eval ('translate ("1234567 1234567", "123", "abc")', xml_tree_doc (xml_tree ('<a><b>11</b><b>33</b></a>')), 1);

select xpath_eval ('round-number (11.2)', xml_tree_doc (xml_tree ('<a><b>11</b><b>33</b></a>')), 1);

select length (xpath_eval ('//@href', xml_tree_doc (xml_tree ('<html><a href="1">11</a><ul><a href = "2"></a></ul><ul><a name="test"></a></ul></html>')), 0));
echo both $IF $EQU $LAST[1] 2 "PASSED" "*** FAILED";
echo both ": " $LAST[1] " rows in xpath_eval //@href\n";

select length (xpath_eval ('//a/@name', xml_tree_doc (xml_tree ('<html><a href="1">11</a><ul><a href = "2"></a></ul><ul><a name="test"></a></ul></html>')), 0));
echo both $IF $EQU $LAST[1] 1 "PASSED" "*** FAILED";
echo both ": " $LAST[1] " rows in xpath_eval //a/@name\n";


--- free text options


select xt_id from xml_text where contains (xt_text, 'database', 0,r,'start_id', 11, 'desc');
select xt_id from xml_text where contains (xt_text, 'database', 0,r,'start_id', 11);

select xt_id from xml_text where contains (xt_text, 'database or (isolation  or backup)');

select xt_id from xml_text where contains (xt_text, 'database and  (isolation  or backup)');

select xt_id from xml_text where contains (xt_text, 'database and  (isolation  or backup)', 0, r, 'desc');

ECHO BOTH "COMPLETED: nwml bigint suite (nwxmlb.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";

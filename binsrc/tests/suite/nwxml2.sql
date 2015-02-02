--
--  $Id: nwxml2.sql,v 1.39.10.1 2013/01/02 16:14:46 source Exp $
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

select count (*) from XML_TEXT where XT_ID = 1 and xpath_contains (XT_TEXT, '1 > 2 != 2 > 1');
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

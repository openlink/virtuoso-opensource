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


echo "Start nwxmltype3\n";

drop table XML_TEXT2_XML_TEXT_WORDS;
drop table XML_TEXT2;


create table XML_TEXT2 (XT_ID integer, XT_FILE varchar, XT_TEXT DB.DBA.XMLType identified by XT_FILE, primary key (XT_ID));
alter index xml_text2 on xml_text2 partition (xt_id int);
create index XT_FILE2 on XML_TEXT2 (XT_FILE) partition (xt_file varchar);
create text xml index on XML_TEXT2 (XT_TEXT) with key XT_ID;
sequence_set ('XML_TEXT2', 1, 0);

vt_batch_update ('XML_TEXT2', 'ON', NULL);

vt_index_DB_DBA_XML_TEXT2 (0);

create procedure xml_per_text(in f varchar, in text varchar)
{
  declare  tree, s, xper any;
  whenever sqlstate '40001' goto deadl;
 again:
   xper := xtree_doc (blob_to_string (text));
  if (exists (select 1 from XML_TEXT2 where XT_FILE = f))
    update XML_TEXT2 set XT_TEXT = xper where XT_FILE = f;
  else
    insert into XML_TEXT2 (XT_ID, XT_FILE, XT_TEXT) 
      values (sequence_next ('XML_TEXT2'), f, xper);
  return;
 deadl:
  rollback work;
  goto again;
}


create procedure xml_per_load (in f varchar)
{
  declare text, tree, s, xper any;
  whenever sqlstate '40001' goto deadl;
 again:
  text := file_to_string (f);
  xper := xtree_doc (text);
  if (exists (select 1 from XML_TEXT2 where XT_FILE = f))
    update XML_TEXT2 set XT_TEXT = xper where XT_FILE = f;
  else
    insert into XML_TEXT2 (XT_ID, XT_FILE, XT_TEXT) 
      values (sequence_next ('XML_TEXT2'), f, xper);
  return;
 deadl:
  rollback work;
  goto again;
}

xml_per_text ('cat1', (select XT_TEXT from XML_TEXT where XT_FILE = 'cat1'));
xml_per_text ('cat2', (select XT_TEXT from XML_TEXT where XT_FILE = 'cat2'));
xml_per_text ('ord1', (select XT_TEXT from XML_TEXT where XT_FILE = 'ord1'));

xml_per_load ('docsrc/dbconcepts.xml');
xml_per_load ('docsrc/intl.xml');
xml_per_load ('docsrc/odbcimplementation.xml');
xml_per_load ('docsrc/ptune.xml');
xml_per_load ('docsrc/repl.xml');
xml_per_load ('docsrc/server.xml');
xml_per_load ('docsrc/sqlfunctions.xml');
xml_per_load ('docsrc/sqlprocedures.xml');
xml_per_load ('docsrc/sqlreference.xml');
xml_per_load ('docsrc/vdbconcepts.xml');
xml_per_load ('docsrc/virtdocs.xml');
xml_per_load ('ce.xml');

vt_inc_index_DB_DBA_XML_TEXT2 ();


select xml_persistent (XT_TEXT) from XML_TEXT2 where XT_FILE = 'ce.xml';

select t from XML_TEXT2 where xpath_contains (XT_TEXT, '//title', t);
ECHO BOTH $IF $EQU $ROWCNT 792 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows in xpath_contains //title\n";

select t from XML_TEXT2 where xpath_contains (XT_TEXT, '//title [. like ''%ISOLATION%'' ]', t);
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows in xpath_contains //title [. like '%ISOLATION%' ]\n";
ECHO BOTH $IF $EQU $LAST[1]  "<title>SQL_TXN_ISOLATION</title>" "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " last row in xpath_contains //title [. like '%ISOLATION%' ]\n";

select t from XML_TEXT2 where xpath_contains (XT_TEXT, '//title [.=''ISOLATION'' ]', t);
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows in xpath_contains //title [.='ISOLATION' ]\n";

select t from XML_TEXT2 where xpath_contains (XT_TEXT, '//title [. like ''%ISOLATION%'' ]/ancestor::*/title', t);
ECHO BOTH $IF $EQU $ROWCNT 16 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows in xpath_contains //title [. like '%ISOLATION%' ]/ancestor::*/title\n";

select t from XML_TEXT2 where xpath_contains (XT_TEXT, '//title [.=''ISOLATION'' ]/ancestor::*/title', t);
ECHO BOTH $IF $EQU $ROWCNT 7 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows in xpath_contains //title [.='ISOLATION' ]/ancestor::*/title\n";
-- ECHO BOTH $IF $EQU $LAST[1] "<title>SQL Reference</title>" "PASSED" "***FAILED";
-- ECHO BOTH ": " $LAST[1] " last row in xpath_contains //title [. like '%ISOLATION%' ]/ancestor::*/title\n";

select t from XML_TEXT2 where xpath_contains (XT_TEXT, '//chapter/title', t);
ECHO BOTH $IF $EQU $ROWCNT 20 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows in xpath_contains //chapter/title\n";
--ECHO BOTH $IF $EQU $LAST[1] "<title>Virtual Database Concepts</title>" "PASSED" "***FAILED";
--ECHO BOTH ": " $LAST[1] " last row in xpath_contains //chapter/title\n";

select t from XML_TEXT2 where xpath_contains (XT_TEXT, '//chapter/title[position () = 1]', t);
ECHO BOTH $IF $EQU $ROWCNT 20 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows in xpath_contains //chapter/title[position () = 1]\n";
-- ECHO BOTH $IF $EQU $LAST[1] "<title>International character support and compatibility</title>" "PASSED" "***FAILED";
-- ECHO BOTH ": " $LAST[1] " last row in xpath_contains //chapter/title[position () = 1]\n";

select count (*) from XML_TEXT2 where xpath_contains (XT_TEXT, '//chapter//para[position () > 10]', t);
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in xpath_contains //chapter//para[position () > 10]\n";

select count (*) from XML_TEXT2 where xpath_contains (XT_TEXT, '//chapter/descendant::para[position () > 10]', t);
ECHO BOTH $IF $EQU $LAST[1] 1630 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in xpath_contains //chapter/descendant::para[position () > 10]\n";

select c from XML_TEXT2 where xpath_contains (XT_TEXT, '//customer[.//product/@unit_price > 20]/@name', c);


select p from XML_TEXT2 where xpath_contains (XT_TEXT, 'document/*[3]/product[2]', p);
select p from XML_TEXT2 where xpath_contains (XT_TEXT, '(document/category/product)[22]', p);
select p from XML_TEXT2 where xpath_contains (XT_TEXT, '(document/category/product)[position () > 22 and position() < 33]', p);

select count (*) from XML_TEXT2 where XT_ID = 1 and xpath_contains (XT_TEXT, '1 > 2 != 2 > 1');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in xpath_contains 1 > 2 != 2 > 1\n";


select p from XML_TEXT2 where xpath_contains (XT_TEXT, '[xmlns:r="http://www.w3.org/TR/RDF/"]//*[@r:id = "Top"]', p);



select SCORE, XT_FILE from XML_TEXT2 where contains (XT_TEXT, '"case sensitive"');
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows in contains case sensitive\n";
ECHO BOTH $IF $EQU $LAST[1] 176 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " last score in contains case sensitive\n";

select SCORE, XT_FILE from XML_TEXT2 where contains (XT_TEXT, '"case sensitive"') order by XT_ID desc;

select SCORE, XT_FILE, dbg_obj_print (ranges) from XML_TEXT2 where contains (XT_TEXT, '"case sensitive"', 0, ranges) order by XT_ID desc;

select SCORE, XT_FILE, dbg_obj_print (ranges) from XML_TEXT2 where contains (XT_TEXT, '"cas* sensitiv*"', 0, ranges);

select SCORE, XT_FILE from XML_TEXT2 where contains (XT_TEXT, 'crash near recovery');
select XT_FILE from XML_TEXT2 where contains (XT_TEXT, 'virtuoso');

select XT_FILE from XML_TEXT2 where contains (XT_TEXT, 'virtuoso and not database');


select XT_FILE, t from XML_TEXT2 where contains (XT_TEXT, 'virtuoso and not database') and xpath_contains (XT_TEXT, '//title', t);

select t from XML_TEXT2 where xpath_contains (XT_TEXT, '/document/category[last ()]', t);

select XT_ID, c  from XML_TEXT2 where xpath_contains (XT_TEXT, 'count (/document/category/product)', c);

select n from XML_TEXT2 where xpath_contains (XT_TEXT, 'string (/document/category)', n);

select n from XML_TEXT2 where xpath_contains (XT_TEXT, 'local-name (/*/*)', n);

select n from XML_TEXT2 where xpath_contains (XT_TEXT, 'namespace-uri (/*/*)', n);

select n from XML_TEXT2 where xpath_contains (XT_TEXT, 'concat ("111", //product/@ProductName, "222")', n);

select n from XML_TEXT2 where xpath_contains (XT_TEXT, 'substring-before ("11122", "2")', n);

select n from XML_TEXT2 where xpath_contains (XT_TEXT, 'sum (/document/category )', n);

select xpath_eval ('sum (/a/b)', xml_tree_doc (xml_tree ('<a><b>11</b><b>33</b></a>')), 1);


select n from XML_TEXT2 where xpath_contains (XT_TEXT, '//product [contains (@ProductName, "Sill")]', n);
select n from XML_TEXT2 where xpath_contains (XT_TEXT, '//product [contains (@ProductName, "Inla")]', n);


select n from XML_TEXT2 where xpath_contains (XT_TEXT, '//product [string-length (@ProductName) > 25]', n);

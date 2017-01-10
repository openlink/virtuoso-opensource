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
select t from XML_TEXT2 where xcontains (XT_TEXT, '//title', 0, t);
ECHO BOTH $IF $EQU $ROWCNT 397 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows in xcontains //title\n";

explain ('select t from XML_TEXT2 where xcontains (XT_TEXT, ''//title'', 0, t)', 2);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ":  BUG 5796: scrollable cursor over xcontains STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select t from XML_TEXT2 where xcontains (XT_TEXT, '//title [. like ''%ISOLATION%'' ]', 0, t);
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows in xcontains //title [. like '%ISOLATION%' ]\n";
ECHO BOTH $IF $EQU $LAST[1] "<title>ISOLATION</title>" "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " last row in xcontains //title [. like '%ISOLATION%' ]\n";

select t from XML_TEXT2 where xcontains (XT_TEXT, '//title [. like ''%ISOLATION%'' ]/ancestor::*/title', 0, t);
ECHO BOTH $IF $EQU $ROWCNT 7 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows in xcontains //title [. like '%ISOLATION%' ]/ancestor::*/title\n";
ECHO BOTH $IF $EQU $LAST[1] "<title>SQL Reference</title>" "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " last row in xcontains //title [. like '%ISOLATION%' ]/ancestor::*/title\n";

select t from XML_TEXT2 where xcontains (XT_TEXT, '//chapter/title', 0, t);
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows in xcontains //chapter/title\n";
ECHO BOTH $IF $EQU $LAST[1] "<title>Virtual Database Concepts</title>" "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " last row in xcontains //chapter/title\n";

select t from XML_TEXT2 where xcontains (XT_TEXT, '//chapter/title[position () = 1]', 0, t);
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows in xcontains //chapter/title[position () = 1]\n";
ECHO BOTH $IF $EQU $LAST[1] "<title>Virtual Database Concepts</title>" "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " last row in xcontains //chapter/title[position () = 1]\n";

select count (*) from XML_TEXT2 where xcontains (XT_TEXT, '//chapter//para[position () > 10]', 0, t);
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in xcontains //chapter//para[position () > 10]\n";

select c from XML_TEXT2 where xcontains (XT_TEXT, '//customer[.//product/@unit_price > 20]/@name', 0, c);


select p from XML_TEXT2 where xcontains (XT_TEXT, 'document/*[3]/product[2]', 0, p);
select p from XML_TEXT2 where xcontains (XT_TEXT, '(document/category/product)[22]', 0, p);
select p from XML_TEXT2 where xcontains (XT_TEXT, '(document/category/product)[position () > 22 and position() < 33]', 0, p);

select count (*) from XML_TEXT2 where XT_ID = 1 and xcontains (XT_TEXT, '1 > 2 != 2 > 1');
--ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
--ECHO BOTH ": " $LAST[1] " rows in xcontains 1 > 2 != 2 > 1\n";


select p from XML_TEXT2 where xcontains (XT_TEXT, '[xmlns:r="http://www.w3.org/TR/RDF/"]//*[@r:id = "Top"]', 0, p);

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

select XT_FILE, t from XML_TEXT2 where contains (XT_TEXT, 'virtuoso and not database') and xcontains (XT_TEXT, '//title', 0, t);

select t from XML_TEXT2 where xcontains (XT_TEXT, '/document/category[last ()]', 0, t);

select XT_ID, c  from XML_TEXT2 where xcontains (XT_TEXT, 'count (/document/category/product)', 0, c);

select n from XML_TEXT2 where xcontains (XT_TEXT, 'string (/document/category)', 0, n);

select n from xml_text2 where xcontains (xt_text, 'local-name (/*/*)', 0, n);

select n from xml_text2 where xcontains (xt_text, 'namespace_uri (/*/*)', 0, n);

select n from XML_TEXT2 where xcontains (XT_TEXT, 'concat ("111", //product/@ProductName, "222")', 0, n);

select n from xml_text2 where xcontains (xt_text, 'substring-before ("11122", "2")', 0, n);

select n from xml_text2 where xcontains (xt_text, 'sum (/document/category )', 0, n);

select xpath_eval ('sum (/a/b)', xml_tree_doc (xml_tree ('<a><b>11</b><b>33</b></a>')), 1);


select n from XML_TEXT2 where xcontains (XT_TEXT, '//product [contains (@ProductName, "Sill")]', 0, n);
select n from XML_TEXT2 where xcontains (XT_TEXT, '//product [contains (@ProductName, "Inla")]', 0, n);


select n from XML_TEXT2 where xcontains (XT_TEXT, '//product [string-length (@ProductName) > 25]', 0, n);

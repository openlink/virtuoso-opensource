--
--  $Id: nwxml4.sql,v 1.11.10.1 2013/01/02 16:14:47 source Exp $
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
select t from XML_TEXT2 where xcontains (XT_TEXT, '//title', 0, t);
echo both $if $equ $rowcnt 397 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xcontains //title\n";

explain ('select t from XML_TEXT2 where xcontains (XT_TEXT, ''//title'', 0, t)', 2);
echo both $if $equ $state OK "PASSED" "*** FAILED";
echo both ":  BUG 5796: scrollable cursor over xcontains STATE=" $state " MESSAGE=" $message "\n";

select t from XML_TEXT2 where xcontains (XT_TEXT, '//title [. like ''%ISOLATION%'' ]', 0, t);
echo both $if $equ $rowcnt 2 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xcontains //title [. like '%ISOLATION%' ]\n";
echo both $if $equ $last[1] "<title>ISOLATION</title>" "PASSED" "*** FAILED";
echo both ": " $last[1] " last row in xcontains //title [. like '%ISOLATION%' ]\n";

select t from XML_TEXT2 where xcontains (XT_TEXT, '//title [. like ''%ISOLATION%'' ]/ancestor::*/title', 0, t);
echo both $if $equ $rowcnt 7 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xcontains //title [. like '%ISOLATION%' ]/ancestor::*/title\n";
echo both $if $equ $last[1] "<title>SQL Reference</title>" "PASSED" "*** FAILED";
echo both ": " $last[1] " last row in xcontains //title [. like '%ISOLATION%' ]/ancestor::*/title\n";

select t from XML_TEXT2 where xcontains (XT_TEXT, '//chapter/title', 0, t);
echo both $if $equ $rowcnt 10 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xcontains //chapter/title\n";
echo both $if $equ $last[1] "<title>Virtual Database Concepts</title>" "PASSED" "*** FAILED";
echo both ": " $last[1] " last row in xcontains //chapter/title\n";

select t from XML_TEXT2 where xcontains (XT_TEXT, '//chapter/title[position () = 1]', 0, t);
echo both $if $equ $rowcnt 10 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in xcontains //chapter/title[position () = 1]\n";
echo both $if $equ $last[1] "<title>Virtual Database Concepts</title>" "PASSED" "*** FAILED";
echo both ": " $last[1] " last row in xcontains //chapter/title[position () = 1]\n";

select count (*) from XML_TEXT2 where xcontains (XT_TEXT, '//chapter//para[position () > 10]', 0, t);
echo both $if $equ $last[1] 3 "PASSED" "*** FAILED";
echo both ": " $last[1] " rows in xcontains //chapter//para[position () > 10]\n";

select c from XML_TEXT2 where xcontains (XT_TEXT, '//customer[.//product/@unit_price > 20]/@name', 0, c);


select p from XML_TEXT2 where xcontains (XT_TEXT, 'document/*[3]/product[2]', 0, p);
select p from XML_TEXT2 where xcontains (XT_TEXT, '(document/category/product)[22]', 0, p);
select p from XML_TEXT2 where xcontains (XT_TEXT, '(document/category/product)[position () > 22 and position() < 33]', 0, p);

select count (*) from XML_TEXT2 where XT_ID = 1 and xcontains (XT_TEXT, '1 > 2 != 2 > 1');
--echo both $if $equ $last[1] 1 "PASSED" "*** FAILED";
--echo both ": " $last[1] " rows in xcontains 1 > 2 != 2 > 1\n";


select p from XML_TEXT2 where xcontains (XT_TEXT, '[xmlns:r="http://www.w3.org/TR/RDF/"]//*[@r:id = "Top"]', 0, p);

select SCORE, XT_FILE from XML_TEXT2 where contains (XT_TEXT, '"case sensitive"');
echo both $if $equ $rowcnt 3 "PASSED" "*** FAILED";
echo both ": " $rowcnt " rows in contains case sensitive\n";
echo both $if $equ $last[1] 176 "PASSED" "*** FAILED";
echo both ": " $last[1] " last score in contains case sensitive\n";

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

--
--  ttext_outer.sql
--
--  A free-text condition on a table that is not the driving one is checked
--  by a text node right after that table.  When an outer join came next, the
--  outer join took that text node in with its own nodes, so a row whose text
--  did not match was kept, with NULLs for the optional part:
--  contains () plus OPTIONAL with FROM gave 5 rows where 2 match.
--  The same happened to a text node that stands for its whole table (only the
--  key is read): the outer join after it then saw one input row, and its rows
--  without a match were dropped, a left join returning what an inner join does.
--
--  The documents are d1 .. d5; d1 and d3 contain "second request".  Sums of
--  weights d1 = 1, d2 = 10, d3 = 100, d4 = 1000, d5 = 10000 name the rows found.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2026 OpenLink Software
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

ECHO BOTH "STARTED: free-text check before an outer join\n";

create table TTXT_KEY (ID integer primary key, CODE varchar);
create table TTXT_DOC (ID integer primary key, TXT varchar);
create table TTXT_FLAG (ID integer primary key, F integer);
create table TTXT_FLAG2 (ID integer primary key, F integer);
create text index on TTXT_DOC (TXT);

insert into TTXT_KEY values (1, 'd1');
insert into TTXT_KEY values (2, 'd2');
insert into TTXT_KEY values (3, 'd3');
insert into TTXT_KEY values (4, 'd4');
insert into TTXT_KEY values (5, 'd5');
insert into TTXT_DOC values (1, 'A filing for a healthcare deal; no second request was issued.');
insert into TTXT_DOC values (2, 'A risk assessment for a laboratory services deal.');
insert into TTXT_DOC values (3, 'The agency issued a Second Request and the filing was withdrawn.');
insert into TTXT_DOC values (4, 'An initial public offering with trust and warrant agreements.');
insert into TTXT_DOC values (5, 'A bridge loan with a preliminary closing checklist.');
insert into TTXT_FLAG values (1, 0);
insert into TTXT_FLAG values (3, 1);
insert into TTXT_FLAG values (4, 0);
insert into TTXT_FLAG2 values (3, 1);
insert into TTXT_FLAG2 values (4, 0);

create function ttxt_w (in code varchar) returns integer
{
  return case code when 'd1' then 1 when 'd2' then 10 when 'd3' then 100
    when 'd4' then 1000 when 'd5' then 10000 else 100000 end;
}
;

-- SQL: the documents are reached by key, so contains () is a check after them
select count (*), sum (ttxt_w (K.CODE))
  from TTXT_KEY K join TTXT_DOC D on (D.ID = K.ID) left outer join TTXT_FLAG F on (F.ID = K.ID)
 where contains (D.TXT, '"second request"') option (order, loop);
ECHO BOTH $IF $EQU $LAST[2] 101 "PASSED" "***FAILED";
ECHO BOTH ": SQL, contains () checked, then an outer join: d1 d3 (sum 101): " $LAST[2] "\n";

select sum (coalesce (F.F, 0) + 1)
  from TTXT_KEY K join TTXT_DOC D on (D.ID = K.ID) left outer join TTXT_FLAG F on (F.ID = K.ID)
 where contains (D.TXT, '"second request"') option (order, loop);
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": SQL, the outer join still fills its columns, flags 0 and 1 (sum of flag + 1 is 3): " $LAST[1] "\n";

select count (*), sum (ttxt_w (K.CODE))
  from TTXT_KEY K join TTXT_DOC D on (D.ID = K.ID)
 where contains (D.TXT, '"second request"') option (order, loop);
ECHO BOTH $IF $EQU $LAST[2] 101 "PASSED" "***FAILED";
ECHO BOTH ": guard, SQL, contains () checked, no outer join: d1 d3 (sum 101): " $LAST[2] "\n";

select count (*), sum (ttxt_w (K.CODE))
  from TTXT_KEY K join TTXT_DOC D on (D.ID = K.ID) left outer join TTXT_FLAG F on (F.ID = K.ID)
 where contains (D.TXT, '"second request"');
ECHO BOTH $IF $EQU $LAST[2] 101 "PASSED" "***FAILED";
ECHO BOTH ": guard, SQL, the plan the optimizer picks: d1 d3 (sum 101): " $LAST[2] "\n";

-- SQL: only the key of the documents is read, so the text node stands for the table
select count (*), count (F.F)
  from TTXT_DOC D left outer join TTXT_FLAG2 F on (F.ID = D.ID)
 where contains (D.TXT, '"second request"') option (loop);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": SQL, contains () alone gives the documents, then an outer join: 2 rows: " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": SQL, contains () alone gives the documents, then an outer join: 1 of them with a flag: " $LAST[2] "\n";

select sum (D.ID * 10 + coalesce (F.F, 0))
  from TTXT_DOC D left outer join TTXT_FLAG2 F on (F.ID = D.ID)
 where contains (D.TXT, '"second request"');
ECHO BOTH $IF $EQU $LAST[1] 41 "PASSED" "***FAILED";
ECHO BOTH ": SQL, the same, the optimizer's plan: d1 without a flag, d3 with flag 1 (sum 41): " $LAST[1] "\n";

-- SPARQL
sparql clear graph <urn:ttxt:oj>;
DB.DBA.RDF_OBJ_FT_RULE_ADD ('urn:ttxt:oj', null, 'ttxt_oj');
sparql insert data { graph <urn:ttxt:oj> {
  <urn:ttxt:m1> <urn:ttxt:ident> "d1" ; <urn:ttxt:summary> "A filing for a healthcare deal; no second request was issued." ; <urn:ttxt:flag> false .
  <urn:ttxt:m2> <urn:ttxt:ident> "d2" ; <urn:ttxt:summary> "A risk assessment for a laboratory services deal." .
  <urn:ttxt:m3> <urn:ttxt:ident> "d3" ; <urn:ttxt:summary> "The agency issued a Second Request and the filing was withdrawn." ; <urn:ttxt:flag> true .
  <urn:ttxt:m4> <urn:ttxt:ident> "d4" ; <urn:ttxt:summary> "An initial public offering with trust and warrant agreements." ; <urn:ttxt:flag> false .
  <urn:ttxt:m5> <urn:ttxt:ident> "d5" ; <urn:ttxt:summary> "A bridge loan with a preliminary closing checklist." . } };
DB.DBA.VT_INC_INDEX_DB_DBA_RDF_OBJ ();

sparql define sql:select-option "loop" select ?id ?f from <urn:ttxt:oj>
 where { ?m <urn:ttxt:ident> ?id ; <urn:ttxt:summary> ?t . ?t bif:contains '"second request"' .
         optional { ?m <urn:ttxt:flag> ?f } } order by ?id;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL with FROM, bif:contains and OPTIONAL, loop joins: 2 rows: " $ROWCNT "\n";
ECHO BOTH $IF $EQU $LAST[1] "d3" "PASSED" "***FAILED";
ECHO BOTH ": SPARQL with FROM, bif:contains and OPTIONAL, loop joins: last d3: " $LAST[1] "\n";

sparql select ?id ?f from <urn:ttxt:oj>
 where { ?m <urn:ttxt:summary> ?t ; <urn:ttxt:ident> ?id . ?t bif:contains '"second request"' .
         optional { ?m <urn:ttxt:flag> ?f } } order by ?id;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL with FROM, bif:contains and OPTIONAL: 2 rows: " $ROWCNT "\n";
ECHO BOTH $IF $EQU $LAST[1] "d3" "PASSED" "***FAILED";
ECHO BOTH ": SPARQL with FROM, bif:contains and OPTIONAL: last d3: " $LAST[1] "\n";

sparql select ?id from <urn:ttxt:oj>
 where { ?m <urn:ttxt:summary> ?t ; <urn:ttxt:ident> ?id . ?t bif:contains '"second request"' } order by ?id;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": guard, SPARQL with FROM, bif:contains, no OPTIONAL: 2 rows: " $ROWCNT "\n";

sparql clear graph <urn:ttxt:oj>;
DB.DBA.RDF_OBJ_FT_RULE_DEL ('urn:ttxt:oj', null, 'ttxt_oj');
drop function ttxt_w;
drop table TTXT_FLAG2;
drop table TTXT_FLAG;
drop table TTXT_DOC;
drop table TTXT_KEY;

ECHO BOTH "COMPLETED: free-text check before an outer join\n";

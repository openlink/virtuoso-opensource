--
--  tsparql_group_literal.sql
--
--  A literal read from RDF_QUAD.O and the same literal computed in the query
--  (str (), BIND, VALUES: DB.DBA.RDF_OBJ_OF_SQLVAL) are one RDF term and
--  carry one RDF_OBJ id; dv_compare () finds them equal by that id.  The
--  hash table compared their serializations, the id alone against a box
--  holding the id, so SPARQL GROUP BY and DISTINCT gave a group for each and a
--  hash join of the two found nothing.  COUNT (DISTINCT) was right.
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

ECHO BOTH "STARTED: SPARQL GROUP BY over stored and computed literals\n";

sparql clear graph <urn:tgl:g>;
DB.DBA.TTLP ('
@prefix ex: <urn:tgl:> .
ex:m1 ex:id "1001-00001" .
ex:m2 ex:id "1001-00002" .
ex:m3 ex:id "1002-00001" .
ex:m7 ex:id "1007-00001"^^ex:code .
ex:m8 ex:id "1008-00001"@en .
ex:m9 ex:id "1009-00001-a-very-long-matter-identifier" .
', '', 'urn:tgl:g');

--  6 stored literals and their str (): the 4 plain literals are their own
--  str (), the typed and the language-tagged one are not: 4 + 2 + 2 = 8.
sparql select count (*) where { { select ?x (count (*) as ?c) where { graph <urn:tgl:g> {
  { ?m <urn:tgl:id> ?x } union { ?m <urn:tgl:id> ?y . bind (str (?y) as ?x) } } } group by ?x } };
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": GROUP BY over literals and their str (): " $LAST[1] " groups\n";

sparql select count (*) where { { select ?x (count (*) as ?c) where { graph <urn:tgl:g> {
  { ?m <urn:tgl:id> ?x } union { ?m <urn:tgl:id> ?y . bind (str (?y) as ?x) } } } group by ?x having (count (*) = 2) } };
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": groups holding a literal and its str (): " $LAST[1] "\n";

sparql select count (*) where { { select distinct ?x where { graph <urn:tgl:g> {
  { ?m <urn:tgl:id> ?x } union { ?m <urn:tgl:id> ?y . bind (str (?y) as ?x) } } } } };
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": DISTINCT over the same: " $LAST[1] " rows\n";

sparql select count (distinct ?x) where { graph <urn:tgl:g> {
  { ?m <urn:tgl:id> ?x } union { ?m <urn:tgl:id> ?y . bind (str (?y) as ?x) } } };
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": guard, COUNT (DISTINCT) over the same: " $LAST[1] "\n";

--  A stored literal joined to the computed one.
sparql define sql:select-option "order,loop" select count (*) where { graph <urn:tgl:g> { ?m <urn:tgl:id> ?x .
  { select ?x where { graph <urn:tgl:g> { ?n <urn:tgl:id> ?y . bind (str (?y) as ?x) } } } } };
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": guard, loop join of stored and computed literals: " $LAST[1] " rows\n";

sparql define sql:select-option "order,hash" select count (*) where { graph <urn:tgl:g> { ?m <urn:tgl:id> ?x .
  { select ?x where { graph <urn:tgl:g> { ?n <urn:tgl:id> ?y . bind (str (?y) as ?x) } } } } };
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": hash join of stored and computed literals: " $LAST[1] " rows\n";

--  The same in SQL.
select count (*) from (select k from (select O as k from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tgl:g')
  union all select DB.DBA.RDF_OBJ_OF_SQLVAL (__rdf_strsqlval (O, 0)) as k from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tgl:g')) u group by k) g;
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": SQL GROUP BY over O and RDF_OBJ_OF_SQLVAL of its string: " $LAST[1] " groups\n";

select count (*) from (select k from (select O as k from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tgl:g')
  union all select O as k from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tgl:g')) u group by k) g;
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": guard, GROUP BY over O twice: " $LAST[1] " groups\n";

select count (*) from (select k from (select DB.DBA.RDF_OBJ_OF_SQLVAL (__rdf_strsqlval (O, 0)) as k from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tgl:g')
  union all select DB.DBA.RDF_OBJ_OF_SQLVAL (__rdf_strsqlval (O, 0)) as k from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tgl:g')) u group by k) g;
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": guard, GROUP BY over the computed literals twice: " $LAST[1] " groups\n";

--  Literals that differ only in language or datatype stay apart.
sparql select count (*) where { { select ?x where { { bind (strlang ("1008-00001", "en") as ?x) } union { bind (strlang ("1008-00001", "fr") as ?x) }
  union { bind (strdt ("1008-00001", <urn:tgl:code>) as ?x) } union { bind ("1008-00001" as ?x) } } group by ?x } };
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": guard, @en, @fr, typed and plain literals of one text: " $LAST[1] " groups\n";

sparql clear graph <urn:tgl:g>;

ECHO BOTH "COMPLETED: SPARQL GROUP BY over stored and computed literals\n";

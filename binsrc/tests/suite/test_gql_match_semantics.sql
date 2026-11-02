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
--
--
--  GQL for Virtuoso - MATCH pattern semantics
--
--  The answers a MATCH gives on a small graph, against counts worked out by
--  hand and checked with hand-written SPARQL:
--
--    U  an undirected edge  (a)-[:R]-(b)  or  (a)~[:R]~(b)  matches a stored
--       edge in both orientations;
--    N  a pattern predicate in WHERE,  (c)-[:R]->(a)  or
--       EXISTS { (c)-[:R]->(a) },  and its negation, filter the match;
--    A  an anonymous node is the endpoint of the edges next to it;
--    F  a FILTER statement filters the rows, as WHERE does;
--    O  an equality on a variable only an OPTIONAL MATCH binds is a filter,
--       not a value to start from;
--    T  a pattern with no undirected edge translates as it did before;
--    W  a query given as a wide string (NVARCHAR) runs as the narrow text does;
--    L  a lone node, (n) or (), is one row per node;
--    S  a IS SOURCE OF e and b IS DESTINATION OF e test the stored edge;
--    M  a MINUS pattern shares only the query's own variables with it;
--    P  under USE PROPERTY GRAPH, EXISTS, pattern predicates and MINUS use
--       the property graph's vocabulary;
--    D  DETACH DELETE removes a node, its edges and their property holders;
--    E  DELETE of an edge variable removes that edge and its holder only;
--    Y  an edge of no single type, -[r]->, -[r:%]->, -[r:!T]->, matches only
--       edges, not labels, properties or property holders;
--    EV RETURN r of a named edge returns every edge it matched, with or
--       without properties.
--
--  Run via isql: isql <host>:<port> dba dba test_gql_match_semantics.sql
--

ECHO "STARTED: GQL MATCH pattern semantics tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

-- Five people; KNOWS is stored once per pair, in one direction:
--   p1->p2, p2->p3, p3->p1 (a triangle), p3->p4, p4->p5.
-- Three messages: post m1 tagged t1; comments m2 (tags t1, t2) and m3
-- (tag t3) reply to m1.  Two cities in one country.
sparql clear graph <urn:gql:ms>;
sparql prefix o: <http://localhost:8890/gql/ontology/>
insert data { graph <urn:gql:ms> {
  <urn:ms:p1> a o:Person . <urn:ms:p2> a o:Person . <urn:ms:p3> a o:Person .
  <urn:ms:p4> a o:Person . <urn:ms:p5> a o:Person .
  <urn:ms:p1> o:KNOWS <urn:ms:p2> . <urn:ms:p2> o:KNOWS <urn:ms:p3> .
  <urn:ms:p3> o:KNOWS <urn:ms:p1> . <urn:ms:p3> o:KNOWS <urn:ms:p4> .
  <urn:ms:p4> o:KNOWS <urn:ms:p5> .
  <urn:ms:c1> a o:City . <urn:ms:c2> a o:City . <urn:ms:k1> a o:Country .
  <urn:ms:p1> o:IS_LOCATED_IN <urn:ms:c1> . <urn:ms:p2> o:IS_LOCATED_IN <urn:ms:c1> .
  <urn:ms:p3> o:IS_LOCATED_IN <urn:ms:c2> . <urn:ms:p4> o:IS_LOCATED_IN <urn:ms:c2> .
  <urn:ms:p5> o:IS_LOCATED_IN <urn:ms:c2> .
  <urn:ms:c1> o:IS_PART_OF <urn:ms:k1> . <urn:ms:c2> o:IS_PART_OF <urn:ms:k1> .
  <urn:ms:t1> a o:Tag . <urn:ms:t2> a o:Tag . <urn:ms:t3> a o:Tag .
  <urn:ms:m1> a o:Message , o:Post . <urn:ms:m2> a o:Message , o:Comment .
  <urn:ms:m3> a o:Message , o:Comment .
  <urn:ms:m1> o:HAS_TAG <urn:ms:t1> .
  <urn:ms:m2> o:REPLY_OF <urn:ms:m1> . <urn:ms:m2> o:HAS_TAG <urn:ms:t1> .
  <urn:ms:m2> o:HAS_TAG <urn:ms:t2> .
  <urn:ms:m3> o:REPLY_OF <urn:ms:m1> . <urn:ms:m3> o:HAS_TAG <urn:ms:t3> .
} };

-- The count a MATCH ... RETURN count(*) gives on the fixture, or -1 when the
-- statement raises.
create procedure DB.DBA.GQL_MS_T_COUNT (in _q varchar) returns integer
{
  declare _r any;
  declare exit handler for sqlstate '*' { return -1; };
  _r := DB.DBA.GQL_RUN (_q, 'urn:gql:ms');
  if (not isarray (_r) or length (_r) <> 1)
    return -2;
  return aref (aref (_r, 0), 0);
}
;

-- U1: each stored edge matches in both orientations: 5 edges, 10 matches.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[:KNOWS]-(b:Person) RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": U1 an undirected edge matches a stored edge in both orientations: " $LAST[1] "\n";

-- U2, U3: directed edges are unchanged.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[:KNOWS]->(b:Person) RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": U2 a right-directed edge matches each stored edge once: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)<-[:KNOWS]-(b:Person) RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": U3 a left-directed edge matches each stored edge once: " $LAST[1] "\n";

-- U4: the tilde spelling of an undirected edge.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)~[:KNOWS]~(b:Person) RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": U4 an undirected ~[ ]~ edge matches both orientations: " $LAST[1] "\n";

-- U5: from a bound endpoint, p4 is linked to p3 (p3->p4) and p5 (p4->p5).
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[:KNOWS]-(b:Person) WHERE a = iri(''urn:ms:p4'') RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": U5 an undirected edge from a bound node reaches its in- and out-neighbours: " $LAST[1] "\n";

-- U6: the triangle p1, p2, p3 in all six orders (three rotations, two
-- directions); a directed cycle would give three.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[:KNOWS]-(b:Person)-[:KNOWS]-(c:Person)-[:KNOWS]-(a) RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": U6 an undirected triangle is matched in all six orders: " $LAST[1] "\n";

-- U7: naming the edge does not change what matches.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[r:KNOWS]-(b:Person) RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": U7 a named undirected edge matches both orientations: " $LAST[1] "\n";

-- U8: two-hop undirected paths between distinct ends.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[:KNOWS]-(b:Person)-[:KNOWS]-(c:Person) WHERE a <> c RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": U8 two undirected hops between distinct ends: " $LAST[1] "\n";

-- N1: of the five directed two-hop paths, three close a directed cycle.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[:KNOWS]->(b:Person)-[:KNOWS]->(c:Person) WHERE NOT (c)-[:KNOWS]->(a) RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": N1 a negated pattern predicate removes the matches it describes: " $LAST[1] "\n";

-- N2: the positive predicate keeps exactly those three.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[:KNOWS]->(b:Person)-[:KNOWS]->(c:Person) WHERE (c)-[:KNOWS]->(a) RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": N2 a pattern predicate keeps only the matches it describes: " $LAST[1] "\n";

-- N3: a reply tagged with something its parent is not, and not with the
-- parent's tag: only m3 (t3) qualifies; m2 also carries t1.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (t1:Tag)<-[:HAS_TAG]-(m:Message)<-[:REPLY_OF]-(c:Comment)-[:HAS_TAG]->(t2:Tag) WHERE NOT (c)-[:HAS_TAG]->(t1) AND t1 <> t2 RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": N3 a negated pattern predicate combines with a comparison: " $LAST[1] "\n";

-- N4: two undirected hops whose ends are not linked either way.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[:KNOWS]-(b:Person)-[:KNOWS]-(c:Person) WHERE NOT (a)-[:KNOWS]-(c) AND a <> c RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": N4 a negated undirected pattern predicate excludes both orientations: " $LAST[1] "\n";

-- N5: the same test as N1, written EXISTS { graph pattern }.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[:KNOWS]->(b:Person)-[:KNOWS]->(c:Person) WHERE NOT EXISTS { (c)-[:KNOWS]->(a) } RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": N5 NOT EXISTS { graph pattern } filters like the bare predicate: " $LAST[1] "\n";

-- N6: and written EXISTS { MATCH graph pattern }, which already worked.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[:KNOWS]->(b:Person)-[:KNOWS]->(c:Person) WHERE NOT EXISTS { MATCH (c)-[:KNOWS]->(a) } RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": N6 NOT EXISTS { MATCH graph pattern } filters the same way: " $LAST[1] "\n";

-- N7: the positive undirected predicate keeps the paths whose ends are linked.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[:KNOWS]-(b:Person)-[:KNOWS]-(c:Person) WHERE (a)-[:KNOWS]-(c) AND a <> c RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": N7 an undirected pattern predicate keeps both orientations: " $LAST[1] "\n";

-- N8: a predicate that is one undirected edge tests each orientation with
-- its own EXISTS -- a semi-join on one triple -- rather than one EXISTS over a
-- UNION, which runs as a correlated sub-query for every row it filters.  The
-- outer edge is directed, so any UNION would be the predicate's.
select 99;
select case when strstr (s, 'UNION') is null and strstr (s, '||') is not null then 1 else 0 end
  from (select DB.DBA.GQL_TO_SPARQL ('MATCH (a:Person)-[:KNOWS]->(c:Person) WHERE NOT (a)-[:KNOWS]-(c) RETURN count(*) AS c') as s) x;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": N8 a one-edge undirected predicate is one EXISTS per orientation, not an EXISTS over a UNION\n";

-- A1: every person is in a city of the country: 5, not a cross product.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (:Country)<-[:IS_PART_OF]-(:City)<-[:IS_LOCATED_IN]-(:Person) RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": A1 a chain of anonymous nodes is joined through its edges: " $LAST[1] "\n";

-- A2: an anonymous node at the end of a pattern is the edge's endpoint.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (p:Person)-[:IS_LOCATED_IN]->(:City) RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": A2 a trailing anonymous node is the edge's endpoint: " $LAST[1] "\n";

-- A3: the named form of A1, which already worked.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (k:Country)<-[:IS_PART_OF]-(ci:City)<-[:IS_LOCATED_IN]-(p:Person) RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": A3 the same chain with named nodes: " $LAST[1] "\n";

-- A4: anonymous nodes at both ends around a named one.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (:Tag)<-[:HAS_TAG]-(m:Message)<-[:REPLY_OF]-(:Comment) RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": A4 anonymous nodes on both sides of a named node: " $LAST[1] "\n";

-- F1-F8: a FILTER statement filters the working rows like WHERE.  KNOWS edges
-- p1->p2, p2->p3, p3->p1, p3->p4, p4->p5.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[:KNOWS]->(b:Person) FILTER a = iri(''urn:ms:p3'') RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": F1 FILTER keeps only the matching rows: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[:KNOWS]->(b:Person) FILTER a = iri(''urn:ms:p3'') FILTER b = iri(''urn:ms:p4'') RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": F2 two FILTER statements both apply: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[:KNOWS]->(b:Person) WHERE a = iri(''urn:ms:p3'') FILTER b <> iri(''urn:ms:p1'') RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": F3 WHERE and FILTER both apply: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[:KNOWS]->(b:Person) FILTER NOT (b)-[:KNOWS]->(:Person) RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": F4 FILTER takes a pattern predicate: " $LAST[1] "\n";

-- F5: after an OPTIONAL MATCH, FILTER sees the unmatched rows (only p5 knows
-- nobody).
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person) OPTIONAL MATCH (a)-[:KNOWS]->(b:Person) FILTER b IS NULL RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": F5 FILTER after OPTIONAL MATCH filters the joined rows: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person) FILTER a = iri(''urn:ms:p3'') MATCH (a)-[:KNOWS]->(b:Person) RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": F6 FILTER between two MATCH statements: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[:KNOWS]->(b:Person) FILTER a <> iri(''urn:ms:p3'') RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": F7 FILTER with an inequality: " $LAST[1] "\n";

-- F8: FILTER and WHERE with the same condition translate to the same SPARQL.
select 99;
select case when cast (DB.DBA.GQL_TO_SPARQL ('MATCH (a:Person)-[:KNOWS]->(b:Person) FILTER a <> iri(''urn:ms:p3'') RETURN count(*) AS c') as varchar)
              = cast (DB.DBA.GQL_TO_SPARQL ('MATCH (a:Person)-[:KNOWS]->(b:Person) WHERE a <> iri(''urn:ms:p3'') RETURN count(*) AS c') as varchar)
            then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": F8 FILTER translates as WHERE does\n";

-- O1-O5: WHERE/FILTER b = <constant> on a variable only an OPTIONAL MATCH
-- binds keeps only the rows where the optional part matched it: p3 is the only
-- person who knows p4.  Binding b to the constant before the OPTIONAL would
-- keep every person, with b set to p4.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person) OPTIONAL MATCH (a)-[:KNOWS]->(b:Person) WHERE b = iri(''urn:ms:p4'') RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": O1 WHERE equality on an OPTIONAL-only variable filters: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person) OPTIONAL MATCH (a)-[:KNOWS]->(b:Person) FILTER b = iri(''urn:ms:p4'') RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": O2 FILTER equality on an OPTIONAL-only variable filters: " $LAST[1] "\n";

select 99;
select case when strstr (s, 'AS ?gql_n_b)') is null then 1 else 0 end
  from (select cast (DB.DBA.GQL_TO_SPARQL ('MATCH (a:Person) OPTIONAL MATCH (a)-[:KNOWS]->(b:Person) WHERE b = iri(''urn:ms:p4'') RETURN count(*) AS c') as varchar) as s) x;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": O3 an OPTIONAL-only variable is not bound before the OPTIONAL\n";

-- O4, O5: a variable a mandatory MATCH binds is still bound to the constant
-- up front (the start-value optimisation), and still counts right.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person) OPTIONAL MATCH (a)-[:KNOWS]->(b:Person) WHERE a = iri(''urn:ms:p3'') RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": O4 equality on a mandatory variable beside an OPTIONAL: " $LAST[1] "\n";

select 99;
select case when strstr (s, 'VALUES ?gql_n_b { <urn:ms:p4> }') is not null then 1 else 0 end
  from (select cast (DB.DBA.GQL_TO_SPARQL ('MATCH (a:Person)-[:KNOWS]->(b:Person) WHERE b = iri(''urn:ms:p4'') RETURN count(*) AS c') as varchar) as s) x;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": O5 a mandatory variable is still bound to its constant up front\n";

-- T1: a pattern of directed edges and named nodes still translates to plain
-- triple patterns -- no union, no path alternative.
select 99;
select case when strstr (s, 'UNION') is null and strstr (s, '|^') is null then 1 else 0 end
  from (select DB.DBA.GQL_TO_SPARQL ('MATCH (k:Country)<-[:IS_PART_OF]-(ci:City)<-[:IS_LOCATED_IN]-(p:Person)-[:KNOWS]->(q:Person) RETURN count(*) AS c') as s) x;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": T1 directed edges between named nodes translate to plain triple patterns\n";

-- AC1-AC9 (no AC4): clauses the parser accepted but that could not run:
-- CALL of a procedure and of a query (invalid SPARQL), FOR ... WITH
-- ORDINALITY / OFFSET (a position no clause could name, crossed with every
-- item), UNNEST of a property (invalid SPARQL) and FINISH (G2000).
create procedure DB.DBA.GQL_MS_T_AC_ROWS (in _q varchar) returns integer
{
  declare _r any;
  declare exit handler for sqlstate '*' { return -1; };
  _r := DB.DBA.GQL_RUN (_q, 'urn:gql:ms:ac');
  if (not isarray (_r))
    return -2;
  return length (_r);
}
;

create procedure DB.DBA.GQL_MS_T_AC_FIRST (in _q varchar) returns varchar
{
  declare _r any;
  declare exit handler for sqlstate '*' { return concat ('error ', __SQL_STATE); };
  _r := DB.DBA.GQL_RUN (_q, 'urn:gql:ms:ac');
  if (not isarray (_r) or length (_r) < 1)
    return 'no row';
  return cast (aref (aref (_r, 0), 0) as varchar);
}
;

select 99;
select DB.DBA.GQL_RUN ('INSERT (:Person {name: ''Ann''}), (:Person {name: ''Ben''})', 'urn:gql:ms:ac');
sparql insert data { graph <urn:gql:ms:ac> { <urn:gql:ms:ac:t> <http://localhost:8890/gql/ontology/name> "T" ; <http://localhost:8890/gql/ontology/tags> "x", "y" . } };

select 99;
select DB.DBA.GQL_MS_T_AC_FIRST ('CALL GQL_VERSION () YIELD v');
ECHO $IF $EQU $LAST[1] "GQL for Virtuoso 0.6.0" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": AC1 CALL of a procedure returns its value: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_AC_ROWS ('CALL DB.DBA.GQL_VERSION ()');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": AC2 and with its qualified name: " $LAST[1] " row\n";

select 99;
select DB.DBA.GQL_MS_T_AC_ROWS ('CALL { MATCH (p:Person) RETURN p.name AS n } YIELD n');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": AC3 CALL of a query returns its rows: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_AC_ROWS ('FOR x IN [''a'', ''b''] WITH ORDINALITY i RETURN x, i');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": AC5 FOR ... WITH ORDINALITY i: one row per item: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_AC_FIRST ('FOR x IN [''a'', ''b''] WITH ORDINALITY i FILTER x = ''b'' RETURN i');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": AC6 and b is item 2: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_AC_FIRST ('FOR x IN [''a'', ''b''] WITH OFFSET i FILTER x = ''b'' RETURN i');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": AC7 WITH OFFSET counts from 0: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_AC_ROWS ('MATCH (n {name: ''T''}) UNNEST (n.tags AS t) RETURN t');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": AC8 UNNEST of a property: one row per value: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_AC_ROWS ('MATCH (p:Person) FINISH');
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": AC9 FINISH runs and returns no rows: " $LAST[1] "\n";
sparql clear graph <urn:gql:ms:ac>;

-- W1-W5: a query given as a wide string (NVARCHAR, what a Unicode ODBC or
-- JDBC client binds) runs as the same text given narrow does; c1 is named
-- with a non-ASCII character, stored as UTF-8.
sparql prefix o: <http://localhost:8890/gql/ontology/>
insert data { graph <urn:gql:ms> { <urn:ms:c1> o:name "Zürich" } };

select 99;
select DB.DBA.GQL_MS_T_COUNT (N'MATCH (a:Person)-[:KNOWS]->(b:Person) RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": W1 a wide-string query runs: " $LAST[1] "\n";

select 99;
select case when DB.DBA.GQL_TO_SPARQL (N'MATCH (a:Person)-[:KNOWS]->(b:Person) RETURN count(*) AS c', 'urn:gql:ms')
  = DB.DBA.GQL_TO_SPARQL ('MATCH (a:Person)-[:KNOWS]->(b:Person) RETURN count(*) AS c', 'urn:gql:ms') then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": W2 a wide-string query translates as the narrow one does\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (c:City) WHERE c.name = ''Zürich'' RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": W3 a non-ASCII literal in a narrow (UTF-8) query matches: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT (charset_recode ('MATCH (c:City) WHERE c.name = ''Zürich'' RETURN count(*) AS c', 'UTF-8', '_WIDE_'));
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": W4 a non-ASCII literal in a wide query matches: " $LAST[1] "\n";

select 99;
select length (DB.DBA.GQL_PREPARED_PARAMS (N'MATCH (a:Person)-[:KNOWS]->(b:Person) RETURN a', 'urn:gql:ms', vector ()));
ECHO $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": W5 a wide-string query runs prepared: " $LAST[1] "\n";

-- L1-L10: a lone node with no label or property, (n) or (), is one row per
-- node of the graph.  A node is a subject or an IRI object -- not a class
-- (the object of rdf:type), not a literal, and not the resource that holds
-- an edge's properties.  On <urn:gql:ms:l>: three people (p3 has only its
-- type), names, p1 KNOWS p2, p1 HAS_TAG t1 (t1 is only an object) -- four
-- nodes in seven triples.
sparql clear graph <urn:gql:ms:l>;
sparql prefix o: <http://localhost:8890/gql/ontology/>
insert data { graph <urn:gql:ms:l> {
  <urn:ms:l:p1> a o:Person . <urn:ms:l:p2> a o:Person . <urn:ms:l:p3> a o:Person .
  <urn:ms:l:p1> o:name "A" . <urn:ms:l:p2> o:name "B" .
  <urn:ms:l:p1> o:KNOWS <urn:ms:l:p2> . <urn:ms:l:p1> o:HAS_TAG <urn:ms:l:t1> .
} };

create procedure DB.DBA.GQL_MS_T_COUNT_IN (in _q varchar, in _g varchar) returns integer
{
  declare _r any;
  declare exit handler for sqlstate '*' { return -1; };
  _r := DB.DBA.GQL_RUN (_q, _g);
  if (not isarray (_r) or length (_r) <> 1)
    return -2;
  return aref (aref (_r, 0), 0);
}
;

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (n) RETURN count(*) AS c', 'urn:gql:ms:l');
ECHO $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L1 MATCH (n) is one row per node: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH () RETURN count(*) AS c', 'urn:gql:ms:l');
ECHO $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L2 MATCH () is one row per node: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (n) WHERE n = iri(''urn:ms:l:t1'') RETURN count(*) AS c', 'urn:gql:ms:l');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L3 an IRI that is only an object is a node: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (n) WHERE n = iri(''urn:ms:l:p1'') RETURN count(*) AS c', 'urn:gql:ms:l');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L4 a node with four triples is one row: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (n) WHERE n = iri(''http://localhost:8890/gql/ontology/Person'') RETURN count(*) AS c', 'urn:gql:ms:l');
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L5 a class is not a node: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (n) WHERE n.name = ''A'' RETURN count(*) AS c', 'urn:gql:ms:l');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L6 a lone node filtered on a property: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (n), (m:Person) RETURN count(*) AS c', 'urn:gql:ms:l');
ECHO $IF $EQU $LAST[1] 12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L7 a lone node beside another pattern: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (n) MATCH (n)-[:KNOWS]->(m) RETURN count(*) AS c', 'urn:gql:ms:l');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L8 a lone node joined to a later MATCH: " $LAST[1] "\n";

-- L9: an equality on a lone node stays a FILTER: bound up front, the node
-- set is enumerated in full before the join (90 s on a 30M-triple graph,
-- against 2 ms as a FILTER).
select 99;
select case when strstr (s, 'AS ?gql_n_n)') is null then 1 else 0 end
  from (select cast (DB.DBA.GQL_TO_SPARQL ('MATCH (n) WHERE n = iri(''urn:ms:l:p1'') RETURN count(*) AS c', 'urn:gql:ms:l') as varchar) as s) x;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L9 an equality on a lone node is not bound up front\n";

-- L10: the resource GQL stores an edge's properties on (rdf:Statement,
-- rdf:subject/predicate/object) is not a node, nor is the edge type.
sparql clear graph <urn:gql:ms:lr>;
select DB.DBA.GQL_RUN ('INSERT (a:Person {name: ''A''})-[:KNOWS {since: 2020}]->(b:Person {name: ''B''})', 'urn:gql:ms:lr');
select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (n) RETURN count(*) AS c', 'urn:gql:ms:lr');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L10 an edge's property holder is not a node: " $LAST[1] "\n";

-- LW1-LW7: a label wildcard and a lone negation.  A Person knows B
-- (Person), B owns D (Dog), both edges with a property, and U has no
-- label.  (n:%) is the labelled nodes, once each -- it was one row per
-- triple; (n:!L) alone ranges over the nodes, as (n) does -- it bound
-- nothing and gave one NULL row.
select 99;
select DB.DBA.GQL_RUN ('INSERT (a:Person {name: ''A''})-[:knows {since: 1}]->(b:Person {name: ''B''}), (b)-[:owns {since: 2}]->(d:Dog {name: ''D''}), (u {name: ''U''})', 'urn:gql:ms:lw');

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (n:%) RETURN count(*) AS c', 'urn:gql:ms:lw');
ECHO $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": LW1 (n:%) is the 3 labelled nodes: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (n:!Person) RETURN count(n) AS c', 'urn:gql:ms:lw');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": LW2 (n:!Person) binds the 2 nodes that are not persons: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (n:!Person) RETURN count(*) AS c', 'urn:gql:ms:lw');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": LW3 in 2 rows, not one NULL row: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (n:!%) RETURN count(n) AS c', 'urn:gql:ms:lw');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": LW4 (n:!%) binds the node without a label: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (n:% {name: ''D''}) RETURN count(*) AS c', 'urn:gql:ms:lw');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": LW5 (n:% {name: 'D'}): " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (n:Person & !Dog) RETURN count(*) AS c', 'urn:gql:ms:lw');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": LW6 a negation next to a label (guard): " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (a)-[:%]->(b) RETURN count(*) AS c', 'urn:gql:ms:lw');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": LW7 an edge wildcard is the 2 edges (guard): " $LAST[1] "\n";
sparql clear graph <urn:gql:ms:lw>;

-- S1-S9: a IS SOURCE OF e / b IS DESTINATION OF e compare with the subject
-- and object of the stored edge e, whichever way round the pattern is
-- written; on the fixture's five KNOWS edges.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[e:KNOWS]->(b:Person) WHERE a IS SOURCE OF e RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": S1 IS SOURCE OF holds for the source of each edge: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[e:KNOWS]->(b:Person) WHERE b IS DESTINATION OF e RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": S2 IS DESTINATION OF holds for the destination of each edge: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[e:KNOWS]->(b:Person) WHERE b IS SOURCE OF e RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": S3 the destination is not the source: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[e:KNOWS]->(b:Person) WHERE b IS NOT SOURCE OF e RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": S4 IS NOT SOURCE OF: " $LAST[1] "\n";

-- S5: of the ten undirected matches, a is the stored subject in five.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[e:KNOWS]-(b:Person) WHERE a IS SOURCE OF e RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": S5 IS SOURCE OF on an undirected edge is the stored subject: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)<-[e:KNOWS]-(b:Person) WHERE a IS DESTINATION OF e RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": S6 IS DESTINATION OF on a left-pointing edge: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[e]->(b:Person) WHERE a IS SOURCE OF e RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": S7 IS SOURCE OF on an edge of any type: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[e:KNOWS]->(b:Person) MATCH (c:Person) WHERE c IS SOURCE OF e RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": S8 IS SOURCE OF on an edge an earlier MATCH bound: " $LAST[1] "\n";

-- S9: a quantified edge binds a list of edges, not one edge: an error, not
-- an empty result.
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[e:KNOWS*]->(b:Person) WHERE a IS SOURCE OF e RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": S9 IS SOURCE OF a path variable is an error: " $LAST[1] "\n";

-- M1, M2: a MINUS pattern shares only the query's own variables with it:
-- every person who knows someone is located in a city, so nothing is
-- left.  (Inner fresh variables numbered from 1 again met the outer ones:
-- the friend and the city were both ?dst_1, and MINUS removed nothing.)
select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[:KNOWS]->(:Person) MINUS (a)-[:IS_LOCATED_IN]->(:City) RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": M1 MINUS removes every row its pattern matches: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT ('MATCH (a:Person)-[:KNOWS]->(:Person) MINUS (a)-[:IS_LOCATED_IN]->(:City {name: ''nowhere''}) RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": M2 MINUS with a pattern that matches nothing removes nothing: " $LAST[1] "\n";

-- SO1-SO10: set operations.  Alice KNOWS Bob KNOWS Carol; Alice and Bob
-- are P, with surnames.  The branches are combined as sub-selects, column
-- by column, under the left branch's names.  UNION concatenated two
-- SELECTs and EXCEPT, INTERSECT and OTHERWISE had unbalanced braces, so
-- none of them compiled; the SQL GQL statement returned nothing for them.
select 99;
select DB.DBA.GQL_RUN ('INSERT (a:P {name: ''Alice'', surname: ''Smith''})-[:knows]->(b:P {name: ''Bob'', surname: ''Jones''})-[:knows]->(c {name: ''Carol''})', 'urn:gql:ms:so');

-- The number of rows a statement returns, through GQL_RUN, or -1 when it
-- raises.
create procedure DB.DBA.GQL_MS_T_SO_ROWS (in _q varchar) returns integer
{
  declare _r any;
  declare exit handler for sqlstate '*' { return -1; };
  _r := DB.DBA.GQL_RUN (_q, 'urn:gql:ms:so');
  if (not isarray (_r))
    return -2;
  return length (_r);
}
;

-- The rows of a statement run as an SQL GQL statement, or -1 when it
-- raises.
create procedure DB.DBA.GQL_MS_T_SO_STMT_ROWS (in _q varchar) returns integer
{
  declare _st, _msg, _meta, _rows any;
  _st := '00000';
  exec (concat ('GQL USE GRAPH <urn:gql:ms:so> ', _q), _st, _msg, vector (), 0, _meta, _rows);
  if (_st <> '00000')
    return -1;
  if (not isarray (_rows))
    return -2;
  return length (_rows);
}
;

-- The values of the first column, sorted and joined with '|'.
create procedure DB.DBA.GQL_MS_T_SO_VALUES (in _q varchar) returns varchar
{
  declare _r, _v any;
  declare _i integer;
  declare _s varchar;
  declare exit handler for sqlstate '*' { return concat ('error ', __SQL_STATE); };
  _r := DB.DBA.GQL_RUN (_q, 'urn:gql:ms:so');
  _v := make_array (length (_r), 'any');
  for (_i := 0; _i < length (_r); _i := _i + 1)
    _v[_i] := cast (aref (aref (_r, _i), 0) as varchar);
  _v := __vector_sort (_v);
  _s := '';
  for (_i := 0; _i < length (_v); _i := _i + 1)
    _s := concat (_s, case when _i > 0 then '|' else '' end, _v[_i]);
  return _s;
}
;

select 99;
select DB.DBA.GQL_MS_T_SO_VALUES ('MATCH (a)-[:knows]->(b) RETURN b.name AS name UNION MATCH (a)-[:knows]->(c) RETURN a.name AS name');
ECHO $IF $EQU $LAST[1] "Alice|Bob|Carol" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": SO1 UNION of the knows targets and sources: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_SO_ROWS ('MATCH (a)-[:knows]->(b) RETURN b.name AS name UNION ALL MATCH (a)-[:knows]->(c) RETURN a.name AS name');
ECHO $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": SO2 UNION ALL keeps the duplicate Bob: " $LAST[1] " rows\n";

select 99;
select DB.DBA.GQL_MS_T_SO_VALUES ('MATCH (n:P) RETURN n.name AS name EXCEPT MATCH (m)-[:knows]->(x:P) RETURN x.name AS name');
ECHO $IF $EQU $LAST[1] "Alice" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": SO3 EXCEPT: the P nodes nobody knows: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_SO_VALUES ('MATCH (n:P) RETURN n.name AS name INTERSECT MATCH (m)-[:knows]->(x:P) RETURN x.name AS name');
ECHO $IF $EQU $LAST[1] "Bob" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": SO4 INTERSECT: the P nodes somebody knows: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_SO_VALUES ('MATCH (a:P {name: ''Alice''}) RETURN a.surname AS s OTHERWISE MATCH (a:P {name: ''Bob''}) RETURN a.surname AS s');
ECHO $IF $EQU $LAST[1] "Smith" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": SO5 OTHERWISE with rows on the left gives the left: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_SO_VALUES ('MATCH (a:P {name: ''Zed''}) RETURN a.surname AS s OTHERWISE MATCH (a:P) RETURN a.surname AS s');
ECHO $IF $EQU $LAST[1] "Jones|Smith" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": SO6 OTHERWISE with no rows on the left gives the right: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_SO_VALUES ('MATCH (a:P) RETURN a.name AS x UNION MATCH (a:P) RETURN a.surname AS y');
ECHO $IF $EQU $LAST[1] "Alice|Bob|Jones|Smith" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": SO7 the branches' columns are matched by position, not name: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_SO_ROWS ('MATCH (a:P) RETURN a.name AS x, a.surname AS y UNION MATCH (a:P) RETURN a.name AS x');
ECHO $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": SO8 branches with different numbers of columns are refused: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_SO_STMT_ROWS ('MATCH (a)-[:knows]->(b) RETURN b.name AS name UNION MATCH (a)-[:knows]->(c) RETURN a.name AS name');
ECHO $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": SO9 the SQL GQL statement returns the UNION's rows: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_SO_ROWS ('MATCH (a:P) RETURN a.name AS name UNION MATCH (a:P) RETURN a.name AS name UNION ALL MATCH (a:P) RETURN a.name AS name');
ECHO $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": SO10 a chain of set operations: " $LAST[1] " rows\n";
sparql clear graph <urn:gql:ms:so>;

-- P1-P5: under USE PROPERTY GRAPH, labels and edge types inside EXISTS,
-- a pattern predicate, NOT EXISTS and MINUS are the property graph's, as
-- outside them.  MsBakery: three people, p1 KNOWS p2.
sparql clear graph <http://localhost:8890/pgraph/MsBakery>;
sparql insert data { graph <http://localhost:8890/pgraph/MsBakery> {
  <urn:ms:bk:p1> a <http://localhost:8890/pgraph/MsBakery/ontology#Person> .
  <urn:ms:bk:p2> a <http://localhost:8890/pgraph/MsBakery/ontology#Person> .
  <urn:ms:bk:p3> a <http://localhost:8890/pgraph/MsBakery/ontology#Person> .
  <urn:ms:bk:p1> <http://localhost:8890/pgraph/MsBakery/ontology#KNOWS> <urn:ms:bk:p2> .
} };

select 99;
select DB.DBA.GQL_MS_T_COUNT ('USE PROPERTY GRAPH MsBakery MATCH (a:Person) WHERE EXISTS { MATCH (a)-[:KNOWS]->(b:Person) } RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": P1 EXISTS under a property graph uses its vocabulary: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT ('USE PROPERTY GRAPH MsBakery MATCH (a:Person) WHERE (a)-[:KNOWS]->(:Person) RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": P2 a pattern predicate under a property graph: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT ('USE PROPERTY GRAPH MsBakery MATCH (a:Person) WHERE NOT EXISTS { MATCH (a)-[:KNOWS]->(b:Person) } RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": P3 NOT EXISTS under a property graph: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT ('USE PROPERTY GRAPH MsBakery MATCH (a:Person) MINUS (a)-[:KNOWS]->(:Person) RETURN count(*) AS c');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": P4 MINUS under a property graph: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT ('USE PROPERTY GRAPH MsBakery MATCH (a:Person) OPTIONAL MATCH (a)-[:KNOWS]->(b:Person) RETURN count(b) AS c');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": P5 OPTIONAL MATCH under a property graph: " $LAST[1] "\n";
sparql clear graph <http://localhost:8890/pgraph/MsBakery>;

-- D1-D4: DETACH DELETE n removes n's triples, the triples that point at
-- n, and the resource that holds the properties of each edge of n.  On
-- <urn:gql:ms:d>: A KNOWS B {since: 2020} -- 5 triples for A and B, 5 for
-- the edge's property holder -- and p9 HAS_TAG t9, where t9 is only an
-- object.
sparql clear graph <urn:gql:ms:d>;
select DB.DBA.GQL_RUN ('INSERT (a:Person {name: ''A''})-[:KNOWS {since: 2020}]->(b:Person {name: ''B''})', 'urn:gql:ms:d');
sparql prefix o: <http://localhost:8890/gql/ontology/>
insert data { graph <urn:gql:ms:d> { <urn:ms:d:p9> o:HAS_TAG <urn:ms:d:t9> } };

select 99;
select DB.DBA.GQL_RUN ('MATCH (n:Person {name: ''A''}) DETACH DELETE n', 'urn:gql:ms:d');
sparql select count(*) from <urn:gql:ms:d> where { ?s ?p ?o };
ECHO $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": D1 DETACH DELETE removes the node, its edges and their property holders -- triples left: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_RUN ('MATCH (p)-[:HAS_TAG]->(n) DETACH DELETE n', 'urn:gql:ms:d');
sparql select count(*) from <urn:gql:ms:d> where { ?s ?p ?o };
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": D2 DETACH DELETE of a node with only incoming triples -- triples left: " $LAST[1] "\n";

sparql clear graph <urn:gql:ms:d>;
select DB.DBA.GQL_RUN ('INSERT (a:Person {name: ''A''})-[:KNOWS {since: 2020}]->(b:Person {name: ''B''})', 'urn:gql:ms:d');
select 99;
select DB.DBA.GQL_RUN ('MATCH (n) DETACH DELETE n', 'urn:gql:ms:d');
sparql select count(*) from <urn:gql:ms:d> where { ?s ?p ?o };
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": D3 MATCH (n) DETACH DELETE n empties the graph -- triples left: " $LAST[1] "\n";

sparql clear graph <urn:gql:ms:d>;
select DB.DBA.GQL_RUN ('INSERT (a:Person {name: ''A''})-[:KNOWS {since: 2020}]->(b:Person {name: ''B''}), (c:Person {name: ''C''})', 'urn:gql:ms:d');
select 99;
select DB.DBA.GQL_RUN ('MATCH (a:Person)-[:KNOWS]->(b:Person) DETACH DELETE a, b', 'urn:gql:ms:d');
sparql select count(*) from <urn:gql:ms:d> where { ?s ?p ?o };
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": D4 DETACH DELETE of two nodes -- triples left: " $LAST[1] "\n";

-- PM1-PM7: a property map in a pattern, {k: v}, means n.k = v.  A value a
-- triple pattern cannot hold -- a function call, an operator expression --
-- was put in the triple as it was: a call did not compile (SP030), and an
-- operator expression, (60 + 8), was read as an RDF collection and matched
-- nothing.
sparql insert data { graph <urn:gql:ms:pm> {
  <urn:gql:ms:pm:fr> a <http://localhost:8890/gql/ontology/Country> ;
    <http://localhost:8890/gql/ontology/name> "France" ;
    <http://localhost:8890/gql/ontology/capital> <urn:gql:ms:pm:paris> ;
    <http://localhost:8890/gql/ontology/pop> 68 .
  <urn:gql:ms:pm:it> a <http://localhost:8890/gql/ontology/Country> ;
    <http://localhost:8890/gql/ontology/name> "Italy" ;
    <http://localhost:8890/gql/ontology/capital> <urn:gql:ms:pm:rome> ;
    <http://localhost:8890/gql/ontology/pop> 59 . } };
select DB.DBA.GQL_RUN ('MATCH (a:Country {name: ''France''}), (b:Country {name: ''Italy''}) INSERT (a)-[:borders {km: 515}]->(b)', 'urn:gql:ms:pm');

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (c:Country {name: ''France''}) RETURN count(*) AS n', 'urn:gql:ms:pm');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": PM1 a literal in a property map (guard): " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (c:Country {capital: iri(''urn:gql:ms:pm:paris'')}) RETURN count(*) AS n', 'urn:gql:ms:pm');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": PM2 iri (...) in a property map: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (c:Country {name: substring(''France!'', 1, 6)}) RETURN count(*) AS n', 'urn:gql:ms:pm');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": PM3 a function of a string in a property map: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (c:Country {pop: 60 + 8}) RETURN count(*) AS n', 'urn:gql:ms:pm');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": PM4 an operator expression in a property map: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (a)-[e:borders {km: 500 + 15}]->(b) RETURN count(*) AS n', 'urn:gql:ms:pm');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": PM5 an expression in an edge's property map: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (c:Country) OPTIONAL MATCH (c)-[:borders]->(d:Country {name: lower(''ITALY'')}) RETURN count(*) AS n', 'urn:gql:ms:pm');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": PM6 in an OPTIONAL MATCH, the test stays inside it: " $LAST[1] " rows\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (c:Country {pop: p}) RETURN sum(p) AS s', 'urn:gql:ms:pm');
ECHO $IF $EQU $LAST[1] 127 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": PM7 a variable in a property map binds it (guard): " $LAST[1] "\n";

sparql clear graph <urn:gql:ms:pm>;

-- E1-E5: DELETE e and DETACH DELETE e on an edge variable remove that edge
-- and its property holder, nothing else.  On <urn:gql:ms:d>: A KNOWS B
-- {since: 2020} and C LIKES D -- 15 triples: 8 for the four people, 1 + 5
-- for the KNOWS edge and its holder, 1 for LIKES.
sparql clear graph <urn:gql:ms:d>;
select DB.DBA.GQL_RUN ('INSERT (a:Person {name: ''A''})-[:KNOWS {since: 2020}]->(b:Person {name: ''B''}), (c:Person {name: ''C''})-[:LIKES]->(d:Person {name: ''D''})', 'urn:gql:ms:d');

select 99;
select DB.DBA.GQL_RUN ('MATCH (a:Person)-[e:KNOWS]->(b:Person) DETACH DELETE e', 'urn:gql:ms:d');
sparql select count(*) from <urn:gql:ms:d> where { ?s ?p ?o };
ECHO $IF $EQU $LAST[1] 9 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": E1 DETACH DELETE e removes the edge and its holder only -- triples left: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_RUN ('MATCH (c:Person)-[e:LIKES]->(d:Person) DELETE e', 'urn:gql:ms:d');
sparql select count(*) from <urn:gql:ms:d> where { ?s ?p ?o };
ECHO $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": E2 DELETE e removes the edge -- triples left: " $LAST[1] "\n";

-- E3, E4: an edge of any type, and an undirected edge (X KNOWS Y, matched
-- from Y); 4 triples for the two people, 1 for the edge.
sparql clear graph <urn:gql:ms:d>;
select DB.DBA.GQL_RUN ('INSERT (x:Person {name: ''X''})-[:KNOWS]->(y:Person {name: ''Y''})', 'urn:gql:ms:d');
select 99;
select DB.DBA.GQL_RUN ('MATCH (x:Person)-[e]->(y:Person) DELETE e', 'urn:gql:ms:d');
sparql select count(*) from <urn:gql:ms:d> where { ?s ?p ?o };
ECHO $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": E3 DELETE e on an edge of any type -- triples left: " $LAST[1] "\n";

sparql clear graph <urn:gql:ms:d>;
select DB.DBA.GQL_RUN ('INSERT (x:Person {name: ''X''})-[:KNOWS]->(y:Person {name: ''Y''})', 'urn:gql:ms:d');
select 99;
select DB.DBA.GQL_RUN ('MATCH (y:Person {name: ''Y''})-[e:KNOWS]-(x:Person) DELETE e', 'urn:gql:ms:d');
sparql select count(*) from <urn:gql:ms:d> where { ?s ?p ?o };
ECHO $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": E4 DELETE e on an undirected edge -- triples left: " $LAST[1] "\n";

-- E5: a quantified edge binds a list of edges: an error, and nothing
-- deleted (X KNOWS Y and an unrelated Z: 7 triples).
sparql clear graph <urn:gql:ms:d>;
select DB.DBA.GQL_RUN ('INSERT (x:Person {name: ''X''})-[:KNOWS]->(y:Person {name: ''Y''}), (z:Person {name: ''Z''})', 'urn:gql:ms:d');
select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (x:Person)-[e:KNOWS+]->(y:Person) DETACH DELETE e', 'urn:gql:ms:d');
sparql select count(*) from <urn:gql:ms:d> where { ?s ?p ?o };
ECHO $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": E5 DETACH DELETE of a path variable deletes nothing -- triples left: " $LAST[1] "\n";

-- DP1-DP5: a DEFINE in a statement that also has a PREFIX or a BASE.  The
-- SPARQL must have the DEFINE first; it had the PREFIX or BASE first,
-- whatever order the GQL used, and did not compile (SP030).
select 99;
select DB.DBA.GQL_RUN ('INSERT (:Person {name: ''A''}), (:Person {name: ''B''})', 'urn:gql:ms:def');

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('DEFINE input:same-as "yes" MATCH (p:Person) RETURN count(*) AS c', 'urn:gql:ms:def');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DP1 DEFINE alone (guard): " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('PREFIX ex: <http://example.org/> DEFINE input:same-as "yes" MATCH (p:Person) RETURN count(*) AS c', 'urn:gql:ms:def');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DP2 PREFIX then DEFINE: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('DEFINE input:same-as "yes" PREFIX ex: <http://example.org/> MATCH (p:Person) RETURN count(*) AS c', 'urn:gql:ms:def');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DP3 DEFINE then PREFIX: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('BASE <http://example.org/> DEFINE input:same-as "yes" INSERT (:Thing {name: ''T''})', 'urn:gql:ms:def');
select DB.DBA.GQL_MS_T_COUNT_IN ('BASE <http://example.org/> MATCH (t:Thing) RETURN count(*) AS c', 'urn:gql:ms:def');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DP4 BASE and DEFINE in an INSERT: the node is written: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('BASE <http://example.org/> DEFINE input:same-as "yes" MATCH (t:Thing) RETURN count(*) AS c', 'urn:gql:ms:def');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DP5 BASE and DEFINE in a read: " $LAST[1] "\n";
sparql clear graph <urn:gql:ms:def>;

-- Y0-Y9: an edge with no type, (a)-[r]->(b) or (a)-[]->(b), or with the
-- wildcard or a negated type (-[:%]->, -[:!T]->), matches only edges: a
-- triple whose object is a node and whose predicate is not GQL's
-- own storage -- not a label (rdf:type), not a property (a literal object),
-- not the triples of the resource that holds an edge's properties
-- (rdf:subject, rdf:predicate, rdf:object, rdf:reifies, or any triple of
-- that resource).  On <urn:gql:ms:y>: A KNOWS B {since: 2020} and C KNOWS D
-- -- 8 triples for the four people, 2 edges, 5 for the holder of A's edge --
-- and an IRI-valued property on that holder: 16 triples, 2 edges.
sparql clear graph <urn:gql:ms:y>;
select DB.DBA.GQL_RUN ('INSERT (a:Person {name: ''A''})-[:KNOWS {since: 2020}]->(b:Person {name: ''B''}), (c:Person {name: ''C''})-[:KNOWS]->(d:Person {name: ''D''})', 'urn:gql:ms:y');
sparql prefix o: <http://localhost:8890/gql/ontology/>
insert into graph <urn:gql:ms:y> { ?h o:source <urn:ms:y:feed> }
where { graph <urn:gql:ms:y> { ?h a rdf:Statement } };

select 99;
sparql select count (*) from <urn:gql:ms:y> where { ?s ?p ?o };
ECHO $IF $EQU $LAST[1] 16 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Y0 the graph holds 16 triples: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (a)-[r]->(b) RETURN count(*) AS c', 'urn:gql:ms:y');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Y1 (a)-[r]->(b) matches the 2 edges, not every triple: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (a)-[]->(b) RETURN count(*) AS c', 'urn:gql:ms:y');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Y2 (a)-[]->(b) likewise: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (a)-[r]-(b) RETURN count(*) AS c', 'urn:gql:ms:y');
ECHO $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Y3 undirected (a)-[r]-(b): each edge in both orientations: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (a)-[r]->(b:Person) RETURN count(*) AS c', 'urn:gql:ms:y');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Y4 an untyped edge into a labelled node is not the holder's rdf:object: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (a:Person)-[r]->(b) RETURN count(*) AS c', 'urn:gql:ms:y');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Y5 an untyped edge out of a labelled node: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (a)-[:KNOWS]->(b) RETURN count(*) AS c', 'urn:gql:ms:y');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Y6 a typed edge (guard): " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (a)-[r:%]->(b) RETURN count(*) AS c', 'urn:gql:ms:y');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Y7 the wildcard type, -[r:%]->, likewise: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (a)-[r:!KNOWS]->(b) RETURN count(*) AS c', 'urn:gql:ms:y');
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Y8 a negated type, -[r:!KNOWS]->, matches no storage triple: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (a)-[r:!LIKES]->(b) RETURN count(*) AS c', 'urn:gql:ms:y');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Y9 -[r:!LIKES]-> matches the 2 KNOWS edges: " $LAST[1] "\n";

sparql clear graph <urn:gql:ms:y>;

-- RD1-RD6: RDF 1.2 mode.  An INSERT of an edge with a property wrote its
-- reifier as _:?reif_1 (SP030); the {| |} annotation was emitted with a
-- '.' inside it (SP030); DEFINE input:rdf12 was passed on to SPARQL, which
-- does not know it (SP031).
create procedure DB.DBA.GQL_MS_T_STATE_IN (in _q varchar, in _g varchar) returns varchar
{
  declare exit handler for sqlstate '*' { return __SQL_STATE; };
  DB.DBA.GQL_RUN (_q, _g);
  return 'OK';
}
;

select 99;
select DB.DBA.GQL_MS_T_STATE_IN ('VERSION "rdf 1.2" INSERT (a:Person {name: ''A''})-[:knows {since: 2020}]->(b:Person {name: ''B''})', 'urn:gql:ms:rd');
ECHO $IF $EQU $LAST[1] "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": RD1 an RDF 1.2 INSERT of an edge with a property runs: " $LAST[1] "\n";

select 99;
select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:gql:ms:rd') and P = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": RD2 and writes one reifier: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('VERSION "rdf 1.2" MATCH (p:Person)-[e:knows {| since: 2020 |}]->(m:Person) RETURN count(*) AS c', 'urn:gql:ms:rd');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": RD3 the annotation form finds the edge: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('VERSION "rdf 1.2" MATCH (p:Person)-[e:knows {| since: 1999 |}]->(m:Person) RETURN count(*) AS c', 'urn:gql:ms:rd');
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": RD4 and not with another value: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('DEFINE input:rdf12 "yes" MATCH (p:Person)-[e:knows]->(m:Person) RETURN count(*) AS c', 'urn:gql:ms:rd');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": RD5 DEFINE input:rdf12 sets RDF 1.2 mode: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_STATE_IN ('VERSION "rdf 1.2" INSERT (c:Person {name: ''C''})-[r:knows {since: 2021}]->(d:Person {name: ''D''})', 'urn:gql:ms:rd');
ECHO $IF $EQU $LAST[1] "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": RD6 and with a named edge: " $LAST[1] "\n";
sparql clear graph <urn:gql:ms:rd>;

-- EV1-EV5: RETURN r of a named edge returns every edge it matched, whether or
-- not the edge has properties.  An edge with properties is the resource
-- that holds them, as before; one without is its triple, as RDF 1.2 mode
-- returns every edge.  On <urn:gql:ms:r>: A KNOWS B {since: 2020} and
-- C KNOWS D.
sparql clear graph <urn:gql:ms:r>;
select DB.DBA.GQL_RUN ('INSERT (a:Person {name: ''A''})-[:KNOWS {since: 2020}]->(b:Person {name: ''B''}), (c:Person {name: ''C''})-[:KNOWS]->(d:Person {name: ''D''})', 'urn:gql:ms:r');

create procedure DB.DBA.GQL_MS_T_ROWS_IN (in _q varchar, in _g varchar) returns integer
{
  declare _r any;
  declare exit handler for sqlstate '*' { return -1; };
  _r := DB.DBA.GQL_RUN (_q, _g);
  if (not isarray (_r))
    return -2;
  return length (_r);
}
;

-- 1 for a non-null value in the first column of the only row, else <= 0.
create procedure DB.DBA.GQL_MS_T_NOT_NULL_IN (in _q varchar, in _g varchar) returns integer
{
  declare _r any;
  declare exit handler for sqlstate '*' { return -1; };
  _r := DB.DBA.GQL_RUN (_q, _g);
  if (not isarray (_r) or length (_r) <> 1)
    return -2;
  if (aref (aref (_r, 0), 0) is null)
    return 0;
  return 1;
}
;

select 99;
select DB.DBA.GQL_MS_T_ROWS_IN ('MATCH (a)-[r:KNOWS]->(b) RETURN a.name AS an, r', 'urn:gql:ms:r');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": EV1 RETURN r returns both edges, with and without a property: " $LAST[1] " rows\n";

select 99;
select DB.DBA.GQL_MS_T_NOT_NULL_IN ('MATCH (a {name: ''C''})-[r:KNOWS]->(b) RETURN r', 'urn:gql:ms:r');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": EV2 an edge without properties is returned, not null: " $LAST[1] "\n";

select 99;
select case when strstr (cast (aref (aref (DB.DBA.GQL_RUN ('MATCH (a {name: ''A''})-[r:KNOWS]->(b) RETURN r', 'urn:gql:ms:r'), 0), 0) as varchar), '/gql/data/edge_') is not null then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": EV3 an edge with properties is still the resource holding them: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('MATCH (a)-[r:KNOWS]->(b) RETURN count(r) AS c', 'urn:gql:ms:r');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": EV4 count(r) counts both edges: " $LAST[1] "\n";

-- EV5: two edges with properties between the same two nodes are two edges.
select DB.DBA.GQL_RUN ('MATCH (a {name: ''A''}), (b {name: ''B''}) INSERT (a)-[:KNOWS {since: 2024}]->(b)', 'urn:gql:ms:r');
select 99;
select DB.DBA.GQL_MS_T_ROWS_IN ('MATCH (a {name: ''A''})-[r:KNOWS]->(b) RETURN r', 'urn:gql:ms:r');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": EV5 two edges with properties between the same nodes are two edges (guard): " $LAST[1] " rows\n";

sparql clear graph <urn:gql:ms:r>;

-- RR1-RR5: in RDF 1.2 mode the properties of an edge are the properties of
-- its reifier, the resource that rdf:reifies the edge's triple term.  A
-- property read through the edge variable (e.since, in RETURN or WHERE)
-- looked it up on the triple term itself, and found nothing.  A knows B
-- has a reifier with since 2020; B knows C has none.
sparql insert data { graph <urn:gql:ms:rr> {
  <urn:gql:ms:rr:a> <http://localhost:8890/gql/ontology/name> "A" .
  <urn:gql:ms:rr:b> <http://localhost:8890/gql/ontology/name> "B" .
  <urn:gql:ms:rr:c> <http://localhost:8890/gql/ontology/name> "C" .
  <urn:gql:ms:rr:a> <http://localhost:8890/gql/ontology/knows> <urn:gql:ms:rr:b> .
  <urn:gql:ms:rr:b> <http://localhost:8890/gql/ontology/knows> <urn:gql:ms:rr:c> .
  <urn:gql:ms:rr:r> <http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies>
      <<( <urn:gql:ms:rr:a> <http://localhost:8890/gql/ontology/knows> <urn:gql:ms:rr:b> )>> .
  <urn:gql:ms:rr:r> <http://localhost:8890/gql/ontology/since> 2020 . } };

-- The second column of the only row, else -2 (no row, or more than one).
create procedure DB.DBA.GQL_MS_T_SECOND_IN (in _q varchar, in _g varchar) returns any
{
  declare _r any;
  declare exit handler for sqlstate '*' { return -1; };
  _r := DB.DBA.GQL_RUN (_q, _g);
  if (not isarray (_r) or length (_r) <> 1)
    return -2;
  return aref (aref (_r, 0), 1);
}
;

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('VERSION "rdf 1.2" MATCH (a)-[e:knows {since: w}]->(b) RETURN w', 'urn:gql:ms:rr');
ECHO $IF $EQU $LAST[1] 2020 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": RR1 a property in the edge pattern, in RDF 1.2 mode (guard): " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('VERSION "rdf 1.2" MATCH (a)-[e:knows]->(b) RETURN e.since', 'urn:gql:ms:rr');
ECHO $IF $EQU $LAST[1] 2020 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": RR2 e.since in RETURN reads the reifier: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_COUNT_IN ('VERSION "rdf 1.2" MATCH (a)-[e:knows]->(b) WHERE e.since = 2020 RETURN count(*) AS c', 'urn:gql:ms:rr');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": RR3 e.since in WHERE: " $LAST[1] " edge\n";

select 99;
select DB.DBA.GQL_MS_T_SECOND_IN ('VERSION "rdf 1.2" MATCH (a)-[e:knows]->(b) RETURN e, e.since', 'urn:gql:ms:rr');
ECHO $IF $EQU $LAST[1] 2020 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": RR4 RETURN e, e.since: one row, with the reifier's value: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_MS_T_ROWS_IN ('VERSION "rdf 1.2" MATCH (a)-[e:knows]->(b) RETURN e', 'urn:gql:ms:rr');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": RR5 RETURN e alone still returns both edges (guard): " $LAST[1] " rows\n";

sparql clear graph <urn:gql:ms:rr>;

-- SV1-SV6: SERVICE sends the remote endpoint SPARQL 1.1: a sub-SELECT
-- whose RETURN items are aliases, NOT IN, and, for a node or an edge with
-- no label, a nested SELECT and the exclusion of the resources that hold
-- edge properties.  For an endpoint whose service description is not
-- loaded, the SPARQL compiler allows only SPARQL 1.0: a node or an edge
-- with no label did not compile (SP031), and an alias was left out of the
-- query sent while the reply was still read under it.  The SQL text of the
-- query shows what would be sent; no endpoint is called.
create function DB.DBA.GQL_MS_T_SVC_SQL (in _gql varchar) returns varchar
{
  declare _sparql varchar;
  declare exit handler for sqlstate '*' { return concat ('ERROR ', __SQL_STATE, ' ', __SQL_MESSAGE); };
  _sparql := DB.DBA.GQL_TO_SPARQL (_gql);
  if (_sparql like 'SPARQL %')
    _sparql := subseq (_sparql, 7);
  return cast (sparql_to_sql_text (_sparql) as varchar);
}
;

select 99;
select case when t like '%SPARQL_SINV%' and t not like '%runaway%' then 1 else 0 end, left (t, 120)
  from (select DB.DBA.GQL_MS_T_SVC_SQL ('SERVICE <http://example.com/sparql> { MATCH (p) RETURN p AS n } RETURN n') as t) x;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": SV1 a node with no label inside SERVICE: " $LAST[2] "\n";

select 99;
select case when t like '%SPARQL_SINV%' and t not like '%runaway%' then 1 else 0 end, left (t, 120)
  from (select DB.DBA.GQL_MS_T_SVC_SQL ('SERVICE <http://example.com/sparql> { MATCH (a)-[e]->(b) RETURN a AS x } RETURN x') as t) x;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": SV2 an edge with no label inside SERVICE: " $LAST[2] "\n";

select 99;
select case when t like '%AS ?country%' and t like '%expected_vars = vector ( ''country'' )%' then 1 else 0 end, left (t, 120)
  from (select DB.DBA.GQL_MS_T_SVC_SQL ('SERVICE <http://example.com/sparql> { MATCH (c:Country) RETURN c AS country } RETURN country') as t) x;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": SV3 the alias read back is the alias sent: " $LAST[2] "\n";

select 99;
select case when t like '%SPARQL_SINV%' and t not like '%runaway%' then 1 else 0 end, left (t, 120)
  from (select DB.DBA.GQL_MS_T_SVC_SQL ('SERVICE SILENT <http://example.com/sparql> { MATCH (p) RETURN p AS n } RETURN n') as t) x;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": SV4 SERVICE SILENT, a node with no label: " $LAST[2] "\n";

-- An endpoint whose description is loaded is sent what the description
-- allows; the query does not override it.
select jso_triple_add ('http://example.com/described-sparql', 'http://www.openlinksw.com/schemas/virtrdf#dialect', '00006120');
select 99;
select case when DB.DBA.GQL_TO_SPARQL ('SERVICE <http://example.com/described-sparql> { MATCH (p) RETURN p AS n } RETURN n') like '%lang:dialect%' then 0 else 1 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": SV5 a described endpoint keeps its description (guard): " $LAST[1] "\n";
select jso_triples_del ('http://example.com/described-sparql', 'http://www.openlinksw.com/schemas/virtrdf#dialect', null);

select 99;
select case when DB.DBA.GQL_TO_SPARQL ('MATCH (p) RETURN p AS n') like '%FILTER NOT EXISTS%' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": SV6 outside SERVICE a lone node is translated as before (guard): " $LAST[1] "\n";

sparql clear graph <urn:gql:ms:d>;
sparql clear graph <urn:gql:ms:l>;
sparql clear graph <urn:gql:ms:lr>;
sparql clear graph <urn:gql:ms>;

ECHO "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: GQL MATCH pattern semantics tests\n";

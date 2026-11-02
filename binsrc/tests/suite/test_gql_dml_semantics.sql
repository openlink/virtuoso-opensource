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
--  GQL for Virtuoso - data-modifying statement semantics
--
--  What INSERT, DELETE, SET and REMOVE leave in the graph, against counts
--  worked out by hand:
--
--    DN  DELETE n deletes a node that has no edges, labels and properties
--        included, and refuses one that still has an edge (G4015), as
--        NODETACH DELETE n does; DETACH DELETE n deletes the node and its
--        edges;
--    DI  MATCH ... DELETE, SET or REMOVE with an INSERT is one update: the
--        MATCH is evaluated once, before anything is deleted;
--    MI  a variable is one node across all the patterns of the INSERTs, and
--        a node or edge the INSERT creates is new for each row of the MATCH;
--    WF  SET and REMOVE change only the rows the MATCH's WHERE or FILTER
--        keeps;
--    DS  DELETE, SET and REMOVE in one statement are one update, over one
--        evaluation of the MATCH.
--
--  Run via isql: isql <host>:<port> dba dba test_gql_dml_semantics.sql
--

ECHO "STARTED: GQL data-modifying statement semantics tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

-- 'OK', or the SQLSTATE the statement raises.
create procedure DB.DBA.GQL_DML_T_STATE (in _q varchar, in _g varchar) returns varchar
{
  declare exit handler for sqlstate '*' { return __SQL_STATE; };
  DB.DBA.GQL_RUN (_q, _g);
  return 'OK';
}
;

-- The count a MATCH ... RETURN count(*) gives, or -1 when it raises.
create procedure DB.DBA.GQL_DML_T_COUNT (in _q varchar, in _g varchar) returns integer
{
  declare _r any;
  declare exit handler for sqlstate '*' { return -1; };
  _r := DB.DBA.GQL_RUN (_q, _g);
  if (not isarray (_r) or length (_r) <> 1)
    return -2;
  return aref (aref (_r, 0), 0);
}
;

-- The number of triples in the graph _g.
create procedure DB.DBA.GQL_DML_T_TRIPLES (in _g varchar) returns integer
{
  return (select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id (_g));
}
;

-- A KNOWS B, and C, with properties and no edge: 8 triples.  _props gives
-- the edge a property (its holder adds 5 triples).
create procedure DB.DBA.GQL_DML_T_DN_FIXTURE (in _g varchar, in _props integer := 0)
{
  exec (sprintf ('sparql clear graph <%s>', _g));
  DB.DBA.GQL_RUN (sprintf ('INSERT (a:Person {name: ''A''})-[:KNOWS%s]->(b:Person {name: ''B''}), (c:Person {name: ''C'', age: 30})',
    case when _props then ' {since: 2020}' else '' end), _g);
}
;

-- DN0-DN10: DELETE n.
DB.DBA.GQL_DML_T_DN_FIXTURE ('urn:gql:dml:dn');
select 99;
select DB.DBA.GQL_DML_T_TRIPLES ('urn:gql:dml:dn');
ECHO $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DN0 the fixture holds 8 triples: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (n {name: ''C''}) DELETE n', 'urn:gql:dml:dn');
ECHO $IF $EQU $LAST[1] "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DN1 DELETE n of a node without edges runs: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_TRIPLES ('urn:gql:dml:dn');
ECHO $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DN2 and deletes it, its label and properties included -- triples left: " $LAST[1] "\n";

DB.DBA.GQL_DML_T_DN_FIXTURE ('urn:gql:dml:dn');
select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (n {name: ''A''}) DELETE n', 'urn:gql:dml:dn');
ECHO $IF $EQU $LAST[1] "G4015" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DN3 DELETE n of a node with an outgoing edge is G4015: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_TRIPLES ('urn:gql:dml:dn');
ECHO $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DN4 and deletes nothing (guard) -- triples left: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (n {name: ''B''}) NODETACH DELETE n', 'urn:gql:dml:dn');
ECHO $IF $EQU $LAST[1] "G4015" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DN5 NODETACH DELETE n of a node with an incoming edge is G4015: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a)-[:KNOWS]->(b {name: ''B''}) RETURN count(*) AS c', 'urn:gql:dml:dn');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DN6 and keeps the node and its edge: " $LAST[1] "\n";

DB.DBA.GQL_DML_T_DN_FIXTURE ('urn:gql:dml:dn');
select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (a {name: ''A''})-[e:KNOWS]->(b) DELETE e, a', 'urn:gql:dml:dn');
ECHO $IF $EQU $LAST[1] "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DN7 an edge the same statement deletes does not count: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_TRIPLES ('urn:gql:dml:dn');
ECHO $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DN8 the node and the edge are gone, B and C stay -- triples left: " $LAST[1] "\n";

DB.DBA.GQL_DML_T_DN_FIXTURE ('urn:gql:dml:dn', 1);
select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (a {name: ''A''})-[e:KNOWS]->(b) DELETE e, a', 'urn:gql:dml:dn');
select DB.DBA.GQL_DML_T_TRIPLES ('urn:gql:dml:dn');
ECHO $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DN9 the same with a property on the edge: its holder goes too -- triples left: " $LAST[1] "\n";

DB.DBA.GQL_DML_T_DN_FIXTURE ('urn:gql:dml:dn');
select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (n {name: ''B''}) DETACH DELETE n', 'urn:gql:dml:dn');
select DB.DBA.GQL_DML_T_TRIPLES ('urn:gql:dml:dn');
ECHO $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DN10 DETACH DELETE n deletes the node and its edge (guard) -- triples left: " $LAST[1] "\n";

sparql clear graph <urn:gql:dml:dn>;

-- DI1-DI12: MATCH ... DELETE / SET / REMOVE ... INSERT is one update: the
-- MATCH is evaluated once, before anything is deleted, and both happen.
-- On <urn:gql:dml:di>: A KNOWS B {since: 2020} -- 4 triples for the
-- people, the edge, 5 for the holder of its property: 10 triples.
create procedure DB.DBA.GQL_DML_T_DI_FIXTURE (in _g varchar)
{
  exec (sprintf ('sparql clear graph <%s>', _g));
  DB.DBA.GQL_RUN ('INSERT (a:Person {name: ''A''})-[:KNOWS {since: 2020}]->(b:Person {name: ''B''})', _g);
}
;

DB.DBA.GQL_DML_T_DI_FIXTURE ('urn:gql:dml:di');
select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (a {name: ''A''})-[e:KNOWS]->(b) DELETE e INSERT (a)-[:KNOWS {since: 2024}]->(b)', 'urn:gql:dml:di');
ECHO $IF $EQU $LAST[1] "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DI1 DELETE e INSERT (a)-[:KNOWS {...}]->(b) runs: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a)-[r:KNOWS]->(b) WHERE r.since = 2020 RETURN count(*) AS c', 'urn:gql:dml:di');
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DI2 the old edge is deleted: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a)-[r:KNOWS]->(b) WHERE r.since = 2024 RETURN count(*) AS c', 'urn:gql:dml:di');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DI3 the new edge is inserted (guard): " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_TRIPLES ('urn:gql:dml:di');
ECHO $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DI4 one edge, one holder -- triples: " $LAST[1] "\n";

DB.DBA.GQL_DML_T_DI_FIXTURE ('urn:gql:dml:di');
select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (a {name: ''A''})-[e:KNOWS]->(b) INSERT (a)-[:KNOWS {since: 2030}]->(b) DELETE e', 'urn:gql:dml:di');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a)-[r:KNOWS]->(b) RETURN count(r) AS c', 'urn:gql:dml:di');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DI5 INSERT before DELETE e: the new edge replaces the old one: " $LAST[1] " edge(s)\n";

select 99;
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a)-[r:KNOWS]->(b) WHERE r.since = 2030 RETURN count(*) AS c', 'urn:gql:dml:di');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DI6 and it is the new one: " $LAST[1] "\n";

DB.DBA.GQL_DML_T_DI_FIXTURE ('urn:gql:dml:di');
select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (a {name: ''A''}), (b {name: ''B''}) SET a.age = 40 INSERT (a)-[:LIKES]->(b)', 'urn:gql:dml:di');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a {name: ''A'', age: 40}) RETURN count(*) AS c', 'urn:gql:dml:di');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DI7 SET ... INSERT: the SET is done: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a {name: ''A''})-[:LIKES]->(b {name: ''B''}) RETURN count(*) AS c', 'urn:gql:dml:di');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DI8 and the INSERT (guard): " $LAST[1] "\n";

DB.DBA.GQL_RUN ('MATCH (a {name: ''A''}) SET a.age = 40', 'urn:gql:dml:di');
select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (a {name: ''A''}), (b {name: ''B''}) REMOVE a.age INSERT (b)-[:LIKES]->(a)', 'urn:gql:dml:di');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a {name: ''A'', age: 40}) RETURN count(*) AS c', 'urn:gql:dml:di');
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DI9 REMOVE ... INSERT: the REMOVE is done: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_COUNT ('MATCH (b {name: ''B''})-[:LIKES]->(a {name: ''A''}) RETURN count(*) AS c', 'urn:gql:dml:di');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DI10 and the INSERT (guard): " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (a {name: ''A''})-[e:LIKES]->(b) DELETE e SET a.age = 50 INSERT (a)-[:KNOWS {since: 2040}]->(b)', 'urn:gql:dml:di');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a {name: ''A''})-[:LIKES]->(b) RETURN count(*) AS c', 'urn:gql:dml:di');
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DI11 DELETE e SET ... INSERT: the edge is deleted: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a)-[r:KNOWS]->(b) WHERE r.since = 2040 RETURN count(*) AS c', 'urn:gql:dml:di');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DI12 and the new edge inserted: " $LAST[1] "\n";

sparql clear graph <urn:gql:dml:di>;

-- MI1-MI8: a variable is one node across all the patterns of a statement's
-- INSERTs, and a node or edge the INSERT creates is a new one for each row
-- the MATCH gives.
create procedure DB.DBA.GQL_DML_T_CLEAR (in _g varchar)
{
  exec (sprintf ('sparql clear graph <%s>', _g));
}
;

-- The number of distinct resources holding edge properties in _g.
create procedure DB.DBA.GQL_DML_T_HOLDERS (in _g varchar) returns integer
{
  return (select count (distinct S) from DB.DBA.RDF_QUAD
    where G = iri_to_id (_g) and P = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type')
      and O = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement'));
}
;

DB.DBA.GQL_DML_T_CLEAR ('urn:gql:dml:mi');
select 99;
select DB.DBA.GQL_DML_T_STATE ('INSERT (a:Person {name: ''A''})-[:KNOWS]->(b:Person {name: ''B''}), (b)-[:LIKES]->(c:Person {name: ''C''})', 'urn:gql:dml:mi');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (n) RETURN count(*) AS c', 'urn:gql:dml:mi');
ECHO $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": MI1 (b) in a second pattern is the b of the first: nodes: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_COUNT ('MATCH (x {name: ''B''})-[:LIKES]->(y {name: ''C''}) RETURN count(*) AS c', 'urn:gql:dml:mi');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": MI2 the second edge starts at the node named B: " $LAST[1] "\n";

DB.DBA.GQL_DML_T_CLEAR ('urn:gql:dml:mi');
select 99;
select DB.DBA.GQL_DML_T_STATE ('INSERT (a:Person {name: ''A''}) INSERT (a)-[:KNOWS]->(:Person {name: ''B''})', 'urn:gql:dml:mi');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (x {name: ''A''})-[:KNOWS]->(y {name: ''B''}) RETURN count(*) AS c', 'urn:gql:dml:mi');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": MI3 and across two INSERT clauses: " $LAST[1] "\n";

DB.DBA.GQL_DML_T_CLEAR ('urn:gql:dml:mi');
DB.DBA.GQL_RUN ('INSERT (:Person {name: ''A''}), (:Person {name: ''B''}), (:Person {name: ''C''}), (:Target {name: ''T''})', 'urn:gql:dml:mi');
select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (a:Person {name: ''A''}) INSERT (a)-[:OWNS]->(n:Pet {name: ''P''}), (n)-[:HAS]->(m:Toy {name: ''Y''})', 'urn:gql:dml:mi');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a {name: ''A''})-[:OWNS]->(n:Pet {name: ''P''})-[:HAS]->(m:Toy {name: ''Y''}) RETURN count(*) AS c', 'urn:gql:dml:mi');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": MI4 MATCH ... INSERT of new named nodes inserts them: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (p:Person) INSERT (p)-[:HAS]->(:Badge {kind: ''x''})', 'urn:gql:dml:mi');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (b:Badge) RETURN count(*) AS c', 'urn:gql:dml:mi');
ECHO $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": MI5 a new anonymous node is a new node for each of the 3 rows: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (p:Person), (t:Target) INSERT (p)-[:RATES {stars: 5}]->(t)', 'urn:gql:dml:mi');
select DB.DBA.GQL_DML_T_HOLDERS ('urn:gql:dml:mi');
ECHO $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": MI6 a new edge's property holder is a new one for each row: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (p)-[e:RATES]->(t) DELETE e INSERT (p)-[:RATES {stars: 4}]->(t)', 'urn:gql:dml:mi');
select DB.DBA.GQL_DML_T_HOLDERS ('urn:gql:dml:mi');
ECHO $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": MI7 likewise beside a DELETE: holders: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_COUNT ('MATCH (p)-[r:RATES]->(t) WHERE r.stars = 4 RETURN count(*) AS c', 'urn:gql:dml:mi');
ECHO $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": MI8 each with its own property (guard): " $LAST[1] "\n";

sparql clear graph <urn:gql:dml:mi>;

-- MR1-MR6: a variable described twice -- with labels or properties in two
-- node patterns of a statement's INSERTs -- is refused (G3014): the two
-- descriptions were merged into one node, explicit IRIs and all.  A bare
-- reference, (p), is the same node, before or after its description.
DB.DBA.GQL_DML_T_CLEAR ('urn:gql:dml:mr');
select 99;
select DB.DBA.GQL_DML_T_STATE ('INSERT (p:Person {firstName: ''Zed'', age: 3}) INSERT (p:Person {firstName: ''Yan'', age: 4})', 'urn:gql:dml:mr');
ECHO $IF $EQU $LAST[1] "G3014" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": MR1 INSERT (p {...}) INSERT (p {...}) is refused: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_TRIPLES ('urn:gql:dml:mr');
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": MR2 and writes nothing: triples " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_STATE ('INSERT (c:Customer {iri: ''urn:gql:dml:mr:1'', name: ''Alice''}) INSERT (c:Customer {iri: ''urn:gql:dml:mr:2'', name: ''Bob''})', 'urn:gql:dml:mr');
ECHO $IF $EQU $LAST[1] "G3014" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": MR3 two explicit IRIs for one variable are refused: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_STATE ('INSERT (p:Person {name: ''A''}), (p:Person {name: ''B''})', 'urn:gql:dml:mr');
ECHO $IF $EQU $LAST[1] "G3014" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": MR4 likewise in one INSERT clause: " $LAST[1] "\n";

DB.DBA.GQL_DML_T_CLEAR ('urn:gql:dml:mr');
select 99;
select DB.DBA.GQL_DML_T_STATE ('INSERT (a:Person {name: ''A''})-[:KNOWS]->(b), (b:Person {name: ''B''})', 'urn:gql:dml:mr');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (x:Person {name: ''A''})-[:KNOWS]->(y:Person {name: ''B''}) RETURN count(*) AS c', 'urn:gql:dml:mr');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": MR5 a bare (b) described later is one node (guard): " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_COUNT ('MATCH (n) RETURN count(*) AS c', 'urn:gql:dml:mr');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": MR6 and the graph has two nodes (guard): " $LAST[1] "\n";
sparql clear graph <urn:gql:dml:mr>;

-- WF1-WF6: SET and REMOVE change only the rows the MATCH's WHERE (or a
-- FILTER statement) keeps.  On <urn:gql:dml:wf>: A, 20, and B, 40, both
-- with x: 1.
create procedure DB.DBA.GQL_DML_T_WF_FIXTURE (in _g varchar)
{
  exec (sprintf ('sparql clear graph <%s>', _g));
  DB.DBA.GQL_RUN ('INSERT (:Person {name: ''A'', age: 20, x: 1}), (:Person {name: ''B'', age: 40, x: 1})', _g);
}
;

DB.DBA.GQL_DML_T_WF_FIXTURE ('urn:gql:dml:wf');
select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (a:Person) WHERE a.age > 30 SET a.flag = 1', 'urn:gql:dml:wf');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a:Person {flag: 1}) RETURN count(*) AS c', 'urn:gql:dml:wf');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": WF1 MATCH ... WHERE a.age > 30 SET sets the one person over 30: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (a:Person) FILTER a.age > 30 SET a.y = 1', 'urn:gql:dml:wf');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a:Person {y: 1}) RETURN count(*) AS c', 'urn:gql:dml:wf');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": WF2 likewise after a FILTER statement: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (a:Person) WHERE a.age > 30 SET a:Senior', 'urn:gql:dml:wf');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a:Senior) RETURN count(*) AS c', 'urn:gql:dml:wf');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": WF3 a label SET likewise: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (a:Person) WHERE a.age > 30 REMOVE a.x', 'urn:gql:dml:wf');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a:Person {x: 1}) RETURN count(*) AS c', 'urn:gql:dml:wf');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": WF4 REMOVE removes from the one person over 30 only: " $LAST[1] " keep x\n";

select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (a:Person) WHERE a.age > 30 REMOVE a:Person', 'urn:gql:dml:wf');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a:Person) RETURN count(*) AS c', 'urn:gql:dml:wf');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": WF5 a label REMOVE likewise: " $LAST[1] " keep the label\n";

DB.DBA.GQL_DML_T_WF_FIXTURE ('urn:gql:dml:wf');
select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (a:Person) WHERE a.age > 30 DETACH DELETE a', 'urn:gql:dml:wf');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a:Person) RETURN count(*) AS c', 'urn:gql:dml:wf');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": WF6 DETACH DELETE likewise (guard): " $LAST[1] "\n";

sparql clear graph <urn:gql:dml:wf>;

-- DS1-DS8: DELETE, SET and REMOVE in one statement are one update: the
-- MATCH is evaluated once, before any of them, and all of them happen.
-- On <urn:gql:dml:ds>: A {nick: 'x'} LIKES B.
create procedure DB.DBA.GQL_DML_T_DS_FIXTURE (in _g varchar)
{
  exec (sprintf ('sparql clear graph <%s>', _g));
  DB.DBA.GQL_RUN ('INSERT (a:Person {name: ''A'', nick: ''x''})-[:LIKES]->(b:Person {name: ''B''})', _g);
}
;

DB.DBA.GQL_DML_T_DS_FIXTURE ('urn:gql:dml:ds');
select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (a {name: ''A''})-[e:LIKES]->(b) DELETE e SET a.age = 50', 'urn:gql:dml:ds');
ECHO $IF $EQU $LAST[1] "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DS1 DELETE e SET a.age = 50 runs: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a {name: ''A'', age: 50}) RETURN count(*) AS c', 'urn:gql:dml:ds');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DS2 the SET is done although the MATCH's edge is deleted: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a {name: ''A''})-[:LIKES]->(b) RETURN count(*) AS c', 'urn:gql:dml:ds');
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DS3 and the edge is deleted (guard): " $LAST[1] "\n";

DB.DBA.GQL_DML_T_DS_FIXTURE ('urn:gql:dml:ds');
select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (a {name: ''A''})-[e:LIKES]->(b) DELETE e REMOVE a.nick', 'urn:gql:dml:ds');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a {name: ''A'', nick: ''x''}) RETURN count(*) AS c', 'urn:gql:dml:ds');
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DS4 DELETE e REMOVE a.nick: the REMOVE is done: " $LAST[1] "\n";

DB.DBA.GQL_DML_T_DS_FIXTURE ('urn:gql:dml:ds');
DB.DBA.GQL_RUN ('MATCH (a {name: ''A''}) SET a.age = 50', 'urn:gql:dml:ds');
select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (a {name: ''A'', age: 50}) SET a.age = 60 REMOVE a.nick', 'urn:gql:dml:ds');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a {name: ''A'', nick: ''x''}) RETURN count(*) AS c', 'urn:gql:dml:ds');
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DS5 SET ... REMOVE where the MATCH reads what SET changes: the REMOVE is done: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a {name: ''A'', age: 60}) RETURN count(*) AS c', 'urn:gql:dml:ds');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DS6 and the SET (guard): " $LAST[1] "\n";

DB.DBA.GQL_DML_T_DS_FIXTURE ('urn:gql:dml:ds');
select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (a {name: ''A''})-[e:LIKES]->(b) DELETE e SET a.age = 70 INSERT (a)-[:KNOWS {since: 1}]->(b)', 'urn:gql:dml:ds');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a {name: ''A'', age: 70}) RETURN count(*) AS c', 'urn:gql:dml:ds');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DS7 DELETE e SET ... INSERT: the SET is done: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a {name: ''A''})-[r:KNOWS]->(b) WHERE r.since = 1 RETURN count(*) AS c', 'urn:gql:dml:ds');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": DS8 and the INSERT (guard): " $LAST[1] "\n";

sparql clear graph <urn:gql:dml:ds>;

-- TD1-TD13: data-modifying forms that failed or did the wrong thing.
DB.DBA.GQL_DML_T_CLEAR ('urn:gql:dml:td');
select 99;
select DB.DBA.GQL_DML_T_STATE ('INSERT (n:Person & Employee {name: ''Ann''})', 'urn:gql:dml:td');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (n:Person & Employee {name: ''Ann''}) RETURN count(*) AS c', 'urn:gql:dml:td');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": TD1 INSERT (n:A & B) writes a node with both labels: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_STATE ('INSERT (n:Person | Employee {name: ''Bo''})', 'urn:gql:dml:td');
ECHO $IF $EQU $LAST[1] "G2004" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": TD2 an inserted node takes a label set, not A | B: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_RUN ('INSERT (p:Person {name: ''Bob'', age: 25})', 'urn:gql:dml:td');
select DB.DBA.GQL_DML_T_STATE ('MATCH (p:Person {name: ''Bob''}) SET p.updated = CURRENT_TIMESTAMP', 'urn:gql:dml:td');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (p:Person {name: ''Bob''}) WHERE p.updated IS NOT NULL RETURN count(*) AS c', 'urn:gql:dml:td');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": TD3 SET p.x = CURRENT_TIMESTAMP sets it: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_STATE ('MATCH (p:Person {name: ''Bob''}) DELETE p.age', 'urn:gql:dml:td');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (p:Person {name: ''Bob''}) RETURN count(p.age) AS c', 'urn:gql:dml:td');
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": TD4 DELETE p.prop removes the property: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_RUN ('MATCH (p:Person {name: ''Bob''}) SET p.age = 26', 'urn:gql:dml:td');
select DB.DBA.GQL_DML_T_STATE ('WITH <urn:gql:dml:td> MATCH (p:Person {name: ''Bob''}) DELETE p.age', null);
select DB.DBA.GQL_DML_T_COUNT ('MATCH (p:Person {name: ''Bob''}) RETURN count(p.age) AS c', 'urn:gql:dml:td');
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": TD5 and under WITH: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_RUN ('MATCH (p:Person {name: ''Bob''}) SET p.age = 27', 'urn:gql:dml:td');
select DB.DBA.GQL_DML_T_STATE ('MATCH (p:Person {name: ''Bob''}) USING <urn:gql:dml:td> REMOVE p.age', 'urn:gql:dml:td');
ECHO $IF $EQU $LAST[1] "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": TD6 USING compiles: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_COUNT ('MATCH (p:Person {name: ''Bob''}) RETURN count(p.age) AS c', 'urn:gql:dml:td');
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": TD7 and the update reads the USING graph: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_RUN ('INSERT (z:Person {iri: ''urn:gql:dml:td:zed'', name: ''Zed''})', 'urn:gql:dml:td');
select DB.DBA.GQL_DML_T_STATE ('DELETE DATA (z:Person {iri: ''urn:gql:dml:td:zed'', name: ''Zed''})', 'urn:gql:dml:td');
select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:gql:dml:td') and S = iri_to_id ('urn:gql:dml:td:zed');
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": TD8 DELETE DATA with an iri deletes the node's triples: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_STATE ('DELETE DATA (z:Person {name: ''Zed''})', 'urn:gql:dml:td');
ECHO $IF $EQU $LAST[1] "G2004" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": TD9 DELETE DATA without an iri is refused: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_RUN ('INSERT (c:Person {name: ''Carl''})-[:knows {since: 1}]->(d:Person {name: ''Dora''}), (e:Person {name: ''Ed''})-[:knows]->(c)', 'urn:gql:dml:td');
select DB.DBA.GQL_DML_T_STATE ('MATCH (p:Person {name: ''Carl''}) DETACH DELETE p INSERT (q:Person {name: ''Carla''})', 'urn:gql:dml:td');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (q:Person {name: ''Carla''}) RETURN count(*) AS c', 'urn:gql:dml:td');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": TD10 DETACH DELETE p beside INSERT of a new node writes one node: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_COUNT ('MATCH (n {name: ''Carl''}) RETURN count(*) AS c', 'urn:gql:dml:td');
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": TD11 and deletes Carl (guard): " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_STATE ('INSERT (a:Person {name: ''Dave''}) INSERT (b:Person {name: ''Erin''}) MATCH (a:Person {name: ''Dave''}), (b:Person {name: ''Erin''}) INSERT (a)-[:knows]->(b)', 'urn:gql:dml:td');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (a {name: ''Dave''})-[:knows]->(b {name: ''Erin''}) RETURN count(*) AS c', 'urn:gql:dml:td');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": TD12 INSERT, INSERT, MATCH ... INSERT runs in order: " $LAST[1] "\n";

select 99;
select DB.DBA.GQL_DML_T_STATE ('INSERT (f:Person {name: ''Finn''}) MATCH (b:Person {name: ''Erin''}) INSERT (f)-[:knows]->(b)', 'urn:gql:dml:td');
select DB.DBA.GQL_DML_T_COUNT ('MATCH (f:Person {name: ''Finn''})-[:knows]->(b {name: ''Erin''}) RETURN count(*) AS c', 'urn:gql:dml:td');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": TD13 and a node the first INSERT made is the same node after the MATCH: " $LAST[1] "\n";
sparql clear graph <urn:gql:dml:td>;

ECHO "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: GQL data-modifying statement semantics tests\n";

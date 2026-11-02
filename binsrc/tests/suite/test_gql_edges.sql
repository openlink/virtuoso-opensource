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
--  GQL for Virtuoso - edge insertion tests
--
--  MATCH ... INSERT finds its endpoints in the graph it writes to, through
--  every DML entry point.  GQL_VECTOR_EDGE_INSERT and GQL_STAGED_EDGE_INSERT
--  write edges between key-matched nodes in bounded vectored chunks, and an
--  opt-in route runs literal MATCH ... INSERT statements of that shape the
--  same way; all of them check graph permissions as MATCH ... INSERT does.
--
--  Run via isql: isql <host>:<port> dba dba test_gql_edges.sql
--

ECHO "STARTED: GQL edge insertion tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

create procedure DB.DBA.GQL_EDGES_T_COUNT (in _q varchar, in _g varchar) returns integer
{
  declare _r any;
  _r := DB.DBA.GQL_RUN (_q, _g);
  if (not isarray (_r))
    return 0;
  return length (_r);
}
;

-- Two graphs: 'a' and 'b' are in urn:gql:edges, 'a' and 'zz' in
-- urn:gql:edges:other.
create procedure DB.DBA.GQL_EDGES_T_GRAPHS ()
{
  sparql clear graph <urn:gql:edges>;
  sparql clear graph <urn:gql:edges:other>;
  DB.DBA.GQL_RUN ('INSERT (:Person { name: ''a'' }), (:Person { name: ''b'' })', 'urn:gql:edges');
  DB.DBA.GQL_RUN ('INSERT (:Person { name: ''a'' }), (:Person { name: ''zz'' })', 'urn:gql:edges:other');
  commit work;
}
;

DB.DBA.GQL_EDGES_T_GRAPHS ();

-- G1: an endpoint that exists only in another graph is not matched.
create procedure DB.DBA.GQL_EDGES_T_OTHER_ONLY () returns integer
{
  DB.DBA.GQL_RUN ('MATCH (s:Person { name: ''a'' }), (t:Person { name: ''zz'' }) INSERT (s)-[:G1]->(t)',
    'urn:gql:edges');
  commit work;
  return DB.DBA.GQL_EDGES_T_COUNT ('MATCH (s)-[:G1]->(t) RETURN s', 'urn:gql:edges');
}
;

select 99;
select DB.DBA.GQL_EDGES_T_OTHER_ONLY ();
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": G1 MATCH ... INSERT does not match a node of another graph\n";

-- G2: a key both graphs have matches only the target graph's node.
create procedure DB.DBA.GQL_EDGES_T_BOTH () returns integer
{
  DB.DBA.GQL_RUN ('MATCH (s:Person { name: ''a'' }), (t:Person { name: ''b'' }) INSERT (s)-[:G2]->(t)',
    'urn:gql:edges');
  commit work;
  return DB.DBA.GQL_EDGES_T_COUNT ('MATCH (s)-[:G2]->(t) RETURN s', 'urn:gql:edges');
}
;

select 99;
select DB.DBA.GQL_EDGES_T_BOTH ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": G2 a key in both graphs links only the target graph's node\n";

-- G3: the same through a batch.
create procedure DB.DBA.GQL_EDGES_T_BATCH () returns integer
{
  DB.DBA.GQL_BATCH_PARAMS (
    concat ('MATCH (s:Person { name: ', chr (36), 'src }), (t:Person { name: ', chr (36), 'dst }) INSERT (s)-[:G3]->(t)'),
    'urn:gql:edges',
    vector (vector (vector ('src', 'a'), vector ('dst', 'zz')),
            vector (vector ('src', 'a'), vector ('dst', 'b'))));
  commit work;
  return DB.DBA.GQL_EDGES_T_COUNT ('MATCH (s)-[:G3]->(t) RETURN s', 'urn:gql:edges');
}
;

select 99;
select DB.DBA.GQL_EDGES_T_BATCH ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": G3 a batch MATCH ... INSERT matches only the target graph\n";

-- G4: the same through prepared DML.
create procedure DB.DBA.GQL_EDGES_T_PREPARED () returns integer
{
  declare _q varchar;
  _q := concat ('MATCH (s:Person { name: ', chr (36), 'src }), (t:Person { name: ', chr (36), 'dst }) INSERT (s)-[:G4]->(t)');
  DB.DBA.GQL_PREPARED_DML_PARAMS (_q, 'urn:gql:edges', vector (vector ('src', 'a'), vector ('dst', 'zz')));
  DB.DBA.GQL_PREPARED_DML_PARAMS (_q, 'urn:gql:edges', vector (vector ('src', 'a'), vector ('dst', 'b')));
  commit work;
  return DB.DBA.GQL_EDGES_T_COUNT ('MATCH (s)-[:G4]->(t) RETURN s', 'urn:gql:edges');
}
;

select 99;
select DB.DBA.GQL_EDGES_T_PREPARED ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": G4 a prepared MATCH ... INSERT matches only the target graph\n";

-- G5: the same through GQL_EXECUTE.
create procedure DB.DBA.GQL_EDGES_T_EXEC () returns integer
{
  declare _st, _msg varchar;
  declare _meta, _data any;
  _st := '00000'; _msg := '';
  exec ('DB.DBA.GQL_EXECUTE (?, ?)', _st, _msg,
    vector ('MATCH (s:Person { name: ''a'' }), (t:Person { name: ''b'' }) INSERT (s)-[:G5]->(t)', 'urn:gql:edges'),
    100, _meta, _data);
  if (_st <> '00000')
    signal (_st, _msg);
  commit work;
  return DB.DBA.GQL_EDGES_T_COUNT ('MATCH (s)-[:G5]->(t) RETURN s', 'urn:gql:edges');
}
;

select 99;
select DB.DBA.GQL_EDGES_T_EXEC ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": G5 GQL_EXECUTE MATCH ... INSERT matches only the target graph\n";

-- G6: a statement that names its own dataset with WITH still reads it.
create procedure DB.DBA.GQL_EDGES_T_WITH () returns integer
{
  DB.DBA.GQL_RUN ('WITH <urn:gql:edges:other> MATCH (s:Person { name: ''zz'' }) INSERT (s)-[:G6]->(s)',
    'urn:gql:edges');
  commit work;
  return DB.DBA.GQL_EDGES_T_COUNT ('MATCH (s)-[:G6]->(t) RETURN s', 'urn:gql:edges');
}
;

select 99;
select DB.DBA.GQL_EDGES_T_WITH ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": G6 MATCH ... INSERT with WITH reads the named graph\n";

----------------------------------------------------------------------
-- GQL_VECTOR_EDGE_INSERT: edges between nodes found by one key property,
-- given as arrays of keys and run in bounded vectored chunks.  It checks
-- the caller's graph permissions as MATCH ... INSERT does, validates every
-- endpoint before writing, and leaves the transaction to the caller.
----------------------------------------------------------------------

-- 'src>dst;' for each _edge edge of _g, by the endpoints' _key, ordered.
create procedure DB.DBA.GQL_EDGES_T_PAIRS (in _edge varchar, in _g varchar, in _key varchar := 'name') returns varchar
{
  declare _r any;
  declare _s varchar;
  declare _i integer;
  _r := DB.DBA.GQL_RUN (sprintf ('MATCH (a)-[:%s]->(b) RETURN a.%s AS src, b.%s AS dst ORDER BY src, dst', _edge, _key, _key), _g);
  _s := '';
  if (not isarray (_r))
    return _s;
  for (_i := 0; _i < length (_r); _i := _i + 1)
    _s := concat (_s, cast (aref (_r, _i, 0) as varchar), '>', cast (aref (_r, _i, 1) as varchar), ';');
  return _s;
}
;

-- The value of _key in a GQL_VECTOR_EDGE_INSERT result.
create procedure DB.DBA.GQL_EDGES_T_RES (in _r any, in _key varchar) returns any
{
  declare _i integer;
  for (_i := 0; _i < length (_r); _i := _i + 1)
    if (aref (_r, _i, 0) = _key)
      return aref (_r, _i, 1);
  return null;
}
;

-- 'SQLSTATE message' of running _sql with _params ('00000 ' if it ran).
create procedure DB.DBA.GQL_EDGES_T_STATE (in _sql varchar, in _params any) returns varchar
{
  declare _st, _msg varchar;
  _st := '00000'; _msg := '';
  exec (_sql, _st, _msg, _params);
  return concat (_st, ' ', _msg);
}
;

create procedure DB.DBA.GQL_EDGES_T_VE_SETUP ()
{
  sparql clear graph <urn:gql:ve>;
  sparql clear graph <urn:gql:ve:other>;
  -- The Item comes first: a lookup that takes the first node with the key
  -- and only then checks its label does not find the Person.
  DB.DBA.GQL_RUN ('INSERT (:Item { name: ''shadow'' })', 'urn:gql:ve');
  DB.DBA.GQL_RUN ('INSERT (:Person { name: ''v0'' }), (:Person { name: ''v1'' }), (:Person { name: ''v2'' }), (:Person { name: ''v3'' }), (:Person { name: ''v4'' })', 'urn:gql:ve');
  DB.DBA.GQL_RUN ('INSERT (:Person { name: ''shadow'' }), (:Person { name: ''twin'' }), (:Person { name: ''twin'' })', 'urn:gql:ve');
  DB.DBA.GQL_RUN ('INSERT (:Person { name: "O''Reilly Ω" }), (:Person { name: ''} UNION { ?s ?p ?o } #'' })', 'urn:gql:ve');
  DB.DBA.GQL_RUN ('INSERT (:Person { name: ''elsewhere'' })', 'urn:gql:ve:other');
  commit work;
}
;

DB.DBA.GQL_EDGES_T_VE_SETUP ();

-- V1: five rows in chunks of two: three chunks, five edges.
create procedure DB.DBA.GQL_EDGES_T_V1 () returns integer
{
  declare _r any;
  _r := DB.DBA.GQL_VECTOR_EDGE_INSERT ('urn:gql:ve', 'Person', 'name', vector ('v0', 'v1', 'v2', 'v3', 'v4'),
    'Person', 'name', vector ('v1', 'v2', 'v3', 'v4', 'v0'), 'KNOWS', 2);
  commit work;
  if (DB.DBA.GQL_EDGES_T_PAIRS ('KNOWS', 'urn:gql:ve') = 'v0>v1;v1>v2;v2>v3;v3>v4;v4>v0;'
      and DB.DBA.GQL_EDGES_T_RES (_r, 'rows_submitted') = 5
      and DB.DBA.GQL_EDGES_T_RES (_r, 'rows_succeeded') = 5
      and DB.DBA.GQL_EDGES_T_RES (_r, 'chunks_executed') = 3
      and DB.DBA.GQL_EDGES_T_RES (_r, 'execution_mode') = 'vector')
    return 1;
  return 0;
}
;

select 99;
select DB.DBA.GQL_EDGES_T_V1 ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": V1 five key pairs in chunks of two write five edges\n";

-- V2: they are the edges MATCH ... INSERT writes for the same pairs.
create procedure DB.DBA.GQL_EDGES_T_V2 () returns integer
{
  declare _i integer;
  declare _src, _dst any;
  _src := vector ('v0', 'v1', 'v2', 'v3', 'v4');
  _dst := vector ('v1', 'v2', 'v3', 'v4', 'v0');
  for (_i := 0; _i < 5; _i := _i + 1)
    DB.DBA.GQL_RUN (sprintf ('MATCH (s:Person { name: ''%s'' }), (t:Person { name: ''%s'' }) INSERT (s)-[:KNOWS_S]->(t)',
      aref (_src, _i), aref (_dst, _i)), 'urn:gql:ve');
  commit work;
  if (DB.DBA.GQL_EDGES_T_PAIRS ('KNOWS_S', 'urn:gql:ve') = DB.DBA.GQL_EDGES_T_PAIRS ('KNOWS', 'urn:gql:ve')
      and DB.DBA.GQL_EDGES_T_COUNT ('MATCH (a)-[:KNOWS]->(b), (a)-[:KNOWS_S]->(b) RETURN a', 'urn:gql:ve') = 5)
    return 1;
  return 0;
}
;

select 99;
select DB.DBA.GQL_EDGES_T_V2 ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": V2 the edges are those MATCH ... INSERT writes\n";

-- V3: quotes, non-ASCII text and statement-shaped keys are only values.
create procedure DB.DBA.GQL_EDGES_T_V3 () returns integer
{
  DB.DBA.GQL_VECTOR_EDGE_INSERT ('urn:gql:ve', 'Person', 'name', vector ('O''Reilly Ω'),
    'Person', 'name', vector ('} UNION { ?s ?p ?o } #'), 'SPECIAL');
  commit work;
  if (DB.DBA.GQL_EDGES_T_PAIRS ('SPECIAL', 'urn:gql:ve') = 'O''Reilly Ω>} UNION { ?s ?p ?o } #;')
    return 1;
  return 0;
}
;

select 99;
select DB.DBA.GQL_EDGES_T_V3 ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": V3 quoted, non-ASCII and statement-shaped keys are values\n";

-- V4: no rows is a successful no-op.
create procedure DB.DBA.GQL_EDGES_T_V4 () returns integer
{
  declare _r any;
  _r := DB.DBA.GQL_VECTOR_EDGE_INSERT ('urn:gql:ve', 'Person', 'name', vector (),
    'Person', 'name', vector (), 'EMPTY_E');
  if (DB.DBA.GQL_EDGES_T_RES (_r, 'rows_submitted') = 0 and DB.DBA.GQL_EDGES_T_PAIRS ('EMPTY_E', 'urn:gql:ve') = '')
    return 1;
  return 0;
}
;

select 99;
select DB.DBA.GQL_EDGES_T_V4 ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": V4 empty key arrays are a no-op\n";

-- V5: key arrays of different lengths are refused before any write.
select 99;
select case when DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_VECTOR_EDGE_INSERT (?, ?, ?, ?, ?, ?, ?, ?)',
    vector ('urn:gql:ve', 'Person', 'name', vector ('v0', 'v1'), 'Person', 'name', vector ('v1'), 'BAD_E')) like 'G4100 %'
  and DB.DBA.GQL_EDGES_T_PAIRS ('BAD_E', 'urn:gql:ve') = '' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": V5 key arrays of different lengths are G4100\n";

-- V6: a missing endpoint names its row, and no row of the call is written.
select 99;
select case when DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_VECTOR_EDGE_INSERT (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    vector ('urn:gql:ve', 'Person', 'name', vector ('v0', 'absent', 'v2'), 'Person', 'name', vector ('v1', 'v2', 'v3'), 'ATOMIC_E', 2))
    like 'G4101 %row 1 %'
  and DB.DBA.GQL_EDGES_T_PAIRS ('ATOMIC_E', 'urn:gql:ve') = '' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": V6 a missing source is G4101 for its row and writes nothing\n";

-- V7: the chunk size is bounded.
select 99;
select case when DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_VECTOR_EDGE_INSERT (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    vector ('urn:gql:ve', 'Person', 'name', vector ('v0'), 'Person', 'name', vector ('v1'), 'BAD_E', 4097)) like 'G4100 %'
  and DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_VECTOR_EDGE_INSERT (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    vector ('urn:gql:ve', 'Person', 'name', vector ('v0'), 'Person', 'name', vector ('v1'), 'BAD_E', 0)) like 'G4100 %'
  then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": V7 a chunk size outside 1..4096 is G4100\n";

-- V8: nothing is committed: the caller's rollback removes the edges.
create procedure DB.DBA.GQL_EDGES_T_V8 () returns integer
{
  DB.DBA.GQL_VECTOR_EDGE_INSERT ('urn:gql:ve', 'Person', 'name', vector ('v0'),
    'Person', 'name', vector ('v2'), 'ROLLBACK_E');
  rollback work;
  if (DB.DBA.GQL_EDGES_T_PAIRS ('ROLLBACK_E', 'urn:gql:ve') = '')
    return 1;
  return 0;
}
;

select 99;
select DB.DBA.GQL_EDGES_T_V8 ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": V8 the caller's rollback removes the edges\n";

-- V9: a key two nodes of the label share is refused, not one of them picked.
select 99;
select case when DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_VECTOR_EDGE_INSERT (?, ?, ?, ?, ?, ?, ?, ?)',
    vector ('urn:gql:ve', 'Person', 'name', vector ('v0', 'v1'), 'Person', 'name', vector ('v1', 'twin'), 'TWIN_E'))
    like 'G4103 %row 1 %'
  and DB.DBA.GQL_EDGES_T_PAIRS ('TWIN_E', 'urn:gql:ve') = '' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": V9 a key two nodes share is G4103 and writes nothing\n";

-- V10: a node of another label with the same key does not hide the node.
create procedure DB.DBA.GQL_EDGES_T_V10 () returns integer
{
  DB.DBA.GQL_VECTOR_EDGE_INSERT ('urn:gql:ve', 'Person', 'name', vector ('shadow'),
    'Person', 'name', vector ('v0'), 'SHADOW_E');
  commit work;
  if (DB.DBA.GQL_EDGES_T_COUNT ('MATCH (a:Person { name: ''shadow'' })-[:SHADOW_E]->(b:Person) RETURN a', 'urn:gql:ve') = 1
      and DB.DBA.GQL_EDGES_T_COUNT ('MATCH (a:Item)-[:SHADOW_E]->(b) RETURN a', 'urn:gql:ve') = 0)
    return 1;
  return 0;
}
;

select 99;
select DB.DBA.GQL_EDGES_T_V10 ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": V10 a same-key node of another label does not hide the endpoint\n";

-- V11: an endpoint is looked up in the target graph only.
select 99;
select case when DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_VECTOR_EDGE_INSERT (?, ?, ?, ?, ?, ?, ?, ?)',
    vector ('urn:gql:ve', 'Person', 'name', vector ('v0'), 'Person', 'name', vector ('elsewhere'), 'OTHER_E'))
    like 'G4102 %row 0 %'
  and DB.DBA.GQL_EDGES_T_COUNT ('MATCH (a)-[:OTHER_E]->(b) RETURN a', 'urn:gql:ve') = 0 then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": V11 a node of another graph is not an endpoint (G4102)\n";

-- V12: errors name the caller's row ordinals when given.
select 99;
select case when DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_VECTOR_EDGE_INSERT (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    vector ('urn:gql:ve', 'Person', 'name', vector ('v0', 'absent', 'v2'), 'Person', 'name', vector ('v1', 'v2', 'v3'), 'ORD_E', 2,
      vector (10, 20, 30))) like 'G4101 %row 20 %' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": V12 an error names the caller's row ordinal\n";

-- V13: in a property graph, labels and edge types are in its namespace.
create procedure DB.DBA.GQL_EDGES_T_V13 () returns integer
{
  declare _st, _msg varchar;
  declare _n integer;
  DB.DBA.GQL_PG_DROP ('EdgesPg', 1);
  _st := '00000'; _msg := '';
  exec ('DB.DBA.GQL_EXECUTE (?)', _st, _msg, vector ('CREATE PROPERTY GRAPH EdgesPg'));
  DB.DBA.GQL_RUN ('USE PROPERTY GRAPH EdgesPg INSERT (:Person { name: ''p1'' }), (:Person { name: ''p2'' })');
  DB.DBA.GQL_VECTOR_EDGE_INSERT (DB.DBA.GQL_PG_GRAPH_IRI ('EdgesPg'), 'Person', 'name', vector ('p1'),
    'Person', 'name', vector ('p2'), 'PG_E');
  commit work;
  _n := length (DB.DBA.GQL_RUN ('USE PROPERTY GRAPH EdgesPg MATCH (a:Person)-[:PG_E]->(b:Person) RETURN a.name'));
  DB.DBA.GQL_PG_DROP ('EdgesPg', 1);
  if (_n = 1)
    return 1;
  return 0;
}
;

select 99;
select DB.DBA.GQL_EDGES_T_V13 ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": V13 a property graph's edges use its namespaces\n";

-- V14: a virtual property graph is not writable (GQ213, as for INSERT).
insert into DB.DBA.GQL_PROPERTY_GRAPH_DEF (PG_NAME, PG_MODE, GRAPH_IRI, ONTOLOGY_NS, DATA_NS, CREATED)
  values ('EdgesVirt', 'virtual', 'urn:gql:ve:virt', 'urn:gql:ve:virt:ont#', 'urn:gql:ve:virt:data#', now ());

select 99;
select case when DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_VECTOR_EDGE_INSERT (?, ?, ?, ?, ?, ?, ?, ?)',
    vector ('urn:gql:ve:virt', 'Person', 'name', vector ('v0'), 'Person', 'name', vector ('v1'), 'VIRT_E')) like 'GQ213 %'
  then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": V14 a virtual property graph is GQ213\n";

delete from DB.DBA.GQL_PROPERTY_GRAPH_DEF where PG_NAME = 'EdgesVirt';

----------------------------------------------------------------------
-- GQL_STAGED_EDGE_INSERT: the same edges from rows of a staging table,
-- read in ordinal order in bounded pages; every row is validated before
-- the first edge is written.
----------------------------------------------------------------------

create table DB.DBA.GQL_EDGES_T_STAGE (ORD integer not null primary key, SRC varchar, DST varchar, ETYPE varchar);
create table DB.DBA.GQL_EDGES_T_STAGE_DUP (ORD integer, SRC varchar, DST varchar, ETYPE varchar);

create procedure DB.DBA.GQL_EDGES_T_STAGED (in _edge varchar, in _chunk integer) returns varchar
{
  return DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_STAGED_EDGE_INSERT (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    vector ('DB.DBA.GQL_EDGES_T_STAGE', 'ORD', 'SRC', 'DST', 'ETYPE', 'urn:gql:ve',
      'Person', 'name', 'Person', 'name', _edge, _chunk));
}
;

-- S1: three staged rows in pages of two.
create procedure DB.DBA.GQL_EDGES_T_S1 () returns integer
{
  declare _r any;
  delete from DB.DBA.GQL_EDGES_T_STAGE;
  insert into DB.DBA.GQL_EDGES_T_STAGE values (10, 'v0', 'v1', 'STAGED');
  insert into DB.DBA.GQL_EDGES_T_STAGE values (20, 'v1', 'v2', 'STAGED');
  insert into DB.DBA.GQL_EDGES_T_STAGE values (30, 'v2', 'v3', 'STAGED');
  commit work;
  _r := DB.DBA.GQL_STAGED_EDGE_INSERT ('DB.DBA.GQL_EDGES_T_STAGE', 'ORD', 'SRC', 'DST', 'ETYPE', 'urn:gql:ve',
    'Person', 'name', 'Person', 'name', 'STAGED', 2);
  commit work;
  if (DB.DBA.GQL_EDGES_T_PAIRS ('STAGED', 'urn:gql:ve') = 'v0>v1;v1>v2;v2>v3;'
      and DB.DBA.GQL_EDGES_T_RES (_r, 'rows_submitted') = 3
      and DB.DBA.GQL_EDGES_T_RES (_r, 'chunks_executed') = 2)
    return 1;
  return 0;
}
;

select 99;
select DB.DBA.GQL_EDGES_T_S1 ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": S1 three staged rows in pages of two write three edges\n";

-- S2: a missing endpoint names its staged ordinal; no row is written.
delete from DB.DBA.GQL_EDGES_T_STAGE;
insert into DB.DBA.GQL_EDGES_T_STAGE values (70, 'v0', 'v2', 'ATOMIC_S');
insert into DB.DBA.GQL_EDGES_T_STAGE values (75, 'absent', 'v3', 'ATOMIC_S');

select 99;
select case when DB.DBA.GQL_EDGES_T_STAGED ('ATOMIC_S', 1) like 'G4101 %row 75 %'
  and DB.DBA.GQL_EDGES_T_PAIRS ('ATOMIC_S', 'urn:gql:ve') = '' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": S2 a missing endpoint is G4101 for its ordinal and writes nothing\n";

-- S3: a row of another edge type is refused.
delete from DB.DBA.GQL_EDGES_T_STAGE;
insert into DB.DBA.GQL_EDGES_T_STAGE values (91, 'v0', 'v1', 'WRONG_TYPE');

select 99;
select case when DB.DBA.GQL_EDGES_T_STAGED ('EXPECTED_TYPE', 2) like 'G4202 %row 91 %' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": S3 a row of another edge type is G4202\n";

-- S4: a repeated ordinal is refused (keyset paging would skip a row).
insert into DB.DBA.GQL_EDGES_T_STAGE_DUP values (5, 'v0', 'v1', 'DUP_S');
insert into DB.DBA.GQL_EDGES_T_STAGE_DUP values (5, 'v1', 'v2', 'DUP_S');

select 99;
select case when DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_STAGED_EDGE_INSERT (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    vector ('DB.DBA.GQL_EDGES_T_STAGE_DUP', 'ORD', 'SRC', 'DST', 'ETYPE', 'urn:gql:ve',
      'Person', 'name', 'Person', 'name', 'DUP_S', 1)) like 'G4201 %ordinal 5%'
  and DB.DBA.GQL_EDGES_T_PAIRS ('DUP_S', 'urn:gql:ve') = '' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": S4 a repeated ordinal is G4201\n";

-- S5: nothing is committed.
create procedure DB.DBA.GQL_EDGES_T_S5 () returns integer
{
  delete from DB.DBA.GQL_EDGES_T_STAGE;
  insert into DB.DBA.GQL_EDGES_T_STAGE values (100, 'v0', 'v3', 'ROLLBACK_S');
  commit work;
  DB.DBA.GQL_STAGED_EDGE_INSERT ('DB.DBA.GQL_EDGES_T_STAGE', 'ORD', 'SRC', 'DST', 'ETYPE', 'urn:gql:ve',
    'Person', 'name', 'Person', 'name', 'ROLLBACK_S', 8);
  rollback work;
  if (DB.DBA.GQL_EDGES_T_PAIRS ('ROLLBACK_S', 'urn:gql:ve') = '')
    return 1;
  return 0;
}
;

select 99;
select DB.DBA.GQL_EDGES_T_S5 ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": S5 the caller's rollback removes staged edges\n";

-- S6: a column the table does not have is refused before any read.
select 99;
select case when DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_STAGED_EDGE_INSERT (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    vector ('DB.DBA.GQL_EDGES_T_STAGE', 'NO_SUCH_COLUMN', 'SRC', 'DST', 'ETYPE', 'urn:gql:ve',
      'Person', 'name', 'Person', 'name', 'X', 2)) like 'G4200 %' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": S6 a missing staging column is G4200\n";

----------------------------------------------------------------------
-- Opt-in (registry __gql_literal_vector = 'on'): a literal MATCH ... INSERT
-- of independent key-matched node pairs runs as one vectored lookup and
-- insert, with the results of the SPARQL route.  The connection variable
-- gql_literal_vector_dispatch says which route ran ('vector', 'fallback').
----------------------------------------------------------------------

create procedure DB.DBA.GQL_EDGES_T_VL_SETUP ()
{
  declare _rows any;
  declare _i integer;
  sparql clear graph <urn:gql:vl>;
  sparql clear graph <urn:gql:vl:other>;
  vectorbld_init (_rows);
  for (_i := 0; _i < 70; _i := _i + 1)
    vectorbld_acc (_rows, vector (vector ('nm', sprintf ('l%d', _i))));
  vectorbld_final (_rows);
  DB.DBA.GQL_BATCH_PARAMS (concat ('INSERT (:Person { name: ', chr (36), 'nm })'), 'urn:gql:vl', _rows);
  DB.DBA.GQL_RUN ('INSERT (:Person { name: ''twin'' }), (:Person { name: ''twin'' }), (:Person { name: ''Ωmega'' })', 'urn:gql:vl');
  DB.DBA.GQL_RUN ('INSERT (:Num { id: 1 }), (:Num { id: 2 }), (:Person { name: ''scored'', score: 1.5 })', 'urn:gql:vl');
  DB.DBA.GQL_RUN ('INSERT (:Person { name: ''elsewhere'' })', 'urn:gql:vl:other');
  commit work;
}
;

DB.DBA.GQL_EDGES_T_VL_SETUP ();

-- MATCH (s<k>:Person { name: ... }), (t<k>:Person { name: ... }) for each
-- pair of _pairs, INSERT (s<k>)-[:_edge]->(t<k>).
create procedure DB.DBA.GQL_EDGES_T_STMT (in _pairs any, in _edge varchar) returns varchar
{
  declare _m, _ins varchar;
  declare _k integer;
  _m := ''; _ins := '';
  for (_k := 0; _k < length (_pairs); _k := _k + 1)
    {
      _m := concat (_m, case when _k > 0 then ', ' else '' end,
        sprintf ('(s%d:Person { name: ''%s'' }), (t%d:Person { name: ''%s'' })', _k, aref (_pairs, _k, 0), _k, aref (_pairs, _k, 1)));
      _ins := concat (_ins, case when _k > 0 then ', ' else '' end, sprintf ('(s%d)-[:%s]->(t%d)', _k, _edge, _k));
    }
  return concat ('MATCH ', _m, ' INSERT ', _ins);
}
;

-- 'SQLSTATE route results' for _q through GQL_EXECUTE: route is the
-- dispatch it reports, results 'rows' if it returned a result set.
create procedure DB.DBA.GQL_EDGES_T_OPEN (in _q varchar, in _g varchar) returns varchar
{
  declare _st, _msg varchar;
  declare _meta, _data any;
  connection_set ('gql_literal_vector_dispatch', null);
  _st := '00000'; _msg := '';
  exec ('DB.DBA.GQL_EXECUTE (?, ?)', _st, _msg, vector (_q, _g), 100, _meta, _data);
  return concat (_st, ' ', coalesce (connection_get ('gql_literal_vector_dispatch'), 'none'), ' ',
    case when isarray (_meta) and length (_meta) > 0 and isarray (aref (_meta, 0)) and length (aref (_meta, 0)) > 0
      then 'rows' else 'norows' end);
}
;

-- 'route value' for _q through GQL_RUN.
create procedure DB.DBA.GQL_EDGES_T_RUN (in _q varchar, in _g varchar) returns varchar
{
  declare _r any;
  connection_set ('gql_literal_vector_dispatch', null);
  _r := DB.DBA.GQL_RUN (_q, _g);
  return concat (coalesce (connection_get ('gql_literal_vector_dispatch'), 'none'), ' ', cast (_r as varchar));
}
;

-- L1: by default the statement takes the SPARQL route.
select 99;
select case when DB.DBA.GQL_EDGES_T_OPEN (DB.DBA.GQL_EDGES_T_STMT (vector (vector ('l0', 'l1'), vector ('l2', 'l3'),
      vector ('l4', 'l5'), vector ('l6', 'l7'), vector ('l8', 'l9')), 'LF'), 'urn:gql:vl') = '00000 none norows'
  and DB.DBA.GQL_EDGES_T_PAIRS ('LF', 'urn:gql:vl') = 'l0>l1;l2>l3;l4>l5;l6>l7;l8>l9;' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L1 off by default: a five-edge statement takes the SPARQL route\n";

registry_set ('__gql_literal_vector', 'on');

-- L2: on, the same statement is vectored and writes the same edges.
select 99;
select case when DB.DBA.GQL_EDGES_T_OPEN (DB.DBA.GQL_EDGES_T_STMT (vector (vector ('l0', 'l1'), vector ('l2', 'l3'),
      vector ('l4', 'l5'), vector ('l6', 'l7'), vector ('l8', 'l9')), 'LV'), 'urn:gql:vl') = '00000 vector norows'
  and DB.DBA.GQL_EDGES_T_PAIRS ('LV', 'urn:gql:vl') = DB.DBA.GQL_EDGES_T_PAIRS ('LF', 'urn:gql:vl')
  and DB.DBA.GQL_EDGES_T_COUNT ('MATCH (a)-[:LF]->(b), (a)-[:LV]->(b) RETURN a', 'urn:gql:vl') = 5 then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L2 on: GQL_EXECUTE vectors it and writes the same edges\n";

-- L3: GQL_RUN too, returning the SPARQL route's triple count.
select 99;
select case when DB.DBA.GQL_EDGES_T_RUN (DB.DBA.GQL_EDGES_T_STMT (vector (vector ('l10', 'l11'), vector ('l12', 'l13')), 'LR'), 'urn:gql:vl') = 'vector 2'
  and DB.DBA.GQL_EDGES_T_PAIRS ('LR', 'urn:gql:vl') = 'l10>l11;l12>l13;' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L3 on: GQL_RUN vectors it and returns the triple count\n";

-- L4: a missing endpoint writes nothing and raises nothing, as SPARQL does.
select 99;
select case when DB.DBA.GQL_EDGES_T_OPEN (DB.DBA.GQL_EDGES_T_STMT (vector (vector ('l0', 'l1'), vector ('l2', 'absent')), 'LM'), 'urn:gql:vl') = '00000 vector norows'
  and DB.DBA.GQL_EDGES_T_RUN (DB.DBA.GQL_EDGES_T_STMT (vector (vector ('l0', 'l1'), vector ('l2', 'absent')), 'LM'), 'urn:gql:vl') = 'vector 0'
  and DB.DBA.GQL_EDGES_T_PAIRS ('LM', 'urn:gql:vl') = '' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L4 on: a missing endpoint writes no edge, as the SPARQL route\n";

-- L5: a key two nodes share takes the SPARQL route, which links both.
select 99;
select case when DB.DBA.GQL_EDGES_T_OPEN (DB.DBA.GQL_EDGES_T_STMT (vector (vector ('l0', 'twin')), 'LT'), 'urn:gql:vl') = '00000 fallback norows'
  and DB.DBA.GQL_EDGES_T_COUNT ('MATCH (a)-[:LT]->(b) RETURN b', 'urn:gql:vl') = 2 then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L5 on: a key two nodes share takes the SPARQL route\n";

-- L6: statements outside the shape take the SPARQL route unchanged: an edge
-- property, two edge types, a node no edge uses, a non-string, non-integer
-- key and a named edge.
select 99;
select case when DB.DBA.GQL_EDGES_T_OPEN ('MATCH (s:Person { name: ''l0'' }), (t:Person { name: ''l1'' }) INSERT (s)-[:LP { w: 1 }]->(t)', 'urn:gql:vl') = '00000 fallback norows'
  and DB.DBA.GQL_EDGES_T_COUNT ('MATCH (a)-[:LP]->(b) RETURN a', 'urn:gql:vl') = 1
  and DB.DBA.GQL_EDGES_T_OPEN ('MATCH (s0:Person { name: ''l0'' }), (t0:Person { name: ''l1'' }), (s1:Person { name: ''l2'' }), (t1:Person { name: ''l3'' }) INSERT (s0)-[:LA]->(t0), (s1)-[:LB]->(t1)', 'urn:gql:vl') = '00000 fallback norows'
  and DB.DBA.GQL_EDGES_T_PAIRS ('LA', 'urn:gql:vl') = 'l0>l1;' and DB.DBA.GQL_EDGES_T_PAIRS ('LB', 'urn:gql:vl') = 'l2>l3;'
  and DB.DBA.GQL_EDGES_T_OPEN ('MATCH (s0:Person { name: ''l0'' }), (t0:Person { name: ''l1'' }), (s1:Person { name: ''l2'' }), (x:Person { name: ''absent'' }) INSERT (s0)-[:LU]->(t0), (s1)-[:LU]->(t0)', 'urn:gql:vl') = '00000 fallback norows'
  and DB.DBA.GQL_EDGES_T_PAIRS ('LU', 'urn:gql:vl') = ''
  and DB.DBA.GQL_EDGES_T_OPEN ('MATCH (s:Person { name: ''l0'' }), (t:Person { score: 1.5 }) INSERT (s)-[:LS]->(t)', 'urn:gql:vl') = '00000 fallback norows'
  and DB.DBA.GQL_EDGES_T_PAIRS ('LS', 'urn:gql:vl') = 'l0>scored;'
  and DB.DBA.GQL_EDGES_T_OPEN ('MATCH (s:Person { name: ''l0'' }), (t:Person { name: ''l1'' }) INSERT (s)-[e:LE]->(t)', 'urn:gql:vl') = '00000 fallback norows'
  and DB.DBA.GQL_EDGES_T_PAIRS ('LE', 'urn:gql:vl') = 'l0>l1;' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L6 on: statements outside the shape take the SPARQL route\n";

-- L7: a node of another graph is not an endpoint (no edge, as SPARQL).
select 99;
select case when DB.DBA.GQL_EDGES_T_OPEN (DB.DBA.GQL_EDGES_T_STMT (vector (vector ('l0', 'elsewhere')), 'LO'), 'urn:gql:vl') = '00000 vector norows'
  and DB.DBA.GQL_EDGES_T_COUNT ('MATCH (a)-[:LO]->(b) RETURN a', 'urn:gql:vl') = 0 then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L7 on: a node of another graph is not an endpoint\n";

-- L8: nothing is committed.
create procedure DB.DBA.GQL_EDGES_T_L8 () returns integer
{
  declare _r varchar;
  _r := DB.DBA.GQL_EDGES_T_OPEN (DB.DBA.GQL_EDGES_T_STMT (vector (vector ('l0', 'l3'), vector ('l1', 'l4')), 'LRB'), 'urn:gql:vl');
  rollback work;
  if (_r = '00000 vector norows' and DB.DBA.GQL_EDGES_T_PAIRS ('LRB', 'urn:gql:vl') = '')
    return 1;
  return 0;
}
;

select 99;
select DB.DBA.GQL_EDGES_T_L8 ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L8 on: the caller's rollback removes the edges\n";

-- L9: running a statement again adds no edge; an edge given twice is one.
select 99;
select case when DB.DBA.GQL_EDGES_T_OPEN (DB.DBA.GQL_EDGES_T_STMT (vector (vector ('l0', 'l1'), vector ('l2', 'l3'),
      vector ('l4', 'l5'), vector ('l6', 'l7'), vector ('l8', 'l9')), 'LV'), 'urn:gql:vl') = '00000 vector norows'
  and DB.DBA.GQL_EDGES_T_COUNT ('MATCH (a)-[:LV]->(b) RETURN a', 'urn:gql:vl') = 5
  and DB.DBA.GQL_EDGES_T_OPEN (DB.DBA.GQL_EDGES_T_STMT (vector (vector ('l20', 'l21'), vector ('l20', 'l21')), 'LDUP'), 'urn:gql:vl') = '00000 vector norows'
  and DB.DBA.GQL_EDGES_T_PAIRS ('LDUP', 'urn:gql:vl') = 'l20>l21;' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L9 on: repeated and duplicated edges are written once\n";

-- L10: USE PROPERTY GRAPH: the property graph's namespaces; a virtual
-- property graph is GQ213, as on the SPARQL route.
create procedure DB.DBA.GQL_EDGES_T_L10 () returns integer
{
  declare _st, _msg, _r, _rv varchar;
  declare _n integer;
  DB.DBA.GQL_PG_DROP ('EdgesLPg', 1);
  _st := '00000'; _msg := '';
  exec ('DB.DBA.GQL_EXECUTE (?)', _st, _msg, vector ('CREATE PROPERTY GRAPH EdgesLPg'));
  DB.DBA.GQL_RUN ('USE PROPERTY GRAPH EdgesLPg INSERT (:Person { name: ''p1'' }), (:Person { name: ''p2'' })');
  commit work;
  _r := DB.DBA.GQL_EDGES_T_OPEN ('USE PROPERTY GRAPH EdgesLPg MATCH (s:Person { name: ''p1'' }), (t:Person { name: ''p2'' }) INSERT (s)-[:LPG]->(t)', null);
  _n := length (DB.DBA.GQL_RUN ('USE PROPERTY GRAPH EdgesLPg MATCH (a:Person)-[:LPG]->(b:Person) RETURN a.name'));
  DB.DBA.GQL_PG_DROP ('EdgesLPg', 1);
  insert into DB.DBA.GQL_PROPERTY_GRAPH_DEF (PG_NAME, PG_MODE, GRAPH_IRI, ONTOLOGY_NS, DATA_NS, CREATED)
    values ('EdgesLVirt', 'virtual', 'urn:gql:vl:virt', 'urn:gql:vl:virt:ont#', 'urn:gql:vl:virt:data#', now ());
  _rv := DB.DBA.GQL_EDGES_T_OPEN ('USE PROPERTY GRAPH EdgesLVirt MATCH (s:Person { name: ''p1'' }), (t:Person { name: ''p2'' }) INSERT (s)-[:LPG]->(t)', null);
  delete from DB.DBA.GQL_PROPERTY_GRAPH_DEF where PG_NAME = 'EdgesLVirt';
  commit work;
  if (_r = '00000 vector norows' and _n = 1 and _rv like 'GQ213 %')
    return 1;
  return 0;
}
;

select 99;
select DB.DBA.GQL_EDGES_T_L10 ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L10 on: property graph namespaces; a virtual one is GQ213\n";

-- L11: integer and non-ASCII keys are typed lookups.
select 99;
select case when DB.DBA.GQL_EDGES_T_OPEN ('MATCH (s:Num { id: 1 }), (t:Num { id: 2 }) INSERT (s)-[:LN]->(t)', 'urn:gql:vl') = '00000 vector norows'
  and DB.DBA.GQL_EDGES_T_PAIRS ('LN', 'urn:gql:vl', 'id') = '1>2;'
  and DB.DBA.GQL_EDGES_T_OPEN (DB.DBA.GQL_EDGES_T_STMT (vector (vector ('l0', 'Ωmega')), 'LU8'), 'urn:gql:vl') = '00000 vector norows'
  and DB.DBA.GQL_EDGES_T_PAIRS ('LU8', 'urn:gql:vl') = 'l0>Ωmega;' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L11 on: integer and non-ASCII keys\n";

-- L12: a statement with bound parameters takes the SPARQL route.
create procedure DB.DBA.GQL_EDGES_T_L12 () returns integer
{
  connection_set ('gql_literal_vector_dispatch', null);
  DB.DBA.GQL_PARAMS (concat ('MATCH (s:Person { name: ', chr (36), 'a }), (t:Person { name: ', chr (36), 'b }) INSERT (s)-[:LQ]->(t)'),
    'urn:gql:vl', vector (vector ('a', 'l0'), vector ('b', 'l1')));
  if (connection_get ('gql_literal_vector_dispatch') = 'fallback'
      and DB.DBA.GQL_EDGES_T_PAIRS ('LQ', 'urn:gql:vl') = 'l0>l1;')
    return 1;
  return 0;
}
;

select 99;
select DB.DBA.GQL_EDGES_T_L12 ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L12 on: a statement with parameters takes the SPARQL route\n";

-- L13: what it is for: five-edge statements with new literals each time
-- are compiled once each on the SPARQL route; the vectored route compiles
-- nothing.  Same statements, same run: at least ten times faster.
create procedure DB.DBA.GQL_EDGES_T_L13 () returns integer
{
  declare _t0, _t_off, _t_on, _i, _k integer;
  declare _p any;
  declare _q varchar;
  _t_off := 0; _t_on := 0;
  for (_i := 0; _i < 3; _i := _i + 1)
    {
      vectorbld_init (_p);
      for (_k := 0; _k < 5; _k := _k + 1)
        vectorbld_acc (_p, vector (sprintf ('l%d', 30 + 10 * _i + 2 * _k), sprintf ('l%d', 31 + 10 * _i + 2 * _k)));
      vectorbld_final (_p);
      registry_set ('__gql_literal_vector', 'off');
      _q := DB.DBA.GQL_EDGES_T_STMT (_p, 'LPERF_S');
      _t0 := msec_time ();
      DB.DBA.GQL_EXECUTE (_q, 'urn:gql:vl');
      _t_off := _t_off + msec_time () - _t0;
      registry_set ('__gql_literal_vector', 'on');
      _q := DB.DBA.GQL_EDGES_T_STMT (_p, 'LPERF_V');
      _t0 := msec_time ();
      DB.DBA.GQL_EXECUTE (_q, 'urn:gql:vl');
      _t_on := _t_on + msec_time () - _t0;
    }
  commit work;
  if (_t_off >= 10 * (_t_on + 1)
      and DB.DBA.GQL_EDGES_T_PAIRS ('LPERF_V', 'urn:gql:vl') = DB.DBA.GQL_EDGES_T_PAIRS ('LPERF_S', 'urn:gql:vl')
      and DB.DBA.GQL_EDGES_T_COUNT ('MATCH (a)-[:LPERF_V]->(b) RETURN a', 'urn:gql:vl') = 15)
    return 1;
  return 0;
}
;

select 99;
select DB.DBA.GQL_EDGES_T_L13 ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": L13 on: five-edge statements are ten times faster vectored\n";

registry_set ('__gql_literal_vector', 'off');

----------------------------------------------------------------------
-- Graph security: a user who may not write (or read) the graph gets the
-- error MATCH ... INSERT gives on the SPARQL route from every bulk path,
-- and nothing is written; a user who may write it uses them.
----------------------------------------------------------------------

create user GQL_EDGES_U;
grant SPARQL_SELECT to GQL_EDGES_U;
grant SPARQL_UPDATE to GQL_EDGES_U;
grant execute on DB.DBA.GQL_VECTOR_EDGE_INSERT to GQL_EDGES_U;
grant execute on DB.DBA.GQL_STAGED_EDGE_INSERT to GQL_EDGES_U;
grant execute on DB.DBA.GQL_RUN to GQL_EDGES_U;
grant execute on DB.DBA.GQL_EXECUTE to GQL_EDGES_U;
grant execute on DB.DBA.GQL_EDGES_T_STATE to GQL_EDGES_U;
grant execute on DB.DBA.GQL_EDGES_T_STMT to GQL_EDGES_U;
DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('GQL_EDGES_U', 0);
DB.DBA.RDF_GRAPH_USER_PERMS_SET ('urn:gql:ve', 'GQL_EDGES_U', 1);
registry_set ('__gql_literal_vector', 'on');

reconnect GQL_EDGES_U;

-- U1: may read, not write: RDF02 (write) from the vector API, the
-- vectored literal route and the SPARQL route (an edge with a property
-- always takes it) alike.
select 99;
select case when DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_VECTOR_EDGE_INSERT (?, ?, ?, ?, ?, ?, ?, ?)',
    vector ('urn:gql:ve', 'Person', 'name', vector ('v0'), 'Person', 'name', vector ('v1'), 'DENIED_E')) like 'RDF02 %no write permission%'
  and DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_EXECUTE (?, ?)',
    vector (DB.DBA.GQL_EDGES_T_STMT (vector (vector ('v0', 'v1'), vector ('v1', 'v2')), 'DENIED_E'), 'urn:gql:ve')) like 'RDF02 %no write permission%'
  and DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_RUN (?, ?)',
    vector ('MATCH (s:Person { name: ''v0'' }), (t:Person { name: ''v1'' }) INSERT (s)-[:DENIED_E { w: 1 }]->(t)', 'urn:gql:ve')) like 'RDF02 %no write permission%'
  then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": U1 a user who may not write gets RDF02 from every path\n";

-- Without the grant for the graph the user's default, no access, applies (a
-- grant narrower than the unauthenticated user's is refused, RDF99).
reconnect dba;
DB.DBA.RDF_GRAPH_USER_PERMS_DEL ('urn:gql:ve', 'GQL_EDGES_U');
reconnect GQL_EDGES_U;

-- U2: may not read: RDF02 (read) alike -- the lookups read the graph.  The
-- SPARQL route refuses it too, RDF02, in words that depend on its INSERT
-- template: with a fixed resource in it the target graph's read and write
-- rights are asserted before any row, and read is named; with none (an
-- edge's property holder is made for each row) the rows are filtered by the
-- read right and the insert is refused for want of the write right.
select 99;
select case when DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_VECTOR_EDGE_INSERT (?, ?, ?, ?, ?, ?, ?, ?)',
    vector ('urn:gql:ve', 'Person', 'name', vector ('v0'), 'Person', 'name', vector ('absent'), 'DENIED_E')) like 'RDF02 %no read permission%'
  and DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_EXECUTE (?, ?)',
    vector (DB.DBA.GQL_EDGES_T_STMT (vector (vector ('v0', 'v1'), vector ('v1', 'v2')), 'DENIED_E'), 'urn:gql:ve')) like 'RDF02 %no read permission%'
  and DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_RUN (?, ?)',
    vector ('MATCH (s:Person { name: ''v0'' }), (t:Person { name: ''v1'' }) INSERT (s)-[:DENIED_E { w: 1 }]->(t)', 'urn:gql:ve')) like 'RDF02 %no % permission%'
  then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": U2 a user who may not read gets RDF02 (read), not G4102\n";

reconnect dba;
DB.DBA.RDF_GRAPH_USER_PERMS_SET ('urn:gql:ve', 'GQL_EDGES_U', 3);
reconnect GQL_EDGES_U;

-- U3: may read and write: the vector API and the literal route run.
select 99;
select case when DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_VECTOR_EDGE_INSERT (?, ?, ?, ?, ?, ?, ?, ?)',
    vector ('urn:gql:ve', 'Person', 'name', vector ('v0'), 'Person', 'name', vector ('v3'), 'USER_E')) = '00000 '
  and DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_EXECUTE (?, ?)',
    vector (DB.DBA.GQL_EDGES_T_STMT (vector (vector ('v1', 'v3')), 'USER_E'), 'urn:gql:ve')) = '00000 '
  then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": U3 a user who may write the graph uses the bulk paths\n";

-- U4: the staging table is read with the user's rights.
select 99;
select case when DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_STAGED_EDGE_INSERT (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    vector ('DB.DBA.GQL_EDGES_T_STAGE', 'ORD', 'SRC', 'DST', 'ETYPE', 'urn:gql:ve',
      'Person', 'name', 'Person', 'name', 'USER_S', 2)) like 'G4200 %' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": U4 a staging table the user may not read is G4200\n";

reconnect dba;
delete from DB.DBA.GQL_EDGES_T_STAGE;
insert into DB.DBA.GQL_EDGES_T_STAGE values (1, 'v2', 'v4', 'USER_S');
grant select on DB.DBA.GQL_EDGES_T_STAGE to GQL_EDGES_U;
reconnect GQL_EDGES_U;

-- U5: one it may read is loaded.
select 99;
select case when DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_STAGED_EDGE_INSERT (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    vector ('DB.DBA.GQL_EDGES_T_STAGE', 'ORD', 'SRC', 'DST', 'ETYPE', 'urn:gql:ve',
      'Person', 'name', 'Person', 'name', 'USER_S', 2)) = '00000 ' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": U5 a staging table the user may read is loaded\n";

reconnect dba;
registry_set ('__gql_literal_vector', 'off');

-- U6: what the refused calls left: nothing; what the allowed ones wrote.
select 99;
select case when DB.DBA.GQL_EDGES_T_PAIRS ('DENIED_E', 'urn:gql:ve') = ''
  and DB.DBA.GQL_EDGES_T_PAIRS ('USER_E', 'urn:gql:ve') = 'v0>v3;v1>v3;'
  and DB.DBA.GQL_EDGES_T_PAIRS ('USER_S', 'urn:gql:ve') = 'v2>v4;' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": U6 refused calls wrote nothing; allowed ones wrote their edges\n";

-- U7: the graph permissions without the right to update the quad store
-- (SPARQL_SELECT, not SPARQL_UPDATE): the SPARQL route refuses (42000), and
-- so does every bulk path; nothing is written.
create user GQL_EDGES_RO;
grant SPARQL_SELECT to GQL_EDGES_RO;
grant execute on DB.DBA.GQL_VECTOR_EDGE_INSERT to GQL_EDGES_RO;
grant execute on DB.DBA.GQL_STAGED_EDGE_INSERT to GQL_EDGES_RO;
grant execute on DB.DBA.GQL_RUN to GQL_EDGES_RO;
grant execute on DB.DBA.GQL_EXECUTE to GQL_EDGES_RO;
grant execute on DB.DBA.GQL_EDGES_T_STATE to GQL_EDGES_RO;
grant execute on DB.DBA.GQL_EDGES_T_STMT to GQL_EDGES_RO;
grant select on DB.DBA.GQL_EDGES_T_STAGE to GQL_EDGES_RO;
DB.DBA.RDF_GRAPH_USER_PERMS_SET ('urn:gql:ve', 'GQL_EDGES_RO', 3);
delete from DB.DBA.GQL_EDGES_T_STAGE;
insert into DB.DBA.GQL_EDGES_T_STAGE values (2, 'v3', 'v4', 'RO_E');
registry_set ('__gql_literal_vector', 'on');

reconnect GQL_EDGES_RO;

select 99;
select case when DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_RUN (?, ?)',
    vector ('MATCH (s:Person { name: ''v0'' }), (t:Person { name: ''v1'' }) INSERT (s)-[:RO_E { w: 1 }]->(t)', 'urn:gql:ve')) like '42000 %'
  and DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_VECTOR_EDGE_INSERT (?, ?, ?, ?, ?, ?, ?, ?)',
    vector ('urn:gql:ve', 'Person', 'name', vector ('v0'), 'Person', 'name', vector ('v1'), 'RO_E')) like '42000 %'
  and DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_EXECUTE (?, ?)',
    vector (DB.DBA.GQL_EDGES_T_STMT (vector (vector ('v1', 'v2')), 'RO_E'), 'urn:gql:ve')) like '42000 %'
  and DB.DBA.GQL_EDGES_T_STATE ('DB.DBA.GQL_STAGED_EDGE_INSERT (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    vector ('DB.DBA.GQL_EDGES_T_STAGE', 'ORD', 'SRC', 'DST', 'ETYPE', 'urn:gql:ve',
      'Person', 'name', 'Person', 'name', 'RO_E', 2)) like '42000 %'
  then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": U7 a user who may not update the quad store is refused by every path\n";

reconnect dba;
registry_set ('__gql_literal_vector', 'off');

select 99;
select case when DB.DBA.GQL_EDGES_T_PAIRS ('RO_E', 'urn:gql:ve') = '' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": U8 the refused calls wrote nothing\n";

DB.DBA.RDF_GRAPH_USER_PERMS_DEL ('urn:gql:ve', 'GQL_EDGES_RO');
DB.DBA.USER_DROP ('GQL_EDGES_RO', 1);
DB.DBA.RDF_GRAPH_USER_PERMS_DEL ('urn:gql:ve', 'GQL_EDGES_U');
DB.DBA.RDF_DEFAULT_USER_PERMS_DEL ('GQL_EDGES_U');
DB.DBA.USER_DROP ('GQL_EDGES_U', 1);
drop table DB.DBA.GQL_EDGES_T_STAGE;
drop table DB.DBA.GQL_EDGES_T_STAGE_DUP;

ECHO "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: GQL edge insertion tests\n";

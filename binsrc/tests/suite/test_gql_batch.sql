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
--  GQL for Virtuoso - DML batch and prepared DML tests
--
--  GQL_BATCH_PARAMS runs one DML template for many rows of named
--  parameter values: it is translated once and executed as a few compiled
--  statements, each binding a bounded number of rows.  GQL_PREPARED_DML_PARAMS
--  does the same for one row.  Nodes and edges a template creates get fresh
--  IRIs for every row.
--
--  Run via isql: isql <host>:<port> dba dba test_gql_batch.sql
--

ECHO "STARTED: GQL DML batch tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

-- Rows of (name, value) pairs: vector (vector ('nm', 'a'), ...) per row.
create procedure DB.DBA.GQL_BATCH_T_ROWS (in _n integer, in _prefix varchar) returns any
{
  declare _rows any;
  declare _i integer;
  vectorbld_init (_rows);
  for (_i := 0; _i < _n; _i := _i + 1)
    vectorbld_acc (_rows, vector (vector ('nm', sprintf ('%s-%d', _prefix, _i)), vector ('ag', 20 + _i)));
  vectorbld_final (_rows);
  return _rows;
}
;

create procedure DB.DBA.GQL_BATCH_T_COUNT (in _q varchar, in _g varchar) returns integer
{
  declare _r any;
  _r := DB.DBA.GQL_RUN (_q, _g);
  if (not isarray (_r))
    return 0;
  return length (_r);
}
;

-- B1: one template inserts 50 independently bound nodes.
create procedure DB.DBA.GQL_BATCH_T_BASIC () returns integer
{
  sparql clear graph <urn:gql:b1>;
  commit work;
  DB.DBA.GQL_BATCH_PARAMS (concat ('INSERT (:Person { name: ', chr (36), 'nm, age: ', chr (36), 'ag })'),
    'urn:gql:b1', DB.DBA.GQL_BATCH_T_ROWS (50, 'b1'));
  commit work;
  if (DB.DBA.GQL_BATCH_T_COUNT ('MATCH (p:Person) RETURN p.name', 'urn:gql:b1') = 50
      and DB.DBA.GQL_BATCH_T_COUNT ('MATCH (p:Person { name: ''b1-7'' }) WHERE p.age = 27 RETURN p', 'urn:gql:b1') = 1)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_BATCH_T_BASIC ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": B1 a template inserts 50 independently bound nodes\n";

-- B2: a successful batch does not commit behind the caller.
create procedure DB.DBA.GQL_BATCH_T_ROLLBACK () returns integer
{
  declare _n integer;
  set isolation = 'serializable';
  sparql clear graph <urn:gql:b2>;
  commit work;
  DB.DBA.GQL_BATCH_PARAMS (concat ('INSERT (:Person { name: ', chr (36), 'nm, age: ', chr (36), 'ag })'),
    'urn:gql:b2', DB.DBA.GQL_BATCH_T_ROWS (3, 'b2'));
  rollback work;
  _n := DB.DBA.GQL_BATCH_T_COUNT ('MATCH (p:Person) RETURN p.name', 'urn:gql:b2');
  if (_n = 0)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_BATCH_T_ROLLBACK ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": B2 an outer ROLLBACK undoes a successful batch\n";

-- B3: a later row missing a parameter fails the batch and leaves none of
-- the earlier rows written - also when they were in an earlier chunk.
create procedure DB.DBA.GQL_BATCH_T_ATOMIC () returns integer
{
  declare _rows any;
  declare _caught varchar;
  set isolation = 'serializable';
  sparql clear graph <urn:gql:b3>;
  commit work;
  _rows := vector_concat (DB.DBA.GQL_BATCH_T_ROWS (450, 'b3'), vector (vector (vector ('nm', 'missing-age'))));
  _caught := '00000';
  {
    declare exit handler for sqlstate '*' { _caught := __SQL_STATE; goto failed; };
    DB.DBA.GQL_BATCH_PARAMS (concat ('INSERT (:Person { name: ', chr (36), 'nm, age: ', chr (36), 'ag })'),
      'urn:gql:b3', _rows);
  }
failed:
  if (_caught = 'G4011'
      and DB.DBA.GQL_BATCH_T_COUNT ('MATCH (p:Person) RETURN p.name', 'urn:gql:b3') = 0)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_BATCH_T_ATOMIC ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": B3 a failed row leaves no row of the batch written\n";

-- B4: MATCH ... INSERT edges, each row binding its own endpoints.
create procedure DB.DBA.GQL_BATCH_T_EDGES () returns integer
{
  sparql clear graph <urn:gql:b4>;
  commit work;
  DB.DBA.GQL_BATCH_PARAMS (concat ('INSERT (:Person { name: ', chr (36), 'nm })'), 'urn:gql:b4',
    vector (vector (vector ('nm', 'e-a')), vector (vector ('nm', 'e-b')),
            vector (vector ('nm', 'e-c')), vector (vector ('nm', 'e-d'))));
  DB.DBA.GQL_BATCH_PARAMS (
    concat ('MATCH (a:Person { name: ', chr (36), 'src }), (b:Person { name: ', chr (36), 'dst }) INSERT (a)-[:KNOWS]->(b)'),
    'urn:gql:b4',
    vector (vector (vector ('src', 'e-a'), vector ('dst', 'e-b')),
            vector (vector ('src', 'e-b'), vector ('dst', 'e-c')),
            vector (vector ('src', 'e-c'), vector ('dst', 'e-d'))));
  commit work;
  if (DB.DBA.GQL_BATCH_T_COUNT ('MATCH (a:Person)-[:KNOWS]->(b:Person) RETURN a.name, b.name', 'urn:gql:b4') = 3
      and DB.DBA.GQL_BATCH_T_COUNT ('MATCH (a:Person { name: ''e-b'' })-[:KNOWS]->(b:Person { name: ''e-c'' }) RETURN a', 'urn:gql:b4') = 1)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_BATCH_T_EDGES ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": B4 a MATCH ... INSERT template binds each row's endpoints\n";

-- B5: batches larger than one statement may bind run in bounded chunks:
-- 450 rows of 2 parameters (200 rows a statement), and 250 rows of 5
-- (exactly 1000 bind markers a statement).
create procedure DB.DBA.GQL_BATCH_T_CHUNKS () returns integer
{
  declare _rows any;
  declare _i integer;
  sparql clear graph <urn:gql:b5>;
  commit work;
  DB.DBA.GQL_BATCH_PARAMS (concat ('INSERT (:Person { name: ', chr (36), 'nm, age: ', chr (36), 'ag })'),
    'urn:gql:b5', DB.DBA.GQL_BATCH_T_ROWS (450, 'two'));
  vectorbld_init (_rows);
  for (_i := 0; _i < 250; _i := _i + 1)
    vectorbld_acc (_rows, vector (vector ('a', sprintf ('five-%d', _i)), vector ('b', _i), vector ('c', 'x'),
      vector ('d', 'y'), vector ('e', 'z')));
  vectorbld_final (_rows);
  DB.DBA.GQL_BATCH_PARAMS (concat ('INSERT (:Wide { a: ', chr (36), 'a, b: ', chr (36), 'b, c: ', chr (36),
    'c, d: ', chr (36), 'd, e: ', chr (36), 'e })'), 'urn:gql:b5', _rows);
  commit work;
  if (DB.DBA.GQL_BATCH_T_COUNT ('MATCH (p:Person) RETURN p.name', 'urn:gql:b5') = 450
      and DB.DBA.GQL_BATCH_T_COUNT ('MATCH (w:Wide) RETURN w.a', 'urn:gql:b5') = 250)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_BATCH_T_CHUNKS ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": B5 large batches run in bounded chunks (450 x 2 and 250 x 5 parameters)\n";

-- B6: a template with more parameters than one statement may bind is
-- refused with an explicit error.
create procedure DB.DBA.GQL_BATCH_T_TOO_WIDE () returns varchar
{
  declare _ses any;
  declare _i integer;
  declare _row any;
  declare exit handler for sqlstate '*' { return __SQL_STATE; };
  _ses := string_output ();
  http ('INSERT (:Huge { k0: ', _ses);
  http (concat (chr (36), 'p0'), _ses);
  vectorbld_init (_row);
  vectorbld_acc (_row, vector ('p0', 0));
  for (_i := 1; _i < 1001; _i := _i + 1)
    {
      http (sprintf (', k%d: %sp%d', _i, chr (36), _i), _ses);
      vectorbld_acc (_row, vector (sprintf ('p%d', _i), _i));
    }
  vectorbld_final (_row);
  http (' })', _ses);
  DB.DBA.GQL_BATCH_PARAMS (string_output_string (_ses), 'urn:gql:b6', vector (_row));
  return '00000';
}
;

select 0;
select DB.DBA.GQL_BATCH_T_TOO_WIDE ();
ECHO $IF $EQU $LAST[1] "G4013" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": B6 a template with 1001 parameters is refused (" $LAST[1] ")\n";

-- B7: nodes a batch creates in a property graph get IRIs in that graph's
-- data namespace, as a single INSERT does.
create procedure DB.DBA.GQL_BATCH_T_PG_NAMESPACE () returns integer
{
  declare _st, _msg varchar;
  declare _ns, _g varchar;
  declare _meta, _data any;
  DB.DBA.GQL_PG_DROP ('BatchPg', 1);
  exec ('DB.DBA.GQL_EXECUTE (?)', _st, _msg, vector ('CREATE PROPERTY GRAPH BatchPg'));
  _g := DB.DBA.GQL_PG_GRAPH_IRI ('BatchPg');
  _ns := DB.DBA.GQL_PG_DATA_NS ('BatchPg');
  DB.DBA.GQL_BATCH_PARAMS (concat ('USE PROPERTY GRAPH BatchPg INSERT (:Person { name: ', chr (36), 'nm })'),
    null, vector (vector (vector ('nm', 'pg-a')), vector (vector ('nm', 'pg-b'))));
  commit work;
  _st := '00000';
  exec (sprintf ('sparql select count (*) from <%s> where { ?s ?p ?o . filter (strstarts (str (?s), "%s")) }', _g, _ns),
    _st, _msg, vector (), 0, _meta, _data);
  DB.DBA.GQL_PG_DROP ('BatchPg', 1);
  if (_st = '00000' and isarray (_data) and aref (_data, 0, 0) >= 4)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_BATCH_T_PG_NAMESPACE ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": B7 a batch into a property graph mints IRIs in its data namespace\n";

-- B8: an edge with properties is a reified statement; each row of a batch
-- gets its own, carrying that row's property value.
create procedure DB.DBA.GQL_BATCH_T_EDGE_PROPS () returns integer
{
  declare _r any;
  sparql clear graph <urn:gql:b8>;
  commit work;
  DB.DBA.GQL_BATCH_PARAMS (concat ('INSERT (:Person { name: ', chr (36), 'nm })'), 'urn:gql:b8',
    vector (vector (vector ('nm', 'w-a')), vector (vector ('nm', 'w-b')), vector (vector ('nm', 'w-c'))));
  DB.DBA.GQL_BATCH_PARAMS (
    concat ('MATCH (a:Person { name: ', chr (36), 'src }), (b:Person { name: ', chr (36), 'dst }) ',
      'INSERT (a)-[:RATED { weight: ', chr (36), 'w }]->(b)'),
    'urn:gql:b8',
    vector (vector (vector ('src', 'w-a'), vector ('dst', 'w-b'), vector ('w', 1)),
            vector (vector ('src', 'w-b'), vector ('dst', 'w-c'), vector ('w', 2)),
            vector (vector ('src', 'w-c'), vector ('dst', 'w-a'), vector ('w', 3))));
  commit work;
  -- (Aliases that differ from the variable names: RETURN a.name AS a reads
  -- the alias, not the node -- a separate translator defect.)
  _r := DB.DBA.GQL_RUN ('MATCH (a:Person)-[r:RATED]->(b:Person) RETURN a.name AS src, r.weight AS w ORDER BY src', 'urn:gql:b8');
  if (isarray (_r) and length (_r) = 3
      and aref (_r, 0, 0) = 'w-a' and cast (aref (_r, 0, 1) as integer) = 1
      and aref (_r, 1, 0) = 'w-b' and cast (aref (_r, 1, 1) as integer) = 2
      and aref (_r, 2, 0) = 'w-c' and cast (aref (_r, 2, 1) as integer) = 3)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_BATCH_T_EDGE_PROPS ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": B8 each row's property-bearing edge gets its own statement\n";

-- B10: a statement that translates to several SPARQL statements (SET plus
-- REMOVE) runs as one GQL statement.  Each is executed on its own, so each
-- needs the SPARQL keyword and the PREFIX lines the translator writes once.
create procedure DB.DBA.GQL_BATCH_T_SEVERAL_SCALAR () returns integer
{
  declare _r any;
  sparql clear graph <urn:gql:b10>;
  commit work;
  DB.DBA.GQL_RUN ('INSERT (:Person { name: ''t-a'', age: 1, x: 1 })', 'urn:gql:b10');
  DB.DBA.GQL_RUN ('MATCH (n:Person { name: ''t-a'' }) SET n.age = 10 REMOVE n.x', 'urn:gql:b10');
  commit work;
  _r := DB.DBA.GQL_RUN ('MATCH (n:Person) RETURN n.age AS ag', 'urn:gql:b10');
  if (isarray (_r) and length (_r) = 1 and cast (aref (_r, 0, 0) as integer) = 10
      and DB.DBA.GQL_BATCH_T_COUNT ('MATCH (n:Person) RETURN n.x', 'urn:gql:b10') = 0)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_BATCH_T_SEVERAL_SCALAR ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": B10 SET ... REMOVE, two SPARQL statements, runs as one GQL statement\n";

-- B9: a template that translates to several SPARQL statements (SET plus
-- REMOVE) runs them row by row, each binding its own parameters.
create procedure DB.DBA.GQL_BATCH_T_SEVERAL () returns integer
{
  declare _r any;
  sparql clear graph <urn:gql:b9>;
  commit work;
  DB.DBA.GQL_RUN ('INSERT (:Person { name: ''s-a'', age: 1, x: 1 }), (:Person { name: ''s-b'', age: 2, x: 2 }), (:Person { name: ''s-c'', age: 3, x: 3 })', 'urn:gql:b9');
  commit work;
  DB.DBA.GQL_BATCH_PARAMS (
    concat ('MATCH (n:Person { name: ', chr (36), 'nm }) SET n.age = ', chr (36), 'ag REMOVE n.x'), 'urn:gql:b9',
    vector (vector (vector ('nm', 's-a'), vector ('ag', 10)),
            vector (vector ('nm', 's-b'), vector ('ag', 20)),
            vector (vector ('nm', 's-c'), vector ('ag', 30))));
  commit work;
  _r := DB.DBA.GQL_RUN ('MATCH (n:Person) RETURN n.name AS nm, n.age AS ag ORDER BY nm', 'urn:gql:b9');
  if (isarray (_r) and length (_r) = 3
      and cast (aref (_r, 0, 1) as integer) = 10 and cast (aref (_r, 1, 1) as integer) = 20
      and cast (aref (_r, 2, 1) as integer) = 30
      and DB.DBA.GQL_BATCH_T_COUNT ('MATCH (n:Person) RETURN n.x', 'urn:gql:b9') = 0)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_BATCH_T_SEVERAL ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": B9 a several-statement template runs row by row\n";

-- ------------------------------------------------------------------
-- D1-D6: prepared single-row DML, GQL_PREPARED_DML_PLAN /
-- GQL_PREPARED_DML_PARAMS.
-- ------------------------------------------------------------------

-- D1: one DML template, translated once: other values bind to the same
-- statement; nothing the caller supplies is written into its text.
create procedure DB.DBA.GQL_BATCH_T_PREPARED_DML () returns integer
{
  declare _q, _s1, _s2 varchar;
  declare _v1, _v2 any;
  _q := concat ('MATCH (a:Person { name: ', chr (36), 'src }), (b:Person { name: ', chr (36), 'dst }) INSERT (a)-[:KNOWS]->(b)');
  DB.DBA.GQL_PREPARED_DML_PLAN (_q, 'urn:gql:d1', vector (vector ('src', 'p-a'), vector ('dst', 'p-b')), _s1, _v1);
  DB.DBA.GQL_PREPARED_DML_PLAN (_q, 'urn:gql:d1', vector (vector ('src', 'O''Reilly } UNION { ?s ?p ?o } #'), vector ('dst', 'p-d')), _s2, _v2);
  if (strstr (_s1, '??') is not null and strstr (_s1, 'p-a') is null and _s1 = _s2
      and aref (_v1, 0) = 'p-a' and aref (_v2, 0) = 'O''Reilly } UNION { ?s ?p ?o } #' and strstr (_s2, 'UNION { ?s') is null)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_BATCH_T_PREPARED_DML ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": D1 a prepared DML template binds its values\n";

-- D2: an anonymous-node INSERT prepared once still makes a new node each
-- time it runs.
create procedure DB.DBA.GQL_BATCH_T_PREPARED_FRESH () returns integer
{
  declare _q varchar;
  sparql clear graph <urn:gql:d2>;
  commit work;
  _q := concat ('INSERT (:Person { name: ', chr (36), 'nm })');
  DB.DBA.GQL_PREPARED_DML_PARAMS (_q, 'urn:gql:d2', vector (vector ('nm', 'same')));
  DB.DBA.GQL_PREPARED_DML_PARAMS (_q, 'urn:gql:d2', vector (vector ('nm', 'same')));
  commit work;
  if (DB.DBA.GQL_BATCH_T_COUNT ('MATCH (p:Person { name: ''same'' }) RETURN p', 'urn:gql:d2') = 2)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_BATCH_T_PREPARED_FRESH ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": D2 a prepared anonymous-node INSERT makes a new node each run\n";

-- D3: integer and NULL values keep their types.
create procedure DB.DBA.GQL_BATCH_T_PREPARED_TYPES () returns integer
{
  declare _s varchar;
  declare _v any;
  DB.DBA.GQL_PREPARED_DML_PLAN (concat ('INSERT (:Value { name: ', chr (36), 'name, rank: ', chr (36), 'rank })'),
    'urn:gql:d3', vector (vector ('name', null), vector ('rank', 7)), _s, _v);
  if (aref (_v, 0) is null and __tag (aref (_v, 1)) = __tag (7))
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_BATCH_T_PREPARED_TYPES ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": D3 prepared DML values keep their types\n";

-- D4: a read template and missing or unknown parameters are refused.
create procedure DB.DBA.GQL_BATCH_T_PREPARED_BAD (in _case integer) returns varchar
{
  declare _s varchar;
  declare _v any;
  declare exit handler for sqlstate '*' { return __SQL_STATE; };
  if (_case = 1)
    DB.DBA.GQL_PREPARED_DML_PLAN (concat ('MATCH (n) WHERE n.name = ', chr (36), 'nm RETURN n'), 'urn:gql:d4',
      vector (vector ('nm', 'x')), _s, _v);
  else if (_case = 2)
    DB.DBA.GQL_PREPARED_DML_PLAN (concat ('INSERT (:P { a: ', chr (36), 'a, b: ', chr (36), 'b })'), 'urn:gql:d4',
      vector (vector ('a', 1)), _s, _v);
  else
    DB.DBA.GQL_PREPARED_DML_PLAN (concat ('INSERT (:P { a: ', chr (36), 'a })'), 'urn:gql:d4',
      vector (vector ('a', 1), vector ('zz', 2)), _s, _v);
  return '00000';
}
;

select 0;
select case when DB.DBA.GQL_BATCH_T_PREPARED_BAD (1) = 'G4012' and DB.DBA.GQL_BATCH_T_PREPARED_BAD (2) = 'G4011'
  and DB.DBA.GQL_BATCH_T_PREPARED_BAD (3) = 'G4010' then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": D4 a read template and missing or unknown parameters are refused\n";

-- D5: prepared DML stays inside the caller's transaction.
create procedure DB.DBA.GQL_BATCH_T_PREPARED_TXN () returns integer
{
  set isolation = 'serializable';
  sparql clear graph <urn:gql:d5>;
  commit work;
  DB.DBA.GQL_PREPARED_DML_PARAMS (concat ('INSERT (:Person { name: ', chr (36), 'nm })'), 'urn:gql:d5',
    vector (vector ('nm', 'gone')));
  rollback work;
  if (DB.DBA.GQL_BATCH_T_COUNT ('MATCH (p:Person) RETURN p', 'urn:gql:d5') = 0)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_BATCH_T_PREPARED_TXN ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": D5 an outer ROLLBACK undoes prepared DML\n";

-- B11/D6: SET translates to an update whose WHERE is a sub-select, which
-- binds the new value inside it.  A batch and prepared DML must give each
-- row its value there: SET replaces the property, it never only deletes it.
create procedure DB.DBA.GQL_BATCH_T_SET_SETUP (in _g varchar)
{
  exec (sprintf ('sparql clear graph <%s>', _g));
  DB.DBA.GQL_RUN ('INSERT (:Product { id: ''s1'', price: 10 }), (:Product { id: ''s2'', price: 20 }), (:Product { id: ''s3'', price: 30 })', _g);
  commit work;
}
;

create procedure DB.DBA.GQL_BATCH_T_PRICES (in _g varchar) returns varchar
{
  declare _r any;
  declare _s varchar;
  declare _i integer;
  _r := DB.DBA.GQL_RUN ('MATCH (p:Product) RETURN p.id AS pid, p.price AS pr ORDER BY pid', _g);
  _s := '';
  if (isarray (_r))
    for (_i := 0; _i < length (_r); _i := _i + 1)
      _s := concat (_s, cast (aref (_r, _i, 0) as varchar), '=', cast (aref (_r, _i, 1) as varchar), ';');
  return _s;
}
;

create procedure DB.DBA.GQL_BATCH_T_SET_BATCH () returns varchar
{
  DB.DBA.GQL_BATCH_T_SET_SETUP ('urn:gql:b11');
  DB.DBA.GQL_BATCH_PARAMS (concat ('MATCH (p:Product { id: ', chr (36), 'id }) SET p.price = ', chr (36), 'pr'), 'urn:gql:b11',
    vector (vector (vector ('id', 's1'), vector ('pr', 11)),
            vector (vector ('id', 's3'), vector ('pr', 33))));
  commit work;
  return DB.DBA.GQL_BATCH_T_PRICES ('urn:gql:b11');
}
;

select 0;
select DB.DBA.GQL_BATCH_T_SET_BATCH ();
ECHO $IF $EQU $LAST[1] "s1=11;s2=20;s3=33;" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": B11 a batch SET gives each row its value (" $LAST[1] ")\n";

create procedure DB.DBA.GQL_BATCH_T_SET_PREPARED () returns varchar
{
  DB.DBA.GQL_BATCH_T_SET_SETUP ('urn:gql:d6');
  DB.DBA.GQL_PREPARED_DML_PARAMS (concat ('MATCH (p:Product { id: ', chr (36), 'id }) SET p.price = ', chr (36), 'pr'), 'urn:gql:d6',
    vector (vector ('id', 's2'), vector ('pr', 22)));
  commit work;
  return DB.DBA.GQL_BATCH_T_PRICES ('urn:gql:d6');
}
;

select 0;
select DB.DBA.GQL_BATCH_T_SET_PREPARED ();
ECHO $IF $EQU $LAST[1] "s1=10;s2=22;s3=30;" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": D6 a prepared SET replaces the value (" $LAST[1] ")\n";

ECHO "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: GQL DML batch tests\n";

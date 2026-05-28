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
--  openCypher openCypher 2024.3 smoke tests
--
--  These tests are intentionally small. They make the current compliance
--  boundary visible while full TCK coverage is being ported.
--

create procedure DB.DBA.OPENCYPHER_OC24_FAIL (in _msg varchar)
{
  signal ('OC240', _msg);
}
;

create procedure DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (in _name varchar, in _query varchar, in _expected varchar)
{
  declare state, msg varchar;
  declare meta, data any;

  state := '00000';
  msg := '';
  exec ('SELECT DB.DBA.CYPHER_TO_SPARQL (?)', state, msg, vector (_query), 0, meta, data);

  if (state = '00000')
    DB.DBA.OPENCYPHER_OC24_FAIL (sprintf ('%s expected an error containing "%s"', _name, _expected));

  if (strstr (msg, _expected) is null)
    DB.DBA.OPENCYPHER_OC24_FAIL (sprintf ('%s expected error containing "%s", got "%s"', _name, _expected, msg));
}
;

create procedure DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (in _name varchar, in _query varchar, in _expected varchar)
{
  declare out_s varchar;
  out_s := DB.DBA.CYPHER_TO_SPARQL (_query);
  if (strstr (out_s, _expected) is null)
    DB.DBA.OPENCYPHER_OC24_FAIL (sprintf ('%s expected translation containing "%s"', _name, _expected));
}
;

create procedure DB.DBA.OPENCYPHER_OC24_EXPECT_NO_TRANSLATION (in _name varchar, in _query varchar, in _unexpected varchar)
{
  declare out_s varchar;
  out_s := DB.DBA.CYPHER_TO_SPARQL (_query);
  if (strstr (out_s, _unexpected) is not null)
    DB.DBA.OPENCYPHER_OC24_FAIL (sprintf ('%s expected translation not containing "%s"', _name, _unexpected));
}
;

create procedure DB.DBA.OPENCYPHER_OC24_EXPECT_PLAN_OP (in _name varchar, in _query varchar, in _op varchar)
{
  declare plan, ops, item any;
  declare i integer;

  plan := DB.DBA.CYPHER_PLAN (_query);
  if (aref (plan, 0) <> 'PLAN')
    DB.DBA.OPENCYPHER_OC24_FAIL (sprintf ('%s expected PLAN root', _name));

  ops := aref (plan, 1);
  for (i := 0; i < length (ops); i := i + 1)
    {
      item := aref (ops, i);
      if (aref (item, 0) = 'PLAN_OP' and aref (item, 1) = _op)
        return;
    }

  DB.DBA.OPENCYPHER_OC24_FAIL (sprintf ('%s expected plan op %s', _name, _op));
}
;

create procedure DB.DBA.OPENCYPHER_OC24_EXPECT_SCOPE_VAR (in _name varchar, in _query varchar, in _op varchar, in _var varchar)
{
  declare trace, items, row, vars any;
  declare i, j integer;

  trace := DB.DBA.CYPHER_PLAN_SCOPE (_query);
  if (aref (trace, 0) <> 'SCOPE_TRACE')
    DB.DBA.OPENCYPHER_OC24_FAIL (sprintf ('%s expected SCOPE_TRACE root', _name));

  items := aref (trace, 1);
  for (i := 0; i < length (items); i := i + 1)
    {
      row := aref (items, i);
      if (aref (row, 0) = _op)
        {
          vars := aref (row, 1);
          for (j := 0; j < length (vars); j := j + 1)
            {
              if (aref (vars, j) = _var)
                return;
            }
        }
    }

  DB.DBA.OPENCYPHER_OC24_FAIL (sprintf ('%s expected %s in scope after %s', _name, _var, _op));
}
;

create procedure DB.DBA.OPENCYPHER_OC24_EXPECT_PLAN_VALID (in _name varchar, in _query varchar)
{
  declare result varchar;
  result := DB.DBA.CYPHER_PLAN_VALIDATE (_query);
  if (result <> 'OK')
    DB.DBA.OPENCYPHER_OC24_FAIL (sprintf ('%s expected scope validation OK', _name));
}
;

create procedure DB.DBA.OPENCYPHER_OC24_EXPECT_PLAN_INVALID (in _name varchar, in _query varchar, in _expected varchar)
{
  declare state, msg varchar;
  declare meta, data any;

  state := '00000';
  msg := '';
  exec ('SELECT DB.DBA.CYPHER_PLAN_VALIDATE (?)', state, msg, vector (_query), 0, meta, data);

  if (state = '00000')
    DB.DBA.OPENCYPHER_OC24_FAIL (sprintf ('%s expected scope validation error containing "%s"', _name, _expected));

  if (strstr (msg, _expected) is null)
    DB.DBA.OPENCYPHER_OC24_FAIL (sprintf ('%s expected scope validation error containing "%s", got "%s"', _name, _expected, msg));
}
;

-- Test fixture graph used by result-based assertions.
create procedure DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ()
{
  return 'http://www.openlinksw.com/schemas/opencypher/test/oc24#';
}
;

-- Separate graph for write-clause tests so they can mutate freely
-- without disturbing the shared read fixture.
create procedure DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ()
{
  return 'http://www.openlinksw.com/schemas/opencypher/test/oc24w#';
}
;

-- Drop every quad in the supplied graph so result tests start from a
-- known empty state.  Uses SPARQL CLEAR GRAPH which is idempotent.
create procedure DB.DBA.OPENCYPHER_OC24_RESET_GRAPH (in _graph varchar)
{
  declare state, msg varchar;
  declare meta, data any;

  state := '00000';
  msg := '';
  exec (sprintf ('SPARQL CLEAR GRAPH <%s>', _graph),
        state, msg, vector (), 0, meta, data);
  if (state <> '00000' and state <> '00001')
    signal (state, msg);
}
;

-- Insert a tiny, deterministic node + relationship fixture into the
-- supplied graph.  Designed for the WITH/UNWIND/UNION/CALL/CASE smoke
-- tests so they exercise real result rows rather than translation
-- substrings.
--
-- Nodes:   :Person  alice (age 30), bob (age 25), carol (age 40)
-- Edges:   alice KNOWS bob, bob KNOWS carol
create procedure DB.DBA.OPENCYPHER_OC24_FIXTURE_SMALL (in _graph varchar)
{
  declare ttl, ins varchar;

  DB.DBA.OPENCYPHER_OC24_RESET_GRAPH (_graph);

  ttl := 'PREFIX v:  <http://www.openlinksw.com/schemas/opencypher#> ' ||
         'PREFIX ex: <http://example.org/> ' ||
         'INSERT IN GRAPH <' || _graph || '> { ' ||
         '  ex:alice a v:Person ; v:name "Alice" ; v:age 30 . ' ||
         '  ex:bob   a v:Person ; v:name "Bob"   ; v:age 25 . ' ||
         '  ex:carol a v:Person ; v:name "Carol" ; v:age 40 . ' ||
         '  ex:alice v:KNOWS ex:bob . ' ||
         '  ex:bob   v:KNOWS ex:carol . ' ||
         '}';
  ins := 'SPARQL ' || ttl;
  DB.DBA.CYPHER_EXEC_SPARQL (ins);
}
;

-- Run a Cypher query through DB.DBA.CYPHER and assert the row count.
create procedure DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT
  (in _name varchar, in _query varchar, in _graph varchar, in _expected integer)
{
  declare data any;
  declare got integer;

  data := DB.DBA.CYPHER (_query, _graph);
  if (data is null)
    got := 0;
  else
    got := length (data);

  if (got <> _expected)
    DB.DBA.OPENCYPHER_OC24_FAIL (sprintf ('%s expected %d rows, got %d',
                                      _name, _expected, got));
}
;

-- Run a Cypher query and assert the (0,0) cell equals the expected value.
-- _expected is compared as a string so callers can pass numbers or IRIs
-- without worrying about the underlying SPARQL result box type.
create procedure DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR
  (in _name varchar, in _query varchar, in _graph varchar, in _expected any)
{
  declare data any;
  declare got any;

  data := DB.DBA.CYPHER (_query, _graph);
  if (data is null or length (data) = 0)
    DB.DBA.OPENCYPHER_OC24_FAIL (sprintf ('%s expected scalar "%s", got no rows',
                                      _name, cast (_expected as varchar)));

  got := aref (aref (data, 0), 0);
  if (cast (got as varchar) <> cast (_expected as varchar))
    DB.DBA.OPENCYPHER_OC24_FAIL (sprintf ('%s expected scalar "%s", got "%s"',
                                      _name,
                                      cast (_expected as varchar),
                                      cast (got as varchar)));
}
;

-- Run a Cypher query and assert the (0,0) cell is null (an unbound
-- SPARQL value).  Useful for openCypher null-in / null-out checks
-- where the helper above cannot be used directly because cast(null as
-- varchar) does not round-trip through string comparison.
create procedure DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL
  (in _name varchar, in _query varchar, in _graph varchar)
{
  declare data any;
  declare got any;

  data := DB.DBA.CYPHER (_query, _graph);
  if (data is null or length (data) = 0)
    DB.DBA.OPENCYPHER_OC24_FAIL (sprintf ('%s expected null scalar, got no rows', _name));

  got := aref (aref (data, 0), 0);
  if (got is not null)
    DB.DBA.OPENCYPHER_OC24_FAIL (sprintf ('%s expected null scalar, got "%s"',
                                      _name,
                                      cast (got as varchar)));
}
;

-- Run a Cypher query and assert the first column matches an ordered
-- vector of expected values.  Both length and per-row equality are
-- checked, so this doubles as a row-count check.
create procedure DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_SEQUENCE
  (in _name varchar, in _query varchar, in _graph varchar, in _expected any)
{
  declare data any;
  declare i integer;
  declare got any;

  data := DB.DBA.CYPHER (_query, _graph);
  if (data is null)
    data := vector ();

  if (length (data) <> length (_expected))
    DB.DBA.OPENCYPHER_OC24_FAIL (sprintf ('%s expected %d rows, got %d',
                                      _name,
                                      length (_expected),
                                      length (data)));

  for (i := 0; i < length (_expected); i := i + 1)
    {
      got := aref (aref (data, i), 0);
      if (cast (got as varchar) <> cast (aref (_expected, i) as varchar))
        DB.DBA.OPENCYPHER_OC24_FAIL (
          sprintf ('%s row %d expected "%s", got "%s"',
                    _name, i,
                    cast (aref (_expected, i) as varchar),
                    cast (got as varchar)));
    }
}
;

-- Record an expected failure: the query is run, and the test only fails
-- if the query unexpectedly succeeds.  _reason must be one of the four
-- documented tags so the smoke output stays grep-friendly:
--   missing                - feature not implemented yet
--   explicit-diagnostic    - we deliberately raise a clear error
--   rdf-native-difference  - openCypher behavior we model differently
--   virtuoso-extension     - extension that the spec does not cover
create procedure DB.DBA.OPENCYPHER_OC24_XFAIL
  (in _name varchar, in _query varchar, in _graph varchar, in _reason varchar)
{
  declare state, msg varchar;
  declare meta, data any;

  if (_reason <> 'missing'
      and _reason <> 'explicit-diagnostic'
      and _reason <> 'rdf-native-difference'
      and _reason <> 'virtuoso-extension')
    DB.DBA.OPENCYPHER_OC24_FAIL (sprintf ('%s unknown xfail reason "%s"',
                                      _name, _reason));

  state := '00000';
  msg := '';
  exec ('SELECT DB.DBA.CYPHER (?, ?)',
        state, msg, vector (_query, _graph), 0, meta, data);

  if (state = '00000')
    DB.DBA.OPENCYPHER_OC24_FAIL (sprintf ('%s xfail (%s) unexpectedly succeeded',
                                      _name, _reason));
}
;

create procedure DB.DBA.OPENCYPHER_OC24_RUN ()
{
  declare total, passed integer;
  declare plugin_available integer;

  total := 0;
  passed := 0;

  plugin_available := DB.DBA.OPENCYPHER_PLUGIN_AVAILABLE ();
  if (plugin_available <> 0 and plugin_available <> 1)
    DB.DBA.OPENCYPHER_OC24_FAIL ('Plugin availability helper must return 0 or 1');
  total := total + 1; passed := passed + 1;

  -- Result-based assertions need a known graph state.
  DB.DBA.OPENCYPHER_OC24_FIXTURE_SMALL (DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());

  DB.DBA.OPENCYPHER_OC24_EXPECT_PLAN_OP (
    'Logical plan MATCH op',
    'MATCH (n) RETURN n',
    'MATCH');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_PLAN_OP (
    'Logical plan RETURN op',
    'MATCH (n) RETURN n',
    'RETURN');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_PLAN_OP (
    'Logical plan WITH project op',
    'MATCH (n) WITH n RETURN n',
    'PROJECT');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCOPE_VAR (
    'Scope trace MATCH variable',
    'MATCH (n)-[r:KNOWS]->(m) RETURN n',
    'MATCH',
    'r');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCOPE_VAR (
    'Scope trace WITH alias',
    'MATCH (n) WITH n AS person RETURN person',
    'PROJECT',
    'person');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCOPE_VAR (
    'Scope trace VALUES variable',
    'VALUES x {1, 2} RETURN x',
    'VALUES',
    'x');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCOPE_VAR (
    'Scope trace BIND alias',
    'MATCH (n) BIND(n.name AS name) RETURN name',
    'BIND',
    'name');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_PLAN_VALID (
    'Scope validation accepts visible variable',
    'MATCH (n) RETURN n');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_PLAN_INVALID (
    'Scope validation rejects variable hidden by WITH',
    'MATCH (n) WITH n AS person RETURN n',
    'Variable n is not in scope');
  total := total + 1; passed := passed + 1;

  -- WITH clause result-based smoke (was translation-only).
  -- Fixture: 3 :Person nodes (Alice 30, Bob 25, Carol 40).
  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'WITH basic projection',
    'MATCH (n:Person) WITH n RETURN n',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 3);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'WITH alias projection',
    'MATCH (n:Person) WITH n AS person RETURN person',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 3);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'WITH DISTINCT',
    'MATCH (n:Person) WITH DISTINCT n RETURN n',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 3);
  total := total + 1; passed := passed + 1;

  -- Phase 13.14: WITH ORDER BY / SKIP / LIMIT compose through to the
  -- outer RETURN.  ORDER BY is hoisted onto the outer SELECT so the
  -- requested order survives, and pagination flows through the
  -- subselect boundary.
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_SEQUENCE (
    'WITH ORDER BY n.age propagates ascending order',
    'MATCH (n:Person) WITH n ORDER BY n.age RETURN n.age',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (),
    vector (25, 30, 40));
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_SEQUENCE (
    'WITH ORDER BY DESC propagates descending order',
    'MATCH (n:Person) WITH n ORDER BY n.age DESC RETURN n.age',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (),
    vector (40, 30, 25));
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_SEQUENCE (
    'WITH ORDER BY + LIMIT composes pagination',
    'MATCH (n:Person) WITH n ORDER BY n.age LIMIT 2 RETURN n.age',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (),
    vector (25, 30));
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_SEQUENCE (
    'WITH ORDER BY + SKIP composes pagination',
    'MATCH (n:Person) WITH n ORDER BY n.age SKIP 1 RETURN n.age',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (),
    vector (30, 40));
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'WITH LIMIT 2',
    'MATCH (n:Person) WITH n LIMIT 2 RETURN n',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 2);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'WITH SKIP 2',
    'MATCH (n:Person) WITH n SKIP 2 RETURN n',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 1);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'WITH count(*) aggregation',
    'MATCH (n:Person) WITH count(*) AS cnt RETURN cnt',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 3);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'WITH WHERE filtering (age > 25)',
    'MATCH (n:Person) WITH n WHERE n.age > 25 RETURN n',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 2);
  total := total + 1; passed := passed + 1;

  -- UNWIND clause result-based smoke (was translation-only).
  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'UNWIND literal list yields one row per element',
    'UNWIND [1,2,3] AS x RETURN x',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 3);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_SEQUENCE (
    'UNWIND with ORDER BY ascending',
    'UNWIND [3,1,2] AS x RETURN x ORDER BY x',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (),
    vector (1, 2, 3));
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'List element access index',
    'WITH [1,2,3] AS list RETURN list[0]',
    'sql:CYP_LIST_GET');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'head() function',
    'WITH [1,2,3] AS list RETURN head(list)',
    'sql:CYP_LIST_GET');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'last() function',
    'WITH [1,2,3] AS list RETURN last(list)',
    'sql:CYP_LIST_LENGTH');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'size() function for lists',
    'WITH [1,2,3] AS list RETURN size(list)',
    'sql:CYP_LIST_LENGTH');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Map literal vector value',
    'RETURN {name: ''Neo'', born: 1964} AS m',
    'sql:CYP_MAP_TO_VECTOR');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Static map access',
    'RETURN {name: ''Neo'', born: 1964}.name AS name',
    '"Neo"');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'keys(map) literal support',
    'RETURN keys({name: ''Neo'', born: 1964}) AS ks',
    'sql:CYP_MAP_KEYS');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Dynamic property access',
    'MATCH (n) WITH ''name'' AS k, n RETURN n[k] AS v',
    'IRI(CONCAT');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Dynamic map access by variable key',
    'WITH ''name'' AS k RETURN {name: ''Neo'', born: 1964}[k] AS v',
    'sql:CYP_MAP_GET');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Map projection with .prop items',
    'MATCH (n) RETURN n {.name, .born} AS m',
    'sql:CYP_MAP_NEW');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Map projection with alias item',
    'MATCH (n) RETURN n {alias: n.name + ''!''} AS m',
    'sql:CYP_MAP_NEW');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Map projection wildcard item',
    'MATCH (n) RETURN n {*} AS m',
    'sql:VECTOR_AGG');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'List slice',
    'RETURN [1,2,3][1..3] AS xs',
    'sql:CYP_LIST_SLICE');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'List concatenation',
    'RETURN [1,2] + [3,4] AS xs',
    'sql:CYP_LIST_CONCAT');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'range() numeric helper path',
    'RETURN range(1, 5, 2) AS xs',
    'sql:CYP_NUMERIC_VECTOR_RANGE');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'List comprehension over literal source',
    'RETURN [x IN [1,2,3] WHERE x > 1 | x + 10] AS xs',
    'bif:vector_concat');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'List comprehension over WITH-bound literal source',
    'WITH [1,2,3] AS xs RETURN [x IN xs WHERE x > 1 | x] AS ys',
    'bif:vector_concat');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'List quantifier all',
    'RETURN all(x IN [1,2,3] WHERE x > 0) AS ok',
    '&&');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'List quantifier over WITH-bound literal source',
    'WITH [1,2,3] AS xs RETURN any(x IN xs WHERE x > 1)',
    '||');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'REDUCE over literal list',
    'RETURN REDUCE(acc = 0, x IN [1,2,3] | acc + x) AS sum',
    '+ 3');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'REDUCE over WITH-bound literal source',
    'WITH [1,2,3] AS xs RETURN REDUCE(acc = 0, x IN xs | acc + x) AS sum',
    '+ 3');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Dynamic map access over WITH-bound literal map',
    'WITH {name: ''Neo'', born: 1964} AS m, ''name'' AS k RETURN m[k] AS v',
    'sql:CYP_MAP_GET');
  total := total + 1; passed := passed + 1;

  -- Phase 13.14: UNION / UNION ALL execution.  openCypher UNION wraps
  -- the lowering in SELECT DISTINCT so duplicate rows collapse; UNION
  -- ALL keeps the multiset.  Branches that share a column name (?x)
  -- exercise the dedup path; branches with different names retain
  -- both columns and so do not overlap.
  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'UNION ALL multiset of two identical reads',
    'MATCH (n:Person) RETURN n.name AS x UNION ALL MATCH (m:Person) RETURN m.name AS x',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 6);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'UNION (set) deduplicates two identical reads',
    'MATCH (n:Person) RETURN n.name AS x UNION MATCH (m:Person) RETURN m.name AS x',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 3);
  total := total + 1; passed := passed + 1;

  -- CALL ... YIELD result-based smoke (was translation-only).
  -- Fixture only declares :Person, so labels() yields exactly one row.
  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'CALL opencypher.labels() YIELD label',
    'CALL opencypher.labels() YIELD label RETURN label',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 1);
  total := total + 1; passed := passed + 1;

  -- properties() exposes every distinct predicate used in the graph;
  -- exact count is fixture-specific so just confirm rows come back.
  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'CALL opencypher.properties() YIELD key',
    'CALL opencypher.properties() YIELD key RETURN key',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 4);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (
    'CALL rejects unknown procedures',
    'CALL unknown.proc() YIELD x RETURN x',
    'Unknown procedure');
  total := total + 1; passed := passed + 1;

  -- Phase 6: Paths and Graph Pattern Completeness
  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Named path binding',
    'MATCH p = (a)-[:KNOWS]->(b) RETURN p',
    'p');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Zero-or-more relationship property path',
    'MATCH (a)-[:KNOWS*]->(b) RETURN a, b',
    '<http://www.openlinksw.com/schemas/opencypher#knows>*');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'One-or-more relationship property path',
    'MATCH (a)-[:KNOWS+]->(b) RETURN a, b',
    '<http://www.openlinksw.com/schemas/opencypher#knows>+');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Bounded relationship property path',
    'MATCH (a)-[:KNOWS*1..3]->(b) RETURN a, b',
    '<http://www.openlinksw.com/schemas/opencypher#knows>{1,3}');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (
    'ANY path search prefix diagnostic',
    'MATCH p = ANY (a)-[:R]->(b) RETURN p',
    'Path search prefix ANY is not yet implemented');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (
    'ALL SHORTEST path search prefix diagnostic',
    'MATCH p = ALL SHORTEST (a)-[:R]->(b) RETURN p',
    'Path search prefix ALL SHORTEST is not yet implemented');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (
    'ANY SHORTEST path search prefix diagnostic',
    'MATCH p = ANY SHORTEST (a)-[:R]->(b) RETURN p',
    'Path search prefix ANY SHORTEST is not yet implemented');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (
    'SHORTEST count path search prefix diagnostic',
    'MATCH p = SHORTEST 2 (a)-[:R]->(b) RETURN p',
    'Path search prefix SHORTEST 2 is not yet implemented');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (
    'SHORTEST groups path search prefix diagnostic',
    'MATCH p = SHORTEST 2 GROUPS (a)-[:R]->(b) RETURN p',
    'Path search prefix SHORTEST 2 GROUPS is not yet implemented');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (
    'Quantified path primary diagnostic',
    'MATCH ((a)-[:R]->(b)){2,3} RETURN a, b',
    'Quantified path primaries and parenthesized path patterns are not yet implemented');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (
    'Parenthesized quantified path with WHERE diagnostic',
    'MATCH (a) ((x)-[:R]->(y) WHERE x.ok = true)+ (b) RETURN a, b',
    'Quantified path primaries and parenthesized path patterns are not yet implemented');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'length() one-hop named path',
    'MATCH p = (a)-[:KNOWS]->(b) RETURN length(p)',
    'SELECT 1');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'nodes() one-hop named path',
    'MATCH p = (a)-[:KNOWS]->(b) RETURN nodes(p)',
    'sql:CYP_PATH_NODES');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'relationships() one-hop named path',
    'MATCH p = (a)-[:KNOWS]->(b) RETURN relationships(p)',
    'sql:CYP_PATH_RELS');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (
    'Variable-length path function diagnostic',
    'MATCH p = (a)-[:KNOWS*]->(b) RETURN length(p)',
    'Path value functions on variable-length paths are not yet implemented');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Pattern predicate translates to EXISTS',
    'MATCH (a), (b) WHERE (a)-[:KNOWS]->(b) RETURN a, b',
    'EXISTS');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (
    'Pattern comprehension diagnostic',
    'MATCH (a) RETURN [(a)-[:KNOWS]->(b) | b] AS known',
    'Pattern comprehensions are not yet implemented');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (
    'Named pattern comprehension diagnostic',
    'MATCH (a) RETURN [p = (a)-[:KNOWS]->(b) WHERE b.name IS NOT NULL | b.name]',
    'Pattern comprehensions are not yet implemented');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (
    'shortestPath error',
    'MATCH (a), (b) RETURN shortestPath(a, b) AS p',
    'shortestPath() is not yet implemented');
  total := total + 1; passed := passed + 1;

  -- Phase 7: Expression Completeness — CASE result-based smoke.
  -- ORDER BY is placed on the final RETURN (not inside WITH) because
  -- WITH ... ORDER BY ... RETURN does not currently propagate order
  -- through the projection.  Tracked separately.
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_SEQUENCE (
    'CASE with multiple WHEN arms',
    'MATCH (n:Person) ' ||
    'RETURN CASE n.age ' ||
    '         WHEN 25 THEN ''twentyfive'' ' ||
    '         WHEN 30 THEN ''thirty'' ' ||
    '         ELSE ''other'' END ' ||
    'ORDER BY n.age',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (),
    vector ('twentyfive', 'thirty', 'other'));
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_SEQUENCE (
    'Searched CASE expression',
    'MATCH (n:Person) ' ||
    'RETURN CASE WHEN n.age > 30 THEN ''old'' ELSE ''young'' END ' ||
    'ORDER BY n.age',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (),
    vector ('young', 'young', 'old'));
  total := total + 1; passed := passed + 1;

  -- Simple CASE with no matching arm and no ELSE returns null
  -- (the row count must still be 3 — null projection does not drop rows).
  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'CASE no-match no-ELSE preserves row count',
    'MATCH (n:Person) ' ||
    'RETURN n.name AS name, ' ||
    '  CASE n.age WHEN 999 THEN ''x'' END AS status',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 3);
  total := total + 1; passed := passed + 1;

  -- Searched CASE with no ELSE: rows where the condition is false get null.
  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'Searched CASE no-ELSE preserves row count',
    'MATCH (n:Person) ' ||
    'RETURN CASE WHEN n.age > 100 THEN ''aged'' END AS label',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 3);
  total := total + 1; passed := passed + 1;

  -- CASE expr WHEN NULL: per Cypher three-valued logic, expr = NULL is
  -- never true, so the WHEN NULL arm never fires.  This locks in the
  -- spec-conformant fall-through to ELSE.
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_SEQUENCE (
    'CASE WHEN NULL falls through to ELSE',
    'MATCH (n:Person) ' ||
    'RETURN CASE n.missing WHEN NULL THEN ''null'' ELSE ''value'' END ' ||
    'ORDER BY n.name',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (),
    vector ('value', 'value', 'value'));
  total := total + 1; passed := passed + 1;

  -- Searched CASE with explicit IS NULL is the right way to detect null.
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_SEQUENCE (
    'Searched CASE WHEN IS NULL detects null',
    'MATCH (n:Person) ' ||
    'RETURN CASE WHEN n.missing IS NULL THEN ''null'' ELSE ''value'' END ' ||
    'ORDER BY n.name',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (),
    vector ('null', 'null', 'null'));
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (
    'Unknown function error',
    'RETURN unknownFunc(1,2,3)',
    'Unknown or unsupported function');
  total := total + 1; passed := passed + 1;

  -- Missing clause families should fail explicitly until implemented.

  DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (
    'Dynamic list comprehension diagnostic',
    'MATCH (n) WITH collect(n.name) AS xs RETURN [x IN xs WHERE x IS NOT NULL | x]',
    'List comprehensions over dynamic list sources are not yet implemented');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (
    'Dynamic quantifier diagnostic',
    'MATCH (n) WITH collect(n.name) AS xs RETURN any(x IN xs WHERE x IS NOT NULL)',
    'Quantifiers over dynamic list sources are not yet implemented');
  total := total + 1; passed := passed + 1;

  -- Phase 8: Parameters and Host API
  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Parameter in WHERE clause',
    'MATCH (n) WHERE n.name = $name RETURN n',
    'name');
  total := total + 1; passed := passed + 1;

  -- isql macro-expands an unbound $word in the source string to the
  -- literal NULL before the smoke harness ever sees it, so this test
  -- effectively asserts that NULL in a RETURN expression lowers to a
  -- SPARQL unbound (COALESCE()) value.  That is exactly the
  -- openCypher null contract enforced by Phase 13.11, so the
  -- substring assertion is intentionally pinned to COALESCE.
  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Parameter in RETURN expression',
    'MATCH (n) RETURN n.age > $minAge AS isAdult',
    'COALESCE');
  total := total + 1; passed := passed + 1;

  -- See note above: the $min / $max placeholders are macro-expanded by
  -- isql to NULL before the smoke harness sees the query, so this test
  -- pins the post-fix lowering of multiple null literals to COALESCE.
  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Multiple parameters',
    'MATCH (n) WHERE n.age > $min AND n.age < $max RETURN n',
    'COALESCE');
  total := total + 1; passed := passed + 1;

  -- Existing supported RDF-native features should still translate.
  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'PREFIX translation',
    'PREFIX ex: <http://example.org/> MATCH (n:ex:Person) RETURN n.ex:name',
    'http://example.org/Person');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Full IRI property access',
    'PREFIX mv: <http://demo.openlinksw.com/movie-ontology#> MATCH (m:mv:Movie) FROM <urn:movies:opencypher:demo> RETURN m.<http://demo.openlinksw.com/movie-ontology#title>, m.mv:released',
    'http://demo.openlinksw.com/movie-ontology#title');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Full IRI label and relationship type',
    'MATCH (a:<http://demo.openlinksw.com/movie-ontology#Actor>)-[:<http://demo.openlinksw.com/movie-ontology#actedIn>]->(m:<http://demo.openlinksw.com/movie-ontology#Movie>) RETURN a, m',
    'http://demo.openlinksw.com/movie-ontology#actedIn');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'GRAPH translation',
    'GRAPH <urn:g> { MATCH (n:Person) RETURN n AS n2 } RETURN n2',
    'GRAPH <urn:g>');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'GRAPH adds named dataset',
    'GRAPH <urn:g> { MATCH (n:Person) RETURN n AS n2 } RETURN n2',
    'FROM NAMED <urn:g>');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'USE GRAPH dotted graph reference',
    'USE GRAPH analytics.sales MATCH (n) RETURN n',
    'FROM <analytics:sales>');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'USE GRAPH prefixed graph reference',
    'PREFIX ex: <http://example.org/> USE GRAPH ex:analytics MATCH (n) RETURN n',
    'FROM <http://example.org/analytics>');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_NO_TRANSLATION (
    'USE ANY GRAPH suppresses default FROM',
    'USE ANY GRAPH MATCH (n) RETURN n',
    'FROM <urn:opencypher:default>');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'All MATCH FROM NAMED clauses contribute dataset',
    'MATCH (n) FROM NAMED <urn:g1> MATCH (m) FROM NAMED <urn:g2> RETURN n, m',
    'FROM NAMED <urn:g2>');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'SERVICE translation',
    'SERVICE <http://example.org/sparql> { MATCH (n:Person) RETURN n AS n2 } RETURN n2',
    'SERVICE <http://example.org/sparql>');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'SERVICE SILENT translation',
    'SERVICE SILENT <http://example.org/sparql> { MATCH (n:Person) RETURN n AS n2 } RETURN n2',
    'SERVICE SILENT <http://example.org/sparql>');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'SERVICE prefixed labels use declared URI',
    'PREFIX dbo: <http://dbpedia.org/ontology/> SERVICE <https://dbpedia.org/sparql> { MATCH (film:dbo:Film)-[:dbo:writer]->(writer) RETURN film AS film2 } RETURN film2',
    '<http://dbpedia.org/ontology/Film>');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'SERVICE prefixed relationships use declared URI',
    'PREFIX dbo: <http://dbpedia.org/ontology/> SERVICE <https://dbpedia.org/sparql> { MATCH (film:dbo:Film)-[:dbo:writer]->(writer) RETURN film AS film2 } RETURN film2',
    '<http://dbpedia.org/ontology/writer>');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_NO_TRANSLATION (
    'SERVICE prefixed terms avoid openCypher fallback',
    'PREFIX dbo: <http://dbpedia.org/ontology/> SERVICE <https://dbpedia.org/sparql> { MATCH (film:dbo:Film)-[:dbo:writer]->(writer) RETURN film AS film2 } RETURN film2',
    'opencypher#dbo');
  total := total + 1; passed := passed + 1;

  DB.DBA.XML_SET_NS_DECL ('ocnsreg', 'http://example.com/registered-ns#', 2);
  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Registered namespace label expands without PREFIX',
    'MATCH (p:ocnsreg:Person) RETURN p.ocnsreg:name AS name',
    '<http://example.com/registered-ns#Person>');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Registered namespace property expands without PREFIX',
    'MATCH (p:ocnsreg:Person) RETURN p.ocnsreg:name AS name',
    '<http://example.com/registered-ns#name>');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_NO_TRANSLATION (
    'Registered namespace avoids openCypher fallback',
    'MATCH (p:ocnsreg:Person) RETURN p.ocnsreg:name AS name',
    'opencypher#ocnsreg');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_NO_TRANSLATION (
    'SERVICE relationship endpoints avoid generic node probes',
    'PREFIX dbo: <http://dbpedia.org/ontology/> SERVICE <https://dbpedia.org/sparql> { MATCH (film:dbo:Film)-[:dbo:writer]->(writer) RETURN film AS film2 } RETURN film2',
    '?writer ?');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'SERVICE projected properties reuse inner binding',
    'PREFIX dbo: <http://dbpedia.org/ontology/> PREFIX dbr: <http://dbpedia.org/resource/> PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> SERVICE <https://dbpedia.org/sparql> { MATCH (film:dbo:Film)-[:dbo:writer]->(writer) WHERE writer = dbr:Spike_Lee AND lang(film.`rdfs:label`) = ''en'' } RETURN DISTINCT film.`rdfs:label` AS title ORDER BY title',
    '?film_rdfs_label AS ?title');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_NO_TRANSLATION (
    'SERVICE projected properties avoid outer local optional',
    'PREFIX dbo: <http://dbpedia.org/ontology/> PREFIX dbr: <http://dbpedia.org/resource/> PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> SERVICE <https://dbpedia.org/sparql> { MATCH (film:dbo:Film)-[:dbo:writer]->(writer) WHERE writer = dbr:Spike_Lee AND lang(film.`rdfs:label`) = ''en'' } RETURN DISTINCT film.`rdfs:label` AS title ORDER BY title',
    'OPTIONAL { ?film <http://www.w3.org/2000/01/rdf-schema#label>');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_NO_TRANSLATION (
    'SERVICE-only queries do not inject default FROM',
    'PREFIX dbo: <http://dbpedia.org/ontology/> PREFIX dbr: <http://dbpedia.org/resource/> PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> SERVICE <http://dbpedia.org/sparql> { MATCH (film:dbo:Film)-[:dbo:writer]->(writer) WHERE writer = dbr:Spike_Lee AND lang(film.`rdfs:label`) = ''en'' } RETURN DISTINCT film.`rdfs:label` AS title ORDER BY title',
    'FROM <http://www.openlinksw.com/schemas/opencypher#>');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'VALUES BIND translation',
    'VALUES x {1, 2} BIND(x + 1 AS y) RETURN y',
    'VALUES ?x { 1 2 }');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'MINUS translation',
    'MATCH (n) MINUS { MATCH (n:Blocked) } RETURN n',
    'MINUS {');
  total := total + 1; passed := passed + 1;

  -- Phase 13.1: OFFSET as a synonym for SKIP (openCypher 2024.3)
  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'RETURN OFFSET synonym',
    'MATCH (n) RETURN n OFFSET 5',
    'OFFSET 5');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'WITH OFFSET synonym',
    'MATCH (n) WITH n OFFSET 5 RETURN n',
    'OFFSET 5');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'RETURN SKIP unchanged',
    'MATCH (n) RETURN n SKIP 7',
    'OFFSET 7');
  total := total + 1; passed := passed + 1;

  -- Phase 13.2: label expressions (openCypher 2024.3)
  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Label OR (|) yields FILTER ||',
    'MATCH (n:Person|Employee) RETURN n',
    '||');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Label OR has both class URIs',
    'MATCH (n:Person|Employee) RETURN n',
    'Employee');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Label NOT (!) yields FILTER !(...)',
    'MATCH (n:!Blocked) RETURN n',
    '!(');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Label conjunction (&) flattens to two type triples',
    'MATCH (n:Person&Employee) RETURN n',
    'Employee');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'IS Label is alias for : Label',
    'MATCH (n IS Person) RETURN n',
    'opencypher#Person');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'WHERE n IS Label uses EXISTS',
    'MATCH (n) WHERE n IS Person RETURN n',
    'EXISTS');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Relationship IS TYPE is alias for :TYPE',
    'MATCH (a)-[r IS KNOWS]->(b) RETURN r',
    'opencypher#knows');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'Wildcard label (:%) binds class without filter',
    'MATCH (n:%) RETURN n',
    '_class');
  total := total + 1; passed := passed + 1;

  -- Phase 13.10: EXISTS { ... } existential subqueries (openCypher 2024).
  -- Translation form: WHERE EXISTS { ... } becomes SPARQL FILTER EXISTS.
  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'EXISTS { pattern } WHERE-form translates to FILTER EXISTS',
    'MATCH (a:Person) WHERE EXISTS { (a:Person) } RETURN a',
    'FILTER (EXISTS');
  total := total + 1; passed := passed + 1;

  -- RETURN form: RETURN EXISTS { ... } AS x becomes a SPARQL EXISTS expr.
  DB.DBA.OPENCYPHER_OC24_EXPECT_TRANSLATION (
    'EXISTS { pattern } RETURN-form translates to EXISTS expression',
    'MATCH (a:Person) RETURN EXISTS { (a:Person) } AS has_self',
    'EXISTS {');
  total := total + 1; passed := passed + 1;

  -- Result-based: uncorrelated EXISTS over same label keeps every row.
  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'EXISTS uncorrelated keeps all matching outer rows',
    'MATCH (a:Person) WHERE EXISTS { (a:Person) } RETURN a',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 3);
  total := total + 1; passed := passed + 1;

  -- Result-based: correlated EXISTS WHERE filters via outer-bound variable.
  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'EXISTS correlated WHERE filters outer rows',
    'MATCH (a:Person) WHERE EXISTS { (a:Person) WHERE a.age > 30 } RETURN a',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 1);
  total := total + 1; passed := passed + 1;

  -- Result-based: RETURN EXISTS { ... } AS x yields one row per outer
  -- match (the boolean values are exercised below with an aggregate so
  -- the assertion does not depend on outer row ordering).
  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'RETURN EXISTS { ... } returns one row per outer match',
    'MATCH (a:Person) RETURN EXISTS { (a:Person) WHERE a.age > 25 } AS adult',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 3);
  total := total + 1; passed := passed + 1;

  -- Aggregate count of outer rows for which EXISTS holds: 2 of 3 persons
  -- are over 25, so the count must be 2 regardless of result ordering.
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'EXISTS correlated count over outer rows',
    'MATCH (a:Person) WHERE EXISTS { (a:Person) WHERE a.age > 25 } ' ||
    'RETURN count(a) AS n',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 2);
  total := total + 1; passed := passed + 1;

  -- Result-based: inner-only variables stay inside the EXISTS body and do
  -- not leak into the outer pattern (pinning the inner-context fix).
  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'EXISTS inner-only variable does not multiply outer rows',
    'MATCH (a:Person) WHERE EXISTS { (b:Person) WHERE b.age > 30 } RETURN a',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 3);
  total := total + 1; passed := passed + 1;

  -- Phase 13.11: function null-in / null-out and type-conversion
  -- completeness (openCypher 2024).  All scalar function families
  -- (string, math, conversion) must propagate a null input to a null
  -- output, and the type-conversion functions must yield null on
  -- invalid input rather than raising.

  -- String functions: null in -> null out.
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL (
    'toString(null) is null',
    'RETURN toString(null) AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL (
    'toLower(null) is null',
    'RETURN toLower(null) AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL (
    'trim(null) is null',
    'RETURN trim(null) AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL (
    'substring(null,...) is null',
    'RETURN substring(null, 0, 1) AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL (
    'replace(null,...) is null',
    'RETURN replace(null, ''a'', ''b'') AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL (
    'left(null, n) is null',
    'RETURN left(null, 2) AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL (
    'right(null, n) is null',
    'RETURN right(null, 2) AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());
  total := total + 1; passed := passed + 1;

  -- Math functions: null in -> null out (covers ABS, FLOOR/CEIL/ROUND
  -- inherited from SPARQL builtins, plus the explicitly null-guarded
  -- sign and the bif:* numeric helpers).
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL (
    'abs(null) is null',
    'RETURN abs(null) AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL (
    'sign(null) is null',
    'RETURN sign(null) AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL (
    'sqrt(null) is null',
    'RETURN sqrt(null) AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'sign(-3) is -1',
    'RETURN sign(-3) AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), -1);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'sign(0) is 0',
    'RETURN sign(0) AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 0);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'sign(7) is 1',
    'RETURN sign(7) AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 1);
  total := total + 1; passed := passed + 1;

  -- Type conversion: invalid input yields null per openCypher.
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL (
    'toInteger("foo") is null on invalid input',
    'RETURN toInteger(''foo'') AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL (
    'toFloat("foo") is null on invalid input',
    'RETURN toFloat(''foo'') AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL (
    'toBoolean("maybe") is null on invalid input',
    'RETURN toBoolean(''maybe'') AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'toInteger("42") is 42',
    'RETURN toInteger(''42'') AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 42);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'toBoolean(case-insensitive "TRUE") is true',
    'RETURN toBoolean(''TRUE'') AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 1);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'toBoolean("false") is false',
    'RETURN toBoolean(''false'') AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 0);
  total := total + 1; passed := passed + 1;

  -- Boolean literal pass-through (Phase 13.11 carry-forward closed by
  -- the LIT_BOOL AST node).  Cypher TRUE / FALSE now lower to the
  -- SPARQL `true` / `false` keywords so toBoolean / toString and
  -- direct boolean comparisons see an xsd:boolean rather than an
  -- integer 0/1.
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'toBoolean(true) is true (literal pass-through)',
    'RETURN toBoolean(true) AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 1);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'toBoolean(false) is false (literal pass-through)',
    'RETURN toBoolean(false) AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 0);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'toString(true) is "true"',
    'RETURN toString(true) AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 'true');
  total := total + 1; passed := passed + 1;

  -- toIntegerOrNull / toFloatOrNull (openCypher 2024 aliases).
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL (
    'toIntegerOrNull("foo") is null',
    'RETURN toIntegerOrNull(''foo'') AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'toIntegerOrNull("42") is 42',
    'RETURN toIntegerOrNull(''42'') AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 42);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL (
    'toFloatOrNull("foo") is null',
    'RETURN toFloatOrNull(''foo'') AS r', DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());
  total := total + 1; passed := passed + 1;

  -- split() and reverse() raise explicit diagnostics until a working
  -- Virtuoso bif counterpart is wired up (bif:tokenize / bif:reverse
  -- are not registered).
  DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (
    'split() raises explicit diagnostic',
    'RETURN split(''a,b'', '','') AS r',
    'split() is not yet implemented');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (
    'reverse() raises explicit diagnostic',
    'RETURN reverse(''abc'') AS r',
    'reverse() is not yet implemented');
  total := total + 1; passed := passed + 1;

  -- Phase 13.12: temporal value support (openCypher 2024).  Cypher
  -- temporal types are mapped to the matching XSD types so the SPARQL
  -- engine's native temporal arithmetic and comparison are reused
  -- end to end.

  -- Constructors: string, no-arg, and map forms.
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'date(string) parses ISO 8601',
    'RETURN date(''2020-01-15'') AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), '2020-01-15');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'date(map) builds the date',
    'RETURN date({year:2020, month:1, day:15}) AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), '2020-01-15');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'date(map year-only) defaults month/day to 1',
    'RETURN date({year:2020}) AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), '2020-01-01');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'datetime(map) builds the date-time',
    'RETURN datetime({year:2020,month:1,day:15,hour:10,minute:30,second:5}) AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), '2020-01-15 10:30:05');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'time(map) builds the time of day',
    'RETURN time({hour:10, minute:30, second:45}) AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), '10:30:45');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'duration(string) parses ISO 8601',
    'RETURN duration(''P1Y2M'') AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 'P1Y2M');
  total := total + 1; passed := passed + 1;

  -- Accessors.
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'year(date) returns 2020',
    'RETURN year(date(''2020-06-15'')) AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 2020);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'month(date) returns 6',
    'RETURN month(date(''2020-06-15'')) AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 6);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'day(date) returns 15',
    'RETURN day(date(''2020-06-15'')) AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 15);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'hour(datetime) returns 10',
    'RETURN hour(datetime(''2020-06-15T10:30:45'')) AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 10);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'minute(datetime) returns 30',
    'RETURN minute(datetime(''2020-06-15T10:30:45'')) AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 30);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'second(datetime) returns the integer second',
    'RETURN second(datetime(''2020-06-15T10:30:45'')) AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 45);
  total := total + 1; passed := passed + 1;

  -- Comparison and arithmetic.
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'date equality between identical dates is true',
    'RETURN date(''2020-01-15'') = date(''2020-01-15'') AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 1);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'date ordering: earlier < later is true',
    'RETURN date(''2020-01-15'') < date(''2020-02-15'') AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 1);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'date + duration("P1Y") advances by one year',
    'RETURN date(''2020-01-15'') + duration(''P1Y'') AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), '2021-01-15');
  total := total + 1; passed := passed + 1;

  -- Carry-forward: truncate / epoch / sub-second accessors / map-form
  -- duration() raise explicit translation-time diagnostics.
  DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (
    'truncate() raises explicit diagnostic',
    'RETURN truncate(''day'', date(''2020-06-15'')) AS r',
    'truncate() temporal function is not yet implemented');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (
    'epochMillis() raises explicit diagnostic',
    'RETURN epochMillis(date(''2020-06-15'')) AS r',
    'is not yet implemented');
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_ERROR (
    'duration({components}) raises explicit diagnostic',
    'RETURN duration({hours: 1, minutes: 30}) AS r',
    'Map-form duration() is not yet implemented');
  total := total + 1; passed := passed + 1;

  -- Phase 13.13: literal forms, null propagation, operator precedence
  -- (openCypher 2024 expressions/literals, expressions/null, expressions/precedence).
  -- Hex / octal / scientific integer and float literals.
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'hex integer literal 0x10FF parses to 4351',
    'RETURN 0x10FF AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 4351);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'octal integer literal 0177 parses to 127',
    'RETURN 0177 AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 127);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'scientific float literal 1.5e7 parses to 15000000',
    'RETURN 1.5e7 AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 15000000);
  total := total + 1; passed := passed + 1;

  -- String escape sequences including \\uXXXX.
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'string escape \\u0041 decodes to ASCII A',
    'RETURN ''\\u0041'' AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 'A');
  total := total + 1; passed := passed + 1;

  -- Multi-byte \uXXXX escapes are validated by length: a non-decoded
  -- escape would surface as the 6-character literal "\uXXXX", whereas
  -- a correctly decoded escape collapses to a single Unicode character.
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'string escape \\u00e9 decodes to single Unicode char',
    'RETURN size(''\\u00e9'') AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 1);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'string escape \\u4e2d decodes to single Unicode char',
    'RETURN size(''\\u4e2d'') AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 1);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'standard string escapes \\t and \\n are decoded',
    'RETURN ''a\\tb\\nc'' AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 'a' || chr (9) || 'b' || chr (10) || 'c');
  total := total + 1; passed := passed + 1;

  -- openCypher null propagation: NULL through arithmetic, boolean,
  -- comparison, IN, and STARTS WITH must all yield NULL (unbound).
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL (
    '1 + NULL propagates to NULL',
    'RETURN 1 + NULL AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL (
    'NULL AND true propagates to NULL',
    'RETURN NULL AND true AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL (
    'NULL = NULL is NULL, not true',
    'RETURN NULL = NULL AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL (
    'NULL IN [1,2,3] is NULL, not false',
    'RETURN NULL IN [1, 2, 3] AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR_NULL (
    '''abc'' STARTS WITH NULL is NULL',
    'RETURN ''abc'' STARTS WITH NULL AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH ());
  total := total + 1; passed := passed + 1;

  -- Operator precedence: arithmetic before comparison before AND before OR,
  -- unary NOT binding tighter than comparison, list indexing tighter than
  -- arithmetic.
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    '1 + 2 * 3 binds * tighter than +',
    'RETURN 1 + 2 * 3 AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 7);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    '(1 + 2) * 3 forces + before *',
    'RETURN (1 + 2) * 3 AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 9);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'true OR false AND false binds AND tighter than OR',
    'RETURN true OR false AND false AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 1);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'NOT 1 = 2 binds = before NOT (NOT applies to result)',
    'RETURN NOT 1 = 2 AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 1);
  total := total + 1; passed := passed + 1;

  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    '[1,2,3][1] + 10 binds index tighter than +',
    'RETURN [1, 2, 3][1] + 10 AS r',
    DB.DBA.OPENCYPHER_OC24_TEST_GRAPH (), 12);
  total := total + 1; passed := passed + 1;

  -- Phase 13.8: Write side-effect parity.  Each test re-installs the
  -- fixture in the dedicated write graph so it is independent of any
  -- earlier mutation, then asserts the post-write state via a Cypher
  -- read.  Use OPENCYPHER_OC24_WRITE_GRAPH () so the read fixture used by
  -- WITH/UNWIND/CALL/CASE tests above stays untouched.

  -- CREATE
  DB.DBA.OPENCYPHER_OC24_FIXTURE_SMALL (DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.CYPHER ('CREATE (p:Person {name: ''Dave'', age: 50})',
                 DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'CREATE adds a node',
    'MATCH (p:Person) RETURN p',
    DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH (), 4);
  total := total + 1; passed := passed + 1;

  -- DELETE node
  DB.DBA.OPENCYPHER_OC24_FIXTURE_SMALL (DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.CYPHER ('MATCH (n:Person {name: ''Bob''}) DELETE n',
                 DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'DELETE removes the node',
    'MATCH (p:Person {name: ''Bob''}) RETURN p',
    DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH (), 0);
  total := total + 1; passed := passed + 1;

  -- DETACH DELETE node (Bob has an incoming KNOWS from Alice and
  -- an outgoing KNOWS to Carol; both must go).
  DB.DBA.OPENCYPHER_OC24_FIXTURE_SMALL (DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.CYPHER ('MATCH (n:Person {name: ''Bob''}) DETACH DELETE n',
                 DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'DETACH DELETE removes the node',
    'MATCH (p:Person {name: ''Bob''}) RETURN p',
    DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH (), 0);
  total := total + 1; passed := passed + 1;

  -- SET n.prop = value
  DB.DBA.OPENCYPHER_OC24_FIXTURE_SMALL (DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.CYPHER ('MATCH (n:Person {name: ''Alice''}) SET n.age = 99',
                 DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'SET single property updates the value',
    'MATCH (n:Person {name: ''Alice''}) RETURN n.age',
    DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH (), 99);
  total := total + 1; passed := passed + 1;

  -- REMOVE n.prop
  DB.DBA.OPENCYPHER_OC24_FIXTURE_SMALL (DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.CYPHER ('MATCH (n:Person {name: ''Alice''}) REMOVE n.age',
                 DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'REMOVE drops the property',
    'MATCH (n:Person {name: ''Alice''}) WHERE n.age IS NOT NULL RETURN n',
    DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH (), 0);
  total := total + 1; passed := passed + 1;

  -- SET n.prop = NULL is Cypher null-as-remove: same effect as REMOVE.
  DB.DBA.OPENCYPHER_OC24_FIXTURE_SMALL (DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.CYPHER ('MATCH (n:Person {name: ''Alice''}) SET n.age = NULL',
                 DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'SET prop = NULL removes the property',
    'MATCH (n:Person {name: ''Alice''}) WHERE n.age IS NOT NULL RETURN n',
    DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH (), 0);
  total := total + 1; passed := passed + 1;

  -- MERGE: existing match keeps cardinality
  DB.DBA.OPENCYPHER_OC24_FIXTURE_SMALL (DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.CYPHER ('MERGE (n:Person {name: ''Alice''})',
                 DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'MERGE existing leaves count unchanged',
    'MATCH (p:Person) RETURN p',
    DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH (), 3);
  total := total + 1; passed := passed + 1;

  -- MERGE: new node mints
  DB.DBA.OPENCYPHER_OC24_FIXTURE_SMALL (DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.CYPHER ('MERGE (n:Person {name: ''Eve''})',
                 DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'MERGE new mints a node',
    'MATCH (p:Person) RETURN p',
    DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH (), 4);
  total := total + 1; passed := passed + 1;

  -- The remaining write-clause features hard-error today and are
  -- captured here so a future fix can flip the xfail to a positive
  -- assertion.

  -- SET n = map (replacement): replaces all non-label properties on
  -- the matched node.  rdf:type triples are preserved.
  DB.DBA.OPENCYPHER_OC24_FIXTURE_SMALL (DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.CYPHER (
    'MATCH (n:Person {name: ''Alice''}) SET n = {age: 99}',
    DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'SET n = map applies new property',
    'MATCH (n:Person) WHERE n.age = 99 RETURN n.age',
    DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH (), 99);
  total := total + 1; passed := passed + 1;
  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'SET n = map drops absent property',
    'MATCH (n:Person) WHERE n.name = ''Alice'' RETURN n',
    DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH (), 0);
  total := total + 1; passed := passed + 1;
  DB.DBA.OPENCYPHER_OC24_EXPECT_ROW_COUNT (
    'SET n = map preserves :Label',
    'MATCH (n:Person) RETURN n',
    DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH (), 3);
  total := total + 1; passed := passed + 1;

  -- SET n += map (merge): existing properties not mentioned in the
  -- map are left alone; mentioned keys are added or replaced.
  DB.DBA.OPENCYPHER_OC24_FIXTURE_SMALL (DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.CYPHER (
    'MATCH (n:Person {name: ''Alice''}) SET n += {nick: ''Al'', age: 31}',
    DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'SET n += map adds new property',
    'MATCH (n:Person {name: ''Alice''}) RETURN n.nick',
    DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH (), 'Al');
  total := total + 1; passed := passed + 1;
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'SET n += map updates existing property',
    'MATCH (n:Person {name: ''Alice''}) RETURN n.age',
    DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH (), 31);
  total := total + 1; passed := passed + 1;
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'SET n += map preserves untouched property',
    'MATCH (n:Person {name: ''Alice''}) RETURN n.name',
    DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH (), 'Alice');
  total := total + 1; passed := passed + 1;

  -- MERGE ... ON CREATE SET fires when the pattern is created.
  DB.DBA.OPENCYPHER_OC24_FIXTURE_SMALL (DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.CYPHER ('MERGE (n:Person {name: ''Frank''}) ON CREATE SET n.age = 100',
                 DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'MERGE ON CREATE SET applies to new node',
    'MATCH (n:Person {name: ''Frank''}) RETURN n.age',
    DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH (), '100');
  total := total + 1; passed := passed + 1;

  -- MERGE ... ON MATCH SET fires when the pattern already exists.
  DB.DBA.OPENCYPHER_OC24_FIXTURE_SMALL (DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.CYPHER ('MERGE (n:Person {name: ''Alice''}) ON MATCH SET n.age = 99',
                 DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.OPENCYPHER_OC24_EXPECT_SCALAR (
    'MERGE ON MATCH SET updates existing node',
    'MATCH (n:Person {name: ''Alice''}) RETURN n.age',
    DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH (), '99');
  total := total + 1; passed := passed + 1;

  -- SET on a relationship variable is intentionally rejected: in
  -- openCypher relationships are plain RDF triples with no property bag.
  DB.DBA.OPENCYPHER_OC24_FIXTURE_SMALL (DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());
  DB.DBA.OPENCYPHER_OC24_XFAIL (
    'SET on relationship signals explicit diagnostic',
    'MATCH (a:Person)-[r:KNOWS]->(b:Person) SET r.since = 2020',
    DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH (),
    'rdf-native-difference');
  total := total + 1; passed := passed + 1;

  -- Always reset the write graph after the block so a subsequent run
  -- starts from a clean slate.
  DB.DBA.OPENCYPHER_OC24_RESET_GRAPH (DB.DBA.OPENCYPHER_OC24_WRITE_GRAPH ());

  -- Phase 14.1 — value runtime helper smoke.  These exercise the
  -- LIST/MAP/PATH/ROW helpers on their canonical shapes so future
  -- work packages can rely on the contract without reverifying it.
  declare l, m, p, p2, pv, r, pd, pn, nv, nv_plain any;

  l := DB.DBA.CYP_LIST_NEW (vector (10, 20, 30));
  if (DB.DBA.CYP_LIST_IS (l) <> 1)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_LIST_IS rejected a freshly built LIST');
  if (DB.DBA.CYP_LIST_SIZE (l) <> 3)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_LIST_SIZE expected 3');
  if (DB.DBA.CYP_LIST_GET (l, 1) <> 20)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_LIST_GET expected 20 at index 1');
  if (DB.DBA.CYP_LIST_GET (l, 99) is not null)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_LIST_GET out-of-range must return NULL');
  if (DB.DBA.CYP_LIST_SIZE (DB.DBA.CYP_LIST_APPEND (l, 40)) <> 4)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_LIST_APPEND must extend by one');
  if (DB.DBA.CYP_LIST_IS (vector ('MAP', vector (), vector ())) <> 0)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_LIST_IS must reject non-LIST cells');
  if (DB.DBA.CYP_LIST_LENGTH (l) <> 3)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_LIST_LENGTH expected 3');
  if (length (DB.DBA.CYP_LIST_TO_VECTOR (DB.DBA.CYP_LIST_SLICE (l, 1, 3))) <> 2)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_LIST_SLICE expected two elements');
  if (DB.DBA.CYP_LIST_GET (DB.DBA.CYP_LIST_CONCAT (DB.DBA.CYP_LIST_NEW (vector (1, 2)), DB.DBA.CYP_LIST_NEW (vector (3, 4))), 3) <> 4)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_LIST_CONCAT expected index 3 to be 4');
  total := total + 9; passed := passed + 9;

  nv := DB.DBA.CYP_NUMERIC_VECTOR_NEW (vector (1, 2.5, 3));
  nv_plain := DB.DBA.CYP_NUMERIC_VECTOR_TO_VECTOR (nv);
  if (DB.DBA.CYP_DENSE_NUMERIC_AVAILABLE () not in (0, 1))
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_DENSE_NUMERIC_AVAILABLE expected boolean result');
  if (length (nv_plain) <> 3 or cast (aref (nv_plain, 1) as double precision) <> 2.5)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_NUMERIC_VECTOR_TO_VECTOR expected three numeric values');
  if (cast (DB.DBA.CYP_NUMERIC_VECTOR_SUM (nv) as double precision) <> 6.5)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_NUMERIC_VECTOR_SUM expected 6.5');
  if (cast (DB.DBA.CYP_NUMERIC_VECTOR_AVG (nv) as double precision) <> cast (6.5 / 3 as double precision))
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_NUMERIC_VECTOR_AVG expected 6.5/3');
  if (length (DB.DBA.CYP_NUMERIC_VECTOR_TO_VECTOR (DB.DBA.CYP_NUMERIC_VECTOR_RANGE (1, 5, 2))) <> 3)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_NUMERIC_VECTOR_RANGE expected three values');
  if (length (DB.DBA.CYP_LIST_TO_VECTOR (DB.DBA.CYP_LIST_NEW (vector (1, 'two', null)))) <> 3)
    DB.DBA.OPENCYPHER_OC24_FAIL ('Mixed Cypher LIST must stay vector-compatible');
  total := total + 6; passed := passed + 6;

  m := DB.DBA.CYP_MAP_NEW (vector ('name', 'age'), vector ('Alice', 30));
  if (DB.DBA.CYP_MAP_IS (m) <> 1)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_MAP_IS rejected a freshly built MAP');
  if (DB.DBA.CYP_MAP_GET (m, 'age') <> 30)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_MAP_GET expected 30 for age');
  if (DB.DBA.CYP_MAP_HAS_KEY (m, 'name') <> 1)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_MAP_HAS_KEY expected 1 for name');
  if (DB.DBA.CYP_MAP_HAS (m, 'missing') <> 0)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_MAP_HAS expected 0 for missing key');
  if (DB.DBA.CYP_MAP_GET (m, 'missing') is not null)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_MAP_GET missing key must return NULL');
  if (length (DB.DBA.CYP_MAP_KEYS (m)) <> 2)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_MAP_KEYS expected 2 keys');
  if (DB.DBA.CYP_MAP_GET (DB.DBA.CYP_MAP_PUT (m, 'role', 'One'), 'role') <> 'One')
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_MAP_PUT expected role=One');
  if (length (DB.DBA.CYP_MAP_TO_VECTOR (m)) <> 4)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_MAP_TO_VECTOR expected flat vector length 4');
  if (DB.DBA.CYP_MAP_GET (vector ('MAP', vector ('name'), vector ('Fallback')), 'name') <> 'Fallback')
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_MAP_GET vector fallback expected Fallback');
  total := total + 9; passed := passed + 9;

  pd := dict_new ();
  dict_put (pd, 'name', 'Neo');
  pn := DB.DBA.CYPHER_NORMALIZE_PARAMS (pd);
  if (length (pn) <> 1 or aref (aref (pn, 0), 0) <> 'name' or aref (aref (pn, 0), 1) <> 'Neo')
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYPHER_NORMALIZE_PARAMS dictionary input expected name=Neo');
  total := total + 1; passed := passed + 1;

  p := DB.DBA.CYP_PATH_NEW (vector ('n0', 'n1', 'n2'), vector ('r0', 'r1'));
  if (DB.DBA.CYP_PATH_IS (p) <> 1)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_PATH_IS rejected a freshly built PATH');
  if (DB.DBA.CYP_PATH_LENGTH (p) <> 2)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_PATH_LENGTH expected 2');
  if (length (DB.DBA.CYP_PATH_NODES (p)) <> 3)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_PATH_NODES expected 3 nodes');
  if (length (DB.DBA.CYP_PATH_RELS (p)) <> 2)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_PATH_RELS expected 2 rels');
  -- Empty path: zero nodes and zero rels is allowed.
  if (DB.DBA.CYP_PATH_LENGTH (DB.DBA.CYP_PATH_NEW (vector (), vector ())) <> 0)
    DB.DBA.OPENCYPHER_OC24_FAIL ('Empty PATH must report length 0');
  p2 := DB.DBA.CYP_PATH_APPEND_HOP (DB.DBA.CYP_PATH_NEW (vector ('n0'), vector ()), 'r0', 'n1');
  if (DB.DBA.CYP_PATH_LENGTH (p2) <> 1 or length (DB.DBA.CYP_PATH_NODES (p2)) <> 2 or length (DB.DBA.CYP_PATH_RELS (p2)) <> 1)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_PATH_APPEND_HOP expected one-hop path');
  pv := DB.DBA.CYP_PATH_VAR_NEW ('p', 2, vector ('?a', '?b', '?c'), vector ('?r1', '?r2'), 0);
  if (DB.DBA.CYP_PATH_VAR_NAME (pv) <> 'p'
      or DB.DBA.CYP_PATH_VAR_HOP_COUNT (pv) <> 2
      or length (DB.DBA.CYP_PATH_VAR_NODE_TERMS (pv)) <> 3
      or length (DB.DBA.CYP_PATH_VAR_REL_TERMS (pv)) <> 2
      or DB.DBA.CYP_PATH_VAR_HAS_VARLEN (pv) <> 0)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_PATH_VAR_* accessors returned unexpected metadata');
  total := total + 7; passed := passed + 7;

  r := DB.DBA.CYP_ROW_NEW (vector ('name', 'age'), vector ('Bob', 25));
  if (DB.DBA.CYP_ROW_IS (r) <> 1)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_ROW_IS rejected a freshly built ROW');
  if (DB.DBA.CYP_ROW_GET (r, 'age') <> 25)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_ROW_GET expected 25 for age');
  if (DB.DBA.CYP_ROW_GET (r, 'missing') is not null)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_ROW_GET missing alias must return NULL');
  if (length (DB.DBA.CYP_ROW_KEYS (r)) <> 2)
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_ROW_KEYS expected 2 aliases');
  if (DB.DBA.CYP_ROW_GET (vector ('ROW', vector ('name'), vector ('Fallback')), 'name') <> 'Fallback')
    DB.DBA.OPENCYPHER_OC24_FAIL ('CYP_ROW_GET vector fallback expected Fallback');
  total := total + 5; passed := passed + 5;

  result (sprintf ('OPEN CYPHER 2024 SMOKE TESTS PASSED: %d/%d', passed, total));
}
;

DB.DBA.OPENCYPHER_OC24_RUN ();

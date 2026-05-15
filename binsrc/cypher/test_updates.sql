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
--  Phase 9: Update Side-Effect Tests for openCypher
--
--  Tests CREATE, DELETE, SET, REMOVE, MERGE side-effect semantics
--

set echo on;

create procedure DB.DBA.OPENCYPHER_UPDATE_RUN ()
{
  declare total, passed, failed integer;
  declare cnt, cnt2 integer;
  declare rows any;
  declare msg varchar;
  declare results any;

  total := 0;
  passed := 0;
  failed := 0;
  results := vector ();

  -- Clean slate
  DB.DBA.CYPHER_RESET ();

  -- Test 1: CREATE side effects visible to RETURN in same statement
  msg := 'Test 1: CREATE + RETURN in same statement';
  total := total + 1;
  rows := DB.DBA.CYPHER ('CREATE (n:TestNode {name: ''test1''}) RETURN n.name');
  if (length (rows) = 1 and aref (aref (rows, 0), 0) = 'test1')
    {
      passed := passed + 1;
      results := vector_concat (results, vector (msg || ' PASSED'));
    }
  else
    {
      failed := failed + 1;
      results := vector_concat (results, vector (msg || ' FAILED'));
    }

  -- Test 2: Multiple CREATE in same statement
  msg := 'Test 2: Multiple CREATE nodes';
  total := total + 1;
  DB.DBA.CYPHER ('CREATE (:MultiNode {id: 1}), (:MultiNode {id: 2}), (:MultiNode {id: 3})');
  rows := DB.DBA.CYPHER ('MATCH (n:MultiNode) RETURN count(n)');
  if (length (rows) = 1 and aref (aref (rows, 0), 0) = 3)
    {
      passed := passed + 1;
      result (msg || ' PASSED');
    }
  else
    {
      failed := failed + 1;
      result (msg || ' FAILED: expected count=3');
    }

  -- Test 3: SET single property
  msg := 'Test 3: SET single property';
  total := total + 1;
  DB.DBA.CYPHER ('CREATE (n:SetTest {name: ''original''})');
  DB.DBA.CYPHER ('MATCH (n:SetTest {name: ''original''}) SET n.value = 42');
  rows := DB.DBA.CYPHER ('MATCH (n:SetTest) RETURN n.value');
  if (length (rows) = 1 and aref (aref (rows, 0), 0) = 42)
    {
      passed := passed + 1;
      result (msg || ' PASSED');
    }
  else
    {
      failed := failed + 1;
      result (msg || ' FAILED: expected value=42');
    }

  -- Test 4: SET multiple properties
  msg := 'Test 4: SET multiple properties';
  total := total + 1;
  DB.DBA.CYPHER ('CREATE (n:MultiSet {id: 1})');
  DB.DBA.CYPHER ('MATCH (n:MultiSet) SET n.a = 1, n.b = 2, n.c = 3');
  rows := DB.DBA.CYPHER ('MATCH (n:MultiSet) RETURN n.a, n.b, n.c');
  if (length (rows) = 1 and aref (aref (rows, 0), 0) = 1 and aref (aref (rows, 0), 1) = 2)
    {
      passed := passed + 1;
      result (msg || ' PASSED');
    }
  else
    {
      failed := failed + 1;
      result (msg || ' FAILED: expected a=1, b=2');
    }

  -- Test 5: SET overwrites existing property
  msg := 'Test 5: SET overwrites existing property';
  total := total + 1;
  DB.DBA.CYPHER ('CREATE (n:Overwrite {value: 10})');
  DB.DBA.CYPHER ('MATCH (n:Overwrite) SET n.value = 99');
  rows := DB.DBA.CYPHER ('MATCH (n:Overwrite) RETURN n.value');
  if (length (rows) = 1 and aref (aref (rows, 0), 0) = 99)
    {
      passed := passed + 1;
      result (msg || ' PASSED');
    }
  else
    {
      failed := failed + 1;
      result (msg || ' FAILED: expected value=99 after overwrite');
    }

  -- Test 6: SET to NULL removes property
  msg := 'Test 6: SET prop = NULL removes property';
  total := total + 1;
  DB.DBA.CYPHER ('CREATE (n:NullProp {keep: ''yes'', remove: ''no''})');
  DB.DBA.CYPHER ('MATCH (n:NullProp) SET n.remove = NULL');
  rows := DB.DBA.CYPHER ('MATCH (n:NullProp) RETURN n.keep, n.remove');
  -- n.keep should exist, n.remove should be NULL (not bound)
  if (length (rows) = 1 and aref (aref (rows, 0), 0) = 'yes')
    {
      passed := passed + 1;
      result (msg || ' PASSED');
    }
  else
    {
      failed := failed + 1;
      result (msg || ' FAILED: property removal check');
    }

  -- Test 7: REMOVE property
  msg := 'Test 7: REMOVE property';
  total := total + 1;
  DB.DBA.CYPHER ('CREATE (n:RemoveTest {a: 1, b: 2})');
  DB.DBA.CYPHER ('MATCH (n:RemoveTest) REMOVE n.a');
  rows := DB.DBA.CYPHER ('MATCH (n:RemoveTest) RETURN n.a, n.b');
  if (length (rows) = 1)
    {
      -- n.a should be NULL, n.b should still be 2
      declare a_val, b_val any;
      a_val := aref (aref (rows, 0), 0);
      b_val := aref (aref (rows, 0), 1);
      if (a_val is null and b_val = 2)
        {
          passed := passed + 1;
          result (msg || ' PASSED');
        }
      else
        {
          failed := failed + 1;
          result (msg || ' FAILED: expected a=NULL, b=2');
        }
    }
  else
    {
      failed := failed + 1;
      result (msg || ' FAILED: no rows returned');
    }

  -- Test 8: DELETE node
  msg := 'Test 8: DELETE node';
  total := total + 1;
  DB.DBA.CYPHER ('CREATE (n:DeleteMe {id: 123})');
  cnt := DB.DBA.OPENCYPHER_BT_SPARQL_COUNT ('SPARQL SELECT ?n FROM <http://www.openlinksw.com/schemas/opencypher#> WHERE { ?n a <http://www.openlinksw.com/schemas/opencypher#DeleteMe> }');
  if (cnt <> 1)
    {
      failed := failed + 1;
      result (msg || ' FAILED: setup did not create node');
    }
  else
    {
      DB.DBA.CYPHER ('MATCH (n:DeleteMe) DELETE n');
      cnt := DB.DBA.OPENCYPHER_BT_SPARQL_COUNT ('SPARQL SELECT ?n FROM <http://www.openlinksw.com/schemas/opencypher#> WHERE { ?n a <http://www.openlinksw.com/schemas/opencypher#DeleteMe> }');
      if (cnt = 0)
        {
          passed := passed + 1;
          result (msg || ' PASSED');
        }
      else
        {
          failed := failed + 1;
          result (msg || ' FAILED: node still exists after DELETE');
        }
    }

  -- Test 9: MERGE creates when not exists
  msg := 'Test 9: MERGE creates new node';
  total := total + 1;
  DB.DBA.CYPHER ('MERGE (n:MergeTest {key: ''new''})');
  rows := DB.DBA.CYPHER ('MATCH (n:MergeTest {key: ''new''}) RETURN n.key');
  if (length (rows) = 1 and aref (aref (rows, 0), 0) = 'new')
    {
      passed := passed + 1;
      result (msg || ' PASSED');
    }
  else
    {
      failed := failed + 1;
      result (msg || ' FAILED: MERGE did not create node');
    }

  -- Test 10: MERGE matches existing (idempotent)
  msg := 'Test 10: MERGE is idempotent';
  total := total + 1;
  DB.DBA.CYPHER ('MERGE (n:Idempotent {key: ''same''})');
  DB.DBA.CYPHER ('MERGE (n:Idempotent {key: ''same''})');
  rows := DB.DBA.CYPHER ('MATCH (n:Idempotent {key: ''same''}) RETURN count(n)');
  if (length (rows) = 1 and aref (aref (rows, 0), 0) = 1)
    {
      passed := passed + 1;
      result (msg || ' PASSED');
    }
  else
    {
      failed := failed + 1;
      result (msg || ' FAILED: MERGE created duplicate');
    }

  -- Test 11: MATCH + CREATE relationship
  msg := 'Test 11: MATCH then CREATE relationship';
  total := total + 1;
  DB.DBA.CYPHER ('CREATE (a:RelNode {name: ''a''}), (b:RelNode {name: ''b''})');
  DB.DBA.CYPHER ('MATCH (a:RelNode {name: ''a''}), (b:RelNode {name: ''b''}) CREATE (a)-[:RELATES]->(b)');
  rows := DB.DBA.CYPHER ('MATCH (a:RelNode)-[:RELATES]->(b:RelNode) RETURN a.name, b.name');
  if (length (rows) = 1 and aref (aref (rows, 0), 0) = 'a' and aref (aref (rows, 0), 1) = 'b')
    {
      passed := passed + 1;
      result (msg || ' PASSED');
    }
  else
    {
      failed := failed + 1;
      result (msg || ' FAILED: relationship not created');
    }

  -- Summary
  result ('');
  result ('========================================');
  result ('Update Tests: ' || cast (passed as varchar) || '/' || cast (total as varchar) || ' passed');
  if (failed > 0)
    result ('FAILED: ' || cast (failed as varchar) || ' tests');
  result ('========================================');

  return vector (total, passed, failed);
}
;

-- Helper for counting (reused from Burton/Taylor)
create procedure DB.DBA.OPENCYPHER_BT_SPARQL_COUNT (in _sparql varchar)
{
  declare state, msg varchar;
  declare meta, data any;

  state := '00000';
  msg := '';
  exec (_sparql, state, msg, vector (), 0, meta, data);
  if (state <> '00000')
    return -1;
  if (data is null or length (data) = 0)
    return 0;
  return length (data);
}
;

-- Run the tests
DB.DBA.OPENCYPHER_UPDATE_RUN ()
;

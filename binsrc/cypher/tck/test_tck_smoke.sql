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
--  Phase 10: TCK Smoke Runner for openCypher 2024.3
--
--  One-command runner: ./binsrc/tests/isql 1111 dba dba < binsrc/cypher/tck/test_tck_smoke.sql
--

-- TCK Test Registry
create procedure DB.DBA.OPENCYPHER_TCK_RUN ()
{
  declare pass, fail, total integer;
  declare msg varchar;

  pass := 0;
  fail := 0;
  total := 0;

  result ('openCypher TCK Smoke Test - openCypher 2024.3');
  result ('============================================');

  -- Test 1: Basic CREATE
  total := total + 1;
  whenever sqlstate '*' goto t1_fail;
  DB.DBA.CYPHER_TO_SPARQL ('CREATE (n) RETURN n');
  pass := pass + 1;
  result ('[PASS] CREATE (n) RETURN n');
  goto t2;
t1_fail:
  fail := fail + 1;
  result ('[FAIL] CREATE (n) RETURN n: ' || __SQL_MESSAGE);
  resume t2;

  -- Test 2: MATCH with label
T2:  total := total + 1;
  whenever sqlstate '*' goto t2_fail;
  DB.DBA.CYPHER_TO_SPARQL ('MATCH (n:Person) RETURN n');
  pass := pass + 1;
  result ('[PASS] MATCH (n:Person) RETURN n');
  goto t3;
t2_fail:
  fail := fail + 1;
  result ('[FAIL] MATCH (n:Person) RETURN n: ' || __SQL_MESSAGE);
  resume t3;

  -- Test 3: WHERE clause
T3:  total := total + 1;
  whenever sqlstate '*' goto t3_fail;
  DB.DBA.CYPHER_TO_SPARQL ('MATCH (n) WHERE n.name = ''Alice'' RETURN n');
  pass := pass + 1;
  result ('[PASS] MATCH with WHERE');
  goto t4;
t3_fail:
  fail := fail + 1;
  result ('[FAIL] MATCH with WHERE: ' || __SQL_MESSAGE);
  resume t4;

  -- Test 4: ORDER BY
T4:  total := total + 1;
  whenever sqlstate '*' goto t4_fail;
  DB.DBA.CYPHER_TO_SPARQL ('MATCH (n) RETURN n ORDER BY n.name');
  pass := pass + 1;
  result ('[PASS] ORDER BY');
  goto t5;
t4_fail:
  fail := fail + 1;
  result ('[FAIL] ORDER BY: ' || __SQL_MESSAGE);
  resume t5;

  -- Test 5: LIMIT
T5:  total := total + 1;
  whenever sqlstate '*' goto t5_fail;
  DB.DBA.CYPHER_TO_SPARQL ('MATCH (n) RETURN n LIMIT 10');
  pass := pass + 1;
  result ('[PASS] LIMIT');
  goto t6;
t5_fail:
  fail := fail + 1;
  result ('[FAIL] LIMIT: ' || __SQL_MESSAGE);
  resume t6;

  -- Test 6: SKIP
T6:  total := total + 1;
  whenever sqlstate '*' goto t6_fail;
  DB.DBA.CYPHER_TO_SPARQL ('MATCH (n) RETURN n SKIP 5');
  pass := pass + 1;
  result ('[PASS] SKIP');
  goto t7;
t6_fail:
  fail := fail + 1;
  result ('[FAIL] SKIP: ' || __SQL_MESSAGE);
  resume t7;

  -- Test 7: WITH clause
T7:  total := total + 1;
  whenever sqlstate '*' goto t7_fail;
  DB.DBA.CYPHER_TO_SPARQL ('MATCH (n) WITH n RETURN n');
  pass := pass + 1;
  result ('[PASS] WITH clause');
  goto t8;
t7_fail:
  fail := fail + 1;
  result ('[FAIL] WITH clause: ' || __SQL_MESSAGE);
  resume t8;

  -- Test 8: UNION
T8:  total := total + 1;
  whenever sqlstate '*' goto t8_fail;
  DB.DBA.CYPHER_TO_SPARQL ('MATCH (n) RETURN n UNION MATCH (m) RETURN m');
  pass := pass + 1;
  result ('[PASS] UNION');
  goto t9;
t8_fail:
  fail := fail + 1;
  result ('[FAIL] UNION: ' || __SQL_MESSAGE);
  resume t9;

  -- Test 9: Aggregate COUNT
T9:  total := total + 1;
  whenever sqlstate '*' goto t9_fail;
  DB.DBA.CYPHER_TO_SPARQL ('MATCH (n) RETURN count(n)');
  pass := pass + 1;
  result ('[PASS] COUNT aggregate');
  goto t10;
t9_fail:
  fail := fail + 1;
  result ('[FAIL] COUNT aggregate: ' || __SQL_MESSAGE);
  resume t10;

  -- Test 10: CASE expression
T10:  total := total + 1;
  whenever sqlstate '*' goto t10_fail;
  DB.DBA.CYPHER_TO_SPARQL ('MATCH (n) RETURN CASE n.a WHEN 1 THEN ''one'' ELSE ''other'' END');
  pass := pass + 1;
  result ('[PASS] CASE expression');
  goto t_done;
t10_fail:
  fail := fail + 1;
  result ('[FAIL] CASE expression: ' || __SQL_MESSAGE);

T_DONE:
  result ('');
  result ('============================================');
  result ('Results: ' || cast(pass as varchar) || '/' || cast(total as varchar) || ' passed');
  if (fail > 0) result ('         ' || cast(fail as varchar) || ' failed');
  result ('============================================');

  return vector (pass, fail, total);
}
;

-- Run the TCK smoke tests
DB.DBA.OPENCYPHER_TCK_RUN ()
;

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
--  Phase 10: TCK Smoke Runner for openCypher 2024.3 (Simple Version)
--

set echo on;

create procedure DB.DBA.OPENCYPHER_TCK_SIMPLE ()
{
  declare pass, fail, total integer;
  declare results any;
  declare sparql_str varchar;

  pass := 0; fail := 0; total := 0; results := vector ();

  results := vector_concat (results, vector ('openCypher TCK Smoke Test - openCypher 2024.3'));
  results := vector_concat (results, vector ('============================================'));

  -- Test 1: Basic CREATE
  total := total + 1;
  whenever sqlstate '*' goto t1_fail;
  sparql_str := DB.DBA.CYPHER_TO_SPARQL ('CREATE (n) RETURN n');
  pass := pass + 1;
  results := vector_concat (results, vector ('[PASS] CREATE (n) RETURN n'));
  goto t2;
t1_fail:
  fail := fail + 1;
  results := vector_concat (results, vector ('[FAIL] CREATE: ' || __SQL_MESSAGE));
  resume t2;

t2:
  -- Test 2: MATCH with label
  total := total + 1;
  whenever sqlstate '*' goto t2_fail;
  sparql_str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n:Person) RETURN n');
  pass := pass + 1;
  results := vector_concat (results, vector ('[PASS] MATCH (n:Person) RETURN n'));
  goto t3;
t2_fail:
  fail := fail + 1;
  results := vector_concat (results, vector ('[FAIL] MATCH with label: ' || __SQL_MESSAGE));
  resume t3;

t3:
  -- Test 3: WHERE clause
  total := total + 1;
  whenever sqlstate '*' goto t3_fail;
  sparql_str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n) WHERE n.name = ''Alice'' RETURN n');
  pass := pass + 1;
  results := vector_concat (results, vector ('[PASS] MATCH with WHERE'));
  goto t4;
t3_fail:
  fail := fail + 1;
  results := vector_concat (results, vector ('[FAIL] WHERE clause: ' || __SQL_MESSAGE));
  resume t4;

t4:
  -- Test 4: UNION
  total := total + 1;
  whenever sqlstate '*' goto t4_fail;
  sparql_str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n) RETURN n UNION MATCH (m) RETURN m');
  pass := pass + 1;
  results := vector_concat (results, vector ('[PASS] UNION'));
  goto t5;
t4_fail:
  fail := fail + 1;
  results := vector_concat (results, vector ('[FAIL] UNION: ' || __SQL_MESSAGE));
  resume t5;

t5:
  -- Test 5: COUNT aggregate
  total := total + 1;
  whenever sqlstate '*' goto t5_fail;
  sparql_str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n) RETURN count(n)');
  pass := pass + 1;
  results := vector_concat (results, vector ('[PASS] COUNT aggregate'));
  goto t6;
t5_fail:
  fail := fail + 1;
  results := vector_concat (results, vector ('[FAIL] COUNT: ' || __SQL_MESSAGE));
  resume t6;

t6:
  -- Summary
  results := vector_concat (results, vector (''));
  results := vector_concat (results, vector ('============================================'));
  results := vector_concat (results, vector ('Results: ' || cast(pass as varchar) || '/' || cast(total as varchar) || ' passed'));
  if (fail > 0) results := vector_concat (results, vector ('         ' || cast(fail as varchar) || ' failed'));
  results := vector_concat (results, vector ('============================================'));

  return results;
}
;

-- Execute and display results
create procedure DB.DBA.OPENCYPHER_TCK_DISPLAY ()
{
  declare results any;
  declare i integer;
  results := DB.DBA.OPENCYPHER_TCK_SIMPLE ();
  for (i := 0; i < length (results); i := i + 1)
    {
      select aref (results, i) as result;
    }
}
;

DB.DBA.OPENCYPHER_TCK_DISPLAY ()
;

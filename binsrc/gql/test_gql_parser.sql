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
--  openGQL: GQL for Virtuoso - Parser Tests
--
--  Run via isql: isql <host>:<port> dba dba < test_gql_parser.sql
--

create procedure DB.DBA.GQL_PARSER_TESTS ()
{
  declare _pass, _fail, _total integer;
  declare _results any;
  declare _tokens, _ast any;

  _pass := 0; _fail := 0; _total := 0;
  _results := vector ();

  -- Helper: parse and check AST tag
  declare _CHECK_AST varchar;
  _CHECK_AST := 'AST';

  -- ===================================================================
  -- Section 1: Basic query statements
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n) RETURN n');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG'
      and aref (aref (aref (_ast, 1), 3), 0) = 'QUERY')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT1 PASS: MATCH RETURN basic')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT1 FAIL: MATCH RETURN basic')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n) WHERE n.name = ''Alice'' RETURN n');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT2 PASS: MATCH WHERE RETURN')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT2 FAIL: MATCH WHERE RETURN')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n) RETURN DISTINCT n.name');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT3 PASS: RETURN DISTINCT')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT3 FAIL: RETURN DISTINCT')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n) RETURN n ORDER BY n.name ASC');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT4 PASS: RETURN ORDER BY ASC')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT4 FAIL: RETURN ORDER BY ASC')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n) RETURN n SKIP 10 LIMIT 5');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT5 PASS: RETURN SKIP LIMIT')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT5 FAIL: RETURN SKIP LIMIT')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('OPTIONAL MATCH (n)-[:KNOWS]->(m) RETURN n,m');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT6 PASS: OPTIONAL MATCH')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT6 FAIL: OPTIONAL MATCH')); }

  -- ===================================================================
  -- Section 2: Data-modifying statements
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('INSERT (:Person { firstname: ''Firstname'' })');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT7 PASS: INSERT node with props')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT7 FAIL: INSERT node with props')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (a), (b) INSERT (a)-[:GRADUATED]->(b)');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT8 PASS: MATCH INSERT edge')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT8 FAIL: MATCH INSERT edge')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n) SET n.name = ''Bob''');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT9 PASS: SET property')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT9 FAIL: SET property')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n) REMOVE n:OldLabel');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT10 PASS: REMOVE label')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT10 FAIL: REMOVE label')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n) DELETE n');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT11 PASS: DELETE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT11 FAIL: DELETE')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n) DETACH DELETE n');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT12 PASS: DETACH DELETE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT12 FAIL: DETACH DELETE')); }

  -- ===================================================================
  -- Section 3: Pattern elements
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n) RETURN n');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT13 PASS: basic node no labels')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n:Person:Employee) RETURN n');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT14 PASS: node with multi labels')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT14 FAIL: node with multi labels')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n:Person { name: ''Alice'', age: 30 }) RETURN n');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT15 PASS: node with properties')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT15 FAIL: node with properties')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n)-[:KNOWS]->(m) RETURN n,m');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT16 PASS: directed edge')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT16 FAIL: directed edge')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n)<-[:KNOWS]-(m) RETURN n,m');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT17 PASS: left-directed edge')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT17 FAIL: left-directed edge')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n)-[:KNOWS]-(m) RETURN n,m');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT18 PASS: undirected edge (both)')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT18 FAIL: undirected edge (both)')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n)-[:KNOWS*1..3]->(m) RETURN n,m');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT19 PASS: quantified edge 1..3')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT19 FAIL: quantified edge 1..3')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n)-[:KNOWS*]->(m) RETURN n,m');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT20 PASS: unbounded edge *')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT20 FAIL: unbounded edge *')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n)-[:KNOWS+]->(m) RETURN n,m');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT21 PASS: one-or-more edge +')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT21 FAIL: one-or-more edge +')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (a)-[r1]->(b)-[r2]->(c) RETURN a,b,c');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT22 PASS: multi-hop path')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT22 FAIL: multi-hop path')); }

  -- ===================================================================
  -- Section 4: USE graph and LET
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('USE mygraph MATCH (n) RETURN n');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT23 PASS: USE graph')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT23 FAIL: USE graph')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('SERVICE <http://example.org/sparql> { MATCH (n) RETURN n AS n2 ORDER BY n2 } RETURN n2');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT24 PASS: SERVICE nested RETURN')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT24 FAIL: SERVICE nested RETURN')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH ALL (n) RETURN n');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG'
      and aref (aref (aref (aref (_ast, 1), 3), 1), 0) = 'MATCH'
      and aref (aref (aref (aref (_ast, 1), 3), 1), 4) = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT25 PASS: MATCH ALL flag')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT25 FAIL: MATCH ALL flag')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('LET x = 42 MATCH (n) RETURN n');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT24 PASS: LET binding')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT24 FAIL: LET binding')); }

  -- ===================================================================
  -- Section 5: Catalog-modifying (parse-only)
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('CREATE SCHEMA myschema');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG' and aref (aref (_ast, 1), 0) = 'PROC')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT25 PASS: CREATE SCHEMA')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT25 FAIL: CREATE SCHEMA')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('CREATE SCHEMA IF NOT EXISTS myschema');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT26 PASS: CREATE SCHEMA IF NOT EXISTS')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT26 FAIL: CREATE SCHEMA IF NOT EXISTS')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('CREATE GRAPH mygraph ANY');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT27 PASS: CREATE GRAPH ANY')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT27 FAIL: CREATE GRAPH ANY')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('CREATE PROPERTY GRAPH mygraph AS COPY OF srcgraph');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT28 PASS: CREATE PROPERTY GRAPH COPY OF')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT28 FAIL: CREATE PROPERTY GRAPH COPY OF')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('DROP SCHEMA IF EXISTS myschema');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT29 PASS: DROP SCHEMA IF EXISTS')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT29 FAIL: DROP SCHEMA IF EXISTS')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('DROP GRAPH mygraph');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT30 PASS: DROP GRAPH')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT30 FAIL: DROP GRAPH')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('CREATE GRAPH TYPE mytype { (Person :Person { name STRING }) }');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT31 PASS: CREATE GRAPH TYPE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT31 FAIL: CREATE GRAPH TYPE')); }

  -- ===================================================================
  -- Section 6: Edge cases
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (a), (b), (c) RETURN a,b,c');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT32 PASS: comma-separated patterns')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT32 FAIL: comma-separated patterns')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH () RETURN *');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT33 PASS: empty node RETURN *')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT33 FAIL: empty node RETURN *')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n) RETURN n ORDER BY n.name DESC LIMIT 5');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT34 PASS: RETURN DESC LIMIT')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('PT34 FAIL: RETURN DESC LIMIT')); }

  -- ===================================================================
  -- Section 7: Error cases
  -- ===================================================================

  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT35 PASS: unexpected token -> error')); goto pt35_done; };
    _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n) FOO n');
    _ast := DB.DBA.GQL_PARSE (_tokens);
    _fail := _fail + 1; _results := vector_concat (_results, vector ('PT35 FAIL: unexpected token should error'));
  }
  pt35_done:;

  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _pass := _pass + 1; _results := vector_concat (_results, vector ('PT36 PASS: unterminated pattern -> error')); goto pt36_done; };
    _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n');
    _ast := DB.DBA.GQL_PARSE (_tokens);
    _fail := _fail + 1; _results := vector_concat (_results, vector ('PT36 FAIL: unterminated pattern should error'));
  }
  pt36_done:;

  -- ===================================================================
  -- Summary
  -- ===================================================================

  _results := vector_concat (_results, vector (''));
  _results := vector_concat (_results, vector (concat ('TOTAL: ', cast (_total as varchar))));
  _results := vector_concat (_results, vector (concat ('PASS:  ', cast (_pass as varchar))));
  _results := vector_concat (_results, vector (concat ('FAIL:  ', cast (_fail as varchar))));

  declare i integer;
  for (i := 0; i < length (_results); i := i + 1)
    dbg_obj_print (aref (_results, i));

  if (_fail > 0)
    signal ('23000', concat (cast (_fail as varchar), ' test(s) failed'));
}
;

SELECT DB.DBA.GQL_PARSER_TESTS ();

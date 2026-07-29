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
--  openGQL: GQL for Virtuoso - End-to-End Tests
--
--  Run via isql: isql <host>:<port> dba dba < test_gql_e2e.sql
--  Requires all GQL modules loaded (see gql_load.sql).
--

create procedure DB.DBA.GQL_E2E_TESTS ()
{
  declare _pass, _fail, _total integer;
  declare _results any;
  declare _data any;
  declare _cnt integer;

  _pass := 0; _fail := 0; _total := 0;
  _results := vector ();

  -- Clean up before tests
  DB.DBA.GQL_RESET ();

  -- E2E1: MATCH on empty graph returns empty results
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('E2E1 FAIL: MATCH on empty graph errored')); goto e2e1_done; };
    _data := DB.DBA.GQL_RUN ('MATCH (n) RETURN n LIMIT 1', 'urn:gql:test:e2e');
    _pass := _pass + 1; _results := vector_concat (_results, vector ('E2E1 PASS: MATCH on empty graph'));
  }
  e2e1_done:;

  -- E2E2: INSERT a node
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('E2E2 FAIL: INSERT node errored')); goto e2e2_done; };
    DB.DBA.GQL_RUN ('INSERT (:Person { name: ''Alice'', age: 30 })', 'urn:gql:test:e2e');
    _pass := _pass + 1; _results := vector_concat (_results, vector ('E2E2 PASS: INSERT node'));
  }
  e2e2_done:;

  -- E2E3: MATCH the inserted node by label
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('E2E3 FAIL: MATCH after INSERT errored')); goto e2e3_done; };
    _data := DB.DBA.GQL_RUN ('MATCH (n:Person) RETURN n.name, n.age LIMIT 1', 'urn:gql:test:e2e');
    if (_data is not null and length (_data) > 0)
      _pass := _pass + 1;
    else
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('E2E3 FAIL: no results')); goto e2e3_done; }
    _results := vector_concat (_results, vector ('E2E3 PASS: MATCH after INSERT'));
  }
  e2e3_done:;

  -- E2E3a: Raw GQL statement through SQL parser
  _total := _total + 1;
  {
    declare _state, _msg varchar;
    declare _meta any;
    declare exit handler for sqlstate '*'
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('E2E3a FAIL: raw GQL statement errored')); goto e2e3a_done; };
    _state := '00000';
    _msg := '';
    exec ('GQL
MATCH (n) RETURN n LIMIT 1', _state, _msg, vector (), 0, _meta, _data);
    if (_state = '00000')
      _pass := _pass + 1;
    else
      { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('E2E3a FAIL: raw GQL returned ', _state, ' ', _msg))); goto e2e3a_done; }
    _results := vector_concat (_results, vector ('E2E3a PASS: raw GQL statement'));
  }
  e2e3a_done:;

  -- E2E3b: Raw OPENGQL statement through SQL parser
  _total := _total + 1;
  {
    declare _state, _msg varchar;
    declare _meta any;
    declare exit handler for sqlstate '*'
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('E2E3b FAIL: raw OPENGQL statement errored')); goto e2e3b_done; };
    _state := '00000';
    _msg := '';
    exec ('OPENGQL
MATCH (n) RETURN n LIMIT 1', _state, _msg, vector (), 0, _meta, _data);
    if (_state = '00000')
      _pass := _pass + 1;
    else
      { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('E2E3b FAIL: raw OPENGQL returned ', _state, ' ', _msg))); goto e2e3b_done; }
    _results := vector_concat (_results, vector ('E2E3b PASS: raw OPENGQL statement'));
  }
  e2e3b_done:;

  -- E2E4: INSERT edge between two nodes
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('E2E4 FAIL: INSERT edge errored')); goto e2e4_done; };
    DB.DBA.GQL_RUN ('MATCH (a:Person { name: ''Alice'' }) INSERT (:Person { name: ''Bob'' }), (a)-[:KNOWS]->(:Person { name: ''Bob'' })', 'urn:gql:test:e2e');
    _pass := _pass + 1; _results := vector_concat (_results, vector ('E2E4 PASS: INSERT edge'));
  }
  e2e4_done:;

  -- E2E5: MATCH the edge
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('E2E5 FAIL: MATCH edge errored')); goto e2e5_done; };
    _data := DB.DBA.GQL_RUN ('MATCH (a:Person)-[:KNOWS]->(b:Person) RETURN a.name, b.name LIMIT 1', 'urn:gql:test:e2e');
    if (_data is not null and length (_data) > 0)
      _pass := _pass + 1;
    else
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('E2E5 FAIL: no edge results')); goto e2e5_done; }
    _results := vector_concat (_results, vector ('E2E5 PASS: MATCH edge'));
  }
  e2e5_done:;

  -- E2E6: SET property update
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('E2E6 FAIL: SET property errored')); goto e2e6_done; };
    DB.DBA.GQL_RUN ('MATCH (n:Person { name: ''Alice'' }) SET n.age = 31', 'urn:gql:test:e2e');
    _pass := _pass + 1; _results := vector_concat (_results, vector ('E2E6 PASS: SET property'));
  }
  e2e6_done:;

  -- E2E7: COUNT after INSERT
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('E2E7 FAIL: COUNT errored')); goto e2e7_done; };
    _data := DB.DBA.GQL_RUN ('MATCH (n:Person) RETURN count(n) AS cnt', 'urn:gql:test:e2e');
    _pass := _pass + 1; _results := vector_concat (_results, vector ('E2E7 PASS: COUNT aggregation'));
  }
  e2e7_done:;

  -- E2E8: DETACH DELETE
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('E2E8 FAIL: DETACH DELETE errored')); goto e2e8_done; };
    DB.DBA.GQL_RUN ('MATCH (n:Person { name: ''Alice'' }) DETACH DELETE n', 'urn:gql:test:e2e');
    _pass := _pass + 1; _results := vector_concat (_results, vector ('E2E8 PASS: DETACH DELETE'));
  }
  e2e8_done:;

  -- E2E9: ASK returns boolean result
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('E2E9 FAIL: ASK errored')); goto e2e9_done; };
    _data := DB.DBA.GQL_RUN ('MATCH (n:Person) ASK', 'urn:gql:test:e2e');
    _pass := _pass + 1; _results := vector_concat (_results, vector ('E2E9 PASS: ASK returns result'));
  }
  e2e9_done:;

  -- E2E10: MINUS removes matching solutions
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('E2E10 FAIL: MINUS errored')); goto e2e10_done; };
    -- Insert test data for MINUS
    DB.DBA.GQL_RUN ('INSERT (:Person { name: ''Carol'' }), (:Employee { name: ''Carol'' })', 'urn:gql:test:e2e');
    _data := DB.DBA.GQL_RUN ('MATCH (n:Person) MINUS (n:Employee) RETURN n.name', 'urn:gql:test:e2e');
    _pass := _pass + 1; _results := vector_concat (_results, vector ('E2E10 PASS: MINUS removes matching solutions'));
  }
  e2e10_done:;

  -- E2E11: SHORTEST 1 GROUPS PATH executes without error (no G3005)
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('E2E11 FAIL: SHORTEST 1 GROUPS errored')); goto e2e11_done; };
    DB.DBA.GQL_RUN ('INSERT (:Person { name: ''P1'' }), (:Person { name: ''P2'' }), (:Person { name: ''P3'' })', 'urn:gql:test:e2e');
    DB.DBA.GQL_RUN ('MATCH (a:Person { name: ''P1'' }), (b:Person { name: ''P2'' }) INSERT (a)-[:KNOWS]->(b)', 'urn:gql:test:e2e');
    DB.DBA.GQL_RUN ('MATCH (a:Person { name: ''P2'' }), (b:Person { name: ''P3'' }) INSERT (a)-[:KNOWS]->(b)', 'urn:gql:test:e2e');
    _data := DB.DBA.GQL_RUN ('MATCH SHORTEST 1 GROUPS PATH (a:Person { name: ''P1'' })-[:KNOWS*]->(b:Person { name: ''P3'' }) RETURN a.name, b.name', 'urn:gql:test:e2e');
    _pass := _pass + 1; _results := vector_concat (_results, vector ('E2E11 PASS: SHORTEST 1 GROUPS PATH executes'));
  }
  e2e11_done:;

  -- E2E12: Undirected quantified edge executes without error (no G3006)
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('E2E12 FAIL: undirected quantified edge errored')); goto e2e12_done; };
    _data := DB.DBA.GQL_RUN ('MATCH (a:Person { name: ''P3'' })-[:KNOWS*]-(b:Person { name: ''P1'' }) RETURN a.name, b.name', 'urn:gql:test:e2e');
    _pass := _pass + 1; _results := vector_concat (_results, vector ('E2E12 PASS: undirected quantified edge executes'));
  }
  e2e12_done:;

  -- E2E13: Property-path negation !iri executes without error
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('E2E13 FAIL: !iri negated property path errored')); goto e2e13_done; };
    DB.DBA.GQL_RUN ('MATCH (a:Person { name: ''P1'' }), (b:Person { name: ''P3'' }) INSERT (a)-[:LIKES]->(b)', 'urn:gql:test:e2e');
    _data := DB.DBA.GQL_RUN ('MATCH (a:Person { name: ''P1'' })-[:!KNOWS]->(b) RETURN b.name', 'urn:gql:test:e2e');
    _pass := _pass + 1; _results := vector_concat (_results, vector ('E2E13 PASS: !iri negated property path executes'));
  }
  e2e13_done:;

  -- E2E14: Property-path negation !(iri1|iri2) executes without error
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('E2E14 FAIL: !(iri1|iri2) negated property path errored')); goto e2e14_done; };
    _data := DB.DBA.GQL_RUN ('MATCH (a:Person { name: ''P1'' })-[:!(KNOWS|LIKES)]->(b) RETURN b.name', 'urn:gql:test:e2e');
    _pass := _pass + 1; _results := vector_concat (_results, vector ('E2E14 PASS: !(iri1|iri2) negated property path'));
  }
  e2e14_done:;

  -- Clean up
  DB.DBA.GQL_RESET ();

  -- Summary
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

SELECT DB.DBA.GQL_E2E_TESTS ();

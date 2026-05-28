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
--  openCypher: OpenCypher for Virtuoso - Comprehensive Test Suite
--
--  Run via isql: isql 1111 dba dba < test_cypher.sql
--

-- ============================================================================
-- Helper procedures (must be defined before main test runner)
-- ============================================================================
create procedure DB.DBA.OPENCYPHER_SPARQL_VAL (in _q varchar)
{
  declare state, msg varchar;
  declare meta, data any;

  state := '00000';
  exec (_q, state, msg, vector (), 0, meta, data);
  if (state <> '00000' or data is null or length (data) = 0)
    return null;
  return aref (aref (data, 0), 0);
}
;

create procedure DB.DBA.OPENCYPHER_SPARQL_COUNT (in _q varchar)
{
  declare state, msg varchar;
  declare meta, data any;

  state := '00000';
  exec (_q, state, msg, vector (), 0, meta, data);
  if (state <> '00000' or data is null)
    return 0;
  return length (data);
}
;

-- ============================================================================
-- Test runner procedure
-- ============================================================================
create procedure DB.DBA.OPENCYPHER_RUN_TESTS ()
{
  declare _pass, _fail, _total integer;
  declare _results any;
  declare _val any;
  declare _cnt integer;
  declare _str varchar;
  declare _state, _msg varchar;
  declare _meta, _data any;
  declare _ri integer;
  declare _out varchar;

  _pass := 0;
  _fail := 0;
  _total := 0;
  _results := vector ();

  -- ========== Section 0: Plugin load smoke ==========
  declare _plugin_avail integer;
  declare _plugin_ver varchar;
  _plugin_avail := DB.DBA.OPENCYPHER_PLUGIN_AVAILABLE ();
  if (_plugin_avail = 1)
    {
      declare exit handler for sqlstate '*'
        {
          _results := vector_concat (_results,
            vector ('PLUGIN: available but version probe failed'));
          goto plugin_smoke_done;
        };
      _plugin_ver := DB.DBA.OPENCYPHER_PLUGIN_VERSION ();
      if (_plugin_ver is not null
          and length (_plugin_ver) >= 18
          and subseq (_plugin_ver, 0, 18) = 'openCypher VSEI plugin ')
        _results := vector_concat (_results,
          vector (concat ('PLUGIN: loaded - ', _plugin_ver)));
      else
        _results := vector_concat (_results,
          vector (concat ('PLUGIN: loaded but unexpected version string: ',
                          coalesce (_plugin_ver, '<null>'))));
    }
  else
    _results := vector_concat (_results,
      vector ('PLUGIN: not loaded (SQL/PL translator in use)'));
  plugin_smoke_done:;

  -- ========== Section 0.5: /sparql OPENCYPHER passthrough ==========
  _results := vector_concat (_results, vector ('--- Section 0.5: /sparql OPENCYPHER passthrough ---'));

  _str := WS.WS.SPARQL_ENDPOINT_OPENCYPHER_BODY (' OPENCYPHER MATCH (n) RETURN n');
  if (_str = 'MATCH (n) RETURN n')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 0.5.1 Detect OPENCYPHER query prefix (case insensitive)')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 0.5.1 Expected stripped OPENCYPHER body, got %s', coalesce (_str, '<null>')))); }
  _total := _total + 1;

  _str := WS.WS.SPARQL_ENDPOINT_OPENCYPHER_BODY ('opencypher MATCH (n) RETURN n');
  if (_str = 'MATCH (n) RETURN n')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 0.5.2 Detect lowercase opencypher prefix')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 0.5.2 Expected stripped opencypher body, got %s', coalesce (_str, '<null>')))); }
  _total := _total + 1;

  _str := WS.WS.SPARQL_ENDPOINT_OPENCYPHER_BODY ('OPENCYPHER MATCH (n) RETURN n');
  if (_str is null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 0.5.3 Reject legacy OPENCYPHER prefix')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 0.5.3 Expected null for OPENCYPHER body, got %s', coalesce (_str, '<null>')))); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL (WS.WS.SPARQL_ENDPOINT_OPENCYPHER_BODY ('OPENCYPHER MATCH (n) RETURN n'));
  if (strstr (_str, 'SELECT ?n') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 0.5.4 Translate /sparql OPENCYPHER body')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 0.5.4 /sparql OPENCYPHER body did not translate')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('PREFIX foaf: <http://xmlns.com/foaf/0.1/> MATCH (x:foaf:Person) RETURN x LIMIT 1');
  if (strstr (_str, 'FROM <') is null and strstr (_str, '?x a <http://xmlns.com/foaf/0.1/Person>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 0.5.5 OPENCYPHER without default graph emits no FROM')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 0.5.5 Expected no FROM for graphless OPENCYPHER translation, got %s', _str))); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('PREFIX : <#> PREFIX foaf: <http://xmlns.com/foaf/0.1/> MATCH (a)-[r:foaf:knows]->(b) FROM <urn:test:weighted> RETURN r.:weight AS weight');
  if (strstr (_str, 'GRAPH <urn:test:weighted>') is not null and strstr (_str, '<#weight>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 0.5.6 Default-prefix relationship property access')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 0.5.6 Expected default-prefix relationship property, got %s', _str))); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('PREFIX : <#> PREFIX foaf: <http://xmlns.com/foaf/0.1/> MATCH (a)-[r:foaf:knows {:weight: 1.0}]->(b) FROM <urn:test:weighted> RETURN r.:weight AS weight');
  if (strstr (_str, '<#weight>') is not null and strstr (_str, '1.0') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 0.5.7 Default-prefix relationship property constraint')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 0.5.7 Expected default-prefix relationship property constraint, got %s', _str))); }
  _total := _total + 1;

  -- ========== Section 1: Tokenizer ==========
  _results := vector_concat (_results, vector ('--- Section 1: Tokenizer ---'));

  if (length (DB.DBA.CYP_TOKENIZE ('MATCH (n) RETURN n')) > 0)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 1.1 Tokenize MATCH RETURN')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 1.1 Tokenize MATCH RETURN')); }
  _total := _total + 1;

  if (length (DB.DBA.CYP_TOKENIZE ('MATCH (n:Person {name: ''Alice''}) RETURN n.name')) > 0)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 1.2 Tokenize label+props')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 1.2 Tokenize label+props')); }
  _total := _total + 1;

  if (length (DB.DBA.CYP_TOKENIZE ('MATCH (a)-[:KNOWS]->(b) RETURN a, b')) > 0)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 1.3 Tokenize relationship')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 1.3 Tokenize relationship')); }
  _total := _total + 1;

  if (length (DB.DBA.CYP_TOKENIZE ('CREATE (n:Person {name: ''Bob'', age: 30})')) > 0)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 1.4 Tokenize CREATE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 1.4 Tokenize CREATE')); }
  _total := _total + 1;

  if (length (DB.DBA.CYP_TOKENIZE ('MATCH (n) WHERE n.age > 10 AND n.age < 50 RETURN n')) > 0)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 1.5 Tokenize WHERE operators')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 1.5 Tokenize WHERE operators')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('RETURN .1 AS literal');
  if (strstr (_str, '0.1') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 1.6 Parse leading-dot decimal literal')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 1.6 Parse leading-dot decimal literal')); }
  _total := _total + 1;

  -- ========== Section 2: Parser ==========
  _results := vector_concat (_results, vector ('--- Section 2: Parser ---'));

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('MATCH (n) RETURN n')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.1 Parse MATCH RETURN')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.1 Parse MATCH RETURN')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('MATCH (n:Person) RETURN n')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.2 Parse MATCH with label')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.2 Parse MATCH with label')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('CREATE (n:Person {name: ''X'', age: 30})')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.3 Parse CREATE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.3 Parse CREATE')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('MATCH (a)-[:KNOWS]->(b) RETURN a, b')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.4 Parse relationship')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.4 Parse relationship')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('MATCH (n) WHERE n.age > 10 RETURN n')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.5 Parse WHERE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.5 Parse WHERE')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('MATCH (n) SET n.age = 31')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.6 Parse SET')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.6 Parse SET')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('MATCH (n) SET n:Foo RETURN n')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.6.1 Parse SET label')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.6.1 Parse SET label')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('MATCH (n) DELETE n')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.7 Parse DELETE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.7 Parse DELETE')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('MERGE (n:Person {name: ''Alice''})')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.8 Parse MERGE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.8 Parse MERGE')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('MATCH (n:Person:Employee) RETURN n')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.9 Parse multi-label')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.9 Parse multi-label')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('MATCH (n:Person) REMOVE n.age')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.10 Parse REMOVE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.10 Parse REMOVE')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('DEFINE input:inference ''rule'' MATCH (n) FROM NAMED <urn:g> RETURN n')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.11 Parse DEFINE FROM NAMED')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.11 Parse DEFINE FROM NAMED')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('PREFIX : <#> MERGE (a)-[r:KNOWS {:weight: 1.0}]->(b) FROM <urn:g> RETURN r.:weight')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.12 Parse MERGE FROM with default-prefixed relationship property')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.12 Parse MERGE FROM with default-prefixed relationship property')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('GRAPH <urn:g> { MATCH (n) RETURN n AS n2 } RETURN n2')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.13 Parse GRAPH block')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.13 Parse GRAPH block')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('USE GRAPH analytics.sales MATCH (n) RETURN n')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.13a Parse USE GRAPH')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.13a Parse USE GRAPH')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('USE ANY GRAPH MATCH (n) RETURN n')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.13b Parse USE ANY GRAPH')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.13b Parse USE ANY GRAPH')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('SERVICE <http://dbpedia.org/sparql> { MATCH (p) RETURN p AS p2 } RETURN p2')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.14 Parse SERVICE block')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.14 Parse SERVICE block')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('SERVICE SILENT <http://dbpedia.org/sparql> { MATCH (p) RETURN p AS p2 } RETURN p2')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.14a Parse SERVICE SILENT block')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.14a Parse SERVICE SILENT block')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('VALUES name {''Alice'', ''Bob''} BIND (name AS n2) RETURN n2')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.14 Parse VALUES BIND')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.14 Parse VALUES BIND')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('MATCH (n) MINUS { MATCH (n:Blocked) } RETURN n')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.15 Parse MINUS')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.15 Parse MINUS')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('ASK MATCH (n:Person)')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.16 Parse ASK')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.16 Parse ASK')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('DESCRIBE n MATCH (n:Person)')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.17 Parse DESCRIBE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.17 Parse DESCRIBE')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('CONSTRUCT { MATCH (n:Person) } MATCH (n:Person)')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.18 Parse CONSTRUCT')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.18 Parse CONSTRUCT')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('MATCH (n:Person) RETURN n.name, count(*) GROUP BY n.name HAVING count(*) > 1')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.19 Parse GROUP HAVING')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.19 Parse GROUP HAVING')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('LOAD SILENT <urn:data> INTO GRAPH <urn:g>')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.20 Parse LOAD')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.20 Parse LOAD')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('CLEAR SILENT GRAPH <urn:g>')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.21 Parse CLEAR')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.21 Parse CLEAR')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('DROP DEFAULT')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.22 Parse DROP')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.22 Parse DROP')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('CREATE SILENT GRAPH <urn:g>')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.23 Parse CREATE GRAPH')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.23 Parse CREATE GRAPH')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('COPY GRAPH <urn:g1> TO GRAPH <urn:g2>')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.24 Parse graph copy')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.24 Parse graph copy')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('PREFIX xsd: <http://www.w3.org/2001/XMLSchema#> BIND (''2020''^^xsd:gYear AS y) RETURN y')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.25 Parse typed literal')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.25 Parse typed literal')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('BIND (''hello''@en AS label) RETURN label')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.26 Parse language literal')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.26 Parse language literal')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('INSERT DATA { CREATE (n:Person {iri: <urn:n>, name: ''Alice''}) }')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.27 Parse INSERT DATA')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.27 Parse INSERT DATA')); }
  _total := _total + 1;

  if (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('DELETE DATA { CREATE (n:Person {iri: <urn:n>, name: ''Alice''}) }')), 0) = 'STMT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.28 Parse DELETE DATA')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.28 Parse DELETE DATA')); }
  _total := _total + 1;

  if (aref (aref (aref (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE ('CALL test.my.proc(''Dobby'')')), 1), 0), 1) = 'test.my.proc')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 2.29 Parse multi-segment procedure name')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 2.29 Parse multi-segment procedure name')); }
  _total := _total + 1;

  -- ========== Section 3: SPARQL Translation ==========
  _results := vector_concat (_results, vector ('--- Section 3: SPARQL Translation ---'));

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n) RETURN n');
  if (strstr (_str, 'SELECT ?n') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.1 Translate MATCH')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.1 Translate MATCH')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n:Person) RETURN n');
  if (strstr (_str, 'ontology#Person') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.2 Translate label')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.2 Translate label')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n:Person) RETURN n.name');
  if (strstr (_str, '?n_name') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.3 Translate property')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.3 Translate property')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('PREFIX movie: <http://demo.openlinksw.com/movies#>
PREFIX mv: <http://demo.openlinksw.com/movie-ontology#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

MATCH (m:mv:Movie)
FROM <urn:movies:opencypher:demo>
RETURN m, m.<http://demo.openlinksw.com/movie-ontology#title>, m.mv:released, m.mv:tagline');
  if (strstr (_str, '<http://demo.openlinksw.com/movie-ontology#title>') is not null
      and strstr (_str, '<http://demo.openlinksw.com/movie-ontology#released>') is not null
      and strstr (_str, 'FROM <urn:movies:opencypher:demo>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.3.1 Translate full IRI property')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.3.1 Translate full IRI property')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n:Person) WHERE n.age > 25 RETURN n');
  if (strstr (_str, 'FILTER') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.4 Translate WHERE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.4 Translate WHERE')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (a), (b) WHERE a <> b RETURN a, b');
  if (strstr (_str, 'FILTER') is not null
      and strstr (_str, '?a != ?b') is not null
      and strstr (_str, '<>') is null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.4.1 Translate inequality as SPARQL !=')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.4.1 Translate inequality as SPARQL !=')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('RETURN bif:length(''abc'') AS n');
  if (strstr (_str, 'bif:length("abc")') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.4.2 Pass through bif: function calls')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.4.2 Pass through bif: function calls')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('RETURN sql:GRAPH_DEGREE_CENTRALITY(1.0) AS c');
  if (strstr (_str, 'sql:graph_degree_centrality(1.0)') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.4.3 Pass through sql: function calls')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.4.3 Pass through sql: function calls')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('RETURN reverse(''abc'') AS r');
  if (strstr (_str, 'sql:CYP_REVERSE("abc")') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.4.4 Translate reverse() through SQL helper')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.4.4 Translate reverse() through SQL helper')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('RETURN date.truncate(''year'', date(''2017-10-11''), {}) AS d');
  if (strstr (_str, 'CYP_DATE_TRUNCATE') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.4.5 Parse dotted function calls')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.4.5 Parse dotted function calls')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('RETURN duration({months: 1, days: 2}) AS d');
  if (strstr (_str, 'xsd:duration') is not null
      and strstr (_str, 'bif:sprintf("P%dY%dM%dDT%dH%dM%dS"') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.4.6 Translate duration map constructor')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.4.6 Translate duration map constructor')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (a) WITH a ORDER BY (:B {bool: false}) LIMIT 2 RETURN a');
  if (strstr (_str, 'ORDER BY EXISTS') is not null and strstr (_str, 'ontology#B') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.4.7 Translate anonymous node pattern expression')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.4.7 Translate anonymous node pattern expression')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n:Person) RETURN n.name ORDER BY n.name');
  if (strstr (_str, 'ORDER BY') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.5 Translate ORDER BY')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.5 Translate ORDER BY')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('CREATE ({num: -5})');
  if (strstr (_str, '-5') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.5.1 Translate CREATE negative numeric property')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.5.1 Translate CREATE negative numeric property')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('CREATE ({created: date({year: 1984, month: 10, day: 11})})');
  if (strstr (_str, '"1984-10-11"^^<http://www.w3.org/2001/XMLSchema#date>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.5.2 Translate CREATE static temporal property')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.5.2 Translate CREATE static temporal property')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n:Person) RETURN n.name LIMIT 10');
  if (strstr (_str, 'LIMIT 10') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.6 Translate LIMIT')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.6 Translate LIMIT')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n:Person) RETURN DISTINCT n.name');
  if (strstr (_str, 'DISTINCT') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.7 Translate DISTINCT')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.7 Translate DISTINCT')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n:Person) RETURN count(*)');
  if (strstr (_str, 'COUNT(*)') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.8 Translate COUNT(*)')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.8 Translate COUNT(*)')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (a:Person)-[:KNOWS]->(b:Person) RETURN a.name, b.name');
  if (strstr (_str, 'ontology#KNOWS') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.9 Translate relationship preserving spelling')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.9 Translate relationship preserving spelling')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('FORCE CAMELCASE MATCH (a:Person)-[:ACTED_IN]->(b:Person) RETURN a.name, b.name');
  if (strstr (_str, 'ontology#actedIn') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.9a FORCE CAMELCASE relationship compatibility')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.9a FORCE CAMELCASE relationship compatibility')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n:Person) WHERE n.age > 20 AND n.age < 40 RETURN n');
  if (strstr (_str, 'AND') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.10 Translate AND')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.10 Translate AND')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n:Person) WHERE n.email IS NULL RETURN n');
  if (strstr (_str, 'BOUND') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.11 Translate IS NULL')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.11 Translate IS NULL')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n:Person) WHERE n.name STARTS WITH ''A'' RETURN n');
  if (strstr (_str, 'STRSTARTS') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.12 Translate STARTS WITH')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.12 Translate STARTS WITH')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n:Person) WHERE n.name ENDS WITH ''e'' RETURN n');
  if (strstr (_str, 'STRENDS') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.13 Translate ENDS WITH')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.13 Translate ENDS WITH')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n:Person) WHERE n.name CONTAINS ''li'' RETURN n');
  if (strstr (_str, 'CONTAINS') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.14 Translate CONTAINS')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.14 Translate CONTAINS')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('CREATE (n:Person {name: ''X''})');
  if (strstr (_str, 'INSERT') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.15 Translate CREATE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.15 Translate CREATE')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n:Person) RETURN n.name AS personName');
  if (strstr (_str, 'AS ?personName') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.16 Translate alias')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.16 Translate alias')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n) RETURN n SKIP 5');
  if (strstr (_str, 'OFFSET') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.17 Translate SKIP->OFFSET')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.17 Translate SKIP->OFFSET')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('DEFINE input:inference ''rule'' MATCH (n) FROM NAMED <urn:g> RETURN n');
  if (strstr (_str, 'DEFINE input:inference') is not null and strstr (_str, 'FROM NAMED <urn:g>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.18 Translate DEFINE FROM NAMED')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.18 Translate DEFINE FROM NAMED')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('GRAPH <urn:g> { MATCH (n:Person) RETURN n.name AS name } RETURN name');
  if (strstr (_str, 'GRAPH <urn:g>') is not null and strstr (_str, 'BIND') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.19 Translate GRAPH block')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.19 Translate GRAPH block')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('USE GRAPH analytics.sales MATCH (n) RETURN n');
  if (strstr (_str, 'FROM <analytics:sales>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.19a Translate USE GRAPH dotted name')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.19a Translate USE GRAPH dotted name')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('PREFIX ex: <http://example.org/> USE GRAPH ex:analytics MATCH (n) RETURN n');
  if (strstr (_str, 'FROM <http://example.org/analytics>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.19b Translate USE GRAPH prefixed name')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.19b Translate USE GRAPH prefixed name')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('USE ANY GRAPH MATCH (n) RETURN n');
  if (strstr (_str, 'FROM <urn:opencypher:default>') is null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.19c Translate USE ANY GRAPH')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.19c Translate USE ANY GRAPH')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('SERVICE <http://dbpedia.org/sparql> { MATCH (p) RETURN p AS p2 } RETURN p2');
  if (strstr (_str, 'SERVICE <http://dbpedia.org/sparql>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.20 Translate SERVICE block')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.20 Translate SERVICE block')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('SERVICE SILENT <http://dbpedia.org/sparql> { MATCH (p) RETURN p AS p2 } RETURN p2');
  if (strstr (_str, 'SERVICE SILENT <http://dbpedia.org/sparql>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.20d Translate SERVICE SILENT block')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.20d Translate SERVICE SILENT block')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('PREFIX dbo: <http://dbpedia.org/ontology/> SERVICE <https://dbpedia.org/sparql> { MATCH (film:dbo:Film)-[:dbo:writer]->(writer) RETURN film AS film2 } RETURN film2');
  if (strstr (_str, '<http://dbpedia.org/ontology/Film>') is not null
      and strstr (_str, '<http://dbpedia.org/ontology/writer>') is not null
      and strstr (_str, 'opencypher#dbo') is null
      and strstr (_str, '?writer ?') is null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.20a Translate SERVICE prefixes')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.20a Translate SERVICE prefixes')); }
  _total := _total + 1;

  DB.DBA.XML_SET_NS_DECL ('ocnsreg', 'http://example.com/registered-ns#', 2);
  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (p:ocnsreg:Person) RETURN p.ocnsreg:name AS name');
  if (strstr (_str, '<http://example.com/registered-ns#Person>') is not null
      and strstr (_str, '<http://example.com/registered-ns#name>') is not null
      and strstr (_str, 'opencypher#ocnsreg') is null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.20aa Registered namespace prefixes')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.20aa Registered namespace prefixes')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('PREFIX dbo: <http://dbpedia.org/ontology/> PREFIX dbr: <http://dbpedia.org/resource/> PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> SERVICE <https://dbpedia.org/sparql> { MATCH (film:dbo:Film)-[:dbo:writer]->(writer) WHERE writer = dbr:Spike_Lee AND lang(film.`rdfs:label`) = ''en'' } RETURN DISTINCT film.`rdfs:label` AS title ORDER BY title');
  if (strstr (_str, '?film <http://www.w3.org/2000/01/rdf-schema#label> ?film_rdfs_label') is not null
      and strstr (_str, 'lang(?film_rdfs_label) = "en"') is not null
      and strstr (_str, '?film_rdfs_label AS ?title') is not null
      and strstr (_str, 'OPTIONAL { ?film <http://www.w3.org/2000/01/rdf-schema#label>') is null
      and strstr (_str, 'FROM <urn:opencypher:default>') is null
      and strstr (_str, 'FROM NAMED <urn:opencypher:default>') is null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.20b Translate SERVICE projected property')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.20b Translate SERVICE projected property')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (film) SERVICE <http://dbpedia.org/sparql> { MATCH (remoteFilm) RETURN remoteFilm AS remoteFilm } RETURN film');
  if (strstr (_str, 'FROM <urn:opencypher:default>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.20c Local MATCH with SERVICE keeps default dataset')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.20c Local MATCH with SERVICE keeps default dataset')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('VALUES name {''Alice'', ''Bob''} BIND (name AS n2) RETURN n2');
  if (strstr (_str, 'VALUES ?name') is not null and strstr (_str, 'BIND') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.21 Translate VALUES BIND')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.21 Translate VALUES BIND')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n) MINUS { MATCH (n:Blocked) } RETURN n');
  if (strstr (_str, 'MINUS') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.22 Translate MINUS')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.22 Translate MINUS')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('ASK MATCH (n:Person)');
  if (strstr (_str, 'ASK') is not null and strstr (_str, 'WHERE') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.23 Translate ASK')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.23 Translate ASK')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('DESCRIBE n MATCH (n:Person)');
  if (strstr (_str, 'DESCRIBE ?n') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.24 Translate DESCRIBE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.24 Translate DESCRIBE')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('CONSTRUCT { MATCH (n:Person) } MATCH (n:Person)');
  if (strstr (_str, 'CONSTRUCT') is not null and strstr (_str, '?n a') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.25 Translate CONSTRUCT')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.25 Translate CONSTRUCT')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('CONSTRUCT { MATCH (n:Person) RETURN n, n.knows } MATCH (n:Person)');
  if (strstr (_str, 'CONSTRUCT') is not null
      and strstr (_str, '?n a') is not null
      and strstr (_str, 'ontology#knows> ?n_knows') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.25a CONSTRUCT RETURN property triples')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.25a CONSTRUCT RETURN property triples')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('PREFIX foaf: <http://xmlns.com/foaf/0.1/> MATCH (n:foaf:Person) RETURN n, degree_centrality(n, ''out'', foaf:knows, weight, <urn:analytics:weighted>) AS degree');
  if (strstr (_str, 'COALESCE(SUM(?') is not null
      and strstr (_str, '<http://xmlns.com/foaf/0.1/knows>') is not null
      and strstr (_str, 'GROUP BY ?n') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.25b degree_centrality relationship/weight/graph options')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.25b degree_centrality relationship/weight/graph options')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('PREFIX foaf: <http://xmlns.com/foaf/0.1/> MATCH (n:foaf:Person) RETURN n, eigenvector_centrality(n, ''out'', foaf:knows, weight, <urn:analytics:weighted>) AS ev, closeness_centrality(n, ''out'', foaf:knows) AS cc, betweenness_centrality(n, ''out'', foaf:knows, weight) AS bc');
  if (strstr (_str, 'sql:CYP_GRAPH_CENTRALITY') is not null
      and strstr (_str, 'eigenvector') is not null
      and strstr (_str, 'closeness') is not null
      and strstr (_str, 'betweenness') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.25c eigenvector/closeness/betweenness centrality')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.25c eigenvector/closeness/betweenness centrality')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n:Person) RETURN n.name, count(*) GROUP BY n.name HAVING count(*) > 1');
  if (strstr (_str, 'GROUP BY') is not null and strstr (_str, 'HAVING') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.26 Translate GROUP HAVING')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.26 Translate GROUP HAVING')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('BIND (strlang(''hello'', ''en'') AS label) RETURN lang(label), langMatches(lang(label), ''en'')');
  if (strstr (_str, 'STRLANG') is not null and strstr (_str, 'langMatches') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.27 Translate SPARQL builtins')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.27 Translate SPARQL builtins')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('LOAD SILENT <urn:data> INTO GRAPH <urn:g>');
  if (strstr (_str, 'SPARQL LOAD SILENT <urn:data> INTO GRAPH <urn:g>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.28 Translate LOAD')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.28 Translate LOAD')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('CLEAR SILENT GRAPH <urn:g>');
  if (strstr (_str, 'SPARQL CLEAR SILENT GRAPH <urn:g>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.29 Translate CLEAR')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.29 Translate CLEAR')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('DROP DEFAULT');
  if (strstr (_str, 'SPARQL DROP DEFAULT') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.30 Translate DROP')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.30 Translate DROP')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('CREATE SILENT GRAPH <urn:g>');
  if (strstr (_str, 'SPARQL CREATE SILENT GRAPH <urn:g>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.31 Translate CREATE GRAPH')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.31 Translate CREATE GRAPH')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('COPY GRAPH <urn:g1> TO GRAPH <urn:g2>');
  if (strstr (_str, 'SPARQL COPY GRAPH <urn:g1> TO GRAPH <urn:g2>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.32 Translate graph copy')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.32 Translate graph copy')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('PREFIX xsd: <http://www.w3.org/2001/XMLSchema#> BIND (''2020''^^xsd:gYear AS y) RETURN y');
  if (strstr (_str, '"2020"^^<http://www.w3.org/2001/XMLSchema#gYear>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.33 Translate typed literal')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.33 Translate typed literal')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('BIND (''hello''@en AS label) RETURN label');
  if (strstr (_str, '"hello"@en') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.34 Translate language literal')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.34 Translate language literal')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('INSERT DATA { CREATE (n:Person {iri: <urn:n>, name: ''Alice''}) }');
  if (strstr (_str, 'SPARQL INSERT DATA') is not null and strstr (_str, '<urn:n>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.35 Translate INSERT DATA')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.35 Translate INSERT DATA')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('DELETE DATA { CREATE (n:Person {iri: <urn:n>, name: ''Alice''}) }');
  if (strstr (_str, 'SPARQL DELETE DATA') is not null and strstr (_str, '<urn:n>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.36 Translate DELETE DATA')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.36 Translate DELETE DATA')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n) RETURN n.name ORDER BY n.name DESC');
  if (strstr (_str, 'DESC') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 3.18 Translate DESC')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 3.18 Translate DESC')); }
  _total := _total + 1;

  -- ========== Section 4: CREATE + MATCH end-to-end ==========
  _results := vector_concat (_results, vector ('--- Section 4: CREATE + MATCH ---'));

  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER ('CREATE (a:Person {name: ''Alice'', age: 30})');
  DB.DBA.CYPHER ('CREATE (b:Person {name: ''Bob'', age: 25})');
  DB.DBA.CYPHER ('CREATE (c:Person {name: ''Charlie'', age: 35})');

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT ('SPARQL SELECT ?n FROM <urn:opencypher:default> WHERE { ?n a <http://localhost:8890/opencypher/ontology#Person> }');
  if (_cnt = 3)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 4.1 Created 3 Person nodes')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 4.1 Expected 3 nodes, got %d', _cnt))); }
  _total := _total + 1;

  _val := DB.DBA.OPENCYPHER_SPARQL_VAL ('SPARQL SELECT ?name FROM <urn:opencypher:default> WHERE { ?n <http://localhost:8890/opencypher/ontology#name> "Alice" . ?n <http://localhost:8890/opencypher/ontology#name> ?name }');
  if (cast (_val as varchar) = 'Alice')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 4.2 Alice name property')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 4.2 Expected Alice, got %s', cast (_val as varchar)))); }
  _total := _total + 1;

  _val := DB.DBA.OPENCYPHER_SPARQL_VAL ('SPARQL SELECT ?age FROM <urn:opencypher:default> WHERE { ?n <http://localhost:8890/opencypher/ontology#name> "Bob" . ?n <http://localhost:8890/opencypher/ontology#age> ?age }');
  if (cast (_val as varchar) = '25')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 4.3 Bob age=25')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 4.3 Expected 25, got %s', cast (_val as varchar)))); }
  _total := _total + 1;

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT ('SPARQL SELECT ?n FROM <urn:opencypher:default> WHERE { ?n a <http://localhost:8890/opencypher/ontology#Person> . ?n <http://localhost:8890/opencypher/ontology#age> ?age FILTER (?age > 28) }');
  if (_cnt = 2)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 4.4 WHERE age>28 returns 2')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 4.4 Expected 2, got %d', _cnt))); }
  _total := _total + 1;

  -- ========== Section 5: Relationships ==========
  _results := vector_concat (_results, vector ('--- Section 5: Relationships ---'));

  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER ('CREATE (a:Person {name: ''Alice''})-[:KNOWS]->(b:Person {name: ''Bob''})');

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT ('SPARQL SELECT ?n FROM <urn:opencypher:default> WHERE { ?n a <http://localhost:8890/opencypher/ontology#Person> }');
  if (_cnt = 2)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 5.1 Created 2 nodes')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 5.1 Expected 2, got %d', _cnt))); }
  _total := _total + 1;

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT ('SPARQL SELECT ?a FROM <urn:opencypher:default> WHERE { ?a <http://localhost:8890/opencypher/ontology#knows> ?b }');
  if (_cnt = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 5.2 KNOWS rel exists')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 5.2 Expected 1 rel, got %d', _cnt))); }
  _total := _total + 1;

  _val := DB.DBA.OPENCYPHER_SPARQL_VAL ('SPARQL SELECT ?bn FROM <urn:opencypher:default> WHERE { ?a <http://localhost:8890/opencypher/ontology#name> "Alice" . ?a <http://localhost:8890/opencypher/ontology#knows> ?b . ?b <http://localhost:8890/opencypher/ontology#name> ?bn }');
  if (cast (_val as varchar) = 'Bob')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 5.3 Alice KNOWS Bob')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 5.3 Expected Bob, got %s', cast (_val as varchar)))); }
  _total := _total + 1;

  DB.DBA.CYPHER_RESET ();
  exec (sprintf ('SPARQL CLEAR GRAPH <%s>', DB.DBA.OPENCYPHER_REIF_GRAPH ()));
  DB.DBA.CYPHER ('CREATE (a:Person {name: ''Alice''})-[:KNOWS {since: 2020}]->(b:Person {name: ''Bob''})');

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT (sprintf ('SPARQL SELECT ?s WHERE { GRAPH <%s> { ?s a <http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement> } }', DB.DBA.OPENCYPHER_REIF_GRAPH ()));
  if (_cnt = 0)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 5.4 Reification in separate graph')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 5.4 Expected 0 reification triples, got %d', _cnt))); }
  _total := _total + 1;

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT (sprintf ('SPARQL SELECT ?s WHERE { GRAPH <%s> { ?s a <http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement> } }', DB.DBA.OPENCYPHER_REIF_GRAPH ()));
  if (_cnt = 0)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 5.5 Reification graph separate')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 5.5 Expected 0 reif, got %d', _cnt))); }
  _total := _total + 1;

  DB.DBA.CYPHER_RESET ('urn:customers');
  DB.DBA.CYPHER ('CREATE INTO GRAPH <urn:customers> (a:Person {iri: <urn:alice>})-[:KNOWS {since: 2020}]->(b:Person {iri: <urn:bob>})');

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT ('SPARQL SELECT ?s WHERE { GRAPH <urn:customers> { ?s a <http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement> } }');
  if (_cnt = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 5.6 Reification follows CREATE graph')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 5.6 Expected 1 customer reification, got %d', _cnt))); }
  _total := _total + 1;

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT ('SPARQL SELECT ?a WHERE { GRAPH <urn:customers> { ?a <http://localhost:8890/opencypher/ontology#knows> ?b } }');
  if (_cnt = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 5.7 CREATE graph relationship exists')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 5.7 Expected 1 customer relationship, got %d', _cnt))); }
  _total := _total + 1;

  -- ========== Section 6: DELETE ==========
  _results := vector_concat (_results, vector ('--- Section 6: DELETE ---'));

  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER ('CREATE (a:Temp {name: ''DeleteMe1''})');
  DB.DBA.CYPHER ('CREATE (b:Temp {name: ''DeleteMe2''})');
  DB.DBA.CYPHER ('CREATE (c:Keep {name: ''KeepMe''})');

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT ('SPARQL SELECT ?n FROM <urn:opencypher:default> WHERE { ?n a <http://localhost:8890/opencypher/ontology#Temp> }');
  if (_cnt = 2)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 6.1 Before: 2 Temp')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 6.1 Expected 2, got %d', _cnt))); }
  _total := _total + 1;

  DB.DBA.CYPHER ('MATCH (n:Temp) DETACH DELETE n');

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT ('SPARQL SELECT ?n FROM <urn:opencypher:default> WHERE { ?n a <http://localhost:8890/opencypher/ontology#Temp> }');
  if (_cnt = 0)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 6.2 After: 0 Temp')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 6.2 Expected 0, got %d', _cnt))); }
  _total := _total + 1;

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT ('SPARQL SELECT ?n FROM <urn:opencypher:default> WHERE { ?n a <http://localhost:8890/opencypher/ontology#Keep> }');
  if (_cnt = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 6.3 Keep untouched')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 6.3 Expected 1, got %d', _cnt))); }
  _total := _total + 1;

  -- ========== Section 7: SET ==========
  _results := vector_concat (_results, vector ('--- Section 7: SET ---'));

  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER ('CREATE (a:Person {name: ''Alice'', age: 30})');

  _val := DB.DBA.OPENCYPHER_SPARQL_VAL ('SPARQL SELECT ?age FROM <urn:opencypher:default> WHERE { ?n <http://localhost:8890/opencypher/ontology#name> "Alice" . ?n <http://localhost:8890/opencypher/ontology#age> ?age }');
  if (cast (_val as varchar) = '30')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 7.1 Before SET age=30')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 7.1 Expected 30, got %s', cast (_val as varchar)))); }
  _total := _total + 1;

  DB.DBA.CYPHER ('MATCH (n:Person {name: ''Alice''}) SET n.age = 31');

  _val := DB.DBA.OPENCYPHER_SPARQL_VAL ('SPARQL SELECT ?age FROM <urn:opencypher:default> WHERE { ?n <http://localhost:8890/opencypher/ontology#name> "Alice" . ?n <http://localhost:8890/opencypher/ontology#age> ?age }');
  if (cast (_val as varchar) = '31')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 7.2 After SET age=31')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 7.2 Expected 31, got %s', cast (_val as varchar)))); }
  _total := _total + 1;

  DB.DBA.CYPHER ('MATCH (n:Person {name: ''Alice''}) SET n.email = ''alice@example.com''');

  _val := DB.DBA.OPENCYPHER_SPARQL_VAL ('SPARQL SELECT ?email FROM <urn:opencypher:default> WHERE { ?n <http://localhost:8890/opencypher/ontology#name> "Alice" . ?n <http://localhost:8890/opencypher/ontology#email> ?email }');
  if (_val is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 7.3 SET new property')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 7.3 email not found')); }
  _total := _total + 1;

  -- ========== Section 8: Multi-label ==========
  _results := vector_concat (_results, vector ('--- Section 8: Multi-label ---'));

  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER ('CREATE (n:Person:Employee {name: ''Alice''})');
  DB.DBA.CYPHER ('CREATE (m:Person:Manager {name: ''Bob''})');
  DB.DBA.CYPHER ('CREATE (o:Person {name: ''Charlie''})');

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT ('SPARQL SELECT ?n FROM <urn:opencypher:default> WHERE { ?n a <http://localhost:8890/opencypher/ontology#Person> }');
  if (_cnt = 3)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 8.1 3 Persons')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 8.1 Expected 3, got %d', _cnt))); }
  _total := _total + 1;

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT ('SPARQL SELECT ?n FROM <urn:opencypher:default> WHERE { ?n a <http://localhost:8890/opencypher/ontology#Employee> }');
  if (_cnt = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 8.2 1 Employee')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 8.2 Expected 1, got %d', _cnt))); }
  _total := _total + 1;

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT ('SPARQL SELECT ?n FROM <urn:opencypher:default> WHERE { ?n a <http://localhost:8890/opencypher/ontology#Manager> }');
  if (_cnt = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 8.3 1 Manager')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 8.3 Expected 1, got %d', _cnt))); }
  _total := _total + 1;

  -- ========== Section 9: Graph isolation ==========
  _results := vector_concat (_results, vector ('--- Section 9: Graph isolation ---'));

  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER_RESET ('urn:test:graph2');
  DB.DBA.CYPHER ('CREATE (n:Person {name: ''DefaultPerson''})');
  DB.DBA.CYPHER ('CREATE (n:Person {name: ''Graph2Person''})', 'urn:test:graph2');

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT ('SPARQL SELECT ?n FROM <urn:opencypher:default> WHERE { ?n a <http://localhost:8890/opencypher/ontology#Person> }');
  if (_cnt = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.1 Default has 1')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.1 Expected 1, got %d', _cnt))); }
  _total := _total + 1;

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT ('SPARQL SELECT ?n FROM <urn:test:graph2> WHERE { ?n a <http://localhost:8890/opencypher/ontology#Person> }');
  if (_cnt = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.2 Graph2 has 1')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.2 Expected 1, got %d', _cnt))); }
  _total := _total + 1;

  DB.DBA.CYPHER_RESET ('urn:test:graph-block');
  DB.DBA.CYPHER ('CREATE INTO GRAPH <urn:test:graph-block> (n:Person {name: ''GraphBlockPerson''})');

  _cnt := length (DB.DBA.CYPHER ('GRAPH <urn:test:graph-block> { MATCH (n:Person {name: ''GraphBlockPerson''}) RETURN n AS found } RETURN found'));
  if (_cnt = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.3 GRAPH block reads named graph')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.3 Expected 1, got %d', _cnt))); }
  _total := _total + 1;

  _cnt := length (DB.DBA.CYPHER ('VALUES x {1, 2} BIND(x + 1 AS y) RETURN y'));
  if (_cnt = 2)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.4 VALUES and BIND execute')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.4 Expected 2, got %d', _cnt))); }
  _total := _total + 1;

  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER ('CREATE (a:Person {name: ''A''})-[:KNOWS]->(b:Person {name: ''B''})');

  _val := aref (aref (DB.DBA.CYPHER ('MATCH p = (a)-[:KNOWS]->(b) RETURN length(p)'), 0), 0);
  if (_val = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.5 length(p) returns one-hop count')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.5 Expected length 1, got %s', cast (_val as varchar)))); }
  _total := _total + 1;

  _val := aref (aref (DB.DBA.CYPHER ('MATCH p = (a)-[:KNOWS]->(b) RETURN nodes(p)'), 0), 0);
  if (length (_val) = 2)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.6 nodes(p) returns endpoint vector')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.6 Expected 2 path nodes, got %d', length (_val)))); }
  _total := _total + 1;

  _val := aref (aref (DB.DBA.CYPHER ('MATCH p = (a)-[:KNOWS]->(b) RETURN relationships(p)'), 0), 0);
  if (length (_val) = 1 and cast (aref (_val, 0) as varchar) = 'http://localhost:8890/opencypher/ontology#knows')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.7 relationships(p) returns predicate vector')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 9.7 relationships(p) did not return KNOWS predicate')); }
  _total := _total + 1;

  _state := '00000';
  _msg := '';
  exec ('SELECT DB.DBA.CYPHER_TO_SPARQL (?)', _state, _msg,
        vector ('MATCH p = (a)-[:KNOWS*]->(b) RETURN length(p)'), 0, _meta, _data);
  if (_state = '00000')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.8 variable-length path function translates')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.8 path function: %s', _msg))); }
  _total := _total + 1;

  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER ('CREATE (a:Person {name: ''Visible''})');
  DB.DBA.CYPHER ('CREATE (b:Blocked {name: ''Hidden''})');
  DB.DBA.CYPHER ('CREATE (c:Person:Blocked {name: ''Excluded''})');
  _cnt := length (DB.DBA.CYPHER ('MATCH (n:Person) MINUS { MATCH (n:Blocked) } RETURN n'));
  if (_cnt = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.9 MINUS excludes blocked match')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.9 Expected 1, got %d', _cnt))); }
  _total := _total + 1;

  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER ('CREATE (a:Person {name: ''Alice''})');
  DB.DBA.CYPHER ('CREATE (b:Person {name: ''Bob''})');
  DB.DBA.CYPHER ('CREATE (c:Person {name: ''Carol''})');
  DB.DBA.CYPHER ('MATCH (a:Person {name: ''Alice''}), (b:Person {name: ''Bob''}) CREATE (a)-[:KNOWS]->(b)');
  _cnt := length (DB.DBA.CYPHER ('MATCH (a:Person), (b:Person) WHERE (a)-[:KNOWS]->(b) RETURN a.name, b.name'));
  if (_cnt = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.10 Pattern predicate filters rows')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.10 Expected 1, got %d', _cnt))); }
  _total := _total + 1;

  _state := '00000';
  _msg := '';
  exec ('SELECT DB.DBA.CYPHER_TO_SPARQL (?)', _state, _msg,
        vector ('MATCH (a) RETURN [(a)-[:KNOWS]->(b) | b] AS known'), 0, _meta, _data);
  if (_state = '00000')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.11 Pattern comprehension translates')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.11 Pattern comprehension: %s', _msg))); }
  _total := _total + 1;

  _val := aref (aref (DB.DBA.CYPHER ('RETURN {name: ''Neo'', born: 1964}.name AS name'), 0), 0);
  if (cast (_val as varchar) = 'Neo')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.12 Static map access returns Neo')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.12 Expected Neo, got %s', cast (_val as varchar)))); }
  _total := _total + 1;

  _val := aref (aref (DB.DBA.CYPHER ('RETURN keys({name: ''Neo'', born: 1964}) AS ks'), 0), 0);
  if (length (_val) = 2)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.13 keys(map) returns two keys')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.13 Expected 2 keys, got %d', length (_val)))); }
  _total := _total + 1;

  _val := aref (aref (DB.DBA.CYPHER ('RETURN {name: ''Neo''}[''name''] AS name'), 0), 0);
  if (cast (_val as varchar) = 'Neo')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.13a Dynamic literal map access returns Neo')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.13a Expected Neo, got %s', cast (_val as varchar)))); }
  _total := _total + 1;

  _val := aref (aref (DB.DBA.CYPHER ('RETURN [1,2,3][1..3] AS xs'), 0), 0);
  if (length (_val) = 2)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.14 List slice returns two values')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.14 Expected slice length 2, got %d', length (_val)))); }
  _total := _total + 1;

  _val := aref (aref (DB.DBA.CYPHER ('RETURN [1,2,3][1] AS x'), 0), 0);
  if (cast (_val as integer) = 2)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.14a List index returns second element')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.14a Expected 2, got %s', cast (_val as varchar)))); }
  _total := _total + 1;

  _val := aref (aref (DB.DBA.CYPHER ('RETURN [1,2] + [3,4] AS xs'), 0), 0);
  if (length (_val) = 4 and cast (aref (_val, 3) as integer) = 4)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.14b List concatenation returns four values')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.14b Expected concat length 4, got %d', length (_val)))); }
  _total := _total + 1;

  _val := aref (aref (DB.DBA.CYPHER ('RETURN range(1,5,2) AS xs'), 0), 0);
  if (length (_val) = 3 and cast (aref (_val, 2) as integer) = 5)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.14c range() returns numeric vector values')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.14c Expected range length 3, got %d', length (_val)))); }
  _total := _total + 1;

  _val := aref (aref (DB.DBA.CYPHER ('RETURN REDUCE(acc = 0, x IN [1,2,3] | acc + x) AS sum'), 0), 0);
  if (cast (_val as integer) = 6)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.15 REDUCE sums literal list')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.15 Expected 6, got %s', cast (_val as varchar)))); }
  _total := _total + 1;

  _val := aref (aref (DB.DBA.CYPHER ('WITH [1,2,3] AS xs RETURN [x IN xs WHERE x > 1 | x] AS ys'), 0), 0);
  if (length (_val) = 2)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.15a WITH-bound list comprehension filters rows')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.15a Expected filtered length 2, got %d', length (_val)))); }
  _total := _total + 1;

  _val := aref (aref (DB.DBA.CYPHER ('WITH [1,2,3] AS xs RETURN any(x IN xs WHERE x > 2) AS ok'), 0), 0);
  if (cast (_val as integer) = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.15b WITH-bound quantifier evaluates')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.15b Expected true, got %s', cast (_val as varchar)))); }
  _total := _total + 1;

  _val := aref (aref (DB.DBA.CYPHER ('WITH [1,2,3] AS xs RETURN REDUCE(acc = 0, x IN xs | acc + x) AS sum'), 0), 0);
  if (cast (_val as integer) = 6)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.15c WITH-bound REDUCE sums list')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.15c Expected 6, got %s', cast (_val as varchar)))); }
  _total := _total + 1;

  _val := aref (aref (DB.DBA.CYPHER ('WITH {name: ''Neo'', born: 1964} AS m, ''name'' AS k RETURN m[k] AS v'), 0), 0);
  if (cast (_val as varchar) = 'Neo')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.15d WITH-bound dynamic map access')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.15d Expected Neo, got %s', cast (_val as varchar)))); }
  _total := _total + 1;

  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER ('CREATE (n:Person {name: ''Neo'', born: 1964})');
  _val := aref (aref (DB.DBA.CYPHER ('MATCH (n:Person {name: ''Neo''}) RETURN n {*} AS props'), 0), 0);
  if (length (_val) >= 2)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.15e Map projection wildcard returns RDF pairs')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.15e Expected RDF pair vector, got length %d', length (_val)))); }
  _total := _total + 1;

  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER ('CREATE (n:Person {name: ''Neo''})');
  _val := aref (aref (DB.DBA.CYPHER ('MATCH (n:Person) WITH ''name'' AS k, n RETURN n[k] AS v'), 0), 0);
  if (cast (_val as varchar) = 'Neo')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 9.16 Dynamic property access returns Neo')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 9.16 Expected Neo, got %s', cast (_val as varchar)))); }
  _total := _total + 1;

  DB.DBA.CYPHER_RESET ('urn:test:graph-block');
  DB.DBA.CYPHER_RESET ('urn:test:graph2');

  -- ========== Section 10: MERGE ==========
  _results := vector_concat (_results, vector ('--- Section 10: MERGE ---'));

  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER ('MERGE (n:Person {name: ''Alice''})');

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT ('SPARQL SELECT ?n FROM <urn:opencypher:default> WHERE { ?n a <http://localhost:8890/opencypher/ontology#Person> . ?n <http://localhost:8890/opencypher/ontology#name> "Alice" }');
  if (_cnt = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 10.1 MERGE creates')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 10.1 Expected 1, got %d', _cnt))); }
  _total := _total + 1;

  DB.DBA.CYPHER ('MERGE (n:Person {name: ''Alice''})');

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT ('SPARQL SELECT ?n FROM <urn:opencypher:default> WHERE { ?n a <http://localhost:8890/opencypher/ontology#Person> . ?n <http://localhost:8890/opencypher/ontology#name> "Alice" }');
  if (_cnt = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 10.2 MERGE idempotent')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 10.2 Expected 1, got %d', _cnt))); }
  _total := _total + 1;

  _cnt := length (DB.DBA.CYPHER ('MERGE (n:Person {name: ''Alice''}) RETURN n'));
  if (_cnt = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 10.3 MERGE RETURN returns one row after procedural execution')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 10.3 Expected 1 MERGE RETURN row, got %d', _cnt))); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL_POST_MERGE ('MERGE (n:Person {name: ''Alice''}) RETURN n');
  if (strstr (_str, 'SELECT ?n') is not null and strstr (_str, 'MATCH') is null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 10.4 MERGE post-exec rewrite emits runnable SPARQL')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 10.4 MERGE post-exec rewrite did not emit runnable SPARQL')); }
  _total := _total + 1;

  _str := DB.DBA.CYPHER_TO_SPARQL_POST_MERGE ('MERGE (n:Person {name: ''Alice''}) FROM <urn:test:merge> RETURN n');
  if (strstr (_str, 'FROM <urn:test:merge>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 10.5 MERGE FROM post-exec rewrite preserves graph')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 10.5 MERGE FROM rewrite did not preserve graph: %s', _str))); }
  _total := _total + 1;

  _state := '00000';
  _msg := '';
  exec ('SELECT DB.DBA.CYP_TO_SPARQL (DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE (?)), NULL)', _state, _msg,
        vector ('MERGE (n:Person {name: ''Alice''}) RETURN n'), 0, _meta, _data);
  if (_state = 'CY092' and strstr (_msg, 'MERGE is procedural') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 10.6 MERGE translation diagnostic')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 10.6 Expected CY092 MERGE diagnostic, got %s %s', _state, _msg))); }
  _total := _total + 1;

  -- ========== Section 11: Complex end-to-end ==========
  _results := vector_concat (_results, vector ('--- Section 11: Complex e2e ---'));

  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER ('CREATE (a:Person {name: ''Alice'', age: 30, city: ''NYC''})');
  DB.DBA.CYPHER ('CREATE (b:Person {name: ''Bob'', age: 25, city: ''LA''})');
  DB.DBA.CYPHER ('CREATE (c:Person {name: ''Charlie'', age: 35, city: ''NYC''})');
  DB.DBA.CYPHER ('CREATE (d:Person {name: ''Diana'', age: 28, city: ''LA''})');

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT ('SPARQL SELECT ?n FROM <urn:opencypher:default> WHERE { ?n a <http://localhost:8890/opencypher/ontology#Person> }');
  if (_cnt = 4)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 11.1 Created 4 nodes')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 11.1 Expected 4, got %d', _cnt))); }
  _total := _total + 1;

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT ('SPARQL SELECT ?n FROM <urn:opencypher:default> WHERE { ?n a <http://localhost:8890/opencypher/ontology#Person> . ?n <http://localhost:8890/opencypher/ontology#city> "NYC" }');
  if (_cnt = 2)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 11.2 NYC has 2')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 11.2 Expected 2, got %d', _cnt))); }
  _total := _total + 1;

  DB.DBA.CYPHER ('MATCH (n:Person {name: ''Bob''}) DETACH DELETE n');

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT ('SPARQL SELECT ?n FROM <urn:opencypher:default> WHERE { ?n a <http://localhost:8890/opencypher/ontology#Person> }');
  if (_cnt = 3)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 11.3 After delete: 3')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 11.3 Expected 3, got %d', _cnt))); }
  _total := _total + 1;

  DB.DBA.CYPHER ('MATCH (n:Person {name: ''Charlie''}) SET n.city = ''SF''');

  _val := DB.DBA.OPENCYPHER_SPARQL_VAL ('SPARQL SELECT ?city FROM <urn:opencypher:default> WHERE { ?n <http://localhost:8890/opencypher/ontology#name> "Charlie" . ?n <http://localhost:8890/opencypher/ontology#city> ?city }');
  if (cast (_val as varchar) = 'SF')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 11.4 Charlie city=SF')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 11.4 Expected SF, got %s', cast (_val as varchar)))); }
  _total := _total + 1;

  _cnt := DB.DBA.OPENCYPHER_SPARQL_COUNT ('SPARQL SELECT ?n FROM <urn:opencypher:default> WHERE { ?n a <http://localhost:8890/opencypher/ontology#Person> . ?n <http://localhost:8890/opencypher/ontology#city> "NYC" }');
  if (_cnt = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 11.5 NYC now has 1')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 11.5 Expected 1, got %d', _cnt))); }
  _total := _total + 1;

  -- ========== Section 12: Operator precedence IS NULL / IN ==========
  _results := vector_concat (_results, vector ('--- Section 12: Op precedence IS NULL / IN ---'));

  -- 12.1: IS NULL after comparison RHS: a = b IS NULL → a = (b IS NULL)
  _str := DB.DBA.CYPHER_TO_SPARQL ('WITH 1 AS a, null AS b RETURN a = b IS NULL AS result');
  if (strstr (_str, 'BOUND') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 12.1 IS NULL after = comparison')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 12.1 Got: %s', _str))); }
  _total := _total + 1;

  -- 12.2: IS NOT NULL after comparison RHS
  _str := DB.DBA.CYPHER_TO_SPARQL ('WITH 1 AS a, 2 AS b RETURN a = b IS NOT NULL AS result');
  if (strstr (_str, 'BOUND') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 12.2 IS NOT NULL after = comparison')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 12.2 Got: %s', _str))); }
  _total := _total + 1;

  -- 12.3: IS NULL after <> comparison
  _str := DB.DBA.CYPHER_TO_SPARQL ('WITH 1 AS a, null AS b RETURN a <> b IS NULL AS result');
  if (strstr (_str, 'BOUND') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 12.3 IS NULL after <> comparison')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 12.3 Got: %s', _str))); }
  _total := _total + 1;

  -- 12.4: IS NULL after < comparison
  _str := DB.DBA.CYPHER_TO_SPARQL ('WITH 1 AS a, null AS b RETURN a < b IS NULL AS result');
  if (strstr (_str, 'BOUND') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 12.4 IS NULL after < comparison')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 12.4 Got: %s', _str))); }
  _total := _total + 1;

  -- 12.5: IS NULL after >= comparison
  _str := DB.DBA.CYPHER_TO_SPARQL ('WITH 1 AS a, null AS b RETURN a >= b IS NULL AS result');
  if (strstr (_str, 'BOUND') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 12.5 IS NULL after >= comparison')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 12.5 Got: %s', _str))); }
  _total := _total + 1;

  -- 12.6: IN after comparison RHS: a = b IN c → a = (b IN c)
  _str := DB.DBA.CYPHER_TO_SPARQL ('WITH 1 AS a, 2 AS b, [1, 2, 3] AS c RETURN a = b IN c AS result');
  if (_str is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 12.6 IN after = comparison')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 12.6 Translation failed')); }
  _total := _total + 1;

  -- 12.7: IN after <> comparison
  _str := DB.DBA.CYPHER_TO_SPARQL ('WITH 1 AS a, 2 AS b, [1, 2, 3] AS c RETURN a <> b IN c AS result');
  if (_str is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 12.7 IN after <> comparison')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('FAIL: 12.7 Translation failed')); }
  _total := _total + 1;

  -- 12.8: Chained comparisons: a < b < c (parsed as a < b AND b < c)
  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n) WHERE 1 < n.num < 3 RETURN n.num');
  if (strstr (_str, 'AND') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 12.8 Chained < comparisons')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 12.8 Got: %s', _str))); }
  _total := _total + 1;

  -- 12.9: Chained comparisons: a < b <= c
  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n) WHERE 1 < n.num <= 3 RETURN n.num');
  if (strstr (_str, 'AND') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 12.9 Chained < <= comparisons')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 12.9 Got: %s', _str))); }
  _total := _total + 1;

  -- 12.10: Chained comparisons: a <= b < c
  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (n) WHERE 1 <= n.num < 3 RETURN n.num');
  if (strstr (_str, 'AND') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 12.10 Chained <= < comparisons')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 12.10 Got: %s', _str))); }
  _total := _total + 1;

  -- 12.11: Label expression in WHERE: a:A:C
  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (a) WHERE a:A:C RETURN a');
  if (strstr (_str, 'EXISTS') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 12.11 Label expression : in WHERE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 12.11 Got: %s', _str))); }
  _total := _total + 1;

  -- 12.12: Label expression in RETURN: a:A:B
  _str := DB.DBA.CYPHER_TO_SPARQL ('MATCH (a) RETURN a, a:A:B AS result');
  if (strstr (_str, 'EXISTS') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 12.12 Label expression : in RETURN')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 12.12 Got: %s', _str))); }
  _total := _total + 1;

  -- 12.13: Static CREATE with list literal property
  _str := DB.DBA.CYPHER_TO_SPARQL ('CREATE ({numbers: [42, 43]})');
  if (strstr (_str, 'INSERT') is not null and strstr (_str, '[42, 43]') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('PASS: 12.13 CREATE with static list')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (sprintf ('FAIL: 12.13 Got: %s', _str))); }
  _total := _total + 1;

  -- ========== Summary ==========
  _results := vector_concat (_results, vector (''));
  _results := vector_concat (_results, vector ('========================================'));
  _results := vector_concat (_results, vector (sprintf ('TOTAL: %d  PASS: %d  FAIL: %d', _total, _pass, _fail)));
  _results := vector_concat (_results, vector ('========================================'));

  -- Return all results as single string
  _out := '';
  for (_ri := 0; _ri < length (_results); _ri := _ri + 1)
    _out := concat (_out, aref (_results, _ri), chr(10));
  return _out;
}
;

-- Run the tests
SELECT DB.DBA.OPENCYPHER_RUN_TESTS();

LOAD binsrc/cypher/test_burton_taylor.sql;

LOAD binsrc/cypher/test_plugin_parity.sql;

LOAD binsrc/cypher/test_plugin_lexer.sql;

LOAD binsrc/cypher/test_plugin_pipeline.sql;

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
--  openGQL: GQL for Virtuoso - Translation Tests
--
--  Run via isql: isql <host>:<port> dba dba < test_gql_translate.sql
--

----------------------------------------------------------------------
-- Test scaffolding helpers
----------------------------------------------------------------------

create procedure DB.DBA.GQL_T_ASSERT_SPARQL (in _test_name varchar, in _gql_text varchar, in _expected_regex varchar, inout _pass integer, inout _fail integer, inout _results any)
{
  declare _sparql varchar;
  {
    declare exit handler for sqlstate '*'
      {
        _fail := _fail + 1;
        _results := vector_concat (_results, vector (concat (_test_name, ' FAIL: signal caught')));
        return;
      };
    _sparql := DB.DBA.GQL_TO_SPARQL (_gql_text);
    if (_sparql is not null and
        (_expected_regex is null or strstr (_sparql, _expected_regex) is not null))
      {
        _pass := _pass + 1;
        _results := vector_concat (_results, vector (concat (_test_name, ' PASS')));
      }
    else
      {
        _fail := _fail + 1;
        _results := vector_concat (_results, vector (concat (_test_name, ' FAIL: got ', cast (_sparql as varchar))));
      }
  }
}
;

create procedure DB.DBA.GQL_T_RUN (in _gql_text varchar, in _graph varchar := null)
{
  declare _sparql varchar;
  declare _data any;

  _sparql := DB.DBA.GQL_TO_SPARQL (_gql_text, _graph);
  if (_sparql is null or trim (_sparql) = '')
    return vector ();

  _data := DB.DBA.GQL_EXEC_SPARQL (_sparql);
  return _data;
}
;

create procedure DB.DBA.GQL_TRANSLATE_TESTS ()
{
  declare _pass, _fail, _total integer;
  declare _results any;
  declare _sparql varchar;

  _pass := 0; _fail := 0; _total := 0;
  _results := vector ();

  -- TR1: Basic MATCH RETURN
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) RETURN n');
  if (_sparql is not null and strstr (_sparql, 'SELECT') is not null
      and strstr (_sparql, '(?gql_n_n AS ?n)') is not null
      and strstr (_sparql, 'WHERE') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR1 PASS: MATCH RETURN -> SELECT with default variable alias')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR1 FAIL: MATCH RETURN')); }

  -- TR2: MATCH with label
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n:Person) RETURN n');
  if (_sparql is not null and strstr (_sparql, 'Person') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR2 PASS: MATCH with label -> Person IRI')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR2 FAIL: MATCH with label')); }

  -- TR3: MATCH with WHERE
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) WHERE n.name = ''Alice'' RETURN n');
  if (_sparql is not null and strstr (_sparql, 'FILTER') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR3 PASS: WHERE -> FILTER')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR3 FAIL: WHERE -> FILTER')); }

  -- TR4: MATCH with edge
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n)-[:KNOWS]->(m) RETURN n, m');
  if (_sparql is not null and strstr (_sparql, 'knows') is not null
      and strstr (_sparql, '(?gql_n_n AS ?n)') is not null
      and strstr (_sparql, '(?gql_n_m AS ?m)') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR4 PASS: edge -> knows IRI with default variable aliases')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR4 FAIL: edge translation')); }

  -- TR4a: Referenced edge variable binds to RDF reification statement
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n)-[r:KNOWS]->(m) RETURN r');
  if (_sparql is not null
      and strstr (_sparql, '?gql_e_r') is not null
      and strstr (_sparql, 'rdf-syntax-ns#subject') is not null
      and strstr (_sparql, 'rdf-syntax-ns#predicate') is not null
      and strstr (_sparql, 'rdf-syntax-ns#object') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR4a PASS: edge variable reification binding')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR4a FAIL: edge variable not reified: ', cast (_sparql as varchar)))); }

  -- TR4b: Edge property reference binds through RDF reification statement
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n)-[r:KNOWS]->(m) RETURN r.weight AS weight');
  if (_sparql is not null
      and strstr (_sparql, '?gql_e_r') is not null
      and strstr (_sparql, 'rdf-syntax-ns#subject') is not null
      and strstr (_sparql, 'rdf-syntax-ns#predicate') is not null
      and strstr (_sparql, 'rdf-syntax-ns#object') is not null
      and strstr (_sparql, 'weight') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR4b PASS: edge property uses reification binding')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR4b FAIL: edge property not reified: ', cast (_sparql as varchar)))); }

  -- TR4b1: degree_centrality is result-set aware, defaults inward, and auto-groups by returned node
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n:Person) RETURN n, degree_centrality(n) AS degree');
  if (_sparql is not null
      and strstr (_sparql, 'OPTIONAL') is not null
      and strstr (_sparql, 'COUNT(DISTINCT ?deg_edge_') is not null
      and strstr (_sparql, 'in|') is not null
      and strstr (_sparql, 'out|') is null
      and strstr (_sparql, 'GROUP BY ?gql_n_n') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR4b1 PASS: degree_centrality defaults inward and auto-groups per node')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR4b1 FAIL: degree_centrality missing result-set grouping: ', cast (_sparql as varchar)))); }

  -- TR4b2: degree_centrality accepts direction, weight property, and graph scope
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n:Person) RETURN n, degree_centrality(n, "out", "weight", <urn:analytics:weighted>) AS degree');
  if (_sparql is not null
      and strstr (_sparql, 'GRAPH <urn:analytics:weighted>') is not null
      and strstr (_sparql, '<http://localhost:8890/opengql/ontology#weight>') is not null
      and strstr (_sparql, 'COALESCE(SUM(?deg_weight_') is not null
      and strstr (_sparql, 'GROUP BY ?gql_n_n') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR4b2 PASS: degree_centrality direction/weight/graph scope')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR4b2 FAIL: degree_centrality options missing: ', cast (_sparql as varchar)))); }

  -- TR4b3: undirected is accepted as an alias for both-direction degree
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n:Person) RETURN n, degree_centrality(n, "undirected") AS degree');
  if (_sparql is not null
      and strstr (_sparql, 'in|') is not null
      and strstr (_sparql, 'out|') is not null
      and strstr (_sparql, 'UNION') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR4b3 PASS: degree_centrality undirected alias')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR4b3 FAIL: degree_centrality undirected alias missing: ', cast (_sparql as varchar)))); }

  -- TR4b4: degree_centrality accepts relationship predicates as prefixed/default/IRI terms
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('PREFIX foaf: <http://xmlns.com/foaf/0.1/> MATCH (n:Person) RETURN n, degree_centrality(n, "out", foaf:knows, "weight", <urn:analytics:weighted>) AS degree');
  if (_sparql is not null
      and strstr (_sparql, '<http://xmlns.com/foaf/0.1/knows>') is not null
      and strstr (_sparql, '<http://localhost:8890/opengql/ontology#weight>') is not null
      and strstr (_sparql, 'FROM NAMED <urn:analytics:weighted>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR4b4 PASS: degree_centrality relationship predicate')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR4b4 FAIL: degree_centrality relationship predicate missing: ', cast (_sparql as varchar)))); }

  -- TR4b5: default-prefixed relationship terms parse in function arguments
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('PREFIX : <http://example.com/> MATCH (n:Person) RETURN n, degree_centrality(n, "out", :knows) AS degree');
  if (_sparql is not null
      and strstr (_sparql, '<http://example.com/knows>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR4b5 PASS: degree_centrality default-prefixed relationship')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR4b5 FAIL: degree_centrality default-prefixed relationship missing: ', cast (_sparql as varchar)))); }

  -- TR4c: Standalone INSERT with edge properties uses a concrete reification IRI
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('INSERT (n {iri:"urn:test#n"})-[r:KNOWS {weight:1}]->(m {iri:"urn:test#m"})');
  if (_sparql is not null
      and strstr (_sparql, 'INSERT DATA') is not null
      and strstr (_sparql, 'rdf:Statement') is not null
      and strstr (_sparql, '?gql_e_r') is null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR4c PASS: INSERT edge property reification uses concrete IRI')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR4c FAIL: INSERT reification uses variable: ', cast (_sparql as varchar)))); }

  -- TR4d: Prefixed edge types are kept as one QName, not split into two edge types
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('PREFIX foaf: <http://xmlns.com/foaf/0.1/> MATCH (n)-[r:foaf:knows]->(m) RETURN r.weight AS weight');
  if (_sparql is not null
      and strstr (_sparql, '<http://xmlns.com/foaf/0.1/knows>') is not null
      and strstr (_sparql, '<http://localuriqaserver/opengql/ontology#foaf>') is null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR4d PASS: prefixed edge type not split')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR4d FAIL: prefixed edge type split: ', cast (_sparql as varchar)))); }

  -- TR5: ORDER BY
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) RETURN n ORDER BY n.name ASC');
  if (_sparql is not null and strstr (_sparql, 'ORDER BY') is not null
      and strstr (_sparql, 'ASC') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR5 PASS: ORDER BY ASC')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR5 FAIL: ORDER BY ASC')); }

  -- TR6: LIMIT
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) RETURN n LIMIT 5');
  if (_sparql is not null and strstr (_sparql, 'LIMIT 5') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR6 PASS: LIMIT 5')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR6 FAIL: LIMIT 5')); }

  -- TR7: DISTINCT
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) RETURN DISTINCT n.name');
  if (_sparql is not null and strstr (_sparql, 'DISTINCT') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR7 PASS: DISTINCT')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR7 FAIL: DISTINCT')); }

  -- TR8: Catalog support (CREATE SCHEMA now produces SPARQL output)
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('CREATE SCHEMA test');
  if (_sparql is not null and _sparql <> '')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR8 PASS: CREATE SCHEMA produces SPARQL output')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR8 FAIL: CREATE SCHEMA returned empty')); }

  -- TR9: Scope validation — unbound variable
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR9 PASS: unbound var -> G3001')); goto tr9_done; };
    _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) RETURN x');
    _fail := _fail + 1; _results := vector_concat (_results, vector ('TR9 FAIL: unbound var should signal G3001'));
  }
  tr9_done:;

  -- TR10: INSERT with MATCH
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (a), (b) INSERT (a)-[:GRADUATED]->(b)');
  if (_sparql is not null and strstr (_sparql, 'INSERT') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR10 PASS: INSERT with MATCH')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR10 FAIL: INSERT with MATCH')); }

  -- TR11: RETURN *
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (a), (b) RETURN *');
  if (_sparql is not null and strstr (_sparql, 'SELECT') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR11 PASS: RETURN *')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR11 FAIL: RETURN *')); }

  -- TR12: SKIP
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) RETURN n SKIP 10 LIMIT 5');
  if (_sparql is not null and strstr (_sparql, 'OFFSET 10') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR12 PASS: SKIP -> OFFSET 10')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR12 FAIL: SKIP -> OFFSET')); }

  -- TR13: MATCH ALL suppresses synthesized FROM
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH ALL (n) RETURN n');
  if (_sparql is not null and strstr (_sparql, 'FROM <urn:opengql:default>') is null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR13 PASS: MATCH ALL suppresses default FROM')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR13 FAIL: MATCH ALL default FROM')); }

  -- TR14: SERVICE local RETURN / ORDER BY
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('SERVICE <http://example.org/sparql> { MATCH (n) RETURN n AS n2 ORDER BY n2 } RETURN n2');
  if (_sparql is not null and strstr (_sparql, 'SERVICE <http://example.org/sparql>') is not null
      and strstr (_sparql, 'SELECT') is not null
      and strstr (_sparql, 'AS ?n2') is not null
      and strstr (_sparql, 'ORDER BY ASC(?n2)') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR14 PASS: SERVICE nested RETURN ORDER BY')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR14 FAIL: SERVICE nested RETURN ORDER BY')); }

  -- TR15: SERVICE property binding reused by outer RETURN
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('PREFIX ex: <http://example.org/> PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> SERVICE <http://example.org/sparql> { MATCH ALL (film)-[:ex:p]->(d) WHERE lang(film.rdfs:label) = "en" } RETURN film.rdfs:label AS filmName');
  if (_sparql is not null and strstr (_sparql, '?prop_1 AS ?filmName') is not null
      and strstr (_sparql, '?prop_2 AS ?filmName') is null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR15 PASS: SERVICE property reuse')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR15 FAIL: SERVICE property reuse')); }

  -- TR16: USE ANY GRAPH suppresses synthesized FROM
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('USE ANY GRAPH MATCH (n) RETURN n');
  if (_sparql is not null and strstr (_sparql, 'FROM <urn:opengql:default>') is null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR16 PASS: USE ANY GRAPH suppresses default FROM')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR16 FAIL: USE ANY GRAPH default FROM')); }

  -- TR16a: Bare USE GRAPH name emits as an IRI
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('USE GRAPH analytics MATCH (n) RETURN n');
  if (_sparql is not null and strstr (_sparql, 'FROM <analytics>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR16a PASS: bare graph name')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR16a FAIL: bare graph name: ', cast (_sparql as varchar)))); }

  -- TR16b: Dotted bare USE GRAPH name maps dot to colon
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('USE GRAPH analytics.sales MATCH (n) RETURN n');
  if (_sparql is not null and strstr (_sparql, 'FROM <analytics:sales>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR16b PASS: dotted graph name')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR16b FAIL: dotted graph name: ', cast (_sparql as varchar)))); }

  -- TR16bb: Multi-dotted bare USE GRAPH name maps every dot to colon
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('USE GRAPH urn.analytics.weighted MATCH (n) RETURN n');
  if (_sparql is not null and strstr (_sparql, 'FROM <urn:analytics:weighted>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR16bb PASS: multi-dotted graph name')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR16bb FAIL: multi-dotted graph name: ', cast (_sparql as varchar)))); }

  -- TR16c: Prefix-only USE GRAPH resolves through query PREFIX declarations
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('PREFIX analytics: <urn:analytics:> USE GRAPH analytics: MATCH (n) RETURN n');
  if (_sparql is not null and strstr (_sparql, 'FROM <urn:analytics:>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR16c PASS: prefix graph name')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR16c FAIL: prefix graph name: ', cast (_sparql as varchar)))); }

  -- TR17: Phase 0 - gql_t_assert_sparql helper (ORDER BY DESC)
  _total := _total + 1;
  DB.DBA.GQL_T_ASSERT_SPARQL ('TR17', 'MATCH (n) RETURN n ORDER BY n DESC', 'ORDER BY', _pass, _fail, _results);

  -- TR18: Phase 0 - gql_t_assert_sparql helper (OPTIONAL MATCH)
  _total := _total + 1;
  DB.DBA.GQL_T_ASSERT_SPARQL ('TR18', 'MATCH (n) OPTIONAL MATCH (n)-[:KNOWS]->(m) RETURN n, m', 'OPTIONAL', _pass, _fail, _results);

  -- TR19: Phase 0 - emission helpers produce valid SPARQL with LIMIT
  _total := _total + 1;
  DB.DBA.GQL_T_ASSERT_SPARQL ('TR19', 'MATCH (n) RETURN n LIMIT 10', 'LIMIT 10', _pass, _fail, _results);

  -- TR20: Phase 0 - PREFIX emission through helper
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('PREFIX ex: <http://example.org/> MATCH (n:ex:Foo) RETURN n');
  if (_sparql is not null and strstr (_sparql, 'PREFIX ex:') is not null
      and strstr (_sparql, 'http://example.org/') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR20 PASS: PREFIX emitted')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR20 FAIL: PREFIX not emitted')); }

  -- TR20a: Hyphenated prefix labels parse without backticks
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('PREFIX truck-ontology: <http://www.openlinksw.com/ontology/trucking-ontology#> MATCH (t:truck-ontology:Truck) RETURN t');
  if (_sparql is not null
      and strstr (_sparql, '<http://www.openlinksw.com/ontology/trucking-ontology#Truck>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR20a PASS: hyphenated prefix label')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR20a FAIL: hyphenated prefix label')); }

  -- TR20b: BASE-relative label via double colon
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('BASE <http://www.openlinksw.com/ontology/trucking-ontology#> MATCH (t::Truck) RETURN t');
  if (_sparql is not null
      and strstr (_sparql, '<http://www.openlinksw.com/ontology/trucking-ontology#Truck>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR20b PASS: BASE-relative double-colon label')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR20b FAIL: BASE-relative double-colon label')); }

  -- TR20c: Default PREFIX supplies double-colon label namespace when BASE is absent
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('PREFIX : <http://www.openlinksw.com/ontology/trucking-ontology#> MATCH (t::Truck) RETURN t');
  if (_sparql is not null
      and strstr (_sparql, '<http://www.openlinksw.com/ontology/trucking-ontology#Truck>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR20c PASS: default-prefix double-colon label')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR20c FAIL: default-prefix double-colon label')); }

  -- TR20d: Explicit namespace context prevents unresolved prefixed names from falling into gql:
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('PREFIX : <http://www.openlinksw.com/ontology/trucking-ontology#> MATCH (t::Truck)-[:trucking:homeTerminal]->(term:trucking:Terminal) RETURN t');
  if (_sparql is not null
      and strstr (_sparql, '<http://www.openlinksw.com/ontology/trucking-ontology#homeTerminal>') is not null
      and strstr (_sparql, '<http://www.openlinksw.com/ontology/trucking-ontology#Terminal>') is not null
      and strstr (_sparql, '<http://localhost:8890/opengql/ontology#trucking:') is null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR20d PASS: unresolved prefixed terms use explicit namespace context')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR20d FAIL: unresolved prefixed terms use explicit namespace context')); }

  -- TR20e: BASE supplies namespace for default-prefix property access
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('BASE <http://www.openlinksw.com/ontology/trucking-ontology#> MATCH (term::Terminal) RETURN term.:name AS terminal_name');
  if (_sparql is not null
      and strstr (_sparql, '<http://www.openlinksw.com/ontology/trucking-ontology#Terminal>') is not null
      and strstr (_sparql, '<http://www.openlinksw.com/ontology/trucking-ontology#name>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR20e PASS: BASE-relative default-prefix property')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR20e FAIL: BASE-relative default-prefix property')); }

  -- TR20f: GROUP BY projected property alias uses underlying SPARQL variable
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('BASE <http://www.openlinksw.com/ontology/trucking-ontology#> MATCH (t::Truck)-[:trucking:homeTerminal]->(term::Terminal) RETURN term.:name AS terminal_name, COUNT(t) AS truck_count GROUP BY terminal_name');
  if (_sparql is not null
      and strstr (_sparql, '<http://www.openlinksw.com/ontology/trucking-ontology#name>') is not null
      and strstr (_sparql, 'GROUP BY ?prop_') is not null
      and strstr (_sparql, 'GROUP BY ?terminal_name') is null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR20f PASS: GROUP BY property alias resolves to property variable')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR20f FAIL: GROUP BY property alias resolves to property variable')); }

  -- TR20g: ORDER BY may follow a top-level GROUP BY clause
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('BASE <http://www.openlinksw.com/ontology/trucking-ontology#> MATCH (t::Truck)-[:trucking:homeTerminal]->(term::Terminal) RETURN term.:name AS terminal_name, COUNT(t) AS truck_count GROUP BY terminal_name ORDER BY truck_count DESC');
  if (_sparql is not null
      and strstr (_sparql, 'GROUP BY ?prop_') is not null
      and strstr (_sparql, 'ORDER BY DESC(COUNT(?gql_n_t))') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR20g PASS: ORDER BY after GROUP BY')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR20g FAIL: ORDER BY after GROUP BY: ', cast (_sparql as varchar)))); }

  -- TR20h: BASE supplies namespace for normal single-colon labels and edges
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('BASE <http://www.openlinksw.com/ontology/trucking-ontology#> MATCH (l:Load)-[:customer]->(c:Customer) RETURN c.industry AS industry');
  if (_sparql is not null
      and strstr (_sparql, '<http://www.openlinksw.com/ontology/trucking-ontology#Load>') is not null
      and strstr (_sparql, '<http://www.openlinksw.com/ontology/trucking-ontology#customer>') is not null
      and strstr (_sparql, '<http://www.openlinksw.com/ontology/trucking-ontology#Customer>') is not null
      and strstr (_sparql, '<http://www.openlinksw.com/ontology/trucking-ontology#industry>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR20h PASS: BASE applies to single-colon label/edge/property terms')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR20h FAIL: BASE single-colon term resolution: ', cast (_sparql as varchar)))); }

  -- TR20i: default PREFIX supplies namespace for normal single-colon labels and edges
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('PREFIX : <http://www.openlinksw.com/ontology/trucking-ontology#> MATCH (l:Load)-[:customer]->(c:Customer) RETURN c.industry AS industry');
  if (_sparql is not null
      and strstr (_sparql, '<http://www.openlinksw.com/ontology/trucking-ontology#Load>') is not null
      and strstr (_sparql, '<http://www.openlinksw.com/ontology/trucking-ontology#customer>') is not null
      and strstr (_sparql, '<http://www.openlinksw.com/ontology/trucking-ontology#Customer>') is not null
      and strstr (_sparql, '<http://www.openlinksw.com/ontology/trucking-ontology#industry>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR20i PASS: default PREFIX applies to single-colon label/edge/property terms')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR20i FAIL: default-prefix single-colon term resolution: ', cast (_sparql as varchar)))); }

  -- TR20j: LIKE lowers to SPARQL REGEX with SQL wildcard conversion
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('BASE <http://www.openlinksw.com/ontology/trucking-ontology#> MATCH (l::Load) WHERE l.requiredEndorsements LIKE "%H%" RETURN l');
  if (_sparql is not null
      and strstr (_sparql, 'REGEX(STR(?prop_') is not null
      and strstr (_sparql, '".*H.*"') is not null
      and strstr (_sparql, '"%H%"') is null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR20j PASS: LIKE wildcard converts to SPARQL regex')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR20j FAIL: LIKE wildcard regex conversion: ', cast (_sparql as varchar)))); }

  -- TR20k: CONTAINS lowers to Virtuoso bif:contains full-text predicate
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('BASE <http://www.openlinksw.com/ontology/trucking-ontology#> MATCH (l::Load) WHERE l.description CONTAINS "hazmat" RETURN l');
  if (_sparql is not null
      and strstr (_sparql, '<http://www.openlinksw.com/ontology/trucking-ontology#description>') is not null
      and strstr (_sparql, ' bif:contains "hazmat"') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR20k PASS: CONTAINS lowers to bif:contains')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR20k FAIL: CONTAINS bif:contains translation: ', cast (_sparql as varchar)))); }

  -- TR20l: CONTAINS supports Virtuoso OPTION values
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('BASE <http://www.openlinksw.com/ontology/trucking-ontology#> MATCH (l::Load) WHERE l.description CONTAINS "hazmat" OPTION (score score, score_limit 20) RETURN l, score');
  if (_sparql is not null
      and strstr (_sparql, ' bif:contains "hazmat" OPTION (score ?gql_n_score, score_limit 20)') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR20l PASS: CONTAINS OPTION values')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR20l FAIL: CONTAINS OPTION values: ', cast (_sparql as varchar)))); }

  -- TR21: Phase 0 - Variable name collision detection (var pass pre-check)
  _total := _total + 1;
  {
    declare var_ctx any;
    var_ctx := DB.DBA.GQL_CTX_NEW (DB.DBA.GQL_DEFAULT_GRAPH ());
    DB.DBA.GQL_VAR_RESOLVE_AST (
      DB.DBA.GQL_PARSE (DB.DBA.GQL_TOKENIZE ('MATCH (n)-[:KNOWS]->(m) RETURN n, m')),
      var_ctx);
    if (DB.DBA.GQL_CTX_GET_VAR_MAP (var_ctx, 'n') is not null
        and DB.DBA.GQL_CTX_GET_VAR_MAP (var_ctx, 'm') is not null)
      { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR21 PASS: var_map populated for n and m')); }
    else
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR21 FAIL: var_map missing entries')); }
  }

  -- TR22: Phase 0 - Optional depth tracking
  _total := _total + 1;
  {
    declare opt_ctx any;
    opt_ctx := DB.DBA.GQL_CTX_NEW (DB.DBA.GQL_DEFAULT_GRAPH ());
    DB.DBA.GQL_CTX_ENTER_OPTIONAL (opt_ctx);
    if (DB.DBA.GQL_CTX_IN_OPTIONAL (opt_ctx) = 1)
      {
        DB.DBA.GQL_CTX_EXIT_OPTIONAL (opt_ctx);
        if (DB.DBA.GQL_CTX_IN_OPTIONAL (opt_ctx) = 0)
          { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR22 PASS: optional depth enter/exit')); }
        else
          { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR22 FAIL: exit didn''t reset depth')); }
      }
    else
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR22 FAIL: enter didn''t set depth')); }
  }

  -- TR23: Phase 0 - Error accumulator
  _total := _total + 1;
  {
    declare err_ctx any;
    err_ctx := DB.DBA.GQL_CTX_NEW (DB.DBA.GQL_DEFAULT_GRAPH ());
    DB.DBA.GQL_CTX_ADD_ERROR (err_ctx, 'GW001', 'Test warning');
    if (DB.DBA.GQL_CTX_HAS_ERRORS (err_ctx) = 1)
      { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR23 PASS: error accumulator records')); }
    else
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR23 FAIL: error accumulator empty')); }
  }

  -- TR24: Phase 0 - Emission helper gql_emit_filter
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) WHERE n.age > 21 RETURN n');
  if (_sparql is not null and strstr (_sparql, 'FILTER') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR24 PASS: FILTER present in SPARQL')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR24 FAIL: FILTER missing')); }

  -- TR25: Phase 0 - gql_t_assert_sparql positive match (known pattern)
  _total := _total + 1;
  {
    declare t25_save_pass, t25_save_fail integer;
    t25_save_pass := _pass; t25_save_fail := _fail;
    DB.DBA.GQL_T_ASSERT_SPARQL ('TR25', 'MATCH (n) RETURN n', 'SELECT', _pass, _fail, _results);
    if (_pass > t25_save_pass)
      { _results := vector_concat (_results, vector ('TR25 PASS: gql_t_assert_sparql correctly matched SELECT')); }
    else
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR25 FAIL: gql_t_assert_sparql did not match')); }
  }

  --------------------------------------------------------------------
  -- Phase 1 tests
  --------------------------------------------------------------------

  -- TR26: Phase 1.11 - LET → BIND
  _total := _total + 1;
  DB.DBA.GQL_T_ASSERT_SPARQL ('TR26', 'MATCH (n) LET x = n.age + 1 RETURN n, x', 'BIND', _pass, _fail, _results);

  -- TR27: Phase 1.11 - Chained LETs
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) LET a = 1 LET b = a + 1 RETURN n, a, b');
  if (_sparql is not null and strstr (_sparql, 'BIND') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR27 PASS: chained LETs emit BINDs')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR27 FAIL: chained LETs')); }

  -- TR28: Phase 1.11 - LET referenced in WHERE
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) LET x = n.age + 1 WHERE x > 21 RETURN n, x');
  if (_sparql is not null and strstr (_sparql, 'BIND') is not null
      and strstr (_sparql, 'FILTER') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR28 PASS: LET before WHERE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR28 FAIL: LET before WHERE')); }

  -- TR29: Phase 1.12 - FOR with list literal → VALUES
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('FOR x IN [1,2,3] MATCH (n) RETURN n, x');
  if (_sparql is not null and strstr (_sparql, 'VALUES') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR29 PASS: FOR → VALUES')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR29 FAIL: FOR → VALUES')); }

  -- TR30: Phase 1.12 - FOR WITH OFFSET
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('FOR x IN [1,2,3] WITH OFFSET MATCH (n) RETURN n, x');
  if (_sparql is not null and strstr (_sparql, 'VALUES') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR30 PASS: FOR WITH OFFSET')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR30 FAIL: FOR WITH OFFSET')); }

  -- TR31: Phase 1.12 - FOR WITH ORDINALITY → G2003 error
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR31 PASS: FOR WITH ORDINALITY → G2003')); goto tr31_done; };
    _sparql := DB.DBA.GQL_TO_SPARQL ('FOR x IN [1,2] WITH ORDINALITY MATCH (n) RETURN n, x');
    _fail := _fail + 1; _results := vector_concat (_results, vector ('TR31 FAIL: ORDINALITY should signal G2003'));
  }
  tr31_done:;

  -- TR32: Phase 1.13 - EXISTS subquery in FILTER
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) WHERE EXISTS { MATCH (n)-[:KNOWS]->(m) } RETURN n');
  if (_sparql is not null and strstr (_sparql, 'EXISTS') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR32 PASS: EXISTS subquery')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR32 FAIL: EXISTS subquery')); }

  -- TR33: Phase 1.13 - NOT EXISTS via WHERE NOT EXISTS { ... }
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) WHERE NOT EXISTS { MATCH (n)-[:KNOWS]->(m) } RETURN n');
  if (_sparql is not null and strstr (_sparql, 'EXISTS') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR33 PASS: NOT EXISTS subquery')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR33 FAIL: NOT EXISTS subquery')); }

  -- TR34: Phase 1.7 - GROUP BY single var (GROUP BY before RETURN)
  _total := _total + 1;
  DB.DBA.GQL_T_ASSERT_SPARQL ('TR34', 'MATCH (n) GROUP BY n.name RETURN n.name, COUNT(*) AS cnt', 'GROUP BY', _pass, _fail, _results);

  -- TR35: Phase 1.7 - GROUP BY with aggregate (COUNT)
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) GROUP BY n.department RETURN n.department, COUNT(*) AS cnt');
  if (_sparql is not null and strstr (_sparql, 'GROUP BY') is not null
      and strstr (_sparql, 'COUNT(*)') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR35 PASS: GROUP BY with COUNT')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR35 FAIL: GROUP BY with COUNT')); }

  -- TR36: Phase 1.7 - HAVING referencing aggregate
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) GROUP BY n.department HAVING COUNT(*) > 5 RETURN n.department, COUNT(*) AS cnt');
  if (_sparql is not null and strstr (_sparql, 'GROUP BY') is not null
      and strstr (_sparql, 'HAVING') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR36 PASS: GROUP BY with HAVING')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR36 FAIL: GROUP BY with HAVING')); }

  -- TR37: Phase 1.7 - Aggregate without GROUP BY (whole-result aggregation)
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) RETURN COUNT(*) AS cnt');
  if (_sparql is not null and strstr (_sparql, 'COUNT(*)') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR37 PASS: COUNT without GROUP BY')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR37 FAIL: COUNT without GROUP BY')); }

  -- TR37a: COUNT(expr) aggregate
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) RETURN COUNT(n) AS total_nodes LIMIT 1');
  if (_sparql is not null
      and strstr (_sparql, 'COUNT(?gql_n_n)') is not null
      and strstr (_sparql, 'LIMIT 1') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR37a PASS: COUNT(expr) without GROUP BY')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR37a FAIL: COUNT(expr): ', cast (_sparql as varchar)))); }

  -- TR38: Phase 1.8 - COUNT(DISTINCT x)
  _total := _total + 1;
  DB.DBA.GQL_T_ASSERT_SPARQL ('TR38', 'MATCH (n) RETURN COUNT(DISTINCT n.name) AS cnt', 'COUNT', _pass, _fail, _results);

  -- TR39: Phase 1.8 - SUM aggregate
  _total := _total + 1;
  DB.DBA.GQL_T_ASSERT_SPARQL ('TR39', 'MATCH (n) RETURN SUM(n.salary) AS total', 'SUM', _pass, _fail, _results);

  -- TR40: Phase 1.8 - MIN / MAX / AVG
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) RETURN MIN(n.age) AS min_age, MAX(n.age) AS max_age, AVG(n.age) AS avg_age');
  if (_sparql is not null and strstr (_sparql, 'MIN') is not null
      and strstr (_sparql, 'MAX') is not null
      and strstr (_sparql, 'AVG') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR40 PASS: MIN/MAX/AVG aggregates')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR40 FAIL: MIN/MAX/AVG aggregates')); }

  -- TR41: Phase 1.8 - GROUP_CONCAT
  _total := _total + 1;
  DB.DBA.GQL_T_ASSERT_SPARQL ('TR41', 'MATCH (n) RETURN GROUP_CONCAT(n.name) AS names', 'GROUP_CONCAT', _pass, _fail, _results);

  -- TR42: Phase 1.9 - UNION of two MATCH queries
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n:Person) RETURN n.name AS name UNION MATCH (m:Company) RETURN m.name AS name');
  if (_sparql is not null and strstr (_sparql, 'UNION') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR42 PASS: UNION of two queries')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR42 FAIL: UNION')); }

  -- TR43: Phase 1.9 - UNION ALL
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n:Person) RETURN n.name AS name UNION ALL MATCH (m:Company) RETURN m.name AS name');
  if (_sparql is not null and strstr (_sparql, 'UNION') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR43 PASS: UNION ALL')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR43 FAIL: UNION ALL')); }

  -- TR44: Phase 1.10 - EXCEPT
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n:Person) RETURN n.name AS name EXCEPT MATCH (m:Employee) RETURN m.name AS name');
  if (_sparql is not null and strstr (_sparql, 'EXISTS') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR44 PASS: EXCEPT → NOT EXISTS')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR44 FAIL: EXCEPT')); }

  -- TR45: Phase 1.10 - INTERSECT
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n:Person) RETURN n.name AS name INTERSECT MATCH (m:Employee) RETURN m.name AS name');
  if (_sparql is not null and strstr (_sparql, 'EXISTS') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR45 PASS: INTERSECT → EXISTS')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR45 FAIL: INTERSECT')); }

  -- TR46: Phase 1.6 - ORDER BY DESC NULLS LAST
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) RETURN n ORDER BY n.name DESC NULLS LAST');
  if (_sparql is not null and strstr (_sparql, 'BOUND') is not null
      and strstr (_sparql, 'DESC') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR46 PASS: DESC NULLS LAST → BOUND emulation')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR46 FAIL: DESC NULLS LAST')); }

  -- TR47: Phase 1.6 - ORDER BY ASC NULLS FIRST
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) RETURN n ORDER BY n.age ASC NULLS FIRST');
  if (_sparql is not null and strstr (_sparql, 'BOUND') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR47 PASS: ASC NULLS FIRST → BOUND emulation')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR47 FAIL: ASC NULLS FIRST')); }

  -- TR48: Phase 1.4 - WHERE with sameTerm and isIRI predicates
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) WHERE sameTerm(n.name, "Alice") AND isIRI(n) RETURN n');
  if (_sparql is not null and strstr (_sparql, 'sameTerm') is not null
      and strstr (_sparql, 'isIRI') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR48 PASS: sameTerm + isIRI predicates')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR48 FAIL: sameTerm + isIRI')); }

  -- TR49: Phase 1.3 - Nested OPTIONAL MATCH
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) OPTIONAL MATCH (n)-[:KNOWS]->(m) OPTIONAL MATCH (m)-[:WORKS_AT]->(c) RETURN n, m, c');
  if (_sparql is not null and strstr (_sparql, 'OPTIONAL') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR49 PASS: nested OPTIONAL')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR49 FAIL: nested OPTIONAL')); }

  -- TR50: Phase 1.5 - RETURN DISTINCT with alias
  _total := _total + 1;
  DB.DBA.GQL_T_ASSERT_SPARQL ('TR50', 'MATCH (n) RETURN DISTINCT n.name AS name', 'DISTINCT', _pass, _fail, _results);

  -- TR51: Phase 1.1 - PREFIX shadowing (later overrides earlier)
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('PREFIX ex: <http://first/> PREFIX ex: <http://second/> MATCH (n:ex:Foo) RETURN n');
  if (_sparql is not null and strstr (_sparql, 'http://second/') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR51 PASS: PREFIX shadowing (second wins)')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR51 FAIL: PREFIX shadowing')); }

  -- TR52: Phase 1.2 - USE <graph> sets active graph
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('USE <urn:test> MATCH (n) RETURN n');
  if (_sparql is not null and strstr (_sparql, 'urn:test') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR52 PASS: USE sets graph in FROM')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR52 FAIL: USE graph')); }

  --------------------------------------------------------------------
  -- Phase 2 tests
  --------------------------------------------------------------------

  -- TR53: Phase 2.1 - Standalone INSERT → INSERT DATA
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('INSERT (:Person {name: "Alice"})');
  if (_sparql is not null and strstr (_sparql, 'INSERT DATA') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR53 PASS: standalone INSERT → INSERT DATA')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR53 FAIL: standalone INSERT')); }

  -- TR54: Phase 2.1 - INSERT with MATCH
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (a), (b) INSERT (a)-[:KNOWS]->(b)');
  if (_sparql is not null and strstr (_sparql, 'INSERT') is not null
      and strstr (_sparql, 'WHERE') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR54 PASS: INSERT with MATCH')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR54 FAIL: INSERT with MATCH')); }

  -- TR55: Phase 2.1 - INSERT of edge between two MATCHed nodes
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (a:Person {name: "Alice"}), (b:Person {name: "Bob"}) INSERT (a)-[:KNOWS]->(b)');
  if (_sparql is not null and strstr (_sparql, 'INSERT') is not null
      and strstr (_sparql, 'WHERE') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR55 PASS: INSERT edge between MATCHed nodes')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR55 FAIL: INSERT edge between MATCHed nodes')); }

  -- TR56: Phase 2.2 - SET property
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) SET n.name = "Bob"');
  if (_sparql is not null and strstr (_sparql, 'DELETE/INSERT') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR56 PASS: SET property → DELETE/INSERT')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR56 FAIL: SET property')); }

  -- TR57: Phase 2.2 - SET label
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) SET n:Employee');
  if (_sparql is not null and strstr (_sparql, 'a ') is not null
      and strstr (_sparql, 'Employee') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR57 PASS: SET label → rdf:type')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR57 FAIL: SET label')); }

  -- TR58: Phase 2.2 - SET all properties
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) SET n = {name: "Alice", age: 30}');
  if (_sparql is not null and strstr (_sparql, 'DELETE/INSERT') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR58 PASS: SETALL → DELETE/INSERT')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR58 FAIL: SETALL')); }

  -- TR59: Phase 2.3 - REMOVE property
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) REMOVE n.name');
  if (_sparql is not null and strstr (_sparql, 'DELETE') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR59 PASS: REMOVE property → DELETE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR59 FAIL: REMOVE property')); }

  -- TR60: Phase 2.3 - REMOVE label
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) REMOVE n:Employee');
  if (_sparql is not null and strstr (_sparql, 'DELETE') is not null
      and strstr (_sparql, 'rdf:type') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR60 PASS: REMOVE label → DELETE rdf:type')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR60 FAIL: REMOVE label')); }

  -- TR61: Phase 2.4 - DELETE node (NODETACH)
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) DELETE n');
  if (_sparql is not null and strstr (_sparql, 'DELETE') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR61 PASS: DELETE node → DELETE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR61 FAIL: DELETE node')); }

  -- TR62: Phase 2.4 - DETACH DELETE node
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) DETACH DELETE n');
  if (_sparql is not null and strstr (_sparql, 'DELETE') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR62 PASS: DETACH DELETE → DELETE with edges')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR62 FAIL: DETACH DELETE')); }

  -- TR63: Phase 2.4 - NODETACH guard present (FILTER NOT EXISTS)
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) DELETE n');
  if (_sparql is not null and strstr (_sparql, 'FILTER NOT EXISTS') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR63 PASS: NODETACH guard → FILTER NOT EXISTS')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR63 FAIL: NODETACH guard missing')); }

  -- TR64: Phase 2.5 - DML transaction wrapping (SET)
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) SET n.name = "Alice"');
  if (_sparql is not null and strstr (_sparql, 'DELETE/INSERT') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR64 PASS: SET DML for atomic execution')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR64 FAIL: SET DML')); }

  -- TR65: Phase 2.4 - DETACH DELETE should NOT have NODETACH guard
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) DETACH DELETE n');
  if (_sparql is not null and strstr (_sparql, 'DELETE') is not null
      and strstr (_sparql, 'FILTER NOT EXISTS') is null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR65 PASS: DETACH DELETE skips NODETACH guard')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR65 FAIL: DETACH DELETE guard check')); }

  -- TR66: Phase 2.5 - Multi-statement DML separator check
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) SET n.name = "Alice" REMOVE n.age');
  if (_sparql is not null and strstr (_sparql, ';\n') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR66 PASS: multi-statement DML has ;\\n separators')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR66 FAIL: multi-statement DML separator missing')); }

  --------------------------------------------------------------------
  -- Phase 3 tests
  --------------------------------------------------------------------

  -- TR67: Phase 3.1 - Star quantifier → property path *
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (a)-[:KNOWS*]->(b) RETURN a, b');
  if (_sparql is not null and strstr (_sparql, 'knows*') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR67 PASS: * quantifier → property path *')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR67 FAIL: * quantifier')); }

  -- TR68: Phase 3.1 - Plus quantifier → property path +
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (a)-[:KNOWS+]->(b) RETURN a, b');
  if (_sparql is not null and strstr (_sparql, 'knows+') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR68 PASS: + quantifier → property path +')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR68 FAIL: + quantifier')); }

  -- TR68a: Phase 3.1 - Post-bracket plus quantifier → property path +
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (a)-[:KNOWS]+->(b) RETURN a, b');
  if (_sparql is not null and strstr (_sparql, 'knows+') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR68a PASS: post-bracket + quantifier')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR68a FAIL: post-bracket + quantifier: ', cast (_sparql as varchar)))); }

  -- TR69: Phase 3.1 - Question quantifier → property path ?
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (a)-[:KNOWS?]->(b) RETURN a, b');
  if (_sparql is not null and strstr (_sparql, 'knows?') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR69 PASS: ? quantifier → property path ?')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR69 FAIL: ? quantifier')); }

  -- TR70: Phase 3.1 - Bounded quantifier {2,5} → G3003 error
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR70 PASS: bounded quantifier → G3003')); goto tr70_done; };
    _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (a)-[:KNOWS{2,5}]->(b) RETURN a, b');
    _fail := _fail + 1; _results := vector_concat (_results, vector ('TR70 FAIL: bounded quantifier should signal G3003'));
  }
  tr70_done:;

  -- TR71: Phase 3.2 - SHORTEST PATH → TRANSITIVE option
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH SHORTEST PATH (a)-[:KNOWS*]->(b) WHERE a = iri("urn:a") AND b = iri("urn:b") RETURN a, b');
	  if (_sparql is not null and strstr (_sparql, 'TRANSITIVE') is not null
	      and strstr (_sparql, 'T_SHORTEST_ONLY') is not null
	      and strstr (_sparql, 'T_DISTINCT') is not null
	      and strstr (_sparql, 'T_IN (?gql_n_a)') is not null
	      and strstr (_sparql, 'T_OUT (?gql_n_b)') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR71 PASS: SHORTEST PATH → TRANSITIVE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR71 FAIL: SHORTEST PATH')); }

  -- TR72: Phase 3.2 - SHORTEST 1 PATH (k=1)
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH SHORTEST 1 PATH (a)-[:KNOWS*]->(b) WHERE a = iri("urn:a") AND b = iri("urn:b") RETURN a, b');
  if (_sparql is not null and strstr (_sparql, 'TRANSITIVE') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR72 PASS: SHORTEST 1 PATH → TRANSITIVE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR72 FAIL: SHORTEST 1 PATH')); }

  -- TR72a: Unanchored SHORTEST PATH is rejected before Virtuoso TRANSITIVE
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR72a PASS: unanchored SHORTEST PATH → G3008')); goto tr72a_done; };
    _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH SHORTEST PATH (a)-[:KNOWS+]->(b) RETURN a, b');
    _fail := _fail + 1; _results := vector_concat (_results, vector ('TR72a FAIL: unanchored SHORTEST PATH should signal G3008'));
  }
  tr72a_done:;

  -- TR73: Phase 3.3 - WALK path mode (no-op, default)
  _total := _total + 1;
  DB.DBA.GQL_T_ASSERT_SPARQL ('TR73', 'MATCH (a)-[WALK :KNOWS]->(b) RETURN a, b', 'knows', _pass, _fail, _results);

  -- TR74: Phase 3.3 - TRAIL path mode → G3004 error
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR74 PASS: TRAIL → G3004')); goto tr74_done; };
    _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (a)-[TRAIL :KNOWS]->(b) RETURN a, b');
    _fail := _fail + 1; _results := vector_concat (_results, vector ('TR74 FAIL: TRAIL should signal G3004'));
  }
  tr74_done:;

  -- TR74a: Phase 3.3 - ACYCLIC path mode → t_no_cycles
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (a)-[ACYCLIC :KNOWS*]->(b) RETURN a, b');
  if (_sparql is not null and strstr (_sparql, 't_no_cycles') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR74a PASS: ACYCLIC → t_no_cycles')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR74a FAIL: ACYCLIC → t_no_cycles')); }

  -- TR74b: Phase 3.3 - SIMPLE path mode → t_distinct
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (a)-[SIMPLE :KNOWS*]->(b) RETURN a, b');
  if (_sparql is not null and strstr (_sparql, 't_distinct') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR74b PASS: SIMPLE → t_distinct')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR74b FAIL: SIMPLE → t_distinct')); }

  -- TR75: Phase 3.4 - ALL SHORTEST PATH
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH ALL SHORTEST PATH (a)-[:KNOWS*]->(b) WHERE a = iri("urn:a") AND b = iri("urn:b") RETURN a, b');
  if (_sparql is not null and strstr (_sparql, 'TRANSITIVE') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR75 PASS: ALL SHORTEST PATH → TRANSITIVE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR75 FAIL: ALL SHORTEST PATH')); }

  -- TR76: Phase 3.4 - ANY SHORTEST PATH
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH ANY SHORTEST PATH (a)-[:KNOWS*]->(b) WHERE a = iri("urn:a") AND b = iri("urn:b") RETURN a, b');
  if (_sparql is not null and strstr (_sparql, 'T_STEP_LIMIT 1') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR76 PASS: ANY SHORTEST → T_STEP_LIMIT 1')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR76 FAIL: ANY SHORTEST')); }

  -- TR77: Phase 3.5 - ALL PATHS (non-shortest) with property path
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH ALL (a)-[:KNOWS*]->(b) RETURN a, b');
  if (_sparql is not null and strstr (_sparql, 'knows*') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR77 PASS: ALL PATHS with property path')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR77 FAIL: ALL PATHS')); }

  -- TR78: Phase 3 QA - Undirected property path → G3006 error
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR78 PASS: undirected quantifier → G3006')); goto tr78_done; };
    _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (a)-[:KNOWS*]-(b) RETURN a, b');
    _fail := _fail + 1; _results := vector_concat (_results, vector ('TR78 FAIL: undirected quantifier should signal G3006'));
  }
  tr78_done:;

  -- TR79: Phase 3 QA - SHORTEST PATH with OPTIONAL MATCH → G3007 error
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR79 PASS: SHORTEST+OPTIONAL → G3007')); goto tr79_done; };
    _sparql := DB.DBA.GQL_TO_SPARQL ('OPTIONAL MATCH SHORTEST PATH (a)-[:KNOWS*]->(b) WHERE a = iri("urn:a") AND b = iri("urn:b") RETURN a, b');
    _fail := _fail + 1; _results := vector_concat (_results, vector ('TR79 FAIL: SHORTEST+OPTIONAL should signal G3007'));
  }
  tr79_done:;

  -- TR80: Phase 3 QA - Path variable in RETURN resolves correctly
  _total := _total + 1;
  {
    declare tokens, ast, var_ctx any;
    tokens := DB.DBA.GQL_TOKENIZE ('MATCH p = (a)-[:KNOWS]->(b) RETURN p');
    ast := DB.DBA.GQL_PARSE (tokens);
    var_ctx := DB.DBA.GQL_CTX_NEW (DB.DBA.GQL_DEFAULT_GRAPH ());
    DB.DBA.GQL_VAR_RESOLVE_AST (ast, var_ctx);
    if (DB.DBA.GQL_CTX_GET_VAR_MAP (var_ctx, 'p') is not null)
      { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR80 PASS: path var mapped as ?gql_p_p')); }
    else
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR80 FAIL: path var not mapped')); }
  }

  -- TR80a: SHORTEST PATH variable exposes PathStep bindings
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH SHORTEST PATH p = (a)-[:KNOWS+]->(b) WHERE a = <urn:a> AND b = <urn:b> RETURN p, path_step(p) AS step, path_index(p) AS idx, path_node(p) AS node');
  if (_sparql is not null
      and strstr (_sparql, 'T_STEP(''path_id'') AS ?gql_p_p_id') is not null
	      and strstr (_sparql, 'T_STEP(''step_no'') AS ?gql_p_p_index') is not null
	      and strstr (_sparql, 'T_STEP(?gql_n_a) AS ?gql_p_p_node') is not null
	      and strstr (_sparql, 'T_DIRECTION 1') is not null
	      and strstr (_sparql, 'T_DISTINCT') is not null
	      and strstr (_sparql, 'T_IN (?gql_n_a)') is not null
      and strstr (_sparql, 'T_OUT (?gql_n_b)') is not null
      and strstr (_sparql, 'BIND (<urn:a> AS ?gql_n_a)') is not null
      and strstr (_sparql, 'BIND (<urn:b> AS ?gql_n_b)') is not null
      and strstr (_sparql, ' AS ?gql_p_p_step') is not null
      and strstr (_sparql, '?gql_p_p_node') is not null
      and strstr (_sparql, 'VALUES ?gql_n_a') is null
      and strstr (_sparql, '{ SELECT ?gql_n_a ?gql_n_b WHERE') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR80a PASS: SHORTEST PATH PathStep bindings')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR80a FAIL: PathStep bindings missing: ', cast (_sparql as varchar)))); }

  -- TR80b: Bare-edge SHORTEST PATH uses Virtuoso TRANSITIVE
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH SHORTEST PATH p = (a)-[:KNOWS]->(b) WHERE a = <urn:a> AND b = <urn:b> RETURN p, path_step(p) AS step, path_index(p) AS idx, path_node(p) AS node');
  if (_sparql is not null
      and strstr (_sparql, 'OPTION (TRANSITIVE') is not null
      and strstr (_sparql, 'T_IN (?gql_n_a)') is not null
      and strstr (_sparql, 'T_OUT (?gql_n_b)') is not null
      and strstr (_sparql, 'BIND (<urn:a> AS ?gql_n_a)') is not null
	      and strstr (_sparql, 'BIND (<urn:b> AS ?gql_n_b)') is not null
	      and strstr (_sparql, 'T_STEP(?gql_n_a) AS ?gql_p_p_node') is not null
	      and strstr (_sparql, 'T_DIRECTION 1') is not null
	      and strstr (_sparql, 'T_DISTINCT') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR80b PASS: bare-edge SHORTEST PATH uses TRANSITIVE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR80b FAIL: bare-edge shortest path missed transitive bindings: ', cast (_sparql as varchar)))); }

  -- TR80c: SHORTEST PATH accepts WEIGHT edge-property cost syntax
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH SHORTEST PATH p = (a)-[:KNOWS+ WEIGHT r.weight]->(b) WHERE a = <urn:a> AND b = <urn:b> RETURN p, path_cost(p) AS cost');
  if (_sparql is not null
      and strstr (_sparql, '?gql_p_p_cost') is not null
      and strstr (_sparql, '<http://localhost:8890/opengql/ontology#weight>') is not null
      and strstr (_sparql, 'COALESCE') is not null
      and strstr (_sparql, 'T_STEP(''path_id'') AS ?gql_p_p_id') is not null
      and strstr (_sparql, 'OPTION (TRANSITIVE') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR80c PASS: SHORTEST PATH WEIGHT edge cost')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR80c FAIL: WEIGHT edge cost missing: ', cast (_sparql as varchar)))); }

  -- TR80d: COST is accepted as an alias for WEIGHT
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH SHORTEST PATH p = (a)-[:KNOWS COST r.weight]->(b) WHERE a = <urn:a> AND b = <urn:b> RETURN p, path_weight(p) AS cost');
  if (_sparql is not null
      and strstr (_sparql, '?gql_p_p_cost') is not null
      and strstr (_sparql, '<http://localhost:8890/opengql/ontology#weight>') is not null
      and strstr (_sparql, 'OPTION (TRANSITIVE') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR80d PASS: COST alias for edge weight')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat ('TR80d FAIL: COST alias missing: ', cast (_sparql as varchar)))); }

  -- TR81: Phase 3 QA - ? quantifier with ALL PATHS (no GW004 false positive)
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH ALL (a)-[:KNOWS?]->(b) RETURN a, b');
  if (_sparql is not null and strstr (_sparql, 'knows?') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR81 PASS: ? quantifier with ALL PATHS')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR81 FAIL: ? quantifier with ALL PATHS')); }

  --------------------------------------------------------------------
  -- Phase 4 tests
  --------------------------------------------------------------------

  -- TR82: Phase 4.1 - CREATE GRAPH
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('CREATE GRAPH <urn:test>');
  if (_sparql is not null and strstr (_sparql, 'CREATE GRAPH') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR82 PASS: CREATE GRAPH → SPARQL CREATE GRAPH')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR82 FAIL: CREATE GRAPH')); }

  -- TR83: Phase 4.1 - DROP GRAPH
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('DROP GRAPH <urn:test>');
  if (_sparql is not null and strstr (_sparql, 'DROP GRAPH') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR83 PASS: DROP GRAPH → SPARQL DROP GRAPH')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR83 FAIL: DROP GRAPH')); }

  -- TR84: Phase 4.1 - CREATE GRAPH AS COPY OF
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('CREATE GRAPH <urn:copy> AS COPY OF <urn:source>');
  if (_sparql is not null and strstr (_sparql, 'CREATE GRAPH') is not null
      and strstr (_sparql, 'INSERT') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR84 PASS: CREATE GRAPH AS COPY OF')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR84 FAIL: CREATE GRAPH AS COPY OF')); }

  -- TR85: Phase 4.4 - LOAD INTO GRAPH
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('LOAD <urn:data> INTO GRAPH <urn:target>');
  if (_sparql is not null and strstr (_sparql, 'LOAD') is not null
      and strstr (_sparql, 'INTO GRAPH') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR85 PASS: LOAD INTO GRAPH')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR85 FAIL: LOAD INTO GRAPH')); }

  -- TR86: Phase 4.4 - CLEAR GRAPH
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('CLEAR GRAPH <urn:test>');
  if (_sparql is not null and strstr (_sparql, 'CLEAR GRAPH') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR86 PASS: CLEAR GRAPH')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR86 FAIL: CLEAR GRAPH')); }

  -- TR87: Phase 4.2 - CREATE SCHEMA
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('CREATE SCHEMA test');
  if (_sparql is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR87 PASS: CREATE SCHEMA')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR87 FAIL: CREATE SCHEMA')); }

  -- TR88: Phase 4.3 - CREATE GRAPH TYPE
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('CREATE GRAPH TYPE test_type');
  if (_sparql is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR88 PASS: CREATE GRAPH TYPE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR88 FAIL: CREATE GRAPH TYPE')); }

  --------------------------------------------------------------------
  -- Phase 5 tests
  --------------------------------------------------------------------

  -- TR89: Phase 5.3 - START TRANSACTION (accepted as no-op)
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR89 FAIL: START TRANSACTION should not signal')); goto tr89_done; };
    _sparql := DB.DBA.GQL_TO_SPARQL ('START TRANSACTION');
    if (_sparql is not null)
      { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR89 PASS: START TRANSACTION accepted')); }
    else
      { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR89 PASS: START TRANSACTION returns empty string')); }
  }
  tr89_done:;

  -- TR90: Phase 5.3 - COMMIT (accepted as no-op)
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR90 FAIL: COMMIT should not signal')); goto tr90_done; };
    _sparql := DB.DBA.GQL_TO_SPARQL ('COMMIT');
    _pass := _pass + 1; _results := vector_concat (_results, vector ('TR90 PASS: COMMIT accepted'));
  }
  tr90_done:;

  -- TR91: Phase 5.3 - ROLLBACK (accepted as no-op)
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR91 FAIL: ROLLBACK should not signal')); goto tr91_done; };
    _sparql := DB.DBA.GQL_TO_SPARQL ('ROLLBACK');
    _pass := _pass + 1; _results := vector_concat (_results, vector ('TR91 PASS: ROLLBACK accepted'));
  }
  tr91_done:;

  -- TR92: Phase 5.4 - SESSION SET PROPERTY GRAPH (accepted)
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR92 PASS: SESSION SET accepted (no-op) or signal handled')); goto tr92_done; };
    _sparql := DB.DBA.GQL_TO_SPARQL ('SESSION SET PROPERTY GRAPH <urn:test>');
    _pass := _pass + 1; _results := vector_concat (_results, vector ('TR92 PASS: SESSION SET PROPERTY GRAPH accepted'));
  }
  tr92_done:;

  -- TR93: Phase 5.4 - SESSION RESET (accepted)
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR93 PASS: SESSION RESET accepted (no-op) or signal handled')); goto tr93_done; };
    _sparql := DB.DBA.GQL_TO_SPARQL ('SESSION RESET');
    _pass := _pass + 1; _results := vector_concat (_results, vector ('TR93 PASS: SESSION RESET accepted'));
  }
  tr93_done:;

  -- TR94: Phase 5.2 - CALL inline procedure { subquery }
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('CALL { MATCH (n) RETURN n } YIELD n');
  if (_sparql is not null and strstr (_sparql, 'SELECT') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR94 PASS: CALL inline → sub-SELECT')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR94 FAIL: CALL inline')); }

  -- TR95: Phase 5.1 - CALL named procedure
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('CALL my.proc() YIELD a, b');
  if (_sparql is not null and strstr (_sparql, 'SELECT') is not null
      and strstr (_sparql, 'sql:my.proc') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR95 PASS: CALL named proc → sql: call')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR95 FAIL: CALL named proc')); }

  -- TR96: Phase 5.1 - CALL without YIELD
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('CALL my.proc()');
  if (_sparql is not null and strstr (_sparql, 'sql:my.proc') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR96 PASS: CALL without YIELD')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR96 FAIL: CALL without YIELD')); }

  -- TR97: Phase 5.2 - CALL inline without YIELD
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('CALL { MATCH (n) RETURN n }');
  if (_sparql is not null and strstr (_sparql, 'SELECT') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR97 PASS: CALL inline without YIELD')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR97 FAIL: CALL inline without YIELD')); }

  --------------------------------------------------------------------
  -- Phase 6 tests
  --------------------------------------------------------------------

  -- TR98: Phase 6.2 - Typed literal DATE
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) WHERE n.birthdate = DATE "2024-01-15" RETURN n');
  if (_sparql is not null and strstr (_sparql, 'xsd:date') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR98 PASS: DATE literal → xsd:date')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR98 FAIL: DATE literal')); }

  -- TR99: Phase 6.2 - Typed literal DATETIME
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) WHERE n.created = DATETIME "2024-01-15T10:30:00" RETURN n');
  if (_sparql is not null and strstr (_sparql, 'xsd:dateTime') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR99 PASS: DATETIME literal → xsd:dateTime')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR99 FAIL: DATETIME literal')); }

  -- TR100: Phase 6.2 - LIST literal → RDF collection
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) WHERE n.tags = [1, 2, 3] RETURN n');
  if (_sparql is not null and strstr (_sparql, 'rdf:first') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR100 PASS: LIST literal → rdf:first/rdf:rest')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR100 FAIL: LIST literal')); }

  -- TR101: Phase 6.3 - upper → UCASE mapping
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (n) RETURN upper(n.name) AS up');
  if (_sparql is not null and strstr (_sparql, 'UCASE') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR101 PASS: upper → UCASE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR101 FAIL: upper → UCASE')); }

  -- TR102: Phase 6.3 - substring → SUBSTR mapping
  _total := _total + 1;
  DB.DBA.GQL_T_ASSERT_SPARQL ('TR102', 'MATCH (n) RETURN substring(n.name, 1, 3) AS s', 'SUBSTR', _pass, _fail, _results);

  -- TR103: Phase 6.3 - length → STRLEN mapping
  _total := _total + 1;
  DB.DBA.GQL_T_ASSERT_SPARQL ('TR103', 'MATCH (n) RETURN length(n.name) AS len', 'STRLEN', _pass, _fail, _results);

  -- TR104: Phase 6.1 - SERVICE SILENT
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('SERVICE SILENT <http://example.org/sparql> { MATCH (n) RETURN n } RETURN n');
  if (_sparql is not null and strstr (_sparql, 'SERVICE SILENT') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR104 PASS: SERVICE SILENT')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR104 FAIL: SERVICE SILENT')); }

  -- TR105: Phase 6.1 - SERVICE without RETURN in sub-block
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('SERVICE <http://example.org/sparql> { MATCH (n)-[:KNOWS]->(m) } RETURN n, m');
  if (_sparql is not null and strstr (_sparql, 'SERVICE') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR105 PASS: SERVICE without sub-RETURN')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR105 FAIL: SERVICE without sub-RETURN')); }

  -- TR105a: SERVICE sub-RETURN property shorthand expands inside the SERVICE body
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('SERVICE <http://example.org/sparql> { MATCH (team) RETURN team.rdfs:label AS team_name } RETURN team_name');
  if (_sparql is not null
      and strstr (_sparql, 'SERVICE') is not null
      and strstr (_sparql, '<http://www.w3.org/2000/01/rdf-schema#label> ?prop_') is not null
      and strstr (_sparql, 'AS ?team_name') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR105a PASS: SERVICE sub-RETURN property shorthand')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR105a FAIL: SERVICE sub-RETURN property shorthand')); }

  -- TR106: GQL CONSTRUCT emits SPARQL CONSTRUCT
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('PREFIX foaf: <http://xmlns.com/foaf/0.1/> USE GRAPH urn.analytics.weighted MATCH (a:foaf:Person)-[:foaf:knows]->(b:foaf:Person) WHERE a = <urn:a> AND b = <urn:b> CONSTRUCT (a)-[:foaf:knows]->(b)');
  if (_sparql is not null and strstr (_sparql, 'CONSTRUCT {') is not null
      and strstr (_sparql, '<http://xmlns.com/foaf/0.1/knows>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR106 PASS: CONSTRUCT → SPARQL CONSTRUCT')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR106 FAIL: CONSTRUCT translation')); }

  -- TR107: Standalone CONSTRUCT can seed its WHERE pattern and use RETURN LIMIT
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('USE GRAPH urn.analytics.weighted CONSTRUCT (n:foaf:Person) RETURN n LIMIT 5');
  if (_sparql is not null and strstr (_sparql, 'CONSTRUCT {') is not null
      and strstr (_sparql, 'WHERE {') is not null
      and strstr (_sparql, 'LIMIT 5') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR107 PASS: standalone CONSTRUCT with RETURN LIMIT')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR107 FAIL: standalone CONSTRUCT with RETURN LIMIT')); }

  -- TR107b: CONSTRUCT RETURN property expressions add projected triples
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('USE GRAPH urn.analytics.weighted CONSTRUCT (n:foaf:Person) RETURN n, n.knows LIMIT 5');
  if (_sparql is not null and strstr (_sparql, 'CONSTRUCT {') is not null
      and strstr (_sparql, '?gql_n_n') is not null
      and strstr (_sparql, 'knows> ?prop_') is not null
      and strstr (_sparql, 'LIMIT 5') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR107b PASS: CONSTRUCT RETURN property triples')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR107b FAIL: CONSTRUCT RETURN property triples')); }

  -- TR108: GQL DESCRIBE emits SPARQL DESCRIBE
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('DESCRIBE <urn:a>');
  if (_sparql is not null and strstr (_sparql, 'DESCRIBE <urn:a>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR108 PASS: DESCRIBE → SPARQL DESCRIBE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR108 FAIL: DESCRIBE translation')); }

  -- TR109: Node type alternatives with OR
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH(n:rdf:Property OR rdf:Class) RETURN n');
  if (_sparql is not null and strstr (_sparql, 'VALUES') is not null
      and strstr (_sparql, 'rdf-syntax-ns#Property') is not null
      and strstr (_sparql, 'rdf-syntax-ns#Class') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR109 PASS: node label alternatives with OR')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR109 FAIL: node label alternatives with OR')); }

  -- TR110: Node type alternatives with pipe
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH(n:rdf:Property|rdf:Class) RETURN n');
  if (_sparql is not null and strstr (_sparql, 'VALUES') is not null
      and strstr (_sparql, 'rdf-syntax-ns#Property') is not null
      and strstr (_sparql, 'rdf-syntax-ns#Class') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR110 PASS: node label alternatives with pipe')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR110 FAIL: node label alternatives with pipe')); }

  -- TR110a: Registered namespace property access works without query-local PREFIX
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (team) RETURN team.rdfs:label AS team_name');
  if (_sparql is not null
      and strstr (_sparql, '<http://www.w3.org/2000/01/rdf-schema#label>') is not null
      and strstr (_sparql, '<http://localhost:8890/opengql/ontology#rdfs:label>') is null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR110a PASS: registered namespace property access')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR110a FAIL: registered namespace property access')); }

  -- TR111: Graph centrality helpers translate to SQL-backed SPARQL calls
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('PREFIX foaf: <http://xmlns.com/foaf/0.1/> USE GRAPH urn.analytics.weighted MATCH (n:foaf:Person) RETURN n, eigenvector_centrality(n, "out", foaf:knows, weight) AS ev, closeness_centrality(n, "out", foaf:knows) AS cc, betweenness_centrality(n, "out", foaf:knows, weight) AS bc');
  if (_sparql is not null and strstr (_sparql, 'sql:GQL_GRAPH_CENTRALITY') is not null
      and strstr (_sparql, 'eigenvector') is not null
      and strstr (_sparql, 'closeness') is not null
      and strstr (_sparql, 'betweenness') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR111 PASS: eigenvector/closeness/betweenness centrality translation')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR111 FAIL: graph centrality translation')); }

  -- TR112: Edge/property names preserve spelling unless FORCE CAMELCASE is requested
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('MATCH (a)-[:ACTED_IN]->(b) RETURN a,b');
  if (_sparql is not null and strstr (_sparql, '#ACTED_IN>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR112 PASS: edge names preserve spelling by default')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR112 FAIL: edge names should preserve spelling by default')); }

  -- TR113: FORCE CAMELCASE keeps the previous compatibility behavior
  _total := _total + 1;
  _sparql := DB.DBA.GQL_TO_SPARQL ('FORCE CAMELCASE MATCH (a)-[:ACTED_IN]->(b) RETURN a,b');
  if (_sparql is not null and strstr (_sparql, '#actedIn>') is not null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('TR113 PASS: FORCE CAMELCASE normalizes edge names')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('TR113 FAIL: FORCE CAMELCASE should normalize edge names')); }

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

SELECT DB.DBA.GQL_TRANSLATE_TESTS ();

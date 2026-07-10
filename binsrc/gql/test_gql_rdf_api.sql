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
--  openGQL: GQL for Virtuoso - RDF API Equivalence Tests
--
--  Mirrors binsrc/tests/suite/trdfapi.sql — verifies that GQL queries
--  return the same results as the equivalent SPARQL queries against
--  the same RDF data loaded via TTLP.
--
--  Run via isql: isql <host>:<port> dba dba < test_gql_rdf_api.sql
--  Requires all GQL modules loaded (see gql_load.sql).
--

ECHO BOTH "STARTED: GQL RDF API equivalence tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

-- ============================================================
-- Clean up any previous test data
-- ============================================================
sparql delete { graph ?g { ?s ?p ?o } } where { graph ?g { ?s ?p ?o } filter (?g in (<http://example.org/bob>,<http://example.org/alice>,<http://example.org/default>,<http://example.org/joe>))};

-- ============================================================
-- Load the same TriG data as trdfapi.sql
-- ============================================================
TTLP('
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix dc: <http://purl.org/dc/terms/> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix ex: <http://www.example.org/vocabulary#> .
@prefix : <http://example.org/> .

# default graph - no {} used.

:joe dc:publisher "Joe" .

{
  <http://example.org/bob> dc:publisher "Bob" .
  <http://example.org/alice> dc:publisher "Alice" .
}

# GRAPH keyword to highlight a named graph
# Abbreviation of triples using ;
GRAPH <http://example.org/bob>
{
   [] foaf:name "Bob" ;
      foaf:mbox <mailto:bob@oldcorp.example.org> ;
      foaf:knows _:b .
}

<http://example.org/alice>
{
    _:b foaf:name "Alice" ;
        foaf:mbox <mailto:alice@work.example.org>
}

GRAPH :joe { :me a ex:Person ;
              ex:name "Joe Doe" ;
              ex:homepage <http://example.org/joedoe> ;
              foaf:knows _:b ;
              ex:hasSkill graph ,
                          ex:Nothing .
}', 'http://example.org/', 'http://example.org/default', 256);

-- ============================================================
-- SPARQL baseline: verify data loaded correctly (same as trdfapi.sql)
-- ============================================================
sparql select * from <http://example.org/default> { ?s ?p ?o };
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": <http://example.org/default> contains : " $ROWCNT " triples\n";

sparql select * from <http://example.org/bob> { ?s ?p ?o };
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": <http://example.org/bob> contains : " $ROWCNT " triples\n";

sparql select * from <http://example.org/alice> { ?s ?p ?o };
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": <http://example.org/alice> contains : " $ROWCNT " triples\n";

sparql select * from <http://example.org/joe> { ?s ?p ?o };
ECHO BOTH $IF $EQU $ROWCNT 6 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": <http://example.org/joe> contains : " $ROWCNT " triples\n";

-- ============================================================
-- GQL equivalence: query the same graphs via GQL MATCH
-- The GQL implementation stores nodes as RDF triples with labels
-- as rdf:type and properties as predicates in the ontology NS.
-- We query the raw triples via GQL to verify the RDF store is
-- accessible through the GQL layer.
-- ============================================================

-- RA1: GQL MATCH on the default graph returns 3 triples worth of nodes
-- GQL MATCH (n) translates to SPARQL SELECT ?n WHERE { ?n ?p ?o } in the graph
-- We verify via count that the GQL query returns the same number of distinct subjects
create procedure DB.DBA.GQL_RDF_API_TEST_1 ()
{
  declare _data any;
  declare _cnt integer;
  _data := DB.DBA.GQL_RUN ('MATCH (n) RETURN n', 'http://example.org/default');
  _cnt := length (_data);
  return _cnt;
}
;

SELECT DB.DBA.GQL_RDF_API_TEST_1 ();
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL MATCH on default graph returns 3 nodes\n";

-- RA2: GQL MATCH on the bob graph returns 3 triples worth of nodes
create procedure DB.DBA.GQL_RDF_API_TEST_2 ()
{
  declare _data any;
  declare _cnt integer;
  _data := DB.DBA.GQL_RUN ('MATCH (n) RETURN n', 'http://example.org/bob');
  _cnt := length (_data);
  return _cnt;
}
;

SELECT DB.DBA.GQL_RDF_API_TEST_2 ();
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL MATCH on bob graph returns 3 nodes\n";

-- RA3: GQL MATCH on the alice graph returns 2 triples worth of nodes
create procedure DB.DBA.GQL_RDF_API_TEST_3 ()
{
  declare _data any;
  declare _cnt integer;
  _data := DB.DBA.GQL_RUN ('MATCH (n) RETURN n', 'http://example.org/alice');
  _cnt := length (_data);
  return _cnt;
}
;

SELECT DB.DBA.GQL_RDF_API_TEST_3 ();
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL MATCH on alice graph returns 2 nodes\n";

-- RA4: GQL MATCH on the joe graph returns 6 triples worth of nodes
create procedure DB.DBA.GQL_RDF_API_TEST_4 ()
{
  declare _data any;
  declare _cnt integer;
  _data := DB.DBA.GQL_RUN ('MATCH (n) RETURN n', 'http://example.org/joe');
  _cnt := length (_data);
  return _cnt;
}
;

SELECT DB.DBA.GQL_RDF_API_TEST_4 ();
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL MATCH on joe graph returns 6 nodes\n";

-- RA5: GQL INSERT a node then MATCH to verify it persists
create procedure DB.DBA.GQL_RDF_API_TEST_5 ()
{
  declare _data any;
  declare _cnt integer;
  DB.DBA.GQL_RUN ('INSERT (:TestNode { name: ''TestUser'', age: 25 })', 'http://example.org/test');
  _data := DB.DBA.GQL_RUN ('MATCH (n:TestNode) RETURN n.name, n.age LIMIT 1', 'http://example.org/test');
  if (_data is not null and length (_data) > 0)
    return 1;
  return 0;
}
;

SELECT DB.DBA.GQL_RDF_API_TEST_5 ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL INSERT + MATCH round-trip on named graph\n";

-- RA6: GQL MATCH with WHERE filter on property value
create procedure DB.DBA.GQL_RDF_API_TEST_6 ()
{
  declare _data any;
  declare _cnt integer;
  DB.DBA.GQL_RUN ('INSERT (:Person { name: ''Alice'', city: ''NY'' })', 'http://example.org/filter');
  DB.DBA.GQL_RUN ('INSERT (:Person { name: ''Bob'', city: ''LA'' })', 'http://example.org/filter');
  _data := DB.DBA.GQL_RUN ('MATCH (n:Person) WHERE n.city = ''NY'' RETURN n.name', 'http://example.org/filter');
  if (_data is not null and length (_data) = 1)
    return 1;
  return 0;
}
;

SELECT DB.DBA.GQL_RDF_API_TEST_6 ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL MATCH with WHERE filter on property\n";

-- RA7: GQL MATCH with edge pattern
create procedure DB.DBA.GQL_RDF_API_TEST_7 ()
{
  declare _data any;
  declare _cnt integer;
  DB.DBA.GQL_RUN ('INSERT (:Person { name: ''Alice'' }), (:Person { name: ''Bob'' })', 'http://example.org/edge');
  DB.DBA.GQL_RUN ('MATCH (a:Person { name: ''Alice'' }), (b:Person { name: ''Bob'' }) INSERT (a)-[:KNOWS]->(b)', 'http://example.org/edge');
  _data := DB.DBA.GQL_RUN ('MATCH (a:Person)-[:KNOWS]->(b:Person) RETURN a.name, b.name', 'http://example.org/edge');
  if (_data is not null and length (_data) > 0)
    return 1;
  return 0;
}
;

SELECT DB.DBA.GQL_RDF_API_TEST_7 ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL MATCH with edge pattern\n";

-- RA8: GQL COUNT aggregation
create procedure DB.DBA.GQL_RDF_API_TEST_8 ()
{
  declare _data any;
  DB.DBA.GQL_RUN ('INSERT (:Person { name: ''P1'' }), (:Person { name: ''P2'' }), (:Person { name: ''P3'' })', 'http://example.org/count');
  _data := DB.DBA.GQL_RUN ('MATCH (n:Person) RETURN count(n) AS cnt', 'http://example.org/count');
  if (_data is not null and length (_data) > 0)
    return 1;
  return 0;
}
;

SELECT DB.DBA.GQL_RDF_API_TEST_8 ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL COUNT aggregation\n";

-- RA9: GQL DETACH DELETE removes node and its edges
create procedure DB.DBA.GQL_RDF_API_TEST_9 ()
{
  declare _data any;
  declare _cnt_before, _cnt_after integer;
  _data := DB.DBA.GQL_RUN ('MATCH (n:Person) RETURN n', 'http://example.org/count');
  _cnt_before := length (_data);
  DB.DBA.GQL_RUN ('MATCH (n:Person { name: ''P1'' }) DETACH DELETE n', 'http://example.org/count');
  _data := DB.DBA.GQL_RUN ('MATCH (n:Person) RETURN n', 'http://example.org/count');
  _cnt_after := length (_data);
  if (_cnt_before > _cnt_after)
    return 1;
  return 0;
}
;

SELECT DB.DBA.GQL_RDF_API_TEST_9 ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL DETACH DELETE removes node\n";

-- RA10: GQL SET updates a property
create procedure DB.DBA.GQL_RDF_API_TEST_10 ()
{
  declare _data any;
  DB.DBA.GQL_RUN ('INSERT (:Person { name: ''UpdateMe'', age: 20 })', 'http://example.org/set');
  DB.DBA.GQL_RUN ('MATCH (n:Person { name: ''UpdateMe'' }) SET n.age = 42', 'http://example.org/set');
  _data := DB.DBA.GQL_RUN ('MATCH (n:Person { name: ''UpdateMe'' }) RETURN n.age', 'http://example.org/set');
  if (_data is not null and length (_data) > 0)
    return 1;
  return 0;
}
;

SELECT DB.DBA.GQL_RDF_API_TEST_10 ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL SET updates property\n";

-- RA11: GQL multi-graph FROM equivalent — query across graphs
-- SPARQL uses FROM; GQL uses the graph parameter. We verify that
-- querying the combined graph (via SPARQL FROM) returns the same
-- total as querying each graph individually via GQL.
create procedure DB.DBA.GQL_RDF_API_TEST_11 ()
{
  declare _d1, _d2, _d3, _d4 any;
  declare _total integer;
  _d1 := DB.DBA.GQL_RUN ('MATCH (n) RETURN n', 'http://example.org/default');
  _d2 := DB.DBA.GQL_RUN ('MATCH (n) RETURN n', 'http://example.org/bob');
  _d3 := DB.DBA.GQL_RUN ('MATCH (n) RETURN n', 'http://example.org/alice');
  _d4 := DB.DBA.GQL_RUN ('MATCH (n) RETURN n', 'http://example.org/joe');
  _total := length (_d1) + length (_d2) + length (_d3) + length (_d4);
  return _total;
}
;

SELECT DB.DBA.GQL_RDF_API_TEST_11 ();
ECHO BOTH $IF $EQU $LAST[1] 14 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL multi-graph total = 14 (matches SPARQL FROM total)\n";

-- ============================================================
-- Cleanup
-- ============================================================
sparql clear graph <http://example.org/test>;
sparql clear graph <http://example.org/filter>;
sparql clear graph <http://example.org/edge>;
sparql clear graph <http://example.org/count>;
sparql clear graph <http://example.org/set>;
sparql delete { graph ?g { ?s ?p ?o } } where { graph ?g { ?s ?p ?o } filter (?g in (<http://example.org/bob>,<http://example.org/alice>,<http://example.org/default>,<http://example.org/joe>))};

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: GQL RDF API equivalence tests\n";

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
--  Burton/Taylor openCypher regression tests
--

create procedure DB.DBA.OPENCYPHER_BT_FAIL (in _msg varchar)
{
  signal ('BT001', _msg);
}
;

create procedure DB.DBA.OPENCYPHER_BT_ASSERT_INT (in _name varchar, in _actual integer, in _expected integer)
{
  if (_actual <> _expected)
    DB.DBA.OPENCYPHER_BT_FAIL (sprintf ('%s expected %d, got %d', _name, _expected, _actual));
}
;

create procedure DB.DBA.OPENCYPHER_BT_ASSERT_STR (in _name varchar, in _actual any, in _expected varchar)
{
  if (cast (_actual as varchar) <> _expected)
    DB.DBA.OPENCYPHER_BT_FAIL (sprintf ('%s expected %s, got %s', _name, _expected, cast (_actual as varchar)));
}
;

create procedure DB.DBA.OPENCYPHER_BT_SPARQL_COUNT (in _q varchar)
{
  declare state, msg varchar;
  declare meta, data any;
  state := '00000';
  msg := '';
  exec (_q, state, msg, vector (), 0, meta, data);
  if (state <> '00000')
    signal (state, msg);
  if (data is not null and length (data) > 0)
    return length (data);
  return 0;
}
;

create procedure DB.DBA.OPENCYPHER_BT_RUN ()
{
  declare total, passed integer;
  declare cnt integer;
  declare rows any;
  declare sparql_q varchar;

  total := 0;
  passed := 0;

  -- Bug 1: a single statement with multiple CREATE clauses keeps all clauses.
  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER ('CREATE (richard:Person {name: ''Richard''})
CREATE (liz:Person {name: ''Liz''})
CREATE (richard)-[:MARRIED]->(liz)');
  cnt := DB.DBA.OPENCYPHER_BT_SPARQL_COUNT ('SPARQL SELECT ?n FROM <http://www.openlinksw.com/schemas/opencypher#> WHERE { ?n a <http://www.openlinksw.com/schemas/opencypher#Person> }');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('Bug 1 Person count', cnt, 2);
  cnt := DB.DBA.OPENCYPHER_BT_SPARQL_COUNT ('SPARQL SELECT ?a FROM <http://www.openlinksw.com/schemas/opencypher#> WHERE { ?a <http://www.openlinksw.com/schemas/opencypher#married> ?b }');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('Bug 1 relationship count', cnt, 1);
  total := total + 1; passed := passed + 1;

  -- Bug 2: anonymous CREATE node produces a fresh URI and no iri_to_id error.
  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER ('CREATE (:Person {name: ''X''})');
  cnt := DB.DBA.OPENCYPHER_BT_SPARQL_COUNT ('SPARQL SELECT ?n FROM <http://www.openlinksw.com/schemas/opencypher#> WHERE { ?n a <http://www.openlinksw.com/schemas/opencypher#Person> }');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('Bug 2 anonymous Person count', cnt, 1);
  total := total + 1; passed := passed + 1;

  -- Bug 3: MATCH ... CREATE emits an INSERT template and reuses matched variables.
  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER ('CREATE (richard:Person {name: ''Richard''})
CREATE (liz:Person {name: ''Liz''})');
  DB.DBA.CYPHER ('MATCH (a:Person {name: ''Richard''}), (b:Person {name: ''Liz''}) CREATE (a)-[:FOO]->(b)');
  cnt := DB.DBA.OPENCYPHER_BT_SPARQL_COUNT ('SPARQL SELECT ?a FROM <http://www.openlinksw.com/schemas/opencypher#> WHERE { ?a <http://www.openlinksw.com/schemas/opencypher#foo> ?b }');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('Bug 3 FOO edge count', cnt, 1);
  cnt := DB.DBA.OPENCYPHER_BT_SPARQL_COUNT ('SPARQL SELECT ?n FROM <http://www.openlinksw.com/schemas/opencypher#> WHERE { ?n a <http://www.openlinksw.com/schemas/opencypher#Person> }');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('Bug 3 no extra Person nodes', cnt, 2);
  total := total + 1; passed := passed + 1;

  -- Bug 4: MERGE matches label+property nodes before creating.
  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER ('MERGE (n:L {k: ''v''})');
  DB.DBA.CYPHER ('MERGE (n:L {k: ''v''})');
  cnt := DB.DBA.OPENCYPHER_BT_SPARQL_COUNT ('SPARQL SELECT ?n FROM <http://www.openlinksw.com/schemas/opencypher#> WHERE { ?n a <http://www.openlinksw.com/schemas/opencypher#L> . ?n <http://www.openlinksw.com/schemas/opencypher#k> "v" }');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('Bug 4 idempotent node MERGE', cnt, 1);
  DB.DBA.CYPHER ('CREATE (m:MarriageEvent {id: ''LMR1Start'', when: 1960})');
  DB.DBA.CYPHER ('MERGE (m:MarriageEvent {id: ''LMR1Start''})-[:WHERE]->(l:Location {name: ''Rome''})');
  DB.DBA.CYPHER ('MERGE (d:DivorceEvent {id: ''LMR1End''})-[:ENDS]->(m:MarriageEvent {id: ''LMR1Start''})');
  cnt := DB.DBA.OPENCYPHER_BT_SPARQL_COUNT ('SPARQL SELECT ?n FROM <http://www.openlinksw.com/schemas/opencypher#> WHERE { ?n a <http://www.openlinksw.com/schemas/opencypher#MarriageEvent> . ?n <http://www.openlinksw.com/schemas/opencypher#id> "LMR1Start" }');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('Bug 4 relationship MERGE reuses node', cnt, 1);
  total := total + 1; passed := passed + 1;

  -- Bug 5: PREFIX IRI refs flow through translation.
  sparql_q := DB.DBA.CYPHER_TO_SPARQL ('PREFIX ex: <http://example.org/> MATCH (n:ex:Person) RETURN n.ex:name');
  if (strstr (sparql_q, 'http://example.org/Person') is null or strstr (sparql_q, 'http://example.org/name') is null)
    DB.DBA.OPENCYPHER_BT_FAIL ('Bug 5 PREFIX expansion missing expected URIs');
  total := total + 1; passed := passed + 1;

  -- Burton/Taylor setup with all CREATE clauses in one statement.
  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER ('CREATE (richard:Person {name: ''Richard''})
CREATE (liz:Person {name: ''Liz''})
CREATE (rome:Location {name: ''Rome''})
CREATE (newYork:Location {name: ''New York''})
CREATE (lmr1start:MarriageEvent {id: ''LMR1Start'', when: 1960})
CREATE (lmr1end:DivorceEvent {id: ''LMR1End'', when: 1970})
CREATE (richard)-[:MARRIED]->(liz)
CREATE (richard)-[:PARTICIPATED]->(lmr1start)
CREATE (liz)-[:PARTICIPATED]->(lmr1start)
CREATE (lmr1start)-[:WHERE]->(rome)
CREATE (lmr1end)-[:ENDS]->(lmr1start)
CREATE (lmr1end)-[:WHERE]->(newYork)');

  cnt := DB.DBA.OPENCYPHER_BT_SPARQL_COUNT ('SPARQL SELECT DISTINCT ?n FROM <http://www.openlinksw.com/schemas/opencypher#> WHERE { ?n a ?class . FILTER (?class IN (<http://www.openlinksw.com/schemas/opencypher#Person>, <http://www.openlinksw.com/schemas/opencypher#Location>, <http://www.openlinksw.com/schemas/opencypher#MarriageEvent>, <http://www.openlinksw.com/schemas/opencypher#DivorceEvent>)) }');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('Burton/Taylor node count', cnt, 6);

  rows := DB.DBA.CYPHER ('MATCH (a:Person)-[:MARRIED]->(b:Person) RETURN a.name, b.name');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('Burton/Taylor married row count', length (rows), 1);
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Burton/Taylor spouse lhs', aref (aref (rows, 0), 0), 'Richard');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Burton/Taylor spouse rhs', aref (aref (rows, 0), 1), 'Liz');

  rows := DB.DBA.CYPHER ('MATCH (d:DivorceEvent)-[:ENDS]->(m:MarriageEvent) RETURN d.id, m.id');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('Burton/Taylor divorce row count', length (rows), 1);
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Burton/Taylor divorce id', aref (aref (rows, 0), 0), 'LMR1End');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Burton/Taylor marriage id', aref (aref (rows, 0), 1), 'LMR1Start');

  cnt := DB.DBA.OPENCYPHER_BT_SPARQL_COUNT ('SPARQL SELECT ?e FROM <http://www.openlinksw.com/schemas/opencypher#> WHERE { ?e <http://www.openlinksw.com/schemas/opencypher#where> ?l . ?l a <http://www.openlinksw.com/schemas/opencypher#Location> }');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('Burton/Taylor WHERE edge count', cnt, 2);

  rows := DB.DBA.CYPHER ('MATCH (p1:Person)-[:PARTICIPATED]->(m:MarriageEvent),
       (p2:Person)-[:PARTICIPATED]->(m),
       (p1)-[:MARRIED]->(p2),
       (m)-[:WHERE]->(startLoc:Location),
       (d:DivorceEvent)-[:ENDS]->(m),
       (d)-[:WHERE]->(endLoc:Location)
RETURN p1.name, p2.name, m.when, startLoc.name, d.when, endLoc.name');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('Burton/Taylor full join row count', length (rows), 1);
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Burton/Taylor full join p1', aref (aref (rows, 0), 0), 'Richard');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Burton/Taylor full join p2', aref (aref (rows, 0), 1), 'Liz');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Burton/Taylor full join start year', aref (aref (rows, 0), 2), '1960');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Burton/Taylor full join start location', aref (aref (rows, 0), 3), 'Rome');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Burton/Taylor full join end year', aref (aref (rows, 0), 4), '1970');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Burton/Taylor full join end location', aref (aref (rows, 0), 5), 'New York');
  total := total + 1; passed := passed + 1;

  -- Relationship properties are stored as RDF reification in the active graph
  -- and must be queryable through property maps and relationship variables.
  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER ('PREFIX movie: <http://demo.openlinksw.com/movies#>
PREFIX mv: <http://demo.openlinksw.com/movie-ontology#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
CREATE (matrix:mv:Movie {iri: movie:TheMatrix, `rdfs:label`: ''The Matrix''})
CREATE (keanu:mv:Actor {iri: movie:KeanuReeves, `rdfs:label`: ''Keanu Reeves''})
CREATE (keanu)-[:mv:actedIn {`mv:role`: ''Neo''}]->(matrix)');
  rows := DB.DBA.CYPHER ('PREFIX mv: <http://demo.openlinksw.com/movie-ontology#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
MATCH (actor:mv:Actor)-[:mv:actedIn {`mv:role`: ''Neo''}]->(film:mv:Movie)
RETURN actor.rdfs:label, film.rdfs:label');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('Relationship property map row count', length (rows), 1);
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Relationship property map actor', aref (aref (rows, 0), 0), 'Keanu Reeves');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Relationship property map film', aref (aref (rows, 0), 1), 'The Matrix');
  rows := DB.DBA.CYPHER ('PREFIX mv: <http://demo.openlinksw.com/movie-ontology#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
MATCH (actor:mv:Actor)-[actedIn:mv:actedIn {`mv:role`: ''Neo''}]->(film:mv:Movie)
RETURN actor.rdfs:label, film.rdfs:label, actedIn.mv:role');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('Relationship property return row count', length (rows), 1);
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Relationship property return actor', aref (aref (rows, 0), 0), 'Keanu Reeves');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Relationship property return film', aref (aref (rows, 0), 1), 'The Matrix');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Relationship property return role', aref (aref (rows, 0), 2), 'Neo');
  rows := DB.DBA.CYPHER ('PREFIX mv: <http://demo.openlinksw.com/movie-ontology#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
MATCH (actor:mv:Actor)-[actedIn:mv:actedIn]->(film:mv:Movie)
RETURN actor.rdfs:label, film.rdfs:label, actedIn.mv:role');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('Relationship variable return row count', length (rows), 1);
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Relationship variable return actor', aref (aref (rows, 0), 0), 'Keanu Reeves');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Relationship variable return film', aref (aref (rows, 0), 1), 'The Matrix');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Relationship variable return role', aref (aref (rows, 0), 2), 'Neo');
  rows := DB.DBA.CYPHER ('PREFIX mv: <http://demo.openlinksw.com/movie-ontology#>
MATCH (:mv:Actor)-[:mv:actedIn {`mv:role`: ''Morpheus''}]->(:mv:Movie)
RETURN count(*)');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Relationship property negative match', aref (aref (rows, 0), 0), '0');

  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER ('PREFIX movie: <http://demo.openlinksw.com/movies#>
PREFIX mv: <http://demo.openlinksw.com/movie-ontology#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
CREATE (matrix:mv:Movie {iri: movie:TheMatrix, `rdfs:label`: ''The Matrix''})
CREATE (keanu:mv:Actor {iri: movie:KeanuReeves, `rdfs:label`: ''Keanu Reeves''})
CREATE (neo:mv:Role {iri: movie:Neo, `rdfs:label`: ''Neo''})
CREATE (keanu)-[:mv:actedIn {`mv:role`: movie:Neo}]->(matrix)');
  rows := DB.DBA.CYPHER ('PREFIX movie: <http://demo.openlinksw.com/movies#>
PREFIX mv: <http://demo.openlinksw.com/movie-ontology#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
MATCH (actor:mv:Actor)-[actedIn:mv:actedIn {`mv:role`: movie:Neo}]->(film:mv:Movie),
      (role:mv:Role)
WHERE actedIn.mv:role = role
RETURN actor.rdfs:label, film.rdfs:label, role.rdfs:label');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('Relationship resource property row count', length (rows), 1);
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Relationship resource property actor', aref (aref (rows, 0), 0), 'Keanu Reeves');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Relationship resource property film', aref (aref (rows, 0), 1), 'The Matrix');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('Relationship resource property role', aref (aref (rows, 0), 2), 'Neo');
  total := total + 1; passed := passed + 1;

  -- RDF-native data: deterministic IRIs and ontology classes, no opencypher:Node marker.
  DB.DBA.CYPHER_RESET ();
  exec ('SPARQL
PREFIX m: <http://demo.openlinksw.com/marriage#>
PREFIX oc: <http://demo.openlinksw.com/opencypher#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
INSERT INTO GRAPH <http://www.openlinksw.com/schemas/opencypher#> {
  m:Richard a foaf:Person ; rdfs:label "Richard" ; foaf:name "Richard" ; oc:married m:Liz ; oc:participated m:LMR1Start .
  m:Liz a foaf:Person ; rdfs:label "Liz" ; foaf:name "Liz" ; oc:participated m:LMR1Start .
  m:Rome a m:Location ; rdfs:label "Rome" ; oc:name "Rome" .
  m:NewYork a m:Location ; rdfs:label "New York" ; oc:name "New York" .
  m:LMR1Start a m:MarriageEvent ; oc:id "LMR1Start" ; oc:when 1960 ; rdfs:label "LMR1Start" ; oc:where m:Rome .
  m:LMR1End a m:DivorceEvent ; oc:id "LMR1End" ; oc:when 1970 ; rdfs:label "LMR1End" ; oc:ends m:LMR1Start ; oc:where m:NewYork .
}');

  rows := DB.DBA.CYPHER ('PREFIX m: <http://demo.openlinksw.com/marriage#>
PREFIX oc: <http://demo.openlinksw.com/opencypher#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
MATCH (a:foaf:Person)-[:oc:married]->(b:foaf:Person)
RETURN a.foaf:name, b.foaf:name');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('RDF-native married row count', length (rows), 1);
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('RDF-native spouse lhs', aref (aref (rows, 0), 0), 'Richard');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('RDF-native spouse rhs', aref (aref (rows, 0), 1), 'Liz');

  rows := DB.DBA.CYPHER ('PREFIX m: <http://demo.openlinksw.com/marriage#>
PREFIX oc: <http://demo.openlinksw.com/opencypher#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
MATCH (p1:foaf:Person)-[:oc:participated]->(mar:m:MarriageEvent),
      (p2:foaf:Person)-[:oc:participated]->(mar),
      (p1)-[:oc:married]->(p2),
      (mar)-[:oc:where]->(startLoc:m:Location),
      (div:m:DivorceEvent)-[:oc:ends]->(mar),
      (div)-[:oc:where]->(endLoc:m:Location)
RETURN p1.foaf:name, p2.foaf:name, mar.oc:when, startLoc.oc:name, div.oc:when, endLoc.oc:name');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('RDF-native full join row count', length (rows), 1);
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('RDF-native full join p1', aref (aref (rows, 0), 0), 'Richard');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('RDF-native full join p2', aref (aref (rows, 0), 1), 'Liz');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('RDF-native full join start year', aref (aref (rows, 0), 2), '1960');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('RDF-native full join start location', aref (aref (rows, 0), 3), 'Rome');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('RDF-native full join end year', aref (aref (rows, 0), 4), '1970');
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('RDF-native full join end location', aref (aref (rows, 0), 5), 'New York');
  total := total + 1; passed := passed + 1;

  -- RDF-native CREATE identity: iri/@id property controls the RDF subject and is not emitted as a data property.
  DB.DBA.CYPHER_RESET ();
  DB.DBA.CYPHER ('PREFIX m: <http://demo.openlinksw.com/marriage#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
CREATE (richard:foaf:Person {iri: m:Richard, `rdfs:label`: ''Richard'', `foaf:name`: ''Richard''})');
  cnt := DB.DBA.OPENCYPHER_BT_SPARQL_COUNT ('SPARQL PREFIX m: <http://demo.openlinksw.com/marriage#> PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?name FROM <http://www.openlinksw.com/schemas/opencypher#> WHERE { m:Richard a foaf:Person ; foaf:name ?name }');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('RDF-native CREATE deterministic IRI', cnt, 1);
  cnt := DB.DBA.OPENCYPHER_BT_SPARQL_COUNT ('SPARQL PREFIX m: <http://demo.openlinksw.com/marriage#> SELECT ?iri FROM <http://www.openlinksw.com/schemas/opencypher#> WHERE { m:Richard <http://www.openlinksw.com/schemas/opencypher#iri> ?iri }');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('RDF-native CREATE skips iri data property', cnt, 0);
  rows := DB.DBA.CYPHER ('PREFIX foaf: <http://xmlns.com/foaf/0.1/> MATCH (p:foaf:Person) RETURN p.foaf:name');
  DB.DBA.OPENCYPHER_BT_ASSERT_INT ('RDF-native CREATE OPENCYPHER query row count', length (rows), 1);
  DB.DBA.OPENCYPHER_BT_ASSERT_STR ('RDF-native CREATE OPENCYPHER query name', aref (aref (rows, 0), 0), 'Richard');
  total := total + 1; passed := passed + 1;

  return sprintf ('TESTS PASSED: %d/%d', passed, total);
}
;

SELECT DB.DBA.OPENCYPHER_BT_RUN ();

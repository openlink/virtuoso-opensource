--
--  trdfstar_serialize.sql
--
--  RDF 1.2 triple terms written out by the Turtle, TriG and N-Triples
--  serializers.
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

ECHO BOTH "STARTED: RDF 1.2 triple term serialization tests (trdfstar_serialize.sql)\n";

SPARQL CLEAR GRAPH <urn:trdfstar_serialize:bn>;

-- Serializes the triples of a graph the way a CONSTRUCT result is serialized.
create function TRDFSTAR_SER_WRITE (in fmt varchar, in graph_iri varchar) returns varchar
{
  declare triples, ses any;
  triples := (select vector_agg (vector (S, P, __ro2lo (O))) from DB.DBA.RDF_QUAD where G = iri_to_id (graph_iri));
  ses := string_output ();
  if (fmt = 'NT')
    DB.DBA.RDF_TRIPLES_TO_NT (triples, ses);
  else if (fmt = 'TTL')
    DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
  else if (fmt = 'TRIG')
    DB.DBA.RDF_TRIPLES_TO_TRIG (triples, ses);
  else
    signal ('22023', 'TRDFSTAR_SER_WRITE: unknown format');
  return string_output_string (ses);
}
;

-- How often a blank node label is written; a label is always followed by a
-- space or a tab, so a label that is a prefix of another is not counted.
create function TRDFSTAR_SER_LABEL_COUNT (in txt varchar, in label varchar) returns integer
{
  declare n integer;
  n := 0;
  foreach (varchar sep in vector (' ', '\t')) do
    n := n + (length (txt) - length (replace (txt, label || sep, ''))) / length (label || sep);
  return n;
}
;

-- The label the serializers give the blank node subject of the only triple
-- with predicate pred.
create function TRDFSTAR_SER_LABEL (in graph_iri varchar, in pred varchar) returns varchar
{
  return (select '_:v' || subseq (id_to_iri (S), 9) from DB.DBA.RDF_QUAD
    where G = iri_to_id (graph_iri) and P = iri_to_id (pred));
}
;

--------------------------------------------------------------------------
-- 1. A blank node inside a triple term.
--
--    It was written as an IRI, <nodeID://b...>, while the same node outside
--    the triple term was _:vb...: the written graph had an IRI where the
--    stored one has a blank node, unrelated to the node it stands for.
--------------------------------------------------------------------------

DB.DBA.TTLP ('@prefix : <http://example.com/ns#> .
_:b1 :first "one" .
_:b2 :second "two" .
:r rdf:reifies <<( _:b1 :p _:b2 )>> .
_:r2 rdf:reifies <<( :a :b _:b1 )>> .
:r3 rdf:reifies <<( :a :b <<( _:b1 :q _:b2 )>> )>> .
', '', 'urn:trdfstar_serialize:bn', 0);

select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:trdfstar_serialize:bn');
echo both $if $equ $LAST[1] 5 "PASSED" "***FAILED";
echo both ": 1a the graph with blank nodes inside triple terms is loaded\n";

select case when strstr (TRDFSTAR_SER_WRITE ('NT', 'urn:trdfstar_serialize:bn'), '<nodeID:') is null then 'none' else 'found' end;
echo both $if $equ $LAST[1] "none" "PASSED" "***FAILED";
echo both ": 1b N-Triples writes no blank node as an <nodeID:...> IRI\n";

select TRDFSTAR_SER_LABEL_COUNT (TRDFSTAR_SER_WRITE ('NT', 'urn:trdfstar_serialize:bn'),
  TRDFSTAR_SER_LABEL ('urn:trdfstar_serialize:bn', 'http://example.com/ns#first'));
echo both $if $equ $LAST[1] 4 "PASSED" "***FAILED";
echo both ": 1c N-Triples writes the subject, object and nested triple term blank node with the label it has outside them\n";

select TRDFSTAR_SER_LABEL_COUNT (TRDFSTAR_SER_WRITE ('NT', 'urn:trdfstar_serialize:bn'),
  TRDFSTAR_SER_LABEL ('urn:trdfstar_serialize:bn', 'http://example.com/ns#second'));
echo both $if $equ $LAST[1] 3 "PASSED" "***FAILED";
echo both ": 1d N-Triples writes a triple term object blank node with the label it has outside it\n";

select case when strstr (TRDFSTAR_SER_WRITE ('TTL', 'urn:trdfstar_serialize:bn'), '<nodeID:') is null then 'none' else 'found' end;
echo both $if $equ $LAST[1] "none" "PASSED" "***FAILED";
echo both ": 1e Turtle writes no blank node as an <nodeID:...> IRI\n";

select TRDFSTAR_SER_LABEL_COUNT (TRDFSTAR_SER_WRITE ('TTL', 'urn:trdfstar_serialize:bn'),
  TRDFSTAR_SER_LABEL ('urn:trdfstar_serialize:bn', 'http://example.com/ns#first'));
echo both $if $equ $LAST[1] 4 "PASSED" "***FAILED";
echo both ": 1f Turtle writes the blank node inside triple terms with the label it has outside them\n";

select case when strstr (TRDFSTAR_SER_WRITE ('TRIG', 'urn:trdfstar_serialize:bn'), '<nodeID:') is null then 'none' else 'found' end;
echo both $if $equ $LAST[1] "none" "PASSED" "***FAILED";
echo both ": 1g TriG writes no blank node as an <nodeID:...> IRI\n";

select TRDFSTAR_SER_LABEL_COUNT (TRDFSTAR_SER_WRITE ('TRIG', 'urn:trdfstar_serialize:bn'),
  TRDFSTAR_SER_LABEL ('urn:trdfstar_serialize:bn', 'http://example.com/ns#first'));
echo both $if $equ $LAST[1] 4 "PASSED" "***FAILED";
echo both ": 1h TriG writes the blank node inside triple terms with the label it has outside them\n";

--------------------------------------------------------------------------
-- 2. A written graph with triple terms reads back as the same graph.
--
--    A triple term was written as << s p o >>, which RDF 1.2 Turtle and TriG
--    read as a reifying triple, a fresh reifier of the triple, and N-Triples
--    1.2 does not accept at all; and a blank node reifier was replaced by its
--    triple term wherever it was used, its rdf:reifies triple dropped.  So
--    :r rdf:reifies <<( :a :b :c )>> read back as :r rdf:reifies _:x .
--    _:x rdf:reifies <<( :a :b :c )>>, and a reifier used three times read
--    back as three reifiers.
--------------------------------------------------------------------------

SPARQL CLEAR GRAPH <urn:trdfstar_serialize:rt>;

DB.DBA.TTLP ('@prefix : <http://example.com/ns#> .
:r rdf:reifies <<( :a :b :c )>> .
:x :p <<( :a :b :e )>> .
_:r2 rdf:reifies <<( :a :b :d )>> .
_:r2 :src :x .
_:r2 :date "2020" .
:y :about _:r2 .
:r4 rdf:reifies <<( :a :b <<( :c :d :e )>> )>> .
', '', 'urn:trdfstar_serialize:rt', 0);

-- Writes a graph in fmt and loads the text into a second graph.
create procedure TRDFSTAR_SER_ROUND_TRIP (in fmt varchar, in graph_iri varchar, in copy_iri varchar)
{
  declare txt varchar;
  txt := TRDFSTAR_SER_WRITE (fmt, graph_iri);
  delete from DB.DBA.RDF_QUAD where G = iri_to_id (copy_iri);
  DB.DBA.TTLP (txt, '', copy_iri, case when fmt = 'TRIG' then 256 else 0 end);
}
;

-- The shape of the test graph: triples, rdf:reifies triples, triples with a
-- triple term object, whether :r reifies a triple term itself, and whether
-- one node is the reifier of <<( :a :b :d )>> in all four of its uses.
create function TRDFSTAR_SER_SHAPE (in graph_iri varchar) returns varchar
{
  declare gid, reifies, src, dt, about any;
  gid := iri_to_id (graph_iri);
  reifies := iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies');
  src := iri_to_id ('http://example.com/ns#src');
  dt := iri_to_id ('http://example.com/ns#date');
  about := iri_to_id ('http://example.com/ns#about');
  return sprintf ('%d %d %d %d %d',
    (select count (*) from DB.DBA.RDF_QUAD where G = gid),
    (select count (*) from DB.DBA.RDF_QUAD where G = gid and P = reifies),
    (select count (*) from DB.DBA.RDF_QUAD where G = gid and isiri_id (O) and id_to_iri (O) like 'urn:rdf-star:triple:%'),
    (select count (*) from DB.DBA.RDF_QUAD where G = gid and S = iri_to_id ('http://example.com/ns#r') and P = reifies
       and isiri_id (O) and id_to_iri (O) like 'urn:rdf-star:triple:%'),
    (select count (*) from DB.DBA.RDF_QUAD a, DB.DBA.RDF_QUAD b, DB.DBA.RDF_QUAD c, DB.DBA.RDF_QUAD d
       where a.G = gid and a.P = src and b.G = gid and b.S = a.S and b.P = dt
         and c.G = gid and c.O = a.S and c.P = about and d.G = gid and d.S = a.S and d.P = reifies));
}
;

select TRDFSTAR_SER_SHAPE ('urn:trdfstar_serialize:rt');
echo both $if $equ $LAST[1] "7 3 4 1 1" "PASSED" "***FAILED";
echo both ": 2a the round trip test graph is loaded (shape " $LAST[1] ")\n";

select case when strstr (TRDFSTAR_SER_WRITE ('NT', 'urn:trdfstar_serialize:rt'), '<<(') is null then 'none' else 'found' end;
echo both $if $equ $LAST[1] "found" "PASSED" "***FAILED";
echo both ": 2b N-Triples writes a triple term as <<( s p o )>>\n";

select case when strstr (TRDFSTAR_SER_WRITE ('NT', 'urn:trdfstar_serialize:rt'), '<< ') is null then 'none' else 'found' end;
echo both $if $equ $LAST[1] "none" "PASSED" "***FAILED";
echo both ": 2c N-Triples writes no reifying triple << s p o >>\n";

select case when "LEFT" (TRDFSTAR_SER_WRITE ('NT', 'urn:trdfstar_serialize:rt'), 2) = '<<'
  or strstr (TRDFSTAR_SER_WRITE ('NT', 'urn:trdfstar_serialize:rt'), '\n<<') is not null then 'found' else 'none' end;
echo both $if $equ $LAST[1] "none" "PASSED" "***FAILED";
echo both ": 2d N-Triples writes no triple term as a subject\n";

TRDFSTAR_SER_ROUND_TRIP ('NT', 'urn:trdfstar_serialize:rt', 'urn:trdfstar_serialize:rt:nt');
select TRDFSTAR_SER_SHAPE ('urn:trdfstar_serialize:rt:nt');
echo both $if $equ $LAST[1] "7 3 4 1 1" "PASSED" "***FAILED";
echo both ": 2e the N-Triples output reads back as the same graph (shape " $LAST[1] ")\n";

select case when strstr (TRDFSTAR_SER_WRITE ('TTL', 'urn:trdfstar_serialize:rt'), '<< ') is null then 'none' else 'found' end;
echo both $if $equ $LAST[1] "none" "PASSED" "***FAILED";
echo both ": 2f Turtle writes a triple term as a triple term, not as a reifying triple << s p o >>\n";

TRDFSTAR_SER_ROUND_TRIP ('TTL', 'urn:trdfstar_serialize:rt', 'urn:trdfstar_serialize:rt:ttl');
select TRDFSTAR_SER_SHAPE ('urn:trdfstar_serialize:rt:ttl');
echo both $if $equ $LAST[1] "7 3 4 1 1" "PASSED" "***FAILED";
echo both ": 2g the Turtle output reads back as the same graph (shape " $LAST[1] ")\n";

select case when strstr (TRDFSTAR_SER_WRITE ('TRIG', 'urn:trdfstar_serialize:rt'), '<< ') is null then 'none' else 'found' end;
echo both $if $equ $LAST[1] "none" "PASSED" "***FAILED";
echo both ": 2h TriG writes a triple term as a triple term, not as a reifying triple << s p o >>\n";

TRDFSTAR_SER_ROUND_TRIP ('TRIG', 'urn:trdfstar_serialize:rt', 'urn:trdfstar_serialize:rt:trig');
select TRDFSTAR_SER_SHAPE ('urn:trdfstar_serialize:rt:trig');
echo both $if $equ $LAST[1] "7 3 4 1 1" "PASSED" "***FAILED";
echo both ": 2i the TriG output reads back as the same graph (shape " $LAST[1] ")\n";

--------------------------------------------------------------------------
-- 3. A triple without a triple term written after one with a triple term.
--
--    The Turtle and TriG writers write a triple with a triple term in SQL
--    and the others with http_ttl_triple, closing the statement the latter
--    left open first; but they cleared the wrong slots of its state, so the
--    next triple it wrote began with a second " ." and the output did not
--    parse.
--------------------------------------------------------------------------

SPARQL CLEAR GRAPH <urn:trdfstar_serialize:mix>;

DB.DBA.TTLP ('@prefix : <http://example.com/ns#> .
:a1 :p "v" .
:a2 :p <<( :x :y :z )>> .
:a3 :p "w" .
', '', 'urn:trdfstar_serialize:mix', 0);

-- The number of triples the written text reads back as, -1 if it does not parse.
create function TRDFSTAR_SER_RELOAD_COUNT (in fmt varchar, in graph_iri varchar, in copy_iri varchar) returns integer
{
  declare exit handler for sqlstate '*' { return -1; };
  TRDFSTAR_SER_ROUND_TRIP (fmt, graph_iri, copy_iri);
  return (select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id (copy_iri));
}
;

select TRDFSTAR_SER_RELOAD_COUNT ('TTL', 'urn:trdfstar_serialize:mix', 'urn:trdfstar_serialize:mix:ttl');
echo both $if $equ $LAST[1] 3 "PASSED" "***FAILED";
echo both ": 3a Turtle with a plain triple after a triple term triple reads back (" $LAST[1] " triples)\n";

select TRDFSTAR_SER_RELOAD_COUNT ('TRIG', 'urn:trdfstar_serialize:mix', 'urn:trdfstar_serialize:mix:trig');
echo both $if $equ $LAST[1] 3 "PASSED" "***FAILED";
echo both ": 3b TriG with a plain triple after a triple term triple reads back (" $LAST[1] " triples)\n";

--------------------------------------------------------------------------
-- cleanup
--------------------------------------------------------------------------

SPARQL CLEAR GRAPH <urn:trdfstar_serialize:bn>;
SPARQL CLEAR GRAPH <urn:trdfstar_serialize:rt>;
SPARQL CLEAR GRAPH <urn:trdfstar_serialize:rt:nt>;
SPARQL CLEAR GRAPH <urn:trdfstar_serialize:rt:ttl>;
SPARQL CLEAR GRAPH <urn:trdfstar_serialize:rt:trig>;
SPARQL CLEAR GRAPH <urn:trdfstar_serialize:mix>;
SPARQL CLEAR GRAPH <urn:trdfstar_serialize:mix:ttl>;
SPARQL CLEAR GRAPH <urn:trdfstar_serialize:mix:trig>;

ECHO BOTH "COMPLETED: RDF 1.2 triple term serialization tests (trdfstar_serialize.sql)\n";

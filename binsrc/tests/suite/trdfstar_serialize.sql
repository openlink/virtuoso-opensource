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
-- cleanup
--------------------------------------------------------------------------

SPARQL CLEAR GRAPH <urn:trdfstar_serialize:bn>;

ECHO BOTH "COMPLETED: RDF 1.2 triple term serialization tests (trdfstar_serialize.sql)\n";

--
--  trdfstar_update.sql
--
--  RDF 1.2 triple terms written through SPARQL Update: ground data
--  (INSERT DATA / DELETE DATA) and update templates.  Every write is read
--  back, and every triple-term IRI the SPARQL path mints is compared with
--  the one the Turtle loader (TTLP) mints for the same data, so a silent
--  no-op or a differently encoded term cannot pass.
--
--  A "select 99" before a statement whose first result column is asserted
--  keeps a statement that raised from passing on the previous value of
--  $LAST[1].
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

ECHO BOTH "STARTED: RDF 1.2 triple terms through SPARQL Update (trdfstar_update.sql)\n";

--------------------------------------------------------------------------
-- 1. A nested triple term in ground data:  <<( s p <<( s2 p2 o2 )>> )>>
--
--    INSERT DATA and DELETE DATA build their template from constants
--    (spar_compose_retvals_of_ctor, "big ssl const" mode), which knew IRIs,
--    literals and blank nodes but not a triple term nested in a triple term,
--    so both statements failed with "Internal error: Non-const in big ssl
--    const mode constructor pattern".  TTLP stores the same data; the SPARQL
--    path must mint the identical nested triple-term IRI.
--------------------------------------------------------------------------

SPARQL CLEAR GRAPH <urn:trdfstar_update:nested>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:nested_ttl>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:nested_ins>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:nested3>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:nested3_ttl>;

-- 1a. the statement itself.
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT DATA { GRAPH <urn:trdfstar_update:nested> { :r rdf:reifies <<( :a :b <<( :c :d :e )>> )>> } };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 1a INSERT DATA of a nested triple term <<( s p <<( s2 p2 o2 )>> )>>\n";

-- 1b. the Turtle loader's encoding of the same data is the reference.
DB.DBA.TTLP ('@prefix : <http://ex.org/> . @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
:r rdf:reifies <<( :a :b <<( :c :d :e )>> )>> .', '', 'urn:trdfstar_update:nested_ttl');
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 1b TTLP loads the same nested triple term (fixture)\n";

select 99;
select (case when
    (select id_to_iri (O) from DB.DBA.RDF_QUAD
       where G = iri_to_id ('urn:trdfstar_update:nested')
         and P = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies'))
  = (select id_to_iri (O) from DB.DBA.RDF_QUAD
       where G = iri_to_id ('urn:trdfstar_update:nested_ttl')
         and P = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies'))
  then 1 else 0 end);
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 1c INSERT DATA stores the same nested triple-term IRI as TTLP\n";

-- 1d. the stored term reads back through a nested pattern.
select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT ?x FROM <urn:trdfstar_update:nested> WHERE { :r rdf:reifies <<( :a :b <<( :c :d ?x )>> )>> };
echo both $if $equ $LAST[1] "http://ex.org/e" "PASSED" "***FAILED";
echo both ": 1d the inserted nested term matches <<( :a :b <<( :c :d ?x )>> )>> with ?x = :e\n";

-- 1e. DELETE DATA of the same nested term goes through the same constant
--     template and removes exactly that quad.
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
DELETE DATA { GRAPH <urn:trdfstar_update:nested> { :r rdf:reifies <<( :a :b <<( :c :d :e )>> )>> } };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 1e DELETE DATA of a nested triple term\n";

select 99;
SPARQL SELECT COUNT(*) FROM <urn:trdfstar_update:nested> WHERE { ?s ?p ?o };
echo both $if $equ $LAST[1] 0 "PASSED" "***FAILED";
echo both ": 1f DELETE DATA removed the nested triple term\n";

-- 1g. three levels, with an inline-valued integer at the bottom (the P1
--     crash shape, now reached through the nested conversion).
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT DATA { GRAPH <urn:trdfstar_update:nested3> { :r rdf:reifies <<( :a :b <<( :c :d <<( :e :f 42 )>> )>> )>> } };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 1g INSERT DATA of a triple term nested three deep with an integer leaf\n";

DB.DBA.TTLP ('@prefix : <http://ex.org/> . @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
:r rdf:reifies <<( :a :b <<( :c :d <<( :e :f 42 )>> )>> )>> .', '', 'urn:trdfstar_update:nested3_ttl');

select 99;
select (case when
    (select id_to_iri (O) from DB.DBA.RDF_QUAD
       where G = iri_to_id ('urn:trdfstar_update:nested3')
         and P = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies'))
  = (select id_to_iri (O) from DB.DBA.RDF_QUAD
       where G = iri_to_id ('urn:trdfstar_update:nested3_ttl')
         and P = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies'))
  then 1 else 0 end);
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 1h the three-deep triple term is the same IRI as TTLP mints\n";

-- 1i. guard: an INSERT template (not ground data) already reached the
--     nested term through the run-time expression path; it must keep
--     minting the same IRI.
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT INTO <urn:trdfstar_update:nested_ins> { :r rdf:reifies <<( :a :b <<( :c :d :e )>> )>> } WHERE { };
select 99;
select (case when
    (select id_to_iri (O) from DB.DBA.RDF_QUAD
       where G = iri_to_id ('urn:trdfstar_update:nested_ins')
         and P = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies'))
  = (select id_to_iri (O) from DB.DBA.RDF_QUAD
       where G = iri_to_id ('urn:trdfstar_update:nested_ttl')
         and P = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies'))
  then 1 else 0 end);
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 1i INSERT ... WHERE {} mints the same nested triple-term IRI as TTLP\n";

--------------------------------------------------------------------------
-- 2. A blank node inside a triple term.
--
--    RDF 1.2 allows a blank node as the subject or object of a triple term
--    (SPARQL 1.2 grammar [120], [121]).  In INSERT DATA it is a fresh blank
--    node, the same one wherever its label appears in that operation; in an
--    INSERT template it is fresh per solution.  A triple term's IRI embeds
--    the IRI_ID of its subject, so it can only be minted after the blank node
--    is, at run time.  The compiler instead rejected the statement ("Blank
--    nodes can not be used in backquoted expressions of constructor
--    template"), or -- for an annotation on a blank-node subject -- minted the
--    triple term from the label "_:x" at compile time, so the term named a
--    node that was never inserted, and the same node in every statement that
--    used the label.  Blank nodes stay forbidden in DELETE DATA and in DELETE
--    templates (SPARQL 1.2 Update 3.1.2, Note 9 of the grammar).
--------------------------------------------------------------------------

SPARQL CLEAR GRAPH <urn:trdfstar_update:bn>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:bn_ann>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:bn_ins>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:bn_long>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:bn_reif>;

create procedure TRDFSTAR_UPDATE_ERROR_OF (in stmt varchar) returns varchar
{
  declare st, msg varchar;
  st := '00000';
  exec (stmt, st, msg);
  if ('00000' = st)
    return 'no error';
  return msg;
}
;

-- 2a. INSERT DATA with a blank node in the subject of a triple term.
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT DATA { GRAPH <urn:trdfstar_update:bn> { _:x :name "X" . :r rdf:reifies <<( _:x :p :o )>> . } };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 2a INSERT DATA of <<( _:x :p :o )>>\n";

-- 2b. the subject of the stored triple term is the blank node that the
--     same operation inserted as _:x.
select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT(*) FROM <urn:trdfstar_update:bn> WHERE { ?x :name "X" . :r rdf:reifies <<( ?x :p :o )>> . FILTER (isBLANK (?x)) };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 2b the triple term's subject is the blank node inserted as _:x\n";

-- 2c. a blank node in the object position of a triple term.
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT DATA { GRAPH <urn:trdfstar_update:bn> { :r2 rdf:reifies <<( :s :p _:y )>> . _:y :name "Y" . } };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 2c INSERT DATA of <<( :s :p _:y )>>\n";

select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT(*) FROM <urn:trdfstar_update:bn> WHERE { ?y :name "Y" . :r2 rdf:reifies <<( :s :p ?y )>> . FILTER (isBLANK (?y)) };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 2d the triple term's object is the blank node inserted as _:y\n";

-- 2e. an annotation on a triple whose subject is a blank node: the
--     annotation's triple term must name the inserted blank node.  This
--     compiled before, but minted the term from the label "_:x".
SPARQL PREFIX : <http://ex.org/>
INSERT DATA { GRAPH <urn:trdfstar_update:bn_ann> { _:x :p :o {| :src :one |} . } };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 2e INSERT DATA of an annotation on a blank-node subject\n";

select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT(*) FROM <urn:trdfstar_update:bn_ann> WHERE { ?x :p :o . ?r rdf:reifies <<( ?x :p :o )>> ; :src :one . FILTER (isBLANK (?x)) };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 2f the annotation's triple term names the inserted blank node\n";

-- 2g. the same label in a second operation is a different blank node, so
--     its triple term is a different term.
SPARQL PREFIX : <http://ex.org/>
INSERT DATA { GRAPH <urn:trdfstar_update:bn_ann> { _:x :p :o {| :src :two |} . } };
select 99;
SPARQL PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT (DISTINCT ?t) FROM <urn:trdfstar_update:bn_ann> WHERE { ?r rdf:reifies ?t };
echo both $if $equ $LAST[1] 2 "PASSED" "***FAILED";
echo both ": 2g _:x in two operations gives two blank nodes and two triple terms\n";

-- 2h. an INSERT template: the blank node is fresh per solution, and each
--     solution's triple term names its own blank node.
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT { GRAPH <urn:trdfstar_update:bn_ins> { _:b :name ?n . :r3 rdf:reifies <<( _:b :p ?n )>> . } }
WHERE { VALUES ?n { "N1" "N2" } };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 2h INSERT template with <<( _:b :p ?n )>>\n";

select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT(*) FROM <urn:trdfstar_update:bn_ins> WHERE { ?b :name ?n . :r3 rdf:reifies <<( ?b :p ?n )>> . FILTER (isBLANK (?b)) };
echo both $if $equ $LAST[1] 2 "PASSED" "***FAILED";
echo both ": 2i two solutions, two blank nodes, each named by its own triple term\n";

-- 2j. CONSTRUCT with a blank node inside a triple term.
SPARQL PREFIX : <http://ex.org/> CONSTRUCT { _:b :about <<( _:b :p :o )>> } WHERE { };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 2j CONSTRUCT { _:b :about <<( _:b :p :o )>> }\n";

-- 2k. guards: blank nodes stay forbidden in DELETE DATA and DELETE templates.
select (case when TRDFSTAR_UPDATE_ERROR_OF ('SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> DELETE DATA { GRAPH <urn:trdfstar_update:bn> { :r rdf:reifies <<( _:x :p :o )>> } }')
  like '%Blank node%not allowed%' then 1 else 0 end);
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 2k DELETE DATA with a blank node inside a triple term is rejected\n";

select (case when TRDFSTAR_UPDATE_ERROR_OF ('SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> WITH <urn:trdfstar_update:bn> DELETE { :r rdf:reifies <<( _:x :p :o )>> } WHERE { }')
  like '%Blank node%not allowed%' then 1 else 0 end);
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 2l a DELETE template with a blank node inside a triple term is rejected\n";

select 99;
SPARQL SELECT COUNT(*) FROM <urn:trdfstar_update:bn> WHERE { ?s ?p ?o };
echo both $if $equ $LAST[1] 4 "PASSED" "***FAILED";
echo both ": 2m the rejected deletes changed nothing\n";

-- 2n. a long IRI and a long literal next to a blank node are encoded exactly
--     as in a ground triple term: after the subject, the two IRIs are equal.
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT DATA { GRAPH <urn:trdfstar_update:bn_long> {
  _:x :name "L" .
  :rb rdf:reifies <<( _:x <http://example.org/a/rather/long/predicate/iri/to/encode> "a literal long enough to be stored as an RDF box, not inline" )>> .
  :rg rdf:reifies <<( :s <http://example.org/a/rather/long/predicate/iri/to/encode> "a literal long enough to be stored as an RDF box, not inline" )>> . } };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 2n INSERT DATA of a triple term with a blank node and long constants\n";

select 99;
select (case when
    (select subseq (id_to_iri (O), strchr (subseq (id_to_iri (O), 20), ':') + 20) from DB.DBA.RDF_QUAD
       where G = iri_to_id ('urn:trdfstar_update:bn_long') and S = iri_to_id ('http://ex.org/rb'))
  = (select subseq (id_to_iri (O), strchr (subseq (id_to_iri (O), 20), ':') + 20) from DB.DBA.RDF_QUAD
       where G = iri_to_id ('urn:trdfstar_update:bn_long') and S = iri_to_id ('http://ex.org/rg'))
  then 1 else 0 end);
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 2o the predicate and object of the blank-node triple term are encoded as in a ground one\n";

-- 2p. the reifier forms with an explicit reifier: the triple term names the
--     inserted blank node.
SPARQL PREFIX : <http://ex.org/>
INSERT DATA { GRAPH <urn:trdfstar_update:bn_reif> { << _:x :p :o ~ :r1 >> :src :v . _:x :name "V" . _:y :p :o ~ :r2 {| :src :w |} . } };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 2p INSERT DATA of << _:x :p :o ~ :r1 >> and _:y :p :o ~ :r2 {| ... |}\n";

select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT(*) FROM <urn:trdfstar_update:bn_reif> WHERE {
  { ?x :name "V" . :r1 rdf:reifies <<( ?x :p :o )>> ; :src :v . FILTER (isBLANK (?x)) }
  UNION
  { ?y :p :o . :r2 rdf:reifies <<( ?y :p :o )>> ; :src :w . FILTER (isBLANK (?y)) } };
echo both $if $equ $LAST[1] 2 "PASSED" "***FAILED";
echo both ": 2q both explicit reifiers reify a triple term naming the inserted blank node\n";

--------------------------------------------------------------------------
-- cleanup
--------------------------------------------------------------------------

SPARQL CLEAR GRAPH <urn:trdfstar_update:bn>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:bn_ann>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:bn_ins>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:bn_long>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:bn_reif>;
drop procedure TRDFSTAR_UPDATE_ERROR_OF;
SPARQL CLEAR GRAPH <urn:trdfstar_update:nested>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:nested_ttl>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:nested_ins>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:nested3>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:nested3_ttl>;

ECHO BOTH "COMPLETED: RDF 1.2 triple terms through SPARQL Update (trdfstar_update.sql)\n";

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
-- 3. A number in the object of a triple term, bound to a variable by a
--    triple-term pattern, keeps its datatype.
--
--    The triple-term IRI encodes 42 as the integer it is ("i:42"), and the
--    decoder returns an integer, but RDF_STAR_TT_GET_O cast every object to
--    varchar: <<( ?s ?p ?o )>> bound ?o to "42"^^xsd:string.  Arithmetic and
--    comparisons on ?o failed, and a template that mints the term again from
--    ?o -- the SPARQL 1.2 Update pattern of DELETE/INSERT over triple terms --
--    minted <<( :x :age "42" )>>, a different term from the stored one.
--    The decimal and the double are loaded with TTLP, whose encoding keeps
--    their type; the SPARQL path's encoding of them is a separate defect.
--------------------------------------------------------------------------

SPARQL CLEAR GRAPH <urn:trdfstar_update:num>;

SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT DATA { GRAPH <urn:trdfstar_update:num> {
  :c1 rdf:reifies <<( :x :age 42 )>> .
  :c4 rdf:reifies <<( :x :name "Forty-two" )>> . } };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 3a INSERT DATA of triple terms with an integer and a string object\n";

DB.DBA.TTLP ('@prefix : <http://ex.org/> . @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
:c2 rdf:reifies <<( :x :ratio 2.5 )>> .
:c3 rdf:reifies <<( :x :weight 1.5e0 )>> .', '', 'urn:trdfstar_update:num');

select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT (datatype (?o) = xsd:integer) FROM <urn:trdfstar_update:num> WHERE { :c1 rdf:reifies <<( ?s ?p ?o )>> };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 3b the integer object binds as an xsd:integer\n";

select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT (?o + 1) FROM <urn:trdfstar_update:num> WHERE { :c1 rdf:reifies <<( ?s ?p ?o )>> };
echo both $if $equ $LAST[1] 43 "PASSED" "***FAILED";
echo both ": 3c arithmetic on the bound integer: ?o + 1 = 43\n";

select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT (datatype (?o) = xsd:decimal) FROM <urn:trdfstar_update:num> WHERE { :c2 rdf:reifies <<( ?s ?p ?o )>> };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 3d the decimal object binds as an xsd:decimal\n";

select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT (datatype (?o) = xsd:double) FROM <urn:trdfstar_update:num> WHERE { :c3 rdf:reifies <<( ?s ?p ?o )>> };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 3e the double object binds as an xsd:double\n";

select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT(*) FROM <urn:trdfstar_update:num> WHERE { ?c rdf:reifies <<( ?s ?p ?o )>> FILTER (?o > 40) };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 3f FILTER (?o > 40) over the bound objects matches the integer only\n";

-- 3g. guard: a string object stays the string it was.
select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT (datatype (?o) = xsd:string && ?o = "Forty-two") FROM <urn:trdfstar_update:num> WHERE { :c4 rdf:reifies <<( ?s ?p ?o )>> };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 3g the string object still binds as the same xsd:string\n";

--------------------------------------------------------------------------
-- 4. SPARQL 1.2 Update, Example 8: DELETE/INSERT over triple-term patterns.
--
--    In a template, a triple term with a variable inside was lowered to a
--    fresh reifier blank node plus an rdf:reifies triple: the DELETE template
--    refused it ("Blank nodes are not allowed in DELETE constructor
--    patterns"), and the INSERT template reified the term twice.  DELETE
--    WHERE copies its pattern into the template, with the blank node that
--    stands for a matched triple term.  The short form << s p o ~ ?claim >>
--    bound its components before ?claim was bound, so it never matched.
--------------------------------------------------------------------------

SPARQL CLEAR GRAPH <urn:trdfstar_update:e8>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:e8_copy>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:e8s>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:e8n>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:e8n_ref>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:dw>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:cw>;

create procedure TRDFSTAR_UPDATE_CONSTRUCT_OBJECT (in stmt varchar) returns varchar
{
  declare st, msg varchar;
  declare mdta, rows any;
  st := '00000';
  exec (stmt, st, msg, vector (), 0, mdta, rows);
  if ('00000' <> st)
    return msg;
  -- one row per constructed triple: subject, predicate, object
  if (1 <> length (rows))
    return sprintf ('%d triples', length (rows));
  return cast (rows[0][2] as varchar);
}
;

-- 4a. Example 8, long form, verbatim but for the graph.
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT DATA { GRAPH <urn:trdfstar_update:e8> { :claim1 :claimedBy :alice ; rdf:reifies <<( :bob :name "Bob" )>> . } };

SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
WITH <urn:trdfstar_update:e8>
DELETE { ?claim rdf:reifies <<( ?s ?p ?o )>> ; ?pp :alice . }
INSERT { ?claim rdf:reifies <<( ?s ?p ?o )>> ; ?pp :carol . ?s ?p ?o . }
WHERE  { ?claim rdf:reifies <<( ?s ?p ?o )>> ; ?pp :alice . };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 4a Example 8 (long form) runs\n";

select 99;
SPARQL PREFIX : <http://ex.org/> SELECT ?w FROM <urn:trdfstar_update:e8> WHERE { :claim1 :claimedBy ?w };
echo both $if $equ $LAST[1] "http://ex.org/carol" "PASSED" "***FAILED";
echo both ": 4b the claim is now by :carol\n";

select 99;
SPARQL PREFIX : <http://ex.org/> SELECT COUNT(*) FROM <urn:trdfstar_update:e8> WHERE { :claim1 :claimedBy :alice };
echo both $if $equ $LAST[1] 0 "PASSED" "***FAILED";
echo both ": 4c and no longer by :alice\n";

select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT(*) FROM <urn:trdfstar_update:e8> WHERE { ?r rdf:reifies ?t };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 4d one rdf:reifies triple: the triple term was reinserted, not reified again\n";

select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT(*) FROM <urn:trdfstar_update:e8> WHERE { :claim1 rdf:reifies <<( :bob :name "Bob" )>> . :bob :name "Bob" };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 4e the reification is kept and :bob :name \"Bob\" is asserted\n";

-- 4f. an INSERT template mints the triple term itself: one triple, whose
--     object is the stored triple term.
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT { GRAPH <urn:trdfstar_update:e8_copy> { ?claim :about <<( ?s ?p ?o )>> } }
WHERE { GRAPH <urn:trdfstar_update:e8> { ?claim rdf:reifies <<( ?s ?p ?o )>> } };
select 99;
select (case when
    (select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:trdfstar_update:e8_copy')) = 1
  and
    (select O from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:trdfstar_update:e8_copy'))
  = (select O from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:trdfstar_update:e8')
       and P = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies'))
  then 1 else 0 end);
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 4f INSERT { ?c :about <<( ?s ?p ?o )>> } writes the stored triple term, once\n";

-- 4g. the same update over a triple term with an integer object: the
--     DELETE must find the stored term and the INSERT must mint it again.
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT DATA { GRAPH <urn:trdfstar_update:e8n> { :claim2 :claimedBy :alice ; rdf:reifies <<( :bob :age 23 )>> . } };
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT DATA { GRAPH <urn:trdfstar_update:e8n_ref> { :claim2 rdf:reifies <<( :bob :age 23 )>> . } };
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
WITH <urn:trdfstar_update:e8n>
DELETE { ?claim rdf:reifies <<( ?s ?p ?o )>> ; ?pp :alice . }
INSERT { ?claim rdf:reifies <<( ?s ?p ?o )>> ; ?pp :carol . ?s ?p ?o . }
WHERE  { ?claim rdf:reifies <<( ?s ?p ?o )>> ; ?pp :alice . };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 4g Example 8 over <<( :bob :age 23 )>> runs\n";

select 99;
select (case when
    (select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:trdfstar_update:e8n')
       and P = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies')) = 1
  and
    (select O from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:trdfstar_update:e8n')
       and P = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies'))
  = (select O from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:trdfstar_update:e8n_ref'))
  then 1 else 0 end);
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 4h the integer triple term is the one stored before, not a re-minted \"23\"\n";

select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT COUNT(*) FROM <urn:trdfstar_update:e8n> WHERE { :bob :age ?a . :claim2 :claimedBy :carol . FILTER (datatype (?a) = xsd:integer && ?a = 23) };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 4i :bob :age 23 is asserted as an integer and the claim is by :carol\n";

-- 4j. Example 8, short form: << s p o ~ ?claim >> binds before ?claim is used.
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT DATA { GRAPH <urn:trdfstar_update:e8s> { :claim1 :claimedBy :alice ; rdf:reifies <<( :bob :name "Bob" )>> . } };
select 99;
SPARQL PREFIX : <http://ex.org/>
SELECT COUNT(*) FROM <urn:trdfstar_update:e8s> WHERE { << ?s ?p ?o ~ ?claim >> ?pp :alice };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 4j << ?s ?p ?o ~ ?claim >> ?pp :alice matches the claim\n";

SPARQL PREFIX : <http://ex.org/>
WITH <urn:trdfstar_update:e8s>
DELETE { << ?s ?p ?o ~ ?claim >> ?pp :alice }
INSERT { ?s ?p ?o ~ ?claim {| ?pp :carol |} }
WHERE  { << ?s ?p ?o ~ ?claim >> ?pp :alice };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 4k Example 8 (short form) runs\n";

select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT(*) FROM <urn:trdfstar_update:e8s> WHERE {
  :claim1 :claimedBy :carol ; rdf:reifies <<( :bob :name "Bob" )>> . :bob :name "Bob" .
  FILTER NOT EXISTS { :claim1 :claimedBy :alice } };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 4l the short form reattributes the claim, keeps the reification, asserts the triple\n";

-- 4m. DELETE WHERE over a triple-term pattern.
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT DATA { GRAPH <urn:trdfstar_update:dw> { :claim1 :claimedBy :alice ; rdf:reifies <<( :bob :name "Bob" )>> . :bob :name "Bob" . } };
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
DELETE WHERE { GRAPH <urn:trdfstar_update:dw> { ?c rdf:reifies <<( :bob :name ?n )>> ; :claimedBy ?w } };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 4m DELETE WHERE { ?c rdf:reifies <<( :bob :name ?n )>> ; :claimedBy ?w } runs\n";

select 99;
SPARQL PREFIX : <http://ex.org/> SELECT COUNT(*) FROM <urn:trdfstar_update:dw> WHERE { ?s ?p ?o };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 4n DELETE WHERE removed the reification and the claim, kept :bob :name \"Bob\"\n";

-- 4o. CONSTRUCT WHERE writes the matched triple term, not a new blank node.
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT DATA { GRAPH <urn:trdfstar_update:cw> { :claim1 rdf:reifies <<( :bob :name "Bob" )>> . } };
select 99;
select left (TRDFSTAR_UPDATE_CONSTRUCT_OBJECT ('SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> CONSTRUCT WHERE { GRAPH <urn:trdfstar_update:cw> { ?c rdf:reifies <<( :bob :name ?n )>> } }'), 20);
echo both $if $equ $LAST[1] "urn:rdf-star:triple:" "PASSED" "***FAILED";
echo both ": 4o CONSTRUCT WHERE over a triple-term pattern constructs the triple term\n";

-- 4p. guard: an unnamed reifier in a DELETE template is a blank node, which
--     the DELETE template forbids (SPARQL 1.2 Update, Example 8 note).
select (case when TRDFSTAR_UPDATE_ERROR_OF ('SPARQL PREFIX : <http://ex.org/> WITH <urn:trdfstar_update:e8s> DELETE { << ?s ?p ?o >> :claimedBy ?w } WHERE { << ?s ?p ?o ~ ?c >> :claimedBy ?w }')
  like '%Blank node%not allowed%' then 1 else 0 end);
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 4p DELETE { << ?s ?p ?o >> ... } is rejected: an unnamed reifier is a blank node\n";

--------------------------------------------------------------------------
-- 5. An unnamed reifier is a fresh blank node.
--
--    When << s p o >>, a bare ~ or {| |} names no reifier, RDF 1.2 makes the
--    reifier a fresh blank node, and so does the Turtle loader.  SPARQL INSERT
--    instead rewrote every blank-node subject of an rdf:reifies triple, made
--    by the template or written by the user, into the IRI
--    urn:rdf-star:reifier:<the triple term>
--    (RDF_TRIPLES_CANONICALIZE_GENERATED_REIFIERS, run on every insert batch):
--    two annotations of the same triple became one reifier carrying both, and
--    a reifier named inside another triple term was left as a blank node with
--    no triples.  A reifier written as an IRI is the user's and stays one node.
--------------------------------------------------------------------------

SPARQL CLEAR GRAPH <urn:trdfstar_update:reif>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:reif_user>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:reif_forms>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:reif_nested>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:reif_tmpl>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:reif_named>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:reif_legacy>;

-- 5a. the reifier of an annotation is a blank node.
SPARQL PREFIX : <http://ex.org/>
INSERT DATA { GRAPH <urn:trdfstar_update:reif> { :bob :name "Bob" {| :claimedBy :alice |} } };
select 99;
SPARQL PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT (isBLANK (?r)) FROM <urn:trdfstar_update:reif> WHERE { ?r rdf:reifies ?t };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 5a the reifier of an annotation is a blank node\n";

-- 5b. a second annotation of the same triple is a second reifier, and
--     neither carries the other's claim.
SPARQL PREFIX : <http://ex.org/>
INSERT DATA { GRAPH <urn:trdfstar_update:reif> { :bob :name "Bob" {| :claimedBy :carol |} } };
select 99;
SPARQL PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT (DISTINCT ?r) FROM <urn:trdfstar_update:reif> WHERE { ?r rdf:reifies ?t };
echo both $if $equ $LAST[1] 2 "PASSED" "***FAILED";
echo both ": 5b two annotations of one triple are two reifiers\n";

select 99;
SPARQL PREFIX : <http://ex.org/>
SELECT COUNT(*) FROM <urn:trdfstar_update:reif> WHERE { ?r :claimedBy :alice , :carol };
echo both $if $equ $LAST[1] 0 "PASSED" "***FAILED";
echo both ": 5c no reifier carries both claims\n";

-- 5d. blank-node reifiers written by the user stay the distinct nodes they are.
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT DATA { GRAPH <urn:trdfstar_update:reif_user> {
  _:r1 rdf:reifies <<( :bob :name "Bob" )>> ; :src :x .
  _:r2 rdf:reifies <<( :bob :name "Bob" )>> ; :src :y . } };
select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT(*) FROM <urn:trdfstar_update:reif_user> WHERE { ?r rdf:reifies ?t ; :src ?src . FILTER (isBLANK (?r)) FILTER NOT EXISTS { ?r :src ?other . FILTER (?other != ?src) } };
echo both $if $equ $LAST[1] 2 "PASSED" "***FAILED";
echo both ": 5d _:r1 and _:r2 stay two blank-node reifiers, one source each\n";

-- 5e. the reifier of << s p o >> and of a bare ~ is a blank node.
SPARQL PREFIX : <http://ex.org/>
INSERT DATA { GRAPH <urn:trdfstar_update:reif_forms> { << :a :b :c >> :src :x . :d :e :f ~ . } };
select 99;
SPARQL PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT(*) FROM <urn:trdfstar_update:reif_forms> WHERE { ?r rdf:reifies ?t FILTER (isBLANK (?r)) };
echo both $if $equ $LAST[1] 2 "PASSED" "***FAILED";
echo both ": 5e the reifiers of << s p o >> and of ~ are blank nodes\n";

-- 5f. a reifier named inside another triple term keeps its triples.
SPARQL PREFIX : <http://ex.org/>
INSERT DATA { GRAPH <urn:trdfstar_update:reif_nested> { << :a :b << :c :d :e >> >> :src :x . } };
select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT(*) FROM <urn:trdfstar_update:reif_nested> WHERE { ?r2 rdf:reifies <<( :a :b ?r1 )>> ; :src :x . ?r1 rdf:reifies <<( :c :d :e )>> };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 5f << :a :b << :c :d :e >> >>: the outer term names the inner reifier, which reifies <<( :c :d :e )>>\n";

-- 5g. an INSERT template makes a fresh reifier per solution.
SPARQL PREFIX : <http://ex.org/>
INSERT { GRAPH <urn:trdfstar_update:reif_tmpl> { :a :b :c {| :src ?n |} } } WHERE { VALUES ?n { 1 2 } };
select 99;
SPARQL PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT (DISTINCT ?r) FROM <urn:trdfstar_update:reif_tmpl> WHERE { ?r rdf:reifies ?t };
echo both $if $equ $LAST[1] 2 "PASSED" "***FAILED";
echo both ": 5g two solutions of an INSERT template make two reifiers\n";

-- 5h. guard: a reifier named with an IRI is one node, however often it is written.
SPARQL PREFIX : <http://ex.org/>
INSERT DATA { GRAPH <urn:trdfstar_update:reif_named> { :a :b :c ~ :r {| :src :y |} } };
SPARQL PREFIX : <http://ex.org/>
INSERT DATA { GRAPH <urn:trdfstar_update:reif_named> { :a :b :c ~ :r {| :src :z |} } };
select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT(*) FROM <urn:trdfstar_update:reif_named> WHERE { ?r rdf:reifies ?t ; :src :y , :z . FILTER (?r = :r) };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 5h the named reifier :r is one node with both sources\n";

-- 5i. guard: a reifier stored in the old content-addressed IRI form still
--     reads back through << s p o >>.
create procedure TRDFSTAR_UPDATE_LEGACY_REIFIER ()
{
  declare tt, reif varchar;
  tt := DB.DBA.RDF_STAR_TT_IRI ('http://ex.org/a', 'http://ex.org/b', 'http://ex.org/c');
  reif := cast (DB.DBA.RDF_STAR_REIFIER_IRI (tt) as varchar);
  DB.DBA.TTLP (sprintf ('<%s> <http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies> <%s> . <%s> <http://ex.org/src> <http://ex.org/old> .', reif, tt, reif),
    '', 'urn:trdfstar_update:reif_legacy');
}
;
TRDFSTAR_UPDATE_LEGACY_REIFIER ();
select 99;
SPARQL PREFIX : <http://ex.org/>
SELECT COUNT(*) FROM <urn:trdfstar_update:reif_legacy> WHERE { << :a :b :c >> :src :old };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 5i a stored urn:rdf-star:reifier: reifier still matches << s p o >>\n";
drop procedure TRDFSTAR_UPDATE_LEGACY_REIFIER;

--------------------------------------------------------------------------
-- 6. Every annotation block reifies the triple, once.
--
--    RDF 1.2: in s p o ~ {| ... |} the block is about the reifier the ~
--    makes, and each block that follows no reifier gets a fresh reifier of
--    its own, as the Turtle loader does.  The SPARQL grammar instead gave a
--    block after a bare ~ a reifier of its own, so INSERT stored two reifiers,
--    one with nothing to say, and a WHERE pattern had two unrelated reifier
--    variables; and of two blocks on one triple only the last was made a
--    reifier, leaving the first block's properties on a node that reified
--    nothing.
--------------------------------------------------------------------------

SPARQL CLEAR GRAPH <urn:trdfstar_update:ab>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:ab_two>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:ab_where>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:ab_ttl>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:ab_two_ttl>;

-- 6a. a block after a bare ~ annotates that reifier: one reifier.
SPARQL PREFIX : <http://ex.org/>
INSERT DATA { GRAPH <urn:trdfstar_update:ab> { :d :e :f ~ {| :src :y |} . } };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 6a INSERT DATA of :d :e :f ~ {| :src :y |}\n";

select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT (DISTINCT ?r) FROM <urn:trdfstar_update:ab> WHERE { ?r rdf:reifies ?t };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 6b one reifier\n";

select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT(*) FROM <urn:trdfstar_update:ab> WHERE { ?r rdf:reifies <<( :d :e :f )>> ; :src :y . FILTER (isBLANK (?r)) };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 6c and it is the blank node that carries :src :y\n";

-- 6d. two blocks on one triple: two reifiers, each with its block.
SPARQL PREFIX : <http://ex.org/>
INSERT DATA { GRAPH <urn:trdfstar_update:ab_two> { :a :b :c {| :p1 :o1 |} {| :p2 :o2 |} . } };
select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT(*) FROM <urn:trdfstar_update:ab_two> WHERE {
  ?r1 rdf:reifies <<( :a :b :c )>> ; :p1 :o1 .
  ?r2 rdf:reifies <<( :a :b :c )>> ; :p2 :o2 .
  FILTER (?r1 != ?r2) };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 6d {| :p1 :o1 |} {| :p2 :o2 |}: two reifiers, each reifies the triple\n";

-- 6e. the same shape as the Turtle loader stores, annotation by annotation.
DB.DBA.TTLP ('@prefix : <http://ex.org/> . :d :e :f ~ {| :src :y |} .', '', 'urn:trdfstar_update:ab_ttl');
DB.DBA.TTLP ('@prefix : <http://ex.org/> . :a :b :c {| :p1 :o1 |} {| :p2 :o2 |} .', '', 'urn:trdfstar_update:ab_two_ttl');
select 99;
select (case when
    (select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:trdfstar_update:ab'))
  = (select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:trdfstar_update:ab_ttl'))
  and
    (select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:trdfstar_update:ab_two'))
  = (select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:trdfstar_update:ab_two_ttl'))
  then 1 else 0 end);
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 6e as many quads as TTLP stores for each of the two annotations\n";

-- 6f. in WHERE, the block after ~ constrains that reifier: over a triple
--     with one bare reifier and one annotated reifier there is one match.
DB.DBA.TTLP ('@prefix : <http://ex.org/> . :g :h :i ~ . :g :h :i {| :src :z |} .', '', 'urn:trdfstar_update:ab_where');
select 99;
SPARQL PREFIX : <http://ex.org/>
SELECT COUNT(*) FROM <urn:trdfstar_update:ab_where> WHERE { :g :h :i ~ {| :src :z |} };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 6f WHERE { :g :h :i ~ {| :src :z |} } matches the annotated reifier only\n";

-- 6g. guard: ~ ?r {| |} binds ?r to the annotated reifier.
select 99;
SPARQL PREFIX : <http://ex.org/>
SELECT COUNT(*) FROM <urn:trdfstar_update:ab_where> WHERE { :g :h :i ~ ?r {| :src :z |} };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 6g WHERE { :g :h :i ~ ?r {| :src :z |} } matches once\n";

--------------------------------------------------------------------------
-- 7. A decimal or double in a triple term is one term, however it is written.
--
--    The Turtle loader and the run-time minter encode a number in a triple
--    term with its type ("n:2.5", "d:1.5e0"); the SPARQL compile-time path
--    encoded its original text ("2.5", "1.5e0", "2.50"), so INSERT DATA and
--    TTLP stored the same triple term under two IRIs, its object bound as a
--    string, and "7"^^xsd:integer was not the term 7.  A pattern compared the
--    text of its constant with the text of the stored number, so
--    <<( :x :v 1.5e0 )>> did not match the double 1.5 the loader stores.
--------------------------------------------------------------------------

SPARQL CLEAR GRAPH <urn:trdfstar_update:enc>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:enc_ttl>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:enc_old>;

SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
INSERT DATA { GRAPH <urn:trdfstar_update:enc> {
  :c2 rdf:reifies <<( :x :v 2.5 )>> .
  :c3 rdf:reifies <<( :x :v 1.5e0 )>> .
  :c6 rdf:reifies <<( :x :v 2.50 )>> .
  :c7 rdf:reifies <<( :x :v 7 )>> .
  :c8 rdf:reifies <<( :x :v "7"^^xsd:integer )>> . } };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 7a INSERT DATA of triple terms with decimal, double and integer objects\n";

DB.DBA.TTLP ('@prefix : <http://ex.org/> . @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
:c2 rdf:reifies <<( :x :v 2.5 )>> .
:c3 rdf:reifies <<( :x :v 1.5e0 )>> .
:c6 rdf:reifies <<( :x :v 2.50 )>> .', '', 'urn:trdfstar_update:enc_ttl');

create procedure TRDFSTAR_UPDATE_SAME_TERM (in g1 varchar, in s1 varchar, in g2 varchar, in s2 varchar) returns integer
{
  if ((select O from DB.DBA.RDF_QUAD where G = iri_to_id (g1) and S = iri_to_id (s1))
    = (select O from DB.DBA.RDF_QUAD where G = iri_to_id (g2) and S = iri_to_id (s2)))
    return 1;
  return 0;
}
;

select 99;
select TRDFSTAR_UPDATE_SAME_TERM ('urn:trdfstar_update:enc', 'http://ex.org/c2', 'urn:trdfstar_update:enc_ttl', 'http://ex.org/c2')
     + TRDFSTAR_UPDATE_SAME_TERM ('urn:trdfstar_update:enc', 'http://ex.org/c3', 'urn:trdfstar_update:enc_ttl', 'http://ex.org/c3')
     + TRDFSTAR_UPDATE_SAME_TERM ('urn:trdfstar_update:enc', 'http://ex.org/c6', 'urn:trdfstar_update:enc_ttl', 'http://ex.org/c6');
echo both $if $equ $LAST[1] 3 "PASSED" "***FAILED";
echo both ": 7b 2.5, 1.5e0 and 2.50 are stored as the triple terms TTLP stores\n";

select 99;
select TRDFSTAR_UPDATE_SAME_TERM ('urn:trdfstar_update:enc', 'http://ex.org/c7', 'urn:trdfstar_update:enc', 'http://ex.org/c8');
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 7c <<( :x :v \"7\"^^xsd:integer )>> is the term <<( :x :v 7 )>>\n";

select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT COUNT(*) FROM <urn:trdfstar_update:enc> WHERE {
  { :c2 rdf:reifies <<( ?s ?p ?o )>> FILTER (datatype (?o) = xsd:decimal) }
  UNION
  { :c3 rdf:reifies <<( ?s ?p ?o )>> FILTER (datatype (?o) = xsd:double) } };
echo both $if $equ $LAST[1] 2 "PASSED" "***FAILED";
echo both ": 7d the decimal and the double inserted by SPARQL bind with their datatypes\n";

select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT(*) FROM <urn:trdfstar_update:enc_ttl> WHERE { ?c rdf:reifies <<( :x :v 1.5e0 )>> };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 7e <<( :x :v 1.5e0 )>> matches the double TTLP stored\n";

select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT(*) FROM <urn:trdfstar_update:enc> WHERE { ?c rdf:reifies <<( :x :v 2.5 )>> };
echo both $if $equ $LAST[1] 2 "PASSED" "***FAILED";
echo both ": 7f <<( :x :v 2.5 )>> matches both 2.5 and 2.50\n";

select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT(*) FROM <urn:trdfstar_update:enc> WHERE { ?c rdf:reifies <<( :x :v 1.5e0 )>> };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 7g <<( :x :v 1.5e0 )>> matches the double SPARQL stored\n";

-- 7h. guard: a term stored before this change, with the number as text,
--     still matches a pattern that writes the number the same way.
create procedure TRDFSTAR_UPDATE_OLD_NUMBER_TERM ()
{
  declare tt varchar;
  tt := DB.DBA.RDF_STAR_TT_IRI ('http://ex.org/x', 'http://ex.org/v', '1.5e0');
  DB.DBA.TTLP (sprintf ('<http://ex.org/c9> <http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies> <%s> .', tt),
    '', 'urn:trdfstar_update:enc_old');
}
;
TRDFSTAR_UPDATE_OLD_NUMBER_TERM ();
select 99;
SPARQL PREFIX : <http://ex.org/> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT COUNT(*) FROM <urn:trdfstar_update:enc_old> WHERE { ?c rdf:reifies <<( :x :v 1.5e0 )>> };
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 7h a term stored with the number as text still matches <<( :x :v 1.5e0 )>>\n";
drop procedure TRDFSTAR_UPDATE_OLD_NUMBER_TERM;
drop procedure TRDFSTAR_UPDATE_SAME_TERM;

--------------------------------------------------------------------------
-- cleanup
--------------------------------------------------------------------------

SPARQL CLEAR GRAPH <urn:trdfstar_update:num>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:e8>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:e8_copy>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:e8s>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:e8n>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:e8n_ref>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:dw>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:cw>;
drop procedure TRDFSTAR_UPDATE_CONSTRUCT_OBJECT;
SPARQL CLEAR GRAPH <urn:trdfstar_update:enc>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:enc_ttl>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:enc_old>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:ab>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:ab_two>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:ab_where>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:ab_ttl>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:ab_two_ttl>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:reif>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:reif_user>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:reif_forms>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:reif_nested>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:reif_tmpl>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:reif_named>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:reif_legacy>;

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

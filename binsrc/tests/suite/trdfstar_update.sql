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
-- cleanup
--------------------------------------------------------------------------

SPARQL CLEAR GRAPH <urn:trdfstar_update:nested>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:nested_ttl>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:nested_ins>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:nested3>;
SPARQL CLEAR GRAPH <urn:trdfstar_update:nested3_ttl>;

ECHO BOTH "COMPLETED: RDF 1.2 triple terms through SPARQL Update (trdfstar_update.sql)\n";

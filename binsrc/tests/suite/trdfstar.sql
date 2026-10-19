--
--  trdfstar.sql
--
--  RDF 1.2 (RDF-star) triple terms and reifiers, exercised through SPARQL.
--
--  These assertions are CaseMode sensitive by design.  The suite runs at
--  CaseMode 1 by default (testlib.sh), and the RDF 1.2 helper functions used
--  to read DB.DBA.RDF_QUAD through quoted lower case column names, which only
--  resolve under the case insensitive comparison of CaseMode 2.  At CaseMode
--  0 and 1 every statement below failed with S0022 / SQ200 "No column s.",
--  making RDF 1.2 unusable from SPARQL on those servers while the Turtle
--  parser kept working.  Nothing in the suite covered RDF 1.2 at all, so the
--  feature was entirely unusable there without a single test going red.
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

ECHO BOTH "STARTED: RDF 1.2 triple term tests (trdfstar.sql)\n";

select cfg_item_value (virtuoso_ini_path (), 'Parameters', 'CaseMode');
ECHO BOTH "CaseMode of the server under test: " $LAST[1] "\n";

SPARQL CLEAR GRAPH <urn:trdfstar:load>;
SPARQL CLEAR GRAPH <urn:trdfstar:tt>;
SPARQL CLEAR GRAPH <urn:trdfstar:ann>;

--------------------------------------------------------------------------
-- 1. the RDF 1.2 helper functions must be callable at every CaseMode.
--    Each of these used to raise S0022 before running a single line of its
--    own body: the whole procedure body, including the RDF_QUAD select, is
--    compiled on first invocation, so even the early return paths failed.
--------------------------------------------------------------------------

select DB.DBA.RDF_STAR_REIFIER_IRI ('urn:rdf-star:triple:1:2:3');
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": RDF_STAR_REIFIER_IRI is callable\n";
echo both $if $equ $LAST[1] "urn:rdf-star:reifier:1:2:3" "PASSED" "***FAILED";
echo both ": RDF_STAR_REIFIER_IRI maps a triple term IRI to its reifier\n";

select DB.DBA.RDF_STAR_REIFIER_TO_TRIPLE_IRI ('urn:rdf-star:reifier:1:2:3');
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": RDF_STAR_REIFIER_TO_TRIPLE_IRI is callable\n";
echo both $if $equ $LAST[1] "urn:rdf-star:triple:1:2:3" "PASSED" "***FAILED";
echo both ": RDF_STAR_REIFIER_TO_TRIPLE_IRI maps a reifier IRI back to its triple term\n";

select DB.DBA.RDF_STAR_TT_CHECK ('urn:trdfstar:no:such:node', 0, 0, 0);
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": RDF_STAR_TT_CHECK is callable\n";
echo both $if $equ $LAST[1] 0 "PASSED" "***FAILED";
echo both ": RDF_STAR_TT_CHECK says no for a node that reifies nothing\n";

--------------------------------------------------------------------------
-- 2. the Turtle parser side, which was never affected, is the fixture.
--------------------------------------------------------------------------

DB.DBA.TTLP ('<urn:trdfstar:a> <urn:trdfstar:e> <urn:trdfstar:b> {| <urn:trdfstar:w> 0.5 |} .', '', 'urn:trdfstar:load');
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": TTLP loads a triple carrying an RDF 1.2 annotation\n";

SPARQL SELECT (COUNT(*) AS ?n) FROM <urn:trdfstar:load> WHERE { ?s ?p ?o };
echo both $if $equ $LAST[1] 3 "PASSED" "***FAILED";
echo both ": the annotated triple is stored as 3 quads (triple, rdf:reifies, annotation)\n";

--------------------------------------------------------------------------
-- 3. the stored reifier lookup -- this is the code path that actually
--    reads DB.DBA.RDF_QUAD, so it is the one the wrong column spelling
--    made unreachable.
--------------------------------------------------------------------------

select left (DB.DBA.RDF_STAR_REIFIER_IRI (
    (select id_to_iri (S) from DB.DBA.RDF_QUAD
      where G = iri_to_id ('urn:trdfstar:load')
        and P = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies'))), 21);
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": RDF_STAR_REIFIER_IRI resolves a stored reifier node\n";
echo both $if $equ $LAST[1] "urn:rdf-star:reifier:" "PASSED" "***FAILED";
echo both ": the stored reifier node maps to a urn:rdf-star:reifier: IRI\n";

select DB.DBA.RDF_STAR_TT_CHECK (
    (select id_to_iri (S) from DB.DBA.RDF_QUAD
      where G = iri_to_id ('urn:trdfstar:load')
        and P = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies')),
    'urn:trdfstar:a', 'urn:trdfstar:e', 'urn:trdfstar:b');
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": RDF_STAR_TT_CHECK confirms the s/p/o a stored reifier stands for\n";

select DB.DBA.RDF_STAR_TT_CHECK (
    (select id_to_iri (S) from DB.DBA.RDF_QUAD
      where G = iri_to_id ('urn:trdfstar:load')
        and P = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies')),
    'urn:trdfstar:WRONG', 'urn:trdfstar:e', 'urn:trdfstar:b');
echo both $if $equ $LAST[1] 0 "PASSED" "***FAILED";
echo both ": RDF_STAR_TT_CHECK rejects a subject the reifier does not stand for\n";

--------------------------------------------------------------------------
-- 4. reading a triple term from SPARQL.  RDF_STAR_TT_CHECK is what the
--    SPARQL compiler emits for a << s p o >> pattern, so a plain SELECT
--    failed the same way an update did.
--------------------------------------------------------------------------

SPARQL SELECT (COUNT(*) AS ?n) FROM <urn:trdfstar:load>
  WHERE { << <urn:trdfstar:a> <urn:trdfstar:e> <urn:trdfstar:b> >> ?a ?b };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": SPARQL SELECT over a << s p o >> pattern compiles and runs\n";
echo both $if $equ $LAST[1] 2 "PASSED" "***FAILED";
echo both ": the triple term carries 2 properties (rdf:reifies and the annotation)\n";

SPARQL SELECT (xsd:double (?b) AS ?w) FROM <urn:trdfstar:load>
  WHERE { << <urn:trdfstar:a> <urn:trdfstar:e> <urn:trdfstar:b> >> <urn:trdfstar:w> ?b };
echo both $if $equ $LAST[1] 0.5 "PASSED" "***FAILED";
echo both ": the annotation value loaded by TTLP reads back through << s p o >>\n";

--------------------------------------------------------------------------
-- 5. writing a triple term from SPARQL, both spellings, then reading it
--    back.  A round trip, so a silent no-op write cannot pass.
--------------------------------------------------------------------------

SPARQL INSERT INTO GRAPH <urn:trdfstar:tt>
  { << <urn:trdfstar:a2> <urn:trdfstar:e2> <urn:trdfstar:b2> >> <urn:trdfstar:w> 0.25 . };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": SPARQL INSERT of a << s p o >> triple term\n";

SPARQL SELECT (xsd:double (?b) AS ?w) FROM <urn:trdfstar:tt>
  WHERE { << <urn:trdfstar:a2> <urn:trdfstar:e2> <urn:trdfstar:b2> >> <urn:trdfstar:w> ?b };
echo both $if $equ $LAST[1] 0.25 "PASSED" "***FAILED";
echo both ": the << s p o >> insert round trips\n";

SPARQL INSERT INTO GRAPH <urn:trdfstar:ann>
  { <urn:trdfstar:a3> <urn:trdfstar:e3> <urn:trdfstar:b3> {| <urn:trdfstar:w> 0.75 |} . };
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": SPARQL INSERT of an {| p v |} annotation\n";

SPARQL SELECT (xsd:double (?b) AS ?w) FROM <urn:trdfstar:ann>
  WHERE { << <urn:trdfstar:a3> <urn:trdfstar:e3> <urn:trdfstar:b3> >> <urn:trdfstar:w> ?b };
echo both $if $equ $LAST[1] 0.75 "PASSED" "***FAILED";
echo both ": the {| p v |} insert round trips through a << s p o >> read\n";

SPARQL SELECT (COUNT(*) AS ?n) FROM <urn:trdfstar:ann> WHERE { ?s ?p ?o };
echo both $if $equ $LAST[1] 3 "PASSED" "***FAILED";
echo both ": the {| p v |} insert stored the same 3 quads TTLP stores\n";

--------------------------------------------------------------------------
-- 6. cleanup
--------------------------------------------------------------------------

SPARQL CLEAR GRAPH <urn:trdfstar:load>;
SPARQL CLEAR GRAPH <urn:trdfstar:tt>;
SPARQL CLEAR GRAPH <urn:trdfstar:ann>;

ECHO BOTH "COMPLETED: RDF 1.2 triple term tests (trdfstar.sql)\n";

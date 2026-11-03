--
--  trdfinf_count.sql
--
--  Under a rule set, a quad pattern has one solution per stored triple and
--  inferred class (or property) it derives, whether or not the variable that
--  carries the inferred value is read.  COUNT (*), COUNT (?s) and a listing
--  that leaves the type out must count what a listing of the type counts.
--  With the property open, a class is inferred for the objects of rdf:type
--  triples only.
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

ECHO BOTH "STARTED: inferred solutions counted whether or not the inferred variable is read\n";

sparql clear graph <urn:tic:data>;
sparql clear graph <urn:tic:schema>;
DB.DBA.TTLP ('@prefix ex: <urn:tic:> . @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
ex:Partner rdfs:subClassOf ex:Lawyer . ex:Associate rdfs:subClassOf ex:Lawyer .
ex:Lawyer rdfs:subClassOf ex:Person . ex:Paralegal rdfs:subClassOf ex:Person .
ex:worksFor rdfs:subPropertyOf ex:affiliatedWith . ex:affiliatedWith rdfs:subPropertyOf ex:relatedTo .', '', 'urn:tic:schema');
--  jdoe has two stored types on one chain; ex:x likes a class (not a type triple).
DB.DBA.TTLP ('@prefix ex: <urn:tic:> .
ex:jdoe a ex:Partner . ex:jdoe a ex:Lawyer . ex:asmith a ex:Associate . ex:clee a ex:Person . ex:bkhan a ex:Paralegal .
ex:jdoe ex:worksFor ex:firm . ex:asmith ex:affiliatedWith ex:firm . ex:x ex:likes ex:Partner .', '', 'urn:tic:data');
rdfs_rule_set ('tic-rules', 'urn:tic:schema');

--  ?s a ?t: 3 + 2 (jdoe) + 3 (asmith) + 1 (clee) + 2 (bkhan) = 11 derivations.
sparql define input:inference "tic-rules" select ?s ?t from <urn:tic:data> where { ?s a ?t };
ECHO BOTH $IF $EQU $ROWCNT 11 "PASSED" "***FAILED";
ECHO BOTH ": guard, ?s a ?t listed with the type: " $ROWCNT " rows\n";

sparql define input:inference "tic-rules" select count (?t) from <urn:tic:data> where { ?s a ?t };
ECHO BOTH $IF $EQU $LAST[1] 11 "PASSED" "***FAILED";
ECHO BOTH ": guard, COUNT (?t) of ?s a ?t: " $LAST[1] "\n";

sparql define input:inference "tic-rules" select count (*) from <urn:tic:data> where { ?s a ?t };
ECHO BOTH $IF $EQU $LAST[1] 11 "PASSED" "***FAILED";
ECHO BOTH ": COUNT (*) of ?s a ?t: " $LAST[1] "\n";

sparql define input:inference "tic-rules" select count (?s) from <urn:tic:data> where { ?s a ?t };
ECHO BOTH $IF $EQU $LAST[1] 11 "PASSED" "***FAILED";
ECHO BOTH ": COUNT (?s) of ?s a ?t: " $LAST[1] "\n";

sparql define input:inference "tic-rules" select ?s from <urn:tic:data> where { ?s a ?t };
ECHO BOTH $IF $EQU $ROWCNT 11 "PASSED" "***FAILED";
ECHO BOTH ": ?s a ?t listed without the type: " $ROWCNT " rows\n";

sparql define input:inference "tic-rules" select count (*) from <urn:tic:data> where { <urn:tic:jdoe> a ?t };
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": COUNT (*) of one subject's types: " $LAST[1] "\n";

--  ?s ?p ?o: the 11 type derivations, worksFor 3, affiliatedWith 2, likes 1 = 17.
sparql define input:inference "tic-rules" select ?s ?p ?o from <urn:tic:data> where { ?s ?p ?o };
ECHO BOTH $IF $EQU $ROWCNT 17 "PASSED" "***FAILED";
ECHO BOTH ": guard, ?s ?p ?o listed: " $ROWCNT " rows\n";

sparql define input:inference "tic-rules" select count (*) from <urn:tic:data> where { ?s ?p ?o };
ECHO BOTH $IF $EQU $LAST[1] 17 "PASSED" "***FAILED";
ECHO BOTH ": COUNT (*) of ?s ?p ?o: " $LAST[1] "\n";

sparql define input:inference "tic-rules" select count (?p) from <urn:tic:data> where { ?s ?p ?o };
ECHO BOTH $IF $EQU $LAST[1] 17 "PASSED" "***FAILED";
ECHO BOTH ": COUNT (?p) of ?s ?p ?o, the object not read: " $LAST[1] "\n";

sparql define input:inference "tic-rules" select count (?o) from <urn:tic:data> where { ?s ?p ?o };
ECHO BOTH $IF $EQU $LAST[1] 17 "PASSED" "***FAILED";
ECHO BOTH ": COUNT (?o) of ?s ?p ?o, the property not read: " $LAST[1] "\n";

sparql define input:inference "tic-rules" select ?s ?o from <urn:tic:data> where { ?s ?p ?o };
ECHO BOTH $IF $EQU $ROWCNT 17 "PASSED" "***FAILED";
ECHO BOTH ": ?s ?p ?o listed without the property: " $ROWCNT " rows\n";

--  ex:x likes ex:Partner is not a type triple: no Lawyer, no Person for it.
sparql define input:inference "tic-rules" select ?o from <urn:tic:data> where { <urn:tic:x> ?p ?o };
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": the object of a non-type triple, property not read: " $ROWCNT " rows\n";

sparql define input:inference "tic-rules" select distinct ?s ?o from <urn:tic:data> where { ?s ?p ?o };
ECHO BOTH $IF $EQU $ROWCNT 12 "PASSED" "***FAILED";
ECHO BOTH ": DISTINCT ?s ?o, property not read: " $ROWCNT " rows\n";

--  The object given, the property open: Person by 5 derivations, firm by 5.
sparql define input:inference "tic-rules" select ?s ?p from <urn:tic:data> where { ?s ?p <urn:tic:Person> };
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
ECHO BOTH ": guard, ?s ?p ex:Person listed with the property: " $ROWCNT " rows\n";

sparql define input:inference "tic-rules" select ?s from <urn:tic:data> where { ?s ?p <urn:tic:Person> };
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
ECHO BOTH ": ?s ?p ex:Person listed without the property: " $ROWCNT " rows\n";

sparql define input:inference "tic-rules" select count (*) from <urn:tic:data> where { ?s ?p <urn:tic:firm> };
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": COUNT (*) of ?s ?p ex:firm: " $LAST[1] "\n";

--  Both sides of a join, the rule-set table hashed or looked up: jdoe's 5 types.
select count (*) from DB.DBA.RDF_QUAD b, DB.DBA.RDF_QUAD a table option (with 'tic-rules', hash)
  where a.G = iri_to_id ('urn:tic:data') and b.G = iri_to_id ('urn:tic:data')
  and a.P = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type') and b.P = iri_to_id ('urn:tic:worksFor')
  and b.S = a.S option (order);
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": COUNT (*) of a join, the rule-set table hashed: " $LAST[1] "\n";

select count (*) from DB.DBA.RDF_QUAD b, DB.DBA.RDF_QUAD a table option (with 'tic-rules', loop)
  where a.G = iri_to_id ('urn:tic:data') and b.G = iri_to_id ('urn:tic:data')
  and a.P = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type') and b.P = iri_to_id ('urn:tic:worksFor')
  and b.S = a.S option (order);
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": COUNT (*) of a join, the rule-set table looked up: " $LAST[1] "\n";

--  Guards: what does not change.
sparql define input:inference "tic-rules" select count (*) from <urn:tic:data> where { ?s a <urn:tic:Person> };
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": guard, COUNT (*) of a fixed class, one per derivation: " $LAST[1] "\n";

sparql define input:inference "tic-rules" select count (distinct ?s) from <urn:tic:data> where { ?s a ?t };
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": guard, COUNT (DISTINCT ?s) of ?s a ?t: " $LAST[1] "\n";

sparql define input:inference "tic-rules" select distinct ?s from <urn:tic:data> where { ?s a ?t };
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
ECHO BOTH ": guard, DISTINCT ?s of ?s a ?t: " $ROWCNT " rows\n";

sparql define input:inference "tic-rules" select distinct ?s from <urn:tic:data> where { ?s ?p ?o };
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
ECHO BOTH ": guard, DISTINCT ?s of ?s ?p ?o: " $ROWCNT " rows\n";

sparql define input:inference "tic-rules" select ?t count (*) from <urn:tic:data> where { ?s a ?t } group by ?t order by ?t;
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
ECHO BOTH ": guard, ?s a ?t grouped by type: " $ROWCNT " groups\n";

sparql define input:inference "tic-rules" ask from <urn:tic:data> where { ?s a ?t };
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": guard, ASK ?s a ?t: " $LAST[1] "\n";

sparql select count (*) from <urn:tic:data> where { ?s a ?t };
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": guard, no rule set, COUNT (*) of ?s a ?t: " $LAST[1] "\n";

sparql select count (*) from <urn:tic:data> where { ?s ?p ?o };
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": guard, no rule set, COUNT (*) of ?s ?p ?o: " $LAST[1] "\n";

sparql clear graph <urn:tic:data>;
sparql clear graph <urn:tic:schema>;

ECHO BOTH "COMPLETED: inferred solutions counted whether or not the inferred variable is read\n";

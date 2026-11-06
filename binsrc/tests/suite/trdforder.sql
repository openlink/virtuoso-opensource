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

-- RDF ORDER BY: native value ordering and the __rdf_order_rank kind of term
ECHO BOTH "STARTED: RDF ORDER BY rank tests\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

-- A. Plain value ordering, from PR #1482. No triple term here, so no rank is
-- injected: these check the ordinary ORDER BY path is unchanged.


-- Check double ASC without explicitly casting the ordering expression.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?s WHERE { VALUES ?s { "63.0" "112.0" "-20" "-1000" "0" }
BIND (STRDT (?s, xsd:double) AS ?v) } ORDER BY ASC (?v) LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": double ASC query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": double ASC row count\n";
ECHO BOTH $IF $EQU $LAST[1] "-1000" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": double ASC value = " $LAST[1] "\n";

-- Check double DESC without explicitly casting the ordering expression.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?s WHERE { VALUES ?s { "63.0" "112.0" "-20" "-1000" "0" }
BIND (STRDT (?s, xsd:double) AS ?v) } ORDER BY DESC (?v) LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": double DESC query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": double DESC row count\n";
ECHO BOTH $IF $EQU $LAST[1] "112.0" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": double DESC value = " $LAST[1] "\n";

-- Check integer ASC without explicitly casting the ordering expression.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?s WHERE { VALUES ?s { "125" "98" "9" "-20" "-1000" "0" }
BIND (STRDT (?s, xsd:integer) AS ?v) } ORDER BY ASC (?v) LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": integer ASC query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": integer ASC row count\n";
ECHO BOTH $IF $EQU $LAST[1] "-1000" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": integer ASC value = " $LAST[1] "\n";

-- Check integer DESC without explicitly casting the ordering expression.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?s WHERE { VALUES ?s { "125" "98" "9" "-20" "-1000" "0" }
BIND (STRDT (?s, xsd:integer) AS ?v) } ORDER BY DESC (?v) LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": integer DESC query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": integer DESC row count\n";
ECHO BOTH $IF $EQU $LAST[1] "125" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": integer DESC value = " $LAST[1] "\n";

-- Check decimal ASC without explicitly casting the ordering expression.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?s WHERE { VALUES ?s { "100000000000000000000000000001" "100000000000000000000000000000" "-100000000000000000000000000001" "0" "1.25" }
BIND (STRDT (?s, xsd:decimal) AS ?v) } ORDER BY ASC (?v) LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": decimal ASC query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": decimal ASC row count\n";
ECHO BOTH $IF $EQU $LAST[1] "-100000000000000000000000000001" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": decimal ASC value = " $LAST[1] "\n";

-- Check decimal DESC without explicitly casting the ordering expression.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?s WHERE { VALUES ?s { "100000000000000000000000000001" "100000000000000000000000000000" "-100000000000000000000000000001" "0" "1.25" }
BIND (STRDT (?s, xsd:decimal) AS ?v) } ORDER BY DESC (?v) LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": decimal DESC query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": decimal DESC row count\n";
ECHO BOTH $IF $EQU $LAST[1] "100000000000000000000000000001" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": decimal DESC value = " $LAST[1] "\n";

-- Check numeric LIMIT/OFFSET without explicitly casting the ordering expression.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?s WHERE { VALUES ?s { "125" "98" "9" }
BIND (STRDT (?s, xsd:double) AS ?v) } ORDER BY ?v LIMIT 1 OFFSET 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": numeric LIMIT/OFFSET query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": numeric LIMIT/OFFSET row count\n";
ECHO BOTH $IF $EQU $LAST[1] "98" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": numeric LIMIT/OFFSET value = " $LAST[1] "\n";

-- Check mixed numeric types without explicitly casting the ordering expression.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?s WHERE { VALUES (?s ?type) { ("9" xsd:integer) ("120" xsd:double) ("114" xsd:decimal) }
BIND (STRDT (?s, ?type) AS ?v) } ORDER BY DESC (?v) LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed numeric types query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed numeric types row count\n";
ECHO BOTH $IF $EQU $LAST[1] "120" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed numeric types value = " $LAST[1] "\n";

-- Check strings remain lexical without explicitly casting the ordering expression.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?s WHERE { VALUES ?s { "x" "2" "10" }
BIND (STRDT (?s, xsd:string) AS ?v) } ORDER BY ?v LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": strings remain lexical query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": strings remain lexical row count\n";
ECHO BOTH $IF $EQU $LAST[1] "10" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": strings remain lexical value = " $LAST[1] "\n";

-- Check dateTime timezone order without explicitly casting the ordering expression.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?s WHERE { VALUES ?s { "2010-01-01T00:00:00Z" "2009-12-31T20:00:00-05:00" }
BIND (STRDT (?s, xsd:dateTime) AS ?v) } ORDER BY DESC (?v) LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dateTime timezone order query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dateTime timezone order row count\n";
ECHO BOTH $IF $EQU $LAST[1] "2009-12-31T20:00:00-05:00" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dateTime timezone order value = " $LAST[1] "\n";

-- Check multiple sort directions without explicitly casting the ordering expression.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?s WHERE { VALUES (?group ?s) { ("a" "98") ("a" "125") ("b" "9") }
BIND (STRDT (?s, xsd:double) AS ?v) } ORDER BY ?group DESC (?v) LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": multiple sort directions query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": multiple sort directions row count\n";
ECHO BOTH $IF $EQU $LAST[1] "125" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": multiple sort directions value = " $LAST[1] "\n";

-- Check native numeric expression without explicitly casting the ordering expression.
SPARQL SELECT ?label WHERE { VALUES (?label ?v) { ("small" 9) ("largest" 125) ("middle" 98) } }
ORDER BY DESC (?v) LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": native numeric expression query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": native numeric expression row count\n";
ECHO BOTH $IF $EQU $LAST[1] "largest" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": native numeric expression value = " $LAST[1] "\n";

-- Check unbound before bound without explicitly casting the ordering expression.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?label WHERE { VALUES (?label ?s) { ("unbound" UNDEF) ("bound" "112") }
BIND (STRDT (?s, xsd:double) AS ?v) } ORDER BY ?v LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": unbound before bound query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": unbound before bound row count\n";
ECHO BOTH $IF $EQU $LAST[1] "unbound" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": unbound before bound value = " $LAST[1] "\n";

-- Check IRI before literal without explicitly casting the ordering expression.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?label WHERE { VALUES (?label ?v) { ("literal" "112"^^xsd:integer) ("iri" <urn:trdforder:item>) } }
ORDER BY ?v LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": IRI before literal query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": IRI before literal row count\n";
ECHO BOTH $IF $EQU $LAST[1] "iri" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": IRI before literal value = " $LAST[1] "\n";


-- B. __rdf_order_rank on constants (scalar bif)

select __rdf_order_rank (NULL);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank NULL state\n";
ECHO BOTH $IF $EQU $LAST[1] "0" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank NULL = " $LAST[1] " (expected 0)\n";

select __rdf_order_rank ('http://example.com/a');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank plain string state\n";
ECHO BOTH $IF $EQU $LAST[1] "3" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank plain string = " $LAST[1] " (expected 3)\n";

select __rdf_order_rank (5);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank integer state\n";
ECHO BOTH $IF $EQU $LAST[1] "3" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank integer = " $LAST[1] " (expected 3)\n";

select __rdf_order_rank (now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank datetime state\n";
ECHO BOTH $IF $EQU $LAST[1] "3" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank datetime = " $LAST[1] " (expected 3)\n";

select __rdf_order_rank (__bft ('http://example.com/a', 1));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank IRI string state\n";
ECHO BOTH $IF $EQU $LAST[1] "2" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank IRI string = " $LAST[1] " (expected 2)\n";

select __rdf_order_rank (__uname ('http://example.com/a'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank UNAME state\n";
ECHO BOTH $IF $EQU $LAST[1] "2" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank UNAME = " $LAST[1] " (expected 2)\n";

select __rdf_order_rank (__bft ('nodeID://b1', 1));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank blank node string state\n";
ECHO BOTH $IF $EQU $LAST[1] "1" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank blank node string = " $LAST[1] " (expected 1)\n";

select __rdf_order_rank (__bft ('_:b1', 1));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank _: string state\n";
ECHO BOTH $IF $EQU $LAST[1] "1" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank _: string = " $LAST[1] " (expected 1)\n";

select __rdf_order_rank (__bft ('urn:rdf-star:triple:1:2:i3', 1));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank triple term IRI state\n";
ECHO BOTH $IF $EQU $LAST[1] "4" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank triple term IRI = " $LAST[1] " (expected 4)\n";

select __rdf_order_rank ('urn:rdf-star:triple:1:2:i3');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank triple prefix literal state\n";
ECHO BOTH $IF $EQU $LAST[1] "3" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank triple prefix literal = " $LAST[1] " (expected 3)\n";

select __rdf_order_rank (iri_id_from_num (100));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank IRI_ID state\n";
ECHO BOTH $IF $EQU $LAST[1] "2" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank IRI_ID = " $LAST[1] " (expected 2)\n";

select __rdf_order_rank (iri_id_from_num (4611686018427387905));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank bnode IRI_ID state\n";
ECHO BOTH $IF $EQU $LAST[1] "1" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank bnode IRI_ID = " $LAST[1] " (expected 1)\n";


-- C. __rdf_order_rank over query values (vectored bif); an ANY table column drops BF_IRI on storage, so values come from the query
SPARQL SELECT (SUM (bif:__rdf_order_rank (?x)) AS ?n) WHERE { VALUES ?x { <urn:trdforder:a> 5 "s" "urn:rdf-star:triple:1:2:i3" } };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": vectored rank of IRI, literals, triple-prefix literal state\n";
ECHO BOTH $IF $EQU $LAST[1] "11" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": vectored rank of IRI, literals, triple-prefix literal = " $LAST[1] " (expected 11)\n";
SPARQL SELECT (COUNT (*) AS ?n) WHERE { VALUES ?x { <urn:trdforder:a> <urn:trdforder:b> 5 } FILTER (bif:__rdf_order_rank (?x) = 2) };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": vectored rank IRIs state\n";
ECHO BOTH $IF $EQU $LAST[1] "2" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": vectored rank IRIs = " $LAST[1] " (expected 2)\n";
SPARQL SELECT (COUNT (*) AS ?n) WHERE { VALUES ?o { <urn:trdforder:c> <urn:trdforder:b> 7 }
BIND (<<( <urn:trdforder:s> <urn:trdforder:p> ?o )>> AS ?t) FILTER (bif:__rdf_order_rank (?t) = 4) };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": vectored rank triple terms state\n";
ECHO BOTH $IF $EQU $LAST[1] "3" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": vectored rank triple terms = " $LAST[1] " (expected 3)\n";

drop table TRDFORDER_IID;
create table TRDFORDER_IID (ID integer primary key, X IRI_ID_8);
insert into TRDFORDER_IID values (1, iri_id_from_num (100));
insert into TRDFORDER_IID values (2, NULL);
insert into TRDFORDER_IID values (3, iri_id_from_num (4611686018427387905));
select sum (__rdf_order_rank (X) * ID) from TRDFORDER_IID;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": vectored rank of nullable IRI_ID column state\n";
ECHO BOTH $IF $EQU $LAST[1] "5" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": vectored rank of nullable IRI_ID column = " $LAST[1] " (expected 5)\n";
drop table TRDFORDER_IID;

-- D. The rank is injected only where the query builds a triple term

select case when strstr (cast (sparql_to_sql_text ('SELECT ?v WHERE { VALUES ?v { 2 1 } } ORDER BY ?v') as varchar), '__rdf_order_rank') is null then 'no' else 'yes' end;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no rank for plain values state\n";
ECHO BOTH $IF $EQU $LAST[1] "no" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no rank for plain values = " $LAST[1] " (expected no)\n";

select case when strstr (cast (sparql_to_sql_text ('SELECT ?o WHERE { ?s ?p ?o } ORDER BY ?o') as varchar), '__rdf_order_rank') is null then 'no' else 'yes' end;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no rank for stored O state\n";
ECHO BOTH $IF $EQU $LAST[1] "no" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no rank for stored O = " $LAST[1] " (expected no)\n";

select case when strstr (cast (sparql_to_sql_text ('SELECT ?o WHERE { VALUES ?o { <urn:trdforder:c> <urn:trdforder:b> } BIND (<<( <urn:trdforder:s> <urn:trdforder:p> ?o )>> AS ?t) } ORDER BY ?t') as varchar), '__rdf_order_rank') is null then 'no' else 'yes' end;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank for <<( )>> BIND state\n";
ECHO BOTH $IF $EQU $LAST[1] "yes" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank for <<( )>> BIND = " $LAST[1] " (expected yes)\n";

select case when strstr (cast (sparql_to_sql_text ('SELECT ?o WHERE { VALUES ?o { <urn:trdforder:c> <urn:trdforder:b> } BIND (TRIPLE (<urn:trdforder:s>, <urn:trdforder:p>, ?o) AS ?t) } ORDER BY ?t') as varchar), '__rdf_order_rank') is null then 'no' else 'yes' end;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank for TRIPLE() BIND state\n";
ECHO BOTH $IF $EQU $LAST[1] "yes" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank for TRIPLE() BIND = " $LAST[1] " (expected yes)\n";

select case when strstr (cast (sparql_to_sql_text ('SELECT ?t WHERE { { VALUES ?o { <urn:trdforder:c> } BIND (<<( <urn:trdforder:s> <urn:trdforder:p> ?o )>> AS ?t) } UNION { VALUES ?t { 5 <urn:trdforder:i> } } } ORDER BY ?t') as varchar), '__rdf_order_rank') is null then 'no' else 'yes' end;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank for UNION of triple term and plain values state\n";
ECHO BOTH $IF $EQU $LAST[1] "yes" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rank for UNION of triple term and plain values = " $LAST[1] " (expected yes)\n";


-- E. Results with triple terms

-- triple terms compare by their own IRI text, which encodes component IRI ids
SPARQL SELECT ?o WHERE { VALUES ?o { <urn:trdforder:c> <urn:trdforder:b> }
BIND (<<( <urn:trdforder:s> <urn:trdforder:p> ?o )>> AS ?t) } ORDER BY STR (?t) LIMIT 1;
SET ARGV[2] $LAST[1];
SPARQL SELECT ?o WHERE { VALUES ?o { <urn:trdforder:c> <urn:trdforder:b> }
BIND (<<( <urn:trdforder:s> <urn:trdforder:p> ?o )>> AS ?t) } ORDER BY ?t LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": triple terms sort state\n";
ECHO BOTH $IF $EQU $LAST[1] $ARGV[2] "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": triple terms sort by their IRI = " $LAST[1] " (expected " $ARGV[2] ")\n";

SPARQL SELECT ?label WHERE {
{ BIND (<<( <urn:trdforder:s> <urn:trdforder:p> <urn:trdforder:o> )>> AS ?t) BIND ("tt" AS ?label) }
UNION { VALUES (?label ?t) { ("lit" 5) ("iri" <urn:trdforder:i>) } } } ORDER BY DESC (?t) LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": triple term last in UNION state\n";
ECHO BOTH $IF $EQU $LAST[1] "tt" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": triple term last in UNION, DESC first = " $LAST[1] " (expected tt)\n";

-- mixed kinds in one column: IRI, then literal, then triple term (SPARQL 1.2 15.1)
SPARQL SELECT ?label WHERE {
{ VALUES ?o { <urn:trdforder:o> } BIND (<<( <urn:trdforder:s> <urn:trdforder:p> ?o )>> AS ?t) BIND ("tt" AS ?label) }
UNION { VALUES (?label ?t) { ("lit" 5) ("iri" <urn:trdforder:i>) } } } ORDER BY ?t LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed kinds ASC, first is the IRI state\n";
ECHO BOTH $IF $EQU $LAST[1] "iri" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed kinds ASC, first is the IRI = " $LAST[1] " (expected iri)\n";
SPARQL SELECT ?label WHERE {
{ VALUES ?o { <urn:trdforder:o> } BIND (<<( <urn:trdforder:s> <urn:trdforder:p> ?o )>> AS ?t) BIND ("tt" AS ?label) }
UNION { VALUES (?label ?t) { ("lit" 5) ("iri" <urn:trdforder:i>) } } } ORDER BY ?t LIMIT 1 OFFSET 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed kinds ASC, second is the literal state\n";
ECHO BOTH $IF $EQU $LAST[1] "lit" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed kinds ASC, second is the literal = " $LAST[1] " (expected lit)\n";
SPARQL SELECT ?label WHERE {
{ VALUES ?o { <urn:trdforder:o> } BIND (<<( <urn:trdforder:s> <urn:trdforder:p> ?o )>> AS ?t) BIND ("tt" AS ?label) }
UNION { VALUES (?label ?t) { ("lit" 5) ("iri" <urn:trdforder:i>) } } } ORDER BY ?t LIMIT 1 OFFSET 2;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed kinds ASC, last is the triple term state\n";
ECHO BOTH $IF $EQU $LAST[1] "tt" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed kinds ASC, last is the triple term = " $LAST[1] " (expected tt)\n";


ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: RDF ORDER BY rank tests\n";

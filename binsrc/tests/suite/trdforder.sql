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

-- Check native numeric, datetime and string values on the RDF-star ordering path.
ECHO BOTH "STARTED: RDF native value ordering tests\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

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

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: RDF native value ordering tests\n";

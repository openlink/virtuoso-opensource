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

-- Check the implementation-defined ordering of partial and complete dates.
ECHO BOTH "STARTED: RDF partial date ordering tests\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

-- Check mixed year and date DESC using the existing datetime parser normalization.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?label WHERE { VALUES (?label ?s ?type) { ("newest" "2008" xsd:gYear) ("oldest" "1904-11-25" xsd:date) ("middle" "1998" xsd:gYear) }
BIND (STRDT (?s, ?type) AS ?v) } ORDER BY DESC (?v) LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed year and date DESC query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed year and date DESC row count\n";
ECHO BOTH $IF $EQU $LAST[1] "newest" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed year and date DESC value = " $LAST[1] "\n";

-- Check mixed year and date ASC using the existing datetime parser normalization.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?label WHERE { VALUES (?label ?s ?type) { ("newest" "2008" xsd:gYear) ("oldest" "1904-11-25" xsd:date) ("middle" "1998" xsd:gYear) }
BIND (STRDT (?s, ?type) AS ?v) } ORDER BY ?v LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed year and date ASC query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed year and date ASC row count\n";
ECHO BOTH $IF $EQU $LAST[1] "oldest" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed year and date ASC value = " $LAST[1] "\n";

-- Check mixed year and month DESC using the existing datetime parser normalization.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?label WHERE { VALUES (?label ?s ?type) { ("year" "2008" xsd:gYear) ("month" "2008-02" xsd:gYearMonth) }
BIND (STRDT (?s, ?type) AS ?v) } ORDER BY DESC (?v) LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed year and month DESC query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed year and month DESC row count\n";
ECHO BOTH $IF $EQU $LAST[1] "month" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed year and month DESC value = " $LAST[1] "\n";

-- Check mixed year and month ASC using the existing datetime parser normalization.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?label WHERE { VALUES (?label ?s ?type) { ("year" "2008" xsd:gYear) ("month" "2008-02" xsd:gYearMonth) }
BIND (STRDT (?s, ?type) AS ?v) } ORDER BY ?v LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed year and month ASC query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed year and month ASC row count\n";
ECHO BOTH $IF $EQU $LAST[1] "year" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed year and month ASC value = " $LAST[1] "\n";

-- Check mixed date and dateTime using the existing datetime parser normalization.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?label WHERE { VALUES (?label ?s ?type) { ("newest" "2008-01-01" xsd:date) ("oldest" "1904-11-25T00:00:00Z" xsd:dateTime) }
BIND (STRDT (?s, ?type) AS ?v) } ORDER BY DESC (?v) LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed date and dateTime query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed date and dateTime row count\n";
ECHO BOTH $IF $EQU $LAST[1] "newest" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mixed date and dateTime value = " $LAST[1] "\n";

-- Check invalid year lexical form using the existing datetime parser normalization.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?s WHERE { VALUES ?s { "T23" }
BIND (STRDT (?s, xsd:gYear) AS ?v) } ORDER BY ?v;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": invalid year lexical form query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": invalid year lexical form row count\n";
ECHO BOTH $IF $EQU $LAST[1] "T23" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": invalid year lexical form value = " $LAST[1] "\n";

-- Check invalid month lexical form using the existing datetime parser normalization.
SPARQL PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
SELECT ?s WHERE { VALUES ?s { "T23" }
BIND (STRDT (?s, xsd:gYearMonth) AS ?v) } ORDER BY ?v;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": invalid month lexical form query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": invalid month lexical form row count\n";
ECHO BOTH $IF $EQU $LAST[1] "T23" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": invalid month lexical form value = " $LAST[1] "\n";

-- Exercise the helper directly even when a single-row ORDER BY is optimized away.
SELECT CASE WHEN __tag (DB.DBA.RDF_STAR_ORDER_VALUE (
DB.DBA.RDF_STRDT_IMPL ('2008', UNAME'http://www.w3.org/2001/XMLSchema#gYear')))
= __tag of datetime THEN 1 ELSE 0 END;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": boxed gYear comparison type query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": boxed gYear comparison type row count\n";
ECHO BOTH $IF $EQU $LAST[1] "1" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": boxed gYear comparison type value = " $LAST[1] "\n";

-- Exercise the helper directly even when a single-row ORDER BY is optimized away.
SELECT CASE WHEN __tag (DB.DBA.RDF_STAR_ORDER_VALUE (
DB.DBA.RDF_STRDT_IMPL ('2008-02', UNAME'http://www.w3.org/2001/XMLSchema#gYearMonth')))
= __tag of datetime THEN 1 ELSE 0 END;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": boxed gYearMonth comparison type query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": boxed gYearMonth comparison type row count\n";
ECHO BOTH $IF $EQU $LAST[1] "1" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": boxed gYearMonth comparison type value = " $LAST[1] "\n";

-- Exercise the helper directly even when a single-row ORDER BY is optimized away.
SELECT DB.DBA.RDF_STAR_ORDER_VALUE (
DB.DBA.RDF_STRDT_IMPL ('T23', UNAME'http://www.w3.org/2001/XMLSchema#gYear'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": invalid boxed gYear fallback query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": invalid boxed gYear fallback row count\n";
ECHO BOTH $IF $EQU $LAST[1] "T23" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": invalid boxed gYear fallback value = " $LAST[1] "\n";

-- Exercise the helper directly even when a single-row ORDER BY is optimized away.
SELECT DB.DBA.RDF_STAR_ORDER_VALUE (
DB.DBA.RDF_STRDT_IMPL ('T23', UNAME'http://www.w3.org/2001/XMLSchema#gYearMonth'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": invalid boxed gYearMonth fallback query state\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": invalid boxed gYearMonth fallback row count\n";
ECHO BOTH $IF $EQU $LAST[1] "T23" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": invalid boxed gYearMonth fallback value = " $LAST[1] "\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: RDF partial date ordering tests\n";

--
--  test_fuzzy.sql
--
--  $Id$
--
--  Formal test suite for Virtuoso fuzzy string similarity search.
--
--  Covers:
--    Group A — Algorithm correctness (standalone BIFs)
--    Group B — NULL and edge-case handling
--    Group C — SQL contains() with fuzzy options
--    Group D — SPARQL bif:contains with OPTION (...)
--    Group E — Error handling
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

ECHO BOTH "STARTED: FUZZY SEARCH TEST SUITE\n";
CONNECT;

SET ARGV[0] 0;
SET ARGV[1] 0;

-- ============================================================
-- Helper procedure for numeric approximation checks
-- ============================================================
create procedure fuzzy_approx (in actual any, in expected any, in tolerance float)
{
  if (isnull (actual) or isnull (expected))
    return 0;
  if (abs (cast (actual as float) - cast (expected as float)) < tolerance)
    return 1;
  return 0;
}
;

-- ============================================================
-- Group A — Algorithm correctness (standalone BIFs)
-- ============================================================
ECHO BOTH "\n--- Group A: Algorithm correctness ---\n";

-- Levenshtein distance
SELECT levenshtein ('kitten', 'sitting');
ECHO BOTH $IF $EQU $LAST[1] "3"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": A1 levenshtein('kitten','sitting') = " $LAST[1] " (expected 3)\n";

SELECT levenshtein ('', 'abc');
ECHO BOTH $IF $EQU $LAST[1] "3"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": A2 levenshtein('','abc') = " $LAST[1] " (expected 3)\n";

SELECT levenshtein ('abc', 'abc');
ECHO BOTH $IF $EQU $LAST[1] "0"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": A3 levenshtein('abc','abc') = " $LAST[1] " (expected 0)\n";

-- Levenshtein similarity
SELECT levenshtein_similarity ('kitten', 'sitting');
ECHO BOTH $IF $EQU $LAST[1] "0.5714285714285714"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": A4 levenshtein_similarity('kitten','sitting') = " $LAST[1] "\n";

SELECT levenshtein_similarity ('abc', 'abc');
ECHO BOTH $IF $EQU $LAST[1] "1"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": A5 levenshtein_similarity('abc','abc') = " $LAST[1] " (expected 1)\n";

-- Jaro-Winkler similarity
SELECT jaro_winkler ('MARTHA', 'MARHTA');
ECHO BOTH $IF $EQU $LAST[1] "0.9611111111111111"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": A6 jaro_winkler('MARTHA','MARHTA') = " $LAST[1] "\n";

SELECT jaro_winkler ('DWAYNE', 'DUANE');
ECHO BOTH $IF $EQU $LAST[1] "0.8400000000000001"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": A7 jaro_winkler('DWAYNE','DUANE') = " $LAST[1] "\n";

SELECT jaro_winkler ('abc', 'abc');
ECHO BOTH $IF $EQU $LAST[1] "1"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": A8 jaro_winkler('abc','abc') = " $LAST[1] " (expected 1)\n";

SELECT jaro_winkler ('', '');
ECHO BOTH $IF $EQU $LAST[1] "1"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": A9 jaro_winkler('','') = " $LAST[1] " (expected 1)\n";

-- jaro_winkler_similarity alias
SELECT jaro_winkler_similarity ('MARTHA', 'MARHTA');
ECHO BOTH $IF $EQU $LAST[1] "0.9611111111111111"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": A10 jaro_winkler_similarity('MARTHA','MARHTA') = " $LAST[1] " (alias)\n";

-- N-gram cosine
SELECT ngram_cosine ('johnson', 'jonsson');
ECHO BOTH $IF $EQU $LAST[1] "0.7826237921249264"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": A11 ngram_cosine('johnson','jonsson') = " $LAST[1] "\n";

SELECT ngram_cosine ('abc', 'abc');
ECHO BOTH $IF $EQU $LAST[1] "1"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": A12 ngram_cosine('abc','abc') = " $LAST[1] " (expected 1)\n";

SELECT ngram_cosine ('abc', 'xyz');
ECHO BOTH $IF $EQU $LAST[1] "0"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": A13 ngram_cosine('abc','xyz') = " $LAST[1] " (expected 0)\n";

-- N-gram cosine with explicit n
SELECT ngram_cosine_n ('johnson', 'jonsson', 3);
ECHO BOTH $IF $EQU $LAST[1] "0.4285714285714285"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": A14 ngram_cosine_n('johnson','jonsson',3) = " $LAST[1] "\n";

SELECT ngram_cosine_n ('abc', 'abc', 1);
ECHO BOTH $IF $EQU $LAST[1] "0.9999999999999999"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": A15 ngram_cosine_n('abc','abc',1) = " $LAST[1] " (unigram, ~1.0)\n";

-- ============================================================
-- Group B — NULL and edge-case handling
-- ============================================================
ECHO BOTH "\n--- Group B: NULL and edge-case handling ---\n";

SELECT levenshtein (NULL, 'abc');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B1 levenshtein(NULL,'abc') = " $LAST[1] " (expected NULL) STATE=" $STATE "\n";

SELECT levenshtein ('abc', NULL);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B2 levenshtein('abc',NULL) = " $LAST[1] " (expected NULL) STATE=" $STATE "\n";

SELECT jaro_winkler (NULL, NULL);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B3 jaro_winkler(NULL,NULL) = " $LAST[1] " (expected NULL) STATE=" $STATE "\n";

SELECT ngram_cosine (NULL, 'abc');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B4 ngram_cosine(NULL,'abc') = " $LAST[1] " (expected NULL) STATE=" $STATE "\n";

-- n=0 defaults to bigram (n=2)
SELECT ngram_cosine_n ('abc', 'abc', 0);
ECHO BOTH $IF $EQU $LAST[1] "1"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B5 ngram_cosine_n('abc','abc',0) = " $LAST[1] " (n=0 defaults to bigram, expected 1)\n";

-- n=8 clamped to max (7)
SELECT ngram_cosine_n ('abc', 'abc', 8);
ECHO BOTH $IF $EQU $LAST[1] "1"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B6 ngram_cosine_n('abc','abc',8) = " $LAST[1] " (n=8 clamped, expected 1)\n";

-- Non-string argument should error
SELECT levenshtein (123, 'abc');
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B7 levenshtein(123,'abc') errors STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- ============================================================
-- Group C — SQL contains() with fuzzy options
-- ============================================================
ECHO BOTH "\n--- Group C: SQL contains() with fuzzy ---\n";

-- Setup
whenever sqlstate '*' goto c0_ok;
drop table fuzzy_test;
c0_ok:
whenever sqlstate '*' default;
ECHO BOTH "PASSED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C0 dropped old fuzzy_test (if existed)\n";

create table fuzzy_test (id integer not null primary key, name varchar);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C1 created fuzzy_test\n";

create text index on fuzzy_test (name);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C2 created text index on fuzzy_test\n";

insert into fuzzy_test (id, name) values (1, 'Johnson');
insert into fuzzy_test (id, name) values (2, 'Jonsson');
insert into fuzzy_test (id, name) values (3, 'Janson');
insert into fuzzy_test (id, name) values (4, 'Johansson');
insert into fuzzy_test (id, name) values (5, 'Smith');
insert into fuzzy_test (id, name) values (6, 'Smythe');
vt_batch_update ('DB.DBA.FUZZY_TEST', 'ON', 0);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C3 inserted 6 rows and updated text index\n";

-- Standard contains (regression)
SELECT id, name FROM fuzzy_test WHERE contains (name, 'Johnson');
ECHO BOTH $IF $EQU $ROWCNT 1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C4 standard contains('Johnson') = " $ROWCNT " rows (expected 1)\n";

-- Jaro-Winkler fuzzy
SELECT id, name FROM fuzzy_test WHERE contains (name, 'Johnson', 'fuzzy', 'jaro_winkler', 'fuzzy_threshold', 0.6);
ECHO BOTH $IF $EQU $ROWCNT 3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C5 fuzzy jaro_winkler threshold=0.6 = " $ROWCNT " rows (expected 3)\n";

-- Levenshtein fuzzy
SELECT id, name FROM fuzzy_test WHERE contains (name, 'Johnson', 'fuzzy', 'levenshtein', 'fuzzy_threshold', 0.5);
ECHO BOTH $IF $EQU $ROWCNT 3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C6 fuzzy levenshtein threshold=0.5 = " $ROWCNT " rows (expected 3)\n";

-- N-gram cosine with explicit n
SELECT id, name FROM fuzzy_test WHERE contains (name, 'Johnson', 'fuzzy', 'ngram_cosine', 'fuzzy_threshold', 0.5, 'fuzzy_n', 2);
ECHO BOTH $IF $EQU $ROWCNT 3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C7 fuzzy ngram_cosine n=2 threshold=0.5 = " $ROWCNT " rows (expected 3)\n";

-- N-gram cosine default n
SELECT id, name FROM fuzzy_test WHERE contains (name, 'Johnson', 'fuzzy', 'ngram_cosine', 'fuzzy_threshold', 0.5);
ECHO BOTH $IF $EQU $ROWCNT 3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C8 fuzzy ngram_cosine default n threshold=0.5 = " $ROWCNT " rows (expected 3)\n";

-- With SCORE — exact match should rank highest (3 rows)
SELECT SCORE, id, name FROM fuzzy_test WHERE contains (name, 'Johnson', 'fuzzy', 'jaro_winkler', 'fuzzy_threshold', 0.6) ORDER BY SCORE DESC;
ECHO BOTH $IF $EQU $ROWCNT 3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C9 fuzzy with SCORE = " $ROWCNT " rows (expected 3)\n";

-- Top result (LIMIT 1) should be the exact match "Johnson"
SELECT top 1 SCORE, id, name FROM fuzzy_test WHERE contains (name, 'Johnson', 'fuzzy', 'jaro_winkler', 'fuzzy_threshold', 0.6) ORDER BY SCORE DESC;
ECHO BOTH $IF $EQU $LAST[3] "Johnson"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": C10 top result is '" $LAST[3] "' (expected Johnson, highest score)\n";

-- ============================================================
-- Group D — SPARQL bif:contains with OPTION (...)
-- ============================================================
ECHO BOTH "\n--- Group D: SPARQL bif:contains with OPTION ---\n";

-- Setup RDF data with text index
SPARQL CLEAR GRAPH <http://example.com/>;
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D0 cleared graph\n";

DB.DBA.RDF_OBJ_FT_RULE_ADD (null, null, 'all text');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D1 added FT rule\n";

DB.DBA.TTLP ('
<http://example.com/p1> <http://example.com/name> "Johnson" .
<http://example.com/p2> <http://example.com/name> "Jonsson" .
<http://example.com/p3> <http://example.com/name> "Janson" .
<http://example.com/p4> <http://example.com/name> "Johansson" .
<http://example.com/p5> <http://example.com/name> "Smith" .
<http://example.com/p6> <http://example.com/name> "Smythe" .
', '', 'http://example.com/', 0);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D2 loaded TTL data\n";

DB.DBA.vt_batch_update ('DB.DBA.RDF_OBJ', 'OFF', 1);
DB.DBA.vt_batch_update ('DB.DBA.RDF_OBJ', 'ON', 1);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D3 flushed VT index\n";

-- Standard bif:contains (regression)
SPARQL SELECT ?s ?name WHERE { ?s <http://example.com/name> ?name . ?name bif:contains "'Johnson'" . };
ECHO BOTH $IF $EQU $ROWCNT 1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D4 standard bif:contains('Johnson') = " $ROWCNT " rows (expected 1)\n";

-- FUZZY with Jaro-Winkler
SPARQL SELECT ?s ?name WHERE { ?s <http://example.com/name> ?name . ?name bif:contains "'Johnson'" OPTION (FUZZY 'jaro_winkler', FUZZY_THRESHOLD 0.6) . };
ECHO BOTH $IF $EQU $ROWCNT 3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D5 SPARQL fuzzy jaro_winkler threshold=0.6 = " $ROWCNT " rows (expected 3)\n";

-- FUZZY with SCORE (3 rows)
SPARQL SELECT ?s ?name ?sc WHERE { ?s <http://example.com/name> ?name . ?name bif:contains "'Johnson'" OPTION (SCORE ?sc, FUZZY 'jaro_winkler', FUZZY_THRESHOLD 0.6) . } ORDER BY DESC(?sc);
ECHO BOTH $IF $EQU $ROWCNT 3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D6 SPARQL fuzzy with SCORE = " $ROWCNT " rows (expected 3)\n";

-- Top SPARQL result (LIMIT 1) should be the exact match "Johnson"
SPARQL SELECT ?s ?name ?sc WHERE { ?s <http://example.com/name> ?name . ?name bif:contains "'Johnson'" OPTION (SCORE ?sc, FUZZY 'jaro_winkler', FUZZY_THRESHOLD 0.6) . } ORDER BY DESC(?sc) LIMIT 1;
ECHO BOTH $IF $EQU $LAST[2] "Johnson"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D7 top SPARQL result is '" $LAST[2] "' (expected Johnson)\n";

-- FUZZY with ngram_cosine and FUZZY_N
SPARQL SELECT ?s ?name WHERE { ?s <http://example.com/name> ?name . ?name bif:contains "'Johnson'" OPTION (FUZZY 'ngram_cosine', FUZZY_THRESHOLD 0.5, FUZZY_N 2) . };
ECHO BOTH $IF $EQU $ROWCNT 3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D8 SPARQL fuzzy ngram_cosine n=2 = " $ROWCNT " rows (expected 3)\n";

-- FUZZY with levenshtein
SPARQL SELECT ?s ?name WHERE { ?s <http://example.com/name> ?name . ?name bif:contains "'Johnson'" OPTION (FUZZY 'levenshtein', FUZZY_THRESHOLD 0.5) . };
ECHO BOTH $IF $EQU $ROWCNT 3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D9 SPARQL fuzzy levenshtein = " $ROWCNT " rows (expected 3)\n";

-- Lowercase keywords (case-insensitivity)
SPARQL SELECT ?s ?name WHERE { ?s <http://example.com/name> ?name . ?name bif:contains "'Johnson'" OPTION (fuzzy 'jaro_winkler', fuzzy_threshold 0.6) . };
ECHO BOTH $IF $EQU $ROWCNT 3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D10 SPARQL lowercase fuzzy keywords = " $ROWCNT " rows (expected 3)\n";

-- Mixed case keywords
SPARQL SELECT ?s ?name WHERE { ?s <http://example.com/name> ?name . ?name bif:contains "'Johnson'" OPTION (Fuzzy 'jaro_winkler', Fuzzy_Threshold 0.6) . };
ECHO BOTH $IF $EQU $ROWCNT 3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D11 SPARQL mixed-case fuzzy keywords = " $ROWCNT " rows (expected 3)\n";

-- Standalone BIFs in SPARQL
SPARQL SELECT (bif:jaro_winkler ("MARTHA", "MARHTA") AS ?sim) WHERE { } LIMIT 1;
ECHO BOTH $IF $EQU $LAST[1] "0.9611111111111111"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D12 SPARQL bif:jaro_winkler('MARTHA','MARHTA') = " $LAST[1] "\n";

SPARQL SELECT (bif:levenshtein ("kitten", "sitting") AS ?dist) WHERE { } LIMIT 1;
ECHO BOTH $IF $EQU $LAST[1] "3"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D13 SPARQL bif:levenshtein('kitten','sitting') = " $LAST[1] " (expected 3)\n";

SPARQL SELECT (bif:ngram_cosine ("johnson", "jonsson") AS ?sim) WHERE { } LIMIT 1;
ECHO BOTH $IF $EQU $LAST[1] "0.7826237921249264"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D14 SPARQL bif:ngram_cosine('johnson','jonsson') = " $LAST[1] "\n";

-- ============================================================
-- Group E — Error handling
-- ============================================================
ECHO BOTH "\n--- Group E: Error handling ---\n";

-- Invalid algorithm name in SQL
SELECT id, name FROM fuzzy_test WHERE contains (name, 'Johnson', 'fuzzy', 'invalid_algo');
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": E1 SQL invalid algo name errors STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Invalid algorithm name in SPARQL
SPARQL SELECT ?s ?name WHERE { ?s <http://example.com/name> ?name . ?name bif:contains "'Johnson'" OPTION (FUZZY 'invalid_algo') . };
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": E2 SPARQL invalid algo name errors STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- ============================================================
-- Cleanup
-- ============================================================
drop table fuzzy_test;
SPARQL CLEAR GRAPH <http://example.com/>;
DB.DBA.RDF_OBJ_FT_RULE_DEL (null, null, 'all text');
DB.DBA.vt_batch_update ('DB.DBA.RDF_OBJ', 'OFF', 1);
DB.DBA.vt_batch_update ('DB.DBA.RDF_OBJ', 'ON', 1);

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: FUZZY SEARCH TEST SUITE\n";

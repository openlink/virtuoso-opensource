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

-- Optional mode returns normalized similarity while preserving the two-argument distance form.
SELECT levenshtein ('kitten', 'sitting', 'similarity');
ECHO BOTH $IF $EQU $LAST[1] "0.5714285714285714"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": A3a levenshtein('kitten','sitting','similarity') = " $LAST[1] "\n";

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
<http://example.com/p7> <http://example.com/name> "Fuzzy Wuzziee" .
<http://example.com/p8> <http://example.com/name> "Fuzzy Wuzzy" .
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

-- Integer FUZZY_THRESHOLD must be handled as a numeric value, not a double pointer.
SPARQL SELECT ?s ?name ?sc WHERE { ?s <http://example.com/name> ?name . ?name bif:contains '"Fuzzy Wuzziee"' OPTION (SCORE ?sc, FUZZY 'jaro_winkler', FUZZY_THRESHOLD 1) . };
ECHO BOTH $IF $EQU $ROWCNT 1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D8 integer fuzzy threshold with phrase and SCORE = " $ROWCNT " rows (expected 1)\n";

-- FUZZY with ngram_cosine and FUZZY_N
SPARQL SELECT ?s ?name WHERE { ?s <http://example.com/name> ?name . ?name bif:contains "'Johnson'" OPTION (FUZZY 'ngram_cosine', FUZZY_THRESHOLD 0.5, FUZZY_N 2) . };
ECHO BOTH $IF $EQU $ROWCNT 3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D9 SPARQL fuzzy ngram_cosine n=2 = " $ROWCNT " rows (expected 3)\n";

-- FUZZY with levenshtein
SPARQL SELECT ?s ?name WHERE { ?s <http://example.com/name> ?name . ?name bif:contains "'Johnson'" OPTION (FUZZY 'levenshtein', FUZZY_THRESHOLD 0.5) . };
ECHO BOTH $IF $EQU $ROWCNT 3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D10 SPARQL fuzzy levenshtein = " $ROWCNT " rows (expected 3)\n";

-- Lowercase keywords (case-insensitivity)
SPARQL SELECT ?s ?name WHERE { ?s <http://example.com/name> ?name . ?name bif:contains "'Johnson'" OPTION (fuzzy 'jaro_winkler', fuzzy_threshold 0.6) . };
ECHO BOTH $IF $EQU $ROWCNT 3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D11 SPARQL lowercase fuzzy keywords = " $ROWCNT " rows (expected 3)\n";

-- Mixed case keywords
SPARQL SELECT ?s ?name WHERE { ?s <http://example.com/name> ?name . ?name bif:contains "'Johnson'" OPTION (Fuzzy 'jaro_winkler', Fuzzy_Threshold 0.6) . };
ECHO BOTH $IF $EQU $ROWCNT 3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D12 SPARQL mixed-case fuzzy keywords = " $ROWCNT " rows (expected 3)\n";

-- Standalone BIFs in SPARQL
SPARQL SELECT (bif:jaro_winkler ("MARTHA", "MARHTA") AS ?sim) WHERE { } LIMIT 1;
ECHO BOTH $IF $EQU $LAST[1] "0.9611111111111111"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D13 SPARQL bif:jaro_winkler('MARTHA','MARHTA') = " $LAST[1] "\n";

SPARQL SELECT (bif:levenshtein ("kitten", "sitting") AS ?dist) WHERE { } LIMIT 1;
ECHO BOTH $IF $EQU $LAST[1] "3"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D14 SPARQL bif:levenshtein('kitten','sitting') = " $LAST[1] " (expected 3)\n";

SPARQL SELECT (bif:ngram_cosine ("johnson", "jonsson") AS ?sim) WHERE { } LIMIT 1;
ECHO BOTH $IF $EQU $LAST[1] "0.7826237921249264"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D15 SPARQL bif:ngram_cosine('johnson','jonsson') = " $LAST[1] "\n";

-- SIMILARITY must be populated without requiring SCORE.
SPARQL SELECT ?s ?name ?sim WHERE { ?s <http://example.com/name> ?name . FILTER (?s = <http://example.com/p8>) . ?name bif:contains "'Fuzzle'" OPTION (SIMILARITY ?sim, FUZZY 'jaro_winkler', FUZZY_THRESHOLD 0.6) . };
ECHO BOTH $IF $GT $LAST[3] 0.6  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D16 SPARQL SIMILARITY without SCORE = " $LAST[3] " (expected > 0.6)\n";

-- Quoted fuzzy phrases use a word chain and must propagate child similarity.
SPARQL SELECT ?s ?name ?sim WHERE { ?s <http://example.com/name> ?name . FILTER (?s = <http://example.com/p8>) . ?name bif:contains '"Fuzzy Wuzzy"' OPTION (SIMILARITY ?sim, FUZZY 'jaro_winkler', FUZZY_THRESHOLD 0.6) . };
ECHO BOTH $IF $GT $LAST[3] 0.99  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": D17 SPARQL quoted-phrase SIMILARITY without SCORE = " $LAST[3] " (expected 1)\n";

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
-- Group F — Unicode / code-point-aware algorithms (P1-1)
-- ============================================================
ECHO BOTH "\n--- Group F: Unicode code-point-aware algorithms ---\n";

-- CJK: 1 character different out of 3
SELECT levenshtein ('日本語', '日本国');
ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F1 levenshtein('日本語','日本国') = " $LAST[1] " (expected 1)\n";

SELECT levenshtein_similarity ('日本語', '日本国');
ECHO BOTH $IF $GT $LAST[1] 0.6  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F2 levenshtein_similarity('日本語','日本国') = " $LAST[1] " (expected ~0.667)\n";

SELECT jaro_winkler ('日本語', '日本国');
ECHO BOTH $IF $GT $LAST[1] 0.7  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F3 jaro_winkler('日本語','日本国') = " $LAST[1] " (expected ~0.833)\n";

-- Emoji: 1 character different out of 2
SELECT levenshtein ('😀😁', '😀😂');
ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F4 levenshtein('😀😁','😀😂') = " $LAST[1] " (expected 1)\n";

-- Mixed ASCII + CJK
SELECT levenshtein ('abc日本語', 'abc日本国');
ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F5 levenshtein('abc日本語','abc日本国') = " $LAST[1] " (expected 1)\n";

-- N-gram cosine on CJK (shared bigram: 日本)
SELECT ngram_cosine ('日本語', '日本国');
ECHO BOTH $IF $GT $LAST[1] 0.3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F6 ngram_cosine('日本語','日本国') = " $LAST[1] " (expected ~0.5)\n";

-- N-gram cosine on CJK with unigrams (shared: 日, 本)
SELECT ngram_cosine_n ('日本語', '日本国', 1);
ECHO BOTH $IF $GT $LAST[1] 0.5  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F7 ngram_cosine_n('日本語','日本国',1) = " $LAST[1] " (expected ~0.667)\n";

-- Pure ASCII regression (must not change)
SELECT levenshtein ('kitten', 'sitting');
ECHO BOTH $IF $EQU $LAST[1] 3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F8 levenshtein('kitten','sitting') = " $LAST[1] " (expected 3, ASCII regression)\n";

SELECT jaro_winkler ('MARTHA', 'MARHTA');
ECHO BOTH $IF $GT $LAST[1] 0.95  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": F9 jaro_winkler('MARTHA','MARHTA') = " $LAST[1] " (expected ~0.961, ASCII regression)\n";

-- ============================================================
-- Group G — Score fusion tie discrimination (P1-3)
-- ============================================================
ECHO BOTH "\n--- Group G: Score fusion tie discrimination ---\n";

CREATE TABLE fuzzy_score_test (id INTEGER NOT NULL PRIMARY KEY, name VARCHAR);
CREATE TEXT INDEX ON fuzzy_score_test (name);
INSERT INTO fuzzy_score_test (id, name) VALUES (1, 'Johnson');
INSERT INTO fuzzy_score_test (id, name) VALUES (2, 'Jonson');
INSERT INTO fuzzy_score_test (id, name) VALUES (3, 'Jonsen');
INSERT INTO fuzzy_score_test (id, name) VALUES (4, 'Jhnson');
INSERT INTO fuzzy_score_test (id, name) VALUES (5, 'Johansson');
INSERT INTO fuzzy_score_test (id, name) VALUES (6, 'Johnsen');
DB.DBA.vt_batch_update ('DB.DBA.fuzzy_score_test', 'ON', 1);

-- Each row should have a distinct score (no unnecessary ties).
-- Some words may have identical similarity values, so we check for
-- at least 4 distinct scores (the old multiplicative fusion with
-- integer truncation would produce fewer).
SELECT COUNT (DISTINCT SCORE) FROM fuzzy_score_test WHERE contains (name, 'Johnson', 'fuzzy', 'jaro_winkler', 'fuzzy_threshold', 0.5);
ECHO BOTH $IF $GE $LAST[1] 4  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": G1 distinct scores for 6 rows = " $LAST[1] " (expected >=4, no unnecessary ties)\n";

-- Exact match should rank highest
SELECT TOP 1 SCORE, name FROM fuzzy_score_test WHERE contains (name, 'Johnson', 'fuzzy', 'jaro_winkler', 'fuzzy_threshold', 0.5) ORDER BY SCORE DESC;
ECHO BOTH $IF $EQU $LAST[2] "Johnson"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": G2 top result by score is '" $LAST[2] "' (expected Johnson)\n";

DROP TABLE fuzzy_score_test;

-- ============================================================
-- Group H — Configurable prefix length (P1-4)
-- ============================================================
ECHO BOTH "\n--- Group H: Configurable prefix length ---\n";

-- Note: "Janson" (id=3) starts with "Ja", not "Jo".
-- With prefix=2 (default), the scan range is "Jo..." so Janson is NOT scanned.
-- With prefix=1, the scan range is "J..." so Janson IS scanned and may match.

-- Default prefix (2) — scans "Jo*" range, finds Johnson, Jonsson, Johansson
SELECT COUNT (*) FROM fuzzy_test WHERE contains (name, 'Johnson', 'fuzzy', 'jaro_winkler', 'fuzzy_threshold', 0.5);
ECHO BOTH $IF $EQU $LAST[1] 3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": H1 default prefix=2 finds " $LAST[1] " rows (expected 3)\n";

-- Prefix 1 — scans "J*" range, also finds Janson
SELECT COUNT (*) FROM fuzzy_test WHERE contains (name, 'Johnson', 'fuzzy', 'jaro_winkler', 'fuzzy_threshold', 0.5, 'fuzzy_prefix', 1);
ECHO BOTH $IF $EQU $LAST[1] 4  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": H2 prefix=1 finds " $LAST[1] " rows (expected 4, includes Janson)\n";

-- Prefix 3 — scans "Joh*" range, only Johnson and Johansson
SELECT COUNT (*) FROM fuzzy_test WHERE contains (name, 'Johnson', 'fuzzy', 'jaro_winkler', 'fuzzy_threshold', 0.5, 'fuzzy_prefix', 3);
ECHO BOTH $IF $EQU $LAST[1] 2  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": H3 prefix=3 finds " $LAST[1] " rows (expected 2)\n";

-- SPARQL with FUZZY_PREFIX
SPARQL SELECT ?s ?name WHERE { ?s <http://example.com/name> ?name . ?name bif:contains "'Johnson'" OPTION (FUZZY 'jaro_winkler', FUZZY_THRESHOLD 0.5, FUZZY_PREFIX 1) . };
ECHO BOTH $IF $NEQ $ROWCNT 0  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": H4 SPARQL FUZZY_PREFIX 1 = " $ROWCNT " rows (expected >0)\n";

-- ============================================================
-- Group I — SPARQL algorithm validation (P1-5)
-- ============================================================
ECHO BOTH "\n--- Group I: SPARQL algorithm validation ---\n";

-- SPARQL: invalid algorithm (should error with valid names listed)
SPARQL SELECT ?s ?name WHERE { ?s <http://example.com/name> ?name . ?name bif:contains "'Johnson'" OPTION (FUZZY 'bad_algo') . };
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": I1 SPARQL invalid algo errors STATE=" $STATE "\n";

-- SPARQL: non-literal algorithm (variable) — should error
SPARQL SELECT ?s ?name WHERE { ?s <http://example.com/name> ?name . ?name bif:contains "'Johnson'" OPTION (FUZZY ?algo) . };
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": I2 SPARQL non-literal algo errors STATE=" $STATE "\n";

-- ============================================================
-- Group J — Interaction with existing contains() features (P1-2)
-- ============================================================
ECHO BOTH "\n--- Group J: Interaction with contains() features ---\n";

-- J1: Fuzzy + SCORE (regression — already tested, verify ordering)
SELECT SCORE, id, name FROM fuzzy_test WHERE contains (name, 'Johnson', 'fuzzy', 'jaro_winkler', 'fuzzy_threshold', 0.6) ORDER BY SCORE DESC;
ECHO BOTH $IF $EQU $ROWCNT 3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": J1 fuzzy + SCORE = " $ROWCNT " rows (expected 3)\n";

-- J2: Fuzzy + SCORE_LIMIT
SELECT id, name FROM fuzzy_test WHERE contains (name, 'Johnson', 'fuzzy', 'jaro_winkler', 'fuzzy_threshold', 0.6, 'score_limit', 1);
ECHO BOTH $IF $NEQ $ROWCNT 0  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": J2 fuzzy + SCORE_LIMIT = " $ROWCNT " rows (expected >0)\n";

-- J3: Fuzzy + DESCENDING (flag, no value)
SELECT id, name FROM fuzzy_test WHERE contains (name, 'Johnson', 'fuzzy', 'jaro_winkler', 'fuzzy_threshold', 0.6, 'descending');
ECHO BOTH $IF $EQU $ROWCNT 3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": J3 fuzzy + DESCENDING = " $ROWCNT " rows (expected 3)\n";

-- J4: Fuzzy + START_ID / END_ID
SELECT id, name FROM fuzzy_test WHERE contains (name, 'Johnson', 'fuzzy', 'jaro_winkler', 'fuzzy_threshold', 0.5, 'start_id', 2, 'end_id', 5);
ECHO BOTH $IF $NEQ $ROWCNT 0  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": J4 fuzzy + START_ID/END_ID = " $ROWCNT " rows (expected >0)\n";

-- J5: Fuzzy + encoding prefix (SPARQL path)
SELECT id, name FROM fuzzy_test WHERE contains (name, '[__enc "UTF-8"] Johnson', 'fuzzy', 'jaro_winkler', 'fuzzy_threshold', 0.6);
ECHO BOTH $IF $EQU $ROWCNT 3  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": J5 fuzzy + encoding prefix = " $ROWCNT " rows (expected 3)\n";

-- J6: Fuzzy + boolean AND — both words treated as fuzzy
SELECT id, name FROM fuzzy_test WHERE contains (name, 'Johnson AND Smith', 'fuzzy', 'jaro_winkler', 'fuzzy_threshold', 0.5);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": J6 fuzzy + boolean AND STATE=" $STATE " rows=" $ROWCNT "\n";

-- J7: Fuzzy + boolean OR — both words treated as fuzzy
SELECT id, name FROM fuzzy_test WHERE contains (name, 'Johnson OR Smith', 'fuzzy', 'jaro_winkler', 'fuzzy_threshold', 0.5);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": J7 fuzzy + boolean OR STATE=" $STATE " rows=" $ROWCNT "\n";

-- ============================================================
-- Cleanup
-- ============================================================
drop table fuzzy_test;
SPARQL CLEAR GRAPH <http://example.com/>;
DB.DBA.RDF_OBJ_FT_RULE_DEL (null, null, 'all text');
DB.DBA.vt_batch_update ('DB.DBA.RDF_OBJ', 'OFF', 1);
DB.DBA.vt_batch_update ('DB.DBA.RDF_OBJ', 'ON', 1);

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: FUZZY SEARCH TEST SUITE\n";

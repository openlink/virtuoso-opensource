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
--
--  openGQL: GQL for Virtuoso - Observability (P2-7) tests
--
--  Tests for the GQL stats/logging/timing/explain module.
--  Run via isql: isql <port> dba dba < test_gql_stats.sql
--

ECHO BOTH "STARTED: GQL observability tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

-- ============================================================
-- Helper: get a named counter value from GQL_STATS()
-- ============================================================
create procedure DB.DBA.GQL_TEST_STATS_GET (in counter_name varchar)
{
  declare stats any;
  declare i integer;
  stats := DB.DBA.GQL_STATS ();
  for (i := 0; i < length (stats); i := i + 1)
    {
      if (stats[i][0] = counter_name)
        return stats[i][1];
    }
  return -1;
}
;

-- ============================================================
-- Helper: get total_time for a named counter
-- ============================================================
create procedure DB.DBA.GQL_TEST_STATS_GET_TOTAL (in counter_name varchar)
{
  declare stats any;
  declare i integer;
  stats := DB.DBA.GQL_STATS ();
  for (i := 0; i < length (stats); i := i + 1)
    {
      if (stats[i][0] = counter_name)
        return stats[i][2];
    }
  return -1;
}
;

-- ============================================================
-- ST1: GQL_STATS() returns a non-empty result set after RESET
-- ============================================================
SELECT DB.DBA.GQL_STATS_RESET ();
SELECT case when length (DB.DBA.GQL_STATS ()) > 0 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST1 GQL_STATS() returns non-empty result\n";

-- ============================================================
-- ST2: GQL_STATS_RESET() zeros all counters
-- ============================================================
SELECT DB.DBA.GQL_STATS_RESET ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST2 GQL_STATS_RESET() returns 1\n";

-- ============================================================
-- ST3: With stats off, counters do not increment
-- ============================================================
SELECT DB.DBA.GQL_TEST_STATS_GET ('requests_total');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST3 requests_total=0 before any queries (stats off)\n";

-- Run a few queries with stats off — should not increment
SELECT DB.DBA.GQL_TO_SPARQL ('MATCH (n) RETURN n');
SELECT DB.DBA.GQL_TO_SPARQL ('MATCH (n:Person) RETURN n');

SELECT DB.DBA.GQL_TEST_STATS_GET ('requests_total');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST3a requests_total=0 after queries (stats off)\n";

-- ============================================================
-- ST4: Enable stats, run queries, verify counters increment
-- ============================================================
DB.DBA.GQL_STATS_SET_FLAG ('__opengql_stats_enabled', 'on');

SELECT DB.DBA.GQL_STATS_RESET ();

-- Run 3 successful translation-only queries
SELECT DB.DBA.GQL_TO_SPARQL ('MATCH (n) RETURN n');
SELECT DB.DBA.GQL_TO_SPARQL ('MATCH (n:Person) RETURN n');
SELECT DB.DBA.GQL_TO_SPARQL ('MATCH (a)-[:KNOWS]->(b) RETURN a, b');

SELECT DB.DBA.GQL_TEST_STATS_GET ('requests_total');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST4 requests_total=3 after 3 queries (stats on)\n";

SELECT DB.DBA.GQL_TEST_STATS_GET ('requests_ok');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST4a requests_ok=3\n";

-- ============================================================
-- ST5: Error queries increment error counters
-- ============================================================
SELECT DB.DBA.GQL_TEST_STATS_GET ('requests_error');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST5 requests_error=0 before error query\n";

-- Run a query that will error (undefined variable in scope)
create procedure DB.DBA.GQL_TEST_RUN_ERROR (in q varchar)
{
  declare exit handler for sqlstate '*' { return __SQL_STATE; };
  DB.DBA.GQL_TO_SPARQL (q);
  return '00000';
}
;

SELECT DB.DBA.GQL_TEST_RUN_ERROR ('MATCH (n) RETURN nonexistent_var');
SELECT DB.DBA.GQL_TEST_STATS_GET ('requests_error');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST5a requests_error=1 after error query\n";

SELECT DB.DBA.GQL_TEST_STATS_GET ('requests_total');
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST5b requests_total=4 (3 ok + 1 error)\n";

-- ============================================================
-- ST6: Timing counters are recorded
-- ============================================================
SELECT DB.DBA.GQL_TEST_STATS_GET ('time_translate_count');
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST6 time_translate_count > 0\n";

SELECT DB.DBA.GQL_TEST_STATS_GET_TOTAL ('time_translate_total');
ECHO BOTH $IF $GTE $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST6a time_translate_total >= 0\n";

-- ============================================================
-- ST7: Disable stats, verify counters stop incrementing
-- ============================================================
DB.DBA.GQL_STATS_SET_FLAG ('__opengql_stats_enabled', 'off');

SELECT DB.DBA.GQL_TEST_STATS_GET ('requests_total');
declare _before_total integer;
_before_total := DB.DBA.GQL_TEST_STATS_GET ('requests_total');

SELECT DB.DBA.GQL_TO_SPARQL ('MATCH (n) RETURN n');

SELECT DB.DBA.GQL_TEST_STATS_GET ('requests_total');
ECHO BOTH $IF $EQU $LAST[1] $_before_total "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST7 requests_total unchanged after stats disabled\n";

-- ============================================================
-- ST8: GQL_EXPLAIN returns translated SPARQL + plan
-- ============================================================
SELECT case when length (DB.DBA.GQL_EXPLAIN ('MATCH (n) RETURN n')) >= 2 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST8 GQL_EXPLAIN returns vector with >= 2 elements\n";

-- Check that the first element is the SPARQL text (contains SELECT)
SELECT case when strstr (DB.DBA.GQL_EXPLAIN ('MATCH (n) RETURN n')[0], 'SELECT') is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST8a GQL_EXPLAIN[0] contains SELECT\n";

-- ============================================================
-- ST9: GQL_EXPLAIN for DML query returns INSERT SPARQL + explain
-- ============================================================
SELECT case when strstr (DB.DBA.GQL_EXPLAIN ('INSERT (:Test { name: ''x'' })')[0], 'INSERT') is not null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST9 GQL_EXPLAIN DML returns INSERT SPARQL\n";

-- ============================================================
-- ST10: GQL_STATS_SET_FLAG works and returns void
-- ============================================================
DB.DBA.GQL_STATS_SET_FLAG ('__opengql_stats_enabled', 'on');
SELECT DB.DBA.GQL_STATS_ENABLED ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST10 GQL_STATS_ENABLED returns 1 after set on\n";

DB.DBA.GQL_STATS_SET_FLAG ('__opengql_stats_enabled', 'off');
SELECT DB.DBA.GQL_STATS_ENABLED ();
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST10a GQL_STATS_ENABLED returns 0 after set off\n";

-- ============================================================
-- ST11: Error classification works for different error families
-- ============================================================
-- Parse error (GQ0xx)
SELECT DB.DBA.GQL_STATS_CLASSIFY_ERROR ('GQ003');
ECHO BOTH $IF $EQU $LAST[1] 'errors_parse' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST11 GQ003 classified as errors_parse\n";

-- Scope error (G3xxx)
SELECT DB.DBA.GQL_STATS_CLASSIFY_ERROR ('G3001');
ECHO BOTH $IF $EQU $LAST[1] 'errors_scope' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST11a G3001 classified as errors_scope\n";

-- DML error (G4xxx)
SELECT DB.DBA.GQL_STATS_CLASSIFY_ERROR ('G4001');
ECHO BOTH $IF $EQU $LAST[1] 'errors_dml' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST11b G4001 classified as errors_dml\n";

-- Other error
SELECT DB.DBA.GQL_STATS_CLASSIFY_ERROR ('42000');
ECHO BOTH $IF $EQU $LAST[1] 'errors_exec' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ST11c 42000 classified as errors_exec\n";

-- ============================================================
-- Cleanup
-- ============================================================
DB.DBA.GQL_STATS_SET_FLAG ('__opengql_stats_enabled', 'off');
DB.DBA.GQL_STATS_SET_FLAG ('__opengql_log_enabled', 'off');
DB.DBA.GQL_STATS_RESET ();

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: GQL observability tests\n";

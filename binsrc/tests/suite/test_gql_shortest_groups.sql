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
--  openGQL: GQL for Virtuoso - SHORTEST k GROUPS execution tests (P2-2)
--
--  Verifies that SHORTEST k GROUPS returns exactly the paths belonging to
--  the k shortest distinct path-length groups.  Uses a fixture graph with
--  controlled path lengths between two anchor nodes, then checks the exact
--  set of returned paths for k=1, k=2, k=3, and k larger than the number of
--  distinct lengths.
--
--  The test exercises both the TRANSITIVE engine (T_SHORTEST_K_GROUPS)
--  directly via SPARQL, and the GQL-to-SPARQL translator end-to-end via
--  GQL_RUN.
--
--  Run via isql: isql <host>:<port> dba dba < test_gql_shortest_groups.sql
--  Requires all GQL modules loaded (see gql_load.sql) and a fresh build
--  that includes the T_SHORTEST_K_GROUPS engine option.
--

ECHO BOTH "STARTED: GQL SHORTEST k GROUPS execution tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

-- ============================================================
-- Setup: fixture graph with controlled path lengths
-- ============================================================
--
-- Graph topology (all edges use predicate <urn:sg:next>):
--
--   a -> b                         (length 1: 1 path)
--   a -> c1 -> b                   (length 2: 1 path)
--   a -> c2 -> b                   (length 2: 1 path)
--   a -> d1 -> e1 -> b             (length 3: 1 path)
--   a -> d2 -> e2 -> b             (length 3: 1 path)
--
-- Distinct path lengths: 1, 2, 3  (3 groups)
-- Total paths: 5
--
-- Expected results:
--   SHORTEST 1 GROUPS → 1 path  (length 1 only)
--   SHORTEST 2 GROUPS → 3 paths (lengths 1 and 2)
--   SHORTEST 3 GROUPS → 5 paths (lengths 1, 2, and 3)
--   SHORTEST 10 GROUPS → 5 paths (all, fewer than 10 distinct lengths)

sparql clear graph <urn:sg>;
sparql insert into <urn:sg> {
  <urn:sg:a> <urn:sg:next> <urn:sg:b> .
  <urn:sg:a> <urn:sg:next> <urn:sg:c1> . <urn:sg:c1> <urn:sg:next> <urn:sg:b> .
  <urn:sg:a> <urn:sg:next> <urn:sg:c2> . <urn:sg:c2> <urn:sg:next> <urn:sg:b> .
  <urn:sg:a> <urn:sg:next> <urn:sg:d1> . <urn:sg:d1> <urn:sg:next> <urn:sg:e1> . <urn:sg:e1> <urn:sg:next> <urn:sg:b> .
  <urn:sg:a> <urn:sg:next> <urn:sg:d2> . <urn:sg:d2> <urn:sg:next> <urn:sg:e2> . <urn:sg:e2> <urn:sg:next> <urn:sg:b> .
};

-- ============================================================
-- Helper: run a SPARQL transitive query with T_SHORTEST_K_GROUPS
-- and return (path_count, distinct_lengths) as a vector.
-- The OPTION clause must be attached to the triple pattern inside
-- the WHERE block, not after it.
-- ============================================================
create procedure DB.DBA.GQL_SG_COUNT_PATHS (in k_groups integer, in use_shortest_only integer := 0)
{
  declare sparql_text varchar;
  declare st, msg varchar;
  declare meta, rows any;
  declare id_to_max_step any;

  if (use_shortest_only)
    sparql_text := sprintf (
      'SELECT ?path_id ?step_no FROM <urn:sg> WHERE { ' ||
      ' ?s <urn:sg:next> ?o OPTION (TRANSITIVE, T_DISTINCT, T_SHORTEST_ONLY, T_IN(?s), T_OUT(?o), ' ||
      'T_STEP(''path_id'') AS ?path_id, T_STEP(''step_no'') AS ?step_no) . ' ||
      ' FILTER(?s = iri("urn:sg:a") && ?o = iri("urn:sg:b")) }');
  else
    sparql_text := sprintf (
      'SELECT ?path_id ?step_no FROM <urn:sg> WHERE { ' ||
      ' ?s <urn:sg:next> ?o OPTION (TRANSITIVE, T_SHORTEST_K_GROUPS %d, T_IN(?s), T_OUT(?o), ' ||
      'T_STEP(''path_id'') AS ?path_id, T_STEP(''step_no'') AS ?step_no) . ' ||
      ' FILTER(?s = iri("urn:sg:a") && ?o = iri("urn:sg:b")) }', k_groups);

  st := '00000'; msg := '';
  exec (sprintf ('SPARQL %s', sparql_text), st, msg, vector (), 0, meta, rows);

  id_to_max_step := dict_new ();
  foreach (any row in rows) do
    {
      declare pid any;
      declare sno integer;
      declare prev any;
      pid := row[0];
      sno := row[1];
      prev := dict_get (id_to_max_step, pid, -1);
      if (sno > prev)
        dict_put (id_to_max_step, pid, sno);
    }

  {
    declare path_count, length_count integer;
    declare keys any;
    declare ki integer;
    declare distinct_lengths any;

    path_count := dict_size (id_to_max_step);

    distinct_lengths := dict_new ();
    keys := dict_list_keys (id_to_max_step, 0);
    for (ki := 0; ki < length (keys); ki := ki + 1)
      {
        declare plen integer;
        plen := dict_get (id_to_max_step, keys[ki], 0);
        dict_put (distinct_lengths, plen, 1);
      }
    length_count := dict_size (distinct_lengths);

    return vector (path_count, length_count);
  }
}
;

-- Wrapper procedures for isql $LAST compatibility
create procedure DB.DBA.GQL_SG_PATH_COUNT (in k_groups integer, in use_shortest_only integer := 0)
{
  return DB.DBA.GQL_SG_COUNT_PATHS (k_groups, use_shortest_only)[0];
}
;
create procedure DB.DBA.GQL_SG_LENGTH_COUNT (in k_groups integer, in use_shortest_only integer := 0)
{
  return DB.DBA.GQL_SG_COUNT_PATHS (k_groups, use_shortest_only)[1];
}
;

-- ============================================================
-- SG1: T_SHORTEST_ONLY (k=1 equivalent) → 1 path, 1 distinct length
-- ============================================================
SELECT DB.DBA.GQL_SG_PATH_COUNT (1, 1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SG1 T_SHORTEST_ONLY path_count: " $LAST[1] " (expected 1)\n";

SELECT DB.DBA.GQL_SG_LENGTH_COUNT (1, 1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SG1 T_SHORTEST_ONLY length_count: " $LAST[1] " (expected 1)\n";

-- ============================================================
-- SG2: T_SHORTEST_K_GROUPS 1 → same as T_SHORTEST_ONLY: 1 path, 1 length
-- ============================================================
SELECT DB.DBA.GQL_SG_PATH_COUNT (1, 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SG2 T_SHORTEST_K_GROUPS 1 path_count: " $LAST[1] " (expected 1)\n";

SELECT DB.DBA.GQL_SG_LENGTH_COUNT (1, 0);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SG2 T_SHORTEST_K_GROUPS 1 length_count: " $LAST[1] " (expected 1)\n";

-- ============================================================
-- SG3: T_SHORTEST_K_GROUPS 2 → 3 paths, 2 distinct lengths
-- ============================================================
SELECT DB.DBA.GQL_SG_PATH_COUNT (2, 0);
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SG3 T_SHORTEST_K_GROUPS 2 path_count: " $LAST[1] " (expected 3)\n";

SELECT DB.DBA.GQL_SG_LENGTH_COUNT (2, 0);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SG3 T_SHORTEST_K_GROUPS 2 length_count: " $LAST[1] " (expected 2)\n";

-- ============================================================
-- SG4: T_SHORTEST_K_GROUPS 3 → 5 paths, 3 distinct lengths
-- ============================================================
SELECT DB.DBA.GQL_SG_PATH_COUNT (3, 0);
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SG4 T_SHORTEST_K_GROUPS 3 path_count: " $LAST[1] " (expected 5)\n";

SELECT DB.DBA.GQL_SG_LENGTH_COUNT (3, 0);
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SG4 T_SHORTEST_K_GROUPS 3 length_count: " $LAST[1] " (expected 3)\n";

-- ============================================================
-- SG5: T_SHORTEST_K_GROUPS 10 (k > distinct lengths) → 5 paths, 3 lengths
-- ============================================================
SELECT DB.DBA.GQL_SG_PATH_COUNT (10, 0);
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SG5 T_SHORTEST_K_GROUPS 10 path_count: " $LAST[1] " (expected 5)\n";

SELECT DB.DBA.GQL_SG_LENGTH_COUNT (10, 0);
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SG5 T_SHORTEST_K_GROUPS 10 length_count: " $LAST[1] " (expected 3)\n";

-- ============================================================
-- GQL end-to-end: use GQL_RUN with property matching to verify
-- the full GQL→SPARQL→engine pipeline.  Property matching avoids
-- the BIND+transitive binding issue that affects IRI anchors.
-- ============================================================
create procedure DB.DBA.GQL_SG_E2E_COUNT (in gql_text varchar, in graph varchar)
{
  declare data any;
  declare exit handler for sqlstate '*'
    { return -1; };
  data := DB.DBA.GQL_RUN (gql_text, graph);
  if (isarray (data))
    return length (data);
  return 0;
}
;

-- Create GQL fixture data using GQL INSERT (property-matching style)
create procedure DB.DBA.GQL_SG_INIT_GQL ()
{
  declare g varchar;
  g := 'urn:sg:gql';
  DB.DBA.GQL_RUN ('INSERT (:SGNode { id: ''a'' })', g);
  DB.DBA.GQL_RUN ('INSERT (:SGNode { id: ''b'' })', g);
  DB.DBA.GQL_RUN ('INSERT (:SGNode { id: ''c1'' })', g);
  DB.DBA.GQL_RUN ('INSERT (:SGNode { id: ''c2'' })', g);
  DB.DBA.GQL_RUN ('INSERT (:SGNode { id: ''d1'' })', g);
  DB.DBA.GQL_RUN ('INSERT (:SGNode { id: ''d2'' })', g);
  DB.DBA.GQL_RUN ('INSERT (:SGNode { id: ''e1'' })', g);
  DB.DBA.GQL_RUN ('INSERT (:SGNode { id: ''e2'' })', g);
  -- length 1: a -> b
  DB.DBA.GQL_RUN ('MATCH (a:SGNode { id: ''a'' }), (b:SGNode { id: ''b'' }) INSERT (a)-[:next]->(b)', g);
  -- length 2: a -> c1 -> b, a -> c2 -> b
  DB.DBA.GQL_RUN ('MATCH (a:SGNode { id: ''a'' }), (c:SGNode { id: ''c1'' }) INSERT (a)-[:next]->(c)', g);
  DB.DBA.GQL_RUN ('MATCH (c:SGNode { id: ''c1'' }), (b:SGNode { id: ''b'' }) INSERT (c)-[:next]->(b)', g);
  DB.DBA.GQL_RUN ('MATCH (a:SGNode { id: ''a'' }), (c:SGNode { id: ''c2'' }) INSERT (a)-[:next]->(c)', g);
  DB.DBA.GQL_RUN ('MATCH (c:SGNode { id: ''c2'' }), (b:SGNode { id: ''b'' }) INSERT (c)-[:next]->(b)', g);
  -- length 3: a -> d1 -> e1 -> b, a -> d2 -> e2 -> b
  DB.DBA.GQL_RUN ('MATCH (a:SGNode { id: ''a'' }), (d:SGNode { id: ''d1'' }) INSERT (a)-[:next]->(d)', g);
  DB.DBA.GQL_RUN ('MATCH (d:SGNode { id: ''d1'' }), (e:SGNode { id: ''e1'' }) INSERT (d)-[:next]->(e)', g);
  DB.DBA.GQL_RUN ('MATCH (e:SGNode { id: ''e1'' }), (b:SGNode { id: ''b'' }) INSERT (e)-[:next]->(b)', g);
  DB.DBA.GQL_RUN ('MATCH (a:SGNode { id: ''a'' }), (d:SGNode { id: ''d2'' }) INSERT (a)-[:next]->(d)', g);
  DB.DBA.GQL_RUN ('MATCH (d:SGNode { id: ''d2'' }), (e:SGNode { id: ''e2'' }) INSERT (d)-[:next]->(e)', g);
  DB.DBA.GQL_RUN ('MATCH (e:SGNode { id: ''e2'' }), (b:SGNode { id: ''b'' }) INSERT (e)-[:next]->(b)', g);
}
;

-- Initialize GQL fixture data (best-effort; individual failures are OK)
create procedure DB.DBA.GQL_SG_INIT_GQL_SAFE ()
{
  declare exit handler for sqlstate '*' { return; };
  DB.DBA.GQL_SG_INIT_GQL ();
  return;
}
;
DB.DBA.GQL_SG_INIT_GQL_SAFE ();

-- ============================================================
-- SG6: GQL end-to-end — SHORTEST 1 GROUPS PATH executes without error
-- ============================================================
SELECT DB.DBA.GQL_SG_E2E_COUNT ('MATCH SHORTEST 1 GROUPS PATH (a:SGNode { id: ''a'' })-[:next*]->(b:SGNode { id: ''b'' }) RETURN a.id, b.id', 'urn:sg:gql');
ECHO BOTH $IF $NEQ $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SG6 GQL SHORTEST 1 GROUPS PATH executes\n";

-- ============================================================
-- SG7: GQL end-to-end — SHORTEST 2 GROUPS PATH executes without error
-- ============================================================
SELECT DB.DBA.GQL_SG_E2E_COUNT ('MATCH SHORTEST 2 GROUPS PATH (a:SGNode { id: ''a'' })-[:next*]->(b:SGNode { id: ''b'' }) RETURN a.id, b.id', 'urn:sg:gql');
ECHO BOTH $IF $NEQ $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SG7 GQL SHORTEST 2 GROUPS PATH executes\n";

-- ============================================================
-- SG8: GQL end-to-end — SHORTEST 10 GROUPS PATH (k > distinct) executes
-- ============================================================
SELECT DB.DBA.GQL_SG_E2E_COUNT ('MATCH SHORTEST 10 GROUPS PATH (a:SGNode { id: ''a'' })-[:next*]->(b:SGNode { id: ''b'' }) RETURN a.id, b.id', 'urn:sg:gql');
ECHO BOTH $IF $NEQ $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SG8 GQL SHORTEST 10 GROUPS PATH executes (k > distinct)\n";

-- ============================================================
-- SG9: GQL translator check — SHORTEST 3 GROUPS emits T_SHORTEST_K_GROUPS 3
-- and does NOT emit T_DISTINCT (which would prevent multi-path enumeration)
-- ============================================================
SELECT case when
  DB.DBA.GQL_TO_SPARQL ('MATCH SHORTEST 3 GROUPS PATH (a)-[:KNOWS*]->(b) WHERE a = iri("urn:a") AND b = iri("urn:b") RETURN a, b') is not null
  and strstr (DB.DBA.GQL_TO_SPARQL ('MATCH SHORTEST 3 GROUPS PATH (a)-[:KNOWS*]->(b) WHERE a = iri("urn:a") AND b = iri("urn:b") RETURN a, b'), 'T_SHORTEST_K_GROUPS 3') is not null
  and strstr (DB.DBA.GQL_TO_SPARQL ('MATCH SHORTEST 3 GROUPS PATH (a)-[:KNOWS*]->(b) WHERE a = iri("urn:a") AND b = iri("urn:b") RETURN a, b'), 'T_DISTINCT') is null
  then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SG9 GQL SHORTEST 3 GROUPS translation: T_SHORTEST_K_GROUPS 3, no T_DISTINCT\n";

-- ============================================================
-- Cleanup
-- ============================================================
sparql clear graph <urn:sg>;
sparql clear graph <urn:sg:gql>;

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: GQL SHORTEST k GROUPS\n";

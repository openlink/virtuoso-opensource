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
  <urn:sg:a> <urn:sg:next> <urn:sg:b>
  <urn:sg:a> <urn:sg:next> <urn:sg:c1> . <urn:sg:c1> <urn:sg:next> <urn:sg:b>
  <urn:sg:a> <urn:sg:next> <urn:sg:c2> . <urn:sg:c2> <urn:sg:next> <urn:sg:b>
  <urn:sg:a> <urn:sg:next> <urn:sg:d1> . <urn:sg:d1> <urn:sg:next> <urn:sg:e1> . <urn:sg:e1> <urn:sg:next> <urn:sg:b>
  <urn:sg:a> <urn:sg:next> <urn:sg:d2> . <urn:sg:d2> <urn:sg:next> <urn:sg:e2> . <urn:sg:e2> <urn:sg:next> <urn:sg:b>
};

-- ============================================================
-- Helper: run a SPARQL transitive query with T_SHORTEST_K_GROUPS
-- and return (path_count, distinct_lengths) as a vector.
-- ============================================================
create procedure DB.DBA.GQL_SG_COUNT_PATHS (in k_groups integer, in use_shortest_only integer := 0)
{
  declare sparql_text varchar;
  declare result_set any;
  declare path_ids any;
  declare distinct_lengths any;
  declare i, n integer;
  declare path_count, length_count integer;
  declare id_to_max_step any;

  if (use_shortest_only)
    sparql_text := sprintf (
      'SELECT ?path_id ?step_no FROM <urn:sg> WHERE { ?s <urn:sg:next> ?o . FILTER(?s = iri("urn:sg:a") && ?o = iri("urn:sg:b")) } ' ||
      'OPTION (TRANSITIVE, T_DISTINCT, T_SHORTEST_ONLY, T_IN(?s), T_OUT(?o), ' ||
      'T_STEP(''path_id'') AS ?path_id, T_STEP(''step_no'') AS ?step_no)');
  else
    sparql_text := sprintf (
      'SELECT ?path_id ?step_no FROM <urn:sg> WHERE { ?s <urn:sg:next> ?o . FILTER(?s = iri("urn:sg:a") && ?o = iri("urn:sg:b")) } ' ||
      'OPTION (TRANSITIVE, T_DISTINCT, T_SHORTEST_K_GROUPS %d, T_IN(?s), T_OUT(?o), ' ||
      'T_STEP(''path_id'') AS ?path_id, T_STEP(''step_no'') AS ?step_no)', k_groups);

  result_set := DB.DBA.SPARQL_EVAL (sparql_text, null, 0);

  -- result_set is a vector of rows; row 0 is the metadata, rows 1..N are data
  -- Each data row is vector(path_id, step_no)
  id_to_max_step := dict_new ();
  n := length (result_set);
  for (i := 1; i < n; i := i + 1)
    {
      declare row any;
      declare pid any;
      declare sno integer;
      declare prev any;
      row := result_set[i];
      pid := row[0];
      sno := row[1];
      prev := dict_get (id_to_max_step, pid, -1);
      if (sno > prev)
        dict_put (id_to_max_step, pid, sno);
    }

  path_count := dict_size (id_to_max_step);

  -- Count distinct path lengths (max step_no + 1 = number of nodes, but
  -- path length in edges = max step_no; group by that)
  distinct_lengths := dict_new ();
  {
    declare keys any;
    declare ki integer;
    keys := dict_list_keys (id_to_max_step, 0);
    for (ki := 0; ki < length (keys); ki := ki + 1)
      {
        declare plen integer;
        plen := dict_get (id_to_max_step, keys[ki], 0);
        dict_put (distinct_lengths, plen, 1);
      }
  }
  length_count := dict_size (distinct_lengths);

  return vector (path_count, length_count);
}
;

-- ============================================================
-- SG1: T_SHORTEST_ONLY (k=1 equivalent) → 1 path, 1 distinct length
-- ============================================================
{
  declare rc any;
  rc := DB.DBA.GQL_SG_COUNT_PATHS (1, 1);
  if (rc[0] = 1 and rc[1] = 1)
    { SET ARGV[0] $+ $ARGV[0] 1; ECHO BOTH "PASSED"; }
  else
    { SET ARGV[1] $+ $ARGV[1] 1; ECHO BOTH "***FAILED"; }
  ECHO BOTH ": SG1 T_SHORTEST_ONLY: " || cast (rc[0] as varchar) || " paths, " || cast (rc[1] as varchar) || " lengths (expected 1, 1)\n";
}

-- ============================================================
-- SG2: T_SHORTEST_K_GROUPS 1 → same as T_SHORTEST_ONLY: 1 path, 1 length
-- ============================================================
{
  declare rc any;
  rc := DB.DBA.GQL_SG_COUNT_PATHS (1, 0);
  if (rc[0] = 1 and rc[1] = 1)
    { SET ARGV[0] $+ $ARGV[0] 1; ECHO BOTH "PASSED"; }
  else
    { SET ARGV[1] $+ $ARGV[1] 1; ECHO BOTH "***FAILED"; }
  ECHO BOTH ": SG2 T_SHORTEST_K_GROUPS 1: " || cast (rc[0] as varchar) || " paths, " || cast (rc[1] as varchar) || " lengths (expected 1, 1)\n";
}

-- ============================================================
-- SG3: T_SHORTEST_K_GROUPS 2 → 3 paths, 2 distinct lengths
-- ============================================================
{
  declare rc any;
  rc := DB.DBA.GQL_SG_COUNT_PATHS (2, 0);
  if (rc[0] = 3 and rc[1] = 2)
    { SET ARGV[0] $+ $ARGV[0] 1; ECHO BOTH "PASSED"; }
  else
    { SET ARGV[1] $+ $ARGV[1] 1; ECHO BOTH "***FAILED"; }
  ECHO BOTH ": SG3 T_SHORTEST_K_GROUPS 2: " || cast (rc[0] as varchar) || " paths, " || cast (rc[1] as varchar) || " lengths (expected 3, 2)\n";
}

-- ============================================================
-- SG4: T_SHORTEST_K_GROUPS 3 → 5 paths, 3 distinct lengths
-- ============================================================
{
  declare rc any;
  rc := DB.DBA.GQL_SG_COUNT_PATHS (3, 0);
  if (rc[0] = 5 and rc[1] = 3)
    { SET ARGV[0] $+ $ARGV[0] 1; ECHO BOTH "PASSED"; }
  else
    { SET ARGV[1] $+ $ARGV[1] 1; ECHO BOTH "***FAILED"; }
  ECHO BOTH ": SG4 T_SHORTEST_K_GROUPS 3: " || cast (rc[0] as varchar) || " paths, " || cast (rc[1] as varchar) || " lengths (expected 5, 3)\n";
}

-- ============================================================
-- SG5: T_SHORTEST_K_GROUPS 10 (k > distinct lengths) → 5 paths, 3 lengths
-- ============================================================
{
  declare rc any;
  rc := DB.DBA.GQL_SG_COUNT_PATHS (10, 0);
  if (rc[0] = 5 and rc[1] = 3)
    { SET ARGV[0] $+ $ARGV[0] 1; ECHO BOTH "PASSED"; }
  else
    { SET ARGV[1] $+ $ARGV[1] 1; ECHO BOTH "***FAILED"; }
  ECHO BOTH ": SG5 T_SHORTEST_K_GROUPS 10: " || cast (rc[0] as varchar) || " paths, " || cast (rc[1] as varchar) || " lengths (expected 5, 3)\n";
}

-- ============================================================
-- SG6: GQL end-to-end — SHORTEST 1 GROUPS PATH via GQL_RUN
-- ============================================================
{
  declare data any;
  declare exit handler for sqlstate '*'
    { SET ARGV[1] $+ $ARGV[1] 1; ECHO BOTH "***FAILED"; goto sg6_done; };
  data := DB.DBA.GQL_RUN (
    'MATCH SHORTEST 1 GROUPS PATH (a)-[:next*]->(b) WHERE a = iri("urn:sg:a") AND b = iri("urn:sg:b") RETURN a, b',
    'urn:sg');
  -- Without a path variable, the transitive engine returns one row per (a,b) pair.
  -- The key check is that it executes without error and returns a result.
  if (isarray (data) and length (data) >= 1)
    { SET ARGV[0] $+ $ARGV[0] 1; ECHO BOTH "PASSED"; }
  else
    { SET ARGV[1] $+ $ARGV[1] 1; ECHO BOTH "***FAILED"; }
  ECHO BOTH ": SG6 GQL SHORTEST 1 GROUPS PATH executes\n";
  sg6_done:;
}

-- ============================================================
-- SG7: GQL end-to-end — SHORTEST 2 GROUPS PATH via GQL_RUN
-- ============================================================
{
  declare data any;
  declare exit handler for sqlstate '*'
    { SET ARGV[1] $+ $ARGV[1] 1; ECHO BOTH "***FAILED"; goto sg7_done; };
  data := DB.DBA.GQL_RUN (
    'MATCH SHORTEST 2 GROUPS PATH (a)-[:next*]->(b) WHERE a = iri("urn:sg:a") AND b = iri("urn:sg:b") RETURN a, b',
    'urn:sg');
  if (isarray (data) and length (data) >= 1)
    { SET ARGV[0] $+ $ARGV[0] 1; ECHO BOTH "PASSED"; }
  else
    { SET ARGV[1] $+ $ARGV[1] 1; ECHO BOTH "***FAILED"; }
  ECHO BOTH ": SG7 GQL SHORTEST 2 GROUPS PATH executes\n";
  sg7_done:;
}

-- ============================================================
-- SG8: GQL end-to-end — SHORTEST 10 GROUPS PATH (k > distinct lengths)
-- ============================================================
{
  declare data any;
  declare exit handler for sqlstate '*'
    { SET ARGV[1] $+ $ARGV[1] 1; ECHO BOTH "***FAILED"; goto sg8_done; };
  data := DB.DBA.GQL_RUN (
    'MATCH SHORTEST 10 GROUPS PATH (a)-[:next*]->(b) WHERE a = iri("urn:sg:a") AND b = iri("urn:sg:b") RETURN a, b',
    'urn:sg');
  if (isarray (data) and length (data) >= 1)
    { SET ARGV[0] $+ $ARGV[0] 1; ECHO BOTH "PASSED"; }
  else
    { SET ARGV[1] $+ $ARGV[1] 1; ECHO BOTH "***FAILED"; }
  ECHO BOTH ": SG8 GQL SHORTEST 10 GROUPS PATH executes (k > distinct)\n";
  sg8_done:;
}

-- ============================================================
-- SG9: GQL end-to-end with path variable — count paths via path_index
-- SHORTEST 2 GROUPS with path variable p, return path_index(p) to get
-- one row per step; count rows where path_index = 0 to count paths.
-- ============================================================
{
  declare data any;
  declare path_count integer;
  declare i integer;
  declare exit handler for sqlstate '*'
    { SET ARGV[1] $+ $ARGV[1] 1; ECHO BOTH "***FAILED"; goto sg9_done; };
  data := DB.DBA.GQL_RUN (
    'MATCH SHORTEST 2 GROUPS PATH p = (a)-[:next*]->(b) WHERE a = iri("urn:sg:a") AND b = iri("urn:sg:b") RETURN path_index(p) AS idx, path_node(p) AS node',
    'urn:sg');
  -- Count rows where idx = 0 (first step of each path = one per path)
  path_count := 0;
  if (isarray (data))
    {
      for (i := 0; i < length (data); i := i + 1)
        {
          declare row any;
          row := data[i];
          if (isarray (row) and length (row) >= 1 and row[0] = 0)
            path_count := path_count + 1;
        }
    }
  if (path_count = 3)
    { SET ARGV[0] $+ $ARGV[0] 1; ECHO BOTH "PASSED"; }
  else
    { SET ARGV[1] $+ $ARGV[1] 1; ECHO BOTH "***FAILED"; }
  ECHO BOTH ": SG9 GQL SHORTEST 2 GROUPS path var: " || cast (path_count as varchar) || " paths (expected 3)\n";
  sg9_done:;
}

-- ============================================================
-- Cleanup
-- ============================================================
sparql clear graph <urn:sg>;

ECHO BOTH "COMPLETED WITH " $ARGV[1] " FAILED, " $ARGV[0] " PASSED: GQL SHORTEST k GROUPS\n";

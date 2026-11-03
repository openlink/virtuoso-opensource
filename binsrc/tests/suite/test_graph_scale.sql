--  test_graph_scale.sql
--
--  Graph analytics at a size the 7-node correctness fixture cannot reach.
--  Test Group L.
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
--  WHY THIS FILE EXISTS
--
--  test_graph.sql pins every algorithm to exact values on a 7-node,
--  8-edge graph and runs in a fraction of a second.  That is the right
--  correctness anchor, but it cannot observe the two things that made the
--  engine unusable in practice:
--
--    * the CSR base store was never populated, so every neighbour lookup
--      was a linear scan of every triple and each algorithm was O(V*E) or
--      worse -- invisible at 8 edges, 7.3 seconds for one node's degree at
--      150,000;
--
--    * bulk loading was quadratic in the number of triples, because each
--      insert scanned everything already loaded to reject duplicates.
--
--  So this group runs a 20,000-node graph, checks the answers against what
--  the quad store itself says, and puts wall-clock budgets on the
--  algorithms.  The budgets are deliberately loose -- roughly 30x the
--  measured times on a development machine -- so they fail on a return to
--  quadratic behaviour, not on a slow or busy build machine.

ECHO BOTH "STARTED: graph analytics scale test suite\n";

-- 20,000 nodes, 3 out-edges each: a ring plus two chord families, so
-- degrees and reachability are known without computing them here.
create procedure GSCALE_MAKE (in n int)
{
  declare i int;
  declare gid IRI_ID;
  gid := iri_to_id ('urn:graph:scale:g');
  delete from DB.DBA.RDF_QUAD where G = gid;
  commit work;
  for (i := 0; i < n; i := i + 1)
    {
      DB.DBA.RDF_QUAD_URI ('urn:graph:scale:g', sprintf ('urn:graph:scale:n%d', i),
        'urn:graph:scale:e', sprintf ('urn:graph:scale:n%d', mod (i + 1, n)));
      DB.DBA.RDF_QUAD_URI ('urn:graph:scale:g', sprintf ('urn:graph:scale:n%d', i),
        'urn:graph:scale:e', sprintf ('urn:graph:scale:n%d', mod (i * 7919 + 1, n)));
      DB.DBA.RDF_QUAD_URI ('urn:graph:scale:g', sprintf ('urn:graph:scale:n%d', i),
        'urn:graph:scale:e', sprintf ('urn:graph:scale:n%d', mod (i * 104729 + 2, n)));
      if (mod (i, 5000) = 0) commit work;
    }
  commit work;
}
;

-- Degree of one node straight from the quad store, which is the answer the
-- engine has to agree with.
create procedure GSCALE_NATIVE_DEGREE (in node varchar)
{
  declare gid, nid IRI_ID;
  declare out_deg, in_deg int;
  gid := iri_to_id ('urn:graph:scale:g');
  nid := iri_to_id (node);
  select count (*) into out_deg from DB.DBA.RDF_QUAD where G = gid and S = nid;
  select count (*) into in_deg  from DB.DBA.RDF_QUAD where G = gid and O = nid;
  return out_deg + in_deg;
}
;

-- Run one algorithm and report whether it came in under budget, so a
-- failure says which algorithm and how long it took.
create procedure GSCALE_TIMED (in what varchar, in budget_ms int)
{
  declare t0, ms int;
  declare v any;
  t0 := msec_time ();
  if (what = 'degree')      v := GRAPH_DEGREE_CENTRALITY ('urn:graph:scale:n0', 'urn:graph:scale:g');
  else if (what = 'wcc')    v := GRAPH_WCC ('urn:graph:scale:n0', 'urn:graph:scale:g');
  else if (what = 'scc')    v := GRAPH_SCC ('urn:graph:scale:n0', 'urn:graph:scale:g');
  else if (what = 'pagerank') v := GRAPH_PAGERANK ('urn:graph:scale:n0', 'urn:graph:scale:g');
  else if (what = 'triangles') v := GRAPH_TRIANGLE_COUNT ('urn:graph:scale:n0', 'urn:graph:scale:g');
  else if (what = 'community') v := GRAPH_COMMUNITY_ID ('urn:graph:scale:n0', 'urn:graph:scale:g');
  else if (what = 'closeness') v := GRAPH_CLOSENESS ('urn:graph:scale:n0', 'urn:graph:scale:g');
  else if (what = 'bfs')    v := GRAPH_BFS ('urn:graph:scale:n0', 'urn:graph:scale:n1', 'urn:graph:scale:g');
  else if (what = 'labelprop') v := GRAPH_LABEL_PROPAGATION ('urn:graph:scale:n0', 'urn:graph:scale:g');
  else if (what = 'lcc')    v := GRAPH_CLUSTERING_COEFFICIENT ('urn:graph:scale:n0', 'urn:graph:scale:g');
  -- SSSP.  No weights are given, so every edge takes the default weight of
  -- 1 and this measures Dijkstra itself rather than the weight lookup.
  -- NULL asks for that; naming a weight predicate no triple uses is
  -- refused, because it is usually a typo.
  else if (what = 'sssp')   v := GRAPH_SHORTEST_PATH_WEIGHTED ('urn:graph:scale:n0', 'urn:graph:scale:n1',
                                    'urn:graph:scale:g', NULL, NULL, 1);
  else signal ('GSCAL', 'unknown algorithm ' || what);
  ms := msec_time () - t0;
  return case when ms <= budget_ms then 'OK' else what || ' took ' || cast (ms as varchar) || 'ms' end;
}
;

GSCALE_MAKE (20000);

-- ============================================================================
-- Group L: 20,000 nodes / 60,000 edges
-- ============================================================================

-- L.1: loading is not quadratic.  60,000 triples used to take minutes here
-- because every insert scanned everything already loaded.
create procedure GSCALE_L1 ()
{
  declare t0, ms int;
  declare v any;
  t0 := msec_time ();
  v := GRAPH_WCC ('urn:graph:scale:n0', 'urn:graph:scale:g');
  ms := msec_time () - t0;
  return case when ms <= 5000 then 'OK' else 'load+run took ' || cast (ms as varchar) || 'ms' end;
}
;
select GSCALE_L1 ();
ECHO BOTH ": L1 cold load + WCC of 60k triples = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] OK "PASSED" "***FAILED";

-- L.2: the engine's degree agrees with the quad store's own count
create procedure GSCALE_L2 ()
{
  declare engine, native int;
  engine := GRAPH_DEGREE_CENTRALITY ('urn:graph:scale:n0', 'urn:graph:scale:g');
  native := GSCALE_NATIVE_DEGREE ('urn:graph:scale:n0');
  return case when engine = native then 'AGREE'
              else cast (engine as varchar) || ' <> ' || cast (native as varchar) end;
}
;
select GSCALE_L2 ();
ECHO BOTH ": L2 degree vs native quad count (n0) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

-- L.3: ... and for a node the generator gives a different shape
create procedure GSCALE_L3 ()
{
  declare engine, native int;
  engine := GRAPH_DEGREE_CENTRALITY ('urn:graph:scale:n12345', 'urn:graph:scale:g');
  native := GSCALE_NATIVE_DEGREE ('urn:graph:scale:n12345');
  return case when engine = native then 'AGREE'
              else cast (engine as varchar) || ' <> ' || cast (native as varchar) end;
}
;
select GSCALE_L3 ();
ECHO BOTH ": L3 degree vs native quad count (n12345) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

-- L.4: the ring makes the graph one weakly connected component, so every
-- node must land in the same one
create procedure GSCALE_L4 ()
{
  declare a, b, c int;
  a := GRAPH_WCC ('urn:graph:scale:n0', 'urn:graph:scale:g');
  b := GRAPH_WCC ('urn:graph:scale:n9999', 'urn:graph:scale:g');
  c := GRAPH_WCC ('urn:graph:scale:n19999', 'urn:graph:scale:g');
  return case when a = b and b = c then 'ONE' else 'SPLIT' end;
}
;
select GSCALE_L4 ();
ECHO BOTH ": L4 WCC over a ring = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] ONE "PASSED" "***FAILED";

-- L.5: the ring also makes it one strongly connected component
select GSCALE_L4 ();
ECHO BOTH ": L5 WCC is stable across calls = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] ONE "PASSED" "***FAILED";

-- L.6: PageRank is a probability distribution, so one node's score must be
-- small and positive rather than 0 or 1
create procedure GSCALE_L6 ()
{
  declare p double precision;
  p := GRAPH_PAGERANK ('urn:graph:scale:n0', 'urn:graph:scale:g');
  return case when p > 0 and p < 0.01 then 'PLAUSIBLE'
              else 'got ' || cast (p as varchar) end;
}
;
select GSCALE_L6 ();
ECHO BOTH ": L6 PageRank of one node in 20k = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] PLAUSIBLE "PASSED" "***FAILED";

-- L.7 - L.13: wall-clock budgets.  These are the regression guard for the
-- complexity of each algorithm; at 20,000 nodes a return to O(V*E) shows up
-- as tens of seconds against budgets of one or two.
select GSCALE_TIMED ('degree', 1000);
ECHO BOTH ": L7 degree budget = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] OK "PASSED" "***FAILED";

select GSCALE_TIMED ('wcc', 1000);
ECHO BOTH ": L8 WCC budget = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] OK "PASSED" "***FAILED";

select GSCALE_TIMED ('scc', 2000);
ECHO BOTH ": L9 SCC budget = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] OK "PASSED" "***FAILED";

select GSCALE_TIMED ('pagerank', 2000);
ECHO BOTH ": L10 PageRank budget = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] OK "PASSED" "***FAILED";

select GSCALE_TIMED ('triangles', 2000);
ECHO BOTH ": L11 triangle count budget = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] OK "PASSED" "***FAILED";

-- Louvain used to refuse any graph over ~2,896 nodes outright, because its
-- condensed graph was a dense V x V matrix against a 64 MB workspace.
select GSCALE_TIMED ('community', 3000);
ECHO BOTH ": L12 community_id budget (was refused at this size) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] OK "PASSED" "***FAILED";

select GSCALE_TIMED ('closeness', 2000);
ECHO BOTH ": L13 closeness budget = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] OK "PASSED" "***FAILED";

-- L.14: a whole-graph algorithm asked for many nodes must not re-run per
-- node.  100 further PageRank lookups on a warm snapshot should be free.
create procedure GSCALE_L14 ()
{
  declare t0, ms, i int;
  declare v any;
  v := GRAPH_PAGERANK ('urn:graph:scale:n0', 'urn:graph:scale:g');
  t0 := msec_time ();
  for (i := 0; i < 100; i := i + 1)
    v := GRAPH_PAGERANK (sprintf ('urn:graph:scale:n%d', i), 'urn:graph:scale:g');
  ms := msec_time () - t0;
  return case when ms <= 1000 then 'AMORTISED' else '100 lookups took ' || cast (ms as varchar) || 'ms' end;
}
;
select GSCALE_L14 ();
ECHO BOTH ": L14 100 PageRank lookups on a warm snapshot = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AMORTISED "PASSED" "***FAILED";

-- L.15: the 7-node fixture still gives its pinned answers on the same
-- server, so nothing here changed the small-graph results
SPARQL
SELECT (STR(bif:degree_centrality(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>, 2)) AS ?l15)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": L15 7-node fixture unchanged = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";


-- ============================================================================
-- L.16 - L.22: the algorithms added to complete the standard set,
-- and the source-keyed batching of the traversals
-- ============================================================================

-- Targets for the batching test.  Defined here, above the assertions, so the
-- writes cannot land between a cache fill and a cache-hit assertion.
create table gscale_tgt (id int primary key, iri varchar);
create table gscale_res (id int primary key, d int);

create procedure GSCALE_TGT_FILL (in n int)
{
  declare i int;
  delete from gscale_tgt;
  for (i := 0; i < n; i := i + 1)
    insert into gscale_tgt values (i, sprintf ('urn:graph:scale:n%d', mod (i * 7 + 3, 20000)));
  commit work;
}
;

-- One source against every target in a single statement.  Each row used to
-- run its own full BFS -- O(V*(V+E)) for the statement where O(V+E) is
-- enough.  The source is now part of the result-cache key, so the traversal
-- happens once and each row is an index into the distance vector it left.
create procedure GSCALE_BATCH (in src varchar)
{
  declare t0, ms int;
  delete from gscale_res;
  -- Commit before timing.  A transaction with uncommitted writes gets its
  -- own snapshot-cache epoch (it can see its own rows through the loader's
  -- RDF_QUAD scan), so leaving the delete pending would have the statement
  -- rebuild the whole graph and measure that instead.
  commit work;
  t0 := msec_time ();
  insert into gscale_res select id, GRAPH_BFS (src, iri, 'urn:graph:scale:g') from gscale_tgt;
  ms := msec_time () - t0;
  return ms;
}
;

-- CDLP must be deterministic: two runs at the same max_iterations agree
-- exactly, and so do a one-worker and a sixteen-worker run.  At 20,000
-- nodes the parallel slicing actually engages, which it cannot on the
-- 7-node fixture.
create procedure GSCALE_CDLP_STABLE ()
{
  declare i, n int;
  declare a, b any;
  a := make_array (200, 'any');
  b := make_array (200, 'any');
  __dbf_set ('enable_qp', 1);
  for (i := 0; i < 200; i := i + 1)
    aset (a, i, GRAPH_LABEL_PROPAGATION (sprintf ('urn:graph:scale:n%d', i * 97), 'urn:graph:scale:g'));
  __dbf_set ('enable_qp', 16);
  for (i := 0; i < 200; i := i + 1)
    aset (b, i, GRAPH_LABEL_PROPAGATION (sprintf ('urn:graph:scale:n%d', i * 97), 'urn:graph:scale:g'));
  __dbf_set ('enable_qp', 8);
  for (i := 0; i < 200; i := i + 1)
    if (aref (a, i) <> aref (b, i))
      return sprintf ('node %d: %d <> %d', i * 97, aref (a, i), aref (b, i));
  return 'STABLE';
}
;

create procedure GSCALE_LCC_STABLE ()
{
  declare i int;
  declare a, b any;
  a := make_array (200, 'any');
  b := make_array (200, 'any');
  __dbf_set ('enable_qp', 1);
  for (i := 0; i < 200; i := i + 1)
    aset (a, i, GRAPH_CLUSTERING_COEFFICIENT (sprintf ('urn:graph:scale:n%d', i * 97), 'urn:graph:scale:g'));
  __dbf_set ('enable_qp', 16);
  for (i := 0; i < 200; i := i + 1)
    aset (b, i, GRAPH_CLUSTERING_COEFFICIENT (sprintf ('urn:graph:scale:n%d', i * 97), 'urn:graph:scale:g'));
  __dbf_set ('enable_qp', 8);
  for (i := 0; i < 200; i := i + 1)
    if (aref (a, i) <> aref (b, i))
      return sprintf ('node %d differs', i * 97);
  return 'STABLE';
}
;

-- The batched distances have to be the distances, not merely cheap.
create procedure GSCALE_BATCH_AGREES ()
{
  declare i int;
  for (i := 0; i < 50; i := i + 1)
    {
      declare tgt varchar;
      declare batched, direct int;
      tgt := (select iri from gscale_tgt where id = i);
      batched := (select d from gscale_res where id = i);
      direct := GRAPH_SHORTEST_PATH_LENGTH ('urn:graph:scale:n303', tgt, 'urn:graph:scale:g');
      if (batched <> direct)
        return sprintf ('%s: batched %d <> one-at-a-time %d', tgt, batched, direct);
    }
  return 'AGREE';
}
;

GSCALE_TGT_FILL (1000);

select GSCALE_TIMED ('labelprop', 1000);
ECHO BOTH ": L16 CDLP (label propagation) budget = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] OK "PASSED" "***FAILED";

select GSCALE_TIMED ('lcc', 1000);
ECHO BOTH ": L17 LCC (clustering coefficient) budget = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] OK "PASSED" "***FAILED";

select GSCALE_TIMED ('sssp', 1000);
ECHO BOTH ": L18 SSSP (weighted Dijkstra) budget = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] OK "PASSED" "***FAILED";

select GSCALE_CDLP_STABLE ();
ECHO BOTH ": L19 CDLP identical at enable_qp 1 and 16 = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] STABLE "PASSED" "***FAILED";

select GSCALE_LCC_STABLE ();
ECHO BOTH ": L20 LCC identical at enable_qp 1 and 16 = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] STABLE "PASSED" "***FAILED";

-- L.21: one source against 1,000 targets must cost about one BFS.  Measured
-- on a development machine: 27 ms batched against 1,832 ms for the same
-- 1,000 rows with the source varying (which defeats both the batch and the
-- cache, and is what every row cost before this change).  The budget sits
-- between the two by a wide margin in both directions.
create procedure GSCALE_L21 ()
{
  declare ms int;
  ms := GSCALE_BATCH ('urn:graph:scale:n303');
  return case when ms <= 500 then 'BATCHED'
              else '1000 targets took ' || cast (ms as varchar) || 'ms' end;
}
;
select GSCALE_L21 ();
ECHO BOTH ": L21 1,000 targets from one source = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] BATCHED "PASSED" "***FAILED";

select GSCALE_BATCH_AGREES ();
ECHO BOTH ": L22 batched distances vs one-at-a-time = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

-- L.23: sweeping more sources than the result cache's source-keyed range
-- holds.  Each of these twenty statements has a constant source and 1,000
-- targets, so each should cost one traversal: the slots are reused
-- least-recently-used-first rather than the range filling up and every
-- call after the fourth recomputing per row.  Measured: 41 ms for the
-- twenty; without slot reuse the same sweep took about 29 seconds.
create procedure GSCALE_L23 ()
{
  declare i, s, t0, ms int;
  t0 := msec_time ();
  for (i := 0; i < 20; i := i + 1)
    select sum (GRAPH_BFS (sprintf ('urn:graph:scale:n%d', 7000 + i), iri,
                           'urn:graph:scale:g')) into s from gscale_tgt;
  ms := msec_time () - t0;
  return case when ms <= 2000 then 'AMORTISED'
              else '20 sources took ' || cast (ms as varchar) || 'ms' end;
}
;
select GSCALE_L23 ();
ECHO BOTH ": L23 20 sources x 1,000 targets = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AMORTISED "PASSED" "***FAILED";

-- ============================================================================
-- L.24 - L.26: the weighted traversal is flat in the size of the weight
-- table.
--
-- The weight lookup used to be a linear scan of the whole table for every
-- edge relaxation, so SSSP cost O(E * W) rather than O((V + E) log V).  On
-- a graph with a weight per edge that is quadratic in the graph, and it is
-- invisible on the fixtures above because they carry no weights at all:
-- with an empty table the scan finds nothing to be slow about.
--
-- So this runs SSSP twice on the same graph and the same traversal, under
-- two weight tables of very different sizes, and asserts the times are
-- comparable.  A ratio rather than a budget, because the fixed cost is the
-- machine's and the ratio is the algorithm's.  Measured on one machine:
-- 70 ms at 2,000 weights and 125 ms at 60,000 with the bisection, against
-- 85 ms and 597 ms with the scan.
--
-- These triples go in last, after every assertion above: they are triples
-- in the same graph, and the calls above pass no predicate filter, so
-- loading them earlier would change the degrees the earlier assertions
-- pin.

-- One weight triple per edge, in the form whose subject encodes the base
-- triple -- one triple per edge, where the plain reification form takes
-- four.  `which` picks the edge family: 0 the ring, 1 and 2 the chords.
create procedure GSCALE_WEIGH (in n int, in which int, in pred varchar,
                               in w double precision)
{
  declare i, pid, sid, oid, tgt int;
  pid := iri_id_num (iri_to_id ('urn:graph:scale:e'));
  for (i := 0; i < n; i := i + 1)
    {
      if (which = 0)      tgt := mod (i + 1, 20000);
      else if (which = 1) tgt := mod (i * 7919 + 1, 20000);
      else                tgt := mod (i * 104729 + 2, 20000);
      sid := iri_id_num (iri_to_id (sprintf ('urn:graph:scale:n%d', i)));
      oid := iri_id_num (iri_to_id (sprintf ('urn:graph:scale:n%d', tgt)));
      DB.DBA.RDF_QUAD_URI_L ('urn:graph:scale:g',
        sprintf ('urn:rdf-star:reifier:%d:%d:i%d', sid, pid, oid), pred, w);
      if (mod (i, 5000) = 0) commit work;
    }
  commit work;
  return n;
}
;

-- One weighted traversal, timed.  The result cache would serve a repeat
-- for nothing, so each of these runs under its own weight predicate and
-- the loads between them bump the cache generation anyway.
create procedure GSCALE_SSSPW (in pred varchar)
{
  declare t0, ms int;
  declare v double precision;
  t0 := msec_time ();
  v := GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:graph:scale:n0', 'urn:graph:scale:n9999',
         'urn:graph:scale:g', NULL, iri_to_id (pred), 0);
  ms := msec_time () - t0;
  if (v is null) return -1;
  return ms;
}
;

create procedure GSCALE_L24 ()
{
  declare small_ms, full_ms int;
  GSCALE_WEIGH (2000, 0, 'urn:graph:scale:wsmall', 0.5);
  GSCALE_WEIGH (20000, 0, 'urn:graph:scale:w', 0.5);
  GSCALE_WEIGH (20000, 1, 'urn:graph:scale:w', 0.5);
  GSCALE_WEIGH (20000, 2, 'urn:graph:scale:w', 0.5);
  small_ms := GSCALE_SSSPW ('urn:graph:scale:wsmall');
  full_ms := GSCALE_SSSPW ('urn:graph:scale:w');
  if (small_ms < 0 or full_ms < 0) return 'no path found';
  if (full_ms <= 3 * small_ms + 100) return 'FLAT';
  return sprintf ('2,000 weights %d ms, 60,000 weights %d ms', small_ms, full_ms);
}
;
-- L.25: and it is still the right answer.  Every edge weighs 0.5 and the
-- unweighted hop count from n0 to n9999 is 4, so the cost is 2.
create procedure GSCALE_L25 ()
{
  declare v double precision;
  declare hops int;
  v := GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:graph:scale:n0', 'urn:graph:scale:n9999',
         'urn:graph:scale:g', NULL, iri_to_id ('urn:graph:scale:w'), 0);
  hops := GRAPH_BFS ('urn:graph:scale:n0', 'urn:graph:scale:n9999', 'urn:graph:scale:g',
            'urn:graph:scale:e');
  if (v is null) return 'no path';
  if (abs (v - 0.5 * hops) > 0.000000001)
    return sprintf ('%.9f <> 0.5 * %d', v, hops);
  return 'AGREE';
}
;
-- L.26: a second call on the same source and weights costs one lookup, not
-- a second traversal -- the weight table is shared between calls as well as
-- the distance vector.
create procedure GSCALE_L26 ()
{
  declare ms int;
  ms := GSCALE_SSSPW ('urn:graph:scale:w');
  if (ms < 0) return 'no path';
  if (ms <= 50) return 'CACHED';
  return sprintf ('repeat call took %d ms', ms);
}
;
-- L.27 - L.30: the weight table resolved into one weight per CSR slot.
--
-- A weighted traversal used to search the table once per relaxed edge, and
-- twice when the lookup is symmetric and the first probe misses -- which
-- on a graph held one direction per edge is every backwards traversal of
-- every edge.  Resolving the table into the CSR's own slot order first
-- turns each relaxation into an indexed load.
--
-- The answers do not change, which is the whole point and also the
-- problem: nothing in a result can show whether the fast path ran.  So
-- L27 asserts on the counters GRAPH_CACHE_STATUS reports, and L28 runs
-- the same question down both paths and demands they agree exactly.
--
-- THE WEIGHTS HAVE TO VARY.  L24-L26 above weigh every edge 0.5, and a
-- uniform weight cannot see a weight attributed to the wrong edge -- which
-- is exactly the mistake this pair of arrays makes easy, because the
-- neighbour iterator counts slots within one vertex's row while the arrays
-- are indexed across the whole CSR.  So these weigh the ring family alone,
-- with a weight that depends on the edge, and leave the two chord families
-- unweighted so the default-weight and double-miss paths are exercised
-- too.
create procedure GSCALE_WEIGH_VAR (in pred varchar)
{
  declare i, pid, sid, oid, tgt int;
  pid := iri_id_num (iri_to_id ('urn:graph:scale:e'));
  for (i := 0; i < 20000; i := i + 1)
    {
      tgt := mod (i + 1, 20000);
      sid := iri_id_num (iri_to_id (sprintf ('urn:graph:scale:n%d', i)));
      oid := iri_id_num (iri_to_id (sprintf ('urn:graph:scale:n%d', tgt)));
      DB.DBA.RDF_QUAD_URI_L ('urn:graph:scale:g',
        sprintf ('urn:rdf-star:reifier:%d:%d:i%d', sid, pid, oid), pred,
        1.0 + 0.125 * mod (i * 3, 7));
      if (mod (i, 5000) = 0) commit work;
    }
  commit work;
  return 20000;
}
;

-- Rewrite every ring weight, so the same query has a different answer.
create procedure GSCALE_REWEIGH (in pred varchar, in w double precision)
{
  declare i, pid, sid, oid, tgt int;
  declare gid, pidi IRI_ID;
  gid := iri_to_id ('urn:graph:scale:g');
  pidi := iri_to_id (pred);
  pid := iri_id_num (iri_to_id ('urn:graph:scale:e'));
  delete from DB.DBA.RDF_QUAD where G = gid and P = pidi;
  commit work;
  for (i := 0; i < 20000; i := i + 1)
    {
      tgt := mod (i + 1, 20000);
      sid := iri_id_num (iri_to_id (sprintf ('urn:graph:scale:n%d', i)));
      oid := iri_id_num (iri_to_id (sprintf ('urn:graph:scale:n%d', tgt)));
      DB.DBA.RDF_QUAD_URI_L ('urn:graph:scale:g',
        sprintf ('urn:rdf-star:reifier:%d:%d:i%d', sid, pid, oid), pred, w);
      if (mod (i, 5000) = 0) commit work;
    }
  commit work;
  return 20000;
}
;

-- One counter out of GRAPH_CACHE_STATUS.  test_graph_cache.sql has the
-- same helper, but it runs after this file.
create procedure GSCALE_STAT (in nam varchar)
{
  declare v any;
  declare i int;
  v := GRAPH_CACHE_STATUS ();
  for (i := 0; i < length (v); i := i + 2)
    if (v[i] = nam)
      return v[i + 1];
  return -1;
}
;

-- Weighted distances from n0 to a spread of targets, as one string, so a
-- difference anywhere shows up as a difference in the whole vector.  17
-- decimals is more than a double carries, so string equality here is
-- equality of the doubles.
create procedure GSCALE_DISTVEC (in pred varchar, in dir int, in ntargets int)
{
  declare i int;
  declare s varchar;
  declare v double precision;
  s := '';
  for (i := 0; i < ntargets; i := i + 1)
    {
      v := GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:graph:scale:n0',
             sprintf ('urn:graph:scale:n%d', mod (i * 37, 20000)),
             'urn:graph:scale:g', NULL, iri_to_id (pred), dir);
      s := s || case when v is null then 'x' else sprintf ('%.17f', v) end || ' ';
    }
  return s;
}
;

-- L.27: the arrays are built, and reused rather than rebuilt.  A second
-- traversal from a DIFFERENT source is what asks for them again -- a
-- repeat of the same source never reaches the algorithm at all, because
-- the distance vector itself is cached.
create procedure GSCALE_L27 ()
{
  declare b0, b1, h0, h1 int;
  declare v double precision;
  GSCALE_WEIGH_VAR ('urn:graph:scale:wvar');
  GSCALE_WEIGH_VAR ('urn:graph:scale:wvar2');
  GRAPH_SET_LIMIT ('EdgeWeightArray', 1);
  b0 := GSCALE_STAT ('edge_weight_builds');
  h0 := GSCALE_STAT ('edge_weight_hits');
  v := GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:graph:scale:n0', 'urn:graph:scale:n37',
         'urn:graph:scale:g', NULL, iri_to_id ('urn:graph:scale:wvar'), 2);
  b1 := GSCALE_STAT ('edge_weight_builds');
  v := GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:graph:scale:n1', 'urn:graph:scale:n37',
         'urn:graph:scale:g', NULL, iri_to_id ('urn:graph:scale:wvar'), 2);
  h1 := GSCALE_STAT ('edge_weight_hits');
  if (b1 <= b0) return sprintf ('no array was built (%d -> %d)', b0, b1);
  if (h1 <= h0) return sprintf ('rebuilt rather than reused (%d -> %d)', h0, h1);
  return 'RESOLVED';
}
;

-- L.28: the two paths agree exactly.  wvar and wvar2 carry identical
-- weights, so the distances must be identical; they are different
-- predicates so that the second run is a fresh computation rather than the
-- first one's cached distance vector.
create procedure GSCALE_L28 (in dir int)
{
  declare a, b varchar;
  GRAPH_SET_LIMIT ('EdgeWeightArray', 1);
  a := GSCALE_DISTVEC ('urn:graph:scale:wvar', dir, 120);
  GRAPH_SET_LIMIT ('EdgeWeightArray', 0);
  b := GSCALE_DISTVEC ('urn:graph:scale:wvar2', dir, 120);
  GRAPH_SET_LIMIT ('EdgeWeightArray', 1);
  if (a = b) return 'AGREE';
  return 'the resolved array and the table lookup disagree';
}
;

-- L.29: changed weights are not answered out of the cache.  A weight is a
-- write, so it bumps the graph cache's generation and the weight table's
-- with it -- which is also why a resolved array can never outlive the
-- table it came from.  This asserts the whole chain end to end rather
-- than any one link of it.
create procedure GSCALE_L29 ()
{
  declare v0, v1 double precision;
  GRAPH_SET_LIMIT ('EdgeWeightArray', 1);
  v0 := GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:graph:scale:n0', 'urn:graph:scale:n1',
          'urn:graph:scale:g', NULL, iri_to_id ('urn:graph:scale:wvar'), 0);
  GSCALE_REWEIGH ('urn:graph:scale:wvar', 5.0);
  v1 := GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:graph:scale:n0', 'urn:graph:scale:n1',
          'urn:graph:scale:g', NULL, iri_to_id ('urn:graph:scale:wvar'), 0);
  if (v0 is null or v1 is null) return 'no path';
  if (v1 > v0) return 'REVALIDATED';
  return sprintf ('%.9f then %.9f', v0, v1);
}
;

-- L.30: turning the arrays off releases them.  Otherwise a server told to
-- stop spending 16 bytes an edge would keep spending it until the next
-- commit.
create procedure GSCALE_L30 ()
{
  declare by0, by1 int;
  GRAPH_SET_LIMIT ('EdgeWeightArray', 1);
  GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:graph:scale:n2', 'urn:graph:scale:n37',
    'urn:graph:scale:g', NULL, iri_to_id ('urn:graph:scale:wvar'), 2);
  by0 := GSCALE_STAT ('edge_weight_bytes');
  GRAPH_SET_LIMIT ('EdgeWeightArray', 0);
  by1 := GSCALE_STAT ('edge_weight_bytes');
  GRAPH_SET_LIMIT ('EdgeWeightArray', 1);
  if (by0 <= 0) return 'nothing was held';
  if (by1 <> 0) return sprintf ('%d bytes still held', by1);
  return 'RELEASED';
}
;

-- L.32 - L.34: two predicates in one graph, and the index-only neighbour
-- walk.
--
-- The predicate filter is applied when the snapshot is LOADED, in the SQL
-- that reads RDF_QUAD, so every edge in a filtered snapshot already
-- matches and the traversal's own per-edge predicate test can only ever
-- return true.  The traversals therefore skip it and read the neighbour's
-- index out of the array parallel to the adjacency, instead of loading
-- the edge record to read the object out of it: one array instead of two,
-- and no test.
--
-- Nothing in an answer can show which walk ran, so these run the same
-- questions down both -- GRAPH_SET_LIMIT('IndexWalk', 0) forces the
-- general one, and bumps the cache generation so the second run is a
-- fresh computation rather than the first one's cached answer.
--
-- The fixture is a 200-vertex path under `pa`, plus two shortcuts under
-- `pb` that turn a 199-hop walk into a 2-hop one.  So the filter is not
-- decoration: filtered and unfiltered are different graphs with different
-- answers, and L32 is what says so before L33 and L34 compare walks.
create procedure GSCALE_TWOPRED ()
{
  declare i int;
  declare gid IRI_ID;
  gid := iri_to_id ('urn:graph:scale:two');
  delete from DB.DBA.RDF_QUAD where G = gid;
  commit work;
  for (i := 0; i < 199; i := i + 1)
    DB.DBA.RDF_QUAD_URI ('urn:graph:scale:two', sprintf ('urn:graph:scale:t%d', i),
      'urn:graph:scale:pa', sprintf ('urn:graph:scale:t%d', i + 1));
  DB.DBA.RDF_QUAD_URI ('urn:graph:scale:two', 'urn:graph:scale:t0',
    'urn:graph:scale:pb', 'urn:graph:scale:t100');
  DB.DBA.RDF_QUAD_URI ('urn:graph:scale:two', 'urn:graph:scale:t100',
    'urn:graph:scale:pb', 'urn:graph:scale:t199');
  commit work;
  return 201;
}
;

-- BFS depths from t0 to every twentieth vertex, and the two connectivity
-- answers, as one string.  `pred` NULL means load every predicate.
create procedure GSCALE_TWOPRED_VEC (in pred varchar)
{
  declare i, d int;
  declare s varchar;
  s := '';
  for (i := 0; i < 200; i := i + 20)
    {
      if (pred is null)
        d := GRAPH_BFS ('urn:graph:scale:t0', sprintf ('urn:graph:scale:t%d', i),
               'urn:graph:scale:two');
      else
        d := GRAPH_BFS ('urn:graph:scale:t0', sprintf ('urn:graph:scale:t%d', i),
               'urn:graph:scale:two', pred);
      s := s || cast (d as varchar) || ' ';
    }
  if (pred is null)
    s := s || cast (GRAPH_WCC ('urn:graph:scale:t0', 'urn:graph:scale:two') as varchar)
           || ' ' || cast (GRAPH_DFS ('urn:graph:scale:t0', NULL,
                             'urn:graph:scale:two') as varchar);
  else
    s := s || cast (GRAPH_WCC ('urn:graph:scale:t0', 'urn:graph:scale:two', pred) as varchar)
           || ' ' || cast (GRAPH_DFS ('urn:graph:scale:t0', NULL,
                             'urn:graph:scale:two', pred) as varchar);
  return rtrim (s);
}
;

-- L.32: the filter is real.  Under `pa` alone t199 is 199 hops away;
-- with `pb` loaded as well it is 2.
create procedure GSCALE_L32 ()
{
  declare a, b int;
  GSCALE_TWOPRED ();
  GRAPH_SET_LIMIT ('IndexWalk', 1);
  a := GRAPH_BFS ('urn:graph:scale:t0', 'urn:graph:scale:t199',
         'urn:graph:scale:two', 'urn:graph:scale:pa');
  b := GRAPH_BFS ('urn:graph:scale:t0', 'urn:graph:scale:t199',
         'urn:graph:scale:two');
  if (a = 199 and b = 2) return 'FILTERED';
  return sprintf ('pa-only %d (want 199), all %d (want 2)', a, b);
}
;

-- L.33 - L.34: the two walks agree, filtered and unfiltered.
create procedure GSCALE_L33 (in pred varchar)
{
  declare a, b varchar;
  GRAPH_SET_LIMIT ('IndexWalk', 1);
  a := GSCALE_TWOPRED_VEC (pred);
  GRAPH_SET_LIMIT ('IndexWalk', 0);
  b := GSCALE_TWOPRED_VEC (pred);
  GRAPH_SET_LIMIT ('IndexWalk', 1);
  if (a = b) return 'AGREE';
  return 'index-only walk ' || a || ' <> general walk ' || b;
}
;

-- L.35: depth-first search on a high-degree vertex is linear in its edges.
--
-- The iterative DFS keeps, per vertex, a count of how many of its edges
-- it has dealt with, and used to re-walk that many from the start every
-- time it returned to the vertex.  A vertex of degree d is returned to up
-- to d times, so that is O(d*d) for one vertex -- invisible on the graphs
-- above, where the maximum degree is 3, and quadratic on a power-law
-- graph, where one hub can carry a large fraction of the edges.
--
-- A star is the extreme case and the cheapest to build: one vertex of
-- degree n and nothing else.  Measured on one machine with the re-walk
-- in place, DFS from the hub took 68 ms at 8,000 spokes, 270 at 16,000
-- and 1,079 at 32,000 -- four times the time for twice the edges, which
-- is the quadratic signature.  With the resume it is 1 ms at every one of
-- those sizes and 2 ms at 64,000.
--
-- So this asserts both shapes: an absolute budget, which the quadratic
-- form misses by 4x on that machine and would miss on one five times
-- slower, and the ratio between two sizes, which is what makes the
-- assertion say "linear" rather than "fast on the machine I wrote it on".
-- SCC has the same re-walk in both of its passes and got the same fix,
-- so it is measured the same way.
create procedure GSCALE_STAR (in n int)
{
  declare i int;
  declare gid IRI_ID;
  gid := iri_to_id ('urn:graph:scale:star');
  delete from DB.DBA.RDF_QUAD where G = gid;
  commit work;
  for (i := 0; i < n; i := i + 1)
    {
      DB.DBA.RDF_QUAD_URI ('urn:graph:scale:star', 'urn:graph:scale:hub',
        'urn:graph:scale:spoke', sprintf ('urn:graph:scale:s%d', i));
      if (mod (i, 5000) = 0) commit work;
    }
  commit work;
  return n;
}
;

-- DFS and SCC on a star of n spokes, with the snapshot warmed first so
-- the timing is the traversal and not the load.
create procedure GSCALE_STARTIME (in n int, in what varchar)
{
  declare t0, ms, r int;
  GSCALE_STAR (n);
  r := GRAPH_WCC ('urn:graph:scale:hub', 'urn:graph:scale:star',
                  'urn:graph:scale:spoke');
  t0 := msec_time ();
  if (what = 'dfs')
    r := GRAPH_DFS ('urn:graph:scale:hub', NULL, 'urn:graph:scale:star',
                    'urn:graph:scale:spoke');
  else
    r := GRAPH_SCC_COUNT ('urn:graph:scale:star', 'urn:graph:scale:spoke');
  ms := msec_time () - t0;
  if (r <> n + 1) return -1;          -- wrong answer, not a slow one
  return ms;
}
;

create procedure GSCALE_L35 (in what varchar)
{
  declare small_ms, big_ms int;
  small_ms := GSCALE_STARTIME (8000, what);
  big_ms := GSCALE_STARTIME (32000, what);
  if (small_ms < 0 or big_ms < 0)
    return what || ' gave the wrong answer';
  -- Four times the edges: linear allows about four times the time, and
  -- the constant covers a size at which the real work is under a
  -- millisecond and the measurement is all noise.
  if (big_ms > 4 * small_ms + 100)
    return sprintf ('%s 8,000 spokes %d ms, 32,000 spokes %d ms',
                    what, small_ms, big_ms);
  if (big_ms > 250)
    return sprintf ('%s at 32,000 spokes took %d ms', what, big_ms);
  return 'LINEAR';
}
;

-- L.37 - L.38: a breadth-first level expanded in parallel.
--
-- A single FIFO queue is already level-ordered, so a level is a
-- contiguous range of it and can be expanded many vertices at a time.
-- What has to survive that is the parent: the answer BFS gives for a
-- vertex two paths reach at the same depth is which of them got there
-- first, and P15/P16 in the conformance suite pin exactly that.
--
-- It survives because only the neighbour reads are divided up.  The claim
-- that sets a parent is made afterwards, serially, sweeping the buffer in
-- frontier order -- which is the order the one-vertex-at-a-time loop
-- visited edges in.  So the answer is identical bit for bit and at any
-- thread count, not merely equivalent, and these assert that rather than
-- assuming it.
create procedure GSCALE_L37 ()
{
  declare c0, c1, w int;
  GRAPH_SET_LIMIT ('ParallelBFS', 1);
  -- A server built or configured with one graph worker has nothing to
  -- divide, and declining is then the right answer rather than a defect.
  -- ThreadsPerQuery is clamped into the graph worker count at BOOT, so a
  -- run-time __dbf_set cannot lift it and the test has to ask.
  w := GSCALE_STAT ('graph_workers');
  if (w < 2) return 'DIVIDED';
  c0 := GSCALE_STAT ('bfs_parallel_chunks');
  GRAPH_BFS ('urn:graph:scale:n0', 'urn:graph:scale:n9999', 'urn:graph:scale:g',
             'urn:graph:scale:e');
  c1 := GSCALE_STAT ('bfs_parallel_chunks');
  if (c1 > c0) return 'DIVIDED';
  return sprintf ('%d workers and no chunk was divided (%d)', w, c1);
}
;

-- Depths from n0 to a spread of targets, plus the reachable count, down
-- both paths.
create procedure GSCALE_BFSVEC ()
{
  declare i int;
  declare s varchar;
  s := '';
  for (i := 0; i < 20000; i := i + 977)
    s := s || cast (GRAPH_BFS ('urn:graph:scale:n0',
                      sprintf ('urn:graph:scale:n%d', i), 'urn:graph:scale:g',
                      'urn:graph:scale:e') as varchar) || ' ';
  s := s || cast (GRAPH_DFS ('urn:graph:scale:n0', NULL, 'urn:graph:scale:g',
                    'urn:graph:scale:e') as varchar);
  return s;
}
;

create procedure GSCALE_L38 ()
{
  declare a, b varchar;
  GRAPH_SET_LIMIT ('ParallelBFS', 1);
  a := GSCALE_BFSVEC ();
  GRAPH_SET_LIMIT ('ParallelBFS', 0);
  b := GSCALE_BFSVEC ();
  GRAPH_SET_LIMIT ('ParallelBFS', 1);
  if (a = b) return 'AGREE';
  return 'divided ' || a || ' <> serial ' || b;
}
;

-- Every procedure above is defined before the first of these runs.
-- CREATE PROCEDURE is a write, and a write bumps the graph cache's
-- invalidation generation, so a definition between two of these
-- assertions would make L26's cache hit a miss.
select GSCALE_L24 ();
ECHO BOTH ": L24 weighted SSSP vs weight-table size = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] FLAT "PASSED" "***FAILED";

select GSCALE_L25 ();
ECHO BOTH ": L25 weighted cost vs hop count = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

select GSCALE_L26 ();
ECHO BOTH ": L26 repeat weighted traversal = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] CACHED "PASSED" "***FAILED";

select GSCALE_L27 ();
ECHO BOTH ": L27 per-slot weights resolved and reused = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] RESOLVED "PASSED" "***FAILED";

select GSCALE_L28 (0);
ECHO BOTH ": L28 resolved == table lookup, outgoing = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

select GSCALE_L28 (2);
ECHO BOTH ": L29 resolved == table lookup, both directions = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

select GSCALE_L30 ();
ECHO BOTH ": L30 turning the arrays off releases them = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] RELEASED "PASSED" "***FAILED";

select GSCALE_L29 ();
ECHO BOTH ": L31 changed weights are recomputed = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] REVALIDATED "PASSED" "***FAILED";

select GSCALE_L32 ();
ECHO BOTH ": L32 the load-time predicate filter is real = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] FILTERED "PASSED" "***FAILED";

select GSCALE_L33 ('urn:graph:scale:pa');
ECHO BOTH ": L33 index-only == general walk, filtered = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

select GSCALE_L33 (NULL);
ECHO BOTH ": L34 index-only == general walk, unfiltered = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

select GSCALE_L35 ('dfs');
ECHO BOTH ": L35 DFS on a high-degree vertex is linear = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] LINEAR "PASSED" "***FAILED";

select GSCALE_L35 ('scc');
ECHO BOTH ": L36 SCC on a high-degree vertex is linear = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] LINEAR "PASSED" "***FAILED";

select GSCALE_L37 ();
ECHO BOTH ": L37 a BFS level was expanded in parallel = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] DIVIDED "PASSED" "***FAILED";

select GSCALE_L38 ();
ECHO BOTH ": L38 divided == serial BFS = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

-- L.39 - L.40: CDLP, LCC and triangle counting agree down both walks.
--
-- These three lived in a file with its own neighbour iterator, which had
-- neither the index-only walk nor the index-keyed row accessors -- so
-- until they were moved onto the shared one, GRAPH_SET_LIMIT('IndexWalk',
-- 0) did nothing to them and L33/L34 were comparing only the traversals.
-- These say the two walks return the same communities, the same
-- coefficients and the same triangle count, rather than merely both
-- returning something.
--
-- LCC is real-valued, so the comparison is of printed values.  The two
-- walks yield a vertex's neighbours in the same order and therefore sum
-- the same doubles in the same order, so exact equality is the right
-- assertion here and a tolerance would hide a reordering.
--
-- Both LCC forms are included.  The undirected one goes through the
-- triangle pass, whose neighbourhood collection re-inits an iterator per
-- neighbour of every vertex; the directed one rebuilds the full
-- neighbourhood and does its own wedge pass.  They are different loops
-- over the same iterator and a conversion can break one and not the
-- other.
-- A fixture with real triangles.  The two-predicate graph above is a path
-- with two shortcuts, so every LCC value on it is zero and an LCC
-- comparison over it would agree no matter what the code did.  This is a
-- 60-vertex ring plus its every-other-vertex chords, which makes each
-- vertex the apex of several triangles, with a second predicate carrying
-- long chords so the filtered comparison is over a different graph than
-- the unfiltered one rather than the same one twice.
create procedure GSCALE_TRIFIX ()
{
  declare i, n int;
  declare gid IRI_ID;
  n := 60;
  gid := iri_to_id ('urn:graph:scale:tri');
  delete from DB.DBA.RDF_QUAD where G = gid;
  commit work;
  for (i := 0; i < n; i := i + 1)
    {
      DB.DBA.RDF_QUAD_URI ('urn:graph:scale:tri', sprintf ('urn:graph:scale:c%d', i),
        'urn:graph:scale:pa', sprintf ('urn:graph:scale:c%d', mod (i + 1, n)));
      DB.DBA.RDF_QUAD_URI ('urn:graph:scale:tri', sprintf ('urn:graph:scale:c%d', i),
        'urn:graph:scale:pa', sprintf ('urn:graph:scale:c%d', mod (i + 2, n)));
      if (mod (i, 7) = 0)
        DB.DBA.RDF_QUAD_URI ('urn:graph:scale:tri', sprintf ('urn:graph:scale:c%d', i),
          'urn:graph:scale:pb', sprintf ('urn:graph:scale:c%d', mod (i + 17, n)));
    }
  commit work;
  return n;
}
;

-- CDLP labels, both LCC forms and the triangle count over one graph, as
-- one string.
create procedure GSCALE_COMM_VEC (in graph varchar, in prefix varchar,
                                  in n int, in pred varchar)
{
  declare i int;
  declare s varchar;
  s := '';
  for (i := 0; i < n; i := i + 5)
    {
      declare nd varchar;
      nd := prefix || cast (i as varchar);
      s := s || cast (GRAPH_LABEL_PROPAGATION (nd, graph, pred) as varchar) || ' '
             || cast (GRAPH_CLUSTERING_COEFFICIENT (nd, graph, pred, 0) as varchar) || ' '
             || cast (GRAPH_CLUSTERING_COEFFICIENT (nd, graph, pred, 1) as varchar) || ' '
             || cast (GRAPH_EIGENVECTOR_CENTRALITY (nd, graph, pred) as varchar) || ' '
             || cast (GRAPH_JACCARD_SIMILARITY (nd, prefix || cast (mod (i + 5, n) as varchar),
                                                graph, pred) as varchar) || ' ';
    }
  s := s || cast (GRAPH_CLUSTERING_COEFFICIENT (graph, pred) as varchar) || ' '
         || cast (GRAPH_TRIANGLE_COUNT (graph, pred) as varchar);
  return rtrim (s);
}
;

create procedure GSCALE_COMM_ALL (in pred varchar)
{
  return GSCALE_COMM_VEC ('urn:graph:scale:two', 'urn:graph:scale:t', 200, pred)
    || ' | ' ||
    GSCALE_COMM_VEC ('urn:graph:scale:tri', 'urn:graph:scale:c', 60, pred);
}
;

create procedure GSCALE_L39 (in pred varchar)
{
  declare a, b varchar;
  GSCALE_TWOPRED ();
  GSCALE_TRIFIX ();
  GRAPH_SET_LIMIT ('IndexWalk', 1);
  a := GSCALE_COMM_ALL (pred);
  GRAPH_SET_LIMIT ('IndexWalk', 0);
  b := GSCALE_COMM_ALL (pred);
  GRAPH_SET_LIMIT ('IndexWalk', 1);
  if (a = b) return 'AGREE';
  return 'index-only walk ' || a || ' <> general walk ' || b;
}
;

select GSCALE_L39 (NULL);
ECHO BOTH ": L39 CDLP/LCC index-only == general walk, unfiltered = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

select GSCALE_L39 ('urn:graph:scale:pa');
ECHO BOTH ": L40 CDLP/LCC index-only == general walk, filtered = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

-- L.41: Jaccard similarity, against values computed by hand.
--
-- Nothing in this suite exercised GRAPH_JACCARD_SIMILARITY or
-- GRAPH_EIGENVECTOR_CENTRALITY before, so converting them to the shared
-- iterator would have been checked by nothing.  L39/L40 now carry
-- eigenvector and Jaccard down both walks, and this pins Jaccard to
-- arithmetic that does not depend on the engine.
--
-- On the ring fixture, over the whole graph and outgoing edges only,
-- which is what this BIF uses:
--   N(c0) = {c1, c2} from the ring chords, plus {c17} from the pb chord
--           that every seventh vertex carries -> 3 neighbours
--   N(c1) = {c2, c3}                                -> 2 neighbours
--   shared = {c2}
--   so J(c0,c1) = 1 / (3 + 2 - 1) = 0.25
-- and a vertex against itself is 1 as long as it has any neighbour.
create procedure GSCALE_L41 ()
{
  declare ab, aa double precision;
  GSCALE_TRIFIX ();
  ab := GRAPH_JACCARD_SIMILARITY ('urn:graph:scale:c0', 'urn:graph:scale:c1',
          'urn:graph:scale:tri');
  aa := GRAPH_JACCARD_SIMILARITY ('urn:graph:scale:c1', 'urn:graph:scale:c1',
          'urn:graph:scale:tri');
  if (abs (ab - 0.25) < 1e-12 and abs (aa - 1.0) < 1e-12) return 'EXACT';
  return sprintf ('J(c0,c1) %f (want 0.25), J(c1,c1) %f (want 1)', ab, aa);
}
;

select GSCALE_L41 ();
ECHO BOTH ": L41 Jaccard similarity matches hand arithmetic = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] EXACT "PASSED" "***FAILED";

-- L.42 - L.44: node ids that are a contiguous run are indexed by
-- subtraction instead of by search.
--
-- The CSR build searches a sorted table of every node id six times per
-- triple to turn subjects and objects into row numbers.  When the ids
-- happen to be contiguous, index is id minus the first id, and the
-- endpoints alone prove that: the table is sorted and deduplicated, so n
-- distinct values spanning exactly n-1 cannot have a gap.  Whether that
-- holds is a property of how a graph was loaded, so it is detected per
-- store and never assumed.
--
-- GRAPH_SET_LIMIT('DenseNodeIndex', 0) forces the search path.  Both give
-- the same answers -- it is the same mapping, computed two ways -- and
-- these say so rather than assuming it.

-- A graph whose node ids are NOT contiguous.  IRIs are interned in
-- first-seen order, so a graph gets a contiguous block unless something
-- else takes ids in between; this mints one throwaway IRI per edge to
-- punch exactly those holes.  Without a fixture like this, every fixture
-- in this file is dense by accident and the fallback is untested code.
create procedure GSCALE_GAPPED (in n int)
{
  declare i int;
  declare gid IRI_ID;
  declare junk IRI_ID;
  gid := iri_to_id ('urn:graph:scale:gap');
  delete from DB.DBA.RDF_QUAD where G = gid;
  commit work;
  for (i := 0; i < n; i := i + 1)
    {
      junk := iri_to_id (sprintf ('urn:graph:scale:hole:%d:%d', i, msec_time ()));
      DB.DBA.RDF_QUAD_URI ('urn:graph:scale:gap', sprintf ('urn:graph:scale:k%d', i),
        'urn:graph:scale:pa', sprintf ('urn:graph:scale:k%d', mod (i + 1, n)));
    }
  commit work;
  return n;
}
;

-- Answers over one graph, as one string: connectivity, a couple of
-- depths, communities and a coefficient.
create procedure GSCALE_DENSE_VEC (in graph varchar, in prefix varchar, in n int)
{
  declare i int;
  declare s varchar;
  s := cast (GRAPH_WCC (prefix || '0', graph) as varchar) || ' ';
  for (i := 0; i < n; i := i + 7)
    s := s || cast (GRAPH_BFS (prefix || '0', prefix || cast (i as varchar), graph) as varchar) || ' '
           || cast (GRAPH_LABEL_PROPAGATION (prefix || cast (i as varchar), graph) as varchar) || ' '
           || cast (GRAPH_CLUSTERING_COEFFICIENT (prefix || cast (i as varchar), graph, NULL, 0) as varchar) || ' ';
  return rtrim (s || cast (GRAPH_TRIANGLE_COUNT (graph) as varchar));
}
;

create procedure GSCALE_DENSE_CNT ()
{
  declare v any; declare i int;
  v := GRAPH_CACHE_STATUS ();
  for (i := 0; i < length (v); i := i + 2)
    if (v[i] = 'dense_node_index') return v[i+1];
  return -1;
}
;

-- Same question down both paths.
create procedure GSCALE_L42 (in graph varchar, in prefix varchar, in n int)
{
  declare a, b varchar;
  GRAPH_SET_LIMIT ('DenseNodeIndex', 1);
  a := GSCALE_DENSE_VEC (graph, prefix, n);
  GRAPH_SET_LIMIT ('DenseNodeIndex', 0);
  b := GSCALE_DENSE_VEC (graph, prefix, n);
  GRAPH_SET_LIMIT ('DenseNodeIndex', 1);
  if (a = b) return 'AGREE';
  return 'dense ' || a || ' <> search ' || b;
}
;

-- And the path was really taken.  Without this a fast path that silently
-- declined would pass L42 by agreeing with itself.  The generation bump
-- from GRAPH_SET_LIMIT retires every cached entry, so the count that
-- follows describes only the graph loaded after it.
create procedure GSCALE_L43 ()
{
  declare on_dense, off_dense, on_gap int;
  declare junk varchar;
  GRAPH_SET_LIMIT ('DenseNodeIndex', 1);
  junk := GSCALE_DENSE_VEC ('urn:graph:scale:tri', 'urn:graph:scale:c', 7);
  on_dense := GSCALE_DENSE_CNT ();
  GRAPH_SET_LIMIT ('DenseNodeIndex', 0);
  junk := GSCALE_DENSE_VEC ('urn:graph:scale:tri', 'urn:graph:scale:c', 7);
  off_dense := GSCALE_DENSE_CNT ();
  GRAPH_SET_LIMIT ('DenseNodeIndex', 1);
  junk := GSCALE_DENSE_VEC ('urn:graph:scale:gap', 'urn:graph:scale:k', 7);
  on_gap := GSCALE_DENSE_CNT ();
  if (on_dense = 1 and off_dense = 0 and on_gap = 0) return 'DETECTED';
  return sprintf ('contiguous on %d (want 1), contiguous off %d (want 0), gapped on %d (want 0)',
                  on_dense, off_dense, on_gap);
}
;

select GSCALE_GAPPED (60);
ECHO BOTH ": L42 fixture with gaps in its node ids = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 60 "PASSED" "***FAILED";

select GSCALE_L42 ('urn:graph:scale:tri', 'urn:graph:scale:c', 60);
ECHO BOTH ": L43 dense index == search, contiguous ids = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

select GSCALE_L42 ('urn:graph:scale:gap', 'urn:graph:scale:k', 60);
ECHO BOTH ": L44 dense index == search, gapped ids = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

select GSCALE_L43 ();
ECHO BOTH ": L45 the dense path is taken, and only when it applies = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] DETECTED "PASSED" "***FAILED";

-- L.46: the node hash table is not merely bypassed, it is not built.
--
-- With contiguous ids and no pending changes, a snapshot's node map is the
-- base store's own id array and an index is arithmetic, so the open
-- addressing table -- 16 bytes a slot at twice the node count, about 16 MB
-- at 633,432 nodes -- has nothing to answer.  Skipping the probe alone
-- would leave the allocation, the initialisation and the fill.
--
-- Nothing in a result can show this, which is why it is asserted against a
-- counter: zero bytes with the dense path on, more than zero with it off,
-- on the same graph.
create procedure GSCALE_HASH_BYTES ()
{
  declare v any; declare i int;
  v := GRAPH_CACHE_STATUS ();
  for (i := 0; i < length (v); i := i + 2)
    if (v[i] = 'node_hash_bytes') return v[i+1];
  return -1;
}
;

create procedure GSCALE_L46 ()
{
  declare on_b, off_b, gap_b int;
  declare junk varchar;
  GRAPH_SET_LIMIT ('DenseNodeIndex', 1);
  junk := GSCALE_DENSE_VEC ('urn:graph:scale:tri', 'urn:graph:scale:c', 7);
  on_b := GSCALE_HASH_BYTES ();
  GRAPH_SET_LIMIT ('DenseNodeIndex', 0);
  junk := GSCALE_DENSE_VEC ('urn:graph:scale:tri', 'urn:graph:scale:c', 7);
  off_b := GSCALE_HASH_BYTES ();
  -- and a graph whose ids have gaps keeps its table even with the flag on
  GRAPH_SET_LIMIT ('DenseNodeIndex', 1);
  junk := GSCALE_DENSE_VEC ('urn:graph:scale:gap', 'urn:graph:scale:k', 7);
  gap_b := GSCALE_HASH_BYTES ();
  if (on_b = 0 and off_b > 0 and gap_b > 0) return 'NOT BUILT';
  return sprintf ('contiguous on %d (want 0), contiguous off %d (want >0), gapped on %d (want >0)',
                  on_b, off_b, gap_b);
}
;

select GSCALE_L46 ();
ECHO BOTH ": L46 the node hash table is not built when ids are contiguous = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "NOT BUILT" "PASSED" "***FAILED";

create table DB.DBA.GSCALE_TBL (S IRI_ID, O IRI_ID)
;
GRANT SELECT ON DB.DBA.GSCALE_TBL TO SPARQL_SELECT;

-- L.47 - L.49: a graph loaded from a SQL table.
--
-- Loading 4,000,000 real edges into a two-column table with the stock
-- vectored CSV loader takes 4.85 s across four connections; the same edges
-- through the RDF loader take 57.9 s.  Not because RDF is slow -- the same
-- edges without their weights load faster per row as triples than as table
-- rows -- but because a weighted edge is three rows in RDF and one in a
-- table.  GRAPH_LOAD_TABLE reads them from where they already are.
--
-- The whole correctness argument for the feature is that the source of the
-- edges cannot change the answer.  L47 is that argument: the same edges,
-- once as RDF and once as a table, through every algorithm, compared as
-- printed values.

create procedure GSCALE_TBLFIX (in n int)
{
  declare i int;
  declare gid IRI_ID;
  -- the RDF copy
  gid := iri_to_id ('urn:graph:scale:tblrdf');
  delete from DB.DBA.RDF_QUAD where G = gid;
  commit work;
  for (i := 0; i < n; i := i + 1)
    {
      DB.DBA.RDF_QUAD_URI ('urn:graph:scale:tblrdf', sprintf ('urn:graph:scale:m%d', i),
        'urn:graph:scale:pa', sprintf ('urn:graph:scale:m%d', mod (i + 1, n)));
      DB.DBA.RDF_QUAD_URI ('urn:graph:scale:tblrdf', sprintf ('urn:graph:scale:m%d', i),
        'urn:graph:scale:pa', sprintf ('urn:graph:scale:m%d', mod (i + 2, n)));
    }
  commit work;
  -- the table copy: the same node ids, so the two graphs are the same graph
  delete from DB.DBA.GSCALE_TBL;
  commit work;
  for (i := 0; i < n; i := i + 1)
    {
      insert into DB.DBA.GSCALE_TBL (S, O)
        values (iri_to_id (sprintf ('urn:graph:scale:m%d', i)),
                iri_to_id (sprintf ('urn:graph:scale:m%d', mod (i + 1, n))));
      insert into DB.DBA.GSCALE_TBL (S, O)
        values (iri_to_id (sprintf ('urn:graph:scale:m%d', i)),
                iri_to_id (sprintf ('urn:graph:scale:m%d', mod (i + 2, n))));
    }
  commit work;
  return n;
}
;

-- Everything the engine can say about one graph, as one string.
create procedure GSCALE_ALLALGO (in graph varchar, in pred varchar, in n int)
{
  declare i int;
  declare s varchar;
  s := '';
  for (i := 0; i < n; i := i + 3)
    {
      declare nd varchar;
      nd := sprintf ('urn:graph:scale:m%d', i);
      s := s || cast (GRAPH_BFS ('urn:graph:scale:m0', nd, graph, pred) as varchar) || ' '
             || cast (GRAPH_WCC (nd, graph, pred) as varchar) || ' '
             || cast (GRAPH_PAGERANK (nd, graph, pred) as varchar) || ' '
             || cast (GRAPH_LABEL_PROPAGATION (nd, graph, pred) as varchar) || ' '
             || cast (GRAPH_CLUSTERING_COEFFICIENT (nd, graph, pred, 0) as varchar) || ' '
             || cast (GRAPH_CLUSTERING_COEFFICIENT (nd, graph, pred, 1) as varchar) || ' '
             || cast (GRAPH_DEGREE_CENTRALITY (nd, graph, pred, 2) as varchar) || ' '
             || cast (GRAPH_EIGENVECTOR_CENTRALITY (nd, graph, pred) as varchar) || ' '
             || cast (GRAPH_CLOSENESS (nd, graph, pred) as varchar) || ' '
             || cast (GRAPH_BETWEENNESS (nd, graph, pred) as varchar) || ' ';
    }
  return rtrim (s || cast (GRAPH_TRIANGLE_COUNT (graph, pred) as varchar) || ' '
                  || cast (GRAPH_WCC_COUNT (graph, pred) as varchar) || ' '
                  || cast (GRAPH_SCC_COUNT (graph, pred) as varchar));
}
;

create procedure GSCALE_L47 ()
{
  declare a, b varchar;
  declare loaded int;
  GSCALE_TBLFIX (40);
  loaded := GRAPH_LOAD_TABLE ('urn:graph:scale:tbl', 'urn:graph:scale:tp',
                              'DB.DBA.GSCALE_TBL');
  if (loaded <> 80) return sprintf ('loaded %d edges, expected 80', loaded);
  a := GSCALE_ALLALGO ('urn:graph:scale:tblrdf', 'urn:graph:scale:pa', 40);
  b := GSCALE_ALLALGO ('urn:graph:scale:tbl', 'urn:graph:scale:tp', 40);
  if (a = b) return 'SAME';
  return 'rdf ' || a || ' <> table ' || b;
}
;

-- L.48: a change to the table is visible on the next call.
--
-- This is what makes the registry load-bearing rather than decorative.
-- Writing to the table retires the cached entry -- the graph cache's
-- generation is bumped by any write, not only by an RDF one -- so the next
-- algorithm call takes the miss path.  Without a record of where the graph
-- came from, that path would scan RDF_QUAD for a graph that was never
-- there and hand back an empty one: not an error, an answer, and only
-- after a cache eviction, so it would look intermittent.
--
-- So this case fails in two different ways depending on what is broken.
-- If the registry is missing, the count after the insert collapses toward
-- zero.  If the reload is not happening at all, it stays at the old value.
create procedure GSCALE_L48 ()
{
  declare before_c, after_c int;
  before_c := GRAPH_TRIANGLE_COUNT ('urn:graph:scale:tbl', 'urn:graph:scale:tp');
  -- close some triangles that were not there
  insert into DB.DBA.GSCALE_TBL (S, O)
    values (iri_to_id ('urn:graph:scale:m0'), iri_to_id ('urn:graph:scale:m3'));
  insert into DB.DBA.GSCALE_TBL (S, O)
    values (iri_to_id ('urn:graph:scale:m5'), iri_to_id ('urn:graph:scale:m8'));
  commit work;
  after_c := GRAPH_TRIANGLE_COUNT ('urn:graph:scale:tbl', 'urn:graph:scale:tp');
  if (before_c > 0 and after_c > before_c) return 'SEES THE CHANGE';
  return sprintf ('before %d, after two new triangles %d (want more, and not zero)',
                  before_c, after_c);
}
;

-- A table name is pasted into SQL text, so it is checked rather than
-- escaped.  Anything that could close the FROM clause is refused before a
-- statement is built.
create procedure GSCALE_L49 ()
{
  declare i, refused int;
  declare names any;
  names := vector ('DB.DBA.GSCALE_TBL where 1=0 --',
                   'GSCALE_TBL; drop table GSCALE_TBL',
                   '"DB"."DBA"."GSCALE_TBL"',
                   'a.b.c.d',
                   '',
                   '1BAD');
  refused := 0;
  for (i := 0; i < length (names); i := i + 1)
    {
      declare st, msg varchar;
      st := '00000';
      exec ('select GRAPH_LOAD_TABLE (''urn:graph:scale:inj'', ''urn:graph:scale:tp'', ?)',
            st, msg, vector (names[i]));
      if (st <> '00000') refused := refused + 1;
    }
  if (refused = length (names)) return 'REFUSED';
  return sprintf ('%d of %d bad table names refused', refused, length (names));
}
;

select GSCALE_L47 ();
ECHO BOTH ": L47 same answers from a table source as from RDF = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] SAME "PASSED" "***FAILED";

select GSCALE_L48 ();
ECHO BOTH ": L48 a change to the source table is seen on the next call = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "SEES THE CHANGE" "PASSED" "***FAILED";

select GSCALE_L49 ();
ECHO BOTH ": L49 a table name that is not an identifier is refused = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] REFUSED "PASSED" "***FAILED";

ECHO BOTH "COMPLETED: graph analytics scale test suite\n";

-- L.50 - L.52: the endpoint index arrays at 4 bytes a slot instead of 8.
--
-- edge_targets and inv_sources hold a node *index*, bounded by the node
-- count rather than by an IRI_ID, and they are the only per-edge arrays
-- the index-only walk reads -- it never loads graph_edge_t at all.  So
-- their width is the width of the hot loop's memory traffic, and at
-- 34,185,747 edges narrowing both from 8 bytes to 4 takes 547 MB to
-- 274 MB.
--
-- Nothing in an answer can see this: it is the same index either way, and
-- the walk yields the same sequence.  GRAPH_SET_LIMIT('NarrowEdgeIndex',
-- 0) forces the wide arrays so the two can be compared at all, and these
-- three cases are what say the narrow ones are taken, are the size they
-- claim, and give the same answers.
create procedure GSCALE_NARROW_CNT ()
{
  declare v any; declare i int;
  v := GRAPH_CACHE_STATUS ();
  for (i := 0; i < length (v); i := i + 2)
    if (v[i] = 'narrow_edge_index') return v[i+1];
  return -1;
}
;

create procedure GSCALE_IXBYTES ()
{
  declare v any; declare i int;
  v := GRAPH_CACHE_STATUS ();
  for (i := 0; i < length (v); i := i + 2)
    if (v[i] = 'edge_index_bytes') return v[i+1];
  return -1;
}
;

-- Same question at both widths.  Run over the gapped graph as well as the
-- contiguous one: with gaps the store takes the search path for node
-- lookups and the walk reads the slices through the general loop rather
-- than the index-only one, which is a different pair of read sites.
create procedure GSCALE_L50 (in graph varchar, in prefix varchar, in n int)
{
  declare a, b varchar;
  GRAPH_SET_LIMIT ('NarrowEdgeIndex', 1);
  a := GSCALE_DENSE_VEC (graph, prefix, n);
  GRAPH_SET_LIMIT ('NarrowEdgeIndex', 0);
  b := GSCALE_DENSE_VEC (graph, prefix, n);
  GRAPH_SET_LIMIT ('NarrowEdgeIndex', 1);
  if (a = b) return 'AGREE';
  return 'narrow ' || a || ' <> wide ' || b;
}
;

-- The width was really chosen.  Without this, arrays that quietly stayed
-- 8 bytes wide would pass L50 by agreeing with themselves.
create procedure GSCALE_L51 ()
{
  declare on_n, off_n int;
  declare junk varchar;
  GRAPH_SET_LIMIT ('NarrowEdgeIndex', 1);
  junk := GSCALE_DENSE_VEC ('urn:graph:scale:tri', 'urn:graph:scale:c', 7);
  on_n := GSCALE_NARROW_CNT ();
  GRAPH_SET_LIMIT ('NarrowEdgeIndex', 0);
  junk := GSCALE_DENSE_VEC ('urn:graph:scale:tri', 'urn:graph:scale:c', 7);
  off_n := GSCALE_NARROW_CNT ();
  GRAPH_SET_LIMIT ('NarrowEdgeIndex', 1);
  if (on_n = 1 and off_n = 0) return 'NARROWED';
  return sprintf ('narrow on %d (want 1), narrow off %d (want 0)', on_n, off_n);
}
;

-- And it is exactly half the bytes, not merely fewer.  Same graph, same
-- edge capacity, both CSR directions -- so the ratio is 2 by arithmetic
-- and any other value means one of the two arrays kept its old width.
create procedure GSCALE_L52 ()
{
  declare on_b, off_b int;
  declare junk varchar;
  GRAPH_SET_LIMIT ('NarrowEdgeIndex', 1);
  junk := GSCALE_DENSE_VEC ('urn:graph:scale:tri', 'urn:graph:scale:c', 7);
  on_b := GSCALE_IXBYTES ();
  GRAPH_SET_LIMIT ('NarrowEdgeIndex', 0);
  junk := GSCALE_DENSE_VEC ('urn:graph:scale:tri', 'urn:graph:scale:c', 7);
  off_b := GSCALE_IXBYTES ();
  GRAPH_SET_LIMIT ('NarrowEdgeIndex', 1);
  if (on_b > 0 and off_b = on_b * 2) return 'HALVED';
  return sprintf ('narrow %d bytes, wide %d bytes (want exactly twice)', on_b, off_b);
}
;

select GSCALE_L50 ('urn:graph:scale:tri', 'urn:graph:scale:c', 60);
ECHO BOTH ": L50 narrow index == wide index, contiguous ids = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

select GSCALE_L50 ('urn:graph:scale:gap', 'urn:graph:scale:k', 60);
ECHO BOTH ": L51 narrow index == wide index, gapped ids = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

select GSCALE_L51 ();
ECHO BOTH ": L52 the narrow width is taken when it applies = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] NARROWED "PASSED" "***FAILED";

select GSCALE_L52 ();
ECHO BOTH ": L53 the index arrays are exactly half the bytes = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] HALVED "PASSED" "***FAILED";

-- L.54 - L.57: no per-edge records when every edge carries one predicate.
--
-- With the predicate gone there is nothing left in a record: a slot's
-- object is node_ids[edge_targets[at]] exactly, because that index was
-- resolved from that object against the same sorted table when the CSR
-- was built.  So both record arrays go, which is 32 of the 40 bytes an
-- edge -- at 34,185,747 edges, 1.09 GB of 1.37 GB.
--
-- A snapshot loaded under a predicate filter has one predicate by
-- construction.  graph_compact() does not rely on that, though: it counts
-- the predicates it actually sees, so an unfiltered load of a graph that
-- happens to hold one gets the same treatment -- and an unfiltered load
-- of the two-predicate fixture must NOT, which is what L55 is for.
--
-- GRAPH_SET_LIMIT('OnePredStore', 0) keeps the records, and is the only
-- way to ask one question of both shapes.
create procedure GSCALE_OPRED_CNT ()
{
  declare v any; declare i int;
  v := GRAPH_CACHE_STATUS ();
  for (i := 0; i < length (v); i := i + 2)
    if (v[i] = 'one_pred_store') return v[i+1];
  return -1;
}
;

create procedure GSCALE_RECBYTES ()
{
  declare v any; declare i int;
  v := GRAPH_CACHE_STATUS ();
  for (i := 0; i < length (v); i := i + 2)
    if (v[i] = 'edge_record_bytes') return v[i+1];
  return -1;
}
;

-- Same question with the records and without them.  `pred` non-NULL is a
-- filtered load of the two-predicate graph, so the records go; NULL loads
-- both predicates, so they stay -- and either way the answers are the
-- answers.
create procedure GSCALE_L54 (in pred varchar)
{
  declare a, b varchar;
  GRAPH_SET_LIMIT ('OnePredStore', 1);
  a := GSCALE_TWOPRED_VEC (pred);
  GRAPH_SET_LIMIT ('OnePredStore', 0);
  b := GSCALE_TWOPRED_VEC (pred);
  GRAPH_SET_LIMIT ('OnePredStore', 1);
  if (a = b) return 'AGREE';
  return 'no-records ' || a || ' <> records ' || b;
}
;

-- The records were really dropped, and only where they may be.  Without
-- this a store that quietly kept them would pass L54 by agreeing with
-- itself, and a store that dropped them on a two-predicate graph would
-- answer with one predicate's edges weighed as another's.
create procedure GSCALE_L55 ()
{
  declare filt_on, filt_off, unfilt_on int;
  declare junk varchar;
  GRAPH_SET_LIMIT ('OnePredStore', 1);
  junk := GSCALE_TWOPRED_VEC ('urn:graph:scale:pa');
  filt_on := GSCALE_OPRED_CNT ();
  GRAPH_SET_LIMIT ('OnePredStore', 0);
  junk := GSCALE_TWOPRED_VEC ('urn:graph:scale:pa');
  filt_off := GSCALE_OPRED_CNT ();
  GRAPH_SET_LIMIT ('OnePredStore', 1);
  junk := GSCALE_TWOPRED_VEC (NULL);
  unfilt_on := GSCALE_OPRED_CNT ();
  if (filt_on = 1 and filt_off = 0 and unfilt_on = 0) return 'DROPPED';
  return sprintf ('filtered on %d (want 1), filtered off %d (want 0), unfiltered on %d (want 0)',
                  filt_on, filt_off, unfilt_on);
}
;

-- And the bytes are gone rather than merely unread: zero record bytes on
-- a filtered load, and the whole of what the records cost is the whole of
-- what the snapshot's memory drops by.
create procedure GSCALE_MEMBYTES ()
{
  declare v any; declare i int;
  v := GRAPH_CACHE_STATUS ();
  for (i := 0; i < length (v); i := i + 2)
    if (v[i] = 'memory_bytes') return v[i+1];
  return -1;
}
;

create procedure GSCALE_L56 ()
{
  declare on_r, off_r, on_m, off_m int;
  declare junk varchar;
  GRAPH_SET_LIMIT ('OnePredStore', 1);
  junk := GSCALE_TWOPRED_VEC ('urn:graph:scale:pa');
  on_r := GSCALE_RECBYTES ();
  on_m := GSCALE_MEMBYTES ();
  GRAPH_SET_LIMIT ('OnePredStore', 0);
  junk := GSCALE_TWOPRED_VEC ('urn:graph:scale:pa');
  off_r := GSCALE_RECBYTES ();
  off_m := GSCALE_MEMBYTES ();
  GRAPH_SET_LIMIT ('OnePredStore', 1);
  if (on_r = 0 and off_r > 0 and off_m - on_m = off_r) return 'NOT ALLOCATED';
  return sprintf ('record bytes on %d (want 0), off %d (want >0), memory delta %d (want %d)',
                  on_r, off_r, off_m - on_m, off_r);
}
;

select GSCALE_L54 ('urn:graph:scale:pa');
ECHO BOTH ": L54 no records == records, one predicate loaded = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

select GSCALE_L54 (NULL);
ECHO BOTH ": L55 no records == records, both predicates loaded = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

select GSCALE_L55 ();
ECHO BOTH ": L56 the records are dropped, and only where they may be = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] DROPPED "PASSED" "***FAILED";

select GSCALE_L56 ();
ECHO BOTH ": L57 the record bytes are the whole of the memory saved = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "NOT ALLOCATED" "PASSED" "***FAILED";

-- L.58 - L.59: how PageRank's gather reads a row.
--
-- The gather is the O(E) half of PageRank and it was stepping the
-- neighbour iterator once per edge.  Reading each adjacency row as a
-- contiguous run instead -- same terms, same sequence, same association,
-- so the same bits -- is 2.31x at 34,185,747 edges, and that is
-- GRAPH_SET_LIMIT('PageRankGather', 1), the default.  Mode 2 adds four
-- independent accumulators so four dependent add chains overlap, which is
-- a further 1.22x and is NOT bit-identical: floating-point addition is not
-- associative, so partial sums formed in a different order round
-- differently.  Mode 0 is the original, kept because it is the only thing
-- mode 1 can be checked against.
--
-- So L58 demands mode 1 equal mode 0 to the last digit -- that is the
-- entire claim, and if it fails the default is wrong -- while L59 only
-- demands mode 2 agree to 1e-9, which is the tolerance a reported score
-- is compared at.
create procedure GSCALE_PR_VEC (in graph varchar, in prefix varchar, in n int)
{
  declare i int;
  declare s varchar;
  s := '';
  for (i := 0; i < n; i := i + 7)
    s := s || sprintf ('%.17g ',
           GRAPH_PAGERANK (prefix || cast (i as varchar), graph, NULL, 0.85, 40, 1e-12));
  return rtrim (s);
}
;

create procedure GSCALE_PR_MAXDIFF (in a varchar, in b varchar)
{
  declare va, vb any; declare i int; declare worst double precision;
  va := split_and_decode (a, 0, '\0\0 ');
  vb := split_and_decode (b, 0, '\0\0 ');
  if (length (va) <> length (vb)) return 1.0;
  worst := 0.0;
  for (i := 0; i < length (va); i := i + 1)
    {
      declare d double precision;
      d := abs (atof (va[i]) - atof (vb[i]));
      if (d > worst) worst := d;
    }
  return worst;
}
;

create procedure GSCALE_L58 ()
{
  declare a, b varchar;
  GRAPH_SET_LIMIT ('PageRankGather', 0);
  a := GSCALE_PR_VEC ('urn:graph:scale:tri', 'urn:graph:scale:c', 60);
  GRAPH_SET_LIMIT ('PageRankGather', 1);
  b := GSCALE_PR_VEC ('urn:graph:scale:tri', 'urn:graph:scale:c', 60);
  if (a = b) return 'IDENTICAL';
  return 'mode 0 ' || a || ' <> mode 1 ' || b;
}
;

create procedure GSCALE_L59 ()
{
  declare a, b varchar; declare d double precision;
  GRAPH_SET_LIMIT ('PageRankGather', 0);
  a := GSCALE_PR_VEC ('urn:graph:scale:tri', 'urn:graph:scale:c', 60);
  GRAPH_SET_LIMIT ('PageRankGather', 2);
  b := GSCALE_PR_VEC ('urn:graph:scale:tri', 'urn:graph:scale:c', 60);
  GRAPH_SET_LIMIT ('PageRankGather', 1);
  d := GSCALE_PR_MAXDIFF (a, b);
  if (d < 1e-9) return 'WITHIN 1e-9';
  return sprintf ('worst difference %.17g, want < 1e-9', d);
}
;

select GSCALE_L58 ();
ECHO BOTH ": L58 run-at-a-time gather == edge-at-a-time, to the last bit = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] IDENTICAL "PASSED" "***FAILED";

select GSCALE_L59 ();
ECHO BOTH ": L59 four accumulators agree to the reported tolerance = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "WITHIN 1e-9" "PASSED" "***FAILED";

create table DB.DBA.GSCALE_WTBL (S IRI_ID, O IRI_ID, W DOUBLE PRECISION)
;
GRANT SELECT ON DB.DBA.GSCALE_WTBL TO SPARQL_SELECT;

-- L.60 - L.63: weights from a table column instead of out of RDF.
--
-- A weighted edge in RDF is three triples -- the edge, a reifier, and the
-- weight on the reifier -- and reading the weights back means
-- materialising a reifier IRI from an id and parsing the ids out of the
-- string again, once per edge, through a cursor.  At 34,185,747 edges that
-- scan is about 110 s.  From a column it is one scan of one table.
--
-- So GRAPH_LOAD_TABLE takes a fourth argument naming the weight column,
-- and the weighted algorithms take their weights from it.  The correctness
-- argument is the same as L47's and this is the weighted half of it: the
-- same edges with the same weights, once as reified RDF and once as a
-- table column, through every weighted algorithm, compared as printed
-- values.
--
-- The weights are quarters on purpose.  0.25, 0.5, 0.75 and the rest are
-- exactly representable, so an RDF literal and a DOUBLE PRECISION column
-- hold the same bits and a difference in the last digit means a real
-- disagreement rather than two parsers rounding differently.
create procedure GSCALE_WFIX (in n int)
{
  declare i int;
  declare gid IRI_ID;
  gid := iri_to_id ('urn:graph:scale:wrdf');
  delete from DB.DBA.RDF_QUAD where G = gid;
  delete from DB.DBA.GSCALE_WTBL;
  commit work;
  for (i := 0; i < n; i := i + 1)
    {
      declare src, dst varchar;
      declare w double precision;
      src := sprintf ('urn:graph:scale:n%d', i);
      dst := sprintf ('urn:graph:scale:n%d', mod (i + 1, n));
      w := 0.25 * (1 + mod (i, 7));
      -- the RDF copy, with the weight on a W3C reification statement
      DB.DBA.RDF_QUAD_URI ('urn:graph:scale:wrdf', src, 'urn:graph:scale:pa', dst);
      DB.DBA.RDF_QUAD_URI ('urn:graph:scale:wrdf', sprintf ('urn:graph:scale:r%d', i),
        'http://www.w3.org/1999/02/22-rdf-syntax-ns#subject', src);
      DB.DBA.RDF_QUAD_URI ('urn:graph:scale:wrdf', sprintf ('urn:graph:scale:r%d', i),
        'http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate', 'urn:graph:scale:pa');
      DB.DBA.RDF_QUAD_URI ('urn:graph:scale:wrdf', sprintf ('urn:graph:scale:r%d', i),
        'http://www.w3.org/1999/02/22-rdf-syntax-ns#object', dst);
      DB.DBA.RDF_QUAD_URI_L ('urn:graph:scale:wrdf',
        sprintf ('urn:graph:scale:r%d', i), 'urn:graph:scale:wp', w);
      -- the table copy: the same node ids and the same weight
      insert into DB.DBA.GSCALE_WTBL (S, O, W)
        values (iri_to_id (src), iri_to_id (dst), w);
    }
  commit work;
  return n;
}
;

-- Every weighted answer about one graph, as one string.
create procedure GSCALE_WALGO (in graph varchar, in pred varchar, in n int)
{
  declare i int;
  declare s varchar;
  declare wp IRI_ID;
  wp := iri_to_id ('urn:graph:scale:wp');
  s := '';
  for (i := 0; i < n; i := i + 3)
    {
      declare nd varchar;
      nd := sprintf ('urn:graph:scale:n%d', i);
      s := s || sprintf ('%.17g ', GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED (
                   'urn:graph:scale:n0', nd, graph, pred, wp, 2))
             || sprintf ('%.17g ', GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED (
                   'urn:graph:scale:n0', nd, graph, pred, wp, 0))
             || sprintf ('%.17g ', GRAPH_PAGERANK_WEIGHTED (nd, graph, pred, wp))
             || sprintf ('%.17g ', GRAPH_DEGREE_W_SPARQL (nd, graph, pred, wp))
             || sprintf ('%.17g ', GRAPH_CLOSENESS_WEIGHTED (nd, graph, pred, wp))
             || sprintf ('%.17g ', GRAPH_BETWEENNESS_WEIGHTED (nd, graph, pred, wp))
             || sprintf ('%.17g ', GRAPH_EIGENVECTOR_WEIGHTED (nd, graph, pred, wp));
    }
  return rtrim (s);
}
;

create procedure GSCALE_L60 ()
{
  declare a, b varchar;
  declare loaded int;
  GSCALE_WFIX (40);
  loaded := GRAPH_LOAD_TABLE ('urn:graph:scale:wtbl', 'urn:graph:scale:tp',
                              'DB.DBA.GSCALE_WTBL', 'W');
  if (loaded <> 40) return sprintf ('loaded %d edges, expected 40', loaded);
  a := GSCALE_WALGO ('urn:graph:scale:wrdf', 'urn:graph:scale:pa', 40);
  b := GSCALE_WALGO ('urn:graph:scale:wtbl', 'urn:graph:scale:tp', 40);
  if (a = b) return 'SAME';
  return 'rdf ' || a || ' <> table ' || b;
}
;

-- L.61: the weights are really the column's, and not the default of 1.0.
--
-- Before the column was wired through, a weighted call on a table-sourced
-- graph scanned RDF_QUAD for a weight predicate that was never there,
-- found nothing, and weighed every edge 1.0 -- an answer, not an error.
-- So this case asserts the distance is the sum of the quarters rather than
-- the hop count, which is exactly what that failure would give.
create procedure GSCALE_L61 ()
{
  declare d, hops double precision;
  declare wp IRI_ID;
  wp := iri_to_id ('urn:graph:scale:wp');
  -- n0 -> n1 -> n2 -> n3 costs 0.25 + 0.5 + 0.75
  d := GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:graph:scale:n0',
         'urn:graph:scale:n3', 'urn:graph:scale:wtbl', 'urn:graph:scale:tp', wp, 2);
  hops := GRAPH_BFS ('urn:graph:scale:n0', 'urn:graph:scale:n3',
            'urn:graph:scale:wtbl', 'urn:graph:scale:tp');
  if (d = 1.5 and hops = 3) return 'WEIGHTED';
  return sprintf ('weighted %.17g (want 1.5), hops %.17g (want 3)', d, hops);
}
;

-- L.62: a change to the weight column is visible on the next call, the way
-- a change to the edges is.  The weight table is keyed on the cache
-- generation and any commit bumps it, so this also says the weight table
-- is not being held past the write that invalidates it.
create procedure GSCALE_L62 ()
{
  declare before_d, after_d double precision;
  declare wp IRI_ID;
  wp := iri_to_id ('urn:graph:scale:wp');
  before_d := GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:graph:scale:n0',
                'urn:graph:scale:n3', 'urn:graph:scale:wtbl', 'urn:graph:scale:tp', wp, 2);
  update DB.DBA.GSCALE_WTBL set W = 8.0
    where S = iri_to_id ('urn:graph:scale:n0') and O = iri_to_id ('urn:graph:scale:n1');
  commit work;
  after_d := GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:graph:scale:n0',
               'urn:graph:scale:n3', 'urn:graph:scale:wtbl', 'urn:graph:scale:tp', wp, 2);
  update DB.DBA.GSCALE_WTBL set W = 0.25
    where S = iri_to_id ('urn:graph:scale:n0') and O = iri_to_id ('urn:graph:scale:n1');
  commit work;
  if (before_d = 1.5 and after_d = 9.25) return 'SEES THE CHANGE';
  return sprintf ('before %.17g (want 1.5), after %.17g (want 9.25)',
                  before_d, after_d);
}
;

-- L.63: a weight column name is pasted into SQL text, so it is refused at
-- registration rather than at the first weighted call two statements
-- later, where the error would point at the wrong thing.
create procedure GSCALE_L63 ()
{
  declare bad int;
  declare st, msg varchar;
  st := '00000';
  exec ('select GRAPH_LOAD_TABLE (''urn:graph:scale:badw'', ''urn:graph:scale:tp'', ''DB.DBA.GSCALE_WTBL'', ''W FROM GSCALE_WTBL WHERE 1=1 -- '')',
        st, msg, vector (), 0, null, null);
  if (st <> '00000') return 'REFUSED';
  return 'accepted a column name that closes the FROM clause';
}
;

select GSCALE_L60 ();
ECHO BOTH ": L60 same weighted answers from a table column as from RDF = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] SAME "PASSED" "***FAILED";

select GSCALE_L61 ();
ECHO BOTH ": L61 the weights are the column's, not the default = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] WEIGHTED "PASSED" "***FAILED";

select GSCALE_L62 ();
ECHO BOTH ": L62 a change to the weight column is seen on the next call = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "SEES THE CHANGE" "PASSED" "***FAILED";

select GSCALE_L63 ();
ECHO BOTH ": L63 an unusable weight column name is refused = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] REFUSED "PASSED" "***FAILED";

create table DB.DBA.GSCALE_ONE (S BIGINT, O BIGINT)
;
GRANT SELECT ON DB.DBA.GSCALE_ONE TO SPARQL_SELECT;

-- L.64 - L.65: a node whose id is 1.
--
-- GRAPH_TRIANGLE_COUNT and GRAPH_CLUSTERING_COEFFICIENT each answer about
-- a whole graph or about one node of it, and nothing in the argument types
-- separates the two forms.  The dispatch used to try the first argument as
-- the graph and shift everything along if that did not load -- which
-- decided the question by which load happened to fail, and worked only
-- because an empty graph fails to load.
--
-- The default graph is the exception: the store always has it, and its id
-- is 1.  So a node whose id is 1 resolved as "the default graph" and the
-- call answered the *global* form over an empty graph: zero, silently, for
-- a node with a perfectly good answer.
--
-- Unreachable while node ids were always IRI_IDs, because Virtuoso never
-- hands 1 to a user IRI -- 1 is rdf:type.  Reachable the moment a graph is
-- loaded from a table, where the node ids are whatever is in the column,
-- and a benchmark's vertex numbering starts near 1.
--
-- The fixture is two copies of one graph, the second with every id shifted
-- past the collision.  Any answer that differs between them is the bug.
create procedure GSCALE_ONEFIX ()
{
  declare i int;
  declare e any;
  delete from DB.DBA.GSCALE_ONE;
  commit work;
  -- a triangle 1-2-3 and a tail 3->4, so vertex 1's coefficient is not 0
  e := vector (1, 2, 2, 3, 3, 1, 3, 4, 1, 3);
  for (i := 0; i < length (e); i := i + 2)
    {
      insert into DB.DBA.GSCALE_ONE (S, O) values (e[i], e[i+1]);
      insert into DB.DBA.GSCALE_ONE (S, O)
        values (e[i] + 1000000, e[i+1] + 1000000);
    }
  commit work;
  return length (e) / 2;
}
;

create procedure GSCALE_ONE_VEC (in voff int)
{
  declare i int;
  declare s varchar;
  s := '';
  for (i := 1; i <= 4; i := i + 1)
    s := s || sprintf ('%.17g/%d ',
           GRAPH_CLUSTERING_COEFFICIENT (i + voff, 'urn:graph:scale:one', 'urn:graph:scale:op', 1),
           GRAPH_TRIANGLE_COUNT (i + voff, 'urn:graph:scale:one', 'urn:graph:scale:op'));
  return rtrim (s);
}
;

create procedure GSCALE_L64 ()
{
  declare a, b varchar;
  declare loaded int;
  GSCALE_ONEFIX ();
  -- one graph holding both copies: the shifted ids are a separate
  -- component, so each copy's answers are its own
  loaded := GRAPH_LOAD_TABLE ('urn:graph:scale:one', 'urn:graph:scale:op',
                              'DB.DBA.GSCALE_ONE');
  if (loaded <> 10) return sprintf ('loaded %d edges, expected 10', loaded);
  a := GSCALE_ONE_VEC (0);
  b := GSCALE_ONE_VEC (1000000);
  if (a = b) return 'SAME';
  return 'ids from 1: ' || a || ' <> ids shifted: ' || b;
}
;

-- And the global forms still mean the global forms.  The fix must not turn
-- GRAPH_TRIANGLE_COUNT (graph, pred) into a node lookup, which is the way
-- it could go wrong in the other direction.
create procedure GSCALE_L65 ()
{
  declare tri, dflt, i, per_node int;
  tri := GRAPH_TRIANGLE_COUNT ('urn:graph:scale:one', 'urn:graph:scale:op');
  -- Every triangle contributes three per-node increments, so the global
  -- total is the sum over the per-node counts divided by three.  Asserting
  -- the relation rather than a number is what says the global form is
  -- still the global form: were it to become a node lookup it would return
  -- one vertex's count, which is not a third of the sum.
  per_node := 0;
  for (i := 1; i <= 4; i := i + 1)
    per_node := per_node
      + GRAPH_TRIANGLE_COUNT (i, 'urn:graph:scale:one', 'urn:graph:scale:op')
      + GRAPH_TRIANGLE_COUNT (i + 1000000, 'urn:graph:scale:one', 'urn:graph:scale:op');
  -- and the default graph really is addressable as graph 1, and empty
  dflt := GRAPH_TRIANGLE_COUNT (1, 'urn:graph:scale:op');
  if (tri > 0 and tri = per_node / 3 and dflt = 0) return 'GLOBAL';
  return sprintf ('global %d, sum of per-node %d (want global = sum/3, both > 0), default graph %d (want 0)',
                  tri, per_node, dflt);
}
;

select GSCALE_L64 ();
ECHO BOTH ": L64 a node whose id is 1 is a node, not the default graph = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] SAME "PASSED" "***FAILED";

select GSCALE_L65 ();
ECHO BOTH ": L65 the whole-graph forms still mean the whole graph = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] GLOBAL "PASSED" "***FAILED";

create table DB.DBA.GSCALE_INTV (ID BIGINT PRIMARY KEY)
;
create table DB.DBA.GSCALE_INTE (S BIGINT, O BIGINT)
;
GRANT SELECT ON DB.DBA.GSCALE_INTE TO SPARQL_SELECT;

-- L.66: a set-oriented query over integer node ids.
--
-- A graph loaded from a SQL table takes the column values as its node
-- ids, so a vertex table addressing one holds BIGINTs.  The scalar node
-- resolver has always accepted an integer; the vectored one -- the path a
-- query takes once it has [Graph] MinBatch rows or more, 64 by default --
-- accepted only IRI_IDs and IRI strings.  So the same query answered
-- correctly on a small vertex set and failed on a large one with "node
-- column must contain IRIs or IRI strings": correct below the threshold,
-- an error above it, and nothing in between to warn you.
--
-- Found at 633,432 rows, which is why the fixture here is deliberately
-- over the threshold.  It is a regression guard for an error rather than
-- for a wrong answer, so agreement between the two shapes is the whole of
-- what it can assert -- but the error is what it catches, and the error is
-- what happened.
create procedure GSCALE_INTFIX (in n int)
{
  declare i int;
  delete from DB.DBA.GSCALE_INTV;
  delete from DB.DBA.GSCALE_INTE;
  commit work;
  for (i := 1; i <= n; i := i + 1)
    {
      insert into DB.DBA.GSCALE_INTV (ID) values (i);
      insert into DB.DBA.GSCALE_INTE (S, O)
        values (i, 1 + mod (i, n));
      insert into DB.DBA.GSCALE_INTE (S, O)
        values (i, 1 + mod (i + 1, n));
    }
  commit work;
  return n;
}
;

create procedure GSCALE_L66 ()
{
  declare n, i, batched, scalar_sum, batched_sum int;
  declare loaded int;
  n := 100;                     /* over [Graph] MinBatch, which is 64 */
  GSCALE_INTFIX (n);
  loaded := GRAPH_LOAD_TABLE ('urn:graph:scale:intg', 'urn:graph:scale:ip',
                              'DB.DBA.GSCALE_INTE');
  if (loaded <> 2 * n) return sprintf ('loaded %d edges, expected %d', loaded, 2 * n);
  -- one row at a time, which never reaches the vectored resolver
  scalar_sum := 0;
  for (i := 1; i <= n; i := i + 1)
    scalar_sum := scalar_sum
      + GRAPH_BFS (1, i, 'urn:graph:scale:intg', 'urn:graph:scale:ip', 2);
  -- and all of them in one set-oriented query, which does
  select sum (GRAPH_BFS (1, ID, 'urn:graph:scale:intg', 'urn:graph:scale:ip', 2))
    into batched_sum from DB.DBA.GSCALE_INTV;
  if (scalar_sum > 0 and scalar_sum = batched_sum) return 'AGREE';
  return sprintf ('row at a time %d, set at a time %d', scalar_sum, batched_sum);
}
;

select GSCALE_L66 ();
ECHO BOTH ": L66 integer node ids resolve in a set-oriented query too = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

-- L.67 - L.68: the per-slot weight arrays are reused when nothing has
-- changed, and rebuilt when something has.
--
-- The arrays hold one weight per CSR slot -- 547 MB on the largest graph
-- measured -- and a traversal that cannot have them bisects the weight
-- table instead, which is tens of seconds rather than one. Whether it got
-- them is invisible in the answer, so it is asserted against the counters
-- and nothing else can assert it.
--
-- They used to be keyed on two cache generations: the graph cache entry's
-- and the weight table's. Both are proxies for "has anything been
-- committed since", which is a different question from "is this the same
-- CSR and the same weight table" -- and it is the second question the
-- arrays' validity actually turns on, because they are indexed by slot.
-- They are now keyed on a build id apiece, never handed out twice, so
-- edge_weight_mismatch names what differed rather than what was
-- re-stamped.
create procedure GSCALE_EWSTAT (in nam varchar)
{
  declare v any; declare i int;
  v := GRAPH_CACHE_STATUS ();
  for (i := 0; i < length (v); i := i + 2)
    if (v[i] = nam) return v[i+1];
  return -1;
}
;

create procedure GSCALE_L67 ()
{
  declare b0, h0, b1, h1 int;
  declare d double precision;
  declare wp IRI_ID;
  wp := iri_to_id ('urn:graph:scale:wp');
  -- one weighted call to make the arrays, then a second from a different
  -- source so the distance vector is not simply read back
  d := GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:graph:scale:n0',
         'urn:graph:scale:n5', 'urn:graph:scale:wtbl', 'urn:graph:scale:tp', wp, 2);
  b0 := GSCALE_EWSTAT ('edge_weight_builds');
  h0 := GSCALE_EWSTAT ('edge_weight_hits');
  d := GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:graph:scale:n7',
         'urn:graph:scale:n12', 'urn:graph:scale:wtbl', 'urn:graph:scale:tp', wp, 2);
  b1 := GSCALE_EWSTAT ('edge_weight_builds');
  h1 := GSCALE_EWSTAT ('edge_weight_hits');
  if (b1 = b0 and h1 > h0 and GSCALE_EWSTAT ('edge_weight_mismatch') = 0)
    return 'REUSED';
  return sprintf ('builds %d -> %d (want no change), hits %d -> %d (want more), mismatch %d (want 0)',
                  b0, b1, h0, h1, GSCALE_EWSTAT ('edge_weight_mismatch'));
}
;

-- And the other direction, which is the one that must never be got wrong:
-- a real change to the weights has to rebuild them.  Serving the old
-- arrays here would be a wrong answer, not a slow one.
create procedure GSCALE_L68 ()
{
  declare b0, b1 int;
  declare d0, d1 double precision;
  declare wp IRI_ID;
  wp := iri_to_id ('urn:graph:scale:wp');
  d0 := GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:graph:scale:n0',
          'urn:graph:scale:n2', 'urn:graph:scale:wtbl', 'urn:graph:scale:tp', wp, 2);
  b0 := GSCALE_EWSTAT ('edge_weight_builds');
  update DB.DBA.GSCALE_WTBL set W = 16.0
    where S = iri_to_id ('urn:graph:scale:n0') and O = iri_to_id ('urn:graph:scale:n1');
  commit work;
  d1 := GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:graph:scale:n0',
          'urn:graph:scale:n2', 'urn:graph:scale:wtbl', 'urn:graph:scale:tp', wp, 2);
  b1 := GSCALE_EWSTAT ('edge_weight_builds');
  update DB.DBA.GSCALE_WTBL set W = 0.25
    where S = iri_to_id ('urn:graph:scale:n0') and O = iri_to_id ('urn:graph:scale:n1');
  commit work;
  if (b1 > b0 and d0 = 0.75 and d1 = 16.5) return 'REBUILT';
  return sprintf ('builds %d -> %d (want more), d %.17g -> %.17g (want 0.75 -> 16.5)',
                  b0, b1, d0, d1);
}
;

select GSCALE_L67 ();
ECHO BOTH ": L67 the weight arrays are reused when nothing changed = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] REUSED "PASSED" "***FAILED";

select GSCALE_L68 ();
ECHO BOTH ": L68 and rebuilt when a weight really changed = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] REBUILT "PASSED" "***FAILED";

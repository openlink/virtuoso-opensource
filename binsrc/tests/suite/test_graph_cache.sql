--  test_graph_cache.sql
--
--  Graph analytics: snapshot cache reuse, invalidation and memory bound.
--  Test Group M.
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
--  The snapshot cache used to key on the transaction's write id, which is
--  reassigned at every transaction boundary.  In autocommit -- every isql
--  statement and every SPARQL endpoint query -- that meant a fresh key per
--  statement and a guaranteed miss, so every statement rebuilt the whole
--  graph from RDF_QUAD.  On top of that, the post-commit invalidation hook
--  fired on *every* commit, including the read-only autocommit of a SELECT,
--  which would have defeated any key.
--
--  These assertions are on GRAPH_CACHE_STATUS() counters rather than on
--  wall-clock timings, so they are deterministic on any machine.

ECHO BOTH "STARTED: graph analytics cache test suite\n";

create procedure GCACHE_STAT (in nam varchar)
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

-- A second graph, so cache behaviour can be observed without disturbing
-- <urn:graph:test>.
SPARQL
INSERT INTO <urn:graph:cache:g> {
  <urn:graph:cache:a> <urn:graph:cache:e> <urn:graph:cache:b> .
  <urn:graph:cache:b> <urn:graph:cache:e> <urn:graph:cache:c> .
  <urn:graph:cache:c> <urn:graph:cache:e> <urn:graph:cache:a> .
};
commit work;

-- ============================================================================
-- Group M: the cache survives across statements, and only across the right
-- ones
-- ============================================================================

-- Result slots are reused least-recently-used-first once a range is full,
-- and a slot with readers is never a candidate.  The source-keyed
-- traversals are what make that matter: their key includes the source
-- node, so a workload sweeping sources produces an unbounded number of
-- distinct keys.  Before slots could be reused, the fifth distinct source
-- against one graph found no room and every call after it recomputed.
--
-- Seven sources against the 7-node fixture is more than the reserved range
-- holds, so this has to reuse slots to answer at all.
create procedure GCACHE_M13 ()
{
  declare i, ev0, ev1 int;
  declare names any;
  names := vector ('A', 'B', 'C', 'D', 'E', 'F', 'F2');
  ev0 := GCACHE_STAT ('result_evictions');
  for (i := 0; i < 7; i := i + 1)
    GRAPH_BFS ('urn:graph:test:' || aref (names, i), 'urn:graph:test:E', 'urn:graph:test');
  ev1 := GCACHE_STAT ('result_evictions');
  return case when ev1 > ev0 then 'REUSED'
              else 'no slot was reused (' || cast (ev1 - ev0 as varchar) || ')' end;
}
;

-- ... and reuse must not corrupt what it reuses.  Every source is asked
-- again, through both BIFs that share the traversal, after enough further
-- sources to have evicted its slot.
create procedure GCACHE_M14 ()
{
  declare i, k int;
  declare names any;
  names := vector ('A', 'B', 'C', 'D', 'E', 'F', 'F2');
  for (i := 0; i < 7; i := i + 1)
    for (k := 0; k < 7; k := k + 1)
      {
        declare src, tgt varchar;
        src := 'urn:graph:test:' || aref (names, i);
        tgt := 'urn:graph:test:' || aref (names, k);
        if (GRAPH_BFS (src, tgt, 'urn:graph:test')
            <> GRAPH_SHORTEST_PATH_LENGTH (src, tgt, 'urn:graph:test'))
          return 'MISMATCH ' || src || ' -> ' || tgt;
      }
  return 'CONSISTENT';
}
;

-- The source-keyed results live in their own range, so a sweep of them
-- cannot take the slot an expensive parameter-keyed result is using.
create procedure GCACHE_M15 ()
{
  declare i int;
  declare b0, b1 double precision;
  declare names any;
  names := vector ('A', 'B', 'C', 'D', 'E', 'F', 'F2');
  b0 := GRAPH_BETWEENNESS ('urn:graph:test:C', 'urn:graph:test');
  for (i := 0; i < 7; i := i + 1)
    GRAPH_BFS ('urn:graph:test:' || aref (names, i), 'urn:graph:test:D', 'urn:graph:test');
  b1 := GRAPH_BETWEENNESS ('urn:graph:test:C', 'urn:graph:test');
  return case when b0 = b1 then 'UNDISTURBED'
              else cast (b0 as varchar) || ' <> ' || cast (b1 as varchar) end;
}
;

-- Every helper is created up front: CREATE PROCEDURE is a write, and a
-- write bumps the invalidation generation, so defining a procedure between
-- two assertions would evict the entry the second one is meant to hit.
create procedure GCACHE_M1 ()
{
  declare miss0, miss1 int;
  miss0 := GCACHE_STAT ('misses');
  GRAPH_WCC ('urn:graph:cache:a', 'urn:graph:cache:g');
  miss1 := GCACHE_STAT ('misses');
  return case when miss1 > miss0 then 'MISS' else 'HIT' end;
}
;
create procedure GCACHE_M2 ()
{
  declare hit0, hit1 int;
  hit0 := GCACHE_STAT ('hits');
  GRAPH_WCC ('urn:graph:cache:a', 'urn:graph:cache:g');
  hit1 := GCACHE_STAT ('hits');
  return case when hit1 > hit0 then 'HIT' else 'MISS' end;
}
;
create procedure GCACHE_M4 ()
{
  declare g0, g1 int;
  declare c int;
  g0 := GCACHE_STAT ('generation');
  select count (*) into c from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:graph:cache:g');
  commit work;
  g1 := GCACHE_STAT ('generation');
  return case when g1 = g0 then 'STABLE' else 'BUMPED' end;
}
;
create procedure GCACHE_M5 ()
{
  declare g0, g1 int;
  g0 := GCACHE_STAT ('generation');
  DB.DBA.RDF_QUAD_URI ('urn:graph:cache:g', 'urn:graph:cache:d', 'urn:graph:cache:e', 'urn:graph:cache:a');
  commit work;
  g1 := GCACHE_STAT ('generation');
  return case when g1 > g0 then 'BUMPED' else 'STABLE' end;
}
;
create procedure GCACHE_M7 ()
{
  declare own, after_rollback int;
  DB.DBA.RDF_QUAD_URI ('urn:graph:cache:g', 'urn:graph:cache:z', 'urn:graph:cache:e', 'urn:graph:cache:a');
  own := GRAPH_DEGREE_CENTRALITY ('urn:graph:cache:z', 'urn:graph:cache:g');
  rollback work;
  after_rollback := GRAPH_DEGREE_CENTRALITY ('urn:graph:cache:z', 'urn:graph:cache:g');
  return cast (own as varchar) || '/' || cast (after_rollback as varchar);
}
;
create procedure GCACHE_M11 ()
{
  declare t0, t1, i int;
  declare v any;
  -- warm the snapshot, then time one whole-graph run against 50 more
  v := GRAPH_WCC ('urn:graph:cache:a', 'urn:graph:cache:g');
  t0 := msec_time ();
  v := GRAPH_BETWEENNESS ('urn:graph:cache:a', 'urn:graph:cache:g');
  t0 := msec_time () - t0;
  t1 := msec_time ();
  for (i := 0; i < 50; i := i + 1)
    v := GRAPH_BETWEENNESS ('urn:graph:cache:b', 'urn:graph:cache:g');
  t1 := msec_time () - t1;
  -- 50 further whole-graph queries must not cost 50 whole-graph runs
  return case when t1 <= t0 * 10 + 50 then 'AMORTISED' else 'REPEATED' end;
}
;
create procedure GCACHE_M12 ()
{
  declare a, b int;
  declare p1, p2 double precision;
  -- the same parameters must give the same answer ...
  a := GRAPH_COMMUNITY_ID ('urn:graph:cache:a', 'urn:graph:cache:g', NULL, 1.0);
  b := GRAPH_COMMUNITY_ID ('urn:graph:cache:a', 'urn:graph:cache:g', NULL, 1.0);
  -- ... and different ones must not collide in the result cache
  p1 := GRAPH_PAGERANK ('urn:graph:cache:a', 'urn:graph:cache:g', NULL, 0.5);
  p2 := GRAPH_PAGERANK ('urn:graph:cache:a', 'urn:graph:cache:g', NULL, 0.85);
  return case when a = b and p1 <> p2 then 'KEYED' else 'COLLIDED' end;
}
;
create procedure GCACHE_M8 ()
{
  declare e0, e1, i int;
  e0 := GCACHE_STAT ('entries');
  for (i := 0; i < 20; i := i + 1)
    GRAPH_WCC ('urn:graph:cache:a', 'urn:graph:cache:g');
  e1 := GCACHE_STAT ('entries');
  return case when e1 <= e0 + 1 then 'BOUNDED' else 'GROWING' end;
}
;

-- M.1: first call on a graph is a miss
-- M.16-M.18 fixture.  A table nothing is registered against, so a write to
-- it cannot have changed any cached graph.  Created here with the other
-- helpers because CREATE TABLE is a schema change, and a schema change is
-- exactly the commit the notifier cannot attribute -- doing it between two
-- assertions would retire the entry the second one is meant to hit.
create table DB.DBA.GCACHE_UNRELATED (I integer primary key, V varchar)
;

-- M.16: a commit that wrote only tables no cached graph reads must retire
-- nothing.
--
-- Every committing transaction that changed data used to retire every
-- cached snapshot in the server, because the hook had no way to say what
-- had been written.  A run that writes its results to a table therefore
-- rebuilt the whole graph after every result row.  The generation must not
-- move, the commit must be counted as skipped, and -- the assertion that
-- actually matters -- the next algorithm call must still be a hit.
create procedure GCACHE_M16 ()
{
  declare g0, g1, hit0, hit1, sk0, sk1 int;
  GRAPH_WCC ('urn:graph:cache:a', 'urn:graph:cache:g');   -- warm
  g0 := GCACHE_STAT ('generation');
  sk0 := GCACHE_STAT ('commit_skipped');
  insert into DB.DBA.GCACHE_UNRELATED (I, V) values (1, 'x');
  commit work;
  g1 := GCACHE_STAT ('generation');
  sk1 := GCACHE_STAT ('commit_skipped');
  hit0 := GCACHE_STAT ('hits');
  GRAPH_WCC ('urn:graph:cache:a', 'urn:graph:cache:g');
  hit1 := GCACHE_STAT ('hits');
  if (g1 <> g0)
    return sprintf ('generation moved %d -> %d on an unrelated write', g0, g1);
  if (sk1 <= sk0) return 'the commit was not counted as skipped';
  if (hit1 <= hit0) return 'the entry was retired anyway';
  return 'KEPT';
}
;

-- M.17: and the other direction, which is the one that would be a wrong
-- answer.  A write to RDF_QUAD in the graph's own graph must retire the
-- entry, and the next call must see the new edge.
create procedure GCACHE_M17 ()
{
  declare g0, g1, d0, d1 int;
  d0 := GRAPH_DEGREE_CENTRALITY ('urn:graph:cache:a', 'urn:graph:cache:g', null, 2);
  g0 := GCACHE_STAT ('generation');
  DB.DBA.RDF_QUAD_URI ('urn:graph:cache:g', 'urn:graph:cache:a',
                       'urn:graph:cache:e', 'urn:graph:cache:m17');
  commit work;
  g1 := GCACHE_STAT ('generation');
  d1 := GRAPH_DEGREE_CENTRALITY ('urn:graph:cache:a', 'urn:graph:cache:g', null, 2);
  if (g1 <= g0) return 'an RDF write did not retire the cache';
  if (d1 <> d0 + 1)
    return sprintf ('degree %d -> %d, expected %d', d0, d1, d0 + 1);
  return 'RETIRED';
}
;

-- M.18: the unknown-write path.  A schema change makes no rollback entry
-- that names a table and changes what key ids mean, so the notifier cannot
-- say what was written -- and "I could not tell" has to mean "retire
-- everything", never "skip".
create procedure GCACHE_M18 ()
{
  declare g0, g1, u0, u1 int;
  GRAPH_WCC ('urn:graph:cache:a', 'urn:graph:cache:g');   -- warm
  g0 := GCACHE_STAT ('generation');
  u0 := GCACHE_STAT ('commit_unknown');
  exec ('create table DB.DBA.GCACHE_DDL_PROBE (I integer primary key)');
  commit work;
  g1 := GCACHE_STAT ('generation');
  u1 := GCACHE_STAT ('commit_unknown');
  exec ('drop table DB.DBA.GCACHE_DDL_PROBE');
  commit work;
  if (u1 <= u0) return 'a schema change was reported as attributable';
  if (g1 <= g0) return 'an unattributable commit did not retire the cache';
  return 'RETIRED';
}
;

-- M.19: an entry in continuous use must not be dropped by the TTL.
--
-- expires_at was set once, when the entry was built, and never moved, so
-- a cached graph went exactly [Graph] CacheTTL seconds after it was
-- materialised no matter how hard it was being used -- including in the
-- middle of one statement.  At 34,185,747 edges that meant a
-- single-source sweep stopping to reload the whole graph part way
-- through, which is why one measured traversal ranged over 47 to 78
-- seconds for work that costs about 2.
--
-- The TTL is dropped to 2 seconds here so the boundary can be crossed
-- inside a test.  What is asserted is both halves of what a TTL means: an
-- entry being used across the boundary survives, and an idle one past it
-- still goes.
create procedure GCACHE_M19 ()
{
  declare l0, l1, l2, t0 int;
  declare answer varchar;
  GRAPH_SET_LIMIT ('CacheTTL', 2);
  GRAPH_WCC ('urn:graph:cache:a', 'urn:graph:cache:g');       -- build
  l0 := GCACHE_STAT ('loads');
  -- Keep asking for longer than the TTL.  A tight loop rather than one
  -- call a second: expiry is compared in whole seconds, so a one-second
  -- gap can read as two and cross a two-second TTL on its own.
  t0 := msec_time ();
  while (msec_time () - t0 < 3000)
    GRAPH_WCC ('urn:graph:cache:a', 'urn:graph:cache:g');
  l1 := GCACHE_STAT ('loads');
  -- ... then stop asking for longer than the TTL
  delay (4);
  GRAPH_WCC ('urn:graph:cache:a', 'urn:graph:cache:g');
  l2 := GCACHE_STAT ('loads');
  GRAPH_SET_LIMIT ('CacheTTL', 300);
  if (l1 <> l0)
    answer := sprintf ('an entry in use was reloaded %d time(s)', l1 - l0);
  else if (l2 <= l1)
    answer := 'an idle entry outlived its TTL';
  else
    answer := 'IDLE TIMEOUT';
  return answer;
}
;

-- M.20 fixture: two graphs from two different tables.
create table DB.DBA.GCACHE_TA (S IRI_ID, O IRI_ID)
;
GRANT SELECT ON DB.DBA.GCACHE_TA TO SPARQL_SELECT;
create table DB.DBA.GCACHE_TB (S IRI_ID, O IRI_ID)
;
GRANT SELECT ON DB.DBA.GCACHE_TB TO SPARQL_SELECT;

-- M.20: a write to one graph's source table must not retire the other's.
--
-- Before this, any commit that changed data bumped one global counter and
-- every cached graph in the server went with it -- so loading a second
-- dataset, or writing a result row into a table one graph happens to be
-- built from, threw away every other graph's snapshot too.  The commit
-- notifier now knows which indices were written and the registry knows
-- which graph each source table feeds, so a write to one table retires
-- exactly the graphs registered against that table.
--
-- The second assertion is the whole point and nothing else tests it.
create procedure GCACHE_M20 ()
{
  declare a0, a1, hb0, hb1, pg0, pg1 int;
  insert into DB.DBA.GCACHE_TA (S, O)
    values (iri_to_id ('urn:graph:cache:ta:a'), iri_to_id ('urn:graph:cache:ta:b'));
  insert into DB.DBA.GCACHE_TB (S, O)
    values (iri_to_id ('urn:graph:cache:tb:a'), iri_to_id ('urn:graph:cache:tb:b'));
  commit work;
  GRAPH_LOAD_TABLE ('urn:graph:cache:ta', 'urn:graph:cache:tp', 'DB.DBA.GCACHE_TA');
  GRAPH_LOAD_TABLE ('urn:graph:cache:tb', 'urn:graph:cache:tp', 'DB.DBA.GCACHE_TB');
  a0 := GRAPH_DEGREE_CENTRALITY ('urn:graph:cache:ta:a', 'urn:graph:cache:ta',
                                 'urn:graph:cache:tp', 2);
  GRAPH_DEGREE_CENTRALITY ('urn:graph:cache:tb:a', 'urn:graph:cache:tb',
                           'urn:graph:cache:tp', 2);
  pg0 := GCACHE_STAT ('commit_per_graph');
  hb0 := GCACHE_STAT ('hits');
  -- write to A's table only
  insert into DB.DBA.GCACHE_TA (S, O)
    values (iri_to_id ('urn:graph:cache:ta:a'), iri_to_id ('urn:graph:cache:ta:c'));
  commit work;
  pg1 := GCACHE_STAT ('commit_per_graph');
  -- B must still be a cache hit
  GRAPH_DEGREE_CENTRALITY ('urn:graph:cache:tb:a', 'urn:graph:cache:tb',
                           'urn:graph:cache:tp', 2);
  hb1 := GCACHE_STAT ('hits');
  -- ... and A must see the new edge
  a1 := GRAPH_DEGREE_CENTRALITY ('urn:graph:cache:ta:a', 'urn:graph:cache:ta',
                                 'urn:graph:cache:tp', 2);
  if (pg1 <= pg0) return 'the write was not attributed to one graph';
  if (hb1 <= hb0) return 'the other graph was retired too';
  if (a1 <> a0 + 1)
    return sprintf ('degree in the written graph %d -> %d, expected %d', a0, a1, a0 + 1);
  return 'ONE GRAPH';
}
;

-- M.21: the commit path only collects written keys when there is
-- something cached to invalidate.
--
-- The notifier is installed at server start-up whether or not anyone ever
-- uses graph analytics, so without a gate every write transaction in the
-- database would pay to have its written key set collected -- two mutexes
-- and two hash walks -- for a cache holding nothing.  Measured on a fresh
-- server that had not touched a graph: 169 committing transactions during
-- start-up alone, now 0.
--
-- Only half of that is assertable here, and this file is the reason why:
-- the suite exists to cache graphs, so by the time it runs the gate is
-- open and cannot be brought down again.  What this checks is that the
-- flag is maintained at all -- that something raised it.  The closed case
-- is verified on a fresh server by hand.
create procedure GCACHE_M21 ()
{
  declare g, n0, n1 int;
  GRAPH_WCC ('urn:graph:cache:a', 'urn:graph:cache:g');   -- ensure a cached graph
  g := GCACHE_STAT ('commit_gate');
  if (g <> 1) return sprintf ('gate is %d with a graph cached', g);
  -- ... and with it open, a write really does reach the notifier
  n0 := GCACHE_STAT ('commit_notifies');
  insert into DB.DBA.GCACHE_UNRELATED (I, V) values (21, 'gate');
  commit work;
  n1 := GCACHE_STAT ('commit_notifies');
  if (n1 <= n0) return 'the notifier was not reached through an open gate';
  return 'OPEN';
}
;

-- M.22: hub and authority are two readings of one HITS run.
--
-- They are separate BIFs with separate names, so nothing about the call
-- site says whether the power iteration runs once or twice -- both
-- spellings return the same right answers.  The result-cache counters are
-- what tell them apart: the first call must miss and compute, and the
-- second must be served without computing anything, because the two share
-- a cache key and differ only in which half of the payload they read.
--
-- Asserted on a cold key (a distinct max_iter, so no earlier case in this
-- file can have warmed it) and in both orders, since "hub then authority"
-- hitting would not by itself prove the reverse.
create procedure GCACHE_M22 ()
{
  declare h0, h1, h2, m0, m1, m2 int;
  declare hub, auth double precision;
  -- cold: a max_iter no other case uses, so this key cannot be warm
  m0 := GCACHE_STAT ('result_misses');
  h0 := GCACHE_STAT ('result_hits');
  hub := GRAPH_HITS_HUB ('urn:graph:cache:a', 'urn:graph:cache:g', null, 37);
  m1 := GCACHE_STAT ('result_misses');
  h1 := GCACHE_STAT ('result_hits');
  if (m1 <= m0) return 'the first HITS call did not miss';
  -- the other half of the same key: must not compute again
  auth := GRAPH_HITS_AUTHORITY ('urn:graph:cache:a', 'urn:graph:cache:g', null, 37);
  m2 := GCACHE_STAT ('result_misses');
  h2 := GCACHE_STAT ('result_hits');
  if (m2 <> m1)
    return sprintf ('authority recomputed: %d misses', m2 - m1);
  if (h2 <= h1) return 'authority did not come from the result cache';
  -- and the same in the other order, on a second cold key
  m0 := GCACHE_STAT ('result_misses');
  auth := GRAPH_HITS_AUTHORITY ('urn:graph:cache:a', 'urn:graph:cache:g', null, 38);
  m1 := GCACHE_STAT ('result_misses');
  hub := GRAPH_HITS_HUB ('urn:graph:cache:a', 'urn:graph:cache:g', null, 38);
  m2 := GCACHE_STAT ('result_misses');
  if (m1 <= m0) return 'the first HITS call did not miss (auth first)';
  if (m2 <> m1) return sprintf ('hub recomputed: %d misses', m2 - m1);
  return 'ONE RUN';
}
;

-- M.23: GRAPH_UNLOAD_TABLE takes a table-backed graph back out again.
--
-- Nothing tested it, and the failure it can have is not a wrong number:
-- it drops the registration and retires the snapshot, so a leak or a
-- stale store would show up as memory or as an answer from a graph that
-- no longer has a source, neither of which any value assertion notices.
--
-- Three things have to hold.  It reports whether there was anything to
-- unload, so a second call on the same graph says 0.  The graph stops
-- answering from its table.  And the registration really is gone, which
-- is the part a caller cannot see directly: after unloading, a write to
-- the table it used to be built from must no longer retire anything on
-- its behalf -- commit_per_graph is what counts those.
create procedure GCACHE_M23 ()
{
  declare had1, had2, pg0, pg1, d int;
  -- a graph of its own so the other table cases are undisturbed
  GRAPH_LOAD_TABLE ('urn:graph:cache:tu', 'urn:graph:cache:tp', 'DB.DBA.GCACHE_TA');
  d := GRAPH_DEGREE_CENTRALITY ('urn:graph:cache:ta:a', 'urn:graph:cache:tu',
                                'urn:graph:cache:tp', 2);
  if (d < 1) return sprintf ('loaded graph answered %d', d);

  had1 := GRAPH_UNLOAD_TABLE ('urn:graph:cache:tu');
  if (had1 <> 1) return sprintf ('unload reported %d, wanted 1', had1);

  -- unloading twice is not an error, and the second says there was nothing
  had2 := GRAPH_UNLOAD_TABLE ('urn:graph:cache:tu');
  if (had2 <> 0) return sprintf ('second unload reported %d, wanted 0', had2);

  -- and the table is no longer a source for it: a write there retires
  -- nothing on this graph's behalf
  pg0 := GCACHE_STAT ('commit_per_graph');
  insert into DB.DBA.GCACHE_TA (S, O)
    values (iri_to_id ('urn:graph:cache:ta:a'), iri_to_id ('urn:graph:cache:ta:u'));
  commit work;
  pg1 := GCACHE_STAT ('commit_per_graph');
  -- GCACHE_TA still feeds urn:graph:cache:ta from M.20, so at most that one
  -- graph may be retired -- never two.
  if (pg1 - pg0 > 1)
    return sprintf ('%d graphs retired, wanted at most 1', pg1 - pg0);
  return 'UNLOADED';
}
;

-- M.24: GRAPH_COMMIT_KEYS names the indices a committing transaction wrote.
--
-- This is the evidence the commit gate is argued from -- "a write to a
-- table no cached graph reads retires nothing" is only checkable if the
-- server can say what was written -- and nothing asserted it reported
-- anything at all.  A key id means nothing on its own, so the assertion
-- is that the table a write went to appears, joined back through
-- SYS_KEYS to a name.
create procedure GCACHE_M24 ()
{
  declare v, seen any;
  declare i, n int;
  declare nm varchar;
  GRAPH_COMMIT_KEYS (1);                -- read and reset
  insert into DB.DBA.GCACHE_UNRELATED (I, V) values (24, 'keys');
  commit work;
  v := GRAPH_COMMIT_KEYS ();
  n := length (v);
  if (n = 0) return 'no keys reported for a write that happened';
  seen := 0;
  for (i := 0; i < n; i := i + 2)
    {
      nm := coalesce ((select top 1 KEY_TABLE from DB.DBA.SYS_KEYS where KEY_ID = v[i]), '');
      if (nm like '%GCACHE_UNRELATED%') seen := 1;
    }
  if (seen = 0) return sprintf ('%d keys reported, none of them the table written', n / 2);
  return 'NAMED';
}
;

-- M.25: GRAPH_COMMIT_WHY accounts for every commit the notifier saw.
--
-- The gate may only narrow an invalidation when the written-key list is
-- known to be complete; every other case has to fall back to retiring
-- everything.  GRAPH_COMMIT_WHY is the breakdown of which it was, and an
-- ordinary row write has to land in "complete" -- if it did not, the
-- narrowing that the whole commit-path change rests on would never
-- happen, and nothing else would say so.
create procedure GCACHE_M25 ()
{
  declare v any;
  declare i, n, c0, c1 int;
  declare nm varchar;
  v := GRAPH_COMMIT_WHY ();
  n := length (v);
  if (n = 0) return 'no reasons reported at all';
  c0 := -1;
  for (i := 0; i < n; i := i + 2)
    if (v[i] = 'complete') c0 := v[i + 1];
  if (c0 < 0) return 'no "complete" reason in the breakdown';

  insert into DB.DBA.GCACHE_UNRELATED (I, V) values (25, 'why');
  commit work;

  v := GRAPH_COMMIT_WHY ();
  c1 := -1;
  for (i := 0; i < length (v); i := i + 2)
    if (v[i] = 'complete') c1 := v[i + 1];
  if (c1 <= c0)
    return sprintf ('complete went %d -> %d for an ordinary row write', c0, c1);
  return 'ATTRIBUTED';
}
;

select GCACHE_M1 ();
ECHO BOTH ": M1 first call = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] MISS "PASSED" "***FAILED";

-- M.2: a *separate statement* over the same graph now hits.  This is the
-- regression: it used to miss because the key carried the transaction id.
select GCACHE_M2 ();
ECHO BOTH ": M2 second statement = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] HIT "PASSED" "***FAILED";

-- M.3: ... and it keeps hitting
select GCACHE_M2 ();
ECHO BOTH ": M3 third statement = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] HIT "PASSED" "***FAILED";

-- M.4: a read-only statement must not bump the invalidation generation
select GCACHE_M4 ();
ECHO BOTH ": M4 generation after a read = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] STABLE "PASSED" "***FAILED";

-- M.5: a write must bump it
select GCACHE_M5 ();
ECHO BOTH ": M5 generation after a write = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] BUMPED "PASSED" "***FAILED";

-- M.6: and the next read must see the new edge, not the cached graph
select cast (GRAPH_DEGREE_CENTRALITY ('urn:graph:cache:d', 'urn:graph:cache:g') as integer);
ECHO BOTH ": M6 degree of the new node = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- M.7: an uncommitted writer must not publish its view to other readers.
-- The writer sees its own row; after rollback the committed state is what
-- everyone else still sees.
select GCACHE_M7 ();
ECHO BOTH ": M7 uncommitted/after-rollback degree = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "1/0" "PASSED" "***FAILED";

-- M.8: repeated statements do not grow the cache without bound -- the same
-- key reuses one entry rather than accumulating one per statement
select GCACHE_M8 ();
ECHO BOTH ": M8 entries after 20 calls = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] BOUNDED "PASSED" "***FAILED";

-- M.9: the cache reports a memory figure, so the budget has something to
-- enforce against
select case when GCACHE_STAT ('memory_bytes') > 0 then 'ACCOUNTED' else 'ZERO' end;
ECHO BOTH ": M9 cache memory accounting = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] ACCOUNTED "PASSED" "***FAILED";

-- M.10: GRAPH_CACHE_STATUS is DBA-only
select GRAPH_SEC_STATE ('gtest2', 'select GRAPH_CACHE_STATUS ()');
ECHO BOTH ": M10 GRAPH_CACHE_STATUS as non-dba = " $LAST[1] "\n";
ECHO BOTH $IF $NEQ $LAST[1] 00000 "PASSED" "***FAILED";

-- M.11: the scalar path uses the whole-graph result cache too.  It used to
-- re-run the algorithm on every call, so a query that was not vectored (or
-- whose batch was under [Graph] MinBatch) paid a full Brandes pass per row.
select GCACHE_M11 ();
ECHO BOTH ": M11 repeated whole-graph scalar calls = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AMORTISED "PASSED" "***FAILED";

-- M.12: the result cache is keyed by parameters, so different parameters
-- still produce different answers
select GCACHE_M12 ();
ECHO BOTH ": M12 result cache parameter keying = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] KEYED "PASSED" "***FAILED";

-- M.13: more distinct source-keyed results than the range holds.  The
-- slots have to be reused, and the counter is how that is visible: before
-- reuse existed, a full range meant the lookup gave up and every further
-- call recomputed without caching.
select GCACHE_M13 ();
ECHO BOTH ": M13 result slots reused past the range = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] REUSED "PASSED" "***FAILED";

-- M.14: reuse frees a payload, so it has to be the right one.  Every
-- source is asked again after enough others to have taken its slot, and
-- through both BIFs that read the same cached traversal.
select GCACHE_M14 ();
ECHO BOTH ": M14 answers after slot reuse = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] CONSISTENT "PASSED" "***FAILED";

-- M.15: the two ranges are disjoint, so a source sweep leaves the
-- expensive parameter-keyed results alone
select GCACHE_M15 ();
ECHO BOTH ": M15 betweenness across a source sweep = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] UNDISTURBED "PASSED" "***FAILED";

-- M.16: a write to a table no graph is built from retires nothing
select GCACHE_M16 ();
ECHO BOTH ": M16 cache across an unrelated write = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] KEPT "PASSED" "***FAILED";

-- M.17: ... and a write to the graph's own RDF still does
select GCACHE_M17 ();
ECHO BOTH ": M17 cache across a write to the graph = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] RETIRED "PASSED" "***FAILED";

-- M.18: a commit the notifier cannot attribute retires everything
select GCACHE_M18 ();
ECHO BOTH ": M18 cache across an unattributable commit = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] RETIRED "PASSED" "***FAILED";

-- M.19: the TTL is an idle timeout, not a lifetime
select GCACHE_M19 ();
ECHO BOTH ": M19 TTL across continuous use = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "IDLE TIMEOUT" "PASSED" "***FAILED";

-- M.20: a write to one graph's source table leaves the other graph cached
select GCACHE_M20 ();
ECHO BOTH ": M20 write to one of two table sources = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "ONE GRAPH" "PASSED" "***FAILED";

-- M.21: the commit path is gated on there being something cached
select GCACHE_M21 ();
ECHO BOTH ": M21 commit-path gate with a graph cached = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] OPEN "PASSED" "***FAILED";

-- M.22: one HITS run answers both hub and authority
select GCACHE_M22 ();
ECHO BOTH ": M22 HITS pair from one run = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "ONE RUN" "PASSED" "***FAILED";

-- M.23: a table-backed graph can be taken back out
select GCACHE_M23 ();
ECHO BOTH ": M23 GRAPH_UNLOAD_TABLE = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] UNLOADED "PASSED" "***FAILED";

-- M.24: the notifier names the index a write touched
select GCACHE_M24 ();
ECHO BOTH ": M24 GRAPH_COMMIT_KEYS names the table written = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] NAMED "PASSED" "***FAILED";

-- M.25: and says why it could or could not narrow
select GCACHE_M25 ();
ECHO BOTH ": M25 GRAPH_COMMIT_WHY attributes a row write = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] ATTRIBUTED "PASSED" "***FAILED";

-- ============================================================================
-- Group TX: a transaction with uncommitted writes shares no cache entry
-- ============================================================================
SPARQL PREFIX tx: <urn:gtx:> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT INTO GRAPH <urn:gtx:g> {
  tx:a tx:p tx:b . tx:b tx:p tx:c .
  [] rdf:subject tx:a ; rdf:predicate tx:p ; rdf:object tx:b ; tx:w 1.0 .
  [] rdf:subject tx:b ; rdf:predicate tx:p ; rdf:object tx:c ; tx:w 2.0 .
};
COMMIT WORK;

-- TX.1: each call sees the transaction's latest write.  The snapshot was
-- keyed on the transaction id, which does not change between writes, so the
-- third call was served the second call's graph.
create procedure GCACHE_TX1 ()
{
  declare d1, d2, d3 int;
  d1 := GRAPH_DEGREE_CENTRALITY ('urn:gtx:a', 'urn:gtx:g', 'urn:gtx:p', 2);
  sparql insert into <urn:gtx:g> { <urn:gtx:a> <urn:gtx:p> <urn:gtx:d> };
  d2 := GRAPH_DEGREE_CENTRALITY ('urn:gtx:a', 'urn:gtx:g', 'urn:gtx:p', 2);
  sparql insert into <urn:gtx:g> { <urn:gtx:a> <urn:gtx:p> <urn:gtx:e> };
  d3 := GRAPH_DEGREE_CENTRALITY ('urn:gtx:a', 'urn:gtx:g', 'urn:gtx:p', 2);
  rollback work;
  return sprintf ('%d/%d/%d', d1, d2, d3);
}
;
select GCACHE_TX1 ();
ECHO BOTH ": TX1 degree(a) before and after two uncommitted inserts = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "1/2/3" "PASSED" "***FAILED";

select cast (GRAPH_DEGREE_CENTRALITY ('urn:gtx:a', 'urn:gtx:g', 'urn:gtx:p', 2) as integer);
ECHO BOTH ": TX1 degree(a) after the rollback = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- TX.2: weights read with an uncommitted change in view stay with that
-- transaction.  The weight table was published under the current
-- generation, and a rollback does not move it, so the next caller got the
-- rolled-back weight.  The commit first makes this call the first builder.
create procedure GCACHE_TX2 ()
{
  declare w2 int;
  sparql insert into <urn:gtx:g> { <urn:gtx:x> <urn:gtx:q> <urn:gtx:y> };
  commit work;
  sparql prefix tx: <urn:gtx:> prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
    delete from <urn:gtx:g> { ?r tx:w ?w } insert into <urn:gtx:g> { ?r tx:w 10.0 }
    where { graph <urn:gtx:g> { ?r rdf:subject tx:a ; tx:w ?w } };
  w2 := GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:gtx:a', 'urn:gtx:c', 'urn:gtx:g',
                                              'urn:gtx:p', iri_to_id ('urn:gtx:w'), 0);
  rollback work;
  return w2;
}
;
select GCACHE_TX2 ();
ECHO BOTH ": TX2 weighted a to c, a to b raised to 10 uncommitted = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 12 "PASSED" "***FAILED";

select cast (GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:gtx:a', 'urn:gtx:c', 'urn:gtx:g',
             'urn:gtx:p', iri_to_id ('urn:gtx:w'), 0) as integer);
ECHO BOTH ": TX2 weighted a to c after the rollback = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";

ECHO BOTH "COMPLETED: graph analytics cache test suite\n";

--  test_graph_concurrency.sql
--
--  Graph analytics: concurrent load coordination and enable_qp churn.
--  Test Group N.
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
--  Three things in this area could only be reasoned about, never observed:
--
--    * a caller waiting for another thread to finish materialising the same
--      graph used to wait on an untimed condition variable, so a loader that
--      never published parked every other caller for good;
--
--    * a whole-graph result slot reserved as "being computed" was left that
--      way on some exit paths, and the next caller for the same graph and
--      parameters waited on a computation that would never finish;
--
--    * algorithms size their per-worker scratch from the worker count and
--      then slice their loops by it again later, and the count follows
--      enable_qp, which is settable at run time.
--
--  Concurrency is driven with async queues so that several connections hit
--  the same graph at once from inside one test script.

ECHO BOTH "STARTED: graph analytics concurrency test suite\n";

-- A graph big enough that materialising it is not instant, but small
-- enough to keep the suite quick.
create procedure GCON_MAKE ()
{
  declare i int;
  declare gid IRI_ID;
  gid := iri_to_id ('urn:graph:con:g');
  delete from DB.DBA.RDF_QUAD where G = gid;
  commit work;
  for (i := 0; i < 3000; i := i + 1)
    {
      DB.DBA.RDF_QUAD_URI ('urn:graph:con:g', sprintf ('urn:graph:con:n%d', i),
                           'urn:graph:con:e', sprintf ('urn:graph:con:n%d', mod (i + 1, 3000)));
      DB.DBA.RDF_QUAD_URI ('urn:graph:con:g', sprintf ('urn:graph:con:n%d', i),
                           'urn:graph:con:e', sprintf ('urn:graph:con:n%d', mod (i * 7 + 3, 3000)));
      if (mod (i, 1000) = 0) commit work;
    }
  commit work;
}
;

-- One worker: run a mix of graph algorithms over the shared graph and
-- return a signature of the answers, so divergence between concurrent
-- callers is visible and not just a crash.
create procedure GCON_WORK (in reps int)
{
  declare i int;
  declare sig varchar;
  sig := '';
  for (i := 0; i < reps; i := i + 1)
    {
      sig := cast (GRAPH_DEGREE_CENTRALITY ('urn:graph:con:n0', 'urn:graph:con:g') as varchar)
          || '/' || cast (GRAPH_WCC ('urn:graph:con:n0', 'urn:graph:con:g') as varchar)
          || '/' || cast (GRAPH_TRIANGLE_COUNT ('urn:graph:con:n0', 'urn:graph:con:g') as varchar);
    }
  return sig;
}
;

-- aq_wait() hands back whatever the queued procedure returned, wrapped in
-- a vector when the call produced one; unwrap either shape.
create procedure GCON_VAL (in res any)
{
  if (isarray (res) and not isstring (res))
    {
      if (length (res) > 1) return cast (res[1] as varchar);
      if (length (res) > 0) return cast (res[0] as varchar);
      return '';
    }
  return cast (res as varchar);
}
;

-- Fan the workers out over an async queue, wait for all of them, and
-- report how many agreed with the single-threaded answer.
create procedure GCON_RACE (in n_workers int, in reps int)
{
  declare aq any;
  declare reqs any;
  declare i, agreed int;
  declare expected varchar;
  expected := GCON_WORK (1);
  aq := async_queue (n_workers, 1);
  reqs := make_array (n_workers, 'any');
  for (i := 0; i < n_workers; i := i + 1)
    reqs[i] := aq_request (aq, 'DB.DBA.GCON_WORK', vector (reps));
  agreed := 0;
  for (i := 0; i < n_workers; i := i + 1)
    if (GCON_VAL (aq_wait (aq, reqs[i], 1)) = expected)
      agreed := agreed + 1;
  return cast (agreed as varchar) || '/' || cast (n_workers as varchar);
}
;

GCON_MAKE ();

-- ============================================================================
-- Group N: concurrent callers agree, and nothing wedges
-- ============================================================================

-- N.1: eight connections racing to materialise the same cold graph.  Only
-- one of them loads it; the rest either wait for that load or build their
-- own.  Either way every one of them must produce the same answers.
create procedure GCON_N1 ()
{
  DB.DBA.RDF_QUAD_URI ('urn:graph:con:g', 'urn:graph:con:tick', 'urn:graph:con:e', 'urn:graph:con:n0');
  commit work;   -- invalidate, so the eight racers start from a cold cache
  return GCON_RACE (8, 3);
}
;
select GCON_N1 ();
ECHO BOTH ": N1 cold-start race, workers agreeing = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "8/8" "PASSED" "***FAILED";

-- N.2: the same race against a warm cache, exercising the shared-entry
-- reference counting rather than the load coordination
select GCON_RACE (8, 5);
ECHO BOTH ": N2 warm-cache race, workers agreeing = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "8/8" "PASSED" "***FAILED";

-- N.3: whole-graph algorithms share one result slot per (graph,
-- parameters).  Racing on those must not leave a slot reserved, which
-- would make the next caller wait for a computation that never finishes.
create procedure GCON_WG (in reps int)
{
  declare i int;
  declare sig varchar;
  sig := '';
  for (i := 0; i < reps; i := i + 1)
    sig := cast (GRAPH_PAGERANK ('urn:graph:con:n0', 'urn:graph:con:g') as varchar)
        || '/' || cast (GRAPH_COMMUNITY_ID ('urn:graph:con:n0', 'urn:graph:con:g') as varchar);
  return sig;
}
;
create procedure GCON_N3 ()
{
  declare aq any;
  declare reqs any;
  declare i, agreed int;
  declare expected varchar;
  expected := GCON_WG (1);
  aq := async_queue (8, 1);
  reqs := make_array (8, 'any');
  for (i := 0; i < 8; i := i + 1)
    reqs[i] := aq_request (aq, 'DB.DBA.GCON_WG', vector (3));
  agreed := 0;
  for (i := 0; i < 8; i := i + 1)
    if (GCON_VAL (aq_wait (aq, reqs[i], 1)) = expected)
      agreed := agreed + 1;
  return cast (agreed as varchar) || '/8';
}
;
select GCON_N3 ();
ECHO BOTH ": N3 whole-graph result race = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "8/8" "PASSED" "***FAILED";

-- N.4: ... and the graph is still answerable afterwards.  If a result slot
-- had been left reserved, this call would block rather than return.
select case when GRAPH_PAGERANK ('urn:graph:con:n0', 'urn:graph:con:g') is not null then 1 else 0 end;
ECHO BOTH ": N4 whole-graph query after the race = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- N.5: enable_qp changing under a running workload.  Per-worker scratch is
-- sized from the worker count and the loops are sliced by it, so the count
-- is pinned for the duration of a call; results must not depend on it.
create procedure GCON_N5 ()
{
  declare seq, par varchar;
  __dbf_set ('enable_qp', 1);
  seq := GCON_WORK (2);
  __dbf_set ('enable_qp', 16);
  par := GCON_WORK (2);
  __dbf_set ('enable_qp', 1);
  return case when seq = par then 'IDENTICAL' else seq || ' <> ' || par end;
}
;
select GCON_N5 ();
ECHO BOTH ": N5 enable_qp 1 vs 16 = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] IDENTICAL "PASSED" "***FAILED";

-- N.6: raising enable_qp while calls are in flight must not corrupt
-- anything -- this is the case where the worker count could otherwise grow
-- between sizing the scratch blocks and slicing the loops.
create procedure GCON_N6 ()
{
  declare aq any;
  declare reqs any;
  declare i, agreed int;
  declare expected varchar;
  __dbf_set ('enable_qp', 1);
  expected := GCON_WORK (1);
  aq := async_queue (8, 1);
  reqs := make_array (8, 'any');
  for (i := 0; i < 8; i := i + 1)
    {
      reqs[i] := aq_request (aq, 'DB.DBA.GCON_WORK', vector (4));
      __dbf_set ('enable_qp', case when mod (i, 2) = 0 then 16 else 1 end);
    }
  agreed := 0;
  for (i := 0; i < 8; i := i + 1)
    if (GCON_VAL (aq_wait (aq, reqs[i], 1)) = expected)
      agreed := agreed + 1;
  __dbf_set ('enable_qp', 1);
  return cast (agreed as varchar) || '/8';
}
;
select GCON_N6 ();
ECHO BOTH ": N6 enable_qp churn under load = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "8/8" "PASSED" "***FAILED";

-- N.7: the algorithms added to complete the set, raced the same way.
-- BFS is the interesting one: its result key includes the source node, so
-- it lives in the reserved trailing slots of the result cache rather than
-- competing with PageRank and the rest for the leading ones.  A slot left
-- reserved there would park the next caller for the same source.
create procedure GCON_MIXED (in reps int)
{
  declare i int;
  declare sig varchar;
  sig := '';
  for (i := 0; i < reps; i := i + 1)
    sig := cast (GRAPH_LABEL_PROPAGATION ('urn:graph:con:n0', 'urn:graph:con:g') as varchar)
        || '/' || cast (GRAPH_CLUSTERING_COEFFICIENT ('urn:graph:con:n0', 'urn:graph:con:g') as varchar)
        || '/' || cast (GRAPH_BFS ('urn:graph:con:n0', 'urn:graph:con:n7', 'urn:graph:con:g') as varchar);
  return sig;
}
;
create procedure GCON_N7 ()
{
  declare aq any;
  declare reqs any;
  declare i, agreed int;
  declare expected varchar;
  expected := GCON_MIXED (1);
  aq := async_queue (8, 1);
  reqs := make_array (8, 'any');
  for (i := 0; i < 8; i := i + 1)
    reqs[i] := aq_request (aq, 'DB.DBA.GCON_MIXED', vector (3));
  agreed := 0;
  for (i := 0; i < 8; i := i + 1)
    if (GCON_VAL (aq_wait (aq, reqs[i], 1)) = expected)
      agreed := agreed + 1;
  return cast (agreed as varchar) || '/8';
}
;
select GCON_N7 ();
ECHO BOTH ": N7 CDLP/LCC/BFS race = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "8/8" "PASSED" "***FAILED";

-- N.8: ... and a source-keyed traversal still answers afterwards, from a
-- source no worker used, so it needs a slot rather than a hit.
select case when GRAPH_BFS ('urn:graph:con:n11', 'urn:graph:con:n12', 'urn:graph:con:g') is not null
            then 1 else 0 end;
ECHO BOTH ": N8 traversal after the race = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- N.9: slot reuse under concurrency.  Each worker sweeps its own band of
-- source nodes, so the source-keyed range is far too small to hold them
-- all and slots are being freed and reused throughout -- while other
-- workers are indexing payloads out of the same array.  A slot reused
-- while a reader held it would show up here as a wrong answer or worse.
create procedure GCON_SWEEP (in base int, in reps int)
{
  declare i, r int;
  declare sig varchar;
  sig := '';
  for (r := 0; r < reps; r := r + 1)
    for (i := 0; i < 12; i := i + 1)
      sig := cast (GRAPH_BFS (sprintf ('urn:graph:con:n%d', base + i),
                              'urn:graph:con:n0', 'urn:graph:con:g') as varchar);
  return sig;
}
;
create procedure GCON_N9 ()
{
  declare aq any;
  declare reqs any;
  declare i, agreed int;
  declare expected any;
  aq := async_queue (8, 1);
  reqs := make_array (8, 'any');
  expected := make_array (8, 'any');
  -- Bands differ, so each worker has a different expected answer; take
  -- them single-threaded first.
  for (i := 0; i < 8; i := i + 1)
    aset (expected, i, GCON_SWEEP (i * 12, 1));
  for (i := 0; i < 8; i := i + 1)
    reqs[i] := aq_request (aq, 'DB.DBA.GCON_SWEEP', vector (i * 12, 6));
  agreed := 0;
  for (i := 0; i < 8; i := i + 1)
    if (GCON_VAL (aq_wait (aq, reqs[i], 1)) = aref (expected, i))
      agreed := agreed + 1;
  return cast (agreed as varchar) || '/8';
}
;
select GCON_N9 ();
ECHO BOTH ": N9 concurrent source sweep = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "8/8" "PASSED" "***FAILED";

-- N.10: ... and no slot was left pinned by it.  A reference that is taken
-- and never released would make its slot permanently ineligible for reuse,
-- and after enough of those the range would be full of unreusable slots
-- and every call would recompute.  A sweep that still reuses slots is the
-- evidence that the references were all given back.
-- Local rather than borrowed from test_graph_cache.sql: these files are
-- run in one order today but each should stand on its own.
create procedure GCON_STAT (in nam varchar)
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
create procedure GCON_N10 ()
{
  declare i, ev0, ev1 int;
  ev0 := GCON_STAT ('result_evictions');
  for (i := 0; i < 12; i := i + 1)
    GRAPH_BFS (sprintf ('urn:graph:con:n%d', 500 + i), 'urn:graph:con:n0', 'urn:graph:con:g');
  ev1 := GCON_STAT ('result_evictions');
  return case when ev1 > ev0 then 'STILL REUSING'
              else 'slots pinned: no reuse in 12 fresh sources' end;
}
;
select GCON_N10 ();
ECHO BOTH ": N10 slots still reusable after the race = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "STILL REUSING" "PASSED" "***FAILED";

-- Leave query parallelism as the rest of the suite expects it.
SELECT __dbf_set ('enable_qp', 8);

ECHO BOTH "COMPLETED: graph analytics concurrency test suite\n";

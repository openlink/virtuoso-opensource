--  test_graph.sql
--
--  Graph analytics BIF test suite.
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
--  All queries use the SPARQL prefix so that IRI literals (<urn:...>)
--  work without iri_to_id().
--
--  In SELECT expression position, graph BIFs require the graph IRI as
--  an explicit second argument.  In predicate position (Groups D/E/F),
--  the SPARQL compiler injects the FROM graph automatically; an
--  OPTION (graph <iri>) overrides it (E.3).
--
--  Pass/fail is asserted with the isql ECHO BOTH $LAST[n] idiom; exact
--  numeric expectations are pinned to this data set (see
--  test_graph_data.sql for the graph and its expected properties).
--
--  Deep parallel-vs-inline determinism on large graphs is covered by the
--  runtime verification battery, not here: on an 8-node graph the
--  algorithm work always runs inline (min_batch = 64), so Group H only
--  asserts the enable_qp equivalence invariant.

ECHO BOTH "STARTED: graph analytics BIF test suite\n";

-- Procedures the assertions below use.  CREATE PROCEDURE is a write, so it
-- bumps the graph cache's invalidation generation; defining them all here,
-- above every assertion, keeps that away from Group G's cache checks.

-- CDLP is the DETERMINISTIC (synchronous) form of label propagation:
-- every node reads the previous iteration's labels, the iteration count is
-- fixed, ties go to the smallest label.  On this
-- fixture that puts A..E in one community and leaves F and F2 in two.
--
-- F and F2 not merging is correct, not a defect.  {F, F2} is a two-node
-- bipartite component: under synchronous updates each takes the other's
-- label every iteration, so the two labels swap forever and never meet.
-- Asynchronous label propagation would merge them, but it is not the
-- variant specified here, and this branch needs the deterministic one.
CREATE PROCEDURE GTEST_CDLP ()
{
  DECLARE a, b, c, d, e, f, f2 INT;
  a  := GRAPH_LABEL_PROPAGATION ('urn:graph:test:A', 'urn:graph:test', 'urn:graph:test:edge');
  b  := GRAPH_LABEL_PROPAGATION ('urn:graph:test:B', 'urn:graph:test', 'urn:graph:test:edge');
  c  := GRAPH_LABEL_PROPAGATION ('urn:graph:test:C', 'urn:graph:test', 'urn:graph:test:edge');
  d  := GRAPH_LABEL_PROPAGATION ('urn:graph:test:D', 'urn:graph:test', 'urn:graph:test:edge');
  e  := GRAPH_LABEL_PROPAGATION ('urn:graph:test:E', 'urn:graph:test', 'urn:graph:test:edge');
  f  := GRAPH_LABEL_PROPAGATION ('urn:graph:test:F', 'urn:graph:test', 'urn:graph:test:edge');
  f2 := GRAPH_LABEL_PROPAGATION ('urn:graph:test:F2', 'urn:graph:test', 'urn:graph:test:edge');
  IF (a = b AND b = c AND c = d AND d = e AND a <> f AND f <> f2)
    RETURN 'ABCDE|F|F2';
  RETURN sprintf ('%d %d %d %d %d %d %d', a, b, c, d, e, f, f2);
}
;

-- The local clustering coefficient has to agree with the two BIFs a caller
-- would otherwise approximate it from -- and with their degree convention,
-- which is what those callers get wrong.
CREATE PROCEDURE GTEST_LCC_IDENTITY ()
{
  DECLARE lcc, expect, d, tri DOUBLE PRECISION;
  lcc := GRAPH_CLUSTERING_COEFFICIENT ('urn:graph:test:A', 'urn:graph:test', 'urn:graph:test:edge');
  tri := GRAPH_TRIANGLE_COUNT ('urn:graph:test:A', 'urn:graph:test', 'urn:graph:test:edge');
  d   := GRAPH_DEGREE_CENTRALITY ('urn:graph:test:A', 'urn:graph:test', 'urn:graph:test:edge');
  expect := tri / (d * (d - 1) / 2);
  RETURN CASE WHEN lcc = expect THEN 'AGREE'
              ELSE cast (lcc AS VARCHAR) || ' <> ' || cast (expect AS VARCHAR) END;
}
;

-- GRAPH_BFS and GRAPH_SHORTEST_PATH_LENGTH are now two readings of one
-- cached distance vector, so they must agree everywhere -- including on the
-- unreachable answer.
CREATE PROCEDURE GTEST_BFS_SPL_AGREE ()
{
  DECLARE i INT;
  DECLARE n VARCHAR;
  DECLARE names ANY;
  names := vector ('A', 'B', 'C', 'D', 'E', 'F', 'F2');
  FOR (i := 0; i < 7; i := i + 1)
    {
      n := 'urn:graph:test:' || aref (names, i);
      IF (GRAPH_BFS ('urn:graph:test:A', n, 'urn:graph:test', 'urn:graph:test:edge')
          <> GRAPH_SHORTEST_PATH_LENGTH ('urn:graph:test:A', n, 'urn:graph:test', 'urn:graph:test:edge'))
        RETURN 'DIFFER at ' || n;
    }
  RETURN 'AGREE';
}
;

-- The reason a graph BIF gives for a graph it could not load, reduced to
-- the words after "failed to load graph: " with spaces underscored, so the
-- ECHO $EQU comparisons stay single-token.  'NOERROR' when the statement
-- unexpectedly succeeds, so a silent pass is impossible, and 'OTHER:...'
-- when it failed for an unrelated reason.
CREATE PROCEDURE GTEST_LOAD_ERR (IN txt VARCHAR)
{
  DECLARE st, msg, tag VARCHAR;
  DECLARE mdta, rset ANY;
  DECLARE pos INT;
  st := '00000';
  msg := '';
  EXEC (txt, st, msg, VECTOR (), 0, mdta, rset);
  IF (st = '00000')
    RETURN 'NOERROR';
  tag := 'failed to load graph: ';
  pos := strstr (msg, tag);
  IF (pos IS NULL)
    RETURN 'OTHER:' || msg;
  RETURN replace (subseq (msg, pos + length (tag)), ' ', '_');
}
;

-- ============================================================================
-- Group A: Algorithm correctness with exact values
-- ============================================================================

-- A.1: Degree centrality of node A, outgoing (expected: 2)
SPARQL
SELECT (STR(bif:degree_centrality(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>, 2)) AS ?a1)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": A1 degree(A,OUT) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

-- A.2: Shortest path length A->D (expected: 2)
SPARQL
SELECT (STR(bif:shortest_path_length(<urn:graph:test:A>, <urn:graph:test:D>, <urn:graph:test>, <urn:graph:test:edge>)) AS ?a2)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": A2 sp(A,D) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

-- A.3: Shortest path length A->E (expected: 3)
SPARQL
SELECT (STR(bif:shortest_path_length(<urn:graph:test:A>, <urn:graph:test:E>, <urn:graph:test>, <urn:graph:test:edge>)) AS ?a3)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": A3 sp(A,E) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";

-- A.4: Shortest path length A->F (expected: -1, unreachable)
SPARQL
SELECT (STR(bif:shortest_path_length(<urn:graph:test:A>, <urn:graph:test:F>, <urn:graph:test>, <urn:graph:test:edge>)) AS ?a4)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": A4 sp(A,F) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";

-- A.5: PageRank of node A (pinned exact value, default parameters)
SPARQL
SELECT (STR(bif:pagerank(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>)) AS ?a5)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": A5 pagerank(A) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.1336783543770536 "PASSED" "***FAILED";

-- A.6: WCC of A and E: same component
SPARQL
SELECT (STR(bif:wcc(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>)
            = bif:wcc(<urn:graph:test:E>, <urn:graph:test>, <urn:graph:test:edge>)) AS ?a6)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": A6 wcc(A) == wcc(E) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "true" "PASSED" "***FAILED";

-- A.7: WCC of A and F: different components
SPARQL
SELECT (STR(bif:wcc(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>)
            != bif:wcc(<urn:graph:test:F>, <urn:graph:test>, <urn:graph:test:edge>)) AS ?a7)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": A7 wcc(A) != wcc(F) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "true" "PASSED" "***FAILED";

-- A.8: Triangle count (expected: 2, triangles A-B-C and B-C-D)
SPARQL
SELECT (STR(bif:triangle_count(<urn:graph:test>, <urn:graph:test:edge>)) AS ?a8)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": A8 triangles = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

-- A.9: Jaccard similarity A,B (expected: 1/3)
SPARQL
SELECT (STR(bif:jaccard_similarity(<urn:graph:test:A>, <urn:graph:test:B>, <urn:graph:test>, <urn:graph:test:edge>)) AS ?a9)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": A9 jaccard(A,B) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.3333333333333333 "PASSED" "***FAILED";

-- A.10: SCC of A, B, C: all same component
SPARQL
SELECT (STR(bif:scc(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>)
            = bif:scc(<urn:graph:test:B>, <urn:graph:test>, <urn:graph:test:edge>)
            && bif:scc(<urn:graph:test:B>, <urn:graph:test>, <urn:graph:test:edge>)
            = bif:scc(<urn:graph:test:C>, <urn:graph:test>, <urn:graph:test:edge>)) AS ?a10)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": A10 scc(A)=scc(B)=scc(C) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "true" "PASSED" "***FAILED";

-- A.11: SCC of A vs D: different components
SPARQL
SELECT (STR(bif:scc(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>)
            != bif:scc(<urn:graph:test:D>, <urn:graph:test>, <urn:graph:test:edge>)) AS ?a11)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": A11 scc(A) != scc(D) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "true" "PASSED" "***FAILED";

-- A.12: Eigenvector centrality of A (pinned exact value)
--
-- The pin moved from 0.3728480715891352 when the iteration became (I + A)
-- instead of A (see Group AJ).  Same eigenvector -- the shift moves no
-- eigenvector -- reached more exactly: the principal eigenvector of this
-- graph has A = 0.3728481450402906, which the old value missed by 7.3e-08
-- and this one by 3.0e-09.
SPARQL
SELECT (STR(bif:eigenvector(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>)) AS ?a12)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": A12 eigenvector(A) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.3728481480601242 "PASSED" "***FAILED";

-- A.13: Betweenness: C strictly more central than A (C=1.333..., A=0)
SPARQL
SELECT (STR(bif:betweenness(<urn:graph:test:C>, <urn:graph:test>, <urn:graph:test:edge>)
            > bif:betweenness(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>)) AS ?a13)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": A13 betweenness(C) > betweenness(A) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "true" "PASSED" "***FAILED";

-- A.14: Closeness: C strictly more central than A (0.6666 vs 0.5714)
SPARQL
SELECT (STR(bif:closeness(<urn:graph:test:C>, <urn:graph:test>, <urn:graph:test:edge>)
            > bif:closeness(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>)) AS ?a14)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": A14 closeness(C) > closeness(A) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "true" "PASSED" "***FAILED";

-- A.15: Community id of A is deterministic (pinned: 0)
SPARQL
SELECT (STR(bif:community_id(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>)) AS ?a15)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": A15 community_id(A) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- A.16: BFS distance A->E (expected: 3)
SPARQL
SELECT (STR(bif:bfs(<urn:graph:test:A>, <urn:graph:test:E>, <urn:graph:test>, <urn:graph:test:edge>)) AS ?a16)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": A16 bfs(A,E) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";

-- A.17: CDLP label of A (pinned: 0).  Labels are renumbered densely by
-- first appearance in node-map order, as GRAPH_COMMUNITY_ID's are, so the
-- value is stable rather than being whichever node id won.
SPARQL
SELECT (STR(bif:label_propagation(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>)) AS ?a17)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": A17 label_propagation(A) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- A.18: the whole CDLP partition, including the bipartite pair that
-- synchronous propagation is required not to merge (see GTEST_CDLP)
select GTEST_CDLP ();
ECHO BOTH ": A18 CDLP partition = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "ABCDE|F|F2" "PASSED" "***FAILED";

-- A.19: LCC of A (pinned exact value: 1 triangle over 3*2/2 pairs)
SPARQL
SELECT (STR(bif:clustering_coefficient(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>)) AS ?a19)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": A19 clustering_coefficient(A) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.3333333333333333 "PASSED" "***FAILED";

-- A.20: ... and it equals triangles(A) / (d*(d-1)/2) from the other two
-- BIFs, so the formula and the degree convention are asserted to agree
select GTEST_LCC_IDENTITY ();
ECHO BOTH ": A20 LCC(A) vs triangles/degree = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

-- A.21: graph-wide mean LCC (pinned): (1/3 + 2/3 + 1/3 + 1/3 + 0 + 0 + 0)/7.
-- The mean is over ALL nodes, counting the degree < 2 ones as the zeroes
-- they are -- the usual definition, and the one a caller can recompute
-- from the per-node values alone.
select cast (GRAPH_CLUSTERING_COEFFICIENT ('urn:graph:test', 'urn:graph:test:edge') as varchar);
ECHO BOTH ": A21 mean LCC = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.2380952380952381 "PASSED" "***FAILED";

-- A.22: BFS and shortest-path length now read one cached distance vector
-- rather than each running their own traversal; they must still agree
select GTEST_BFS_SPL_AGREE ();
ECHO BOTH ": A22 bfs == shortest_path_length for every target = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

-- ============================================================================
-- Group B: NULL and error semantics
-- ============================================================================

-- B.1: NULL node argument is a runtime error (VGPR01, SQLSTATE 42001)
select pagerank (NULL);
ECHO BOTH ": B1 pagerank(NULL) state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE 42001 "PASSED" "***FAILED";

-- B.2: Integer node ids are accepted as raw IRI_IDs (no error; a node id
-- outside the resolved scope yields NULL)
select pagerank (1, iri_to_id ('urn:graph:test'), iri_to_id ('urn:graph:test:edge'));
ECHO BOTH ": B2 pagerank(1) state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";

-- B.3: Out-of-range damping rejected at parse time (37000)
SPARQL PREFIX bif: <http://www.openlinksw.com/schemas/bif#>
SELECT ?d FROM <urn:graph:test> WHERE {
  <urn:graph:test:A> <urn:graph:test:edge> ?o .
  <urn:graph:test:A> bif:degree_centrality ?d OPTION (damping 1.5) . } LIMIT 1;
ECHO BOTH ": B3 damping 1.5 state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE 37000 "PASSED" "***FAILED";

-- B.4: Out-of-range max_iter rejected at parse time (37000)
SPARQL PREFIX bif: <http://www.openlinksw.com/schemas/bif#>
SELECT ?d FROM <urn:graph:test> WHERE {
  <urn:graph:test:A> <urn:graph:test:edge> ?o .
  <urn:graph:test:A> bif:pagerank ?d OPTION (max_iter 0) . } LIMIT 1;
ECHO BOTH ": B4 max_iter 0 state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE 37000 "PASSED" "***FAILED";

-- B.5: Unresolvable graph IRI is a runtime error (VGPR03, SQLSTATE 42006)
select pagerank (iri_to_id ('urn:graph:test:A'), iri_to_id ('urn:no-such-graph'));
ECHO BOTH ": B5 bad graph state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE 42006 "PASSED" "***FAILED";

-- B.6: Node missing from the resolved graph returns NULL (not an error)
select pagerank (iri_to_id ('urn:graph:test:NOPE'), iri_to_id ('urn:graph:test'), iri_to_id ('urn:graph:test:edge'));
ECHO BOTH ": B6 missing node state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": B6 missing node value = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] NULL "PASSED" "***FAILED";

-- ============================================================================
-- Group C: SQL scalar forms
-- ============================================================================

-- C.1: 3-arg degree defaults to BOTH directions (out 2 + in 1 = 3)
select degree_centrality (iri_to_id ('urn:graph:test:A'), iri_to_id ('urn:graph:test'), iri_to_id ('urn:graph:test:edge'));
ECHO BOTH ": C1 degree(A,BOTH) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";

-- C.2: 4-arg degree with direction 2 = OUTGOING (expected: 2)
select degree_centrality (iri_to_id ('urn:graph:test:A'), iri_to_id ('urn:graph:test'), iri_to_id ('urn:graph:test:edge'), 2);
ECHO BOTH ": C2 degree(A,OUT) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

-- C.3: Custom damping/max_iter/tolerance change the PageRank result
select pagerank (iri_to_id ('urn:graph:test:A'), iri_to_id ('urn:graph:test'), iri_to_id ('urn:graph:test:edge'))
     - pagerank (iri_to_id ('urn:graph:test:A'), iri_to_id ('urn:graph:test'), iri_to_id ('urn:graph:test:edge'), 0.5, 30, 0.000001);
ECHO BOTH ": C3 pagerank param diff = " $LAST[1] "\n";
ECHO BOTH $IF $NEQ $LAST[1] 0 "PASSED" "***FAILED";

-- C.4: Explicit graph argument selects <urn:graph:test2>: X has
-- out-degree 2 there (and does not exist in <urn:graph:test>)
select degree_centrality (iri_to_id ('urn:graph:test:X'), iri_to_id ('urn:graph:test2'), iri_to_id ('urn:graph:test:edge'));
ECHO BOTH ": C4 degree(X in test2) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

-- C.5: SQL shortest_path_length A->E (expected: 3)
select shortest_path_length (iri_to_id ('urn:graph:test:A'), iri_to_id ('urn:graph:test:E'), iri_to_id ('urn:graph:test'), iri_to_id ('urn:graph:test:edge'));
ECHO BOTH ": C5 sp(A,E) SQL form = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";

-- ============================================================================
-- Group D: SPARQL predicate forms and OPTION parameters
-- ============================================================================

-- D.1: PageRank in predicate position (graph scope auto-injected);
-- 8 edge rows, every node resolves
SPARQL
SELECT ?node ?rank
FROM <urn:graph:test>
WHERE {
    ?node <urn:graph:test:edge> ?o .
    ?node bif:pagerank ?rank .
}
ORDER BY DESC(?rank)
LIMIT 3;
ECHO BOTH ": D1 predicate pagerank state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": D1 rows = " $ROWCNT "\n";
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";

-- D.2: Predicate-position PageRank with OPTION parameters
SPARQL
SELECT ?node ?rank
FROM <urn:graph:test>
WHERE {
    ?node <urn:graph:test:edge> ?o .
    ?node bif:pagerank ?rank
    OPTION (damping 0.9, max_iter 20, tolerance 0.000001) .
}
ORDER BY DESC(?rank)
LIMIT 3;
ECHO BOTH ": D2 OPTION params state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": D2 rows = " $ROWCNT "\n";
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";

-- D.3: Betweenness with normalized/directed options (pinned exact value)
SPARQL
SELECT ?node (STR(?bet) AS ?d3)
FROM <urn:graph:test>
WHERE {
    <urn:graph:test:C> <urn:graph:test:edge> ?o .
    <urn:graph:test:C> bif:betweenness ?bet
    OPTION (normalized 1, directed 1) .
}
LIMIT 1;
ECHO BOTH ": D3 normalized betweenness state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": D3 normalized betweenness(C) = " $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[2] 0.06666666666666667 "PASSED" "***FAILED";

-- D.4: Option keywords are case-insensitive
SPARQL
SELECT ?node ?rank
FROM <urn:graph:test>
WHERE {
    ?node <urn:graph:test:edge> ?o .
    ?node bif:pagerank ?rank
    OPTION (Damping 0.9, MAX_ITER 20) .
}
ORDER BY DESC(?rank)
LIMIT 1;
ECHO BOTH ": D4 mixed-case options state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": D4 rows = " $ROWCNT "\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";

-- D.5: Predicate-position degree defaults to BOTH and matches C.1 (3)
SPARQL
SELECT ?node (STR(?deg) AS ?d5)
FROM <urn:graph:test>
WHERE {
    <urn:graph:test:A> <urn:graph:test:edge> ?o .
    <urn:graph:test:A> bif:degree_centrality ?deg .
}
LIMIT 1;
ECHO BOTH ": D5 predicate degree(A) = " $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[2] 3 "PASSED" "***FAILED";

-- ============================================================================
-- Group E: FROM scoping, multi-FROM and OPTION (graph ...) override
-- ============================================================================

-- E.1: Count triples in graph (expected: 8)
SPARQL
SELECT (COUNT(*) AS ?cnt)
FROM <urn:graph:test>
WHERE { ?s ?p ?o };
ECHO BOTH ": E1 count = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";

-- E.2: Explicit graph argument overrides FROM: X is not a subject of
-- <urn:graph:test> (the FROM graph) but has degree 2 in <urn:graph:test2>
SPARQL
SELECT (STR(bif:degree_centrality(<urn:graph:test:X>, <urn:graph:test2>, <urn:graph:test:edge>)) AS ?e2)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": E2 degree(X in test2, FROM test) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

-- E.3: OPTION (graph <iri>) overrides the dataset scope with the highest
-- priority: under a two-graph FROM, restricting to <urn:graph:test>
-- reproduces exactly the single-graph PageRank (A.5)
SPARQL
SELECT (STR(?r) AS ?e3)
FROM <urn:graph:test> FROM <urn:graph:test2>
WHERE {
    <urn:graph:test:A> <urn:graph:test:edge> ?o .
    <urn:graph:test:A> bif:pagerank ?r
    OPTION (graph <urn:graph:test>) .
}
LIMIT 1;
ECHO BOTH ": E3 OPTION graph override pagerank(A) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.1336783543770536 "PASSED" "***FAILED";

-- E.4: Multi-FROM union: 8 + 2 quads (expected: 10)
SPARQL
SELECT (COUNT(*) AS ?cnt)
FROM <urn:graph:test> FROM <urn:graph:test2>
WHERE { ?s ?p ?o };
ECHO BOTH ": E4 multi-FROM count = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";

-- ============================================================================
-- Group F: Batch/vectored behavior
-- ============================================================================

-- F.1: Vectored PageRank for all edge rows (8 rows)
SPARQL
SELECT ?node ?rank
FROM <urn:graph:test>
WHERE {
    ?node <urn:graph:test:edge> ?o .
    ?node bif:pagerank ?rank .
}
ORDER BY DESC(?rank);
ECHO BOTH ": F1 vectored pagerank state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": F1 rows = " $ROWCNT "\n";
ECHO BOTH $IF $EQU $ROWCNT 8 "PASSED" "***FAILED";

-- F.2: Vectored degree centrality for all edge rows (8 rows)
SPARQL
SELECT ?node ?deg
FROM <urn:graph:test>
WHERE {
    ?node <urn:graph:test:edge> ?o .
    ?node bif:degree_centrality ?deg .
}
ORDER BY DESC(?deg);
ECHO BOTH ": F2 vectored degree state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": F2 rows = " $ROWCNT "\n";
ECHO BOTH $IF $EQU $ROWCNT 8 "PASSED" "***FAILED";

-- ----------------------------------------------------------------------------
-- F.3 - F.6: the vectored path actually runs, and agrees with the scalar one.
--
-- F.1 and F.2 above assert only that a query over every edge row returns
-- the right number of rows.  On this fixture that is eight rows, and
-- [Graph] MinBatch is 64, so the vectored implementations decline and the
-- scalar row loop runs: both cases assert the scalar path twice over.
-- Dropping the threshold to 1 is what makes the vectored path reachable
-- at all at this size.
--
-- The comparison is between the two positions of the same BIF.  In
-- predicate position the compiler binds a variable and the vectored
-- implementation maps whole result columns; in expression position the
-- scalar function runs per row.  Anything that differs between them --
-- a row mapped to the wrong node, a payload read at the wrong offset --
-- shows up as a non-zero count here and as nothing at all anywhere else,
-- because both paths return plausible numbers.
-- ----------------------------------------------------------------------------
SELECT GRAPH_SET_LIMIT ('MinBatch', 1);
ECHO BOTH ": F3 MinBatch lowered = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- The comparison cannot be "predicate position against expression
-- position": at MinBatch 1 the compiler vectorises the expression too, so
-- both halves of such a test go down the same path and agree with each
-- other however wrong they are.  A deliberate break of the vectored
-- offset was invisible to exactly that shape of assertion.  These pin the
-- vectored values against the fixture instead, which no code path can
-- talk its way out of.

-- F.4: vectored harmonic.  B's score is 1 + 1 + 1/2 + 1/2, exact in
-- binary, so this is an equality and not a tolerance.
SPARQL
SELECT (COUNT(*) AS ?f4)
FROM <urn:graph:test>
WHERE {
    ?node <urn:graph:test:edge> ?o .
    ?node bif:harmonic ?h .
    FILTER (?node = <urn:graph:test:B> && ?h != 3.0)
};
ECHO BOTH ": F4 vectored harmonic(B) wrong rows = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- F.5: vectored hits_hub -- the first half of the two-array payload.  D
-- points only at E, a dead end, so its hub score decays to nothing.
SPARQL
SELECT (COUNT(*) AS ?f5)
FROM <urn:graph:test>
WHERE {
    ?node <urn:graph:test:edge> ?o .
    ?node bif:hits_hub ?h .
    FILTER ((?node = <urn:graph:test:D> && ?h >= 0.1) ||
            (?node = <urn:graph:test:B> && ?h <= 0.7))
};
ECHO BOTH ": F5 vectored hits_hub wrong rows = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- F.6: vectored hits_authority -- the second half, read at an offset of
-- node_count doubles.  D is the joint-best authority at 0.653 and the
-- worst hub at ~0, so a row mapping that ignored the offset would return
-- roughly zero here.  That break is what this case exists for; it is
-- invisible to a vectored-against-vectored comparison.
SPARQL
SELECT (COUNT(*) AS ?f6)
FROM <urn:graph:test>
WHERE {
    ?node <urn:graph:test:edge> ?o .
    ?node bif:hits_authority ?a .
    FILTER ((?node = <urn:graph:test:D> && ?a <= 0.6) ||
            (?node = <urn:graph:test:B> && ?a >= 0.3))
};
ECHO BOTH ": F6 vectored hits_authority wrong rows = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- F.7: and the two halves are not one column read twice.
SPARQL
SELECT (COUNT(*) AS ?f7)
FROM <urn:graph:test>
WHERE {
    ?node <urn:graph:test:edge> ?o .
    ?node bif:hits_hub ?h .
    ?node bif:hits_authority ?a .
    FILTER (?h = ?a)
};
ECHO BOTH ": F7 vectored rows where hub = authority = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- F.8: vectored degree centrality against the value A.1 pins for the
-- scalar form.  The whole-graph batch driver has been exercised by F.1
-- and F.2 since they were written, but never at a batch size that
-- reached it.
SPARQL
SELECT (COUNT(*) AS ?f8)
FROM <urn:graph:test>
WHERE {
    ?node <urn:graph:test:edge> ?o .
    ?node bif:degree_centrality ?d .
    FILTER (?node = <urn:graph:test:A> && ?d != 3)
};
ECHO BOTH ": F8 vectored degree(A) wrong rows = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

SELECT GRAPH_SET_LIMIT ('MinBatch', 64);
ECHO BOTH ": F9 MinBatch restored = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 64 "PASSED" "***FAILED";

-- ============================================================================
-- Group G: Cache hits and invalidation
-- ============================================================================

-- G.1: Two calls to PageRank in one query return the same value
SPARQL
SELECT (STR(bif:pagerank(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>)
            = bif:pagerank(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>)) AS ?g1)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": G1 pagerank cache equality = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "true" "PASSED" "***FAILED";

-- G.2: Insert a new edge, degree of E goes 0 -> 1, revert -> 0
SPARQL
SELECT (STR(bif:degree_centrality(<urn:graph:test:E>, <urn:graph:test>, <urn:graph:test:edge>, 2)) AS ?g2a)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": G2 degree(E,OUT) before = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

SPARQL INSERT INTO GRAPH <urn:graph:test> {
    <urn:graph:test:E> <urn:graph:test:edge> <urn:graph:test:F> .
};

SPARQL
SELECT (STR(bif:degree_centrality(<urn:graph:test:E>, <urn:graph:test>, <urn:graph:test:edge>, 2)) AS ?g2b)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": G2 degree(E,OUT) after insert = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

SPARQL DELETE FROM GRAPH <urn:graph:test> {
    <urn:graph:test:E> <urn:graph:test:edge> <urn:graph:test:F> .
};

SPARQL
SELECT (STR(bif:degree_centrality(<urn:graph:test:E>, <urn:graph:test>, <urn:graph:test:edge>, 2)) AS ?g2c)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": G2 degree(E,OUT) after revert = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- ============================================================================
-- Group H: Parallel vs sequential equivalence (enable_qp)
-- ============================================================================
-- enable_qp is runtime-settable; the graph layer must honor the live value
-- per parallel-section dispatch.  Both runs must produce bit-identical
-- results.  (On this small graph the algorithm work runs inline either
-- way; large-graph parallel determinism is covered by the runtime
-- verification battery.)

CREATE TABLE gh_nodes (id INT PRIMARY KEY, iri IRI_ID);
CREATE TABLE gh_seq (id INT PRIMARY KEY, v DOUBLE PRECISION);
CREATE TABLE gh_par (id INT PRIMARY KEY, v DOUBLE PRECISION);

CREATE PROCEDURE gh_fill ()
{
  DECLARE i, k INT;
  i := 0;
  WHILE (i < 100)
    {
      k := i - ((i / 6) * 6);
      INSERT INTO gh_nodes VALUES (i + 1,
        iri_to_id (CONCAT ('urn:graph:test:', aref (vector ('A','B','C','D','E','F'), k))));
      i := i + 1;
    }
}

gh_fill ();

-- Sequential pass: one graph-analytics worker
SELECT __dbf_set ('enable_qp', 1);
INSERT INTO gh_seq SELECT id, pagerank (iri, iri_to_id ('urn:graph:test'), iri_to_id ('urn:graph:test:edge')) FROM gh_nodes;

-- Parallel pass: restore the suite default worker count
SELECT __dbf_set ('enable_qp', 8);
INSERT INTO gh_par SELECT id, pagerank (iri, iri_to_id ('urn:graph:test'), iri_to_id ('urn:graph:test:edge')) FROM gh_nodes;

-- H.1: same row count (100)
SELECT COUNT(*) FROM gh_par;
ECHO BOTH ": H1 parallel rows = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 100 "PASSED" "***FAILED";

-- H.2: no value differs between the two passes
SELECT COUNT(*) FROM gh_seq s, gh_par p WHERE s.id = p.id AND s.v <> p.v;
ECHO BOTH ": H2 value mismatches = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- H.3: sequential pass completed all rows too
SELECT COUNT(*) FROM gh_seq;
ECHO BOTH ": H3 sequential rows = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 100 "PASSED" "***FAILED";

-- H.4/H.5: the two algorithms added to complete the set must be enable_qp
-- independent for the same reason PageRank is: their parallel pass is a
-- per-node gather that writes only its own slice.  (On a 7-node graph the
-- work runs inline either way; test_graph_scale.sql Group L asserts the
-- same equality at 20,000 nodes, where the slicing actually engages.)
CREATE TABLE gh_seq2 (id INT PRIMARY KEY, lp INT, cc DOUBLE PRECISION);
CREATE TABLE gh_par2 (id INT PRIMARY KEY, lp INT, cc DOUBLE PRECISION);

SELECT __dbf_set ('enable_qp', 1);
INSERT INTO gh_seq2 SELECT id,
    label_propagation (iri, iri_to_id ('urn:graph:test'), iri_to_id ('urn:graph:test:edge')),
    clustering_coefficient (iri, iri_to_id ('urn:graph:test'), iri_to_id ('urn:graph:test:edge'))
  FROM gh_nodes;

SELECT __dbf_set ('enable_qp', 8);
INSERT INTO gh_par2 SELECT id,
    label_propagation (iri, iri_to_id ('urn:graph:test'), iri_to_id ('urn:graph:test:edge')),
    clustering_coefficient (iri, iri_to_id ('urn:graph:test'), iri_to_id ('urn:graph:test:edge'))
  FROM gh_nodes;

SELECT COUNT(*) FROM gh_seq2 s, gh_par2 p WHERE s.id = p.id AND s.lp <> p.lp;
ECHO BOTH ": H4 label_propagation mismatches = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

SELECT COUNT(*) FROM gh_seq2 s, gh_par2 p WHERE s.id = p.id AND s.cc <> p.cc;
ECHO BOTH ": H5 clustering_coefficient mismatches = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

DROP TABLE gh_seq2;
DROP TABLE gh_par2;
DROP TABLE gh_nodes;
DROP TABLE gh_seq;
DROP TABLE gh_par;

-- ============================================================================
-- Group I: Invalid OPTION values rejected at parse time
-- ============================================================================

-- I.1: Unknown option keyword (37000)
SPARQL PREFIX bif: <http://www.openlinksw.com/schemas/bif#>
SELECT ?d FROM <urn:graph:test> WHERE {
  <urn:graph:test:A> <urn:graph:test:edge> ?o .
  <urn:graph:test:A> bif:pagerank ?d OPTION (bogus 1) . } LIMIT 1;
ECHO BOTH ": I1 bogus option state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE 37000 "PASSED" "***FAILED";

-- I.2: Non-literal option value rejected by the parser (37000); before
-- the parse-time check this silently fell back to default parameters
SPARQL PREFIX bif: <http://www.openlinksw.com/schemas/bif#>
SELECT ?d FROM <urn:graph:test> WHERE {
  <urn:graph:test:A> <urn:graph:test:edge> ?o .
  <urn:graph:test:A> bif:pagerank ?d OPTION (damping ?x) . } LIMIT 1;
ECHO BOTH ": I2 non-literal option state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE 37000 "PASSED" "***FAILED";

-- I.3: Option not valid for this algorithm (37000)
SPARQL PREFIX bif: <http://www.openlinksw.com/schemas/bif#>
SELECT ?d FROM <urn:graph:test> WHERE {
  <urn:graph:test:A> <urn:graph:test:edge> ?o .
  <urn:graph:test:A> bif:degree_centrality ?d OPTION (damping 0.9) . } LIMIT 1;
ECHO BOTH ": I3 wrong option for algorithm state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE 37000 "PASSED" "***FAILED";

-- ============================================================================
-- Group J: Weighted graph algorithms (RDF 1.2 triple terms)
-- ============================================================================

-- J.1: Load weighted test data using W3C reification (plain triples).
--
-- Weight edges are represented as reification statements carrying the
-- weight predicate.  W3C reification is used instead of RDF 1.2 triple
-- terms because << s p o >> SPARUL INSERT is broken on fresh databases
-- when CaseMode is 0 or 1 (upstream: the generated SQL fails with
-- SQ200 "No column s.").  The weighted loaders accept both forms: RDF
-- 1.2 reifier IRIs are parsed directly, and these plain reification
-- triples are joined on rdf:subject/rdf:predicate/rdf:object.
SPARQL INSERT INTO GRAPH <urn:graph:test> {
    <urn:graph:test:w1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:graph:test:A> .
    <urn:graph:test:w1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:graph:test:edge> .
    <urn:graph:test:w1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:graph:test:B> .
    <urn:graph:test:w1> <urn:graph:test:weight> 0.9 .
    <urn:graph:test:w2> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:graph:test:A> .
    <urn:graph:test:w2> <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:graph:test:edge> .
    <urn:graph:test:w2> <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:graph:test:C> .
    <urn:graph:test:w2> <urn:graph:test:weight> 0.5 .
    <urn:graph:test:w3> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:graph:test:B> .
    <urn:graph:test:w3> <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:graph:test:edge> .
    <urn:graph:test:w3> <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:graph:test:C> .
    <urn:graph:test:w3> <urn:graph:test:weight> 0.8 .
    <urn:graph:test:w4> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:graph:test:C> .
    <urn:graph:test:w4> <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:graph:test:edge> .
    <urn:graph:test:w4> <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:graph:test:A> .
    <urn:graph:test:w4> <urn:graph:test:weight> 0.7 .
    <urn:graph:test:w5> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:graph:test:B> .
    <urn:graph:test:w5> <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:graph:test:edge> .
    <urn:graph:test:w5> <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:graph:test:D> .
    <urn:graph:test:w5> <urn:graph:test:weight> 0.6 .
    <urn:graph:test:w6> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:graph:test:C> .
    <urn:graph:test:w6> <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:graph:test:edge> .
    <urn:graph:test:w6> <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:graph:test:D> .
    <urn:graph:test:w6> <urn:graph:test:weight> 0.4 .
    <urn:graph:test:w7> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:graph:test:D> .
    <urn:graph:test:w7> <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:graph:test:edge> .
    <urn:graph:test:w7> <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:graph:test:E> .
    <urn:graph:test:w7> <urn:graph:test:weight> 1.0 .
};

SPARQL
SELECT (COUNT(*) AS ?j1)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:weight> ?w };
ECHO BOTH ": J1 weight triples = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";

-- J.2: Weighted PageRank using weight predicate (pinned exact value)
SPARQL
SELECT (STR(bif:GRAPH_PAGERANK_WEIGHTED(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>, <urn:graph:test:weight>)) AS ?j2)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": J2 weighted pagerank(A) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.1530128725273583 "PASSED" "***FAILED";

-- J.3: Weighted degree using weight predicate (out 0.9+0.5, in 0.7 = 2.1)
SPARQL
SELECT (STR(bif:GRAPH_DEGREE_W_SPARQL(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>, <urn:graph:test:weight>)) AS ?j3)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": J3 weighted degree(A) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2.1 "PASSED" "***FAILED";

-- J.4: Weighted betweenness of C, normalized and directed (pinned exact
-- value).
--
-- The arguments are given rather than defaulted now.  They used to be the
-- defaults -- this BIF passed NULL parameters and ran on
-- GRAPH_BETWEENNESS_DEFAULT, where normalized and directed are both true,
-- while GRAPH_BETWEENNESS defaults both to 0.  The value is unchanged
-- because the measure is unchanged; only the way of asking for it is.
SELECT GRAPH_BETWEENNESS_WEIGHTED ('urn:graph:test:C', 'urn:graph:test',
         'urn:graph:test:edge', iri_to_id ('urn:graph:test:weight'), 1, 1);
ECHO BOTH ": J4 weighted betweenness(C), normalized+directed = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.1 "PASSED" "***FAILED";

-- J.4b: omitting them must give the same number, because absent means
-- GRAPH_BETWEENNESS_DEFAULT -- which is what GRAPH_BETWEENNESS does too.
--
-- Worth its own case because the unweighted BIF reads as though it
-- defaulted them to 0: it parses `normalized` and `directed` with `: 0`
-- and then voids both.  Betweenness is a whole-graph algorithm, and the
-- compute callback re-reads the arguments from scratch, starting at the
-- library default.  Taking the scalar function at face value and
-- defaulting this one to 0 made the two disagree, and J.17 is what said
-- so.
SELECT GRAPH_BETWEENNESS_WEIGHTED ('urn:graph:test:C', 'urn:graph:test',
         'urn:graph:test:edge', iri_to_id ('urn:graph:test:weight'));
ECHO BOTH ": J4b weighted betweenness(C), defaults = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.1 "PASSED" "***FAILED";

-- J.5: Weighted closeness of A (pinned exact value).
--
-- The pinned value moved, from 0.634920634920635 to 0.9523809523809526,
-- because the default changed rather than the arithmetic.  This BIF used
-- to pass NULL parameters and so ran on GRAPH_CLOSENESS_DEFAULT, whose
-- .normalized is true; the unweighted GRAPH_CLOSENESS overrides that to 0.
-- One measure, two halves, opposite defaults, and no argument to say which
-- you meant.
--
-- Both numbers are the same walk.  Dijkstra from A over the weights below
-- gives B 0.9, C 0.5, D 0.9, E 1.9 -- four nodes reached, 4.2 total -- so
-- the raw score is 4/4.2 and the normalized one is that times
-- reached/(n-1) = 4/6.  0.9523809523809526 * (4.0/6.0) is exactly the old
-- pin, which is how this value was derived rather than read back.
SPARQL
SELECT (STR(bif:GRAPH_CLOSENESS_WEIGHTED(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>, <urn:graph:test:weight>)) AS ?j5)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": J5 weighted closeness(A), raw = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.9523809523809526 "PASSED" "***FAILED";

-- J.5b: ... and the normalized reading is now reachable, as the fifth
-- argument.  It is the old pin, which is what makes this a default change
-- and not a lost capability.
SELECT GRAPH_CLOSENESS_WEIGHTED ('urn:graph:test:A', 'urn:graph:test',
         'urn:graph:test:edge', iri_to_id ('urn:graph:test:weight'), 1);
ECHO BOTH ": J5b weighted closeness(A), normalized = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.634920634920635 "PASSED" "***FAILED";

-- J.6: Weighted eigenvector of A (pinned exact value)
--
-- Moved with A.12 and for the same reason: true value 0.3865437681574676,
-- old pin off by 8.0e-08, this one by 1.0e-08.
-- Compared within 1e-12, not digit for digit: the last of 16 digits differs
-- between compilers and CPUs (seen ...827 on Linux, ...828 elsewhere).
SPARQL
SELECT (IF (ABS (bif:GRAPH_EIGENVECTOR_WEIGHTED(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>, <urn:graph:test:weight>) - 0.3865437581641828) < 1e-12,
            "0.38654375816418",
            STR (bif:GRAPH_EIGENVECTOR_WEIGHTED(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>, <urn:graph:test:weight>))) AS ?j6)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": J6 weighted eigenvector(A) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.38654375816418 "PASSED" "***FAILED";

-- J.7: Weighted shortest path A->E (return_type=1 for vector result)
SPARQL
SELECT (bif:GRAPH_SHORTEST_PATH_WEIGHTED(<urn:graph:test:A>, <urn:graph:test:E>, <urn:graph:test>, <urn:graph:test:edge>, <urn:graph:test:weight>, 1) AS ?j7)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": J7 weighted shortest path state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";

-- J.8: Predicate-position weighted degree centrality (ground node C,
-- pinned exact value: out 0.7+0.4, in 0.5+0.8 = 2.4)
SPARQL
SELECT ?node (STR(?wdeg) AS ?j8)
FROM <urn:graph:test>
WHERE {
    <urn:graph:test:C> <urn:graph:test:edge> ?o .
    <urn:graph:test:C> bif:degree_centrality ?wdeg
    OPTION (weight <urn:graph:test:weight>) .
}
LIMIT 1;
ECHO BOTH ": J8 predicate weighted degree(C) = " $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[2] 2.4 "PASSED" "***FAILED";

-- J.9: Predicate-position weighted PageRank for node D (pinned exact value;
-- equals the direct GRAPH_PAGERANK_WEIGHTED(D, ...) value because the
-- all-predicates load excludes the reification vocabulary)
SPARQL
SELECT ?node (STR(?wr) AS ?j9)
FROM <urn:graph:test>
WHERE {
    ?node <urn:graph:test:edge> ?o .
    ?node bif:pagerank ?wr
    OPTION (weight <urn:graph:test:weight>) .
    FILTER (?node = <urn:graph:test:D>)
}
LIMIT 1;
ECHO BOTH ": J9 predicate weighted pagerank(D) = " $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[2] 0.1644555376899454 "PASSED" "***FAILED";

-- J.10 - J.13: the two weighted-degree BIFs, pinned.
--
-- GRAPH_DEGREE_WEIGHTED had no value coverage at all: the only case that
-- named it asserted the SQLSTATE of a permission denial.  So it could be
-- rewritten -- and it has been, off the raw adjacency records and onto
-- the shared neighbour iterator -- and nothing would have said if the
-- answer moved.
--
-- The weights on this fixture are A->B 0.9, A->C 0.5, B->C 0.8, C->A 0.7,
-- B->D 0.6, C->D 0.4, D->E 1.0, and F->F2 carries none so it costs the
-- default 1.0.  Every value below is that arithmetic and not a reading.
SPARQL
SELECT (STR(bif:GRAPH_DEGREE_WEIGHTED(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>, <urn:graph:test:weight>)) AS ?j10)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": J10 GRAPH_DEGREE_WEIGHTED(A) out 0.9+0.5 in 0.7 = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2.1 "PASSED" "***FAILED";

SPARQL
SELECT (STR(bif:GRAPH_DEGREE_WEIGHTED(<urn:graph:test:C>, <urn:graph:test>, <urn:graph:test:edge>, <urn:graph:test:weight>)) AS ?j11)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": J11 GRAPH_DEGREE_WEIGHTED(C) out 0.7+0.4 in 0.5+0.8 = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2.4 "PASSED" "***FAILED";

-- And the direction argument of the other one, which J3 exercises only at
-- its default.  A directed answer is the half of J3's 2.1 that the
-- direction names, so these two also say the split is on the right axis.
SPARQL
SELECT (STR(bif:GRAPH_DEGREE_W_SPARQL(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>, <urn:graph:test:weight>, 2)) AS ?j12)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": J12 weighted out-degree(A) 0.9+0.5 = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1.4 "PASSED" "***FAILED";

SPARQL
SELECT (STR(bif:GRAPH_DEGREE_W_SPARQL(<urn:graph:test:A>, <urn:graph:test>, <urn:graph:test:edge>, <urn:graph:test:weight>, 1)) AS ?j13)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": J13 weighted in-degree(A) 0.7 = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.7 "PASSED" "***FAILED";

-- Clean up weighted test data again
SPARQL CLEAR GRAPH <urn:graph:test>;

SPARQL INSERT INTO GRAPH <urn:graph:test> {
    <urn:graph:test:A> <urn:graph:test:edge> <urn:graph:test:B> .
    <urn:graph:test:A> <urn:graph:test:edge> <urn:graph:test:C> .
    <urn:graph:test:B> <urn:graph:test:edge> <urn:graph:test:C> .
    <urn:graph:test:C> <urn:graph:test:edge> <urn:graph:test:A> .
    <urn:graph:test:B> <urn:graph:test:edge> <urn:graph:test:D> .
    <urn:graph:test:C> <urn:graph:test:edge> <urn:graph:test:D> .
    <urn:graph:test:D> <urn:graph:test:edge> <urn:graph:test:E> .
    <urn:graph:test:F> <urn:graph:test:edge> <urn:graph:test:F2> .
};

-- J.14: weighted closeness must agree with unweighted closeness when every
-- edge weighs exactly 1.
--
-- The two share a definition: (nodes reached) / (sum of distances to them),
-- following outgoing edges.  With unit weights a Dijkstra distance is a hop
-- count, so the weighted result has to be the *same double*, not merely a
-- close one -- both sums are small exact integers and both divisions are
-- correctly rounded.  That makes the comparison self-checking: it needs no
-- pinned constant, holds at every graph size, and any disagreement is a
-- defect in the weighted path rather than a question about tolerance.
--
-- It is asserted across a size sweep because the weighted implementation
-- tracked its Dijkstra visited-set in a single uint64_t.  Only the first 64
-- node indices had a bit of their own; `visited >> i` for i >= 64 is
-- undefined, and on this hardware reads bit (i & 63), so node 64 shared
-- node 0's bit.  Settling a high-index node marked a low-index one visited,
-- Dijkstra then skipped a node it still had to relax, and the distances
-- came out wrong.  Wrong, not absent: a plausible number was returned for
-- every node, which is why nothing above 64 nodes had ever caught it.  The
-- fixture graphs elsewhere in this file are eight nodes, so every existing
-- weighted case ran inside the one word that worked.
CREATE PROCEDURE GTEST_CW_CHAIN (IN n INT)
{
  -- A directed chain of n nodes in its own graph, so no size disturbs
  -- another and nothing needs clearing between them.
  DECLARE i INT;
  DECLARE s VARCHAR;
  s := '';
  FOR (i := 0; i < n - 1; i := i + 1)
    s := s || sprintf ('<urn:cw:n%d> <urn:cw:e> <urn:cw:n%d> . ', i, i + 1);
  DB.DBA.TTLP (s, '', sprintf ('urn:cw:g%d', n));
  COMMIT WORK;
}
;

CREATE PROCEDURE GTEST_CW_UNIT_WEIGHTS (IN n INT)
{
  -- The [subject, object, weight] vector form, so the weights arrive
  -- without writing reification triples the other cases would then see.
  DECLARE i INT;
  DECLARE v ANY;
  v := make_array (n - 1, 'any');
  FOR (i := 0; i < n - 1; i := i + 1)
    v[i] := vector (sprintf ('urn:cw:n%d', i),
                    sprintf ('urn:cw:n%d', i + 1), 1.0);
  RETURN v;
}
;

CREATE PROCEDURE GTEST_J14 ()
{
  DECLARE sizes ANY;
  DECLARE i INT;
  DECLARE n INT;
  DECLARE g VARCHAR;
  DECLARE w, u DOUBLE PRECISION;
  -- 8 is the size of every other weighted case here; 64 is the last size
  -- the old single-word visited set could represent; 65 is the first it
  -- could not; 100 is past it by enough that the damage is unmistakable.
  sizes := vector (8, 64, 65, 100);
  FOR (i := 0; i < length (sizes); i := i + 1)
    {
      n := sizes[i];
      g := sprintf ('urn:cw:g%d', n);
      GTEST_CW_CHAIN (n);
      w := GRAPH_CLOSENESS_WEIGHTED ('urn:cw:n0', g, 'urn:cw:e',
                                     GTEST_CW_UNIT_WEIGHTS (n));
      u := GRAPH_CLOSENESS ('urn:cw:n0', g, 'urn:cw:e');
      IF (w IS NULL OR u IS NULL)
        RETURN sprintf ('n=%d null: %s / %s', n,
                        CAST (w AS VARCHAR), CAST (u AS VARCHAR));
      IF (w <> u)
        RETURN sprintf ('n=%d weighted %.17g <> unweighted %.17g', n, w, u);
    }
  RETURN 'AGREE';
}
;
SELECT GTEST_J14 ();
ECHO BOTH ": J14 unit-weighted closeness = unweighted, 8..100 nodes = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

-- J.15: the same identity read out at every node, not just the chain head.
--
-- graph_algo_closeness_weighted computes all sources in one call and the
-- BIF returns one node's entry, so J.14 already runs the whole pass -- but
-- it only ever inspects one number out of it.  A visited set that is right
-- for the first source and wrong for a later one, or right for low node
-- indices and wrong for high ones, would satisfy J.14 and still be broken.
-- This walks the full score array through the BIF instead, and reports the
-- first node where the two definitions part company.
CREATE PROCEDURE GTEST_J15 ()
{
  DECLARE n, i, bad INT;
  DECLARE g, node, firstbad VARCHAR;
  DECLARE wv ANY;
  DECLARE w, u DOUBLE PRECISION;
  n := 100;
  g := sprintf ('urn:cw:g%d', n);
  GTEST_CW_CHAIN (n);
  wv := GTEST_CW_UNIT_WEIGHTS (n);
  bad := 0;
  firstbad := '';
  FOR (i := 0; i < n; i := i + 1)
    {
      node := sprintf ('urn:cw:n%d', i);
      w := GRAPH_CLOSENESS_WEIGHTED (node, g, 'urn:cw:e', wv);
      u := GRAPH_CLOSENESS (node, g, 'urn:cw:e');
      IF (w <> u)
        {
          bad := bad + 1;
          -- held in its own variable: `node` is rebuilt every iteration,
          -- so reporting through it would name the last node examined
          -- rather than the first one that disagreed.
          IF (bad = 1)
            firstbad := sprintf ('first n%d: %.17g <> %.17g', i, w, u);
        }
    }
  IF (bad > 0) RETURN sprintf ('%d of %d nodes disagree, %s', bad, n, firstbad);
  RETURN 'AGREE';
}
;
SELECT GTEST_J15 ();
ECHO BOTH ": J15 the identity at every node of a 100-node chain = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

-- J.16: weighted betweenness against a closed form, above and below 64 nodes.
--
-- graph_algo_betweenness_weighted kept its Dijkstra visited set in a single
-- uint64_t, exactly as the weighted closeness did.  Only the first 64 node
-- indices had a bit of their own, `visited >> i` is undefined for i >= 64,
-- and on this hardware it reads bit (i & 63) -- so settling a high-index
-- node marked a low-index one visited and Brandes accumulated over paths
-- that were not the shortest ones.
--
-- On a directed chain the answer is known without running anything: the
-- only path from s to t is the one through every node between them, so
-- node k lies on exactly (k) * (n-1-k) of them, and the normalisation
-- divides by (n-1)(n-2).  That is a real expectation rather than a
-- reading, and it holds at any n -- which is what lets one case cover
-- both sides of the boundary.
--
-- normalized and directed are passed explicitly.  They were the defaults
-- when this case was written and are not any more, and the closed form
-- above is the directed one -- so naming them keeps the case asserting
-- what it was built to assert.
--
-- 60 nodes fits the old single word and passed; 100 did not and came back
-- 0.15986394557823129 where the answer is 0.25252525252525254 -- low by
-- more than a third, with nothing to say so.
CREATE PROCEDURE GTEST_BW_CHAIN (IN n INT)
{
  DECLARE i INT;
  DECLARE s VARCHAR;
  s := '';
  FOR (i := 0; i < n - 1; i := i + 1)
    s := s || sprintf ('<urn:bw:n%d> <urn:bw:e> <urn:bw:n%d> . ', i, i + 1);
  DB.DBA.TTLP (s, '', sprintf ('urn:bw:g%d', n));
  COMMIT WORK;
}
;

CREATE PROCEDURE GTEST_BW_UNIT_WEIGHTS (IN n INT)
{
  DECLARE i INT;
  DECLARE v ANY;
  v := make_array (n - 1, 'any');
  FOR (i := 0; i < n - 1; i := i + 1)
    v[i] := vector (sprintf ('urn:bw:n%d', i), sprintf ('urn:bw:n%d', i + 1), 1.0);
  RETURN v;
}
;

CREATE PROCEDURE GTEST_J16 ()
{
  DECLARE sizes ANY;
  DECLARE si, k, n INT;
  DECLARE g VARCHAR;
  DECLARE wv ANY;
  DECLARE got, want DOUBLE PRECISION;
  -- 8 and 60 sit inside the word that worked; 65 is the first that did not
  -- and 100 is past it far enough that the shortfall is unmistakable.
  sizes := vector (8, 60, 65, 100);
  FOR (si := 0; si < length (sizes); si := si + 1)
    {
      n := sizes[si];
      g := sprintf ('urn:bw:g%d', n);
      GTEST_BW_CHAIN (n);
      wv := GTEST_BW_UNIT_WEIGHTS (n);
      -- every interior node, not just the middle one: a visited set that
      -- is right for low indices and wrong for high ones would survive a
      -- single sample, and which node lands on which index is the node
      -- map's business, not this file's.
      FOR (k := 1; k < n - 1; k := k + 1)
        {
          got := GRAPH_BETWEENNESS_WEIGHTED (sprintf ('urn:bw:n%d', k), g, 'urn:bw:e', wv, 1, 1);
          want := (k * cast (n - 1 - k AS DOUBLE PRECISION))
                  / ((n - 1) * cast (n - 2 AS DOUBLE PRECISION));
          IF (abs (got - want) > 0.000000001)
            RETURN sprintf ('n=%d k=%d got %.17g want %.17g', n, k, got, want);
        }
    }
  RETURN 'CLOSED FORM';
}
;
SELECT GTEST_J16 ();
ECHO BOTH ": J16 weighted betweenness on a chain, 8..100 nodes = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "CLOSED FORM" "PASSED" "***FAILED";

-- J.17: weighted betweenness equals unweighted betweenness when every edge
-- weighs 1 -- the same identity J.14 and J.15 hold closeness to, and the
-- assertion that gives the aligned defaults their meaning.
--
-- Until this branch the two were not comparable at all, and not because of
-- the weights.  GRAPH_BETWEENNESS_WEIGHTED passed NULL parameters, so it
-- ran on GRAPH_BETWEENNESS_DEFAULT -- normalized and directed both true --
-- where GRAPH_BETWEENNESS defaults both to 0; and the library's weighted
-- path ignored `directed` outright, hardcoding OUTGOING and INCOMING, so
-- it answered the directed question however it was asked.  Two different
-- measures wearing one name, with no argument to pick between them.
--
-- With the defaults aligned and `directed` honoured, the two are one
-- measure again, and a graph whose edges all weigh 1 is where that has to
-- show: a Dijkstra distance over unit weights is a hop count, so the two
-- are computing the same thing by different routes -- Dijkstra against
-- BFS, a linear-scan frontier against a queue.  Compared to a tolerance
-- rather than exactly, because that is the one claim here that is about
-- floating-point accumulation order and not about arithmetic: the two
-- walks push dependencies onto the stack in different orders, and Brandes'
-- backward pass is a sum of quotients.
CREATE PROCEDURE GTEST_J17 ()
{
  DECLARE sizes ANY;
  DECLARE si, k, n, bad INT;
  DECLARE g, firstbad VARCHAR;
  DECLARE wv ANY;
  DECLARE w, u DOUBLE PRECISION;
  sizes := vector (8, 65, 100);
  bad := 0; firstbad := '';
  FOR (si := 0; si < length (sizes); si := si + 1)
    {
      n := sizes[si];
      g := sprintf ('urn:bw:g%d', n);
      GTEST_BW_CHAIN (n);
      wv := GTEST_BW_UNIT_WEIGHTS (n);
      FOR (k := 0; k < n; k := k + 1)
        {
          w := GRAPH_BETWEENNESS_WEIGHTED (sprintf ('urn:bw:n%d', k), g, 'urn:bw:e', wv);
          u := GRAPH_BETWEENNESS (sprintf ('urn:bw:n%d', k), g, 'urn:bw:e');
          IF (abs (w - u) > 0.000000001)
            {
              bad := bad + 1;
              IF (bad = 1)
                firstbad := sprintf ('first n=%d k=%d: %.17g <> %.17g', n, k, w, u);
            }
        }
    }
  IF (bad > 0) RETURN sprintf ('%d disagree, %s', bad, firstbad);
  RETURN 'AGREE';
}
;
SELECT GTEST_J17 ();
ECHO BOTH ": J17 unit-weighted betweenness = unweighted, 8..100 nodes = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

-- ============================================================================
-- Group R: undirected traversal and undirected PageRank
-- ============================================================================
-- An undirected graph is held one direction per edge, so walking it means
-- asking for direction 2 and for a symmetric PageRank neighbourhood.  Both
-- are opt-in: every value pinned above is the directed one and none of it
-- moves.  Group Q checks the same behaviour against another
-- implementation's published output; this group checks it on the fixture
-- the rest of this file uses, where the answers are readable by eye.
--
-- On the fixture, E has one edge and it is incoming (D -> E).  Following
-- out-edges from E therefore reaches nothing, and following both reaches
-- D, then B and C, then A.

-- R.1: BFS from E to A, both directions: E-D-B-A or E-D-C-A, so 3.
SELECT GRAPH_BFS ('urn:graph:test:E', 'urn:graph:test:A', 'urn:graph:test',
                  'urn:graph:test:edge', 2);
ECHO BOTH ": R1 bfs(E, A, both) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";

-- R.2: ... and out-edges only still reaches nothing, so the default has
-- not quietly become symmetric.
SELECT GRAPH_BFS ('urn:graph:test:E', 'urn:graph:test:A', 'urn:graph:test',
                  'urn:graph:test:edge', 0);
ECHO BOTH ": R2 bfs(E, A, out) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";

-- R.3: reachable count from E, both directions: E, D, B, C, A.
SELECT GRAPH_BFS ('urn:graph:test:E', NULL, 'urn:graph:test',
                  'urn:graph:test:edge', 2);
ECHO BOTH ": R3 reachable from E, both = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";

-- R.4: out-edges only, that is E alone.
SELECT GRAPH_BFS ('urn:graph:test:E', NULL, 'urn:graph:test',
                  'urn:graph:test:edge', 0);
ECHO BOTH ": R4 reachable from E, out = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- R.5: walking both ways does not join the two components: F is still
-- unreachable from A.
SELECT GRAPH_BFS ('urn:graph:test:A', 'urn:graph:test:F', 'urn:graph:test',
                  'urn:graph:test:edge', 2);
ECHO BOTH ": R5 bfs(A, F, both) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";

-- R.6: the weighted traversal takes the same direction argument.  No
-- weights are given, so every edge costs 1 and the cost equals the hop
-- count R.1 reports.  (Naming a weight predicate that matches nothing is
-- refused with VGSLW04 since 3da13a1a39, so no predicate is named here.)
SELECT CAST (GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:graph:test:E',
         'urn:graph:test:A', 'urn:graph:test', 'urn:graph:test:edge',
         NULL, 2) AS VARCHAR);
ECHO BOTH ": R6 weighted length(E, A, both) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";

-- R.7: and at direction 0 there is no path, so it is NULL rather than a
-- number that happens to look plausible.
CREATE PROCEDURE GTEST_R7 ()
{
  DECLARE v DOUBLE PRECISION;
  v := GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:graph:test:E', 'urn:graph:test:A',
         'urn:graph:test', 'urn:graph:test:edge',
         NULL, 0);
  RETURN CASE WHEN v IS NULL THEN 'NULL' ELSE CAST (v AS VARCHAR) END;
}
;
SELECT GTEST_R7 ();
ECHO BOTH ": R7 weighted length(E, A, out) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] NULL "PASSED" "***FAILED";

-- R.8: undirected PageRank of A, pinned.  A.5 pins the directed value on
-- the same fixture and must not move; these two differ, which is the point.
SELECT CAST (GRAPH_PAGERANK ('urn:graph:test:A', 'urn:graph:test',
        'urn:graph:test:edge', 0.85, 100, 0.000001, 0) AS VARCHAR);
ECHO BOTH ": R8 undirected pagerank(A) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.1450705938042077 "PASSED" "***FAILED";

-- R.9: the directed value is still the default, whether or not the
-- argument is given.
CREATE PROCEDURE GTEST_R9 ()
{
  DECLARE a, b, c DOUBLE PRECISION;
  a := GRAPH_PAGERANK ('urn:graph:test:A', 'urn:graph:test', 'urn:graph:test:edge');
  b := GRAPH_PAGERANK ('urn:graph:test:A', 'urn:graph:test', 'urn:graph:test:edge',
                       0.85, 100, 0.000001, 1);
  c := GRAPH_PAGERANK ('urn:graph:test:A', 'urn:graph:test', 'urn:graph:test:edge',
                       0.85, 100, 0.000001, 0);
  IF (a <> b) RETURN 'default is not the directed form';
  IF (a = c) RETURN 'undirected served the directed cached vector';
  RETURN 'DEFAULT IS DIRECTED';
}
;
SELECT GTEST_R9 ();
ECHO BOTH ": R9 default vs explicit directed = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "DEFAULT IS DIRECTED" "PASSED" "***FAILED";

-- R.10: results do not depend on enable_qp, undirected form included.
CREATE PROCEDURE GTEST_R10 ()
{
  DECLARE seq_pr, par_pr DOUBLE PRECISION;
  DECLARE seq_bfs, par_bfs INT;
  __dbf_set ('enable_qp', 1);
  seq_pr := GRAPH_PAGERANK ('urn:graph:test:A', 'urn:graph:test',
              'urn:graph:test:edge', 0.85, 100, 0.000001, 0);
  seq_bfs := GRAPH_BFS ('urn:graph:test:E', 'urn:graph:test:A', 'urn:graph:test',
               'urn:graph:test:edge', 2);
  __dbf_set ('enable_qp', 8);
  par_pr := GRAPH_PAGERANK ('urn:graph:test:A', 'urn:graph:test',
              'urn:graph:test:edge', 0.85, 100, 0.000001, 0);
  par_bfs := GRAPH_BFS ('urn:graph:test:E', 'urn:graph:test:A', 'urn:graph:test',
               'urn:graph:test:edge', 2);
  __dbf_set ('enable_qp', 1);
  IF (seq_pr <> par_pr)
    RETURN sprintf ('pagerank %.17g <> %.17g', seq_pr, par_pr);
  IF (seq_bfs <> par_bfs)
    RETURN sprintf ('bfs %d <> %d', seq_bfs, par_bfs);
  RETURN 'IDENTICAL';
}
;
SELECT GTEST_R10 ();
ECHO BOTH ": R10 undirected forms are enable_qp independent = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] IDENTICAL "PASSED" "***FAILED";

-- R.11: weights written the way RDF 1.2 Turtle writes them.  Virtuoso's
-- parser turns << s p o >> into a BLANK NODE reifier plus an rdf:reifies
-- triple pointing at the triple term, not into a reifier IRI, so the
-- weighted algorithms used to load this file cleanly and then weigh every
-- edge at the default of 1.  Two hops of 0.25 cost 0.5, not 2.
CREATE PROCEDURE GTEST_R11 ()
{
  DECLARE v DOUBLE PRECISION;
  DB.DBA.TTLP (
    '<urn:graph:ttl:1> <urn:graph:ttl:e> <urn:graph:ttl:2> . ' ||
    '<urn:graph:ttl:2> <urn:graph:ttl:e> <urn:graph:ttl:3> . ' ||
    '<< <urn:graph:ttl:1> <urn:graph:ttl:e> <urn:graph:ttl:2> >> <urn:graph:ttl:w> 0.25 . ' ||
    '<< <urn:graph:ttl:2> <urn:graph:ttl:e> <urn:graph:ttl:3> >> <urn:graph:ttl:w> 0.25 . ',
    '', 'urn:graph:ttl:g');
  COMMIT WORK;
  v := GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:graph:ttl:1', 'urn:graph:ttl:3',
         'urn:graph:ttl:g', 'urn:graph:ttl:e', iri_to_id ('urn:graph:ttl:w'), 0);
  IF (v IS NULL) RETURN 'no path';
  IF (abs (v - 0.5) > 0.000000001) RETURN CAST (v AS VARCHAR);
  RETURN 'READ';
}
;
SPARQL CLEAR GRAPH <urn:graph:ttl:g>;
SELECT GTEST_R11 ();
ECHO BOTH ": R11 RDF 1.2 << >> weights = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] READ "PASSED" "***FAILED";
SPARQL CLEAR GRAPH <urn:graph:ttl:g>;

-- R.12: the same weights in RDF 1.2's *other* spelling -- the annotation
-- syntax, `s p o {| w 0.25 |}`, which is how a writer that wants to state
-- the triple and annotate it in one breath produces it.
--
-- It is a separate case rather than a variant of R.11 because the two are
-- not the same input. The annotation form asserts the base triple as well
-- as the annotation, so this file has no separate `s p o .` line; the
-- `<< >>` form asserts only the annotation, and R.11 states its edges
-- separately. Both end as a blank-node reifier plus rdf:reifies, which is
-- the shape that made R.11 necessary: get the reifier wrong and the file
-- still loads, every edge weighs the default 1.0, and two hops of 0.25
-- cost 2 instead of 0.5. A wrong answer, not an error, so only a pinned
-- distance catches it.
CREATE PROCEDURE GTEST_R12 ()
{
  DECLARE v DOUBLE PRECISION;
  DB.DBA.TTLP (
    '<urn:graph:ann:1> <urn:graph:ann:e> <urn:graph:ann:2> ' ||
    '{| <urn:graph:ann:w> 0.25 |} . ' ||
    '<urn:graph:ann:2> <urn:graph:ann:e> <urn:graph:ann:3> ' ||
    '{| <urn:graph:ann:w> 0.25 |} . ',
    '', 'urn:graph:ann:g');
  COMMIT WORK;
  v := GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:graph:ann:1', 'urn:graph:ann:3',
         'urn:graph:ann:g', 'urn:graph:ann:e', iri_to_id ('urn:graph:ann:w'), 0);
  IF (v IS NULL) RETURN 'no path';
  IF (abs (v - 0.5) > 0.000000001) RETURN CAST (v AS VARCHAR);
  RETURN 'READ';
}
;
SPARQL CLEAR GRAPH <urn:graph:ann:g>;
SELECT GTEST_R12 ();
ECHO BOTH ": R12 RDF 1.2 {| |} annotation weights = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] READ "PASSED" "***FAILED";
SPARQL CLEAR GRAPH <urn:graph:ann:g>;

-- ============================================================================
-- Group S: harmonic centrality, HITS, and batch Jaccard
-- ============================================================================
--
-- These three were implemented in the library from the first import but
-- reachable from nothing -- no BIF, no predicate, no caller.  Exposing
-- them means their arithmetic is asserted here for the first time, so the
-- expectations below are derived from the fixture by hand rather than
-- captured from a run: a pin taken from the code under test would only
-- assert that it still does what it does.
--
-- Values use PL comparisons rather than STR() equality throughout.  Three
-- of the harmonic scores and two of the HITS scores are exact small
-- integers or zero, and STR() of a DOUBLE is not a stable spelling of
-- those across CaseMode and locale settings.

-- ----------------------------------------------------------------------------
-- Harmonic centrality: sum over reachable v != u of 1/d(u,v), raw.
--
-- On the fixture, following OUTGOING edges:
--
--   H(A) = 1/1(B) + 1/1(C) + 1/2(D) + 1/3(E) = 17/6 = 2.8333...
--   H(B) = 1/1(C) + 1/1(D) + 1/2(A) + 1/2(E) = 3        exactly
--   H(C) = 1/1(A) + 1/1(D) + 1/2(B) + 1/2(E) = 3        exactly
--   H(D) = 1/1(E)                            = 1        exactly
--   H(E) = (no out-edges)                    = 0        exactly
--   H(F) = 1/1(F2)                           = 1        exactly
--
-- B and C are the useful cases: every term is a power of two, so the sum
-- is exact in binary whatever order the node map puts them in.  H(A) has
-- a 1/3 in it and is therefore only pinned to a tolerance -- the last bit
-- depends on summation order, which the node map decides.
-- ----------------------------------------------------------------------------

CREATE PROCEDURE GTEST_S1 ()
{
  DECLARE ha, hb, hc, hd, he, hf DOUBLE PRECISION;
  ha := GRAPH_HARMONIC ('urn:graph:test:A', 'urn:graph:test', 'urn:graph:test:edge');
  hb := GRAPH_HARMONIC ('urn:graph:test:B', 'urn:graph:test', 'urn:graph:test:edge');
  hc := GRAPH_HARMONIC ('urn:graph:test:C', 'urn:graph:test', 'urn:graph:test:edge');
  hd := GRAPH_HARMONIC ('urn:graph:test:D', 'urn:graph:test', 'urn:graph:test:edge');
  he := GRAPH_HARMONIC ('urn:graph:test:E', 'urn:graph:test', 'urn:graph:test:edge');
  hf := GRAPH_HARMONIC ('urn:graph:test:F', 'urn:graph:test', 'urn:graph:test:edge');
  IF (hb <> 3.0) RETURN 'B ' || CAST (hb AS VARCHAR);
  IF (hc <> 3.0) RETURN 'C ' || CAST (hc AS VARCHAR);
  IF (hd <> 1.0) RETURN 'D ' || CAST (hd AS VARCHAR);
  IF (he <> 0.0) RETURN 'E ' || CAST (he AS VARCHAR);
  IF (hf <> 1.0) RETURN 'F ' || CAST (hf AS VARCHAR);
  IF (abs (ha - 2.8333333333333335) > 0.000000000001) RETURN 'A ' || CAST (ha AS VARCHAR);
  RETURN 'EXACT';
}
;
SELECT GTEST_S1 ();
ECHO BOTH ": S1 harmonic pinned values = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] EXACT "PASSED" "***FAILED";

-- S.2: harmonic is not closeness under another name.  Both are read off
-- the same BFS, and the only thing separating them is which branch of
-- closeness_compute_one runs -- so a wiring mistake that left the flag
-- clear would return a plausible number, not an error.  The two
-- disagree in magnitude on every node of this fixture and, on A, they
-- disagree by more than a factor of four.
CREATE PROCEDURE GTEST_S2 ()
{
  DECLARE h, c DOUBLE PRECISION;
  h := GRAPH_HARMONIC  ('urn:graph:test:A', 'urn:graph:test', 'urn:graph:test:edge');
  c := GRAPH_CLOSENESS ('urn:graph:test:A', 'urn:graph:test', 'urn:graph:test:edge');
  IF (abs (c - 0.5714285714285714) > 0.000000000001) RETURN 'closeness ' || CAST (c AS VARCHAR);
  IF (abs (h - 2.8333333333333335) > 0.000000000001) RETURN 'harmonic ' || CAST (h AS VARCHAR);
  IF (h <= c) RETURN 'not distinct';
  RETURN 'DISTINCT';
}
;
SELECT GTEST_S2 ();
ECHO BOTH ": S2 harmonic <> closeness = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] DISTINCT "PASSED" "***FAILED";

-- S.3: harmonic in predicate position, graph scope injected from FROM
SPARQL
SELECT ?node ?h
FROM <urn:graph:test>
WHERE {
    ?node <urn:graph:test:edge> ?o .
    ?node bif:harmonic ?h .
}
ORDER BY DESC(?h) ?node
LIMIT 3;
ECHO BOTH ": S3 predicate harmonic state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": S3 rows = " $ROWCNT "\n";
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";

-- S.4: harmonic in expression position agrees with the scalar SQL form.
-- B and C tie at exactly 3, so the comparison has to be an equality and
-- not an ordering: an implementation that returned closeness here would
-- also tie them, but at 0.6666 rather than 3.
SPARQL
SELECT (STR(bif:harmonic(<urn:graph:test:B>, <urn:graph:test>, <urn:graph:test:edge>)
            = bif:harmonic(<urn:graph:test:C>, <urn:graph:test>, <urn:graph:test:edge>)) AS ?s4)
FROM <urn:graph:test>
WHERE { ?s <urn:graph:test:edge> ?o }
LIMIT 1;
ECHO BOTH ": S4 harmonic(B) = harmonic(C) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "true" "PASSED" "***FAILED";

-- S.5: NORMALIZED is a harmonic option and must be honoured, not merely
-- accepted.  It used to be refused here, on the ground that the harmonic
-- branch ignored the flag the two measures share, so the option would
-- have been taken and silently dropped.  The branch now divides by n-1.
--
-- What is checked is the shape of the division rather than its result.
-- This graph is written to by a dozen groups before this line, so its
-- node count is not a constant anyone should pin -- an earlier draft of
-- this test asserted raw/9 and was wrong by the time it ran, the divisor
-- being 6.  The claim that survives that is: the raw value is still S.1's,
-- the normalized one is smaller, and the ratio between them is a whole
-- number, which it can only be if n-1 is what it divided by.
--
-- AK.7 and AK.15 pin the arithmetic exactly, on a four-node graph that
-- nothing else touches.
CREATE PROCEDURE GTEST_S5_HARM_NORM ()
{
  DECLARE raw, nrm, k DOUBLE PRECISION;
  raw := GRAPH_HARMONIC ('urn:graph:test:A', 'urn:graph:test', 'urn:graph:test:edge', 0, 0);
  nrm := GRAPH_HARMONIC ('urn:graph:test:A', 'urn:graph:test', 'urn:graph:test:edge', 0, 1);
  IF (raw IS NULL OR nrm IS NULL)
    RETURN 'NULL';
  IF (ABS (raw - 2.8333333333333335) > 0.000000000001)
    RETURN 'raw ' || CAST (raw AS VARCHAR);
  IF (nrm <= 0 OR nrm >= raw)
    RETURN 'normalized did not move: ' || CAST (nrm AS VARCHAR);
  k := raw / nrm;
  IF (k < 2 OR ABS (k - ROUND (k)) > 0.000000001)
    RETURN 'divisor ' || CAST (k AS VARCHAR) || ' is not a node count less one';
  RETURN 'NORMALIZED';
}
;

SELECT GTEST_S5_HARM_NORM ();
ECHO BOTH ": S5 harmonic honours normalized = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] NORMALIZED "PASSED" "***FAILED";

-- ----------------------------------------------------------------------------
-- HITS: hub and authority, by power iteration with L2 normalisation.
--
-- hub(u)  = sum of auth(v) over u's out-neighbours
-- auth(v) = sum of hub(u)  over v's in-neighbours
--
-- The fixed point on this fixture (computed independently, to 1e-9):
--
--        hub          auth
--   A    0.5          0.2705980
--   B    0.7071068    0.2705980
--   C    0.5          0.6532815
--   D    0            0.6532815
--   E    0            0
--   F    0            0
--   F2   0            0
--
-- D and F reach zero hub, and E and F2 zero auth, only in the limit;
-- at the default tolerance of 1e-6 they stop at around 7e-8, so those
-- are asserted as "small", not as zero.  E and F2 have no out-edges at
-- all and F has no in-edges, so those three ARE exactly zero at every
-- iteration and are asserted as such.
-- ----------------------------------------------------------------------------

CREATE PROCEDURE GTEST_S6 ()
{
  DECLARE ha, hb, hc, he, hf2 DOUBLE PRECISION;
  DECLARE aa, ac, ad, af DOUBLE PRECISION;
  ha  := GRAPH_HITS_HUB ('urn:graph:test:A', 'urn:graph:test', 'urn:graph:test:edge');
  hb  := GRAPH_HITS_HUB ('urn:graph:test:B', 'urn:graph:test', 'urn:graph:test:edge');
  hc  := GRAPH_HITS_HUB ('urn:graph:test:C', 'urn:graph:test', 'urn:graph:test:edge');
  he  := GRAPH_HITS_HUB ('urn:graph:test:E', 'urn:graph:test', 'urn:graph:test:edge');
  hf2 := GRAPH_HITS_HUB ('urn:graph:test:F2', 'urn:graph:test', 'urn:graph:test:edge');
  aa  := GRAPH_HITS_AUTHORITY ('urn:graph:test:A', 'urn:graph:test', 'urn:graph:test:edge');
  ac  := GRAPH_HITS_AUTHORITY ('urn:graph:test:C', 'urn:graph:test', 'urn:graph:test:edge');
  ad  := GRAPH_HITS_AUTHORITY ('urn:graph:test:D', 'urn:graph:test', 'urn:graph:test:edge');
  af  := GRAPH_HITS_AUTHORITY ('urn:graph:test:F', 'urn:graph:test', 'urn:graph:test:edge');
  -- exactly zero at every iteration: no out-edges, resp. no in-edges
  IF (he  <> 0.0) RETURN 'hub(E) '   || CAST (he AS VARCHAR);
  IF (hf2 <> 0.0) RETURN 'hub(F2) '  || CAST (hf2 AS VARCHAR);
  IF (af  <> 0.0) RETURN 'auth(F) '  || CAST (af AS VARCHAR);
  -- the fixed point, to the tolerance the iteration is asked to reach
  IF (abs (ha - 0.5)       > 0.00001) RETURN 'hub(A) '  || CAST (ha AS VARCHAR);
  IF (abs (hc - 0.5)       > 0.00001) RETURN 'hub(C) '  || CAST (hc AS VARCHAR);
  IF (abs (hb - 0.7071068) > 0.00001) RETURN 'hub(B) '  || CAST (hb AS VARCHAR);
  IF (abs (aa - 0.2705980) > 0.00001) RETURN 'auth(A) ' || CAST (aa AS VARCHAR);
  IF (abs (ac - 0.6532815) > 0.00001) RETURN 'auth(C) ' || CAST (ac AS VARCHAR);
  IF (abs (ad - 0.6532815) > 0.00001) RETURN 'auth(D) ' || CAST (ad AS VARCHAR);
  RETURN 'FIXPOINT';
}
;
SELECT GTEST_S6 ();
ECHO BOTH ": S6 HITS fixed point = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] FIXPOINT "PASSED" "***FAILED";

-- S.7: the signature of HITS -- hub and authority are two rankings, not
-- one vector read twice.  D is the joint-best authority (B and C both
-- point at it) and simultaneously the worst hub of the four connected
-- nodes (it points only at E, a dead end).  A is the reverse: a decent
-- hub with a weak authority.  So the two orderings invert between A and
-- D.  No single-vector measure -- PageRank, eigenvector, degree -- can
-- produce that, which is what makes this the case that would catch a
-- BIF wired to the wrong half of the pair.
CREATE PROCEDURE GTEST_S7 ()
{
  DECLARE hubA, hubD, authA, authD DOUBLE PRECISION;
  hubA  := GRAPH_HITS_HUB       ('urn:graph:test:A', 'urn:graph:test', 'urn:graph:test:edge');
  hubD  := GRAPH_HITS_HUB       ('urn:graph:test:D', 'urn:graph:test', 'urn:graph:test:edge');
  authA := GRAPH_HITS_AUTHORITY ('urn:graph:test:A', 'urn:graph:test', 'urn:graph:test:edge');
  authD := GRAPH_HITS_AUTHORITY ('urn:graph:test:D', 'urn:graph:test', 'urn:graph:test:edge');
  IF (NOT (hubA > hubD))   RETURN 'hub(A) !> hub(D)';
  IF (NOT (authD > authA)) RETURN 'auth(D) !> auth(A)';
  RETURN 'INVERTS';
}
;
SELECT GTEST_S7 ();
ECHO BOTH ": S7 HITS hub/auth orderings invert = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] INVERTS "PASSED" "***FAILED";

-- S.8: both halves in predicate position in one query.  They are two
-- reads of a single cached pair, so this also asserts that asking for
-- both in one pattern resolves.
SPARQL
SELECT ?node ?hub ?auth
FROM <urn:graph:test>
WHERE {
    ?node <urn:graph:test:edge> ?o .
    ?node bif:hits_hub ?hub .
    ?node bif:hits_authority ?auth .
}
ORDER BY DESC(?hub) ?node
LIMIT 3;
ECHO BOTH ": S8 predicate hits_hub + hits_authority state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": S8 rows = " $ROWCNT "\n";
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";

-- S.9: HITS honours max_iter.  One iteration from the all-ones start
-- cannot have reached the fixed point, so a run capped at 1 must differ
-- from the converged run.  This is the assertion that fails if the
-- OPTION is parsed and then dropped on the floor.
CREATE PROCEDURE GTEST_S9 ()
{
  DECLARE conv, capped DOUBLE PRECISION;
  conv := GRAPH_HITS_HUB ('urn:graph:test:B', 'urn:graph:test', 'urn:graph:test:edge');
  capped := GRAPH_HITS_HUB ('urn:graph:test:B', 'urn:graph:test', 'urn:graph:test:edge', 1);
  IF (abs (conv - 0.7071068) > 0.00001) RETURN 'converged ' || CAST (conv AS VARCHAR);
  IF (abs (capped - conv) < 0.0001) RETURN 'max_iter ignored';
  RETURN 'HONOURED';
}
;
SELECT GTEST_S9 ();
ECHO BOTH ": S9 HITS max_iter honoured = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] HONOURED "PASSED" "***FAILED";

-- S.10: WEIGHT is not a HITS option.  There is no weighted HITS in the
-- library, so accepting the option would mean accepting it and running
-- the unweighted algorithm.
SPARQL PREFIX bif: <http://www.openlinksw.com/schemas/bif#>
SELECT ?h FROM <urn:graph:test> WHERE {
  <urn:graph:test:A> <urn:graph:test:edge> ?o .
  <urn:graph:test:A> bif:hits_hub ?h OPTION (weight <urn:graph:test:weight>) . } LIMIT 1;
ECHO BOTH ": S10 hits_hub rejects weight state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE 37000 "PASSED" "***FAILED";

-- ----------------------------------------------------------------------------
-- Batch Jaccard: one call for many pairs.
--
-- GRAPH_JACCARD_BATCH takes two equal-length vectors of node IRIs and
-- returns a vector of similarities, pairing them elementwise.  It
-- resolves the graph once for the whole list instead of once per pair,
-- which is the only reason it exists; the arithmetic per pair is the
-- scalar BIF's, so the test that matters is that the two agree.
-- ----------------------------------------------------------------------------

CREATE PROCEDURE GTEST_S11 ()
{
  DECLARE v ANY;
  v := GRAPH_JACCARD_BATCH (
         vector ('urn:graph:test:A', 'urn:graph:test:B', 'urn:graph:test:A'),
         vector ('urn:graph:test:B', 'urn:graph:test:C', 'urn:graph:test:C'),
         'urn:graph:test', 'urn:graph:test:edge');
  IF (length (v) <> 3) RETURN 'length ' || CAST (length (v) AS VARCHAR);
  -- out(A)={B,C} out(B)={C,D}: intersection {C}, union {B,C,D}
  IF (abs (v[0] - 0.3333333333333333) > 0.000000000001) RETURN 'AB ' || CAST (v[0] AS VARCHAR);
  -- out(B)={C,D} out(C)={A,D}: intersection {D}, union {A,C,D}
  IF (abs (v[1] - 0.3333333333333333) > 0.000000000001) RETURN 'BC ' || CAST (v[1] AS VARCHAR);
  -- out(A)={B,C} out(C)={A,D}: disjoint
  IF (v[2] <> 0.0) RETURN 'AC ' || CAST (v[2] AS VARCHAR);
  RETURN 'PINNED';
}
;
SELECT GTEST_S11 ();
ECHO BOTH ": S11 batch jaccard pinned values = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] PINNED "PASSED" "***FAILED";

-- S.12: batch agrees with the scalar BIF pair for pair, bit for bit.
-- The batch form delegates to the same function, so any disagreement is
-- a wiring fault -- a mispaired vector, a direction that defaults
-- differently, or a graph resolved from the wrong argument.  Includes
-- the two degenerate pairs: a node against itself (union = its own
-- neighbours, so 1) and two nodes that both have no out-edges (empty
-- union, which the library reports as 0 rather than as undefined).
CREATE PROCEDURE GTEST_S12 ()
{
  DECLARE a, b, v ANY;
  DECLARE i INT;
  DECLARE s DOUBLE PRECISION;
  a := vector ('urn:graph:test:A', 'urn:graph:test:B', 'urn:graph:test:A',
               'urn:graph:test:A', 'urn:graph:test:E', 'urn:graph:test:A');
  b := vector ('urn:graph:test:B', 'urn:graph:test:C', 'urn:graph:test:C',
               'urn:graph:test:A', 'urn:graph:test:F2', 'urn:graph:test:F');
  v := GRAPH_JACCARD_BATCH (a, b, 'urn:graph:test', 'urn:graph:test:edge');
  IF (length (v) <> 6) RETURN 'length ' || CAST (length (v) AS VARCHAR);
  FOR (i := 0; i < 6; i := i + 1)
    {
      s := GRAPH_JACCARD_SIMILARITY (a[i], b[i], 'urn:graph:test', 'urn:graph:test:edge');
      IF (v[i] <> s)
        RETURN CAST (i AS VARCHAR) || ': ' || CAST (v[i] AS VARCHAR)
               || ' <> ' || CAST (s AS VARCHAR);
    }
  IF (v[3] <> 1.0) RETURN 'self ' || CAST (v[3] AS VARCHAR);
  IF (v[4] <> 0.0) RETURN 'empty ' || CAST (v[4] AS VARCHAR);
  RETURN 'AGREE';
}
;
SELECT GTEST_S12 ();
ECHO BOTH ": S12 batch jaccard = scalar jaccard = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

-- S.13: mismatched vector lengths are an error, not a short read of the
-- longer one and not a walk off the end of the shorter.
CREATE PROCEDURE GTEST_S13 ()
{
  DECLARE v ANY;
  DECLARE exit HANDLER FOR SQLSTATE '*'
    {
      -- Pinned to the graph module's own invalid-argument state, not to
      -- "any error".  An unbound function raises too, so a wildcard
      -- handler would report this case as rejected on a server where the
      -- BIF does not exist at all.
      IF (__SQL_STATE = '42002') RETURN 'REJECTED';
      RETURN 'wrong state ' || __SQL_STATE;
    };
  v := GRAPH_JACCARD_BATCH (
         vector ('urn:graph:test:A', 'urn:graph:test:B'),
         vector ('urn:graph:test:B'),
         'urn:graph:test', 'urn:graph:test:edge');
  RETURN 'accepted, length ' || CAST (length (v) AS VARCHAR);
}
;
SELECT GTEST_S13 ();
ECHO BOTH ": S13 batch jaccard length mismatch = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] REJECTED "PASSED" "***FAILED";

-- S.14: an empty pair list is a legal call returning an empty vector,
-- not an error and not NULL.  A caller building the vectors from a query
-- gets this whenever the query matched nothing.
CREATE PROCEDURE GTEST_S14 ()
{
  DECLARE v ANY;
  v := GRAPH_JACCARD_BATCH (vector (), vector (),
                            'urn:graph:test', 'urn:graph:test:edge');
  IF (v IS NULL) RETURN 'null';
  IF (length (v) <> 0) RETURN 'length ' || CAST (length (v) AS VARCHAR);
  RETURN 'EMPTY';
}
;
SELECT GTEST_S14 ();
ECHO BOTH ": S14 batch jaccard empty list = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] EMPTY "PASSED" "***FAILED";

-- ============================================================================
-- Group T: the traversal predicates in predicate position, keyed on a source
-- ============================================================================
--
-- A predicate pattern offers two slots, subject and object, and the object
-- is where the result goes.  A traversal needs three things -- where from,
-- where to, and the answer -- so one of them has to be named elsewhere.
--
-- Until this group it was named nowhere.  The compiler passed the object,
-- an unbound result variable, as the target: `<a> bif:shortest_path_length
-- ?d` asked for the distance from <a> to nothing and failed at run time
-- with `42001, node argument is NULL`.  bif:bfs did not fail, which was
-- worse -- with no target it answers a different question, the size of the
-- reachable set, and bound that to a variable the query had called ?dist.
--
-- OPTION (source_node ...) names the source, which makes the subject the
-- target and the object the answer:
--
-- The keyword is `source_node`, not `source`, because SPARQL already has
-- `source` -- sparqlwords.gperf maps it to GRAPH_L, so `OPTION (source <x>)`
-- means `OPTION (graph <x>)` and would have asked for a graph named after a
-- node.  `source_node` is also what Neo4j calls it.
--
--     ?node bif:bfs ?d OPTION (source_node <a>)
--
-- reads as "?d is the distance from <a> to ?node".  That is also the shape
-- the engine was already built for -- vgraph_wg_bfs carries row_arg_index
-- 1, "args[0] is the fixed source and args[1] the target that varies per
-- row" -- so one traversal answers every row of the batch, and it is the
-- shape Neo4j's gds.bfs.stream uses, where sourceNode is required config
-- and there is no pair-at-a-time form at all.
--
-- Distances from A over this fixture, following outgoing edges:
--   A 0,  B 1,  C 1,  D 2,  E 3,  F and F2 unreachable (-1).
-- The driving pattern binds ?node to edge subjects, so A, B, C, D and F
-- appear and E and F2 do not.

-- T.1: shortest_path_length, keyed on a source.  Every node's distance is
-- pinned, including the unreachable one -- F is in another component, and
-- -1 rather than "no row" is what the scalar form returns for it.
SPARQL
SELECT (COUNT(*) AS ?t1)
FROM <urn:graph:test>
WHERE {
    ?node <urn:graph:test:edge> ?o .
    ?node bif:shortest_path_length ?d OPTION (source_node <urn:graph:test:A>) .
    FILTER ((?node = <urn:graph:test:A> && ?d != 0) ||
            (?node = <urn:graph:test:B> && ?d != 1) ||
            (?node = <urn:graph:test:C> && ?d != 1) ||
            (?node = <urn:graph:test:D> && ?d != 2) ||
            (?node = <urn:graph:test:F> && ?d != -1))
};
ECHO BOTH ": T1 source-keyed shortest_path_length wrong rows = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- T.2: bfs the same way, and it must agree with shortest_path_length --
-- they are two readings of one distance vector, so a source-keyed bfs that
-- disagreed would mean the option reached only one of them.
SPARQL
SELECT (COUNT(*) AS ?t2)
FROM <urn:graph:test>
WHERE {
    ?node <urn:graph:test:edge> ?o .
    ?node bif:bfs ?d OPTION (source_node <urn:graph:test:A>) .
    ?node bif:shortest_path_length ?sp OPTION (source_node <urn:graph:test:A>) .
    FILTER (?d != ?sp)
};
ECHO BOTH ": T2 source-keyed bfs <> shortest_path_length rows = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- T.3: and against the function form, which has always taken both
-- endpoints.  This is the assertion that says the option means what the
-- two-argument call means, rather than merely being accepted.
SPARQL
SELECT (COUNT(*) AS ?t3)
FROM <urn:graph:test>
WHERE {
    ?node <urn:graph:test:edge> ?o .
    ?node bif:shortest_path_length ?d OPTION (source_node <urn:graph:test:A>) .
    FILTER (?d != bif:shortest_path_length(<urn:graph:test:A>, ?node,
                    <urn:graph:test>, <urn:graph:test:edge>))
};
ECHO BOTH ": T3 source-keyed vs two-argument form rows = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- T.4: shortest_path returns the path itself, so it only has to resolve
-- and bind; the values are pinned by A.6 in the function form.
SPARQL
SELECT ?node ?path
FROM <urn:graph:test>
WHERE {
    ?node <urn:graph:test:edge> ?o .
    ?node bif:shortest_path ?path OPTION (source_node <urn:graph:test:A>) .
}
LIMIT 3;
ECHO BOTH ": T4 source-keyed shortest_path state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": T4 rows = " $ROWCNT "\n";
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";

-- T.5: jaccard_similarity is a pair predicate too, and takes the source the
-- same way -- "how like <A> is each node", which is the question Neo4j's
-- gds.nodeSimilarity answers.  out(A)={B,C}: against B {C,D} that is 1/3,
-- against C {A,D} nothing, against itself 1.
SPARQL
SELECT (COUNT(*) AS ?t5)
FROM <urn:graph:test>
WHERE {
    ?node <urn:graph:test:edge> ?o .
    ?node bif:jaccard_similarity ?s OPTION (source_node <urn:graph:test:A>) .
    FILTER ((?node = <urn:graph:test:A> && ?s != 1) ||
            (?node = <urn:graph:test:C> && ?s != 0) ||
            (?node = <urn:graph:test:B> && ?s < 0.333) ||
            (?node = <urn:graph:test:B> && ?s > 0.334))
};
ECHO BOTH ": T5 source-keyed jaccard wrong rows = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- T.6: the reading without a source is unchanged.  bif:bfs with no target
-- answers the size of the reachable set -- A reaches itself, B, C, D and E
-- -- and that is deliberate, so adding the option must not have taken it
-- away from anyone relying on it.
SPARQL
SELECT (COUNT(*) AS ?t6)
FROM <urn:graph:test>
WHERE {
    <urn:graph:test:A> <urn:graph:test:edge> ?o .
    <urn:graph:test:A> bif:bfs ?n .
    FILTER (?n != 5)
};
ECHO BOTH ": T6 sourceless bfs still the reachable count, wrong rows = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- T.7: shortest_path_length without a source is refused at parse time.
-- There is no reading of it: it used to pass the unbound result variable as
-- the target and fail at run time complaining that a node argument was
-- NULL, which named neither the option that was missing nor the form that
-- works.
SPARQL PREFIX bif: <http://www.openlinksw.com/schemas/bif#>
SELECT ?d FROM <urn:graph:test> WHERE {
  <urn:graph:test:A> <urn:graph:test:edge> ?o .
  <urn:graph:test:A> bif:shortest_path_length ?d . } LIMIT 1;
ECHO BOTH ": T7 sourceless shortest_path_length state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE 37000 "PASSED" "***FAILED";

-- T.8: ... and so is shortest_path, which has the same shape.
SPARQL PREFIX bif: <http://www.openlinksw.com/schemas/bif#>
SELECT ?p FROM <urn:graph:test> WHERE {
  <urn:graph:test:A> <urn:graph:test:edge> ?o .
  <urn:graph:test:A> bif:shortest_path ?p . } LIMIT 1;
ECHO BOTH ": T8 sourceless shortest_path state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE 37000 "PASSED" "***FAILED";

-- T.9: source_node is not an option every algorithm takes.  PageRank has no
-- source, and accepting one there would be accepting it and ignoring it.
SPARQL PREFIX bif: <http://www.openlinksw.com/schemas/bif#>
SELECT ?r FROM <urn:graph:test> WHERE {
  ?node <urn:graph:test:edge> ?o .
  ?node bif:pagerank ?r OPTION (source_node <urn:graph:test:A>) . } LIMIT 1;
ECHO BOTH ": T9 source_node rejected for pagerank state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE 37000 "PASSED" "***FAILED";

-- T.10: the vectored path.  One traversal has to answer the whole batch --
-- that is the reason the option is keyed this way round -- so the values
-- must be the same with the batch driver actually engaged.
SELECT GRAPH_SET_LIMIT ('MinBatch', 1);
ECHO BOTH ": T10 MinBatch lowered = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

SPARQL
SELECT (COUNT(*) AS ?t10)
FROM <urn:graph:test>
WHERE {
    ?node <urn:graph:test:edge> ?o .
    ?node bif:shortest_path_length ?d OPTION (source_node <urn:graph:test:A>) .
    FILTER ((?node = <urn:graph:test:D> && ?d != 2) ||
            (?node = <urn:graph:test:F> && ?d != -1))
};
ECHO BOTH ": T10 vectored source-keyed distances wrong rows = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

SELECT GRAPH_SET_LIMIT ('MinBatch', 64);
ECHO BOTH ": T11 MinBatch restored = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 64 "PASSED" "***FAILED";

-- ============================================================================
-- Group U: what Jaccard similarity compares
-- ============================================================================
--
-- Two separate things live here.  The first is a defect in the measure as it
-- stood; the second is that "how similar are these two nodes" has more than
-- one answer on an RDF graph, and the caller has to be able to say which.
--
-- THE DEFECT.  The union was counted from edges and the intersection from a
-- set.  graph_algo_jaccard took each side's size from the adjacency row
-- length -- the number of edges -- while the membership test went through a
-- hash of neighbour nodes.  Where a node reaches the same object twice, by
-- two different predicates, the two disagree, and `ca + cb - inter`
-- overstates the union while `inter` overcounts the overlap.  RDF_QUAD makes
-- (s,p,o) unique, so this cannot happen under a predicate filter; with no
-- filter -- the default, and the natural way to ask about an RDF graph -- it
-- is ordinary.
--
-- THE MODES.  Discarding the predicate is the graph reading: it is what
-- Neo4j's gds.nodeSimilarity does, over outgoing neighbourhoods, and it is
-- the right answer when the edges mean one thing.  It is the wrong answer on
-- a graph where they do not: `likes` and `hates` pointing at the same object
-- make two entities identical.  So the predicate-blind reading stays the
-- default, and the readings that keep the predicate are selectable:
--
--   0  outgoing neighbours, predicate discarded   (default; gds.nodeSimilarity)
--   1  outgoing (predicate, object) pairs         (entity similarity)
--   2  as 1, plus incoming (subject, predicate)   (the full description)
--   3  neighbours both ways, predicate discarded  (structural, undirected)
--
-- Literals are in none of them, in any mode: the loader keeps only edges
-- between nodes, so <a> <name> "Alice" is not in the graph at all and no
-- mode can compare it.  U.7 pins that, because it is a limit of the store
-- rather than of the measure and will not be obvious to a caller.

-- U.1: the defect.  a reaches two distinct objects, b reaches one of them
-- twice by different predicates.  As neighbour SETS that is {x,y} against
-- {x}: one shared out of two, so 0.5.  Counting b's two edges as two
-- members made the answer 1 -- "identical" -- which is the worst direction
-- for a similarity measure to be wrong in.
CREATE PROCEDURE GTEST_U1 ()
{
  DECLARE v DOUBLE PRECISION;
  SPARQL CLEAR GRAPH <urn:u:dup>;
  DB.DBA.TTLP ('<urn:u:a> <urn:u:p1> <urn:u:x> . <urn:u:a> <urn:u:p1> <urn:u:y> . ' ||
               '<urn:u:b> <urn:u:p1> <urn:u:x> . <urn:u:b> <urn:u:p2> <urn:u:x> . ',
               '', 'urn:u:dup');
  COMMIT WORK;
  v := GRAPH_JACCARD_SIMILARITY ('urn:u:a', 'urn:u:b', 'urn:u:dup');
  IF (abs (v - 0.5) > 0.000000001) RETURN CAST (v AS VARCHAR);
  RETURN 'SETS';
}
;
SELECT GTEST_U1 ();
ECHO BOTH ": U1 parallel edges counted once = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] SETS "PASSED" "***FAILED";

-- U.2: and a predicate filter still gives the same answer, as it always
-- did -- (s,p,o) uniqueness meant the edge count and the set size already
-- agreed there, so this is the case that must not move.
CREATE PROCEDURE GTEST_U2 ()
{
  DECLARE v DOUBLE PRECISION;
  v := GRAPH_JACCARD_SIMILARITY ('urn:u:a', 'urn:u:b', 'urn:u:dup', iri_to_id ('urn:u:p1'));
  IF (abs (v - 0.5) > 0.000000001) RETURN CAST (v AS VARCHAR);
  RETURN 'UNCHANGED';
}
;
SELECT GTEST_U2 ();
ECHO BOTH ": U2 filtered case unchanged = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] UNCHANGED "PASSED" "***FAILED";

-- U.3: the modes disagree, and that is the point.  One entity likes a
-- thing and the other hates it.  Structurally they are the same node --
-- both reach it -- and by their statements they share nothing.
CREATE PROCEDURE GTEST_U3 ()
{
  DECLARE m0, m1 DOUBLE PRECISION;
  SPARQL CLEAR GRAPH <urn:u:op>;
  DB.DBA.TTLP ('<urn:u:c> <urn:u:likes> <urn:u:pizza> . ' ||
               '<urn:u:d> <urn:u:hates> <urn:u:pizza> . ', '', 'urn:u:op');
  COMMIT WORK;
  m0 := GRAPH_JACCARD_SIMILARITY ('urn:u:c', 'urn:u:d', 'urn:u:op', NULL, 0);
  m1 := GRAPH_JACCARD_SIMILARITY ('urn:u:c', 'urn:u:d', 'urn:u:op', NULL, 1);
  IF (m0 <> 1.0) RETURN 'mode 0 ' || CAST (m0 AS VARCHAR);
  IF (m1 <> 0.0) RETURN 'mode 1 ' || CAST (m1 AS VARCHAR);
  RETURN 'DISAGREE';
}
;
SELECT GTEST_U3 ();
ECHO BOTH ": U3 likes vs hates, mode 0 = 1 and mode 1 = 0 = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] DISAGREE "PASSED" "***FAILED";

-- U.4: mode 0 is the default, so naming it must change nothing.  Worth its
-- own case because the default is the one reading every existing caller is
-- already getting.
CREATE PROCEDURE GTEST_U4 ()
{
  DECLARE dflt, named DOUBLE PRECISION;
  dflt  := GRAPH_JACCARD_SIMILARITY ('urn:u:c', 'urn:u:d', 'urn:u:op');
  named := GRAPH_JACCARD_SIMILARITY ('urn:u:c', 'urn:u:d', 'urn:u:op', NULL, 0);
  IF (dflt <> named) RETURN CAST (dflt AS VARCHAR) || ' <> ' || CAST (named AS VARCHAR);
  RETURN 'SAME';
}
;
SELECT GTEST_U4 ();
ECHO BOTH ": U4 default is mode 0 = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] SAME "PASSED" "***FAILED";

-- U.5: mode 2 adds what is said *about* an entity.  Two people of the same
-- type are alike by their own statements (mode 1), and less alike once it
-- counts that only one of them is known by anyone.
CREATE PROCEDURE GTEST_U5 ()
{
  DECLARE m1, m2 DOUBLE PRECISION;
  SPARQL CLEAR GRAPH <urn:u:inb>;
  DB.DBA.TTLP ('<urn:u:e> <urn:u:type> <urn:u:Person> . ' ||
               '<urn:u:f> <urn:u:type> <urn:u:Person> . ' ||
               '<urn:u:g> <urn:u:knows> <urn:u:e> . ', '', 'urn:u:inb');
  COMMIT WORK;
  m1 := GRAPH_JACCARD_SIMILARITY ('urn:u:e', 'urn:u:f', 'urn:u:inb', NULL, 1);
  m2 := GRAPH_JACCARD_SIMILARITY ('urn:u:e', 'urn:u:f', 'urn:u:inb', NULL, 2);
  -- mode 1: both {(type,Person)} -> 1
  IF (m1 <> 1.0) RETURN 'mode 1 ' || CAST (m1 AS VARCHAR);
  -- mode 2: e {(out type,Person),(in g,knows)} vs f {(out type,Person)} -> 1/2
  IF (abs (m2 - 0.5) > 0.000000001) RETURN 'mode 2 ' || CAST (m2 AS VARCHAR);
  RETURN 'INCOMING COUNTS';
}
;
SELECT GTEST_U5 ();
ECHO BOTH ": U5 mode 2 counts incoming statements = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "INCOMING COUNTS" "PASSED" "***FAILED";

-- U.6: mode 3 reads the graph as undirected.  a points at c and c points at
-- b, so following edges outward they share nothing; taken as an undirected
-- neighbourhood they are both exactly c's neighbour.
CREATE PROCEDURE GTEST_U6 ()
{
  DECLARE m0, m3 DOUBLE PRECISION;
  SPARQL CLEAR GRAPH <urn:u:un>;
  DB.DBA.TTLP ('<urn:u:h> <urn:u:p> <urn:u:i> . <urn:u:i> <urn:u:p> <urn:u:j> . ',
               '', 'urn:u:un');
  COMMIT WORK;
  m0 := GRAPH_JACCARD_SIMILARITY ('urn:u:h', 'urn:u:j', 'urn:u:un', NULL, 0);
  m3 := GRAPH_JACCARD_SIMILARITY ('urn:u:h', 'urn:u:j', 'urn:u:un', NULL, 3);
  IF (m0 <> 0.0) RETURN 'mode 0 ' || CAST (m0 AS VARCHAR);
  IF (m3 <> 1.0) RETURN 'mode 3 ' || CAST (m3 AS VARCHAR);
  RETURN 'UNDIRECTED';
}
;
SELECT GTEST_U6 ();
ECHO BOTH ": U6 mode 3 reads both directions = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] UNDIRECTED "PASSED" "***FAILED";

-- U.7: no mode sees a literal.  Two entities whose only shared statement is
-- a literal-valued one are not similar in any mode, because the loader
-- keeps edges between nodes and a literal is not one.  This is a property
-- of the store, and pinning it here is what stops someone reading mode 1 as
-- "compares the entities' properties" without qualification.
CREATE PROCEDURE GTEST_U7 ()
{
  DECLARE m0, m1, m2 DOUBLE PRECISION;
  SPARQL CLEAR GRAPH <urn:u:lit>;
  DB.DBA.TTLP ('<urn:u:k> <urn:u:name> "Alice" . <urn:u:l> <urn:u:name> "Alice" . ',
               '', 'urn:u:lit');
  COMMIT WORK;
  m0 := GRAPH_JACCARD_SIMILARITY ('urn:u:k', 'urn:u:l', 'urn:u:lit', NULL, 0);
  m1 := GRAPH_JACCARD_SIMILARITY ('urn:u:k', 'urn:u:l', 'urn:u:lit', NULL, 1);
  m2 := GRAPH_JACCARD_SIMILARITY ('urn:u:k', 'urn:u:l', 'urn:u:lit', NULL, 2);
  IF (m0 <> 0.0 OR m1 <> 0.0 OR m2 <> 0.0)
    RETURN sprintf ('%f %f %f', m0, m1, m2);
  RETURN 'LITERALS INVISIBLE';
}
;
SELECT GTEST_U7 ();
ECHO BOTH ": U7 literals invisible to every mode = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "LITERALS INVISIBLE" "PASSED" "***FAILED";

-- U.8: an unknown mode is refused rather than silently read as the default.
CREATE PROCEDURE GTEST_U8 ()
{
  DECLARE v DOUBLE PRECISION;
  DECLARE exit HANDLER FOR SQLSTATE '*'
    {
      IF (__SQL_STATE = '42002') RETURN 'REJECTED';
      RETURN 'wrong state ' || __SQL_STATE;
    };
  v := GRAPH_JACCARD_SIMILARITY ('urn:u:c', 'urn:u:d', 'urn:u:op', NULL, 9);
  RETURN 'accepted, ' || CAST (v AS VARCHAR);
}
;
SELECT GTEST_U8 ();
ECHO BOTH ": U8 unknown mode rejected = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] REJECTED "PASSED" "***FAILED";

-- U.9: the batch form takes the mode too, and agrees with the scalar one
-- pair for pair.  It delegates, so a mode that reached only one of them
-- would be a wiring fault rather than an arithmetic one.
CREATE PROCEDURE GTEST_U9 ()
{
  DECLARE a, b, v ANY;
  DECLARE i, m INT;
  DECLARE s DOUBLE PRECISION;
  a := vector ('urn:u:c', 'urn:u:d', 'urn:u:c');
  b := vector ('urn:u:d', 'urn:u:c', 'urn:u:c');
  FOR (m := 0; m <= 3; m := m + 1)
    {
      v := GRAPH_JACCARD_BATCH (a, b, 'urn:u:op', NULL, m);
      IF (length (v) <> 3) RETURN sprintf ('mode %d length %d', m, length (v));
      FOR (i := 0; i < 3; i := i + 1)
        {
          s := GRAPH_JACCARD_SIMILARITY (a[i], b[i], 'urn:u:op', NULL, m);
          IF (v[i] <> s)
            RETURN sprintf ('mode %d pair %d: %f <> %f', m, i, v[i], s);
        }
    }
  RETURN 'AGREE';
}
;
SELECT GTEST_U9 ();
ECHO BOTH ": U9 batch = scalar in every mode = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

-- U.10: and the SPARQL predicate form takes it as an OPTION.
SPARQL
SELECT (COUNT(*) AS ?u10)
FROM <urn:u:op>
WHERE {
    ?node <urn:u:likes> ?o .
    ?node bif:jaccard_similarity ?s
      OPTION (source_node <urn:u:d>, mode 1) .
    FILTER (?s != 0)
};
ECHO BOTH ": U10 mode as a SPARQL OPTION, non-zero rows = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- ============================================================================
-- Group V: a graph that does not exist reports "Not found", whatever it is called
--
-- vgraph_iri_to_id_ex() resolves a graph IRI with IRI_TO_ID_IF_KNOWN, so an
-- IRI that no triple has ever used comes back 0.  It used to fall through to
-- fnv1a_hash() and hand that hash back as the graph id; the loader then
-- pasted it into "WHERE G = #i<id>".  About half of all names hash with the
-- top bit set, and such a value is outside the signed-64 IRI_ID range, so
-- sql_compile() failed with SQ074 and the caller reported the generic
-- "I/O error" -- meaning the answer you got for a missing graph depended on
-- the hash of its name.
--
-- The two names below sit on opposite sides of that split.  The hash is
-- fnv1a over the string *and its NUL terminator*, which is what box_length
-- counts:
--
--   urn:graph:test:absent:hi    13920842542990203324   top bit SET
--   urn:graph:test:absent:low    3346532395021949965   top bit clear
--
-- V.3 is the assertion that actually catches a regression here: it compares
-- the two names against each other rather than against fixed text, so it
-- keeps its meaning if the hash function or the wording ever changes.
-- ============================================================================

-- V.1: an absent graph whose name hashes with the top bit SET
SELECT GTEST_LOAD_ERR ('select GRAPH_PAGERANK (''urn:graph:test:A'', ''urn:graph:test:absent:hi'')');
ECHO BOTH ": V1 absent graph, hash high = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] Not_found "PASSED" "***FAILED";

-- V.2: and one whose name hashes with the top bit clear
SELECT GTEST_LOAD_ERR ('select GRAPH_PAGERANK (''urn:graph:test:A'', ''urn:graph:test:absent:low'')');
ECHO BOTH ": V2 absent graph, hash low = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] Not_found "PASSED" "***FAILED";

-- V.3: the two must agree -- the name must not decide the error
SELECT CASE WHEN
    GTEST_LOAD_ERR ('select GRAPH_PAGERANK (''urn:graph:test:A'', ''urn:graph:test:absent:hi'')')
  = GTEST_LOAD_ERR ('select GRAPH_PAGERANK (''urn:graph:test:A'', ''urn:graph:test:absent:low'')')
  THEN 'SAME' ELSE 'DIFFER' END;
ECHO BOTH ": V3 both absent graphs agree = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] SAME "PASSED" "***FAILED";

-- V.4: the SPARQL predicate form, which is how the report came in
SELECT GTEST_LOAD_ERR ('SPARQL SELECT ?node ?rank FROM <urn:graph:test> WHERE {
    ?node <urn:graph:test:edge> ?other .
    ?node bif:pagerank ?rank OPTION (graph <urn:graph:test:absent:hi>) . }');
ECHO BOTH ": V4 OPTION (graph <absent>) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] Not_found "PASSED" "***FAILED";

-- V.5: a graph that exists but holds nothing says the same thing, so the
-- absent and the empty cases stay indistinguishable to a caller.
SPARQL CLEAR GRAPH <urn:graph:test:emptied>;
SPARQL INSERT DATA INTO GRAPH <urn:graph:test:emptied> { <urn:x> <urn:p> <urn:y> };
SPARQL CLEAR GRAPH <urn:graph:test:emptied>;
SELECT GTEST_LOAD_ERR ('select GRAPH_PAGERANK (''urn:graph:test:A'', ''urn:graph:test:emptied'')');
ECHO BOTH ": V5 interned but empty graph = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] Not_found "PASSED" "***FAILED";

-- V.6: an absent *node* in a graph that does exist is a different answer.
-- The graph loaded, so this must not be reported as a load failure -- it
-- guards the node path, whose own unknown-IRI branch already returns
-- GRAPH_NODE_ID_INVALID and must keep doing so.
SELECT CASE WHEN GTEST_LOAD_ERR (
    'select GRAPH_PAGERANK (''urn:graph:test:no:such:node'', ''urn:graph:test'')')
  LIKE 'OTHER:%' THEN 'NOTALOAD' ELSE 'LOADERR' END;
ECHO BOTH ": V6 absent node, real graph = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] NOTALOAD "PASSED" "***FAILED";

-- ============================================================================
-- Group W: a load failure says what actually failed
--
-- GRAPH_ERR_IO_ERROR is what the loader returns whenever the internal SQL it
-- runs to materialise a graph will not compile or execute -- a dropped
-- backing table, a cancelled query, a lock it could not take.  The real
-- error used to be dk_free_tree()d at every one of those sites and replaced
-- with the bare code, so "I/O error" was all the caller ever saw and no
-- amount of staring at it could say which cause it was.
--
-- The underlying SQLSTATE and message are now carried into the VGPR03 text.
-- The fixture below is the one failure that can be staged deterministically:
-- a table-sourced graph whose table is dropped underneath it.
--
-- Withholding that detail from a caller who is not DBA is asserted in
-- test_graph_security.sql, where the non-DBA identity already exists.
-- ============================================================================

CREATE TABLE DB.DBA.GTEST_W_EDGES (S IRI_ID, O IRI_ID, PRIMARY KEY (S, O));
GRANT SELECT ON DB.DBA.GTEST_W_EDGES TO SPARQL_SELECT;
INSERT INTO DB.DBA.GTEST_W_EDGES (S, O)
  VALUES (iri_to_id ('urn:graph:w:a'), iri_to_id ('urn:graph:w:b'));
INSERT INTO DB.DBA.GTEST_W_EDGES (S, O)
  VALUES (iri_to_id ('urn:graph:w:b'), iri_to_id ('urn:graph:w:c'));

-- W.1: control -- the table-sourced graph answers while its table is there
SELECT CASE WHEN GRAPH_LOAD_TABLE ('urn:graph:w:g', 'urn:graph:w:edge',
                                   'DB.DBA.GTEST_W_EDGES') = 2
       THEN 'LOADED' ELSE 'NOTLOADED' END;
ECHO BOTH ": W1 table-sourced graph loaded = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] LOADED "PASSED" "***FAILED";

DROP TABLE DB.DBA.GTEST_W_EDGES;

-- W.2: with the table gone the reason must carry a detail, not just a code
SELECT CASE WHEN strstr (GTEST_LOAD_ERR (
    'select GRAPH_PAGERANK (''urn:graph:w:a'', ''urn:graph:w:g'')'), '(') IS NULL
  THEN 'NODETAIL' ELSE 'DETAIL' END;
ECHO BOTH ": W2 dropped backing table, detail present = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] DETAIL "PASSED" "***FAILED";

-- W.3: and the detail must be the error SQL actually raised
SELECT CASE WHEN strstr (GTEST_LOAD_ERR (
    'select GRAPH_PAGERANK (''urn:graph:w:a'', ''urn:graph:w:g'')'), 'SQ200') IS NULL
  THEN 'UNNAMED' ELSE 'NAMED' END;
ECHO BOTH ": W3 dropped backing table, names SQ200 = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] NAMED "PASSED" "***FAILED";

-- W.4: a detail from one call must not stick to the next.  This graph fails
-- for a different reason entirely, and must say so on its own terms.
SELECT GTEST_LOAD_ERR ('select GRAPH_PAGERANK (''urn:graph:test:A'', ''urn:graph:test:absent:hi'')');
ECHO BOTH ": W4 next call is not contaminated = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] Not_found "PASSED" "***FAILED";

-- W.6: GRAPH_LOAD_TABLE's own failure names the cause too.  It reports
-- "failed to read <table>" rather than "failed to load graph", so it is a
-- separate message and was left behind when the others started carrying the
-- detail -- the one load error in the set that still said only "I/O error".
CREATE PROCEDURE GTEST_READ_ERR (IN txt VARCHAR)
{
  DECLARE st, msg, tag VARCHAR;
  DECLARE mdta, rset ANY;
  DECLARE pos INT;
  st := '00000';
  msg := '';
  EXEC (txt, st, msg, VECTOR (), 0, mdta, rset);
  IF (st = '00000')
    RETURN 'NOERROR';
  tag := 'failed to read ';
  pos := strstr (msg, tag);
  IF (pos IS NULL)
    RETURN 'OTHER:' || msg;
  RETURN replace (subseq (msg, pos + length (tag)), ' ', '_');
}
;

SELECT CASE WHEN strstr (GTEST_READ_ERR (
    'select GRAPH_LOAD_TABLE (''urn:graph:w:g2'', ''urn:graph:w:edge'', ''DB.DBA.GTEST_W_ABSENT'')'),
  'SQ200') IS NULL THEN 'UNNAMED' ELSE 'NAMED' END;
ECHO BOTH ": W6 GRAPH_LOAD_TABLE names why the read failed = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] NAMED "PASSED" "***FAILED";

-- Forget the dead registration: it is process-wide and would otherwise
-- outlive this file and reroute anything else naming that graph.
SELECT CASE WHEN GRAPH_UNLOAD_TABLE ('urn:graph:w:g') = 1
       THEN 'UNLOADED' ELSE 'NOTHING' END;
ECHO BOTH ": W5 table source forgotten = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] UNLOADED "PASSED" "***FAILED";

-- ============================================================================
-- Group X: a weight predicate that matches nothing is refused
--
-- Naming a weight predicate no statement in the graph uses leaves every
-- edge on the default weight of 1.0, so a weighted shortest path would
-- return the hop count: a plausible number, in the units of the weights,
-- for a question nobody asked.  A predicate that matches no edges is
-- refused with 42006 for exactly that reason, and the most common way to
-- get there is a typo -- which names an IRI the store has never seen.  The
-- resolver reports such an IRI as 0, and build_weight_lookup_from_graph()
-- used to turn that 0 into an empty table and answer, so the refusal never
-- reached the typo it was written for.  X1 pins the refusal for it.
-- ============================================================================

CREATE PROCEDURE GTEST_NOWEIGHT ()
{
  DECLARE w, u DOUBLE PRECISION;
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  -- a three-node chain carrying real weights under urn:xw:weight
  DB.DBA.TTLP ('<urn:xw:a> <urn:xw:e> <urn:xw:b> . <urn:xw:b> <urn:xw:e> <urn:xw:c> . ',
               '', 'urn:xw:g');
  DB.DBA.TTLP ('_:r1 <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:xw:a> ; ' ||
               '<http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:xw:e> ; ' ||
               '<http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:xw:b> ; ' ||
               '<urn:xw:weight> "5.0"^^<http://www.w3.org/2001/XMLSchema#double> . ' ||
               '_:r2 <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:xw:b> ; ' ||
               '<http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:xw:e> ; ' ||
               '<http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:xw:c> ; ' ||
               '<urn:xw:weight> "7.0"^^<http://www.w3.org/2001/XMLSchema#double> . ',
               '', 'urn:xw:g');
  COMMIT WORK;
  -- with the real predicate the weights are read: 5 + 7
  w := GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED ('urn:xw:a', 'urn:xw:c', 'urn:xw:g',
                                            'urn:xw:e', 'urn:xw:weight');
  IF (ABS (w - 12.0) > 0.0001)
    RETURN sprintf ('weighted %f, expected 12', w);
  -- with a predicate nothing uses -- not even an IRI the store knows --
  -- the call is refused rather than answered with two hops
  st := '00000';
  msg := '';
  EXEC ('select GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED (''urn:xw:a'', ''urn:xw:c'', ' ||
        '''urn:xw:g'', ''urn:xw:e'', ''urn:xw:NOSUCH'')', st, msg, VECTOR (), 0, mdta, rset);
  IF (st = '00000')
    {
      u := rset[0][0];
      RETURN sprintf ('answered %f', u);
    }
  IF (st <> '42006' OR strstr (msg, 'matched no edges') IS NULL)
    RETURN 'raised ' || st;
  RETURN 'REFUSED';
}
;

SELECT GTEST_NOWEIGHT ();
ECHO BOTH ": X1 unknown weight predicate is refused = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] REFUSED "PASSED" "***FAILED";

-- ============================================================================
-- Group AV: a weight predicate the store has never seen is refused, in
-- every weighted function
--
-- X1 for all eight weighted SQL functions and for SPARQL.  A typo in the
-- weight predicate names an IRI nothing has interned; the resolver reports
-- it as 0, and every function then answered over unit weights.  A SQL NULL
-- is different and keeps meaning "no weights, every edge 1.0" -- R6 and R7
-- ask for unit weights that way.
--
-- A table-sourced graph keeps its weights in a column and needs no
-- predicate, so an unknown one must still read the column: AV2.
-- ============================================================================

CREATE PROCEDURE GTEST_NOWEIGHT_ALL (IN warg VARCHAR)
{
  DECLARE calls ANY;
  DECLARE i INTEGER;
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  calls := VECTOR (
    'GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED (''urn:xw:a'', ''urn:xw:c'', ''urn:xw:g'', ''urn:xw:e'', %s)',
    'GRAPH_SHORTEST_PATH_WEIGHTED (''urn:xw:a'', ''urn:xw:c'', ''urn:xw:g'', ''urn:xw:e'', %s, 1)',
    'GRAPH_PAGERANK_WEIGHTED (''urn:xw:b'', ''urn:xw:g'', ''urn:xw:e'', %s)',
    'GRAPH_BETWEENNESS_WEIGHTED (''urn:xw:b'', ''urn:xw:g'', ''urn:xw:e'', %s)',
    'GRAPH_CLOSENESS_WEIGHTED (''urn:xw:a'', ''urn:xw:g'', ''urn:xw:e'', %s)',
    'GRAPH_EIGENVECTOR_WEIGHTED (''urn:xw:b'', ''urn:xw:g'', ''urn:xw:e'', %s)',
    'GRAPH_DEGREE_WEIGHTED (''urn:xw:b'', ''urn:xw:g'', ''urn:xw:e'', %s)',
    'GRAPH_DEGREE_W_SPARQL (''urn:xw:b'', ''urn:xw:g'', ''urn:xw:e'', %s)');
  FOR (i := 0; i < LENGTH (calls); i := i + 1)
    {
      st := '00000';
      msg := '';
      EXEC ('select ' || sprintf (calls[i], warg), st, msg, VECTOR (), 0, mdta, rset);
      IF (st = '00000')
        RETURN sprintf ('%d answered', i);
      IF (st <> '42006' OR strstr (msg, 'matched no edges') IS NULL)
        RETURN sprintf ('%d raised %s', i, st);
    }
  RETURN 'ALLREFUSED';
}
;

-- AV.1: a weight predicate the store has never seen, in all eight
SELECT GTEST_NOWEIGHT_ALL ('''urn:xw:NOSUCH''');
ECHO BOTH ": AV1 unknown weight predicate, every weighted function = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] ALLREFUSED "PASSED" "***FAILED";

-- AV.2 - AV.3: a table's weight column needs no predicate at all.  Two hops
-- of 5 beat the direct edge of 20; unweighted, the direct edge is one hop.
CREATE TABLE DB.DBA.AV_E (S BIGINT, O BIGINT, W DOUBLE PRECISION)
;
GRANT SELECT ON DB.DBA.AV_E TO SPARQL_SELECT;
INSERT INTO DB.DBA.AV_E (S,O,W) VALUES (1,2,5.0);
INSERT INTO DB.DBA.AV_E (S,O,W) VALUES (2,3,5.0);
INSERT INTO DB.DBA.AV_E (S,O,W) VALUES (1,3,20.0);
COMMIT WORK;
SELECT GRAPH_LOAD_TABLE ('urn:av:t', 'urn:av:e', 'DB.DBA.AV_E', 'W');

SELECT GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED (1, 3, 'urn:av:t', 'urn:av:e', 'urn:av:anything');
ECHO BOTH ": AV2 column weights under any predicate = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";

SELECT GRAPH_SHORTEST_PATH_LENGTH (1, 3, 'urn:av:t', 'urn:av:e');
ECHO BOTH ": AV3 unweighted is a different number = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

SELECT GRAPH_UNLOAD_TABLE ('urn:av:t');

-- AV.4: from SPARQL, a weight predicate the store has never seen
SPARQL SELECT ?n ?d FROM <urn:xw:g> WHERE {
  ?n <urn:xw:e> ?o .
  ?n bif:shortest_path_length ?d OPTION (weight <urn:xw:NOSUCH:sparql>, source_node <urn:xw:a>) . };
ECHO BOTH ": AV4 SPARQL OPTION (weight <unknown>) state = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE 42006 "PASSED" "***FAILED";

-- ============================================================================
-- Group Z: a graph that exists only for this call
--
-- Analytics could only ever read two things: RDF_QUAD, or a SQL table
-- registered with GRAPH_LOAD_TABLE.  Anything a query produced itself --
-- a SERVICE result, a computed join, a temporary shape -- was invisible,
-- and invisible in the worst way: the IRIs intern just by passing through
-- a result set, so the node id resolves, the node is not in the loaded
-- graph, and every score comes back NULL with no error at all.
--
-- GRAPH_LOAD_EDGES takes the edges directly and makes a graph of them,
-- addressable by IRI like any other, readable by every algorithm, and
-- written nowhere.  Z.2 is the assertion that gives the feature its
-- point; Z.1 is the one that says the answers are the same answers.
-- ============================================================================

-- The same four-node graph, built both ways, compared node by node.  Any
-- difference in load order, node identity or edge direction shows up as a
-- score difference, so this is the assertion that does not care how
-- PageRank is implemented.
CREATE PROCEDURE GTEST_Z_SAMEVALUES ()
{
  DECLARE i INT;
  DECLARE n VARCHAR;
  DECLARE fromrdf, fromvec DOUBLE PRECISION;
  DECLARE names ANY;
  names := vector ('a', 'b', 'c', 'd');
  FOR (i := 0; i < length (names); i := i + 1)
    {
      n := 'urn:z:' || names[i];
      fromrdf := GRAPH_PAGERANK (iri_to_id (n), iri_to_id ('urn:z:rdf'), iri_to_id ('urn:z:e'));
      fromvec := GRAPH_PAGERANK (iri_to_id (n), iri_to_id ('urn:z:vec'), iri_to_id ('urn:z:e'));
      IF (fromrdf IS NULL OR fromvec IS NULL)
        RETURN n || ': NULL';
      IF (ABS (fromrdf - fromvec) > 0.000000001)
        RETURN sprintf ('%s: rdf %.17g <> vec %.17g', n, fromrdf, fromvec);
    }
  RETURN 'SAME';
}
;

-- The edge list, once, so the two loads cannot drift apart.
CREATE PROCEDURE GTEST_Z_EDGES ()
{
  RETURN vector (
    vector (iri_to_id ('urn:z:a'), iri_to_id ('urn:z:b')),
    vector (iri_to_id ('urn:z:b'), iri_to_id ('urn:z:c')),
    vector (iri_to_id ('urn:z:c'), iri_to_id ('urn:z:d')),
    vector (iri_to_id ('urn:z:d'), iri_to_id ('urn:z:a')),
    vector (iri_to_id ('urn:z:a'), iri_to_id ('urn:z:c')));
}
;

SPARQL CLEAR GRAPH <urn:z:rdf>;
SPARQL INSERT DATA INTO GRAPH <urn:z:rdf> {
  <urn:z:a> <urn:z:e> <urn:z:b> . <urn:z:b> <urn:z:e> <urn:z:c> .
  <urn:z:c> <urn:z:e> <urn:z:d> . <urn:z:d> <urn:z:e> <urn:z:a> .
  <urn:z:a> <urn:z:e> <urn:z:c> .
};

-- Z.1a: the load reports the edge count it was given
SELECT GRAPH_LOAD_EDGES ('urn:z:vec', 'urn:z:e', GTEST_Z_EDGES ());
ECHO BOTH ": Z1a edges loaded = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";

-- Z.1b: and the graph it makes answers exactly as the RDF one does
SELECT GTEST_Z_SAMEVALUES ();
ECHO BOTH ": Z1b transient == RDF, node by node = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] SAME "PASSED" "***FAILED";

-- Z.2: and nothing was written.  This is the whole point of the feature:
-- if it ever fails, the graph is being materialised and the answer to
-- "can I analyse data I have not stored" has quietly become "no".
SELECT COUNT (*) FROM DB.DBA.RDF_QUAD WHERE G = iri_to_id ('urn:z:vec', 0);
ECHO BOTH ": Z2 quads written by a transient load = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- Z.3: every algorithm reaches it, not just the one it was built for
CREATE PROCEDURE GTEST_Z_ALLALGOS ()
{
  DECLARE g, p IRI_ID;
  DECLARE d, w, spl INT;
  g := iri_to_id ('urn:z:vec');
  p := iri_to_id ('urn:z:e');
  d := GRAPH_DEGREE_CENTRALITY (iri_to_id ('urn:z:a'), g, p, 2);
  IF (d <> 2) RETURN sprintf ('out-degree(a) = %d, expected 2', d);
  w := GRAPH_WCC_COUNT (g, p);
  IF (w <> 1) RETURN sprintf ('wcc components = %d, expected 1', w);
  spl := GRAPH_SHORTEST_PATH_LENGTH (iri_to_id ('urn:z:a'), iri_to_id ('urn:z:d'), g, p);
  IF (spl <> 2) RETURN sprintf ('spl(a,d) = %d, expected 2', spl);
  RETURN 'ALLREACH';
}
;

SELECT GTEST_Z_ALLALGOS ();
ECHO BOTH ": Z3 degree, WCC and shortest path all reach it = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] ALLREACH "PASSED" "***FAILED";

-- Z.4: and it is reachable from SPARQL predicate position, which is what
-- makes it usable on a query's own data rather than only from SQL
SPARQL
SELECT (COUNT(*) AS ?z4)
FROM <urn:z:rdf>
WHERE {
    ?node <urn:z:e> ?o .
    ?node bif:pagerank ?rank OPTION (graph <urn:z:vec>) .
    FILTER (?rank > 0)
};
ECHO BOTH ": Z4 SPARQL OPTION (graph <transient>) rows = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";

-- Z.5: unload says whether there was one, and the graph is gone after
SELECT GRAPH_UNLOAD_EDGES ('urn:z:vec');
ECHO BOTH ": Z5a unload of a transient graph = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

SELECT GTEST_LOAD_ERR ('select GRAPH_PAGERANK (''urn:z:a'', ''urn:z:vec'', ''urn:z:e'')');
ECHO BOTH ": Z5b after unload = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] Not_found "PASSED" "***FAILED";

SELECT GRAPH_UNLOAD_EDGES ('urn:z:neverloaded');
ECHO BOTH ": Z5c unload of a graph that was never transient = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- Z.6: an edge list over the triple limit is refused, not silently cut
-- short.  A truncated graph gives confident wrong answers.
CREATE PROCEDURE GTEST_Z_OVERLIMIT_EDGES ()
{
  DECLARE i INT;
  DECLARE e ANY;
  e := make_array (200, 'any');
  FOR (i := 0; i < 200; i := i + 1)
    aset (e, i, vector (iri_to_id (sprintf ('urn:z:ol:n%d', i)),
                        iri_to_id (sprintf ('urn:z:ol:n%d', mod (i + 1, 200)))));
  RETURN e;
}
;

CREATE PROCEDURE GTEST_Z_OVERLIMIT ()
{
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  GRAPH_SET_LIMIT ('MaxGraphTriples', 50);
  st := '00000';
  msg := '';
  EXEC ('select GRAPH_LOAD_EDGES (''urn:z:ol'', ''urn:z:e'', GTEST_Z_OVERLIMIT_EDGES ())',
        st, msg, vector (), 0, mdta, rset);
  GRAPH_SET_LIMIT ('MaxGraphTriples', 1000000);
  IF (st = '00000')
    RETURN 'ACCEPTED';
  RETURN 'REFUSED';
}
;

SELECT GTEST_Z_OVERLIMIT ();
ECHO BOTH ": Z6 edge list over MaxGraphTriples = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] REFUSED "PASSED" "***FAILED";

-- Z.7: a malformed edge list is an error, not a partial graph
CREATE PROCEDURE GTEST_Z_MALFORMED ()
{
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  DECLARE bad INT;
  bad := 0;
  -- not a vector at all
  st := '00000'; msg := '';
  EXEC ('select GRAPH_LOAD_EDGES (''urn:z:bad1'', ''urn:z:e'', ''notavector'')',
        st, msg, vector (), 0, mdta, rset);
  IF (st = '00000') bad := bad + 1;
  -- rows that are not pairs
  st := '00000'; msg := '';
  EXEC ('select GRAPH_LOAD_EDGES (''urn:z:bad2'', ''urn:z:e'', vector (vector (1)))',
        st, msg, vector (), 0, mdta, rset);
  IF (st = '00000') bad := bad + 1;
  IF (bad > 0)
    RETURN sprintf ('%d malformed inputs accepted', bad);
  RETURN 'REFUSED';
}
;

SELECT GTEST_Z_MALFORMED ();
ECHO BOTH ": Z7 malformed edge lists = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] REFUSED "PASSED" "***FAILED";

-- Z.8 - Z.10: the entry points that take a query rather than a vector.
--
-- GRAPH_LOAD_EDGES is the mechanism, but marshalling a result set into a
-- vector of pairs by hand is not something a user should have to write to
-- analyse their own query.  These run the query and do it.  Nothing here
-- needs a network: a local SPARQL query exercises the same path a
-- federated one does, because SERVICE is resolved by the SPARQL engine
-- long before these see a row.

SPARQL CLEAR GRAPH <urn:z:src>;
SPARQL INSERT DATA INTO GRAPH <urn:z:src> {
  <urn:z:s1> <urn:z:link> <urn:z:s2> . <urn:z:s2> <urn:z:link> <urn:z:s3> .
  <urn:z:s3> <urn:z:link> <urn:z:s1> . <urn:z:s1> <urn:z:link> <urn:z:s3> .
};

-- Z.8: a query's own result set becomes a graph
SELECT DB.DBA.GRAPH_LOAD_SPARQL ('urn:z:fromq', 'urn:z:e',
  'SELECT ?s ?o FROM <urn:z:src> WHERE { ?s <urn:z:link> ?o }');
ECHO BOTH ": Z8 edges taken from a query = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";

-- ... and it is a real graph: s1 has two out-edges in that result
SELECT cast (GRAPH_DEGREE_CENTRALITY ('urn:z:s1', 'urn:z:fromq', 'urn:z:e', 2) as integer);
ECHO BOTH ": Z8b out-degree(s1) in the query's graph = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

-- Z.9: still nothing written
SELECT COUNT (*) FROM DB.DBA.RDF_QUAD WHERE G = iri_to_id ('urn:z:fromq', 0);
ECHO BOTH ": Z9 quads written by GRAPH_LOAD_SPARQL = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

SELECT GRAPH_UNLOAD_EDGES ('urn:z:fromq');
ECHO BOTH ": Z9b unloaded = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- Z.10: and the one-call form ranks the query's own data, leaving nothing
-- registered behind it
CREATE PROCEDURE GTEST_Z_ONECALL ()
{
  DECLARE n, rows_seen INT;
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  st := '00000';
  msg := '';
  EXEC ('DB.DBA.GRAPH_ANALYTICS_SPARQL (''pagerank'', ''SELECT ?s ?o FROM <urn:z:src> WHERE { ?s <urn:z:link> ?o }'')',
        st, msg, vector (), 0, mdta, rset);
  IF (st <> '00000')
    RETURN 'STATE:' || st;
  IF (NOT isarray (rset))
    RETURN 'NOROWS';
  rows_seen := length (rset);
  IF (rows_seen <> 3)
    RETURN sprintf ('%d rows, expected 3 nodes', rows_seen);
  RETURN 'RANKED';
}
;

SELECT GTEST_Z_ONECALL ();
ECHO BOTH ": Z10 one call ranks a query's own data = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] RANKED "PASSED" "***FAILED";

-- ============================================================================
-- Group AB: analytics over a query's own rows, from SPARQL
--
-- GRAPH_LOAD_EDGES takes edges from SQL.  This is the same capability from
-- SPARQL, and it is what makes a SERVICE result analysable at the endpoint
-- rather than only from a SQL connection: a subselect whose one projected
-- value is the transient graph built from the rows it collects.
--
--   { SELECT (sql:GRAPH_EDGES_AGG(?s, ?o) AS ?g) WHERE { ... } }
--   BIND (bif:GRAPH_PAGERANK(?n, ?g, "urn:graph:edges:e") AS ?score)
--
-- It is an aggregate rather than a BIF because a graph is the whole
-- solution set and a BIF sees one row, or one vectored batch.  AB.4 is
-- sized past the batch for exactly that reason.
--
-- A local pattern stands in for SERVICE: federation is resolved long
-- before the aggregate sees a row, so the two take the same path.
-- ============================================================================

SPARQL CLEAR GRAPH <urn:ab:src>;
SPARQL INSERT DATA INTO GRAPH <urn:ab:src> {
  <urn:ab:a> <urn:ab:link> <urn:ab:b> .
  <urn:ab:b> <urn:ab:link> <urn:ab:c> .
  <urn:ab:a> <urn:ab:link> <urn:ab:c> .
  <urn:ab:c> <urn:ab:other> <urn:ab:d> .
};

-- The three <link> edges as a named transient graph, to compare against.
-- The FROM graph also holds an <other> edge, so an implementation that
-- quietly used the FROM graph instead would not match.
SELECT GRAPH_LOAD_EDGES ('urn:ab:ref', 'urn:ab:link',
  vector (vector (iri_to_id ('urn:ab:a'), iri_to_id ('urn:ab:b')),
          vector (iri_to_id ('urn:ab:b'), iri_to_id ('urn:ab:c')),
          vector (iri_to_id ('urn:ab:a'), iri_to_id ('urn:ab:c'))));
ECHO BOTH ": AB0 reference graph built = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";

-- AB.1: the collected graph answers exactly as the named one does
CREATE PROCEDURE GTEST_AB_SAME ()
{
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  DECLARE i INT;
  st := '00000';
  msg := '';
  EXEC ('SPARQL PREFIX sql: <sql:>
         SELECT DISTINCT ?n (bif:pagerank(?n, ''urn:ab:ref'', ''urn:ab:link'') AS ?viagraph) ?viaedges
         FROM <urn:ab:src>
         WHERE { ?n <urn:ab:link> ?o .
                 { SELECT (sql:GRAPH_EDGES_AGG(?s2, ?o2) AS ?g) WHERE {
                     ?s2 <urn:ab:link> ?o2 } }
                 BIND (bif:GRAPH_PAGERANK(?n, ?g, "urn:graph:edges:e") AS ?viaedges) }
         ORDER BY ?n',
        st, msg, VECTOR (), 0, mdta, rset);
  IF (st <> '00000')
    RETURN 'STATE:' || st;
  IF (NOT isarray (rset) OR length (rset) = 0)
    RETURN 'NOROWS';
  FOR (i := 0; i < length (rset); i := i + 1)
    {
      DECLARE g, e DOUBLE PRECISION;
      g := rset[i][1];
      e := rset[i][2];
      IF (g IS NULL OR e IS NULL)
        RETURN sprintf ('%s: NULL', cast (rset[i][0] AS VARCHAR));
      IF (ABS (g - e) > 0.000000001)
        RETURN sprintf ('%s: graph %.17g <> collected %.17g',
                        cast (rset[i][0] AS VARCHAR), g, e);
    }
  RETURN 'SAME';
}
;

SELECT GTEST_AB_SAME ();
ECHO BOTH ": AB1 collected graph == the same edges named = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] SAME "PASSED" "***FAILED";

-- AB.2: and nothing was written
SELECT COUNT (*) FROM DB.DBA.RDF_QUAD WHERE G = iri_to_id ('urn:graph:edges:e', 0);
ECHO BOTH ": AB2 quads written by collecting = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- AB.3: a FILTER inside the subselect is honoured, so a caller can collect
-- a subset of the rows they enumerate
CREATE PROCEDURE GTEST_AB_FILTERED ()
{
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  st := '00000';
  msg := '';
  EXEC ('SPARQL PREFIX sql: <sql:>
         SELECT (bif:GRAPH_DEGREE_CENTRALITY(''urn:ab:a'', ?g, "urn:graph:edges:e", 2) AS ?d)
         WHERE { { SELECT (sql:GRAPH_EDGES_AGG(?s, ?o) AS ?g) WHERE {
                     GRAPH <urn:ab:src> { ?s <urn:ab:link> ?o }
                     FILTER (?o != <urn:ab:c>) } } }',
        st, msg, VECTOR (), 0, mdta, rset);
  IF (st <> '00000')
    RETURN 'STATE:' || st;
  IF (NOT isarray (rset) OR length (rset) = 0)
    RETURN 'NOROWS';
  -- a has two <link> edges; filtering out ?o = c leaves one
  RETURN sprintf ('%d', cast (rset[0][0] AS INTEGER));
}
;

SELECT GTEST_AB_FILTERED ();
ECHO BOTH ": AB3 out-degree(a) with ?o != c filtered out = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- AB.4: a solution set larger than one vectored batch.  A collector that
-- saw only a batch would build a path and disagree with the ring.
CREATE PROCEDURE GTEST_AB_BIG (IN n INT)
{
  DECLARE i INT;
  DECLARE s VARCHAR;
  DECLARE e ANY;
  s := '';
  e := make_array (n, 'any');
  FOR (i := 0; i < n; i := i + 1)
    {
      s := s || sprintf ('<urn:ab:big:n%d> <urn:ab:big:e> <urn:ab:big:n%d> . ',
                         i, mod (i + 1, n));
      aset (e, i, vector (iri_to_id (sprintf ('urn:ab:big:n%d', i)),
                          iri_to_id (sprintf ('urn:ab:big:n%d', mod (i + 1, n)))));
    }
  DB.DBA.TTLP (s, '', 'urn:ab:big');
  COMMIT WORK;
  GRAPH_LOAD_EDGES ('urn:ab:bigref', 'urn:ab:big:e', e);
  RETURN n;
}
;

SELECT GTEST_AB_BIG (5000);
ECHO BOTH ": AB4a big ring built = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 5000 "PASSED" "***FAILED";

CREATE PROCEDURE GTEST_AB_BIGSAME ()
{
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  DECLARE i, bad INT;
  st := '00000';
  msg := '';
  bad := 0;
  EXEC ('SPARQL PREFIX sql: <sql:>
         SELECT ?n (bif:pagerank(?n, ''urn:ab:bigref'', ''urn:ab:big:e'') AS ?viagraph) ?viaedges
         FROM <urn:ab:big>
         WHERE { ?n <urn:ab:big:e> ?o .
                 { SELECT (sql:GRAPH_EDGES_AGG(?s2, ?o2) AS ?g) WHERE {
                     GRAPH <urn:ab:big> { ?s2 <urn:ab:big:e> ?o2 } } }
                 BIND (bif:GRAPH_PAGERANK(?n, ?g, "urn:graph:edges:e") AS ?viaedges) }',
        st, msg, VECTOR (), 0, mdta, rset);
  IF (st <> '00000')
    RETURN 'STATE:' || st;
  IF (NOT isarray (rset) OR length (rset) < 5000)
    RETURN sprintf ('%d rows', case when isarray (rset) then length (rset) else -1 end);
  FOR (i := 0; i < length (rset); i := i + 1)
    {
      DECLARE g, e DOUBLE PRECISION;
      g := rset[i][1];
      e := rset[i][2];
      IF (g IS NULL OR e IS NULL OR ABS (g - e) > 0.000000001)
        bad := bad + 1;
    }
  IF (bad > 0)
    RETURN sprintf ('%d of %d rows differ', bad, length (rset));
  RETURN 'SAME';
}
;

SELECT GTEST_AB_BIGSAME ();
ECHO BOTH ": AB4b 5000 rows, every node agrees = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] SAME "PASSED" "***FAILED";

SELECT GRAPH_UNLOAD_EDGES ('urn:ab:ref');
SELECT GRAPH_UNLOAD_EDGES ('urn:ab:bigref');

-- ============================================================================
-- Group AC: OPTION (edges (?a, ?b)) -- the same capability as Group AB, at
-- the surface a user actually writes.
--
--   ?film bif:pagerank ?score OPTION (edges (?film, ?actor))
--
-- The graph is built from the rows of the group the option is written in,
-- filters included, and nothing is written to the store.  That is what
-- makes a SERVICE result analysable: the rows never have to land anywhere
-- first.  A local pattern stands in for SERVICE here, because federation
-- is resolved long before the collector sees a row.
--
-- Every assertion below is written so that IGNORING the option fails it:
-- the collected edge set is always a proper subset of what the FROM graph
-- would give.  An earlier version of this work passed a version of these
-- tests while doing nothing, because the fixture happened to hold exactly
-- the collected edges.
-- ============================================================================

SPARQL CLEAR GRAPH <urn:ac:src>;
SPARQL INSERT DATA INTO GRAPH <urn:ac:src> {
  <urn:ac:a> <urn:ac:link> <urn:ac:b> .
  <urn:ac:a> <urn:ac:link> <urn:ac:c> .
  <urn:ac:b> <urn:ac:link> <urn:ac:c> .
  <urn:ac:a> <urn:ac:other> <urn:ac:d> .
  <urn:ac:a> <urn:ac:other> <urn:ac:e> .
};

-- AC.1: the graph is the collected rows, not the FROM graph.
-- Degree of <urn:ac:a> is 2 over the <link> edges and 4 over everything in
-- <urn:ac:src>, so an ignored option reads 4.
CREATE PROCEDURE GTEST_AC_SUBSET ()
{
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  st := '00000';
  msg := '';
  EXEC ('SPARQL SELECT DISTINCT ?d
         FROM <urn:ac:src>
         WHERE { ?s <urn:ac:link> ?o .
                 ?s bif:degree_centrality ?d OPTION (edges (?s, ?o))
                 FILTER (?s = iri ("urn:ac:a")) }',
        st, msg, VECTOR (), 0, mdta, rset);
  IF (st <> '00000')
    RETURN 'STATE:' || st || ' ' || msg;
  IF (NOT isarray (rset) OR length (rset) = 0)
    RETURN 'NOROWS';
  RETURN cast (rset[0][0] AS VARCHAR);
}
;

SELECT GTEST_AC_SUBSET ();
ECHO BOTH ": AC1 graph is the collected rows (2, not 4) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

-- AC.2: a FILTER on the group narrows the graph too.
-- With <urn:ac:a> excluded the only edge left is b->c, so b reads 1 where
-- the unfiltered collection reads 2.  This is the assertion that fails if
-- the graph is built before the filters are attached -- which is where the
-- first attempt at this feature went wrong, silently.
CREATE PROCEDURE GTEST_AC_FILTERED ()
{
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  st := '00000';
  msg := '';
  EXEC ('SPARQL SELECT DISTINCT ?d
         FROM <urn:ac:src>
         WHERE { ?s <urn:ac:link> ?o .
                 FILTER (?s != iri ("urn:ac:a"))
                 ?s bif:degree_centrality ?d OPTION (edges (?s, ?o)) }',
        st, msg, VECTOR (), 0, mdta, rset);
  IF (st <> '00000')
    RETURN 'STATE:' || st || ' ' || msg;
  IF (NOT isarray (rset) OR length (rset) = 0)
    RETURN 'NOROWS';
  RETURN cast (rset[0][0] AS VARCHAR);
}
;

SELECT GTEST_AC_FILTERED ();
ECHO BOTH ": AC2 a FILTER narrows the graph (1, not 2) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- AC.3: the option answers exactly as a transient graph built by hand from
-- the same edges.  Both sides are computed in one query, so any difference
-- is the option's.
SELECT GRAPH_LOAD_EDGES ('urn:ac:ref', 'urn:ac:link',
  vector (vector (iri_to_id ('urn:ac:a'), iri_to_id ('urn:ac:b')),
          vector (iri_to_id ('urn:ac:a'), iri_to_id ('urn:ac:c')),
          vector (iri_to_id ('urn:ac:b'), iri_to_id ('urn:ac:c'))));
ECHO BOTH ": AC3a reference graph built = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";

CREATE PROCEDURE GTEST_AC_SAME ()
{
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  DECLARE i INT;
  st := '00000';
  msg := '';
  EXEC ('SPARQL SELECT DISTINCT ?s
           (bif:pagerank (?s, ''urn:ac:ref'', ''urn:ac:link'') AS ?viaref)
           ?viaedges
         FROM <urn:ac:src>
         WHERE { ?s <urn:ac:link> ?o .
                 ?s bif:pagerank ?viaedges OPTION (edges (?s, ?o)) }
         ORDER BY ?s',
        st, msg, VECTOR (), 0, mdta, rset);
  IF (st <> '00000')
    RETURN 'STATE:' || st || ' ' || msg;
  IF (NOT isarray (rset) OR length (rset) = 0)
    RETURN 'NOROWS';
  FOR (i := 0; i < length (rset); i := i + 1)
    {
      DECLARE r, e DOUBLE PRECISION;
      r := rset[i][1];
      e := rset[i][2];
      IF (r IS NULL OR e IS NULL)
        RETURN sprintf ('%s: NULL', cast (rset[i][0] AS VARCHAR));
      IF (ABS (r - e) > 0.000000001)
        RETURN sprintf ('%s: %f vs %f', cast (rset[i][0] AS VARCHAR), r, e);
    }
  RETURN 'SAME';
}
;

SELECT GTEST_AC_SAME ();
ECHO BOTH ": AC3b option agrees with a hand-built graph = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] SAME "PASSED" "***FAILED";

-- AC.4: EDGES and GRAPH name two different graphs, so asking for both is
-- rejected where it is written rather than resolved by precedence.
CREATE PROCEDURE GTEST_AC_BOTH ()
{
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  st := '00000';
  msg := '';
  EXEC ('SPARQL SELECT ?d FROM <urn:ac:src>
         WHERE { ?s <urn:ac:link> ?o .
                 ?s bif:degree_centrality ?d
                   OPTION (edges (?s, ?o), graph <urn:ac:src>) }',
        st, msg, VECTOR (), 0, mdta, rset);
  IF (st = '00000')
    RETURN 'ACCEPTED';
  IF (strstr (msg, 'not both') IS NULL)
    RETURN 'WRONGERR:' || msg;
  RETURN 'REJECTED';
}
;

SELECT GTEST_AC_BOTH ();
ECHO BOTH ": AC4 EDGES with GRAPH is rejected = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] REJECTED "PASSED" "***FAILED";

-- AC.5: nothing was written.  The graph exists for the query and the store
-- is untouched -- the whole point of the feature for federated rows.
SPARQL SELECT COUNT(*) AS ?c FROM <urn:ac:src> WHERE { ?s ?p ?o };
ECHO BOTH ": AC5 store still holds its 5 triples = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";

SELECT COUNT(*) FROM DB.DBA.RDF_QUAD
  WHERE G = iri_to_id ('urn:graph:edges:1', 0);
ECHO BOTH ": AC5b no transient graph was persisted = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- AC.6: past one vectored batch.  A collector that saw only a batch would
-- build a path where the data is a ring, and every rank would disagree.
CREATE PROCEDURE GTEST_AC_BIG (IN n INT)
{
  DECLARE i INT;
  DECLARE s VARCHAR;
  DECLARE e ANY;
  s := '';
  e := make_array (n, 'any');
  FOR (i := 0; i < n; i := i + 1)
    {
      s := s || sprintf ('<urn:ac:big:n%d> <urn:ac:big:e> <urn:ac:big:n%d> . ',
                         i, mod (i + 1, n));
      aset (e, i, vector (iri_to_id (sprintf ('urn:ac:big:n%d', i)),
                          iri_to_id (sprintf ('urn:ac:big:n%d', mod (i + 1, n)))));
    }
  DB.DBA.TTLP (s, '', 'urn:ac:big');
  -- One extra edge only in the store, so the FROM graph and the collected
  -- set cannot coincide: an ignored option would rank against a ring plus
  -- a chord and disagree everywhere.
  DB.DBA.TTLP ('<urn:ac:big:n0> <urn:ac:big:x> <urn:ac:big:n7> .', '', 'urn:ac:big');
  COMMIT WORK;
  GRAPH_LOAD_EDGES ('urn:ac:bigref', 'urn:ac:big:e', e);
  RETURN n;
}
;

SELECT GTEST_AC_BIG (5000);
ECHO BOTH ": AC6a big ring built = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 5000 "PASSED" "***FAILED";

CREATE PROCEDURE GTEST_AC_BIGSAME ()
{
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  DECLARE i, bad INT;
  st := '00000';
  msg := '';
  bad := 0;
  EXEC ('SPARQL SELECT ?n
           (bif:pagerank (?n, ''urn:ac:bigref'', ''urn:ac:big:e'') AS ?viaref)
           ?viaedges
         FROM <urn:ac:big>
         WHERE { ?n <urn:ac:big:e> ?o .
                 ?n bif:pagerank ?viaedges OPTION (edges (?n, ?o)) }',
        st, msg, VECTOR (), 0, mdta, rset);
  IF (st <> '00000')
    RETURN 'STATE:' || st || ' ' || msg;
  IF (NOT isarray (rset) OR length (rset) < 5000)
    RETURN sprintf ('%d rows', case when isarray (rset) then length (rset) else -1 end);
  FOR (i := 0; i < length (rset); i := i + 1)
    {
      DECLARE r, e DOUBLE PRECISION;
      r := rset[i][1];
      e := rset[i][2];
      IF (r IS NULL OR e IS NULL OR ABS (r - e) > 0.000000001)
        bad := bad + 1;
    }
  IF (bad > 0)
    RETURN sprintf ('%d of %d rows differ', bad, length (rset));
  RETURN 'SAME';
}
;

SELECT GTEST_AC_BIGSAME ();
ECHO BOTH ": AC6b 5000 rows, every node agrees = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] SAME "PASSED" "***FAILED";

-- AC.7: an endpoint the pattern does not bind is caught where it is
-- written.  Left to run, it reaches the loader as a NULL and fails there
-- naming an edge number instead of the variable.
CREATE PROCEDURE GTEST_AC_UNBOUND ()
{
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  st := '00000';
  msg := '';
  EXEC ('SPARQL SELECT ?d FROM <urn:ac:src>
         WHERE { ?s <urn:ac:link> ?o .
                 ?s bif:degree_centrality ?d OPTION (edges (?s, ?nosuch)) }',
        st, msg, VECTOR (), 0, mdta, rset);
  IF (st = '00000')
    RETURN 'ACCEPTED';
  IF (strstr (msg, 'not bound by') IS NULL)
    RETURN 'WRONGERR:' || msg;
  RETURN 'REJECTED';
}
;

SELECT GTEST_AC_UNBOUND ();
ECHO BOTH ": AC7 an unbound endpoint is rejected = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] REJECTED "PASSED" "***FAILED";

-- AC.8: endpoints bound by a nested subselect rather than by a triple of
-- the group itself.  This is the SERVICE shape -- a federated block holds
-- a SELECT, and the names it projects live in that select's retvals, two
-- levels down -- and it is the whole point of the feature.  A check that
-- looks only for triples rejects it, which is a regression this pins.
CREATE PROCEDURE GTEST_AC_NESTED ()
{
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  st := '00000';
  msg := '';
  EXEC ('SPARQL SELECT DISTINCT ?d
         FROM <urn:ac:src>
         WHERE { { SELECT ?s ?o WHERE { ?s <urn:ac:link> ?o } }
                 ?s bif:degree_centrality ?d OPTION (edges (?s, ?o))
                 FILTER (?s = iri ("urn:ac:a")) }',
        st, msg, VECTOR (), 0, mdta, rset);
  IF (st <> '00000')
    RETURN 'STATE:' || st || ' ' || msg;
  IF (NOT isarray (rset) OR length (rset) = 0)
    RETURN 'NOROWS';
  RETURN cast (rset[0][0] AS VARCHAR);
}
;

SELECT GTEST_AC_NESTED ();
ECHO BOTH ": AC8 endpoints bound by a nested subselect (2, not 4) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

-- AC.11: an endpoint a subquery binds but does not project.
--
-- The name is right there in the query text, so "not bound by the
-- pattern it collects" reads as though the engine cannot see it.  What
-- is actually wrong is the projection: a subquery exports only the
-- variables it selects, so this is the shape a federated query falls
-- into when the SERVICE block wraps a SELECT that forgets one.  The
-- message has to say which of the two it is.
CREATE PROCEDURE GTEST_AC_UNPROJECTED ()
{
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  st := '00000';
  msg := '';
  EXEC ('SPARQL SELECT ?s ?d FROM <urn:ac:src>
         WHERE { { SELECT ?o WHERE { ?s <urn:ac:link> ?o } }
                 ?s bif:degree_centrality ?d OPTION (edges (?s, ?o)) }',
        st, msg, VECTOR (), 0, mdta, rset);
  IF (st = '00000')
    RETURN 'ACCEPTED';
  IF (strstr (msg, 'does not project') IS NULL)
    RETURN 'GENERIC:' || msg;
  RETURN 'SAYSPROJECT';
}
;

SELECT GTEST_AC_UNPROJECTED ();
ECHO BOTH ": AC11 an unprojected endpoint says so = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] SAYSPROJECT "PASSED" "***FAILED";

-- AC.12: and a name that appears nowhere still gets the plain message,
-- so the new wording does not swallow the ordinary typo.
CREATE PROCEDURE GTEST_AC_ABSENT ()
{
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  st := '00000';
  msg := '';
  EXEC ('SPARQL SELECT ?s ?d FROM <urn:ac:src>
         WHERE { ?s <urn:ac:link> ?o .
                 ?s bif:degree_centrality ?d OPTION (edges (?s, ?nowhere)) }',
        st, msg, VECTOR (), 0, mdta, rset);
  IF (st = '00000')
    RETURN 'ACCEPTED';
  IF (strstr (msg, 'does not project') IS NOT NULL)
    RETURN 'WRONGMSG:' || msg;
  IF (strstr (msg, 'not bound by') IS NULL)
    RETURN 'WRONGERR:' || msg;
  RETURN 'PLAIN';
}
;

SELECT GTEST_AC_ABSENT ();
ECHO BOTH ": AC12 a name bound nowhere still gets the plain message = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] PLAIN "PASSED" "***FAILED";

-- AC.9: collecting a solution set is linear in its size.
--
-- The collector is the whole cost of the feature on a large federated
-- result, and the shape of that cost is not visible in any answer -- a
-- quadratic collector returns exactly the right graph, slowly.  It first
-- shipped quadratic: `ctx := vector (arr, used + 1)` at the end of each
-- accumulator step copied the whole accumulated array into a fresh
-- wrapper, which is precisely the O(n^2) the geometric growth above it
-- was there to avoid.  Measured then: 500 edges 55 ms, 1000 214 ms,
-- 2000 830 ms, 4000 3246 ms, 8000 13147 ms.
--
-- A ratio rather than a budget, so the assertion means the same thing on
-- a slow machine as on a fast one: four times the rows should cost about
-- four times the time.  Quadratic costs sixteen.  The threshold is 8 --
-- twice the linear expectation, half the quadratic one.
CREATE TABLE GTEST_AC_EDGES (I INT PRIMARY KEY, S IRI_ID, O IRI_ID);

CREATE PROCEDURE GTEST_AC_FILL (IN n INT)
{
  DECLARE i INT;
  DELETE FROM GTEST_AC_EDGES;
  FOR (i := 0; i < n; i := i + 1)
    INSERT INTO GTEST_AC_EDGES VALUES (i,
      iri_to_id (sprintf ('urn:ac:sc:n%d', i)),
      iri_to_id (sprintf ('urn:ac:sc:n%d', mod (i + 1, n))));
  COMMIT WORK;
  RETURN n;
}
;

CREATE PROCEDURE GTEST_AC_TIME (IN n INT)
{
  DECLARE t0 INT;
  DECLARE g VARCHAR;
  GTEST_AC_FILL (n);
  t0 := msec_time ();
  SELECT GRAPH_EDGES_AGG (S, O) INTO g FROM GTEST_AC_EDGES;
  t0 := msec_time () - t0;
  GRAPH_UNLOAD_EDGES (g);
  RETURN t0;
}
;

CREATE PROCEDURE GTEST_AC_LINEAR ()
{
  DECLARE small, big INT;
  GTEST_AC_TIME (4000);           -- warm the page cache and the plan
  small := GTEST_AC_TIME (4000);
  big := GTEST_AC_TIME (16000);
  -- Below the clock's resolution the ratio is noise, not evidence; a run
  -- that fast is not quadratic at this size under any reading.
  IF (small < 5)
    RETURN 'LINEAR';
  IF (big > small * 8)
    RETURN sprintf ('QUADRATIC: 4000 %d ms, 16000 %d ms', small, big);
  RETURN 'LINEAR';
}
;

SELECT GTEST_AC_LINEAR ();
ECHO BOTH ": AC9 collecting a solution set is linear in its size = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] LINEAR "PASSED" "***FAILED";

-- AC.10: and the collected graph is still right at that size.
CREATE PROCEDURE GTEST_AC_LINEAR_OK ()
{
  DECLARE g VARCHAR;
  DECLARE d ANY;
  GTEST_AC_FILL (16000);
  SELECT GRAPH_EDGES_AGG (S, O) INTO g FROM GTEST_AC_EDGES;
  d := GRAPH_DEGREE_CENTRALITY ('urn:ac:sc:n0', g, NULL, 0);
  GRAPH_UNLOAD_EDGES (g);
  RETURN cast (d AS VARCHAR);
}
;

SELECT GTEST_AC_LINEAR_OK ();
ECHO BOTH ": AC10 a 16000-edge ring still reads degree 2 = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

DROP TABLE GTEST_AC_EDGES;

SELECT GRAPH_UNLOAD_EDGES ('urn:ac:ref');
SELECT GRAPH_UNLOAD_EDGES ('urn:ac:bigref');

-- ============================================================================
-- Group AD: weights on the rows a query collects
--
--   ?actor bif:pagerank ?score OPTION (edges (?film, ?actor, ?weight))
--
-- A third variable carries the weight of each collected edge, so a
-- weighted algorithm can run over rows that were never stored.  Without
-- it the only way to weight an analysis was a weight *predicate* read
-- from the quad store, which a collected graph has no triples for.
--
-- That combination -- edges with weight -- used to be accepted and then
-- silently ignored, returning unweighted numbers to a caller who had
-- asked for weighted ones.  AD3 is there so it cannot come back.
-- ============================================================================

SPARQL CLEAR GRAPH <urn:ad:src>;
SPARQL INSERT DATA INTO GRAPH <urn:ad:src> {
  <urn:ad:a> <urn:ad:link> <urn:ad:b> .
  <urn:ad:a> <urn:ad:link> <urn:ad:c> .
  <urn:ad:b> <urn:ad:link> <urn:ad:c> .
  <urn:ad:a> <urn:ad:pop> "1"^^<http://www.w3.org/2001/XMLSchema#double> .
  <urn:ad:b> <urn:ad:pop> "50"^^<http://www.w3.org/2001/XMLSchema#double> .
  <urn:ad:c> <urn:ad:pop> "99"^^<http://www.w3.org/2001/XMLSchema#double>
};

-- AD.1: the weight changes the answer.
--
-- Measured on <urn:ad:b>, which has an incoming edge.  <urn:ad:a> has
-- none, so its rank is the base value and no edge weight can move it --
-- an earlier version of this test sampled the first row, got <urn:ad:a>,
-- and reported a working implementation as broken.
--
-- Unweighted, a's rank splits evenly over two out-edges, so b receives
-- half.  Weighted it receives 50/149, because a->c weighs 99.
CREATE PROCEDURE GTEST_AD_RANK (IN weighted INT)
{
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  DECLARE q VARCHAR;
  st := '00000';
  msg := '';
  IF (weighted)
    q := 'SPARQL SELECT DISTINCT ?s ?r FROM <urn:ad:src>
          WHERE { ?s <urn:ad:link> ?o . ?o <urn:ad:pop> ?w .
                  ?s bif:pagerank ?r OPTION (edges (?s, ?o, ?w)) }';
  ELSE
    q := 'SPARQL SELECT DISTINCT ?s ?r FROM <urn:ad:src>
          WHERE { ?s <urn:ad:link> ?o . ?o <urn:ad:pop> ?w .
                  ?s bif:pagerank ?r OPTION (edges (?s, ?o)) }';
  EXEC (q, st, msg, VECTOR (), 0, mdta, rset);
  IF (st <> '00000')
    RETURN 'STATE:' || st || ' ' || msg;
  IF (NOT isarray (rset) OR length (rset) = 0)
    RETURN 'NOROWS';
  -- Picked out of the result rather than filtered for in the query: a
  -- FILTER narrows the collected graph as well as the output, so asking
  -- only about <urn:ad:b> would build a graph of b's edges alone and the
  -- weights would have nothing left to change.
  DECLARE i INT;
  FOR (i := 0; i < length (rset); i := i + 1)
    {
      IF (cast (rset[i][0] AS VARCHAR) = 'urn:ad:b')
        RETURN sprintf ('%.12f', cast (rset[i][1] AS DOUBLE PRECISION));
    }
  RETURN 'NOB';
}
;

CREATE PROCEDURE GTEST_AD_DIFFERS ()
{
  DECLARE w, u VARCHAR;
  w := GTEST_AD_RANK (1);
  u := GTEST_AD_RANK (0);
  IF (w LIKE 'STATE:%' OR w = 'NOROWS')
    RETURN w;
  IF (w = u)
    RETURN 'IGNORED:' || w;
  RETURN 'DIFFERS';
}
;

SELECT GTEST_AD_DIFFERS ();
ECHO BOTH ": AD1 a collected weight changes the answer = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] DIFFERS "PASSED" "***FAILED";

-- AD.2: and it is the same answer the same weights give by another
-- route.  Two routes, because one of them alone proves nothing: a
-- reference that also ignored its weights would agree with an option
-- that ignored them.
--
--   * a transient graph built by hand with GRAPH_LOAD_EDGES_W
--   * the same weights as W3C reification triples in the quad store
--
-- The reification path predates this work and is covered elsewhere, so
-- agreeing with it is independent evidence.
CREATE PROCEDURE GTEST_AD_SAME ()
{
  DECLARE viaopt, viahand, viardf, plain DOUBLE PRECISION;
  DECLARE w VARCHAR;
  GRAPH_LOAD_EDGES_W ('urn:ad:ref', 'urn:ad:link',
    vector (vector (iri_to_id ('urn:ad:a'), iri_to_id ('urn:ad:b'), 50.0),
            vector (iri_to_id ('urn:ad:a'), iri_to_id ('urn:ad:c'), 99.0),
            vector (iri_to_id ('urn:ad:b'), iri_to_id ('urn:ad:c'), 99.0)));
  GRAPH_LOAD_EDGES ('urn:ad:plain', 'urn:ad:link',
    vector (vector (iri_to_id ('urn:ad:a'), iri_to_id ('urn:ad:b')),
            vector (iri_to_id ('urn:ad:a'), iri_to_id ('urn:ad:c')),
            vector (iri_to_id ('urn:ad:b'), iri_to_id ('urn:ad:c'))));
  w := GTEST_AD_RANK (1);
  IF (w LIKE 'STATE:%' OR w = 'NOROWS')
    { GRAPH_UNLOAD_EDGES ('urn:ad:ref'); GRAPH_UNLOAD_EDGES ('urn:ad:plain'); RETURN w; }
  viaopt  := cast (w AS DOUBLE PRECISION);
  viahand := GRAPH_PAGERANK_WEIGHTED ('urn:ad:b', 'urn:ad:ref', 'urn:ad:link');
  plain   := GRAPH_PAGERANK_WEIGHTED ('urn:ad:b', 'urn:ad:plain', 'urn:ad:link');
  viardf  := GRAPH_PAGERANK_WEIGHTED ('urn:ad:b', 'urn:ad:wrdf', 'urn:ad:link',
                                      'urn:ad:wt');
  GRAPH_UNLOAD_EDGES ('urn:ad:ref');
  GRAPH_UNLOAD_EDGES ('urn:ad:plain');
  IF (viahand IS NULL OR viardf IS NULL OR plain IS NULL)
    RETURN 'NULL';
  -- the hand-built reference must itself be weighing something
  IF (ABS (viahand - plain) < 0.000000001)
    RETURN 'REFUNWEIGHTED';
  IF (ABS (viaopt - viahand) > 0.000000001)
    RETURN sprintf ('hand: %.12f vs %.12f', viaopt, viahand);
  IF (ABS (viaopt - viardf) > 0.000000001)
    RETURN sprintf ('rdf: %.12f vs %.12f', viaopt, viardf);
  RETURN 'SAME';
}
;

-- the same weights again, as reification, for the third opinion above
SPARQL PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT DATA INTO GRAPH <urn:ad:wrdf> {
  <urn:ad:a> <urn:ad:link> <urn:ad:b> .
  <urn:ad:a> <urn:ad:link> <urn:ad:c> .
  <urn:ad:b> <urn:ad:link> <urn:ad:c> .
  <urn:ad:r1> rdf:type rdf:Statement ; rdf:subject <urn:ad:a> ;
    rdf:predicate <urn:ad:link> ; rdf:object <urn:ad:b> ;
    <urn:ad:wt> "50"^^<http://www.w3.org/2001/XMLSchema#double> .
  <urn:ad:r2> rdf:type rdf:Statement ; rdf:subject <urn:ad:a> ;
    rdf:predicate <urn:ad:link> ; rdf:object <urn:ad:c> ;
    <urn:ad:wt> "99"^^<http://www.w3.org/2001/XMLSchema#double> .
  <urn:ad:r3> rdf:type rdf:Statement ; rdf:subject <urn:ad:b> ;
    rdf:predicate <urn:ad:link> ; rdf:object <urn:ad:c> ;
    <urn:ad:wt> "99"^^<http://www.w3.org/2001/XMLSchema#double>
};

SELECT GTEST_AD_SAME ();
ECHO BOTH ": AD2 agrees with the same weights by two other routes = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] SAME "PASSED" "***FAILED";

-- AD.3: edges with a weight PREDICATE is refused.
-- A weight predicate is read from the quad store, and a collected graph
-- has no triples there, so the weight can only be silently dropped.  It
-- was, and the numbers looked plausible.
CREATE PROCEDURE GTEST_AD_PREDWEIGHT ()
{
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  st := '00000';
  msg := '';
  EXEC ('SPARQL SELECT ?s ?r FROM <urn:ad:src>
         WHERE { ?s <urn:ad:link> ?o .
                 ?s bif:pagerank ?r OPTION (edges (?s, ?o), weight <urn:ad:pop>) }',
        st, msg, VECTOR (), 0, mdta, rset);
  IF (st = '00000')
    RETURN 'ACCEPTED';
  IF (strstr (msg, 'third variable') IS NULL)
    RETURN 'WRONGERR:' || msg;
  RETURN 'REJECTED';
}
;

SELECT GTEST_AD_PREDWEIGHT ();
ECHO BOTH ": AD3 edges with a weight predicate is refused = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] REJECTED "PASSED" "***FAILED";

-- AD.4: past one vectored batch, so a weight array that is right for a
-- batch and wrong for the rest cannot pass.
CREATE PROCEDURE GTEST_AD_BIG (IN n INT)
{
  DECLARE i INT;
  DECLARE s VARCHAR;
  DECLARE e ANY;
  s := '';
  e := make_array (n, 'any');
  FOR (i := 0; i < n; i := i + 1)
    {
      s := s || sprintf ('<urn:ad:big:n%d> <urn:ad:big:e> <urn:ad:big:n%d> . ',
                         i, mod (i + 1, n));
      s := s || sprintf ('<urn:ad:big:n%d> <urn:ad:big:w> "%d"^^<http://www.w3.org/2001/XMLSchema#double> . ',
                         i, 1 + mod (i, 7));
      aset (e, i, vector (iri_to_id (sprintf ('urn:ad:big:n%d', i)),
                          iri_to_id (sprintf ('urn:ad:big:n%d', mod (i + 1, n))),
                          cast (1 + mod (mod (i + 1, n), 7) AS DOUBLE PRECISION)));
    }
  DB.DBA.TTLP (s, '', 'urn:ad:big');
  COMMIT WORK;
  GRAPH_LOAD_EDGES_W ('urn:ad:bigref', 'urn:ad:big:e', e);
  RETURN n;
}
;

SELECT GTEST_AD_BIG (5000);
ECHO BOTH ": AD4a big weighted ring built = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 5000 "PASSED" "***FAILED";

CREATE PROCEDURE GTEST_AD_BIGSAME ()
{
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  DECLARE i, bad INT;
  st := '00000';
  msg := '';
  bad := 0;
  EXEC ('SPARQL SELECT DISTINCT ?n ?viaedges FROM <urn:ad:big>
         WHERE { ?n <urn:ad:big:e> ?o . ?o <urn:ad:big:w> ?w .
                 ?n bif:pagerank ?viaedges OPTION (edges (?n, ?o, ?w)) }',
        st, msg, VECTOR (), 0, mdta, rset);
  IF (st <> '00000')
    RETURN 'STATE:' || st || ' ' || msg;
  IF (NOT isarray (rset) OR length (rset) < 5000)
    RETURN sprintf ('%d rows', case when isarray (rset) then length (rset) else -1 end);
  FOR (i := 0; i < length (rset); i := i + 1)
    {
      DECLARE e, r DOUBLE PRECISION;
      e := rset[i][1];
      r := GRAPH_PAGERANK_WEIGHTED ((rset[i][0]), 'urn:ad:bigref', 'urn:ad:big:e');
      IF (e IS NULL OR r IS NULL OR ABS (e - r) > 0.000000001)
        bad := bad + 1;
    }
  IF (bad > 0)
    RETURN sprintf ('%d of %d rows differ', bad, length (rset));
  RETURN 'SAME';
}
;

SELECT GTEST_AD_BIGSAME ();
ECHO BOTH ": AD4b 5000 weighted rows agree = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] SAME "PASSED" "***FAILED";

-- AD.5: zero is a weight, and a missing one is not.
--
-- Virtuoso boxes a small integer inline, so DV_TYPE_OF() calls anything
-- that is not a box pointer a DV_LONG_INT and the integer 0 is the same
-- pointer as C NULL.  Testing the pointer to catch a null therefore
-- rejects a weight of zero -- which cost a live federated query, where
-- one actor of 366 had no sitelinks and so weighed 0.  A real SQL NULL
-- is a DV_DB_NULL box, and is still refused.
CREATE PROCEDURE GTEST_AD_ZERO (IN w ANY)
{
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  st := '00000';
  msg := '';
  EXEC ('select GRAPH_LOAD_EDGES_W (''urn:ad:z'', ''urn:ad:link'', ' ||
        'vector (vector (iri_to_id (''urn:ad:a''), iri_to_id (''urn:ad:b''), ?)))',
        st, msg, VECTOR (w), 0, mdta, rset);
  IF (st = '00000')
    GRAPH_UNLOAD_EDGES ('urn:ad:z');
  RETURN st;
}
;

CREATE PROCEDURE GTEST_AD_ZERONULL ()
{
  DECLARE z, n, s VARCHAR;
  z := GTEST_AD_ZERO (0);
  n := GTEST_AD_ZERO (NULL);
  s := GTEST_AD_ZERO (2.5);
  IF (z <> '00000')
    RETURN 'ZERO_REFUSED:' || z;
  IF (s <> '00000')
    RETURN 'NUM_REFUSED:' || s;
  IF (n = '00000')
    RETURN 'NULL_ACCEPTED';
  RETURN 'OK';
}
;

SELECT GTEST_AD_ZERONULL ();
ECHO BOTH ": AD5 zero weighs, NULL does not = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] OK "PASSED" "***FAILED";

SELECT GRAPH_UNLOAD_EDGES ('urn:ad:bigref');

-- ============================================================================
-- Group AE: a weighted algorithm honours its own parameters
--
-- The reference documents damping, max_iter, tolerance and directed for
-- bif:pagerank, and max_iter and tolerance for bif:eigenvector.  On the
-- WEIGHTED path both BIFs passed NULL for the parameter block, so the
-- algorithm used its built-in defaults and every one of those keywords
-- was accepted, validated, and then dropped.
--
-- Nothing said so.  A query asking for damping 0.5 got damping 0.85 and
-- a plausible number.  It is easiest to hit through OPTION (edges (?a,
-- ?b, ?w)), which dispatches to the weighted variant, but it was there
-- for the weight-predicate form too.
-- ============================================================================

SPARQL CLEAR GRAPH <urn:ae:src>;
SPARQL PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT DATA INTO GRAPH <urn:ae:src> {
  <urn:ae:a> <urn:ae:e> <urn:ae:b> .
  <urn:ae:a> <urn:ae:e> <urn:ae:c> .
  <urn:ae:b> <urn:ae:e> <urn:ae:c> .
  <urn:ae:c> <urn:ae:e> <urn:ae:a> .
  <urn:ae:b> <urn:ae:w> "2"^^<http://www.w3.org/2001/XMLSchema#double> .
  <urn:ae:c> <urn:ae:w> "3"^^<http://www.w3.org/2001/XMLSchema#double> .
  <urn:ae:a> <urn:ae:w> "5"^^<http://www.w3.org/2001/XMLSchema#double> .
  <urn:ae:r1> rdf:type rdf:Statement ; rdf:subject <urn:ae:a> ;
    rdf:predicate <urn:ae:e> ; rdf:object <urn:ae:b> ;
    <urn:ae:wt> "2"^^<http://www.w3.org/2001/XMLSchema#double> .
  <urn:ae:r2> rdf:type rdf:Statement ; rdf:subject <urn:ae:a> ;
    rdf:predicate <urn:ae:e> ; rdf:object <urn:ae:c> ;
    <urn:ae:wt> "3"^^<http://www.w3.org/2001/XMLSchema#double> .
  <urn:ae:r3> rdf:type rdf:Statement ; rdf:subject <urn:ae:b> ;
    rdf:predicate <urn:ae:e> ; rdf:object <urn:ae:c> ;
    <urn:ae:wt> "3"^^<http://www.w3.org/2001/XMLSchema#double> .
  <urn:ae:r4> rdf:type rdf:Statement ; rdf:subject <urn:ae:c> ;
    rdf:predicate <urn:ae:e> ; rdf:object <urn:ae:a> ;
    <urn:ae:wt> "5"^^<http://www.w3.org/2001/XMLSchema#double>
};

-- Runs one analytics query and returns <urn:ae:a>'s score to 12 places.
-- The node is picked out of the result rather than filtered for: a
-- FILTER would narrow the collected graph as well as the output.
CREATE PROCEDURE GTEST_AE_SCORE (IN opts VARCHAR, IN algo VARCHAR,
  IN weighted_by VARCHAR)
{
  DECLARE st, msg, q VARCHAR;
  DECLARE mdta, rset ANY;
  DECLARE i INT;
  st := '00000';
  msg := '';
  q := sprintf ('SPARQL SELECT DISTINCT ?s ?r FROM <urn:ae:src>
         WHERE { ?s <urn:ae:e> ?o . %s
                 ?s bif:%s ?r OPTION (%s) }',
    case when weighted_by = 'edges' then '?o <urn:ae:w> ?w .' else '' end,
    algo, opts);
  EXEC (q, st, msg, VECTOR (), 0, mdta, rset);
  IF (st <> '00000')
    RETURN 'STATE:' || st || ' ' || msg;
  IF (NOT isarray (rset) OR length (rset) = 0)
    RETURN 'NOROWS';
  FOR (i := 0; i < length (rset); i := i + 1)
    {
      IF (cast (rset[i][0] AS VARCHAR) = 'urn:ae:a')
        RETURN sprintf ('%.12f', cast (rset[i][1] AS DOUBLE PRECISION));
    }
  RETURN 'NOA';
}
;

-- AE.1: damping reaches weighted pagerank, collected-edges form
CREATE PROCEDURE GTEST_AE_DAMPING_EDGES ()
{
  DECLARE hi, lo VARCHAR;
  hi := GTEST_AE_SCORE ('edges (?s, ?o, ?w), damping 0.85', 'pagerank', 'edges');
  lo := GTEST_AE_SCORE ('edges (?s, ?o, ?w), damping 0.50', 'pagerank', 'edges');
  IF (hi LIKE 'STATE:%' OR hi LIKE 'NO%')
    RETURN hi;
  IF (hi = lo)
    RETURN 'DROPPED:' || hi;
  RETURN 'HONOURED';
}
;

SELECT GTEST_AE_DAMPING_EDGES ();
ECHO BOTH ": AE1 damping reaches weighted pagerank (edges) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] HONOURED "PASSED" "***FAILED";

-- AE.2: and through the weight-predicate form, which had the same gap
CREATE PROCEDURE GTEST_AE_DAMPING_PRED ()
{
  DECLARE hi, lo VARCHAR;
  hi := GTEST_AE_SCORE ('weight <urn:ae:wt>, damping 0.85', 'pagerank', 'pred');
  lo := GTEST_AE_SCORE ('weight <urn:ae:wt>, damping 0.50', 'pagerank', 'pred');
  IF (hi LIKE 'STATE:%' OR hi LIKE 'NO%')
    RETURN hi;
  IF (hi = lo)
    RETURN 'DROPPED:' || hi;
  RETURN 'HONOURED';
}
;

SELECT GTEST_AE_DAMPING_PRED ();
ECHO BOTH ": AE2 damping reaches weighted pagerank (weight pred) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] HONOURED "PASSED" "***FAILED";

-- AE.3: max_iter reaches weighted pagerank.  One iteration cannot have
-- reached the converged answer on this graph.
CREATE PROCEDURE GTEST_AE_MAXITER ()
{
  DECLARE few, many VARCHAR;
  few  := GTEST_AE_SCORE ('edges (?s, ?o, ?w), max_iter 1', 'pagerank', 'edges');
  many := GTEST_AE_SCORE ('edges (?s, ?o, ?w), max_iter 100', 'pagerank', 'edges');
  IF (few LIKE 'STATE:%' OR few LIKE 'NO%')
    RETURN few;
  IF (few = many)
    RETURN 'DROPPED:' || few;
  RETURN 'HONOURED';
}
;

SELECT GTEST_AE_MAXITER ();
ECHO BOTH ": AE3 max_iter reaches weighted pagerank = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] HONOURED "PASSED" "***FAILED";

-- AE.4: and reaches weighted eigenvector, which passed NULL the same way
CREATE PROCEDURE GTEST_AE_EIGEN ()
{
  DECLARE few, many VARCHAR;
  few  := GTEST_AE_SCORE ('edges (?s, ?o, ?w), max_iter 1', 'eigenvector', 'edges');
  many := GTEST_AE_SCORE ('edges (?s, ?o, ?w), max_iter 100', 'eigenvector', 'edges');
  IF (few LIKE 'STATE:%' OR few LIKE 'NO%')
    RETURN few;
  IF (few = many)
    RETURN 'DROPPED:' || few;
  RETURN 'HONOURED';
}
;

SELECT GTEST_AE_EIGEN ();
ECHO BOTH ": AE4 max_iter reaches weighted eigenvector = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] HONOURED "PASSED" "***FAILED";

-- AE.5: the documented default is still the default.  Asking for
-- damping 0.85 explicitly must equal not asking at all, or the fix
-- above would have changed every existing weighted answer.
CREATE PROCEDURE GTEST_AE_DEFAULT ()
{
  DECLARE stated, silent VARCHAR;
  stated := GTEST_AE_SCORE ('edges (?s, ?o, ?w), damping 0.85', 'pagerank', 'edges');
  silent := GTEST_AE_SCORE ('edges (?s, ?o, ?w)', 'pagerank', 'edges');
  IF (stated LIKE 'STATE:%' OR stated LIKE 'NO%')
    RETURN stated;
  IF (stated <> silent)
    RETURN sprintf ('%s vs %s', stated, silent);
  RETURN 'SAME';
}
;

-- AE.6: normalized reaches weighted closeness.
--
-- On its own graph, and measured on a node that does not reach
-- everything.  Normalizing scales by reached/(n-1), so on the strongly
-- connected fixture above that factor is 1 and the keyword cannot show
-- itself however faithfully it is forwarded -- an earlier version of
-- this test used it and reported a working forward as dropped.  Here the
-- chain a->b->c->d leaves <urn:ae:ch:b> reaching two of three.
SPARQL CLEAR GRAPH <urn:ae:chain>;
SPARQL INSERT DATA INTO GRAPH <urn:ae:chain> {
  <urn:ae:ch:a> <urn:ae:e> <urn:ae:ch:b> .
  <urn:ae:ch:b> <urn:ae:e> <urn:ae:ch:c> .
  <urn:ae:ch:c> <urn:ae:e> <urn:ae:ch:d> .
  <urn:ae:ch:b> <urn:ae:w> "1"^^<http://www.w3.org/2001/XMLSchema#double> .
  <urn:ae:ch:c> <urn:ae:w> "1"^^<http://www.w3.org/2001/XMLSchema#double> .
  <urn:ae:ch:d> <urn:ae:w> "1"^^<http://www.w3.org/2001/XMLSchema#double>
};

CREATE PROCEDURE GTEST_AE_CLOSE_ONE (IN norm INT)
{
  DECLARE st, msg, q VARCHAR;
  DECLARE mdta, rset ANY;
  DECLARE i INT;
  st := '00000';
  msg := '';
  q := sprintf ('SPARQL SELECT DISTINCT ?s ?r FROM <urn:ae:chain>
         WHERE { ?s <urn:ae:e> ?o . ?o <urn:ae:w> ?w .
                 ?s bif:closeness ?r OPTION (edges (?s, ?o, ?w), normalized %d) }', norm);
  EXEC (q, st, msg, VECTOR (), 0, mdta, rset);
  IF (st <> '00000')
    RETURN 'STATE:' || st || ' ' || msg;
  IF (NOT isarray (rset) OR length (rset) = 0)
    RETURN 'NOROWS';
  FOR (i := 0; i < length (rset); i := i + 1)
    {
      IF (cast (rset[i][0] AS VARCHAR) = 'urn:ae:ch:b')
        RETURN sprintf ('%.12f', cast (rset[i][1] AS DOUBLE PRECISION));
    }
  RETURN 'NOB';
}
;

CREATE PROCEDURE GTEST_AE_CLOSENESS ()
{
  DECLARE raw, norm VARCHAR;
  raw  := GTEST_AE_CLOSE_ONE (0);
  norm := GTEST_AE_CLOSE_ONE (1);
  IF (raw LIKE 'STATE:%' OR raw LIKE 'NO%')
    RETURN raw;
  IF (raw = norm)
    RETURN 'DROPPED:' || raw;
  RETURN 'HONOURED';
}
;

SELECT GTEST_AE_CLOSENESS ();
ECHO BOTH ": AE6 normalized reaches weighted closeness = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] HONOURED "PASSED" "***FAILED";

-- AE.7 and AE.8 share a fixture, because both need four nodes.
--
-- Betweenness normalization divides by (n-1)(n-2), which at n=3 is
-- exactly 1 -- so on a triangle `normalized 1` and `normalized 0` return
-- the same number however faithfully the keyword is honoured, and an
-- earlier version of AE7 used a triangle and reported a working forward
-- as dropped.  Four nodes, and a node that actually lies on shortest
-- paths, are the minimum that can tell the two apart.
--
-- Every edge weighs 1 on purpose: that makes weighted and unweighted
-- betweenness the same computation, which is what AE8 asserts.
SPARQL CLEAR GRAPH <urn:ae:unit>;
SPARQL INSERT DATA INTO GRAPH <urn:ae:unit> {
  <urn:ae:u:a> <urn:ae:e> <urn:ae:u:b> .
  <urn:ae:u:b> <urn:ae:e> <urn:ae:u:c> .
  <urn:ae:u:c> <urn:ae:e> <urn:ae:u:d> .
  <urn:ae:u:a> <urn:ae:e> <urn:ae:u:c> .
  <urn:ae:u:b> <urn:ae:w> "1"^^<http://www.w3.org/2001/XMLSchema#double> .
  <urn:ae:u:c> <urn:ae:w> "1"^^<http://www.w3.org/2001/XMLSchema#double> .
  <urn:ae:u:d> <urn:ae:w> "1"^^<http://www.w3.org/2001/XMLSchema#double>
};

-- c, not b: b lies on no shortest path and reads 0 under every
-- convention, so it cannot tell any two of them apart.
CREATE PROCEDURE GTEST_AE_UNIT (IN weighted INT, IN extra VARCHAR)
{
  DECLARE st, msg, q VARCHAR;
  DECLARE mdta, rset ANY;
  DECLARE i INT;
  st := '00000';
  msg := '';
  q := sprintf ('SPARQL SELECT DISTINCT ?s ?r FROM <urn:ae:unit>
         WHERE { ?s <urn:ae:e> ?o . ?o <urn:ae:w> ?w .
                 ?s bif:betweenness ?r OPTION (edges (?s, ?o%s)%s) }',
    case when weighted then ', ?w' else '' end,
    case when length (extra) then ', ' || extra else '' end);
  EXEC (q, st, msg, VECTOR (), 0, mdta, rset);
  IF (st <> '00000')
    RETURN 'STATE:' || st || ' ' || msg;
  IF (NOT isarray (rset) OR length (rset) = 0)
    RETURN 'NOROWS';
  FOR (i := 0; i < length (rset); i := i + 1)
    {
      IF (cast (rset[i][0] AS VARCHAR) = 'urn:ae:u:c')
        RETURN sprintf ('%.6f', cast (rset[i][1] AS DOUBLE PRECISION));
    }
  RETURN 'NOC';
}
;

-- AE.7: normalized reaches weighted betweenness.
CREATE PROCEDURE GTEST_AE_BETWEENNESS ()
{
  DECLARE raw, norm VARCHAR;
  raw  := GTEST_AE_UNIT (1, 'normalized 0');
  norm := GTEST_AE_UNIT (1, 'normalized 1');
  IF (raw LIKE 'STATE:%' OR raw LIKE 'NO%')
    RETURN raw;
  IF (raw = norm)
    RETURN 'DROPPED:' || raw;
  RETURN 'HONOURED';
}
;

SELECT GTEST_AE_BETWEENNESS ();
ECHO BOTH ": AE7 normalized reaches weighted betweenness = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] HONOURED "PASSED" "***FAILED";

-- AE.8: the two halves of one measure answer the same question.
--
-- Weighted betweenness used to default to GRAPH_BETWEENNESS_DEFAULT,
-- which normalizes and is directed, while the unweighted SPARQL path
-- passed 0 for both.  So one graph gave two different numbers depending
-- on which half of the implementation a query happened to reach, and
-- neither said so.
--
-- The identity that catches it: on a graph whose every edge weighs 1,
-- weighted and unweighted betweenness are the same computation and must
-- return the same number.  Both now default to raw and undirected --
-- what the unweighted SPARQL path has always done, and what Neo4j GDS
-- does; NetworkX normalizes by default and so disagrees with GDS, which
-- is why the requirement here is only that Virtuoso agree with itself.
CREATE PROCEDURE GTEST_AE_UNIT_CHK ()
{
  DECLARE w, u VARCHAR;
  w := GTEST_AE_UNIT (1, '');
  u := GTEST_AE_UNIT (0, '');
  IF (w LIKE 'STATE:%' OR w LIKE 'NO%')
    RETURN w;
  IF (w <> u)
    RETURN sprintf ('weighted %s vs unweighted %s', w, u);
  RETURN 'AGREE';
}
;

SELECT GTEST_AE_UNIT_CHK ();
ECHO BOTH ": AE8 unit weights give the unweighted answer = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

-- AE.9: a flag whose legal values include 0 must mean 0, however the
-- constant is spelled.
--
-- Virtuoso boxes a small integer inline, so the integer 0 is the same
-- pointer as C NULL, and a guard of the form `if (a && ...)` skips the
-- argument and leaves the default.  damping and max_iter are safe from
-- it -- neither may be 0 -- but `directed`, `direction` and their kind
-- are not.
--
-- This is a guard, not a reproduction: the original failure appeared
-- only when the rows came from a SERVICE, where the plan delivers the
-- constant inline, and `directed 0` was silently read as the default
-- while `directed 0.0` worked.  Locally both spellings already agreed,
-- so this would not have failed before the fix.  What it pins is the
-- invariant that makes the bug impossible to reintroduce quietly: the
-- two spellings must agree, and must not equal `directed 1`.
CREATE PROCEDURE GTEST_AE_ZEROFLAG ()
{
  DECLARE one, zero_i, zero_d VARCHAR;
  one    := GTEST_AE_SCORE ('edges (?s, ?o), directed 1', 'pagerank', 'plain');
  zero_i := GTEST_AE_SCORE ('edges (?s, ?o), directed 0', 'pagerank', 'plain');
  zero_d := GTEST_AE_SCORE ('edges (?s, ?o), directed 0.0', 'pagerank', 'plain');
  IF (one LIKE 'STATE:%' OR one LIKE 'NO%')
    RETURN one;
  IF (zero_i <> zero_d)
    RETURN sprintf ('0 gives %s, 0.0 gives %s', zero_i, zero_d);
  IF (zero_i = one)
    RETURN 'DROPPED:' || zero_i;
  RETURN 'OK';
}
;

-- AE.10: shortest_path_length has a weighted form and must reach it.
--
-- The BIF exists (GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED) and the option
-- table documents `weight` for this predicate, but the compiler's
-- weighted dispatch had no entry for it, so asking for a weighted
-- cheapest-cost was refused outright.
--
-- The fixture is the shape that makes the answer mean something: a->b
-- costs 10 in one hop, a->c->b costs 2 in two.  Unweighted the answer is
-- 1 (hops); weighted it is 2 (cost), and a run that silently ignored the
-- weights would say 1.
SPARQL CLEAR GRAPH <urn:af:src>;
SPARQL INSERT DATA INTO GRAPH <urn:af:src> {
  <urn:af:a> <urn:af:e> <urn:af:b> .
  <urn:af:a> <urn:af:e> <urn:af:c> .
  <urn:af:c> <urn:af:e> <urn:af:b> .
  <urn:af:b> <urn:af:w> "10"^^<http://www.w3.org/2001/XMLSchema#double> .
  <urn:af:c> <urn:af:w> "1"^^<http://www.w3.org/2001/XMLSchema#double>
};

CREATE PROCEDURE GTEST_AE_SPLW (IN weighted INT)
{
  DECLARE st, msg, q VARCHAR;
  DECLARE mdta, rset ANY;
  st := '00000';
  msg := '';
  IF (weighted)
    q := 'SPARQL SELECT DISTINCT ?len FROM <urn:af:src>
          WHERE { ?s <urn:af:e> ?o . ?o <urn:af:w> ?w .
                  <urn:af:b> bif:shortest_path_length ?len
                    OPTION (edges (?s, ?o, ?w), source_node <urn:af:a>) }';
  ELSE
    q := 'SPARQL SELECT DISTINCT ?len FROM <urn:af:src>
          WHERE { ?s <urn:af:e> ?o . ?o <urn:af:w> ?w .
                  <urn:af:b> bif:shortest_path_length ?len
                    OPTION (edges (?s, ?o), source_node <urn:af:a>) }';
  EXEC (q, st, msg, VECTOR (), 0, mdta, rset);
  IF (st <> '00000')
    RETURN 'STATE:' || st || ' ' || msg;
  IF (NOT isarray (rset) OR length (rset) = 0)
    RETURN 'NOROWS';
  RETURN sprintf ('%.6f', cast (rset[0][0] AS DOUBLE PRECISION));
}
;

CREATE PROCEDURE GTEST_AE_SPLW_CHK ()
{
  DECLARE w, u VARCHAR;
  u := GTEST_AE_SPLW (0);
  w := GTEST_AE_SPLW (1);
  IF (w LIKE 'STATE:%')
    RETURN 'REFUSED:' || "LEFT" (w, 80);
  IF (u LIKE 'STATE:%')
    RETURN 'UNW:' || "LEFT" (u, 80);
  IF (w = u)
    RETURN 'IGNORED:' || w;
  RETURN 'HONOURED';
}
;

SELECT GTEST_AE_SPLW_CHK ();
ECHO BOTH ": AE10 shortest_path_length reaches its weighted form = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] HONOURED "PASSED" "***FAILED";

-- AE.11: a weighted traversal can be asked to walk edges both ways.
--
-- opStart/opEnd, or any other "which end did we record first", is a
-- recording convention rather than a direction of travel.  A route over
-- such data has to be free to use an edge backwards, and the weighted
-- BIFs have always taken a direction argument for exactly that -- but
-- the option list did not offer it, so SPARQL could only ever ask for
-- the as-recorded reading.
--
-- The fixture makes the two answers different on purpose: a->b costs 10
-- as recorded, while a-c-b costs 2 but needs the c->a edge walked
-- backwards.
-- Shaped like the data this came from: the weight is a property of the
-- section, not of either endpoint.  Hanging it on the object instead
-- makes every edge into a node weigh the same, which cannot express the
-- graph below -- and the first draft of this test did exactly that, so
-- both readings came back 10 and a working implementation looked broken.
SPARQL CLEAR GRAPH <urn:ag:src>;
SPARQL INSERT DATA INTO GRAPH <urn:ag:src> {
  <urn:ag:s1> <urn:ag:from> <urn:ag:a> ; <urn:ag:to> <urn:ag:b> ;
              <urn:ag:km> "10"^^<http://www.w3.org/2001/XMLSchema#double> .
  <urn:ag:s2> <urn:ag:from> <urn:ag:c> ; <urn:ag:to> <urn:ag:a> ;
              <urn:ag:km> "1"^^<http://www.w3.org/2001/XMLSchema#double> .
  <urn:ag:s3> <urn:ag:from> <urn:ag:c> ; <urn:ag:to> <urn:ag:b> ;
              <urn:ag:km> "1"^^<http://www.w3.org/2001/XMLSchema#double>
};

CREATE PROCEDURE GTEST_AE_SPLDIR (IN opts VARCHAR)
{
  DECLARE st, msg, q VARCHAR;
  DECLARE mdta, rset ANY;
  st := '00000';
  msg := '';
  q := sprintf ('SPARQL SELECT DISTINCT ?len FROM <urn:ag:src>
         WHERE { ?sec <urn:ag:from> ?s ; <urn:ag:to> ?o ; <urn:ag:km> ?w .
                 <urn:ag:b> bif:shortest_path_length ?len OPTION (%s) }', opts);
  EXEC (q, st, msg, VECTOR (), 0, mdta, rset);
  IF (st <> '00000')
    RETURN 'STATE:' || st || ' ' || msg;
  IF (NOT isarray (rset) OR length (rset) = 0)
    RETURN 'NOROWS';
  RETURN sprintf ('%.4f', cast (rset[0][0] AS DOUBLE PRECISION));
}
;

CREATE PROCEDURE GTEST_AE_SPLDIR_CHK ()
{
  DECLARE asrec, both VARCHAR;
  asrec := GTEST_AE_SPLDIR ('edges (?s, ?o, ?w), source_node <urn:ag:a>');
  both  := GTEST_AE_SPLDIR ('edges (?s, ?o, ?w), source_node <urn:ag:a>, direction 2');
  IF (both LIKE 'STATE:%')
    RETURN 'REFUSED:' || "LEFT" (both, 90);
  IF (asrec LIKE 'STATE:%')
    RETURN 'ASREC:' || "LEFT" (asrec, 90);
  IF (asrec = both)
    RETURN 'IGNORED:' || asrec;
  RETURN sprintf ('%s/%s', asrec, both);
}
;

SELECT GTEST_AE_SPLDIR_CHK ();
ECHO BOTH ": AE11 a weighted route can walk both ways = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 10.0000/2.0000 "PASSED" "***FAILED";

-- AE.12 is retired.  It asserted that DIRECTION without a weight was
-- refused, which was right when the only BIFs taking a direction were
-- the weighted ones: accepting the keyword elsewhere would have answered
-- the as-recorded question to a caller who asked for the other.  The
-- unweighted traversals now take a direction of their own, so the
-- refusal is gone and Group AG covers what replaced it.  Kept as a note
-- rather than deleted, because "this used to be refused" is the sort of
-- thing a reader of AG will want to know.

SELECT GTEST_AE_ZEROFLAG ();
ECHO BOTH ": AE9 directed 0 and 0.0 agree, and differ from 1 = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] OK "PASSED" "***FAILED";

SELECT GTEST_AE_DEFAULT ();
ECHO BOTH ": AE5 stating the default changes nothing = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] SAME "PASSED" "***FAILED";

-- ============================================================================
-- Group AF: a weighted whole-graph algorithm runs once, not once per row
--
-- Betweenness, PageRank and eigenvector are whole-graph algorithms: one
-- pass produces a score for every node.  The unweighted forms go through
-- vgraph_scalar_whole_graph(), which runs the pass once per snapshot and
-- serves every row from the cached vector.  The weighted forms called
-- the algorithm directly, so a query over N rows ran the whole pass N
-- times.
--
-- Nothing about the answers showed it.  On the EU rail register, a
-- weighted betweenness over 1,762 sections -- 2.9 s for a single call --
-- had not finished after fifteen minutes, because it was on its way to
-- doing that 1,762 times.
--
-- The assertion is a ratio, so it means the same on any machine: a query
-- over N rows must not cost N single calls.  Uncached the ratio is ~N;
-- cached it is near 1.
-- ============================================================================

CREATE PROCEDURE GTEST_AF_BUILD (IN n INT)
{
  DECLARE i, k INT;
  DECLARE e, e2 ANY;
  DECLARE s VARCHAR;
  -- A ring with a chord every tenth node: enough structure that shortest
  -- paths are not all the same, and sparse enough to stay quick.
  e := make_array (n + n / 10 + 2, 'any');
  e2 := make_array (n + n / 10 + 2, 'any');
  s := '';
  k := 0;
  FOR (i := 0; i < n; i := i + 1)
    {
      aset (e, k, vector (iri_to_id (sprintf ('urn:af:p:n%d', i)),
                          iri_to_id (sprintf ('urn:af:p:n%d', mod (i + 1, n))),
                          cast (1 + mod (i, 5) AS DOUBLE PRECISION)));
      aset (e2, k, vector (iri_to_id (sprintf ('urn:af:p:n%d', i)),
                           iri_to_id (sprintf ('urn:af:p:n%d', mod (i + 1, n)))));
      k := k + 1;
    }
  FOR (i := 0; i < n; i := i + 10)
    {
      aset (e, k, vector (iri_to_id (sprintf ('urn:af:p:n%d', i)),
                          iri_to_id (sprintf ('urn:af:p:n%d', mod (i + 37, n))),
                          cast (2 + mod (i, 3) AS DOUBLE PRECISION)));
      aset (e2, k, vector (iri_to_id (sprintf ('urn:af:p:n%d', i)),
                           iri_to_id (sprintf ('urn:af:p:n%d', mod (i + 37, n)))));
      k := k + 1;
    }
  e := subseq (e, 0, k);
  e2 := subseq (e2, 0, k);
  GRAPH_LOAD_EDGES_W ('urn:af:p:w', 'urn:af:p:e', e);
  GRAPH_LOAD_EDGES ('urn:af:p:u', 'urn:af:p:e', e2);
  RETURN k;
}
;

SELECT GTEST_AF_BUILD (400);
ECHO BOTH ": AF1a weighted perf fixture built = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 440 "PASSED" "***FAILED";

-- One call, so the ratio below has something to be a ratio of.
CREATE PROCEDURE GTEST_AF_ONE (IN weighted INT)
{
  DECLARE t0 INT;
  DECLARE x ANY;
  t0 := msec_time ();
  IF (weighted)
    x := GRAPH_BETWEENNESS_WEIGHTED ('urn:af:p:n0', 'urn:af:p:w', 'urn:af:p:e', NULL, 0, 0);
  ELSE
    x := GRAPH_BETWEENNESS ('urn:af:p:n0', 'urn:af:p:u', 'urn:af:p:e', 0, 0);
  RETURN msec_time () - t0;
}
;

-- Every node of the ring, scored in one query.
CREATE PROCEDURE GTEST_AF_ALL (IN weighted INT)
{
  DECLARE t0 INT;
  DECLARE st, msg, q VARCHAR;
  DECLARE mdta, rset ANY;
  st := '00000';
  msg := '';
  IF (weighted)
    q := 'SELECT COUNT(*), SUM(GRAPH_BETWEENNESS_WEIGHTED (N, ''urn:af:p:w'', ''urn:af:p:e'', NULL, 0, 0)) FROM GTEST_AF_NODES';
  ELSE
    q := 'SELECT COUNT(*), SUM(GRAPH_BETWEENNESS (N, ''urn:af:p:u'', ''urn:af:p:e'', 0, 0)) FROM GTEST_AF_NODES';
  t0 := msec_time ();
  EXEC (q, st, msg, VECTOR (), 0, mdta, rset);
  IF (st <> '00000')
    RETURN -1;
  RETURN msec_time () - t0;
}
;

CREATE TABLE GTEST_AF_NODES (N VARCHAR PRIMARY KEY);

CREATE PROCEDURE GTEST_AF_FILL (IN n INT)
{
  DECLARE i INT;
  DELETE FROM GTEST_AF_NODES;
  FOR (i := 0; i < n; i := i + 1)
    INSERT INTO GTEST_AF_NODES VALUES (sprintf ('urn:af:p:n%d', i));
  COMMIT WORK;
  RETURN (SELECT COUNT(*) FROM GTEST_AF_NODES);
}
;

SELECT GTEST_AF_FILL (400);
ECHO BOTH ": AF1b node table filled = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 400 "PASSED" "***FAILED";

-- AF.2: the unweighted form already runs once.  Here to show the
-- assertion is calibrated -- if this ever fails, the threshold is wrong
-- rather than the weighted path.
CREATE PROCEDURE GTEST_AF_RATIO (IN weighted INT)
{
  DECLARE one, allrows INT;
  GTEST_AF_ONE (weighted);              -- warm the snapshot and the cache
  one := GTEST_AF_ONE (weighted);
  allrows := GTEST_AF_ALL (weighted);
  IF (allrows < 0)
    RETURN 'QUERYFAILED';
  IF (one < 3)
    one := 3;                            -- below the clock, do not divide by noise
  IF (allrows > one * 20)
    RETURN sprintf ('PERROW: one=%d ms all-400=%d ms ratio=%d', one, allrows, allrows / one);
  RETURN 'ONCE';
}
;

SELECT GTEST_AF_RATIO (0);
ECHO BOTH ": AF2 unweighted betweenness runs once for the query = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] ONCE "PASSED" "***FAILED";

-- AF.3: and so must the weighted form.
SELECT GTEST_AF_RATIO (1);
ECHO BOTH ": AF3 weighted betweenness runs once for the query = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] ONCE "PASSED" "***FAILED";

-- AF.4: the scores are unchanged by being cached.  A cache keyed on too
-- little would serve one parameter set's vector to another.
CREATE PROCEDURE GTEST_AF_SAME ()
{
  DECLARE a, b, c DOUBLE PRECISION;
  a := GRAPH_BETWEENNESS_WEIGHTED ('urn:af:p:n7', 'urn:af:p:w', 'urn:af:p:e', NULL, 0, 0);
  b := GRAPH_BETWEENNESS_WEIGHTED ('urn:af:p:n7', 'urn:af:p:w', 'urn:af:p:e', NULL, 1, 0);
  c := GRAPH_BETWEENNESS_WEIGHTED ('urn:af:p:n7', 'urn:af:p:w', 'urn:af:p:e', NULL, 0, 0);
  IF (a IS NULL OR b IS NULL)
    RETURN 'NULL';
  IF (a <> c)
    RETURN sprintf ('unstable: %f then %f', a, c);
  IF (a = b)
    RETURN sprintf ('normalized ignored: %f', a);
  RETURN 'DISTINCT';
}
;

SELECT GTEST_AF_SAME ();
ECHO BOTH ": AF4 caching keeps the parameters apart = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] DISTINCT "PASSED" "***FAILED";

SELECT GRAPH_UNLOAD_EDGES ('urn:af:p:w');
SELECT GRAPH_UNLOAD_EDGES ('urn:af:p:u');
DROP TABLE GTEST_AF_NODES;

-- ============================================================================
-- Group AG: DIRECTION on the unweighted traversals
--
-- The weighted forms of shortest_path and shortest_path_length take a
-- direction; the unweighted ones did not, so an undirected hop count
-- could not be asked for and SPARQL refused the keyword rather than
-- accept-and-ignore it.  bfs always had one.
--
-- Fixture: c->a and c->b, and nothing out of a.  As recorded there is no
-- route from a to b at all; walking edges either way it is two hops.
-- ============================================================================

SPARQL CLEAR GRAPH <urn:ag2:src>;
SPARQL INSERT DATA INTO GRAPH <urn:ag2:src> {
  <urn:ag2:c> <urn:ag2:e> <urn:ag2:a> .
  <urn:ag2:c> <urn:ag2:e> <urn:ag2:b>
};

CREATE PROCEDURE GTEST_AG_HOPS (IN opts VARCHAR)
{
  DECLARE st, msg, q VARCHAR;
  DECLARE mdta, rset ANY;
  st := '00000';
  msg := '';
  q := sprintf ('SPARQL SELECT DISTINCT ?len FROM <urn:ag2:src>
         WHERE { ?s <urn:ag2:e> ?o .
                 <urn:ag2:b> bif:shortest_path_length ?len OPTION (%s) }', opts);
  EXEC (q, st, msg, VECTOR (), 0, mdta, rset);
  IF (st <> '00000')
    RETURN 'STATE:' || st || ' ' || msg;
  IF (NOT isarray (rset) OR length (rset) = 0)
    RETURN 'NOROWS';
  RETURN cast (rset[0][0] AS VARCHAR);
}
;

CREATE PROCEDURE GTEST_AG_CHK ()
{
  DECLARE asrec, both VARCHAR;
  asrec := GTEST_AG_HOPS ('edges (?s, ?o), source_node <urn:ag2:a>');
  both  := GTEST_AG_HOPS ('edges (?s, ?o), source_node <urn:ag2:a>, direction 2');
  IF (both LIKE 'STATE:%')
    RETURN 'REFUSED:' || "LEFT" (both, 70);
  IF (asrec = both)
    RETURN 'IGNORED:' || asrec;
  RETURN sprintf ('%s/%s', asrec, both);
}
;

SELECT GTEST_AG_CHK ();
ECHO BOTH ": AG1 unweighted shortest_path_length takes a direction = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] -1/2 "PASSED" "***FAILED";

-- AG.2: and so does the path form, whose direction sits after
-- return_type rather than in the same position.
CREATE PROCEDURE GTEST_AG_PATH (IN opts VARCHAR)
{
  DECLARE st, msg, q VARCHAR;
  DECLARE mdta, rset ANY;
  st := '00000';
  msg := '';
  q := sprintf ('SPARQL SELECT DISTINCT ?p FROM <urn:ag2:src>
         WHERE { ?s <urn:ag2:e> ?o .
                 <urn:ag2:b> bif:shortest_path ?p OPTION (%s) }', opts);
  EXEC (q, st, msg, VECTOR (), 0, mdta, rset);
  IF (st <> '00000')
    RETURN 'STATE:' || st || ' ' || msg;
  IF (NOT isarray (rset) OR length (rset) = 0)
    RETURN 'NOROWS';
  IF (rset[0][0] IS NULL)
    RETURN 'NULL';
  RETURN sprintf ('len%d', length (rset[0][0]));
}
;

CREATE PROCEDURE GTEST_AG_PATHCHK ()
{
  DECLARE asrec, both VARCHAR;
  asrec := GTEST_AG_PATH ('edges (?s, ?o), source_node <urn:ag2:a>');
  both  := GTEST_AG_PATH ('edges (?s, ?o), source_node <urn:ag2:a>, direction 2');
  IF (both LIKE 'STATE:%')
    RETURN 'REFUSED:' || "LEFT" (both, 70);
  IF (asrec = both)
    RETURN 'IGNORED:' || asrec;
  RETURN sprintf ('%s/%s', asrec, both);
}
;

SELECT GTEST_AG_PATHCHK ();
ECHO BOTH ": AG2 unweighted shortest_path takes a direction = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] NULL/len3 "PASSED" "***FAILED";

-- AG.3: the cache keeps the two readings apart.  They share the BFS
-- result slot, so a direction that was not part of the key would let the
-- first answer stand in for the second.
CREATE PROCEDURE GTEST_AG_CACHE ()
{
  DECLARE a1, b1, a2 VARCHAR;
  a1 := GTEST_AG_HOPS ('edges (?s, ?o), source_node <urn:ag2:a>');
  b1 := GTEST_AG_HOPS ('edges (?s, ?o), source_node <urn:ag2:a>, direction 2');
  a2 := GTEST_AG_HOPS ('edges (?s, ?o), source_node <urn:ag2:a>');
  IF (a1 <> a2)
    RETURN sprintf ('unstable: %s then %s', a1, a2);
  IF (a1 = b1)
    RETURN 'SHARED';
  RETURN 'SEPARATE';
}
;

SELECT GTEST_AG_CACHE ();
ECHO BOTH ": AG3 the two readings do not share a cache slot = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] SEPARATE "PASSED" "***FAILED";

-- ============================================================================
-- Group AH: an undirected weighted run must know what an edge weighs in
-- both directions
--
-- A weight lookup is a table keyed on (subject, object) as the edge was
-- stored.  When a traversal is undirected it walks each edge both ways,
-- so it asks for the weight of (object, subject) too -- and unless the
-- lookup is told it may answer symmetrically, that probe misses and the
-- edge silently takes the default weight of 1.
--
-- Only the shortest-path BIFs ever set that flag.  Betweenness, PageRank
-- and the rest did not, so every `directed 0` weighted run was computed
-- with the reverse of each edge weighing 1 whatever it really weighed.
--
-- Unit weights hide it completely -- the default is the right answer --
-- which is why the identity in AE8 passes either way and why this needs
-- tests of its own.
-- ============================================================================

-- The smallest graph that shows it, reduced from a random search:
--   0-4 weighs 1, 0-1 weighs 1, 1-4 weighs 2
-- The pair (1,4) has two shortest paths of length 2 -- the direct edge,
-- and 1-0-4 -- so node 0 lies on one of two and scores exactly 0.5.
-- NetworkX agrees; Virtuoso returned 0.25, because traversing 1-4 from 4
-- found no weight for (4,1) and used 1 instead of 2.
CREATE PROCEDURE GTEST_AH_TRI ()
{
  DECLARE e ANY;
  DECLARE v DOUBLE PRECISION;
  e := vector (vector (iri_to_id ('urn:ah:x'), iri_to_id ('urn:ah:z'), 1.0),
               vector (iri_to_id ('urn:ah:y'), iri_to_id ('urn:ah:z'), 2.0),
               vector (iri_to_id ('urn:ah:x'), iri_to_id ('urn:ah:y'), 1.0));
  GRAPH_LOAD_EDGES_W ('urn:ah:g', 'urn:ah:e', e);
  v := GRAPH_BETWEENNESS_WEIGHTED ('urn:ah:x', 'urn:ah:g', 'urn:ah:e', NULL, 0, 0);
  GRAPH_UNLOAD_EDGES ('urn:ah:g');
  IF (v IS NULL)
    RETURN 'NULL';
  RETURN sprintf ('%.6f', v);
}
;

SELECT GTEST_AH_TRI ();
ECHO BOTH ": AH1 undirected weighted betweenness on a known triangle = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.500000 "PASSED" "***FAILED";

-- AH.2: and the general invariant behind it.  Which end of an edge was
-- recorded first is not a property of the graph, so an undirected run
-- must return the same answer when every edge is stored the other way
-- round.  A lookup that only answers in the stored direction fails this
-- however the rest of the algorithm behaves -- which is what caught
-- weighted PageRank, whose error happened to be symmetric on AH1.
CREATE PROCEDURE GTEST_AH_REVERSE (IN algo VARCHAR)
{
  DECLARE fwd, rev ANY;
  DECLARE a, b DOUBLE PRECISION;
  fwd := vector (vector (iri_to_id ('urn:ah:x'), iri_to_id ('urn:ah:z'), 1.0),
                 vector (iri_to_id ('urn:ah:y'), iri_to_id ('urn:ah:z'), 2.0),
                 vector (iri_to_id ('urn:ah:x'), iri_to_id ('urn:ah:y'), 1.0));
  rev := vector (vector (iri_to_id ('urn:ah:z'), iri_to_id ('urn:ah:x'), 1.0),
                 vector (iri_to_id ('urn:ah:z'), iri_to_id ('urn:ah:y'), 2.0),
                 vector (iri_to_id ('urn:ah:y'), iri_to_id ('urn:ah:x'), 1.0));
  GRAPH_LOAD_EDGES_W ('urn:ah:f', 'urn:ah:e', fwd);
  GRAPH_LOAD_EDGES_W ('urn:ah:r', 'urn:ah:e', rev);
  IF (algo = 'pagerank')
    {
      a := GRAPH_PAGERANK_WEIGHTED ('urn:ah:x', 'urn:ah:f', 'urn:ah:e', NULL, 0.85, 100, 0.000001, 0);
      b := GRAPH_PAGERANK_WEIGHTED ('urn:ah:x', 'urn:ah:r', 'urn:ah:e', NULL, 0.85, 100, 0.000001, 0);
    }
  ELSE
    {
      a := GRAPH_BETWEENNESS_WEIGHTED ('urn:ah:x', 'urn:ah:f', 'urn:ah:e', NULL, 0, 0);
      b := GRAPH_BETWEENNESS_WEIGHTED ('urn:ah:x', 'urn:ah:r', 'urn:ah:e', NULL, 0, 0);
    }
  GRAPH_UNLOAD_EDGES ('urn:ah:f');
  GRAPH_UNLOAD_EDGES ('urn:ah:r');
  IF (a IS NULL OR b IS NULL)
    RETURN 'NULL';
  IF (ABS (a - b) > 0.000000001)
    RETURN sprintf ('as-stored %.6f, reversed %.6f', a, b);
  RETURN 'INVARIANT';
}
;

SELECT GTEST_AH_REVERSE ('pagerank');
ECHO BOTH ": AH2 weighted pagerank ignores how an edge was stored = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] INVARIANT "PASSED" "***FAILED";

SELECT GTEST_AH_REVERSE ('betweenness');
ECHO BOTH ": AH3 weighted betweenness ignores how an edge was stored = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] INVARIANT "PASSED" "***FAILED";

-- ============================================================================
-- Group AI: a tie in path length is still a tie when the two sums round
-- differently
--
-- Weighted betweenness counts shortest paths, so it must decide when two
-- routes are the same length.  Arriving at a node by two routes means
-- adding the same weights in a different order, and in binary floating
-- point those sums can land an ulp or two apart.  Four nodes show it:
--
--     A-B 0.5,  A-C 1.3,  A-D 1.8,  B-C 0.8
--
-- From D, C is 3.1 away either way, but 1.8+1.3 and (1.8+0.5)+0.8 differ
-- in the last two bits.  Read the smaller as strictly shorter and the path
-- count drops from 2 to 1, D's dependency on A rises from 2 to 3, and A
-- scores 2.5 instead of 2.  So the near-equal test has to be made before
-- the strictly-shorter test, not after it.
--
-- Scores are raw (normalized 0) and undirected, and are exact: A = 2, B = 1.
-- ============================================================================
CREATE PROCEDURE GTEST_AI_TIE (IN exact INTEGER, IN which VARCHAR)
{
  DECLARE e ANY;
  DECLARE g VARCHAR;
  DECLARE v DOUBLE PRECISION;
  -- the same graph twice: once in tenths, once in whole units.  Scaling
  -- every weight by 10 cannot change which routes are shortest, so the
  -- betweenness of a node cannot change either.
  IF (exact)
    {
      g := 'urn:ai:gx';
      e := vector (vector (iri_to_id ('urn:ai:a'), iri_to_id ('urn:ai:b'), 5.0),
                   vector (iri_to_id ('urn:ai:a'), iri_to_id ('urn:ai:c'), 13.0),
                   vector (iri_to_id ('urn:ai:a'), iri_to_id ('urn:ai:d'), 18.0),
                   vector (iri_to_id ('urn:ai:b'), iri_to_id ('urn:ai:c'), 8.0));
    }
  ELSE
    {
      g := 'urn:ai:gd';
      e := vector (vector (iri_to_id ('urn:ai:a'), iri_to_id ('urn:ai:b'), 0.5),
                   vector (iri_to_id ('urn:ai:a'), iri_to_id ('urn:ai:c'), 1.3),
                   vector (iri_to_id ('urn:ai:a'), iri_to_id ('urn:ai:d'), 1.8),
                   vector (iri_to_id ('urn:ai:b'), iri_to_id ('urn:ai:c'), 0.8));
    }
  GRAPH_LOAD_EDGES_W (g, 'urn:ai:e', e);
  v := GRAPH_BETWEENNESS_WEIGHTED (which, g, 'urn:ai:e', NULL, 0, 0);
  GRAPH_UNLOAD_EDGES (g);
  IF (v IS NULL)
    RETURN 'NULL';
  RETURN sprintf ('%.6f', v);
}
;

SELECT GTEST_AI_TIE (0, 'urn:ai:a');
ECHO BOTH ": AI1 A carries both tied routes from D = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2.000000 "PASSED" "***FAILED";

SELECT GTEST_AI_TIE (0, 'urn:ai:b');
ECHO BOTH ": AI2 B keeps only its half of the tie = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1.000000 "PASSED" "***FAILED";

-- AI.3: the general property behind AI1/AI2, which holds whatever the
-- scores happen to be: multiplying every weight by a constant leaves the
-- shortest paths, and so the betweenness, untouched.  Only the rounding
-- changes -- which is exactly what the near-equal test is there to absorb.
CREATE PROCEDURE GTEST_AI_SCALE (IN which VARCHAR)
{
  DECLARE a, b VARCHAR;
  a := GTEST_AI_TIE (0, which);
  b := GTEST_AI_TIE (1, which);
  IF (a = 'NULL' OR b = 'NULL')
    RETURN 'NULL';
  IF (a <> b)
    RETURN sprintf ('tenths %s, whole units %s', a, b);
  RETURN 'INVARIANT';
}
;

SELECT GTEST_AI_SCALE ('urn:ai:a');
ECHO BOTH ": AI3 weighted betweenness is unchanged by the scale of a weight = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] INVARIANT "PASSED" "***FAILED";

-- ============================================================================
-- Group AJ: eigenvector centrality has to reach an eigenvector
--
-- Eigenvector centrality is the principal eigenvector of the adjacency
-- matrix, found by power iteration.  Plain power iteration only converges
-- when one eigenvalue is strictly larger in modulus than the rest -- and a
-- directed cycle gives several of equal modulus (the roots of unity), so
-- the iterate rotates forever and whatever it holds when the iteration cap
-- is reached gets returned as the answer.
--
-- Four nodes are enough: a->b->c->a, plus d->a.
--
--     correct   a = b = c = 1/sqrt(3) = 0.577350,  d = 0
--     rotating  a = 0.816497, b = c = 0.408248,    d = 0
--
-- The cure is the standard one: iterate (I + A) rather than A.  Adding the
-- identity shifts every eigenvalue by 1, which separates the moduli without
-- moving a single eigenvector, so the answer is unchanged wherever the plain
-- iteration already converged.
-- ============================================================================
CREATE PROCEDURE GTEST_AJ_LOAD ()
{
  DECLARE e ANY;
  e := vector (vector (iri_to_id ('urn:aj:a'), iri_to_id ('urn:aj:b'), 1.0),
               vector (iri_to_id ('urn:aj:b'), iri_to_id ('urn:aj:c'), 1.0),
               vector (iri_to_id ('urn:aj:c'), iri_to_id ('urn:aj:a'), 1.0),
               vector (iri_to_id ('urn:aj:d'), iri_to_id ('urn:aj:a'), 1.0));
  GRAPH_LOAD_EDGES_W ('urn:aj:g', 'urn:aj:e', e);
}
;

CREATE PROCEDURE GTEST_AJ_ONE (IN nd VARCHAR, IN weighted INTEGER)
{
  DECLARE v DOUBLE PRECISION;
  GTEST_AJ_LOAD ();
  IF (weighted)
    v := GRAPH_EIGENVECTOR_WEIGHTED (nd, 'urn:aj:g', 'urn:aj:e', NULL, 1000, 0.000000000001);
  ELSE
    v := GRAPH_EIGENVECTOR_CENTRALITY (nd, 'urn:aj:g', NULL, 1000, 0.000000000001);
  GRAPH_UNLOAD_EDGES ('urn:aj:g');
  IF (v IS NULL)
    RETURN 'NULL';
  RETURN sprintf ('%.6f', v);
}
;

SELECT GTEST_AJ_ONE ('urn:aj:a', 0);
ECHO BOTH ": AJ1 eigenvector settles on the cycle, not mid-rotation = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.577350 "PASSED" "***FAILED";

SELECT GTEST_AJ_ONE ('urn:aj:b', 0);
ECHO BOTH ": AJ2 every node of the cycle carries the same weight = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.577350 "PASSED" "***FAILED";

-- AJ.3: the unit-weight identity.  Weights of 1 are no weights at all, so
-- the weighted form must answer exactly as the unweighted one -- the two
-- share nothing but the definition, and each has its own iteration.
CREATE PROCEDURE GTEST_AJ_UNIT ()
{
  DECLARE a, b VARCHAR;
  a := GTEST_AJ_ONE ('urn:aj:a', 0);
  b := GTEST_AJ_ONE ('urn:aj:a', 1);
  IF (a = 'NULL' OR b = 'NULL')
    RETURN 'NULL';
  IF (a <> b)
    RETURN sprintf ('unweighted %s, weighted %s', a, b);
  RETURN 'IDENTICAL';
}
;

SELECT GTEST_AJ_UNIT ();
ECHO BOTH ": AJ3 weighted eigenvector at unit weights = unweighted = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] IDENTICAL "PASSED" "***FAILED";

-- AJ.4: the property behind AJ1/AJ2, which needs no expected value at all.
-- A vector is an eigenvector exactly when applying the adjacency matrix
-- scales it: the in-neighbour scores of every node must come to the same
-- multiple of that node's own score.  On this graph the three ratios are
--   a: (c + d) / a      b: a / b      c: b / c
-- and the rotating iterate makes them 0.5, 2.0 and 1.0.
CREATE PROCEDURE GTEST_AJ_EIGEN ()
{
  DECLARE a, b, c, d DOUBLE PRECISION;
  DECLARE l1, l2, l3 DOUBLE PRECISION;
  GTEST_AJ_LOAD ();
  a := GRAPH_EIGENVECTOR_CENTRALITY ('urn:aj:a', 'urn:aj:g', NULL, 1000, 0.000000000001);
  b := GRAPH_EIGENVECTOR_CENTRALITY ('urn:aj:b', 'urn:aj:g', NULL, 1000, 0.000000000001);
  c := GRAPH_EIGENVECTOR_CENTRALITY ('urn:aj:c', 'urn:aj:g', NULL, 1000, 0.000000000001);
  d := GRAPH_EIGENVECTOR_CENTRALITY ('urn:aj:d', 'urn:aj:g', NULL, 1000, 0.000000000001);
  GRAPH_UNLOAD_EDGES ('urn:aj:g');
  IF (a IS NULL OR b IS NULL OR c IS NULL OR d IS NULL)
    RETURN 'NULL';
  IF (a <= 0 OR b <= 0 OR c <= 0)
    RETURN sprintf ('a=%.6f b=%.6f c=%.6f', a, b, c);
  l1 := (c + d) / a; l2 := a / b; l3 := b / c;
  IF (ABS (l1 - l2) > 0.000001 OR ABS (l2 - l3) > 0.000001)
    RETURN sprintf ('ratios %.4f %.4f %.4f', l1, l2, l3);
  RETURN 'EIGENVECTOR';
}
;

SELECT GTEST_AJ_EIGEN ();
ECHO BOTH ": AJ4 the result satisfies the eigenvalue equation = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] EIGENVECTOR "PASSED" "***FAILED";

-- ============================================================================
-- Group AK: which way a measure looks, and what it is divided by
--
-- Fixture: a->b, b->c, c->d, a->c.  Four nodes, and every value below is
-- asymmetric enough that reading it the other way round cannot coincide.
--
--                       a       b       c       d
--   closeness out    0.75    0.6667   1.0     0
--   closeness in     0       1.0      1.0     0.6
--   harmonic  out    2.5     1.5      1.0     0
--   harmonic  in     0       1.0      2.0     2.0
--   degree(c)        out 1,  in 2,    both 3
--
-- Three things are being pinned:
--
--  1. closeness and harmonic could only ever be read outgoing.  They now
--     take a direction, and outgoing stays the default, so no existing
--     answer moves.  They use the traversal encoding -- 0 out, 1 in,
--     2 both -- which is what bfs, dfs and shortest_path already use.
--
--  2. That encoding is NOT the one degree_centrality uses, where 0 is
--     both and 2 is out.  Each default suits its own measure and neither
--     can be renumbered without silently changing what a shipped query
--     returns, so the direction may instead be named: 'out', 'in',
--     'both'.  A name means the same thing everywhere, which is the whole
--     point of AK5 -- the integer 2 means "out" to degree_centrality and
--     "both" to closeness, while 'out' means out to both.
--
--  3. degree_centrality and harmonic return raw values, and now take the
--     normalized flag that betweenness and closeness already had.  It
--     divides by n-1 and defaults to 0, so again nothing moves.
-- ============================================================================
CREATE PROCEDURE GTEST_AK_LOAD ()
{
  DECLARE e ANY;
  e := vector (vector (iri_to_id ('urn:ak:a'), iri_to_id ('urn:ak:b'), 1.0),
               vector (iri_to_id ('urn:ak:b'), iri_to_id ('urn:ak:c'), 1.0),
               vector (iri_to_id ('urn:ak:c'), iri_to_id ('urn:ak:d'), 1.0),
               vector (iri_to_id ('urn:ak:a'), iri_to_id ('urn:ak:c'), 1.0));
  GRAPH_LOAD_EDGES_W ('urn:ak:g', 'urn:ak:e', e);
}
;

-- AK.1/AK.2: closeness can be read either way, and the two readings of the
-- same graph are different numbers.
CREATE PROCEDURE GTEST_AK_CLOSE (IN nd VARCHAR, IN dir ANY)
{
  DECLARE v DOUBLE PRECISION;
  GTEST_AK_LOAD ();
  v := GRAPH_CLOSENESS (nd, 'urn:ak:g', NULL, 0, dir);
  GRAPH_UNLOAD_EDGES ('urn:ak:g');
  IF (v IS NULL) RETURN 'NULL';
  RETURN sprintf ('%.6f', v);
}
;

SELECT GTEST_AK_CLOSE ('urn:ak:a', 0);
ECHO BOTH ": AK1 closeness read outgoing = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.750000 "PASSED" "***FAILED";

SELECT GTEST_AK_CLOSE ('urn:ak:d', 1);
ECHO BOTH ": AK2 closeness read incoming = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.600000 "PASSED" "***FAILED";

-- AK.3: and the default did not move.  Asking for nothing must still be
-- asking for outgoing, or every closeness answer ever returned changed.
CREATE PROCEDURE GTEST_AK_DEFAULT ()
{
  DECLARE a, b DOUBLE PRECISION;
  GTEST_AK_LOAD ();
  a := GRAPH_CLOSENESS ('urn:ak:a', 'urn:ak:g', NULL, 0);
  b := GRAPH_CLOSENESS ('urn:ak:a', 'urn:ak:g', NULL, 0, 0);
  GRAPH_UNLOAD_EDGES ('urn:ak:g');
  IF (a IS NULL OR b IS NULL) RETURN 'NULL';
  IF (ABS (a - b) > 0.000000001)
    RETURN sprintf ('absent %.6f, outgoing %.6f', a, b);
  RETURN 'UNCHANGED';
}
;

SELECT GTEST_AK_DEFAULT ();
ECHO BOTH ": AK3 an absent direction still means outgoing = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] UNCHANGED "PASSED" "***FAILED";

-- AK.4: harmonic reads both ways too.  d is the sharpest node on this
-- graph: nothing leaves it, so outgoing is 0 and incoming is 2.
CREATE PROCEDURE GTEST_AK_HARM (IN nd VARCHAR, IN dir ANY, IN norm ANY)
{
  DECLARE v DOUBLE PRECISION;
  GTEST_AK_LOAD ();
  v := GRAPH_HARMONIC (nd, 'urn:ak:g', NULL, dir, norm);
  GRAPH_UNLOAD_EDGES ('urn:ak:g');
  IF (v IS NULL) RETURN 'NULL';
  RETURN sprintf ('%.6f', v);
}
;

SELECT GTEST_AK_HARM ('urn:ak:d', 1, 0);
ECHO BOTH ": AK4 harmonic read incoming = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2.000000 "PASSED" "***FAILED";

-- AK.5: the reason names exist.  degree_centrality counts 0 as both and 2
-- as out; every traversal counts 0 as out and 2 as both.  Neither can
-- change.  So each integer is checked against the name that means the same
-- thing to that particular predicate, and the names are checked against
-- each other -- 'out' has to mean out in both places, which is exactly what
-- the integer 2 does not.
CREATE PROCEDURE GTEST_AK_NAMES ()
{
  DECLARE dn_out, dn_in, dn_both, di_out, di_in, di_both DOUBLE PRECISION;
  DECLARE cn_out, cn_both, ci_out, ci_both DOUBLE PRECISION;
  GTEST_AK_LOAD ();
  -- degree_centrality: named, then the integer that means the same
  dn_out  := GRAPH_DEGREE_CENTRALITY ('urn:ak:c', 'urn:ak:g', NULL, 'out');
  dn_in   := GRAPH_DEGREE_CENTRALITY ('urn:ak:c', 'urn:ak:g', NULL, 'in');
  dn_both := GRAPH_DEGREE_CENTRALITY ('urn:ak:c', 'urn:ak:g', NULL, 'both');
  di_out  := GRAPH_DEGREE_CENTRALITY ('urn:ak:c', 'urn:ak:g', NULL, 2);
  di_in   := GRAPH_DEGREE_CENTRALITY ('urn:ak:c', 'urn:ak:g', NULL, 1);
  di_both := GRAPH_DEGREE_CENTRALITY ('urn:ak:c', 'urn:ak:g', NULL, 0);
  -- closeness: the same names, the other integers
  cn_out  := GRAPH_CLOSENESS ('urn:ak:a', 'urn:ak:g', NULL, 0, 'out');
  cn_both := GRAPH_CLOSENESS ('urn:ak:a', 'urn:ak:g', NULL, 0, 'both');
  ci_out  := GRAPH_CLOSENESS ('urn:ak:a', 'urn:ak:g', NULL, 0, 0);
  ci_both := GRAPH_CLOSENESS ('urn:ak:a', 'urn:ak:g', NULL, 0, 2);
  GRAPH_UNLOAD_EDGES ('urn:ak:g');
  IF (dn_out IS NULL OR dn_in IS NULL OR dn_both IS NULL OR
      cn_out IS NULL OR cn_both IS NULL)
    RETURN 'NULL';
  IF (dn_out <> 1 OR dn_in <> 2 OR dn_both <> 3)
    RETURN sprintf ('degree by name: out %.0f in %.0f both %.0f', dn_out, dn_in, dn_both);
  IF (dn_out <> di_out OR dn_in <> di_in OR dn_both <> di_both)
    RETURN 'degree names and integers disagree';
  IF (ABS (cn_out - ci_out) > 0.000000001 OR ABS (cn_both - ci_both) > 0.000000001)
    RETURN 'closeness names and integers disagree';
  -- and the point: the integer 2 is not portable, the name is
  IF (ABS (di_out - dn_out) > 0.000000001 AND ABS (ci_out - cn_out) > 0.000000001)
    RETURN 'unexpected';
  RETURN 'PORTABLE';
}
;

SELECT GTEST_AK_NAMES ();
ECHO BOTH ": AK5 'out' means out to both encodings = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] PORTABLE "PASSED" "***FAILED";

-- AK.6/AK.7: the normalized flag that betweenness and closeness already
-- had, on the two measures that lacked it.  Dividing by n-1 = 3.
CREATE PROCEDURE GTEST_AK_DEGN (IN norm ANY)
{
  DECLARE v DOUBLE PRECISION;
  GTEST_AK_LOAD ();
  v := GRAPH_DEGREE_CENTRALITY ('urn:ak:c', 'urn:ak:g', NULL, 'both', norm);
  GRAPH_UNLOAD_EDGES ('urn:ak:g');
  IF (v IS NULL) RETURN 'NULL';
  RETURN sprintf ('%.6f', v);
}
;

SELECT GTEST_AK_DEGN (1);
ECHO BOTH ": AK6 degree_centrality normalized by n-1 = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1.000000 "PASSED" "***FAILED";

SELECT GTEST_AK_HARM ('urn:ak:a', 0, 1);
ECHO BOTH ": AK7 harmonic normalized by n-1 = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.833333 "PASSED" "***FAILED";

-- AK.8: neither flag moved the raw answer.  Both default to 0, and 0 has
-- to be what absence already meant.
CREATE PROCEDURE GTEST_AK_RAW ()
{
  DECLARE d0, d1, h0, h1 DOUBLE PRECISION;
  GTEST_AK_LOAD ();
  d0 := GRAPH_DEGREE_CENTRALITY ('urn:ak:c', 'urn:ak:g', NULL, 'both');
  d1 := GRAPH_DEGREE_CENTRALITY ('urn:ak:c', 'urn:ak:g', NULL, 'both', 0);
  h0 := GRAPH_HARMONIC ('urn:ak:a', 'urn:ak:g', NULL, 0);
  h1 := GRAPH_HARMONIC ('urn:ak:a', 'urn:ak:g', NULL, 0, 0);
  GRAPH_UNLOAD_EDGES ('urn:ak:g');
  IF (d0 IS NULL OR d1 IS NULL OR h0 IS NULL OR h1 IS NULL) RETURN 'NULL';
  IF (d0 <> 3 OR d1 <> 3) RETURN sprintf ('degree %.4f / %.4f', d0, d1);
  IF (ABS (h0 - 2.5) > 0.000001 OR ABS (h1 - 2.5) > 0.000001)
    RETURN sprintf ('harmonic %.4f / %.4f', h0, h1);
  RETURN 'RAW';
}
;

SELECT GTEST_AK_RAW ();
ECHO BOTH ": AK8 absent normalized still means raw = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] RAW "PASSED" "***FAILED";

-- AK.9: the weighted closeness path is a separate implementation and needs
-- the direction just as much.  At unit weights it must answer exactly as
-- the unweighted form, whichever way it is read.
CREATE PROCEDURE GTEST_AK_WCLOSE ()
{
  DECLARE i INT; DECLARE u, w DOUBLE PRECISION; DECLARE nd VARCHAR;
  DECLARE nodes, dirs ANY;
  nodes := vector ('urn:ak:a', 'urn:ak:b', 'urn:ak:c', 'urn:ak:d');
  dirs  := vector (0, 1, 2);
  GTEST_AK_LOAD ();
  FOR (i := 0; i < 12; i := i + 1)
    {
      nd := nodes[mod (i, 4)];
      u := GRAPH_CLOSENESS (nd, 'urn:ak:g', NULL, 0, dirs[i / 4]);
      w := GRAPH_CLOSENESS_WEIGHTED (nd, 'urn:ak:g', 'urn:ak:e', NULL, 0, dirs[i / 4]);
      IF (u IS NULL OR w IS NULL)
        { GRAPH_UNLOAD_EDGES ('urn:ak:g'); RETURN 'NULL'; }
      IF (ABS (u - w) > 0.000000001)
        {
          GRAPH_UNLOAD_EDGES ('urn:ak:g');
          RETURN sprintf ('%s dir %d: unweighted %.6f, weighted %.6f',
                          nd, dirs[i / 4], u, w);
        }
    }
  GRAPH_UNLOAD_EDGES ('urn:ak:g');
  RETURN 'IDENTICAL';
}
;

SELECT GTEST_AK_WCLOSE ();
ECHO BOTH ": AK9 weighted closeness reads the same way at unit weights = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] IDENTICAL "PASSED" "***FAILED";

-- AK.10/AK.11: and the same two options over SPARQL, which is how anyone
-- outside SQL reaches them.  d is the node that settles it: nothing leaves
-- it, so read outgoing it is 0 either way.
SPARQL INSERT INTO GRAPH <urn:ak:q> {
  <urn:ak:qa> <urn:ak:qe> <urn:ak:qb> . <urn:ak:qb> <urn:ak:qe> <urn:ak:qc> .
  <urn:ak:qc> <urn:ak:qe> <urn:ak:qd> . <urn:ak:qa> <urn:ak:qe> <urn:ak:qc> . };

SPARQL SELECT (STR(?c) AS ?v) FROM <urn:ak:q> WHERE {
  ?s <urn:ak:qe> ?n . ?n bif:closeness ?c OPTION (direction 1) .
  FILTER (?n = <urn:ak:qd>) } LIMIT 1;
ECHO BOTH ": AK10 SPARQL closeness OPTION (direction 1) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.6 "PASSED" "***FAILED";

SPARQL SELECT (STR(?h) AS ?v) FROM <urn:ak:q> WHERE {
  ?s <urn:ak:qe> ?n . ?n bif:harmonic ?h OPTION (direction 1) .
  FILTER (?n = <urn:ak:qd>) } LIMIT 1;
ECHO BOTH ": AK11 SPARQL harmonic OPTION (direction 1) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

-- AK.12/AK.13: the names over SPARQL.  c has out-degree 1 and total
-- degree 3, so "out" and the integer 2 agreeing on 1 is the whole claim:
-- to a traversal that same 2 would have meant "both".
SPARQL SELECT (STR(?d) AS ?v) FROM <urn:ak:q> WHERE {
  ?s <urn:ak:qe> ?n . ?n bif:degree_centrality ?d OPTION (direction "out") .
  FILTER (?n = <urn:ak:qc>) } LIMIT 1;
ECHO BOTH ": AK12 SPARQL OPTION (direction \"out\") on degree = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- A name that is not one of the three is a compiler error, like every
-- other bad option value, rather than a run-time surprise.
SPARQL SELECT (STR(?c) AS ?v) FROM <urn:ak:q> WHERE {
  ?s <urn:ak:qe> ?n . ?n bif:closeness ?c OPTION (direction "sideways") } LIMIT 1;
ECHO BOTH ": AK13 an unknown direction name is refused state = " $STATE "\n";
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";

-- AK.14: normalized over SPARQL.  c has total degree 3 on four nodes, so
-- 3/(4-1) = 1 -- a value the raw count cannot reach on this graph.
SPARQL SELECT (STR(?d) AS ?v) FROM <urn:ak:q> WHERE {
  ?s <urn:ak:qe> ?n . ?n bif:degree_centrality ?d OPTION (direction "both", normalized 1) .
  FILTER (?n = <urn:ak:qc>) } LIMIT 1;
ECHO BOTH ": AK14 SPARQL degree_centrality OPTION (normalized 1) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- AK.15: harmonic's normalized flag over SPARQL.  a's raw harmonic on the
-- four-node fixture is 2.5, so over n-1 = 3 it is 0.8333333333333334.
SPARQL SELECT (STR(?h) AS ?v) FROM <urn:ak:q> WHERE {
  ?n <urn:ak:qe> ?o . ?n bif:harmonic ?h OPTION (normalized 1) .
  FILTER (?n = <urn:ak:qa>) } LIMIT 1;
ECHO BOTH ": AK15 SPARQL harmonic OPTION (normalized 1) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.8333333333333334 "PASSED" "***FAILED";

-- ============================================================================
-- Group AL: depth-first search, reachable from SPARQL
--
-- GRAPH_DFS existed as a SQL function with no bif: name, so
-- `?n bif:dfs ?v` matched nothing at all -- silently, because an
-- unregistered predicate is not an error, it is a pattern that binds
-- no rows.  That is the worst way for a gap to present.
--
-- What DFS returns is reachability: 1 if the target can be reached from
-- the source, 0 if not, and with no target the count of nodes reached.
-- None of that depends on the order the traversal visits in, so it is
-- the same question breadth-first search answers -- which is the point
-- of AL3.  The two now share one cached traversal rather than running
-- two, and DFS gained the direction every other traversal takes.
--
-- Fixture: a -> b -> c -> d, and e -> a.  From a, everything but e is
-- reachable forwards; e is reachable only against the arrows.
-- ============================================================================
CREATE PROCEDURE GTEST_AL_LOAD ()
{
  DECLARE e ANY;
  e := vector (vector (iri_to_id ('urn:al:a'), iri_to_id ('urn:al:b'), 1.0),
               vector (iri_to_id ('urn:al:b'), iri_to_id ('urn:al:c'), 1.0),
               vector (iri_to_id ('urn:al:c'), iri_to_id ('urn:al:d'), 1.0),
               vector (iri_to_id ('urn:al:e'), iri_to_id ('urn:al:a'), 1.0));
  GRAPH_LOAD_EDGES_W ('urn:al:g', 'urn:al:w', e);
}
;

CREATE PROCEDURE GTEST_AL_DFS (IN nd VARCHAR, IN dir ANY)
{
  DECLARE v ANY;
  GTEST_AL_LOAD ();
  v := GRAPH_DFS ('urn:al:a', nd, 'urn:al:g', NULL, dir);
  GRAPH_UNLOAD_EDGES ('urn:al:g');
  IF (v IS NULL) RETURN 'NULL';
  RETURN sprintf ('%d', v);
}
;

SELECT GTEST_AL_DFS ('urn:al:d', 0);
ECHO BOTH ": AL1 dfs reaches the far end of the chain = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

SELECT GTEST_AL_DFS ('urn:al:e', 0);
ECHO BOTH ": AL2 dfs does not reach against the arrows = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

SELECT GTEST_AL_DFS ('urn:al:e', 'both');
ECHO BOTH ": AL3 dfs takes a direction like every other traversal = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- AL.4: the invariant that makes one cached traversal correct for both.
-- Reachability does not depend on visit order, so dfs must be 1 exactly
-- where bfs is not -1, for every node and every direction.
CREATE PROCEDURE GTEST_AL_AGREE ()
{
  DECLARE i, j INT; DECLARE nodes, dirs ANY;
  DECLARE d, b ANY;
  nodes := vector ('urn:al:a', 'urn:al:b', 'urn:al:c', 'urn:al:d', 'urn:al:e');
  dirs := vector (0, 1, 2);
  GTEST_AL_LOAD ();
  FOR (j := 0; j < 3; j := j + 1)
    FOR (i := 0; i < 5; i := i + 1)
      {
        DECLARE dreach, breach INT;
        d := GRAPH_DFS ('urn:al:a', nodes[i], 'urn:al:g', NULL, dirs[j]);
        b := GRAPH_BFS ('urn:al:a', nodes[i], 'urn:al:g', NULL, dirs[j]);
        IF (d IS NULL OR b IS NULL)
          { GRAPH_UNLOAD_EDGES ('urn:al:g'); RETURN 'NULL'; }
        dreach := CASE WHEN d = 1 THEN 1 ELSE 0 END;
        breach := CASE WHEN b >= 0 THEN 1 ELSE 0 END;
        IF (dreach <> breach)
          {
            GRAPH_UNLOAD_EDGES ('urn:al:g');
            RETURN sprintf ('%s dir %d: dfs=%d bfs=%d', nodes[i], dirs[j], d, b);
          }
      }
  GRAPH_UNLOAD_EDGES ('urn:al:g');
  RETURN 'AGREE';
}
;

SELECT GTEST_AL_AGREE ();
ECHO BOTH ": AL4 dfs is reachable exactly where bfs is = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] AGREE "PASSED" "***FAILED";

-- AL.5: and the SPARQL predicate exists at all.  Before this it bound no
-- rows, so the count was 0 -- which no value assertion would have caught,
-- because there was no value.
SPARQL INSERT INTO GRAPH <urn:al:q> {
  <urn:al:qa> <urn:al:qe> <urn:al:qb> . <urn:al:qb> <urn:al:qe> <urn:al:qc> .
  <urn:al:qc> <urn:al:qe> <urn:al:qd> . <urn:al:qe2> <urn:al:qe> <urn:al:qa> . };

SPARQL SELECT (COUNT(DISTINCT ?n) AS ?c) FROM <urn:al:q> WHERE {
  { ?n <urn:al:qe> ?o } UNION { ?x <urn:al:qe> ?n }
  ?n bif:dfs ?r OPTION (source_node <urn:al:qa>) };
ECHO BOTH ": AL5 bif:dfs binds rows in SPARQL = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";

SPARQL SELECT (STR(?r) AS ?v) FROM <urn:al:q> WHERE {
  { ?n <urn:al:qe> ?o } UNION { ?x <urn:al:qe> ?n }
  ?n bif:dfs ?r OPTION (source_node <urn:al:qa>, direction "both") .
  FILTER (?n = <urn:al:qe2>) } LIMIT 1;
ECHO BOTH ": AL6 SPARQL bif:dfs honours direction = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- ============================================================================
-- Group AM: a traversal may start from a variable
--
-- OPTION (source_node ...) took an IRI and nothing else, so the predicate
-- form of bfs, dfs, shortest_path, shortest_path_length and
-- jaccard_similarity could only ever measure every node against ONE fixed
-- node.  All-pairs was reachable only through the expression form.
--
-- Nothing under the grammar required that.  vgraph_vec_whole_graph
-- already handles args[0] arriving as a vector: it serves the batch from
-- one distance vector when every row shares a source and falls back to
-- the row loop when they do not, and that loop reads the same
-- source-keyed cache, so N distinct sources cost N traversals rather than
-- one per row.  The expression form bif:bfs(?a, ?b, <g>) has always
-- accepted two variables.  Only the option production was narrower.
--
-- Fixture: qa -> qb -> qc -> qd, and qe2 -> qa (loaded by Group AL).
-- ============================================================================
-- The chain qa->qb->qc->qd with qe2->qa has exactly 15 ordered pairs
-- that are reachable: 4 from qa, 3 from qb, 2 from qc, 1 from qd and 5
-- from qe2 (which reaches everything).  A count, not "more than zero" --
-- an errored query returns no rows, and "no rows" must not read as pass.
SPARQL SELECT (COUNT(DISTINCT CONCAT(STR(?a), "|", STR(?b))) AS ?reachable_pairs)
FROM <urn:al:q> WHERE {
  { ?a <urn:al:qe> ?o1 } UNION { ?w <urn:al:qe> ?a }
  { ?b <urn:al:qe> ?o2 } UNION { ?y <urn:al:qe> ?b }
  ?b bif:bfs ?d OPTION (source_node ?a) .
  FILTER (?d >= 0) };
ECHO BOTH ": AM1 bfs accepts a variable source = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 15 "PASSED" "***FAILED";

-- AM.2: and it agrees with the expression form, which has always taken
-- two variables.  Stated as an invariant so it cannot drift.
SPARQL SELECT (COUNT(*) AS ?disagreements) FROM <urn:al:q> WHERE {
  { ?a <urn:al:qe> ?o1 } UNION { ?w <urn:al:qe> ?a }
  { ?b <urn:al:qe> ?o2 } UNION { ?y <urn:al:qe> ?b }
  ?b bif:bfs ?d OPTION (source_node ?a) .
  FILTER (?d != bif:bfs (?a, ?b, <urn:al:q>)) };
ECHO BOTH ": AM2 variable source agrees with the expression form = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- AM.3: the fixed-IRI form did not move.  qe2 reaches qd in four hops and
-- nothing reaches qe2, so this is the sharpest node on the fixture.
SPARQL SELECT (STR(?d) AS ?v) FROM <urn:al:q> WHERE {
  { ?b <urn:al:qe> ?o } UNION { ?y <urn:al:qe> ?b }
  ?b bif:bfs ?d OPTION (source_node <urn:al:qe2>) .
  FILTER (?b = <urn:al:qd>) } LIMIT 1;
ECHO BOTH ": AM3 a fixed IRI source still works = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";

-- AM.4: jaccard_similarity is the reason this matters -- all-pairs in
-- predicate position, which previously needed the expression form.
SPARQL SELECT (COUNT(*) AS ?disagreements) FROM <urn:al:q> WHERE {
  { ?a <urn:al:qe> ?o1 } UNION { ?w <urn:al:qe> ?a }
  { ?b <urn:al:qe> ?o2 } UNION { ?y <urn:al:qe> ?b }
  ?b bif:jaccard_similarity ?sim OPTION (source_node ?a) .
  FILTER (?sim != bif:jaccard_similarity (?a, ?b, <urn:al:q>)) };
ECHO BOTH ": AM4 jaccard all-pairs from a variable source = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- AM.5: and shortest_path_length, the other source-keyed traversal.
SPARQL SELECT (COUNT(*) AS ?disagreements) FROM <urn:al:q> WHERE {
  { ?a <urn:al:qe> ?o1 } UNION { ?w <urn:al:qe> ?a }
  { ?b <urn:al:qe> ?o2 } UNION { ?y <urn:al:qe> ?b }
  ?b bif:shortest_path_length ?len OPTION (source_node ?a) .
  FILTER (?len != bif:shortest_path_length (?a, ?b, <urn:al:q>)) };
ECHO BOTH ": AM5 shortest_path_length from a variable source = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- AM.6: an unbound variable is refused when the query is compiled, the
-- same way OPTION (edges ...) refuses an unbound endpoint.  A traversal
-- with no start is not a query anyone meant to write.
SPARQL SELECT ?b ?d FROM <urn:al:q> WHERE {
  { ?b <urn:al:qe> ?o } UNION { ?y <urn:al:qe> ?b }
  ?b bif:bfs ?d OPTION (source_node ?nowhere) } LIMIT 1;
ECHO BOTH ": AM6 an unbound variable source is refused state = " $STATE "\n";
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";

-- ============================================================================
-- Group AN: a node column with no values must not be dereferenced
--
-- vgraph_iri_to_id_batch() null-checks its arguments and then reads
-- node_col->dc_values without checking it.  A variable that is bound in
-- only one branch of a UNION -- which is what BIND under UNION produces,
-- and what a federated SERVICE result routinely produces -- arrives as a
-- data column carrying no values, and the read is of address zero.
--
-- It needs more than [Graph] MinBatch (64) rows to reach, because below that
-- the vectored path declines and the scalar one answers cleanly.  So the
-- fixture is 120 edges: the same query over ten rows returns a tidy
-- "node argument is NULL" and over a hundred killed the server with
-- SIGSEGV.
--
-- Reachable from any SPARQL query against a graph of any size, which is
-- what makes it worth a fixture of its own rather than a note.
-- ============================================================================
SPARQL INSERT INTO GRAPH <urn:an:g> {
  <urn:an:0> <urn:an:e> <urn:an:1> .
  <urn:an:1> <urn:an:e> <urn:an:8> .
  <urn:an:2> <urn:an:e> <urn:an:15> .
  <urn:an:3> <urn:an:e> <urn:an:22> .
  <urn:an:4> <urn:an:e> <urn:an:29> .
  <urn:an:5> <urn:an:e> <urn:an:36> .
  <urn:an:6> <urn:an:e> <urn:an:43> .
  <urn:an:7> <urn:an:e> <urn:an:50> .
  <urn:an:8> <urn:an:e> <urn:an:57> .
  <urn:an:9> <urn:an:e> <urn:an:64> .
  <urn:an:10> <urn:an:e> <urn:an:71> .
  <urn:an:11> <urn:an:e> <urn:an:78> .
  <urn:an:12> <urn:an:e> <urn:an:85> .
  <urn:an:13> <urn:an:e> <urn:an:92> .
  <urn:an:14> <urn:an:e> <urn:an:99> .
  <urn:an:15> <urn:an:e> <urn:an:106> .
  <urn:an:16> <urn:an:e> <urn:an:113> .
  <urn:an:17> <urn:an:e> <urn:an:0> .
  <urn:an:18> <urn:an:e> <urn:an:7> .
  <urn:an:19> <urn:an:e> <urn:an:14> .
  <urn:an:20> <urn:an:e> <urn:an:21> .
  <urn:an:21> <urn:an:e> <urn:an:28> .
  <urn:an:22> <urn:an:e> <urn:an:35> .
  <urn:an:23> <urn:an:e> <urn:an:42> .
  <urn:an:24> <urn:an:e> <urn:an:49> .
  <urn:an:25> <urn:an:e> <urn:an:56> .
  <urn:an:26> <urn:an:e> <urn:an:63> .
  <urn:an:27> <urn:an:e> <urn:an:70> .
  <urn:an:28> <urn:an:e> <urn:an:77> .
  <urn:an:29> <urn:an:e> <urn:an:84> .
  <urn:an:30> <urn:an:e> <urn:an:91> .
  <urn:an:31> <urn:an:e> <urn:an:98> .
  <urn:an:32> <urn:an:e> <urn:an:105> .
  <urn:an:33> <urn:an:e> <urn:an:112> .
  <urn:an:34> <urn:an:e> <urn:an:119> .
  <urn:an:35> <urn:an:e> <urn:an:6> .
  <urn:an:36> <urn:an:e> <urn:an:13> .
  <urn:an:37> <urn:an:e> <urn:an:20> .
  <urn:an:38> <urn:an:e> <urn:an:27> .
  <urn:an:39> <urn:an:e> <urn:an:34> .
  <urn:an:40> <urn:an:e> <urn:an:41> .
  <urn:an:41> <urn:an:e> <urn:an:48> .
  <urn:an:42> <urn:an:e> <urn:an:55> .
  <urn:an:43> <urn:an:e> <urn:an:62> .
  <urn:an:44> <urn:an:e> <urn:an:69> .
  <urn:an:45> <urn:an:e> <urn:an:76> .
  <urn:an:46> <urn:an:e> <urn:an:83> .
  <urn:an:47> <urn:an:e> <urn:an:90> .
  <urn:an:48> <urn:an:e> <urn:an:97> .
  <urn:an:49> <urn:an:e> <urn:an:104> .
  <urn:an:50> <urn:an:e> <urn:an:111> .
  <urn:an:51> <urn:an:e> <urn:an:118> .
  <urn:an:52> <urn:an:e> <urn:an:5> .
  <urn:an:53> <urn:an:e> <urn:an:12> .
  <urn:an:54> <urn:an:e> <urn:an:19> .
  <urn:an:55> <urn:an:e> <urn:an:26> .
  <urn:an:56> <urn:an:e> <urn:an:33> .
  <urn:an:57> <urn:an:e> <urn:an:40> .
  <urn:an:58> <urn:an:e> <urn:an:47> .
  <urn:an:59> <urn:an:e> <urn:an:54> .
  <urn:an:60> <urn:an:e> <urn:an:61> .
  <urn:an:61> <urn:an:e> <urn:an:68> .
  <urn:an:62> <urn:an:e> <urn:an:75> .
  <urn:an:63> <urn:an:e> <urn:an:82> .
  <urn:an:64> <urn:an:e> <urn:an:89> .
  <urn:an:65> <urn:an:e> <urn:an:96> .
  <urn:an:66> <urn:an:e> <urn:an:103> .
  <urn:an:67> <urn:an:e> <urn:an:110> .
  <urn:an:68> <urn:an:e> <urn:an:117> .
  <urn:an:69> <urn:an:e> <urn:an:4> .
  <urn:an:70> <urn:an:e> <urn:an:11> .
  <urn:an:71> <urn:an:e> <urn:an:18> .
  <urn:an:72> <urn:an:e> <urn:an:25> .
  <urn:an:73> <urn:an:e> <urn:an:32> .
  <urn:an:74> <urn:an:e> <urn:an:39> .
  <urn:an:75> <urn:an:e> <urn:an:46> .
  <urn:an:76> <urn:an:e> <urn:an:53> .
  <urn:an:77> <urn:an:e> <urn:an:60> .
  <urn:an:78> <urn:an:e> <urn:an:67> .
  <urn:an:79> <urn:an:e> <urn:an:74> .
  <urn:an:80> <urn:an:e> <urn:an:81> .
  <urn:an:81> <urn:an:e> <urn:an:88> .
  <urn:an:82> <urn:an:e> <urn:an:95> .
  <urn:an:83> <urn:an:e> <urn:an:102> .
  <urn:an:84> <urn:an:e> <urn:an:109> .
  <urn:an:85> <urn:an:e> <urn:an:116> .
  <urn:an:86> <urn:an:e> <urn:an:3> .
  <urn:an:87> <urn:an:e> <urn:an:10> .
  <urn:an:88> <urn:an:e> <urn:an:17> .
  <urn:an:89> <urn:an:e> <urn:an:24> .
  <urn:an:90> <urn:an:e> <urn:an:31> .
  <urn:an:91> <urn:an:e> <urn:an:38> .
  <urn:an:92> <urn:an:e> <urn:an:45> .
  <urn:an:93> <urn:an:e> <urn:an:52> .
  <urn:an:94> <urn:an:e> <urn:an:59> .
  <urn:an:95> <urn:an:e> <urn:an:66> .
  <urn:an:96> <urn:an:e> <urn:an:73> .
  <urn:an:97> <urn:an:e> <urn:an:80> .
  <urn:an:98> <urn:an:e> <urn:an:87> .
  <urn:an:99> <urn:an:e> <urn:an:94> .
  <urn:an:100> <urn:an:e> <urn:an:101> .
  <urn:an:101> <urn:an:e> <urn:an:108> .
  <urn:an:102> <urn:an:e> <urn:an:115> .
  <urn:an:103> <urn:an:e> <urn:an:2> .
  <urn:an:104> <urn:an:e> <urn:an:9> .
  <urn:an:105> <urn:an:e> <urn:an:16> .
  <urn:an:106> <urn:an:e> <urn:an:23> .
  <urn:an:107> <urn:an:e> <urn:an:30> .
  <urn:an:108> <urn:an:e> <urn:an:37> .
  <urn:an:109> <urn:an:e> <urn:an:44> .
  <urn:an:110> <urn:an:e> <urn:an:51> .
  <urn:an:111> <urn:an:e> <urn:an:58> .
  <urn:an:112> <urn:an:e> <urn:an:65> .
  <urn:an:113> <urn:an:e> <urn:an:72> .
  <urn:an:114> <urn:an:e> <urn:an:79> .
  <urn:an:115> <urn:an:e> <urn:an:86> .
  <urn:an:116> <urn:an:e> <urn:an:93> .
  <urn:an:117> <urn:an:e> <urn:an:100> .
  <urn:an:118> <urn:an:e> <urn:an:107> .
  <urn:an:119> <urn:an:e> <urn:an:114> .
};

SPARQL SELECT DISTINCT ?n ?rank FROM <urn:an:g> WHERE {
  ?a <urn:an:e> ?b .
  { BIND (?a AS ?n) } UNION { BIND (?b AS ?n) }
  ?n bif:pagerank ?rank OPTION (edges (?a, ?b)) } LIMIT 5;
ECHO BOTH ": AN1 an unbound node column is refused, not dereferenced = " $STATE "\n";
ECHO BOTH $IF $EQU $STATE 42001 "PASSED" "***FAILED";

-- AN.2: and the server is still there.  AN1 asserting a SQL state says
-- nothing if the process died -- the connection simply drops and every
-- later assertion fails for an unrelated-looking reason.  This one is the
-- evidence that it did not.
SPARQL SELECT (COUNT(*) AS ?c) FROM <urn:an:g> WHERE { ?s <urn:an:e> ?o };
ECHO BOTH ": AN2 the server survived the previous query = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 120 "PASSED" "***FAILED";

-- ============================================================================
-- Group AO: one weighted graph, written three ways
--
-- A weight does not belong on a triple -- a triple has no room for it --
-- so every RDF vocabulary that carries weights puts them somewhere else:
-- on an RDF 1.2 triple term, on a W3C reification, or on an n-ary node
-- that stands for the relationship.  The first two the weighted loaders
-- read by themselves; the third they cannot, because an n-ary node is a
-- node like any other and nothing marks it as an edge.  That one is
-- reached through OPTION (edges (?a, ?b, ?w)), which takes the weight
-- from the query's own rows.
--
-- The point of the group is that all three describe the SAME graph and
-- must therefore give the SAME numbers.  Nine legs between seven depots,
-- with the hours chosen so the quickest route (5 hours, three legs) is
-- NOT the shortest one (2 legs, 7 hours): if the weights were ignored
-- and every edge counted 1, the weighted answer would come back 2, and
-- 2 is what a silently-empty weight table returns.
-- ============================================================================
SPARQL CLEAR GRAPH <urn:ao:star>;
SPARQL CLEAR GRAPH <urn:ao:reif>;
SPARQL CLEAR GRAPH <urn:ao:nary>;

-- AO.1: RDF 1.2, in the annotation spelling, which asserts the leg and
-- its hours in one breath.  Loaded as Turtle because << >> and {| |} in a
-- SPARUL INSERT are broken on a fresh database at CaseMode 0 or 1.
CREATE PROCEDURE GTEST_AO_LOAD_STAR ()
{
  DB.DBA.TTLP (
    '<urn:ao:leuven>    <urn:ao:leg> <urn:ao:brussels>  {| <urn:ao:hours> 2 |} . ' ||
    '<urn:ao:leuven>    <urn:ao:leg> <urn:ao:liege>     {| <urn:ao:hours> 3 |} . ' ||
    '<urn:ao:leuven>    <urn:ao:leg> <urn:ao:ghent>     {| <urn:ao:hours> 4 |} . ' ||
    '<urn:ao:brussels>  <urn:ao:leg> <urn:ao:antwerp>   {| <urn:ao:hours> 1 |} . ' ||
    '<urn:ao:brussels>  <urn:ao:leg> <urn:ao:ghent>     {| <urn:ao:hours> 1 |} . ' ||
    '<urn:ao:antwerp>   <urn:ao:leg> <urn:ao:rotterdam> {| <urn:ao:hours> 2 |} . ' ||
    '<urn:ao:ghent>     <urn:ao:leg> <urn:ao:rotterdam> {| <urn:ao:hours> 3 |} . ' ||
    '<urn:ao:liege>     <urn:ao:leg> <urn:ao:eindhoven> {| <urn:ao:hours> 2 |} . ' ||
    '<urn:ao:eindhoven> <urn:ao:leg> <urn:ao:rotterdam> {| <urn:ao:hours> 2 |} . ',
    '', 'urn:ao:star');
  COMMIT WORK;
  RETURN 'LOADED';
}
;
SELECT GTEST_AO_LOAD_STAR ();
ECHO BOTH ": AO1 RDF 1.2 annotation syntax loads = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] LOADED "PASSED" "***FAILED";

-- AO.2: the same nine legs as W3C reification.
SPARQL INSERT INTO GRAPH <urn:ao:reif> {
  <urn:ao:leuven> <urn:ao:leg> <urn:ao:brussels> . <urn:ao:leuven> <urn:ao:leg> <urn:ao:liege> .
  <urn:ao:leuven> <urn:ao:leg> <urn:ao:ghent> . <urn:ao:brussels> <urn:ao:leg> <urn:ao:antwerp> .
  <urn:ao:brussels> <urn:ao:leg> <urn:ao:ghent> . <urn:ao:antwerp> <urn:ao:leg> <urn:ao:rotterdam> .
  <urn:ao:ghent> <urn:ao:leg> <urn:ao:rotterdam> . <urn:ao:liege> <urn:ao:leg> <urn:ao:eindhoven> .
  <urn:ao:eindhoven> <urn:ao:leg> <urn:ao:rotterdam> .
  <urn:ao:s1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:ao:leuven> ; <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:ao:leg> ; <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:ao:brussels> ; <urn:ao:hours> 2 .
  <urn:ao:s2> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:ao:leuven> ; <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:ao:leg> ; <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:ao:liege> ; <urn:ao:hours> 3 .
  <urn:ao:s3> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:ao:leuven> ; <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:ao:leg> ; <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:ao:ghent> ; <urn:ao:hours> 4 .
  <urn:ao:s4> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:ao:brussels> ; <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:ao:leg> ; <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:ao:antwerp> ; <urn:ao:hours> 1 .
  <urn:ao:s5> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:ao:brussels> ; <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:ao:leg> ; <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:ao:ghent> ; <urn:ao:hours> 1 .
  <urn:ao:s6> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:ao:antwerp> ; <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:ao:leg> ; <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:ao:rotterdam> ; <urn:ao:hours> 2 .
  <urn:ao:s7> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:ao:ghent> ; <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:ao:leg> ; <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:ao:rotterdam> ; <urn:ao:hours> 3 .
  <urn:ao:s8> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:ao:liege> ; <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:ao:leg> ; <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:ao:eindhoven> ; <urn:ao:hours> 2 .
  <urn:ao:s9> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:ao:eindhoven> ; <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:ao:leg> ; <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:ao:rotterdam> ; <urn:ao:hours> 2 .
};
SPARQL SELECT (COUNT(*) AS ?c) FROM <urn:ao:reif> WHERE { ?s <urn:ao:leg> ?o };
ECHO BOTH ": AO2 reified legs loaded = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 9 "PASSED" "***FAILED";

-- AO.3: and as n-ary relationships -- a leg node per leg, carrying the
-- far end and the hours, which is what a vocabulary does when the
-- relationship has more to say than one number.
SPARQL INSERT INTO GRAPH <urn:ao:nary> {
  <urn:ao:leuven> <urn:ao:hasLeg> <urn:ao:L1> . <urn:ao:L1> <urn:ao:to> <urn:ao:brussels> ; <urn:ao:hours> 2 .
  <urn:ao:leuven> <urn:ao:hasLeg> <urn:ao:L2> . <urn:ao:L2> <urn:ao:to> <urn:ao:liege> ; <urn:ao:hours> 3 .
  <urn:ao:leuven> <urn:ao:hasLeg> <urn:ao:L3> . <urn:ao:L3> <urn:ao:to> <urn:ao:ghent> ; <urn:ao:hours> 4 .
  <urn:ao:brussels> <urn:ao:hasLeg> <urn:ao:L4> . <urn:ao:L4> <urn:ao:to> <urn:ao:antwerp> ; <urn:ao:hours> 1 .
  <urn:ao:brussels> <urn:ao:hasLeg> <urn:ao:L5> . <urn:ao:L5> <urn:ao:to> <urn:ao:ghent> ; <urn:ao:hours> 1 .
  <urn:ao:antwerp> <urn:ao:hasLeg> <urn:ao:L6> . <urn:ao:L6> <urn:ao:to> <urn:ao:rotterdam> ; <urn:ao:hours> 2 .
  <urn:ao:ghent> <urn:ao:hasLeg> <urn:ao:L7> . <urn:ao:L7> <urn:ao:to> <urn:ao:rotterdam> ; <urn:ao:hours> 3 .
  <urn:ao:liege> <urn:ao:hasLeg> <urn:ao:L8> . <urn:ao:L8> <urn:ao:to> <urn:ao:eindhoven> ; <urn:ao:hours> 2 .
  <urn:ao:eindhoven> <urn:ao:hasLeg> <urn:ao:L9> . <urn:ao:L9> <urn:ao:to> <urn:ao:rotterdam> ; <urn:ao:hours> 2 .
};
SPARQL SELECT (COUNT(*) AS ?c) FROM <urn:ao:nary> WHERE { ?l <urn:ao:hours> ?h };
ECHO BOTH ": AO3 n-ary legs loaded = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 9 "PASSED" "***FAILED";

-- AO.4: the quickest route Leuven -> Rotterdam read off the RDF 1.2 form.
-- 5, not 2: three legs of 2+1+2 beat the two-leg route that costs 7.
SPARQL SELECT (MAX(?len) AS ?l) FROM <urn:ao:star> WHERE {
  <urn:ao:rotterdam> bif:shortest_path_length ?len
  OPTION (source_node <urn:ao:leuven>, weight <urn:ao:hours>) };
ECHO BOTH ": AO4 RDF 1.2 weighted path = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";

-- AO.5: the same number off the reified form.
SPARQL SELECT (MAX(?len) AS ?l) FROM <urn:ao:reif> WHERE {
  <urn:ao:rotterdam> bif:shortest_path_length ?len
  OPTION (source_node <urn:ao:leuven>, weight <urn:ao:hours>) };
ECHO BOTH ": AO5 reified weighted path = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";

-- AO.6: and off the n-ary form, whose weights arrive through the query.
SPARQL SELECT (MAX(?len) AS ?l) FROM <urn:ao:nary> WHERE {
  ?from <urn:ao:hasLeg> ?leg . ?leg <urn:ao:to> ?to ; <urn:ao:hours> ?hours .
  <urn:ao:rotterdam> bif:shortest_path_length ?len
  OPTION (edges (?from, ?to, ?hours), source_node <urn:ao:leuven>) };
ECHO BOTH ": AO6 n-ary weighted path = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";

-- AO.7: the guard the other three lean on.  Unweighted, the same graph
-- answers 2, and 2 is exactly what AO.4-AO.6 would report if the weight
-- table had come back empty.  Without this line, a weight lookup that
-- quietly found nothing would still look like a pass in a run where the
-- hours happened to sum to 2.
SPARQL SELECT (MAX(?len) AS ?l) FROM <urn:ao:star> WHERE {
  <urn:ao:rotterdam> bif:shortest_path_length ?len OPTION (source_node <urn:ao:leuven>) };
ECHO BOTH ": AO7 unweighted path is a different number = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

-- AO.8-AO.10: weighted betweenness agrees across the three spellings.
-- A path length reads one number out of the weight table; betweenness
-- reads all of them, on every shortest path in the graph, so it is the
-- assertion that a partially-loaded table fails.
SPARQL SELECT (MAX(?b) AS ?m) FROM <urn:ao:star> WHERE {
  { ?n <urn:ao:leg> ?x } UNION { ?y <urn:ao:leg> ?n }
  ?n bif:betweenness ?b OPTION (weight <urn:ao:hours>) };
ECHO BOTH ": AO8 RDF 1.2 weighted betweenness peak = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 5.5 "PASSED" "***FAILED";

SPARQL SELECT (MAX(?b) AS ?m) FROM <urn:ao:reif> WHERE {
  { ?n <urn:ao:leg> ?x } UNION { ?y <urn:ao:leg> ?n }
  ?n bif:betweenness ?b OPTION (weight <urn:ao:hours>) };
ECHO BOTH ": AO9 reified weighted betweenness peak = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 5.5 "PASSED" "***FAILED";

SPARQL SELECT (MAX(?b) AS ?m) FROM <urn:ao:nary> WHERE {
  ?from <urn:ao:hasLeg> ?leg . ?leg <urn:ao:to> ?to ; <urn:ao:hours> ?hours .
  { ?n <urn:ao:hasLeg> ?l2 } UNION { ?l3 <urn:ao:to> ?n }
  ?n bif:betweenness ?b OPTION (edges (?from, ?to, ?hours)) };
ECHO BOTH ": AO10 n-ary weighted betweenness peak = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 5.5 "PASSED" "***FAILED";

-- AO.11: betweenness is undirected unless asked otherwise.  Directed,
-- Rotterdam cannot be an intermediate node on anything -- every leg into
-- it is one-way -- and the peak drops to Brussels' 3.  The default is
-- worth pinning because the two answers are both plausible and only one
-- of them is what an unqualified query returns.
SPARQL SELECT (MAX(?b) AS ?m) FROM <urn:ao:star> WHERE {
  { ?n <urn:ao:leg> ?x } UNION { ?y <urn:ao:leg> ?n }
  ?n bif:betweenness ?b OPTION (weight <urn:ao:hours>, directed 1) };
ECHO BOTH ": AO11 directed weighted betweenness peak = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";

-- AO.12-AO.14: two different edge sets in one session must not become
-- one graph, and the same edge set twice must not become two.
--
-- The transient graph an OPTION (edges ...) builds is named by the
-- content of its edge list, so that the planner re-evaluating the
-- collector -- which it may do once per row of the enclosing join --
-- lands on the entry it made last time instead of minting another.  It
-- used to mint one per evaluation from a per-connection counter, and a
-- single statement put 81 graphs into a registry that holds 64: the
-- registration its own rows were still carrying got evicted, and the
-- algorithm failed with "failed to load graph: Not found".  AO.10 is the
-- assertion that catches that; these three are the assertions that catch
-- over-correcting it, because a name that stopped discriminating would
-- quietly serve one edge set's answer for another's.
--
-- The subset is a proper subset -- the six legs of two hours or less --
-- and its peak is a different number from the whole network's, so a
-- collision between the two names cannot pass.
SPARQL SELECT (MAX(?b) AS ?m) FROM <urn:ao:nary> WHERE {
  ?from <urn:ao:hasLeg> ?leg . ?leg <urn:ao:to> ?to ; <urn:ao:hours> ?hours .
  { ?n <urn:ao:hasLeg> ?l2 } UNION { ?l3 <urn:ao:to> ?n }
  ?n bif:betweenness ?b OPTION (edges (?from, ?to, ?hours)) };
ECHO BOTH ": AO12 whole edge set = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 5.5 "PASSED" "***FAILED";

SPARQL SELECT (MAX(?b) AS ?m) FROM <urn:ao:nary> WHERE {
  ?from <urn:ao:hasLeg> ?leg . ?leg <urn:ao:to> ?to ; <urn:ao:hours> ?hours .
  FILTER (?hours <= 2)
  { ?n <urn:ao:hasLeg> ?l2 } UNION { ?l3 <urn:ao:to> ?n }
  ?n bif:betweenness ?b OPTION (edges (?from, ?to, ?hours)) };
ECHO BOTH ": AO13 a subset is its own graph = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 9 "PASSED" "***FAILED";

-- And back again: the whole set still answers for the whole set.  If the
-- subset had overwritten it -- one name for two contents -- this reads 9.
SPARQL SELECT (MAX(?b) AS ?m) FROM <urn:ao:nary> WHERE {
  ?from <urn:ao:hasLeg> ?leg . ?leg <urn:ao:to> ?to ; <urn:ao:hours> ?hours .
  { ?n <urn:ao:hasLeg> ?l2 } UNION { ?l3 <urn:ao:to> ?n }
  ?n bif:betweenness ?b OPTION (edges (?from, ?to, ?hours)) };
ECHO BOTH ": AO14 the whole set survived the subset = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 5.5 "PASSED" "***FAILED";

-- ============================================================================
-- Group AP: a graph loaded from a table weighs its edges from the column,
-- whatever the caller calls the weight predicate
--
-- GRAPH_LOAD_TABLE (g, p, tbl, 'W') registers a graph whose weights are a
-- column.  There is no RDF behind such a graph, so the weight predicate a
-- weighted BIF is handed cannot be found in the store -- and it does not
-- need to be, because the column is the only candidate.
--
-- build_weight_lookup_from_graph() knew that, but only after an earlier
-- shortcut: an unresolvable weight predicate returned an EMPTY weight
-- table on the reasoning that a predicate the store never heard of
-- carries no weights.  For an RDF graph that is right.  For a
-- table-sourced one it skipped the column and weighed every edge at the
-- default 1.0, so a weighted shortest path returned its HOP COUNT -- a
-- whole number, in the units of the weights, with no error.
--
-- It was invisible from SQL, because iri_to_id() interns the IRI it is
-- given: writing the predicate as iri_to_id('...') makes it resolvable
-- and the bug does not fire.  Passing the same IRI as a plain string,
-- which is what a caller that never wrote any RDF does, is what reaches
-- it.  Both spellings are asserted below.
-- ============================================================================
CREATE TABLE DB.DBA.AP_E (S BIGINT, O BIGINT, W DOUBLE PRECISION)
;
GRANT SELECT ON DB.DBA.AP_E TO SPARQL_SELECT;
INSERT INTO DB.DBA.AP_E (S,O,W) VALUES (1,2,0.25);
INSERT INTO DB.DBA.AP_E (S,O,W) VALUES (2,3,0.25);
INSERT INTO DB.DBA.AP_E (S,O,W) VALUES (3,4,0.25);
INSERT INTO DB.DBA.AP_E (S,O,W) VALUES (1,4,9.0);
COMMIT WORK;

SELECT GRAPH_LOAD_TABLE ('urn:ap:g', 'urn:ap:e', 'DB.DBA.AP_E', 'W');
ECHO BOTH ": AP1 table with a weight column registers = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";

-- AP.2: the weight predicate as a plain string, never interned.  Three
-- hops of 0.25 beat the single edge of 9.0, so the answer is 0.75.  The
-- defect returns 1: one hop, the direct edge, counted as weight 1.
SELECT GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED (1, 4, 'urn:ap:g', 'urn:ap:e',
         'urn:ap:never-interned', 0);
ECHO BOTH ": AP2 column weights with an unknown predicate = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.75 "PASSED" "***FAILED";

-- AP.3: the same call with the predicate interned first.  This spelling
-- always worked, and it is here so that a regression tells you which of
-- the two paths broke.
SELECT iri_to_id ('urn:ap:interned');
SELECT GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED (1, 4, 'urn:ap:g', 'urn:ap:e',
         'urn:ap:interned', 0);
ECHO BOTH ": AP3 column weights with an interned predicate = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.75 "PASSED" "***FAILED";

-- AP.4: the guard.  Unweighted, the same graph answers 1, and 1 is
-- exactly what AP.2 returns when the column is skipped.  Without this
-- line the pin in AP.2 could be read as an arbitrary constant.
SELECT GRAPH_SHORTEST_PATH_LENGTH (1, 4, 'urn:ap:g', 'urn:ap:e');
ECHO BOTH ": AP4 unweighted is a different number = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- ============================================================================
-- Group AQ: an enclosing GRAPH block wins over FROM
-- ============================================================================
-- With FROM <g1> FROM NAMED <g2>, a predicate inside GRAPH <g2> { } was
-- handed g1, the single FROM, and answered about the wrong graph.
SPARQL INSERT INTO <urn:gfg:g1> { <urn:gfg:a> <urn:gfg:p> <urn:gfg:b> };
SPARQL INSERT INTO <urn:gfg:g2> { <urn:gfg:a> <urn:gfg:p> <urn:gfg:b> . <urn:gfg:a> <urn:gfg:p> <urn:gfg:c> };
COMMIT WORK;

SPARQL SELECT (STR (?d) AS ?aq1) FROM <urn:gfg:g1> FROM NAMED <urn:gfg:g2>
WHERE { GRAPH <urn:gfg:g2> { <urn:gfg:a> bif:degree_centrality ?d } };
ECHO BOTH ": AQ1 degree(a) inside GRAPH <g2> with FROM <g1> = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

SPARQL SELECT (STR (?d) AS ?aq2) FROM <urn:gfg:g1>
WHERE { <urn:gfg:a> bif:degree_centrality ?d };
ECHO BOTH ": AQ2 degree(a) with FROM <g1> and no GRAPH block = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- ============================================================================
-- Group AR: a self-loop does not close a triangle
-- ============================================================================
-- 1 -> 2 and 2 -> 2 counted (1, 2, 2) as a triangle.
SPARQL INSERT INTO <urn:gsl:g> { <urn:gsl:1> <urn:gsl:p> <urn:gsl:2> . <urn:gsl:2> <urn:gsl:p> <urn:gsl:2> };
COMMIT WORK;

SPARQL SELECT (STR (bif:triangle_count (<urn:gsl:g>, <urn:gsl:p>)) AS ?ar1) WHERE { };
ECHO BOTH ": AR1 triangles with only a self-loop and one edge = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

select cast (GRAPH_TRIANGLE_COUNT ('urn:gsl:2', 'urn:gsl:g', 'urn:gsl:p') as integer);
ECHO BOTH ": AR2 triangles at the looped node = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";

-- ============================================================================
-- Group AY: a refused load says why, whichever function was refused
--
-- A graph BIF that cannot load its graph reports "failed to load graph:
-- <reason>" -- "Capacity exceeded" for a graph over [Graph] MaxNodes, "Not
-- found", or the underlying error.  The traversals, the component functions
-- and GRAPH_DEGREE_WEIGHTED dropped the reason and said only "failed to load
-- graph", so a graph refused for its size read exactly like one that is
-- missing, and the one fact an operator needs -- raise the limit -- was not
-- in the message.  GRAPH_PAGERANK is the control: it always said why.
-- ============================================================================

CREATE PROCEDURE GTEST_LOAD_REASON ()
{
  DECLARE fns, stmts ANY;
  DECLARE i INT;
  DECLARE st, msg VARCHAR;
  DECLARE mdta, rset ANY;
  fns := vector ('GRAPH_PAGERANK', 'GRAPH_BFS', 'GRAPH_DFS',
                 'GRAPH_SHORTEST_PATH_LENGTH', 'GRAPH_SHORTEST_PATH',
                 'GRAPH_WCC', 'GRAPH_WCC_COUNT', 'GRAPH_SCC', 'GRAPH_SCC_COUNT',
                 'GRAPH_DEGREE_WEIGHTED');
  stmts := vector (
    'select GRAPH_PAGERANK (''urn:graph:test:A'', ''urn:graph:test'', ''urn:graph:test:edge'')',
    'select GRAPH_BFS (''urn:graph:test:A'', ''urn:graph:test:E'', ''urn:graph:test'', ''urn:graph:test:edge'')',
    'select GRAPH_DFS (''urn:graph:test:A'', ''urn:graph:test:E'', ''urn:graph:test'', ''urn:graph:test:edge'')',
    'select GRAPH_SHORTEST_PATH_LENGTH (''urn:graph:test:A'', ''urn:graph:test:E'', ''urn:graph:test'', ''urn:graph:test:edge'')',
    'select GRAPH_SHORTEST_PATH (''urn:graph:test:A'', ''urn:graph:test:E'', ''urn:graph:test'', ''urn:graph:test:edge'')',
    'select GRAPH_WCC (''urn:graph:test:A'', ''urn:graph:test'', ''urn:graph:test:edge'')',
    'select GRAPH_WCC_COUNT (''urn:graph:test'', ''urn:graph:test:edge'')',
    'select GRAPH_SCC (''urn:graph:test:A'', ''urn:graph:test'', ''urn:graph:test:edge'')',
    'select GRAPH_SCC_COUNT (''urn:graph:test'', ''urn:graph:test:edge'')',
    'select GRAPH_DEGREE_WEIGHTED (''urn:graph:test:A'', ''urn:graph:test'', ''urn:graph:test:edge'', ' ||
      'vector (vector (''urn:graph:test:A'', ''urn:graph:test:B'', 2.0)))');
  GRAPH_SET_LIMIT ('MaxGraphNodes', 3);
  for (i := 0; i < length (stmts); i := i + 1)
    {
      st := '00000';
      msg := '';
      exec (stmts[i], st, msg, vector (), 0, mdta, rset);
      if (st <> '42006' or strstr (msg, 'Capacity exceeded') is null)
        {
          GRAPH_SET_LIMIT ('MaxGraphNodes', 100000);
          return fns[i] || ' ' || st;
        }
    }
  GRAPH_SET_LIMIT ('MaxGraphNodes', 100000);
  return 'ALLSAID';
}
;

-- AY.1: every one of them names the limit that refused it
SELECT GTEST_LOAD_REASON ();
ECHO BOTH ": AY1 a refusal for size says Capacity exceeded = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] ALLSAID "PASSED" "***FAILED";

-- AY.2: and with the limit back, the same graph loads, so AY1 was the limit
-- talking and not a graph the functions could not have read anyway
select GRAPH_WCC_COUNT ('urn:graph:test', 'urn:graph:test:edge');
ECHO BOTH ": AY2 components with the limit restored = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

-- ============================================================================
-- Group AX: a weighted predicate call with no graph scope aligns its arguments
--
-- In predicate position the compiler builds the weighted BIF's arguments
-- positionally.  When a graph can be injected -- FROM, an enclosing GRAPH
-- block, or OPTION (graph) -- the list is (node, graph, pred, weight, ...).
-- When none can, the graph slot was set to NULL but the pred slot was
-- dropped, so weight landed in pred, and every later option slid one place
-- left: pagerank read max_iter (100) as damping, eigenvector read the weight
-- IRI box as max_iter, and betweenness and closeness returned a silent 0.
-- The unweighted branch kept the slot and resolved the empty default graph
-- cleanly, which is the behaviour the weighted branch must match.
--
-- Checked on the generated SQL, which shows the slot directly and does not
-- depend on what graph is loaded or on how an empty one answers.  The
-- argument-aligned form has the graph slot and the pred slot both before
-- the weight IRI; the defect had only the graph slot, so the weight landed
-- one place early.  Whitespace-stripped, the aligned form reads
-- "0,0,<weight>" and the defect "0,<weight>", wherever the node arguments
-- end.  A.1 above already covers that the aligned call computes the right
-- values, so this only has to pin the alignment.
-- ============================================================================

-- A compiled statement's SQL with all whitespace removed, for a structural
-- substring test.  sparql_to_sql_text() resolves IRIs at compile time, so
-- it needs no data loaded.  (The parameter is not named `sparql` and the
-- variable not `sql`: both are reserved words as identifiers, and the
-- whitespace is stripped with chr() rather than '\n', which would be a
-- real newline in the source and split the CREATE.)
CREATE PROCEDURE GTEST_SQL_NOWS (IN qtext VARCHAR)
{
  DECLARE stxt VARCHAR;
  stxt := cast (sparql_to_sql_text (qtext) AS VARCHAR);
  -- a debug build prints comments such as /* QName as sqlval */
  stxt := regexp_replace (stxt, '/\\*[^*]*\\*/', '', 1, null);
  stxt := replace (stxt, chr (32), '');
  stxt := replace (stxt, chr (9), '');
  stxt := replace (stxt, chr (10), '');
  stxt := replace (stxt, chr (13), '');
  RETURN stxt;
}
;

CREATE PROCEDURE GTEST_WNOSCOPE ()
{
  DECLARE preds, forms ANY;
  DECLARE i INT;
  DECLARE stxt VARCHAR;
  -- node-argument shapes differ (per-node vs the pair traversal), but in
  -- every aligned form the weight IRI is preceded by graph 0 and pred 0
  forms := vector (
    'SELECT ?n ?r WHERE { ?n <urn:ax:e> ?o . ?n bif:pagerank ?r OPTION (weight <urn:ax:w>) }',
    'SELECT ?n ?r WHERE { ?n <urn:ax:e> ?o . ?n bif:betweenness ?r OPTION (weight <urn:ax:w>) }',
    'SELECT ?n ?r WHERE { ?n <urn:ax:e> ?o . ?n bif:closeness ?r OPTION (weight <urn:ax:w>) }',
    'SELECT ?n ?r WHERE { ?n <urn:ax:e> ?o . ?n bif:eigenvector ?r OPTION (weight <urn:ax:w>) }',
    'SELECT ?n ?r WHERE { ?n <urn:ax:e> ?o . ?n bif:degree_centrality ?r OPTION (weight <urn:ax:w>) }',
    'SELECT ?n ?r WHERE { ?n <urn:ax:e> ?o . ?n bif:shortest_path_length ?r OPTION (weight <urn:ax:w>, source_node <urn:ax:a>) }');
  preds := vector ('pagerank', 'betweenness', 'closeness', 'eigenvector',
                   'degree_centrality', 'shortest_path_length');
  FOR (i := 0; i < length (forms); i := i + 1)
    {
      stxt := GTEST_SQL_NOWS (forms[i]);
      -- aligned: graph 0, pred 0, then the weight IRI.  The defect emitted
      -- only graph 0 before it ("0,__bft(...'urn:ax:w'"), so this is absent.
      IF (strstr (stxt, '0,0,__bft(__bft(''urn:ax:w''') IS NULL)
        RETURN preds[i] || ' misaligned';
    }
  RETURN 'ALIGNED';
}
;

-- AX.1: every weighted predicate form, compiled with no graph scope, puts
-- the weight IRI after both the graph slot and the pred slot
SELECT GTEST_WNOSCOPE ();
ECHO BOTH ": AX1 weighted predicate forms with no scope = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] ALIGNED "PASSED" "***FAILED";

-- AX.2: the FROM-scoped form was already aligned (its graph slot is the
-- FROM IRI, its pred slot 0), so the fix must not disturb it
SELECT case when strstr (GTEST_SQL_NOWS (
  'SELECT ?n ?r FROM <urn:ax:g> WHERE { ?n <urn:ax:e> ?o . ?n bif:pagerank ?r OPTION (weight <urn:ax:w>) }'),
  '0,__bft(__bft(''urn:ax:w''') is not null then 'ALIGNED' else 'MOVED' end;
ECHO BOTH ": AX2 FROM-scoped weighted pagerank still aligned = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] ALIGNED "PASSED" "***FAILED";

-- ============================================================================
-- Summary
-- ============================================================================
SPARQL SELECT ('Graph analytics test suite completed' AS ?summary)
WHERE { ?s ?p ?o }
LIMIT 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";

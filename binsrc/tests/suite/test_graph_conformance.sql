--  test_graph_conformance.sql
--
--  Hand-computed conformance for the six standard graph algorithms.
--  Test Group P.
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
--  test_graph_scale.sql puts wall-clock budgets on a 20,000-node graph:
--  that is the performance anchor, and it says nothing about whether the
--  answers are the right ones.  This file is the conformance anchor.  Its
--  graph is small enough that every expected value below was worked out by
--  hand before it was run, and all six of the standard algorithms -- BFS,
--  PageRank, WCC, CDLP, LCC, SSSP -- are pinned on it.
--
--  THE GRAPH  <urn:graph:conf>, edges on <urn:graph:conf:link>
--
--    Component X, a directed triangle with a pendant:
--        a -> b,  b -> c,  c -> a,  a -> d
--    Component Y, a directed 4-cycle:
--        e -> f,  f -> g,  g -> h,  h -> e
--
--  Undirected degrees (a directed edge counts once in each direction, which
--  is the convention triangle counting, LCC and CDLP all use):
--        a 3,  b 2,  c 2,  d 1,  e 2,  f 2,  g 2,  h 2
--
--  Worked out by hand, then pinned below:
--
--    BFS from a, following out-edges:  a 0, b 1, d 1, c 2; e..h unreachable
--    WCC:                              {a,b,c,d} and {e,f,g,h}
--    Triangles:                        one, a-b-c
--    LCC:      lcc(v) = tri(v) / (d(v)*(d(v)-1)/2), and 0 when d(v) < 2
--              a 1/3,  b 1,  c 1,  d 0,  e..h 0
--              mean over all eight nodes = (1/3 + 1 + 1) / 8 = 7/24
--    PageRank: e, f, g, h sit on a symmetric closed cycle with no in-edges
--              from component X, so they start equal and stay equal at
--              every iteration -- their scores must be bit-identical
--    SSSP from a, with weights a->b 4, a->d 1, b->c 1, c->a 1:
--              d(a,d) = 1,  d(a,b) = 4,  d(a,c) = 4 + 1 = 5,  e unreachable
--    CDLP:     labels never cross a component boundary, so a and e must
--              differ.  Within a component, see the note on GCONF_CDLP.
--
--  THE TIE GRAPH  <urn:graph:conf:tie>, edges on <urn:graph:conf:link>
--
--    s -> x (weight 1),  s -> y (weight 1),
--    x -> t (weight 1),  y -> t (weight 1)
--
--  d(s,t) is 2 by either route, so which vertex ends up as t's parent is
--  decided entirely by the order the traversal relaxes edges in -- it is
--  not determined by the distances, and no distance assertion can see it.
--  P.15 and P.16 pin it: the FIRST relaxation to reach a tied distance
--  keeps the parent, and edges leave a vertex in ascending target order,
--  so the winner is the lower node index.  x is minted before y, so the
--  path is s, x, t.
--
--  That rule is a contract, not an accident.  Any change to the heap, to
--  the traversal order, or to how the work is divided between threads has
--  to preserve it, and this is the assertion that says so.
--
--  Every call passes the predicate filter <urn:graph:conf:link>.  The
--  weights are W3C reification triples in the same graph (the weighted
--  loaders read them from RDF_QUAD directly), and the filter is what keeps
--  those reification triples out of the graph structure itself.

ECHO BOTH "STARTED: graph analytics conformance suite\n";

SPARQL CLEAR GRAPH <urn:graph:conf>;

SPARQL INSERT INTO GRAPH <urn:graph:conf> {
    <urn:graph:conf:a> <urn:graph:conf:link> <urn:graph:conf:b> .
    <urn:graph:conf:b> <urn:graph:conf:link> <urn:graph:conf:c> .
    <urn:graph:conf:c> <urn:graph:conf:link> <urn:graph:conf:a> .
    <urn:graph:conf:a> <urn:graph:conf:link> <urn:graph:conf:d> .
    <urn:graph:conf:e> <urn:graph:conf:link> <urn:graph:conf:f> .
    <urn:graph:conf:f> <urn:graph:conf:link> <urn:graph:conf:g> .
    <urn:graph:conf:g> <urn:graph:conf:link> <urn:graph:conf:h> .
    <urn:graph:conf:h> <urn:graph:conf:link> <urn:graph:conf:e> .
};

-- Edge weights for SSSP, as W3C reification.  RDF 1.2 << s p o >> is not
-- used here for the same reason Group J avoids it: SPARUL INSERT of a
-- triple term is broken on a fresh database at CaseMode 0 or 1.
SPARQL INSERT INTO GRAPH <urn:graph:conf> {
    <urn:graph:conf:w1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:graph:conf:a> .
    <urn:graph:conf:w1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:graph:conf:link> .
    <urn:graph:conf:w1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:graph:conf:b> .
    <urn:graph:conf:w1> <urn:graph:conf:w> 4.0 .
    <urn:graph:conf:w2> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:graph:conf:a> .
    <urn:graph:conf:w2> <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:graph:conf:link> .
    <urn:graph:conf:w2> <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:graph:conf:d> .
    <urn:graph:conf:w2> <urn:graph:conf:w> 1.0 .
    <urn:graph:conf:w3> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:graph:conf:b> .
    <urn:graph:conf:w3> <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:graph:conf:link> .
    <urn:graph:conf:w3> <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:graph:conf:c> .
    <urn:graph:conf:w3> <urn:graph:conf:w> 1.0 .
    <urn:graph:conf:w4> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:graph:conf:c> .
    <urn:graph:conf:w4> <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:graph:conf:link> .
    <urn:graph:conf:w4> <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:graph:conf:a> .
    <urn:graph:conf:w4> <urn:graph:conf:w> 1.0 .
};

SPARQL CLEAR GRAPH <urn:graph:conf:tie>;

-- Mint s, x, y, t in that order before any edge, so node index order is
-- s < x < y < t and the tie-break below is stated in terms of something
-- the fixture controls rather than of whatever order the parser happened
-- to intern names in.
SPARQL INSERT INTO GRAPH <urn:graph:conf:tie> {
    <urn:graph:conf:tie:1s> <urn:graph:conf:mint> 1 .
    <urn:graph:conf:tie:2x> <urn:graph:conf:mint> 1 .
    <urn:graph:conf:tie:3y> <urn:graph:conf:mint> 1 .
    <urn:graph:conf:tie:4t> <urn:graph:conf:mint> 1 .
};

SPARQL INSERT INTO GRAPH <urn:graph:conf:tie> {
    <urn:graph:conf:tie:1s> <urn:graph:conf:link> <urn:graph:conf:tie:2x> .
    <urn:graph:conf:tie:1s> <urn:graph:conf:link> <urn:graph:conf:tie:3y> .
    <urn:graph:conf:tie:2x> <urn:graph:conf:link> <urn:graph:conf:tie:4t> .
    <urn:graph:conf:tie:3y> <urn:graph:conf:link> <urn:graph:conf:tie:4t> .
};

SPARQL INSERT INTO GRAPH <urn:graph:conf:tie> {
    <urn:graph:conf:tw1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:graph:conf:tie:1s> .
    <urn:graph:conf:tw1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:graph:conf:link> .
    <urn:graph:conf:tw1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:graph:conf:tie:2x> .
    <urn:graph:conf:tw1> <urn:graph:conf:w> 1.0 .
    <urn:graph:conf:tw2> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:graph:conf:tie:1s> .
    <urn:graph:conf:tw2> <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:graph:conf:link> .
    <urn:graph:conf:tw2> <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:graph:conf:tie:3y> .
    <urn:graph:conf:tw2> <urn:graph:conf:w> 1.0 .
    <urn:graph:conf:tw3> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:graph:conf:tie:2x> .
    <urn:graph:conf:tw3> <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:graph:conf:link> .
    <urn:graph:conf:tw3> <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:graph:conf:tie:4t> .
    <urn:graph:conf:tw3> <urn:graph:conf:w> 1.0 .
    <urn:graph:conf:tw4> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <urn:graph:conf:tie:3y> .
    <urn:graph:conf:tw4> <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <urn:graph:conf:link> .
    <urn:graph:conf:tw4> <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <urn:graph:conf:tie:4t> .
    <urn:graph:conf:tw4> <urn:graph:conf:w> 1.0 .
};

-- Every procedure is defined here, above the assertions: CREATE PROCEDURE is
-- a write and bumps the graph cache's invalidation generation.

create procedure GCONF_N (in n varchar) { return 'urn:graph:conf:' || n; }
;

-- BFS depths from a, following out-edges, as one string so a failure shows
-- the whole vector rather than the first difference.
create procedure GCONF_BFS ()
{
  declare i int;
  declare s varchar;
  declare names any;
  names := vector ('a','b','c','d','e','f','g','h');
  s := '';
  for (i := 0; i < 8; i := i + 1)
    s := s || cast (GRAPH_BFS (GCONF_N ('a'), GCONF_N (aref (names, i)),
                               'urn:graph:conf', 'urn:graph:conf:link') as varchar) || ' ';
  return rtrim (s);
}
;

create procedure GCONF_WCC ()
{
  declare a, b, c, d, e, f, g, h int;
  a := GRAPH_WCC (GCONF_N ('a'), 'urn:graph:conf', 'urn:graph:conf:link');
  b := GRAPH_WCC (GCONF_N ('b'), 'urn:graph:conf', 'urn:graph:conf:link');
  c := GRAPH_WCC (GCONF_N ('c'), 'urn:graph:conf', 'urn:graph:conf:link');
  d := GRAPH_WCC (GCONF_N ('d'), 'urn:graph:conf', 'urn:graph:conf:link');
  e := GRAPH_WCC (GCONF_N ('e'), 'urn:graph:conf', 'urn:graph:conf:link');
  f := GRAPH_WCC (GCONF_N ('f'), 'urn:graph:conf', 'urn:graph:conf:link');
  g := GRAPH_WCC (GCONF_N ('g'), 'urn:graph:conf', 'urn:graph:conf:link');
  h := GRAPH_WCC (GCONF_N ('h'), 'urn:graph:conf', 'urn:graph:conf:link');
  if (a = b and b = c and c = d and e = f and f = g and g = h and a <> e)
    return 'ABCD|EFGH';
  return sprintf ('%d %d %d %d %d %d %d %d', a, b, c, d, e, f, g, h);
}
;

create procedure GCONF_LCC ()
{
  declare i int;
  declare s varchar;
  declare names any;
  names := vector ('a','b','c','d','e','f','g','h');
  s := '';
  for (i := 0; i < 8; i := i + 1)
    s := s || cast (GRAPH_CLUSTERING_COEFFICIENT (GCONF_N (aref (names, i)),
                      'urn:graph:conf', 'urn:graph:conf:link') as varchar) || ' ';
  return rtrim (s);
}
;

-- The four nodes of the closed cycle are interchangeable, so PageRank must
-- give them the same score to the last bit -- an exact equality that needs
-- no pinned constant and no tolerance.
create procedure GCONF_PR_SYMMETRY ()
{
  declare e, f, g, h double precision;
  e := GRAPH_PAGERANK (GCONF_N ('e'), 'urn:graph:conf', 'urn:graph:conf:link');
  f := GRAPH_PAGERANK (GCONF_N ('f'), 'urn:graph:conf', 'urn:graph:conf:link');
  g := GRAPH_PAGERANK (GCONF_N ('g'), 'urn:graph:conf', 'urn:graph:conf:link');
  h := GRAPH_PAGERANK (GCONF_N ('h'), 'urn:graph:conf', 'urn:graph:conf:link');
  if (e = f and f = g and g = h and e > 0)
    return 'SYMMETRIC';
  return sprintf ('%s %s %s %s', cast (e as varchar), cast (f as varchar),
                                 cast (g as varchar), cast (h as varchar));
}
;

-- ... and a is strictly ahead of the two nodes that only receive from it or
-- from one predecessor, which fixes the ordering PageRank is used for.
create procedure GCONF_PR_ORDER ()
{
  declare a, b, c, d double precision;
  a := GRAPH_PAGERANK (GCONF_N ('a'), 'urn:graph:conf', 'urn:graph:conf:link');
  b := GRAPH_PAGERANK (GCONF_N ('b'), 'urn:graph:conf', 'urn:graph:conf:link');
  c := GRAPH_PAGERANK (GCONF_N ('c'), 'urn:graph:conf', 'urn:graph:conf:link');
  d := GRAPH_PAGERANK (GCONF_N ('d'), 'urn:graph:conf', 'urn:graph:conf:link');
  if (a > c and c > b and b = d)
    return 'A>C>B=D';
  return sprintf ('%s %s %s %s', cast (a as varchar), cast (b as varchar),
                                 cast (c as varchar), cast (d as varchar));
}
;

create procedure GCONF_SSSP (in tgt varchar)
{
  declare v any;
  v := GRAPH_SHORTEST_PATH_WEIGHTED (GCONF_N ('a'), GCONF_N (tgt), 'urn:graph:conf',
                                     'urn:graph:conf:link', 'urn:graph:conf:w', 1);
  if (v is null)
    return 'UNREACHABLE';
  return cast (aref (v, 2) as varchar);
}
;

-- CDLP is the deterministic (synchronous) variant:
-- every node reads the previous iteration's labels, the iteration count is
-- fixed, and ties go to the smallest label.
--
-- Component X collapses to one label.  Component Y does NOT, and must not:
-- a 4-cycle is bipartite, so under synchronous updates the two independent
-- sets {e,g} and {f,h} exchange labels every iteration and never meet.
-- That is the specified behaviour of this variant, not a defect -- it is
-- also why GRAPH_LABEL_PROPAGATION is not a drop-in replacement for
-- GRAPH_COMMUNITY_ID, which is Louvain and would merge them.
create procedure GCONF_CDLP ()
{
  declare a, b, c, d, e, f, g, h int;
  a := GRAPH_LABEL_PROPAGATION (GCONF_N ('a'), 'urn:graph:conf', 'urn:graph:conf:link');
  b := GRAPH_LABEL_PROPAGATION (GCONF_N ('b'), 'urn:graph:conf', 'urn:graph:conf:link');
  c := GRAPH_LABEL_PROPAGATION (GCONF_N ('c'), 'urn:graph:conf', 'urn:graph:conf:link');
  d := GRAPH_LABEL_PROPAGATION (GCONF_N ('d'), 'urn:graph:conf', 'urn:graph:conf:link');
  e := GRAPH_LABEL_PROPAGATION (GCONF_N ('e'), 'urn:graph:conf', 'urn:graph:conf:link');
  f := GRAPH_LABEL_PROPAGATION (GCONF_N ('f'), 'urn:graph:conf', 'urn:graph:conf:link');
  g := GRAPH_LABEL_PROPAGATION (GCONF_N ('g'), 'urn:graph:conf', 'urn:graph:conf:link');
  h := GRAPH_LABEL_PROPAGATION (GCONF_N ('h'), 'urn:graph:conf', 'urn:graph:conf:link');
  if (a = b and b = c and c = d and e = g and f = h and e <> f and a <> e and a <> f)
    return 'ABCD|EG|FH';
  return sprintf ('%d %d %d %d %d %d %d %d', a, b, c, d, e, f, g, h);
}
;

-- Two runs at the same iteration count have to give the same partition.
create procedure GCONF_CDLP_REPEAT ()
{
  declare one, two varchar;
  one := GCONF_CDLP ();
  two := GCONF_CDLP ();
  return case when one = two then 'SAME' else one || ' <> ' || two end;
}
;

-- The parent chain, as the path it reconstructs.  Distances cannot see a
-- tie-break; a path can.
create procedure GCONF_TIE_PATH (in weighted int)
{
  declare v any;
  declare i int;
  declare s varchar;
  if (weighted)
    v := GRAPH_SHORTEST_PATH_WEIGHTED ('urn:graph:conf:tie:1s', 'urn:graph:conf:tie:4t',
           'urn:graph:conf:tie', 'urn:graph:conf:link', 'urn:graph:conf:w', 0);
  else
    v := GRAPH_SHORTEST_PATH ('urn:graph:conf:tie:1s', 'urn:graph:conf:tie:4t',
           'urn:graph:conf:tie', 'urn:graph:conf:link', 0);
  if (v is null)
    return 'NULL';
  s := '';
  for (i := 0; i < length (v); i := i + 1)
    {
      declare nm varchar;
      nm := cast (aref (v, i) as varchar);
      s := s || subseq (nm, length ('urn:graph:conf:tie:'));
    }
  return s;
}
;

-- ============================================================================
-- Group P: the six standard algorithms on a hand-computed graph
-- ============================================================================

-- P.1: the fixture loaded (8 edges + 16 weight triples)
SPARQL SELECT (COUNT(*) AS ?p1) FROM <urn:graph:conf> WHERE { ?s <urn:graph:conf:link> ?o };
ECHO BOTH ": P1 edges = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";

-- P.2: BFS depths from a: a 0, b 1, c 2, d 1, e..h unreachable
select GCONF_BFS ();
ECHO BOTH ": P2 BFS depths from a = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "0 1 2 1 -1 -1 -1 -1" "PASSED" "***FAILED";

-- P.3: WCC membership: two components
select GCONF_WCC ();
ECHO BOTH ": P3 WCC membership = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "ABCD|EFGH" "PASSED" "***FAILED";

-- P.4: exactly one triangle, a-b-c
select GRAPH_TRIANGLE_COUNT ('urn:graph:conf', 'urn:graph:conf:link');
ECHO BOTH ": P4 triangles = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- P.5: LCC per node, hand-computed above
select GCONF_LCC ();
ECHO BOTH ": P5 LCC per node = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "0.3333333333333333 1 1 0 0 0 0 0" "PASSED" "***FAILED";

-- P.6: mean LCC over all eight nodes = 7/24
select cast (GRAPH_CLUSTERING_COEFFICIENT ('urn:graph:conf', 'urn:graph:conf:link') as varchar);
ECHO BOTH ": P6 mean LCC = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 0.2916666666666666 "PASSED" "***FAILED";

-- P.7: PageRank is exactly equal on the symmetric cycle
select GCONF_PR_SYMMETRY ();
ECHO BOTH ": P7 PageRank on the symmetric cycle = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] SYMMETRIC "PASSED" "***FAILED";

-- P.8: ... and the ordering in the other component is the expected one
select GCONF_PR_ORDER ();
ECHO BOTH ": P8 PageRank order in component X = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "A>C>B=D" "PASSED" "***FAILED";

-- P.9 - P.12: SSSP from a under the weights above
select GCONF_SSSP ('d');
ECHO BOTH ": P9 SSSP a->d (weight 1) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

select GCONF_SSSP ('b');
ECHO BOTH ": P10 SSSP a->b (weight 4) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";

select GCONF_SSSP ('c');
ECHO BOTH ": P11 SSSP a->c (4 + 1) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";

select GCONF_SSSP ('e');
ECHO BOTH ": P12 SSSP a->e (other component) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] UNREACHABLE "PASSED" "***FAILED";

-- P.13: CDLP partition, including the bipartite component it must not merge
select GCONF_CDLP ();
ECHO BOTH ": P13 CDLP partition = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "ABCD|EG|FH" "PASSED" "***FAILED";

-- P.14: and it is the same partition on a second run
select GCONF_CDLP_REPEAT ();
ECHO BOTH ": P14 CDLP repeatable = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] SAME "PASSED" "***FAILED";

-- P.15 - P.16: the tie-break, weighted and unweighted.  Both routes to t
-- cost the same, so this is the only assertion in the suite that pins
-- which parent a tie gets.
select GCONF_TIE_PATH (1);
ECHO BOTH ": P15 weighted tie-break path s->t = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "1s2x4t" "PASSED" "***FAILED";

select GCONF_TIE_PATH (0);
ECHO BOTH ": P16 unweighted tie-break path s->t = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "1s2x4t" "PASSED" "***FAILED";

ECHO BOTH "COMPLETED: graph analytics conformance suite\n";

--  test_graph_reference.sql
--
--  The six standard graph algorithms against another implementation's
--  published expected output.  Test Group Q.
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
--  test_graph_conformance.sql pins values worked out by hand.  That checks
--  we are self-consistent; it cannot check that we answer the same question
--  as everybody else.  This file loads the two small example graphs that a
--  widely used graph benchmark ships with its validation module, and pins
--  OUR answers to ITS published expected output, value for value.
--
--  It is the file that catches a difference in convention rather than a
--  difference in arithmetic, and four of the assertions below fail against
--  an engine that has the conventions wrong even though every number it
--  produces is internally consistent:
--
--    * an undirected graph is stored one direction per edge, so BFS and
--      SSSP have to walk both ways (direction 2) and PageRank has to take
--      the neighbourhood symmetrically (directed 0);
--    * a weight triple is written once per edge, so a traversal that walks
--      an edge backwards has to find the same weight;
--    * community labels are the community's representative vertex, not a
--      dense counter, and ties break on vertex id, which is only true if
--      the loader mints vertex IRIs in ascending vertex order -- Q1 and Q2
--      are what check that, and every CDLP assertion depends on them;
--    * on a DIRECTED graph the clustering coefficient is over the DISTINCT
--      neighbourhood and counts ordered pairs joined by a directed edge.
--
--  THE GRAPHS
--
--  <urn:graph:ref:d>, ten vertices, seventeen directed edges.
--  <urn:graph:ref:u>, nine vertices, twelve undirected edges held one
--  direction each.  Both on <urn:graph:ref:e>, with a weight per edge as
--  one reifier triple on <urn:graph:ref:w>.
--
--  Vertex n is <urn:graph:ref:d:n> / <urn:graph:ref:u:n>.
--
--  The expected values are the reference implementation's own, for its own
--  parameters: two iterations for PageRank (damping 0.85) and for the
--  community labels.

ECHO BOTH "STARTED: graph analytics reference-output suite\n";

SPARQL CLEAR GRAPH <urn:graph:ref:d>;
SPARQL CLEAR GRAPH <urn:graph:ref:u>;

-- Mint every vertex IRI in ascending vertex order BEFORE any edge is
-- loaded.  IRI_IDs are handed out in the order iri_to_id() first sees a
-- name, node indices are ascending IRI_ID order, and the community
-- tie-break is on node index -- so this is what makes our tie-break agree
-- with a tie-break on vertex id.  Q1/Q2 verify it rather than trust it.
create procedure QREF_MINT (in pfx varchar, in lo int, in hi int)
{
  declare i int;
  for (i := lo; i <= hi; i := i + 1)
    iri_to_id (pfx || cast (i as varchar), 1);
  commit work;
  return hi - lo + 1;
}
;

create procedure QREF_ORDER (in pfx varchar, in lo int, in hi int)
{
  declare i, prev, cur int;
  prev := -1;
  for (i := lo; i <= hi; i := i + 1)
    {
      cur := iri_id_num (iri_to_id (pfx || cast (i as varchar)));
      if (prev >= 0 and cur <= prev)
        return sprintf ('OUT OF ORDER at %d', i);
      prev := cur;
    }
  return 'ASCENDING';
}
;

-- One edge plus its weight.  The weight is a single triple whose subject
-- encodes the base triple, which is one triple per edge against four for
-- the plain reification form.
create procedure QREF_EDGE (in g varchar, in pfx varchar, in s int, in o int,
                            in w double precision)
{
  declare sid, pid, oid int;
  DB.DBA.RDF_QUAD_URI (g, pfx || cast (s as varchar), 'urn:graph:ref:e',
                       pfx || cast (o as varchar));
  sid := iri_id_num (iri_to_id (pfx || cast (s as varchar)));
  pid := iri_id_num (iri_to_id ('urn:graph:ref:e'));
  oid := iri_id_num (iri_to_id (pfx || cast (o as varchar)));
  DB.DBA.RDF_QUAD_URI_L (g, sprintf ('urn:rdf-star:reifier:%d:%d:i%d', sid, pid, oid),
                         'urn:graph:ref:w', w);
  return 1;
}
;

create procedure QREF_LOAD ()
{
  declare d, u varchar;
  d := 'urn:graph:ref:d:';
  u := 'urn:graph:ref:u:';
  QREF_EDGE ('urn:graph:ref:d', d, 1, 3, 0.5);
  QREF_EDGE ('urn:graph:ref:d', d, 1, 5, 0.3);
  QREF_EDGE ('urn:graph:ref:d', d, 2, 4, 0.1);
  QREF_EDGE ('urn:graph:ref:d', d, 2, 5, 0.3);
  QREF_EDGE ('urn:graph:ref:d', d, 2, 10, 0.12);
  QREF_EDGE ('urn:graph:ref:d', d, 3, 1, 0.53);
  QREF_EDGE ('urn:graph:ref:d', d, 3, 5, 0.62);
  QREF_EDGE ('urn:graph:ref:d', d, 3, 8, 0.21);
  QREF_EDGE ('urn:graph:ref:d', d, 3, 10, 0.52);
  QREF_EDGE ('urn:graph:ref:d', d, 5, 3, 0.69);
  QREF_EDGE ('urn:graph:ref:d', d, 5, 4, 0.53);
  QREF_EDGE ('urn:graph:ref:d', d, 5, 8, 0.1);
  QREF_EDGE ('urn:graph:ref:d', d, 6, 3, 0.23);
  QREF_EDGE ('urn:graph:ref:d', d, 6, 4, 0.39);
  QREF_EDGE ('urn:graph:ref:d', d, 7, 4, 0.83);
  QREF_EDGE ('urn:graph:ref:d', d, 8, 1, 0.39);
  QREF_EDGE ('urn:graph:ref:d', d, 9, 4, 0.69);
  QREF_EDGE ('urn:graph:ref:u', u, 2, 3, 0.9);
  QREF_EDGE ('urn:graph:ref:u', u, 2, 4, 0.69);
  QREF_EDGE ('urn:graph:ref:u', u, 3, 4, 0.13);
  QREF_EDGE ('urn:graph:ref:u', u, 3, 5, 0.5);
  QREF_EDGE ('urn:graph:ref:u', u, 3, 8, 0.32);
  QREF_EDGE ('urn:graph:ref:u', u, 5, 6, 0.63);
  QREF_EDGE ('urn:graph:ref:u', u, 5, 8, 0.12);
  QREF_EDGE ('urn:graph:ref:u', u, 6, 7, 0.53);
  QREF_EDGE ('urn:graph:ref:u', u, 6, 8, 0.64);
  QREF_EDGE ('urn:graph:ref:u', u, 6, 9, 0.23);
  QREF_EDGE ('urn:graph:ref:u', u, 6, 10, 0.63);
  QREF_EDGE ('urn:graph:ref:u', u, 7, 9, 0.36);
  commit work;
  return 'loaded';
}
;

-- Compare a per-vertex integer result against the expected vector.  The
-- vector is indexed from vertex `lo`; -1 in it means "unreachable", which
-- is what our BFS returns and what the other implementation writes as
-- 9223372036854775807.
create procedure QREF_CMP_INT (in pfx varchar, in g varchar, in src int,
                               in lo int, in hi int, in dir int, in expect any)
{
  declare i, got, want int;
  for (i := lo; i <= hi; i := i + 1)
    {
      got := GRAPH_BFS (pfx || cast (src as varchar), pfx || cast (i as varchar),
                        g, 'urn:graph:ref:e', dir);
      want := aref (expect, i - lo);
      if (got is null or got <> want)
        return sprintf ('v%d got %s want %d', i,
                        case when got is null then 'NULL' else cast (got as varchar) end, want);
    }
  return 'MATCH';
}
;

-- Weighted distances.  A NULL from the engine and a NULL in the expected
-- vector both mean unreachable.
create procedure QREF_CMP_SSSP (in pfx varchar, in g varchar, in src int,
                                in lo int, in hi int, in dir int, in expect any)
{
  declare i int;
  declare got, want double precision;
  for (i := lo; i <= hi; i := i + 1)
    {
      got := GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED (pfx || cast (src as varchar),
               pfx || cast (i as varchar), g, 'urn:graph:ref:e',
               iri_to_id ('urn:graph:ref:w'), dir);
      want := aref (expect, i - lo);
      if (want is null)
        {
          if (got is not null)
            return sprintf ('v%d got %f want unreachable', i, got);
        }
      else if (got is null)
        return sprintf ('v%d got unreachable want %f', i, want);
      else if (abs (got - want) > 0.000000001)
        return sprintf ('v%d got %.12f want %.12f', i, got, want);
    }
  return 'MATCH';
}
;

create procedure QREF_CMP_PR (in pfx varchar, in g varchar, in lo int, in hi int,
                              in directed int, in expect any)
{
  declare i int;
  declare got, want double precision;
  for (i := lo; i <= hi; i := i + 1)
    {
      got := GRAPH_PAGERANK (pfx || cast (i as varchar), g, 'urn:graph:ref:e',
                             0.85, 2, 0.0000000001, directed);
      want := aref (expect, i - lo);
      if (abs (got - want) > 0.000000001)
        return sprintf ('v%d got %.12f want %.12f', i, got, want);
    }
  return 'MATCH';
}
;

-- Community labels in the representative-vertex form: the label is the
-- IRI_ID of a real vertex, so it is compared as a vertex number.
create procedure QREF_CMP_CDLP (in pfx varchar, in g varchar, in lo int, in hi int,
                                in expect any)
{
  declare i, lbl, want int;
  declare iri varchar;
  for (i := lo; i <= hi; i := i + 1)
    {
      lbl := GRAPH_LABEL_PROPAGATION (pfx || cast (i as varchar), g,
                                      'urn:graph:ref:e', 2, 1);
      iri := cast (id_to_iri (iri_id_from_num (lbl)) as varchar);
      want := aref (expect, i - lo);
      if (iri <> pfx || cast (want as varchar))
        return sprintf ('v%d got %s want %d', i, iri, want);
    }
  return 'MATCH';
}
;

create procedure QREF_CMP_LCC (in pfx varchar, in g varchar, in lo int, in hi int,
                               in directed int, in expect any)
{
  declare i int;
  declare got, want double precision;
  for (i := lo; i <= hi; i := i + 1)
    {
      got := GRAPH_CLUSTERING_COEFFICIENT (pfx || cast (i as varchar), g,
                                           'urn:graph:ref:e', directed);
      want := aref (expect, i - lo);
      if (abs (got - want) > 0.000000001)
        return sprintf ('v%d got %.12f want %.12f', i, got, want);
    }
  return 'MATCH';
}
;

create procedure QREF_WCC_ONE (in pfx varchar, in g varchar, in lo int, in hi int)
{
  declare i, c, first int;
  first := -1;
  for (i := lo; i <= hi; i := i + 1)
    {
      c := GRAPH_WCC (pfx || cast (i as varchar), g, 'urn:graph:ref:e');
      if (first < 0) first := c;
      if (c <> first) return sprintf ('v%d is in a different component', i);
    }
  return 'ONE';
}
;

-- A clustering coefficient outside [0,1] is a defect, not a discrepancy.
-- Each convention is checked on the kind of graph it is defined for: the
-- default one counts a neighbour once per direction, which on a DIRECTED
-- graph double-counts a vertex joined both ways and can exceed 1 -- that
-- is exactly what the directed form exists to fix, and Q17 pins the
-- unfixed values so the default cannot move by accident.
create procedure QREF_LCC_BOUND ()
{
  declare i int;
  declare v double precision;
  for (i := 1; i <= 10; i := i + 1)
    {
      v := GRAPH_CLUSTERING_COEFFICIENT ('urn:graph:ref:d:' || cast (i as varchar),
             'urn:graph:ref:d', 'urn:graph:ref:e', 1);
      if (v < 0 or v > 1)
        return sprintf ('directed v%d lcc=%f', i, v);
    }
  for (i := 2; i <= 10; i := i + 1)
    {
      v := GRAPH_CLUSTERING_COEFFICIENT ('urn:graph:ref:u:' || cast (i as varchar),
             'urn:graph:ref:u', 'urn:graph:ref:e', 0);
      if (v < 0 or v > 1)
        return sprintf ('undirected v%d lcc=%f', i, v);
    }
  return 'IN RANGE';
}
;

-- Total rank over every vertex.  PageRank is a probability distribution,
-- so this is 1.0 whatever the iteration count -- the reference
-- implementation's values sum to 1.0 as well, and any redistribution of
-- dangling mass that loses or invents rank shows up here and nowhere
-- else.  Q11 and Q12 pin two iterations; this runs the iteration far
-- enough that a per-iteration bug in the score arrays cannot hide behind
-- an early exit.  Vertices 4 and 10 of the directed graph have out-degree
-- zero, so the dangling term is live in both graphs.
create procedure QREF_PR_MASS (in pfx varchar, in g varchar, in lo int, in hi int,
                               in directed int, in iters int)
{
  declare i int;
  declare s double precision;
  s := 0;
  for (i := lo; i <= hi; i := i + 1)
    s := s + GRAPH_PAGERANK (pfx || cast (i as varchar), g, 'urn:graph:ref:e',
                             0.85, iters, 0.0000000001, directed);
  if (abs (s - 1.0) > 0.000000001)
    return sprintf ('%d iterations sum to %.17f', iters, s);
  return 'UNIT';
}
;

-- The default label form is still the dense one: labels in
-- [0, community_count), not vertex ids.
create procedure QREF_CDLP_DENSE ()
{
  declare i, lbl, n int;
  n := 0;
  for (i := 1; i <= 10; i := i + 1)
    {
      lbl := GRAPH_LABEL_PROPAGATION ('urn:graph:ref:d:' || cast (i as varchar),
               'urn:graph:ref:d', 'urn:graph:ref:e', 2);
      if (lbl < 0 or lbl >= 10)
        return sprintf ('v%d dense label %d out of [0,10)', i, lbl);
      if (lbl > n) n := lbl;
    }
  return 'DENSE';
}
;

select QREF_MINT ('urn:graph:ref:d:', 1, 10);
select QREF_MINT ('urn:graph:ref:u:', 2, 10);
select QREF_LOAD ();

-- ============================================================================
-- Group Q: our answers against another implementation's expected output
-- ============================================================================

-- Q.1 - Q.2: the loader's IRI order.  Every community assertion below rests
-- on this, so it is asserted rather than assumed.
select QREF_ORDER ('urn:graph:ref:d:', 1, 10);
ECHO BOTH ": Q1 directed vertex IRI order = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] ASCENDING "PASSED" "***FAILED";

select QREF_ORDER ('urn:graph:ref:u:', 2, 10);
ECHO BOTH ": Q2 undirected vertex IRI order = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] ASCENDING "PASSED" "***FAILED";

-- Q.3: the fixture loaded: 17 directed edges, 12 undirected, one weight
-- triple each.
SPARQL SELECT (COUNT(*) AS ?q3) FROM <urn:graph:ref:d>
  WHERE { ?s <urn:graph:ref:e> ?o };
ECHO BOTH ": Q3 directed edges = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 17 "PASSED" "***FAILED";

SPARQL SELECT (COUNT(*) AS ?q4) FROM <urn:graph:ref:u>
  WHERE { ?s <urn:graph:ref:e> ?o };
ECHO BOTH ": Q4 undirected edges = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 12 "PASSED" "***FAILED";

-- Q.5: BFS from vertex 1 on the directed graph, following out-edges.
select QREF_CMP_INT ('urn:graph:ref:d:', 'urn:graph:ref:d', 1, 1, 10, 0,
  vector (0, -1, 1, 2, 1, -1, -1, 2, -1, 2));
ECHO BOTH ": Q5 directed BFS from 1 = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] MATCH "PASSED" "***FAILED";

-- Q.6: BFS from vertex 2 on the undirected graph.  Direction 2 is the
-- whole point: the graph holds one direction per edge, and at direction 0
-- this returns unreachable for six of the nine vertices.
select QREF_CMP_INT ('urn:graph:ref:u:', 'urn:graph:ref:u', 2, 2, 10, 2,
  vector (0, 1, 1, 2, 3, 4, 2, 4, 4));
ECHO BOTH ": Q6 undirected BFS from 2 = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] MATCH "PASSED" "***FAILED";

-- Q.7 - Q.8: both example graphs are one weakly connected component.
select QREF_WCC_ONE ('urn:graph:ref:d:', 'urn:graph:ref:d', 1, 10);
ECHO BOTH ": Q7 directed WCC = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] ONE "PASSED" "***FAILED";

select QREF_WCC_ONE ('urn:graph:ref:u:', 'urn:graph:ref:u', 2, 10);
ECHO BOTH ": Q8 undirected WCC = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] ONE "PASSED" "***FAILED";

-- Q.9: weighted distances from vertex 1, directed.
select QREF_CMP_SSSP ('urn:graph:ref:d:', 'urn:graph:ref:d', 1, 1, 10, 0,
  vector (0.0, NULL, 0.5, 0.83, 0.3, NULL, NULL, 0.4, NULL, 1.02));
ECHO BOTH ": Q9 directed SSSP from 1 = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] MATCH "PASSED" "***FAILED";

-- Q.10: and from vertex 2 undirected.  Every edge here is relaxed from
-- whichever end the traversal reaches first, so this is also the assertion
-- that a weight written once per edge is found in both directions:
-- d(2,3) is 0.82 by way of vertex 4, not the 0.9 of the direct edge.
select QREF_CMP_SSSP ('urn:graph:ref:u:', 'urn:graph:ref:u', 2, 2, 10, 2,
  vector (0.0, 0.82, 0.69, 1.26, 1.78, 2.31, 1.14, 2.01, 2.41));
ECHO BOTH ": Q10 undirected SSSP from 2 = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] MATCH "PASSED" "***FAILED";

-- Q.11: PageRank on the directed graph, damping 0.85, two iterations.
select QREF_CMP_PR ('urn:graph:ref:d:', 'urn:graph:ref:d', 1, 10, 1,
  vector (0.1477629166666667, 0.04753375, 0.1550469444444444,
          0.1597573611111111, 0.14624, 0.04753375, 0.04753375,
          0.1135740277777778, 0.04753375, 0.08748375000000001));
ECHO BOTH ": Q11 directed PageRank = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] MATCH "PASSED" "***FAILED";

-- Q.12: and on the undirected graph, where the neighbourhood has to be
-- taken symmetrically.  At directed 1 this graph gets the rank of half of
-- itself and no value below is reproduced.
select QREF_CMP_PR ('urn:graph:ref:u:', 'urn:graph:ref:u', 2, 10, 0,
  vector (0.09084490740740739, 0.1424089506172839, 0.09084490740740739,
          0.1249891975308642, 0.1686172839506173, 0.09749537037037037,
          0.1249891975308642, 0.09749537037037037, 0.06231481481481481));
ECHO BOTH ": Q12 undirected PageRank = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] MATCH "PASSED" "***FAILED";

-- Q.13 - Q.14: community labels, two iterations, as representative
-- vertices.  Exact equality: these are vertex ids, not scores.
select QREF_CMP_CDLP ('urn:graph:ref:d:', 'urn:graph:ref:d', 1, 10,
  vector (1, 2, 3, 4, 1, 1, 2, 3, 2, 1));
ECHO BOTH ": Q13 directed CDLP = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] MATCH "PASSED" "***FAILED";

select QREF_CMP_CDLP ('urn:graph:ref:u:', 'urn:graph:ref:u', 2, 10,
  vector (2, 3, 2, 2, 6, 5, 2, 5, 5));
ECHO BOTH ": Q14 undirected CDLP = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] MATCH "PASSED" "***FAILED";

-- Q.15: the local clustering coefficient on the directed graph, over the
-- distinct neighbourhood and the ordered pairs inside it.
select QREF_CMP_LCC ('urn:graph:ref:d:', 'urn:graph:ref:d', 1, 10, 1,
  vector (0.6666666666666666, 0.1666666666666667, 0.15, 0.05, 0.25,
          0.0, 0.0, 0.8333333333333334, 0.0, 0.0));
ECHO BOTH ": Q15 directed LCC = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] MATCH "PASSED" "***FAILED";

-- Q.16: and on the undirected graph, where the default convention is
-- already the right one.
select QREF_CMP_LCC ('urn:graph:ref:u:', 'urn:graph:ref:u', 2, 10, 0,
  vector (1.0, 0.3333333333333333, 1.0, 0.6666666666666666, 0.2,
          1.0, 0.6666666666666666, 1.0, 0.0));
ECHO BOTH ": Q16 undirected LCC = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] MATCH "PASSED" "***FAILED";

-- Q.17: the default LCC convention has not moved.  These are the values it
-- gives on a directed graph, wrong answers to the reference's question and
-- the right ones to the question it was asked; vertex 8 above 1 is why the
-- directed form was added.
select QREF_CMP_LCC ('urn:graph:ref:d:', 'urn:graph:ref:d', 1, 10, 0,
  vector (0.8333333333333334, 0.3333333333333333, 0.2857142857142857, 0.1, 0.4,
          0.0, 0.0, 1.666666666666667, 0.0, 0.0));
ECHO BOTH ": Q17 default LCC on a directed graph unchanged = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] MATCH "PASSED" "***FAILED";

-- Q.18: 0 <= lcc <= 1, each convention on the graph it is defined for.
select QREF_LCC_BOUND ();
ECHO BOTH ": Q18 LCC in [0,1] = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "IN RANGE" "PASSED" "***FAILED";

-- Q.19: the default community label form is still the dense one.
select QREF_CDLP_DENSE ();
ECHO BOTH ": Q19 default CDLP labels are dense = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] DENSE "PASSED" "***FAILED";

-- Q.20 - Q.25: the rank sums to one, on both graphs, at two iterations and
-- well past them.
select QREF_PR_MASS ('urn:graph:ref:d:', 'urn:graph:ref:d', 1, 10, 1, 2);
ECHO BOTH ": Q20 directed PageRank mass, 2 iterations = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] UNIT "PASSED" "***FAILED";

select QREF_PR_MASS ('urn:graph:ref:d:', 'urn:graph:ref:d', 1, 10, 1, 10);
ECHO BOTH ": Q21 directed PageRank mass, 10 iterations = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] UNIT "PASSED" "***FAILED";

select QREF_PR_MASS ('urn:graph:ref:d:', 'urn:graph:ref:d', 1, 10, 1, 30);
ECHO BOTH ": Q22 directed PageRank mass, 30 iterations = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] UNIT "PASSED" "***FAILED";

select QREF_PR_MASS ('urn:graph:ref:u:', 'urn:graph:ref:u', 2, 10, 0, 2);
ECHO BOTH ": Q23 undirected PageRank mass, 2 iterations = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] UNIT "PASSED" "***FAILED";

select QREF_PR_MASS ('urn:graph:ref:u:', 'urn:graph:ref:u', 2, 10, 0, 10);
ECHO BOTH ": Q24 undirected PageRank mass, 10 iterations = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] UNIT "PASSED" "***FAILED";

select QREF_PR_MASS ('urn:graph:ref:u:', 'urn:graph:ref:u', 2, 10, 0, 30);
ECHO BOTH ": Q25 undirected PageRank mass, 30 iterations = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] UNIT "PASSED" "***FAILED";

ECHO BOTH "COMPLETED: graph analytics reference-output suite\n";

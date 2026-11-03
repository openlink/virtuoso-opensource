--  test_graph_data.sql
--
--  Graph analytics test data setup.
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
--  Creates small, deterministic test graphs with known structure so that
--  algorithm results can be checked exactly.
--
--  Test graph (8 nodes, 8 edges) in <urn:graph:test>:
--
--    A -> B
--    A -> C
--    B -> C
--    C -> A
--    B -> D
--    C -> D
--    D -> E
--    F -> F2
--
--  Expected properties:
--    - Node A: out-degree 2, in-degree 1, both-directions degree 3
--    - Node B: out-degree 2, in-degree 1
--    - Node C: out-degree 2, in-degree 2
--    - Node D: out-degree 1, in-degree 2
--    - Node E: out-degree 0, in-degree 1
--    - Node F: out-degree 1, in-degree 0 (edge to F2)
--    - Node F2: out-degree 0, in-degree 1
--    - WCC: 2 components ({A,B,C,D,E}, {F,F2})
--    - SCC: 1 non-trivial ({A,B,C}), rest singletons
--    - Triangles: A-B-C and B-C-D (2 triangles)
--    - Shortest path A->D: length 2 (A->B->D or A->C->D)
--    - Shortest path A->E: length 3 (A->B->D->E)
--    - BFS A->E: distance 3
--    - Jaccard(A,B) outgoing: neighbors(A)={B,C}, neighbors(B)={C,D},
--      intersection={C}, union={B,C,D} = 1/3
--
--  A second graph <urn:graph:test2> provides an alternate scope for the
--  multi-FROM and OPTION (graph ...) override tests:
--
--    X -> Y
--    X -> Z
--
--  Expected properties of <urn:graph:test2>:
--    - Node X: out-degree 2, in-degree 0, both-directions degree 2
--    - Nodes Y, Z: out-degree 0, in-degree 1
--    - Node A does not exist in <urn:graph:test2>

-- Clear any previous data
SPARQL CLEAR GRAPH <urn:graph:test>;
SPARQL CLEAR GRAPH <urn:graph:test2>;

-- Insert test triples
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

-- Insert the second test graph
SPARQL INSERT INTO GRAPH <urn:graph:test2> {
    <urn:graph:test:X> <urn:graph:test:edge> <urn:graph:test:Y> .
    <urn:graph:test:X> <urn:graph:test:edge> <urn:graph:test:Z> .
};

-- Verify data loaded (expected: 8 in the first graph, 2 in the second)
SPARQL SELECT COUNT(*) FROM <urn:graph:test> WHERE { ?s ?p ?o };
SPARQL SELECT COUNT(*) FROM <urn:graph:test2> WHERE { ?s ?p ?o };
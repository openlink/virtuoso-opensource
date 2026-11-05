ECHO BOTH "STARTED: graph analytics core BIF tests\n";

SPARQL CLEAR GRAPH <urn:graph-algo:test>;
SPARQL INSERT DATA INTO GRAPH <urn:graph-algo:test> {
  <urn:node:a> <urn:edge> <urn:node:b> .
  <urn:node:b> <urn:edge> <urn:node:c> .
  <urn:node:c> <urn:edge> <urn:node:a> .
};

select degree_centrality (iri_to_id ('urn:node:a'), iri_to_id ('urn:graph-algo:test'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": scalar degree_centrality\n";

sparql prefix bif: <http://www.openlinksw.com/schemas/bif#>
  select ?node ?rank from <urn:graph-algo:test>
  where { ?node <urn:edge> ?o . ?node bif:pagerank ?rank };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": predicate-position pagerank\n";

sparql prefix bif: <http://www.openlinksw.com/schemas/bif#>
  select ?node ?rank from <urn:graph-algo:test>
  where { ?node <urn:edge> ?o . ?node bif:pagerank ?rank option (damping 0.9, max_iter 20, tolerance 0.000001) };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": predicate-position OPTION parameters\n";


ECHO BOTH "STARTED: expression-position graph scope\n";

-- A second graph, so that an explicit graph argument can be shown to win.
SPARQL CLEAR GRAPH <urn:graph-algo:test2>;
SPARQL INSERT DATA INTO GRAPH <urn:graph-algo:test2> {
  <urn:node:a> <urn:edge> <urn:node:b> .
  <urn:node:b> <urn:edge> <urn:node:a> .
};

-- A call written as a function takes the graph from FROM, exactly as the
-- predicate form does.  Pinned value: a -> b -> c is two hops.
sparql prefix bif: <http://www.openlinksw.com/schemas/bif#>
  select (bif:shortest_path_length (<urn:node:a>, <urn:node:c>) as ?len)
  from <urn:graph-algo:test> where { };
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": expression position takes the graph from FROM\n";

-- ... and agrees with an explicit graph argument rather than merely being
-- non-null.  Compared inside one query so a NULL on either side is caught.
sparql prefix bif: <http://www.openlinksw.com/schemas/bif#>
  select (if (bif:pagerank (<urn:node:a>) =
              bif:pagerank (<urn:node:a>, <urn:graph-algo:test>),
              'SAME', 'DIFF') as ?v)
  from <urn:graph-algo:test> where { };
ECHO BOTH $IF $EQU $LAST[1] SAME "PASSED" "***FAILED";
ECHO BOTH ": expression position agrees with an explicit graph\n";

-- The graph BIF is reached inside an operator, which is how FILTERs are
-- written.  Without descending into the comparison the call keeps its
-- empty-graph answer and this returns DIFF.
sparql prefix bif: <http://www.openlinksw.com/schemas/bif#>
  select (if (bif:degree_centrality (<urn:node:a>) = 2, 'OK', 'BAD') as ?v)
  from <urn:graph-algo:test> where { };
ECHO BOTH $IF $EQU $LAST[1] OK "PASSED" "***FAILED";
ECHO BOTH ": expression position inside an operator\n";

-- An explicit graph argument still overrides FROM: there is no a -> c path
-- in test2, so this is -1 and not 2.
sparql prefix bif: <http://www.openlinksw.com/schemas/bif#>
  select (bif:shortest_path_length (<urn:node:a>, <urn:node:c>,
                                    <urn:graph-algo:test2>) as ?len)
  from <urn:graph-algo:test> where { };
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
ECHO BOTH ": explicit graph argument still wins over FROM\n";

-- The documented positional mistake must stay loud.  Arguments are
-- positional and the graph comes first, so 0.9 is read as the graph and the
-- load fails; it must not become a silently different answer.
sparql prefix bif: <http://www.openlinksw.com/schemas/bif#>
  select (bif:pagerank (<urn:node:a>, 0.9) as ?r)
  from <urn:graph-algo:test> where { };
ECHO BOTH $IF $EQU $STATE OK "***FAILED" "PASSED";
ECHO BOTH ": a non-graph first optional argument still raises\n";

SPARQL CLEAR GRAPH <urn:graph-algo:test2>;


ECHO BOTH "STARTED: edge_predicate option\n";

SPARQL CLEAR GRAPH <urn:graph-algo:mixed>;
SPARQL INSERT DATA INTO GRAPH <urn:graph-algo:mixed> {
  <urn:node:a> <urn:pays> <urn:node:b> .
  <urn:node:b> <urn:pays> <urn:node:c> .
  <urn:node:a> <urn:knows> <urn:node:c> .
  <urn:node:c> <urn:knows> <urn:node:a> .
  <urn:node:a> <urn:knows> <urn:node:d> .
};

-- Without a filter every IRI-to-IRI triple in scope is an edge, so the
-- degree of a is 4 -- one payment and three acquaintances.
sparql prefix bif: <http://www.openlinksw.com/schemas/bif#>
  select ?d from <urn:graph-algo:mixed>
  where { <urn:node:a> <urn:pays> ?o . <urn:node:a> bif:degree_centrality ?d };
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": no edge_predicate reads every relation\n";

-- Restricted to one relation it is 1, which is what the SQL function
-- returns when given the same predicate as its third argument.
sparql prefix bif: <http://www.openlinksw.com/schemas/bif#>
  select ?d from <urn:graph-algo:mixed>
  where { <urn:node:a> <urn:pays> ?o .
          <urn:node:a> bif:degree_centrality ?d option (edge_predicate <urn:pays>) };
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": edge_predicate restricts the graph to one relation\n";

-- A traversal takes it in the same slot: a -> b -> c over payments only.
sparql prefix bif: <http://www.openlinksw.com/schemas/bif#>
  select ?len from <urn:graph-algo:mixed>
  where { <urn:node:c> bif:shortest_path_length ?len
          option (source_node <urn:node:a>, edge_predicate <urn:pays>) };
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": edge_predicate on a traversal\n";

-- EDGES builds the graph from the group's own rows, so a predicate filter
-- over it would mean nothing; the two are refused together.
sparql prefix bif: <http://www.openlinksw.com/schemas/bif#>
  select ?d from <urn:graph-algo:mixed>
  where { ?x <urn:pays> ?y .
          ?x bif:degree_centrality ?d option (edges (?x, ?y), edge_predicate <urn:pays>) };
ECHO BOTH $IF $EQU $STATE OK "***FAILED" "PASSED";
ECHO BOTH ": edge_predicate with edges is refused\n";

SPARQL CLEAR GRAPH <urn:graph-algo:mixed>;


ECHO BOTH "STARTED: parallel betweenness\n";

-- Default is the sequential order, which is the only thing mode 1 can be
-- checked against.
SELECT GRAPH_SET_LIMIT ('BetweennessParallel', 0);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": BetweennessParallel defaults off\n";

SELECT sprintf ('%.9f', GRAPH_BETWEENNESS (iri_to_id ('urn:node:a'),
                        iri_to_id ('urn:graph-algo:test')));
ECHO BOTH $IF $EQU $LAST[1] 0.500000000 "PASSED" "***FAILED";
ECHO BOTH ": sequential betweenness value\n";

-- Same answer with the source loop sliced across workers.  Compared to
-- nine places rather than for bit-equality: the reduction sums in worker
-- order, which rounds differently from source order by design.
SELECT GRAPH_SET_LIMIT ('BetweennessParallel', 1);
SELECT sprintf ('%.9f', GRAPH_BETWEENNESS (iri_to_id ('urn:node:a'),
                        iri_to_id ('urn:graph-algo:test')));
ECHO BOTH $IF $EQU $LAST[1] 0.500000000 "PASSED" "***FAILED";
ECHO BOTH ": parallel betweenness agrees with sequential\n";

-- A graph with fewer nodes than there are workers still gets every source.
SELECT sprintf ('%.9f', GRAPH_BETWEENNESS (iri_to_id ('urn:node:b'),
                        iri_to_id ('urn:graph-algo:test')));
ECHO BOTH $IF $EQU $LAST[1] 0.500000000 "PASSED" "***FAILED";
ECHO BOTH ": parallel betweenness on a graph smaller than the worker count\n";

SELECT GRAPH_SET_LIMIT ('BetweennessParallel', 0);

SPARQL CLEAR GRAPH <urn:graph-algo:test>;

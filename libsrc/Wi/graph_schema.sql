--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2026 OpenLink Software
--
--  This program is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--

-- ----------------------------------------------------------------------
-- Analytics over a query's own result set.
--
-- GRAPH_LOAD_EDGES takes the edges, but marshalling a result set into a
-- vector of pairs by hand is not something a caller should have to write
-- to analyse their own query.  These run the query and do it.
--
-- SERVICE needs no special handling here: federation is resolved by the
-- SPARQL engine long before these see a row, so a federated query and a
-- local one take exactly the same path.  Nothing is written to the quad
-- store by either.
-- ----------------------------------------------------------------------

-- The edge list and the distinct node list of a query, in one pass.
-- Returns vector (edges, nodes).
create procedure DB.DBA.GRAPH__SPARQL_EDGES (in q varchar)
{
  declare st, msg varchar;
  declare mdta, rset any;
  declare edges, nodes, seen any;
  declare i, n int;

  st := '00000';
  msg := '';
  if (q not like 'SPARQL %' and q not like 'sparql %')
    q := 'SPARQL ' || q;
  -- exec() compiles as the invoker, which is what we want: the caller's
  -- rights, and the caller's access to whatever the query reaches.
  exec (q, st, msg, vector (), 0, mdta, rset);
  if (st <> '00000')
    signal (st, msg);
  if (not isarray (rset))
    return vector (vector (), vector ());

  n := length (rset);
  edges := make_array (n, 'any');
  seen := dict_new (n * 2);
  for (i := 0; i < n; i := i + 1)
    {
      declare row, s, o any;
      row := rset[i];
      if (not isarray (row) or length (row) < 2)
        signal ('42000',
          'GRAPH_LOAD_SPARQL: the query must project at least two columns, ' ||
          'the first two being the edge subject and object');
      -- A federated result arrives as strings; a local one may already be
      -- IRI_IDs.  iri_to_id() mints an id for an IRI the store has not
      -- seen, which is a row in the IRI table and not a triple -- the
      -- quad store is still untouched.
      s := row[0];
      o := row[1];
      if (not isiri_id (s)) s := iri_to_id (cast (s as varchar));
      if (not isiri_id (o)) o := iri_to_id (cast (o as varchar));
      aset (edges, i, vector (s, o));
      dict_put (seen, s, 1);
      dict_put (seen, o, 1);
    }
  nodes := dict_list_keys (seen, 1);
  return vector (edges, nodes);
}
;

-- Make a graph of a query's result set.  Returns the edge count.
create procedure DB.DBA.GRAPH_LOAD_SPARQL (in graph_iri varchar,
                                           in pred_iri varchar,
                                           in q varchar)
{
  declare parts any;
  parts := DB.DBA.GRAPH__SPARQL_EDGES (q);
  return GRAPH_LOAD_EDGES (graph_iri, pred_iri, parts[0]);
}
;

-- Run one algorithm over a query's result set and return (node, score).
-- The transient graph is private to this call and dropped on the way out,
-- including when the algorithm raises.
create procedure DB.DBA.GRAPH_ANALYTICS_SPARQL (in algo varchar, in q varchar)
{
  declare node varchar;
  declare score double precision;
  declare parts, nodes any;
  declare g, p varchar;
  declare i int;

  declare exit handler for sqlstate '*'
    {
      GRAPH_UNLOAD_EDGES (g);
      resignal;
    };

  g := 'urn:graph:analytics:' || md5 (q);
  p := 'urn:graph:analytics:edge';
  parts := DB.DBA.GRAPH__SPARQL_EDGES (q);
  nodes := parts[1];
  GRAPH_LOAD_EDGES (g, p, parts[0]);

  result_names (node, score);
  for (i := 0; i < length (nodes); i := i + 1)
    {
      declare nid any;
      nid := nodes[i];
      score := case lower (algo)
        when 'pagerank'               then GRAPH_PAGERANK (nid, g, p)
        when 'degree'                 then GRAPH_DEGREE_CENTRALITY (nid, g, p, 0)
        when 'degree_centrality'      then GRAPH_DEGREE_CENTRALITY (nid, g, p, 0)
        when 'betweenness'            then GRAPH_BETWEENNESS (nid, g, p)
        when 'closeness'              then GRAPH_CLOSENESS (nid, g, p)
        when 'harmonic'               then GRAPH_HARMONIC (nid, g, p)
        when 'eigenvector'            then GRAPH_EIGENVECTOR_CENTRALITY (nid, g, p)
        when 'wcc'                    then GRAPH_WCC (nid, g, p)
        when 'scc'                    then GRAPH_SCC (nid, g, p)
        when 'triangle_count'         then GRAPH_TRIANGLE_COUNT (nid, g, p)
        when 'clustering_coefficient' then GRAPH_CLUSTERING_COEFFICIENT (nid, g, p)
        when 'hits_hub'               then GRAPH_HITS_HUB (nid, g, p)
        when 'hits_authority'         then GRAPH_HITS_AUTHORITY (nid, g, p)
        else signal ('42000',
               'GRAPH_ANALYTICS_SPARQL: unknown algorithm ' || algo ||
               '; expected pagerank, degree, betweenness, closeness, harmonic, ' ||
               'eigenvector, wcc, scc, triangle_count, clustering_coefficient, ' ||
               'hits_hub or hits_authority')
        end;
      node := id_to_iri (nid);
      result (node, score);
    }
  GRAPH_UNLOAD_EDGES (g);
}
;

-- ----------------------------------------------------------------------
-- Collecting a solution set into a transient graph.
--
-- This is what OPTION (edges (?a, ?b)) compiles to.  It is a user-defined
-- aggregate rather than a BIF because a graph is the whole solution set
-- and a BIF sees one row, or one vectored batch -- building from a batch
-- would be right below the vector size and silently wrong above it.
--
-- Reachable from SPARQL as sql:GRAPH_EDGES_AGG.  The bif: prefix requires
-- a C built-in; sql: resolves a stored procedure, and spar_make_funcall()
-- recognises a user aggregate through qr_aggregate.
-- ----------------------------------------------------------------------

create procedure DB.DBA.GRAPH_EDGES_INIT (inout ctx any)
{
  -- Slot 0 holds the count; the edges follow it.
  --
  -- The count lives inside the array rather than beside it in an
  -- (array, used) pair for one reason: a pair has to be rebuilt on every
  -- row, and `ctx := vector (arr, used + 1)` copies the whole accumulated
  -- array into the new wrapper.  That is O(n^2) -- exactly what the
  -- geometric growth below is there to avoid, reintroduced one line
  -- later.  It cost 3.2 seconds to collect 4000 edges and 53 to collect
  -- 16000; in place, 9 ms and 37 ms.
  --
  -- Nothing about the result changes, which is why this needs a test of
  -- its own: a quadratic collector returns exactly the right graph.
  ctx := make_array (257, 'any');
  aset (ctx, 0, 0);
}
;

create procedure DB.DBA.GRAPH_EDGES_ACC (inout ctx any, in s any, in o any)
{
  declare used, cap int;
  used := ctx[0];
  cap := length (ctx);
  if (used + 1 >= cap)
    {
      -- Doubling, so the copies cost O(n) over the whole collection.
      declare bigger any;
      declare i int;
      bigger := make_array (cap * 2, 'any');
      for (i := 0; i <= used; i := i + 1)
        aset (bigger, i, ctx[i]);
      ctx := bigger;
    }
  -- aset mutates in place: no reassignment of ctx on the common path.
  aset (ctx, used + 1, vector (s, o));
  aset (ctx, 0, used + 1);
}
;

create procedure DB.DBA.GRAPH_EDGES_FIN (inout ctx any)
{
  declare edges any;
  declare used, i int;
  declare g varchar;
  if (ctx is null)
    return null;
  used := ctx[0];
  -- One O(n) copy to hand GRAPH_LOAD_EDGES an exactly-sized array.
  edges := make_array (used, 'any');
  for (i := 0; i < used; i := i + 1)
    aset (edges, i, ctx[i + 1]);
  -- The name is the content, so that two different edge sets get two
  -- different names -- two uses in one query, or two statements on one
  -- connection, still do not overwrite each other -- while the SAME edge
  -- set always gets the SAME name.
  --
  -- That second half is the load-bearing one.  A counter here gave every
  -- *evaluation* its own name, and the planner may evaluate this
  -- aggregate once per row of the enclosing join: one statement minted 81
  -- graphs into a registry that holds 64, evicted the registration its
  -- own rows were still carrying, and the algorithm that went looking for
  -- it failed with "failed to load graph: Not found".  Naming by content
  -- makes re-evaluation land on the entry it made last time instead of
  -- consuming another slot.
  --
  -- Linear in the edge count and measured at 83 ms per million edges,
  -- against a load of the same edges that costs far more than that.
  -- The count goes in the name beside the digest: two edge sets that
  -- collide on md5 would still have to agree on how many edges they
  -- have before one could stand in for the other.
  g := sprintf ('urn:graph:edges:%d:%s', used, md5 (serialize (edges)));
  GRAPH_LOAD_EDGES (g, 'urn:graph:edges:e', edges);
  return g;
}
;

create aggregate DB.DBA.GRAPH_EDGES_AGG (in s any, in o any) returns varchar
  from DB.DBA.GRAPH_EDGES_INIT, DB.DBA.GRAPH_EDGES_ACC, DB.DBA.GRAPH_EDGES_FIN
;

-- The same collector, with a weight per edge.
--
-- A separate aggregate rather than an optional third argument: Virtuoso
-- dispatches a user aggregate by name and arity, and the two differ in
-- what a row means, not merely in how many columns it has.
create procedure DB.DBA.GRAPH_EDGES_W_INIT (inout ctx any)
{
  ctx := make_array (257, 'any');
  aset (ctx, 0, 0);
}
;

create procedure DB.DBA.GRAPH_EDGES_W_ACC (inout ctx any, in s any, in o any,
  in w any)
{
  declare used, cap int;
  used := ctx[0];
  cap := length (ctx);
  if (used + 1 >= cap)
    {
      declare bigger any;
      declare i int;
      bigger := make_array (cap * 2, 'any');
      for (i := 0; i <= used; i := i + 1)
        aset (bigger, i, ctx[i]);
      ctx := bigger;
    }
  aset (ctx, used + 1, vector (s, o, w));
  aset (ctx, 0, used + 1);
}
;

create procedure DB.DBA.GRAPH_EDGES_W_FIN (inout ctx any)
{
  declare edges any;
  declare used, i int;
  declare g varchar;
  if (ctx is null)
    return null;
  used := ctx[0];
  edges := make_array (used, 'any');
  for (i := 0; i < used; i := i + 1)
    aset (edges, i, ctx[i + 1]);
  -- Named by content, for the reason spelled out in GRAPH_EDGES_FIN.
  -- The prefix differs from the unweighted collector's so that a weighted
  -- edge set and an unweighted one can never answer to the same name even
  -- if their rows happened to serialize alike.
  g := sprintf ('urn:graph:edges:w:%d:%s', used, md5 (serialize (edges)));
  GRAPH_LOAD_EDGES_W (g, 'urn:graph:edges:e', edges);
  return g;
}
;

create aggregate DB.DBA.GRAPH_EDGES_W_AGG (in s any, in o any, in w any)
  returns varchar
  from DB.DBA.GRAPH_EDGES_W_INIT, DB.DBA.GRAPH_EDGES_W_ACC,
       DB.DBA.GRAPH_EDGES_W_FIN
;

-- The aggregate is usable by anyone who can write a query, which is the
-- point of it: it exists so that a SPARQL caller can analyse the rows
-- their own query produced.
--
-- This grants no capability that was not already reachable.
-- GRAPH_LOAD_EDGES is a BIF and needs no grant, so a caller could always
-- build a transient graph; the aggregate only collects the rows for them.
-- Every bound that applies there applies here: [Graph] MaxTriples and
-- [Graph] MaxNodes cap the size, the graph is private to the session
-- that built it, and over HTTP it is dropped at the end of the request.
grant execute on DB.DBA.GRAPH_EDGES_INIT to public
;
grant execute on DB.DBA.GRAPH_EDGES_ACC to public
;
grant execute on DB.DBA.GRAPH_EDGES_FIN to public
;
grant execute on DB.DBA.GRAPH_EDGES_AGG to public
;

grant execute on DB.DBA.GRAPH_EDGES_W_INIT to public
;
grant execute on DB.DBA.GRAPH_EDGES_W_ACC to public
;
grant execute on DB.DBA.GRAPH_EDGES_W_FIN to public
;
grant execute on DB.DBA.GRAPH_EDGES_W_AGG to public
;

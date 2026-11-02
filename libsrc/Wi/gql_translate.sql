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
--  GQL for Virtuoso - AST to SPARQL Translator
--
--  Copyright (C) 1998-2026 OpenLink Software
--
--  Translates parsed GQL AST into executable SPARQL queries.
--  Uses a translation context (ctx) to track variable bindings and state.
--
--  Context (tx_state): flat vector of key-value pairs.
--    'active_graph'     - target graph URI (renamed from 'graph')
--    'vars'             - vector of known GQL variable names
--    'triples'          - accumulated triple patterns (string)
--    'pre_values'       - VALUES clauses that must precede triple patterns
--    'pre_binds'        - BIND clauses that must precede triple patterns
--    'filters'          - accumulated FILTER clauses (string)
--    'optionals'        - accumulated OPTIONAL blocks (string)
--    'binds'            - accumulated BIND clauses (string)
--    'values'           - accumulated VALUES clauses (string)
--    'prefixes'         - vector of vector(prefix, uri)
--    'prop_cache'       - vector of vector(subject_expr, prop_name, sparql_var)
--    'defines'          - vector of vector(key, value)
--    'base_uri'         - optional SPARQL BASE URI
--    'edge_vars'        - vector of edge variable names (for reification)
--    'edge_bindings'    - vector of vector(edge_var, subj, pred, obj)
--    'edge_ends'        - vector of vector(edge_var, subj, obj, pred): the
--                         stored edge a named single edge pattern binds
--    'edge_reif_vars'   - vector of edge vars already materialized as RDF reification
--    'reif_graph'       - graph URI for RDF reification triples
--    'active_path_var'  - path variable currently being materialized by T_STEP
--    'has_where_filters'- query has a WHERE clause that may bind path endpoints
--    'var_counter'      - counter for generating unique SPARQL variables
--    'extra_from_graphs'- additional FROM clauses
--    'suppress_default_from' - flag to suppress default FROM
--    'ontology_ns'      - per-graph ontology namespace (set by USE PROPERTY GRAPH)
--    'data_ns'          - per-graph data namespace (set by USE PROPERTY GRAPH)
--    'is_property_graph'- 1 when USE PROPERTY GRAPH is active
--    'pg_name'          - bare property-graph name (for IRI derivation)
--    'var_map'          - vector of vector(gql_name, sparql_var, kind)
--                         kind: 'node', 'edge', 'path', 'value', 'alias'
--    'in_optional_depth'- integer counter for nested OPTIONAL scoping
--    'in_set_op'        - flag: 1 when inside a UNION/EXCEPT/INTERSECT branch
--    'in_service'       - flag: 1 when translating the body of a SERVICE block
--    'error_acc'        - vector of accumulated non-fatal error messages
--

----------------------------------------------------------------------
-- Context helpers
----------------------------------------------------------------------

create procedure DB.DBA.GQL_CTX_NEW (in _graph varchar)
{
  return vector (
    'graph', _graph,
    'active_graph', _graph,
    'vars', vector (),
    'triples', '',
    'pre_values', '',
    'pre_binds', '',
    'filters', '',
    'optionals', '',
    'binds', '',
    'values', '',
    'prefixes', vector (),
    'prop_cache', vector (),
    'alias_bindings', vector (),
    'defines', vector (),
    'base_uri', null,
    'edge_vars', vector (),
    'edge_bindings', vector (),
    'edge_ends', vector (),
    'edge_reif_vars', vector (),
    'reif_graph', _graph,
    'active_path_var', null,
    'needs_auto_group', 0,
    'has_where_filters', 0,
    'var_counter', 0,
    'extra_from_graphs', vector (),
    'with_graph', null,
    'using_graphs', vector (),
    'suppress_default_from', 0,
    'force_camelcase', 0,
    'rdf12_mode', 0,
    'ontology_ns', null,
    'data_ns', null,
    'is_property_graph', 0,
    'pg_name', null,
    'var_map', vector (),
    'in_optional_depth', 0,
    'in_set_op', 0,
    'in_service', 0,
    'error_acc', vector ()
  );
}
;

-- The context is a flat (key, value, ...) vector of some forty entries that
-- the translator reads and writes on nearly every step.  get_keyword and
-- position (..., 1, 2) find a key among the even positions in C; the PL loop
-- they replace copied every key it compared.  Anything that is not an
-- even-length vector keeps the loop.

create procedure DB.DBA.GQL_CTX_GET (inout _ctx any, in _key varchar)
{
  declare i integer;
  if (__tag (_ctx) = __tag of vector and mod (length (_ctx), 2) = 0)
    return get_keyword (_key, _ctx);
  for (i := 0; i + 1 < length (_ctx); i := i + 2)
    { if (aref (_ctx, i) = _key) return aref (_ctx, i + 1); }
  return null;
}
;

create procedure DB.DBA.GQL_CTX_SET (inout _ctx any, in _key varchar, in _val any)
{
  declare i integer;
  if (__tag (_ctx) = __tag of vector and mod (length (_ctx), 2) = 0)
    {
      i := position (_key, _ctx, 1, 2);
      if (i > 0)
        {
          aset (_ctx, i, _val);
          return;
        }
    }
  else
    {
      for (i := 0; i + 1 < length (_ctx); i := i + 2)
        { if (aref (_ctx, i) = _key) { aset (_ctx, i + 1, _val); return; } }
    }
  _ctx := vector_concat (_ctx, vector (_key, _val));
}
;

-- Bind a property graph into ctx: sets graph IRI, ontology_ns, data_ns,
-- is_property_graph flag, and pg_name from a bare graph name.
-- Called by USE PROPERTY GRAPH and INSERT INTO PROPERTY GRAPH handlers.
create procedure DB.DBA.GQL_CTX_BIND_PROPERTY_GRAPH (inout _ctx any, in _graph_ref any)
{
  declare graph_val, pg_name varchar;
  declare kind varchar;

  -- Resolve the graph reference to a bare name for IRI derivation.
  -- For BARE names, use the value directly; for PNAME/IRI, resolve normally.
  if (isarray (_graph_ref) and length (_graph_ref) > 1 and aref (_graph_ref, 0) = 'GRAPH_REF')
    {
      pg_name := cast (aref (_graph_ref, 1) as varchar);
      kind := 'BARE';
      if (length (_graph_ref) > 2)
        kind := cast (aref (_graph_ref, 2) as varchar);

      if (kind = 'BARE')
        {
          -- Derive graph IRI and namespaces from the bare name
          graph_val := DB.DBA.GQL_PG_GRAPH_IRI (pg_name);
          DB.DBA.GQL_CTX_SET (_ctx, 'graph', graph_val);
          DB.DBA.GQL_CTX_SET (_ctx, 'active_graph', graph_val);
          DB.DBA.GQL_CTX_SET (_ctx, 'ontology_ns', DB.DBA.GQL_PG_ONTOLOGY_NS (pg_name));
          DB.DBA.GQL_CTX_SET (_ctx, 'data_ns', DB.DBA.GQL_PG_DATA_NS (pg_name));
          DB.DBA.GQL_CTX_SET (_ctx, 'is_property_graph', 1);
          DB.DBA.GQL_CTX_SET (_ctx, 'pg_name', pg_name);
          return;
        }
    }

  -- Non-bare reference (PNAME, IRI): resolve normally, no per-graph NS
  graph_val := DB.DBA.GQL_GRAPH_REF_VALUE_CTX (_graph_ref, _ctx);
  DB.DBA.GQL_CTX_SET (_ctx, 'graph', graph_val);
  DB.DBA.GQL_CTX_SET (_ctx, 'active_graph', graph_val);
  DB.DBA.GQL_CTX_SET (_ctx, 'is_property_graph', 0);
  DB.DBA.GQL_CTX_SET (_ctx, 'pg_name', null);
}
;

create procedure DB.DBA.GQL_CTX_ADD_VAR (inout _ctx any, in _var varchar)
{
  declare vars any;
  declare i integer;
  if (_var is null or _var = '' or _var = '*') return;
  vars := DB.DBA.GQL_CTX_GET (_ctx, 'vars');
  for (i := 0; i < length (vars); i := i + 1)
    { if (aref (vars, i) = _var) return; }
  vars := vector_concat (vars, vector (_var));
  DB.DBA.GQL_CTX_SET (_ctx, 'vars', vars);
}
;

create procedure DB.DBA.GQL_CTX_ADD_ALIAS (inout _ctx any, in _var varchar, in _sparql_var varchar)
{
  declare aliases any;
  declare i integer;
  if (_var is null or _var = '' or _sparql_var is null or _sparql_var = '')
    return;
  aliases := DB.DBA.GQL_CTX_GET (_ctx, 'alias_bindings');
  for (i := 0; i < length (aliases); i := i + 1)
    {
      if (aref (aref (aliases, i), 0) = _var)
        {
          aset (aliases, i, vector (_var, _sparql_var));
          DB.DBA.GQL_CTX_SET (_ctx, 'alias_bindings', aliases);
          return;
        }
    }
  aliases := vector_concat (aliases, vector (vector (_var, _sparql_var)));
  DB.DBA.GQL_CTX_SET (_ctx, 'alias_bindings', aliases);
}
;

create procedure DB.DBA.GQL_CTX_GET_ALIAS (inout _ctx any, in _var varchar)
{
  declare aliases any;
  declare i integer;
  aliases := DB.DBA.GQL_CTX_GET (_ctx, 'alias_bindings');
  for (i := 0; i < length (aliases); i := i + 1)
    {
      if (aref (aref (aliases, i), 0) = _var)
        return aref (aref (aliases, i), 1);
    }
  return null;
}
;

create procedure DB.DBA.GQL_CTX_ADD_TRIPLE (inout _ctx any, in _s varchar, in _p varchar, in _o varchar)
{
  declare triples varchar;
  triples := DB.DBA.GQL_CTX_GET (_ctx, 'triples');
  triples := concat (triples, '  ', _s, ' ', _p, ' ', _o, ' .\n');
  DB.DBA.GQL_CTX_SET (_ctx, 'triples', triples);
}
;

create procedure DB.DBA.GQL_CTX_ADD_TRIPLE_OPTION (inout _ctx any, in _s varchar, in _p varchar, in _o varchar, in _option varchar)
{
  declare triples varchar;
  triples := DB.DBA.GQL_CTX_GET (_ctx, 'triples');
  triples := concat (triples, '  ', _s, ' ', _p, ' ', _o, ' OPTION (', _option, ') .\n');
  DB.DBA.GQL_CTX_SET (_ctx, 'triples', triples);
}
;

create procedure DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (inout _ctx any, in _text varchar)
{
  declare triples varchar;
  triples := DB.DBA.GQL_CTX_GET (_ctx, 'triples');
  triples := concat (triples, _text);
  DB.DBA.GQL_CTX_SET (_ctx, 'triples', triples);
}
;

create procedure DB.DBA.GQL_CTX_ADD_TRANSITIVE_SUBQUERY_OPTION (inout _ctx any, in _s varchar, in _p varchar, in _o varchar, in _option varchar)
{
  declare triples varchar;
  triples := DB.DBA.GQL_CTX_GET (_ctx, 'triples');
  triples := concat (triples,
    '  { SELECT ', _s, ' ', _o, ' WHERE { ', _s, ' ', _p, ' ', _o, ' } } OPTION (',
    _option, ') .\n');
  DB.DBA.GQL_CTX_SET (_ctx, 'triples', triples);
}
;

create procedure DB.DBA.GQL_EDGE_COST_PROP_NAME (in _cost_expr any, in _edge_var varchar)
{
  declare base any;
  if (_cost_expr is null)
    return null;
  if (not isarray (_cost_expr) or aref (_cost_expr, 0) <> 'PROP')
    return null;
  base := aref (_cost_expr, 1);
  if (not isarray (base) or aref (base, 0) <> 'VAR')
    return null;
  if (_edge_var is not null and aref (base, 1) <> _edge_var)
    return null;
  return aref (_cost_expr, 2);
}
;

create procedure DB.DBA.GQL_CTX_ADD_TRANSITIVE_WEIGHTED_SUBQUERY_OPTION
  (inout _ctx any, in _s varchar, in _p varchar, in _o varchar,
   in _cost_prop varchar, in _cost_var varchar, in _option varchar)
{
  declare triples varchar;
  declare edge_stmt, edge_cost_raw varchar;

  triples := DB.DBA.GQL_CTX_GET (_ctx, 'triples');
  edge_stmt := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'edge_stmt_');
  edge_cost_raw := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'edge_cost_raw_');

  triples := concat (triples,
    '  { SELECT ', _s, ' ', _o, ' ', _cost_var, ' WHERE {\n',
    '      ', _s, ' ', _p, ' ', _o, ' .\n',
    '      OPTIONAL {\n',
    '        ', edge_stmt, ' <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> ', _s, ' .\n',
    '        ', edge_stmt, ' <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> ', _p, ' .\n',
    '        ', edge_stmt, ' <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> ', _o, ' .\n',
    '        ', edge_stmt, ' ', DB.DBA.GQL_GEN_PROP_IRI_CTX (_cost_prop, _ctx), ' ', edge_cost_raw, ' .\n',
    '      }\n',
    '      BIND (COALESCE(', edge_cost_raw, ', 1) AS ', _cost_var, ')\n',
    '    } } OPTION (', _option, ') .\n');
  DB.DBA.GQL_CTX_SET (_ctx, 'triples', triples);
}
;

create procedure DB.DBA.GQL_EXPR_LITERAL_STRING (in _expr any)
{
  if (_expr is null or not isarray (_expr))
    return null;
  if (aref (_expr, 0) = 'LIT')
    return cast (aref (_expr, 1) as varchar);
  if (aref (_expr, 0) = 'VAR')
    return cast (aref (_expr, 1) as varchar);
  return null;
}
;

create procedure DB.DBA.GQL_EXPR_IS_AGGREGATE (in _expr any)
{
  declare fname varchar;
  if (_expr is null or not isarray (_expr))
    return 0;
  if (aref (_expr, 0) <> 'FUNC' and aref (_expr, 0) <> 'FUNC_DISTINCT')
    return 0;
  fname := lower (cast (aref (_expr, 1) as varchar));
  if (fname = 'count' or fname = 'sum' or fname = 'avg' or fname = 'min' or fname = 'max'
      or fname = 'sample' or fname = 'group_concat' or fname = 'degree_centrality'
      or fname = 'percentile_cont' or fname = 'percentile_disc')
    return 1;
  return 0;
}
;

create procedure DB.DBA.GQL_CENTRALITY_ADD_NODE (inout _dict any, inout _nodes any, in _uri varchar)
{
  declare idx any;
  _uri := trim (_uri);
  if (_uri is null or _uri = '')
    return null;
  idx := dict_get (_dict, _uri, null);
  if (idx is not null)
    return idx - 1;
  idx := length (_nodes);
  _nodes := vector_concat (_nodes, vector (_uri));
  dict_put (_dict, _uri, idx + 1);
  return idx;
}
;

create procedure DB.DBA.GQL_CENTRALITY_GRAPH
  (in _node varchar, in _graph varchar, in _rel varchar, in _direction varchar, in _weight varchar)
{
  declare q, state, msg varchar;
  declare meta, data any;
  declare nodes, edges, ndict any;
  declare i integer;
  declare dir varchar;
  declare target_idx any;

  nodes := vector ();
  edges := vector ();
  ndict := dict_new ();
  target_idx := DB.DBA.GQL_CENTRALITY_ADD_NODE (ndict, nodes, _node);

  dir := lower (coalesce (_direction, 'in'));
  if (dir = 'undirected')
    dir := 'both';
  if (dir <> 'in' and dir <> 'out' and dir <> 'both')
    dir := 'in';

  if (_rel is not null and _rel <> '')
    {
      if (_weight is not null and _weight <> '')
        q := 'sparql select (str(?s)) (str(?o)) ?w where { graph `iri(??)` { ?s `iri(??)` ?o . optional { ?stmt rdf:subject ?s ; rdf:predicate `iri(??)` ; rdf:object ?o ; `iri(??)` ?w } filter (isIRI(?s) && isIRI(?o)) } }';
      else
        q := 'sparql select (str(?s)) (str(?o)) (1.0) where { graph `iri(??)` { ?s `iri(??)` ?o . filter (isIRI(?s) && isIRI(?o)) } }';
    }
  else
    {
      if (_weight is not null and _weight <> '')
        q := 'sparql select (str(?s)) (str(?o)) ?w where { graph `iri(??)` { ?s ?p ?o . optional { ?stmt rdf:subject ?s ; rdf:predicate ?p ; rdf:object ?o ; `iri(??)` ?w } filter (isIRI(?s) && isIRI(?o) && ?p not in (rdf:type, rdf:subject, rdf:predicate, rdf:object)) } }';
      else
        q := 'sparql select (str(?s)) (str(?o)) (1.0) where { graph `iri(??)` { ?s ?p ?o . filter (isIRI(?s) && isIRI(?o) && ?p not in (rdf:type, rdf:subject, rdf:predicate, rdf:object)) } }';
    }

  state := '00000';
  msg := '';
  if (_rel is not null and _rel <> '' and _weight is not null and _weight <> '')
    exec (q, state, msg, vector (_graph, _rel, _rel, _weight), 0, meta, data);
  else if (_rel is not null and _rel <> '')
    exec (q, state, msg, vector (_graph, _rel), 0, meta, data);
  else if (_weight is not null and _weight <> '')
    exec (q, state, msg, vector (_graph, _weight), 0, meta, data);
  else
    exec (q, state, msg, vector (_graph), 0, meta, data);

  if (state <> '00000')
    signal (state, msg);

  for (i := 0; i < length (data); i := i + 1)
    {
      declare s, o varchar;
      declare w any;
      declare si, oi any;
      declare wt double precision;
      s := cast (aref (aref (data, i), 0) as varchar);
      o := cast (aref (aref (data, i), 1) as varchar);
      w := aref (aref (data, i), 2);
      wt := 1.0;
      if (w is not null)
        wt := cast (w as double precision);
      if (wt < 0.0)
        wt := 0.0;
      si := DB.DBA.GQL_CENTRALITY_ADD_NODE (ndict, nodes, s);
      oi := DB.DBA.GQL_CENTRALITY_ADD_NODE (ndict, nodes, o);
      if (dir = 'out' or dir = 'both')
        edges := vector_concat (edges, vector (vector (si, oi, wt)));
      if (dir = 'in' or dir = 'both')
        edges := vector_concat (edges, vector (vector (oi, si, wt)));
    }

  target_idx := dict_get (ndict, _node, null);
  if (target_idx is not null)
    target_idx := target_idx - 1;
  return vector (nodes, edges, target_idx);
}
;

create procedure DB.DBA.GQL_CENTRALITY_SHORTEST (in _source integer, in _nodes any, in _edges any)
{
  declare n, i, ei, changed integer;
  declare inf double precision;
  declare dist, sigma, delta any;

  n := length (_nodes);
  inf := 1.0e308;
  dist := make_array (n, 'double');
  sigma := make_array (n, 'double');
  delta := make_array (n, 'double');
  for (i := 0; i < n; i := i + 1)
    {
      aset (dist, i, inf);
      aset (sigma, i, 0.0);
      aset (delta, i, 0.0);
    }
  aset (dist, _source, 0.0);
  aset (sigma, _source, 1.0);

  changed := 1;
  while (changed)
    {
      changed := 0;
      for (ei := 0; ei < length (_edges); ei := ei + 1)
        {
          declare e any;
          declare u, v integer;
          declare w, nd double precision;
          e := aref (_edges, ei);
          u := aref (e, 0);
          v := aref (e, 1);
          w := aref (e, 2);
          if (w <= 0.0) w := 1.0;
          if (aref (dist, u) < inf)
            {
              nd := aref (dist, u) + w;
              if (nd + 1.0e-9 < aref (dist, v))
                {
                  aset (dist, v, nd);
                  changed := 1;
                }
            }
        }
    }

  aset (sigma, _source, 1.0);
  changed := 0;
  while (changed)
    {
      changed := 0;
      for (ei := 0; ei < length (_edges); ei := ei + 1)
        {
          declare e2 any;
          declare u2, v2 integer;
          declare w2 double precision;
          e2 := aref (_edges, ei);
          u2 := aref (e2, 0);
          v2 := aref (e2, 1);
          w2 := aref (e2, 2);
          if (w2 <= 0.0) w2 := 1.0;
          if (abs ((aref (dist, u2) + w2) - aref (dist, v2)) < 1.0e-9
              and aref (dist, u2) < aref (dist, v2)
              and aref (sigma, u2) > 0.0)
            {
              declare ns double precision;
              ns := aref (sigma, v2) + aref (sigma, u2);
              if (ns > aref (sigma, v2) + 1.0e-9)
                { aset (sigma, v2, ns); changed := 1; }
            }
        }
    }

  return vector (dist, sigma, delta);
}
;

create procedure DB.DBA.GQL_GRAPH_CENTRALITY
  (in _node varchar, in _graph varchar, in _rel varchar := null, in _direction varchar := 'in',
   in _weight varchar := null, in _metric varchar := 'closeness')
{
  declare g, nodes, edges, sp, dist, sigma, delta any;
  declare n, target, i, ei, iter integer;
  declare metric varchar;
  declare inf, sumd, reachable, score, norm double precision;

  g := DB.DBA.GQL_CENTRALITY_GRAPH (_node, _graph, _rel, _direction, _weight);
  nodes := aref (g, 0);
  edges := aref (g, 1);
  target := aref (g, 2);
  if (target is null)
    return 0.0;
  n := length (nodes);
  if (n <= 1)
    return 0.0;

  metric := lower (coalesce (_metric, 'closeness'));
  inf := 1.0e308;

  if (metric = 'closeness')
    {
      sp := DB.DBA.GQL_CENTRALITY_SHORTEST (target, nodes, edges);
      dist := aref (sp, 0);
      sumd := 0.0;
      reachable := 0.0;
      for (i := 0; i < n; i := i + 1)
        {
          if (i <> target and aref (dist, i) < inf / 2.0)
            {
              sumd := sumd + aref (dist, i);
              reachable := reachable + 1.0;
            }
        }
      if (sumd <= 0.0)
        return 0.0;
      return reachable / sumd;
    }

  if (metric = 'eigenvector')
    {
      declare scores, next_scores any;
      scores := make_array (n, 'double');
      next_scores := make_array (n, 'double');
      for (i := 0; i < n; i := i + 1)
        aset (scores, i, 1.0 / cast (n as double precision));
      for (iter := 0; iter < 50; iter := iter + 1)
        {
          norm := 0.0;
          for (i := 0; i < n; i := i + 1)
            aset (next_scores, i, 0.0);
          for (ei := 0; ei < length (edges); ei := ei + 1)
            {
              declare e any;
              declare u, v integer;
              declare w double precision;
              e := aref (edges, ei);
              u := aref (e, 0);
              v := aref (e, 1);
              w := aref (e, 2);
              if (w <= 0.0) w := 1.0;
              aset (next_scores, v, aref (next_scores, v) + (aref (scores, u) * w));
            }
          for (i := 0; i < n; i := i + 1)
            norm := norm + (aref (next_scores, i) * aref (next_scores, i));
          norm := sqrt (norm);
          if (norm <= 0.0)
            return 0.0;
          for (i := 0; i < n; i := i + 1)
            aset (scores, i, aref (next_scores, i) / norm);
        }
      return aref (scores, target);
    }

  if (metric = 'betweenness')
    {
      score := 0.0;
      declare target_sp, target_dist any;
      target_sp := DB.DBA.GQL_CENTRALITY_SHORTEST (target, nodes, edges);
      target_dist := aref (target_sp, 0);
      for (i := 0; i < n; i := i + 1)
        {
          declare s integer;
          s := i;
          if (s = target)
            goto between_next_source;
          sp := DB.DBA.GQL_CENTRALITY_SHORTEST (s, nodes, edges);
          dist := aref (sp, 0);
          for (declare t integer, t := 0; t < n; t := t + 1)
            {
              if (t = s or t = target or aref (dist, t) >= inf / 2.0)
                goto between_next_target;
              if (aref (dist, target) < inf / 2.0
                  and aref (target_dist, t) < inf / 2.0
                  and abs ((aref (dist, target) + aref (target_dist, t)) - aref (dist, t)) < 1.0e-9)
                score := score + 1.0;
            between_next_target:;
            }
        between_next_source:;
        }
      return score;
    }

  signal ('G3102', sprintf ('Unsupported centrality metric: %s', metric));
}
;

create procedure DB.DBA.GQL_DEGREE_GRAPH_EXPR (in _expr any, inout _ctx any)
{
  declare iri_uri any;
  if (_expr is null)
    return null;
  if (isarray (_expr) and aref (_expr, 0) = 'IRI')
    {
      iri_uri := DB.DBA.GQL_EXPAND_PREFIXED_NAME (_ctx, aref (_expr, 1));
      if (not isstring (iri_uri))
        iri_uri := aref (_expr, 1);
      return concat ('<', iri_uri, '>');
    }
  if (isarray (_expr) and aref (_expr, 0) = 'LIT')
    return concat ('<', cast (aref (_expr, 1) as varchar), '>');
  return DB.DBA.GQL_GEN_EXPR (_expr, _ctx);
}
;

create procedure DB.DBA.GQL_DEGREE_WEIGHT_PROP (in _expr any, inout _ctx any)
{
  declare prop_name varchar;
  if (_expr is null)
    return null;
  if (isarray (_expr) and aref (_expr, 0) = 'IRI')
    return DB.DBA.GQL_GEN_EXPR (_expr, _ctx);
  prop_name := DB.DBA.GQL_EXPR_LITERAL_STRING (_expr);
  if (prop_name is null or prop_name = '' or lower (prop_name) = 'none')
    return null;
  if (strchr (prop_name, ':') is null)
    return concat ('<', DB.DBA.GQL_NS_CTX (_ctx), prop_name, '>');
  return DB.DBA.GQL_GEN_PROP_IRI_CTX (prop_name, _ctx);
}
;

create procedure DB.DBA.GQL_DEGREE_RELATION_PRED (in _expr any, inout _ctx any)
{
  declare rel_name varchar;
  if (_expr is null)
    return null;
  if (isarray (_expr) and aref (_expr, 0) = 'IRI')
    return DB.DBA.GQL_GEN_EXPR (_expr, _ctx);
  rel_name := DB.DBA.GQL_EXPR_LITERAL_STRING (_expr);
  if (rel_name is null or rel_name = '' or rel_name = '*' or lower (rel_name) = 'any')
    return null;
  return DB.DBA.GQL_GEN_EDGE_TYPE_IRI_CTX (rel_name, _ctx);
}
;

create procedure DB.DBA.GQL_CENTRALITY_GRAPH_URI (in _expr any, inout _ctx any)
{
  declare val any;
  if (_expr is null)
    return DB.DBA.GQL_CTX_GET (_ctx, 'graph');
  if (isarray (_expr) and aref (_expr, 0) = 'IRI')
    {
      val := DB.DBA.GQL_EXPAND_PREFIXED_NAME (_ctx, aref (_expr, 1));
      if (isstring (val))
        return val;
      return aref (_expr, 1);
    }
  if (isarray (_expr) and aref (_expr, 0) = 'LIT')
    return cast (aref (_expr, 1) as varchar);
  return DB.DBA.GQL_CTX_GET (_ctx, 'graph');
}
;

create procedure DB.DBA.GQL_CENTRALITY_REL_URI (in _expr any, inout _ctx any)
{
  declare rel_name varchar;
  if (_expr is null)
    return null;
  if (isarray (_expr) and aref (_expr, 0) = 'IRI')
    {
      declare val any;
      val := DB.DBA.GQL_EXPAND_PREFIXED_NAME (_ctx, aref (_expr, 1));
      if (isstring (val))
        return val;
      return aref (_expr, 1);
    }
  rel_name := DB.DBA.GQL_EXPR_LITERAL_STRING (_expr);
  if (rel_name is null or rel_name = '' or rel_name = '*' or lower (rel_name) = 'any')
    return null;
  return DB.DBA.GQL_TERM_URI (_ctx, rel_name, 'edge');
}
;

create procedure DB.DBA.GQL_CENTRALITY_WEIGHT_URI (in _expr any, inout _ctx any)
{
  declare prop_name varchar;
  if (_expr is null)
    return null;
  if (isarray (_expr) and aref (_expr, 0) = 'IRI')
    {
      declare val any;
      val := DB.DBA.GQL_EXPAND_PREFIXED_NAME (_ctx, aref (_expr, 1));
      if (isstring (val))
        return val;
      return aref (_expr, 1);
    }
  prop_name := DB.DBA.GQL_EXPR_LITERAL_STRING (_expr);
  if (prop_name is null or prop_name = '' or lower (prop_name) = 'none')
    return null;
  if (strchr (prop_name, ':') is null)
    return concat (DB.DBA.GQL_NS_CTX (_ctx), prop_name);
  return DB.DBA.GQL_TERM_URI (_ctx, prop_name, 'prop');
}
;

create procedure DB.DBA.GQL_GEN_GRAPH_CENTRALITY_EXPR (in _args any, inout _ctx any, in _metric varchar)
{
  declare node_expr any;
  declare node_s, dir, rel_uri, weight_uri, graph_uri varchar;

  if (length (_args) < 1)
    signal ('G3100', sprintf ('%s_centrality requires a node expression', _metric));

  node_expr := aref (_args, 0);
  node_s := DB.DBA.GQL_GEN_EXPR (node_expr, _ctx);
  dir := 'in';
  if (length (_args) > 1)
    {
      declare dir_arg varchar;
      dir_arg := lower (DB.DBA.GQL_EXPR_LITERAL_STRING (aref (_args, 1)));
      if (dir_arg is not null and dir_arg <> '')
        dir := dir_arg;
    }
  if (dir = 'undirected')
    dir := 'both';
  if (dir <> 'both' and dir <> 'out' and dir <> 'in')
    signal ('G3101', sprintf ('%s_centrality direction must be "in", "out", "both", or "undirected"', _metric));

  rel_uri := null;
  weight_uri := null;
  graph_uri := DB.DBA.GQL_CTX_GET (_ctx, 'graph');
  if (length (_args) > 2)
    {
      if (length (_args) = 4
          and isarray (aref (_args, 3)) and aref (aref (_args, 3), 0) = 'IRI'
          and isarray (aref (_args, 2)) and aref (aref (_args, 2), 0) <> 'IRI')
        {
          weight_uri := DB.DBA.GQL_CENTRALITY_WEIGHT_URI (aref (_args, 2), _ctx);
          graph_uri := DB.DBA.GQL_CENTRALITY_GRAPH_URI (aref (_args, 3), _ctx);
        }
      else
        {
          rel_uri := DB.DBA.GQL_CENTRALITY_REL_URI (aref (_args, 2), _ctx);
          if (length (_args) > 3)
            weight_uri := DB.DBA.GQL_CENTRALITY_WEIGHT_URI (aref (_args, 3), _ctx);
          if (length (_args) > 4)
            graph_uri := DB.DBA.GQL_CENTRALITY_GRAPH_URI (aref (_args, 4), _ctx);
        }
    }

  return concat ('sql:GQL_GRAPH_CENTRALITY(CONCAT("", STR(', node_s, ')), ',
    DB.DBA.GQL_GEN_LITERAL (graph_uri), ', ',
    case when rel_uri is null then DB.DBA.GQL_GEN_LITERAL ('') else DB.DBA.GQL_GEN_LITERAL (rel_uri) end, ', ',
    DB.DBA.GQL_GEN_LITERAL (dir), ', ',
    case when weight_uri is null then DB.DBA.GQL_GEN_LITERAL ('') else DB.DBA.GQL_GEN_LITERAL (weight_uri) end, ', ',
    DB.DBA.GQL_GEN_LITERAL (_metric), ')');
}
;

create procedure DB.DBA.GQL_CTX_ADD_DEGREE_BRANCH
  (inout _ctx any, in _node varchar, in _direction varchar, in _rel_pred varchar, in _weight_prop varchar,
   in _edge_id_var varchar, in _weight_var varchar, in _indent varchar)
{
  declare nbr, pred, stmt, raw_weight varchar;
  declare branch varchar;

  nbr := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'deg_nbr_');
  if (_rel_pred is not null and _rel_pred <> '')
    pred := _rel_pred;
  else
    pred := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'deg_p_');

  if (_weight_prop is not null)
    {
      stmt := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'deg_stmt_');
      raw_weight := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'deg_weight_raw_');
    }

  -- Only the patterns go in the OPTIONAL: the edge's id and weight are bound
  -- after it, by the caller, on the neighbour being bound.  (A BIND inside
  -- the OPTIONAL is computed for a node with no edge too, on the empty row:
  -- CONCAT of unbound values is "out||", counted as an edge.)
  declare edge_expr, weight_expr varchar;
  if (_direction = 'in')
    {
      branch := concat (_indent, nbr, ' ', pred, ' ', _node, ' .\n');
      edge_expr := concat ('CONCAT("in|", STR(', nbr, '), "|", STR(', pred, '))');
    }
  else
    {
      branch := concat (_indent, _node, ' ', pred, ' ', nbr, ' .\n');
      edge_expr := concat ('CONCAT("out|", STR(', pred, '), "|", STR(', nbr, '))');
    }

  if (_rel_pred is null or _rel_pred = '')
    branch := concat (branch, _indent, 'FILTER (isIRI(', nbr, ') && ', pred,
      ' NOT IN (rdf:type, rdf:subject, rdf:predicate, rdf:object))\n');

  if (_weight_prop is not null)
    {
      if (_direction = 'in')
        branch := concat (branch,
          _indent, 'OPTIONAL {\n',
          _indent, '  ', stmt, ' <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> ', nbr, ' .\n',
          _indent, '  ', stmt, ' <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> ', pred, ' .\n',
          _indent, '  ', stmt, ' <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> ', _node, ' .\n',
          _indent, '  ', stmt, ' ', _weight_prop, ' ', raw_weight, ' .\n',
          _indent, '}\n');
      else
        branch := concat (branch,
          _indent, 'OPTIONAL {\n',
          _indent, '  ', stmt, ' <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> ', _node, ' .\n',
          _indent, '  ', stmt, ' <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> ', pred, ' .\n',
          _indent, '  ', stmt, ' <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> ', nbr, ' .\n',
          _indent, '  ', stmt, ' ', _weight_prop, ' ', raw_weight, ' .\n',
          _indent, '}\n');
      weight_expr := concat ('COALESCE(', raw_weight, ', 1)');
    }
  else
    weight_expr := '1';

  DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx, branch);
  return vector (nbr, edge_expr, weight_expr);
}
;

create procedure DB.DBA.GQL_GEN_DEGREE_CENTRALITY (in _args any, inout _ctx any)
{
  declare node_expr any;
  declare node_var, dir, rel_pred, weight_prop, graph_expr varchar;
  declare edge_id_var, weight_var varchar;
  declare saved_triples, degree_body varchar;

  if (length (_args) < 1)
    signal ('G3100', 'degree_centrality requires a node expression');

  node_expr := aref (_args, 0);
  node_var := DB.DBA.GQL_GEN_EXPR (node_expr, _ctx);

  dir := 'in';
  if (length (_args) > 1)
    {
      declare dir_arg varchar;
      dir_arg := lower (DB.DBA.GQL_EXPR_LITERAL_STRING (aref (_args, 1)));
      if (dir_arg is not null and dir_arg <> '')
        dir := dir_arg;
    }
  if (dir = 'undirected')
    dir := 'both';
  if (dir <> 'both' and dir <> 'out' and dir <> 'in')
    signal ('G3101', 'degree_centrality direction must be "in", "out", "both", or "undirected"');

  rel_pred := null;
  weight_prop := null;
  graph_expr := null;
  if (length (_args) > 2)
    {
      -- Preferred form:
      --   degree_centrality(n, direction, relationship, weight, graph)
      -- Backward-compatible form kept for the previous preview:
      --   degree_centrality(n, direction, weight, graph)
      if (length (_args) = 4
          and isarray (aref (_args, 3)) and aref (aref (_args, 3), 0) = 'IRI'
          and isarray (aref (_args, 2)) and aref (aref (_args, 2), 0) <> 'IRI')
        {
          weight_prop := DB.DBA.GQL_DEGREE_WEIGHT_PROP (aref (_args, 2), _ctx);
          graph_expr := DB.DBA.GQL_DEGREE_GRAPH_EXPR (aref (_args, 3), _ctx);
        }
      else
        {
          rel_pred := DB.DBA.GQL_DEGREE_RELATION_PRED (aref (_args, 2), _ctx);
          if (length (_args) > 3)
            weight_prop := DB.DBA.GQL_DEGREE_WEIGHT_PROP (aref (_args, 3), _ctx);
          if (length (_args) > 4)
            graph_expr := DB.DBA.GQL_DEGREE_GRAPH_EXPR (aref (_args, 4), _ctx);
        }
    }
  if (graph_expr is not null and length (graph_expr) > 2
      and subseq (graph_expr, 0, 1) = '<' and subseq (graph_expr, length (graph_expr) - 1) = '>')
    {
      declare extras any;
      declare graph_uri varchar;
      graph_uri := subseq (graph_expr, 1, length (graph_expr) - 1);
      extras := DB.DBA.GQL_CTX_GET (_ctx, 'extra_from_graphs');
      extras := vector_concat (extras, vector (vector ('FROM_NAMED', graph_uri)));
      DB.DBA.GQL_CTX_SET (_ctx, 'extra_from_graphs', extras);
    }

  edge_id_var := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'deg_edge_');
  weight_var := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'deg_weight_');

  saved_triples := DB.DBA.GQL_CTX_GET (_ctx, 'triples');
  DB.DBA.GQL_CTX_SET (_ctx, 'triples', '');

  declare br1, br2 any;
  declare edge_bind, weight_bind varchar;
  br2 := null;
  if (dir = 'out')
    br1 := DB.DBA.GQL_CTX_ADD_DEGREE_BRANCH (_ctx, node_var, 'out', rel_pred, weight_prop, edge_id_var, weight_var, '    ');
  else if (dir = 'in')
    br1 := DB.DBA.GQL_CTX_ADD_DEGREE_BRANCH (_ctx, node_var, 'in', rel_pred, weight_prop, edge_id_var, weight_var, '    ');
  else
    {
      DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx, '    {\n');
      br1 := DB.DBA.GQL_CTX_ADD_DEGREE_BRANCH (_ctx, node_var, 'out', rel_pred, weight_prop, edge_id_var, weight_var, '      ');
      DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx, '    } UNION {\n');
      br2 := DB.DBA.GQL_CTX_ADD_DEGREE_BRANCH (_ctx, node_var, 'in', rel_pred, weight_prop, edge_id_var, weight_var, '      ');
      DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx, '    }\n');
    }
  -- The edge's id and weight where a branch bound a neighbour; unbound (the
  -- first neighbour variable, unbound there) where none did.
  if (br2 is null)
    {
      edge_bind := concat ('IF(BOUND(', aref (br1, 0), '), ', aref (br1, 1), ', ', aref (br1, 0), ')');
      weight_bind := concat ('IF(BOUND(', aref (br1, 0), '), ', aref (br1, 2), ', ', aref (br1, 0), ')');
    }
  else
    {
      edge_bind := concat ('IF(BOUND(', aref (br1, 0), '), ', aref (br1, 1), ', IF(BOUND(', aref (br2, 0), '), ',
        aref (br2, 1), ', ', aref (br1, 0), '))');
      weight_bind := concat ('IF(BOUND(', aref (br1, 0), '), ', aref (br1, 2), ', IF(BOUND(', aref (br2, 0), '), ',
        aref (br2, 2), ', ', aref (br1, 0), '))');
    }

  degree_body := DB.DBA.GQL_CTX_GET (_ctx, 'triples');
  DB.DBA.GQL_CTX_SET (_ctx, 'triples', saved_triples);

  if (graph_expr is not null and graph_expr <> '')
    degree_body := concat ('    GRAPH ', graph_expr, ' {\n', degree_body, '    }\n');

  DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx, concat ('  OPTIONAL {\n', degree_body, '  }\n',
    '  BIND (', edge_bind, ' AS ', edge_id_var, ')\n',
    '  BIND (', weight_bind, ' AS ', weight_var, ')\n'));
  DB.DBA.GQL_CTX_SET (_ctx, 'needs_auto_group', 1);

  if (weight_prop is not null)
    return concat ('COALESCE(SUM(', weight_var, '), 0)');
  return concat ('COUNT(DISTINCT ', edge_id_var, ')');
}
;

create procedure DB.DBA.GQL_CTX_ADD_FILTER (inout _ctx any, in _filter varchar)
{
  declare filters varchar;
  filters := DB.DBA.GQL_CTX_GET (_ctx, 'filters');
  filters := concat (filters, '  FILTER (', _filter, ')\n');
  DB.DBA.GQL_CTX_SET (_ctx, 'filters', filters);
}
;

-- 1 when _s, translated SPARQL, can stand in a triple pattern as an object:
-- a variable, an IRI, a literal, a number or a boolean.  A function call or
-- an operator expression has a '(' or a space outside its literals and
-- IRIs.
create procedure DB.DBA.GQL_SPARQL_IS_PATTERN_OBJECT (in _s varchar)
{
  declare n, i, c integer;
  _s := trim (_s);
  n := length (_s);
  if (n = 0)
    return 0;
  i := 0;
  while (i < n)
    {
      c := aref (_s, i);
      if (c = 34 or c = 39)
        {
          declare q integer;
          q := c;
          i := i + 1;
          while (i < n and aref (_s, i) <> q)
            i := i + case when aref (_s, i) = 92 then 2 else 1 end;
        }
      else if (c = 60)
        {
          while (i < n and aref (_s, i) <> 62)
            i := i + 1;
        }
      else if (c = 40 or c = 32)
        return 0;
      i := i + 1;
    }
  return 1;
}
;

-- The object of a property in a pattern's property map: the value itself
-- when a triple pattern can hold it, else a fresh variable that a FILTER
-- compares with the value, as {k: f (x)} means n.k = f (x).
create procedure DB.DBA.GQL_CTX_PATTERN_PROP_VALUE (inout _ctx any, in _val varchar)
{
  declare pv varchar;
  if (DB.DBA.GQL_SPARQL_IS_PATTERN_OBJECT (_val))
    return _val;
  pv := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'pmap_');
  DB.DBA.GQL_CTX_ADD_FILTER (_ctx, concat (pv, ' = ', _val));
  return pv;
}
;

create procedure DB.DBA.GQL_CTX_ADD_BIND (inout _ctx any, in _var varchar, in _expr varchar)
{
  declare binds varchar;
  binds := DB.DBA.GQL_CTX_GET (_ctx, 'binds');
  binds := concat (binds, '  BIND (', _expr, ' AS ', _var, ')\n');
  DB.DBA.GQL_CTX_SET (_ctx, 'binds', binds);
}
;

create procedure DB.DBA.GQL_CTX_ADD_PRE_BIND_ONCE (inout _ctx any, in _var varchar, in _expr varchar)
{
  declare binds varchar;
  binds := DB.DBA.GQL_CTX_GET (_ctx, 'pre_binds');
  if (strstr (binds, concat (' AS ', _var, ')')) is not null)
    return;
  binds := concat (binds, '  BIND (', _expr, ' AS ', _var, ')\n');
  DB.DBA.GQL_CTX_SET (_ctx, 'pre_binds', binds);
}
;

create procedure DB.DBA.GQL_CTX_ADD_PRE_VALUE_ONCE (inout _ctx any, in _var varchar, in _expr varchar)
{
  declare values_text varchar;
  values_text := DB.DBA.GQL_CTX_GET (_ctx, 'pre_values');
  if (strstr (values_text, concat ('VALUES ', _var, ' ')) is not null)
    return;
  values_text := concat (values_text, '  VALUES ', _var, ' { ', _expr, ' }\n');
  DB.DBA.GQL_CTX_SET (_ctx, 'pre_values', values_text);
}
;

create procedure DB.DBA.GQL_CTX_ADD_BIND_ONCE (inout _ctx any, in _var varchar, in _expr varchar)
{
  declare binds varchar;
  binds := DB.DBA.GQL_CTX_GET (_ctx, 'binds');
  if (strstr (binds, concat (' AS ', _var, ')')) is not null)
    return;
  DB.DBA.GQL_CTX_ADD_BIND (_ctx, _var, _expr);
}
;

create procedure DB.DBA.GQL_PATH_FIELD_VAR (in _pvar varchar, in _field varchar)
{
  if (_field = 'path')
    return concat ('?gql_p_', _pvar);
  if (_field = 'id')
    return concat ('?gql_p_', _pvar, '_id');
  if (_field = 'step')
    return concat ('?gql_p_', _pvar, '_step');
  if (_field = 'step_value')
    return concat ('?gql_p_', _pvar, '_step_value');
  if (_field = 'index')
    return concat ('?gql_p_', _pvar, '_index');
  if (_field = 'node')
    return concat ('?gql_p_', _pvar, '_node');
  if (_field = 'cost')
    return concat ('?gql_p_', _pvar, '_cost');
  if (_field = 'value')
    return concat ('?gql_p_', _pvar, '_value');
  return null;
}
;

create procedure DB.DBA.GQL_CTX_MATERIALIZE_PATH_STEP (inout _ctx any, in _pvar varchar)
{
  declare path_var, path_id_var, step_var, index_var, node_var, step_value_var varchar;
  if (_pvar is null or _pvar = '')
    return;
  path_var := DB.DBA.GQL_PATH_FIELD_VAR (_pvar, 'path');
  path_id_var := DB.DBA.GQL_PATH_FIELD_VAR (_pvar, 'id');
  step_var := DB.DBA.GQL_PATH_FIELD_VAR (_pvar, 'step');
  index_var := DB.DBA.GQL_PATH_FIELD_VAR (_pvar, 'index');
  node_var := DB.DBA.GQL_PATH_FIELD_VAR (_pvar, 'node');
  step_value_var := DB.DBA.GQL_PATH_FIELD_VAR (_pvar, 'step_value');
  DB.DBA.GQL_CTX_ADD_BIND_ONCE (_ctx, path_var,
    concat ('IRI(CONCAT("', DB.DBA.GQL_DATA_NS_CTX (_ctx), 'path_", ENCODE_FOR_URI(STR(', path_id_var, '))))'));
  DB.DBA.GQL_CTX_ADD_BIND_ONCE (_ctx, step_var,
    concat ('IRI(CONCAT("', DB.DBA.GQL_DATA_NS_CTX (_ctx), 'pathstep_", ENCODE_FOR_URI(STR(', path_id_var, ')), "_", STR(', index_var, ')))'));
  DB.DBA.GQL_CTX_ADD_BIND_ONCE (_ctx, step_value_var,
    concat ('CONCAT(STR(', index_var, '), ": ", STR(', node_var, '))'));
}
;

create procedure DB.DBA.GQL_CTX_MATERIALIZE_EXACT_PATH (inout _ctx any, in _pvar varchar, in _src varchar, in _pred varchar, in _dst varchar)
{
  declare path_var, path_id_var, step_var, step_value_var, index_var, node_var, value_var varchar;
  declare path_id_expr, path_expr, value_expr varchar;
  if (_pvar is null or _pvar = '')
    return;

  path_var := DB.DBA.GQL_PATH_FIELD_VAR (_pvar, 'path');
  path_id_var := DB.DBA.GQL_PATH_FIELD_VAR (_pvar, 'id');
  step_var := DB.DBA.GQL_PATH_FIELD_VAR (_pvar, 'step');
  step_value_var := DB.DBA.GQL_PATH_FIELD_VAR (_pvar, 'step_value');
  index_var := DB.DBA.GQL_PATH_FIELD_VAR (_pvar, 'index');
  node_var := DB.DBA.GQL_PATH_FIELD_VAR (_pvar, 'node');
  value_var := DB.DBA.GQL_PATH_FIELD_VAR (_pvar, 'value');

  path_id_expr := concat ('CONCAT("exact|", STR(', _src, '), "|', replace (_pred, '"', '\\"'), '|", STR(', _dst, '))');
  path_expr := concat ('IRI(CONCAT("', DB.DBA.GQL_DATA_NS_CTX (_ctx), 'path_", ENCODE_FOR_URI(STR(', path_id_var, '))))');
  value_expr := concat ('CONCAT(STR(', _src, '), " -> ", STR(', _dst, '))');

  DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx,
    concat ('  {\n',
            '    ', _src, ' ', _pred, ' ', _dst, ' .\n',
            '    BIND (', path_id_expr, ' AS ', path_id_var, ')\n',
            '    BIND (0 AS ', index_var, ')\n',
            '    BIND (', path_expr, ' AS ', path_var, ')\n',
            '    BIND (IRI(CONCAT("', DB.DBA.GQL_DATA_NS_CTX (_ctx), 'pathstep_", ENCODE_FOR_URI(STR(', path_id_var, ')), "_", STR(', index_var, '))) AS ', step_var, ')\n',
            '    BIND (', _src, ' AS ', node_var, ')\n',
            '    BIND (CONCAT(STR(', index_var, '), ": ", STR(', node_var, ')) AS ', step_value_var, ')\n',
            '    BIND (', value_expr, ' AS ', value_var, ')\n',
            '  } UNION {\n',
            '    ', _src, ' ', _pred, ' ', _dst, ' .\n',
            '    BIND (', path_id_expr, ' AS ', path_id_var, ')\n',
            '    BIND (1 AS ', index_var, ')\n',
            '    BIND (', path_expr, ' AS ', path_var, ')\n',
            '    BIND (IRI(CONCAT("', DB.DBA.GQL_DATA_NS_CTX (_ctx), 'pathstep_", ENCODE_FOR_URI(STR(', path_id_var, ')), "_", STR(', index_var, '))) AS ', step_var, ')\n',
            '    BIND (', _dst, ' AS ', node_var, ')\n',
            '    BIND (CONCAT(STR(', index_var, '), ": ", STR(', node_var, ')) AS ', step_value_var, ')\n',
            '    BIND (', value_expr, ' AS ', value_var, ')\n',
            '  }\n'));
}
;

create procedure DB.DBA.GQL_CTX_ADD_VALUES (inout _ctx any, in _var varchar, in _values varchar)
{
  declare values_text varchar;
  values_text := DB.DBA.GQL_CTX_GET (_ctx, 'values');
  values_text := concat (values_text, '  VALUES ', _var, ' { ', _values, ' }\n');
  DB.DBA.GQL_CTX_SET (_ctx, 'values', values_text);
}
;

create procedure DB.DBA.GQL_CTX_GET_PROP_VAR (inout _ctx any, in _subj varchar, in _prop varchar)
{
  declare cache any;
  declare i integer;
  cache := DB.DBA.GQL_CTX_GET (_ctx, 'prop_cache');
  for (i := 0; i < length (cache); i := i + 1)
    {
      if (aref (aref (cache, i), 0) = _subj and aref (aref (cache, i), 1) = _prop)
        return aref (aref (cache, i), 2);
    }
  return null;
}
;

create procedure DB.DBA.GQL_CTX_ADD_PROP_VAR (inout _ctx any, in _subj varchar, in _prop varchar, in _var varchar)
{
  declare cache any;
  cache := DB.DBA.GQL_CTX_GET (_ctx, 'prop_cache');
  cache := vector_concat (cache, vector (vector (_subj, _prop, _var)));
  DB.DBA.GQL_CTX_SET (_ctx, 'prop_cache', cache);
}
;

create procedure DB.DBA.GQL_CTX_MERGE_PROP_CACHE (inout _ctx any, in _from_ctx any)
{
  declare src_cache, dst_cache any;
  declare src_entry any;
  declare found_flag integer;
  declare i, j integer;

  src_cache := DB.DBA.GQL_CTX_GET (_from_ctx, 'prop_cache');
  dst_cache := DB.DBA.GQL_CTX_GET (_ctx, 'prop_cache');
  for (i := 0; i < length (src_cache); i := i + 1)
    {
      src_entry := aref (src_cache, i);
      found_flag := 0;
      for (j := 0; j < length (dst_cache); j := j + 1)
        {
          if (aref (aref (dst_cache, j), 0) = aref (src_entry, 0)
              and aref (aref (dst_cache, j), 1) = aref (src_entry, 1))
            { found_flag := 1; goto next_src_prop; }
        }
    next_src_prop:
      if (not found_flag)
        dst_cache := vector_concat (dst_cache, vector (src_entry));
    }
  DB.DBA.GQL_CTX_SET (_ctx, 'prop_cache', dst_cache);
}
;

create procedure DB.DBA.GQL_CTX_ADD_EDGE_BINDING (inout _ctx any, in _edge_var varchar, in _subj varchar, in _pred varchar, in _obj varchar)
{
  declare bindings any;
  declare i integer;

  if (_edge_var is null or _edge_var = '' or _subj is null or _pred is null or _obj is null)
    return;

  bindings := DB.DBA.GQL_CTX_GET (_ctx, 'edge_bindings');
  for (i := 0; i < length (bindings); i := i + 1)
    {
      if (aref (aref (bindings, i), 0) = _edge_var
          and aref (aref (bindings, i), 1) = _subj
          and aref (aref (bindings, i), 2) = _pred
          and aref (aref (bindings, i), 3) = _obj)
        return;
    }
  bindings := vector_concat (bindings, vector (vector (_edge_var, _subj, _pred, _obj)));
  DB.DBA.GQL_CTX_SET (_ctx, 'edge_bindings', bindings);
}
;

-- The subject and object of the stored edge that a named single
-- (unquantified) edge pattern binds, which IS SOURCE OF and IS DESTINATION
-- OF compare with, and its predicate -- an IRI, a variable, or null for an
-- edge of more than one type -- which DELETE of the edge deletes.
create procedure DB.DBA.GQL_CTX_ADD_EDGE_ENDS (inout _ctx any, in _edge_var varchar, in _subj varchar, in _obj varchar, in _pred varchar)
{
  declare ends any;

  if (_edge_var is null or _edge_var = '' or _subj is null or _obj is null)
    return;
  ends := DB.DBA.GQL_CTX_GET (_ctx, 'edge_ends');
  if (ends is null)
    ends := vector ();
  ends := vector_concat (ends, vector (vector (_edge_var, _subj, _obj, _pred)));
  DB.DBA.GQL_CTX_SET (_ctx, 'edge_ends', ends);
}
;

-- The subject (_which 1), object (2) or predicate (3) of the stored edge
-- _edge_var denotes; null when it is not the variable of a single edge.
create procedure DB.DBA.GQL_CTX_EDGE_END (inout _ctx any, in _edge_var varchar, in _which integer)
{
  declare ends any;
  declare i integer;

  ends := DB.DBA.GQL_CTX_GET (_ctx, 'edge_ends');
  for (i := 0; i < length (ends); i := i + 1)
    {
      if (aref (aref (ends, i), 0) = _edge_var)
        return aref (aref (ends, i), _which);
    }
  return null;
}
;

create procedure DB.DBA.GQL_CTX_HAS_EDGE_BINDING (inout _ctx any, in _edge_var varchar)
{
  declare bindings any;
  declare i integer;

  bindings := DB.DBA.GQL_CTX_GET (_ctx, 'edge_bindings');
  for (i := 0; i < length (bindings); i := i + 1)
    {
      if (aref (aref (bindings, i), 0) = _edge_var)
        return 1;
    }
  return 0;
}
;

create procedure DB.DBA.GQL_CTX_EDGE_REIF_DONE (inout _ctx any, in _edge_var varchar)
{
  declare done any;
  declare i integer;

  done := DB.DBA.GQL_CTX_GET (_ctx, 'edge_reif_vars');
  for (i := 0; i < length (done); i := i + 1)
    {
      if (aref (done, i) = _edge_var)
        return 1;
    }
  return 0;
}
;

create procedure DB.DBA.GQL_CTX_MARK_EDGE_REIF (inout _ctx any, in _edge_var varchar)
{
  declare done any;

  if (DB.DBA.GQL_CTX_EDGE_REIF_DONE (_ctx, _edge_var))
    return;
  done := DB.DBA.GQL_CTX_GET (_ctx, 'edge_reif_vars');
  done := vector_concat (done, vector (_edge_var));
  DB.DBA.GQL_CTX_SET (_ctx, 'edge_reif_vars', done);
}
;

-- Bind the edge variable _edge_var to the resource that holds the
-- properties of each edge it matched: four mandatory triples per binding.
create procedure DB.DBA.GQL_CTX_EDGE_HOLDER_TRIPLES (inout _ctx any, in _edge_var varchar, inout _bindings any)
{
  declare i integer;
  declare esv varchar;

  esv := DB.DBA.GQL_EDGE_SPARQL_VAR (_edge_var);
  for (i := 0; i < length (_bindings); i := i + 1)
    {
      declare binding any;
      binding := aref (_bindings, i);
      if (aref (binding, 0) = _edge_var)
        {
          DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, esv,
            concat ('<', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'type>'),
            concat ('<', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'Statement>'));
          DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, esv,
            concat ('<', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'subject>'),
            aref (binding, 1));
          DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, esv,
            concat ('<', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'predicate>'),
            aref (binding, 2));
          DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, esv,
            concat ('<', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'object>'),
            aref (binding, 3));
        }
    }
}
;

-- In RDF 1.2 mode the properties of an edge are those of its reifier: bind
-- the edge variable _edge_var to the resource that rdf:reifies the triple
-- term of each edge it matched, a mandatory triple per binding.
create procedure DB.DBA.GQL_CTX_EDGE_REIFIER_TRIPLES (inout _ctx any, in _edge_var varchar, inout _bindings any)
{
  declare i integer;
  declare esv varchar;

  esv := DB.DBA.GQL_EDGE_SPARQL_VAR (_edge_var);
  for (i := 0; i < length (_bindings); i := i + 1)
    {
      declare binding any;
      binding := aref (_bindings, i);
      if (aref (binding, 0) = _edge_var)
        DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, esv,
          concat ('<', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'reifies>'),
          concat ('<<(', aref (binding, 1), ' ', aref (binding, 2), ' ', aref (binding, 3), ')>>'));
    }
}
;

-- Bind the edge variable _edge_var, once per statement.  An edge whose
-- property the statement reads (r.since) is the resource holding its
-- properties -- outside RDF 1.2 mode its rdf:Statement, in RDF 1.2 mode its
-- reifier -- a mandatory join as a node's property is.  An edge used only
-- as itself (_as_value: RETURN r, count (r)) is every edge it matched --
-- outside RDF 1.2 mode that resource when the edge has one, else its
-- triple; in RDF 1.2 mode its triple term.  If a property of it is read
-- later in the statement, the binding becomes the mandatory one.
create procedure DB.DBA.GQL_CTX_MATERIALIZE_EDGE_VAR (inout _ctx any, in _edge_var varchar, in _as_value integer := 0)
{
  declare bindings any;
  declare i integer;
  declare esv varchar;

  if (_edge_var is null or _edge_var = '')
    return 0;
  if (DB.DBA.GQL_CTX_EDGE_REIF_DONE (_ctx, _edge_var))
    {
      if (not _as_value)
        {
          declare vb any;
          vb := DB.DBA.GQL_CTX_GET (_ctx, 'edge_value_binds');
          for (i := 0; i + 1 < length (vb); i := i + 2)
            {
              if (aref (vb, i) = _edge_var)
                {
                  declare opts, binds varchar;
                  opts := DB.DBA.GQL_CTX_GET (_ctx, 'optionals');
                  binds := DB.DBA.GQL_CTX_GET (_ctx, 'binds');
                  aset (vb, i, '');
                  DB.DBA.GQL_CTX_SET (_ctx, 'edge_value_binds', vb);
                  -- Still in this pattern's text (not yet inside a WITH's
                  -- subquery): replace it by the mandatory binding.
                  if (strstr (opts, aref (vb, i + 1)) is not null)
                    {
                      DB.DBA.GQL_CTX_SET (_ctx, 'optionals', replace (opts, aref (vb, i + 1), ''));
                      bindings := DB.DBA.GQL_CTX_GET (_ctx, 'edge_bindings');
                      DB.DBA.GQL_CTX_EDGE_HOLDER_TRIPLES (_ctx, _edge_var, bindings);
                    }
                  else if (strstr (binds, aref (vb, i + 1)) is not null)
                    {
                      DB.DBA.GQL_CTX_SET (_ctx, 'binds', replace (binds, aref (vb, i + 1), ''));
                      bindings := DB.DBA.GQL_CTX_GET (_ctx, 'edge_bindings');
                      DB.DBA.GQL_CTX_EDGE_REIFIER_TRIPLES (_ctx, _edge_var, bindings);
                    }
                }
            }
        }
      return 1;
    }

  bindings := DB.DBA.GQL_CTX_GET (_ctx, 'edge_bindings');
  esv := DB.DBA.GQL_EDGE_SPARQL_VAR (_edge_var);

  if (DB.DBA.GQL_CTX_GET (_ctx, 'rdf12_mode') = 1 and not _as_value)
    DB.DBA.GQL_CTX_EDGE_REIFIER_TRIPLES (_ctx, _edge_var, bindings);
  else if (DB.DBA.GQL_CTX_GET (_ctx, 'rdf12_mode') = 1)
    {
      declare tt_expr varchar;
      tt_expr := null;
      for (i := 0; i < length (bindings); i := i + 1)
        {
          declare binding any;
          binding := aref (bindings, i);
          if (aref (binding, 0) = _edge_var)
            {
              if (tt_expr is null)
                tt_expr := concat ('TRIPLE(', aref (binding, 1), ', ', aref (binding, 2), ', ', aref (binding, 3), ')');
              else
                tt_expr := concat ('COALESCE(', tt_expr, ', TRIPLE(', aref (binding, 1), ', ', aref (binding, 2), ', ', aref (binding, 3), '))');
            }
        }
      if (tt_expr is not null and strstr (DB.DBA.GQL_CTX_GET (_ctx, 'binds'), concat (' AS ', esv, ')')) is null)
        {
          DB.DBA.GQL_CTX_ADD_BIND (_ctx, esv, tt_expr);
          DB.DBA.GQL_CTX_SET (_ctx, 'edge_value_binds', vector_concat (
            coalesce (DB.DBA.GQL_CTX_GET (_ctx, 'edge_value_binds'), vector ()),
            vector (_edge_var, concat ('  BIND (', tt_expr, ' AS ', esv, ')\n'))));
        }
    }
  else
    {
      declare ebind any;
      declare nb integer;
      nb := 0;
      ebind := null;
      if (_as_value)
        {
          for (i := 0; i < length (bindings); i := i + 1)
            {
              if (aref (aref (bindings, i), 0) = _edge_var)
                {
                  nb := nb + 1;
                  ebind := aref (bindings, i);
                }
            }
        }
      if (nb = 1)
        {
          declare hv, snippet varchar;
          hv := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'edge_holder_');
          snippet := concat (
            '  OPTIONAL { ', hv, ' <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement> ;\n',
            '      <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> ', aref (ebind, 1), ' ;\n',
            '      <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> ', aref (ebind, 2), ' ;\n',
            '      <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> ', aref (ebind, 3), ' }\n',
            '  BIND (COALESCE (', hv, ', TRIPLE (', aref (ebind, 1), ', ', aref (ebind, 2), ', ',
            aref (ebind, 3), ')) AS ', esv, ')\n');
          DB.DBA.GQL_CTX_SET (_ctx, 'optionals', concat (DB.DBA.GQL_CTX_GET (_ctx, 'optionals'), snippet));
          DB.DBA.GQL_CTX_SET (_ctx, 'edge_value_binds', vector_concat (
            coalesce (DB.DBA.GQL_CTX_GET (_ctx, 'edge_value_binds'), vector ()), vector (_edge_var, snippet)));
        }
      else
        DB.DBA.GQL_CTX_EDGE_HOLDER_TRIPLES (_ctx, _edge_var, bindings);
    }

  if (DB.DBA.GQL_CTX_HAS_EDGE_BINDING (_ctx, _edge_var))
    {
      DB.DBA.GQL_CTX_MARK_EDGE_REIF (_ctx, _edge_var);
      return 1;
    }
  return 0;
}
;

create procedure DB.DBA.GQL_CTX_FRESH_VAR (inout _ctx any, in _prefix varchar)
{
  declare ctr integer;
  ctr := DB.DBA.GQL_CTX_GET (_ctx, 'var_counter');
  ctr := ctr + 1;
  DB.DBA.GQL_CTX_SET (_ctx, 'var_counter', ctr);
  return concat ('?', _prefix, cast (ctr as varchar));
}
;

-- A context for a pattern translated inside the query -- EXISTS, a pattern
-- predicate, MINUS: the query's prefixes, namespaces and modes, so names
-- resolve as they do outside, its edge records, and its fresh-variable
-- counter, so no fresh variable meets one of the query's.  The caller
-- copies var_counter back when done.
create procedure DB.DBA.GQL_CTX_NEW_INNER (inout _ctx any)
{
  declare sub any;
  declare k integer;
  declare keys any;

  sub := DB.DBA.GQL_CTX_NEW (DB.DBA.GQL_CTX_GET (_ctx, 'graph'));
  keys := vector ('prefixes', 'base_uri', 'force_camelcase', 'rdf12_mode', 'var_counter',
    'reif_graph', 'ontology_ns', 'data_ns', 'is_property_graph', 'pg_name', 'edge_ends', 'in_service');
  for (k := 0; k < length (keys); k := k + 1)
    DB.DBA.GQL_CTX_SET (sub, aref (keys, k), DB.DBA.GQL_CTX_GET (_ctx, aref (keys, k)));
  return sub;
}
;

create procedure DB.DBA.GQL_CTX_ADD_PREFIX (inout _ctx any, in _prefix varchar, in _uri varchar)
{
  declare prefixes any;
  prefixes := DB.DBA.GQL_CTX_GET (_ctx, 'prefixes');
  prefixes := vector_concat (prefixes, vector (vector (_prefix, _uri)));
  DB.DBA.GQL_CTX_SET (_ctx, 'prefixes', prefixes);
}
;

create procedure DB.DBA.GQL_CTX_ADD_DEFINE (inout _ctx any, in _key varchar, in _value any)
{
  declare defines any;
  defines := DB.DBA.GQL_CTX_GET (_ctx, 'defines');
  defines := vector_concat (defines, vector (vector (_key, _value)));
  DB.DBA.GQL_CTX_SET (_ctx, 'defines', defines);
}
;

create procedure DB.DBA.GQL_CTX_FORCE_CAMELCASE (inout _ctx any)
{
  return DB.DBA.GQL_CTX_GET (_ctx, 'force_camelcase');
}
;

----------------------------------------------------------------------
-- Optional depth tracking (for scoping FILTER/BIND inside OPTIONAL)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_CTX_ENTER_OPTIONAL (inout _ctx any)
{
  declare d integer;
  d := DB.DBA.GQL_CTX_GET (_ctx, 'in_optional_depth');
  if (d is null) d := 0;
  DB.DBA.GQL_CTX_SET (_ctx, 'in_optional_depth', d + 1);
}
;

create procedure DB.DBA.GQL_CTX_EXIT_OPTIONAL (inout _ctx any)
{
  declare d integer;
  d := DB.DBA.GQL_CTX_GET (_ctx, 'in_optional_depth');
  if (d is null or d = 0) return;
  DB.DBA.GQL_CTX_SET (_ctx, 'in_optional_depth', d - 1);
}
;

create procedure DB.DBA.GQL_CTX_IN_OPTIONAL (inout _ctx any)
{
  declare d integer;
  d := DB.DBA.GQL_CTX_GET (_ctx, 'in_optional_depth');
  if (d is null or d = 0) return 0;
  return 1;
}
;

----------------------------------------------------------------------
-- Set-operation context tracking
----------------------------------------------------------------------

create procedure DB.DBA.GQL_CTX_ENTER_SET_OP (inout _ctx any)
{
  DB.DBA.GQL_CTX_SET (_ctx, 'in_set_op', 1);
}
;

create procedure DB.DBA.GQL_CTX_EXIT_SET_OP (inout _ctx any)
{
  DB.DBA.GQL_CTX_SET (_ctx, 'in_set_op', 0);
}
;

create procedure DB.DBA.GQL_CTX_IN_SET_OP (inout _ctx any)
{
  if (DB.DBA.GQL_CTX_GET (_ctx, 'in_set_op') = 1) return 1;
  return 0;
}
;

----------------------------------------------------------------------
-- Error accumulator (non-fatal errors collected during translation)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_CTX_ADD_ERROR (inout _ctx any, in _code varchar, in _msg varchar)
{
  declare errors any;
  errors := DB.DBA.GQL_CTX_GET (_ctx, 'error_acc');
  errors := vector_concat (errors, vector (vector (_code, _msg)));
  DB.DBA.GQL_CTX_SET (_ctx, 'error_acc', errors);
}
;

create procedure DB.DBA.GQL_CTX_HAS_ERRORS (inout _ctx any)
{
  declare errors any;
  errors := DB.DBA.GQL_CTX_GET (_ctx, 'error_acc');
  if (errors is not null and length (errors) > 0) return 1;
  return 0;
}
;

create procedure DB.DBA.GQL_CTX_GET_ERRORS (inout _ctx any)
{
  return DB.DBA.GQL_CTX_GET (_ctx, 'error_acc');
}
;

----------------------------------------------------------------------
-- Variable map: maps GQL variable names → SPARQL variable info
-- Each entry: vector(gql_name, sparql_var, kind)
--   kind: 'node', 'edge', 'path', 'value', 'alias'
----------------------------------------------------------------------

create procedure DB.DBA.GQL_CTX_ADD_VAR_MAP (inout _ctx any, in _gql_name varchar, in _sparql_var varchar, in _kind varchar)
{
  declare vm any;
  declare i integer;

  if (_gql_name is null or _gql_name = '')
    return;

  vm := DB.DBA.GQL_CTX_GET (_ctx, 'var_map');
  for (i := 0; i < length (vm); i := i + 1)
    {
      if (aref (aref (vm, i), 0) = _gql_name)
        {
          aset (vm, i, vector (_gql_name, _sparql_var, _kind));
          DB.DBA.GQL_CTX_SET (_ctx, 'var_map', vm);
          return;
        }
    }
  vm := vector_concat (vm, vector (vector (_gql_name, _sparql_var, _kind)));
  DB.DBA.GQL_CTX_SET (_ctx, 'var_map', vm);
}
;

create procedure DB.DBA.GQL_CTX_GET_VAR_MAP (inout _ctx any, in _gql_name varchar)
{
  declare vm any;
  declare i integer;

  if (_gql_name is null)
    return null;

  vm := DB.DBA.GQL_CTX_GET (_ctx, 'var_map');
  for (i := 0; i < length (vm); i := i + 1)
    {
      if (aref (aref (vm, i), 0) = _gql_name)
        return aref (vm, i);
    }
  return null;
}
;

create procedure DB.DBA.GQL_CTX_GET_VAR_MAP_SPARQL_VAR (inout _ctx any, in _gql_name varchar)
{
  declare entry any;
  entry := DB.DBA.GQL_CTX_GET_VAR_MAP (_ctx, _gql_name);
  if (entry is not null)
    return aref (entry, 1);
  return null;
}
;

----------------------------------------------------------------------
-- Name mapping: GQL variable → SPARQL variable
----------------------------------------------------------------------

create procedure DB.DBA.GQL_SPARQL_VAR (in _name varchar)
{
  if (_name is null) return null;
  return concat ('?gql_', _name);
}
;

create procedure DB.DBA.GQL_NODE_SPARQL_VAR (in _name varchar)
{
  if (_name is null) return null;
  return concat ('?gql_n_', _name);
}
;

create procedure DB.DBA.GQL_EDGE_SPARQL_VAR (in _name varchar)
{
  if (_name is null) return null;
  return concat ('?gql_e_', _name);
}
;

-- A copy of an EDGE pattern element with another direction ('RIGHT', 'LEFT').
create procedure DB.DBA.GQL_EDGE_WITH_DIRECTION (in _edge any, in _dir varchar)
{
  declare e any;
  declare i integer;
  e := make_array (length (_edge), 'any');
  for (i := 0; i < length (_edge); i := i + 1)
    aset (e, i, aref (_edge, i));
  aset (e, 3, _dir);
  return e;
}
;

-----------------------------------------------------------------------
-- Label expression emitter: recursively generates SPARQL for label
-- expressions (LABEL_OR, LABEL_AND, LABEL_NOT, LABEL_WILDCARD, plain string)
-----------------------------------------------------------------------

create procedure DB.DBA.GQL_EMIT_LABEL_EXPR (in _label_expr any, in _node_var varchar, inout _ctx any)
{
  declare expr_type varchar;
  if (isvector (_label_expr))
    expr_type := aref (_label_expr, 0);
  else
    expr_type := '';

  -- Plain label: emit rdf:type triple
  if (expr_type = '')
    {
      DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, _node_var, 'rdf:type',
        DB.DBA.GQL_GEN_LABEL_IRI_CTX (_label_expr, _ctx));
    }
  -- LABEL_OR: VALUES + rdf:type triple
  else if (expr_type = 'LABEL_OR')
    {
      declare label_choices any;
      declare label_var, values_s varchar;
      declare lci integer;
      label_choices := aref (_label_expr, 1);
      label_var := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'label_');
      values_s := concat ('  VALUES ', label_var, ' {');
      for (lci := 0; lci < length (label_choices); lci := lci + 1)
        values_s := concat (values_s, ' ',
          DB.DBA.GQL_GEN_LABEL_IRI_CTX (aref (label_choices, lci), _ctx));
      values_s := concat (values_s, ' }\n');
      DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, _node_var, 'rdf:type', label_var);
      DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx, values_s);
    }
  -- LABEL_AND: recursively emit each child
  else if (expr_type = 'LABEL_AND')
    {
      declare and_children any;
      declare ai integer;
      and_children := aref (_label_expr, 1);
      for (ai := 0; ai < length (and_children); ai := ai + 1)
        DB.DBA.GQL_EMIT_LABEL_EXPR (aref (and_children, ai), _node_var, _ctx);
    }
  -- LABEL_NOT: FILTER NOT EXISTS
  else if (expr_type = 'LABEL_NOT')
    {
      declare not_filter varchar;
      declare not_child any;
      not_child := aref (_label_expr, 1);
      if (isvector (not_child) and aref (not_child, 0) = 'LABEL_WILDCARD')
        {
          -- !% means "no label at all"
          declare any_type_var varchar;
          any_type_var := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'any_type_');
          not_filter := concat ('NOT EXISTS { ', _node_var, ' rdf:type ', any_type_var, ' }');
        }
      else if (isvector (not_child) and aref (not_child, 0) = 'LABEL_OR')
        {
          -- !(A|B) -> NOT EXISTS { { ?node rdf:type A } UNION { ?node rdf:type B } }
          declare or_choices any;
          declare oi integer;
          or_choices := aref (not_child, 1);
          not_filter := 'NOT EXISTS { ';
          for (oi := 0; oi < length (or_choices); oi := oi + 1)
            {
              if (oi > 0) not_filter := concat (not_filter, ' UNION ');
              not_filter := concat (not_filter, '{ ', _node_var, ' rdf:type ',
                DB.DBA.GQL_GEN_LABEL_IRI_CTX (aref (or_choices, oi), _ctx), ' }');
            }
          not_filter := concat (not_filter, ' }');
        }
      else if (isvector (not_child) and aref (not_child, 0) = 'LABEL_AND')
        {
          -- !(A&B) -> NOT EXISTS { ?node rdf:type A . ?node rdf:type B }
          declare and_children2 any;
          declare ai2 integer;
          and_children2 := aref (not_child, 1);
          not_filter := 'NOT EXISTS { ';
          for (ai2 := 0; ai2 < length (and_children2); ai2 := ai2 + 1)
            {
              not_filter := concat (not_filter, _node_var, ' rdf:type ',
                DB.DBA.GQL_GEN_LABEL_IRI_CTX (aref (and_children2, ai2), _ctx), ' . ');
            }
          not_filter := concat (not_filter, '}');
        }
      else
        {
          -- !Label -> NOT EXISTS { ?node rdf:type :Label }
          not_filter := concat ('NOT EXISTS { ', _node_var, ' rdf:type ',
            DB.DBA.GQL_GEN_LABEL_IRI_CTX (not_child, _ctx), ' }');
        }
      DB.DBA.GQL_CTX_ADD_FILTER (_ctx, not_filter);
    }
  -- LABEL_WILDCARD: % is any label, so the node has one -- each such node
  -- once, whatever number of labels it has.  The resources that hold edge
  -- properties (rdf:Statement) are not nodes.
  else if (expr_type = 'LABEL_WILDCARD')
    {
      declare any_type varchar;
      any_type := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'any_type_');
      DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx, concat (
        '  { SELECT DISTINCT ', _node_var, ' WHERE { ', _node_var, ' rdf:type ', any_type,
        ' . FILTER (', any_type, ' != rdf:Statement) } } .\n'));
    }
}
;

-- 1 when the label expression gives the node a pattern that binds it (a
-- label, an alternative, a conjunction with such a part, the wildcard);
-- 0 for a negation, which is only a filter.
create procedure DB.DBA.GQL_LABEL_EXPR_BINDS (in _label_expr any)
{
  declare expr_type varchar;
  declare i integer;
  if (not isvector (_label_expr) or isstring (_label_expr))
    return 1;
  expr_type := aref (_label_expr, 0);
  if (expr_type = 'LABEL_NOT')
    return 0;
  if (expr_type = 'LABEL_AND')
    {
      for (i := 0; i < length (aref (_label_expr, 1)); i := i + 1)
        if (DB.DBA.GQL_LABEL_EXPR_BINDS (aref (aref (_label_expr, 1), i)))
          return 1;
      return 0;
    }
  return 1;
}
;

-----------------------------------------------------------------------
-- Edge label expression emitter: handles edge type label expressions.
-- For plain strings and LABEL_OR, returns a vector of IRI strings.
-- For LABEL_AND, LABEL_NOT, LABEL_WILDCARD, emits FILTER constraints
-- and returns a vector with a fresh predicate variable.
-- Returns: vector of (iri_or_var, is_complex) pairs.
-----------------------------------------------------------------------

create procedure DB.DBA.GQL_EMIT_EDGE_LABEL_EXPR (in _label_expr any, in _src varchar, in _dst varchar, inout _ctx any)
{
  declare expr_type varchar;
  if (isvector (_label_expr))
    expr_type := aref (_label_expr, 0);
  else
    expr_type := '';

  -- Plain label: single edge type IRI
  if (expr_type = '')
    {
      return vector (vector (DB.DBA.GQL_GEN_EDGE_TYPE_IRI_CTX (_label_expr, _ctx), 0));
    }
  -- LABEL_OR: use SPARQL property path alternative (iri1|iri2|...)
  else if (expr_type = 'LABEL_OR')
    {
      declare or_choices any;
      declare oi integer;
      declare pp varchar;
      or_choices := aref (_label_expr, 1);
      pp := '';
      for (oi := 0; oi < length (or_choices); oi := oi + 1)
        {
          declare child_result any;
          declare child_iri varchar;
          child_result := DB.DBA.GQL_EMIT_EDGE_LABEL_EXPR (aref (or_choices, oi), _src, _dst, _ctx);
          -- Use the first IRI from each child (children should be plain labels)
          child_iri := aref (aref (child_result, 0), 0);
          if (oi > 0) pp := concat (pp, '|');
          pp := concat (pp, child_iri);
        }
      return vector (vector (concat ('(', pp, ')'), 0));
    }
  -- LABEL_AND: emit first type as triple, rest as FILTER on the edge variable
  else if (expr_type = 'LABEL_AND')
    {
      declare and_children any;
      declare ai integer;
      declare and_results any;
      and_children := aref (_label_expr, 1);
      and_results := vector ();
      for (ai := 0; ai < length (and_children); ai := ai + 1)
        {
          declare child_result any;
          child_result := DB.DBA.GQL_EMIT_EDGE_LABEL_EXPR (aref (and_children, ai), _src, _dst, _ctx);
          and_results := vector_concat (and_results, child_result);
        }
      return and_results;
    }
  -- LABEL_NOT: emit SPARQL negated property path !iri or !(iri1|iri2)
  -- For !% (wildcard negation), use NOT EXISTS (semantically "no edge at all")
  else if (expr_type = 'LABEL_NOT')
    {
      declare not_child any;
      not_child := aref (_label_expr, 1);
      if (isvector (not_child) and aref (not_child, 0) = 'LABEL_WILDCARD')
        {
          -- !% on edge: "no edge at all" between src and dst.  Emit ONLY a
          -- NOT EXISTS filter and return no edge IRI, so the caller adds no
          -- positive triple.  (Asserting a positive edge triple here would
          -- both contradict the filter -- yielding zero rows always -- and be
          -- duplicated by the caller's edge-triple emission.)
          DB.DBA.GQL_CTX_ADD_FILTER (_ctx, concat ('NOT EXISTS { ', _src, ' ?any_p ', _dst, ' }'));
          return vector ();
        }
      else if (isvector (not_child) and aref (not_child, 0) = 'LABEL_OR')
        {
          -- !(iri1|iri2) -> SPARQL negated property path
          declare or_choices any;
          declare oi2 integer;
          declare neg_pp varchar;
          or_choices := aref (not_child, 1);
          neg_pp := '!(';
          for (oi2 := 0; oi2 < length (or_choices); oi2 := oi2 + 1)
            {
              if (oi2 > 0) neg_pp := concat (neg_pp, '|');
              neg_pp := concat (neg_pp, DB.DBA.GQL_GEN_EDGE_TYPE_IRI_CTX (aref (or_choices, oi2), _ctx));
            }
          neg_pp := concat (neg_pp, ')');
          return vector (vector (neg_pp, 1));
        }
      else
        {
          -- !iri -> SPARQL negated property path
          return vector (vector (concat ('!', DB.DBA.GQL_GEN_EDGE_TYPE_IRI_CTX (not_child, _ctx)), 1));
        }
    }
  -- LABEL_WILDCARD: any edge type
  else if (expr_type = 'LABEL_WILDCARD')
    {
      declare any_edge_var varchar;
      any_edge_var := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'edge_type_');
      return vector (vector (any_edge_var, 1));
    }
  return vector ();
}
;

----------------------------------------------------------------------
-- IRI construction for labels, edge types, and properties
----------------------------------------------------------------------

create procedure DB.DBA.GQL_IS_ABSOLUTE_IRI_NAME (in _name varchar)
{
  if (_name is null)
    return 0;
  if (strstr (_name, '://') is not null)
    return 1;
  if (length (_name) >= 4 and subseq (_name, 0, 4) = 'urn:')
    return 1;
  return 0;
}
;

create procedure DB.DBA.GQL_REGISTERED_NS_URI (in _prefix varchar)
{
  declare ns_uri varchar;
  if (_prefix is null)
    return null;
  ns_uri := null;
  select max (NS_URL) into ns_uri
    from DB.DBA.SYS_XML_PERSISTENT_NS_DECL
   where NS_PREFIX = _prefix;
  if (isstring (ns_uri) and length (ns_uri) > 0)
    return ns_uri;
  if (_prefix = 'rdf')
    return 'http://www.w3.org/1999/02/22-rdf-syntax-ns#';
  if (_prefix = 'rdfs')
    return 'http://www.w3.org/2000/01/rdf-schema#';
  if (_prefix = 'owl')
    return 'http://www.w3.org/2002/07/owl#';
  if (_prefix = 'xsd')
    return 'http://www.w3.org/2001/XMLSchema#';
  if (_prefix = 'foaf')
    return 'http://xmlns.com/foaf/0.1/';
  if (_prefix = 'skos')
    return 'http://www.w3.org/2004/02/skos/core#';
  return ns_uri;
}
;

create procedure DB.DBA.GQL_EXPAND_PREFIXED_NAME (inout _ctx any, in _name varchar)
{
  declare colon_pos integer;
  declare prefix_name, local_name, ns_uri varchar;
  declare prefixes any;
  declare i integer;

  if (_name is null)
    return null;
  colon_pos := strchr (_name, ':');
  if (colon_pos is null)
    return null;
  if (DB.DBA.GQL_IS_ABSOLUTE_IRI_NAME (_name))
    return null;

  prefix_name := subseq (_name, 0, colon_pos);
  local_name := subseq (_name, colon_pos + 1);
  prefixes := DB.DBA.GQL_CTX_GET (_ctx, 'prefixes');
  for (i := 0; i < length (prefixes); i := i + 1)
    {
      if (aref (aref (prefixes, i), 0) = prefix_name)
        return concat (aref (aref (prefixes, i), 1), local_name);
    }
  ns_uri := DB.DBA.GQL_REGISTERED_NS_URI (prefix_name);
  if (isstring (ns_uri) and length (ns_uri) > 0)
    return concat (ns_uri, local_name);
  return null;
}
;

create procedure DB.DBA.GQL_CTX_DEFAULT_PREFIX_URI (inout _ctx any)
{
  declare prefixes any;
  declare i integer;
  prefixes := DB.DBA.GQL_CTX_GET (_ctx, 'prefixes');
  for (i := 0; i < length (prefixes); i := i + 1)
    {
      if (aref (aref (prefixes, i), 0) = '')
        return aref (aref (prefixes, i), 1);
    }
  return null;
}
;

create procedure DB.DBA.GQL_NS_JOIN_LOCAL (in _ns varchar, in _local varchar)
{
  declare last_ch integer;
  if (_ns is null or _ns = '')
    return null;
  if (_local is null)
    return _ns;
  if (length (_ns) = 0)
    return _local;
  last_ch := aref (_ns, length (_ns) - 1);
  if (last_ch = 35 or last_ch = 47 or last_ch = 58)  -- # / :
    return concat (_ns, _local);
  return concat (_ns, '#', _local);
}
;

create procedure DB.DBA.GQL_CTX_RELATIVE_TERM_URI (inout _ctx any, in _local varchar)
{
  declare base_uri, default_uri varchar;
  base_uri := DB.DBA.GQL_CTX_GET (_ctx, 'base_uri');
  if (base_uri is not null and base_uri <> '')
    return DB.DBA.GQL_NS_JOIN_LOCAL (base_uri, _local);
  default_uri := DB.DBA.GQL_CTX_DEFAULT_PREFIX_URI (_ctx);
  if (default_uri is not null and default_uri <> '')
    return DB.DBA.GQL_NS_JOIN_LOCAL (default_uri, _local);
  -- The active graph is a data container, not a vocabulary namespace: labels,
  -- properties and edge types always resolve to the ontology (GQL_NS), never
  -- to the graph IRI, so a query behaves the same whichever graph it targets
  -- (home graph, USE GRAPH <g>, or the default). Only an explicit BASE or a
  -- default ':' prefix overrides the ontology for relative terms.
  return null;
}
;

create procedure DB.DBA.GQL_TERM_URI (inout _ctx any, in _name varchar, in _kind varchar)
{
  declare expanded any;
  declare base_uri varchar;
  declare colon_pos integer;
  declare rel_uri varchar;
  if (DB.DBA.GQL_IS_ABSOLUTE_IRI_NAME (_name))
    return _name;
  if (length (_name) > 2 and subseq (_name, 0, 2) = '::')
    {
      rel_uri := DB.DBA.GQL_CTX_RELATIVE_TERM_URI (_ctx, subseq (_name, 2));
      if (rel_uri is null)
        signal ('G3011', sprintf ('Base-relative name %s requires BASE or PREFIX :', _name));
      return rel_uri;
    }
  expanded := DB.DBA.GQL_EXPAND_PREFIXED_NAME (_ctx, _name);
  if (isstring (expanded))
    return expanded;
  colon_pos := strchr (_name, ':');
  if (colon_pos = 0)
    {
      rel_uri := DB.DBA.GQL_CTX_RELATIVE_TERM_URI (_ctx, subseq (_name, 1));
      if (rel_uri is not null)
        return rel_uri;
    }
  if (colon_pos is not null and colon_pos > 0)
    {
      rel_uri := DB.DBA.GQL_CTX_RELATIVE_TERM_URI (_ctx, subseq (_name, colon_pos + 1));
      if (rel_uri is not null)
        return rel_uri;
    }
  rel_uri := DB.DBA.GQL_CTX_RELATIVE_TERM_URI (_ctx, _name);
  if (rel_uri is not null)
    return rel_uri;
  if (_kind = 'label')
    return concat (DB.DBA.GQL_NS_CTX (_ctx), _name);
  if (_kind = 'edge')
    {
      if (DB.DBA.GQL_CTX_FORCE_CAMELCASE (_ctx) = 1)
        return concat (DB.DBA.GQL_NS_CTX (_ctx), DB.DBA.GQL_TO_CAMEL_CASE (_name));
      return concat (DB.DBA.GQL_NS_CTX (_ctx), _name);
    }
  if (_kind = 'prop' and DB.DBA.GQL_CTX_FORCE_CAMELCASE (_ctx) = 1)
    return concat (DB.DBA.GQL_NS_CTX (_ctx), DB.DBA.GQL_TO_CAMEL_CASE (_name));
  return concat (DB.DBA.GQL_NS_CTX (_ctx), _name);
}
;

create procedure DB.DBA.GQL_GEN_LABEL_IRI_CTX (in _label varchar, inout _ctx any)
{
  return concat ('<', DB.DBA.GQL_TERM_URI (_ctx, _label, 'label'), '>');
}
;

create procedure DB.DBA.GQL_GEN_EDGE_TYPE_IRI_CTX (in _type varchar, inout _ctx any)
{
  return concat ('<', DB.DBA.GQL_TERM_URI (_ctx, _type, 'edge'), '>');
}
;

create procedure DB.DBA.GQL_GEN_PROP_IRI_CTX (in _prop varchar, inout _ctx any)
{
  return concat ('<', DB.DBA.GQL_TERM_URI (_ctx, _prop, 'prop'), '>');
}
;

create procedure DB.DBA.GQL_GEN_NS_IRI (inout _ctx any, in _local varchar)
{
  return concat ('<', DB.DBA.GQL_NS_CTX (_ctx), _local, '>');
}
;

create procedure DB.DBA.GQL_GRAPH_REF_VALUE (in _graph_ref any)
{
  declare tmp_ctx any;
  if (_graph_ref is null)
    return null;
  if (isarray (_graph_ref) and length (_graph_ref) > 1 and aref (_graph_ref, 0) = 'GRAPH_REF')
    {
      tmp_ctx := DB.DBA.GQL_CTX_NEW (DB.DBA.GQL_DEFAULT_GRAPH ());
      return DB.DBA.GQL_GRAPH_REF_VALUE_CTX (_graph_ref, tmp_ctx);
    }
  return cast (_graph_ref as varchar);
}
;

create procedure DB.DBA.GQL_GRAPH_REF_VALUE_CTX (in _graph_ref any, inout _ctx any)
{
  declare val, kind varchar;
  declare expanded any;

  if (_graph_ref is null)
    return null;

  if (isarray (_graph_ref) and length (_graph_ref) > 1 and aref (_graph_ref, 0) = 'GRAPH_REF')
    {
      val := cast (aref (_graph_ref, 1) as varchar);
      kind := 'BARE';
      if (length (_graph_ref) > 2)
        kind := cast (aref (_graph_ref, 2) as varchar);

      if (kind = 'PNAME')
        {
          expanded := DB.DBA.GQL_EXPAND_PREFIXED_NAME (_ctx, val);
          if (isstring (expanded))
            return expanded;
        }
      return val;
    }

  return cast (_graph_ref as varchar);
}
;

create procedure DB.DBA.GQL_GEN_BASE_CLAUSE (inout _ctx any)
{
  declare base_uri varchar;
  base_uri := DB.DBA.GQL_CTX_GET (_ctx, 'base_uri');
  if (base_uri is null or base_uri = '')
    return '';
  return concat ('BASE <', base_uri, '> ');
}
;

create procedure DB.DBA.GQL_GEN_DEFINE_CLAUSE (inout _ctx any)
{
  declare defines any;
  declare i integer;
  declare define_clause varchar;
  defines := DB.DBA.GQL_CTX_GET (_ctx, 'defines');
  define_clause := '';
  for (i := 0; i < length (defines); i := i + 1)
    {
      if (define_clause <> '')
        define_clause := concat (define_clause, ' ');
      define_clause := concat (define_clause, 'DEFINE ', aref (aref (defines, i), 0), ' ',
        DB.DBA.GQL_GEN_EXPR (aref (aref (defines, i), 1), _ctx));
    }
  if (define_clause <> '')
    define_clause := concat (define_clause, ' ');
  return define_clause;
}
;

----------------------------------------------------------------------
-- FROM / FROM NAMED dataset clauses
----------------------------------------------------------------------

create procedure DB.DBA.GQL_GEN_FROM_CLAUSES (inout _ctx any)
{
  declare extras any;
  declare i integer;
  declare out_s varchar;
  declare any_default integer;
  declare _graph varchar;

  out_s := '';
  any_default := 0;
  -- When no graph was named, the active graph is the internal default sentinel.
  -- Emit no FROM in that case so the query runs against Virtuoso's default SPARQL
  -- dataset, returning the same result set a bare SPARQL query would -- rather
  -- than restricting to a GQL-only default graph.
  _graph := DB.DBA.GQL_CTX_GET (_ctx, 'graph');
  if (_graph = DB.DBA.GQL_DEFAULT_GRAPH ())
    DB.DBA.GQL_CTX_SET (_ctx, 'suppress_default_from', 1);
  if (DB.DBA.GQL_CTX_GET (_ctx, 'suppress_default_from') = 1)
    {
      extras := DB.DBA.GQL_CTX_GET (_ctx, 'extra_from_graphs');
      if (extras is null or length (extras) = 0)
        return '';
    }
  extras := DB.DBA.GQL_CTX_GET (_ctx, 'extra_from_graphs');
  if (extras is not null and length (extras) > 0)
    {
      for (i := 0; i < length (extras); i := i + 1)
        {
          declare entry any;
          declare kind, gval varchar;
          entry := aref (extras, i);
          kind := aref (entry, 0);
          gval := aref (entry, 1);
          if (kind = 'FROM_NAMED')
            out_s := concat (out_s, 'FROM NAMED <', gval, '>\n');
          else if (kind = 'NOT_FROM')
            out_s := concat (out_s, 'NOT FROM <', gval, '>\n');
          else if (kind = 'NOT_FROM_NAMED')
            out_s := concat (out_s, 'NOT FROM NAMED <', gval, '>\n');
          else
            { out_s := concat (out_s, 'FROM <', gval, '>\n'); any_default := 1; }
        }
      if (any_default = 0 and DB.DBA.GQL_CTX_GET (_ctx, 'suppress_default_from') <> 1)
        out_s := concat ('FROM <', DB.DBA.GQL_CTX_GET (_ctx, 'graph'), '>\n', out_s);
      return out_s;
    }
  if (DB.DBA.GQL_CTX_GET (_ctx, 'suppress_default_from') = 1)
    return '';
  return concat ('FROM <', DB.DBA.GQL_CTX_GET (_ctx, 'graph'), '>\n');
}
;

create procedure DB.DBA.GQL_GEN_EXPLICIT_FROM_CLAUSES (inout _ctx any)
{
  declare extras any;
  declare i integer;
  declare out_s varchar;

  out_s := '';
  extras := DB.DBA.GQL_CTX_GET (_ctx, 'extra_from_graphs');
  if (extras is not null and length (extras) > 0)
    {
      for (i := 0; i < length (extras); i := i + 1)
        {
          declare entry any;
          declare kind, gval varchar;
          entry := aref (extras, i);
          kind := aref (entry, 0);
          gval := aref (entry, 1);
          if (kind = 'FROM_NAMED')
            out_s := concat (out_s, 'FROM NAMED <', gval, '>\n');
          else
            out_s := concat (out_s, 'FROM <', gval, '>\n');
        }
    }
  return out_s;
}
;

----------------------------------------------------------------------
-- The options of a SERVICE block.  What a SERVICE block sends is SPARQL
-- 1.1: a sub-SELECT whose RETURN items are aliases, NOT IN, and, for a node
-- or an edge with no label, a nested SELECT.  For an endpoint whose service
-- description is not loaded, the SPARQL compiler allows only SPARQL 1.0: it
-- refuses NOT IN and the nested SELECT, and leaves an alias out of the
-- query it sends.  Unless the endpoint has a loaded description, say what
-- the query needs: IN (0x20), sub-queries and aggregates (0x100), and
-- SPARQL 1.1 (0x2000, 0x4000).  A loaded description is used as it is.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_SERVICE_OPTIONS (in _endpoint varchar)
{
  if (_endpoint like '<%>'
      and length (jso_triple_get_objs (subseq (_endpoint, 1, length (_endpoint) - 1),
        'http://www.openlinksw.com/schemas/virtrdf#dialect')) = 1)
    return '';
  return ' (DEFINE lang:dialect 24864)';
}
;

----------------------------------------------------------------------
-- SERVICE block: emit `SERVICE <endpoint> { triples ... }` into context
-- triples accumulator. The inner block reuses the outer context so any
-- variables it binds become visible to the surrounding query.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_GEN_SERVICE (in _service_ast any, inout _ctx any)
{
  declare endpoint_expr, svc_query, svc_clauses any;
  declare endpoint_str, svc_opts, body, triples, explicit_from varchar;
  declare is_silent, i integer;
  declare svc_ctx any;
  declare has_return integer;
  declare return_ast any;
  declare match_asts, where_asts, for_asts any;
  declare order_clause, limit_clause, skip_clause varchar;
  declare is_distinct integer;
  declare ret_vars any;
  declare proj varchar;
  declare ri integer;
  declare clause, ctype any;

  endpoint_expr := aref (_service_ast, 1);
  svc_query := aref (_service_ast, 2);
  is_silent := 0;
  if (length (_service_ast) > 3 and aref (_service_ast, 3) is not null)
    is_silent := aref (_service_ast, 3);

  endpoint_str := DB.DBA.GQL_GEN_GRAPH_TERM (endpoint_expr, _ctx);
  if (not isarray (svc_query) or aref (svc_query, 0) <> 'QUERY')
    svc_clauses := vector ();
  else
    svc_clauses := aref (svc_query, 1);

  svc_ctx := DB.DBA.GQL_CTX_NEW (DB.DBA.GQL_CTX_GET (_ctx, 'graph'));
  DB.DBA.GQL_CTX_SET (svc_ctx, 'prefixes', DB.DBA.GQL_CTX_GET (_ctx, 'prefixes'));
  DB.DBA.GQL_CTX_SET (svc_ctx, 'base_uri', DB.DBA.GQL_CTX_GET (_ctx, 'base_uri'));
  DB.DBA.GQL_CTX_SET (svc_ctx, 'defines', DB.DBA.GQL_CTX_GET (_ctx, 'defines'));
  DB.DBA.GQL_CTX_SET (svc_ctx, 'force_camelcase', DB.DBA.GQL_CTX_GET (_ctx, 'force_camelcase'));
  DB.DBA.GQL_CTX_SET (svc_ctx, 'rdf12_mode', DB.DBA.GQL_CTX_GET (_ctx, 'rdf12_mode'));
  DB.DBA.GQL_CTX_SET (svc_ctx, 'var_counter', DB.DBA.GQL_CTX_GET (_ctx, 'var_counter'));
  DB.DBA.GQL_CTX_SET (svc_ctx, 'reif_graph', DB.DBA.GQL_CTX_GET (_ctx, 'reif_graph'));
  DB.DBA.GQL_CTX_SET (svc_ctx, 'ontology_ns', DB.DBA.GQL_CTX_GET (_ctx, 'ontology_ns'));
  DB.DBA.GQL_CTX_SET (svc_ctx, 'data_ns', DB.DBA.GQL_CTX_GET (_ctx, 'data_ns'));
  DB.DBA.GQL_CTX_SET (svc_ctx, 'is_property_graph', DB.DBA.GQL_CTX_GET (_ctx, 'is_property_graph'));
  DB.DBA.GQL_CTX_SET (svc_ctx, 'pg_name', DB.DBA.GQL_CTX_GET (_ctx, 'pg_name'));
  DB.DBA.GQL_CTX_SET (svc_ctx, 'in_service', 1);
  svc_opts := DB.DBA.GQL_SERVICE_OPTIONS (endpoint_str);

  match_asts := vector ();
  where_asts := vector ();
  for_asts := vector ();
  return_ast := null;
  has_return := 0;

  for (i := 0; i < length (svc_clauses); i := i + 1)
    {
      clause := aref (svc_clauses, i);
      if (not isarray (clause)) goto svc_next_clause;
      ctype := aref (clause, 0);
      if (ctype = 'MATCH' or ctype = 'OPTIONAL')
        {
          match_asts := vector_concat (match_asts, vector (clause));
          if (length (clause) > 4 and aref (clause, 4) = 1)
            DB.DBA.GQL_CTX_SET (svc_ctx, 'suppress_default_from', 1);
        }
      else if (ctype = 'WHERE' or ctype = 'FILTER')
        where_asts := vector_concat (where_asts, vector (clause));
      else if (ctype = 'FOR')
        for_asts := vector_concat (for_asts, vector (clause));
      else if (ctype = 'RETURN')
        { has_return := 1; return_ast := clause; }
      else if (ctype = 'FINISH')
        { has_return := 0; }
      else if (ctype = 'PREFIX')
        DB.DBA.GQL_CTX_ADD_PREFIX (svc_ctx, aref (clause, 1), aref (clause, 2));
      else if (ctype = 'BASE')
        DB.DBA.GQL_CTX_SET (svc_ctx, 'base_uri', aref (clause, 1));
      else if (ctype = 'DEFINE')
        DB.DBA.GQL_CTX_ADD_DEFINE (svc_ctx, aref (clause, 1), aref (clause, 2));
      else if (ctype = 'FORCE_CAMELCASE')
        DB.DBA.GQL_CTX_SET (svc_ctx, 'force_camelcase', 1);
      else if (ctype = 'USE')
        DB.DBA.GQL_CTX_SET (svc_ctx, 'graph', DB.DBA.GQL_GRAPH_REF_VALUE_CTX (aref (clause, 1), svc_ctx));
      else if (ctype = 'USE_PROPERTY')
        DB.DBA.GQL_CTX_BIND_PROPERTY_GRAPH (svc_ctx, aref (clause, 1));
      else if (ctype = 'USE_ANY_GRAPH')
        DB.DBA.GQL_CTX_SET (svc_ctx, 'suppress_default_from', 1);
      else if (ctype = 'USE_HOME_GRAPH')
        DB.DBA.GQL_CTX_SET (svc_ctx, 'graph', DB.DBA.GQL_HOME_GRAPH ());
      else if (ctype = 'FROM_CLAUSE')
        {
          declare extra_from any;
          extra_from := DB.DBA.GQL_CTX_GET (svc_ctx, 'extra_from_graphs');
          extra_from := vector_concat (extra_from,
            vector (vector (aref (clause, 1), DB.DBA.GQL_GRAPH_REF_VALUE_CTX (aref (clause, 2), svc_ctx))));
          DB.DBA.GQL_CTX_SET (svc_ctx, 'extra_from_graphs', extra_from);
        }
      else if (ctype = 'SERVICE')
        DB.DBA.GQL_GEN_SERVICE (clause, svc_ctx);
    svc_next_clause:;
    }

  for (i := 0; i < length (match_asts); i := i + 1)
    {
      declare m_ast any;
      m_ast := aref (match_asts, i);
      if (length (m_ast) > 4 and aref (m_ast, 4) = 1)
        DB.DBA.GQL_CTX_SET (svc_ctx, 'suppress_default_from', 1);
      DB.DBA.GQL_GEN_MATCH (m_ast, svc_ctx);
    }
  for (i := 0; i < length (for_asts); i := i + 1)
    {
      declare fc any;
      fc := aref (for_asts, i);
      if (aref (fc, 0) = 'UNNEST')
        DB.DBA.GQL_GEN_UNNEST (fc, svc_ctx);
      else
        DB.DBA.GQL_GEN_FOR_VALUES (fc, svc_ctx);
    }
  for (i := 0; i < length (where_asts); i := i + 1)
    {
      declare wexpr varchar;
      wexpr := DB.DBA.GQL_GEN_EXPR (aref (aref (where_asts, i), 1), svc_ctx);
      DB.DBA.GQL_CTX_ADD_FILTER (svc_ctx, wexpr);
    }

  triples := DB.DBA.GQL_CTX_GET (_ctx, 'triples');
  if (has_return)
    {
      ret_vars := DB.DBA.GQL_GEN_RETURN (return_ast, svc_ctx, order_clause, limit_clause, skip_clause, is_distinct);
      explicit_from := DB.DBA.GQL_GEN_EXPLICIT_FROM_CLAUSES (svc_ctx);

      body := DB.DBA.GQL_CTX_GET (svc_ctx, 'values');
      body := concat (body, DB.DBA.GQL_CTX_GET (svc_ctx, 'pre_values'));
      body := concat (body, DB.DBA.GQL_CTX_GET (svc_ctx, 'pre_binds'));
      body := concat (body, DB.DBA.GQL_CTX_GET (svc_ctx, 'triples'));
      body := concat (body, DB.DBA.GQL_CTX_GET (svc_ctx, 'binds'));
      body := concat (body, DB.DBA.GQL_CTX_GET (svc_ctx, 'filters'));
      body := concat (body, DB.DBA.GQL_CTX_GET (svc_ctx, 'optionals'));

      proj := '';
      for (ri := 0; ri < length (ret_vars); ri := ri + 1)
        {
          declare rv, ralias any;
          rv := aref (aref (ret_vars, ri), 0);
          ralias := aref (aref (ret_vars, ri), 1);
          if (proj <> '') proj := concat (proj, ' ');
          if (ralias is not null and rv <> concat ('?', ralias))
            proj := concat (proj, '(', rv, ' AS ?', ralias, ')');
          else
            proj := concat (proj, rv);
        }
      if (proj = '')
        proj := '*';

      if (is_silent)
        triples := concat (triples, '  SERVICE SILENT ', endpoint_str, svc_opts, ' {\n');
      else
        triples := concat (triples, '  SERVICE ', endpoint_str, svc_opts, ' {\n');
      triples := concat (triples, '    SELECT ');
      if (is_distinct)
        triples := concat (triples, 'DISTINCT ');
      triples := concat (triples, proj, '\n');
      triples := concat (triples, explicit_from);
      triples := concat (triples, '    WHERE {\n', body, '    }\n');
      if (order_clause <> '')
        triples := concat (triples, '    ', order_clause, '\n');
      if (skip_clause <> '')
        triples := concat (triples, '    ', skip_clause, '\n');
      if (limit_clause <> '')
        triples := concat (triples, '    ', limit_clause, '\n');
      triples := concat (triples, '  }\n');

      for (i := 0; i < length (aref (return_ast, 2)); i := i + 1)
        {
          declare item, expr, alias any;
          item := aref (aref (return_ast, 2), i);
          expr := aref (item, 1);
          alias := aref (item, 2);
          if (isarray (expr) and aref (expr, 0) = 'VAR' and aref (expr, 1) = '*')
            {
              declare svc_vars any;
              declare vi integer;
              svc_vars := DB.DBA.GQL_CTX_GET (svc_ctx, 'vars');
              for (vi := 0; vi < length (svc_vars); vi := vi + 1)
                DB.DBA.GQL_CTX_ADD_VAR (_ctx, aref (svc_vars, vi));
            }
          else if (alias is not null)
            {
              DB.DBA.GQL_CTX_ADD_VAR (_ctx, alias);
              DB.DBA.GQL_CTX_ADD_ALIAS (_ctx, alias, concat ('?', alias));
            }
          else if (isarray (expr) and aref (expr, 0) = 'VAR')
            {
              DB.DBA.GQL_CTX_ADD_VAR (_ctx, aref (expr, 1));
              DB.DBA.GQL_CTX_ADD_ALIAS (_ctx, aref (expr, 1), concat ('?', aref (expr, 1)));
            }
        }
    }
  else
    {
      body := DB.DBA.GQL_CTX_GET (svc_ctx, 'values');
      body := concat (body, DB.DBA.GQL_CTX_GET (svc_ctx, 'pre_values'));
      body := concat (body, DB.DBA.GQL_CTX_GET (svc_ctx, 'pre_binds'));
      body := concat (body, DB.DBA.GQL_CTX_GET (svc_ctx, 'triples'));
      body := concat (body, DB.DBA.GQL_CTX_GET (svc_ctx, 'binds'));
      body := concat (body, DB.DBA.GQL_CTX_GET (svc_ctx, 'filters'));
      body := concat (body, DB.DBA.GQL_CTX_GET (svc_ctx, 'optionals'));

      if (is_silent)
        triples := concat (triples, '  SERVICE SILENT ', endpoint_str, svc_opts, ' {\n', body, '  }\n');
      else
        triples := concat (triples, '  SERVICE ', endpoint_str, svc_opts, ' {\n', body, '  }\n');
      for (i := 0; i < length (DB.DBA.GQL_CTX_GET (svc_ctx, 'vars')); i := i + 1)
        DB.DBA.GQL_CTX_ADD_VAR (_ctx, aref (DB.DBA.GQL_CTX_GET (svc_ctx, 'vars'), i));
      DB.DBA.GQL_CTX_MERGE_PROP_CACHE (_ctx, svc_ctx);
    }

  DB.DBA.GQL_CTX_SET (_ctx, 'triples', triples);
  DB.DBA.GQL_CTX_SET (_ctx, 'var_counter', DB.DBA.GQL_CTX_GET (svc_ctx, 'var_counter'));
}
;

----------------------------------------------------------------------
-- Render an expression into a SPARQL graph/service term (IRI or var).
----------------------------------------------------------------------

create procedure DB.DBA.GQL_GEN_GRAPH_TERM (in _expr any, inout _ctx any)
{
  declare uri any;

  if (isarray (_expr) and aref (_expr, 0) = 'IRI')
    {
      uri := DB.DBA.GQL_EXPAND_PREFIXED_NAME (_ctx, aref (_expr, 1));
      if (not isstring (uri))
        uri := aref (_expr, 1);
      return concat ('<', uri, '>');
    }
  if (isarray (_expr) and aref (_expr, 0) = 'GRAPH_REF')
    return concat ('<', cast (aref (_expr, 1) as varchar), '>');
  if (isarray (_expr) and aref (_expr, 0) = 'LIT' and isstring (aref (_expr, 1)))
    return concat ('<', aref (_expr, 1), '>');
  if (isstring (_expr))
    return concat ('<', _expr, '>');
  return DB.DBA.GQL_GEN_EXPR (_expr, _ctx);
}
;

create procedure DB.DBA.GQL_GEN_FOR_VALUES (in _for_ast any, inout _ctx any)
{
  declare var_name, var_sparql, values_list, pos_name, pos_sparql varchar;
  declare expr, items any;
  declare i, first_pos integer;
  declare ordinality_offset varchar;

  var_name := aref (_for_ast, 1);
  expr := aref (_for_ast, 2);
  ordinality_offset := null;
  pos_name := null;
  if (length (_for_ast) > 3)
    ordinality_offset := aref (_for_ast, 3);
  if (length (_for_ast) > 4)
    pos_name := aref (_for_ast, 4);
  if (ordinality_offset is not null and pos_name is null)
    pos_name := concat (var_name, '_', lower (ordinality_offset));

  if (not isarray (expr) or aref (expr, 0) <> 'LIST')
    signal ('G2002', 'FOR currently supports only list literals');

  items := aref (expr, 1);
  var_sparql := DB.DBA.GQL_NODE_SPARQL_VAR (var_name);
  DB.DBA.GQL_CTX_ADD_VAR (_ctx, var_name);
  if (ordinality_offset is null)
    {
      values_list := '';
      for (i := 0; i < length (items); i := i + 1)
        {
          if (values_list <> '')
            values_list := concat (values_list, ' ');
          values_list := concat (values_list, DB.DBA.GQL_GEN_EXPR (aref (items, i), _ctx));
        }
      DB.DBA.GQL_CTX_ADD_VALUES (_ctx, var_sparql, values_list);
      return;
    }

  -- WITH ORDINALITY (from 1) / WITH OFFSET (from 0): each item with its
  -- position, in one VALUES row -- two VALUES blocks would cross them.
  first_pos := case when ordinality_offset = 'ORDINALITY' then 1 else 0 end;
  pos_sparql := DB.DBA.GQL_NODE_SPARQL_VAR (pos_name);
  DB.DBA.GQL_CTX_ADD_VAR (_ctx, pos_name);
  values_list := '';
  for (i := 0; i < length (items); i := i + 1)
    values_list := concat (values_list, ' (', DB.DBA.GQL_GEN_EXPR (aref (items, i), _ctx), ' ',
      cast (i + first_pos as varchar), ')');
  DB.DBA.GQL_CTX_SET (_ctx, 'values', concat (DB.DBA.GQL_CTX_GET (_ctx, 'values'),
    '  VALUES (', var_sparql, ' ', pos_sparql, ') {', values_list, ' }\n'));
}
;

create procedure DB.DBA.GQL_GEN_UNNEST (in _unnest_ast any, inout _ctx any)
{
  declare var_name, var_sparql, values_list varchar;
  declare expr, items any;
  declare i integer;

  var_name := aref (_unnest_ast, 1);
  expr := aref (_unnest_ast, 2);

  -- For list literals, expand into VALUES (same as FOR)
  if (isarray (expr) and aref (expr, 0) = 'LIST')
    {
      items := aref (expr, 1);
      values_list := '';
      for (i := 0; i < length (items); i := i + 1)
        {
          if (values_list <> '')
            values_list := concat (values_list, ' ');
          values_list := concat (values_list, DB.DBA.GQL_GEN_EXPR (aref (items, i), _ctx));
        }
      var_sparql := DB.DBA.GQL_NODE_SPARQL_VAR (var_name);
      DB.DBA.GQL_CTX_ADD_VAR (_ctx, var_name);
      DB.DBA.GQL_CTX_ADD_VALUES (_ctx, var_sparql, values_list);
      return;
    }

  -- A property is one row per value it has: the triples that hold it.
  if (isarray (expr) and aref (expr, 0) = 'PROP')
    {
      var_sparql := DB.DBA.GQL_NODE_SPARQL_VAR (var_name);
      DB.DBA.GQL_CTX_ADD_VAR (_ctx, var_name);
      DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, DB.DBA.GQL_GEN_EXPR (aref (expr, 1), _ctx),
        DB.DBA.GQL_GEN_PROP_IRI_CTX (aref (expr, 2), _ctx), var_sparql);
      return;
    }
  -- Anything else -- a list held in a value -- has no expansion in SPARQL.
  signal ('G2002', 'UNNEST supports a list literal or a property');
}
;

----------------------------------------------------------------------
-- Literal formatting for SPARQL
----------------------------------------------------------------------

create procedure DB.DBA.GQL_GEN_LITERAL (in _val any)
{
  if (_val is null) return 'UNDEF';
  if (isstring (_val))
    {
      declare escaped varchar;
      escaped := replace (_val, '\\', '\\\\');
      escaped := replace (escaped, '"', '\\"');
      escaped := replace (escaped, '\n', '\\n');
      escaped := replace (escaped, '\r', '\\r');
      escaped := replace (escaped, '\t', '\\t');
      return concat ('"', escaped, '"');
    }
  if (isinteger (_val))
    return cast (_val as varchar);
  if (isfloat (_val) or isdouble (_val))
    return cast (_val as varchar);
  if (_val = 1) return 'true';
  if (_val = 0) return 'false';
  return cast (_val as varchar);
}
;

----------------------------------------------------------------------
-- Parameter value binding for SPARQL
--
-- Used to bind GQL $parameters ($name) to supplied values as typed SPARQL
-- terms at translation time (see the 'PARAM' case in GQL_GEN_EXPR). Values
-- are always emitted through GQL_GEN_LITERAL (which escapes strings and
-- types numbers/booleans) — a string value can therefore never break out
-- of its literal and alter the query. The only exception is a string that
-- is a strict, well-formed absolute IRI with no characters that could
-- escape a <...> term, which is emitted as an IRI so that IRI-valued
-- parameters bind with the correct RDF type.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARAM_IS_IRI (in _val any)
{
  declare i, n, ci integer;
  if (not isstring (_val)) return 0;
  n := length (_val);
  if (n < 4) return 0;
  -- scheme must begin with an ASCII letter and contain '://'
  ci := aref (_val, 0);
  if (not ((ci >= 65 and ci <= 90) or (ci >= 97 and ci <= 122)))
    return 0;
  if (strstr (_val, '://') is null)
    return 0;
  -- reject any character not permitted raw in a SPARQL IRIREF, so the value
  -- can never break out of the surrounding <...>
  for (i := 0; i < n; i := i + 1)
    {
      ci := aref (_val, i);
      if (ci <= 32) return 0;               -- controls and space
      if (ci = 34) return 0;                -- "
      if (ci = 60 or ci = 62) return 0;     -- < >
      if (ci = 92) return 0;                -- backslash
      if (ci = 94 or ci = 96) return 0;     -- ^ `
      if (ci = 123 or ci = 124 or ci = 125) return 0;  -- { | }
    }
  return 1;
}
;

create procedure DB.DBA.GQL_PARAM_TO_SPARQL (in _val any)
{
  if (DB.DBA.GQL_PARAM_IS_IRI (_val))
    return concat ('<', _val, '>');
  return DB.DBA.GQL_GEN_LITERAL (_val);
}
;

----------------------------------------------------------------------
-- Emit a GQL list literal ('LIST' AST node) as a Virtuoso vector scalar:
-- bif:vector(e1, e2, ...). Used for list VALUE functions (CARDINALITY/SIZE/
-- TRIM) where the list must be a single value, as opposed to the RDF
-- collection / VALUES forms used for list membership and expansion.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_GEN_LIST_VECTOR (in _list_ast any, inout _ctx any)
{
  declare items any;
  declare i integer;
  declare parts varchar;
  items := aref (_list_ast, 1);
  parts := '';
  for (i := 0; i < length (items); i := i + 1)
    {
      if (i > 0) parts := concat (parts, ', ');
      parts := concat (parts, DB.DBA.GQL_GEN_EXPR (aref (items, i), _ctx));
    }
  return concat ('bif:vector(', parts, ')');
}
;

create procedure DB.DBA.GQL_LIKE_PATTERN_TO_REGEX (in _pattern varchar)
{
  declare i, ch_code integer;
  declare ch, res varchar;

  if (_pattern is null)
    return '';

  res := '';
  for (i := 0; i < length (_pattern); i := i + 1)
    {
      ch := subseq (_pattern, i, i + 1);
      ch_code := aref (_pattern, i);
      if (ch = '%')
        res := concat (res, '.*');
      else if (ch = '_')
        res := concat (res, '.');
      else if (ch = '.' or ch = '^' or ch_code = 36 or ch = '*' or ch = '+'
               or ch = '?' or ch = '(' or ch = ')' or ch = '[' or ch = ']'
               or ch = '{' or ch = '}' or ch = '|' or ch = '\\')
        res := concat (res, '\\', ch);
      else
        res := concat (res, ch);
    }
  return res;
}
;

create procedure DB.DBA.GQL_GEN_CONTAINS_OPTIONS (in _opts any, inout _ctx any)
{
  declare i integer;
  declare parts varchar;

  parts := '';
  if (_opts is null or not isarray (_opts))
    return parts;

  for (i := 0; i < length (_opts); i := i + 1)
    {
      declare opt any;
      declare opt_name, opt_val varchar;
      opt := aref (_opts, i);
      if (not isarray (opt) or length (opt) < 1)
        goto contains_opt_next;
      opt_name := lower (cast (aref (opt, 0) as varchar));
      if (parts <> '')
        parts := concat (parts, ', ');
      if (length (opt) > 1 and aref (opt, 1) is not null)
        {
          opt_val := DB.DBA.GQL_GEN_EXPR (aref (opt, 1), _ctx);
          parts := concat (parts, opt_name, ' ', opt_val);
        }
      else
        parts := concat (parts, opt_name);
    contains_opt_next:;
    }

  if (parts = '')
    return '';
  return concat (' OPTION (', parts, ')');
}
;

----------------------------------------------------------------------
-- Expression → SPARQL expression translation
----------------------------------------------------------------------

create procedure DB.DBA.GQL_GEN_EXPR (in _expr any, inout _ctx any)
{
  declare etype varchar;
  declare lhs, rhs varchar;

  if (not isarray (_expr))
    return '""';

  etype := aref (_expr, 0);

  -- COUNT(*) special form
  if (etype = 'COUNTSTAR')
    return 'COUNT(*)';

  -- count(*) of a pre-aggregated query (GQL_PREAGG_REWRITE): the sum over
  -- the rows of the product of the leaves' counts -- an OPTIONAL leaf with
  -- no match counts 1.  The SUM goes in a sub-select (see the WHERE
  -- composition): COALESCE (SUM (...), 0) over a joined GROUP BY sub-select
  -- does not compile (VECSL), and SUM over no rows is NULL.
  if (etype = 'PREAGG_COUNT')
    {
      declare pc_prod, pc_f varchar;
      declare pc_i integer;
      pc_prod := '';
      for (pc_i := 0; pc_i < length (aref (_expr, 1)); pc_i := pc_i + 1)
        {
          pc_f := sprintf ('?gql_cnt_%d', aref (aref (aref (_expr, 1), pc_i), 0));
          if (aref (aref (aref (_expr, 1), pc_i), 1))
            pc_f := concat ('COALESCE(', pc_f, ', 1)');
          if (pc_prod = '')
            pc_prod := pc_f;
          else
            pc_prod := concat (pc_prod, ' * ', pc_f);
        }
      DB.DBA.GQL_CTX_SET (_ctx, 'preagg_sum', concat ('SUM(', pc_prod, ')'));
      -- Typed as count(*) is: beside a UNION the sum would be declared ANY,
      -- which ODBC clients receive as a string.
      return '<http://www.w3.org/2001/XMLSchema#integer>(COALESCE(?gql_cnt_sum, 0))';
    }

  -- Variable reference
  if (etype = 'VAR')
    {
      declare vname varchar;
      declare alias_var varchar;
      vname := aref (_expr, 1);
      if (vname = '*') return '*';
      alias_var := DB.DBA.GQL_CTX_GET_ALIAS (_ctx, vname);
      if (alias_var is not null)
        return alias_var;
      if (DB.DBA.GQL_CTX_MATERIALIZE_EDGE_VAR (_ctx, vname, 1))
        return DB.DBA.GQL_EDGE_SPARQL_VAR (vname);
      return DB.DBA.GQL_NODE_SPARQL_VAR (vname);
    }

  -- Literal values
  if (etype = 'LIT' or etype = 'LIT_BOOL')
    return DB.DBA.GQL_GEN_LITERAL (aref (_expr, 1));
  if (etype = 'FLOAT')
    return aref (_expr, 1);
  if (etype = 'IRI')
    {
      declare iri_uri any;
      iri_uri := DB.DBA.GQL_EXPAND_PREFIXED_NAME (_ctx, aref (_expr, 1));
      if (not isstring (iri_uri))
        iri_uri := aref (_expr, 1);
      return concat ('<', iri_uri, '>');
    }
  if (etype = 'PARAM')
    {
      -- If a value was supplied for this $parameter (published on the
      -- connection-scoped 'gql_bound_params' by GQL_TO_SPARQL_PARAMS), bind
      -- it as a typed SPARQL term. Values are formatted through
      -- GQL_PARAM_TO_SPARQL / GQL_GEN_LITERAL, so they are always escaped and
      -- can never alter the query structure (no string substitution, no
      -- substring collisions). An unbound parameter stays a SPARQL variable.
      declare pname, pkey, cand varchar;
      declare pbound, ppair any;
      declare pi integer;
      pname := aref (_expr, 1);
      -- The parser keeps the leading '$' (or '?') in the parameter name
      -- ('$v'); strip it so callers may supply names with or without it, and
      -- so an unbound parameter yields a valid SPARQL variable (?v, not ?$v
      -- or ??v -- the latter is a positional bind marker).
      pkey := pname;
      if (isstring (pkey) and length (pkey) > 0 and (aref (pkey, 0) = 36 or aref (pkey, 0) = 63))  -- '$' or '?'
        pkey := subseq (pkey, 1);
      -- A caller that binds values by position translates with
      -- gql_marker_mode set: the parameter becomes the placeholder
      -- ?__gql_m<k>, and its name is element k of gql_marker_seq.  The
      -- caller turns placeholders into positional markers afterwards, in
      -- the order of the final text -- which is not the order they are
      -- emitted in (WHERE patterns are generated before SELECT expressions).
      -- In 'auto' mode only the literals GQL_PARAM_REWRITE replaced are
      -- marked -- their names begin with chr (1), which the lexer never
      -- produces -- and in 'all' mode every named parameter is.
      {
        declare _mmode varchar;
        declare _mseq any;
        _mmode := connection_get ('gql_marker_mode');
        if (_mmode is not null and isstring (pkey)
            and (_mmode = 'all' or (length (pkey) > 0 and aref (pkey, 0) = 1)))
          {
            _mseq := connection_get ('gql_marker_seq');
            if (not isarray (_mseq))
              _mseq := vector ();
            connection_set ('gql_marker_seq', vector_concat (_mseq, vector (pkey)));
            return sprintf ('?__gql_m%d', length (_mseq));
          }
      }
      pbound := connection_get ('gql_bound_params');
      if (pbound is not null and isarray (pbound))
        {
          for (pi := 0; pi < length (pbound); pi := pi + 1)
            {
              ppair := aref (pbound, pi);
              if (isarray (ppair) and length (ppair) >= 2)
                {
                  cand := aref (ppair, 0);
                  if (isstring (cand) and length (cand) > 0 and aref (cand, 0) = 36)
                    cand := subseq (cand, 1);
                  if (cand = pkey)
                    return DB.DBA.GQL_PARAM_TO_SPARQL (aref (ppair, 1));
                }
            }
        }
      return concat ('?', pkey);  -- unbound parameter -> SPARQL variable
    }

  if (etype = 'CONTAINS')
    {
      declare ft_lhs, ft_rhs, ft_options varchar;
      ft_lhs := DB.DBA.GQL_GEN_EXPR (aref (_expr, 1), _ctx);
      ft_rhs := DB.DBA.GQL_GEN_EXPR (aref (_expr, 2), _ctx);
      ft_options := DB.DBA.GQL_GEN_CONTAINS_OPTIONS (aref (_expr, 3), _ctx);
      DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx,
        concat ('  ', ft_lhs, ' bif:contains ', ft_rhs, ft_options, ' .\n'));
      return 'true';
    }

  -- Property access: expr.prop → SPARQL variable for that property
  if (etype = 'PROP')
    {
      declare prop_var, prop_name varchar;
      declare subj varchar;
      declare prop_base any;
      -- Generate a unique SPARQL variable for this property access
      prop_name := aref (_expr, 2);
      prop_base := aref (_expr, 1);
      if (isarray (prop_base) and aref (prop_base, 0) = 'VAR')
        DB.DBA.GQL_CTX_MATERIALIZE_EDGE_VAR (_ctx, aref (prop_base, 1));
      subj := DB.DBA.GQL_GEN_EXPR (prop_base, _ctx);
      prop_var := DB.DBA.GQL_CTX_GET_PROP_VAR (_ctx, subj, prop_name);
      if (prop_var is not null)
        return prop_var;
      prop_var := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'prop_');
      DB.DBA.GQL_CTX_ADD_PROP_VAR (_ctx, subj, prop_name, prop_var);
      DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, subj, DB.DBA.GQL_GEN_PROP_IRI_CTX (prop_name, _ctx), prop_var);
      return prop_var;
    }

  -- Binary operators
  -- list [i], from 0: the element of a list literal, as a vector (generating
  -- the list as an expression would add an RDF collection to the pattern)
  if (etype = 'BINOP' and aref (_expr, 1) = '[]'
      and isarray (aref (_expr, 2)) and aref (aref (_expr, 2), 0) = 'LIST')
    return concat ('bif:aref(', DB.DBA.GQL_GEN_LIST_VECTOR (aref (_expr, 2), _ctx), ', ',
      DB.DBA.GQL_GEN_EXPR (aref (_expr, 3), _ctx), ')');
  if (etype = 'BINOP')
    {
      lhs := DB.DBA.GQL_GEN_EXPR (aref (_expr, 2), _ctx);
      rhs := DB.DBA.GQL_GEN_EXPR (aref (_expr, 3), _ctx);
      declare op varchar;
      op := aref (_expr, 1);
      if (op = '<>') op := '!=';
      else if (op = '=') op := '=';
      -- SPARQL has no XOR or IMPLIES
      else if (op = 'XOR')
        return concat ('((', lhs, ' || ', rhs, ') && !(', lhs, ' && ', rhs, '))');
      else if (op = 'IMPLIES')
        return concat ('(!(', lhs, ') || ', rhs, ')');
      else if (op = '[]')
        return concat ('bif:aref(', lhs, ', ', rhs, ')');
      else if (op = 'LIKE')
        {
          declare raw_rhs any;
          raw_rhs := aref (_expr, 3);
          if (isarray (raw_rhs) and aref (raw_rhs, 0) = 'LIT' and isstring (aref (raw_rhs, 1)))
            return concat ('REGEX(STR(', lhs, '), ',
              DB.DBA.GQL_GEN_LITERAL (DB.DBA.GQL_LIKE_PATTERN_TO_REGEX (aref (raw_rhs, 1))), ')');
          return concat ('REGEX(STR(', lhs, '), STR(', rhs, '))');
        }
      return concat ('(', lhs, ' ', op, ' ', rhs, ')');
    }

  -- Unary operators
  if (etype = 'UNOP')
    {
      declare uexpr varchar;
      uexpr := DB.DBA.GQL_GEN_EXPR (aref (_expr, 2), _ctx);
      if (aref (_expr, 1) = 'NOT')
        return concat ('(!(', uexpr, '))');
      return concat ('(', aref (_expr, 1), ' ', uexpr, ')');
    }

  -- Function calls
  if (etype = 'FUNC' or etype = 'FUNC_DISTINCT')
    {
      declare fname, fname_orig, fargs varchar;
      declare fi integer;
      declare args_vec any;
      declare distinct_kw varchar;
      fname_orig := aref (_expr, 1);
      fname := lower (cast (fname_orig as varchar));
      fargs := '';
      if (etype = 'FUNC_DISTINCT')
        {
          args_vec := aref (_expr, 2);
          distinct_kw := 'DISTINCT ';
        }
      else
        {
          args_vec := aref (_expr, 3);
          distinct_kw := '';
        }
      -- EXISTS ((c)-[:R]->(a)) is the pattern predicate itself.
      if (fname = 'exists' and length (args_vec) = 1
          and isarray (aref (args_vec, 0)) and aref (aref (args_vec, 0), 0) = 'PATTERNPRED')
        return DB.DBA.GQL_GEN_EXPR (aref (args_vec, 0), _ctx);
      if (lower (fname) = 'degree_centrality')
        return DB.DBA.GQL_GEN_DEGREE_CENTRALITY (args_vec, _ctx);
      if (lower (fname) = 'eigenvector_centrality')
        return DB.DBA.GQL_GEN_GRAPH_CENTRALITY_EXPR (args_vec, _ctx, 'eigenvector');
      if (lower (fname) = 'closeness_centrality')
        return DB.DBA.GQL_GEN_GRAPH_CENTRALITY_EXPR (args_vec, _ctx, 'closeness');
      if (lower (fname) = 'betweenness_centrality')
        return DB.DBA.GQL_GEN_GRAPH_CENTRALITY_EXPR (args_vec, _ctx, 'betweenness');
      -- List value functions over the Virtuoso vector form. A list LITERAL is
      -- emitted as bif:vector(...) — a scalar value — rather than the RDF
      -- collection form used for membership/expansion (UNNEST/IN/FOR), so
      -- length/trim work. Handled BEFORE the generic argument loop below so a
      -- list argument is not also materialized as rdf:first/rdf:rest triples.
      if ((fname = 'cardinality' or fname = 'size')
          and length (args_vec) = 1
          and isarray (aref (args_vec, 0)) and aref (aref (args_vec, 0), 0) = 'LIST')
        return concat ('bif:length(',
          DB.DBA.GQL_GEN_LIST_VECTOR (aref (args_vec, 0), _ctx), ')');
      if (fname = 'trim' and length (args_vec) = 2)
        {
          declare _lst_sparql varchar;
          if (isarray (aref (args_vec, 0)) and aref (aref (args_vec, 0), 0) = 'LIST')
            _lst_sparql := DB.DBA.GQL_GEN_LIST_VECTOR (aref (args_vec, 0), _ctx);
          else
            _lst_sparql := DB.DBA.GQL_GEN_EXPR (aref (args_vec, 0), _ctx);
          return concat ('sql:GQL_LIST_TRIM(', _lst_sparql, ', ',
            DB.DBA.GQL_GEN_EXPR (aref (args_vec, 1), _ctx), ')');
        }
      for (fi := 0; fi < length (args_vec); fi := fi + 1)
        {
          if (fargs <> '') fargs := concat (fargs, ', ');
          fargs := concat (fargs, DB.DBA.GQL_GEN_EXPR (aref (args_vec, fi), _ctx));
        }
      -- SPARQL extension functions: sql:NAME(...) / bif:NAME(...) pass through
      -- verbatim so users can call any Virtuoso SQL function or built-in.
      if ((length (fname) > 4 and subseq (fname, 0, 4) = 'sql:')
          or (length (fname) > 4 and subseq (fname, 0, 4) = 'bif:'))
        return concat (fname_orig, '(', fargs, ')');
      -- Aggregate functions: map GQL names to SPARQL built-ins (with optional DISTINCT)
      if (fname = 'count') return concat ('COUNT(', distinct_kw, fargs, ')');
      if (fname = 'sum') return concat ('SUM(', distinct_kw, fargs, ')');
      if (fname = 'avg') return concat ('AVG(', distinct_kw, fargs, ')');
      if (fname = 'min') return concat ('MIN(', distinct_kw, fargs, ')');
      if (fname = 'max') return concat ('MAX(', distinct_kw, fargs, ')');
      if (fname = 'sample') return concat ('SAMPLE(', distinct_kw, fargs, ')');
      if (fname = 'group_concat')
        return concat ('GROUP_CONCAT(', distinct_kw, fargs, ')');
      -- Path materialisation helpers for MATCH SHORTEST PATH p = ...
      if (length (args_vec) = 1 and isarray (aref (args_vec, 0))
          and aref (aref (args_vec, 0), 0) = 'VAR')
        {
          declare path_arg varchar;
          path_arg := aref (aref (args_vec, 0), 1);
          if (fname = 'path_id')
            return DB.DBA.GQL_PATH_FIELD_VAR (path_arg, 'id');
          if (fname = 'path_step')
            return DB.DBA.GQL_PATH_FIELD_VAR (path_arg, 'step_value');
          if (fname = 'path_step_iri')
            return DB.DBA.GQL_PATH_FIELD_VAR (path_arg, 'step');
          if (fname = 'path_index')
            return DB.DBA.GQL_PATH_FIELD_VAR (path_arg, 'index');
          if (fname = 'path_node')
            return DB.DBA.GQL_PATH_FIELD_VAR (path_arg, 'node');
          if (fname = 'path_cost' or fname = 'path_weight')
            return DB.DBA.GQL_PATH_FIELD_VAR (path_arg, 'cost');
          if (fname = 'path_value')
            return DB.DBA.GQL_PATH_FIELD_VAR (path_arg, 'value');
        }
      -- General functions: map GQL names to SPARQL built-ins where they differ.
      -- Case conversion
      if (fname = 'upper') return concat ('UCASE(', fargs, ')');
      if (fname = 'lower') return concat ('LCASE(', fargs, ')');
      -- String functions
      if (fname = 'substring') return concat ('SUBSTR(', fargs, ')');
      if (fname = 'length') return concat ('STRLEN(', fargs, ')');
      if (fname = 'replace') return concat ('REPLACE(', fargs, ')');
      if (fname = 'concat') return concat ('CONCAT(', fargs, ')');
      -- Single-argument string trim. TRIM(list, n) (two args) is a list
      -- function handled earlier via the Virtuoso vector form.
      if (fname = 'trim') return concat ('bif:trim(', fargs, ')');
      -- String functions via bif: pass-through
      if (fname = 'left') return concat ('bif:left(', fargs, ')');
      if (fname = 'right') return concat ('bif:right(', fargs, ')');
      if (fname = 'btrim') return concat ('bif:trim(', fargs, ')');
      if (fname = 'ltrim') return concat ('bif:ltrim(', fargs, ')');
      if (fname = 'rtrim') return concat ('bif:rtrim(', fargs, ')');
      if (fname = 'char_length') return concat ('bif:length(', fargs, ')');
      if (fname = 'character_length') return concat ('bif:length(', fargs, ')');
      if (fname = 'octet_length' or fname = 'byte_length')
        return concat ('bif:length(sql:GQL_UTF8(', fargs, '))');
      -- Unicode normalization via gqlc C plugin BIFs
      if (fname = 'normalize')
        {
          DB.DBA.GQL_REQUIRE_GQLC ('NORMALIZE');
          -- the plugin takes UTF-8; a non-ASCII literal is a wide string
          if (length (args_vec) > 1)
            return concat ('bif:GQL_NORMALIZE(sql:GQL_UTF8(', DB.DBA.GQL_GEN_EXPR (aref (args_vec, 0), _ctx), '), ',
              DB.DBA.GQL_GEN_EXPR (aref (args_vec, 1), _ctx), ')');
          return concat ('bif:GQL_NORMALIZE(sql:GQL_UTF8(', fargs, '))');
        }
      -- List/cardinality functions via bif: pass-through
      if (fname = 'cardinality') return concat ('bif:length(', fargs, ')');
      if (fname = 'size') return concat ('bif:length(', fargs, ')');
      -- Numeric functions (same name in SPARQL, mapped explicitly for clarity)
      if (fname = 'abs') return concat ('ABS(', fargs, ')');
      if (fname = 'ceil') return concat ('CEIL(', fargs, ')');
      if (fname = 'ceiling') return concat ('bif:ceiling(', fargs, ')');
      if (fname = 'floor') return concat ('FLOOR(', fargs, ')');
      if (fname = 'round') return concat ('ROUND(', fargs, ')');
      -- Numeric functions via bif: pass-through (not in SPARQL standard)
      if (fname = 'sqrt') return concat ('bif:sqrt(', fargs, ')');
      if (fname = 'exp') return concat ('bif:exp(', fargs, ')');
      if (fname = 'log' and length (args_vec) = 2)
        return concat ('(bif:log(', DB.DBA.GQL_GEN_EXPR (aref (args_vec, 1), _ctx), ') / bif:log(',
          DB.DBA.GQL_GEN_EXPR (aref (args_vec, 0), _ctx), '))');
      if (fname = 'log') return concat ('bif:log(', fargs, ')');
      if (fname = 'log10') return concat ('bif:log10(', fargs, ')');
      if (fname = 'ln') return concat ('bif:log(', fargs, ')');
      if (fname = 'power') return concat ('bif:power(', fargs, ')');
      if (fname = 'mod') return concat ('bif:mod(', fargs, ')');
      if (fname = 'sin') return concat ('bif:sin(', fargs, ')');
      if (fname = 'cos') return concat ('bif:cos(', fargs, ')');
      if (fname = 'tan') return concat ('bif:tan(', fargs, ')');
      if (fname = 'cot') return concat ('bif:cot(', fargs, ')');
      if (fname = 'asin') return concat ('bif:asin(', fargs, ')');
      if (fname = 'acos') return concat ('bif:acos(', fargs, ')');
      if (fname = 'atan') return concat ('bif:atan(', fargs, ')');
      if (fname = 'degrees') return concat ('bif:degrees(', fargs, ')');
      if (fname = 'radians') return concat ('bif:radians(', fargs, ')');
      -- Hyperbolic functions via PL procedures (must use sql: not bif:)
      if (fname = 'sinh') return concat ('sql:GQL_SINH(', fargs, ')');
      if (fname = 'cosh') return concat ('sql:GQL_COSH(', fargs, ')');
      if (fname = 'tanh') return concat ('sql:GQL_TANH(', fargs, ')');
      -- Duration functions via PL procedures (must use sql: not bif:)
      if (fname = 'duration') return concat ('STRDT(sql:GQL_DURATION(', fargs, '), xsd:duration)');
      if (fname = 'duration_between') return concat ('sql:GQL_DURATION_BETWEEN(', fargs, ')');
      -- Geospatial functions via bif: pass-through
      if (fname = 'st_intersects') return concat ('bif:st_intersects(', fargs, ')');
      if (fname = 'st_contains') return concat ('bif:st_contains(', fargs, ')');
      if (fname = 'st_within') return concat ('bif:st_within(', fargs, ')');
      if (fname = 'st_may_intersect') return concat ('bif:st_may_intersect(', fargs, ')');
      if (fname = 'st_distance') return concat ('bif:st_distance(', fargs, ')');
      if (fname = 'st_area')
        signal ('G2004', 'ST_AREA is not available: Virtuoso has no area function for geometries');
      if (fname = 'st_x') return concat ('bif:st_x(', fargs, ')');
      if (fname = 'st_y') return concat ('bif:st_y(', fargs, ')');
      -- Aggregate functions via native sql: user-defined aggregates
      if (fname = 'stddev') return concat ('sql:STDDEV(', distinct_kw, fargs, ')');
      if (fname = 'stddev_samp') return concat ('sql:STDDEV_SAMP(', distinct_kw, fargs, ')');
      if (fname = 'stddev_pop') return concat ('sql:STDDEV_POP(', distinct_kw, fargs, ')');
      -- Aggregate functions via gqlc C plugin BIFs
      if (fname = 'percentile_cont')
        {
          DB.DBA.GQL_REQUIRE_GQLC ('PERCENTILE_CONT');
          -- an aggregate: the percentile of the group's values
          if (length (args_vec) = 2)
            return concat ('bif:GQL_PERCENTILE_CONT(sql:VECTOR_AGG(', DB.DBA.GQL_GEN_EXPR (aref (args_vec, 0), _ctx), '), ',
              DB.DBA.GQL_GEN_EXPR (aref (args_vec, 1), _ctx), ')');
          return concat ('bif:GQL_PERCENTILE_CONT(', fargs, ')');
        }
      if (fname = 'percentile_disc')
        {
          DB.DBA.GQL_REQUIRE_GQLC ('PERCENTILE_DISC');
          if (length (args_vec) = 2)
            return concat ('bif:GQL_PERCENTILE_DISC(sql:VECTOR_AGG(', DB.DBA.GQL_GEN_EXPR (aref (args_vec, 0), _ctx), '), ',
              DB.DBA.GQL_GEN_EXPR (aref (args_vec, 1), _ctx), ')');
          return concat ('bif:GQL_PERCENTILE_DISC(', fargs, ')');
        }
      if (fname = 'collect_list') return concat ('sql:VECTOR_AGG(', fargs, ')');
      -- Temporal functions (same name in SPARQL)
      if (fname = 'year') return concat ('YEAR(', fargs, ')');
      if (fname = 'month') return concat ('MONTH(', fargs, ')');
      if (fname = 'day') return concat ('DAY(', fargs, ')');
      if (fname = 'hours') return concat ('HOURS(', fargs, ')');
      if (fname = 'minutes') return concat ('MINUTES(', fargs, ')');
      if (fname = 'seconds') return concat ('SECONDS(', fargs, ')');
      -- RDF/literal functions (same name in SPARQL)
      if (fname = 'str') return concat ('STR(', fargs, ')');
      if (fname = 'lang') return concat ('LANG(', fargs, ')');
      if (fname = 'datatype') return concat ('DATATYPE(', fargs, ')');
      if (fname = 'iri') return concat ('IRI(', fargs, ')');
      if (fname = 'bnode') return concat ('BNODE(', fargs, ')');
      if (fname = 'strdt') return concat ('STRDT(', fargs, ')');
      if (fname = 'strlang') return concat ('STRLANG(', fargs, ')');
      -- Predicate functions (same name in SPARQL)
      -- (fname is lower case: these compare lower case names)
      if (fname = 'isiri' or fname = 'is_iri') return concat ('isIRI(', fargs, ')');
      if (fname = 'isliteral' or fname = 'is_literal') return concat ('isLiteral(', fargs, ')');
      if (fname = 'isblank' or fname = 'is_blank') return concat ('isBlank(', fargs, ')');
      if (fname = 'isnumeric' or fname = 'is_numeric') return concat ('isNumeric(', fargs, ')');
      if (fname = 'sameterm' or fname = 'same_term') return concat ('sameTerm(', fargs, ')');
      if (fname = 'langmatches' or fname = 'lang_matches') return concat ('langMatches(', fargs, ')');
      if (fname = 'starts_with') return concat ('STRSTARTS(', fargs, ')');
      if (fname = 'ends_with') return concat ('STRENDS(', fargs, ')');
      if (fname = 'regex') return concat ('REGEX(', fargs, ')');
      if (fname = 'contains') return concat ('CONTAINS(', fargs, ')');
      if (fname = 'strstarts') return concat ('STRSTARTS(', fargs, ')');
      if (fname = 'strends') return concat ('STRENDS(', fargs, ')');
      if (fname = 'encode_for_uri') return concat ('ENCODE_FOR_URI(', fargs, ')');
      -- Conditional
      if (fname = 'coalesce') return concat ('COALESCE(', fargs, ')');
      if (fname = 'if') return concat ('IF(', fargs, ')');
      if (fname = 'nullif' and length (args_vec) = 2)
        {
          declare nf_a, nf_b varchar;
          nf_a := DB.DBA.GQL_GEN_EXPR (aref (args_vec, 0), _ctx);
          nf_b := DB.DBA.GQL_GEN_EXPR (aref (args_vec, 1), _ctx);
          return concat ('IF(', nf_a, ' = ', nf_b, ', ', DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'nullif_'), ', ', nf_a, ')');
        }
      if (fname = 'greatest') return concat ('bif:__max(', fargs, ')');
      if (fname = 'least') return concat ('bif:__min(', fargs, ')');
      -- DATE (expr), TIME (expr), DATETIME / TIMESTAMP (expr): conversions
      if (fname = 'date' and length (args_vec) = 1) return concat ('xsd:date(', fargs, ')');
      if (fname = 'time' and length (args_vec) = 1) return concat ('xsd:time(', fargs, ')');
      if ((fname = 'datetime' or fname = 'timestamp') and length (args_vec) = 1)
        return concat ('xsd:dateTime(', fargs, ')');
      -- Datetime functions via bif: pass-through
      if (fname = 'current_date') return concat ('bif:current_date(', fargs, ')');
      if (fname = 'current_time') return concat ('bif:current_time(', fargs, ')');
      if (fname = 'current_timestamp') return concat ('bif:current_timestamp(', fargs, ')');
      if (fname = 'local_time') return concat ('bif:curtime(', fargs, ')');
      if (fname = 'local_timestamp') return concat ('bif:now(', fargs, ')');
      -- Existence
      if (fname = 'bound') return concat ('BOUND(', fargs, ')');
      if (fname = 'exists') return concat ('EXISTS { ', fargs, ' }');
      -- Element identity
      if (fname = 'element_id') return concat ('STR(', fargs, ')');
      -- RDF 1.2 triple-term accessors (same name in SPARQL)
      if (fname = 'triple') return concat ('TRIPLE(', fargs, ')');
      if (fname = 'subject') return concat ('SUBJECT(', fargs, ')');
      if (fname = 'predicate') return concat ('PREDICATE(', fargs, ')');
      if (fname = 'object') return concat ('OBJECT(', fargs, ')');
      if (fname = 'istriple' or fname = 'is_triple') return concat ('isTRIPLE(', fargs, ')');
      -- Default pass-through for sql:, bif:, and unknown functions
      return concat (fname_orig, '(', fargs, ')');
    }

  -- CAST(expr AS type)
  if (etype = 'CAST')
    {
      declare cast_val varchar;
      declare cast_type varchar;
      cast_val := DB.DBA.GQL_GEN_EXPR (aref (_expr, 1), _ctx);
      cast_type := aref (_expr, 2);
      return concat ('sql:GQL_CAST(', cast_val, ', ', DB.DBA.GQL_GEN_LITERAL (cast_type), ')');
    }

  -- IS NULL / IS NOT NULL
  if (etype = 'ISNULL')
    {
      lhs := DB.DBA.GQL_GEN_EXPR (aref (_expr, 1), _ctx);
      if (aref (_expr, 2) = 1)
        return concat ('(BOUND(', lhs, '))');
      return concat ('(!BOUND(', lhs, '))');
    }

  -- IS DIRECTED / IS NOT DIRECTED — all RDF edges are directed
  if (etype = 'IS_DIRECTED')
    {
      if (aref (_expr, 2) = 1)
        return '(1 = 0)';
      return '(1 = 1)';
    }

  -- IS NORMALIZED / IS NOT NORMALIZED — via gqlc C plugin BIF
  if (etype = 'IS_NORMALIZED')
    {
      declare in_lhs, in_form varchar;
      DB.DBA.GQL_REQUIRE_GQLC ('IS NORMALIZED');
      in_lhs := DB.DBA.GQL_GEN_EXPR (aref (_expr, 1), _ctx);
      in_form := aref (_expr, 2);
      if (in_form is null or in_form = '')
        in_form := 'NFC';
      if (aref (_expr, 3) = 1)
        return concat ('(!bif:GQL_IS_NORMALIZED(', in_lhs, ', ', DB.DBA.GQL_GEN_LITERAL (in_form), '))');
      return concat ('(bif:GQL_IS_NORMALIZED(', in_lhs, ', ', DB.DBA.GQL_GEN_LITERAL (in_form), '))');
    }

  -- IS TYPED <type>
  if (etype = 'IS_TYPED')
    {
      declare tt_lhs, tt_type varchar;
      declare tt_types any;
      tt_lhs := DB.DBA.GQL_GEN_EXPR (aref (_expr, 1), _ctx);
      tt_type := aref (_expr, 2);
      tt_types := vector (
        'INTEGER', 'http://www.w3.org/2001/XMLSchema#integer',
        'INT', 'http://www.w3.org/2001/XMLSchema#integer',
        'STRING', 'http://www.w3.org/2001/XMLSchema#string',
        'BOOLEAN', 'http://www.w3.org/2001/XMLSchema#boolean',
        'BOOL', 'http://www.w3.org/2001/XMLSchema#boolean',
        'FLOAT', 'http://www.w3.org/2001/XMLSchema#float',
        'DOUBLE', 'http://www.w3.org/2001/XMLSchema#double',
        'DATE', 'http://www.w3.org/2001/XMLSchema#date',
        'TIME', 'http://www.w3.org/2001/XMLSchema#time',
        'DATETIME', 'http://www.w3.org/2001/XMLSchema#dateTime',
        'TIMESTAMP', 'http://www.w3.org/2001/XMLSchema#dateTime');
      declare tt_idx integer;
      declare tt_xsd varchar;
      tt_xsd := null;
      for (tt_idx := 0; tt_idx < length (tt_types); tt_idx := tt_idx + 2)
        {
          if (upper (tt_type) = aref (tt_types, tt_idx))
            { tt_xsd := aref (tt_types, tt_idx + 1); goto tt_found; }
        }
      tt_found:
      if (tt_xsd is null)
        tt_xsd := concat ('http://www.w3.org/2001/XMLSchema#', lower (tt_type));
      if (aref (_expr, 3) = 1)
        return concat ('(DATATYPE(', tt_lhs, ') != <', tt_xsd, '>)');
      return concat ('(DATATYPE(', tt_lhs, ') = <', tt_xsd, '>)');
    }

  -- IS SOURCE OF / IS DESTINATION OF: the node is the subject (object) of
  -- the stored edge the edge variable denotes.
  if (etype = 'IS_SOURCE_OF' or etype = 'IS_DEST_OF')
    {
      declare so_lhs, so_end varchar;
      declare so_edge any;
      so_edge := aref (_expr, 2);
      so_end := null;
      if (isarray (so_edge) and length (so_edge) > 1 and aref (so_edge, 0) = 'VAR')
        so_end := DB.DBA.GQL_CTX_EDGE_END (_ctx, aref (so_edge, 1),
          case when etype = 'IS_SOURCE_OF' then 1 else 2 end);
      if (so_end is null)
        signal ('G3012', sprintf ('IS %s OF needs the variable of a single edge',
          case when etype = 'IS_SOURCE_OF' then 'SOURCE' else 'DESTINATION' end));
      so_lhs := DB.DBA.GQL_GEN_EXPR (aref (_expr, 1), _ctx);
      if (aref (_expr, 3) = 1)
        return concat ('(', so_lhs, ' != ', so_end, ')');
      return concat ('(', so_lhs, ' = ', so_end, ')');
    }

  -- IS LABEL — check rdf:type
  if (etype = 'ISLABEL')
    {
      declare il_lhs, il_label varchar;
      il_lhs := DB.DBA.GQL_GEN_EXPR (aref (_expr, 1), _ctx);
      il_label := DB.DBA.GQL_GEN_LABEL_IRI_CTX (aref (_expr, 2), _ctx);
      return concat ('EXISTS { ', il_lhs, ' rdf:type ', il_label, ' }');
    }

  -- String concatenation operator (||)
  if (etype = 'STROP')
    {
      declare sc_lhs, sc_rhs varchar;
      sc_lhs := DB.DBA.GQL_GEN_EXPR (aref (_expr, 2), _ctx);
      sc_rhs := DB.DBA.GQL_GEN_EXPR (aref (_expr, 3), _ctx);
      return concat ('CONCAT(', sc_lhs, ', ', sc_rhs, ')');
    }

  -- ALL_DIFFERENT (var1, var2, ...) — pairwise inequality
  if (etype = 'ALL_DIFFERENT')
    {
      declare ad_args any;
      declare ad_i, ad_j integer;
      declare ad_lhs, ad_rhs varchar;
      declare ad_result varchar;
      ad_args := aref (_expr, 1);
      ad_result := '';
      for (ad_i := 0; ad_i < length (ad_args); ad_i := ad_i + 1)
        {
          for (ad_j := ad_i + 1; ad_j < length (ad_args); ad_j := ad_j + 1)
            {
              ad_lhs := DB.DBA.GQL_GEN_EXPR (aref (ad_args, ad_i), _ctx);
              ad_rhs := DB.DBA.GQL_GEN_EXPR (aref (ad_args, ad_j), _ctx);
              if (ad_result <> '') ad_result := concat (ad_result, ' && ');
              ad_result := concat (ad_result, '(', ad_lhs, ' != ', ad_rhs, ')');
            }
        }
      if (ad_result = '') return '(1 = 1)';
      return concat ('(', ad_result, ')');
    }

  -- SAME (var1, var2, ...) — all equal
  if (etype = 'SAME_PRED')
    {
      declare sm_args any;
      declare sm_i integer;
      declare sm_lhs, sm_rhs varchar;
      declare sm_result varchar;
      sm_args := aref (_expr, 1);
      sm_result := '';
      for (sm_i := 1; sm_i < length (sm_args); sm_i := sm_i + 1)
        {
          sm_lhs := DB.DBA.GQL_GEN_EXPR (aref (sm_args, 0), _ctx);
          sm_rhs := DB.DBA.GQL_GEN_EXPR (aref (sm_args, sm_i), _ctx);
          if (sm_result <> '') sm_result := concat (sm_result, ' && ');
          sm_result := concat (sm_result, '(', sm_lhs, ' = ', sm_rhs, ')');
        }
      if (sm_result = '') return '(1 = 1)';
      return concat ('(', sm_result, ')');
    }

  -- PROPERTY_EXISTS (var, propName) — EXISTS check on property triple
  if (etype = 'PROP_EXISTS')
    {
      declare pe_lhs, pe_prop varchar;
      declare pe_prop_iri varchar;
      pe_lhs := DB.DBA.GQL_GEN_EXPR (aref (_expr, 1), _ctx);
      pe_prop := aref (_expr, 2);
      pe_prop_iri := concat ('<', DB.DBA.GQL_TERM_URI (_ctx, pe_prop, 'property'), '>');
      return concat ('EXISTS { ', pe_lhs, ' ', pe_prop_iri, ' ?pe_val }');
    }

  -- IN expression
  if (etype = 'INEXPR')
    {
      lhs := DB.DBA.GQL_GEN_EXPR (aref (_expr, 1), _ctx);
      -- x IN [a, b]: the list's items (as an expression the list would be
      -- an RDF collection the data has to hold)
      if (isarray (aref (_expr, 2)) and aref (aref (_expr, 2), 0) = 'LIST')
        {
          declare in_items any;
          declare in_i integer;
          in_items := aref (aref (_expr, 2), 1);
          if (length (in_items) = 0)
            return 'false';
          rhs := '';
          for (in_i := 0; in_i < length (in_items); in_i := in_i + 1)
            rhs := concat (rhs, case when in_i > 0 then ', ' else '' end,
              DB.DBA.GQL_GEN_EXPR (aref (in_items, in_i), _ctx));
          return concat ('(', lhs, ' IN (', rhs, '))');
        }
      rhs := DB.DBA.GQL_GEN_EXPR (aref (_expr, 2), _ctx);
      return concat ('(', lhs, ' IN (', rhs, '))');
    }

  -- CASE expression
  if (etype = 'CASEEXPR')
    {
      declare c_expr varchar;
      declare ci integer;
      declare case_operand, whens_vec, else_e any;
      case_operand := aref (_expr, 1);
      whens_vec := aref (_expr, 2);
      else_e := aref (_expr, 3);
      c_expr := 'IF(';
      for (ci := 0; ci < length (whens_vec); ci := ci + 1)
        {
          declare w any;
          w := aref (whens_vec, ci);
          if (c_expr <> 'IF(') c_expr := concat (c_expr, ', IF(');
          c_expr := concat (c_expr, DB.DBA.GQL_GEN_EXPR (aref (w, 0), _ctx), ', ', DB.DBA.GQL_GEN_EXPR (aref (w, 1), _ctx));
        }
      if (else_e is not null)
        c_expr := concat (c_expr, ', ', DB.DBA.GQL_GEN_EXPR (else_e, _ctx));
      for (ci := 1; ci < length (whens_vec); ci := ci + 1)
        c_expr := concat (c_expr, ')');
      c_expr := concat (c_expr, ')');
      return c_expr;
    }

  -- Pattern predicate: WHERE (c)-[:R]->(a) holds when the pattern has a
  -- match for the bindings in scope -- EXISTS { MATCH (c)-[:R]->(a) }.  A lone
  -- parenthesised node, (x), is the variable itself.
  if (etype = 'PATTERNPRED')
    {
      declare pp_pat, pp_elems any;
      pp_pat := aref (_expr, 1);
      pp_elems := null;
      if (isarray (pp_pat) and aref (pp_pat, 0) = 'PATTERN')
        pp_elems := aref (pp_pat, 1);
      if (isarray (pp_elems) and length (pp_elems) = 1
          and isarray (aref (pp_elems, 0)) and aref (aref (pp_elems, 0), 0) = 'NODE'
          and aref (aref (pp_elems, 0), 1) is not null
          and length (aref (aref (pp_elems, 0), 2)) = 0
          and length (aref (aref (pp_elems, 0), 3)) = 0)
        return DB.DBA.GQL_GEN_EXPR (vector ('VAR', aref (aref (pp_elems, 0), 1)), _ctx);
      -- One undirected edge without a quantifier: one EXISTS per orientation.
      -- Each is a semi-join on one triple; an EXISTS over the edge's UNION
      -- would run as a correlated sub-query for every row it filters.
      if (isarray (pp_elems) and length (pp_elems) = 3
          and isarray (aref (pp_elems, 1)) and aref (aref (pp_elems, 1), 0) = 'EDGE'
          and (aref (aref (pp_elems, 1), 3) = 'BOTH' or aref (aref (pp_elems, 1), 3) = 'UNDIRECTED')
          and aref (aref (pp_elems, 1), 4) is null)
        {
          declare pp_out, pp_in any;
          pp_out := DB.DBA.GQL_EDGE_WITH_DIRECTION (aref (pp_elems, 1), 'RIGHT');
          pp_in := DB.DBA.GQL_EDGE_WITH_DIRECTION (aref (pp_elems, 1), 'LEFT');
          return concat ('(',
            DB.DBA.GQL_GEN_EXPR (vector ('PATTERNPRED', vector ('PATTERN',
              vector (aref (pp_elems, 0), pp_out, aref (pp_elems, 2)))), _ctx),
            ' || ',
            DB.DBA.GQL_GEN_EXPR (vector ('PATTERNPRED', vector ('PATTERN',
              vector (aref (pp_elems, 0), pp_in, aref (pp_elems, 2)))), _ctx),
            ')');
        }
      return DB.DBA.GQL_GEN_EXPR (vector ('EXISTS_SUBQUERY',
          vector ('QUERY', vector (vector ('MATCH', 0, vector (pp_pat), null, 0, null, null)), null)),
        _ctx);
    }

  -- EXISTS subquery: EXISTS { MATCH ... WHERE ... }
  if (etype = 'EXISTS_SUBQUERY')
    {
      declare sub_ctx any;
      declare sub_query, sub_clauses any;
      declare sub_body varchar;
      declare si integer;

      sub_query := aref (_expr, 1);
      if (not isarray (sub_query) or aref (sub_query, 0) <> 'QUERY')
        return 'EXISTS { }';

      sub_ctx := DB.DBA.GQL_CTX_NEW_INNER (_ctx);
      DB.DBA.GQL_CTX_SET (sub_ctx, 'suppress_default_from', 1);

      sub_clauses := aref (sub_query, 1);
      for (si := 0; si < length (sub_clauses); si := si + 1)
        {
          declare sclause, sctype any;
          sclause := aref (sub_clauses, si);
          if (not isarray (sclause)) goto sub_next;
          sctype := aref (sclause, 0);
          if (sctype = 'MATCH')
            DB.DBA.GQL_GEN_MATCH (sclause, sub_ctx);
          else if (sctype = 'WHERE' or sctype = 'FILTER')
            {
              declare swexpr varchar;
              swexpr := DB.DBA.GQL_GEN_EXPR (aref (sclause, 1), sub_ctx);
              DB.DBA.GQL_CTX_ADD_FILTER (sub_ctx, swexpr);
            }
        sub_next:;
        }

      sub_body := DB.DBA.GQL_CTX_GET (sub_ctx, 'pre_values');
      sub_body := concat (sub_body, DB.DBA.GQL_CTX_GET (sub_ctx, 'pre_binds'));
      sub_body := concat (sub_body, DB.DBA.GQL_CTX_GET (sub_ctx, 'triples'));
      sub_body := concat (sub_body, DB.DBA.GQL_CTX_GET (sub_ctx, 'binds'));
      sub_body := concat (sub_body, DB.DBA.GQL_CTX_GET (sub_ctx, 'filters'));

      DB.DBA.GQL_CTX_SET (_ctx, 'var_counter', DB.DBA.GQL_CTX_GET (sub_ctx, 'var_counter'));
      -- Merge sub-ctx vars into parent so outer query sees them
      DB.DBA.GQL_CTX_MERGE_PROP_CACHE (_ctx, sub_ctx);

      if (sub_body = '')
        return 'EXISTS { }';
      return concat ('EXISTS { ', sub_body, ' }');
    }

  -- TYPEDLIT: DATE '...', TIMESTAMP '...', TIME '...', DATETIME '...'
  if (etype = 'TYPEDLIT')
    {
      declare tlit_type, tlit_val varchar;
      declare xsd_type varchar;
      tlit_type := aref (_expr, 1);
      tlit_val := aref (_expr, 2);
      if (tlit_type = 'DATE')
        xsd_type := 'xsd:date';
      else if (tlit_type = 'TIME')
        xsd_type := 'xsd:time';
      else if (tlit_type = 'TIMESTAMP')
        xsd_type := 'xsd:dateTime';
      else if (tlit_type = 'DATETIME')
        xsd_type := 'xsd:dateTime';
      else
        xsd_type := concat ('xsd:', lower (tlit_type));
      return concat ('"', tlit_val, '"^^', xsd_type);
    }

  -- TYPEDLIT_IRI: "value"^^prefixed:name  or  "value"^^<absolute-iri>
  if (etype = 'TYPEDLIT_IRI')
    {
      declare tli_val, tli_dt varchar;
      declare tli_expanded varchar;
      tli_val := aref (_expr, 1);
      tli_dt := aref (_expr, 2);
      -- If it's a PNAME_NS, expand via prefix table; if IRIREF, use as-is
      tli_expanded := DB.DBA.GQL_EXPAND_PREFIXED_NAME (_ctx, tli_dt);
      if (tli_expanded is null or tli_expanded = '')
        tli_expanded := tli_dt;  -- already an absolute IRI or unresolvable
      return concat ('"', tli_val, '"^^<', tli_expanded, '>');
    }

  -- LIST literal: encode as RDF collection (rdf:first/rdf:rest)
  if (etype = 'LIST')
    {
      declare items any;
      declare li integer;
      declare list_var, head_var, prev_var varchar;
      items := aref (_expr, 1);
      if (length (items) = 0)
        return 'rdf:nil';
      list_var := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'list_');
      head_var := list_var;
      for (li := 0; li < length (items); li := li + 1)
        {
          if (li = 0)
            {
              DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, head_var, 'rdf:first',
                DB.DBA.GQL_GEN_EXPR (aref (items, li), _ctx));
            }
          else
            {
              prev_var := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'list_');
              DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, prev_var, 'rdf:first',
                DB.DBA.GQL_GEN_EXPR (aref (items, li), _ctx));
              DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, head_var, 'rdf:rest', prev_var);
              head_var := prev_var;
            }
        }
      DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, head_var, 'rdf:rest', 'rdf:nil');
      return list_var;
    }

  -- RECORD literal: <{ key: val, ... }> → blank node with predicate-per-field
  if (etype = 'RECORD')
    {
      declare rec_keys, rec_vals any;
      declare ri integer;
      declare rec_var varchar;
      rec_keys := aref (_expr, 1);
      rec_vals := aref (_expr, 2);
      rec_var := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'rec_');
      for (ri := 0; ri < length (rec_keys); ri := ri + 1)
        {
          declare rk varchar;
          rk := aref (rec_keys, ri);
          DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, rec_var,
            DB.DBA.GQL_GEN_PROP_IRI_CTX (rk, _ctx),
            DB.DBA.GQL_GEN_EXPR (aref (rec_vals, ri), _ctx));
        }
      return rec_var;
    }

  -- Default: return as-is
  return '""';
}
;

----------------------------------------------------------------------
-- Property path suffix from edge quantifier
-- Returns SPARQL property path suffix or '' for exact-1-hop edges.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PROPERTY_PATH_SUFFIX (in _quant any)
{
  if (_quant is null)
    return '';

  if (not isarray (_quant) or length (_quant) < 2)
    return '';

  declare min_hops, max_hops any;
  min_hops := aref (_quant, 0);
  max_hops := aref (_quant, 1);

  -- * : zero or more (min=0, max=null)
  if ((min_hops is null or min_hops = 0) and max_hops is null)
    return '*';

  -- + : one or more (min=1, max=null)
  if (min_hops = 1 and max_hops is null)
    return '+';

  -- ? : zero or one (min=0, max=1)
  if ((min_hops is null or min_hops = 0) and max_hops = 1)
    return '?';

  -- Bounded {m,n}: SPARQL 1.1 has no built-in support. For now,
  -- reject bounded quantifiers that can't be expressed as */+/?.
  -- Small fixed bounds could be expanded in a future phase.
  if (min_hops is not null)
    signal ('G3003', sprintf ('Bounded path quantifier {%d,%s} is not supported — use *, +, or ?',
      min_hops, cast (max_hops as varchar)));

  return '';
}
;

create procedure DB.DBA.GQL_NODE_PATTERN_HAS_ANCHOR (in _node any)
{
  if (not isarray (_node) or aref (_node, 0) <> 'NODE')
    return 0;
  if (length (aref (_node, 2)) > 0)
    return 1;
  if (length (aref (_node, 3)) > 0)
    return 1;
  return 0;
}
;

create procedure DB.DBA.GQL_PATTERN_ENDPOINTS_ANCHORED (in _pattern any)
{
  declare pat, elems any;
  declare first_node, last_node any;
  declare i integer;

  pat := _pattern;
  if (isarray (pat) and (aref (pat, 0) = 'PATH' or aref (pat, 0) = 'PATHVAR'))
    pat := vector ('PATTERN', aref (pat, 2));
  if (not isarray (pat) or aref (pat, 0) <> 'PATTERN')
    return 0;

  elems := aref (pat, 1);
  first_node := null;
  last_node := null;
  for (i := 0; i < length (elems); i := i + 1)
    {
      if (isarray (aref (elems, i)) and aref (aref (elems, i), 0) = 'NODE')
        {
          if (first_node is null)
            first_node := aref (elems, i);
          last_node := aref (elems, i);
        }
    }

  if (DB.DBA.GQL_NODE_PATTERN_HAS_ANCHOR (first_node)
      and DB.DBA.GQL_NODE_PATTERN_HAS_ANCHOR (last_node))
    return 1;
  return 0;
}
;

create procedure DB.DBA.GQL_EXPR_IS_PREBIND_VALUE (in _expr any)
{
  declare etype varchar;
  if (not isarray (_expr))
    return 0;
  etype := aref (_expr, 0);
  if (etype = 'IRI' or etype = 'LIT' or etype = 'LIT_BOOL'
      or etype = 'FLOAT' or etype = 'TYPEDLIT' or etype = 'TYPEDLIT_IRI' or etype = 'PARAM')
    return 1;
  if (etype = 'FUNC' and lower (cast (aref (_expr, 1) as varchar)) = 'iri')
    return 1;
  return 0;
}
;

create procedure DB.DBA.GQL_EXPR_IS_PREVALUE_VALUE (in _expr any)
{
  declare etype varchar;
  if (not isarray (_expr))
    return 0;
  etype := aref (_expr, 0);
  if (etype = 'IRI' or etype = 'LIT' or etype = 'LIT_BOOL'
      or etype = 'FLOAT' or etype = 'TYPEDLIT' or etype = 'TYPEDLIT_IRI' or etype = 'PARAM')
    return 1;
  return 0;
}
;

create procedure DB.DBA.GQL_CTX_ADD_PRE_ENDPOINT (inout _ctx any, in _var varchar, in _expr any)
{
  declare sparql_expr varchar;
  -- iri ('…') of a string is that IRI: a VALUES term, not a BIND.  (A
  -- transitive search sees a VALUES-bound end as bound, a BIND-bound one
  -- not.)
  if (isarray (_expr) and aref (_expr, 0) = 'FUNC' and lower (cast (aref (_expr, 1) as varchar)) = 'iri'
      and length (_expr) > 3 and length (aref (_expr, 3)) = 1
      and isarray (aref (aref (_expr, 3), 0)) and aref (aref (aref (_expr, 3), 0), 0) = 'LIT'
      and isstring (aref (aref (aref (_expr, 3), 0), 1))
      and strchr (aref (aref (aref (_expr, 3), 0), 1), '>') is null
      and strchr (aref (aref (aref (_expr, 3), 0), 1), ' ') is null)
    {
      DB.DBA.GQL_CTX_ADD_PRE_VALUE_ONCE (_ctx, _var, concat ('<', aref (aref (aref (_expr, 3), 0), 1), '>'));
      return;
    }
  sparql_expr := DB.DBA.GQL_GEN_EXPR (_expr, _ctx);
  if (DB.DBA.GQL_EXPR_IS_PREVALUE_VALUE (_expr))
    DB.DBA.GQL_CTX_ADD_PRE_VALUE_ONCE (_ctx, _var, sparql_expr);
  else
    DB.DBA.GQL_CTX_ADD_PRE_BIND_ONCE (_ctx, _var, sparql_expr);
}
;

create procedure DB.DBA.GQL_CTX_ADD_PRE_ENDPOINT_BIND (inout _ctx any, in _var varchar, in _expr any)
{
  DB.DBA.GQL_CTX_ADD_PRE_BIND_ONCE (_ctx, _var, DB.DBA.GQL_GEN_EXPR (_expr, _ctx));
}
;

create procedure DB.DBA.GQL_BIND_ENDPOINT_FILTERS (in _expr any, inout _ctx any)
{
  declare etype varchar;
  if (not isarray (_expr))
    return;
  etype := aref (_expr, 0);
  if (etype = 'BINOP' and aref (_expr, 1) = 'AND')
    {
      DB.DBA.GQL_BIND_ENDPOINT_FILTERS (aref (_expr, 2), _ctx);
      DB.DBA.GQL_BIND_ENDPOINT_FILTERS (aref (_expr, 3), _ctx);
      return;
    }
  if (etype = 'BINOP' and aref (_expr, 1) = '=')
    {
      declare lhs, rhs any;
      lhs := aref (_expr, 2);
      rhs := aref (_expr, 3);
      if (isarray (lhs) and aref (lhs, 0) = 'VAR'
          and DB.DBA.GQL_EXPR_IS_PREBIND_VALUE (rhs)
          and not DB.DBA.GQL_PLAN_VEC_HAS (DB.DBA.GQL_CTX_GET (_ctx, 'prebind_skip'), aref (lhs, 1)))
        DB.DBA.GQL_CTX_ADD_PRE_ENDPOINT_BIND (_ctx,
          DB.DBA.GQL_NODE_SPARQL_VAR (aref (lhs, 1)),
          rhs);
      else if (isarray (rhs) and aref (rhs, 0) = 'VAR'
          and DB.DBA.GQL_EXPR_IS_PREBIND_VALUE (lhs)
          and not DB.DBA.GQL_PLAN_VEC_HAS (DB.DBA.GQL_CTX_GET (_ctx, 'prebind_skip'), aref (rhs, 1)))
        DB.DBA.GQL_CTX_ADD_PRE_ENDPOINT_BIND (_ctx,
          DB.DBA.GQL_NODE_SPARQL_VAR (aref (rhs, 1)),
          lhs);
    }
}
;

create procedure DB.DBA.GQL_PREBIND_ENDPOINT_FILTERS (in _expr any, inout _ctx any)
{
  declare etype varchar;
  if (not isarray (_expr))
    return;
  etype := aref (_expr, 0);
  if (etype = 'BINOP' and aref (_expr, 1) = 'AND')
    {
      DB.DBA.GQL_PREBIND_ENDPOINT_FILTERS (aref (_expr, 2), _ctx);
      DB.DBA.GQL_PREBIND_ENDPOINT_FILTERS (aref (_expr, 3), _ctx);
      return;
    }
  if (etype = 'BINOP' and aref (_expr, 1) = '=')
    {
      declare lhs, rhs any;
      lhs := aref (_expr, 2);
      rhs := aref (_expr, 3);
      if (isarray (lhs) and aref (lhs, 0) = 'VAR'
          and DB.DBA.GQL_EXPR_IS_PREBIND_VALUE (rhs)
          and not DB.DBA.GQL_PLAN_VEC_HAS (DB.DBA.GQL_CTX_GET (_ctx, 'prebind_skip'), aref (lhs, 1)))
        DB.DBA.GQL_CTX_ADD_PRE_ENDPOINT (_ctx,
          DB.DBA.GQL_NODE_SPARQL_VAR (aref (lhs, 1)),
          rhs);
      else if (isarray (rhs) and aref (rhs, 0) = 'VAR'
          and DB.DBA.GQL_EXPR_IS_PREBIND_VALUE (lhs)
          and not DB.DBA.GQL_PLAN_VEC_HAS (DB.DBA.GQL_CTX_GET (_ctx, 'prebind_skip'), aref (rhs, 1)))
        DB.DBA.GQL_CTX_ADD_PRE_ENDPOINT (_ctx,
          DB.DBA.GQL_NODE_SPARQL_VAR (aref (rhs, 1)),
          lhs);
    }
}
;

create procedure DB.DBA.GQL_MATCH_HAS_PATH_VAR (in _match_ast any)
{
  declare patterns any;
  declare i integer;

  if (not isarray (_match_ast) or length (_match_ast) < 3)
    return 0;
  patterns := aref (_match_ast, 2);
  for (i := 0; i < length (patterns); i := i + 1)
    {
      if (isarray (aref (patterns, i))
          and (aref (aref (patterns, i), 0) = 'PATH'
               or aref (aref (patterns, i), 0) = 'PATHVAR'))
        return 1;
    }
  return 0;
}
;

create procedure DB.DBA.GQL_MATCHES_HAVE_SHORTEST_PATH_VAR (in _match_asts any)
{
  declare i integer;
  for (i := 0; i < length (_match_asts); i := i + 1)
    {
      declare m any;
      m := aref (_match_asts, i);
      if (isarray (m) and length (m) > 5 and aref (m, 5) is not null
          and DB.DBA.GQL_MATCH_HAS_PATH_VAR (m))
        return 1;
    }
  return 0;
}
;

----------------------------------------------------------------------
-- Pattern → triple generation
----------------------------------------------------------------------

-- The GQL variable of a path pattern that is one node with no label or
-- property, (n); null for any other pattern, and for ().
create procedure DB.DBA.GQL_LONE_NODE_VAR (in _pattern any)
{
  declare elems, elem any;

  if (not isarray (_pattern) or length (_pattern) < 2)
    return null;
  if ((aref (_pattern, 0) = 'PATH' or aref (_pattern, 0) = 'PATHVAR') and length (_pattern) > 2)
    return DB.DBA.GQL_LONE_NODE_VAR (vector ('PATTERN', aref (_pattern, 2)));
  if (aref (_pattern, 0) <> 'PATTERN')
    return null;
  elems := aref (_pattern, 1);
  if (not isarray (elems) or length (elems) <> 1)
    return null;
  elem := aref (elems, 0);
  if (not isarray (elem) or length (elem) < 4 or aref (elem, 0) <> 'NODE'
      or length (aref (elem, 2)) > 0 or length (aref (elem, 3)) > 0)
    return null;
  return aref (elem, 1);
}
;

-- Inside a SERVICE block, the test that _s is not a resource that holds an
-- edge's properties, written without FILTER NOT EXISTS: the SPARQL compiler
-- sends a variable that a FILTER EXISTS inside a SERVICE refers to as an
-- unbound parameter.  Each OPTIONAL comes after the pattern that binds _s;
-- it binds a fresh variable only for a holder, and the FILTER keeps the
-- rows where none is bound.
create procedure DB.DBA.GQL_NOT_HOLDER_OPTIONALS (inout _ctx any, in _s varchar, in _prefix varchar)
{
  declare h1, h2, h3 varchar;
  h1 := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, _prefix);
  h2 := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, _prefix);
  h3 := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, _prefix);
  return concat (
    'OPTIONAL { ', _s, ' rdf:type ', h1, ' . FILTER (', h1, ' = rdf:Statement) }',
    ' OPTIONAL { ', _s, ' rdf:subject ', h2, ' }',
    ' OPTIONAL { ', _s, ' rdf:reifies ', h3, ' }',
    ' FILTER (!BOUND (', h1, ') && !BOUND (', h2, ') && !BOUND (', h3, '))');
}
;

-- An edge of no single type -- (a)-[r]->(b), -[:%]->, -[:!T]-> -- is a
-- triple with a variable predicate or a negated path, which would also
-- match GQL's own storage: labels (rdf:type), properties (a literal
-- object), and the resource that holds an edge's properties (its
-- rdf:subject, rdf:predicate, rdf:object, rdf:reifies and other triples).
-- Returns the predicate to emit for _p (a negated path also leaves out the
-- storage predicates) and, in _filter, what keeps the triples (_s, _p, _o)
-- to edges: an object that is a node, a predicate that is not storage, and
-- -- unless the subject's label already makes it a node -- a subject that
-- is not a property holder.  The exclusions are those of the node set
-- (GQL_CTX_ADD_NODE_SET).
create procedure DB.DBA.GQL_EDGE_ONLY (inout _ctx any, in _s varchar, in _p varchar, in _o varchar,
  in _s_labelled integer, out _filter varchar)
{
  declare storage, inner_p, pred varchar;

  storage := 'rdf:type, rdf:subject, rdf:predicate, rdf:object, rdf:reifies';
  if (_p like '!%')
    {
      inner_p := subseq (_p, 1);
      if (inner_p like '(%)')
        inner_p := subseq (inner_p, 1, length (inner_p) - 1);
      pred := concat ('!(', inner_p, '|', replace (storage, ', ', '|'), ')');
      _filter := concat ('FILTER (isIRI (', _o, '))');
    }
  else
    {
      pred := _p;
      _filter := concat ('FILTER (isIRI (', _o, ') && ', _p, ' NOT IN (', storage, '))');
    }
  if (not _s_labelled and DB.DBA.GQL_CTX_GET (_ctx, 'in_service') = 1)
    _filter := concat (_filter, ' ', DB.DBA.GQL_NOT_HOLDER_OPTIONALS (_ctx, _s, 'edge_h_'));
  else if (not _s_labelled)
    _filter := concat (_filter,
      ' FILTER NOT EXISTS { ', _s, ' rdf:type rdf:Statement }',
      ' FILTER NOT EXISTS { ', _s, ' rdf:subject ', DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'edge_h_'), ' }',
      ' FILTER NOT EXISTS { ', _s, ' rdf:reifies ', DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'edge_h_'), ' }');
  return pred;
}
;

-- 1 when the node element _elem has a plain label: a node with one cannot
-- be the resource that holds an edge's properties.
create procedure DB.DBA.GQL_ELEM_HAS_LABEL (in _elem any)
{
  declare labels any;
  if (not isarray (_elem) or length (_elem) < 3 or aref (_elem, 0) <> 'NODE')
    return 0;
  labels := aref (_elem, 2);
  if (isarray (labels) and length (labels) > 0 and isstring (aref (labels, 0)))
    return 1;
  return 0;
}
;

-- Bind _nsv to each node of the graph once: each subject and each IRI
-- object.  A literal is not a node, nor a class (the object of rdf:type),
-- nor a resource that holds an edge's properties (an rdf:Statement, or one
-- with rdf:subject or rdf:reifies) or the edge type it names.  (A filter
-- that also lets a blank-node object through, isIRI || isBlank, makes the
-- NOT EXISTS probes below compare in the wrong format and keep the holders.)
create procedure DB.DBA.GQL_CTX_ADD_NODE_SET (inout _ctx any, in _nsv varchar)
{
  declare sp, so, os, op, r1, r2 varchar;

  sp := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'node_p_');
  so := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'node_o_');
  os := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'node_s_');
  op := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'node_p_');
  if (DB.DBA.GQL_CTX_GET (_ctx, 'in_service') = 1)
    {
      DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx, concat (
        '  { SELECT DISTINCT ', _nsv, ' WHERE {\n',
        '      { ', _nsv, ' ', sp, ' ', so, ' }\n',
        '      UNION\n',
        '      { ', os, ' ', op, ' ', _nsv, ' . FILTER (isIRI (', _nsv, ') && ', op,
        ' NOT IN (rdf:type, rdf:subject, rdf:predicate, rdf:object, rdf:reifies)) }\n',
        '      ', DB.DBA.GQL_NOT_HOLDER_OPTIONALS (_ctx, _nsv, 'node_r_'), ' } } .\n'));
      return;
    }
  r1 := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'node_r_');
  r2 := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'node_r_');
  DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx, concat (
    '  { SELECT DISTINCT ', _nsv, ' WHERE {\n',
    '      { ', _nsv, ' ', sp, ' ', so, ' }\n',
    '      UNION\n',
    '      { ', os, ' ', op, ' ', _nsv, ' . FILTER (isIRI (', _nsv, ') && ', op,
    ' NOT IN (rdf:type, rdf:subject, rdf:predicate, rdf:object, rdf:reifies)) }\n',
    '      FILTER NOT EXISTS { ', _nsv, ' rdf:type rdf:Statement }\n',
    '      FILTER NOT EXISTS { ', _nsv, ' rdf:subject ', r1, ' }\n',
    '      FILTER NOT EXISTS { ', _nsv, ' rdf:reifies ', r2, ' } } } .\n'));
}
;

create procedure DB.DBA.GQL_GEN_MATCH_PATTERN (in _pattern any, inout _ctx any)
{
  declare elems, elem, etype any;
  declare i integer;
  declare prev_var varchar;

  if (not isarray (_pattern)) return;

  -- PATH or PATTERN
  if (aref (_pattern, 0) = 'PATH' or aref (_pattern, 0) = 'PATHVAR')
    {
      declare path_gql_name varchar;
      path_gql_name := aref (_pattern, 1);
      DB.DBA.GQL_CTX_ADD_VAR (_ctx, path_gql_name);
      -- Map path variable to ?gql_p_<name> so RETURN/WHERE resolve correctly
      DB.DBA.GQL_CTX_ADD_ALIAS (_ctx, path_gql_name,
        DB.DBA.GQL_PATH_FIELD_VAR (path_gql_name, 'value'));
      DB.DBA.GQL_GEN_MATCH_PATTERN (vector ('PATTERN', aref (_pattern, 2)), _ctx);
      return;
    }

  if (aref (_pattern, 0) <> 'PATTERN') return;

  elems := aref (_pattern, 1);
  prev_var := null;

  -- The variable an edge chose for the anonymous node after it; that node
  -- must use it, or the edge's endpoint and the node are unrelated.
  declare next_anon_var varchar;
  next_anon_var := null;

  for (i := 0; i < length (elems); i := i + 1)
    {
      elem := aref (elems, i);
      if (not isarray (elem)) goto pattern_next;
      etype := aref (elem, 0);

      -- NODE element
      if (etype = 'NODE')
        {
          declare nvar, nsv varchar;
          declare nlabels, nprops any;
          declare li, pi integer;
          nvar := aref (elem, 1);
          nlabels := aref (elem, 2);
          nprops := aref (elem, 3);
          nsv := DB.DBA.GQL_NODE_SPARQL_VAR (nvar);
          if (nsv is null and next_anon_var is not null)
            nsv := next_anon_var;
          else if (nsv is null)
            nsv := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'anon_node_');
          next_anon_var := null;
          DB.DBA.GQL_CTX_ADD_VAR (_ctx, nvar);

          -- Emit labels via label expression emitter
          for (li := 0; li < length (nlabels); li := li + 1)
            {
              DB.DBA.GQL_EMIT_LABEL_EXPR (aref (nlabels, li), nsv, _ctx);
            }

          -- Emit properties
          for (pi := 0; pi < length (nprops); pi := pi + 1)
            {
              declare pkey, pval any;
              declare pval_str varchar;
              pkey := aref (aref (nprops, pi), 0);
              pval := aref (aref (nprops, pi), 1);
              pval_str := DB.DBA.GQL_CTX_PATTERN_PROP_VALUE (_ctx, DB.DBA.GQL_GEN_EXPR (pval, _ctx));
              DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, nsv, DB.DBA.GQL_GEN_PROP_IRI_CTX (pkey, _ctx), pval_str);
            }

          -- A lone node, (n) or (), ranges over the nodes of the graph, one
          -- row each; so does one whose labels are only negations, which
          -- are filters on it.
          if (length (nprops) = 0 and length (elems) = 1)
            {
              declare binds integer;
              binds := 0;
              for (li := 0; li < length (nlabels); li := li + 1)
                if (DB.DBA.GQL_LABEL_EXPR_BINDS (aref (nlabels, li)))
                  binds := 1;
              if (not binds)
                DB.DBA.GQL_CTX_ADD_NODE_SET (_ctx, nsv);
            }

          prev_var := nsv;
        }

      -- EDGE element
      else if (etype = 'EDGE')
        {
          declare evar, etypes, edir, equant, eprops, ecost any;
          declare eidx, epi integer;
          declare esv, esrc, edst, und_s, und_o varchar;
          und_s := null;
          und_o := null;
          evar := aref (elem, 1);
          etypes := aref (elem, 2);
          edir := aref (elem, 3);
          equant := aref (elem, 4);
          eprops := aref (elem, 5);
          ecost := null;
          if (length (elem) > 7)
            ecost := aref (elem, 7);

          esv := DB.DBA.GQL_EDGE_SPARQL_VAR (evar);
          DB.DBA.GQL_CTX_ADD_VAR (_ctx, evar);

          -- Determine source and destination from prev node and next node
          esrc := prev_var;  -- source is the previous node
          -- The destination will be set when we process the next node
          -- For now, just emit edge types

          -- For each edge type, emit a triple: src edgeType dst
          -- But we need to know the dst — it's the NEXT node in the pattern
          if (i + 1 < length (elems))
            {
              declare next_elem, next_etype, next_var any;
              next_elem := aref (elems, i + 1);
              next_etype := null;
              next_var := null;
              if (isarray (next_elem))
                {
                  next_etype := aref (next_elem, 0);
                  if (next_etype = 'NODE')
                    next_var := DB.DBA.GQL_NODE_SPARQL_VAR (aref (next_elem, 1));
                }
              if (next_var is not null)
                edst := next_var;
              else
                {
                  edst := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'dst_');
                  -- An anonymous node is this edge's destination.
                  if (next_etype = 'NODE')
                    next_anon_var := edst;
                }
            }
          else
            edst := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'dst_');

          -- Whether the stored subject (src_lab) or object (dst_lab) of the
          -- edge is a labelled node, for GQL_EDGE_ONLY.
          declare src_lab, dst_lab integer;
          src_lab := 0;
          dst_lab := 0;
          if (i > 0)
            src_lab := DB.DBA.GQL_ELEM_HAS_LABEL (aref (elems, i - 1));
          if (i + 1 < length (elems))
            dst_lab := DB.DBA.GQL_ELEM_HAS_LABEL (aref (elems, i + 1));

          -- Handle direction
          if (edir = 'LEFT')
            {
              declare tmp varchar;
              declare tmp_lab integer;
              tmp := esrc; esrc := edst; edst := tmp;
              tmp_lab := src_lab; src_lab := dst_lab; dst_lab := tmp_lab;
            }
          else if (edir = 'BOTH' or edir = 'UNDIRECTED')
            {
              -- Undirected quantified edges use SPARQL property path
              -- (iri|^iri)* to match both directions.  The wrapping is
              -- applied in the edge emission loop below.
              ;
            }
          -- RIGHT is default

          -- Compute property path suffix from quantifier
          declare pp_suffix varchar;
          pp_suffix := DB.DBA.GQL_PROPERTY_PATH_SUFFIX (equant);

          -- Expand edge type label expressions into a flat list of IRIs
          declare all_edge_iris any;
          all_edge_iris := vector ();
          for (eidx := 0; eidx < length (etypes); eidx := eidx + 1)
            {
              declare edge_iris any;
              edge_iris := DB.DBA.GQL_EMIT_EDGE_LABEL_EXPR (aref (etypes, eidx), esrc, edst, _ctx);
              all_edge_iris := vector_concat (all_edge_iris, edge_iris);
            }

          -- Untyped edge -[e]-> or -[]->: no explicit type, so connect the
          -- endpoints with a predicate variable (bound to the edge variable
          -- when one is named), matching an edge of any type.  Without this the
          -- pattern would emit no triple and leave the endpoints unconstrained.
          if (length (all_edge_iris) = 0)
            {
              declare any_edge_pred varchar;
              if (evar is not null)
                any_edge_pred := DB.DBA.GQL_EDGE_SPARQL_VAR (evar);
              else
                any_edge_pred := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'edge_p_');
              all_edge_iris := vector (vector (any_edge_pred, 1));
            }

          -- Emit edge type triples (with property path suffix if quantified)
          for (eidx := 0; eidx < length (all_edge_iris); eidx := eidx + 1)
            {
              declare edge_iri varchar;
              declare transitive_options varchar;
              declare active_path_var varchar;
              declare cost_prop varchar;
              declare is_shortest_path integer;
              edge_iri := aref (aref (all_edge_iris, eidx), 0);
              transitive_options := DB.DBA.GQL_CTX_GET (_ctx, 'transitive_options');
              active_path_var := DB.DBA.GQL_CTX_GET (_ctx, 'active_path_var');
              cost_prop := DB.DBA.GQL_EDGE_COST_PROP_NAME (ecost, evar);
              if (ecost is not null and cost_prop is null)
                signal ('G3010', 'WEIGHT/COST currently expects an edge property expression such as r.weight');
              is_shortest_path := 0;
              if (transitive_options is not null and strstr (transitive_options, 'T_SHORTEST_ONLY') is not null)
                is_shortest_path := 1;
              if (transitive_options is not null and transitive_options <> '' and (equant is not null or is_shortest_path))
                {
                  declare option_text varchar;
                  option_text := concat (transitive_options, ', T_IN (', esrc, '), T_OUT (', edst, ')');
                  if (active_path_var is not null and active_path_var <> '')
                    {
                      declare path_cost_var varchar;
                      path_cost_var := DB.DBA.GQL_PATH_FIELD_VAR (active_path_var, 'cost');
                      option_text := concat (option_text,
                        ', T_STEP(''path_id'') AS ', DB.DBA.GQL_PATH_FIELD_VAR (active_path_var, 'id'),
                        ', T_STEP(''step_no'') AS ', DB.DBA.GQL_PATH_FIELD_VAR (active_path_var, 'index'),
                        ', T_STEP(', esrc, ') AS ', DB.DBA.GQL_PATH_FIELD_VAR (active_path_var, 'node'),
                        ', T_DIRECTION 1');
                      DB.DBA.GQL_CTX_MATERIALIZE_PATH_STEP (_ctx, active_path_var);
                      DB.DBA.GQL_CTX_ADD_BIND_ONCE (_ctx, DB.DBA.GQL_PATH_FIELD_VAR (active_path_var, 'value'),
                        concat ('CONCAT("path ", STR(', DB.DBA.GQL_PATH_FIELD_VAR (active_path_var, 'id'), '))'));
                      if (cost_prop is not null)
                        {
                          DB.DBA.GQL_CTX_ADD_BIND_ONCE (_ctx, DB.DBA.GQL_PATH_FIELD_VAR (active_path_var, 'step_value'),
                            concat ('CONCAT(STR(', DB.DBA.GQL_PATH_FIELD_VAR (active_path_var, 'index'), '), ": ", STR(',
                              DB.DBA.GQL_PATH_FIELD_VAR (active_path_var, 'node'), '), " cost=", STR(', path_cost_var, '))'));
                          DB.DBA.GQL_CTX_ADD_TRANSITIVE_WEIGHTED_SUBQUERY_OPTION (_ctx, esrc, edge_iri, edst, cost_prop, path_cost_var, option_text);
                        }
                      else
                        DB.DBA.GQL_CTX_ADD_TRANSITIVE_SUBQUERY_OPTION (_ctx, esrc, edge_iri, edst, option_text);
                    }
                  else
                    DB.DBA.GQL_CTX_ADD_TRIPLE_OPTION (_ctx, esrc, edge_iri, edst, option_text);
                }
              else if (pp_suffix <> '')
                {
                  declare emit_pred varchar;
                  emit_pred := edge_iri;
                  if ((edir = 'BOTH' or edir = 'UNDIRECTED') and equant is not null)
                    emit_pred := concat ('(', edge_iri, '|^', edge_iri, ')');
                  DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, esrc, concat (emit_pred, pp_suffix), edst);
                }
              else if (edir = 'BOTH' or edir = 'UNDIRECTED')
                {
                  -- An undirected edge matches a stored edge in either
                  -- orientation.  A named one also binds the stored subject
                  -- and object, which is what the edge variable denotes.
                  -- An edge of no single type keeps to edges in each
                  -- orientation (GQL_EDGE_ONLY).
                  declare up1, up2, uf1, uf2 varchar;
                  up1 := edge_iri; up2 := edge_iri; uf1 := ''; uf2 := '';
                  if (aref (aref (all_edge_iris, eidx), 1) = 1)
                    {
                      up1 := DB.DBA.GQL_EDGE_ONLY (_ctx, esrc, edge_iri, edst, src_lab, uf1);
                      up2 := DB.DBA.GQL_EDGE_ONLY (_ctx, edst, edge_iri, esrc, dst_lab, uf2);
                      -- after the triple, or after the BINDs that follow it
                      uf1 := concat (case when evar is null then ' . ' else ' ' end, uf1);
                      uf2 := concat (case when evar is null then ' . ' else ' ' end, uf2);
                    }
                  if (evar is null)
                    DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx, concat (
                      '  { ', esrc, ' ', up1, ' ', edst, uf1, ' } UNION { ',
                      edst, ' ', up2, ' ', esrc, uf2, ' } .\n'));
                  else
                    {
                      und_s := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'eu_s_');
                      und_o := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'eu_o_');
                      DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx, concat (
                        '  { ', esrc, ' ', up1, ' ', edst,
                        ' . BIND (', esrc, ' AS ', und_s, ') BIND (', edst, ' AS ', und_o, ')', uf1, ' } UNION { ',
                        edst, ' ', up2, ' ', esrc,
                        ' . BIND (', edst, ' AS ', und_s, ') BIND (', esrc, ' AS ', und_o, ')', uf2, ' } .\n'));
                      if (aref (aref (all_edge_iris, eidx), 1) = 0)
                        DB.DBA.GQL_CTX_ADD_EDGE_BINDING (_ctx, evar, und_s, edge_iri, und_o);
                    }
                }
              else if (aref (aref (all_edge_iris, eidx), 1) = 1)
                {
                  -- An edge of no single type keeps to edges (GQL_EDGE_ONLY).
                  declare dp, df varchar;
                  dp := DB.DBA.GQL_EDGE_ONLY (_ctx, esrc, edge_iri, edst, src_lab, df);
                  DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, esrc, dp, edst);
                  DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx, concat ('  ', df, '\n'));
                }
              else
                {
                  DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, esrc, edge_iri, edst);
                  DB.DBA.GQL_CTX_ADD_EDGE_BINDING (_ctx, evar, esrc, edge_iri, edst);
                }
            }

          -- The properties of a named undirected edge belong to the stored
          -- edge, whichever way round the pattern wrote it.
          if (und_s is not null and length (all_edge_iris) = 1)
            {
              esrc := und_s;
              edst := und_o;
            }

          -- A named single edge denotes one stored edge, with esrc its
          -- subject and edst its object -- for an undirected edge only when
          -- one type's branches bind them.
          if (evar is not null and equant is null
              and coalesce (DB.DBA.GQL_CTX_GET (_ctx, 'transitive_options'), '') = ''
              and ((edir <> 'BOTH' and edir <> 'UNDIRECTED') or (und_s is not null and length (all_edge_iris) = 1)))
            DB.DBA.GQL_CTX_ADD_EDGE_ENDS (_ctx, evar, esrc, edst,
              case when length (all_edge_iris) = 1 then aref (aref (all_edge_iris, 0), 0) else null end);

          -- If edge has properties, emit reification or RDF 1.2 annotations
          if (length (eprops) > 0 and evar is not null)
            {
              declare annot_mode integer;
              declare tt_mode integer;
              declare reifier_n varchar;
              declare eff_mode integer;
              declare reifier_var varchar;
              annot_mode := 0;
              tt_mode := 0;
              reifier_n := null;
              if (length (elem) > 8)
                annot_mode := aref (elem, 8);
              if (length (elem) > 9)
                tt_mode := aref (elem, 9);
              if (length (elem) > 10)
                reifier_n := aref (elem, 10);

              -- Determine effective mode
              eff_mode := 0;
              if (tt_mode = 1)
                { eff_mode := 1; }
              else if (tt_mode = 2)
                { eff_mode := 3; }
              else if (annot_mode = 1)
                { eff_mode := 2; }
              else if (DB.DBA.GQL_CTX_GET (_ctx, 'rdf12_mode') = 1)
                { eff_mode := 1; }

              reifier_var := null;
              if (reifier_n is not null)
                reifier_var := reifier_n;
              else if (evar is not null)
                reifier_var := esv;

              if (eff_mode = 2)  -- annotation {| |}
                {
                  for (eidx := 0; eidx < length (all_edge_iris); eidx := eidx + 1)
                    {
                      declare annot_body varchar;
                      annot_body := '';
                      for (epi := 0; epi < length (eprops); epi := epi + 1)
                        {
                          declare epkey any;
                          declare epval_str varchar;
                          epkey := aref (aref (eprops, epi), 0);
                          epval_str := DB.DBA.GQL_CTX_PATTERN_PROP_VALUE (_ctx, DB.DBA.GQL_GEN_EXPR (aref (aref (eprops, epi), 1), _ctx));
                          -- the properties of an annotation are separated by ';'
                          annot_body := concat (annot_body, case when annot_body = '' then '' else ' ; ' end,
                            DB.DBA.GQL_GEN_PROP_IRI_CTX (epkey, _ctx), ' ', epval_str);
                        }
                      DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx,
                        concat ('  ', esrc, ' ',
                          aref (aref (all_edge_iris, eidx), 0), ' ', edst,
                          ' {| ', annot_body, ' |} .\n'));
                    }
                }
              else if (eff_mode = 1)  -- triple-term <<(s p o)>>
                {
                  declare rsv varchar;
                  if (reifier_var is not null)
                    rsv := reifier_var;
                  else
                    rsv := esv;
                  for (eidx := 0; eidx < length (all_edge_iris); eidx := eidx + 1)
                    {
                      declare tt_obj varchar;
                      tt_obj := concat ('<<(', esrc, ' ',
                        aref (aref (all_edge_iris, eidx), 0), ' ', edst, ')>>');
                      DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, rsv,
                        concat ('<', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'reifies>'),
                        tt_obj);
                      for (epi := 0; epi < length (eprops); epi := epi + 1)
                        {
                          declare epkey any;
                          declare epval_str varchar;
                          epkey := aref (aref (eprops, epi), 0);
                          epval_str := DB.DBA.GQL_CTX_PATTERN_PROP_VALUE (_ctx, DB.DBA.GQL_GEN_EXPR (aref (aref (eprops, epi), 1), _ctx));
                          DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, rsv,
                            DB.DBA.GQL_GEN_PROP_IRI_CTX (epkey, _ctx), epval_str);
                        }
                    }
                }
              else if (eff_mode = 3)  -- reified-triple shorthand << s p o ~ r >>
                {
                  declare rsv varchar;
                  if (reifier_var is not null)
                    rsv := reifier_var;
                  else
                    rsv := esv;
                  for (eidx := 0; eidx < length (all_edge_iris); eidx := eidx + 1)
                    {
                      declare rt_str varchar;
                      rt_str := concat ('<<', esrc, ' ',
                        aref (aref (all_edge_iris, eidx), 0), ' ', edst,
                        ' ~ ', rsv, '>>');
                      for (epi := 0; epi < length (eprops); epi := epi + 1)
                        {
                          declare epkey any;
                          declare epval_str varchar;
                          epkey := aref (aref (eprops, epi), 0);
                          epval_str := DB.DBA.GQL_CTX_PATTERN_PROP_VALUE (_ctx, DB.DBA.GQL_GEN_EXPR (aref (aref (eprops, epi), 1), _ctx));
                          DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, rt_str,
                            DB.DBA.GQL_GEN_PROP_IRI_CTX (epkey, _ctx), epval_str);
                        }
                    }
                }
              else  -- classic reification
                {
                  DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, esv,
                    concat ('<', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'type>'),
                    concat ('<', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'Statement>'));
                  DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, esv,
                    concat ('<', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'subject>'),
                    esrc);
                  for (eidx := 0; eidx < length (all_edge_iris); eidx := eidx + 1)
                    {
                      DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, esv,
                        concat ('<', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'predicate>'),
                        aref (aref (all_edge_iris, eidx), 0));
                    }
                  DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, esv,
                    concat ('<', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'object>'),
                    edst);
                  for (epi := 0; epi < length (eprops); epi := epi + 1)
                    {
                      declare epkey any;
                      epkey := aref (aref (eprops, epi), 0);
                      declare epval_str varchar;
                      epval_str := DB.DBA.GQL_CTX_PATTERN_PROP_VALUE (_ctx, DB.DBA.GQL_GEN_EXPR (aref (aref (eprops, epi), 1), _ctx));
                      DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, esv, DB.DBA.GQL_GEN_PROP_IRI_CTX (epkey, _ctx), epval_str);
                    }
                }
              DB.DBA.GQL_CTX_SET (_ctx, 'edge_vars',
                vector_concat (DB.DBA.GQL_CTX_GET (_ctx, 'edge_vars'), vector (evar)));
              DB.DBA.GQL_CTX_MARK_EDGE_REIF (_ctx, evar);
            }

          prev_var := edst;
        }

    pattern_next:;
    }
}
;

----------------------------------------------------------------------
-- MATCH clause → triple generation
----------------------------------------------------------------------

create procedure DB.DBA.GQL_GEN_MATCH (in _match_ast any, inout _ctx any)
{
  declare is_optional integer;
  declare patterns any;
  declare i integer;

  is_optional := aref (_match_ast, 1);
  patterns := aref (_match_ast, 2);

  -- Collect path mode flags from patterns (ACYCLIC → t_no_cycles, SIMPLE → t_distinct)
  declare path_mode_flags varchar;
  path_mode_flags := '';
  if (length (patterns) > 0)
    {
      declare pmi integer;
      for (pmi := 0; pmi < length (patterns); pmi := pmi + 1)
        {
          declare ppat, pptype, pelems, pei integer;
          ppat := aref (patterns, pmi);
          if (not isarray (ppat)) goto pm_next;
          pptype := aref (ppat, 0);
          if (pptype = 'PATH' or pptype = 'PATHVAR')
            ppat := vector ('PATTERN', aref (ppat, 2));
          if (not isarray (ppat) or aref (ppat, 0) <> 'PATTERN') goto pm_next;
          pelems := aref (ppat, 1);
          for (pei := 0; pei < length (pelems); pei := pei + 1)
            {
              declare pee, peetype any;
              pee := aref (pelems, pei);
              if (not isarray (pee)) goto pme_next;
              peetype := aref (pee, 0);
              if (peetype = 'EDGE' and length (pee) > 6 and aref (pee, 6) is not null)
                {
                  declare pm varchar;
                  declare pm_extra varchar;
                  declare pm_comma integer;
                  pm := aref (pee, 6);
                  -- Check for extended path_mode with appended transitive options
                  pm_comma := strstr (pm, ', ');
                  pm_extra := '';
                  if (pm_comma is not null)
                    {
                      pm_extra := subseq (pm, pm_comma);
                      pm := subseq (pm, 0, pm_comma);
                    }
                  if (pm = 'ACYCLIC')
                    path_mode_flags := concat (path_mode_flags, ', t_no_cycles', pm_extra);
                  else if (pm = 'SIMPLE')
                    path_mode_flags := concat (path_mode_flags, ', t_distinct', pm_extra);
                  else if (pm = 'TRAIL')
                    path_mode_flags := concat (path_mode_flags, ', t_trail', pm_extra);
                  else if (pm = 'WALK')
                    path_mode_flags := concat (path_mode_flags, pm_extra);
                  else
                    path_mode_flags := concat (path_mode_flags, pm_extra);
                }
            pme_next:;
            }
        pm_next:;
        }
    }

  -- MATCH-level path mode (MATCH ACYCLIC (a)-[:knows*]->(b)): applies to this
  -- MATCH's transitive edges, the same way an in-bracket edge mode does.  Only
  -- add a flag not already contributed by an in-bracket mode.
  if (length (_match_ast) > 6 and aref (_match_ast, 6) is not null)
    {
      declare mmode varchar;
      mmode := aref (_match_ast, 6);
      if (mmode = 'ACYCLIC' and strstr (path_mode_flags, 't_no_cycles') is null)
        path_mode_flags := concat (path_mode_flags, ', t_no_cycles');
      else if (mmode = 'SIMPLE' and strstr (path_mode_flags, 't_distinct') is null)
        path_mode_flags := concat (path_mode_flags, ', t_distinct');
      else if (mmode = 'TRAIL' and strstr (path_mode_flags, 't_trail') is null)
        path_mode_flags := concat (path_mode_flags, ', t_trail');
      -- WALK is the default (no flag)
    }

  -- SHORTEST PATH: collect TRANSITIVE option for Virtuoso SPARQL extension
  if (length (_match_ast) > 5 and aref (_match_ast, 5) is not null)
    {
      -- SHORTEST PATH with OPTIONAL MATCH is not supported: the TRANSITIVE
      -- option would apply to the entire WHERE clause, not just the OPTIONAL.
      if (is_optional)
        signal ('G3007', 'SHORTEST PATH with OPTIONAL MATCH is not supported — use a sub-query or separate MATCH');
      declare sc any;
      declare sc_kind varchar;
      declare sc_count integer;
      declare sc_groups integer;
      declare topt varchar;
      sc := aref (_match_ast, 5);
      sc_kind := aref (sc, 0);
      sc_count := aref (sc, 1);
      sc_groups := aref (sc, 2);
      -- SHORTEST k GROUPS with k > 1: use T_SHORTEST_K_GROUPS (exact k
      -- distinct length-groups) instead of T_SHORTEST_ONLY (k=1 case).
      -- T_DISTINCT is omitted for k > 1 because it prevents multiple paths
      -- to the same node, which is required to enumerate all paths in each
      -- length-group.  For k=1, T_DISTINCT is safe since T_SHORTEST_ONLY
      -- stops at the first result anyway.
      -- SHORTEST k PATH (k paths, no GROUPS): the transitive engine finds
      -- the paths of the shortest lengths, not a number of paths.  (T_MAX
      -- bounds the length of a path, not their number.)
      if (sc_count > 1 and sc_groups = 0)
        signal ('G3009', sprintf ('SHORTEST %d PATH is not supported -- use SHORTEST %d GROUPS PATH, the paths of the %d shortest lengths',
          sc_count, sc_count, sc_count));
      if (sc_groups = 1 and sc_count > 1)
        topt := concat ('T_SHORTEST_K_GROUPS ', cast (sc_count as varchar));
      else
        topt := 'T_DISTINCT, T_SHORTEST_ONLY';
      -- ANY SHORTEST: T_DISTINCT already gives one row for each pair of
      -- endpoints, at the shortest length.
      if (DB.DBA.GQL_CTX_GET (_ctx, 'has_where_filters') = 0)
        {
          declare anchor_ok integer;
          anchor_ok := 0;
          if (length (patterns) > 0)
            anchor_ok := DB.DBA.GQL_PATTERN_ENDPOINTS_ANCHORED (aref (patterns, 0));
          if (anchor_ok = 0)
            signal ('G3008', 'SHORTEST PATH requires bound start and end nodes in Virtuoso; add endpoint labels/properties or a WHERE clause such as WHERE a = iri("urn:a") AND b = iri("urn:b")');
        }
      -- Path variable materialisation via T_STEP.  The edge emitter adds
      -- path_id, step_no, and node T_STEP bindings once source/destination
      -- variables are known.
      if (aref (_match_ast, 2) is not null and length (aref (_match_ast, 2)) > 0)
        {
          declare first_pat any;
          first_pat := aref (aref (_match_ast, 2), 0);
          if (isarray (first_pat) and (aref (first_pat, 0) = 'PATH' or aref (first_pat, 0) = 'PATHVAR'))
            {
              declare pvar any;
              pvar := aref (first_pat, 1);
              DB.DBA.GQL_CTX_SET (_ctx, 'active_path_var', pvar);
            }
        }
      DB.DBA.GQL_CTX_SET (_ctx, 'transitive_options',
        concat ('TRANSITIVE, ', topt, path_mode_flags));
    }
  -- Non-SHORTEST path with ACYCLIC/SIMPLE: still need TRANSITIVE for t_no_cycles/t_distinct
  else if (path_mode_flags <> '')
    {
      DB.DBA.GQL_CTX_SET (_ctx, 'transitive_options',
        concat ('TRANSITIVE', path_mode_flags));
    }
  -- ALL PATHS with quantified edges: warn about potential exponential result count
  else if (aref (_match_ast, 4) = 1 and length (patterns) > 0)
    {
      -- Check if any pattern has quantified edges
      declare pi integer;
      for (pi := 0; pi < length (patterns); pi := pi + 1)
        {
          declare pat, pat_type, pat_elems, ei2 integer;
          pat := aref (patterns, pi);
          if (not isarray (pat)) goto all_paths_next;
          pat_type := aref (pat, 0);
          if (pat_type = 'PATH' or pat_type = 'PATHVAR')
            pat := vector ('PATTERN', aref (pat, 2));
          if (not isarray (pat) or aref (pat, 0) <> 'PATTERN') goto all_paths_next;
          pat_elems := aref (pat, 1);
          for (ei2 := 0; ei2 < length (pat_elems); ei2 := ei2 + 1)
            {
              declare e2, e2t any;
              e2 := aref (pat_elems, ei2);
              if (not isarray (e2)) goto all_paths_elem_next;
              e2t := aref (e2, 0);
              if (e2t = 'EDGE' and aref (e2, 4) is not null)
                {
                  declare eq any;
                  eq := aref (e2, 4);
                  -- Only warn for truly unbounded quantifiers (* = 0..∞, + = 1..∞)
                  -- ? = 0..1 is bounded and won't cause exponential blowup.
                  if (isarray (eq) and length (eq) >= 2
                      and aref (eq, 1) is null)  -- max is unbounded
                    {
                      DB.DBA.GQL_CTX_ADD_ERROR (_ctx, 'GW004',
                        'ALL PATHS with unbounded quantifier (*, +) may produce exponential result count — consider using SHORTEST PATH or limiting with k');
                      goto all_paths_done;
                    }
                }
            all_paths_elem_next:;
            }
        all_paths_next:;
        }
    all_paths_done:;
    }

  -- Optional matches go into the OPTIONAL block
  if (is_optional)
    {
      declare saved_triples varchar;
      declare saved_filters varchar;
      declare saved_binds varchar;

      DB.DBA.GQL_CTX_ENTER_OPTIONAL (_ctx);
      saved_triples := DB.DBA.GQL_CTX_GET (_ctx, 'triples');
      saved_filters := DB.DBA.GQL_CTX_GET (_ctx, 'filters');
      saved_binds := DB.DBA.GQL_CTX_GET (_ctx, 'binds');
      DB.DBA.GQL_CTX_SET (_ctx, 'triples', '');
      DB.DBA.GQL_CTX_SET (_ctx, 'filters', '');
      DB.DBA.GQL_CTX_SET (_ctx, 'binds', '');

      for (i := 0; i < length (patterns); i := i + 1)
        DB.DBA.GQL_GEN_MATCH_PATTERN (aref (patterns, i), _ctx);

      declare opt_body varchar;
      opt_body := DB.DBA.GQL_CTX_GET (_ctx, 'values');
      opt_body := concat (opt_body, DB.DBA.GQL_CTX_GET (_ctx, 'triples'));
      opt_body := concat (opt_body, DB.DBA.GQL_CTX_GET (_ctx, 'binds'));
      opt_body := concat (opt_body, DB.DBA.GQL_CTX_GET (_ctx, 'filters'));

      DB.DBA.GQL_CTX_SET (_ctx, 'triples', saved_triples);
      DB.DBA.GQL_CTX_SET (_ctx, 'filters', saved_filters);
      DB.DBA.GQL_CTX_SET (_ctx, 'binds', saved_binds);

      declare optionals varchar;
      optionals := DB.DBA.GQL_CTX_GET (_ctx, 'optionals');
      optionals := concat (optionals, '  OPTIONAL {\n', opt_body, '  }\n');
      DB.DBA.GQL_CTX_SET (_ctx, 'optionals', optionals);

      DB.DBA.GQL_CTX_EXIT_OPTIONAL (_ctx);
    }
  else
    {
      declare triples_before integer;
      triples_before := length (DB.DBA.GQL_CTX_GET (_ctx, 'triples'));
      for (i := 0; i < length (patterns); i := i + 1)
        DB.DBA.GQL_GEN_MATCH_PATTERN (aref (patterns, i), _ctx);
      if (length (_match_ast) > 5 and aref (_match_ast, 5) is not null)
        DB.DBA.GQL_CTX_ORDER_SHORTEST (_ctx, triples_before);
    }
}
;

-- A SHORTEST search must run with both its ends bound: T_SHORTEST_ONLY
-- stops at the first length where it finds any result, and
-- T_SHORTEST_K_GROUPS counts the lengths of all the paths it finds, so
-- searched from one end alone they return the paths to the nearest nodes,
-- and the other end's condition, applied after, removes them.  Emit the
-- pattern's own triples (properties, then labels) ahead of the transitive
-- one, and have the SQL compiler keep that order.  Only a pattern of
-- single-line triples is reordered.
create procedure DB.DBA.GQL_CTX_ORDER_SHORTEST (inout _ctx any, in _from integer)
{
  declare triples, tail, line, props, types, trans varchar;
  declare lines any;
  declare i integer;
  triples := DB.DBA.GQL_CTX_GET (_ctx, 'triples');
  tail := subseq (triples, _from);
  lines := split_and_decode (tail, 0, '\0\0\n');
  props := '';
  types := '';
  trans := '';
  for (i := 0; i < length (lines); i := i + 1)
    {
      line := aref (lines, i);
      if (line = '')
        goto next_line;
      if (strstr (line, 'OPTION (TRANSITIVE') is not null)
        trans := concat (trans, line, '\n');
      else if (strchr (line, '{') is not null or strchr (line, '}') is not null)
        return;
      else if (strstr (line, ' rdf:type ') is not null)
        types := concat (types, line, '\n');
      else
        props := concat (props, line, '\n');
    next_line:;
    }
  if (trans = '')
    return;
  DB.DBA.GQL_CTX_SET (_ctx, 'triples', concat (subseq (triples, 0, _from), props, types, trans));
  if (DB.DBA.GQL_CTX_GET (_ctx, 'shortest_order') is null)
    {
      DB.DBA.GQL_CTX_ADD_DEFINE (_ctx, 'sql:select-option', vector ('LIT', 'order'));
      DB.DBA.GQL_CTX_SET (_ctx, 'shortest_order', 1);
    }
}
;

----------------------------------------------------------------------
-- RETURN clause → SELECT generation
----------------------------------------------------------------------

create procedure DB.DBA.GQL_GEN_RETURN (in _return_ast any, inout _ctx any, inout _order_clause varchar, inout _limit_clause varchar, inout _skip_clause varchar, inout _is_distinct integer)
{
  declare items, order_by any;
  declare ret_vars any;
  declare i integer;

  _is_distinct := 0;
  _order_clause := '';
  _limit_clause := '';
  _skip_clause := '';

  if (not isarray (_return_ast))
    return vector ();

  _is_distinct := aref (_return_ast, 1);
  items := aref (_return_ast, 2);
  order_by := aref (_return_ast, 3);

  -- Make RETURN aliases visible to ORDER BY and subsequent outer scopes.
  for (i := 0; i < length (items); i := i + 1)
    {
      declare ri, ria any;
      ri := aref (items, i);
      ria := aref (ri, 2);
      if (ria is not null)
        DB.DBA.GQL_CTX_ADD_ALIAS (_ctx, ria, concat ('?', ria));
    }

  -- LIMIT / SKIP
  if (length (_return_ast) > 4 and aref (_return_ast, 4) is not null)
    _skip_clause := concat ('OFFSET ', DB.DBA.GQL_GEN_EXPR (aref (_return_ast, 4), _ctx));
  if (length (_return_ast) > 5 and aref (_return_ast, 5) is not null)
    _limit_clause := concat ('LIMIT ', DB.DBA.GQL_GEN_EXPR (aref (_return_ast, 5), _ctx));

  -- ORDER BY
  if (isarray (order_by) and length (order_by) > 0)
    {
      declare oitems varchar;
      oitems := '';
      for (i := 0; i < length (order_by); i := i + 1)
        {
          declare oitem, oexpr, odir any;
          oitem := aref (order_by, i);
          oexpr := DB.DBA.GQL_GEN_EXPR (aref (oitem, 1), _ctx);
          odir := aref (oitem, 2);
          if (oitems <> '') oitems := concat (oitems, ' ');
          if (odir = 'DESC')
            oitems := concat (oitems, 'DESC(', oexpr, ')');
          else
            oitems := concat (oitems, 'ASC(', oexpr, ')');
        }
      _order_clause := concat ('ORDER BY ', oitems);
    }

  -- Build return items list
  ret_vars := vector ();
  for (i := 0; i < length (items); i := i + 1)
    {
      declare ri, rie, ria any;
      declare sparql_expr varchar;
      ri := aref (items, i);
      rie := aref (ri, 1);  -- expression
      ria := aref (ri, 2);  -- alias

      if (isarray (rie) and aref (rie, 0) = 'VAR' and aref (rie, 1) = '*')
        {
          -- RETURN * — emit all bound variables
          declare all_vars any;
          declare vi integer;
          all_vars := DB.DBA.GQL_CTX_GET (_ctx, 'vars');
          for (vi := 0; vi < length (all_vars); vi := vi + 1)
            ret_vars := vector_concat (ret_vars, vector (vector (DB.DBA.GQL_NODE_SPARQL_VAR (aref (all_vars, vi)), null)));
          goto ret_done;
        }

      sparql_expr := DB.DBA.GQL_GEN_EXPR (rie, _ctx);
      if (ria is not null)
        {
          DB.DBA.GQL_CTX_ADD_ALIAS (_ctx, ria, sparql_expr);
          ret_vars := vector_concat (ret_vars, vector (vector (sparql_expr, ria)));
        }
      else if (isarray (rie) and aref (rie, 0) = 'VAR')
        ret_vars := vector_concat (ret_vars, vector (vector (sparql_expr, aref (rie, 1))));
      else
        ret_vars := vector_concat (ret_vars, vector (vector (sparql_expr, null)));
    }
  ret_done:
  return ret_vars;
}
;

----------------------------------------------------------------------
-- Set operations.  Each branch is translated on its own, to a complete
-- SELECT; the set operation nests the two as sub-selects (a sub-select
-- keeps its own FROM, ORDER BY and LIMIT) and matches their columns by
-- position, under the left branch's names.
----------------------------------------------------------------------

-- Split a translated SELECT into its prologue (DEFINE, BASE, PREFIX) and
-- the query from SELECT on, and list the names of the columns it projects.
create procedure DB.DBA.GQL_SETOP_SPLIT (in _sparql varchar, out _prologue varchar, out _query varchar, out _cols any)
{
  declare pos, eol, i, n, depth, in_str, start integer;
  declare proj, item varchar;
  declare cols any;
  if (_sparql like 'SPARQL %')
    _sparql := subseq (_sparql, 7);
  if (_sparql like 'SELECT %')
    pos := 0;
  else
    {
      pos := strstr (_sparql, '\nSELECT ');
      if (pos is null)
        signal ('G2004', 'Each side of a set operation must be a query that returns rows (MATCH ... RETURN)');
      pos := pos + 1;
    }
  _prologue := subseq (_sparql, 0, pos);
  _query := subseq (_sparql, pos);
  eol := strstr (_query, '\n');
  if (eol is null)
    eol := length (_query);
  proj := subseq (_query, 7, eol);
  if (proj like 'DISTINCT %')
    proj := subseq (proj, 9);
  proj := trim (proj);
  if (proj = '*')
    signal ('G2004', 'A set operation needs the RETURN items of each side, not RETURN *');
  -- The projection is items separated by spaces at depth 0: ?var, or
  -- (expr AS ?var); a string in an expression may hold spaces or parens.
  vectorbld_init (cols);
  n := length (proj);
  depth := 0;
  in_str := 0;
  start := 0;
  for (i := 0; i <= n; i := i + 1)
    {
      declare c integer;
      c := case when i < n then aref (proj, i) else 32 end;
      if (in_str)
        {
          if (c = 92)
            i := i + 1;
          else if (c = 34)
            in_str := 0;
        }
      else if (c = 34)
        in_str := 1;
      else if (c = 40)
        depth := depth + 1;
      else if (c = 41)
        depth := depth - 1;
      else if (c = 32 and depth = 0)
        {
          item := trim (subseq (proj, start, i));
          start := i + 1;
          if (item = '')
            goto next_char;
          if (item like '?%')
            vectorbld_acc (cols, subseq (item, 1));
          else if (item like '(%)' and strstr (item, ' AS ?') is not null)
            {
              declare as_pos, next_pos integer;
              as_pos := strstr (item, ' AS ?');
              next_pos := strstr (subseq (item, as_pos + 1), ' AS ?');
              while (next_pos is not null)
                {
                  as_pos := as_pos + 1 + next_pos;
                  next_pos := strstr (subseq (item, as_pos + 1), ' AS ?');
                }
              vectorbld_acc (cols, trim (subseq (item, as_pos + 5, length (item) - 1)));
            }
          else
            signal ('G2004', sprintf ('Name each RETURN item of a set operation with AS (item %s)', item));
        }
    next_char:;
    }
  vectorbld_final (cols);
  _cols := cols;
}
;

-- Combine the translations of the two branches of a set operation.
create procedure DB.DBA.GQL_SETOP_COMBINE (in _op varchar, in _left varchar, in _right varchar)
{
  declare l_pro, l_q, r_pro, r_q, l_body, r_body, proj, outer_sel, where_s varchar;
  declare l_cols, r_cols any;
  declare i, same_names integer;
  DB.DBA.GQL_SETOP_SPLIT (_left, l_pro, l_q, l_cols);
  DB.DBA.GQL_SETOP_SPLIT (_right, r_pro, r_q, r_cols);
  if (length (l_cols) <> length (r_cols))
    signal ('G2004', sprintf ('The sides of %s return %d and %d columns; a set operation needs the same number on each side',
      _op, length (l_cols), length (r_cols)));
  proj := '';
  for (i := 0; i < length (l_cols); i := i + 1)
    proj := concat (proj, case when i > 0 then ' ' else '' end, '?', aref (l_cols, i));
  l_body := concat ('{ ', l_q, ' }');
  -- The right side's columns take the left side's names, by position,
  -- through fresh names so that a name the two sides use for different
  -- columns cannot clash.
  same_names := 1;
  for (i := 0; i < length (l_cols); i := i + 1)
    if (aref (l_cols, i) <> aref (r_cols, i))
      same_names := 0;
  if (same_names)
    r_body := concat ('{ ', r_q, ' }');
  else
    {
      declare tmp_proj, out_proj varchar;
      tmp_proj := '';
      out_proj := '';
      for (i := 0; i < length (r_cols); i := i + 1)
        {
          tmp_proj := concat (tmp_proj, case when i > 0 then ' ' else '' end,
            '(?', aref (r_cols, i), ' AS ?__gql_so_', cast (i as varchar), ')');
          out_proj := concat (out_proj, case when i > 0 then ' ' else '' end,
            '(?__gql_so_', cast (i as varchar), ' AS ?', aref (l_cols, i), ')');
        }
      r_body := concat ('{ SELECT ', out_proj, ' WHERE { { SELECT ', tmp_proj, ' WHERE { { ', r_q, ' } } } } }');
    }
  if (_op = 'UNION_ALL')
    {
      outer_sel := 'SELECT ';
      where_s := concat (l_body, '\nUNION\n', r_body);
    }
  else if (_op = 'UNION')
    {
      outer_sel := 'SELECT DISTINCT ';
      where_s := concat (l_body, '\nUNION\n', r_body);
    }
  else if (_op = 'EXCEPT')
    {
      -- The left rows with no equal right row: an OPTIONAL join on all the
      -- columns, kept where it found nothing.  (FILTER NOT EXISTS and MINUS
      -- do not see the values a sub-select projects.)
      outer_sel := 'SELECT DISTINCT ';
      where_s := concat (l_body, '\nOPTIONAL { SELECT DISTINCT ', proj, ' (1 AS ?__gql_so_hit) WHERE { ', r_body,
        ' } }\nFILTER (!BOUND (?__gql_so_hit))');
    }
  else if (_op = 'INTERSECT')
    {
      -- The rows on both sides: a join on all the columns.
      outer_sel := 'SELECT DISTINCT ';
      where_s := concat (l_body, '\n', r_body);
    }
  else if (_op = 'OTHERWISE')
    {
      -- The left rows, or the right rows when the left has none: the test
      -- of the right branch projects only a fresh variable, so it does not
      -- correlate with the right's columns.
      outer_sel := 'SELECT ';
      where_s := concat (l_body, '\nUNION\n{ ', r_body,
        '\n  FILTER NOT EXISTS { { SELECT ?__gql_so_any WHERE { ', l_body,
        ' BIND (1 AS ?__gql_so_any) } LIMIT 1 } } }');
    }
  else
    signal ('G2004', sprintf ('Unsupported set operation: %s', _op));
  return concat ('SPARQL ', l_pro, outer_sel, proj, '\nWHERE {\n', where_s, '\n}\n');
}
;

----------------------------------------------------------------------
-- PROC helpers: merge binding defs and USE_ANY_GRAPH into leaf QUERY nodes
-- Recursively walks SETOP trees so prefixes are visible in all branches.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PROC_MERGE_BINDINGS (in _stmt any, in _binding_defs any)
{
  declare stmt_type, stmt_clauses any;

  stmt_type := aref (_stmt, 0);
  if (stmt_type = 'QUERY')
    {
      stmt_clauses := vector_concat (_binding_defs, aref (_stmt, 1));
      return vector ('QUERY', stmt_clauses, aref (_stmt, 2));
    }
  else if (stmt_type = 'SETOP')
    {
      declare left_branch, right_branch any;
      left_branch := DB.DBA.GQL_PROC_MERGE_BINDINGS (aref (_stmt, 2), _binding_defs);
      right_branch := DB.DBA.GQL_PROC_MERGE_BINDINGS (aref (_stmt, 3), _binding_defs);
      return vector ('SETOP', aref (_stmt, 1), left_branch, right_branch);
    }
  return _stmt;
}
;

create procedure DB.DBA.GQL_PROC_MERGE_USE_ANY_GRAPH (in _stmt any)
{
  declare stmt_type, stmt_clauses any;
  declare use_any_clause any;

  stmt_type := aref (_stmt, 0);
  if (stmt_type = 'QUERY')
    {
      use_any_clause := vector ('USE_ANY_GRAPH');
      stmt_clauses := vector_concat (vector (use_any_clause), aref (_stmt, 1));
      return vector ('QUERY', stmt_clauses, aref (_stmt, 2));
    }
  else if (stmt_type = 'SETOP')
    {
      declare left_branch, right_branch any;
      left_branch := DB.DBA.GQL_PROC_MERGE_USE_ANY_GRAPH (aref (_stmt, 2));
      right_branch := DB.DBA.GQL_PROC_MERGE_USE_ANY_GRAPH (aref (_stmt, 3));
      return vector ('SETOP', aref (_stmt, 1), left_branch, right_branch);
    }
  return _stmt;
}
;

----------------------------------------------------------------------
-- Top-level translator: AST → SPARQL string
----------------------------------------------------------------------

----------------------------------------------------------------------
-- Count pre-aggregation (opt-in: registry __gql_count_preagg 'on')
----------------------------------------------------------------------

-- Every variable name in an AST subtree: the name of each VAR, NODE, EDGE,
-- PATH or PATHVAR vector wherever it is -- a pattern, an expression, a
-- pattern predicate, EXISTS.  Blunt on purpose: any name it finds counts as
-- a reference.
create procedure DB.DBA.GQL_PREAGG_NAMES (in _x any, inout _names any)
{
  declare i integer;
  declare k any;

  if (__tag (_x) <> __tag of vector)
    return;
  if (length (_x) > 1)
    {
      k := aref (_x, 0);
      if (isstring (k) and (k = 'VAR' or k = 'NODE' or k = 'EDGE' or k = 'PATH' or k = 'PATHVAR')
          and isstring (aref (_x, 1)))
        _names := DB.DBA.GQL_PLAN_VEC_ADD (_names, aref (_x, 1));
    }
  for (i := 0; i < length (_x); i := i + 1)
    DB.DBA.GQL_PREAGG_NAMES (aref (_x, i), _names);
}
;

create procedure DB.DBA.GQL_PREAGG_UNION (in _a any, in _b any)
{
  declare i integer;
  for (i := 0; i < length (_b); i := i + 1)
    _a := DB.DBA.GQL_PLAN_VEC_ADD (_a, aref (_b, i));
  return _a;
}
;

create procedure DB.DBA.GQL_PREAGG_COMMON (in _a any, in _b any)
{
  declare r any;
  declare i integer;
  r := vector ();
  for (i := 0; i < length (_a); i := i + 1)
    if (DB.DBA.GQL_PLAN_VEC_HAS (_b, aref (_a, i)))
      r := vector_concat (r, vector (aref (_a, i)));
  return r;
}
;

-- Whether a pattern element may be counted inside a leaf: a node, or an
-- unnamed edge with no quantifier, property, path mode, cost or RDF 1.2
-- form -- nothing the translator binds for later.
create procedure DB.DBA.GQL_PREAGG_ELEM_OK (in _el any)
{
  if (__tag (_el) <> __tag of vector or length (_el) < 2 or not isstring (aref (_el, 0)))
    return 0;
  if (aref (_el, 0) = 'NODE')
    return 1;
  if (aref (_el, 0) <> 'EDGE' or aref (_el, 1) is not null)
    return 0;
  if (length (_el) > 4 and aref (_el, 4) is not null) return 0;
  if (length (_el) > 5 and length (aref (_el, 5)) > 0) return 0;
  if (length (_el) > 6 and aref (_el, 6) is not null) return 0;
  if (length (_el) > 7 and aref (_el, 7) is not null) return 0;
  if (length (_el) > 8 and coalesce (aref (_el, 8), 0) <> 0) return 0;
  if (length (_el) > 9 and coalesce (aref (_el, 9), 0) <> 0) return 0;
  if (length (_el) > 10 and aref (_el, 10) is not null) return 0;
  return 1;
}
;

-- Whether _pats (path patterns) are plain PATTERNs of countable elements.
create procedure DB.DBA.GQL_PREAGG_PATS_OK (in _pats any)
{
  declare i, j integer;
  declare p any;
  for (i := 0; i < length (_pats); i := i + 1)
    {
      p := aref (_pats, i);
      if (__tag (p) <> __tag of vector or aref (p, 0) <> 'PATTERN')
        return 0;
      for (j := 0; j < length (aref (p, 1)); j := j + 1)
        if (not DB.DBA.GQL_PREAGG_ELEM_OK (aref (aref (p, 1), j)))
          return 0;
    }
  return 1;
}
;

-- Whether _name is a node of one of _pats.
create procedure DB.DBA.GQL_PREAGG_HAS_NODE (in _pats any, in _name varchar)
{
  declare i, j integer;
  declare el any;
  for (i := 0; i < length (_pats); i := i + 1)
    for (j := 0; j < length (aref (aref (_pats, i), 1)); j := j + 1)
      {
        el := aref (aref (aref (_pats, i), 1), j);
        if (aref (el, 0) = 'NODE' and aref (el, 1) = _name)
          return 1;
      }
  return 0;
}
;

-- The count pre-aggregation of a QUERY that returns only count(*).  Parts
-- of its pattern that hang off the rest at one node -- leaves -- are counted
-- first, each per attachment node in a GROUP BY sub-select (a COUNT_LEAF
-- clause), and the count becomes the sum over the rest's rows of the
-- product of the leaves' counts (PREAGG_COUNT).  GQL's matches are a bag:
-- per match of the rest, a pattern's matches are the product of each
-- leaf's matches at its node, so the count is exact.  A leaf is
--   (a) an OPTIONAL MATCH meeting the rest at one node a mandatory MATCH
--       binds, counted as COALESCE (c, 1) -- no match keeps the row once;
--   (b) a comma pattern of a mandatory MATCH meeting the rest at one node,
--       never the first pattern of the first MATCH;
--   (c) the part of a path beyond the last node (or before the first) that
--       a WHERE or FILTER refers to, when the rest of the path keeps an
--       edge.
-- No other variable of a leaf may appear anywhere else, and its edges must
-- be plain.  Only these shapes paid on LSQB SF1: counting a cheap leaf (a
-- tag, a creator) first, or splitting a chain, runs a GROUP BY over the
-- whole graph and was 2x slower.  Anything else returns _q unchanged.
create procedure DB.DBA.GQL_PREAGG_REWRITE (in _q any)
{
  declare clauses, c, ret, item, units, u, pats, exprnames, mandnames, others any;
  declare leaves, cuts, newc, newpats, prodv any;
  declare i, j, n, ui, nleaf integer;
  declare t varchar;

  if (__tag (_q) <> __tag of vector or length (_q) < 2 or aref (_q, 0) <> 'QUERY')
    return _q;
  if (length (_q) > 2 and length (aref (_q, 2)) > 0)
    return _q;
  clauses := aref (_q, 1);
  n := length (clauses);

  -- Shape: MATCH / OPTIONAL MATCH, WHERE, FILTER, one RETURN count(*).
  ret := null;
  for (i := 0; i < n; i := i + 1)
    {
      c := aref (clauses, i);
      if (__tag (c) <> __tag of vector or not isstring (aref (c, 0)))
        return _q;
      t := aref (c, 0);
      if (t = 'RETURN')
        {
          if (ret is not null)
            return _q;
          ret := c;
        }
      else if (t = 'MATCH')
        {
          if (length (c) < 3 or (length (c) > 3 and length (aref (c, 3)) > 0)
              or (length (c) > 4 and coalesce (aref (c, 4), 0) <> 0)
              or (length (c) > 5 and aref (c, 5) is not null)
              or (length (c) > 6 and aref (c, 6) is not null))
            return _q;
        }
      else if (t <> 'WHERE' and t <> 'FILTER' and t <> 'USE' and t <> 'USE_PROPERTY'
               and t <> 'PREFIX' and t <> 'BASE' and t <> 'DEFINE' and t <> 'VERSION')
        return _q;
    }
  if (ret is null or coalesce (aref (ret, 1), 0) <> 0 or length (aref (ret, 2)) <> 1
      or length (aref (ret, 3)) > 0
      or (length (ret) > 4 and aref (ret, 4) is not null)
      or (length (ret) > 5 and aref (ret, 5) is not null))
    return _q;
  item := aref (aref (ret, 2), 0);
  if (__tag (aref (item, 1)) <> __tag of vector or aref (aref (item, 1), 0) <> 'COUNTSTAR')
    return _q;

  -- The units leaves must be independent of, with their names: each
  -- mandatory pattern (P), each OPTIONAL MATCH (O), each WHERE/FILTER (W).
  units := vector ();
  exprnames := vector ();
  mandnames := vector ();
  for (i := 0; i < n; i := i + 1)
    {
      declare nm any;
      c := aref (clauses, i);
      t := aref (c, 0);
      if (t = 'MATCH' and coalesce (aref (c, 1), 0) = 0)
        {
          pats := aref (c, 2);
          for (j := 0; j < length (pats); j := j + 1)
            {
              nm := vector ();
              DB.DBA.GQL_PREAGG_NAMES (aref (pats, j), nm);
              units := vector_concat (units, vector (vector ('P', i, j, nm)));
              mandnames := DB.DBA.GQL_PREAGG_UNION (mandnames, nm);
            }
        }
      else if (t = 'MATCH')
        {
          nm := vector ();
          DB.DBA.GQL_PREAGG_NAMES (aref (c, 2), nm);
          units := vector_concat (units, vector (vector ('O', i, -1, nm)));
        }
      else if (t = 'WHERE' or t = 'FILTER')
        {
          nm := vector ();
          DB.DBA.GQL_PREAGG_NAMES (aref (c, 1), nm);
          units := vector_concat (units, vector (vector ('W', i, -1, nm)));
          exprnames := DB.DBA.GQL_PREAGG_UNION (exprnames, nm);
        }
    }

  -- (a) and (b): a unit that meets the rest at exactly one node.
  leaves := vector ();   -- vector (clause, pattern or -1, attachment, patterns, optional)
  for (ui := 0; ui < length (units); ui := ui + 1)
    {
      declare common, upats any;
      u := aref (units, ui);
      if (aref (u, 0) = 'W' or (aref (u, 0) = 'P' and aref (u, 1) = DB.DBA.GQL_PREAGG_FIRST_MATCH (clauses) and aref (u, 2) = 0))
        goto next_unit;
      others := vector ();
      for (j := 0; j < length (units); j := j + 1)
        if (j <> ui)
          others := DB.DBA.GQL_PREAGG_UNION (others, aref (aref (units, j), 3));
      common := DB.DBA.GQL_PREAGG_COMMON (aref (u, 3), others);
      if (length (common) <> 1)
        goto next_unit;
      if (aref (u, 0) = 'P')
        upats := vector (aref (aref (aref (clauses, aref (u, 1)), 2), aref (u, 2)));
      else
        upats := aref (aref (clauses, aref (u, 1)), 2);
      if (not DB.DBA.GQL_PREAGG_PATS_OK (upats) or not DB.DBA.GQL_PREAGG_HAS_NODE (upats, aref (common, 0)))
        goto next_unit;
      -- The attachment must be bound by a mandatory pattern other than this one.
      if (not DB.DBA.GQL_PREAGG_BOUND_ELSEWHERE (units, ui, aref (common, 0)))
        goto next_unit;
      leaves := vector_concat (leaves, vector (vector (aref (u, 1), aref (u, 2), aref (common, 0),
        upats, case when aref (u, 0) = 'O' then 1 else 0 end)));
    next_unit:;
    }

  -- (c): cut a mandatory path that is not a leaf after its last (before its
  -- first) node a WHERE/FILTER refers to.
  cuts := vector ();     -- vector (clause, pattern, core pattern)
  for (ui := 0; ui < length (units); ui := ui + 1)
    {
      declare p, els, core_els, sfx, pfx, own any;
      declare k, jj, m, e, lo, hi integer;
      u := aref (units, ui);
      if (aref (u, 0) <> 'P' or DB.DBA.GQL_PREAGG_IS_LEAF (leaves, aref (u, 1), aref (u, 2)))
        goto next_cut;
      p := aref (aref (aref (clauses, aref (u, 1)), 2), aref (u, 2));
      if (aref (p, 0) <> 'PATTERN')
        goto next_cut;
      els := aref (p, 1);
      m := length (els) - 1;
      k := -1;
      jj := -1;
      for (e := 0; e <= m; e := e + 2)
        if (aref (aref (els, e), 0) = 'NODE' and isstring (aref (aref (els, e), 1))
            and DB.DBA.GQL_PLAN_VEC_HAS (exprnames, aref (aref (els, e), 1)))
          {
            if (jj < 0) jj := e;
            k := e;
          }
      if (k < 0)
        goto next_cut;
      others := vector ();
      for (j := 0; j < length (units); j := j + 1)
        if (j <> ui)
          others := DB.DBA.GQL_PREAGG_UNION (others, aref (aref (units, j), 3));
      lo := 0;
      hi := m;
      -- Beyond the last referred-to node.
      if (k >= 2 and k < m)
        {
          sfx := vector ();
          own := vector ();
          for (e := k + 1; e <= m; e := e + 1)
            sfx := vector_concat (sfx, vector (aref (els, e)));
          DB.DBA.GQL_PREAGG_NAMES (sfx, own);
          core_els := vector ();
          for (e := 0; e <= k; e := e + 1)
            core_els := vector_concat (core_els, vector (aref (els, e)));
          if (DB.DBA.GQL_PREAGG_PATS_OK (vector (vector ('PATTERN', sfx)))
              and length (DB.DBA.GQL_PREAGG_COMMON (own, others)) = 0
              and length (DB.DBA.GQL_PREAGG_COMMON (own, DB.DBA.GQL_PREAGG_NAMES_OF (core_els))) = 0)
            {
              leaves := vector_concat (leaves, vector (vector (aref (u, 1), -2, aref (aref (els, k), 1),
                vector (vector ('PATTERN', vector_concat (vector (vector ('NODE', aref (aref (els, k), 1), vector (), vector ())), sfx))), 0)));
              hi := k;
            }
        }
      -- Before the first referred-to node.
      if (jj >= 2 and hi - jj >= 2)
        {
          pfx := vector ();
          own := vector ();
          for (e := 0; e < jj; e := e + 1)
            pfx := vector_concat (pfx, vector (aref (els, e)));
          DB.DBA.GQL_PREAGG_NAMES (pfx, own);
          core_els := vector ();
          for (e := jj; e <= hi; e := e + 1)
            core_els := vector_concat (core_els, vector (aref (els, e)));
          if (DB.DBA.GQL_PREAGG_PATS_OK (vector (vector ('PATTERN', pfx)))
              and length (DB.DBA.GQL_PREAGG_COMMON (own, others)) = 0
              and length (DB.DBA.GQL_PREAGG_COMMON (own, DB.DBA.GQL_PREAGG_NAMES_OF (core_els))) = 0)
            {
              leaves := vector_concat (leaves, vector (vector (aref (u, 1), -2, aref (aref (els, jj), 1),
                vector (vector ('PATTERN', vector_concat (pfx, vector (vector ('NODE', aref (aref (els, jj), 1), vector (), vector ()))))), 0)));
              lo := jj;
            }
        }
      if (lo > 0 or hi < m)
        {
          core_els := vector ();
          for (e := lo; e <= hi; e := e + 1)
            core_els := vector_concat (core_els, vector (aref (els, e)));
          cuts := vector_concat (cuts, vector (vector (aref (u, 1), aref (u, 2), vector ('PATTERN', core_els))));
        }
    next_cut:;
    }

  if (length (leaves) = 0)
    return _q;

  -- The rewritten clauses: leaves out of their MATCHes, cut paths shortened,
  -- a COUNT_LEAF per leaf, and the count as the sum of the products.
  newc := vector ();
  for (i := 0; i < n; i := i + 1)
    {
      c := aref (clauses, i);
      t := aref (c, 0);
      if (t = 'MATCH' and coalesce (aref (c, 1), 0) <> 0)
        {
          if (DB.DBA.GQL_PREAGG_IS_LEAF (leaves, i, -1))
            goto next_clause;
        }
      else if (t = 'MATCH')
        {
          pats := aref (c, 2);
          newpats := vector ();
          for (j := 0; j < length (pats); j := j + 1)
            {
              if (DB.DBA.GQL_PREAGG_IS_LEAF (leaves, i, j))
                goto next_pat;
              newpats := vector_concat (newpats, vector (DB.DBA.GQL_PREAGG_CUT_OF (cuts, i, j, aref (pats, j))));
            next_pat:;
            }
          if (length (newpats) = 0)
            goto next_clause;
          c := vector_concat (vector (aref (c, 0), aref (c, 1), newpats), subseq (c, 3));
        }
      else if (t = 'RETURN')
        {
          prodv := vector ();
          for (nleaf := 0; nleaf < length (leaves); nleaf := nleaf + 1)
            prodv := vector_concat (prodv, vector (vector (nleaf + 1, aref (aref (leaves, nleaf), 4))));
          c := vector_concat (vector (aref (c, 0), aref (c, 1),
            vector (vector (aref (item, 0), vector ('PREAGG_COUNT', prodv), aref (item, 2)))), subseq (c, 3));
        }
      newc := vector_concat (newc, vector (c));
    next_clause:;
    }
  for (nleaf := 0; nleaf < length (leaves); nleaf := nleaf + 1)
    newc := vector_concat (newc, vector (vector ('COUNT_LEAF', aref (aref (leaves, nleaf), 2),
      aref (aref (leaves, nleaf), 3), aref (aref (leaves, nleaf), 4), nleaf + 1)));
  return vector_concat (vector (aref (_q, 0), newc), subseq (_q, 2));
}
;

create procedure DB.DBA.GQL_PREAGG_NAMES_OF (in _x any)
{
  declare nm any;
  nm := vector ();
  DB.DBA.GQL_PREAGG_NAMES (_x, nm);
  return nm;
}
;

-- The clause index of the first mandatory MATCH.
create procedure DB.DBA.GQL_PREAGG_FIRST_MATCH (in _clauses any)
{
  declare i integer;
  for (i := 0; i < length (_clauses); i := i + 1)
    if (aref (aref (_clauses, i), 0) = 'MATCH' and coalesce (aref (aref (_clauses, i), 1), 0) = 0)
      return i;
  return -1;
}
;

-- Whether a mandatory pattern other than unit _ui binds _name.
create procedure DB.DBA.GQL_PREAGG_BOUND_ELSEWHERE (in _units any, in _ui integer, in _name varchar)
{
  declare j integer;
  for (j := 0; j < length (_units); j := j + 1)
    if (j <> _ui and aref (aref (_units, j), 0) = 'P' and DB.DBA.GQL_PLAN_VEC_HAS (aref (aref (_units, j), 3), _name))
      return 1;
  return 0;
}
;

-- Whether clause _ci (pattern _pj; -1 for a whole OPTIONAL MATCH) is a leaf.
create procedure DB.DBA.GQL_PREAGG_IS_LEAF (in _leaves any, in _ci integer, in _pj integer)
{
  declare i integer;
  for (i := 0; i < length (_leaves); i := i + 1)
    if (aref (aref (_leaves, i), 0) = _ci and aref (aref (_leaves, i), 1) = _pj)
      return 1;
  return 0;
}
;

-- Pattern _pj of clause _ci with its cut leaves removed, or _p.
create procedure DB.DBA.GQL_PREAGG_CUT_OF (in _cuts any, in _ci integer, in _pj integer, in _p any)
{
  declare i integer;
  for (i := 0; i < length (_cuts); i := i + 1)
    if (aref (aref (_cuts, i), 0) = _ci and aref (aref (_cuts, i), 1) = _pj)
      return aref (aref (_cuts, i), 2);
  return _p;
}
;

-- A COUNT_LEAF clause: the leaf's matches counted per attachment node in a
-- GROUP BY sub-select, joined to the rest -- OPTIONAL for an OPTIONAL MATCH
-- leaf.  Translated in a context of its own, which hands its fresh-variable
-- counter back.
create procedure DB.DBA.GQL_GEN_COUNT_LEAF (in _leaf any, inout _ctx any)
{
  declare l_ctx any;
  declare att, cnt, body, sub varchar;

  l_ctx := DB.DBA.GQL_CTX_NEW_INNER (_ctx);
  DB.DBA.GQL_GEN_MATCH (vector ('MATCH', 0, aref (_leaf, 2), vector (), 0, null, null), l_ctx);
  body := concat (DB.DBA.GQL_CTX_GET (l_ctx, 'values'), DB.DBA.GQL_CTX_GET (l_ctx, 'pre_values'),
    DB.DBA.GQL_CTX_GET (l_ctx, 'pre_binds'), DB.DBA.GQL_CTX_GET (l_ctx, 'triples'),
    DB.DBA.GQL_CTX_GET (l_ctx, 'binds'), DB.DBA.GQL_CTX_GET (l_ctx, 'filters'),
    DB.DBA.GQL_CTX_GET (l_ctx, 'optionals'));
  DB.DBA.GQL_CTX_SET (_ctx, 'var_counter', DB.DBA.GQL_CTX_GET (l_ctx, 'var_counter'));
  att := DB.DBA.GQL_NODE_SPARQL_VAR (aref (_leaf, 1));
  cnt := sprintf ('?gql_cnt_%d', aref (_leaf, 4));
  sub := concat ('{ SELECT ', att, ' (COUNT(*) AS ', cnt, ') WHERE {\n', body, '  } GROUP BY ', att, ' }');
  if (aref (_leaf, 3))
    DB.DBA.GQL_CTX_SET (_ctx, 'optionals', concat (DB.DBA.GQL_CTX_GET (_ctx, 'optionals'), '  OPTIONAL ', sub, '\n'));
  else
    DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx, concat ('  ', sub, ' .\n'));
}
;

create procedure DB.DBA.GQL_TO_SPARQL_IMPL (in _ast any, in _graph varchar)
{
  declare node_type varchar;
  declare clauses any;
  declare i, n integer;
  declare ctx any;
  declare has_return, has_insert, has_construct, has_describe, has_delete, has_set, has_remove, has_ask, has_modify integer;
  declare has_finish integer;
  declare return_ast, insert_asts, construct_asts, describe_ast, delete_ast, set_ast, remove_ast, modify_ast any;
  declare n_pre_match_inserts integer;
  declare match_asts, where_asts, minus_asts, preagg_leaves any;
  declare for_asts, let_asts, service_asts, pattern_asts any;
  declare use_ast any;
  declare group_ast, having_ast any;
  declare order_ast, skip_ast, limit_ast any;
  declare catalog_asts, call_asts any;
  declare order_clause, limit_clause, skip_clause varchar;
  declare is_distinct integer;
  declare clause, ctype any;

  -- Navigate AST to QUERY
  if (not isarray (_ast)) signal ('G2000', 'Invalid AST');
  node_type := aref (_ast, 0);

  if (node_type = 'PROG')
    {
      declare proc_body, trans_act any;
      proc_body := aref (_ast, 1);
      trans_act := aref (_ast, 2);

      -- PROC body (the normal code path)
      if (proc_body is not null and isarray (proc_body) and aref (proc_body, 0) = 'PROC')
        return DB.DBA.GQL_TO_SPARQL_IMPL (proc_body, _graph);

      -- Transaction commands: START TRANSACTION / COMMIT / ROLLBACK
      -- Virtuoso auto-commits each request, so these are accepted as no-ops.
      if (trans_act is not null and isarray (trans_act))
        {
          if (aref (trans_act, 0) = 'TRANS_END')
            return '';  -- COMMIT/ROLLBACK: no SPARQL emitted
          if (aref (trans_act, 0) = 'TRANSACTION')
            return '';  -- START TRANSACTION: no SPARQL emitted
        }

      -- Session commands (handled separately, may return empty)
      if (proc_body is not null and isarray (proc_body))
        {
          declare ptype varchar;
          ptype := aref (proc_body, 0);
          if (ptype = 'SESSION_SET' or ptype = 'SESSION_RESET')
            return '';  -- Session commands handled by endpoint, not translated
        }

      return '';
    }

  if (node_type = 'PROC')
    {
      declare stmt, at_schema, binding_defs, stmt_clauses any;
      at_schema := aref (_ast, 1);
      binding_defs := aref (_ast, 2);
      stmt := aref (_ast, 3);
      if (stmt is not null and isarray (stmt))
        {
          if (at_schema is not null)
            {
              if (isarray (at_schema) and aref (at_schema, 0) = 'ANY_GRAPH')
                _graph := null;
              else if (isarray (at_schema) and aref (at_schema, 0) = 'HOME_GRAPH')
                _graph := DB.DBA.GQL_HOME_GRAPH ();
              else if (isarray (at_schema) and aref (at_schema, 0) = 'USE_PROPERTY_AT_SCHEMA')
                {
                  -- USE PROPERTY GRAPH at schema level: derive graph IRI
                  -- and per-graph namespaces from the bare graph name.
                  declare pg_ref any;
                  declare pg_name varchar;
                  pg_ref := aref (at_schema, 1);
                  if (isarray (pg_ref) and length (pg_ref) > 1 and aref (pg_ref, 0) = 'GRAPH_REF')
                    {
                      pg_name := cast (aref (pg_ref, 1) as varchar);
                      _graph := DB.DBA.GQL_PG_GRAPH_IRI (pg_name);
                      -- Stash per-graph NS for propagation into the query
                      connection_set ('__gql_pg_ontology_ns', DB.DBA.GQL_PG_ONTOLOGY_NS (pg_name));
                      connection_set ('__gql_pg_data_ns', DB.DBA.GQL_PG_DATA_NS (pg_name));
                      connection_set ('__gql_pg_is_property_graph', 1);
                      connection_set ('__gql_pg_name', pg_name);
                    }
                  else
                    _graph := DB.DBA.GQL_GRAPH_REF_VALUE (pg_ref);
                }
              else
                {
                  declare graph_ctx any;
                  declare bi integer;
                  graph_ctx := DB.DBA.GQL_CTX_NEW (_graph);
                  for (bi := 0; bi < length (binding_defs); bi := bi + 1)
                    {
                      if (isarray (aref (binding_defs, bi)) and aref (aref (binding_defs, bi), 0) = 'PREFIX')
                        DB.DBA.GQL_CTX_ADD_PREFIX (graph_ctx, aref (aref (binding_defs, bi), 1), aref (aref (binding_defs, bi), 2));
                      else if (isarray (aref (binding_defs, bi)) and aref (aref (binding_defs, bi), 0) = 'BASE')
                        DB.DBA.GQL_CTX_SET (graph_ctx, 'base_uri', aref (aref (binding_defs, bi), 1));
                      else if (isarray (aref (binding_defs, bi)) and aref (aref (binding_defs, bi), 0) = 'VERSION')
                        {
                          declare _ver_str varchar;
                          _ver_str := lower (cast (aref (aref (binding_defs, bi), 1) as varchar));
                          if (_ver_str like 'rdf 1.2%' or _ver_str like '1.2%'
                              or _ver_str like 'rdf12%' or _ver_str like '"rdf 1.2"%')
                            DB.DBA.GQL_CTX_SET (graph_ctx, 'rdf12_mode', 1);
                        }
                    }
                  _graph := DB.DBA.GQL_GRAPH_REF_VALUE_CTX (at_schema, graph_ctx);
                }
            }
          -- Merge binding defs (PREFIX, BASE, DEFINE) and USE_ANY_GRAPH
          -- into leaf QUERY nodes. For SETOP nodes, propagate recursively
          -- into both branches so prefixes are visible in all sub-queries.
          if (binding_defs is not null and length (binding_defs) > 0)
            stmt := DB.DBA.GQL_PROC_MERGE_BINDINGS (stmt, binding_defs);
          if (at_schema is not null and isarray (at_schema) and aref (at_schema, 0) = 'ANY_GRAPH')
            stmt := DB.DBA.GQL_PROC_MERGE_USE_ANY_GRAPH (stmt);
          -- Opt-in: a count(*) query counts its leaves first
          -- (GQL_PREAGG_REWRITE).  Only a top-level QUERY: set operations and
          -- nested queries are left as they are.
          if (aref (stmt, 0) = 'QUERY' and coalesce (registry_get ('__gql_count_preagg'), 'off') = 'on')
            stmt := DB.DBA.GQL_PREAGG_REWRITE (stmt);
          return DB.DBA.GQL_TO_SPARQL_IMPL (stmt, _graph);
        }
      signal ('G2000', 'Expected QUERY inside PROC');
    }

  -- SETOP: UNION / EXCEPT / INTERSECT between two query branches
  if (node_type = 'SETOP')
    {
      declare setop_name varchar;
      declare left_ast, right_ast any;
      declare left_sparql, right_sparql varchar;

      setop_name := aref (_ast, 1);
      left_ast := aref (_ast, 2);
      right_ast := aref (_ast, 3);

      left_sparql := DB.DBA.GQL_TO_SPARQL_IMPL (left_ast, _graph);
      right_sparql := DB.DBA.GQL_TO_SPARQL_IMPL (right_ast, _graph);

      return DB.DBA.GQL_SETOP_COMBINE (setop_name, left_sparql, right_sparql);
    }

  if (node_type <> 'QUERY')
    signal ('G2000', sprintf ('Expected QUERY node, got %s', node_type));

  -- Check for unsupported catalog/session features
  clauses := aref (_ast, 1);
  for (i := 0; i < length (clauses); i := i + 1)
    {
      clause := aref (clauses, i);
      if (not isarray (clause)) goto unsup_next;
      ctype := aref (clause, 0);
    unsup_next:;
    }

  -- Initialize
  if (_graph is null) _graph := DB.DBA.GQL_SESSION_DEFAULT_GRAPH ();
  ctx := DB.DBA.GQL_CTX_NEW (_graph);
  -- Propagate per-graph NS from proc body USE PROPERTY GRAPH (if set)
  {
    declare pg_ons, pg_dns, pg_nm varchar;
    declare pg_flag integer;
    pg_ons := connection_get ('__gql_pg_ontology_ns');
    pg_dns := connection_get ('__gql_pg_data_ns');
    pg_flag := connection_get ('__gql_pg_is_property_graph');
    pg_nm := connection_get ('__gql_pg_name');
    if (pg_ons is not null)
      DB.DBA.GQL_CTX_SET (ctx, 'ontology_ns', pg_ons);
    if (pg_dns is not null)
      DB.DBA.GQL_CTX_SET (ctx, 'data_ns', pg_dns);
    if (pg_flag = 1)
      DB.DBA.GQL_CTX_SET (ctx, 'is_property_graph', 1);
    if (pg_nm is not null)
      DB.DBA.GQL_CTX_SET (ctx, 'pg_name', pg_nm);
    -- Clear the stashed values so they don't leak to subsequent queries
    connection_set ('__gql_pg_ontology_ns', null);
    connection_set ('__gql_pg_data_ns', null);
    connection_set ('__gql_pg_is_property_graph', 0);
    connection_set ('__gql_pg_name', null);
  }
  n := length (clauses);

  has_return := 0;
  has_finish := 0;
  has_insert := 0;
  has_construct := 0;
  has_describe := 0;
  has_delete := 0;
  has_set := 0;
  has_remove := 0;
  has_ask := 0;
  has_modify := 0;
  return_ast := null;
  insert_asts := vector ();
  -- The number of INSERT clauses before the first MATCH: -1 until a MATCH.
  n_pre_match_inserts := -1;
  construct_asts := vector ();
  describe_ast := null;
  delete_ast := null;
  set_ast := null;
  remove_ast := null;
  modify_ast := null;
  match_asts := vector ();
  where_asts := vector ();
  minus_asts := vector ();
  preagg_leaves := vector ();
  service_asts := vector ();
  pattern_asts := vector ();
  for_asts := vector ();
  let_asts := vector ();
  group_ast := null;
  having_ast := null;
  order_ast := null;
  skip_ast := null;
  limit_ast := null;
  use_ast := null;
  catalog_asts := vector ();
  call_asts := vector ();
  order_clause := '';
  limit_clause := '';
  skip_clause := '';
  is_distinct := 0;

  -- Classify clauses
  for (i := 0; i < n; i := i + 1)
    {
      clause := aref (clauses, i);
      if (not isarray (clause)) goto class_next;
      ctype := aref (clause, 0);

      if (ctype = 'MATCH')
        {
          match_asts := vector_concat (match_asts, vector (clause));
          if (n_pre_match_inserts < 0)
            n_pre_match_inserts := length (insert_asts);
          pattern_asts := vector_concat (pattern_asts, vector (clause));
          if (length (clause) > 4 and aref (clause, 4) = 1)
            DB.DBA.GQL_CTX_SET (ctx, 'suppress_default_from', 1);
        }
      -- A FILTER statement filters the working rows as WHERE does.
      else if (ctype = 'WHERE' or ctype = 'FILTER')
        {
          where_asts := vector_concat (where_asts, vector (clause));
          DB.DBA.GQL_CTX_SET (ctx, 'has_where_filters', 1);
        }
      else if (ctype = 'RETURN')
        { has_return := 1; return_ast := clause; }
      else if (ctype = 'FINISH')
        { has_finish := 1; }
      else if (ctype = 'INSERT')
        {
          has_insert := 1; insert_asts := vector_concat (insert_asts, vector (clause));
          -- Inline target graph: INSERT INTO GRAPH <g> (...)
          if (length (clause) > 2 and aref (clause, 2) is not null)
            {
              declare ins_graph_val varchar;
              ins_graph_val := DB.DBA.GQL_GRAPH_REF_VALUE_CTX (aref (clause, 2), ctx);
              DB.DBA.GQL_CTX_SET (ctx, 'graph', ins_graph_val);
              DB.DBA.GQL_CTX_SET (ctx, 'active_graph', ins_graph_val);
            }
        }
      else if (ctype = 'INSERT_PROPERTY')
        {
          has_insert := 1; insert_asts := vector_concat (insert_asts, vector (clause));
          -- Inline target: INSERT INTO PROPERTY GRAPH <g> (...)
          -- Bind per-graph ontology/data namespaces from the graph name.
          if (length (clause) > 2 and aref (clause, 2) is not null)
            {
              DB.DBA.GQL_CTX_BIND_PROPERTY_GRAPH (ctx, aref (clause, 2));
              -- Reject INSERT into a virtual (read-only) property graph
              declare ins_pg_name varchar;
              ins_pg_name := DB.DBA.GQL_CTX_GET (ctx, 'pg_name');
              if (ins_pg_name is not null
                  and __proc_exists ('DB.DBA.GQL_PG_DEF_GET') is not null)
                {
                  declare ins_meta any;
                  ins_meta := DB.DBA.GQL_PG_DEF_GET (ins_pg_name);
                  if (ins_meta is not null and aref (ins_meta, 0) = 'virtual')
                    signal ('GQ213',
                      sprintf ('Cannot INSERT into virtual property graph %s; virtual PGs are read-only views. Use CREATE PHYSICAL PROPERTY GRAPH for writable graphs.',
                        ins_pg_name));
                }
            }
        }
      else if (ctype = 'CONSTRUCT')
        { has_construct := 1; construct_asts := vector_concat (construct_asts, vector (clause)); }
      else if (ctype = 'DESCRIBE')
        { has_describe := 1; describe_ast := clause; }
      else if (ctype = 'DELETE')
        { has_delete := 1; delete_ast := clause; }
      else if (ctype = 'SET')
        { has_set := 1; set_ast := clause; }
      else if (ctype = 'REMOVE')
        { has_remove := 1; remove_ast := clause; }
      else if (ctype = 'ASK')
        { has_ask := 1; }
      else if (ctype = 'MODIFY')
        { has_modify := 1; modify_ast := clause; }
      else if (ctype = 'MINUS')
        { minus_asts := vector_concat (minus_asts, vector (clause)); }
      else if (ctype = 'COUNT_LEAF')
        { preagg_leaves := vector_concat (preagg_leaves, vector (clause)); }
      else if (ctype = 'USE')
        {
          declare use_graph_val varchar;
          use_graph_val := DB.DBA.GQL_GRAPH_REF_VALUE_CTX (aref (clause, 1), ctx);
          use_ast := clause;
          DB.DBA.GQL_CTX_SET (ctx, 'graph', use_graph_val);
          DB.DBA.GQL_CTX_SET (ctx, 'active_graph', use_graph_val);
        }
      else if (ctype = 'USE_PROPERTY')
        {
          -- USE PROPERTY GRAPH <name>: bind the property graph with
          -- per-graph ontology and data namespaces derived from the name.
          use_ast := clause;
          DB.DBA.GQL_CTX_BIND_PROPERTY_GRAPH (ctx, aref (clause, 1));
        }
      else if (ctype = 'USE_ANY_GRAPH')
        { use_ast := clause; DB.DBA.GQL_CTX_SET (ctx, 'suppress_default_from', 1); }
      else if (ctype = 'USE_HOME_GRAPH')
        {
          -- USE HOME_PROPERTY_GRAPH: bind the configured home graph as a
          -- concrete named graph, regardless of the [GQL] mode flag.
          declare home_graph_val varchar;
          home_graph_val := DB.DBA.GQL_HOME_GRAPH ();
          use_ast := clause;
          DB.DBA.GQL_CTX_SET (ctx, 'graph', home_graph_val);
          DB.DBA.GQL_CTX_SET (ctx, 'active_graph', home_graph_val);
        }
      else if (ctype = 'FROM_CLAUSE')
        {
          declare extra_from any;
          extra_from := DB.DBA.GQL_CTX_GET (ctx, 'extra_from_graphs');
          extra_from := vector_concat (extra_from,
            vector (vector (aref (clause, 1), DB.DBA.GQL_GRAPH_REF_VALUE_CTX (aref (clause, 2), ctx))));
          DB.DBA.GQL_CTX_SET (ctx, 'extra_from_graphs', extra_from);
        }
      else if (ctype = 'WITH')
        {
          DB.DBA.GQL_CTX_SET (ctx, 'with_graph', DB.DBA.GQL_GRAPH_REF_VALUE_CTX (aref (clause, 1), ctx));
        }
      else if (ctype = 'USING_CLAUSE')
        {
          declare using_list any;
          using_list := DB.DBA.GQL_CTX_GET (ctx, 'using_graphs');
          using_list := vector_concat (using_list,
            vector (vector (aref (clause, 1), DB.DBA.GQL_GRAPH_REF_VALUE_CTX (aref (clause, 2), ctx))));
          DB.DBA.GQL_CTX_SET (ctx, 'using_graphs', using_list);
        }
      else if (ctype = 'SERVICE')
        {
          service_asts := vector_concat (service_asts, vector (clause));
          pattern_asts := vector_concat (pattern_asts, vector (clause));
        }
      else if (ctype = 'PREFIX')
        { DB.DBA.GQL_CTX_ADD_PREFIX (ctx, aref (clause, 1), aref (clause, 2)); }
      else if (ctype = 'BASE')
        { DB.DBA.GQL_CTX_SET (ctx, 'base_uri', aref (clause, 1)); }
      else if (ctype = 'DEFINE')
        {
          -- input:rdf12 / input:rdf-star set GQL's RDF 1.2 mode, as
          -- VERSION "rdf 1.2" does; SPARQL does not know them.
          if (lower (cast (aref (clause, 1) as varchar)) = 'input:rdf-star'
              or lower (cast (aref (clause, 1) as varchar)) = 'input:rdf12')
            DB.DBA.GQL_CTX_SET (ctx, 'rdf12_mode', 1);
          else
            DB.DBA.GQL_CTX_ADD_DEFINE (ctx, aref (clause, 1), aref (clause, 2));
        }
      else if (ctype = 'VERSION')
        {
          declare ver_str varchar;
          ver_str := lower (cast (aref (clause, 1) as varchar));
          if (ver_str like 'rdf 1.2%' or ver_str like '1.2%'
              or ver_str like 'rdf12%' or ver_str like '"rdf 1.2"%')
            DB.DBA.GQL_CTX_SET (ctx, 'rdf12_mode', 1);
        }
      else if (ctype = 'FORCE_CAMELCASE')
        { DB.DBA.GQL_CTX_SET (ctx, 'force_camelcase', 1); }
      else if (ctype = 'UNION')
        { ; }  -- handled at a higher level
      else if (ctype = 'FOR')
        for_asts := vector_concat (for_asts, vector (clause));
      else if (ctype = 'UNNEST')
        for_asts := vector_concat (for_asts, vector (clause));
      else if (ctype = 'LET')
        let_asts := vector_concat (let_asts, vector (clause));
      else if (ctype = 'LET_GRAPH')
        let_asts := vector_concat (let_asts, vector (clause));
      else if (ctype = 'LET_TABLE')
        let_asts := vector_concat (let_asts, vector (clause));
      else if (ctype = 'GROUP' or ctype = 'GROUP_SETS' or ctype = 'GROUP_CUBE' or ctype = 'GROUP_ROLLUP')
        group_ast := clause;
      else if (ctype = 'HAVING')
        having_ast := clause;
      else if (ctype = 'ORDER')
        order_ast := clause;
      else if (ctype = 'SKIP')
        skip_ast := clause;
      else if (ctype = 'LIMIT')
        limit_ast := clause;
      else if (ctype = 'CALL' or ctype = 'CALL_INLINE')
        call_asts := vector_concat (call_asts, vector (clause));
      else if (ctype = 'CREATE_GRAPH' or ctype = 'DROP_GRAPH'
               or ctype = 'DROP_PROPERTY_GRAPH'
               or ctype = 'CREATE_PROPERTY_GRAPH_V2'
               or ctype = 'CREATE_SCHEMA' or ctype = 'DROP_SCHEMA'
               or ctype = 'CREATE_GRAPH_TYPE' or ctype = 'DROP_GRAPH_TYPE'
               or ctype = 'LOAD' or ctype = 'CLEAR')
        catalog_asts := vector_concat (catalog_asts, vector (clause));

    class_next:;
    }

  -- DELETE of a property, DELETE p.x, removes it: the same as REMOVE p.x.
  if (has_delete and isarray (delete_ast) and length (delete_ast) > 3
      and coalesce (aref (delete_ast, 3), 'NORMAL') = 'NORMAL')
    {
      declare d_items, d_keep, d_moved any;
      declare d_i integer;
      d_items := aref (delete_ast, 2);
      d_keep := vector ();
      d_moved := vector ();
      for (d_i := 0; d_i < length (d_items); d_i := d_i + 1)
        {
          if (isarray (aref (d_items, d_i)) and aref (aref (d_items, d_i), 0) = 'PROP')
            d_moved := vector_concat (d_moved, vector (vector ('RMPROP', aref (d_items, d_i))));
          else
            d_keep := vector_concat (d_keep, vector (aref (d_items, d_i)));
        }
      if (length (d_moved) > 0)
        {
          if (has_remove)
            remove_ast := vector ('REMOVE', vector_concat (aref (remove_ast, 1), d_moved));
          else
            remove_ast := vector ('REMOVE', d_moved);
          has_remove := 1;
          if (length (d_keep) = 0)
            {
              has_delete := 0;
              delete_ast := null;
            }
          else
            aset (delete_ast, 2, d_keep);
        }
    }

  -- FINISH ends a statement that returns nothing: a read runs and gives no
  -- rows (RETURN 1 LIMIT 0); a write is the write.
  if (has_finish and not has_return
      and not (has_insert or has_delete or has_set or has_remove or has_construct or has_describe))
    {
      has_return := 1;
      return_ast := vector ('RETURN', 0, vector (vector ('RETITEM', vector ('LIT', 1), 'finish')),
        vector (), null, vector ('LIT', 0));
    }

  -- Reject writes against a virtual (read-only) property graph selected
  -- via USE PROPERTY GRAPH.  (The inline INSERT INTO PROPERTY GRAPH form
  -- is checked above; this covers USE PROPERTY GRAPH <v> ... INSERT/SET/
  -- REMOVE/DELETE.)  Virtual PGs map to relational tables through quad
  -- maps and are not writable.
  if (has_insert or has_set or has_remove or has_delete)
    {
      declare _wr_pg_name varchar;
      _wr_pg_name := DB.DBA.GQL_CTX_GET (ctx, 'pg_name');
      if (_wr_pg_name is not null
          and __proc_exists ('DB.DBA.GQL_PG_DEF_GET') is not null)
        {
          declare _wr_meta any;
          _wr_meta := DB.DBA.GQL_PG_DEF_GET (_wr_pg_name);
          if (_wr_meta is not null and aref (_wr_meta, 0) = 'virtual')
            signal ('GQ213',
              sprintf ('Cannot write to virtual property graph %s; virtual PGs are read-only views. Use CREATE PHYSICAL PROPERTY GRAPH for writable graphs.',
                _wr_pg_name));
        }
    }

  -- Pull MATCH-attached FROM <graph> clauses into the dataset list
  for (i := 0; i < length (match_asts); i := i + 1)
    {
      declare m_ast, m_from_graphs any;
      declare j integer;
      m_ast := aref (match_asts, i);
      if (length (m_ast) > 3)
        {
          m_from_graphs := aref (m_ast, 3);
          for (j := 0; j < length (m_from_graphs); j := j + 1)
            {
              declare fg any;
              declare extra_from any;
              fg := aref (m_from_graphs, j);
              extra_from := DB.DBA.GQL_CTX_GET (ctx, 'extra_from_graphs');
              extra_from := vector_concat (extra_from,
                vector (vector (aref (fg, 0), DB.DBA.GQL_GRAPH_REF_VALUE_CTX (aref (fg, 1), ctx))));
              DB.DBA.GQL_CTX_SET (ctx, 'extra_from_graphs', extra_from);
            }
        }
    }

  -- CALL inline procedure: translate inner query as sub-SELECT
  if (length (call_asts) > 0)
    {
      if (length (match_asts) > 0 or has_return or has_insert or has_construct or has_describe or has_delete
          or has_set or has_remove or length (where_asts) > 0
          or length (for_asts) > 0 or length (let_asts) > 0
          or group_ast is not null or having_ast is not null
          or order_ast is not null or skip_ast is not null or limit_ast is not null
          or length (service_asts) > 0 or use_ast is not null
          or length (catalog_asts) > 0)
        signal ('G5001', 'CALL cannot be combined with other query or DML clauses — CALL is standalone');
      return DB.DBA.GQL_GEN_CALL (call_asts, ctx);
    }

  -- Catalog operations (CREATE/DROP GRAPH/SCHEMA/GRAPH TYPE + LOAD/CLEAR)
  if (length (catalog_asts) > 0)
    {
      -- Catalog operations are standalone — reject mixed DDL+query statements
      if (length (match_asts) > 0 or has_return or has_insert or has_construct or has_describe or has_delete
          or has_set or has_remove or length (where_asts) > 0
          or length (for_asts) > 0 or length (let_asts) > 0
          or group_ast is not null or having_ast is not null
          or order_ast is not null or skip_ast is not null or limit_ast is not null)
        signal ('G4005', 'Catalog operations (CREATE/DROP/LOAD/CLEAR) cannot be combined with query or DML clauses');
      return DB.DBA.GQL_GEN_CATALOG (catalog_asts, ctx);
    }

  -- SERVICE-only queries and MATCH ALL suppress the synthesized default FROM.
  if ((length (service_asts) > 0 and length (match_asts) = 0 and use_ast is null
       and length (DB.DBA.GQL_CTX_GET (ctx, 'extra_from_graphs')) = 0)
      or DB.DBA.GQL_CTX_GET (ctx, 'suppress_default_from') = 1)
    DB.DBA.GQL_CTX_SET (ctx, 'suppress_default_from', 1);

  -- A variable only an OPTIONAL MATCH binds must not get its WHERE/FILTER
  -- constant as a start value: bound before the OPTIONAL, it would keep every
  -- row the optional part did not match, now carrying the constant.  Nor
  -- must a lone node's: the node set would be enumerated in full before the
  -- join, where a FILTER is pushed into it.
  declare opt_vars, mand_vars, prebind_skip any;
  opt_vars := vector ();
  mand_vars := vector ();
  prebind_skip := vector ();
  for (i := 0; i < length (match_asts); i := i + 1)
    {
      declare pm, pms any;
      declare pj integer;
      pm := aref (match_asts, i);
      pms := aref (pm, 2);
      for (pj := 0; pj < length (pms); pj := pj + 1)
        {
          if (aref (pm, 1) is not null and aref (pm, 1) <> 0)
            opt_vars := DB.DBA.GQL_PLAN_COLLECT_PATTERN_VARS (aref (pms, pj), opt_vars);
          else
            mand_vars := DB.DBA.GQL_PLAN_COLLECT_PATTERN_VARS (aref (pms, pj), mand_vars);
          if (DB.DBA.GQL_LONE_NODE_VAR (aref (pms, pj)) is not null)
            prebind_skip := DB.DBA.GQL_PLAN_VEC_ADD (prebind_skip, DB.DBA.GQL_LONE_NODE_VAR (aref (pms, pj)));
        }
    }
  for (i := 0; i < length (opt_vars); i := i + 1)
    if (not DB.DBA.GQL_PLAN_VEC_HAS (mand_vars, aref (opt_vars, i)))
      prebind_skip := DB.DBA.GQL_PLAN_VEC_ADD (prebind_skip, aref (opt_vars, i));
  DB.DBA.GQL_CTX_SET (ctx, 'prebind_skip', prebind_skip);

  -- Pre-bind simple equality constraints before MATCH where possible.
  -- Path-step materialisation must use BIND, not VALUES: Virtuoso accepts
  -- BIND anchors for T_STEP(?source), while VALUES anchors can fail.
  if (DB.DBA.GQL_MATCHES_HAVE_SHORTEST_PATH_VAR (match_asts))
    {
      for (i := 0; i < length (where_asts); i := i + 1)
        DB.DBA.GQL_BIND_ENDPOINT_FILTERS (aref (aref (where_asts, i), 1), ctx);
    }
  else
    {
      for (i := 0; i < length (where_asts); i := i + 1)
        DB.DBA.GQL_PREBIND_ENDPOINT_FILTERS (aref (aref (where_asts, i), 1), ctx);
    }

  -- Emit MATCH and SERVICE clauses in source order → triple patterns / SERVICE blocks
  for (i := 0; i < length (pattern_asts); i := i + 1)
    {
      declare p_ast any;
      declare p_type varchar;
      p_ast := aref (pattern_asts, i);
      p_type := aref (p_ast, 0);
      if (p_type = 'MATCH')
        {
          if (length (p_ast) > 4 and aref (p_ast, 4) = 1)
            DB.DBA.GQL_CTX_SET (ctx, 'suppress_default_from', 1);
          DB.DBA.GQL_GEN_MATCH (p_ast, ctx);
        }
      else if (p_type = 'SERVICE')
        DB.DBA.GQL_GEN_SERVICE (p_ast, ctx);
    }

  -- Count pre-aggregation: each leaf counted per attachment node.
  for (i := 0; i < length (preagg_leaves); i := i + 1)
    DB.DBA.GQL_GEN_COUNT_LEAF (aref (preagg_leaves, i), ctx);

  -- Emit FOR/UNNEST list bindings as SPARQL VALUES.
  for (i := 0; i < length (for_asts); i := i + 1)
    {
      declare fc any;
      fc := aref (for_asts, i);
      if (aref (fc, 0) = 'UNNEST')
        DB.DBA.GQL_GEN_UNNEST (fc, ctx);
      else
        DB.DBA.GQL_GEN_FOR_VALUES (fc, ctx);
    }

  -- Emit LET clauses → BIND (after MATCH/FOR so referenced vars are bound,
  -- before WHERE/FILTER so filter can reference LET variables).
  for (i := 0; i < length (let_asts); i := i + 1)
    {
      declare let_ast, let_var, let_expr any;
      declare let_sparql_var, let_sparql_expr varchar;
      declare let_type varchar;
      let_ast := aref (let_asts, i);
      let_type := aref (let_ast, 0);
      let_var := aref (let_ast, 1);

      if (let_type = 'LET_GRAPH')
        {
          -- GRAPH var = graphRef: set the active graph for subsequent patterns
          declare graph_ref any;
          declare graph_val varchar;
          graph_ref := aref (let_ast, 2);
          graph_val := DB.DBA.GQL_GRAPH_REF_VALUE_CTX (graph_ref, ctx);
          let_sparql_var := concat ('?gql_v_', let_var);
          DB.DBA.GQL_CTX_ADD_BIND (ctx, let_sparql_var, concat ('IRI(', graph_val, ')'));
          DB.DBA.GQL_CTX_ADD_VAR (ctx, let_var);
          DB.DBA.GQL_CTX_ADD_ALIAS (ctx, let_var, let_sparql_var);
          -- Also register as a graph reference for FROM clauses
          DB.DBA.GQL_CTX_SET (ctx, 'graph', graph_val);
          DB.DBA.GQL_CTX_SET (ctx, 'active_graph', graph_val);
        }
      else if (let_type = 'LET_TABLE')
        {
          -- TABLE var = (subquery): emit as sub-SELECT and bind result
          declare sub_query any;
          declare sub_sparql varchar;
          declare saved_graph varchar;
          sub_query := aref (let_ast, 2);
          saved_graph := DB.DBA.GQL_CTX_GET (ctx, 'graph');
          sub_sparql := DB.DBA.GQL_TO_SPARQL_IMPL (sub_query, saved_graph);
          -- Strip 'SPARQL ' prefix for inline use
          if (length (sub_sparql) >= 7 and subseq (sub_sparql, 0, 7) = 'SPARQL ')
            sub_sparql := subseq (sub_sparql, 7);
          let_sparql_var := concat ('?gql_v_', let_var);
          DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (ctx, concat ('  { ', sub_sparql, ' }\n'));
          DB.DBA.GQL_CTX_ADD_VAR (ctx, let_var);
          DB.DBA.GQL_CTX_ADD_ALIAS (ctx, let_var, let_sparql_var);
        }
      else
        {
          -- LET var = expr: simple value binding
          let_expr := aref (let_ast, 2);
          let_sparql_var := concat ('?gql_v_', let_var);
          let_sparql_expr := DB.DBA.GQL_GEN_EXPR (let_expr, ctx);
          DB.DBA.GQL_CTX_ADD_BIND (ctx, let_sparql_var, let_sparql_expr);
          DB.DBA.GQL_CTX_ADD_VAR (ctx, let_var);
          DB.DBA.GQL_CTX_ADD_ALIAS (ctx, let_var, let_sparql_var);
        }
    }

  -- Emit WHERE clauses → FILTER
  for (i := 0; i < length (where_asts); i := i + 1)
    {
      declare wexpr varchar;
      wexpr := DB.DBA.GQL_GEN_EXPR (aref (aref (where_asts, i), 1), ctx);
      DB.DBA.GQL_CTX_ADD_FILTER (ctx, wexpr);
    }

  -- Emit MINUS patterns → MINUS { ... } blocks
  for (i := 0; i < length (minus_asts); i := i + 1)
    {
      declare m_ast any;
      declare m_patterns, m_body varchar;
      declare mi integer;
      declare m_ctx any;
      m_ast := aref (minus_asts, i);
      m_patterns := aref (m_ast, 1);
      -- Build MINUS body in a sub-context so triples don't pollute the main WHERE
      m_ctx := DB.DBA.GQL_CTX_NEW_INNER (ctx);
      for (mi := 0; mi < length (m_patterns); mi := mi + 1)
        DB.DBA.GQL_GEN_MATCH (vector ('MATCH', 0, vector (aref (m_patterns, mi)), vector (), 0, null), m_ctx);
      m_body := DB.DBA.GQL_CTX_GET (m_ctx, 'triples');
      m_body := concat (m_body, DB.DBA.GQL_CTX_GET (m_ctx, 'binds'));
      m_body := concat (m_body, DB.DBA.GQL_CTX_GET (m_ctx, 'filters'));
      DB.DBA.GQL_CTX_SET (ctx, 'var_counter', DB.DBA.GQL_CTX_GET (m_ctx, 'var_counter'));
      DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (ctx, concat ('  MINUS {\n', m_body, '  }\n'));
    }

  -- INSERTs before the first MATCH: the statements of a linear statement
  -- run in order, so they are an update of their own, ahead of the one the
  -- MATCH guards (GQL_RUN and GQL_EXECUTE run the two in one transaction),
  -- and a node they make is the same node in a later INSERT.
  if (has_insert and n_pre_match_inserts > 0 and length (match_asts) > 0
      and coalesce (connection_get ('gql_marker_mode'), '') <> 'all')
    {
      declare pre_ctx, pre_asts, rest_asts any;
      declare pre_sparql, rest_sparql varchar;
      declare pk integer;
      pre_asts := vector ();
      rest_asts := vector ();
      for (pk := 0; pk < length (insert_asts); pk := pk + 1)
        {
          if (pk < n_pre_match_inserts)
            pre_asts := vector_concat (pre_asts, vector (aref (insert_asts, pk)));
          else
            rest_asts := vector_concat (rest_asts, vector (aref (insert_asts, pk)));
        }
      pre_ctx := DB.DBA.GQL_CTX_NEW_INNER (ctx);
      pre_sparql := DB.DBA.GQL_GEN_INSERT_WHERE (pre_asts, vector (), pre_ctx);
      DB.DBA.GQL_CTX_SET (ctx, 'insert_var_terms', DB.DBA.GQL_CTX_GET (pre_ctx, 'insert_var_terms'));
      if (length (rest_asts) > 0)
        {
          if (has_return)
            signal ('G2004', 'INSERT with MATCH and RETURN is not yet supported — use separate statements');
          if (has_delete or has_set or has_remove)
            {
              DB.DBA.GQL_GEN_INSERT_WHERE (rest_asts, match_asts, ctx);
              DB.DBA.GQL_CTX_SET (ctx, 'dml_insert_body', DB.DBA.GQL_CTX_GET (ctx, 'insert_body'));
              rest_sparql := DB.DBA.GQL_GEN_DML (delete_ast, set_ast, remove_ast, ctx);
            }
          else
            rest_sparql := DB.DBA.GQL_GEN_INSERT_WHERE (rest_asts, match_asts, ctx);
        }
      else if (has_delete or has_set or has_remove)
        rest_sparql := DB.DBA.GQL_GEN_DML (delete_ast, set_ast, remove_ast, ctx);
      else
        signal ('G2004', 'A MATCH after INSERT needs a data-modifying statement after it -- INSERT, SET, REMOVE or DELETE');
      return concat (pre_sparql, ';\n', rest_sparql);
    }

  -- Handle INSERT
  if (has_insert and length (match_asts) > 0)
    {
      -- INSERT with MATCH: INSERT { ... } WHERE { ... }
      -- If RETURN is also present, signal error — focused linear
      -- data-modifying statement with RETURN not yet supported.
      if (has_return)
        signal ('G2004', 'INSERT with MATCH and RETURN is not yet supported — use separate statements');
      -- Beside DELETE, SET or REMOVE the INSERT is part of their update
      -- (GQL_GEN_DML): one WHERE, evaluated before anything is deleted.
      if (has_delete or has_set or has_remove)
        {
          DB.DBA.GQL_GEN_INSERT_WHERE (insert_asts, match_asts, ctx);
          DB.DBA.GQL_CTX_SET (ctx, 'dml_insert_body', DB.DBA.GQL_CTX_GET (ctx, 'insert_body'));
          return DB.DBA.GQL_GEN_DML (delete_ast, set_ast, remove_ast, ctx);
        }
      return DB.DBA.GQL_GEN_INSERT_WHERE (insert_asts, match_asts, ctx);
    }

  -- Handle CONSTRUCT
  if (has_construct)
    {
      declare construct_order_items any;
      declare coi integer;
      declare construct_seed_where integer;
      declare construct_limit_expr, construct_offset_expr varchar;
      declare construct_return_body varchar;

      if (has_insert or has_describe or has_delete or has_set or has_remove)
        signal ('G2004', 'CONSTRUCT cannot be combined with DESCRIBE or DML clauses');
      if (group_ast is not null or having_ast is not null)
        signal ('G2004', 'CONSTRUCT with GROUP BY or HAVING is not yet supported');

      construct_order_items := vector ();
      if (order_ast is not null or (has_return and isarray (aref (return_ast, 3)) and length (aref (return_ast, 3)) > 0))
        {
          declare raw_construct_order any;
          if (order_ast is not null)
            raw_construct_order := aref (order_ast, 1);
          else
            raw_construct_order := aref (return_ast, 3);
          for (coi := 0; coi < length (raw_construct_order); coi := coi + 1)
            {
              declare coitem, conulls any;
              coitem := aref (raw_construct_order, coi);
              conulls := null;
              if (length (coitem) > 3)
                conulls := aref (coitem, 3);
              construct_order_items := vector_concat (construct_order_items,
                vector (vector (DB.DBA.GQL_GEN_EXPR (aref (coitem, 1), ctx), aref (coitem, 2), conulls)));
            }
        }
      construct_limit_expr := null;
      construct_offset_expr := null;
      if (limit_ast is not null)
        construct_limit_expr := DB.DBA.GQL_GEN_EXPR (aref (limit_ast, 1), ctx);
      else if (has_return and length (return_ast) > 5 and aref (return_ast, 5) is not null)
        construct_limit_expr := DB.DBA.GQL_GEN_EXPR (aref (return_ast, 5), ctx);
      if (skip_ast is not null)
        construct_offset_expr := DB.DBA.GQL_GEN_EXPR (aref (skip_ast, 1), ctx);
      else if (has_return and length (return_ast) > 4 and aref (return_ast, 4) is not null)
        construct_offset_expr := DB.DBA.GQL_GEN_EXPR (aref (return_ast, 4), ctx);

      construct_return_body := '';
      if (has_return)
        construct_return_body := DB.DBA.GQL_GEN_CONSTRUCT_RETURN_TEMPLATE (return_ast, ctx);
      construct_seed_where := case when length (match_asts) = 0 then 1 else 0 end;

      return DB.DBA.GQL_GEN_CONSTRUCT_WHERE (construct_asts, ctx,
        construct_order_items, construct_limit_expr, construct_offset_expr, construct_return_body,
        construct_seed_where);
    }

  -- Handle DESCRIBE
  if (has_describe)
    {
      declare describe_order_items any;
      declare doi integer;
      declare describe_limit_expr, describe_offset_expr varchar;

      if (has_return or has_insert or has_delete or has_set or has_remove)
        signal ('G2004', 'DESCRIBE cannot be combined with RETURN or DML clauses');
      if (group_ast is not null or having_ast is not null)
        signal ('G2004', 'DESCRIBE with GROUP BY or HAVING is not yet supported');

      describe_order_items := vector ();
      if (order_ast is not null)
        {
          declare raw_describe_order any;
          raw_describe_order := aref (order_ast, 1);
          for (doi := 0; doi < length (raw_describe_order); doi := doi + 1)
            {
              declare doitem, donulls any;
              doitem := aref (raw_describe_order, doi);
              donulls := null;
              if (length (doitem) > 3)
                donulls := aref (doitem, 3);
              describe_order_items := vector_concat (describe_order_items,
                vector (vector (DB.DBA.GQL_GEN_EXPR (aref (doitem, 1), ctx), aref (doitem, 2), donulls)));
            }
        }
      describe_limit_expr := null;
      describe_offset_expr := null;
      if (limit_ast is not null)
        describe_limit_expr := DB.DBA.GQL_GEN_EXPR (aref (limit_ast, 1), ctx);
      if (skip_ast is not null)
        describe_offset_expr := DB.DBA.GQL_GEN_EXPR (aref (skip_ast, 1), ctx);

      return DB.DBA.GQL_GEN_DESCRIBE_WHERE (describe_ast, ctx,
        describe_order_items, describe_limit_expr, describe_offset_expr);
    }

  -- Handle DELETE/INSERT (DML without MATCH returns)
  if (has_delete or has_set or has_remove)
    {
      return DB.DBA.GQL_GEN_DML (delete_ast, set_ast, remove_ast, ctx);
    }

  -- Handle MODIFY: atomic DELETE+INSERT in one operation
  if (has_modify)
    {
      declare mod_sparql varchar;
      declare mod_del_items, mod_ins_patterns any;
      declare mod_del_body, mod_ins_body, mod_where_body varchar;
      declare mdi integer;
      if (has_return)
        signal ('G2004', 'MODIFY with RETURN is not yet supported — use separate statements');
      mod_del_items := aref (modify_ast, 1);
      mod_ins_patterns := aref (modify_ast, 2);
      -- Build DELETE body + WHERE bindings from the delete items.  Each item is
      -- an expression: a bare node variable `n` (delete the whole node) or a
      -- property reference `n.prop` (delete that property).  The object being
      -- deleted is a variable, which must be bound in the WHERE clause or SPARQL
      -- instantiates nothing and the delete silently no-ops.  Bind it with an
      -- OPTIONAL so a paired INSERT still fires when the old value was absent.
      declare mod_opt_extra varchar;
      mod_del_body := '';
      mod_opt_extra := '';
      for (mdi := 0; mdi < length (mod_del_items); mdi := mdi + 1)
        {
          declare mditem any;
          mditem := aref (mod_del_items, mdi);
          if (not isarray (mditem)) goto mod_del_next;
          if (aref (mditem, 0) = 'VAR')
            {
              declare mdvar, mdp, mdo varchar;
              mdvar := DB.DBA.GQL_NODE_SPARQL_VAR (aref (mditem, 1));
              mdp := concat ('?mp', cast (mdi as varchar));
              mdo := concat ('?mo', cast (mdi as varchar));
              mod_del_body := concat (mod_del_body, '  ', mdvar, ' ', mdp, ' ', mdo, ' .\n');
              mod_opt_extra := concat (mod_opt_extra, '  OPTIONAL {\n    ', mdvar, ' ', mdp, ' ', mdo, ' .\n  }\n');
            }
          else if (aref (mditem, 0) = 'PROP')
            {
              declare mdsubj, mdprop, mdrv varchar;
              mdsubj := DB.DBA.GQL_GEN_EXPR (aref (mditem, 1), ctx);
              mdprop := DB.DBA.GQL_GEN_PROP_IRI_CTX (aref (mditem, 2), ctx);
              mdrv := concat ('?mdel', cast (mdi as varchar));
              mod_del_body := concat (mod_del_body, '  ', mdsubj, ' ', mdprop, ' ', mdrv, ' .\n');
              mod_opt_extra := concat (mod_opt_extra, '  OPTIONAL {\n    ', mdsubj, ' ', mdprop, ' ', mdrv, ' .\n  }\n');
            }
          else
            signal ('G2007', 'MODIFY DELETE supports a node variable (n) or a property reference (n.prop)');
        mod_del_next:;
        }
      -- Build INSERT body from insert patterns (reuse INSERT WHERE body builder)
      mod_ins_body := '';
      if (length (mod_ins_patterns) > 0)
        {
          declare mod_ins_asts, mod_ins_sparql any;
          declare mod_prefix_len integer;
          mod_ins_asts := vector (vector ('INSERT', mod_ins_patterns));
          -- Reuse GQL_GEN_INSERT_WHERE to build the INSERT triple body, then
          -- extract just that body (its WHERE, if any, is discarded — MODIFY
          -- supplies its own).  Pass the real MATCH so insert node variables
          -- reference the matched nodes (?gql_n_x) instead of being treated as
          -- fresh nodes with newly minted URIs.
          mod_ins_sparql := DB.DBA.GQL_GEN_INSERT_WHERE (mod_ins_asts, match_asts, ctx);
          -- The body sits inside a GRAPH <g> { ... } block when a graph was
          -- named.  With no graph it is emitted bare: directly under INSERT { ...
          -- } WHERE when there is a MATCH, or under INSERT DATA { ... } when there
          -- is not.  Pick the matching delimiters.
          declare mod_graph_str, mod_close_str varchar;
          declare mod_body_start, mod_body_end integer;
          if (DB.DBA.GQL_DML_HAS_GRAPH (DB.DBA.GQL_CTX_GET (ctx, 'graph')) = 1)
            {
              mod_graph_str := concat ('GRAPH <', DB.DBA.GQL_CTX_GET (ctx, 'graph'), '> {\n');
              mod_close_str := '  }\n';
            }
          else if (length (match_asts) > 0)
            {
              mod_graph_str := 'INSERT {\n';
              mod_close_str := '} WHERE';
            }
          else
            {
              mod_graph_str := 'INSERT DATA {\n';
              mod_close_str := '}\n';
            }
          mod_body_start := strstr (mod_ins_sparql, mod_graph_str);
          if (mod_body_start is not null)
            {
              mod_body_start := mod_body_start + length (mod_graph_str);
              mod_body_end := strstr (subseq (mod_ins_sparql, mod_body_start), mod_close_str);
              if (mod_body_end is not null)
                mod_ins_body := subseq (mod_ins_sparql, mod_body_start, mod_body_start + mod_body_end);
            }
        }
      -- Build WHERE body from accumulated context
      mod_where_body := DB.DBA.GQL_CTX_GET (ctx, 'pre_values');
      mod_where_body := concat (mod_where_body, DB.DBA.GQL_CTX_GET (ctx, 'pre_binds'));
      mod_where_body := concat (mod_where_body, DB.DBA.GQL_CTX_GET (ctx, 'triples'));
      mod_where_body := concat (mod_where_body, DB.DBA.GQL_CTX_GET (ctx, 'binds'));
      mod_where_body := concat (mod_where_body, DB.DBA.GQL_CTX_GET (ctx, 'filters'));
      mod_where_body := concat (mod_where_body, DB.DBA.GQL_CTX_GET (ctx, 'optionals'));
      mod_where_body := concat (mod_where_body, mod_opt_extra);
      -- Compose SPARQL.  Emit the DELETE and INSERT clauses only when non-empty
      -- so an insert-only or delete-only MODIFY does not produce an empty
      -- template block (which Virtuoso rejects as a syntax error).
      mod_sparql := concat ('SPARQL ', DB.DBA.GQL_GEN_DEFINE_CLAUSE (ctx), DB.DBA.GQL_GEN_BASE_CLAUSE (ctx));
      mod_sparql := concat (mod_sparql, 'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>\n');
      mod_sparql := concat (mod_sparql, 'PREFIX gql: <', DB.DBA.GQL_NS_CTX (ctx), '>\n');
      declare mod_g varchar;
      mod_g := DB.DBA.GQL_CTX_GET (ctx, 'graph');
      if (mod_del_body <> '')
        mod_sparql := concat (mod_sparql, 'DELETE {\n', DB.DBA.GQL_DML_G_WRAP (mod_g, mod_del_body), '} ');
      if (mod_ins_body <> '')
        mod_sparql := concat (mod_sparql, 'INSERT {\n', DB.DBA.GQL_DML_G_WRAP (mod_g, mod_ins_body), '} ');
      mod_sparql := concat (mod_sparql, 'WHERE {\n', DB.DBA.GQL_DML_G_OPEN (mod_g));
      mod_sparql := concat (mod_sparql, mod_where_body);
      mod_sparql := concat (mod_sparql, DB.DBA.GQL_DML_G_CLOSE (mod_g), '}\n');
      return mod_sparql;
    }

  -- Handle ASK: boolean query form — emits ASK instead of SELECT
  if (has_ask)
    {
      declare ask_sparql varchar;
      declare ask_where_body varchar;
      if (has_insert or has_delete or has_set or has_remove or has_construct or has_describe)
        signal ('G2004', 'ASK cannot be combined with DML, CONSTRUCT, or DESCRIBE clauses');
      ask_sparql := concat ('SPARQL ',
        DB.DBA.GQL_GEN_DEFINE_CLAUSE (ctx),
        DB.DBA.GQL_EMIT_PREFIX_BLOCK (ctx));
      ask_sparql := concat (ask_sparql, 'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>\n');
      ask_sparql := concat (ask_sparql, 'PREFIX gql: <', DB.DBA.GQL_NS_CTX (ctx), '>\n');
      ask_sparql := concat (ask_sparql, 'ASK ');
      ask_sparql := concat (ask_sparql, DB.DBA.GQL_GEN_FROM_CLAUSES (ctx));
      ask_where_body := '';
      ask_where_body := concat (ask_where_body, DB.DBA.GQL_CTX_GET (ctx, 'values'));
      ask_where_body := concat (ask_where_body, DB.DBA.GQL_CTX_GET (ctx, 'pre_values'));
      ask_where_body := concat (ask_where_body, DB.DBA.GQL_CTX_GET (ctx, 'pre_binds'));
      ask_where_body := concat (ask_where_body, DB.DBA.GQL_CTX_GET (ctx, 'triples'));
      ask_where_body := concat (ask_where_body, DB.DBA.GQL_CTX_GET (ctx, 'binds'));
      ask_where_body := concat (ask_where_body, DB.DBA.GQL_CTX_GET (ctx, 'filters'));
      ask_where_body := concat (ask_where_body, DB.DBA.GQL_CTX_GET (ctx, 'optionals'));
      ask_sparql := concat (ask_sparql, DB.DBA.GQL_EMIT_WHERE (ctx, ask_where_body));
      return ask_sparql;
    }

  -- SERVICE-only SPARQL-FED style query: project variables made visible by
  -- SERVICE clauses even when the outer GQL query omits an explicit RETURN.
  if (not has_return and length (service_asts) > 0)
    {
      declare service_vars any;
      declare svi integer;
      service_vars := DB.DBA.GQL_CTX_GET (ctx, 'vars');
      if (length (service_vars) > 0)
        {
          declare sparql_text, where_body varchar;
          declare proj_items any;
          proj_items := vector ();
          for (svi := 0; svi < length (service_vars); svi := svi + 1)
            {
              declare sv_name varchar;
              sv_name := aref (service_vars, svi);
              proj_items := vector_concat (proj_items,
                vector (vector (DB.DBA.GQL_GEN_EXPR (vector ('VAR', sv_name), ctx), sv_name)));
            }

          sparql_text := concat ('SPARQL ',
            DB.DBA.GQL_GEN_DEFINE_CLAUSE (ctx),
            DB.DBA.GQL_EMIT_PREFIX_BLOCK (ctx));
          sparql_text := concat (sparql_text, 'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>\n');
          sparql_text := concat (sparql_text, 'PREFIX gql: <', DB.DBA.GQL_NS_CTX (ctx), '>\n');
          sparql_text := concat (sparql_text, DB.DBA.GQL_EMIT_SELECT (ctx, 0, proj_items));
          sparql_text := concat (sparql_text, DB.DBA.GQL_GEN_FROM_CLAUSES (ctx));

          where_body := '';
          where_body := concat (where_body, DB.DBA.GQL_CTX_GET (ctx, 'values'));
          where_body := concat (where_body, DB.DBA.GQL_CTX_GET (ctx, 'pre_values'));
          where_body := concat (where_body, DB.DBA.GQL_CTX_GET (ctx, 'pre_binds'));
          where_body := concat (where_body, DB.DBA.GQL_CTX_GET (ctx, 'triples'));
          where_body := concat (where_body, DB.DBA.GQL_CTX_GET (ctx, 'binds'));
          where_body := concat (where_body, DB.DBA.GQL_CTX_GET (ctx, 'filters'));
          where_body := concat (where_body, DB.DBA.GQL_CTX_GET (ctx, 'optionals'));
          sparql_text := concat (sparql_text, DB.DBA.GQL_EMIT_WHERE (ctx, where_body));
          return sparql_text;
        }
    }

  -- Build SELECT query
  if (has_return)
    {
      declare ret_vars any;
      declare sparql_text varchar;

      ret_vars := DB.DBA.GQL_GEN_RETURN (return_ast, ctx, order_clause, limit_clause, skip_clause, is_distinct);

      -- Compose final SPARQL using emission helpers
      declare proj_items any;
      declare where_body varchar;
      declare order_items any;
      declare oi integer;

      -- Build projection items list for gql_emit_select
      proj_items := ret_vars;
      -- Defensive: if no projection items, auto-project all bound vars.
      -- The `= '*'` check is future-proofing for when GQL_GEN_RETURN
      -- may return a literal star placeholder without expanding vars.
      if (length (proj_items) = 0 or (length (proj_items) = 1 and aref (aref (proj_items, 0), 0) = '*'))
        {
          -- No explicit projection: auto-project all bound vars
          declare all_vars any;
          declare vi integer;
          proj_items := vector ();
          all_vars := DB.DBA.GQL_CTX_GET (ctx, 'vars');
          for (vi := 0; vi < length (all_vars); vi := vi + 1)
            proj_items := vector_concat (proj_items, vector (vector (DB.DBA.GQL_NODE_SPARQL_VAR (aref (all_vars, vi)), null)));
        }

      -- Compose SPARQL text
      sparql_text := concat ('SPARQL ',
        DB.DBA.GQL_GEN_DEFINE_CLAUSE (ctx),
        DB.DBA.GQL_EMIT_PREFIX_BLOCK (ctx));
      sparql_text := concat (sparql_text, 'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>\n');
      sparql_text := concat (sparql_text, 'PREFIX gql: <', DB.DBA.GQL_NS_CTX (ctx), '>\n');

      sparql_text := concat (sparql_text,
        DB.DBA.GQL_EMIT_SELECT (ctx, is_distinct, proj_items));

      -- FROM clauses (dataset)
      sparql_text := concat (sparql_text, DB.DBA.GQL_GEN_FROM_CLAUSES (ctx));

      -- WHERE clause body from accumulated context fragments
      where_body := '';
      where_body := concat (where_body, DB.DBA.GQL_CTX_GET (ctx, 'values'));
      where_body := concat (where_body, DB.DBA.GQL_CTX_GET (ctx, 'pre_values'));
      where_body := concat (where_body, DB.DBA.GQL_CTX_GET (ctx, 'pre_binds'));
      where_body := concat (where_body, DB.DBA.GQL_CTX_GET (ctx, 'triples'));
      where_body := concat (where_body, DB.DBA.GQL_CTX_GET (ctx, 'binds'));
      where_body := concat (where_body, DB.DBA.GQL_CTX_GET (ctx, 'filters'));
      where_body := concat (where_body, DB.DBA.GQL_CTX_GET (ctx, 'optionals'));
      if (DB.DBA.GQL_CTX_GET (ctx, 'preagg_sum') is not null)
        where_body := concat ('  { SELECT (', DB.DBA.GQL_CTX_GET (ctx, 'preagg_sum'), ' AS ?gql_cnt_sum) WHERE {\n',
          where_body, '  } }\n');
      sparql_text := concat (sparql_text,
        DB.DBA.GQL_EMIT_WHERE (ctx, where_body));

      -- Result-set-aware graph analytics functions such as degree_centrality()
      -- inject aggregate expressions.  If the user did not provide GROUP BY,
      -- group by the non-aggregate RETURN expressions so the score is computed
      -- per returned node/value rather than over the whole result set.
      if (group_ast is null and DB.DBA.GQL_CTX_GET (ctx, 'needs_auto_group') = 1)
        {
          declare auto_group_vars any;
          declare agi integer;
          auto_group_vars := vector ();
          for (agi := 0; agi < length (aref (return_ast, 2)); agi := agi + 1)
            {
              declare aritem, arexpr any;
              aritem := aref (aref (return_ast, 2), agi);
              arexpr := aref (aritem, 1);
              if (DB.DBA.GQL_EXPR_IS_AGGREGATE (arexpr) = 0)
                auto_group_vars := vector_concat (auto_group_vars, vector (DB.DBA.GQL_GEN_EXPR (arexpr, ctx)));
            }
          if (length (auto_group_vars) > 0)
            sparql_text := concat (sparql_text,
              DB.DBA.GQL_EMIT_GROUP_MODIFIER (ctx, auto_group_vars, null));
        }

      -- GROUP BY
      if (group_ast is not null)
        {
          declare group_type varchar;
          declare group_items any;
          declare group_vars any;
          declare gi integer;
          group_type := aref (group_ast, 0);
          group_items := aref (group_ast, 1);

          if (group_type = 'GROUP_SETS')
            {
              declare group_sets_s varchar;
              declare gsi, gsj integer;
              group_sets_s := 'GROUP BY GROUPING SETS (';
              for (gsi := 0; gsi < length (group_items); gsi := gsi + 1)
                {
                  declare set_exprs any;
                  if (gsi > 0) group_sets_s := concat (group_sets_s, ', ');
                  set_exprs := aref (group_items, gsi);
                  group_sets_s := concat (group_sets_s, '(');
                  for (gsj := 0; gsj < length (set_exprs); gsj := gsj + 1)
                    {
                      if (gsj > 0) group_sets_s := concat (group_sets_s, ', ');
                      group_sets_s := concat (group_sets_s, DB.DBA.GQL_GEN_EXPR (aref (set_exprs, gsj), ctx));
                    }
                  group_sets_s := concat (group_sets_s, ')');
                }
              group_sets_s := concat (group_sets_s, ')\n');
              sparql_text := concat (sparql_text, group_sets_s);
            }
          else if (group_type = 'GROUP_CUBE' or group_type = 'GROUP_ROLLUP')
            {
              declare cube_rollup_s varchar;
              declare cr_kw varchar;
              cr_kw := case when group_type = 'GROUP_CUBE' then 'CUBE' else 'ROLLUP' end;
              cube_rollup_s := concat ('GROUP BY ', cr_kw, ' (');
              for (gi := 0; gi < length (group_items); gi := gi + 1)
                {
                  declare gexpr_sparql varchar;
                  if (gi > 0) cube_rollup_s := concat (cube_rollup_s, ', ');
                  gexpr_sparql := DB.DBA.GQL_GEN_EXPR (aref (group_items, gi), ctx);
                  cube_rollup_s := concat (cube_rollup_s, gexpr_sparql);
                }
              cube_rollup_s := concat (cube_rollup_s, ')\n');
              sparql_text := concat (sparql_text, cube_rollup_s);
            }
          else
            {
              group_vars := vector ();
              if (length (group_items) > 0)
                {
                  for (gi := 0; gi < length (group_items); gi := gi + 1)
                    {
                      declare gexpr_sparql varchar;
                      gexpr_sparql := DB.DBA.GQL_GEN_EXPR (aref (group_items, gi), ctx);
                      group_vars := vector_concat (group_vars, vector (gexpr_sparql));
                    }
                }
              sparql_text := concat (sparql_text,
                DB.DBA.GQL_EMIT_GROUP_MODIFIER (ctx, group_vars, null));
            }
        }

      -- HAVING
      if (having_ast is not null)
        {
          declare having_sparql varchar;
          having_sparql := DB.DBA.GQL_GEN_EXPR (aref (having_ast, 1), ctx);
          -- If we already emitted GROUP BY, we need to re-emit with HAVING.
          -- Since GROUP was emitted above, we emit HAVING as a separate line.
          sparql_text := concat (sparql_text, 'HAVING (', having_sparql, ')\n');
        }

      -- Build order items for gql_emit_solution_modifier
      order_items := vector ();
      if (order_ast is not null or (isarray (aref (return_ast, 3)) and length (aref (return_ast, 3)) > 0))
        {
          declare raw_order any;
          if (order_ast is not null)
            raw_order := aref (order_ast, 1);
          else
            raw_order := aref (return_ast, 3);
          for (oi := 0; oi < length (raw_order); oi := oi + 1)
            {
              declare oitem, onulls any;
              oitem := aref (raw_order, oi);
              onulls := null;
              if (length (oitem) > 3)
                onulls := aref (oitem, 3);
              order_items := vector_concat (order_items,
                vector (vector (DB.DBA.GQL_GEN_EXPR (aref (oitem, 1), ctx), aref (oitem, 2), onulls)));
            }
        }

      declare limit_expr, offset_expr varchar;
      limit_expr := null;
      offset_expr := null;
      if (limit_ast is not null)
        limit_expr := DB.DBA.GQL_GEN_EXPR (aref (limit_ast, 1), ctx);
      else if (length (return_ast) > 5 and aref (return_ast, 5) is not null)
        limit_expr := DB.DBA.GQL_GEN_EXPR (aref (return_ast, 5), ctx);
      if (skip_ast is not null)
        offset_expr := DB.DBA.GQL_GEN_EXPR (aref (skip_ast, 1), ctx);
      else if (length (return_ast) > 4 and aref (return_ast, 4) is not null)
        offset_expr := DB.DBA.GQL_GEN_EXPR (aref (return_ast, 4), ctx);

      sparql_text := concat (sparql_text,
        DB.DBA.GQL_EMIT_SOLUTION_MODIFIER (ctx, order_items,
          limit_expr, offset_expr));

	      return sparql_text;
    }

  -- Standalone INSERT (no MATCH): use INSERT DATA
  if (has_insert and length (match_asts) = 0)
    return DB.DBA.GQL_GEN_INSERT_WHERE (insert_asts, vector (), ctx);

  -- No RETURN clause (INSERT-only queries with MATCH have no output)
  if (has_insert)
    return '';

  signal ('G2000', 'Query has no RETURN clause');
}
;

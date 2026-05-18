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
--  openGQL: GQL for Virtuoso - AST to SPARQL Translator
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
--    'edge_reif_vars'   - vector of edge vars already materialized as RDF reification
--    'reif_graph'       - graph URI for RDF reification triples
--    'active_path_var'  - path variable currently being materialized by T_STEP
--    'has_where_filters'- query has a WHERE clause that may bind path endpoints
--    'var_counter'      - counter for generating unique SPARQL variables
--    'extra_from_graphs'- additional FROM clauses
--    'suppress_default_from' - flag to suppress default FROM
--    'var_map'          - vector of vector(gql_name, sparql_var, kind)
--                         kind: 'node', 'edge', 'path', 'value', 'alias'
--    'in_optional_depth'- integer counter for nested OPTIONAL scoping
--    'in_set_op'        - flag: 1 when inside a UNION/EXCEPT/INTERSECT branch
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
    'edge_reif_vars', vector (),
    'reif_graph', _graph,
    'active_path_var', null,
    'needs_auto_group', 0,
    'has_where_filters', 0,
    'var_counter', 0,
    'extra_from_graphs', vector (),
    'suppress_default_from', 0,
    'force_camelcase', 0,
    'var_map', vector (),
    'in_optional_depth', 0,
    'in_set_op', 0,
    'error_acc', vector ()
  );
}
;

create procedure DB.DBA.GQL_CTX_GET (inout _ctx any, in _key varchar)
{
  declare i integer;
  for (i := 0; i + 1 < length (_ctx); i := i + 2)
    { if (aref (_ctx, i) = _key) return aref (_ctx, i + 1); }
  return null;
}
;

create procedure DB.DBA.GQL_CTX_SET (inout _ctx any, in _key varchar, in _val any)
{
  declare i integer;
  for (i := 0; i + 1 < length (_ctx); i := i + 2)
    { if (aref (_ctx, i) = _key) { aset (_ctx, i + 1, _val); return; } }
  _ctx := vector_concat (_ctx, vector (_key, _val));
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
      or fname = 'sample' or fname = 'group_concat' or fname = 'degree_centrality')
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
    return concat ('<', DB.DBA.GQL_NS (), prop_name, '>');
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
    return concat (DB.DBA.GQL_NS (), prop_name);
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

  if (_direction = 'in')
    branch := concat (_indent, nbr, ' ', pred, ' ', _node, ' .\n',
      _indent, 'BIND (CONCAT("in|", STR(', nbr, '), "|", STR(', pred, ')) AS ', _edge_id_var, ')\n');
  else
    branch := concat (_indent, _node, ' ', pred, ' ', nbr, ' .\n',
      _indent, 'BIND (CONCAT("out|", STR(', pred, '), "|", STR(', nbr, ')) AS ', _edge_id_var, ')\n');

  if (_rel_pred is null or _rel_pred = '')
    branch := replace (branch, 'BIND (',
      concat ('FILTER (isIRI(', nbr, ') && ', pred, ' NOT IN (rdf:type, rdf:subject, rdf:predicate, rdf:object))\n', _indent, 'BIND ('));

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
      branch := concat (branch,
        _indent, 'BIND (COALESCE(', raw_weight, ', 1) AS ', _weight_var, ')\n');
    }
  else
    branch := concat (branch, _indent, 'BIND (1 AS ', _weight_var, ')\n');

  DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx, branch);
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

  if (dir = 'out')
    DB.DBA.GQL_CTX_ADD_DEGREE_BRANCH (_ctx, node_var, 'out', rel_pred, weight_prop, edge_id_var, weight_var, '    ');
  else if (dir = 'in')
    DB.DBA.GQL_CTX_ADD_DEGREE_BRANCH (_ctx, node_var, 'in', rel_pred, weight_prop, edge_id_var, weight_var, '    ');
  else
    {
      DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx, '    {\n');
      DB.DBA.GQL_CTX_ADD_DEGREE_BRANCH (_ctx, node_var, 'out', rel_pred, weight_prop, edge_id_var, weight_var, '      ');
      DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx, '    } UNION {\n');
      DB.DBA.GQL_CTX_ADD_DEGREE_BRANCH (_ctx, node_var, 'in', rel_pred, weight_prop, edge_id_var, weight_var, '      ');
      DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx, '    }\n');
    }

  degree_body := DB.DBA.GQL_CTX_GET (_ctx, 'triples');
  DB.DBA.GQL_CTX_SET (_ctx, 'triples', saved_triples);

  if (graph_expr is not null and graph_expr <> '')
    degree_body := concat ('    GRAPH ', graph_expr, ' {\n', degree_body, '    }\n');

  DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx, concat ('  OPTIONAL {\n', degree_body, '  }\n'));
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
    concat ('IRI(CONCAT("', DB.DBA.GQL_DATA_NS (), 'path_", ENCODE_FOR_URI(STR(', path_id_var, '))))'));
  DB.DBA.GQL_CTX_ADD_BIND_ONCE (_ctx, step_var,
    concat ('IRI(CONCAT("', DB.DBA.GQL_DATA_NS (), 'pathstep_", ENCODE_FOR_URI(STR(', path_id_var, ')), "_", STR(', index_var, ')))'));
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
  path_expr := concat ('IRI(CONCAT("', DB.DBA.GQL_DATA_NS (), 'path_", ENCODE_FOR_URI(STR(', path_id_var, '))))');
  value_expr := concat ('CONCAT(STR(', _src, '), " -> ", STR(', _dst, '))');

  DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx,
    concat ('  {\n',
            '    ', _src, ' ', _pred, ' ', _dst, ' .\n',
            '    BIND (', path_id_expr, ' AS ', path_id_var, ')\n',
            '    BIND (0 AS ', index_var, ')\n',
            '    BIND (', path_expr, ' AS ', path_var, ')\n',
            '    BIND (IRI(CONCAT("', DB.DBA.GQL_DATA_NS (), 'pathstep_", ENCODE_FOR_URI(STR(', path_id_var, ')), "_", STR(', index_var, '))) AS ', step_var, ')\n',
            '    BIND (', _src, ' AS ', node_var, ')\n',
            '    BIND (CONCAT(STR(', index_var, '), ": ", STR(', node_var, ')) AS ', step_value_var, ')\n',
            '    BIND (', value_expr, ' AS ', value_var, ')\n',
            '  } UNION {\n',
            '    ', _src, ' ', _pred, ' ', _dst, ' .\n',
            '    BIND (', path_id_expr, ' AS ', path_id_var, ')\n',
            '    BIND (1 AS ', index_var, ')\n',
            '    BIND (', path_expr, ' AS ', path_var, ')\n',
            '    BIND (IRI(CONCAT("', DB.DBA.GQL_DATA_NS (), 'pathstep_", ENCODE_FOR_URI(STR(', path_id_var, ')), "_", STR(', index_var, '))) AS ', step_var, ')\n',
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

create procedure DB.DBA.GQL_CTX_MATERIALIZE_EDGE_VAR (inout _ctx any, in _edge_var varchar)
{
  declare bindings any;
  declare i integer;
  declare esv varchar;

  if (_edge_var is null or _edge_var = '')
    return 0;
  if (DB.DBA.GQL_CTX_EDGE_REIF_DONE (_ctx, _edge_var))
    return 1;

  bindings := DB.DBA.GQL_CTX_GET (_ctx, 'edge_bindings');
  esv := DB.DBA.GQL_EDGE_SPARQL_VAR (_edge_var);
  for (i := 0; i < length (bindings); i := i + 1)
    {
      declare binding any;
      binding := aref (bindings, i);
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
  declare base_uri, default_uri, graph_uri varchar;
  base_uri := DB.DBA.GQL_CTX_GET (_ctx, 'base_uri');
  if (base_uri is not null and base_uri <> '')
    return DB.DBA.GQL_NS_JOIN_LOCAL (base_uri, _local);
  default_uri := DB.DBA.GQL_CTX_DEFAULT_PREFIX_URI (_ctx);
  if (default_uri is not null and default_uri <> '')
    return DB.DBA.GQL_NS_JOIN_LOCAL (default_uri, _local);
  graph_uri := DB.DBA.GQL_CTX_GET (_ctx, 'active_graph');
  if (graph_uri is not null and graph_uri <> '' and graph_uri <> DB.DBA.GQL_DEFAULT_GRAPH ())
    return DB.DBA.GQL_NS_JOIN_LOCAL (graph_uri, _local);
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
        signal ('G3010', sprintf ('Base-relative name %s requires BASE, PREFIX :, or USE GRAPH', _name));
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
    return DB.DBA.GQL_LABEL_URI (_name);
  if (_kind = 'edge')
    {
      if (DB.DBA.GQL_CTX_FORCE_CAMELCASE (_ctx) = 1)
        return concat (DB.DBA.GQL_NS (), DB.DBA.GQL_TO_CAMEL_CASE (_name));
      return DB.DBA.GQL_EDGE_TYPE_URI (_name);
    }
  if (_kind = 'prop' and DB.DBA.GQL_CTX_FORCE_CAMELCASE (_ctx) = 1)
    return concat (DB.DBA.GQL_NS (), DB.DBA.GQL_TO_CAMEL_CASE (_name));
  return DB.DBA.GQL_PROP_URI (_name);
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

create procedure DB.DBA.GQL_GEN_NS_IRI (in _local varchar)
{
  return concat ('<', DB.DBA.GQL_NS (), _local, '>');
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

  out_s := '';
  any_default := 0;
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
-- SERVICE block: emit `SERVICE <endpoint> { triples ... }` into context
-- triples accumulator. The inner block reuses the outer context so any
-- variables it binds become visible to the surrounding query.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_GEN_SERVICE (in _service_ast any, inout _ctx any)
{
  declare endpoint_expr, svc_query, svc_clauses any;
  declare endpoint_str, body, triples, explicit_from varchar;
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
  DB.DBA.GQL_CTX_SET (svc_ctx, 'var_counter', DB.DBA.GQL_CTX_GET (_ctx, 'var_counter'));
  DB.DBA.GQL_CTX_SET (svc_ctx, 'reif_graph', DB.DBA.GQL_CTX_GET (_ctx, 'reif_graph'));

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
      else if (ctype = 'USE_ANY_GRAPH')
        DB.DBA.GQL_CTX_SET (svc_ctx, 'suppress_default_from', 1);
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
    DB.DBA.GQL_GEN_FOR_VALUES (aref (for_asts, i), svc_ctx);
  for (i := 0; i < length (where_asts); i := i + 1)
    {
      declare wexpr varchar;
      wexpr := DB.DBA.GQL_GEN_EXPR (aref (aref (where_asts, i), 1), svc_ctx);
      DB.DBA.GQL_CTX_ADD_FILTER (svc_ctx, wexpr);
    }

  body := DB.DBA.GQL_CTX_GET (svc_ctx, 'values');
  body := concat (body, DB.DBA.GQL_CTX_GET (svc_ctx, 'pre_values'));
  body := concat (body, DB.DBA.GQL_CTX_GET (svc_ctx, 'pre_binds'));
  body := concat (body, DB.DBA.GQL_CTX_GET (svc_ctx, 'triples'));
  body := concat (body, DB.DBA.GQL_CTX_GET (svc_ctx, 'binds'));
  body := concat (body, DB.DBA.GQL_CTX_GET (svc_ctx, 'filters'));
  body := concat (body, DB.DBA.GQL_CTX_GET (svc_ctx, 'optionals'));

  triples := DB.DBA.GQL_CTX_GET (_ctx, 'triples');
  if (has_return)
    {
      ret_vars := DB.DBA.GQL_GEN_RETURN (return_ast, svc_ctx, order_clause, limit_clause, skip_clause, is_distinct);
      explicit_from := DB.DBA.GQL_GEN_EXPLICIT_FROM_CLAUSES (svc_ctx);

      proj := '';
      for (ri := 0; ri < length (ret_vars); ri := ri + 1)
        {
          declare rv, ralias any;
          rv := aref (aref (ret_vars, ri), 0);
          ralias := aref (aref (ret_vars, ri), 1);
          if (proj <> '') proj := concat (proj, ' ');
          if (ralias is not null)
            proj := concat (proj, '(', rv, ' AS ?', ralias, ')');
          else
            proj := concat (proj, rv);
        }
      if (proj = '')
        proj := '*';

      if (is_silent)
        triples := concat (triples, '  SERVICE SILENT ', endpoint_str, ' {\n');
      else
        triples := concat (triples, '  SERVICE ', endpoint_str, ' {\n');
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
            DB.DBA.GQL_CTX_ADD_VAR (_ctx, aref (expr, 1));
        }
    }
  else
    {
      if (is_silent)
        triples := concat (triples, '  SERVICE SILENT ', endpoint_str, ' {\n', body, '  }\n');
      else
        triples := concat (triples, '  SERVICE ', endpoint_str, ' {\n', body, '  }\n');
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
  declare var_name, var_sparql, values_list varchar;
  declare expr, items any;
  declare i integer;
  declare ordinality_offset varchar;

  var_name := aref (_for_ast, 1);
  expr := aref (_for_ast, 2);
  ordinality_offset := null;
  if (length (_for_ast) > 3)
    ordinality_offset := aref (_for_ast, 3);

  if (ordinality_offset = 'ORDINALITY')
    signal ('G2003', 'FOR ... WITH ORDINALITY is not supported — ordinality requires runtime list expansion which has no SPARQL equivalent');

  if (not isarray (expr) or aref (expr, 0) <> 'LIST')
    signal ('G2002', 'FOR currently supports only list literals');

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

  -- WITH OFFSET: emit a companion VALUES block with 0-based indices
  if (ordinality_offset = 'OFFSET')
    {
      declare offset_var varchar;
      declare offset_vals varchar;
      offset_var := concat ('?gql_v_', var_name, '_offset');
      offset_vals := '';
      for (i := 0; i < length (items); i := i + 1)
        {
          if (offset_vals <> '')
            offset_vals := concat (offset_vals, ' ');
          offset_vals := concat (offset_vals, cast (i as varchar));
        }
      DB.DBA.GQL_CTX_ADD_VALUES (_ctx, offset_var, offset_vals);
      DB.DBA.GQL_CTX_ADD_VAR (_ctx, concat (var_name, '_offset'));
    }
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
      if (DB.DBA.GQL_CTX_MATERIALIZE_EDGE_VAR (_ctx, vname))
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
    return concat ('?', aref (_expr, 1));  -- SPARQL parameter

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
  if (etype = 'BINOP')
    {
      lhs := DB.DBA.GQL_GEN_EXPR (aref (_expr, 2), _ctx);
      rhs := DB.DBA.GQL_GEN_EXPR (aref (_expr, 3), _ctx);
      declare op varchar;
      op := aref (_expr, 1);
      if (op = '<>') op := '!=';
      else if (op = '=') op := '=';
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
      fname_orig := aref (_expr, 1);
      fname := lower (cast (fname_orig as varchar));
      fargs := '';
      if (etype = 'FUNC_DISTINCT')
        args_vec := aref (_expr, 2);
      else
        args_vec := aref (_expr, 3);
      if (lower (fname) = 'degree_centrality')
        return DB.DBA.GQL_GEN_DEGREE_CENTRALITY (args_vec, _ctx);
      if (lower (fname) = 'eigenvector_centrality')
        return DB.DBA.GQL_GEN_GRAPH_CENTRALITY_EXPR (args_vec, _ctx, 'eigenvector');
      if (lower (fname) = 'closeness_centrality')
        return DB.DBA.GQL_GEN_GRAPH_CENTRALITY_EXPR (args_vec, _ctx, 'closeness');
      if (lower (fname) = 'betweenness_centrality')
        return DB.DBA.GQL_GEN_GRAPH_CENTRALITY_EXPR (args_vec, _ctx, 'betweenness');
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
      -- Aggregate functions: map GQL names to SPARQL built-ins
      if (fname = 'count') return concat ('COUNT(', fargs, ')');
      if (fname = 'sum') return concat ('SUM(', fargs, ')');
      if (fname = 'avg') return concat ('AVG(', fargs, ')');
      if (fname = 'min') return concat ('MIN(', fargs, ')');
      if (fname = 'max') return concat ('MAX(', fargs, ')');
      if (fname = 'sample') return concat ('SAMPLE(', fargs, ')');
      if (fname = 'group_concat')
        return concat ('GROUP_CONCAT(', fargs, ')');
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
      if (fname = 'trim') return concat ('TRIM(', fargs, ')');
      -- Numeric functions (same name in SPARQL, mapped explicitly for clarity)
      if (fname = 'abs') return concat ('ABS(', fargs, ')');
      if (fname = 'ceil') return concat ('CEIL(', fargs, ')');
      if (fname = 'floor') return concat ('FLOOR(', fargs, ')');
      if (fname = 'round') return concat ('ROUND(', fargs, ')');
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
      if (fname = 'isIRI') return concat ('isIRI(', fargs, ')');
      if (fname = 'isLiteral') return concat ('isLiteral(', fargs, ')');
      if (fname = 'isBlank') return concat ('isBlank(', fargs, ')');
      if (fname = 'isNumeric') return concat ('isNumeric(', fargs, ')');
      if (fname = 'sameTerm') return concat ('sameTerm(', fargs, ')');
      if (fname = 'langMatches') return concat ('langMatches(', fargs, ')');
      if (fname = 'regex') return concat ('REGEX(', fargs, ')');
      if (fname = 'contains') return concat ('CONTAINS(', fargs, ')');
      if (fname = 'strstarts') return concat ('STRSTARTS(', fargs, ')');
      if (fname = 'strends') return concat ('STRENDS(', fargs, ')');
      if (fname = 'encode_for_uri') return concat ('ENCODE_FOR_URI(', fargs, ')');
      -- Conditional
      if (fname = 'coalesce') return concat ('COALESCE(', fargs, ')');
      if (fname = 'if') return concat ('IF(', fargs, ')');
      -- Existence
      if (fname = 'bound') return concat ('BOUND(', fargs, ')');
      if (fname = 'exists') return concat ('EXISTS { ', fargs, ' }');
      -- Default pass-through for sql:, bif:, and unknown functions
      return concat (fname_orig, '(', fargs, ')');
    }

  -- IS NULL / IS NOT NULL
  if (etype = 'ISNULL')
    {
      lhs := DB.DBA.GQL_GEN_EXPR (aref (_expr, 1), _ctx);
      if (aref (_expr, 2) = 1)
        return concat ('(!BOUND(', lhs, '))');
      return concat ('(BOUND(', lhs, '))');
    }

  -- IN expression
  if (etype = 'INEXPR')
    {
      lhs := DB.DBA.GQL_GEN_EXPR (aref (_expr, 1), _ctx);
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

      sub_ctx := DB.DBA.GQL_CTX_NEW (DB.DBA.GQL_CTX_GET (_ctx, 'graph'));
      DB.DBA.GQL_CTX_SET (sub_ctx, 'prefixes', DB.DBA.GQL_CTX_GET (_ctx, 'prefixes'));
      DB.DBA.GQL_CTX_SET (sub_ctx, 'base_uri', DB.DBA.GQL_CTX_GET (_ctx, 'base_uri'));
      DB.DBA.GQL_CTX_SET (sub_ctx, 'var_counter', DB.DBA.GQL_CTX_GET (_ctx, 'var_counter'));
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
        xsd_type := 'xsd:dateTimeStamp';
      else if (tlit_type = 'DATETIME')
        xsd_type := 'xsd:dateTime';
      else
        xsd_type := concat ('xsd:', lower (tlit_type));
      return concat ('"', tlit_val, '"^^', xsd_type);
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
      or etype = 'FLOAT' or etype = 'TYPEDLIT' or etype = 'PARAM')
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
      or etype = 'FLOAT' or etype = 'TYPEDLIT' or etype = 'PARAM')
    return 1;
  return 0;
}
;

create procedure DB.DBA.GQL_CTX_ADD_PRE_ENDPOINT (inout _ctx any, in _var varchar, in _expr any)
{
  declare sparql_expr varchar;
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
          and DB.DBA.GQL_EXPR_IS_PREBIND_VALUE (rhs))
        DB.DBA.GQL_CTX_ADD_PRE_ENDPOINT_BIND (_ctx,
          DB.DBA.GQL_NODE_SPARQL_VAR (aref (lhs, 1)),
          rhs);
      else if (isarray (rhs) and aref (rhs, 0) = 'VAR'
          and DB.DBA.GQL_EXPR_IS_PREBIND_VALUE (lhs))
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
          and DB.DBA.GQL_EXPR_IS_PREBIND_VALUE (rhs))
        DB.DBA.GQL_CTX_ADD_PRE_ENDPOINT (_ctx,
          DB.DBA.GQL_NODE_SPARQL_VAR (aref (lhs, 1)),
          rhs);
      else if (isarray (rhs) and aref (rhs, 0) = 'VAR'
          and DB.DBA.GQL_EXPR_IS_PREBIND_VALUE (lhs))
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
          declare any_pred, any_obj varchar;
          nvar := aref (elem, 1);
          nlabels := aref (elem, 2);
          nprops := aref (elem, 3);
          nsv := DB.DBA.GQL_NODE_SPARQL_VAR (nvar);
          if (nsv is null)
            nsv := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'anon_node_');
          DB.DBA.GQL_CTX_ADD_VAR (_ctx, nvar);

          -- Emit labels as rdf:type triples
          for (li := 0; li < length (nlabels); li := li + 1)
            {
              declare label_item any;
              label_item := aref (nlabels, li);
              if (isarray (label_item) and aref (label_item, 0) = 'LABEL_OR')
                {
                  declare label_choices any;
                  declare label_var, values_s varchar;
                  declare lci integer;
                  label_choices := aref (label_item, 1);
                  label_var := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'label_');
                  values_s := concat ('  VALUES ', label_var, ' {');
                  for (lci := 0; lci < length (label_choices); lci := lci + 1)
                    values_s := concat (values_s, ' ',
                      DB.DBA.GQL_GEN_LABEL_IRI_CTX (aref (label_choices, lci), _ctx));
                  values_s := concat (values_s, ' }\n');
                  DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, nsv, 'rdf:type', label_var);
                  DB.DBA.GQL_CTX_ADD_RAW_TRIPLES (_ctx, values_s);
                }
              else
                DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, nsv,
                  'rdf:type',
                  DB.DBA.GQL_GEN_LABEL_IRI_CTX (label_item, _ctx));
            }

          -- Emit properties
          for (pi := 0; pi < length (nprops); pi := pi + 1)
            {
              declare pkey, pval any;
              declare pval_str varchar;
              pkey := aref (aref (nprops, pi), 0);
              pval := aref (aref (nprops, pi), 1);
              pval_str := DB.DBA.GQL_GEN_EXPR (pval, _ctx);
              DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, nsv, DB.DBA.GQL_GEN_PROP_IRI_CTX (pkey, _ctx), pval_str);
            }

          if (length (nlabels) = 0 and length (nprops) = 0 and length (elems) = 1)
            {
              any_pred := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'node_p_');
              any_obj := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'node_o_');
              DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, nsv, any_pred, any_obj);
            }

          prev_var := nsv;
        }

      -- EDGE element
      else if (etype = 'EDGE')
        {
          declare evar, etypes, edir, equant, eprops, ecost any;
          declare eidx, epi integer;
          declare esv, esrc, edst varchar;
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
              if (isarray (next_elem))
                {
                  next_etype := aref (next_elem, 0);
                  if (next_etype = 'NODE')
                    next_var := DB.DBA.GQL_NODE_SPARQL_VAR (aref (next_elem, 1));
                }
              if (next_var is not null)
                edst := next_var;
              else
                edst := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'dst_');
            }
          else
            edst := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'dst_');

          -- Handle direction
          if (edir = 'LEFT')
            { declare tmp varchar; tmp := esrc; esrc := edst; edst := tmp; }
          else if (edir = 'BOTH' or edir = 'UNDIRECTED')
            {
              -- Undirected quantified edges require bipartite property path
              -- syntax (<iri>|^<iri>)* which is not yet generated.
              if (equant is not null)
                signal ('G3006', 'Undirected property paths with quantifiers (*, +, ?) are not yet supported — use a directed edge or expand to two directed patterns');
            }
          -- RIGHT is default

          -- Compute property path suffix from quantifier
          declare pp_suffix varchar;
          pp_suffix := DB.DBA.GQL_PROPERTY_PATH_SUFFIX (equant);

	          -- Emit edge type triples (with property path suffix if quantified)
	          for (eidx := 0; eidx < length (etypes); eidx := eidx + 1)
		            {
		              declare edge_iri varchar;
		              declare transitive_options varchar;
		              declare active_path_var varchar;
		              declare cost_prop varchar;
		              declare is_shortest_path integer;
		              edge_iri := DB.DBA.GQL_GEN_EDGE_TYPE_IRI_CTX (aref (etypes, eidx), _ctx);
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
	                DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, esrc, concat (edge_iri, pp_suffix), edst);
		              else
		                {
	                  DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, esrc, edge_iri, edst);
	                  DB.DBA.GQL_CTX_ADD_EDGE_BINDING (_ctx, evar, esrc, edge_iri, edst);
	                }
            }

          -- If edge has properties, emit reification
          if (length (eprops) > 0 and evar is not null)
            {
              DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, esv,
                concat ('<', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'type>'),
                concat ('<', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'Statement>'));
              DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, esv,
                concat ('<', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'subject>'),
                esrc);
              -- Emit predicate for each type
              for (eidx := 0; eidx < length (etypes); eidx := eidx + 1)
                {
                  DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, esv,
                    concat ('<', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'predicate>'),
                    DB.DBA.GQL_GEN_EDGE_TYPE_IRI_CTX (aref (etypes, eidx), _ctx));
                }
              DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, esv,
                concat ('<', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'object>'),
                edst);
              -- Edge properties go on the reification node
              for (epi := 0; epi < length (eprops); epi := epi + 1)
                {
                  declare epkey any;
                  epkey := aref (aref (eprops, epi), 0);
                  declare epval_str varchar;
                  epval_str := DB.DBA.GQL_GEN_EXPR (aref (aref (eprops, epi), 1), _ctx);
                  DB.DBA.GQL_CTX_ADD_TRIPLE (_ctx, esv, DB.DBA.GQL_GEN_PROP_IRI_CTX (epkey, _ctx), epval_str);
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
                  pm := aref (pee, 6);
                  if (pm = 'ACYCLIC')
                    path_mode_flags := concat (path_mode_flags, ', t_no_cycles');
                  else if (pm = 'SIMPLE')
                    path_mode_flags := concat (path_mode_flags, ', t_distinct');
                }
            pme_next:;
            }
        pm_next:;
        }
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
	      topt := 'T_DISTINCT, T_SHORTEST_ONLY';
      -- ANY SHORTEST → limit to 1 result
      if (sc_kind = 'ANY')
        {
          topt := concat (topt, ', T_STEP_LIMIT 1');
        }
      -- SHORTEST k (counted) → limit to k results
      else if (sc_count > 1)
        {
          topt := concat (topt, ', T_MAX ', cast (sc_count as varchar));
        }
      -- SHORTEST k GROUPS → group by path length
      if (sc_groups = 1)
        signal ('G3005', 'SHORTEST k GROUPS: path-length grouping is not yet supported — requires nested SELECT with GROUP BY path length');
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
      for (i := 0; i < length (patterns); i := i + 1)
        DB.DBA.GQL_GEN_MATCH_PATTERN (aref (patterns, i), _ctx);
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
-- SPARQL string helpers for set operations
----------------------------------------------------------------------

create procedure DB.DBA.GQL_EXTRACT_WHERE_BODY (in _sparql varchar)
{
  declare where_pos, where_end integer;

  where_pos := strstr (_sparql, 'WHERE {');
  if (where_pos is null)
    return '';

  -- Find the matching closing brace for WHERE {
  where_pos := where_pos + 7;  -- skip 'WHERE {'
  where_end := DB.DBA.GQL_FIND_MATCHING_BRACE (_sparql, where_pos);
  if (where_end is null)
    return subseq (_sparql, where_pos);

  return subseq (_sparql, where_pos, where_end);
}
;

create procedure DB.DBA.GQL_FIND_MATCHING_BRACE (in _s varchar, in _start integer)
{
  declare depth, i, slen integer;
  depth := 0;
  slen := length (_s);
  for (i := _start; i < slen; i := i + 1)
    {
      if (aref (_s, i) = 123)  -- '{'
        depth := depth + 1;
      else if (aref (_s, i) = 125)  -- '}'
        {
          depth := depth - 1;
          if (depth = 0)
            return i;
        }
    }
  return null;
}
;

create procedure DB.DBA.GQL_EXTRACT_SELECT_HEADER (in _sparql varchar)
{
  declare where_pos integer;
  declare header varchar;

  where_pos := strstr (_sparql, 'WHERE {');
  if (where_pos is null)
    return _sparql;  -- no WHERE clause

  return subseq (_sparql, 0, where_pos);
}
;

create procedure DB.DBA.GQL_EXTRACT_POST_WHERE (in _sparql varchar)
{
  declare where_pos, where_end, tail_start integer;

  where_pos := strstr (_sparql, 'WHERE {');
  if (where_pos is null)
    return '';

  where_pos := where_pos + 7;
  where_end := DB.DBA.GQL_FIND_MATCHING_BRACE (_sparql, where_pos);
  if (where_end is null)
    return '';

  return subseq (_sparql, where_end + 1);  -- after the closing }
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

create procedure DB.DBA.GQL_TO_SPARQL_IMPL (in _ast any, in _graph varchar)
{
  declare node_type varchar;
  declare clauses any;
  declare i, n integer;
  declare ctx any;
  declare has_return, has_insert, has_construct, has_describe, has_delete, has_set, has_remove integer;
  declare return_ast, insert_asts, construct_asts, describe_ast, delete_ast, set_ast, remove_ast any;
  declare match_asts, where_asts any;
  declare for_asts, let_asts, service_asts any;
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

      if (setop_name = 'UNION' or setop_name = 'UNION_ALL')
        {
          -- Strip 'SPARQL ' prefix from the right side so we don't double-emit.
          -- Keep the left side's prefix intact as it carries PREFIX/BASE/DEFINE.
          declare prefix_len integer;
          declare r_stripped varchar;
          prefix_len := length ('SPARQL ');
          r_stripped := right_sparql;
          if (length (r_stripped) >= prefix_len
              and subseq (r_stripped, 0, prefix_len) = 'SPARQL ')
            r_stripped := subseq (r_stripped, prefix_len);
          return concat (left_sparql, ' UNION ', r_stripped);
        }

      if (setop_name = 'EXCEPT')
        {
          -- EXCEPT → SELECT <left_proj> WHERE { { <left_body> } FILTER NOT EXISTS { <right_body> } }
          declare lhdr, lbody, rbody, ltail varchar;
          lhdr := DB.DBA.GQL_EXTRACT_SELECT_HEADER (left_sparql);
          lbody := DB.DBA.GQL_EXTRACT_WHERE_BODY (left_sparql);
          rbody := DB.DBA.GQL_EXTRACT_WHERE_BODY (right_sparql);
          ltail := DB.DBA.GQL_EXTRACT_POST_WHERE (left_sparql);
          return concat (lhdr, 'WHERE { { ', lbody, ' } FILTER NOT EXISTS { ', rbody, ' } } ', ltail);
        }

      if (setop_name = 'INTERSECT')
        {
          -- INTERSECT → SELECT <left_proj> WHERE { { <left_body> } FILTER EXISTS { <right_body> } }
          declare ihdr, ibody, irbody, itail varchar;
          ihdr := DB.DBA.GQL_EXTRACT_SELECT_HEADER (left_sparql);
          ibody := DB.DBA.GQL_EXTRACT_WHERE_BODY (left_sparql);
          irbody := DB.DBA.GQL_EXTRACT_WHERE_BODY (right_sparql);
          itail := DB.DBA.GQL_EXTRACT_POST_WHERE (left_sparql);
          return concat (ihdr, 'WHERE { { ', ibody, ' } FILTER EXISTS { ', irbody, ' } } ', itail);
        }

      signal ('G2004', sprintf ('Unsupported set operation: %s', setop_name));
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
  if (_graph is null) _graph := DB.DBA.GQL_DEFAULT_GRAPH ();
  ctx := DB.DBA.GQL_CTX_NEW (_graph);
  n := length (clauses);

  has_return := 0;
  has_insert := 0;
  has_construct := 0;
  has_describe := 0;
  has_delete := 0;
  has_set := 0;
  has_remove := 0;
  return_ast := null;
  insert_asts := vector ();
  construct_asts := vector ();
  describe_ast := null;
  delete_ast := null;
  set_ast := null;
  remove_ast := null;
  match_asts := vector ();
  where_asts := vector ();
  service_asts := vector ();
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
          if (length (clause) > 4 and aref (clause, 4) = 1)
            DB.DBA.GQL_CTX_SET (ctx, 'suppress_default_from', 1);
        }
      else if (ctype = 'WHERE')
        {
          where_asts := vector_concat (where_asts, vector (clause));
          DB.DBA.GQL_CTX_SET (ctx, 'has_where_filters', 1);
        }
      else if (ctype = 'RETURN')
        { has_return := 1; return_ast := clause; }
      else if (ctype = 'INSERT')
        { has_insert := 1; insert_asts := vector_concat (insert_asts, vector (clause)); }
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
      else if (ctype = 'USE')
        {
          declare use_graph_val varchar;
          use_graph_val := DB.DBA.GQL_GRAPH_REF_VALUE_CTX (aref (clause, 1), ctx);
          use_ast := clause;
          DB.DBA.GQL_CTX_SET (ctx, 'graph', use_graph_val);
          DB.DBA.GQL_CTX_SET (ctx, 'active_graph', use_graph_val);
        }
      else if (ctype = 'USE_ANY_GRAPH')
        { use_ast := clause; DB.DBA.GQL_CTX_SET (ctx, 'suppress_default_from', 1); }
      else if (ctype = 'FROM_CLAUSE')
        {
          declare extra_from any;
          extra_from := DB.DBA.GQL_CTX_GET (ctx, 'extra_from_graphs');
          extra_from := vector_concat (extra_from,
            vector (vector (aref (clause, 1), DB.DBA.GQL_GRAPH_REF_VALUE_CTX (aref (clause, 2), ctx))));
          DB.DBA.GQL_CTX_SET (ctx, 'extra_from_graphs', extra_from);
        }
      else if (ctype = 'SERVICE')
        service_asts := vector_concat (service_asts, vector (clause));
      else if (ctype = 'PREFIX')
        { DB.DBA.GQL_CTX_ADD_PREFIX (ctx, aref (clause, 1), aref (clause, 2)); }
      else if (ctype = 'BASE')
        { DB.DBA.GQL_CTX_SET (ctx, 'base_uri', aref (clause, 1)); }
      else if (ctype = 'DEFINE')
        { DB.DBA.GQL_CTX_ADD_DEFINE (ctx, aref (clause, 1), aref (clause, 2)); }
      else if (ctype = 'FORCE_CAMELCASE')
        { DB.DBA.GQL_CTX_SET (ctx, 'force_camelcase', 1); }
      else if (ctype = 'UNION')
        { ; }  -- handled at a higher level
      else if (ctype = 'FOR')
        for_asts := vector_concat (for_asts, vector (clause));
      else if (ctype = 'LET')
        let_asts := vector_concat (let_asts, vector (clause));
      else if (ctype = 'GROUP')
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
               or ctype = 'CREATE_SCHEMA' or ctype = 'DROP_SCHEMA'
               or ctype = 'CREATE_GRAPH_TYPE' or ctype = 'DROP_GRAPH_TYPE'
               or ctype = 'LOAD' or ctype = 'CLEAR')
        catalog_asts := vector_concat (catalog_asts, vector (clause));

    class_next:;
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

  -- Emit MATCH clauses → triple patterns
  for (i := 0; i < length (match_asts); i := i + 1)
    {
      declare m_ast any;
      m_ast := aref (match_asts, i);
      if (length (m_ast) > 4 and aref (m_ast, 4) = 1)
        DB.DBA.GQL_CTX_SET (ctx, 'suppress_default_from', 1);
      DB.DBA.GQL_GEN_MATCH (m_ast, ctx);
    }

  -- Emit SERVICE clauses → SERVICE blocks (after MATCH so local triples
  -- precede the federated block in the WHERE pattern).
  for (i := 0; i < length (service_asts); i := i + 1)
    DB.DBA.GQL_GEN_SERVICE (aref (service_asts, i), ctx);

  -- Emit FOR list bindings as SPARQL VALUES.
  for (i := 0; i < length (for_asts); i := i + 1)
    DB.DBA.GQL_GEN_FOR_VALUES (aref (for_asts, i), ctx);

  -- Emit LET clauses → BIND (after MATCH/FOR so referenced vars are bound,
  -- before WHERE/FILTER so filter can reference LET variables).
  for (i := 0; i < length (let_asts); i := i + 1)
    {
      declare let_ast, let_var, let_expr any;
      declare let_sparql_var, let_sparql_expr varchar;
      let_ast := aref (let_asts, i);
      let_var := aref (let_ast, 1);
      let_expr := aref (let_ast, 2);
      let_sparql_var := concat ('?gql_v_', let_var);
      let_sparql_expr := DB.DBA.GQL_GEN_EXPR (let_expr, ctx);
      DB.DBA.GQL_CTX_ADD_BIND (ctx, let_sparql_var, let_sparql_expr);
      DB.DBA.GQL_CTX_ADD_VAR (ctx, let_var);
      DB.DBA.GQL_CTX_ADD_ALIAS (ctx, let_var, let_sparql_var);
    }

  -- Emit WHERE clauses → FILTER
  for (i := 0; i < length (where_asts); i := i + 1)
    {
      declare wexpr varchar;
      wexpr := DB.DBA.GQL_GEN_EXPR (aref (aref (where_asts, i), 1), ctx);
      DB.DBA.GQL_CTX_ADD_FILTER (ctx, wexpr);
    }

  -- Handle INSERT
  if (has_insert and length (match_asts) > 0)
    {
      -- INSERT with MATCH: INSERT { ... } WHERE { ... }
      -- If RETURN is also present, signal error — focused linear
      -- data-modifying statement with RETURN not yet supported.
      if (has_return)
        signal ('G2004', 'INSERT with MATCH and RETURN is not yet supported — use separate statements');
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
        DB.DBA.GQL_EMIT_PREFIX_BLOCK (ctx),
        DB.DBA.GQL_GEN_DEFINE_CLAUSE (ctx));
      sparql_text := concat (sparql_text, 'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>\n');
      sparql_text := concat (sparql_text, 'PREFIX gql: <', DB.DBA.GQL_NS (), '>\n');

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
          declare group_items any;
          declare group_vars any;
          declare gi integer;
          group_items := aref (group_ast, 1);
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

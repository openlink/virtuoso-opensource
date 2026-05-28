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
--  openCypher: OpenCypher for Virtuoso - Cypher AST to SPARQL Translator
--
--  Translates parsed AST into executable SPARQL queries.
--  Uses a translation context (ctx) to track variable bindings and state.
--
--  Context structure: vector of key-value pairs stored as a flat vector
--    'graph'       - target graph URI
--    'vars'        - vector of known variable names
--    'triples'     - accumulated triple patterns (string)
--    'filters'     - accumulated FILTER clauses (string)
--    'optionals'   - accumulated OPTIONAL blocks (string)
--    'prop_vars'   - vector of vector(var_name, prop_name, sparql_var) for property access tracking
--    'binds'       - accumulated BIND clauses (string)
--    'prefixes'    - vector of vector(prefix, uri)
--    'defines'     - vector of vector(key, value_expr)
--    'rel_vars'    - vector of relationship variable names bound to reification statement nodes
--    'reif_graph'  - graph URI used for RDF reification triples
--    'path_vars'   - vector of vector(path_name, hop_count, node_terms, rel_terms, has_variable_length)
--    'strict_prefixed_terms' - reject unresolved prefixed RDF terms instead of falling back to openCypher IRIs
--    'force_camelcase' - compatibility option for legacy relationship type normalization
--    'suppress_path_node_existence' - do not add generic node-existence triples for relationship path endpoints
--    'suppress_default_from' - do not synthesize local default FROM clauses for remote-only SERVICE queries
--    'in_path_pattern' - current pattern has at least one relationship edge
--    'expr_bindings' - vector of vector(var_name, expr_ast) for WITH-bound literal maps/lists/scalars
--

-- Create a new translation context
create procedure DB.DBA.CYP_CTX_NEW (in _graph varchar)
{

  return vector (
    'graph', _graph,
    'vars', vector (),
    'triples', '',
    'filters', '',
    'optionals', '',
    'prop_vars', vector (),
    'binds', '',
    'prefixes', vector (),
    'defines', vector (),
    'rel_vars', vector (),
    'path_vars', vector (),
    'reif_graph', _graph,
    'extra_from_graphs', vector (),
    'var_counter', 0,
    'strict_prefixed_terms', 0,
    'force_camelcase', 0,
    'suppress_path_node_existence', 0,
    'suppress_default_from', 0,
    'in_path_pattern', 0,
    'expr_bindings', vector ()
  );
}
;

create procedure DB.DBA.CYP_REIF_GRAPH (inout _ctx any)
{
  declare reif_graph varchar;
  reif_graph := DB.DBA.CYP_CTX_GET (_ctx, 'reif_graph');
  if (reif_graph is null)
    reif_graph := DB.DBA.CYP_CTX_GET (_ctx, 'graph');
  if (reif_graph is null)
    reif_graph := DB.DBA.OPENCYPHER_DEFAULT_GRAPH ();
  return reif_graph;
}
;

create procedure DB.DBA.CYP_CTX_ADD_DEFINE (inout _ctx any, in _key varchar, in _value any)
{
  declare defines any;

  defines := DB.DBA.CYP_CTX_GET (_ctx, 'defines');
  defines := vector_concat (defines, vector (vector (_key, _value)));
  DB.DBA.CYP_CTX_SET (_ctx, 'defines', defines);
}
;

-- Register a PREFIX declaration in the translation context
create procedure DB.DBA.CYP_CTX_ADD_PREFIX (inout _ctx any, in _prefix varchar, in _uri varchar)
{
  declare prefixes any;

  prefixes := DB.DBA.CYP_CTX_GET (_ctx, 'prefixes');
  prefixes := vector_concat (prefixes, vector (vector (_prefix, _uri)));
  DB.DBA.CYP_CTX_SET (_ctx, 'prefixes', prefixes);
}
;

create procedure DB.DBA.CYP_REGISTERED_NS_URI (in _prefix varchar)
{
  declare ns_uri varchar;

  if (_prefix is null)
    return null;

  ns_uri := null;
  select max (NS_URL) into ns_uri
    from DB.DBA.SYS_XML_PERSISTENT_NS_DECL
   where NS_PREFIX = _prefix;
  return ns_uri;
}
;

-- Expand a prefixed name using PREFIX declarations, else return null
create procedure DB.DBA.CYP_EXPAND_PREFIXED_NAME (inout _ctx any, in _name varchar)
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
  if (DB.DBA.CYP_IS_ABSOLUTE_IRI_NAME (_name))
    return null;

  prefix_name := subseq (_name, 0, colon_pos);
  local_name := subseq (_name, colon_pos + 1);
  prefixes := DB.DBA.CYP_CTX_GET (_ctx, 'prefixes');
  for (i := 0; i < length (prefixes); i := i + 1)
    {
      if (aref (aref (prefixes, i), 0) = prefix_name)
        return concat (aref (aref (prefixes, i), 1), local_name);
    }
  ns_uri := DB.DBA.CYP_REGISTERED_NS_URI (prefix_name);
  if (isstring (ns_uri) and length (ns_uri) > 0)
    return concat (ns_uri, local_name);
  return null;
}
;

create procedure DB.DBA.CYP_IS_ABSOLUTE_IRI_NAME (in _name varchar)
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

create procedure DB.DBA.CYP_IS_PREFIXED_NAME (in _name varchar)
{
  declare colon_pos integer;

  if (_name is null)
    return 0;
  if (DB.DBA.CYP_IS_ABSOLUTE_IRI_NAME (_name))
    return 0;
  colon_pos := strchr (_name, ':');
  if (colon_pos is null)
    return 0;
  return 1;
}
;

create procedure DB.DBA.CYP_LABEL_URI (inout _ctx any, in _name varchar)
{
  declare expanded any;
  declare base_uri varchar;
  declare base_tag varchar;
  base_tag := concat (chr (1), 'BASE', chr (1));
  if (_name is not null and length (_name) > length (base_tag)
      and subseq (_name, 0, length (base_tag)) = base_tag)
    {
      base_uri := DB.DBA.CYP_CTX_GET (_ctx, 'base_uri');
      if (base_uri is null or length (base_uri) = 0)
        signal ('CY010', concat ('::', subseq (_name, length (base_tag)),
                                  ' used but no BASE declared'));
      return concat (base_uri, subseq (_name, length (base_tag)));
    }
  if (DB.DBA.CYP_IS_ABSOLUTE_IRI_NAME (_name))
    return _name;
  expanded := DB.DBA.CYP_EXPAND_PREFIXED_NAME (_ctx, _name);
  if (isstring (expanded))
    return expanded;
  if (DB.DBA.CYP_CTX_GET (_ctx, 'strict_prefixed_terms') and DB.DBA.CYP_IS_PREFIXED_NAME (_name))
    signal ('CY010', concat ('Undefined namespace prefix in label: ', _name));
  return DB.DBA.OPENCYPHER_LABEL_URI (_name);
}
;

create procedure DB.DBA.CYP_PROP_URI (inout _ctx any, in _name varchar)
{
  declare expanded any;
  if (DB.DBA.CYP_IS_ABSOLUTE_IRI_NAME (_name))
    return _name;
  expanded := DB.DBA.CYP_EXPAND_PREFIXED_NAME (_ctx, _name);
  if (isstring (expanded))
    return expanded;
  if (DB.DBA.CYP_CTX_GET (_ctx, 'strict_prefixed_terms') and DB.DBA.CYP_IS_PREFIXED_NAME (_name))
    signal ('CY010', concat ('Undefined namespace prefix in property: ', _name));
  return DB.DBA.OPENCYPHER_PROP_URI (_name);
}
;

create procedure DB.DBA.CYP_SAFE_VAR_SUFFIX (in _name varchar)
{
  declare out_s varchar;

  out_s := _name;
  out_s := replace (out_s, ':', '_');
  out_s := replace (out_s, '/', '_');
  out_s := replace (out_s, '#', '_');
  out_s := replace (out_s, '.', '_');
  out_s := replace (out_s, '-', '_');
  out_s := replace (out_s, '?', '_');
  out_s := replace (out_s, '&', '_');
  out_s := replace (out_s, '=', '_');
  out_s := replace (out_s, '%', '_');
  return out_s;
}
;

create procedure DB.DBA.CYP_REL_TYPE_URI (inout _ctx any, in _type varchar)
{
  declare expanded any;
  declare base_uri varchar;
  declare base_tag varchar;
  base_tag := concat (chr (1), 'BASE', chr (1));
  if (_type is not null and length (_type) > length (base_tag)
      and subseq (_type, 0, length (base_tag)) = base_tag)
    {
      base_uri := DB.DBA.CYP_CTX_GET (_ctx, 'base_uri');
      if (base_uri is null or length (base_uri) = 0)
        signal ('CY010', concat ('::', subseq (_type, length (base_tag)),
                                  ' used but no BASE declared'));
      return concat (base_uri, subseq (_type, length (base_tag)));
    }
  if (DB.DBA.CYP_IS_ABSOLUTE_IRI_NAME (_type))
    return _type;
  expanded := DB.DBA.CYP_EXPAND_PREFIXED_NAME (_ctx, _type);
  if (isstring (expanded))
    return expanded;
  if (DB.DBA.CYP_CTX_GET (_ctx, 'strict_prefixed_terms') and DB.DBA.CYP_IS_PREFIXED_NAME (_type))
    signal ('CY010', concat ('Undefined namespace prefix in relationship type: ', _type));
  if (DB.DBA.CYP_CTX_GET (_ctx, 'force_camelcase'))
    return DB.DBA.OPENCYPHER_REL_TYPE_URI (_type);
  return concat (DB.DBA.OPENCYPHER_NS (), _type);
}
;

create procedure DB.DBA.CYP_GEN_GRAPH_TERM (in _expr any, inout _ctx any)
{
  declare uri any;

  if (isarray (_expr) and aref (_expr, 0) = 'IRI')
    {
      uri := DB.DBA.CYP_EXPAND_PREFIXED_NAME (_ctx, aref (_expr, 1));
      if (not isstring (uri))
        uri := aref (_expr, 1);
      return DB.DBA.OPENCYPHER_FMT_URI (uri);
    }
  if (isarray (_expr) and aref (_expr, 0) = 'LIT' and isstring (aref (_expr, 1)))
    return DB.DBA.OPENCYPHER_FMT_URI (aref (_expr, 1));
  return DB.DBA.CYP_GEN_EXPR (_expr, _ctx, 0);
}
;

create procedure DB.DBA.CYP_ADD_RAW_TRIPLES (inout _ctx any, in _body varchar)
{
  declare cur varchar;
  cur := DB.DBA.CYP_CTX_GET (_ctx, 'triples');
  cur := concat (cur, _body);
  DB.DBA.CYP_CTX_SET (_ctx, 'triples', cur);
}
;

create procedure DB.DBA.CYP_EXPR_LITERAL_STRING (in _expr any)
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

create procedure DB.DBA.CYP_CENTRALITY_ADD_NODE (inout _dict any, inout _nodes any, in _uri varchar)
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

create procedure DB.DBA.CYP_CENTRALITY_GRAPH
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
  target_idx := DB.DBA.CYP_CENTRALITY_ADD_NODE (ndict, nodes, _node);

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
      si := DB.DBA.CYP_CENTRALITY_ADD_NODE (ndict, nodes, s);
      oi := DB.DBA.CYP_CENTRALITY_ADD_NODE (ndict, nodes, o);
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

create procedure DB.DBA.CYP_CENTRALITY_SHORTEST (in _source integer, in _nodes any, in _edges any)
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

  return vector (dist, sigma, delta);
}
;

create procedure DB.DBA.CYP_GRAPH_CENTRALITY
  (in _node varchar, in _graph varchar, in _rel varchar := null, in _direction varchar := 'in',
   in _weight varchar := null, in _metric varchar := 'closeness')
{
  declare g, nodes, edges, sp, dist any;
  declare n, target, i, ei, iter integer;
  declare metric varchar;
  declare inf, sumd, reachable, score, norm double precision;

  g := DB.DBA.CYP_CENTRALITY_GRAPH (_node, _graph, _rel, _direction, _weight);
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
      sp := DB.DBA.CYP_CENTRALITY_SHORTEST (target, nodes, edges);
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
      for (i := 0; i < n; i := i + 1)
        {
          declare s integer;
          s := i;
          if (s = target)
            goto between_next_source;
          sp := DB.DBA.CYP_CENTRALITY_SHORTEST (s, nodes, edges);
          dist := aref (sp, 0);
          for (declare t integer, t := 0; t < n; t := t + 1)
            {
              if (t = s or t = target or aref (dist, t) >= inf / 2.0)
                goto between_next_target;
              if (aref (dist, target) < inf / 2.0)
                score := score + 1.0;
            between_next_target:;
            }
        between_next_source:;
        }
      return score;
    }

  signal ('CY3102', sprintf ('Unsupported centrality metric: %s', metric));
}
;

-- Get context value by key
create procedure DB.DBA.CYP_CTX_GET (in _ctx any, in _key varchar)
{
  declare i, n integer;

  n := length (_ctx);
  for (i := 0; i < n; i := i + 2)
    {
      if (aref (_ctx, i) = _key)
        return aref (_ctx, i + 1);
    }
  return null;
}
;

-- Set context value by key (returns new context)
create procedure DB.DBA.CYP_CTX_SET (inout _ctx any, in _key varchar, in _val any)
{
  declare i, n integer;

  n := length (_ctx);
  for (i := 0; i < n; i := i + 2)
    {
      if (aref (_ctx, i) = _key)
        {
          aset (_ctx, i + 1, _val);
          return;
        }
    }
  _ctx := vector_concat (_ctx, vector (_key, _val));
}
;

create procedure DB.DBA.CYP_CTX_HAS_VAR (in _ctx any, in _var_name varchar)
{
  declare vars any;
  declare i integer;

  vars := DB.DBA.CYP_CTX_GET (_ctx, 'vars');
  for (i := 0; i < length (vars); i := i + 1)
    {
      if (aref (vars, i) = _var_name)
        return 1;
    }
  return 0;
}
;

create procedure DB.DBA.CYP_CTX_ADD_VAR (inout _ctx any, in _var_name varchar)
{
  declare vars any;

  if (_var_name is null)
    return;
  if (DB.DBA.CYP_CTX_HAS_VAR (_ctx, _var_name))
    return;
  vars := DB.DBA.CYP_CTX_GET (_ctx, 'vars');
  vars := vector_concat (vars, vector (_var_name));
  DB.DBA.CYP_CTX_SET (_ctx, 'vars', vars);
}
;

create procedure DB.DBA.CYP_DEGREE_GRAPH_EXPR (in _expr any, inout _ctx any)
{
  declare iri_uri any;
  if (_expr is null)
    return null;
  if (isarray (_expr) and aref (_expr, 0) = 'IRI')
    {
      iri_uri := DB.DBA.CYP_EXPAND_PREFIXED_NAME (_ctx, aref (_expr, 1));
      if (not isstring (iri_uri))
        iri_uri := aref (_expr, 1);
      return concat ('<', iri_uri, '>');
    }
  if (isarray (_expr) and aref (_expr, 0) = 'LIT')
    return concat ('<', cast (aref (_expr, 1) as varchar), '>');
  return DB.DBA.CYP_GEN_EXPR (_expr, _ctx, 0);
}
;

create procedure DB.DBA.CYP_DEGREE_WEIGHT_PROP (in _expr any, inout _ctx any)
{
  declare prop_name varchar;
  if (_expr is null)
    return null;
  if (isarray (_expr) and aref (_expr, 0) = 'IRI')
    return DB.DBA.CYP_GEN_EXPR (_expr, _ctx, 0);
  prop_name := DB.DBA.CYP_EXPR_LITERAL_STRING (_expr);
  if (prop_name is null or prop_name = '' or lower (prop_name) = 'none')
    return null;
  return DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_PROP_URI (_ctx, prop_name));
}
;

create procedure DB.DBA.CYP_DEGREE_RELATION_PRED (in _expr any, inout _ctx any)
{
  declare rel_name varchar;
  if (_expr is null)
    return null;
  if (isarray (_expr) and aref (_expr, 0) = 'IRI')
    return DB.DBA.CYP_GEN_EXPR (_expr, _ctx, 0);
  rel_name := DB.DBA.CYP_EXPR_LITERAL_STRING (_expr);
  if (rel_name is null or rel_name = '' or rel_name = '*' or lower (rel_name) = 'any')
    return null;
  return DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_REL_TYPE_URI (_ctx, rel_name));
}
;

create procedure DB.DBA.CYP_CTX_ADD_DEGREE_BRANCH
  (inout _ctx any, in _node varchar, in _direction varchar, in _rel_pred varchar, in _weight_prop varchar,
   in _edge_id_var varchar, in _weight_var varchar, in _indent varchar)
{
  declare nbr, pred, stmt, raw_weight varchar;
  declare branch varchar;

  nbr := concat ('?', DB.DBA.CYP_FRESH_VAR (_ctx), '_deg_nbr');
  if (_rel_pred is not null and _rel_pred <> '')
    pred := _rel_pred;
  else
    pred := concat ('?', DB.DBA.CYP_FRESH_VAR (_ctx), '_deg_p');

  if (_weight_prop is not null)
    {
      stmt := concat ('?', DB.DBA.CYP_FRESH_VAR (_ctx), '_deg_stmt');
      raw_weight := concat ('?', DB.DBA.CYP_FRESH_VAR (_ctx), '_deg_weight_raw');
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

  DB.DBA.CYP_ADD_RAW_TRIPLES (_ctx, branch);
}
;

create procedure DB.DBA.CYP_GEN_DEGREE_CENTRALITY (in _args any, inout _ctx any, in _optional integer)
{
  declare node_expr any;
  declare node_var, dir, rel_pred, weight_prop, graph_expr varchar;
  declare edge_id_var, weight_var varchar;
  declare saved_triples, degree_body varchar;

  if (length (_args) < 1)
    signal ('CY3100', 'degree_centrality requires a node expression');

  node_expr := aref (_args, 0);
  node_var := DB.DBA.CYP_GEN_EXPR (node_expr, _ctx, _optional);

  dir := 'in';
  if (length (_args) > 1)
    {
      declare dir_arg varchar;
      dir_arg := lower (DB.DBA.CYP_EXPR_LITERAL_STRING (aref (_args, 1)));
      if (dir_arg is not null and dir_arg <> '')
        dir := dir_arg;
    }
  if (dir = 'undirected')
    dir := 'both';
  if (dir <> 'both' and dir <> 'out' and dir <> 'in')
    signal ('CY3101', 'degree_centrality direction must be "in", "out", "both", or "undirected"');

  rel_pred := null;
  weight_prop := null;
  graph_expr := null;
  if (length (_args) > 2)
    {
      if (length (_args) = 4
          and isarray (aref (_args, 3)) and aref (aref (_args, 3), 0) = 'IRI'
          and isarray (aref (_args, 2)) and aref (aref (_args, 2), 0) <> 'IRI')
        {
          weight_prop := DB.DBA.CYP_DEGREE_WEIGHT_PROP (aref (_args, 2), _ctx);
          graph_expr := DB.DBA.CYP_DEGREE_GRAPH_EXPR (aref (_args, 3), _ctx);
        }
      else
        {
          rel_pred := DB.DBA.CYP_DEGREE_RELATION_PRED (aref (_args, 2), _ctx);
          if (length (_args) > 3)
            weight_prop := DB.DBA.CYP_DEGREE_WEIGHT_PROP (aref (_args, 3), _ctx);
          if (length (_args) > 4)
            graph_expr := DB.DBA.CYP_DEGREE_GRAPH_EXPR (aref (_args, 4), _ctx);
        }
    }
  if (graph_expr is not null and length (graph_expr) > 2
      and subseq (graph_expr, 0, 1) = '<' and subseq (graph_expr, length (graph_expr) - 1) = '>')
    {
      declare extras any;
      declare graph_uri varchar;
      graph_uri := subseq (graph_expr, 1, length (graph_expr) - 1);
      extras := DB.DBA.CYP_CTX_GET (_ctx, 'extra_from_graphs');
      extras := vector_concat (extras, vector (vector ('FROM_NAMED', graph_uri)));
      DB.DBA.CYP_CTX_SET (_ctx, 'extra_from_graphs', extras);
    }

  edge_id_var := concat ('?', DB.DBA.CYP_FRESH_VAR (_ctx), '_deg_edge');
  weight_var := concat ('?', DB.DBA.CYP_FRESH_VAR (_ctx), '_deg_weight');

  saved_triples := DB.DBA.CYP_CTX_GET (_ctx, 'triples');
  DB.DBA.CYP_CTX_SET (_ctx, 'triples', '');

  if (dir = 'out')
    DB.DBA.CYP_CTX_ADD_DEGREE_BRANCH (_ctx, node_var, 'out', rel_pred, weight_prop, edge_id_var, weight_var, '    ');
  else if (dir = 'in')
    DB.DBA.CYP_CTX_ADD_DEGREE_BRANCH (_ctx, node_var, 'in', rel_pred, weight_prop, edge_id_var, weight_var, '    ');
  else
    {
      DB.DBA.CYP_ADD_RAW_TRIPLES (_ctx, '    {\n');
      DB.DBA.CYP_CTX_ADD_DEGREE_BRANCH (_ctx, node_var, 'out', rel_pred, weight_prop, edge_id_var, weight_var, '      ');
      DB.DBA.CYP_ADD_RAW_TRIPLES (_ctx, '    } UNION {\n');
      DB.DBA.CYP_CTX_ADD_DEGREE_BRANCH (_ctx, node_var, 'in', rel_pred, weight_prop, edge_id_var, weight_var, '      ');
      DB.DBA.CYP_ADD_RAW_TRIPLES (_ctx, '    }\n');
    }

  degree_body := DB.DBA.CYP_CTX_GET (_ctx, 'triples');
  DB.DBA.CYP_CTX_SET (_ctx, 'triples', saved_triples);

  if (graph_expr is not null and graph_expr <> '')
    degree_body := concat ('    GRAPH ', graph_expr, ' {\n', degree_body, '    }\n');

  DB.DBA.CYP_ADD_RAW_TRIPLES (_ctx, concat ('  OPTIONAL {\n', degree_body, '  }\n'));

  if (weight_prop is not null)
    return concat ('COALESCE(SUM(', weight_var, '), 0)');
  return concat ('COUNT(DISTINCT ', edge_id_var, ')');
}
;

create procedure DB.DBA.CYP_CENTRALITY_GRAPH_URI (in _expr any, inout _ctx any)
{
  declare val any;
  if (_expr is null)
    return coalesce (DB.DBA.CYP_CTX_GET (_ctx, 'graph'), DB.DBA.OPENCYPHER_DEFAULT_GRAPH ());
  if (isarray (_expr) and aref (_expr, 0) = 'IRI')
    {
      val := DB.DBA.CYP_EXPAND_PREFIXED_NAME (_ctx, aref (_expr, 1));
      if (isstring (val))
        return val;
      return aref (_expr, 1);
    }
  if (isarray (_expr) and aref (_expr, 0) = 'LIT')
    return cast (aref (_expr, 1) as varchar);
  return coalesce (DB.DBA.CYP_CTX_GET (_ctx, 'graph'), DB.DBA.OPENCYPHER_DEFAULT_GRAPH ());
}
;

create procedure DB.DBA.CYP_CENTRALITY_REL_URI (in _expr any, inout _ctx any)
{
  declare rel_name varchar;
  if (_expr is null)
    return null;
  if (isarray (_expr) and aref (_expr, 0) = 'IRI')
    {
      declare val any;
      val := DB.DBA.CYP_EXPAND_PREFIXED_NAME (_ctx, aref (_expr, 1));
      if (isstring (val))
        return val;
      return aref (_expr, 1);
    }
  rel_name := DB.DBA.CYP_EXPR_LITERAL_STRING (_expr);
  if (rel_name is null or rel_name = '' or rel_name = '*' or lower (rel_name) = 'any')
    return null;
  return DB.DBA.CYP_REL_TYPE_URI (_ctx, rel_name);
}
;

create procedure DB.DBA.CYP_CENTRALITY_WEIGHT_URI (in _expr any, inout _ctx any)
{
  declare prop_name varchar;
  if (_expr is null)
    return null;
  if (isarray (_expr) and aref (_expr, 0) = 'IRI')
    {
      declare val any;
      val := DB.DBA.CYP_EXPAND_PREFIXED_NAME (_ctx, aref (_expr, 1));
      if (isstring (val))
        return val;
      return aref (_expr, 1);
    }
  prop_name := DB.DBA.CYP_EXPR_LITERAL_STRING (_expr);
  if (prop_name is null or prop_name = '' or lower (prop_name) = 'none')
    return null;
  return DB.DBA.CYP_PROP_URI (_ctx, prop_name);
}
;

create procedure DB.DBA.CYP_GEN_GRAPH_CENTRALITY_EXPR (in _args any, inout _ctx any, in _metric varchar, in _optional integer)
{
  declare node_expr any;
  declare node_s, dir, rel_uri, weight_uri, graph_uri varchar;

  if (length (_args) < 1)
    signal ('CY3100', sprintf ('%s_centrality requires a node expression', _metric));

  node_expr := aref (_args, 0);
  node_s := DB.DBA.CYP_GEN_EXPR (node_expr, _ctx, _optional);
  dir := 'in';
  if (length (_args) > 1)
    {
      declare dir_arg varchar;
      dir_arg := lower (DB.DBA.CYP_EXPR_LITERAL_STRING (aref (_args, 1)));
      if (dir_arg is not null and dir_arg <> '')
        dir := dir_arg;
    }
  if (dir = 'undirected')
    dir := 'both';
  if (dir <> 'both' and dir <> 'out' and dir <> 'in')
    signal ('CY3101', sprintf ('%s_centrality direction must be "in", "out", "both", or "undirected"', _metric));

  rel_uri := null;
  weight_uri := null;
  graph_uri := coalesce (DB.DBA.CYP_CTX_GET (_ctx, 'graph'), DB.DBA.OPENCYPHER_DEFAULT_GRAPH ());
  if (length (_args) > 2)
    {
      if (length (_args) = 4
          and isarray (aref (_args, 3)) and aref (aref (_args, 3), 0) = 'IRI'
          and isarray (aref (_args, 2)) and aref (aref (_args, 2), 0) <> 'IRI')
        {
          weight_uri := DB.DBA.CYP_CENTRALITY_WEIGHT_URI (aref (_args, 2), _ctx);
          graph_uri := DB.DBA.CYP_CENTRALITY_GRAPH_URI (aref (_args, 3), _ctx);
        }
      else
        {
          rel_uri := DB.DBA.CYP_CENTRALITY_REL_URI (aref (_args, 2), _ctx);
          if (length (_args) > 3)
            weight_uri := DB.DBA.CYP_CENTRALITY_WEIGHT_URI (aref (_args, 3), _ctx);
          if (length (_args) > 4)
            graph_uri := DB.DBA.CYP_CENTRALITY_GRAPH_URI (aref (_args, 4), _ctx);
        }
    }

  return concat ('sql:CYP_GRAPH_CENTRALITY(CONCAT("", STR(', node_s, ')), ',
    DB.DBA.OPENCYPHER_FMT_LITERAL (graph_uri), ', ',
    case when rel_uri is null then DB.DBA.OPENCYPHER_FMT_LITERAL ('') else DB.DBA.OPENCYPHER_FMT_LITERAL (rel_uri) end, ', ',
    DB.DBA.OPENCYPHER_FMT_LITERAL (dir), ', ',
    case when weight_uri is null then DB.DBA.OPENCYPHER_FMT_LITERAL ('') else DB.DBA.OPENCYPHER_FMT_LITERAL (weight_uri) end, ', ',
    DB.DBA.OPENCYPHER_FMT_LITERAL (_metric), ')');
}
;

create procedure DB.DBA.CYP_EXPR_IS_BINDABLE_LITERAL (in _expr any)
{
  declare etype varchar;
  declare vals any;
  declare i integer;

  if (_expr is null or not isarray (_expr))
    return 0;

  etype := aref (_expr, 0);
  if (etype = 'LIT' or etype = 'FLOAT' or etype = 'IRI' or etype = 'TYPEDLIT' or etype = 'LANGLIT')
    return 1;

  if (etype = 'LIST')
    {
      vals := aref (_expr, 1);
      for (i := 0; i < length (vals); i := i + 1)
        {
          if (not DB.DBA.CYP_EXPR_IS_BINDABLE_LITERAL (aref (vals, i)))
            return 0;
        }
      return 1;
    }

  if (etype = 'MAP')
    {
      vals := aref (_expr, 2);
      for (i := 0; i < length (vals); i := i + 1)
        {
          if (not DB.DBA.CYP_EXPR_IS_BINDABLE_LITERAL (aref (vals, i)))
            return 0;
        }
      return 1;
    }

  return 0;
}
;

create procedure DB.DBA.CYP_CTX_GET_EXPR_BINDING (in _ctx any, in _var_name varchar)
{
  declare bindings any;
  declare i integer;

  bindings := DB.DBA.CYP_CTX_GET (_ctx, 'expr_bindings');
  if (bindings is null)
    return null;

  for (i := 0; i < length (bindings); i := i + 1)
    {
      if (aref (aref (bindings, i), 0) = _var_name)
        return aref (aref (bindings, i), 1);
    }
  return null;
}
;

create procedure DB.DBA.CYP_CTX_BIND_EXPR (inout _ctx any, in _var_name varchar, in _expr any)
{
  declare bindings, out_bindings any;
  declare i integer;

  if (_var_name is null or not DB.DBA.CYP_EXPR_IS_BINDABLE_LITERAL (_expr))
    return;

  bindings := DB.DBA.CYP_CTX_GET (_ctx, 'expr_bindings');
  if (bindings is null)
    bindings := vector ();
  out_bindings := vector ();
  for (i := 0; i < length (bindings); i := i + 1)
    {
      if (aref (aref (bindings, i), 0) <> _var_name)
        out_bindings := vector_concat (out_bindings, vector (aref (bindings, i)));
    }
  out_bindings := vector_concat (out_bindings, vector (vector (_var_name, _expr)));
  DB.DBA.CYP_CTX_SET (_ctx, 'expr_bindings', out_bindings);
}
;

create procedure DB.DBA.CYP_EXPR_RESOLVE_BINDING (in _expr any, inout _ctx any)
{
  declare bound any;

  if (isarray (_expr) and aref (_expr, 0) = 'VAR')
    {
      bound := DB.DBA.CYP_CTX_GET_EXPR_BINDING (_ctx, aref (_expr, 1));
      if (bound is not null)
        return bound;
    }
  return _expr;
}
;

create procedure DB.DBA.CYP_CTX_ADD_REL_VAR (inout _ctx any, in _var_name varchar)
{
  declare rel_vars any;
  declare i integer;

  if (_var_name is null)
    return;

  rel_vars := DB.DBA.CYP_CTX_GET (_ctx, 'rel_vars');
  for (i := 0; i < length (rel_vars); i := i + 1)
    {
      if (aref (rel_vars, i) = _var_name)
        return;
    }
  rel_vars := vector_concat (rel_vars, vector (_var_name));
  DB.DBA.CYP_CTX_SET (_ctx, 'rel_vars', rel_vars);
}
;

create procedure DB.DBA.CYP_CTX_IS_REL_VAR (in _ctx any, in _var_name varchar)
{
  declare rel_vars any;
  declare i integer;

  rel_vars := DB.DBA.CYP_CTX_GET (_ctx, 'rel_vars');
  for (i := 0; i < length (rel_vars); i := i + 1)
    {
      if (aref (rel_vars, i) = _var_name)
        return 1;
    }
  return 0;
}
;

create procedure DB.DBA.CYP_CTX_ADD_PATH_VAR (
  inout _ctx any,
  in _path_name varchar,
  in _hop_count integer,
  in _node_terms any,
  in _rel_terms any,
  in _has_varlen integer)
{
  declare path_vars any;
  declare i integer;

  if (_path_name is null)
    return;

  path_vars := DB.DBA.CYP_CTX_GET (_ctx, 'path_vars');
  for (i := 0; i < length (path_vars); i := i + 1)
    {
      if (DB.DBA.CYP_PATH_VAR_NAME (aref (path_vars, i)) = _path_name)
        {
          aset (path_vars, i, DB.DBA.CYP_PATH_VAR_NEW (
            _path_name, _hop_count, _node_terms, _rel_terms, _has_varlen));
          DB.DBA.CYP_CTX_SET (_ctx, 'path_vars', path_vars);
          return;
        }
    }

  path_vars := vector_concat (path_vars,
                              vector (DB.DBA.CYP_PATH_VAR_NEW (
                                _path_name, _hop_count, _node_terms, _rel_terms, _has_varlen)));
  DB.DBA.CYP_CTX_SET (_ctx, 'path_vars', path_vars);
}
;

create procedure DB.DBA.CYP_CTX_GET_PATH_VAR (in _ctx any, in _path_name varchar)
{
  declare path_vars any;
  declare i integer;

  path_vars := DB.DBA.CYP_CTX_GET (_ctx, 'path_vars');
  for (i := 0; i < length (path_vars); i := i + 1)
    {
      if (DB.DBA.CYP_PATH_VAR_NAME (aref (path_vars, i)) = _path_name)
        return aref (path_vars, i);
    }
  return null;
}
;

create procedure DB.DBA.CYP_CTX_PATTERN_EXPR (inout _ctx any)
{
  declare pctx any;

  pctx := DB.DBA.CYP_CTX_NEW (DB.DBA.CYP_CTX_GET (_ctx, 'graph'));
  DB.DBA.CYP_CTX_SET (pctx, 'prefixes', DB.DBA.CYP_CTX_GET (_ctx, 'prefixes'));
  DB.DBA.CYP_CTX_SET (pctx, 'base_uri', DB.DBA.CYP_CTX_GET (_ctx, 'base_uri'));
  DB.DBA.CYP_CTX_SET (pctx, 'defines', DB.DBA.CYP_CTX_GET (_ctx, 'defines'));
  DB.DBA.CYP_CTX_SET (pctx, 'reif_graph', DB.DBA.CYP_REIF_GRAPH (_ctx));
  DB.DBA.CYP_CTX_SET (pctx, 'extra_from_graphs', DB.DBA.CYP_CTX_GET (_ctx, 'extra_from_graphs'));
  DB.DBA.CYP_CTX_SET (pctx, 'var_counter', DB.DBA.CYP_CTX_GET (_ctx, 'var_counter'));
  return pctx;
}
;

create procedure DB.DBA.CYP_PATTERN_EXPR_SEED_NODE_VARS (inout _ctx any, in _pat any)
{
  declare pat_type varchar;
  declare elements any;
  declare i integer;
  declare elem any;

  pat_type := aref (_pat, 0);
  if (pat_type = 'PATHVAR')
    {
      DB.DBA.CYP_PATTERN_EXPR_SEED_NODE_VARS (_ctx, aref (_pat, 2));
      return;
    }
  if (pat_type <> 'PATTERN')
    return;

  elements := aref (_pat, 1);
  for (i := 0; i < length (elements); i := i + 1)
    {
      elem := aref (elements, i);
      if (aref (elem, 0) = 'NODE' and aref (elem, 1) is not null)
        DB.DBA.CYP_CTX_ADD_VAR (_ctx, aref (elem, 1));
    }
}
;

create procedure DB.DBA.CYP_PATTERN_HAS_REL (in _pat any)
{
  declare pat_type varchar;
  declare elements any;
  declare i integer;

  pat_type := aref (_pat, 0);
  if (pat_type = 'PATHVAR')
    return DB.DBA.CYP_PATTERN_HAS_REL (aref (_pat, 2));
  if (pat_type <> 'PATTERN')
    return 0;

  elements := aref (_pat, 1);
  for (i := 0; i < length (elements); i := i + 1)
    {
      if (aref (aref (elements, i), 0) = 'REL')
        return 1;
    }
  return 0;
}
;

create procedure DB.DBA.CYP_PATTERN_EXPR_BODY (inout _ctx any, in _pat any)
{
  declare pctx any;
  declare body varchar;

  pctx := DB.DBA.CYP_CTX_PATTERN_EXPR (_ctx);
  DB.DBA.CYP_PATTERN_EXPR_SEED_NODE_VARS (pctx, _pat);
  DB.DBA.CYP_GEN_PATTERN (pctx, _pat, 0);
  DB.DBA.CYP_CTX_SET (_ctx, 'var_counter', DB.DBA.CYP_CTX_GET (pctx, 'var_counter'));
  body := DB.DBA.CYP_CTX_GET (pctx, 'triples');
  body := concat (body, DB.DBA.CYP_CTX_GET (pctx, 'binds'));
  body := concat (body, DB.DBA.CYP_CTX_GET (pctx, 'optionals'));
  body := concat (body, DB.DBA.CYP_CTX_GET (pctx, 'filters'));
  return body;
}
;

create procedure DB.DBA.CYP_EXPR_SUBST_VAR (in _expr any, in _var varchar, in _replacement any)
{
  declare etype varchar;
  declare i integer;
  declare elems, keys, vals, args, whens any;
  declare out_expr any;

  if (_expr is null or not isarray (_expr))
    return _expr;

  etype := aref (_expr, 0);
  if (etype = 'VAR' and aref (_expr, 1) = _var)
    return _replacement;

  if (etype = 'BINOP')
    return vector ('BINOP', aref (_expr, 1),
                   DB.DBA.CYP_EXPR_SUBST_VAR (aref (_expr, 2), _var, _replacement),
                   DB.DBA.CYP_EXPR_SUBST_VAR (aref (_expr, 3), _var, _replacement));
  if (etype = 'UNOP')
    return vector ('UNOP', aref (_expr, 1),
                   DB.DBA.CYP_EXPR_SUBST_VAR (aref (_expr, 2), _var, _replacement));
  if (etype = 'PROP')
    return vector ('PROP',
                   DB.DBA.CYP_EXPR_SUBST_VAR (aref (_expr, 1), _var, _replacement),
                   aref (_expr, 2));
  if (etype = 'SLICE')
    return vector ('SLICE',
                   DB.DBA.CYP_EXPR_SUBST_VAR (aref (_expr, 1), _var, _replacement),
                   DB.DBA.CYP_EXPR_SUBST_VAR (aref (_expr, 2), _var, _replacement),
                   DB.DBA.CYP_EXPR_SUBST_VAR (aref (_expr, 3), _var, _replacement));
  if (etype = 'ISNULL')
    return vector ('ISNULL',
                   DB.DBA.CYP_EXPR_SUBST_VAR (aref (_expr, 1), _var, _replacement),
                   aref (_expr, 2));
  if (etype = 'INEXPR' or etype = 'STROP')
    return vector (etype, aref (_expr, 1),
                   DB.DBA.CYP_EXPR_SUBST_VAR (aref (_expr, 2), _var, _replacement),
                   DB.DBA.CYP_EXPR_SUBST_VAR (aref (_expr, 3), _var, _replacement));
  if (etype = 'FUNC')
    {
      args := vector ();
      for (i := 0; i < length (aref (_expr, 3)); i := i + 1)
        args := vector_concat (args, vector (DB.DBA.CYP_EXPR_SUBST_VAR (aref (aref (_expr, 3), i), _var, _replacement)));
      return vector ('FUNC', aref (_expr, 1), aref (_expr, 2), args);
    }
  if (etype = 'LIST')
    {
      elems := vector ();
      for (i := 0; i < length (aref (_expr, 1)); i := i + 1)
        elems := vector_concat (elems, vector (DB.DBA.CYP_EXPR_SUBST_VAR (aref (aref (_expr, 1), i), _var, _replacement)));
      return vector ('LIST', elems);
    }
  if (etype = 'MAP')
    {
      keys := aref (_expr, 1);
      vals := vector ();
      for (i := 0; i < length (aref (_expr, 2)); i := i + 1)
        vals := vector_concat (vals, vector (DB.DBA.CYP_EXPR_SUBST_VAR (aref (aref (_expr, 2), i), _var, _replacement)));
      return vector ('MAP', keys, vals);
    }
  if (etype = 'CASEEXPR')
    {
      whens := vector ();
      for (i := 0; i < length (aref (_expr, 2)); i := i + 1)
        whens := vector_concat (whens, vector (vector (
          DB.DBA.CYP_EXPR_SUBST_VAR (aref (aref (aref (_expr, 2), i), 0), _var, _replacement),
          DB.DBA.CYP_EXPR_SUBST_VAR (aref (aref (aref (_expr, 2), i), 1), _var, _replacement))));
      return vector ('CASEEXPR',
                     DB.DBA.CYP_EXPR_SUBST_VAR (aref (_expr, 1), _var, _replacement),
                     whens,
                     DB.DBA.CYP_EXPR_SUBST_VAR (aref (_expr, 3), _var, _replacement));
    }

  out_expr := _expr;
  return out_expr;
}
;

create procedure DB.DBA.CYP_GEN_VECTOR_EXPR (in _elems any, inout _ctx any, in _optional integer)
{
  declare i integer;
  declare out_s varchar;

  out_s := '';
  for (i := 0; i < length (_elems); i := i + 1)
    {
      if (i > 0) out_s := concat (out_s, ', ');
      out_s := concat (out_s, DB.DBA.CYP_GEN_EXPR (aref (_elems, i), _ctx, _optional));
    }
  return concat ('bif:vector(', out_s, ')');
}
;

create procedure DB.DBA.CYP_GEN_LIST_CELL_EXPR (in _expr any, inout _ctx any, in _optional integer)
{
  if (isarray (_expr) and aref (_expr, 0) = 'LIST')
    return concat ('sql:CYP_LIST_NEW(',
                   DB.DBA.CYP_GEN_VECTOR_EXPR (aref (_expr, 1), _ctx, _optional),
                   ')');
  return concat ('sql:CYP_LIST_NEW(',
                 DB.DBA.CYP_GEN_EXPR (_expr, _ctx, _optional),
                 ')');
}
;

create procedure DB.DBA.CYP_MAP_LITERAL_GET (in _map any, in _key varchar)
{
  declare keys any;
  declare i integer;
  keys := aref (_map, 1);
  for (i := 0; i < length (keys); i := i + 1)
    {
      if (aref (keys, i) = _key)
        return aref (aref (_map, 2), i);
    }
  return vector ('LIT', null);
}
;

create procedure DB.DBA.CYP_GEN_MAP_CELL_EXPR (in _map any, inout _ctx any, in _optional integer)
{
  declare i integer;
  declare keys, vals any;
  declare key_s, val_s varchar;

  keys := aref (_map, 1);
  vals := aref (_map, 2);
  key_s := '';
  val_s := '';
  for (i := 0; i < length (keys); i := i + 1)
    {
      if (i > 0)
        {
          key_s := concat (key_s, ', ');
          val_s := concat (val_s, ', ');
        }
      key_s := concat (key_s, DB.DBA.OPENCYPHER_FMT_LITERAL (aref (keys, i)));
      val_s := concat (val_s, DB.DBA.CYP_GEN_EXPR (aref (vals, i), _ctx, _optional));
    }
  return concat ('sql:CYP_MAP_NEW(bif:vector(', key_s, '), bif:vector(', val_s, '))');
}
;

create procedure DB.DBA.CYP_GEN_MAP_EXPR (in _map any, inout _ctx any, in _optional integer)
{
  return concat ('sql:CYP_MAP_TO_VECTOR(',
                 DB.DBA.CYP_GEN_MAP_CELL_EXPR (_map, _ctx, _optional), ')');
}
;

create procedure DB.DBA.CYP_GEN_LISTCOMP_EXPR (in _expr any, inout _ctx any, in _optional integer)
{
  declare var_name varchar;
  declare list_expr, where_expr, proj_expr, item_expr any;
  declare elems, out_elems any;
  declare i integer;
  declare acc_s, cond_s, proj_s varchar;

  var_name := aref (_expr, 1);
  list_expr := aref (_expr, 2);
  where_expr := aref (_expr, 3);
  proj_expr := aref (_expr, 4);
  if (proj_expr is null)
    proj_expr := vector ('VAR', var_name);

  list_expr := DB.DBA.CYP_EXPR_RESOLVE_BINDING (list_expr, _ctx);
  if (not isarray (list_expr) or aref (list_expr, 0) <> 'LIST')
    return sprintf ('sql:CYP_LISTCOMP_EVAL(%s, ''%s'', ''%s'', ''%s'')',
      DB.DBA.CYP_GEN_EXPR (list_expr, _ctx, _optional),
      var_name,
      DB.DBA.CYP_GEN_EXPR (where_expr, _ctx, _optional),
      DB.DBA.CYP_GEN_EXPR (proj_expr, _ctx, _optional));

  elems := aref (list_expr, 1);
  if (where_expr is not null)
    {
      acc_s := 'bif:vector()';
      for (i := 0; i < length (elems); i := i + 1)
        {
          item_expr := aref (elems, i);
          cond_s := DB.DBA.CYP_GEN_EXPR (DB.DBA.CYP_EXPR_SUBST_VAR (where_expr, var_name, item_expr), _ctx, _optional);
          proj_s := DB.DBA.CYP_GEN_EXPR (DB.DBA.CYP_EXPR_SUBST_VAR (proj_expr, var_name, item_expr), _ctx, _optional);
          acc_s := sprintf ('bif:vector_concat(%s, IF(%s, bif:vector(%s), bif:vector()))',
                            acc_s, cond_s, proj_s);
        }
      return acc_s;
    }

  out_elems := vector ();
  for (i := 0; i < length (elems); i := i + 1)
    {
      item_expr := aref (elems, i);
      out_elems := vector_concat (out_elems, vector (DB.DBA.CYP_EXPR_SUBST_VAR (proj_expr, var_name, item_expr)));
    }
  return DB.DBA.CYP_GEN_VECTOR_EXPR (out_elems, _ctx, _optional);
}
;

create procedure DB.DBA.CYP_GEN_REDUCE_EXPR (in _expr any, inout _ctx any, in _optional integer)
{
  declare acc_name, var_name varchar;
  declare acc_expr, list_expr, body_expr any;
  declare elems any;
  declare i integer;

  acc_name := aref (_expr, 1);
  acc_expr := aref (_expr, 2);
  var_name := aref (_expr, 3);
  list_expr := aref (_expr, 4);
  body_expr := aref (_expr, 5);

  list_expr := DB.DBA.CYP_EXPR_RESOLVE_BINDING (list_expr, _ctx);
  if (not isarray (list_expr) or aref (list_expr, 0) <> 'LIST')
    signal ('CY095', 'REDUCE over dynamic list sources is not yet implemented in openCypher');

  elems := aref (list_expr, 1);
  for (i := 0; i < length (elems); i := i + 1)
    acc_expr := DB.DBA.CYP_EXPR_SUBST_VAR (
      DB.DBA.CYP_EXPR_SUBST_VAR (body_expr, var_name, aref (elems, i)),
      acc_name,
      acc_expr);
  return DB.DBA.CYP_GEN_EXPR (acc_expr, _ctx, _optional);
}
;

-- Generate a fresh SPARQL variable name
create procedure DB.DBA.CYP_FRESH_VAR (inout _ctx any)
{
  declare cnt integer;

  cnt := DB.DBA.CYP_CTX_GET (_ctx, 'var_counter');
  if (cnt is null) cnt := 0;
  cnt := cnt + 1;
  DB.DBA.CYP_CTX_SET (_ctx, 'var_counter', cnt);
  return sprintf ('_v%d', cnt);
}
;

-- Add triple pattern to context
create procedure DB.DBA.CYP_ADD_TRIPLE (inout _ctx any, in _s varchar, in _p varchar, in _o varchar)
{
  declare cur varchar;

  cur := DB.DBA.CYP_CTX_GET (_ctx, 'triples');
  cur := concat (cur, '    ', _s, ' ', _p, ' ', _o, ' .\n');
  DB.DBA.CYP_CTX_SET (_ctx, 'triples', cur);
}
;

-- Add FILTER to context
create procedure DB.DBA.CYP_ADD_FILTER (inout _ctx any, in _f varchar)
{
  declare cur varchar;

  cur := DB.DBA.CYP_CTX_GET (_ctx, 'filters');
  cur := concat (cur, '    FILTER (', _f, ') .\n');
  DB.DBA.CYP_CTX_SET (_ctx, 'filters', cur);
}
;

-- Add OPTIONAL block to context
create procedure DB.DBA.CYP_ADD_OPTIONAL (inout _ctx any, in _block varchar)
{
  declare cur varchar;

  cur := DB.DBA.CYP_CTX_GET (_ctx, 'optionals');
  cur := concat (cur, '    OPTIONAL { ', _block, ' } .\n');
  DB.DBA.CYP_CTX_SET (_ctx, 'optionals', cur);
}
;

-- Add BIND to context
create procedure DB.DBA.CYP_ADD_BIND (inout _ctx any, in _expr varchar, in _var varchar)
{
  declare cur varchar;

  cur := DB.DBA.CYP_CTX_GET (_ctx, 'binds');
  cur := concat (cur, '    BIND (', _expr, ' AS ', _var, ') .\n');
  DB.DBA.CYP_CTX_SET (_ctx, 'binds', cur);
}
;

-- Get or create a SPARQL variable for a Cypher property access (n.prop)
create procedure DB.DBA.CYP_PROP_SPARQL_VAR (inout _ctx any, in _var_name varchar, in _prop_name varchar, in _optional integer)
{
  declare pvs any;
  declare i, n integer;
  declare sparql_var varchar;
  declare safe_prop_name varchar;
  declare pv any;
  declare triple varchar;

  pvs := DB.DBA.CYP_CTX_GET (_ctx, 'prop_vars');
  n := length (pvs);
  for (i := 0; i < n; i := i + 1)
    {
      pv := aref (pvs, i);
      if (aref (pv, 0) = _var_name and aref (pv, 1) = _prop_name)
        return aref (pv, 2);
    }

  -- Create new property variable
  safe_prop_name := DB.DBA.CYP_SAFE_VAR_SUFFIX (_prop_name);
  sparql_var := concat ('?', _var_name, '_', safe_prop_name);
  pvs := vector_concat (pvs, vector (vector (_var_name, _prop_name, sparql_var)));
  DB.DBA.CYP_CTX_SET (_ctx, 'prop_vars', pvs);

  -- Add triple pattern for this property access
  triple := concat ('?', _var_name, ' ', DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_PROP_URI (_ctx, _prop_name)),
                    ' ', sparql_var);
  if (DB.DBA.CYP_CTX_IS_REL_VAR (_ctx, _var_name))
    {
      declare cur varchar;
      if (_optional)
        {
          cur := DB.DBA.CYP_CTX_GET (_ctx, 'optionals');
          cur := concat (cur, '    OPTIONAL { GRAPH ', DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_REIF_GRAPH (_ctx)), ' { ',
                         triple, ' . } } .\n');
          DB.DBA.CYP_CTX_SET (_ctx, 'optionals', cur);
        }
      else
        {
          cur := DB.DBA.CYP_CTX_GET (_ctx, 'triples');
          cur := concat (cur, '    GRAPH ', DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_REIF_GRAPH (_ctx)), ' { ',
                         triple, ' . } .\n');
          DB.DBA.CYP_CTX_SET (_ctx, 'triples', cur);
        }
    }
  else if (_optional)
    DB.DBA.CYP_ADD_OPTIONAL (_ctx, triple);
  else
    DB.DBA.CYP_ADD_TRIPLE (_ctx, concat ('?', _var_name),
                           DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_PROP_URI (_ctx, _prop_name)),
                           sparql_var);
  return sparql_var;
}
;

-- ============================================================================
-- Main translation: AST -> SPARQL
-- ============================================================================

create procedure DB.DBA.CYP_TO_SPARQL (in _ast any, in _graph varchar)
{
  declare node_type varchar;
  declare clauses any;
  declare i, n integer;
  declare ctx any;
  declare sparql_str, select_clause, where_body varchar;
  declare has_return, has_create, has_delete, has_set, has_remove, has_merge integer;
  declare has_ask, has_construct, has_describe, has_call integer;
  declare has_sparql_update integer;
  declare return_ast, delete_ast, set_ast, remove_ast, merge_ast any;
  declare construct_ast, describe_ast any;
  declare sparql_update_ast any;
  declare create_asts any;
  declare match_asts, where_asts, with_asts, unwind_asts any;
  declare union_asts any;
  declare call_asts any;
  declare graph_asts, service_asts, values_asts, bind_asts, minus_asts any;
  declare order_clause, limit_clause, skip_clause varchar;
  declare is_distinct integer;
  declare clause any;
  declare ctype varchar;
  declare wexpr varchar;
  declare match_from_graphs any;
  declare use_graph_uri varchar;

  node_type := aref (_ast, 0);
  if (node_type <> 'STMT')
    signal ('CY020', 'Expected STMT node at top level');

  clauses := aref (_ast, 1);
  n := length (clauses);
  ctx := DB.DBA.CYP_CTX_NEW (_graph);

  has_return := 0;
  has_create := 0;
  has_delete := 0;
  has_set := 0;
  has_remove := 0;
  has_merge := 0;
  has_ask := 0;
  has_construct := 0;
  has_describe := 0;
  has_call := 0;
  has_sparql_update := 0;
  return_ast := null;
  construct_ast := null;
  describe_ast := null;
  sparql_update_ast := null;
  create_asts := vector ();
  delete_ast := null;
  set_ast := null;
  remove_ast := null;
  merge_ast := null;
  match_asts := vector ();
  where_asts := vector ();
  with_asts := vector ();
  unwind_asts := vector ();
  union_asts := vector ();
  call_asts := vector ();
  graph_asts := vector ();
  service_asts := vector ();
  values_asts := vector ();
  bind_asts := vector ();
  minus_asts := vector ();
  order_clause := '';
  limit_clause := '';
  skip_clause := '';
  is_distinct := 0;
  match_from_graphs := vector ();

  -- Classify clauses
  for (i := 0; i < n; i := i + 1)
    {
      clause := aref (clauses, i);
      ctype := aref (clause, 0);

      if (ctype = 'MATCH')
        match_asts := vector_concat (match_asts, vector (clause));
      else if (ctype = 'WHERE')
        where_asts := vector_concat (where_asts, vector (clause));
      else if (ctype = 'RETURN')
        { has_return := 1; return_ast := clause; }
      else if (ctype = 'ASK')
        has_ask := 1;
      else if (ctype = 'CONSTRUCT')
        { has_construct := 1; construct_ast := clause; }
      else if (ctype = 'DESCRIBE')
        { has_describe := 1; describe_ast := clause; }
      else if (ctype = 'CREATE')
        { has_create := 1; create_asts := vector_concat (create_asts, vector (clause)); }
      else if (ctype = 'DELETE')
        { has_delete := 1; delete_ast := clause; }
      else if (ctype = 'SET')
        { has_set := 1; set_ast := clause; }
      else if (ctype = 'REMOVE')
        { has_remove := 1; remove_ast := clause; }
      else if (ctype = 'MERGE')
        { has_merge := 1; merge_ast := clause; }
      else if (ctype = 'PREFIX')
        DB.DBA.CYP_CTX_ADD_PREFIX (ctx, aref (clause, 1), aref (clause, 2));
      else if (ctype = 'BASE')
        DB.DBA.CYP_CTX_SET (ctx, 'base_uri', aref (clause, 1));
      else if (ctype = 'FORCE_CAMELCASE')
        DB.DBA.CYP_CTX_SET (ctx, 'force_camelcase', 1);
      else if (ctype = 'DEFINE')
        DB.DBA.CYP_CTX_ADD_DEFINE (ctx, aref (clause, 1), aref (clause, 2));
      else if (ctype = 'USE')
        {
          use_graph_uri := DB.DBA.CYP_GRAPH_EXPR_URI (aref (clause, 1), ctx, _graph);
          _graph := use_graph_uri;
          DB.DBA.CYP_CTX_SET (ctx, 'graph', use_graph_uri);
          DB.DBA.CYP_CTX_SET (ctx, 'reif_graph', use_graph_uri);
          DB.DBA.CYP_CTX_SET (ctx, 'suppress_default_from', 0);
        }
      else if (ctype = 'USE_ANY_GRAPH')
        {
          _graph := null;
          DB.DBA.CYP_CTX_SET (ctx, 'graph', null);
          DB.DBA.CYP_CTX_SET (ctx, 'reif_graph', null);
          DB.DBA.CYP_CTX_SET (ctx, 'suppress_default_from', 1);
        }
      else if (ctype = 'WITH')
        with_asts := vector_concat (with_asts, vector (clause));
      else if (ctype = 'UNWIND')
        unwind_asts := vector_concat (unwind_asts, vector (clause));
      else if (ctype = 'UNION')
        union_asts := vector_concat (union_asts, vector (clause));
      else if (ctype = 'CALL')
        {
          has_call := 1;
          call_asts := vector_concat (call_asts, vector (clause));
        }
      else if (ctype = 'GRAPH')
        graph_asts := vector_concat (graph_asts, vector (clause));
      else if (ctype = 'SERVICE')
        service_asts := vector_concat (service_asts, vector (clause));
      else if (ctype = 'VALUES')
        values_asts := vector_concat (values_asts, vector (clause));
      else if (ctype = 'BIND')
        bind_asts := vector_concat (bind_asts, vector (clause));
      else if (ctype = 'MINUS')
        minus_asts := vector_concat (minus_asts, vector (clause));
      else if (ctype = 'SPARQL_LOAD' or ctype = 'SPARQL_CLEAR' or ctype = 'SPARQL_DROP'
               or ctype = 'SPARQL_CREATE_GRAPH' or ctype = 'SPARQL_GRAPH_COPY'
               or ctype = 'SPARQL_DATA_UPDATE')
        {
          has_sparql_update := 1;
          sparql_update_ast := clause;
        }
    }

  for (i := 0; i < length (match_asts); i := i + 1)
    {
      declare m any;
      m := aref (match_asts, i);
      if (length (m) > 3)
        match_from_graphs := vector_concat (match_from_graphs, aref (m, 3));
    }

  if (length (match_from_graphs) > 0)
    {
      declare fg any;
      for (i := 0; i < length (match_from_graphs); i := i + 1)
        {
          fg := aref (match_from_graphs, i);
          if (aref (fg, 0) = 'FROM')
            {
              DB.DBA.CYP_CTX_SET (ctx, 'reif_graph',
                                  DB.DBA.CYP_GRAPH_EXPR_URI (aref (fg, 1), ctx, null));
              goto match_reif_from_done;
            }
        }
    }
match_reif_from_done:

  if (has_sparql_update)
    {
      if (_graph is null)
        {
          _graph := DB.DBA.OPENCYPHER_DEFAULT_GRAPH ();
          DB.DBA.CYP_CTX_SET (ctx, 'graph', _graph);
          DB.DBA.CYP_CTX_SET (ctx, 'reif_graph', _graph);
        }
    return DB.DBA.CYP_GEN_SPARQL_UPDATE (sparql_update_ast, ctx);
    }

  if (length (service_asts) > 0
      and length (match_asts) = 0
      and length (graph_asts) = 0
      and length (minus_asts) = 0
      and length (union_asts) = 0
      and length (call_asts) = 0
      and length (unwind_asts) = 0
      and not has_create and not has_delete and not has_set and not has_remove and not has_merge)
    DB.DBA.CYP_CTX_SET (ctx, 'suppress_default_from', 1);

  if (length (service_asts) > 0 and length (match_asts) > 0 and _graph is null)
    {
      _graph := DB.DBA.OPENCYPHER_DEFAULT_GRAPH ();
      DB.DBA.CYP_CTX_SET (ctx, 'graph', _graph);
      DB.DBA.CYP_CTX_SET (ctx, 'reif_graph', _graph);
    }

  -- Process MATCH clauses -> generate triple patterns
  for (i := 0; i < length (match_asts); i := i + 1)
    DB.DBA.CYP_GEN_MATCH (aref (match_asts, i), ctx);

  -- Process WHERE clauses -> generate FILTER
  for (i := 0; i < length (where_asts); i := i + 1)
    {
      wexpr := DB.DBA.CYP_GEN_EXPR (aref (aref (where_asts, i), 1), ctx, 0);
      DB.DBA.CYP_ADD_FILTER (ctx, wexpr);
    }

  for (i := 0; i < length (values_asts); i := i + 1)
    DB.DBA.CYP_GEN_VALUES_CLAUSE (ctx, aref (values_asts, i));

  for (i := 0; i < length (bind_asts); i := i + 1)
    DB.DBA.CYP_GEN_BIND_CLAUSE (ctx, aref (bind_asts, i));

  for (i := 0; i < length (graph_asts); i := i + 1)
    DB.DBA.CYP_GEN_GRAPHLIKE_CLAUSE (ctx, aref (graph_asts, i), 'GRAPH');

  for (i := 0; i < length (service_asts); i := i + 1)
    DB.DBA.CYP_GEN_GRAPHLIKE_CLAUSE (ctx, aref (service_asts, i), 'SERVICE');

  for (i := 0; i < length (minus_asts); i := i + 1)
    DB.DBA.CYP_GEN_MINUS_CLAUSE (ctx, aref (minus_asts, i));

  -- Process WITH clauses - each creates a subquery boundary
  for (i := 0; i < length (with_asts); i := i + 1)
    DB.DBA.CYP_APPLY_WITH (aref (with_asts, i), ctx, _graph);

  -- Process UNWIND clauses - each expands a list into rows
  for (i := 0; i < length (unwind_asts); i := i + 1)
    DB.DBA.CYP_GEN_UNWIND (aref (unwind_asts, i), ctx);

  -- Process CALL procedure clauses
  for (i := 0; i < length (call_asts); i := i + 1)
    DB.DBA.CYP_GEN_CALL (aref (call_asts, i), ctx, _graph);

  -- Handle CREATE-only queries (no MATCH)
  if (has_create and length (match_asts) = 0 and not has_return)
    {
      if (_graph is null)
        {
          _graph := DB.DBA.OPENCYPHER_DEFAULT_GRAPH ();
          DB.DBA.CYP_CTX_SET (ctx, 'graph', _graph);
          DB.DBA.CYP_CTX_SET (ctx, 'reif_graph', _graph);
        }
      -- When preceding WITH/UNWIND clauses provide variable context,
      -- use the template (INSERT...WHERE) path so dynamic expressions
      -- like VAR, PROP, and BINOP can reference those variables.
      if (length (with_asts) > 0 or length (unwind_asts) > 0)
        return DB.DBA.CYP_GEN_MATCH_CREATE_SPARQL (match_asts, where_asts, create_asts, ctx, _graph);
      return DB.DBA.CYP_GEN_CREATE_CLAUSES_SPARQL (create_asts, ctx, _graph);
    }

  -- Handle MATCH + CREATE (create based on matched data)
  if (has_create and length (match_asts) > 0)
    {
      if (_graph is null)
        {
          _graph := DB.DBA.OPENCYPHER_DEFAULT_GRAPH ();
          DB.DBA.CYP_CTX_SET (ctx, 'graph', _graph);
          DB.DBA.CYP_CTX_SET (ctx, 'reif_graph', _graph);
        }
      return DB.DBA.CYP_GEN_MATCH_CREATE_SPARQL (match_asts, where_asts, create_asts, ctx, _graph);
    }

  -- Handle DELETE
  if (has_delete)
    {
      if (_graph is null)
        {
          _graph := DB.DBA.OPENCYPHER_DEFAULT_GRAPH ();
          DB.DBA.CYP_CTX_SET (ctx, 'graph', _graph);
          DB.DBA.CYP_CTX_SET (ctx, 'reif_graph', _graph);
        }
      return DB.DBA.CYP_GEN_DELETE_SPARQL (delete_ast, match_asts, where_asts, ctx, _graph);
    }

  -- Handle SET
  if (has_set)
    {
      if (_graph is null)
        {
          _graph := DB.DBA.OPENCYPHER_DEFAULT_GRAPH ();
          DB.DBA.CYP_CTX_SET (ctx, 'graph', _graph);
          DB.DBA.CYP_CTX_SET (ctx, 'reif_graph', _graph);
        }
      return DB.DBA.CYP_GEN_SET_SPARQL (set_ast, match_asts, where_asts, ctx, _graph);
    }

  -- Handle REMOVE
  if (has_remove)
    {
      if (_graph is null)
        {
          _graph := DB.DBA.OPENCYPHER_DEFAULT_GRAPH ();
          DB.DBA.CYP_CTX_SET (ctx, 'graph', _graph);
          DB.DBA.CYP_CTX_SET (ctx, 'reif_graph', _graph);
        }
      return DB.DBA.CYP_GEN_REMOVE_SPARQL (remove_ast, match_asts, where_asts, ctx, _graph);
    }

  -- Handle MERGE
  if (has_merge)
    {
      if (_graph is null)
        {
          _graph := DB.DBA.OPENCYPHER_DEFAULT_GRAPH ();
          DB.DBA.CYP_CTX_SET (ctx, 'graph', _graph);
          DB.DBA.CYP_CTX_SET (ctx, 'reif_graph', _graph);
        }
      return DB.DBA.CYP_GEN_MERGE_SPARQL (merge_ast, ctx, _graph);
    }

  -- Handle UNION composite statements
  if (length (union_asts) > 0)
    return DB.DBA.CYP_GEN_UNION_SPARQL (clauses, _graph);

  if (has_ask or has_construct or has_describe or has_return or has_call)
    {
      declare from_graphs any;
      from_graphs := match_from_graphs;
      if (has_ask)
        return DB.DBA.CYP_GEN_ASK_SPARQL (ctx, _graph, from_graphs);
      if (has_construct)
        return DB.DBA.CYP_GEN_CONSTRUCT_SPARQL (construct_ast, ctx, _graph, from_graphs);
      if (has_describe)
        return DB.DBA.CYP_GEN_DESCRIBE_SPARQL (describe_ast, ctx, _graph, from_graphs);
      if (has_call and not has_return)
        {
          declare dummy_return any;
          dummy_return := vector ('RETURN', 0, vector (vector ('RETITEM', vector ('LIT', 1), null)), null, null, null, null, null);
          return DB.DBA.CYP_GEN_SELECT_SPARQL (dummy_return, ctx, _graph, from_graphs);
        }
      return DB.DBA.CYP_GEN_SELECT_SPARQL (return_ast, ctx, _graph, from_graphs);
    }

  signal ('CY021', 'Query must have RETURN, ASK, CONSTRUCT, DESCRIBE, CREATE, DELETE, SET, REMOVE or MERGE clause');
}
;

-- ============================================================================
-- Parameterized translation: AST -> SPARQL with parameter binding
-- ============================================================================

create procedure DB.DBA.CYP_TO_SPARQL_PARAMS (in _ast any, in _graph varchar, in _params any := null)
{
  declare node_type varchar;
  declare clauses any;
  declare i, n integer;
  declare ctx any;
  declare sparql_str varchar;
  declare param_binding_str varchar;

  node_type := aref (_ast, 0);
  if (node_type <> 'STMT')
    signal ('CY020', 'Expected STMT node at top level');

  clauses := aref (_ast, 1);

  -- Create context with parameters stored
  ctx := DB.DBA.CYP_CTX_NEW (_graph);
  DB.DBA.CYP_CTX_SET (ctx, 'params', _params);

  -- Substitute parameters into the AST before translation
  clauses := DB.DBA.CYP_SUBSTITUTE_PARAMS (clauses, _params);

  -- Create modified AST with substituted params
  _ast := vector ('STMT', clauses);

  -- Use regular translation on modified AST
  sparql_str := DB.DBA.CYP_TO_SPARQL (_ast, _graph);

  return sparql_str;
}
;

-- Substitute parameter values into AST nodes
create procedure DB.DBA.CYP_SUBSTITUTE_PARAMS (in _clauses any, in _params any)
{
  declare i, j integer;
  declare clause any;
  declare ctype varchar;
  declare result any;

  if (_params is null or length (_params) = 0)
    return _clauses;

  result := vector ();
  for (i := 0; i < length (_clauses); i := i + 1)
    {
      clause := aref (_clauses, i);
      ctype := aref (clause, 0);

      -- Substitute params in WHERE clause expressions
      if (ctype = 'WHERE' and length (clause) > 1)
        {
          clause := vector ('WHERE', DB.DBA.CYP_SUBST_PARAMS_IN_EXPR (aref (clause, 1), _params));
        }

      -- Substitute params in RETURN clause items
      if (ctype = 'RETURN' and length (clause) > 2)
        {
          declare items, new_items any;
          declare ri integer;
          items := aref (clause, 2);
          new_items := vector ();
          for (ri := 0; ri < length (items); ri := ri + 1)
            {
              declare item any;
              item := aref (items, ri);
              if (length (item) >= 2)
                {
                  declare new_expr any;
                  new_expr := DB.DBA.CYP_SUBST_PARAMS_IN_EXPR (aref (item, 1), _params);
                  if (length (item) = 3)
                    item := vector (aref (item, 0), new_expr, aref (item, 2));
                  else
                    item := vector (aref (item, 0), new_expr);
                }
              new_items := vector_concat (new_items, vector (item));
            }
          clause := vector (aref (clause, 0), aref (clause, 1), new_items);
          if (length (clause) > 3)
            clause := vector_concat (clause, vector (aref (clause, 3)));
          if (length (clause) > 4)
            clause := vector_concat (clause, vector (aref (clause, 4)));
          if (length (clause) > 5)
            clause := vector_concat (clause, vector (aref (clause, 5)));
          if (length (clause) > 6)
            clause := vector_concat (clause, vector (aref (clause, 6)));
        }

      result := vector_concat (result, vector (clause));
    }

  return result;
}
;

-- Recursively substitute parameters in an expression AST
create procedure DB.DBA.CYP_SUBST_PARAMS_IN_EXPR (in _expr any, in _params any)
{
  declare etype varchar;
  declare i integer;
  declare result any;
  declare args any;

  if (_expr is null)
    return null;

  if (not isarray (_expr))
    return _expr;

  etype := aref (_expr, 0);

  -- PARAM node: look up and substitute
  if (etype = 'PARAM')
    {
      declare pname varchar;
      declare pval any;
      pname := aref (_expr, 1);
      pval := DB.DBA.CYP_LOOKUP_PARAM (_params, pname);
      if (pval is not null)
        {
          -- Return appropriate literal node based on value type
          if (isstring (pval))
            return vector ('STR', pval);
          if (isinteger (pval))
            return vector ('INT', pval);
          if (isnumeric (pval))
            return vector ('FLOAT', pval);
          return vector ('LIT', pval);
        }
      -- Param not found - leave as PARAM (will use SPARQL parameter)
      return _expr;
    }

  -- Recursively process sub-expressions
  if (etype = 'FUNC')
    {
      -- Function call: substitute in arguments
      args := aref (_expr, 3);
      result := vector ();
      for (i := 0; i < length (args); i := i + 1)
        result := vector_concat (result, vector (DB.DBA.CYP_SUBST_PARAMS_IN_EXPR (aref (args, i), _params)));
      return vector (aref (_expr, 0), aref (_expr, 1), aref (_expr, 2), result);
    }

  if (etype = 'BINOP')
    {
      -- Binary operation: substitute in both operands
      return vector ('BINOP', aref (_expr, 1),
        DB.DBA.CYP_SUBST_PARAMS_IN_EXPR (aref (_expr, 2), _params),
        DB.DBA.CYP_SUBST_PARAMS_IN_EXPR (aref (_expr, 3), _params));
    }

  if (etype = 'UNOP')
    {
      -- Unary operation: substitute in operand
      return vector ('UNOP', aref (_expr, 1),
        DB.DBA.CYP_SUBST_PARAMS_IN_EXPR (aref (_expr, 2), _params));
    }

  if (etype = 'CASEEXPR')
    {
      -- CASE expression: substitute in operand, whens, and else
      declare operand, whens, else_e any;
      declare new_whens any;
      declare wi integer;

      operand := aref (_expr, 1);
      whens := aref (_expr, 2);
      else_e := aref (_expr, 3);

      new_whens := vector ();
      for (wi := 0; wi < length (whens); wi := wi + 1)
        {
          declare w any;
          w := aref (whens, wi);
          new_whens := vector_concat (new_whens, vector (vector (
            DB.DBA.CYP_SUBST_PARAMS_IN_EXPR (aref (w, 0), _params),
            DB.DBA.CYP_SUBST_PARAMS_IN_EXPR (aref (w, 1), _params))));
        }

      return vector ('CASEEXPR',
        DB.DBA.CYP_SUBST_PARAMS_IN_EXPR (operand, _params),
        new_whens,
        DB.DBA.CYP_SUBST_PARAMS_IN_EXPR (else_e, _params));
    }

  -- For other expression types, return as-is (could add more recursive cases as needed)
  return _expr;
}
;

-- Look up a parameter value by name
create procedure DB.DBA.CYP_LOOKUP_PARAM (in _params any, in _name varchar)
{
  declare i integer;
  declare pname varchar;

  if (_params is null)
    return null;

  for (i := 0; i < length (_params); i := i + 1)
    {
      declare pv any;
      pv := aref (_params, i);
      if (isarray (pv) and length (pv) = 2)
        {
          if (aref (pv, 0) = _name)
            return aref (pv, 1);
        }
    }

  return null;
}
;

-- Generate SPARQL for MATCH patterns
create procedure DB.DBA.CYP_GEN_MATCH (in _match_ast any, inout _ctx any)
{
  declare is_optional integer;
  declare patterns any;
  declare i, j, n integer;
  declare pat any;

  is_optional := aref (_match_ast, 1);
  patterns := aref (_match_ast, 2);
  n := length (patterns);

  for (i := 0; i < n; i := i + 1)
    {
      pat := aref (patterns, i);
      DB.DBA.CYP_GEN_PATTERN (_ctx, pat, is_optional);
    }
}
;

create procedure DB.DBA.CYP_GEN_BLOCK_BODY (in _clauses any, inout _ctx any)
{
  declare i integer;
  declare clause any;
  declare ctype varchar;
  declare wexpr varchar;
  declare item, expr any;
  declare alias_name, expr_str varchar;
  declare ri integer;
  declare binds_str varchar;

  for (i := 0; i < length (_clauses); i := i + 1)
    {
      clause := aref (_clauses, i);
      ctype := aref (clause, 0);
      if (ctype = 'MATCH')
        DB.DBA.CYP_GEN_MATCH (clause, _ctx);
      else if (ctype = 'WHERE')
        {
          wexpr := DB.DBA.CYP_GEN_EXPR (aref (clause, 1), _ctx, 0);
          DB.DBA.CYP_ADD_FILTER (_ctx, wexpr);
        }
      else if (ctype = 'RETURN')
        {
          for (ri := 0; ri < length (aref (clause, 2)); ri := ri + 1)
            {
              item := aref (aref (clause, 2), ri);
              expr := aref (item, 1);
              alias_name := aref (item, 2);
              expr_str := DB.DBA.CYP_GEN_EXPR (expr, _ctx, 0);
              if (alias_name is not null)
                {
                  binds_str := DB.DBA.CYP_CTX_GET (_ctx, 'binds');
                  binds_str := concat (binds_str, '    BIND (', expr_str, ' AS ?', alias_name, ') .\n');
                  DB.DBA.CYP_CTX_SET (_ctx, 'binds', binds_str);
                  DB.DBA.CYP_CTX_ADD_VAR (_ctx, alias_name);
                }
            }
        }
      else if (ctype = 'VALUES')
        DB.DBA.CYP_GEN_VALUES_CLAUSE (_ctx, clause);
      else if (ctype = 'BIND')
        DB.DBA.CYP_GEN_BIND_CLAUSE (_ctx, clause);
      else if (ctype = 'GRAPH')
        DB.DBA.CYP_GEN_GRAPHLIKE_CLAUSE (_ctx, clause, 'GRAPH');
      else if (ctype = 'SERVICE')
        DB.DBA.CYP_GEN_GRAPHLIKE_CLAUSE (_ctx, clause, 'SERVICE');
      else if (ctype = 'MINUS')
        DB.DBA.CYP_GEN_MINUS_CLAUSE (_ctx, clause);
    }
}
;

create procedure DB.DBA.CYP_GEN_VALUES_CLAUSE (inout _ctx any, in _clause any)
{
  declare var_name, binds_str, val_str varchar;
  declare vals any;
  declare i integer;

  var_name := aref (_clause, 1);
  vals := aref (_clause, 2);
  binds_str := DB.DBA.CYP_CTX_GET (_ctx, 'binds');
  binds_str := concat (binds_str, '    VALUES ?', var_name, ' {');
  for (i := 0; i < length (vals); i := i + 1)
    {
      val_str := DB.DBA.CYP_GEN_EXPR (aref (vals, i), _ctx, 0);
      binds_str := concat (binds_str, ' ', val_str);
    }
  binds_str := concat (binds_str, ' }\n');
  DB.DBA.CYP_CTX_SET (_ctx, 'binds', binds_str);
  DB.DBA.CYP_CTX_ADD_VAR (_ctx, var_name);
}
;

create procedure DB.DBA.CYP_GEN_BIND_CLAUSE (inout _ctx any, in _clause any)
{
  declare binds_str varchar;
  binds_str := DB.DBA.CYP_CTX_GET (_ctx, 'binds');
  binds_str := concat (binds_str, '    BIND (',
                       DB.DBA.CYP_GEN_EXPR (aref (_clause, 1), _ctx, 0),
                       ' AS ?', aref (_clause, 2), ') .\n');
  DB.DBA.CYP_CTX_SET (_ctx, 'binds', binds_str);
  DB.DBA.CYP_CTX_ADD_VAR (_ctx, aref (_clause, 2));
}
;

create procedure DB.DBA.CYP_GEN_GRAPHLIKE_CLAUSE (inout _ctx any, in _clause any, in _kw varchar)
{
  declare inner_ctx any;
  declare prefixes any;
  declare target varchar;
  declare graphlike_kw varchar;
  declare body varchar;
  declare triples varchar;
  declare extra_from_graphs any;
  declare inner_prop_vars, outer_prop_vars any;
  declare pv any;
  declare i, j, is_found integer;

  target := DB.DBA.CYP_GEN_GRAPH_TERM (aref (_clause, 1), _ctx);
  graphlike_kw := _kw;
  if (_kw = 'SERVICE' and length (_clause) > 3 and aref (_clause, 3))
    graphlike_kw := 'SERVICE SILENT';
  if (_kw = 'GRAPH')
    {
      extra_from_graphs := DB.DBA.CYP_CTX_GET (_ctx, 'extra_from_graphs');
      extra_from_graphs := vector_concat (extra_from_graphs, vector (vector ('FROM_NAMED', aref (_clause, 1))));
      DB.DBA.CYP_CTX_SET (_ctx, 'extra_from_graphs', extra_from_graphs);
    }
  inner_ctx := DB.DBA.CYP_CTX_NEW (DB.DBA.CYP_CTX_GET (_ctx, 'graph'));
  prefixes := DB.DBA.CYP_CTX_GET (_ctx, 'prefixes');
  DB.DBA.CYP_CTX_SET (inner_ctx, 'prefixes', prefixes);
  DB.DBA.CYP_CTX_SET (inner_ctx, 'base_uri', DB.DBA.CYP_CTX_GET (_ctx, 'base_uri'));
  DB.DBA.CYP_CTX_SET (inner_ctx, 'defines', DB.DBA.CYP_CTX_GET (_ctx, 'defines'));
  DB.DBA.CYP_CTX_SET (inner_ctx, 'reif_graph', DB.DBA.CYP_REIF_GRAPH (_ctx));
  DB.DBA.CYP_CTX_SET (inner_ctx, 'extra_from_graphs', DB.DBA.CYP_CTX_GET (_ctx, 'extra_from_graphs'));
  DB.DBA.CYP_CTX_SET (inner_ctx, 'var_counter', DB.DBA.CYP_CTX_GET (_ctx, 'var_counter'));
  if (_kw = 'SERVICE')
    {
      DB.DBA.CYP_CTX_SET (inner_ctx, 'strict_prefixed_terms', 1);
      DB.DBA.CYP_CTX_SET (inner_ctx, 'suppress_path_node_existence', 1);
    }
  DB.DBA.CYP_GEN_BLOCK_BODY (aref (_clause, 2), inner_ctx);
  DB.DBA.CYP_CTX_SET (_ctx, 'var_counter', DB.DBA.CYP_CTX_GET (inner_ctx, 'var_counter'));

  body := DB.DBA.CYP_CTX_GET (inner_ctx, 'triples');
  body := concat (body, DB.DBA.CYP_CTX_GET (inner_ctx, 'binds'));
  body := concat (body, DB.DBA.CYP_CTX_GET (inner_ctx, 'optionals'));
  body := concat (body, DB.DBA.CYP_CTX_GET (inner_ctx, 'filters'));

  triples := DB.DBA.CYP_CTX_GET (_ctx, 'triples');
  triples := concat (triples, '    ', graphlike_kw, ' ', target, ' {\n', body, '    } .\n');
  DB.DBA.CYP_CTX_SET (_ctx, 'triples', triples);

  for (i := 0; i < length (DB.DBA.CYP_CTX_GET (inner_ctx, 'vars')); i := i + 1)
    DB.DBA.CYP_CTX_ADD_VAR (_ctx, aref (DB.DBA.CYP_CTX_GET (inner_ctx, 'vars'), i));

  inner_prop_vars := DB.DBA.CYP_CTX_GET (inner_ctx, 'prop_vars');
  outer_prop_vars := DB.DBA.CYP_CTX_GET (_ctx, 'prop_vars');
  for (i := 0; i < length (inner_prop_vars); i := i + 1)
    {
      pv := aref (inner_prop_vars, i);
      is_found := 0;
      for (j := 0; j < length (outer_prop_vars); j := j + 1)
        {
          if (aref (aref (outer_prop_vars, j), 0) = aref (pv, 0)
              and aref (aref (outer_prop_vars, j), 1) = aref (pv, 1))
            {
              is_found := 1;
              goto next_prop_var;
            }
        }
      next_prop_var:
      if (not is_found)
        outer_prop_vars := vector_concat (outer_prop_vars, vector (pv));
    }
  DB.DBA.CYP_CTX_SET (_ctx, 'prop_vars', outer_prop_vars);
}
;

create procedure DB.DBA.CYP_GEN_MINUS_CLAUSE (inout _ctx any, in _clause any)
{
  declare inner_ctx any;
  declare prefixes any;
  declare body varchar;
  declare triples varchar;

  inner_ctx := DB.DBA.CYP_CTX_NEW (DB.DBA.CYP_CTX_GET (_ctx, 'graph'));
  prefixes := DB.DBA.CYP_CTX_GET (_ctx, 'prefixes');
  DB.DBA.CYP_CTX_SET (inner_ctx, 'prefixes', prefixes);
  DB.DBA.CYP_CTX_SET (inner_ctx, 'base_uri', DB.DBA.CYP_CTX_GET (_ctx, 'base_uri'));
  DB.DBA.CYP_GEN_BLOCK_BODY (aref (_clause, 1), inner_ctx);

  body := DB.DBA.CYP_CTX_GET (inner_ctx, 'triples');
  body := concat (body, DB.DBA.CYP_CTX_GET (inner_ctx, 'binds'));
  body := concat (body, DB.DBA.CYP_CTX_GET (inner_ctx, 'optionals'));
  body := concat (body, DB.DBA.CYP_CTX_GET (inner_ctx, 'filters'));

  triples := DB.DBA.CYP_CTX_GET (_ctx, 'triples');
  triples := concat (triples, '    MINUS {\n', body, '    } .\n');
  DB.DBA.CYP_CTX_SET (_ctx, 'triples', triples);
}
;

create procedure DB.DBA.CYP_REL_TERM_FOR_PATH (inout _ctx any, in _rel any)
{
  declare var_name varchar;
  declare types, props any;

  var_name := aref (_rel, 1);
  types := aref (_rel, 2);
  props := aref (_rel, 6);

  if (var_name is not null)
    return concat ('?', var_name);
  if (length (props) > 0)
    return null;
  if (length (types) = 1)
    return DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_REL_TYPE_URI (_ctx, aref (types, 0)));
  return null;
}
;

create procedure DB.DBA.CYP_REGISTER_PATH_VAR (inout _ctx any, in _path_name varchar, in _pat any)
{
  declare elements, elem, rel any;
  declare i, n, hop_count, has_varlen integer;
  declare node_terms, rel_terms any;
  declare node_var, rel_term varchar;

  if (_path_name is null)
    return;
  if (aref (_pat, 0) <> 'PATTERN')
    signal ('CY091', 'Path variable must bind a path pattern');

  elements := aref (_pat, 1);
  n := length (elements);
  node_terms := vector ();
  rel_terms := vector ();
  hop_count := 0;
  has_varlen := 0;

  for (i := 0; i < n; i := i + 1)
    {
      elem := aref (elements, i);
      if (aref (elem, 0) = 'NODE')
        {
          node_var := aref (elem, 1);
          if (node_var is null)
            node_terms := vector_concat (node_terms, vector (null));
          else
            node_terms := vector_concat (node_terms, vector (concat ('?', node_var)));
        }
      else if (aref (elem, 0) = 'REL')
        {
          rel := elem;
          hop_count := hop_count + 1;
          if (aref (rel, 4) is not null)
            has_varlen := 1;
          rel_term := DB.DBA.CYP_REL_TERM_FOR_PATH (_ctx, rel);
          rel_terms := vector_concat (rel_terms, vector (rel_term));
        }
    }

  DB.DBA.CYP_CTX_ADD_PATH_VAR (_ctx, _path_name, hop_count, node_terms, rel_terms, has_varlen);
  DB.DBA.CYP_CTX_ADD_VAR (_ctx, _path_name);
}
;

-- Generate triples for a pattern (node-rel-node chain)
create procedure DB.DBA.CYP_GEN_PATTERN (inout _ctx any, in _pat any, in _optional integer)
{
  declare pat_type varchar;
  declare elements any;
  declare i, n integer;
  declare elem any;
  declare prev_node, next_node any;
  declare path_mode, old_path_mode integer;

  pat_type := aref (_pat, 0);

  if (pat_type = 'PATHVAR')
    {
      DB.DBA.CYP_REGISTER_PATH_VAR (_ctx, aref (_pat, 1), aref (_pat, 2));
      DB.DBA.CYP_GEN_PATTERN (_ctx, aref (_pat, 2), _optional);
      return;
    }

  if (pat_type <> 'PATTERN')
    signal ('CY022', sprintf ('Expected PATTERN node, got %s', pat_type));

  elements := aref (_pat, 1);
  n := length (elements);

  old_path_mode := DB.DBA.CYP_CTX_GET (_ctx, 'in_path_pattern');
  path_mode := 0;
  if (DB.DBA.CYP_CTX_GET (_ctx, 'suppress_path_node_existence') and DB.DBA.CYP_PATTERN_HAS_REL (_pat))
    {
      path_mode := 1;
      DB.DBA.CYP_CTX_SET (_ctx, 'in_path_pattern', 1);
      DB.DBA.CYP_PATTERN_EXPR_SEED_NODE_VARS (_ctx, _pat);
    }

  -- Process elements: node, rel, node, rel, node, ...
  for (i := 0; i < n; i := i + 1)
    {
      elem := aref (elements, i);

      if (aref (elem, 0) = 'NODE')
        DB.DBA.CYP_GEN_NODE_PATTERN (_ctx, elem, _optional);
      else if (aref (elem, 0) = 'REL')
        {
          -- Relationship connects previous node to next node
          if (i = 0 or i >= n - 1)
            signal ('CY023', 'Relationship must be between two nodes');
          prev_node := aref (elements, i - 1);
          next_node := aref (elements, i + 1);
          DB.DBA.CYP_GEN_REL_PATTERN (_ctx, elem, prev_node, next_node, _optional);
        }
    }

  if (path_mode)
    DB.DBA.CYP_CTX_SET (_ctx, 'in_path_pattern', old_path_mode);
}
;

-- Build a SPARQL FILTER expression from a label expression AST, using
-- _classvar (e.g. '?n_class') as the bound rdf:type for the node.
-- Returns null for the wildcard '%' (no constraint, just binding).
create procedure DB.DBA.CYP_GEN_LBLEXPR_FILTER (inout _ctx any, in _expr any, in _classvar varchar)
{
  declare kind varchar;
  declare l, r varchar;
  declare uri varchar;
  if (not isarray (_expr) or aref (_expr, 0) <> 'LBLEXPR')
    signal ('CY031', 'CYP_GEN_LBLEXPR_FILTER: not a LBLEXPR');
  kind := aref (_expr, 1);
  if (kind = 'WILD')
    return null;
  if (kind = 'NAME')
    {
      uri := DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_LABEL_URI (_ctx, aref (_expr, 2)));
      return concat (_classvar, ' = ', uri);
    }
  if (kind = 'NOT')
    {
      l := DB.DBA.CYP_GEN_LBLEXPR_FILTER (_ctx, aref (_expr, 2), _classvar);
      if (l is null)
        return '0=1';  -- !% : no class would satisfy
      return concat ('!(', l, ')');
    }
  if (kind = 'AND')
    {
      l := DB.DBA.CYP_GEN_LBLEXPR_FILTER (_ctx, aref (_expr, 2), _classvar);
      r := DB.DBA.CYP_GEN_LBLEXPR_FILTER (_ctx, aref (_expr, 3), _classvar);
      if (l is null) return r;
      if (r is null) return l;
      return concat ('(', l, ') && (', r, ')');
    }
  if (kind = 'OR')
    {
      l := DB.DBA.CYP_GEN_LBLEXPR_FILTER (_ctx, aref (_expr, 2), _classvar);
      r := DB.DBA.CYP_GEN_LBLEXPR_FILTER (_ctx, aref (_expr, 3), _classvar);
      if (l is null or r is null)
        return null;  -- WILD subsumes
      return concat ('(', l, ') || (', r, ')');
    }
  signal ('CY031', concat ('CYP_GEN_LBLEXPR_FILTER: unknown kind ', kind));
}
;

-- Detect AST form for label expression (mirror of parser predicate).
create procedure DB.DBA.CYP_LBLEXPR_IS_AST_T (in _labels any)
{
  declare first any;
  if (not isarray (_labels) or length (_labels) <> 1)
    return 0;
  first := aref (_labels, 0);
  if (not isarray (first) or length (first) < 2)
    return 0;
  if (aref (first, 0) = 'LBLEXPR')
    return 1;
  return 0;
}
;

-- Generate triples for a node pattern
create procedure DB.DBA.CYP_GEN_NODE_PATTERN (inout _ctx any, in _node any, in _optional integer)
{
  declare var_name varchar;
  declare labels, props any;
  declare i, n integer;
  declare vars any;
  declare prop any;
  declare pname, pvar varchar;
  declare pval any;
  declare any_pred, any_obj varchar;
  declare was_known integer;

  var_name := aref (_node, 1);
  labels := aref (_node, 2);
  props := aref (_node, 3);

  if (var_name is null)
    var_name := DB.DBA.CYP_FRESH_VAR (_ctx);

  was_known := DB.DBA.CYP_CTX_HAS_VAR (_ctx, var_name);

  -- Register variable
  vars := DB.DBA.CYP_CTX_GET (_ctx, 'vars');
  if (not was_known)
    {
      vars := vector_concat (vars, vector (var_name));
      DB.DBA.CYP_CTX_SET (_ctx, 'vars', vars);
    }

  -- Labels -> rdf:type assertions. RDF-native matches do not require the
  -- openCypher internal node marker when an explicit class/label is present.
  if (DB.DBA.CYP_LBLEXPR_IS_AST_T (labels))
    {
      declare class_var varchar;
      declare flt varchar;
      class_var := concat ('?', DB.DBA.CYP_FRESH_VAR (_ctx), '_class');
      DB.DBA.CYP_ADD_TRIPLE (_ctx, concat ('?', var_name), 'a', class_var);
      flt := DB.DBA.CYP_GEN_LBLEXPR_FILTER (_ctx, aref (labels, 0), class_var);
      if (flt is not null)
        DB.DBA.CYP_ADD_FILTER (_ctx, flt);
    }
  else
    {
      n := length (labels);
      if (n = 0 and length (props) = 0 and not was_known
          and not (DB.DBA.CYP_CTX_GET (_ctx, 'suppress_path_node_existence')
                   and DB.DBA.CYP_CTX_GET (_ctx, 'in_path_pattern')))
        {
          any_pred := concat ('?', DB.DBA.CYP_FRESH_VAR (_ctx), '_p');
          any_obj := concat ('?', DB.DBA.CYP_FRESH_VAR (_ctx), '_o');
          DB.DBA.CYP_ADD_TRIPLE (_ctx, concat ('?', var_name), any_pred, any_obj);
        }
      else if (n = 0)
        {
          -- Property-only node patterns are already constrained below.
          ;
        }
      else
        {
          for (i := 0; i < n; i := i + 1)
            {
              DB.DBA.CYP_ADD_TRIPLE (_ctx, concat ('?', var_name), 'a',
                                     DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_LABEL_URI (_ctx, aref (labels, i))));
            }
        }
    }

  -- Inline properties -> value constraints via FILTER
  n := length (props);
  for (i := 0; i < n; i := i + 1)
    {
      prop := aref (props, i);
      pname := aref (prop, 0);
      pval := aref (prop, 1);
      pvar := DB.DBA.CYP_PROP_SPARQL_VAR (_ctx, var_name, pname, 0);
      DB.DBA.CYP_ADD_FILTER (_ctx, concat (pvar, ' = ', DB.DBA.CYP_GEN_EXPR (pval, _ctx, 0)));
    }
}
;

-- Generate triples for a relationship pattern
create procedure DB.DBA.CYP_GEN_REL_PATTERN (inout _ctx any, in _rel any, in _prev_node any, in _next_node any, in _optional integer)
{
  declare var_name, direction varchar;
  declare types, props any;
  declare min_hops, max_hops any;
  declare src_var, dst_var varchar;
  declare i, n integer;
  declare pred_var varchar;
  declare fv varchar;
  declare pred_uri varchar;
  declare values_list varchar;
  declare binds_str varchar;
  declare stmt_var varchar;
  declare prop any;
  declare pvar varchar;
  declare actual_src_var, actual_dst_var varchar;
  declare rel_pred_term varchar;
  declare rel_triples varchar;

  var_name := aref (_rel, 1);
  types := aref (_rel, 2);
  direction := aref (_rel, 3);
  min_hops := aref (_rel, 4);
  max_hops := aref (_rel, 5);
  props := aref (_rel, 6);

  -- Determine source and destination based on direction
  src_var := aref (_prev_node, 1);
  dst_var := aref (_next_node, 1);
  if (src_var is null) src_var := DB.DBA.CYP_FRESH_VAR (_ctx);
  if (dst_var is null) dst_var := DB.DBA.CYP_FRESH_VAR (_ctx);
  if (direction = 'LEFT')
    { actual_src_var := dst_var; actual_dst_var := src_var; }
  else
    { actual_src_var := src_var; actual_dst_var := dst_var; }
  rel_pred_term := null;

  -- Variable-length paths use SPARQL property paths
  if (min_hops is not null)
    {
      DB.DBA.CYP_GEN_VAR_LENGTH_REL (_ctx, types, direction, src_var, dst_var, min_hops, max_hops);
      return;
    }

  -- Simple relationship: direct triple
  n := length (types);
  if (n = 0)
    {
      -- Untyped relationship: use a variable for the predicate
      if (var_name is not null)
        pred_var := concat ('?', var_name, '_type');
      else
        pred_var := concat ('?', DB.DBA.CYP_FRESH_VAR (_ctx), '_type');

      if (direction = 'LEFT')
        DB.DBA.CYP_ADD_TRIPLE (_ctx, concat ('?', dst_var), pred_var, concat ('?', src_var));
      else if (direction = 'RIGHT')
        DB.DBA.CYP_ADD_TRIPLE (_ctx, concat ('?', src_var), pred_var, concat ('?', dst_var));
      else  -- BOTH/NONE - bidirectional
        {
          fv := DB.DBA.CYP_FRESH_VAR (_ctx);
          -- Use UNION for bidirectional (simplified: just add both patterns)
          DB.DBA.CYP_ADD_TRIPLE (_ctx, concat ('?', src_var), pred_var, concat ('?', dst_var));
        }
      rel_pred_term := pred_var;
    }
  else if (n = 1)
    {
      pred_uri := DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_REL_TYPE_URI (_ctx, aref (types, 0)));
      if (direction = 'LEFT')
        DB.DBA.CYP_ADD_TRIPLE (_ctx, concat ('?', dst_var), pred_uri, concat ('?', src_var));
      else if (direction = 'RIGHT')
        DB.DBA.CYP_ADD_TRIPLE (_ctx, concat ('?', src_var), pred_uri, concat ('?', dst_var));
      else
        DB.DBA.CYP_ADD_TRIPLE (_ctx, concat ('?', src_var), pred_uri, concat ('?', dst_var));
      rel_pred_term := pred_uri;
    }
  else
    {
      -- Multiple types: use VALUES clause for predicate
      pred_var := concat ('?', DB.DBA.CYP_FRESH_VAR (_ctx), '_reltype');
      values_list := '';
      for (i := 0; i < n; i := i + 1)
        values_list := concat (values_list, ' ', DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_REL_TYPE_URI (_ctx, aref (types, i))));

      binds_str := DB.DBA.CYP_CTX_GET (_ctx, 'binds');
      binds_str := concat (binds_str, '    VALUES ', pred_var, ' { ', values_list, ' }\n');
      DB.DBA.CYP_CTX_SET (_ctx, 'binds', binds_str);

      if (direction = 'LEFT')
        DB.DBA.CYP_ADD_TRIPLE (_ctx, concat ('?', dst_var), pred_var, concat ('?', src_var));
      else
        DB.DBA.CYP_ADD_TRIPLE (_ctx, concat ('?', src_var), pred_var, concat ('?', dst_var));
      rel_pred_term := pred_var;
    }

  -- Handle relationship variables/properties via reification.
  if (var_name is not null or length (props) > 0)
    {
      -- Reification: relationship becomes a statement node
      if (var_name is not null)
        {
          stmt_var := concat ('?', var_name);
          DB.DBA.CYP_CTX_ADD_REL_VAR (_ctx, var_name);
        }
      else
        stmt_var := concat ('?', DB.DBA.CYP_FRESH_VAR (_ctx));

      rel_triples := DB.DBA.CYP_CTX_GET (_ctx, 'triples');
      rel_triples := concat (rel_triples, '    GRAPH ', DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_REIF_GRAPH (_ctx)), ' {\n');
      rel_triples := concat (rel_triples, '      ', stmt_var, ' a <http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement> .\n');
      rel_triples := concat (rel_triples, '      ', stmt_var, ' <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> ?', actual_src_var, ' .\n');
      rel_triples := concat (rel_triples, '      ', stmt_var, ' <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> ', rel_pred_term, ' .\n');
      rel_triples := concat (rel_triples, '      ', stmt_var, ' <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> ?', actual_dst_var, ' .\n');
      for (i := 0; i < length (props); i := i + 1)
        {
          prop := aref (props, i);
          pvar := concat ('?', DB.DBA.CYP_FRESH_VAR (_ctx), '_relprop');
          rel_triples := concat (rel_triples, '      ', stmt_var, ' ',
                                 DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_PROP_URI (_ctx, aref (prop, 0))), ' ',
                                 pvar, ' .\n');
          DB.DBA.CYP_ADD_FILTER (_ctx, concat (pvar, ' = ', DB.DBA.CYP_GEN_EXPR (aref (prop, 1), _ctx, 0)));
        }
      rel_triples := concat (rel_triples, '    } .\n');
      DB.DBA.CYP_CTX_SET (_ctx, 'triples', rel_triples);
    }
}
;

-- Generate variable-length path pattern using SPARQL property paths
create procedure DB.DBA.CYP_GEN_VAR_LENGTH_REL (inout _ctx any, in _types any, in _direction varchar,
                                                  in _src varchar, in _dst varchar,
                                                  in _min integer, in _max integer)
{
  declare pred, path_expr varchar;
  declare i integer;

  if (length (_types) = 0)
    pred := DB.DBA.OPENCYPHER_FMT_URI (concat (DB.DBA.OPENCYPHER_NS (), '_rel'));
  else if (length (_types) = 1)
    pred := DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_REL_TYPE_URI (_ctx, aref (_types, 0)));
  else
    {
      pred := '(';
      for (i := 0; i < length (_types); i := i + 1)
        {
          if (i > 0) pred := concat (pred, '|');
          pred := concat (pred, DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_REL_TYPE_URI (_ctx, aref (_types, i))));
        }
      pred := concat (pred, ')');
    }

  -- Build property path quantifier. Prefer standard SPARQL operators for
  -- the common unbounded cases and keep Virtuoso bounded path syntax for
  -- explicit openCypher bounds.
  if (_min = 0 and _max = -1)
    path_expr := concat (pred, '*');
  else if (_min = 1 and _max = -1)
    path_expr := concat (pred, '+');
  else if (_min = 0 and _max = 1)
    path_expr := concat (pred, '?');
  else if (_min = _max and _min > 0)
    path_expr := concat (pred, '{', cast (_min as varchar), '}');
  else if (_max = -1)
    path_expr := concat (pred, '{', cast (_min as varchar), ',}');
  else
    path_expr := concat (pred, '{', cast (_min as varchar), ',', cast (_max as varchar), '}');

  if (_direction = 'LEFT')
    DB.DBA.CYP_ADD_TRIPLE (_ctx, concat ('?', _dst), concat ('^', path_expr), concat ('?', _src));
  else
    DB.DBA.CYP_ADD_TRIPLE (_ctx, concat ('?', _src), path_expr, concat ('?', _dst));
}
;

-- Generate expression as SPARQL string
create procedure DB.DBA.CYP_GEN_EXPR (in _expr any, inout _ctx any, in _optional integer)
{
  declare etype varchar;
  declare v any;
  declare base_expr any;
  declare lhs_expr, rhs_expr any;
  declare prop_name varchar;
  declare op, left_s, right_s varchar;
  declare operand_s varchar;
  declare list_s varchar;
  declare fname varchar;
  declare is_dist integer;
  declare args any;
  declare arg0_expr any;
  declare args_str varchar;
  declare fi integer;
  declare elems any;
  declare list_str varchar;
  declare li integer;
  declare case_str varchar;
  declare operand, whens, else_e any;
  declare ci integer;
  declare w any;

  if (_expr is null)
    return 'UNDEF';
  if (isstring (_expr))
    return _expr;
  if (not isarray (_expr))
    return cast (_expr as varchar);

  etype := aref (_expr, 0);

  if (etype = 'LIT_BOOL')
    {
      -- Cypher TRUE / FALSE lower to the SPARQL boolean keywords so
      -- toBoolean / toString and direct boolean comparisons see an
      -- xsd:boolean rather than an integer 0/1.
      if (aref (_expr, 1) = 1) return 'true';
      return 'false';
    }

  if (etype = 'LIT')
    {
      v := aref (_expr, 1);
      -- The Cypher null literal must lower to a SPARQL expression that
      -- evaluates to unbound so functions and operators propagate null
      -- per openCypher.  COALESCE() with no arguments yields an unbound
      -- value in SPARQL 1.1, which is preserved by the standard
      -- builtins (LCASE, SUBSTR, ABS, bif:sqrt, etc.).
      if (v is null) return 'COALESCE()';
      if (isstring (v)) return DB.DBA.OPENCYPHER_FMT_LITERAL (v);
      if (isinteger (v)) return cast (v as varchar);
      return cast (v as varchar);
    }

  if (etype = 'FLOAT')
    return aref (_expr, 1);

  if (etype = 'VAR')
    return concat ('?', aref (_expr, 1));

  if (etype = 'PROP')
    {
      base_expr := aref (_expr, 1);
      base_expr := DB.DBA.CYP_EXPR_RESOLVE_BINDING (base_expr, _ctx);
      prop_name := aref (_expr, 2);
      if (aref (base_expr, 0) = 'VAR')
        return DB.DBA.CYP_PROP_SPARQL_VAR (_ctx, aref (base_expr, 1), prop_name, _optional);
      if (aref (base_expr, 0) = 'MAP')
        return sprintf ('sql:CYP_MAP_GET(%s, %s)',
          DB.DBA.CYP_GEN_MAP_CELL_EXPR (base_expr, _ctx, _optional),
          DB.DBA.OPENCYPHER_FMT_LITERAL (prop_name));
      -- Nested property access
      return concat (DB.DBA.CYP_GEN_EXPR (base_expr, _ctx, _optional), '_', prop_name);
    }

  if (etype = 'BINOP')
    {
      op := aref (_expr, 1);
      if (op = '[]'
          and isarray (DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_expr, 2), _ctx))
          and aref (DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_expr, 2), _ctx), 0) = 'MAP'
          and isarray (DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_expr, 3), _ctx))
          and aref (DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_expr, 3), _ctx), 0) = 'LIT'
          and isstring (aref (DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_expr, 3), _ctx), 1)))
        return sprintf ('sql:CYP_MAP_GET(%s, %s)',
          DB.DBA.CYP_GEN_MAP_CELL_EXPR (DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_expr, 2), _ctx), _ctx, _optional),
          DB.DBA.CYP_GEN_EXPR (DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_expr, 3), _ctx), _ctx, _optional));
      -- Dynamic map access: literal-source map with non-literal-string key.
      -- Lower to a MAP helper lookup; falls back to NULL if no match.
      if (op = '[]'
          and isarray (DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_expr, 2), _ctx))
          and aref (DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_expr, 2), _ctx), 0) = 'MAP')
        {
          return sprintf ('sql:CYP_MAP_GET(%s, %s)',
            DB.DBA.CYP_GEN_MAP_CELL_EXPR (DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_expr, 2), _ctx), _ctx, _optional),
            DB.DBA.CYP_GEN_EXPR (DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_expr, 3), _ctx), _ctx, _optional));
        }
      if (op = '[]'
          and isarray (aref (_expr, 2))
          and aref (aref (_expr, 2), 0) = 'VAR'
          and not (isarray (DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_expr, 3), _ctx))
                   and aref (DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_expr, 3), _ctx), 0) = 'LIT'
                   and isinteger (aref (DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_expr, 3), _ctx), 1))))
        {
          declare dyn_var, dyn_pred, dyn_key varchar;
          dyn_var := concat ('?', DB.DBA.CYP_FRESH_VAR (_ctx), '_dyn');
          dyn_pred := concat ('?', DB.DBA.CYP_FRESH_VAR (_ctx), '_pred');
          dyn_key := DB.DBA.CYP_GEN_EXPR (DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_expr, 3), _ctx), _ctx, _optional);
          DB.DBA.CYP_ADD_TRIPLE (_ctx, concat ('?', aref (aref (_expr, 2), 1)), dyn_pred, dyn_var);
          DB.DBA.CYP_ADD_FILTER (_ctx, sprintf ('%s = IRI(CONCAT("%s", STR(%s)))',
                                                dyn_pred, DB.DBA.OPENCYPHER_NS (), dyn_key));
          return dyn_var;
        }
      lhs_expr := DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_expr, 2), _ctx);
      rhs_expr := DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_expr, 3), _ctx);
      left_s := DB.DBA.CYP_GEN_EXPR (lhs_expr, _ctx, _optional);
      right_s := DB.DBA.CYP_GEN_EXPR (rhs_expr, _ctx, _optional);
      if (op = '+'
          and ((isarray (lhs_expr) and aref (lhs_expr, 0) = 'LIST')
               or (isarray (rhs_expr) and aref (rhs_expr, 0) = 'LIST')))
        return sprintf ('sql:CYP_LIST_TO_VECTOR(sql:CYP_LIST_CONCAT(%s, %s))',
          DB.DBA.CYP_GEN_LIST_CELL_EXPR (lhs_expr, _ctx, _optional),
          DB.DBA.CYP_GEN_LIST_CELL_EXPR (rhs_expr, _ctx, _optional));
      -- List element access: list[index] -> CYP_LIST_GET(LIST, index)
      if (op = '[]' and isarray (lhs_expr) and aref (lhs_expr, 0) = 'LIST')
        return sprintf ('sql:CYP_LIST_GET(%s, %s)',
          DB.DBA.CYP_GEN_LIST_CELL_EXPR (lhs_expr, _ctx, _optional),
          right_s);
      if (op = '[]')
        return sprintf ('bif:aref(%s, %s)', left_s, right_s);
      -- openCypher null propagation: comparing NULL to anything yields NULL,
      -- not false.  SPARQL =/<>/<,<=,>,>= on an unbound operand raise an
      -- error which is coerced to false in EBV context, so when the AST
      -- shows a literal NULL on either side we short-circuit to unbound.
      if ((op = '=' or op = '<>' or op = '!='
           or op = '<' or op = '<=' or op = '>' or op = '>=')
          and ((isarray (aref (_expr, 2)) and aref (aref (_expr, 2), 0) = 'LIT'
                and aref (aref (_expr, 2), 1) is null)
               or (isarray (aref (_expr, 3)) and aref (aref (_expr, 3), 0) = 'LIT'
                   and aref (aref (_expr, 3), 1) is null)))
        return 'COALESCE()';
      if (op = '<>')
        op := '!=';
      return sprintf ('(%s %s %s)', left_s, op, right_s);
    }

  if (etype = 'SLICE')
    {
      declare slice_base, slice_start, slice_end varchar;
      lhs_expr := DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_expr, 1), _ctx);
      slice_base := DB.DBA.CYP_GEN_EXPR (lhs_expr, _ctx, _optional);
      if (aref (_expr, 2) is null) slice_start := 'NULL';
      else slice_start := DB.DBA.CYP_GEN_EXPR (aref (_expr, 2), _ctx, _optional);
      if (aref (_expr, 3) is null) slice_end := 'NULL';
      else slice_end := DB.DBA.CYP_GEN_EXPR (aref (_expr, 3), _ctx, _optional);
      if (isarray (lhs_expr) and aref (lhs_expr, 0) = 'LIST')
        return sprintf ('sql:CYP_LIST_TO_VECTOR(sql:CYP_LIST_SLICE(%s, %s, %s))',
          DB.DBA.CYP_GEN_LIST_CELL_EXPR (lhs_expr, _ctx, _optional),
          slice_start,
          slice_end);
      if (aref (_expr, 2) is null) slice_start := '0';
      if (aref (_expr, 3) is null) slice_end := sprintf ('bif:length(%s)', slice_base);
      return sprintf ('bif:subseq(%s, %s, %s)', slice_base, slice_start, slice_end);
    }

  if (etype = 'UNOP')
    {
      op := aref (_expr, 1);
      operand_s := DB.DBA.CYP_GEN_EXPR (aref (_expr, 2), _ctx, _optional);
      if (op = 'NOT') return sprintf ('(!(%s))', operand_s);
      if (op = '-') return sprintf ('(-%s)', operand_s);
      return sprintf ('(%s %s)', op, operand_s);
    }

  if (etype = 'ISNULL')
    {
      operand_s := DB.DBA.CYP_GEN_EXPR (aref (_expr, 1), _ctx, _optional);
      if (aref (_expr, 2) = 1)  -- IS NOT NULL
        return sprintf ('BOUND(%s)', operand_s);
      return sprintf ('(!BOUND(%s))', operand_s);
    }

  if (etype = 'ISLABEL')
    {
      declare lbl_class_var varchar;
      declare lbl_filter varchar;
      declare lbl_node varchar;
      lbl_node := DB.DBA.CYP_GEN_EXPR (aref (_expr, 1), _ctx, _optional);
      lbl_class_var := concat ('?', DB.DBA.CYP_FRESH_VAR (_ctx), '_lbl');
      lbl_filter := DB.DBA.CYP_GEN_LBLEXPR_FILTER (_ctx, aref (_expr, 2), lbl_class_var);
      if (lbl_filter is null)
        return sprintf ('EXISTS { %s a %s }', lbl_node, lbl_class_var);
      return sprintf ('EXISTS { %s a %s . FILTER (%s) }', lbl_node, lbl_class_var, lbl_filter);
    }

  if (etype = 'INEXPR')
    {
      -- openCypher: NULL IN [...] propagates as NULL.
      if (isarray (aref (_expr, 1)) and aref (aref (_expr, 1), 0) = 'LIT'
          and aref (aref (_expr, 1), 1) is null)
        return 'COALESCE()';
      operand_s := DB.DBA.CYP_GEN_EXPR (aref (_expr, 1), _ctx, _optional);
      if (isarray (aref (_expr, 2)) and aref (aref (_expr, 2), 0) = 'LIST')
        {
          elems := aref (aref (_expr, 2), 1);
          list_s := '';
          for (li := 0; li < length (elems); li := li + 1)
            {
              if (li > 0) list_s := concat (list_s, ', ');
              list_s := concat (list_s, DB.DBA.CYP_GEN_EXPR (aref (elems, li), _ctx, _optional));
            }
        }
      else
        list_s := DB.DBA.CYP_GEN_EXPR (aref (_expr, 2), _ctx, _optional);
      return sprintf ('(%s IN (%s))', operand_s, list_s);
    }

  if (etype = 'STROP')
    {
      op := aref (_expr, 1);
      left_s := DB.DBA.CYP_GEN_EXPR (aref (_expr, 2), _ctx, _optional);
      right_s := DB.DBA.CYP_GEN_EXPR (aref (_expr, 3), _ctx, _optional);
      if (op = 'STARTS WITH') return sprintf ('STRSTARTS(STR(%s), STR(%s))', left_s, right_s);
      if (op = 'ENDS WITH') return sprintf ('STRENDS(STR(%s), STR(%s))', left_s, right_s);
      if (op = 'CONTAINS') return sprintf ('CONTAINS(STR(%s), STR(%s))', left_s, right_s);
    }

  if (etype = 'COUNTSTAR')
    return 'COUNT(*)';

  if (etype = 'FUNC')
    {
      fname := lower (aref (_expr, 1));
      is_dist := aref (_expr, 2);
      args := aref (_expr, 3);

      -- Special handling for GRAPH() function - returns the graph URI of a node
      if (fname = 'graph' and length (args) = 1)
        {
          -- GRAPH(node) -> SPARQL to get the graph containing the node
          -- This uses a subquery to find which graph contains the node variable
          declare node_var varchar;
          node_var := DB.DBA.CYP_GEN_EXPR (aref (args, 0), _ctx, _optional);
          -- Return a SPARQL expression that yields the graph
          return sprintf ('(SELECT ?g WHERE { GRAPH ?g { %s ?p ?o } } LIMIT 1)', node_var);
        }

      args_str := '';
      for (fi := 0; fi < length (args); fi := fi + 1)
        {
          if (fi > 0) args_str := concat (args_str, ', ');
          args_str := concat (args_str, DB.DBA.CYP_GEN_EXPR (aref (args, fi), _ctx, _optional));
        }
      -- Map Cypher functions to SPARQL equivalents
      if (fname = 'degree_centrality' or fname = 'weighted_degree_centrality')
        return DB.DBA.CYP_GEN_DEGREE_CENTRALITY (args, _ctx, _optional);
      if (fname = 'eigenvector_centrality')
        return DB.DBA.CYP_GEN_GRAPH_CENTRALITY_EXPR (args, _ctx, 'eigenvector', _optional);
      if (fname = 'closeness_centrality')
        return DB.DBA.CYP_GEN_GRAPH_CENTRALITY_EXPR (args, _ctx, 'closeness', _optional);
      if (fname = 'betweenness_centrality')
        return DB.DBA.CYP_GEN_GRAPH_CENTRALITY_EXPR (args, _ctx, 'betweenness', _optional);
      return DB.DBA.CYP_MAP_FUNCTION (fname, is_dist, args_str, args, _ctx, _optional);
    }

  if (etype = 'LIST')
    return DB.DBA.CYP_GEN_VECTOR_EXPR (aref (_expr, 1), _ctx, _optional);

  if (etype = 'LISTCOMP')
    return DB.DBA.CYP_GEN_LISTCOMP_EXPR (_expr, _ctx, _optional);

  if (etype = 'MAP')
    return DB.DBA.CYP_GEN_MAP_EXPR (_expr, _ctx, _optional);

  if (etype = 'CASEEXPR')
    {
      operand := aref (_expr, 1);
      whens := aref (_expr, 2);
      else_e := aref (_expr, 3);

      -- Build nested IFs for multiple WHEN clauses
      -- CASE WHEN c1 THEN r1 WHEN c2 THEN r2 ELSE r3 END
      -- -> IF(c1, r1, IF(c2, r2, r3))
      if (length (whens) = 0)
        signal ('CY085', 'CASE expression must have at least one WHEN clause');

      -- Build from inside out: start with ELSE or an unbound variable
      -- (SPARQL has no NULL literal; an unbound variable in expression
      -- position evaluates to unbound, matching Cypher's null result
      -- when no WHEN matches and there is no ELSE).
      if (else_e is not null)
        case_str := DB.DBA.CYP_GEN_EXPR (else_e, _ctx, _optional);
      else
        case_str := concat ('?', DB.DBA.CYP_FRESH_VAR (_ctx), '_caseunb');

      -- Process WHEN clauses in reverse order (right to left for nesting)
      for (ci := length (whens) - 1; ci >= 0; ci := ci - 1)
        {
          w := aref (whens, ci);
          declare cond_str, result_str varchar;
          result_str := DB.DBA.CYP_GEN_EXPR (aref (w, 1), _ctx, _optional);

          if (operand is not null)
            {
              -- Simple CASE: CASE expr WHEN val THEN ...
              -- Condition: operand = val
              declare val_str varchar;
              val_str := DB.DBA.CYP_GEN_EXPR (aref (w, 0), _ctx, _optional);
              cond_str := sprintf ('%s = %s',
                DB.DBA.CYP_GEN_EXPR (operand, _ctx, _optional),
                val_str);
            }
          else
            {
              -- Searched CASE: CASE WHEN cond THEN ...
              cond_str := DB.DBA.CYP_GEN_EXPR (aref (w, 0), _ctx, _optional);
            }

          -- Nest: IF(cond, result, previous)
          case_str := sprintf ('IF(%s, %s, %s)', cond_str, result_str, case_str);
        }

      return case_str;
    }

  if (etype = 'PARAM')
    return concat (chr(36), aref (_expr, 1));

  if (etype = 'PATTERNPRED')
    return sprintf ('EXISTS {\n%s  }', DB.DBA.CYP_PATTERN_EXPR_BODY (_ctx, aref (_expr, 1)));

  if (etype = 'QUANT')
    {
      declare qkind, qvar, qexpr_s varchar;
      declare qlist, qpred, qelems any;
      declare qi integer;
      qkind := aref (_expr, 1);
      qvar := aref (_expr, 2);
      qlist := aref (_expr, 3);
      qpred := aref (_expr, 4);
      qlist := DB.DBA.CYP_EXPR_RESOLVE_BINDING (qlist, _ctx);
      if (not isarray (qlist) or aref (qlist, 0) <> 'LIST')
        return sprintf ('sql:CYP_QUANT_EVAL(''%s'', %s, ''%s'', ''%s'')',
          qkind,
          DB.DBA.CYP_GEN_EXPR (qlist, _ctx, _optional),
          qvar,
          DB.DBA.CYP_GEN_EXPR (qpred, _ctx, _optional));
      qelems := aref (qlist, 1);
      qexpr_s := '';
      if (qkind = 'ALL' and length (qelems) = 0) return 'true';
      if ((qkind = 'ANY' or qkind = 'SINGLE' or qkind = 'NONE') and length (qelems) = 0)
        {
          if (qkind = 'NONE') return 'true';
          return 'false';
        }
      if (qkind = 'SINGLE')
        {
          for (qi := 0; qi < length (qelems); qi := qi + 1)
            {
              if (qi > 0) qexpr_s := concat (qexpr_s, ' + ');
              qexpr_s := concat (qexpr_s, 'IF(',
                                 DB.DBA.CYP_GEN_EXPR (DB.DBA.CYP_EXPR_SUBST_VAR (qpred, qvar, aref (qelems, qi)), _ctx, _optional),
                                 ', 1, 0)');
            }
          return concat ('((', qexpr_s, ') = 1)');
        }
      for (qi := 0; qi < length (qelems); qi := qi + 1)
        {
          if (qi > 0)
            {
              if (qkind = 'ALL') qexpr_s := concat (qexpr_s, ' && ');
              else qexpr_s := concat (qexpr_s, ' || ');
            }
          qexpr_s := concat (qexpr_s, '(',
                             DB.DBA.CYP_GEN_EXPR (DB.DBA.CYP_EXPR_SUBST_VAR (qpred, qvar, aref (qelems, qi)), _ctx, _optional),
                             ')');
        }
      if (qkind = 'NONE') return concat ('!(', qexpr_s, ')');
      return concat ('(', qexpr_s, ')');
    }

  if (etype = 'REDUCEEXPR')
    return DB.DBA.CYP_GEN_REDUCE_EXPR (_expr, _ctx, _optional);

  if (etype = 'IRI')
    {
      declare iri_uri any;
      iri_uri := DB.DBA.CYP_EXPAND_PREFIXED_NAME (_ctx, aref (_expr, 1));
      if (not isstring (iri_uri))
        iri_uri := aref (_expr, 1);
      return DB.DBA.OPENCYPHER_FMT_URI (iri_uri);
    }

  if (etype = 'TYPEDLIT')
    return concat (DB.DBA.OPENCYPHER_FMT_LITERAL (aref (_expr, 1)), '^^',
                   DB.DBA.CYP_GEN_GRAPH_TERM (aref (_expr, 2), _ctx));

  if (etype = 'LANGLIT')
    return concat (DB.DBA.OPENCYPHER_FMT_LITERAL (aref (_expr, 1)), '@', aref (_expr, 2));

  -- Existential subquery: EXISTS { pattern [WHERE expr] } is rendered
  -- as a SPARQL FILTER EXISTS pattern.  Outer-scope variables stay
  -- visible inside the body because SPARQL EXISTS shares the enclosing
  -- variable scope, which matches Cypher correlation semantics.
  if (etype = 'EXISTSSUBQ')
    {
      declare _esq_inner any;
      declare _esq_patterns, _esq_where any;
      declare _esq_body, _esq_filter_expr varchar;
      declare _esq_i integer;

      _esq_patterns := aref (_expr, 1);
      _esq_where := aref (_expr, 2);

      _esq_inner := DB.DBA.CYP_CTX_NEW (DB.DBA.CYP_CTX_GET (_ctx, 'graph'));
      DB.DBA.CYP_CTX_SET (_esq_inner, 'prefixes', DB.DBA.CYP_CTX_GET (_ctx, 'prefixes'));
      DB.DBA.CYP_CTX_SET (_esq_inner, 'base_uri', DB.DBA.CYP_CTX_GET (_ctx, 'base_uri'));
      DB.DBA.CYP_CTX_SET (_esq_inner, 'defines', DB.DBA.CYP_CTX_GET (_ctx, 'defines'));
      DB.DBA.CYP_CTX_SET (_esq_inner, 'reif_graph', DB.DBA.CYP_REIF_GRAPH (_ctx));
      DB.DBA.CYP_CTX_SET (_esq_inner, 'var_counter', DB.DBA.CYP_CTX_GET (_ctx, 'var_counter'));

      for (_esq_i := 0; _esq_i < length (_esq_patterns); _esq_i := _esq_i + 1)
        DB.DBA.CYP_GEN_PATTERN (_esq_inner, aref (_esq_patterns, _esq_i), 0);

      -- Generate any WHERE filter against the inner context first so that
      -- property triples for inner-only variables (e.g. b.age inside
      -- EXISTS { (b:Person) WHERE b.age > 30 }) land in the EXISTS body
      -- rather than leaking into the outer query pattern.  Outer-scope
      -- variables still correlate because property SPARQL variable names
      -- are derived from the Cypher variable name and so match by name.
      _esq_filter_expr := null;
      if (_esq_where is not null)
        _esq_filter_expr := DB.DBA.CYP_GEN_EXPR (_esq_where, _esq_inner, _optional);

      DB.DBA.CYP_CTX_SET (_ctx, 'var_counter', DB.DBA.CYP_CTX_GET (_esq_inner, 'var_counter'));

      _esq_body := DB.DBA.CYP_CTX_GET (_esq_inner, 'triples');
      _esq_body := concat (_esq_body, DB.DBA.CYP_CTX_GET (_esq_inner, 'binds'));
      _esq_body := concat (_esq_body, DB.DBA.CYP_CTX_GET (_esq_inner, 'optionals'));
      _esq_body := concat (_esq_body, DB.DBA.CYP_CTX_GET (_esq_inner, 'filters'));

      if (_esq_filter_expr is not null)
        _esq_body := concat (_esq_body, '      FILTER (', _esq_filter_expr, ')\n');

      -- Wrap the body in the outer query's named graph so the inner
      -- triples match the same dataset that the outer MATCH selected.
      declare _esq_graph varchar;
      _esq_graph := DB.DBA.CYP_CTX_GET (_ctx, 'graph');
      if (_esq_graph is not null)
        return concat ('EXISTS { GRAPH <', _esq_graph, '> { ', _esq_body, ' } }');
      return concat ('EXISTS { ', _esq_body, ' }');
    }

  -- Pattern comprehension: generate SPARQL subquery with VECTOR_AGG
  if (etype = 'PATTERNCOMP')
    {
      declare _pc_pat, _pc_where, _pc_proj any;
      declare _pc_body, _pc_proj_str varchar;
      declare _pc_inner any;
      _pc_pat := aref (_expr, 1);
      _pc_where := aref (_expr, 2);
      _pc_proj := aref (_expr, 3);
      if (_pc_proj is null)
        _pc_proj := vector ('VAR', '');
      _pc_inner := DB.DBA.CYP_CTX_PATTERN_EXPR (_ctx);
      DB.DBA.CYP_PATTERN_EXPR_SEED_NODE_VARS (_pc_inner, _pc_pat);
      DB.DBA.CYP_GEN_PATTERN (_pc_inner, _pc_pat, 0);
      _pc_body := DB.DBA.CYP_CTX_GET (_pc_inner, 'triples');
      _pc_body := concat (_pc_body, DB.DBA.CYP_CTX_GET (_pc_inner, 'binds'));
      _pc_body := concat (_pc_body, DB.DBA.CYP_CTX_GET (_pc_inner, 'optionals'));
      _pc_body := concat (_pc_body, DB.DBA.CYP_CTX_GET (_pc_inner, 'filters'));
      if (_pc_where is not null)
        _pc_body := concat (_pc_body, 'FILTER (', DB.DBA.CYP_GEN_EXPR (_pc_where, _pc_inner, _optional), ')\n');
      _pc_proj_str := DB.DBA.CYP_GEN_EXPR (_pc_proj, _pc_inner, _optional);
      DB.DBA.CYP_CTX_SET (_ctx, 'var_counter', DB.DBA.CYP_CTX_GET (_pc_inner, 'var_counter'));
      return sprintf ('(SELECT sql:VECTOR_AGG(%s) AS ?_pc_result WHERE { %s })',
        _pc_proj_str, _pc_body);
    }

  -- Map projection: n {.prop, alias: expr, *}
  -- Lower to MAP literal; emit with same backend as MAP.
  if (etype = 'MAPPROJ')
    {
      declare mp_src any;
      declare mp_items any;
      declare mp_keys, mp_vals any;
      declare mp_i integer;
      declare mp_item any;
      declare mp_kind varchar;
      declare mp_pvar, mp_ovar varchar;
      mp_src := aref (_expr, 1);
      mp_items := aref (_expr, 2);

      if (length (mp_items) = 1 and aref (aref (mp_items, 0), 0) = 'STAR')
        {
          if (not isarray (mp_src) or aref (mp_src, 0) <> 'VAR')
            signal ('CY091', 'Map projection wildcard (*) requires a node variable source');

          mp_pvar := concat ('?', DB.DBA.CYP_FRESH_VAR (_ctx), '_map_p');
          mp_ovar := concat ('?', DB.DBA.CYP_FRESH_VAR (_ctx), '_map_o');
          DB.DBA.CYP_ADD_TRIPLE (_ctx, concat ('?', aref (mp_src, 1)), mp_pvar, mp_ovar);
          return sprintf ('sql:VECTOR_AGG(bif:vector(STR(%s), %s))', mp_pvar, mp_ovar);
        }

      mp_keys := vector ();
      mp_vals := vector ();
      mp_i := 0;
      while (mp_i < length (mp_items))
        {
          mp_item := aref (mp_items, mp_i);
          mp_kind := aref (mp_item, 0);
          if (mp_kind = 'PROP')
            {
              mp_keys := vector_concat (mp_keys, vector (aref (mp_item, 1)));
              mp_vals := vector_concat (mp_vals,
                vector (vector ('PROP', mp_src, aref (mp_item, 1))));
            }
          else if (mp_kind = 'ALIAS')
            {
              mp_keys := vector_concat (mp_keys, vector (aref (mp_item, 1)));
              mp_vals := vector_concat (mp_vals, vector (aref (mp_item, 2)));
            }
          else if (mp_kind = 'STAR')
            signal ('CY091',
              'Map projection wildcard (*) cannot be mixed with explicit projection items yet');
          else
            signal ('CY088', sprintf ('Unknown map projection item kind: %s', mp_kind));
          mp_i := mp_i + 1;
        }
      return DB.DBA.CYP_GEN_MAP_EXPR (vector ('MAP', mp_keys, mp_vals), _ctx, _optional);
    }

  -- Dynamic property access (Phase 7)
  if (etype = 'DYNPROP')
    signal ('CY089', 'Dynamic property access (n[key]) is not yet implemented in openCypher');

  -- Unknown expression type - explicit error (Phase 7)
  signal ('CY090', sprintf ('Unsupported expression type: %s', etype));
}
;

-- Build a SPARQL temporal expression from a Cypher map literal whose
-- keys are the openCypher temporal component names (year, month, day,
-- hour, minute, second, ...).  Missing date components default to 1
-- (so date({year:2020}) -> "2020-01-01") and missing time components
-- default to 0; this matches the openCypher 2024 component-default
-- contract.  The result is wrapped in the xsd: cast appropriate for
-- the requested kind ('date', 'datetime'/'localdatetime',
-- 'time'/'localtime').
create procedure DB.DBA.CYP_GEN_TEMPORAL_FROM_MAP
  (in _map any, in _kind varchar, inout _ctx any, in _optional integer)
{
  declare year_e, month_e, day_e any;
  declare hour_e, min_e, sec_e any;
  declare zero_e, one_e any;

  zero_e := vector ('LIT', 0);
  one_e := vector ('LIT', 1);

  -- Helper: read a component from the map, default to _fallback when
  -- the key is missing (CYP_MAP_LITERAL_GET returns LIT null in that
  -- case).
  declare component any;
  -- Inline-extract date components.
  year_e := DB.DBA.CYP_MAP_LITERAL_GET (_map, 'year');
  month_e := DB.DBA.CYP_MAP_LITERAL_GET (_map, 'month');
  if (isarray (month_e) and aref (month_e, 0) = 'LIT' and aref (month_e, 1) is null) month_e := one_e;
  day_e := DB.DBA.CYP_MAP_LITERAL_GET (_map, 'day');
  if (isarray (day_e) and aref (day_e, 0) = 'LIT' and aref (day_e, 1) is null) day_e := one_e;

  hour_e := DB.DBA.CYP_MAP_LITERAL_GET (_map, 'hour');
  if (isarray (hour_e) and aref (hour_e, 0) = 'LIT' and aref (hour_e, 1) is null) hour_e := zero_e;
  min_e := DB.DBA.CYP_MAP_LITERAL_GET (_map, 'minute');
  if (isarray (min_e) and aref (min_e, 0) = 'LIT' and aref (min_e, 1) is null) min_e := zero_e;
  sec_e := DB.DBA.CYP_MAP_LITERAL_GET (_map, 'second');
  if (isarray (sec_e) and aref (sec_e, 0) = 'LIT' and aref (sec_e, 1) is null) sec_e := zero_e;

  if (_kind = 'date')
    return sprintf ('xsd:date(bif:sprintf("%%04d-%%02d-%%02d", %s, %s, %s))',
      DB.DBA.CYP_GEN_EXPR (year_e,  _ctx, _optional),
      DB.DBA.CYP_GEN_EXPR (month_e, _ctx, _optional),
      DB.DBA.CYP_GEN_EXPR (day_e,   _ctx, _optional));
  if (_kind = 'datetime' or _kind = 'localdatetime')
    return sprintf (
      'xsd:dateTime(bif:sprintf("%%04d-%%02d-%%02dT%%02d:%%02d:%%02d", %s, %s, %s, %s, %s, %s))',
      DB.DBA.CYP_GEN_EXPR (year_e,  _ctx, _optional),
      DB.DBA.CYP_GEN_EXPR (month_e, _ctx, _optional),
      DB.DBA.CYP_GEN_EXPR (day_e,   _ctx, _optional),
      DB.DBA.CYP_GEN_EXPR (hour_e,  _ctx, _optional),
      DB.DBA.CYP_GEN_EXPR (min_e,   _ctx, _optional),
      DB.DBA.CYP_GEN_EXPR (sec_e,   _ctx, _optional));
  if (_kind = 'time' or _kind = 'localtime')
    return sprintf ('xsd:time(bif:sprintf("%%02d:%%02d:%%02d", %s, %s, %s))',
      DB.DBA.CYP_GEN_EXPR (hour_e, _ctx, _optional),
      DB.DBA.CYP_GEN_EXPR (min_e,  _ctx, _optional),
      DB.DBA.CYP_GEN_EXPR (sec_e,  _ctx, _optional));
  signal ('CY099', sprintf ('Map-form temporal constructor not supported for %s()', _kind));
}
;

create procedure DB.DBA.CYP_GEN_DURATION_FROM_MAP
  (in _map any, inout _ctx any, in _optional integer)
{
  declare years_e, months_e, weeks_e, days_e any;
  declare hours_e, minutes_e, seconds_e any;
  declare zero_e any;

  zero_e := vector ('LIT', 0);

  years_e := DB.DBA.CYP_MAP_LITERAL_GET (_map, 'years');
  if (isarray (years_e) and aref (years_e, 0) = 'LIT' and aref (years_e, 1) is null)
    years_e := DB.DBA.CYP_MAP_LITERAL_GET (_map, 'year');
  if (isarray (years_e) and aref (years_e, 0) = 'LIT' and aref (years_e, 1) is null)
    years_e := zero_e;

  months_e := DB.DBA.CYP_MAP_LITERAL_GET (_map, 'months');
  if (isarray (months_e) and aref (months_e, 0) = 'LIT' and aref (months_e, 1) is null)
    months_e := DB.DBA.CYP_MAP_LITERAL_GET (_map, 'month');
  if (isarray (months_e) and aref (months_e, 0) = 'LIT' and aref (months_e, 1) is null)
    months_e := zero_e;

  weeks_e := DB.DBA.CYP_MAP_LITERAL_GET (_map, 'weeks');
  if (isarray (weeks_e) and aref (weeks_e, 0) = 'LIT' and aref (weeks_e, 1) is null)
    weeks_e := DB.DBA.CYP_MAP_LITERAL_GET (_map, 'week');
  if (isarray (weeks_e) and aref (weeks_e, 0) = 'LIT' and aref (weeks_e, 1) is null)
    weeks_e := zero_e;

  days_e := DB.DBA.CYP_MAP_LITERAL_GET (_map, 'days');
  if (isarray (days_e) and aref (days_e, 0) = 'LIT' and aref (days_e, 1) is null)
    days_e := DB.DBA.CYP_MAP_LITERAL_GET (_map, 'day');
  if (isarray (days_e) and aref (days_e, 0) = 'LIT' and aref (days_e, 1) is null)
    days_e := zero_e;

  hours_e := DB.DBA.CYP_MAP_LITERAL_GET (_map, 'hours');
  if (isarray (hours_e) and aref (hours_e, 0) = 'LIT' and aref (hours_e, 1) is null)
    hours_e := DB.DBA.CYP_MAP_LITERAL_GET (_map, 'hour');
  if (isarray (hours_e) and aref (hours_e, 0) = 'LIT' and aref (hours_e, 1) is null)
    hours_e := zero_e;

  minutes_e := DB.DBA.CYP_MAP_LITERAL_GET (_map, 'minutes');
  if (isarray (minutes_e) and aref (minutes_e, 0) = 'LIT' and aref (minutes_e, 1) is null)
    minutes_e := DB.DBA.CYP_MAP_LITERAL_GET (_map, 'minute');
  if (isarray (minutes_e) and aref (minutes_e, 0) = 'LIT' and aref (minutes_e, 1) is null)
    minutes_e := zero_e;

  seconds_e := DB.DBA.CYP_MAP_LITERAL_GET (_map, 'seconds');
  if (isarray (seconds_e) and aref (seconds_e, 0) = 'LIT' and aref (seconds_e, 1) is null)
    seconds_e := DB.DBA.CYP_MAP_LITERAL_GET (_map, 'second');
  if (isarray (seconds_e) and aref (seconds_e, 0) = 'LIT' and aref (seconds_e, 1) is null)
    seconds_e := zero_e;

  return sprintf (
    'xsd:duration(bif:sprintf("P%%dY%%dM%%dDT%%dH%%dM%%dS", %s, %s, (%s * 7) + %s, %s, %s, %s))',
    DB.DBA.CYP_GEN_EXPR (years_e, _ctx, _optional),
    DB.DBA.CYP_GEN_EXPR (months_e, _ctx, _optional),
    DB.DBA.CYP_GEN_EXPR (weeks_e, _ctx, _optional),
    DB.DBA.CYP_GEN_EXPR (days_e, _ctx, _optional),
    DB.DBA.CYP_GEN_EXPR (hours_e, _ctx, _optional),
    DB.DBA.CYP_GEN_EXPR (minutes_e, _ctx, _optional),
    DB.DBA.CYP_GEN_EXPR (seconds_e, _ctx, _optional));
}
;

-- Map Cypher function names to SPARQL equivalents
create procedure DB.DBA.CYP_MAP_FUNCTION (in _fname varchar, in _is_distinct integer,
                                           in _args_str varchar, in _args any,
                                           inout _ctx any, in _optional integer)
{
  declare dist_kw varchar;
  declare a0 varchar;
  declare arg0_expr any;
  declare path_info, path_nodes, path_rels any;
  declare path_name, vec_s, node_vec_s, rel_vec_s, rel_term, node_term varchar;
  declare pi integer;

  dist_kw := '';
  if (_is_distinct) dist_kw := 'DISTINCT ';

  -- SPARQL extension functions.  These are deliberately limited to the
  -- Virtuoso function namespaces users already expect to call from SPARQL.
  if ((length (_fname) > 4 and subseq (_fname, 0, 4) = 'sql:')
      or (length (_fname) > 4 and subseq (_fname, 0, 4) = 'bif:'))
    {
      if (_is_distinct)
        signal ('CY104', sprintf ('DISTINCT is not supported for extension function %s()', _fname));
      return sprintf ('%s(%s)', _fname, _args_str);
    }

  if ((_fname = 'length' or _fname = 'nodes' or _fname = 'relationships')
      and length (_args) = 1
      and isarray (aref (_args, 0))
      and aref (aref (_args, 0), 0) = 'VAR')
    {
      path_name := aref (aref (_args, 0), 1);
      path_info := DB.DBA.CYP_CTX_GET_PATH_VAR (_ctx, path_name);
      if (path_info is not null)
        {
          if (DB.DBA.CYP_PATH_VAR_HAS_VARLEN (path_info))
            {
              if (_fname = 'length') return '-1';
              if (_fname = 'nodes') return 'bif:vector()';
              return 'bif:vector()';
            }

          if (_fname = 'length')
            return cast (DB.DBA.CYP_PATH_VAR_HOP_COUNT (path_info) as varchar);

          if (_fname = 'nodes')
            {
              path_nodes := DB.DBA.CYP_PATH_VAR_NODE_TERMS (path_info);
              path_rels := DB.DBA.CYP_PATH_VAR_REL_TERMS (path_info);
              vec_s := '';
              for (pi := 0; pi < length (path_nodes); pi := pi + 1)
                {
                  if (aref (path_nodes, pi) is null)
                    return 'bif:vector()';
                  if (pi > 0) vec_s := concat (vec_s, ', ');
                  vec_s := concat (vec_s, aref (path_nodes, pi));
                }
              rel_vec_s := '';
              for (pi := 0; pi < length (path_rels); pi := pi + 1)
                {
                  rel_term := aref (path_rels, pi);
                  if (rel_term is null) rel_term := 'NULL';
                  if (pi > 0) rel_vec_s := concat (rel_vec_s, ', ');
                  rel_vec_s := concat (rel_vec_s, rel_term);
                }
              return concat ('sql:CYP_PATH_NODES(sql:CYP_PATH_NEW(bif:vector(',
                             vec_s, '), bif:vector(', rel_vec_s, ')))');
            }

          if (_fname = 'relationships')
            {
              path_nodes := DB.DBA.CYP_PATH_VAR_NODE_TERMS (path_info);
              path_rels := DB.DBA.CYP_PATH_VAR_REL_TERMS (path_info);
              node_vec_s := '';
              for (pi := 0; pi < length (path_nodes); pi := pi + 1)
                {
                  node_term := aref (path_nodes, pi);
                  if (node_term is null) node_term := 'NULL';
                  if (pi > 0) node_vec_s := concat (node_vec_s, ', ');
                  node_vec_s := concat (node_vec_s, node_term);
                }
              rel_vec_s := '';
              for (pi := 0; pi < length (path_rels); pi := pi + 1)
                {
                  rel_term := aref (path_rels, pi);
                  if (rel_term is null)
                    signal ('CY094', 'relationships(p) requires typed relationships or relationship variables in the bound path');
                  if (pi > 0) rel_vec_s := concat (rel_vec_s, ', ');
                  rel_vec_s := concat (rel_vec_s, rel_term);
                }
              return concat ('sql:CYP_PATH_RELS(sql:CYP_PATH_NEW(bif:vector(',
                             node_vec_s, '), bif:vector(', rel_vec_s, ')))');
            }
        }
    }

  -- Aggregation functions (pass through to SPARQL)
  if (_fname = 'count') return sprintf ('COUNT(%s%s)', dist_kw, _args_str);
  if (_fname = 'sum') return sprintf ('SUM(%s%s)', dist_kw, _args_str);
  if (_fname = 'avg') return sprintf ('AVG(%s%s)', dist_kw, _args_str);
  if (_fname = 'min') return sprintf ('MIN(%s%s)', dist_kw, _args_str);
  if (_fname = 'max') return sprintf ('MAX(%s%s)', dist_kw, _args_str);
  if (_fname = 'collect') return sprintf ('GROUP_CONCAT(%s%s; separator=",")', dist_kw, _args_str);

  -- String functions
  if (_fname = 'tostring') return sprintf ('STR(%s)', _args_str);
  -- Type conversion: invalid casts of strings produce a SPARQL evaluation
  -- error which COALESCE absorbs into an unbound result, matching the
  -- openCypher contract that toInteger/toFloat return null on garbage
  -- input.  toIntegerOrNull / toFloatOrNull are openCypher 2024 aliases
  -- with identical semantics in our lowering.
  if (_fname = 'tointeger' or _fname = 'tointegerornull')
    return sprintf ('COALESCE(xsd:integer(%s))', _args_str);
  if (_fname = 'tofloat' or _fname = 'tofloatornull')
    return sprintf ('COALESCE(xsd:double(%s))', _args_str);
  -- toBoolean: per openCypher returns the input boolean unchanged, parses
  -- the case-insensitive strings "true" / "false", and yields null for
  -- any other input or for null itself.  Virtuoso's xsd:boolean cast
  -- always returns true for non-empty strings, so we lower to an explicit
  -- IF cascade.  Each argument expression is materialised once into a
  -- SPARQL BIND-style let via STR() so the input is evaluated a single
  -- time inside the cascade.
  if (_fname = 'toboolean')
    return sprintf (
      'IF(LCASE(STR(%s)) = "true", true, IF(LCASE(STR(%s)) = "false", false, COALESCE()))',
      _args_str, _args_str);
  if (_fname = 'tolower') return sprintf ('LCASE(%s)', _args_str);
  if (_fname = 'toupper') return sprintf ('UCASE(%s)', _args_str);
  if (_fname = 'trim') return sprintf ('bif:trim(%s)', _args_str);
  if (_fname = 'ltrim') return sprintf ('bif:ltrim(%s)', _args_str);
  if (_fname = 'rtrim') return sprintf ('bif:rtrim(%s)', _args_str);
  if (_fname = 'replace') return sprintf ('REPLACE(%s)', _args_str);
  if (_fname = 'substring') return sprintf ('SUBSTR(%s)', _args_str);
  -- left(s, n) and right(s, n) are openCypher string slicers.  Virtuoso
  -- exposes bif:left and bif:right which return the first / last n
  -- characters and propagate an unbound first argument to an unbound
  -- result, so we lower directly to those builtins instead of building
  -- the SUBSTR/STRLEN expression by hand (the standard SUBSTR form
  -- raises a Virtuoso SR008 when called with an unbound start index).
  if (_fname = 'left') return sprintf ('bif:left(%s, %s)',
    DB.DBA.CYP_GEN_EXPR (aref (_args, 0), _ctx, _optional),
    DB.DBA.CYP_GEN_EXPR (aref (_args, 1), _ctx, _optional));
  if (_fname = 'right') return sprintf ('bif:right(%s, %s)',
    DB.DBA.CYP_GEN_EXPR (aref (_args, 0), _ctx, _optional),
    DB.DBA.CYP_GEN_EXPR (aref (_args, 1), _ctx, _optional));
  -- split() returns a list by splitting a string on a delimiter.
  if (_fname = 'split')
    return sprintf ('sql:CYP_SPLIT(%s, %s)',
      DB.DBA.CYP_GEN_EXPR (aref (_args, 0), _ctx, _optional),
      DB.DBA.CYP_GEN_EXPR (aref (_args, 1), _ctx, _optional));
  if (_fname = 'reverse')
    return sprintf ('sql:CYP_REVERSE(%s)', _args_str);
  -- size() and length() moved to list functions section for array support
  if (_fname = 'length') return sprintf ('STRLEN(%s)', _args_str);

  -- Qualified openCypher library calls such as date.truncate() and
  -- duration.between() parse as dotted function names.  Keep them in the
  -- SQL-script layer by lowering to SQL helper names; implementations can
  -- be filled in independently without requiring lexer/plugin changes.
  if (strchr (_fname, '.') is not null)
    return sprintf ('sql:CYP_%s(%s)', upper (replace (_fname, '.', '_')), _args_str);

  -- Temporal constructors (Phase 13.12).  Each accepts the openCypher
  -- forms documented in the language spec:
  --   <name>()                 - current value (date / datetime only)
  --   <name>("ISO 8601 string") - parse the string with the matching
  --                              xsd: cast (Virtuoso accepts ISO 8601
  --                              date / dateTime / time / duration
  --                              literals natively)
  --   <name>({components})      - build an ISO 8601 string from a map
  --                              of openCypher temporal component
  --                              names and parse with the xsd: cast
  if (_fname = 'date'
      or _fname = 'time' or _fname = 'localtime'
      or _fname = 'datetime' or _fname = 'localdatetime')
    {
      declare _t_arg any;
      declare _t_xsd varchar;
      if (_fname = 'date') _t_xsd := 'xsd:date';
      else if (_fname = 'datetime' or _fname = 'localdatetime') _t_xsd := 'xsd:dateTime';
      else _t_xsd := 'xsd:time';

      if (length (_args) = 0)
        {
          -- date() / datetime() / localdatetime() yield the current
          -- value; time() / localtime() likewise yield the current
          -- wall-clock time of day.  Virtuoso's NOW() returns an
          -- xsd:dateTime which the xsd: cast narrows as needed.
          if (_fname = 'date' or _fname = 'datetime' or _fname = 'localdatetime')
            return sprintf ('%s(NOW())', _t_xsd);
          return 'xsd:time(NOW())';
        }

      _t_arg := DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_args, 0), _ctx);
      if (isarray (_t_arg) and aref (_t_arg, 0) = 'MAP')
        return DB.DBA.CYP_GEN_TEMPORAL_FROM_MAP (_t_arg, _fname, _ctx, _optional);
      return sprintf ('%s(%s)', _t_xsd, _args_str);
    }

  -- Duration constructor: openCypher accepts duration("PnYnMnDTnHnMnS")
  -- as an ISO 8601 lexical form.  Virtuoso's xsd:duration cast handles
  -- the full lexical space and yields a value compatible with date /
  -- dateTime arithmetic operators.  Map-form construction is left as a
  -- carry-forward (component-by-component ISO assembly is verbose; we
  -- raise an explicit diagnostic so the gap is visible at translation
  -- time rather than producing a malformed SPARQL string).
  if (_fname = 'duration')
    {
      declare _d_arg any;
      if (length (_args) = 0)
        signal ('CY100', 'duration() requires a string or map argument');
      _d_arg := DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_args, 0), _ctx);
      if (isarray (_d_arg) and aref (_d_arg, 0) = 'MAP')
        return DB.DBA.CYP_GEN_DURATION_FROM_MAP (_d_arg, _ctx, _optional);
      return sprintf ('xsd:duration(%s)', _args_str);
    }

  -- Temporal accessors (Phase 13.12).  SPARQL exposes YEAR / MONTH /
  -- DAY / HOURS / MINUTES / SECONDS / TZ / TIMEZONE which match the
  -- openCypher accessor contract for xsd:date / xsd:dateTime / xsd:time
  -- inputs.  openCypher second() returns an integer; SPARQL SECONDS
  -- returns a decimal, so we wrap with FLOOR to drop fractional
  -- seconds while preserving the integer typing.
  if (_fname = 'year') return sprintf ('YEAR(%s)', _args_str);
  if (_fname = 'month') return sprintf ('MONTH(%s)', _args_str);
  if (_fname = 'day') return sprintf ('DAY(%s)', _args_str);
  if (_fname = 'hour') return sprintf ('HOURS(%s)', _args_str);
  if (_fname = 'minute') return sprintf ('MINUTES(%s)', _args_str);
  if (_fname = 'second') return sprintf ('FLOOR(SECONDS(%s))', _args_str);
  if (_fname = 'timezone' or _fname = 'offset')
    return sprintf ('TIMEZONE(%s)', _args_str);

  -- Sub-second accessors and epoch projections rely on Virtuoso's
  -- bif:datediff for a portable integer answer regardless of the
  -- input's xsd type.  millisecond / microsecond / nanosecond return
  -- the fractional-second portion at the requested resolution; the
  -- epoch projections measure the distance from the Unix epoch.
  if (_fname = 'millisecond' or _fname = 'microsecond' or _fname = 'nanosecond'
      or _fname = 'epochmillis' or _fname = 'epochseconds')
    signal ('CY102',
      sprintf ('%s() temporal accessor is not yet implemented in openCypher', _fname));

  if (_fname = 'truncate')
    signal ('CY103', 'truncate() temporal function is not yet implemented in openCypher');

  -- Node/relationship introspection
  if (_fname = 'keys' and length (_args) = 1)
    {
      if (isarray (aref (_args, 0)))
        {
          declare key_arg_type varchar;
          key_arg_type := aref (aref (_args, 0), 0);
          if (key_arg_type = 'MAP')
            return sprintf ('sql:CYP_MAP_KEYS(%s)',
              DB.DBA.CYP_GEN_MAP_CELL_EXPR (aref (_args, 0), _ctx, _optional));
          if (key_arg_type = 'VAR' or key_arg_type = 'PROP')
            return sprintf ('sql:CYP_NODE_KEYS(%s)',
              DB.DBA.CYP_GEN_EXPR (aref (_args, 0), _ctx, _optional));
        }
      -- keys(null) / keys($param) / non-node → null
      return 'COALESCE()';
    }
  if (_fname = 'properties' and length (_args) = 1)
    {
      if (isarray (aref (_args, 0)))
        {
          declare prop_arg_type varchar;
          prop_arg_type := aref (aref (_args, 0), 0);
          if (prop_arg_type = 'MAP')
            return DB.DBA.CYP_GEN_MAP_CELL_EXPR (aref (_args, 0), _ctx, _optional);
          if (prop_arg_type = 'VAR' or prop_arg_type = 'PROP')
            return sprintf ('sql:CYP_NODE_PROPS(%s)',
              DB.DBA.CYP_GEN_EXPR (aref (_args, 0), _ctx, _optional));
        }
      -- properties(null) / properties(1) / non-node → null
      return 'COALESCE()';
    }
  if (_fname = 'id') return sprintf ('STR(%s)', _args_str);
  if (_fname = 'type')
    {
      -- type(r) returns the relationship type name
      return sprintf ('REPLACE(STR(%s), "%s", "")', _args_str, DB.DBA.OPENCYPHER_NS ());
    }
  if (_fname = 'labels')
    {
      -- labels(n) - would need subquery; simplified
      return sprintf ('bif:concat("label:", STR(%s))', _args_str);
    }

  -- Existence/coalesce
  if (_fname = 'exists') return sprintf ('EXISTS { %s }', _args_str);
  if (_fname = 'coalesce') return sprintf ('COALESCE(%s)', _args_str);
  if (_fname = 'bound') return sprintf ('BOUND(%s)', _args_str);
  if (_fname = 'sameterm') return sprintf ('sameTerm(%s)', _args_str);
  if (_fname = 'isiri') return sprintf ('isIRI(%s)', _args_str);
  if (_fname = 'isuri') return sprintf ('isURI(%s)', _args_str);
  if (_fname = 'isblank') return sprintf ('isBlank(%s)', _args_str);
  if (_fname = 'isliteral') return sprintf ('isLiteral(%s)', _args_str);
  if (_fname = 'isnumeric') return sprintf ('isNumeric(%s)', _args_str);
  if (_fname = 'datatype') return sprintf ('datatype(%s)', _args_str);
  if (_fname = 'lang') return sprintf ('lang(%s)', _args_str);
  if (_fname = 'langmatches') return sprintf ('langMatches(%s)', _args_str);
  if (_fname = 'regex') return sprintf ('REGEX(%s)', _args_str);
  if (_fname = 'strdt') return sprintf ('STRDT(%s)', _args_str);
  if (_fname = 'strlang') return sprintf ('STRLANG(%s)', _args_str);
  if (_fname = 'uuid') return 'UUID()';
  if (_fname = 'struuid') return 'STRUUID()';
  if (_fname = 'md5') return sprintf ('MD5(%s)', _args_str);
  if (_fname = 'sha1') return sprintf ('SHA1(%s)', _args_str);
  if (_fname = 'sha256') return sprintf ('SHA256(%s)', _args_str);
  if (_fname = 'sha384') return sprintf ('SHA384(%s)', _args_str);
  if (_fname = 'sha512') return sprintf ('SHA512(%s)', _args_str);

  -- Math functions
  if (_fname = 'abs') return sprintf ('ABS(%s)', _args_str);
  if (_fname = 'ceil') return sprintf ('CEIL(%s)', _args_str);
  if (_fname = 'floor') return sprintf ('FLOOR(%s)', _args_str);
  if (_fname = 'round') return sprintf ('ROUND(%s)', _args_str);
  -- sign(x): -1 / 0 / 1 / null.  The IF cascade alone evaluates an
  -- unbound input as a non-positive non-negative number and returns 0,
  -- so add `0 * x` to force null propagation: when x is unbound the
  -- product is unbound, the addition is unbound, and the COALESCE
  -- returns null.  When x is a number the term is 0 and the sum is
  -- unchanged.
  if (_fname = 'sign')
    return sprintf ('(IF(%s > 0, 1, IF(%s < 0, -1, 0)) + 0 * %s)',
      _args_str, _args_str, _args_str);
  if (_fname = 'rand') return sprintf ('RAND()');
  if (_fname = 'sqrt') return sprintf ('bif:sqrt(%s)', _args_str);
  if (_fname = 'log') return sprintf ('bif:log(%s)', _args_str);
  if (_fname = 'log10') return sprintf ('bif:log10(%s)', _args_str);
  if (_fname = 'exp') return sprintf ('bif:exp(%s)', _args_str);
  if (_fname = 'e') return '2.718281828459045';
  if (_fname = 'pi') return '3.141592653589793';

  -- List functions
  if (length (_args) > 0)
    arg0_expr := DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (_args, 0), _ctx);
  else
    arg0_expr := null;
  if (_fname = 'head'
      and isarray (arg0_expr) and aref (arg0_expr, 0) = 'LIST')
    return sprintf ('sql:CYP_LIST_GET(%s, 0)',
      DB.DBA.CYP_GEN_LIST_CELL_EXPR (arg0_expr, _ctx, _optional));
  if (_fname = 'head') return sprintf ('bif:aref(%s, 0)', _args_str);
  if (_fname = 'last'
      and isarray (arg0_expr) and aref (arg0_expr, 0) = 'LIST')
    return sprintf ('sql:CYP_LIST_GET(%s, sql:CYP_LIST_LENGTH(%s) - 1)',
      DB.DBA.CYP_GEN_LIST_CELL_EXPR (arg0_expr, _ctx, _optional),
      DB.DBA.CYP_GEN_LIST_CELL_EXPR (arg0_expr, _ctx, _optional));
  if (_fname = 'last') return sprintf ('bif:aref(%s, bif:length(%s) - 1)', _args_str, _args_str);
  if (_fname = 'range')
    {
      if (length (_args) = 2)
        return sprintf ('sql:CYP_NUMERIC_VECTOR_TO_VECTOR(sql:CYP_NUMERIC_VECTOR_RANGE(%s, %s))',
          DB.DBA.CYP_GEN_EXPR (aref (_args, 0), _ctx, _optional),
          DB.DBA.CYP_GEN_EXPR (aref (_args, 1), _ctx, _optional));
      if (length (_args) = 3)
        return sprintf ('sql:CYP_NUMERIC_VECTOR_TO_VECTOR(sql:CYP_NUMERIC_VECTOR_RANGE(%s, %s, %s))',
          DB.DBA.CYP_GEN_EXPR (aref (_args, 0), _ctx, _optional),
          DB.DBA.CYP_GEN_EXPR (aref (_args, 1), _ctx, _optional),
          DB.DBA.CYP_GEN_EXPR (aref (_args, 2), _ctx, _optional));
      signal ('CY080', 'range() expects two or three numeric arguments');
    }
  if (_fname = 'size')
    {
      if (isarray (arg0_expr) and aref (arg0_expr, 0) = 'LIST')
        return sprintf ('sql:CYP_LIST_LENGTH(%s)',
          DB.DBA.CYP_GEN_LIST_CELL_EXPR (arg0_expr, _ctx, _optional));
      return sprintf ('bif:length(%s)', _args_str);
    }
  if (_fname = 'length')
    {
      if (isarray (arg0_expr) and aref (arg0_expr, 0) = 'LIST')
        return sprintf ('sql:CYP_LIST_LENGTH(%s)',
          DB.DBA.CYP_GEN_LIST_CELL_EXPR (arg0_expr, _ctx, _optional));
      return sprintf ('bif:length(%s)', _args_str);
    }
  if (_fname = 'tail')
    {
      if (isarray (arg0_expr) and aref (arg0_expr, 0) = 'LIST')
        return sprintf ('sql:CYP_LIST_TO_VECTOR(sql:CYP_LIST_SLICE(%s, 1, NULL))',
          DB.DBA.CYP_GEN_LIST_CELL_EXPR (arg0_expr, _ctx, _optional));
      return sprintf ('bif:subseq(%s, 1, bif:length(%s))', _args_str, _args_str);
    }

  -- Path functions (Phase 6)
  if (_fname = 'nodes')
    return sprintf ('sql:CYP_PATH_NODES(%s)', _args_str);
  if (_fname = 'relationships')
    return sprintf ('sql:CYP_PATH_RELS(%s)', _args_str);
  if (_fname = 'shortestpath')
    signal ('CY078', 'shortestPath() is not yet implemented in openCypher');
  if (_fname = 'allshortestpaths')
    signal ('CY079', 'allShortestPaths() is not yet implemented in openCypher');

  -- Temporal
  if (_fname = 'timestamp') return 'NOW()';
  if (_fname = 'date') return sprintf ('xsd:date(%s)', _args_str);
  if (_fname = 'datetime') return sprintf ('xsd:dateTime(%s)', _args_str);
  if (_fname = 'year') return sprintf ('YEAR(%s)', _args_str);
  if (_fname = 'month') return sprintf ('MONTH(%s)', _args_str);
  if (_fname = 'day') return sprintf ('DAY(%s)', _args_str);
  if (_fname = 'hours') return sprintf ('HOURS(%s)', _args_str);
  if (_fname = 'minutes') return sprintf ('MINUTES(%s)', _args_str);
  if (_fname = 'seconds') return sprintf ('SECONDS(%s)', _args_str);
  if (_fname = 'timezone') return sprintf ('TIMEZONE(%s)', _args_str);
  if (_fname = 'tz') return sprintf ('TZ(%s)', _args_str);

  -- Quantifier functions (Phase 7)
  if (_fname = 'all')
    signal ('CY080', 'all() quantifier is not yet implemented in openCypher');
  if (_fname = 'any')
    signal ('CY081', 'any() quantifier is not yet implemented in openCypher');
  if (_fname = 'none')
    signal ('CY082', 'none() quantifier is not yet implemented in openCypher');
  if (_fname = 'single')
    signal ('CY083', 'single() quantifier is not yet implemented in openCypher');

  -- Percentile aggregate functions
  if (_fname = 'percentiledisc')
    return sprintf ('sql:CYP_PERCENTILE_DISC(%s)', _args_str);
  if (_fname = 'percentilecont')
    return sprintf ('sql:CYP_PERCENTILE_CONT(%s)', _args_str);

  -- Default: unknown function error (Phase 7 - replace fallback)
  signal ('CY084', sprintf ('Unknown or unsupported function: %s()', _fname));
}
;

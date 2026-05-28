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
--  openCypher: OpenCypher for Virtuoso - Main Entry Point and Execution Engine
--
--  Primary interface: DB.DBA.CYPHER(query, graph)
--  Returns: result set for read queries, status for write queries
--
--  Production Cypher -> SPARQL translation uses the SQL/PL implementation:
--    CYP_TOKENIZE -> CYP_PARSE -> CYP_PLAN_VALIDATE_SCOPE -> CYP_TO_SPARQL.
--
--  The optional C plugin is retained as an explicit secondary frontend for
--  development, benchmarking, and parity testing. Normal DB.DBA.CYPHER* and
--  DB.DBA.CYPHER_TO_SPARQL* entrypoints do not auto-route through the plugin.
--  See test_plugin_parity.sql for the explicit PL-vs-plugin comparison path.
--

-- Main entry point: execute a Cypher query (backward compatible)
create procedure DB.DBA.CYPHER (in _query varchar, in _graph varchar := null)
{
  declare tokens, ast any;
  declare clauses any;
  declare i, n integer;
  declare has_merge integer;

  if (_graph is null)
    _graph := DB.DBA.OPENCYPHER_DEFAULT_GRAPH ();

  -- Tokenize
  tokens := DB.DBA.CYP_TOKENIZE (_query);

  -- Parse
  ast := DB.DBA.CYP_PARSE (tokens);

  -- Check for MERGE (needs procedural handling)
  has_merge := 0;
  clauses := aref (ast, 1);
  n := length (clauses);
  for (i := 0; i < n; i := i + 1)
    {
      if (aref (aref (clauses, i), 0) = 'MERGE')
        has_merge := 1;
    }

  -- MERGE is handled directly (no parameter support yet)
  if (has_merge)
    return DB.DBA.CYPHER_EXEC_MERGE (ast, _graph);

  -- For non-MERGE queries, use the parameterized version with null params
  return DB.DBA.CYPHER_PARAMS (_query, _graph, null);
}
;

-- Parameterized entry point: execute a Cypher query with parameters
create procedure DB.DBA.CYPHER_PARAMS (in _query varchar, in _graph varchar := null, in _params any := null)
{
  declare tokens, ast any;
  declare sparql_str varchar;
  declare clauses any;
  declare i, n integer;
  declare has_merge integer;
  declare param_vector any;

  if (_graph is null)
    _graph := DB.DBA.OPENCYPHER_DEFAULT_GRAPH ();

  -- Normalize params to a vector of name/value pairs
  param_vector := DB.DBA.CYPHER_NORMALIZE_PARAMS (_params);

  -- Tokenize
  tokens := DB.DBA.CYP_TOKENIZE (_query);

  -- Parse
  ast := DB.DBA.CYP_PARSE (tokens);

  -- Check for MERGE (needs procedural handling)
  has_merge := 0;
  clauses := aref (ast, 1);
  n := length (clauses);
  for (i := 0; i < n; i := i + 1)
    {
      if (aref (aref (clauses, i), 0) = 'MERGE')
        has_merge := 1;
    }

  if (has_merge)
    signal ('CY091', 'MERGE with parameters is not yet supported. Use CYPHER() without params for MERGE.');

  -- Translate to SPARQL with parameter substitution
  sparql_str := DB.DBA.CYPHER_TO_SPARQL_PARAMS (_query, _graph, param_vector);

  -- Check if this is a multi-statement update (SET/REMOVE can produce multiple SPARQL statements)
  if (strchr (sparql_str, ';') is not null and strstr (sparql_str, 'SPARQL') is not null)
    return DB.DBA.CYPHER_EXEC_MULTI_PARAMS (sparql_str, param_vector);

  -- Execute single SPARQL statement with parameters
  return DB.DBA.CYPHER_EXEC_SPARQL_PARAMS (sparql_str, param_vector);
}
;

create procedure DB.DBA.OPENCYPHER_PLUGIN_AVAILABLE ()
{
  declare state, msg varchar;
  declare meta, data any;

  state := '00000';
  msg := '';
  exec ('SELECT OPENCYPHER_PLUGIN_VERSION ()', state, msg, vector (), 0, meta, data);
  if (state = '00000' and data is not null and length (data) > 0
      and aref (aref (data, 0), 0) is not null)
    return 1;
  return 0;
}
;

create procedure DB.DBA.OPENCYPHER_PLUGIN_VERSION ()
{
  declare state, msg varchar;
  declare meta, data any;

  state := '00000';
  msg := '';
  exec ('SELECT OPENCYPHER_PLUGIN_VERSION ()', state, msg, vector (), 0, meta, data);
  if (state <> '00000')
    signal (state, msg);
  if (data is not null and length (data) > 0)
    return aref (aref (data, 0), 0);
  signal ('CY070', 'openCypher plugin returned no version string');
}
;

create procedure DB.DBA.OPENCYPHER_PLUGIN_TO_SPARQL (in _query varchar, in _graph varchar, in _params any := null, in _flags integer := 0)
{
  declare state, msg varchar;
  declare meta, data any;

  state := '00000';
  msg := '';
  exec ('SELECT OPENCYPHER_PLUGIN_TO_SPARQL (?, ?, ?, ?)',
        state, msg, vector (_query, _graph, _params, _flags), 0, meta, data);
  if (state <> '00000')
    signal (state, msg);
  if (data is not null and length (data) > 0)
    return aref (aref (data, 0), 0);
  signal ('CY070', 'openCypher plugin returned no SPARQL text');
}
;

create procedure DB.DBA.OPENCYPHER_PLUGIN_TOKENIZE (in _query varchar)
{
  declare state, msg varchar;
  declare meta, data any;

  state := '00000';
  msg := '';
  exec ('SELECT OPENCYPHER_PLUGIN_TOKENIZE (?)',
        state, msg, vector (_query), 0, meta, data);
  if (state <> '00000')
    signal (state, msg);
  if (data is not null and length (data) > 0)
    return aref (aref (data, 0), 0);
  signal ('CY070', 'openCypher plugin returned no token stream');
}
;

create procedure DB.DBA.OPENCYPHER_PLUGIN_PARSE (in _query varchar, in _flags integer := 0)
{
  declare state, msg varchar;
  declare meta, data any;

  state := '00000';
  msg := '';
  exec ('SELECT OPENCYPHER_PLUGIN_PARSE (?, ?)',
        state, msg, vector (_query, _flags), 0, meta, data);
  if (state <> '00000')
    signal (state, msg);
  if (data is not null and length (data) > 0)
    return aref (aref (data, 0), 0);
  signal ('CY070', 'openCypher plugin returned no AST');
}
;

create procedure DB.DBA.OPENCYPHER_PLUGIN_PLAN (in _query varchar, in _flags integer := 0)
{
  declare state, msg varchar;
  declare meta, data any;

  state := '00000';
  msg := '';
  exec ('SELECT OPENCYPHER_PLUGIN_PLAN (?, ?)',
        state, msg, vector (_query, _flags), 0, meta, data);
  if (state <> '00000')
    signal (state, msg);
  if (data is not null and length (data) > 0)
    return aref (aref (data, 0), 0);
  signal ('CY070', 'openCypher plugin returned no plan');
}
;

create procedure DB.DBA.OPENCYPHER_PLUGIN_GEN_SPARQL (in _query varchar, in _graph varchar := null, in _flags integer := 0)
{
  declare state, msg varchar;
  declare meta, data any;

  state := '00000';
  msg := '';
  exec ('SELECT OPENCYPHER_PLUGIN_GEN_SPARQL (?, ?, ?)',
        state, msg, vector (_query, _graph, _flags), 0, meta, data);
  if (state <> '00000')
    signal (state, msg);
  if (data is not null and length (data) > 0)
    return aref (aref (data, 0), 0);
  signal ('CY070', 'openCypher plugin returned no generated SPARQL');
}
;

create procedure DB.DBA.OPENCYPHER_PLUGIN_TO_SPARQL_CALL (in _query varchar, in _graph varchar, in _params any := null, in _flags integer := 0)
{
  declare state, msg varchar;
  declare meta, data any;

  state := '00000';
  msg := '';
  exec ('SELECT OPENCYPHER_PLUGIN_TO_SPARQL (?, ?, ?, ?)',
        state, msg, vector (_query, _graph, _params, _flags), 0, meta, data);
  if (state <> '00000')
    signal (state, msg);
  if (data is not null and length (data) > 0)
    return aref (aref (data, 0), 0);
  signal ('CY070', 'openCypher plugin returned no SPARQL text');
}
;

-- Execute a single SPARQL statement and return results
create procedure DB.DBA.CYPHER_EXEC_SPARQL (in _sparql varchar)
{
  declare state, msg varchar;
  declare meta, data any;

  state := '00000';
  msg := '';
  exec (_sparql, state, msg, vector (), 0, meta, data);
  if (state <> '00000')
    signal (state, msg);
  if (data is not null)
    return data;
  return vector ();
}
;

-- Execute multiple SPARQL statements (semicolon-separated)
create procedure DB.DBA.CYPHER_EXEC_MULTI (in _sparql_multi varchar)
{
  declare statements any;
  declare i, n integer;
  declare state, msg varchar;
  declare meta, data, last_result any;
  declare stmts any;
  declare stmt varchar;
  declare pos, prev_pos integer;

  last_result := null;

  -- Split by semicolons (simplistic split)
  pos := 0;
  prev_pos := 0;

  while (pos <= length (_sparql_multi))
    {
      if (pos = length (_sparql_multi) or aref (_sparql_multi, pos) = 59)  -- semicolon
        {
          stmt := trim (subseq (_sparql_multi, prev_pos, pos));
          if (length (stmt) > 0 and strstr (stmt, 'SPARQL') is not null)
            {
              state := '00000';
              msg := '';
              exec (stmt, state, msg, vector (), 0, meta, data);
              if (state <> '00000')
                signal (state, msg);
              if (data is not null)
                last_result := data;
            }
          prev_pos := pos + 1;
        }
      pos := pos + 1;
    }

  if (last_result is not null)
    return last_result;
  return vector ();
}
;

-- Execute MERGE using procedural logic
create procedure DB.DBA.CYPHER_EXEC_MERGE (in _ast any, in _graph varchar)
{
  declare clauses any;
  declare i, n integer;
  declare merge_ast, on_create, on_match any;
  declare match_ctx any;
  declare state, msg varchar;
  declare meta, data any;
  declare clause any;
  declare patterns any;
  declare match_query varchar;
  declare match_ast any;
  declare set_ast any;
  declare set_sparql varchar;
  declare create_ast, create_stmt any;
  declare create_sparql varchar;
  declare set_ast2 any;
  declare set_sparql2 varchar;
  declare prefix_ctx any;
  declare has_return integer;
  declare post_merge_ast any;
  declare post_merge_sparql varchar;
  declare merge_graph varchar;
  declare merge_from_graphs any;

  clauses := aref (_ast, 1);
  n := length (clauses);
  prefix_ctx := DB.DBA.CYP_CTX_NEW (_graph);
  has_return := 0;

  for (i := 0; i < n; i := i + 1)
    {
      clause := aref (clauses, i);
      if (aref (clause, 0) = 'PREFIX')
        DB.DBA.CYP_CTX_ADD_PREFIX (prefix_ctx, aref (clause, 1), aref (clause, 2));
      else if (aref (clause, 0) = 'RETURN')
        has_return := 1;
    }

  for (i := 0; i < n; i := i + 1)
    {
      clause := aref (clauses, i);
      if (aref (clause, 0) = 'MERGE')
        {
          patterns := aref (clause, 1);
          on_create := aref (clause, 2);
          on_match := aref (clause, 3);
          merge_graph := _graph;
          merge_from_graphs := vector ();
          if (length (clause) > 4)
            merge_from_graphs := aref (clause, 4);
          if (merge_from_graphs is not null and length (merge_from_graphs) > 0)
            merge_graph := DB.DBA.CYP_GRAPH_EXPR_URI (aref (aref (merge_from_graphs, 0), 1), prefix_ctx, _graph);
          DB.DBA.CYP_CTX_SET (prefix_ctx, 'graph', merge_graph);
          DB.DBA.CYP_CTX_SET (prefix_ctx, 'reif_graph', merge_graph);

          -- Try to MATCH the pattern first
          match_ast := vector ('STMT', vector (
            vector ('MATCH', 0, patterns, merge_from_graphs),
            vector ('RETURN', 0, vector (vector ('RETITEM', vector ('VAR', '*'), null)), null, null, null)
          ));
          match_query := DB.DBA.CYP_TO_SPARQL (match_ast, merge_graph);

          state := '00000';
          msg := '';
          exec (match_query, state, msg, vector (), 0, meta, data);

          if (data is not null and length (data) > 0)
            {
              -- Pattern exists: execute ON MATCH SET if present
              if (on_match is not null)
                {
                  set_ast := vector ('STMT', vector (
                    vector ('MATCH', 0, patterns, merge_from_graphs),
                    on_match
                  ));
                  set_sparql := DB.DBA.CYP_TO_SPARQL (set_ast, merge_graph);
                  DB.DBA.CYPHER_EXEC_MULTI (set_sparql);
                }
            }
          else
            {
              -- Pattern doesn't exist: create only missing nodes, then relationships.
              DB.DBA.CYPHER_EXEC_MERGE_PATTERNS (patterns, prefix_ctx, merge_graph);

              -- Execute ON CREATE SET if present
              if (on_create is not null)
                {
                  set_ast2 := vector ('STMT', vector (
                    vector ('MATCH', 0, patterns, merge_from_graphs),
                    on_create
                  ));
                  set_sparql2 := DB.DBA.CYP_TO_SPARQL (set_ast2, merge_graph);
                  DB.DBA.CYPHER_EXEC_MULTI (set_sparql2);
                }
            }
        }
    }

  if (has_return)
    {
      post_merge_ast := DB.DBA.CYP_STMT_REWRITE_MERGE_AS_MATCH (_ast);
      post_merge_sparql := DB.DBA.CYP_TO_SPARQL (post_merge_ast, _graph);
      return DB.DBA.CYPHER_EXEC_SPARQL (post_merge_sparql);
    }

  return vector ();
}
;

create procedure DB.DBA.CYP_STMT_REWRITE_MERGE_AS_MATCH (in _ast any)
{
  declare clauses, new_clauses any;
  declare i integer;
  declare clause, patterns, on_create, on_match, from_graphs any;

  if (not isarray (_ast) or aref (_ast, 0) <> 'STMT')
    signal ('CY095', 'Expected STMT AST for MERGE rewrite');

  clauses := aref (_ast, 1);
  new_clauses := vector ();
  for (i := 0; i < length (clauses); i := i + 1)
    {
      clause := aref (clauses, i);
      if (aref (clause, 0) = 'MERGE')
        {
          patterns := aref (clause, 1);
          on_create := aref (clause, 2);
          on_match := aref (clause, 3);
          from_graphs := aref (clause, 4);
          -- MATCH to test existence
          new_clauses := vector_concat (new_clauses,
            vector (vector ('MATCH', 0, patterns, from_graphs)));
          -- ON MATCH SET actions (applied when MATCH succeeds)
          if (on_match is not null)
            new_clauses := vector_concat (new_clauses, vector (on_match));
          -- CREATE for when MATCH found nothing
          new_clauses := vector_concat (new_clauses,
            vector (vector ('CREATE', patterns, null)));
          -- ON CREATE SET actions (applied after CREATE)
          if (on_create is not null)
            new_clauses := vector_concat (new_clauses, vector (on_create));
        }
      else
        new_clauses := vector_concat (new_clauses, vector (clause));
    }
  return vector ('STMT', new_clauses);
}
;

create procedure DB.DBA.CYP_STMT_HAS_MERGE (in _ast any)
{
  declare clauses any;
  declare i integer;

  if (not isarray (_ast) or aref (_ast, 0) <> 'STMT')
    signal ('CY096', 'Expected STMT AST for MERGE detection');

  clauses := aref (_ast, 1);
  for (i := 0; i < length (clauses); i := i + 1)
    {
      if (aref (aref (clauses, i), 0) = 'MERGE')
        return 1;
    }
  return 0;
}
;

create procedure DB.DBA.CYPHER_QUERY_HAS_MERGE (in _query varchar)
{
  return DB.DBA.CYP_STMT_HAS_MERGE (
    DB.DBA.CYP_PARSE (DB.DBA.CYP_TOKENIZE (_query)));
}
;

create procedure DB.DBA.CYPHER_EXEC_MERGE_PATTERNS (in _patterns any, inout _ctx any, in _graph varchar)
{
  declare i integer;

  for (i := 0; i < length (_patterns); i := i + 1)
    DB.DBA.CYPHER_EXEC_MERGE_PATTERN (aref (_patterns, i), _ctx, _graph);
}
;

create procedure DB.DBA.CYPHER_EXEC_MERGE_PATTERN (in _pat any, inout _ctx any, in _graph varchar)
{
  declare pat_type varchar;
  declare elements any;
  declare i, n integer;
  declare elem, rel, prev_node, next_node, types any;
  declare props any;
  declare node_uris any;
  declare src_key, dst_key, src_uri, dst_uri, actual_src, actual_dst varchar;
  declare node_key, node_uri varchar;
  declare direction, rel_uri, check_sparql, insert_sparql varchar;
  declare stmt_uri, reif_graph varchar;
  declare prop any;
  declare pi integer;
  declare state, msg varchar;
  declare meta, data any;

  pat_type := aref (_pat, 0);
  if (pat_type = 'PATHVAR')
    {
      DB.DBA.CYPHER_EXEC_MERGE_PATTERN (aref (_pat, 2), _ctx, _graph);
      return;
    }
  if (pat_type <> 'PATTERN')
    signal ('CY040', sprintf ('Expected PATTERN in MERGE, got %s', pat_type));

  elements := aref (_pat, 1);
  n := length (elements);
  node_uris := vector ();

  for (i := 0; i < n; i := i + 1)
    {
      elem := aref (elements, i);
      if (aref (elem, 0) = 'NODE')
        {
          node_key := DB.DBA.CYP_CREATE_NODE_KEY (aref (elem, 1), i);
          node_uri := DB.DBA.CYPHER_MERGE_NODE_URI (elem, _ctx, _graph);
          node_uris := vector_concat (node_uris, vector (vector (node_key, node_uri)));
        }
    }

  for (i := 0; i < n; i := i + 1)
    {
      elem := aref (elements, i);
      if (aref (elem, 0) = 'REL' and i > 0 and i < n - 1)
        {
          rel := elem;
          direction := aref (rel, 3);
          types := aref (rel, 2);
          props := aref (rel, 6);
          if (length (types) = 0)
            signal ('CY041', 'MERGE relationship requires a relationship type');

          prev_node := aref (elements, i - 1);
          next_node := aref (elements, i + 1);
          src_key := DB.DBA.CYP_CREATE_NODE_KEY (aref (prev_node, 1), i - 1);
          dst_key := DB.DBA.CYP_CREATE_NODE_KEY (aref (next_node, 1), i + 1);
          src_uri := DB.DBA.CYP_FIND_NODE_URI (node_uris, src_key);
          dst_uri := DB.DBA.CYP_FIND_NODE_URI (node_uris, dst_key);
          if (direction = 'LEFT')
            { actual_src := dst_uri; actual_dst := src_uri; }
          else
            { actual_src := src_uri; actual_dst := dst_uri; }

          rel_uri := DB.DBA.CYP_REL_TYPE_URI (_ctx, aref (types, 0));
          check_sparql := sprintf ('SPARQL SELECT ?s FROM <%s> WHERE { <%s> <%s> <%s> } LIMIT 1',
                                   _graph, actual_src, rel_uri, actual_dst);
          state := '00000';
          msg := '';
          exec (check_sparql, state, msg, vector (), 0, meta, data);
          if (state <> '00000')
            signal (state, msg);
          if (data is null or length (data) = 0)
            {
              insert_sparql := sprintf ('SPARQL INSERT DATA { GRAPH <%s> { <%s> <%s> <%s> . } }',
                                        _graph, actual_src, rel_uri, actual_dst);
              DB.DBA.CYPHER_EXEC_SPARQL (insert_sparql);
            }
          if (length (props) > 0)
            {
              reif_graph := DB.DBA.CYP_REIF_GRAPH (_ctx);
              stmt_uri := DB.DBA.OPENCYPHER_REIF_STATEMENT_ID (actual_src, aref (types, 0), actual_dst);
              insert_sparql := sprintf (
                'SPARQL INSERT DATA { GRAPH <%s> { <%s> a <http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement> . <%s> <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> <%s> . <%s> <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> <%s> . <%s> <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> <%s> .',
                reif_graph, stmt_uri, stmt_uri, actual_src, stmt_uri, rel_uri, stmt_uri, actual_dst);
              for (pi := 0; pi < length (props); pi := pi + 1)
                {
                  prop := aref (props, pi);
                  insert_sparql := concat (insert_sparql, sprintf (' <%s> <%s> %s .',
                    stmt_uri, DB.DBA.CYP_PROP_URI (_ctx, aref (prop, 0)),
                    DB.DBA.CYP_CREATE_VALUE (_ctx, aref (prop, 1))));
                }
              insert_sparql := concat (insert_sparql, ' } }');
              DB.DBA.CYPHER_EXEC_SPARQL (insert_sparql);
            }
        }
    }
}
;

create procedure DB.DBA.CYPHER_MERGE_NODE_URI (in _node any, inout _ctx any, in _graph varchar)
{
  declare found_uri varchar;
  declare subject_uri varchar;

  subject_uri := DB.DBA.CYP_NODE_IRI_FROM_PROPS (_ctx, aref (_node, 3));
  if (subject_uri is not null)
    {
      DB.DBA.CYPHER_ENSURE_MERGE_NODE (subject_uri, _node, _ctx, _graph);
      return subject_uri;
    }

  found_uri := DB.DBA.CYPHER_FIND_MERGE_NODE (_node, _ctx, _graph);
  if (found_uri is not null)
    return found_uri;
  return DB.DBA.CYPHER_CREATE_MERGE_NODE (_node, _ctx, _graph);
}
;

create procedure DB.DBA.CYPHER_ENSURE_MERGE_NODE (in _node_uri varchar, in _node any, inout _ctx any, in _graph varchar)
{
  declare labels, props any;
  declare i integer;
  declare prop any;
  declare triples, sparql_q varchar;

  labels := aref (_node, 2);
  props := aref (_node, 3);
  triples := '';
  for (i := 0; i < length (labels); i := i + 1)
    triples := concat (triples, sprintf ('<%s> a <%s> .\n', _node_uri, DB.DBA.CYP_LABEL_URI (_ctx, aref (labels, i))));
  for (i := 0; i < length (props); i := i + 1)
    {
      prop := aref (props, i);
      if (not DB.DBA.CYP_IS_NODE_IRI_PROP (aref (prop, 0)))
        triples := concat (triples, sprintf ('<%s> <%s> %s .\n',
                          _node_uri, DB.DBA.CYP_PROP_URI (_ctx, aref (prop, 0)),
                          DB.DBA.CYP_CREATE_LITERAL_VALUE (aref (prop, 1))));
    }

  if (length (triples) > 0)
    {
      sparql_q := sprintf ('SPARQL INSERT INTO GRAPH <%s> {\n%s}', _graph, triples);
      DB.DBA.CYPHER_EXEC_SPARQL (sparql_q);
    }
}
;

create procedure DB.DBA.CYPHER_FIND_MERGE_NODE (in _node any, inout _ctx any, in _graph varchar)
{
  declare labels, props any;
  declare i integer;
  declare prop any;
  declare where_body, sparql_q varchar;
  declare state, msg varchar;
  declare meta, data any;

  labels := aref (_node, 2);
  props := aref (_node, 3);
  where_body := '';
  for (i := 0; i < length (labels); i := i + 1)
    where_body := concat (where_body, sprintf (' ?n a <%s> . ', DB.DBA.CYP_LABEL_URI (_ctx, aref (labels, i))));
  for (i := 0; i < length (props); i := i + 1)
    {
      prop := aref (props, i);
      if (not DB.DBA.CYP_IS_NODE_IRI_PROP (aref (prop, 0)))
        where_body := concat (where_body, sprintf (' ?n <%s> %s . ',
                            DB.DBA.CYP_PROP_URI (_ctx, aref (prop, 0)),
                            DB.DBA.CYP_CREATE_LITERAL_VALUE (aref (prop, 1))));
    }

  sparql_q := sprintf ('SPARQL SELECT ?n FROM <%s> WHERE { %s } LIMIT 1', _graph, where_body);
  state := '00000';
  msg := '';
  exec (sparql_q, state, msg, vector (), 0, meta, data);
  if (state <> '00000')
    signal (state, msg);
  if (data is not null and length (data) > 0)
    return cast (aref (aref (data, 0), 0) as varchar);
  return null;
}
;

create procedure DB.DBA.CYPHER_CREATE_MERGE_NODE (in _node any, inout _ctx any, in _graph varchar)
{
  declare node_uri varchar;
  declare labels, props any;
  declare i integer;
  declare prop any;
  declare triples, sparql_q varchar;

  labels := aref (_node, 2);
  props := aref (_node, 3);
  node_uri := DB.DBA.CYP_NODE_IRI_FROM_PROPS (_ctx, props);
  if (node_uri is null)
    node_uri := DB.DBA.OPENCYPHER_NEW_NODE_URI ();
  triples := '';
  for (i := 0; i < length (labels); i := i + 1)
    triples := concat (triples, sprintf ('<%s> a <%s> .\n', node_uri, DB.DBA.CYP_LABEL_URI (_ctx, aref (labels, i))));
  for (i := 0; i < length (props); i := i + 1)
    {
      prop := aref (props, i);
      if (not DB.DBA.CYP_IS_NODE_IRI_PROP (aref (prop, 0)))
        triples := concat (triples, sprintf ('<%s> <%s> %s .\n',
                          node_uri, DB.DBA.CYP_PROP_URI (_ctx, aref (prop, 0)),
                          DB.DBA.CYP_CREATE_LITERAL_VALUE (aref (prop, 1))));
    }

  sparql_q := sprintf ('SPARQL INSERT INTO GRAPH <%s> {\n%s}', _graph, triples);
  DB.DBA.CYPHER_EXEC_SPARQL (sparql_q);
  return node_uri;
}
;

-- Convenience: translate Cypher to SPARQL without executing (for debugging)
create procedure DB.DBA.CYPHER_TO_SPARQL (in _query varchar, in _graph varchar := null)
{
  declare tokens, ast any;
  declare i integer;
  declare clauses, clause any;
  declare has_merge integer;

  tokens := DB.DBA.CYP_TOKENIZE (_query);
  ast := DB.DBA.CYP_PARSE (tokens);

  -- Detect MERGE and route through the post-rewrite path so MERGE
  -- is expanded to MATCH+CREATE before scope validation and translation.
  has_merge := 0;
  clauses := aref (ast, 1);
  for (i := 0; i < length (clauses); i := i + 1)
    {
      clause := aref (clauses, i);
      if (isarray (clause) and aref (clause, 0) = 'MERGE')
        has_merge := 1;
    }
  if (has_merge)
    {
      declare has_return_or_ask integer;
      has_return_or_ask := 0;
      for (i := 0; i < length (clauses); i := i + 1)
        {
          clause := aref (clauses, i);
          if (isarray (clause) and (aref (clause, 0) = 'RETURN' or aref (clause, 0) = 'ASK'
               or aref (clause, 0) = 'CONSTRUCT' or aref (clause, 0) = 'DESCRIBE'))
            has_return_or_ask := 1;
        }
      ast := DB.DBA.CYP_STMT_REWRITE_MERGE_AS_MATCH (ast);
      if (not has_return_or_ask)
        {
          -- Standalone MERGE (no RETURN): append a synthetic RETURN
          -- so the translation produces valid SPARQL.
          declare new_clauses any;
          new_clauses := vector_concat (aref (ast, 1),
            vector (vector ('RETURN', 0,
              vector (vector ('RETITEM', vector ('LIT', 1), null)),
              null, null, null, null, null)));
          ast := vector ('STMT', new_clauses);
        }
      DB.DBA.CYP_PLAN_VALIDATE_SCOPE (DB.DBA.CYP_PLAN_BUILD (ast));
      return DB.DBA.CYP_TO_SPARQL (ast, _graph);
    }

  DB.DBA.CYP_PLAN_VALIDATE_SCOPE (DB.DBA.CYP_PLAN_BUILD (ast));
  return DB.DBA.CYP_TO_SPARQL (ast, _graph);
}
;

-- Convenience: tokenize only (for debugging)
create procedure DB.DBA.CYPHER_TOKENIZE (in _query varchar)
{

  return DB.DBA.CYP_TOKENIZE (_query);
}
;

-- Convenience: parse only (for debugging)
create procedure DB.DBA.CYPHER_PARSE (in _query varchar)
{
  declare tokens any;

  tokens := DB.DBA.CYP_TOKENIZE (_query);
  return DB.DBA.CYP_PARSE (tokens);
}
;

-- Clear all Cypher data in default graph
create procedure DB.DBA.CYPHER_RESET (in _graph varchar := null)
{

  if (_graph is null)
    _graph := DB.DBA.OPENCYPHER_DEFAULT_GRAPH ();
  DB.DBA.OPENCYPHER_CLEAR_GRAPH (_graph);
  DB.DBA.OPENCYPHER_CLEAR_GRAPH (DB.DBA.OPENCYPHER_REIF_GRAPH ());
  return 'Graph cleared';
}
;

-- Return version information
create procedure DB.DBA.CYPHER_VERSION ()
{

  return 'openCypher 0.1.0 - OpenCypher for Virtuoso';
}
;

-- ============================================================================
-- Parameter Support (Phase 8)
-- ============================================================================

-- Normalize various param input forms to a vector of vector(name, value)
-- Supported forms:
--   - null -> empty vector
--   - vector of vector(name, value) -> passed through
--   - vector of name, value pairs flat -> converted to nested
--   - JSON object string -> parsed and converted
--   - SQL dictionary -> converted to vector
create procedure DB.DBA.CYPHER_NORMALIZE_PARAMS (in _params any)
{
  declare result any;
  declare i, n integer;
  declare keys any;

  if (_params is null)
    return vector ();

  -- SQL dictionary - convert to vector(name, value) pairs.
  if (__tag (_params) = __tag of dictionary reference)
    {
      declare dict_vec any;
      dict_vec := dict_to_vector (_params, 0);
      result := vector ();
      for (i := 0; i < length (dict_vec); i := i + 1)
        {
          if (isarray (aref (dict_vec, i)) and length (aref (dict_vec, i)) = 2)
            result := vector_concat (result,
              vector (vector (aref (aref (dict_vec, i), 0),
                              aref (aref (dict_vec, i), 1))));
          else if (i + 1 < length (dict_vec))
            {
              result := vector_concat (result,
                vector (vector (aref (dict_vec, i), aref (dict_vec, i + 1))));
              i := i + 1;
            }
        }
      return result;
    }

  -- Already a vector - check if properly nested
  if (isarray (_params))
    {
      if (length (_params) = 0)
        return vector ();

      -- Check if it's vector of pairs or flat vector
      declare first_elem any;
      first_elem := aref (_params, 0);
      if (isarray (first_elem) and length (first_elem) = 2)
        {
          -- Already vector of vector(name, value)
          return _params;
        }

      -- Flat vector - convert to pairs
      result := vector ();
      n := length (_params);
      for (i := 0; i < n; i := i + 2)
        {
          if (i + 1 < n)
            result := vector_concat (result, vector (vector (aref (_params, i), aref (_params, i + 1))));
        }
      return result;
    }

  -- JSON string - parse it
  if (isstring (_params))
    {
      declare json_obj any;
      json_obj := json_parse (_params);
      if (isarray (json_obj))
        return DB.DBA.CYPHER_NORMALIZE_PARAMS (json_obj);

      -- Single value wrapped as param
      return vector (vector ('param', json_obj));
    }

  -- Unknown format
  return vector ();
}
;

-- Execute SPARQL with parameters
create procedure DB.DBA.CYPHER_EXEC_SPARQL_PARAMS (in _sparql varchar, in _params any)
{
  declare state, msg varchar;
  declare meta, data any;
  declare exec_params any;
  declare i integer;

  state := '00000';
  msg := '';

  -- Build parameter vector for exec
  exec_params := vector ();
  if (_params is not null)
    {
      for (i := 0; i < length (_params); i := i + 1)
        {
          declare pv any;
          pv := aref (_params, i);
          if (isarray (pv) and length (pv) = 2)
            exec_params := vector_concat (exec_params, vector (aref (pv, 1)));
        }
    }

  exec (_sparql, state, msg, exec_params, 0, meta, data);
  if (state <> '00000')
    signal (state, msg);
  if (data is not null)
    return data;
  return vector ();
}
;

-- Execute multiple SPARQL statements with parameters
create procedure DB.DBA.CYPHER_EXEC_MULTI_PARAMS (in _sparql_multi varchar, in _params any)
{
  declare statements any;
  declare i, n integer;
  declare state, msg varchar;
  declare meta, data, last_result any;
  declare stmts any;
  declare stmt varchar;
  declare pos, prev_pos integer;
  declare exec_params any;

  last_result := null;

  -- Build parameter vector for exec
  exec_params := vector ();
  if (_params is not null)
    {
      for (i := 0; i < length (_params); i := i + 1)
        {
          declare pv any;
          pv := aref (_params, i);
          if (isarray (pv) and length (pv) = 2)
            exec_params := vector_concat (exec_params, vector (aref (pv, 1)));
        }
    }

  -- Split by semicolons (simplistic split)
  pos := 0;
  prev_pos := 0;

  while (pos <= length (_sparql_multi))
    {
      if (pos = length (_sparql_multi) or aref (_sparql_multi, pos) = 59)  -- semicolon
        {
          stmt := trim (subseq (_sparql_multi, prev_pos, pos));
          if (length (stmt) > 0 and strstr (stmt, 'SPARQL') is not null)
            {
              state := '00000';
              msg := '';
              exec (stmt, state, msg, exec_params, 0, meta, data);
              if (state <> '00000')
                signal (state, msg);
              if (data is not null)
                last_result := data;
            }
          prev_pos := pos + 1;
        }
      pos := pos + 1;
    }

  if (last_result is not null)
    return last_result;
  return vector ();
}
;

-- Translate Cypher to SPARQL with parameter substitution
create procedure DB.DBA.CYPHER_TO_SPARQL_PARAMS (in _query varchar, in _graph varchar := null, in _params any := null)
{
  declare tokens, ast any;
  declare sparql_result any;

  tokens := DB.DBA.CYP_TOKENIZE (_query);
  ast := DB.DBA.CYP_PARSE (tokens);
  sparql_result := DB.DBA.CYP_TO_SPARQL_PARAMS (ast, _graph, _params);

  return sparql_result;
}
;

create procedure DB.DBA.CYPHER_TO_SPARQL_POST_MERGE (in _query varchar, in _graph varchar := null)
{
  declare tokens, ast any;

  tokens := DB.DBA.CYP_TOKENIZE (_query);
  ast := DB.DBA.CYP_PARSE (tokens);
  ast := DB.DBA.CYP_STMT_REWRITE_MERGE_AS_MATCH (ast);
  DB.DBA.CYP_PLAN_VALIDATE_SCOPE (DB.DBA.CYP_PLAN_BUILD (ast));
  return DB.DBA.CYP_TO_SPARQL (ast, _graph);
}
;

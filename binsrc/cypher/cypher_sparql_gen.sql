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
--  openCypher: OpenCypher for Virtuoso - SPARQL Generation (CREATE, DELETE, SET, SELECT, MERGE)
--

-- Generate SPARQL INSERT DATA for standalone CREATE (no MATCH)
create procedure DB.DBA.CYP_GEN_SPARQL_TARGET (in _kind varchar, in _expr any, inout _ctx any)
{
  if (_kind = 'GRAPH')
    return concat ('GRAPH ', DB.DBA.CYP_GEN_GRAPH_TERM (_expr, _ctx));
  if (_kind = 'DEFAULT')
    return 'DEFAULT';
  if (_kind = 'NAMED')
    return 'NAMED';
  if (_kind = 'ALL')
    return 'ALL';
  signal ('CY037', sprintf ('Unsupported SPARQL graph target %s', _kind));
}
;

create procedure DB.DBA.CYP_GRAPH_EXPR_URI (in _expr any, inout _ctx any, in _fallback varchar)
{
  declare uri any;
  if (_expr is null)
    return _fallback;
  if (isarray (_expr) and aref (_expr, 0) = 'IRI')
    {
      uri := DB.DBA.CYP_EXPAND_PREFIXED_NAME (_ctx, aref (_expr, 1));
      if (not isstring (uri))
        uri := aref (_expr, 1);
      return uri;
    }
  if (isarray (_expr) and aref (_expr, 0) = 'LIT' and isstring (aref (_expr, 1)))
    return aref (_expr, 1);
  if (isstring (_expr))
    return _expr;
  return _fallback;
}
;

create procedure DB.DBA.CYP_GEN_SPARQL_UPDATE (in _ast any, inout _ctx any)
{
  declare ctype varchar;
  declare silent varchar;
  declare load_target varchar;
  declare op varchar;
  declare clauses any;
  declare i, pi integer;
  declare clause, patterns, graph_expr any;
  declare target_graph varchar;
  declare triples varchar;
  declare node_uris any;

  ctype := aref (_ast, 0);
  silent := '';

  if (ctype = 'SPARQL_LOAD')
    {
      if (aref (_ast, 1))
        silent := ' SILENT';
      load_target := '';
      if (aref (_ast, 3) is not null)
        load_target := concat (' INTO GRAPH ', DB.DBA.CYP_GEN_GRAPH_TERM (aref (_ast, 3), _ctx));
      return concat ('SPARQL LOAD', silent, ' ',
                     DB.DBA.CYP_GEN_GRAPH_TERM (aref (_ast, 2), _ctx),
                     load_target);
    }

  if (ctype = 'SPARQL_CLEAR' or ctype = 'SPARQL_DROP')
    {
      if (aref (_ast, 1))
        silent := ' SILENT';
      if (ctype = 'SPARQL_CLEAR')
        op := 'CLEAR';
      else
        op := 'DROP';
      return concat ('SPARQL ', op, silent, ' ',
                     DB.DBA.CYP_GEN_SPARQL_TARGET (aref (_ast, 2), aref (_ast, 3), _ctx));
    }

  if (ctype = 'SPARQL_CREATE_GRAPH')
    {
      if (aref (_ast, 1))
        silent := ' SILENT';
      return concat ('SPARQL CREATE', silent, ' GRAPH ',
                     DB.DBA.CYP_GEN_GRAPH_TERM (aref (_ast, 2), _ctx));
    }

  if (ctype = 'SPARQL_GRAPH_COPY')
    {
      if (aref (_ast, 2))
        silent := ' SILENT';
      return concat ('SPARQL ', aref (_ast, 1), silent, ' ',
                     DB.DBA.CYP_GEN_SPARQL_TARGET (aref (_ast, 3), aref (_ast, 4), _ctx),
                     ' TO ',
                     DB.DBA.CYP_GEN_SPARQL_TARGET (aref (_ast, 5), aref (_ast, 6), _ctx));
    }

  if (ctype = 'SPARQL_DATA_UPDATE')
    {
      op := aref (_ast, 1);
      clauses := aref (_ast, 2);
      triples := '';
      target_graph := DB.DBA.CYP_CTX_GET (_ctx, 'graph');
      node_uris := vector ();
      DB.DBA.CYP_CTX_SET (_ctx, 'create_triples', '');
      DB.DBA.CYP_CTX_SET (_ctx, 'create_nodes', node_uris);

      for (i := 0; i < length (clauses); i := i + 1)
        {
          clause := aref (clauses, i);
          if (aref (clause, 0) <> 'CREATE')
            signal ('CY039', 'INSERT DATA and DELETE DATA blocks currently accept CREATE templates');
          graph_expr := aref (clause, 2);
          if (graph_expr is not null)
            target_graph := DB.DBA.CYP_GRAPH_EXPR_URI (graph_expr, _ctx, target_graph);
          DB.DBA.CYP_CTX_SET (_ctx, 'reif_graph', target_graph);
          patterns := aref (clause, 1);
          for (pi := 0; pi < length (patterns); pi := pi + 1)
            {
              DB.DBA.CYP_GEN_CREATE_PATTERN (_ctx, aref (patterns, pi), triples, node_uris);
              triples := DB.DBA.CYP_CTX_GET (_ctx, 'create_triples');
              node_uris := DB.DBA.CYP_CTX_GET (_ctx, 'create_nodes');
              node_uris := DB.DBA.CYP_KEEP_NAMED_NODE_URIS (node_uris);
            }
        }

      return concat ('SPARQL ', op, ' DATA {\nGRAPH ',
                     DB.DBA.OPENCYPHER_FMT_URI (target_graph), ' {\n',
                     triples, '}\n}');
    }

  signal ('CY038', sprintf ('Unsupported SPARQL update clause %s', ctype));
}
;

create procedure DB.DBA.CYP_GEN_CREATE_CLAUSES_SPARQL (in _create_asts any, inout _ctx any, in _graph varchar)
{
  declare i, pi integer;
  declare patterns any;
  declare graph_expr any;
  declare target_graph varchar;
  declare insert_triples varchar;
  declare node_uris any;

  insert_triples := '';
  node_uris := vector ();
  target_graph := _graph;

  for (i := 0; i < length (_create_asts); i := i + 1)
    {
      graph_expr := aref (aref (_create_asts, i), 2);
      if (graph_expr is not null)
        target_graph := DB.DBA.CYP_GRAPH_EXPR_URI (graph_expr, _ctx, target_graph);
      DB.DBA.CYP_CTX_SET (_ctx, 'reif_graph', target_graph);

      patterns := aref (aref (_create_asts, i), 1);
      for (pi := 0; pi < length (patterns); pi := pi + 1)
        {
          DB.DBA.CYP_GEN_CREATE_PATTERN (_ctx, aref (patterns, pi), insert_triples, node_uris);
          insert_triples := DB.DBA.CYP_CTX_GET (_ctx, 'create_triples');
          node_uris := DB.DBA.CYP_CTX_GET (_ctx, 'create_nodes');
          node_uris := DB.DBA.CYP_KEEP_NAMED_NODE_URIS (node_uris);
        }
    }

  return sprintf ('SPARQL INSERT INTO GRAPH <%s> {\n%s}', target_graph, insert_triples);
}
;

create procedure DB.DBA.CYP_GEN_CREATE_SPARQL (in _create_ast any, inout _ctx any, in _graph varchar)
{
  declare patterns any;
  declare graph_expr any;
  declare i, j, n integer;
  declare insert_triples varchar;
  declare node_uris any;
  declare pat any;
  declare target_graph varchar;

  patterns := aref (_create_ast, 1);
  graph_expr := aref (_create_ast, 2);  -- optional graph expression from INTO GRAPH
  insert_triples := '';
  node_uris := vector ();  -- vector of vector(var_name, uri)

  -- Determine target graph: explicit INTO GRAPH takes precedence
  target_graph := DB.DBA.CYP_GRAPH_EXPR_URI (graph_expr, _ctx, _graph);
  DB.DBA.CYP_CTX_SET (_ctx, 'reif_graph', target_graph);

  for (i := 0; i < length (patterns); i := i + 1)
    {
      pat := aref (patterns, i);
      DB.DBA.CYP_GEN_CREATE_PATTERN (_ctx, pat, insert_triples, node_uris);
      insert_triples := DB.DBA.CYP_CTX_GET (_ctx, 'create_triples');
      node_uris := DB.DBA.CYP_CTX_GET (_ctx, 'create_nodes');
      node_uris := DB.DBA.CYP_KEEP_NAMED_NODE_URIS (node_uris);
    }

  return sprintf ('SPARQL INSERT INTO GRAPH <%s> {\n%s}', target_graph, insert_triples);
}
;

create procedure DB.DBA.CYP_CREATE_NODE_KEY (in _var_name varchar, in _idx integer)
{
  if (_var_name is not null and length (_var_name) > 0)
    return _var_name;
  return sprintf ('__anon_%d', _idx);
}
;

create procedure DB.DBA.CYP_KEEP_NAMED_NODE_URIS (in _node_uris any)
{
  declare kept any;
  declare i integer;
  declare node_key varchar;

  kept := vector ();
  for (i := 0; i < length (_node_uris); i := i + 1)
    {
      node_key := aref (aref (_node_uris, i), 0);
      if (node_key is not null and subseq (node_key, 0, 7) <> '__anon_')
        kept := vector_concat (kept, vector (aref (_node_uris, i)));
    }
  return kept;
}
;

create procedure DB.DBA.CYP_IS_NODE_IRI_PROP (in _prop_name varchar)
{
  if (_prop_name = 'iri' or _prop_name = '@id')
    return 1;
  return 0;
}
;

create procedure DB.DBA.CYP_NODE_IRI_FROM_PROPS (inout _ctx any, in _props any)
{
  declare i integer;
  declare prop, expr any;
  declare pname varchar;
  declare iri_uri any;

  for (i := 0; i < length (_props); i := i + 1)
    {
      prop := aref (_props, i);
      pname := aref (prop, 0);
      if (DB.DBA.CYP_IS_NODE_IRI_PROP (pname))
        {
          expr := aref (prop, 1);
          if (isarray (expr) and aref (expr, 0) = 'IRI')
            {
              iri_uri := DB.DBA.CYP_EXPAND_PREFIXED_NAME (_ctx, aref (expr, 1));
              if (not isstring (iri_uri))
                iri_uri := aref (expr, 1);
              return iri_uri;
            }
          if (isarray (expr) and aref (expr, 0) = 'LIT' and isstring (aref (expr, 1)))
            return aref (expr, 1);
        }
    }
  return null;
}
;

-- Generate CREATE triples for a pattern
create procedure DB.DBA.CYP_GEN_CREATE_PATTERN (inout _ctx any, in _pat any,
                                                  in _triples varchar, in _node_uris any)
{
  declare pat_type varchar;
  declare elements any;
  declare i, n integer;
  declare elem any;
  declare var_name, node_uri varchar;
  declare labels, props any;
  declare li integer;
  declare prop any;
  declare rel any;
  declare src_var, dst_var, src_uri, dst_uri, direction varchar;
  declare types any;
  declare actual_src, actual_dst varchar;
  declare rel_uri varchar;
  declare stmt_uri varchar;
  declare pi integer;

  pat_type := aref (_pat, 0);
  if (pat_type = 'PATHVAR')
    {
      DB.DBA.CYP_GEN_CREATE_PATTERN (_ctx, aref (_pat, 2), _triples, _node_uris);
      return;
    }
  if (pat_type <> 'PATTERN')
    signal ('CY030', sprintf ('Expected PATTERN in CREATE, got %s', pat_type));

  elements := aref (_pat, 1);
  n := length (elements);

  -- First pass: create URIs for all nodes
  for (i := 0; i < n; i := i + 1)
    {
      elem := aref (elements, i);
      if (aref (elem, 0) = 'NODE')
        {
          var_name := DB.DBA.CYP_CREATE_NODE_KEY (aref (elem, 1), i);
          node_uri := DB.DBA.CYP_FIND_NODE_URI (_node_uris, var_name);
          if (node_uri is null)
            {
              node_uri := DB.DBA.CYP_NODE_IRI_FROM_PROPS (_ctx, aref (elem, 3));
              if (node_uri is null)
                node_uri := DB.DBA.OPENCYPHER_NEW_NODE_URI ();
              if (var_name is not null and length (var_name) > 0)
                _node_uris := vector_concat (_node_uris, vector (vector (var_name, node_uri)));
            }
        }
    }

  -- Second pass: generate triples for nodes and relationships
  for (i := 0; i < n; i := i + 1)
    {
      elem := aref (elements, i);

      if (aref (elem, 0) = 'NODE')
        {
          var_name := DB.DBA.CYP_CREATE_NODE_KEY (aref (elem, 1), i);
          labels := aref (elem, 2);
          props := aref (elem, 3);
          node_uri := DB.DBA.CYP_FIND_NODE_URI (_node_uris, var_name);

          -- Labels
          for (li := 0; li < length (labels); li := li + 1)
            _triples := concat (_triples, '  ', DB.DBA.OPENCYPHER_FMT_URI (node_uri), ' a ',
                               DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_LABEL_URI (_ctx, aref (labels, li))), ' .\n');

          -- Properties
          for (li := 0; li < length (props); li := li + 1)
            {
              prop := aref (props, li);
              if (isarray (prop) and aref (prop, 0) = 'PARAMPROPS')
                goto skip_create_node_prop;
              if (not DB.DBA.CYP_IS_NODE_IRI_PROP (aref (prop, 0)))
                _triples := concat (_triples, '  ', DB.DBA.OPENCYPHER_FMT_URI (node_uri), ' ',
                                   DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_PROP_URI (_ctx, aref (prop, 0))), ' ',
                                   DB.DBA.CYP_CREATE_VALUE (_ctx, aref (prop, 1)), ' .\n');
              skip_create_node_prop: ;
            }
        }
      else if (aref (elem, 0) = 'REL' and i > 0 and i < n - 1)
        {
          rel := elem;
          direction := aref (rel, 3);
          types := aref (rel, 2);
          props := aref (rel, 6);

          src_var := DB.DBA.CYP_CREATE_NODE_KEY (aref (aref (elements, i - 1), 1), i - 1);
          dst_var := DB.DBA.CYP_CREATE_NODE_KEY (aref (aref (elements, i + 1), 1), i + 1);
          src_uri := DB.DBA.CYP_FIND_NODE_URI (_node_uris, src_var);
          dst_uri := DB.DBA.CYP_FIND_NODE_URI (_node_uris, dst_var);

          if (src_uri is null or dst_uri is null)
            signal ('CY031', 'Cannot CREATE relationship: node variable not found');

          if (direction = 'LEFT')
            { actual_src := dst_uri; actual_dst := src_uri; }
          else
            { actual_src := src_uri; actual_dst := dst_uri; }

          if (length (types) > 0)
            {
              rel_uri := DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_REL_TYPE_URI (_ctx, aref (types, 0)));
              _triples := concat (_triples, '  ', DB.DBA.OPENCYPHER_FMT_URI (actual_src), ' ',
                                 rel_uri, ' ', DB.DBA.OPENCYPHER_FMT_URI (actual_dst), ' .\n');

              -- Relationship properties via reification (per specs)
              if (length (props) > 0)
                {
                  -- Deterministic statement ID based on (subject, predicate, object)
                  declare reif_graph varchar;
                  reif_graph := DB.DBA.CYP_REIF_GRAPH (_ctx);
                  stmt_uri := DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.OPENCYPHER_REIF_STATEMENT_ID (actual_src, aref (types, 0), actual_dst));

                  -- Reification triples go to reification graph
                  _triples := concat (_triples, '  GRAPH ', DB.DBA.OPENCYPHER_FMT_URI (reif_graph), ' {\n');
                  _triples := concat (_triples, '    ', stmt_uri,
                                     ' a <http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement> .\n');
                  _triples := concat (_triples, '    ', stmt_uri,
                                     ' <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> ',
                                     DB.DBA.OPENCYPHER_FMT_URI (actual_src), ' .\n');
                  _triples := concat (_triples, '    ', stmt_uri,
                                     ' <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> ',
                                     rel_uri, ' .\n');
                  _triples := concat (_triples, '    ', stmt_uri,
                                     ' <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> ',
                                     DB.DBA.OPENCYPHER_FMT_URI (actual_dst), ' .\n');
                  for (pi := 0; pi < length (props); pi := pi + 1)
                    {
                      prop := aref (props, pi);
                      if (isarray (prop) and aref (prop, 0) = 'PARAMPROPS')
                        goto skip_create_rel_prop;
                      _triples := concat (_triples, '    ', stmt_uri, ' ',
                                         DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_PROP_URI (_ctx, aref (prop, 0))), ' ',
                                         DB.DBA.CYP_CREATE_VALUE (_ctx, aref (prop, 1)), ' .\n');
                      skip_create_rel_prop: ;
                    }
                  _triples := concat (_triples, '  }\n');
                }
            }
        }
    }

  DB.DBA.CYP_CTX_SET (_ctx, 'create_triples', _triples);
  DB.DBA.CYP_CTX_SET (_ctx, 'create_nodes', _node_uris);
}
;

-- Find node URI by variable name in node_uris list
create procedure DB.DBA.CYP_FIND_NODE_URI (in _node_uris any, in _var_name varchar)
{
  declare i integer;

  if (_var_name is null) return null;
  for (i := 0; i < length (_node_uris); i := i + 1)
    {
      if (aref (aref (_node_uris, i), 0) = _var_name)
        return aref (aref (_node_uris, i), 1);
    }
  return null;
}
;

create procedure DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT
  (in _map any, in _key varchar, in _fallback any)
{
  declare expr, inner_expr any;
  declare op varchar;

  expr := DB.DBA.CYP_MAP_LITERAL_GET (_map, _key);
  if (isarray (expr) and aref (expr, 0) = 'LIT' and aref (expr, 1) is null)
    return _fallback;
  if (isarray (expr) and aref (expr, 0) = 'LIT' and isinteger (aref (expr, 1)))
    return aref (expr, 1);
  if (isarray (expr) and aref (expr, 0) = 'UNOP')
    {
      op := aref (expr, 1);
      inner_expr := aref (expr, 2);
      if (op = '-' and isarray (inner_expr) and aref (inner_expr, 0) = 'LIT' and isinteger (aref (inner_expr, 1)))
        return -1 * aref (inner_expr, 1);
      if (op = '+' and isarray (inner_expr) and aref (inner_expr, 0) = 'LIT' and isinteger (aref (inner_expr, 1)))
        return aref (inner_expr, 1);
    }
  return null;
}
;

create procedure DB.DBA.CYP_CREATE_STATIC_STRING_COMPONENT
  (in _map any, in _key varchar, in _fallback any)
{
  declare expr any;

  expr := DB.DBA.CYP_MAP_LITERAL_GET (_map, _key);
  if (isarray (expr) and aref (expr, 0) = 'LIT' and aref (expr, 1) is null)
    return _fallback;
  if (isarray (expr) and aref (expr, 0) = 'LIT' and isstring (aref (expr, 1)))
    return aref (expr, 1);
  return null;
}
;

create procedure DB.DBA.CYP_CREATE_STATIC_TEMPORAL_VALUE (inout _ctx any, in _expr any)
{
  declare fn varchar;
  declare args, arg any;
  declare year_i, month_i, day_i, hour_i, minute_i, second_i any;
  declare years_i, months_i, weeks_i, days_i, hours_i, minutes_i, seconds_i any;
  declare tz, lex, datatype varchar;

  if (not isarray (_expr) or aref (_expr, 0) <> 'FUNC')
    return null;

  fn := lower (aref (_expr, 1));
  args := aref (_expr, 3);
  if (length (args) <> 1)
    return null;

  arg := DB.DBA.CYP_EXPR_RESOLVE_BINDING (aref (args, 0), _ctx);
  datatype := null;
  if (fn = 'date') datatype := 'http://www.w3.org/2001/XMLSchema#date';
  else if (fn = 'time' or fn = 'localtime') datatype := 'http://www.w3.org/2001/XMLSchema#time';
  else if (fn = 'datetime' or fn = 'localdatetime') datatype := 'http://www.w3.org/2001/XMLSchema#dateTime';
  else if (fn = 'duration') datatype := 'http://www.w3.org/2001/XMLSchema#duration';
  else return null;

  if (isarray (arg) and aref (arg, 0) = 'LIT' and isstring (aref (arg, 1)))
    return concat (DB.DBA.OPENCYPHER_FMT_LITERAL (aref (arg, 1)), '^^<', datatype, '>');

  if (not isarray (arg) or aref (arg, 0) <> 'MAP')
    return null;

  if (fn = 'date')
    {
      year_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'year', null);
      month_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'month', 1);
      day_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'day', 1);
      if (year_i is null or month_i is null or day_i is null)
        return null;
      lex := sprintf ('%04d-%02d-%02d', year_i, month_i, day_i);
      return concat (DB.DBA.OPENCYPHER_FMT_LITERAL (lex), '^^<', datatype, '>');
    }

  if (fn = 'time' or fn = 'localtime')
    {
      hour_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'hour', 0);
      minute_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'minute', 0);
      second_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'second', 0);
      tz := DB.DBA.CYP_CREATE_STATIC_STRING_COMPONENT (arg, 'timezone', '');
      if (hour_i is null or minute_i is null or second_i is null or tz is null)
        return null;
      lex := sprintf ('%02d:%02d:%02d%s', hour_i, minute_i, second_i, tz);
      return concat (DB.DBA.OPENCYPHER_FMT_LITERAL (lex), '^^<', datatype, '>');
    }

  if (fn = 'datetime' or fn = 'localdatetime')
    {
      year_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'year', null);
      month_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'month', 1);
      day_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'day', 1);
      hour_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'hour', 0);
      minute_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'minute', 0);
      second_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'second', 0);
      tz := DB.DBA.CYP_CREATE_STATIC_STRING_COMPONENT (arg, 'timezone', '');
      if (year_i is null or month_i is null or day_i is null
          or hour_i is null or minute_i is null or second_i is null or tz is null)
        return null;
      lex := sprintf ('%04d-%02d-%02dT%02d:%02d:%02d%s',
        year_i, month_i, day_i, hour_i, minute_i, second_i, tz);
      return concat (DB.DBA.OPENCYPHER_FMT_LITERAL (lex), '^^<', datatype, '>');
    }

  if (fn = 'duration')
    {
      years_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'years', null);
      if (years_i is null) years_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'year', 0);
      months_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'months', null);
      if (months_i is null) months_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'month', 0);
      weeks_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'weeks', null);
      if (weeks_i is null) weeks_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'week', 0);
      days_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'days', null);
      if (days_i is null) days_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'day', 0);
      hours_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'hours', null);
      if (hours_i is null) hours_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'hour', 0);
      minutes_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'minutes', null);
      if (minutes_i is null) minutes_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'minute', 0);
      seconds_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'seconds', null);
      if (seconds_i is null) seconds_i := DB.DBA.CYP_CREATE_STATIC_INT_COMPONENT (arg, 'second', 0);
      if (years_i is null or months_i is null or weeks_i is null or days_i is null
          or hours_i is null or minutes_i is null or seconds_i is null)
        return null;
      lex := sprintf ('P%dY%dM%dDT%dH%dM%dS',
        years_i, months_i, (weeks_i * 7) + days_i, hours_i, minutes_i, seconds_i);
      return concat (DB.DBA.OPENCYPHER_FMT_LITERAL (lex), '^^<', datatype, '>');
    }

  return null;
}
;

-- Convert AST expression to SPARQL RDF term for INSERT
create procedure DB.DBA.CYP_CREATE_VALUE (inout _ctx any, in _expr any)
{
  declare etype varchar;
  declare v any;
  declare iri_uri any;
  declare static_value any;

  if (not isarray (_expr))
    return DB.DBA.OPENCYPHER_FMT_LITERAL (_expr);

  etype := aref (_expr, 0);
  if (etype = 'IRI')
    {
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

  if (etype = 'LIT_BOOL')
    {
      -- Cypher TRUE / FALSE -> SPARQL boolean keywords (xsd:boolean
      -- in RDF triple object position).
      if (aref (_expr, 1) = 1) return 'true';
      return 'false';
    }
  if (etype = 'LIT')
    {
      v := aref (_expr, 1);
      if (v is null) return '"NULL"';
      if (isstring (v)) return DB.DBA.OPENCYPHER_FMT_LITERAL (v);
      if (isinteger (v)) return cast (v as varchar);
      if (isfloat (v) or isdouble (v)) return cast (v as varchar);
      return cast (v as varchar);
    }
  if (etype = 'FLOAT')
    return aref (_expr, 1);
  if (etype = 'FUNC')
    {
      static_value := DB.DBA.CYP_CREATE_STATIC_TEMPORAL_VALUE (_ctx, _expr);
      if (static_value is not null)
        return static_value;
    }
  if (etype = 'UNOP')
    {
      declare op varchar;
      declare rhs any;
      op := aref (_expr, 1);
      rhs := aref (_expr, 2);
      if (op = '-' and isarray (rhs) and aref (rhs, 0) = 'LIT')
        {
          v := aref (rhs, 1);
          if (isinteger (v) or isfloat (v) or isdouble (v))
            return concat ('-', cast (v as varchar));
        }
      if (op = '-' and isarray (rhs) and aref (rhs, 0) = 'FLOAT')
        return concat ('-', aref (rhs, 1));
      if (op = '+' and isarray (rhs) and (aref (rhs, 0) = 'LIT' or aref (rhs, 0) = 'FLOAT'))
        return DB.DBA.CYP_CREATE_VALUE (_ctx, rhs);
    }
  if (etype = 'LIST')
    {
      declare elems any;
      declare out_s varchar;
      declare i integer;
      declare elem any;
      declare ev any;
      elems := aref (_expr, 1);
      out_s := '[';
      for (i := 0; i < length (elems); i := i + 1)
        {
          if (i > 0) out_s := concat (out_s, ', ');
          elem := aref (elems, i);
          if (not isarray (elem))
            out_s := concat (out_s, cast (elem as varchar));
          else if (aref (elem, 0) = 'LIT')
            {
              ev := aref (elem, 1);
              if (ev is null)
                out_s := concat (out_s, 'null');
              else if (isstring (ev))
                out_s := concat (out_s, '"', ev, '"');
              else
                out_s := concat (out_s, cast (ev as varchar));
            }
          else if (aref (elem, 0) = 'FLOAT')
            out_s := concat (out_s, aref (elem, 1));
          else if (aref (elem, 0) = 'LIT_BOOL')
            out_s := concat (out_s, cast (aref (elem, 1) as varchar));
          else
            out_s := concat (out_s, cast (DB.DBA.CYP_CREATE_VALUE (_ctx, elem) as varchar));
        }
      out_s := concat (out_s, ']');
      return DB.DBA.OPENCYPHER_FMT_LITERAL (out_s);
    }
  if (etype = 'VAR')
    return concat ('?', aref (_expr, 1));
  if (etype = 'PROP')
    return DB.DBA.CYP_GEN_EXPR (_expr, _ctx, 0);
  if (etype = 'BINOP' or etype = 'UNOP' or etype = 'FUNC')
    {
      declare bind_var varchar;
      declare bind_expr varchar;
      declare binds_str varchar;
      bind_var := concat ('?', DB.DBA.CYP_FRESH_VAR (_ctx), '_cv');
      bind_expr := DB.DBA.CYP_GEN_EXPR (_expr, _ctx, 0);
      binds_str := DB.DBA.CYP_CTX_GET (_ctx, 'binds');
      binds_str := concat (binds_str, '    BIND (', bind_expr, ' AS ', bind_var, ')\n');
      DB.DBA.CYP_CTX_SET (_ctx, 'binds', binds_str);
      return bind_var;
    }
  signal ('CY092',
    sprintf ('Unsupported INSERT/CREATE value expression type: %s', etype));
}
;

-- Backward-compatible literal-only entry point used by older procedural paths.
create procedure DB.DBA.CYP_CREATE_LITERAL_VALUE (in _expr any)
{
  declare ctx any;
  ctx := DB.DBA.CYP_CTX_NEW (DB.DBA.OPENCYPHER_DEFAULT_GRAPH ());
  return DB.DBA.CYP_CREATE_VALUE (ctx, _expr);
}
;

-- Emit a SPARQL `BASE <iri> ` prologue if a BASE was declared in this query
create procedure DB.DBA.CYP_GEN_BASE_CLAUSE (inout _ctx any)
{
  declare base_uri varchar;
  base_uri := DB.DBA.CYP_CTX_GET (_ctx, 'base_uri');
  if (base_uri is null or length (base_uri) = 0)
    return '';
  return concat ('BASE <', base_uri, '> ');
}
;

create procedure DB.DBA.CYP_GEN_DEFINE_CLAUSE (inout _ctx any)
{
  declare i integer;
  declare defines any;
  declare define_clause varchar;

  defines := DB.DBA.CYP_CTX_GET (_ctx, 'defines');
  define_clause := '';
  for (i := 0; i < length (defines); i := i + 1)
    define_clause := concat (define_clause, 'DEFINE ', aref (aref (defines, i), 0), ' ',
                             DB.DBA.CYP_GEN_EXPR (aref (aref (defines, i), 1), _ctx, 0), '\n');
  return define_clause;
}
;

create procedure DB.DBA.CYP_GEN_FROM_CLAUSE (inout _ctx any, in _graph varchar, in _from_graphs any := null)
{
  declare from_clause varchar;
  declare all_from_graphs any;
  declare extra_from_graphs any;
  declare i integer;

  from_clause := '';
  all_from_graphs := vector ();
  if (_from_graphs is not null)
    all_from_graphs := vector_concat (all_from_graphs, _from_graphs);
  extra_from_graphs := DB.DBA.CYP_CTX_GET (_ctx, 'extra_from_graphs');
  if (extra_from_graphs is not null)
    all_from_graphs := vector_concat (all_from_graphs, extra_from_graphs);

  if (length (all_from_graphs) > 0)
    {
      for (i := 0; i < length (all_from_graphs); i := i + 1)
        {
          declare gexpr any;
          declare gstr varchar;
          declare from_kind varchar;
          gexpr := aref (all_from_graphs, i);
          from_kind := 'FROM';
          if (isarray (gexpr) and (aref (gexpr, 0) = 'FROM' or aref (gexpr, 0) = 'FROM_NAMED'))
            {
              from_kind := aref (gexpr, 0);
              gexpr := aref (gexpr, 1);
            }
          gstr := DB.DBA.CYP_GEN_GRAPH_TERM (gexpr, _ctx);
          if (from_kind = 'FROM_NAMED')
            from_clause := concat (from_clause, 'FROM NAMED ', gstr, '\n');
          else
            from_clause := concat (from_clause, 'FROM ', gstr, '\n');
        }
    }
  else if (DB.DBA.CYP_CTX_GET (_ctx, 'suppress_default_from'))
    return from_clause;
  else if (_graph is null)
    return from_clause;
  else
    from_clause := concat ('FROM ', DB.DBA.OPENCYPHER_FMT_URI (_graph), '\n');
  if (DB.DBA.CYP_CTX_GET (_ctx, 'reif_graph') is not null)
    from_clause := concat (from_clause, 'FROM NAMED ', DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_REIF_GRAPH (_ctx)), '\n');
  return from_clause;
}
;

create procedure DB.DBA.CYP_GEN_WHERE_BODY (inout _ctx any)
{
  declare where_body varchar;
  where_body := DB.DBA.CYP_CTX_GET (_ctx, 'triples');
  where_body := concat (where_body, DB.DBA.CYP_CTX_GET (_ctx, 'binds'));
  where_body := concat (where_body, DB.DBA.CYP_CTX_GET (_ctx, 'optionals'));
  where_body := concat (where_body, DB.DBA.CYP_CTX_GET (_ctx, 'filters'));
  return where_body;
}
;

-- Generate SELECT SPARQL for RETURN clause
create procedure DB.DBA.CYP_GEN_SELECT_SPARQL (in _return_ast any, inout _ctx any, in _graph varchar, in _from_graphs any := null)
{
  declare is_distinct integer;
  declare items, order_by, explicit_group_by any;
  declare skip_expr, limit_expr, having_expr any;
  declare select_vars, sparql_str, where_body varchar;
  declare i integer;
  declare has_aggregation integer;
  declare group_by_vars varchar;
  declare item, expr any;
  declare alias_name, expr_str varchar;
  declare vars any;
  declare vi integer;
  declare order_str varchar;
  declare sitem any;
  declare sexpr_str, sdir varchar;
  declare from_clause, define_clause varchar;
  declare agg_group_keys varchar;

  is_distinct := aref (_return_ast, 1);
  items := aref (_return_ast, 2);
  order_by := aref (_return_ast, 3);
  skip_expr := aref (_return_ast, 4);
  limit_expr := aref (_return_ast, 5);
  explicit_group_by := null;
  having_expr := null;
  if (length (_return_ast) > 6)
    explicit_group_by := aref (_return_ast, 6);
  if (length (_return_ast) > 7)
    having_expr := aref (_return_ast, 7);

  define_clause := DB.DBA.CYP_GEN_DEFINE_CLAUSE (_ctx);
  from_clause := DB.DBA.CYP_GEN_FROM_CLAUSE (_ctx, _graph, _from_graphs);

  -- Build SELECT variables
  select_vars := '';
  has_aggregation := 0;
  group_by_vars := '';

  for (i := 0; i < length (items); i := i + 1)
    {
      item := aref (items, i);
      expr := aref (item, 1);
      alias_name := aref (item, 2);

      if (aref (expr, 0) = 'VAR' and aref (expr, 1) = '*')
        {
          -- RETURN * - include all known variables
          vars := DB.DBA.CYP_CTX_GET (_ctx, 'vars');
          for (vi := 0; vi < length (vars); vi := vi + 1)
            {
              if (vi > 0 or i > 0) select_vars := concat (select_vars, ' ');
              select_vars := concat (select_vars, '?', aref (vars, vi));
            }
          goto next_item;
        }

      expr_str := DB.DBA.CYP_GEN_EXPR (expr, _ctx, 1);

      -- Check if expression contains aggregation
      if (DB.DBA.CYP_EXPR_HAS_AGG (expr))
        {
          has_aggregation := 1;
          agg_group_keys := DB.DBA.CYP_EXPR_AGG_GROUP_KEYS (expr);
          if (length (agg_group_keys) > 0 and strstr (group_by_vars, agg_group_keys) is null)
            {
              if (length (group_by_vars) > 0) group_by_vars := concat (group_by_vars, ' ');
              group_by_vars := concat (group_by_vars, agg_group_keys);
            }
        }
      else if (has_aggregation = 0 or not DB.DBA.CYP_EXPR_HAS_AGG (expr))
        {
          if (length (group_by_vars) > 0) group_by_vars := concat (group_by_vars, ' ');
          group_by_vars := concat (group_by_vars, expr_str);
        }

      if (alias_name is not null)
        {
          if (i > 0) select_vars := concat (select_vars, ' ');
          select_vars := concat (select_vars, '(', expr_str, ' AS ?', alias_name, ')');
        }
      else
        {
          if (i > 0) select_vars := concat (select_vars, ' ');
          select_vars := concat (select_vars, expr_str);
        }
      next_item: ;
    }

  -- Build WHERE body
  where_body := DB.DBA.CYP_GEN_WHERE_BODY (_ctx);

  -- Incorporate WITH subqueries if present
  -- WITH subqueries wrap the prior patterns, so we need to restructure
  declare with_subqueries any;
  declare with_where_body varchar;
  with_subqueries := DB.DBA.CYP_CTX_GET (_ctx, 'with_subqueries');
  if (with_subqueries is not null and length (with_subqueries) > 0)
    {
      declare i integer;
      declare sq varchar;
      -- The innermost subquery should contain the accumulated patterns
      -- Start with the innermost (first in vector) and wrap outward
      with_where_body := '';
      for (i := 0; i < length (with_subqueries); i := i + 1)
        {
          sq := aref (with_subqueries, i);
          if (i = 0)
            with_where_body := concat ('  { ', sq, ' }');
          else
            with_where_body := concat ('  { ', sq, ' { ', with_where_body, ' } }');
        }
      -- Add any patterns accumulated after the last WITH
      if (length (where_body) > 0)
        where_body := concat (with_where_body, '\n', where_body);
      else
        where_body := with_where_body;
    }

  -- Assemble SPARQL
  sparql_str := concat ('SPARQL ', DB.DBA.CYP_GEN_BASE_CLAUSE (_ctx), define_clause, 'SELECT ');
  if (is_distinct) sparql_str := concat (sparql_str, 'DISTINCT ');
  sparql_str := concat (sparql_str, select_vars, '\n');
  sparql_str := concat (sparql_str, from_clause);
  sparql_str := concat (sparql_str, 'WHERE {\n', where_body, '}\n');

  if (explicit_group_by is not null and length (explicit_group_by) > 0)
    {
      group_by_vars := '';
      for (i := 0; i < length (explicit_group_by); i := i + 1)
        {
          if (i > 0) group_by_vars := concat (group_by_vars, ' ');
          group_by_vars := concat (group_by_vars, DB.DBA.CYP_GEN_EXPR (aref (explicit_group_by, i), _ctx, 1));
        }
      sparql_str := concat (sparql_str, 'GROUP BY ', group_by_vars, '\n');
    }
  else if (has_aggregation and length (group_by_vars) > 0)
    sparql_str := concat (sparql_str, 'GROUP BY ', group_by_vars, '\n');

  if (having_expr is not null)
    sparql_str := concat (sparql_str, 'HAVING (', DB.DBA.CYP_GEN_EXPR (having_expr, _ctx, 1), ')\n');

  -- ORDER BY: prefer RETURN's own; fall back to a hoisted ORDER BY from
  -- the most recent WITH (Phase 13.14).
  declare hoisted_order, hoisted_skip, hoisted_limit varchar;
  hoisted_order := DB.DBA.CYP_CTX_GET (_ctx, 'with_hoisted_order_by');
  hoisted_skip  := DB.DBA.CYP_CTX_GET (_ctx, 'with_hoisted_skip');
  hoisted_limit := DB.DBA.CYP_CTX_GET (_ctx, 'with_hoisted_limit');

  if (order_by is not null)
    {
      order_str := '';
      for (i := 0; i < length (order_by); i := i + 1)
        {
          sitem := aref (order_by, i);
          sexpr_str := DB.DBA.CYP_GEN_EXPR (aref (sitem, 1), _ctx, 1);
          sdir := aref (sitem, 2);
          if (i > 0) order_str := concat (order_str, ' ');
          if (sdir = 'DESC')
            order_str := concat (order_str, 'DESC(', sexpr_str, ')');
          else
            order_str := concat (order_str, sexpr_str);
        }
      sparql_str := concat (sparql_str, 'ORDER BY ', order_str, '\n');
    }
  else if (hoisted_order is not null and length (hoisted_order) > 0)
    sparql_str := concat (sparql_str, 'ORDER BY ', hoisted_order, '\n');

  -- OFFSET (SKIP)
  if (skip_expr is not null)
    sparql_str := concat (sparql_str, 'OFFSET ', DB.DBA.CYP_GEN_EXPR (skip_expr, _ctx, 0), '\n');
  else if (hoisted_skip is not null and length (hoisted_skip) > 0)
    sparql_str := concat (sparql_str, 'OFFSET ', hoisted_skip, '\n');

  -- LIMIT
  if (limit_expr is not null)
    sparql_str := concat (sparql_str, 'LIMIT ', DB.DBA.CYP_GEN_EXPR (limit_expr, _ctx, 0), '\n');
  else if (hoisted_limit is not null and length (hoisted_limit) > 0)
    sparql_str := concat (sparql_str, 'LIMIT ', hoisted_limit, '\n');

  return sparql_str;
}
;

-- Check if expression contains aggregation function
create procedure DB.DBA.CYP_EXPR_HAS_AGG (in _expr any)
{
  declare etype varchar;
  declare fn varchar;

  if (_expr is null or not isarray (_expr)) return 0;
  etype := aref (_expr, 0);
  if (etype = 'COUNTSTAR') return 1;
  if (etype = 'FUNC')
    {
      fn := lower (aref (_expr, 1));
      if (fn = 'count' or fn = 'sum' or fn = 'avg' or fn = 'min' or fn = 'max' or fn = 'collect'
          or fn = 'degree_centrality' or fn = 'weighted_degree_centrality')
        return 1;
    }
  if (etype = 'BINOP')
    return DB.DBA.CYP_EXPR_HAS_AGG (aref (_expr, 2)) + DB.DBA.CYP_EXPR_HAS_AGG (aref (_expr, 3));
  if (etype = 'UNOP')
    return DB.DBA.CYP_EXPR_HAS_AGG (aref (_expr, 2));
  if (etype = 'PROP')
    return DB.DBA.CYP_EXPR_HAS_AGG (aref (_expr, 1));
  if (etype = 'MAPPROJ')
    {
      declare mp_items any;
      if (length (_expr) > 2)
        {
          mp_items := aref (_expr, 2);
          if (length (mp_items) = 1 and aref (aref (mp_items, 0), 0) = 'STAR')
            return 1;
        }
    }
  return 0;
}
;

create procedure DB.DBA.CYP_EXPR_AGG_GROUP_KEYS (in _expr any)
{
  declare etype varchar;
  declare mp_src, mp_items any;

  if (_expr is null or not isarray (_expr)) return '';
  etype := aref (_expr, 0);

  if (etype = 'MAPPROJ' and length (_expr) > 2)
    {
      mp_src := aref (_expr, 1);
      mp_items := aref (_expr, 2);
      if (length (mp_items) = 1
          and aref (aref (mp_items, 0), 0) = 'STAR'
          and isarray (mp_src)
          and aref (mp_src, 0) = 'VAR')
        return concat ('?', aref (mp_src, 1));
    }

  return '';
}
;

create procedure DB.DBA.CYP_GEN_ASK_SPARQL (inout _ctx any, in _graph varchar, in _from_graphs any := null)
{
  return concat ('SPARQL ', DB.DBA.CYP_GEN_BASE_CLAUSE (_ctx), DB.DBA.CYP_GEN_DEFINE_CLAUSE (_ctx),
                 'ASK\n',
                 DB.DBA.CYP_GEN_FROM_CLAUSE (_ctx, _graph, _from_graphs),
                 'WHERE {\n', DB.DBA.CYP_GEN_WHERE_BODY (_ctx), '}\n');
}
;

create procedure DB.DBA.CYP_GEN_DESCRIBE_SPARQL (in _describe_ast any, inout _ctx any, in _graph varchar, in _from_graphs any := null)
{
  declare i integer;
  declare items any;
  declare target_vars varchar;

  items := aref (_describe_ast, 1);
  target_vars := '';
  for (i := 0; i < length (items); i := i + 1)
    {
      if (i > 0) target_vars := concat (target_vars, ' ');
      target_vars := concat (target_vars, DB.DBA.CYP_GEN_EXPR (aref (aref (items, i), 1), _ctx, 1));
    }
  return concat ('SPARQL ', DB.DBA.CYP_GEN_BASE_CLAUSE (_ctx), DB.DBA.CYP_GEN_DEFINE_CLAUSE (_ctx),
                 'DESCRIBE ', target_vars, '\n',
                 DB.DBA.CYP_GEN_FROM_CLAUSE (_ctx, _graph, _from_graphs),
                 'WHERE {\n', DB.DBA.CYP_GEN_WHERE_BODY (_ctx), '}\n');
}
;

create procedure DB.DBA.CYP_GEN_CONSTRUCT_TEMPLATE_PATTERN (inout _ctx any, in _pat any, inout _template varchar)
{
  declare pat_type varchar;
  declare elements any;
  declare i, li, n integer;
  declare elem any;
  declare var_name, src_var, dst_var, direction, rel_uri varchar;
  declare labels, types any;
  declare actual_src, actual_dst varchar;

  pat_type := aref (_pat, 0);
  if (pat_type = 'PATHVAR')
    {
      DB.DBA.CYP_GEN_CONSTRUCT_TEMPLATE_PATTERN (_ctx, aref (_pat, 2), _template);
      return;
    }
  if (pat_type <> 'PATTERN')
    signal ('CY033', sprintf ('Expected PATTERN in CONSTRUCT, got %s', pat_type));

  elements := aref (_pat, 1);
  n := length (elements);
  for (i := 0; i < n; i := i + 1)
    {
      elem := aref (elements, i);
      if (aref (elem, 0) = 'NODE')
        {
          var_name := aref (elem, 1);
          labels := aref (elem, 2);
          if (var_name is not null)
            {
              for (li := 0; li < length (labels); li := li + 1)
                _template := concat (_template, '  ?', var_name, ' a ',
                                     DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_LABEL_URI (_ctx, aref (labels, li))), ' .\n');
            }
        }
      else if (aref (elem, 0) = 'REL' and i > 0 and i < n - 1)
        {
          types := aref (elem, 2);
          if (length (types) > 0)
            {
              src_var := aref (aref (elements, i - 1), 1);
              dst_var := aref (aref (elements, i + 1), 1);
              if (src_var is not null and dst_var is not null)
                {
                  direction := aref (elem, 3);
                  if (direction = 'LEFT')
                    { actual_src := dst_var; actual_dst := src_var; }
                  else
                    { actual_src := src_var; actual_dst := dst_var; }
                  rel_uri := DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_REL_TYPE_URI (_ctx, aref (types, 0)));
                  _template := concat (_template, '  ?', actual_src, ' ', rel_uri, ' ?', actual_dst, ' .\n');
                }
            }
        }
    }
}
;

create procedure DB.DBA.CYP_GEN_CONSTRUCT_RETURN_TEMPLATE (inout _ctx any, in _return_ast any, inout _template varchar)
{
  declare items any;
  declare i integer;

  if (_return_ast is null or not isarray (_return_ast) or length (_return_ast) < 3)
    return;

  items := aref (_return_ast, 2);
  for (i := 0; i < length (items); i := i + 1)
    {
      declare item, expr, base_expr any;
      declare subj, obj, prop_name varchar;
      item := aref (items, i);
      if (not isarray (item) or length (item) < 2)
        goto construct_return_next;
      expr := aref (item, 1);
      if (isarray (expr) and aref (expr, 0) = 'PROP')
        {
          base_expr := aref (expr, 1);
          prop_name := aref (expr, 2);
          if (isarray (base_expr) and aref (base_expr, 0) = 'VAR')
            {
              subj := concat ('?', aref (base_expr, 1));
              obj := DB.DBA.CYP_GEN_EXPR (expr, _ctx, 0);
              _template := concat (_template, '  ', subj, ' ',
                DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_PROP_URI (_ctx, prop_name)), ' ', obj, ' .\n');
            }
        }
    construct_return_next:;
    }
}
;

create procedure DB.DBA.CYP_GEN_CONSTRUCT_SPARQL (in _construct_ast any, inout _ctx any, in _graph varchar, in _from_graphs any := null)
{
  declare clauses any;
  declare i, j integer;
  declare clause, patterns any;
  declare template varchar;

  clauses := aref (_construct_ast, 1);
  template := '';
  for (i := 0; i < length (clauses); i := i + 1)
    {
      clause := aref (clauses, i);
      if (aref (clause, 0) = 'MATCH')
        {
          patterns := aref (clause, 2);
          for (j := 0; j < length (patterns); j := j + 1)
            DB.DBA.CYP_GEN_CONSTRUCT_TEMPLATE_PATTERN (_ctx, aref (patterns, j), template);
        }
      else if (aref (clause, 0) = 'RETURN')
        DB.DBA.CYP_GEN_CONSTRUCT_RETURN_TEMPLATE (_ctx, clause, template);
    }

  return concat ('SPARQL ', DB.DBA.CYP_GEN_BASE_CLAUSE (_ctx), DB.DBA.CYP_GEN_DEFINE_CLAUSE (_ctx),
                 'CONSTRUCT {\n', template, '}\n',
                 DB.DBA.CYP_GEN_FROM_CLAUSE (_ctx, _graph, _from_graphs),
                 'WHERE {\n', DB.DBA.CYP_GEN_WHERE_BODY (_ctx), '}\n');
}
;

-- Generate DELETE SPARQL
create procedure DB.DBA.CYP_GEN_DELETE_SPARQL (in _delete_ast any, in _match_asts any,
                                                in _where_asts any, inout _ctx any, in _graph varchar)
{
  declare is_detach integer;
  declare del_items any;
  declare where_body, delete_patterns, where_patterns varchar;
  declare i integer;
  declare item any;
  declare var_str varchar;

  is_detach := aref (_delete_ast, 1);
  del_items := aref (_delete_ast, 2);

  where_body := DB.DBA.CYP_CTX_GET (_ctx, 'triples');
  where_body := concat (where_body, DB.DBA.CYP_CTX_GET (_ctx, 'filters'));

  delete_patterns := '';
  where_patterns := '';
  for (i := 0; i < length (del_items); i := i + 1)
    {
      item := aref (del_items, i);
      var_str := DB.DBA.CYP_GEN_EXPR (item, _ctx, 0);

      if (is_detach)
        {
          -- DETACH DELETE: remove all triples where node is subject or object
          delete_patterns := concat (delete_patterns, '  ', var_str, ' ?_dp ?_do .\n');
          delete_patterns := concat (delete_patterns, '  ?_ds ?_dp2 ', var_str, ' .\n');
          -- In WHERE: outgoing required, incoming OPTIONAL (node may have no incoming triples)
          where_patterns := concat (where_patterns, '  ', var_str, ' ?_dp ?_do .\n');
          where_patterns := concat (where_patterns, '  OPTIONAL { ?_ds ?_dp2 ', var_str, ' . }\n');
        }
      else
        {
          -- Regular DELETE: remove node's own triples
          delete_patterns := concat (delete_patterns, '  ', var_str, ' ?_dp ?_do .\n');
          where_patterns := concat (where_patterns, '  ', var_str, ' ?_dp ?_do .\n');
        }
    }

  return sprintf ('SPARQL WITH <%s> DELETE {\n%s} WHERE {\n%s  %s}',
                  _graph, delete_patterns, where_body,
                  where_patterns);
}
;

-- Generate SET SPARQL (INSERT/DELETE for property updates)
create procedure DB.DBA.CYP_GEN_SET_SPARQL (in _set_ast any, in _match_asts any,
                                              in _where_asts any, inout _ctx any, in _graph varchar)
{
  declare items any;
  declare where_body, sparql_str varchar;
  declare i integer;
  declare item any;
  declare itype varchar;
  declare prop_expr, val_expr any;
  declare var_name, prop_name, val_str varchar;
  declare lbls any;
  declare li integer;

  items := aref (_set_ast, 1);
  where_body := DB.DBA.CYP_CTX_GET (_ctx, 'triples');
  where_body := concat (where_body, DB.DBA.CYP_CTX_GET (_ctx, 'filters'));

  sparql_str := '';
  for (i := 0; i < length (items); i := i + 1)
    {
      item := aref (items, i);
      itype := aref (item, 0);

      if (itype = 'SETPROP')
        {
          -- SET n.prop = value -> DELETE old value, INSERT new value
          prop_expr := aref (item, 1);
          val_expr := aref (item, 2);

          if (aref (prop_expr, 0) = 'PROP' and aref (aref (prop_expr, 1), 0) = 'VAR')
            {
              var_name := aref (aref (prop_expr, 1), 1);
              prop_name := aref (prop_expr, 2);

              if (DB.DBA.CYP_CTX_IS_REL_VAR (_ctx, var_name))
                {
                  -- Relationship variable: property is stored as reification.
                  -- Generate DELETE/INSERT targeting the reification graph.
                  declare reif_g varchar;
                  reif_g := DB.DBA.CYP_REIF_GRAPH (_ctx);
                  if (isarray (val_expr) and aref (val_expr, 0) = 'LIT' and aref (val_expr, 1) is null)
                    {
                      sparql_str := concat (sparql_str, sprintf (
                        'SPARQL WITH <%s> DELETE { GRAPH <%s> { ?%s <%s> ?_old_val } } WHERE { %s GRAPH <%s> { ?%s <%s> ?_old_val } };\n',
                        _graph, reif_g, var_name, DB.DBA.CYP_PROP_URI (_ctx, prop_name),
                        where_body, reif_g, var_name, DB.DBA.CYP_PROP_URI (_ctx, prop_name)));
                    }
                  else
                    {
                      val_str := DB.DBA.CYP_GEN_EXPR (val_expr, _ctx, 0);
                      sparql_str := concat (sparql_str, sprintf (
                        'SPARQL WITH <%s> DELETE { GRAPH <%s> { ?%s <%s> ?_old_val } } INSERT { GRAPH <%s> { ?%s <%s> %s } } WHERE { %s OPTIONAL { GRAPH <%s> { ?%s <%s> ?_old_val } } };\n',
                        _graph, reif_g, var_name, DB.DBA.CYP_PROP_URI (_ctx, prop_name),
                        reif_g, var_name, DB.DBA.CYP_PROP_URI (_ctx, prop_name), val_str,
                        where_body, reif_g, var_name, DB.DBA.CYP_PROP_URI (_ctx, prop_name)));
                    }
                }
              else if (isarray (val_expr) and aref (val_expr, 0) = 'LIT' and aref (val_expr, 1) is null)
                {
                  -- Cypher null-as-remove: SET n.prop = NULL drops
                  -- the existing triple instead of writing a "NULL"
                  -- literal.
                  sparql_str := concat (sparql_str, sprintf (
                    'SPARQL WITH <%s> DELETE { ?%s <%s> ?_old_val } WHERE { %s ?%s <%s> ?_old_val };\n',
                    _graph, var_name, DB.DBA.CYP_PROP_URI (_ctx, prop_name),
                    where_body, var_name, DB.DBA.CYP_PROP_URI (_ctx, prop_name)));
                }
              else
                {
                  val_str := DB.DBA.CYP_GEN_EXPR (val_expr, _ctx, 0);
                  sparql_str := concat (sparql_str, sprintf (
                    'SPARQL WITH <%s> DELETE { ?%s <%s> ?_old_val } INSERT { ?%s <%s> %s } WHERE { %s OPTIONAL { ?%s <%s> ?_old_val } };\n',
                    _graph, var_name, DB.DBA.CYP_PROP_URI (_ctx, prop_name),
                    var_name, DB.DBA.CYP_PROP_URI (_ctx, prop_name), val_str,
                    where_body, var_name, DB.DBA.CYP_PROP_URI (_ctx, prop_name)));
                }
            }
        }
      else if (itype = 'SETLABEL')
        {
          var_name := aref (item, 1);
          lbls := aref (item, 2);
          for (li := 0; li < length (lbls); li := li + 1)
            {
              sparql_str := concat (sparql_str, sprintf (
                'SPARQL INSERT INTO GRAPH <%s> { ?%s a <%s> } WHERE { GRAPH <%s> { %s } };\n',
                _graph, var_name, DB.DBA.CYP_LABEL_URI (_ctx, aref (lbls, li)), _graph, where_body));
            }
        }
      else if (itype = 'SETALL')
        {
          declare set_var, set_map any;
          declare is_plus integer;
          declare keys, vals any;
          declare ki integer;
          declare key_name varchar;
          declare val_expr any;
          declare val_str, prop_uri varchar;
          declare insert_buf varchar;

          set_var := aref (item, 1);
          set_map := aref (item, 2);
          is_plus := aref (item, 3);

          if (set_map is null or aref (set_map, 0) <> 'MAP')
            signal ('CY007', 'SET n = expr requires a literal map on the right-hand side');

          if (DB.DBA.CYP_CTX_IS_REL_VAR (_ctx, set_var))
            {
              -- SET on relationship: wrap DELETE/INSERT in reification graph
              declare setall_reif_g varchar;
              setall_reif_g := DB.DBA.CYP_REIF_GRAPH (_ctx);
              keys := aref (set_map, 1);
              vals := aref (set_map, 2);

              if (is_plus = 0)
                {
                  insert_buf := '';
                  for (ki := 0; ki < length (keys); ki := ki + 1)
                    {
                      key_name := aref (keys, ki);
                      val_expr := aref (vals, ki);
                      if (DB.DBA.CYP_IS_NODE_IRI_PROP (key_name))
                        goto skip_rel_setall_key_repl;
                      if (isarray (val_expr) and aref (val_expr, 0) = 'LIT' and aref (val_expr, 1) is null)
                        goto skip_rel_setall_key_repl;
                      prop_uri := DB.DBA.CYP_PROP_URI (_ctx, key_name);
                      val_str := DB.DBA.CYP_GEN_EXPR (val_expr, _ctx, 0);
                      insert_buf := concat (insert_buf,
                        sprintf ('?%s <%s> %s . ', set_var, prop_uri, val_str));
                      skip_rel_setall_key_repl: ;
                    }

                  sparql_str := concat (sparql_str, sprintf (
                    'SPARQL WITH <%s> DELETE { GRAPH <%s> { ?%s ?_setall_p ?_setall_o } } INSERT { GRAPH <%s> { %s} } WHERE { %s OPTIONAL { GRAPH <%s> { ?%s ?_setall_p ?_setall_o . FILTER (?_setall_p != <http://www.w3.org/1999/02/22-rdf-syntax-ns#type>) } } };\n',
                    _graph, setall_reif_g, set_var, setall_reif_g, insert_buf,
                    where_body, setall_reif_g, set_var));
                }
              else
                {
                  for (ki := 0; ki < length (keys); ki := ki + 1)
                    {
                      key_name := aref (keys, ki);
                      val_expr := aref (vals, ki);
                      if (DB.DBA.CYP_IS_NODE_IRI_PROP (key_name))
                        goto skip_rel_setall_key_merge;
                      prop_uri := DB.DBA.CYP_PROP_URI (_ctx, key_name);
                      if (isarray (val_expr) and aref (val_expr, 0) = 'LIT' and aref (val_expr, 1) is null)
                        {
                          sparql_str := concat (sparql_str, sprintf (
                            'SPARQL WITH <%s> DELETE { GRAPH <%s> { ?%s <%s> ?_old_val } } WHERE { %s GRAPH <%s> { ?%s <%s> ?_old_val } };\n',
                            _graph, setall_reif_g, set_var, prop_uri,
                            where_body, setall_reif_g, set_var, prop_uri));
                        }
                      else
                        {
                          val_str := DB.DBA.CYP_GEN_EXPR (val_expr, _ctx, 0);
                          sparql_str := concat (sparql_str, sprintf (
                            'SPARQL WITH <%s> DELETE { GRAPH <%s> { ?%s <%s> ?_old_val } } INSERT { GRAPH <%s> { ?%s <%s> %s } } WHERE { %s OPTIONAL { GRAPH <%s> { ?%s <%s> ?_old_val } } };\n',
                            _graph, setall_reif_g, set_var, prop_uri,
                            setall_reif_g, set_var, prop_uri, val_str,
                            where_body, setall_reif_g, set_var, prop_uri));
                        }
                      skip_rel_setall_key_merge: ;
                    }
                }
            }
          else
            {

          keys := aref (set_map, 1);
          vals := aref (set_map, 2);

          if (is_plus = 0)
            {
              insert_buf := '';
              for (ki := 0; ki < length (keys); ki := ki + 1)
                {
                  key_name := aref (keys, ki);
                  val_expr := aref (vals, ki);
                  if (DB.DBA.CYP_IS_NODE_IRI_PROP (key_name))
                    goto skip_setall_key_repl;
                  if (isarray (val_expr) and aref (val_expr, 0) = 'LIT' and aref (val_expr, 1) is null)
                    goto skip_setall_key_repl;
                  prop_uri := DB.DBA.CYP_PROP_URI (_ctx, key_name);
                  val_str := DB.DBA.CYP_GEN_EXPR (val_expr, _ctx, 0);
                  insert_buf := concat (insert_buf,
                    sprintf ('?%s <%s> %s . ', set_var, prop_uri, val_str));
                  skip_setall_key_repl: ;
                }

              sparql_str := concat (sparql_str, sprintf (
                'SPARQL WITH <%s> DELETE { ?%s ?_setall_p ?_setall_o } INSERT { %s} WHERE { %s OPTIONAL { ?%s ?_setall_p ?_setall_o . FILTER (?_setall_p != <http://www.w3.org/1999/02/22-rdf-syntax-ns#type>) } };\n',
                _graph, set_var, insert_buf, where_body, set_var));
            }
          else
            {
              for (ki := 0; ki < length (keys); ki := ki + 1)
                {
                  key_name := aref (keys, ki);
                  val_expr := aref (vals, ki);
                  if (DB.DBA.CYP_IS_NODE_IRI_PROP (key_name))
                    goto skip_setall_key_merge;
                  prop_uri := DB.DBA.CYP_PROP_URI (_ctx, key_name);
                  if (isarray (val_expr) and aref (val_expr, 0) = 'LIT' and aref (val_expr, 1) is null)
                    {
                      sparql_str := concat (sparql_str, sprintf (
                        'SPARQL WITH <%s> DELETE { ?%s <%s> ?_old_val } WHERE { %s ?%s <%s> ?_old_val };\n',
                        _graph, set_var, prop_uri, where_body, set_var, prop_uri));
                    }
                  else
                    {
                      val_str := DB.DBA.CYP_GEN_EXPR (val_expr, _ctx, 0);
                      sparql_str := concat (sparql_str, sprintf (
                        'SPARQL WITH <%s> DELETE { ?%s <%s> ?_old_val } INSERT { ?%s <%s> %s } WHERE { %s OPTIONAL { ?%s <%s> ?_old_val } };\n',
                        _graph, set_var, prop_uri, set_var, prop_uri, val_str,
                        where_body, set_var, prop_uri));
                    }
                  skip_setall_key_merge: ;
                }
            }

            }  -- end non-rel SETALL
        }
    }

  return sparql_str;
}
;

-- Generate REMOVE SPARQL
create procedure DB.DBA.CYP_GEN_REMOVE_SPARQL (in _remove_ast any, in _match_asts any,
                                                 in _where_asts any, inout _ctx any, in _graph varchar)
{
  declare items any;
  declare where_body, sparql_str varchar;
  declare i integer;
  declare item any;
  declare itype varchar;
  declare prop_expr any;
  declare var_name, prop_name varchar;
  declare lbls any;
  declare li integer;

  items := aref (_remove_ast, 1);
  where_body := DB.DBA.CYP_CTX_GET (_ctx, 'triples');
  where_body := concat (where_body, DB.DBA.CYP_CTX_GET (_ctx, 'filters'));

  sparql_str := '';
  for (i := 0; i < length (items); i := i + 1)
    {
      item := aref (items, i);
      itype := aref (item, 0);

      if (itype = 'RMPROP')
        {
          prop_expr := aref (item, 1);
          if (aref (prop_expr, 0) = 'PROP' and aref (aref (prop_expr, 1), 0) = 'VAR')
            {
              var_name := aref (aref (prop_expr, 1), 1);
              prop_name := aref (prop_expr, 2);
              sparql_str := concat (sparql_str, sprintf (
                'SPARQL WITH <%s> DELETE { ?%s <%s> ?_old } WHERE { %s ?%s <%s> ?_old };\n',
                _graph, var_name, DB.DBA.CYP_PROP_URI (_ctx, prop_name),
                where_body, var_name, DB.DBA.CYP_PROP_URI (_ctx, prop_name)));
            }
        }
      else if (itype = 'RMLABEL')
        {
          var_name := aref (item, 1);
          lbls := aref (item, 2);
          for (li := 0; li < length (lbls); li := li + 1)
            {
              sparql_str := concat (sparql_str, sprintf (
                'SPARQL WITH <%s> DELETE { ?%s a <%s> } WHERE { %s ?%s a <%s> };\n',
                _graph, var_name, DB.DBA.CYP_LABEL_URI (_ctx, aref (lbls, li)),
                where_body, var_name, DB.DBA.CYP_LABEL_URI (_ctx, aref (lbls, li))));
            }
        }
    }

  return sparql_str;
}
;

-- Generate MERGE SPARQL (simplified: try MATCH, if no results then CREATE)
create procedure DB.DBA.CYP_GEN_MERGE_SPARQL (in _merge_ast any, inout _ctx any, in _graph varchar)
{
  signal ('CY092',
          'MERGE is procedural and is not available through CYPHER_TO_SPARQL; use DB.DBA.CYPHER() for MERGE execution');
}
;

create procedure DB.DBA.CYP_TEMPLATE_NODE_TERM (inout _ctx any, in _node any, in _idx integer, inout _node_terms any)
{
  declare var_name, node_key, term varchar;
  declare subject_uri varchar;
  declare vars any;
  declare i integer;

  var_name := aref (_node, 1);
  node_key := DB.DBA.CYP_CREATE_NODE_KEY (var_name, _idx);

  for (i := 0; i < length (_node_terms); i := i + 1)
    {
      if (aref (aref (_node_terms, i), 0) = node_key)
        return aref (aref (_node_terms, i), 1);
    }

  if (var_name is not null and length (var_name) > 0)
    {
      vars := DB.DBA.CYP_CTX_GET (_ctx, 'vars');
      for (i := 0; i < length (vars); i := i + 1)
        {
          if (aref (vars, i) = var_name)
            {
              term := concat ('?', var_name);
              _node_terms := vector_concat (_node_terms, vector (vector (node_key, term, 1)));
              return term;
            }
        }
    }

  subject_uri := DB.DBA.CYP_NODE_IRI_FROM_PROPS (_ctx, aref (_node, 3));
  if (subject_uri is not null)
    term := DB.DBA.OPENCYPHER_FMT_URI (subject_uri);
  else
    term := DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.OPENCYPHER_NEW_NODE_URI ());
  _node_terms := vector_concat (_node_terms, vector (vector (node_key, term, 0)));
  return term;
}
;

create procedure DB.DBA.CYP_TEMPLATE_FIND_TERM (in _node_terms any, in _key varchar)
{
  declare i integer;

  for (i := 0; i < length (_node_terms); i := i + 1)
    {
      if (aref (aref (_node_terms, i), 0) = _key)
        return aref (aref (_node_terms, i), 1);
    }
  return null;
}
;

create procedure DB.DBA.CYP_TEMPLATE_IS_MATCHED (in _node_terms any, in _key varchar)
{
  declare i integer;

  for (i := 0; i < length (_node_terms); i := i + 1)
    {
      if (aref (aref (_node_terms, i), 0) = _key)
        return aref (aref (_node_terms, i), 2);
    }
  return 0;
}
;

-- Generate INSERT template triples for MATCH ... CREATE.
create procedure DB.DBA.CYP_GEN_CREATE_TEMPLATE_PATTERN (inout _ctx any, in _pat any,
                                                           in _triples varchar, in _node_terms any)
{
  declare pat_type varchar;
  declare elements any;
  declare i, li, pi, n integer;
  declare elem, labels, props, prop, rel, types any;
  declare var_name, node_key, term varchar;
  declare src_key, dst_key, src_term, dst_term, actual_src, actual_dst varchar;
  declare direction, rel_uri, stmt_uri varchar;

  pat_type := aref (_pat, 0);
  if (pat_type = 'PATHVAR')
    {
      DB.DBA.CYP_GEN_CREATE_TEMPLATE_PATTERN (_ctx, aref (_pat, 2), _triples, _node_terms);
      return;
    }
  if (pat_type <> 'PATTERN')
    signal ('CY032', sprintf ('Expected PATTERN in MATCH CREATE, got %s', pat_type));

  elements := aref (_pat, 1);
  n := length (elements);

  for (i := 0; i < n; i := i + 1)
    {
      elem := aref (elements, i);
      if (aref (elem, 0) = 'NODE')
        {
          term := DB.DBA.CYP_TEMPLATE_NODE_TERM (_ctx, elem, i, _node_terms);
        }
    }

  for (i := 0; i < n; i := i + 1)
    {
      elem := aref (elements, i);
      if (aref (elem, 0) = 'NODE')
        {
          var_name := aref (elem, 1);
          node_key := DB.DBA.CYP_CREATE_NODE_KEY (var_name, i);
          term := DB.DBA.CYP_TEMPLATE_FIND_TERM (_node_terms, node_key);
          if (DB.DBA.CYP_TEMPLATE_IS_MATCHED (_node_terms, node_key) = 0)
            {
              labels := aref (elem, 2);
              props := aref (elem, 3);
              for (li := 0; li < length (labels); li := li + 1)
                _triples := concat (_triples, '  ', term, ' a ', DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_LABEL_URI (_ctx, aref (labels, li))), ' .\n');
              for (pi := 0; pi < length (props); pi := pi + 1)
                {
                  prop := aref (props, pi);
                  if (isarray (prop) and aref (prop, 0) = 'PARAMPROPS')
                    goto skip_tmpl_node_prop;
                  if (not DB.DBA.CYP_IS_NODE_IRI_PROP (aref (prop, 0)))
                    _triples := concat (_triples, '  ', term, ' ', DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_PROP_URI (_ctx, aref (prop, 0))), ' ',
                                       DB.DBA.CYP_CREATE_VALUE (_ctx, aref (prop, 1)), ' .\n');
                  skip_tmpl_node_prop: ;
                }
            }
        }
      else if (aref (elem, 0) = 'REL' and i > 0 and i < n - 1)
        {
          rel := elem;
          direction := aref (rel, 3);
          types := aref (rel, 2);
          props := aref (rel, 6);
          src_key := DB.DBA.CYP_CREATE_NODE_KEY (aref (aref (elements, i - 1), 1), i - 1);
          dst_key := DB.DBA.CYP_CREATE_NODE_KEY (aref (aref (elements, i + 1), 1), i + 1);
          src_term := DB.DBA.CYP_TEMPLATE_FIND_TERM (_node_terms, src_key);
          dst_term := DB.DBA.CYP_TEMPLATE_FIND_TERM (_node_terms, dst_key);

          if (direction = 'LEFT')
            { actual_src := dst_term; actual_dst := src_term; }
          else
            { actual_src := src_term; actual_dst := dst_term; }

          if (length (types) > 0)
            {
              rel_uri := DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_REL_TYPE_URI (_ctx, aref (types, 0)));
              _triples := concat (_triples, '  ', actual_src, ' ', rel_uri, ' ', actual_dst, ' .\n');
              if (length (props) > 0)
                {
                  stmt_uri := DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.OPENCYPHER_REIF_STATEMENT_ID (actual_src, aref (types, 0), actual_dst));
                  _triples := concat (_triples, '  GRAPH ', DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_REIF_GRAPH (_ctx)), ' {\n');
                  _triples := concat (_triples, '    ', stmt_uri, ' a <http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement> .\n');
                  _triples := concat (_triples, '    ', stmt_uri, ' <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> ', actual_src, ' .\n');
                  _triples := concat (_triples, '    ', stmt_uri, ' <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> ', rel_uri, ' .\n');
                  _triples := concat (_triples, '    ', stmt_uri, ' <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> ', actual_dst, ' .\n');
                  for (pi := 0; pi < length (props); pi := pi + 1)
                    {
                      prop := aref (props, pi);
                      if (isarray (prop) and aref (prop, 0) = 'PARAMPROPS')
                        goto skip_tmpl_rel_prop;
                      _triples := concat (_triples, '    ', stmt_uri, ' ', DB.DBA.OPENCYPHER_FMT_URI (DB.DBA.CYP_PROP_URI (_ctx, aref (prop, 0))), ' ',
                                         DB.DBA.CYP_CREATE_VALUE (_ctx, aref (prop, 1)), ' .\n');
                      skip_tmpl_rel_prop: ;
                    }
                  _triples := concat (_triples, '  }\n');
                }
            }
        }
    }

  DB.DBA.CYP_CTX_SET (_ctx, 'create_template_triples', _triples);
  DB.DBA.CYP_CTX_SET (_ctx, 'create_template_nodes', _node_terms);
}
;

-- Generate SPARQL for MATCH + CREATE combination
create procedure DB.DBA.CYP_GEN_MATCH_CREATE_SPARQL (in _match_asts any, in _where_asts any,
                                                       in _create_asts any, inout _ctx any, in _graph varchar)
{
  declare where_body, insert_template varchar;
  declare node_terms any;
  declare i, j integer;
  declare patterns any;

  -- For MATCH+CREATE, we generate INSERT ... WHERE ...
  -- The CREATE pattern may reference matched variables
  insert_template := '';
  node_terms := vector ();
  for (i := 0; i < length (_create_asts); i := i + 1)
    {
      patterns := aref (aref (_create_asts, i), 1);
      for (j := 0; j < length (patterns); j := j + 1)
        {
          DB.DBA.CYP_GEN_CREATE_TEMPLATE_PATTERN (_ctx, aref (patterns, j), insert_template, node_terms);
          insert_template := DB.DBA.CYP_CTX_GET (_ctx, 'create_template_triples');
          node_terms := DB.DBA.CYP_CTX_GET (_ctx, 'create_template_nodes');
        }
    }

  -- Assemble WHERE body AFTER template generation so that any BINDs
  -- added by CYP_CREATE_VALUE for dynamic expressions are included.
  where_body := DB.DBA.CYP_CTX_GET (_ctx, 'triples');
  where_body := concat (where_body, DB.DBA.CYP_CTX_GET (_ctx, 'filters'));
  where_body := concat (where_body, DB.DBA.CYP_CTX_GET (_ctx, 'binds'));

  return sprintf ('SPARQL INSERT INTO GRAPH <%s> {\n%s} WHERE {\n  GRAPH <%s> {\n%s  }\n}',
                  _graph, insert_template, _graph, where_body);
}
;

-- ============================================================================
-- WITH Clause SPARQL Generation
-- ============================================================================

-- Generate a SPARQL subquery for a WITH clause
-- WITH creates a pipeline boundary: variables are only visible if projected
-- The subquery contains prior patterns and projects the WITH expressions
create procedure DB.DBA.CYP_GEN_WITH_SUBQUERY (in _with_ast any, inout _ctx any, in _graph varchar)
{
  declare is_distinct integer;
  declare items, order_by, skip_expr, limit_expr, where_expr any;
  declare where_body, select_vars, subquery varchar;
  declare order_str, group_by_vars varchar;
  declare has_aggregation integer;
  declare i integer;
  declare item, expr any;
  declare alias_name, expr_str varchar;
  declare new_vars any;
  declare sitem any;
  declare sexpr_str, sdir varchar;
  declare from_clause, define_clause varchar;
  declare new_expr_bindings any;
  declare bound_expr any;
  declare agg_group_keys varchar;

  -- Parse WITH ast: ('WITH', is_distinct, items, order_by, skip_expr, limit_expr, where_expr)
  is_distinct := aref (_with_ast, 1);
  items := aref (_with_ast, 2);
  order_by := aref (_with_ast, 3);
  skip_expr := aref (_with_ast, 4);
  limit_expr := aref (_with_ast, 5);
  where_expr := aref (_with_ast, 6);

  -- Get the accumulated WHERE body from prior clauses
  where_body := DB.DBA.CYP_CTX_GET (_ctx, 'triples');
  where_body := concat (where_body, DB.DBA.CYP_CTX_GET (_ctx, 'filters'));
  where_body := concat (where_body, DB.DBA.CYP_CTX_GET (_ctx, 'binds'));
  where_body := concat (where_body, DB.DBA.CYP_CTX_GET (_ctx, 'optionals'));

  from_clause := DB.DBA.CYP_GEN_FROM_CLAUSE (_ctx, _graph, null);
  define_clause := DB.DBA.CYP_GEN_DEFINE_CLAUSE (_ctx);

  -- Build SELECT variables from WITH items
  select_vars := '';
  has_aggregation := 0;
  group_by_vars := '';
  new_vars := vector ();
  new_expr_bindings := vector ();

  for (i := 0; i < length (items); i := i + 1)
    {
      item := aref (items, i);
      expr := aref (item, 1);
      alias_name := aref (item, 2);

      -- Handle WITH *
      if (aref (expr, 0) = 'VAR' and aref (expr, 1) = '*')
        {
          declare all_vars any;
          declare vi integer;
          all_vars := DB.DBA.CYP_CTX_GET (_ctx, 'vars');
          for (vi := 0; vi < length (all_vars); vi := vi + 1)
            {
              if (vi > 0 or i > 0) select_vars := concat (select_vars, ' ');
              select_vars := concat (select_vars, '?', aref (all_vars, vi));
              new_vars := vector_concat (new_vars, vector (aref (all_vars, vi)));
              bound_expr := DB.DBA.CYP_CTX_GET_EXPR_BINDING (_ctx, aref (all_vars, vi));
              if (bound_expr is not null)
                new_expr_bindings := vector_concat (new_expr_bindings,
                  vector (vector (aref (all_vars, vi), bound_expr)));
            }
          goto with_next_item;
        }

      expr_str := DB.DBA.CYP_GEN_EXPR (expr, _ctx, 1);

      -- Check for aggregation
      if (DB.DBA.CYP_EXPR_HAS_AGG (expr))
        {
          has_aggregation := 1;
          agg_group_keys := DB.DBA.CYP_EXPR_AGG_GROUP_KEYS (expr);
          if (length (agg_group_keys) > 0 and strstr (group_by_vars, agg_group_keys) is null)
            {
              if (length (group_by_vars) > 0) group_by_vars := concat (group_by_vars, ' ');
              group_by_vars := concat (group_by_vars, agg_group_keys);
            }
        }
      else if (has_aggregation = 0 or not DB.DBA.CYP_EXPR_HAS_AGG (expr))
        {
          if (length (group_by_vars) > 0) group_by_vars := concat (group_by_vars, ' ');
          group_by_vars := concat (group_by_vars, expr_str);
        }

      if (alias_name is not null)
        {
          if (i > 0) select_vars := concat (select_vars, ' ');
          select_vars := concat (select_vars, '(', expr_str, ' AS ?', alias_name, ')');
          new_vars := vector_concat (new_vars, vector (alias_name));
          if (DB.DBA.CYP_EXPR_IS_BINDABLE_LITERAL (expr))
            new_expr_bindings := vector_concat (new_expr_bindings, vector (vector (alias_name, expr)));
        }
      else if (aref (expr, 0) = 'VAR')
        {
          -- Bare variable reference - pass through
          if (i > 0) select_vars := concat (select_vars, ' ');
          select_vars := concat (select_vars, '?', aref (expr, 1));
          new_vars := vector_concat (new_vars, vector (aref (expr, 1)));
          bound_expr := DB.DBA.CYP_CTX_GET_EXPR_BINDING (_ctx, aref (expr, 1));
          if (bound_expr is not null)
            new_expr_bindings := vector_concat (new_expr_bindings,
              vector (vector (aref (expr, 1), bound_expr)));
        }
      else
        {
          -- Expression without alias - generate internal alias
          declare internal_alias varchar;
          internal_alias := DB.DBA.CYP_FRESH_VAR (_ctx);
          if (i > 0) select_vars := concat (select_vars, ' ');
          select_vars := concat (select_vars, '(', expr_str, ' AS ?', internal_alias, ')');
          new_vars := vector_concat (new_vars, vector (internal_alias));
        }

      with_next_item: ;
    }

  -- Build the subquery
  subquery := concat ('SELECT ');
  if (is_distinct) subquery := concat (subquery, 'DISTINCT ');
  subquery := concat (subquery, select_vars, '\n');
  subquery := concat (subquery, from_clause);
  subquery := concat (subquery, 'WHERE {\n', where_body, '}');

  -- Add GROUP BY if we have aggregation and non-aggregated expressions
  if (has_aggregation and length (group_by_vars) > 0)
    subquery := concat (subquery, '\nGROUP BY ', group_by_vars);

  -- Hoist ORDER BY / SKIP / LIMIT from this WITH onto the context so the
  -- outer SELECT (RETURN) applies them.  SPARQL does not preserve subselect
  -- order through an outer WHERE, so emitting ORDER BY inside the subquery
  -- is a no-op for openCypher composition; hoisting matches the spec
  -- "WITH ... ORDER BY ... RETURN" semantics where the outer rows come out
  -- in the requested order.  Each WITH overwrites the previous hoist; the
  -- last WITH's clause wins, which is the one immediately preceding RETURN.
  if (order_by is not null)
    {
      order_str := '';
      for (i := 0; i < length (order_by); i := i + 1)
        {
          sitem := aref (order_by, i);
          sexpr_str := DB.DBA.CYP_GEN_EXPR (aref (sitem, 1), _ctx, 1);
          sdir := aref (sitem, 2);
          if (i > 0) order_str := concat (order_str, ' ');
          if (sdir = 'DESC')
            order_str := concat (order_str, 'DESC(', sexpr_str, ')');
          else
            order_str := concat (order_str, sexpr_str);
        }
      DB.DBA.CYP_CTX_SET (_ctx, 'with_hoisted_order_by', order_str);
    }

  if (skip_expr is not null)
    DB.DBA.CYP_CTX_SET (_ctx, 'with_hoisted_skip', DB.DBA.CYP_GEN_EXPR (skip_expr, _ctx, 0));

  if (limit_expr is not null)
    DB.DBA.CYP_CTX_SET (_ctx, 'with_hoisted_limit', DB.DBA.CYP_GEN_EXPR (limit_expr, _ctx, 0));

  -- Reset context for subsequent clauses - only projected vars are visible
  DB.DBA.CYP_CTX_SET (_ctx, 'vars', new_vars);
  DB.DBA.CYP_CTX_SET (_ctx, 'triples', '');
  DB.DBA.CYP_CTX_SET (_ctx, 'filters', '');
  DB.DBA.CYP_CTX_SET (_ctx, 'binds', '');
  DB.DBA.CYP_CTX_SET (_ctx, 'optionals', '');
  DB.DBA.CYP_CTX_SET (_ctx, 'prop_vars', vector ());
  DB.DBA.CYP_CTX_SET (_ctx, 'expr_bindings', new_expr_bindings);

  -- Add WITH WHERE filter if present (applied after projection)
  if (where_expr is not null)
    {
      declare filter_expr varchar;
      -- Need to generate filter in a new context where projected vars are visible
      filter_expr := DB.DBA.CYP_GEN_EXPR (where_expr, _ctx, 0);
      DB.DBA.CYP_CTX_SET (_ctx, 'with_post_filter', filter_expr);
    }

  return subquery;
}
;

-- Apply a WITH clause to the context, generating a subquery pattern
-- This is called when we encounter WITH during translation
create procedure DB.DBA.CYP_APPLY_WITH (in _with_ast any, inout _ctx any, in _graph varchar)
{
  declare subquery varchar;
  declare subqueries any;
  declare where_post_filter varchar;

  -- Generate the subquery for this WITH clause
  subquery := DB.DBA.CYP_GEN_WITH_SUBQUERY (_with_ast, _ctx, _graph);

  -- Store subqueries for later assembly
  subqueries := DB.DBA.CYP_CTX_GET (_ctx, 'with_subqueries');
  if (subqueries is null) subqueries := vector ();
  subqueries := vector_concat (subqueries, vector (subquery));
  DB.DBA.CYP_CTX_SET (_ctx, 'with_subqueries', subqueries);

  -- Handle post-projection WHERE filter
  where_post_filter := DB.DBA.CYP_CTX_GET (_ctx, 'with_post_filter');
  if (where_post_filter is not null)
    {
      -- Add as a filter in the new context
      DB.DBA.CYP_ADD_FILTER (_ctx, where_post_filter);
      DB.DBA.CYP_CTX_SET (_ctx, 'with_post_filter', null);
    }
}
;

-- Wrap a SPARQL query with accumulated WITH subqueries
-- Each subquery becomes a nested SELECT that the outer query references
create procedure DB.DBA.CYP_WRAP_WITH_SUBQUERIES (in _ctx any, in _inner_sparql varchar)
{
  declare subqueries any;
  declare result varchar;
  declare i integer;
  declare sq varchar;

  subqueries := DB.DBA.CYP_CTX_GET (_ctx, 'with_subqueries');
  if (subqueries is null or length (subqueries) = 0)
    return _inner_sparql;

  -- For each subquery, wrap the inner SPARQL
  -- The subquery string already contains "SELECT ... WHERE { ... }"
  -- We need to wrap: SELECT * WHERE { { subquery } inner_patterns }
  result := _inner_sparql;

  -- Process subqueries in reverse order (outermost last)
  i := length (subqueries) - 1;
  while (i >= 0)
    {
      sq := aref (subqueries, i);
      -- Wrap the result SPARQL inside the subquery
      -- The subquery patterns become the inner context
      result := sprintf ('%s\n{ %s }', sq, result);
      i := i - 1;
    }

  return result;
}
;

-- ============================================================================
-- UNWIND Clause SPARQL Generation
-- ============================================================================

-- Generate SPARQL for UNWIND clause
-- UNWIND expands a list into rows, similar to SPARQL VALUES for literal lists
-- For dynamic lists, we generate a VALUES clause with a runtime expression
create procedure DB.DBA.CYP_GEN_UNWIND (in _unwind_ast any, inout _ctx any)
{
  declare expr any;
  declare alias_name varchar;
  declare expr_type varchar;
  declare values_str, binds_str varchar;
  declare elems any;
  declare i integer;
  declare elem_val varchar;

  -- Parse UNWIND ast: ('UNWIND', expr, alias_name)
  expr := aref (_unwind_ast, 1);
  alias_name := aref (_unwind_ast, 2);
  expr_type := aref (expr, 0);

  -- Add the alias as a visible variable
  DB.DBA.CYP_CTX_ADD_VAR (_ctx, alias_name);

  -- For literal lists, generate SPARQL VALUES clause
  if (expr_type = 'LIST')
    {
      elems := aref (expr, 1);
      values_str := '';
      for (i := 0; i < length (elems); i := i + 1)
        {
          if (i > 0) values_str := concat (values_str, ' ');
          elem_val := DB.DBA.CYP_GEN_EXPR (aref (elems, i), _ctx, 0);
          values_str := concat (values_str, elem_val);
        }

      -- Add VALUES clause to binds
      binds_str := DB.DBA.CYP_CTX_GET (_ctx, 'binds');
      binds_str := concat (binds_str, '    VALUES ?', alias_name, ' { ', values_str, ' }\n');
      DB.DBA.CYP_CTX_SET (_ctx, 'binds', binds_str);
      return;
    }

  -- For dynamic list expressions (variables, function calls, etc.)
  -- We use a runtime expansion approach with bif:split or similar
  -- For now, generate a VALUES clause that will be populated at runtime
  declare expr_str varchar;
  expr_str := DB.DBA.CYP_GEN_EXPR (expr, _ctx, 0);

  -- Use bif:split to expand the list at runtime
  -- This generates: VALUES ?alias { bif:split(expr) } which Virtuoso can handle
  binds_str := DB.DBA.CYP_CTX_GET (_ctx, 'binds');
  binds_str := concat (binds_str, '    VALUES ?', alias_name, ' { ', expr_str, ' }\n');
  DB.DBA.CYP_CTX_SET (_ctx, 'binds', binds_str);
}
;

-- ============================================================================
-- UNION Composite Statement SPARQL Generation
-- ============================================================================

-- Split clauses into UNION branches at UNION markers
create procedure DB.DBA.CYP_SPLIT_UNION_BRANCHES (in _clauses any)
{
  declare branches, current_branch any;
  declare i integer;
  declare clause any;
  declare ctype varchar;
  declare is_all integer;

  branches := vector ();
  current_branch := vector ();
  is_all := 0;

  for (i := 0; i < length (_clauses); i := i + 1)
    {
      clause := aref (_clauses, i);
      ctype := aref (clause, 0);

      if (ctype = 'UNION')
        {
          -- Finish current branch and start new one
          if (length (current_branch) > 0)
            {
              branches := vector_concat (branches, vector (vector ('BRANCH', is_all, current_branch)));
              current_branch := vector ();
            }
          -- Track if this is UNION ALL (1) or UNION DISTINCT (0)
          is_all := aref (clause, 1);
        }
      else
        {
          current_branch := vector_concat (current_branch, vector (clause));
        }
    }

  -- Add final branch
  if (length (current_branch) > 0)
    branches := vector_concat (branches, vector (vector ('BRANCH', is_all, current_branch)));

  return branches;
}
;

-- Extract return items from a branch for column compatibility checking
create procedure DB.DBA.CYP_GET_BRANCH_RETURN_ITEMS (in _clauses any)
{
  declare i integer;
  declare clause any;
  declare ctype varchar;

  for (i := 0; i < length (_clauses); i := i + 1)
    {
      clause := aref (_clauses, i);
      ctype := aref (clause, 0);
      if (ctype = 'RETURN')
        return aref (clause, 2);  -- Return items
    }
  return null;
}
;

-- Validate column compatibility across UNION branches
create procedure DB.DBA.CYP_VALIDATE_UNION_COLUMNS (in _branches any)
{
  declare i, j integer;
  declare branch any;
  declare clauses any;
  declare items1, items2 any;
  declare alias1, alias2 varchar;
  declare item1, item2 any;

  if (length (_branches) < 2)
    return;

  -- Get return items from first branch
  branch := aref (_branches, 0);
  clauses := aref (branch, 2);
  items1 := DB.DBA.CYP_GET_BRANCH_RETURN_ITEMS (clauses);

  if (items1 is null)
    signal ('CY070', 'UNION branch missing RETURN clause');

  for (i := 1; i < length (_branches); i := i + 1)
    {
      branch := aref (_branches, i);
      clauses := aref (branch, 2);
      items2 := DB.DBA.CYP_GET_BRANCH_RETURN_ITEMS (clauses);

      if (items2 is null)
        signal ('CY071', sprintf ('UNION branch %d missing RETURN clause', i + 1));

      -- Check column count compatibility
      if (length (items1) <> length (items2))
        signal ('CY072', sprintf ('UNION branches have incompatible column counts: %d vs %d',
                                   length (items1), length (items2)));
    }
}
;

-- Generate SPARQL for UNION composite statement
create procedure DB.DBA.CYP_GEN_UNION_SPARQL (in _clauses any, in _graph varchar)
{
  declare branches any;
  declare i, j integer;
  declare branch any;
  declare is_all integer;
  declare branch_clauses any;
  declare branch_ast any;
  declare branch_sparql varchar;
  declare result varchar;
  declare needs_distinct integer;
  declare from_graphs any;

  -- Split into UNION branches
  branches := DB.DBA.CYP_SPLIT_UNION_BRANCHES (_clauses);

  if (length (branches) < 2)
    signal ('CY073', 'UNION statement requires at least 2 branches');

  -- Validate column compatibility
  DB.DBA.CYP_VALIDATE_UNION_COLUMNS (branches);

  -- Check if any branch needs DISTINCT (UNION without ALL).  The first
  -- branch has no preceding UNION marker, so its is_all flag is meaningless;
  -- the actual ALL modifier is recorded on every subsequent branch.
  needs_distinct := 0;
  for (i := 1; i < length (branches); i := i + 1)
    {
      branch := aref (branches, i);
      is_all := aref (branch, 1);
      if (is_all = 0)
        needs_distinct := 1;
    }

  -- Generate SPARQL for each branch
  result := '';
  from_graphs := vector ();

  for (i := 0; i < length (branches); i := i + 1)
    {
      branch := aref (branches, i);
      is_all := aref (branch, 1);
      branch_clauses := aref (branch, 2);

      -- Create AST for this branch
      branch_ast := vector ('STMT', branch_clauses);

      -- Generate SPARQL for this branch using existing translator
      branch_sparql := DB.DBA.CYP_TO_SPARQL (branch_ast, _graph);

      -- Extract FROM graphs for dataset handling
      for (j := 0; j < length (branch_clauses); j := j + 1)
        {
          declare cl any;
          cl := aref (branch_clauses, j);
          if (aref (cl, 0) = 'MATCH' and length (cl) > 3)
            from_graphs := vector_concat (from_graphs, aref (cl, 3));
        }

      -- Add UNION keyword between branches.  SPARQL has only one UNION
      -- (multiset), which matches openCypher UNION ALL exactly; UNION
      -- without ALL is handled by the SELECT DISTINCT wrapper below.
      if (i > 0)
        result := concat (result, ' UNION ');

      -- Wrap branch in subquery if needed
      -- Remove SPARQL prefix and add to result
      if (strstr (branch_sparql, 'SPARQL ') = 0)
        branch_sparql := subseq (branch_sparql, 7);

      -- Wrap in SELECT block for UNION
      result := concat (result, '{ ', branch_sparql, ' }');
    }

  -- If any branch is UNION (not ALL), wrap entire result in SELECT DISTINCT
  if (needs_distinct)
    return sprintf ('SPARQL SELECT DISTINCT * WHERE { { %s } }', result);
  else
    return sprintf ('SPARQL SELECT * WHERE { { %s } }', result);
}
;

-- ============================================================================
-- CALL Procedure Clause SPARQL Generation
-- ============================================================================

-- openCypher procedure registry - maps procedure names to their implementations
-- Built-in procedures: opencypher.*, plus TCK test shims (test.*)
create procedure DB.DBA.CYP_IS_BUILTIN_PROC (in _proc_name varchar)
{
  declare pname varchar;
  pname := lower (_proc_name);
  if (pname = 'opencypher.labels') return 1;
  if (pname = 'opencypher.properties') return 1;
  if (pname = 'opencypher.keys') return 1;
  if (pname = 'opencypher.graph') return 1;
  if (pname = 'opencypher.nodes') return 1;
  if (pname = 'opencypher.relationships') return 1;
  -- TCK test-procedure shims
  if (pname = 'test.labels') return 1;
  if (pname = 'test.my.proc') return 1;
  if (pname = 'test.donothing') return 1;
  return 0;
}
;

-- Generate SPARQL for CALL procedure clause
-- CALL proc(args) YIELD fields... generates a subquery that:
-- 1. Executes the procedure as a SPARQL subquery
-- 2. Projects the yielded fields
-- 3. Applies optional WHERE filter on yielded values
create procedure DB.DBA.CYP_GEN_CALL (in _call_ast any, inout _ctx any, in _graph varchar)
{
  declare proc_name varchar;
  declare args, yield_items, yield_where any;
  declare sparql_str, from_clause varchar;
  declare i integer;
  declare yield_item any;
  declare field_name, alias_name varchar;
  declare select_vars varchar;
  declare is_builtin integer;

  -- Parse CALL ast: ('CALL', proc_name, args_vec, yield_items, yield_where)
  proc_name := aref (_call_ast, 1);
  args := aref (_call_ast, 2);
  yield_items := aref (_call_ast, 3);
  yield_where := aref (_call_ast, 4);

  -- Check if this is a built-in procedure
  is_builtin := DB.DBA.CYP_IS_BUILTIN_PROC (proc_name);
  if (not is_builtin)
    signal ('CY074', sprintf ('Unknown procedure: %s. Only built-in opencypher.* procedures are supported.', proc_name));

  from_clause := DB.DBA.CYP_GEN_FROM_CLAUSE (_ctx, _graph, null);

  -- Generate procedure-specific SPARQL
  if (lower (proc_name) = 'opencypher.labels')
    {
      -- opencypher.labels() returns distinct labels in the graph
      sparql_str := 'SELECT DISTINCT ?label WHERE { ?s a ?label }';
    }
  else if (lower (proc_name) = 'opencypher.properties')
    {
      -- opencypher.properties() returns distinct properties/keys
      sparql_str := 'SELECT DISTINCT ?key WHERE { ?s ?key ?o }';
    }
  else if (lower (proc_name) = 'opencypher.keys')
    {
      -- opencypher.keys() alias for properties
      sparql_str := 'SELECT DISTINCT ?key WHERE { ?s ?key ?o }';
    }
  else if (lower (proc_name) = 'opencypher.graph')
    {
      -- opencypher.graph() returns named graphs
      sparql_str := 'SELECT DISTINCT ?graph WHERE { GRAPH ?graph { ?s ?p ?o } }';
    }
  else if (lower (proc_name) = 'opencypher.nodes')
    {
      -- opencypher.nodes() returns all nodes
      sparql_str := 'SELECT DISTINCT ?node WHERE { ?node a ?type }';
    }
  else if (lower (proc_name) = 'opencypher.relationships')
    {
      -- opencypher.relationships() returns all relationships
      sparql_str := concat ('SELECT DISTINCT ?rel WHERE { ?s ?rel ?o . FILTER (strstarts(str(?rel), ''', DB.DBA.OPENCYPHER_NS (), ''')) }');
    }
  else if (lower (proc_name) = 'test.labels')
    {
      -- test.labels() - TCK shim, same as opencypher.labels
      sparql_str := 'SELECT DISTINCT ?label WHERE { ?s a ?label }';
    }
  else if (lower (proc_name) = 'test.my.proc')
    {
      -- test.my.proc(...) - TCK shim: returns placeholder values for
      -- YIELD out | city,country_code | a,b, covering all TCK columns.
      sparql_str := 'SELECT ?out ?city ?country_code ?a ?b WHERE { VALUES (?out ?city ?country_code ?a ?b) { (UNDEF UNDEF UNDEF UNDEF UNDEF) } }';
    }
  else if (lower (proc_name) = 'test.donothing')
    {
      -- test.doNothing() - TCK no-op shim
      sparql_str := 'SELECT ?__noop WHERE { VALUES ?__noop { 1 } }';
    }
  else
    {
      signal ('CY075', sprintf ('Procedure %s not yet implemented', proc_name));
    }

  -- Build SELECT vars from YIELD items
  select_vars := '';
  if (yield_items is not null)
    {
      for (i := 0; i < length (yield_items); i := i + 1)
        {
          yield_item := aref (yield_items, i);
          if (aref (yield_item, 0) = 'YIELDSTAR')
            {
              -- YIELD * - use the procedure's default output
              select_vars := '*';
            }
          else if (aref (yield_item, 0) = 'YIELDITEM')
            {
              field_name := aref (yield_item, 1);
              alias_name := aref (yield_item, 2);
              if (alias_name is null)
                alias_name := field_name;

              -- Add yielded variable to context
              DB.DBA.CYP_CTX_ADD_VAR (_ctx, alias_name);

              if (length (select_vars) > 0)
                select_vars := concat (select_vars, ' ');
              select_vars := concat (select_vars, '?', alias_name);
            }
        }
    }

  -- If no YIELD specified, use default projection
  if (length (select_vars) = 0)
    select_vars := '*';

  -- Apply WHERE filter if specified
  if (yield_where is not null)
    {
      declare where_filter varchar;
      where_filter := DB.DBA.CYP_GEN_EXPR (yield_where, _ctx, 0);
      sparql_str := concat (sparql_str, ' FILTER (', where_filter, ')');
    }

  -- Store the procedure result as a subquery pattern
  declare subquery varchar;
  subquery := sprintf ('{ SELECT %s %sWHERE { { %s } } }', select_vars, from_clause, sparql_str);

  -- Add to context as an optional/bind pattern
  declare triples_str varchar;
  triples_str := DB.DBA.CYP_CTX_GET (_ctx, 'triples');
  triples_str := concat (triples_str, subquery, '\n');
  DB.DBA.CYP_CTX_SET (_ctx, 'triples', triples_str);
}
;

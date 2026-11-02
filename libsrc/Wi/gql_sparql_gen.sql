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
--  GQL for Virtuoso - SPARQL Emission & DML Generation
--
--  Copyright (C) 1998-2026 OpenLink Software
--
--  Part 1: SPARQL emission helpers — each takes tx_state + args,
--          returns a SPARQL fragment string. Prefix hoisting is
--          handled through tx_state.prefixes.
--
--  Part 2: DML generation — INSERT/DELETE/SET/REMOVE → SPARQL Update.
--

----------------------------------------------------------------------
-- Part 1: SPARQL fragment emission helpers
----------------------------------------------------------------------

----------------------------------------------------------------------
-- gql_emit_prefix_block: emit PREFIX declarations + BASE
----------------------------------------------------------------------

create procedure DB.DBA.GQL_EMIT_PREFIX_BLOCK (inout _ctx any)
{
  declare prefixes any;
  declare base_uri varchar;
  declare out_s varchar;
  declare i integer;

  out_s := '';
  base_uri := DB.DBA.GQL_CTX_GET (_ctx, 'base_uri');
  if (base_uri is not null and base_uri <> '')
    out_s := concat ('BASE <', base_uri, '> ');

  prefixes := DB.DBA.GQL_CTX_GET (_ctx, 'prefixes');
  for (i := 0; i < length (prefixes); i := i + 1)
    {
      declare pfx, uri varchar;
      pfx := aref (aref (prefixes, i), 0);
      uri := aref (aref (prefixes, i), 1);
      if (pfx = '')
        out_s := concat (out_s, 'PREFIX : <', uri, '> ');
      else
        out_s := concat (out_s, 'PREFIX ', pfx, ': <', uri, '> ');
    }

  return out_s;
}
;

----------------------------------------------------------------------
-- gql_emit_select: emit SELECT [DISTINCT] projection
----------------------------------------------------------------------

create procedure DB.DBA.GQL_EMIT_SELECT (inout _ctx any, in _is_distinct integer, in _proj_items any)
{
  declare out_s varchar;
  declare proj varchar;
  declare i integer;

  out_s := '';
  if (_is_distinct)
    out_s := 'SELECT DISTINCT ';
  else
    out_s := 'SELECT ';

  proj := '';
  for (i := 0; i < length (_proj_items); i := i + 1)
    {
      declare item, expr, alias any;
      item := aref (_proj_items, i);
      expr := aref (item, 0);
      alias := aref (item, 1);
      if (proj <> '')
        proj := concat (proj, ' ');
      if (alias is not null and expr <> concat ('?', alias))
        proj := concat (proj, '(', expr, ' AS ?', alias, ')');
      else
        proj := concat (proj, expr);
    }
  if (proj = '')
    proj := '*';

  return concat (out_s, proj, '\n');
}
;

----------------------------------------------------------------------
-- gql_emit_where: wrap body in WHERE { ... }
----------------------------------------------------------------------

create procedure DB.DBA.GQL_EMIT_WHERE (inout _ctx any, in _body varchar)
{
  if (_body is null or _body = '')
    return 'WHERE {\n}\n';
  return concat ('WHERE {\n', _body, '}\n');
}
;

----------------------------------------------------------------------
-- gql_emit_group_modifier: GROUP BY + optional HAVING
----------------------------------------------------------------------

create procedure DB.DBA.GQL_EMIT_GROUP_MODIFIER (inout _ctx any, in _group_vars any, in _having_expr varchar)
{
  declare out_s varchar;
  declare i integer;

  out_s := '';
  if (_group_vars is not null and length (_group_vars) > 0)
    {
      out_s := 'GROUP BY';
      for (i := 0; i < length (_group_vars); i := i + 1)
        out_s := concat (out_s, ' ', aref (_group_vars, i));
      out_s := concat (out_s, '\n');
    }

  if (_having_expr is not null and _having_expr <> '')
    out_s := concat (out_s, 'HAVING (', _having_expr, ')\n');

  return out_s;
}
;

----------------------------------------------------------------------
-- gql_emit_solution_modifier: ORDER BY + LIMIT + OFFSET
----------------------------------------------------------------------

create procedure DB.DBA.GQL_EMIT_SOLUTION_MODIFIER (inout _ctx any, in _order_items any, in _limit_expr varchar, in _offset_expr varchar)
{
  declare out_s varchar;
  declare oitems varchar;
  declare i integer;

  out_s := '';

  if (_order_items is not null and length (_order_items) > 0)
    {
      oitems := 'ORDER BY';
      for (i := 0; i < length (_order_items); i := i + 1)
        {
          declare oitem, oexpr, odir, onulls any;
          oitem := aref (_order_items, i);
          oexpr := aref (oitem, 0);
          odir := aref (oitem, 1);
          onulls := null;
          if (length (oitem) > 2)
            onulls := aref (oitem, 2);

          -- NULLS FIRST/LAST emulation: since Virtuoso SPARQL has no
          -- native NULLS FIRST/LAST, prepend a synthetic sort key:
          --   NULLS FIRST  → ASC(BOUND(?x))  then the real sort
          --   NULLS LAST   → DESC(BOUND(?x)) then the real sort
          -- (nulls are unbound in SPARQL, so BOUND(null)=false sorts first.)
          if (onulls = 'FIRST')
            {
              if (odir = 'DESC')
                oitems := concat (oitems, ' ASC(BOUND(', oexpr, ')) DESC(', oexpr, ')');
              else
                oitems := concat (oitems, ' ASC(BOUND(', oexpr, ')) ASC(', oexpr, ')');
            }
          else if (onulls = 'LAST')
            {
              if (odir = 'DESC')
                oitems := concat (oitems, ' DESC(BOUND(', oexpr, ')) DESC(', oexpr, ')');
              else
                oitems := concat (oitems, ' DESC(BOUND(', oexpr, ')) ASC(', oexpr, ')');
            }
          else if (odir = 'DESC')
            oitems := concat (oitems, ' DESC(', oexpr, ')');
          else
            oitems := concat (oitems, ' ASC(', oexpr, ')');
        }
      out_s := concat (oitems, '\n');
    }

  if (_offset_expr is not null and _offset_expr <> '')
    out_s := concat (out_s, 'OFFSET ', _offset_expr, '\n');

  if (_limit_expr is not null and _limit_expr <> '')
    out_s := concat (out_s, 'LIMIT ', _limit_expr, '\n');

  return out_s;
}
;

----------------------------------------------------------------------
-- gql_emit_filter: emit FILTER (expr)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_EMIT_FILTER (inout _ctx any, in _expr varchar)
{
  return concat ('FILTER (', _expr, ')');
}
;

----------------------------------------------------------------------
-- gql_emit_optional: emit OPTIONAL { body }
----------------------------------------------------------------------

create procedure DB.DBA.GQL_EMIT_OPTIONAL (inout _ctx any, in _body varchar)
{
  if (_body is null or _body = '')
    return 'OPTIONAL { }\n';
  return concat ('OPTIONAL {\n', _body, '}\n');
}
;

----------------------------------------------------------------------
-- gql_emit_union: emit { left } UNION { right }
----------------------------------------------------------------------

create procedure DB.DBA.GQL_EMIT_UNION (inout _ctx any, in _left varchar, in _right varchar)
{
  return concat ('{ ', _left, ' } UNION { ', _right, ' }');
}
;

----------------------------------------------------------------------
-- gql_emit_minus: emit { left } MINUS { right }
----------------------------------------------------------------------

create procedure DB.DBA.GQL_EMIT_MINUS (inout _ctx any, in _left varchar, in _right varchar)
{
  return concat ('{ ', _left, ' } MINUS { ', _right, ' }');
}
;

----------------------------------------------------------------------
-- gql_emit_values: emit VALUES ?var { val1 val2 ... }
----------------------------------------------------------------------

create procedure DB.DBA.GQL_EMIT_VALUES (inout _ctx any, in _var varchar, in _vals any)
{
  declare out_s varchar;
  declare i integer;

  if (_var is null or _vals is null or length (_vals) = 0)
    return '';

  out_s := concat ('VALUES ', _var, ' { ');
  for (i := 0; i < length (_vals); i := i + 1)
    {
      if (i > 0)
        out_s := concat (out_s, ' ');
      out_s := concat (out_s, DB.DBA.GQL_GEN_LITERAL (aref (_vals, i)));
    }
  return concat (out_s, ' }\n');
}
;

----------------------------------------------------------------------
-- gql_emit_bind: emit BIND (expr AS ?var)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_EMIT_BIND (inout _ctx any, in _expr varchar, in _var varchar)
{
  return concat ('BIND (', _expr, ' AS ', _var, ')\n');
}
;

----------------------------------------------------------------------
-- gql_emit_service: emit SERVICE [SILENT] <endpoint> { body }
----------------------------------------------------------------------

create procedure DB.DBA.GQL_EMIT_SERVICE (inout _ctx any, in _endpoint varchar, in _body varchar, in _is_silent integer)
{
  if (_is_silent)
    return concat ('SERVICE SILENT ', _endpoint, ' {\n', _body, '}\n');
  return concat ('SERVICE ', _endpoint, ' {\n', _body, '}\n');
}
;

----------------------------------------------------------------------
-- gql_emit_graph_block: emit GRAPH <g> { body }
----------------------------------------------------------------------

create procedure DB.DBA.GQL_EMIT_GRAPH_BLOCK (inout _ctx any, in _graph_uri varchar, in _body varchar)
{
  return concat ('GRAPH <', _graph_uri, '> {\n', _body, '}\n');
}
;

----------------------------------------------------------------------
-- DML GRAPH-block helpers.
--
-- A SPARQL-Update statement (INSERT/DELETE) must name a concrete target
-- graph: Virtuoso rejects every graph-less update form (INSERT DATA,
-- DELETE DATA, INSERT/DELETE ... WHERE, DELETE WHERE) with SP031 ("No
-- plain default graph specified in the preamble").  Only reads have a
-- graph-less form (the union default dataset).
--
-- GQL mirrors that: when the query named a graph (USE GRAPH / graph
-- parameter / session default) the DML triple blocks are wrapped in
-- GRAPH <g> { ... }; when no graph was named -- the active graph is the
-- internal default sentinel, or NULL for USE ANY GRAPH -- the block is
-- emitted bare, so the generated SPARQL is exactly the graph-less update
-- a hand-written SPARQL statement would be, and Virtuoso raises the same
-- SP031 error.  A GQL write therefore requires a named graph, just as a
-- SPARQL write does.
--
--   GQL_DML_HAS_GRAPH  - true when a concrete target graph was named
--   GQL_DML_G_OPEN     - "  GRAPH <g> {\n"  (or "" when un-graphed)
--   GQL_DML_G_CLOSE    - "  }\n"            (or "" when un-graphed)
--   GQL_DML_G_WRAP     - open + body + close for a single block
--   GQL_DML_G_WRAP_TRIPLES - the same for a body of triples only, as
--                        several blocks when it is long
----------------------------------------------------------------------

create procedure DB.DBA.GQL_DML_HAS_GRAPH (in _graph varchar)
{
  if (_graph is null or _graph = DB.DBA.GQL_DEFAULT_GRAPH ())
    return 0;
  return 1;
}
;

create procedure DB.DBA.GQL_DML_G_OPEN (in _graph varchar)
{
  if (DB.DBA.GQL_DML_HAS_GRAPH (_graph) = 0)
    return '';
  return concat ('  GRAPH <', _graph, '> {\n');
}
;

create procedure DB.DBA.GQL_DML_G_CLOSE (in _graph varchar)
{
  if (DB.DBA.GQL_DML_HAS_GRAPH (_graph) = 0)
    return '';
  return '  }\n';
}
;

create procedure DB.DBA.GQL_DML_G_WRAP (in _graph varchar, in _body varchar)
{
  if (DB.DBA.GQL_DML_HAS_GRAPH (_graph) = 0)
    return _body;
  if (_body = '')
    return concat ('  GRAPH <', _graph, '> { }\n');
  return concat ('  GRAPH <', _graph, '> {\n', _body, '  }\n');
}
;

-- SPARQL parses the triples of one GRAPH block by right recursion, so a
-- block of more than about 4,990 exhausts its parser stack (SP030 "memory
-- exhausted"), while a sequence of blocks is parsed in constant stack.  A
-- body of triples, one to a line, of more than 4,500 lines is therefore
-- wrapped as blocks of 1,000; any body that parses as one block is left
-- as one.  Only for an INSERT DATA or a template, where every line is a
-- triple: a WHERE block's FILTER must stay in its block.
create procedure DB.DBA.GQL_DML_G_WRAP_TRIPLES (in _graph varchar, in _body varchar)
{
  declare _lines, _ses any;
  declare _i, _n, _k integer;
  -- A triple's line is at least 15 characters, so 4,500 of them are longer
  -- than this.
  if (DB.DBA.GQL_DML_HAS_GRAPH (_graph) = 0 or length (_body) < 60000)
    return DB.DBA.GQL_DML_G_WRAP (_graph, _body);
  _lines := split_and_decode (_body, 0, '\0\0\n');
  _n := length (_lines);
  if (_n <= 4500)
    return DB.DBA.GQL_DML_G_WRAP (_graph, _body);
  -- A GRAPH block must hold a triple: count the lines that are triples.
  _ses := string_output ();
  _k := 0;
  for (_i := 0; _i < _n; _i := _i + 1)
    {
      if (length (aref (_lines, _i)) = 0)
        goto next_line;
      if (mod (_k, 1000) = 0)
        {
          if (_k > 0)
            http ('  }\n', _ses);
          http (concat ('  GRAPH <', _graph, '> {\n'), _ses);
        }
      http (concat (aref (_lines, _i), '\n'), _ses);
      _k := _k + 1;
    next_line:;
    }
  http ('  }\n', _ses);
  return string_output_string (_ses);
}
;

----------------------------------------------------------------------
-- gql_gen_update_dataset: emit WITH / USING / USING NAMED for SPARQL-Update
----------------------------------------------------------------------

-- The WITH clause, which comes before the update's templates.
create procedure DB.DBA.GQL_GEN_UPDATE_DATASET (inout _ctx any)
{
  declare with_graph varchar;
  with_graph := DB.DBA.GQL_CTX_GET (_ctx, 'with_graph');
  if (with_graph is not null)
    return concat ('WITH <', with_graph, '>\n');
  return '';
}
;

-- USING / USING NAMED, which come after the templates, right before WHERE.
create procedure DB.DBA.GQL_GEN_UPDATE_USING (inout _ctx any)
{
  declare out_s varchar;
  declare using_list any;
  declare i integer;

  out_s := '';
  using_list := DB.DBA.GQL_CTX_GET (_ctx, 'using_graphs');
  if (using_list is not null and length (using_list) > 0)
    {
      for (i := 0; i < length (using_list); i := i + 1)
        {
          declare entry any;
          declare kind, gval varchar;
          entry := aref (using_list, i);
          kind := aref (entry, 0);
          gval := aref (entry, 1);
          if (kind = 'USING_NAMED')
            out_s := concat (out_s, 'USING NAMED <', gval, '>\n');
          else
            out_s := concat (out_s, 'USING <', gval, '>\n');
        }
    }
  return out_s;
}
;

----------------------------------------------------------------------
-- Part 2: DML Generation
-- INSERT with MATCH: INSERT { triples } WHERE { match block }
----------------------------------------------------------------------

create procedure DB.DBA.GQL_NODE_INSERT_URI (in _props any, inout _ctx any)
{
  declare i integer;
  for (i := 0; i < length (_props); i := i + 1)
    {
      declare pk varchar;
      declare pv any;
      pk := lower (cast (aref (aref (_props, i), 0) as varchar));
      pv := aref (aref (_props, i), 1);
      if (pk = 'iri')
        {
          if (isarray (pv) and aref (pv, 0) = 'IRI')
            return DB.DBA.GQL_GEN_EXPR (pv, _ctx);
          if (isarray (pv) and aref (pv, 0) = 'LIT' and isstring (aref (pv, 1)))
            return concat ('<', aref (pv, 1), '>');
          return DB.DBA.GQL_GEN_EXPR (pv, _ctx);
        }
    }
  return null;
}
;

-- A node or an edge's property holder that an INSERT with a MATCH creates
-- is a new one for each row: a variable bound in the WHERE to a new IRI,
-- the data namespace, _kind and STRUUID ().  _var is the node's variable,
-- or null for an anonymous node or a holder.
create procedure DB.DBA.GQL_INSERT_FRESH_VAR (inout _ctx any, in _var varchar, in _kind varchar)
{
  declare v varchar;
  if (_var is not null)
    v := DB.DBA.GQL_NODE_SPARQL_VAR (_var);
  else
    v := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, concat ('new_', _kind));
  DB.DBA.GQL_CTX_SET (_ctx, 'binds', concat (DB.DBA.GQL_CTX_GET (_ctx, 'binds'),
    '  BIND (IRI (CONCAT ("', DB.DBA.GQL_DATA_NS_CTX (_ctx), _kind, '", STRUUID ())) AS ', v, ')\n'));
  DB.DBA.GQL_CTX_SET (_ctx, 'insert_fresh', 1);
  return v;
}
;

-- The labels of a node pattern being inserted, as a flat list of names: an
-- inserted node has a definite set of labels, A & B, not an alternative,
-- a negation or the wildcard.
create procedure DB.DBA.GQL_INSERT_LABELS (in _labels any)
{
  declare res any;
  declare i integer;
  vectorbld_init (res);
  for (i := 0; i < length (_labels); i := i + 1)
    DB.DBA.GQL_INSERT_LABELS_ACC (aref (_labels, i), res);
  vectorbld_final (res);
  return res;
}
;

create procedure DB.DBA.GQL_INSERT_LABELS_ACC (in _label any, inout _res any)
{
  declare i integer;
  if (isstring (_label))
    {
      vectorbld_acc (_res, _label);
      return;
    }
  if (isvector (_label) and aref (_label, 0) = 'LABEL_AND')
    {
      for (i := 0; i < length (aref (_label, 1)); i := i + 1)
        DB.DBA.GQL_INSERT_LABELS_ACC (aref (aref (_label, 1), i), _res);
      return;
    }
  signal ('G2004', 'An inserted node takes a set of labels (A & B), not a label expression with |, ! or %');
}
;

-- 1 when _s, translated SPARQL, is an RDF term an update template can hold
-- as it is: an IRI, a literal (typed or tagged), a number or a boolean.  A
-- function call or other expression is bound in the WHERE clause instead.
create procedure DB.DBA.GQL_SPARQL_IS_TERM (in _s varchar)
{
  declare n, i integer;
  _s := trim (_s);
  n := length (_s);
  if (n = 0)
    return 0;
  if (aref (_s, 0) = 60)
    return case when aref (_s, n - 1) = 62 and strchr (_s, ' ') is null then 1 else 0 end;
  if (aref (_s, 0) = 34)
    {
      for (i := 1; i < n; i := i + 1)
        {
          if (aref (_s, i) = 92)
            i := i + 1;
          else if (aref (_s, i) = 34)
            goto closed;
        }
      return 0;
    closed:
      if (i = n - 1)
        return 1;
      if (subseq (_s, i + 1, i + 3) = '^^' or aref (_s, i + 1) = 64)
        return case when strchr (subseq (_s, i + 1), ' ') is null and strchr (subseq (_s, i + 1), '(') is null then 1 else 0 end;
      return 0;
    }
  if (_s in ('true', 'false'))
    return 1;
  if (regexp_match ('^[-+]?[0-9]+(\\.[0-9]*)?([eE][-+]?[0-9]+)?$', _s) is not null)
    return 1;
  return 0;
}
;

create procedure DB.DBA.GQL_GEN_INSERT_WHERE (in _insert_asts any, in _match_asts any, inout _ctx any)
{
  declare sparql_text, insert_body, where_body, dataset varchar;
  declare i, pi integer;
  declare clause, patterns, graph_expr any;
  declare graph varchar;

  graph := DB.DBA.GQL_CTX_GET (_ctx, 'graph');

  -- A variable is one node across all the patterns of the statement's
  -- INSERTs: its term, by name.  With a MATCH, a variable the MATCH binds
  -- is that node; any other node the INSERT creates is a new one for each
  -- row (GQL_INSERT_FRESH_VAR) -- except in a translation that runs many
  -- times (marker mode 'all'), whose executor binds a fresh IRI on each
  -- run (GQL_FRESH_IRI_SLOT).
  declare var_terms, var_described any;
  declare match_text varchar;
  declare fresh_row integer;
  var_terms := DB.DBA.GQL_CTX_GET (_ctx, 'insert_var_terms');
  if (var_terms is null)
    {
      var_terms := dict_new (31);
      DB.DBA.GQL_CTX_SET (_ctx, 'insert_var_terms', var_terms);
    }
  -- The variables a node pattern has already described with labels or
  -- properties: a second description is an error, not a merge.
  var_described := dict_new (31);
  match_text := '';
  fresh_row := 0;
  if (length (_match_asts) > 0)
    {
      match_text := concat (DB.DBA.GQL_CTX_GET (_ctx, 'pre_values'), DB.DBA.GQL_CTX_GET (_ctx, 'pre_binds'),
        DB.DBA.GQL_CTX_GET (_ctx, 'triples'), DB.DBA.GQL_CTX_GET (_ctx, 'filters'),
        DB.DBA.GQL_CTX_GET (_ctx, 'binds'), DB.DBA.GQL_CTX_GET (_ctx, 'optionals'));
      if (coalesce (connection_get ('gql_marker_mode'), '') <> 'all')
        fresh_row := 1;
    }

  -- Build INSERT body
  insert_body := '';
  for (i := 0; i < length (_insert_asts); i := i + 1)
    {
      clause := aref (_insert_asts, i);
      if (not isarray (clause)) goto ins_next;
      patterns := aref (clause, 1);
      for (pi := 0; pi < length (patterns); pi := pi + 1)
        {
          declare pat_elems, elem, elem_subjects any;
          declare ei integer;
          pat_elems := aref (aref (patterns, pi), 1);
          elem_subjects := vector ();
          for (ei := 0; ei < length (pat_elems); ei := ei + 1)
            {
              elem := aref (pat_elems, ei);
              if (isarray (elem) and aref (elem, 0) = 'NODE')
                {
                  declare pre_uri varchar;
                  declare nvar any;
                  nvar := aref (elem, 1);
                  pre_uri := null;
                  if (nvar is not null
                      and (length (aref (elem, 2)) > 0 or length (aref (elem, 3)) > 0))
                    {
                      if (dict_get (var_described, nvar, 0))
                        signal ('G3014', sprintf ('INSERT describes variable %s twice; after its labels and properties are given once, refer to it as (%s)',
                          cast (nvar as varchar), cast (nvar as varchar)));
                      dict_put (var_described, nvar, 1);
                    }
                  if (nvar is not null)
                    pre_uri := dict_get (var_terms, nvar, null);
                  if (pre_uri is null and nvar is not null and length (_match_asts) > 0
                      and DB.DBA.GQL_TEXT_HAS_VAR (match_text, DB.DBA.GQL_NODE_SPARQL_VAR (nvar)))
                    pre_uri := DB.DBA.GQL_NODE_SPARQL_VAR (nvar);
                  if (pre_uri is null)
                    {
                      pre_uri := DB.DBA.GQL_NODE_INSERT_URI (aref (elem, 3), _ctx);
                      if (pre_uri is null)
                        {
                          -- Translated to run many times, the new node is a
                          -- variable bound to a fresh IRI on every run.
                          if (connection_get ('gql_marker_mode') = 'all')
                            pre_uri := DB.DBA.GQL_FRESH_IRI_SLOT (concat (DB.DBA.GQL_DATA_NS_CTX (_ctx), 'node_'));
                          else if (fresh_row)
                            pre_uri := DB.DBA.GQL_INSERT_FRESH_VAR (_ctx, nvar, 'node_');
                          else
                            pre_uri := concat ('<', DB.DBA.GQL_NEW_NODE_URI_CTX (_ctx), '>');
                        }
                    }
                  if (nvar is not null)
                    dict_put (var_terms, nvar, pre_uri);
                  elem_subjects := vector_concat (elem_subjects, vector (pre_uri));
                }
              else
                elem_subjects := vector_concat (elem_subjects, vector (null));
            }
          for (ei := 0; ei < length (pat_elems); ei := ei + 1)
            {
              elem := aref (pat_elems, ei);
              if (not isarray (elem)) goto elem_next;
              if (aref (elem, 0) = 'NODE')
                {
                  declare new_uri, nsv varchar;
                  declare labels, props any;
                  declare li, prii integer;
                  declare nvar_name any;
                  nvar_name := aref (elem, 1);
                  labels := DB.DBA.GQL_INSERT_LABELS (aref (elem, 2));
                  props := aref (elem, 3);

                  new_uri := aref (elem_subjects, ei);
                  nsv := new_uri;

                  -- Bind the node variable to the new URI
                  if (nvar_name is not null)
                    {
                      -- If this node variable is bound by MATCH, skip
                      -- generating label/property triples — the node already
                      -- exists; only edge triples should be inserted.
                      if (length (_match_asts) > 0 and length (labels) = 0 and length (props) = 0)
                        goto elem_next;
                      -- Note: we deliberately do NOT assert an implicit
                      -- <...>#Node type here.  A node's triples are exactly the
                      -- labels and properties the query states; GQL matching
                      -- never relies on a synthetic Node type, so emitting one
                      -- would silently add a type the user did not ask for.
                      DB.DBA.GQL_CTX_ADD_VAR (_ctx, nvar_name);
                    }

                  -- Emit label triples
                  for (li := 0; li < length (labels); li := li + 1)
                    {
                      insert_body := concat (insert_body, '  ',
                        nsv, ' a ',
                        DB.DBA.GQL_GEN_LABEL_IRI_CTX (aref (labels, li), _ctx), ' .\n');
                    }

                  -- Emit property triples
                  for (prii := 0; prii < length (props); prii := prii + 1)
                    {
                      declare pk, pv any;
                      pk := aref (aref (props, prii), 0);
                      pv := aref (aref (props, prii), 1);
                      if (lower (cast (pk as varchar)) = 'iri')
                        goto prop_next;
                      insert_body := concat (insert_body, '  ',
                        nsv, ' ',
                        DB.DBA.GQL_GEN_PROP_IRI_CTX (pk, _ctx), ' ',
                        DB.DBA.GQL_GEN_EXPR (pv, _ctx), ' .\n');
                    prop_next:;
                    }
                }
              else if (aref (elem, 0) = 'EDGE')
                {
                  declare evar, etypes, edir, eprops any;
                  declare etidx integer;
                  declare esrc_var, edst_var varchar;
                  declare annot_mode integer;
                  declare tt_mode integer;
                  declare reifier_n varchar;
                  evar := aref (elem, 1);
                  etypes := aref (elem, 2);
                  edir := aref (elem, 3);
                  eprops := aref (elem, 5);
                  annot_mode := 0;
                  tt_mode := 0;
                  reifier_n := null;
                  if (length (elem) > 8)
                    annot_mode := aref (elem, 8);
                  if (length (elem) > 9)
                    tt_mode := aref (elem, 9);
                  if (length (elem) > 10)
                    reifier_n := aref (elem, 10);

                  -- Find source and destination from adjacent NODEs
                  esrc_var := null; edst_var := null;
                  if (ei > 0)
                    {
                      declare prev_e any;
                      prev_e := aref (pat_elems, ei - 1);
                      if (isarray (prev_e) and aref (prev_e, 0) = 'NODE')
                        esrc_var := aref (elem_subjects, ei - 1);
                    }
                  if (ei + 1 < length (pat_elems))
                    {
                      declare next_e any;
                      next_e := aref (pat_elems, ei + 1);
                      if (isarray (next_e) and aref (next_e, 0) = 'NODE')
                        edst_var := aref (elem_subjects, ei + 1);
                    }

                  if (esrc_var is null) esrc_var := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'src_');
                  if (edst_var is null) edst_var := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'dst_');

                  -- Handle direction for INSERT
                  if (edir = 'LEFT') { declare t varchar; t := esrc_var; esrc_var := edst_var; edst_var := t; }

                  for (etidx := 0; etidx < length (etypes); etidx := etidx + 1)
                    {
                      insert_body := concat (insert_body, '  ', esrc_var, ' ',
                        DB.DBA.GQL_GEN_EDGE_TYPE_IRI_CTX (aref (etypes, etidx), _ctx), ' ',
                        edst_var, ' .\n');
                    }

                  -- Edge properties: RDF 1.2 triple-term, annotation, or classic reification
                  if (length (eprops) > 0)
                    {
                      -- Determine effective mode:
                      --   tt_mode=1 → explicit <<( )>> triple-term (standard RDF 1.2)
                      --   tt_mode=2 → explicit << >> reified-triple shorthand
                      --   annot_mode=1 → {| |} annotation
                      --   rdf12_mode → default to triple-term
                      --   else → classic reification
                      declare eff_mode integer;
                      declare reifier_var varchar;
                      eff_mode := 0;  -- 0=classic, 1=triple-term, 2=annotation, 3=reified-shorthand
                      if (tt_mode = 1)
                        { eff_mode := 1; }
                      else if (tt_mode = 2)
                        { eff_mode := 3; }
                      else if (annot_mode = 1)
                        { eff_mode := 2; }
                      else if (DB.DBA.GQL_CTX_GET (_ctx, 'rdf12_mode') = 1)
                        { eff_mode := 1; }

                      -- Determine reifier variable/IRI: a given reifier, else
                      -- a new blank node -- the edge is new, so its variable,
                      -- if it has one, is bound to nothing yet.
                      reifier_var := null;
                      if (reifier_n is not null)
                        { reifier_var := reifier_n; }

                      if (evar is not null)
                        { DB.DBA.GQL_CTX_ADD_VAR (_ctx, evar); }

                      if (eff_mode = 2)
                        {
                          for (etidx := 0; etidx < length (etypes); etidx := etidx + 1)
                            {
                              declare annot_body varchar;
                              annot_body := '';
                              for (declare epi integer, epi := 0; epi < length (eprops); epi := epi + 1)
                                {
                                  annot_body := concat (annot_body, case when annot_body = '' then '' else ' ; ' end,
                                    DB.DBA.GQL_GEN_PROP_IRI_CTX (aref (aref (eprops, epi), 0), _ctx), ' ',
                                    DB.DBA.GQL_GEN_EXPR (aref (aref (eprops, epi), 1), _ctx));
                                }
                              insert_body := concat (insert_body, '  ', esrc_var, ' ',
                                DB.DBA.GQL_GEN_EDGE_TYPE_IRI_CTX (aref (etypes, etidx), _ctx), ' ',
                                edst_var, ' {| ', annot_body, ' |} .\n');
                            }
                        }
                      else if (eff_mode = 1)
                        {
                          -- Standard RDF 1.2: reifier rdf:reifies <<(s p o)>> . reifier prop val .
                          declare rsv varchar;
                          if (reifier_var is not null)
                            { rsv := reifier_var; }
                          else
                            { rsv := concat ('_:', subseq (DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'reif_'), 1)); }
                          for (etidx := 0; etidx < length (etypes); etidx := etidx + 1)
                            {
                              declare tt_obj varchar;
                              tt_obj := concat ('<<(', esrc_var, ' ',
                                DB.DBA.GQL_GEN_EDGE_TYPE_IRI_CTX (aref (etypes, etidx), _ctx), ' ',
                                edst_var, ')>>');
                              insert_body := concat (insert_body, '  ', rsv, ' rdf:reifies ', tt_obj, ' .\n');
                              for (declare epi integer, epi := 0; epi < length (eprops); epi := epi + 1)
                                {
                                  insert_body := concat (insert_body, '  ', rsv, ' ',
                                    DB.DBA.GQL_GEN_PROP_IRI_CTX (aref (aref (eprops, epi), 0), _ctx), ' ',
                                    DB.DBA.GQL_GEN_EXPR (aref (aref (eprops, epi), 1), _ctx), ' .\n');
                                }
                            }
                        }
                      else if (eff_mode = 3)
                        {
                          declare rsv varchar;
                          if (reifier_var is not null)
                            { rsv := reifier_var; }
                          else
                            { rsv := concat ('_:', subseq (DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'reif_'), 1)); }
                          for (etidx := 0; etidx < length (etypes); etidx := etidx + 1)
                            {
                              declare rt_str varchar;
                              rt_str := concat ('<<', esrc_var, ' ',
                                DB.DBA.GQL_GEN_EDGE_TYPE_IRI_CTX (aref (etypes, etidx), _ctx), ' ',
                                edst_var, ' ~ ', rsv, '>>');
                              for (declare epi integer, epi := 0; epi < length (eprops); epi := epi + 1)
                                {
                                  insert_body := concat (insert_body, '  ', rt_str, ' ',
                                    DB.DBA.GQL_GEN_PROP_IRI_CTX (aref (aref (eprops, epi), 0), _ctx), ' ',
                                    DB.DBA.GQL_GEN_EXPR (aref (aref (eprops, epi), 1), _ctx), ' .\n');
                                }
                            }
                        }
                      else
                        {
                          declare esv varchar;
                          -- The edge's statement IRI, like a new node's, is
                          -- fresh on every run of a many-times translation.
                          if (connection_get ('gql_marker_mode') = 'all')
                            esv := DB.DBA.GQL_FRESH_IRI_SLOT (concat (DB.DBA.GQL_DATA_NS_CTX (_ctx), 'edge_'));
                          else if (fresh_row)
                            esv := DB.DBA.GQL_INSERT_FRESH_VAR (_ctx, null, 'edge_');
                          else
                            esv := concat ('<', DB.DBA.GQL_NEW_EDGE_URI_CTX (_ctx), '>');
                          -- Only use reifier_var as edge subject if it's a concrete IRI
                          -- (not a SPARQL variable like ?gql_e_r)
                          if (reifier_var is not null and subseq (reifier_var, 0, 1) <> '?')
                            { esv := reifier_var; }

                          insert_body := concat (insert_body, '  ', esv, ' a rdf:Statement .\n');
                          insert_body := concat (insert_body, '  ', esv, ' rdf:subject ', esrc_var, ' .\n');
                          for (etidx := 0; etidx < length (etypes); etidx := etidx + 1)
                            {
                              insert_body := concat (insert_body, '  ', esv, ' rdf:predicate ',
                                DB.DBA.GQL_GEN_EDGE_TYPE_IRI_CTX (aref (etypes, etidx), _ctx), ' .\n');
                            }
                          insert_body := concat (insert_body, '  ', esv, ' rdf:object ', edst_var, ' .\n');

                          declare epi integer;
                          for (epi := 0; epi < length (eprops); epi := epi + 1)
                            {
                              insert_body := concat (insert_body, '  ', esv, ' ',
                                DB.DBA.GQL_GEN_PROP_IRI_CTX (aref (aref (eprops, epi), 0), _ctx), ' ',
                                DB.DBA.GQL_GEN_EXPR (aref (aref (eprops, epi), 1), _ctx), ' .\n');
                            }
                        }
                    }
                }
            elem_next:;
            }
        }
    ins_next:;
    }
  DB.DBA.GQL_CTX_SET (_ctx, 'insert_body', insert_body);

  -- Build WHERE body from MATCH patterns (already in context triples)
  where_body := DB.DBA.GQL_CTX_GET (_ctx, 'pre_values');
  where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'pre_binds'));
  where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'triples'));
  where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'filters'));
  where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'binds'));

  -- Compose final SPARQL
  sparql_text := concat ('SPARQL ', DB.DBA.GQL_GEN_DEFINE_CLAUSE (_ctx), DB.DBA.GQL_GEN_BASE_CLAUSE (_ctx));
  sparql_text := concat (sparql_text, 'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>\n');
  sparql_text := concat (sparql_text, 'PREFIX gql: <', DB.DBA.GQL_NS_CTX (_ctx), '>\n');

  -- WITH before the templates, USING / USING NAMED before WHERE
  declare using_s varchar;
  dataset := DB.DBA.GQL_GEN_UPDATE_DATASET (_ctx);
  using_s := DB.DBA.GQL_GEN_UPDATE_USING (_ctx);
  sparql_text := concat (sparql_text, dataset);

  -- Standalone INSERT (no MATCH): emit INSERT DATA { GRAPH <g> { ... } }
  -- (bare INSERT DATA { ... } when no graph was named).
  if (length (_match_asts) = 0)
    {
      sparql_text := concat (sparql_text, 'INSERT DATA {\n');
      sparql_text := concat (sparql_text, DB.DBA.GQL_DML_G_WRAP_TRIPLES (graph, insert_body));
      sparql_text := concat (sparql_text, '}\n');
      return sparql_text;
    }

  -- INSERT with MATCH: INSERT { ... } WHERE { match BGP }.  The MATCH is
  -- matched in the graph written to, as SET, REMOVE and DELETE match theirs,
  -- unless the statement names its own dataset.
  sparql_text := concat (sparql_text, 'INSERT {\n');
  sparql_text := concat (sparql_text, DB.DBA.GQL_DML_G_WRAP_TRIPLES (graph, insert_body));
  sparql_text := concat (sparql_text, '} ', using_s, 'WHERE {\n');
  if (dataset = '' and using_s = '')
    sparql_text := concat (sparql_text, DB.DBA.GQL_DML_G_OPEN (graph), where_body, DB.DBA.GQL_DML_G_CLOSE (graph));
  else
    sparql_text := concat (sparql_text, where_body);
  sparql_text := concat (sparql_text, '}\n');

  return sparql_text;
}
;

----------------------------------------------------------------------
-- CONSTRUCT: GQL template patterns → SPARQL CONSTRUCT template
----------------------------------------------------------------------

create procedure DB.DBA.GQL_CONSTRUCT_NODE_TERM (in _elem any, in _pi integer, in _ei integer, inout _ctx any)
{
  declare nvar_name any;
  declare pre_uri varchar;

  nvar_name := aref (_elem, 1);
  if (nvar_name is not null)
    return DB.DBA.GQL_NODE_SPARQL_VAR (nvar_name);

  pre_uri := DB.DBA.GQL_NODE_INSERT_URI (aref (_elem, 3), _ctx);
  if (pre_uri is not null)
    return pre_uri;

  return concat ('_:gql_c_', cast (_pi as varchar), '_', cast (_ei as varchar));
}
;

create procedure DB.DBA.GQL_GEN_CONSTRUCT_TEMPLATE (in _construct_asts any, inout _ctx any)
{
  declare construct_body varchar;
  declare i, pi integer;
  declare clause, patterns any;

  construct_body := '';
  for (i := 0; i < length (_construct_asts); i := i + 1)
    {
      clause := aref (_construct_asts, i);
      if (not isarray (clause)) goto construct_clause_next;
      patterns := aref (clause, 1);
      for (pi := 0; pi < length (patterns); pi := pi + 1)
        {
          declare pat_elems, elem, elem_subjects any;
          declare ei integer;
          pat_elems := aref (aref (patterns, pi), 1);
          elem_subjects := vector ();

          for (ei := 0; ei < length (pat_elems); ei := ei + 1)
            {
              elem := aref (pat_elems, ei);
              if (isarray (elem) and aref (elem, 0) = 'NODE')
                elem_subjects := vector_concat (elem_subjects,
                  vector (DB.DBA.GQL_CONSTRUCT_NODE_TERM (elem, pi, ei, _ctx)));
              else
                elem_subjects := vector_concat (elem_subjects, vector (null));
            }

          for (ei := 0; ei < length (pat_elems); ei := ei + 1)
            {
              elem := aref (pat_elems, ei);
              if (not isarray (elem)) goto construct_elem_next;
              if (aref (elem, 0) = 'NODE')
                {
                  declare nsv varchar;
                  declare labels, props any;
                  declare li, prii integer;
                  nsv := aref (elem_subjects, ei);
                  labels := aref (elem, 2);
                  props := aref (elem, 3);

                  for (li := 0; li < length (labels); li := li + 1)
                    {
                      declare construct_label any;
                      construct_label := aref (labels, li);
                      if (isarray (construct_label) and aref (construct_label, 0) = 'LABEL_OR')
                        {
                          declare construct_label_choices any;
                          declare cli integer;
                          construct_label_choices := aref (construct_label, 1);
                          for (cli := 0; cli < length (construct_label_choices); cli := cli + 1)
                            construct_body := concat (construct_body, '  ',
                              nsv, ' a ', DB.DBA.GQL_GEN_LABEL_IRI_CTX (aref (construct_label_choices, cli), _ctx), ' .\n');
                        }
                      else
                        construct_body := concat (construct_body, '  ',
                          nsv, ' a ', DB.DBA.GQL_GEN_LABEL_IRI_CTX (construct_label, _ctx), ' .\n');
                    }

                  for (prii := 0; prii < length (props); prii := prii + 1)
                    {
                      declare pk, pv any;
                      pk := aref (aref (props, prii), 0);
                      pv := aref (aref (props, prii), 1);
                      if (lower (cast (pk as varchar)) = 'iri')
                        goto construct_node_prop_next;
                      construct_body := concat (construct_body, '  ',
                        nsv, ' ', DB.DBA.GQL_GEN_PROP_IRI_CTX (pk, _ctx), ' ',
                        DB.DBA.GQL_GEN_EXPR (pv, _ctx), ' .\n');
                    construct_node_prop_next:;
                    }
                }
              else if (aref (elem, 0) = 'EDGE')
                {
                  declare evar, etypes, edir, eprops any;
                  declare etidx integer;
                  declare esrc_var, edst_var varchar;
                  declare annot_mode integer;
                  declare tt_mode integer;
                  declare reifier_n varchar;
                  evar := aref (elem, 1);
                  etypes := aref (elem, 2);
                  edir := aref (elem, 3);
                  eprops := aref (elem, 5);
                  annot_mode := 0;
                  tt_mode := 0;
                  reifier_n := null;
                  if (length (elem) > 8)
                    annot_mode := aref (elem, 8);
                  if (length (elem) > 9)
                    tt_mode := aref (elem, 9);
                  if (length (elem) > 10)
                    reifier_n := aref (elem, 10);

                  esrc_var := null; edst_var := null;
                  if (ei > 0)
                    {
                      declare prev_e any;
                      prev_e := aref (pat_elems, ei - 1);
                      if (isarray (prev_e) and aref (prev_e, 0) = 'NODE')
                        esrc_var := aref (elem_subjects, ei - 1);
                    }
                  if (ei + 1 < length (pat_elems))
                    {
                      declare next_e any;
                      next_e := aref (pat_elems, ei + 1);
                      if (isarray (next_e) and aref (next_e, 0) = 'NODE')
                        edst_var := aref (elem_subjects, ei + 1);
                    }
                  if (esrc_var is null)
                    esrc_var := concat ('_:gql_c_src_', cast (pi as varchar), '_', cast (ei as varchar));
                  if (edst_var is null)
                    edst_var := concat ('_:gql_c_dst_', cast (pi as varchar), '_', cast (ei as varchar));

                  if (edir = 'LEFT')
                    { declare t varchar; t := esrc_var; esrc_var := edst_var; edst_var := t; }

                  for (etidx := 0; etidx < length (etypes); etidx := etidx + 1)
                    construct_body := concat (construct_body, '  ', esrc_var, ' ',
                      DB.DBA.GQL_GEN_EDGE_TYPE_IRI_CTX (aref (etypes, etidx), _ctx), ' ',
                      edst_var, ' .\n');

                  if (length (eprops) > 0)
                    {
                      -- Determine effective mode (same logic as INSERT path)
                      declare eff_mode integer;
                      declare reifier_var varchar;
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
                        { reifier_var := reifier_n; }
                      else if (evar is not null)
                        { reifier_var := DB.DBA.GQL_EDGE_SPARQL_VAR (evar); }

                      if (eff_mode = 2)  -- annotation {| |}
                        {
                          for (etidx := 0; etidx < length (etypes); etidx := etidx + 1)
                            {
                              declare annot_body varchar;
                              annot_body := '';
                              for (declare epi integer, epi := 0; epi < length (eprops); epi := epi + 1)
                                {
                                  annot_body := concat (annot_body, case when annot_body = '' then '' else ' ; ' end,
                                    DB.DBA.GQL_GEN_PROP_IRI_CTX (aref (aref (eprops, epi), 0), _ctx), ' ',
                                    DB.DBA.GQL_GEN_EXPR (aref (aref (eprops, epi), 1), _ctx));
                                }
                              construct_body := concat (construct_body, '  ', esrc_var, ' ',
                                DB.DBA.GQL_GEN_EDGE_TYPE_IRI_CTX (aref (etypes, etidx), _ctx), ' ',
                                edst_var, ' {| ', annot_body, ' |} .\n');
                            }
                        }
                      else if (eff_mode = 1)  -- triple-term <<(s p o)>>
                        {
                          declare rsv varchar;
                          if (reifier_var is not null)
                            rsv := reifier_var;
                          else
                            rsv := concat ('_:gql_reif_', cast (pi as varchar), '_', cast (ei as varchar));
                          for (etidx := 0; etidx < length (etypes); etidx := etidx + 1)
                            {
                              declare tt_obj varchar;
                              tt_obj := concat ('<<(', esrc_var, ' ',
                                DB.DBA.GQL_GEN_EDGE_TYPE_IRI_CTX (aref (etypes, etidx), _ctx), ' ',
                                edst_var, ')>>');
                              construct_body := concat (construct_body, '  ', rsv, ' rdf:reifies ', tt_obj, ' .\n');
                              for (declare epi integer, epi := 0; epi < length (eprops); epi := epi + 1)
                                {
                                  construct_body := concat (construct_body, '  ', rsv, ' ',
                                    DB.DBA.GQL_GEN_PROP_IRI_CTX (aref (aref (eprops, epi), 0), _ctx), ' ',
                                    DB.DBA.GQL_GEN_EXPR (aref (aref (eprops, epi), 1), _ctx), ' .\n');
                                }
                            }
                        }
                      else if (eff_mode = 3)  -- reified-triple shorthand << s p o ~ r >>
                        {
                          declare rsv varchar;
                          if (reifier_var is not null)
                            rsv := reifier_var;
                          else
                            rsv := concat ('_:gql_reif_', cast (pi as varchar), '_', cast (ei as varchar));
                          for (etidx := 0; etidx < length (etypes); etidx := etidx + 1)
                            {
                              declare rt_str varchar;
                              rt_str := concat ('<<', esrc_var, ' ',
                                DB.DBA.GQL_GEN_EDGE_TYPE_IRI_CTX (aref (etypes, etidx), _ctx), ' ',
                                edst_var, ' ~ ', rsv, '>>');
                              for (declare epi integer, epi := 0; epi < length (eprops); epi := epi + 1)
                                {
                                  construct_body := concat (construct_body, '  ', rt_str, ' ',
                                    DB.DBA.GQL_GEN_PROP_IRI_CTX (aref (aref (eprops, epi), 0), _ctx), ' ',
                                    DB.DBA.GQL_GEN_EXPR (aref (aref (eprops, epi), 1), _ctx), ' .\n');
                                }
                            }
                        }
                      else  -- classic reification
                        {
                          declare esv varchar;
                          declare epi integer;
                          if (evar is not null)
                            esv := DB.DBA.GQL_EDGE_SPARQL_VAR (evar);
                          else
                            esv := concat ('_:gql_ce_', cast (pi as varchar), '_', cast (ei as varchar));

                          construct_body := concat (construct_body, '  ', esv, ' a rdf:Statement .\n');
                          construct_body := concat (construct_body, '  ', esv, ' rdf:subject ', esrc_var, ' .\n');
                          for (etidx := 0; etidx < length (etypes); etidx := etidx + 1)
                            construct_body := concat (construct_body, '  ', esv, ' rdf:predicate ',
                              DB.DBA.GQL_GEN_EDGE_TYPE_IRI_CTX (aref (etypes, etidx), _ctx), ' .\n');
                          construct_body := concat (construct_body, '  ', esv, ' rdf:object ', edst_var, ' .\n');

                          for (epi := 0; epi < length (eprops); epi := epi + 1)
                            construct_body := concat (construct_body, '  ', esv, ' ',
                              DB.DBA.GQL_GEN_PROP_IRI_CTX (aref (aref (eprops, epi), 0), _ctx), ' ',
                              DB.DBA.GQL_GEN_EXPR (aref (aref (eprops, epi), 1), _ctx), ' .\n');
                        }
                    }
                }
            construct_elem_next:;
            }
        }
    construct_clause_next:;
    }

  return construct_body;
}
;

create procedure DB.DBA.GQL_GEN_CONSTRUCT_RETURN_TEMPLATE (in _return_ast any, inout _ctx any)
{
  declare construct_body varchar;
  declare items any;
  declare i integer;

  construct_body := '';
  if (_return_ast is null or not isarray (_return_ast))
    return construct_body;
  if (length (_return_ast) < 3 or aref (_return_ast, 2) is null)
    return construct_body;

  items := aref (_return_ast, 2);
  for (i := 0; i < length (items); i := i + 1)
    {
      declare item, expr any;
      item := aref (items, i);
      if (not isarray (item) or length (item) < 2)
        goto construct_return_next;
      expr := aref (item, 1);

      if (isarray (expr) and aref (expr, 0) = 'PROP')
        {
          declare subj, obj, prop_name varchar;
          subj := DB.DBA.GQL_GEN_EXPR (aref (expr, 1), _ctx);
          obj := DB.DBA.GQL_GEN_EXPR (expr, _ctx);
          prop_name := aref (expr, 2);
          construct_body := concat (construct_body, '  ', subj, ' ',
            DB.DBA.GQL_GEN_PROP_IRI_CTX (prop_name, _ctx), ' ', obj, ' .\n');
        }

    construct_return_next:;
    }

  return construct_body;
}
;

create procedure DB.DBA.GQL_GEN_CONSTRUCT_WHERE
  (in _construct_asts any, inout _ctx any, in _order_items any, in _limit_expr varchar,
   in _offset_expr varchar, in _extra_construct_body varchar, in _seed_template_where integer)
{
  declare sparql_text, base_construct_body, construct_body, where_body varchar;

  base_construct_body := DB.DBA.GQL_GEN_CONSTRUCT_TEMPLATE (_construct_asts, _ctx);
  construct_body := concat (base_construct_body, coalesce (_extra_construct_body, ''));
  where_body := '';
  if (_seed_template_where)
    where_body := concat (where_body, base_construct_body);
  where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'values'));
  where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'pre_values'));
  where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'pre_binds'));
  where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'triples'));
  where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'binds'));
  where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'filters'));
  where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'optionals'));
  if (where_body = '')
    where_body := construct_body;

  sparql_text := concat ('SPARQL ',
    DB.DBA.GQL_GEN_DEFINE_CLAUSE (_ctx),
    DB.DBA.GQL_EMIT_PREFIX_BLOCK (_ctx));
  sparql_text := concat (sparql_text, 'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>\n');
  sparql_text := concat (sparql_text, 'PREFIX gql: <', DB.DBA.GQL_NS_CTX (_ctx), '>\n');
  sparql_text := concat (sparql_text, 'CONSTRUCT {\n', construct_body, '}\n');
  sparql_text := concat (sparql_text, DB.DBA.GQL_GEN_FROM_CLAUSES (_ctx));
  sparql_text := concat (sparql_text, DB.DBA.GQL_EMIT_WHERE (_ctx, where_body));
  sparql_text := concat (sparql_text,
    DB.DBA.GQL_EMIT_SOLUTION_MODIFIER (_ctx, _order_items, _limit_expr, _offset_expr));

  return sparql_text;
}
;

create procedure DB.DBA.GQL_GEN_DESCRIBE_WHERE
  (in _describe_ast any, inout _ctx any, in _order_items any, in _limit_expr varchar, in _offset_expr varchar)
{
  declare sparql_text, describe_items, where_body varchar;
  declare items any;
  declare i integer;

  describe_items := '';
  items := aref (_describe_ast, 1);
  for (i := 0; i < length (items); i := i + 1)
    {
      declare ditem any;
      ditem := aref (items, i);
      if (describe_items <> '')
        describe_items := concat (describe_items, ' ');
      if (isarray (ditem) and aref (ditem, 0) = 'VAR' and aref (ditem, 1) = '*')
        describe_items := concat (describe_items, '*');
      else
        describe_items := concat (describe_items, DB.DBA.GQL_GEN_EXPR (ditem, _ctx));
    }
  if (describe_items = '')
    describe_items := '*';

  where_body := '';
  where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'values'));
  where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'pre_values'));
  where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'pre_binds'));
  where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'triples'));
  where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'binds'));
  where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'filters'));
  where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'optionals'));

  sparql_text := concat ('SPARQL ',
    DB.DBA.GQL_GEN_DEFINE_CLAUSE (_ctx),
    DB.DBA.GQL_EMIT_PREFIX_BLOCK (_ctx));
  sparql_text := concat (sparql_text, 'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>\n');
  sparql_text := concat (sparql_text, 'PREFIX gql: <', DB.DBA.GQL_NS_CTX (_ctx), '>\n');
  sparql_text := concat (sparql_text, 'DESCRIBE ', describe_items, '\n');
  sparql_text := concat (sparql_text, DB.DBA.GQL_GEN_FROM_CLAUSES (_ctx));
  if (where_body <> '')
    sparql_text := concat (sparql_text, DB.DBA.GQL_EMIT_WHERE (_ctx, where_body));
  sparql_text := concat (sparql_text,
    DB.DBA.GQL_EMIT_SOLUTION_MODIFIER (_ctx, _order_items, _limit_expr, _offset_expr));

  return sparql_text;
}
;

----------------------------------------------------------------------
-- DML: DELETE / SET / REMOVE via SPARQL Update
----------------------------------------------------------------------

-- Whether the SPARQL text _text uses the variable _var (?name), not just a
-- longer name it begins.
create procedure DB.DBA.GQL_TEXT_HAS_VAR (in _text varchar, in _var varchar)
{
  declare pos, nxt integer;

  pos := 0;
  while (1)
    {
      declare hit any;
      hit := strstr (subseq (_text, pos), _var);
      if (hit is null)
        return 0;
      pos := pos + hit + length (_var);
      if (pos >= length (_text))
        return 1;
      nxt := aref (_text, pos);
      if (not ((nxt >= 48 and nxt <= 57) or (nxt >= 65 and nxt <= 90) or (nxt >= 97 and nxt <= 122) or nxt = 95))
        return 1;
    }
}
;

-- The triples of DELETE DATA (pattern): ground triples only, so every node
-- is named by its iri property, and an edge is one triple between two such
-- nodes (an edge with properties has a holder no pattern can name).
create procedure DB.DBA.GQL_GEN_DELETE_DATA_TRIPLES (in _patterns any, inout _ctx any)
{
  declare body, prev_s, edge_p varchar;
  declare edge_dir varchar;
  declare pi, ei, li, pri integer;
  body := '';
  for (pi := 0; pi < length (_patterns); pi := pi + 1)
    {
      declare elems any;
      elems := aref (aref (_patterns, pi), 1);
      prev_s := null;
      edge_p := null;
      for (ei := 0; ei < length (elems); ei := ei + 1)
        {
          declare elem any;
          elem := aref (elems, ei);
          if (aref (elem, 0) = 'NODE')
            {
              declare props, labels any;
              declare subj varchar;
              props := aref (elem, 3);
              labels := DB.DBA.GQL_INSERT_LABELS (aref (elem, 2));
              subj := null;
              for (pri := 0; pri < length (props); pri := pri + 1)
                if (lower (cast (aref (aref (props, pri), 0) as varchar)) = 'iri')
                  {
                    declare iri_ast any;
                    iri_ast := aref (aref (props, pri), 1);
                    if (not isarray (iri_ast) or aref (iri_ast, 0) <> 'LIT' or not isstring (aref (iri_ast, 1)))
                      signal ('G2004', 'DELETE DATA needs the iri of each node as a string literal');
                    subj := concat ('<', aref (iri_ast, 1), '>');
                  }
              if (subj is null)
                signal ('G2004', 'DELETE DATA names each node by its iri property; to delete a node found by a pattern use MATCH ... DELETE');
              for (li := 0; li < length (labels); li := li + 1)
                body := concat (body, '  ', subj, ' a ', DB.DBA.GQL_GEN_LABEL_IRI_CTX (aref (labels, li), _ctx), ' .\n');
              for (pri := 0; pri < length (props); pri := pri + 1)
                {
                  if (lower (cast (aref (aref (props, pri), 0) as varchar)) = 'iri')
                    goto dd_prop_next;
                  body := concat (body, '  ', subj, ' ', DB.DBA.GQL_GEN_PROP_IRI_CTX (aref (aref (props, pri), 0), _ctx), ' ',
                    DB.DBA.GQL_GEN_EXPR (aref (aref (props, pri), 1), _ctx), ' .\n');
                dd_prop_next:;
                }
              if (edge_p is not null)
                {
                  if (edge_dir = 'LEFT')
                    body := concat (body, '  ', subj, ' ', edge_p, ' ', prev_s, ' .\n');
                  else
                    body := concat (body, '  ', prev_s, ' ', edge_p, ' ', subj, ' .\n');
                  edge_p := null;
                }
              prev_s := subj;
            }
          else if (aref (elem, 0) = 'EDGE')
            {
              declare etypes any;
              etypes := aref (elem, 2);
              if (length (etypes) <> 1 or not isstring (aref (etypes, 0))
                  or (length (elem) > 5 and isarray (aref (elem, 5)) and length (aref (elem, 5)) > 0)
                  or aref (elem, 4) is not null
                  or aref (elem, 3) not in ('RIGHT', 'LEFT'))
                signal ('G2004', 'DELETE DATA deletes a directed edge of one type with no properties; use MATCH ... DELETE e for the others');
              edge_p := DB.DBA.GQL_GEN_EDGE_TYPE_IRI_CTX (aref (etypes, 0), _ctx);
              edge_dir := aref (elem, 3);
            }
        }
    }
  return body;
}
;

create procedure DB.DBA.GQL_GEN_DML (in _delete_ast any, in _set_ast any, in _remove_ast any, inout _ctx any)
{
  declare sparql_text varchar;
  declare graph varchar;

  -- The template of an INSERT in the same statement (GQL_TO_SPARQL_IMPL):
  -- it goes into the first update emitted below, so that the MATCH is
  -- evaluated once, before anything is deleted.  Null when there is none.
  declare ins_body varchar;
  declare emitted integer;
  ins_body := DB.DBA.GQL_CTX_GET (_ctx, 'dml_insert_body');
  if (ins_body = '')
    ins_body := null;
  emitted := 0;
  -- An INSERT that creates a node or an edge's property holder binds a new
  -- IRI to it for each row (GQL_INSERT_FRESH_VAR).  The update a DELETE,
  -- SET or REMOVE emits has more rows than the MATCH -- one per triple it
  -- deletes -- so its WHERE takes the MATCH's rows, with those IRIs, from a
  -- SELECT DISTINCT that is made before the rest is joined to it (a plain
  -- subquery is merged into the query, and STRUUID () made again for each
  -- of the rows).  m_opts: the MATCH's OPTIONALs, before SET adds its own.
  declare ins_fresh integer;
  declare m_opts varchar;
  ins_fresh := 0;
  if (ins_body is not null and DB.DBA.GQL_CTX_GET (_ctx, 'insert_fresh') = 1)
    ins_fresh := 1;
  m_opts := coalesce (DB.DBA.GQL_CTX_GET (_ctx, 'optionals'), '');

  -- Two or more of DELETE (of what the MATCH binds), SET and REMOVE are one
  -- update: emitted one after another, each would evaluate the MATCH again
  -- after the ones before it changed the graph -- a SET after DELETE e no
  -- longer matches the deleted edge.  The sections leave their templates
  -- (c_del, c_ins), the NODETACH guard (c_guard) and the patterns that bind
  -- what they delete (c_exp) here; the update is put together at the end.
  declare combine, n_upd integer;
  declare c_del, c_ins, c_guard, c_exp varchar;
  n_upd := 0;
  if (_delete_ast is not null and coalesce (aref (_delete_ast, 3), '') <> 'DATA'
      and coalesce (aref (_delete_ast, 3), '') <> 'WHERE')
    n_upd := n_upd + 1;
  if (_set_ast is not null)
    n_upd := n_upd + 1;
  if (_remove_ast is not null)
    n_upd := n_upd + 1;
  combine := case when n_upd > 1 then 1 else 0 end;
  c_del := '';
  c_ins := '';
  c_guard := '';
  c_exp := '';

  graph := DB.DBA.GQL_CTX_GET (_ctx, 'graph');
  sparql_text := concat ('SPARQL ', DB.DBA.GQL_GEN_DEFINE_CLAUSE (_ctx), DB.DBA.GQL_GEN_BASE_CLAUSE (_ctx));

  sparql_text := concat (sparql_text, 'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>\n');
  sparql_text := concat (sparql_text, 'PREFIX gql: <', DB.DBA.GQL_NS_CTX (_ctx), '>\n');

  -- WITH before the templates; USING / USING NAMED before each WHERE.  With
  -- USING the WHERE reads the graphs it names, so it is not put in a GRAPH
  -- block (with no USING NAMED, a GRAPH block in it would match nothing).
  declare using_s, wgraph varchar;
  sparql_text := concat (sparql_text, DB.DBA.GQL_GEN_UPDATE_DATASET (_ctx));
  using_s := DB.DBA.GQL_GEN_UPDATE_USING (_ctx);
  wgraph := case when using_s <> '' then null else graph end;

  -- DELETE section
  if (_delete_ast is not null)
    {
      declare del_items any;
      declare di integer;
      declare del_body, del_body_out, del_body_alt, del_body_edge, match_text, where_body varchar;
      declare del_mode varchar;
      declare del_patterns any;

      del_mode := aref (_delete_ast, 3);
      del_patterns := aref (_delete_ast, 4);
      if (ins_body is not null and (del_mode = 'DATA' or del_mode = 'WHERE'))
        signal ('G2004', sprintf ('DELETE %s with INSERT in one statement is not supported -- use separate statements', del_mode));

      -- DELETE DATA (pattern) → DELETE DATA { GRAPH <g> { ... } }
      -- Ground-triple bulk delete, no WHERE clause
      if (del_mode = 'DATA')
        {
          declare dd_body varchar;
          dd_body := DB.DBA.GQL_GEN_DELETE_DATA_TRIPLES (del_patterns, _ctx);
          sparql_text := concat (sparql_text, 'DELETE DATA {\n', DB.DBA.GQL_DML_G_WRAP (graph, dd_body), '}\n');
          goto dml_set_section;
        }

      -- DELETE WHERE (pattern) → DELETE WHERE { GRAPH <g> { ... } }
      -- Shorthand: template = WHERE body, no separate DELETE template
      if (del_mode = 'WHERE')
        {
          declare dw_ctx any;
          declare dw_body varchar;
          declare dw_pi integer;
          dw_ctx := DB.DBA.GQL_CTX_NEW (graph);
          DB.DBA.GQL_CTX_SET (dw_ctx, 'prefixes', DB.DBA.GQL_CTX_GET (_ctx, 'prefixes'));
          DB.DBA.GQL_CTX_SET (dw_ctx, 'base_uri', DB.DBA.GQL_CTX_GET (_ctx, 'base_uri'));
          DB.DBA.GQL_CTX_SET (dw_ctx, 'force_camelcase', DB.DBA.GQL_CTX_GET (_ctx, 'force_camelcase'));
          for (dw_pi := 0; dw_pi < length (del_patterns); dw_pi := dw_pi + 1)
            DB.DBA.GQL_GEN_MATCH (vector ('MATCH', 0, vector (aref (del_patterns, dw_pi)), vector (), 0, null), dw_ctx);
          dw_body := DB.DBA.GQL_CTX_GET (dw_ctx, 'triples');
          dw_body := concat (dw_body, DB.DBA.GQL_CTX_GET (dw_ctx, 'binds'));
          dw_body := concat (dw_body, DB.DBA.GQL_CTX_GET (dw_ctx, 'filters'));
          sparql_text := concat (sparql_text, 'DELETE WHERE {\n', DB.DBA.GQL_DML_G_WRAP (graph, dw_body), '}\n');
          goto dml_set_section;
        }

      del_items := aref (_delete_ast, 2);
      del_body := '';
      del_body_out := '';
      del_body_alt := '';
      del_body_edge := '';
      match_text := concat (DB.DBA.GQL_CTX_GET (_ctx, 'pre_values'), DB.DBA.GQL_CTX_GET (_ctx, 'pre_binds'),
        DB.DBA.GQL_CTX_GET (_ctx, 'triples'), DB.DBA.GQL_CTX_GET (_ctx, 'binds'),
        DB.DBA.GQL_CTX_GET (_ctx, 'filters'), DB.DBA.GQL_CTX_GET (_ctx, 'optionals'));
      for (di := 0; di < length (del_items); di := di + 1)
        {
          declare ditem, dt_expr any;
          ditem := aref (del_items, di);
          if (isarray (ditem) and aref (ditem, 0) = 'VAR')
            {
              declare dvar, dn, e_src, e_pred, e_dst varchar;
              declare out_pat varchar;
              dvar := DB.DBA.GQL_NODE_SPARQL_VAR (aref (ditem, 1));
              dn := cast (di as varchar);
              -- An edge variable: the stored edge and its property holder,
              -- DETACH or not.
              e_src := DB.DBA.GQL_CTX_EDGE_END (_ctx, aref (ditem, 1), 1);
              if (e_src is not null)
                {
                  e_dst := DB.DBA.GQL_CTX_EDGE_END (_ctx, aref (ditem, 1), 2);
                  e_pred := DB.DBA.GQL_CTX_EDGE_END (_ctx, aref (ditem, 1), 3);
                  if (e_pred is null or (e_pred not like '<%' and e_pred not like '?%'))
                    signal ('G3013', sprintf ('DELETE %s: deleting an edge of more than one type is not supported', aref (ditem, 1)));
                  del_body := concat (del_body,
                    '  ', e_src, ' ', e_pred, ' ', e_dst, ' .\n',
                    '  ?h', dn, ' ?hp', dn, ' ?ho', dn, ' .\n');
                  del_body_edge := concat (del_body_edge,
                    '  OPTIONAL { ?h', dn, ' rdf:subject ', e_src, ' ; rdf:predicate ', e_pred,
                    ' ; rdf:object ', e_dst, ' .\n',
                    '             ?h', dn, ' ?hp', dn, ' ?ho', dn, ' }\n');
                  goto next_del_item;
                }
              -- Anything else must be a node the MATCH binds: a variable it
              -- does not bind (a list of edges) would match every triple.
              if (not DB.DBA.GQL_TEXT_HAS_VAR (match_text, dvar))
                signal ('G3013', sprintf ('DELETE %s: %s is not a node or a single edge of the MATCH',
                  aref (ditem, 1), aref (ditem, 1)));
              -- Delete all triples where this node appears as subject
              out_pat := concat ('  ', dvar, ' ?p', dn, ' ?o', dn, ' .\n');
              del_body := concat (del_body, out_pat);
              if (aref (_delete_ast, 1) = 1)  -- DETACH
                {
                  -- Also the triples that point at the node, and every
                  -- triple of the resource that holds the properties of an
                  -- edge of the node.  Each kind is its own UNION branch, so
                  -- their rows add rather than multiply, and a node with no
                  -- outgoing triple is deleted too.
                  del_body := concat (del_body,
                    '  ?s', dn, ' ?q', dn, ' ', dvar, ' .\n',
                    '  ?h', dn, ' ?hp', dn, ' ?ho', dn, ' .\n');
                  del_body_alt := concat (del_body_alt,
                    case when del_body_alt = '' then '  ' else '  UNION ' end,
                    '{ ', dvar, ' ?p', dn, ' ?o', dn, ' }\n',
                    '  UNION { ?s', dn, ' ?q', dn, ' ', dvar, ' }\n',
                    '  UNION { { ?h', dn, ' rdf:subject ', dvar, ' } UNION { ?h', dn, ' rdf:object ', dvar, ' }\n',
                    '          ?h', dn, ' ?hp', dn, ' ?ho', dn, ' }\n');
                }
              else
                del_body_out := concat (del_body_out, out_pat);
            }
        next_del_item:;
        }

      where_body := DB.DBA.GQL_CTX_GET (_ctx, 'pre_values');
      where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'pre_binds'));
      where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'triples'));
      where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'binds'));

      -- NODETACH (the default): a node that still has an edge -- one that
      -- is not deleted by the same statement -- is an error, raised before
      -- anything is deleted; a node without edges is deleted with its
      -- labels and properties.  An edge is a triple to or from the node
      -- that is not GQL's storage (labels, properties, the resource holding
      -- an edge's properties), as an untyped edge pattern matches.
      declare del_guard varchar;
      del_guard := '';
      if (aref (_delete_ast, 1) = 0)
        {
          declare guard_di, guard_ei integer;
          declare guard_keep varchar;
          guard_keep := '';
          for (guard_ei := 0; guard_ei < length (del_items); guard_ei := guard_ei + 1)
            {
              declare ge_item any;
              ge_item := aref (del_items, guard_ei);
              if (isarray (ge_item) and aref (ge_item, 0) = 'VAR'
                  and DB.DBA.GQL_CTX_EDGE_END (_ctx, aref (ge_item, 1), 1) is not null)
                guard_keep := concat (guard_keep, ' && !(?gs = ',
                  DB.DBA.GQL_CTX_EDGE_END (_ctx, aref (ge_item, 1), 1), ' && ?gp = ',
                  DB.DBA.GQL_CTX_EDGE_END (_ctx, aref (ge_item, 1), 3), ' && ?go = ',
                  DB.DBA.GQL_CTX_EDGE_END (_ctx, aref (ge_item, 1), 2), ')');
            }
          for (guard_di := 0; guard_di < length (del_items); guard_di := guard_di + 1)
            {
              declare guard_item any;
              declare guard_var varchar;
              guard_item := aref (del_items, guard_di);
              if (isarray (guard_item) and aref (guard_item, 0) = 'VAR'
                  and DB.DBA.GQL_CTX_EDGE_END (_ctx, aref (guard_item, 1), 1) is null)
                {
                  guard_var := DB.DBA.GQL_NODE_SPARQL_VAR (aref (guard_item, 1));
                  del_guard := concat (del_guard,
                    '  FILTER (IF (EXISTS {\n',
                    '      { ', guard_var, ' ?gp ?go . BIND (', guard_var, ' AS ?gs)',
                    ' FILTER (isIRI (?go) && ?gp NOT IN (rdf:type, rdf:subject, rdf:predicate, rdf:object, rdf:reifies)',
                    guard_keep, ') }\n',
                    '      UNION { ?gs ?gp ', guard_var, ' . BIND (', guard_var, ' AS ?go)',
                    ' FILTER (?gp NOT IN (rdf:type, rdf:subject, rdf:predicate, rdf:object, rdf:reifies)',
                    guard_keep, ') } },\n',
                    '    bif:signal (''G4015'', ''DELETE ', aref (guard_item, 1),
                    ': the node still has edges; delete them first, or use DETACH DELETE''), 1))\n');
                }
            }
        }

      where_body := concat (where_body, del_guard);
      where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'filters'));
      where_body := concat (where_body, DB.DBA.GQL_CTX_GET (_ctx, 'optionals'));
      -- Beside an INSERT that mints IRIs, the DETACH union goes in a
      -- sub-select of its own: joined directly with the sub-select that
      -- mints them, the union is distributed over its branches, each of
      -- which makes its own copy of that sub-select and its own IRIs.
      if (ins_fresh and del_body_alt <> '')
        del_body_alt := concat ('  { SELECT * WHERE {\n', del_body_alt, '  } }\n');
      if (combine)
        {
          c_del := concat (c_del, del_body);
          c_guard := del_guard;
          c_exp := concat (c_exp, del_body_out, del_body_alt, del_body_edge);
          goto dml_set_section;
        }
      if (ins_fresh)
        where_body := concat ('  { SELECT DISTINCT * WHERE {\n', where_body, '  } }\n');

      sparql_text := concat (sparql_text, 'DELETE {\n', DB.DBA.GQL_DML_G_WRAP (graph, del_body), '} ');
      if (ins_body is not null)
        {
          sparql_text := concat (sparql_text, 'INSERT {\n', DB.DBA.GQL_DML_G_WRAP_TRIPLES (graph, ins_body), '} ');
          ins_body := null;
        }
      sparql_text := concat (sparql_text, using_s, 'WHERE {\n');
      sparql_text := concat (sparql_text, DB.DBA.GQL_DML_G_OPEN (wgraph));
      sparql_text := concat (sparql_text, where_body);
      -- Add outgoing edge patterns as required in WHERE
      sparql_text := concat (sparql_text, del_body_out);
      -- DETACH: what to delete, one UNION branch per kind of triple
      sparql_text := concat (sparql_text, del_body_alt);
      -- Edges: the property holder of each, where it has one
      sparql_text := concat (sparql_text, del_body_edge);
      sparql_text := concat (sparql_text, DB.DBA.GQL_DML_G_CLOSE (wgraph), '}\n');
      emitted := 1;
    }

  dml_set_section:
  -- SET section (separated by ;\n for multi-statement execution)
  if (_set_ast is not null)
    {
      if (_delete_ast is not null and not combine)
        sparql_text := concat (sparql_text, ';\n');
      declare set_items, si any;
      declare sii integer;
      declare set_ins, set_del varchar;

      set_items := aref (_set_ast, 1);
      set_ins := '';
      set_del := '';

      for (sii := 0; sii < length (set_items); sii := sii + 1)
        {
          si := aref (set_items, sii);
          if (not isarray (si)) goto set_next;
          if (aref (si, 0) = 'SETPROP')
            {
              declare sprop_expr, sprop_val any;
              sprop_expr := aref (si, 1);  -- PROP node
              sprop_val := aref (si, 2);   -- new value
              declare sp_s, sp_p varchar;
              sp_s := DB.DBA.GQL_GEN_EXPR (aref (sprop_expr, 1), _ctx);
              sp_p := DB.DBA.GQL_GEN_PROP_IRI_CTX (aref (sprop_expr, 2), _ctx);
              declare sp_v varchar;
              declare old_var, new_var varchar;
              sp_v := DB.DBA.GQL_GEN_EXPR (sprop_val, _ctx);
              old_var := concat ('?old', cast (sii as varchar));
              new_var := concat ('?new', cast (sii as varchar));
              set_del := concat (set_del, '  ', sp_s, ' ', sp_p, ' ', old_var, ' .\n');
              -- If the value expression contains references to WHERE-bound
              -- variables (e.g. property access), use BIND to compute the new
              -- value in the WHERE clause, then reference the BIND variable
              -- in the INSERT template. SPARQL INSERT templates don't evaluate
              -- arithmetic expressions — they only accept terms.
              if (strstr (sp_v, '?') is not null or not DB.DBA.GQL_SPARQL_IS_TERM (sp_v))
                {
                  set_ins := concat (set_ins, '  ', sp_s, ' ', sp_p, ' ', new_var, ' .\n');
                  declare saved_bind_sp varchar;
                  saved_bind_sp := DB.DBA.GQL_CTX_GET (_ctx, 'binds');
                  DB.DBA.GQL_CTX_SET (_ctx, 'binds',
                    concat (saved_bind_sp, '  BIND (', sp_v, ' AS ', new_var, ')\n'));
                }
              else
                set_ins := concat (set_ins, '  ', sp_s, ' ', sp_p, ' ', sp_v, ' .\n');
              -- Add OPTIONAL { ?s ?p ?old } to WHERE so old value is bound
              -- without making the property mandatory
              declare sprop_opt_body varchar;
              sprop_opt_body := concat ('    ', sp_s, ' ', sp_p, ' ', old_var, ' .\n');
              declare saved_opt_sp varchar;
              saved_opt_sp := DB.DBA.GQL_CTX_GET (_ctx, 'optionals');
              DB.DBA.GQL_CTX_SET (_ctx, 'optionals',
                concat (saved_opt_sp, '  OPTIONAL {\n', sprop_opt_body, '  }\n'));
            }
          else if (aref (si, 0) = 'SETALL')
            {
              declare svar_name varchar;
              declare sval_expr, smap_keys, smap_vals any;
              declare sis_plus integer;
              declare ssvar varchar;
              declare ski integer;
              svar_name := aref (si, 1);
              sval_expr := aref (si, 2);
              sis_plus := aref (si, 3);
              ssvar := DB.DBA.GQL_NODE_SPARQL_VAR (svar_name);
              if (isarray (sval_expr) and aref (sval_expr, 0) = 'MAP')
                {
                  smap_keys := aref (sval_expr, 1);
                  smap_vals := aref (sval_expr, 2);
                  for (ski := 0; ski < length (smap_keys); ski := ski + 1)
                    {
                      declare smk varchar;
                      declare smv_sparql varchar;
                      smk := aref (smap_keys, ski);
                      smv_sparql := DB.DBA.GQL_GEN_EXPR (aref (smap_vals, ski), _ctx);
                      -- An update template holds terms only: bind anything else in WHERE.
                      if (strstr (smv_sparql, '?') is not null or not DB.DBA.GQL_SPARQL_IS_TERM (smv_sparql))
                        {
                          declare smv_var, saved_bind_sm varchar;
                          smv_var := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'setall_v');
                          saved_bind_sm := DB.DBA.GQL_CTX_GET (_ctx, 'binds');
                          DB.DBA.GQL_CTX_SET (_ctx, 'binds',
                            concat (saved_bind_sm, '  BIND (', smv_sparql, ' AS ', smv_var, ')\n'));
                          smv_sparql := smv_var;
                        }
                      set_ins := concat (set_ins, '  ', ssvar, ' ',
                        DB.DBA.GQL_GEN_PROP_IRI_CTX (smk, _ctx), ' ', smv_sparql, ' .\n');
                    }
                  -- DELETE all existing non-rdf:type property triples for this node
                  declare fresh_p varchar;
                  declare fresh_o varchar;
                  fresh_p := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'setall_p');
                  fresh_o := DB.DBA.GQL_CTX_FRESH_VAR (_ctx, 'setall_o');
                  set_del := concat (set_del, '  ', ssvar, ' ', fresh_p, ' ', fresh_o, ' .\n');
                  -- Add OPTIONAL to WHERE that binds the fresh vars
                  declare setall_opt_body varchar;
                  setall_opt_body := concat ('    ', ssvar, ' ', fresh_p, ' ', fresh_o, ' .\n');
                  setall_opt_body := concat (setall_opt_body, '    FILTER (', fresh_p, ' != rdf:type)\n');
                  declare saved_opt varchar;
                  saved_opt := DB.DBA.GQL_CTX_GET (_ctx, 'optionals');
                  DB.DBA.GQL_CTX_SET (_ctx, 'optionals',
                    concat (saved_opt, '  OPTIONAL {\n', setall_opt_body, '  }\n'));
                }
              else
                signal ('G2006', 'SET n = expr currently supports only map literals');
            }
          else if (aref (si, 0) = 'SETLABEL')
            {
              declare slvar, sllabels any;
              declare sli integer;
              slvar := DB.DBA.GQL_NODE_SPARQL_VAR (aref (si, 1));
              sllabels := aref (si, 2);
              for (sli := 0; sli < length (sllabels); sli := sli + 1)
                set_ins := concat (set_ins, '  ', slvar, ' a ', DB.DBA.GQL_GEN_LABEL_IRI_CTX (aref (sllabels, sli), _ctx), ' .\n');
            }
        set_next:;
        }

      if (combine)
        {
          c_del := concat (c_del, set_del);
          c_ins := concat (c_ins, set_ins);
          goto dml_remove_section;
        }
      if (set_ins <> '' or set_del <> '')
        {
          declare swhere_body varchar;
          swhere_body := DB.DBA.GQL_CTX_GET (_ctx, 'pre_values');
          swhere_body := concat (swhere_body, DB.DBA.GQL_CTX_GET (_ctx, 'pre_binds'));
          swhere_body := concat (swhere_body, DB.DBA.GQL_CTX_GET (_ctx, 'triples'));
          swhere_body := concat (swhere_body, DB.DBA.GQL_CTX_GET (_ctx, 'binds'));
          swhere_body := concat (swhere_body, DB.DBA.GQL_CTX_GET (_ctx, 'filters'));
          if (ins_fresh and ins_body is not null)
            swhere_body := concat ('  { SELECT DISTINCT * WHERE {\n', swhere_body, m_opts, '  } }\n',
              subseq (coalesce (DB.DBA.GQL_CTX_GET (_ctx, 'optionals'), ''), length (m_opts)));
          else
            swhere_body := concat (swhere_body, DB.DBA.GQL_CTX_GET (_ctx, 'optionals'));

          if (set_del <> '')
            {
              sparql_text := concat (sparql_text, 'DELETE {\n', DB.DBA.GQL_DML_G_OPEN (graph));
              sparql_text := concat (sparql_text, set_del);
              sparql_text := concat (sparql_text, DB.DBA.GQL_DML_G_CLOSE (graph), '} ');
            }
          sparql_text := concat (sparql_text, 'INSERT {\n', DB.DBA.GQL_DML_G_OPEN (graph));
          sparql_text := concat (sparql_text, set_ins);
          sparql_text := concat (sparql_text, DB.DBA.GQL_DML_G_CLOSE (graph));
          if (ins_body is not null)
            {
              sparql_text := concat (sparql_text, DB.DBA.GQL_DML_G_WRAP_TRIPLES (graph, ins_body));
              ins_body := null;
            }
          sparql_text := concat (sparql_text, '} ', using_s, 'WHERE {\n', DB.DBA.GQL_DML_G_OPEN (wgraph));
          -- When this is a combined DELETE+INSERT MODIFY whose INSERT template
          -- references a computed BIND variable (e.g. SET a.bal = a.bal - 1),
          -- wrap the WHERE body in a SELECT subquery so the computed value is
          -- materialised as a projected binding.  A bare DELETE+INSERT ... WHERE
          -- with a BIND-computed INSERT variable, executed via exec() inside a
          -- stored procedure (the GQL_RUN path), drops that variable — only the
          -- DELETE takes effect and the new value is never written.  Wrapping in
          -- a sub-SELECT makes the value survive.  (INSERT-only SET — e.g. SET
          -- of a label — has no set_del and is unaffected.)
          if (set_del <> '')
            sparql_text := concat (sparql_text, '  { SELECT * WHERE {\n', swhere_body, '  } }\n');
          else
            sparql_text := concat (sparql_text, swhere_body);
          sparql_text := concat (sparql_text, DB.DBA.GQL_DML_G_CLOSE (wgraph), '}\n');
          emitted := 1;
        }
    }

  dml_remove_section:
  -- REMOVE section (separated by ;\n for multi-statement execution)
  if (_remove_ast is not null)
    {
      -- Only insert a statement separator when a DELETE or SET statement was
      -- actually emitted before this one.  sparql_text is never empty here (it
      -- always holds the SPARQL preamble), so testing it directly wrongly split
      -- a standalone REMOVE into a prefix-only statement + a broken second one.
      if ((_delete_ast is not null or _set_ast is not null) and not combine)
        sparql_text := concat (sparql_text, ';\n');
      declare ritems, ri any;
      declare rii integer;
      declare rdel varchar;

      ritems := aref (_remove_ast, 1);
      rdel := '';
      -- Property removals delete a triple whose object is a variable (?rvN).
      -- That variable must be bound in the WHERE clause, or SPARQL instantiates
      -- nothing for it and the delete silently no-ops.  Bind it with an OPTIONAL
      -- (one per removed property, so removing an absent property does not block
      -- removing the others).
      declare rwhere_extra varchar;
      rwhere_extra := '';
      for (rii := 0; rii < length (ritems); rii := rii + 1)
        {
          ri := aref (ritems, rii);
          if (not isarray (ri)) goto rem_next;
          if (aref (ri, 0) = 'RMPROP')
            {
              declare rprop_expr any;
              declare rsubj, rprop, rvv varchar;
              rprop_expr := aref (ri, 1);
              rsubj := DB.DBA.GQL_GEN_EXPR (aref (rprop_expr, 1), _ctx);
              rprop := DB.DBA.GQL_GEN_PROP_IRI_CTX (aref (rprop_expr, 2), _ctx);
              rvv := concat ('?rv', cast (rii as varchar));
              rdel := concat (rdel, '  ', rsubj, ' ', rprop, ' ', rvv, ' .\n');
              rwhere_extra := concat (rwhere_extra, '  OPTIONAL {\n    ', rsubj, ' ', rprop, ' ', rvv, ' .\n  }\n');
            }
          else if (aref (ri, 0) = 'RMLABEL')
            {
              declare rlvar, rllabels any;
              declare rli integer;
              rlvar := DB.DBA.GQL_NODE_SPARQL_VAR (aref (ri, 1));
              rllabels := aref (ri, 2);
              for (rli := 0; rli < length (rllabels); rli := rli + 1)
                rdel := concat (rdel, '  ', rlvar, ' a ', DB.DBA.GQL_GEN_LABEL_IRI_CTX (aref (rllabels, rli), _ctx), ' .\n');
            }
        rem_next:;
        }

      if (combine)
        {
          c_del := concat (c_del, rdel);
          c_exp := concat (c_exp, rwhere_extra);
          goto dml_combined;
        }
      if (rdel <> '')
        {
          declare rwhere_body varchar;
          rwhere_body := DB.DBA.GQL_CTX_GET (_ctx, 'pre_values');
          rwhere_body := concat (rwhere_body, DB.DBA.GQL_CTX_GET (_ctx, 'pre_binds'));
          rwhere_body := concat (rwhere_body, DB.DBA.GQL_CTX_GET (_ctx, 'triples'));
          rwhere_body := concat (rwhere_body, DB.DBA.GQL_CTX_GET (_ctx, 'binds'));
          rwhere_body := concat (rwhere_body, DB.DBA.GQL_CTX_GET (_ctx, 'filters'));
          rwhere_body := concat (rwhere_body, DB.DBA.GQL_CTX_GET (_ctx, 'optionals'));
          if (ins_fresh and ins_body is not null)
            rwhere_body := concat ('  { SELECT DISTINCT * WHERE {\n', rwhere_body, '  } }\n');
          rwhere_body := concat (rwhere_body, rwhere_extra);

          sparql_text := concat (sparql_text, 'DELETE {\n', DB.DBA.GQL_DML_G_WRAP (graph, rdel), '} ');
          if (ins_body is not null)
            {
              sparql_text := concat (sparql_text, 'INSERT {\n', DB.DBA.GQL_DML_G_WRAP_TRIPLES (graph, ins_body), '} ');
              ins_body := null;
            }
          sparql_text := concat (sparql_text, using_s, 'WHERE {\n', DB.DBA.GQL_DML_G_OPEN (wgraph));
          sparql_text := concat (sparql_text, rwhere_body);
          sparql_text := concat (sparql_text, DB.DBA.GQL_DML_G_CLOSE (wgraph), '}\n');
          emitted := 1;
        }
    }

  dml_combined:
  -- The rows of the MATCH, with the values SET computes and the NODETACH
  -- guard, made once in a subquery; what the update deletes is bound by
  -- patterns joined to them (SET's OPTIONALs, the old values, among them).
  if (combine)
    {
      declare c_rows, c_tmpl varchar;
      c_rows := concat (DB.DBA.GQL_CTX_GET (_ctx, 'pre_values'), DB.DBA.GQL_CTX_GET (_ctx, 'pre_binds'),
        DB.DBA.GQL_CTX_GET (_ctx, 'triples'), DB.DBA.GQL_CTX_GET (_ctx, 'binds'), c_guard,
        DB.DBA.GQL_CTX_GET (_ctx, 'filters'), m_opts);
      c_rows := concat ('  { SELECT ', case when ins_fresh then 'DISTINCT ' else '' end, '* WHERE {\n', c_rows, '  } }\n');
      c_tmpl := concat (c_ins, coalesce (ins_body, ''));
      if (c_del <> '' or c_tmpl <> '')
        {
          if (c_del <> '')
            sparql_text := concat (sparql_text, 'DELETE {\n', DB.DBA.GQL_DML_G_WRAP (graph, c_del), '} ');
          if (c_tmpl <> '')
            sparql_text := concat (sparql_text, 'INSERT {\n', DB.DBA.GQL_DML_G_WRAP_TRIPLES (graph, c_tmpl), '} ');
          sparql_text := concat (sparql_text, using_s, 'WHERE {\n', DB.DBA.GQL_DML_G_OPEN (wgraph), c_rows, c_exp,
            subseq (coalesce (DB.DBA.GQL_CTX_GET (_ctx, 'optionals'), ''), length (m_opts)),
            DB.DBA.GQL_DML_G_CLOSE (wgraph), '}\n');
          emitted := 1;
          ins_body := null;
        }
    }

  -- An INSERT no update above took (SET and REMOVE that change nothing):
  -- on its own, never dropped.
  if (ins_body is not null)
    {
      declare iwhere_body varchar;
      iwhere_body := concat (DB.DBA.GQL_CTX_GET (_ctx, 'pre_values'), DB.DBA.GQL_CTX_GET (_ctx, 'pre_binds'),
        DB.DBA.GQL_CTX_GET (_ctx, 'triples'), DB.DBA.GQL_CTX_GET (_ctx, 'filters'),
        DB.DBA.GQL_CTX_GET (_ctx, 'binds'));
      if (emitted)
        sparql_text := concat (sparql_text, ';\n');
      sparql_text := concat (sparql_text, 'INSERT {\n', DB.DBA.GQL_DML_G_WRAP_TRIPLES (graph, ins_body),
        '} ', using_s, 'WHERE {\n', DB.DBA.GQL_DML_G_OPEN (wgraph), iwhere_body, DB.DBA.GQL_DML_G_CLOSE (wgraph), '}\n');
    }

  return sparql_text;
}
;

----------------------------------------------------------------------
-- Standalone INSERT DATA (no MATCH)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_GEN_INSERT_DATA (in _insert_asts any, in _graph varchar)
{
  -- Similar to GQL_GEN_INSERT_WHERE but emits INSERT DATA { ... }
  -- For now, delegates to INSERT WHERE with empty match
  declare ctx any;
  ctx := DB.DBA.GQL_CTX_NEW (_graph);
  return DB.DBA.GQL_GEN_INSERT_WHERE (_insert_asts, vector (), ctx);
}
;

----------------------------------------------------------------------
-- Part 3: Catalog DDL Generation
----------------------------------------------------------------------

-- While 'gql_pg_ddl_deferred' is a vector (the SPARQL endpoint sets it) the action is only recorded.
create procedure DB.DBA.GQL_PG_DDL_DO (in _op varchar, in _pg_name varchar,
  in _node_tables any := null, in _rel_tables any := null)
{
  declare _deferred any;
  _deferred := connection_get ('gql_pg_ddl_deferred');
  if (isvector (_deferred))
    {
      connection_set ('gql_pg_ddl_deferred',
        vector_concat (_deferred, vector (vector (_op, _pg_name, _node_tables, _rel_tables))));
      return;
    }
  if (_op = 'CREATE VIRTUAL')
    DB.DBA.GQL_PG_CREATE_VIRTUAL (_pg_name, _node_tables, _rel_tables);
  else if (_op = 'CREATE PHYSICAL')
    DB.DBA.GQL_PG_CREATE_PHYSICAL (_pg_name, _node_tables, _rel_tables);
  else if (_op = 'DROP')
    DB.DBA.GQL_PG_DROP (_pg_name, 1);
  else
    signal ('22023', sprintf ('Unknown property graph DDL action %s', _op));
}
;

create procedure DB.DBA.GQL_GEN_CATALOG (in _catalog_asts any, inout _ctx any)
{
  declare sparql_text varchar;
  declare i integer;

  sparql_text := '';

  for (i := 0; i < length (_catalog_asts); i := i + 1)
    {
      declare clause, ctype any;
      declare graph_ref, graph_uri varchar;
      clause := aref (_catalog_asts, i);
      if (not isarray (clause)) goto cat_next;
      ctype := aref (clause, 0);

      if (ctype = 'CREATE_GRAPH')
        {
          declare copy_of, like_graph, graph_type_ref any;
          declare is_property integer;
          declare pg_name varchar;
          graph_ref := aref (clause, 1);
          graph_type_ref := aref (clause, 2);
          copy_of := aref (clause, 3);
          like_graph := aref (clause, 4);
          is_property := 0;
          if (length (clause) > 5)
            is_property := aref (clause, 5);
          if (graph_type_ref is not null)
            signal ('G4002', 'Typed graph initializer { ... } is not yet supported in CREATE GRAPH');
          if (like_graph is not null)
            signal ('G4003', 'CREATE GRAPH LIKE is not yet supported -- use AS COPY OF instead');
          -- For CREATE PROPERTY GRAPH with a bare name, derive the graph IRI
          -- and per-graph namespaces from the name.
          if (is_property and isarray (graph_ref)
              and length (graph_ref) > 2 and aref (graph_ref, 2) = 'BARE')
            {
              pg_name := cast (aref (graph_ref, 1) as varchar);
              graph_uri := DB.DBA.GQL_PG_GRAPH_IRI (pg_name);
            }
          else
            graph_uri := DB.DBA.GQL_GRAPH_REF_VALUE_CTX (graph_ref, _ctx);
          if (sparql_text <> '') sparql_text := concat (sparql_text, ';\n');
          sparql_text := concat (sparql_text, 'SPARQL CREATE GRAPH <', graph_uri, '>\n');
          -- CREATE PROPERTY GRAPH: insert catalog metadata recording the
          -- per-graph ontology and data namespace scheme.
          if (is_property and pg_name is not null)
            {
              sparql_text := concat (sparql_text, ';\nSPARQL INSERT DATA { GRAPH <',
                graph_uri, '> { <', graph_uri, '> a <urn:gql:PropertyGraph> ; ',
                '<urn:gql:ontologyNS> "', DB.DBA.GQL_PG_ONTOLOGY_NS (pg_name), '" ; ',
                '<urn:gql:dataNS> "', DB.DBA.GQL_PG_DATA_NS (pg_name), '" . } }\n');
            }
          -- AS COPY OF: copy triples from source graph
          if (copy_of is not null)
            {
              declare src_uri varchar;
              src_uri := DB.DBA.GQL_GRAPH_REF_VALUE_CTX (copy_of, _ctx);
              sparql_text := concat (sparql_text, ';\nSPARQL INSERT { GRAPH <', graph_uri, '> { ?s ?p ?o } } WHERE { GRAPH <', src_uri, '> { ?s ?p ?o } }\n');
            }
        }
      else if (ctype = 'CREATE_PROPERTY_GRAPH_V2')
        {
          -- CREATE [VIRTUAL|PHYSICAL] PROPERTY GRAPH
          -- Executed via DB.DBA.GQL_PG_CREATE_VIRTUAL or GQL_PG_CREATE_PHYSICAL
          declare v2_pg_name varchar;
          declare v2_pg_mode integer;
          declare v2_node_tables, v2_rel_tables any;
          v2_pg_name := aref (clause, 1);
          v2_pg_mode := aref (clause, 2);  -- 545=virtual, 546=physical
          v2_node_tables := aref (clause, 3);
          v2_rel_tables := aref (clause, 4);
          if (__proc_exists ('DB.DBA.GQL_PG_CREATE_VIRTUAL') is not null)
            {
              -- The DDL is executed here, as a side effect of translation
              -- (it calls PL procedures, not SPARQL text).  It therefore
              -- contributes NOTHING to sparql_text: the callers (GQL_RUN,
              -- GQL_EXECUTE, GQL_TO_SPARQL) must not try to re-execute a
              -- generated statement.  Emitting leftover text here caused a
              -- spurious SQL syntax error (SQ074) when run over the SQL/
              -- GQL-prefix path even though the graph was created.
              if (v2_pg_mode = 545)  -- VIRTUAL
                DB.DBA.GQL_PG_DDL_DO ('CREATE VIRTUAL', v2_pg_name, v2_node_tables, v2_rel_tables);
              else  -- PHYSICAL (546)
                DB.DBA.GQL_PG_DDL_DO ('CREATE PHYSICAL', v2_pg_name, v2_node_tables, v2_rel_tables);
            }
          else
            signal ('GQ212', 'CREATE VIRTUAL/PHYSICAL PROPERTY GRAPH requires the gql_pg_ddl.sql module to be loaded');
        }
      else if (ctype = 'DROP_GRAPH')
        {
          declare if_exists integer;
          graph_ref := aref (clause, 1);
          if_exists := aref (clause, 2);
          graph_uri := DB.DBA.GQL_GRAPH_REF_VALUE_CTX (graph_ref, _ctx);
          if (sparql_text <> '') sparql_text := concat (sparql_text, ';\n');
          if (if_exists)
            sparql_text := concat (sparql_text, 'SPARQL DROP SILENT GRAPH <', graph_uri, '>\n');
          else
            sparql_text := concat (sparql_text, 'SPARQL DROP GRAPH <', graph_uri, '>\n');
        }
      else if (ctype = 'DROP_PROPERTY_GRAPH')
        {
          declare if_exists integer;
          declare drop_pg_name, drop_mode varchar;
          graph_ref := aref (clause, 1);
          if_exists := aref (clause, 2);
          -- Optional VIRTUAL/PHYSICAL keyword asserts the target's mode.
          drop_mode := null;
          if (length (clause) > 3)
            drop_mode := aref (clause, 3);
          -- For a bare name, derive the property-graph IRI
          if (isarray (graph_ref) and length (graph_ref) > 2 and aref (graph_ref, 2) = 'BARE')
            {
              drop_pg_name := cast (aref (graph_ref, 1) as varchar);
              -- Use the new GQL_PG_DROP function which handles both
              -- virtual (quad map) and physical (named graph) PGs.  It is
              -- executed here (a PL call, not SPARQL text) and contributes
              -- NOTHING to sparql_text — see CREATE_PROPERTY_GRAPH_V2 above.
              -- DROP PROPERTY GRAPH is idempotent (silent when the graph
              -- is not defined), so pass if_exists=1 regardless of the
              -- IF EXISTS clause.
              if (__proc_exists ('DB.DBA.GQL_PG_DROP') is not null)
                {
                  -- Mode assertion: DROP VIRTUAL/PHYSICAL must match the
                  -- recorded mode of the target graph.
                  if (drop_mode is not null)
                    {
                      declare _dmeta any;
                      _dmeta := DB.DBA.GQL_PG_DEF_GET (drop_pg_name);
                      if (_dmeta is null)
                        {
                          if (not if_exists)
                            signal ('GQ206', sprintf ('Property graph %s does not exist', drop_pg_name));
                        }
                      else if (aref (_dmeta, 0) <> drop_mode)
                        signal ('GQ214', sprintf (
                          'Property graph %s is %s, not %s; use DROP %s PROPERTY GRAPH (or DROP PROPERTY GRAPH)',
                          drop_pg_name, aref (_dmeta, 0), drop_mode, upper (aref (_dmeta, 0))));
                    }
                  DB.DBA.GQL_PG_DDL_DO ('DROP', drop_pg_name);
                }
              else
                {
                  graph_uri := DB.DBA.GQL_PG_GRAPH_IRI (drop_pg_name);
                  if (sparql_text <> '') sparql_text := concat (sparql_text, ';\n');
                  if (if_exists)
                    sparql_text := concat (sparql_text, 'SPARQL DROP SILENT GRAPH <', graph_uri, '>\n');
                  else
                    sparql_text := concat (sparql_text, 'SPARQL DROP GRAPH <', graph_uri, '>\n');
                }
            }
          else
            {
              graph_uri := DB.DBA.GQL_GRAPH_REF_VALUE_CTX (graph_ref, _ctx);
              if (sparql_text <> '') sparql_text := concat (sparql_text, ';\n');
              if (if_exists)
                sparql_text := concat (sparql_text, 'SPARQL DROP SILENT GRAPH <', graph_uri, '>\n');
              else
                sparql_text := concat (sparql_text, 'SPARQL DROP GRAPH <', graph_uri, '>\n');
            }
        }
      else if (ctype = 'CREATE_SCHEMA')
        {
          declare schema_ref, schema_name varchar;
          declare if_not_exists, or_replace integer;
          schema_ref := aref (clause, 1);
          if_not_exists := aref (clause, 2);
          or_replace := aref (clause, 3);
          if (or_replace)
            signal ('G4004', 'CREATE OR REPLACE SCHEMA is not yet supported');
          schema_name := DB.DBA.GQL_GRAPH_REF_VALUE_CTX (schema_ref, _ctx);
          if (sparql_text <> '') sparql_text := concat (sparql_text, ';\n');
          if (if_not_exists)
            sparql_text := concat (sparql_text, 'SPARQL INSERT { GRAPH <', DB.DBA.GQL_CTX_GET (_ctx, 'graph'), '> { <urn:gql:schema:', schema_name, '> a <urn:gql:Schema> } } WHERE { FILTER NOT EXISTS { GRAPH <', DB.DBA.GQL_CTX_GET (_ctx, 'graph'), '> { <urn:gql:schema:', schema_name, '> a <urn:gql:Schema> } } }\n');
          else
            sparql_text := concat (sparql_text, 'SPARQL INSERT DATA { GRAPH <', DB.DBA.GQL_CTX_GET (_ctx, 'graph'), '> { <urn:gql:schema:', schema_name, '> a <urn:gql:Schema> } }\n');
        }
      else if (ctype = 'DROP_SCHEMA')
        {
          declare ds_ref, ds_name varchar;
          declare ds_if_exists integer;
          ds_ref := aref (clause, 1);
          ds_if_exists := aref (clause, 2);
          ds_name := DB.DBA.GQL_GRAPH_REF_VALUE_CTX (ds_ref, _ctx);
          if (sparql_text <> '') sparql_text := concat (sparql_text, ';\n');
          if (ds_if_exists)
            sparql_text := concat (sparql_text, 'SPARQL DELETE { GRAPH <', DB.DBA.GQL_CTX_GET (_ctx, 'graph'), '> { <urn:gql:schema:', ds_name, '> ?p ?o } } WHERE { GRAPH <', DB.DBA.GQL_CTX_GET (_ctx, 'graph'), '> { <urn:gql:schema:', ds_name, '> ?p ?o } }\n');
          else
            sparql_text := concat (sparql_text, 'SPARQL DELETE { GRAPH <', DB.DBA.GQL_CTX_GET (_ctx, 'graph'), '> { <urn:gql:schema:', ds_name, '> ?p ?o } } WHERE { GRAPH <', DB.DBA.GQL_CTX_GET (_ctx, 'graph'), '> { <urn:gql:schema:', ds_name, '> ?p ?o } }\n');
        }
      else if (ctype = 'CREATE_GRAPH_TYPE')
        {
          declare type_ref, type_name varchar;
          type_ref := aref (clause, 1);
          type_name := DB.DBA.GQL_GRAPH_REF_VALUE_CTX (type_ref, _ctx);
          if (sparql_text <> '') sparql_text := concat (sparql_text, ';\n');
          sparql_text := concat (sparql_text, 'SPARQL INSERT DATA { GRAPH <', DB.DBA.GQL_CTX_GET (_ctx, 'graph'), '> { <urn:gql:graph-type:', type_name, '> a <urn:gql:GraphType> } }\n');
        }
      else if (ctype = 'LOAD')
        {
          declare load_iri, load_graph varchar;
          load_iri := DB.DBA.GQL_GEN_EXPR (aref (clause, 1), _ctx);
          if (length (clause) > 2 and aref (clause, 2) is not null)
            load_graph := DB.DBA.GQL_GRAPH_REF_VALUE_CTX (aref (clause, 2), _ctx);
          else
            load_graph := DB.DBA.GQL_CTX_GET (_ctx, 'graph');
          if (sparql_text <> '') sparql_text := concat (sparql_text, ';\n');
          sparql_text := concat (sparql_text, 'SPARQL LOAD ', load_iri, ' INTO GRAPH <', load_graph, '>\n');
        }
      else if (ctype = 'CLEAR')
        {
          declare clear_graph varchar;
          clear_graph := DB.DBA.GQL_GRAPH_REF_VALUE_CTX (aref (clause, 1), _ctx);
          if (sparql_text <> '') sparql_text := concat (sparql_text, ';\n');
          sparql_text := concat (sparql_text, 'SPARQL CLEAR GRAPH <', clear_graph, '>\n');
        }
      else if (ctype = 'DROP_GRAPH_TYPE')
        {
          declare dt_ref, dt_name varchar;
          declare dt_if_exists integer;
          dt_ref := aref (clause, 1);
          dt_if_exists := aref (clause, 2);
          dt_name := DB.DBA.GQL_GRAPH_REF_VALUE_CTX (dt_ref, _ctx);
          if (sparql_text <> '') sparql_text := concat (sparql_text, ';\n');
          sparql_text := concat (sparql_text, 'SPARQL DELETE { GRAPH <', DB.DBA.GQL_CTX_GET (_ctx, 'graph'), '> { <urn:gql:graph-type:', dt_name, '> ?p ?o } } WHERE { GRAPH <', DB.DBA.GQL_CTX_GET (_ctx, 'graph'), '> { <urn:gql:graph-type:', dt_name, '> ?p ?o } }\n');
        }

    cat_next:;
    }

  return sparql_text;
}
;

----------------------------------------------------------------------
-- Part 4: CALL Procedure Generation
----------------------------------------------------------------------

create procedure DB.DBA.GQL_GEN_CALL (in _call_asts any, inout _ctx any)
{
  declare sparql_text varchar;
  declare i integer;

  sparql_text := '';

  for (i := 0; i < length (_call_asts); i := i + 1)
    {
      declare clause, ctype any;
      clause := aref (_call_asts, i);
      if (not isarray (clause)) goto call_next;
      ctype := aref (clause, 0);

      if (ctype = 'CALL_INLINE')
        {
          declare subquery, yield_vars any;
          declare sub_sparql varchar;
          subquery := aref (clause, 1);
          yield_vars := aref (clause, 2);
          sub_sparql := DB.DBA.GQL_TO_SPARQL_IMPL (subquery, DB.DBA.GQL_CTX_GET (_ctx, 'graph'));

          -- Strip 'SPARQL ' prefix from sub-query before nesting inside { { } }
          declare prefix_len, sel_pos integer;
          declare sub_prologue varchar;
          prefix_len := length ('SPARQL ');
          if (length (sub_sparql) >= prefix_len
              and subseq (sub_sparql, 0, prefix_len) = 'SPARQL ')
            sub_sparql := subseq (sub_sparql, prefix_len);
          -- The sub-query's prologue (DEFINE, BASE, PREFIX) goes to the top:
          -- it cannot stand inside a group pattern.
          sub_prologue := '';
          if (sub_sparql not like 'SELECT %')
            {
              sel_pos := strstr (sub_sparql, '\nSELECT ');
              if (sel_pos is null)
                signal ('G5001', 'CALL { ... } needs a query that returns rows');
              sub_prologue := subseq (sub_sparql, 0, sel_pos + 1);
              sub_sparql := subseq (sub_sparql, sel_pos + 1);
            }

          declare proj varchar;
          declare yi integer;
          proj := '';
          if (length (yield_vars) > 0)
            {
              for (yi := 0; yi < length (yield_vars); yi := yi + 1)
                {
                  if (proj <> '') proj := concat (proj, ' ');
                  proj := concat (proj, '?', aref (yield_vars, yi));
                }
            }
          else
            proj := '*';

          if (sparql_text <> '') sparql_text := concat (sparql_text, ';\n');
          sparql_text := concat (sparql_text, 'SPARQL ', sub_prologue, 'SELECT ', proj, ' WHERE { { ',
            sub_sparql, ' } }\n');

          for (yi := 0; yi < length (yield_vars); yi := yi + 1)
            {
              DB.DBA.GQL_CTX_ADD_VAR (_ctx, aref (yield_vars, yi));
              DB.DBA.GQL_CTX_ADD_ALIAS (_ctx, aref (yield_vars, yi),
                concat ('?', aref (yield_vars, yi)));
            }
        }
      else if (ctype = 'CALL')
        {
          declare proc_ref, args, yield_vars any;
          declare proc_name, arg_str varchar;
          declare ai2 integer;
          proc_ref := aref (clause, 1);
          args := aref (clause, 2);
          yield_vars := aref (clause, 3);
          proc_name := DB.DBA.GQL_GRAPH_REF_VALUE_CTX (proc_ref, _ctx);
          -- SPARQL calls a procedure of DB.DBA by its bare name (sql:NAME)
          -- and refuses any other qualified name.
          proc_name := replace (proc_name, ':', '.');
          if (upper (proc_name) like 'DB.DBA.%')
            proc_name := subseq (proc_name, 7);
          if (strchr (proc_name, '.') is not null)
            signal ('G5002', sprintf ('CALL %s: only a procedure of DB.DBA can be called from GQL', proc_name));

          -- Serialize procedure arguments
          arg_str := '';
          for (ai2 := 0; ai2 < length (args); ai2 := ai2 + 1)
            {
              if (arg_str <> '') arg_str := concat (arg_str, ', ');
              arg_str := concat (arg_str, DB.DBA.GQL_GEN_EXPR (aref (args, ai2), _ctx));
            }

          declare yi2 integer;
          declare nproj varchar;
          nproj := '';
          if (length (yield_vars) > 0)
            {
              for (yi2 := 0; yi2 < length (yield_vars); yi2 := yi2 + 1)
                {
                  if (nproj <> '') nproj := concat (nproj, ' ');
                  nproj := concat (nproj, '?', aref (yield_vars, yi2));
                }
            }
          else
            nproj := '*';

          -- One row, the value the procedure returns, under the YIELD name.
          if (length (yield_vars) > 1)
            signal ('G5002', sprintf ('CALL %s returns one value: YIELD one name', proc_name));
          if (sparql_text <> '') sparql_text := concat (sparql_text, ';\n');
          sparql_text := concat (sparql_text, 'SPARQL SELECT (sql:', proc_name, '(', arg_str, ') AS ?',
            case when length (yield_vars) > 0 then aref (yield_vars, 0) else 'result' end, ') WHERE { }\n');

          for (yi2 := 0; yi2 < length (yield_vars); yi2 := yi2 + 1)
            {
              DB.DBA.GQL_CTX_ADD_VAR (_ctx, aref (yield_vars, yi2));
              DB.DBA.GQL_CTX_ADD_ALIAS (_ctx, aref (yield_vars, yi2),
                concat ('?', aref (yield_vars, yi2)));
            }
        }

    call_next:;
    }

  return sparql_text;
}
;

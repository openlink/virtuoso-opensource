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
--  GQL for Virtuoso - Main Entry Points
--
--  Copyright (C) 1998-2026 OpenLink Software
--
--  Primary interface:
--    DB.DBA.GQL_RUN(query, graph?)
--    DB.DBA.GQL_PARAMS(query, graph?, params?)
--    DB.DBA.GQL_TO_SPARQL(query, graph?)        -- translation only
--    DB.DBA.GQL_TO_SPARQL_PARAMS(query, graph?, params?)
--

----------------------------------------------------------------------
-- Check if query contains INSERT (used by endpoint for procedural dispatch)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_QUERY_HAS_INSERT (in _query varchar)
{
  declare tokens, ast, clauses any;
  declare i integer;

  tokens := DB.DBA.GQL_TOKENIZE (_query);
  ast := DB.DBA.GQL_PARSE (tokens);

  -- Navigate to QUERY
  if (aref (ast, 0) = 'PROG' and aref (ast, 1) is not null and isarray (aref (ast, 1))
      and aref (aref (ast, 1), 0) = 'PROC')
    ast := aref (aref (ast, 1), 3);
  if (ast is null or not isarray (ast) or aref (ast, 0) <> 'QUERY')
    return 0;

  clauses := aref (ast, 1);
  for (i := 0; i < length (clauses); i := i + 1)
    {
      if (isarray (aref (clauses, i)) and aref (aref (clauses, i), 0) = 'INSERT')
        return 1;
    }
  return 0;
}
;

----------------------------------------------------------------------
-- Normalize parameters to name/value pairs
----------------------------------------------------------------------

create procedure DB.DBA.GQL_NORMALIZE_PARAMS (in _params any)
{
  declare out_vec any;
  declare i integer;

  if (_params is null)
    return vector ();
  if (not isarray (_params))
    return vector ();
  out_vec := vector ();
  for (i := 0; i < length (_params); i := i + 1)
    {
      declare p any;
      p := aref (_params, i);
      if (isarray (p) and length (p) >= 2)
        out_vec := vector_concat (out_vec, vector (p));
    }
  return out_vec;
}
;

----------------------------------------------------------------------
-- Execute SPARQL and return results
----------------------------------------------------------------------

----------------------------------------------------------------------
-- 1 when every top-level clause of a parsed QUERY only reads.  Such a
-- statement's translation is a pure function of its text and graph, with
-- no side effect, so its SPARQL may be cached and its compiled plan reused.
-- This is a whitelist: a clause kind not listed here (a write, DDL, CALL,
-- LOAD, session change, set operation, or anything added later) counts as
-- not read-only, which only costs the caching.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_AST_IS_READ (inout _query_ast any)
{
  declare _clauses any;
  declare _i, _n integer;
  -- A set operation reads when both of its sides read.
  if (isarray (_query_ast) and length (_query_ast) > 3 and aref (_query_ast, 0) = 'SETOP')
    {
      declare _side any;
      _side := aref (_query_ast, 2);
      if (not DB.DBA.GQL_AST_IS_READ (_side))
        return 0;
      _side := aref (_query_ast, 3);
      return DB.DBA.GQL_AST_IS_READ (_side);
    }
  if (_query_ast is null or not isarray (_query_ast) or length (_query_ast) < 2
      or aref (_query_ast, 0) <> 'QUERY')
    return 0;
  _clauses := aref (_query_ast, 1);
  if (not isarray (_clauses))
    return 0;
  _n := length (_clauses);
  for (_i := 0; _i < _n; _i := _i + 1)
    {
      if (not isarray (aref (_clauses, _i)) or isstring (aref (_clauses, _i)))
        return 0;
      if (not (aref (_clauses, _i, 0) in ('MATCH', 'RETURN', 'FILTER', 'WHERE',
            'ORDER', 'LIMIT', 'SKIP', 'LET', 'FOR', 'UNNEST', 'GROUP', 'GROUP_SETS',
            'GROUP_ROLLUP', 'GROUP_CUBE', 'HAVING', 'ASK', 'CONSTRUCT', 'DESCRIBE',
            'MINUS', 'FROM_CLAUSE', 'DEFINE', 'PREFIX', 'BASE', 'USE', 'USE_PROPERTY',
            'USE_HOME_GRAPH', 'USE_ANY_GRAPH', 'FINISH', 'FORCE_CAMELCASE', 'SERVICE')))
        return 0;
    }
  return 1;
}
;

create procedure DB.DBA.GQL_EXEC_SPARQL (in _sparql varchar)
{
  declare state, msg varchar;
  declare meta, data any;

  state := '00000';
  msg := '';
  -- A read reuses its compiled plan (use_cache: the shared plan cache the
  -- /sparql endpoint uses; a bare 0 here is a row limit).  An INSERT or
  -- DELETE text carries its literals, is rarely repeated, and would only
  -- push read plans out of the cache, so it is compiled as before.
  if (strstr (_sparql, 'INSERT') is null and strstr (_sparql, 'DELETE') is null)
    exec (_sparql, state, msg, vector (), vector ('use_cache', 1), meta, data);
  else
    exec (_sparql, state, msg, vector (), 0, meta, data);
  if (state <> '00000')
    signal (state, msg);
  return data;
}
;

----------------------------------------------------------------------
-- Split a generated SPARQL string into its top-level statements.
--
-- The translator separates distinct SPARQL update statements with ';\n'
-- (a semicolon immediately followed by a newline). Triples *within* a
-- single statement are separated by ' .\n', and the literal formatter
-- (DB.DBA.GQL_GEN_LITERAL) escapes newlines inside string literals to the
-- two characters '\' 'n'. A raw ';' + newline therefore only appears at a
-- true statement boundary, which makes splitting on that sequence safe.
-- Empty fragments (e.g. a trailing separator) are dropped.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_SPLIT_SPARQL_STATEMENTS (in _sparql_str varchar)
{
  declare statements any;
  declare i, pos, slen integer;
  declare frag varchar;

  statements := vector ();
  if (_sparql_str is null)
    return statements;
  slen := length (_sparql_str);
  pos := 0;
  for (i := 0; i < slen; i := i + 1)
    {
      if (aref (_sparql_str, i) = 59  -- ';'
          and i + 1 < slen and aref (_sparql_str, i + 1) = 10)  -- '\n'
        {
          frag := trim (subseq (_sparql_str, pos, i));
          if (length (frag) > 0)
            statements := vector_concat (statements, vector (frag));
          pos := i + 2;  -- skip both ';' and '\n'
        }
    }
  if (pos < slen)
    {
      frag := trim (subseq (_sparql_str, pos, slen));
      if (length (frag) > 0)
        statements := vector_concat (statements, vector (frag));
    }
  -- The translator writes the SPARQL keyword and the PREFIX lines once,
  -- before the first statement; each statement is executed on its own, so
  -- the later ones get the same preamble.
  if (length (statements) > 1)
    {
      declare pre varchar;
      pre := DB.DBA.GQL_SPARQL_PREAMBLE (aref (statements, 0));
      for (i := 1; i < length (statements); i := i + 1)
        if (upper (subseq (aref (statements, i), 0, 6)) <> 'SPARQL')
          aset (statements, i, concat (pre, aref (statements, i)));
    }
  return statements;
}
;

-- The "SPARQL" keyword and the PREFIX, DEFINE and BASE lines that open a
-- translated statement.
create procedure DB.DBA.GQL_SPARQL_PREAMBLE (in _s varchar)
{
  declare pos, n, eol integer;
  declare line varchar;
  n := length (_s);
  if (n < 6 or upper (subseq (_s, 0, 6)) <> 'SPARQL')
    return '';
  pos := 0;
  while (pos < n)
    {
      eol := pos;
      while (eol < n and aref (_s, eol) <> 10)
        eol := eol + 1;
      line := upper (trim (subseq (_s, pos, eol)));
      if (pos = 0)
        line := trim (subseq (line, 6));
      if (not (line like 'PREFIX %' or line like 'DEFINE %' or line like 'BASE %' or line = ''))
        {
          if (pos = 0)
            return 'SPARQL ';
          return subseq (_s, 0, pos);
        }
      pos := eol + 1;
    }
  return 'SPARQL ';
}
;

create procedure DB.DBA.GQL_EXEC_MULTI_SPARQL (in _sparql_str varchar)
{
  declare statements any;
  declare i integer;
  declare state, msg varchar;
  declare meta, data any;

  statements := DB.DBA.GQL_SPLIT_SPARQL_STATEMENTS (_sparql_str);
  for (i := 0; i < length (statements); i := i + 1)
    {
      state := '00000';
      msg := '';
      exec (aref (statements, i), state, msg, vector (), 0, meta, data);
      if (state <> '00000')
        signal (state, msg);
    }
  return data;
}
;

----------------------------------------------------------------------
-- Atomic DML execution: executes a multi-statement DML group as an
-- all-or-nothing unit.
--
-- Transaction model: GQL DML participates in the caller's transaction
-- and does NOT auto-commit (see binsrc/tests/suite/test_gql_rdf_acid.sql
-- AC6, where an outer ROLLBACK WORK undoes a GQL INSERT). Therefore, when
-- any statement in a multi-statement group fails, we ROLL BACK the whole
-- group and re-signal, so no partial write survives. We deliberately do
-- NOT COMMIT on success: commit/rollback stays with the caller's
-- transaction (the /sparql endpoint auto-commits at end-of-request as
-- usual, and callers managing their own transaction keep control). An
-- internal COMMIT here would defeat outer-rollback semantics.
--
-- Single-statement groups take the fast path with no added overhead.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_EXEC_DML_ATOMIC (in _sparql_str varchar)
{
  declare statements any;
  declare i integer;
  declare state, msg varchar;
  declare meta, data any;

  statements := DB.DBA.GQL_SPLIT_SPARQL_STATEMENTS (_sparql_str);

  if (length (statements) <= 1)
    {
      -- Single statement: execute directly without transaction overhead.
      -- Virtuoso already runs one SPARQL update atomically.
      return DB.DBA.GQL_EXEC_MULTI_SPARQL (_sparql_str);
    }

  -- Multi-statement group: roll back everything on the first failure.
  -- The handler also catches errors raised (rather than returned in
  -- `state`) by exec(), guaranteeing the rollback fires either way.
  declare exit handler for sqlstate '*'
    {
      rollback work;
      signal (__SQL_STATE, __SQL_MESSAGE);
    };

  for (i := 0; i < length (statements); i := i + 1)
    {
      state := '00000';
      msg := '';
      exec (aref (statements, i), state, msg, vector (), 0, meta, data);
      if (state <> '00000')
        signal ('G4001',
          sprintf ('GQL DML statement %d of %d failed [%s]: %s',
            i + 1, length (statements), state, msg));
    }

  return data;
}
;

----------------------------------------------------------------------
-- GQL -> SPARQL translation cache.
--
-- Translating a statement (lex, parse, emit) costs far more than running a
-- typical point lookup, and a read's translation is a pure function of its
-- text, its graph and the URIQA host.  A connection keeps translations in a
-- private dictionary in front of a process-wide cache (the
-- __gql_shape_cache_* BIFs, which only DBA-owned code may call).
--
--  * Only reads are cached (GQL_AST_IS_READ).  A write's translation mints
--    node IRIs and must be made fresh each time; DDL runs while translating.
--  * Keys are length-prefixed: no two (kind, text, graph, host) share one.
--  * A change to the property-graph catalog flushes the shared cache and
--    advances its generation (triggers on GQL_PROPERTY_GRAPH_DEF).  A
--    connection drops its private cache when it sees a new generation, and
--    a translation that began before a flush is not published after it.
--  * The translator also reads connection variables any user can set; they
--    are cleared before a translation that may be published
--    (GQL_TRANS_INPUTS_RESET).
--  * Bounded: the shared cache in entries and bytes (sqlbif.c), the private
--    one at 500 entries; neither keeps an entry over 64 KB.
--  * registry __gql_trans_cache = 'off' disables both, and
--    __gql_shared_trans_cache = 'off' only the shared one.
--  * The [GQL] ini items are read when translating: after changing them on
--    a running server, call DB.DBA.GQL_TRANS_CACHE_FLUSH () (or restart).
----------------------------------------------------------------------

create procedure DB.DBA.GQL_TRANS_CACHE_KEY (in _kind varchar, in _query varchar, in _graph varchar)
{
  _query := DB.DBA.GQL_QUERY_TEXT (_query);
  -- The opt-in translation choices are part of the key, so turning one on
  -- or off never reuses a text translated the other way.
  return concat (_kind, chr (1), cast (length (_query) as varchar), chr (1), _query, chr (1),
    case when _graph is null then '-' else cast (length (_graph) as varchar) end, chr (1),
    coalesce (_graph, ''), chr (1),
    coalesce (cast (registry_get ('URIQADefaultHost') as varchar), ''), chr (1),
    coalesce (cast (registry_get ('__gql_count_preagg') as varchar), 'off'));
}
;

-- Bytes a cached value holds: a SPARQL text, or a vector of texts, numbers
-- and vectors of names.
create procedure DB.DBA.GQL_TRANS_CACHE_VALUE_BYTES (inout _val any)
{
  declare _i, _n integer;
  if (isstring (_val))
    return length (_val);
  if (not isarray (_val))
    return 8;
  _n := 8 * length (_val);
  for (_i := 0; _i < length (_val); _i := _i + 1)
    {
      if (isstring (aref (_val, _i)))
        _n := _n + length (aref (_val, _i));
      else if (isarray (aref (_val, _i)))
        _n := _n + 64 * length (aref (_val, _i));
    }
  return _n;
}
;

create procedure DB.DBA.GQL_TRANS_CACHE_LOCAL_PUT (in _key varchar, inout _val any)
{
  declare _c any;
  _c := connection_get ('gql_trans_cache');
  if (_c is null or dict_size (_c) >= 500)
    {
      _c := dict_new (101);
      connection_set ('gql_trans_cache', _c);
    }
  dict_put (_c, _key, _val);
}
;

create procedure DB.DBA.GQL_TRANS_CACHE_GET (in _key varchar)
{
  declare _c, _shared, _v any;
  declare _generation integer;
  if (coalesce (registry_get ('__gql_trans_cache'), 'on') = 'off')
    return null;
  _generation := __gql_shape_cache_generation ();
  if (coalesce (connection_get ('gql_trans_cache_generation'), -1) <> _generation)
    {
      connection_set ('gql_trans_cache', null);
      connection_set ('gql_trans_cache_generation', _generation);
    }
  _c := connection_get ('gql_trans_cache');
  if (_c is not null)
    {
      _v := dict_get (_c, _key, null);
      if (_v is not null)
        return _v;
    }
  -- Remember the generation this miss saw, for the publication after it.
  connection_set ('gql_trans_cache_lookup_generation', _generation);
  if (coalesce (registry_get ('__gql_shared_trans_cache'), 'on') = 'off')
    return null;
  _shared := __gql_shape_cache_get (_key);
  connection_set ('gql_trans_cache_lookup_generation', aref (_shared, 0));
  _v := aref (_shared, 1);
  if (_v is null)
    return null;
  DB.DBA.GQL_TRANS_CACHE_LOCAL_PUT (_key, _v);
  return _v;
}
;

-- Publish the translation made after a miss on _key: to the shared cache,
-- carrying the generation that miss saw (refused if a flush came between),
-- then to this connection's private cache.
create procedure DB.DBA.GQL_TRANS_CACHE_PUT (in _key varchar, in _val any)
{
  declare _generation integer;
  if (coalesce (registry_get ('__gql_trans_cache'), 'on') = 'off')
    return;
  if (_val is null or length (_key) + DB.DBA.GQL_TRANS_CACHE_VALUE_BYTES (_val) > 65536)
    return;
  _generation := coalesce (connection_get ('gql_trans_cache_lookup_generation'),
    __gql_shape_cache_generation ());
  if (coalesce (registry_get ('__gql_shared_trans_cache'), 'on') <> 'off')
    {
      if (__gql_shape_cache_put (_key, _val, _generation) = 0)
        return;
    }
  else if (_generation <> __gql_shape_cache_generation ())
    return;
  DB.DBA.GQL_TRANS_CACHE_LOCAL_PUT (_key, _val);
}
;

create procedure DB.DBA.GQL_TRANS_CACHE_FLUSH ()
{
  connection_set ('gql_trans_cache', null);
  connection_set ('gql_trans_cache_generation', __gql_shape_cache_flush ());
}
;

-- vector (hits, misses, puts, evictions, generation, entries,
-- invalidations, bytes) of the shared cache.
create procedure DB.DBA.GQL_TRANS_CACHE_STATS ()
{
  return __gql_shape_cache_stats ();
}
;

create procedure DB.DBA.GQL_TRANS_CACHE_STATS_NAMED ()
{
  declare _s any;
  _s := __gql_shape_cache_stats ();
  return vector (
    vector ('hits', aref (_s, 0)),
    vector ('misses', aref (_s, 1)),
    vector ('puts', aref (_s, 2)),
    vector ('evictions', aref (_s, 3)),
    vector ('generation', aref (_s, 4)),
    vector ('entries', aref (_s, 5)),
    vector ('invalidations', aref (_s, 6)),
    vector ('bytes', aref (_s, 7)));
}
;

-- Drop only this connection's private cache; the shared one is untouched.
create procedure DB.DBA.GQL_TRANS_CACHE_LOCAL_CLEAR ()
{
  connection_set ('gql_trans_cache', null);
  connection_set ('gql_trans_cache_lookup_generation', null);
}
;

-- The translator reads connection variables: the property-graph stash it
-- fills from a USE clause and empties again (__gql_pg_*), bound parameters
-- (gql_bound_params) and the gqlc probe's answer (__gql_has_gqlc).  Any user
-- can set them with connection_set; a translation that may be published to
-- every connection must depend on nothing but its key, so it starts with
-- them cleared.
create procedure DB.DBA.GQL_TRANS_INPUTS_RESET ()
{
  connection_set ('gql_bound_params', null);
  connection_set ('__gql_pg_ontology_ns', null);
  connection_set ('__gql_pg_data_ns', null);
  connection_set ('__gql_pg_is_property_graph', 0);
  connection_set ('__gql_pg_name', null);
  connection_set ('__gql_has_gqlc', null);
}
;

----------------------------------------------------------------------
-- Positional parameters.
--
-- Parameterized reads, prepared reads and DML batches send values to one
-- compiled SPARQL statement through positional bind markers (??), which the
-- SQL compiler numbers :0, :1, ...  A statement may carry at most 1000 of
-- them: sqlc_make_param_list collects numbered parameters into a fixed
-- 1000-slot array, and on this branch the 1001st overruns it at compile
-- time, before a value is bound.  Every GQL path that emits markers stays
-- within GQL_MAX_BIND_MARKERS -- by falling back to inline literals, by
-- refusing the template (G4013), or by splitting a batch.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_MAX_BIND_MARKERS ()
{
  return 1000;
}
;

-- Parse a statement's tokens for translation: resolve the graph a USE or
-- AT clause names into _graph, validate variable scope, and return the
-- validated AST.  _query_ast gets its QUERY node, or NULL if it has none.
create procedure DB.DBA.GQL_PARSE_STATEMENT (inout _tokens any, inout _graph varchar, out _query_ast any)
{
  declare ast, proc_body, at_schema, pg_ref any;
  ast := DB.DBA.GQL_PARSE (_tokens);
  proc_body := null;
  if (isarray (ast) and aref (ast, 0) = 'PROG')
    proc_body := aref (ast, 1);
  if (proc_body is not null and isarray (proc_body) and aref (proc_body, 0) = 'PROC'
      and aref (proc_body, 1) is not null)
    {
      at_schema := aref (proc_body, 1);
      if (isarray (at_schema) and aref (at_schema, 0) = 'ANY_GRAPH')
        _graph := null;
      else if (isarray (at_schema) and aref (at_schema, 0) = 'HOME_GRAPH')
        _graph := DB.DBA.GQL_HOME_GRAPH ();
      else if (isarray (at_schema) and aref (at_schema, 0) = 'USE_PROPERTY_AT_SCHEMA')
        {
          -- USE PROPERTY GRAPH <name> wraps a GRAPH_REF: resolve the
          -- property graph's IRI from the catalog.
          pg_ref := aref (at_schema, 1);
          if (isarray (pg_ref) and length (pg_ref) > 1 and aref (pg_ref, 0) = 'GRAPH_REF')
            _graph := DB.DBA.GQL_PG_GRAPH_IRI (cast (aref (pg_ref, 1) as varchar));
          else
            _graph := DB.DBA.GQL_GRAPH_REF_VALUE (pg_ref);
        }
      else
        _graph := DB.DBA.GQL_GRAPH_REF_VALUE (at_schema);
    }
  ast := DB.DBA.GQL_PLAN_VALIDATE_SCOPE (ast);
  _query_ast := ast;
  if (isarray (_query_ast) and aref (_query_ast, 0) = 'PROG')
    {
      if (aref (_query_ast, 1) is not null and isarray (aref (_query_ast, 1))
          and aref (aref (_query_ast, 1), 0) = 'PROC')
        _query_ast := aref (aref (_query_ast, 1), 3);
      else
        _query_ast := null;
    }
  if (_query_ast is not null and (not isarray (_query_ast)
      or (aref (_query_ast, 0) <> 'QUERY' and aref (_query_ast, 0) <> 'SETOP')))
    _query_ast := null;
  return ast;
}
;

-- Find the parameter placeholders (?__gql_m<k>) in SPARQL text, outside
-- string literals and IRIs.  _order gets k for each, in text order.  With
-- _to_markers = 1 each placeholder is replaced by a positional marker (??).
create procedure DB.DBA.GQL_SPARQL_PLACEHOLDERS (inout _s varchar, in _to_markers integer, out _order any)
{
  declare i, j, n, ch, instr, run, k integer;
  declare ses, ord any;
  n := length (_s);
  i := 0; instr := 0; run := 0;
  vectorbld_init (ord);
  ses := null;
  if (_to_markers)
    ses := string_output ();
  while (i < n)
    {
      ch := aref (_s, i);
      if (instr = 1)
        {
          if (ch = 92)
            i := i + 2;
          else
            {
              if (ch = 34)
                instr := 0;
              i := i + 1;
            }
        }
      else if (ch = 34)
        {
          instr := 1;
          i := i + 1;
        }
      else if (ch = 60 and i + 1 < n and aref (_s, i + 1) not in (32, 60, 61))
        {
          -- An IRI runs to the next '>' without spaces; '<' as an operator
          -- is followed by a space, '<' or '='.
          j := i + 1;
          while (j < n and aref (_s, j) <> 62 and aref (_s, j) > 32)
            j := j + 1;
          if (j < n and aref (_s, j) = 62)
            i := j + 1;
          else
            i := i + 1;
        }
      else if (ch = 63 and i + 8 < n and subseq (_s, i, i + 8) = '?__gql_m'
               and aref (_s, i + 8) >= 48 and aref (_s, i + 8) <= 57)
        {
          j := i + 8;
          k := 0;
          while (j < n and aref (_s, j) >= 48 and aref (_s, j) <= 57)
            {
              k := 10 * k + aref (_s, j) - 48;
              j := j + 1;
            }
          vectorbld_acc (ord, k + 0);
          if (ses is not null)
            {
              http (subseq (_s, run, i), ses);
              http ('??', ses);
              run := j;
            }
          i := j;
        }
      else
        i := i + 1;
    }
  vectorbld_final (ord);
  _order := ord;
  if (ses is null)
    return _s;
  http (subseq (_s, run, n), ses);
  return string_output_string (ses);
}
;

-- Translate with parameters bound by position (see the PARAM case of
-- GQL_GEN_EXPR): _mode 'auto' marks the literals GQL_PARAM_REWRITE
-- replaced, 'all' every named parameter.  Returns the SPARQL with a
-- positional marker (??) for each, and real newlines (a statement with
-- markers is parsed strictly); _names gets the parameter name of each
-- marker in the order of the text.
create procedure DB.DBA.GQL_TRANSLATE_MARKED (inout _ast any, in _graph varchar, in _mode varchar, out _names any)
{
  declare sparql_str varchar;
  declare seq, ord, names any;
  declare i integer;
  declare exit handler for sqlstate '*'
    {
      connection_set ('gql_marker_mode', null);
      connection_set ('gql_marker_seq', null);
      resignal;
    };
  connection_set ('gql_marker_seq', vector ());
  connection_set ('gql_marker_mode', _mode);
  sparql_str := DB.DBA.GQL_TO_SPARQL_IMPL (_ast, _graph);
  seq := connection_get ('gql_marker_seq');
  connection_set ('gql_marker_mode', null);
  connection_set ('gql_marker_seq', null);
  if (not isarray (seq))
    seq := vector ();
  _names := vector ();
  if (sparql_str is null)
    return null;
  sparql_str := DB.DBA.GQL_SPARQL_PLACEHOLDERS (sparql_str, 1, ord);
  vectorbld_init (names);
  for (i := 0; i < length (ord); i := i + 1)
    vectorbld_acc (names, aref (seq, aref (ord, i)));
  vectorbld_final (names);
  _names := names;
  return DB.DBA.GQL_SPARQL_UNESC_NL (sparql_str);
}
;

----------------------------------------------------------------------
-- Parameterized reads (registry __gql_parameterize = 'on').
--
-- GQL_PARAM_REWRITE replaces a read's data literals with auto-parameters so
-- that every value of a repeated query shape shares one translation and one
-- compiled plan.  Only a plain string literal ('..' or "..") right after ':'
-- (a property-map value), '=' or '<>' is replaced -- positions that hold
-- data; numbers, typed and language-tagged strings, LIKE patterns and list
-- members stay in the text.  It returns the rewritten tokens; _values gets
-- the literals in token order and _sig a signature of everything else.
-- An auto-parameter is named chr (1) || its index: no GQL text can produce
-- that name, so a caller's own $parameters are never mistaken for one.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARAM_REWRITE (inout _tokens any, out _values any, out _sig varchar)
{
  declare n, i, tt, prevc, nextc, nvals integer;
  declare out_toks, vals, ses any;
  declare v varchar;
  n := length (_tokens);
  vectorbld_init (out_toks);
  vectorbld_init (vals);
  nvals := 0;
  ses := string_output ();
  prevc := 0;
  for (i := 0; i < n; i := i + 1)
    {
      tt := aref (_tokens, i, 0);
      nextc := 0;
      if (i + 1 < n)
        nextc := aref (_tokens, i + 1, 0);
      if ((tt = 65 or tt = 72)                         -- STRING / DQ_STRING
          and (prevc = 7 or prevc = 15 or prevc = 16)  -- after ':' '=' '<>'
          and nextc <> 23 and nextc <> 73)             -- not ^^type / @lang
        {
          vectorbld_acc (out_toks, vector (68, concat (chr (1), cast (nvals as varchar)), aref (_tokens, i, 2)));
          vectorbld_acc (vals, aref (_tokens, i, 1));
          nvals := nvals + 1;
          http (' ?', ses);
        }
      else
        {
          -- Each value is length-prefixed, so two different token streams
          -- never share a signature.
          vectorbld_acc (out_toks, aref (_tokens, i));
          v := cast (aref (_tokens, i, 1) as varchar);
          http (sprintf (' %d:%d:', tt, length (v)), ses);
          http (v, ses);
        }
      prevc := tt;
    }
  vectorbld_final (out_toks);
  vectorbld_final (vals);
  _values := vals;
  _sig := string_output_string (ses);
  return out_toks;
}
;

-- The translator separates statements and clauses with the two characters
-- '\' 'n'.  A statement with bind markers is parsed strictly and rejects
-- them, so turn them into newlines -- outside string literals only, where a
-- '\n' is an escape in the data.
create procedure DB.DBA.GQL_SPARQL_UNESC_NL (in _s varchar)
{
  declare i, n, instr, ch integer;
  declare ses any;
  n := length (_s);
  ses := string_output ();
  i := 0; instr := 0;
  while (i < n)
    {
      ch := aref (_s, i);
      if (instr = 0 and ch = 92 and i + 1 < n and aref (_s, i + 1) = 110)  -- \n outside a string
        { http (chr (10), ses); i := i + 2; }
      else if (instr = 1 and ch = 92 and i + 1 < n)                         -- escape pair inside a string
        { http (chr (92), ses); http (chr (aref (_s, i + 1)), ses); i := i + 2; }
      else
        {
          if (ch = 34) instr := 1 - instr;   -- toggle on an unescaped "
          http (chr (ch), ses); i := i + 1;
        }
    }
  return string_output_string (ses);
}
;

-- The values for a statement's markers: _values in token order, _order the
-- index of the value each marker takes.
create procedure DB.DBA.GQL_PARAM_REORDER (inout _values any, inout _order any)
{
  declare _out any;
  declare i, m integer;
  m := length (_order);
  vectorbld_init (_out);
  for (i := 0; i < m; i := i + 1)
    vectorbld_acc (_out, aref (_values, aref (_order, i)));
  vectorbld_final (_out);
  return _out;
}
;

----------------------------------------------------------------------
-- Prepared reads: a template with named $parameters, translated once per
-- (template, graph) and executed with its values bound to markers.  Only
-- reads are accepted (G4012); the check runs on a miss, before translating,
-- so a cached entry was always a read.
----------------------------------------------------------------------

-- The values for _names (marker order) from caller pairs (name, value);
-- a name may be written with or without its '$' or '?'.
create procedure DB.DBA.GQL_PREPARED_BIND_PARAMS (in _params any, inout _names any)
{
  declare supplied, outv any;
  declare i, n integer;
  declare k varchar;
  if (_params is null)
    _params := vector ();
  if (not isarray (_params) or isstring (_params))
    signal ('G4010', 'Prepared GQL parameters must be a vector of name/value pairs');
  supplied := dict_new (2 * length (_params) + 1);
  for (i := 0; i < length (_params); i := i + 1)
    {
      if (not isarray (aref (_params, i)) or isstring (aref (_params, i))
          or length (aref (_params, i)) <> 2 or not isstring (aref (_params, i, 0)))
        signal ('G4010', 'Malformed prepared GQL name/value pair');
      k := aref (_params, i, 0);
      if (length (k) > 0 and (aref (k, 0) = 36 or aref (k, 0) = 63))
        k := subseq (k, 1);
      if (dict_get (supplied, k, null) is not null)
        signal ('G4010', sprintf ('Duplicate prepared GQL parameter $%s', k));
      dict_put (supplied, k, vector (aref (_params, i, 1)));
    }
  n := length (_names);
  vectorbld_init (outv);
  for (i := 0; i < n; i := i + 1)
    {
      k := aref (_names, i);
      if (dict_get (supplied, k, null) is null)
        signal ('G4011', sprintf ('Missing prepared GQL parameter $%s', k));
      vectorbld_acc (outv, aref (dict_get (supplied, k, null), 0));
    }
  vectorbld_final (outv);
  -- Every supplied name must be one the template uses.
  for (i := 0; i < n; i := i + 1)
    dict_remove (supplied, aref (_names, i));
  if (dict_size (supplied) > 0)
    signal ('G4010', sprintf ('Unknown prepared GQL parameter $%s', aref (dict_list_keys (supplied, 0), 0)));
  return outv;
}
;

create procedure DB.DBA.GQL_PREPARED_PLAN
  (in _query varchar, in _graph varchar, in _params any, out _sparql varchar, out _execv any)
{
  declare pkey, cached, names, tokens, ast, query_ast any;
  declare i, nparams integer;
  if (_graph is null)
    _graph := DB.DBA.GQL_SESSION_DEFAULT_GRAPH ();
  pkey := DB.DBA.GQL_TRANS_CACHE_KEY ('prepared', _query, _graph);
  cached := DB.DBA.GQL_TRANS_CACHE_GET (pkey);
  if (cached is not null)
    {
      _sparql := aref (cached, 0);
      names := aref (cached, 1);
    }
  else
    {
      DB.DBA.GQL_TRANS_INPUTS_RESET ();
      tokens := DB.DBA.GQL_TOKENIZE (_query);
      nparams := 0;
      for (i := 0; i < length (tokens); i := i + 1)
        if (aref (tokens, i, 0) = 68)
          nparams := nparams + 1;
      if (nparams > DB.DBA.GQL_MAX_BIND_MARKERS ())
        signal ('G4013', sprintf ('Prepared GQL template has %d parameters; one statement may bind at most %d',
          nparams, DB.DBA.GQL_MAX_BIND_MARKERS ()));
      ast := DB.DBA.GQL_PARSE_STATEMENT (tokens, _graph, query_ast);
      if (not DB.DBA.GQL_AST_IS_READ (query_ast))
        signal ('G4012', 'Prepared GQL API accepts read queries only');
      _sparql := DB.DBA.GQL_TRANSLATE_MARKED (ast, _graph, 'all', names);
      if (_sparql is null or trim (_sparql) = '')
        signal ('G4012', 'Prepared GQL query did not produce a read plan');
      if (length (names) > DB.DBA.GQL_MAX_BIND_MARKERS ())
        signal ('G4013', sprintf ('Prepared GQL template binds %d values; one statement may bind at most %d',
          length (names), DB.DBA.GQL_MAX_BIND_MARKERS ()));
      DB.DBA.GQL_TRANS_CACHE_PUT (pkey, vector (_sparql, names));
    }
  _execv := DB.DBA.GQL_PREPARED_BIND_PARAMS (_params, names);
}
;

----------------------------------------------------------------------
-- DML batches and prepared DML.
--
-- A DML template with named $parameters is translated once, in marker mode
-- 'all': each parameter is the placeholder variable ?__gql_m<k> and each node
-- or edge the template creates is a fresh-IRI variable ?__gql_fresh_<k>
-- (GQL_FRESH_IRI_SLOT).  GQL_BATCH_PARAMS runs it for a vector of rows,
-- GQL_PREPARED_DML_PARAMS for one.  A one-statement template runs set-wise:
-- each chunk of rows BINDs the variables in a UNION of groups, and full
-- chunks share one compiled plan.  A chunk holds at most 50 rows and
-- GQL_MAX_BIND_MARKERS markers: the cost per row grows with the UNION
-- (5 markers a row: 10,800 rows/s at 50 rows, 9,400 at 100, 5,800 at 200),
-- and much past 200 the statement no longer compiles (SQ200/SQ199).  The variables are bound by name, so where the translator put them
-- in the text does not matter.  A template that translates to several
-- statements runs them row by row, in order, each with its own markers.
-- Values are always bound, never written into the text; the update runs as
-- the caller, so SPARUL applies graph security as for any update.
----------------------------------------------------------------------

-- 1 when a parsed QUERY writes and does nothing else: reads plus INSERT,
-- DELETE, SET and REMOVE.  DDL, CALL, LOAD, CLEAR, session changes and
-- anything unknown are not batched.
create procedure DB.DBA.GQL_AST_IS_DML (inout _query_ast any)
{
  declare _clauses any;
  declare _i, _n, _writes integer;
  declare _k varchar;
  if (_query_ast is null or not isarray (_query_ast) or length (_query_ast) < 2
      or aref (_query_ast, 0) <> 'QUERY')
    return 0;
  _clauses := aref (_query_ast, 1);
  if (not isarray (_clauses))
    return 0;
  _n := length (_clauses);
  _writes := 0;
  for (_i := 0; _i < _n; _i := _i + 1)
    {
      if (not isarray (aref (_clauses, _i)) or isstring (aref (_clauses, _i)))
        return 0;
      _k := aref (_clauses, _i, 0);
      if (_k in ('INSERT', 'INSERT_PROPERTY', 'SET', 'REMOVE', 'DELETE'))
        _writes := _writes + 1;
      else if (not (_k in ('MATCH', 'FILTER', 'WHERE', 'LET', 'FOR', 'UNNEST', 'DEFINE',
            'PREFIX', 'BASE', 'USE', 'USE_PROPERTY', 'USE_HOME_GRAPH', 'FINISH',
            'FORCE_CAMELCASE')))
        return 0;
    }
  if (_writes > 0)
    return 1;
  return 0;
}
;

-- The translated form of a DML template for _graph, cached: vector
-- (statements, names, slots, orders) -- the SPARQL statements with their
-- placeholders, the parameter name of placeholder k, the IRI prefix of each
-- fresh slot, and for each statement the k of its placeholders in text
-- order.  No IRI is minted while translating in 'all' mode, so this
-- translation is reusable like a read's.
create procedure DB.DBA.GQL_DML_TEMPLATE (in _query varchar, inout _graph varchar)
{
  declare pkey, cached, tokens, ast, query_ast, names, slots, statements, orders, ord any;
  declare sparql_str, stmt varchar;
  declare i, j integer;
  pkey := DB.DBA.GQL_TRANS_CACHE_KEY ('dml', _query, _graph);
  cached := DB.DBA.GQL_TRANS_CACHE_GET (pkey);
  if (cached is not null)
    return cached;
  DB.DBA.GQL_TRANS_INPUTS_RESET ();
  tokens := DB.DBA.GQL_TOKENIZE (_query);
  ast := DB.DBA.GQL_PARSE_STATEMENT (tokens, _graph, query_ast);
  if (not DB.DBA.GQL_AST_IS_DML (query_ast))
    signal ('G4012', 'GQL DML batches and prepared DML accept INSERT, DELETE, SET and REMOVE statements only');
  {
    declare exit handler for sqlstate '*'
      {
        connection_set ('gql_marker_mode', null);
        connection_set ('gql_marker_seq', null);
        connection_set ('gql_fresh_slots', null);
        resignal;
      };
    connection_set ('gql_marker_seq', vector ());
    connection_set ('gql_fresh_slots', vector ());
    connection_set ('gql_marker_mode', 'all');
    sparql_str := DB.DBA.GQL_TO_SPARQL_IMPL (ast, _graph);
    names := connection_get ('gql_marker_seq');
    slots := connection_get ('gql_fresh_slots');
    connection_set ('gql_marker_mode', null);
    connection_set ('gql_marker_seq', null);
    connection_set ('gql_fresh_slots', null);
  }
  if (not isarray (names))
    names := vector ();
  if (not isarray (slots))
    slots := vector ();
  if (sparql_str is null or trim (sparql_str) = '')
    signal ('G4012', 'GQL DML template did not produce a SPARQL update');
  if (length (names) = 0 and length (slots) = 0)
    signal ('G4014', 'GQL DML template must contain a parameter or create a node');
  if (length (names) + length (slots) > DB.DBA.GQL_MAX_BIND_MARKERS ())
    signal ('G4013', sprintf ('GQL DML template binds %d values a row; one statement may bind at most %d',
      length (names) + length (slots), DB.DBA.GQL_MAX_BIND_MARKERS ()));
  statements := DB.DBA.GQL_SPLIT_SPARQL_STATEMENTS (DB.DBA.GQL_SPARQL_UNESC_NL (sparql_str));
  vectorbld_init (orders);
  for (i := 0; i < length (statements); i := i + 1)
    {
      stmt := aref (statements, i);
      DB.DBA.GQL_SPARQL_PLACEHOLDERS (stmt, 0, ord);
      for (j := 0; j < length (ord); j := j + 1)
        if (aref (ord, j) >= length (names))
          signal ('G4014', 'GQL DML template has a placeholder with no parameter');
      vectorbld_acc (orders, ord);
    }
  vectorbld_final (orders);
  cached := vector (statements, names, slots, orders);
  DB.DBA.GQL_TRANS_CACHE_PUT (pkey, cached);
  return cached;
}
;

-- One row's values for a template: the value of each of _names (by
-- placeholder index), then a fresh IRI for each slot.  _row is a vector of
-- (name, value) pairs; a name may carry its '$' or '?'.
create procedure DB.DBA.GQL_BATCH_ROW_VALUES (in _row any, inout _names any, inout _slots any, in _rowno integer)
{
  declare supplied, outv any;
  declare i integer;
  declare k varchar;
  if (not isarray (_row) or isstring (_row))
    signal ('G4010', sprintf ('GQL batch row %d is not a vector of name/value pairs', _rowno));
  supplied := dict_new (2 * length (_row) + 1);
  for (i := 0; i < length (_row); i := i + 1)
    {
      if (isarray (aref (_row, i)) and not isstring (aref (_row, i)) and length (aref (_row, i)) = 2
          and isstring (aref (_row, i, 0)))
        {
          k := aref (_row, i, 0);
          if (length (k) > 0 and (aref (k, 0) = 36 or aref (k, 0) = 63))
            k := subseq (k, 1);
          dict_put (supplied, k, vector (aref (_row, i, 1)));
        }
    }
  vectorbld_init (outv);
  for (i := 0; i < length (_names); i := i + 1)
    {
      k := aref (_names, i);
      if (dict_get (supplied, k, null) is null)
        signal ('G4011', sprintf ('Missing GQL batch parameter $%s in row %d', k, _rowno));
      vectorbld_acc (outv, aref (dict_get (supplied, k, null), 0));
    }
  for (i := 0; i < length (_slots); i := i + 1)
    vectorbld_acc (outv, concat (aref (_slots, i), cast (uuid () as varchar)));
  vectorbld_final (outv);
  return outv;
}
;

-- A WHERE block for a statement, appended after its own: INSERT DATA cannot
-- hold variables, so it becomes INSERT {...} WHERE {...}; any other update
-- gets the block before its last '}' (the end of its WHERE).
create procedure DB.DBA.GQL_DML_ADD_WHERE (inout _stmt varchar, in _block varchar)
{
  declare p integer;
  p := strstr (_stmt, 'INSERT DATA {');
  if (p is not null)
    return concat (subseq (_stmt, 0, p), 'INSERT {', subseq (_stmt, p + 13), ' WHERE { ', _block, ' }');
  p := strrchr (_stmt, '}');
  if (p is null)
    signal ('G4014', 'GQL DML template has no WHERE block to bind its rows in');
  return concat (subseq (_stmt, 0, p), ' ', _block, ' ', subseq (_stmt, p));
}
;

-- A one-statement template binding its _nvals placeholder variables and
-- _nslots fresh-IRI variables once for each of _nrows rows: a UNION of BIND
-- groups whose markers take, row by row, the values in placeholder order
-- and then the fresh IRIs.
create procedure DB.DBA.GQL_DML_SETWISE (inout _stmt varchar, in _nvals integer, in _nslots integer, in _nrows integer)
{
  declare ses any;
  declare r, k integer;
  ses := string_output ();
  for (r := 0; r < _nrows; r := r + 1)
    {
      if (r > 0)
        http (' UNION ', ses);
      http ('{ ', ses);
      for (k := 0; k < _nvals; k := k + 1)
        http (sprintf ('BIND (?? AS ?__gql_m%d) . ', k), ses);
      for (k := 0; k < _nslots; k := k + 1)
        http (sprintf ('BIND (iri (??) AS ?__gql_fresh_%d) . ', k), ses);
      http ('}', ses);
    }
  return DB.DBA.GQL_DML_ADD_WHERE (_stmt, string_output_string (ses));
}
;

-- One row's form of a template statement: its placeholders as ?? in text
-- order (_ord: the parameter each stands for) and a BIND of each fresh IRI
-- it uses (_used: their slots) after its WHERE.  A placeholder stays where
-- the translator put it -- inside a sub-select too, which a block of
-- bindings after the WHERE does not reach.
create procedure DB.DBA.GQL_DML_ROW_FORM (in _stmt varchar, in _nslots integer, out _ord any, out _used any)
{
  declare _ses any;
  declare _k integer;
  _stmt := DB.DBA.GQL_SPARQL_PLACEHOLDERS (_stmt, 1, _ord);
  _ses := string_output ();
  vectorbld_init (_used);
  for (_k := 0; _k < _nslots; _k := _k + 1)
    if (strstr (_stmt, sprintf ('?__gql_fresh_%d', _k)) is not null)
      {
        http (sprintf ('BIND (iri (??) AS ?__gql_fresh_%d) . ', _k), _ses);
        vectorbld_acc (_used, _k + 0);
      }
  vectorbld_final (_used);
  if (length (_used) > 0)
    _stmt := DB.DBA.GQL_DML_ADD_WHERE (_stmt, string_output_string (_ses));
  return _stmt;
}
;

-- The values a GQL_DML_ROW_FORM statement binds for one row, from _rowv:
-- the template's values, then its fresh IRIs.
create procedure DB.DBA.GQL_DML_ROW_VALUES (inout _rowv any, inout _ord any, inout _used any, in _nvals integer)
{
  declare _execv any;
  declare _k integer;
  vectorbld_init (_execv);
  for (_k := 0; _k < length (_ord); _k := _k + 1)
    vectorbld_acc (_execv, aref (_rowv, aref (_ord, _k)));
  for (_k := 0; _k < length (_used); _k := _k + 1)
    vectorbld_acc (_execv, aref (_rowv, _nvals + aref (_used, _k)));
  vectorbld_final (_execv);
  return _execv;
}
;

create procedure DB.DBA.GQL_DML_EXEC (in _stmt varchar, inout _execv any, in _what varchar)
{
  declare state, msg varchar;
  declare meta, data any;
  state := '00000'; msg := '';
  exec (_stmt, state, msg, _execv, vector ('use_cache', 1), meta, data);
  if (state <> '00000')
    signal ('G4001', sprintf ('GQL %s failed [%s]: %s', _what, state, msg));
}
;

-- Run a DML template for every row of _rows (each a vector of (name, value)
-- pairs).  Atomic: if any row fails, the transaction is rolled back and the
-- error re-signalled; on success nothing is committed, so the caller's
-- transaction decides.
create procedure DB.DBA.GQL_BATCH_PARAMS
  (in _query varchar, in _graph varchar := null, in _rows any := null)
{
  declare _tmpl, _statements, _names, _slots, _orders, _ord, _execv, _rowv, _used any;
  declare _forms, _ords, _useds any;
  declare _stmt varchar;
  declare _nvals, _nslots, _nper, _chunk, _off, _stop, _r, _k, _s integer;
  if (_graph is null)
    _graph := DB.DBA.GQL_SESSION_DEFAULT_GRAPH ();
  if (not isarray (_rows) or isstring (_rows))
    signal ('G4010', 'GQL batch rows must be a vector');
  if (length (_rows) = 0)
    return vector ();

  declare exit handler for sqlstate '*'
    {
      rollback work;
      resignal;
    };

  _tmpl := DB.DBA.GQL_DML_TEMPLATE (_query, _graph);
  _statements := aref (_tmpl, 0);
  _names := aref (_tmpl, 1);
  _slots := aref (_tmpl, 2);
  _orders := aref (_tmpl, 3);
  _nvals := length (_names);
  _nslots := length (_slots);
  _nper := _nvals + _nslots;

  -- One statement binds a chunk of rows at once (GQL_DML_SETWISE), unless
  -- its WHERE has a sub-select (SET), which those bindings do not reach.
  if (length (_statements) = 1 and strcasestr (aref (_statements, 0), '{ SELECT ') is null)
    {
      _chunk := DB.DBA.GQL_MAX_BIND_MARKERS () / _nper;
      if (_chunk > 50)
        _chunk := 50;
      for (_off := 0; _off < length (_rows); _off := _off + _chunk)
        {
          _stop := _off + _chunk;
          if (_stop > length (_rows))
            _stop := length (_rows);
          vectorbld_init (_execv);
          for (_r := _off; _r < _stop; _r := _r + 1)
            {
              _rowv := DB.DBA.GQL_BATCH_ROW_VALUES (aref (_rows, _r), _names, _slots, _r);
              for (_k := 0; _k < _nper; _k := _k + 1)
                vectorbld_acc (_execv, aref (_rowv, _k));
            }
          vectorbld_final (_execv);
          _stmt := aref (_statements, 0);
          DB.DBA.GQL_DML_EXEC (DB.DBA.GQL_DML_SETWISE (_stmt, _nvals, _nslots, _stop - _off), _execv,
            sprintf ('batch rows %d-%d', _off, _stop - 1));
        }
      return vector ();
    }

  -- Otherwise each row, statement by statement, in each statement's row
  -- form, built once.
  vectorbld_init (_forms);
  vectorbld_init (_ords);
  vectorbld_init (_useds);
  for (_s := 0; _s < length (_statements); _s := _s + 1)
    {
      vectorbld_acc (_forms, DB.DBA.GQL_DML_ROW_FORM (aref (_statements, _s), _nslots, _ord, _used));
      vectorbld_acc (_ords, _ord);
      vectorbld_acc (_useds, _used);
    }
  vectorbld_final (_forms);
  vectorbld_final (_ords);
  vectorbld_final (_useds);
  for (_r := 0; _r < length (_rows); _r := _r + 1)
    {
      _rowv := DB.DBA.GQL_BATCH_ROW_VALUES (aref (_rows, _r), _names, _slots, _r);
      for (_s := 0; _s < length (_statements); _s := _s + 1)
        {
          _ord := aref (_ords, _s);
          _used := aref (_useds, _s);
          _execv := DB.DBA.GQL_DML_ROW_VALUES (_rowv, _ord, _used, _nvals);
          DB.DBA.GQL_DML_EXEC (aref (_forms, _s), _execv, sprintf ('batch row %d statement %d', _r, _s + 1));
        }
    }
  return vector ();
}
;

-- Prepared single-row DML: _sparql is the template's statement in its row
-- form (GQL_DML_ROW_FORM, cached with it), _execv its values and fresh
-- IRIs.  A template that translates to several statements is refused here
-- (G4012); a batch of one row runs it.
create procedure DB.DBA.GQL_PREPARED_DML_PLAN
  (in _query varchar, in _graph varchar, in _params any, out _sparql varchar, out _execv any)
{
  declare tmpl, statements, names, slots, cached, pkey, values_, outv, ord, used any;
  declare k integer;
  if (_graph is null)
    _graph := DB.DBA.GQL_SESSION_DEFAULT_GRAPH ();
  tmpl := DB.DBA.GQL_DML_TEMPLATE (_query, _graph);
  statements := aref (tmpl, 0);
  names := aref (tmpl, 1);
  slots := aref (tmpl, 2);
  if (length (statements) <> 1)
    signal ('G4012', 'Prepared GQL DML accepts a statement that translates to one SPARQL update');
  pkey := DB.DBA.GQL_TRANS_CACHE_KEY ('pdml', _query, _graph);
  cached := DB.DBA.GQL_TRANS_CACHE_GET (pkey);
  if (cached is null)
    {
      cached := vector (DB.DBA.GQL_DML_ROW_FORM (aref (statements, 0), length (slots), ord, used), ord, used);
      DB.DBA.GQL_TRANS_CACHE_PUT (pkey, cached);
    }
  _sparql := aref (cached, 0);
  ord := aref (cached, 1);
  used := aref (cached, 2);
  values_ := DB.DBA.GQL_PREPARED_BIND_PARAMS (_params, names);
  vectorbld_init (outv);
  for (k := 0; k < length (values_); k := k + 1)
    vectorbld_acc (outv, aref (values_, k));
  for (k := 0; k < length (slots); k := k + 1)
    vectorbld_acc (outv, concat (aref (slots, k), cast (uuid () as varchar)));
  vectorbld_final (outv);
  _execv := DB.DBA.GQL_DML_ROW_VALUES (outv, ord, used, length (names));
}
;

create procedure DB.DBA.GQL_PREPARED_DML_PARAMS
  (in _query varchar, in _graph varchar := null, in _params any := null)
{
  declare sparql_str varchar;
  declare execv any;
  DB.DBA.GQL_PREPARED_DML_PLAN (_query, _graph, _params, sparql_str, execv);
  DB.DBA.GQL_DML_EXEC (sparql_str, execv, 'prepared DML');
  return vector ();
}
;

----------------------------------------------------------------------
-- Vectored edge insertion.
--
-- An edge between two nodes found by a key property: the source is the
-- node of a label whose key property has a given value, and the target
-- likewise.  GQL_VECTOR_EDGE_INSERT takes the keys as two arrays and
-- writes one edge per position.  It looks the endpoints up, and writes the
-- edges, a bounded chunk at a time: each chunk is one vectored lookup and
-- one vectored insert, by statements compiled with the procedure, not per
-- call.  GQL_STAGED_EDGE_INSERT feeds it from a staging table.  With the
-- registry setting __gql_literal_vector 'on', a literal MATCH ... INSERT
-- of that shape runs the same way (GQL_LITERAL_VECTOR_TRY).
--
-- The caller must be allowed to read and write the graph, as for
-- MATCH ... INSERT, whose lookups these are.  Nothing is committed.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_VECTOR_EDGE_RESULT
  (in _submitted integer, in _succeeded integer, in _failed integer,
   in _first_error integer, in _shape varchar, in _mode varchar,
   in _chunks integer)
{
  return vector (
    vector ('rows_submitted', _submitted),
    vector ('rows_succeeded', _succeeded),
    vector ('rows_failed', _failed),
    vector ('first_error_row', _first_error),
    vector ('row_errors', vector ()),
    vector ('transaction_state', 'caller-owned'),
    vector ('plan_shape_id', _shape),
    vector ('cache_hit', null),
    vector ('execution_mode', _mode),
    vector ('chunks_executed', _chunks));
}
;

-- The caller may do what MATCH ... INSERT does to _graph.  The SPARQL
-- route runs as the caller: it reads and inserts into RDF_QUAD with the
-- caller's rights (the SPARQL_UPDATE role grants them), and checks the
-- graph's read and write permissions (SPARUL INSERT).  The bulk paths
-- insert with the procedure owner's, so they check both here.
create procedure DB.DBA.GQL_VECTOR_EDGE_AUTHORIZE (in _graph varchar)
{
  if (__any_grants ('DB.DBA.RDF_QUAD', 1) = 0 or __any_grants ('DB.DBA.RDF_QUAD', 4) = 0)
    signal ('42000', sprintf ('GQL edge insert access denied: user %s may not select from and insert into DB.DBA.RDF_QUAD (the SPARQL_UPDATE role grants it)',
      user));
  __rgs_assert_cbk (_graph, get_user_id (1), 3, 'SPARUL INSERT');
}
;

-- For each of _keys, the node of label _label_iid whose property _prop_iid
-- has that value in graph _graph_iid: its IRI_ID, NULL if there is none,
-- 0 if there is more than one.
create procedure DB.DBA.GQL_VECTOR_EDGE_LOOKUP
  (in _graph_iid any, in _label_iid any, in _prop_iid any, in _keys any, out _ids any)
{
  declare _type_iid any;
  _type_iid := __i2idn (UNAME'http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
  for vectored (in _key any array := _keys, out _ids := _id)
    {
      declare _id any array;
      -- From the key to the node (POGS), then the node's label: the option
      -- keeps that order whatever the statistics of the graph.
      _id := (select case when count (*) > 1 then 0 else min (a.S) end
                from DB.DBA.RDF_QUAD a, DB.DBA.RDF_QUAD b
               where a.G = _graph_iid and a.P = _prop_iid and a.O = DB.DBA.RDF_MAKE_OBJ_OF_SQLVAL (_key)
                 and b.G = _graph_iid and b.S = a.S and b.P = _type_iid and b.O = _label_iid
              option (order));
    }
}
;

-- One edge _edge_iid in _graph_iid from each of _source_ids to the target
-- at the same position; an edge the graph has is not added again.
create procedure DB.DBA.GQL_VECTOR_EDGE_WRITE
  (in _graph_iid any, in _edge_iid any, in _source_ids any, in _target_ids any)
{
  for vectored modify (in _s any array := _source_ids, in _o any array := _target_ids)
    {
      insert soft DB.DBA.RDF_QUAD (G, S, P, O) values (_graph_iid, _s, _edge_iid, _o);
    }
}
;

-- The translation context for terms written into _graph: a property
-- graph's namespaces when _graph is one.  A virtual property graph is not
-- writable (GQ213, as for INSERT).
create procedure DB.DBA.GQL_VECTOR_EDGE_CTX (in _graph varchar)
{
  declare _ctx any;
  _ctx := DB.DBA.GQL_CTX_NEW (_graph);
  for (select PG_NAME as _pg_name, PG_MODE as _pg_mode, ONTOLOGY_NS as _ons, DATA_NS as _dns
         from DB.DBA.GQL_PROPERTY_GRAPH_DEF where GRAPH_IRI = _graph) do
    {
      if (_pg_mode = 'virtual')
        signal ('GQ213',
          sprintf ('Cannot write to virtual property graph %s; virtual PGs are read-only views. Use CREATE PHYSICAL PROPERTY GRAPH for writable graphs.',
            _pg_name));
      DB.DBA.GQL_CTX_SET (_ctx, 'ontology_ns', _ons);
      DB.DBA.GQL_CTX_SET (_ctx, 'data_ns', _dns);
      DB.DBA.GQL_CTX_SET (_ctx, 'is_property_graph', 1);
      DB.DBA.GQL_CTX_SET (_ctx, 'pg_name', _pg_name);
    }
  return _ctx;
}
;

-- One edge _edge_label from the _source_label node whose _source_key_prop
-- is _source_keys[i] to the _target_label node whose _target_key_prop is
-- _target_keys[i], for each i.  Every endpoint is found before the first
-- edge is written: an endpoint that is not there is G4101 (source) or
-- G4102 (target), a key two nodes share G4103, naming the row (its
-- position, or _row_ordinals[i]).  _validate_only = 1 only checks.
-- Returns the GQL_VECTOR_EDGE_RESULT of the call.
create procedure DB.DBA.GQL_VECTOR_EDGE_INSERT
  (in _graph varchar, in _source_label varchar, in _source_key_prop varchar,
   in _source_keys any, in _target_label varchar, in _target_key_prop varchar,
   in _target_keys any, in _edge_label varchar, in _chunk_size integer := 256,
   in _row_ordinals any := null, in _validate_only integer := 0)
{
  declare _ctx, _graph_iid, _sl_iid, _sp_iid, _tl_iid, _tp_iid, _edge_iid any;
  declare _skeys, _tkeys, _sids, _tids, _all_s, _all_t, _cs, _ct any;
  declare _count, _start, _stop, _i, _j integer;
  declare _shape varchar;

  if (_graph is null or _graph = '')
    signal ('G4100', 'GQL vector edge graph must be specified');
  if (not isarray (_source_keys) or not isarray (_target_keys))
    signal ('G4100', 'GQL vector edge keys must be arrays');
  _count := length (_source_keys);
  if (length (_target_keys) <> _count)
    signal ('G4100', sprintf ('GQL vector edge array length mismatch: source=%d target=%d',
      _count, length (_target_keys)));
  if (_chunk_size is null or _chunk_size < 1 or _chunk_size > 4096)
    signal ('G4100', 'GQL vector edge chunk_size must be between 1 and 4096');
  if (_validate_only is null or _validate_only not in (0, 1))
    signal ('G4100', 'GQL vector edge validate_only must be 0 or 1');
  if (_row_ordinals is not null
      and (not isarray (_row_ordinals) or length (_row_ordinals) <> _count))
    signal ('G4100', 'GQL vector edge row_ordinal array length mismatch');

  _ctx := DB.DBA.GQL_VECTOR_EDGE_CTX (_graph);
  DB.DBA.GQL_VECTOR_EDGE_AUTHORIZE (_graph);
  if (_count = 0)
    return DB.DBA.GQL_VECTOR_EDGE_RESULT (0, 0, 0, null, '', 'vector', 0);

  _graph_iid := iri_to_id (_graph);
  -- A label or property no node has: every lookup finds nothing.
  _sl_iid := iri_to_id (DB.DBA.GQL_TERM_URI (_ctx, _source_label, 'label'), 0);
  _sp_iid := iri_to_id (DB.DBA.GQL_TERM_URI (_ctx, _source_key_prop, 'prop'), 0);
  _tl_iid := iri_to_id (DB.DBA.GQL_TERM_URI (_ctx, _target_label, 'label'), 0);
  _tp_iid := iri_to_id (DB.DBA.GQL_TERM_URI (_ctx, _target_key_prop, 'prop'), 0);
  _shape := sprintf ('%s|%s.%s|%s|%s.%s', _graph, _source_label,
    _source_key_prop, _edge_label, _target_label, _target_key_prop);

  -- Find every endpoint, a chunk at a time, before writing anything.
  vectorbld_init (_all_s);
  vectorbld_init (_all_t);
  for (_start := 0; _start < _count; _start := _start + _chunk_size)
    {
      _stop := _start + _chunk_size;
      if (_stop > _count)
        _stop := _count;
      vectorbld_init (_skeys);
      vectorbld_init (_tkeys);
      for (_i := _start; _i < _stop; _i := _i + 1)
        {
          vectorbld_acc (_skeys, aref (_source_keys, _i));
          vectorbld_acc (_tkeys, aref (_target_keys, _i));
        }
      vectorbld_final (_skeys);
      vectorbld_final (_tkeys);
      DB.DBA.GQL_VECTOR_EDGE_LOOKUP (_graph_iid, _sl_iid, _sp_iid, _skeys, _sids);
      DB.DBA.GQL_VECTOR_EDGE_LOOKUP (_graph_iid, _tl_iid, _tp_iid, _tkeys, _tids);
      for (_j := 0; _j < _stop - _start; _j := _j + 1)
        {
          _cs := aref_set_0 (_sids, _j);
          _ct := aref_set_0 (_tids, _j);
          if (not isiri_id (_cs) or not isiri_id (_ct))
            {
              declare _row varchar;
              _row := cast (case when _row_ordinals is null then _start + _j
                else aref (_row_ordinals, _start + _j) end as varchar);
              if (_cs is null)
                signal ('G4101', sprintf ('GQL vector edge row %s source vertex not found', _row));
              if (not isiri_id (_cs))
                signal ('G4103', sprintf ('GQL vector edge row %s source key matches more than one %s node', _row, _source_label));
              if (_ct is null)
                signal ('G4102', sprintf ('GQL vector edge row %s target vertex not found', _row));
              signal ('G4103', sprintf ('GQL vector edge row %s target key matches more than one %s node', _row, _target_label));
            }
          vectorbld_acc (_all_s, _cs);
          vectorbld_acc (_all_t, _ct);
        }
    }
  vectorbld_final (_all_s);
  vectorbld_final (_all_t);
  if (_validate_only = 1)
    return DB.DBA.GQL_VECTOR_EDGE_RESULT (_count, 0, 0, null, _shape, 'validate', 0);

  _edge_iid := iri_to_id (DB.DBA.GQL_TERM_URI (_ctx, _edge_label, 'edge'));
  for (_start := 0; _start < _count; _start := _start + _chunk_size)
    {
      _stop := _start + _chunk_size;
      if (_stop > _count)
        _stop := _count;
      vectorbld_init (_sids);
      vectorbld_init (_tids);
      for (_i := _start; _i < _stop; _i := _i + 1)
        {
          vectorbld_acc (_sids, aref_set_0 (_all_s, _i));
          vectorbld_acc (_tids, aref_set_0 (_all_t, _i));
        }
      vectorbld_final (_sids);
      vectorbld_final (_tids);
      DB.DBA.GQL_VECTOR_EDGE_WRITE (_graph_iid, _edge_iid, _sids, _tids);
    }
  return DB.DBA.GQL_VECTOR_EDGE_RESULT (_count, _count, 0, null, _shape, 'vector',
    (_count + _chunk_size - 1) / _chunk_size);
}
;

-- The name a column of the staging table _table has, for _column in any
-- case; G4200 if it has none.
create procedure DB.DBA.GQL_STAGE_COLUMN_RESOLVE (in _table varchar, in _column varchar)
{
  for (select "COLUMN" as _catalog_column from DB.DBA.SYS_COLS
    where "TABLE" = _table and lower ("COLUMN") = lower (_column)) do
    return _catalog_column;
  signal ('G4200', sprintf ('GQL edge staging column %s does not exist in %s',
    _column, _table));
}
;

-- GQL_VECTOR_EDGE_INSERT for the rows of the staging table _stage_table:
-- source key, target key and edge type in the named columns, read in the
-- order of the unique, non-NULL ordinal column, a page of _chunk_size rows
-- at a time and with the caller's rights.  Each row's edge type must be
-- _edge_label (G4202).  Every page is validated before the first edge is
-- written; errors name the row's ordinal.
create procedure DB.DBA.GQL_STAGED_EDGE_INSERT
  (in _stage_table varchar, in _ordinal_column varchar,
   in _source_column varchar, in _target_column varchar,
   in _edge_column varchar, in _graph varchar,
   in _source_label varchar, in _source_key_prop varchar,
   in _target_label varchar, in _target_key_prop varchar,
   in _edge_label varchar, in _chunk_size integer := 256)
{
  declare _table, _qtable, _ord_col, _src_col, _dst_col, _edge_col varchar;
  declare _sql, _state, _msg varchar;
  declare _meta, _data, _row, _ordinals, _sources, _targets any;
  declare _ord_acc, _src_acc, _dst_acc any;
  declare _last_ordinal any;
  declare _pass, _first, _i, _total, _chunks integer;

  if (_chunk_size is null or _chunk_size < 1 or _chunk_size > 4096)
    signal ('G4200', 'GQL staged edge chunk_size must be between 1 and 4096');
  _table := complete_table_name (_stage_table, 1);
  if (_table is null or not exists
      (select 1 from DB.DBA.SYS_COLS where "TABLE" = _table))
    signal ('G4200', sprintf ('GQL edge staging table %s does not exist', _stage_table));
  _ord_col := DB.DBA.GQL_STAGE_COLUMN_RESOLVE (_table, _ordinal_column);
  _src_col := DB.DBA.GQL_STAGE_COLUMN_RESOLVE (_table, _source_column);
  _dst_col := DB.DBA.GQL_STAGE_COLUMN_RESOLVE (_table, _target_column);
  _edge_col := DB.DBA.GQL_STAGE_COLUMN_RESOLVE (_table, _edge_column);
  _qtable := sprintf ('"%I"."%I"."%I"', name_part (_table, 0),
    name_part (_table, 1), name_part (_table, 2));

  -- Paging by ordinal needs every ordinal present and distinct.
  _sql := sprintf ('select top 1 "%I" from %s where "%I" is null',
    _ord_col, _qtable, _ord_col);
  _state := '00000'; _msg := '';
  exec (_sql, _state, _msg, vector (), vector ('use_cache', 1), _meta, _data);
  if (_state <> '00000')
    signal ('G4200', _msg);
  if (isarray (_data) and length (_data) > 0)
    signal ('G4201', 'GQL edge staging row has NULL row ordinal');
  _sql := sprintf ('select top 1 "%I" from %s group by "%I" having count (*) > 1',
    _ord_col, _qtable, _ord_col);
  _state := '00000'; _msg := '';
  exec (_sql, _state, _msg, vector (), vector ('use_cache', 1), _meta, _data);
  if (_state <> '00000')
    signal ('G4200', _msg);
  if (isarray (_data) and length (_data) > 0)
    signal ('G4201', sprintf ('GQL edge staging row ordinal %s is duplicated',
      cast (aref (_data, 0, 0) as varchar)));

  -- Pass 0 validates every page, pass 1 writes them.
  _total := 0; _chunks := 0;
  for (_pass := 0; _pass < 2; _pass := _pass + 1)
    {
      _first := 1; _last_ordinal := null;
      while (1)
        {
          if (_first = 1)
            _sql := sprintf (
              'select top %d "%I", "%I", "%I", "%I" from %s order by "%I"',
              _chunk_size, _ord_col, _src_col, _dst_col, _edge_col, _qtable, _ord_col);
          else
            _sql := sprintf (
              'select top %d "%I", "%I", "%I", "%I" from %s where "%I" > ? order by "%I"',
              _chunk_size, _ord_col, _src_col, _dst_col, _edge_col, _qtable,
              _ord_col, _ord_col);
          _state := '00000'; _msg := '';
          exec (_sql, _state, _msg,
            case when _first = 1 then vector () else vector (_last_ordinal) end,
            vector ('use_cache', 1), _meta, _data);
          if (_state <> '00000')
            signal ('G4200', _msg);
          if (not isarray (_data) or length (_data) = 0)
            goto staged_pass_done;

          vectorbld_init (_ord_acc);
          vectorbld_init (_src_acc);
          vectorbld_init (_dst_acc);
          for (_i := 0; _i < length (_data); _i := _i + 1)
            {
              _row := aref_set_0 (_data, _i);
              if (aref (_row, 3) is null or cast (aref (_row, 3) as varchar) <> _edge_label)
                signal ('G4202', sprintf ('GQL edge staging row %s has edge type %s; expected %s',
                  cast (aref (_row, 0) as varchar),
                  coalesce (cast (aref (_row, 3) as varchar), 'NULL'), _edge_label));
              vectorbld_acc (_ord_acc, aref_set_0 (_row, 0));
              vectorbld_acc (_src_acc, aref_set_0 (_row, 1));
              vectorbld_acc (_dst_acc, aref_set_0 (_row, 2));
            }
          vectorbld_final (_ord_acc);
          vectorbld_final (_src_acc);
          vectorbld_final (_dst_acc);
          _ordinals := _ord_acc; _sources := _src_acc; _targets := _dst_acc;
          _last_ordinal := aref (_ordinals, length (_ordinals) - 1);
          _first := 0;

          DB.DBA.GQL_VECTOR_EDGE_INSERT (_graph, _source_label,
            _source_key_prop, _sources, _target_label, _target_key_prop,
            _targets, _edge_label, _chunk_size, _ordinals,
            case when _pass = 0 then 1 else 0 end);
          if (_pass = 0)
            _total := _total + length (_ordinals);
          else
            _chunks := _chunks + 1;
        }
      staged_pass_done:;
    }

  return DB.DBA.GQL_VECTOR_EDGE_RESULT (_total, _total, 0, null,
    concat ('stage:', _table, '|', _edge_label), 'staged-vector', _chunks);
}
;

----------------------------------------------------------------------
-- Opt-in literal route (registry __gql_literal_vector = 'on').
--
-- A literal MATCH ... INSERT that only links key-matched node pairs, as a
-- loader writes edges in groups, compiles one SPARQL join of all its node
-- patterns per new text: about 0.4 s for five edges.  This route runs it
-- as the vectored lookup and insert, with the results of the SPARQL route,
-- and leaves any other statement to it.  The connection variable
-- gql_literal_vector_dispatch says which ran: 'vector' or 'fallback'.  The
-- route reads and writes the quad store (RDF_QUAD) directly; it is not for
-- graphs an RDF view maps (a virtual property graph is left to the SPARQL
-- route, which refuses it).
----------------------------------------------------------------------

create procedure DB.DBA.GQL_LITERAL_VECTOR_ENABLED ()
{
  return case when coalesce (registry_get ('__gql_literal_vector'), 'off') = 'on' then 1 else 0 end;
}
;

-- A label, property or edge type GQL_TERM_URI maps to <namespace><name>:
-- letters, digits and '_', not starting with a digit.
create procedure DB.DBA.GQL_LITERAL_VECTOR_NAME_OK (in _n any)
{
  declare _i, _c integer;
  if (not isstring (_n) or length (_n) = 0 or length (_n) > 200)
    return 0;
  for (_i := 0; _i < length (_n); _i := _i + 1)
    {
      _c := aref (_n, _i);
      if (not ((_c >= 65 and _c <= 90) or (_c >= 97 and _c <= 122) or _c = 95
               or (_i > 0 and _c >= 48 and _c <= 57)))
        return 0;
    }
  return 1;
}
;

-- The statements the literal route runs: MATCH of 2n node patterns
-- (v:Label { key: value }) -- one label, one property, a string or integer
-- value, every variable different -- then INSERT of n edges
-- (s)-[:Type]->(t), one type, no variable or properties, each MATCH
-- variable an endpoint of exactly one edge, all sources one label and key
-- property, all targets likewise, all edges one type; no other clause, and
-- no preamble but USE PROPERTY GRAPH <name>.  Returns 1 with the labels,
-- key properties and keys of the sources and targets, the edge type and
-- the property graph's name (NULL for none); 0 for any other statement.
create procedure DB.DBA.GQL_LITERAL_VECTOR_CLASSIFY
  (inout _ast any, inout _query_ast any,
   out _source_label varchar, out _source_prop varchar, out _source_keys any,
   out _target_label varchar, out _target_prop varchar, out _target_keys any,
   out _edge_label varchar, out _pg_name varchar)
{
  declare _proc, _at, _ref, _clauses, _match, _insert, _mpats, _ipats any;
  declare _names, _labels, _props, _values, _used, _sk, _tk any;
  declare _i, _n, _sa, _ta integer;

  _source_label := null; _source_prop := null; _source_keys := null;
  _target_label := null; _target_prop := null; _target_keys := null;
  _edge_label := null; _pg_name := null;

  -- No preamble but USE PROPERTY GRAPH <name>: the others change how
  -- names resolve or which graph is matched.
  if (not isarray (_ast) or length (_ast) <> 3 or aref (_ast, 0) <> 'PROG' or aref (_ast, 2) is not null)
    return 0;
  _proc := aref (_ast, 1);
  if (not isarray (_proc) or length (_proc) <> 4 or aref (_proc, 0) <> 'PROC')
    return 0;
  if (isarray (aref (_proc, 2)) and length (aref (_proc, 2)) > 0)
    return 0;
  _at := aref (_proc, 1);
  if (_at is not null)
    {
      if (not isarray (_at) or length (_at) < 2 or aref (_at, 0) <> 'USE_PROPERTY_AT_SCHEMA')
        return 0;
      _ref := aref (_at, 1);
      if (not isarray (_ref) or length (_ref) <> 3 or aref (_ref, 0) <> 'GRAPH_REF'
          or aref (_ref, 2) <> 'BARE' or not isstring (aref (_ref, 1)))
        return 0;
      _pg_name := aref (_ref, 1);
    }

  -- MATCH then INSERT, nothing else.
  if (not isarray (_query_ast) or aref (_query_ast, 0) <> 'QUERY')
    return 0;
  if (length (_query_ast) > 2 and isarray (aref (_query_ast, 2)) and length (aref (_query_ast, 2)) > 0)
    return 0;
  _clauses := aref (_query_ast, 1);
  if (not isarray (_clauses) or length (_clauses) <> 2)
    return 0;
  _match := aref (_clauses, 0);
  _insert := aref (_clauses, 1);
  if (not isarray (_match) or length (_match) <> 7 or aref (_match, 0) <> 'MATCH'
      or aref (_match, 1) <> 0 or length (aref (_match, 3)) <> 0 or aref (_match, 4) <> 0
      or aref (_match, 5) is not null or aref (_match, 6) is not null)
    return 0;
  if (not isarray (_insert) or length (_insert) <> 2 or aref (_insert, 0) <> 'INSERT')
    return 0;
  _mpats := aref (_match, 2);
  _ipats := aref (_insert, 1);
  if (not isarray (_mpats) or not isarray (_ipats) or length (_ipats) = 0
      or length (_mpats) <> 2 * length (_ipats))
    return 0;

  -- The node patterns: (v:Label { key: value }).
  _n := length (_mpats);
  vectorbld_init (_names);
  vectorbld_init (_labels);
  vectorbld_init (_props);
  vectorbld_init (_values);
  for (_i := 0; _i < _n; _i := _i + 1)
    {
      declare _pat, _el, _node, _pair, _expr any;
      _pat := aref (_mpats, _i);
      if (not isarray (_pat) or length (_pat) <> 2 or aref (_pat, 0) <> 'PATTERN')
        return 0;
      _el := aref (_pat, 1);
      if (not isarray (_el) or length (_el) <> 1)
        return 0;
      _node := aref (_el, 0);
      if (not isarray (_node) or length (_node) <> 4 or aref (_node, 0) <> 'NODE'
          or not isstring (aref (_node, 1))
          or not isarray (aref (_node, 2)) or length (aref (_node, 2)) <> 1
          or DB.DBA.GQL_LITERAL_VECTOR_NAME_OK (aref (_node, 2, 0)) = 0
          or not isarray (aref (_node, 3)) or length (aref (_node, 3)) <> 1)
        return 0;
      _pair := aref (_node, 3, 0);
      if (not isarray (_pair) or length (_pair) <> 2
          or DB.DBA.GQL_LITERAL_VECTOR_NAME_OK (aref (_pair, 0)) = 0
          or lower (aref (_pair, 0)) = 'iri')
        return 0;
      _expr := aref (_pair, 1);
      if (not isarray (_expr) or length (_expr) <> 2 or aref (_expr, 0) <> 'LIT'
          or not (isstring (aref (_expr, 1)) or isinteger (aref (_expr, 1))))
        return 0;
      vectorbld_acc (_names, aref (_node, 1));
      vectorbld_acc (_labels, aref (_node, 2, 0));
      vectorbld_acc (_props, aref (_pair, 0));
      vectorbld_acc (_values, aref (_expr, 1));
    }
  vectorbld_final (_names);
  vectorbld_final (_labels);
  vectorbld_final (_props);
  vectorbld_final (_values);
  for (_i := 1; _i < _n; _i := _i + 1)
    if (position (aref (_names, _i), _names) <> _i + 1)
      return 0;

  -- The edges: (s)-[:Type]->(t), each node an endpoint of exactly one
  -- (make_array starts every element at 0).
  _used := make_array (_n, 'any');
  vectorbld_init (_sk);
  vectorbld_init (_tk);
  for (_i := 0; _i < length (_ipats); _i := _i + 1)
    {
      declare _pat, _el, _s, _e, _t any;
      _pat := aref (_ipats, _i);
      if (not isarray (_pat) or length (_pat) <> 2 or aref (_pat, 0) <> 'PATTERN')
        return 0;
      _el := aref (_pat, 1);
      if (not isarray (_el) or length (_el) <> 3)
        return 0;
      _s := aref (_el, 0); _e := aref (_el, 1); _t := aref (_el, 2);
      if (not isarray (_s) or length (_s) <> 4 or aref (_s, 0) <> 'NODE' or not isstring (aref (_s, 1))
          or length (aref (_s, 2)) <> 0 or length (aref (_s, 3)) <> 0
          or not isarray (_t) or length (_t) <> 4 or aref (_t, 0) <> 'NODE' or not isstring (aref (_t, 1))
          or length (aref (_t, 2)) <> 0 or length (aref (_t, 3)) <> 0)
        return 0;
      if (not isarray (_e) or length (_e) <> 11 or aref (_e, 0) <> 'EDGE' or aref (_e, 1) is not null
          or not isarray (aref (_e, 2)) or length (aref (_e, 2)) <> 1
          or DB.DBA.GQL_LITERAL_VECTOR_NAME_OK (aref (_e, 2, 0)) = 0
          or aref (_e, 3) <> 'RIGHT' or aref (_e, 4) is not null
          or not isarray (aref (_e, 5)) or length (aref (_e, 5)) <> 0
          or aref (_e, 6) is not null or aref (_e, 7) is not null
          or aref (_e, 8) <> 0 or aref (_e, 9) <> 0 or aref (_e, 10) is not null)
        return 0;
      _sa := position (aref (_s, 1), _names) - 1;
      _ta := position (aref (_t, 1), _names) - 1;
      if (_sa < 0 or _ta < 0 or aref (_used, _sa) = 1 or aref (_used, _ta) = 1 or _sa = _ta)
        return 0;
      aset (_used, _sa, 1);
      aset (_used, _ta, 1);
      if (_i = 0)
        {
          _source_label := aref (_labels, _sa); _source_prop := aref (_props, _sa);
          _target_label := aref (_labels, _ta); _target_prop := aref (_props, _ta);
          _edge_label := aref (_e, 2, 0);
        }
      else if (_source_label <> aref (_labels, _sa) or _source_prop <> aref (_props, _sa)
          or _target_label <> aref (_labels, _ta) or _target_prop <> aref (_props, _ta)
          or _edge_label <> aref (_e, 2, 0))
        return 0;
      vectorbld_acc (_sk, aref (_values, _sa));
      vectorbld_acc (_tk, aref (_values, _ta));
    }
  vectorbld_final (_sk);
  vectorbld_final (_tk);
  _source_keys := _sk;
  _target_keys := _tk;
  return 1;
}
;

-- Runs the parsed statement on the literal route if it takes it
-- (GQL_LITERAL_VECTOR_CLASSIFY): returns 1, with _edges the edges it
-- wrote, the triple count the SPARQL route reports.  Returns 0, having
-- written nothing, to leave the statement to the SPARQL route: one it does
-- not take, one into no graph or a virtual property graph, or one where a
-- key matches two nodes (the SPARQL route then links both).  An endpoint
-- that is not there writes no edge, as the SPARQL route, whose MATCH then
-- has no solution.  _graph is the graph the parse resolved.
create procedure DB.DBA.GQL_LITERAL_VECTOR_TRY
  (inout _ast any, inout _query_ast any, in _graph varchar, out _edges integer)
{
  declare _sl, _sp, _tl, _tp, _el, _pg varchar;
  declare _sk, _tk, _ctx, _meta, _g, _sids, _tids any;
  declare _i, _n integer;
  _edges := 0;
  connection_set ('gql_literal_vector_dispatch', 'fallback');
  if (DB.DBA.GQL_LITERAL_VECTOR_CLASSIFY (_ast, _query_ast, _sl, _sp, _sk, _tl, _tp, _tk, _el, _pg) = 0)
    return 0;
  if (DB.DBA.GQL_DML_HAS_GRAPH (_graph) = 0)
    return 0;
  -- The context the translator builds for the statement: its property
  -- graph's namespaces, as USE PROPERTY GRAPH binds them.
  _ctx := DB.DBA.GQL_CTX_NEW (_graph);
  if (_pg is not null)
    {
      _meta := DB.DBA.GQL_PG_DEF_GET (_pg);
      if (_meta is not null and aref (_meta, 0) = 'virtual')
        return 0;
      DB.DBA.GQL_CTX_SET (_ctx, 'ontology_ns', DB.DBA.GQL_PG_ONTOLOGY_NS (_pg));
      DB.DBA.GQL_CTX_SET (_ctx, 'data_ns', DB.DBA.GQL_PG_DATA_NS (_pg));
      DB.DBA.GQL_CTX_SET (_ctx, 'is_property_graph', 1);
      DB.DBA.GQL_CTX_SET (_ctx, 'pg_name', _pg);
    }
  DB.DBA.GQL_VECTOR_EDGE_AUTHORIZE (_graph);
  _g := iri_to_id (_graph);
  DB.DBA.GQL_VECTOR_EDGE_LOOKUP (_g, iri_to_id (DB.DBA.GQL_TERM_URI (_ctx, _sl, 'label'), 0),
    iri_to_id (DB.DBA.GQL_TERM_URI (_ctx, _sp, 'prop'), 0), _sk, _sids);
  DB.DBA.GQL_VECTOR_EDGE_LOOKUP (_g, iri_to_id (DB.DBA.GQL_TERM_URI (_ctx, _tl, 'label'), 0),
    iri_to_id (DB.DBA.GQL_TERM_URI (_ctx, _tp, 'prop'), 0), _tk, _tids);
  _n := length (_sk);
  for (_i := 0; _i < _n; _i := _i + 1)
    if (aref (_sids, _i) is null or aref (_tids, _i) is null)
      {
        connection_set ('gql_literal_vector_dispatch', 'vector');
        return 1;
      }
  for (_i := 0; _i < _n; _i := _i + 1)
    if (not isiri_id (aref (_sids, _i)) or not isiri_id (aref (_tids, _i)))
      return 0;
  DB.DBA.GQL_VECTOR_EDGE_WRITE (_g, iri_to_id (DB.DBA.GQL_TERM_URI (_ctx, _el, 'edge')), _sids, _tids);
  _edges := _n;
  connection_set ('gql_literal_vector_dispatch', 'vector');
  return 1;
}
;

----------------------------------------------------------------------
-- Translation-only entry points
----------------------------------------------------------------------

-- _parsed, if given, is vector (AST, graph) from GQL_PARSE_STATEMENT of
-- _query, which is then not parsed again.
create procedure DB.DBA.GQL_TO_SPARQL (in _query varchar, in _graph varchar := null, in _parsed any := null)
{
  declare tokens, ast any;
  declare proc_body any;
  declare sparql_str varchar;
  declare _t0 integer;
  declare _stats_on, _log_on integer;

  _query := DB.DBA.GQL_QUERY_TEXT (_query);
  if (_graph is null and _parsed is null)
    _graph := DB.DBA.GQL_SESSION_DEFAULT_GRAPH ();

  _stats_on := DB.DBA.GQL_STATS_ENABLED ();
  _log_on := DB.DBA.GQL_LOG_ENABLED ();
  if (_stats_on or _log_on)
    _t0 := msec_time ();

  declare exit handler for sqlstate '*'
    {
      declare _elapsed integer;
      if (_stats_on or _log_on)
        _elapsed := msec_time () - _t0;
      if (_stats_on)
        DB.DBA.GQL_STATS_RECORD ('error', __SQL_STATE, _elapsed, 0);
      if (_log_on)
        DB.DBA.GQL_LOG_REQUEST (_query, null, 'error', __SQL_STATE, __SQL_MESSAGE, _elapsed, 0);
      signal (__SQL_STATE, __SQL_MESSAGE);
    };

  if (_parsed is not null)
    {
      ast := aref_set_0 (_parsed, 0);
      _graph := aref (_parsed, 1);
      goto parsed;
    }
  tokens := DB.DBA.GQL_TOKENIZE (_query);
  ast := DB.DBA.GQL_PARSE (tokens);
  proc_body := null;
  if (isarray (ast) and aref (ast, 0) = 'PROG')
    proc_body := aref (ast, 1);
  if (proc_body is not null and isarray (proc_body) and aref (proc_body, 0) = 'PROC'
      and aref (proc_body, 1) is not null)
    {
      if (isarray (aref (proc_body, 1)) and aref (aref (proc_body, 1), 0) = 'ANY_GRAPH')
        _graph := null;
      else if (isarray (aref (proc_body, 1)) and aref (aref (proc_body, 1), 0) = 'HOME_GRAPH')
        _graph := DB.DBA.GQL_HOME_GRAPH ();
      else if (isarray (aref (proc_body, 1)) and aref (aref (proc_body, 1), 0) = 'USE_PROPERTY_AT_SCHEMA')
        {
          -- USE PROPERTY GRAPH at schema: derive graph IRI from bare name
          declare pg_ref any;
          pg_ref := aref (aref (proc_body, 1), 1);
          if (isarray (pg_ref) and length (pg_ref) > 2 and aref (pg_ref, 0) = 'GRAPH_REF')
            _graph := DB.DBA.GQL_PG_GRAPH_IRI (cast (aref (pg_ref, 1) as varchar));
          else
            _graph := DB.DBA.GQL_GRAPH_REF_VALUE (pg_ref);
        }
      else
        _graph := DB.DBA.GQL_GRAPH_REF_VALUE (aref (proc_body, 1));
    }
  ast := DB.DBA.GQL_PLAN_VALIDATE_SCOPE (ast);
parsed:

  -- Optional variable-resolution diagnostics pass.
  --
  -- This pass walks the AST and reports non-fatal WARNINGS only — variable
  -- shadowing inside nested OPTIONAL (GW002) and re-use of a name across
  -- kinds (GW001, which is legitimate for e.g. `RETURN n AS n`). It is NOT
  -- the authority on variable naming: SPARQL variable names are a
  -- deterministic function of (name, kind) — ?gql_n_<name> / ?gql_e_<name> /
  -- ?gql_v_<name> — produced identically by the pass and by the translator's
  -- GQL_NODE_SPARQL_VAR / GQL_EDGE_SPARQL_VAR helpers, so there is no naming
  -- to "feed in". The real binding error — a variable used without being
  -- bound by MATCH/LET/FOR — is already enforced earlier by
  -- GQL_PLAN_VALIDATE_SCOPE (signals G3001).
  --
  -- Because these are only warnings, the pass is off by default (no per-query
  -- overhead, no log noise). A DBA can enable it for debugging with
  -- registry_set('__gql_var_diagnostics', 'on'); warnings are then logged.
  if (coalesce (registry_get ('__gql_var_diagnostics'), 'off') = 'on')
    {
      declare var_ctx any;
      declare i integer;
      var_ctx := DB.DBA.GQL_CTX_NEW (_graph);
      DB.DBA.GQL_VAR_RESOLVE_AST (ast, var_ctx);
      if (DB.DBA.GQL_CTX_HAS_ERRORS (var_ctx))
        {
          declare var_errors any;
          var_errors := DB.DBA.GQL_CTX_GET_ERRORS (var_ctx);
          for (i := 0; i < length (var_errors); i := i + 1)
            dbg_obj_print (concat ('GQL var-diagnostic [',
              aref (aref (var_errors, i), 0), '] ',
              aref (aref (var_errors, i), 1)));
        }
    }

  sparql_str := DB.DBA.GQL_TO_SPARQL_IMPL (ast, _graph);

  {
    declare _elapsed integer;
    if (_stats_on or _log_on)
      _elapsed := msec_time () - _t0;
    if (_stats_on)
      DB.DBA.GQL_STATS_RECORD ('ok', null, _elapsed, 0);
    if (_log_on)
      DB.DBA.GQL_LOG_REQUEST (_query, sparql_str, 'ok', null, null, _elapsed, 0);
  }

  return sparql_str;
}
;

create procedure DB.DBA.GQL_TO_SPARQL_PARAMS (in _query varchar, in _graph varchar := null, in _params any := null,
  in _parsed any := null)
{
  -- Parameters ($name) are bound as typed SPARQL terms DURING translation
  -- (see the 'PARAM' case in GQL_GEN_EXPR), never by string substitution.
  -- We publish the normalized name/value pairs on a connection-scoped
  -- variable that the translator reads for every (sub-)context, then clear
  -- it immediately — on success and on error — so a supplied value can
  -- neither be injected into the query text nor leak into an unrelated
  -- GQL_TO_SPARQL call on the same connection.
  declare sparql_str varchar;
  declare param_vector any;

  declare exit handler for sqlstate '*'
    {
      connection_set ('gql_bound_params', null);
      signal (__SQL_STATE, __SQL_MESSAGE);
    };

  param_vector := DB.DBA.GQL_NORMALIZE_PARAMS (_params);
  connection_set ('gql_bound_params', param_vector);
  sparql_str := DB.DBA.GQL_TO_SPARQL (_query, _graph, _parsed);
  connection_set ('gql_bound_params', null);
  return sparql_str;
}
;

----------------------------------------------------------------------
-- Execution entry points
----------------------------------------------------------------------

create procedure DB.DBA.GQL_RUN (in _query varchar, in _graph varchar := null)
{
  return DB.DBA.GQL_PARAMS (_query, _graph, null);
}
;

-- Prepared read: rows of _query with _params bound (see GQL_PREPARED_PLAN).
create procedure DB.DBA.GQL_PREPARED_PARAMS
  (in _query varchar, in _graph varchar := null, in _params any := null)
{
  declare sparql_str, state, msg varchar;
  declare execv, meta, data any;
  DB.DBA.GQL_PREPARED_PLAN (_query, _graph, _params, sparql_str, execv);
  state := '00000'; msg := '';
  exec (sparql_str, state, msg, execv, vector ('use_cache', 1), meta, data);
  if (state <> '00000')
    signal (state, msg);
  if (not isarray (data))
    return vector ();
  return data;
}
;

create procedure DB.DBA.GQL_PARAMS (in _query varchar, in _graph varchar := null, in _params any := null)
{
  declare sparql_str varchar;
  declare _parsed any;
  declare _stats_on, _log_on integer;
  declare _t0_translate, _t0_execute integer;
  declare _translate_ms integer;

  _query := DB.DBA.GQL_QUERY_TEXT (_query);
  if (_graph is null)
    _graph := DB.DBA.GQL_SESSION_DEFAULT_GRAPH ();

  _stats_on := DB.DBA.GQL_STATS_ENABLED ();
  _log_on := DB.DBA.GQL_LOG_ENABLED ();
  if (_stats_on or _log_on)
    _t0_translate := msec_time ();

  declare exit handler for sqlstate '*'
    {
      declare _exec_ms integer;
      if (_stats_on or _log_on)
        _exec_ms := msec_time () - _t0_translate;
      if (_stats_on)
        DB.DBA.GQL_STATS_RECORD ('error', __SQL_STATE, _exec_ms, 0);
      if (_log_on)
        DB.DBA.GQL_LOG_REQUEST (_query, null, 'error', __SQL_STATE, __SQL_MESSAGE, _exec_ms, 0);
      signal (__SQL_STATE, __SQL_MESSAGE);
    };

  -- Opt-in literal route (GQL_LITERAL_VECTOR_TRY).  An INSERT is parsed
  -- here once, for whichever route runs it.
  _parsed := null;
  if (DB.DBA.GQL_LITERAL_VECTOR_ENABLED ())
    {
      connection_set ('gql_literal_vector_dispatch', 'fallback');
      if (_params is null and strcasestr (_query, 'INSERT') is not null)
        {
          declare _tokens, _ast, _qast any;
          declare _g varchar;
          declare _edges integer;
          _tokens := DB.DBA.GQL_TOKENIZE (_query);
          _g := _graph;
          _ast := DB.DBA.GQL_PARSE_STATEMENT (_tokens, _g, _qast);
          if (_qast is not null and DB.DBA.GQL_LITERAL_VECTOR_TRY (_ast, _qast, _g, _edges) = 1)
            {
              if (_stats_on)
                DB.DBA.GQL_STATS_RECORD ('ok', null, msec_time () - _t0_translate, 0);
              if (_log_on)
                DB.DBA.GQL_LOG_REQUEST (_query, null, 'ok', null, 'literal-vector',
                  msec_time () - _t0_translate, 0);
              return _edges;
            }
          _parsed := vector (_ast, _g);
        }
    }

  sparql_str := DB.DBA.GQL_TO_SPARQL_PARAMS (_query, _graph, _params, _parsed);

  if (_stats_on or _log_on)
    _translate_ms := msec_time () - _t0_translate;
  else
    _translate_ms := 0;

  -- Empty SPARQL means DML-only query
  if (sparql_str is null or trim (sparql_str) = '')
    {
      if (_stats_on)
        DB.DBA.GQL_STATS_RECORD ('ok', null, _translate_ms, 0);
      if (_log_on)
        DB.DBA.GQL_LOG_REQUEST (_query, sparql_str, 'ok', null, null, _translate_ms, 0);
      return vector ();
    }

  if (_stats_on or _log_on)
    _t0_execute := msec_time ();

  if (strchr (sparql_str, ';') is not null and
      (strstr (sparql_str, 'DELETE') is not null
       or strstr (sparql_str, 'INSERT') is not null))
    {
      declare _result any;
      _result := DB.DBA.GQL_EXEC_DML_ATOMIC (sparql_str);
      if (_stats_on)
        {
          declare _exec_ms integer;
          _exec_ms := msec_time () - _t0_execute;
          DB.DBA.GQL_STATS_RECORD ('ok', null, _translate_ms, _exec_ms);
        }
      if (_log_on)
        {
          declare _exec_ms integer;
          _exec_ms := msec_time () - _t0_execute;
          DB.DBA.GQL_LOG_REQUEST (_query, sparql_str, 'ok', null, null, _translate_ms, _exec_ms);
        }
      return _result;
    }

  {
    declare _result any;
    _result := DB.DBA.GQL_EXEC_SPARQL (sparql_str);
    if (_stats_on)
      {
        declare _exec_ms integer;
        _exec_ms := msec_time () - _t0_execute;
        DB.DBA.GQL_STATS_RECORD ('ok', null, _translate_ms, _exec_ms);
      }
    if (_log_on)
      {
        declare _exec_ms integer;
        _exec_ms := msec_time () - _t0_execute;
        DB.DBA.GQL_LOG_REQUEST (_query, sparql_str, 'ok', null, null, _translate_ms, _exec_ms);
      }
    return _result;
  }
}
;

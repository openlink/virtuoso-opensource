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
--  GQL for Virtuoso - SQL Execution Handler
--
--  Copyright (C) 1998-2026 OpenLink Software
--
--  Provides the DB.DBA.GQL_EXECUTE entry point for direct SQL invocation
--  of GQL queries. Parses optional DEFINE/PREFIX preamble, then
--  dispatches into DB.DBA.GQL / DB.DBA.GQL_PARAMS.
--

----------------------------------------------------------------------
-- GQL execution handler
----------------------------------------------------------------------

-- Run SPARQL for GQL_EXECUTE and send its rows to the client.  A read
-- reuses its compiled plan (use_cache); a write's text carries its literals
-- and is compiled each time.
create procedure DB.DBA.GQL_EXEC_STREAM (in _sparql varchar, in _reuse_plan integer, in _params any := null)
{
  declare state, msg varchar;
  declare meta, data any;
  declare j, nrows integer;
  state := '00000';
  msg := '';
  if (_reuse_plan)
    exec (_sparql, state, msg, coalesce (_params, vector ()), vector ('use_cache', 1), meta, data);
  else
    exec (_sparql, state, msg, coalesce (_params, vector ()), 0, meta, data);
  if (state <> '00000')
    signal (state, msg);
  if (isarray (meta) and length (meta) > 0)
    {
      exec_result_names (meta[0]);
      if (isarray (data))
        {
          -- Each row is sent once and data is not read again, so take the
          -- row out of the vector (aref_set_0) instead of copying it.
          nrows := length (data);
          for (j := 0; j < nrows; j := j + 1)
            exec_result (aref_set_0 (data, j));
        }
    }
}
;

----------------------------------------------------------------------
-- Parameterized execution of a read (registry __gql_parameterize = 'on').
--
-- The read's data literals become bind parameters (GQL_PARAM_REWRITE), so
-- the translation is keyed by the literal-free signature and serves every
-- value of the shape, with one compiled plan.  Returns 1 if it ran the
-- statement, 0 to leave it to the inline path -- for a write or DDL (decided
-- from the parsed statement, and remembered for the signature so the next
-- such statement is not parsed twice), for a statement with no literal to
-- bind or with more than one statement may bind, and when the first run of a
-- new shape fails in any way (the inline path then runs it and reports any
-- real error).  The plan for a bound value is about 0.02 ms slower to run
-- than one for an inline literal (DB.DBA.RDF_OBJ_OF_SQLVAL runs per call),
-- which is why this is opt-in: it pays when values vary.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_EXECUTE_PZ (in _query varchar, in _default_graph varchar)
{
  declare tokens, vals, ast, query_ast, cached, names, order_, execv any;
  declare psig, pkey, sparql_str varchar;
  declare i integer;

  tokens := DB.DBA.GQL_TOKENIZE (_query);
  tokens := DB.DBA.GQL_PARAM_REWRITE (tokens, vals, psig);
  if (length (vals) = 0 or length (vals) > DB.DBA.GQL_MAX_BIND_MARKERS ())
    return 0;
  pkey := DB.DBA.GQL_TRANS_CACHE_KEY ('pz', psig, _default_graph);
  cached := DB.DBA.GQL_TRANS_CACHE_GET (pkey);
  if (cached is not null)
    {
      if (aref (cached, 0) <> 'read')
        return 0;
      execv := DB.DBA.GQL_PARAM_REORDER (vals, aref (cached, 2));
      DB.DBA.GQL_EXEC_STREAM (aref (cached, 1), 1, execv);
      return 1;
    }

  {
    -- The first run of a shape: any failure leaves the statement to the
    -- inline path.
    declare exit handler for sqlstate '*'
      {
        connection_set ('gql_marker_mode', null);
        connection_set ('gql_marker_seq', null);
        DB.DBA.GQL_TRANS_CACHE_PUT (pkey, vector ('inline'));
        return 0;
      };
    DB.DBA.GQL_TRANS_INPUTS_RESET ();
    ast := DB.DBA.GQL_PARSE_STATEMENT (tokens, _default_graph, query_ast);
    if (query_ast is null or not DB.DBA.GQL_AST_IS_READ (query_ast))
      {
        DB.DBA.GQL_TRANS_CACHE_PUT (pkey, vector ('inline'));
        return 0;
      }
    sparql_str := DB.DBA.GQL_TRANSLATE_MARKED (ast, _default_graph, 'auto', names);
    if (sparql_str is null or trim (sparql_str) = '')
      {
        DB.DBA.GQL_TRANS_CACHE_PUT (pkey, vector ('inline'));
        return 0;
      }
    -- A marker is named chr (1) || the index of its literal.
    vectorbld_init (order_);
    for (i := 0; i < length (names); i := i + 1)
      vectorbld_acc (order_, atoi (subseq (aref (names, i), 1)));
    vectorbld_final (order_);
    execv := DB.DBA.GQL_PARAM_REORDER (vals, order_);
    DB.DBA.GQL_EXEC_STREAM (sparql_str, 1, execv);
  }
  DB.DBA.GQL_TRANS_CACHE_PUT (pkey, vector ('read', sparql_str, order_));
  return 1;
}
;

-- Prepared read endpoint: stream the rows of a template with named
-- $parameters (see GQL_PREPARED_PLAN).
create procedure DB.DBA.GQL_EXECUTE_PREPARED_PARAMS
  (in _query varchar, in _default_graph varchar := null, in _params any := null)
{
  declare sparql_str varchar;
  declare execv any;
  DB.DBA.GQL_PREPARED_PLAN (_query, _default_graph, _params, sparql_str, execv);
  DB.DBA.GQL_EXEC_STREAM (sparql_str, 1, execv);
}
;

create procedure DB.DBA.GQL_EXECUTE (in _query varchar, in _default_graph varchar := null)
{
  declare tokens, ast, query_ast any;
  declare sparql_str, _ckey varchar;
  declare is_read, has_pg_ddl integer;
  declare clauses, clause any;
  declare i, n integer;

  if (_default_graph is null)
    _default_graph := DB.DBA.GQL_SESSION_DEFAULT_GRAPH ();

  -- Opt-in: one translation and plan for every literal value of a read's
  -- shape.  Returns 0 for anything it does not run (writes, DDL, no
  -- literals), which continues below.
  if (coalesce (registry_get ('__gql_parameterize'), 'off') = 'on'
      and DB.DBA.GQL_EXECUTE_PZ (_query, _default_graph) = 1)
    return;

  -- A read translated before, for this graph, runs its cached SPARQL.  The
  -- key holds the graph as given, before a USE clause in the text resolves
  -- it, so the text and that graph determine the translation.
  _ckey := DB.DBA.GQL_TRANS_CACHE_KEY ('inline', _query, _default_graph);
  sparql_str := DB.DBA.GQL_TRANS_CACHE_GET (_ckey);
  if (sparql_str is not null)
    {
      DB.DBA.GQL_EXEC_STREAM (sparql_str, 1);
      return;
    }

  -- This translation may be published to every connection: start it with
  -- the translator's connection-variable inputs cleared.
  DB.DBA.GQL_TRANS_INPUTS_RESET ();
  tokens := DB.DBA.GQL_TOKENIZE (_query);
  ast := DB.DBA.GQL_PARSE_STATEMENT (tokens, _default_graph, query_ast);
  if (query_ast is null)
    return;
  is_read := DB.DBA.GQL_AST_IS_READ (query_ast);

  -- Opt-in literal route (GQL_LITERAL_VECTOR_TRY): like the SPARQL route's
  -- update, it returns no result set.
  if (not is_read and DB.DBA.GQL_LITERAL_VECTOR_ENABLED ())
    {
      declare _edges integer;
      if (DB.DBA.GQL_LITERAL_VECTOR_TRY (ast, query_ast, _default_graph, _edges) = 1)
        return;
    }

  -- Property-graph DDL is executed as a side effect of translation (a PL
  -- call, not SPARQL text), so it must not be run again below.
  has_pg_ddl := 0;
  -- Only a single query can hold property-graph DDL, not a set operation.
  if (aref (query_ast, 0) = 'QUERY')
    clauses := aref (query_ast, 1);
  else
    clauses := vector ();
  n := length (clauses);
  for (i := 0; i < n; i := i + 1)
    {
      clause := aref (clauses, i);
      if (isarray (clause)
          and (aref (clause, 0) = 'CREATE_PROPERTY_GRAPH_V2'
               or aref (clause, 0) = 'DROP_PROPERTY_GRAPH'))
        has_pg_ddl := 1;
    }

  -- Translate to SPARQL.  For property-graph DDL this also executes the
  -- statement (CREATE/DROP VIRTUAL/PHYSICAL PROPERTY GRAPH).
  sparql_str := DB.DBA.GQL_TO_SPARQL_IMPL (ast, _default_graph);

  if (sparql_str is null or trim (sparql_str) = '')
    {
      -- Property-graph DDL already ran during translation above — do not
      -- re-run it (that would double-execute, e.g. GQ202 on CREATE).
      if (not has_pg_ddl)
        DB.DBA.GQL_RUN (_query, _default_graph);  -- INSERT-only / DML-only: execute for side effects
      exec_result_names (vector ('Status'));
      exec_result (vector ('OK'));
      return;
    }

  -- A write that translates to several SPARQL updates (a ';' and a newline
  -- between them, see GQL_SPLIT_SPARQL_STATEMENTS) runs them in turn and
  -- atomically, as GQL_RUN does; like one update, it returns no result set.
  if (not is_read and strstr (sparql_str, ';\n') is not null)
    {
      DB.DBA.GQL_EXEC_DML_ATOMIC (sparql_str);
      return;
    }

  -- Only a read's translation is kept: a write's mints node IRIs.
  if (is_read)
    DB.DBA.GQL_TRANS_CACHE_PUT (_ckey, sparql_str);
  DB.DBA.GQL_EXEC_STREAM (sparql_str, is_read);
}
;

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
--  openGQL: GQL for Virtuoso - Main Entry Points
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

create procedure DB.DBA.GQL_EXEC_SPARQL (in _sparql varchar)
{
  declare state, msg varchar;
  declare meta, data any;

  state := '00000';
  msg := '';
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
  return statements;
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
-- Translation-only entry points
----------------------------------------------------------------------

create procedure DB.DBA.GQL_TO_SPARQL (in _query varchar, in _graph varchar := null)
{
  declare tokens, ast any;
  declare proc_body any;
  declare sparql_str varchar;
  declare _t0 integer;
  declare _stats_on, _log_on integer;

  if (_graph is null)
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
      else
        _graph := DB.DBA.GQL_GRAPH_REF_VALUE (aref (proc_body, 1));
    }
  ast := DB.DBA.GQL_PLAN_VALIDATE_SCOPE (ast);

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
  -- registry_set('__opengql_var_diagnostics', 'on'); warnings are then logged.
  if (coalesce (registry_get ('__opengql_var_diagnostics'), 'off') = 'on')
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
            dbg_obj_print (concat ('openGQL var-diagnostic [',
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

create procedure DB.DBA.GQL_TO_SPARQL_PARAMS (in _query varchar, in _graph varchar := null, in _params any := null)
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
  sparql_str := DB.DBA.GQL_TO_SPARQL (_query, _graph);
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

create procedure DB.DBA.GQL_PARAMS (in _query varchar, in _graph varchar := null, in _params any := null)
{
  declare sparql_str varchar;
  declare _stats_on, _log_on integer;
  declare _t0_translate, _t0_execute integer;
  declare _translate_ms integer;

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

  sparql_str := DB.DBA.GQL_TO_SPARQL_PARAMS (_query, _graph, _params);

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

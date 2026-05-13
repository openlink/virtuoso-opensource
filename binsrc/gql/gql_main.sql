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
--    DB.DBA.GQL(query, graph?)
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

create procedure DB.DBA.GQL_EXEC_MULTI_SPARQL (in _sparql_str varchar)
{
  declare statements any;
  declare i integer;
  declare state, msg varchar;
  declare meta, data any;
  declare pos, slen, next_pos integer;

  -- Split on ';\n' boundaries between SPARQL statements
  statements := vector ();
  slen := length (_sparql_str);
  pos := 0;
  for (i := 0; i < slen; i := i + 1)
    {
      if (aref (_sparql_str, i) = 59  -- ';'
          and i + 1 < slen and aref (_sparql_str, i + 1) = 10)  -- newline
        {
          statements := vector_concat (statements, vector (trim (subseq (_sparql_str, pos, i))));
          pos := i + 2;  -- skip both ';' and '\n'
        }
    }
  if (pos < slen)
    statements := vector_concat (statements, vector (trim (subseq (_sparql_str, pos, slen))));

  for (i := 0; i < length (statements); i := i + 1)
    {
      declare stmt varchar;
      stmt := aref (statements, i);
      if (length (trim (stmt)) > 0)
        {
          state := '00000';
          exec (stmt, state, msg, vector (), 0, meta, data);
          if (state <> '00000')
            signal (state, msg);
        }
    }
  return data;
}
;

----------------------------------------------------------------------
-- Atomic DML execution: executes multi-statement DML, failing fast
-- on the first error with a clear error code.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_EXEC_DML_ATOMIC (in _sparql_str varchar)
{
  declare statements any;
  declare i integer;
  declare state, msg varchar;
  declare meta, data any;
  declare pos, slen integer;
  declare has_error integer;

  has_error := 0;

  -- Split on ';\n' boundaries between SPARQL statements
  statements := vector ();
  slen := length (_sparql_str);
  pos := 0;
  for (i := 0; i < slen; i := i + 1)
    {
      if (aref (_sparql_str, i) = 59  -- ';'
          and i + 1 < slen and aref (_sparql_str, i + 1) = 10)  -- newline
        {
          statements := vector_concat (statements, vector (trim (subseq (_sparql_str, pos, i))));
          pos := i + 1;
        }
    }
  if (pos < slen)
    statements := vector_concat (statements, vector (trim (subseq (_sparql_str, pos, slen))));

  if (length (statements) <= 1)
    {
      -- Single statement: execute directly without transaction overhead
      return DB.DBA.GQL_EXEC_MULTI_SPARQL (_sparql_str);
    }

  -- Multi-statement DML: execute sequentially within a single procedure
  -- context. Each exec() runs in its own implicit transaction in Virtuoso.
  -- We execute all statements in order; if any fails, the remaining are
  -- skipped and the error is propagated.
  for (i := 0; i < length (statements); i := i + 1)
    {
      declare stmt varchar;
      stmt := aref (statements, i);
      if (length (trim (stmt)) > 0)
        {
          state := '00000';
          exec (stmt, state, msg, vector (), 0, meta, data);
          if (state <> '00000')
            signal ('G4001', concat ('DML statement failed: ', msg));
        }
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

  if (_graph is null)
    _graph := DB.DBA.GQL_DEFAULT_GRAPH ();

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
      else
        _graph := DB.DBA.GQL_GRAPH_REF_VALUE (aref (proc_body, 1));
    }
  ast := DB.DBA.GQL_PLAN_VALIDATE_SCOPE (ast);

  -- Pre-resolve all GQL variables: populates ctx.var_map, detects
  -- shadowing in nested OPTIONAL, and warns on kind mismatches.
  -- NOTE (Phase 0): var_pass is diagnostics-only — the translator
  -- still builds its own variable bindings via GQL_NODE_SPARQL_VAR /
  -- GQL_EDGE_SPARQL_VAR. Phase 1+ should feed var_map into the
  -- translation ctx so emission helpers use pre-computed mappings.
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
          dbg_obj_print (concat ('[', aref (aref (var_errors, i), 0), '] ',
            aref (aref (var_errors, i), 1)));
      }
  }

  sparql_str := DB.DBA.GQL_TO_SPARQL_IMPL (ast, _graph);
  return sparql_str;
}
;

create procedure DB.DBA.GQL_TO_SPARQL_PARAMS (in _query varchar, in _graph varchar := null, in _params any := null)
{
  -- For now, param substitution is basic: replace ?paramName in SPARQL
  declare sparql_str varchar;
  declare param_vector any;
  declare i integer;

  sparql_str := DB.DBA.GQL_TO_SPARQL (_query, _graph);
  param_vector := DB.DBA.GQL_NORMALIZE_PARAMS (_params);

  for (i := 0; i < length (param_vector); i := i + 1)
    {
      declare pname, pval any;
      pname := aref (aref (param_vector, i), 0);
      pval := aref (aref (param_vector, i), 1);
      sparql_str := replace (sparql_str, concat ('?', pname), cast (pval as varchar));
    }
  return sparql_str;
}
;

----------------------------------------------------------------------
-- Execution entry points
----------------------------------------------------------------------

create procedure DB.DBA.GQL (in _query varchar, in _graph varchar := null)
{
  return DB.DBA.GQL_PARAMS (_query, _graph, null);
}
;

create procedure DB.DBA.GQL_PARAMS (in _query varchar, in _graph varchar := null, in _params any := null)
{
  declare sparql_str varchar;

  if (_graph is null)
    _graph := DB.DBA.GQL_DEFAULT_GRAPH ();

  sparql_str := DB.DBA.GQL_TO_SPARQL_PARAMS (_query, _graph, _params);

  -- Empty SPARQL means DML-only query
  if (sparql_str is null or trim (sparql_str) = '')
    return vector ();

  if (strchr (sparql_str, ';') is not null and
      (strstr (sparql_str, 'DELETE') is not null
       or strstr (sparql_str, 'INSERT') is not null))
    return DB.DBA.GQL_EXEC_DML_ATOMIC (sparql_str);

  return DB.DBA.GQL_EXEC_SPARQL (sparql_str);
}
;

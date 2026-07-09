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
--  openGQL: GQL for Virtuoso - SQL Execution Handler
--
--  Copyright (C) 1998-2026 OpenLink Software
--
--  Provides the DB.DBA.OPENGQL_EXEC entry point for direct SQL invocation
--  of GQL queries. Parses optional DEFINE/PREFIX preamble, then
--  dispatches into DB.DBA.GQL / DB.DBA.GQL_PARAMS.
--

----------------------------------------------------------------------
-- OPENGQL execution handler
----------------------------------------------------------------------

create procedure DB.DBA."OPENGQL" (in _query varchar, in _default_graph varchar := null)
{
  return DB.DBA.OPENGQL_EXEC (_query, _default_graph);
}
;

create procedure DB.DBA.OPENGQL_PARAMS (in _query varchar, in _default_graph varchar := null, in _params any := null)
{
  return DB.DBA.GQL_PARAMS (_query, _default_graph, _params);
}
;

create procedure DB.DBA.OPENGQL_EXEC (in _query varchar, in _default_graph varchar := null)
{
  declare tokens, ast, query_ast any;
  declare proc_body any;
  declare sparql_str varchar;
  declare state, msg varchar;
  declare meta, data any;
  declare has_return integer;
  declare clauses, clause any;
  declare i, n integer;

  if (_default_graph is null)
    _default_graph := DB.DBA.GQL_DEFAULT_GRAPH ();

  -- Tokenize
  tokens := DB.DBA.GQL_TOKENIZE (_query);

  -- Parse
  ast := DB.DBA.GQL_PARSE (tokens);
  proc_body := null;
  if (isarray (ast) and aref (ast, 0) = 'PROG')
    proc_body := aref (ast, 1);
  if (proc_body is not null and isarray (proc_body) and aref (proc_body, 0) = 'PROC'
      and aref (proc_body, 1) is not null)
    _default_graph := DB.DBA.GQL_GRAPH_REF_VALUE (aref (proc_body, 1));

  -- Validate scope
  ast := DB.DBA.GQL_PLAN_VALIDATE_SCOPE (ast);
  query_ast := ast;

  -- Navigate to QUERY
  if (aref (query_ast, 0) = 'PROG')
    {
      if (aref (query_ast, 1) is not null and isarray (aref (query_ast, 1))
          and aref (aref (query_ast, 1), 0) = 'PROC')
        query_ast := aref (aref (query_ast, 1), 3);
      else
        return;
    }

  if (query_ast is null or not isarray (query_ast) or aref (query_ast, 0) <> 'QUERY')
    return;

  -- Check for RETURN clause
  has_return := 0;
  clauses := aref (query_ast, 1);
  n := length (clauses);
  for (i := 0; i < n; i := i + 1)
    {
      clause := aref (clauses, i);
      if (isarray (clause) and aref (clause, 0) = 'RETURN')
        has_return := 1;
    }

  -- Translate to SPARQL
  sparql_str := DB.DBA.GQL_TO_SPARQL_IMPL (ast, _default_graph);

  if (sparql_str is null or trim (sparql_str) = '')
    {
      -- INSERT-only or DML-only: execute for side effects
      DB.DBA.GQL_RUN (_query, _default_graph);
      exec_result_names (vector ('Status'));
      exec_result (vector ('OK'));
      return;
    }

  -- Execute SPARQL
  state := '00000';
  msg := '';
  exec (sparql_str, state, msg, vector (), 0, meta, data);

  if (state <> '00000')
    signal (state, msg);

  return data;
}
;

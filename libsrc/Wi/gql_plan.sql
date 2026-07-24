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
--  openGQL: GQL for Virtuoso - Scope Validation
--
--  Copyright (C) 1998-2026 OpenLink Software
--
--  Validates variable bindings across GQL clauses.
--  Emits G3001 (binding error) / G3002 (type error) diagnostics.
--

----------------------------------------------------------------------
-- Vector helpers for scope tracking
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PLAN_VEC_HAS (in _vec any, in _item varchar)
{
  declare i integer;
  for (i := 0; i < length (_vec); i := i + 1)
    { if (aref (_vec, i) = _item) return 1; }
  return 0;
}
;

create procedure DB.DBA.GQL_PLAN_VEC_ADD (in _vec any, in _item varchar)
{
  if (_item is null or _item = '')
    return _vec;
  if (DB.DBA.GQL_PLAN_VEC_HAS (_vec, _item))
    return _vec;
  return vector_concat (_vec, vector (_item));
}
;

create procedure DB.DBA.GQL_PLAN_VEC_MERGE (in _a any, in _b any)
{
  declare i integer;
  for (i := 0; i < length (_b); i := i + 1)
    _a := DB.DBA.GQL_PLAN_VEC_ADD (_a, aref (_b, i));
  return _a;
}
;

----------------------------------------------------------------------
-- Variable collectors from AST
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PLAN_COLLECT_PATTERN_VARS (in _pattern any, in _vars any)
{
  declare ptype varchar;
  declare elems any;
  declare i integer;

  if (not isarray (_pattern))
    return _vars;

  ptype := aref (_pattern, 0);
  if (ptype = 'PATH' or ptype = 'PATHVAR')
    {
      _vars := DB.DBA.GQL_PLAN_VEC_ADD (_vars, aref (_pattern, 1));
      return DB.DBA.GQL_PLAN_COLLECT_PATTERN_VARS (vector ('PATTERN', aref (_pattern, 2)), _vars);
    }

  if (ptype <> 'PATTERN')
    return _vars;

  elems := aref (_pattern, 1);
  for (i := 0; i < length (elems); i := i + 1)
    {
      declare elem, etype any;
      elem := aref (elems, i);
      if (not isarray (elem)) goto next_elem;
      etype := aref (elem, 0);
      if (etype = 'NODE')
        _vars := DB.DBA.GQL_PLAN_VEC_ADD (_vars, aref (elem, 1));
      else if (etype = 'EDGE')
        _vars := DB.DBA.GQL_PLAN_VEC_ADD (_vars, aref (elem, 1));
    next_elem:;
    }
  return _vars;
}
;

create procedure DB.DBA.GQL_PLAN_COLLECT_CLAUSE_VARS (in _clause any, in _vars any)
{
  declare ctype varchar;
  declare i integer;

  if (not isarray (_clause))
    return _vars;

  ctype := aref (_clause, 0);
  if (ctype = 'MATCH')
    {
      declare patterns any;
      patterns := aref (_clause, 2);
      for (i := 0; i < length (patterns); i := i + 1)
        _vars := DB.DBA.GQL_PLAN_COLLECT_PATTERN_VARS (aref (patterns, i), _vars);
    }
  else if (ctype = 'INSERT')
    {
      declare ins_patterns any;
      ins_patterns := aref (_clause, 1);
      for (i := 0; i < length (ins_patterns); i := i + 1)
        _vars := DB.DBA.GQL_PLAN_COLLECT_PATTERN_VARS (aref (ins_patterns, i), _vars);
    }
  else if (ctype = 'CONSTRUCT')
    {
      declare construct_patterns any;
      construct_patterns := aref (_clause, 1);
      for (i := 0; i < length (construct_patterns); i := i + 1)
        _vars := DB.DBA.GQL_PLAN_COLLECT_PATTERN_VARS (aref (construct_patterns, i), _vars);
    }
  else if (ctype = 'LET')
    _vars := DB.DBA.GQL_PLAN_VEC_ADD (_vars, aref (_clause, 1));
  else if (ctype = 'LET_GRAPH')
    _vars := DB.DBA.GQL_PLAN_VEC_ADD (_vars, aref (_clause, 1));
  else if (ctype = 'LET_TABLE')
    _vars := DB.DBA.GQL_PLAN_VEC_ADD (_vars, aref (_clause, 1));
  else if (ctype = 'FOR')
    _vars := DB.DBA.GQL_PLAN_VEC_ADD (_vars, aref (_clause, 1));
  else if (ctype = 'SERVICE')
    {
      declare svc_query, svc_clauses any;
      declare j integer;
      declare has_return integer;
      declare svc_return any;
      declare inner_bound any;

      svc_query := aref (_clause, 2);
      if (isarray (svc_query) and aref (svc_query, 0) = 'QUERY')
        {
          svc_clauses := aref (svc_query, 1);
          inner_bound := vector ();
          has_return := 0;
          svc_return := null;

          for (j := 0; j < length (svc_clauses); j := j + 1)
            {
              declare svc_clause any;
              declare svc_ctype varchar;
              svc_clause := aref (svc_clauses, j);
              if (not isarray (svc_clause)) goto next_svc_clause;
              svc_ctype := aref (svc_clause, 0);
              if (svc_ctype = 'RETURN')
                { has_return := 1; svc_return := svc_clause; }
              else
                inner_bound := DB.DBA.GQL_PLAN_COLLECT_CLAUSE_VARS (svc_clause, inner_bound);
            next_svc_clause:;
            }

          if (has_return)
            _vars := DB.DBA.GQL_PLAN_VEC_MERGE (_vars,
              DB.DBA.GQL_PLAN_COLLECT_RETURN_OUTPUT_VARS (svc_return, inner_bound));
          else
            _vars := DB.DBA.GQL_PLAN_VEC_MERGE (_vars, inner_bound);
        }
      else if (isarray (svc_query))
        _vars := DB.DBA.GQL_PLAN_COLLECT_CLAUSE_VARS (svc_query, _vars);
    }

  return _vars;
}
;

create procedure DB.DBA.GQL_PLAN_COLLECT_RETURN_OUTPUT_VARS (in _return_clause any, in _inner_bound any)
{
  declare vars any;
  declare items any;
  declare i integer;

  vars := vector ();
  if (not isarray (_return_clause))
    return vars;
  if (aref (_return_clause, 0) <> 'RETURN')
    return vars;

  items := aref (_return_clause, 2);
  for (i := 0; i < length (items); i := i + 1)
    {
      declare item, expr, alias any;
      item := aref (items, i);
      expr := aref (item, 1);
      alias := aref (item, 2);
      if (isarray (expr) and aref (expr, 0) = 'VAR' and aref (expr, 1) = '*')
        vars := DB.DBA.GQL_PLAN_VEC_MERGE (vars, _inner_bound);
      else if (alias is not null)
        vars := DB.DBA.GQL_PLAN_VEC_ADD (vars, alias);
      else if (isarray (expr) and aref (expr, 0) = 'VAR')
        vars := DB.DBA.GQL_PLAN_VEC_ADD (vars, aref (expr, 1));
    }
  return vars;
}
;

create procedure DB.DBA.GQL_PLAN_COLLECT_PATTERN_EXPR_VARS (in _pattern any, in _vars any)
{
  declare elems, elem any;
  declare i, j integer;
  declare etype varchar;

  if (not isarray (_pattern))
    return _vars;
  elems := aref (_pattern, 1);
  for (i := 0; i < length (elems); i := i + 1)
    {
      elem := aref (elems, i);
      if (not isarray (elem)) goto cpe_next_elem;
      etype := aref (elem, 0);
      if (etype = 'NODE')
        {
          declare nprops any;
          nprops := aref (elem, 3);
          for (j := 0; j < length (nprops); j := j + 1)
            _vars := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (aref (nprops, j), 1), _vars);
        }
      else if (etype = 'EDGE')
        {
          declare eprops any;
          eprops := aref (elem, 5);
          for (j := 0; j < length (eprops); j := j + 1)
            _vars := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (aref (eprops, j), 1), _vars);
        }
    cpe_next_elem:;
    }
  return _vars;
}
;

create procedure DB.DBA.GQL_PLAN_QUERY_OUTPUT_VARS (in _query_ast any)
{
  declare clauses any;
  declare inner_bound any;
  declare has_return integer;
  declare return_clause any;
  declare i integer;

  inner_bound := vector ();
  has_return := 0;
  return_clause := null;

  if (not isarray (_query_ast) or aref (_query_ast, 0) <> 'QUERY')
    return inner_bound;

  clauses := aref (_query_ast, 1);
  for (i := 0; i < length (clauses); i := i + 1)
    {
      declare clause, ctype any;
      clause := aref (clauses, i);
      if (not isarray (clause)) goto next_query_clause;
      ctype := aref (clause, 0);
      if (ctype = 'RETURN')
        { has_return := 1; return_clause := clause; }
      else
        inner_bound := DB.DBA.GQL_PLAN_COLLECT_CLAUSE_VARS (clause, inner_bound);
    next_query_clause:;
    }

  if (has_return)
    return DB.DBA.GQL_PLAN_COLLECT_RETURN_OUTPUT_VARS (return_clause, inner_bound);

  return inner_bound;
}
;

create procedure DB.DBA.GQL_PLAN_COLLECT_CONTAINS_OPTION_VARS (in _expr any, in _vars any)
{
  declare etype varchar;
  declare i integer;

  if (not isarray (_expr))
    return _vars;

  etype := aref (_expr, 0);
  if (etype = 'CONTAINS')
    {
      declare opts any;
      opts := aref (_expr, 3);
      for (i := 0; i < length (opts); i := i + 1)
        {
          declare opt any;
          opt := aref (opts, i);
          if (isarray (opt) and length (opt) > 1
              and isarray (aref (opt, 1)) and aref (aref (opt, 1), 0) = 'VAR')
            _vars := DB.DBA.GQL_PLAN_VEC_ADD (_vars, aref (aref (opt, 1), 1));
        }
      _vars := DB.DBA.GQL_PLAN_COLLECT_CONTAINS_OPTION_VARS (aref (_expr, 1), _vars);
      return DB.DBA.GQL_PLAN_COLLECT_CONTAINS_OPTION_VARS (aref (_expr, 2), _vars);
    }
  if (etype = 'PROP')
    return DB.DBA.GQL_PLAN_COLLECT_CONTAINS_OPTION_VARS (aref (_expr, 1), _vars);
  if (etype = 'BINOP')
    {
      _vars := DB.DBA.GQL_PLAN_COLLECT_CONTAINS_OPTION_VARS (aref (_expr, 2), _vars);
      return DB.DBA.GQL_PLAN_COLLECT_CONTAINS_OPTION_VARS (aref (_expr, 3), _vars);
    }
  if (etype = 'UNOP')
    return DB.DBA.GQL_PLAN_COLLECT_CONTAINS_OPTION_VARS (aref (_expr, 2), _vars);
  return _vars;
}
;

create procedure DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (in _expr any, in _vars any)
{
  declare etype varchar;
  declare i integer;

  if (not isarray (_expr))
    return _vars;

  etype := aref (_expr, 0);
  if (etype = 'VAR')
    return DB.DBA.GQL_PLAN_VEC_ADD (_vars, aref (_expr, 1));
  if (etype = 'PROP')
    return DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (_expr, 1), _vars);
  if (etype = 'BINOP')
    {
      _vars := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (_expr, 2), _vars);
      return DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (_expr, 3), _vars);
    }
  if (etype = 'CONTAINS')
    {
      _vars := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (_expr, 1), _vars);
      return DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (_expr, 2), _vars);
    }
  if (etype = 'UNOP')
    return DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (_expr, 2), _vars);
  if (etype = 'FUNC' or etype = 'FUNC_DISTINCT')
    {
      declare args any;
      declare fname varchar;
      if (etype = 'FUNC_DISTINCT')
        args := aref (_expr, 2);
      else
        args := aref (_expr, 3);
      fname := lower (cast (aref (_expr, 1) as varchar));
      if (fname = 'degree_centrality' or fname = 'eigenvector_centrality'
          or fname = 'closeness_centrality' or fname = 'betweenness_centrality')
        {
          if (length (args) > 0)
            _vars := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (args, 0), _vars);
          return _vars;
        }
      for (i := 0; i < length (args); i := i + 1)
        _vars := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (args, i), _vars);
      return _vars;
    }
  if (etype = 'ISNULL')
    return DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (_expr, 1), _vars);
  if (etype = 'INEXPR')
    {
      _vars := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (_expr, 1), _vars);
      return DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (_expr, 2), _vars);
    }
  if (etype = 'LIST')
    {
      declare elems any;
      elems := aref (_expr, 1);
      for (i := 0; i < length (elems); i := i + 1)
        _vars := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (elems, i), _vars);
      return _vars;
    }
  if (etype = 'CASEEXPR')
    {
      declare whens, else_expr any;
      if (aref (_expr, 1) is not null)
        _vars := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (_expr, 1), _vars);
      whens := aref (_expr, 2);
      for (i := 0; i < length (whens); i := i + 1)
        {
          declare w any;
          w := aref (whens, i);
          _vars := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (w, 0), _vars);
          _vars := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (w, 1), _vars);
        }
      if (aref (_expr, 3) is not null)
        _vars := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (_expr, 3), _vars);
      return _vars;
    }
  if (etype = 'SLICE')
    {
      _vars := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (_expr, 1), _vars);
      if (aref (_expr, 2) is not null)
        _vars := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (_expr, 2), _vars);
      if (aref (_expr, 3) is not null)
        _vars := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (_expr, 3), _vars);
      return _vars;
    }
  if (etype = 'TYPEDLIT' or etype = 'TYPEDLIT_IRI' or etype = 'PATTERNPRED' or etype = 'EXISTS_SUBQUERY')
    return _vars;

  return _vars;
}
;

----------------------------------------------------------------------
-- Main scope validator
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PLAN_VALIDATE_SCOPE (in _ast any)
{
  declare node_type varchar;
  declare clauses, clause, ctype any;
  declare bound_vars any;
  declare i, j integer;

  if (not isarray (_ast))
    return _ast;

  node_type := aref (_ast, 0);
  -- Navigate PROG → PROC → QUERY
  if (node_type = 'PROG')
    {
      declare proc_body any;
      proc_body := aref (_ast, 1);
      if (proc_body is not null)
        return vector ('PROG', DB.DBA.GQL_PLAN_VALIDATE_SCOPE (proc_body), aref (_ast, 2));
      return _ast;
    }
  if (node_type = 'PROC')
    {
      declare stmt_block any;
      stmt_block := aref (_ast, 3);
      if (stmt_block is not null)
        return vector ('PROC', aref (_ast, 1), aref (_ast, 2), DB.DBA.GQL_PLAN_VALIDATE_SCOPE (stmt_block));
      return _ast;
    }
  if (node_type <> 'QUERY')
    return _ast;

  clauses := aref (_ast, 1);
  bound_vars := vector ();

  -- Pass 1: Collect bound variables from MATCH, LET, FOR, INSERT
  for (i := 0; i < length (clauses); i := i + 1)
    {
      clause := aref (clauses, i);
      if (not isarray (clause)) goto next_clause;
      ctype := aref (clause, 0);
      if (ctype = 'MATCH' or ctype = 'INSERT' or ctype = 'LET' or ctype = 'LET_GRAPH'
          or ctype = 'LET_TABLE' or ctype = 'FOR'
          or ctype = 'SERVICE')
        bound_vars := DB.DBA.GQL_PLAN_COLLECT_CLAUSE_VARS (clause, bound_vars);
      else if (ctype = 'WHERE' or ctype = 'FILTER')
        bound_vars := DB.DBA.GQL_PLAN_COLLECT_CONTAINS_OPTION_VARS (aref (clause, 1), bound_vars);
    next_clause:;
    }

  if (length (bound_vars) = 0)
    {
      for (i := 0; i < length (clauses); i := i + 1)
        {
          clause := aref (clauses, i);
          if (isarray (clause) and aref (clause, 0) = 'CONSTRUCT')
            bound_vars := DB.DBA.GQL_PLAN_COLLECT_CLAUSE_VARS (clause, bound_vars);
        }
    }

  -- Pass 2: Validate WHERE, FILTER, RETURN, CONSTRUCT, DESCRIBE, SET, REMOVE, DELETE
  for (i := 0; i < length (clauses); i := i + 1)
    {
      declare used_vars, uv any;
      clause := aref (clauses, i);
      if (not isarray (clause)) goto next_check;
      ctype := aref (clause, 0);

      if (ctype = 'WHERE' or ctype = 'FILTER')
        {
          used_vars := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (clause, 1), vector ());
          for (j := 0; j < length (used_vars); j := j + 1)
            {
              uv := aref (used_vars, j);
              if (not DB.DBA.GQL_PLAN_VEC_HAS (bound_vars, uv))
                signal ('G3001', sprintf ('Variable ''%s'' used in %s is not bound by any MATCH, LET, or FOR clause', uv, ctype));
            }
        }
      else if (ctype = 'RETURN')
        {
          declare ret_items, k integer;
          declare return_visible any;
          ret_items := aref (clause, 2);
          used_vars := vector ();
          for (k := 0; k < length (ret_items); k := k + 1)
            used_vars := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (aref (ret_items, k), 1), used_vars);
          return_visible := DB.DBA.GQL_PLAN_COLLECT_RETURN_OUTPUT_VARS (clause, bound_vars);
          for (j := 0; j < length (used_vars); j := j + 1)
            {
              uv := aref (used_vars, j);
              if (uv = '*') goto ret_next_check;
              if (not DB.DBA.GQL_PLAN_VEC_HAS (bound_vars, uv))
                signal ('G3001', sprintf ('Variable ''%s'' used in RETURN is not bound by any MATCH, LET, or FOR clause', uv));
            }
          -- Also check ORDER BY expressions
          if (length (clause) > 3)
            {
              declare order_items any;
              order_items := aref (clause, 3);
              for (k := 0; k < length (order_items); k := k + 1)
                {
                  declare ov, oi integer;
                  ov := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (aref (order_items, k), 1), vector ());
                  for (oi := 0; oi < length (ov); oi := oi + 1)
                    {
                      uv := aref (ov, oi);
                      if (uv = '*') goto order_next_check;
                      if (not DB.DBA.GQL_PLAN_VEC_HAS (bound_vars, uv)
                          and not DB.DBA.GQL_PLAN_VEC_HAS (return_visible, uv))
                        signal ('G3001', sprintf ('Variable ''%s'' used in RETURN is not bound by any MATCH, LET, or FOR clause', uv));
                    }
                order_next_check:;
                }
            }
        ret_next_check:;
        }
      else if (ctype = 'CONSTRUCT')
        {
          declare construct_patterns any;
          declare cpi integer;
          construct_patterns := aref (clause, 1);
          used_vars := vector ();
          for (cpi := 0; cpi < length (construct_patterns); cpi := cpi + 1)
            {
              used_vars := DB.DBA.GQL_PLAN_COLLECT_PATTERN_VARS (aref (construct_patterns, cpi), used_vars);
              used_vars := DB.DBA.GQL_PLAN_COLLECT_PATTERN_EXPR_VARS (aref (construct_patterns, cpi), used_vars);
            }
          for (j := 0; j < length (used_vars); j := j + 1)
            {
              uv := aref (used_vars, j);
              if (uv is not null and not DB.DBA.GQL_PLAN_VEC_HAS (bound_vars, uv))
                signal ('G3001', sprintf ('Variable ''%s'' used in CONSTRUCT is not bound by any MATCH, LET, or FOR clause', uv));
            }
        }
      else if (ctype = 'DESCRIBE')
        {
          declare desc_items any;
          desc_items := aref (clause, 1);
          used_vars := vector ();
          for (j := 0; j < length (desc_items); j := j + 1)
            used_vars := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (desc_items, j), used_vars);
          for (j := 0; j < length (used_vars); j := j + 1)
            {
              uv := aref (used_vars, j);
              if (uv = '*') goto describe_next_check;
              if (not DB.DBA.GQL_PLAN_VEC_HAS (bound_vars, uv))
                signal ('G3001', sprintf ('Variable ''%s'' used in DESCRIBE is not bound by any MATCH, LET, FOR, or CONSTRUCT clause', uv));
            describe_next_check:;
            }
        }
      else if (ctype = 'SET' or ctype = 'REMOVE')
        {
          declare set_items any;
          set_items := aref (clause, 1);
          for (j := 0; j < length (set_items); j := j + 1)
            {
              declare si, stype any;
              si := aref (set_items, j);
              stype := aref (si, 0);
              if (stype = 'SETPROP' or stype = 'RMPROP')
                used_vars := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (si, 1), vector ());
              else if (stype = 'SETALL')
                { uv := aref (si, 1); if (not DB.DBA.GQL_PLAN_VEC_HAS (bound_vars, uv)) signal ('G3001', sprintf ('Variable ''%s'' in SET/REMOVE is not bound', uv)); }
              else if (stype = 'SETLABEL' or stype = 'RMLABEL')
                { uv := aref (si, 1); if (not DB.DBA.GQL_PLAN_VEC_HAS (bound_vars, uv)) signal ('G3001', sprintf ('Variable ''%s'' in SET/REMOVE is not bound', uv)); }
            }
        }
      else if (ctype = 'DELETE')
        {
          declare del_items any;
          del_items := aref (clause, 2);
          for (j := 0; j < length (del_items); j := j + 1)
            {
              used_vars := DB.DBA.GQL_PLAN_COLLECT_EXPR_VARS (aref (del_items, j), vector ());
              declare k integer;
              for (k := 0; k < length (used_vars); k := k + 1)
                { uv := aref (used_vars, k); if (not DB.DBA.GQL_PLAN_VEC_HAS (bound_vars, uv)) signal ('G3001', sprintf ('Variable ''%s'' in DELETE is not bound', uv)); }
            }
        }

    next_check:;
    }
  return _ast;
}
;

----------------------------------------------------------------------
-- Optional-feature gate
----------------------------------------------------------------------

create procedure DB.DBA.GQL_FEATURES_SUPPORTED ()
{
  return vector ('GG01');
}
;

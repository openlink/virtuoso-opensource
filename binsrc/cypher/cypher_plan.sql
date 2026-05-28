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
--  openCypher: OpenCypher for Virtuoso - Logical Plan Scaffolding
--
--  This module normalizes the parser AST into ordered row-pipeline
--  operators. It is intentionally non-executing for now; translation still
--  uses the existing AST path until the plan operators are complete.
--

create procedure DB.DBA.CYP_PLAN_OPERATOR (in _op varchar, in _payload any)
{
  return vector ('PLAN_OP', _op, _payload);
}
;

create procedure DB.DBA.CYP_PLAN_VEC_HAS (in _vec any, in _item varchar)
{
  declare i integer;

  for (i := 0; i < length (_vec); i := i + 1)
    {
      if (aref (_vec, i) = _item)
        return 1;
    }
  return 0;
}
;

create procedure DB.DBA.CYP_PLAN_VEC_ADD (in _vec any, in _item varchar)
{
  if (_item is null or _item = '')
    return _vec;
  if (DB.DBA.CYP_PLAN_VEC_HAS (_vec, _item))
    return _vec;
  return vector_concat (_vec, vector (_item));
}
;

-- Merge two scope vectors
create procedure DB.DBA.CYP_PLAN_VEC_MERGE (in _a any, in _b any)
{
  declare i integer;
  for (i := 0; i < length (_b); i := i + 1)
    _a := DB.DBA.CYP_PLAN_VEC_ADD (_a, aref (_b, i));
  return _a;
}
;

create procedure DB.DBA.CYP_PLAN_COLLECT_PATTERN_VARS (in _pattern any, in _vars any)
{
  declare ptype varchar;
  declare elems any;
  declare i integer;
  declare elem any;
  declare etype varchar;

  if (not isarray (_pattern))
    return _vars;

  ptype := aref (_pattern, 0);
  if (ptype = 'PATHVAR')
    {
      _vars := DB.DBA.CYP_PLAN_VEC_ADD (_vars, aref (_pattern, 1));
      return DB.DBA.CYP_PLAN_COLLECT_PATTERN_VARS (aref (_pattern, 2), _vars);
    }

  if (ptype <> 'PATTERN')
    return _vars;

  elems := aref (_pattern, 1);
  for (i := 0; i < length (elems); i := i + 1)
    {
      elem := aref (elems, i);
      etype := aref (elem, 0);
      if (etype = 'NODE')
        _vars := DB.DBA.CYP_PLAN_VEC_ADD (_vars, aref (elem, 1));
      else if (etype = 'REL')
        _vars := DB.DBA.CYP_PLAN_VEC_ADD (_vars, aref (elem, 1));
    }
  return _vars;
}
;

create procedure DB.DBA.CYP_PLAN_COLLECT_MATCH_VARS (in _clause any, in _vars any)
{
  declare patterns any;
  declare i integer;

  patterns := aref (_clause, 2);
  for (i := 0; i < length (patterns); i := i + 1)
    _vars := DB.DBA.CYP_PLAN_COLLECT_PATTERN_VARS (aref (patterns, i), _vars);
  return _vars;
}
;

-- CREATE AST is ('CREATE', patterns, graph_expr) — patterns at index 1
create procedure DB.DBA.CYP_PLAN_COLLECT_CREATE_VARS (in _clause any, in _vars any)
{
  declare patterns any;
  declare i integer;

  patterns := aref (_clause, 1);
  for (i := 0; i < length (patterns); i := i + 1)
    _vars := DB.DBA.CYP_PLAN_COLLECT_PATTERN_VARS (aref (patterns, i), _vars);
  return _vars;
}
;

create procedure DB.DBA.CYP_PLAN_COLLECT_RETURN_VARS (in _items any)
{
  declare vars any;
  declare i integer;
  declare item, expr any;

  vars := vector ();
  for (i := 0; i < length (_items); i := i + 1)
    {
      item := aref (_items, i);
      expr := aref (item, 1);
      if (isarray (expr) and aref (expr, 0) = 'VAR')
        {
          if (aref (item, 2) is not null)
            vars := DB.DBA.CYP_PLAN_VEC_ADD (vars, aref (item, 2));
          else
            vars := DB.DBA.CYP_PLAN_VEC_ADD (vars, aref (expr, 1));
        }
      else if (aref (item, 2) is not null)
        vars := DB.DBA.CYP_PLAN_VEC_ADD (vars, aref (item, 2));
    }
  return vars;
}
;

create procedure DB.DBA.CYP_PLAN_SCOPE_TRACE (in _plan any)
{
  declare ops, trace, vars any;
  declare i integer;
  declare op, opname, payload any;

  if (not isarray (_plan) or aref (_plan, 0) <> 'PLAN')
    signal ('CY082', 'Expected PLAN root for scope tracing');

  ops := aref (_plan, 1);
  trace := vector ();
  vars := vector ();

  for (i := 0; i < length (ops); i := i + 1)
    {
      op := aref (ops, i);
      opname := aref (op, 1);
      payload := aref (op, 2);

      if (opname = 'MATCH' or opname = 'OPTIONAL_MATCH')
        vars := DB.DBA.CYP_PLAN_COLLECT_MATCH_VARS (payload, vars);
      else if (opname = 'CREATE' or opname = 'MERGE')
        vars := DB.DBA.CYP_PLAN_COLLECT_CREATE_VARS (payload, vars);
      else if (opname = 'UNWIND')
        vars := DB.DBA.CYP_PLAN_VEC_ADD (vars, aref (payload, 2));
      else if (opname = 'BIND')
        vars := DB.DBA.CYP_PLAN_VEC_ADD (vars, aref (payload, 2));
      else if (opname = 'VALUES')
        vars := DB.DBA.CYP_PLAN_VEC_ADD (vars, aref (payload, 1));
      else if (opname = 'PROJECT')
        vars := DB.DBA.CYP_PLAN_COLLECT_RETURN_VARS (aref (payload, 2));
      else if (opname = 'RETURN')
        vars := DB.DBA.CYP_PLAN_COLLECT_RETURN_VARS (aref (payload, 2));
      else if (opname = 'CALL')
        {
          -- CALL clause yields variables from its YIELD items
          declare yield_items any;
          declare j integer;
          declare yield_item any;
          yield_items := aref (payload, 3);
          if (yield_items is not null)
            {
              for (j := 0; j < length (yield_items); j := j + 1)
                {
                  yield_item := aref (yield_items, j);
                  if (aref (yield_item, 0) = 'YIELDSTAR')
                    {
                      vars := DB.DBA.CYP_PLAN_VEC_ADD (vars, '*');
                    }
                  else if (aref (yield_item, 0) = 'YIELDITEM')
                    {
                      declare alias_name varchar;
                      alias_name := aref (yield_item, 2);
                      if (alias_name is null)
                        alias_name := aref (yield_item, 1);
                      vars := DB.DBA.CYP_PLAN_VEC_ADD (vars, alias_name);
                    }
                }
            }
        }

      trace := vector_concat (trace, vector (vector (opname, vars)));
    }

  return vector ('SCOPE_TRACE', trace);
}
;

create procedure DB.DBA.CYP_PLAN_EXPR_VARS (in _expr any, in _vars any)
{
  declare etype varchar;
  declare i integer;
  declare args any;

  if (not isarray (_expr))
    return _vars;

  etype := aref (_expr, 0);
  if (etype = 'VAR')
    return DB.DBA.CYP_PLAN_VEC_ADD (_vars, aref (_expr, 1));

  if (etype = 'PROP')
    return DB.DBA.CYP_PLAN_EXPR_VARS (aref (_expr, 1), _vars);

  if (etype = 'BINOP' or etype = 'STROP')
    {
      _vars := DB.DBA.CYP_PLAN_EXPR_VARS (aref (_expr, 2), _vars);
      return DB.DBA.CYP_PLAN_EXPR_VARS (aref (_expr, 3), _vars);
    }

  if (etype = 'UNOP' or etype = 'ISNULL')
    return DB.DBA.CYP_PLAN_EXPR_VARS (aref (_expr, 2), _vars);

  if (etype = 'INEXPR')
    {
      _vars := DB.DBA.CYP_PLAN_EXPR_VARS (aref (_expr, 1), _vars);
      return DB.DBA.CYP_PLAN_EXPR_VARS (aref (_expr, 2), _vars);
    }

  if (etype = 'FUNC')
    {
      declare fname varchar;
      args := aref (_expr, 3);
      fname := lower (cast (aref (_expr, 1) as varchar));
      if (fname = 'degree_centrality' or fname = 'weighted_degree_centrality'
          or fname = 'eigenvector_centrality' or fname = 'closeness_centrality'
          or fname = 'betweenness_centrality')
        {
          if (length (args) > 0)
            _vars := DB.DBA.CYP_PLAN_EXPR_VARS (aref (args, 0), _vars);
          return _vars;
        }
      for (i := 0; i < length (args); i := i + 1)
        _vars := DB.DBA.CYP_PLAN_EXPR_VARS (aref (args, i), _vars);
      return _vars;
    }

  if (etype = 'LIST')
    {
      args := aref (_expr, 1);
      for (i := 0; i < length (args); i := i + 1)
        _vars := DB.DBA.CYP_PLAN_EXPR_VARS (aref (args, i), _vars);
      return _vars;
    }

  return _vars;
}
;

-- Recursively collect variables from pattern-predicate nodes inside an
-- expression tree (e.g. WHERE (a)-->(b) AND (c)--(d)).
create procedure DB.DBA.CYP_PLAN_COLLECT_PATTERNPRED_VARS (in _expr any, in _vars any)
{
  declare etype varchar;
  declare i integer;

  if (not isarray (_expr))
    return _vars;

  etype := aref (_expr, 0);
  if (etype = 'PATTERNPRED')
    return DB.DBA.CYP_PLAN_COLLECT_PATTERN_VARS (aref (_expr, 1), _vars);

  if (etype = 'BINOP' or etype = 'STROP')
    {
      _vars := DB.DBA.CYP_PLAN_COLLECT_PATTERNPRED_VARS (aref (_expr, 2), _vars);
      return DB.DBA.CYP_PLAN_COLLECT_PATTERNPRED_VARS (aref (_expr, 3), _vars);
    }

  if (etype = 'UNOP' or etype = 'ISNULL' or etype = 'ISLABEL')
    return DB.DBA.CYP_PLAN_COLLECT_PATTERNPRED_VARS (aref (_expr, 2), _vars);

  if (etype = 'INEXPR')
    {
      _vars := DB.DBA.CYP_PLAN_COLLECT_PATTERNPRED_VARS (aref (_expr, 1), _vars);
      return DB.DBA.CYP_PLAN_COLLECT_PATTERNPRED_VARS (aref (_expr, 2), _vars);
    }

  return _vars;
}
;

create procedure DB.DBA.CYP_PLAN_VALIDATE_EXPR_SCOPE (in _expr any, in _scope any, in _opname varchar)
{
  declare vars any;
  declare i integer;
  declare v varchar;

  -- When YIELD * is in effect ('*' in scope), allow any variable
  if (DB.DBA.CYP_PLAN_VEC_HAS (_scope, '*'))
    return;

  vars := DB.DBA.CYP_PLAN_EXPR_VARS (_expr, vector ());
  for (i := 0; i < length (vars); i := i + 1)
    {
      v := aref (vars, i);
      if (v <> '*' and not DB.DBA.CYP_PLAN_VEC_HAS (_scope, v))
        signal ('CY083', sprintf ('Variable %s is not in scope for %s', v, _opname));
    }
}
;

create procedure DB.DBA.CYP_PLAN_VALIDATE_RETURN_SCOPE (in _clause any, in _scope any, in _opname varchar)
{
  declare items, order_by, group_by any;
  declare i integer;

  items := aref (_clause, 2);
  for (i := 0; i < length (items); i := i + 1)
    DB.DBA.CYP_PLAN_VALIDATE_EXPR_SCOPE (aref (aref (items, i), 1), _scope, _opname);

  order_by := aref (_clause, 3);
  if (isarray (order_by))
    {
      for (i := 0; i < length (order_by); i := i + 1)
        DB.DBA.CYP_PLAN_VALIDATE_EXPR_SCOPE (aref (aref (order_by, i), 0), _scope, _opname);
    }

  if (aref (_clause, 4) is not null)
    DB.DBA.CYP_PLAN_VALIDATE_EXPR_SCOPE (aref (_clause, 4), _scope, _opname);
  if (aref (_clause, 5) is not null)
    DB.DBA.CYP_PLAN_VALIDATE_EXPR_SCOPE (aref (_clause, 5), _scope, _opname);

  -- Index 6 is GROUP BY for RETURN, but WHERE for PROJECT (WITH).
  -- Skip for PROJECT so the WHERE expression is not misinterpreted.
  if (_opname <> 'PROJECT' and length (_clause) > 6)
    {
      group_by := aref (_clause, 6);
      if (isarray (group_by))
        {
          for (i := 0; i < length (group_by); i := i + 1)
            DB.DBA.CYP_PLAN_VALIDATE_EXPR_SCOPE (aref (group_by, i), _scope, _opname);
        }
    }

  if (_opname <> 'PROJECT' and length (_clause) > 7 and aref (_clause, 7) is not null)
    DB.DBA.CYP_PLAN_VALIDATE_EXPR_SCOPE (aref (_clause, 7), _scope, _opname);
}
;

create procedure DB.DBA.CYP_PLAN_VALIDATE_SCOPE (in _plan any)
{
  declare ops, vars, inner_plan, inner_trace, inner_rows, inner_vars any;
  declare i, j integer;
  declare op, opname, payload any;

  if (not isarray (_plan) or aref (_plan, 0) <> 'PLAN')
    signal ('CY082', 'Expected PLAN root for scope validation');

  ops := aref (_plan, 1);
  vars := vector ();

  for (i := 0; i < length (ops); i := i + 1)
    {
      op := aref (ops, i);
      opname := aref (op, 1);
      payload := aref (op, 2);

      if (opname = 'MATCH' or opname = 'OPTIONAL_MATCH')
        vars := DB.DBA.CYP_PLAN_COLLECT_MATCH_VARS (payload, vars);
      else if (opname = 'CREATE' or opname = 'MERGE')
        vars := DB.DBA.CYP_PLAN_COLLECT_CREATE_VARS (payload, vars);
      else if (opname = 'FILTER')
        {
          DB.DBA.CYP_PLAN_VALIDATE_EXPR_SCOPE (aref (payload, 1), vars, opname);
          -- Pattern predicates (WHERE (a)--()) introduce new variables;
          -- scan the expression tree for PATTERNPRED nodes to collect them.
          vars := DB.DBA.CYP_PLAN_COLLECT_PATTERNPRED_VARS (aref (payload, 1), vars);
        }
      else if (opname = 'PROJECT')
        {
          declare proj_vars any;
          DB.DBA.CYP_PLAN_VALIDATE_RETURN_SCOPE (payload, vars, opname);
          proj_vars := DB.DBA.CYP_PLAN_COLLECT_RETURN_VARS (aref (payload, 2));
          -- WHERE clause sees projected aliases as well as prior scope
          if (aref (payload, 6) is not null)
            DB.DBA.CYP_PLAN_VALIDATE_EXPR_SCOPE (aref (payload, 6),
              DB.DBA.CYP_PLAN_VEC_MERGE (vars, proj_vars), opname);
          vars := proj_vars;
        }
      else if (opname = 'RETURN')
        DB.DBA.CYP_PLAN_VALIDATE_RETURN_SCOPE (payload, vars, opname);
      else if (opname = 'UNWIND')
        {
          DB.DBA.CYP_PLAN_VALIDATE_EXPR_SCOPE (aref (payload, 1), vars, opname);
          vars := DB.DBA.CYP_PLAN_VEC_ADD (vars, aref (payload, 2));
        }
      else if (opname = 'BIND')
        {
          DB.DBA.CYP_PLAN_VALIDATE_EXPR_SCOPE (aref (payload, 1), vars, opname);
          vars := DB.DBA.CYP_PLAN_VEC_ADD (vars, aref (payload, 2));
        }
      else if (opname = 'VALUES')
        vars := DB.DBA.CYP_PLAN_VEC_ADD (vars, aref (payload, 1));
      else if (opname = 'CALL')
        {
          -- CALL clause: collect yielded variables
          declare yield_items any;
          declare j integer;
          declare yield_item any;
          yield_items := aref (payload, 3);
          if (yield_items is not null)
            {
              for (j := 0; j < length (yield_items); j := j + 1)
                {
                  yield_item := aref (yield_items, j);
                  if (aref (yield_item, 0) = 'YIELDSTAR')
                    {
                      vars := DB.DBA.CYP_PLAN_VEC_ADD (vars, '*');
                    }
                  else if (aref (yield_item, 0) = 'YIELDITEM')
                    {
                      declare alias_name varchar;
                      alias_name := aref (yield_item, 2);
                      if (alias_name is null)
                        alias_name := aref (yield_item, 1);
                      vars := DB.DBA.CYP_PLAN_VEC_ADD (vars, alias_name);
                    }
                }
            }
        }
      else if (opname = 'GRAPH' or opname = 'SERVICE')
        {
          inner_plan := DB.DBA.CYP_PLAN_BUILD (vector ('STMT', aref (payload, 2)));
          DB.DBA.CYP_PLAN_VALIDATE_SCOPE (inner_plan);
          inner_trace := DB.DBA.CYP_PLAN_SCOPE_TRACE (inner_plan);
          inner_rows := aref (inner_trace, 1);
          if (length (inner_rows) > 0)
            {
              inner_vars := aref (aref (inner_rows, length (inner_rows) - 1), 1);
              for (j := 0; j < length (inner_vars); j := j + 1)
                vars := DB.DBA.CYP_PLAN_VEC_ADD (vars, aref (inner_vars, j));
            }
        }
    }

  return 'OK';
}
;

create procedure DB.DBA.CYP_PLAN_BUILD (in _ast any)
{
  declare clauses, ops any;
  declare i, n integer;
  declare clause any;
  declare ctype varchar;

  if (not isarray (_ast) or length (_ast) < 2 or aref (_ast, 0) <> 'STMT')
    signal ('CY080', 'Expected STMT AST for logical planning');

  clauses := aref (_ast, 1);
  ops := vector ();
  n := length (clauses);

  for (i := 0; i < n; i := i + 1)
    {
      clause := aref (clauses, i);
      ctype := aref (clause, 0);

      if (ctype = 'PREFIX')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('PREFIX', clause)));
      else if (ctype = 'FORCE_CAMELCASE')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('FORCE_CAMELCASE', clause)));
      else if (ctype = 'DEFINE')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('DEFINE', clause)));
      else if (ctype = 'USE' or ctype = 'USE_ANY_GRAPH')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR (ctype, clause)));
      else if (ctype = 'MATCH')
        {
          if (length (clause) > 1 and aref (clause, 1))
            ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('OPTIONAL_MATCH', clause)));
          else
            ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('MATCH', clause)));
        }
      else if (ctype = 'WHERE')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('FILTER', clause)));
      else if (ctype = 'WITH')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('PROJECT', clause)));
      else if (ctype = 'UNWIND')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('UNWIND', clause)));
      else if (ctype = 'CALL')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('CALL', clause)));
      else if (ctype = 'RETURN')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('RETURN', clause)));
      else if (ctype = 'CREATE')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('CREATE', clause)));
      else if (ctype = 'MERGE')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('MERGE', clause)));
      else if (ctype = 'SET')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('SET', clause)));
      else if (ctype = 'REMOVE')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('REMOVE', clause)));
      else if (ctype = 'DELETE')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('DELETE', clause)));
      else if (ctype = 'UNION')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('UNION', clause)));
      else if (ctype = 'GRAPH')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('GRAPH', clause)));
      else if (ctype = 'SERVICE')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('SERVICE', clause)));
      else if (ctype = 'VALUES')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('VALUES', clause)));
      else if (ctype = 'BIND')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('BIND', clause)));
      else if (ctype = 'MINUS')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('MINUS', clause)));
      else if (ctype = 'ASK' or ctype = 'CONSTRUCT' or ctype = 'DESCRIBE')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR (ctype, clause)));
      else if (ctype = 'SPARQL_LOAD' or ctype = 'SPARQL_CLEAR' or ctype = 'SPARQL_DROP'
               or ctype = 'SPARQL_CREATE_GRAPH' or ctype = 'SPARQL_GRAPH_COPY'
               or ctype = 'SPARQL_DATA_UPDATE')
        ops := vector_concat (ops, vector (DB.DBA.CYP_PLAN_OPERATOR ('SPARQL_UPDATE', clause)));
      else
        signal ('CY081', sprintf ('Unsupported AST clause in logical planner: %s', ctype));
    }

  return vector ('PLAN', ops);
}
;

create procedure DB.DBA.CYPHER_PLAN (in _query varchar)
{
  declare tokens, ast any;

  tokens := DB.DBA.CYP_TOKENIZE (_query);
  ast := DB.DBA.CYP_PARSE (tokens);
  return DB.DBA.CYP_PLAN_BUILD (ast);
}
;

create procedure DB.DBA.CYPHER_PLAN_SCOPE (in _query varchar)
{
  return DB.DBA.CYP_PLAN_SCOPE_TRACE (DB.DBA.CYPHER_PLAN (_query));
}
;

create procedure DB.DBA.CYPHER_PLAN_VALIDATE (in _query varchar)
{
  return DB.DBA.CYP_PLAN_VALIDATE_SCOPE (DB.DBA.CYPHER_PLAN (_query));
}
;

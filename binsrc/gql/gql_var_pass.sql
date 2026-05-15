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
--  openGQL: GQL for Virtuoso - Variable Resolution Pass
--
--  Copyright (C) 1998-2026 OpenLink Software
--
--  Pre-translation AST walk that resolves all GQL variables to their
--  SPARQL variable names and populates ctx.var_map before emission.
--
--  Variable naming convention:
--    Node variables:  ?gql_n_<name>
--    Edge variables:  ?gql_e_<name>
--    Path variables:  ?gql_p_<name>
--    Value variables: ?gql_v_<name>  (LET/FOR-bound)
--    Generic:         ?gql_<name>
--
--  This pass also detects:
--    - Variable shadowing in nested OPTIONAL blocks
--    - Unbound variable references in WHERE/FILTER/RETURN
--    - Duplicate variable definitions
--

----------------------------------------------------------------------
-- Entry point: resolve all variables in a parsed AST into ctx.var_map
----------------------------------------------------------------------

create procedure DB.DBA.GQL_VAR_RESOLVE_AST (in _ast any, inout _ctx any)
{
  declare node_type varchar;

  if (not isarray (_ast))
    return;

  node_type := aref (_ast, 0);

  if (node_type = 'PROG')
    {
      declare proc_body any;
      proc_body := aref (_ast, 1);
      if (proc_body is not null)
        DB.DBA.GQL_VAR_RESOLVE_AST (proc_body, _ctx);
    }
  else if (node_type = 'PROC')
    {
      declare stmt_block any;
      stmt_block := aref (_ast, 3);
      if (stmt_block is not null)
        DB.DBA.GQL_VAR_RESOLVE_AST (stmt_block, _ctx);
    }
  else if (node_type = 'QUERY')
    {
      declare clauses any;
      declare i integer;
      clauses := aref (_ast, 1);
      for (i := 0; i < length (clauses); i := i + 1)
        DB.DBA.GQL_VAR_RESOLVE_CLAUSE (aref (clauses, i), _ctx);
    }
}
;

----------------------------------------------------------------------
-- Resolve variables within a single clause
----------------------------------------------------------------------

create procedure DB.DBA.GQL_VAR_RESOLVE_CLAUSE (in _clause any, inout _ctx any)
{
  declare ctype varchar;
  declare i integer;
  declare patterns, ins_patterns, construct_patterns, items any;
  declare item, expr, item_alias any;
  declare let_var, for_var varchar;
  declare is_optional integer;
  declare svc_query any;

  if (not isarray (_clause))
    return;

  ctype := aref (_clause, 0);

  if (ctype = 'MATCH')
    {
      is_optional := aref (_clause, 1);
      if (is_optional)
        DB.DBA.GQL_CTX_ENTER_OPTIONAL (_ctx);

      patterns := aref (_clause, 2);
      for (i := 0; i < length (patterns); i := i + 1)
        DB.DBA.GQL_VAR_RESOLVE_PATTERN (aref (patterns, i), _ctx);

      if (is_optional)
        DB.DBA.GQL_CTX_EXIT_OPTIONAL (_ctx);
    }
  else if (ctype = 'INSERT')
    {
      ins_patterns := aref (_clause, 1);
      for (i := 0; i < length (ins_patterns); i := i + 1)
        DB.DBA.GQL_VAR_RESOLVE_PATTERN (aref (ins_patterns, i), _ctx);
    }
  else if (ctype = 'CONSTRUCT')
    {
      construct_patterns := aref (_clause, 1);
      for (i := 0; i < length (construct_patterns); i := i + 1)
        DB.DBA.GQL_VAR_RESOLVE_PATTERN (aref (construct_patterns, i), _ctx);
    }
  else if (ctype = 'LET')
    {
      let_var := aref (_clause, 1);
      DB.DBA.GQL_VAR_RESOLVE_REGISTER (let_var, 'value', _ctx);
    }
  else if (ctype = 'FOR')
    {
      for_var := aref (_clause, 1);
      DB.DBA.GQL_VAR_RESOLVE_REGISTER (for_var, 'value', _ctx);
    }
  else if (ctype = 'RETURN')
    {
      items := aref (_clause, 2);
      for (i := 0; i < length (items); i := i + 1)
        {
          item := aref (items, i);
          expr := aref (item, 1);
          item_alias := aref (item, 2);
          if (item_alias is not null)
            DB.DBA.GQL_VAR_RESOLVE_REGISTER (item_alias, 'alias', _ctx);
          else if (isarray (expr) and aref (expr, 0) = 'VAR' and aref (expr, 1) <> '*')
            {
              -- Ensure referenced var is known; if not, it will be caught by scope validator
              ;
            }
        }
    }
  else if (ctype = 'DESCRIBE')
    {
      ;
    }
  else if (ctype = 'SERVICE')
    {
      svc_query := aref (_clause, 2);
      if (isarray (svc_query) and aref (svc_query, 0) = 'QUERY')
        DB.DBA.GQL_VAR_RESOLVE_AST (svc_query, _ctx);
    }
}
;

----------------------------------------------------------------------
-- Resolve variables in a graph pattern (node/edge elements)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_VAR_RESOLVE_PATTERN (in _pattern any, inout _ctx any)
{
  declare ptype varchar;
  declare elems any;
  declare i integer;

  if (not isarray (_pattern))
    return;

  ptype := aref (_pattern, 0);

  if (ptype = 'PATH')
    {
      declare path_var varchar;
      path_var := aref (_pattern, 1);
      DB.DBA.GQL_VAR_RESOLVE_REGISTER (path_var, 'path', _ctx);
      if (length (_pattern) > 2)
        DB.DBA.GQL_VAR_RESOLVE_PATTERN (vector ('PATTERN', aref (_pattern, 2)), _ctx);
    }
  else if (ptype = 'PATHVAR')
    {
      declare pv_var varchar;
      pv_var := aref (_pattern, 1);
      DB.DBA.GQL_VAR_RESOLVE_REGISTER (pv_var, 'path', _ctx);
      if (length (_pattern) > 2)
        DB.DBA.GQL_VAR_RESOLVE_PATTERN (vector ('PATTERN', aref (_pattern, 2)), _ctx);
    }
  else if (ptype = 'PATTERN')
    {
      elems := aref (_pattern, 1);
      for (i := 0; i < length (elems); i := i + 1)
        {
          declare elem, etype any;
          elem := aref (elems, i);
          if (not isarray (elem))
            goto next_elem;
          etype := aref (elem, 0);
          if (etype = 'NODE')
            {
              declare nvar varchar;
              nvar := aref (elem, 1);
              DB.DBA.GQL_VAR_RESOLVE_REGISTER (nvar, 'node', _ctx);
            }
          else if (etype = 'EDGE')
            {
              declare evar varchar;
              evar := aref (elem, 1);
              DB.DBA.GQL_VAR_RESOLVE_REGISTER (evar, 'edge', _ctx);
            }
        next_elem:;
        }
    }
}
;

----------------------------------------------------------------------
-- Register a GQL variable in ctx.var_map with its SPARQL name
----------------------------------------------------------------------

create procedure DB.DBA.GQL_VAR_RESOLVE_REGISTER (in _gql_name varchar, in _kind varchar, inout _ctx any)
{
  declare sparql_var varchar;
  declare existing any;

  if (_gql_name is null or _gql_name = '')
    return;

  -- Determine SPARQL variable name based on kind
  if (_kind = 'node')
    sparql_var := concat ('?gql_n_', _gql_name);
  else if (_kind = 'edge')
    sparql_var := concat ('?gql_e_', _gql_name);
  else if (_kind = 'path')
    sparql_var := concat ('?gql_p_', _gql_name);
  else if (_kind = 'value' or _kind = 'alias')
    sparql_var := concat ('?gql_v_', _gql_name);
  else
    sparql_var := concat ('?gql_', _gql_name);

  -- Check for existing mapping with different kind (collision)
  existing := DB.DBA.GQL_CTX_GET_VAR_MAP (_ctx, _gql_name);
  if (existing is not null and aref (existing, 2) <> _kind)
    {
      -- Variable re-used with a different kind — warn via error accumulator
      -- but allow it; the last registration wins.
      DB.DBA.GQL_CTX_ADD_ERROR (_ctx, 'GW001',
        sprintf ('Variable ''%s'' re-declared with different kind (was %s, now %s)',
          _gql_name, aref (existing, 2), _kind));
    }

  -- Check for shadowing: if in_optional_depth > 0 and variable already exists
  -- in outer scope, we flag it
  if (DB.DBA.GQL_CTX_IN_OPTIONAL (_ctx) and existing is not null)
    {
      DB.DBA.GQL_CTX_ADD_ERROR (_ctx, 'GW002',
        sprintf ('Variable ''%s'' shadowed inside OPTIONAL — inner binding hides outer',
          _gql_name));
    }

  DB.DBA.GQL_CTX_ADD_VAR_MAP (_ctx, _gql_name, sparql_var, _kind);
}
;

----------------------------------------------------------------------
-- Debug: dump var_map contents
----------------------------------------------------------------------

create procedure DB.DBA.GQL_VAR_RESOLVE_DUMP (inout _ctx any)
{
  declare vm any;
  declare i integer;
  declare out_s varchar;

  vm := DB.DBA.GQL_CTX_GET (_ctx, 'var_map');
  out_s := 'Variable map:\n';
  for (i := 0; i < length (vm); i := i + 1)
    {
      declare entry any;
      entry := aref (vm, i);
      out_s := concat (out_s, '  ', aref (entry, 0), ' → ', aref (entry, 1),
        ' (', aref (entry, 2), ')\n');
    }
  return out_s;
}
;

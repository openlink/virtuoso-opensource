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
--  openGQL: GQL for Virtuoso - Parser
--
--  Copyright (C) 1998-2026 OpenLink Software
--
--  Recursive-descent parser producing AST as nested vectors.
--  Mirrors cypher_parser.sql patterns; reuses AST tags where
--  semantics match exactly for translator code sharing.
--
--  AST node formats:
--    Program:      vector('PROG', sessionActivity, transactionActivity)
--    ProcBody:     vector('PROC', atSchema, bindingDefs, statementBlock)
--    Query:        vector('QUERY', clauses, set_ops)
--    Match:        vector('MATCH', is_optional, patterns, from_graphs, is_all)
--    Where:        vector('WHERE', expr)
--    Filter:       vector('FILTER', expr)
--    Return:       vector('RETURN', is_distinct, items, order_by, skip, limit)
--    Insert:       vector('INSERT', patterns [, graph_ref])  -- graph_ref present for INSERT INTO GRAPH <g>
--    Set:          vector('SET', items)                     -- sub-items: SETPROP, SETALL, SETLABEL
--    Remove:       vector('REMOVE', items)                  -- sub-items: RMPROP, RMLABEL
--    Delete:       vector('DELETE', is_detach, items)
--    Use:          vector('USE', graph_expr)
--    UseAnyGraph:  vector('USE_ANY_GRAPH')
--    FromClause:   vector('FROM_CLAUSE', kind, graph_expr)    -- kind: 'FROM' | 'FROM_NAMED'
--    Service:      vector('SERVICE', endpoint_expr, query_ast, is_silent)
--    Prefix:       vector('PREFIX', prefix_name, uri)
--    Base:         vector('BASE', uri)
--    Define:       vector('DEFINE', key, value_expr)
--    Let:          vector('LET', var_name, expr)
--    For:          vector('FOR', var_name, expr, clauses)
--    CreateSchema: vector('CREATE_SCHEMA', schema_ref, if_not_exists, or_replace)
--    DropSchema:   vector('DROP_SCHEMA', schema_ref, if_exists)
--    CreateGraph:  vector('CREATE_GRAPH', graph_ref, graph_type_ref, copy_of, like)
--    DropGraph:    vector('DROP_GRAPH', graph_ref, if_exists)
--    CreateType:   vector('CREATE_GRAPH_TYPE', type_ref, body)
--    DropType:     vector('DROP_GRAPH_TYPE', type_ref, if_exists)
--    SessionSet:   vector('SESSION_SET', setting_vec)
--    SessionReset: vector('SESSION_RESET', arguments_vec)
--    Node:         vector('NODE', var_name, labels_vec, props_vec)
--    Edge:         vector('EDGE', var_name, types_vec, direction, quantifier, props_vec, path_mode, cost_expr)
--                  direction: 'RIGHT', 'LEFT', 'BOTH', 'UNDIRECTED'
--                  quantifier: null or vector(min, max) with null = unbounded
--    PathPattern:  vector('PATH', var_name, elements_vec)
--    ReturnItem:   vector('RETITEM', expr, alias)
--    SortItem:     vector('SORT', expr, direction)         -- 'ASC' or 'DESC'
--    SetProp:      vector('SETPROP', expr, value_expr)
--    SetLabel:     vector('SETLABEL', var_name, labels_vec)
--    SetAllProps:  vector('SETALL', var_name, expr, is_plus)
--    RemoveProp:   vector('RMPROP', expr)
--    RemoveLabel:  vector('RMLABEL', var_name, labels_vec)
--    PropAccess:   vector('PROP', var_or_expr, prop_name)
--    Variable:     vector('VAR', name)
--    Literal:      vector('LIT', value)
--

----------------------------------------------------------------------
-- Clause-start detection
----------------------------------------------------------------------

create procedure DB.DBA.GQL_IS_CLAUSE_START (in _type integer)
{
  if (_type = 200) return 1;  -- MATCH
  if (_type = 201) return 1;  -- INSERT
  if (_type = 527) return 1;  -- CONSTRUCT
  if (_type = 528) return 1;  -- DESCRIBE
  if (_type = 202) return 1;  -- SET
  if (_type = 203) return 1;  -- REMOVE
  if (_type = 204) return 1;  -- DELETE
  if (_type = 205) return 1;  -- RETURN
  if (_type = 206) return 1;  -- WHERE
  if (_type = 207) return 1;  -- OPTIONAL
  if (_type = 208) return 1;  -- FOR
  if (_type = 209) return 1;  -- FILTER
  if (_type = 210) return 1;  -- LET
  if (_type = 218) return 1;  -- UNION
  if (_type = 219) return 1;  -- EXCEPT
  if (_type = 220) return 1;  -- INTERSECT
  if (_type = 223) return 1;  -- CREATE
  if (_type = 224) return 1;  -- DROP
  if (_type = 244) return 1;  -- SESSION
  if (_type = 248) return 1;  -- USE
  if (_type = 252) return 1;  -- CALL
  if (_type = 264) return 1;  -- WITH
  if (_type = 285) return 1;  -- PREFIX
  if (_type = 286) return 1;  -- FROM
  if (_type = 415) return 1;  -- BASE
  if (_type = 425) return 1;  -- SERVICE
  if (_type = 418) return 1;  -- LOAD
  if (_type = 419) return 1;  -- CLEAR
  if (_type = 529) return 1;  -- FORCE
  return 0;
}
;

----------------------------------------------------------------------
-- Top-level parse entry point
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE (in _tokens any)
{
  declare pos integer;
  declare ast any;
  pos := 0;
  ast := DB.DBA.GQL_PARSE_PROGRAM (_tokens, pos);
  return ast;
}
;

----------------------------------------------------------------------
-- gqlProgram : programActivity sessionCloseCommand? EOF
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_PROGRAM (in _tokens any, inout _pos integer)
{
  declare session_act, trans_act any;
  declare tt integer;

  session_act := null;
  trans_act := null;

  tt := DB.DBA.GQL_PEEK (_tokens, _pos);

  -- SESSION commands
  if (tt = 244)  -- SESSION
    {
      declare tt2 integer;
      tt2 := DB.DBA.GQL_PEEK (_tokens, _pos + 1);
      if (tt2 = 202)  -- SET
        session_act := DB.DBA.GQL_PARSE_SESSION_SET (_tokens, _pos);
      else if (tt2 = 300)  -- RESET
        session_act := DB.DBA.GQL_PARSE_SESSION_RESET (_tokens, _pos);
      else if (tt2 = 299)  -- CLOSE
        {
          _pos := _pos + 2;
          DB.DBA.GQL_EXPECT (_tokens, _pos, 999);
          return vector ('PROG', null, null);
        }
      else
        signal ('GQ003', sprintf ('Expected SET, RESET, or CLOSE after SESSION at token position %d', _pos));
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);
    }
  -- Transaction activity
  else if (tt = 245)  -- START
    {
      trans_act := DB.DBA.GQL_PARSE_TRANSACTION_STUB (_tokens, _pos);
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);
    }
  else if (tt = 246 or tt = 247)  -- COMMIT or ROLLBACK
    {
      _pos := _pos + 1;
      trans_act := vector ('TRANS_END', DB.DBA.GQL_PEEK_VAL (_tokens, _pos - 1));
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);
    }

  -- Procedure body (the common code path)
  if (tt <> 999)
    {
      declare proc_body any;
      proc_body := DB.DBA.GQL_PARSE_PROCEDURE_BODY (_tokens, _pos);
      DB.DBA.GQL_EXPECT (_tokens, _pos, 999);
      return vector ('PROG', proc_body, null);
    }

  DB.DBA.GQL_EXPECT (_tokens, _pos, 999);
  return vector ('PROG', session_act, trans_act);
}
;

----------------------------------------------------------------------
-- procedureBody : atSchemaClause? bindingDefinitionClause* statementBlock
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_PROCEDURE_BODY (in _tokens any, inout _pos integer)
{
  declare at_schema, binding_defs, stmt_block any;

  at_schema := null;
  binding_defs := vector ();

  -- Optional USE <graph> at-schema clause
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 248)  -- USE
    {
      _pos := _pos + 1;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 255)  -- ANY
        {
          _pos := _pos + 1;
          DB.DBA.GQL_EXPECT (_tokens, _pos, 225);  -- GRAPH
          at_schema := vector ('ANY_GRAPH');
        }
      else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 330)  -- HOME_PROPERTY_GRAPH
        {
          _pos := _pos + 1;
          at_schema := vector ('HOME_GRAPH');
        }
      else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 227)  -- PROPERTY
        {
          _pos := _pos + 1;
          DB.DBA.GQL_EXPECT (_tokens, _pos, 225);  -- GRAPH
          at_schema := vector ('USE_PROPERTY_AT_SCHEMA',
            DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos));
        }
      else
        at_schema := DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos);
    }

  -- Binding definitions
  while (DB.DBA.GQL_PEEK (_tokens, _pos) = 285  -- PREFIX
         or DB.DBA.GQL_PEEK (_tokens, _pos) = 284  -- DEFINE
         or DB.DBA.GQL_PEEK (_tokens, _pos) = 415  -- BASE
         or DB.DBA.GQL_PEEK (_tokens, _pos) = 544)  -- VERSION
    {
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 285)
        binding_defs := vector_concat (binding_defs, vector (DB.DBA.GQL_PARSE_PREFIX (_tokens, _pos)));
      else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 415)
        binding_defs := vector_concat (binding_defs, vector (DB.DBA.GQL_PARSE_BASE (_tokens, _pos)));
      else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 544)
        binding_defs := vector_concat (binding_defs, vector (DB.DBA.GQL_PARSE_VERSION (_tokens, _pos)));
      else
        binding_defs := vector_concat (binding_defs, vector (DB.DBA.GQL_PARSE_DEFINE (_tokens, _pos)));
    }

  -- Statement block
  stmt_block := DB.DBA.GQL_PARSE_COMPOSITE_QUERY (_tokens, _pos);

  return vector ('PROC', at_schema, binding_defs, stmt_block);
}
;

----------------------------------------------------------------------
-- compositeQueryStatement : linearDataModifyingStatement? queryStatement
-- or linearDataModifyingStatement alone
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_COMPOSITE_QUERY (in _tokens any, inout _pos integer)
{
  declare clauses, clause, set_ops any;
  declare tt, saved_pos integer;

  clauses := vector ();
  set_ops := vector ();

  while (1)
    {
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);
      if (tt = 999) goto query_done;
      if (tt = 6) goto query_done;   -- RBRACE (closing block)
      if (tt = 2) goto query_done;   -- RPAREN (closing TABLE sub-query)
      if (tt = 260)  -- END (closing FOR block)
        { _pos := _pos + 1; goto query_done; }

      if (tt = 200)  -- MATCH
        {
          clause := DB.DBA.GQL_PARSE_MATCH (_tokens, _pos, 0);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 531)  -- ASK
        {
          _pos := _pos + 1;
          clauses := vector_concat (clauses, vector (vector ('ASK')));
        }
      else if (tt = 532)  -- MINUS
        {
          declare minus_patterns any;
          _pos := _pos + 1;
          minus_patterns := DB.DBA.GQL_PARSE_PATTERN_LIST (_tokens, _pos);
          clauses := vector_concat (clauses, vector (vector ('MINUS', minus_patterns)));
        }
      else if (tt = 533)  -- MODIFY
        {
          declare mod_delete_items, mod_insert_patterns any;
          _pos := _pos + 1;  -- consume MODIFY
          -- Expect DELETE <items>
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 204)  -- DELETE
            {
              _pos := _pos + 1;
              mod_delete_items := vector ();
              while (1)
                {
                  mod_delete_items := vector_concat (mod_delete_items, vector (DB.DBA.GQL_PARSE_EXPR (_tokens, _pos)));
                  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)
                    _pos := _pos + 1;
                  else
                    goto mod_del_done;
                }
              mod_del_done:
              -- Expect INSERT <patterns>
              if (DB.DBA.GQL_PEEK (_tokens, _pos) = 201)  -- INSERT
                {
                  _pos := _pos + 1;
                  mod_insert_patterns := DB.DBA.GQL_PARSE_PATTERN_LIST (_tokens, _pos);
                }
              else
                mod_insert_patterns := vector ();
              clauses := vector_concat (clauses, vector (vector ('MODIFY', mod_delete_items, mod_insert_patterns)));
            }
          else
            signal ('GQ003', sprintf ('Expected DELETE after MODIFY at position %d', _pos));
        }
      else if (tt = 207)  -- OPTIONAL
        {
          clause := DB.DBA.GQL_PARSE_MATCH (_tokens, _pos, 1);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 201)  -- INSERT
        {
          clause := DB.DBA.GQL_PARSE_INSERT (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 527)  -- CONSTRUCT
        {
          clause := DB.DBA.GQL_PARSE_CONSTRUCT (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 528)  -- DESCRIBE
        {
          clause := DB.DBA.GQL_PARSE_DESCRIBE (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 202)  -- SET
        {
          clause := DB.DBA.GQL_PARSE_SET (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 529)  -- FORCE
        {
          clause := DB.DBA.GQL_PARSE_FORCE_OPTION (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 203)  -- REMOVE
        {
          clause := DB.DBA.GQL_PARSE_REMOVE (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 204)  -- DELETE
        {
          clause := DB.DBA.GQL_PARSE_DELETE (_tokens, _pos, 0);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 436)  -- DETACH
        {
          _pos := _pos + 1;
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 204)  -- DELETE
            clause := DB.DBA.GQL_PARSE_DELETE (_tokens, _pos, 1);
          else
            signal ('GQ003', sprintf ('Expected DELETE after DETACH at position %d', _pos));
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 205)  -- RETURN
        {
          clause := DB.DBA.GQL_PARSE_RETURN (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 328)  -- FINISH
        {
          _pos := _pos + 1;
          clauses := vector_concat (clauses, vector (vector ('FINISH')));
        }
      else if (tt = 206)  -- WHERE
        {
          clause := DB.DBA.GQL_PARSE_WHERE (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 209)  -- FILTER
        {
          clause := DB.DBA.GQL_PARSE_FILTER (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 208)  -- FOR
        {
          clause := DB.DBA.GQL_PARSE_FOR (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 543)  -- UNNEST
        {
          clause := DB.DBA.GQL_PARSE_UNNEST (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 210)  -- LET
        {
          clause := DB.DBA.GQL_PARSE_LET (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 279)  -- VALUE (alias for LET)
        {
          clause := DB.DBA.GQL_PARSE_LET (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 225  -- GRAPH
               and _pos + 2 < length (_tokens)
               and DB.DBA.GQL_PEEK (_tokens, _pos + 1) = 64  -- IDENT
               and DB.DBA.GQL_PEEK (_tokens, _pos + 2) = 15)  -- EQ
        {
          clause := DB.DBA.GQL_PARSE_GRAPH_BINDING (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 281)  -- TABLE
        {
          clause := DB.DBA.GQL_PARSE_TABLE_BINDING (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 262)  -- GROUP
        {
          clause := DB.DBA.GQL_PARSE_GROUP_BY (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 263)  -- HAVING
        {
          clause := DB.DBA.GQL_PARSE_HAVING (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 211)  -- ORDER
        {
          clause := DB.DBA.GQL_PARSE_ORDER_BY (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 216)  -- SKIP/OFFSET
        {
          clause := DB.DBA.GQL_PARSE_SKIP (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 215)  -- LIMIT
        {
          clause := DB.DBA.GQL_PARSE_LIMIT (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 248)  -- USE
        {
          clause := DB.DBA.GQL_PARSE_USE_GRAPH (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 286)  -- FROM (top-level dataset clause)
        {
          clause := DB.DBA.GQL_PARSE_FROM_CLAUSE (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 231 and _pos + 1 < length (_tokens)
               and DB.DBA.GQL_PEEK (_tokens, _pos + 1) = 286)  -- NOT FROM
        {
          _pos := _pos + 1;  -- consume NOT
          clause := DB.DBA.GQL_PARSE_NOT_FROM_CLAUSE (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 264)  -- WITH <graph> (SPARQL-Update dataset)
        {
          declare with_graph any;
          _pos := _pos + 1;
          with_graph := DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos);
          clauses := vector_concat (clauses, vector (vector ('WITH', with_graph)));
        }
      else if (tt = 416)  -- USING / USING NAMED (SPARQL-Update dataset)
        {
          declare using_kind varchar;
          declare using_graph any;
          _pos := _pos + 1;
          using_kind := 'USING';
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 426)  -- NAMED
            { _pos := _pos + 1; using_kind := 'USING_NAMED'; }
          using_graph := DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos);
          clauses := vector_concat (clauses, vector (vector ('USING_CLAUSE', using_kind, using_graph)));
        }
      else if (tt = 425)  -- SERVICE
        {
          clause := DB.DBA.GQL_PARSE_SERVICE (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 223)  -- CREATE
        {
          clause := DB.DBA.GQL_PARSE_CREATE_STMT (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 224)  -- DROP
        {
          clause := DB.DBA.GQL_PARSE_DROP_STMT (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 418)  -- LOAD
        {
          clause := DB.DBA.GQL_PARSE_LOAD (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 419)  -- CLEAR
        {
          clause := DB.DBA.GQL_PARSE_CLEAR (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 252)  -- CALL
        {
          clause := DB.DBA.GQL_PARSE_CALL (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 218 or tt = 219 or tt = 220 or tt = 430)  -- UNION/EXCEPT/INTERSECT/OTHERWISE
        {
          declare setop_name varchar;
          declare left_query, right_query any;
          if (tt = 218) setop_name := 'UNION';
          else if (tt = 219) setop_name := 'EXCEPT';
          else if (tt = 220) setop_name := 'INTERSECT';
          else setop_name := 'OTHERWISE';
          _pos := _pos + 1;
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 221)  -- ALL
            { _pos := _pos + 1; setop_name := concat (setop_name, '_ALL'); }
          -- Wrap clauses collected so far as the left query branch
          left_query := vector ('QUERY', clauses, set_ops);
          -- Parse the right query branch
          right_query := DB.DBA.GQL_PARSE_COMPOSITE_QUERY (_tokens, _pos);
          return vector ('SETOP', setop_name, left_query, right_query);
        }
      else
        signal ('GQ003', sprintf ('Unexpected token ''%s'' (type %d) at position %d',
                DB.DBA.GQL_PEEK_VAL (_tokens, _pos), tt, _pos));
    }
  query_done:
  return vector ('QUERY', clauses, set_ops);
}
;

----------------------------------------------------------------------
-- MATCH / OPTIONAL MATCH
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_MATCH (in _tokens any, inout _pos integer, in _is_optional integer)
{
  declare patterns, from_graphs any;
  declare is_all integer;
  declare shortest_config, s_kind any;
  declare s_count integer;

  if (_is_optional)
    _pos := _pos + 1;  -- consume OPTIONAL
  DB.DBA.GQL_EXPECT (_tokens, _pos, 200);  -- MATCH

  is_all := 0;
  shortest_config := null;
  declare any_prefix integer;
  any_prefix := 0;

  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 221)  -- ALL
    {
      _pos := _pos + 1;
      is_all := 1;
    }
  else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 255            -- ANY SHORTEST
           and DB.DBA.GQL_PEEK (_tokens, _pos + 1) = 271)   -- (ISO order: ANY before SHORTEST)
    {
      _pos := _pos + 1;
      any_prefix := 1;
    }

  -- SHORTEST [k | ALL | ANY] [GROUPS] PATH
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 271)  -- SHORTEST
    {
      _pos := _pos + 1;
      s_kind := 'ALL';  -- default
      if (any_prefix)   -- MATCH ANY SHORTEST ...
        s_kind := 'ANY';
      s_count := 1;     -- default
      declare s_groups integer;
      s_groups := 0;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 66)  -- INTEGER
        {
          s_count := atoi (DB.DBA.GQL_PEEK_VAL (_tokens, _pos));
          _pos := _pos + 1;
        }
      else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 221)  -- ALL
        {
          _pos := _pos + 1;
          s_kind := 'ALL';
        }
      else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 255)  -- ANY
        {
          _pos := _pos + 1;
          s_kind := 'ANY';
        }
      -- Optional GROUPS
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 448)  -- GROUPS
        {
          _pos := _pos + 1;
          s_groups := 1;
        }
      DB.DBA.GQL_EXPECT (_tokens, _pos, 269);  -- PATH
      shortest_config := vector (s_kind, s_count, s_groups);
    }

  -- Optional path mode prefix: MATCH [WALK|TRAIL|SIMPLE|ACYCLIC] (pattern).
  -- ISO GQL places the mode before the path pattern (see gql-path-patterns.md);
  -- it applies to the quantified/transitive edges of this MATCH.
  declare match_path_mode varchar;
  match_path_mode := null;
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 272)       -- WALK
    { _pos := _pos + 1; match_path_mode := 'WALK'; }
  else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 440)  -- TRAIL
    { _pos := _pos + 1; match_path_mode := 'TRAIL'; }
  else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 360)  -- SIMPLE
    { _pos := _pos + 1; match_path_mode := 'SIMPLE'; }
  else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 343)  -- ACYCLIC
    { _pos := _pos + 1; match_path_mode := 'ACYCLIC'; }

  patterns := DB.DBA.GQL_PARSE_PATTERN_LIST (_tokens, _pos);

  -- Optional ON/FROM <graph> clause
  from_graphs := vector ();
  while (DB.DBA.GQL_PEEK (_tokens, _pos) = 286)  -- FROM
    {
      _pos := _pos + 1;
      from_graphs := vector_concat (from_graphs, vector (vector ('FROM', DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos))));
    }

  return vector ('MATCH', _is_optional, patterns, from_graphs, is_all, shortest_config, match_path_mode);
}
;

----------------------------------------------------------------------
-- RETURN
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_RETURN (in _tokens any, inout _pos integer)
{
  declare is_distinct integer;
  declare items, order_by, skip, limit any;
  declare tt integer;

  _pos := _pos + 1;  -- consume RETURN
  is_distinct := 0;

  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 222)  -- DISTINCT
    { is_distinct := 1; _pos := _pos + 1; }

  items := DB.DBA.GQL_PARSE_RETURN_ITEMS (_tokens, _pos);

  -- Optional ORDER BY
  order_by := vector ();
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 211)  -- ORDER
    {
      _pos := _pos + 1;
      DB.DBA.GQL_EXPECT (_tokens, _pos, 212);  -- BY
      order_by := DB.DBA.GQL_PARSE_SORT_ITEMS (_tokens, _pos);
    }

  -- Optional SKIP/OFFSET
  skip := null;
  tt := DB.DBA.GQL_PEEK (_tokens, _pos);
  if (tt = 216)  -- SKIP/OFFSET
    {
      _pos := _pos + 1;
      skip := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
    }

  -- Optional LIMIT
  limit := null;
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 215)  -- LIMIT
    {
      _pos := _pos + 1;
      limit := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
    }

  return vector ('RETURN', is_distinct, items, order_by, skip, limit);
}
;

create procedure DB.DBA.GQL_PARSE_RETURN_ITEMS (in _tokens any, inout _pos integer)
{
  declare items, item any;

  items := vector ();

  -- Handle RETURN * (all variables)
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 20)  -- STAR
    {
      _pos := _pos + 1;
      return vector (vector ('RETITEM', vector ('VAR', '*'), null));
    }

  while (1)
    {
      declare expr, alias any;
      expr := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
      alias := null;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 241)  -- AS
        {
          declare _alias_tok integer;
          _pos := _pos + 1;
          _alias_tok := DB.DBA.GQL_PEEK (_tokens, _pos);
          if (_alias_tok = 64)  -- IDENT: bare name, use as-is
            alias := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
          else if (_alias_tok = 68)  -- PARAM: ?name or $name, strip prefix
            {
              alias := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
              if (length (alias) > 0 and (aref (alias, 0) = 63 or aref (alias, 0) = 36))
                alias := subseq (alias, 1);
            }
          else if (_alias_tok = 71)  -- ACCENT_IDENT: `name`, strip backticks
            {
              alias := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
              if (length (alias) >= 2 and aref (alias, 0) = 96)
                alias := subseq (alias, 1, length (alias) - 1);
            }
          else if (_alias_tok >= 200)  -- keyword token used as alias name
            alias := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
          else
            signal ('GQ003', sprintf ('Expected identifier after AS at position %d', _pos));
          _pos := _pos + 1;
        }
      items := vector_concat (items, vector (vector ('RETITEM', expr, alias)));
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
        _pos := _pos + 1;
      else
        goto retitems_done;
    }
  retitems_done:
  return items;
}
;

create procedure DB.DBA.GQL_PARSE_SORT_ITEMS (in _tokens any, inout _pos integer)
{
  declare items, expr, dir, nulls_order any;

  items := vector ();
  while (1)
    {
      expr := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
      dir := 'ASC';
      nulls_order := null;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 213)  -- ASC
        { _pos := _pos + 1; dir := 'ASC'; }
      else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 214)  -- DESC
        { _pos := _pos + 1; dir := 'DESC'; }
      else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 288)  -- ASCENDING
        { _pos := _pos + 1; dir := 'ASC'; }
      else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 289)  -- DESCENDING
        { _pos := _pos + 1; dir := 'DESC'; }
      -- NULLS FIRST / NULLS LAST
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 519)  -- NULLS
        {
          _pos := _pos + 1;
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 438)  -- FIRST
            { _pos := _pos + 1; nulls_order := 'FIRST'; }
          else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 439)  -- LAST
            { _pos := _pos + 1; nulls_order := 'LAST'; }
          else
            signal ('GQ003', sprintf ('Expected FIRST or LAST after NULLS at position %d', _pos));
        }
      items := vector_concat (items, vector (vector ('SORT', expr, dir, nulls_order)));
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
        _pos := _pos + 1;
      else
        goto sort_done;
    }
  sort_done:
  return items;
}
;

create procedure DB.DBA.GQL_PARSE_ORDER_BY (in _tokens any, inout _pos integer)
{
  _pos := _pos + 1;  -- consume ORDER
  DB.DBA.GQL_EXPECT (_tokens, _pos, 212);  -- BY
  return vector ('ORDER', DB.DBA.GQL_PARSE_SORT_ITEMS (_tokens, _pos));
}
;

create procedure DB.DBA.GQL_PARSE_SKIP (in _tokens any, inout _pos integer)
{
  _pos := _pos + 1;  -- consume SKIP/OFFSET
  return vector ('SKIP', DB.DBA.GQL_PARSE_EXPR (_tokens, _pos));
}
;

create procedure DB.DBA.GQL_PARSE_LIMIT (in _tokens any, inout _pos integer)
{
  _pos := _pos + 1;  -- consume LIMIT
  return vector ('LIMIT', DB.DBA.GQL_PARSE_EXPR (_tokens, _pos));
}
;

----------------------------------------------------------------------
-- WHERE / FILTER
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_WHERE (in _tokens any, inout _pos integer)
{
  _pos := _pos + 1;
  return vector ('WHERE', DB.DBA.GQL_PARSE_EXPR (_tokens, _pos));
}
;

create procedure DB.DBA.GQL_PARSE_FILTER (in _tokens any, inout _pos integer)
{
  _pos := _pos + 1;
  return vector ('FILTER', DB.DBA.GQL_PARSE_EXPR (_tokens, _pos));
}
;

----------------------------------------------------------------------
-- INSERT
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_INSERT (in _tokens any, inout _pos integer)
{
  declare patterns, graph_ref any;
  declare is_property integer;
  _pos := _pos + 1;  -- consume INSERT
  -- Optional inline target graph: INSERT INTO [PROPERTY] GRAPH <g> (...)
  graph_ref := null;
  is_property := 0;
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 287)  -- INTO
    {
      _pos := _pos + 1;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 227)  -- PROPERTY
        {
          _pos := _pos + 1;
          is_property := 1;
        }
      DB.DBA.GQL_EXPECT (_tokens, _pos, 225);  -- GRAPH
      graph_ref := DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos);
    }
  patterns := DB.DBA.GQL_PARSE_PATTERN_LIST (_tokens, _pos);
  if (graph_ref is not null)
    {
      if (is_property)
        return vector ('INSERT_PROPERTY', patterns, graph_ref);
      return vector ('INSERT', patterns, graph_ref);
    }
  return vector ('INSERT', patterns);
}
;

create procedure DB.DBA.GQL_PARSE_CONSTRUCT (in _tokens any, inout _pos integer)
{
  declare patterns any;
  _pos := _pos + 1;  -- consume CONSTRUCT
  patterns := DB.DBA.GQL_PARSE_PATTERN_LIST (_tokens, _pos);
  return vector ('CONSTRUCT', patterns);
}
;

create procedure DB.DBA.GQL_PARSE_DESCRIBE (in _tokens any, inout _pos integer)
{
  declare items any;
  items := vector ();
  _pos := _pos + 1;  -- consume DESCRIBE

  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 20)  -- STAR
    {
      _pos := _pos + 1;
      return vector ('DESCRIBE', vector (vector ('VAR', '*')));
    }

  while (1)
    {
      items := vector_concat (items, vector (DB.DBA.GQL_PARSE_EXPR (_tokens, _pos)));
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
        _pos := _pos + 1;
      else
        goto describe_done;
    }
describe_done:
  return vector ('DESCRIBE', items);
}
;

----------------------------------------------------------------------
-- SET (reuses openCypher pattern)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_SET (in _tokens any, inout _pos integer)
{
  declare items, item, expr, pname_val any;
  declare var_name varchar;
  declare lbls any;
  declare tt, colon_pos, colon_count integer;

  _pos := _pos + 1;  -- consume SET
  items := vector ();

  while (1)
    {
      -- Handle PNAME_NS for SET var:Label
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 69)
        {
          pname_val := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
          colon_pos := strchr (pname_val, ':');
          if (colon_pos is not null and colon_pos > 0)
            {
              var_name := subseq (pname_val, 0, colon_pos);
              lbls := vector (subseq (pname_val, colon_pos + 1));
              _pos := _pos + 1;
              while (DB.DBA.GQL_PEEK (_tokens, _pos) = 7)  -- COLON
                {
                  _pos := _pos + 1;
                  lbls := vector_concat (lbls, vector (DB.DBA.GQL_PEEK_VAL (_tokens, _pos)));
                  _pos := _pos + 1;
                }
              items := vector_concat (items, vector (vector ('SETLABEL', var_name, lbls)));
              goto set_item_done;
            }
        }

      expr := DB.DBA.GQL_PARSE_ADD_EXPR (_tokens, _pos);
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);

      if (tt = 15)  -- EQ
        {
          _pos := _pos + 1;
          item := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
          if (aref (expr, 0) = 'VAR')
            items := vector_concat (items, vector (vector ('SETALL', aref (expr, 1), item, 0)));
          else
            items := vector_concat (items, vector (vector ('SETPROP', expr, item)));
        }
      else if (tt = 27)  -- PLUSEQ
        {
          _pos := _pos + 1;
          if (aref (expr, 0) = 'VAR')
            {
              item := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
              items := vector_concat (items, vector (vector ('SETALL', aref (expr, 1), item, 1)));
            }
          else
            signal ('GQ003', 'Expected variable before +=');
        }
      else if (tt = 7)  -- COLON
        {
          if (aref (expr, 0) = 'VAR')
            {
              lbls := vector ();
              while (DB.DBA.GQL_PEEK (_tokens, _pos) = 7)
                {
                  _pos := _pos + 1;
                  lbls := vector_concat (lbls, vector (DB.DBA.GQL_PEEK_VAL (_tokens, _pos)));
                  _pos := _pos + 1;
                }
              items := vector_concat (items, vector (vector ('SETLABEL', aref (expr, 1), lbls)));
            }
          else
            signal ('GQ003', 'Expected variable before :Label in SET');
        }
      else
        signal ('GQ003', 'Expected =, += or :Label in SET clause');

      set_item_done:
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)
        _pos := _pos + 1;
      else
        goto set_done;
    }
  set_done:
  return vector ('SET', items);
}
;

----------------------------------------------------------------------
-- REMOVE (reuses openCypher pattern)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_REMOVE (in _tokens any, inout _pos integer)
{
  declare items, expr any;
  declare tt integer;
  declare lbls any;

  _pos := _pos + 1;  -- consume REMOVE
  items := vector ();

  while (1)
    {
      expr := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);
      if (tt = 7)  -- COLON
        {
          if (aref (expr, 0) = 'VAR')
            {
              lbls := vector ();
              while (DB.DBA.GQL_PEEK (_tokens, _pos) = 7)
                {
                  _pos := _pos + 1;
                  lbls := vector_concat (lbls, vector (DB.DBA.GQL_PEEK_VAL (_tokens, _pos)));
                  _pos := _pos + 1;
                }
              items := vector_concat (items, vector (vector ('RMLABEL', aref (expr, 1), lbls)));
            }
          else
            signal ('GQ003', 'Expected variable before :Label in REMOVE');
        }
      else if (isarray (expr) and aref (expr, 0) = 'IRI'
               and not DB.DBA.GQL_IS_ABSOLUTE_IRI_NAME (aref (expr, 1))
               and strchr (aref (expr, 1), ':') is not null)
        {
          -- REMOVE n:Label lexes "n:Label" as a single prefixed-name token, so
          -- the COLON branch above never fires.  In REMOVE position a bare
          -- prefixed name means label removal (node n, label Label), not a
          -- property, so split it into an RMLABEL item.  (A property target is
          -- n.prop, which parses as a PROP node and keeps the RMPROP branch.)
          declare rraw, rvar, rlbl varchar;
          declare rcolon integer;
          rraw := aref (expr, 1);
          rcolon := strchr (rraw, ':');
          rvar := subseq (rraw, 0, rcolon);
          rlbl := subseq (rraw, rcolon + 1);
          items := vector_concat (items, vector (vector ('RMLABEL', rvar, vector (rlbl))));
        }
      else
        items := vector_concat (items, vector (vector ('RMPROP', expr)));

      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)
        _pos := _pos + 1;
      else
        goto remove_done;
    }
  remove_done:
  return vector ('REMOVE', items);
}
;

----------------------------------------------------------------------
-- DELETE
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_DELETE (in _tokens any, inout _pos integer, in _detach integer)
{
  declare items any;
  declare del_mode varchar;

  _pos := _pos + 1;  -- consume DELETE (DETACH was already consumed by caller)

  del_mode := 'NORMAL';
  items := vector ();   -- keep index 2 a well-formed array for DATA/WHERE modes too
                        -- (those return before the NORMAL item loop below)

  -- DELETE DATA (pattern) — ground-triple bulk delete
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 417)  -- DATA
    {
      _pos := _pos + 1;
      del_mode := 'DATA';
      declare patterns any;
      patterns := DB.DBA.GQL_PARSE_PATTERN_LIST (_tokens, _pos);
      return vector ('DELETE', _detach, items, del_mode, patterns);
    }

  -- DELETE WHERE (pattern) — shorthand: template = WHERE body
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 206)  -- WHERE
    {
      _pos := _pos + 1;
      del_mode := 'WHERE';
      declare patterns any;
      patterns := DB.DBA.GQL_PARSE_PATTERN_LIST (_tokens, _pos);
      return vector ('DELETE', _detach, items, del_mode, patterns);
    }

  items := vector ();
  while (1)
    {
      items := vector_concat (items, vector (DB.DBA.GQL_PARSE_EXPR (_tokens, _pos)));
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)
        _pos := _pos + 1;
      else
        goto delete_done;
    }
  delete_done:
  return vector ('DELETE', _detach, items, del_mode, null);
}
;

----------------------------------------------------------------------
-- USE <graph>
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_USE_GRAPH (in _tokens any, inout _pos integer)
{
  declare graph_expr any;
  declare is_property integer;
  _pos := _pos + 1;  -- consume USE
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 255)  -- ANY
    {
      _pos := _pos + 1;
      DB.DBA.GQL_EXPECT (_tokens, _pos, 225);  -- GRAPH
      return vector ('USE_ANY_GRAPH');
    }
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 330)  -- HOME_PROPERTY_GRAPH
    {
      _pos := _pos + 1;
      return vector ('USE_HOME_GRAPH');
    }
  is_property := 0;
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 227)  -- PROPERTY
    {
      _pos := _pos + 1;
      DB.DBA.GQL_EXPECT (_tokens, _pos, 225);  -- GRAPH
      is_property := 1;
    }
  graph_expr := DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos);
  if (is_property)
    return vector ('USE_PROPERTY', graph_expr);
  return vector ('USE', graph_expr);
}
;

----------------------------------------------------------------------
-- FROM <graph> | FROM NAMED <graph>   (SPARQL-style dataset clause)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_FROM_CLAUSE (in _tokens any, inout _pos integer)
{
  declare graph_expr any;
  declare kind varchar;

  _pos := _pos + 1;  -- consume FROM
  kind := 'FROM';
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 426)  -- NAMED
    { _pos := _pos + 1; kind := 'FROM_NAMED'; }
  graph_expr := DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos);
  return vector ('FROM_CLAUSE', kind, graph_expr);
}
;

----------------------------------------------------------------------
-- NOT FROM / NOT FROM NAMED — negative dataset restriction
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_NOT_FROM_CLAUSE (in _tokens any, inout _pos integer)
{
  declare graph_expr any;
  declare kind varchar;

  _pos := _pos + 1;  -- consume FROM (NOT already consumed)
  kind := 'NOT_FROM';
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 426)  -- NAMED
    { _pos := _pos + 1; kind := 'NOT_FROM_NAMED'; }
  graph_expr := DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos);
  return vector ('FROM_CLAUSE', kind, graph_expr);
}
;

----------------------------------------------------------------------
-- SERVICE [SILENT] <endpoint> { ...clauses... }
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_SERVICE (in _tokens any, inout _pos integer)
{
  declare endpoint_expr, query_ast any;
  declare is_silent integer;

  _pos := _pos + 1;  -- consume SERVICE
  is_silent := 0;
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 420)  -- SILENT
    { _pos := _pos + 1; is_silent := 1; }
  endpoint_expr := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
  DB.DBA.GQL_EXPECT (_tokens, _pos, 5);  -- LBRACE
  query_ast := DB.DBA.GQL_PARSE_COMPOSITE_QUERY (_tokens, _pos);
  DB.DBA.GQL_EXPECT (_tokens, _pos, 6);  -- RBRACE
  return vector ('SERVICE', endpoint_expr, query_ast, is_silent);
}
;

create procedure DB.DBA.GQL_PARSE_PREFIX (in _tokens any, inout _pos integer)
{
  declare prefix_name, uri_val, full_name varchar;
  declare colon_pos integer;

  _pos := _pos + 1;  -- consume PREFIX

  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 7)  -- default prefix
    { prefix_name := ''; _pos := _pos + 1; }
  else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 64
          or DB.DBA.GQL_PEEK (_tokens, _pos) >= 200)  -- IDENT or keyword-as-name (e.g. schema)
    {
      prefix_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 1;
      DB.DBA.GQL_EXPECT (_tokens, _pos, 7);  -- COLON
    }
  else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 69)  -- PNAME_NS
    {
      full_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
      colon_pos := strchr (full_name, ':');
      if (colon_pos is not null)
        prefix_name := subseq (full_name, 0, colon_pos);
      else
        prefix_name := full_name;
      _pos := _pos + 1;
    }
  else
    signal ('GQ003', sprintf ('Expected prefix name at position %d', _pos));

  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 70)  -- IRIREF
    { uri_val := DB.DBA.GQL_PEEK_VAL (_tokens, _pos); _pos := _pos + 1; }
  else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 65 or DB.DBA.GQL_PEEK (_tokens, _pos) = 72)  -- STRING
    { uri_val := DB.DBA.GQL_PEEK_VAL (_tokens, _pos); _pos := _pos + 1; }
  else
    signal ('GQ003', sprintf ('Expected URI after PREFIX at position %d', _pos));

  return vector ('PREFIX', prefix_name, uri_val);
}
;

create procedure DB.DBA.GQL_PARSE_BASE (in _tokens any, inout _pos integer)
{
  declare uri_val varchar;

  _pos := _pos + 1;  -- consume BASE
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 70)  -- IRIREF
    { uri_val := DB.DBA.GQL_PEEK_VAL (_tokens, _pos); _pos := _pos + 1; }
  else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 65 or DB.DBA.GQL_PEEK (_tokens, _pos) = 72)  -- STRING
    { uri_val := DB.DBA.GQL_PEEK_VAL (_tokens, _pos); _pos := _pos + 1; }
  else
    signal ('GQ003', sprintf ('Expected URI after BASE at position %d', _pos));

  return vector ('BASE', uri_val);
}
;

create procedure DB.DBA.GQL_PARSE_DEFINE (in _tokens any, inout _pos integer)
{
  declare key_name varchar;
  declare val_expr any;

  _pos := _pos + 1;  -- consume DEFINE
  if (DB.DBA.GQL_PEEK (_tokens, _pos) <> 64 and DB.DBA.GQL_PEEK (_tokens, _pos) <> 69)
    signal ('GQ003', sprintf ('Expected DEFINE key at position %d', _pos));
  key_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
  _pos := _pos + 1;
  val_expr := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
  return vector ('DEFINE', key_name, val_expr);
}
;

create procedure DB.DBA.GQL_PARSE_VERSION (in _tokens any, inout _pos integer)
{
  declare version_str varchar;

  _pos := _pos + 1;  -- consume VERSION
  if (DB.DBA.GQL_PEEK (_tokens, _pos) <> 65 and DB.DBA.GQL_PEEK (_tokens, _pos) <> 72)
    signal ('GQ003', sprintf ('Expected version string after VERSION at position %d', _pos));
  version_str := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
  _pos := _pos + 1;
  return vector ('VERSION', version_str);
}
;

create procedure DB.DBA.GQL_PARSE_FORCE_OPTION (in _tokens any, inout _pos integer)
{
  _pos := _pos + 1;  -- consume FORCE
  DB.DBA.GQL_EXPECT (_tokens, _pos, 530);  -- CAMELCASE
  return vector ('FORCE_CAMELCASE');
}
;

----------------------------------------------------------------------
-- FOR / LET
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_FOR (in _tokens any, inout _pos integer)
{
  declare var_name varchar;
  declare expr, ordinality_offset any;
  _pos := _pos + 1;  -- consume FOR
  var_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
  DB.DBA.GQL_EXPECT (_tokens, _pos, 64);  -- IDENT
  DB.DBA.GQL_EXPECT (_tokens, _pos, 239);  -- IN
  expr := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);

  -- Optional WITH ORDINALITY / WITH OFFSET
  ordinality_offset := null;
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 264)  -- WITH
    {
      _pos := _pos + 1;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 412)  -- ORDINALITY
        { _pos := _pos + 1; ordinality_offset := 'ORDINALITY'; }
      else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 216)  -- OFFSET
        { _pos := _pos + 1; ordinality_offset := 'OFFSET'; }
      else
        signal ('GQ003', sprintf ('Expected ORDINALITY or OFFSET after WITH at position %d', _pos));
    }

  return vector ('FOR', var_name, expr, ordinality_offset);
}
;

----------------------------------------------------------------------
-- UNNEST
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_UNNEST (in _tokens any, inout _pos integer)
{
  declare var_name varchar;
  declare expr any;
  _pos := _pos + 1;  -- consume UNNEST
  DB.DBA.GQL_EXPECT (_tokens, _pos, 1);  -- LPAREN
  expr := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
  DB.DBA.GQL_EXPECT (_tokens, _pos, 241);  -- AS
  var_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
  DB.DBA.GQL_EXPECT (_tokens, _pos, 64);  -- IDENT
  DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
  return vector ('UNNEST', var_name, expr);
}
;

create procedure DB.DBA.GQL_PARSE_LET (in _tokens any, inout _pos integer)
{
  declare var_name varchar;
  declare expr any;
  _pos := _pos + 1;  -- consume LET
  var_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
  DB.DBA.GQL_EXPECT (_tokens, _pos, 64);  -- IDENT
  DB.DBA.GQL_EXPECT (_tokens, _pos, 15);  -- EQ
  expr := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
  return vector ('LET', var_name, expr);
}
;

----------------------------------------------------------------------
-- GRAPH binding: GRAPH var = graphExpression
-- Binds a variable to a graph reference for subsequent MATCH clauses.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_GRAPH_BINDING (in _tokens any, inout _pos integer)
{
  declare var_name varchar;
  declare graph_ref any;
  _pos := _pos + 1;  -- consume GRAPH
  var_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
  DB.DBA.GQL_EXPECT (_tokens, _pos, 64);  -- IDENT
  DB.DBA.GQL_EXPECT (_tokens, _pos, 15);  -- EQ
  graph_ref := DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos);
  return vector ('LET_GRAPH', var_name, graph_ref);
}
;

----------------------------------------------------------------------
-- TABLE binding: TABLE var = bindingTableExpression
-- Binds a variable to a tabular result (sub-query).
-- Currently supports: TABLE var = ( queryExpression )
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_TABLE_BINDING (in _tokens any, inout _pos integer)
{
  declare var_name varchar;
  declare sub_query any;
  _pos := _pos + 1;  -- consume TABLE
  var_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
  DB.DBA.GQL_EXPECT (_tokens, _pos, 64);  -- IDENT
  DB.DBA.GQL_EXPECT (_tokens, _pos, 15);  -- EQ
  -- Parse a sub-query enclosed in parentheses
  DB.DBA.GQL_EXPECT (_tokens, _pos, 1);  -- LPAREN
  sub_query := DB.DBA.GQL_PARSE_COMPOSITE_QUERY (_tokens, _pos);
  DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
  return vector ('LET_TABLE', var_name, sub_query);
}
;

----------------------------------------------------------------------
-- GROUP BY
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_GROUP_BY (in _tokens any, inout _pos integer)
{
  declare items, expr any;
  declare grp_sets any;
  declare set_items any;
  _pos := _pos + 1;  -- consume GROUP
  DB.DBA.GQL_EXPECT (_tokens, _pos, 212);  -- BY

  -- GROUPING SETS (set1, set2, ...)
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 539)  -- GROUPING
    {
      _pos := _pos + 1;
      DB.DBA.GQL_EXPECT (_tokens, _pos, 540);  -- SETS
      DB.DBA.GQL_EXPECT (_tokens, _pos, 1);  -- LPAREN
      grp_sets := vector ();
      while (1)
        {
          DB.DBA.GQL_EXPECT (_tokens, _pos, 1);  -- LPAREN for each set
          set_items := vector ();
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 2)  -- RPAREN (empty set)
            { _pos := _pos + 1; }
          else
            {
              while (1)
                {
                  expr := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
                  set_items := vector_concat (set_items, vector (expr));
                  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
                    _pos := _pos + 1;
                  else
                    goto set_items_done;
                }
            set_items_done:
              DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
            }
          grp_sets := vector_concat (grp_sets, vector (set_items));
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
            _pos := _pos + 1;
          else
            goto sets_done;
        }
    sets_done:
      DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
      return vector ('GROUP_SETS', grp_sets);
    }

  -- CUBE (expr1, expr2, ...)
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 541)  -- CUBE
    {
      _pos := _pos + 1;
      DB.DBA.GQL_EXPECT (_tokens, _pos, 1);  -- LPAREN
      items := vector ();
      if (DB.DBA.GQL_PEEK (_tokens, _pos) <> 2)  -- not RPAREN
        {
          while (1)
            {
              expr := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
              items := vector_concat (items, vector (expr));
              if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
                _pos := _pos + 1;
              else
                goto cube_done;
            }
        }
      cube_done:
      DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
      return vector ('GROUP_CUBE', items);
    }

  -- ROLLUP (expr1, expr2, ...)
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 542)  -- ROLLUP
    {
      _pos := _pos + 1;
      DB.DBA.GQL_EXPECT (_tokens, _pos, 1);  -- LPAREN
      items := vector ();
      if (DB.DBA.GQL_PEEK (_tokens, _pos) <> 2)  -- not RPAREN
        {
          while (1)
            {
              expr := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
              items := vector_concat (items, vector (expr));
              if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
                _pos := _pos + 1;
              else
                goto rollup_done;
            }
        }
      rollup_done:
      DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
      return vector ('GROUP_ROLLUP', items);
    }

  items := vector ();
  -- Empty grouping set: GROUP BY ()
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 1)  -- LPAREN
    {
      _pos := _pos + 1;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 2)  -- RPAREN (empty grouping set)
        { _pos := _pos + 1; return vector ('GROUP', items); }
      -- Grouping elements enclosed in parens
      while (1)
        {
          expr := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
          items := vector_concat (items, vector (expr));
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
            _pos := _pos + 1;
          else
            goto group_paren_done;
        }
    group_paren_done:
      DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
      return vector ('GROUP', items);
    }

  -- Comma-separated grouping expressions
  while (1)
    {
      expr := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
      items := vector_concat (items, vector (expr));
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
        _pos := _pos + 1;
      else
        goto group_done;
    }
  group_done:
  return vector ('GROUP', items);
}
;

----------------------------------------------------------------------
-- HAVING
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_HAVING (in _tokens any, inout _pos integer)
{
  declare expr any;
  _pos := _pos + 1;  -- consume HAVING
  expr := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
  return vector ('HAVING', expr);
}
;

----------------------------------------------------------------------
-- Expression atom (simplified for Phase 3 — full expr parser in Phase 4)
-- Handles: literals, variables, property access, basic comparisons
----------------------------------------------------------------------

-- Expression parser is defined in gql_expr.sql.
-- Parser procedures reference DB.DBA.GQL_PARSE_EXPR which is resolved at runtime
-- (Virtuoso PL does not check procedure existence at CREATE PROCEDURE time).

----------------------------------------------------------------------
-- Pattern parsers
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_PATTERN_LIST (in _tokens any, inout _pos integer)
{
  declare patterns, pat any;
  patterns := vector ();
  pat := DB.DBA.GQL_PARSE_PATTERN (_tokens, _pos);
  patterns := vector_concat (patterns, vector (pat));
  while (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
    {
      _pos := _pos + 1;
      pat := DB.DBA.GQL_PARSE_PATTERN (_tokens, _pos);
      patterns := vector_concat (patterns, vector (pat));
    }
  return patterns;
}
;

create procedure DB.DBA.GQL_PARSE_PATTERN (in _tokens any, inout _pos integer)
{
  declare elements, elem any;
  declare path_var varchar;
  declare tt integer;

  path_var := null;

  -- Check for path variable: ident =
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 64)  -- IDENT
    {
      if (_pos + 1 < length (_tokens) and DB.DBA.GQL_PEEK (_tokens, _pos + 1) = 15)  -- EQ
        {
          path_var := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 2;
        }
    }

  elements := vector ();

  -- First element must be a node
  elem := DB.DBA.GQL_PARSE_NODE_PATTERN (_tokens, _pos);
  elements := vector_concat (elements, vector (elem));

  -- Then alternating edge-node pairs
  while (1)
    {
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);
      if (tt = 12        -- DASH
          or tt = 11     -- ARROW_L
          or tt = 10     -- ARROW_R
          or tt = 32     -- TILDE
          or tt = 46     -- MINUS_LEFT_BRACKET (-[)
          or tt = 47     -- TILDE_LEFT_BRACKET (~[)
          or tt = 49     -- SLASH_MINUS
          or tt = 35     -- ARROW_R_PIPE
          or tt = 36)    -- PIPE_ARROW_L
        {
          elem := DB.DBA.GQL_PARSE_EDGE_PATTERN (_tokens, _pos);
          elements := vector_concat (elements, vector (elem));
          elem := DB.DBA.GQL_PARSE_NODE_PATTERN (_tokens, _pos);
          elements := vector_concat (elements, vector (elem));
        }
      else
        goto pattern_done;
    }
  pattern_done:

  if (path_var is not null)
    return vector ('PATH', path_var, elements);
  return vector ('PATTERN', elements);
}
;

----------------------------------------------------------------------
-- Node pattern: (var:Label1:Label2 {prop: val, ...})
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_TYPE_NAME_VALUE (in _tokens any, inout _pos integer)
{
  declare type_name varchar;
  type_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
  _pos := _pos + 1;
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 7)
    {
      _pos := _pos + 1;
      type_name := concat (type_name, ':', DB.DBA.GQL_PEEK_VAL (_tokens, _pos));
      _pos := _pos + 1;
    }
  return type_name;
}
;

create procedure DB.DBA.GQL_PARSE_COLON_TYPE_NAME (in _tokens any, inout _pos integer, in _sep integer)
{
  declare type_name varchar;
  type_name := DB.DBA.GQL_PARSE_TYPE_NAME_VALUE (_tokens, _pos);
  if (_sep = 30)
    return concat ('::', type_name);
  return type_name;
}
;

----------------------------------------------------------------------
-- Label expression parser: handles & (AND), | (OR), ! (NOT), % (wildcard), ()
-- Grammar: labelExpression : !labelExpression | labelExpression & labelExpression
--          | labelExpression | labelExpression | % | (labelExpression)
-- Precedence: ! (highest) > & > | (lowest)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_LABEL_EXPR_PRIMARY (in _tokens any, inout _pos integer)
{
  declare tt integer;
  tt := DB.DBA.GQL_PEEK (_tokens, _pos);
  if (tt = 22)  -- PERCENT (wildcard)
    { _pos := _pos + 1; return vector ('LABEL_WILDCARD'); }
  if (tt = 1)  -- LPAREN (sub-expression)
    {
      declare expr any;
      _pos := _pos + 1;
      expr := DB.DBA.GQL_PARSE_LABEL_EXPR_OR (_tokens, _pos);
      DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN (increments _pos)
      return expr;
    }
  if (tt >= 64)  -- IDENT or keyword
    {
      declare label_name varchar;
      label_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 1;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 7)  -- COLON for prefixed name
        {
          _pos := _pos + 1;
          label_name := concat (label_name, ':', DB.DBA.GQL_PEEK_VAL (_tokens, _pos));
          _pos := _pos + 1;
        }
      return label_name;
    }
  signal ('GQ004', sprintf ('Expected label name, %% or ( in label expression at position %d', _pos));
}
;

create procedure DB.DBA.GQL_PARSE_LABEL_EXPR_UNARY (in _tokens any, inout _pos integer)
{
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 24)  -- BANG (NOT)
    {
      _pos := _pos + 1;
      return vector ('LABEL_NOT', DB.DBA.GQL_PARSE_LABEL_EXPR_UNARY (_tokens, _pos));
    }
  return DB.DBA.GQL_PARSE_LABEL_EXPR_PRIMARY (_tokens, _pos);
}
;

create procedure DB.DBA.GQL_PARSE_LABEL_EXPR_AND (in _tokens any, inout _pos integer, in _first any)
{
  declare lhs any;
  if (_first is not null and _first <> '')
    lhs := _first;
  else
    lhs := DB.DBA.GQL_PARSE_LABEL_EXPR_UNARY (_tokens, _pos);
  while (DB.DBA.GQL_PEEK (_tokens, _pos) = 29)  -- AMPERSAND
    {
      declare rhs any;
      _pos := _pos + 1;
      rhs := DB.DBA.GQL_PARSE_LABEL_EXPR_UNARY (_tokens, _pos);
      if (isvector (lhs) and aref (lhs, 0) = 'LABEL_AND')
        lhs := vector ('LABEL_AND', vector_concat (aref (lhs, 1), vector (rhs)));
      else
        lhs := vector ('LABEL_AND', vector (lhs, rhs));
    }
  return lhs;
}
;

create procedure DB.DBA.GQL_PARSE_LABEL_EXPR_OR (in _tokens any, inout _pos integer)
{
  declare lhs any;
  lhs := DB.DBA.GQL_PARSE_LABEL_EXPR_AND (_tokens, _pos, null);
  while (DB.DBA.GQL_PEEK (_tokens, _pos) = 25 or DB.DBA.GQL_PEEK (_tokens, _pos) = 233)  -- PIPE or OR
    {
      declare rhs any;
      _pos := _pos + 1;
      rhs := DB.DBA.GQL_PARSE_LABEL_EXPR_AND (_tokens, _pos, null);
      if (isvector (lhs) and aref (lhs, 0) = 'LABEL_OR')
        lhs := vector ('LABEL_OR', vector_concat (aref (lhs, 1), vector (rhs)));
      else
        lhs := vector ('LABEL_OR', vector (lhs, rhs));
    }
  return lhs;
}
;

-- Entry point: parse a full label expression.
-- _first_label: optional pre-parsed first label (for PNAME_NS var:Label case)
create procedure DB.DBA.GQL_PARSE_LABEL_EXPRESSION (in _tokens any, inout _pos integer, in _first_label any)
{
  declare lhs any;
  lhs := DB.DBA.GQL_PARSE_LABEL_EXPR_AND (_tokens, _pos, _first_label);
  while (DB.DBA.GQL_PEEK (_tokens, _pos) = 25 or DB.DBA.GQL_PEEK (_tokens, _pos) = 233)  -- PIPE or OR
    {
      declare rhs any;
      _pos := _pos + 1;
      rhs := DB.DBA.GQL_PARSE_LABEL_EXPR_AND (_tokens, _pos, null);
      if (isvector (lhs) and aref (lhs, 0) = 'LABEL_OR')
        lhs := vector ('LABEL_OR', vector_concat (aref (lhs, 1), vector (rhs)));
      else
        lhs := vector ('LABEL_OR', vector (lhs, rhs));
    }
  return lhs;
}
;

create procedure DB.DBA.GQL_PARSE_LABEL_ALTERNATIVES (in _tokens any, inout _pos integer, in _first_label any)
{
  declare labels any;
  labels := vector (_first_label);

  while (DB.DBA.GQL_PEEK (_tokens, _pos) = 25 or DB.DBA.GQL_PEEK (_tokens, _pos) = 233)
    {
      declare sep integer;
      _pos := _pos + 1;
      sep := DB.DBA.GQL_PEEK (_tokens, _pos);
      if (sep = 7 or sep = 30)
        {
          _pos := _pos + 1;
          labels := vector_concat (labels,
            vector (DB.DBA.GQL_PARSE_COLON_TYPE_NAME (_tokens, _pos, sep)));
        }
      else
        labels := vector_concat (labels,
          vector (DB.DBA.GQL_PARSE_TYPE_NAME_VALUE (_tokens, _pos)));
    }

  if (length (labels) = 1)
    return _first_label;
  return vector ('LABEL_OR', labels);
}
;

create procedure DB.DBA.GQL_PARSE_NODE_PATTERN (in _tokens any, inout _pos integer)
{
  declare var_name varchar;
  declare labels, props any;
  declare tt integer;
  declare pname_val varchar;
  declare colon_pos integer;
  declare label_name varchar;

  var_name := null;
  labels := vector ();
  props := vector ();

  DB.DBA.GQL_EXPECT (_tokens, _pos, 1);  -- LPAREN

  tt := DB.DBA.GQL_PEEK (_tokens, _pos);

  -- Empty node ()
  if (tt = 2)
    { _pos := _pos + 1; return vector ('NODE', null, labels, props); }

  -- Handle PNAME_NS: tokenizer produced var:Label as single token
  if (tt = 69)
    {
      pname_val := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
      colon_pos := strchr (pname_val, ':');
      if (colon_pos is not null and colon_pos > 0)
        {
          var_name := subseq (pname_val, 0, colon_pos);
          label_name := subseq (pname_val, colon_pos + 1);
          if (DB.DBA.GQL_PEEK (_tokens, _pos + 1) = 7)
            {
              _pos := _pos + 1;
              label_name := concat (label_name, ':', DB.DBA.GQL_PEEK_VAL (_tokens, _pos + 1));
              _pos := _pos + 1;
            }
          _pos := _pos + 1;
          labels := vector_concat (labels,
            vector (DB.DBA.GQL_PARSE_LABEL_EXPRESSION (_tokens, _pos, label_name)));
        }
      else
        {
          var_name := pname_val;
          _pos := _pos + 1;
        }
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);
    }
  -- Variable name
  else if (tt = 64)  -- IDENT
    {
      var_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 1;
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);
    }

  -- Colon-introduced labels.  Single colon supports full label expressions
  -- (&, |, !, %, ()); double colon is a base-relative label, e.g. BASE <...#> MATCH (t::Truck).
  if (tt = 7 or tt = 30)  -- COLON or DOUBLECOLON
    {
      while (DB.DBA.GQL_PEEK (_tokens, _pos) = 7 or DB.DBA.GQL_PEEK (_tokens, _pos) = 30)
        {
          declare label_sep integer;
          declare parsed_label any;
          label_sep := DB.DBA.GQL_PEEK (_tokens, _pos);
          _pos := _pos + 1;
          if (label_sep = 30)  -- DOUBLECOLON: base-relative label (no expression)
            {
              parsed_label := DB.DBA.GQL_PARSE_COLON_TYPE_NAME (_tokens, _pos, label_sep);
              parsed_label := DB.DBA.GQL_PARSE_LABEL_ALTERNATIVES (_tokens, _pos, parsed_label);
            }
          else
            parsed_label := DB.DBA.GQL_PARSE_LABEL_EXPRESSION (_tokens, _pos, null);
          labels := vector_concat (labels, vector (parsed_label));
        }
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);
    }

  -- Properties
  if (tt = 5)  -- LBRACE
    {
      props := DB.DBA.GQL_PARSE_PROPERTIES (_tokens, _pos);
    }

  DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
  return vector ('NODE', var_name, labels, props);
}
;

----------------------------------------------------------------------
-- Edge path cost/weight clause
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_EDGE_COST (in _tokens any, inout _pos integer)
{
  declare tt integer;
  declare kw varchar;

  tt := DB.DBA.GQL_PEEK (_tokens, _pos);
  if (tt <> 64)  -- IDENT; WEIGHT/COST are intentionally not lexer keywords
    return null;

  kw := upper (DB.DBA.GQL_PEEK_VAL (_tokens, _pos));
  if (kw <> 'WEIGHT' and kw <> 'COST')
    return null;

  _pos := _pos + 1;
  return DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
}
;

----------------------------------------------------------------------
-- Edge pattern with GQL direction, quantifiers, and path cost
--   -[...]->, <-[...]-, -[...]-, ~[...]~, /.../, etc.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_EDGE_PATTERN (in _tokens any, inout _pos integer)
{
  declare var_name, direction varchar;
  declare types, props, quantifier, cost_expr any;
  declare tt, start_dir integer;
  declare pname_val varchar;
  declare type_name varchar;
  declare path_mode varchar;
  declare colon_pos integer;
  declare annot_mode integer;
  declare triple_term_mode integer;
  declare reifier_name varchar;

  var_name := null;
  types := vector ();
  props := vector ();
  quantifier := null;
  cost_expr := null;
  path_mode := null;
  start_dir := 0;
  annot_mode := 0;
  triple_term_mode := 0;
  reifier_name := null;

  tt := DB.DBA.GQL_PEEK (_tokens, _pos);

  -- Determine start direction
  if (tt = 11)  -- <- (ARROW_L)
    { direction := 'LEFT'; _pos := _pos + 1; }
  else if (tt = 10)  -- ->
    { direction := 'RIGHT'; _pos := _pos + 1; }
  else if (tt = 12)  -- -
    { direction := 'RIGHT'; _pos := _pos + 1; }
  else if (tt = 32)  -- ~
    { direction := 'UNDIRECTED'; _pos := _pos + 1; }
  else if (tt = 46)  -- -[
    { direction := 'RIGHT'; start_dir := 1; _pos := _pos + 1; }
  else if (tt = 47)  -- ~[
    { direction := 'UNDIRECTED'; start_dir := 1; _pos := _pos + 1; }
  else if (tt = 49)  -- /- (SLASH_MINUS)
    { direction := 'UNDIRECTED'; _pos := _pos + 1; }
  else if (tt = 35)  -- ->| (ARROW_R_PIPE)
    { direction := 'RIGHT'; _pos := _pos + 1; }
  else if (tt = 36)  -- |-> (PIPE_ARROW_L)
    { direction := 'RIGHT'; _pos := _pos + 1; }
  else
    signal ('GQ003', sprintf ('Expected edge-pattern start at position %d (got type %d: ''%s'')',
            _pos, tt, DB.DBA.GQL_PEEK_VAL (_tokens, _pos)));

  tt := DB.DBA.GQL_PEEK (_tokens, _pos);

  -- Optional bracket section [...]
  if (tt = 3 or start_dir = 1)  -- LBRACKET or combined -[
    {
      if (tt = 3)
        _pos := _pos + 1;
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);

      -- Handle PNAME_NS for var:Type
      if (tt = 69)
        {
          pname_val := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
          colon_pos := strchr (pname_val, ':');
          if (colon_pos is not null and colon_pos > 0)
            {
              var_name := subseq (pname_val, 0, colon_pos);
              type_name := subseq (pname_val, colon_pos + 1);
              if (DB.DBA.GQL_PEEK (_tokens, _pos + 1) = 7)
                {
                  _pos := _pos + 1;
                  type_name := concat (type_name, ':', DB.DBA.GQL_PEEK_VAL (_tokens, _pos + 1));
                  _pos := _pos + 1;
                }
              _pos := _pos + 1;
              types := vector_concat (types,
                vector (DB.DBA.GQL_PARSE_LABEL_EXPRESSION (_tokens, _pos, type_name)));
            }
          else
            {
              var_name := pname_val;
              _pos := _pos + 1;
            }
          tt := DB.DBA.GQL_PEEK (_tokens, _pos);
        }
      -- Variable name
      else if (tt = 64)  -- IDENT
        {
          var_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 1;
          tt := DB.DBA.GQL_PEEK (_tokens, _pos);
        }

      -- Colon-introduced edge types (supports full label expressions)
      if (tt = 7)  -- COLON
        {
          _pos := _pos + 1;
          declare edge_label_expr any;
          edge_label_expr := DB.DBA.GQL_PARSE_LABEL_EXPRESSION (_tokens, _pos, null);
          types := vector_concat (types, vector (edge_label_expr));
          -- Additional colon-separated type expressions (conjunction)
          while (DB.DBA.GQL_PEEK (_tokens, _pos) = 7)  -- COLON
            {
              _pos := _pos + 1;
              edge_label_expr := DB.DBA.GQL_PARSE_LABEL_EXPRESSION (_tokens, _pos, null);
              types := vector_concat (types, vector (edge_label_expr));
            }
          tt := DB.DBA.GQL_PEEK (_tokens, _pos);
        }

      if (cost_expr is null)
        cost_expr := DB.DBA.GQL_PARSE_EDGE_COST (_tokens, _pos);
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);

      -- Path mode: WALK (default), ACYCLIC (t_no_cycles), SIMPLE (t_distinct), TRAIL (t_trail)
      if (tt = 272        -- WALK
          or tt = 440     -- TRAIL
          or tt = 360     -- SIMPLE
          or tt = 343)    -- ACYCLIC
        {
          if (tt = 272)
            path_mode := 'WALK';
          else if (tt = 440)
            path_mode := 'TRAIL';
          else if (tt = 360)
            path_mode := 'SIMPLE';
          else
            path_mode := 'ACYCLIC';
          _pos := _pos + 1;
          tt := DB.DBA.GQL_PEEK (_tokens, _pos);
        }

      -- Advanced transitive options: T_CYCLES_ONLY, T_END_FLAG, T_FINAL_AS,
      -- T_NO_ORDER, BIJECTION — collected as comma-separated flags
      declare trans_extra varchar;
      trans_extra := '';
      while (tt = 534 or tt = 535 or tt = 536 or tt = 537 or tt = 538)
        {
          if (tt = 534) trans_extra := concat (trans_extra, ', t_cycles_only');
          else if (tt = 535) trans_extra := concat (trans_extra, ', t_end_flag');
          else if (tt = 536) trans_extra := concat (trans_extra, ', t_final_as');
          else if (tt = 537) trans_extra := concat (trans_extra, ', t_no_order');
          else if (tt = 538) trans_extra := concat (trans_extra, ', bijection');
          _pos := _pos + 1;
          tt := DB.DBA.GQL_PEEK (_tokens, _pos);
        }
      -- Store in path_mode as suffix if any extra flags were collected
      if (trans_extra <> '' and path_mode is null)
        path_mode := concat ('WALK', trans_extra);
      else if (trans_extra <> '')
        path_mode := concat (path_mode, trans_extra);

      if (cost_expr is null)
        cost_expr := DB.DBA.GQL_PARSE_EDGE_COST (_tokens, _pos);
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);

      -- Quantifier: *, +, ?, .., *N, *N..M
      if (tt = 20        -- STAR
          or tt = 19     -- PLUS
          or tt = 42     -- QUESTION
          or tt = 26)    -- DOTDOT (shorthand *0..)
        quantifier := DB.DBA.GQL_PARSE_QUANTIFIER (_tokens, _pos);

      tt := DB.DBA.GQL_PEEK (_tokens, _pos);

      -- Advanced transitive options may also follow the quantifier
      -- (e.g. [:KNOWS* T_CYCLES_ONLY]); collect them the same way.
      trans_extra := '';
      while (tt = 534 or tt = 535 or tt = 536 or tt = 537 or tt = 538)
        {
          if (tt = 534) trans_extra := concat (trans_extra, ', t_cycles_only');
          else if (tt = 535) trans_extra := concat (trans_extra, ', t_end_flag');
          else if (tt = 536) trans_extra := concat (trans_extra, ', t_final_as');
          else if (tt = 537) trans_extra := concat (trans_extra, ', t_no_order');
          else if (tt = 538) trans_extra := concat (trans_extra, ', bijection');
          _pos := _pos + 1;
          tt := DB.DBA.GQL_PEEK (_tokens, _pos);
        }
      if (trans_extra <> '' and path_mode is null)
        path_mode := concat ('WALK', trans_extra);
      else if (trans_extra <> '')
        path_mode := concat (path_mode, trans_extra);

      if (cost_expr is null)
        cost_expr := DB.DBA.GQL_PARSE_EDGE_COST (_tokens, _pos);
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);

      -- Brace: could be {min,max} quantifier, {props}, or {| props |} annotation
      if (tt = 5)  -- LBRACE
        {
          declare _qsave, _next integer;
          _qsave := _pos;
          _pos := _pos + 1;  -- skip {
          _next := DB.DBA.GQL_PEEK (_tokens, _pos);
          if (_next = 66 and (_pos + 1 < length (_tokens)
              and (DB.DBA.GQL_PEEK (_tokens, _pos + 1) = 9     -- COMMA
                   or DB.DBA.GQL_PEEK (_tokens, _pos + 1) = 6)))  -- RBRACE
            { _pos := _qsave; quantifier := DB.DBA.GQL_PARSE_QUANTIFIER (_tokens, _pos); }
          else if (_next = 25)  -- PIPE → {| props |} RDF 1.2 annotation syntax
            { _pos := _qsave; props := DB.DBA.GQL_PARSE_ANNOTATION_PROPERTIES (_tokens, _pos); annot_mode := 1; }
          else
            { _pos := _qsave; props := DB.DBA.GQL_PARSE_PROPERTIES (_tokens, _pos); }
          tt := DB.DBA.GQL_PEEK (_tokens, _pos);
        }

      -- Properties (only if LBRACE wasn't consumed as quantifier or props above)
      if (tt = 5)  -- LBRACE
        {
          if (DB.DBA.GQL_PEEK (_tokens, _pos + 1) = 25)  -- PIPE → annotation
            { props := DB.DBA.GQL_PARSE_ANNOTATION_PROPERTIES (_tokens, _pos); annot_mode := 1; }
          else
            props := DB.DBA.GQL_PARSE_PROPERTIES (_tokens, _pos);
        }

      -- RDF 1.2 triple-term / reified-triple property syntax:
      --   <<( props )>>   → explicit triple-term mode (standard RDF 1.2)
      --   << props >>      → reified-triple mode (shorthand)
      -- Optional ~ :iri or ~ var after props names the reifier.
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);
      if (tt = 420)  -- '<<'
        {
          _pos := _pos + 1;  -- consume <<
          -- Optional '(' for triple-term form <<( ... )>>
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 1)  -- '('
            {
              _pos := _pos + 1;  -- consume (
              triple_term_mode := 1;  -- explicit triple-term
            }
          else
            triple_term_mode := 2;  -- reified-triple shorthand
          -- Parse properties (bare key:value, no enclosing braces)
          props := DB.DBA.GQL_PARSE_PROPERTIES_BARE (_tokens, _pos);
          -- Optional ~ reifier
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 32)  -- '~'
            {
              _pos := _pos + 1;  -- consume ~
              -- Optional IRI or variable name after ~
              tt := DB.DBA.GQL_PEEK (_tokens, _pos);
              if (tt = 70)  -- IRIREF
                { reifier_name := concat ('<', DB.DBA.GQL_PEEK_VAL (_tokens, _pos), '>'); _pos := _pos + 1; }
              else if (tt = 2)  -- IDENT (variable or prefixed name)
                { reifier_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos); _pos := _pos + 1; }
              -- If nothing follows ~, a fresh blank node is allocated in codegen
            }
          -- Close: )>> or >>
          if (triple_term_mode = 1)
            DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- ')'
          DB.DBA.GQL_EXPECT (_tokens, _pos, 421);  -- '>>'
          tt := DB.DBA.GQL_PEEK (_tokens, _pos);
        }

      tt := DB.DBA.GQL_PEEK (_tokens, _pos);
      if (cost_expr is null)
        cost_expr := DB.DBA.GQL_PARSE_EDGE_COST (_tokens, _pos);
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);
      if (tt = 44)  -- ]->
        { _pos := _pos + 1; return vector ('EDGE', var_name, types, 'RIGHT', quantifier, props, path_mode, cost_expr, annot_mode, triple_term_mode, reifier_name); }
      if (tt = 45)  -- ]~>
        { _pos := _pos + 1; return vector ('EDGE', var_name, types, 'RIGHT', quantifier, props, path_mode, cost_expr, annot_mode, triple_term_mode, reifier_name); }
	      if (tt = 51)  -- ]-
	        { _pos := _pos + 1; return vector ('EDGE', var_name, types, 'BOTH', quantifier, props, path_mode, cost_expr, annot_mode, triple_term_mode, reifier_name); }
	      if (tt = 52)  -- ]~
	        { _pos := _pos + 1; return vector ('EDGE', var_name, types, 'UNDIRECTED', quantifier, props, path_mode, cost_expr, annot_mode, triple_term_mode, reifier_name); }
	      DB.DBA.GQL_EXPECT (_tokens, _pos, 4);  -- RBRACKET
	    }

	  -- Allow the common post-bracket path quantifier form:
	  --   -[:KNOWS]+->, -[:KNOWS]*->, -[:KNOWS]?->
	  tt := DB.DBA.GQL_PEEK (_tokens, _pos);
	  if (tt = 20        -- STAR
	      or tt = 19     -- PLUS
	      or tt = 42     -- QUESTION
	      or tt = 26)    -- DOTDOT (shorthand *0..)
	    quantifier := DB.DBA.GQL_PARSE_QUANTIFIER (_tokens, _pos);

	  -- Determine final direction from end arrow
	  tt := DB.DBA.GQL_PEEK (_tokens, _pos);

  if (direction = 'LEFT')
    {
      if (tt = 12)  -- DASH
        { _pos := _pos + 1; direction := 'LEFT'; }
      else if (tt = 10)  -- ->
        { _pos := _pos + 1; direction := 'BOTH'; }
      else if (tt = 11)  -- <-
        { _pos := _pos + 1; direction := 'BOTH'; }
      else
        signal ('GQ003', 'Expected - or -> after left-directed edge bracket');
    }
  else if (direction = 'RIGHT')
    {
      if (tt = 10)  -- ->
        { direction := 'RIGHT'; _pos := _pos + 1; }
      else if (tt = 44)  -- ]->
        { direction := 'RIGHT'; _pos := _pos + 1; }
      else if (tt = 12)  -- DASH
        { direction := 'BOTH'; _pos := _pos + 1; }
      else if (tt = 35)  -- ->|
        { direction := 'RIGHT'; _pos := _pos + 1; }
      else
        signal ('GQ003', 'Expected -> or - after edge bracket');
    }
  else if (direction = 'UNDIRECTED')
    {
      if (tt = 32)  -- ~
        { _pos := _pos + 1; }
      else if (tt = 12 or tt = 49 or tt = 48 or tt = 50)  -- DASH, SLASH_MINUS, SLASH_TILDE, TILDE_SLASH
        { _pos := _pos + 1; }
      else
        signal ('GQ003', 'Expected ~, -, or / after undirected edge bracket');
    }

  return vector ('EDGE', var_name, types, direction, quantifier, props, path_mode, cost_expr, annot_mode, triple_term_mode, reifier_name);
}
;

----------------------------------------------------------------------
-- Quantifier: *, *min..max, *min.., *..max, +, {min,max}, ?, .., ..max
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_QUANTIFIER (in _tokens any, inout _pos integer)
{
  declare min_hops, max_hops any;
  declare tt integer;

  min_hops := null;
  max_hops := null;

  tt := DB.DBA.GQL_PEEK (_tokens, _pos);

  if (tt = 20)  -- STAR (*)
    {
      _pos := _pos + 1;
      min_hops := 0;
      max_hops := null;  -- unbounded
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);
      if (tt = 66)  -- INTEGER
        {
          min_hops := atoi (DB.DBA.GQL_PEEK_VAL (_tokens, _pos));
          max_hops := min_hops;
          _pos := _pos + 1;
          tt := DB.DBA.GQL_PEEK (_tokens, _pos);
        }
      if (tt = 26)  -- DOTDOT
        {
          _pos := _pos + 1;
          tt := DB.DBA.GQL_PEEK (_tokens, _pos);
          if (tt = 66)  -- INTEGER
            { max_hops := atoi (DB.DBA.GQL_PEEK_VAL (_tokens, _pos)); _pos := _pos + 1; }
          else
            max_hops := null;
        }
    }
  else if (tt = 19)  -- PLUS (+)
    {
      min_hops := 1;
      max_hops := null;
      _pos := _pos + 1;
    }
  else if (tt = 42)  -- QUESTION (?)
    {
      min_hops := 0;
      max_hops := 1;
      _pos := _pos + 1;
    }
  else if (tt = 26)  -- DOTDOT (shorthand *0..)
    {
      _pos := _pos + 1;
      min_hops := 0;
      max_hops := null;
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);
      if (tt = 66)  -- INTEGER
        { max_hops := atoi (DB.DBA.GQL_PEEK_VAL (_tokens, _pos)); _pos := _pos + 1; }
    }
  else if (tt = 5)  -- LBRACE: {min,max} or {exact}
    {
      _pos := _pos + 1;
      min_hops := atoi (DB.DBA.GQL_PEEK_VAL (_tokens, _pos));
      DB.DBA.GQL_EXPECT (_tokens, _pos, 66);  -- INTEGER
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);
      if (tt = 9)  -- COMMA
        {
          _pos := _pos + 1;
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 66)
            { max_hops := atoi (DB.DBA.GQL_PEEK_VAL (_tokens, _pos)); _pos := _pos + 1; }
          else
            max_hops := null;
        }
      else
        max_hops := min_hops;
      DB.DBA.GQL_EXPECT (_tokens, _pos, 6);  -- RBRACE
    }

  if (min_hops is not null or max_hops is not null)
    return vector (min_hops, max_hops);
  return null;
}
;

----------------------------------------------------------------------
-- Properties: { key: value, key2: value2, ... }
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_PROPERTIES (in _tokens any, inout _pos integer)
{
  declare props any;
  declare key_name varchar;
  declare val any;

  DB.DBA.GQL_EXPECT (_tokens, _pos, 5);  -- LBRACE
  props := vector ();

  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 6)  -- RBRACE (empty)
    { _pos := _pos + 1; return props; }

  while (1)
    {
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 7)  -- default-prefixed property
        {
          _pos := _pos + 1;
          key_name := concat (':', DB.DBA.GQL_PEEK_VAL (_tokens, _pos));
          _pos := _pos + 1;
        }
      else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 69)  -- PNAME_NS (e.g. schem:dateCreated)
        {
          key_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 1;
        }
      else if (DB.DBA.GQL_PEEK (_tokens, _pos) >= 200  -- keyword-as-prefix (e.g. schema)
               and _pos + 1 < length (_tokens)
               and DB.DBA.GQL_PEEK (_tokens, _pos + 1) = 7  -- COLON
               and _pos + 2 < length (_tokens)
               and DB.DBA.GQL_PEEK (_tokens, _pos + 2) >= 64)  -- IDENT or keyword as local name
        {
          key_name := concat (DB.DBA.GQL_PEEK_VAL (_tokens, _pos), ':', DB.DBA.GQL_PEEK_VAL (_tokens, _pos + 2));
          _pos := _pos + 3;
        }
      else
        {
          key_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 1;  -- consume key (IDENT, STRING, or keyword-as-name)
        }
      DB.DBA.GQL_EXPECT (_tokens, _pos, 7);  -- COLON (key-value separator)
      val := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
      props := vector_concat (props, vector (vector (key_name, val)));
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
        _pos := _pos + 1;
      else
        goto props_done;
    }
  props_done:
  DB.DBA.GQL_EXPECT (_tokens, _pos, 6);  -- RBRACE
  return props;
}
;

----------------------------------------------------------------------
-- Bare properties (no enclosing braces): key: value, key2: value2, ...
-- Used inside <<( ... )>> and << ... >> RDF 1.2 syntax
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PARSE_PROPERTIES_BARE (in _tokens any, inout _pos integer)
{
  declare props any;
  declare key_name varchar;
  declare val any;

  props := vector ();

  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 2   -- ')'
      or DB.DBA.GQL_PEEK (_tokens, _pos) = 421  -- '>>'
      or DB.DBA.GQL_PEEK (_tokens, _pos) = 32)  -- '~' (reifier, no props)
    return props;

  while (1)
    {
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 7)  -- default-prefixed property
        {
          _pos := _pos + 1;
          key_name := concat (':', DB.DBA.GQL_PEEK_VAL (_tokens, _pos));
          _pos := _pos + 1;
        }
      else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 69)  -- PNAME_NS
        {
          key_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 1;
        }
      else if (DB.DBA.GQL_PEEK (_tokens, _pos) >= 200
               and _pos + 1 < length (_tokens)
               and DB.DBA.GQL_PEEK (_tokens, _pos + 1) = 7
               and _pos + 2 < length (_tokens)
               and DB.DBA.GQL_PEEK (_tokens, _pos + 2) >= 64)
        {
          key_name := concat (DB.DBA.GQL_PEEK_VAL (_tokens, _pos), ':', DB.DBA.GQL_PEEK_VAL (_tokens, _pos + 2));
          _pos := _pos + 3;
        }
      else
        {
          key_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 1;
        }
      DB.DBA.GQL_EXPECT (_tokens, _pos, 7);  -- COLON
      val := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
      props := vector_concat (props, vector (vector (key_name, val)));
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
        _pos := _pos + 1;
      else
        goto bare_props_done;
    }
  bare_props_done:
  return props;
}
;

----------------------------------------------------------------------
-- Annotation properties: {| key: value, key2: value2, ... |}
-- RDF 1.2 annotation syntax for edge properties
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_ANNOTATION_PROPERTIES (in _tokens any, inout _pos integer)
{
  declare props any;
  declare key_name varchar;
  declare val any;

  DB.DBA.GQL_EXPECT (_tokens, _pos, 5);  -- LBRACE
  DB.DBA.GQL_EXPECT (_tokens, _pos, 25);  -- PIPE
  props := vector ();

  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 25  -- PIPE (empty {| |})
      and DB.DBA.GQL_PEEK (_tokens, _pos + 1) = 6)  -- RBRACE
    { _pos := _pos + 2; return props; }

  while (1)
    {
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 7)  -- default-prefixed property
        {
          _pos := _pos + 1;
          key_name := concat (':', DB.DBA.GQL_PEEK_VAL (_tokens, _pos));
          _pos := _pos + 1;
        }
      else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 69)  -- PNAME_NS
        {
          key_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 1;
        }
      else if (DB.DBA.GQL_PEEK (_tokens, _pos) >= 200  -- keyword-as-prefix
               and _pos + 1 < length (_tokens)
               and DB.DBA.GQL_PEEK (_tokens, _pos + 1) = 7  -- COLON
               and _pos + 2 < length (_tokens)
               and DB.DBA.GQL_PEEK (_tokens, _pos + 2) >= 64)
        {
          key_name := concat (DB.DBA.GQL_PEEK_VAL (_tokens, _pos), ':', DB.DBA.GQL_PEEK_VAL (_tokens, _pos + 2));
          _pos := _pos + 3;
        }
      else
        {
          key_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 1;  -- consume key
        }
      DB.DBA.GQL_EXPECT (_tokens, _pos, 7);  -- COLON
      val := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
      props := vector_concat (props, vector (vector (key_name, val)));
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
        _pos := _pos + 1;
      else
        goto annot_props_done;
    }
  annot_props_done:
  DB.DBA.GQL_EXPECT (_tokens, _pos, 25);  -- PIPE
  DB.DBA.GQL_EXPECT (_tokens, _pos, 6);  -- RBRACE
  return props;
}
;

----------------------------------------------------------------------
-- Graph reference: ident, /path/ref, GRAPH <iri>, etc.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_GRAPH_REFERENCE (in _tokens any, inout _pos integer)
{
  declare tt integer;
  declare val any;
  declare kind varchar;

  tt := DB.DBA.GQL_PEEK (_tokens, _pos);

  if (tt = 64)  -- IDENT (simple name)
    {
      val := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 1;
      while (DB.DBA.GQL_PEEK (_tokens, _pos) = 8)  -- DOT: urn.analytics.weighted -> urn:analytics:weighted
        {
          _pos := _pos + 1;
          val := concat (val, ':', DB.DBA.GQL_PEEK_VAL (_tokens, _pos));
          _pos := _pos + 1;
        }
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 7)  -- COLON: analytics: or analytics:sales
        {
          _pos := _pos + 1;
          if (DB.DBA.GQL_IS_CLAUSE_START (DB.DBA.GQL_PEEK (_tokens, _pos))
              or DB.DBA.GQL_PEEK (_tokens, _pos) = 999)
            val := concat (val, ':');
          else
            {
              val := concat (val, ':', DB.DBA.GQL_PEEK_VAL (_tokens, _pos));
              _pos := _pos + 1;
            }
          return vector ('GRAPH_REF', val, 'PNAME');
        }
      return vector ('GRAPH_REF', val, 'BARE');
    }
  if (tt = 70)  -- IRIREF
    { val := DB.DBA.GQL_PEEK_VAL (_tokens, _pos); _pos := _pos + 1; return vector ('GRAPH_REF', val, 'IRI'); }
  if (tt = 69)  -- PNAME_NS
    { val := DB.DBA.GQL_PEEK_VAL (_tokens, _pos); _pos := _pos + 1; return vector ('GRAPH_REF', val, 'PNAME'); }
  if (tt = 225)  -- GRAPH keyword
    { _pos := _pos + 1; return DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos); }
  -- Absolute path: /schema/graph
  if (tt = 21)  -- SLASH
    {
      val := '';
      while (DB.DBA.GQL_PEEK (_tokens, _pos) = 21)
        { val := concat (val, '/'); _pos := _pos + 1; val := concat (val, DB.DBA.GQL_PEEK_VAL (_tokens, _pos)); _pos := _pos + 1; }
      return vector ('GRAPH_REF', val, 'BARE');
    }

  signal ('GQ003', sprintf ('Expected graph reference at position %d', _pos));
}
;

----------------------------------------------------------------------
-- Catalog-modifying statements (parse-only — rejected at translation)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_CREATE_STMT (in _tokens any, inout _pos integer)
{
  declare tt integer;
  declare pg_mode integer;
  _pos := _pos + 1;  -- consume CREATE
  tt := DB.DBA.GQL_PEEK (_tokens, _pos);

  if (tt = 228)  -- SCHEMA
    return DB.DBA.GQL_PARSE_CREATE_SCHEMA (_tokens, _pos);
  if (tt = 225)  -- GRAPH
    {
      if (_pos + 1 < length (_tokens) and DB.DBA.GQL_PEEK (_tokens, _pos + 1) = 226)  -- TYPE
        return DB.DBA.GQL_PARSE_CREATE_GRAPH_TYPE (_tokens, _pos);
      return DB.DBA.GQL_PARSE_CREATE_GRAPH (_tokens, _pos, 0);
    }
  if (DB.DBA.GQL_KW (_tokens, _pos, 'VIRTUAL') or DB.DBA.GQL_KW (_tokens, _pos, 'PHYSICAL'))  -- soft keywords
    {
      if (DB.DBA.GQL_KW (_tokens, _pos, 'VIRTUAL'))
        pg_mode := 545;   -- logical mode code: virtual
      else
        pg_mode := 546;   -- logical mode code: physical
      _pos := _pos + 1;  -- consume VIRTUAL/PHYSICAL
      DB.DBA.GQL_EXPECT (_tokens, _pos, 227);  -- PROPERTY
      DB.DBA.GQL_EXPECT (_tokens, _pos, 225);  -- GRAPH
      return DB.DBA.GQL_PARSE_CREATE_PROPERTY_GRAPH_V2 (_tokens, _pos, pg_mode);
    }
  if (tt = 227)  -- PROPERTY (no VIRTUAL/PHYSICAL keyword — defaults to physical)
    {
      _pos := _pos + 1;
      DB.DBA.GQL_EXPECT (_tokens, _pos, 225);  -- GRAPH
      return DB.DBA.GQL_PARSE_CREATE_PROPERTY_GRAPH_V2 (_tokens, _pos, 546);
    }
  signal ('GQ003', sprintf ('Expected SCHEMA, GRAPH, or PROPERTY GRAPH after CREATE at position %d', _pos));
}
;

----------------------------------------------------------------------
-- Is the token at _pos usable as a name (table / column / label)?
-- Accepts real identifiers (IDENT, ACCENT_IDENT, STRING) and any word
-- the lexer happens to classify as a keyword (e.g. PRODUCT, ORDER,
-- CONTAINS) — property-graph DDL names routinely collide with GQL
-- keywords, so at these grammar positions a keyword-word is a name.
-- Punctuation, numeric literals, and EOF are rejected.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_TOK_IS_NAME (in _tokens any, in _pos integer)
{
  declare _id, _c integer;
  declare _v any;
  _id := DB.DBA.GQL_PEEK (_tokens, _pos);
  if (_id = 64 or _id = 71 or _id = 65)  -- IDENT, ACCENT_IDENT, STRING
    return 1;
  if (_id = 999)  -- EOF
    return 0;
  _v := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
  if (not isstring (_v))
    return 0;
  if (length (_v) = 0)
    return 0;
  _c := aref (_v, 0);  -- first byte
  -- A-Z, a-z, or underscore → a keyword-derived word usable as a name
  if ((_c >= 65 and _c <= 90) or (_c >= 97 and _c <= 122) or _c = 95)
    return 1;
  return 0;
}
;

----------------------------------------------------------------------
-- Soft keyword test: the property-graph DDL words (VIRTUAL, PHYSICAL,
-- NODE/RELATIONSHIP TABLES, KEY, PROPERTIES, REFERENCES, REIFIER,
-- NAMED, ANONYMOUS, IRI, TEMPLATE) are NOT reserved — they lex as
-- ordinary identifiers so that names like iri(), key, template stay
-- usable everywhere else.  In the DDL grammar they are recognised
-- positionally by matching the identifier's (upper-cased) text.
-- Only an unquoted identifier (token type 64) can act as a keyword;
-- a quoted "IRI" or a string is always a literal name.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_KW (in _tokens any, in _pos integer, in _word varchar)
{
  if (DB.DBA.GQL_PEEK (_tokens, _pos) <> 64)
    return 0;
  if (upper (DB.DBA.GQL_PEEK_VAL (_tokens, _pos)) = _word)
    return 1;
  return 0;
}
;

----------------------------------------------------------------------
-- Consume a soft keyword or raise a parse error.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_EXPECT_KW (in _tokens any, inout _pos integer, in _word varchar)
{
  if (DB.DBA.GQL_KW (_tokens, _pos, _word))
    {
      _pos := _pos + 1;
      return;
    }
  signal ('GQ003', sprintf ('Expected %s at position %d', _word, _pos));
}
;

----------------------------------------------------------------------
-- Parse a qualified table name: identifier (. identifier)*
-- Returns the dotted name as a string, e.g. "DB.DBA.products".
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PARSE_TABLE_NAME (in _tokens any, inout _pos integer)
{
  declare name varchar;
  if (not DB.DBA.GQL_TOK_IS_NAME (_tokens, _pos))
    signal ('GQ003', sprintf ('Expected table name at position %d', _pos));
  name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
  _pos := _pos + 1;
  while (DB.DBA.GQL_PEEK (_tokens, _pos) = 8)  -- DOT
    {
      _pos := _pos + 1;
      if (not DB.DBA.GQL_TOK_IS_NAME (_tokens, _pos))
        signal ('GQ003', sprintf ('Expected identifier after dot at position %d', _pos));
      name := concat (name, '.', DB.DBA.GQL_PEEK_VAL (_tokens, _pos));
      _pos := _pos + 1;
    }
  return name;
}
;

----------------------------------------------------------------------
-- Parse a column list: ( col [, col]* )
-- Returns a vector of column-name strings.
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PARSE_COLUMN_LIST (in _tokens any, inout _pos integer)
{
  declare cols any;
  declare _first integer;
  cols := vector ();
  DB.DBA.GQL_EXPECT (_tokens, _pos, 1);  -- LPAREN
  _first := 1;
  while (DB.DBA.GQL_PEEK (_tokens, _pos) <> 2)  -- until RPAREN
    {
      if (not _first)
        DB.DBA.GQL_EXPECT (_tokens, _pos, 9);  -- COMMA
      _first := 0;
      if (not DB.DBA.GQL_TOK_IS_NAME (_tokens, _pos))
        signal ('GQ003', sprintf ('Expected column name at position %d', _pos));
      cols := vector_concat (cols, vector (DB.DBA.GQL_PEEK_VAL (_tokens, _pos)));
      _pos := _pos + 1;
    }
  DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
  return cols;
}
;

----------------------------------------------------------------------
-- Parse a properties list: PROPERTIES ( col [AS prop] [, col [AS prop]]* )
-- Returns a vector of pairs: vector (col_name, prop_name_or_null)
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PARSE_PROPERTIES_LIST (in _tokens any, inout _pos integer)
{
  declare props any;
  declare col_name, prop_name varchar;
  declare _first integer;
  props := vector ();
  DB.DBA.GQL_EXPECT_KW (_tokens, _pos, 'PROPERTIES');  -- PROPERTIES
  DB.DBA.GQL_EXPECT (_tokens, _pos, 1);    -- LPAREN
  _first := 1;
  while (DB.DBA.GQL_PEEK (_tokens, _pos) <> 2)  -- until RPAREN
    {
      if (not _first)
        DB.DBA.GQL_EXPECT (_tokens, _pos, 9);  -- COMMA
      _first := 0;
      if (not DB.DBA.GQL_TOK_IS_NAME (_tokens, _pos))
        signal ('GQ003', sprintf ('Expected column name in PROPERTIES at position %d', _pos));
      col_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 1;
      prop_name := null;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 241)  -- AS
        {
          _pos := _pos + 1;
          if (not DB.DBA.GQL_TOK_IS_NAME (_tokens, _pos))
            signal ('GQ003', sprintf ('Expected property name after AS at position %d', _pos));
          prop_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 1;
        }
      props := vector_concat (props, vector (vector (col_name, prop_name)));
    }
  DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
  return props;
}
;

----------------------------------------------------------------------
-- Parse one node table entry.
-- Syntax: table_name [KEY ( cols )] [LABEL lbl [LABEL lbl]*] [PROPERTIES (...)]
-- Returns: vector (table_name, key_cols, labels, properties)
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PARSE_NODE_TABLE (in _tokens any, inout _pos integer)
{
  declare tbl_name varchar;
  declare key_cols, labels, props any;

  tbl_name := DB.DBA.GQL_PARSE_TABLE_NAME (_tokens, _pos);
  key_cols := null;
  labels := vector ();
  props := null;

  -- KEY ( cols )
  if (DB.DBA.GQL_KW (_tokens, _pos, 'KEY'))  -- KEY
    {
      _pos := _pos + 1;
      key_cols := DB.DBA.GQL_PARSE_COLUMN_LIST (_tokens, _pos);
    }

  -- LABEL name [LABEL name]*  (multiple labels allowed)
  while (DB.DBA.GQL_PEEK (_tokens, _pos) = 273)  -- LABEL
    {
      _pos := _pos + 1;
      if (not DB.DBA.GQL_TOK_IS_NAME (_tokens, _pos))
        signal ('GQ003', sprintf ('Expected label name at position %d', _pos));
      labels := vector_concat (labels, vector (DB.DBA.GQL_PEEK_VAL (_tokens, _pos)));
      _pos := _pos + 1;
    }

  -- PROPERTIES ( ... )
  if (DB.DBA.GQL_KW (_tokens, _pos, 'PROPERTIES'))  -- PROPERTIES
    props := DB.DBA.GQL_PARSE_PROPERTIES_LIST (_tokens, _pos);

  return vector (tbl_name, key_cols, labels, props);
}
;

----------------------------------------------------------------------
-- Parse one relationship table entry.
-- Syntax:
--   table_name [KEY ( cols )]
--   SOURCE [KEY ( cols )] [REFERENCES] node_table [( cols )]
--   DESTINATION [KEY ( cols )] [REFERENCES] node_table [( cols )]
--   [LABEL label]
--   [PROPERTIES (...)]
--   [REIFIER (NAMED|ANONYMOUS)]
--   [REIFIER IRI TEMPLATE 'string']
-- Returns: vector (tbl_name, key_cols,
--                   src_table, src_cols,
--                   dst_table, dst_cols,
--                   label, props,
--                   reifier_named, reifier_iri_template)
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PARSE_RELATIONSHIP_TABLE (in _tokens any, inout _pos integer)
{
  declare tbl_name, label varchar;
  declare key_cols, props any;
  declare src_table, dst_table varchar;
  declare src_cols, dst_cols any;
  declare reifier_named integer;
  declare reifier_iri_template varchar;

  tbl_name := DB.DBA.GQL_PARSE_TABLE_NAME (_tokens, _pos);
  key_cols := null;
  src_table := null;  src_cols := null;
  dst_table := null;  dst_cols := null;
  label := null;
  props := null;
  reifier_named := 0;  -- anonymous by default
  reifier_iri_template := null;

  -- KEY ( cols )
  if (DB.DBA.GQL_KW (_tokens, _pos, 'KEY'))  -- KEY
    {
      _pos := _pos + 1;
      key_cols := DB.DBA.GQL_PARSE_COLUMN_LIST (_tokens, _pos);
    }

  -- SOURCE [KEY ( cols )] [REFERENCES] node_table [( cols )]
  DB.DBA.GQL_EXPECT (_tokens, _pos, 347);  -- SOURCE
  if (DB.DBA.GQL_KW (_tokens, _pos, 'KEY'))  -- KEY
    {
      _pos := _pos + 1;
      src_cols := DB.DBA.GQL_PARSE_COLUMN_LIST (_tokens, _pos);
    }
  if (DB.DBA.GQL_KW (_tokens, _pos, 'REFERENCES'))  -- REFERENCES
    _pos := _pos + 1;
  src_table := DB.DBA.GQL_PARSE_TABLE_NAME (_tokens, _pos);
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 1)  -- LPAREN
    {
      if (src_cols is null)
        src_cols := DB.DBA.GQL_PARSE_COLUMN_LIST (_tokens, _pos);
      else
        {  -- skip the reference column list; source key already parsed
          declare _skip any;
          _skip := DB.DBA.GQL_PARSE_COLUMN_LIST (_tokens, _pos);
        }
    }

  -- DESTINATION [KEY ( cols )] [REFERENCES] node_table [( cols )]
  DB.DBA.GQL_EXPECT (_tokens, _pos, 348);  -- DESTINATION
  if (DB.DBA.GQL_KW (_tokens, _pos, 'KEY'))  -- KEY
    {
      _pos := _pos + 1;
      dst_cols := DB.DBA.GQL_PARSE_COLUMN_LIST (_tokens, _pos);
    }
  if (DB.DBA.GQL_KW (_tokens, _pos, 'REFERENCES'))  -- REFERENCES
    _pos := _pos + 1;
  dst_table := DB.DBA.GQL_PARSE_TABLE_NAME (_tokens, _pos);
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 1)  -- LPAREN
    {
      if (dst_cols is null)
        dst_cols := DB.DBA.GQL_PARSE_COLUMN_LIST (_tokens, _pos);
      else
        {  -- skip
          declare _skip2 any;
          _skip2 := DB.DBA.GQL_PARSE_COLUMN_LIST (_tokens, _pos);
        }
    }

  -- LABEL label
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 273)  -- LABEL
    {
      _pos := _pos + 1;
      if (not DB.DBA.GQL_TOK_IS_NAME (_tokens, _pos))
        signal ('GQ003', sprintf ('Expected relationship label at position %d', _pos));
      label := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 1;
    }

  -- PROPERTIES ( ... )
  if (DB.DBA.GQL_KW (_tokens, _pos, 'PROPERTIES'))  -- PROPERTIES
    props := DB.DBA.GQL_PARSE_PROPERTIES_LIST (_tokens, _pos);

  -- REIFIER (NAMED | ANONYMOUS)
  while (DB.DBA.GQL_KW (_tokens, _pos, 'REIFIER'))  -- REIFIER
    {
      _pos := _pos + 1;
      if (DB.DBA.GQL_KW (_tokens, _pos, 'NAMED'))  -- NAMED
        { _pos := _pos + 1; reifier_named := 1; }
      else if (DB.DBA.GQL_KW (_tokens, _pos, 'ANONYMOUS'))  -- ANONYMOUS
        { _pos := _pos + 1; reifier_named := 0; }
      else if (DB.DBA.GQL_KW (_tokens, _pos, 'IRI'))  -- IRI
        {
          _pos := _pos + 1;
          DB.DBA.GQL_EXPECT_KW (_tokens, _pos, 'TEMPLATE');  -- TEMPLATE
          if (DB.DBA.GQL_PEEK (_tokens, _pos) <> 65)  -- STRING
            signal ('GQ003', sprintf ('Expected string after REIFIER IRI TEMPLATE at position %d', _pos));
          reifier_iri_template := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 1;
        }
      else
        signal ('GQ003', sprintf ('Expected NAMED, ANONYMOUS, or IRI after REIFIER at position %d', _pos));
    }

  return vector (tbl_name, key_cols,
                 src_table, src_cols,
                 dst_table, dst_cols,
                 label, props,
                 reifier_named, reifier_iri_template);
}
;

----------------------------------------------------------------------
-- Parse CREATE [VIRTUAL|PHYSICAL] PROPERTY GRAPH <name> ...
-- pg_mode: 545=virtual, 546=physical
-- VIRTUAL requires NODE TABLES; PHYSICAL accepts it optionally
-- (with tables: build + materialize; without: empty writable graph).
-- Returns:
--   ('CREATE_PROPERTY_GRAPH_V2', pg_name, pg_mode_token,
--    node_tables_vector, rel_tables_vector)
----------------------------------------------------------------------
create procedure DB.DBA.GQL_PARSE_CREATE_PROPERTY_GRAPH_V2 (
  inout _tokens any, inout _pos integer, in _pg_mode integer)
{
  declare pg_name varchar;
  declare node_tables, rel_tables any;
  declare graph_ref any;

  -- Parse graph name (bare name or IRI)
  graph_ref := DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos);
  if (isarray (graph_ref) and length (graph_ref) > 2 and aref (graph_ref, 2) = 'BARE')
    pg_name := cast (aref (graph_ref, 1) as varchar);
  else if (isarray (graph_ref) and length (graph_ref) > 2 and aref (graph_ref, 2) = 'IRI')
    pg_name := cast (aref (graph_ref, 1) as varchar);
  else
    signal ('GQ003', 'Property graph name must be a bare name or IRI');

  node_tables := vector ();
  rel_tables := vector ();

  -- Both VIRTUAL and PHYSICAL accept NODE TABLES / RELATIONSHIP TABLES.
  -- VIRTUAL requires NODE TABLES (a virtual graph with no tables is
  -- meaningless).  PHYSICAL makes it optional: with tables it builds
  -- quad maps and materializes; without tables it creates an empty
  -- writable graph.
  if (_pg_mode = 545)  -- VIRTUAL: NODE TABLES is required
    {
      declare _nt_first, _rt_first integer;
      -- NODE TABLES ( ... )
      DB.DBA.GQL_EXPECT (_tokens, _pos, 266);  -- NODE
      DB.DBA.GQL_EXPECT_KW (_tokens, _pos, 'TABLES');  -- TABLES
      DB.DBA.GQL_EXPECT (_tokens, _pos, 1);    -- LPAREN
      _nt_first := 1;
      while (DB.DBA.GQL_PEEK (_tokens, _pos) <> 2)  -- until RPAREN
        {
          if (not _nt_first)
            DB.DBA.GQL_EXPECT (_tokens, _pos, 9);  -- COMMA
          _nt_first := 0;
          node_tables := vector_concat (node_tables,
            vector (DB.DBA.GQL_PARSE_NODE_TABLE (_tokens, _pos)));
        }
      DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN

      -- Optional RELATIONSHIP TABLES ( ... )
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 268)  -- RELATIONSHIP
        {
          _pos := _pos + 1;
          DB.DBA.GQL_EXPECT_KW (_tokens, _pos, 'TABLES');  -- TABLES
          DB.DBA.GQL_EXPECT (_tokens, _pos, 1);    -- LPAREN
          _rt_first := 1;
          while (DB.DBA.GQL_PEEK (_tokens, _pos) <> 2)  -- until RPAREN
            {
              if (not _rt_first)
                DB.DBA.GQL_EXPECT (_tokens, _pos, 9);  -- COMMA
              _rt_first := 0;
              rel_tables := vector_concat (rel_tables,
                vector (DB.DBA.GQL_PARSE_RELATIONSHIP_TABLE (_tokens, _pos)));
            }
          DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
        }
    }
  else  -- PHYSICAL: NODE TABLES is optional
    {
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 266)  -- NODE
        {
          declare _nt_first, _rt_first integer;
          _pos := _pos + 1;  -- consume NODE
          DB.DBA.GQL_EXPECT_KW (_tokens, _pos, 'TABLES');  -- TABLES
          DB.DBA.GQL_EXPECT (_tokens, _pos, 1);    -- LPAREN
          _nt_first := 1;
          while (DB.DBA.GQL_PEEK (_tokens, _pos) <> 2)  -- until RPAREN
            {
              if (not _nt_first)
                DB.DBA.GQL_EXPECT (_tokens, _pos, 9);  -- COMMA
              _nt_first := 0;
              node_tables := vector_concat (node_tables,
                vector (DB.DBA.GQL_PARSE_NODE_TABLE (_tokens, _pos)));
            }
          DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN

          -- Optional RELATIONSHIP TABLES ( ... )
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 268)  -- RELATIONSHIP
            {
              _pos := _pos + 1;
              DB.DBA.GQL_EXPECT_KW (_tokens, _pos, 'TABLES');  -- TABLES
              DB.DBA.GQL_EXPECT (_tokens, _pos, 1);    -- LPAREN
              _rt_first := 1;
              while (DB.DBA.GQL_PEEK (_tokens, _pos) <> 2)  -- until RPAREN
                {
                  if (not _rt_first)
                    DB.DBA.GQL_EXPECT (_tokens, _pos, 9);  -- COMMA
                  _rt_first := 0;
                  rel_tables := vector_concat (rel_tables,
                    vector (DB.DBA.GQL_PARSE_RELATIONSHIP_TABLE (_tokens, _pos)));
                }
              DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
            }
        }
    }

  return vector ('CREATE_PROPERTY_GRAPH_V2', pg_name, _pg_mode, node_tables, rel_tables);
}
;

create procedure DB.DBA.GQL_PARSE_CREATE_SCHEMA (in _tokens any, inout _pos integer)
{
  declare if_not_exists, or_replace integer;
  declare schema_ref any;

  _pos := _pos + 1;  -- consume SCHEMA
  if_not_exists := 0;
  or_replace := 0;

  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 229)  -- IF
    {
      _pos := _pos + 1;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 231)  -- NOT
        { _pos := _pos + 1; if_not_exists := 1; }
      DB.DBA.GQL_EXPECT (_tokens, _pos, 230);  -- EXISTS
    }
  else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 233)  -- OR
    {
      _pos := _pos + 1;
      DB.DBA.GQL_EXPECT (_tokens, _pos, 338);  -- REPLACE
      or_replace := 1;
    }

  schema_ref := DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos);
  return vector ('CREATE_SCHEMA', schema_ref, if_not_exists, or_replace);
}
;

create procedure DB.DBA.GQL_PARSE_CREATE_GRAPH (in _tokens any, inout _pos integer, in _is_property integer)
{
  declare graph_ref, graph_type_ref, copy_of, like_graph any;

  _pos := _pos + 1;  -- consume GRAPH
  graph_ref := DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos);
  graph_type_ref := null;
  copy_of := null;
  like_graph := null;

  -- Optional open/any graph type spec (no schema constraint):
  --   CREATE GRAPH g ANY  |  CREATE GRAPH g OPEN
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 255)       -- ANY
    { _pos := _pos + 1; graph_type_ref := 'ANY'; }
  else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 327)  -- OPEN
    { _pos := _pos + 1; graph_type_ref := 'OPEN'; }

  -- Optional typed graph initializer: { ... }
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 5)  -- LBRACE
    {
      declare brace_depth integer;
      brace_depth := 1;
      _pos := _pos + 1;
      while (brace_depth > 0 and _pos < length (_tokens))
        {
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 5) brace_depth := brace_depth + 1;
          else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 6) brace_depth := brace_depth - 1;
          _pos := _pos + 1;
        }
      graph_type_ref := '<typed_init>';
    }

  -- AS COPY OF
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 241)  -- AS
    {
      _pos := _pos + 1;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 242)  -- COPY
        {
          _pos := _pos + 1;
          DB.DBA.GQL_EXPECT (_tokens, _pos, 243);  -- OF
          copy_of := DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos);
        }
    }
  -- LIKE
  else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 240)  -- LIKE
    {
      _pos := _pos + 1;
      like_graph := DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos);
    }

  return vector ('CREATE_GRAPH', graph_ref, graph_type_ref, copy_of, like_graph, _is_property);
}
;

create procedure DB.DBA.GQL_PARSE_CREATE_GRAPH_TYPE (in _tokens any, inout _pos integer)
{
  declare type_ref, body any;

  _pos := _pos + 1;  -- consume GRAPH
  DB.DBA.GQL_EXPECT (_tokens, _pos, 226);  -- TYPE
  type_ref := DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos);

  -- Parse body: { ... } — capture as opaque blob for Phase 8
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 5)
    {
      declare _d integer;
      _d := 1;
      _pos := _pos + 1;
      while (_d > 0 and _pos < length (_tokens))
        {
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 5) _d := _d + 1;
          else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 6) _d := _d - 1;
          _pos := _pos + 1;
        }
      body := '<graph_type_body>';
    }
  else
    body := null;

  return vector ('CREATE_GRAPH_TYPE', type_ref, body);
}
;

----------------------------------------------------------------------
-- DROP statements
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_DROP_STMT (in _tokens any, inout _pos integer)
{
  declare if_exists integer;
  declare tt integer;

  _pos := _pos + 1;  -- consume DROP
  if_exists := 0;

  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 229)  -- IF
    {
      _pos := _pos + 1;
      DB.DBA.GQL_EXPECT (_tokens, _pos, 230);  -- EXISTS
      if_exists := 1;
    }

  tt := DB.DBA.GQL_PEEK (_tokens, _pos);
  if (tt = 228)  -- SCHEMA
    {
      _pos := _pos + 1;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 229)  -- IF EXISTS (ISO order: after the object)
        { _pos := _pos + 1; DB.DBA.GQL_EXPECT (_tokens, _pos, 230); if_exists := 1; }
      return vector ('DROP_SCHEMA', DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos), if_exists);
    }
  -- DROP [VIRTUAL|PHYSICAL] PROPERTY GRAPH.  VIRTUAL/PHYSICAL are soft
  -- keywords (see GQL_KW); when present they assert the target's mode so
  -- the drop fails if it does not match (mirrors CREATE's mode split).
  else if (DB.DBA.GQL_KW (_tokens, _pos, 'VIRTUAL') or DB.DBA.GQL_KW (_tokens, _pos, 'PHYSICAL'))
    {
      declare drop_mode varchar;
      if (DB.DBA.GQL_KW (_tokens, _pos, 'VIRTUAL'))
        drop_mode := 'virtual';
      else
        drop_mode := 'physical';
      _pos := _pos + 1;  -- consume VIRTUAL/PHYSICAL
      DB.DBA.GQL_EXPECT (_tokens, _pos, 227);  -- PROPERTY
      DB.DBA.GQL_EXPECT (_tokens, _pos, 225);  -- GRAPH
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 229)  -- IF EXISTS
        { _pos := _pos + 1; DB.DBA.GQL_EXPECT (_tokens, _pos, 230); if_exists := 1; }
      return vector ('DROP_PROPERTY_GRAPH', DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos), if_exists, drop_mode);
    }
  else if (tt = 227)  -- PROPERTY
    {
      _pos := _pos + 1;
      DB.DBA.GQL_EXPECT (_tokens, _pos, 225);  -- GRAPH
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 229)  -- IF EXISTS
        { _pos := _pos + 1; DB.DBA.GQL_EXPECT (_tokens, _pos, 230); if_exists := 1; }
      return vector ('DROP_PROPERTY_GRAPH', DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos), if_exists, null);
    }
  else if (tt = 225)  -- GRAPH
    {
      _pos := _pos + 1;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 226)  -- TYPE
        {
          _pos := _pos + 1;
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 229)  -- IF EXISTS
            { _pos := _pos + 1; DB.DBA.GQL_EXPECT (_tokens, _pos, 230); if_exists := 1; }
          return vector ('DROP_GRAPH_TYPE', DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos), if_exists);
        }
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 229)  -- IF EXISTS
        { _pos := _pos + 1; DB.DBA.GQL_EXPECT (_tokens, _pos, 230); if_exists := 1; }
      return vector ('DROP_GRAPH', DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos), if_exists);
    }

  signal ('GQ003', sprintf ('Expected SCHEMA, GRAPH, PROPERTY GRAPH, or GRAPH TYPE after DROP at position %d', _pos));
}
;

----------------------------------------------------------------------
-- SESSION SET / SESSION RESET (stubs — rejected at translation)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_SESSION_SET (in _tokens any, inout _pos integer)
{
  declare setting any;
  _pos := _pos + 2;  -- consume SESSION SET

  setting := null;
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 228)  -- SCHEMA
    { _pos := _pos + 1; setting := DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos); }
  else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 225 or DB.DBA.GQL_PEEK (_tokens, _pos) = 227)  -- GRAPH or PROPERTY
    {
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 227) _pos := _pos + 1;  -- PROPERTY
      DB.DBA.GQL_EXPECT (_tokens, _pos, 225);  -- GRAPH
      setting := vector ('SESSION_SET_GRAPH', DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos));
    }
  else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 302)  -- TIME
    { _pos := _pos + 1; DB.DBA.GQL_EXPECT (_tokens, _pos, 301); setting := vector ('SESSION_SET_TIMEZONE'); _pos := _pos + 1; /* skip value */ if (_pos < length (_tokens)) _pos := _pos + 1; }
  else if (DB.DBA.GQL_PEEK (_tokens, _pos) = 279)  -- VALUE
    { _pos := _pos + 1; while (_pos < length (_tokens) and DB.DBA.GQL_PEEK (_tokens, _pos) <> 999 and not DB.DBA.GQL_IS_CLAUSE_START (DB.DBA.GQL_PEEK (_tokens, _pos))) _pos := _pos + 1; setting := '<session_set_value>'; }

  return vector ('SESSION_SET', setting);
}
;

create procedure DB.DBA.GQL_PARSE_SESSION_RESET (in _tokens any, inout _pos integer)
{
  _pos := _pos + 2;  -- consume SESSION RESET
  while (_pos < length (_tokens) and DB.DBA.GQL_PEEK (_tokens, _pos) <> 999 and not DB.DBA.GQL_IS_CLAUSE_START (DB.DBA.GQL_PEEK (_tokens, _pos)))
    _pos := _pos + 1;
  return vector ('SESSION_RESET', null);
}
;

----------------------------------------------------------------------
-- LOAD <iri> [INTO GRAPH <g>]
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_LOAD (in _tokens any, inout _pos integer)
{
  declare iri, graph_ref any;
  _pos := _pos + 1;  -- consume LOAD
  iri := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
  graph_ref := null;
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 287)  -- INTO
    {
      _pos := _pos + 1;
      DB.DBA.GQL_EXPECT (_tokens, _pos, 225);  -- GRAPH
      graph_ref := DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos);
    }
  return vector ('LOAD', iri, graph_ref);
}
;

----------------------------------------------------------------------
-- CLEAR GRAPH <g>
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_CLEAR (in _tokens any, inout _pos integer)
{
  declare graph_ref any;
  _pos := _pos + 1;  -- consume CLEAR
  DB.DBA.GQL_EXPECT (_tokens, _pos, 225);  -- GRAPH
  graph_ref := DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos);
  return vector ('CLEAR', graph_ref);
}
;

----------------------------------------------------------------------
-- CALL <ref>([args]) [YIELD vars]  |  CALL { subquery } [YIELD vars]
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_CALL (in _tokens any, inout _pos integer)
{
  declare proc_ref, args, yield_vars any;
  _pos := _pos + 1;  -- consume CALL

  -- CALL { <subquery> }: inline procedure call
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 5)  -- LBRACE
    {
      declare subquery any;
      _pos := _pos + 1;  -- consume '{' before parsing the inline subquery
      subquery := DB.DBA.GQL_PARSE_COMPOSITE_QUERY (_tokens, _pos);
      DB.DBA.GQL_EXPECT (_tokens, _pos, 6);  -- RBRACE
      yield_vars := DB.DBA.GQL_PARSE_YIELD (_tokens, _pos);
      return vector ('CALL_INLINE', subquery, yield_vars);
    }

  -- CALL <procedure_reference>
  proc_ref := DB.DBA.GQL_PARSE_GRAPH_REFERENCE (_tokens, _pos);
  args := vector ();
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 1)  -- LPAREN
    {
      _pos := _pos + 1;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) <> 2)  -- not RPAREN
        {
          args := vector_concat (args, vector (DB.DBA.GQL_PARSE_EXPR (_tokens, _pos)));
          while (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
            {
              _pos := _pos + 1;
              args := vector_concat (args, vector (DB.DBA.GQL_PARSE_EXPR (_tokens, _pos)));
            }
        }
      DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
    }

  yield_vars := DB.DBA.GQL_PARSE_YIELD (_tokens, _pos);
  return vector ('CALL', proc_ref, args, yield_vars);
}
;

create procedure DB.DBA.GQL_PARSE_YIELD (in _tokens any, inout _pos integer)
{
  declare yield_vars any;
  yield_vars := vector ();
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 251)  -- YIELD
    {
      _pos := _pos + 1;
      yield_vars := vector_concat (yield_vars, vector (DB.DBA.GQL_PEEK_VAL (_tokens, _pos)));
      _pos := _pos + 1;
      while (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
        {
          _pos := _pos + 1;
          yield_vars := vector_concat (yield_vars, vector (DB.DBA.GQL_PEEK_VAL (_tokens, _pos)));
          _pos := _pos + 1;
        }
    }
  return yield_vars;
}
;

----------------------------------------------------------------------
-- Transaction stub
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_TRANSACTION_STUB (in _tokens any, inout _pos integer)
{
  _pos := _pos + 1;  -- consume START
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 322)  -- TRANSACTION
    _pos := _pos + 1;
  while (_pos < length (_tokens) and DB.DBA.GQL_PEEK (_tokens, _pos) <> 999
         and not DB.DBA.GQL_IS_CLAUSE_START (DB.DBA.GQL_PEEK (_tokens, _pos)))
    _pos := _pos + 1;
  return vector ('TRANSACTION', null);
}
;

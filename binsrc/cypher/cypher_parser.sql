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
--  openCypher: OpenCypher for Virtuoso - Parser
--
--  Recursive descent parser producing AST as nested vectors.
--
--  AST node formats:
--    Statement:    vector('STMT', clauses_vector)
--    Match:        vector('MATCH', is_optional, patterns_vector)
--    Where:        vector('WHERE', expr)
--    Return:       vector('RETURN', is_distinct, items, order_by, skip_expr, limit_expr)
--    Create:       vector('CREATE', patterns_vector)
--    Delete:       vector('DELETE', is_detach, items)
--    Set:          vector('SET', items)
--    Remove:       vector('REMOVE', items)
--    Merge:        vector('MERGE', pattern, on_create_set, on_match_set)
--    Unwind:       vector('UNWIND', expr, alias)
--    With:         vector('WITH', is_distinct, items, order_by, skip_expr, limit_expr, where_expr)
--    Union:        vector('UNION', is_all)
--    Define:       vector('DEFINE', key, value_expr)
--    Graph:        vector('GRAPH', graph_expr, clauses)
--    Service:      vector('SERVICE', endpoint_expr, clauses)
--    Values:       vector('VALUES', var_name, values_vec)
--    Bind:         vector('BIND', expr, alias)
--    Minus:        vector('MINUS', clauses)
--    Ask:          vector('ASK')
--    Construct:    vector('CONSTRUCT', clauses)
--    Describe:     vector('DESCRIBE', items)
--    Load:         vector('SPARQL_LOAD', silent, source_expr, target_expr)
--    Clear:        vector('SPARQL_CLEAR', silent, target_kind, target_expr)
--    Drop:         vector('SPARQL_DROP', silent, target_kind, target_expr)
--    CreateGraph:  vector('SPARQL_CREATE_GRAPH', silent, graph_expr)
--    Copy/Move/Add: vector('SPARQL_GRAPH_COPY', op, silent, src_kind, src_expr, dst_kind, dst_expr)
--    Insert/Delete Data: vector('SPARQL_DATA_UPDATE', op, clauses)
--    Node:         vector('NODE', var_name, labels_vec, props_vec)
--    Rel:          vector('REL', var_name, types_vec, direction, min_hops, max_hops, props_vec)
--                  direction: 'RIGHT', 'LEFT', 'BOTH', 'NONE'
--    ReturnItem:   vector('RETITEM', expr, alias)
--    SortItem:     vector('SORT', expr, direction)  -- 'ASC' or 'DESC'
--    SetProp:      vector('SETPROP', expr, value_expr)
--    SetLabel:     vector('SETLABEL', var_name, labels_vec)
--    SetAllProps:  vector('SETALL', var_name, expr, is_plus)
--    RemoveProp:   vector('RMPROP', expr)
--    RemoveLabel:  vector('RMLABEL', var_name, labels_vec)
--    PropAccess:   vector('PROP', var_or_expr, prop_name)
--    Variable:     vector('VAR', name)
--    Literal:      vector('LIT', value)  -- value is native type (string/int/float/null)
--    BinaryOp:     vector('BINOP', operator, left, right)
--    UnaryOp:      vector('UNOP', operator, expr)
--    FuncCall:     vector('FUNC', name, is_distinct, args_vec)
--    CountStar:    vector('COUNTSTAR')
--    ListLit:      vector('LIST', elements_vec)
--    MapLit:       vector('MAP', keys_vec, values_vec)
--    Param:        vector('PARAM', name)
--    IsNull:       vector('ISNULL', expr, is_negated)
--    InExpr:       vector('INEXPR', expr, list_expr)
--    StringOp:     vector('STROP', op, left, right)  -- op: 'STARTS WITH','ENDS WITH','CONTAINS'
--    CaseExpr:     vector('CASEEXPR', operand, whens_vec, else_expr)
--    Pattern:      vector('PATTERN', elements_vec)  -- alternating node/rel
--    PathVar:      vector('PATHVAR', var_name, pattern)
--

-- Helper: is token a clause-starting keyword?
create procedure DB.DBA.CYP_IS_CLAUSE_START (in _type integer)
{

  if (_type = 100) return 1;  -- MATCH
  if (_type = 101) return 1;  -- OPTIONAL
  if (_type = 102) return 1;  -- WHERE
  if (_type = 103) return 1;  -- RETURN
  if (_type = 104) return 1;  -- CREATE
  if (_type = 105) return 1;  -- DELETE
  if (_type = 106) return 1;  -- DETACH
  if (_type = 107) return 1;  -- SET
  if (_type = 108) return 1;  -- REMOVE
  if (_type = 109) return 1;  -- MERGE
  if (_type = 110) return 1;  -- WITH
  if (_type = 111) return 1;  -- UNWIND
  if (_type = 119) return 1;  -- UNION
  if (_type = 142) return 1;  -- CALL
  if (_type = 153) return 1;  -- PREFIX
  if (_type = 154) return 1;  -- GRAPH
  if (_type = 157) return 1;  -- DEFINE
  if (_type = 159) return 1;  -- SERVICE
  if (_type = 160) return 1;  -- VALUES
  if (_type = 161) return 1;  -- BIND
  if (_type = 162) return 1;  -- MINUS
  if (_type = 165) return 1;  -- ASK
  if (_type = 166) return 1;  -- CONSTRUCT
  if (_type = 167) return 1;  -- DESCRIBE
  if (_type = 168) return 1;  -- LOAD
  if (_type = 169) return 1;  -- CLEAR
  if (_type = 170) return 1;  -- DROP
  if (_type = 171) return 1;  -- ADD
  if (_type = 172) return 1;  -- MOVE
  if (_type = 173) return 1;  -- COPY
  if (_type = 178) return 1;  -- INSERT
  if (_type = 182) return 1;  -- BASE
  if (_type = 183) return 1;  -- FORCE
  return 0;
}
;

-- Main parse entry point
create procedure DB.DBA.CYP_PARSE (in _tokens any)
{
  declare pos integer;
  declare clauses any;

  pos := 0;
  clauses := DB.DBA.CYP_PARSE_STATEMENT (_tokens, pos);
  return vector ('STMT', clauses);
}
;

-- Parse a complete statement (sequence of clauses)
create procedure DB.DBA.CYP_PARSE_STATEMENT (in _tokens any, inout _pos integer)
{
  declare clauses, clause any;
  declare tt integer;

  clauses := vector ();

  while (1)
    {
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);
      if (tt = 999 or tt = 6) goto stmt_done;  -- EOF or closing block

      if (tt = 100)  -- MATCH
        {
          clause := DB.DBA.CYP_PARSE_MATCH (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 101)  -- OPTIONAL
        {
          clause := DB.DBA.CYP_PARSE_OPTIONAL_MATCH (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 102)  -- WHERE
        {
          clause := DB.DBA.CYP_PARSE_WHERE (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 103)  -- RETURN
        {
          clause := DB.DBA.CYP_PARSE_RETURN (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 104)  -- CREATE
        {
          if (DB.DBA.CYP_PEEK (_tokens, _pos + 1) = 154
              or (DB.DBA.CYP_PEEK (_tokens, _pos + 1) = 174 and DB.DBA.CYP_PEEK (_tokens, _pos + 2) = 154))  -- GRAPH
            clause := DB.DBA.CYP_PARSE_SPARQL_CREATE_GRAPH (_tokens, _pos);
          else
            clause := DB.DBA.CYP_PARSE_CREATE (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 105)  -- DELETE
        {
          if (DB.DBA.CYP_PEEK (_tokens, _pos + 1) = 179)  -- DATA
            clause := DB.DBA.CYP_PARSE_SPARQL_DATA_UPDATE (_tokens, _pos, 'DELETE');
          else
            clause := DB.DBA.CYP_PARSE_DELETE (_tokens, _pos, 0);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 106)  -- DETACH
        {
          _pos := _pos + 1;
          DB.DBA.CYP_EXPECT (_tokens, _pos, 105);  -- DELETE
          clause := DB.DBA.CYP_PARSE_DELETE_ITEMS (_tokens, _pos, 1);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 107)  -- SET
        {
          clause := DB.DBA.CYP_PARSE_SET (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 108)  -- REMOVE
        {
          clause := DB.DBA.CYP_PARSE_REMOVE (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 109)  -- MERGE
        {
          clause := DB.DBA.CYP_PARSE_MERGE (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 110)  -- WITH
        {
          clause := DB.DBA.CYP_PARSE_WITH (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 111)  -- UNWIND
        {
          clause := DB.DBA.CYP_PARSE_UNWIND (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 119)  -- UNION
        {
          _pos := _pos + 1;
          if (DB.DBA.CYP_PEEK (_tokens, _pos) = 120)  -- ALL
            {
              _pos := _pos + 1;
              clauses := vector_concat (clauses, vector (vector ('UNION', 1)));
            }
          else
            clauses := vector_concat (clauses, vector (vector ('UNION', 0)));
        }
      else if (tt = 142)  -- CALL
        {
          clause := DB.DBA.CYP_PARSE_CALL (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 153)  -- PREFIX
        {
          clause := DB.DBA.CYP_PARSE_PREFIX (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 182)  -- BASE
        {
          clause := DB.DBA.CYP_PARSE_BASE (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 154)  -- GRAPH
        {
          clause := DB.DBA.CYP_PARSE_GRAPH_BLOCK (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 157)  -- DEFINE
        {
          clause := DB.DBA.CYP_PARSE_DEFINE (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 159)  -- SERVICE
        {
          clause := DB.DBA.CYP_PARSE_SERVICE (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 160)  -- VALUES
        {
          clause := DB.DBA.CYP_PARSE_VALUES (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 161)  -- BIND
        {
          clause := DB.DBA.CYP_PARSE_BIND (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 162)  -- MINUS
        {
          clause := DB.DBA.CYP_PARSE_MINUS (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 165)  -- ASK
        {
          _pos := _pos + 1;
          clauses := vector_concat (clauses, vector (vector ('ASK')));
        }
      else if (tt = 166)  -- CONSTRUCT
        {
          clause := DB.DBA.CYP_PARSE_CONSTRUCT (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 167)  -- DESCRIBE
        {
          clause := DB.DBA.CYP_PARSE_DESCRIBE (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 168)  -- LOAD
        {
          clause := DB.DBA.CYP_PARSE_SPARQL_LOAD (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 169)  -- CLEAR
        {
          clause := DB.DBA.CYP_PARSE_SPARQL_CLEAR_DROP (_tokens, _pos, 'SPARQL_CLEAR');
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 170)  -- DROP
        {
          clause := DB.DBA.CYP_PARSE_SPARQL_CLEAR_DROP (_tokens, _pos, 'SPARQL_DROP');
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 171 or tt = 172 or tt = 173)  -- ADD/MOVE/COPY
        {
          clause := DB.DBA.CYP_PARSE_SPARQL_GRAPH_COPY (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 178)  -- INSERT
        {
          clause := DB.DBA.CYP_PARSE_SPARQL_DATA_UPDATE (_tokens, _pos, 'INSERT');
          clauses := vector_concat (clauses, vector (clause));
        }
      else if (tt = 183)  -- FORCE
        {
          clause := DB.DBA.CYP_PARSE_FORCE_OPTION (_tokens, _pos);
          clauses := vector_concat (clauses, vector (clause));
        }
      else
        {
          signal ('CY003', sprintf ('Unexpected token ''%s'' (type %d) at position %d',
                  DB.DBA.CYP_PEEK_VAL (_tokens, _pos), tt, _pos));
        }
    }
  stmt_done:
  return clauses;
}
;

create procedure DB.DBA.CYP_PARSE_FORCE_OPTION (in _tokens any, inout _pos integer)
{
  DB.DBA.CYP_EXPECT (_tokens, _pos, 183);  -- FORCE
  DB.DBA.CYP_EXPECT (_tokens, _pos, 184);  -- CAMELCASE
  return vector ('FORCE_CAMELCASE');
}
;

-- Parse MATCH clause with optional FROM GRAPH (specs-compliant: FROM comes after pattern)
create procedure DB.DBA.CYP_PARSE_MATCH (in _tokens any, inout _pos integer)
{
  declare patterns any;
  declare from_graphs any;

  _pos := _pos + 1;  -- consume MATCH

  -- Parse pattern list first (specs: MATCH (pattern) FROM <graph>)
  patterns := DB.DBA.CYP_PARSE_PATTERN_LIST (_tokens, _pos);

  -- Parse optional FROM GRAPH clauses after patterns
  from_graphs := vector ();
  while (DB.DBA.CYP_PEEK (_tokens, _pos) = 156)  -- FROM
    {
      _pos := _pos + 1;  -- consume FROM

      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 158)  -- NAMED
        {
          _pos := _pos + 1;
          from_graphs := vector_concat (from_graphs, vector (vector ('FROM_NAMED', DB.DBA.CYP_PARSE_EXPR (_tokens, _pos))));
        }
      else if (DB.DBA.CYP_PEEK (_tokens, _pos) = 154)  -- GRAPH_KW
        {
          _pos := _pos + 1;  -- consume GRAPH
          -- Parse graph expression (can be IRI, variable, or inline URI)
          from_graphs := vector_concat (from_graphs, vector (vector ('FROM', DB.DBA.CYP_PARSE_EXPR (_tokens, _pos))));
        }
      else
        {
          -- Direct graph IRI/expression without GRAPH keyword: FROM <uri>
          from_graphs := vector_concat (from_graphs, vector (vector ('FROM', DB.DBA.CYP_PARSE_EXPR (_tokens, _pos))));
        }
    }

  return vector ('MATCH', 0, patterns, from_graphs);
}
;

-- Parse OPTIONAL MATCH clause with optional FROM GRAPH
create procedure DB.DBA.CYP_PARSE_OPTIONAL_MATCH (in _tokens any, inout _pos integer)
{
  declare patterns any;
  declare from_graphs any;

  _pos := _pos + 1;  -- consume OPTIONAL
  DB.DBA.CYP_EXPECT (_tokens, _pos, 100);  -- MATCH

  -- Parse pattern list first
  patterns := DB.DBA.CYP_PARSE_PATTERN_LIST (_tokens, _pos);

  -- Parse optional FROM GRAPH clauses after patterns
  from_graphs := vector ();
  while (DB.DBA.CYP_PEEK (_tokens, _pos) = 156)  -- FROM
    {
      _pos := _pos + 1;  -- consume FROM

      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 158)  -- NAMED
        {
          _pos := _pos + 1;
          from_graphs := vector_concat (from_graphs, vector (vector ('FROM_NAMED', DB.DBA.CYP_PARSE_EXPR (_tokens, _pos))));
        }
      else if (DB.DBA.CYP_PEEK (_tokens, _pos) = 154)  -- GRAPH_KW
        {
          _pos := _pos + 1;  -- consume GRAPH
          from_graphs := vector_concat (from_graphs, vector (vector ('FROM', DB.DBA.CYP_PARSE_EXPR (_tokens, _pos))));
        }
      else
        {
          -- Direct graph IRI/expression
          from_graphs := vector_concat (from_graphs, vector (vector ('FROM', DB.DBA.CYP_PARSE_EXPR (_tokens, _pos))));
        }
    }

  return vector ('MATCH', 1, patterns, from_graphs);
}
;

-- Parse comma-separated list of patterns
create procedure DB.DBA.CYP_PARSE_PATTERN_LIST (in _tokens any, inout _pos integer)
{
  declare patterns, pat any;

  patterns := vector ();
  pat := DB.DBA.CYP_PARSE_PATTERN (_tokens, _pos);
  patterns := vector_concat (patterns, vector (pat));
  while (DB.DBA.CYP_PEEK (_tokens, _pos) = 9)  -- COMMA
    {
      _pos := _pos + 1;
      pat := DB.DBA.CYP_PARSE_PATTERN (_tokens, _pos);
      patterns := vector_concat (patterns, vector (pat));
    }
  return patterns;
}
;

create procedure DB.DBA.CYP_PATH_SEARCH_PREFIX_NAME (in _tokens any, inout _pos integer)
{
  declare tt integer;
  declare mode varchar;

  tt := DB.DBA.CYP_PEEK (_tokens, _pos);
  if (tt = 150)  -- ANY
    {
      _pos := _pos + 1;
      mode := 'ANY';
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 180)  -- SHORTEST
        {
          _pos := _pos + 1;
          mode := 'ANY SHORTEST';
        }
      return mode;
    }
  if (tt = 120)  -- ALL
    {
      _pos := _pos + 1;
      mode := 'ALL';
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 180)  -- SHORTEST
        {
          _pos := _pos + 1;
          mode := 'ALL SHORTEST';
        }
      return mode;
    }
  if (tt = 180)  -- SHORTEST
    {
      _pos := _pos + 1;
      mode := 'SHORTEST';
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 52)  -- INTEGER
        {
          mode := concat (mode, ' ', DB.DBA.CYP_PEEK_VAL (_tokens, _pos));
          _pos := _pos + 1;
          if (DB.DBA.CYP_PEEK (_tokens, _pos) = 181)  -- GROUPS
            {
              mode := concat (mode, ' GROUPS');
              _pos := _pos + 1;
            }
        }
      return mode;
    }
  return null;
}
;

create procedure DB.DBA.CYP_SIGNAL_UNSUPPORTED_PATH_SEARCH (in _mode varchar)
{
  signal ('CY040', sprintf ('Path search prefix %s is not yet implemented in openCypher', _mode));
}
;

create procedure DB.DBA.CYP_SIGNAL_UNSUPPORTED_QUANTIFIED_PATH ()
{
  signal ('CY041', 'Quantified path primaries and parenthesized path patterns are not yet implemented in openCypher');
}
;

-- Parse a single pattern: optional path variable assignment, then node/rel chain
create procedure DB.DBA.CYP_PARSE_PATTERN (in _tokens any, inout _pos integer)
{
  declare elements, elem any;
  declare path_var, path_mode varchar;
  declare tt integer;
  declare save_pos integer;

  path_var := null;
  path_mode := null;

  -- Check for path variable: ident = pattern
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 50)  -- IDENT
    {
      save_pos := _pos;
      if (_pos + 1 < length (_tokens) and DB.DBA.CYP_PEEK (_tokens, _pos + 1) = 15)  -- EQ
        {
          path_var := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 2;  -- consume ident and =
        }
    }

  path_mode := DB.DBA.CYP_PATH_SEARCH_PREFIX_NAME (_tokens, _pos);
  if (path_mode is not null)
    DB.DBA.CYP_SIGNAL_UNSUPPORTED_PATH_SEARCH (path_mode);

  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 1 and DB.DBA.CYP_PEEK (_tokens, _pos + 1) = 1)
    DB.DBA.CYP_SIGNAL_UNSUPPORTED_QUANTIFIED_PATH ();

  elements := vector ();

  -- First element must be a node
  elem := DB.DBA.CYP_PARSE_NODE_PATTERN (_tokens, _pos);
  elements := vector_concat (elements, vector (elem));

  -- Then alternating relationship-node pairs
  while (DB.DBA.CYP_PEEK (_tokens, _pos) = 12 or DB.DBA.CYP_PEEK (_tokens, _pos) = 11)  -- DASH or ARROW_L(<-)
    {
      elem := DB.DBA.CYP_PARSE_REL_PATTERN (_tokens, _pos);
      elements := vector_concat (elements, vector (elem));
      elem := DB.DBA.CYP_PARSE_NODE_PATTERN (_tokens, _pos);
      elements := vector_concat (elements, vector (elem));
    }

  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 1
      or DB.DBA.CYP_PEEK (_tokens, _pos) = 19
      or DB.DBA.CYP_PEEK (_tokens, _pos) = 20
      or DB.DBA.CYP_PEEK (_tokens, _pos) = 5)
    DB.DBA.CYP_SIGNAL_UNSUPPORTED_QUANTIFIED_PATH ();

  if (path_var is not null)
    return vector ('PATHVAR', path_var, vector ('PATTERN', elements));
  return vector ('PATTERN', elements);
}
;

-- Parse node pattern: (var:Label:Label2 {prop: val, ...})
-- Also supports openCypher 2024.3 label expressions:
--   (n IS Person), (n:Person|Employee), (n:Person&Employee),
--   (n:!Blocked), (n:%), (n:(A|B)&C)
create procedure DB.DBA.CYP_PARSE_NODE_PATTERN (in _tokens any, inout _pos integer)
{
  declare var_name varchar;
  declare labels, props any;
  declare tt integer;
  declare pname_val varchar;
  declare colon_pos integer;
  declare label_name varchar;
  declare lbl_expr any;

  var_name := null;
  labels := vector ();
  props := vector ();

  DB.DBA.CYP_EXPECT (_tokens, _pos, 1);  -- LPAREN

  tt := DB.DBA.CYP_PEEK (_tokens, _pos);

  -- Empty node ()
  if (tt = 2)
    {
      _pos := _pos + 1;
      return vector ('NODE', null, labels, props);
    }

  -- Handle PNAME_NS (55): tokenizer produced var:Label as single token
  if (tt = 55)
    {
      pname_val := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
      colon_pos := strchr (pname_val, ':');
      if (colon_pos is not null and colon_pos > 0)
        {
          var_name := subseq (pname_val, 0, colon_pos);
          label_name := subseq (pname_val, colon_pos + 1);
          if (DB.DBA.CYP_PEEK (_tokens, _pos + 1) = 7 and label_name = lower (label_name))
            {
              _pos := _pos + 1;
              label_name := concat (label_name, ':', DB.DBA.CYP_PEEK_VAL (_tokens, _pos + 1));
              _pos := _pos + 1;
            }
          labels := vector_concat (labels, vector (label_name));
        }
      else
        var_name := pname_val;
      _pos := _pos + 1;
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);

      -- If a label-expression operator follows the PNAME_NS-extracted label,
      -- continue parsing into a full label expression.
      if (length (labels) = 1 and (tt = 25 or tt = 29))
        {
          lbl_expr := DB.DBA.CYP_PARSE_LBL_OR_FROM (_tokens, _pos,
                                                    vector ('LBLEXPR', 'NAME', aref (labels, 0)));
          labels := DB.DBA.CYP_LBL_FINALIZE (lbl_expr);
          tt := DB.DBA.CYP_PEEK (_tokens, _pos);
        }
    }
  -- Variable name
  else if (tt = 50)  -- IDENT
    {
      var_name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 1;
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);
    }

  -- IS <label expression> (openCypher 2024.3 label predicate inside pattern)
  if (tt = 127)  -- IS keyword
    {
      _pos := _pos + 1;
      lbl_expr := DB.DBA.CYP_PARSE_LBL_OR (_tokens, _pos);
      labels := DB.DBA.CYP_LBL_FINALIZE (lbl_expr);
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);
    }
  -- Colon-introduced label expression: ':' <label expression>
  else if (tt = 7 and length (labels) = 0)
    {
      _pos := _pos + 1;
      lbl_expr := DB.DBA.CYP_PARSE_LBL_OR (_tokens, _pos);
      labels := DB.DBA.CYP_LBL_FINALIZE (lbl_expr);
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);
    }
  -- Continued legacy chain after PNAME_NS extracted the first label
  else if (tt = 7 and length (labels) >= 1
           and not DB.DBA.CYP_LBLEXPR_IS_AST (labels))
    {
      lbl_expr := vector ('LBLEXPR', 'NAME', aref (labels, 0));
      lbl_expr := DB.DBA.CYP_PARSE_LBL_OR_FROM (_tokens, _pos, lbl_expr);
      labels := DB.DBA.CYP_LBL_FINALIZE (lbl_expr);
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);
    }

  -- Parameter map: (n $param) — all properties from a parameter
  if (tt = 28)  -- DOLLAR
    {
      declare param_name varchar;
      _pos := _pos + 1;
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 50)
        {
          param_name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 1;
          props := vector_concat (props, vector (vector ('PARAMPROPS', param_name)));
        }
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);
    }

  -- Properties
  if (tt = 5)  -- LBRACE
    {
      props := DB.DBA.CYP_PARSE_PROPERTIES (_tokens, _pos);
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);
    }

  DB.DBA.CYP_EXPECT (_tokens, _pos, 2);  -- RPAREN
  return vector ('NODE', var_name, labels, props);
}
;

-- Check if token type is a keyword that can be used as identifier in certain contexts
create procedure DB.DBA.CYP_IS_NON_RESERVED_KW (in _type integer)
{

  -- Many Cypher keywords can appear as label/property names
  if (_type >= 100 and _type <= 152 and _type <> 100 and _type <> 103 and _type <> 104)
    return 1;
  return 0;
}
;

-- ============================================================================
-- Label expression parsing (openCypher 2024.3 <label expression>)
--
-- AST nodes:
--   vector('LBLEXPR', 'NAME', name)       -- single label name
--   vector('LBLEXPR', 'WILD')              -- wildcard '%'
--   vector('LBLEXPR', 'NOT', inner)        -- '!' inner
--   vector('LBLEXPR', 'AND', lhs, rhs)     -- inner '&' inner   (or legacy ':')
--   vector('LBLEXPR', 'OR',  lhs, rhs)     -- inner '|' inner
--
-- A pure conjunction of NAME nodes is flattened back to a varchar vector
-- so legacy translator paths keep working unchanged.
-- ============================================================================

create procedure DB.DBA.CYP_PARSE_LBL_PRIMARY (in _tokens any, inout _pos integer)
{
  declare tt integer;
  declare nm varchar;
  declare sub any;
  tt := DB.DBA.CYP_PEEK (_tokens, _pos);
  if (tt = 22)  -- PERCENT (wildcard)
    {
      _pos := _pos + 1;
      return vector ('LBLEXPR', 'WILD');
    }
  if (tt = 1)  -- LPAREN: parenthesized
    {
      _pos := _pos + 1;
      sub := DB.DBA.CYP_PARSE_LBL_OR (_tokens, _pos);
      DB.DBA.CYP_EXPECT (_tokens, _pos, 2);
      return sub;
    }
  if (tt = 55 or tt = 56)  -- PNAME_NS or IRIREF
    {
      nm := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 1;
      return vector ('LBLEXPR', 'NAME', nm);
    }
  if (tt = 50 or DB.DBA.CYP_IS_NON_RESERVED_KW (tt))
    {
      nm := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 1;
      return vector ('LBLEXPR', 'NAME', nm);
    }
  if (tt = 7)  -- second colon: BASE-relative label name (::Name)
    {
      _pos := _pos + 1;
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);
      if (tt = 50 or DB.DBA.CYP_IS_NON_RESERVED_KW (tt))
        {
          nm := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 1;
          return vector ('LBLEXPR', 'NAME', concat (chr (1), 'BASE', chr (1), nm));
        }
      signal ('CY030', sprintf ('Expected name after :: at position %d', _pos));
    }
  signal ('CY030', sprintf ('Expected label expression at position %d', _pos));
}
;

create procedure DB.DBA.CYP_PARSE_LBL_FACTOR (in _tokens any, inout _pos integer)
{
  declare tt integer;
  declare sub any;
  tt := DB.DBA.CYP_PEEK (_tokens, _pos);
  if (tt = 24)  -- BANG
    {
      _pos := _pos + 1;
      sub := DB.DBA.CYP_PARSE_LBL_FACTOR (_tokens, _pos);
      return vector ('LBLEXPR', 'NOT', sub);
    }
  return DB.DBA.CYP_PARSE_LBL_PRIMARY (_tokens, _pos);
}
;

-- Parse <label term>: factor (('&'|':') factor)*
-- Treats COLON between primaries the same as '&' so legacy ':A:B' AST is
-- syntactically AND-of-NAME and flattens back to ['A','B'].
create procedure DB.DBA.CYP_PARSE_LBL_AND (in _tokens any, inout _pos integer)
{
  declare lhs, rhs any;
  declare tt integer;
  lhs := DB.DBA.CYP_PARSE_LBL_FACTOR (_tokens, _pos);
  while (1)
    {
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);
      if (tt <> 29 and tt <> 7)
        return lhs;
      _pos := _pos + 1;
      rhs := DB.DBA.CYP_PARSE_LBL_FACTOR (_tokens, _pos);
      lhs := vector ('LBLEXPR', 'AND', lhs, rhs);
    }
  return lhs;
}
;

-- Continue an AND term given an already-parsed left-hand side (e.g. a label
-- carried over from the PNAME_NS optimization). Stops when no AND operator.
create procedure DB.DBA.CYP_PARSE_LBL_AND_FROM (in _tokens any, inout _pos integer, in _lhs any)
{
  declare lhs, rhs any;
  declare tt integer;
  lhs := _lhs;
  while (1)
    {
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);
      if (tt <> 29 and tt <> 7)
        return lhs;
      _pos := _pos + 1;
      rhs := DB.DBA.CYP_PARSE_LBL_FACTOR (_tokens, _pos);
      lhs := vector ('LBLEXPR', 'AND', lhs, rhs);
    }
  return lhs;
}
;

create procedure DB.DBA.CYP_PARSE_LBL_OR (in _tokens any, inout _pos integer)
{
  declare lhs, rhs any;
  lhs := DB.DBA.CYP_PARSE_LBL_AND (_tokens, _pos);
  while (DB.DBA.CYP_PEEK (_tokens, _pos) = 25)  -- PIPE
    {
      _pos := _pos + 1;
      -- Allow legacy ':A|:B' shape too.
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 7)
        _pos := _pos + 1;
      rhs := DB.DBA.CYP_PARSE_LBL_AND (_tokens, _pos);
      lhs := vector ('LBLEXPR', 'OR', lhs, rhs);
    }
  return lhs;
}
;

create procedure DB.DBA.CYP_PARSE_LBL_OR_FROM (in _tokens any, inout _pos integer, in _lhs any)
{
  declare lhs, rhs any;
  lhs := DB.DBA.CYP_PARSE_LBL_AND_FROM (_tokens, _pos, _lhs);
  while (DB.DBA.CYP_PEEK (_tokens, _pos) = 25)
    {
      _pos := _pos + 1;
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 7)
        _pos := _pos + 1;
      rhs := DB.DBA.CYP_PARSE_LBL_AND (_tokens, _pos);
      lhs := vector ('LBLEXPR', 'OR', lhs, rhs);
    }
  return lhs;
}
;

-- If the expression is a pure conjunction of NAME atoms, return a flat varchar
-- vector matching the legacy labels representation. Otherwise return null.
create procedure DB.DBA.CYP_LBLEXPR_FLATTEN_AND (in _expr any, inout _names any)
{
  declare kind varchar;
  if (not isarray (_expr) or length (_expr) < 2 or aref (_expr, 0) <> 'LBLEXPR')
    return 0;
  kind := aref (_expr, 1);
  if (kind = 'NAME')
    {
      _names := vector_concat (_names, vector (aref (_expr, 2)));
      return 1;
    }
  if (kind = 'AND')
    {
      if (DB.DBA.CYP_LBLEXPR_FLATTEN_AND (aref (_expr, 2), _names) = 0)
        return 0;
      return DB.DBA.CYP_LBLEXPR_FLATTEN_AND (aref (_expr, 3), _names);
    }
  return 0;
}
;

-- Convert a parsed label expression into the labels representation used by
-- the rest of the parser/translator. Pure AND-of-NAMEs becomes a flat name
-- vector (legacy compatible). Anything more expressive is wrapped in a
-- single-element vector so downstream code can detect the AST form.
create procedure DB.DBA.CYP_LBL_FINALIZE (in _expr any)
{
  declare names any;
  names := vector ();
  if (DB.DBA.CYP_LBLEXPR_FLATTEN_AND (_expr, names))
    return names;
  return vector (_expr);
}
;

-- Returns 1 if labels vector holds a single LBLEXPR AST instead of flat names.
create procedure DB.DBA.CYP_LBLEXPR_IS_AST (in _labels any)
{
  declare first any;
  if (not isarray (_labels) or length (_labels) <> 1)
    return 0;
  first := aref (_labels, 0);
  if (not isarray (first) or length (first) < 2)
    return 0;
  if (aref (first, 0) = 'LBLEXPR')
    return 1;
  return 0;
}
;

-- Parse relationship pattern: -[var:TYPE*min..max {props}]-> or <-[...]- or -[...]-
create procedure DB.DBA.CYP_PARSE_REL_PATTERN (in _tokens any, inout _pos integer)
{
  declare var_name, direction varchar;
  declare types, props any;
  declare min_hops, max_hops any;
  declare tt integer;
  declare rel_pname varchar;
  declare rel_colon integer;
  declare type_name varchar;

  var_name := null;
  types := vector ();
  props := vector ();
  min_hops := null;
  max_hops := null;
  direction := 'NONE';

  tt := DB.DBA.CYP_PEEK (_tokens, _pos);

  -- Determine start direction
  if (tt = 11)  -- <-
    {
      direction := 'LEFT';
      _pos := _pos + 1;
    }
  else if (tt = 12)  -- -
    {
      direction := 'RIGHT';  -- tentative, will confirm with -> at end
      _pos := _pos + 1;
    }
  else
    signal ('CY005', sprintf ('Expected - or <- at position %d', _pos));

  tt := DB.DBA.CYP_PEEK (_tokens, _pos);

  -- Optional bracket section [...]
  if (tt = 3)  -- LBRACKET
    {
      _pos := _pos + 1;
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);

      -- Handle PNAME_NS (55): tokenizer produced var:Type as single token
      if (tt = 55)
        {
          rel_pname := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
          rel_colon := strchr (rel_pname, ':');
          if (rel_colon is not null and rel_colon > 0)
            {
              var_name := subseq (rel_pname, 0, rel_colon);
              type_name := subseq (rel_pname, rel_colon + 1);
              if (DB.DBA.CYP_PEEK (_tokens, _pos + 1) = 7)
                {
                  _pos := _pos + 1;
                  type_name := concat (type_name, ':', DB.DBA.CYP_PEEK_VAL (_tokens, _pos + 1));
                  _pos := _pos + 1;
                }
              types := vector_concat (types, vector (type_name));
            }
          else
            var_name := rel_pname;
          _pos := _pos + 1;
          tt := DB.DBA.CYP_PEEK (_tokens, _pos);
        }
      -- Variable name
      else if (tt = 50)  -- IDENT
        {
          var_name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 1;
          tt := DB.DBA.CYP_PEEK (_tokens, _pos);
        }

      -- Relationship types: ':TYPE' or 'IS TYPE' (openCypher 2024.3)
      if (tt = 7 or tt = 127)  -- COLON or IS
        {
          _pos := _pos + 1;
          if (DB.DBA.CYP_PEEK (_tokens, _pos) = 7)  -- second colon: BASE-relative type
            {
              _pos := _pos + 1;
              if (DB.DBA.CYP_PEEK (_tokens, _pos) = 50 or DB.DBA.CYP_IS_NON_RESERVED_KW (DB.DBA.CYP_PEEK (_tokens, _pos)))
                {
                  types := vector_concat (types,
                    vector (concat (chr (1), 'BASE', chr (1), DB.DBA.CYP_PEEK_VAL (_tokens, _pos))));
                  _pos := _pos + 1;
                }
              else
                signal ('CY005', sprintf ('Expected name after :: at position %d', _pos));
            }
          else if (DB.DBA.CYP_PEEK (_tokens, _pos) = 55 or DB.DBA.CYP_PEEK (_tokens, _pos) = 56)
            {
              types := vector_concat (types, vector (DB.DBA.CYP_PEEK_VAL (_tokens, _pos)));
              _pos := _pos + 1;
            }
          else if (DB.DBA.CYP_PEEK (_tokens, _pos) = 50 or DB.DBA.CYP_IS_NON_RESERVED_KW (DB.DBA.CYP_PEEK (_tokens, _pos)))
            {
              types := vector_concat (types, vector (DB.DBA.CYP_PEEK_VAL (_tokens, _pos)));
              _pos := _pos + 1;
            }
          -- Additional types with |
          while (DB.DBA.CYP_PEEK (_tokens, _pos) = 25)  -- PIPE
            {
              _pos := _pos + 1;
              if (DB.DBA.CYP_PEEK (_tokens, _pos) = 7)  -- COLON (optional after pipe)
                _pos := _pos + 1;
              types := vector_concat (types, vector (DB.DBA.CYP_PEEK_VAL (_tokens, _pos)));
              _pos := _pos + 1;
            }
          tt := DB.DBA.CYP_PEEK (_tokens, _pos);
        }
      -- Additional types with | after a PNAME_NS-introduced type (r:KNOWS|HATES)
      while (DB.DBA.CYP_PEEK (_tokens, _pos) = 25)  -- PIPE
        {
          _pos := _pos + 1;
          if (DB.DBA.CYP_PEEK (_tokens, _pos) = 7)  -- COLON (optional after pipe)
            _pos := _pos + 1;
          types := vector_concat (types, vector (DB.DBA.CYP_PEEK_VAL (_tokens, _pos)));
          _pos := _pos + 1;
        }

      -- Legacy relationship length: *, +, *min..max, *..max, *N
      -- Also: .. (shorthand for *0..) and *-N (reverse exact count)
      if (tt = 20)  -- STAR
        {
          _pos := _pos + 1;
          tt := DB.DBA.CYP_PEEK (_tokens, _pos);
          min_hops := 0;
          max_hops := -1;  -- unbounded
          if (tt = 12)  -- DASH (negative hop count: *-N)
            {
              _pos := _pos + 1;
              tt := DB.DBA.CYP_PEEK (_tokens, _pos);
              if (tt = 52)  -- INTEGER
                {
                  min_hops := atoi (DB.DBA.CYP_PEEK_VAL (_tokens, _pos));
                  max_hops := min_hops;
                  _pos := _pos + 1;
                  tt := DB.DBA.CYP_PEEK (_tokens, _pos);
                }
            }
          else if (tt = 52)  -- INTEGER
            {
              min_hops := atoi (DB.DBA.CYP_PEEK_VAL (_tokens, _pos));
              max_hops := min_hops;
              _pos := _pos + 1;
              tt := DB.DBA.CYP_PEEK (_tokens, _pos);
            }
          if (tt = 26)  -- DOTDOT
            {
              _pos := _pos + 1;
              tt := DB.DBA.CYP_PEEK (_tokens, _pos);
              if (tt = 52)  -- INTEGER
                {
                  max_hops := atoi (DB.DBA.CYP_PEEK_VAL (_tokens, _pos));
                  _pos := _pos + 1;
                  tt := DB.DBA.CYP_PEEK (_tokens, _pos);
                }
              else
                max_hops := -1;
            }
        }
      else if (tt = 26)  -- DOTDOT (shorthand for *0..)
        {
          _pos := _pos + 1;
          min_hops := 0;
          max_hops := -1;
          tt := DB.DBA.CYP_PEEK (_tokens, _pos);
          if (tt = 52)  -- INTEGER
            {
              max_hops := atoi (DB.DBA.CYP_PEEK_VAL (_tokens, _pos));
              _pos := _pos + 1;
              tt := DB.DBA.CYP_PEEK (_tokens, _pos);
            }
        }
      else if (tt = 19)  -- PLUS
        {
          min_hops := 1;
          max_hops := -1;
          _pos := _pos + 1;
          tt := DB.DBA.CYP_PEEK (_tokens, _pos);
        }

      -- Parameter map: -[r:FOO $param]->
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 28)  -- DOLLAR
        {
          declare rel_param_name varchar;
          _pos := _pos + 1;
          if (DB.DBA.CYP_PEEK (_tokens, _pos) = 50)
            {
              rel_param_name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
              _pos := _pos + 1;
              props := vector_concat (props, vector (vector ('PARAMPROPS', rel_param_name)));
            }
        }

      -- Properties
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 5)  -- LBRACE
        props := DB.DBA.CYP_PARSE_PROPERTIES (_tokens, _pos);

      DB.DBA.CYP_EXPECT (_tokens, _pos, 4);  -- RBRACKET
    }

  -- Determine final direction from end arrow
  tt := DB.DBA.CYP_PEEK (_tokens, _pos);
  if (direction = 'LEFT')
    {
      -- We started with <-, expect - or -> at end (-> supports <-->)
      if (tt = 12)  -- DASH
        {
          _pos := _pos + 1;
          if (DB.DBA.CYP_PEEK (_tokens, _pos) = 14)  -- >
            {
              _pos := _pos + 1;
              direction := 'BOTH';
            }
        }
      else if (tt = 10)  -- ->
        {
          _pos := _pos + 1;
          direction := 'BOTH';
        }
      else
        signal ('CY005', sprintf ('Expected - after relationship bracket at position %d', _pos));
    }
  else
    {
      -- We started with -, check for -> or just -
      if (tt = 10)  -- ->
        {
          direction := 'RIGHT';
          _pos := _pos + 1;
        }
      else if (tt = 12)  -- just another -
        {
          direction := 'BOTH';
          _pos := _pos + 1;
        }
      else
        signal ('CY005', sprintf ('Expected -> or - after relationship at position %d', _pos));
    }

  return vector ('REL', var_name, types, direction, min_hops, max_hops, props);
}
;

-- Parse property map: {key: value, key2: value2, ...}
create procedure DB.DBA.CYP_PARSE_PROPERTIES (in _tokens any, inout _pos integer)
{
  declare props any;
  declare key_name varchar;
  declare val any;

  props := vector ();
  DB.DBA.CYP_EXPECT (_tokens, _pos, 5);  -- LBRACE

  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 6)  -- empty map {}
    {
      _pos := _pos + 1;
      return props;
    }

  while (1)
    {
      -- key name (identifier or keyword-as-identifier)
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 7)
        {
          _pos := _pos + 1;
          if (DB.DBA.CYP_PEEK (_tokens, _pos) <> 50
              and not DB.DBA.CYP_IS_NON_RESERVED_KW (DB.DBA.CYP_PEEK (_tokens, _pos)))
            signal ('CY006', sprintf ('Expected property name after default prefix at position %d',
                    _pos));
          key_name := concat (':', DB.DBA.CYP_PEEK_VAL (_tokens, _pos));
          _pos := _pos + 1;
        }
      else
        {
          if (DB.DBA.CYP_PEEK (_tokens, _pos) <> 50
              and DB.DBA.CYP_PEEK (_tokens, _pos) <> 55
              and DB.DBA.CYP_PEEK (_tokens, _pos) <> 56
              and not DB.DBA.CYP_IS_NON_RESERVED_KW (DB.DBA.CYP_PEEK (_tokens, _pos)))
            signal ('CY006', sprintf ('Expected property name at position %d, got ''%s''',
                    _pos, DB.DBA.CYP_PEEK_VAL (_tokens, _pos)));
          key_name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 1;
        }
      DB.DBA.CYP_EXPECT (_tokens, _pos, 7);  -- COLON
      val := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
      props := vector_concat (props, vector (vector (key_name, val)));

      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 9)  -- COMMA
        _pos := _pos + 1;
      else
        goto props_done;
    }
  props_done:
  DB.DBA.CYP_EXPECT (_tokens, _pos, 6);  -- RBRACE
  return props;
}
;

-- Parse WHERE clause
create procedure DB.DBA.CYP_PARSE_WHERE (in _tokens any, inout _pos integer)
{
  declare expr any;

  _pos := _pos + 1;  -- consume WHERE
  expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
  return vector ('WHERE', expr);
}
;

-- Parse RETURN clause
create procedure DB.DBA.CYP_PARSE_RETURN (in _tokens any, inout _pos integer)
{
  declare is_distinct integer;
  declare items, order_by any;
  declare group_by, having_expr any;
  declare skip_expr, limit_expr any;

  _pos := _pos + 1;  -- consume RETURN
  is_distinct := 0;
  order_by := null;
  group_by := null;
  having_expr := null;
  skip_expr := null;
  limit_expr := null;

  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 121)  -- DISTINCT
    {
      is_distinct := 1;
      _pos := _pos + 1;
    }

  items := DB.DBA.CYP_PARSE_RETURN_ITEMS (_tokens, _pos);

  -- GROUP BY
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 163)  -- GROUP
    {
      _pos := _pos + 1;
      DB.DBA.CYP_EXPECT (_tokens, _pos, 114);  -- BY
      group_by := DB.DBA.CYP_PARSE_EXPR_LIST (_tokens, _pos);
    }

  -- HAVING
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 164)  -- HAVING
    {
      _pos := _pos + 1;
      having_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
    }

  -- ORDER BY
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 113)  -- ORDER
    {
      _pos := _pos + 1;
      DB.DBA.CYP_EXPECT (_tokens, _pos, 114);  -- BY
      order_by := DB.DBA.CYP_PARSE_SORT_ITEMS (_tokens, _pos);
    }

  -- SKIP / OFFSET (openCypher 2024.3 synonym)
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 117)  -- SKIP | OFFSET
    {
      _pos := _pos + 1;
      skip_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
    }

  -- LIMIT
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 118)  -- LIMIT
    {
      _pos := _pos + 1;
      limit_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
    }

  return vector ('RETURN', is_distinct, items, order_by, skip_expr, limit_expr, group_by, having_expr);
}
;

-- Parse return items (comma-separated expressions with optional aliases)
create procedure DB.DBA.CYP_PARSE_RETURN_ITEMS (in _tokens any, inout _pos integer)
{
  declare items any;
  declare expr any;
  declare alias_name varchar;

  items := vector ();

  -- Check for RETURN *
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 20)  -- STAR
    {
      _pos := _pos + 1;
      return vector (vector ('RETITEM', vector ('VAR', '*'), null));
    }

  while (1)
    {
      expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
      alias_name := null;
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 112)  -- AS
        {
          _pos := _pos + 1;
          alias_name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 1;
        }
      items := vector_concat (items, vector (vector ('RETITEM', expr, alias_name)));
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 9)  -- COMMA
        _pos := _pos + 1;
      else
        goto retitems_done;
    }
  retitems_done:
  return items;
}
;

-- Parse sort items
create procedure DB.DBA.CYP_PARSE_SORT_ITEMS (in _tokens any, inout _pos integer)
{
  declare items any;
  declare expr any;
  declare dir varchar;
  declare tt integer;

  items := vector ();
  while (1)
    {
      expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
      dir := 'ASC';
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);
      if (tt = 115 or tt = 144)  -- ASC or ASCENDING
        { dir := 'ASC'; _pos := _pos + 1; }
      else if (tt = 116 or tt = 145)  -- DESC or DESCENDING
        { dir := 'DESC'; _pos := _pos + 1; }
      items := vector_concat (items, vector (vector ('SORT', expr, dir)));
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 9)  -- COMMA
        _pos := _pos + 1;
      else
        goto sortdone;
    }
  sortdone:
  return items;
}
;

create procedure DB.DBA.CYP_PARSE_EXPR_LIST (in _tokens any, inout _pos integer)
{
  declare items any;

  items := vector ();
  while (1)
    {
      items := vector_concat (items, vector (DB.DBA.CYP_PARSE_EXPR (_tokens, _pos)));
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 9)
        _pos := _pos + 1;
      else
        goto exprlistdone;
    }
  exprlistdone:
  return items;
}
;

create procedure DB.DBA.CYP_PARSE_SPARQL_SILENT (in _tokens any, inout _pos integer)
{
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 174)  -- SILENT
    {
      _pos := _pos + 1;
      return 1;
    }
  return 0;
}
;

create procedure DB.DBA.CYP_PARSE_SPARQL_GRAPH_TARGET (in _tokens any, inout _pos integer, in _allow_dataset integer)
{
  declare tt integer;
  tt := DB.DBA.CYP_PEEK (_tokens, _pos);

  if (tt = 154)  -- GRAPH
    {
      _pos := _pos + 1;
      return vector ('GRAPH', DB.DBA.CYP_PARSE_EXPR (_tokens, _pos));
    }
  if (tt = 175)  -- DEFAULT
    {
      _pos := _pos + 1;
      return vector ('DEFAULT', null);
    }
  if (_allow_dataset and tt = 158)  -- NAMED
    {
      _pos := _pos + 1;
      return vector ('NAMED', null);
    }
  if (_allow_dataset and tt = 120)  -- ALL
    {
      _pos := _pos + 1;
      return vector ('ALL', null);
    }
  signal ('CY034', 'Expected GRAPH, DEFAULT, NAMED, or ALL graph target');
}
;

create procedure DB.DBA.CYP_PARSE_SPARQL_LOAD (in _tokens any, inout _pos integer)
{
  declare silent integer;
  declare source_expr, target_expr any;

  _pos := _pos + 1;  -- consume LOAD
  silent := DB.DBA.CYP_PARSE_SPARQL_SILENT (_tokens, _pos);
  source_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
  target_expr := null;

  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 155)  -- INTO
    {
      _pos := _pos + 1;
      if (DB.DBA.CYP_PEEK (_tokens, _pos) <> 154)
        signal ('CY035', 'Expected GRAPH after LOAD ... INTO');
      _pos := _pos + 1;
      target_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
    }

  return vector ('SPARQL_LOAD', silent, source_expr, target_expr);
}
;

create procedure DB.DBA.CYP_PARSE_SPARQL_CLEAR_DROP (in _tokens any, inout _pos integer, in _kind varchar)
{
  declare silent integer;
  declare target any;

  _pos := _pos + 1;  -- consume CLEAR or DROP
  silent := DB.DBA.CYP_PARSE_SPARQL_SILENT (_tokens, _pos);
  target := DB.DBA.CYP_PARSE_SPARQL_GRAPH_TARGET (_tokens, _pos, 1);
  return vector (_kind, silent, aref (target, 0), aref (target, 1));
}
;

create procedure DB.DBA.CYP_PARSE_SPARQL_CREATE_GRAPH (in _tokens any, inout _pos integer)
{
  declare silent integer;
  declare graph_expr any;

  _pos := _pos + 1;  -- consume CREATE
  silent := DB.DBA.CYP_PARSE_SPARQL_SILENT (_tokens, _pos);
  DB.DBA.CYP_EXPECT (_tokens, _pos, 154);  -- GRAPH
  graph_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
  return vector ('SPARQL_CREATE_GRAPH', silent, graph_expr);
}
;

create procedure DB.DBA.CYP_PARSE_SPARQL_GRAPH_COPY (in _tokens any, inout _pos integer)
{
  declare tt, silent integer;
  declare op varchar;
  declare source, target any;

  tt := DB.DBA.CYP_PEEK (_tokens, _pos);
  if (tt = 171) op := 'ADD';
  else if (tt = 172) op := 'MOVE';
  else if (tt = 173) op := 'COPY';
  else signal ('CY036', 'Expected ADD, MOVE, or COPY');

  _pos := _pos + 1;
  silent := DB.DBA.CYP_PARSE_SPARQL_SILENT (_tokens, _pos);
  source := DB.DBA.CYP_PARSE_SPARQL_GRAPH_TARGET (_tokens, _pos, 0);
  DB.DBA.CYP_EXPECT (_tokens, _pos, 176);  -- TO
  target := DB.DBA.CYP_PARSE_SPARQL_GRAPH_TARGET (_tokens, _pos, 0);

  return vector ('SPARQL_GRAPH_COPY', op, silent,
                 aref (source, 0), aref (source, 1),
                 aref (target, 0), aref (target, 1));
}
;

create procedure DB.DBA.CYP_PARSE_SPARQL_DATA_UPDATE (in _tokens any, inout _pos integer, in _op varchar)
{
  declare clauses any;

  _pos := _pos + 1;  -- consume INSERT or DELETE
  DB.DBA.CYP_EXPECT (_tokens, _pos, 179);  -- DATA
  DB.DBA.CYP_EXPECT (_tokens, _pos, 5);    -- {
  clauses := DB.DBA.CYP_PARSE_STATEMENT (_tokens, _pos);
  DB.DBA.CYP_EXPECT (_tokens, _pos, 6);    -- }
  return vector ('SPARQL_DATA_UPDATE', _op, clauses);
}
;

-- Parse CREATE clause with optional INTO GRAPH
create procedure DB.DBA.CYP_PARSE_CREATE (in _tokens any, inout _pos integer)
{
  declare patterns any;
  declare graph_expr any;

  _pos := _pos + 1;  -- consume CREATE

  -- Check for INTO GRAPH clause
  graph_expr := null;
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 155)  -- INTO
    {
      _pos := _pos + 1;  -- consume INTO
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 154)  -- GRAPH_KW
        {
          _pos := _pos + 1;  -- consume GRAPH
          -- Parse graph expression (IRI or variable)
          graph_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
        }
      else
        signal ('CY011', 'Expected GRAPH after INTO');
    }

  patterns := DB.DBA.CYP_PARSE_PATTERN_LIST (_tokens, _pos);
  return vector ('CREATE', patterns, graph_expr);
}
;

-- Parse DELETE clause
create procedure DB.DBA.CYP_PARSE_DELETE (in _tokens any, inout _pos integer, in _detach integer)
{

  _pos := _pos + 1;  -- consume DELETE
  return DB.DBA.CYP_PARSE_DELETE_ITEMS (_tokens, _pos, _detach);
}
;

create procedure DB.DBA.CYP_PARSE_DELETE_ITEMS (in _tokens any, inout _pos integer, in _detach integer)
{
  declare items, expr any;

  items := vector ();
  while (1)
    {
      expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
      items := vector_concat (items, vector (expr));
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 9)  -- COMMA
        _pos := _pos + 1;
      else
        goto deldone;
    }
  deldone:
  return vector ('DELETE', _detach, items);
}
;

-- Parse SET clause
create procedure DB.DBA.CYP_PARSE_SET (in _tokens any, inout _pos integer)
{
  declare items, item any;
  declare var_name, prop_name varchar;
  declare expr any;
  declare tt integer;
  declare lbls any;
  declare pname_val varchar;
  declare colon_pos integer;

  _pos := _pos + 1;  -- consume SET
  items := vector ();

  while (1)
    {
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 55)
        {
          pname_val := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
          colon_pos := strchr (pname_val, ':');
          if (colon_pos is not null and colon_pos > 0)
            {
              var_name := subseq (pname_val, 0, colon_pos);
              lbls := vector (subseq (pname_val, colon_pos + 1));
              _pos := _pos + 1;
              while (DB.DBA.CYP_PEEK (_tokens, _pos) = 7)
                {
                  _pos := _pos + 1;
                  lbls := vector_concat (lbls, vector (DB.DBA.CYP_PEEK_VAL (_tokens, _pos)));
                  _pos := _pos + 1;
                }
              items := vector_concat (items, vector (vector ('SETLABEL', var_name, lbls)));
              goto set_item_done;
            }
        }

      -- Could be: var.prop = expr, var = expr, var += expr, var:Label
      -- Use postfix expr to avoid consuming '=' as comparison operator
      expr := DB.DBA.CYP_PARSE_POSTFIX_EXPR (_tokens, _pos);
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);

      if (tt = 15)  -- EQ (=)
        {
          _pos := _pos + 1;
          item := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
          if (aref (expr, 0) = 'VAR')
            -- SET n = expr (property replacement); is_plus = 0
            items := vector_concat (items, vector (vector ('SETALL', aref (expr, 1), item, 0)));
          else
            -- SET n.prop = expr (single property update)
            items := vector_concat (items, vector (vector ('SETPROP', expr, item)));
        }
      else if (tt = 27)  -- PLUSEQ (+=)
        {
          _pos := _pos + 1;
          if (aref (expr, 0) = 'VAR')
            {
              item := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
              items := vector_concat (items, vector (vector ('SETALL', aref (expr, 1), item, 1)));
            }
          else
            signal ('CY007', 'Expected variable before +=');
        }
      else if (tt = 7)  -- COLON - setting labels: SET n:Label
        {
          if (aref (expr, 0) = 'VAR')
            {
              lbls := vector ();
              while (DB.DBA.CYP_PEEK (_tokens, _pos) = 7)
                {
                  _pos := _pos + 1;
                  lbls := vector_concat (lbls, vector (DB.DBA.CYP_PEEK_VAL (_tokens, _pos)));
                  _pos := _pos + 1;
                }
              items := vector_concat (items, vector (vector ('SETLABEL', aref (expr, 1), lbls)));
            }
          else
            signal ('CY007', 'Expected variable before :Label in SET');
        }
      else
        signal ('CY007', sprintf ('Expected =, += or :Label in SET clause at position %d', _pos));

      set_item_done:
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 9)  -- COMMA
        _pos := _pos + 1;
      else
        goto setdone;
    }
  setdone:
  return vector ('SET', items);
}
;

-- Parse REMOVE clause
create procedure DB.DBA.CYP_PARSE_REMOVE (in _tokens any, inout _pos integer)
{
  declare items, expr any;
  declare tt integer;
  declare lbls any;

  _pos := _pos + 1;  -- consume REMOVE
  items := vector ();

  while (1)
    {
      expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);

      if (tt = 7)  -- COLON - removing labels
        {
          if (aref (expr, 0) = 'VAR')
            {
              lbls := vector ();
              while (DB.DBA.CYP_PEEK (_tokens, _pos) = 7)
                {
                  _pos := _pos + 1;
                  lbls := vector_concat (lbls, vector (DB.DBA.CYP_PEEK_VAL (_tokens, _pos)));
                  _pos := _pos + 1;
                }
              items := vector_concat (items, vector (vector ('RMLABEL', aref (expr, 1), lbls)));
            }
          else
            signal ('CY008', 'Expected variable before :Label in REMOVE');
        }
      else
        {
          -- Removing a property: REMOVE n.prop
          items := vector_concat (items, vector (vector ('RMPROP', expr)));
        }

      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 9)  -- COMMA
        _pos := _pos + 1;
      else
        goto rmdone;
    }
  rmdone:
  return vector ('REMOVE', items);
}
;

-- Parse MERGE clause
create procedure DB.DBA.CYP_PARSE_MERGE (in _tokens any, inout _pos integer)
{
  declare patterns, on_create, on_match, from_graphs any;
  declare tt integer;

  _pos := _pos + 1;  -- consume MERGE
  patterns := DB.DBA.CYP_PARSE_PATTERN_LIST (_tokens, _pos);
  from_graphs := vector ();
  while (DB.DBA.CYP_PEEK (_tokens, _pos) = 156)  -- FROM
    {
      _pos := _pos + 1;
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 158)  -- NAMED
        {
          _pos := _pos + 1;
          from_graphs := vector_concat (from_graphs, vector (vector ('FROM_NAMED', DB.DBA.CYP_PARSE_EXPR (_tokens, _pos))));
        }
      else if (DB.DBA.CYP_PEEK (_tokens, _pos) = 154)  -- GRAPH_KW
        {
          _pos := _pos + 1;
          from_graphs := vector_concat (from_graphs, vector (vector ('FROM', DB.DBA.CYP_PARSE_EXPR (_tokens, _pos))));
        }
      else
        from_graphs := vector_concat (from_graphs, vector (vector ('FROM', DB.DBA.CYP_PARSE_EXPR (_tokens, _pos))));
    }
  on_create := null;
  on_match := null;

  while (DB.DBA.CYP_PEEK (_tokens, _pos) = 134)  -- ON
    {
      _pos := _pos + 1;
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);
      if (tt = 100)  -- MATCH
        {
          _pos := _pos + 1;
          on_match := DB.DBA.CYP_PARSE_SET (_tokens, _pos);
        }
      else if (tt = 104)  -- CREATE
        {
          _pos := _pos + 1;
          on_create := DB.DBA.CYP_PARSE_SET (_tokens, _pos);
        }
      else
        signal ('CY009', 'Expected MATCH or CREATE after ON in MERGE');
    }

  return vector ('MERGE', patterns, on_create, on_match, from_graphs);
}
;

-- Parse WITH clause (like RETURN but with optional WHERE)
create procedure DB.DBA.CYP_PARSE_WITH (in _tokens any, inout _pos integer)
{
  declare is_distinct integer;
  declare items, order_by, where_expr any;
  declare skip_expr, limit_expr any;

  _pos := _pos + 1;  -- consume WITH
  is_distinct := 0;
  order_by := null;
  skip_expr := null;
  limit_expr := null;
  where_expr := null;

  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 121)  -- DISTINCT
    {
      is_distinct := 1;
      _pos := _pos + 1;
    }

  items := DB.DBA.CYP_PARSE_RETURN_ITEMS (_tokens, _pos);

  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 113)  -- ORDER
    {
      _pos := _pos + 1;
      DB.DBA.CYP_EXPECT (_tokens, _pos, 114);  -- BY
      order_by := DB.DBA.CYP_PARSE_SORT_ITEMS (_tokens, _pos);
    }
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 117)  -- SKIP | OFFSET (openCypher 2024.3 synonym)
    {
      _pos := _pos + 1;
      skip_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
    }
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 118)  -- LIMIT
    {
      _pos := _pos + 1;
      limit_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
    }
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 102)  -- WHERE
    {
      _pos := _pos + 1;
      where_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
    }

  return vector ('WITH', is_distinct, items, order_by, skip_expr, limit_expr, where_expr);
}
;

-- Parse UNWIND clause
create procedure DB.DBA.CYP_PARSE_UNWIND (in _tokens any, inout _pos integer)
{
  declare expr any;
  declare alias_name varchar;

  _pos := _pos + 1;  -- consume UNWIND
  expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
  DB.DBA.CYP_EXPECT (_tokens, _pos, 112);  -- AS
  alias_name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
  _pos := _pos + 1;
  return vector ('UNWIND', expr, alias_name);
}
;

-- Parse PREFIX clause: PREFIX prefix: <uri>
create procedure DB.DBA.CYP_PARSE_PREFIX (in _tokens any, inout _pos integer)
{
  declare prefix_name varchar;
  declare uri_val varchar;
  declare tt integer;

  _pos := _pos + 1;  -- consume PREFIX

  -- Prefix name should be a prefixed name token (e.g., "foaf:"),
  -- identifier followed by colon, or a bare colon for the default prefix.
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 7)  -- COLON
    {
      prefix_name := '';
      _pos := _pos + 1;
    }
  else if (DB.DBA.CYP_PEEK (_tokens, _pos) = 50)  -- IDENT
    {
      prefix_name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 1;
      DB.DBA.CYP_EXPECT (_tokens, _pos, 7);  -- COLON
    }
  else if (DB.DBA.CYP_PEEK (_tokens, _pos) = 55)  -- PNAME_NS (prefixed name)
    {
      -- Token already includes prefix:localname or just prefix:
      declare full_name varchar;
      full_name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
      -- Extract just the prefix part (before :)
      declare colon_pos integer;
      colon_pos := locate (':', full_name);
      if (colon_pos > 0)
        prefix_name := subseq (full_name, 0, colon_pos);
      else
        prefix_name := full_name;
      _pos := _pos + 1;
    }
  else
    signal ('CY010', sprintf ('Expected prefix name at position %d', _pos));

  -- URI should be a string literal or IRIref
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 51)  -- STRING
    {
      uri_val := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 1;
    }
  else if (DB.DBA.CYP_PEEK (_tokens, _pos) = 56)  -- IRIREF
    {
      uri_val := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 1;
    }
  else if (DB.DBA.CYP_PEEK (_tokens, _pos) = 13)  -- LT, IRI ref start
    {
      _pos := _pos + 1;
      uri_val := '';
      while (DB.DBA.CYP_PEEK (_tokens, _pos) <> 14 and DB.DBA.CYP_PEEK (_tokens, _pos) <> 999)
        {
          uri_val := concat (uri_val, DB.DBA.CYP_PEEK_VAL (_tokens, _pos));
          _pos := _pos + 1;
        }
      DB.DBA.CYP_EXPECT (_tokens, _pos, 14);  -- GT
    }
  else
    signal ('CY010', sprintf ('Expected URI string after prefix at position %d', _pos));

  return vector ('PREFIX', prefix_name, uri_val);
}
;

-- Parse BASE clause: BASE <iri>
create procedure DB.DBA.CYP_PARSE_BASE (in _tokens any, inout _pos integer)
{
  declare uri_val varchar;

  _pos := _pos + 1;  -- consume BASE

  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 56)  -- IRIREF
    {
      uri_val := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 1;
    }
  else if (DB.DBA.CYP_PEEK (_tokens, _pos) = 51)  -- STRING
    {
      uri_val := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 1;
    }
  else if (DB.DBA.CYP_PEEK (_tokens, _pos) = 13)  -- LT, IRI ref start
    {
      _pos := _pos + 1;
      uri_val := '';
      while (DB.DBA.CYP_PEEK (_tokens, _pos) <> 14 and DB.DBA.CYP_PEEK (_tokens, _pos) <> 999)
        {
          uri_val := concat (uri_val, DB.DBA.CYP_PEEK_VAL (_tokens, _pos));
          _pos := _pos + 1;
        }
      DB.DBA.CYP_EXPECT (_tokens, _pos, 14);  -- GT
    }
  else
    signal ('CY010', sprintf ('Expected <iri> after BASE at position %d', _pos));

  return vector ('BASE', uri_val);
}
;

create procedure DB.DBA.CYP_PARSE_DEFINE (in _tokens any, inout _pos integer)
{
  declare key_name varchar;
  declare val_expr any;

  _pos := _pos + 1;  -- consume DEFINE
  key_name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
  if (DB.DBA.CYP_PEEK (_tokens, _pos) <> 50 and DB.DBA.CYP_PEEK (_tokens, _pos) <> 55)
    signal ('CY010', sprintf ('Expected DEFINE key at position %d', _pos));
  _pos := _pos + 1;
  val_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
  return vector ('DEFINE', key_name, val_expr);
}
;

create procedure DB.DBA.CYP_PARSE_BLOCK_CLAUSES (in _tokens any, inout _pos integer)
{
  declare clauses any;
  DB.DBA.CYP_EXPECT (_tokens, _pos, 5);  -- {
  clauses := DB.DBA.CYP_PARSE_STATEMENT (_tokens, _pos);
  DB.DBA.CYP_EXPECT (_tokens, _pos, 6);  -- }
  return clauses;
}
;

create procedure DB.DBA.CYP_PARSE_GRAPH_BLOCK (in _tokens any, inout _pos integer)
{
  declare graph_expr any;
  declare clauses any;

  _pos := _pos + 1;  -- consume GRAPH
  graph_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
  clauses := DB.DBA.CYP_PARSE_BLOCK_CLAUSES (_tokens, _pos);
  return vector ('GRAPH', graph_expr, clauses);
}
;

create procedure DB.DBA.CYP_PARSE_SERVICE (in _tokens any, inout _pos integer)
{
  declare endpoint_expr any;
  declare clauses any;

  _pos := _pos + 1;  -- consume SERVICE
  endpoint_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
  clauses := DB.DBA.CYP_PARSE_BLOCK_CLAUSES (_tokens, _pos);
  return vector ('SERVICE', endpoint_expr, clauses);
}
;

create procedure DB.DBA.CYP_PARSE_VALUES (in _tokens any, inout _pos integer)
{
  declare var_name varchar;
  declare vals any;

  _pos := _pos + 1;  -- consume VALUES
  if (DB.DBA.CYP_PEEK (_tokens, _pos) <> 50)
    signal ('CY010', sprintf ('Expected VALUES variable at position %d', _pos));
  var_name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
  _pos := _pos + 1;

  vals := vector ();
  DB.DBA.CYP_EXPECT (_tokens, _pos, 5);  -- {
  while (DB.DBA.CYP_PEEK (_tokens, _pos) <> 6 and DB.DBA.CYP_PEEK (_tokens, _pos) <> 999)
    {
      vals := vector_concat (vals, vector (DB.DBA.CYP_PARSE_EXPR (_tokens, _pos)));
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 9)
        _pos := _pos + 1;
    }
  DB.DBA.CYP_EXPECT (_tokens, _pos, 6);  -- }
  return vector ('VALUES', var_name, vals);
}
;

create procedure DB.DBA.CYP_PARSE_BIND (in _tokens any, inout _pos integer)
{
  declare expr any;
  declare alias_name varchar;

  _pos := _pos + 1;  -- consume BIND
  DB.DBA.CYP_EXPECT (_tokens, _pos, 1);  -- (
  expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
  DB.DBA.CYP_EXPECT (_tokens, _pos, 112);  -- AS
  if (DB.DBA.CYP_PEEK (_tokens, _pos) <> 50)
    signal ('CY010', sprintf ('Expected BIND alias at position %d', _pos));
  alias_name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
  _pos := _pos + 1;
  DB.DBA.CYP_EXPECT (_tokens, _pos, 2);  -- )
  return vector ('BIND', expr, alias_name);
}
;

create procedure DB.DBA.CYP_PARSE_MINUS (in _tokens any, inout _pos integer)
{
  declare clauses any;

  _pos := _pos + 1;  -- consume MINUS
  clauses := DB.DBA.CYP_PARSE_BLOCK_CLAUSES (_tokens, _pos);
  return vector ('MINUS', clauses);
}
;

create procedure DB.DBA.CYP_PARSE_CONSTRUCT (in _tokens any, inout _pos integer)
{
  declare clauses any;

  _pos := _pos + 1;  -- consume CONSTRUCT
  clauses := DB.DBA.CYP_PARSE_BLOCK_CLAUSES (_tokens, _pos);
  return vector ('CONSTRUCT', clauses);
}
;

create procedure DB.DBA.CYP_PARSE_DESCRIBE (in _tokens any, inout _pos integer)
{
  declare items any;
  declare expr any;

  _pos := _pos + 1;  -- consume DESCRIBE
  items := vector ();
  while (1)
    {
      expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
      items := vector_concat (items, vector (vector ('RETITEM', expr, null)));
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 9)
        _pos := _pos + 1;
      else
        goto describedone;
    }
  describedone:
  return vector ('DESCRIBE', items);
}
;

-- Parse CALL procedure statement: CALL proc(args) YIELD field AS alias, ...
-- or standalone: CALL proc(args)
-- AST: ('CALL', proc_name, args_vec, yield_items, yield_where)
-- yield_items: vector of ('YIELDITEM', field_name, alias_name)
create procedure DB.DBA.CYP_PARSE_CALL (in _tokens any, inout _pos integer)
{
  declare proc_name varchar;
  declare args any;
  declare yield_items, yield_where any;
  declare has_yield integer;

  _pos := _pos + 1;  -- consume CALL

  -- Parse procedure name
  proc_name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
  _pos := _pos + 1;

  -- Check for qualified names (opencypher.labels, test.my.proc, ...)
  while (DB.DBA.CYP_PEEK (_tokens, _pos) = 8)  -- '.'
    {
      _pos := _pos + 1;
      proc_name := concat (proc_name, '.', DB.DBA.CYP_PEEK_VAL (_tokens, _pos));
      _pos := _pos + 1;
    }

  -- Parse optional arguments (parentheses may be omitted when no args)
  args := vector ();
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 1)  -- '('
    {
      _pos := _pos + 1;
      if (DB.DBA.CYP_PEEK (_tokens, _pos) <> 2)  -- not ')'
        {
          while (1)
            {
              args := vector_concat (args, vector (DB.DBA.CYP_PARSE_EXPR (_tokens, _pos)));
              if (DB.DBA.CYP_PEEK (_tokens, _pos) = 9)  -- ','
                _pos := _pos + 1;
              else
                goto argsdone;
            }
        }
    argsdone:
      DB.DBA.CYP_EXPECT (_tokens, _pos, 2);  -- ')'
    }

  -- Parse optional YIELD clause
  yield_items := null;
  yield_where := null;
  has_yield := 1;

  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 143)  -- YIELD
    {
      _pos := _pos + 1;  -- consume YIELD

      -- Check for YIELD *
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 6)  -- '*'
        {
          _pos := _pos + 1;
          yield_items := vector (vector ('YIELDSTAR'));
        }
      else
        {
          yield_items := vector ();
          while (1)
            {
              declare field_name, alias_name varchar;
              field_name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
              _pos := _pos + 1;
              alias_name := null;

              if (DB.DBA.CYP_PEEK (_tokens, _pos) = 112)  -- AS
                {
                  _pos := _pos + 1;
                  alias_name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
                  _pos := _pos + 1;
                }

              yield_items := vector_concat (yield_items, vector (vector ('YIELDITEM', field_name, alias_name)));

              if (DB.DBA.CYP_PEEK (_tokens, _pos) = 9)  -- ','
                _pos := _pos + 1;
              else
                goto yielddone;
            }
        }
    }
  yielddone:

  -- Parse optional WHERE after YIELD
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 107)  -- WHERE
    {
      _pos := _pos + 1;
      yield_where := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
    }

  return vector ('CALL', proc_name, args, yield_items, yield_where);
}
;

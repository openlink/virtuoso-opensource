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
--  openGQL: GQL for Virtuoso - Expression Parser
--
--  Copyright (C) 1998-2026 OpenLink Software
--
--  Recursive-descent expression parser with operator precedence.
--  Precedence (lowest to highest):
--    OR > XOR > AND > NOT > IMPLIES (=>) > Comparison > Addition
--    > Multiplication > Power > Unary > Postfix > Primary
--
--  AST tags reuse openCypher conventions for translator code sharing:
--    BINOP, UNOP, LIT, LIT_BOOL, VAR, PROP, FUNC, FUNC_DISTINCT,
--    COUNTSTAR, ISNULL, INEXPR, STROP, CASEEXPR, PARAM, LIST,
--    MAP, RECORD, IRI, TYPEDLIT, PATTERNPRED, SLICE, MAPPROJ,
--    LISTCOMP, EXISTS_SUBQUERY, LANGLIT, FLOAT
--

----------------------------------------------------------------------
-- Entry point
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_EXPR (in _tokens any, inout _pos integer)
{
  return DB.DBA.GQL_PARSE_OR_EXPR (_tokens, _pos);
}
;

----------------------------------------------------------------------
-- Integer literal converter (decimal, hex 0x, octal 0o, binary 0b)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_INT_LITERAL (in _val varchar)
  returns integer
{
  declare _len, _i, _ch, _digit, _acc integer;
  declare _is_neg integer;

  _len := length (_val);
  _i := 0;
  _is_neg := 0;

  -- Strip trailing GQL suffix (M)
  if (_len > 0 and (aref (_val, _len - 1) = 77))
    _len := _len - 1;

  if (_len > 0 and aref (_val, 0) = 45)  -- '-'
    { _is_neg := 1; _i := 1; }
  else if (_len > 0 and aref (_val, 0) = 43)  -- '+'
    { _i := 1; }

  -- Hex: 0x...
  if (_i + 1 < _len and aref (_val, _i) = 48
      and (aref (_val, _i + 1) = 120 or aref (_val, _i + 1) = 88))
    {
      _i := _i + 2;
      _acc := 0;
      while (_i < _len)
        {
          _ch := aref (_val, _i);
          if (_ch >= 48 and _ch <= 57) _digit := _ch - 48;
          else if (_ch >= 65 and _ch <= 70) _digit := _ch - 55;
          else if (_ch >= 97 and _ch <= 102) _digit := _ch - 87;
          else signal ('GQ004', sprintf ('Invalid hex digit in literal %s', _val));
          _acc := _acc * 16 + _digit;
          _i := _i + 1;
        }
      if (_is_neg) return -_acc;
      return _acc;
    }

  -- Octal: 0o...
  if (_i + 1 < _len and aref (_val, _i) = 48
      and (aref (_val, _i + 1) = 111 or aref (_val, _i + 1) = 79))
    {
      _i := _i + 2;
      _acc := 0;
      while (_i < _len)
        {
          _ch := aref (_val, _i);
          if (_ch >= 48 and _ch <= 55) _digit := _ch - 48;
          else signal ('GQ004', sprintf ('Invalid octal digit in literal %s', _val));
          _acc := _acc * 8 + _digit;
          _i := _i + 1;
        }
      if (_is_neg) return -_acc;
      return _acc;
    }

  -- Binary: 0b...
  if (_i + 1 < _len and aref (_val, _i) = 48
      and (aref (_val, _i + 1) = 98 or aref (_val, _i + 1) = 66))
    {
      _i := _i + 2;
      _acc := 0;
      while (_i < _len)
        {
          _ch := aref (_val, _i);
          if (_ch = 48 or _ch = 49) _digit := _ch - 48;
          else signal ('GQ004', sprintf ('Invalid binary digit in literal %s', _val));
          _acc := _acc * 2 + _digit;
          _i := _i + 1;
        }
      if (_is_neg) return -_acc;
      return _acc;
    }

  -- Plain decimal.
  if (_is_neg) return -atoi (subseq (_val, _i, _len));
  return atoi (subseq (_val, _i, _len));
}
;

----------------------------------------------------------------------
-- OR expression
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_OR_EXPR (in _tokens any, inout _pos integer)
{
  declare lhs, rhs any;
  lhs := DB.DBA.GQL_PARSE_XOR_EXPR (_tokens, _pos);
  while (DB.DBA.GQL_PEEK (_tokens, _pos) = 233)  -- OR
    { _pos := _pos + 1; rhs := DB.DBA.GQL_PARSE_XOR_EXPR (_tokens, _pos); lhs := vector ('BINOP', 'OR', lhs, rhs); }
  return lhs;
}
;

----------------------------------------------------------------------
-- XOR expression
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_XOR_EXPR (in _tokens any, inout _pos integer)
{
  declare lhs, rhs any;
  lhs := DB.DBA.GQL_PARSE_AND_EXPR (_tokens, _pos);
  while (DB.DBA.GQL_PEEK (_tokens, _pos) = 234)  -- XOR
    { _pos := _pos + 1; rhs := DB.DBA.GQL_PARSE_AND_EXPR (_tokens, _pos); lhs := vector ('BINOP', 'XOR', lhs, rhs); }
  return lhs;
}
;

----------------------------------------------------------------------
-- AND expression
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_AND_EXPR (in _tokens any, inout _pos integer)
{
  declare lhs, rhs any;
  lhs := DB.DBA.GQL_PARSE_NOT_EXPR (_tokens, _pos);
  while (DB.DBA.GQL_PEEK (_tokens, _pos) = 232)  -- AND
    { _pos := _pos + 1; rhs := DB.DBA.GQL_PARSE_NOT_EXPR (_tokens, _pos); lhs := vector ('BINOP', 'AND', lhs, rhs); }
  return lhs;
}
;

----------------------------------------------------------------------
-- NOT expression
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_NOT_EXPR (in _tokens any, inout _pos integer)
{
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 231)  -- NOT
    { _pos := _pos + 1; return vector ('UNOP', 'NOT', DB.DBA.GQL_PARSE_NOT_EXPR (_tokens, _pos)); }
  return DB.DBA.GQL_PARSE_IMPLIES_EXPR (_tokens, _pos);
}
;

----------------------------------------------------------------------
-- IMPLIES (=>) expression (GQL-specific)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_IMPLIES_EXPR (in _tokens any, inout _pos integer)
{
  declare lhs, rhs any;
  lhs := DB.DBA.GQL_PARSE_COMPARISON (_tokens, _pos);
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 31)  -- EQGT (=>)
    { _pos := _pos + 1; rhs := DB.DBA.GQL_PARSE_IMPLIES_EXPR (_tokens, _pos); return vector ('BINOP', 'IMPLIES', lhs, rhs); }
  return lhs;
}
;

----------------------------------------------------------------------
-- Comparison expression
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_COMPARISON (in _tokens any, inout _pos integer)
{
  declare lhs, rhs, chain_head any;
  declare tt integer;
  declare op varchar;

  lhs := DB.DBA.GQL_PARSE_ADD_EXPR (_tokens, _pos);
  chain_head := null;

  while (1)
    {
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);

      -- Binary comparisons
      if (tt = 15 or tt = 16 or tt = 13 or tt = 14 or tt = 17 or tt = 18)
        {
          if (tt = 15) op := '=';
          else if (tt = 16) op := '<>';
          else if (tt = 13) op := '<';
          else if (tt = 14) op := '>';
          else if (tt = 17) op := '<=';
          else op := '>=';
          _pos := _pos + 1;
          rhs := DB.DBA.GQL_PARSE_ADD_EXPR (_tokens, _pos);
          rhs := DB.DBA.GQL_TRY_IN_EXPR (_tokens, _pos, rhs);
          rhs := DB.DBA.GQL_TRY_IS_EXPR (_tokens, _pos, rhs);
          declare cmp any;
          cmp := vector ('BINOP', op, lhs, rhs);
          declare nxt integer;
          nxt := DB.DBA.GQL_PEEK (_tokens, _pos);
          if (nxt = 15 or nxt = 16 or nxt = 13 or nxt = 14 or nxt = 17 or nxt = 18)
            {
              if (chain_head is null) chain_head := cmp;
              else chain_head := vector ('BINOP', 'AND', chain_head, cmp);
              lhs := rhs;
              goto cmp_next;
            }
          else
            {
              if (chain_head is not null) return vector ('BINOP', 'AND', chain_head, cmp);
              return cmp;
            }
        }

      -- IS (NULL, NOT NULL, label)
      if (tt = 235)
        { lhs := DB.DBA.GQL_TRY_IS_EXPR (_tokens, _pos, lhs); }
      -- IN
      else if (tt = 239)
        { lhs := DB.DBA.GQL_TRY_IN_EXPR (_tokens, _pos, lhs); }
      -- LIKE
      else if (tt = 240)
        {
          _pos := _pos + 1;
          rhs := DB.DBA.GQL_PARSE_ADD_EXPR (_tokens, _pos);
          return vector ('BINOP', 'LIKE', lhs, rhs);
        }
      -- CONTAINS: Virtuoso full text search predicate.
      else if (tt = 525)
        {
          declare opts any;
          _pos := _pos + 1;
          rhs := DB.DBA.GQL_PARSE_ADD_EXPR (_tokens, _pos);
          opts := DB.DBA.GQL_PARSE_CONTAINS_OPTIONS (_tokens, _pos);
          return vector ('CONTAINS', lhs, rhs, opts);
        }
      else
        return lhs;
    cmp_next:
      ;
    }
}
;

create procedure DB.DBA.GQL_PARSE_CONTAINS_OPTIONS (in _tokens any, inout _pos integer)
{
  declare opts any;
  declare tt integer;

  opts := vector ();
  tt := DB.DBA.GQL_PEEK (_tokens, _pos);
  if (tt <> 526 and not (tt = 64 and upper (DB.DBA.GQL_PEEK_VAL (_tokens, _pos)) = 'OPTION'))
    return opts;

  _pos := _pos + 1;  -- consume OPTION
  DB.DBA.GQL_EXPECT (_tokens, _pos, 1);  -- LPAREN
  while (DB.DBA.GQL_PEEK (_tokens, _pos) <> 2)  -- RPAREN
    {
      declare opt_name varchar;
      declare opt_val any;
      opt_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 1;
      opt_val := null;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) <> 9 and DB.DBA.GQL_PEEK (_tokens, _pos) <> 2)
        opt_val := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
      opts := vector_concat (opts, vector (vector (lower (opt_name), opt_val)));
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
        _pos := _pos + 1;
      else if (DB.DBA.GQL_PEEK (_tokens, _pos) <> 2)
        signal ('GQ003', sprintf ('Expected comma or ) in CONTAINS OPTION at position %d', _pos));
    }
  DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
  return opts;
}
;

----------------------------------------------------------------------
-- IS expression (postfix)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_TRY_IS_EXPR (in _tokens any, inout _pos integer, in _expr any)
{
  declare nxt integer;
  declare is_not integer;
  if (DB.DBA.GQL_PEEK (_tokens, _pos) <> 235)  -- IS
    return _expr;
  _pos := _pos + 1;
  is_not := 0;
  nxt := DB.DBA.GQL_PEEK (_tokens, _pos);
  if (nxt = 231)  -- NOT
    { is_not := 1; _pos := _pos + 1; nxt := DB.DBA.GQL_PEEK (_tokens, _pos); }
  if (nxt = 236)  -- NULL_KW
    { _pos := _pos + 1; return vector ('ISNULL', _expr, is_not); }
  -- IS DIRECTED
  if (nxt = 344)  -- DIRECTED
    { _pos := _pos + 1; return vector ('IS_DIRECTED', _expr, is_not); }
  -- IS TYPED <type>
  if (nxt = 474)  -- TYPED
    {
      declare type_name varchar;
      declare type_tok integer;
      _pos := _pos + 1;
      type_tok := DB.DBA.GQL_PEEK (_tokens, _pos);
      if (type_tok < 64)  -- must be IDENT or keyword, not a structural token
        signal ('GQ004', sprintf ('Expected type name after TYPED at position %d', _pos));
      type_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 1;
      return vector ('IS_TYPED', _expr, type_name, is_not);
    }
  -- IS SOURCE OF <edge>
  if (nxt = 347)  -- SOURCE
    {
      declare src_edge any;
      _pos := _pos + 1;
      DB.DBA.GQL_EXPECT (_tokens, _pos, 243);  -- OF
      src_edge := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
      return vector ('IS_SOURCE_OF', _expr, src_edge, is_not);
    }
  -- IS DESTINATION OF <edge>
  if (nxt = 348)  -- DESTINATION
    {
      declare dst_edge any;
      _pos := _pos + 1;
      DB.DBA.GQL_EXPECT (_tokens, _pos, 243);  -- OF
      dst_edge := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
      return vector ('IS_DEST_OF', _expr, dst_edge, is_not);
    }
  -- IS <label> — parse as label name
  if (nxt = 64 or nxt = 69)  -- IDENT or PNAME_NS
    { declare lbl varchar; lbl := DB.DBA.GQL_PEEK_VAL (_tokens, _pos); _pos := _pos + 1; return vector ('ISLABEL', _expr, lbl); }
  signal ('GQ004', sprintf ('Expected NULL, NOT NULL, DIRECTED, TYPED, SOURCE OF, DESTINATION OF, or label after IS at position %d', _pos));
}
;

----------------------------------------------------------------------
-- IN expression (postfix)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_TRY_IN_EXPR (in _tokens any, inout _pos integer, in _expr any)
{
  declare list_expr any;
  if (DB.DBA.GQL_PEEK (_tokens, _pos) <> 239)  -- IN
    return _expr;
  _pos := _pos + 1;
  -- IN [ list ] or IN expression
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 3)  -- LBRACKET
    list_expr := DB.DBA.GQL_PARSE_LIST_LITERAL (_tokens, _pos);
  else
    list_expr := DB.DBA.GQL_PARSE_PRIMARY (_tokens, _pos);
  return vector ('INEXPR', _expr, list_expr);
}
;

----------------------------------------------------------------------
-- Addition expression
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_ADD_EXPR (in _tokens any, inout _pos integer)
{
  declare lhs, rhs any;
  declare tt integer;
  lhs := DB.DBA.GQL_PARSE_MUL_EXPR (_tokens, _pos);
  while (1)
    {
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);
      if (tt = 19)  -- PLUS
        { _pos := _pos + 1; rhs := DB.DBA.GQL_PARSE_MUL_EXPR (_tokens, _pos); lhs := vector ('BINOP', '+', lhs, rhs); }
      else if (tt = 12)  -- DASH (minus)
        { _pos := _pos + 1; rhs := DB.DBA.GQL_PARSE_MUL_EXPR (_tokens, _pos); lhs := vector ('BINOP', '-', lhs, rhs); }
      else if (tt = 54)  -- || (concatenation)
        { _pos := _pos + 1; rhs := DB.DBA.GQL_PARSE_MUL_EXPR (_tokens, _pos); lhs := vector ('STROP', '||', lhs, rhs); }
      else
        return lhs;
    }
}
;

----------------------------------------------------------------------
-- Multiplication expression
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_MUL_EXPR (in _tokens any, inout _pos integer)
{
  declare lhs, rhs any;
  declare tt integer;
  lhs := DB.DBA.GQL_PARSE_POWER_EXPR (_tokens, _pos);
  while (1)
    {
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);
      if (tt = 20)  -- STAR
        { _pos := _pos + 1; rhs := DB.DBA.GQL_PARSE_POWER_EXPR (_tokens, _pos); lhs := vector ('BINOP', '*', lhs, rhs); }
      else if (tt = 21)  -- SLASH
        { _pos := _pos + 1; rhs := DB.DBA.GQL_PARSE_POWER_EXPR (_tokens, _pos); lhs := vector ('BINOP', '/', lhs, rhs); }
      else if (tt = 22)  -- PERCENT
        { _pos := _pos + 1; rhs := DB.DBA.GQL_PARSE_POWER_EXPR (_tokens, _pos); lhs := vector ('BINOP', '%', lhs, rhs); }
      else
        return lhs;
    }
}
;

----------------------------------------------------------------------
-- Power expression (right-associative)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_POWER_EXPR (in _tokens any, inout _pos integer)
{
  declare lhs, rhs any;
  lhs := DB.DBA.GQL_PARSE_UNARY_EXPR (_tokens, _pos);
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 23)  -- CARET
    { _pos := _pos + 1; rhs := DB.DBA.GQL_PARSE_POWER_EXPR (_tokens, _pos); lhs := vector ('BINOP', '^', lhs, rhs); }
  return lhs;
}
;

----------------------------------------------------------------------
-- Unary expression
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_UNARY_EXPR (in _tokens any, inout _pos integer)
{
  declare tt integer;
  tt := DB.DBA.GQL_PEEK (_tokens, _pos);
  if (tt = 19)  -- PLUS
    { _pos := _pos + 1; return vector ('UNOP', '+', DB.DBA.GQL_PARSE_UNARY_EXPR (_tokens, _pos)); }
  if (tt = 12)  -- DASH (minus)
    { _pos := _pos + 1; return vector ('UNOP', '-', DB.DBA.GQL_PARSE_UNARY_EXPR (_tokens, _pos)); }
  if (tt = 231)  -- NOT
    { _pos := _pos + 1; return vector ('UNOP', 'NOT', DB.DBA.GQL_PARSE_UNARY_EXPR (_tokens, _pos)); }
  return DB.DBA.GQL_PARSE_POSTFIX_EXPR (_tokens, _pos);
}
;

----------------------------------------------------------------------
-- Postfix expression (property access, subscript, label test)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_POSTFIX_EXPR (in _tokens any, inout _pos integer)
{
  declare expr, idx_expr, start_expr, end_expr any;
  declare tt integer;
  declare prop_name varchar;

  expr := DB.DBA.GQL_PARSE_PRIMARY (_tokens, _pos);

  while (1)
    {
      tt := DB.DBA.GQL_PEEK (_tokens, _pos);

      -- Property access: expr.name or expr.:name (default-prefix)
      if (tt = 8)  -- DOT
        {
          _pos := _pos + 1;
          tt := DB.DBA.GQL_PEEK (_tokens, _pos);
          if (tt = 7)  -- COLON — default-prefix property
            {
              _pos := _pos + 1;
              if (DB.DBA.GQL_PEEK (_tokens, _pos) <> 64)
                signal ('GQ004', 'Expected property name after default prefix');
              prop_name := concat (':', DB.DBA.GQL_PEEK_VAL (_tokens, _pos));
              _pos := _pos + 1;
              expr := vector ('PROP', expr, prop_name);
              goto postfix_next;
            }
          if (tt <> 64 and tt <> 69 and tt <> 70)  -- IDENT, PNAME_NS, IRIREF
            signal ('GQ004', sprintf ('Expected property name after dot at position %d', _pos));
          prop_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 1;
          -- Function call via dotted name? (rare in GQL but supported)
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 1)  -- LPAREN
            {
              declare func_name varchar;
              func_name := prop_name;
              expr := DB.DBA.GQL_PARSE_FUNC_CALL (_tokens, _pos, func_name);
              goto postfix_next;
            }
          expr := vector ('PROP', expr, prop_name);
        }
      -- Subscript: expr[idx] or expr[start..end]
      else if (tt = 3)  -- LBRACKET
        {
          _pos := _pos + 1;
          start_expr := null;
          end_expr := null;
          if (DB.DBA.GQL_PEEK (_tokens, _pos) <> 26 and DB.DBA.GQL_PEEK (_tokens, _pos) <> 4)  -- not .. or ]
            start_expr := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 26)  -- DOTDOT
            {
              _pos := _pos + 1;
              if (DB.DBA.GQL_PEEK (_tokens, _pos) <> 4)
                end_expr := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
              DB.DBA.GQL_EXPECT (_tokens, _pos, 4);  -- RBRACKET
              expr := vector ('SLICE', expr, start_expr, end_expr);
            }
          else
            {
              idx_expr := start_expr;
              DB.DBA.GQL_EXPECT (_tokens, _pos, 4);  -- RBRACKET
              expr := vector ('BINOP', '[]', expr, idx_expr);
            }
        }
      -- Label test: expr:Label
      else if (tt = 7)  -- COLON
        {
          _pos := _pos + 1;
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 64 or DB.DBA.GQL_PEEK (_tokens, _pos) = 69)
            { prop_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos); _pos := _pos + 1; expr := vector ('ISLABEL', expr, prop_name); }
          else
            signal ('GQ004', 'Expected label name after colon');
        }
      else
        goto postfix_done;

    postfix_next:
      ;
    }
  postfix_done:
  return expr;
}
;

----------------------------------------------------------------------
-- Primary expression
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_PRIMARY (in _tokens any, inout _pos integer)
{
  declare tt integer;
  declare val, fname varchar;
  declare expr, sub_expr any;

  tt := DB.DBA.GQL_PEEK (_tokens, _pos);
  val := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);

  -- Parenthesized expression or pattern predicate
  if (tt = 1)  -- LPAREN
    {
      if (DB.DBA.GQL_EXPR_STARTS_PATTERN (_tokens, _pos))
        return vector ('PATTERNPRED', DB.DBA.GQL_PARSE_PATTERN (_tokens, _pos));
      _pos := _pos + 1;
      expr := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
      DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
      return expr;
    }

  -- List literal
  if (tt = 3)  -- LBRACKET
    return DB.DBA.GQL_PARSE_LIST_LITERAL (_tokens, _pos);

  -- Map literal or record literal (via <{...}>)
  if (tt = 5)  -- LBRACE
    return DB.DBA.GQL_PARSE_MAP_LITERAL (_tokens, _pos);

  -- Record literal: <{...}>
  if (tt = 13 and _pos + 1 < length (_tokens) and DB.DBA.GQL_PEEK (_tokens, _pos + 1) = 5)  -- LT LBRACE
    {
      _pos := _pos + 2;  -- consume <{
      declare rkeys, rvals any;
      DB.DBA.GQL_PARSE_MAP_ENTRIES (_tokens, _pos, rkeys, rvals);
      DB.DBA.GQL_EXPECT (_tokens, _pos, 14);  -- GT
      return vector ('RECORD', rkeys, rvals);
    }

  -- String literals
  if (tt = 65 or tt = 72)  -- STRING or DQ_STRING
    {
      _pos := _pos + 1;
      -- Language tag?
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 73)  -- LANGTAG
        { declare lang varchar; lang := DB.DBA.GQL_PEEK_VAL (_tokens, _pos); _pos := _pos + 1; return vector ('LANGLIT', val, lang); }
      return vector ('LIT', val);
    }

  -- IRIREF
  if (tt = 70)  -- IRIREF
    { _pos := _pos + 1; return vector ('IRI', val); }

  -- Default-prefixed IRI, e.g. :knows
  if (tt = 7)  -- COLON
    {
      _pos := _pos + 1;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) <> 64)
        signal ('GQ004', 'Expected local name after default prefix');
      val := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 1;
      return vector ('IRI', concat (':', val));
    }

  -- Integer literal
  if (tt = 66)  -- INTEGER
    { _pos := _pos + 1; return vector ('LIT', DB.DBA.GQL_PARSE_INT_LITERAL (val)); }

  -- Float literal
  if (tt = 67)  -- FLOAT
    { _pos := _pos + 1; return vector ('FLOAT', val); }

  -- Booleans
  if (tt = 237)  -- TRUE
    { _pos := _pos + 1; return vector ('LIT_BOOL', 1); }
  if (tt = 238)  -- FALSE
    { _pos := _pos + 1; return vector ('LIT_BOOL', 0); }
  if (tt = 236)  -- NULL_KW
    { _pos := _pos + 1; return vector ('LIT', null); }

  -- Aggregate functions.  COUNT(*) is represented explicitly; the other
  -- aggregate forms parse as normal function calls.
  if (tt = 261)  -- COUNT
    {
      if (_pos + 2 < length (_tokens)
          and DB.DBA.GQL_PEEK (_tokens, _pos + 1) = 1  -- LPAREN
          and DB.DBA.GQL_PEEK (_tokens, _pos + 2) = 20) -- STAR
        { _pos := _pos + 3; DB.DBA.GQL_EXPECT (_tokens, _pos, 2); return vector ('COUNTSTAR'); }
      _pos := _pos + 1;
      return DB.DBA.GQL_PARSE_FUNC_CALL (_tokens, _pos, val);
    }

  if (tt = 403 or tt = 404 or tt = 405 or tt = 406)  -- MAX/MIN/AVG/SUM
    {
      _pos := _pos + 1;
      return DB.DBA.GQL_PARSE_FUNC_CALL (_tokens, _pos, val);
    }

  -- STDDEV_POP/STDDEV_SAMP/COLLECT_LIST/PERCENTILE_CONT/PERCENTILE_DISC
  if (tt = 407 or tt = 408 or tt = 409 or tt = 410 or tt = 411)
    {
      _pos := _pos + 1;
      return DB.DBA.GQL_PARSE_FUNC_CALL (_tokens, _pos, val);
    }

  -- Numeric keyword functions: SQRT, EXP, LOG, LN, POWER, MOD, SIN, COS, TAN, COT,
  -- ASIN, ACOS, ATAN, DEGREES, RADIANS, CEILING, ABS, FLOOR, ROUND, LOG10
  if (tt = 369 or tt = 370 or tt = 371 or tt = 372 or tt = 373 or tt = 374
      or tt = 375 or tt = 376 or tt = 377 or tt = 378 or tt = 379 or tt = 380
      or tt = 381 or tt = 382 or tt = 383 or tt = 387 or tt = 388 or tt = 389 or tt = 390
      or tt = 518)
    {
      _pos := _pos + 1;
      return DB.DBA.GQL_PARSE_FUNC_CALL (_tokens, _pos, val);
    }

  -- String keyword functions: TRIM, BTRIM, LTRIM, RTRIM, SUBSTRING, UPPER, LOWER,
  -- LEFT, RIGHT, CHAR_LENGTH, CHARACTER_LENGTH, BYTE_LENGTH, OCTET_LENGTH
  if (tt = 361 or tt = 362 or tt = 363 or tt = 364 or tt = 365 or tt = 367 or tt = 368
      or tt = 493 or tt = 494 or tt = 391 or tt = 392 or tt = 393 or tt = 394)
    {
      _pos := _pos + 1;
      return DB.DBA.GQL_PARSE_FUNC_CALL (_tokens, _pos, val);
    }

  -- List/cardinality functions: SIZE, CARDINALITY
  if (tt = 395 or tt = 413)
    {
      _pos := _pos + 1;
      return DB.DBA.GQL_PARSE_FUNC_CALL (_tokens, _pos, val);
    }

  -- Conditional functions: COALESCE, NULLIF, IFNULL, GREATEST, LEAST
  if (tt = 397 or tt = 398 or tt = 399 or tt = 400 or tt = 401)
    {
      _pos := _pos + 1;
      return DB.DBA.GQL_PARSE_FUNC_CALL (_tokens, _pos, val);
    }

  -- Datetime functions: CURRENT_DATE, CURRENT_TIME, CURRENT_TIMESTAMP
  if (tt = 520 or tt = 521 or tt = 522)
    {
      _pos := _pos + 1;
      -- These may be called with no args: CURRENT_DATE or CURRENT_DATE()
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 1)  -- LPAREN
        return DB.DBA.GQL_PARSE_FUNC_CALL (_tokens, _pos, val);
      return vector ('FUNC', val, 0, vector ());
    }

  -- LOCAL_TIME, LOCAL_TIMESTAMP (no-arg datetime functions)
  if (tt = 307 or tt = 309)
    {
      _pos := _pos + 1;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 1)  -- LPAREN
        return DB.DBA.GQL_PARSE_FUNC_CALL (_tokens, _pos, val);
      return vector ('FUNC', val, 0, vector ());
    }

  -- CASE
  if (tt = 256)  -- CASE
    return DB.DBA.GQL_PARSE_CASE (_tokens, _pos);

  -- ALL_DIFFERENT (var1, var2, ...)
  if (tt = 449)  -- ALL_DIFFERENT
    {
      declare ad_args any;
      _pos := _pos + 1;
      DB.DBA.GQL_EXPECT (_tokens, _pos, 1);  -- LPAREN
      ad_args := vector ();
      while (1)
        {
          ad_args := vector_concat (ad_args, vector (DB.DBA.GQL_PARSE_EXPR (_tokens, _pos)));
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
            _pos := _pos + 1;
          else
            goto ad_done;
        }
      ad_done:
      DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
      return vector ('ALL_DIFFERENT', ad_args);
    }

  -- SAME (var1, var2, ...)
  if (tt = 277)  -- SAME
    {
      declare sm_args any;
      _pos := _pos + 1;
      DB.DBA.GQL_EXPECT (_tokens, _pos, 1);  -- LPAREN
      sm_args := vector ();
      while (1)
        {
          sm_args := vector_concat (sm_args, vector (DB.DBA.GQL_PARSE_EXPR (_tokens, _pos)));
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
            _pos := _pos + 1;
          else
            goto sm_done;
        }
      sm_done:
      DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
      return vector ('SAME_PRED', sm_args);
    }

  -- PROPERTY_EXISTS (var, .propertyName)
  if (tt = 276)  -- PROPERTY_EXISTS
    {
      declare pe_var, pe_prop any;
      _pos := _pos + 1;
      DB.DBA.GQL_EXPECT (_tokens, _pos, 1);  -- LPAREN
      pe_var := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
      DB.DBA.GQL_EXPECT (_tokens, _pos, 9);  -- COMMA
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 8)  -- DOT
        _pos := _pos + 1;
      pe_prop := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 1;
      DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
      return vector ('PROP_EXISTS', pe_var, pe_prop);
    }

  -- ELEMENT_ID (var)
  if (tt = 351)  -- ELEMENT_ID
    {
      declare ei_var any;
      _pos := _pos + 1;
      DB.DBA.GQL_EXPECT (_tokens, _pos, 1);  -- LPAREN
      ei_var := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
      DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
      return vector ('FUNC', 'element_id', 0, vector (ei_var));
    }

  -- EXISTS
  if (tt = 230)  -- EXISTS
    {
      _pos := _pos + 1;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 1)  -- LPAREN
        {
          _pos := _pos + 1;
          sub_expr := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
          DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
          return vector ('FUNC', 'exists', 0, vector (sub_expr));
        }
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 5)  -- LBRACE — existential subquery
        return DB.DBA.GQL_PARSE_EXISTS_SUBQUERY (_tokens, _pos);
      signal ('GQ004', sprintf ('Expected ( or { after EXISTS at position %d', _pos));
    }

  -- Typed literals: DATE '...', TIMESTAMP '...', TIME '...', DATETIME '...'
  if (tt = 313 or tt = 321 or tt = 302 or tt = 305)  -- DATE, TIMESTAMP, TIME, DATETIME
    {
      declare tlit_type varchar;
      tlit_type := val;
      _pos := _pos + 1;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 65 or DB.DBA.GQL_PEEK (_tokens, _pos) = 72)  -- STRING or DQ_STRING
        { val := DB.DBA.GQL_PEEK_VAL (_tokens, _pos); _pos := _pos + 1; return vector ('TYPEDLIT', tlit_type, val); }
      signal ('GQ004', sprintf ('Expected string literal after %s at position %d', tlit_type, _pos));
    }

  -- Quoted identifier used as variable
  if (tt = 71)  -- ACCENT_IDENT
    { _pos := _pos + 1; return vector ('VAR', val); }

  -- Variable / function call
  if (tt = 64)  -- IDENT
    {
      _pos := _pos + 1;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 1)  -- LPAREN — function call
        return DB.DBA.GQL_PARSE_FUNC_CALL (_tokens, _pos, val);
      return vector ('VAR', val);
    }

  -- Parameter
  if (tt = 68)  -- PARAM
    { _pos := _pos + 1; return vector ('PARAM', val); }

  -- PNAME_NS — either a function call (prefix:name(...)) or a prefixed IRI
  if (tt = 69)  -- PNAME_NS
    {
      _pos := _pos + 1;
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 1)  -- LPAREN — function call
        return DB.DBA.GQL_PARSE_FUNC_CALL (_tokens, _pos, val);
      return vector ('IRI', val);
    }

  signal ('GQ004', sprintf ('Unexpected token type %d at position %d in expression', tt, _pos));
}
;

----------------------------------------------------------------------
-- Pattern detection for parenthesized expressions
----------------------------------------------------------------------

create procedure DB.DBA.GQL_EXPR_STARTS_PATTERN (in _tokens any, in _pos integer)
{
  if (DB.DBA.GQL_PEEK (_tokens, _pos) <> 1)  -- must start with LPAREN
    return 0;
  -- ( :Label ... ) is a pattern
  if (DB.DBA.GQL_PEEK (_tokens, _pos + 1) = 7)  -- COLON
    return 1;
  -- ( var ) with no following op is a pattern predicate
  if (DB.DBA.GQL_PEEK (_tokens, _pos + 1) = 64
      and DB.DBA.GQL_PEEK (_tokens, _pos + 2) = 2)  -- IDENT RPAREN
    return 1;
  return 0;
}
;

----------------------------------------------------------------------
-- List literal: [elem, ...]
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_LIST_LITERAL (in _tokens any, inout _pos integer)
{
  declare elements, elem any;

  DB.DBA.GQL_EXPECT (_tokens, _pos, 3);  -- LBRACKET
  elements := vector ();

  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 4)  -- empty []
    { _pos := _pos + 1; return vector ('LIST', elements); }

  while (1)
    {
      elem := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
      elements := vector_concat (elements, vector (elem));
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
        _pos := _pos + 1;
      else
        goto list_done;
    }
  list_done:
  DB.DBA.GQL_EXPECT (_tokens, _pos, 4);  -- RBRACKET
  return vector ('LIST', elements);
}
;

----------------------------------------------------------------------
-- Map literal: { key: val, ... }
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_MAP_LITERAL (in _tokens any, inout _pos integer)
{
  declare keys, vals any;
  DB.DBA.GQL_PARSE_MAP_ENTRIES (_tokens, _pos, keys, vals);
  return vector ('MAP', keys, vals);
}
;

create procedure DB.DBA.GQL_PARSE_MAP_ENTRIES (in _tokens any, inout _pos integer, inout _keys any, inout _vals any)
{
  declare key_name varchar;
  declare val any;

  DB.DBA.GQL_EXPECT (_tokens, _pos, 5);  -- LBRACE
  _keys := vector ();
  _vals := vector ();

  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 6)  -- empty {}
    { _pos := _pos + 1; return; }

  while (1)
    {
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 7)  -- default-prefixed key
        {
          _pos := _pos + 1;
          key_name := concat (':', DB.DBA.GQL_PEEK_VAL (_tokens, _pos));
        }
      else
        key_name := DB.DBA.GQL_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 1;  -- consume key
      DB.DBA.GQL_EXPECT (_tokens, _pos, 7);  -- COLON
      val := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
      _keys := vector_concat (_keys, vector (key_name));
      _vals := vector_concat (_vals, vector (val));
      if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
        _pos := _pos + 1;
      else
        goto map_done;
    }
  map_done:
  DB.DBA.GQL_EXPECT (_tokens, _pos, 6);  -- RBRACE
}
;

----------------------------------------------------------------------
-- Function call
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_FUNC_CALL (in _tokens any, inout _pos integer, in _fname varchar)
{
  declare args any;
  declare is_distinct integer;

  DB.DBA.GQL_EXPECT (_tokens, _pos, 1);  -- LPAREN
  is_distinct := 0;

  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 222)  -- DISTINCT
    { _pos := _pos + 1; is_distinct := 1; }

  args := vector ();
  if (DB.DBA.GQL_PEEK (_tokens, _pos) <> 2)  -- not RPAREN
    {
      while (1)
        {
          args := vector_concat (args, vector (DB.DBA.GQL_PARSE_EXPR (_tokens, _pos)));
          if (DB.DBA.GQL_PEEK (_tokens, _pos) = 9)  -- COMMA
            _pos := _pos + 1;
          else
            goto args_done;
        }
    }
  args_done:
  DB.DBA.GQL_EXPECT (_tokens, _pos, 2);  -- RPAREN
  if (is_distinct)
    return vector ('FUNC_DISTINCT', _fname, args);
  return vector ('FUNC', _fname, 0, args);
}
;

----------------------------------------------------------------------
-- CASE expression
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_CASE (in _tokens any, inout _pos integer)
{
  declare operand, whens, else_expr, when_pair any;
  declare tt integer;

  _pos := _pos + 1;  -- consume CASE
  operand := null;

  -- CASE operand WHEN ... or CASE WHEN ...
  tt := DB.DBA.GQL_PEEK (_tokens, _pos);
  if (tt <> 257)  -- not WHEN
    { operand := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos); }

  whens := vector ();
  while (DB.DBA.GQL_PEEK (_tokens, _pos) = 257)  -- WHEN
    {
      declare cond, result any;
      _pos := _pos + 1;
      cond := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
      DB.DBA.GQL_EXPECT (_tokens, _pos, 258);  -- THEN
      result := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos);
      whens := vector_concat (whens, vector (vector (cond, result)));
    }

  else_expr := null;
  if (DB.DBA.GQL_PEEK (_tokens, _pos) = 259)  -- ELSE
    { _pos := _pos + 1; else_expr := DB.DBA.GQL_PARSE_EXPR (_tokens, _pos); }

  DB.DBA.GQL_EXPECT (_tokens, _pos, 260);  -- END
  return vector ('CASEEXPR', operand, whens, else_expr);
}
;

----------------------------------------------------------------------
-- EXISTS subquery
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PARSE_EXISTS_SUBQUERY (in _tokens any, inout _pos integer)
{
  declare clauses any;

  DB.DBA.GQL_EXPECT (_tokens, _pos, 5);  -- LBRACE
  clauses := DB.DBA.GQL_PARSE_COMPOSITE_QUERY (_tokens, _pos);
  DB.DBA.GQL_EXPECT (_tokens, _pos, 6);  -- RBRACE
  return vector ('EXISTS_SUBQUERY', clauses);
}
;

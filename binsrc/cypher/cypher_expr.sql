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
--  openCypher: OpenCypher for Virtuoso - Expression Parser
--
--  Recursive descent expression parser with operator precedence.
--  Precedence (lowest to highest):
--    OR, XOR, AND, NOT, comparison, addition, multiplication, unary, power, postfix, primary
--
--  NOTE: 'left'/'right' are reserved SQL keywords in Virtuoso; use lhs/rhs.
--  NOTE: All 'declare' must be at top of procedure body in Virtuoso/PL.
--

-- Parse expression (entry point for all expressions)
create procedure DB.DBA.CYP_PARSE_EXPR (in _tokens any, inout _pos integer)
{
  return DB.DBA.CYP_PARSE_OR_EXPR (_tokens, _pos);
}
;

-- Decode an integer literal lexeme covering decimal, hex (0x...), and
-- octal (leading-zero) forms.  The lexer hands us the raw source text,
-- so the conversion lives here next to the AST construction.
create procedure DB.DBA.CYP_PARSE_INT_LITERAL (in _val varchar)
  returns integer
{
  declare _len, _i, _ch, _digit, _acc integer;
  declare _is_neg integer;

  _len := length (_val);
  _i := 0;
  _is_neg := 0;
  if (_len > 0 and aref (_val, 0) = 45)  -- '-'
    { _is_neg := 1; _i := 1; }
  else if (_len > 0 and aref (_val, 0) = 43)  -- '+'
    { _i := 1; }

  -- Hex: 0x... / 0X...
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
          else
            signal ('CY001', sprintf ('Invalid hex digit ''%s'' in literal %s', chr (_ch), _val));
          _acc := _acc * 16 + _digit;
          _i := _i + 1;
        }
      if (_is_neg) return -_acc;
      return _acc;
    }

  -- Octal explicit prefix: 0o... / 0O...
  if (_i + 1 < _len and aref (_val, _i) = 48
      and (aref (_val, _i + 1) = 111 or aref (_val, _i + 1) = 79))
    {
      _i := _i + 2;
      _acc := 0;
      while (_i < _len)
        {
          _ch := aref (_val, _i);
          if (_ch >= 48 and _ch <= 55) _digit := _ch - 48;
          else
            signal ('CY001', sprintf ('Invalid octal digit ''%s'' in literal %s', chr (_ch), _val));
          _acc := _acc * 8 + _digit;
          _i := _i + 1;
        }
      if (_is_neg) return -_acc;
      return _acc;
    }

  -- Octal: leading 0 followed by another digit (0177 -> 127).  Bare 0
  -- and floats are handled by the lexer before reaching this branch.
  if (_i + 1 < _len and aref (_val, _i) = 48
      and aref (_val, _i + 1) >= 48 and aref (_val, _i + 1) <= 55)
    {
      _i := _i + 1;
      _acc := 0;
      while (_i < _len)
        {
          _ch := aref (_val, _i);
          if (_ch < 48 or _ch > 55)
            signal ('CY001', sprintf ('Invalid octal digit ''%s'' in literal %s', chr (_ch), _val));
          _acc := _acc * 8 + (_ch - 48);
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

-- OR expression
create procedure DB.DBA.CYP_PARSE_OR_EXPR (in _tokens any, inout _pos integer)
{
  declare lhs, rhs any;
  lhs := DB.DBA.CYP_PARSE_XOR_EXPR (_tokens, _pos);
  while (DB.DBA.CYP_PEEK (_tokens, _pos) = 123)
    {
      _pos := _pos + 1;
      rhs := DB.DBA.CYP_PARSE_XOR_EXPR (_tokens, _pos);
      lhs := vector ('BINOP', 'OR', lhs, rhs);
    }
  return lhs;
}
;

-- XOR expression
create procedure DB.DBA.CYP_PARSE_XOR_EXPR (in _tokens any, inout _pos integer)
{
  declare lhs, rhs any;
  lhs := DB.DBA.CYP_PARSE_AND_EXPR (_tokens, _pos);
  while (DB.DBA.CYP_PEEK (_tokens, _pos) = 125)
    {
      _pos := _pos + 1;
      rhs := DB.DBA.CYP_PARSE_AND_EXPR (_tokens, _pos);
      lhs := vector ('BINOP', 'XOR', lhs, rhs);
    }
  return lhs;
}
;

-- AND expression
create procedure DB.DBA.CYP_PARSE_AND_EXPR (in _tokens any, inout _pos integer)
{
  declare lhs, rhs any;
  lhs := DB.DBA.CYP_PARSE_NOT_EXPR (_tokens, _pos);
  while (DB.DBA.CYP_PEEK (_tokens, _pos) = 122)
    {
      _pos := _pos + 1;
      rhs := DB.DBA.CYP_PARSE_NOT_EXPR (_tokens, _pos);
      lhs := vector ('BINOP', 'AND', lhs, rhs);
    }
  return lhs;
}
;

-- NOT expression
create procedure DB.DBA.CYP_PARSE_NOT_EXPR (in _tokens any, inout _pos integer)
{
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 124)
    {
      _pos := _pos + 1;
      return vector ('UNOP', 'NOT', DB.DBA.CYP_PARSE_NOT_EXPR (_tokens, _pos));
    }
  return DB.DBA.CYP_PARSE_COMPARISON (_tokens, _pos);
}
;

-- Comparison expression
create procedure DB.DBA.CYP_PARSE_COMPARISON (in _tokens any, inout _pos integer)
{
  declare lhs, rhs, chain_head any;
  declare tt, nxt integer;
  declare op varchar;
  declare cmp any;
  lhs := DB.DBA.CYP_PARSE_ADD_EXPR (_tokens, _pos);
  chain_head := null;
  while (1)
    {
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);

      if (tt = 15 or tt = 16 or tt = 13 or tt = 14 or tt = 17 or tt = 18)
        {
          if (tt = 15) op := '=';
          else if (tt = 16) op := '<>';
          else if (tt = 13) op := '<';
          else if (tt = 14) op := '>';
          else if (tt = 17) op := '<=';
          else op := '>=';
          _pos := _pos + 1;
          rhs := DB.DBA.CYP_PARSE_ADD_EXPR (_tokens, _pos);
          rhs := DB.DBA.CYP_TRY_IN_EXPR (_tokens, _pos, rhs);
          rhs := DB.DBA.CYP_TRY_IS_EXPR (_tokens, _pos, rhs);
          cmp := vector ('BINOP', op, lhs, rhs);
          nxt := DB.DBA.CYP_PEEK (_tokens, _pos);
          if (nxt = 15 or nxt = 16 or nxt = 13 or nxt = 14 or nxt = 17 or nxt = 18)
            {
              if (chain_head is null)
                chain_head := cmp;
              else
                chain_head := vector ('BINOP', 'AND', chain_head, cmp);
              lhs := rhs;
              goto cmp_next;
            }
          else
            {
              if (chain_head is not null)
                return vector ('BINOP', 'AND', chain_head, cmp);
              return cmp;
            }
        }

      if (tt = 127)
        {
          lhs := DB.DBA.CYP_TRY_IS_EXPR (_tokens, _pos, lhs);
        }
      else if (tt = 126)
        {
          lhs := DB.DBA.CYP_TRY_IN_EXPR (_tokens, _pos, lhs);
        }
      else if (tt = 7)
        {
          declare lblexpr any;
          _pos := _pos + 1;
          lblexpr := DB.DBA.CYP_PARSE_LBL_OR (_tokens, _pos);
          lhs := vector ('ISLABEL', lhs, lblexpr);
        }
      else if (tt = 131)
        {
          _pos := _pos + 1;
          DB.DBA.CYP_EXPECT (_tokens, _pos, 110);
          rhs := DB.DBA.CYP_PARSE_ADD_EXPR (_tokens, _pos);
          return vector ('STROP', 'STARTS WITH', lhs, rhs);
        }
      else if (tt = 132)
        {
          _pos := _pos + 1;
          DB.DBA.CYP_EXPECT (_tokens, _pos, 110);
          rhs := DB.DBA.CYP_PARSE_ADD_EXPR (_tokens, _pos);
          return vector ('STROP', 'ENDS WITH', lhs, rhs);
        }
      else if (tt = 133)
        {
          _pos := _pos + 1;
          rhs := DB.DBA.CYP_PARSE_ADD_EXPR (_tokens, _pos);
          return vector ('STROP', 'CONTAINS', lhs, rhs);
        }
      else
        return lhs;
    cmp_next:
      ;
    }
}
;

-- Try to parse an IS NULL / IS NOT NULL / IS <label> suffix on an expression.
-- Returns the wrapped expression if IS is found, otherwise the original expression.
create procedure DB.DBA.CYP_TRY_IS_EXPR (in _tokens any, inout _pos integer, in _expr any)
{
  declare nxt integer;
  declare lblexpr any;
  if (DB.DBA.CYP_PEEK (_tokens, _pos) <> 127)
    return _expr;
  _pos := _pos + 1;
  nxt := DB.DBA.CYP_PEEK (_tokens, _pos);
  if (nxt = 124)
    {
      _pos := _pos + 1;
      DB.DBA.CYP_EXPECT (_tokens, _pos, 128);
      return vector ('ISNULL', _expr, 1);
    }
  if (nxt = 128)
    {
      _pos := _pos + 1;
      return vector ('ISNULL', _expr, 0);
    }
  lblexpr := DB.DBA.CYP_PARSE_LBL_OR (_tokens, _pos);
  return vector ('ISLABEL', _expr, lblexpr);
}
;

-- Try to parse an IN suffix on an expression.
-- Returns the wrapped expression if IN is found, otherwise the original expression.
create procedure DB.DBA.CYP_TRY_IN_EXPR (in _tokens any, inout _pos integer, in _expr any)
{
  declare rhs any;
  if (DB.DBA.CYP_PEEK (_tokens, _pos) <> 126)
    return _expr;
  _pos := _pos + 1;
  rhs := DB.DBA.CYP_PARSE_ADD_EXPR (_tokens, _pos);
  return vector ('INEXPR', _expr, rhs);
}
;

-- Addition/subtraction expression
create procedure DB.DBA.CYP_PARSE_ADD_EXPR (in _tokens any, inout _pos integer)
{
  declare lhs, rhs any;
  declare tt integer;
  declare op varchar;
  lhs := DB.DBA.CYP_PARSE_MUL_EXPR (_tokens, _pos);
  tt := DB.DBA.CYP_PEEK (_tokens, _pos);
  while (tt = 19 or tt = 12)
    {
      if (tt = 19) op := '+'; else op := '-';
      _pos := _pos + 1;
      rhs := DB.DBA.CYP_PARSE_MUL_EXPR (_tokens, _pos);
      lhs := vector ('BINOP', op, lhs, rhs);
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);
    }
  return lhs;
}
;

-- Multiplication/division/modulo expression
create procedure DB.DBA.CYP_PARSE_MUL_EXPR (in _tokens any, inout _pos integer)
{
  declare lhs, rhs any;
  declare tt integer;
  declare op varchar;
  lhs := DB.DBA.CYP_PARSE_POWER_EXPR (_tokens, _pos);
  tt := DB.DBA.CYP_PEEK (_tokens, _pos);
  while (tt = 20 or tt = 21 or tt = 22)
    {
      if (tt = 20) op := '*'; else if (tt = 21) op := '/'; else op := '%';
      _pos := _pos + 1;
      rhs := DB.DBA.CYP_PARSE_POWER_EXPR (_tokens, _pos);
      lhs := vector ('BINOP', op, lhs, rhs);
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);
    }
  return lhs;
}
;

-- Power expression (^)
create procedure DB.DBA.CYP_PARSE_POWER_EXPR (in _tokens any, inout _pos integer)
{
  declare lhs, rhs any;
  lhs := DB.DBA.CYP_PARSE_UNARY_EXPR (_tokens, _pos);
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 23)
    {
      _pos := _pos + 1;
      rhs := DB.DBA.CYP_PARSE_POWER_EXPR (_tokens, _pos);
      return vector ('BINOP', '^', lhs, rhs);
    }
  return lhs;
}
;

-- Unary expression (-, +)
create procedure DB.DBA.CYP_PARSE_UNARY_EXPR (in _tokens any, inout _pos integer)
{
  declare tt integer;
  tt := DB.DBA.CYP_PEEK (_tokens, _pos);
  if (tt = 12)
    {
      _pos := _pos + 1;
      return vector ('UNOP', '-', DB.DBA.CYP_PARSE_POSTFIX_EXPR (_tokens, _pos));
    }
  if (tt = 19)
    {
      _pos := _pos + 1;
      return DB.DBA.CYP_PARSE_POSTFIX_EXPR (_tokens, _pos);
    }
  return DB.DBA.CYP_PARSE_POSTFIX_EXPR (_tokens, _pos);
}
;

-- Parse map projection items after `expr {`
-- Items: `.prop`, `alias: expr`, `*` (all properties)
-- Returns vector of items: vector('PROP', name) | vector('ALIAS', name, expr) | vector('STAR')
create procedure DB.DBA.CYP_PARSE_MAP_PROJ_ITEMS (in _tokens any, inout _pos integer)
{
  declare items any;
  declare tt integer;
  declare name varchar;
  declare val any;
  items := vector ();

  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 6)
    {
      _pos := _pos + 1;
      return items;
    }

  while (1)
    {
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);
      if (tt = 8)
        {
          _pos := _pos + 1;
          tt := DB.DBA.CYP_PEEK (_tokens, _pos);
          if (tt <> 50 and not DB.DBA.CYP_IS_NON_RESERVED_KW (tt))
            signal ('CY010', sprintf ('Expected property name after . in map projection at position %d', _pos));
          name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 1;
          items := vector_concat (items, vector (vector ('PROP', name)));
        }
      else if (tt = 20)
        {
          _pos := _pos + 1;
          items := vector_concat (items, vector (vector ('STAR')));
        }
      else if (tt = 50 or DB.DBA.CYP_IS_NON_RESERVED_KW (tt))
        {
          name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 1;
          DB.DBA.CYP_EXPECT (_tokens, _pos, 7);
          val := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
          items := vector_concat (items, vector (vector ('ALIAS', name, val)));
        }
      else
        signal ('CY010', sprintf ('Expected map projection item at position %d', _pos));

      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 9)
        _pos := _pos + 1;
      else
        goto projdone;
    }
  projdone:
  DB.DBA.CYP_EXPECT (_tokens, _pos, 6);
  return items;
}
;

-- Postfix expression (property access .prop, subscript [idx], map projection {.prop})
create procedure DB.DBA.CYP_DOTTED_FUNC_BASE_NAME (in _expr any)
{
  declare etype varchar;
  declare base varchar;

  if (not isarray (_expr) or length (_expr) = 0)
    return null;

  etype := aref (_expr, 0);
  if (etype = 'VAR')
    return aref (_expr, 1);

  if (etype = 'PROP')
    {
      base := DB.DBA.CYP_DOTTED_FUNC_BASE_NAME (aref (_expr, 1));
      if (base is null)
        return null;
      return concat (base, '.', aref (_expr, 2));
    }

  return null;
}
;

create procedure DB.DBA.CYP_PARSE_POSTFIX_EXPR (in _tokens any, inout _pos integer)
{
  declare expr, idx_expr, start_expr, end_expr, proj_items any;
  declare tt integer;
  declare prop_name, func_base varchar;
  expr := DB.DBA.CYP_PARSE_PRIMARY (_tokens, _pos);

  while (1)
    {
      tt := DB.DBA.CYP_PEEK (_tokens, _pos);
      if (tt = 5)
        {
          -- Disambiguate map projection from a clause-opening `{` (e.g. GRAPH <iri> { MATCH ... }).
          -- Projection items begin with `.`, `*`, `}`, or `IDENT :` (alias). Otherwise leave the
          -- `{` for the clause/block parser.
          declare nxt, nxt2 integer;
          nxt := DB.DBA.CYP_PEEK (_tokens, _pos + 1);
          nxt2 := DB.DBA.CYP_PEEK (_tokens, _pos + 2);
          if (nxt = 8 or nxt = 20 or nxt = 6
              or ((nxt = 50 or DB.DBA.CYP_IS_NON_RESERVED_KW (nxt)) and nxt2 = 7))
            {
              _pos := _pos + 1;
              proj_items := DB.DBA.CYP_PARSE_MAP_PROJ_ITEMS (_tokens, _pos);
              expr := vector ('MAPPROJ', expr, proj_items);
            }
          else
            goto postfix_done;
        }
      else if (tt = 8)
        {
          _pos := _pos + 1;
          tt := DB.DBA.CYP_PEEK (_tokens, _pos);
          if (tt = 7)
            {
              _pos := _pos + 1;
              tt := DB.DBA.CYP_PEEK (_tokens, _pos);
              if (tt <> 50 and not DB.DBA.CYP_IS_NON_RESERVED_KW (tt))
                signal ('CY010', sprintf ('Expected property name after default prefix at position %d', _pos));
              prop_name := concat (':', DB.DBA.CYP_PEEK_VAL (_tokens, _pos));
              _pos := _pos + 1;
              expr := vector ('PROP', expr, prop_name);
              goto postfix_next;
            }
          if (tt <> 50 and tt <> 55 and tt <> 56 and not DB.DBA.CYP_IS_NON_RESERVED_KW (tt))
            signal ('CY010', sprintf ('Expected property name or URI after dot at position %d', _pos));
          prop_name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 1;
          if (DB.DBA.CYP_PEEK (_tokens, _pos) = 1)
            {
              func_base := DB.DBA.CYP_DOTTED_FUNC_BASE_NAME (expr);
              if (func_base is not null)
                {
                  expr := DB.DBA.CYP_PARSE_FUNC_CALL (_tokens, _pos, concat (func_base, '.', prop_name));
                  goto postfix_next;
                }
            }
          expr := vector ('PROP', expr, prop_name);
        }
      else if (tt = 3)
        {
          _pos := _pos + 1;
          start_expr := null;
          end_expr := null;
          if (DB.DBA.CYP_PEEK (_tokens, _pos) <> 26 and DB.DBA.CYP_PEEK (_tokens, _pos) <> 4)
            start_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
          if (DB.DBA.CYP_PEEK (_tokens, _pos) = 26)
            {
              _pos := _pos + 1;
              if (DB.DBA.CYP_PEEK (_tokens, _pos) <> 4)
                end_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
              DB.DBA.CYP_EXPECT (_tokens, _pos, 4);
              expr := vector ('SLICE', expr, start_expr, end_expr);
            }
          else
            {
              idx_expr := start_expr;
              DB.DBA.CYP_EXPECT (_tokens, _pos, 4);
              expr := vector ('BINOP', '[]', expr, idx_expr);
            }
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

create procedure DB.DBA.CYP_EXPR_STARTS_PATTERN (in _tokens any, in _pos integer)
{
  declare pos, depth, tt integer;

  if (DB.DBA.CYP_PEEK (_tokens, _pos) <> 1)
    return 0;
  -- ( :Label ... ) is a pattern
  if (DB.DBA.CYP_PEEK (_tokens, _pos + 1) = 7)
    return 1;
  -- ( var ) in openCypher 2024.3 is a pattern predicate when the
  -- variable is sole content and not followed by an arithmetic/comparison
  -- operator (which would indicate a parenthesized expression).
  if (DB.DBA.CYP_PEEK (_tokens, _pos + 1) = 50
      and DB.DBA.CYP_PEEK (_tokens, _pos + 2) = 2)
    return 1;

  -- Quick reject: (number|unary|dot ...) can never be a pattern
  declare nxt integer;
  nxt := DB.DBA.CYP_PEEK (_tokens, _pos + 1);
  if (nxt = 52 or nxt = 53 or nxt = 12 or nxt = 19 or nxt = 8 or nxt = 1)
    return 0;

  pos := _pos;
  depth := 0;
  while (pos < length (_tokens))
    {
      tt := DB.DBA.CYP_PEEK (_tokens, pos);
      if (tt = 1)
        depth := depth + 1;
      else if (tt = 2)
        {
          depth := depth - 1;
          if (depth = 0)
            {
              tt := DB.DBA.CYP_PEEK (_tokens, pos + 1);
              if (tt = 12 or tt = 11)
                return 1;
              return 0;
            }
        }
      pos := pos + 1;
    }

  return 0;
}
;

create procedure DB.DBA.CYP_EXPR_STARTS_PATH_ASSIGNMENT (in _tokens any, in _pos integer)
{
  if (DB.DBA.CYP_PEEK (_tokens, _pos) <> 50)
    return 0;
  if (DB.DBA.CYP_PEEK (_tokens, _pos + 1) <> 15)
    return 0;
  return DB.DBA.CYP_EXPR_STARTS_PATTERN (_tokens, _pos + 2);
}
;

-- Primary expression
create procedure DB.DBA.CYP_PARSE_PRIMARY (in _tokens any, inout _pos integer)
{
  declare tt integer;
  declare val, fname, pname, lang varchar;
  declare expr, sub_expr any;
  tt := DB.DBA.CYP_PEEK (_tokens, _pos);
  val := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);

  if (tt = 1)
    {
      if (DB.DBA.CYP_EXPR_STARTS_PATTERN (_tokens, _pos))
        return vector ('PATTERNPRED', DB.DBA.CYP_PARSE_PATTERN (_tokens, _pos));

      _pos := _pos + 1;
      expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
      DB.DBA.CYP_EXPECT (_tokens, _pos, 2);
      return expr;
    }

  if (tt = 3)
    return DB.DBA.CYP_PARSE_LIST_LITERAL (_tokens, _pos);

  if (tt = 5)
    return DB.DBA.CYP_PARSE_MAP_LITERAL (_tokens, _pos);

  if (tt = 51)
    {
      _pos := _pos + 1;
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 23 and DB.DBA.CYP_PEEK (_tokens, _pos + 1) = 23)
        {
          _pos := _pos + 2;
          return vector ('TYPEDLIT', val, DB.DBA.CYP_PARSE_PRIMARY (_tokens, _pos));
        }
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 57)
        {
          lang := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 1;
          return vector ('LANGLIT', val, lang);
        }
      return vector ('LIT', val);
    }

  if (tt = 56)
    {
      _pos := _pos + 1;
      return vector ('IRI', val);
    }

  if (tt = 52)
    {
      _pos := _pos + 1;
      return vector ('LIT', DB.DBA.CYP_PARSE_INT_LITERAL (val));
    }

  if (tt = 53)
    {
      _pos := _pos + 1;
      return vector ('FLOAT', val);
    }

  if (tt = 8 and (DB.DBA.CYP_PEEK (_tokens, _pos + 1) = 52
                    or DB.DBA.CYP_PEEK (_tokens, _pos + 1) = 53))
    {
      declare float_val varchar;
      declare nxt_tt integer;
      declare nxt_val varchar;
      -- Leading-dot float: .1, .1e9, .1e-5, .1E-5
      -- When the lexer sees a digit after the dot, it parses a number
      -- token.  If that number includes an exponent it becomes a single
      -- FLOAT token; plain digits become an INTEGER token.
      _pos := _pos + 1;
      nxt_tt := DB.DBA.CYP_PEEK (_tokens, _pos);
      float_val := concat ('0.', DB.DBA.CYP_PEEK_VAL (_tokens, _pos));
      _pos := _pos + 1;
      if (nxt_tt = 52)
        {
          -- INTEGER after dot: check for separate exponent tokens (.1e-5)
          nxt_tt := DB.DBA.CYP_PEEK (_tokens, _pos);
          if (nxt_tt = 50)
            {
              nxt_val := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
              if (length (nxt_val) > 0 and (aref (nxt_val, 0) = 101 or aref (nxt_val, 0) = 69))
                {
                  _pos := _pos + 1;
                  float_val := concat (float_val, nxt_val);
                  if (length (nxt_val) = 1)
                    {
                      nxt_tt := DB.DBA.CYP_PEEK (_tokens, _pos);
                      if (nxt_tt = 12 or nxt_tt = 19)
                        {
                          float_val := concat (float_val, DB.DBA.CYP_PEEK_VAL (_tokens, _pos));
                          _pos := _pos + 1;
                          nxt_tt := DB.DBA.CYP_PEEK (_tokens, _pos);
                          if (nxt_tt = 52)
                            {
                              float_val := concat (float_val, DB.DBA.CYP_PEEK_VAL (_tokens, _pos));
                              _pos := _pos + 1;
                            }
                        }
                    }
                }
            }
        }
      return vector ('FLOAT', float_val);
    }

  -- TRUE / FALSE are kept in a dedicated LIT_BOOL node rather than
  -- being collapsed to LIT 1 / LIT 0 so the SPARQL generator can emit
  -- the boolean keywords `true` / `false` (an RDF xsd:boolean) instead
  -- of integer literals.  Carrying boolean origin through the AST is
  -- what lets toBoolean(true) return true end-to-end (closing the
  -- Phase 13.11 carry-forward).
  if (tt = 129)
    {
      _pos := _pos + 1;
      return vector ('LIT_BOOL', 1);
    }
  if (tt = 130)
    {
      _pos := _pos + 1;
      return vector ('LIT_BOOL', 0);
    }

  if (tt = 128)
    {
      _pos := _pos + 1;
      return vector ('LIT', null);
    }

  if (tt = 141)
    {
      if (_pos + 2 < length (_tokens)
          and DB.DBA.CYP_PEEK (_tokens, _pos + 1) = 1
          and DB.DBA.CYP_PEEK (_tokens, _pos + 2) = 20)
        {
          _pos := _pos + 3;
          DB.DBA.CYP_EXPECT (_tokens, _pos, 2);
          return vector ('COUNTSTAR');
        }
    }

  if (tt = 135)
    return DB.DBA.CYP_PARSE_CASE (_tokens, _pos);

  if (tt = 148)
    return DB.DBA.CYP_PARSE_REDUCE_EXPR (_tokens, _pos);

  if (tt = 120 or tt = 149 or tt = 150 or tt = 151)
    {
      if (DB.DBA.CYP_PEEK (_tokens, _pos + 1) = 1)
        return DB.DBA.CYP_PARSE_QUANTIFIER_EXPR (_tokens, _pos);
    }

  if (tt = 140)
    {
      _pos := _pos + 1;
      -- EXISTS ( expr ) keeps the legacy paren form for property-based
      -- existence checks routed through the exists() function.
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 1)
        {
          _pos := _pos + 1;
          sub_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
          DB.DBA.CYP_EXPECT (_tokens, _pos, 2);
          return vector ('FUNC', 'exists', 0, vector (sub_expr));
        }
      -- EXISTS { ... } is the openCypher 2024 existential subquery.
      -- Body supports both bare pattern+WHERE and full clauses (MATCH, WITH, RETURN).
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 5)
        {
          declare _patterns, _where, _clauses any;
          _pos := _pos + 1;
          if (DB.DBA.CYP_PEEK (_tokens, _pos) = 100)
            _pos := _pos + 1;
          _patterns := DB.DBA.CYP_PARSE_PATTERN_LIST (_tokens, _pos);
          _where := null;
          if (DB.DBA.CYP_PEEK (_tokens, _pos) = 102)
            {
              _pos := _pos + 1;
              _where := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
            }
          -- If a clause keyword follows, parse full clause body
          -- inside EXISTS { ... }.
          if (DB.DBA.CYP_PEEK (_tokens, _pos) = 100   -- MATCH
              or DB.DBA.CYP_PEEK (_tokens, _pos) = 103  -- RETURN
              or DB.DBA.CYP_PEEK (_tokens, _pos) = 110  -- WITH
              or DB.DBA.CYP_PEEK (_tokens, _pos) = 107  -- SET
              or DB.DBA.CYP_PEEK (_tokens, _pos) = 104  -- CREATE
              or DB.DBA.CYP_PEEK (_tokens, _pos) = 105  -- DELETE
              or DB.DBA.CYP_PEEK (_tokens, _pos) = 108) -- REMOVE
            {
              _clauses := vector ();
              while (DB.DBA.CYP_PEEK (_tokens, _pos) <> 6)
                {
                  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 103)
                    {
                      _pos := _pos + 1;
                      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 121)
                         _pos := _pos + 1;
                      _clauses := vector_concat (_clauses, vector (vector ('RETURN', 0, DB.DBA.CYP_PARSE_RETURN_ITEMS (_tokens, _pos), null, null, null, null, null)));
                    }
                  else if (DB.DBA.CYP_PEEK (_tokens, _pos) = 110)
                    {
                      _pos := _pos + 1;
                      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 121)
                         _pos := _pos + 1;
                      _clauses := vector_concat (_clauses, vector (vector ('WITH', 0, DB.DBA.CYP_PARSE_RETURN_ITEMS (_tokens, _pos), null, null, null, null)));
                    }
                  else if (DB.DBA.CYP_PEEK (_tokens, _pos) = 100)  -- MATCH
                    {
                      _pos := _pos + 1;
                      _patterns := vector_concat (_patterns, DB.DBA.CYP_PARSE_PATTERN_LIST (_tokens, _pos));
                    }
                  else if (DB.DBA.CYP_PEEK (_tokens, _pos) = 102)  -- WHERE
                    {
                      _pos := _pos + 1;
                      _where := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
                    }
                  else if (DB.DBA.CYP_PEEK (_tokens, _pos) = 107  -- SET
                           or DB.DBA.CYP_PEEK (_tokens, _pos) = 108 -- REMOVE
                           or DB.DBA.CYP_PEEK (_tokens, _pos) = 104 -- CREATE
                           or DB.DBA.CYP_PEEK (_tokens, _pos) = 105) -- DELETE
                    {
                      -- Skip SET/CREATE/DELETE/REMOVE clause by consuming
                      -- tokens until next clause keyword or closing brace.
                      declare skip_tt integer;
                      _pos := _pos + 1;
                      while (_pos < length (_tokens))
                        {
                          skip_tt := DB.DBA.CYP_PEEK (_tokens, _pos);
                          if (skip_tt = 6   -- RBRACE
                              or skip_tt = 100  -- MATCH
                              or skip_tt = 102  -- WHERE
                              or skip_tt = 103  -- RETURN
                              or skip_tt = 104  -- CREATE
                              or skip_tt = 105  -- DELETE
                              or skip_tt = 107  -- SET
                              or skip_tt = 108  -- REMOVE
                              or skip_tt = 110) -- WITH
                            goto skip_update_done;
                          _pos := _pos + 1;
                        }
                      skip_update_done: ;
                    }
                  else
                    _pos := _pos + 1;
                }
              DB.DBA.CYP_EXPECT (_tokens, _pos, 6);
              return vector ('EXISTSSUBQ', _patterns, _where, _clauses);
            }
          DB.DBA.CYP_EXPECT (_tokens, _pos, 6);
          return vector ('EXISTSSUBQ', _patterns, _where);
        }
      signal ('CY010', 'EXISTS must be followed by ( expr ) or { pattern }');
    }

  if (tt = 28)
    {
      _pos := _pos + 1;
      pname := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 1;
      return vector ('PARAM', pname);
    }

  if (tt = 55)
    {
      _pos := _pos + 1;
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 1)
        return DB.DBA.CYP_PARSE_FUNC_CALL (_tokens, _pos, val);
      return vector ('IRI', val);
    }

  if (tt = 50 or (tt >= 100 and tt <= 182))
    {
      fname := val;
      _pos := _pos + 1;
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 1)
        return DB.DBA.CYP_PARSE_FUNC_CALL (_tokens, _pos, fname);
      return vector ('VAR', fname);
    }

  signal ('CY010', sprintf ('Unexpected token type %d at position %d in expression', tt, _pos));
}
;

create procedure DB.DBA.CYP_PARSE_QUANTIFIER_EXPR (in _tokens any, inout _pos integer)
{
  declare kind, var_name varchar;
  declare list_expr, pred_expr any;

  kind := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
  _pos := _pos + 1;
  DB.DBA.CYP_EXPECT (_tokens, _pos, 1);
  var_name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
  DB.DBA.CYP_EXPECT (_tokens, _pos, 50);
  DB.DBA.CYP_EXPECT (_tokens, _pos, 126);
  list_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
  pred_expr := null;
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 102)
    {
      _pos := _pos + 1;
      pred_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
    }
  else
    pred_expr := vector ('VAR', var_name);
  DB.DBA.CYP_EXPECT (_tokens, _pos, 2);
  return vector ('QUANT', upper (kind), var_name, list_expr, pred_expr);
}
;

create procedure DB.DBA.CYP_PARSE_REDUCE_EXPR (in _tokens any, inout _pos integer)
{
  declare acc_name, var_name varchar;
  declare init_expr, list_expr, body_expr any;

  _pos := _pos + 1;
  DB.DBA.CYP_EXPECT (_tokens, _pos, 1);
  acc_name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
  DB.DBA.CYP_EXPECT (_tokens, _pos, 50);
  DB.DBA.CYP_EXPECT (_tokens, _pos, 15);
  init_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
  DB.DBA.CYP_EXPECT (_tokens, _pos, 9);
  var_name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
  DB.DBA.CYP_EXPECT (_tokens, _pos, 50);
  DB.DBA.CYP_EXPECT (_tokens, _pos, 126);
  list_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
  DB.DBA.CYP_EXPECT (_tokens, _pos, 25);
  body_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
  DB.DBA.CYP_EXPECT (_tokens, _pos, 2);
  return vector ('REDUCEEXPR', acc_name, init_expr, var_name, list_expr, body_expr);
}
;

-- Parse function call (after name consumed, starting at LPAREN)
create procedure DB.DBA.CYP_PARSE_FUNC_CALL (in _tokens any, inout _pos integer, in _fname varchar)
{
  declare args any;
  declare is_distinct integer;
  is_distinct := 0;
  args := vector ();

  DB.DBA.CYP_EXPECT (_tokens, _pos, 1);

  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 2)
    {
      _pos := _pos + 1;
      return vector ('FUNC', _fname, 0, args);
    }

  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 121)
    {
      is_distinct := 1;
      _pos := _pos + 1;
    }

  while (1)
    {
      args := vector_concat (args, vector (DB.DBA.CYP_PARSE_EXPR (_tokens, _pos)));
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 9)
        _pos := _pos + 1;
      else
        goto funcdone;
    }
  funcdone:
  DB.DBA.CYP_EXPECT (_tokens, _pos, 2);
  return vector ('FUNC', _fname, is_distinct, args);
}
;

-- Parse list literal [expr, expr, ...]
create procedure DB.DBA.CYP_PARSE_LIST_LITERAL (in _tokens any, inout _pos integer)
{
  declare elems, lc_list, lc_where, lc_proj any;
  declare pat any;
  declare lc_var varchar;
  elems := vector ();
  DB.DBA.CYP_EXPECT (_tokens, _pos, 3);

  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 4)
    {
      _pos := _pos + 1;
      return vector ('LIST', elems);
    }

  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 50 and
      _pos + 1 < length (_tokens) and DB.DBA.CYP_PEEK (_tokens, _pos + 1) = 126)
    {
      lc_var := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
      _pos := _pos + 2;
      lc_list := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
      lc_where := null;
      lc_proj := null;
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 102)
        {
          _pos := _pos + 1;
          lc_where := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
        }
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 25)
        {
          _pos := _pos + 1;
          lc_proj := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
        }
      DB.DBA.CYP_EXPECT (_tokens, _pos, 4);
      return vector ('LISTCOMP', lc_var, lc_list, lc_where, lc_proj);
    }

  if (DB.DBA.CYP_EXPR_STARTS_PATTERN (_tokens, _pos)
      or DB.DBA.CYP_EXPR_STARTS_PATH_ASSIGNMENT (_tokens, _pos))
    {
      pat := DB.DBA.CYP_PARSE_PATTERN (_tokens, _pos);
      lc_where := null;
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 102)
        {
          _pos := _pos + 1;
          lc_where := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
        }
      DB.DBA.CYP_EXPECT (_tokens, _pos, 25);
      lc_proj := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
      DB.DBA.CYP_EXPECT (_tokens, _pos, 4);
      return vector ('PATTERNCOMP', pat, lc_where, lc_proj);
    }

  while (1)
    {
      elems := vector_concat (elems, vector (DB.DBA.CYP_PARSE_EXPR (_tokens, _pos)));
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 9)
        _pos := _pos + 1;
      else
        goto listdone;
    }
  listdone:
  DB.DBA.CYP_EXPECT (_tokens, _pos, 4);
  return vector ('LIST', elems);
}
;

-- Parse map literal {key: expr, ...}
create procedure DB.DBA.CYP_PARSE_MAP_LITERAL (in _tokens any, inout _pos integer)
{
  declare keys, vals any;
  declare key_name varchar;
  keys := vector ();
  vals := vector ();

  DB.DBA.CYP_EXPECT (_tokens, _pos, 5);
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 6)
    {
      _pos := _pos + 1;
      return vector ('MAP', keys, vals);
    }

  while (1)
    {
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 7)
        {
          _pos := _pos + 1;
          if (DB.DBA.CYP_PEEK (_tokens, _pos) <> 50
              and not DB.DBA.CYP_IS_NON_RESERVED_KW (DB.DBA.CYP_PEEK (_tokens, _pos)))
            signal ('CY010', sprintf ('Expected map key after default prefix at position %d', _pos));
          key_name := concat (':', DB.DBA.CYP_PEEK_VAL (_tokens, _pos));
          _pos := _pos + 1;
        }
      else
        {
          if (DB.DBA.CYP_PEEK (_tokens, _pos) <> 50
              and DB.DBA.CYP_PEEK (_tokens, _pos) <> 55
              and DB.DBA.CYP_PEEK (_tokens, _pos) <> 56
              and not DB.DBA.CYP_IS_NON_RESERVED_KW (DB.DBA.CYP_PEEK (_tokens, _pos)))
            signal ('CY010', sprintf ('Expected map key at position %d', _pos));
          key_name := DB.DBA.CYP_PEEK_VAL (_tokens, _pos);
          _pos := _pos + 1;
        }
      DB.DBA.CYP_EXPECT (_tokens, _pos, 7);
      keys := vector_concat (keys, vector (key_name));
      vals := vector_concat (vals, vector (DB.DBA.CYP_PARSE_EXPR (_tokens, _pos)));
      if (DB.DBA.CYP_PEEK (_tokens, _pos) = 9)
        _pos := _pos + 1;
      else
        goto mapdone;
    }
  mapdone:
  DB.DBA.CYP_EXPECT (_tokens, _pos, 6);
  return vector ('MAP', keys, vals);
}
;

-- Parse CASE expression
create procedure DB.DBA.CYP_PARSE_CASE (in _tokens any, inout _pos integer)
{
  declare operand, else_expr, when_cond, then_expr any;
  declare whens any;
  declare tt integer;

  _pos := _pos + 1;
  operand := null;
  else_expr := null;
  whens := vector ();

  tt := DB.DBA.CYP_PEEK (_tokens, _pos);
  if (tt <> 136)
    operand := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);

  while (DB.DBA.CYP_PEEK (_tokens, _pos) = 136)
    {
      _pos := _pos + 1;
      when_cond := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
      DB.DBA.CYP_EXPECT (_tokens, _pos, 137);
      then_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
      whens := vector_concat (whens, vector (vector (when_cond, then_expr)));
    }

  if (DB.DBA.CYP_PEEK (_tokens, _pos) = 138)
    {
      _pos := _pos + 1;
      else_expr := DB.DBA.CYP_PARSE_EXPR (_tokens, _pos);
    }

  DB.DBA.CYP_EXPECT (_tokens, _pos, 139);
  return vector ('CASEEXPR', operand, whens, else_expr);
}
;

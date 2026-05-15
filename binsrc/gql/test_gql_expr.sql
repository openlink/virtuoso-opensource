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
--  openGQL: GQL for Virtuoso - Expression Parser Tests
--
--  Run via isql: isql <host>:<port> dba dba < test_gql_expr.sql
--

create procedure DB.DBA.GQL_EXPR_TESTS ()
{
  declare _pass, _fail, _total integer;
  declare _results any;
  declare _ast, _tokens any;

  _pass := 0; _fail := 0; _total := 0;
  _results := vector ();

  -- Helper: tokenize and parse expression inline
  declare _PARSE varchar;
  _PARSE := 'PARSE';

  -- ===================================================================
  -- Section 1: Literals
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('42');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'LIT' and aref (_ast, 1) = 42)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET1 PASS: integer 42')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET1 FAIL: integer 42')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('3.14');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'FLOAT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET2 PASS: float 3.14')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET2 FAIL: float 3.14')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('''hello''');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'LIT' and aref (_ast, 1) = 'hello')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET3 PASS: string hello')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET3 FAIL: string hello')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('true');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'LIT_BOOL' and aref (_ast, 1) = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET4 PASS: true')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET4 FAIL: true')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('false');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'LIT_BOOL' and aref (_ast, 1) = 0)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET5 PASS: false')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET5 FAIL: false')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('null');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'LIT' and aref (_ast, 1) is null)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET6 PASS: null')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET6 FAIL: null')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('$param');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'PARAM' and aref (_ast, 1) = '$param')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET7 PASS: param $param')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET7 FAIL: param $param')); }

  -- ===================================================================
  -- Section 2: Arithmetic
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('1 + 2');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'BINOP' and aref (_ast, 1) = '+')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET8 PASS: 1 + 2')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET8 FAIL: 1 + 2')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('1 - 2');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'BINOP' and aref (_ast, 1) = '-')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET9 PASS: 1 - 2')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET9 FAIL: 1 - 2')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('2 * 3');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'BINOP' and aref (_ast, 1) = '*')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET10 PASS: 2 * 3')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET10 FAIL: 2 * 3')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('6 / 2');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'BINOP' and aref (_ast, 1) = '/')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET11 PASS: 6 / 2')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET11 FAIL: 6 / 2')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('2 ^ 8');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'BINOP' and aref (_ast, 1) = '^')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET12 PASS: 2 ^ 8')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET12 FAIL: 2 ^ 8')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('1 + 2 * 3');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'BINOP' and aref (_ast, 1) = '+'
      and aref (aref (_ast, 3), 1) = '*')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET13 PASS: 1 + 2 * 3 precedence')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET13 FAIL: 1 + 2 * 3 precedence')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('(1 + 2) * 3');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'BINOP' and aref (_ast, 1) = '*'
      and aref (aref (_ast, 2), 1) = '+')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET14 PASS: (1 + 2) * 3 parens')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET14 FAIL: (1 + 2) * 3 parens')); }

  -- ===================================================================
  -- Section 3: Boolean
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('a AND b');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'BINOP' and aref (_ast, 1) = 'AND')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET15 PASS: a AND b')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET15 FAIL: a AND b')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('a OR b');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'BINOP' and aref (_ast, 1) = 'OR')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET16 PASS: a OR b')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET16 FAIL: a OR b')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('NOT a');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'UNOP' and aref (_ast, 1) = 'NOT')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET17 PASS: NOT a')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET17 FAIL: NOT a')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('a AND b OR c');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'BINOP' and aref (_ast, 1) = 'OR'
      and aref (aref (_ast, 2), 1) = 'AND')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET18 PASS: a AND b OR c (AND binds tighter)')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET18 FAIL: a AND b OR c precedence')); }

  -- ===================================================================
  -- Section 4: Comparisons
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('a = b');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'BINOP' and aref (_ast, 1) = '=')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET19 PASS: a = b')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET19 FAIL: a = b')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('a <> b');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'BINOP' and aref (_ast, 1) = '<>')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET20 PASS: a <> b')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET20 FAIL: a <> b')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('a > b');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'BINOP' and aref (_ast, 1) = '>')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET21 PASS: a > b')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET21 FAIL: a > b')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('a IS NULL');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'ISNULL' and aref (_ast, 2) = 0)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET22 PASS: a IS NULL')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET22 FAIL: a IS NULL')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('a IS NOT NULL');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'ISNULL' and aref (_ast, 2) = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET23 PASS: a IS NOT NULL')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET23 FAIL: a IS NOT NULL')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('a IN [1, 2, 3]');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'INEXPR')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET24 PASS: a IN [1, 2, 3]')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET24 FAIL: a IN [1, 2, 3]')); }

  -- ===================================================================
  -- Section 5: Property access and postfix
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('n.name');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'PROP' and aref (aref (_ast, 1), 1) = 'n' and aref (_ast, 2) = 'name')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET25 PASS: n.name')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET25 FAIL: n.name')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('n.list[0]');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'BINOP' and aref (_ast, 1) = '[]')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET26 PASS: n.list[0]')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET26 FAIL: n.list[0]')); }

  -- ===================================================================
  -- Section 6: Function calls
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('count(*)');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'COUNTSTAR')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET27 PASS: count(*)')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET27 FAIL: count(*)')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('count(n)');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'FUNC' and aref (_ast, 1) = 'count')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET28 PASS: count(n)')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET28 FAIL: count(n)')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('coalesce(a, b, c)');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'FUNC' and aref (_ast, 1) = 'coalesce'
      and length (aref (_ast, 3)) = 3)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET29 PASS: coalesce(a, b, c)')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET29 FAIL: coalesce(a, b, c)')); }

  -- ===================================================================
  -- Section 7: List and map literals
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('[1, 2, 3]');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'LIST' and length (aref (_ast, 1)) = 3)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET30 PASS: [1, 2, 3]')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET30 FAIL: [1, 2, 3]')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('{key: ''val''}');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'MAP' and length (aref (_ast, 1)) = 1)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET31 PASS: {key: val}')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET31 FAIL: {key: val}')); }

  -- ===================================================================
  -- Section 8: CASE
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('CASE WHEN n > 0 THEN 1 ELSE 0 END');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'CASEEXPR')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET32 PASS: CASE WHEN THEN ELSE END')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET32 FAIL: CASE WHEN THEN ELSE END')); }

  -- ===================================================================
  -- Section 9: Typed literals
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('DATE ''2023-01-01''');
  _ast := DB.DBA.GQL_PARSE_EXPR (_tokens, 0);
  if (aref (_ast, 0) = 'TYPEDLIT' and aref (_ast, 1) = 'DATE')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET33 PASS: DATE typed literal')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET33 FAIL: DATE typed literal')); }

  -- ===================================================================
  -- Section 10: Integration (WHERE/RETURN expressions via parser)
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n) WHERE n.age > 30 RETURN n.name');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET34 PASS: WHERE > expr')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET34 FAIL: WHERE > expr')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n) WHERE n.age > 30 AND n.active = true RETURN n.name');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET35 PASS: WHERE AND compound expr')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET35 FAIL: WHERE AND compound expr')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (n) RETURN n ORDER BY n.name DESC');
  _ast := DB.DBA.GQL_PARSE (_tokens);
  if (aref (_ast, 0) = 'PROG')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('ET36 PASS: ORDER BY DESC expr')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('ET36 FAIL: ORDER BY DESC expr')); }

  -- ===================================================================
  -- Summary
  -- ===================================================================

  _results := vector_concat (_results, vector (''));
  _results := vector_concat (_results, vector (concat ('TOTAL: ', cast (_total as varchar))));
  _results := vector_concat (_results, vector (concat ('PASS:  ', cast (_pass as varchar))));
  _results := vector_concat (_results, vector (concat ('FAIL:  ', cast (_fail as varchar))));

  declare i integer;
  for (i := 0; i < length (_results); i := i + 1)
    dbg_obj_print (aref (_results, i));

  if (_fail > 0)
    signal ('23000', concat (cast (_fail as varchar), ' test(s) failed'));
}
;

SELECT DB.DBA.GQL_EXPR_TESTS ();

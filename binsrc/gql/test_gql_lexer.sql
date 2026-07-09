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
--  openGQL: GQL for Virtuoso - Lexer Round-Trip Tests
--
--  Run via isql: isql <host>:<port> dba dba < test_gql_lexer.sql
--

create procedure DB.DBA.GQL_LEXER_TESTS ()
{
  declare _pass, _fail, _total integer;
  declare _results any;
  declare _tokens any;
  declare _t, _t0, _t1, _t2, _v0, _v1, _v2 any;

  _pass := 0;
  _fail := 0;
  _total := 0;
  _results := vector ();

  -- Helper: assert token type at position
  declare _ASSERT_TYPE varchar;
  _ASSERT_TYPE := 'TYPE';

  -- Helper: assert token value at position
  declare _ASSERT_VAL varchar;
  _ASSERT_VAL := 'VAL';

  -- ===================================================================
  -- Section 1: Empty / Whitespace / EOF
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('');
  if (length (_tokens) = 1 and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 999)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT1 PASS: empty input -> EOF')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT1 FAIL: empty input')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('   \t  \n  ');
  if (length (_tokens) = 1 and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 999)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT2 PASS: whitespace-only -> EOF')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT2 FAIL: whitespace-only')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH');
  if (length (_tokens) = 2
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 200
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 1)) = 999)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT3 PASS: MATCH -> EOF')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT3 FAIL: MATCH alone')); }

  -- ===================================================================
  -- Section 2: Single-char tokens
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('()[]{}:,');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 1
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 1)) = 2
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 2)) = 3
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 3)) = 4
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 4)) = 5
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 5)) = 6
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 6)) = 7
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 7)) = 9)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT4 PASS: single-char delimiters')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT4 FAIL: single-char delimiters')); }

  -- ===================================================================
  -- Section 3: Multi-char operators (2-char)
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('->');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 10)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT5 PASS: ->')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT5 FAIL: ->')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('<-');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 11)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT6 PASS: <-')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT6 FAIL: <-')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('<>');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 16)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT7 PASS: <>')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT7 FAIL: <>')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('<=');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 17)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT8 PASS: <=')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT8 FAIL: <=')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('>=');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 18)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT9 PASS: >=')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT9 FAIL: >=')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('..');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 26)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT10 PASS: ..')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT10 FAIL: ..')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('+=');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 27)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT11 PASS: +=')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT11 FAIL: +=')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('::');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 30)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT12 PASS: ::')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT12 FAIL: ::')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('=>');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 31)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT13 PASS: =>')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT13 FAIL: =>')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('~>');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 33)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT14 PASS: ~>')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT14 FAIL: ~>')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('<~');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 34)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT15 PASS: <~')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT15 FAIL: <~')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('!=');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 16)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT16 PASS: != -> NEQ')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT16 FAIL: != -> NEQ')); }

  -- ===================================================================
  -- Section 4: Multi-char operators (3-char)
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('->|');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 35)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT17 PASS: ->|')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT17 FAIL: ->|')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('|->');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 36)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT18 PASS: |->')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT18 FAIL: |->')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('<->');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 41)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT19 PASS: <->')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT19 FAIL: <->')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('<-/');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 39)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT20 PASS: <-/')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT20 FAIL: <-/')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('/->');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 40)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT21 PASS: /->')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT21 FAIL: /->')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('<~/');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 37)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT22 PASS: <~/')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT22 FAIL: <~/')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('/~>');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 38)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT23 PASS: /~>')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT23 FAIL: /~>')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE (']->');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 44)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT24 PASS: ]->')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT24 FAIL: ]->')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE (']~>');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 45)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT25 PASS: ]~>')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT25 FAIL: ]~>')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('<~[');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 53)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT26 PASS: <~[')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT26 FAIL: <~[')); }

  -- '?', '-[', '~[', '/-', '-/', '~/', '/~', ']~', ']-'
  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('?');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 42)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT27 PASS: ? standalone')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT27 FAIL: ? standalone')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('-[');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 46)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT28 PASS: -[')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT28 FAIL: -[')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('~[');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 47)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT29 PASS: ~[')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT29 FAIL: ~[')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('-/');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 49)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT30 PASS: -/')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT30 FAIL: -/')); }

  -- ===================================================================
  -- Section 5: String escapes
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('''hello\nworld''');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 65
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = concat ('hello', chr(10), 'world'))
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT31 PASS: \\n escape')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT31 FAIL: \\n escape')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('''tab\there''');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 65
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = concat ('tab', chr(9), 'here'))
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT32 PASS: \\t escape')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT32 FAIL: \\t escape')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('''slash\\back''');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 65
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = 'slash\\back')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT33 PASS: \\\\ escape')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT33 FAIL: \\\\ escape')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('''quote\''s''');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 65
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = 'quote''s')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT34 PASS: \\'' escape')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT34 FAIL: \\'' escape')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('''unicodeA''');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 65
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = 'unicodeA')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT35 PASS: \\u0041 -> A')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT35 FAIL: \\u0041 -> A')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('''emoji\U0001F600''');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 65)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT36 PASS: \\U0001F600 emoji')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT36 FAIL: \\U0001F600 emoji')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('''doubled''''quote''');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 65
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = 'doubled''quote')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT37 PASS: doubled '' escape')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT37 FAIL: doubled '' escape')); }

  -- ===================================================================
  -- Section 6: Double-quoted strings
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('"hello"');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 72
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = 'hello')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT38 PASS: double-quoted string')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT38 FAIL: double-quoted string')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('"double\\"quote"');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 72
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = 'double"quote')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT39 PASS: escaped double-quote')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT39 FAIL: escaped double-quote')); }

  -- ===================================================================
  -- Section 7: Backtick identifiers (FIXED logic)
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('`my table`');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 71
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = 'my table')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT40 PASS: backtick identifier')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT40 FAIL: backtick identifier')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('`backtick\\`ident`');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 71
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = 'backtick`ident')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT41 PASS: escaped backtick (FIXED)')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT41 FAIL: escaped backtick')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('`doubled``ident`');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 71
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = 'doubled`ident')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT42 PASS: doubled backtick escape')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT42 FAIL: doubled backtick escape')); }

  -- ===================================================================
  -- Section 8: NO_ESCAPE strings
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('@''raw\\nstring''');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 65
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = 'raw\\nstring')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT43 PASS: NO_ESCAPE single-quoted')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT43 FAIL: NO_ESCAPE single-quoted')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('@"raw\\"string"');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 72
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = 'raw\\"string')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT44 PASS: NO_ESCAPE double-quoted')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT44 FAIL: NO_ESCAPE double-quoted')); }

  -- ===================================================================
  -- Section 9: Comments
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('/* inline */ MATCH');
  if (length (_tokens) = 2
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 200
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 1)) = 999)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT45 PASS: /* */ block comment')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT45 FAIL: /* */ block comment')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('/* multi' || chr(10) || 'line */ MATCH');
  if (length (_tokens) = 2
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 200)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT46 PASS: multi-line block comment')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT46 FAIL: multi-line block comment')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('// line comment' || chr(10) || 'MATCH');
  if (length (_tokens) = 2
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 200)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT47 PASS: // line comment')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT47 FAIL: // line comment')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('-- SQL comment' || chr(10) || 'MATCH');
  if (length (_tokens) = 2
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 200)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT48 PASS: -- SQL comment')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT48 FAIL: -- SQL comment')); }

  -- Unterminated block comment -> error
  _total := _total + 1;
  {
    declare exit handler for sqlstate '*'
      {
        _pass := _pass + 1;
        _results := vector_concat (_results, vector ('LT49 PASS: unterminated /* -> error'));
        goto lt49_done;
      };
    _tokens := DB.DBA.GQL_TOKENIZE ('/* unterminated');
    _fail := _fail + 1;
    _results := vector_concat (_results, vector ('LT49 FAIL: unterminated /* should error'));
  }
  lt49_done:;

  -- ===================================================================
  -- Section 10: Parameters ($, $$, ?)
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('$paramName');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 68
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = '$paramName')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT50 PASS: $param')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT50 FAIL: $param')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('$$paramName');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 68
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = '$$paramName')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT51 PASS: $$param')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT51 FAIL: $$param')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('?paramName');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 68
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = '?paramName')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT52 PASS: ?param')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT52 FAIL: ?param')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('$x');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 68
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = '$x')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT53 PASS: $x')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT53 FAIL: $x')); }

  -- ===================================================================
  -- Section 11: Numbers
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('123');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 66
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = '123')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT54 PASS: integer 123')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT54 FAIL: integer 123')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('1_000_000');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 66
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = '1000000')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT55 PASS: underscore in number')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT55 FAIL: underscore in number')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('0xDEAD_BEEF');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 66
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = '0xDEADBEEF')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT56 PASS: hex with underscore')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT56 FAIL: hex with underscore')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('0o777');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 66)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT57 PASS: octal 0o777')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT57 FAIL: octal 0o777')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('0b1010_0101');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 66
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = '0b10100101')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT58 PASS: binary with underscore')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT58 FAIL: binary with underscore')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('3.14');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 67
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = '3.14')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT59 PASS: float 3.14')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT59 FAIL: float 3.14')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('.5');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 67
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = '.5')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT60 PASS: leading-dot float .5')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT60 FAIL: leading-dot float .5')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('1.5e10');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 67)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT61 PASS: scientific 1.5e10')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT61 FAIL: scientific 1.5e10')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('1.5E-10');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 67)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT62 PASS: scientific 1.5E-10')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT62 FAIL: scientific 1.5E-10')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('123M');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 66
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = '123M')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT63 PASS: exact suffix 123M')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT63 FAIL: exact suffix 123M')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('3.14F');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 67
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = '3.14F')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT64 PASS: approximate suffix 3.14F')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT64 FAIL: approximate suffix 3.14F')); }

  -- ===================================================================
  -- Section 12: IRIREF and prefixed names
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('<http://example.org/ns#Person>');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 70
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = 'http://example.org/ns#Person')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT65 PASS: IRIREF')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT65 FAIL: IRIREF')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('<urn:test:graph>');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 70)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT66 PASS: IRIREF urn')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT66 FAIL: IRIREF urn')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('foaf:Person');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 69
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 0)) = 'foaf:Person')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT67 PASS: prefixed name')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT67 FAIL: prefixed name')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('xsd:integer');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 69)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT68 PASS: xsd:integer')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT68 FAIL: xsd:integer')); }

  -- ===================================================================
  -- Section 13: Case insensitivity
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('match');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 200)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT69 PASS: lowercase match')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT69 FAIL: lowercase match')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('Match');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 200)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT70 PASS: mixed-case Match')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT70 FAIL: mixed-case Match')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MatchVariable');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 64)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT71 PASS: MatchVariable -> IDENT')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT71 FAIL: MatchVariable -> IDENT')); }

  -- ===================================================================
  -- Section 14: Line/column tracking
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH' || chr(10) || 'RETURN');
  if (length (_tokens) = 3
      and DB.DBA.GQL_TOK_LINE (aref (_tokens, 0)) = 1
      and DB.DBA.GQL_TOK_LINE (aref (_tokens, 1)) = 2)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT72 PASS: line tracking')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT72 FAIL: line tracking')); }

  -- ===================================================================
  -- Section 15: Keyword coverage spot-checks
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('RETURN');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 205)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT73 PASS: RETURN')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT73 FAIL: RETURN')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('WHERE');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 206)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT74 PASS: WHERE')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT74 FAIL: WHERE')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('SESSION');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 244)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT75 PASS: SESSION')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT75 FAIL: SESSION')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('INSERT');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 201)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT76 PASS: INSERT')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT76 FAIL: INSERT')); }

  -- ===================================================================
  -- Section 16: New keywords (ASK, MINUS, MODIFY)
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('ASK');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 531)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT80 PASS: ASK keyword')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT80 FAIL: ASK keyword')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MINUS');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 532)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT81 PASS: MINUS keyword')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT81 FAIL: MINUS keyword')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MODIFY');
  if (DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 533)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT82 PASS: MODIFY keyword')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT82 FAIL: MODIFY keyword')); }

  -- ===================================================================
  -- Section 17: DEFINE namespaced key tokenization (§6.1 verification)
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('DEFINE input:inference "urn:rules"');
  if (length (_tokens) >= 4
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 284  -- DEFINE
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 1)) = 69   -- PNAME (input:inference)
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 1)) = 'input:inference')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT83 PASS: DEFINE input:inference namespaced key')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT83 FAIL: DEFINE namespaced key')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('DEFINE input:same-as "yes"');
  if (length (_tokens) >= 4
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 284  -- DEFINE
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 1)) = 69   -- PNAME (input:same-as)
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 1)) = 'input:same-as')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT84 PASS: DEFINE input:same-as namespaced key')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT84 FAIL: DEFINE input:same-as key')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('DEFINE output:format "json"');
  if (length (_tokens) >= 4
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 284  -- DEFINE
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 1)) = 69   -- PNAME (output:format)
      and DB.DBA.GQL_TOK_VAL (aref (_tokens, 1)) = 'output:format')
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT85 PASS: DEFINE output:format namespaced key')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT85 FAIL: DEFINE output:format key')); }

  -- ===================================================================
  -- Section 18: Sample file round-trips (embed key samples)
  -- ===================================================================

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('MATCH (a { firstname: ''Robert'' }), (b { lastname: ''Kowalski'' }) INSERT (a)-[:GRADUATED]->(b)');
  if (length (_tokens) > 10
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 200
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, length (_tokens) - 1)) = 999)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT77 PASS: match_and_insert sample')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT77 FAIL: match_and_insert sample')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('CREATE GRAPH mygraph ANY');
  if (length (_tokens) = 5
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 223
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 1)) = 225)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT78 PASS: CREATE GRAPH sample')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT78 FAIL: CREATE GRAPH sample')); }

  _total := _total + 1;
  _tokens := DB.DBA.GQL_TOKENIZE ('SESSION SET VALUE IF NOT EXISTS $exampleProperty = DATE ''2022-10-10''');
  if (length (_tokens) > 5
      and DB.DBA.GQL_TOK_TYPE (aref (_tokens, 0)) = 244)
    { _pass := _pass + 1; _results := vector_concat (_results, vector ('LT79 PASS: SESSION SET sample')); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector ('LT79 FAIL: SESSION SET sample')); }

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

SELECT DB.DBA.GQL_LEXER_TESTS ();

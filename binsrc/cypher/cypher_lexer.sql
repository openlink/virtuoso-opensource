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
--  openCypher: OpenCypher for Virtuoso - Lexer/Tokenizer
--
--  Token types (integer constants):
--    Symbols: 1=LPAREN 2=RPAREN 3=LBRACKET 4=RBRACKET 5=LBRACE 6=RBRACE
--            7=COLON 8=DOT 9=COMMA 10=ARROW_R(->) 11=ARROW_L(<-)
--            12=DASH 13=LT 14=GT 15=EQ 16=NEQ(<>) 17=LTE 18=GTE
--            19=PLUS 20=STAR 21=SLASH 22=PERCENT 23=CARET 24=BANG
--            25=PIPE 26=DOTDOT(..) 27=PLUSEQ(+=) 28=DOLLAR 29=AMPERSAND
--    Values: 50=IDENT 51=STRING 52=INTEGER 53=FLOAT 54=PARAM 57=LANGTAG
--    Keywords: 100=MATCH 101=OPTIONAL 102=WHERE 103=RETURN 104=CREATE
--            105=DELETE 106=DETACH 107=SET 108=REMOVE 109=MERGE
--            110=WITH 111=UNWIND 112=AS 113=ORDER 114=BY
--            115=ASC 116=DESC 117=SKIP_KW (also OFFSET synonym) 118=LIMIT 119=UNION
--            120=ALL 121=DISTINCT 122=AND 123=OR 124=NOT 125=XOR
--            126=IN 127=IS 128=NULL_KW 129=TRUE_KW 130=FALSE_KW
--            131=STARTS 132=ENDS 133=CONTAINS 134=ON
--            135=CASE 136=WHEN 137=THEN 138=ELSE 139=END_KW
--            140=EXISTS 141=COUNT 142=CALL 143=YIELD
--            144=ASCENDING 145=DESCENDING
--            146=SHORTESTPATH 147=ALLSHORTESTPATHS
--            148=REDUCE 149=SINGLE 150=ANY_KW 151=NONE 152=TRIM
--            153=PREFIX 154=GRAPH_KW 155=INTO 156=FROM
--            157=DEFINE 158=NAMED 159=SERVICE 160=VALUES
--            161=BIND 162=MINUS 163=GROUP 164=HAVING
--            165=ASK 166=CONSTRUCT 167=DESCRIBE
--            168=LOAD 169=CLEAR 170=DROP 171=ADD 172=MOVE 173=COPY
--            174=SILENT 175=DEFAULT 176=TO
--            177=USING 178=INSERT 179=DATA
--            180=SHORTEST 181=GROUPS 182=BASE 183=FORCE 184=CAMELCASE 185=USE
--    Special: 55=PNAME_NS (prefixed name), 56=IRIREF (<...>), 999=EOF
--

-- Lookup keyword, returns token type or 0 if not a keyword
create procedure DB.DBA.CYP_KEYWORD (in _w varchar)
{
  declare w varchar;
  w := upper (_w);
  if (w = 'MATCH') return 100;
  if (w = 'OPTIONAL') return 101;
  if (w = 'WHERE') return 102;
  if (w = 'RETURN') return 103;
  if (w = 'CREATE') return 104;
  if (w = 'DELETE') return 105;
  if (w = 'DETACH') return 106;
  if (w = 'SET') return 107;
  if (w = 'REMOVE') return 108;
  if (w = 'MERGE') return 109;
  if (w = 'WITH') return 110;
  if (w = 'UNWIND') return 111;
  if (w = 'AS') return 112;
  if (w = 'ORDER') return 113;
  if (w = 'BY') return 114;
  if (w = 'ASC') return 115;
  if (w = 'DESC') return 116;
  if (w = 'SKIP') return 117;
  if (w = 'OFFSET') return 117;  -- openCypher 2024.3: <offset synonym> ::= SKIP | OFFSET
  if (w = 'LIMIT') return 118;
  if (w = 'UNION') return 119;
  if (w = 'ALL') return 120;
  if (w = 'DISTINCT') return 121;
  if (w = 'AND') return 122;
  if (w = 'OR') return 123;
  if (w = 'NOT') return 124;
  if (w = 'XOR') return 125;
  if (w = 'IN') return 126;
  if (w = 'IS') return 127;
  if (w = 'NULL') return 128;
  if (w = 'TRUE') return 129;
  if (w = 'FALSE') return 130;
  if (w = 'STARTS') return 131;
  if (w = 'ENDS') return 132;
  if (w = 'CONTAINS') return 133;
  if (w = 'ON') return 134;
  if (w = 'CASE') return 135;
  if (w = 'WHEN') return 136;
  if (w = 'THEN') return 137;
  if (w = 'ELSE') return 138;
  if (w = 'END') return 139;
  if (w = 'EXISTS') return 140;
  if (w = 'COUNT') return 141;
  if (w = 'CALL') return 142;
  if (w = 'YIELD') return 143;
  if (w = 'ASCENDING') return 144;
  if (w = 'DESCENDING') return 145;
  if (w = 'SHORTESTPATH') return 146;
  if (w = 'ALLSHORTESTPATHS') return 147;
  if (w = 'REDUCE') return 148;
  if (w = 'SINGLE') return 149;
  if (w = 'ANY') return 150;
  if (w = 'NONE') return 151;
  if (w = 'TRIM') return 152;
  if (w = 'PREFIX') return 153;
  if (w = 'GRAPH') return 154;
  if (w = 'INTO') return 155;
  if (w = 'FROM') return 156;
  if (w = 'DEFINE') return 157;
  if (w = 'NAMED') return 158;
  if (w = 'SERVICE') return 159;
  if (w = 'VALUES') return 160;
  if (w = 'BIND') return 161;
  if (w = 'MINUS') return 162;
  if (w = 'GROUP') return 163;
  if (w = 'HAVING') return 164;
  if (w = 'ASK') return 165;
  if (w = 'CONSTRUCT') return 166;
  if (w = 'DESCRIBE') return 167;
  if (w = 'LOAD') return 168;
  if (w = 'CLEAR') return 169;
  if (w = 'DROP') return 170;
  if (w = 'ADD') return 171;
  if (w = 'MOVE') return 172;
  if (w = 'COPY') return 173;
  if (w = 'SILENT') return 174;
  if (w = 'DEFAULT') return 175;
  if (w = 'TO') return 176;
  if (w = 'USING') return 177;
  if (w = 'INSERT') return 178;
  if (w = 'DATA') return 179;
  if (w = 'SHORTEST') return 180;
  if (w = 'GROUPS') return 181;
  if (w = 'BASE') return 182;
  if (w = 'FORCE') return 183;
  if (w = 'CAMELCASE') return 184;
  if (w = 'USE') return 185;
  return 0;
}
;

-- Decode a four-hex-digit \uXXXX escape starting at _start in the
-- source string.  Returns the decoded character (UTF-8 for code points
-- above 0x7F).  _err_pos identifies the enclosing string literal for
-- error reporting.
create procedure DB.DBA.CYP_DECODE_UNICODE_ESCAPE (in _q varchar, in _start integer, in _err_pos integer)
  returns varchar
{
  declare _qlen, _i, _ch, _digit, _cp integer;

  _qlen := length (_q);
  if (_start + 4 > _qlen)
    signal ('CY001', sprintf ('Truncated \\u escape in string literal at position %d', _err_pos));
  _cp := 0;
  for (_i := 0; _i < 4; _i := _i + 1)
    {
      _ch := aref (_q, _start + _i);
      if (_ch >= 48 and _ch <= 57) _digit := _ch - 48;
      else if (_ch >= 65 and _ch <= 70) _digit := _ch - 55;
      else if (_ch >= 97 and _ch <= 102) _digit := _ch - 87;
      else
        signal ('CY001', sprintf ('Invalid hex digit ''%s'' in \\u escape at position %d', chr (_ch), _err_pos));
      _cp := _cp * 16 + _digit;
    }

  if (_cp < 128)
    return chr (_cp);
  if (_cp < 2048)
    return concat (chr (192 + bit_shift (_cp, -6)),
                   chr (128 + mod (_cp, 64)));
  return concat (chr (224 + bit_shift (_cp, -12)),
                 chr (128 + mod (bit_shift (_cp, -6), 64)),
                 chr (128 + mod (_cp, 64)));
}
;

-- Token accessors
create procedure DB.DBA.CYP_TOK_TYPE (in _tok any) { return aref (_tok, 0); }
;
create procedure DB.DBA.CYP_TOK_VAL (in _tok any) { return aref (_tok, 1); }
;
create procedure DB.DBA.CYP_TOK_POS (in _tok any) { return aref (_tok, 2); }
;

-- Helper: is character a letter or underscore
create procedure DB.DBA.CYP_IS_IDENT_START (in ch integer)
{
  if (ch >= 65 and ch <= 90) return 1;
  if (ch >= 97 and ch <= 122) return 1;
  if (ch = 95) return 1;
  return 0;
}
;

-- Helper: is character a letter, digit, or underscore
create procedure DB.DBA.CYP_IS_IDENT_CHAR (in ch integer)
{
  if (ch >= 65 and ch <= 90) return 1;
  if (ch >= 97 and ch <= 122) return 1;
  if (ch >= 48 and ch <= 57) return 1;
  if (ch = 95) return 1;
  return 0;
}
;

-- Helper: is character a digit
create procedure DB.DBA.CYP_IS_DIGIT (in ch integer)
{
  if (ch >= 48 and ch <= 57) return 1;
  return 0;
}
;

-- Main tokenizer: returns vector of tokens, each token = vector(type, value, pos)
create procedure DB.DBA.CYP_TOKENIZE (in _q varchar)
{
  declare tokens any;
  declare i, qlen, ch, ch2, start_pos, kw, iri_end integer;
  declare val varchar;

  tokens := vector ();
  qlen := length (_q);
  i := 0;

  while (i < qlen)
    {
      ch := aref (_q, i);

      -- Skip whitespace
      if (ch = 32 or ch = 9 or ch = 10 or ch = 13)
        {
          i := i + 1;
        }
      -- Skip single-line comment //
      else if (ch = 47 and i + 1 < qlen and aref (_q, i + 1) = 47)
        {
          i := i + 2;
          while (i < qlen and aref (_q, i) <> 10)
            i := i + 1;
        }
      -- Parentheses and brackets
      else if (ch = 40) { tokens := vector_concat (tokens, vector (vector (1, '(', i))); i := i + 1; }
      else if (ch = 41) { tokens := vector_concat (tokens, vector (vector (2, ')', i))); i := i + 1; }
      else if (ch = 91) { tokens := vector_concat (tokens, vector (vector (3, '[', i))); i := i + 1; }
      else if (ch = 93) { tokens := vector_concat (tokens, vector (vector (4, ']', i))); i := i + 1; }
      else if (ch = 123) { tokens := vector_concat (tokens, vector (vector (5, '{', i))); i := i + 1; }
      else if (ch = 125) { tokens := vector_concat (tokens, vector (vector (6, '}', i))); i := i + 1; }
      -- Colon
      else if (ch = 58) { tokens := vector_concat (tokens, vector (vector (7, ':', i))); i := i + 1; }
      -- Dot or DotDot
      else if (ch = 46)
        {
          if (i + 1 < qlen and aref (_q, i + 1) = 46)
            { tokens := vector_concat (tokens, vector (vector (26, '..', i))); i := i + 2; }
          else
            { tokens := vector_concat (tokens, vector (vector (8, '.', i))); i := i + 1; }
        }
      -- Comma
      else if (ch = 44) { tokens := vector_concat (tokens, vector (vector (9, ',', i))); i := i + 1; }
      -- Dash, Arrow left component, or negative number start
      else if (ch = 45)
        {
          if (i + 1 < qlen and aref (_q, i + 1) = 62)
            { tokens := vector_concat (tokens, vector (vector (10, '->', i))); i := i + 2; }
          else
            { tokens := vector_concat (tokens, vector (vector (12, '-', i))); i := i + 1; }
        }
      -- Less-than, arrow-left, LTE, NEQ
      else if (ch = 60)
        {
          if (i + 1 < qlen and aref (_q, i + 1) = 45)
            { tokens := vector_concat (tokens, vector (vector (11, '<-', i))); i := i + 2; }
          else if (i + 1 < qlen and aref (_q, i + 1) = 62)
            { tokens := vector_concat (tokens, vector (vector (16, '<>', i))); i := i + 2; }
          else if (i + 1 < qlen and aref (_q, i + 1) = 61)
            { tokens := vector_concat (tokens, vector (vector (17, '<=', i))); i := i + 2; }
          else
            {
              iri_end := i + 1;
              while (iri_end < qlen and aref (_q, iri_end) <> 62 and aref (_q, iri_end) > 32)
                iri_end := iri_end + 1;
              if (iri_end < qlen and aref (_q, iri_end) = 62)
                {
                  tokens := vector_concat (tokens, vector (vector (56, subseq (_q, i + 1, iri_end), i)));
                  i := iri_end + 1;
                }
              else
                { tokens := vector_concat (tokens, vector (vector (13, '<', i))); i := i + 1; }
            }
        }
      -- Greater-than, GTE
      else if (ch = 62)
        {
          if (i + 1 < qlen and aref (_q, i + 1) = 61)
            { tokens := vector_concat (tokens, vector (vector (18, '>=', i))); i := i + 2; }
          else
            { tokens := vector_concat (tokens, vector (vector (14, '>', i))); i := i + 1; }
        }
      -- Equals
      else if (ch = 61) { tokens := vector_concat (tokens, vector (vector (15, '=', i))); i := i + 1; }
      -- Plus, PlusEquals
      else if (ch = 43)
        {
          if (i + 1 < qlen and aref (_q, i + 1) = 61)
            { tokens := vector_concat (tokens, vector (vector (27, '+=', i))); i := i + 2; }
          else
            { tokens := vector_concat (tokens, vector (vector (19, '+', i))); i := i + 1; }
        }
      -- Star
      else if (ch = 42) { tokens := vector_concat (tokens, vector (vector (20, '*', i))); i := i + 1; }
      -- Slash
      else if (ch = 47) { tokens := vector_concat (tokens, vector (vector (21, '/', i))); i := i + 1; }
      -- Percent
      else if (ch = 37) { tokens := vector_concat (tokens, vector (vector (22, '%', i))); i := i + 1; }
      -- Caret
      else if (ch = 94) { tokens := vector_concat (tokens, vector (vector (23, '^', i))); i := i + 1; }
      -- Bang (!)
      else if (ch = 33)
        {
          if (i + 1 < qlen and aref (_q, i + 1) = 61)
            { tokens := vector_concat (tokens, vector (vector (16, '!=', i))); i := i + 2; }
          else
            { tokens := vector_concat (tokens, vector (vector (24, '!', i))); i := i + 1; }
        }
      -- Pipe
      else if (ch = 124) { tokens := vector_concat (tokens, vector (vector (25, '|', i))); i := i + 1; }
      -- Dollar (parameter prefix)
      else if (ch = 36) { tokens := vector_concat (tokens, vector (vector (28, chr(36), i))); i := i + 1; }
      -- Ampersand (label-expression conjunction in openCypher 2024.3)
      else if (ch = 38) { tokens := vector_concat (tokens, vector (vector (29, '&', i))); i := i + 1; }
      -- Language tag (@en, @en-US)
      else if (ch = 64)
        {
          start_pos := i;
          i := i + 1;
          while (i < qlen
                 and ((aref (_q, i) >= 65 and aref (_q, i) <= 90)
                      or (aref (_q, i) >= 97 and aref (_q, i) <= 122)
                      or (aref (_q, i) >= 48 and aref (_q, i) <= 57)
                      or aref (_q, i) = 45))
            i := i + 1;
          tokens := vector_concat (tokens, vector (vector (57, subseq (_q, start_pos + 1, i), start_pos)));
        }
      -- String literal (single quote)
      else if (ch = 39)
        {
          start_pos := i;
          i := i + 1;
          val := '';
          while (i < qlen)
            {
              ch := aref (_q, i);
              if (ch = 92 and i + 1 < qlen)
                {
                  ch2 := aref (_q, i + 1);
                  if (ch2 = 39) { val := concat (val, ''''); i := i + 2; }
                  else if (ch2 = 92) { val := concat (val, '\\'); i := i + 2; }
                  else if (ch2 = 110) { val := concat (val, chr(10)); i := i + 2; }
                  else if (ch2 = 114) { val := concat (val, chr(13)); i := i + 2; }
                  else if (ch2 = 116) { val := concat (val, chr(9)); i := i + 2; }
                  else if (ch2 = 98) { val := concat (val, chr(8)); i := i + 2; }
                  else if (ch2 = 102) { val := concat (val, chr(12)); i := i + 2; }
                  else if (ch2 = 117)  -- \uXXXX
                    {
                      val := concat (val, DB.DBA.CYP_DECODE_UNICODE_ESCAPE (_q, i + 2, start_pos));
                      i := i + 6;
                    }
                  else { val := concat (val, chr (ch2)); i := i + 2; }
                }
              else if (ch = 39)
                {
                  if (i + 1 < qlen and aref (_q, i + 1) = 39)
                    { val := concat (val, chr(39)); i := i + 2; }
                  else
                    { i := i + 1; goto str_done_sq; }
                }
              else
                { val := concat (val, chr (ch)); i := i + 1; }
            }
          signal ('CY001', sprintf ('Unterminated string literal at position %d', start_pos));
          str_done_sq:
          tokens := vector_concat (tokens, vector (vector (51, val, start_pos)));
        }
      -- String literal (double quote)
      else if (ch = 34)
        {
          start_pos := i;
          i := i + 1;
          val := '';
          while (i < qlen)
            {
              ch := aref (_q, i);
              if (ch = 92 and i + 1 < qlen)
                {
                  ch2 := aref (_q, i + 1);
                  if (ch2 = 34) { val := concat (val, '"'); i := i + 2; }
                  else if (ch2 = 92) { val := concat (val, '\\'); i := i + 2; }
                  else if (ch2 = 110) { val := concat (val, chr(10)); i := i + 2; }
                  else if (ch2 = 114) { val := concat (val, chr(13)); i := i + 2; }
                  else if (ch2 = 116) { val := concat (val, chr(9)); i := i + 2; }
                  else if (ch2 = 98) { val := concat (val, chr(8)); i := i + 2; }
                  else if (ch2 = 102) { val := concat (val, chr(12)); i := i + 2; }
                  else if (ch2 = 117)  -- \uXXXX
                    {
                      val := concat (val, DB.DBA.CYP_DECODE_UNICODE_ESCAPE (_q, i + 2, start_pos));
                      i := i + 6;
                    }
                  else { val := concat (val, chr (ch2)); i := i + 2; }
                }
              else if (ch = 34)
                {
                  if (i + 1 < qlen and aref (_q, i + 1) = 34)
                    { val := concat (val, chr(34)); i := i + 2; }
                  else
                    { i := i + 1; goto str_done_dq; }
                }
              else
                { val := concat (val, chr (ch)); i := i + 1; }
            }
          signal ('CY001', sprintf ('Unterminated string literal at position %d', start_pos));
          str_done_dq:
          tokens := vector_concat (tokens, vector (vector (51, val, start_pos)));
        }
      -- Backtick-quoted identifier
      else if (ch = 96)
        {
          start_pos := i;
          i := i + 1;
          val := '';
          while (i < qlen and aref (_q, i) <> 96)
            {
              if (aref (_q, i) = 96 and i + 1 < qlen and aref (_q, i + 1) = 96)
                { val := concat (val, '`'); i := i + 2; }
              else
                { val := concat (val, chr (aref (_q, i))); i := i + 1; }
            }
          if (i >= qlen)
            signal ('CY001', sprintf ('Unterminated backtick identifier at position %d', start_pos));
          i := i + 1;
          tokens := vector_concat (tokens, vector (vector (50, val, start_pos)));
        }
      -- Number (integer or float)
      else if (DB.DBA.CYP_IS_DIGIT (ch))
        {
          start_pos := i;
          -- Check for hex: 0x...
          if (ch = 48 and i + 1 < qlen and (aref (_q, i + 1) = 120 or aref (_q, i + 1) = 88))
            {
              i := i + 2;
              while (i < qlen and (DB.DBA.CYP_IS_DIGIT (aref (_q, i))
                     or (aref (_q, i) >= 65 and aref (_q, i) <= 70)
                     or (aref (_q, i) >= 97 and aref (_q, i) <= 102)))
                i := i + 1;
              val := subseq (_q, start_pos, i);
              tokens := vector_concat (tokens, vector (vector (52, val, start_pos)));
            }
          -- Check for octal: 0o...
          else if (ch = 48 and i + 1 < qlen and (aref (_q, i + 1) = 111 or aref (_q, i + 1) = 79))
            {
              i := i + 2;
              while (i < qlen and aref (_q, i) >= 48 and aref (_q, i) <= 55)
                i := i + 1;
              val := subseq (_q, start_pos, i);
              tokens := vector_concat (tokens, vector (vector (52, val, start_pos)));
            }
          else
            {
              declare is_float integer;
              is_float := 0;
              while (i < qlen and DB.DBA.CYP_IS_DIGIT (aref (_q, i)))
                i := i + 1;
              if (i < qlen and aref (_q, i) = 46 and i + 1 < qlen and DB.DBA.CYP_IS_DIGIT (aref (_q, i + 1)))
                {
                  is_float := 1;
                  i := i + 1;
                  while (i < qlen and DB.DBA.CYP_IS_DIGIT (aref (_q, i)))
                    i := i + 1;
                }
              if (i < qlen and (aref (_q, i) = 101 or aref (_q, i) = 69))
                {
                  is_float := 1;
                  i := i + 1;
                  if (i < qlen and (aref (_q, i) = 43 or aref (_q, i) = 45))
                    i := i + 1;
                  while (i < qlen and DB.DBA.CYP_IS_DIGIT (aref (_q, i)))
                    i := i + 1;
                }
              val := subseq (_q, start_pos, i);
              if (is_float)
                tokens := vector_concat (tokens, vector (vector (53, val, start_pos)));
              else
                tokens := vector_concat (tokens, vector (vector (52, val, start_pos)));
            }
        }
      -- Identifier, keyword, or prefixed name
      else if (DB.DBA.CYP_IS_IDENT_START (ch))
        {
          start_pos := i;
          while (i < qlen and DB.DBA.CYP_IS_IDENT_CHAR (aref (_q, i)))
            i := i + 1;
          val := subseq (_q, start_pos, i);

          -- Check for prefixed name: ident:ident (e.g., foaf:Person)
          if (i < qlen and aref (_q, i) = 58 and i + 1 < qlen and DB.DBA.CYP_IS_IDENT_START (aref (_q, i + 1)))
            {
              -- Consume the colon
              i := i + 1;
              -- Consume the local name
              while (i < qlen and DB.DBA.CYP_IS_IDENT_CHAR (aref (_q, i)))
                i := i + 1;
              val := subseq (_q, start_pos, i);
              tokens := vector_concat (tokens, vector (vector (55, val, start_pos)));
            }
          else
            {
              kw := DB.DBA.CYP_KEYWORD (val);
              if (kw > 0)
                tokens := vector_concat (tokens, vector (vector (kw, val, start_pos)));
              else
                tokens := vector_concat (tokens, vector (vector (50, val, start_pos)));
            }
        }
      else
        {
          signal ('CY001', sprintf ('Unexpected character ''%s'' (code %d) at position %d', chr (ch), ch, i));
        }
    }

  -- Append EOF token
  tokens := vector_concat (tokens, vector (vector (999, '', qlen)));
  return tokens;
}
;

-- Get current token type at position
create procedure DB.DBA.CYP_PEEK (in _tokens any, in _pos integer)
{
  if (_pos >= length (_tokens))
    return 999;
  return aref (aref (_tokens, _pos), 0);
}
;

-- Get current token value at position
create procedure DB.DBA.CYP_PEEK_VAL (in _tokens any, in _pos integer)
{
  if (_pos >= length (_tokens))
    return '';
  return aref (aref (_tokens, _pos), 1);
}
;

-- Check if current token matches expected type
create procedure DB.DBA.CYP_CHECK (in _tokens any, in _pos integer, in _type integer)
{
  if (DB.DBA.CYP_PEEK (_tokens, _pos) = _type)
    return 1;
  return 0;
}
;

-- Consume expected token or signal error
create procedure DB.DBA.CYP_EXPECT (in _tokens any, inout _pos integer, in _type integer)
{
  declare actual integer;
  actual := DB.DBA.CYP_PEEK (_tokens, _pos);
  if (actual <> _type)
    signal ('CY002', sprintf ('Expected token type %d but got %d (''%s'') at position %d',
            _type, actual, DB.DBA.CYP_PEEK_VAL (_tokens, _pos), _pos));
  _pos := _pos + 1;
}
;

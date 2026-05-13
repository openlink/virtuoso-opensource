/*
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2026 OpenLink Software
 *
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */

/*
 *  openCypher plugin lexer
 *
 *  Initial C tokenizer scaffold mirroring binsrc/cypher/cypher_lexer.sql.
 */

#include "opencypher_lexer.h"
#include "opencypher_box.h"

#include <stdio.h>
#include <string.h>

typedef struct opencypher_lexer_s
{
  opencypher_arena_t *arena;
  const char *query;
  long len;
  long i;
  long line;
  long col;
  opencypher_token_stream_t *tokens;
} opencypher_lexer_t;

static int
opencypher_is_ident_start (int ch)
{
  return ((ch >= 'A' && ch <= 'Z')
          || (ch >= 'a' && ch <= 'z')
          || ch == '_');
}

static int
opencypher_is_ident_char (int ch)
{
  return opencypher_is_ident_start (ch) || (ch >= '0' && ch <= '9');
}

static int
opencypher_is_digit (int ch)
{
  return ch >= '0' && ch <= '9';
}

static int
opencypher_keyword (const char *text, size_t len)
{
  struct keyword_s { const char *name; int token; };
  static const struct keyword_s keywords[] = {
    { "MATCH", 100 }, { "OPTIONAL", 101 }, { "WHERE", 102 },
    { "RETURN", 103 }, { "CREATE", 104 }, { "DELETE", 105 },
    { "DETACH", 106 }, { "SET", 107 }, { "REMOVE", 108 },
    { "MERGE", 109 }, { "WITH", 110 }, { "UNWIND", 111 },
    { "AS", 112 }, { "ORDER", 113 }, { "BY", 114 },
    { "ASC", 115 }, { "DESC", 116 }, { "SKIP", 117 }, { "OFFSET", 117 },
    { "LIMIT", 118 }, { "UNION", 119 }, { "ALL", 120 },
    { "DISTINCT", 121 }, { "AND", 122 }, { "OR", 123 },
    { "NOT", 124 }, { "XOR", 125 }, { "IN", 126 },
    { "IS", 127 }, { "NULL", 128 }, { "TRUE", 129 },
    { "FALSE", 130 }, { "STARTS", 131 }, { "ENDS", 132 },
    { "CONTAINS", 133 }, { "ON", 134 }, { "CASE", 135 },
    { "WHEN", 136 }, { "THEN", 137 }, { "ELSE", 138 },
    { "END", 139 }, { "EXISTS", 140 }, { "COUNT", 141 },
    { "CALL", 142 }, { "YIELD", 143 }, { "ASCENDING", 144 },
    { "DESCENDING", 145 }, { "SHORTESTPATH", 146 },
    { "ALLSHORTESTPATHS", 147 }, { "REDUCE", 148 },
    { "SINGLE", 149 }, { "ANY", 150 }, { "NONE", 151 },
    { "TRIM", 152 }, { "PREFIX", 153 }, { "GRAPH", 154 },
    { "INTO", 155 }, { "FROM", 156 }, { "DEFINE", 157 },
    { "NAMED", 158 }, { "SERVICE", 159 }, { "VALUES", 160 },
    { "BIND", 161 }, { "MINUS", 162 }, { "GROUP", 163 },
    { "HAVING", 164 }, { "ASK", 165 }, { "CONSTRUCT", 166 },
    { "DESCRIBE", 167 }, { "LOAD", 168 }, { "CLEAR", 169 },
    { "DROP", 170 }, { "ADD", 171 }, { "MOVE", 172 },
    { "COPY", 173 }, { "SILENT", 174 }, { "DEFAULT", 175 },
    { "TO", 176 }, { "USING", 177 }, { "INSERT", 178 },
    { "DATA", 179 }, { "SHORTEST", 180 }, { "GROUPS", 181 },
    { "BASE", 182 }
  };
  size_t k;

  for (k = 0; k < sizeof (keywords) / sizeof (keywords[0]); k++)
    {
      size_t j;
      if (strlen (keywords[k].name) != len)
        continue;
      for (j = 0; j < len; j++)
        {
          char c = text[j];
          if (c >= 'a' && c <= 'z')
            c = (char) (c - 'a' + 'A');
          if (c != keywords[k].name[j])
            break;
        }
      if (j == len)
        return keywords[k].token;
    }

  return 0;
}

static caddr_t
opencypher_lexer_error (const char *text, long pos)
{
  char buf[256];
  snprintf (buf, sizeof (buf), "%s at position %ld", text, pos);
  return box_dv_short_string (buf);
}

static int
opencypher_peek (const opencypher_lexer_t *lx, long offset)
{
  long pos = lx->i + offset;
  if (pos >= lx->len)
    return 0;
  return (unsigned char) lx->query[pos];
}

static void
opencypher_advance (opencypher_lexer_t *lx)
{
  int ch = opencypher_peek (lx, 0);
  lx->i++;
  if (ch == '\n')
    {
      lx->line++;
      lx->col = 1;
    }
  else
    lx->col++;
}

static void
opencypher_advance_n (opencypher_lexer_t *lx, long n)
{
  while (n-- > 0)
    opencypher_advance (lx);
}

static void
opencypher_add_token (opencypher_lexer_t *lx, int type, const char *value,
                 long pos, long line, long col)
{
  opencypher_token_t *tok = (opencypher_token_t *)
    opencypher_arena_alloc (lx->arena, sizeof (opencypher_token_t));
  tok->type = type;
  tok->value = value;
  tok->pos = pos;
  tok->line = line;
  tok->col = col;
  tok->next = NULL;

  if (lx->tokens->tail)
    lx->tokens->tail->next = tok;
  else
    lx->tokens->head = tok;
  lx->tokens->tail = tok;
  lx->tokens->count++;
}

static const char *
opencypher_literal (opencypher_arena_t *arena, const char *text)
{
  return opencypher_arena_strndup (arena, text, strlen (text));
}

static int
opencypher_scan_string (opencypher_lexer_t *lx, int quote, caddr_t *error_msg)
{
  long start = lx->i;
  long line = lx->line;
  long col = lx->col;
  char *buf = (char *) opencypher_arena_alloc (lx->arena, (size_t) lx->len + 1);
  long out = 0;

  opencypher_advance (lx);
  while (lx->i < lx->len)
    {
      int ch = opencypher_peek (lx, 0);

      if (ch == '\\' && lx->i + 1 < lx->len)
        {
          int ch2 = opencypher_peek (lx, 1);
          if (ch2 == quote) buf[out++] = (char) quote;
          else if (ch2 == '\\') buf[out++] = '\\';
          else if (ch2 == 'n') buf[out++] = '\n';
          else if (ch2 == 'r') buf[out++] = '\r';
          else if (ch2 == 't') buf[out++] = '\t';
          else if (ch2 == 'b') buf[out++] = '\b';
          else if (ch2 == 'f') buf[out++] = '\f';
          else if (ch2 == 'u')
            {
              int hi, hd, cp = 0;
              if (lx->i + 5 >= lx->len)
                {
                  *error_msg = opencypher_lexer_error ("Truncated \\u escape in string literal", start);
                  return -1;
                }
              for (hi = 0; hi < 4; hi++)
                {
                  int hc = opencypher_peek (lx, 2 + hi);
                  if (hc >= '0' && hc <= '9') hd = hc - '0';
                  else if (hc >= 'A' && hc <= 'F') hd = hc - 'A' + 10;
                  else if (hc >= 'a' && hc <= 'f') hd = hc - 'a' + 10;
                  else
                    {
                      *error_msg = opencypher_lexer_error ("Invalid hex digit in \\u escape", start);
                      return -1;
                    }
                  cp = cp * 16 + hd;
                }
              if (cp < 0x80)
                buf[out++] = (char) cp;
              else if (cp < 0x800)
                {
                  buf[out++] = (char) (0xC0 | (cp >> 6));
                  buf[out++] = (char) (0x80 | (cp & 0x3F));
                }
              else
                {
                  buf[out++] = (char) (0xE0 | (cp >> 12));
                  buf[out++] = (char) (0x80 | ((cp >> 6) & 0x3F));
                  buf[out++] = (char) (0x80 | (cp & 0x3F));
                }
              opencypher_advance_n (lx, 6);
              continue;
            }
          else buf[out++] = (char) ch2;
          opencypher_advance_n (lx, 2);
        }
      else if (ch == quote)
        {
          if (lx->i + 1 < lx->len && opencypher_peek (lx, 1) == quote)
            {
              buf[out++] = (char) quote;
              opencypher_advance_n (lx, 2);
            }
          else
            {
              opencypher_advance (lx);
              buf[out] = '\0';
              opencypher_add_token (lx, OPENCYPHER_T_STRING, buf, start, line, col);
              return 0;
            }
        }
      else
        {
          buf[out++] = (char) ch;
          opencypher_advance (lx);
        }
    }

  *error_msg = opencypher_lexer_error ("Unterminated string literal", start);
  return -1;
}

static int
opencypher_scan_backtick (opencypher_lexer_t *lx, caddr_t *error_msg)
{
  long start = lx->i;
  long line = lx->line;
  long col = lx->col;
  char *buf = (char *) opencypher_arena_alloc (lx->arena, (size_t) lx->len + 1);
  long out = 0;

  opencypher_advance (lx);
  while (lx->i < lx->len)
    {
      int ch = opencypher_peek (lx, 0);
      if (ch == '`')
        {
          if (lx->i + 1 < lx->len && opencypher_peek (lx, 1) == '`')
            {
              buf[out++] = '`';
              opencypher_advance_n (lx, 2);
            }
          else
            {
              opencypher_advance (lx);
              buf[out] = '\0';
              opencypher_add_token (lx, OPENCYPHER_T_IDENT, buf, start, line, col);
              return 0;
            }
        }
      else
        {
          buf[out++] = (char) ch;
          opencypher_advance (lx);
        }
    }

  *error_msg = opencypher_lexer_error ("Unterminated backtick identifier", start);
  return -1;
}

static void
opencypher_scan_number (opencypher_lexer_t *lx)
{
  long start = lx->i;
  long line = lx->line;
  long col = lx->col;
  int is_float = 0;

  if (opencypher_peek (lx, 0) == '0'
      && (opencypher_peek (lx, 1) == 'x' || opencypher_peek (lx, 1) == 'X'))
    {
      opencypher_advance_n (lx, 2);
      while (opencypher_is_digit (opencypher_peek (lx, 0))
             || (opencypher_peek (lx, 0) >= 'A' && opencypher_peek (lx, 0) <= 'F')
             || (opencypher_peek (lx, 0) >= 'a' && opencypher_peek (lx, 0) <= 'f'))
        opencypher_advance (lx);
      opencypher_add_token (lx, OPENCYPHER_T_INTEGER,
                       opencypher_arena_strndup (lx->arena, lx->query + start,
                                            (size_t) (lx->i - start)),
                       start, line, col);
      return;
    }

  while (opencypher_is_digit (opencypher_peek (lx, 0)))
    opencypher_advance (lx);
  if (opencypher_peek (lx, 0) == '.'
      && opencypher_is_digit (opencypher_peek (lx, 1)))
    {
      is_float = 1;
      opencypher_advance (lx);
      while (opencypher_is_digit (opencypher_peek (lx, 0)))
        opencypher_advance (lx);
    }
  if (opencypher_peek (lx, 0) == 'e' || opencypher_peek (lx, 0) == 'E')
    {
      is_float = 1;
      opencypher_advance (lx);
      if (opencypher_peek (lx, 0) == '+' || opencypher_peek (lx, 0) == '-')
        opencypher_advance (lx);
      while (opencypher_is_digit (opencypher_peek (lx, 0)))
        opencypher_advance (lx);
    }

  opencypher_add_token (lx, is_float ? OPENCYPHER_T_FLOAT : OPENCYPHER_T_INTEGER,
                   opencypher_arena_strndup (lx->arena, lx->query + start,
                                        (size_t) (lx->i - start)),
                   start, line, col);
}

static void
opencypher_scan_identifier (opencypher_lexer_t *lx)
{
  long start = lx->i;
  long line = lx->line;
  long col = lx->col;
  int kw;

  while (opencypher_is_ident_char (opencypher_peek (lx, 0)))
    opencypher_advance (lx);

  if (opencypher_peek (lx, 0) == ':'
      && opencypher_is_ident_start (opencypher_peek (lx, 1)))
    {
      opencypher_advance (lx);
      while (opencypher_is_ident_char (opencypher_peek (lx, 0)))
        opencypher_advance (lx);
      opencypher_add_token (lx, OPENCYPHER_T_PNAME_NS,
                       opencypher_arena_strndup (lx->arena, lx->query + start,
                                            (size_t) (lx->i - start)),
                       start, line, col);
      return;
    }

  kw = opencypher_keyword (lx->query + start, (size_t) (lx->i - start));
  opencypher_add_token (lx, kw ? kw : OPENCYPHER_T_IDENT,
                   opencypher_arena_strndup (lx->arena, lx->query + start,
                                        (size_t) (lx->i - start)),
                   start, line, col);
}

int
opencypher_lexer_tokenize (opencypher_arena_t *arena,
                      const char *query,
                      opencypher_token_stream_t *tokens,
                      caddr_t *error_msg)
{
  opencypher_lexer_t lx;

  lx.arena = arena;
  lx.query = query;
  lx.len = (long) strlen (query);
  lx.i = 0;
  lx.line = 1;
  lx.col = 1;
  lx.tokens = tokens;
  tokens->head = NULL;
  tokens->tail = NULL;
  tokens->count = 0;

  while (lx.i < lx.len)
    {
      int ch = opencypher_peek (&lx, 0);
      long start = lx.i;
      long line = lx.line;
      long col = lx.col;

      if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r')
        {
          opencypher_advance (&lx);
        }
      else if (ch == '/' && opencypher_peek (&lx, 1) == '/')
        {
          opencypher_advance_n (&lx, 2);
          while (lx.i < lx.len && opencypher_peek (&lx, 0) != '\n')
            opencypher_advance (&lx);
        }
      else if (ch == '(') { opencypher_add_token (&lx, 1, opencypher_literal (arena, "("), start, line, col); opencypher_advance (&lx); }
      else if (ch == ')') { opencypher_add_token (&lx, 2, opencypher_literal (arena, ")"), start, line, col); opencypher_advance (&lx); }
      else if (ch == '[') { opencypher_add_token (&lx, 3, opencypher_literal (arena, "["), start, line, col); opencypher_advance (&lx); }
      else if (ch == ']') { opencypher_add_token (&lx, 4, opencypher_literal (arena, "]"), start, line, col); opencypher_advance (&lx); }
      else if (ch == '{') { opencypher_add_token (&lx, 5, opencypher_literal (arena, "{"), start, line, col); opencypher_advance (&lx); }
      else if (ch == '}') { opencypher_add_token (&lx, 6, opencypher_literal (arena, "}"), start, line, col); opencypher_advance (&lx); }
      else if (ch == ':') { opencypher_add_token (&lx, 7, opencypher_literal (arena, ":"), start, line, col); opencypher_advance (&lx); }
      else if (ch == ',') { opencypher_add_token (&lx, 9, opencypher_literal (arena, ","), start, line, col); opencypher_advance (&lx); }
      else if (ch == '=') { opencypher_add_token (&lx, 15, opencypher_literal (arena, "="), start, line, col); opencypher_advance (&lx); }
      else if (ch == '*') { opencypher_add_token (&lx, 20, opencypher_literal (arena, "*"), start, line, col); opencypher_advance (&lx); }
      else if (ch == '/') { opencypher_add_token (&lx, 21, opencypher_literal (arena, "/"), start, line, col); opencypher_advance (&lx); }
      else if (ch == '%') { opencypher_add_token (&lx, 22, opencypher_literal (arena, "%"), start, line, col); opencypher_advance (&lx); }
      else if (ch == '^') { opencypher_add_token (&lx, 23, opencypher_literal (arena, "^"), start, line, col); opencypher_advance (&lx); }
      else if (ch == '|') { opencypher_add_token (&lx, 25, opencypher_literal (arena, "|"), start, line, col); opencypher_advance (&lx); }
      else if (ch == '$') { opencypher_add_token (&lx, 28, opencypher_literal (arena, "$"), start, line, col); opencypher_advance (&lx); }
      else if (ch == '&') { opencypher_add_token (&lx, 29, opencypher_literal (arena, "&"), start, line, col); opencypher_advance (&lx); }
      else if (ch == '.')
        {
          if (opencypher_peek (&lx, 1) == '.')
            { opencypher_add_token (&lx, 26, opencypher_literal (arena, ".."), start, line, col); opencypher_advance_n (&lx, 2); }
          else
            { opencypher_add_token (&lx, 8, opencypher_literal (arena, "."), start, line, col); opencypher_advance (&lx); }
        }
      else if (ch == '-')
        {
          if (opencypher_peek (&lx, 1) == '>')
            { opencypher_add_token (&lx, 10, opencypher_literal (arena, "->"), start, line, col); opencypher_advance_n (&lx, 2); }
          else
            { opencypher_add_token (&lx, 12, opencypher_literal (arena, "-"), start, line, col); opencypher_advance (&lx); }
        }
      else if (ch == '<')
        {
          if (opencypher_peek (&lx, 1) == '-')
            { opencypher_add_token (&lx, 11, opencypher_literal (arena, "<-"), start, line, col); opencypher_advance_n (&lx, 2); }
          else if (opencypher_peek (&lx, 1) == '>')
            { opencypher_add_token (&lx, 16, opencypher_literal (arena, "<>"), start, line, col); opencypher_advance_n (&lx, 2); }
          else if (opencypher_peek (&lx, 1) == '=')
            { opencypher_add_token (&lx, 17, opencypher_literal (arena, "<="), start, line, col); opencypher_advance_n (&lx, 2); }
          else
            {
              long iri = lx.i + 1;
              while (iri < lx.len && lx.query[iri] != '>' && (unsigned char) lx.query[iri] > 32)
                iri++;
              if (iri < lx.len && lx.query[iri] == '>')
                {
                  opencypher_add_token (&lx, 56,
                                   opencypher_arena_strndup (arena, lx.query + lx.i + 1,
                                                        (size_t) (iri - lx.i - 1)),
                                   start, line, col);
                  opencypher_advance_n (&lx, iri - lx.i + 1);
                }
              else
                { opencypher_add_token (&lx, 13, opencypher_literal (arena, "<"), start, line, col); opencypher_advance (&lx); }
            }
        }
      else if (ch == '>')
        {
          if (opencypher_peek (&lx, 1) == '=')
            { opencypher_add_token (&lx, 18, opencypher_literal (arena, ">="), start, line, col); opencypher_advance_n (&lx, 2); }
          else
            { opencypher_add_token (&lx, 14, opencypher_literal (arena, ">"), start, line, col); opencypher_advance (&lx); }
        }
      else if (ch == '+')
        {
          if (opencypher_peek (&lx, 1) == '=')
            { opencypher_add_token (&lx, 27, opencypher_literal (arena, "+="), start, line, col); opencypher_advance_n (&lx, 2); }
          else
            { opencypher_add_token (&lx, 19, opencypher_literal (arena, "+"), start, line, col); opencypher_advance (&lx); }
        }
      else if (ch == '!')
        {
          if (opencypher_peek (&lx, 1) == '=')
            { opencypher_add_token (&lx, 16, opencypher_literal (arena, "!="), start, line, col); opencypher_advance_n (&lx, 2); }
          else
            { opencypher_add_token (&lx, 24, opencypher_literal (arena, "!"), start, line, col); opencypher_advance (&lx); }
        }
      else if (ch == '@')
        {
          opencypher_advance (&lx);
          while ((opencypher_peek (&lx, 0) >= 'A' && opencypher_peek (&lx, 0) <= 'Z')
                 || (opencypher_peek (&lx, 0) >= 'a' && opencypher_peek (&lx, 0) <= 'z')
                 || (opencypher_peek (&lx, 0) >= '0' && opencypher_peek (&lx, 0) <= '9')
                 || opencypher_peek (&lx, 0) == '-')
            opencypher_advance (&lx);
          opencypher_add_token (&lx, 57,
                           opencypher_arena_strndup (arena, lx.query + start + 1,
                                                (size_t) (lx.i - start - 1)),
                           start, line, col);
        }
      else if (ch == '\'' || ch == '"')
        {
          if (opencypher_scan_string (&lx, ch, error_msg) != 0)
            return -1;
        }
      else if (ch == '`')
        {
          if (opencypher_scan_backtick (&lx, error_msg) != 0)
            return -1;
        }
      else if (opencypher_is_digit (ch))
        opencypher_scan_number (&lx);
      else if (opencypher_is_ident_start (ch))
        opencypher_scan_identifier (&lx);
      else
        {
          char buf[128];
          snprintf (buf, sizeof (buf), "Unexpected character '%c' (code %d)",
                    ch, ch);
          *error_msg = opencypher_lexer_error (buf, start);
          return -1;
        }
    }

  opencypher_add_token (&lx, 999, opencypher_literal (arena, ""), lx.len, lx.line, lx.col);
  return 0;
}

caddr_t
opencypher_lexer_tokens_to_box (const opencypher_token_stream_t *tokens)
{
  caddr_t *arr;
  const opencypher_token_t *tok;
  long i = 0;

  arr = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * tokens->count,
                                  DV_ARRAY_OF_POINTER);
  for (tok = tokens->head; tok; tok = tok->next)
    arr[i++] = opencypher_box_token (tok->type, tok->value,
                                tok->pos, tok->line, tok->col);

  return (caddr_t) arr;
}

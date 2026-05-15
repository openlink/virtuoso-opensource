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
 */

#ifndef _OPENCYPHER_LEXER_H
#define _OPENCYPHER_LEXER_H

#include "import_gate_virtuoso.h"
#include "opencypher_arena.h"

enum opencypher_token_type
{
  OPENCYPHER_T_LPAREN = 1,
  OPENCYPHER_T_RPAREN = 2,
  OPENCYPHER_T_LBRACKET = 3,
  OPENCYPHER_T_RBRACKET = 4,
  OPENCYPHER_T_LBRACE = 5,
  OPENCYPHER_T_RBRACE = 6,
  OPENCYPHER_T_COLON = 7,
  OPENCYPHER_T_DOT = 8,
  OPENCYPHER_T_COMMA = 9,
  OPENCYPHER_T_ARROW_R = 10,
  OPENCYPHER_T_ARROW_L = 11,
  OPENCYPHER_T_DASH = 12,
  OPENCYPHER_T_LT = 13,
  OPENCYPHER_T_GT = 14,
  OPENCYPHER_T_EQ = 15,
  OPENCYPHER_T_NEQ = 16,
  OPENCYPHER_T_LTE = 17,
  OPENCYPHER_T_GTE = 18,
  OPENCYPHER_T_PLUS = 19,
  OPENCYPHER_T_STAR = 20,
  OPENCYPHER_T_SLASH = 21,
  OPENCYPHER_T_PERCENT = 22,
  OPENCYPHER_T_CARET = 23,
  OPENCYPHER_T_BANG = 24,
  OPENCYPHER_T_PIPE = 25,
  OPENCYPHER_T_DOTDOT = 26,
  OPENCYPHER_T_PLUSEQ = 27,
  OPENCYPHER_T_DOLLAR = 28,
  OPENCYPHER_T_IDENT = 50,
  OPENCYPHER_T_STRING = 51,
  OPENCYPHER_T_INTEGER = 52,
  OPENCYPHER_T_FLOAT = 53,
  OPENCYPHER_T_PNAME_NS = 55,
  OPENCYPHER_T_IRIREF = 56,
  OPENCYPHER_T_LANGTAG = 57,
  OPENCYPHER_T_EOF = 999
};

typedef struct opencypher_token_s
{
  int type;
  const char *value;
  long pos;
  long line;
  long col;
  struct opencypher_token_s *next;
} opencypher_token_t;

typedef struct opencypher_token_stream_s
{
  opencypher_token_t *head;
  opencypher_token_t *tail;
  long count;
} opencypher_token_stream_t;

int opencypher_lexer_tokenize (opencypher_arena_t *arena,
                          const char *query,
                          opencypher_token_stream_t *tokens,
                          caddr_t *error_msg);

caddr_t opencypher_lexer_tokens_to_box (const opencypher_token_stream_t *tokens);

#endif /* _OPENCYPHER_LEXER_H */

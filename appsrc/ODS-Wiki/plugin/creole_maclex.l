%{
/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#ifndef MLEX_TEST
#ifdef _USRDLL
#include "import_gate_virtuoso.h"
#else
#include "Dk.h"
#endif
#endif

#define MAXMACRODEPTH 5
typedef struct mlex_state_s {
  YY_BUFFER_STATE stack[MAXMACRODEPTH];
  int depth;
#ifndef MLEX_TEST
  char * mlex_text;
  int mlex_text_len;
  int mlex_text_ofs;
  dk_session_t *mlex_out;
#endif
  } mlex_state_t;

extern char * creole_mlex_macro_resolver (char *call);

#ifdef MLEX_TEST
#define mlex_alloc(n) malloc(n)
#define mlex_free(p,n) free(p)
#else
#define mlex_alloc(n) dk_alloc(n)
#define mlex_free(p,n) dk_free(p,n)
#endif

mlex_state_t mlex_instance;
#define STATE(n) (mlex_instance.n)
#define STATEPTR (&mlex_instance)

#ifdef MLEX_TEST
#define PRINT(strg) printf("%s", (strg))
#else
#define PRINT(strg) session_buffered_write (STATE(mlex_out), (strg), strlen(strg))
#endif

#ifdef MLEX_TEST
#define NPRINT(strg,len) fwrite ((strg), len, 1, stdout)
#else
#define NPRINT(strg,len) session_buffered_write (STATE(mlex_out), (strg), len)
#endif

#define LEXERROR(strg) \
  do { \
    PRINT("\n<!-- SyntError: "); \
    PRINT(strg); PRINT("\n"); \
    PRINT(yytext); PRINT(" -->\n"); \
    } while(0);

#ifndef MLEX_TEST
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
  do \
    { \
      int rest_len = STATE(mlex_text_len) - STATE(mlex_text_ofs); \
      int get_len = (max_size); \
      if (get_len > rest_len) \
	get_len = rest_len; \
      memcpy ((buf), (STATE(mlex_text) + STATE(mlex_text_ofs)), get_len); \
      (result) = get_len; \
      STATE(mlex_text_ofs) += get_len; \
    } while (0);
#endif

%}

%x VERBATIM

WS		([ \t]+)
S_NL		((\r)?(\n)(\r)?)
WS_NL		({WS}?{S_NL})
MACRONAME	([A-Z]+(":"[A-Z]+)?)
MACROARGNAME	([a-z]+)
MACROARGVALUE	("\""[A-Za-z0-9_.:;|\\/?+%&'` \t-]*"\"")
MACROARG	(({MACROARGNAME}"=")?{MACROARGVALUE})
MACROARGS	({WS}?({MACROARG}({WS}{MACROARG})*{WS}?)?)
%%

<INITIAL>^({WS}?)"<verbatim>"{WS_NL}	{ BEGIN(VERBATIM); PRINT(yytext); }
<VERBATIM>^({WS}?)"</verbatim>"{WS_NL}	{ BEGIN(INITIAL); PRINT(yytext); }
<VERBATIM>.*				{ PRINT(yytext); }
<VERBATIM>[\r\n]			{ PRINT(yytext); }

	/* Variables */
<INITIAL>"%"{MACRONAME}"%"	{ do {
	char *tail;
	char *repl = creole_mlex_macro_resolver (yytext);
	if (NULL == repl)
	  {
	    PRINT(yytext);
	    break;
	  }
	tail = strchr (repl, '%');
	if ((NULL == tail) || (STATE(depth) >= MAXMACRODEPTH))
	  {
	    PRINT(repl);
	    break;
	  }
	STATE(stack)[STATE(depth)] = YY_CURRENT_BUFFER;
	STATE(depth) += 1;
	yy_scan_string (repl);
	} while (0); }

<INITIAL>[^%\r\n]+	{ PRINT(yytext); }
<INITIAL>[\r\n]+	{ PRINT(yytext); }
<INITIAL>"%"		{ PRINT(yytext); }

<*><<EOF>> {
      if (STATE(depth) <= 0)
        return 0;
      STATE(depth) -= 1;
      yy_delete_buffer (YY_CURRENT_BUFFER);
      yy_switch_to_buffer (STATE(stack)[STATE(depth)]);
    }

%%

int
creolemacyywrap (void)
{
  return (1);
}

#ifdef MLEX_TEST

char * mlex_macro_resolver (char *call)
{
  if (!strcmp (call, "%A%"))
    return "Test A";
  if (!strcmp (call, "%B%"))
    return "Test B: (%A% %A%)";
  if (!strcmp (call, "%C%"))
    return "";
  if (!strcmp (call, "%D%"))
    return "Test D: (%D%)";
  return NULL;
}

int main(int argc, char *argv[])
{
  if (argc > 1)
    yyin = fopen (argv[1], "r");
  creolemacyylex();
  return 0;
}
#else
void creolemacyylex_prepare (char *text, dk_session_t *out)
{
  memset (&mlex_instance, 0, sizeof (mlex_instance));
  STATE (mlex_text) = text;
  STATE (mlex_text_len) = strlen(text);
  STATE (mlex_out) = out;
  BEGIN(INITIAL);
}
#endif

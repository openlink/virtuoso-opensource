/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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

%option 8bit
%option never-interactive
%option nounput
%{
#include <ctype.h>
#include "Dk.h"
#include "numeric.h"
#include "sqlfn.h"
#include "json_p.h"

void jsonyyerror_impl(const char *s);
int jsonyy_string_input (char *buf, int max);
#undef YY_INPUT
#define YY_INPUT(buf, res, max) \
  res = jsonyy_string_input (buf, max);
#define jsonyyerror(str) jsonyyerror_impl(str)

struct sparp_s; /* forward */
extern caddr_t spar_strliteral (struct sparp_s *sparp, const char *strg, int strg_is_long, int is_json);
extern int json_line;
%}

%x STRLIT

HEX             ([0-9A-Fa-f])

%%

<INITIAL>"{"	{ return OBJ_BEGIN; }
<INITIAL>"}"	{ return OBJ_END; }
<INITIAL>"["	{ return ARR_BEGIN; }
<INITIAL>"]"	{ return ARR_END; }
<INITIAL>":"	{ return COLON; }
<INITIAL>","	{ return COMMA; }
<INITIAL>"\""[^\\\"\n\r\t]*	{ yymore(); BEGIN(STRLIT); }

<INITIAL>"\""[^\\\"\n\r\t]*"\"" 	{
                   jsonyylval.box = t_box_dv_short_nchars (jsonyytext+1, strlen (jsonyytext)-2);
		   return STRING;
		}

<STRLIT>[^\\\"\n\r\t]*"\"" 	{
		   BEGIN(INITIAL);
		   jsonyylval.box = spar_strliteral (NULL /* no sparp for JSON_LITERAL */, jsonyytext, 0, 1);
		   return STRING;
		}

<STRLIT>"\\"([\\\"bfnrt/]|(u{HEX}{HEX}{HEX}{HEX})) { yymore (); }
<STRLIT>[^\\\"\n\r\t]* { yymore (); }
<STRLIT>[\n\r]	{ jsonyyerror ("line break is not allowed in JSON strings"); }
<STRLIT>"\t"	{ jsonyyerror ("tab character is not allowed in JSON strings"); }
<STRLIT>"\\"	{ jsonyyerror ("invalid escaping sequence in a string"); }

<INITIAL>true	{ return TRUE_L; }
<INITIAL>false	{ return FALSE_L; }
<INITIAL>null	{ return NULL_L; }

<INITIAL>"-"?(([1-9][0-9]*)|"0")	{
		  caddr_t err = NULL;
                  int64 n = safe_atoi (jsonyytext, &err);
		  if (err)
                    {
		      dk_free_tree (err);
                      jsonyyerror ("bad integer constant");
		    }
                  jsonyylval.box = t_box_num_and_zero (n);
		  return NUMBER;
		}
<INITIAL>"-"?[0-9]+"."[0-9]* |
<INITIAL>"-"?"."[0-9]+ {
  numeric_t num = t_numeric_allocate ();
  int rc = numeric_from_string (num, jsonyytext);
  if (NUMERIC_STS_SUCCESS == rc)
    {
      jsonyylval.box = (caddr_t) num;
      return NUMBER;
    }
  jsonyylval.box = t_box_double (atof (jsonyytext));
  return NUMBER;
}

<INITIAL>"-"?[0-9]+[eE][+-]?[0-9]+	|
<INITIAL>"-"?[0-9]+"."[0-9]+[eE][+-]?[0-9]+ |
<INITIAL>"-"?"."[0-9]+[eE][+-]?[0-9]+	{
  jsonyylval.box = t_box_double (atof (jsonyytext));
  return NUMBER;
}

<INITIAL>[+-]?[0-9.eE+-]+ { jsonyyerror ("syntax error in number"); }

<INITIAL>[ \r\t]+
<INITIAL>"#"([^\n]*)[\n]   { json_line++; }
<INITIAL>[\n]   { json_line++; }
<INITIAL>.	{ jsonyyerror ("character outside string"); }


%%

void jsonyy_reset (void)
{
  json_line = 1;
  jsonyyrestart (NULL);
  BEGIN INITIAL;
}

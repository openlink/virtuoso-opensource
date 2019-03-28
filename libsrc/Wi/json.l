/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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
%option noyywrap
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
#define SPAR_STRLITERAL_SPARQL_STRING	0
#define SPAR_STRLITERAL_JSON_STRING	1
#define SPAR_STRLITERAL_SPARQL_QNAME	2
extern caddr_t spar_unescape_strliteral (struct sparp_s *sparp, const char *strg, int count_of_quotes, int mode);
extern int json_line;
%}

%x STRLIT

HEX             ([0-9A-Fa-f])

%%

<INITIAL>[\xef][\xbb][\xbf]			{ }
<INITIAL>(([\xfe][\xff])|([\xff][\xfe]))	{ jsonyyerror ("The document contains the BOM (Byte Order Mark) of the UTF-16 encoding but only UTF-8 is supported by this parser"); }
<INITIAL>[\xf7][\x64][\x4c]			{ jsonyyerror ("The document contains the BOM (Byte Order Mark) of the UTF-1 encoding but only UTF-8 is supported by this parser"); }
<INITIAL>[\xdd][\x73][\x66][\x73]		{ jsonyyerror ("The document contains the BOM (Byte Order Mark) of the UTF-EBCDIC encoding but only UTF-8 is supported by this parser"); }
<INITIAL>[\x0e][\xfe][\xff]			{ jsonyyerror ("The document contains the BOM (Byte Order Mark) of the SCSU encoding but only UTF-8 is supported by this parser"); }
<INITIAL>[\xfb][\xee][\x28]			{ jsonyyerror ("The document contains the BOM (Byte Order Mark) of the BOCU-1 encoding but only UTF-8 is supported by this parser"); }
<INITIAL>[\x84][\x31][\x95][\x33]		{ jsonyyerror ("The document contains the BOM (Byte Order Mark) of the GB-18030 encoding but only UTF-8 is supported by this parser"); }

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
                   jsonyylval.box = spar_unescape_strliteral (NULL /* no sparp for JSON_LITERAL */, jsonyytext, 1, SPAR_STRLITERAL_JSON_STRING);
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

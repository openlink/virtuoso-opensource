/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2023 OpenLink Software
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
%option case-sensitive
%option never-interactive
%option noyywrap
%option nounput
%option reentrant
%option bison-bridge
%option noyyalloc
%option noyyrealloc
%option noyyfree
%option noyywrap
%option noinput
%{
#include <ctype.h>
#include "json.h"
#include "numeric.h"
#include "sqlfn.h"
#include "json_p.h"

#undef YY_INPUT
#define YY_EXTRA_TYPE jsonp_t *
#define jsonyyerror(str) jsonyyerror_impl (yyextra, str)
extern VIRT_C_LINKAGE int jsonyylex (YYSTYPE *yylval, jsonp_t *jsonp_arg, yyscan_t yyscanner);
#define YY_DECL int jsonyylex (YYSTYPE *yylval_param, jsonp_t *jsonp_arg, yyscan_t yyscanner)

#define YY_INPUT(buf,result,max_size) \
  do \
    { \
      jsonp_t *jsonp_arg = jsonyyget_extra (yyscanner); \
      int rest_len = jsonp_arg[0].jtext_len - jsonp_arg[0].jtext_ofs; \
      int get_len = (max_size); \
      if (rest_len > 0) \
        { \
          if (get_len > rest_len) \
            get_len = rest_len; \
          memcpy ((buf), (jsonp_arg[0].jtext + jsonp_arg[0].jtext_ofs), get_len); \
          (result) = get_len; \
          jsonp_arg[0].jtext_ofs += get_len; \
          break; \
        } \
      (result) = 0; \
    } while (0);

#define TOKEN_OR_STRING(tok) \
    do { \
        jsonp_t *jsonp_arg = jsonyyget_extra (yyscanner); \
        caddr_t box = spar_unescape_strliteral (NULL, yytext, 1, SPAR_STRLITERAL_JSON_STRING); \
        if (box) \
          box_flags (box) = 0; \
        yylval->box = box; \
        if (jsonp_arg->jpmode & JSON_LD) \
          return tok; \
        return STRING; \
      } while (0)

struct sparp_s; /* forward */
#define SPAR_STRLITERAL_SPARQL_STRING	0
#define SPAR_STRLITERAL_JSON_STRING	1
#define SPAR_STRLITERAL_SPARQL_QNAME	2
extern caddr_t spar_unescape_strliteral (void *sparp, const char *strg, int count_of_quotes, int mode);

#ifdef NO_JSONLD_MP
void *
jsonyyalloc (yy_size_t  size, yyscan_t yyscanner)
{
  return (void *) malloc( size );
}

void *
jsonyyrealloc  (void * ptr, yy_size_t  size , yyscan_t yyscanner)
{
  if (NULL == ptr)
    return jsonyyalloc (size, yyscanner);
  return (void *) realloc( (char *) ptr, size );
}

void
jsonyyfree (void * ptr , yyscan_t yyscanner)
{
  if (NULL != ptr)
    free( (char *) ptr );
}
#else
void *
jsonyyalloc (yy_size_t  size, yyscan_t yyscanner)
{
  return (void *) t_alloc_box (size, DV_STRING);
}

void *
jsonyyrealloc  (void * ptr, yy_size_t  sz , yyscan_t yyscanner)
{
  int old_sz = ((NULL == ptr) ? 0 : box_length (ptr));
  if (old_sz < sz)
    {
      void *res = t_alloc_box (sz, DV_STRING);
      memcpy (res, ptr, old_sz);
      return res;
    }
  if (0 == sz)
    return NULL;
  return ptr;
}

void
jsonyyfree (void * ptr , yyscan_t yyscanner)
{
}
#endif
%}

%x STRLIT

HEX             ([0-9A-Fa-f])
PERCENT	([%]{HEX}{HEX})
UCHAR	([\\](("u"{HEX}{HEX}{HEX}{HEX})|("U"{HEX}{HEX}{HEX}{HEX}{HEX}{HEX}{HEX}{HEX})))

U2A     [\xC2-\xDF][\x80-\xBF]
U2B     \xE0[\xA0-\xBF][\x80-\xBF]
U3A     [\xE1-\xEC\xEE\xEF][\x80-\xBF]{2}
U3B     \xED[\x80-\x9F][\x80-\xBF]
U4A     \xF0[\x90-\xBF][\x80-\xBF]{2}
U4B     [\xF1-\xF3][\x80-\xBF]{3}
U4C     \xF4[\x80-\x8F][\x80-\xBF]{2}
UTF_8   {U2A}|{U2B}|{U3A}|{U3B}|{U4A}|{U4B}|{U4C}
SLASH   "\\/"

IUNRESERVED	([A-Za-z0-9\x7f-\xfe]|[-.~_]|{UCHAR}|{UTF_8})
SUB_DELIMS      ([!$&''()*+,;=])
ISEGMENT_NZNC   ({IUNRESERVED}|{PERCENT}|{SUB_DELIMS}|@)
IRIREF	        ([^\x00-\x20<>\\""{}|^`]|{UCHAR}|{UTF_8}|{SLASH})

DQ              \"
AT              ("@"|"\\u0040")

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

<INITIAL>{DQ}{AT}"context"{DQ}     { TOKEN_OR_STRING(CONTEXT); }
<INITIAL>{DQ}{AT}"graph"{DQ}       { TOKEN_OR_STRING(GRAPH); }
<INITIAL>{DQ}{AT}"direction"{DQ}   { TOKEN_OR_STRING(DIRECTION); }
<INITIAL>{DQ}{AT}"id"{DQ}          { TOKEN_OR_STRING(ID); }
<INITIAL>{DQ}{AT}"type"{DQ}        { TOKEN_OR_STRING(TYPE); }
<INITIAL>{DQ}{AT}"language"{DQ}    { TOKEN_OR_STRING(LANGUAGE); }
<INITIAL>{DQ}{AT}"list"{DQ}        { TOKEN_OR_STRING(LIST); }
<INITIAL>{DQ}{AT}"base"{DQ}        { TOKEN_OR_STRING(BASE); }
<INITIAL>{DQ}{AT}"import"{DQ}      { TOKEN_OR_STRING(IMPORT); }
<INITIAL>{DQ}{AT}"included"{DQ}    { TOKEN_OR_STRING(INCLUDED); }
<INITIAL>{DQ}{AT}"index"{DQ}       { TOKEN_OR_STRING(INDEX); }
<INITIAL>{DQ}{AT}"json"{DQ}        { TOKEN_OR_STRING(JSON); }
<INITIAL>{DQ}{AT}"container"{DQ}   { TOKEN_OR_STRING(CONTAINER); }
<INITIAL>{DQ}{AT}"nest"{DQ}        { TOKEN_OR_STRING(NEST); }
<INITIAL>{DQ}{AT}"none"{DQ}        { TOKEN_OR_STRING(NONE); }
<INITIAL>{DQ}{AT}"prefix"{DQ}      { TOKEN_OR_STRING(PREFIX); }
<INITIAL>{DQ}{AT}"propagate"{DQ}   { TOKEN_OR_STRING(PROPAGATE); }
<INITIAL>{DQ}{AT}"protected"{DQ}   { TOKEN_OR_STRING(PROTECTED); }
<INITIAL>{DQ}{AT}"reverse"{DQ}     { TOKEN_OR_STRING(REVERSE); }
<INITIAL>{DQ}{AT}"set"{DQ}         { TOKEN_OR_STRING(SET); }
<INITIAL>{DQ}{AT}"value"{DQ}       { TOKEN_OR_STRING(VALUE); }
<INITIAL>{DQ}{AT}"vocab"{DQ}       { TOKEN_OR_STRING(VOCAB); }
<INITIAL>{DQ}{AT}"version"{DQ}     { TOKEN_OR_STRING(VERSION); }

<INITIAL>true	{ return TRUE_L; }
<INITIAL>false	{ return FALSE_L; }
<INITIAL>null	{ return NULL_L; }

<INITIAL>{DQ}"_:"({ISEGMENT_NZNC})+{DQ}                      { TOKEN_OR_STRING(BNODE); }
<INITIAL>{DQ}({ISEGMENT_NZNC})+":"({ISEGMENT_NZNC})+{DQ}        { TOKEN_OR_STRING(QNAME); }
<INITIAL>{DQ}({ISEGMENT_NZNC})+{DQ}                          { TOKEN_OR_STRING(NCNAME); }
<INITIAL>{DQ}({IRIREF})*{DQ}                                 { TOKEN_OR_STRING(IRI); }

<INITIAL>"\""[^\\\"\n\r\t]*	{ yymore(); BEGIN(STRLIT); }

<INITIAL>"\""[^\\\"\n\r\t]*"\"" 	{
                   caddr_t box = spar_unescape_strliteral (NULL /* no sparp for JSON_LITERAL */, yytext, 1, SPAR_STRLITERAL_JSON_STRING);
                   if (box)
                     box_flags (box) = 0;
                   yylval->box = box;
		   return STRING;
		}

<STRLIT>[^\\\"\n\r\t]*"\"" 	{
		   BEGIN(INITIAL);
                   yylval->box = spar_unescape_strliteral (NULL /* no sparp for JSON_LITERAL */, yytext, 1, SPAR_STRLITERAL_JSON_STRING);
		   return STRING;
		}

<STRLIT>"\\"([\\\"bfnrt/]|(u{HEX}{HEX}{HEX}{HEX})) { yymore (); }
<STRLIT>[^\\\"\n\r\t]* { yymore (); }
<STRLIT>[\n\r]	{ jsonyyerror ("line break is not allowed in JSON strings"); }
<STRLIT>"\t"	{ jsonyyerror ("tab character is not allowed in JSON strings"); }
<STRLIT>"\\"	{ jsonyyerror ("invalid escaping sequence in a string"); }

<INITIAL>"-"?(([1-9][0-9]*)|"0")	{
		  caddr_t err = NULL;
                  int64 n = safe_atoi (yytext, &err);
		  if (err)
                    {
		      dk_free_tree (err);
                      jsonyyerror ("bad integer constant");
		    }
                  yylval->box = t_box_num_and_zero (n);
		  return NUMBER;
		}
<INITIAL>"-"?[0-9]+"."[0-9]* |
<INITIAL>"-"?"."[0-9]+ {
  numeric_t num = t_numeric_allocate ();
  int rc = numeric_from_string (num, yytext);
  if (NUMERIC_STS_SUCCESS == rc)
    {
      yylval->box = (caddr_t) num;
      return NUMBER;
    }
  yylval->box = t_box_double (atof (yytext));
  return NUMBER;
}

<INITIAL>"-"?[0-9]+[eE][+-]?[0-9]+	|
<INITIAL>"-"?[0-9]+"."[0-9]+[eE][+-]?[0-9]+ |
<INITIAL>"-"?"."[0-9]+[eE][+-]?[0-9]+	{
  yylval->box = t_box_double (atof (yytext));
  return NUMBER;
}

<INITIAL>[+-]?[0-9.eE+-]+ { jsonyyerror ("syntax error in number"); }

<INITIAL>[ \r\t]+
<INITIAL>"#"([^\n]*)[\n]   { yyextra->line++; }
<INITIAL>[\n]   { yyextra->line++; }
<INITIAL>.	{ jsonyyerror ("character outside string"); }


%%


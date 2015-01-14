/*
 *  scn3.l
 *
 *  $Id$
 *
 *  SQL Scanner
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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
%option case-insensitive
%option never-interactive
%option noyyalloc
%option noyyrealloc
%option noyyfree
%option noyywrap
%option reentrant
%{
#include <ctype.h>
#include "Dk.h"
#include "sqlnode.h"
#include "sqlfn.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#ifndef __SQL3_H
#define __SQL3_H
#include "sql3.h"
#endif
#ifndef SCN3SPLIT
#include "sqlwords.h"
#else
struct keyword { char *keiiyword; int token; };
extern const struct keyword *lex_hash_kw (register const char *str, register unsigned int len);
#endif
#include "numeric.h"
#include "sqlcmps.h"
#include "sqlcstate.h"

struct yyguts_t;

extern void *scn3yyalloc (yy_size_t ,yyscan_t yyscanner );
extern void *scn3yyrealloc (void *,yy_size_t ,yyscan_t yyscanner );
extern void scn3yyfree(void *ptr, yyscan_t scanner);

#ifdef SCN3SPLIT
#define scn3splityyalloc(sz,scanner) scn3yyalloc(sz,scanner)
#define scn3splityyrealloc(ptr,sz,scanner) scn3yyrealloc(ptr,sz,scanner)
#define scn3splityyfree(ptr,scanner) do { ; } while (0)
#else

void *
scn3yyalloc (yy_size_t sz, yyscan_t scanner) {
  return t_alloc_box (sz, DV_STRING); }

void *
scn3yyrealloc (void *ptr, yy_size_t sz, yyscan_t scanner) {
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
scn3yyfree(void *ptr, yyscan_t scanner) {}

void
scn3_pragma_line (char *text)
{
#ifdef DEBUG
  char *full_text = text;
#endif
  char *file_start;
  scn3_line_loc_t *sll;
  if (global_scs->scs_scn3c.pragmaline_depth >= SCN3_MAX_PRAGMALINE_DEPTH)
    return;
  sll = global_scs->scs_scn3c.line_locs + global_scs->scs_scn3c.pragmaline_depth;
  sll->sll_start_lineno = global_scs->scs_scn3c.lineno;
  sll->sll_start_lexdepth = global_scs->scs_scn3c.lexdepth;
  if ('#' != text[0])
    goto error;
  text++; /* skip '#' */
  if (!strncmp (text, "pragma", 6))
    {
      text += 6;
      while (isspace(text[0])) text++;
    }
  if (strncmp (text, "line", 4))
    goto error;
  text += 4;
  while (isspace(text[0])) text++;
  sll->sll_pragma_lineno = atoi (text);
  while (isdigit(text[0])) text++;
  while (isspace(text[0])) text++;
  if ('"' == text[0])
    {
      text++;
      file_start = text;
      while (('"' != text[0]) && ('\0' != text[0])) text++;
      if ('"' != text[0])
	goto error;
      sll->sll_pragma_file = t_box_dv_short_nchars (file_start, text-file_start);
      text++;
    }
  while (isspace(text[0])) text++;
  if (('\0' != text[0]) && ('\r' != text[0]) && ('\n' != text[0]) && (('-' != text[0]) || ('-' != text[1])))
    goto error;
  if ((0 == pl_file_offs) && (NULL == pl_file))
    {
      pl_file_offs = sll->sll_pragma_lineno;
      pl_file = t_box_copy (sll->sll_pragma_file);
    }
  return;
error:
#ifdef DEBUG
  GPF_T;
#endif
  sll->sll_pragma_lineno = 1;
  sll->sll_pragma_file = NULL;
}

void
scn3_pragma_line_push (void)
{
  scn3_line_loc_t *sll = global_scs->scs_scn3c.line_locs + global_scs->scs_scn3c.pragmaline_depth;
  sll->sll_pragma_lineno += global_scs->scs_scn3c.lineno - sll->sll_start_lineno;
  global_scs->scs_scn3c.pragmaline_depth++;
  if (global_scs->scs_scn3c.pragmaline_depth >= SCN3_MAX_PRAGMALINE_DEPTH)
    return;
  sll = global_scs->scs_scn3c.line_locs + global_scs->scs_scn3c.pragmaline_depth;
  sll->sll_start_lineno = global_scs->scs_scn3c.lineno;
  sll->sll_start_lexdepth = global_scs->scs_scn3c.lexdepth;
  sll->sll_pragma_lineno = sll[-1].sll_pragma_lineno + (global_scs->scs_scn3c.lineno - sll[-1].sll_start_lineno);
  sll->sll_pragma_file = t_box_copy (sll[-1].sll_pragma_file);
}

void
scn3_pragma_line_pop (void)
{
  scn3_line_loc_t *sll;
  if (0 == global_scs->scs_scn3c.pragmaline_depth)
    scn3yyerror ("More '#line pop' directives than there were '#line push'");
  if (global_scs->scs_scn3c.pragmaline_depth < SCN3_MAX_PRAGMALINE_DEPTH)
    {
      sll = global_scs->scs_scn3c.line_locs + global_scs->scs_scn3c.pragmaline_depth;
      if (global_scs->scs_scn3c.lexdepth != sll->sll_start_lexdepth)
	scn3yyerror ("Parentheses are not balanced between '#line pop' and previous '#line push'");
    }
  global_scs->scs_scn3c.pragmaline_depth--;
  sll = global_scs->scs_scn3c.line_locs + global_scs->scs_scn3c.pragmaline_depth;
  sll->sll_start_lineno = global_scs->scs_scn3c.lineno;
}

void
scn3_pragma_line_reset (void)
{
  global_scs->scs_scn3c.pragmaline_depth = 0;
  global_scs->scs_scn3c.line_locs[0].sll_start_lineno = 1;
  global_scs->scs_scn3c.line_locs[0].sll_start_lexdepth = 0;
  global_scs->scs_scn3c.line_locs[0].sll_pragma_lineno = 1;
  global_scs->scs_scn3c.line_locs[0].sll_pragma_file = NULL;
}

int
scn3_sprint_curr_line_loc (char *buf, size_t max_buf)
{
  int res = 0;
  int depthctr;
  int printed_loc_count = 0;
  res += snprintf (buf, max_buf, "Line %d", global_scs->scs_scn3c.lineno);
  for (depthctr = global_scs->scs_scn3c.pragmaline_depth;
    (depthctr >= 0) && (global_scs->scs_scn3c.line_locs[depthctr].sll_pragma_lineno > 0);
    depthctr-- )
    {
      scn3_line_loc_t *sll = global_scs->scs_scn3c.line_locs + depthctr;
      int l = sll->sll_pragma_lineno + (global_scs->scs_scn3c.lineno - sll->sll_start_lineno);
      if (!printed_loc_count && (l == global_scs->scs_scn3c.lineno) && (NULL == sll->sll_pragma_file))
        continue; /* To avoid garbage like 'Line 8 (line 8)' */
      res += snprintf (buf+res, max_buf - res, "%sline %d",
	(printed_loc_count ? ", " : " ("), l );
      if (NULL != sll->sll_pragma_file)
	res += snprintf (buf+res, max_buf - res, " of \"%s\"", sll->sll_pragma_file);
      printed_loc_count++;
    }
  if (printed_loc_count)
    res += snprintf (buf+res, max_buf - res, ")");
  return res;
}


int
scn3_get_lineno (void)
{
  scn3_line_loc_t *sll = global_scs->scs_scn3c.line_locs + global_scs->scs_scn3c.pragmaline_depth;
  return sll->sll_pragma_lineno + (global_scs->scs_scn3c.lineno - sll->sll_start_lineno);
}

char *
scn3_get_file_name (void)
{
  scn3_line_loc_t *sll = global_scs->scs_scn3c.line_locs + global_scs->scs_scn3c.pragmaline_depth;
  return sll->sll_pragma_file;
}

void
scn3_set_file_line (char *file, int file_nchars, int line_no)
{
  if (global_scs->scs_scn3c.pragmaline_depth < SCN3_MAX_PRAGMALINE_DEPTH)
    {
      scn3_line_loc_t *sll = global_scs->scs_scn3c.line_locs + global_scs->scs_scn3c.pragmaline_depth;
      sll->sll_start_lineno = global_scs->scs_scn3c.lineno;
      sll->sll_start_lexdepth = global_scs->scs_scn3c.lexdepth;
      sll->sll_pragma_lineno = line_no;
      sll->sll_pragma_file = t_box_dv_short_nchars (file, file_nchars);
    }
}

#endif

#ifdef SCN3SPLIT

#define RETURN_CODE(c) do { \
    session_buffered_write (global_scs->scs_scn3c.split_ses, yytext, yyleng); \
    return (c); } \
  while (0)

#define RETURN_WS(c) do { \
  session_buffered_write (global_scs->scs_scn3c.split_ses, yytext, yyleng); \
    } \
  while (0)

#else

#define RETURN_CODE(c) return (c)

#define RETURN_WS(c) ;

#endif

/* macro to save the text of a SQL token */
#define SV  yylval->strval = yytext

/* macro to save the text and return a token */
#define TOK(name) { SV; RETURN_CODE (name); }

#define TOKOPEN_AUX(close) do { \
  if (global_scs->scs_scn3c.lexdepth >= SCN3_MAX_LEX_DEPTH) \
    { \
      if (SCN3_MAX_LEX_DEPTH == global_scs->scs_scn3c.lexdepth) \
        scn3yyerror ("Too many opened parentheses"); \
      GPF_T; \
    } \
  if (((close) == '}') && (global_scs->scs_scn3c.lexdepth >= SCN3_MAX_BRACE_DEPTH)) \
    scn3yyerror ("Curly brace is nested too deep"); \
  if (global_scs->scs_scn3c.lexdepth < 0) \
    GPF_T; \
  global_scs->scs_scn3c.parens[global_scs->scs_scn3c.lexdepth].sp_open_line = global_scs->scs_scn3c.lineno; \
  global_scs->scs_scn3c.parens[global_scs->scs_scn3c.lexdepth].sp_close_paren = (close); \
  global_scs->scs_scn3c.lexdepth++; } while (0)

#define TOKCLOSE_AUX(name,close) do { \
  if (global_scs->scs_scn3c.lexdepth <= 0) \
    scn3yyerror ("Too many closing parentheses"); \
  global_scs->scs_scn3c.lexdepth--; \
  if (global_scs->scs_scn3c.parens[global_scs->scs_scn3c.lexdepth].sp_close_paren != close) \
    { \
      char yerror_tmp_buf[100]; \
      if (global_scs->scs_scn3c.parens[global_scs->scs_scn3c.lexdepth].sp_open_line != global_scs->scs_scn3c.lineno) \
        snprintf (yerror_tmp_buf, sizeof (yerror_tmp_buf), "Mismatched parentheses (expression started at line %d should end with '%c')", global_scs->scs_scn3c.parens[global_scs->scs_scn3c.lexdepth].sp_open_line, global_scs->scs_scn3c.parens[global_scs->scs_scn3c.lexdepth].sp_close_paren); \
      else \
	snprintf (yerror_tmp_buf,  sizeof (yerror_tmp_buf), "Mismatched parentheses ('%c' expected)", global_scs->scs_scn3c.parens[global_scs->scs_scn3c.lexdepth].sp_close_paren); \
      scn3yyerror (yerror_tmp_buf); \
    } \
  } while (0)

#ifdef SCN3SPLIT
#define TOK_SKIP RETURN_WS(WS_SPARQL_SKIP)

#else

#define TOK_SKIP do { \
  session_buffered_write (global_scs->scs_scn3c.include_stack [global_scs->scs_scn3c.include_depth]._.sif_skipped_part, yytext, yyleng); \
  } while (0)

#endif

#define TOKOPEN(name,close) do { \
  TOKOPEN_AUX(close); \
  TOK(name); } while (0)

#define TOKCLOSE(name,close) do { \
  TOKCLOSE_AUX(name,close); \
  TOK(name); } while (0)

#define TOKOPEN_SKIP(name,close) do { \
  TOKOPEN_AUX(close); \
  TOK_SKIP; } while (0)

#define TOKCLOSE_SKIP(name,close) do { \
  TOKCLOSE_AUX(name,close); \
  TOK_SKIP; } while (0)

#define TOK_NL_SKIP do { \
  global_scs->scs_scn3c.lineno += global_scs->scs_scn3c.lineno_increment; \
  global_scs->scs_scn3c.plineno += global_scs->scs_scn3c.lineno_increment; \
  TOK_SKIP; \
  } while (0)

#define SUBTOK(code, name) do { SV; yylval->subtok = code; RETURN_CODE (name); } while (0)

#define TOKBOX(n,name) \
  do { yylval->strval = t_sym_string (&yytext [n]); save_str(yytext); RETURN_CODE (name); } while (0)

#define TOKBOX_TWOTRIMS(n1,n2,name) \
  do { yylval->strval = t_box_dv_short_nchars (yytext+n1, strlen(yytext)-(n1+n2)); \
    box_tag_modify(yylval->strval, DV_SYMBOL); \
    save_str(yytext); RETURN_CODE (name); } while (0)

#define TOKBOX_UPCASE(n,name) \
  do { yylval->strval = t_sqlp_box_id_upcase (&yytext [n]); \
    save_str(yytext); \
    RETURN_CODE (name); \
  } while (0)

#define TOKBOX_QUOTED(n,name) \
  do { yylval->strval = t_sqlp_box_id_quoted (&yytext [n], 1); \
    save_str(yytext); \
    RETURN_CODE (name); \
  } while (0)

void yyfatalerror (const char *s);

#define YY_FATAL_ERROR(msg) yyfatalerror (msg)

extern int yylex (YYSTYPE *yylval, yyscan_t yyscanner);
#define YY_DECL int yylex (YYSTYPE *yylval, yyscan_t yyscanner)

%}

%s SQL
%x STRLIT
%x HEXLIT
%x BITLIT
%x NO_ESC_STRLIT
%x HTML
%x COMMENT

%x PRAGMA_PREFIX
%x PRAGMA_PREFIX_2

	/* Internals of single-quoted SPARQL string lit */
%x MSSQL_XMLCOL

%x SPARQL_SKIP
	/* Internals of single-quoted SPARQL string lit */
%x SPARQL_SQ_SKIP

	/* Internals of double-quoted SPARQL string lit */
%x SPARQL_DQ_SKIP

	/* Internals of triple-single-quoted SPARQL string lit */
%x SPARQL_SSSQ_SKIP

	/* Internals of triple-double-quoted SPARQL string lit */
%x SPARQL_DDDQ_SKIP


S_NL	(\r\n|\n|\r)
SPAR_SQ_PLAIN	([^\\''\r\n])
SPAR_DQ_PLAIN	([^\\""\r\n])
SPAR_ECHAR	([\\]([atbvnrf\\""'']|("u"{HEX}{HEX}{HEX}{HEX})|("U"{HEX}{HEX}{HEX}{HEX}{HEX}{HEX}{HEX}{HEX})))
HEX		([0-9A-Fa-f])

SPAR_NCCHAR1p	([A-Za-z])
SPAR_NCCHAR1	([A-Za-z_])
SPAR_VARNAME	([A-Za-z0-9_]+)
SPAR_NCCHAR	([A-Za-z0-9_-])
SPAR_NCNAME_PREFIX	({SPAR_NCCHAR1p}([A-Za-z0-9_.-]*{SPAR_NCCHAR})?)
SPAR_NCNAME		({SPAR_NCCHAR1}([A-Za-z0-9_.-]*{SPAR_NCCHAR})?)


%%

EXEC[ \t]+SQL		{ sqlp_bin_op_serial = 0; BEGIN SQL;  }

	/* literal keyword tokens */

<SQL>"{"		TOKOPEN(BEGINX,'}');
<SQL>"{"[ \t\r]*"fn"/[^A-Za-z0-9_]	TOKOPEN(BEGIN_FN_X,'}');  /* was: "{"[ \t\r]*"fn", changed to avoid problems in '{ fname := ...' */
<SQL>"{"[ \t\r]*"call"/[^A-Za-z0-9_]	TOKOPEN(BEGIN_CALL_X,'}'); /* the same */
<SQL>"{"[ \t\r]*"?"[ \t\r]*"="[ \t\r]*"call"/[^A-Za-z0-9_]	{
  char tmp[20];
  snprintf (tmp, sizeof (tmp), ":%d", param_inx++);
  yylval->box = t_sym_string (tmp);
  TOKOPEN_AUX('}');
  RETURN_CODE (BEGIN_EQCALL_X);
} /* the same */
<SQL>"{"[ \t\r]*"oj"/[^A-Za-z0-9_]	TOKOPEN(BEGIN_OJ_X,'}'); /* the same */
<SQL>"{?"		TOKOPEN(BEGIN_U_X,'}');
<SQL>"}"		TOKCLOSE(ENDX,'}');
<SQL>"||"		TOK(STRING_CONCAT_OPERATOR);

<SQL>avg		SUBTOK(AMMSC_AVG, AMMSC);
<SQL>count		SUBTOK(AMMSC_COUNT, AMMSC);
<SQL>max		SUBTOK(AMMSC_MAX, AMMSC);
<SQL>min		SUBTOK(AMMSC_MIN, AMMSC);
<SQL>sum		SUBTOK(AMMSC_SUM, AMMSC);

<SQL>timestampadd	SUBTOK(SQL_FN_TIMESTAMPADD, TIMESTAMP_FUNC);
<SQL>timestampdiff	SUBTOK(SQL_FN_TIMESTAMPDIFF, TIMESTAMP_FUNC);

<SQL>SQL_TSI_SECOND	SUBTOK(SQL_TSI_SECOND, SQL_TSI);
<SQL>SQL_TSI_MINUTE	SUBTOK(SQL_TSI_MINUTE, SQL_TSI);
<SQL>SQL_TSI_HOUR	SUBTOK(SQL_TSI_HOUR, SQL_TSI);
<SQL>SQL_TSI_DAY	SUBTOK(SQL_TSI_DAY, SQL_TSI);
<SQL>SQL_TSI_MONTH	SUBTOK(SQL_TSI_MONTH, SQL_TSI);
<SQL>SQL_TSI_YEAR	SUBTOK(SQL_TSI_YEAR, SQL_TSI);

	/* punctuation */
<SQL>"="		SUBTOK(BOP_EQ, COMPARISON);
<SQL>"<>"		 SUBTOK(BOP_NEQ, COMPARISON);
<SQL>"<"		SUBTOK(BOP_LT, COMPARISON);
<SQL>">"		SUBTOK(BOP_GT, COMPARISON);
<SQL>"<="		SUBTOK(BOP_LTE, COMPARISON);
<SQL>">="		SUBTOK(BOP_GTE, COMPARISON);
<SQL>":="		TOK(EQUALS);
<SQL>"::"		TOK(DOUBLE_COLON);
<SQL>":"		TOK(COLON);
<SQL>"=>"		TOK(KWD_TAG);

<SQL>":"[0-9]+ {
  char tmp[20];
  snprintf (tmp, sizeof (tmp), ":%d", atoi (yytext+1)); /* This sprintf(atoi()) is needed to normalize, say, ':012' into ':12' */
  yylval->box = t_sym_string (tmp);
  RETURN_CODE (PARAMETER_L);
}

<SQL>"?" {
  char tmp[20];
  snprintf (tmp, sizeof (tmp), ":%d", param_inx++);
  yylval->box = t_sym_string (tmp);
  RETURN_CODE (PARAMETER_L);
}
<SQL>[-+*/,.\!]	TOK(yytext[0])
<SQL>";"	{
	if (0 < global_scs->scs_scn3c.lexdepth)
	  {
	    if (']' == global_scs->scs_scn3c.parens[global_scs->scs_scn3c.lexdepth-1].sp_close_paren)
	      scn3yyerror ("Misplaced semicolon, check if square braces are balanced in expression");
	    /* TBD: smart check for other combinations. */
	  }
	TOK(yytext[0]); }

<SQL>"("		TOKOPEN('(',')');
<SQL>"["		TOKOPEN('[',']');
<SQL>")"		TOKCLOSE(')',')');
<SQL>"]"		TOKCLOSE(']',']');

	/* names */
<SQL>"\\"[A-Za-z_\x80-\xFF][A-Za-z0-9_:\\\x80-\xFF]*	TOKBOX(1, NAME);
	/* the commented double-quote below is to cure syntax highlighting */
<SQL>\"([^\"\n]|(\"\"))+\"	{ /*"*/ TOKBOX_QUOTED(1, NAME); }
	/*<SQL>\"[^\"\n]*\"	TOKBOX_QUOTED(1, NAME)*/
<SQL>[A-Za-z_\x80-\xFF][A-Za-z0-9_@\x80-\xFF]* {
  const struct keyword *k;
#define WORD_BUF_SIZE 30
  char buf[WORD_BUF_SIZE+1], *cp, *sp;
  for (cp = buf, sp = yytext; *sp && cp < buf + WORD_BUF_SIZE; /*no step*/)
    *cp++ = toupper (*sp++);
  *cp = 0;
  if ((k = lex_hash_kw (buf, cp - buf)) != NULL)
    {
      global_scs->scs_scn3c.last_keyword_yytext = yytext;
      global_scs->scs_scn3c.last_keyword_yyleng = yyleng;
      yylval->strval = k->keiiyword;
      if (SPARQL_L == k->token)
        {
#ifndef SCN3SPILT
          scn3_include_fragment_t *outer;
          outer = global_scs->scs_scn3c.include_stack + global_scs->scs_scn3c.include_depth;
          outer->_.sif_saved_lineno = global_scs->scs_scn3c.lineno;
          outer->_.sif_saved_plineno = global_scs->scs_scn3c.plineno;
          outer->_.sif_saved_lineno_increment = global_scs->scs_scn3c.lineno_increment;
          outer->_.sif_saved_lexdepth = global_scs->scs_scn3c.lexdepth;
          outer->_.sif_skipped_part = strses_allocate ();
#endif
          BEGIN (SPARQL_SKIP);
          RETURN_CODE (SPARQL_L);
        }
      RETURN_CODE (k->token);
    }
  TOKBOX_UPCASE (0, NAME);
}

	/* special names for MS SQL 'SELECT ... FOR XML EXPLICIT'  */
<SQL>"["[A-Za-z][A-Za-z0-9:/._-]*"!"    { BEGIN (MSSQL_XMLCOL); TOKBOX_TWOTRIMS(1,1,MSSQL_XMLCOL_NAME1); }
<SQL>"[\""[A-Za-z][A-Za-z0-9:/._-]*"\"!"    { BEGIN (MSSQL_XMLCOL); TOKBOX_TWOTRIMS(2,2,MSSQL_XMLCOL_NAME1); }
<MSSQL_XMLCOL>0*[1-9][0-9]?[0-9]?   { yylval->box = box_num(atoi(yytext)); RETURN_CODE (MSSQL_XMLCOL_INTNUM); }
<MSSQL_XMLCOL>[0-9]+		    { scn3yyerror ("Invalid index in the description of XML column"); }
<MSSQL_XMLCOL>"!"[A-Za-z][A-Za-z0-9:/._-]*		{ TOKBOX(1,MSSQL_XMLCOL_NAME); }
<MSSQL_XMLCOL>"!\""[A-Za-z][A-Za-z0-9:/._-]*"\""	{ TOKBOX_TWOTRIMS(2,1,MSSQL_XMLCOL_NAME); }
<MSSQL_XMLCOL>"!"[A-Za-z][A-Za-z0-9:/._-]*"]"   { BEGIN(SQL); TOKBOX_TWOTRIMS(1,1,MSSQL_XMLCOL_NAMEZ); }
<MSSQL_XMLCOL>"!\""[A-Za-z][A-Za-z0-9:/._-]*"\"]"   { BEGIN(SQL); TOKBOX_TWOTRIMS(2,2,MSSQL_XMLCOL_NAMEZ); }
<MSSQL_XMLCOL>"!!"[A-Za-z][A-Za-z0-9:/._-]*"]"   { BEGIN(SQL); TOKBOX_TWOTRIMS(2,1,MSSQL_XMLCOL_NAMEYZ); }
<MSSQL_XMLCOL>"!!\""[A-Za-z][A-Za-z0-9:/._-]*"\"]"   { BEGIN(SQL); TOKBOX_TWOTRIMS(3,2,MSSQL_XMLCOL_NAMEYZ); }
<MSSQL_XMLCOL>.			    { scn3yyerror ("Invalid character in the description of XML column"); }

	/* parameters */
<SQL>":"[A-Za-z][A-Za-z0-9_]* {
  yylval->strval = t_sym_string (yytext);
  RETURN_CODE (NAMED_PARAMETER);
}

	/* numbers */
<SQL>[0-9]+ {
  size_t ctr, len;
  long acc_lo, acc_hi;
  len = strlen (yytext);
  if (len < 19)
    {
      caddr_t err = NULL;
      int64 n = safe_atoi (yytext, &err);
      if (err)
	{
	  dk_free_tree (err);
	  scn3yyerror ("bad integer constant");
	}
      yylval->box = t_box_num_and_zero (n);
      RETURN_CODE (INTNUM);
    }
  acc_lo = 0; acc_hi = 0;
  for (ctr = 0; ctr < len; ctr++)
    {
      acc_lo *= 10;
      acc_hi *= 10;
      acc_lo += (yytext[ctr] - '0');
      if (acc_lo & ~0xffff)
	{
	  acc_hi += ((acc_lo & ~0xffff) >> 16);
	  acc_lo &= 0xffff;
	}
      if (acc_hi & ~0x7fff)
	{
	  numeric_t num = t_numeric_allocate ();
	  int rc = numeric_from_string (num, yytext);
	  yylval->box = (caddr_t) num;
	  RETURN_CODE (rc == NUMERIC_STS_SUCCESS ? APPROXNUM : NUM_ERROR);
	}
    }
  yylval->box = t_box_num_and_zero (atol (yytext));
  RETURN_CODE (INTNUM);
}

<SQL>\#ib[0-9]+  {
  iri_id_t * box;
  caddr_t err = NULL;
  int64 n = safe_atoi (yytext+3, &err) | MIN_64BIT_BNODE_IRI_ID;
  if (err)
    {
      dk_free_tree (err);
      scn3yyerror ("bad iri literal");
    }
  box = (iri_id_t*) t_alloc_box (sizeof (iri_id_t), DV_IRI_ID);
  *box = n;
  yylval->box = (caddr_t) box;
  RETURN_CODE (IRI_LIT);
}

<SQL>\#i[0-9]+  {
  iri_id_t * box;
  caddr_t err = NULL;
  int64 n = safe_atoi (yytext+2, &err);
  if (err)
    {
      dk_free_tree (err);
      scn3yyerror ("bad iri literal");
    }
  box = (iri_id_t*) t_alloc_box (sizeof (iri_id_t), DV_IRI_ID);
  *box = n;
  yylval->box = (caddr_t) box;
  RETURN_CODE (IRI_LIT);
}

<SQL>0realhex[0-9A-Fa-f]* {
  size_t ctr, len;
  int32 res;
  len = strlen (yytext);
  ctr = 8;
  if (len!=(8+8))
    RETURN_CODE (NUM_ERROR); /* Too many significant digits */
  res = 0;
  while (ctr < len)
    {
      char c = toupper (yytext[ctr]);
      res = (res << 4) | ((c <= '9') ? ( c - '0') : (c + 10 - 'A'));
      ctr++;
    }
  yylval->box = t_box_float (((float *)(&res))[0]);
  RETURN_CODE (APPROXNUM);
}

<SQL>0dblhex[0-9A-Fa-f]* {
  size_t ctr, len;
  int64 res;
  len = strlen (yytext);
  ctr = 7;
  if (len!=(7+16))
    RETURN_CODE (NUM_ERROR); /* Too many significant digits */
  res = 0;
  while (ctr < len)
    {
      char c = toupper (yytext[ctr]);
      res = (res << 4) | ((c <= '9') ? ( c - '0') : (c + 10 - 'A'));
      ctr++;
    }
  yylval->box = t_box_double (((double *)(&res))[0]);
  RETURN_CODE (APPROXNUM);
}

<SQL>0hex[0-9A-Fa-f]* {
  size_t ctr, len;
  int64 res;
  len = strlen (yytext);
  ctr = 4;
  while ((ctr < len) && ('0' == yytext[ctr])) ctr++;
  if ((len-ctr) > 16)
    RETURN_CODE (NUM_ERROR); /* Too many significant digits */
  res = 0;
  while (ctr < len)
    {
      char c = toupper (yytext[ctr]);
      res = (res << 4) | ((c <= '9') ? ( c - '0') : (c + 10 - 'A'));
      ctr ++;
    }
  yylval->box = t_box_num_and_zero (res);
  RETURN_CODE (INTNUM);
}

<SQL>0x[0-9A-Fa-f]* {
            yylval->box = sqlp_hex_literal (yytext + 2, 0);
	    if (!yylval->box)
	      RETURN_CODE (NUM_ERROR);
	    RETURN_CODE (BINARYNUM);
}

<SQL>[0-9]+("."[0-9]*)* |
<SQL>"."[0-9]+ {
  numeric_t num = t_numeric_allocate ();
  int rc = numeric_from_string (num, yytext);
  if (NUMERIC_STS_SUCCESS == rc)
    {
      yylval->box = (caddr_t) num;
      RETURN_CODE (APPROXNUM);
    }
/*  numeric_free (num);*/
  yylval->box = t_box_double (atof (yytext));
  RETURN_CODE (APPROXNUM);
}

<SQL>[0-9]+[eE][+-]?[0-9]+[D]?		|
<SQL>[0-9]+"."[0-9]+[eE][+-]?[0-9]+[D]?	|
<SQL>"."[0-9]+[eE][+-]?[0-9]+[D]?	|
<SQL>[0-9]+[D]				|
<SQL>[0-9]+"."[0-9]+[D]			|
<SQL>"."[0-9]+[D] {
  yylval->box = t_box_double (atof (yytext));
  RETURN_CODE (APPROXNUM);
}

<SQL>[0-9]+[eE][+-]?[0-9]+[R]		|
<SQL>[0-9]+"."[0-9]+[eE][+-]?[0-9]+[R]	|
<SQL>"."[0-9]+[eE][+-]?[0-9]+[R]		|
<SQL>[0-9]+[R]				|
<SQL>[0-9]+"."[0-9]+[R]			|
<SQL>"."[0-9]+[R] {
  yylval->box = t_box_float (atof (yytext));
  RETURN_CODE (APPROXNUM);
}

	/* HTML */

<SQL>"?>"		{ BEGIN (HTML); html_lines = NULL; }
<HTML>"<?vsp"		{ yytext[strlen (yytext) - 5] = 0; t_set_push (&html_lines, t_box_string (yytext));
			  yylval->box = sqlp_html_string (); BEGIN SQL; RETURN_CODE (HTMLSTR); }

<HTML>"<\?"[=/VU]	{ size_t len = strlen (yytext); char fl = yytext [len - 1]; yytext[len - 3] = 0;
                          if (fl == 'V')
			    fl = '=';
			  else if (fl == 'U')
			    fl = '/';
			t_set_push (&html_lines, t_box_string (yytext));
			  yylval->box = sqlp_html_string (); BEGIN SQL; unput (fl); RETURN_CODE (HTMLSTR); }

<HTML>[^<\r\n]+		{ yymore (); }
<HTML>"<"		{ yymore (); }
<HTML>{S_NL}		{ t_set_push (&html_lines, t_box_string (yytext)); global_scs->scs_scn3c.lineno += global_scs->scs_scn3c.lineno_increment; global_scs->scs_scn3c.plineno += global_scs->scs_scn3c.lineno_increment; }


	/* strings */

  /*
    A new string literal parsing rules for flex by AK 21-MAR-1997.
    This takes to yytext everything between and including '' (single quotes)
    and finally gives yytext for strliteral for more detailed parsing of
    the backslash-escapes, etc.

    Note that a single-quote can be escaped in three ways:
    As '' (doubling it, a SQL-standard way).
	\' (by preceding it with a backslash, a C-standard, also used by mSQL)
	\47 or \047 (backslash plus octal number 47 which is the ascii value
		    for the single quote.)
	\x27 (same but with hexadecimal 27 which is octal 47).

    Now it's also possible to have newlines in strings (not just as \n or \012)
    but by having a trailing backslash in the string followed immediately by
    a newline, in which case the reading of the string token continues from
    the next line.

    Note that a rule with a backslash followed by anything should be
    handled first, before the rule for two singlequotes, which in turn
    should be handled always before the rule for one terminating singlequote
    (in STRLIT state), in which case we can be sure that it is not followed
    by another singlequote.

    As suggested by man flex documentation I have tried to match as much as
    possible to yytext with each rule. That is why there is part [^'\\\n]*
    after almost all patterns, i.e. just to catch into yytext everything
    upto (but excluding it) the next relevant character that is either a
    single quote, backslash or newline. However, that cannot be used after
    the beginning quote which switches the parses to STRLIT state.

    Examples:
    ''	    An empty string ""
    'kala'	A string of four letters, "kala"
    ''''	  A string of one character, singlequote. "'"
    '\''	  Same
    '\047'	As well.
    '\\'	  A string of one character, a backslash. "\"
    '\'''\'\\''!' A string of six characters, "'''\'!"
    'One\
    Two'	  A string of seven characters, with newline being the fourth.
    'One\nTwo'    Same.

    '''	   An unterminated string.
    '\'''	 An unterminated string.
    '\'	   An unterminated string.

  */

<SQL>'         {
  		 yymore();
		 global_scs->scs_scn3c.national_char = 0;
		 global_scs->scs_scn3c.uname_strlit = 0;
		 if (!parse_not_char_c_escape)
		   BEGIN(STRLIT);
		 else
		   BEGIN(NO_ESC_STRLIT);
	       } /* strliteral wants beg. quote */

<SQL>N'        {
  		 yymore();
		 global_scs->scs_scn3c.national_char = 1;
		 global_scs->scs_scn3c.uname_strlit = 0;
		 if (!parse_not_char_c_escape)
		   BEGIN(STRLIT);
		 else
		   BEGIN(NO_ESC_STRLIT);
	       } /* strliteral wants beg. quote */

<SQL>UNAME'        {
  		 yymore();
		 global_scs->scs_scn3c.national_char = 0;
		 global_scs->scs_scn3c.uname_strlit = 1;
		 if (!parse_not_char_c_escape)
		   BEGIN(STRLIT);
		 else
		   BEGIN(NO_ESC_STRLIT);
	       } /* strliteral wants beg. quote */

<STRLIT,NO_ESC_STRLIT>'      { /* saw closing quote - all done */
                 BEGIN(SQL); /* Back to SQL state. */
		 if (global_scs->scs_scn3c.uname_strlit)
		   {
		     caddr_t raw = t_strliteral (yytext + 5 /* == strlen("UNAME")*/);
		     caddr_t tmp = box_dv_uname_nchars (raw, box_length (raw) - 1);
		     /*box_dv_uname_make_immortal (tmp); -- No longer needed because memory pools keep lists of UNAMEs in use and can free them on destroy */
		     yylval->box = tmp;
		     RETURN_CODE (UNAME_LITERAL);
		   }
		 yylval->box = global_scs->scs_scn3c.national_char ? wideliteral (yytext) : t_strliteral (yytext);
		 if (!yylval->box)
		   scn3yyerror (global_scs->scs_scn3c.national_char ? "Invalid wide string literal" : "Invalid string literal");
		 RETURN_CODE (global_scs->scs_scn3c.national_char ? WSTRING : STRING);
	       }

<STRLIT,NO_ESC_STRLIT>{S_NL}     { global_scs->scs_scn3c.lineno += global_scs->scs_scn3c.lineno_increment; global_scs->scs_scn3c.plineno += global_scs->scs_scn3c.lineno_increment; yymore(); } /* { BEGIN(SQL); scn3yyerror("Unterminated string"); } */

<STRLIT>\\{S_NL}[^''\\\r\n]*  { global_scs->scs_scn3c.lineno += global_scs->scs_scn3c.lineno_increment; global_scs->scs_scn3c.plineno += global_scs->scs_scn3c.lineno_increment; yymore(); } /* Backslash + newline. */

<STRLIT>\\.[^''\\\r\n]* | /* Backslash + anything else (also another backslash) */

<STRLIT>''[^''\\\r\n]*  { yymore(); } /* Doubled singlequotes (SQL-standard) */
<STRLIT>[^''\\\r\n]+ { yymore(); } /* For everything else after beginning quote */

<NO_ESC_STRLIT>''[^''\r\n]*  { yymore(); } /* Doubled singlequotes (SQL-standard) */
<NO_ESC_STRLIT>[^''\r\n]+ { yymore(); } /* For everything else after beginning quote */
	/* AK's string parsing part ends here. */

	/* The following old incorrectly working piece commented out.
	  It should be probably compiled with el option (-l)
	  (to be compatible with the old lex) or use specifier %array
	  in the beginning that it worked even with doubled singlequotes.
	  (Otherwise unput will screw up yytext???)
	  See man flex for more info. Tabs inserted here into the beginning
	  of each line.

	<SQL>'[^'\n]*' {
	  int c = input (), len;
	  caddr_t box;
	  unput (c);

	  if (c != '\'')
	    {
	      yylval->box = strliteral (yytext);
	      RETURN_CODE (STRING);
	    }
	  else
	    yymore ();
	}

	<SQL>'[^'\n]*$ { scn3yyerror ("Unterminated string"); }

	******	Commented piece ends here. */

<SQL>{S_NL}	{ save_str(" "); global_scs->scs_scn3c.lineno += global_scs->scs_scn3c.lineno_increment; global_scs->scs_scn3c.plineno += global_scs->scs_scn3c.lineno_increment; RETURN_WS (WS_WHITESPACE); }
{S_NL}	{ scn3yyerror ("unrecognized symbol"); /*global_scs->scs_scn3c.lineno++; ECHO;*/ }

<SQL>[ \t]+	{ save_str(" "); RETURN_WS (WS_WHITESPACE); }

	/* Pragmas */
<SQL>"#"("pragma"[\ t]+)?"line"[ \t]+[0-9]+([ \t]+[""][^""]+[""])?[ \t]*("--".*)?{S_NL} { scn3_pragma_line (yytext); global_scs->scs_scn3c.lineno_increment = 1; global_scs->scs_scn3c.plineno++; RETURN_WS(WS_PRAGMA_LINE); }
<SQL>"#"("pragma"[\ t]+)?"line"[ \t]+"push"[ \t]*("--".*)?{S_NL} { scn3_pragma_line_push (); global_scs->scs_scn3c.lineno_increment = 1; global_scs->scs_scn3c.plineno++; RETURN_WS(WS_PRAGMA_LINE); }
<SQL>"#"("pragma"[\ t]+)?"line"[ \t]+"pop"[ \t]*("--".*)?{S_NL} { scn3_pragma_line_pop (); global_scs->scs_scn3c.lineno_increment = 1; global_scs->scs_scn3c.plineno++; RETURN_WS(WS_PRAGMA_LINE); }
<SQL>"#"("pragma"[\ t]+)?"line"([ \t]+"reset")?[ \t]*("--".*)?{S_NL} { scn3_pragma_line_reset (); global_scs->scs_scn3c.lineno_increment = 1; global_scs->scs_scn3c.plineno++; RETURN_WS(WS_PRAGMA_LINE); }
<SQL>"#"("pragma"[\ t]+)?"line" { scn3yyerror ("Ill formed #line"); }

<SQL>"#pragma"[ \t]+"prefix"[ \t]+	{
	BEGIN(PRAGMA_PREFIX);
	t_set_push (&global_scs->scs_scn3c.namespaces, NULL);
	t_set_push (&global_scs->scs_scn3c.namespaces, NULL);
        RETURN_WS(WS_PRAGMA_PREFIX_1); }

<PRAGMA_PREFIX>({SPAR_NCNAME_PREFIX}?)":"	{
	BEGIN(PRAGMA_PREFIX_2);
	global_scs->scs_scn3c.namespaces->data = t_box_dv_uname_nchars (yytext, strlen (yytext) - 1);
	RETURN_WS(WS_PRAGMA_PREFIX_2); }

<PRAGMA_PREFIX_2>[ \t+]"<"([^<>''{}|^`\001-\040])*">"	{
	const char *langl = strchr (yytext, '<');
	BEGIN(SQL);
	global_scs->scs_scn3c.namespaces->next->data = t_box_dv_uname_nchars (langl + 1, (yytext + yyleng - 2) - langl);
        RETURN_WS(WS_PRAGMA_PREFIX_3); }

<PRAGMA_PREFIX>.	{ scn3yyerror ("Ill formed namespace prefix in #pragma prefix"); }
<PRAGMA_PREFIX><<EOF>>	{ scn3yyerror ("Unexpected end of text in #pragma prefix"); }

<PRAGMA_PREFIX_2>.		{ scn3yyerror ("Ill formed namespace IRI in #pragma prefix"); }
<PRAGMA_PREFIX_2><<EOF>>	{ scn3yyerror ("Unexpected end of text in #pragma prefix"); }

<SQL>"#pragma" { scn3yyerror ("Ill formed #pragma"); }
<SQL>"#" { scn3yyerror ("Misused lattice sign ('#')"); }

<SQL>"--"[ \t]*"no_c_escapes+"[ \t]* { parse_not_char_c_escape = 1; RETURN_WS(WS_PRAGMA_C_ESC); }
<SQL>"--"[ \t]*"no_c_escapes-"[ \t]* { parse_not_char_c_escape = 0; RETURN_WS(WS_PRAGMA_C_ESC); }
<SQL>"--"[ \t]*"utf8_execs=yes"[ \t]* { parse_utf8_execs = 1; RETURN_WS(WS_PRAGMA_UTF8_ESC); }
<SQL>"--"[ \t]*"utf8_execs=no"[ \t]* { parse_utf8_execs = 0; RETURN_WS(WS_PRAGMA_UTF8_ESC); }
<SQL>"--"[ \t]*"pl_debug+"[ \t]* { parse_pldbg = 1; RETURN_WS(WS_PRAGMA_PL_DEBUG); }
<SQL>"--src"[ \t]+[A-Za-z0-9_./\\-]+":"[0-9+-][0-9]*[ \t]*{S_NL} { sqlp_pl_file (yytext); global_scs->scs_scn3c.lineno_increment = 1; global_scs->scs_scn3c.plineno++; RETURN_WS(WS_PRAGMA_SRC); }
<SQL>"--"[^\r\n]*	{ RETURN_WS(WS_COMMENT_EOL); }	/* comment */
<SQL>"/\*"	{ BEGIN (COMMENT); RETURN_WS(WS_COMMENT_BEGIN); }
<COMMENT>"/\*"  { scn3yyerror ("Nested C style comments not supported"); }
<COMMENT>"\*/"	{ BEGIN (SQL); RETURN_WS(WS_COMMENT_END); }
<COMMENT>{S_NL}	{ global_scs->scs_scn3c.lineno += global_scs->scs_scn3c.lineno_increment; global_scs->scs_scn3c.plineno += global_scs->scs_scn3c.lineno_increment; RETURN_WS(WS_COMMENT_LONG); }
<COMMENT>.|((([^/\r\n*])|([*][^/\r\n*]))+)	{ RETURN_WS(WS_COMMENT_LONG); }

	/* IvAn/Fix4AritmSql/000828 Invalid lexems should be handled explicitly */
<SQL>([^A-Za-z0-9_''""+\-*/(){}<=>?.,:;# \t\r\n\[\]]+)		TOK(LEXICAL_ERROR)

        /* hex literal rules */
<SQL>X'		{
                  yymore();
		  BEGIN (HEXLIT);
                }

<HEXLIT>[0-9A-Fa-f]* yymore();

<HEXLIT>'	{
                  BEGIN (SQL);
		  yylval->box = sqlp_hex_literal (yytext + 2, 1);
		  if (!yylval->box)
		    RETURN_CODE (NUM_ERROR);
		  RETURN_CODE (BINARYNUM);
                }


        /* bit literal rules */
<SQL>B'		{
                  yymore();
		  BEGIN (BITLIT);
                }

<BITLIT>[0-1]+ yymore();

<BITLIT>'	{
                  BEGIN (SQL);
		  yylval->box = sqlp_bit_literal (yytext + 2, 1);
		  if (!yylval->box)
		    RETURN_CODE (NUM_ERROR);
		  RETURN_CODE (BINARYNUM);
                }


<SQL><<EOF>>	{
  if (global_scs->scs_scn3c.include_depth <= 0 )
    yyterminate();
  else
    {
      scn3_include_fragment_t *outer;
      global_scs->scs_scn3c.include_depth--;
      outer = global_scs->scs_scn3c.include_stack + global_scs->scs_scn3c.include_depth;
      yy_delete_buffer (YY_CURRENT_BUFFER, yyscanner);
      yy_switch_to_buffer (outer->sif_buffer, yyscanner);
      global_scs->scs_scn3c.lineno = outer->_.sif_saved_lineno;
      global_scs->scs_scn3c.plineno = outer->_.sif_saved_plineno;
      global_scs->scs_scn3c.lineno_increment = outer->_.sif_saved_lineno_increment;
      /* No such assignment, because the fragment may have extra ')' at the end:
         global_scs->scs_scn3c.lexdepth = outer->_.sif_saved_lexdepth; */
    }
  }

<SQL>.		TOK(LEXICAL_ERROR);

	/* Correct skip of SPARQL */

<SPARQL_SKIP>"("	TOKOPEN_SKIP ('(',')');
<SPARQL_SKIP>")"	{
    scn3_include_fragment_t *outer = global_scs->scs_scn3c.include_stack + global_scs->scs_scn3c.include_depth;
    if (outer->_.sif_saved_lexdepth == global_scs->scs_scn3c.lexdepth)
      {
#ifndef SCN3SPLIT
        spar_query_env_t sparqre;
#endif

        BEGIN(SQL);

#ifndef SCN3SPLIT
        scn3_sparp_inline_subselect (&sparqre, "\n)\n", outer, yyscanner);
        yy_scan_buffer (sparqre.sparqre_compiled_text, box_length (sparqre.sparqre_compiled_text) - 1, yyscanner);
#else
        TOKCLOSE (')',')');
#endif
      }
    else
      {
        TOKCLOSE_SKIP (')',')');
      }
  }

<SPARQL_SKIP>";"	{
    scn3_include_fragment_t *outer = global_scs->scs_scn3c.include_stack + global_scs->scs_scn3c.include_depth;
    if (outer->_.sif_saved_lexdepth == global_scs->scs_scn3c.lexdepth)
      {
#ifndef SCN3SPLIT
        spar_query_env_t sparqre;
#endif

        BEGIN(SQL);

#ifndef SCN3SPLIT
        scn3_sparp_inline_subselect (&sparqre, "\n;\n", outer, yyscanner);
        yy_scan_buffer (sparqre.sparqre_compiled_text, box_length (sparqre.sparqre_compiled_text) - 1, yyscanner);
#else
        TOK (';');
#endif
      }
    else
      {
        TOK_SKIP;
      }
  }

<SPARQL_SKIP>"{"	TOKOPEN_SKIP ('{','}');
<SPARQL_SKIP>"}"	TOKCLOSE_SKIP ('}','}');
<SPARQL_SKIP>"["	TOKOPEN_SKIP ('[',']');
<SPARQL_SKIP>"]"	TOKCLOSE_SKIP (']',']');
<SPARQL_SKIP>"<"([^<>"{}|^`\001-\040\\])*">"		{ TOK_SKIP; }
<SPARQL_SKIP>([""][^""\\\n]*[""])|([''][^''\\\n]*[''])	{ TOK_SKIP; }

<SPARQL_SKIP>['']['']['']		{ BEGIN(SPARQL_SSSQ_SKIP); TOK_SKIP; }
<SPARQL_SKIP>[""][""][""]		{ BEGIN(SPARQL_DDDQ_SKIP); TOK_SKIP; }
<SPARQL_SSSQ_SKIP>['']['']['']	{ BEGIN(SPARQL_SKIP); TOK_SKIP; }
<SPARQL_DDDQ_SKIP>[""][""][""]	{ BEGIN(SPARQL_SKIP); TOK_SKIP; }
<SPARQL_SSSQ_SKIP>(([''](['']?))?{S_NL})		{ TOK_NL_SKIP; }
<SPARQL_DDDQ_SKIP>(([""]([""]?))?{S_NL})		{ TOK_NL_SKIP; }
<SPARQL_SSSQ_SKIP>((([''](['']?))?({SPAR_SQ_PLAIN}|{SPAR_ECHAR}))+)		{ yymore(); }
<SPARQL_DDDQ_SKIP>((([""]([""]?))?({SPAR_DQ_PLAIN}|{SPAR_ECHAR}))+)		{ yymore(); }
<SPARQL_SSSQ_SKIP>[\\]		{ scn3yyerror ("Bad escape sequence in a SPARQL long single-quoted string"); }
<SPARQL_DDDQ_SKIP>[\\]		{ scn3yyerror ("Bad escape sequence in a SPARQL long double-quoted string"); }
<SPARQL_SSSQ_SKIP>.			{ scn3yyerror ("Bad character in a SPARQL long single-quoted string"); }
<SPARQL_DDDQ_SKIP>.			{ scn3yyerror ("Bad character in a SPARQL long double-quoted string"); }
<SPARQL_SSSQ_SKIP><<EOF>>		{ scn3yyerror ("Unterminated SPARQL long single-quoted string"); }
<SPARQL_DDDQ_SKIP><<EOF>>		{ scn3yyerror ("Unterminated SPARQL long double-quoted string"); }


<SPARQL_SKIP>['']		{ BEGIN(SPARQL_SQ_SKIP); TOK_SKIP; }
<SPARQL_SKIP>[""]		{ BEGIN(SPARQL_DQ_SKIP); TOK_SKIP; }
<SPARQL_SQ_SKIP>['']		{ BEGIN(SPARQL_SKIP); TOK_SKIP; }
<SPARQL_DQ_SKIP>[""]		{ BEGIN(SPARQL_SKIP); TOK_SKIP; }
<SPARQL_SQ_SKIP>{S_NL}	{ scn3yyerror ("End-of-line in a SPARQL short single-quoted string"); }
<SPARQL_DQ_SKIP>{S_NL}	{ scn3yyerror ("End-of-line in a SPARQL short double-quoted string"); }
<SPARQL_SQ_SKIP>(({SPAR_SQ_PLAIN}|{SPAR_ECHAR})+)		TOK_SKIP;
<SPARQL_DQ_SKIP>(({SPAR_DQ_PLAIN}|{SPAR_ECHAR})+)		TOK_SKIP;
<SPARQL_SQ_SKIP>[\\]		{ scn3yyerror ("Bad escape sequence in a SPARQL short single-quoted string"); }
<SPARQL_DQ_SKIP>[\\]		{ scn3yyerror ("Bad escape sequence in a SPARQL short double-quoted string"); }
<SPARQL_SQ_SKIP><<EOF>>		{ scn3yyerror ("Unterminated SPARQL short single-quoted string"); }
<SPARQL_DQ_SKIP><<EOF>>		{ scn3yyerror ("Unterminated SPARQL short double-quoted string"); }

<SPARQL_SKIP>[^#''""\\\n\r(){}\[\];<>]+ TOK_SKIP;
<SPARQL_SKIP><<EOF>>  {
#ifndef SCN3SPLIT
    scn3_include_fragment_t *outer = global_scs->scs_scn3c.include_stack + global_scs->scs_scn3c.include_depth;
    spar_query_env_t sparqre;
    BEGIN(SQL);
    scn3_sparp_inline_subselect (&sparqre, "\n;\n", outer, yyscanner);
    yy_scan_buffer (sparqre.sparqre_compiled_text, box_length (sparqre.sparqre_compiled_text) - 1, yyscanner);
#else
    yyterminate();
#endif
  }

<SPARQL_SKIP>[#]([^\n\r]*){S_NL}	TOK_NL_SKIP;
<SPARQL_SKIP>{S_NL}	TOK_NL_SKIP;
<SPARQL_SKIP>[<>]	TOK_SKIP;
<SPARQL_SKIP>.		TOK(LEXICAL_ERROR);	/* random non-SPARQL text */

.		TOK(LEXICAL_ERROR);	/* random non-SQL, non-HTML text */
%%

#ifndef SCN3SPLIT
void
scn3_sparp_inline_subselect (spar_query_env_t *sparqre, const char * tail_sql_text, scn3_include_fragment_t *outer, yyscan_t yyscanner)
{
   struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;
   memset (sparqre, 0, sizeof (spar_query_env_t));
   if (0 == global_scs->scs_scn3c.lexdepth)
     {
       if (0 == sqlc_client()->cli_resultset_max_rows)
         sparqre->sparqre_direct_client_call = 1;
     }
   sparqre->sparqre_qi = CALLER_LOCAL;
   sparqre->sparqre_src = &(outer->_);
   sparqre->sparqre_tail_sql_text = tail_sql_text;
   sparqre->sparqre_start_lineno = global_scs->scs_scn3c.lineno;
   sparqre->sparqre_param_ctr = &param_inx;
   sparqre->sparqre_external_namespaces = global_scs->scs_scn3c.namespaces;
   sparqre->sparqre_compiled_text = NULL;
   sparqre->sparqre_catched_error = NULL;
   sparqre->sparqre_super_sc = top_sc;
   if (!rdf_no_string_inline)
     scn3yyerror ("This server version only works with RDF data with no strings inlined.  To convert an existing database, see the documentation concerning the clrdf23.sql script and upgrading pre 06.00.3126 databases. This takes a potentially long time.  To avoid this operation, use the server executable with which the database was created instead.");
   if (0 == cl_run_local_only && (1 != cl_rdf_inf_inited && THREAD_CURRENT_THREAD != cl_rdf_inf_init_thread))
     scn3yyerror ("RDFNI");
   sparp_compile_subselect (sparqre);
   if (NULL != sparqre->sparqre_catched_error)
     {
       char temp[2000];
       strncpy (temp, ERR_MESSAGE (sparqre->sparqre_catched_error), sizeof (temp));
       dk_free_tree (sparqre->sparqre_catched_error);
       sparqre->sparqre_catched_error = NULL;
       scn3yyerror (temp);
     }
   outer->sif_buffer = YY_CURRENT_BUFFER;
   outer->_.sif_saved_lineno = global_scs->scs_scn3c.lineno;
   outer->_.sif_saved_plineno = global_scs->scs_scn3c.plineno;
   outer->_.sif_saved_lineno_increment = global_scs->scs_scn3c.lineno_increment;
   outer->_.sif_saved_lexdepth = global_scs->scs_scn3c.lexdepth;
   global_scs->scs_scn3c.include_depth++; /* No stack overflow check. TBD later when we will be able to nest SQL into SPARQL and get, say, SQL inside SPARQL inside SQL ... */
   global_scs->scs_scn3c.lineno_increment = 0;
}
#endif

#ifndef SCN3SPLIT
void
sql_pop_all_buffers (yyscan_t yyscanner)
#else
void
scn3split_pop_all_buffers (yyscan_t yyscanner)
#endif
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;
  while (global_scs->scs_scn3c.include_depth > 0)
    {
      scn3_include_fragment_t *outer;
      global_scs->scs_scn3c.include_depth--;
      outer = global_scs->scs_scn3c.include_stack + global_scs->scs_scn3c.include_depth;
      yy_delete_buffer (YY_CURRENT_BUFFER, yyscanner);
      yy_switch_to_buffer (outer->sif_buffer, yyscanner);
    }
}

#ifndef SCN3SPLIT
void
sql_yy_reset (yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;
  BEGIN SQL;
#else
void
scn3split_yy_reset (yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;
  BEGIN SQL;
#endif
  global_scs->scs_scn3c.lineno = 1;
  global_scs->scs_scn3c.plineno = 1;
  global_scs->scs_scn3c.lineno_increment = 1;
  global_scs->scs_scn3c.lexdepth = 0;
  global_scs->scs_scn3c.include_depth = 0;
  global_scs->scs_scn3c.inside_error_reporter = 0;
  global_scs->scs_scn3c.namespaces = NULL;
  scn3_pragma_line_reset ();
  dk_free_tree (global_scs->scs_scn3c.split_ses);
  global_scs->scs_scn3c.split_ses = NULL;
}


#ifndef SCN3SPLIT
char *
scn3_get_yytext (yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;
  return yytext;
}

size_t
scn3_get_yyleng (yyscan_t yyscanner)
{
  struct yyguts_t * yyg = (struct yyguts_t*)yyscanner;
  return (size_t) yyleng;
}


#endif

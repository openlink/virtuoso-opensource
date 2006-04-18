%{
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
 *  Copyright (C) 1998-2006 OpenLink Software
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
 *  
*/

#include <ctype.h>
#include "Dk.h"
#include "sqlnode.h"
#include "sqlfn.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sql3.h"
#include "sqlwords.h"
#ifdef __BORLANDC__ /* Rogue Wave STL contains numeric.h */
#include "G:\libsrc\Wi\numeric.h"
#else
#include "numeric.h"
#endif
#include "sqlcmps.h"
#include "sqlcstate.h"

int national_char = 0;
int uname_strlit = 0;

/* Place of an opened '(' or '{' */
typedef struct scn3_paren_s {
  int sp_open_line;	/*!< Line number where it has been opened */
  char sp_close_paren;	/*!< The character that should be used to close it (e.g. '}' if '{' is opened */
} scn3_paren_t;

int scn3_lineno = 1;	/*!< Throughout counter of lines in the source text */
int scn3_plineno = 1;	/*!< Physical counter of lines in the source text - used for the PL debugger */
int scn3_lineno_increment = 1;	/*!< This is zero for 'macroexpanded' fragments of SQL text, to prevent from confusing when a long text is inserted instead of a single line */
int scn3_lexdepth = 0;	/*!< Number of opened parenthesis */

dk_set_t scn3_namespaces = NULL; /*!< List of namespace prefixes and URIs */

#define MAXLEXDEPTH 80	/*!< Maximum allowed number of opened parenthesis */
scn3_paren_t scn3_parens[MAXLEXDEPTH];


#define MAX_PRAGMALINE_DEPTH 4	/*!< Maximum nesting of line locations (i.e. 1 + (max no of nested '#pragma line push')) */

/*! Logical line location as it is set by #pragma line statements.
See the body of scn3_sprint_curr_line_loc() to find out how to use such data
to get a logical filename and line number for the currect position
in the source text. */
typedef struct scn3_line_loc_s {
/*! The value of scn3_lineno at the beginning of #pragma line. */
  int sll_start_lineno;
/*! The value of scn3_lexdepth at the beginning of #pragma line.
This is used to check that there are no cases when e.g. an '{' is
opened in one file and pair '}' is closed in some other file. */
  int sll_start_lexdepth;
/*! Line number as it is written in the body of #pragma line. */
  int sll_pragma_lineno;
/*! File name as it is written in the body of #pragma line. */
  caddr_t sll_pragma_file;
} scn3_line_loc_t;

/*! Stack of logical locations. */
scn3_line_loc_t scn3_line_locs[MAX_PRAGMALINE_DEPTH];
/*! This is the number of not-yet-popped '#pragma line push' directives. */
int scn3_pragmaline_depth = 0;


#define MAX_INCLUDE_DEPTH 4	/*!< Maximum nesting of includes or fragments in different languages. */

/*! Fragment written on one language (say, in SPARQL) that is included into the text on other language (say, in SQL) */
typedef struct scn3_include_fragment_s {
  YY_BUFFER_STATE sif_buffer;
  scn3_include_frag_t _;
} scn3_include_fragment_t;

scn3_include_fragment_t scn3_include_stack [MAX_INCLUDE_DEPTH];

/*! Number of fragments that are started but not yet completed. It's zero while the whole text is in SQL */
int scn3_include_depth = 0;

void scn3_pragma_line (char *text)
{
#ifdef DEBUG
  char *full_text = text;
#endif
  char *file_start;
  scn3_line_loc_t *sll;
  if (scn3_pragmaline_depth >= MAX_PRAGMALINE_DEPTH)
    return;
  sll = scn3_line_locs + scn3_pragmaline_depth;
  sll->sll_start_lineno = scn3_lineno;
  sll->sll_start_lexdepth = scn3_lexdepth;
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

void scn3_pragma_line_push (void)
{
  scn3_line_loc_t *sll = scn3_line_locs + scn3_pragmaline_depth;
  sll->sll_pragma_lineno += scn3_lineno - sll->sll_start_lineno;
  scn3_pragmaline_depth++;
  if (scn3_pragmaline_depth >= MAX_PRAGMALINE_DEPTH)
    return;
  sll = scn3_line_locs + scn3_pragmaline_depth;
  sll->sll_start_lineno = scn3_lineno;
  sll->sll_start_lexdepth = scn3_lexdepth;
  sll->sll_pragma_lineno = sll[-1].sll_pragma_lineno + (scn3_lineno - sll[-1].sll_start_lineno);
  sll->sll_pragma_file = t_box_copy (sll[-1].sll_pragma_file);
}

void scn3_pragma_line_pop (void)
{
  scn3_line_loc_t *sll;
  if (0 == scn3_pragmaline_depth)
    yyerror ("More '#line pop' directives than there were '#line push'");
  if (scn3_pragmaline_depth < MAX_PRAGMALINE_DEPTH)
    {
      sll = scn3_line_locs + scn3_pragmaline_depth;
      if (scn3_lexdepth != sll->sll_start_lexdepth)
	yyerror ("Parentheses are not balanced between '#line pop' and previous '#line push'");
    }
  scn3_pragmaline_depth--;
  sll = scn3_line_locs + scn3_pragmaline_depth;
  sll->sll_start_lineno = scn3_lineno;
}

void scn3_pragma_line_reset (void)
{
  scn3_pragmaline_depth = 0;
  scn3_line_locs[0].sll_start_lineno = 1;
  scn3_line_locs[0].sll_start_lexdepth = 0;
  scn3_line_locs[0].sll_pragma_lineno = 1;
  scn3_line_locs[0].sll_pragma_file = NULL;
}

int scn3_sprint_curr_line_loc (char *buf, size_t max_buf)
{
  int res = 0;
  int depthctr = scn3_pragmaline_depth;
  int printed_loc_count = 0;
  res += snprintf (buf, max_buf, "Line %d", scn3_lineno);
  while ((depthctr >= 0) && (scn3_line_locs[depthctr].sll_pragma_lineno > 0))
    {
      scn3_line_loc_t *sll = scn3_line_locs + depthctr;
      res += snprintf (buf+res, max_buf - res, "%si.e. line %d",
	(printed_loc_count ? ", " : " ("),
	sll->sll_pragma_lineno + (scn3_lineno - sll->sll_start_lineno) );
      if (NULL != sll->sll_pragma_file)
	res += snprintf (buf+res, max_buf - res, " of \"%s\"", sll->sll_pragma_file);
      printed_loc_count++;
      depthctr--;
    }
  if (printed_loc_count)
    res += snprintf (buf+res, max_buf - res, ")");
  return res;
}


int
scn3_get_lineno (void)
{
  scn3_line_loc_t *sll = scn3_line_locs + scn3_pragmaline_depth;
  return sll->sll_pragma_lineno + (scn3_lineno - sll->sll_start_lineno);
}

char *
scn3_get_file_name (void)
{
  scn3_line_loc_t *sll = scn3_line_locs + scn3_pragmaline_depth;
  return sll->sll_pragma_file;
}

void
scn3_set_file_line (char *file, int file_nchars, int line_no)
{
  if (scn3_pragmaline_depth < MAX_PRAGMALINE_DEPTH)
    {
      scn3_line_loc_t *sll = scn3_line_locs + scn3_pragmaline_depth;
      sll->sll_start_lineno = scn3_lineno;
      sll->sll_start_lexdepth = scn3_lexdepth;
      sll->sll_pragma_lineno = line_no;
      sll->sll_pragma_file = t_box_dv_short_nchars (file, file_nchars);
    }
}

void scn3_sparp_inline_subselect (spar_query_env_t *sparqre, const char * tail_sql_text, scn3_include_fragment_t *outer)
{
   memset (sparqre, 0, sizeof (spar_query_env_t));
   if (0 == scn3_lexdepth)
     {
       if (0 == sqlc_client()->cli_resultset_max_rows)
         sparqre->sparqre_direct_client_call = 1;
     }
   sparqre->sparqre_src = &(outer->_);
   sparqre->sparqre_tail_sql_text = tail_sql_text;
   sparqre->sparqre_start_lineno = scn3_lineno;
   sparqre->sparqre_param_ctr = &param_inx;
   sparqre->sparqre_external_namespaces = scn3_namespaces;
   sparqre->sparqre_compiled_text = NULL;
   sparqre->sparqre_catched_error = NULL;
   sparp_compile_subselect (sparqre);
   if (NULL != sparqre->sparqre_catched_error)
     yyerror (ERR_MESSAGE (sparqre->sparqre_catched_error));
   outer->sif_buffer = YY_CURRENT_BUFFER;
   outer->_.sif_saved_lineno = scn3_lineno;
   outer->_.sif_saved_plineno = scn3_plineno;
   outer->_.sif_saved_lineno_increment = scn3_lineno_increment;
   outer->_.sif_saved_lexdepth = scn3_lexdepth;
   scn3_include_depth++; /* No stack overflow check. TBD later when we will be able to nest SQL into SPARQL and get, say, SQL inside SPARQL inside SQL ... */
   scn3_lineno_increment = 0;
}

/* macro to save the text of a SQL token */
#define SV  yylval.strval = yytext

/* macro to save the text and return a token */
#define TOK(name) { SV; return name; }

#define TOKOPEN_AUX(close) { \
  if (scn3_lexdepth >= MAXLEXDEPTH) \
    { \
      if (MAXLEXDEPTH == scn3_lexdepth) \
        yyerror ("Too many opened parentheses"); \
      GPF_T; \
    } \
  if (scn3_lexdepth < 0) \
    GPF_T; \
  scn3_parens[scn3_lexdepth].sp_open_line = scn3_lineno; \
  scn3_parens[scn3_lexdepth].sp_close_paren = (close); \
  scn3_lexdepth++; }

#define TOKCLOSE_AUX(name,close) { \
  if (scn3_lexdepth <= 0) \
    yyerror ("Too many closing parentheses"); \
  scn3_lexdepth--; \
  if (scn3_parens[scn3_lexdepth].sp_close_paren != close) \
    { \
      char yerror_tmp_buf[100]; \
      if (scn3_parens[scn3_lexdepth].sp_open_line != scn3_lineno) \
        snprintf (yerror_tmp_buf, sizeof (yerror_tmp_buf), "Mismatched parentheses (expression started at line %d should end with '%c')", scn3_parens[scn3_lexdepth].sp_open_line, scn3_parens[scn3_lexdepth].sp_close_paren); \
      else \
	snprintf (yerror_tmp_buf,  sizeof (yerror_tmp_buf), "Mismatched parentheses ('%c' expected)", scn3_parens[scn3_lexdepth].sp_close_paren); \
      yyerror (yerror_tmp_buf); \
    } \
  }

#define TOKOPEN(name,close) { \
  TOKOPEN_AUX(close) \
  TOK(name); }

#define TOKCLOSE(name,close) { \
  TOKCLOSE_AUX(name,close); \
  TOK(name); }

#define TOKOPEN_SKIP(name,close) { \
  TOKOPEN_AUX(close) \
  TOK_SKIP; }

#define TOKCLOSE_SKIP(name,close) { \
  TOKCLOSE_AUX(name,close); \
  TOK_SKIP; }

#define TOK_SKIP { \
  session_buffered_write (scn3_include_stack [scn3_include_depth]._.sif_skipped_part, yytext, yyleng); \
  }

#define TOK_NL_SKIP { \
  scn3_lineno += scn3_lineno_increment; \
  scn3_plineno += scn3_lineno_increment; \
  TOK_SKIP; \
  }

#define SUBTOK(code, name) { SV; yylval.subtok = code; return name; }

#define TOKBOX(n,name) \
  { yylval.strval = t_sym_string (&yytext [n]); save_str(yytext); return (name); }

#define TOKBOX_TWOTRIMS(n1,n2,name) \
  { yylval.strval = t_box_dv_short_nchars (yytext+n1, strlen(yytext)-(n1+n2)); \
    box_tag_modify(yylval.strval, DV_SYMBOL); \
    save_str(yytext); return (name); }

#define TOKBOX_UPCASE(n,name) \
  { yylval.strval = t_sqlp_box_id_upcase (&yytext [n]); \
    save_str(yytext); \
    return (name); \
  }

#define TOKBOX_QUOTED(n,name) \
  { yylval.strval = t_sqlp_box_id_quoted (&yytext [n], 1); \
    save_str(yytext); \
    return (name); \
  }

#define YY_FATAL_ERROR(msg) yyerror (msg)

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

<SQL>"{"		TOKOPEN(BEGINX,'}')
<SQL>"{"[ \t\r]*"fn"/[^A-Za-z0-9_]	TOKOPEN(BEGIN_FN_X,'}')  /* was: "{"[ \t\r]*"fn", changed to avoid problems in '{ fname := ...' */
<SQL>"{"[ \t\r]*"call"/[^A-Za-z0-9_]	TOKOPEN(BEGIN_CALL_X,'}') /* the same */
<SQL>"{"[ \t\r]*"?"[ \t\r]*"="[ \t\r]*"call"/[^A-Za-z0-9_]	{
  char tmp[20];
  snprintf (tmp, sizeof (tmp), ":%d", param_inx++);
  yylval.box = t_sym_string (tmp);
  TOKOPEN_AUX('}')
  return BEGIN_EQCALL_X;
} /* the same */
<SQL>"{"[ \t\r]*"oj"/[^A-Za-z0-9_]	TOKOPEN(BEGIN_OJ_X,'}') /* the same */
<SQL>"{?"		TOKOPEN(BEGIN_U_X,'}')
<SQL>"}"		TOKCLOSE(ENDX,'}')
<SQL>"||"		TOK(STRING_CONCAT_OPERATOR)

<SQL>avg		SUBTOK(AMMSC_AVG, AMMSC)
<SQL>count		SUBTOK(AMMSC_COUNT, AMMSC)
<SQL>max		SUBTOK(AMMSC_MAX, AMMSC)
<SQL>min		SUBTOK(AMMSC_MIN, AMMSC)
<SQL>sum		SUBTOK(AMMSC_SUM, AMMSC)

<SQL>timestampadd	SUBTOK(SQL_FN_TIMESTAMPADD, TIMESTAMP_FUNC)
<SQL>timestampdiff	SUBTOK(SQL_FN_TIMESTAMPDIFF, TIMESTAMP_FUNC)

<SQL>SQL_TSI_SECOND	SUBTOK(SQL_TSI_SECOND, SQL_TSI)
<SQL>SQL_TSI_MINUTE	SUBTOK(SQL_TSI_MINUTE, SQL_TSI)
<SQL>SQL_TSI_HOUR	SUBTOK(SQL_TSI_HOUR, SQL_TSI)
<SQL>SQL_TSI_DAY	SUBTOK(SQL_TSI_DAY, SQL_TSI)
<SQL>SQL_TSI_MONTH	SUBTOK(SQL_TSI_MONTH, SQL_TSI)
<SQL>SQL_TSI_YEAR	SUBTOK(SQL_TSI_YEAR, SQL_TSI)

	/* punctuation */
<SQL>"="		SUBTOK(BOP_EQ, COMPARISON)
<SQL>"<>"		 SUBTOK(BOP_NEQ, COMPARISON)
<SQL>"<"		SUBTOK(BOP_LT, COMPARISON)
<SQL>">"		SUBTOK(BOP_GT, COMPARISON)
<SQL>"<="		SUBTOK(BOP_LTE, COMPARISON)
<SQL>">="		SUBTOK(BOP_GTE, COMPARISON)
<SQL>":="		TOK(EQUALS)
<SQL>"::"		TOK(DOUBLE_COLON)
<SQL>":"		TOK(COLON)
<SQL>"=>"		TOK(KWD_TAG)

<SQL>":"[0-9]+ {
  char tmp[20];
  snprintf (tmp, sizeof (tmp), ":%d", atoi (yytext+1)); /* This sprintf(atoi()) is needed to normalize, say, ':012' into ':12' */
  yylval.box = t_sym_string (tmp);
  return PARAMETER_L;
}

<SQL>"?" {
  char tmp[20];
  snprintf (tmp, sizeof (tmp), ":%d", param_inx++);
  yylval.box = t_sym_string (tmp);
  return PARAMETER_L;
}
<SQL>[-+*/,.\!]	TOK(yytext[0])
<SQL>";"	{
	if (0 < scn3_lexdepth)
	  {
	    if (']' == scn3_parens[scn3_lexdepth-1].sp_close_paren)
	      yyerror ("Misplaced semicolon, check if square braces are balanced in expression");
	    /* TBD: smart check for other combinations. */
	  }
	TOK(yytext[0]) }

<SQL>"("		TOKOPEN('(',')')
<SQL>"["		TOKOPEN('[',']')
<SQL>")"		TOKCLOSE(')',')')
<SQL>"]"		TOKCLOSE(']',']')

	/* names */
<SQL>"\\"[A-Za-z_\x80-\xFF][A-Za-z0-9_:\\\x80-\xFF]*	TOKBOX(1, NAME)
	/* the commented double-quote below is to cure syntax highlighting */
<SQL>\"([^\"\n]|(\"\"))*\"	{ /*"*/ TOKBOX_QUOTED(1, NAME) }
	/*<SQL>\"[^\"\n]*\"	TOKBOX_QUOTED(1, NAME)*/
<SQL>[A-Za-z_\x80-\xFF][A-Za-z0-9_@\x80-\xFF]* {
  const struct keyword *k;
  char buf[MAX_WORD_LENGTH + 1], *cp, *sp;
  for (cp = buf, sp = yytext; *sp && cp < &buf[MAX_WORD_LENGTH];)
    *cp++ = toupper (*sp++);
  *cp = 0;
  if ((k = lex_hash_kw (buf, cp - buf)) != NULL)
    {
      yylval.strval = k->keiiyword;
      if (SPARQL_L == k->token)
        {
          scn3_include_fragment_t *outer;
          outer = scn3_include_stack + scn3_include_depth;
          outer->_.sif_saved_lineno = scn3_lineno;
          outer->_.sif_saved_plineno = scn3_plineno;
          outer->_.sif_saved_lineno_increment = scn3_lineno_increment;
          outer->_.sif_saved_lexdepth = scn3_lexdepth;
          outer->_.sif_skipped_part = strses_allocate ();
          BEGIN (SPARQL_SKIP);
          return SPARQL_L;
        }
      else
        return k->token;
    }
  TOKBOX_UPCASE (0, NAME);
}

	/* special names for MS SQL 'SELECT ... FOR XML EXPLICIT'  */
<SQL>"["[A-Za-z][A-Za-z0-9:/._-]*"!"    { BEGIN (MSSQL_XMLCOL); TOKBOX_TWOTRIMS(1,1,MSSQL_XMLCOL_NAME1); }
<SQL>"[\""[A-Za-z][A-Za-z0-9:/._-]*"\"!"    { BEGIN (MSSQL_XMLCOL); TOKBOX_TWOTRIMS(2,2,MSSQL_XMLCOL_NAME1); }
<MSSQL_XMLCOL>0*[1-9][0-9]?[0-9]?   { yylval.box = box_num(atoi(yytext)); return MSSQL_XMLCOL_INTNUM; }
<MSSQL_XMLCOL>[0-9]+		    { yyerror ("Invalid index in the description of XML column"); }
<MSSQL_XMLCOL>"!"[A-Za-z][A-Za-z0-9:/._-]*		{ TOKBOX(1,MSSQL_XMLCOL_NAME); }
<MSSQL_XMLCOL>"!\""[A-Za-z][A-Za-z0-9:/._-]*"\""	{ TOKBOX_TWOTRIMS(2,1,MSSQL_XMLCOL_NAME); }
<MSSQL_XMLCOL>"!"[A-Za-z][A-Za-z0-9:/._-]*"]"   { BEGIN(SQL); TOKBOX_TWOTRIMS(1,1,MSSQL_XMLCOL_NAMEZ); }
<MSSQL_XMLCOL>"!\""[A-Za-z][A-Za-z0-9:/._-]*"\"]"   { BEGIN(SQL); TOKBOX_TWOTRIMS(2,2,MSSQL_XMLCOL_NAMEZ); }
<MSSQL_XMLCOL>"!!"[A-Za-z][A-Za-z0-9:/._-]*"]"   { BEGIN(SQL); TOKBOX_TWOTRIMS(2,1,MSSQL_XMLCOL_NAMEYZ); }
<MSSQL_XMLCOL>"!!\""[A-Za-z][A-Za-z0-9:/._-]*"\"]"   { BEGIN(SQL); TOKBOX_TWOTRIMS(3,2,MSSQL_XMLCOL_NAMEYZ); }
<MSSQL_XMLCOL>.			    { yyerror ("Invalid character in the description of XML column"); }

	/* parameters */
<SQL>":"[A-Za-z][A-Za-z0-9_]* {
  yylval.strval = t_sym_string (yytext);
  return NAMED_PARAMETER;
}

	/* numbers */
<SQL>[0-9]+ {
  size_t ctr, len;
  long acc_lo, acc_hi;
  len = strlen (yytext);
  if (len < 10)
    {
      yylval.box = t_box_num_and_zero (atol (yytext));
      return INTNUM;
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
	  yylval.box = (caddr_t) num;
	  return (rc == NUMERIC_STS_SUCCESS ? APPROXNUM : NUM_ERROR);
	}
    }
  yylval.box = t_box_num_and_zero (atol (yytext));
  return INTNUM;
}

<SQL>\#i[0-9]+ {
  size_t ctr, len;
  iri_id_t * box = (iri_id_t*) t_alloc_box (sizeof (iri_id_t), DV_IRI_ID);
  len = strlen (yytext);
    *box = atoi (&yytext[2]);
    yylval.box = (caddr_t) box;
    return IRI_LIT;
}


<SQL>0hex[0-9A-Fa-f]* {
  size_t ctr, len;
  ptrlong res;
  len = strlen (yytext);
  ctr = 4;
  while ((ctr < len) && ('0' == yytext[ctr])) ctr++;
  if ((len-ctr) > 8)
    return NUM_ERROR; /* Too many significant digits */
  res = 0;
  while (ctr < len)
    {
      char c = toupper (yytext[ctr]);
      res = (res << 4) | ((c <= '9') ? ( c - '0') : (c + 10 - 'A'));
      ctr ++;
    }
  yylval.box = t_box_num_and_zero (res);
  return BINARYNUM;
}

<SQL>0x[0-9A-Fa-f]* {
            yylval.box = sqlp_hex_literal (yytext + 2, 0);
	    if (!yylval.box)
	      return NUM_ERROR;
	    return BINARYNUM;
}

<SQL>[0-9]+("."[0-9]*)* |
<SQL>"."[0-9]+ {
  numeric_t num = t_numeric_allocate ();
  int rc = numeric_from_string (num, yytext);
  if (NUMERIC_STS_SUCCESS == rc)
    {
      yylval.box = (caddr_t) num;
      return APPROXNUM;
    }
/*  numeric_free (num);*/
  yylval.box = t_box_double (atof (yytext));
  return APPROXNUM;
}

<SQL>[0-9]+[eE][+-]?[0-9]+	|
<SQL>[0-9]+"."[0-9]+[eE][+-]?[0-9]+ |
<SQL>"."[0-9]+[eE][+-]?[0-9]+	{
  yylval.box = t_box_double (atof (yytext));
  return APPROXNUM;
}

	/* HTML */

<SQL>"?>"		{ BEGIN (HTML); html_lines = NULL; }
<HTML>"<?vsp"		{ yytext[strlen (yytext) - 5] = 0; t_set_push (&html_lines, t_box_string (yytext));
			  yylval.box = sqlp_html_string (); BEGIN SQL; return HTMLSTR; }

<HTML>"<\?"[=/VU]	{ size_t len = strlen (yytext); char fl = yytext [len - 1]; yytext[len - 3] = 0;
                          if (fl == 'V')
			    fl = '=';
			  else if (fl == 'U')
			    fl = '/';
			t_set_push (&html_lines, t_box_string (yytext));
			  yylval.box = sqlp_html_string (); BEGIN SQL; unput (fl); return HTMLSTR; }

<HTML>[^<\r\n]+		{ yymore (); }
<HTML>"<"		{ yymore (); }
<HTML>{S_NL}		{ t_set_push (&html_lines, t_box_string (yytext)); scn3_lineno += scn3_lineno_increment; scn3_plineno += scn3_lineno_increment; }


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
		 national_char = 0;
		 uname_strlit = 0;
		 if (!parse_not_char_c_escape)
		   BEGIN(STRLIT);
		 else
		   BEGIN(NO_ESC_STRLIT);
	       } /* strliteral wants beg. quote */

<SQL>N'        {
  		 yymore();
		 national_char = 1;
		 uname_strlit = 0;
		 if (!parse_not_char_c_escape)
		   BEGIN(STRLIT);
		 else
		   BEGIN(NO_ESC_STRLIT);
	       } /* strliteral wants beg. quote */

<SQL>UNAME'        {
  		 yymore();
		 national_char = 0;
		 uname_strlit = 1;
		 if (!parse_not_char_c_escape)
		   BEGIN(STRLIT);
		 else
		   BEGIN(NO_ESC_STRLIT);
	       } /* strliteral wants beg. quote */

<STRLIT,NO_ESC_STRLIT>'      { /* saw closing quote - all done */
                 BEGIN(SQL); /* Back to SQL state. */
		 if (uname_strlit)
		   {
		     caddr_t raw = t_strliteral (yytext + 5 /* == strlen("UNAME")*/);
		     caddr_t tmp = box_dv_uname_nchars (raw, box_length (raw) - 1);
		     box_dv_uname_make_immortal (tmp);
		     yylval.box = tmp;
		     return UNAME_LITERAL;
		   }
		 yylval.box = national_char ? wideliteral (yytext) : t_strliteral (yytext);
		 if (!yylval.box)
		   yyerror (national_char ? "Invalid wide string literal" : "Invalid string literal");
		 return national_char ? WSTRING : STRING;
	       }

<STRLIT,NO_ESC_STRLIT>{S_NL}     { scn3_lineno += scn3_lineno_increment; scn3_plineno += scn3_lineno_increment; yymore(); } /* { BEGIN(SQL); yyerror("Unterminated string"); } */

<STRLIT>\\{S_NL}[^''\\\r\n]*  { scn3_lineno += scn3_lineno_increment; scn3_plineno += scn3_lineno_increment; yymore(); } /* Backslash + newline. */

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
	      yylval.box = strliteral (yytext);
	      return STRING;
	    }
	  else
	    yymore ();
	}

	<SQL>'[^'\n]*$ { yyerror ("Unterminated string"); }

	******	Commented piece ends here. */

<SQL>{S_NL}	{ save_str(" "); scn3_lineno += scn3_lineno_increment; scn3_plineno += scn3_lineno_increment; }
{S_NL}	{ yyerror ("unrecognized symbol"); /*scn3_lineno++; ECHO;*/ }

<SQL>[ \t]+	save_str(" ");	/* white space */

	/* Pragmas */
<SQL>"#"("pragma"[\ t]+)?"line"[ \t]+[0-9-]+([ \t]+[""][^""]+[""])?[ \t]*("--".*)?{S_NL} { scn3_pragma_line (yytext); scn3_lineno_increment = 1; scn3_plineno++; }
<SQL>"#"("pragma"[\ t]+)?"line"[ \t]+"push"[ \t]*("--".*)?{S_NL} { scn3_pragma_line_push (); scn3_lineno_increment = 1; scn3_plineno++; }
<SQL>"#"("pragma"[\ t]+)?"line"[ \t]+"pop"[ \t]*("--".*)?{S_NL} { scn3_pragma_line_pop (); scn3_lineno_increment = 1; scn3_plineno++; }
<SQL>"#"("pragma"[\ t]+)?"line"([ \t]+"reset")?[ \t]*("--".*)?{S_NL} { scn3_pragma_line_reset (); scn3_lineno_increment = 1; scn3_plineno++; }
<SQL>"#"("pragma"[\ t]+)?"line" { yyerror ("Ill formed #line"); }

<SQL>"#pragma"[ \t]+"prefix"[ \t]+	{
	BEGIN(PRAGMA_PREFIX);
	t_set_push (&scn3_namespaces, NULL);
	t_set_push (&scn3_namespaces, NULL); }

<PRAGMA_PREFIX>({SPAR_NCNAME_PREFIX}?)":"	{
	BEGIN(PRAGMA_PREFIX_2);
	scn3_namespaces->data = t_box_dv_uname_string (yytext); }

<PRAGMA_PREFIX_2>[ \t+]"<"([^<>''{}|^`\001-\040])*">"	{
	const char *langl = strchr (yytext, '<');
	BEGIN(SQL);
	scn3_namespaces->next->data = t_box_dv_uname_nchars (langl + 1, (yytext + yyleng - 2) - langl); }

<PRAGMA_PREFIX>.	{ yyerror ("Ill formed namespace prefix in #pragma prefix"); }
<PRAGMA_PREFIX><<EOF>>	{ yyerror ("Unexpected end of text in #pragma prefix"); }

<PRAGMA_PREFIX_2>.		{ yyerror ("Ill formed namespace IRI in #pragma prefix"); }
<PRAGMA_PREFIX_2><<EOF>>	{ yyerror ("Unexpected end of text in #pragma prefix"); }

<SQL>"#pragma" { yyerror ("Ill formed #pragma"); }
<SQL>"#" { yyerror ("Misused lattice sign ('#')"); }

<SQL>"--"[ \t]*"no_c_escapes+"[ \t]* { parse_not_char_c_escape = 1; }
<SQL>"--"[ \t]*"no_c_escapes-"[ \t]* { parse_not_char_c_escape = 0; }
<SQL>"--"[ \t]*"utf8_execs=yes"[ \t]* { parse_utf8_execs = 1; }
<SQL>"--"[ \t]*"utf8_execs=no"[ \t]* { parse_utf8_execs = 0; }
<SQL>"--"[ \t]*"pl_debug+"[ \t]* { parse_pldbg = 1; }
<SQL>"--src"[ \t]+[A-Za-z0-9_./\\-]+":"[0-9+-][0-9]*[ \t]*{S_NL} { sqlp_pl_file (yytext); scn3_lineno_increment = 1; scn3_plineno++; }
<SQL>"--"[^\r\n]*	;	/* comment */
<SQL>"/\*"	{ BEGIN (COMMENT); }
<COMMENT>"/\*"  { yyerror ("Nested C style comments not supported"); }
<COMMENT>"\*/"	{ BEGIN (SQL); }
<COMMENT>{S_NL}	{ scn3_lineno += scn3_lineno_increment; scn3_plineno += scn3_lineno_increment; }
<COMMENT>.	;

	/* IvAn/Fix4AritmSql/000828 Invalid lexems should be handled explicitly */
<SQL>([^A-Za-z0-9_'"+\-*/(){}<=>?.,:;# \t\r\n\[\]]+)		TOK(LEXICAL_ERROR)

        /* hex literal rules */
<SQL>X'		{
                  yymore();
		  BEGIN (HEXLIT);
                }

<HEXLIT>[0-9A-Fa-f]* yymore();

<HEXLIT>'	{
                  BEGIN (SQL);
		  yylval.box = sqlp_hex_literal (yytext + 2, 1);
		  if (!yylval.box)
		    return NUM_ERROR;
		  return BINARYNUM;
                }


        /* bit literal rules */
<SQL>B'		{
                  yymore();
		  BEGIN (BITLIT);
                }

<BITLIT>[0-1]+ yymore();

<BITLIT>'	{
                  BEGIN (SQL);
		  yylval.box = sqlp_bit_literal (yytext + 2, 1);
		  if (!yylval.box)
		    return NUM_ERROR;
		  return BINARYNUM;
                }


<SQL><<EOF>>	{
  if (scn3_include_depth <= 0 )
    yyterminate();
  else
    {
      scn3_include_fragment_t *outer;
      scn3_include_depth--;
      outer = scn3_include_stack + scn3_include_depth;
      yy_delete_buffer (YY_CURRENT_BUFFER);
      yy_switch_to_buffer (outer->sif_buffer);
      scn3_lineno = outer->_.sif_saved_lineno;
      scn3_plineno = outer->_.sif_saved_plineno;
      scn3_lineno_increment = outer->_.sif_saved_lineno_increment;
      /* No such assignment, because the fragment may have extra ')' at the end:
         scn3_lexdepth = outer->_.sif_saved_lexdepth; */
    }
  }

<SQL>.		TOK(LEXICAL_ERROR)

	/* Correct skip of SPARQL */

<SPARQL_SKIP>"("	TOKOPEN_SKIP ('(',')')
<SPARQL_SKIP>")"	{
    scn3_include_fragment_t *outer = scn3_include_stack + scn3_include_depth;
    if (outer->_.sif_saved_lexdepth == scn3_lexdepth)
      {
        spar_query_env_t sparqre;
        BEGIN(SQL);
        scn3_sparp_inline_subselect (&sparqre, "\n)\n", outer);
        yy_scan_buffer (sparqre.sparqre_compiled_text, box_length (sparqre.sparqre_compiled_text) - 1);
      }
    else
      {
        TOKCLOSE_SKIP (')',')')
      }
  }

<SPARQL_SKIP>";"	{
    scn3_include_fragment_t *outer = scn3_include_stack + scn3_include_depth;
    if (outer->_.sif_saved_lexdepth == scn3_lexdepth)
      {
        spar_query_env_t sparqre;
        BEGIN(SQL);
        scn3_sparp_inline_subselect (&sparqre, "\n;\n", outer);
        yy_scan_buffer (sparqre.sparqre_compiled_text, box_length (sparqre.sparqre_compiled_text) - 1);
      }
    else
      {
        TOK_SKIP;
      }
  }

<SPARQL_SKIP>"{"	TOKOPEN_SKIP ('{','}')
<SPARQL_SKIP>"}"	TOKCLOSE_SKIP ('}','}')
<SPARQL_SKIP>"["	TOKOPEN_SKIP ('[',']')
<SPARQL_SKIP>"]"	TOKCLOSE_SKIP (']',']')
<SPARQL_SKIP>"<"([^<>''{}|^`\001-\040])*">"		TOK_SKIP
<SPARQL_SKIP>([""][^""\\\n]*[""])|([''][^''\\\n]*[''])	TOK_SKIP

<SPARQL_SKIP>['']['']['']		{ BEGIN(SPARQL_SSSQ_SKIP); TOK_SKIP }
<SPARQL_SKIP>[""][""][""]		{ BEGIN(SPARQL_DDDQ_SKIP); TOK_SKIP }
<SPARQL_SSSQ_SKIP>['']['']['']	{ BEGIN(SPARQL_SKIP); TOK_SKIP }
<SPARQL_DDDQ_SKIP>[""][""][""]	{ BEGIN(SPARQL_SKIP); TOK_SKIP }
<SPARQL_SSSQ_SKIP>(([''](['']?))?{S_NL})		TOK_NL_SKIP
<SPARQL_DDDQ_SKIP>(([""]([""]?))?{S_NL})		TOK_NL_SKIP
<SPARQL_SSSQ_SKIP>((([''](['']?))?({SPAR_SQ_PLAIN}|{SPAR_ECHAR}))+)		{ yymore(); }
<SPARQL_DDDQ_SKIP>((([""]([""]?))?({SPAR_DQ_PLAIN}|{SPAR_ECHAR}))+)		{ yymore(); }
<SPARQL_SSSQ_SKIP>[\\]		{ yyerror ("Bad escape sequence in a SPARQL long single-quoted string"); }
<SPARQL_DDDQ_SKIP>[\\]		{ yyerror ("Bad escape sequence in a SPARQL long double-quoted string"); }
<SPARQL_SSSQ_SKIP>.			{ yyerror ("Bad character in a SPARQL long single-quoted string"); }
<SPARQL_DDDQ_SKIP>.			{ yyerror ("Bad character in a SPARQL long double-quoted string"); }
<SPARQL_SSSQ_SKIP><<EOF>>		{ yyerror ("Unterminated SPARQL long single-quoted string"); }
<SPARQL_DDDQ_SKIP><<EOF>>		{ yyerror ("Unterminated SPARQL long double-quoted string"); }


<SPARQL_SKIP>['']		{ BEGIN(SPARQL_SQ_SKIP); TOK_SKIP }
<SPARQL_SKIP>[""]		{ BEGIN(SPARQL_DQ_SKIP); TOK_SKIP }
<SPARQL_SQ_SKIP>['']		{ BEGIN(SPARQL_SKIP); TOK_SKIP }
<SPARQL_DQ_SKIP>[""]		{ BEGIN(SPARQL_SKIP); TOK_SKIP }
<SPARQL_SQ_SKIP>{S_NL}	{ yyerror ("End-of-line in a SPARQL short single-quoted string"); }
<SPARQL_DQ_SKIP>{S_NL}	{ yyerror ("End-of-line in a SPARQL short double-quoted string"); }
<SPARQL_SQ_SKIP>(({SPAR_SQ_PLAIN}|{SPAR_ECHAR})+)		TOK_SKIP
<SPARQL_DQ_SKIP>(({SPAR_DQ_PLAIN}|{SPAR_ECHAR})+)		TOK_SKIP
<SPARQL_SQ_SKIP>[\\]		{ yyerror ("Bad escape sequence in a SPARQL short single-quoted string"); }
<SPARQL_DQ_SKIP>[\\]		{ yyerror ("Bad escape sequence in a SPARQL short double-quoted string"); }
<SPARQL_SQ_SKIP><<EOF>>		{ yyerror ("Unterminated SPARQL short single-quoted string"); }
<SPARQL_DQ_SKIP><<EOF>>		{ yyerror ("Unterminated SPARQL short double-quoted string"); }

<SPARQL_SKIP>[^''""\\\n\r(){}\[\];]+ TOK_SKIP
<SPARQL_SKIP><<EOF>>  {
    scn3_include_fragment_t *outer = scn3_include_stack + scn3_include_depth;
    spar_query_env_t sparqre;
    BEGIN(SQL);
    scn3_sparp_inline_subselect (&sparqre, "\n;\n", outer);
    yy_scan_buffer (sparqre.sparqre_compiled_text, box_length (sparqre.sparqre_compiled_text) - 1);
  }

<SPARQL_SKIP>{S_NL}	TOK_NL_SKIP
<SPARQL_SKIP>.		TOK(LEXICAL_ERROR);	/* random non-SQL, non-HTML text */

.		TOK(LEXICAL_ERROR);	/* random non-SQL, non-HTML text */
%%


void
sql_yy_reset (void)
{
  BEGIN SQL;
  scn3_lineno = 1;
  scn3_plineno = 1;
  scn3_lineno_increment = 1;
  scn3_lexdepth = 0;
  scn3_include_depth = 0;
  scn3_namespaces = NULL;
  scn3_pragma_line_reset ();
}

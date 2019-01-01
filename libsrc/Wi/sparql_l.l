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
%option case-sensitive
%option never-interactive
%option noyyalloc
%option noyyrealloc
%option noyyfree
%option noyywrap
%option nounput
%option reentrant
%option extra-type="struct sparp_s *"

%{
#include "Dk.h"
#include "xmltree.h"
#include "sparql.h"
#include "sparql_p.h"
#include "numeric.h"
#include "sparqlwords.h"

struct yyguts_t;

#define sparyyerror(strg) sparyyerror_impl(yyextra, yytext, (strg))

#define sparyylval (((YYSTYPE *)(yylval))[0])

#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
  do \
    { \
      int rest_len = yyextra->sparp_text_len - yyextra->sparp_text_ofs; \
      int get_len = (max_size); \
      if (get_len > rest_len) \
	get_len = rest_len; \
      memcpy ((buf), (yyextra->sparp_text + yyextra->sparp_text_ofs), get_len); \
      (result) = get_len; \
      yyextra->sparp_text_ofs += get_len; \
    } while (0);

int sparscn_yy_null = YY_NULL;


#define GET_OUTER_BEGIN			((0 == yyextra->sparp_lexdepth) ? UNREACHEABLE : yyextra->sparp_lexstates[yyextra->sparp_lexdepth-1])
#define GET_CURRENT_BEGIN		yyextra->sparp_lexstates[yyextra->sparp_lexdepth]
#define SET_CURRENT_BEGIN(state)	yyextra->sparp_lexstates[yyextra->sparp_lexdepth] = (state)
#define SET_INNER_BEGIN(state)		yyextra->sparp_lexstates[yyextra->sparp_lexdepth+1] = (state)
#define BEGIN_NEW_CURRENT(state)	BEGIN (yyextra->sparp_lexstates[yyextra->sparp_lexdepth] = (state))
#define BEGIN_CURRENT			BEGIN (yyextra->sparp_lexstates[yyextra->sparp_lexdepth])

static const char *sparyyerror_msg_toodeep = "The expression is too complex, or some closing parentheses are missing";
static const char *sparyyerror_msg_tooshallow = "Too many closing parentheses";

#define BEGIN_INNER \
  do \
    { \
      if (SPARP_MAX_LEX_DEPTH <= yyextra->sparp_lexdepth) \
	sparyyerror (sparyyerror_msg_toodeep); \
      else \
	{ \
	  yyextra->sparp_lexdepth += 1; \
	  BEGIN_CURRENT; \
	} \
    } while(0)

#define BEGIN_INNER_1(i) do { SET_INNER_BEGIN((i)); BEGIN_INNER; yyextra->sparp_lexpars[yyextra->sparp_lexdepth-1]='x'; } while (0)
#define BEGIN_INNER_2(i,c) do { SET_CURRENT_BEGIN((c)); SET_INNER_BEGIN((i)); BEGIN_INNER; yyextra->sparp_lexpars[yyextra->sparp_lexdepth-1]='x'; } while (0)

#define BEGIN_OUTER \
  do \
    { \
      if (0 == yyextra->sparp_lexdepth) \
	sparyyerror (sparyyerror_msg_tooshallow); \
      else \
	{ \
	  yyextra->sparp_lexdepth -= 1; \
	  BEGIN_CURRENT; \
	} \
    } while(0)

/* macro to save the text of a token */
#define SV  yylval->box = t_box_dv_short_nchars(yytext, yyleng);

/* macro to save the text and return a token */
#define TOK(name) { /*SV;*/ return name; }

/* macros to save the text of opening parenthesis and return a token */
#define TOKPAR_FAKE_OPEN(closing_char, state_i) \
    /*SV;*/ \
    if (((closing_char) == '}') && (yyextra->sparp_lexdepth >= SPARP_MAX_BRACE_DEPTH)) \
      sparyyerror ("Curly brace is nested too deep"); \
    SET_INNER_BEGIN (state_i); \
    BEGIN_INNER; \
    yyextra->sparp_lexpars[yyextra->sparp_lexdepth-1]=(closing_char)

#define TOKPAR_OPEN(name, closing_char, state_i) \
  { \
    TOKPAR_FAKE_OPEN(closing_char, state_i); \
    return name; \
  }

#define TOKPAR_OPEN_4(name, closing_char, state_i, state_c) \
  { \
    /*SV;*/ \
    SET_CURRENT_BEGIN (state_c); \
    TOKPAR_FAKE_OPEN(closing_char, state_i); \
    return name; \
  }

/* macros to save the text of closing parenthesis and return a token */
#define TOKPAR_FAKE_CLOSE(closing_char) \
    /*SV;*/ BEGIN_OUTER; \
    if (closing_char != yyextra->sparp_lexpars[yyextra->sparp_lexdepth]) \
      sparyyerror ("Parentheses are not balanced"); \

#define TOKPAR_CLOSE(name, closing_char) \
  { TOKPAR_FAKE_CLOSE(closing_char) \
    return name; \
  }

/* macro to save the text of closing parenthesis and return a token */
#define TOKPAR_CLOSE_3(name, closing_char, state) \
  { /*SV;*/ BEGIN_OUTER; BEGIN_NEW_CURRENT(state); \
    if (closing_char != yyextra->sparp_lexpars[yyextra->sparp_lexdepth]) \
      sparyyerror ("Parentheses are not balanced"); \
    return name; \
  }

#define TOKBOX_L(n,name,lex_type_descr) { \
    yylval->box = t_box_dv_uname_string (yytext+n); \
    TOKBOX_L_FINAL(name,lex_type_descr) }

/* No more dedicated UNAME case. All names are UNAMES :)
#define TOKBOX_UNAME_L(n,name,lex_type_descr) { yylval->box = t_box_dv_uname_string (yytext+n); \
    TOKBOX_L_FINAL(name,lex_type_descr) } */

#define TOKBOX_UPCASE_L(n,name,lex_type_descr) { \
    caddr_t tmp = sqlp_box_id_upcase (yytext+n); \
    yylval->box = t_box_dv_uname_string (tmp); \
    dk_free_box (tmp); \
    TOKBOX_L_FINAL(name,lex_type_descr) }

#define TOKBOX_QUOTED_L(n,name,lex_type_descr) { \
    caddr_t tmp = sqlp_box_id_quoted (yytext+n); \
    yylval->box = t_box_dv_uname_string (tmp); \
    dk_free_box (tmp); \
    TOKBOX_L_FINAL(name,lex_type_descr) }

#define TOKPAR_OPEN_LNAME(n,name,closing_char,state_i,state_c) \
{ \
    SET_CURRENT_BEGIN (state_c); \
    TOKPAR_FAKE_OPEN(closing_char, state_i); \
    do { \
      char *name_begin; \
      int name_len; \
      name_begin = yytext + (n); \
      name_begin += strspn (name_begin, " \t\r"); \
      name_len = strcspn (name_begin, " \t\r{"); \
      yylval->box = t_box_dv_uname_nchars (name_begin, name_len); \
	} while(0); \
    TOKBOX_L_FINAL(name,"Node name") }

void sparyyerror_if_long_qname (caddr_t box, const char *lex_type_descr, struct yyguts_t *yyg);

#define TOKBOX_Q_FINAL(name,lex_type_descr) \
    if (box_length (yylval->box) > MAX_XML_LNAME_LENGTH) \
      sparyyerror_if_long_qname (yylval->box, lex_type_descr, yyg); \
    return (name);

#define TOKBOX_Q(n,name,lex_type_descr) { \
    yylval->box = t_box_dv_uname_string (yytext+(n)); \
    TOKBOX_Q_FINAL(name,lex_type_descr) }

#define TOKBOX_Q2(n1,n2,name,lex_type_descr) { \
    yylval->box = t_box_dv_uname_nchars (yytext + (n1), strlen(yytext) - ((n1)+(n2))); \
    TOKBOX_Q_FINAL(name,lex_type_descr) }

/* No more special UNAME case :)
#define TOKBOX_UNAME_Q(n,name,lex_type_descr) { \
    yylval->box = t_box_dv_uname_string (yytext+(n)); \
    TOKBOX_Q_FINAL(name,lex_type_descr) } */

int sparscn_NUMBER_int (YYSTYPE *yylval, struct yyguts_t * yyg);
int sparscn_NUMBER_decimal (YYSTYPE *yylval, struct yyguts_t * yyg);
int sparscn_NUMBER_double (YYSTYPE *yylval, struct yyguts_t * yyg);

extern int sparyylex (YYSTYPE *yylval, yyscan_t yyscanner);
#define YY_DECL int sparyylex (YYSTYPE *yylval, yyscan_t yyscanner)


void *
sparyyalloc (yy_size_t  size, yyscan_t yyscanner)
{
  return (void *) t_alloc_box (size, DV_STRING);
}

void *
sparyyrealloc  (void * ptr, yy_size_t  sz , yyscan_t yyscanner)
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
sparyyfree (void * ptr , yyscan_t yyscanner)
{
}

%}

	/* Top-level SPARQL state */
%x SPARQL

	/* Internals of single-quoted SPARQL string lit */
%x SPARQL_SQ

	/* Internals of double-quoted SPARQL string lit */
%x SPARQL_DQ

	/* Internals of triple-single-quoted SPARQL string lit */
%x SPARQL_SSSQ

	/* Internals of triple-double-quoted SPARQL string lit */
%x SPARQL_DDDQ

	/* Whitespace between 'COUNT' keyword and '(' or 'DISTINCT' after it */
%x SPARQL_AFTER_COUNT

	/* Whitespace between 'IDENTIFIED' keyword and 'BY' keyword */
%x SPARQL_AFTER_IDENTIFIED

	/* Whitespace between 'NOT' keyword and 'FROM', 'IN' or 'EXISTS' after it */
%x SPARQL_AFTER_NOT

	/* Whitespace between 'WHERE'/'SQLQUERY' keyword and '(' or '{' after it */
%x SPARQL_AFTER_WHERE

	/* A fragment of SQL text between 'WHERE (' and matching ')' */
%x SPARQL_SQL_FRAGMENT

	/* A comment inside SPARQL_SQL_FRAGMENT */
%x SPARQL_SQL_COMMENT

	/* Single-quoted string inside SPARQL_SQL_FRAGMENT */
%x SPARQL_SQL_SQSTRING

	/* Special unreacheable state to fill the first item of yyextra->sparp_lexstates */
%x UNREACHEABLE

A		([Aa])
B		([Bb])
C		([Cc])
D		([Dd])
E		([Ee])
F		([Ff])
G		([Gg])
H		([Hh])
I		([Ii])
J		([Jj])
K		([Kk])
L		([Ll])
M		([Mm])
N		([Nn])
O		([Oo])
P		([Pp])
Q		([Qq])
R		([Rr])
S		([Ss])
T		([Tt])
U		([Uu])
V		([Vv])
W		([Ww])
X		([Xx])
Y		([Yy])
Z		([Zz])

INTEGER_LITERAL ([0-9]+)
DECIMAL_LITERAL (([0-9]+"."[0-9]*)|("."[0-9]+))
DOUBLE_LITERAL	(({INTEGER_LITERAL}|{DECIMAL_LITERAL})[eE][+-]?[0-9]+)

SPAR_SQ_PLAIN	([^\\''\r\n])
SPAR_DQ_PLAIN	([^\\""\r\n])
SPAR_ECHAR	([\\]([atbvnrf\\""'']|("u"{HEX}{HEX}{HEX}{HEX})|("U"{HEX}{HEX}{HEX}{HEX}{HEX}{HEX}{HEX}{HEX})))
S_NL		((\r\n)|(\n\r)|\n|\r)
HEX		([0-9A-Fa-f])

PN_CHARS_BASE	([A-Za-z\x7f-\xfe])
PN_CHARS_U_09	([A-Za-z0-9_\x7f-\xfe])
PN_CHARS	([A-Za-z0-9_\x7f-\xfe-])
PN_PREFIX	({PN_CHARS_BASE}(([.]*{PN_CHARS})*))
PN_LOCAL	({PN_CHARS_U_09}(([.]*{PN_CHARS})*))
SPAR_VARNAME	([A-Za-z0-9_][A-Za-z0-9_\x7f-\xfe]*)
SPAR_PLAIN_SQLNAME	([A-Za-z_][A-Za-z0-9_]*)
SPAR_DQ_SQLNAME		([""][^""\\\r\n]*[""])
SPAR_SQLNAME		(([A-Za-z_][A-Za-z0-9_]*)|([""][^""\\\r\n]*[""]))
SPAR_PARAMNAME	(([A-Z]+"::")?(({SPAR_SQLNAME}("."{SPAR_SQLNAME})?)|(":"{SPAR_SQLNAME})|(":"[0-9]+)))

%%

	/* Plain non-keyword punctuators */

<SPARQL>"&&"		{ return _AMP_AMP	; }
<SPARQL>"`"		{ return _BACKQUOTE	; }
<SPARQL>"!"		{ return _BANG		; }
<SPARQL>"|"		{ return _BAR		; }
<SPARQL>"||"		{ return _BAR_BAR	; }
<SPARQL>"^"		{ return _CARET		; }
<SPARQL>"^^"		{ return _CARET_CARET	; }
<SPARQL>","		{ return _COMMA		; }
<SPARQL>"."		{ return _DOT		; }
<SPARQL>"="		{ return _EQ		; }
<SPARQL>">="		{ return _GE		; }
<SPARQL>">"		{ return _GT		; }
<SPARQL>"<="		{ return _LE		; }
<SPARQL>"<"		{ return _LT		; }
<SPARQL>"-"		{ yylval->token_type = yyextra->sparp_lexdepth; return _MINUS		; }
<SPARQL>"!="		{ return _NOT_EQ	; }
<SPARQL>"+"		{ yylval->token_type = yyextra->sparp_lexdepth; return _PLUS		; }
<SPARQL>"+>"		{ return _PLUS_GT	; }
<SPARQL>"?"		{ return _QMARK		; }
<SPARQL>";"		{ return _SEMI		; }
<SPARQL>"/"		{ return _SLASH		; }
<SPARQL>"*"		{ return _STAR		; }
<SPARQL>"*>"		{ return _STAR_GT	; }

	/* Keyword punctuators */

<SPARQL>"a"				{ return a_L		; }

	/* Grouping non-keyword punctuators */

<SPARQL>"("				TOKPAR_OPEN (_LPAR,')', GET_CURRENT_BEGIN)
<SPARQL>")"				TOKPAR_CLOSE (_RPAR,')')
<SPARQL>"{"				TOKPAR_OPEN (_LBRA,'}', GET_CURRENT_BEGIN)
<SPARQL>"}"				TOKPAR_CLOSE (_RBRA,'}')
<SPARQL>"["				TOKPAR_OPEN (_LSQBRA,']', GET_CURRENT_BEGIN)
<SPARQL>"]"				TOKPAR_CLOSE (_RSQBRA,']')

	/* Name lexems */

<SPARQL>"<"([^<>"{}|^`\001-\040\\])*">"	{
    yylval->box = t_box_dv_uname_nchars (yytext + 1, yyleng - 2);
    return Q_IRI_REF;
  }

<SPARQL>({PN_PREFIX}?)":"{PN_LOCAL}	{ TOKBOX_Q(0,QNAME,"qualified URI"); }
<SPARQL>({PN_PREFIX}?)":"		{ TOKBOX_Q(0,QNAME_NS,"namespace"); }
<SPARQL>"_:"{PN_LOCAL}			{ TOKBOX_Q(0,BLANK_NODE_LABEL,"blank node label"); }

<SPARQL>[?$]{SPAR_VARNAME}	{
    yylval->box = t_box_dv_uname_nchars (yytext + 1, yyleng - 1);
    return QD_VARNAME;
  }

<SPARQL>[?$]":"{SPAR_PARAMNAME}	{
    yylval->box = t_box_dv_uname_nchars (yytext + 1, yyleng - 1);
    return QD_COLON_PARAMNAME;
  }

<SPARQL>[?$]"?"	{
    char buf[20]; sprintf (buf, ":%d", yyextra->sparp_sparqre->sparqre_param_ctr[0]);
    yyextra->sparp_sparqre->sparqre_param_ctr[0] += 1;
    yylval->box = t_box_dv_uname_string (buf);
    return QD_COLON_PARAMNUM;
  }

<SPARQL>"@"([a-zA-Z]+)(("-"([a-zA-Z0-9]+))*)	{
    yylval->box = t_box_dv_uname_nchars (yytext + 1, yyleng - 1);
    return LANGTAG;
  }

<SPARQL>{SPAR_PLAIN_SQLNAME}	{
    const struct sparql_keyword *sk = sparql_lex_hash_kw (yytext, yyleng);
    if (NULL == sk)
      {
        yylval->box = t_box_dv_short_nchars (yytext, yyleng); return SPARQL_PLAIN_ID;
      }
    switch (sk->token)
      {
      case COUNT_L: BEGIN SPARQL_AFTER_COUNT; break;
      case IDENTIFIED_L: BEGIN SPARQL_AFTER_IDENTIFIED; return IDENTIFIED_L;
      case NOT_L: BEGIN SPARQL_AFTER_NOT; break;
      case WHERE_L: BEGIN SPARQL_AFTER_WHERE; return WHERE_L;
      case SQLQUERY_L: BEGIN SPARQL_AFTER_WHERE; return SQLQUERY_L;
      case SPARQL_BIF: yylval->token_type = sk->subtype; return SPARQL_BIF;
      default: return sk->token;
      } }

<SPARQL>{SPAR_SQLNAME}"."{SPAR_SQLNAME} { yylval->box = t_box_dv_short_nchars (yytext, yyleng); return SPARQL_SQL_ALIASCOLNAME; }
<SPARQL>{SPAR_SQLNAME}"."{SPAR_SQLNAME}?"."{SPAR_SQLNAME} { yylval->box = t_box_dv_short_nchars (yytext, yyleng); return SPARQL_SQL_QTABLENAME; }
<SPARQL>{SPAR_SQLNAME}"."{SPAR_SQLNAME}?"."{SPAR_SQLNAME}"."{SPAR_SQLNAME} { yylval->box = t_box_dv_short_nchars (yytext, yyleng); return SPARQL_SQL_QTABLECOLNAME; }

	/* Numeric lexems */

<SPARQL>{INTEGER_LITERAL}			{ return sparscn_NUMBER_int (yylval, yyg); }
<SPARQL>{DECIMAL_LITERAL}			{ return sparscn_NUMBER_decimal (yylval, yyg); }
<SPARQL>{DOUBLE_LITERAL}			{ return sparscn_NUMBER_double (yylval, yyg); }

	/* String lexems */

<SPARQL>([""][^""\\\n]*[""])|([''][^''\\\n]*['']) {
    yylval->box = t_box_dv_short_nchars (yytext+1, yyleng - 2);
    return SPARQL_STRING;
  }

<SPARQL>['']['']['']		{ yymore(); SET_INNER_BEGIN(SPARQL_SSSQ); BEGIN_INNER; }
<SPARQL>[""][""][""]		{ yymore(); SET_INNER_BEGIN(SPARQL_DDDQ); BEGIN_INNER; }
<SPARQL_SSSQ>['']['']['']	{ yylval->box = spar_strliteral (yyextra, yytext, 1, 0); BEGIN_OUTER; return SPARQL_STRING; }
<SPARQL_DDDQ>[""][""][""]	{ yylval->box = spar_strliteral (yyextra, yytext, 1, 0); BEGIN_OUTER; return SPARQL_STRING; }
<SPARQL_SSSQ>(([''](['']?))?{S_NL})		{ yyextra->sparp_lexlineno++; yymore(); }
<SPARQL_DDDQ>(([""]([""]?))?{S_NL})		{ yyextra->sparp_lexlineno++; yymore(); }
<SPARQL_SSSQ>((([''](['']?))?({SPAR_SQ_PLAIN}|{SPAR_ECHAR}))+)		{ yymore(); }
<SPARQL_DDDQ>((([""]([""]?))?({SPAR_DQ_PLAIN}|{SPAR_ECHAR}))+)		{ yymore(); }
<SPARQL_SSSQ>[\\]		{ sparyyerror ("Bad escape sequence in a long single-quoted string"); }
<SPARQL_DDDQ>[\\]		{ sparyyerror ("Bad escape sequence in a long double-quoted string"); }
<SPARQL_SSSQ>.			{ sparyyerror (t_box_sprintf (100, "Bad character '%c' (0x%x) in a long single-quoted string", yytext[0], (unsigned int)((unsigned char)(yytext[0])))); }
<SPARQL_DDDQ>.			{ sparyyerror (t_box_sprintf (100, "Bad character '%c' (0x%x) in a long double-quoted string", yytext[0], (unsigned int)((unsigned char)(yytext[0])))); }
<SPARQL_SSSQ><<EOF>>		{ sparyyerror ("Unterminated long single-quoted string"); }
<SPARQL_DDDQ><<EOF>>		{ sparyyerror ("Unterminated long double-quoted string"); }


<SPARQL>['']		{ yymore(); SET_INNER_BEGIN(SPARQL_SQ); BEGIN_INNER; }
<SPARQL>[""]		{ yymore(); SET_INNER_BEGIN(SPARQL_DQ); BEGIN_INNER; }
<SPARQL_SQ>['']		{ yylval->box = spar_strliteral (yyextra, yytext, 0, 0); BEGIN_OUTER; return SPARQL_STRING; }
<SPARQL_DQ>[""]		{ yylval->box = spar_strliteral (yyextra, yytext, 0, 0); BEGIN_OUTER; return SPARQL_STRING; }
<SPARQL_SQ>{S_NL}	{ sparyyerror ("End-of-line in a short single-quoted string"); yymore(); }
<SPARQL_DQ>{S_NL}	{ sparyyerror ("End-of-line in a short double-quoted string"); yymore(); }
<SPARQL_SQ>(({SPAR_SQ_PLAIN}|{SPAR_ECHAR})+)		{ yymore(); }
<SPARQL_DQ>(({SPAR_DQ_PLAIN}|{SPAR_ECHAR})+)		{ yymore(); }
<SPARQL_SQ>[\\]		{ sparyyerror ("Bad escape sequence in a short single-quoted string"); }
<SPARQL_DQ>[\\]		{ sparyyerror ("Bad escape sequence in a short double-quoted string"); }
<SPARQL_SQ><<EOF>>		{ sparyyerror ("Unterminated short single-quoted string"); }
<SPARQL_DQ><<EOF>>		{ sparyyerror ("Unterminated short double-quoted string"); }


	/* Whitespace after COUNT keyword */
<SPARQL_AFTER_COUNT>"(" { BEGIN SPARQL; TOKPAR_OPEN (COUNT_LPAR, ')', GET_CURRENT_BEGIN) }
<SPARQL_AFTER_COUNT>{D}{I}{S}{T}{I}{N}{C}{T} { BEGIN SPARQL; return COUNT_DISTINCT_L; }
<SPARQL_AFTER_COUNT><<EOF>>	{ sparyyerror ("Unexpected end of SPARQL expression after COUNT keyword"); }

	/* Whitespace after IDENTIFIED keyword */

<SPARQL_AFTER_IDENTIFIED>{B}{Y}		{ BEGIN SPARQL; return BY_L; }
<SPARQL_AFTER_IDENTIFIED><<EOF>>	{ sparyyerror ("Unexpected end of SPARQL expression after IDENTIFIED keyword"); }

	/* Whitespace after NOT keyword */
<SPARQL_AFTER_NOT>{E}{X}{I}{S}{T}{S}	{ BEGIN SPARQL; return NOT_EXISTS_L; }
<SPARQL_AFTER_NOT>{F}{R}{O}{M}		{ BEGIN SPARQL; return NOT_FROM_L; }
<SPARQL_AFTER_NOT>{I}{N}		{ BEGIN SPARQL; return NOT_IN_L; }
<SPARQL_AFTER_NOT>{N}{U}{L}{L}		{ BEGIN SPARQL; return NOT_NULL_L; }
<SPARQL_AFTER_NOT>{U}{S}{I}{N}{G}	{ BEGIN SPARQL; return NOT_USING_L; }
<SPARQL_AFTER_NOT><<EOF>>	{ sparyyerror ("Unexpected end of SPARQL expression after NOT keyword"); }

	/* SQL fragments */

<SPARQL_AFTER_WHERE>"{" { BEGIN SPARQL; TOKPAR_OPEN (_LBRA, '}', GET_CURRENT_BEGIN) }
<SPARQL_AFTER_WHERE>"(" { BEGIN SPARQL; TOKPAR_OPEN (_LPAR, ')', SPARQL_SQL_FRAGMENT) }
<SPARQL_AFTER_WHERE>['']['']['']	{ SET_INNER_BEGIN(SPARQL_SSSQ); BEGIN_INNER; }
<SPARQL_AFTER_WHERE>[""][""][""]	{ SET_INNER_BEGIN(SPARQL_DDDQ); BEGIN_INNER; }
<SPARQL_AFTER_WHERE>['']		{ SET_INNER_BEGIN(SPARQL_SQ); BEGIN_INNER; }
<SPARQL_AFTER_WHERE>[""]		{ SET_INNER_BEGIN(SPARQL_DQ); BEGIN_INNER; }
<SPARQL_AFTER_WHERE><<EOF>>	{ sparyyerror ("Unexpected end of SPARQL expression after WHERE keyword"); }

<SPARQL_SQL_FRAGMENT>[^-''""/(){}]+ { yymore(); }

<SPARQL_SQL_FRAGMENT>"{"	{ TOKPAR_FAKE_OPEN('}', SPARQL_SQL_FRAGMENT); yymore(); }
<SPARQL_SQL_FRAGMENT>"}"	{ TOKPAR_FAKE_CLOSE('}'); yymore(); }
<SPARQL_SQL_FRAGMENT>"("	{ TOKPAR_FAKE_OPEN(')', SPARQL_SQL_FRAGMENT); yymore(); }
<SPARQL_SQL_FRAGMENT>")"	{
    TOKPAR_FAKE_CLOSE(')');
    if (SPARQL == GET_CURRENT_BEGIN)
      {
        yylval->box = t_box_dv_short_nchars (yytext, yyleng-1);
        return SPARQL_SQLTEXT;
      }
    else
      yymore();
  }

<SPARQL_SQL_FRAGMENT>("--".*)?{S_NL}	{ yyextra->sparp_lexlineno++; yymore(); }
<SPARQL_SQL_FRAGMENT>"--".*	 { sparyyerror ("Unterminated comment in SQL fragment after WHERE keyword"); }
<SPARQL_SQL_FRAGMENT>"-"		{ yymore(); }
<SPARQL_SQL_FRAGMENT>['']	{ BEGIN SPARQL_SQL_SQSTRING; yymore(); }
<SPARQL_SQL_FRAGMENT>[""]([^""\r\n]+)[""]	{ yymore(); }
<SPARQL_SQL_FRAGMENT>[""][^""\r\n]* { sparyyerror ("Unterminated double-quoted identifier in SQL fragment after WHERE keyword"); }

<SPARQL_SQL_SQSTRING>['']	{ BEGIN SPARQL_SQL_FRAGMENT; yymore(); }
<SPARQL_SQL_SQSTRING>{S_NL}     { yyextra->sparp_lexlineno++; yymore(); }
<SPARQL_SQL_SQSTRING>\\{S_NL}[^''\\\r\n]*  { yyextra->sparp_lexlineno++; yymore(); }
<SPARQL_SQL_SQSTRING>\\.[^''\\\r\n]*	{ yymore(); }
<SPARQL_SQL_SQSTRING>[''][''][^''\\\r\n]*  { yymore(); }
<SPARQL_SQL_SQSTRING>[^''\\\r\n]+ { yymore(); }
<SPARQL_SQL_SQSTRING><<EOF>>	{ sparyyerror ("Unterminated single-quoted string in SQL fragment after WHERE keyword"); }

	/* Whitespace and comments */

<SPARQL,SPARQL_AFTER_COUNT,SPARQL_AFTER_IDENTIFIED,SPARQL_AFTER_NOT,SPARQL_AFTER_WHERE>("#"(.*))?{S_NL}	{ yyextra->sparp_lexlineno++; }
<SPARQL,SPARQL_AFTER_COUNT,SPARQL_AFTER_IDENTIFIED,SPARQL_AFTER_NOT,SPARQL_AFTER_WHERE>"#"(.*)		{ }
<SPARQL,SPARQL_AFTER_COUNT,SPARQL_AFTER_IDENTIFIED,SPARQL_AFTER_NOT,SPARQL_AFTER_WHERE>[ \t]+		{ }

<SPARQL_SQL_FRAGMENT>"/\*"	{ BEGIN (SPARQL_SQL_COMMENT); yymore(); }
<SPARQL_SQL_FRAGMENT><<EOF>>	{ sparyyerror ("Unterminated SQL fragment after WHERE keyword"); }

<SPARQL_SQL_COMMENT>"/\*"  { sparyyerror ("Nested C style comments not supported"); }
<SPARQL_SQL_COMMENT>"\*/"	{ BEGIN (SPARQL_SQL_FRAGMENT); yymore(); }
<SPARQL_SQL_COMMENT>.|((([^/\r\n*])|([*][^/\r\n*]))+)	{ yymore(); }

	/* Traps; these rules should be latest rules in the file. */

<SPARQL_AFTER_COUNT>.		{ sparyyerror ("Only '(' and DISTINCT are allowed after COUNT keyword in SPARQL expression"); }
<SPARQL_AFTER_IDENTIFIED>.	{ sparyyerror ("Ill formed 'IDENTIFIED BY' term"); }
<SPARQL_AFTER_NOT>.		{ sparyyerror ("Only EXISTS, FROM, IN, NULL and USING are allowed after NOT keyword in SPARQL expression"); }
<SPARQL_AFTER_WHERE>.	{ sparyyerror ("Only '{', '(' and a string literal are allowed after WHERE or SQLQUERY keyword in SPARQL expression"); }
<SPARQL>.			{ sparyyerror (t_box_sprintf (100, "Bad character '%c' (0x%x) in SPARQL expression", yytext[0], (unsigned int)((unsigned char)(yytext[0])))); }

%%

void sparyyerror_if_long_qname (caddr_t box, const char *lex_type_descr, struct yyguts_t * yyg)
{
  size_t boxlen = box_length (box);
  char buf[100];
  char *colon;
  if (boxlen > MAX_XML_QNAME_LENGTH)
    {
      snprintf (buf, sizeof (buf), "%.90s is too long", lex_type_descr);
      sparyyerror (buf);
    }
  colon = strrchr (box, ':');
  if (NULL == colon)
    {
      if (boxlen > MAX_XML_LNAME_LENGTH)
	{
	  snprintf (buf, sizeof (buf), "%.90s is too long", lex_type_descr);
	  sparyyerror (buf);
	}
      return;
    }
  if (colon+1-box > MAX_XML_LNAME_LENGTH)
    {
      snprintf (buf, sizeof (buf), "%.90s contains abnormally long namespace prefix", lex_type_descr);
      sparyyerror (buf);
    }
  if (boxlen-(colon-box) > MAX_XML_LNAME_LENGTH)
    {
      snprintf (buf, sizeof (buf), "%.90s contains abnormally long 'local part' after the colon", lex_type_descr);
      sparyyerror (buf);
    }
}

int sparscn_NUMBER_int (YYSTYPE *yylval, struct yyguts_t * yyg)
{
  if (('-' == yytext[0]) ?                                   /* 012345678901234567890 */
    ((20 > yyleng) || ((20 == yyleng) && (0 >= strcmp (yytext, "-9223372036854775808"))))
    :                                                        /* 01234567890123456789 */
    ((19 > yyleng) || ((19 == yyleng) && (0 >= strcmp (yytext, "9223372036854775807")))) )
    {
      yylval->box = t_box_num_nonull (atol (yytext));
      return SPARQL_INTEGER;
    }
  else
    {
      numeric_t num = t_numeric_allocate ();
      int rc = numeric_from_string (num, yytext);
      yylval->box = (caddr_t) num;
      if (NULL == yylval->box)
	yylval->box = t_box_num_nonull (0);
      if(rc != NUMERIC_STS_SUCCESS)
	sparyyerror ("The absolute value of numeric constant is too large");
      return SPARQL_INTEGER;
    }
}

int sparscn_NUMBER_decimal (YYSTYPE *yylval, struct yyguts_t * yyg)
{
  numeric_t num = t_numeric_allocate ();
  int rc = numeric_from_string (num, yytext);
  if (NUMERIC_STS_SUCCESS == rc)
    {
      if (NULL == (caddr_t) num)
	yylval->box = (caddr_t)t_list (2, t_box_num_nonull (0), t_box_string (yytext));
      yylval->box = (caddr_t)t_list (2, (caddr_t) num, t_box_string (yytext));
      return SPARQL_DECIMAL;
    }
  yylval->box = (caddr_t)t_list (2, t_box_double (atof (yytext)), t_box_string (yytext));
  return SPARQL_DECIMAL;
}

int
sparscn_NUMBER_double (YYSTYPE *yylval, struct yyguts_t * yyg)
{
  yylval->box = (caddr_t)t_list (2, t_box_double (atof (yytext)), t_box_string (yytext));
  return SPARQL_DOUBLE;
}

#define XP_LEXBUF_ELEMENTS 32
void
spar_fill_lexem_bufs (sparp_t *sparp)
{
  yyscan_t scanner;
  yylex_init_extra (sparp, &scanner);
  sparp->sparp_text_len = box_length (sparp->sparp_text)-1;
  sparp = sparp;
  QR_RESET_CTX
    {
      int depth = 0;
      int fill_ctr = 0;
      spar_lexem_t *curr_lex;
#ifdef XPYYDEBUG
	sparp->sparp_yydebug = 1;
#endif
      sparp->sparp_lexlineno = 1;
      sparp->sparp_lexdepth = 0;
      sparp->sparp_curr_lexem_buf = (spar_lexem_t *)t_alloc_box (sizeof (spar_lexem_t) * XP_LEXBUF_ELEMENTS, DV_ARRAY_OF_POINTER);
/* Setting initial state and placing appropriate fake lexem to the lexbuffer */
      curr_lex = sparp->sparp_curr_lexem_buf + fill_ctr;
      curr_lex->sparl_lineno = sparp->sparp_lexlineno;
      curr_lex->sparl_depth = depth;
      curr_lex->sparl_raw_text = t_box_dv_short_string("");
      /* BEGIN_NEW_CURRENT(SPARQL); */ ((struct yyguts_t *)scanner)->yy_start =  1 + 2 * (sparp->sparp_lexstates[sparp->sparp_lexdepth] = SPARQL);
      curr_lex->sparl_lex_value = START_OF_SPARQL_TEXT;
      sparp->sparp_total_lexems_parsed++;
      fill_ctr++;
/* Loop over text */
      for (;;)
        {
	  curr_lex = sparp->sparp_curr_lexem_buf + fill_ctr;
	  curr_lex->sparl_lex_value = sparyylex((YYSTYPE *)(&(curr_lex->sparl_sem_value)), scanner);
	  curr_lex->sparl_lineno = sparp->sparp_lexlineno;
	  curr_lex->sparl_depth = depth;
	  if (0 == curr_lex->sparl_lex_value)
	    {
	      curr_lex->sparl_lex_value = END_OF_SPARQL_TEXT;
	      break;
	    }
	  depth = sparp->sparp_lexdepth;
	  curr_lex->sparl_raw_text = t_box_dv_short_nchars (yyget_text(scanner), yyget_leng (scanner));
#ifdef XPATHP_DEBUG
	  /* curr_lex->sparl_state = GET_CURRENT_BEGIN; */ curr_lex->sparl_state = sparp->sparp_lexstates[sparp->sparp_lexdepth];
#endif
	  fill_ctr++;
          sparp->sparp_total_lexems_parsed++;
	  if (fill_ctr == XP_LEXBUF_ELEMENTS)
	    {
	      t_set_push (&(sparp->sparp_output_lexem_bufs), sparp->sparp_curr_lexem_buf);
	      sparp->sparp_curr_lexem_buf = (spar_lexem_t *)t_alloc_box (sizeof (spar_lexem_t) * XP_LEXBUF_ELEMENTS, DV_ARRAY_OF_POINTER);
	      fill_ctr = 0;
	    }
	}
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      sparp->sparp_sparqre->sparqre_catched_error = thr_get_error_code (self);
      thr_set_error_code (self, NULL);
      /*no POP_QR_RESET*/;
    }
  END_QR_RESET
  yylex_destroy (scanner);
  t_set_push (&(sparp->sparp_output_lexem_bufs), sparp->sparp_curr_lexem_buf);
  sparp->sparp_curr_lexem_buf = NULL;
  sparp->sparp_curr_lexem_bmk.sparlb_lexem_bufs_tail = sparp->sparp_output_lexem_bufs = dk_set_nreverse (sparp->sparp_output_lexem_bufs);
  sparp->sparp_lexem_buf_len = box_length (sparp->sparp_curr_lexem_bmk.sparlb_lexem_bufs_tail->data) / sizeof (spar_lexem_t);
}

/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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
%option reentrant
%option bison-bridge
%option stack

%{
#include "Dk.h"
#include "xmltree.h"
#include "rdf_core.h"
#include "turtle_p.h"
#include "numeric.h"
#include "turtle_p.h"
#include "nquad_p.h"
#include "security.h"
#include "sqlbif.h"
#if (__NQUAD_NONPUNCT_END != __TTL_NONPUNCT_END)
  Sources of parsers are out of sync: mismatch between token declarations in nquad_p.y and turtle_p.y
#endif


#define YY_EXTRA_TYPE ttlp_t *

#define ttlyyerror(strg) ttlyyerror_impl(ttlp_arg, yytext, (strg))

#define TTLYYERROR_OR_REPORT(strg) do { \
  if (!(ttlp_arg[0].ttlp_flags & TTLP_ERROR_RECOVERY)) \
    ttlyyerror (strg); \
  else if (TTLP_SNIFFER & ttlp_arg[0].ttlp_flags) \
    { ttlp_reset_stacks(ttlp_arg); BEGIN(GARBAGE); } \
  else tf_report (ttlp_arg[0].ttlp_tf, 'E', NULL, NULL, (strg)); } while (0)

#define TTLYYERROR_OR_RECOVER(strg) do { \
  TTLYYERROR_OR_REPORT(strg); \
  return TTL_RECOVERABLE_ERROR; } while (0)

#define ttlyylval (((YYSTYPE *)(yylval_param))[0])

#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
  do \
    { \
      ttlp_t *ttlp_arg = ttlyyget_extra (yyscanner); \
      int rest_len = ttlp_arg[0].ttlp_text_len - ttlp_arg[0].ttlp_text_ofs; \
      int get_len = (max_size); \
      if (rest_len > 0) \
        { \
          if (get_len > rest_len) \
            get_len = rest_len; \
          memcpy ((buf), (ttlp_arg[0].ttlp_text + ttlp_arg[0].ttlp_text_ofs), get_len); \
          (result) = get_len; \
          ttlp_arg[0].ttlp_text_ofs += get_len; \
          break; \
        } \
      if (NULL != ttlp_arg[0].ttlp_iter) \
        { \
          (result) = ttlp_arg[0].ttlp_iter (ttlp_arg[0].ttlp_iter_data, buf, max_size); \
          break; \
        } \
      (result) = 0; \
    } while (0);

int ttl_yy_null = YY_NULL;

struct yyguts_t;

extern int ttlyyerror_if_long_qname (ttlp_t *ttlp_arg, int lexcode, caddr_t box, const char *lex_type_descr, struct yyguts_t * yyg);

#define TTL_TOKBOX_Q_FINAL(lexcode,lex_type_descr) \
    if (box_length (ttlyylval.box) > MAX_XML_LNAME_LENGTH) \
      return ttlyyerror_if_long_qname (ttlp_arg, (lexcode), ttlyylval.box, lex_type_descr , yyg); \
    return (lexcode);

#define TTL_TOKBOX_Q(n,lexcode,lex_type_descr) { \
    ttlyylval.box = box_dv_short_string (yytext+(n)); \
    TTL_TOKBOX_Q_FINAL(lexcode,lex_type_descr) }

#define TTL_TOKBOX_BNODE(n,lexcode,lex_type_descr) { \
    int slen = strlen (yytext+(n)); \
    if (slen > 1+MAX_XML_LNAME_LENGTH) { \
        if (!(ttlp_arg[0].ttlp_flags & TTLP_ACCEPT_DIRTY_NAMES)) \
          TTLYYERROR_OR_RECOVER ("Blank node label is abnormally long; this error can be suppressed by parser flags"); \
        else \
          tf_report (ttlp_arg[0].ttlp_tf, 'W', NULL, NULL, "Blank node label is abnormally long"); \
      } \
    ttlyylval.box = box_dv_short_string (yytext+(n)); \
    return (lexcode); }

#define TTL_SPECIAL_QNAME(bit,id) \
 if (!(ttlp_arg[0].ttlp_special_qnames & bit)) \
   return id; \
 ttlyylval.box = box_dv_short_string (yytext); \
 return QNAME;

#define TTL_ONE_CR ttlp_arg[0].ttlp_lexlineno++

#define TTL_TWO_CRS do { \
    ttlp_arg[0].ttlp_lexlineno += 2; \
    if (TTLP_SNIFFER & ttlp_arg[0].ttlp_flags) { BEGIN(TWO_CRS); } \
  } while (0);

extern int ttlp_NUMBER_int (YYSTYPE *yylval_param, ttlp_t *ttlp_arg, struct yyguts_t * yyg);
extern int ttlp_NUMBER_decimal (YYSTYPE *yylval_param, ttlp_t *ttlp_arg, struct yyguts_t * yyg);
extern int ttlp_NUMBER_double (YYSTYPE *yylval_param, ttlp_t *ttlp_arg, struct yyguts_t * yyg);

extern int ttlyylex (YYSTYPE *yylval_param, ttlp_t *ttlp_arg, yyscan_t yyscanner);
#define YY_DECL int ttlyylex (YYSTYPE *yylval_param, ttlp_t *ttlp_arg, yyscan_t yyscanner)

extern int ttlyydebug;

%}

	/* Top-level INITIAL state */
/*%x INITIAL */

	/* Initial state of "Turtle sniffer" parser: beginning of line that is probably garbage */
%x GARBAGE_BOL

	/* State of "Turtle sniffer" parser in the middle of a line that is probably garbage */
%x GARBAGE

	/* State for empty lines after a sniffed fragment, parser can transit to INITIAL without CRs before braces or transit to GARBAGE */
%x TWO_CRS

	/* Internals of single-quoted INITIAL string lit */
%x TURTLE_SQ

	/* Internals of double-quoted INITIAL string lit */
%x TURTLE_DQ

	/* Internals of invalid single-quoted INITIAL string lit */
%x TURTLE_BAD_SQ

	/* Internals of invalid double-quoted INITIAL string lit */
%x TURTLE_BAD_DQ

	/* Internals of triple-single-quoted INITIAL string lit */
%x TURTLE_SSSQ

	/* Internals of triple-double-quoted INITIAL string lit */
%x TURTLE_DDDQ

	/* State after '@' right after quoted string */
%x TURTLE_AT_AFTER_QUOTED

	/* State after _really_ unexpected character, to skip to the dot and whitespace */
%x TURTLE_SKIP_TO_DOT_WS

	/* Special unreacheable state to fill the first item of ttlp_arg[0].ttlp_lexstates */
%x UNREACHEABLE

INTEGER_LITERAL ([0-9]+)
DECIMAL_LITERAL (([0-9]+"."[0-9]*)|("."[0-9]+))
DOUBLE_LITERAL	(({INTEGER_LITERAL}|{DECIMAL_LITERAL})[eE][+-]?[0-9]+)

TTL_CR_IRIREF	([^\x00-\x20<>\\""{}|^`]|{TTL_CR_UCHAR})
TTL_CR_PN_PREFIX	({SPAR_NCCHAR1p}(({SPAR_NCCHAR}|[.])*{SPAR_NCCHAR})?)
TTL_CR_PN_LOCAL	(({SPAR_NCCHAR1}|[0-9:]|{TTL_CR_PLX})(({SPAR_NCCHAR}|[.:]|{TTL_CR_PLX})*({SPAR_NCCHAR}|[:]|{TTL_CR_PLX}))?)
TTL_CR_UCHAR	([\\](("u"{HEX}{HEX}{HEX}{HEX})|("U"{HEX}{HEX}{HEX}{HEX}{HEX}{HEX}{HEX}{HEX})))
TTL_CR_PLX	(([%]{HEX}{HEX})|([\\][_~.!$&''()*+,;=/?#@%-]))

SPAR_SQ_PLAIN	([^\x00-\x1f\\''\r\n]|[\t])
SPAR_DQ_PLAIN	([^\x00-\x1f\\""\r\n]|[\t])
SPAR_ECHAR	([\\]([atbvnrf\\""'']|("u"{HEX}{HEX}{HEX}{HEX})|("U"{HEX}{HEX}{HEX}{HEX}{HEX}{HEX}{HEX}{HEX})))
SPAR_LANGTAG	([a-zA-Z]+)(("-"([a-zA-Z0-9]+))*)
SPAR_OLD_LANGTAG	([a-z]+)"_"([a-zA-Z0-9]+)
S_NL		((\r\n)|(\n\r)|\n|\r)
HEX		([0-9A-Fa-f])

SPAR_NCCHAR1p	([A-Za-z\x7f-\xfe])
SPAR_NCCHAR1	([A-Za-z\x7f-\xfe_])
SPAR_VARNAME	([A-Za-z0-9\x7f-\xfe_]+)
SPAR_NCCHAR	([A-Za-z0-9_\x7f-\xfe-])
SPAR_NCCHAR_X	([A-Za-z0-9_#%?&=*\x7f-\xfe-])
SPAR_NCNAME_PREFIX	({SPAR_NCCHAR1p}([A-Za-z0-9_.\x7f-\xfe-]*{SPAR_NCCHAR})?)
SPAR_NCNAME		({SPAR_NCCHAR1}([A-Za-z0-9_.\x7f-\xfe-]*{SPAR_NCCHAR})?)
SPAR_NCNAME_X		(([A-Za-z0-9_./#%+?&=@*:\x7f-\xfe-]*[A-Za-z0-9_/#%+?&=@*:\x7f-\xfe-]+)|([A-Za-z0-9_./#%+?&=@*:\x7f-\xfe-]*[./#%+?&=@*:][A-Za-z0-9_./#%+?&=@*:\x7f-\xfe-]*[.]))

%%

<INITIAL>"^"[ \t]		{		return _CARET_WS; }
<INITIAL>"^"{S_NL}[ \t]*{S_NL}	{ TTL_TWO_CRS;	return _CARET_WS; }
<INITIAL>"^"{S_NL}		{ TTL_ONE_CR;	return _CARET_WS; }
<INITIAL>"^"			{ return _CARET_NOWS	; }
<INITIAL>"^^"			{ return _CARET_CARET	; }
<INITIAL>","			{ return _COMMA; }
<INITIAL>"."[ \t]		{		return _DOT_WS; }
<INITIAL>"."{S_NL}[ \t]*{S_NL}	{ TTL_TWO_CRS;	return _DOT_WS; }
<INITIAL>"."{S_NL}		{ TTL_ONE_CR;	return _DOT_WS; }
<INITIAL>"."[^0-9]		{ TTLYYERROR_OR_RECOVER ("Whitespace is required after dot if dot is not inside decimal number, string or IRI"); }
<INITIAL>"."			{ return _DOT_WS; }
<INITIAL>":"			{ return _COLON; }
<INITIAL>";"			{ return _SEMI; }
<INITIAL>"="			{ return (((0 == ttlp_arg[0].ttlp_lexdepth) && (ttlp_arg[0].ttlp_flags & TTLP_ALLOW_TRIG)) ? _EQ_TOP_TRIG : _EQ); }
<INITIAL>"=>"			{ return _EQ_GT; }
<INITIAL>"<="			{ return _LT_EQ; }
<INITIAL>"!"			{ return _BANG; }

<INITIAL>"@a"			{ return _AT_a_L; }
<INITIAL,GARBAGE_BOL,GARBAGE,TWO_CRS>"@base"	{ BEGIN(INITIAL); return _AT_base_L; }
<INITIAL>"@has"			{ return _AT_has_L; }
<INITIAL>"@is"			{ return _AT_is_L; }
<INITIAL>"@of"			{ return _AT_of_L; }
<INITIAL>"@this"		{ return _AT_this_L; }
<INITIAL,GARBAGE_BOL,GARBAGE,TWO_CRS>"@keywords"	{ BEGIN(INITIAL); return _AT_keywords_L; }
<INITIAL,GARBAGE_BOL,GARBAGE,TWO_CRS>"@prefix"	{ BEGIN(INITIAL); return _AT_prefix_L; }
<INITIAL>"@forAll"		{ ttlyyerror ("Current version of Virtuoso does not support @forAll keyword"); }
<INITIAL>"@forSome"		{ ttlyyerror ("Current version of Virtuoso does not support @forSome keyword"); }
<INITIAL>"-INF"			{ return _MINUS_INF_L; }
<INITIAL>[+]?"INF"		{ return INF_L; }
<INITIAL>[+-]?"NaN"		{ return NaN_L; }
<INITIAL>"false"		{ return false_L; }
<INITIAL>"true"			{ return true_L; }

<INITIAL>"a"			{ TTL_SPECIAL_QNAME (TTLP_ALLOW_QNAME_A, _AT_a_L) }
<INITIAL>"has"			{ TTL_SPECIAL_QNAME (TTLP_ALLOW_QNAME_HAS, _AT_has_L) }
<INITIAL>"is"			{ TTL_SPECIAL_QNAME (TTLP_ALLOW_QNAME_IS, _AT_is_L) }
<INITIAL>"of"			{ TTL_SPECIAL_QNAME (TTLP_ALLOW_QNAME_OF, _AT_of_L) }
<INITIAL>"this"			{ TTL_SPECIAL_QNAME (TTLP_ALLOW_QNAME_THIS, _AT_this_L) }


<INITIAL>"("			{			ttlp_arg[0].ttlp_lexdepth++;	return _LPAR; }
<GARBAGE_BOL>"("		{ BEGIN(INITIAL);	ttlp_arg[0].ttlp_lexdepth++;	return _LPAR; }
<TWO_CRS>"("			{ BEGIN(INITIAL);	ttlp_arg[0].ttlp_lexdepth++;	return _LPAR; }
<INITIAL>")"			{			ttlp_arg[0].ttlp_lexdepth--;	return _RPAR; }
<INITIAL>"["			{			ttlp_arg[0].ttlp_lexdepth++;	return _LSQBRA; }
<GARBAGE_BOL>"["		{ BEGIN(INITIAL);	ttlp_arg[0].ttlp_lexdepth++;	return _LSQBRA; }
<INITIAL,GARBAGE_BOL,GARBAGE,TWO_CRS>"[]"	{ BEGIN(INITIAL);					return _LSQBRA_RSQBRA; }
<INITIAL>"]"			{			ttlp_arg[0].ttlp_lexdepth--;	return _RSQBRA; }
<INITIAL>"{"			{
    int depth = ttlp_arg[0].ttlp_lexdepth++;
    return (((0 == depth) && (ttlp_arg[0].ttlp_flags & TTLP_ALLOW_TRIG)) ? _LBRA_TOP_TRIG : _LBRA);
  }
<GARBAGE_BOL>"{"		{ BEGIN(INITIAL);	ttlp_arg[0].ttlp_lexdepth++;	return _LBRA; }
<INITIAL>"}"			{			ttlp_arg[0].ttlp_lexdepth--;	return _RBRA; }

<INITIAL,GARBAGE_BOL,GARBAGE,TWO_CRS>"<"([^\\>\001-\040])*">"	{
    if (TTL_MAX_IRI_LEN <= yyleng)
      TTLYYERROR_OR_RECOVER("The \"relative IRI\" (angle-bracketed) notation is too long");
    BEGIN(INITIAL);
    ttlyylval.box = box_dv_short_nchars (yytext + 1, yyleng - 2);
    return Q_IRI_REF;
  }

<INITIAL,GARBAGE_BOL,GARBAGE,TWO_CRS>"<"{TTL_CR_IRIREF}">"	{
    if (TTL_MAX_IRI_LEN <= yyleng)
      TTLYYERROR_OR_RECOVER("The \"relative IRI\" (angle-bracketed) notation is too long");
    BEGIN(INITIAL);
    ttlyylval.box = ttlp_strliteral (ttlp_arg, yytext, TTLP_STRLITERAL_LTGT, '>');
    return Q_IRI_REF;
  }

<INITIAL>"<"(([^\\>\001-\040])|{SPAR_ECHAR}|"\\>")*">"	{
    if (TTL_MAX_IRI_LEN <= yyleng)
      TTLYYERROR_OR_RECOVER("The \"relative IRI\" (angle-bracketed) notation is too long");
    ttlyylval.box = ttlp_strliteral (ttlp_arg, yytext, TTLP_STRLITERAL_LTGT, '>');
    return Q_IRI_REF;
  }

<INITIAL>"<"([^<>\001-\037]|"\t")*">"	{
    if (!(ttlp_arg[0].ttlp_flags & TTLP_ACCEPT_DIRTY_NAMES))
      TTLYYERROR_OR_RECOVER ("Invalid characters in angle-bracketed name; this error can be suppressed by parser flags");
    if (TTL_MAX_IRI_LEN <= yyleng)
      TTLYYERROR_OR_RECOVER("The \"relative IRI\" (angle-bracketed) notation is too long");
    tf_report (ttlp_arg[0].ttlp_tf, 'W', NULL, NULL, "Invalid characters in angle-bracketed name");
    ttlyylval.box = box_dv_short_nchars (yytext + 1, yyleng - 2);
    return Q_IRI_REF;
  }

<INITIAL>"<"([^<>\001-\037]|"\t")+{S_NL}([^<>.;,\[\]{}\'\"\\\001-\037]|"\t")*">"	{
    if (!(ttlp_arg[0].ttlp_flags & TTLP_ACCEPT_DIRTY_NAMES))
      TTLYYERROR_OR_RECOVER ("Line break in angle-bracketed name; this error can be suppressed by parser flags");
    if (TTL_MAX_IRI_LEN <= yyleng)
      TTLYYERROR_OR_RECOVER("The \"relative IRI\" (angle-bracketed) notation is too long");
    tf_report (ttlp_arg[0].ttlp_tf, 'W', NULL, NULL, "Line break in angle-bracketed name");
    ttlyylval.box = box_dv_short_nchars (yytext + 1, yyleng - 2);
    TTL_ONE_CR;
    return Q_IRI_REF;
  }

<INITIAL>"<"([^<>\001-\037]|"\t")*	{
    TTLYYERROR_OR_REPORT ("Invalid characters in angle-bracketed name");
    BEGIN (TURTLE_SKIP_TO_DOT_WS); yymore (); }

<INITIAL,GARBAGE_BOL,GARBAGE,TWO_CRS>({SPAR_NCNAME_PREFIX}?)":"{SPAR_NCNAME}	{ BEGIN(INITIAL); TTL_TOKBOX_Q(0,QNAME,"qualified URI"); }
<INITIAL,GARBAGE_BOL,GARBAGE,TWO_CRS>({TTL_CR_PN_PREFIX}?)":"{TTL_CR_PN_LOCAL}	{ BEGIN(INITIAL); TTL_TOKBOX_Q(0,QNAME,"qualified URI"); }
<INITIAL>({SPAR_NCNAME_PREFIX}?)":"{SPAR_NCNAME_X}	{
    if (!(ttlp_arg[0].ttlp_flags & TTLP_NAME_MAY_CONTAIN_PATH))
      TTLYYERROR_OR_RECOVER ("Invalid characters in local part of QName; this error can be suppressed by parser flags");
    tf_report (ttlp_arg[0].ttlp_tf, 'W', NULL, NULL, "Invalid characters in local part of QName");
    TTL_TOKBOX_Q(0,QNAME,"qualified URI"); }

<INITIAL,GARBAGE_BOL,GARBAGE,TWO_CRS>{SPAR_NCNAME_PREFIX}":"		{ BEGIN(INITIAL); TTL_TOKBOX_Q(0,QNAME_NS,"namespace"); }
<INITIAL>{SPAR_NCNAME}							{
    if ((TTLP_SNIFFER & ttlp_arg[0].ttlp_flags) && ((NULL == ttlp_arg[0].ttlp_base_uri) || ('\0' == ttlp_arg[0].ttlp_base_uri[0])))
      BEGIN (GARBAGE);
    else
      TTL_TOKBOX_Q(0,QNAME,"name without prefix"); }
<INITIAL,GARBAGE_BOL,GARBAGE,TWO_CRS>"_:"{SPAR_NCNAME}			{ BEGIN(INITIAL); TTL_TOKBOX_BNODE(0,BLANK_NODE_LABEL,"blank node label"); }

<INITIAL>"_:"{SPAR_NCCHAR_X}+	{
    if (!(ttlp_arg[0].ttlp_flags & TTLP_ACCEPT_DIRTY_NAMES))
      TTLYYERROR_OR_RECOVER ("Ill formed blank node label; this error can be suppressed by parser flags");
    tf_report (ttlp_arg[0].ttlp_tf, 'W', NULL, NULL, "Ill formed blank node label");
    TTL_TOKBOX_BNODE(0,BLANK_NODE_LABEL,"blank node label"); }

<INITIAL>"?"{SPAR_NCNAME}	{
    if (!(ttlp_arg[0].ttlp_flags & TTLP_ACCEPT_VARIABLES))
      TTLYYERROR_OR_RECOVER ("Full N3 syntax allow variables, TURTLE does not; this error can be suppressed by parser flags");
    tf_report (ttlp_arg[0].ttlp_tf, 'W', NULL, NULL, "Full N3 syntax allow variables, TURTLE does not");
    TTL_TOKBOX_Q(0,VARIABLE,"variable name"); }

<INITIAL>"@"([a-zA-Z]+)(("-"([a-zA-Z0-9]+))*)	{
    if (TTL_MAX_KEYWORD_LEN <= yyleng)
      TTLYYERROR_OR_RECOVER("The @-keyword is too long");
    ttlyylval.box = box_dv_short_nchars (yytext + 1, yyleng - 1);
    return KEYWORD;
  }

<TURTLE_AT_AFTER_QUOTED>{SPAR_LANGTAG}	{
    BEGIN INITIAL;
    if (TTL_MAX_LANGNAME_LEN <= yyleng)
      TTLYYERROR_OR_RECOVER("The language identifier after \"@\" mark is too long");
    ttlyylval.box = box_dv_short_nchars (yytext, yyleng);
    return LANGTAG;
  }

<TURTLE_AT_AFTER_QUOTED>{SPAR_OLD_LANGTAG}	{
    char *tail;
    BEGIN INITIAL;
    if (!(ttlp_arg[0].ttlp_flags & TTLP_ACCEPT_DIRTY_NAMES))
      TTLYYERROR_OR_RECOVER ("Obsolete format of language; this error can be recovered if proper parser flags are set");
    if (TTL_MAX_LANGNAME_LEN <= yyleng)
      TTLYYERROR_OR_RECOVER("The language identifier after \"@\" mark is too long");
    tf_report (ttlp_arg[0].ttlp_tf, 'W', NULL, NULL, "Obsolete format of language");
    ttlyylval.box = box_dv_short_nchars (yytext, yyleng);
    for (tail = ttlyylval.box + (yyleng); tail >= ttlyylval.box; tail--)
      if ('_' == tail[0])
        tail[0] = '-';
    return LANGTAG;
  }

<TURTLE_AT_AFTER_QUOTED>([a-zA-Z0-9-]+)	{ TTLYYERROR_OR_RECOVER ("The identifier after '@' at the end of quoted literal is not a valid language id"); }
<TURTLE_AT_AFTER_QUOTED><<EOF>>		{ TTLYYERROR_OR_RECOVER ("Missing language id after '@' at the end of quoted literal"); }
<TURTLE_AT_AFTER_QUOTED>.		{ TTLYYERROR_OR_RECOVER ("Bad character instead of language id after '@' at the end of quoted literal"); }


<INITIAL>([""][^""\\\n]*[""])|([''][^''\\\n]*['']) {
    if (TTL_MAX_LITERAL_LEN <= yyleng)
      TTLYYERROR_OR_RECOVER("The double-quoted string is too long");
    ttlyylval.box = box_dv_short_nchars (yytext+1, yyleng - 2);
    return TURTLE_STRING;
  }

<INITIAL>(([""][^""\\\n]*[""])|([''][^''\\\n]*['']))"@" {
    if (TTL_MAX_LITERAL_LEN <= yyleng)
      TTLYYERROR_OR_RECOVER("The double-quoted string is too long");
    ttlyylval.box = box_dv_short_nchars (yytext+1, yyleng - 3);
    BEGIN TURTLE_AT_AFTER_QUOTED;
    return TURTLE_STRING;
  }

<INITIAL>['']['']['']		{ yymore(); BEGIN TURTLE_SSSQ; }
<INITIAL>[""][""][""]		{ yymore(); BEGIN TURTLE_DDDQ; }
<TURTLE_SSSQ>[''][''](['']+)	{ if (TTL_MAX_LITERAL_LEN <= yyleng) TTLYYERROR_OR_RECOVER("The triple-single-quoted string is too long"); ttlyylval.box = ttlp_strliteral (ttlp_arg, yytext, TTLP_STRLITERAL_3QUOT, '\''); BEGIN INITIAL; return TURTLE_STRING; }
<TURTLE_DDDQ>[""][""]([""]+)	{ if (TTL_MAX_LITERAL_LEN <= yyleng) TTLYYERROR_OR_RECOVER("The triple-double-quoted string is too long"); ttlyylval.box = ttlp_strliteral (ttlp_arg, yytext, TTLP_STRLITERAL_3QUOT, '\"'); BEGIN INITIAL; return TURTLE_STRING; }
<TURTLE_SSSQ>['']['']['']"@"	{ if (TTL_MAX_LITERAL_LEN <= yyleng) TTLYYERROR_OR_RECOVER("The triple-single-quoted string is too long"); ttlyylval.box = ttlp_strliteral (ttlp_arg, yytext, TTLP_STRLITERAL_3QUOT_AT, '\''); BEGIN TURTLE_AT_AFTER_QUOTED; return TURTLE_STRING; }
<TURTLE_DDDQ>[""][""][""]"@"	{ if (TTL_MAX_LITERAL_LEN <= yyleng) TTLYYERROR_OR_RECOVER("The triple-double-quoted string is too long"); ttlyylval.box = ttlp_strliteral (ttlp_arg, yytext, TTLP_STRLITERAL_3QUOT_AT, '\"'); BEGIN TURTLE_AT_AFTER_QUOTED; return TURTLE_STRING; }
<TURTLE_SSSQ>(([''](['']?))?{S_NL})		{ if (TTL_MAX_LITERAL_LEN <= yyleng) TTLYYERROR_OR_RECOVER("The triple-single-quoted string is too long"); TTL_ONE_CR; yymore(); }
<TURTLE_DDDQ>(([""]([""]?))?{S_NL})		{ if (TTL_MAX_LITERAL_LEN <= yyleng) TTLYYERROR_OR_RECOVER("The triple-double-quoted string is too long"); TTL_ONE_CR; yymore(); }
<TURTLE_SSSQ>((([''](['']?))?({SPAR_SQ_PLAIN}|{SPAR_ECHAR}))+)		{ yymore(); }
<TURTLE_DDDQ>((([""]([""]?))?({SPAR_DQ_PLAIN}|{SPAR_ECHAR}))+)		{ yymore(); }
<TURTLE_SSSQ>[\\]		{ ttlyyerror ("Bad escape sequence in a long single-quoted string"); }
<TURTLE_DDDQ>[\\]		{ ttlyyerror ("Bad escape sequence in a long double-quoted string"); }
<TURTLE_SSSQ>.			{ ttlyyerror ("Bad character in a long single-quoted string"); }
<TURTLE_DDDQ>.			{ ttlyyerror ("Bad character in a long double-quoted string"); }
<TURTLE_SSSQ><<EOF>>		{ ttlyyerror ("Unterminated long single-quoted string"); }
<TURTLE_DDDQ><<EOF>>		{ ttlyyerror ("Unterminated long double-quoted string"); }


<INITIAL>['']		{ yymore(); BEGIN TURTLE_SQ; }
<INITIAL>[""]		{ yymore(); BEGIN TURTLE_DQ; }
<TURTLE_SQ>['']		{ if (TTL_MAX_LITERAL_LEN <= yyleng) TTLYYERROR_OR_RECOVER("The single-quoted string is too long"); ttlyylval.box = ttlp_strliteral (ttlp_arg, yytext, TTLP_STRLITERAL_QUOT, '\''); BEGIN INITIAL; return TURTLE_STRING; }
<TURTLE_DQ>[""]		{ if (TTL_MAX_LITERAL_LEN <= yyleng) TTLYYERROR_OR_RECOVER("The double-quoted string is too long"); ttlyylval.box = ttlp_strliteral (ttlp_arg, yytext, TTLP_STRLITERAL_QUOT, '\"'); BEGIN INITIAL; return TURTLE_STRING; }
<TURTLE_SQ>['']"@"	{ if (TTL_MAX_LITERAL_LEN <= yyleng) TTLYYERROR_OR_RECOVER("The single-quoted string is too long"); ttlyylval.box = ttlp_strliteral (ttlp_arg, yytext, TTLP_STRLITERAL_QUOT_AT, '\''); BEGIN TURTLE_AT_AFTER_QUOTED; return TURTLE_STRING; }
<TURTLE_DQ>[""]"@"	{ if (TTL_MAX_LITERAL_LEN <= yyleng) TTLYYERROR_OR_RECOVER("The double-quoted string is too long"); ttlyylval.box = ttlp_strliteral (ttlp_arg, yytext, TTLP_STRLITERAL_QUOT_AT, '\"'); BEGIN TURTLE_AT_AFTER_QUOTED; return TURTLE_STRING; }
<TURTLE_SQ>{S_NL}	{
    if (!(TTLP_STRING_MAY_CONTAIN_CRLF & ttlp_arg[0].ttlp_flags))
      {
        TTLYYERROR_OR_REPORT ("End-of-line in a short single-quoted string; this error can be suppressed by parser flags");
        BEGIN TURTLE_BAD_SQ;
      }
    else
      tf_report (ttlp_arg[0].ttlp_tf, 'W', NULL, NULL, "End-of-line in a short single-quoted string");
    TTL_ONE_CR; yymore(); }
<TURTLE_DQ>{S_NL}	{
    if (!(TTLP_STRING_MAY_CONTAIN_CRLF & ttlp_arg[0].ttlp_flags))
      {
        TTLYYERROR_OR_REPORT ("End-of-line in a short double-quoted string; this error can be suppressed by parser flags");
        BEGIN TURTLE_BAD_DQ;
      }
    else
      tf_report (ttlp_arg[0].ttlp_tf, 'W', NULL, NULL, "End-of-line in a short double-quoted string");
    TTL_ONE_CR; yymore(); }
<TURTLE_SQ>[\\]{S_NL}	{
    if (!(TTLP_STRING_MAY_CONTAIN_CRLF & ttlp_arg[0].ttlp_flags))
      {
        TTLYYERROR_OR_REPORT ("End-of-line escape sequence in a single-quoted string is not permitted by strict TURTLE; this error can be suppressed by parser flags");
        BEGIN TURTLE_BAD_SQ;
      }
    TTL_ONE_CR; yymore(); }
<TURTLE_DQ>[\\]{S_NL}	{
    if (!(TTLP_STRING_MAY_CONTAIN_CRLF & ttlp_arg[0].ttlp_flags))
      {
        TTLYYERROR_OR_REPORT ("End-of-line escape sequence in a double-quoted string is not permitted by strict TURTLE; this error can be suppressed by parser flags");
        BEGIN TURTLE_BAD_DQ;
      }
    TTL_ONE_CR; yymore(); }
<TURTLE_SQ>(({SPAR_SQ_PLAIN}|{SPAR_ECHAR})+)		{ yymore(); }
<TURTLE_DQ>(({SPAR_DQ_PLAIN}|{SPAR_ECHAR})+)		{ yymore(); }
<TURTLE_SQ>[\\]		{
    TTLYYERROR_OR_REPORT ("Bad escape sequence in a short single-quoted string");
    BEGIN (TURTLE_BAD_SQ); yymore(); }
<TURTLE_DQ>[\\]		{
    TTLYYERROR_OR_REPORT ("Bad escape sequence in a short double-quoted string");
    BEGIN (TURTLE_BAD_DQ); yymore(); }
<TURTLE_BAD_SQ>(({SPAR_SQ_PLAIN}|{SPAR_ECHAR})+) {}
<TURTLE_BAD_DQ>(({SPAR_DQ_PLAIN}|{SPAR_ECHAR})+) {}
<TURTLE_BAD_SQ>{S_NL}	{ TTL_ONE_CR; yymore(); }
<TURTLE_BAD_DQ>{S_NL}	{ TTL_ONE_CR; yymore(); }
<TURTLE_BAD_SQ>[^''] {}
<TURTLE_BAD_DQ>[^""] {}
<TURTLE_BAD_SQ>['']("@"{SPAR_LANGTAG})? { BEGIN INITIAL; return TTL_RECOVERABLE_ERROR; }
<TURTLE_BAD_DQ>[""]("@"{SPAR_LANGTAG})? { BEGIN INITIAL; return TTL_RECOVERABLE_ERROR; }

<TURTLE_SQ,TURTLE_BAD_SQ><<EOF>>		{ ttlyyerror ("Unterminated short single-quoted string"); }
<TURTLE_DQ,TURTLE_BAD_DQ><<EOF>>		{ ttlyyerror ("Unterminated short double-quoted string"); }

<INITIAL>[+-]?{INTEGER_LITERAL}		{ return ttlp_NUMBER_int (yylval, ttlp_arg, yyg); }
<INITIAL>[+-]?{DECIMAL_LITERAL}		{ return ttlp_NUMBER_decimal (yylval, ttlp_arg, yyg); }
<INITIAL>[+-]?{DOUBLE_LITERAL}		{ return ttlp_NUMBER_double (yylval, ttlp_arg, yyg); }

<INITIAL>("#"(.*))?{S_NL}[ \t]*{S_NL}[ \t]*			{ TTL_TWO_CRS; }
<INITIAL,GARBAGE_BOL,GARBAGE,TWO_CRS>("#"(.*))?{S_NL}		{ TTL_ONE_CR; }
<INITIAL,TWO_CRS>"#"(.*)		{ }
<INITIAL,TWO_CRS>[ \t]+			{ }
<INITIAL>.		{
    char buf[100]; sprintf (buf, "Unexpected character '%c'", yytext[yyleng-1]);
    TTLYYERROR_OR_REPORT (buf);
    BEGIN TURTLE_SKIP_TO_DOT_WS; yymore(); }
<TURTLE_SKIP_TO_DOT_WS>"."[ \t]		{ BEGIN INITIAL; yyless (yyleng-2); return _GARBAGE_BEFORE_DOT_WS; }
<TURTLE_SKIP_TO_DOT_WS>"."{S_NL}	{ BEGIN INITIAL; yyless (('.' == yytext[yyleng-2]) ? yyleng-2 : yyleng-3); TTL_ONE_CR; return _GARBAGE_BEFORE_DOT_WS; }
<TURTLE_SKIP_TO_DOT_WS>.	{
    if (yyleng > 8000)
      { char buf[100]; sprintf (buf, "Failed to recover syntax error at \"%.50s...\"", yytext); ttlyyerror (buf); }
    yymore(); }

<GARBAGE>([^_:<@ \t][^: \t]*[ \t]+)+	{ }
<GARBAGE>[^ \t]+	{ }
<GARBAGE>[ \t]+	{ }
<GARBAGE_BOL>[^ \t]+			{ BEGIN(GARBAGE); }
<GARBAGE,GARBAGE_BOL>{S_NL}[ \t]*	{ BEGIN(GARBAGE_BOL); TTL_ONE_CR; }
<TWO_CRS>("#"(.*))?{S_NL}[ \t]*		{ TTL_ONE_CR; }

%%

/*void ttlyy_reset (yyscan_t scanner)
{
  ttlyyrestart (NULL, scanner);
  BEGIN INITIAL;
}*/

int
ttlyyerror_if_long_qname (ttlp_t *ttlp_arg, int lexcode, caddr_t box, const char *lex_type_descr, struct yyguts_t * yyg)
{
  size_t boxlen = box_length (box);
  char buf[100];
  char *colon;
  if (boxlen > MAX_XML_QNAME_LENGTH)
    {
      snprintf (buf, sizeof (buf), "%.90s is too long", lex_type_descr);
      goto err; /* see below */
    }
  colon = strrchr (box, ':');
  if (NULL == colon)
    {
      if (boxlen > MAX_XML_LNAME_LENGTH)
	{
	  snprintf (buf, sizeof (buf), "%.90s is too long", lex_type_descr);
          goto err; /* see below */
	}
      return lexcode;
    }
  if (colon+1-box > MAX_XML_LNAME_LENGTH)
    {
      snprintf (buf, sizeof (buf), "%.90s contains abnormally long namespace prefix", lex_type_descr);
      goto err; /* see below */
    }
  if (boxlen-(colon-box) > MAX_XML_LNAME_LENGTH)
    {
      snprintf (buf, sizeof (buf), "%.90s contains abnormally long 'local part' after the colon", lex_type_descr);
      goto err; /* see below */
    }
  return lexcode;

err:
  TTLYYERROR_OR_RECOVER (buf);
  return 0; /* Never reached */
}

int
ttlp_NUMBER_int (YYSTYPE *yylval_param, ttlp_t *ttlp_arg, struct yyguts_t * yyg)
{
  int l = strlen (yytext);
  int has_sign = ((('-' == yytext[0]) || ('+' == yytext[0])) ? 1 : 0);
  int is_negative = ('-' == yytext[0]);
  if (((10+has_sign) > l) ||
    (((10+has_sign) == l) &&
      (0 >= strcmp (yytext + has_sign,
          (is_negative ? "2147483648" : "2147483647") ) ) ) )
    {
      ttlyylval.box = box_num_nonull (atol (yytext));
      return TURTLE_INTEGER;
    }
  else
    {
      numeric_t num = numeric_allocate ();
      int rc = numeric_from_string (num, yytext);
      ttlyylval.box = (caddr_t) num;
      if (NULL == ttlyylval.box)
	ttlyylval.box = box_num_nonull (0);
      if(rc != NUMERIC_STS_SUCCESS)
	TTLYYERROR_OR_RECOVER ("The absolute value of numeric constant is too large");
      return TURTLE_INTEGER;
    }
}

int
ttlp_NUMBER_decimal (YYSTYPE *yylval_param, ttlp_t *ttlp_arg, struct yyguts_t * yyg)
{
  numeric_t num = numeric_allocate ();
  int rc = numeric_from_string (num, yytext);
  if (NUMERIC_STS_SUCCESS == rc)
    {
      ttlyylval.box = (caddr_t) num;
      if (NULL == ttlyylval.box)
	ttlyylval.box = box_num_nonull (0);
      return TURTLE_DECIMAL;
    }
  numeric_free (num);
  ttlyylval.box = box_double (atof (yytext));
  return TURTLE_DECIMAL;
}

int
ttlp_NUMBER_double (YYSTYPE *yylval_param, ttlp_t *ttlp_arg, struct yyguts_t * yyg)
{
  ttlyylval.box = box_double (atof (yytext));
  return TURTLE_DOUBLE;
}

caddr_t
ttl_lex_analyze (caddr_t str, int flags, wcharset_t *query_charset)
{
  dk_set_t lexems = NULL;
  caddr_t result_array;
  ttlp_t *ttlp;
  yyscan_t scanner;
  int sniffer_recovery = 0;
  if (!DV_STRINGP(str))
    {
      return list (1, list (3, (ptrlong)0, (ptrlong)0, box_dv_short_string ("TURTLE parser: input text is not a string")));
    }
  ttlp = ttlp_alloc ();
  ttlp->ttlp_flags = flags;

resume_sniffing:
  QR_RESET_CTX
    {
      if (sniffer_recovery)
        yy_push_state (GARBAGE, scanner);
      else
        {
          ttlp->ttlp_text = str;
          ttlp->ttlp_text_len = strlen (str);
          ttlp->ttlp_err_hdr = ((flags & TTLP_ALLOW_NQUAD) ? "NQuads lexical analyzer" : ((flags & TTLP_ALLOW_TRIG) ? "TriG lexical analyzer" : "TURTLE lexical analyzer"));
          if (NULL == query_charset)
            query_charset = default_charset;
          if (NULL == query_charset)
            ttlp->ttlp_enc = &eh__ISO8859_1;
          else
            {
              ttlp->ttlp_enc = eh_get_handler (CHARSET_NAME (query_charset, NULL));
              if (NULL == ttlp->ttlp_enc)
                ttlp->ttlp_enc = &eh__ISO8859_1;
            }
          ttlyylex_init (&scanner);
          ttlyyset_extra (ttlp, scanner);
          if (flags & TTLP_SNIFFER)
            yy_push_state (GARBAGE_BOL, scanner);
          else
            {
#ifdef MALLOC_DEBUG
              yy_push_state (INITIAL, scanner);
#endif
            }
        }
      for (;;)
        {
          caddr_t lex_value = NULL;
          int lexem;
          lexem = ttlyylex ((YYSTYPE *)(&lex_value), ttlp, scanner);
          if (0 == lexem)
            break;
          yy_push_state (0, scanner);
          dk_set_push (&lexems, list (6,
              box_num (ttlp->ttlp_lexlineno),
              ttlp->ttlp_lexdepth,
              box_copy (ttlp->ttlp_raw_text),
              lexem, lex_value,
              (ptrlong)yy_top_state (scanner) ) );
          yy_pop_state (scanner);
        }
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      if (flags & TTLP_SNIFFER)
        {
          dk_free_tree (thr_get_error_code (self));
          thr_set_error_code (self, NULL);
          yy_pop_state (scanner);
          ttlp_reset_stacks (ttlp);
          sniffer_recovery = 2;
        }
      else
        {
          /* ttlyydebug = 0; */
          ttlp->ttlp_catched_error = thr_get_error_code (self);
          thr_set_error_code (self, NULL);
        }
      /*no POP_QR_RESET*/;
    }
  END_QR_RESET
  if (2 == sniffer_recovery)
    {
      sniffer_recovery = 1;
      goto resume_sniffing;
    }
  ttlyylex_destroy (scanner);
  if (NULL != ttlp->ttlp_catched_error)
    {
      dk_set_push (&lexems, list (3,
		box_num (ttlp->ttlp_lexlineno),
		ttlp->ttlp_lexdepth,
		box_copy (ERR_MESSAGE (ttlp->ttlp_catched_error)) ) );
    }
  ttlp_free (ttlp);
  result_array = revlist_to_array (lexems);
  return result_array;
}

caddr_t
rdf_load_turtle (
  caddr_t text_or_filename, int arg1_is_filename, caddr_t base_uri, caddr_t graph_uri, long flags,
  ccaddr_t *cbk_names, caddr_t *app_env,
  query_instance_t *qi, wcharset_t *query_charset, caddr_t *err_ret )
{
  FILE *srcfile = NULL;
  bh_from_client_fwd_iter_t bcfi;
  bh_from_disk_fwd_iter_t bdfi;
  dk_session_fwd_iter_t dsfi;
  int sniffer_recovery = 0;
  /* !!!TBD: add wide support: int text_strg_is_wide = 0; */
  dtp_t dtp_of_text = (arg1_is_filename ? 0 : DV_TYPE_OF (text_or_filename));
  caddr_t res;
  ttlp_t *ttlp;
  yyscan_t scanner;
  triple_feed_t *tf;
  if (arg1_is_filename)
    sec_check_dba (qi, "<creading TURTLE from local file>");
  if (DV_BLOB_XPER_HANDLE == dtp_of_text)
    sqlr_new_error ("42000", "SP036", "Unable to parse TURTLE from persistent XML object");
  ttlp = ttlp_alloc ();
  ttlp->ttlp_flags = flags;
  tf = ttlp->ttlp_tf;
  tf->tf_qi = qi;
  tf->tf_app_env = app_env;

  if (arg1_is_filename)
    {
      sec_check_dba (qi, "<read XML from URL of type file://...>");
      tf->tf_boxed_input_name = file_native_name_from_iri_path_nchars (text_or_filename, strlen (text_or_filename));
      file_path_assert (tf->tf_boxed_input_name, NULL, 1);
      srcfile = fopen (tf->tf_boxed_input_name, "rb");
      if (NULL == srcfile)
        {
          ttlp_free (ttlp);
          sqlr_new_error ("42000", "SR598", "TURTLE parser has failed to open file '%s' for reading", tf->tf_boxed_input_name);
        }
      ttlp->ttlp_iter = file_read;
      ttlp->ttlp_iter_data = srcfile;
      goto iter_is_set;
    }
  if ((DV_BLOB_HANDLE == dtp_of_text) /* !!!TBD: add wide support: || (DV_BLOB_WIDE_HANDLE == dtp_of_text)*/ )
    {
      blob_handle_t *bh = (blob_handle_t *) text_or_filename;
#if 0 /* !!!TBD: add wide support: */
      text_strg_is_wide = ((DV_BLOB_WIDE_HANDLE == dtp_of_text) ? 1 : 0);
#endif
      if (bh->bh_ask_from_client)
        {
          bcfi_reset (&bcfi, bh, qi->qi_client);
          ttlp->ttlp_iter = bcfi_read;
          ttlp->ttlp_iter_abend = bcfi_abend;
          ttlp->ttlp_iter_data = &bcfi;
	  goto iter_is_set;
        }
      bdfi_reset (&bdfi, bh, qi);
      ttlp->ttlp_iter = bdfi_read;
      ttlp->ttlp_iter_data = &bdfi;
      goto iter_is_set;
    }
  if (DV_STRING_SESSION == dtp_of_text)
    {
      dk_session_t *ses = (dk_session_t *) text_or_filename;
      dsfi_reset (&dsfi, ses);
      ttlp->ttlp_iter = dsfi_read;
      ttlp->ttlp_iter_data = &dsfi;
      goto iter_is_set;
    }
#if 0 /* !!!TBD: add wide support: */
   if (IS_WIDE_STRING_DTP (dtp_of_text))
    {
      text_len = (s_size_t) (box_length(text_or_filename)-sizeof(wchar_t));
      text_strg_is_wide = 1;
      goto iter_is_set;
    }
#endif
  if (IS_STRING_DTP (dtp_of_text))
    {
      ttlp->ttlp_text = text_or_filename;
      ttlp->ttlp_text_len = box_length(text_or_filename) - 1;
      goto iter_is_set;
    }
  ttlp_free (ttlp);
  sqlr_new_error ("42000", "SP037",
    "Unable to parse TURTLE from data of type %s (%d)", dv_type_title (dtp_of_text), dtp_of_text);

iter_is_set:
  tf->tf_default_graph_uri = box_copy (graph_uri);
  ttlp->ttlp_err_hdr = ((flags & TTLP_ALLOW_NQUAD) ? "NQuads RDF loader" : ((flags & TTLP_ALLOW_TRIG) ? "TriG RDF loader" : "TURTLE RDF loader"));
  if (NULL == query_charset)
    query_charset = default_charset;
  if (NULL == query_charset)
    ttlp->ttlp_enc = &eh__ISO8859_1;
  else
    {
      ttlp->ttlp_enc = eh_get_handler (CHARSET_NAME (query_charset, NULL));
      if (NULL == ttlp->ttlp_enc)
        ttlp->ttlp_enc = &eh__ISO8859_1;
    }
  if (box_length (base_uri) > 1)
    tf->tf_base_uri = box_copy (base_uri);
  tf->tf_line_no_ptr = &(ttlp->ttlp_lexlineno);
resume_sniffing:
  QR_RESET_CTX
    {
      if (sniffer_recovery)
        yy_push_state (GARBAGE, scanner);
      else
        {
          ttlyylex_init (&scanner);
          ttlyyset_extra (ttlp, scanner);
          if ((ttlp->ttlp_iter == file_read) && !lite_mode && (YY_BUF_SIZE < 0x10000))
            ttlyypush_buffer_state (ttlyy_create_buffer (NULL, (YY_BUF_SIZE > 0x2000) ? (YY_BUF_SIZE * 8) : 0x10000, scanner), scanner);
          if (flags & TTLP_SNIFFER)
            yy_push_state (GARBAGE_BOL, scanner);
          else
            {
#ifdef MALLOC_DEBUG
              yy_push_state (INITIAL, scanner);
#endif
            }
          tf_set_cbk_names (tf, (ccaddr_t *)cbk_names);
          TF_CHANGE_GRAPH_TO_DEFAULT (tf);
          /* ttlyydebug = 1; */
        }
      if (flags & TTLP_SNIFFER)
        ttlyyparse (ttlp, scanner);
      if (flags & TTLP_ALLOW_NQUAD)
        nqyyparse (ttlp, scanner);
      else
        ttlyyparse (ttlp, scanner);
      /* ttlyydebug = 0; */
      tf_commit (tf);
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      if (flags & TTLP_SNIFFER)
        {
          dk_free_tree (thr_get_error_code (self));
          thr_set_error_code (self, NULL);
          yy_pop_state (scanner);
          ttlp_reset_stacks (ttlp);
          sniffer_recovery = 2;
        }
      else
        {
          /* ttlyydebug = 0; */
          ttlp->ttlp_catched_error = thr_get_error_code (self);
          thr_set_error_code (self, NULL);
          if (NULL != ttlp->ttlp_iter_abend)
            {
              ttlp->ttlp_iter_abend (ttlp->ttlp_iter_data);
              ttlp->ttlp_iter_abend = NULL;
            }
        }
      /*no POP_QR_RESET*/;
    }
  END_QR_RESET
  if (2 == sniffer_recovery)
    {
      sniffer_recovery = 1;
      goto resume_sniffing;
    }
  if (NULL != srcfile)
    fclose (srcfile);
#ifdef MALLOC_DEBUG_1
  dbg_allows_free_nulls++;
#endif
  ttlyylex_destroy (scanner);
#ifdef MALLOC_DEBUG_1
  dbg_allows_free_nulls--;
#endif
  err_ret[0] = ttlp->ttlp_catched_error;
  ttlp->ttlp_catched_error = NULL;
  res = box_copy (graph_uri);
  ttlp_free (ttlp);
  return res;
}


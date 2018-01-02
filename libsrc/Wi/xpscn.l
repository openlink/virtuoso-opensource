/*
 *  xpscn.l
 *
 *  $Id$
 *
 *  XQuery scanner
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

%{
#include "Dk.h"
#include "sqlnode.h"
#include "xpath.h"
#include "sqlpar.h"
#include "sqlcmps.h"
#include "xmltree.h"
#include "xpathp_impl.h"
#include "sqlpfn.h"
#include "xpathp.h"
#include "numeric.h"
#include "sqlcstate.h"

#define xpyyerror(strg) xpyyerror_impl(xpp, xpyytext, (strg))

#define xpyylval (((YYSTYPE *)(yylval))[0])

xpp_t *xp_lex_env;
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
  do \
    { \
      int rest_len = xp_lex_env->xpp_text_len - xp_lex_env->xpp_text_ofs; \
      int get_len = (max_size); \
      if (get_len > rest_len) \
	get_len = rest_len; \
      memcpy ((buf), (xp_lex_env->xpp_text + xp_lex_env->xpp_text_ofs), get_len); \
      (result) = get_len; \
      xp_lex_env->xpp_text_ofs += get_len; \
    } while (0);

int xpscn_yy_null = YY_NULL;

#define GET_OUTER_BEGIN			((0 == xpp->xpp_lexdepth) ? UNREACHEABLE : xpp->xpp_lexstates[xpp->xpp_lexdepth-1])
#define GET_CURRENT_BEGIN		xpp->xpp_lexstates[xpp->xpp_lexdepth]
#define SET_CURRENT_BEGIN(state)	xpp->xpp_lexstates[xpp->xpp_lexdepth] = (state)
#define SET_INNER_BEGIN(state)		xpp->xpp_lexstates[xpp->xpp_lexdepth+1] = (state)
#define BEGIN_NEW_CURRENT(state)	BEGIN (xpp->xpp_lexstates[xpp->xpp_lexdepth] = (state))
#define BEGIN_CURRENT			BEGIN (xpp->xpp_lexstates[xpp->xpp_lexdepth])

static const char *xpyyerror_msg_toodeep = "The expression is too complex, or some closing parentheses are missing";
static const char *xpyyerror_msg_tooshallow = "Too many closing parentheses";

#define BEGIN_INNER \
  do \
    { \
      if (XPP_MAX_LEXDEPTH <= xpp->xpp_lexdepth) \
	xpyyerror (xpyyerror_msg_toodeep); \
      else \
	{ \
	  xpp->xpp_lexdepth += 1; \
	  BEGIN_CURRENT; \
	} \
    } while(0)

#define BEGIN_INNER_1(i) do { SET_INNER_BEGIN((i)); BEGIN_INNER; xpp->xpp_lexpars[xpp->xpp_lexdepth-1]='x'; } while (0)
#define BEGIN_INNER_2(i,c) do { SET_CURRENT_BEGIN((c)); SET_INNER_BEGIN((i)); BEGIN_INNER; xpp->xpp_lexpars[xpp->xpp_lexdepth-1]='x'; } while (0)

#define BEGIN_OUTER \
  do \
    { \
      if (0 == xpp->xpp_lexdepth) \
	xpyyerror (xpyyerror_msg_tooshallow); \
      else \
	{ \
	  xpp->xpp_lexdepth -= 1; \
	  BEGIN_CURRENT; \
	} \
    } while(0)

/* macro to save the text of a token */
#define SV  xpyylval.box = box_dv_short_nchars(xpyytext, xpyyleng);

/* macro to save the text and return a token */
#define TOK(name) { /*SV;*/ return name; }

/* macros to save the text of opening parenthesis and return a token */
#define TOKPAR_FAKE_OPEN(closing_char, state_i) \
    /*SV;*/ \
    SET_INNER_BEGIN (state_i); \
    BEGIN_INNER; \
    xpp->xpp_lexpars[xpp->xpp_lexdepth-1]=(closing_char)

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
    if (closing_char != xpp->xpp_lexpars[xpp->xpp_lexdepth]) \
      xpyyerror ("Parentheses are not balanced"); \

#define TOKPAR_CLOSE(name, closing_char) \
  { TOKPAR_FAKE_CLOSE(closing_char) \
    return name; \
  }

/* macro to save the text of closing parenthesis and return a token */
#define TOKPAR_CLOSE_3(name, closing_char, state) \
  { /*SV;*/ BEGIN_OUTER; BEGIN_NEW_CURRENT(state); \
    if (closing_char != xpp->xpp_lexpars[xpp->xpp_lexdepth]) \
      xpyyerror ("Parentheses are not balanced"); \
    return name; \
  }

static void xpyyerror_if_long_lname (xpp_t *xpp, caddr_t box, const char *lex_type_descr)
{
  size_t boxlen = box_length (box);
  char buf[100];
  if (boxlen > MAX_XML_LNAME_LENGTH)
    {
      snprintf (buf, sizeof (buf), "%.90s is too long", lex_type_descr);
      xpyyerror (buf);
    }
}

#define TOKBOX_L_FINAL(name,lex_type_descr) \
    if (box_length (xpyylval.box) > MAX_XML_LNAME_LENGTH) \
      xpyyerror_if_long_lname (xpp, xpyylval.box, lex_type_descr); \
    save_str(xpyytext); return (name);

#define TOKBOX_L(n,name,lex_type_descr) { \
    xpyylval.box = box_dv_uname_string (xpyytext+n); \
    TOKBOX_L_FINAL(name,lex_type_descr) }

/* No more dedicated UNAME case. All names are UNAMES :)
#define TOKBOX_UNAME_L(n,name,lex_type_descr) { xpyylval.box = box_dv_uname_string (xpyytext+n); \
    TOKBOX_L_FINAL(name,lex_type_descr) } */

#define TOKBOX_UPCASE_L(n,name,lex_type_descr) { \
    caddr_t tmp = sqlp_box_id_upcase (xpyytext+n); \
    xpyylval.box = box_dv_uname_string (tmp); \
    dk_free_box (tmp); \
    TOKBOX_L_FINAL(name,lex_type_descr) }

#define TOKBOX_QUOTED_L(n,name,lex_type_descr) { \
    caddr_t tmp = sqlp_box_id_quoted (xpyytext+n); \
    xpyylval.box = box_dv_uname_string (tmp); \
    dk_free_box (tmp); \
    TOKBOX_L_FINAL(name,lex_type_descr) }

#define TOKPAR_OPEN_LNAME(n,name,closing_char,state_i,state_c) \
{ \
    SET_CURRENT_BEGIN (state_c); \
    TOKPAR_FAKE_OPEN(closing_char, state_i); \
    do { \
      char *name_begin; \
      int name_len; \
      name_begin = xpyytext + (n); \
      name_begin += strspn (name_begin, " \t\r"); \
      name_len = strcspn (name_begin, " \t\r{"); \
      xpyylval.box = box_dv_uname_nchars (name_begin, name_len); \
	} while(0); \
    TOKBOX_L_FINAL(name,"Node name") }

static void xpyyerror_if_long_qname (xpp_t *xpp, caddr_t box, const char *lex_type_descr)
{
  size_t boxlen = box_length (box);
  char buf[100];
  char *colon;
  if (boxlen > MAX_XML_QNAME_LENGTH)
    {
      snprintf (buf, sizeof (buf), "%.90s is too long", lex_type_descr);
      xpyyerror (buf);
    }
  colon = strrchr (box, ':');
  if (NULL == colon)
    {
      if (boxlen > MAX_XML_LNAME_LENGTH)
	{
	  snprintf (buf, sizeof (buf), "%.90s is too long", lex_type_descr);
	  xpyyerror (buf);
	}
      return;
    }
  if (colon+1-box > MAX_XML_LNAME_LENGTH)
    {
      snprintf (buf, sizeof (buf), "%.90s contains abnormally long namespace prefix", lex_type_descr);
      xpyyerror (buf);
    }
  if (boxlen-(colon-box) > MAX_XML_LNAME_LENGTH)
    {
      snprintf (buf, sizeof (buf), "%.90s contains abnormally long 'local part' after the colon", lex_type_descr);
      xpyyerror (buf);
    }
}

#define TOKBOX_Q_FINAL(name,lex_type_descr) \
    if (box_length (xpyylval.box) > MAX_XML_LNAME_LENGTH) \
      xpyyerror_if_long_qname (xpp, xpyylval.box, lex_type_descr); \
    save_str(xpyytext); return (name);

#define TOKBOX_Q(n,name,lex_type_descr) { \
    xpyylval.box = box_dv_uname_string (xpyytext+(n)); \
    TOKBOX_Q_FINAL(name,lex_type_descr) }

#define TOKBOX_Q2(n1,n2,name,lex_type_descr) { \
    xpyylval.box = box_dv_uname_nchars (xpyytext + (n1), strlen(xpyytext) - ((n1)+(n2))); \
    TOKBOX_Q_FINAL(name,lex_type_descr) }

/* No more special UNAME case :)
#define TOKBOX_UNAME_Q(n,name,lex_type_descr) { \
    xpyylval.box = box_dv_uname_string (xpyytext+(n)); \
    TOKBOX_Q_FINAL(name,lex_type_descr) } */

#define TOKBOX_UPCASE_Q(n,name,lex_type_descr) { \
    caddr_t tmp = sqlp_box_id_upcase (xpyytext+(n)); \
    xpyylval.box = box_dv_uname_string (tmp); \
    dk_free_box (tmp); \
    TOKBOX_Q_FINAL(name,lex_type_descr) }

#define TOKBOX_QUOTED_Q(n,name,lex_type_descr) { \
    caddr_t tmp = sqlp_box_id_quoted (xpyytext+(n)); \
    xpyylval.box = box_dv_uname_string (tmp); \
    dk_free_box (tmp); \
    TOKBOX_Q_FINAL(name,lex_type_descr) }

#define TOKBOX_QWS(n,name,lex_type_descr) \
  { \
    do { \
      char *name_begin; \
      int name_len; \
      name_begin = xpyytext + (n); \
      name_begin += strspn (name_begin, " \t\r"); \
      if ('(' == name_begin[0]) \
        name_len = strstr (name_begin, "!)") + 2 - name_begin; \
      else \
        name_len = strcspn (name_begin, " \t\r{}?+*()"); \
      xpyylval.box = box_dv_uname_nchars (name_begin, name_len); \
      	} while(0); \
    TOKBOX_Q_FINAL(name,lex_type_descr) }

#define TOKPAR_OPEN_QNAME(n,name,closing_char,state_i,state_c) \
  { \
    SET_CURRENT_BEGIN (state_c); \
    TOKPAR_FAKE_OPEN(closing_char, state_i); \
    do { \
      char *name_begin; \
      int name_len; \
      name_begin = xpyytext + (n); \
      name_begin += strspn (name_begin, " \t\r"); \
      if ('(' == name_begin[0]) \
        name_len = strstr (name_begin, "!)") + 2 - name_begin; \
      else \
        name_len = strcspn (name_begin, " \t\r{}?+*()"); \
      xpyylval.box = box_dv_uname_nchars (name_begin, name_len); \
	} while(0); \
    TOKBOX_Q_FINAL(name,"Node name") }

static int xpscn_NUMBER_int (void *yylval, xpp_t *xpp)
{
  if (strlen (xpyytext) < 10)
    {
      xpyylval.box = box_num_nonull (atol (xpyytext));
      return NUMBER;
    }
  else
    {
      numeric_t num = numeric_allocate ();
      int rc = numeric_from_string (num, xpyytext);
      xpyylval.box = (caddr_t) num;
      if (NULL == xpyylval.box)
	xpyylval.box = box_num_nonull (0);
      if(rc != NUMERIC_STS_SUCCESS)
	xpyyerror ("The absolute value of numeric constant is too large");
      return NUMBER;
    }
}


static int xpscn_NUMBER_decimal (void *yylval, xpp_t *xpp)
{
  numeric_t num = numeric_allocate ();
  int rc = numeric_from_string (num, xpyytext);
  if (NUMERIC_STS_SUCCESS == rc)
    {
      xpyylval.box = (caddr_t) num;
      if (NULL == xpyylval.box)
	xpyylval.box = box_num_nonull (0);
      return NUMBER;
    }
  numeric_free (num);
  xpyylval.box = box_double (atof (xpyytext));
  return NUMBER;
}

static int xpscn_NUMBER_double (void *yylval, xpp_t *xpp)
{
  xpyylval.box = box_double (atof (xpyytext));
  return NUMBER;
}


%}

	/* Top-level XQuery state */
%x XQ

	/* Top-level free-text state */
%x FT

	/* XQuery 1.0 OPERATOR */
%x XQ_OP

	/* XQuery 1.0 NAMESPACEDECL */
%x XQ_NAMESPACE_DECL

	/* XQuery 1.0 NAMESPACEKEYWORD */
%x XQ_NAMESPACE_KWD

	/* XQuery 1.0 XMLSPACE_DECL is made implicit */

	/* XQuery 1.0 ITEMTYPE */
%x XQ_ITEM_TYPE

	/* XQuery 1.0 KINDTEST is divided into
	XQ_KT that ends with no OCCURRENCEINDICATOR and
	XQ_KT_OI that ends with an optional OCCURRENCEINDICATOR
	(when entered from ITEMTYPE). */
%x XQ_KT
%x XQ_KT_OI

	/* XQuery 1.0 KINDTESTFORPI (newer ends with OCCURRENCEINDICATOR) */
%x XQ_KT_FOR_PI

	/* XQuery 1.0 CLOSEKINDTEST is divided into
	XQ_CLOSE_KT that ends with no OCCURRENCEINDICATOR and
	XQ_CLOSE_KT_OI that ends with an optional OCCURRENCEINDICATOR
	(when entered from XQ_KT_OI). */
%x XQ_CLOSE_KT
%x XQ_CLOSE_KT_OI

	/* XQuery 1.0 OCCURRENCEINDICATOR is made implicit.
	It can occur in ITEMTYPE after QName and in
	ITEMTYPE, KINDTEST, KINDTESTFORPI, CLOSEKINDTEST after ')'.
	It's much easier to put 6 extra lexems for '?'/'*'/'+' after
	QName/')' than to get portability pain in the [beep] with yyunput()
	that is required for input_stream.backup(1) in one step with state
	change. */

	/* XQuery 1.0 SCHEMACONTEXTSTEP is divided into
	XQ_SCS that ends with no OCCURRENCEINDICATOR and
	XQ_SCS_OI that ends with an optional OCCURRENCEINDICATOR
	(when entered from XQ_KT_OI). */
%x XQ_SCS
%x XQ_SCS_OI

	/* XQuery 1.0 SCHEMACONTEXTSTEP */
%x XQ_VAR_NAME

	/* XQuery 1.0 START_TAG */
%x XQ_START_TAG
%x XQ_START_TAG_ATTRLIST

	/* XQuery 1.0 ELEMENT_CONTENT */
%x XQ_ELEMENT_CONTENT

	/* XQuery 1.0 END_TAG */
%x XQ_END_TAG

	/* XQuery 1.0 XML_COMMENT */
%x XQ_XML_COMMENT

	/* XQuery 1.0 EXPR_COMMENT */
%x XQ_EXPR_COMMENT

	/* XQuery 1.0 EXT_KEY */
%x XQ_EXT_KEY

	/* This is a replacement for EXPR_COMMENT in XQuery 1.0 EXT_KEY
	The idea is to have different lexems for text of comment and text of
	extension for syntax highlighting */
%x XQ_EXT_CONTENT

	/* XQuery 1.0 PROCESSING_INSTRUCTION */
%x XQ_PI

	/* XQuery 1.0 PROCESSING_INSTRUCTION_CONTENT */
%x XQ_PI_CONTENT_GAP
%x XQ_PI_CONTENT

	/* XQuery 1.0 PROCESSING_CDATA_SECTION */
%x XQ_CDATA_SECTION

	/* XQuery 1.0 QUOT_ATTRIBUTE_CONTENT */
%x XQ_DQ_ATTR

	/* XQuery 1.0 APOS_ATTRIBUTE_CONTENT */
%x XQ_SQ_ATTR

	/* Single-quoted string in XQ mode */
%x XQ_SQ

	/* Continuation of single-quoted string in XQ_DQ_ATTR mode after nested {expr} */
%x XQ_SQ_ATTR_CONT

	/* Double-quoted string in XQ mode */
%x XQ_DQ

	/* Continuation of double-quoted string in XQ_DQ_ATTR mode after nested {expr} */
%x XQ_DQ_ATTR_CONT

	/* Single-quoted string in FT mode */
%x FT_SQ

	/* Double-quoted string in FT mode */
%x FT_DQ

	/* State after "[" at the front of an expression */
%x PARAMLIST

	/* Special unreacheable state to fill the first item of xpp->xpp_lexstates */
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

SQ_PLAIN	([^\\''{}\r\n]|("''"))
DQ_PLAIN	([^\\""{}\r\n]|([""][""]))
S_BS		([\\].)
S_NL		((\r\n)|(\n\r)|\n|\r)
S_BSNL		([\\]{S_NL})

XMLNS_NCNAME	([A-Za-z_][A-Za-z0-9_.-]*)
XMLNS_QNAME1	(({XMLNS_NCNAME}":")?{XMLNS_NCNAME})
XMLNS_QNAME	({XMLNS_QNAME1}|("(!"[A-Za-z0-9:_./%#+-]+"!)"))
XMLNS_QQNAME	({XMLNS_NCNAME}":"({XMLNS_NCNAME}":")+{XMLNS_NCNAME})
XML_RESERVED	({X}{M}{L}([A-Za-z0-9_.-]*)":"{XMLNS_NCNAME})

WS		([ \t]+)
AXIS		(({WS})?"::")
NOARGS		({WS})?"("({WS})?")"

INTEGER_LITERAL ([0-9]+)
DECIMAL_LITERAL (([0-9]+"."[0-9]*)|("."[0-9]+))
DOUBLE_LITERAL	(({INTEGER_LITERAL}|{DECIMAL_LITERAL})[eE][+-]?[0-9]+)

XQ_DIGITS	([0-9]+)
XQ_HEX_DIGITS	([0-9a-fA-F]+)
XQ_CHAR_REF	((("&"([A-Za-z]+))|("&#"{XQ_DIGITS})|("&#x"{XQ_HEX_DIGITS}))";")

XP_EXEC_SQL_XPATH {E}{X}{E}{C}{WS}{S}{Q}{L}{WS}{X}{P}{A}{T}{H}

%%

	/* XQ DEFAULT row 1, part of XQ OPERATOR row 13 */
<XQ,XQ_OP>".."				{ BEGIN_NEW_CURRENT(XQ_OP); return _DOT_DOT; }
<XQ,XQ_OP>"."				{ BEGIN_NEW_CURRENT(XQ_OP); return _DOT; }
<XQ,XQ_OP>{INTEGER_LITERAL}		{ BEGIN_NEW_CURRENT(XQ_OP); return xpscn_NUMBER_int (yylval, xpp); }
<XQ,XQ_OP>{DECIMAL_LITERAL}		{ BEGIN_NEW_CURRENT(XQ_OP); return xpscn_NUMBER_decimal (yylval, xpp); }
<XQ,XQ_OP>{DOUBLE_LITERAL}		{ BEGIN_NEW_CURRENT(XQ_OP); return xpscn_NUMBER_double (yylval, xpp); }
	/* Rule for QName is moved after the end of XQ_OP state for proper priority */
<XQ,XQ_OP>"*:"{XMLNS_NCNAME}		{ BEGIN_NEW_CURRENT(XQ_OP); TOKBOX_Q (2, XQ_STAR_COLON_NCNAME, "Local part of name pattern"); }
<XQ,XQ_OP>{XMLNS_NCNAME}":*"		{ BEGIN_NEW_CURRENT(XQ_OP); TOKBOX_Q2 (0, 2, XQ_NCNAME_COLON_STAR, "Namespace part of name pattern"); }
<XQ>"*"					{ BEGIN_NEW_CURRENT(XQ_OP); return _STAR; }
<XQ,XQ_OP>['']				{ yymore(); xpp->xpp_string_literal_lexval = XQSQ_NSQSTRING_SQ; BEGIN_INNER_2(XQ_SQ,XQ_OP); }
<XQ,XQ_OP>[""]				{ yymore(); xpp->xpp_string_literal_lexval = XQDQ_NDQSTRING_DQ; BEGIN_INNER_2(XQ_DQ,XQ_OP); }
<XQ,XQ_OP>"]"				TOKPAR_CLOSE_3 (']',']',XQ_OP)
<XQ,XQ_OP>")"				TOKPAR_CLOSE_3 (')',')',XQ_OP)
<XQ>("declare"|"define"){WS}"validation"{WS}"lax"		{ return DECLARE_VALIDATION_LAX_L; }
<XQ>("declare"|"define"){WS}"validation"{WS}"skip"		{ return DECLARE_VALIDATION_SKIP_L; }
<XQ>("declare"|"define"){WS}"validation"{WS}"strict"	{ return DECLARE_VALIDATION_STRICT_L; }
<XQ>("declare"|"define"){WS}"validation"			{ xpyyerror("'lax', 'skip' or 'strict' expected after 'declare validation'"); }
	/* XQ DEFAULT row 2, XQ OPERATOR row 4, XQ OPERATOR row 6 */
<XQ>"module"{WS}"namespace"			{ BEGIN_NEW_CURRENT(XQ_NAMESPACE_DECL); return MODULE_NAMESPACE_L; }
<XQ,XQ_OP>("declare"|"define"){WS}"default"{WS}"collation"	{ BEGIN_NEW_CURRENT(XQ_NAMESPACE_DECL); return DECLARE_DEFAULT_COLLATION_L; }
<XQ,XQ_OP>("declare"|"define"){WS}"namespace"		{ BEGIN_NEW_CURRENT(XQ_NAMESPACE_DECL); return DECLARE_NAMESPACE_L; }
<XQ,XQ_OP>("declare"|"define"){WS}"base-uri"		{ BEGIN_NEW_CURRENT(XQ_NAMESPACE_DECL); return DECLARE_BASE_URI_L; }
	/* XQ DEFAULT row 3, XQ OPERATOR row 5 */
<XQ,XQ_OP>("declare"|"define"){WS}"default"{WS}"element"	{ BEGIN_NEW_CURRENT(XQ_NAMESPACE_KWD); return DECLARE_DEFAULT_ELEMENT_L; }
<XQ,XQ_OP>("declare"|"define"){WS}"default"{WS}"function"	{ BEGIN_NEW_CURRENT(XQ_NAMESPACE_KWD); return DECLARE_DEFAULT_FUNCTION_L; }
<XQ,XQ_OP>"import"{WS}"schema"			{ BEGIN_NEW_CURRENT(XQ_NAMESPACE_KWD); return IMPORT_SCHEMA_L; }
<XQ,XQ_OP>"import"{WS}"module"			{ BEGIN_NEW_CURRENT(XQ_NAMESPACE_KWD); return IMPORT_MODULE_L; }
	/* XQ DEFAULT row 4, XQ OPERATOR row 10, XQ_ITEM_TYPE row 1 */
<XQ,XQ_OP,XQ_ITEM_TYPE>"$"			{ BEGIN_NEW_CURRENT(XQ_VAR_NAME); return _DOLLAR; }
<XQ,XQ_OP>"for"{WS}"$"				{ BEGIN_NEW_CURRENT(XQ_VAR_NAME); return FOR_DOLLAR_L; }
<XQ,XQ_OP>"let"{WS}"$"				{ BEGIN_NEW_CURRENT(XQ_VAR_NAME); return LET_DOLLAR_L; }
<XQ,XQ_OP>"some"{WS}"$"				{ BEGIN_NEW_CURRENT(XQ_VAR_NAME); return SOME_DOLLAR_L; }
<XQ,XQ_OP>"every"{WS}"$"			{ BEGIN_NEW_CURRENT(XQ_VAR_NAME); return EVERY_DOLLAR_L; }
<XQ,XQ_OP,XQ_ITEM_TYPE>"?" {
    char tmp[20];
    BEGIN_NEW_CURRENT(XQ_OP);
    snprintf (tmp, sizeof (tmp), ":%d", param_inx++);
    xpyylval.box = box_dv_uname_string (tmp);
    return XQVARIABLE_POS;
  }
	/* XQ DEFAULT row 5 */
<XQ>("declare"|"define"){WS}"variable"{WS}"$"		{ BEGIN_NEW_CURRENT(XQ_VAR_NAME); return DECLARE_VARIABLE_DOLLAR_L; }
	/* XQ DEFAULT row 6, part of XQ OPERATOR row 7 */
<XQ,XQ_OP,XQ_ITEM_TYPE>")"{WS}?"as"		TOKPAR_CLOSE_3 (_RPAR_AS_L,')',XQ_ITEM_TYPE)
	/* XQ DEFAULT row 7 */
<XQ>"element"{WS}?"("				TOKPAR_OPEN_4 (ELEMENT_LPAR_L	, ')'	, XQ_KT, XQ_OP)
<XQ>"attribute"{WS}?"("				TOKPAR_OPEN_4 (ATTRIBUTE_LPAR_L	, ')'	, XQ_KT, XQ_OP)
<XQ>"comment"{WS}?"("				TOKPAR_OPEN_4 (COMMENT_LPAR_L	, ')'	, XQ_KT, XQ_OP)
<XQ>"text"{WS}?"("				TOKPAR_OPEN_4 (TEXT_LPAR_L	, ')'	, XQ_KT, XQ_OP)
<XQ>"node"{WS}?"("				TOKPAR_OPEN_4 (NODE_LPAR_L	, ')'	, XQ_KT, XQ_OP)
<XQ>"document-node"{WS}?"("			TOKPAR_OPEN_4 (DOCUMENT_NODE_LPAR_L, ')', XQ_KT, XQ_OP)
<XQ>"schema-element"{WS}?"("			TOKPAR_OPEN_4 (SCHEMA_ELEMENT_LPAR_L	, ')'	, XQ_KT, XQ_OP)
<XQ>"schema-attribute"{WS}?"("			TOKPAR_OPEN_4 (SCHEMA_ATTRIBUTE_LPAR_L	, ')'	, XQ_KT, XQ_OP)
	/* XQ DEFAULT row 8, XQ_ITEM_TYPE row 6 */
<XQ,XQ_ITEM_TYPE>"processing-instruction"{WS}?"("   TOKPAR_OPEN_4 (PI_LPAR_L, ')', XQ_KT_FOR_PI, XQ_OP)
	/* XQ DEFAULT row 9, part of XQ ELEMENT_CONTENT */
<XQ,XQ_ELEMENT_CONTENT>"<!--"			TOKPAR_OPEN (_LT_BANG_MINUS_MINUS, '-', XQ_XML_COMMENT)
	/* XQ DEFAULT row 10 */
<XQ,XQ_ELEMENT_CONTENT>"<?"			TOKPAR_OPEN (_LT_QMARK, '?', XQ_PI)
	/* XQ DEFAULT row 11 */
<XQ,XQ_ELEMENT_CONTENT>"<![CDATA["		TOKPAR_OPEN (_LT_BANG_CDATA, 'C', XQ_CDATA_SECTION)
	/* XQ DEFAULT row 12 */
<XQ>"<"						TOKPAR_OPEN_4 (_LT_OF_TAG, '>', XQ_START_TAG, XQ_OP)
<XQ>"</"					{ xpyyerror ("Ending tag can not appear before appropriate starting tag"); }

	/* XQ DEFAULT row 13, XQ OPERATOR row 8 */
<XQ,XQ_OP>("declare"|"define"){WS}"construction"{WS}"preserve"	{ BEGIN_NEW_CURRENT(XQ); return DECLARE_CONSTRUCTION_PRESERVE_L; }
<XQ,XQ_OP>("declare"|"define"){WS}"construction"{WS}"strip"	{ BEGIN_NEW_CURRENT(XQ); return DECLARE_CONSTRUCTION_STRIP_L; }
<XQ,XQ_OP>("declare"|"define"){WS}"xmlspace"{WS}"preserve"	{ BEGIN_NEW_CURRENT(XQ); return DECLARE_XMLSPACE_PRESERVE_L; }
<XQ,XQ_OP>("declare"|"define"){WS}"xmlspace"{WS}"strip"		{ BEGIN_NEW_CURRENT(XQ); return DECLARE_XMLSPACE_STRIP_L; }
<XQ,XQ_OP>("declare"|"define"){WS}"ordering"{WS}"ordered"	{ BEGIN_NEW_CURRENT(XQ); return DECLARE_ORDERING_ORDERED_L; }
<XQ,XQ_OP>("declare"|"define"){WS}"ordering"{WS}"unordered"	{ BEGIN_NEW_CURRENT(XQ); return DECLARE_ORDERING_UNORDERED_L; }
	/* XQ DEFAULT row 14, XQ_OPERATOR 9 */
<XQ,XQ_OP>"}"					{
						  TOKPAR_FAKE_CLOSE('}');
						  if ((XQ_SQ_ATTR_CONT == GET_CURRENT_BEGIN) || (XQ_DQ_ATTR_CONT == GET_CURRENT_BEGIN))
						    yymore();
						  else
						    return '}';
						}
	/* XQ DEFAULT row 15, XQ_OPERATOR row 3 */
<XQ,XQ_OP>"typeswitch"{WS}?"("			TOKPAR_OPEN_4 (TYPESWITCH_LPAR_L, ')', XQ, XQ_OP)
<XQ,XQ_OP>"validate"{WS}?"{"			TOKPAR_OPEN_4 (VALIDATE_LBRA_L, '}', XQ, XQ_OP)
<XQ,XQ_OP>"validate"{WS}"global"		{
						    /* This differs from W3C to avoid pushing without TOK_OPEN.
						    XQ_KT will do TOKPAR_OPEN_4 ('{', '}', XQ, XQ_OP) */
						  BEGIN_NEW_CURRENT(XQ_KT); return VALIDATE_GLOBAL_L; }
	/* XQ DEFAULT row 16 */
<XQ,XQ_OP>"validate"{WS}"context"		{ BEGIN_NEW_CURRENT(XQ_KT); return VALIDATE_CONTEXT_L; }
<XQ,XQ_OP>"validate"{WS}"lax"			{ BEGIN_NEW_CURRENT(XQ_KT); return VALIDATE_LAX_L; }
<XQ,XQ_OP>"validate"{WS}"strict"		{ BEGIN_NEW_CURRENT(XQ_KT); return VALIDATE_STRICT_L; }
<XQ,XQ_OP>"validate"{WS}"skip"			{ BEGIN_NEW_CURRENT(XQ_KT); return VALIDATE_SKIP_L; }
	/* XQ DEFAULT row 17 */
<XQ>"element"{WS}?"{"				TOKPAR_OPEN_4 (ELEMENT_LBRA_L, '}', XQ, XQ_OP) /* Differs from W3C */
<XQ>"attribute"{WS}?"{"				TOKPAR_OPEN_4 (ATTRIBUTE_LBRA_L, '}', XQ, XQ_OP) /* Differs from W3C */
	/* XQ DEFAULT row 18 */
   /*0         1         2  */
   /*01234567890123456789012*/
<XQ>"processing-instruction"{WS}{XMLNS_NCNAME}{WS}?"{"	TOKPAR_OPEN_LNAME (22, PI_LNAME_LBRA, '}', XQ, XQ_OP)
<XQ>"attribute"{WS}{XMLNS_QNAME}{WS}?"{"	TOKPAR_OPEN_QNAME (9, ATTRIBUTE_QNAME_LBRA, '}', XQ, XQ_OP)
<XQ>"namespace"{WS}{XMLNS_NCNAME}{WS}?"{"	TOKPAR_OPEN_LNAME (9, NAMESPACE_LNAME_LBRA, '}', XQ, XQ_OP)
<XQ>"element"{WS}{XMLNS_QNAME}{WS}?"{"		TOKPAR_OPEN_QNAME (7, ELEMENT_QNAME_LBRA, '}', XQ, XQ_OP)
<XQ>"document"{WS}?"{"				TOKPAR_OPEN_4 (DOCUMENT_LBRA_L, '}', XQ, XQ_OP)
<XQ>"text"{WS}?"{"				TOKPAR_OPEN_4 (TEXT_LBRA_L, '}', XQ, XQ_OP)
<XQ>"processing-instruction"{WS}?"{"		TOKPAR_OPEN_4 (PI_LBRA_L, '}', XQ, XQ_OP)
<XQ>"comment"{WS}?"{"				TOKPAR_OPEN_4 (COMMENT_LBRA_L, '}', XQ, XQ_OP)
	/* XQ DEFAULT row 19, XQ_OPERATOR row 1 */
<XQ,XQ_OP>("declare"|"define"){WS}"function"		{ return DECLARE_FUNCTION_L; }
	/* XQ DEFAULT row 20, XQ OPERATOR row 11, XQ ITEMTYPE row 3, XQ NAMESPACEDECL row 2 etc. */
<XQ,XQ_OP,XQ_NAMESPACE_DECL,XQ_NAMESPACE_KWD,XQ_ITEM_TYPE,XQ_KT,XQ_KT_FOR_PI,XQ_CLOSE_KT,XQ_SCS,XQ_VAR_NAME,XQ_EXPR_COMMENT>"(:"   { TOKPAR_FAKE_OPEN (':', XQ_EXPR_COMMENT); }
	/* XQ DEFAULT row 21, XQ OPERATOR row 12, XQ ITEMTYPE row 4, XQ NAMESPACEDECL row 3 etc. */
<XQ,XQ_OP,XQ_NAMESPACE_DECL,XQ_NAMESPACE_KWD,XQ_ITEM_TYPE,XQ_KT,XQ_KT_FOR_PI,XQ_CLOSE_KT,XQ_SCS,XQ_VAR_NAME,XQ_EXPR_COMMENT>"(::"   { TOKPAR_FAKE_OPEN ('#', XQ_EXT_KEY); }
	/* XQ DEFAULT row 22 */
<XQ,XQ_OP>"ancestor"{AXIS}			{ BEGIN_NEW_CURRENT(XQ); return A_ANCESTOR; }
<XQ,XQ_OP>"ancestor-or-self"{AXIS}		{ BEGIN_NEW_CURRENT(XQ); return A_ANCESTOR_OR_SELF; }
<XQ,XQ_OP>"attribute"{AXIS}			{ BEGIN_NEW_CURRENT(XQ); return A_ATTRIBUTE; }
<XQ,XQ_OP>"child"{AXIS}				{ BEGIN_NEW_CURRENT(XQ); return A_CHILD; }
<XQ,XQ_OP>"descendant"{AXIS}			{ BEGIN_NEW_CURRENT(XQ); return A_DESCENDANT; }
<XQ,XQ_OP>"descendant-or-self"{AXIS}		{ BEGIN_NEW_CURRENT(XQ); return A_DESCENDANT_OR_SELF; }
<XQ,XQ_OP>"following"{AXIS}			{ BEGIN_NEW_CURRENT(XQ); return A_FOLLOWING; }
<XQ,XQ_OP>"following-sibling"{AXIS}		{ BEGIN_NEW_CURRENT(XQ); return A_FOLLOWING_SIBLING; }
<XQ,XQ_OP>"namespace"{AXIS}			{ BEGIN_NEW_CURRENT(XQ); return A_NAMESPACE; }
<XQ,XQ_OP>"parent"{AXIS}			{ BEGIN_NEW_CURRENT(XQ); return A_PARENT; }
<XQ,XQ_OP>"preceding"{AXIS}			{ BEGIN_NEW_CURRENT(XQ); return A_PRECEDING; }
<XQ,XQ_OP>"preceding-sibling"{AXIS}		{ BEGIN_NEW_CURRENT(XQ); return A_PRECEDING_SIBLING; }
<XQ,XQ_OP>"self"{AXIS}				{ BEGIN_NEW_CURRENT(XQ); return A_SELF; }
<XQ,XQ_OP>"{"					TOKPAR_OPEN_4 ('{', '}', XQ, XQ_OP)
<XQ,XQ_OP>"ordered"{WS}?"{"			TOKPAR_OPEN_4 (ORDERED_LBRA_L, '}', XQ, XQ_OP)
<XQ,XQ_OP>"unordered"{WS}?"{"			TOKPAR_OPEN_4 (UNORDERED_LBRA_L, '}', XQ, XQ_OP)
<XQ>"xquery"{WS}"version"{WS}['']		{ yymore(); xpp->xpp_string_literal_lexval = XQ_XQUERY_VERSION_SQ_NSQSTRING_SQ; BEGIN_INNER_2(XQ_SQ,XQ); }
<XQ>"xquery"{WS}"version"{WS}[""]		{ yymore(); xpp->xpp_string_literal_lexval = XQ_XQUERY_VERSION_DQ_NDQSTRING_DQ; BEGIN_INNER_2(XQ_DQ,XQ); }
<XQ,XQ_OP,XQ_NAMESPACE_KWD,XQ_ITEM_TYPE>"at"{WS}['']		{ yymore(); xpp->xpp_string_literal_lexval = XQ_AT_SQ_NSQSTRING_SQ; BEGIN_INNER_2(XQ_SQ,XQ); }
<XQ,XQ_OP,XQ_NAMESPACE_KWD,XQ_ITEM_TYPE>"at"{WS}[""]		{ yymore(); xpp->xpp_string_literal_lexval = XQ_AT_DQ_NDQSTRING_DQ; BEGIN_INNER_2(XQ_DQ,XQ); }
<XQ,XQ_OP>"@"					{ BEGIN_NEW_CURRENT(XQ); return _AT; }
<XQ,XQ_OP,XQ_ITEM_TYPE>","			{ BEGIN_NEW_CURRENT(XQ); return ','; }
<XQ,XQ_OP>"if"{WS}"("				TOKPAR_OPEN_4 (IF_LPAR_L, ')', XQ, XQ)
<XQ,XQ_OP,XQ_ITEM_TYPE>"("			TOKPAR_OPEN ('(', ')', XQ)
<XQ,XQ_OP,XQ_ITEM_TYPE>"["  	{
	  if (2 > xpp->xpp_total_lexems_parsed)
	    {
	      TOKPAR_OPEN_4 ('[',']', PARAMLIST, XQ)	/* Differs from W3C, see <XQ>"]" */
	    }
	  else
	    {
	      TOKPAR_OPEN_4 ('[',']', XQ, XQ_OP)	/* Differs from W3C, see <XQ>"]" */
	    }
	}
<XQ,XQ_OP,XQ_ITEM_TYPE>"-"			{ BEGIN_NEW_CURRENT(XQ); return _MINUS; }
<XQ,XQ_OP>"+"					{ BEGIN_NEW_CURRENT(XQ); return _PLUS; }
<XQ>{XMLNS_QNAME}{WS}?"("			TOKPAR_OPEN_QNAME (0, XQCNAME_LPAR, ')', XQ, XQ_OP) /* Differs from W3C, see <XQ>")" */
<XQ>"not"{WS}{XMLNS_QNAME}{WS}?"("		TOKPAR_OPEN_QNAME (3, NOT_XQCNAME_LPAR, ')', XQ, XQ_OP) /* not in W3C, see <XQ>")" */
<XQ,XQ_OP,XQ_ITEM_TYPE>";"			{ BEGIN_NEW_CURRENT(XQ); return ';'; }
<XQ,XQ_OP>"//"					{ BEGIN_NEW_CURRENT(XQ); return _SLASH_SLASH; }
<XQ,XQ_OP>"/"					{ BEGIN_NEW_CURRENT(XQ); return _SLASH; }


	/* XQ OPERATOR row 1 is in XQ DEFAULT row 13 */
	/* XQ OPERATOR row 2
	    <"at" StringLiteral>, ',', '(', '[', '-', '+', ';', '//', '/' '{' are in XQ DEFAULT row 22
	    SchemaMode is moved to KT state and aggregated with <declare validation> in DEFAULT row 1 */
<XQ_OP,XQ_ITEM_TYPE>"external"			{ BEGIN_NEW_CURRENT(XQ); return EXTERNAL_L; }
<XQ_OP,XQ_ITEM_TYPE>"and"			{ BEGIN_NEW_CURRENT(XQ); return K_AND; }
<XQ_OP,XQ_ITEM_TYPE>"at"			{ BEGIN_NEW_CURRENT(XQ); return AT_L; }
<XQ_OP,XQ_ITEM_TYPE>":="			{ BEGIN_NEW_CURRENT(XQ); return _ASSIGN; }
<XQ_OP,XQ_ITEM_TYPE>"div"			{ BEGIN_NEW_CURRENT(XQ); return K_DIV; }
<XQ_OP,XQ_ITEM_TYPE>"else"			{ BEGIN_NEW_CURRENT(XQ); return ELSE_L; }
<XQ_OP,XQ_ITEM_TYPE>"="				{ BEGIN_NEW_CURRENT(XQ); return _EQ; }
<XQ_OP,XQ_ITEM_TYPE>"=="			{ BEGIN_NEW_CURRENT(XQ); return _SAME; }
<XQ_OP,XQ_ITEM_TYPE>"=>"			{ BEGIN_NEW_CURRENT(XQ); return _POINTER_VIA_ID; }
<XQ_OP,XQ_ITEM_TYPE>"except"			{ BEGIN_NEW_CURRENT(XQ); return EXCEPT_L; }
<XQ_OP,XQ_ITEM_TYPE>"eq"			{ BEGIN_NEW_CURRENT(XQ); return K2_EQ_L; }
<XQ_OP,XQ_ITEM_TYPE>"ge"			{ BEGIN_NEW_CURRENT(XQ); return K2_GE_L; }
<XQ_OP,XQ_ITEM_TYPE>"gt"			{ BEGIN_NEW_CURRENT(XQ); return K2_GT_L; }
<XQ_OP,XQ_ITEM_TYPE>"le"			{ BEGIN_NEW_CURRENT(XQ); return K2_LE_L; }
<XQ_OP,XQ_ITEM_TYPE>"lt"			{ BEGIN_NEW_CURRENT(XQ); return K2_LT_L; }
<XQ_OP,XQ_ITEM_TYPE>"ne"			{ BEGIN_NEW_CURRENT(XQ); return K2_NE_L; }
<XQ_OP,XQ_ITEM_TYPE>">="			{ BEGIN_NEW_CURRENT(XQ); return _GE; }
<XQ_OP,XQ_ITEM_TYPE>">>"			{ BEGIN_NEW_CURRENT(XQ); return _GT_GT; }
<XQ_OP,XQ_ITEM_TYPE>">"				{ BEGIN_NEW_CURRENT(XQ); return _GT; }
<XQ_OP,XQ_ITEM_TYPE>"idiv"			{ BEGIN_NEW_CURRENT(XQ); return K_IDIV; }
<XQ_OP>"global"					{ BEGIN_NEW_CURRENT(XQ); return GLOBAL_L; }
<XQ_OP,XQ_ITEM_TYPE>"intersect"			{ BEGIN_NEW_CURRENT(XQ); return INTERSECT_L; }
<XQ_OP,XQ_ITEM_TYPE>"in"			{ BEGIN_NEW_CURRENT(XQ); return IN_L; }
<XQ_OP,XQ_ITEM_TYPE>"is"			{ BEGIN_NEW_CURRENT(XQ); return _SAME; }
<XQ_OP,XQ_ITEM_TYPE>"<="			{ BEGIN_NEW_CURRENT(XQ); return _LE; }
<XQ_OP,XQ_ITEM_TYPE>"<<"			{ BEGIN_NEW_CURRENT(XQ); return _LT_LT; }
<XQ_OP,XQ_ITEM_TYPE>"<"				{ BEGIN_NEW_CURRENT(XQ); return _LT; }
<XQ_OP,XQ_ITEM_TYPE>"mod"			{ BEGIN_NEW_CURRENT(XQ); return K_MOD; }
<XQ_OP,XQ_ITEM_TYPE>"like"			{ BEGIN_NEW_CURRENT(XQ); return K_LIKE; }
<XQ_OP,XQ_ITEM_TYPE>"near"			{ BEGIN_NEW_CURRENT(XQ); return K_NEAR; }
<XQ_OP>"*"					{ BEGIN_NEW_CURRENT(XQ); return _STAR; }
<XQ_OP,XQ_ITEM_TYPE>"\!="			{ BEGIN_NEW_CURRENT(XQ); return _NOT_EQ; }
<XQ_OP,XQ_ITEM_TYPE>"\!=="			{ BEGIN_NEW_CURRENT(XQ); return _NOT_SAME; }
<XQ_OP,XQ_ITEM_TYPE>"order"{WS}"by"		{ BEGIN_NEW_CURRENT(XQ); return ORDER_BY_L; }
<XQ_OP,XQ_ITEM_TYPE>"stable"{WS}"order"{WS}"by"	{ BEGIN_NEW_CURRENT(XQ); return STABLE_ORDER_BY_L; }
<XQ_OP,XQ_ITEM_TYPE>"or"			{ BEGIN_NEW_CURRENT(XQ); return K_OR; }
<XQ_OP,XQ_ITEM_TYPE>"return"			{ BEGIN_NEW_CURRENT(XQ); return RETURN_L; }
<XQ_OP,XQ_ITEM_TYPE>"satisfies"			{ BEGIN_NEW_CURRENT(XQ); return SATISFIES_L; }
<XQ_OP,XQ_ITEM_TYPE>"then"			{ BEGIN_NEW_CURRENT(XQ); return THEN_L; }
<XQ_OP,XQ_ITEM_TYPE>"to"			{ BEGIN_NEW_CURRENT(XQ); return TO_L; }
<XQ_OP,XQ_ITEM_TYPE>"union"			{ BEGIN_NEW_CURRENT(XQ); return UNION_L; }
<XQ_OP,XQ_ITEM_TYPE>"|"				{ BEGIN_NEW_CURRENT(XQ); return '|'; }
<XQ_OP,XQ_ITEM_TYPE>"where"			{ BEGIN_NEW_CURRENT(XQ); return WHERE_L; }
<XQ_OP,XQ_ITEM_TYPE>"after"			{ BEGIN_NEW_CURRENT(XQ); return AFTER_L; }
<XQ_OP,XQ_ITEM_TYPE>"before"			{ BEGIN_NEW_CURRENT(XQ); return BEFORE_L; }
<XQ_OP,XQ_ITEM_TYPE>"sort"({WS}?)"by"({WS}?)"("	TOKPAR_OPEN (SORTBY_LPAR_L, ')', XQ)
	/* XQ OPERATOR row 3 is in XQ DEFAULT row 15 */
	/* XQ OPERATOR row 4 is in XQ DEFAULT row 2 */
	/* XQ OPERATOR row 5 is in XQ DEFAULT row 3 */
	/* XQ OPERATOR row 6 is in XQ DEFAULT row 2 */
	/* XQ OPERATOR row 7
	    <')' as is in XQ DEFAULT row 6 */
<XQ_OP,XQ_ITEM_TYPE>"instance"{WS}"of"		{ BEGIN_NEW_CURRENT(XQ_ITEM_TYPE); return INSTANCE_OF_L; }
<XQ_OP,XQ_ITEM_TYPE>"castable"{WS}"as"{WS}{XMLNS_QNAME}  {
    BEGIN_NEW_CURRENT (XQ_OP);
    TOKBOX_QWS (strstr (xpyytext+8, "as") + 2 - xpyytext, XQ_CASTABLE_AS_CNAME, "Type name in 'castable as' expression");
  }
<XQ_OP,XQ_ITEM_TYPE>"cast"{WS}"as"{WS}{XMLNS_QNAME}  {
    BEGIN_NEW_CURRENT (XQ_OP);
    TOKBOX_QWS (strstr (xpyytext+4, "as") + 2 - xpyytext, XQ_CAST_AS_CNAME, "Type name in 'cast as' expression");
  }
<XQ_OP,XQ_ITEM_TYPE>"treat"{WS}"as"		{ BEGIN_NEW_CURRENT(XQ_ITEM_TYPE); return TREAT_AS_L; }
<XQ_OP,XQ_ITEM_TYPE>"case"			{ BEGIN_NEW_CURRENT(XQ_ITEM_TYPE); return CASE_L; }
<XQ_OP,XQ_ITEM_TYPE>"as"			{ BEGIN_NEW_CURRENT(XQ_ITEM_TYPE); return AS_L; }
	/* XQ OPERATOR row 8 is in XQ DEFAULT row 13 */
	/* XQ OPERATOR row 9 is in XQ DEFAULT row 14 */
	/* XQ OPERATOR row 10 is in XQ DEFAULT row 4 */
	/* XQ OPERATOR row 11 is in XQ DEFAULT row 20 */
	/* XQ OPERATOR row 12 is in XQ DEFAULT row 21 */
	/* XQ OPERATOR row 13
	    ']', IntegerLiteral, DecimalLiteral, DoubleLiteral, ')', StringLiteral,
	    QName, <NCName ":" "*">, <"*" ":" NCName">, '.', '..' are in XQ DEFAULT row 1 */
<XQ_OP>"collation"				{ return COLLATION_L; }
<XQ_OP>"ascending"				{ return ASCENDING_L; }
<XQ_OP>"descending"				{ return DESCENDING_L; }
<XQ_OP>"empty"{WS}"greatest"			{ return EMPTY_GREATEST_L; }
<XQ_OP>"empty"{WS}"least"			{ return EMPTY_LEAST_L; }
<XQ_OP>"default"				{ return DEFAULT_L; }

	/* Rule for Qname is here for priority reasons */
<XQ,XQ_OP>{XML_RESERVED}		        { BEGIN_NEW_CURRENT(XQ_OP); TOKBOX_Q (0, XQNAMERESERVED, "Reserved XML name"); }
<XQ,XQ_OP>"sql:column"				TOK (SQL_COLON_COLUMN)
<XQ,XQ_OP>"not"					{ BEGIN_NEW_CURRENT(XQ_OP); return K_NOT; }
<XQ,XQ_OP>{XMLNS_QNAME}				{ BEGIN_NEW_CURRENT(XQ_OP); TOKBOX_Q (0, XQCNAME, "Qualified XML name"); }
<XQ,XQ_OP>"\\"[A-Za-z_][A-Za-z0-9_:\\]*		{ TOKBOX_Q (1, XQCNAME, "Name"); }

	/* <XQ>{XMLNS_NCNAME}			TOKBOX_L (0, XQNCNAME, "Name") */

	/* XQ NAMESPACEDECL row 1 */
<XQ_NAMESPACE_DECL,XQ_NAMESPACE_KWD>['']	{ yymore(); xpp->xpp_string_literal_lexval = XQSQ_NSQSTRING_SQ; BEGIN_INNER_2(XQ_SQ,XQ); }
<XQ_NAMESPACE_DECL,XQ_NAMESPACE_KWD>[""]	{ yymore(); xpp->xpp_string_literal_lexval = XQDQ_NDQSTRING_DQ; BEGIN_INNER_2(XQ_DQ,XQ); }
	/* XQ NAMESPACEDECL row 2 is in XQ DEFAULT row 20 */
	/* XQ NAMESPACEDECL row 3 is in XQ DEFAULT row 21 */
	/* XQ NAMESPACEDECL row 4 */
<XQ_NAMESPACE_DECL>"="				{ return _EQ; }
<XQ_NAMESPACE_DECL>{XMLNS_NCNAME}		TOKBOX_L (0, XQNCNAME, "Prefix in namespace declaration");

	/* XQ NAMESPACEKEYWORD
	    StringLiteral is in XQ NAMESPACEDECL row1, <"at" StringLiteral> is in XQ DEFAULT row 22
	    '(:' is in XQ DEFAULT row 20, '(::' is in XQ DEFAULT row 21 */
<XQ_NAMESPACE_KWD>"namespace"				{ BEGIN_NEW_CURRENT (XQ_NAMESPACE_DECL); return NAMESPACE_L; }
<XQ_NAMESPACE_KWD>"default"{WS}"element"		{ return DEFAULT_ELEMENT_L; }
<XQ_NAMESPACE_KWD>("declare"|"define"){WS}"default"{WS}"element"	{ return DECLARE_DEFAULT_ELEMENT_L; }
<XQ_NAMESPACE_KWD>("declare"|"define"){WS}"default"{WS}"function"	{ return DECLARE_DEFAULT_FUNCTION_L; }

	/* XQ XMLSPACE_DECL is made implicit */

	/* XQ ITEM_TYPE row 1 is in XQ DEFAULT row 4 */
	/* XQ ITEM_TYPE row 2 */
<XQ_ITEM_TYPE>"empty"{WS}?"("{WS}?")"		{ BEGIN_NEW_CURRENT (XQ_OP); return EMPTY_LPAR_RPAR_L; }
	/* XQ ITEM_TYPE row 3 is in XQ DEFAULT row 20 */
	/* XQ ITEM_TYPE row 4 is in XQ DEFAULT row 21 */
	/* XQ ITEM_TYPE row 5 */
<XQ_ITEM_TYPE>"element"{WS}?"("			TOKPAR_OPEN_4 (ELEMENT_LPAR_L	, ')'	, XQ_KT_OI, XQ_OP)
<XQ_ITEM_TYPE>"attribute"{WS}?"("		TOKPAR_OPEN_4 (ATTRIBUTE_LPAR_L	, ')'	, XQ_KT_OI, XQ_OP)
<XQ_ITEM_TYPE>"comment"{WS}?"("			TOKPAR_OPEN_4 (COMMENT_LPAR_L	, ')'	, XQ_KT_OI, XQ_OP)
<XQ_ITEM_TYPE>"text"{WS}?"("			TOKPAR_OPEN_4 (TEXT_LPAR_L	, ')'	, XQ_KT_OI, XQ_OP)
<XQ_ITEM_TYPE>"node"{WS}?"("			TOKPAR_OPEN_4 (NODE_LPAR_L	, ')'	, XQ_KT_OI, XQ_OP)
<XQ_ITEM_TYPE>"document-node"{WS}?"("		TOKPAR_OPEN_4 (DOCUMENT_NODE_LPAR_L, ')', XQ_KT_OI, XQ_OP)
<XQ_ITEM_TYPE>"schema-attribute"{WS}?"("		TOKPAR_OPEN_4 (SCHEMA_ATTRIBUTE_LPAR_L	, ')'	, XQ_KT_OI, XQ_OP)
<XQ_ITEM_TYPE>"schema-element"{WS}?"("		TOKPAR_OPEN_4 (SCHEMA_ELEMENT_LPAR_L	, ')'	, XQ_KT_OI, XQ_OP)
	/* XQ ITEM_TYPE row 6 in is XQ DEFAULT row 8 */
	/* XQ ITEM_TYPE row 7 */
<XQ_ITEM_TYPE>{XMLNS_QNAME}{WS}?"*"		{ BEGIN_NEW_CURRENT(XQ_OP); TOKBOX_QWS (0, XQ_CNAME_STAR, "Name in item type"); }
<XQ_ITEM_TYPE>{XMLNS_QNAME}{WS}?"+"		{ BEGIN_NEW_CURRENT(XQ_OP); TOKBOX_QWS (0, XQ_CNAME_PLUS, "Name in item type"); }
<XQ_ITEM_TYPE>{XMLNS_QNAME}{WS}?"?"		{ BEGIN_NEW_CURRENT(XQ_OP); TOKBOX_QWS (0, XQ_CNAME_QMARK, "Name in item type"); }
<XQ_ITEM_TYPE>{XMLNS_QNAME}			{ BEGIN_NEW_CURRENT(XQ_OP); TOKBOX_Q (0, XQCNAME, "Name in item type"); }
<XQ_ITEM_TYPE>"item"{WS}?"("{WS}?")"{WS}?"*"	{ BEGIN_NEW_CURRENT(XQ_OP); return ITEM_LPAR_RPAR_STAR_L; }
<XQ_ITEM_TYPE>"item"{WS}?"("{WS}?")"{WS}?"+"	{ BEGIN_NEW_CURRENT(XQ_OP); return ITEM_LPAR_RPAR_PLUS_L; }
<XQ_ITEM_TYPE>"item"{WS}?"("{WS}?")"{WS}?"?"	{ BEGIN_NEW_CURRENT(XQ_OP); return ITEM_LPAR_RPAR_QMARK_L; }
<XQ_ITEM_TYPE>"item"{WS}?"("{WS}?")"		{ BEGIN_NEW_CURRENT(XQ_OP); return ITEM_LPAR_RPAR_L; }

	/* XQ KINDTEST */
<XQ_KT>"lax"				{ return LAX_L; }
<XQ_KT>"strict"				{ return STRICT_L; }
<XQ_KT>"skip"				{ return SKIP_L; }
<XQ_KT,XQ_KT_OI,XQ_CLOSE_KT,XQ_CLOSE_KT_OI,XQ_SCS,XQ_SCS_OI>"{"		TOKPAR_OPEN_4 ('{', '}', XQ, XQ_OP)
<XQ_KT,XQ_KT_OI>"type"{WS}?"("{WS}?{XMLNS_QNAME}{WS}?")"  {
    BEGIN_NEW_CURRENT ((XQ_KT==GET_CURRENT_BEGIN) ? XQ_SCS : XQ_SCS_OI);
    TOKBOX_QWS (strchr (xpyytext, '(') + 1 - xpyytext, XQ_TYPE_LPAR_CNAME_RPAR, "Type name in schema global context");
  }
<XQ_KT,XQ_KT_OI>"/"			{
    BEGIN_NEW_CURRENT ((XQ_KT==GET_CURRENT_BEGIN) ? XQ_SCS : XQ_SCS_OI);
    return _SLASH;
  }
<XQ_KT,XQ_KT_OI>{XMLNS_QNAME}{WS}?"/"  {
    BEGIN_NEW_CURRENT ((XQ_KT==GET_CURRENT_BEGIN) ? XQ_SCS : XQ_SCS_OI);
    TOKBOX_QWS (0, XQ_CNAME_SLASH, "Name in schema global context");
  }
<XQ_KT_OI,XQ_CLOSE_KT_OI>")"{WS}?"*"		TOKPAR_CLOSE (_RPAR_STAR, ')')
<XQ_KT_OI,XQ_CLOSE_KT_OI>")"{WS}?"+"		TOKPAR_CLOSE (_RPAR_PLUS, ')')
<XQ_KT_OI,XQ_CLOSE_KT_OI>")"{WS}?"?"		TOKPAR_CLOSE (_RPAR_QMARK, ')')
<XQ_KT,XQ_KT_OI,XQ_KT_FOR_PI,XQ_CLOSE_KT,XQ_CLOSE_KT_OI>")"		TOKPAR_CLOSE (')', ')')
<XQ_KT,XQ_KT_OI>"*"				{ BEGIN_NEW_CURRENT((XQ_KT==GET_CURRENT_BEGIN) ? XQ_CLOSE_KT : XQ_CLOSE_KT_OI); return _STAR; }
<XQ_KT,XQ_KT_OI>"element"{WS}?"("		TOKPAR_OPEN (ELEMENT_LPAR_L	, ')'	, XQ_KT)
<XQ_KT,XQ_KT_OI,XQ_SCS,XQ_SCS_OI>"@"		{ return _AT; }
<XQ_KT,XQ_KT_OI>"context"			{ return CONTEXT_L; }
<XQ_KT,XQ_KT_OI>"global"			{ return GLOBAL_L; }
<XQ_KT,XQ_KT_OI,XQ_KT_FOR_PI>['']		{ yymore(); xpp->xpp_string_literal_lexval = XQSQ_NSQSTRING_SQ; BEGIN_INNER_1(XQ_SQ); }
<XQ_KT,XQ_KT_OI,XQ_KT_FOR_PI>[""]		{ yymore(); xpp->xpp_string_literal_lexval = XQDQ_NDQSTRING_DQ; BEGIN_INNER_1(XQ_DQ); }
	/* The rule for QName is moved here for priority reasons */
<XQ_KT,XQ_KT_OI>{XMLNS_QNAME}			{ BEGIN_NEW_CURRENT((XQ_KT==GET_CURRENT_BEGIN) ? XQ_CLOSE_KT : XQ_CLOSE_KT_OI); TOKBOX_Q(0, XQCNAME, "Qualified name") }

	/* XQ KINDTESTFORPI */
<XQ_KT_FOR_PI>{XMLNS_NCNAME}			TOKBOX_L(0, XQNCNAME, "Name of processing instruction")

	/* XQ CLOSEKINDTEST */
<XQ_CLOSE_KT,XQ_CLOSE_KT_OI>","			{ BEGIN_NEW_CURRENT((XQ_CLOSE_KT==GET_CURRENT_BEGIN) ? XQ_KT : XQ_KT_OI); return ','; }
<XQ_CLOSE_KT,XQ_CLOSE_KT_OI>"nillable"		{ return NILLABLE_L; }

	/* XQ SCHEMACONTEXTSTEP */
<XQ_SCS,XQ_SCS_OI>"/"				{ return _SLASH; }
<XQ_SCS,XQ_SCS_OI>{XMLNS_QNAME}{WS}?"/"		{ TOKBOX_QWS (0, XQ_CNAME_SLASH, "Name in schema context step"); }
<XQ_SCS,XQ_SCS_OI>{XMLNS_QNAME}			{ BEGIN_NEW_CURRENT((XQ_SCS==GET_CURRENT_BEGIN) ? XQ_CLOSE_KT : XQ_CLOSE_KT_OI); TOKBOX_Q(0, XQCNAME, "Name in schema context step") }

	/* XQ VAR_NAME */
<XQ_VAR_NAME>{XMLNS_NCNAME}			{ BEGIN_NEW_CURRENT(XQ_OP); TOKBOX_L (0, XQVARIABLE_NAME, "Name of variable") }
<XQ_VAR_NAME>{XMLNS_QNAME}			{ xpyyerror ("Name of variable should be a local name, no colon allowed"); }
<XQ_VAR_NAME><<EOF>>				{ xpyyerror ("Missing name of variable"); }

	/* XQ START_TAG */
<XQ_START_TAG,XQ_START_TAG_ATTRLIST>"/>"	TOKPAR_CLOSE (_SLASH_GT, '>')
<XQ_START_TAG,XQ_START_TAG_ATTRLIST>">"		{ BEGIN_NEW_CURRENT(XQ_ELEMENT_CONTENT); return _GT_OF_TAG; }
<XQ_START_TAG,XQ_START_TAG_ATTRLIST>['']	{ yymore(); BEGIN_INNER_1(XQ_SQ_ATTR); }
<XQ_START_TAG,XQ_START_TAG_ATTRLIST>[""]	{ yymore(); BEGIN_INNER_1(XQ_DQ_ATTR); }
<XQ_START_TAG,XQ_START_TAG_ATTRLIST>"{"		TOKPAR_OPEN_4 ('{', '}', XQ, XQ_START_TAG_ATTRLIST)
<XQ_START_TAG_ATTRLIST>"="			{ return _EQ; }
<XQ_START_TAG>{XMLNS_QNAME}			{ BEGIN_NEW_CURRENT(XQ_START_TAG_ATTRLIST); TOKBOX_Q (0, XQCNAME, "Name of opening XML tag") }
<XQ_START_TAG_ATTRLIST>"xmlns"			TOK (XMLNS)
<XQ_START_TAG_ATTRLIST>{XML_RESERVED}		TOKBOX_Q (0, XQNAMERESERVED, "Name of reserved XML attribute in opening tag")
<XQ_START_TAG_ATTRLIST>{XMLNS_QNAME}		TOKBOX_Q (0, XQCNAME, "Name of XML attribute in opening tag")

	/* XQ ELEMENT_CONTENT */
<XQ_ELEMENT_CONTENT>"</"			{ BEGIN_NEW_CURRENT(XQ_END_TAG); return _LT_SLASH; }
<XQ_ELEMENT_CONTENT>"{"				TOKPAR_OPEN ('{', '}', XQ)
<XQ_ELEMENT_CONTENT>"<"				TOKPAR_OPEN (_LT_OF_TAG, '>', XQ_START_TAG)
<XQ_ELEMENT_CONTENT>{S_NL}			{ xpp->xpp_lexlineno++; xpyylval.box = box_dv_short_string("\n"); return XQ_ECSTRING; }
<XQ_ELEMENT_CONTENT>[^\r\n{}<&]+		{ xpyylval.box = box_dv_short_string(xpyytext); return XQ_ECSTRING; }
<XQ_ELEMENT_CONTENT>"}"				{ xpyyerror ("Unbalanced '}' in element content"); }
<XQ_ELEMENT_CONTENT>"{{"			{ xpyylval.box = box_dv_short_string("{"); return XQ_ECSTRING; }
<XQ_ELEMENT_CONTENT>"}}"			{ xpyylval.box = box_dv_short_string("}"); return XQ_ECSTRING; }
<XQ_ELEMENT_CONTENT>"&"([a-zA-Z0-9#]+)";"	{ xpyylval.box = xp_charref_to_strliteral(xpp, xpyytext); return XQ_ECSTRING; }
<XQ_ELEMENT_CONTENT>"&"				{ xpyylval.box = box_dv_short_string("&"); return XQ_ECSTRING; }

	/* XQ END_TAG */
<XQ_END_TAG>">"					TOKPAR_CLOSE (_GT_OF_TAG, '>')
<XQ_END_TAG>"{"					TOKPAR_OPEN ('{', '}', XQ)
<XQ_END_TAG>{XMLNS_QNAME}			TOKBOX_Q (0, XQCNAME, "Name of closing XML tag")

	/* XQ XML_COMMENT */
<XQ_XML_COMMENT>{S_NL}				{ xpp->xpp_lexlineno++; yymore(); }
<XQ_XML_COMMENT>"-->"				{ xpyylval.box = box_dv_short_nchars (xpyytext, xpyyleng - 3); TOKPAR_CLOSE(XQ_XML_COMMENT_STRING,'-') }
<XQ_XML_COMMENT>(([^\-\r\n]+)|"-")		{ yymore(); }
<XQ_XML_COMMENT><<EOF>>				{ xpyyerror ("Unterminated <!-- comment"); }

	/* XQ EXPR_COMMENT */
<XQ_EXPR_COMMENT>{S_NL}				{ xpp->xpp_lexlineno++; }
<XQ_EXPR_COMMENT>(([^\:()\r\n]+)|":"|")"|"(")  { /* no op */; }
<XQ_EXPR_COMMENT>":)"				{ TOKPAR_FAKE_CLOSE(':') }
<XQ_EXPR_COMMENT><<EOF>>			{ xpyyerror ("Unterminated (: comment"); }

	/* XQ EXT_KEY */
<XQ_EXT_KEY>"pragma"				{ if (xpp->xpp_save_pragmas) return PRAGMA_L;  }
<XQ_EXT_KEY>"extension"				{ if (xpp->xpp_save_pragmas) return EXTENSION_L; }
<XQ_EXT_KEY>{XMLNS_QNAME}			{ BEGIN_NEW_CURRENT(XQ_EXT_CONTENT); if (xpp->xpp_save_pragmas) { TOKBOX_Q(0, XQCNAME, "Name of expression extension") } }

	/* XQ EXT_CONTENT (Missing in W3C) */
<XQ_EXT_CONTENT>{S_NL}				{ xpp->xpp_lexlineno++; if (xpp->xpp_save_pragmas) yymore(); }
<XQ_EXT_CONTENT>([^\:()\r\n]+|":"|")"|"(")	{ if (xpp->xpp_save_pragmas) yymore(); }
<XQ_EXT_CONTENT>"::)"				{ if (xpp->xpp_save_pragmas) { xpyylval.box = box_dv_short_nchars(xpyytext, xpyyleng - 3); TOKPAR_CLOSE(XQ_STRG_EXT_CONTENT,'#') } else { TOKPAR_FAKE_CLOSE('#') } }
<XQ_EXT_CONTENT><<EOF>>				{ xpyyerror ("Unterminated (:: expression extension"); }

	/* XQ PROCESSING_INSTRUCTION */
<XQ_PI>{XMLNS_NCNAME}				{ BEGIN_NEW_CURRENT(XQ_PI_CONTENT_GAP); TOKBOX_L(0, XQNCNAME, "Name of processing instruction") }

	/* XQ PROCESSING_INSTRUCTION_CONTENT */
<XQ_PI_CONTENT_GAP>{S_NL}			{ xpp->xpp_lexlineno++; }
<XQ_PI_CONTENT>{S_NL}				{ xpp->xpp_lexlineno++; yymore(); }
<XQ_PI_CONTENT_GAP>{WS}				{ /* no op*/; }
<XQ_PI_CONTENT_GAP>[^ \t\r\n]			{ BEGIN_NEW_CURRENT(XQ_PI_CONTENT); yymore(); }
<XQ_PI_CONTENT>([^?\r\n]+|"?")			{ yymore(); }
<XQ_PI_CONTENT,XQ_PI_CONTENT_GAP>"?>"		{ xpyylval.box = box_dv_short_nchars (xpyytext, xpyyleng - 2); TOKPAR_CLOSE(XQ_STRG_QMARK_GT,'?') }
<XQ_PI_CONTENT,XQ_PI_CONTENT_GAP><<EOF>>	{ xpyyerror ("Unterminated <? processing instruction"); }

	/* XQ CDATA_SECTION */
<XQ_CDATA_SECTION>{S_NL}			{ xpp->xpp_lexlineno++; yymore(); }
<XQ_CDATA_SECTION>"]]>"				{ xpyylval.box = box_dv_short_nchars (xpyytext, xpyyleng - 3); TOKPAR_CLOSE(CDATA_SECTION,'C') }
<XQ_CDATA_SECTION>([^\]\r\n]+|"]")		{ yymore(); }
<XQ_CDATA_SECTION><<EOF>>			{ xpyyerror ("Unterminated <![CDATA[ section"); }

<XQ>{XP_EXEC_SQL_XPATH}	    {
      if (2 <= xpp->xpp_total_lexems_parsed)
	{
	  TOK(EXEC_SQL_XPATH)
	}
    }
	/* PLAIN LITERAL CHAINS */

<XQ,XQ_OP>":"			TOK (_COLON)
<XQ,XQ_OP>"::"			TOK (_COLON_COLON)
<PARAMLIST>"="			TOK (_EQ)
<PARAMLIST>"."			TOK (_DOT)
<PARAMLIST>".."			TOK (_DOT_DOT)

<FT>{A}{N}{D}				TOK (K_AND)
<FT>{N}{E}{A}{R}			TOK (K_NEAR)
<FT>{N}{O}{T}				TOK (K_NOT)
<FT>{O}{R}				TOK (K_OR)

<PARAMLIST>"__base_uri"		TOK (O_BASE_URI)
<PARAMLIST>"__davprop"		TOK (O_DAVPROP)
<PARAMLIST>"__doc"	 	TOK (O_DOC)
<PARAMLIST>"__enc"	 	TOK (O_ENC)
<PARAMLIST>"__http"		TOK (O_HTTP)
<PARAMLIST>"__key"	 	TOK (O_KEY)
<PARAMLIST>"__lang"		TOK (O_LANG)
<PARAMLIST>"__quiet"		TOK (O_QUIET)
<PARAMLIST>"__sax"	 	TOK (O_SAX)
<PARAMLIST>"__shallow"		TOK (O_SHALLOW)
<PARAMLIST>"__tag"		TOK (O_TAG)
<PARAMLIST>"__view"		TOK (O_VIEW)
<PARAMLIST>"__*"		TOK (O__STAR)
<PARAMLIST>"]"			TOKPAR_CLOSE (']',']')
<PARAMLIST>"]"({WS}?)"["	TOK (_RSQBRA_LSQBRA)

<XQ,PARAMLIST>"xmlns"			TOK (XMLNS)

<PARAMLIST>{XML_RESERVED}	{ TOKBOX_Q (0, XQNAMERESERVED, "Reserved XML name"); }
<PARAMLIST>{XMLNS_NCNAME}	{ TOKBOX_Q (0, XQNCNAME, "Parameter name"); }
<PARAMLIST>{XMLNS_QNAME}	{ TOKBOX_Q (0, XQCNAME, "Parameter Qname"); }


<FT>[,@;|^]			TOK (xpyytext[0])
<FT>"(["			{ TOKPAR_FAKE_OPEN(')', GET_CURRENT_BEGIN); TOKPAR_OPEN (_LPAR_LSQBRA, ']', PARAMLIST) }
<FT>"("				TOKPAR_OPEN ('(',')', GET_CURRENT_BEGIN)
<FT>")"				TOKPAR_CLOSE (')',')')
<FT>"["		{
	  if (2 > xpp->xpp_total_lexems_parsed)
	    {
	      TOKPAR_OPEN ('[', ']', PARAMLIST)
	    }
	  else
	    {
	      TOKPAR_OPEN ('[',']', FT)
	    }
	}

	/* NAMES & VARIABLES */

<FT>[A-Za-z_][A-Za-z0-9_-]*			TOKBOX_L (0, SINGLE_WORD, "Word")

	/* NUMBERS */
<PARAMLIST>{INTEGER_LITERAL}			{ return xpscn_NUMBER_int (yylval, xpp); }
<PARAMLIST>{DECIMAL_LITERAL}			{ return xpscn_NUMBER_decimal (yylval, xpp); }
<PARAMLIST>{DOUBLE_LITERAL}			{ return xpscn_NUMBER_double (yylval, xpp); }

	/* STRINGS */

<FT>[""][^""\n]*[""]				{
  xpyytext[xpyyleng - 1] = 0;
  xpyylval.box = box_dv_short_string (xpyytext+1);
  xpyytext[xpyyleng - 1] = '\"';	/* ... to have correct list of lexems */
  return XQDQ_NDQSTRING_DQ;
  }

<FT,PARAMLIST>['']	{ yymore(); SET_INNER_BEGIN(FT_SQ); BEGIN_INNER; }
<FT,PARAMLIST>[""]	{ yymore(); SET_INNER_BEGIN(FT_DQ); BEGIN_INNER; }

<XQ_SQ>['']		{ xpyylval.box = xp_strliteral (xpp, xpyytext, '\'', 0); BEGIN_OUTER; return xpp->xpp_string_literal_lexval; }
<XQ_DQ>[""]		{ xpyylval.box = xp_strliteral (xpp, xpyytext, '\"', 0); BEGIN_OUTER; return xpp->xpp_string_literal_lexval; }
<XQ_SQ_ATTR>['']	{ xpyylval.box = xp_strliteral (xpp, xpyytext, '\'', 1); BEGIN_OUTER; return XQSQ_NSQSTRING_SQ; }
<XQ_DQ_ATTR>[""]	{ xpyylval.box = xp_strliteral (xpp, xpyytext, '\"', 1); BEGIN_OUTER; return XQDQ_NDQSTRING_DQ; }
<XQ_SQ_ATTR_CONT>['']	{ xpyylval.box = xp_strliteral (xpp, xpyytext, '\'', 1); BEGIN_OUTER; return RBRA_NSQSTRING_SQ; }
<XQ_DQ_ATTR_CONT>[""]	{ xpyylval.box = xp_strliteral (xpp, xpyytext, '\"', 1); BEGIN_OUTER; return RBRA_NDQSTRING_DQ; }
<FT_SQ>['']		{ xpyylval.box = xp_strliteral (xpp, xpyytext, '\'', 0); BEGIN_OUTER; return XQSQ_NSQSTRING_SQ; }
<FT_DQ>[""]		{ xpyylval.box = xp_strliteral (xpp, xpyytext, '\"', 0); BEGIN_OUTER; return XQDQ_NDQSTRING_DQ; }

<XQ_SQ,XQ_DQ,XQ_SQ_ATTR,XQ_DQ_ATTR,XQ_SQ_ATTR_CONT,XQ_DQ_ATTR_CONT,FT_SQ,FT_DQ>{S_NL}	{ xpp->xpp_lexlineno++; yymore(); }
<XQ_SQ,XQ_DQ,XQ_SQ_ATTR,XQ_DQ_ATTR,XQ_SQ_ATTR_CONT,XQ_DQ_ATTR_CONT,FT_SQ,FT_DQ>{S_BSNL}	{ xpp->xpp_lexlineno++; yymore(); }
<XQ_SQ,XQ_SQ_ATTR,XQ_SQ_ATTR_CONT,FT_SQ>(({SQ_PLAIN}|{S_BS})+)		{ yymore(); }
<XQ_DQ,XQ_DQ_ATTR,XQ_DQ_ATTR_CONT,FT_DQ>(({DQ_PLAIN}|{S_BS})+)		{ yymore(); }

<XQ_SQ_ATTR>"{"			{ xpyylval.box = xp_strliteral (xpp, xpyytext, '\'', 1); SET_CURRENT_BEGIN(XQ_SQ_ATTR_CONT); TOKPAR_FAKE_OPEN('}',XQ); return XQSQ_NSQSTRING_LBRA; }
<XQ_DQ_ATTR>"{"			{ xpyylval.box = xp_strliteral (xpp, xpyytext, '\"', 1); SET_CURRENT_BEGIN(XQ_DQ_ATTR_CONT); TOKPAR_FAKE_OPEN('}',XQ); return XQDQ_NDQSTRING_LBRA; }
<XQ_SQ_ATTR_CONT>"{"		{ xpyylval.box = xp_strliteral (xpp, xpyytext, '\'', 1); TOKPAR_FAKE_OPEN('}',XQ); return RBRA_NSQSTRING_LBRA; }
<XQ_DQ_ATTR_CONT>"{"		{ xpyylval.box = xp_strliteral (xpp, xpyytext, '\"', 1); TOKPAR_FAKE_OPEN('}',XQ); return RBRA_NDQSTRING_LBRA; }

<XQ_SQ_ATTR>"}"		{ xpyyerror ("Unbalanced '}' in single-quoted string"); yymore(); }
<XQ_DQ_ATTR>"}"		{ xpyyerror ("Unbalanced '}' in double-quoted string"); yymore(); }
<XQ_SQ_ATTR_CONT>"}"	{ xpyyerror ("Unbalanced '}' in single-quoted string, after embedded expression"); yymore(); }
<XQ_DQ_ATTR_CONT>"}"	{ xpyyerror ("Unbalanced '}' in double-quoted string, after embedded expression"); yymore(); }

<XQ_SQ_ATTR,XQ_DQ_ATTR,XQ_SQ_ATTR_CONT,XQ_DQ_ATTR_CONT>("{{"|"}}")	{ yymore(); }
<XQ_SQ,XQ_DQ,FT_SQ,FT_DQ>("{"|"}")				{ yymore(); }

	/* WHITESPACES */
<XQ,XQ_OP,XQ_NAMESPACE_DECL,XQ_NAMESPACE_KWD,XQ_ITEM_TYPE,XQ_KT,XQ_KT_OI,XQ_KT_FOR_PI,XQ_CLOSE_KT,XQ_CLOSE_KT_OI,XQ_SCS,XQ_SCS_OI,XQ_VAR_NAME,XQ_START_TAG,XQ_START_TAG_ATTRLIST,XQ_END_TAG,XQ_EXT_KEY,XQ_PI,FT,PARAMLIST>{S_NL}	{ xpp->xpp_lexlineno++; }
<XQ,XQ_OP,XQ_NAMESPACE_DECL,XQ_NAMESPACE_KWD,XQ_ITEM_TYPE,XQ_KT,XQ_KT_OI,XQ_KT_FOR_PI,XQ_CLOSE_KT,XQ_CLOSE_KT_OI,XQ_SCS,XQ_SCS_OI,XQ_VAR_NAME,XQ_START_TAG,XQ_START_TAG_ATTRLIST,XQ_END_TAG,XQ_EXT_KEY,XQ_PI,FT,PARAMLIST>{WS}	;
	/* <XQ>"#".*		; */
	/* <XQ>"--".*		; */

<FT>.			{ xpyyerror ("Invalid character in free-text search expression, it may not appear outside quoted string"); }
<XQ,XQ_OP,XQ_NAMESPACE_DECL,XQ_NAMESPACE_KWD,XQ_ITEM_TYPE,XQ_KT,XQ_KT_OI,XQ_KT_FOR_PI,XQ_CLOSE_KT,XQ_CLOSE_KT_OI,XQ_SCS,XQ_SCS_OI,XQ_VAR_NAME,XQ_START_TAG,XQ_START_TAG_ATTRLIST,XQ_END_TAG,XQ_EXT_KEY,XQ_PI,PARAMLIST>.		{ xpyyerror ("Invalid character"); }
<XQ,XQ_OP,XQ_NAMESPACE_DECL,XQ_NAMESPACE_KWD,XQ_ITEM_TYPE,XQ_KT,XQ_KT_OI,XQ_KT_FOR_PI,XQ_CLOSE_KT,XQ_CLOSE_KT_OI,XQ_SCS,XQ_SCS_OI,XQ_VAR_NAME,XQ_START_TAG,XQ_START_TAG_ATTRLIST,XQ_END_TAG,XQ_EXT_KEY,XQ_PI,PARAMLIST>{XMLNS_QQNAME} { TOKBOX_Q (0, XQQQNAME, "Nonstandard XML name"); }



<XQ_SQ><<EOF>>				{ xpyyerror ("Unterminated single-quoted string"); }
<XQ_DQ><<EOF>>				{ xpyyerror ("Unterminated double-quoted string"); }
<XQ_SQ_ATTR,XQ_SQ_ATTR_CONT><<EOF>>	{ xpyyerror ("Unterminated single-quoted attribute value"); }
<XQ_DQ_ATTR,XQ_DQ_ATTR_CONT><<EOF>>	{ xpyyerror ("Unterminated double-quoted attribute value"); }

<FT_SQ><<EOF>>				{ xpyyerror ("Unterminated single-quoted word or phrase"); }
<FT_DQ><<EOF>>				{ xpyyerror ("Unterminated double-quoted word or phrase"); }
<PARAMLIST><<EOF>>			{ xpyyerror ("Unterminated list of configuration parameters"); }

%%


dk_mutex_t *xp_lex_mtx = NULL;

#define XP_LEXBUF_ELEMENTS 32
void
xp_fill_lexem_bufs (xpp_t *xpp)
{
  if (!xp_lex_mtx)
    xp_lex_mtx = mutex_allocate ();
  mutex_enter (xp_lex_mtx);
  xpp->xpp_text_len = box_length(xpp->xpp_text)-1;
  xp_lex_env = xpp;
  if (0 == setjmp (xpp->xpp_reset))
    {
      int depth = 0;
      int fill_ctr = 0;
      xp_lexem_t *curr_lex;
#ifdef XPYYDEBUG
	xpp->xpp_yydebug = 1;
#endif
      xpp->xpp_lexlineno = 1;
      xpp->xpp_lexdepth = 0;
      xpyyrestart (NULL);
      xpp->xpp_curr_lexem_buf = (xp_lexem_t *)dk_alloc_box_zero (sizeof (xp_lexem_t) * XP_LEXBUF_ELEMENTS, DV_ARRAY_OF_POINTER);
/* Setting initial state and placing appropriate fake lexem to the lexbuffer */
      curr_lex = xpp->xpp_curr_lexem_buf + fill_ctr;
      curr_lex->xpl_lineno = xpp->xpp_lexlineno;
      curr_lex->xpl_depth = depth;
      curr_lex->xpl_raw_text = box_dv_short_string("");
      switch (xpp->xpp_expn_type)
        {
          case 'p':
	    BEGIN_NEW_CURRENT(XQ);
	    curr_lex->xpl_lex_value = START_OF_XP_TEXT;
	    break;
	  case 'q':
	    BEGIN_NEW_CURRENT(XQ);
	    curr_lex->xpl_lex_value = START_OF_XQ_TEXT;
	    break;
	  case 't':
	    BEGIN_NEW_CURRENT(FT);
	    curr_lex->xpl_lex_value = START_OF_FT_TEXT;
	    break;
	  default: GPF_T;
	}
      xpp->xpp_total_lexems_parsed++;
      fill_ctr++;
/* Loop over text */
      for (;;)
        {
	  curr_lex = xpp->xpp_curr_lexem_buf + fill_ctr;
	  curr_lex->xpl_lex_value = xpyylex(&(curr_lex->xpl_sem_value), xpp);
	  curr_lex->xpl_lineno = xpp->xpp_lexlineno;
	  curr_lex->xpl_depth = depth;
	  if (0 == curr_lex->xpl_lex_value)
	    {
	      curr_lex->xpl_lex_value = END_OF_XPSCN_TEXT;
	      break;
	    }
	  depth = xpp->xpp_lexdepth;
	  curr_lex->xpl_raw_text = box_dv_short_nchars (xpyytext, xpyyleng);
#ifdef XPATHP_DEBUG
	  curr_lex->xpl_state = GET_CURRENT_BEGIN;
#endif
	  fill_ctr++;
          xpp->xpp_total_lexems_parsed++;
	  if (fill_ctr == XP_LEXBUF_ELEMENTS)
	    {
	      dk_set_push (&(xpp->xpp_output_lexem_bufs), xpp->xpp_curr_lexem_buf);
	      xpp->xpp_curr_lexem_buf = (xp_lexem_t *)dk_alloc_box_zero (sizeof (xp_lexem_t) * XP_LEXBUF_ELEMENTS, DV_ARRAY_OF_POINTER);
	      fill_ctr = 0;
	    }
	}
    }
  xp_lex_env = NULL;
  mutex_leave (xp_lex_mtx);
  dk_set_push (&(xpp->xpp_output_lexem_bufs), xpp->xpp_curr_lexem_buf);
  xpp->xpp_curr_lexem_buf = NULL;
  xpp->xpp_curr_lexem_bmk.xplb_lexem_bufs_tail = xpp->xpp_output_lexem_bufs = dk_set_nreverse (xpp->xpp_output_lexem_bufs);
  xpp->xpp_lexem_buf_len = box_length (xpp->xpp_curr_lexem_bmk.xplb_lexem_bufs_tail->data) / sizeof (xp_lexem_t);
}


int
xpyywrap (void)
{
  return (1);
}

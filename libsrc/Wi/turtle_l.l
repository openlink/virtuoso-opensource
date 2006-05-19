%{
/* 
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

#include "Dk.h"
#include "xmltree.h"
#include "rdf_core.h"
#include "turtle_p.h"
#ifdef __BORLANDC__ /* Rogue Wave STL contains numeric.h */
#include "G:\libsrc\Wi\numeric.h"
#else
#include "numeric.h"
#endif

#define ttlyyerror(strg) ttlyyerror_impl(TTLP_ARG ttlyytext, (strg))

#define ttlyylval (((YYSTYPE *)(yylval))[0])

#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
  do \
    { \
      int rest_len = ttlp_inst.ttlp_text_len - ttlp_inst.ttlp_text_ofs; \
      int get_len = (max_size); \
      dk_session_t *ses; \
      if (rest_len > 0) \
        { \
          if (get_len > rest_len) \
            get_len = rest_len; \
          memcpy ((buf), (ttlp_inst.ttlp_text + ttlp_inst.ttlp_text_ofs), get_len); \
          (result) = get_len; \
          ttlp_inst.ttlp_text_ofs += get_len; \
          break; \
        } \
      ses = ttlp_inst.ttlp_input; \
      if (NULL != ses) \
        { \
          CATCH_READ_FAIL (ses) \
            { \
              (result) = session_buffered_read (ses, (buf), (max_size)); \
            } \
          FAILED \
            { \
              (result) = 0; \
              ttlp_inst.ttlp_input = NULL; \
            } \
          END_READ_FAIL (ses); \
          break; \
        } \
      (result) = 0; \
    } while (0);

int ttl_yy_null = YY_NULL;

static void ttlyyerror_if_long_qname (TTLP_PARAM caddr_t box, const char *lex_type_descr)
{
  size_t boxlen = box_length (box);
  char buf[100];
  char *colon;
  if (boxlen > MAX_XML_QNAME_LENGTH)
    {
      snprintf (buf, sizeof (buf), "%.90s is too long", lex_type_descr);
      ttlyyerror (buf);
    }
  colon = strrchr (box, ':');
  if (NULL == colon)
    {
      if (boxlen > MAX_XML_LNAME_LENGTH)
	{
	  snprintf (buf, sizeof (buf), "%.90s is too long", lex_type_descr);
	  ttlyyerror (buf);
	}
      return;
    }
  if (colon+1-box > MAX_XML_LNAME_LENGTH)
    {
      snprintf (buf, sizeof (buf), "%.90s contains abnormally long namespace prefix", lex_type_descr);
      ttlyyerror (buf);
    }
  if (boxlen-(colon-box) > MAX_XML_LNAME_LENGTH)
    {
      snprintf (buf, sizeof (buf), "%.90s contains abnormally long 'local part' after the colon", lex_type_descr);
      ttlyyerror (buf);
    }
}


#define TTL_TOKBOX_Q_FINAL(name,lex_type_descr) \
    if (box_length (ttlyylval.box) > MAX_XML_LNAME_LENGTH) \
      ttlyyerror_if_long_qname (TTLP_ARG ttlyylval.box, lex_type_descr); \
    return (name);

#define TTL_TOKBOX_Q(n,name,lex_type_descr) { \
    ttlyylval.box = box_dv_short_string (ttlyytext+(n)); \
    TTL_TOKBOX_Q_FINAL(name,lex_type_descr) }

static int ttlp_NUMBER_int (TTLP_PARAM void *yylval)
{
  if (strlen (ttlyytext) < 10)
    {
      ttlyylval.box = box_num_nonull (atol (ttlyytext));
      return TURTLE_INTEGER;
    }
  else
    {
      numeric_t num = numeric_allocate ();
      int rc = numeric_from_string (num, ttlyytext);
      ttlyylval.box = (caddr_t) num;
      if (NULL == ttlyylval.box)
	ttlyylval.box = box_num_nonull (0);
      if(rc != NUMERIC_STS_SUCCESS)
	ttlyyerror ("The absolute value of numeric constant is too large");
      return TURTLE_INTEGER;
    }
}


static int ttlp_NUMBER_decimal (TTLP_PARAM void *yylval)
{
  numeric_t num = numeric_allocate ();
  int rc = numeric_from_string (num, ttlyytext);
  if (NUMERIC_STS_SUCCESS == rc)
    {
      ttlyylval.box = (caddr_t) num;
      if (NULL == ttlyylval.box)
	ttlyylval.box = box_num_nonull (0);
      return TURTLE_DECIMAL;
    }
  numeric_free (num);
  ttlyylval.box = box_double (atof (ttlyytext));
  return TURTLE_DECIMAL;
}

static int ttlp_NUMBER_double (TTLP_PARAM void *yylval)
{
  ttlyylval.box = box_double (atof (ttlyytext));
  return TURTLE_DOUBLE;
}


%}

	/* Top-level INITIAL state */
/*%x INITIAL*/

	/* Internals of single-quoted INITIAL string lit */
%x TURTLE_SQ

	/* Internals of double-quoted INITIAL string lit */
%x TURTLE_DQ

	/* Internals of triple-single-quoted INITIAL string lit */
%x TURTLE_SSSQ

	/* Internals of triple-double-quoted INITIAL string lit */
%x TURTLE_DDDQ

	/* Special unreacheable state to fill the first item of ttlp_inst.ttlp_lexstates */
%x UNREACHEABLE

XMLNS_NCNAME	([A-Za-z_][A-Za-z0-9_.-]*)
XMLNS_QNAME1	(({XMLNS_NCNAME}":")?{XMLNS_NCNAME})
XMLNS_QNAME	({XMLNS_QNAME1}|("(!"[A-Za-z0-9:_./%#+-]+"!)"))
XMLNS_QQNAME	({XMLNS_NCNAME}":"({XMLNS_NCNAME}":")+{XMLNS_NCNAME})
XML_RESERVED	({X}{M}{L}([A-Za-z0-9_.-]*)":"{XMLNS_NCNAME})

INTEGER_LITERAL ([0-9]+)
DECIMAL_LITERAL (([0-9]+"."[0-9]*)|("."[0-9]+))
DOUBLE_LITERAL	(({INTEGER_LITERAL}|{DECIMAL_LITERAL})[eE][+-]?[0-9]+)

SPAR_SQ_PLAIN	([^\\''\r\n])
SPAR_DQ_PLAIN	([^\\""\r\n])
SPAR_ECHAR	([\\]([atbvnrf\\""'']|("u"{HEX}{HEX}{HEX}{HEX})|("U"{HEX}{HEX}{HEX}{HEX}{HEX}{HEX}{HEX}{HEX})))
S_NL		((\r\n)|(\n\r)|\n|\r)
HEX		([0-9A-Fa-f])

 /*
  SPAR_NCCHAR1p	([A-Za-z\200-\377])
  SPAR_NCCHAR1	({SPAR_NCCHAR1p}|[_])
  SPAR_VARNAME	(({SPAR_NCCHAR1}|[0-9])+)
  SPAR_NCCHAR	({SPAR_NCCHAR1}|[0-9-])
  SPAR_NCNAME_PREFIX	({SPAR_NCCHAR1p}(({SPAR_NCCHAR}|[.])*{SPAR_NCCHAR})?)
  SPAR_NCNAME		({SPAR_NCCHAR1}(({SPAR_NCCHAR}|[.])*{SPAR_NCCHAR})?)
  */

SPAR_NCCHAR1p	([A-Za-z])
SPAR_NCCHAR1	([A-Za-z_])
SPAR_VARNAME	([A-Za-z0-9_]+)
SPAR_NCCHAR	([A-Za-z0-9_-])
SPAR_NCNAME_PREFIX	({SPAR_NCCHAR1p}([A-Za-z0-9_.-]*{SPAR_NCCHAR})?)
SPAR_NCNAME		({SPAR_NCCHAR1}([A-Za-z0-9_.-]*{SPAR_NCCHAR})?)

%%

<INITIAL>"^"[ \t]	{ return _CARET_WS ; }
<INITIAL>"^"{S_NL}	{ ttlp_inst.ttlp_lexlineno++; return _CARET_WS ; }
<INITIAL>"^"		{ return _CARET_NOWS	; }
<INITIAL>"^^"		{ return _CARET_CARET	; }
<INITIAL>","		{ return _COMMA; }
<INITIAL>"."[ \t]	{ return _DOT_WS; }
<INITIAL>"."{S_NL}	{ ttlp_inst.ttlp_lexlineno++; return _DOT_WS; }
<INITIAL>"."		{ return _DOT_NOWS; }
<INITIAL>":"		{ return _COLON; }
<INITIAL>";"		{ return _SEMI; }

<INITIAL>"@a"				{ return a_L; }
<INITIAL>"@is"				{ return is_L; }
<INITIAL>"@of"				{ return of_L; }
<INITIAL>"@this"				{ return this_L; }
<INITIAL>"@keywords"			{ return keywords_L; }
<INITIAL>"@prefix"			{ return prefix_L; }
<INITIAL>"false"				{ return false_L; }
<INITIAL>"true"				{ return true_L; }

<INITIAL>"a"				{ /*TBF if*/ return a_L; }
<INITIAL>"is"				{ /*TBF if*/ return is_L; }
<INITIAL>"of"				{ /*TBF if*/ return of_L; }
<INITIAL>"this"				{ /*TBF if*/ return this_L; }


<INITIAL>"("				{ ttlp_inst.ttlp_lexdepth++; return _LPAR; }
<INITIAL>")"				{ ttlp_inst.ttlp_lexdepth--; return _RPAR; }
<INITIAL>"["				{ ttlp_inst.ttlp_lexdepth++; return _LSQBRA; }
<INITIAL>"[]"				{ return _LSQBRA_RSQBRA; }
<INITIAL>"]"				{ ttlp_inst.ttlp_lexdepth--; return _RSQBRA; }

<INITIAL>"<"([^\\>`\001-\040])*">"	{
    ttlyylval.box = box_dv_short_nchars (ttlyytext + 1, ttlyyleng - 2);
    return Q_IRI_REF;
  }

<INITIAL>"<"(([^\\>`\001-\040])|{SPAR_ECHAR})*">"	{
    ttlyylval.box = ttlp_strliteral (TTLP_ARG ttlyytext, 1, '>');  
    return Q_IRI_REF;
  }

<INITIAL>({SPAR_NCNAME_PREFIX}?)":"{SPAR_NCNAME}	{ TTL_TOKBOX_Q(0,QNAME,"qualified URI"); }
<INITIAL>({SPAR_NCNAME_PREFIX}?)":"		{ TTL_TOKBOX_Q(0,QNAME_NS,"namespace"); }
<INITIAL>{SPAR_NCNAME}				{ TTL_TOKBOX_Q(0,QNAME,"name without prefix"); }
<INITIAL>"_:"{SPAR_NCNAME}			{ TTL_TOKBOX_Q(0,BLANK_NODE_LABEL,"blank node label"); }

<INITIAL>"@"([a-zA-Z]+)(("-"([a-zA-Z0-9]+))*)	{
    ttlyylval.box = box_dv_short_nchars (ttlyytext + 1, ttlyyleng - 1);
    return LANGTAG;
  }

<INITIAL>([""][^""\\\n]*[""])|([''][^''\\\n]*['']) {
    ttlyylval.box = box_dv_short_nchars (ttlyytext+1, ttlyyleng - 2);
    return TURTLE_STRING;
  }

<INITIAL>['']['']['']		{ yymore(); BEGIN TURTLE_SSSQ; }
<INITIAL>[""][""][""]		{ yymore(); BEGIN TURTLE_DDDQ; }
<TURTLE_SSSQ>['']['']['']	{ ttlyylval.box = ttlp_strliteral (TTLP_ARG ttlyytext, 1, '\''); BEGIN INITIAL; return TURTLE_STRING; }
<TURTLE_DDDQ>[""][""][""]	{ ttlyylval.box = ttlp_strliteral (TTLP_ARG ttlyytext, 1, '\"'); BEGIN INITIAL; return TURTLE_STRING; }
<TURTLE_SSSQ>(([''](['']?))?{S_NL})		{ ttlp_inst.ttlp_lexlineno++; yymore(); }
<TURTLE_DDDQ>(([""]([""]?))?{S_NL})		{ ttlp_inst.ttlp_lexlineno++; yymore(); }
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
<TURTLE_SQ>['']		{ ttlyylval.box = ttlp_strliteral (TTLP_ARG ttlyytext, 0, '\''); BEGIN INITIAL; return TURTLE_STRING; }
<TURTLE_DQ>[""]		{ ttlyylval.box = ttlp_strliteral (TTLP_ARG ttlyytext, 0, '\"'); BEGIN INITIAL; return TURTLE_STRING; }
<TURTLE_SQ>{S_NL}	{ ttlyyerror ("End-of-line in a short single-quoted string"); yymore(); }
<TURTLE_DQ>{S_NL}	{ ttlyyerror ("End-of-line in a short double-quoted string"); yymore(); }
<TURTLE_SQ>(({SPAR_SQ_PLAIN}|{SPAR_ECHAR})+)		{ yymore(); }
<TURTLE_DQ>(({SPAR_DQ_PLAIN}|{SPAR_ECHAR})+)		{ yymore(); }
<TURTLE_SQ>[\\]		{ ttlyyerror ("Bad escape sequence in a short single-quoted string"); }
<TURTLE_DQ>[\\]		{ ttlyyerror ("Bad escape sequence in a short double-quoted string"); }
<TURTLE_SQ><<EOF>>		{ ttlyyerror ("Unterminated short single-quoted string"); }
<TURTLE_DQ><<EOF>>		{ ttlyyerror ("Unterminated short double-quoted string"); }

<INITIAL>[+-]?{INTEGER_LITERAL}		{ return ttlp_NUMBER_int (TTLP_ARG yylval); }
<INITIAL>[+-]?{DECIMAL_LITERAL}		{ return ttlp_NUMBER_decimal (TTLP_ARG yylval); }
<INITIAL>[+-]?{DOUBLE_LITERAL}		{ return ttlp_NUMBER_double (TTLP_ARG yylval); }

<INITIAL>("#"(.*))?{S_NL}		{ ttlp_inst.ttlp_lexlineno++; }
<INITIAL>"#"(.*)				{ }
<INITIAL>[ \t]+				{ }
<INITIAL>.		{ ttlyyerror ("Invalid character in INITIAL expression"); }

%%

caddr_t
ttl_query_lex_analyze (caddr_t str, wcharset_t *query_charset)
{
  dk_set_t lexems = NULL;
  caddr_t result_array;
  ttlp_t *ttlp;
  if (!DV_STRINGP(str))
    {
      return list (1, list (3, (ptrlong)0, (ptrlong)0, box_dv_short_string ("SPARQL analyzer: input text is not a string")));
    }
  if (!ttl_lex_mtx)
    ttl_lex_mtx = mutex_allocate ();
  mutex_enter (ttl_lex_mtx);
  ttlp = ttlp_alloc ();
  QR_RESET_CTX
    {
      ttlp->ttlp_text = str;
      ttlp->ttlp_text_len = strlen (str);
      ttlp->ttlp_err_hdr = "INITIAL analyzer";
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
      ttlyyrestart (NULL);
      /*BEGIN INITIAL;*/
      for (;;)
        {
          caddr_t lex_value = NULL;
          int lexem;
          lexem = ttlyylex (&lex_value);
          if (0 == lexem)
            break;
          dk_set_push (&lexems, list (4,
		box_num (ttlp->ttlp_lexlineno),
		ttlp->ttlp_lexdepth,
		box_copy (ttlp->ttlp_raw_text),
		lexem ) );
          dk_free_box (lex_value);
	}
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      ttlp->ttlp_catched_error = thr_get_error_code (self);
      thr_set_error_code (self, NULL);
      /*no POP_QR_RESET*/;
    }
  END_QR_RESET
  mutex_leave (ttl_lex_mtx);
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

int
ttlyywrap (void)
{
  return (1);
}

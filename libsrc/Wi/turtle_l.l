%option 8bit
%option case-sensitive
%option never-interactive
%option noyywrap
%option reentrant
%option bison-bridge
%option stack
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
#include "numeric.h"
#include "turtle_p.h"

#define YY_EXTRA_TYPE ttlp_t *

#define ttlyyerror(strg) ttlyyerror_impl(ttlp_arg, yytext, (strg))

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

extern void ttlyyerror_if_long_qname (ttlp_t *ttlp_arg, caddr_t box, const char *lex_type_descr, struct yyguts_t * yyg);

#define TTL_TOKBOX_Q_FINAL(name,lex_type_descr) \
    if (box_length (ttlyylval.box) > MAX_XML_LNAME_LENGTH) \
      ttlyyerror_if_long_qname (ttlp_arg, ttlyylval.box, lex_type_descr , yyg); \
    return (name);

#define TTL_TOKBOX_Q(n,name,lex_type_descr) { \
    ttlyylval.box = box_dv_short_string (yytext+(n)); \
    TTL_TOKBOX_Q_FINAL(name,lex_type_descr) }

#define TTL_SPECIAL_QNAME(bit,id) \
 if (!(ttlp_arg[0].ttlp_special_qnames & bit)) \
   return id; \
 ttlyylval.box = box_dv_short_string (yytext); \
 return QNAME;

extern int ttlp_NUMBER_int (YYSTYPE *yylval_param, ttlp_t *ttlp_arg, struct yyguts_t * yyg);
extern int ttlp_NUMBER_decimal (YYSTYPE *yylval_param, ttlp_t *ttlp_arg, struct yyguts_t * yyg);
extern int ttlp_NUMBER_double (YYSTYPE *yylval_param, ttlp_t *ttlp_arg, struct yyguts_t * yyg);

extern int ttlyylex (YYSTYPE *yylval_param, ttlp_t *ttlp_arg, yyscan_t yyscanner);
#define YY_DECL int ttlyylex (YYSTYPE *yylval_param, ttlp_t *ttlp_arg, yyscan_t yyscanner)

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

	/* State after '@' right after quoted string */
%x AT_AFTER_QUOTED

	/* Special unreacheable state to fill the first item of ttlp_arg[0].ttlp_lexstates */
%x UNREACHEABLE

INTEGER_LITERAL ([0-9]+)
DECIMAL_LITERAL (([0-9]+"."[0-9]*)|("."[0-9]+))
DOUBLE_LITERAL	(({INTEGER_LITERAL}|{DECIMAL_LITERAL})[eE][+-]?[0-9]+)

SPAR_SQ_PLAIN	([^\\''\r\n])
SPAR_DQ_PLAIN	([^\\""\r\n])
SPAR_ECHAR	([\\]([atbvnrf\\""'']|("u"{HEX}{HEX}{HEX}{HEX})|("U"{HEX}{HEX}{HEX}{HEX}{HEX}{HEX}{HEX}{HEX})))
S_NL		((\r\n)|(\n\r)|\n|\r)
HEX		([0-9A-Fa-f])

SPAR_NCCHAR1p	([A-Za-z\x7f-\xfe])
SPAR_NCCHAR1	([A-Za-z\x7f-\xfe_])
SPAR_VARNAME	([A-Za-z0-9\x7f-\xfe_]+)
SPAR_NCCHAR	([A-Za-z0-9_\x7f-\xfe-])
SPAR_NCNAME_PREFIX	({SPAR_NCCHAR1p}([A-Za-z0-9_.\x7f-\xfe-]*{SPAR_NCCHAR})?)
SPAR_NCNAME		({SPAR_NCCHAR1}([A-Za-z0-9_.\x7f-\xfe-]*{SPAR_NCCHAR})?)
SPAR_NCNAME_X		({SPAR_NCCHAR1}([A-Za-z0-9_./#\x7f-\xfe-]*{SPAR_NCCHAR})?)

%%

<INITIAL>"^"[ \t]	{ return _CARET_WS ; }
<INITIAL>"^"{S_NL}	{ ttlp_arg[0].ttlp_lexlineno++; return _CARET_WS ; }
<INITIAL>"^"		{ return _CARET_NOWS	; }
<INITIAL>"^^"		{ return _CARET_CARET	; }
<INITIAL>","		{ return _COMMA; }
<INITIAL>"."[ \t]	{ return _DOT_WS; }
<INITIAL>"."{S_NL}	{ ttlp_arg[0].ttlp_lexlineno++; return _DOT_WS; }
<INITIAL>"."[^0-9]	{ ttlyyerror ("Whitespace is required after dot if dot is not inside decimal number, string or IRI"); }
<INITIAL>"."		{ return _DOT_WS; }
<INITIAL>":"		{ return _COLON; }
<INITIAL>";"		{ return _SEMI; }
<INITIAL>"="		{ return _EQ; }
<INITIAL>"=>"		{ return _EQ_GT; }
<INITIAL>"<="		{ return _LT_EQ; }
<INITIAL>"!"		{ return _BANG; }

<INITIAL>"@a"				{ return _AT_a_L; }
<INITIAL>"@has"				{ return _AT_has_L; }
<INITIAL>"@is"				{ return _AT_is_L; }
<INITIAL>"@of"				{ return _AT_of_L; }
<INITIAL>"@this"			{ return _AT_this_L; }
<INITIAL>"@keywords"			{ return _AT_keywords_L; }
<INITIAL>"@prefix"			{ return _AT_prefix_L; }
<INITIAL>"@forAll"			{ ttlyyerror ("Current version of Virtuoso does not support @forAll keyword"); }
<INITIAL>"@forSome"			{ ttlyyerror ("Current version of Virtuoso does not support @forSome keyword"); }
<INITIAL>"false"				{ return false_L; }
<INITIAL>"true"				{ return true_L; }

<INITIAL>"a"				{ TTL_SPECIAL_QNAME (TTLP_ALLOW_QNAME_A, _AT_a_L) }
<INITIAL>"has"				{ TTL_SPECIAL_QNAME (TTLP_ALLOW_QNAME_HAS, _AT_has_L) }
<INITIAL>"is"				{ TTL_SPECIAL_QNAME (TTLP_ALLOW_QNAME_IS, _AT_is_L) }
<INITIAL>"of"				{ TTL_SPECIAL_QNAME (TTLP_ALLOW_QNAME_OF, _AT_of_L) }
<INITIAL>"this"				{ TTL_SPECIAL_QNAME (TTLP_ALLOW_QNAME_THIS, _AT_this_L) }


<INITIAL>"("				{ ttlp_arg[0].ttlp_lexdepth++; return _LPAR; }
<INITIAL>")"				{ ttlp_arg[0].ttlp_lexdepth--; return _RPAR; }
<INITIAL>"["				{ ttlp_arg[0].ttlp_lexdepth++; return _LSQBRA; }
<INITIAL>"[]"				{ return _LSQBRA_RSQBRA; }
<INITIAL>"]"				{ ttlp_arg[0].ttlp_lexdepth--; return _RSQBRA; }
<INITIAL>"{"				{ ttlp_arg[0].ttlp_lexdepth++; return _LBRA; }
<INITIAL>"}"				{ ttlp_arg[0].ttlp_lexdepth--; return _RBRA; }

<INITIAL>"<"([^\\>\001-\040])*">"	{
    ttlyylval.box = box_dv_short_nchars (yytext + 1, yyleng - 2);
    return Q_IRI_REF;
  }

<INITIAL>"<"(([^\\>\001-\040])|{SPAR_ECHAR})*">"	{
    ttlyylval.box = ttlp_strliteral (ttlp_arg, yytext, 0, '>');  
    return Q_IRI_REF;
  }

<INITIAL>({SPAR_NCNAME_PREFIX}?)":"{SPAR_NCNAME}	{ TTL_TOKBOX_Q(0,QNAME,"qualified URI"); }
<INITIAL>({SPAR_NCNAME_PREFIX}?)":"{SPAR_NCNAME_X}	{ 
    if (!(ttlp_arg[0].ttlp_flags & TTLP_NAME_MAY_CONTAIN_PATH))
      ttlyyerror ("Invalid characters in local part of QName; this error can be suppressed by parser flags");
    TTL_TOKBOX_Q(0,QNAME,"qualified URI"); }

<INITIAL>({SPAR_NCNAME_PREFIX}?)":"		{ TTL_TOKBOX_Q(0,QNAME_NS,"namespace"); }
<INITIAL>{SPAR_NCNAME}				{ TTL_TOKBOX_Q(0,QNAME,"name without prefix"); }
<INITIAL>"_:"{SPAR_NCNAME}			{ TTL_TOKBOX_Q(0,BLANK_NODE_LABEL,"blank node label"); }
<INITIAL>"?"{SPAR_NCNAME}	{
    if (!(ttlp_arg[0].ttlp_flags & TTLP_ACCEPT_VARIABLES))
      ttlyyerror ("Full N3 syntax allow variables, TURTLE does not; this error can be suppressed by parser flags");
    TTL_TOKBOX_Q(0,VARIABLE,"variable name"); }

<INITIAL>"@"([a-zA-Z]+)(("-"([a-zA-Z0-9]+))*)	{
    ttlyylval.box = box_dv_short_nchars (yytext + 1, yyleng - 1);
    return KEYWORD;
  }

<AT_AFTER_QUOTED>([a-zA-Z]+)(("-"([a-zA-Z0-9]+))*)	{
    ttlyylval.box = box_dv_short_nchars (yytext, yyleng);
    BEGIN INITIAL;
    return LANGTAG;
  }

<AT_AFTER_QUOTED>([a-zA-Z0-9-]+)	{ ttlyyerror ("The identifier after '@' at the end of quoted literal is not a valid language id"); }
<AT_AFTER_QUOTED><<EOF>>		{ ttlyyerror ("Missing language id after '@' at the end of quoted literal"); }
<AT_AFTER_QUOTED>.			{ ttlyyerror ("Bad character instead of language id after '@' at the end of quoted literal"); }


<INITIAL>([""][^""\\\n]*[""])|([''][^''\\\n]*['']) {
    ttlyylval.box = box_dv_short_nchars (yytext+1, yyleng - 2);
    return TURTLE_STRING;
  }

<INITIAL>(([""][^""\\\n]*[""])|([''][^''\\\n]*['']))"@" {
    ttlyylval.box = box_dv_short_nchars (yytext+1, yyleng - 3);
    BEGIN AT_AFTER_QUOTED;
    return TURTLE_STRING;
  }

<INITIAL>['']['']['']		{ yymore(); BEGIN TURTLE_SSSQ; }
<INITIAL>[""][""][""]		{ yymore(); BEGIN TURTLE_DDDQ; }
<TURTLE_SSSQ>['']['']['']	{ ttlyylval.box = ttlp_strliteral (ttlp_arg, yytext, TTLP_STRLITERAL_3QUOT, '\''); BEGIN INITIAL; return TURTLE_STRING; }
<TURTLE_DDDQ>[""][""][""]	{ ttlyylval.box = ttlp_strliteral (ttlp_arg, yytext, TTLP_STRLITERAL_3QUOT, '\"'); BEGIN INITIAL; return TURTLE_STRING; }
<TURTLE_SSSQ>['']['']['']"@"	{ ttlyylval.box = ttlp_strliteral (ttlp_arg, yytext, TTLP_STRLITERAL_3QUOT_AT, '\''); BEGIN AT_AFTER_QUOTED; return TURTLE_STRING; }
<TURTLE_DDDQ>[""][""][""]"@"	{ ttlyylval.box = ttlp_strliteral (ttlp_arg, yytext, TTLP_STRLITERAL_3QUOT_AT, '\"'); BEGIN AT_AFTER_QUOTED; return TURTLE_STRING; }
<TURTLE_SSSQ>(([''](['']?))?{S_NL})		{ ttlp_arg[0].ttlp_lexlineno++; yymore(); }
<TURTLE_DDDQ>(([""]([""]?))?{S_NL})		{ ttlp_arg[0].ttlp_lexlineno++; yymore(); }
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
<TURTLE_SQ>['']		{ ttlyylval.box = ttlp_strliteral (ttlp_arg, yytext, TTLP_STRLITERAL_QUOT, '\''); BEGIN INITIAL; return TURTLE_STRING; }
<TURTLE_DQ>[""]		{ ttlyylval.box = ttlp_strliteral (ttlp_arg, yytext, TTLP_STRLITERAL_QUOT, '\"'); BEGIN INITIAL; return TURTLE_STRING; }
<TURTLE_SQ>['']"@"	{ ttlyylval.box = ttlp_strliteral (ttlp_arg, yytext, TTLP_STRLITERAL_QUOT_AT, '\''); BEGIN AT_AFTER_QUOTED; return TURTLE_STRING; }
<TURTLE_DQ>[""]"@"	{ ttlyylval.box = ttlp_strliteral (ttlp_arg, yytext, TTLP_STRLITERAL_QUOT_AT, '\"'); BEGIN AT_AFTER_QUOTED; return TURTLE_STRING; }
<TURTLE_SQ>{S_NL}	{
    if (!(TTLP_STRING_MAY_CONTAIN_CRLF & ttlp_arg[0].ttlp_flags))
      ttlyyerror ("End-of-line in a short single-quoted string; this error can be suppressed by parser flags");
    ttlp_arg[0].ttlp_lexlineno++; yymore(); }
<TURTLE_DQ>{S_NL}	{
    if (!(TTLP_STRING_MAY_CONTAIN_CRLF & ttlp_arg[0].ttlp_flags))
      ttlyyerror ("End-of-line in a short double-quoted string; this error can be suppressed by parser flags");
    ttlp_arg[0].ttlp_lexlineno++; yymore(); }
<TURTLE_SQ>(({SPAR_SQ_PLAIN}|{SPAR_ECHAR})+)		{ yymore(); }
<TURTLE_DQ>(({SPAR_DQ_PLAIN}|{SPAR_ECHAR})+)		{ yymore(); }
<TURTLE_SQ>[\\]		{ ttlyyerror ("Bad escape sequence in a short single-quoted string"); }
<TURTLE_DQ>[\\]		{ ttlyyerror ("Bad escape sequence in a short double-quoted string"); }
<TURTLE_SQ><<EOF>>		{ ttlyyerror ("Unterminated short single-quoted string"); }
<TURTLE_DQ><<EOF>>		{ ttlyyerror ("Unterminated short double-quoted string"); }

<INITIAL>[+-]?{INTEGER_LITERAL}		{ return ttlp_NUMBER_int (yylval, ttlp_arg, yyg); }
<INITIAL>[+-]?{DECIMAL_LITERAL}		{ return ttlp_NUMBER_decimal (yylval, ttlp_arg, yyg); }
<INITIAL>[+-]?{DOUBLE_LITERAL}		{ return ttlp_NUMBER_double (yylval, ttlp_arg, yyg); }

<INITIAL>("#"(.*))?{S_NL}		{ ttlp_arg[0].ttlp_lexlineno++; }
<INITIAL>"#"(.*)				{ }
<INITIAL>[ \t]+				{ }
<INITIAL>.		{ ttlyyerror ("Invalid character in INITIAL expression"); }

%%

/*void ttlyy_reset (yyscan_t scanner)
{
  ttlyyrestart (NULL, scanner);
  BEGIN INITIAL;
}*/

void
ttlyyerror_if_long_qname (ttlp_t *ttlp_arg, caddr_t box, const char *lex_type_descr, struct yyguts_t * yyg)
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
	ttlyyerror ("The absolute value of numeric constant is too large");
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
ttl_query_lex_analyze (caddr_t str, wcharset_t *query_charset)
{
  dk_set_t lexems = NULL;
  caddr_t result_array;
  ttlp_t *ttlp;
  yyscan_t scanner;
  if (!DV_STRINGP(str))
    {
      return list (1, list (3, (ptrlong)0, (ptrlong)0, box_dv_short_string ("TURTLE parser: input text is not a string")));
    }
  ttlp = ttlp_alloc ();
  QR_RESET_CTX
    {
      ttlp->ttlp_text = str;
      ttlp->ttlp_text_len = strlen (str);
      ttlp->ttlp_err_hdr = "TURTLE parser";
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
#ifdef MALLOC_DEBUG
      yy_push_state (INITIAL, scanner);
#endif
      for (;;)
        {
          caddr_t lex_value = NULL;
          int lexem;
          lexem = ttlyylex (&lex_value, ttlp, scanner);
          if (0 == lexem)
            break;
          dk_set_push (&lexems, list (5,
		box_num (ttlp->ttlp_lexlineno),
		ttlp->ttlp_lexdepth,
		box_copy (ttlp->ttlp_raw_text),
		lexem, lex_value ) );
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
  ccaddr_t *cbk_names, caddr_t app_env,
  query_instance_t *qi, wcharset_t *query_charset, caddr_t *err_ret )
{
  FILE *srcfile = NULL;
  bh_from_client_fwd_iter_t bcfi;
  bh_from_disk_fwd_iter_t bdfi;
  dk_session_fwd_iter_t dsfi;
  /* !!!TBD: add wide support: int text_strg_is_wide = 0; */
  dtp_t dtp_of_text = (arg1_is_filename ? 0 : DV_TYPE_OF (text_or_filename));
  caddr_t res;
  ttlp_t *ttlp;
  yyscan_t scanner;
  triple_feed_t *tf;
  if (arg1_is_filename)
    sec_check_dba (qi, "<reading TURTLE from local file>");
  if (DV_BLOB_XPER_HANDLE == dtp_of_text)
    sqlr_new_error ("42000", "SP036", "Unable to parse TURTLE from persistent XML object");
  ttlp = ttlp_alloc ();
  ttlp->ttlp_flags = flags;
  tf = ttlp->ttlp_tf;
  tf->tf_qi = qi;
  tf->tf_app_env = app_env;

  if (arg1_is_filename)
    {
#ifdef WIN32
      char fname[_MAX_PATH], *fname_ptr;
      strncpy (fname, text_or_filename, _MAX_PATH);
      fname[_MAX_PATH - 1] = '\0';
      for (fname_ptr = fname; fname_ptr[0]; fname_ptr++)
        {
          switch (fname_ptr[0])
            {
            case '|':
              fname_ptr[0] = ':';
              break;
            case '/':
              fname_ptr[0] = '\\';
              break;
            }
        }
#else
      char *fname = ((char *) text_or_filename);
#endif
      sec_check_dba (qi, "<read XML from URL of type file://...>");
      srcfile = fopen (fname, "rb");
      if (NULL == srcfile)
        {
          ttlp_free (ttlp);
	  sqlr_new_error ("42000", "SR598", "TURTLE parser has failed to open file '%s' for reading", fname);
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
  tf->tf_graph_uri = box_copy (graph_uri);
  ttlp->ttlp_err_hdr = "TURTLE RDF loader";
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
    ttlp->ttlp_base_uri = box_copy (base_uri);
  QR_RESET_CTX
    {
      ttlyylex_init (&scanner);
      ttlyyset_extra (ttlp, scanner);
#ifdef MALLOC_DEBUG
      yy_push_state (INITIAL, scanner);
#endif
      tf_set_cbk_names (tf, (const char **)cbk_names);
      tf->tf_graph_iid = tf_get_iid (tf, tf->tf_graph_uri);
      tf_commit (tf);
      tf_new_graph (tf, tf->tf_graph_uri);
      ttlyyparse (ttlp, scanner);
      tf_commit (tf);
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      ttlp->ttlp_catched_error = thr_get_error_code (self);
      thr_set_error_code (self, NULL);
      if (NULL != ttlp->ttlp_iter_abend)
        {
          ttlp->ttlp_iter_abend (ttlp->ttlp_iter_data);
          ttlp->ttlp_iter_abend = NULL;
        }
      /*no POP_QR_RESET*/;
    }
  END_QR_RESET
  if (NULL != srcfile)
    fclose (srcfile);
  ttlyylex_destroy (scanner);
  err_ret[0] = ttlp->ttlp_catched_error;
  ttlp->ttlp_catched_error = NULL;
  res = ttlp->ttlp_tf->tf_graph_uri;
  ttlp->ttlp_tf->tf_graph_uri = NULL;
  ttlp_free (ttlp);
  return res;
}


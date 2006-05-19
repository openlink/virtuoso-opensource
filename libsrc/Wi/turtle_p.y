/*
 *   
 *   This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *   project.
 *   
 *   Copyright (C) 1998-2006 OpenLink Software
 *   
 *   This project is free software; you can redistribute it and/or modify it
 *   under the terms of the GNU General Public License as published by the
 *   Free Software Foundation; only version 2 of the License, dated June 1991.
 *   
 *   This program is distributed in the hope that it will be useful, but
 *   WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *   General Public License for more details.
 *   
 *   You should have received a copy of the GNU General Public License along
 *   with this program; if not, write to the Free Software Foundation, Inc.,
 *   51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *   
 *   
*/
%pure_parser

%{

#include "libutil.h"
#include "sqlnode.h"
#include "sqlparext.h"
#include "rdf_core.h"
#include "xmltree.h"
/*#include "langfunc.h"*/

#ifdef RE_ENTRANT_TTLYY
#define YYPARSE_PARAM ttlp_as_void
#define YYLEX_PARAM YYPARSE_PARAM
#define ttlp_arg ((ttlp_t *)(ttlp_as_void))
#else
#define ttlp_arg ttlp_ptr
#endif


#ifdef DEBUG
#define ttlyyerror(strg) ttlyyerror_impl_1(TTLP_ARG NULL, yystate, yyssa, yyssp, (strg))
#else
#define ttlyyerror(strg) ttlyyerror_impl(TTLP_ARG NULL, (strg))
#endif

#ifdef TTLDEBUG
#define YYDEBUG 1
#endif

%}

/* symbolic tokens */
%union {
  caddr_t box;
  ptrlong token_type;
  void *nothing;
}

%token __TTL_PUNCT_BEGIN	/* Delimiting value for syntax highlighting */

%token _CARET_WS	/*:: PUNCT("^"), TTL, LAST("^ "), LAST("^\n") ::*/
%token _CARET_NOWS	/*:: PUNCT("^"), TTL, LAST1("^x") ::*/
%token _CARET_CARET	/*:: PUNCT_TTL_LAST("^^") ::*/
%token _COLON		/*:: PUNCT_TTL_LAST(":") ::*/
%token _COMMA		/*:: PUNCT_TTL_LAST(",") ::*/
%token _DOT_WS		/*:: PUNCT("."), TTL, LAST(". "), LAST(".\n") ::*/
%token _DOT_NOWS	/*:: PUNCT("."), TTL, LAST1(".x") ::*/
%token _LPAR		/*:: PUNCT_TTL_LAST("(") ::*/
%token _LSQBRA		/*:: PUNCT_TTL_LAST("[") ::*/
%token _LSQBRA_RSQBRA	/*:: PUNCT_TTL_LAST("[]") ::*/
%token _RPAR		/*:: PUNCT_TTL_LAST("( )") ::*/
%token _RSQBRA		/*:: PUNCT_TTL_LAST("[ ]") ::*/
%token _SEMI		/*:: PUNCT_TTL_LAST(";") ::*/

%token a_L		/*:: PUNCT_TTL_LAST("@a") ::*/
%token is_L		/*:: PUNCT_TTL_LAST("@is") ::*/
%token keywords_L	/*:: PUNCT_TTL_LAST("@keywords") ::*/
%token of_L		/*:: PUNCT_TTL_LAST("@of") ::*/
%token prefix_L		/*:: PUNCT_TTL_LAST("@prefix") ::*/
%token this_L		/*:: PUNCT_TTL_LAST("@this") ::*/
%token false_L		/*:: PUNCT_TTL_LAST("false") ::*/
%token true_L		/*:: PUNCT_TTL_LAST("true") ::*/

%token __TTL_PUNCT_END	/* Delimiting value for syntax highlighting */

%token __TTL_NONPUNCT_START	/* Delimiting value for syntax highlighting */

%token <box> TURTLE_INTEGER	/*:: LITERAL("%d"), TTL, LAST("1234"), LAST("+1234"), LAST("-1234") ::*/
%token <box> TURTLE_DECIMAL	/*:: LITERAL("%d"), TTL, LAST("1234.56"), LAST("+1234.56"), LAST("-1234.56") ::*/
%token <box> TURTLE_DOUBLE	/*:: LITERAL("%d"), TTL, LAST("1234.56e1"), LAST("+1234.56e1"), LAST("-1234.56e1") ::*/

%token <box> TURTLE_STRING /*:: LITERAL("%s"), TTL, LAST("'sq'"), LAST("\"dq\""), LAST("'''sq1\nsq2'''"), LAST("\"\"\"dq1\ndq2\"\"\""), LAST("'\"'"), LAST("'-\\\\-\\t-\\v-\\r-\\'-\\\"-\\u1234-\\U12345678-\\uaAfF-'") ::*/
%token <box> LANGTAG	/*:: LITERAL("%s"), TTL, LAST("@ES") ::*/

%token <box> QNAME	/*:: LITERAL("%s"), TTL, LAST("pre.fi-X.1:_f.Rag.2"), LAST(":_f.Rag.2") ::*/
%token <box> QNAME_NS	/*:: LITERAL("%s"), TTL, LAST("pre.fi-X.1:") ::*/
%token <box> BLANK_NODE_LABEL /*:: LITERAL("%s"), TTL, LAST("_:_f.Rag.2") ::*/
%token <box> Q_IRI_REF	/*:: LITERAL("%s"), TTL, LAST("<something>"), LAST("<http://www.example.com/sample#frag>") ::*/

%token __TTL_NONPUNCT_END	/* Delimiting value for syntax highlighting */

%type<box> blank
%type<box> subject
%type<box> verb
%%

turtledoc
        : /* empty */
	| clauses _DOT_WS
	| clauses _DOT_NOWS
	| clauses error { ttlyyerror ("The clause is not terminated by a dot"); }
	;

clauses
	: clause
	| clauses _DOT_WS clause
	;

clause
        : keywords_L keyword_list
        | prefix_L QNAME_NS Q_IRI_REF	{
		dk_set_push (&(ttlp_arg->ttlp_namespaces), $3);
		dk_set_push (&(ttlp_arg->ttlp_namespaces), $2); }
	| prefix_L _COLON Q_IRI_REF	{
		dk_set_push (&(ttlp_arg->ttlp_namespaces), $3);
		dk_set_push (&(ttlp_arg->ttlp_namespaces), box_dv_short_string(":")); }
	| subject
		{ dk_free_box (ttlp_arg->ttlp_subj_uri); ttlp_arg->ttlp_subj_uri = $1; }
		predicate_object_list semicolon_opt	{ /* no op */; }
	;

keyword_list
	: QNAME	{;;;}
	| keyword_list _COMMA QNAME	{;;;}
	;

semicolon_opt
	: /*empty*/
	| _SEMI
        ;

predicate_object_list
	: verb
		{ dk_free_box (ttlp_arg->ttlp_pred_uri); ttlp_arg->ttlp_pred_uri = $1; }
		object_list	{ /* no op */; }
	| predicate_object_list _SEMI verb
		{ dk_free_box (ttlp_arg->ttlp_pred_uri); ttlp_arg->ttlp_pred_uri = $3; }
		object_list	{ /* no op */; }
	;

object_list
	: object	{;;;}
	| object_list _COMMA object		{;;;}
	;

verb
	: Q_IRI_REF	{ $$ = $1; }
	| QNAME		{ $$ = ttlp_expand_qname_prefix (TTLP_ARG $1); }
	| a_L		{ $$ = box_dv_uname_string ("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"); }
	;

subject
	: Q_IRI_REF	{ $$ = $1; }
	| QNAME		{ $$ = ttlp_expand_qname_prefix (TTLP_ARG $1); }
	| blank		{ $$ = $1; }
	;

object
	: Q_IRI_REF	{ ttlp_triple (TTLP_ARG $1); }
	| QNAME		{ ttlp_triple (TTLP_ARG ttlp_expand_qname_prefix (TTLP_ARG $1)); }
	| blank		{ ttlp_triple (TTLP_ARG $1); }
	| true_L	{ ttlp_triple_l (TTLP_ARG (caddr_t)((ptrlong)1), uname_xmlschema_ns_uri_hash_boolean, NULL); }
	| false_L	{ ttlp_triple_l (TTLP_ARG (caddr_t)((ptrlong)0), uname_xmlschema_ns_uri_hash_boolean, NULL); }
	| TURTLE_INTEGER	{ ttlp_triple_l (TTLP_ARG $1, uname_xmlschema_ns_uri_hash_integer, NULL); }
	| TURTLE_DECIMAL	{ ttlp_triple_l (TTLP_ARG $1, uname_xmlschema_ns_uri_hash_decimal, NULL); }
	| TURTLE_DOUBLE	{ ttlp_triple_l (TTLP_ARG $1, uname_xmlschema_ns_uri_hash_double, NULL); }
	| TURTLE_STRING				{ ttlp_triple_l (TTLP_ARG $1, NULL, NULL); }
	| TURTLE_STRING LANGTAG			{ ttlp_triple_l (TTLP_ARG $1, NULL, $2); }
	| TURTLE_STRING _CARET_CARET Q_IRI_REF	{ ttlp_triple_l (TTLP_ARG $1, $3, NULL); }
	| TURTLE_STRING _CARET_CARET QNAME	{ ttlp_triple_l (TTLP_ARG $1, ttlp_expand_qname_prefix (TTLP_ARG $3), NULL); }
	;

blank
	: BLANK_NODE_LABEL	{ $$ = tf_bnode_iid (ttlp_arg->ttlp_tf, $1); dk_free_box ($1); }
	| _LSQBRA_RSQBRA	{ $$ = tf_bnode_iid (ttlp_arg->ttlp_tf, NULL); }
        | _LSQBRA
		{ dk_set_push (&(ttlp_arg->ttlp_saved_uris), ttlp_arg->ttlp_subj_uri);
		  dk_set_push (&(ttlp_arg->ttlp_saved_uris), ttlp_arg->ttlp_pred_uri);
		  ttlp_arg->ttlp_subj_uri = tf_bnode_iid (ttlp_arg->ttlp_tf, NULL);
		  ttlp_arg->ttlp_pred_uri = NULL; }
		predicate_object_list _RSQBRA
		{ $$ = ttlp_arg->ttlp_subj_uri;
		  dk_free_box (ttlp_arg->ttlp_pred_uri);
		  ttlp_arg->ttlp_pred_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		  ttlp_arg->ttlp_subj_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris)); }
        | _LPAR	
		{ caddr_t top_bnode = tf_bnode_iid (ttlp_arg->ttlp_tf, NULL);
                  dk_set_push (&(ttlp_arg->ttlp_saved_uris), ttlp_arg->ttlp_subj_uri);
		  dk_set_push (&(ttlp_arg->ttlp_saved_uris), ttlp_arg->ttlp_pred_uri);
                  dk_set_push (&(ttlp_arg->ttlp_saved_uris), top_bnode); /* This is for retval */
                  ttlp_arg->ttlp_subj_uri = box_copy (top_bnode); /* This is the last in the chain */
		  ttlp_arg->ttlp_pred_uri = box_dv_uname_string ("http://www.w3.org/1999/02/22-rdf-syntax-ns#first"); }
		items _RPAR
		{
		  dk_free_box (ttlp_arg->ttlp_pred_uri);
		  ttlp_arg->ttlp_pred_uri = box_dv_uname_string ("http://www.w3.org/1999/02/22-rdf-syntax-ns#rest");
                  ttlp_triple (TTLP_ARG box_dv_uname_string ("http://www.w3.org/1999/02/22-rdf-syntax-ns#nil"));
		  $$ = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		  dk_free_box (ttlp_arg->ttlp_pred_uri);
		  dk_free_box (ttlp_arg->ttlp_subj_uri);
		  ttlp_arg->ttlp_pred_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		  ttlp_arg->ttlp_subj_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris)); }
	;

items
	: /*empty*/	{}
	| items object
		{ caddr_t next_bnode = tf_bnode_iid (ttlp_arg->ttlp_tf, NULL);
                  caddr_t first_pred = ttlp_arg->ttlp_pred_uri;
		  ttlp_arg->ttlp_pred_uri = box_dv_uname_string ("http://www.w3.org/1999/02/22-rdf-syntax-ns#rest");
                  ttlp_triple (TTLP_ARG box_copy (next_bnode));
		  ttlp_arg->ttlp_pred_uri = first_pred;
		  dk_free_box (ttlp_arg->ttlp_subj_uri);
                  ttlp_arg->ttlp_subj_uri = next_bnode; }
	;

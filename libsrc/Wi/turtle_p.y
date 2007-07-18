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
%token _LBRA		/*:: PUNCT_TTL_LAST("{") ::*/
%token _LPAR		/*:: PUNCT_TTL_LAST("(") ::*/
%token _LSQBRA		/*:: PUNCT_TTL_LAST("[") ::*/
%token _LSQBRA_RSQBRA	/*:: PUNCT_TTL_LAST("[]") ::*/
%token _RBRA		/*:: PUNCT_TTL_LAST("{ }") ::*/
%token _RPAR		/*:: PUNCT_TTL_LAST("( )") ::*/
%token _RSQBRA		/*:: PUNCT_TTL_LAST("[ ]") ::*/
%token _SEMI		/*:: PUNCT_TTL_LAST(";") ::*/
%token _EQ		/*:: PUNCT_TTL_LAST("=") ::*/
%token _EQ_GT		/*:: PUNCT_TTL_LAST("=>") ::*/
%token _LT_EQ		/*:: PUNCT_TTL_LAST("<=") ::*/
%token _BANG		/*:: PUNCT_TTL_LAST("!") ::*/

%token _AT_a_L		/*:: PUNCT_TTL_LAST("@a") ::*/
%token _AT_has_L	/*:: PUNCT_TTL_LAST("@has") ::*/
%token _AT_is_L		/*:: PUNCT_TTL_LAST("@is") ::*/
%token _AT_keywords_L	/*:: PUNCT_TTL_LAST("@keywords") ::*/
%token _AT_of_L		/*:: PUNCT_TTL_LAST("@of") ::*/
%token _AT_prefix_L	/*:: PUNCT_TTL_LAST("@prefix") ::*/
%token _AT_this_L	/*:: PUNCT_TTL_LAST("@this") ::*/
%token false_L		/*:: PUNCT_TTL_LAST("false") ::*/
%token true_L		/*:: PUNCT_TTL_LAST("true") ::*/

%token __TTL_PUNCT_END	/* Delimiting value for syntax highlighting */

%token __TTL_NONPUNCT_START	/* Delimiting value for syntax highlighting */

%token <box> TURTLE_INTEGER	/*:: LITERAL("%d"), TTL, LAST("1234"), LAST("+1234"), LAST("-1234") ::*/
%token <box> TURTLE_DECIMAL	/*:: LITERAL("%d"), TTL, LAST("1234.56"), LAST("+1234.56"), LAST("-1234.56") ::*/
%token <box> TURTLE_DOUBLE	/*:: LITERAL("%d"), TTL, LAST("1234.56e1"), LAST("+1234.56e1"), LAST("-1234.56e1") ::*/

%token <box> TURTLE_STRING /*:: LITERAL("%s"), TTL, LAST("'sq'"), LAST("\"dq\""), LAST("'''sq1\nsq2'''"), LAST("\"\"\"dq1\ndq2\"\"\""), LAST("'\"'"), LAST("'-\\\\-\\t-\\v-\\r-\\'-\\\"-\\u1234-\\U12345678-\\uaAfF-'") ::*/
%token <box> KEYWORD	/*:: LITERAL("@%s"), TTL, LAST("@example") ::*/
%token <box> LANGTAG	/*:: LITERAL("%s"), TTL, LAST("@ES") ::*/

%token <box> QNAME	/*:: LITERAL("%s"), TTL, LAST("pre.fi-X.1:_f.Rag.2"), LAST(":_f.Rag.2") ::*/
%token <box> QNAME_NS	/*:: LITERAL("%s"), TTL, LAST("pre.fi-X.1:") ::*/
%token <box> VARIABLE	/*:: LITERAL("%s"), TTL, LAST("?x"), LAST("?_f.Rag.2") ::*/
%token <box> BLANK_NODE_LABEL /*:: LITERAL("%s"), TTL, LAST("_:_f.Rag.2") ::*/
%token <box> Q_IRI_REF	/*:: LITERAL("%s"), TTL, LAST("<something>"), LAST("<http://www.example.com/sample#frag>") ::*/

%token __TTL_NONPUNCT_END	/* Delimiting value for syntax highlighting */

%type<box> blank
%type<box> blank_block_subj
%type<box> blank_block_seq
%type<box> blank_block_formula
%type<box> subject
%type<box> verb
%type<box> rev_verb
%type<token_type> keyword
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

triple_clauses
	: triple_clause
	| triple_clauses _DOT_WS triple_clause
	;

clause
        : _AT_keywords_L { ttlp_arg->ttlp_special_qnames = ~0; } keyword_list
        | _AT_prefix_L QNAME_NS Q_IRI_REF	{
		dk_set_push (&(ttlp_arg->ttlp_namespaces), $3);
		dk_set_push (&(ttlp_arg->ttlp_namespaces), $2); }
	| _AT_prefix_L _COLON Q_IRI_REF		{
		dk_free_box (ttlp_arg->ttlp_default_ns_uri);
		ttlp_arg->ttlp_default_ns_uri = $3; }
	| triple_clause
        | error { ttlyyerror ("Only a triple or a special clause (like prefix declaration) is allowed here"); }
	;

triple_clause
	: subject
		{ dk_free_tree (ttlp_arg->ttlp_subj_uri); ttlp_arg->ttlp_subj_uri = $1; }
		predicate_object_list semicolon_opt	{ /* no op */; }
	| _LSQBRA blank_block_subj	{ /* no op */; }
	| _LPAR blank_block_seq		{ /* no op */; }
	;

keyword_list
	: keyword	{ ttlp_arg->ttlp_special_qnames &= ~($1); }
	| keyword_list _COMMA keyword	{ ttlp_arg->ttlp_special_qnames &= ~($3); }
	;

keyword
	: QNAME		{ $$ = ttlp_bit_of_special_qname ($1); }
	| _AT_a_L	{ $$ = TTLP_ALLOW_QNAME_A; }
	| _AT_has_L	{ $$ = TTLP_ALLOW_QNAME_HAS; }
	| _AT_is_L	{ $$ = TTLP_ALLOW_QNAME_IS; }
	| _AT_of_L	{ $$ = TTLP_ALLOW_QNAME_OF; }
	| _AT_this_L	{ $$ = TTLP_ALLOW_QNAME_THIS; }
	;

semicolon_opt
	: /*empty*/
	| _SEMI
        ;

predicate_object_list
	: verb_and_object_list
	| predicate_object_list _SEMI verb_and_object_list
        | _COMMA { ttlyyerror ("Missing object before comma"); }
        | _SEMI { ttlyyerror ("Missing predicate and object before semicolon"); }
        | _DOT_WS { ttlyyerror ("Missing predicate and object before dot"); }
        | error { ttlyyerror ("Predicate expected"); }
	;

verb_and_object_list
	: verb
		{ dk_free_tree (ttlp_arg->ttlp_pred_uri); ttlp_arg->ttlp_pred_uri = $1; }
		object_list	{ /* no op */; }
	| rev_verb
		{ dk_free_tree (ttlp_arg->ttlp_pred_uri); ttlp_arg->ttlp_pred_uri = $1;
		  ttlp_arg->ttlp_pred_is_reverse = 1; }
		object_list	{ ttlp_arg->ttlp_pred_is_reverse = 0; }
	;


object_list
	: object	{; /* triple is made by object */ }
	| object_list _COMMA object		{; /* triple is made by object */ }
        | _COMMA { ttlyyerror ("Missing object before comma"); }
        | _SEMI { ttlyyerror ("Missing object before semicolon"); }
        | _DOT_WS { ttlyyerror ("Missing object before dot"); }
        | error { ttlyyerror ("Object expected"); }
	;

verb
	: Q_IRI_REF	{ $$ = $1; if (NULL != ttlp_arg->ttlp_base_uri) $$ = ttlp_uri_resolve (TTLP_ARG $$); }
	| QNAME		{ $$ = ttlp_expand_qname_prefix (TTLP_ARG $1); if (NULL != ttlp_arg->ttlp_base_uri) $$ = ttlp_uri_resolve (TTLP_ARG $$); }
	| VARIABLE	{ $$ = $1; }
	| _AT_a_L	{ $$ = uname_rdf_ns_uri_type; }
	| _EQ		{ $$ = box_dv_uname_string ("http://www.w3.org/2002/07/owl#sameAs"); }
        | _EQ_GT	{ $$ = box_dv_uname_string ("http://www.w3.org/2000/10/swap/log#implies"); }
	| _LSQBRA_RSQBRA
		{
		  if (!(ttlp_arg->ttlp_flags & TTLP_VERB_MAY_BE_BLANK))
		    ttlyyerror ("Blank node (written as '[]') can not be used as a predicate");
		  $$ = tf_bnode_iid (ttlp_arg->ttlp_tf, NULL); }
	| BLANK_NODE_LABEL
		{
		  if (!(ttlp_arg->ttlp_flags & TTLP_VERB_MAY_BE_BLANK))
		    ttlyyerror ("Blank node (written as '_:...' label) can not be used as a predicate");
                  if (ttlp_arg->ttlp_formula_iid)
		    $$ = tf_formula_bnode_iid (TTLP_ARG $1);
                  else
		    $$ = tf_bnode_iid (ttlp_arg->ttlp_tf, $1);
		  dk_free_box ($1); }
        | _LSQBRA
		{
		  if (!(ttlp_arg->ttlp_flags & TTLP_VERB_MAY_BE_BLANK))
		    ttlyyerror ("Blank node (written as '[...]' block) can not be used as a predicate"); }
		blank_block_subj { $$ = $3; }
        | _LPAR
		{
		  if (!(ttlp_arg->ttlp_flags & TTLP_VERB_MAY_BE_BLANK))
		    ttlyyerror ("Sequence blank node (written as list in parenthesis) can not be used as a predicate"); }
		blank_block_seq { $$ = $3; }
        | _LBRA
		{
		  if (!(ttlp_arg->ttlp_flags & TTLP_VERB_MAY_BE_BLANK))
		    ttlyyerror ("Sequence blank node (written as '{...}' formula) can not be used as a predicate"); }
		blank_block_formula { $$ = $3; }
	;

rev_verb
	: _AT_is_L Q_IRI_REF _AT_of_L 	{ $$ = $2;  if (NULL != ttlp_arg->ttlp_base_uri) $$ = ttlp_uri_resolve (TTLP_ARG $$); }
	| _AT_is_L QNAME _AT_of_L	{ $$ = ttlp_expand_qname_prefix (TTLP_ARG $2);  if (NULL != ttlp_arg->ttlp_base_uri) $$ = ttlp_uri_resolve (TTLP_ARG $$); }
	| _AT_is_L VARIABLE _AT_of_L 	{ $$ = $2; }
        | _LT_EQ	{ $$ = box_dv_uname_string ("http://www.w3.org/2000/10/swap/log#implies"); /* Note this 'double reversed' meaning :) */ }
	;

subject
	: Q_IRI_REF	{ $$ = $1; if (NULL != ttlp_arg->ttlp_base_uri) $$ = ttlp_uri_resolve (TTLP_ARG $$); }
	| QNAME		{ $$ = ttlp_expand_qname_prefix (TTLP_ARG $1); if (NULL != ttlp_arg->ttlp_base_uri) $$ = ttlp_uri_resolve (TTLP_ARG $$); }
	| VARIABLE	{ $$ = $1; }
	| blank		{ $$ = $1; }
	| literal_subject
		{
		  if (!(ttlp_inst.ttlp_flags & TTLP_SKIP_LITERAL_SUBJECTS))
		    ttlyyerror_impl (TTLP_ARG "", "Virtuoso does not support literal subjects");
		  $$ = NULL; }
	;

literal_subject
	: true_L	{ /* no op */; }
	| false_L	{ /* no op */; }
	| TURTLE_INTEGER	{ /* no op */; }
	| TURTLE_DECIMAL	{ /* no op */; }
	| TURTLE_DOUBLE		{ /* no op */; }
	| TURTLE_STRING				{ /* no op */; }
	| TURTLE_STRING LANGTAG			{ /* no op */; }
	| TURTLE_STRING _CARET_CARET Q_IRI_REF	{ /* no op */; }
	| TURTLE_STRING _CARET_CARET QNAME	{ /* no op */; }
	;


object
	: Q_IRI_REF
		{
		  caddr_t o = $1;
		  if (NULL != ttlp_arg->ttlp_base_uri)
		    o = ttlp_uri_resolve (TTLP_ARG o);
		  ttlp_triple_and_inf (TTLP_ARG o); }
	| QNAME
		{
		  caddr_t o = $1;
		  o = ttlp_expand_qname_prefix (TTLP_ARG $1);
		  if (NULL != ttlp_arg->ttlp_base_uri)
		    o = ttlp_uri_resolve (TTLP_ARG o);
		  ttlp_triple_and_inf (TTLP_ARG o); }
	| VARIABLE	{ ttlp_triple_and_inf (TTLP_ARG $1); }
	| blank		{ ttlp_triple_and_inf (TTLP_ARG $1); }
	| true_L	{ ttlp_triple_l_and_inf (TTLP_ARG (caddr_t)((ptrlong)1), uname_xmlschema_ns_uri_hash_boolean, NULL); }
	| false_L	{ ttlp_triple_l_and_inf (TTLP_ARG (caddr_t)((ptrlong)0), uname_xmlschema_ns_uri_hash_boolean, NULL); }
	| TURTLE_INTEGER	{ ttlp_triple_l_and_inf (TTLP_ARG $1, uname_xmlschema_ns_uri_hash_integer, NULL); }
	| TURTLE_DECIMAL	{ ttlp_triple_l_and_inf (TTLP_ARG $1, uname_xmlschema_ns_uri_hash_decimal, NULL); }
	| TURTLE_DOUBLE		{ ttlp_triple_l_and_inf (TTLP_ARG $1, uname_xmlschema_ns_uri_hash_double, NULL); }
	| TURTLE_STRING				{ ttlp_triple_l_and_inf (TTLP_ARG $1, NULL, NULL); }
	| TURTLE_STRING LANGTAG			{ ttlp_triple_l_and_inf (TTLP_ARG $1, NULL, $2); }
	| TURTLE_STRING _CARET_CARET Q_IRI_REF	{ ttlp_triple_l_and_inf (TTLP_ARG $1, $3, NULL); }
	| TURTLE_STRING _CARET_CARET QNAME	{ ttlp_triple_l_and_inf (TTLP_ARG $1, ttlp_expand_qname_prefix (TTLP_ARG $3), NULL); }
	;

blank
	: BLANK_NODE_LABEL
		{
                  if (ttlp_arg->ttlp_formula_iid)
		    $$ = tf_formula_bnode_iid (TTLP_ARG $1);
                  else
		    $$ = tf_bnode_iid (ttlp_arg->ttlp_tf, $1);
		  dk_free_box ($1); }
	| _LSQBRA_RSQBRA	{ $$ = tf_bnode_iid (ttlp_arg->ttlp_tf, NULL); }
        | _LSQBRA blank_block_subj	{ $$ = $2; }
        | _LPAR	blank_block_seq		{ $$ = $2; }
        | _LBRA	blank_block_formula	{ $$ = $2; }
	;

blank_block_subj
        : 
		{ dk_set_push (&(ttlp_arg->ttlp_saved_uris), (void *)(ptrlong)ttlp_arg->ttlp_pred_is_reverse);
                  dk_set_push (&(ttlp_arg->ttlp_saved_uris), ttlp_arg->ttlp_subj_uri);
		  dk_set_push (&(ttlp_arg->ttlp_saved_uris), ttlp_arg->ttlp_pred_uri);
		  ttlp_arg->ttlp_subj_uri = tf_bnode_iid (ttlp_arg->ttlp_tf, NULL);
		  ttlp_arg->ttlp_pred_uri = NULL; }
		predicate_object_list semicolon_opt _RSQBRA
		{ $$ = ttlp_arg->ttlp_subj_uri;
		  dk_free_tree (ttlp_arg->ttlp_pred_uri);
		  ttlp_arg->ttlp_pred_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		  ttlp_arg->ttlp_subj_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
                  ttlp_arg->ttlp_pred_is_reverse = (ptrlong)dk_set_pop (&(ttlp_arg->ttlp_saved_uris)); }
	;

blank_block_seq
        :	
		{ caddr_t top_bnode = tf_bnode_iid (ttlp_arg->ttlp_tf, NULL);
                  dk_set_push (&(ttlp_arg->ttlp_saved_uris), (void *)(ptrlong)(ttlp_arg->ttlp_pred_is_reverse));
                  dk_set_push (&(ttlp_arg->ttlp_saved_uris), ttlp_arg->ttlp_subj_uri);
		  dk_set_push (&(ttlp_arg->ttlp_saved_uris), ttlp_arg->ttlp_pred_uri);
                  dk_set_push (&(ttlp_arg->ttlp_saved_uris), top_bnode); /* This is for retval */
                  ttlp_arg->ttlp_subj_uri = box_copy (top_bnode); /* This is the last in the chain */
		  ttlp_arg->ttlp_pred_uri = uname_rdf_ns_uri_first; }
		items _RPAR
		{
		  dk_free_tree (ttlp_arg->ttlp_pred_uri);
		  ttlp_arg->ttlp_pred_uri = uname_rdf_ns_uri_rest;
                  ttlp_triple_and_inf (TTLP_ARG uname_rdf_ns_uri_nil);
		  $$ = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		  dk_free_tree (ttlp_arg->ttlp_pred_uri);
		  dk_free_tree (ttlp_arg->ttlp_subj_uri);
		  ttlp_arg->ttlp_pred_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		  ttlp_arg->ttlp_subj_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
                  ttlp_arg->ttlp_pred_is_reverse = (ptrlong)dk_set_pop (&(ttlp_arg->ttlp_saved_uris)); }
	;

blank_block_formula
	:
		{
                  dk_set_push (&(ttlp_arg->ttlp_saved_uris), ttlp_arg->ttlp_formula_iid);
                  dk_set_push (&(ttlp_arg->ttlp_saved_uris), (void *)(ptrlong)ttlp_arg->ttlp_pred_is_reverse);
                  dk_set_push (&(ttlp_arg->ttlp_saved_uris), ttlp_arg->ttlp_subj_uri);
		  dk_set_push (&(ttlp_arg->ttlp_saved_uris), ttlp_arg->ttlp_pred_uri);
		  ttlp_arg->ttlp_formula_iid = tf_bnode_iid (ttlp_arg->ttlp_tf, NULL);
		  ttlp_arg->ttlp_subj_uri = NULL;
		  ttlp_arg->ttlp_pred_uri = NULL; }
		triple_clauses _RBRA
		{ $$ = ttlp_arg->ttlp_formula_iid;
		  dk_free_tree (ttlp_arg->ttlp_subj_uri);
		  dk_free_tree (ttlp_arg->ttlp_pred_uri);
		  ttlp_arg->ttlp_pred_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		  ttlp_arg->ttlp_subj_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
                  ttlp_arg->ttlp_pred_is_reverse = (ptrlong)dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		  ttlp_arg->ttlp_formula_iid = dk_set_pop (&(ttlp_arg->ttlp_saved_uris)); }
	;

items
	: /*empty*/	{}
	| items object
		{ caddr_t next_bnode = tf_bnode_iid (ttlp_arg->ttlp_tf, NULL);
                  caddr_t first_pred = ttlp_arg->ttlp_pred_uri;
		  ttlp_arg->ttlp_pred_uri = uname_rdf_ns_uri_rest;
                  ttlp_triple_and_inf (TTLP_ARG box_copy (next_bnode));
		  ttlp_arg->ttlp_pred_uri = first_pred;
		  dk_free_tree (ttlp_arg->ttlp_subj_uri);
                  ttlp_arg->ttlp_subj_uri = next_bnode; }
	;

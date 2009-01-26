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
%parse-param {ttlp_t * ttlp_arg}
%parse-param {yyscan_t yyscanner}
%lex-param {ttlp_t * ttlp_arg}
%lex-param {yyscan_t yyscanner}
%expect 3

%{

#include "libutil.h"
#include "sqlnode.h"
#include "sqlparext.h"
#include "rdf_core.h"
#include "xmltree.h"
/*#include "langfunc.h"*/

#ifdef DEBUG
#define ttlyyerror(ttlp_arg,yyscan,strg) ttlyyerror_impl_1(ttlp_arg, NULL, yystate, yyssa, yyssp, (strg))
#define ttlyyerror_action(strg) ttlyyerror_impl_1(ttlp_arg, NULL, yystate, yyssa, yyssp, (strg))
#else
#define ttlyyerror(ttlp_arg,yyscan,strg) ttlyyerror_impl(ttlp_arg, NULL, (strg))
#define ttlyyerror_action(strg) ttlyyerror_impl(ttlp_arg, NULL, (strg))
#endif

#define TTLYYERROR_ACTION_COND(flag,strg) do { \
    if (!((flag) & ttlp_arg->ttlp_flags)) \
      ttlyyerror_action(strg); \
    else \
      tf_report (ttlp_arg->ttlp_tf, 'W', NULL, NULL, (strg)); \
  } while (0)


extern int ttlyylex (void *yylval_param, ttlp_t *ttlp_arg, yyscan_t yyscanner);


#ifdef TTLDEBUG
#define YYDEBUG 1
#endif

#define TTLP_URI_RESOLVE_IF_NEEDED(rel) \
  do { \
    if ((NULL != ttlp_arg->ttlp_tf->tf_base_uri) && strncmp ((rel), "http://", 7)) \
      (rel) = ttlp_uri_resolve (ttlp_arg, (rel)); \
    } while (0)

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
%token _DOT_WS		/*:: PUNCT("."), TTL, LAST(". "), LAST(".\n"), LAST(".") ::*/
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
%token _AT_base_L	/*:: PUNCT_TTL_LAST("@base") ::*/
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

%token _GARBAGE_BEFORE_DOT_WS	/* Syntax error that may be (inaccurately) recovered by skipping to dot and space */
%token TTL_RECOVERABLE_ERROR	/* Token that marks error so the triple should be discarded */
%token __TTL_NONPUNCT_END	/* Delimiting value for syntax highlighting */

%type<box> blank
%type<box> blank_block_subj
%type<box> blank_block_subj_tail
%type<box> blank_block_seq
%type<box> blank_block_formula
%type<box> verb
%type<box> rev_verb
%type<token_type> keyword

%left _GARBAGE_BEFORE_DOT_WS _DOT_WS
%left _SEMI
%left _COMMA
%left _LPAR _RPAR _LBRA _RBRA _LSQBRA _RSQBRA

%%

turtledoc
        : /* empty */
	| turtledoc clause
	;

clause
        : _AT_keywords_L { ttlp_arg->ttlp_special_qnames = ~0; } keyword_list dot_opt
	| _AT_base_L Q_IRI_REF dot_opt { dk_free_box (ttlp_arg->ttlp_tf->tf_base_uri); ttlp_arg->ttlp_tf->tf_base_uri = $2; }
        | _AT_prefix_L QNAME_NS Q_IRI_REF dot_opt {
		dk_set_push (&(ttlp_arg->ttlp_namespaces), $3);
		dk_set_push (&(ttlp_arg->ttlp_namespaces), $2); }
	| _AT_prefix_L _COLON Q_IRI_REF dot_opt	{
		dk_free_box (ttlp_arg->ttlp_default_ns_uri);
		ttlp_arg->ttlp_default_ns_uri = $3; }
	| q_complete { dk_free_tree (ttlp_arg->ttlp_subj_uri);
		ttlp_arg->ttlp_subj_uri = ttlp_arg->ttlp_last_complete_uri;
		ttlp_arg->ttlp_last_complete_uri = NULL; }
		trig_block_or_predicate_object_list
	| triple_clause_with_nonq_subj _DOT_WS
        | error { ttlyyerror_action ("Only a triple or a special clause (like prefix declaration) is allowed here"); }
	;

dot_opt
	: /* empty */
	| _DOT_WS
	;

trig_group_end
	: _DOT_WS _RBRA
	| _RBRA
	;

trig_block_or_predicate_object_list
	: predicate_object_list_or_garbage _DOT_WS
	| opt_eq_lbra { 
                tf_commit (ttlp_arg->ttlp_tf);
		TTLYYERROR_ACTION_COND (TTLP_ALLOW_TRIG, "Left curly brace can appear here only if the source text is TriG");
                ttlp_arg->ttlp_trig_graph_uri = ttlp_arg->ttlp_subj_uri; ttlp_arg->ttlp_subj_uri = NULL;
                dk_free_tree (ttlp_arg->ttlp_tf->tf_graph_iid);
                ttlp_arg->ttlp_tf->tf_graph_iid = NULL; /* to avoid double free in case of error in tf_get_iid() below */
                ttlp_arg->ttlp_tf->tf_graph_iid = tf_get_iid (ttlp_arg->ttlp_tf, ttlp_arg->ttlp_trig_graph_uri); }
	    inner_triple_clauses trig_group_end dot_opt {
		tf_commit (ttlp_arg->ttlp_tf);
		dk_free_tree (ttlp_arg->ttlp_trig_graph_uri);
		ttlp_arg->ttlp_trig_graph_uri = NULL; }
	;

opt_eq_lbra
	: _LBRA
	| _EQ _LBRA
	;

inner_triple_clauses
	: inner_triple_clause
	| inner_triple_clauses _DOT_WS inner_triple_clause
	;

inner_triple_clause
	: q_complete { dk_free_tree (ttlp_arg->ttlp_subj_uri);
		ttlp_arg->ttlp_subj_uri = ttlp_arg->ttlp_last_complete_uri;
		ttlp_arg->ttlp_last_complete_uri = NULL; }
		inner_predicate_object_list semicolon_opt
	| triple_clause_with_nonq_subj
	;

triple_clause_with_nonq_subj
	: VARIABLE { dk_free_tree (ttlp_arg->ttlp_subj_uri);
		ttlp_arg->ttlp_subj_uri = $1; }
	    predicate_object_list_or_garbage
	| blank { dk_free_tree (ttlp_arg->ttlp_subj_uri);
		ttlp_arg->ttlp_subj_uri = $1; }
	    predicate_object_list_or_garbage
	| literal_subject {
		TTLYYERROR_ACTION_COND (TTLP_SKIP_LITERAL_SUBJECTS, "Virtuoso does not support literal subjects");
		dk_free_tree (ttlp_arg->ttlp_subj_uri); ttlp_arg->ttlp_subj_uri = NULL; }
	    predicate_object_list_or_garbage
        | TTL_RECOVERABLE_ERROR { dk_free_tree (ttlp_arg->ttlp_subj_uri);
		ttlp_arg->ttlp_subj_uri = NULL; }
	    predicate_object_list_or_garbage
	| _GARBAGE_BEFORE_DOT_WS {}
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

inner_predicate_object_list
	: predicate_object_list
        | _LBRA
		{
		  TTLYYERROR_ACTION_COND (TTLP_VERB_MAY_BE_BLANK, "Sequence blank node (written as '{...}' formula) can not be used as a predicate"); }
		blank_block_formula
	;

predicate_object_list_or_garbage
	: predicate_object_list semicolon_opt
	| predicate_object_list semicolon_opt _GARBAGE_BEFORE_DOT_WS
	| _GARBAGE_BEFORE_DOT_WS
	;

predicate_object_list
	: verb_and_object_list
	| predicate_object_list _SEMI verb_and_object_list_or_garbage
        | _COMMA { ttlyyerror_action ("Missing object before comma"); }
        | _SEMI { ttlyyerror_action ("Missing predicate and object before semicolon"); }
        | _DOT_WS { ttlyyerror_action ("Missing predicate and object before dot"); }
        | error { ttlyyerror_action ("Predicate expected"); }
	;

verb_and_object_list_or_garbage
	: verb_and_object_list
	| verb_and_object_list _GARBAGE_BEFORE_DOT_WS
	| _GARBAGE_BEFORE_DOT_WS
	;

verb_and_object_list
	: verb
		{ dk_free_tree (ttlp_arg->ttlp_pred_uri); ttlp_arg->ttlp_pred_uri = $1; }
	    object_list_or_garbage
	| rev_verb
		{ dk_free_tree (ttlp_arg->ttlp_pred_uri); ttlp_arg->ttlp_pred_uri = $1;
		  ttlp_arg->ttlp_pred_is_reverse = 1; }
	    object_list_or_garbage	{ ttlp_arg->ttlp_pred_is_reverse = 0; }
        | TTL_RECOVERABLE_ERROR {
		  dk_free_tree (ttlp_arg->ttlp_pred_uri);
		  ttlp_arg->ttlp_pred_uri = NULL; }
	    object_list_or_garbage
	;

object_list_or_garbage 
	: object_list
	| _GARBAGE_BEFORE_DOT_WS
	;

object_list
	: object	{; /* triple is made by object */ }
	| object_list _COMMA object_or_garbage	{; /* triple is made by object */ }
        | _COMMA { ttlyyerror_action ("Missing object before comma"); }
        | _SEMI { ttlyyerror_action ("Missing object before semicolon"); }
        | _DOT_WS { ttlyyerror_action ("Missing object before dot"); }
        | error { ttlyyerror_action ("Object expected"); }
	;

verb
	: q_complete	{ $$ = ttlp_arg->ttlp_last_complete_uri; ttlp_arg->ttlp_last_complete_uri = NULL; }
	| VARIABLE	{ $$ = $1; }
	| _AT_a_L	{ $$ = uname_rdf_ns_uri_type; }
	| _EQ		{ $$ = box_dv_uname_string ("http://www.w3.org/2002/07/owl#sameAs"); }
        | _EQ_GT	{ $$ = box_dv_uname_string ("http://www.w3.org/2000/10/swap/log#implies"); }
	| _LSQBRA_RSQBRA
		{
		  TTLYYERROR_ACTION_COND (TTLP_VERB_MAY_BE_BLANK, "Blank node (written as '[]') can not be used as a predicate");
		  $$ = tf_bnode_iid (ttlp_arg->ttlp_tf, NULL); }
	| BLANK_NODE_LABEL
		{
		  TTLYYERROR_ACTION_COND (TTLP_VERB_MAY_BE_BLANK, "Blank node (written as '_:...' label) can not be used as a predicate");
                  if (ttlp_arg->ttlp_formula_iid)
		    $$ = tf_formula_bnode_iid (ttlp_arg, $1);
                  else
		    $$ = tf_bnode_iid (ttlp_arg->ttlp_tf, $1);
		}
        | _LSQBRA
		{
		  TTLYYERROR_ACTION_COND (TTLP_VERB_MAY_BE_BLANK, "Blank node (written as '[...]' block) can not be used as a predicate"); }
		blank_block_subj { $$ = $3; }
        | _LPAR
		{
		  TTLYYERROR_ACTION_COND (TTLP_VERB_MAY_BE_BLANK, "Sequence blank node (written as list in parenthesis) can not be used as a predicate"); }
		blank_block_seq { $$ = $3; }
	;

rev_verb
	: _AT_is_L q_complete _AT_of_L 	{ $$ = ttlp_arg->ttlp_last_complete_uri; ttlp_arg->ttlp_last_complete_uri = NULL; }
	| _AT_is_L VARIABLE _AT_of_L 	{ $$ = $2; }
        | _LT_EQ	{ $$ = box_dv_uname_string ("http://www.w3.org/2000/10/swap/log#implies"); /* Note this 'double reversed' meaning :) */ }
	;

literal_subject
	: true_L
	| false_L
	| TURTLE_INTEGER
	| TURTLE_DECIMAL
	| TURTLE_DOUBLE
	| TURTLE_STRING
	| TURTLE_STRING LANGTAG
	| TURTLE_STRING _CARET_CARET q_complete	{
			dk_free_tree (ttlp_arg->ttlp_last_complete_uri);
			ttlp_arg->ttlp_last_complete_uri = NULL; }
	;

object_or_garbage
	: object
	| _GARBAGE_BEFORE_DOT_WS
	;

object
	: q_complete {
		  dk_free_tree (ttlp_arg->ttlp_obj);
		ttlp_arg->ttlp_obj = ttlp_arg->ttlp_last_complete_uri;
		ttlp_arg->ttlp_last_complete_uri = NULL;
		ttlp_triple_and_inf (ttlp_arg, ttlp_arg->ttlp_obj); }
	| VARIABLE {
		  dk_free_tree (ttlp_arg->ttlp_obj);
		  ttlp_arg->ttlp_obj = $1;
		ttlp_triple_and_inf (ttlp_arg, $1); }
	| blank	{
		  dk_free_tree (ttlp_arg->ttlp_obj);
		  ttlp_arg->ttlp_obj = $1;
		ttlp_triple_and_inf (ttlp_arg, $1); }
	| true_L {
		ttlp_triple_l_and_inf (ttlp_arg, (caddr_t)((ptrlong)1), uname_xmlschema_ns_uri_hash_boolean, NULL); }
	| false_L {
		ttlp_triple_l_and_inf (ttlp_arg, (caddr_t)((ptrlong)0), uname_xmlschema_ns_uri_hash_boolean, NULL); }
	| TURTLE_INTEGER {
		  dk_free_tree (ttlp_arg->ttlp_obj);
		  ttlp_arg->ttlp_obj = $1;
		ttlp_triple_l_and_inf (ttlp_arg, $1, uname_xmlschema_ns_uri_hash_integer, NULL); }
	| TURTLE_DECIMAL {
		  dk_free_tree (ttlp_arg->ttlp_obj);
		  ttlp_arg->ttlp_obj = $1;
		ttlp_triple_l_and_inf (ttlp_arg, $1, uname_xmlschema_ns_uri_hash_decimal, NULL); }
	| TURTLE_DOUBLE {
		  dk_free_tree (ttlp_arg->ttlp_obj);
		  ttlp_arg->ttlp_obj = $1;
		ttlp_triple_l_and_inf (ttlp_arg, $1, uname_xmlschema_ns_uri_hash_double, NULL);	}
	| TURTLE_STRING	{
		  dk_free_tree (ttlp_arg->ttlp_obj);
		  ttlp_arg->ttlp_obj = $1;
		ttlp_triple_l_and_inf (ttlp_arg, $1, NULL, NULL); }
	| TURTLE_STRING LANGTAG	{
		  dk_free_tree (ttlp_arg->ttlp_obj);
		  ttlp_arg->ttlp_obj = $1;
		  dk_free_tree (ttlp_arg->ttlp_obj_lang);
		  ttlp_arg->ttlp_obj_lang = $2;
		ttlp_triple_l_and_inf (ttlp_arg, $1, NULL, $2);	}
	| TURTLE_STRING _CARET_CARET q_complete {
		  dk_free_tree (ttlp_arg->ttlp_obj);
		  ttlp_arg->ttlp_obj = $1;
		  dk_free_tree (ttlp_arg->ttlp_obj_type);
		ttlp_arg->ttlp_obj_type = ttlp_arg->ttlp_last_complete_uri;
		ttlp_arg->ttlp_last_complete_uri = NULL;
		ttlp_triple_l_and_inf (ttlp_arg, ttlp_arg->ttlp_obj, ttlp_arg->ttlp_obj_type, NULL);	}
        | TTL_RECOVERABLE_ERROR { }
	| TURTLE_STRING _CARET_CARET TTL_RECOVERABLE_ERROR { }
        | TTL_RECOVERABLE_ERROR _CARET_CARET q_complete { }
        | TTL_RECOVERABLE_ERROR _CARET_CARET TTL_RECOVERABLE_ERROR { }
	;

blank
	: BLANK_NODE_LABEL
		{
                  if (ttlp_arg->ttlp_formula_iid)
		    $$ = tf_formula_bnode_iid (ttlp_arg, $1);
                  else
		    $$ = tf_bnode_iid (ttlp_arg->ttlp_tf, $1);
		}
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
	  blank_block_subj_tail { $$ = $2; }
	;

blank_block_subj_tail
        : predicate_object_list semicolon_opt _RSQBRA
		{ $$ = ttlp_arg->ttlp_subj_uri;
		  dk_free_tree (ttlp_arg->ttlp_pred_uri);
		  ttlp_arg->ttlp_pred_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		  ttlp_arg->ttlp_subj_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
                  ttlp_arg->ttlp_pred_is_reverse = (ptrlong)dk_set_pop (&(ttlp_arg->ttlp_saved_uris)); }
	| _RSQBRA
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
                  ttlp_triple_and_inf (ttlp_arg, uname_rdf_ns_uri_nil);
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
		inner_triple_clauses _RBRA
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
                  ttlp_triple_and_inf (ttlp_arg, next_bnode);
		  ttlp_arg->ttlp_pred_uri = first_pred;
		  dk_free_tree (ttlp_arg->ttlp_subj_uri);
                  ttlp_arg->ttlp_subj_uri = next_bnode; }
	;

q_complete
	: Q_IRI_REF
		{
                  if (NULL != ttlp_arg->ttlp_last_complete_uri)
		    ttlyyerror_action ("Internal error: proven memory leak");
		  ttlp_arg->ttlp_last_complete_uri = $1;
		  TTLP_URI_RESOLVE_IF_NEEDED(ttlp_arg->ttlp_last_complete_uri);
		 }
	| QNAME
		{
                  if (NULL != ttlp_arg->ttlp_last_complete_uri)
		    ttlyyerror_action ("Internal error: proven memory leak");
		  ttlp_arg->ttlp_last_complete_uri = $1;
		  ttlp_arg->ttlp_last_complete_uri = ttlp_expand_qname_prefix (ttlp_arg, ttlp_arg->ttlp_last_complete_uri);
		  TTLP_URI_RESOLVE_IF_NEEDED(ttlp_arg->ttlp_last_complete_uri);
		}
	| QNAME_NS
		{
                  if (NULL != ttlp_arg->ttlp_last_complete_uri)
		    ttlyyerror_action ("Internal error: proven memory leak");
		  ttlp_arg->ttlp_last_complete_uri = $1;
		  ttlp_arg->ttlp_last_complete_uri = ttlp_expand_qname_prefix (ttlp_arg, ttlp_arg->ttlp_last_complete_uri);
		  TTLP_URI_RESOLVE_IF_NEEDED(ttlp_arg->ttlp_last_complete_uri);
		}
	;


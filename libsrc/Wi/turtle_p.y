/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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

%pure_parser
%parse-param {ttlp_t * ttlp_arg}
%parse-param {yyscan_t yyscanner}
%lex-param {ttlp_t * ttlp_arg}
%lex-param {yyscan_t yyscanner}
%expect 5

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

#define YY_FATAL_ERROR(err) ttlyyerror_action(err)

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
  ptrlong lexlineno;
}

%token __TTL_PUNCT_BEGIN	/* Delimiting value for syntax highlighting */

%token _CARET_WS	/*:: PUNCT("^"), TTL, LAST("^ "), LAST("^\n") ::*/
%token _CARET_NOWS	/*:: PUNCT("^"), TTL, LAST1("^x") ::*/
%token _CARET_CARET	/*:: PUNCT_TTL_LAST("^^") ::*/
%token _COLON		/*:: PUNCT_TTL_LAST(":") ::*/
%token _COMMA		/*:: PUNCT_TTL_LAST(",") ::*/
%token _DOT_WS		/*:: PUNCT("."), TTL, LAST(". "), LAST(".\n"), LAST(".") ::*/
%token _LBRA		/*:: PUNCT_TTL_LAST("{") ::*/
%token _LBRA_TOP_TRIG	/*:: PUNCT_TRIG_LAST("{") ::*/
%token _LPAR		/*:: PUNCT_TTL_LAST("(") ::*/
%token _LSQBRA		/*:: PUNCT_TTL_LAST("[") ::*/
%token _LSQBRA_RSQBRA	/*:: PUNCT_TTL_LAST("[]") ::*/
%token _RBRA		/*:: PUNCT_TTL_LAST("{ }") ::*/
%token _RPAR		/*:: PUNCT_TTL_LAST("( )") ::*/
%token _RSQBRA		/*:: PUNCT_TTL_LAST("[ ]") ::*/
%token _SEMI		/*:: PUNCT_TTL_LAST(";") ::*/
%token _EQ		/*:: PUNCT_TTL_LAST("=") ::*/
%token _EQ_TOP_TRIG	/*:: PUNCT_TRIG_LAST("=") ::*/
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
%token _MINUS_INF_L	/*:: PUNCT_TTL_LAST("-INF") ::*/
%token BASE_L		/*:: PUNCT("BASE"), TTL, LAST("BASE "), LAST("Base "), LAST("base ") ::*/
%token INF_L		/*:: PUNCT_TTL_LAST("INF") ::*/
%token NaN_L		/*:: PUNCT_TTL_LAST("NaN") ::*/
%token PREFIX_L		/*:: PUNCT("PREFIX"), TTL, LAST("PREFIX "), LAST("Prefix "), LAST("prefix ") ::*/
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
%token <box> BLANK_NODE_LABEL_NQ /*:: LITERAL("%s"), TTL, LAST("_:_f.Rag.2"), LAST("_:_f.Rag:ment.2:") ::*/
%token <box> BLANK_NODE_LABEL_TTL /*:: LITERAL("%s"), TTL, LAST("_:_f.Rag.2"), LAST("_:_f.Rag:m%ent%20of%20TTL.2:") ::*/
%token <box> Q_IRI_REF	/*:: LITERAL("%s"), TTL, LAST("<something>"), LAST("<http://www.example.com/sample#frag>") ::*/

%token _GARBAGE_BEFORE_DOT_WS	/* Syntax error that may be (inaccurately) recovered by skipping to dot and space */
%token TTL_RECOVERABLE_ERROR	/* Token that marks error so the triple should be discarded */
%token __TTL_NONPUNCT_END	/* Delimiting value for syntax highlighting */

%type<box> blank
%type<box> blank_block_subj
%type<box> blank_block_subj_tail
%type<box> blank_block_seq
%type<box> blank_block_formula
%type<box> blank_node_label
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
	| _AT_keywords_L { ttlp_arg->ttlp_special_qnames = ~0; } _DOT_WS
	| _AT_keywords_L error { ttlyyerror_action ("Comma-delimited list of names expected after @keywords"); }
	| base_clause dot_opt
	| prefix_clause dot_opt
	| q_complete { dk_free_tree (ttlp_arg->ttlp_subj_uri);
		ttlp_arg->ttlp_subj_uri = ttlp_arg->ttlp_last_complete_uri;
		ttlp_arg->ttlp_last_complete_uri = NULL; }
		trig_block_or_predicate_object_list
	| top_triple_clause_with_nonq_subj
	| _LBRA_TOP_TRIG {
		triple_feed_t *tf = ttlp_arg->ttlp_tf;
		ttlp_enter_trig_group (ttlp_arg);
		TF_CHANGE_GRAPH_TO_DEFAULT (tf); }
	    base_or_prefix_or_inner_triple_clauses _RBRA dot_opt {
		ttlp_triple_process_prepared (ttlp_arg);
		ttlp_leave_trig_group (ttlp_arg); }
	| error { ttlyyerror_action ("Only a triple or a special clause (like prefix declaration) is allowed here"); }
	;

base_clause
	: base_kwd Q_IRI_REF {
		  if (ttlp_arg->ttlp_base_uri != ttlp_arg->ttlp_base_uri_saved)
		    dk_free_box (ttlp_arg->ttlp_base_uri);
		  ttlp_arg->ttlp_base_uri = $2;
		  TF_CHANGE_BASE_AND_DEFAULT_GRAPH(ttlp_arg->ttlp_tf, box_copy ($2)); }
	| base_kwd error { ttlyyerror_action ("Only an IRI reference is allowed after @base keyword"); }
	;

base_kwd
	: _AT_base_L
	| BASE_L
	;

prefix_clause
	: prefix_kwd QNAME_NS Q_IRI_REF {
		id_hash_t **local_hash_ptr = (ttlp_arg->ttlp_in_trig_graph ?
		  &(ttlp_arg->ttlp_inner_namespaces_prefix2iri) :
		  &(ttlp_arg->ttlp_namespaces_prefix2iri) );
		caddr_t *old_uri_ptr;
		caddr_t prefix = $2 ;
		caddr_t ns = $3;
		if (NULL != local_hash_ptr[0])
		  old_uri_ptr = (caddr_t *)id_hash_get (local_hash_ptr[0], (caddr_t)(&prefix));
		else
		  {
		    local_hash_ptr[0] = (id_hash_t *)box_dv_dict_hashtable (31);
		    old_uri_ptr = NULL;
		  }
		if (NULL != old_uri_ptr)
		  {
		    /*
		    int err = strcmp (old_uri_ptr[0], ns);
		    dk_free_box (prefix);
		    dk_free_box (ns);
		    if (err)
		      ttlyyerror_action ("Namespace prefix is re-used for a different namespace IRI");
		    */
		    dk_free_box (prefix);
		    dk_free_box (old_uri_ptr[0]);
		    old_uri_ptr[0] = ns;
		  }
		else
		  id_hash_set (local_hash_ptr[0], (caddr_t)(&prefix), (caddr_t)(&ns));
		ttlp_arg->ttlp_last_q_save = NULL; }
	| prefix_kwd QNAME_NS error { dk_free_box ($2); ttlp_arg->ttlp_last_q_save = NULL; ttlyyerror_action ("A namespace IRI is expected after prefix in namepace declaration"); }
	| prefix_kwd _COLON Q_IRI_REF	{
		if (ttlp_arg->ttlp_default_ns_uri != ttlp_arg->ttlp_default_ns_uri_saved)
		  dk_free_box (ttlp_arg->ttlp_default_ns_uri);
		ttlp_arg->ttlp_default_ns_uri = $3; }
	| prefix_kwd _COLON error { ttlyyerror_action ("A namespace IRI is expected in declaration of default namespace"); }
	| prefix_kwd error { ttlyyerror_action ("A namespace prefix or ':' is expected after prefix keyword in namepace declaration"); }
	;

prefix_kwd
	: _AT_prefix_L
	| PREFIX_L
	;

dot_opt
	: /* empty */
	| _DOT_WS
	;

trig_block_or_predicate_object_list
	: predicate_object_list_or_garbage _DOT_WS		{ ttlp_triple_process_prepared (ttlp_arg); }
	| opt_eq_lbra {
		triple_feed_t *tf = ttlp_arg->ttlp_tf;
		TTLYYERROR_ACTION_COND (TTLP_ALLOW_TRIG, "Left curly brace can appear here only if the source text is TriG");
		ttlp_enter_trig_group (ttlp_arg);
		TF_CHANGE_GRAPH (tf, ttlp_arg->ttlp_subj_uri); }
	    base_or_prefix_or_inner_triple_clauses _RBRA dot_opt {
		triple_feed_t *tf = ttlp_arg->ttlp_tf;
		ttlp_triple_process_prepared (ttlp_arg);
		ttlp_leave_trig_group (ttlp_arg);
		TF_CHANGE_GRAPH_TO_DEFAULT (tf); }
	;

opt_eq_lbra
	: _LBRA_TOP_TRIG
	| _EQ_TOP_TRIG _LBRA_TOP_TRIG
	| _EQ_TOP_TRIG error { ttlyyerror_action ("No '{' after an equality sign in TriG"); }
	;

base_or_prefix_or_inner_triple_clauses
	: base_or_prefix_or_inner_triple_clauses_nodot
	| base_or_prefix_or_inner_triple_clauses_dot
	| base_or_prefix_or_inner_triple_clauses_nodot error { ttlyyerror_action ("A clause of a TriG graph should be ended with '.' or '}'"); }
	| base_or_prefix_or_inner_triple_clauses_dot error { ttlyyerror_action ("Syntax error after '.' in a TriG graph"); }
	| error		{ ttlyyerror_action ("@base, @prefix or triple clauses are expected after opening '{' of a TriG graph"); }
	;

base_or_prefix_or_inner_triple_clauses_nodot
	: base_or_prefix_or_inner_triple_clause
	| base_or_prefix_or_inner_triple_clauses_dot base_or_prefix_or_inner_triple_clause
	;

base_or_prefix_or_inner_triple_clauses_dot
	: base_or_prefix_or_inner_triple_clause _DOT_WS		{ ttlp_triple_process_prepared (ttlp_arg); }
	| base_or_prefix_or_inner_triple_clauses_dot base_or_prefix_or_inner_triple_clause _DOT_WS		{ ttlp_triple_process_prepared (ttlp_arg); }
	;

base_or_prefix_or_inner_triple_clause
	: base_clause
	| prefix_clause
	| inner_triple_clause
	;

inner_triple_clauses
	: inner_triple_clauses_nodot
	| inner_triple_clauses_dot
	;

inner_triple_clauses_nodot
	: inner_triple_clause
	| inner_triple_clauses_dot inner_triple_clause
	;

inner_triple_clauses_dot
	: inner_triple_clause _DOT_WS		{ ttlp_triple_process_prepared (ttlp_arg); }
	| inner_triple_clauses_dot inner_triple_clause _DOT_WS		{ ttlp_triple_process_prepared (ttlp_arg); }
	;

inner_triple_clause
	: q_complete { dk_free_tree (ttlp_arg->ttlp_subj_uri);
		ttlp_arg->ttlp_subj_uri = ttlp_arg->ttlp_last_complete_uri;
		ttlp_arg->ttlp_last_complete_uri = NULL; }
	    inner_predicate_object_list
	| triple_clause_with_nonq_subj
	;

triple_clause_with_nonq_subj
	: VARIABLE { dk_free_tree (ttlp_arg->ttlp_subj_uri);
		ttlp_arg->ttlp_subj_uri = $1; }
	    predicate_object_list_or_garbage
	| blank { dk_free_tree (ttlp_arg->ttlp_subj_uri);
		ttlp_arg->ttlp_subj_uri = $1; }
	    predicate_object_list_or_garbage_opt
	| literal_subject {
		TTLYYERROR_ACTION_COND (TTLP_SKIP_LITERAL_SUBJECTS, "Virtuoso does not support literal subjects");
		dk_free_tree (ttlp_arg->ttlp_subj_uri); ttlp_arg->ttlp_subj_uri = NULL; }
	    predicate_object_list_or_garbage
	| TTL_RECOVERABLE_ERROR { dk_free_tree (ttlp_arg->ttlp_subj_uri);
		ttlp_arg->ttlp_subj_uri = NULL; }
	    predicate_object_list_or_garbage
	| _GARBAGE_BEFORE_DOT_WS
	;

top_triple_clause_with_nonq_subj
	: VARIABLE { dk_free_tree (ttlp_arg->ttlp_subj_uri);
		ttlp_arg->ttlp_subj_uri = $1; }
	    predicate_object_list_or_garbage _DOT_WS		{ ttlp_triple_process_prepared (ttlp_arg); }
	| blank { dk_free_tree (ttlp_arg->ttlp_subj_uri);
		ttlp_arg->ttlp_subj_uri = $1; }
	    top_blank_predicate_object_list_or_garbage_with_dot
	| literal_subject {
		TTLYYERROR_ACTION_COND (TTLP_SKIP_LITERAL_SUBJECTS, "Virtuoso does not support literal subjects");
		dk_free_tree (ttlp_arg->ttlp_subj_uri); ttlp_arg->ttlp_subj_uri = NULL; }
	    predicate_object_list_or_garbage _DOT_WS		{ ttlp_triple_process_prepared (ttlp_arg); }
	| TTL_RECOVERABLE_ERROR { dk_free_tree (ttlp_arg->ttlp_subj_uri);
		ttlp_arg->ttlp_subj_uri = NULL; }
	    predicate_object_list_or_garbage _DOT_WS		{ ttlp_triple_process_prepared (ttlp_arg); }
	| _GARBAGE_BEFORE_DOT_WS _DOT_WS
	;

keyword_list
	: keyword	{ ttlp_arg->ttlp_special_qnames &= ~($1); }
	| keyword_list _COMMA keyword	{ ttlp_arg->ttlp_special_qnames &= ~($3); }
	| keyword_list _COMMA	{ ttlyyerror_action ("Keyword expected after comma in keyword list"); }
	;

keyword
	: QNAME		{ $$ = ttlp_bit_of_special_qname ($1); }
	| _AT_a_L	{ $$ = TTLP_ALLOW_QNAME_A; }
	| _AT_has_L	{ $$ = TTLP_ALLOW_QNAME_HAS; }
	| _AT_is_L	{ $$ = TTLP_ALLOW_QNAME_IS; }
	| _AT_of_L	{ $$ = TTLP_ALLOW_QNAME_OF; }
	| _AT_this_L	{ $$ = TTLP_ALLOW_QNAME_THIS; }
	;

inner_predicate_object_list
	: predicate_object_list
	| _LBRA
		{
		  TTLYYERROR_ACTION_COND (TTLP_VERB_MAY_BE_BLANK, "Sequence blank node (written as '{...}' formula) can not be used as a predicate"); }
	    blank_block_formula
	;

top_blank_predicate_object_list_or_garbage_with_dot
	: top_blank_predicate_object_list _DOT_WS		{ ttlp_triple_process_prepared (ttlp_arg); }
	| top_blank_predicate_object_list _GARBAGE_BEFORE_DOT_WS _DOT_WS		{ ttlp_triple_forget_prepared (ttlp_arg); }
	| _DOT_WS /* This was before Turtle 1.1: { TTLYYERROR_ACTION_COND (TTLP_ACCEPT_DIRTY_SYNTAX, "Missing predicate and object between top-level blank node subject and a dot"); } */
	| _GARBAGE_BEFORE_DOT_WS _DOT_WS
	| _LBRA_TOP_TRIG { ttlyyerror_action ("Virtuoso does not support blank nodes as graph identifiers inTriG, graphs are identified only by IRIs"); }
	;

predicate_object_list_or_garbage_opt
	: /* empty */
	| predicate_object_list_nosemi
	| predicate_object_list_semi
	| predicate_object_list_nosemi _GARBAGE_BEFORE_DOT_WS
	| predicate_object_list_semi _GARBAGE_BEFORE_DOT_WS
	| _GARBAGE_BEFORE_DOT_WS
	;

predicate_object_list_or_garbage
	: predicate_object_list_nosemi
	| predicate_object_list_semi
	| predicate_object_list_nosemi _GARBAGE_BEFORE_DOT_WS
	| predicate_object_list_semi _GARBAGE_BEFORE_DOT_WS
	| _GARBAGE_BEFORE_DOT_WS
	;

top_blank_predicate_object_list
	: predicate_object_list_nosemi
	| predicate_object_list_semi
	| _COMMA { ttlyyerror_action ("Missing predicate and object object between top-level blank node and a comma"); }
	| _SEMI { ttlyyerror_action ("Missing predicate and object between top-level blank node and a semicolon"); }
	| error { ttlyyerror_action ("Predicate expected after top-level blank node"); }
	;

predicate_object_list
	: predicate_object_list_nosemi
	| predicate_object_list_semi
	| _COMMA { ttlyyerror_action ("Missing object before comma"); }
	| _SEMI { ttlyyerror_action ("Missing predicate and object before semicolon"); }
	| _DOT_WS { ttlyyerror_action ("Missing predicate and object before dot"); }
	| error { ttlyyerror_action ("Predicate expected"); }
	;

predicate_object_list_nosemi
	: verb_and_object_list
	| predicate_object_list_semi verb_and_object_list_or_garbage
	;

predicate_object_list_semi
	: verb_and_object_list _SEMI		{ ttlp_triple_process_prepared (ttlp_arg); }
	| predicate_object_list_semi verb_and_object_list_or_garbage _SEMI		{ ttlp_triple_process_prepared (ttlp_arg); }
	;

verb_and_object_list_or_garbage
	: verb_and_object_list
	| verb_and_object_list _GARBAGE_BEFORE_DOT_WS		{ ttlp_triple_forget_prepared (ttlp_arg); }
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
	| _GARBAGE_BEFORE_DOT_WS		{ ttlp_triple_forget_prepared (ttlp_arg); }
	;

object_list
	: object_list_nocomma
	| object_list_comma
	| object_list _COMMA		{ ttlp_triple_process_prepared (ttlp_arg); }
		object_or_garbage
	| _COMMA { ttlyyerror_action ("Missing object before comma"); }
	| _SEMI { ttlyyerror_action ("Missing object before semicolon"); }
	| _DOT_WS { ttlyyerror_action ("Missing object before dot"); }
	| error { ttlyyerror_action ("Object expected after predicate"); }
	;

object_list_nocomma
	: object
	| object_list_comma object
	| object_list_comma error { ttlyyerror_action ("Object expected after comma"); }
	;

object_list_comma
	: object _COMMA					{ ttlp_triple_process_prepared (ttlp_arg); }
	| object_list_comma object _COMMA		{ ttlp_triple_process_prepared (ttlp_arg); }
	;

verb
	: q_complete	{ $$ = ttlp_arg->ttlp_last_complete_uri; ttlp_arg->ttlp_last_complete_uri = NULL; }
	| VARIABLE	{ $$ = $1; }
	| _AT_a_L	{
		  if (TTLP_ALLOW_QNAME_A & ttlp_arg->ttlp_special_qnames)
		    ttlyyerror_action ("@a keyword is used but not specified in @keywords");
		  $$ = uname_rdf_ns_uri_type; }
	| _EQ		{ $$ = box_dv_uname_string ("http://www.w3.org/2002/07/owl#sameAs"); }
	| _EQ_GT	{ $$ = box_dv_uname_string ("http://www.w3.org/2000/10/swap/log#implies"); }
	| _AT_has_L q_complete	{ $$ = ttlp_arg->ttlp_last_complete_uri; ttlp_arg->ttlp_last_complete_uri = NULL; }
	| _AT_has_L VARIABLE	{ $$ = $2; }
	| _AT_has_L  error { ttlyyerror_action ("Only predicate is allowed after \"has\" keyword"); }
	| _LSQBRA_RSQBRA
		{
		  TTLYYERROR_ACTION_COND (TTLP_VERB_MAY_BE_BLANK, "Blank node (written as '[]') can not be used as a predicate");
		  $$ = tf_bnode_iid (ttlp_arg->ttlp_tf, NULL);
		  if (TTLP_DEBUG_BNODES & ttlp_arg->ttlp_flags)
		    ttlp_triples_for_bnodes_debug (ttlp_arg, $$, ttlp_arg->ttlp_lexlineno, NULL);
		}
	| blank_node_label
		{
		  caddr_t label_copy_for_debug = NULL;
		  TTLYYERROR_ACTION_COND (TTLP_VERB_MAY_BE_BLANK, "Blank node (written as '_:...' label) can not be used as a predicate");
		  if (TTLP_DEBUG_BNODES & ttlp_arg->ttlp_flags)
		    label_copy_for_debug = box_copy ($1);
		  if (ttlp_arg->ttlp_formula_iid)
		    $$ = tf_formula_bnode_iid (ttlp_arg, $1);
		  else
		    $$ = tf_bnode_iid (ttlp_arg->ttlp_tf, $1);
		  if (TTLP_DEBUG_BNODES & ttlp_arg->ttlp_flags)
		    ttlp_triples_for_bnodes_debug (ttlp_arg, $$, ttlp_arg->ttlp_lexlineno, label_copy_for_debug);
		}
	| _LSQBRA
		{
		  TTLYYERROR_ACTION_COND (TTLP_VERB_MAY_BE_BLANK, "Blank node (written as '[...]' block) can not be used as a predicate");
		  if (TTLP_DEBUG_BNODES & ttlp_arg->ttlp_flags)
		    $<lexlineno>$ = ttlp_arg->ttlp_lexlineno;
		}
	    blank_block_subj
		{
		  $$ = $3;
		  if (TTLP_DEBUG_BNODES & ttlp_arg->ttlp_flags)
		    ttlp_triples_for_bnodes_debug (ttlp_arg, $$, $<lexlineno>2, NULL);
		}
	| _LPAR
		{
		  TTLYYERROR_ACTION_COND (TTLP_VERB_MAY_BE_BLANK, "Sequence blank node (written as list in parenthesis) can not be used as a predicate");
		  if (TTLP_DEBUG_BNODES & ttlp_arg->ttlp_flags)
		    $<lexlineno>$ = ttlp_arg->ttlp_lexlineno;
		}
	    blank_block_seq
		{
		  $$ = $3;
		  if (TTLP_DEBUG_BNODES & ttlp_arg->ttlp_flags)
		    ttlp_triples_for_bnodes_debug (ttlp_arg, $$, $<lexlineno>2, NULL);
		}
	;

rev_verb
	: _AT_is_L q_complete _AT_of_L	{ $$ = ttlp_arg->ttlp_last_complete_uri; ttlp_arg->ttlp_last_complete_uri = NULL; }
	| _AT_is_L q_complete error	{ ttlyyerror_action ("Keyword @of is expected after @is and QName of a reverse predicate notation"); }
	| _AT_is_L VARIABLE _AT_of_L	{ $$ = $2; }
	| _AT_is_L VARIABLE error	{ ttlyyerror_action ("Keyword @of is expected after @is and variable name of a reverse predicate notation"); }
	| _LT_EQ	{ $$ = box_dv_uname_string ("http://www.w3.org/2000/10/swap/log#implies"); /* Note this 'double reversed' meaning :) */ }
	;

literal_subject
	: true_L
	| false_L
	| TURTLE_INTEGER	{ dk_free_tree ($1); }
	| TURTLE_DECIMAL	{ dk_free_tree ($1); }
	| TURTLE_DOUBLE		{ dk_free_tree ($1); }
	| TURTLE_STRING		{ dk_free_tree ($1); }
	| TURTLE_STRING LANGTAG	{ dk_free_tree ($1); dk_free_tree ($2); }
	| TURTLE_STRING _CARET_CARET q_complete	{
			dk_free_tree ($1);
			dk_free_tree (ttlp_arg->ttlp_last_complete_uri);
			ttlp_arg->ttlp_last_complete_uri = NULL; }
	| TURTLE_STRING _CARET_CARET error	{ dk_free_tree ($1); ttlyyerror_action ("Syntax error in datatype of a subject literal"); }
	;

object_or_garbage
	: object
	| _GARBAGE_BEFORE_DOT_WS
	| error { ttlyyerror_action ("Object is expected"); }
	;

object
	: q_complete {
		ttlp_triple_and_inf_prepare (ttlp_arg, ttlp_arg->ttlp_last_complete_uri);
		ttlp_arg->ttlp_last_complete_uri = NULL; }
	| VARIABLE {
		ttlp_triple_and_inf_prepare (ttlp_arg, $1); }
	| blank	{
		ttlp_triple_and_inf_prepare (ttlp_arg, $1); }
	| true_L {
		ttlp_triple_l_and_inf_prepare (ttlp_arg, (caddr_t)((ptrlong)1), uname_xmlschema_ns_uri_hash_boolean, NULL); }
	| false_L {
		ttlp_triple_l_and_inf_prepare (ttlp_arg, (caddr_t)((ptrlong)0), uname_xmlschema_ns_uri_hash_boolean, NULL); }
	| TURTLE_INTEGER {
		ttlp_triple_l_and_inf_prepare (ttlp_arg, $1, uname_xmlschema_ns_uri_hash_integer, NULL); }
	| TURTLE_DECIMAL {
		ttlp_triple_l_and_inf_prepare (ttlp_arg, $1, uname_xmlschema_ns_uri_hash_decimal, NULL); }
	| TURTLE_DOUBLE {
		ttlp_triple_l_and_inf_prepare (ttlp_arg, $1, uname_xmlschema_ns_uri_hash_double, NULL);	}
	| NaN_L {
	  	double myZERO = 0.0;
		double myNAN_d = 0.0/myZERO;
		ttlp_triple_l_and_inf_prepare (ttlp_arg, box_double (myNAN_d), uname_xmlschema_ns_uri_hash_double, NULL);	}
	| INF_L {
	  	double myZERO = 0.0;
		double myPOSINF_d = 1.0/myZERO;
		ttlp_triple_l_and_inf_prepare (ttlp_arg, box_double (myPOSINF_d), uname_xmlschema_ns_uri_hash_double, NULL);	}
	| _MINUS_INF_L {
	  	double myZERO = 0.0;
		double myNEGINF_d = -1.0/myZERO;
		ttlp_triple_l_and_inf_prepare (ttlp_arg, box_double (myNEGINF_d), uname_xmlschema_ns_uri_hash_double, NULL);	}
	| TURTLE_STRING	{
		ttlp_triple_l_and_inf_prepare (ttlp_arg, $1, NULL, NULL); }
	| TURTLE_STRING LANGTAG	{
		ttlp_triple_l_and_inf_prepare (ttlp_arg, $1, NULL, $2);	}
	| TURTLE_STRING _CARET_CARET q_complete {
		ttlp_triple_l_and_inf_prepare (ttlp_arg, $1, ttlp_arg->ttlp_last_complete_uri, NULL);
		ttlp_arg->ttlp_last_complete_uri = NULL;		}
	| TTL_RECOVERABLE_ERROR { }
	| TURTLE_STRING _CARET_CARET TTL_RECOVERABLE_ERROR {
		dk_free_tree (ttlp_arg->ttlp_obj);
		ttlp_arg->ttlp_obj = $1; }
	| TTL_RECOVERABLE_ERROR _CARET_CARET q_complete {
		dk_free_tree (ttlp_arg->ttlp_last_complete_uri);
		ttlp_arg->ttlp_last_complete_uri = NULL; }
	| TTL_RECOVERABLE_ERROR _CARET_CARET TTL_RECOVERABLE_ERROR { }
	| TURTLE_STRING	_CARET_CARET error {
		dk_free_tree (ttlp_arg->ttlp_obj);
		ttlp_arg->ttlp_obj = $1;
		ttlyyerror_action ("Syntax error in datatype of a subject literal"); }
	;

blank
	: blank_node_label
		{
		  caddr_t label_copy_for_debug = NULL;
		  if (TTLP_DEBUG_BNODES & ttlp_arg->ttlp_flags)
		    label_copy_for_debug = box_copy ($1);
		  if (ttlp_arg->ttlp_formula_iid)
		    $$ = tf_formula_bnode_iid (ttlp_arg, $1);
		  else
		    $$ = tf_bnode_iid (ttlp_arg->ttlp_tf, $1);
		  if (TTLP_DEBUG_BNODES & ttlp_arg->ttlp_flags)
		    ttlp_triples_for_bnodes_debug (ttlp_arg, $$, ttlp_arg->ttlp_lexlineno, label_copy_for_debug);
		}
	| _LSQBRA_RSQBRA
		{
		  $$ = tf_bnode_iid (ttlp_arg->ttlp_tf, NULL);
		  if (TTLP_DEBUG_BNODES & ttlp_arg->ttlp_flags)
		    ttlp_triples_for_bnodes_debug (ttlp_arg, $$, ttlp_arg->ttlp_lexlineno, NULL);
		}
	| _LSQBRA
		{
		  if (TTLP_DEBUG_BNODES & ttlp_arg->ttlp_flags)
		    $<lexlineno>$ = ttlp_arg->ttlp_lexlineno;
		}
	    blank_block_subj
		{
		  $$ = $3;
		  if (TTLP_DEBUG_BNODES & ttlp_arg->ttlp_flags)
		    ttlp_triples_for_bnodes_debug (ttlp_arg, $$, $<lexlineno>2, NULL);
		}
	| _LPAR
		{
		  if (TTLP_DEBUG_BNODES & ttlp_arg->ttlp_flags)
		    $<lexlineno>$ = ttlp_arg->ttlp_lexlineno;
		}
	    blank_block_seq
		{
		  $$ = $3;
		  if (TTLP_DEBUG_BNODES & ttlp_arg->ttlp_flags)
		    ttlp_triples_for_bnodes_debug (ttlp_arg, $$, $<lexlineno>2, NULL);
		}
	| _LBRA
		{
		  if (TTLP_DEBUG_BNODES & ttlp_arg->ttlp_flags)
		    $<lexlineno>$ = ttlp_arg->ttlp_lexlineno;
		}
	    blank_block_formula
		{
		  $$ = $3;
		  if (TTLP_DEBUG_BNODES & ttlp_arg->ttlp_flags)
		    ttlp_triples_for_bnodes_debug (ttlp_arg, $$, $<lexlineno>2, NULL);
		}
	;

blank_block_subj
	:
		{ dk_set_push (&(ttlp_arg->ttlp_saved_uris), (void *)(ptrlong)ttlp_arg->ttlp_pred_is_reverse);
		  dk_set_push (&(ttlp_arg->ttlp_saved_uris), ttlp_arg->ttlp_subj_uri);
		  dk_set_push (&(ttlp_arg->ttlp_saved_uris), ttlp_arg->ttlp_pred_uri);
		  ttlp_arg->ttlp_pred_is_reverse = 0;
		  ttlp_arg->ttlp_subj_uri = tf_bnode_iid (ttlp_arg->ttlp_tf, NULL);
		  ttlp_arg->ttlp_pred_uri = NULL; }
	  blank_block_subj_tail { $$ = $2; }
	;

blank_block_subj_tail
	: predicate_object_list bad_dot_opt_rsqbra
		{ $$ = ttlp_arg->ttlp_subj_uri;
		  dk_free_tree (ttlp_arg->ttlp_pred_uri);
		  ttlp_arg->ttlp_pred_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		  ttlp_arg->ttlp_subj_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		  ttlp_arg->ttlp_pred_is_reverse = (ptrlong)dk_set_pop (&(ttlp_arg->ttlp_saved_uris)); }
	| _RSQBRA
		{ ttlp_triple_process_prepared (ttlp_arg);
		  $$ = ttlp_arg->ttlp_subj_uri;
		  dk_free_tree (ttlp_arg->ttlp_pred_uri);
		  ttlp_arg->ttlp_pred_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		  ttlp_arg->ttlp_subj_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		  ttlp_arg->ttlp_pred_is_reverse = (ptrlong)dk_set_pop (&(ttlp_arg->ttlp_saved_uris)); }
	;

bad_dot_opt_rsqbra
	:	_RSQBRA		{ ttlp_triple_process_prepared (ttlp_arg); }
	|	_DOT_WS _RSQBRA	{
		  TTLYYERROR_ACTION_COND (TTLP_ACCEPT_DIRTY_SYNTAX, "The blank node block should contain only predicate-object between square brackets, trailing dot is not allowed");
		  ttlp_triple_process_prepared (ttlp_arg); }
	|	_DOT_WS error	{ ttlyyerror_action ("The blank node block should contain only predicate-object between square brackets, no dots are allowed"); }
	;

blank_block_seq
	:	{
		  dk_set_push (&(ttlp_arg->ttlp_saved_uris), (void *)(ptrlong)(ttlp_arg->ttlp_pred_is_reverse));
		  dk_set_push (&(ttlp_arg->ttlp_saved_uris), ttlp_arg->ttlp_subj_uri);
		  dk_set_push (&(ttlp_arg->ttlp_saved_uris), ttlp_arg->ttlp_pred_uri);
		  ttlp_arg->ttlp_pred_is_reverse = 0;
		  if (NULL == ttlp_arg->ttlp_unused_seq_bnodes)
		    ttlp_arg->ttlp_subj_uri = tf_bnode_iid (ttlp_arg->ttlp_tf, NULL);
		  else
		    ttlp_arg->ttlp_subj_uri = dk_set_pop (&(ttlp_arg->ttlp_unused_seq_bnodes));
		  dk_set_push (&(ttlp_arg->ttlp_saved_uris), box_copy_tree (ttlp_arg->ttlp_subj_uri)); /* copy of first node */
		  dk_set_push (&(ttlp_arg->ttlp_saved_uris), NULL); /* last incomplete node */
		  ttlp_arg->ttlp_pred_uri = uname_rdf_ns_uri_first; }
		items _RPAR {
		  caddr_t first_node;
		  dk_set_push (&(ttlp_arg->ttlp_unused_seq_bnodes), ttlp_arg->ttlp_subj_uri);
		  if (NULL == ttlp_arg->ttlp_saved_uris->data) /* empty list */
		    {
		      dk_set_pop (&(ttlp_arg->ttlp_saved_uris)); /* pop last incomplete node, it's NULL in this case */
		      dk_free_tree (dk_set_pop (&(ttlp_arg->ttlp_saved_uris))); /* pop copy of first node and delete */
		      first_node = uname_rdf_ns_uri_nil; }
		  else
		    {
		      ttlp_arg->ttlp_subj_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		      ttlp_arg->ttlp_pred_uri = uname_rdf_ns_uri_rest;
		      ttlp_triple_and_inf_now (ttlp_arg, uname_rdf_ns_uri_nil, 0);
		      dk_free_tree (ttlp_arg->ttlp_subj_uri);
		      first_node = dk_set_pop (&(ttlp_arg->ttlp_saved_uris)); }
		  ttlp_arg->ttlp_pred_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		  ttlp_arg->ttlp_subj_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		  ttlp_arg->ttlp_pred_is_reverse = (ptrlong)dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		  $$ = first_node; }
	;

items
	: /*empty*/	{}
	| items object {
		  caddr_t last_node;
		  ttlp_triple_process_prepared (ttlp_arg);
		  last_node = ttlp_arg->ttlp_subj_uri;
		  ttlp_arg->ttlp_subj_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		  dk_set_push (&(ttlp_arg->ttlp_saved_uris), last_node);
		  if (NULL != ttlp_arg->ttlp_subj_uri)
		    {
		      ttlp_arg->ttlp_pred_uri = uname_rdf_ns_uri_rest;
		      ttlp_triple_and_inf_now (ttlp_arg, last_node, 0);
		      dk_free_tree (ttlp_arg->ttlp_subj_uri);
		      ttlp_arg->ttlp_subj_uri = NULL; }
		  if (NULL == ttlp_arg->ttlp_unused_seq_bnodes)
		    ttlp_arg->ttlp_subj_uri = tf_bnode_iid (ttlp_arg->ttlp_tf, NULL);
		  else
		    ttlp_arg->ttlp_subj_uri = dk_set_pop (&(ttlp_arg->ttlp_unused_seq_bnodes));
		  ttlp_arg->ttlp_pred_uri = uname_rdf_ns_uri_first; }
	;

blank_block_formula
	:
		{
		  dk_set_push (&(ttlp_arg->ttlp_saved_uris), ttlp_arg->ttlp_formula_iid);
		  dk_set_push (&(ttlp_arg->ttlp_saved_uris), (void *)(ptrlong)ttlp_arg->ttlp_pred_is_reverse);
		  dk_set_push (&(ttlp_arg->ttlp_saved_uris), ttlp_arg->ttlp_subj_uri);
		  dk_set_push (&(ttlp_arg->ttlp_saved_uris), ttlp_arg->ttlp_pred_uri);
		  ttlp_arg->ttlp_formula_iid = tf_bnode_iid (ttlp_arg->ttlp_tf, NULL);
		  ttlp_arg->ttlp_pred_is_reverse = 0;
		  ttlp_arg->ttlp_subj_uri = NULL;
		  ttlp_arg->ttlp_pred_uri = NULL; }
		inner_triple_clauses _RBRA
		{ ttlp_triple_process_prepared (ttlp_arg);
		  $$ = ttlp_arg->ttlp_formula_iid;
		  dk_free_tree (ttlp_arg->ttlp_subj_uri);
		  dk_free_tree (ttlp_arg->ttlp_pred_uri);
		  ttlp_arg->ttlp_pred_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		  ttlp_arg->ttlp_subj_uri = dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		  ttlp_arg->ttlp_pred_is_reverse = (ptrlong)dk_set_pop (&(ttlp_arg->ttlp_saved_uris));
		  ttlp_arg->ttlp_formula_iid = dk_set_pop (&(ttlp_arg->ttlp_saved_uris)); }
	;

blank_node_label
	: BLANK_NODE_LABEL_NQ
	| BLANK_NODE_LABEL_TTL
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
		  caddr_t uri = $1;
		  if (NULL != ttlp_arg->ttlp_last_complete_uri)
		    ttlyyerror_action ("Internal error: proven memory leak");
		  ttlp_arg->ttlp_last_complete_uri = uri;
		  ttlp_arg->ttlp_last_q_save = NULL;
		  ttlp_arg->ttlp_last_complete_uri = ttlp_expand_qname_prefix (ttlp_arg, ttlp_arg->ttlp_last_complete_uri);
		  TTLP_URI_RESOLVE_IF_NEEDED(ttlp_arg->ttlp_last_complete_uri);
		}
	| _COLON
		{
		  if (NULL != ttlp_arg->ttlp_last_complete_uri)
		    ttlyyerror_action ("Internal error: proven memory leak");
		  if (NULL == ttlp_arg->ttlp_default_ns_uri)
		    ttlyyerror_action ("Default namespace prefix is not defined, so standalone ':' can not be used as an identifier.");
		  ttlp_arg->ttlp_last_complete_uri = box_copy_tree (ttlp_arg->ttlp_default_ns_uri);
		  TTLP_URI_RESOLVE_IF_NEEDED(ttlp_arg->ttlp_last_complete_uri);
		}
	;


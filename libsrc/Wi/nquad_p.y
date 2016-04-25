/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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
%expect 0

%{

#include "libutil.h"
#include "sqlnode.h"
#include "sqlparext.h"
#include "rdf_core.h"
#include "xmltree.h"
/*#include "langfunc.h"*/
#include "turtle_p.h"
#define nqyylex ttlyylex
#define nqyyerror ttlyyerror


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

/* Note that token list should always exactly match one in turtle_p.y */
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
%token __NQUAD_NONPUNCT_END	/* Delimiting value for syntax highlighting, this is instead of __TTL_NONPUNCT_END */

%type<box> blank
%type<token_type> keyword

%left _GARBAGE_BEFORE_DOT_WS _DOT_WS
%left _SEMI
%left _COMMA
%left _LPAR _RPAR _LBRA _RBRA _LSQBRA _RSQBRA

%%

nquaddoc
	: /* empty */
	| nquaddoc clause
	;

clause
	: _AT_keywords_L { ttlp_arg->ttlp_special_qnames = ~0; } keyword_list dot_opt
	| _AT_base_L Q_IRI_REF dot_opt { dk_free_box (ttlp_arg->ttlp_tf->tf_base_uri); ttlp_arg->ttlp_tf->tf_base_uri = $2; }
	| _AT_prefix_L QNAME_NS Q_IRI_REF dot_opt {
		caddr_t *old_uri_ptr;
		if (NULL != ttlp_arg->ttlp_namespaces_prefix2iri)
		  old_uri_ptr = (caddr_t *)id_hash_get (ttlp_arg->ttlp_namespaces_prefix2iri, (caddr_t)(&($2)));
		else
		  {
		    ttlp_arg->ttlp_namespaces_prefix2iri = (id_hash_t *)box_dv_dict_hashtable (31);
		    old_uri_ptr = NULL;
		  }
		if (NULL != old_uri_ptr)
		  {
		    /*
		    int err = strcmp (old_uri_ptr[0], $3);
		    dk_free_box ($2);
		    dk_free_box ($3);
		    if (err)
		      ttlyyerror_action ("Namespace prefix is re-used for a different namespace IRI");
		    */
		    dk_free_box ($2);
		    dk_free_box (old_uri_ptr[0]);
		    old_uri_ptr[0] = $3;
		  }
		else
		  id_hash_set (ttlp_arg->ttlp_namespaces_prefix2iri, (caddr_t)(&($2)), (caddr_t)(&($3)));
		ttlp_arg->ttlp_last_q_save = NULL; }
	| _AT_prefix_L _COLON Q_IRI_REF dot_opt	{
		dk_free_box (ttlp_arg->ttlp_default_ns_uri);
		ttlp_arg->ttlp_default_ns_uri = $3; }
	| subject pred object_with_ctx _DOT_WS		{ ttlp_triple_process_prepared (ttlp_arg); }
	| subject pred _GARBAGE_BEFORE_DOT_WS _DOT_WS
	| subject _GARBAGE_BEFORE_DOT_WS _DOT_WS
	| _GARBAGE_BEFORE_DOT_WS _DOT_WS
	| error { ttlyyerror_action ("Only a triple or a special clause (like prefix declaration) is allowed here"); }
	;

dot_opt
	: /* empty */
	| _DOT_WS
	;

subject
	: q_complete { dk_free_tree (ttlp_arg->ttlp_subj_uri);
		ttlp_arg->ttlp_subj_uri = ttlp_arg->ttlp_last_complete_uri;
		ttlp_arg->ttlp_last_complete_uri = NULL; }
	| VARIABLE { dk_free_tree (ttlp_arg->ttlp_subj_uri);
		ttlp_arg->ttlp_subj_uri = $1; }
	| blank { dk_free_tree (ttlp_arg->ttlp_subj_uri);
		ttlp_arg->ttlp_subj_uri = $1; }
	| literal_subject {
		TTLYYERROR_ACTION_COND (TTLP_SKIP_LITERAL_SUBJECTS, "Virtuoso does not support literal subjects");
		dk_free_tree (ttlp_arg->ttlp_subj_uri); ttlp_arg->ttlp_subj_uri = NULL; }
	| TTL_RECOVERABLE_ERROR { dk_free_tree (ttlp_arg->ttlp_subj_uri);
		ttlp_arg->ttlp_subj_uri = NULL; }
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

pred
	: q_complete	{ dk_free_tree (ttlp_arg->ttlp_pred_uri); ttlp_arg->ttlp_pred_uri = ttlp_arg->ttlp_last_complete_uri; ttlp_arg->ttlp_last_complete_uri = NULL; }
	| VARIABLE	{ dk_free_tree (ttlp_arg->ttlp_pred_uri); ttlp_arg->ttlp_pred_uri = $1; }
	| _AT_a_L	{ dk_free_tree (ttlp_arg->ttlp_pred_uri); ttlp_arg->ttlp_pred_uri = uname_rdf_ns_uri_type; }
	| _EQ		{ dk_free_tree (ttlp_arg->ttlp_pred_uri); ttlp_arg->ttlp_pred_uri = box_dv_uname_string ("http://www.w3.org/2002/07/owl#sameAs"); }
	| _EQ_GT	{ dk_free_tree (ttlp_arg->ttlp_pred_uri); ttlp_arg->ttlp_pred_uri = box_dv_uname_string ("http://www.w3.org/2000/10/swap/log#implies"); }
	| _AT_has_L q_complete	{ dk_free_tree (ttlp_arg->ttlp_pred_uri); ttlp_arg->ttlp_pred_uri = ttlp_arg->ttlp_last_complete_uri; ttlp_arg->ttlp_last_complete_uri = NULL; }
	| _AT_has_L VARIABLE	{ dk_free_tree (ttlp_arg->ttlp_pred_uri); ttlp_arg->ttlp_pred_uri = $2; }
	| _AT_has_L  error { ttlyyerror_action ("Only predicate is allowed after \"has\" keyword"); }
	| _LSQBRA_RSQBRA
		{
		  TTLYYERROR_ACTION_COND (TTLP_VERB_MAY_BE_BLANK, "Blank node (written as '[]') can not be used as a predicate");
		  dk_free_tree (ttlp_arg->ttlp_pred_uri); ttlp_arg->ttlp_pred_uri = tf_bnode_iid (ttlp_arg->ttlp_tf, NULL); }
	| BLANK_NODE_LABEL_NQ
		{
		  TTLYYERROR_ACTION_COND (TTLP_VERB_MAY_BE_BLANK, "Blank node (written as '_:...' label) can not be used as a predicate");
		  dk_free_tree (ttlp_arg->ttlp_pred_uri);
		  if (ttlp_arg->ttlp_formula_iid)
		    ttlp_arg->ttlp_pred_uri = tf_formula_bnode_iid (ttlp_arg, $1);
		  else
		    ttlp_arg->ttlp_pred_uri = tf_bnode_iid (ttlp_arg->ttlp_tf, $1);
		}
	| BLANK_NODE_LABEL_TTL
		{
		  TTLYYERROR_ACTION_COND (TTLP_VERB_MAY_BE_BLANK, "Blank node (written as '_:...' label) can not be used as a predicate");
		  TTLYYERROR_ACTION_COND (TTLP_ACCEPT_DIRTY_NAMES, "Blank node label has Turtle-specific syntax");
		  dk_free_tree (ttlp_arg->ttlp_pred_uri);
		  if (ttlp_arg->ttlp_formula_iid)
		    ttlp_arg->ttlp_pred_uri = tf_formula_bnode_iid (ttlp_arg, $1);
		  else
		    ttlp_arg->ttlp_pred_uri = tf_bnode_iid (ttlp_arg->ttlp_tf, $1);
		}
	| _AT_is_L q_complete _AT_of_L 	{ ttlp_arg->ttlp_pred_is_reverse = 1; dk_free_tree (ttlp_arg->ttlp_pred_uri); ttlp_arg->ttlp_pred_uri = ttlp_arg->ttlp_last_complete_uri; ttlp_arg->ttlp_last_complete_uri = NULL; }
	| _AT_is_L VARIABLE _AT_of_L 	{ ttlp_arg->ttlp_pred_is_reverse = 1; dk_free_tree (ttlp_arg->ttlp_pred_uri); ttlp_arg->ttlp_pred_uri = $2; }
	| _LT_EQ	{ ttlp_arg->ttlp_pred_is_reverse = 1; dk_free_tree (ttlp_arg->ttlp_pred_uri); ttlp_arg->ttlp_pred_uri = box_dv_uname_string ("http://www.w3.org/2000/10/swap/log#implies"); /* Note this 'double reversed' meaning :) */ }
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

object_with_ctx
	: q_complete {
		dk_free_tree (ttlp_arg->ttlp_obj);
		ttlp_arg->ttlp_obj = ttlp_arg->ttlp_last_complete_uri;
		ttlp_arg->ttlp_last_complete_uri = NULL; }
	  ctx_opt {
		ttlp_triple_and_inf_prepare (ttlp_arg, ttlp_arg->ttlp_obj); }
	| VARIABLE {
		dk_free_tree (ttlp_arg->ttlp_obj);
		ttlp_arg->ttlp_obj = $1; }
	  ctx_opt {
		ttlp_triple_and_inf_prepare (ttlp_arg, $1); }
	| blank {
		dk_free_tree (ttlp_arg->ttlp_obj);
		ttlp_arg->ttlp_obj = $1; }
	  ctx_opt {
		ttlp_triple_and_inf_prepare (ttlp_arg, $1); }
	| true_L ctx_opt {
		ttlp_triple_l_and_inf_prepare (ttlp_arg, (caddr_t)((ptrlong)1), uname_xmlschema_ns_uri_hash_boolean, NULL); }
	| false_L ctx_opt {
		ttlp_triple_l_and_inf_prepare (ttlp_arg, (caddr_t)((ptrlong)0), uname_xmlschema_ns_uri_hash_boolean, NULL); }
	| TURTLE_INTEGER ctx_opt {
		dk_free_tree (ttlp_arg->ttlp_obj);
		ttlp_arg->ttlp_obj = $1;
		ttlp_triple_l_and_inf_prepare (ttlp_arg, $1, uname_xmlschema_ns_uri_hash_integer, NULL); }
	| TURTLE_DECIMAL ctx_opt {
		dk_free_tree (ttlp_arg->ttlp_obj);
		ttlp_arg->ttlp_obj = $1;
		ttlp_triple_l_and_inf_prepare (ttlp_arg, $1, uname_xmlschema_ns_uri_hash_decimal, NULL); }
	| TURTLE_DOUBLE ctx_opt {
		dk_free_tree (ttlp_arg->ttlp_obj);
		ttlp_arg->ttlp_obj = $1;
		ttlp_triple_l_and_inf_prepare (ttlp_arg, $1, uname_xmlschema_ns_uri_hash_double, NULL);	}
	| NaN_L ctx_opt {
	  	double myZERO = 0.0;
		double myNAN_d = 0.0/myZERO;
		dk_free_tree (ttlp_arg->ttlp_obj);
		ttlp_arg->ttlp_obj = box_double (myNAN_d);
		ttlp_triple_l_and_inf_prepare (ttlp_arg, ttlp_arg->ttlp_obj, uname_xmlschema_ns_uri_hash_double, NULL);	}
	| INF_L ctx_opt {
	  	double myZERO = 0.0;
	  	double myPOSINF_d = 1.0/myZERO;
		dk_free_tree (ttlp_arg->ttlp_obj);
		ttlp_arg->ttlp_obj = box_double (myPOSINF_d);
		ttlp_triple_l_and_inf_prepare (ttlp_arg, ttlp_arg->ttlp_obj, uname_xmlschema_ns_uri_hash_double, NULL);	}
	| _MINUS_INF_L ctx_opt {
	  	double myZERO = 0.0;
	 	double myNEGINF_d = -1.0/myZERO;
		dk_free_tree (ttlp_arg->ttlp_obj);
		ttlp_arg->ttlp_obj = box_double (myNEGINF_d);
		ttlp_triple_l_and_inf_prepare (ttlp_arg, ttlp_arg->ttlp_obj, uname_xmlschema_ns_uri_hash_double, NULL);	}
	| TURTLE_STRING ctx_opt	{
		dk_free_tree (ttlp_arg->ttlp_obj);
		ttlp_arg->ttlp_obj = $1;
		ttlp_triple_l_and_inf_prepare (ttlp_arg, $1, NULL, NULL); }
	| TURTLE_STRING LANGTAG ctx_opt	{
		dk_free_tree (ttlp_arg->ttlp_obj);
		ttlp_arg->ttlp_obj = $1;
		dk_free_tree (ttlp_arg->ttlp_obj_lang);
		ttlp_arg->ttlp_obj_lang = $2;
		ttlp_triple_l_and_inf_prepare (ttlp_arg, $1, NULL, $2);	}
	| TURTLE_STRING _CARET_CARET q_complete {
		dk_free_tree (ttlp_arg->ttlp_obj);
		ttlp_arg->ttlp_obj = $1;
		dk_free_tree (ttlp_arg->ttlp_obj_type);
		ttlp_arg->ttlp_obj_type = ttlp_arg->ttlp_last_complete_uri;
		ttlp_arg->ttlp_last_complete_uri = NULL; }
	  ctx_opt {
		ttlp_triple_l_and_inf_prepare (ttlp_arg, ttlp_arg->ttlp_obj, ttlp_arg->ttlp_obj_type, NULL);	}
	| TTL_RECOVERABLE_ERROR ctx_opt { }
	| TURTLE_STRING _CARET_CARET TTL_RECOVERABLE_ERROR ctx_opt {
		dk_free_tree (ttlp_arg->ttlp_obj);
		ttlp_arg->ttlp_obj = $1; }
	| TTL_RECOVERABLE_ERROR _CARET_CARET q_complete {
		dk_free_tree (ttlp_arg->ttlp_last_complete_uri);
		ttlp_arg->ttlp_last_complete_uri = NULL; }
	  ctx_opt { }
	| TTL_RECOVERABLE_ERROR _CARET_CARET TTL_RECOVERABLE_ERROR ctx_opt { }
	;

ctx_opt
	: /* empty */	{
		triple_feed_t *tf = ttlp_arg->ttlp_tf;
		if ((NULL == tf->tf_current_graph_uri) || ((NULL != tf->tf_default_graph_uri) && strcmp (tf->tf_current_graph_uri, tf->tf_default_graph_uri)))
		  TF_CHANGE_GRAPH_TO_DEFAULT (tf);
		  }
	| q_complete {
		triple_feed_t *tf = ttlp_arg->ttlp_tf;
		if ((NULL == tf->tf_current_graph_uri) || strcmp (tf->tf_current_graph_uri, ttlp_arg->ttlp_last_complete_uri))
		  TF_CHANGE_GRAPH (tf, ttlp_arg->ttlp_last_complete_uri);
		else {
		    dk_free_tree (ttlp_arg->ttlp_last_complete_uri);
		    ttlp_arg->ttlp_last_complete_uri = NULL; } }
	| TTL_RECOVERABLE_ERROR { }
	| _GARBAGE_BEFORE_DOT_WS { }
	;


blank
	: BLANK_NODE_LABEL_NQ
		{
		  if (ttlp_arg->ttlp_formula_iid)
		    $$ = tf_formula_bnode_iid (ttlp_arg, $1);
		  else
		    $$ = tf_bnode_iid (ttlp_arg->ttlp_tf, $1);
		}
	| BLANK_NODE_LABEL_TTL
		{
		  TTLYYERROR_ACTION_COND (TTLP_ACCEPT_DIRTY_NAMES, "Blank node label has Turtle-specific syntax; this error can be suppressed by parser flag");
		  if (ttlp_arg->ttlp_formula_iid)
		    $$ = tf_formula_bnode_iid (ttlp_arg, $1);
		  else
		    $$ = tf_bnode_iid (ttlp_arg->ttlp_tf, $1);
		}
	| _LSQBRA_RSQBRA	{ $$ = tf_bnode_iid (ttlp_arg->ttlp_tf, NULL); }
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
	;

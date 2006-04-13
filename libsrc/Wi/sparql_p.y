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

#define YYPARSE_PARAM sparp_as_void
#define YYLEX_PARAM YYPARSE_PARAM
#include "libutil.h"
#include "sqlnode.h"
#include "sqlparext.h"
#include "sparql.h"
#include "xmltree.h"
/*#include "langfunc.h"*/

#define sparp_arg ((sparp_t *)(sparp_as_void))

#ifdef DEBUG
#define sparyyerror(strg) sparyyerror_impl_1(sparp_arg, NULL, yystate, yyssa, yyssp, (strg))
#else
#define sparyyerror(strg) sparyyerror_impl(sparp_arg, NULL, (strg))
#endif

#ifdef XPYYDEBUG
#define YYDEBUG 1
#endif

#define sparyylex(lval_ptr, param) sparyylex_from_sparp_bufs ((caddr_t *)(lval_ptr), ((sparp_t *)(param)))

#define SPAR_BIN_OP(dst,op,l,r) (dst) = spartlist (sparp_arg, 3, (op), (l), (r))


#define bmk_offset sparp_curr_lexem_bmk.sparlb_offset
#define bmk_bufs_tail sparp_curr_lexem_bmk.sparlb_lexem_bufs_tail

int sparyylex_from_sparp_bufs (caddr_t *yylval, sparp_t *sparp)
{
  spar_lexem_t *sparl;
  while (sparp->bmk_offset >= sparp->sparp_lexem_buf_len)
    {
      sparp->bmk_bufs_tail = sparp->bmk_bufs_tail->next;
      if (NULL == sparp->bmk_bufs_tail)
	{
	  /*sparp->sparp_curr_lexem = NULL; -- commented out to have at least 'some' current lexem */
	  return 0;
	}
      sparp->sparp_lexem_buf_len = box_length (sparp->bmk_bufs_tail->data) / sizeof (spar_lexem_t);
      sparp->bmk_offset = 0;
    }
  sparl = ((spar_lexem_t *)(sparp->bmk_bufs_tail->data)) + sparp->bmk_offset;
  yylval[0] = sparl->sparl_sem_value;
  sparp->sparp_curr_lexem = sparl;
  sparp->bmk_offset += 1;
  return (int) sparl->sparl_lex_value;
}

%}

/* symbolic tokens */
%union {
  caddr_t box;
  ptrlong token_type;
  SPART *tree;
  SPART **trees;
  dk_set_t list;
  dk_set_t backstack;
  spar_lexbmk_t *bookmark;
  void *nothing;
}

%token __SPAR_PUNCT_BEGIN	/* Delimiting value for syntax highlighting */

%token _AMP_AMP		/*:: PUNCT_SPAR_LAST("&&") ::*/
%token _BACKQUOTE	/*:: PUNCT_SPAR_LAST("`") ::*/
%token _BANG		/*:: PUNCT_SPAR_LAST("!") ::*/
%token _BAR_BAR		/*:: PUNCT_SPAR_LAST("||") ::*/
%token _CARET_CARET	/*:: PUNCT_SPAR_LAST("^^") ::*/
%token _COMMA		/*:: PUNCT_SPAR_LAST(",") ::*/
%token _DOT		/*:: PUNCT_SPAR_LAST(".") ::*/
%token _EQ		/*:: PUNCT_SPAR_LAST("=") ::*/
%token _GE		/*:: PUNCT_SPAR_LAST(">=") ::*/
%token _GT		/*:: PUNCT_SPAR_LAST(">") ::*/
%token _LBRA		/*:: PUNCT_SPAR_LAST("{") ::*/
%token _LE		/*:: PUNCT_SPAR_LAST("<=") ::*/
%token _LPAR		/*:: PUNCT_SPAR_LAST("(") ::*/
%token _LSQBRA		/*:: PUNCT_SPAR_LAST("[") ::*/
%token _LT		/*:: PUNCT_SPAR_LAST("<") ::*/
%token _MINUS		/*:: PUNCT_SPAR_LAST("-") ::*/
%token _NOT_EQ		/*:: PUNCT_SPAR_LAST("!=") ::*/
%token _PLUS		/*:: PUNCT_SPAR_LAST("+") ::*/
%token _RBRA		/*:: PUNCT_SPAR_LAST("{ }") ::*/
%token _RPAR		/*:: PUNCT_SPAR_LAST("( )") ::*/
%token _RSQBRA		/*:: PUNCT_SPAR_LAST("[ ]") ::*/
%token _SEMI		/*:: PUNCT_SPAR_LAST(";") ::*/
%token _SLASH		/*:: PUNCT_SPAR_LAST("/") ::*/
%token _STAR		/*:: PUNCT_SPAR_LAST("*") ::*/

%token a_L		/*:: PUNCT_SPAR_LAST("a") ::*/
%token ASC_L		/*:: PUNCT_SPAR_LAST("ASC") ::*/
%token ASK_L		/*:: PUNCT_SPAR_LAST("ASK") ::*/
%token BASE_L		/*:: PUNCT_SPAR_LAST("BASE") ::*/
%token BOUND_L		/*:: PUNCT_SPAR_LAST("BOUND") ::*/
%token BY_L		/*:: PUNCT_SPAR_LAST("BY") ::*/
%token CONSTRUCT_L	/*:: PUNCT_SPAR_LAST("CONSTRUCT") ::*/
%token DATATYPE_L	/*:: PUNCT_SPAR_LAST("DATATYPE") ::*/
%token DEFINE_L		/*:: PUNCT_SPAR_LAST("DEFINE") ::*/
%token DESC_L		/*:: PUNCT_SPAR_LAST("DESC") ::*/
%token DESCRIBE_L	/*:: PUNCT_SPAR_LAST("DESCRIBE") ::*/
%token DISTINCT_L	/*:: PUNCT_SPAR_LAST("DISTINCT") ::*/
%token false_L		/*:: PUNCT_SPAR_LAST("false") ::*/
%token FILTER_L		/*:: PUNCT_SPAR_LAST("FILTER") ::*/
%token FROM_L		/*:: PUNCT_SPAR_LAST("FROM") ::*/
%token GRAPH_L		/*:: PUNCT_SPAR_LAST("GRAPH") ::*/
%token isBLANK_L	/*:: PUNCT_SPAR_LAST("isBLANK") ::*/
%token isIRI_L		/*:: PUNCT_SPAR_LAST("isIRI") ::*/
%token isLITERAL_L	/*:: PUNCT_SPAR_LAST("isLITERAL") ::*/
%token isURI_L		/*:: PUNCT_SPAR_LAST("isURI") ::*/
%token LANG_L		/*:: PUNCT_SPAR_LAST("LANG") ::*/
%token LANGMATCHES_L	/*:: PUNCT_SPAR_LAST("LANGMATCHES") ::*/
%token LIMIT_L		/*:: PUNCT_SPAR_LAST("LIMIT") ::*/
%token NAMED_L		/*:: PUNCT_SPAR_LAST("NAMED") ::*/
%token NIL_L		/*:: PUNCT_SPAR_LAST("NIL") ::*/
%token OFFSET_L		/*:: PUNCT_SPAR_LAST("OFFSET") ::*/
%token OPTIONAL_L	/*:: PUNCT_SPAR_LAST("OPTIONAL") ::*/
%token ORDER_L		/*:: PUNCT_SPAR_LAST("ORDER") ::*/
%token PREFIX_L		/*:: PUNCT_SPAR_LAST("PREFIX") ::*/
%token REGEX_L		/*:: PUNCT_SPAR_LAST("REGEX") ::*/
%token SELECT_L		/*:: PUNCT_SPAR_LAST("SELECT") ::*/
%token STR_L		/*:: PUNCT_SPAR_LAST("STR") ::*/
%token true_L		/*:: PUNCT_SPAR_LAST("true") ::*/
%token UNION_L		/*:: PUNCT_SPAR_LAST("UNION") ::*/
%token WHERE_L		/*:: PUNCT_SPAR_LAST("WHERE") ::*/

%token __SPAR_PUNCT_END	/* Delimiting value for syntax highlighting */

%token START_OF_SPARQL_TEXT	/*:: FAKE("the beginning of SPARQL text"), SPAR, NULL ::*/
%token END_OF_SPARQL_TEXT	/*:: FAKE("the end of SPARQL text"), SPAR, NULL ::*/

%token __SPAR_NONPUNCT_START	/* Delimiting value for syntax highlighting */

%token <box> SPARQL_INTEGER	/*:: LITERAL("%d"), SPAR, LAST("1234") ::*/
%token <box> SPARQL_DECIMAL	/*:: LITERAL("%d"), SPAR, LAST("1234.56") ::*/
%token <box> SPARQL_DOUBLE	/*:: LITERAL("%d"), SPAR, LAST("1234.56e1") ::*/

%token <box> SPARQL_STRING /*:: LITERAL("%s"), SPAR, LAST("'sq'"), LAST("\"dq\""), LAST("'''sq1\nsq2'''"), LAST("\"\"\"dq1\ndq2\"\"\""), LAST("'\"'"), LAST("'-\\\\-\\t-\\v-\\r-\\'-\\\"-\\u1234-\\U12345678-\\uaAfF-'") ::*/
%token <box> LANGTAG	/*:: LITERAL("%s"), SPAR, LAST("@ES") ::*/

%token <box> QNAME	/*:: LITERAL("%s"), SPAR, LAST("pre.fi-X.1:_f.Rag.2"), LAST(":_f.Rag.2") ::*/
%token <box> QNAME_NS	/*:: LITERAL("%s"), SPAR, LAST("pre.fi-X.1:") ::*/
%token <box> BLANK_NODE_LABEL /*:: LITERAL("%s"), SPAR, LAST("_:_f.Rag.2") ::*/
%token <box> Q_IRI_REF	/*:: LITERAL("%s"), SPAR, LAST("<something>"), LAST("<http://www.example.com/sample#frag>") ::*/

%token <box> QUEST_VARNAME	/*:: LITERAL("?%s"), SPAR, LAST("?1var_Name1") ::*/
%token <box> DOLLAR_VARNAME	/*:: LITERAL("$%s"), SPAR, LAST("$2var_Name2") ::*/
%token <box> QUEST_COLON_PARAMNAME	/*:: LITERAL("?:%s"), SPAR, LAST("?:var_Name1") ::*/
%token <box> DOLLAR_COLON_PARAMNAME	/*:: LITERAL("$:%s"), SPAR, LAST("$:var_Name2") ::*/
%token <box> QUEST_COLON_PARAMNUM	/*:: LITERAL("??"), SPAR, LAST("??") ::*/
%token <box> DOLLAR_COLON_PARAMNUM	/*:: LITERAL("$?"), SPAR, LAST("$?") ::*/

%token __SPAR_NONPUNCT_END	/* Delimiting value for syntax highlighting */

%type <tree> sql
%type <tree> top_sparql
%type <tree> spar_query_body
%type <nothing> spar_prolog
%type <nothing> spar_defines_opt
%type <nothing> spar_define
%type <nothing> spar_base_decl_opt
%type <nothing> spar_prefix_decls_opt
%type <nothing> spar_prefix_decl
%type <tree> spar_select_query
%type <token_type> spar_select_query_mode
%type <trees> spar_select_rset
%type <tree> spar_construct_query
%type <tree> spar_describe_query
%type <trees> spar_describe_rset
%type <tree> spar_ask_query
%type <nothing> spar_dataset_clauses_opt
%type <nothing> spar_dataset_clause
%type <tree> spar_where_clause_opt
%type <tree> spar_where_clause
%type <trees> spar_solution_modifier
%type <backstack> spar_order_clause_opt
%type <backstack> spar_order_conditions
%type <tree> spar_order_condition
%type <token_type> spar_asc_or_desc_opt
%type <box> spar_limit_clause_opt
%type <box> spar_offset_clause_opt
%type <tree> spar_group_gp
%type <nothing> spar_gp
%type <nothing> spar_gp_not_triples
%type <tree> spar_optional_gp
%type <tree> spar_graph_gp
%type <tree> spar_group_or_union_gp
%type <tree> spar_constraint
%type <tree> spar_ctor_template
%type <nothing> spar_ctor_triples
%type <nothing> spar_triples_opt
%type <nothing> spar_triples
%type <nothing> spar_triples1
%type <nothing> spar_props_opt
%type <nothing> spar_props
%type <nothing> spar_graph_nodes
%type <tree> spar_verb
%type <tree> spar_triples_node
%type <nothing> spar_cons_collection
%type <tree> spar_graph_node
%type <tree> spar_var_or_term
%type <backstack> spar_var_or_irirefs
%type <tree> spar_var_or_iriref
%type <tree> spar_var_or_blank_node_or_iriref
%type <backstack> spar_rset_items
%type <tree> spar_rset_item
%type <tree> spar_var
%type <tree> spar_graph_term
%type <backstack> spar_expns
%type <tree> spar_expn
%type <tree> spar_built_in_call
%type <tree> spar_function_call
%type <backstack> spar_arg_list_opt
%type <backstack> spar_arg_list
%type <tree> spar_numeric_literal
%type <tree> spar_rdf_literal
%type <tree> spar_boolean_literal
%type <tree> spar_iriref
%type <tree> spar_qname
%type <tree> spar_blank_node

%left _SEMI
%left _COLON
%left _BAR_BAR
%left _AMP_AMP
%nonassoc _BANG
%nonassoc _EQ _NOT_EQ
%nonassoc _LT _LE _GT _GE 
%left _PLUS _MINUS
%left _SLASH _STAR
%nonassoc UMINUS
%nonassoc UPLUS
%left _LSQBRA _RSQBRA _LPAR _RPAR

%%

/* TOP-LEVEL begin */
sql
	: START_OF_SPARQL_TEXT
		{
		   /* sparp_register_default_namespace_prefixes (sparp_arg); */
		}
	  top_sparql END_OF_SPARQL_TEXT { sparp_arg->sparp_expr = $$ = $3; }
	| error { sparyyerror ("(internal SPARQL processing error) SPARQL mark expected"); }
	;

top_sparql		/* [1]  	Query	  ::=  	Prolog ( SelectQuery | ConstructQuery | DescribeQuery | AskQuery )	*/
        : spar_prolog {;;;} spar_query_body { $$ = $3; }
	| END_OF_SPARQL_TEXT	{ yyerror ("The SPARQL expression is totally empty"); }
        ;

spar_query_body
        : spar_select_query
	| spar_construct_query
	| spar_describe_query
	| spar_ask_query
	;

spar_prolog		/* [2]  	Prolog	  ::=  	BaseDecl? PrefixDecl*	*/
	: spar_defines_opt spar_base_decl_opt spar_prefix_decls_opt
	;

spar_defines_opt
        : /* empty */	{ ; }
        | spar_defines_opt DEFINE_L spar_define	{ ; }
	;

spar_define
        : QNAME QNAME { sparp_define (sparp_arg, $1, QNAME, $2); }
        | QNAME Q_IRI_REF { sparp_define (sparp_arg, $1, Q_IRI_REF, $2); }
	| QNAME SPARQL_STRING { sparp_define (sparp_arg, $1, SPARQL_STRING, $2); }
	;

spar_base_decl_opt	/* [3]  	BaseDecl	  ::=  	'BASE' Q_IRI_REF	*/
	: /* empty */		{ ; }
	| BASE_L Q_IRI_REF	{
		if (NULL != sparp_env()->spare_base_uri)
		  sparyyerror ("Only one base declaration is allowed");
		sparp_env()->spare_base_uri = $2; }
	| BASE_L error { sparyyerror ("Missing <iri-string> after BASE keyword"); }
	;

spar_prefix_decls_opt
	: /* empty */		{ ; }
	| spar_prefix_decls_opt spar_prefix_decl { ; }
	;

spar_prefix_decl	/* [4]  	PrefixDecl	  ::=  	'PREFIX' QNAME_NS Q_IRI_REF	*/
	: PREFIX_L QNAME_NS Q_IRI_REF	{
                if (!strcmp ("sql:", $2) || !strcmp ("bif:", $2))
		  sparyyerror ("Prefixes 'sql:' and 'bif:' are reserved for SQL names");
		t_set_push (&(sparp_env()->spare_namespace_prefixes), $3);
		t_set_push (&(sparp_env()->spare_namespace_prefixes), $2); }
	| PREFIX_L QNAME_NS { sparyyerror ("Missing <namespace-iri-string> in PREFIX declaration"); }
	| PREFIX_L error { sparyyerror ("Missing namespace prefix after PREFIX keyword"); }
	;

spar_select_query	/* [5]  	SelectQuery	  ::=  	'SELECT' 'DISTINCT'? ( Var+ | '*' ) DatasetClause* WhereClause SolutionModifier	*/
	: spar_select_query_mode { spar_selid_push (sparp_arg); }
	    spar_select_rset spar_dataset_clauses_opt { spar_gp_init (sparp_arg, WHERE_L); }
            spar_where_clause spar_solution_modifier {
		$$ = spar_make_top (sparp_arg, $1, $3, spar_selid_pop (sparp_arg),
		  $6, (SPART **)($7[0]), (caddr_t)($7[1]), (caddr_t)($7[2]) ); }
	;

spar_select_query_mode
	: SELECT_L		{ $$ = SELECT_L; }
	| SELECT_L DISTINCT_L	{ $$ = DISTINCT_L; }
	;

spar_select_rset
	: _STAR			{ $$ = (SPART **) _STAR; }
	| spar_rset_items	{ $$ = (SPART **) t_revlist_to_array ($1); }
	;

spar_construct_query	/* [6]  	ConstructQuery	  ::=  	'CONSTRUCT' ConstructTemplate DatasetClause* WhereClause SolutionModifier	*/
	: CONSTRUCT_L { spar_selid_push (sparp_arg); }
            spar_ctor_template spar_dataset_clauses_opt { spar_gp_init (sparp_arg, WHERE_L); }
	    spar_where_clause spar_solution_modifier {
		$$ = spar_make_top (sparp_arg, CONSTRUCT_L,
                  spar_retvals_of_construct (sparp_arg, $3),
                  spar_selid_pop (sparp_arg),
		  $6, (SPART **)($7[0]), (caddr_t)($7[1]), (caddr_t)($7[2]) ); }
	;

spar_describe_query	/* [7]  	DescribeQuery	  ::=  	'DESCRIBE' ( VarOrIRIref+ | '*' ) DatasetClause* WhereClause? SolutionModifier	*/
	: DESCRIBE_L { spar_selid_push (sparp_arg); }
            spar_describe_rset spar_dataset_clauses_opt { spar_gp_init (sparp_arg, WHERE_L); }
	    spar_where_clause_opt spar_solution_modifier {
		$$ = spar_make_top (sparp_arg, DESCRIBE_L, 
                  $3,
                  spar_selid_pop (sparp_arg),
		  $6, (SPART **)($7[0]), (caddr_t)($7[1]), (caddr_t)($7[2]) ); }
	;

spar_describe_rset
	: _STAR			{ $$ = (SPART **) _STAR; }
	| spar_var_or_irirefs	{ $$ = (SPART **) t_list_to_array ($1); }
	;

spar_ask_query		/* [8]  	AskQuery	  ::=  	'ASK' DatasetClause* WhereClause	*/
	: ASK_L { spar_selid_push (sparp_arg); }
            spar_dataset_clauses_opt { spar_gp_init (sparp_arg, WHERE_L); }
	    spar_where_clause_opt {
		$$ = spar_make_top (sparp_arg, ASK_L, (SPART **)t_list(0), spar_selid_pop (sparp_arg),
		  $5, NULL, t_box_num(1), t_box_num(0) ); }
	;

spar_dataset_clauses_opt
	: /* empty */					{ }
	| spar_dataset_clauses_opt spar_dataset_clause	{ }
	;

spar_dataset_clause	/* [9]  	DatasetClause	  ::=  	'FROM' ( DefaultGraphClause | NamedGraphClause )	*/
	: FROM_L spar_iriref {			/* [10]  	DefaultGraphClause	  ::=  	SourceSelector	*/
                if (0 == sparp_env()->spare_default_graph_locked)
                  {
		    if (NULL != sparp_env()->spare_default_graph_uri)
		      sparyyerror ("Default graph clause is defined twice");
                    sparp_env()->spare_default_graph_uri = t_box_copy ($2->_.lit.val);
                  }
		}
	| FROM_L NAMED_L spar_iriref {		/* [11]  	NamedGraphClause	  ::=  	'NAMED' SourceSelector	*/
                if (0 == sparp_env()->spare_named_graphs_locked)
                  t_set_push (&(sparp_env()->spare_named_graph_uris), t_box_copy ($3->_.lit.val));
		}
	;

spar_where_clause_opt
	: /* empty */		{ $$ = spar_gp_finalize (sparp_arg); }
	| spar_where_clause	{ $$ = $1; }
	;

spar_where_clause	/* [13]  	WhereClause	  ::=  	'WHERE'? GroupGraphPattern	*/
	: WHERE_L _LBRA spar_group_gp	{ $$ = $3; }
	| _LBRA spar_group_gp		{ $$ = $2; }
	;

spar_solution_modifier	/* [14]  	SolutionModifier	  ::=  	OrderClause? LimitClause? OffsetClause?	*/
	: spar_order_clause_opt spar_limit_clause_opt spar_offset_clause_opt	{ $$ = (SPART **)t_list (3, t_revlist_to_array ($1), $2, $3); }
	;

spar_order_clause_opt	/* [15]  	OrderClause	  ::=  	'ORDER' 'BY' OrderCondition+	*/
	: /* empty */				{ $$ = NULL; }
	| ORDER_L BY_L spar_order_conditions	{ $$ = $3; }
	;

spar_order_conditions
	: spar_order_condition				{ $$ = NULL; t_set_push (&($$), $1); }
	| spar_order_conditions spar_order_condition	{ $$ = $1; t_set_push (&($$), $2); }
	;

spar_order_condition	/* [16]  	OrderCondition	  ::=  	( ( 'ASC' | 'DESC' ) BrackettedExpression ) | ( FunctionCall | Var | BrackettedExpression ) 	*/
	: spar_asc_or_desc_opt _LPAR spar_expn _RPAR		{ $$ = spartlist (sparp_arg, 3, ORDER_L, $1, $3); }
	| spar_asc_or_desc_opt _LSQBRA spar_expn _RSQBRA	{ $$ = spartlist (sparp_arg, 3, ORDER_L, $1, $3); }
	| spar_function_call					{ $$ = spartlist (sparp_arg, 3, ORDER_L, ASC_L, $1); }
	| spar_var						{ $$ = spartlist (sparp_arg, 3, ORDER_L, ASC_L, $1); }
	;

spar_asc_or_desc_opt
	: /* empty */	{ $$ = ASC_L; }
	| ASC_L		{ $$ = ASC_L; }
	| DESC_L	{ $$ = DESC_L; }
	;

spar_limit_clause_opt	/* [17]  	LimitClause	  ::=  	'LIMIT' INTEGER	*/
	: /* empty */ { $$ = t_box_num (SPARP_MAXLIMIT); }
	| LIMIT_L SPARQL_INTEGER { $$ = $2; }
	;

spar_offset_clause_opt	/* [18]  	OffsetClause	  ::=  	'OFFSET' INTEGER	*/
	: /* empty */ { $$ = t_box_num (0); }
	| OFFSET_L SPARQL_INTEGER { $$ = $2; }
	;

spar_group_gp		/* [19]  	GroupGraphPattern	  ::=  	'{' GraphPattern '}'	*/
	: spar_gp _RBRA { $$ = spar_gp_finalize (sparp_arg); }
	;

spar_gp			/* [20]  	GraphPattern	  ::=  	Triples? ( GraphPatternNotTriples '.'? GraphPattern )?	*/
	: spar_triples_opt { }
	| spar_triples_opt spar_gp_not_triples spar_gp { }
	| spar_triples_opt spar_gp_not_triples _DOT spar_gp { }
	;

spar_gp_not_triples	/* [21]  	GraphPatternNotTriples	  ::=  	OptionalGraphPattern | GroupOrUnionGraphPattern | GraphGraphPattern | Constraint	*/
	: spar_optional_gp { spar_gp_add_member (sparp_arg, $1); }
	| spar_group_or_union_gp { spar_gp_add_member (sparp_arg, $1); }
	| spar_graph_gp { spar_gp_add_member (sparp_arg, $1); }
	| spar_constraint { spar_gp_add_filter (sparp_arg, $1); }
	;

spar_optional_gp	/* [22]  	OptionalGraphPattern	  ::=  	'OPTIONAL' GroupGraphPattern	*/
	: OPTIONAL_L _LBRA { spar_gp_init (sparp_arg, OPTIONAL_L); } spar_group_gp { $$ = $4; }
	| OPTIONAL_L error { sparyyerror ("Missing '{' after OPTIONAL keyword"); }
	;

spar_graph_gp		/* [23]  	GraphGraphPattern	  ::=  	'GRAPH' VarOrBlankNodeOrIRIref GroupGraphPattern	*/
	: GRAPH_L
	    spar_var_or_blank_node_or_iriref { t_set_push (&(sparp_env()->spare_context_graphs), $2); }
	    _LBRA {
		spar_gp_init (sparp_arg, 0);
		spar_gp_add_filter_for_named_graph (sparp_arg); }
	    spar_group_gp { t_set_pop (&(sparp_env()->spare_context_graphs)); $$ = $6; }
	;

spar_group_or_union_gp	/* [24]  	GroupOrUnionGraphPattern	  ::=  	GroupGraphPattern ( 'UNION' GroupGraphPattern )*	*/
	: _LBRA { spar_gp_init (sparp_arg, 0); } spar_group_gp { $$ = $3; }
	| spar_group_or_union_gp UNION_L _LBRA {
                sparp_env()->spare_good_graph_varnames = sparp_env()->spare_good_graph_bmk;
		spar_gp_init (sparp_arg, UNION_L);
		spar_gp_add_member (sparp_arg, $1);
		spar_gp_init (sparp_arg, 0); }
	    spar_group_gp {
		spar_gp_add_member (sparp_arg, $5);
		$$ = spar_gp_finalize (sparp_arg); }
	;

spar_constraint		/* [25]  	Constraint	  ::=  	'FILTER' ( BrackettedExpression | BuiltInCall | FunctionCall )	*/
	: FILTER_L _LPAR spar_expn _RPAR	{ $$ = $3; }
	| FILTER_L spar_built_in_call	{ $$ = $2; }
	| FILTER_L spar_function_call	{ $$ = $2; }
	;

spar_ctor_template	/* [26]  	ConstructTemplate	  ::=  	'{' ConstructTriples '}'	*/
	: _LBRA { spar_gp_init (sparp_arg, CONSTRUCT_L); }
	    spar_ctor_triples_opt _RBRA { $$ = spar_gp_finalize (sparp_arg); }
	;

spar_ctor_triples_opt	/* [27]  	ConstructTriples	  ::=  	( Triples1 ( '.' ConstructTriples )? )?	*/
	: /* empty */ { }
	| spar_ctor_triples { }
	| spar_ctor_triples _DOT { }
	;

spar_ctor_triples
	: spar_triples1				{ }
	| spar_ctor_triples _DOT spar_triples1	{ }
	;

spar_triples_opt
	: /* empty */	{ }
	| spar_triples	{ }
	;

spar_triples		/* [28]  	Triples	  ::=  	Triples1 ( '.' Triples? )?	*/
	: spar_triples1				{ }
	| spar_triples1 _DOT spar_triples_opt	{ }
	;

spar_triples1		/* [29]  	Triples1	  ::=  	VarOrTerm PropertyListNotEmpty | TriplesNode PropertyList	*/
	: spar_var_or_term { t_set_push (&(sparp_env()->spare_context_subjects), $1); }
	    spar_props { t_set_pop (&(sparp_env()->spare_context_subjects)); $$ = $3; }
	| spar_triples_node { t_set_push (&(sparp_env()->spare_context_subjects), $1); }
	    spar_props_opt { t_set_pop (&(sparp_env()->spare_context_subjects)); }
	;

spar_props_opt		/* [30]  	PropertyList	  ::=  	PropertyListNotEmpty?	*/
	: /* empty */	{ }
	| spar_props	{ }
	| spar_props _SEMI	{ }
	;

spar_props		/* [31]  	PropertyListNotEmpty	  ::=  	Verb ObjectList ( ';' PropertyList )?	*/
	: spar_verb { t_set_push (&(sparp_env()->spare_context_predicates), $1); }
	    spar_graph_nodes { t_set_pop (&(sparp_env()->spare_context_predicates)); }
	| spar_props _SEMI
	    spar_verb { t_set_push (&(sparp_env()->spare_context_predicates), $3); }
	    spar_graph_nodes { t_set_pop (&(sparp_env()->spare_context_predicates)); }
	| spar_props _SEMI error { sparyyerror ("Predicate expected after semicolon"); }
	| error { sparyyerror ("Predicate expected"); }
	;

spar_graph_nodes	/* [32]  	ObjectList	  ::=  	GraphNode ( ',' ObjectList )?	*/
	: spar_graph_node {
	    spar_gp_add_member (sparp_arg,
	      spar_make_triple (sparp_arg, NULL, NULL, NULL, $1) ); }
	| spar_graph_nodes _COMMA spar_graph_node {
	    spar_gp_add_member (sparp_arg,
	      spar_make_triple (sparp_arg, NULL, NULL, NULL, $3) ); }
	| spar_graph_nodes _COMMA error { sparyyerror ("Object expected after comma"); }
	| error { sparyyerror ("Object expected"); }
	;

spar_verb		/* [33]  	Verb	  ::=  	VarOrBlankNodeOrIRIref | 'a'	*/
	: spar_var_or_blank_node_or_iriref
	| a_L { $$ = t_box_dv_uname_string ("http://www.w3.org/1999/02/22-rdf-syntax-ns#type"); }
	;

spar_triples_node	/* [34]  	TriplesNode	  ::=  	Collection | BlankNodePropertyList	*/
	: _LSQBRA {	/* [35]  	BlankNodePropertyList	  ::=  	'[' PropertyListNotEmpty ']'	*/
		SPART *bn = spar_make_blank_node (sparp_arg, spar_mkid (sparp_arg, "_:lsqbra"), 1); 
		t_set_push (&(sparp_env()->spare_context_subjects), bn); }
	    spar_props spar_triples_opt_semi_rsqbra {
		$$ = t_set_pop (&(sparp_env()->spare_context_subjects)); }
	| _LPAR {	/* [36]  	Collection	  ::=  	'(' GraphNode+ ')'	*/
		SPART *bn = spar_make_blank_node (sparp_arg, spar_mkid (sparp_arg, "_:topcons"), 1); 
		t_set_push (&(sparp_env()->spare_context_subjects), bn);
		t_set_push (&(sparp_env()->spare_context_subjects), bn); }
	    spar_cons_collection _RPAR {
		spar_gp_add_member (sparp_arg,
		  spar_make_triple (sparp_arg,
		    NULL, NULL,
		    spartlist (sparp_arg, 2, SPAR_QNAME, t_box_dv_uname_string ("http://www.w3.org/1999/02/22-rdf-syntax-ns#rest")),
		    spartlist (sparp_arg, 2, SPAR_QNAME, t_box_dv_uname_string ("http://www.w3.org/1999/02/22-rdf-syntax-ns#nil"))
		    ) );
		t_set_pop (&(sparp_env()->spare_context_subjects));
		$$ = t_set_pop (&(sparp_env()->spare_context_subjects)); }
	;

spar_triples_opt_semi_rsqbra
	: _RSQBRA {}
	| _SEMI _RSQBRA {}
	;

spar_cons_collection	/* [32]  	ObjectList	  ::=  	GraphNode ( ',' ObjectList )?	*/
	: spar_graph_node {
		spar_gp_add_member (sparp_arg,
		  spar_make_triple (sparp_arg, NULL, NULL,
		    spartlist (sparp_arg, 2, SPAR_QNAME, t_box_dv_uname_string ("http://www.w3.org/1999/02/22-rdf-syntax-ns#first")),
		    $1 ) ); }
	| spar_cons_collection spar_graph_node {
		SPART *bn = spar_make_blank_node (sparp_arg, spar_mkid (sparp_arg, "_:cons"), 1); 
		spar_gp_add_member (sparp_arg,
		  spar_make_triple (sparp_arg,
		    NULL, NULL,
		    spartlist (sparp_arg, 2, SPAR_QNAME, t_box_dv_uname_string ("http://www.w3.org/1999/02/22-rdf-syntax-ns#rest")),
		    bn ) );
		sparp_env()->spare_context_subjects->data = bn;
		spar_gp_add_member (sparp_arg,
		  spar_make_triple (sparp_arg, NULL, NULL,
		    spartlist (sparp_arg, 2, SPAR_QNAME, t_box_dv_uname_string ("http://www.w3.org/1999/02/22-rdf-syntax-ns#first")),
		    $2 ) ); }
	;

spar_graph_node		/* [37]  	GraphNode	  ::=  	VarOrTerm | TriplesNode	*/
	: spar_var_or_term
	| spar_triples_node
	;

spar_var_or_term	/* [38]  	VarOrTerm	  ::=  	Var | GraphTerm	*/
	:  spar_var
	|  spar_graph_term
	;

spar_var_or_irirefs
	: spar_var_or_iriref				{ $$ = NULL; t_set_push (&($$), $1); }
	| spar_var_or_irirefs spar_var_or_iriref	{ $$ = $1; t_set_push (&($$), $2); }
	;

spar_var_or_iriref	/* [39]  	VarOrIRIref	  ::=  	Var | IRIref	*/
	:  spar_var
	|  spar_iriref
	;

spar_var_or_blank_node_or_iriref	/* [40]  	VarOrBlankNodeOrIRIref	  ::=  	Var | BlankNode | IRIref	*/
	:  spar_var
	|  spar_blank_node
	|  spar_iriref
	;

spar_rset_items
	: spar_rset_item			{ $$ = NULL; t_set_push (&($$), $1); }
	| spar_rset_items spar_rset_item	{ $$ = $1; t_set_push (&($$), $2); }
	;

spar_rset_item
	: spar_var
        | _LPAR spar_expn _RPAR	{ $$ = $2; }
	;

spar_var		/* [41]  	Var	  ::=  	VAR1 | VAR2	*/
	: QUEST_VARNAME			{ $$ = spar_make_variable (sparp_arg, $1); }
	| DOLLAR_VARNAME		{ $$ = spar_make_variable (sparp_arg, $1); }
	| QUEST_COLON_PARAMNAME		{ $$ = spar_make_variable (sparp_arg, $1); }
	| DOLLAR_COLON_PARAMNAME	{ $$ = spar_make_variable (sparp_arg, $1); }
	| QUEST_COLON_PARAMNUM		{ $$ = spar_make_variable (sparp_arg, $1); }
	| DOLLAR_COLON_PARAMNUM		{ $$ = spar_make_variable (sparp_arg, $1); }
	;

spar_graph_term		/* [42]  	GraphTerm	  ::=  	IRIref | RDFLiteral | ( '-' | '+' )? NumericLiteral | BooleanLiteral | BlankNode | NIL	*/
	: spar_iriref			{ $$ = $1; }
	| spar_rdf_literal		{ $$ = $1; }
	| spar_numeric_literal		{ $$ = $1; }
	| _PLUS spar_numeric_literal	{ $$ = $2; }
	| _MINUS spar_numeric_literal	{ $$ = $2; spar_change_sign (&($2->_.lit.val)); }
        | spar_boolean_literal		{ $$ = $1; }
        | spar_blank_node		{ $$ = $1; }
	| NIL_L				{ $$ = t_box_dv_uname_string ("http://www.w3.org/1999/02/22-rdf-syntax-ns#nil"); }
	| _BACKQUOTE spar_expn _BACKQUOTE {	/* Nonstandard extension */
		  if (CONSTRUCT_L == (ptrlong)(sparp_env()->spare_context_gp_subtypes->data))
                    $$ = $2;
                  else
		    {
		      SPART *bn = spar_make_blank_node (sparp_arg, spar_mkid (sparp_arg, "_:calc"), 1);
		      SPART *eq;
		      SPAR_BIN_OP (eq, BOP_EQ, t_full_box_copy_tree ((caddr_t)bn), $2);
                      spar_gp_add_filter (sparp_arg, eq);
		      $$ = bn;
                    }
		}
	;

spar_expn		/* [43]  	Expression	  ::=  	ConditionalOrExpression	*/
	: spar_expn _BAR_BAR spar_expn { /* [44]  	ConditionalOrExpression	  ::=  	ConditionalAndExpression ( '||' ConditionalAndExpression )*	*/
		  SPAR_BIN_OP ($$, BOP_OR, $1, $3); }
	| spar_expn _AMP_AMP spar_expn { /* [45]  	ConditionalAndExpression	  ::=  	ValueLogical ( '&&' ValueLogical )*	[46]  	ValueLogical	  ::=  	RelationalExpression	*/
		  SPAR_BIN_OP ($$, BOP_AND, $1, $3); }
	| spar_expn _EQ spar_expn {	/* [47]  	RelationalExpression	  ::=  	NumericExpression ( ('='|'!='|'<'|'>'|'<='|'>=') NumericExpression )?	*/
		  SPAR_BIN_OP ($$, BOP_EQ, $1, $3); }
	| spar_expn _NOT_EQ spar_expn	{ SPAR_BIN_OP ($$, BOP_NEQ, $1, $3); }
	| spar_expn _LT spar_expn	{ SPAR_BIN_OP ($$, BOP_LT, $1, $3); }
	| spar_expn _GT spar_expn	{ SPAR_BIN_OP ($$, BOP_LT, $3, $1); }
	| spar_expn _LE spar_expn	{ SPAR_BIN_OP ($$, BOP_LTE, $1, $3); }
	| spar_expn _GE spar_expn	{ SPAR_BIN_OP ($$, BOP_LTE, $3, $1); }
	| spar_expn _PLUS spar_expn {	/* [49]  	AdditiveExpression	  ::=  	MultiplicativeExpression ( ('+'|'-') MultiplicativeExpression )*	*/
		  SPAR_BIN_OP ($$, BOP_PLUS, $1, $3); }
	| spar_expn _MINUS spar_expn	{ SPAR_BIN_OP ($$, BOP_MINUS, $1, $3); }
	| spar_expn _STAR spar_expn {	/* [50]  	MultiplicativeExpression	  ::=  	UnaryExpression ( ('*'|'/') UnaryExpression )*	*/
		  SPAR_BIN_OP ($$, BOP_TIMES, $1, $3); }
	| spar_expn _SLASH spar_expn	{ SPAR_BIN_OP ($$, BOP_DIV, $1, $3); }
	| _BANG spar_expn {		/* [51]  	UnaryExpression	  ::=  	  ('!'|'+'|'-')? PrimaryExpression */
		SPAR_BIN_OP ($$, BOP_NOT, $2, NULL); }
	| _PLUS	spar_expn	%prec UPLUS	{ SPAR_BIN_OP ($$, BOP_PLUS, box_num_nonull (0), $2); }
	| _MINUS spar_expn	%prec UMINUS	{ SPAR_BIN_OP ($$, BOP_MINUS, box_num_nonull (0), $2); }
        | _LPAR spar_expn _RPAR	{ $$ = $2; }	/* [58]  	PrimaryExpression	  ::=  	BrackettedExpression | BuiltInCall | IRIrefOrFunction | RDFLiteral | NumericLiteral | BooleanLiteral | BlankNode | Var	*/
	| spar_built_in_call
	| spar_iriref spar_arg_list_opt {	/* [55]  	IRIrefOrFunction	  ::=  	IRIref ArgList? */
                  if (NULL == $2)
		    $$ = $1;
		  else
		    {
		      SPART **args = (SPART **)(((dk_set_t)NIL_L == $2) ? NULL : t_revlist_to_array ($2));
		      $$ = spartlist (sparp_arg, 4, SPAR_FUNCALL, $1->_.lit.val, BOX_ELEMENTS_0 (args), args);
		    } }
	| spar_rdf_literal		{ $$ = (SPART *)($1); }
	| spar_numeric_literal		{ $$ = (SPART *)($1); }
	| spar_boolean_literal		{ $$ = (SPART *)($1); }
	| spar_blank_node
	| spar_var
	;

spar_built_in_call	/* [52]  	BuiltInCall	  ::= */
	: STR_L _LPAR spar_expn _RPAR	/*... : 'STR' '(' Expression ')' */
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, STR_L, t_list (1, $3)); }
	| LANG_L _LPAR spar_expn _RPAR	/*... | 'LANG' '(' Expression ')' */
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, LANG_L, t_list (1, $3)); }
	| LANGMATCHES_L _LPAR spar_expn _COMMA spar_expn _RPAR	/*... | 'LANGMATCHES' '(' Expression ',' Expression ')' */
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, LANGMATCHES_L, t_list (2, $3, $5)); }
	| DATATYPE_L _LPAR spar_expn _RPAR	/*... | 'DATATYPE' '(' Expression ')' */
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, DATATYPE_L, t_list (1, $3)); }
	| BOUND_L _LPAR spar_var _RPAR	/*... | 'BOUND' '(' Var ')' */
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, BOUND_L, t_list (1, $3)); }
	| isIRI_L _LPAR spar_expn _RPAR	/*... | 'isIRI' '(' Expression ')' */
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, isIRI_L, t_list (1, $3)); }
	| isURI_L _LPAR spar_expn _RPAR	/*... | 'isURI' '(' Expression ')' */
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, isURI_L, t_list (1, $3)); }
	| isBLANK_L _LPAR spar_expn _RPAR	/*... | 'isBLANK' '(' Expression ')' */
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, isBLANK_L, t_list (1, $3)); }
	| isLITERAL_L _LPAR spar_expn _RPAR	/*... | 'isLITERAL' '(' Expression ')' */
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, isLITERAL_L, t_list (1, $3)); }
	| REGEX_L _LPAR spar_expn _COMMA spar_expn _RPAR	/*... | RegexExpression	*/
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, REGEX_L, t_list (2, $3, $5)); }
	| REGEX_L _LPAR spar_expn _COMMA spar_expn _COMMA spar_expn _RPAR	/*... [53]  	RegexExpression	  ::=  	'REGEX' '(' Expression ',' Expression ( ',' Expression )? ')'	*/
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, REGEX_L, t_list (3, $3, $5, $7)); }
	;

spar_function_call	/* [54]  	FunctionCall	  ::=  	IRIref ArgList	*/
	: spar_iriref spar_arg_list	{
                  SPART **args = (SPART **)(((dk_set_t)NIL_L == $2) ? NULL : t_revlist_to_array ($2));
		  $$ = spartlist (sparp_arg, 4, SPAR_FUNCALL, $1->_.lit.val, BOX_ELEMENTS_0 (args), args); }
	;

spar_arg_list_opt
	: /* empty */			{ $$ = NULL; }
	| spar_arg_list			{ $$ = $1; }
	;

spar_arg_list		/* [56]  	ArgList	  ::=  	( NIL | '(' Expression ( ',' Expression )* ')' )	*/
	: NIL_L				{ $$ = (dk_set_t)NIL_L; }
	| _LPAR spar_expns _RPAR	{ $$ = $2; }
	;

 spar_expns
	: spar_expn			{ $$ = NULL; t_set_push (&($$), $1); }
	| spar_expns _COMMA spar_expn   { $$ = $1; t_set_push (&($$), $3); }
	| spar_expns _COMMA error { sparyyerror ("Argument expected after comma"); }
	| spar_expns error { sparyyerror ("Comma or ')' expected after function argument"); }
	;

spar_numeric_literal	/* [59]  	NumericLiteral	  ::=  	INTEGER | DECIMAL | DOUBLE	*/
	: SPARQL_INTEGER	{ $$ = spartlist (sparp_arg, 4, SPAR_LIT, $1, uname_xmlschema_ns_uri_hash_integer, NULL); }
	| SPARQL_DECIMAL	{ $$ = spartlist (sparp_arg, 4, SPAR_LIT, $1, uname_xmlschema_ns_uri_hash_decimal, NULL); }
	| SPARQL_DOUBLE		{ $$ = spartlist (sparp_arg, 4, SPAR_LIT, $1, uname_xmlschema_ns_uri_hash_double, NULL); }
	;

spar_rdf_literal	/* [60]  	RDFLiteral	  ::=  	String ( LANGTAG | ( '^^' IRIref ) )?	*/
	: SPARQL_STRING				{ $$ = spartlist (sparp_arg, 4, SPAR_LIT, $1, NULL, NULL); }
	| SPARQL_STRING LANGTAG			{ $$ = spartlist (sparp_arg, 4, SPAR_LIT, $1, NULL, $2); }
	| SPARQL_STRING _CARET_CARET spar_iriref	{ $$ = spar_make_typed_literal (sparp_arg, $1, $3->_.lit.val, NULL); }
	;

spar_boolean_literal	/* [61]  	BooleanLiteral	  ::=  	'true' | 'false'	*/
	: true_L		{ $$ = spartlist (sparp_arg, 4, SPAR_LIT, 1, uname_xmlschema_ns_uri_hash_boolean, NULL); }
	| false_L		{ $$ = spartlist (sparp_arg, 4, SPAR_LIT, 0, uname_xmlschema_ns_uri_hash_boolean, NULL); }
	;

spar_iriref		/* [63]  	IRIref	  ::=  	Q_IRI_REF | QName	*/
	: Q_IRI_REF		{ $$ = spartlist (sparp_arg, 2, SPAR_QNAME, $1); }
	| spar_qname		{ $$ = $1; }
	;

spar_qname		/* [64]  	QName	  ::=  	QNAME | QNAME_NS	*/
	: QNAME			{ $$ = spartlist (sparp_arg, 2, SPAR_QNAME, sparp_expand_qname_prefix (sparp_arg, $1)); }
	| QNAME_NS		{ $$ = spartlist (sparp_arg, 2, SPAR_QNAME_NS, sparp_expand_qname_prefix (sparp_arg, $1)); }
	;

spar_blank_node		/* [65]  	BlankNode	  ::=  	BLANK_NODE_LABEL | ANON	*/
	: BLANK_NODE_LABEL	{ $$ = spar_make_blank_node (sparp_arg, $1, 0); }
	| _LSQBRA _RSQBRA	{ $$ = spar_make_blank_node (sparp_arg, spar_mkid (sparp_arg, "_:anon"), 1); }
	;

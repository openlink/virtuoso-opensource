/*
 *  $Id$
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
  caddr_t *boxes;
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
%token ALTER_L		/*:: PUNCT_SPAR_LAST("ALTER") ::*/
%token AS_L		/*:: PUNCT_SPAR_LAST("AS") ::*/
%token ASC_L		/*:: PUNCT_SPAR_LAST("ASC") ::*/
%token ASK_L		/*:: PUNCT_SPAR_LAST("ASK") ::*/
%token BASE_L		/*:: PUNCT_SPAR_LAST("BASE") ::*/
%token BIJECTION_L	/*:: PUNCT_SPAR_LAST("BIJECTION") ::*/
%token BOUND_L		/*:: PUNCT_SPAR_LAST("BOUND") ::*/
%token BY_L		/*:: PUNCT("BY"), SPAR, LAST("BY"), LAST("IDENTIFIED BY") ::*/
%token CLASS_L		/*:: PUNCT_SPAR_LAST("CLASS") ::*/
%token CREATE_L		/*:: PUNCT_SPAR_LAST("CREATE") ::*/
%token CONSTRUCT_L	/*:: PUNCT_SPAR_LAST("CONSTRUCT") ::*/
%token DATATYPE_L	/*:: PUNCT_SPAR_LAST("DATATYPE") ::*/
%token DEFINE_L		/*:: PUNCT_SPAR_LAST("DEFINE") ::*/
%token DELETE_L		/*:: PUNCT_SPAR_LAST("DELETE") ::*/
%token DESC_L		/*:: PUNCT_SPAR_LAST("DESC") ::*/
%token DESCRIBE_L	/*:: PUNCT_SPAR_LAST("DESCRIBE") ::*/
%token DISTINCT_L	/*:: PUNCT_SPAR_LAST("DISTINCT") ::*/
%token DROP_L		/*:: PUNCT_SPAR_LAST("DROP") ::*/
%token EXCLUSIVE_L	/*:: PUNCT_SPAR_LAST("EXCLUSIVE") ::*/
%token false_L		/*:: PUNCT_SPAR_LAST("false") ::*/
%token FILTER_L		/*:: PUNCT_SPAR_LAST("FILTER") ::*/
%token FROM_L		/*:: PUNCT_SPAR_LAST("FROM") ::*/
%token FUNCTION_L	/*:: PUNCT_SPAR_LAST("FUNCTION") ::*/
%token GRAPH_L		/*:: PUNCT_SPAR_LAST("GRAPH") ::*/
%token IDENTIFIED_L	/*:: PUNCT("WHERE"), SPAR, LAST1("IDENTIFIED BY"), LAST1("IDENTIFIED\r\nBY"), LAST1("IDENTIFIED #qq\r\nBY"), ERR("IDENTIFIED"), ERR("IDENTIFIED bad") ::*/
%token IN_L		/*:: PUNCT_SPAR_LAST("IN") ::*/
%token INDEX_L		/*:: PUNCT_SPAR_LAST("INDEX") ::*/
%token INFERENCE_L	/*:: PUNCT_SPAR_LAST("INFERENCE") ::*/
%token INSERT_L		/*:: PUNCT_SPAR_LAST("INSERT") ::*/
%token INTO_L		/*:: PUNCT_SPAR_LAST("INTO") ::*/
%token IRI_L		/*:: PUNCT_SPAR_LAST("IRI") ::*/
%token isBLANK_L	/*:: PUNCT_SPAR_LAST("isBLANK") ::*/
%token isIRI_L		/*:: PUNCT_SPAR_LAST("isIRI") ::*/
%token isLITERAL_L	/*:: PUNCT_SPAR_LAST("isLITERAL") ::*/
%token isURI_L		/*:: PUNCT_SPAR_LAST("isURI") ::*/
%token LANG_L		/*:: PUNCT_SPAR_LAST("LANG") ::*/
%token LANGMATCHES_L	/*:: PUNCT_SPAR_LAST("LANGMATCHES") ::*/
%token LIKE_L		/*:: PUNCT_SPAR_LAST("LIKE") ::*/
%token LIMIT_L		/*:: PUNCT_SPAR_LAST("LIMIT") ::*/
%token LITERAL_L	/*:: PUNCT_SPAR_LAST("LITERAL") ::*/
%token LOAD_L		/*:: PUNCT_SPAR_LAST("LOAD") ::*/
%token MAKE_L		/*:: PUNCT_SPAR_LAST("MAKE") ::*/
%token MODIFY_L		/*:: PUNCT_SPAR_LAST("MODIFY") ::*/
%token NAMED_L		/*:: PUNCT_SPAR_LAST("NAMED") ::*/
%token NIL_L		/*:: PUNCT_SPAR_LAST("NIL") ::*/
%token NOT_L		/*:: PUNCT_SPAR_LAST("NOT") ::*/
%token NULL_L		/*:: PUNCT_SPAR_LAST("NULL") ::*/
%token OBJECT_L		/*:: PUNCT_SPAR_LAST("OBJECT") ::*/
%token OF_L		/*:: PUNCT_SPAR_LAST("OF") ::*/
%token OFFSET_L		/*:: PUNCT_SPAR_LAST("OFFSET") ::*/
%token OPTIONAL_L	/*:: PUNCT_SPAR_LAST("OPTIONAL") ::*/
%token OPTION_L		/*:: PUNCT_SPAR_LAST("OPTION") ::*/
%token ORDER_L		/*:: PUNCT_SPAR_LAST("ORDER") ::*/
%token PREDICATE_L	/*:: PUNCT_SPAR_LAST("PREDICATE") ::*/
%token PREFIX_L		/*:: PUNCT_SPAR_LAST("PREFIX") ::*/
%token QUAD_L		/*:: PUNCT_SPAR_LAST("QUAD") ::*/
%token REGEX_L		/*:: PUNCT_SPAR_LAST("REGEX") ::*/
%token RETURNS_L	/*:: PUNCT_SPAR_LAST("RETURNS") ::*/
%token SELECT_L		/*:: PUNCT_SPAR_LAST("SELECT") ::*/
%token STR_L		/*:: PUNCT_SPAR_LAST("STR") ::*/
%token STORAGE_L	/*:: PUNCT_SPAR_LAST("STORAGE") ::*/
%token SUBCLASS_L	/*:: PUNCT_SPAR_LAST("SUBCLASS") ::*/
%token SUBJECT_L	/*:: PUNCT_SPAR_LAST("SUBJECT") ::*/
%token true_L		/*:: PUNCT_SPAR_LAST("true") ::*/
%token UNION_L		/*:: PUNCT_SPAR_LAST("UNION") ::*/
%token USING_L		/*:: PUNCT_SPAR_LAST("USING") ::*/
%token WHERE_L		/*:: PUNCT("WHERE"), SPAR, LAST1("WHERE {"), LAST1("WHERE ("), LAST1("WHERE #cmt\n{"), LAST1("WHERE\r\n("), ERR("WHERE"), ERR("WHERE bad") ::*/
%token __SPAR_PUNCT_END	/* Delimiting value for syntax highlighting */

%token START_OF_SPARQL_TEXT	/*:: FAKE("the beginning of SPARQL text"), SPAR, NULL ::*/
%token END_OF_SPARQL_TEXT	/*:: FAKE("the end of SPARQL text"), SPAR, NULL ::*/

%token __SPAR_NONPUNCT_START	/* Delimiting value for syntax highlighting */

%token <box> TEXT_BL	/*:: PUNCT_SPAR_LAST("TEXT") ::*/
%token <box> XML_BL	/*:: PUNCT_SPAR_LAST("XML") ::*/

%token <box> SPARQL_INTEGER	/*:: LITERAL("%d"), SPAR, LAST("1234") ::*/
%token <box> SPARQL_DECIMAL	/*:: LITERAL("%d"), SPAR, LAST("1234.56") ::*/
%token <box> SPARQL_DOUBLE	/*:: LITERAL("%d"), SPAR, LAST("1234.56e1") ::*/

%token <box> SPARQL_STRING /*:: LITERAL("%s"), SPAR, LAST("'sq'"), LAST("\"dq\""), LAST("'''sq1\nsq2'''"), LAST("\"\"\"dq1\ndq2\"\"\""), LAST("'\"'"), LAST("'-\\\\-\\t-\\v-\\r-\\'-\\\"-\\u1234-\\U12345678-\\uaAfF-'") ::*/
%token <box> SPARQL_CONDITION_AFTER_WHERE_LPAR /*:: LITERAL("%s)"), SPAR, LAST("WHERE ('sq')"), LAST("WHERE (\"dq)\")"), LAST("WHERE ('sq1'')sq2')"), LAST("WHERE (--cmt1)\n)"), LAST("WHERE (/" "*)*" "/") ::*/
%token <box> LANGTAG	/*:: LITERAL("@%s"), SPAR, LAST("@ES") ::*/

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

%token <box> SPARQL_PLAIN_ID	/*:: LITERAL("%s"), SPAR, LAST("q"), LAST("a1"), LAST("_ABYZabyz0189") ::*/
%token <box> SPARQL_SQL_ALIASCOLNAME	/*:: LITERAL("%s"), SPAR, LAST("ALIAS.COL") ::*/
%token <box> SPARQL_SQL_QTABLENAME	/*:: LITERAL("%s"), SPAR, LAST("DB.DBA.SYS_USERS"), LAST("\"Demo\".\"demo\".\"Customers\""), LAST("DB..SYS_USERS"), LAST("\"Demo\"..\"Customers\"") ::*/
%token <box> SPARQL_SQL_QTABLECOLNAME	/*:: LITERAL("%s"), SPAR, LAST("DB.DBA.SYS_USERS.U_NAME"), LAST("\"Demo\".\"demo\".\"Customers\".\"CustomerID\""), LAST("DB..SYS_USERS.U_NAME"), LAST("\"Demo\"..\"Customers\".\"CustomerID\"") ::*/

%token __SPAR_NONPUNCT_END	/* Delimiting value for syntax highlighting */

%type <tree> sparql
/* nonterminals from part 1: */
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
%type <tree> spar_insert_query
%type <tree> spar_delete_query
%type <tree> spar_describe_query
%type <trees> spar_describe_rset
%type <tree> spar_ask_query
%type <nothing> spar_dataset_clauses_opt
%type <nothing> spar_dataset_clause
%type <trees> spar_sponge_optionlist_opt
%type <backstack> spar_sponge_option_commalist
%type <tree> spar_precode_expn
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
%type <nothing> spar_objects
%type <nothing> spar_ograph_node
%type <trees> spar_triple_optionlist_opt
%type <backstack> spar_triple_option_commalist
%type <trees> spar_triple_option
%type <tree> spar_verb
%type <tree> spar_triples_node
%type <nothing> spar_cons_collection
%type <tree> spar_graph_node
%type <tree> spar_var_or_term
%type <backstack> spar_var_or_iriref_or_backquoteds
%type <tree> spar_var_or_blank_node_or_iriref_or_backquoted
%type <tree> spar_var_or_iriref_or_backquoted
%type <backstack> spar_retcols
%type <tree> spar_retcol
%type <tree> spar_retcol_value
%type <tree> spar_var
%type <tree> spar_global_var
%type <tree> spar_graph_term
%type <tree> spar_backquoted
%type <backstack> spar_expns
%type <tree> spar_expn
%type <tree> spar_built_in_call
%type <tree> spar_built_in_regex
%type <tree> spar_function_call
%type <backstack> spar_arg_list_opt
%type <backstack> spar_arg_list
%type <tree> spar_numeric_literal
%type <tree> spar_rdf_literal
%type <tree> spar_boolean_literal
%type <tree> spar_iriref
%type <tree> spar_qname
%type <tree> spar_blank_node
/* nonterminals from part 2: */
%type <nothing> spar_qm_stmts
%type <nothing> spar_qm_stmt
%type <tree> spar_qm_simple_stmt
%type <tree> spar_qm_create_iri_class
%type <tree> spar_qm_drop_iri_class
%type <tree> spar_qm_create_iri_subclass
%type <tree> spar_qm_create_literal_class
%type <tree> spar_qm_drop_literal_class
%type <trees> spar_qm_iri_class_optionlist_opt
%type <backstack> spar_qm_iri_class_option_commalist
%type <trees> spar_qm_iri_class_option
%type <backstack> spar_qm_sprintff_list
%type <trees> spar_qm_literal_class_optionlist_opt
%type <backstack> spar_qm_literal_class_option_commalist
%type <boxes> spar_qm_literal_class_option
%type <nothing> spar_qm_create_quad_storage
%type <nothing> spar_qm_alter_quad_storage
%type <tree> spar_qm_drop_quad_storage
%type <tree> spar_qm_drop_mapping
%type <nothing> spar_qm_from_where_list_opt
%type <nothing> spar_qm_map_top_group
%type <nothing> spar_qm_map_top_dotlist
%type <nothing> spar_qm_map_top_op
%type <nothing> spar_qm_map_group
%type <nothing> spar_qm_map_dotlist
%type <nothing> spar_qm_map_op
%type <nothing> spar_qm_map_iddef
%type <nothing> spar_qm_map_single
%type <nothing> spar_qm_text_literal_list_opt
%type <nothing> spar_qm_text_literal_decl
%type <box> spar_xml_opt
%type <trees> spar_of_sqlcol_opt
%type <trees> spar_qm_text_literal_options_opt
%type <backstack> spar_qm_text_literal_option_commalist
%type <trees> spar_qm_text_literal_option
%type <nothing> spar_qm_triples1
%type <nothing> spar_qm_named_fields
%type <nothing> spar_qm_named_field
%type <nothing> spar_qm_props
%type <nothing> spar_qm_prop
%type <nothing> spar_qm_obj_field_commalist
%type <trees> spar_qm_obj_field
%type <box> spar_qm_as_id_opt
%type <tree> spar_qm_verb
%type <tree> spar_qm_field_or_blank
%type <tree> spar_qm_field
%type <backstack> spar_qm_where_list_opt
%type <backstack> spar_qm_where_list
%type <box> spar_qm_where
%type <trees> spar_qm_options_opt
%type <backstack> spar_qm_option_commalist
%type <trees> spar_qm_option
%type <backstack> spar_qm_sqlcol_commalist_opt
%type <backstack> spar_qm_sqlcol_commalist
%type <backstack> spar_qm_sqlfunc_header_commalist
%type <tree> spar_qm_sqlfunc_header
%type <tree> spar_qm_sqlfunc_arglist
%type <backstack> spar_qm_sqlfunc_arg_commalist_opt
%type <backstack> spar_qm_sqlfunc_arg_commalist
%type <tree> spar_qm_sqlfunc_arg
%type <tree> spar_qm_sql_in_out_inout
%type <boxes> spar_qm_sqltype
%type <tree> spar_qm_sqlcol
%type <box> spar_qm_sql_id
%type <box> spar_qm_iriref_const_expn
%type <nothing> spar_graph_identified_by
%type <nothing> spar_opt_dot_and_end

%left _SEMI
%left _COLON
%left _BAR_BAR
%left _AMP_AMP
%nonassoc _BANG
%nonassoc _EQ _NOT_EQ
%nonassoc IN_L LIKE_L
%nonassoc _LT _LE _GT _GE 
%left _PLUS _MINUS
%left _SLASH _STAR
%nonassoc UMINUS
%nonassoc UPLUS
%left _LSQBRA _RSQBRA _LPAR _RPAR

%%

/* TOP-LEVEL begin */
sparql	/* [1]*	Query		 ::=  Prolog ( QueryBody | ( QmStmt ('.' QmStmt)* '.'? ) )	*/
	: START_OF_SPARQL_TEXT spar_prolog spar_query_body END_OF_SPARQL_TEXT { sparp_arg->sparp_expr = $$ = $3; }
	| START_OF_SPARQL_TEXT spar_prolog spar_qm_stmts spar_opt_dot_and_end { 
		$$ = spar_make_topmost_qm_sql (sparp_arg);
		sparp_arg->sparp_expr = $$; }
	| START_OF_SPARQL_TEXT END_OF_SPARQL_TEXT	{ yyerror ("The SPARQL expression is totally empty"); }
	| error { sparyyerror ("(internal SPARQL processing error) SPARQL mark expected"); }
	;

/* PART 1. Standard SPARQL as described by W3C, with Virtuoso extensions for expressions. */

spar_query_body		/* [1]*	QueryBody	 ::=  SelectQuery | ConstructQuery | InsertQuery | DeleteQuery | DescribeQuery | AskQuery */
        : spar_select_query
	| spar_construct_query
	| spar_insert_query
	| spar_delete_query
	| spar_describe_query
	| spar_ask_query
	;

spar_prolog		/* [2]*	Prolog		 ::=  Define* BaseDecl? PrefixDecl*	*/
	: spar_defines_opt spar_base_decl_opt spar_prefix_decls_opt
	;

spar_defines_opt	/* ::=  Define*	*/
        : /* empty */	{ ; }
        | spar_defines_opt spar_define	{ ; }
	;

spar_define		/* [Virt]	Define		 ::=  'DEFINE' QNAME (QNAME | Q_IRI_REF | String )	*/
        : DEFINE_L QNAME QNAME { sparp_define (sparp_arg, $2, QNAME, $3); }
        | DEFINE_L QNAME Q_IRI_REF { sparp_define (sparp_arg, $2, Q_IRI_REF, $3); }
	| DEFINE_L QNAME SPARQL_STRING { sparp_define (sparp_arg, $2, SPARQL_STRING, $3); }
	| DEFINE_L QNAME SPARQL_INTEGER { sparp_define (sparp_arg, $2, SPARQL_INTEGER, $3); }
	| DEFINE_L QNAME spar_global_var { sparp_define (sparp_arg, $2, SPAR_VARIABLE, (caddr_t)$3); }
	;

spar_base_decl_opt	/* [3]  	BaseDecl	  ::=  	'BASE' Q_IRI_REF	*/
	: /* empty */		{ ; }
	| BASE_L Q_IRI_REF	{
		if (NULL != sparp_env()->spare_base_uri)
		  sparyyerror ("Only one base declaration is allowed");
		sparp_env()->spare_base_uri = $2; }
	| BASE_L error { sparyyerror ("Missing <iri-string> after BASE keyword"); }
	;

spar_prefix_decls_opt	/* ::=  PrefixDecl*	*/
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

spar_select_query	/* [5]*	SelectQuery	 ::=  'SELECT' 'DISTINCT'? ( ( Retcol ( ','? Retcol )* ) | '*' ) DatasetClause* WhereClause SolutionModifier	*/
	: spar_select_query_mode { spar_selid_push (sparp_arg); }
	    spar_select_rset spar_dataset_clauses_opt { spar_gp_init (sparp_arg, WHERE_L); }
            spar_where_clause spar_solution_modifier {
		$$ = spar_make_top (sparp_arg, $1, $3, spar_selid_pop (sparp_arg),
		  $6, (SPART **)($7[0]), (caddr_t)($7[1]), (caddr_t)($7[2]) ); }
	;

spar_select_query_mode	/* ::=  'SELECT' 'DISTINCT'?	*/
	: SELECT_L		{ $$ = SELECT_L; }
	| SELECT_L DISTINCT_L	{ $$ = DISTINCT_L; }
	;

spar_select_rset	/* ::=  ( ( Retcol ( ','? Retcol )* ) | '*' )	*/
	: _STAR			{ $$ = (SPART **) _STAR; }
	| spar_retcols	{ $$ = (SPART **) t_revlist_to_array ($1); }
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

spar_insert_query	/* [Virt]	InsertQuery	 ::=  'INSERT' 'IN' 'GRAPH' PrecodeExpn ConstructTemplate DatasetClause* WhereClause SolutionModifier	*/
	: INSERT_L IN_L spar_graph_identified_by spar_precode_expn { spar_selid_push (sparp_arg); }
            spar_ctor_template spar_dataset_clauses_opt { spar_gp_init (sparp_arg, WHERE_L); }
	    spar_where_clause spar_solution_modifier {
		$$ = spar_make_top (sparp_arg, INSERT_L,
                  spar_retvals_of_insert (sparp_arg, $4, $6),
                  spar_selid_pop (sparp_arg),
		  $9, (SPART **)($10[0]), (caddr_t)($10[1]), (caddr_t)($10[2]) ); }
	;

spar_delete_query	/* [Virt]	DeleteQuery	 ::=  'DELETE' 'FROM' 'GRAPH' PrecodeExpn ConstructTemplate DatasetClause* WhereClause SolutionModifier	*/
	: DELETE_L FROM_L spar_graph_identified_by spar_precode_expn { spar_selid_push (sparp_arg); }
            spar_ctor_template spar_dataset_clauses_opt { spar_gp_init (sparp_arg, WHERE_L); }
	    spar_where_clause spar_solution_modifier {
		$$ = spar_make_top (sparp_arg, DELETE_L,
                  spar_retvals_of_delete (sparp_arg, $4, $6),
                  spar_selid_pop (sparp_arg),
		  $9, (SPART **)($10[0]), (caddr_t)($10[1]), (caddr_t)($10[2]) ); }
	;


spar_describe_query	/* [7]*	DescribeQuery	 ::=  'DESCRIBE' ( VarOrIRIrefOrBackquoted+ | '*' ) DatasetClause* WhereClause? SolutionModifier	*/
	: DESCRIBE_L { spar_selid_push (sparp_arg); }
            spar_describe_rset spar_dataset_clauses_opt { spar_gp_init (sparp_arg, WHERE_L); }
	    spar_where_clause_opt spar_solution_modifier {
		$$ = spar_make_top (sparp_arg, DESCRIBE_L, 
                  $3,
                  spar_selid_pop (sparp_arg),
		  $6, (SPART **)($7[0]), (caddr_t)($7[1]), (caddr_t)($7[2]) ); }
	;

spar_describe_rset	/* ::=  ( VarOrIRIrefOrBackquoted+ | '*' )	*/
	: _STAR			{ $$ = (SPART **) _STAR; }
	| spar_var_or_iriref_or_backquoteds	{ $$ = (SPART **) t_list_to_array ($1); }
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
	: FROM_L spar_iriref spar_sponge_optionlist_opt {			/* [10]*	DefaultGraphClause	 ::=  SourceSelector SpongeOptionList?	*/
                if (0 == sparp_env()->spare_default_graphs_locked)
                  t_set_push (&(sparp_env()->spare_default_graph_precodes),
                    sparp_make_graph_precode (sparp_arg, $2, $3) ); }
	| FROM_L NAMED_L spar_iriref spar_sponge_optionlist_opt {		/* [11]*	NamedGraphClause	 ::=  'NAMED' SourceSelector SpongeOptionList?	*/
                if (0 == sparp_env()->spare_named_graphs_locked)
                  t_set_push (&(sparp_env()->spare_named_graph_precodes),
                    sparp_make_graph_precode (sparp_arg, $3, $4) ); }
	;

spar_sponge_optionlist_opt	/* [Virt]	SpongeOptionList	 ::=  'OPTION' '(' ( SpongeOption ( ',' SpongeOption )* )? ')'	*/
	: /*empty*/		{ $$ = NULL; }
	| OPTION_L _LPAR _RPAR	{ $$ = (SPART **)t_list (0); }
	| OPTION_L _LPAR spar_sponge_option_commalist _RPAR	{ $$ = (SPART **)t_revlist_to_array ($3); }
	;

spar_sponge_option_commalist	/* ::=  SpongeOption ( ',' SpongeOption )* */
	: QNAME spar_precode_expn	{	/* [Virt]	SpongeOption	 ::=  QNAME PrecodeExpn */
		$$ = NULL; t_set_push (&($$), $1); t_set_push (&($$), $2); }
	| spar_sponge_option_commalist _COMMA QNAME spar_precode_expn {
		$$ = $1; t_set_push (&($$), $3); t_set_push (&($$), $4); }
	;

spar_precode_expn	/* [Virt]	PrecodeExpn	 ::=  Expn	(* Only global variables can occur in Expn, local can not *)	*/
	: { sparp_arg->sparp_in_precode_expn = 1; }
	  spar_expn
	  { sparp_arg->sparp_in_precode_expn = 0; $$ = $2; }
	;

spar_where_clause_opt	/* ::=  WhereClause?	*/
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

spar_order_conditions	/* ::=  OrderCondition+	*/
	: spar_order_condition				{ $$ = NULL; t_set_push (&($$), $1); }
	| spar_order_conditions spar_order_condition	{ $$ = $1; t_set_push (&($$), $2); }
	;

spar_order_condition	/* [16]*	OrderCondition	 ::=  ( 'ASC' | 'DESC' )? ( FunctionCall | Var | ( '(' Expn ')' ) | ( '[' Expn ']' ) )	*/
	: spar_asc_or_desc_opt _LPAR spar_expn _RPAR		{ $$ = spartlist (sparp_arg, 3, ORDER_L, $1, $3); }
	| spar_asc_or_desc_opt _LSQBRA spar_expn _RSQBRA	{ $$ = spartlist (sparp_arg, 3, ORDER_L, $1, $3); }
	| spar_function_call					{ $$ = spartlist (sparp_arg, 3, ORDER_L, ASC_L, $1); }
	| spar_var						{ $$ = spartlist (sparp_arg, 3, ORDER_L, ASC_L, $1); }
	;

spar_asc_or_desc_opt	/* ::=  ( 'ASC' | 'DESC' )? */
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
	    spar_var_or_blank_node_or_iriref_or_backquoted { t_set_push (&(sparp_env()->spare_context_graphs), $2); }
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

spar_constraint		/* [25]*	Constraint	 ::=  'FILTER' ( ( '(' Expn ')' ) | BuiltInCall | FunctionCall )	*/
	: FILTER_L _LPAR spar_expn _RPAR	{ $$ = $3; }
	| FILTER_L spar_built_in_call	{ $$ = $2; }
	| FILTER_L spar_function_call	{ $$ = $2; }
	;

spar_ctor_template	/* [26]*	ConstructTemplate	 ::=  '{' ConstructTriples '}'	*/
	: _LBRA { spar_gp_init (sparp_arg, CONSTRUCT_L); }
	    spar_ctor_triples_opt _RBRA { $$ = spar_gp_finalize (sparp_arg); }
	;

spar_ctor_triples_opt	/* [27]  	ConstructTriples	  ::=  	( Triples1 ( '.' ConstructTriples )? )?	*/
	: /* empty */ { }
	| spar_ctor_triples { }
	| spar_ctor_triples _DOT { }
	;

spar_ctor_triples	/* ::=  Triples1 ( '.' Triples1 )* */
	: spar_triples1				{ }
	| spar_ctor_triples _DOT spar_triples1	{ }
	;

spar_triples_opt	/* ::=  Triples?	*/
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
	    spar_objects { t_set_pop (&(sparp_env()->spare_context_predicates)); }
	| spar_props _SEMI
	    spar_verb { t_set_push (&(sparp_env()->spare_context_predicates), $3); }
	    spar_objects { t_set_pop (&(sparp_env()->spare_context_predicates)); }
	| spar_props _SEMI error { sparyyerror ("Predicate expected after semicolon"); }
	| error { sparyyerror ("Predicate expected"); }
	;

spar_objects		/* [32]*	ObjectList	 ::=  ObjGraphNode ( ',' ObjectList )?	*/
	: spar_ograph_node { }
	| spar_objects _COMMA spar_ograph_node { }
	| spar_objects _COMMA error { sparyyerror ("Object expected after comma"); }
	| error { sparyyerror ("Object expected"); }
	;

spar_ograph_node	/* [Virt]	ObjGraphNode	 ::=  GraphNode TripleOptions?	*/
	: spar_graph_node spar_triple_optionlist_opt {
		spar_gp_add_triple_or_special_filter (sparp_arg, NULL, NULL, NULL, $1, $2); }
	;

spar_triple_optionlist_opt	/* [Virt]	TripleOptions	 ::=  'OPTION' '(' TripleOption ( ',' TripleOption )? ')'	*/
	: /* empty */	{ $$ = NULL; }
	| OPTION_L _LPAR spar_triple_option_commalist _RPAR { $$ = (SPART **)t_revlist_to_array ($3); }
	;

spar_triple_option_commalist
	: spar_triple_option	{ $$ = NULL; t_set_push (&($$), ((SPART **)($1))[0]); t_set_push (&($$), ((SPART **)($1))[1]); }
	| spar_triple_option_commalist _COMMA spar_triple_option	{ $$ = $1;  t_set_push (&($$), ((SPART **)($3))[0]); t_set_push (&($$), ((SPART **)($3))[1]); }
	;

spar_triple_option	/* [Virt]	TripleOption	 ::=  'INFERENCE' ( QNAME | Q_IRI_REF | SPARQL_STRING )	*/
	: INFERENCE_L SPARQL_PLAIN_ID {
		if (strcasecmp ($2, "none"))
		  $$ = (SPART **)t_list (2, INFERENCE_L, $2);
		else
		  $$ = (SPART **)t_list (2, INFERENCE_L, NULL); }
	| INFERENCE_L QNAME {
		  $$ = (SPART **)t_list (2, INFERENCE_L, sparp_expand_qname_prefix (sparp_arg, $2)); }
        | INFERENCE_L Q_IRI_REF { $$ = (SPART **)t_list (2, INFERENCE_L, $2); }
	| INFERENCE_L SPARQL_STRING { $$ = (SPART **)t_list (2, INFERENCE_L, $2); }
	;

spar_verb		/* [33]  	Verb	  ::=  	VarOrBlankNodeOrIRIref | 'a'	*/
	: spar_var_or_iriref_or_backquoted
	| a_L { $$ = spartlist (sparp_arg, 2, SPAR_QNAME, uname_rdf_ns_uri_type); }
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
		spar_gp_add_triple_or_special_filter (sparp_arg,
		    NULL, NULL,
		    spartlist (sparp_arg, 2, SPAR_QNAME, uname_rdf_ns_uri_rest),
		  spartlist (sparp_arg, 2, SPAR_QNAME, uname_rdf_ns_uri_nil),
		  NULL );
		t_set_pop (&(sparp_env()->spare_context_subjects));
		$$ = t_set_pop (&(sparp_env()->spare_context_subjects)); }
	;

spar_triples_opt_semi_rsqbra	/* ::=  ';'? ']'	*/
	: _RSQBRA {}
	| _SEMI _RSQBRA {}
	;

spar_cons_collection	/* [32]  	ObjectList	  ::=  	GraphNode ( ',' ObjectList )?	*/
	: spar_graph_node {
		spar_gp_add_triple_or_special_filter (sparp_arg, NULL, NULL,
		    spartlist (sparp_arg, 2, SPAR_QNAME, uname_rdf_ns_uri_first),
		  $1, NULL ); }
	| spar_cons_collection spar_graph_node {
		SPART *bn = spar_make_blank_node (sparp_arg, spar_mkid (sparp_arg, "_:cons"), 1); 
		spar_gp_add_triple_or_special_filter (sparp_arg,
		    NULL, NULL,
		    spartlist (sparp_arg, 2, SPAR_QNAME, uname_rdf_ns_uri_rest),
		  bn, NULL );
		sparp_env()->spare_context_subjects->data = bn;
		spar_gp_add_triple_or_special_filter (sparp_arg, NULL, NULL,
		    spartlist (sparp_arg, 2, SPAR_QNAME, uname_rdf_ns_uri_first),
		  $2, NULL ); }
	;

spar_graph_node		/* [37]  	GraphNode	  ::=  	VarOrTerm | TriplesNode	*/
	: spar_var_or_term
	| spar_triples_node
	;

spar_var_or_term	/* [38]  	VarOrTerm	  ::=  	Var | GraphTerm	*/
	:  spar_var
	|  spar_graph_term
	;

spar_var_or_iriref_or_backquoteds	/* ::=  VarOrIRIrefOrBackquoted+	*/
	: spar_var_or_iriref_or_backquoted					{ $$ = NULL; t_set_push (&($$), $1); }
	| spar_var_or_iriref_or_backquoteds spar_var_or_iriref_or_backquoted	{ $$ = $1; t_set_push (&($$), $2); }
	;

spar_var_or_iriref_or_backquoted	/* [39]*	VarOrIRIrefOrBackquoted	 ::=  Var | IRIref | Backquoted	*/
	:  spar_var
	|  spar_iriref
	| spar_backquoted
	;

spar_var_or_blank_node_or_iriref_or_backquoted	/* [40]*	VarOrBlankNodeOrIRIrefOrBackquoted	 ::=  Var | BlankNode | IRIref | Backquoted	*/
	:  spar_var
	|  spar_blank_node
	|  spar_iriref
	| spar_backquoted
	;

spar_retcols		/* ::=  ( Retcol ( ','? Retcol )*	*/
	: spar_retcol			{ $$ = NULL; t_set_push (&($$), $1); }
	| spar_retcols spar_retcol	{ $$ = $1; t_set_push (&($$), $2); }
	| spar_retcols _COMMA spar_retcol	{ $$ = $1; t_set_push (&($$), $3); }
	;

spar_retcol		/* [Virt]	Retcol	 ::=  ( Var | ( '(' Expn ')' ) ) ( 'AS' ( VAR1 | VAR2 ) )?	*/
	: spar_retcol_value					{ $$ = $1; }
	| spar_retcol_value AS_L QUEST_VARNAME		{ $$ = spartlist (sparp_arg, 3, SPAR_ALIAS, $1, $3); }
	| spar_retcol_value AS_L DOLLAR_VARNAME		{ $$ = spartlist (sparp_arg, 3, SPAR_ALIAS, $1, $3); }
	;

spar_retcol_value	/* ::=  ( Var | ( '(' Expn ')' ) )	*/
	: spar_var
        | _LPAR spar_expn _RPAR	{ $$ = $2; }
	;

spar_var		/* [41]*	Var	 ::=  VAR1 | VAR2 | GlobalVar	*/
	: QUEST_VARNAME			{ $$ = spar_make_variable (sparp_arg, $1); }
	| DOLLAR_VARNAME		{ $$ = spar_make_variable (sparp_arg, $1); }
	| spar_global_var		{ $$ = $1; }
	;

spar_global_var		/* [Virt]	GlobalVar	 ::=  QUEST_COLON_PARAMNAME | DOLLAR_COLON_PARAMNAME | QUEST_COLON_PARAMNUM | DOLLAR_COLON_PARAMNUM	*/
	: QUEST_COLON_PARAMNAME		{ $$ = spar_make_variable (sparp_arg, $1); }
	| DOLLAR_COLON_PARAMNAME	{ $$ = spar_make_variable (sparp_arg, $1); }
	| QUEST_COLON_PARAMNUM		{ $$ = spar_make_variable (sparp_arg, $1); }
	| DOLLAR_COLON_PARAMNUM		{ $$ = spar_make_variable (sparp_arg, $1); }
	;

spar_graph_term		/* [42]*	GraphTerm	 ::=  IRIref | RDFLiteral | ( '-' | '+' )? NumericLiteral | BooleanLiteral | BlankNode | NIL | Backquoted	*/
	: spar_iriref			{ $$ = $1; }
	| spar_rdf_literal		{ $$ = $1; }
	| spar_numeric_literal		{ $$ = $1; }
	| _PLUS spar_numeric_literal	{ $$ = $2; }
	| _MINUS spar_numeric_literal	{ $$ = $2; spar_change_sign (&($2->_.lit.val)); }
        | spar_boolean_literal		{ $$ = $1; }
        | spar_blank_node		{ $$ = $1; }
	| NIL_L				{ $$ = t_box_dv_uname_string ("http://www.w3.org/1999/02/22-rdf-syntax-ns#nil"); }
	| spar_backquoted
	;

spar_backquoted		/* [Virt]	Backquoted	 ::=  '`' Expn '`'	*/
	: _BACKQUOTE spar_expn _BACKQUOTE {
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

spar_expn		/* [43]	Expn		 ::=  ConditionalOrExpn	*/
	: spar_expn _BAR_BAR spar_expn { /* [44]	ConditionalOrExpn	 ::=  ConditionalAndExpn ( '||' ConditionalAndExpn )*	*/
		  SPAR_BIN_OP ($$, BOP_OR, $1, $3); }
	| spar_expn _AMP_AMP spar_expn { /* [45]	ConditionalAndExpn	 ::=  ValueLogical ( '&&' ValueLogical )*	[46]	ValueLogical	 ::=  RelationalExpn	*/
		  SPAR_BIN_OP ($$, BOP_AND, $1, $3); }
	| spar_expn _EQ spar_expn {	/* [47]*	RelationalExpn	 ::=  NumericExpn ( ( ('='|'!='|'<'|'>'|'<='|'>='|'LIKE') NumericExpn ) | ( 'IN' '(' Expns ')' ) )?	*/
		  SPAR_BIN_OP ($$, BOP_EQ, $1, $3); }
	| spar_expn _NOT_EQ spar_expn	{ SPAR_BIN_OP ($$, BOP_NEQ, $1, $3); }
        | spar_expn LIKE_L spar_expn	{	/* Virtuoso-specific extension of [47] */
		$$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, LIKE_L, t_list (2, $1, $3)); }
        | spar_expn IN_L _LPAR spar_expns _RPAR	{	/* Virtuoso-specific extension of [47] */
                dk_set_t args = $4;
                t_set_push (&args, $1);
		$$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, IN_L, t_revlist_to_array (args)); }
	| spar_expn _LT spar_expn	{ SPAR_BIN_OP ($$, BOP_LT, $1, $3); }
	| spar_expn _GT spar_expn	{ SPAR_BIN_OP ($$, BOP_LT, $3, $1); }
	| spar_expn _LE spar_expn	{ SPAR_BIN_OP ($$, BOP_LTE, $1, $3); }
	| spar_expn _GE spar_expn	{ SPAR_BIN_OP ($$, BOP_LTE, $3, $1); }
	| spar_expn _PLUS spar_expn {	/* [49]	AdditiveExpn	 ::=  MultiplicativeExpn ( ('+'|'-') MultiplicativeExpn )*	*/
		  SPAR_BIN_OP ($$, BOP_PLUS, $1, $3); }
	| spar_expn _MINUS spar_expn	{ SPAR_BIN_OP ($$, BOP_MINUS, $1, $3); }
	| spar_expn _STAR spar_expn {	/* [50]	MultiplicativeExpn	 ::=  UnaryExpn ( ('*'|'/') UnaryExpn )*	*/
		  SPAR_BIN_OP ($$, BOP_TIMES, $1, $3); }
	| spar_expn _SLASH spar_expn	{ SPAR_BIN_OP ($$, BOP_DIV, $1, $3); }
	| _BANG spar_expn {		/* [51]	UnaryExpn	 ::=   ('!'|'+'|'-')? PrimaryExpn */
		SPAR_BIN_OP ($$, BOP_NOT, $2, NULL); }
	| _PLUS	spar_expn	%prec UPLUS	{ SPAR_BIN_OP ($$, BOP_PLUS, box_num_nonull (0), $2); }
	| _MINUS spar_expn	%prec UMINUS	{ SPAR_BIN_OP ($$, BOP_MINUS, box_num_nonull (0), $2); }
        | _LPAR spar_expn _RPAR	{ $$ = $2; }	/* [58]	PrimaryExpn	 ::=  BracketedExpn | BuiltInCall | IRIrefOrFunction | RDFLiteral | NumericLiteral | BooleanLiteral | BlankNode | Var	*/
	| spar_built_in_call
	| spar_iriref spar_arg_list_opt {	/* [55]  	IRIrefOrFunction	  ::=  	IRIref ArgList? */
                  if (NULL == $2)
		    $$ = $1;
		  else
		    {
		      SPART **args = (SPART **)(((dk_set_t)NIL_L == $2) ? NULL : t_revlist_to_array ($2));
		      $$ = spartlist (sparp_arg, 4, SPAR_FUNCALL, $1->_.lit.val, (ptrlong)(BOX_ELEMENTS_0 (args)), args);
		    } }
	| spar_rdf_literal		{ $$ = (SPART *)($1); }
	| spar_numeric_literal		{ $$ = (SPART *)($1); }
	| spar_boolean_literal		{ $$ = (SPART *)($1); }
	| spar_blank_node
	| spar_var
	;

spar_built_in_call	/* [52]*	BuiltInCall	 ::=  */
	: STR_L _LPAR spar_expn _RPAR		/*... ( 'STR' '(' Expn ')' ) */
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, STR_L, t_list (1, $3)); }
	| IRI_L _LPAR spar_expn _RPAR		/*... | ( 'IRI' '(' Expn ')' ) */
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, IRI_L, t_list (1, $3)); }
	| LANG_L _LPAR spar_expn _RPAR		/*... | ( 'LANG' '(' Expn ')' ) */
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, LANG_L, t_list (1, $3)); }
	| LANGMATCHES_L _LPAR spar_expn _COMMA spar_expn _RPAR	/*... | ( 'LANGMATCHES' '(' Expn ',' Expn ')' ) */
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, LANGMATCHES_L, t_list (2, $3, $5)); }
	| DATATYPE_L _LPAR spar_expn _RPAR	/*... | ( 'DATATYPE' '(' Expn ')' ) */
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, DATATYPE_L, t_list (1, $3)); }
	| BOUND_L _LPAR spar_var _RPAR		/*... | ( 'BOUND' '(' Var ')' ) */
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, BOUND_L, t_list (1, $3)); }
	| isIRI_L _LPAR spar_expn _RPAR		/*... | ( 'isIRI' '(' Expn ')' ) */
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, isIRI_L, t_list (1, $3)); }
	| isURI_L _LPAR spar_expn _RPAR		/*... | ( 'isURI' '(' Expn ')' ) */
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, isURI_L, t_list (1, $3)); }
	| isBLANK_L _LPAR spar_expn _RPAR	/*... | ( 'isBLANK' '(' Expn ')' ) */
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, isBLANK_L, t_list (1, $3)); }
	| isLITERAL_L _LPAR spar_expn _RPAR	/*... | ( 'isLITERAL' '(' Expn ')' ) */
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, isLITERAL_L, t_list (1, $3)); }
	| spar_built_in_regex		/*... | RegexExpn	*/
	;

spar_built_in_regex	/* [53]	RegexExpn	 ::=  'REGEX' '(' Expn ',' Expn ( ',' Expn )? ')'	*/
	: REGEX_L _LPAR spar_expn _COMMA spar_expn _RPAR
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, REGEX_L, t_list (2, $3, $5)); }
	| REGEX_L _LPAR spar_expn _COMMA spar_expn _COMMA spar_expn _RPAR
		{ $$ = spartlist (sparp_arg, 3, SPAR_BUILT_IN_CALL, REGEX_L, t_list (3, $3, $5, $7)); }
	;

spar_function_call	/* [54]  	FunctionCall	  ::=  	IRIref ArgList	*/
	: spar_iriref spar_arg_list	{
                  SPART **args = (SPART **)(((dk_set_t)NIL_L == $2) ? NULL : t_revlist_to_array ($2));
		  $$ = spartlist (sparp_arg, 4, SPAR_FUNCALL, $1->_.lit.val, (ptrlong)(BOX_ELEMENTS_0 (args)), args); }
	;

spar_arg_list_opt	/* ::=  ArgList?	*/
	: /* empty */			{ $$ = NULL; }
	| spar_arg_list			{ $$ = $1; }
	;

spar_arg_list		/* [56]*	ArgList	 ::=  ( NIL | '(' Expns ')' )	*/
	: NIL_L				{ $$ = (dk_set_t)NIL_L; }
	| _LPAR spar_expns _RPAR	{ $$ = $2; }
	;

spar_expns		/* [Virt]	Expns	 ::=  Expn ( ',' Expn )*	*/
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
	| QNAME_NS		{ $$ = spartlist (sparp_arg, 2, SPAR_QNAME/*_NS*/, sparp_expand_qname_prefix (sparp_arg, $1)); }
	;

spar_blank_node		/* [65]*	BlankNode	 ::=  BLANK_NODE_LABEL | ( '[' ']' )	*/
	: BLANK_NODE_LABEL	{ $$ = spar_make_blank_node (sparp_arg, $1, 0); }
	| _LSQBRA _RSQBRA	{ $$ = spar_make_blank_node (sparp_arg, spar_mkid (sparp_arg, "_:anon"), 1); }
	;

/* PART 2. Quad Map definition statements */

spar_qm_stmts		/* ::=  QmStmt ('.' QmStmt)* */
	: spar_qm_stmt
	| spar_qm_stmts _DOT {
		sparp_env()->spare_qm_default_table = NULL; }
	    spar_qm_stmt
	;

spar_qm_stmt		/* [Virt]	QmStmt		 ::=  QmSimpleStmt | QmCreateStorage | QmAlterStorage	*/
	: spar_qm_simple_stmt		{ t_set_push (&(sparp_env()->spare_acc_qm_sqls), $1); }
	| spar_qm_create_quad_storage
	| spar_qm_alter_quad_storage
	;

spar_qm_simple_stmt	/* [Virt]	QmSimpleStmt	 ::=  QmCreateIRIClass | QmCreateLiteralClass | QmDropIRIClass | QmDropLiteralClass | QmCreateIRISubclass | QmDropQuadStorage | QmDropMap */
	: spar_qm_create_iri_class
	| spar_qm_create_literal_class
	| spar_qm_drop_iri_class
	| spar_qm_drop_literal_class
	| spar_qm_create_iri_subclass
	| spar_qm_drop_quad_storage
	| spar_qm_drop_mapping
	;

spar_qm_create_iri_class	/* [Virt]	QmCreateIRIClass	 ::=  'CREATE' 'IRI' 'CLASS' QmIRIrefConst ( ( String QmSqlfuncArglist ) | ( 'USING' QmSqlfuncHeader ',' QmSqlfuncHeader ) )	*/
	: CREATE_L IRI_L CLASS_L spar_qm_iriref_const_expn SPARQL_STRING spar_qm_sqlfunc_arglist spar_qm_iri_class_optionlist_opt {
		$$ = spar_make_qm_sql (sparp_arg, "DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FORMAT",
		  (SPART **)t_list (3, $4, $5, $6), $7 );
                sparp_jso_push_affected (sparp_arg, uname_virtrdf_ns_uri_QuadStorage); }
	| CREATE_L IRI_L CLASS_L spar_qm_iriref_const_expn USING_L spar_qm_sqlfunc_header_commalist spar_qm_iri_class_optionlist_opt {
		$$ = spar_make_qm_sql (sparp_arg, "DB.DBA.RDF_QM_DEFINE_IRI_CLASS_FUNCTIONS",
		  (SPART **)t_list (2, $4, spar_make_vector_qm_sql (sparp_arg, (SPART **)t_revlist_to_array ($6))), $7 );
                sparp_jso_push_affected (sparp_arg, uname_virtrdf_ns_uri_QuadStorage); }
	;

spar_qm_create_literal_class	/* [Virt]	QmCreateLiteralClass	 ::=  'CREATE' 'LITERAL' 'CLASS' QmIRIrefConst 'USING' QmSqlfuncHeader ',' QmSqlfuncHeader QmLiteralClassOptions?	*/
	: CREATE_L LITERAL_L CLASS_L spar_qm_iriref_const_expn USING_L spar_qm_sqlfunc_header_commalist spar_qm_literal_class_optionlist_opt {
		$$ = spar_make_qm_sql (sparp_arg, "DB.DBA.RDF_QM_DEFINE_LITERAL_CLASS_FUNCTIONS",
		  (SPART **)t_list (2, $4, spar_make_vector_qm_sql (sparp_arg, (SPART **)t_revlist_to_array ($6))), $7 );
                sparp_jso_push_affected (sparp_arg, uname_virtrdf_ns_uri_QuadStorage); }
	;

spar_qm_drop_iri_class		/* [Virt]	QmDropIRIClass	 ::=  'DROP' 'IRI' 'CLASS' QmIRIrefConst	*/
	: DROP_L IRI_L CLASS_L spar_qm_iriref_const_expn {
		$$ = spar_make_qm_sql (sparp_arg, "DB.DBA.RDF_QM_DROP_CLASS",
		  (SPART **)t_list (1, $4), NULL );
                sparp_jso_push_deleted (sparp_arg, uname_virtrdf_ns_uri_QuadMapFormat , $4);
                sparp_jso_push_affected (sparp_arg, uname_virtrdf_ns_uri_QuadStorage); }
	;

spar_qm_drop_literal_class		/* [Virt]	QmDropLiteralClass	 ::=  'DROP' 'LITERAL' 'CLASS' QmIRIrefConst	*/
	: DROP_L LITERAL_L CLASS_L spar_qm_iriref_const_expn {
		$$ = spar_make_qm_sql (sparp_arg, "DB.DBA.RDF_QM_DROP_CLASS",
		  (SPART **)t_list (1, $4), NULL );
                sparp_jso_push_deleted (sparp_arg, uname_virtrdf_ns_uri_QuadMapFormat , $4);
                sparp_jso_push_affected (sparp_arg, uname_virtrdf_ns_uri_QuadStorage); }
	;

spar_qm_create_iri_subclass	/* [Virt]	QmCreateIRISubclass	 ::=  'IRI' 'CLASS' QmIRIrefConst 'SUBCLASS' 'OF' QmIRIrefConst	*/
	: MAKE_L IRI_L CLASS_L spar_qm_iriref_const_expn SUBCLASS_L OF_L spar_qm_iriref_const_expn {
		$$ = spar_make_qm_sql (sparp_arg, "DB.DBA.RDF_QM_DEFINE_SUBCLASS",
		  (SPART **)t_list (2, $4, $7), NULL );
		sparp_jso_push_affected (sparp_arg, uname_virtrdf_ns_uri_QuadStorage); }
	| MAKE_L spar_qm_iriref_const_expn SUBCLASS_L OF_L spar_qm_iriref_const_expn {
		$$ = spar_make_qm_sql (sparp_arg, "DB.DBA.RDF_QM_DEFINE_SUBCLASS",
		  (SPART **)t_list (2, $2, $5), NULL );
		sparp_jso_push_affected (sparp_arg, uname_virtrdf_ns_uri_QuadStorage); }
	;

spar_qm_iri_class_optionlist_opt	/* [Virt]	QmIRIClassOptions	 ::=  'OPTION' '(' QmIRIClassOption (',' QmIRIClassOption)* ')'	*/
        : /* empty */		{ $$ = (SPART **)t_list (0); }
	| OPTION_L _LPAR _RPAR	{ $$ = (SPART **)t_list (0); }
	| OPTION_L _LPAR spar_qm_iri_class_option_commalist _RPAR	{ $$ = (SPART **)t_revlist_to_array ($3); }
	;

spar_qm_iri_class_option_commalist
	: spar_qm_iri_class_option	{
		$$ = NULL;
		t_set_push (&($$), $1[0]);
		t_set_push (&($$), $1[1]); }
	| spar_qm_iri_class_option_commalist _COMMA spar_qm_iri_class_option	{
		$$ = $1;
		t_set_push (&($$), $3[0]);
		t_set_push (&($$), $3[1]); }
	;

spar_qm_iri_class_option	/* [Virt]	QmIRIClassOption	 ::=  */
	: BIJECTION_L		{			/*... 'BIJECTION'	*/
		$$ = (SPART **)t_list (2, t_box_dv_uname_string ("BIJECTION"), 1L); }
	| RETURNS_L spar_qm_sprintff_list	{			/*... | 'RETURNS' STRING ('UNION' STRING)*	*/
		$$ = (SPART **)t_list (2, t_box_dv_uname_string ("RETURNS"),
		    spar_make_vector_qm_sql (sparp_arg, (SPART **)t_revlist_to_array ($2)) ); }
	;

spar_qm_sprintff_list
	: SPARQL_STRING	{ $$ = NULL; t_set_push (&($$), $1); }
	| spar_qm_sprintff_list UNION_L SPARQL_STRING	{ $$ = $1; t_set_push (&($$), $3); }
	;

spar_qm_literal_class_optionlist_opt	/* [Virt]	QmLiteralClassOptions	 ::=  'OPTION' '(' QmLiteralClassOption (',' QmLiteralClassOption)* ')'	*/
        : /* empty */		{ $$ = (SPART **)t_list (0); }
	| OPTION_L _LPAR _RPAR	{ $$ = (SPART **)t_list (0); }
	| OPTION_L _LPAR spar_qm_literal_class_option_commalist _RPAR	{ $$ = (SPART **)t_revlist_to_array ($3); }
	;

spar_qm_literal_class_option_commalist
	: spar_qm_literal_class_option	{
		$$ = NULL;
		t_set_push (&($$), $1[0]);
		t_set_push (&($$), $1[1]); }
	| spar_qm_literal_class_option_commalist _COMMA spar_qm_literal_class_option	{
		$$ = $1;
		t_set_push (&($$), $3[0]);
		t_set_push (&($$), $3[1]); }
	;

spar_qm_literal_class_option	/* [Virt]	QmLiteralClassOption	 ::=  */
	: DATATYPE_L spar_qm_iriref_const_expn	{	/*... ( 'DATATYPE' QmIRIrefConst )	*/
		$$ = t_list (2, t_box_dv_uname_string ("DATATYPE"), t_box_dv_uname_string ($2)); }
	| LANG_L SPARQL_STRING	{			/*... | ( 'LANG' STRING )	*/
		$$ = t_list (2, t_box_dv_uname_string ("LANG"), t_box_dv_uname_string ($2)); }
	| LANG_L spar_qm_sql_id	{			/*... | ( 'LANG' STRING )	*/
		$$ = t_list (2, t_box_dv_uname_string ("LANG"), t_box_dv_uname_string ($2)); }
	| BIJECTION_L		{			/*... | 'BIJECTION'	*/
		$$ = t_list (2, t_box_dv_uname_string ("BIJECTION"), 1L); }
	| RETURNS_L spar_qm_sprintff_list	{			/*... | 'RETURNS' STRING ('UNION' STRING)*	*/
		$$ = t_list (2, t_box_dv_uname_string ("RETURNS"),
		    spar_make_vector_qm_sql (sparp_arg, (SPART **)t_revlist_to_array ($2)) ); }
	;

spar_qm_create_quad_storage	/* [Virt]	QmCreateStorage	 ::=  'CREATE' 'QUAD' 'STORAGE' QmIRIrefConst QmSourceDecl* QmMapTopGroup	*/
	: CREATE_L QUAD_L STORAGE_L spar_qm_iriref_const_expn {
		sparp_env()->spare_storage_name = $4;
		t_set_push (&(sparp_env()->spare_acc_qm_sqls),
		  spar_make_qm_sql (sparp_arg, "DB.DBA.RDF_QM_DEFINE_QUAD_STORAGE",
                    (SPART **)t_list (1, t_box_copy (sparp_env()->spare_storage_name)), NULL ) );
		t_set_push (&(sparp_env()->spare_acc_qm_sqls),
		  spar_make_qm_sql (sparp_arg, "DB.DBA.RDF_QM_BEGIN_ALTER_QUAD_STORAGE",
                    (SPART **)t_list (1, t_box_copy (sparp_env()->spare_storage_name)), NULL ) );
                sparp_jso_push_affected (sparp_arg, $4); }
            spar_qm_from_where_list_opt
	    _LBRA {
		spar_qm_push_bookmark (sparp_arg); }
            spar_qm_map_top_group {
		t_set_push (&(sparp_env()->spare_acc_qm_sqls),
		  spar_make_qm_sql (sparp_arg, "DB.DBA.RDF_QM_END_ALTER_QUAD_STORAGE",
                    (SPART **)t_list (1, t_box_copy (sparp_env()->spare_storage_name)), NULL ) );
		spar_qm_pop_bookmark (sparp_arg);
		sparp_env()->spare_storage_name = NULL; }
        ;

spar_qm_alter_quad_storage	/* [Virt]	QmAlterStorage	 ::=  'ALTER' 'QUAD' 'STORAGE' QmIRIrefConst QmSourceDecl* QmMapTopGroup	*/
	: ALTER_L QUAD_L STORAGE_L spar_qm_iriref_const_expn {
		sparp_env()->spare_storage_name = $4;
		t_set_push (&(sparp_env()->spare_acc_qm_sqls), 
		  spar_make_qm_sql (sparp_arg, "DB.DBA.RDF_QM_BEGIN_ALTER_QUAD_STORAGE",
                    (SPART **)t_list (1, t_box_copy (sparp_env()->spare_storage_name)), NULL ) );
                sparp_jso_push_affected (sparp_arg, $4); }
            spar_qm_from_where_list_opt
	    _LBRA {
		spar_qm_push_bookmark (sparp_arg); }
            spar_qm_map_top_group {
		t_set_push (&(sparp_env()->spare_acc_qm_sqls),
		  spar_make_qm_sql (sparp_arg, "DB.DBA.RDF_QM_END_ALTER_QUAD_STORAGE",
                    (SPART **)t_list (1, t_box_copy (sparp_env()->spare_storage_name)), NULL ) );
		spar_qm_pop_bookmark (sparp_arg);
		sparp_env()->spare_storage_name = NULL; }
        ;

spar_qm_drop_quad_storage	/* [Virt]	QmDropStorage	 ::=  'DROP' 'QUAD' 'STORAGE' QmIRIrefConst	*/
	: DROP_L QUAD_L STORAGE_L spar_qm_iriref_const_expn {
		t_set_push (&(sparp_env()->spare_acc_qm_sqls), 
		  spar_make_qm_sql (sparp_arg, "DB.DBA.RDF_QM_DROP_QUAD_STORAGE",
                    (SPART **)t_list (1, $4), NULL ) );
                sparp_jso_push_deleted (sparp_arg, uname_virtrdf_ns_uri_QuadStorage , $4);
                sparp_jso_push_affected (sparp_arg, $4); }
        ;

spar_qm_drop_mapping		/* [Virt]	QmDropMap	 ::=  'DROP' 'GRAPH'? QmIRIrefConst	*/
	: DROP_L spar_qm_iriref_const_expn	{
		$$ = spar_make_qm_sql (sparp_arg, "DB.DBA.RDF_QM_DROP_MAPPING",
                  (SPART **)t_list (1, t_box_copy (sparp_env()->spare_storage_name)),
                  (SPART **)t_list (2, t_box_dv_uname_string ("ID"), $2) );
		if (NULL == sparp_env()->spare_storage_name)
                  sparp_jso_push_affected (sparp_arg, uname_virtrdf_ns_uri_QuadStorage); }
	| DROP_L spar_graph_identified_by spar_qm_iriref_const_expn	{
		$$ = spar_make_qm_sql (sparp_arg, "DB.DBA.RDF_QM_DROP_MAPPING",
                    (SPART **)t_list (1, t_box_copy (sparp_env()->spare_storage_name)),
                    (SPART **)t_list (2, t_box_dv_uname_string ("GRAPH"), $3) );
		if (NULL == sparp_env()->spare_storage_name)
                  sparp_jso_push_affected (sparp_arg, uname_virtrdf_ns_uri_QuadStorage); }
        ;

spar_qm_from_where_list_opt	/* [Virt]	QmSourceDecl	 ::=  */
	: /* empty */ {}
	| spar_qm_from_where_list_opt FROM_L SPARQL_SQL_QTABLENAME AS_L SPARQL_PLAIN_ID {	/*... ( 'FROM' QTABLE 'AS' PLAIN_ID QmTextLiteral* )	*/
		spar_qm_add_aliased_table (sparp_arg, $3, $5);
		sparp_env()->spare_qm_current_table_alias = $5; }
	    spar_qm_text_literal_list_opt {
		sparp_env()->spare_qm_current_table_alias = NULL; }
	| spar_qm_from_where_list_opt FROM_L SPARQL_PLAIN_ID AS_L SPARQL_PLAIN_ID {		/*... | ( 'FROM' PLAIN_ID 'AS' PLAIN_ID QmTextLiteral* )	*/
		spar_qm_add_aliased_alias (sparp_arg, $3, $5);
		sparp_env()->spare_qm_current_table_alias = $5; }
	    spar_qm_text_literal_list_opt {
		sparp_env()->spare_qm_current_table_alias = NULL; }
	| spar_qm_from_where_list_opt spar_qm_where {						/*... | QmCondition	*/
		spar_qm_add_table_filter (sparp_arg, $2); }
        ;

spar_qm_text_literal_list_opt
	: /* empty */ {}
	| spar_qm_text_literal_list_opt spar_qm_text_literal_decl
	;

spar_qm_text_literal_decl	/* [Virt]	QmTextLiteral	 ::=  'TEXT' 'XML'? 'LITERAL' QmSqlCol ( 'OF' QmSqlCol )? QmTextLiteralOptions? 	*/
	: TEXT_BL spar_xml_opt LITERAL_L spar_qm_sqlcol spar_of_sqlcol_opt spar_qm_text_literal_options_opt {
		spar_qm_add_text_literal (sparp_arg,
		  sparp_env()->spare_qm_current_table_alias,
		  $2, $4, $5, $6 ); }
	;

spar_xml_opt
	: /* empty */ { $$ = NULL; }
	| XML_BL { $$ = $1; }
	;

spar_of_sqlcol_opt
	: /* empty */ { $$ = NULL; }
	| OF_L _LPAR spar_qm_sqlcol_commalist _RPAR	{ $$ = (SPART **)t_revlist_to_array ($3); }
	;

spar_qm_text_literal_options_opt	/* [Virt]	QmTextLiteralOptions	 ::=  'OPTION' '(' QmTextLiteralOption ( ',' QmTextLiteralOption )* ')'	*/
	: /* empty */	{ $$ = NULL; }
	| OPTION_L _LPAR spar_qm_text_literal_option_commalist _RPAR { $$ = (SPART **)t_revlist_to_array ($3); }
	;

spar_qm_text_literal_option_commalist
	: spar_qm_text_literal_option {
		$$ = NULL;
		t_set_push (&($$), $1[1]);
		t_set_push (&($$), $1[0]); }
	| spar_qm_text_literal_option_commalist _COMMA spar_qm_text_literal_option {
		$$ = $1;
		t_set_push (&($$), $3[1]);
		t_set_push (&($$), $3[0]); }
	;

spar_qm_text_literal_option
	: SPARQL_PLAIN_ID		{ $$ = (SPART **)t_list (2, t_box_dv_uname_string ($1), NULL); }
	| SPARQL_PLAIN_ID SPARQL_STRING	{ $$ = (SPART **)t_list (2, t_box_dv_uname_string ($1), $2); }
	;

spar_qm_map_top_group	/* [Virt]	QmMapTopGroup	 ::=  '{' QmMapTopOp ( '.' QmMapTopOp )* '.'? '}'	*/
	: _RBRA	{}
	| spar_qm_map_top_dotlist _RBRA	{}
	| spar_qm_map_top_dotlist _DOT _RBRA	{}
	;

spar_qm_map_top_dotlist	/* ::=  QmMapTopOp ( '.' QmMapTopOp )*	*/
	: spar_qm_map_top_op {}
	| spar_qm_map_top_dotlist _DOT {
		spar_qm_clean_locals (sparp_arg);
		sparp_env()->spare_qm_default_table = NULL; }
	    spar_qm_map_top_op {}
	;

spar_qm_map_top_op		/* [Virt]	QmMapTopOp	 ::=  QmMapOp | QmDropMap	*/
	: spar_qm_map_op
	| spar_qm_drop_mapping {
		t_set_push (&(sparp_env()->spare_acc_qm_sqls), $1); }
	;

spar_qm_map_group		/* [Virt]	QmMapGroup	 ::=  '{' QmMapOp ( '.' QmMapOp )* '.'? '}'	*/
	: _RBRA		{}
	| spar_qm_map_dotlist _RBRA		{}
	| spar_qm_map_dotlist _DOT _RBRA		{}
	;

spar_qm_map_dotlist		/* ::=  QmMapOp ( '.' QmMapOp )*	*/
	: spar_qm_map_op
	| spar_qm_map_dotlist _DOT {
		spar_qm_clean_locals (sparp_arg);
		sparp_env()->spare_qm_default_table = NULL; }
	    spar_qm_map_op
	;

spar_qm_map_op			/* [Virt]	QmMapOp		 ::=  */
	: CREATE_L spar_qm_iriref_const_expn AS_L	/*... ( 'CREATE' QmIRIrefConst 'AS' QmMapIdDef )	*/
		{ spar_qm_push_local (sparp_arg, CREATE_L, (SPART *)($2), 1); }
	    spar_qm_map_iddef {;}
	| CREATE_L spar_qm_iriref_const_expn		/*... | ( 'CREATE' 'GRAPH'? QmIRIrefConst 'USING' 'STORAGE' QmIRIrefConst QmOptions? )	*/
	    USING_L STORAGE_L spar_qm_iriref_const_expn spar_qm_options_opt	{
		spar_qm_push_local (sparp_arg, CREATE_L, (SPART *)($2), 1);
		t_set_push (&(sparp_env()->spare_acc_qm_sqls), 
		  spar_make_qm_sql (sparp_arg, "DB.DBA.RDF_QM_ATTACH_MAPPING",
                    (SPART **)t_list (2, t_box_copy (sparp_env()->spare_storage_name), $5),
		    (SPART **)t_list_concat ((caddr_t)$6, (caddr_t)t_list (2, t_box_dv_uname_string ("ID"), $2)) ) ); }
	| CREATE_L spar_graph_identified_by spar_qm_iriref_const_expn	/* note optional 'GRAPH' in previous case */
	    USING_L STORAGE_L spar_qm_iriref_const_expn spar_qm_options_opt	{
		spar_qm_push_local (sparp_arg, GRAPH_L, (SPART *)($3), 1);
		t_set_push (&(sparp_env()->spare_acc_qm_sqls), 
		  spar_make_qm_sql (sparp_arg, "DB.DBA.RDF_QM_ATTACH_MAPPING",
                    (SPART **)t_list (2, t_box_copy (sparp_env()->spare_storage_name), $6),
		    (SPART **)t_list_concat ((caddr_t)$7, (caddr_t)t_list (2, t_box_dv_uname_string ("GRAPH"), $3)) ) ); }
	| spar_qm_named_fields spar_qm_options_opt	/*... | ( QmNamedField+ QmOptions? QmMapGroup )	*/
	    _LBRA {
		t_set_push (&(sparp_env()->spare_acc_qm_sqls),
		  spar_qm_make_empty_mapping (sparp_arg, NULL, $2) );
		spar_qm_push_local (sparp_arg, _LBRA,
		  spar_qm_get_local (sparp_arg, CREATE_L, 1), 1 );
		spar_qm_push_local (sparp_arg, CREATE_L, NULL, 1);
		spar_qm_push_bookmark (sparp_arg); }
	    spar_qm_map_group {
		spar_qm_pop_bookmark (sparp_arg); }
	| spar_qm_triples1				/*... | QmTriples1	*/
	;

spar_qm_map_iddef	/* [Virt]	QmMapIdDef	 ::=  QmMapTriple | ( QmNamedField+ QmOptions? QmMapGroup )	*/
	: spar_qm_map_single {;}
	| spar_qm_named_fields
            spar_qm_options_opt _LBRA {
		t_set_push (&(sparp_env()->spare_acc_qm_sqls),
		  spar_qm_make_empty_mapping (sparp_arg,
	            (caddr_t) spar_qm_get_local (sparp_arg, CREATE_L, 1),
	            $2 ) );
		spar_qm_push_local (sparp_arg, _LBRA,
		  spar_qm_get_local (sparp_arg, CREATE_L, 1), 1 );
		spar_qm_push_local (sparp_arg, CREATE_L, NULL, 1);
		spar_qm_push_bookmark (sparp_arg); }
	    spar_qm_map_group {
		spar_qm_pop_bookmark (sparp_arg); }
	;

spar_qm_map_single		/* [Virt]	QmMapTriple	 ::=  QmFieldOrBlank QmVerb QmObjField	*/
	: spar_qm_field_or_blank spar_qm_verb spar_qm_obj_field {
		spar_qm_push_local (sparp_arg, SUBJECT_L,
		  ((NULL != $1) ? ((SPART *)($1)) : spar_qm_get_local (sparp_arg, SUBJECT_L, 1)),
		  0);
		spar_qm_push_local (sparp_arg, PREDICATE_L,
		  ((NULL != $2) ? ((SPART *)($2)) : spar_qm_get_local (sparp_arg, PREDICATE_L, 1)),
		  0);
		t_set_push (&(sparp_env()->spare_acc_qm_sqls),
		  spar_qm_make_real_mapping (sparp_arg,
		    (caddr_t)spar_qm_get_local (sparp_arg, CREATE_L, 0),
		    $3 ) ); }
	;

spar_qm_triples1	/* [Virt]	QmTriples1	 ::=  QmFieldOrBlank QmProps	*/
	: spar_qm_field_or_blank { spar_qm_push_local (sparp_arg, SUBJECT_L, $1, 0); }
	    spar_qm_props {}
	;

spar_qm_named_fields	/* ::=  QmNamedField+	*/
	: spar_qm_named_field
	| spar_qm_named_fields spar_qm_named_field
	;

spar_qm_named_field	/* [Virt]	QmNamedField	 ::=  ('GRAPH'|'SUBJECT'|'PREDICATE'|'OBJECT') QmField	*/
	: GRAPH_L spar_qm_field { spar_qm_push_local (sparp_arg, GRAPH_L, $2, 0); }
	| SUBJECT_L spar_qm_field { spar_qm_push_local (sparp_arg, SUBJECT_L, $2, 0); }
	| PREDICATE_L spar_qm_field { spar_qm_push_local (sparp_arg, PREDICATE_L, $2, 0); }
	| OBJECT_L spar_qm_field { spar_qm_push_local (sparp_arg, OBJECT_L, $2, 0); }
	;

spar_qm_props		/* [Virt]	QmProps		 ::=  QmProp ( ';' QmProp )?	*/
	: spar_qm_prop {}
	| spar_qm_props _SEMI {
		spar_qm_pop_key (sparp_arg, PREDICATE_L); }
	    spar_qm_prop
	;

spar_qm_prop		/* [Virt]	QmProp		 ::=  QmVerb QmObjField ( ',' QmObjField )*	*/
	: spar_qm_verb {
		spar_qm_push_local (sparp_arg, PREDICATE_L,
		  ((NULL != $1) ? ((SPART *)($1)) : spar_qm_get_local (sparp_arg, PREDICATE_L, 1)),
		  0 ); }
	    spar_qm_obj_field_commalist {}
        | error { sparyyerror ("Description of predicate field is expected here"); }
	;

spar_qm_obj_field_commalist	/* ::=  QmObjField QmIdSuffix? ( ',' QmObjField QmIdSuffix? )* */
	: spar_qm_obj_field spar_qm_as_id_opt {
		t_set_push (&(sparp_env()->spare_acc_qm_sqls),
		  spar_qm_make_real_mapping (sparp_arg, $2, $1) ); }
	| spar_qm_obj_field_commalist _COMMA {
		spar_qm_pop_key (sparp_arg, OBJECT_L); }
	    spar_qm_obj_field spar_qm_as_id_opt {
		t_set_push (&(sparp_env()->spare_acc_qm_sqls),
		  spar_qm_make_real_mapping (sparp_arg, $5, $4) ); }
	;

spar_qm_obj_field	/* [Virt]	QmObjField	 ::=  QmFieldOrBlank QmCondition* QmOptions?	*/
	: spar_qm_field_or_blank {
		spar_qm_push_local (sparp_arg, OBJECT_L,
		  ((NULL != $1) ? ((SPART *)($1)) : spar_qm_get_local (sparp_arg, OBJECT_L, 1)),
		  0 ); }
	    spar_qm_where_list_opt {
		spar_qm_push_local (sparp_arg, WHERE_L, (SPART *)t_revlist_to_array ($3), 0); }
	    spar_qm_options_opt { $$ = $5; }
        | error { sparyyerror ("Description of object field is expected here"); }
	;

spar_qm_as_id_opt	/* [Virt]	QmIdSuffix	 ::=  'AS' QmIRIrefConst	*/
	: /* empty */ { $$ = NULL; }
	| AS_L spar_qm_iriref_const_expn { $$ = $2; }
	;

spar_qm_verb		/* [Virt]	QmVerb		 ::=  QmField | ( '[' ']' ) | 'a'	*/
	: spar_qm_field	{ $$ = $1; }
	| _LSQBRA _RSQBRA	{ $$ = NULL; }
	| a_L			{ $$ = (SPART *)uname_rdf_ns_uri_type; }
	;

spar_qm_field_or_blank	/* [Virt]	QmFieldOrBlank	 ::=  QmField | ( '[' ']' )	*/
	: spar_qm_field	{ $$ = $1; }
	| _LSQBRA _RSQBRA	{ $$ = NULL; }
	;

spar_qm_field		/* [Virt]	QmField		 ::=  */
	: spar_qm_iriref_const_expn { $$ = (SPART *)$1; }	/* see case below */
	| spar_numeric_literal { $$ = $1; }	/*... NumericLiteral	*/
	| spar_rdf_literal { $$ = $1; }		/*... | RdfLiteral	*/
	| spar_qm_iriref_const_expn		/*... | ( QmIRIrefConst ( '(' ( QmSqlCol ( ',' QmSqlCol )* )? ')' )? )	*/
	    _LPAR spar_qm_sqlcol_commalist_opt _RPAR {
		$$ = spar_make_qm_value (sparp_arg, $1, (SPART **)t_revlist_to_array ($3)); }
	| spar_qm_sqlcol {			/*... | QmSqlCol	*/
		$$ = spar_make_qm_value (sparp_arg, box_dv_uname_string ("literal"), (SPART **)t_list (1, $1)); }
	;

spar_qm_where_list_opt
	: /* empty */ { $$ = NULL; }
        | spar_qm_where_list { $$ = $1; }
	;

spar_qm_where_list
	: spar_qm_where { $$ = NULL; t_set_push (&($$), $1); }
        | spar_qm_where_list spar_qm_where { $$ = $1; t_set_push (&($$), $2); }
	;

spar_qm_where	/* [Virt]	QmCondition	 ::=  'WHERE' ( ( '(' SQLTEXT ')' ) | String )	*/
	: WHERE_L _LPAR SPARQL_CONDITION_AFTER_WHERE_LPAR { $$ = $3; }
	| WHERE_L SPARQL_STRING { $$ = $2; }
	;

spar_qm_options_opt	/* [Virt]	QmOptions	 ::=  'OPTION' '(' QmOption ( ',' QmOption )* ')'	*/
	: /* empty */	{ $$ = (SPART **)t_list (0); }
	| OPTION_L _LPAR _RPAR	{ $$ = (SPART **)t_list (0); }
	| OPTION_L _LPAR spar_qm_option_commalist _RPAR	{ $$ = (SPART **)t_revlist_to_array ($3); }
	;

spar_qm_option_commalist	/* ::=  QmOption ( ',' QmOption )*	*/
	: spar_qm_option {
		$$ = NULL;
		t_set_push (&($$), $1[0]);
		t_set_push (&($$), $1[1]); }
	| spar_qm_option_commalist _COMMA spar_qm_option {
		$$ = $1;
		t_set_push (&($$), $3[0]);
		t_set_push (&($$), $3[1]); }
	;

spar_qm_option		/* [Virt]	QmOption	 ::=  'EXCLUSIVE' | ( 'ORDER' INTEGER ) | ( 'USING' PLAIN_ID )	*/
	: EXCLUSIVE_L			{ $$ = (SPART **)t_list (2, t_box_dv_uname_string ("EXCLUSIVE"), 1L); }
	| ORDER_L SPARQL_INTEGER	{ $$ = (SPART **)t_list (2, t_box_dv_uname_string ("ORDER"), $2); }
	| USING_L SPARQL_PLAIN_ID	{ $$ = (SPART **)t_list (2, t_box_dv_uname_string ("USING"), $2); }
	;

spar_qm_sqlcol_commalist_opt	/* ::=  ( QmSqlCol ( ',' QmSqlCol )* )?	*/
	: /* empty */			{ $$ = NULL; }
	| spar_qm_sqlcol_commalist	{ $$ = $1; }
	;

spar_qm_sqlcol_commalist	/* ::=  QmSqlCol ( ',' QmSqlCol )*	*/
	: spar_qm_sqlcol					{ $$ = NULL; t_set_push (&($$), $1); }
	| spar_qm_sqlcol_commalist _COMMA spar_qm_sqlcol	{ $$ = $1; t_set_push (&($$), $3); }
	;

spar_qm_sqlfunc_header_commalist
	: spar_qm_sqlfunc_header	{ $$ = NULL; t_set_push (&($$), $1); }
	| spar_qm_sqlfunc_header_commalist _COMMA spar_qm_sqlfunc_header	{ $$ = $1; t_set_push (&($$), $3); }
	;

spar_qm_sqlfunc_header	/* [Virt]	QmSqlfuncHeader	 ::=  'FUNCTION' SQL_QTABLECOLNAME QmSqlfuncArglist 'RETURNS' QmSqltype */
	: FUNCTION_L SPARQL_SQL_QTABLENAME spar_qm_sqlfunc_arglist RETURNS_L spar_qm_sqltype {
		$$ = spar_make_vector_qm_sql (sparp_arg,
		  (SPART **)t_list (4, $2, $3, $5[0], $5[1]) ); }
	;

spar_qm_sqlfunc_arglist	/* [Virt]	QmSqlfuncArglist	 ::=  '(' ( QmSqlfuncArg ( ',' QmSqlfuncArg )* )? ')'	*/
	: _LPAR spar_qm_sqlfunc_arg_commalist_opt _RPAR { $$ = spar_make_vector_qm_sql (sparp_arg, (SPART **)t_revlist_to_array ($2)); }
	;

spar_qm_sqlfunc_arg_commalist_opt	/* ::=  ( QmSqlfuncArg ( ',' QmSqlfuncArg )* )?	*/
	: /* empty */				{ $$ = NULL; }
	| spar_qm_sqlfunc_arg_commalist		{ $$ = $1; }
	;

spar_qm_sqlfunc_arg_commalist	/* ::=  QmSqlfuncArg ( ',' QmSqlfuncArg )*	*/
	: spar_qm_sqlfunc_arg						{ $$ = NULL; t_set_push (&($$), $1); }
	| spar_qm_sqlfunc_arg_commalist _COMMA spar_qm_sqlfunc_arg	{ $$ = $1; t_set_push (&($$), $3); }
	;

spar_qm_sqlfunc_arg	/* [Virt]	QmSqlfuncArg	 ::=  ('IN' | QmSqlId) QmSqlId QmSqltype	*/
	: spar_qm_sql_in_out_inout spar_qm_sql_id spar_qm_sqltype	{
		$$ = spar_make_vector_qm_sql (sparp_arg,
		  (SPART **)t_list (4, $1, $2, $3[0], $3[1]) ); }
	;

spar_qm_sqltype		/* [Virt]	QmSqltype	 ::=  QmSqlId ( 'NOT' 'NULL' )?	*/
	: spar_qm_sql_id		{ $$ = t_list (2, $1, (ptrlong)0); }
	| spar_qm_sql_id NOT_L NULL_L	{ $$ = t_list (2, $1, (ptrlong)1); }
	;

spar_qm_sql_in_out_inout	/* ::=  ('IN' | QmSqlId)	*/
	: IN_L			{ $$ = t_box_dv_uname_string ("in"); }
	| spar_qm_sql_id	{ $$ = t_box_dv_uname_string ($1); }
	;

spar_qm_sqlcol		/* [Virt]	QmSqlCol	 ::=  QmSqlId | spar_qm_sql_id	*/
	: spar_qm_sql_id		{ $$ = sparp_make_qm_sqlcol (sparp_arg, SPARQL_PLAIN_ID, $1); }
	| SPARQL_SQL_ALIASCOLNAME	{ $$ = sparp_make_qm_sqlcol (sparp_arg, SPARQL_SQL_ALIASCOLNAME, $1); }
	| SPARQL_SQL_QTABLECOLNAME	{ $$ = sparp_make_qm_sqlcol (sparp_arg, SPARQL_SQL_QTABLECOLNAME, $1); }
	;

spar_qm_sql_id		/* [Virt]	QmSqlId		 ::=  PLAIN_ID | 'TEXT' | 'XML'	*/
	: SPARQL_PLAIN_ID		{ $$ = $1; }
	| TEXT_BL			{ $$ = $1; }
	| XML_BL			{ $$ = $1; }
	/*| a_L { $$ = t_box_dv_short_string ("a"); }*/
	;

spar_qm_iriref_const_expn	/* [Virt]	QmIRIrefConst	 ::=  IRIref | ( 'IRI' '(' String ')' )	*/
	: spar_iriref { $$ = $1->_.lit.val; }
	| IRI_L _LPAR SPARQL_STRING _RPAR {
		$$ = spar_make_iri_from_template (sparp_arg, $3); }
	;

spar_graph_identified_by
	: GRAPH_L			{}
	| GRAPH_L IDENTIFIED_L BY_L	{}
	;

spar_opt_dot_and_end
	: END_OF_SPARQL_TEXT {;}
	| _DOT END_OF_SPARQL_TEXT {;}
	;

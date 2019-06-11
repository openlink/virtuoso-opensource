/*
 *  sql3.y
 *
 *  $Id$
 *
 *  SQL Parser
 *
 *   This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *   project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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
 */

%pure-parser
%parse-param {yyscan_t scanner}
%lex-param {yyscan_t scanner}
/*%parse-param {sql_comp_context_t* scs_arg}*/
/*%lex-param {sql_comp_context_t* scs_arg}*/
%expect 19


%{

#include "libutil.h"
#include "sqlnode.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "crsr.h"
#include "sqltype.h"
#include "sqlbif.h"
#include "soap.h" /* a SOAP related constants */
#include "subseq.h"
#include "sqlcmps.h"
#include "sqlcstate.h"

/* We are a little bit lazy here. Instead of converting NAME tokens
   like d and ts to stringdate, and t to stringtime, and maybe the
   rest to "unimplemented_odbc_brace_escape_keyword:%s"
   we just let them be as they are, and define aliases   d   and   ts
   for   stringdate    and   t    for   stringtime   in sqlbif.c.
   In effect, syntax like {any-name any-single-atom} in the place
   of atom will be converted to function call any-name(any-single-atom)
   Having funny one- or two-character bif-function names like d or ts
   does not make any of them reserved keywords, and they can be used
   to one's heart's contents as the names of tables, columns, etc.
 */
#define obe_keyword_to_bif_fun_name(X) ((X))

#ifdef DEBUG
#define yyerror(scanner,strg) yyerror_1(/* no scanner */ yystate, yyssa, yyssp, strg)
#define yyfatalerror(strg) yyfatalerror_1(/* no scanner */ yyssa, yyssp, strg)
#endif

#define assert_ms_compat(text)


%}

/* symbolic tokens */
%union {
  long intval;
  char *strval;
  sql_tree_t *tree;
  caddr_t box;
  dk_set_t list;
  long subtok;
  sqlp_join_t join;
}

%token <box> NAME
%token <box> STRING
%token <box> WSTRING
%token <box> UNAME_LITERAL
%token <box> INTNUM
%token <box> IRI_LIT
%token <box> APPROXNUM
%token <box> NUM_ERROR
%token <subtok> AMMSC
%token <box> PARAMETER_L
%token <box> NAMED_PARAMETER
%token <box> BEGIN_EQCALL_X
%token <box> HTMLSTR
%token <subtok> SQL_TSI
%token <subtok> TIMESTAMP_FUNC
%token <box> BINARYNUM

%token <box> MSSQL_XMLCOL_NAME
%token <box> MSSQL_XMLCOL_NAME1
%token <box> MSSQL_XMLCOL_NAMEYZ
%token <box> MSSQL_XMLCOL_NAMEZ
%token <box> MSSQL_XMLCOL_INTNUM

%type <box> identifier
%type <strval> table
%type <strval> column
%type <strval> index
/* %type <strval> table_name */
%type <strval> q_table_name
%type <strval> attach_q_table_name
/* pmn %type <box> proc_call_name */
%type <strval> new_proc_or_bif_name
%type <strval> new_table_name

%type <tree> selectinto_statement
%type <tree> query_opt_from_spec
%type <tree> query_spec
/*%type <tree> query_no_from_spec*/
%type <tree> query_exp
%type <tree> sqlonly_query_exp
%type <tree> query_or_sparql_exp
%type <tree> non_final_union_exp
%type <tree> non_final_query_term
%type <tree> non_final_query_spec
%type <tree> non_final_table_exp
%type <tree> opt_corresponding
%type <tree> sqlonly_query_term
%type <tree> sparqlonly_query_term
%type <tree> query_term
%type <tree> table_exp_opt
%type <tree> table_exp

%type <box> assignment
%type <list> assignment_commalist
%type <list> insert_atom_commalist
%type <tree> insert_atom
%type <tree> update_statement_positioned
%type <tree> admin_statement
%type <tree> opt_log
%type <tree> comma_opt_log

%type <tree> insert_statement
%type <subtok> insert_mode
%type <list> column_commalist
%type <list> index_column_commalist
%type <tree> opt_column_commalist
%type <tree> priv_opt_column_commalist
%type <tree> values_or_query_spec
%type <tree> delete_statement_searched
%type <tree> delete_statement_positioned

%type <tree> update_statement_searched
%type <tree> scalar_exp
%type <tree> scalar_exp_no_col_ref
%type <tree> scalar_exp_no_col_ref_no_mem_obs_chain
%type <tree> array_ref
%type <tree> lvalue_array_ref
%type <tree> function_call
%type <box> function_name
%type <tree> obe_literal
%type <list> scalar_exp_commalist
%type <list> select_scalar_exp_commalist
%type <tree> string_concatenation_operator
%type <list> opt_scalar_exp_commalist
%type <tree> selection
%type <list> breakup_list
%type <list> breakup_term
%type <box> atom
%type <box> atom_no_obe
%type <box> parameter_ref
%type <box> parameter
%type <box> cursor
%type <box> literal
%type <box> signed_literal
%type <box> tail_of_tag_of
%type <tree> column_ref
%type <tree> aggregate_ref

%type <tree> sql
%type <tree> manipulative_statement
%type <intval> opt_all_distinct	/* operators */
/*%type <intval> opt_percent*/
%type <intval> opt_ties
%type <tree> opt_top
%type <tree> trans_decl
%type <tree> from_clause
%type <tree> opt_where_clause
%type <tree> where_clause
%type <tree> opt_group_by_clause
%type <tree> opt_having_clause
%type <list> table_ref_commalist
%type <box> table_ref
%type <box> table_ref_nj
%type <box> opt_table
%type <tree> joined_table
%type <tree> joined_table_1
%type <tree> join_condition
%type <subtok> jtype
%type <join> join

%type <tree> search_condition
%type <tree> predicate

%type <tree> comparison_predicate
%type <tree> scalar_exp_predicate
%type <tree> between_predicate

%type <tree> test_for_null
%type <tree> like_predicate
%type <tree> in_predicate
%type <tree> all_or_any_predicate
%type <tree> existence_test
/* pmn %type <list> atom_commalist */
%type <intval> any_all_some

%type <list> target_commalist
%type <tree> target
/* pmn %type <box> range_variable */
/* pmn %type <list> column_ref_commalist */
%type <tree> scalar_subquery
%type <tree> subquery
%type <box> opt_escape

%type <intval> opt_with_data
%type <intval> base_table_opt
%type <tree> base_table_def
%type <tree> view_def
%type <tree> view_def_select_and_opt
%type <tree> view_query_spec
%type <tree> create_index_def
%type <list> base_table_element_commalist
%type <list> base_table_element

%type <box> index_option
%type <list> index_option_list
%type <tree> opt_index_option_list
%type <list> column_def
%type <tree> column_def_opt
%type <tree> column_xml_schema_def
%type <list> column_def_opt_list
%type <list> identity_opt_list
%type <tree> identity_opt
%type <tree> compression_spec
%type <tree> data_type
%type <tree> data_type_ref
%type <tree> base_data_type
%type <tree> column_data_type
%type <tree> table_constraint_def
%type <tree> opt_table_constraint_def
%type <tree> references
%type <tree> drop_index
%type <tree> drop_table
%type <list> add_col_column_def_list
%type <list> add_col_column_list
%type <list> add_column
%type <intval> opt_col_add_column
%type <tree> table_rename
%type <tree> schema_element
%type <list> schema_element_list
%type <tree> create_xml_schema
%type <tree> drop_xml_schema

%type <tree> open_statement
%type <tree> close_statement
%type <tree> fetch_statement
%type <tree> cursor_def
%type <intval> cursor_type

/* procedures */
%type <tree> user_aggregate_declaration
%type <box> user_aggregate_merge_opt
%type <box> user_aggregate_order_opt
%type <tree> routine_declaration
%type <tree> module_body_part
%type <tree> module_declaration
%type <list> module_body
%type <tree> opt_return
%type <tree> rout_parameter
%type <box> rout_parameter_list
%type <list> parameter_commalist
%type <box> rout_alt_type
%type <list> soap_proc_opt_list
%type <list> soap_proc_opt
%type <intval> soap_kwd

%type <subtok> parameter_mode
%type <subtok> opt_parameter_mode
%type <subtok> opt_soap_enc_mode
%type <tree> commit_statement
%type <tree> rollback_statement
%type <tree> routine_statement
%type <tree> statement
%type <tree> statement_in_cs
%type <tree> statement_in_cs_oper
%type <tree> local_declaration
%type <list> statement_list
%type <tree> assignment_statement
%type <list> array_index_list
%type <tree> lvalue
%type <tree> if_statement
%type <tree> while_statement
%type <tree> for_statement
%type <list> for_init_statement_list
%type <tree> for_init_statement
%type <list> for_inc_statement_list
%type <tree> for_opt_search_cond
%type <tree> for_inc_statement
%type <tree> goto_statement
%type <tree> return_statement
%type <tree> call_statement
%type <tree> set_statement
%type <box> txn_isolation_level
%type <subtok> routine_head
%type <tree> compound_statement
%type <tree> control_statement

%type <list> variable_list
%type <tree> variable_declaration
%type <tree> handler_declaration
%type <tree> handler_statement
%type <intval> handler_type
%type <list> cond_value_list
/* pmn %type <tree> elseif_clause */
/* pmn %type <list> elseif_list */
%type <tree> opt_else
%type <tree> cursor_option
%type <list> cursor_options_commalist
%type <box> opt_cursor_options_list
%type <box> with_opt_cursor_options_list
%type <tree> create_user_statement
%type <tree> delete_user_statement
%type <tree> set_group_stmt
%type <tree> add_group_stmt
%type <tree> delete_group_stmt
%type <tree> attach_table
%type <box> opt_as
%type <tree> opt_attach_primary_key
%type <tree> opt_login
%type <box> opt_not_select
%type <tree> opt_remote_name
%type <tree> set_pass
%type <box> user
%type <box> grantee
%type <list> grantee_commalist

%type <tree> privilege_def
%type <tree> privilege_revoke
%type <box> privileges
%type <tree> operation
%type <list> operation_commalist

%type <subtok> opt_with_admin_option
%type <subtok> opt_with_grant_option

%type <subtok> opt_asc_desc
%type <tree> ordering_spec
%type <list> ordering_spec_commalist
%type <box> opt_order_by_clause
%type <box> grouping_set
%type <list> grouping_set_list

%type <tree> trigger_def
%type <tree> trig_action
%type <box> opt_order
%type <subtok> action_time
%type <box> event
%type <box> opt_old_ref
%type <list> old_commalist
%type <tree> old_alias
%type <tree> drop_trigger
%type <tree> drop_proc
%type <box> condition
/* pmn %type <box> opt_prefix */
%type <tree> as_expression
%type <tree> cast_exp
%type <tree> cvt_exp
%type <tree> use_statement
%type <subtok> opt_lock_mode

%type <tree> simple_case
%type <tree> searched_case
%type <list> searched_when_list
%type <list> simple_when_list
%type <list> simple_when
%type <list> searched_when
%type <tree> coalesce_exp
%type <tree> nullif_exp
%type <subtok> opt_with_check_option

%type <box> xmlview_param_value
%type <tree> xmlview_param
%type <list> xmlview_params
%type <list> opt_xmlview_params

%type <box> opt_element
%type <list> xml_col_list
%type <list> xml_join_list
%type <tree> xml_col
%type <tree> xml_join_elt
%type <tree> xml_view
%type <tree> drop_xml_view
/*%type <tree> xml_doc */
%type <tree> opt_join
%type <tree> opt_pk
%type <tree> opt_xml_col_list

%type <tree> create_snapshot_log
%type <tree> drop_snapshot_log
%type <tree> purge_snapshot_log
%type <box>  opt_snapshot_string_literal
%type <box>  opt_snapshot_where_clause
%type <tree> create_snapshot
%type <box>  opt_with_delete
%type <tree> drop_snapshot
%type <subtok>  opt_nonincremental
%type <tree> refresh_snapshot
%type <tree> create_freetext_index
%type <tree> create_freetext_trigger
%type <tree> drop_freetext_trigger
%type <box> opt_xml
%type <box> opt_deffer_generation
%type <box> opt_with_key
%type <tree> opt_with
%type <box> opt_data_modification_action
%type <box> opt_lang
%type <box> opt_enc

%type <strval> opt_collate_exp
%type <tree> opt_xml_child
%type <tree> top_xml_child
%type <box> opt_interval
%type <box> opt_persist

/* IvAn/XmlView/000810 opt_metas added */
%type <tree> opt_metas

%type <tree> opt_publish
%type <subtok> opt_elt
%type <tree> alter_constraint
%type <box> opt_with_permission_set
%type <box> opt_with_autoregister
%type <tree> create_library
%type <tree> create_assembly
%type <tree> drop_library
%type <tree> drop_assembly
%type <subtok> constraint_op
/*%type <subtok> xml_col_dir*/
%type <tree> mssql_xml_col
%type <list> proc_col_list
%type <tree> opt_proc_col_list
%type <tree> column_commalist_or_empty
%type <subtok> opt_best
%type <box> opt_constraint_name
%type <box> opt_column
%type <intval> opt_drop_behavior

%type <tree> opt_referential_triggered_action
%type <tree> referential_rule
%type <intval> referential_action
%type <intval> referential_state
%type <list> kwd_commalist
%type <list> as_commalist /*sqlxml*/
%type <list> opt_arg_commalist
%type <list> sql_option
%type <list> sql_opt_commalist
%type <tree> opt_sql_opt
%type <tree> opt_table_opt


/* user defined types */
%type <tree> user_defined_type
%type <tree> user_defined_type_drop
%type <tree> delete_referential_rule
%type <tree> opt_on_delete_referential_rule
%type <strval> q_type_name
%type <strval> q_old_type_name
%type <strval> new_type_name
%type <strval> opt_subtype_clause
%type <tree> opt_as_type_representation
%type <tree> opt_external_clause
%type <tree> opt_external_type
%type <tree> opt_soap_clause
%type <tree> type_representation
%type <list> type_member_list
%type <tree> opt_external_and_language_clause
%type <tree> type_member
%type <tree> opt_reference_scope_check
%type <box> opt_default_clause
%type <tree> opt_type_option_list
%type <list> type_option_list
%type <tree> type_option
%type <list> method_specification_list
%type <tree> opt_method_specification_list
%type <tree> method_specification
%type <tree> partial_method_specification
%type <intval> method_type
%type <strval> opt_specific_method_name
%type <intval> opt_self_result
%type <tree> opt_method_characteristics
%type <list> method_characteristics
%type <tree> method_characteristic
%type <intval> external_language_name
%type <intval> language_name
%type <tree> method_declaration
%type <tree> static_method_invocation
%type <tree> opt_constructor_return
%type <tree> decl_parameter
%type <box> decl_parameter_list
%type <list> decl_parameter_commalist
%type <tree> method_invocation
%type <tree> top_level_method_invocation
%type <box> method_identifier
%type <tree> member_observer
%type <tree> member_observer_no_id_chain
%type <list> identifier_chain
%type <list> identifier_chain_method
%type <tree> new_invocation
%type <tree> user_defined_type_alter
%type <tree> alter_type_action
%type <box> array_modifier
%type <tree> cost_decl
%type <tree> vectored_decl
%type <list> cost_number_list
%type <box> cost_number
%type <tree> cluster_def
%type <box> opt_cluster
%type <tree> partition_def
%type <list> col_part_list
%type <list> col_part_commalist
%type <list> host_group_list
%type <list> host_list
%type <box> host
%type <box> range
%type <list> range_list
%type <box> opt_modulo
%type <tree> col_partition
%type <tree> host_group
%type <box> opt_index
%type <list> colnum_commalist_2
%type <box> colnum_commalist
%type <list> vectored_list
%type <tree> vectored_var
%type <intval> opt_modify


%token <box> TYPE FINAL_L METHOD CHECKED SYSTEM GENERATED SOURCE RESULT LOCATOR INSTANCE_L CONSTRUCTOR SELF_L OVERRIDING STYLE SQL_L GENERAL DETERMINISTIC NO_L CONTAINS READS DATA DISABLE_L NOVALIDATE_L ENABLE_L VALIDATE_L
%token <box> MODIFIES INPUT CALLED ADA C_L3 COBOL FORTRAN MUMPS PASCAL_L PLI NAME_L TEXT_L JAVA INOUT_L REMOTE KEYSET VALUE PARAMETER VARIABLE ADMIN_L ROLE_L TEMPORARY CLR ATTRIBUTE
%token <box> __SOAP_DOC __SOAP_DOCW __SOAP_HEADER __SOAP_HTTP __SOAP_NAME __SOAP_TYPE __SOAP_XML_TYPE __SOAP_FAULT __SOAP_DIME_ENC __SOAP_ENC_MIME __SOAP_OPTIONS FOREACH POSITION_L
%token ARE REF STATIC_L SPECIFIC DYNAMIC COLUMN START_L
%token __LOCK __TAG_L RDF_BOX_L VECTOR_L VECTORED FOR_VECTORED FOR_ROWS NOT_VECTORED VECTORING HANDLE_L STREAM_L

%nonassoc ORDER FOR
%left UNION EXCEPT
%left INTERSECT
%nonassoc AS
%nonassoc DOUBLE_COLON
%nonassoc COLON
%left OR
%left AND
%left NOT
%left <subtok> COMPARISON /* = <> < > <= >= */
%left EQUALS
%left STRING_CONCAT_OPERATOR
%left '+' '-'
%left '*' '/'
%nonassoc UMINUS

/* literal keyword tokens */

%token ALL ANY ATTACH ASC AUTHORIZATION BETWEEN BIGINT BREAKUP BY
%token CASCADE CHARACTER CHECK CLOSE COMMIT CONSTRAINT CONTINUE CREATE CUBE CURRENT
%token CURSOR DECIMAL_L DECLARE DEFAULT DELETE_L DESC DISTINCT DOUBLE_L
%token DROP ESCAPE EXISTS FETCH FLOAT_L FOREIGN FOUND FROM GOTO GO
%token GRANT GROUP GROUPING_L HAVING IN_L INDEX INDEX_NO_FILL INDEX_ONLY INDICATOR INSERT INTEGER INTO
%token IS KEY LANGUAGE ENCODING LIKE NULLX NUMERIC OF ON OPEN OPTION
%token PRECISION PRIMARY PRIVILEGES PROCEDURE
%token PUBLIC REAL REFERENCES RESTRICT ROLLBACK ROLLUP SCHEMA SELECT SET
%token SMALLINT SOME SQLCODE SQLERROR TABLE TO UNION
%token UNIQUE UPDATE USER VALUES VIEW WHENEVER WHERE WITH WORK WITHOUT_L
%token ARRAY SETS

/* Extensions */
%token CONTIGUOUS OBJECT_ID BITMAPPED UNDER CLUSTER __ELASTIC CLUSTERED VARCHAR VARBINARY BINARY LONG_L REPLACING SOFT HASH LOOP IRI_ID IRI_ID_8 SAME_AS TRANSITIVE QUIETCAST_L SPARQL_L UNAME_L
%token DICTIONARY_L REFERENCE_L

/* Admin statements */
%token SHUTDOWN CHECKPOINT BACKUP REPLICATION
%token SYNC ALTER ADD RENAME DISCONNECT MODIFY

%token BEFORE AFTER INSTEAD TRIGGER REFERENCING OLD


/* procedures */
%token AGGREGATE FUNCTION OUT_L HANDLER IF THEN ELSE ELSEIF WHILE
%token BEGINX ENDX RETURN CALL RETURNS DO EXCLUSIVE PREFETCH
%token SQLSTATE_L SQLWARNING SQLEXCEPTION EXIT RESIGNAL
%token REVOKE PASSWORD OFF LOGX TIMESTAMP DATE_L DATETIME TIME EXECUTE REXECUTE
%token MODULE

/* ODBC brace-escaped keywords. BEGINX_FN_X = "{fn"
   User should not write procedures with calls to functions named
   like fn (or maybe also fnac?) from the beginning of a block
   statement without leaving a space or two after opening brace.
   E.g. if(call_fn is not NULL) {fn(arg1,arg2);} will result
   a syntax error. Other possibility would be make fn itself
   a token and reserved keyword, but I think that is even more
   stupid.
 */

%token BEGIN_FN_X BEGIN_CALL_X BEGIN_OJ_X BEGIN_U_X CONVERT CASE WHEN IDENTITY LEFT RIGHT FULL OUTER
/*%token BEGIN_FN_X BEGIN_CALL_X BEGIN_OJ_X BEGIN_U_X CONVERT CASE WHEN THEN IDENTITY FULL OUTER*/
%token INNER CROSS NATURAL USING JOIN USE COALESCE CAST NULLIF NEW
%token CORRESPONDING EXCEPT INTERSECT BEST TOP PERCENT TIES XML XPATH
%token PERSISTENT INTERVAL INCREMENT_L COMPRESS PARTITION
/* IvAn/XmlView/000810 Options added for "create xml view" statement */
%token DTD INTERNAL EXTERNAL
/* %token SCHEMA is already reserved */
/*%token STRING_CONCAT_OPERATOR*/

/* internationalization keywords */
%token COLLATE NCHAR NVARCHAR

/* replication keywords */
%token INCREMENTAL NONINCREMENTAL PURGE SNAPSHOT
%token IDENTIFIED EXTRACT
%token KWD_TAG

/* IvAn/Fix4AritmSql/000828 Invalid lexems should be handled explicitly */
%token LEXICAL_ERROR

/* ANSI SQL 92 DATE_L/TIME/TIMESTAMP functions */
%token CURRENT_DATE CURRENT_TIME CURRENT_TIMESTAMP

/* CLR CREATE LIBRARY/ASSEMBLY ext keywords */
%token PERMISSION_SET AUTOREGISTER_L LIBRARY_L ASSEMBLY_L SAFE_L UNRESTRICTED_L

/* set transaction isolation level */
%token <box> TRANSACTION_L ISOLATION_L LEVEL_L READ_L COMMITTED_L UNCOMMITTED_L REPEATABLE_L SERIALIZABLE_L

 /* transitive subquery options */
%token T_FINAL_AS T_MIN T_MAX T_IN T_OUT T_SHORTEST_ONLY T_DISTINCT T_EXISTS T_NO_ORDER T_NO_CYCLES T_CYCLES_ONLY T_END_FLAG T_DIRECTION




/* Skip and ws lexems for scn3split.c */
%token WS_WHITESPACE /* This should be the first whitespace token */
%token WS_SPARQL_SKIP
%token WS_PRAGMA_LINE
%token WS_PRAGMA_PREFIX_1 WS_PRAGMA_PREFIX_2 WS_PRAGMA_PREFIX_3
%token WS_PRAGMA_C_ESC WS_PGRAGMA_UTF8_ESC WS_PRAGMA_PL_DEBUG WS_PRAGMA_SRC
%token WS_COMMENT_EOL WS_COMMENT_BEGIN WS_COMMENT_END WS_COMMENT_LONG __COST


/* Important! Do NOT add meaningful SQL tokens at the end of this list!
Instead, add them _before_ WS_WHITESPACE. Tokens after WS_WHITESPACE are
treated as garbage by sql_split_text(). */

%%

/* IvAn/Fix4AritmSql/000828 Trailing semicolon should be trailing explicitly */
sql_list
	: sql_list1 ';'		{ }
	| sql_list1		 { }
	;
sql_list1
	: sql			{ parse_tree = $1; }
/*	| sql_list1 ';' sql	{ }*/
	;


/* schema definition language */
sql
	: schema_element_list  { $$ = t_listst (2, SCHEMA_ELEMENT_LIST,
							t_list_to_array ($1)); }
	| view_def  { $$ = t_listst (2, SCHEMA_ELEMENT_LIST, t_list (1, $1)); }
	| xml_view  { $$ = t_listst (2, SCHEMA_ELEMENT_LIST, t_list (1, $1)); }
	| create_xml_schema { $$ = $1; }
	| drop_xml_schema { $$ = $1; }
	| alter_constraint { $$ = $1; }
	| create_library { $$ = $1; }
	| create_assembly { $$ = $1; }
	| drop_library { $$ = $1; }
	| drop_assembly { $$ = $1; }

	;

/*
schema
	: CREATE SCHEMA AUTHORIZATION user opt_schema_element_list
	;

opt_schema_element_list
	: { $$ = NULL; }
	| schema_element_list
	;
*/

schema_element_list
	: schema_element     { $$ = t_CONS ($1, NULL); }
	| add_column	     { $$ = $1; }
	| schema_element_list schema_element   { $$ = t_NCONC ($1, t_CONS ($2, NULL)); }
	| schema_element_list add_column       { $$ = t_NCONC ($1, $2); }
	;

schema_element
	: base_table_def
/*	| view_def */
	| create_index_def
	| partition_def
	| drop_table
	| drop_index
	| table_rename

	| privilege_def
	| privilege_revoke
	| create_user_statement
	| delete_user_statement
	| set_pass
	| set_group_stmt
	| add_group_stmt
	| delete_group_stmt
	| user_defined_type
	| user_defined_type_drop
	| user_defined_type_alter
	| cluster_def
	;

identifier
	: NAME { $$ = $1; }
	| TYPE			{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| FINAL_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| METHOD		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| CHECKED		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| SYSTEM		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| GENERATED		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| SOURCE		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| RESULT		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| LOCATOR		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| INSTANCE_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| CONSTRUCTOR		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| SELF_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| OVERRIDING		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| STYLE			{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| SQL_L			{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| GENERAL		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| DETERMINISTIC		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
        | DICTIONARY_L          { $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| NO_L			{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| DISABLE_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| NOVALIDATE_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| VALIDATE_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| ENABLE_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| CONTAINS		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| READS			{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| DATA			{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| MODIFIES		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| INPUT			{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| CALLED		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| ADA			{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| C_L3			{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| COBOL			{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| FORTRAN		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| MUMPS			{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| PASCAL_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| PLI			{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| NAME_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| TEXT_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| JAVA			{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| INOUT_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| REMOTE		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
        | REFERENCE_L           { $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| KEYSET		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| VALUE			{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| PARAMETER		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| VARIABLE		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| CLR			{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| TEMPORARY		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| ADMIN_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| __SOAP_DOC		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| __SOAP_DOCW		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| __SOAP_HEADER		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| __SOAP_HTTP		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| __SOAP_NAME		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| __SOAP_TYPE		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| __SOAP_XML_TYPE	{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| __SOAP_FAULT		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| __SOAP_DIME_ENC	{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| __SOAP_ENC_MIME	{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| __SOAP_OPTIONS	{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| START_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| ATTRIBUTE		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| REXECUTE		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| PERMISSION_SET	{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| AUTOREGISTER_L	{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| LIBRARY_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| ASSEMBLY_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| SAFE_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| UNRESTRICTED_L	{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| INCREMENT_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| FOREACH		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| POSITION_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| TRANSACTION_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| ISOLATION_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| LEVEL_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| READ_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| COMMITTED_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| UNCOMMITTED_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| REPEATABLE_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| SERIALIZABLE_L	{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| __TAG_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| RDF_BOX_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| VECTOR_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| UNAME_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| HANDLE_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	| STREAM_L		{ $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	;

opt_with_data
	: /* empty */		{ $$ = 0; }
	| WITH DATA		{ $$ = 1; }
	| WITHOUT_L DATA	{ $$ = 0; }
	;

base_table_opt
	: { $$ = T_ROW; }
	| COLUMN { $$ = T_COLUMN; }
	| DISTINCT COLUMN { $$ = T_DISTINCT_COLUMNS; }
	;


base_table_def
	: CREATE TABLE new_table_name '(' base_table_element_commalist ')' base_table_opt
		{ $$ = t_listst (4, TABLE_DEF, $3,
				 t_list_to_array (sqlc_ensure_primary_key (sqlp_process_col_options ($3, $5))), (ptrlong) $7); }
        | CREATE TABLE new_table_name AS query_exp opt_with_data
		{ $$ = t_listst (4, CREATE_TABLE_AS, $3, $5, t_box_num ((ptrlong) $6)); }
	;

base_table_element_commalist
	: base_table_element
	| base_table_element_commalist ',' base_table_element
			{ $$ = t_NCONC ($1, $3); }
	;

base_table_element
	: column_def
	| table_constraint_def { $$ = t_CONS (NULL, t_CONS ($1, NULL)); }
	;

column_def
	: column column_data_type column_def_opt_list
		{ $$ = t_CONS ($1, t_CONS (t_list (2, $2, t_list_to_array ($3)), NULL)); }
	;

opt_referential_triggered_action
	: /* empty */ { $$ = t_listst (2, 0, 0); }
	| referential_rule {
			  caddr_t *l = (caddr_t *)$1;
			$$ = (l[0] ? t_listst (2, 0, l[1]) : t_listst (2, l[1], 0));
		      }
	| referential_rule referential_rule
		      {
			  caddr_t *l  = (caddr_t *)$1;
			  caddr_t *ll = (caddr_t *)$2;
			if (l[0] == ll [0])
			  yyerror (scanner,"duplicated referential actions");
			$$ = (l[0] ? t_listst (2, ll[1], l[1]) : t_listst (2, l[1], ll[1]));
		      }
	;

referential_rule
	: ON UPDATE referential_action { $$ = t_listst (2, 0, (ptrlong) $3); }
	| delete_referential_rule { $$ = $1; }
	;

delete_referential_rule
	: ON DELETE_L referential_action { $$ = t_listst (2, (ptrlong) 1, (ptrlong) $3); }
	;

opt_on_delete_referential_rule
	: /* empty */ { $$ = NULL; }
	| delete_referential_rule { $$ = $1; }
	;

referential_action
	: CASCADE	{ $$ = 1; }
	| SET NULLX	{ $$ = 2; }
	| SET DEFAULT	{ $$ = 3; }
	;

referential_state
	: 				{ $$ = 0; }
	| ENABLE_L  VALIDATE_L  	{ $$ = 0; }
	| ENABLE_L  NOVALIDATE_L  	{ $$ = 1; }
	| DISABLE_L VALIDATE_L  	{ $$ = 2; }
	| DISABLE_L NOVALIDATE_L  	{ $$ = 3; }
	;

references
	: REFERENCES q_table_name opt_column_commalist opt_referential_triggered_action referential_state
		{
		  caddr_t *l = (caddr_t *) $4;
		  $$ = t_listst (9, FOREIGN_KEY, NULL, $2, $3, NULL, l[0], l[1], NULL, (ptrlong) $5);
		}
	;

column_def_opt_list
	: /* empty */   { $$ = NULL; }
	| column_def_opt_list column_def_opt  { $$ = $2 ? t_NCONC ($1, t_CONS ($2, NULL)) : $1; }
	;

identity_opt
	: START_L WITH signed_literal  { $$ = t_listst (2, CO_ID_START, $3); }
        | INCREMENT_L BY INTNUM { $$ = t_listst (2, CO_ID_INCREMENT_BY, $3); }
/* one day ... ;-)
	| MAXVALUE signed_literal
	| NO_L MAXVALUE
	| MINVALUE signed_literal
	| NO_L MINVALUE
	| CYCLE
	| NO_L CYCLE
*/
	;

compression_spec
	: NO_L COMPRESS { $$ = t_listst (2, CO_COMPRESS, (ptrlong)CC_NONE); }
	| COMPRESS ANY { $$ = t_listst (2, CO_COMPRESS, (ptrlong)CC_OFFSET); }
	| COMPRESS TEXT_L { $$ = t_listst (2, CO_COMPRESS, (ptrlong)CC_PREFIX); }
	;


identity_opt_list
 	: identity_opt			 { $$ = t_CONS ($1, NULL); }
	| identity_opt_list ',' identity_opt { $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

column_def_opt
	: NOT NULLX		{ $$ = (ST *) COL_NOT_NULL; }
	| NULLX			{ $$ = (ST *) NULL; }
	| IDENTITY		{ $$ = (ST *) CO_IDENTITY; }
	| IDENTITY '(' identity_opt_list ')'		{ $$ = t_listst (2, CO_IDENTITY, t_list_to_array ($3)); }
	| PRIMARY KEY '('opt_index_option_list ')'	{ $$ = t_listst (5, INDEX_DEF, NULL, NULL, NULL, $4); }
	| PRIMARY KEY 		 { dk_set_t opts = sqlp_index_default_opts (NULL); caddr_t * oa = opts ? (caddr_t*)t_list_to_array (opts) : NULL; $$ = t_listst (5, INDEX_DEF, NULL, NULL, NULL, oa); }
	| compression_spec { $$ = $1; }
	| DEFAULT signed_literal	{ $$ = t_listst (2, COL_DEFAULT, $2); }
	| COLLATE q_table_name	{ $$ = t_listst (2, COL_COLLATE, $2); }
	| references		   { $$ = $1; }
	| IDENTIFIED BY column	{ $$ = t_listst (2, COL_XML_ID, $3); }
/*	| DEFAULT USER */
	| CHECK '(' search_condition ')'  { $$ = t_listst (3, CHECK_CONSTR, $3, NULL); }
	| WITH SCHEMA column_xml_schema_def
		{
		  ST * check;
		  BIN_OP (check, BOP_NULL,
		    t_listst (3, CALL_STMT,
		      t_sqlp_box_id_upcase ("DB.DBA.XML_COLUMN_SCHEMA_VALIDATE"), $3 ),
		      NULL );
		  $$ = t_listst (3, CHECK_XMLSCHEMA_CONSTR, check, NULL);
		}
	| UNIQUE		 { dk_set_t opts = t_CONS (t_box_string ("unique"), sqlp_index_default_opts (NULL));
	   $$ = t_listst (5, UNIQUE_DEF, NULL, NULL, NULL,
			  t_list_to_array (opts) ); }
	| UNIQUE '(' index_option_list ')'		 {  dk_set_t opts = t_CONS (t_box_string ("unique"), $3);
	   $$ = t_listst (5, UNIQUE_DEF, NULL, NULL, NULL,
			  (ST *) t_list_to_array (opts)); }
	;

column_xml_schema_def
	: '(' STRING ',' STRING ')'  { $$ = t_listst (6, NULL, NULL, NULL, $2, $4, (caddr_t) t_NULLCONST); }
	| '(' STRING ',' STRING ',' STRING ')'  { $$ = t_listst (6, NULL, NULL, NULL, $2, $4, $6); }
	;


table_constraint_def
	: UNDER q_table_name
		{ $$ = t_listst (2, TABLE_UNDER, t_list (1, $2)); }
	| opt_constraint_name PRIMARY KEY '(' index_column_commalist ')' opt_index_option_list
		{ $$ = t_listst (5, INDEX_DEF, NULL, NULL,
		    sqlp_string_col_list ((caddr_t *) t_list_to_array ($5)), $7); }
	| opt_constraint_name FOREIGN KEY '(' column_commalist ')' references
		{ $$ = $7; $7->_.fkey.fk_cols = (caddr_t*) t_list_to_array ($5); $7->_.fkey.fk_name = $1; }
	| opt_constraint_name CHECK '(' search_condition ')'
		{ $$ = t_listst (3, CHECK_CONSTR, $4, $1); }
	| opt_constraint_name UNIQUE '(' column_commalist ')'
		{ $$ =
		  t_listst (5, UNIQUE_DEF, $1, NULL,
		      sqlp_string_col_list ((caddr_t *) t_list_to_array ($4)),
		      (ST *) t_list (1, t_box_string ("unique"))); }
	| opt_constraint_name GROUP opt_index_option_list '(' index_column_commalist ')' { $$ = t_listst (4, COLUMN_GROUP, $1, $3, sqlp_string_col_list (t_list_to_array ($5))); }
	;

opt_constraint_name
	: /*empty*/	{ $$ = NULL; }
	| CONSTRAINT identifier	{ $$ = $2; }
	;

column_commalist
	: column	{ $$ = t_CONS ($1, NULL); }
	| column_commalist ',' column	{ $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

index_column_commalist
	: column opt_asc_desc	{ $$ = t_CONS ($1, NULL); }
	| index_column_commalist ',' column opt_asc_desc { $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

index_option
	: CLUSTERED	{ $$ = t_box_string ("clustered"); }
	| UNIQUE	{ $$ = t_box_string ("unique"); }
	| OBJECT_ID	{ $$ = t_box_string ("object_id"); }
	| BITMAPPED 	{ $$ = t_box_string ("bitmap"); }
	| DISTINCT { $$ = t_box_string ("distinct"); }
	| COLUMN 		{
				    $$ = t_box_string (sqlp_inx_col_opt ());
				}
	| NOT COLUMN { $$ = t_box_string ("not_column"); }
	| NOT NULLX { $$ = t_box_string ("not_null"); }
	| NO_L PRIMARY KEY REF { $$ = t_box_string ("no_pk"); }
	| INDEX_NO_FILL { $$ = t_box_string ("no_fill"); }
	;

index_option_list
	: index_option	{ $$ = t_CONS ($1, NULL); }
	| index_option_list index_option { $$ = t_NCONC ($1, t_CONS ($2, NULL)); }
	;

opt_index_option_list
	: /* empty */		{ dk_set_t deflt = sqlp_index_default_opts (NULL); if (deflt) $$ = (ST *) t_list_to_array (deflt); else $$ = NULL; }
	| index_option_list	{ $$ = (ST *) t_list_to_array (sqlp_index_default_opts ($1)); }
	;

create_index_def
	: CREATE opt_index_option_list INDEX index
		ON q_table_name '(' index_column_commalist ')'
		{ $$ = t_listst (5, INDEX_DEF, $4, $6, t_list_to_array ($8), $2); }
	| CREATE opt_index_option_list INDEX index
	ON q_table_name '(' index_column_commalist ')' PARTITION opt_cluster col_part_list
{ ST * opts = (ST *) t_box_append_1  ((caddr_t) $2, (caddr_t) t_listst (5, PARTITION_DEF,  NULL, NULL, $11, t_list_to_array ($12)));
		 $$ = t_listst (5, INDEX_DEF, $4, $6, t_list_to_array ($8), opts); }
	;

drop_index
	: DROP INDEX identifier opt_table   { $$ = t_listst (3, INDEX_DROP, $3, $4); }
	;

opt_table
	: /* empty */		{ $$ = NULL; }
	| q_table_name		{ $$ = $1; }
	;

drop_table
	: DROP TABLE q_table_name	{ $$ = t_listst (2, TABLE_DROP, $3); }
	| DROP VIEW q_table_name	{ $$ = t_listst (2, TABLE_DROP, $3); }
	;

opt_col_add_column
	: /* empty */ { $$ = 0; }
	| COLUMN { $$ = 1; }
	;

add_col_column_def_list
	: column_def { $$ = t_CONS ($1, NULL); }
	| add_col_column_def_list ',' column_def { $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

add_col_column_list
	: column { $$ = t_CONS ($1, NULL); }
	| add_col_column_list ',' column { $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

add_column
	: ALTER TABLE q_table_name ADD opt_col_add_column add_col_column_def_list
		{
		  dk_set_t ret = NULL, col_defs_list = $6;
		  DO_SET (dk_set_t, col_def, &col_defs_list)
		    {
		      t_set_push (&ret, t_listst (3, ADD_COLUMN, $3, t_list_to_array (col_def)));
		    }
		  END_DO_SET ();
		  $$ = ret;
		}
	| ALTER TABLE q_table_name DROP opt_col_add_column add_col_column_list
		{
		  dk_set_t ret = NULL, col_ref_list = $6;
		  DO_SET (caddr_t, col_ref, &col_ref_list)
		    {
		      t_set_push (&ret, t_listst (3, DROP_COL, $3, col_ref));
		    }
		  END_DO_SET ();
		  $$ = ret;
		}
	| ALTER TABLE q_table_name MODIFY opt_col_add_column column_def
		{
		  $$ = t_CONS (t_listst (3, MODIFY_COLUMN, $3, t_list_to_array ($6)), NULL);
		}
	;

table_rename
	: ALTER TABLE q_table_name RENAME new_table_name
		{ $$ = t_listst (3, TABLE_RENAME, $3, $5); }
	;


constraint_op
	: ADD { $$ = 1; }
	| DROP { $$ = 2; }
	| MODIFY { $$ = 3; }
	;

opt_drop_behavior
	:		 { $$ = 0; }
	| CASCADE	 { $$ = 1; }
	| RESTRICT	 { $$ = 2; }
	;

opt_table_constraint_def
	: CONSTRAINT identifier opt_drop_behavior
		{
		  $$ = t_listst (9, FOREIGN_KEY, NULL, NULL, NULL, NULL, NULL, NULL, (ptrlong) $2, (ptrlong) 0);
		}
	| table_constraint_def { $$ = $1; }
	;

alter_constraint
	: ALTER TABLE q_table_name constraint_op opt_table_constraint_def
	{ ST * c = $5;
	if (INDEX_DEF == c->type)
	  c->type = 0;
	else if (c->type == FOREIGN_KEY)
	  c->type = 1;
	else if (c->type == UNIQUE_DEF)
	  c->type = 2;
	else if (c->type == CHECK_CONSTR)
	  c->type = 3;
	else
	  yyerror (scanner,"ALTER TABLE constraint must be foreign key, primary key, unique or check");
	$$ = (ST*) t_list (3, CALL_STMT, t_sqlp_box_id_upcase ("DB.DBA.ddl_alter_constr"),
		   t_list (3, $3, (ptrlong) $4, t_list (2, QUOTE, $5))); }
	;

create_xml_schema
	: CREATE XML SCHEMA STRING
	    { $$ = t_listst (3, CALL_STMT,
		  t_sqlp_box_id_upcase ("DB.DBA.SYS_CREATE_XML_SCHEMA"),
		  t_list (1, $4)); }
	;

drop_xml_schema
	: DROP XML SCHEMA STRING
	    { $$ = t_listst (3, CALL_STMT,
		  t_sqlp_box_id_upcase ("DB.DBA.SYS_DROP_XML_SCHEMA"),
		  t_list (1, $4)); }
	;

view_query_spec
	: query_exp
	/*| query_no_from_spec*/
	;

view_def_select_and_opt
	: opt_column_commalist AS view_query_spec opt_with_check_option
		{ $$ = t_listst (5, VIEW_DEF, NULL /* temp value, will set in view_def rule */,
			sqlp_view_def ((ST **) $1,
			  $3, 0), NULL, (ptrlong) $4); }
	| opt_column_commalist AS SPARQL_L sqlonly_query_exp
		{ $$ = t_listst (5, VIEW_DEF, NULL /* temp value, will set in view_def rule */,
			sqlp_view_def ((ST **) $1,
			  $4, 0), NULL, (ptrlong) 0); }
	;

view_def
	: CREATE VIEW new_table_name { sqlp_in_view ($3); }
		view_def_select_and_opt
                { $$ = $5; $$->_.view_def.name = $3; }
	| CREATE PROCEDURE VIEW new_table_name AS q_table_name '(' column_commalist_or_empty ')' '(' proc_col_list ')'
		{ $$ = (ST*) t_list (5, VIEW_DEF, $4,
		    t_list (5, PROC_TABLE, $6, $8,
		      t_list_to_array (sqlc_ensure_primary_key (sqlp_process_col_options ($4, $11))),
		      NULL ),
		    NULL, NULL); }
	;

opt_with_check_option
	: /* empty */		  { $$ = 0; }
	| WITH CHECK OPTION	{ $$ = 1; }
	;

opt_column_commalist
	: /* empty */			{ $$ = t_listst (0); }
	| '(' column_commalist ')'	{ $$ = (ST *) t_list_to_array ($2); }
	;

priv_opt_column_commalist
	: /* empty */			{ $$ = (ST *) 0; }
	| '(' column_commalist ')'	{ $$ = (ST *) t_list_to_array ($2); }
	;

privilege_def
	: GRANT ALL PRIVILEGES TO grantee
		{ $$ = t_listst (3, SET_GROUP_STMT, $5, t_box_string ("dba")); }
	| GRANT privileges ON table TO grantee_commalist opt_with_grant_option
		{ $$ = t_listst (4, GRANT_STMT, $2, $4, t_list_to_array ($6)); }
	| GRANT EXECUTE ON function_name TO grantee_commalist opt_with_grant_option
		{ $$ = t_listst (4, GRANT_STMT,
		    t_list (1,
		      t_listst (3, NULL, GR_EXECUTE, NULL)),
		    t_list (5, TABLE_DOTTED, $4, NULL, sqlp_view_u_id (), sqlp_view_g_id ()),
		    t_list_to_array ($6)); }
	| GRANT REXECUTE ON STRING TO grantee_commalist
		{ $$ = t_listst (4, GRANT_STMT,
		    t_list (1,
                      t_listst (3, NULL, GR_REXECUTE, NULL)),
		    t_list (5, TABLE_DOTTED, $4, NULL, sqlp_view_u_id (), sqlp_view_g_id ()),
		    t_list_to_array ($6)); }
	| GRANT UNDER ON q_old_type_name TO grantee_commalist opt_with_grant_option
		{ $$ = t_listst (4, GRANT_STMT,
		    t_list (1,
		      t_listst (3, NULL, GR_UDT_UNDER, NULL)),
		    t_list (5, TABLE_DOTTED, $4, NULL, sqlp_view_u_id (), sqlp_view_g_id ()),
		    t_list_to_array ($6)); }

	| GRANT grantee_commalist TO grantee_commalist opt_with_admin_option
		{ $$ = t_listst (4, GRANT_ROLE_STMT, t_list_to_array ($2), t_list_to_array ($4), (ptrlong) $5); }
	;

opt_with_admin_option
	: /* empty */ 		{ $$ = 0; }
	| WITH ADMIN_L OPTION  	{ $$ = 1; }
	;

privilege_revoke
/* CAUSES GPF !
	: REVOKE ALL PRIVILEGES FROM grantee_commalist
		{ $$ = t_listst (4, GRANT_STMT, NULL, NULL, list_to_array ($5)); }
*/
	: REVOKE privileges ON table FROM grantee_commalist
		{ $$ = t_listst (4, REVOKE_STMT, $2, $4, t_list_to_array ($6)); }

	| REVOKE EXECUTE ON function_name FROM grantee_commalist
		{ $$ = t_listst (4, REVOKE_STMT,
		    t_list (1,
		      t_listst (3, NULL, GR_EXECUTE, NULL)),
		    t_list (5, TABLE_DOTTED, $4, NULL, sqlp_view_u_id (), sqlp_view_g_id ()),
		    t_list_to_array ($6)); }
	| REVOKE UNDER ON q_old_type_name FROM grantee_commalist
		{ $$ = t_listst (4, REVOKE_STMT,
		    t_list (1,
		      t_listst (3, NULL, GR_UDT_UNDER, NULL)),
		    t_list (5, TABLE_DOTTED, $4, NULL, sqlp_view_u_id (), sqlp_view_g_id ()),
		    t_list_to_array ($6)); }
	| REVOKE REXECUTE ON STRING FROM grantee_commalist
		{ $$ = t_listst (4, REVOKE_STMT,
		    t_list (1,
		      t_listst (3, NULL, GR_REXECUTE, NULL)),
		    t_list (5, TABLE_DOTTED, $4, NULL, sqlp_view_u_id (), sqlp_view_g_id ()),
		    t_list_to_array ($6)); }
	| REVOKE grantee_commalist FROM grantee_commalist
		{ $$ = t_listst (4, REVOKE_ROLE_STMT, t_list_to_array ($2), t_list_to_array ($4), 0); }
	;

opt_with_grant_option
	: /* empty */  		{ $$ = 0; }
	| WITH GRANT OPTION	{ $$ = 1; }
	;

privileges
	: ALL PRIVILEGES
			{
			  $$ = t_listbox (5,
				t_list (3, NULL, GR_SELECT, NULL),
				t_list (3, NULL, GR_INSERT, NULL),
				t_list (3, NULL, GR_UPDATE, NULL),
				t_list (3, NULL, GR_DELETE, NULL),
				t_list (3, NULL, GR_REFERENCES, NULL),
				t_list (3, NULL, GR_REXECUTE, NULL),
				t_list (3, NULL, GR_EXECUTE, NULL),
				t_list (3, NULL, GR_UDT_UNDER, NULL)
				);
			}
	| ALL
			{
			  $$ = t_listbox (6,
				t_list (3, NULL, GR_SELECT, NULL),
				t_list (3, NULL, GR_INSERT, NULL),
				t_list (3, NULL, GR_UPDATE, NULL),
				t_list (3, NULL, GR_DELETE, NULL),
				t_list (3, NULL, GR_REFERENCES, NULL),
				t_list (3, NULL, GR_REXECUTE, NULL),
				t_list (3, NULL, GR_EXECUTE, NULL),
				t_list (3, NULL, GR_UDT_UNDER, NULL)
				);
			}
	| operation_commalist	{ $$ = t_list_to_array_box ($1); }
	;

operation_commalist
	: operation		{ $$ = t_CONS ($1, NULL); }
	| operation_commalist ',' operation
				{ $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

operation
	: SELECT priv_opt_column_commalist
			{ $$ = t_listst (3, NULL, GR_SELECT, $2); }
	| INSERT	{ $$ = t_listst (3, NULL, GR_INSERT, NULL); }
	| DELETE_L	{ $$ = t_listst (3, NULL, GR_DELETE, NULL); }
	| UPDATE priv_opt_column_commalist
			{ $$ = t_listst (3, NULL, GR_UPDATE, $2); }
	| REFERENCES priv_opt_column_commalist
			{ $$ = t_listst (3, NULL, GR_REFERENCES, $2); }
/*	| EXECUTE	{ $$ = t_listst (3, NULL, GR_EXECUTE, NULL); }*/
	;

grantee_commalist
	: grantee	{ $$ = t_CONS ($1, NULL); }
	| grantee_commalist ',' grantee
			{ $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

grantee
	: PUBLIC	{ $$ = (caddr_t) U_ID_PUBLIC; }
	| user
	;

set_pass
	: SET PASSWORD identifier identifier
			{ $$ = t_listst (3, SET_PASS_STMT, $3, $4); }
	;

create_user_statement
	: CREATE USER user	{ $$ = t_listst (2, CREATE_USER_STMT, $3); }
	| CREATE ROLE_L user    { $$ = t_listst (2, CREATE_ROLE_STMT, $3); }
	;

delete_user_statement
	 : DELETE_L USER user		{ $$ = t_listst (2, DELETE_USER_STMT, $3); }
	 | DELETE_L USER user CASCADE	{ $$ = t_listst (3, DELETE_USER_STMT, $3, t_box_num (1)); }
	 | DROP USER user		{ $$ = t_listst (2, DELETE_USER_STMT, $3); }
	 | DROP USER user CASCADE	{ $$ = t_listst (3, DELETE_USER_STMT, $3, t_box_num (1)); }
	 | DROP ROLE_L user		{ $$ = t_listst (2, DROP_ROLE_STMT, $3); }
	;

set_group_stmt
	: SET USER GROUP user user
				{ $$ = t_listst (3, SET_GROUP_STMT, $4, $5); }
	;

add_group_stmt
	: ADD USER GROUP user user
				{ $$ = t_listst (3, ADD_GROUP_STMT, $4, $5); }
        ;

delete_group_stmt
	: DELETE_L USER GROUP user user
				{ $$ = t_listst (3, DELETE_GROUP_STMT, $4, $5); }
	;

opt_attach_primary_key
	: /* empty */
		{ $$ = (ST *) t_alloc_box (0, DV_DB_NULL); }
	| PRIMARY KEY '(' column_commalist ')'
		{
		  $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("vector"),
		      sqlp_string_col_list (t_list_to_array ($4)));
		}
	;

attach_table
	: ATTACH TABLE attach_q_table_name opt_attach_primary_key opt_as FROM literal opt_login opt_not_select opt_remote_name
	    {
	      caddr_t *l = (caddr_t *) $8;
	      $$ = t_listst (3, CALL_STMT,
		  $9,
		  t_list (7, $7, $3, $5, l[0], l[1], $4, $10));
	    }
	;

opt_as
	: /* empty */		{ $$ = t_alloc_box (0, DV_DB_NULL); }
	| AS new_table_name	{ $$ = $2; }
	;

opt_login
	: /* empty */
		{ $$ = t_listst (2, t_alloc_box (0, DV_DB_NULL),
			t_alloc_box (0, DV_DB_NULL));
		}
	| USER scalar_exp PASSWORD scalar_exp
				{ $$ = t_listst (2, $2, $4); }
	;

opt_not_select
	: /* empty */ { $$ = t_sqlp_box_id_upcase ("DB.DBA.vd_attach_view"); }
	| NOT SELECT  { $$ = t_sqlp_box_id_upcase ("DB.DBA.vd_attach_view_no_select"); }
	;

opt_remote_name
	: /* empty */ { $$ = NULL; }
	| REMOTE AS scalar_exp
	        {
		  $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("concat"),
		      t_list (2, t_box_string ("\1"), $3));
		}
	;

cursor_type
	: STATIC_L { $$ = _SQL_CURSOR_STATIC; }
	| DYNAMIC  { $$ = _SQL_CURSOR_DYNAMIC; }
	| KEYSET  { $$ = _SQL_CURSOR_KEYSET_DRIVEN; }
	;

/* cursor definition */
cursor_def
	: DECLARE identifier CURSOR FOR query_exp
				{
				  $$ = t_listst (5, CURSOR_DEF, $2, $5, _SQL_CURSOR_FORWARD_ONLY, NULL);
				}
	| DECLARE identifier cursor_type CURSOR FOR query_exp
				{
				  $$ = t_listst (5, CURSOR_DEF, $2, $6, (ptrlong) $3, NULL);
				}
	;

opt_order_by_clause
	: /* empty */		{ $$ = NULL; }
	| ORDER BY ordering_spec_commalist { $$ = t_list_to_array_box ($3); }
	;

ordering_spec_commalist
	: ordering_spec		{ $$ = t_CONS ($1, NULL); }
	| ordering_spec_commalist ',' ordering_spec
				{ $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

ordering_spec
	: scalar_exp opt_asc_desc
		{ $$ = t_listst (4, ORDER_BY, (caddr_t) $1, (ptrlong) $2, NULL);  }
	|  mssql_xml_col opt_asc_desc
		{ $$ = (ST*) t_list (4, ORDER_BY, t_list (3, COL_DOTTED, NULL, sqlp_xml_col_name ($1)), (ptrlong) $2, NULL); }
	;

opt_asc_desc
	: /* empty */		{ $$ = ORDER_ASC; }
	| ASC			{ $$ = ORDER_ASC; }
	| DESC			{ $$ = ORDER_DESC; }
	;

/* replication statements */
create_snapshot_log
	: CREATE SNAPSHOT LOGX FOR q_table_name
	    { $$ = t_listst (3, CALL_STMT,
		  t_sqlp_box_id_upcase ("DB.DBA.repl_create_snapshot_log"),
		  t_list (1, $5)); }
	;

drop_snapshot_log
	: DROP SNAPSHOT LOGX FOR q_table_name
	    { $$ = t_listst (3, CALL_STMT,
		  t_sqlp_box_id_upcase ("DB.DBA.repl_drop_snapshot_log"),
		  t_list (1, $5)); }
	;

purge_snapshot_log
	: PURGE SNAPSHOT LOGX FOR q_table_name
	    { $$ = t_listst (3, CALL_STMT,
		  t_sqlp_box_id_upcase ("DB.DBA.repl_purge_snapshot_log"),
		  t_list (1, $5)); }
	;

opt_snapshot_string_literal
	: /* empty */		 { $$ = (caddr_t) t_NULLCONST; }
	| STRING		{ $$ = $1; }
	;

opt_snapshot_where_clause
	: /* empty */		 { $$ = (caddr_t) t_NULLCONST; }
	| WHERE STRING		{ $$ = $2; }
	;

create_snapshot
	: CREATE SNAPSHOT q_table_name FROM q_table_name opt_snapshot_string_literal opt_snapshot_where_clause
	    { $$ = t_listst (3, CALL_STMT,
		  t_sqlp_box_id_upcase ("DB.DBA.repl_create_inc_snapshot"),
		  t_list (4, $6, $5, $7, $3)); }
	| CREATE NONINCREMENTAL SNAPSHOT q_table_name AS STRING
	    { $$ = t_listst (3, CALL_STMT,
		  t_sqlp_box_id_upcase ("DB.DBA.repl_create_snapshot"),
		  t_list (2, $6, $4)); }
	;

opt_with_delete
	: /* empty */		{ $$ = t_box_num (0); }
	| WITH DELETE_L		{ $$ = t_box_num (1); }
	;

drop_snapshot
	: DROP SNAPSHOT q_table_name opt_with_delete
	    { $$ = t_listst (3, CALL_STMT,
		  t_sqlp_box_id_upcase ("DB.DBA.repl_drop_snapshot"),
		  t_list (2, $3, $4)); }
	;

opt_nonincremental
	: /* empty */		{ $$ = 0; }
	| AS NONINCREMENTAL	{ $$ = 1; }
	;

refresh_snapshot
	: UPDATE SNAPSHOT q_table_name opt_nonincremental
	    {
	      if ($4)
		$$ = t_listst (3, CALL_STMT,
		    t_sqlp_box_id_upcase ("DB.DBA.repl_refresh_noninc_snapshot"),
		    t_list (1, $3));
	      else
		$$ = t_listst (3, CALL_STMT,
		    t_sqlp_box_id_upcase ("DB.DBA.repl_refresh_inc_snapshot"),
		    t_list (1, $3)); }
	;

create_freetext_index
	: CREATE TEXT_L opt_xml INDEX ON q_table_name '(' column ')' opt_with_key opt_deffer_generation opt_with opt_data_modification_action opt_lang opt_enc
            {
	    /*  if (!stricmp ($2, "TEXT"))
		{*/
		  $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("DB.DBA.vt_create_text_index"),
		      t_list (9, $6, t_box_string ($8), $10, $3, $11, t_list(2, QUOTE, $12), $13, $14, $15));
/*		}
	      else
		yyerror (scanner,"Not a text index");*/
	    }
	;

opt_data_modification_action
	: /* empty */		 { $$ = t_box_num(0); }
	| USING FUNCTION	 { $$ = t_box_num(1); }
	;

opt_column
	: /*empty*/	 { $$ = NULL; }
	| '(' column ')' { $$ = t_box_string ($2); }
	;

create_freetext_trigger
	: CREATE TEXT_L TRIGGER ON q_table_name opt_column
	    {
	      $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("DB.DBA.vt_create_ftt"),
		  t_list (4, $5, NULL, $6, NULL));
	    }
	;

drop_freetext_trigger
	: DROP TEXT_L TRIGGER ON q_table_name opt_column
	    {
	      $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("DB.DBA.vt_drop_ftt"),
		  t_list (2, $5, $6));
	    }
	;

opt_xml
	: /* empty */	{ $$ = t_box_num (0); }
	| XML		{ $$ = t_box_num (1); }
	;

opt_with_key
	: /* empty */		{ $$ = (caddr_t) t_NULLCONST; }
	| WITH KEY column	{ $$ = t_box_string ($3); }
	;

opt_with
	: /* empty */		{ $$ = (ST*) t_NULLCONST; }
	| CLUSTERED WITH '(' column_commalist ')'	{ $$ = (ST*) t_list_to_array ($4); }
	;

opt_lang
	: /* empty */		{ $$ = (caddr_t) t_NULLCONST; }
	| LANGUAGE STRING	{ $$ = $2; }
	;

opt_enc
	: /* empty */		{ $$ = (caddr_t) t_NULLCONST; }
	| ENCODING STRING	{ $$ = $2; }
	;

opt_deffer_generation
	: /* empty */		{ $$ = t_box_num (0); }
	| NOT INSERT		{ $$ = t_box_num (1); }
	;

/* manipulative statements */
sql
	: manipulative_statement
	;

manipulative_statement
	: query_or_sparql_exp
	/*| query_no_from_spec*/
	| update_statement_positioned
	| update_statement_searched
	| insert_statement
	| delete_statement_positioned
	| delete_statement_searched
	| call_statement
	| static_method_invocation
	| METHOD CALL static_method_invocation { $$ = $3; }
	| top_level_method_invocation
	| set_statement
	| drop_xml_view
	| commit_statement
	| rollback_statement
	| admin_statement
	| use_statement
	| attach_table
	| create_snapshot_log
	| drop_snapshot_log
	| purge_snapshot_log
	| create_snapshot
	| drop_snapshot
	| refresh_snapshot
	| create_freetext_index
	| create_freetext_trigger
	| drop_freetext_trigger
	;

use_statement
	: USE identifier
		{ $$ = t_listst (3, CALL_STMT,
			t_sqlp_box_id_upcase ("set_qualifier"),
			t_list (1, sqlp_new_qualifier_name ($2, box_length ($2)))); }
	;

close_statement
	: CLOSE cursor	{ $$ = t_listst (2, CLOSE_STMT, $2); }
	;


commit_statement
	: COMMIT WORK   { $$ = (ST*) t_list (3, CALL_STMT, t_sqlp_box_id_upcase ("__commit"), t_list (0)); }
	;


delete_statement_positioned
	: DELETE_L FROM table WHERE CURRENT OF cursor opt_sql_opt
{ $$ = t_listst (4, DELETE_POS, $7, $3, $8); }
	;

delete_statement_searched
	: DELETE_L FROM table opt_where_clause opt_sql_opt
		{ $$ = t_listst (2, DELETE_SRC,
		      sqlp_infoschema_redirect (t_listst (9, TABLE_EXP, t_list (1, $3),
		      $4, NULL, NULL, NULL, NULL, $5, NULL))); }
	;

fetch_statement
	: FETCH cursor INTO target_commalist
		{ $$ = t_listst (5, FETCH_STMT, $2, t_list_to_array ($4), (ptrlong) _SQL_FETCH_NEXT, t_box_num (1)); }
	| FETCH cursor NAME INTO target_commalist
		{
		  ptrlong fetch_type = sqlp_fetch_type_to_code ($3);
		  $$ = t_listst (5, FETCH_STMT, $2, t_list_to_array ($5), fetch_type, t_box_num (1));
		}
	| FETCH cursor NAME scalar_exp INTO target_commalist
		{
		  ptrlong fetch_type = sqlp_fetch_type_to_code ($3);
		  $$ = t_listst (5, FETCH_STMT, $2, t_list_to_array ($6), fetch_type, $4);
		}
	;

insert_mode
	: INTO		{ $$ = INS_NORMAL; }
	| REPLACING	{ $$ = INS_REPLACING; }
	| SOFT		{ $$ = INS_SOFT; }
	;


opt_index
	: { $$ = NULL;}
	| INDEX NAME {$$ = $2; }
	;


insert_statement
	: INSERT insert_mode table opt_index opt_sql_opt priv_opt_column_commalist values_or_query_spec
{ $$ = t_listst (7, INSERT_STMT, $3, $6, $7, (ptrlong) $2, $4, $5); }
	;

values_or_query_spec
	: VALUES '(' insert_atom_commalist ')'
		{ $$ = t_listst (2, INSERT_VALUES, sqlp_wrapper_sqlxml((ST**)t_list_to_array ($3))); }
	| query_spec /* FROM is mandatory here */
	;

insert_atom_commalist
	: insert_atom	{ $$ = t_CONS ($1, NULL); }
	| insert_atom_commalist ',' insert_atom
			{ $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

insert_atom
	: scalar_exp
	;



sql_option
	: ORDER { $$ = t_CONS (OPT_ORDER, t_CONS (1, NULL)); }
	| ANY ORDER { $$ = t_CONS (OPT_ANY_ORDER, t_CONS (1, NULL)); }
	| QUIETCAST_L { $$ = t_CONS (OPT_SPARQL, t_CONS (1, NULL)); }
	| SAME_AS { $$ = t_CONS (OPT_SAME_AS, t_CONS (1, NULL)); }
	| ARRAY { $$ = t_CONS (OPT_ARRAY, t_CONS (1, NULL)); }
	| HASH { $$ = t_CONS (OPT_JOIN, t_CONS (OPT_HASH, NULL)); }
	| HASH SET INTNUM  { $$ = t_CONS (OPT_HASH_SET, t_CONS ($3, NULL)); }
	| HASH PARTITION column { $$ = t_CONS (OPT_HASH_PARTITION, t_CONS ( $3, NULL)); }
	| HASH REPLICATION { $$ = t_CONS (OPT_HASH_REPLICATION, t_CONS ((ptrlong)1, NULL)); }
	| ISOLATION_L txn_isolation_level { $$ = t_CONS (OPT_ISOLATION, t_CONS ( $2, NULL)); }
	| INTERSECT { $$ = t_CONS (OPT_JOIN, t_CONS (OPT_INTERSECT, NULL)); }
	| NO_L __LOCK { $$ = t_CONS (OPT_NO_LOCK, t_CONS (1, NULL)); }
	|  FOR UPDATE { $$ = t_CONS (OPT_NO_LOCK, t_CONS (2, NULL)); }
	| __LOCK { $$ = t_CONS (OPT_NO_LOCK, t_CONS (3, NULL)); }
	| LOOP { $$ = t_CONS (OPT_JOIN, t_CONS (OPT_LOOP, NULL)); }
	| LOOP EXISTS { $$ = t_CONS (OPT_SUBQ_LOOP, t_CONS (SUBQ_LOOP, NULL)); }
	| DO NOT LOOP EXISTS { $$ = t_CONS (OPT_SUBQ_LOOP, t_CONS (SUBQ_NO_LOOP, NULL)); }
	| INDEX identifier { $$ = t_CONS (OPT_INDEX, t_CONS ($2, NULL)); }
	| INDEX PRIMARY KEY { $$ = t_CONS (OPT_INDEX, t_CONS (t_box_string ("PRIMARY KEY"), NULL)); }
	| INDEX TEXT_L KEY { $$ = t_CONS (OPT_INDEX, t_CONS (t_box_string ("TEXT KEY"), NULL)); }
	| INDEX_ONLY { $$ = t_CONS (OPT_INDEX_ONLY, t_CONS (t_box_num (1), NULL)); }
	| WITH STRING { $$ = t_CONS (OPT_RDF_INFERENCE, t_CONS ($2, NULL)); }
	| NO_L CLUSTER { $$ = t_CONS (OPT_NO_CLUSTER, t_CONS (1, NULL)); }
	| NO_L IDENTITY { $$ = t_CONS (OPT_NO_IDENTITY, t_CONS (1, NULL)); }
	| NO_L TRIGGER { $$ = t_CONS (OPT_NO_TRIGGER, t_CONS (1, NULL)); }
	| TRIGGER { $$ = t_CONS (OPT_TRIGGER, t_CONS (1, NULL)); }
	| INTO scalar_exp { $$ = t_CONS (OPT_INTO, t_CONS ($2, NULL)); }
	| FETCH column_ref BY scalar_exp SET column_ref { $$ = t_cons ((void*)OPT_INS_FETCH, t_cons (t_list (4, OPT_INS_FETCH, $2, $4, $6), NULL)); }
| INDEX ORDER { $$ = t_cons ((void*)OPT_INDEX_ORDER, t_cons ((void*)1, NULL)); }
	| VECTORED { $$ = t_cons ((void*)OPT_VECTORED, t_cons ((void*)1, NULL)); }
	| VECTORED INTNUM { $$ = t_cons ((void*)OPT_VECTORED, t_cons ((void*)$2, NULL)); }
	| PARTITION GROUP BY { $$ = t_cons ((void*)OPT_PART_GBY, t_cons ((void*)1, NULL)); }
	| DO NOT PARTITION GROUP BY { $$ = t_cons ((void*)OPT_NO_PART_GBY, t_cons ((void*)1, NULL)); }
	| CHECK { $$ = t_cons ((void*)OPT_CHECK, t_cons ((void*)1, NULL)); }
	| WITHOUT_L VECTORING { $$ = t_cons ((void*)OPT_NOT_VECTORED, t_cons ((void*)1, NULL)); }
	| PARTITION NAME { $$ = t_cons ((void*)OPT_PARTITION, t_cons ((void*)$2, NULL)); }
	| FROM scalar_exp { $$ = t_cons ((void*)OPT_FROM_FILE, t_cons ((void*)$2, NULL)); }
	| START_L scalar_exp { $$ = t_cons ((void*)OPT_FILE_START, t_cons ((void*)$2, NULL)); }
	| ENDX scalar_exp { $$ = t_cons ((void*)OPT_FILE_END, t_cons ((void*)$2, NULL)); }
	| NAME INTNUM {
	  if (!stricmp ($1, "vacuum"))
	    $$ = t_CONS (OPT_VACUUM, t_CONS ($2, NULL));
	  else if (!stricmp ($1, "RANDOM"))
	    $$ = t_CONS (OPT_RANDOM_FETCH, t_CONS ($2, NULL));
	  else if (!stricmp ($1, "PARALLEL"))
	    $$ = t_CONS (OPT_PARALLEL, t_CONS ($2, NULL));
	  else if (!stricmp ($1, "EST_TIME"))
	    $$ = t_CONS (OPT_EST_TIME, t_CONS ($2, NULL));
	  else if (!stricmp ($1, "EST_SIZE"))
	    $$ = t_CONS (OPT_EST_SIZE, t_CONS ($2, NULL));
	  else
	    $$ = NULL;
	}
	;

sql_opt_commalist
	: sql_option { $$ = $1; }
	| sql_opt_commalist ',' sql_option { $$ = NCONC ($1, $3); }
	;

opt_sql_opt
	: { $$ = NULL; }
	| OPTION '(' sql_opt_commalist ')' { $$ = (ST*) t_list_to_array ($3); }
	;

opt_table_opt
	: { $$ = NULL; }
	| TABLE OPTION '(' sql_opt_commalist ')' { $$ = (ST*) t_list_to_array ($4); }
	;

cursor_option
	: EXCLUSIVE		{ $$  = (ST *) EXCLUSIVE_OPT; }
	| PREFETCH INTNUM	{ $$ = t_listst (2, PREFETCH_OPT, $2); }
	;

cursor_options_commalist
	: cursor_option		{ $$ = t_CONS ($1, NULL); }
	| cursor_options_commalist ',' cursor_option
				{ $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

opt_cursor_options_list
	: /* empty */				{ $$ = NULL; }
	| '(' cursor_options_commalist ')'	{ $$ = t_list_to_array_box ($2); }
	;

open_statement
	: OPEN cursor opt_cursor_options_list
		{ $$ = t_listst (4, OPEN_STMT, $2, $3, NULL); }
	;


rollback_statement
	: ROLLBACK WORK { $$ = (ST*) t_list (3, CALL_STMT, t_sqlp_box_id_upcase ("__rollback"), t_list (0)); }
	;


with_opt_cursor_options_list
	: /* empty */			{ $$ = NULL; }
	| WITH opt_cursor_options_list	{ $$ = $2; }
	;

selectinto_statement
	: SELECT opt_top selection
		INTO target_commalist table_exp with_opt_cursor_options_list
		{ char *tmp_cr = "temp_cr";
		  ST *qspec = t_listst (5,
		      SELECT_STMT,
		      $2,
		      sqlp_stars (sqlp_wrapper_sqlxml ((ST **) $3), $6->_.table_exp.from),
		      NULL,
		      $6);
		  sqlp_breakup (qspec);
                  qspec = sqlp_add_top_1 (qspec);

		  $$ = t_listst (5,
		    COMPOUND_STMT,
		    t_list (4,
		      t_list (5, CURSOR_DEF, t_box_string (tmp_cr), qspec, _SQL_CURSOR_FORWARD_ONLY, NULL),
		      t_list (4, OPEN_STMT, t_box_string (tmp_cr), $7, NULL),
		      t_list (5, FETCH_STMT, t_box_string (tmp_cr), t_list_to_array ($5), (ptrlong) _SQL_FETCH_NEXT, NULL),
		      t_list (2, CLOSE_STMT, t_box_string (tmp_cr))),
                    t_box_num (global_scs->scs_scn3c.lineno),
                    t_box_num (scn3_get_lineno()),
                    t_box_string (scn3_get_file_name()));
		}
	;




colnum_commalist_2
	: INTNUM { $$ = t_CONS (sqlp_col_num ($1), NULL); }
	| colnum_commalist_2 ',' INTNUM { $$ = t_NCONC ($1, t_CONS (sqlp_col_num ($3), NULL)); }
	;

colnum_commalist
	: INTNUM { $$ = t_listbox (1, sqlp_col_num ($1)); }
	| '(' colnum_commalist_2 ')' { $$ = t_list_to_array_box ($2); }
	;


trans_opt
	: T_MIN '(' scalar_exp ')'  { global_trans->_.trans.min = $3; }
	| T_MAX '(' scalar_exp ')' { global_trans->_.trans.max = $3; }
	| T_DISTINCT { global_trans->_.trans.distinct = 1; }
	| T_EXISTS { global_trans->_.trans.exists = 1; }
	| T_NO_CYCLES { global_trans->_.trans.no_cycles = 1; }
	| T_CYCLES_ONLY { global_trans->_.trans.cycles_only = 1; }
	| T_NO_ORDER { global_trans->_.trans.no_order = 1; }
	| T_SHORTEST_ONLY { global_trans->_.trans.shortest_only = 1; }
	| T_IN colnum_commalist { global_trans->_.trans.in = (ptrlong*) $2; }
 	| T_OUT colnum_commalist { global_trans->_.trans.out = (ptrlong*) $2; }
	| T_END_FLAG  INTNUM { global_trans->_.trans.end_flag = (ptrlong)sqlp_col_num ($2); }
	| T_FINAL_AS NAME { global_trans->_.trans.final_as = $2; }
	| T_DIRECTION INTNUM { global_trans->_.trans.direction = unbox ($2); }
	;


trans_list
	: trans_opt
	| trans_list trans_opt
	;

trans_decl
	: TRANSITIVE { global_trans = (ST *) t_alloc_box (sizeof (sql_tree_t), DV_ARRAY_OF_POINTER); memset (global_trans, 0, box_length ((caddr_t)global_trans));}
	trans_list { $$ = global_trans; global_trans = NULL; }
	;


opt_all_distinct
	: /* empty */	{ $$ = 0; }
	| ALL		{ $$ = 0; }
	| DISTINCT	{ $$ = 1; }
	;

/*
opt_percent
	: { $$ = 0; }
	| PERCENT { $$ = 1; }
	;
*/

opt_ties
	: { $$ = 0; }
	| WITH TIES  { $$ = 1; }
	;


opt_top
	: opt_all_distinct { $$ = (ST*) (ptrlong) $1; }
	| opt_all_distinct TOP INTNUM /*opt_percent*/ opt_ties
{ $$ = (ST*) t_list (7, SELECT_TOP, (ptrlong) $1, $3, t_box_num (0), /*$4, $5*/ 0, (ptrlong) $4, NULL); }
	| opt_all_distinct TOP '(' scalar_exp ')' /*opt_percent*/ opt_ties
{ $$ = (ST*) t_list (7, SELECT_TOP, (ptrlong) $1, $4, t_box_num (0), /*$6, $7*/ 0, (ptrlong) $6, NULL); }
	| opt_all_distinct TOP INTNUM ',' INTNUM /*opt_percent*/ opt_ties
{ $$ = (ST*) t_list (7, SELECT_TOP, (ptrlong) $1, $5, $3, /*$6, $7*/ 0, (ptrlong) $6, NULL); }
	| opt_all_distinct TOP '(' scalar_exp ',' scalar_exp ')' /*opt_percent*/ opt_ties
{ $$ = (ST*) t_list (7, SELECT_TOP, (ptrlong) $1, $6, $4, /*$8, $9*/ 0, (ptrlong) $8, NULL); }
	| trans_decl { $$ = t_listst (7, SELECT_TOP, NULL, NULL, NULL, NULL, NULL, $1);}
	| opt_all_distinct TOP INTNUM ',' '-' INTNUM opt_ties
		{ $$ = (ST*) t_list (7, SELECT_TOP, (ptrlong) $1, t_box_num_and_zero (-1 * unbox($6)), $3, /*$6, $7*/ 0, (ptrlong) $7, NULL); }
	;


update_statement_positioned
	: UPDATE table SET assignment_commalist WHERE CURRENT OF cursor opt_sql_opt
		{ ST ** asg = (ST **) t_list_to_array ($4);
		  ST ** cols = asg_col_list (asg);
		  ST ** vals = asg_val_list (asg);
		  $$ = t_listst (6, UPDATE_POS, $2, cols, vals, $8, $9); }
	;

assignment_commalist
	: /* empty */		{ $$ = NULL; }
	| assignment		{ $$ = t_CONS ($1, NULL); }
	| assignment_commalist ',' assignment
				{ $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

assignment
	: column COMPARISON scalar_exp	{ $$ = t_listbox (2, $1, sqlp_wrapper_sqlxml_assign((ST*)$3)); }
	;

update_statement_searched
	: UPDATE table SET assignment_commalist opt_where_clause opt_sql_opt
		{
		  ST **asg = (ST **) t_list_to_array ($4);
		  ST **cols = asg_col_list (asg);
		  ST **vals = asg_val_list (asg);
		  ST *table_exp = sqlp_infoschema_redirect (t_listst (9, TABLE_EXP,
		      t_list (1, t_box_copy_tree ($2)), $5, NULL, NULL, NULL, NULL, $6, NULL));

		  $$ = t_listst (5, UPDATE_SRC, $2, cols, vals, table_exp);
		}
	;

target_commalist
	: target			{ $$ = t_CONS ($1, NULL); }
	| target_commalist ',' target	{ $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

/* variable in procedure */
target
	: column_ref
	| member_observer
	| lvalue_array_ref
	;

opt_where_clause
	: /* empty */	{ $$ = NULL; }
	| where_clause
	;

/* query expressions */

opt_best
	: { $$ = 0; }
	| BEST { $$ = 1; }
	;

sqlonly_query_exp
	: sqlonly_query_term
	| non_final_union_exp opt_best UNION opt_corresponding query_term
		{ $$ = t_listst (5, UNION_ST, $1, $5, $4, sqlp_bunion_flag ($1, $5, $2)); }
	| non_final_union_exp opt_best UNION ALL opt_corresponding query_term
		{ $$ = t_listst (5, UNION_ALL_ST, $1, $6, $5, sqlp_bunion_flag ($1, $6, $2)); }
	| non_final_union_exp INTERSECT opt_corresponding query_term
		{ $$ = t_listst (4, INTERSECT_ST, $1, $4, $3); }
	| non_final_union_exp INTERSECT ALL opt_corresponding query_term
		{ $$ = t_listst (4, INTERSECT_ALL_ST, $1, $5, $4); }
	| non_final_union_exp EXCEPT opt_corresponding query_term
		{ $$ = t_listst (4, EXCEPT_ST, $1, $4, $3); }
	| non_final_union_exp EXCEPT ALL opt_corresponding query_term
		{ $$ = t_listst (4, EXCEPT_ALL_ST, $1, $5, $4); }
	;

query_exp
	: sqlonly_query_exp
        | sparqlonly_query_term
	;

query_or_sparql_exp
	: sqlonly_query_exp
	| SPARQL_L sqlonly_query_exp	{ $$ = $2; }
	;

non_final_union_exp
	: non_final_query_term
	| non_final_union_exp opt_best UNION opt_corresponding non_final_query_term
		{ $$ = t_listst (5, UNION_ST, $1, $5, $4, sqlp_bunion_flag ($1, $5, $2)); }
	| non_final_union_exp opt_best UNION ALL opt_corresponding non_final_query_term
		{ $$ = t_listst (5, UNION_ALL_ST, $1, $6, $5, sqlp_bunion_flag ($1, $6, $2)); }
	| non_final_union_exp INTERSECT opt_corresponding non_final_query_term
		{ $$ = t_listst (4, INTERSECT_ST, $1, $4, $3); }
	| non_final_union_exp INTERSECT ALL opt_corresponding non_final_query_term
		{ $$ = t_listst (4, INTERSECT_ALL_ST, $1, $5, $4); }
	| non_final_union_exp EXCEPT opt_corresponding non_final_query_term
		{ $$ = t_listst (4, EXCEPT_ST, $1, $4, $3); }
	| non_final_union_exp EXCEPT ALL opt_corresponding non_final_query_term
		{ $$ = t_listst (4, EXCEPT_ALL_ST, $1, $5, $4); }
	;

non_final_query_term
	: non_final_query_spec
	| XPATH STRING { $$ = sqlp_embedded_xpath ($2); }
	;

sqlonly_query_term
	: query_opt_from_spec
	| '(' query_or_sparql_exp ')' opt_order_by_clause	{ $$ = sqlp_inline_order_by ($2, (ST **) $4); }
	| XPATH STRING { $$ = sqlp_embedded_xpath ($2); }
	;

sparqlonly_query_term
	: '(' SPARQL_L sqlonly_query_exp ')' opt_order_by_clause	{ $$ = sqlp_inline_order_by ($3, (ST **) $5); }
	;

query_term
	: sqlonly_query_term	{ $$ = $1; }
	| sparqlonly_query_term	{ $$ = $1; }
	;

opt_corresponding
	: /* empty */	{ $$ = NULL; }
	| CORRESPONDING BY '(' column_commalist ')'
		{ $$ = (ST*) t_list_to_array ($4); }
	;

non_final_query_spec
	: SELECT opt_top selection non_final_table_exp
		{ $$ = t_listst (5, SELECT_STMT, $2,
		      sqlp_stars (sqlp_wrapper_sqlxml ((ST **) $3), $4->_.table_exp.from) , NULL, $4);
		  sqlp_breakup ($$); }

	;

query_opt_from_spec
	: SELECT opt_top selection table_exp_opt	{
		  if (NULL == $4)
		    $$ = t_listst (5, SELECT_STMT, NULL,
		      sqlp_stars (sqlp_wrapper_sqlxml ((ST **) $3), NULL) , NULL, NULL);
		  else
		    $$ = t_listst (5, SELECT_STMT, $2,
		      sqlp_stars (sqlp_wrapper_sqlxml ((ST **) $3), $4->_.table_exp.from) , NULL, $4);
		  sqlp_breakup ($$); }
	;


query_spec
	: SELECT opt_top selection table_exp
		{ $$ = t_listst (5, SELECT_STMT, $2,
		      sqlp_stars (sqlp_wrapper_sqlxml ((ST **) $3), $4->_.table_exp.from) , NULL, $4);
		  sqlp_breakup ($$); }
	;

/*query_no_from_spec
	: SELECT opt_top selection
		{
		  $$ = t_listst (5, SELECT_STMT, NULL,
		      sqlp_stars (sqlp_wrapper_sqlxml ((ST **) $3), NULL) , NULL, NULL);
		  sqlp_breakup ($$); }
	;
*/


breakup_term
	: '(' select_scalar_exp_commalist  ')' { $$ = t_NCONC ($2, t_CONS (t_list (5, BOP_AS, (ptrlong) 1, NULL, t_box_string ("__brkup_cond"), NULL), NULL)); }
	| '(' select_scalar_exp_commalist WHERE search_condition ')' {
	  ST * cond = (ST*) t_list (5, BOP_AS, t_list (2, SEARCHED_CASE, t_list (4, $4, (caddr_t)1,  t_list (2, QUOTE, NULL), 0)), NULL, t_box_string ("__brkup_cond"), NULL);
	  $$ = t_NCONC ($2, t_CONS (cond, NULL)); }
	;

breakup_list
	: breakup_term { $$ = t_CONS (t_list_to_array ($1), NULL); }
	| breakup_list breakup_term { $$ = t_NCONC ($1, t_CONS (t_list_to_array ($2), NULL)); }
	;

selection
	: select_scalar_exp_commalist	{ $$ = (ST *) t_list_to_array ($1); }
	| BREAKUP breakup_list { $$ = (ST *) t_list_to_array (t_CONS (t_list (1, SELECT_BREAKUP), $2)); }
	;

non_final_table_exp
	: from_clause opt_where_clause opt_group_by_clause opt_having_clause
		{
			ST ** group_by = 0;
			if ($3)
			  group_by =  ((ST***)$3)[0];
			$$ = sqlp_infoschema_redirect (t_listst (9,
				TABLE_EXP, $1, $2, group_by, $4, NULL, NULL, NULL, $3));
		}
	;

table_exp_opt
	: /* empty */ { $$ = NULL; }
	| table_exp
	;

table_exp
	: from_clause opt_where_clause opt_group_by_clause opt_having_clause
		opt_order_by_clause opt_lock_mode opt_sql_opt
		{
			ST ** group_by = 0;
			if ($3)
			  group_by =  ((ST***)$3)[0];
			$$ = sqlp_infoschema_redirect (t_listst (9,
				TABLE_EXP, $1, $2, group_by, $4, $5, (ptrlong) $6, $7, $3));
		}
	;

from_clause
	: FROM table_ref_commalist	{ $$ = (ST *) t_list_to_array ($2); }
	;

table_ref_commalist
	: table_ref		{ $$ = t_CONS ($1, NULL); }
	| table_ref_commalist ',' table_ref
				{ $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;


proc_col_list
	: column_def { $$ = $1; }
	| proc_col_list ',' column_def { $$ =t_NCONC ($1, $3); }
	;


opt_proc_col_list
/* : { $$ = NULL; } */
	: '(' proc_col_list ')' { $$ = (ST*) t_list_to_array ($2); }
;


column_commalist_or_empty
	: { $$ = (ST*) t_list (0); }
	| column_commalist { $$ = (ST *) t_list_to_array ($1); }
	;

table_ref
	: table
		{ $$ = t_listbox (3, TABLE_REF,$1, (caddr_t) NULL); }
	| '(' query_or_sparql_exp ')' identifier
		{
		  $$ = t_listbox (3, DERIVED_TABLE, sqlp_view_def (NULL, $2, 0), $4);
		}
	| '(' query_or_sparql_exp ')' AS identifier
		{
		  $$ = t_listbox (3, DERIVED_TABLE, sqlp_view_def (NULL, $2, 0), $5);
		}
	| joined_table
		{ $$ = t_listbox (3, TABLE_REF,$1, (caddr_t) NULL); }
        | q_table_name '(' column_commalist_or_empty ')' opt_proc_col_list identifier opt_table_opt
		{
		  $$ = t_listbox (3, DERIVED_TABLE, t_list (5, PROC_TABLE, $1, $3, $5, $7), $6);
		}
	;

table_ref_nj
	: table		{ $$ = t_listbox (3, TABLE_REF,$1, (caddr_t) NULL); }
	| subquery identifier
                {
		  $$ = t_listbox (3, DERIVED_TABLE, sqlp_view_def (NULL, $1, 0), (caddr_t) $2);
		}
	| subquery AS identifier
		{
		  $$ = t_listbox (3, DERIVED_TABLE, sqlp_view_def (NULL, $1, 0), (caddr_t) $3);
		}
	| '(' joined_table ')' { $$ = (caddr_t) $2; }
	;

jtype
	: /* empty */		{ $$ = J_INNER; }
	| LEFT opt_outer	{ $$ = OJ_LEFT; }
	| RIGHT opt_outer	{ $$ = OJ_RIGHT; }
/*	| NAME opt_outer 	{ $$ = OJ_LEFT; }*/
	| FULL opt_outer	{ $$ = OJ_FULL; }
	| INNER			{ $$ = J_INNER; }
	| CROSS			{ $$ = J_CROSS; }
	;

opt_outer
	: /* empty */
	| OUTER
	;

join
	: NATURAL jtype
		{ $$.type = $2;
		  $$.natural = 1;
		}
	| jtype
		{ $$.type = $1;
		  $$.natural = 0;
		}
	;

joined_table
	: joined_table_1			{ $$ = $1; }
	| BEGIN_OJ_X joined_table_1 ENDX	{ $$ = $2; }
	| '(' joined_table_1 ')'		{ $$ = $2; }
	;

joined_table_1
	: table_ref join JOIN table_ref_nj join_condition
		{
		  $$ = t_listst (6, JOINED_TABLE, $2.natural, $2.type,
			$1, $4, $5);
		}
	;

join_condition
	:  /* empty */			{ $$ = NULL; }
	| ON search_condition		{ $$ = $2; }
	| USING '(' column_commalist ')'
		{ $$ = (ST*) t_list (2, JC_USING, t_list_to_array ($3)); }
	;

where_clause
	: WHERE search_condition	{ $$ = $2; }
	;

grouping_set
	: '(' ordering_spec_commalist ')' { $$ = (caddr_t) t_list_to_array ($2); }
	| ORDER BY opt_top '(' ordering_spec_commalist ')'
		{
			caddr_t oby = (caddr_t) $3;
			ST *o_spec = (ST *) ($5)->data;
			if (!oby) oby = (caddr_t) (ptrlong) 1;
		        o_spec->_.o_spec.gsopt = (ST *) oby;
			$$ = (caddr_t) t_list_to_array ($5);
		}
	| '(' ')' { $$ = (caddr_t) t_list (0); }
	;

grouping_set_list
	: grouping_set { $$ = t_CONS ($1, NULL); }
	| grouping_set_list ',' grouping_set { $$ = t_NCONC ($1, t_CONS ($3, NULL));  }
	;

opt_group_by_clause
	: /* empty */				{ $$ = NULL; }
	| GROUP BY ordering_spec_commalist
		{
			$$ = (ST*) t_list_to_array(t_CONS (t_list_to_array ($3), NULL));
		}
	| GROUP BY GROUPING_L SETS '(' grouping_set_list ')'
		{
			$$ = (ST *) t_list_to_array ($6);
 		}
	| GROUP BY ROLLUP '(' ordering_spec_commalist ')'
		{
			dk_set_t group_by_full = 0;
			dk_set_t first_group_by_key = (dk_set_t)$5;
			while (first_group_by_key)
			{
			  group_by_full = t_NCONC (group_by_full, t_CONS (t_list_to_array (first_group_by_key), NULL));
			  first_group_by_key = first_group_by_key->next;
			}
			group_by_full = t_NCONC (group_by_full, t_CONS (t_list_to_array (NULL), NULL));
			$$ = (ST*) t_list_to_array (group_by_full);
		}
	| GROUP BY CUBE '(' ordering_spec_commalist ')'
		{
		  ST ** etalon = (ST**) t_list_to_array ($5);
		  dk_set_t group_by_full = 0;
		  int inx;
		  for (inx = 0; inx <= BOX_ELEMENTS_INT (etalon); inx++)
		    {
		      subseq_t * ss = ss_iter_init ((caddr_t*) etalon, BOX_ELEMENTS (etalon) - inx);
		      for (;ss_iter_next(ss);)
		        {
		          dk_set_t group_by_keys = 0;
		          int inx2;
		          DO_BOX (ST*, st2, inx2, ss->ss_state)
		            {
		              group_by_keys = t_NCONC (group_by_keys, t_CONS (st2, NULL));
		            }
		          END_DO_BOX;
		          group_by_full = t_NCONC (group_by_full,
					t_CONS(t_list_to_array (group_by_keys), NULL));
				}
			  ss_iter_free (ss);
			}
		  $$ = (ST*) t_list_to_array (group_by_full);
		}
	;

/* pmn
column_ref_commalist
	: column_ref  {$$ = t_CONS ($1, NULL); }
	| column_ref_commalist ',' column_ref
		{ $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;
*/

opt_having_clause
	: /* empty */			{ $$ = NULL; }
	| HAVING search_condition	{ $$ = $2; }
	;

opt_lock_mode
	: /* empty */			{ $$ = 0; }
	| FOR UPDATE			{ $$ = PL_EXCLUSIVE; }
	| FOR XML NAME { $$ = sqlp_xml_select_flags ($3, NULL); }
	| FOR XML NAME NAME { $$ = sqlp_xml_select_flags ($3, $4); }
	;

/* search conditions */
search_condition
/*	:  empty			{ $$ = NULL; } */
	: search_condition OR search_condition
					{ BIN_OP ($$, BOP_OR, $1, $3) }
	| search_condition AND search_condition
					{ BIN_OP ($$, BOP_AND, $1, $3) }
	| NOT search_condition
					{ UN_OP ($$, BOP_NOT, $2) }
	| '(' search_condition ')'	{ $$ = $2; }
	| predicate
	;

predicate
	: comparison_predicate
	| between_predicate
	| like_predicate
	| test_for_null
	| in_predicate
	| all_or_any_predicate
	| existence_test
	| scalar_exp_predicate
	;

scalar_exp_predicate
	: scalar_exp
		{
		  ST *eq_op;
		  BIN_OP (eq_op, BOP_EQ, (ST *) t_box_num_and_zero (0), $1);
		  NEGATE ($$, eq_op);
                }
	;

comparison_predicate
	: scalar_exp COMPARISON scalar_exp
		{ BIN_OP ($$, $2, $1, $3);
		  /*IvAn*/ if ($$->type == BOP_NEQ)
		    {
		      ST *cmp_tree = $$;
		      $$->type = BOP_EQ;
		      NEGATE ($$, cmp_tree);
		    }/* */
		  }
/*	| scalar_exp COMPARISON subquery
		{
		  if ($2 == BOP_NEQ)

		      ST *tmp = SUBQ_PRED (ALL_PRED, $1, $3, BOP_EQ, NULL);
		      NEGATE ($$, tmp);
		    }
		  else
		    $$ = SUBQ_PRED (ONE_PRED, $1, $3, $2, NULL);
		}
*/
	;

between_predicate
	: scalar_exp NOT BETWEEN scalar_exp AND scalar_exp
		{ ST *copy = (ST *) t_box_copy_tree ((caddr_t) $1);
		  ST *low_test;
		  ST *high_test;
		  BIN_OP (low_test, BOP_LT, $1, $4);
		  BIN_OP (high_test, BOP_GT, copy, $6);
		  BIN_OP ($$, BOP_OR, low_test, high_test);
		}
	| scalar_exp BETWEEN scalar_exp AND scalar_exp
		{ ST *copy = (ST *) t_box_copy_tree ((caddr_t) $1);
		  ST *low_test;
		  ST *high_test;
		  BIN_OP (low_test, BOP_GTE, $1, $3);
		  BIN_OP (high_test, BOP_LTE, copy, $5);
		  BIN_OP ($$, BOP_AND, low_test, high_test);
		}
	;

like_predicate
	: scalar_exp NOT LIKE scalar_exp opt_escape
		{ ST* tmp;
		  BIN_OP (tmp, BOP_LIKE, $1, (ST *) $4);
		  tmp->_.bin_exp.more = $5;
		  NEGATE ($$, tmp);
		}
	| scalar_exp LIKE scalar_exp opt_escape
		{
		  BIN_OP ($$, BOP_LIKE, $1, (ST *) $3);
		  $$->_.bin_exp.more = $4;
		}
	;

opt_escape
	: /* empty */			{ $$ = NULL; }
	| ESCAPE atom
	  	{
		  if (!DV_STRINGP ($2) || box_length ($2) != 2)
		    yy_new_error ("Invalid escape character in LIKE", "37000", "SQ136");
		  $$ = $2;
	  	}
	| BEGINX ESCAPE atom ENDX
		{
		  if (!DV_STRINGP ($3) || box_length ($3) != 2)
		    yy_new_error ("Invalid escape character in LIKE", "37000", "SQ136");
		  $$ = $3;
		} /* ODBC/JDBC standard */
	;

test_for_null
	: scalar_exp IS NOT NULLX
		{ ST *tmp;
		  BIN_OP (tmp, BOP_NULL, $1, NULL);
		  NEGATE ($$, tmp);
		}
	| scalar_exp IS NULLX		{ BIN_OP ($$, BOP_NULL, $1, NULL); }
	;

in_predicate
	: scalar_exp NOT IN_L subquery
		{
		  ST *in = NULL;
		  in = SUBQ_PRED (SOME_PRED, $1, sqlp_wpar_nonselect ($4), BOP_EQ, NULL);
		  NEGATE ($$, in);
		}
	| scalar_exp IN_L subquery
		{
		  $$ = SUBQ_PRED (SOME_PRED, $1, sqlp_wpar_nonselect ($3), BOP_EQ, NULL); }
	| scalar_exp NOT IN_L '(' scalar_exp_commalist ')'
 		{ $$ = sqlp_in_exp ($1, $5, 1);
		}
	| scalar_exp IN_L '(' scalar_exp_commalist ')'
 		{ $$ = sqlp_in_exp ($1, $4, 0);
		}
	;

/* pmn
atom_commalist
	: atom				{ $$ = t_CONS ($1, NULL); }
	| atom_commalist ',' atom	{ $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;
*/

all_or_any_predicate
	: scalar_exp COMPARISON any_all_some subquery
		{ $$ = SUBQ_PRED ($3, $1, sqlp_wpar_nonselect ($4), $2, NULL); }
	;

any_all_some
	: ANY	{ $$ = SOME_PRED; }
	| ALL	{ $$ = ALL_PRED; }
	| SOME	{ $$ = SOME_PRED; }
	;

existence_test
	: EXISTS subquery
		{
		  /* exists (select * ..) becomes exists (select 1 ...) */
		  ST * ext_subq = $2;
		  ext_subq->_.select_stmt.selection = (caddr_t*) t_list (1, t_box_num (1));
		  ext_subq->_.select_stmt.top = NULL;
		  $$ = (ST *) SUBQ_PRED (EXISTS_PRED, NULL, ext_subq, NULL, NULL); }
	;

scalar_subquery
	:	subquery  { $$ = (ST *) t_list (2, SCALAR_SUBQ, sqlp_add_top_1 ($1)); }
	;


subquery
	: '(' sqlonly_query_exp ')'	{ $$ = $2; }
	| '(' SPARQL_L sqlonly_query_exp ')'	{ $$ = $3; }
	;

/* scalar expressions */
scalar_exp
	: scalar_exp '-' scalar_exp	{ BIN_OP ($$, BOP_MINUS, $1, $3) }
	| scalar_exp '+' scalar_exp	{ BIN_OP ($$, BOP_PLUS, $1, $3) }
	| scalar_exp '*' scalar_exp	{ BIN_OP ($$, BOP_TIMES, $1, $3) }
	| scalar_exp '/' scalar_exp	{ BIN_OP ($$, BOP_DIV, $1, $3) }
	| '+' scalar_exp %prec UMINUS	{ $$ = $2; }
	| '-' scalar_exp %prec UMINUS	{ if (sqlp_is_num_lit ((caddr_t)($2))) $$ = (ST *) sqlp_minus ((caddr_t)($2));
				          else BIN_OP ($$, BOP_MINUS, (ST*) t_box_num (0), $2) }
	| assignment_statement
	| string_concatenation_operator
	| column_ref			{ $$ = (sql_tree_t *) $1; }
	| scalar_exp_no_col_ref
	| obe_literal
	;

scalar_exp_no_col_ref
	: atom_no_obe				{ $$ = (sql_tree_t *) $1; }
	| aggregate_ref
	| scalar_subquery
	| '(' scalar_exp ')'		{ $$ = $2; }
	| '(' scalar_exp ',' scalar_exp_commalist ')'
		{ dk_set_t exps = t_CONS ($2, $4);
		  $$ = t_listst (2, COMMA_EXP, t_list_to_array (exps));
		}
	| function_call
	| new_invocation
	| cvt_exp
	| cast_exp
	| simple_case
	| searched_case
	| coalesce_exp
	| nullif_exp
	| array_ref
	| static_method_invocation
	| method_invocation
	| member_observer
	;

scalar_exp_no_col_ref_no_mem_obs_chain
	: atom_no_obe				{ $$ = (sql_tree_t *) $1; }
	| aggregate_ref
	| scalar_subquery
	| '(' scalar_exp ')'		{ $$ = $2; }
	| '(' scalar_exp ',' scalar_exp_commalist ')'
		{ dk_set_t exps = t_CONS ($2, $4);
		  $$ = t_listst (2, COMMA_EXP, t_list_to_array (exps));
		}
	| function_call
	| new_invocation
	| cvt_exp
	| cast_exp
	| simple_case
	| searched_case
	| coalesce_exp
	| nullif_exp
	| array_ref
	| static_method_invocation
	| method_invocation
	| member_observer_no_id_chain
	;

cvt_exp
	: CONVERT '(' data_type ',' scalar_exp ')'
		{
		  ST *dtype = (ST *) t_list (2, QUOTE, $3);
		  ST *expn_to_cast = sqlp_wrapper_sqlxml_assign ($5);
		  $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("_cvt"),
		    t_list (2, dtype, expn_to_cast) );
		  if (LITERAL_P (expn_to_cast))
		    $$ = sqlp_patch_call_if_special_or_optimizable ($$);
		}
	;

opt_collate_exp
	: /* empty */		{ $$ = NULL; }
	| COLLATE q_table_name	{ $$ = $2; }
	;

cast_exp
	: CAST '(' scalar_exp AS data_type opt_collate_exp ')'
		{
		  ST *dtype = (ST *) t_list (2, QUOTE, $5);
		  ST *expn_to_cast = sqlp_wrapper_sqlxml_assign ($3);
		  $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("_cvt"),
		    t_list ($6 == NULL ? 2 : 3, dtype, expn_to_cast, $6) );
		  if (LITERAL_P (expn_to_cast))
		    $$ = sqlp_patch_call_if_special_or_optimizable ($$);
		}
	;


/*xml_col_dir
	: NAME { $$ = XR_ELEMENT; }
	;*/

mssql_xml_col
	: MSSQL_XMLCOL_NAME1 MSSQL_XMLCOL_INTNUM MSSQL_XMLCOL_NAMEZ
		{ $$ = (ST*) t_list (5, XML_COL, $1, $2, $3, XML_COL_ATTR); }
	| MSSQL_XMLCOL_NAME1 MSSQL_XMLCOL_INTNUM MSSQL_XMLCOL_NAMEYZ
		{ $$ = (ST*) t_list (5, XML_COL, $1, $2, t_sym_string(""), sqlp_xml_col_directive ($3)); }
	| MSSQL_XMLCOL_NAME1 MSSQL_XMLCOL_INTNUM MSSQL_XMLCOL_NAME MSSQL_XMLCOL_NAMEZ
		{ $$ = (ST*) t_list (5, XML_COL, $1, $2, $3, sqlp_xml_col_directive ($4)); }
	;

as_expression
	: scalar_exp AS identifier data_type
		{ $$ = t_listst (5, BOP_AS, $1, NULL, $3, $4); }
	| scalar_exp AS identifier
		{ $$ = t_listst (5, BOP_AS, $1, NULL, $3, NULL); }
	| scalar_exp identifier
		{ $$ = t_listst (5, BOP_AS, $1, NULL, $2, NULL); }
	| scalar_exp AS mssql_xml_col
		{ $$ = t_listst (6, BOP_AS, $1, NULL, sqlp_xml_col_name ($3), NULL, $3); }
	| scalar_exp AS STRING
		{ $$ = t_listst (5, BOP_AS, $1, NULL, t_sym_string ($3), NULL); }
	| scalar_exp STRING
		{ $$ = t_listst (5, BOP_AS, $1, NULL, t_sym_string ($2), NULL); }
	;

array_ref
	: scalar_exp_no_col_ref array_index_list
		{ $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("aref"),
		    t_list_to_array (t_CONS ($1, $2)) ); }
	| lvalue_array_ref
	;

lvalue_array_ref
	: column_ref array_index_list
		{ $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("aref"),
		    t_list_to_array (t_CONS ($1, $2)) ); }
	;

opt_scalar_exp_commalist
	: /* empty */		{ $$ = NULL; }
	| scalar_exp_commalist
	;

/* The rest of cases added by AK 22-MAR-1997 for ODBC brace-escaped
   function calls like {fn concat('Bar','bar')}
  */
function_name
	: identifier						  { $$ = sqlp_proc_name (NULL, 0, NULL, 0, NULL, $1); }
	| identifier '.' method_identifier			  { $$ = sqlp_proc_name (NULL, 0, $1, box_length ($1), NULL, $3); }
	| identifier '.' identifier '.' method_identifier	  { $$ = sqlp_proc_name ($1, box_length ($1), $3, box_length ($3), NULL, $5); }
	| identifier '.' identifier '.' identifier '.' method_identifier { $$ = sqlp_proc_name ($1, box_length ($1), $3, box_length ($3), $5, $7); }
	| identifier '.'  '.' method_identifier			  { $$ = sqlp_proc_name ($1, box_length ($1), NULL, 0, NULL, $4); }
	| identifier '.'  '.' identifier '.' method_identifier	  { $$ = sqlp_proc_name ($1, box_length ($1), NULL, 0, $4, $6); }
	| LEFT	{ $$ = t_sqlp_box_id_upcase ("left"); }
	| RIGHT	{ $$ = t_sqlp_box_id_upcase ("right"); }
	| LOGX	{ $$ = t_sqlp_box_id_upcase ("log"); }
	;


kwd_commalist
	: identifier KWD_TAG scalar_exp  { $$ = t_CONS (t_list (3, KWD_PARAM, $1, $3), NULL);}
	| kwd_commalist ',' identifier KWD_TAG scalar_exp { $$ = t_NCONC ($1, t_CONS (t_list (3, KWD_PARAM, $3, $5), NULL)); }
	;

/*sqlxml*/
as_commalist
	: as_expression { $$ = t_CONS ($1, NULL); }
	| as_commalist ',' as_expression { $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	| as_commalist ',' scalar_exp { $$ = t_NCONC ($1, t_CONS ($3, NULL));}
	;

opt_arg_commalist
	: /*empty */ { $$ = NULL; }
	| kwd_commalist { $$ = $1; }
	| scalar_exp_commalist { $$ = $1; }
	| scalar_exp_commalist ',' kwd_commalist{ $$ = t_NCONC ($1, $3); }
/*sqlxml*/
	| scalar_exp_commalist ',' as_commalist{ $$ = t_NCONC ($1, $3); }
	| as_commalist { $$ = $1; }
	;

function_call
	: function_name '(' opt_arg_commalist ')'
		{
		  ST **arglist = (ST **)t_list_to_array ($3);
		  ST *fun_ref = sqlp_make_user_aggregate_fun_ref ($1, arglist, 0);
		  if (NULL != fun_ref)
		    $$ = fun_ref;
		  else
		    {
		      $$ = t_listst (3, CALL_STMT, $1, arglist);
		      $$ = sqlp_patch_call_if_special_or_optimizable ($$);
		    }
		}
	| TIMESTAMP_FUNC '(' SQL_TSI ',' scalar_exp ',' scalar_exp ')'
		{
		  $$ = t_listst (3, CALL_STMT,
		      t_sqlp_box_id_upcase ($1 == SQL_FN_TIMESTAMPADD ? "timestampadd" : "timestampdiff"),
		      t_listst (3, t_box_num($3), $5, $7));
		  $$ = sqlp_patch_call_if_special_or_optimizable ($$);
		}
	| EXTRACT '(' NAME FROM scalar_exp ')'
		{
		  $$ = t_listst (3, CALL_STMT,
		      t_sqlp_box_id_upcase ("__extract"),
		      t_listst (2, t_box_string ($3), $5));
		}
	| BEGIN_FN_X identifier '(' opt_scalar_exp_commalist ')' ENDX
		{ $$ = t_listst (3, CALL_STMT, $2, t_list_to_array ($4));
		  $$ = sqlp_patch_call_if_special_or_optimizable ($$);}
	| BEGIN_FN_X LEFT '(' opt_scalar_exp_commalist ')' ENDX
		{ $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("left"), t_list_to_array ($4));
		$$ = sqlp_patch_call_if_special_or_optimizable ($$);}
	| BEGIN_FN_X RIGHT '(' opt_scalar_exp_commalist ')' ENDX
		{ $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("right"), t_list_to_array ($4));
		  $$ = sqlp_patch_call_if_special_or_optimizable ($$);}
	| BEGIN_FN_X LOGX '(' opt_scalar_exp_commalist ')' ENDX
		{ $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("log"), t_list_to_array ($4));
		  $$ = sqlp_patch_call_if_special_or_optimizable ($$);}
	| BEGIN_FN_X identifier '(' scalar_exp IN_L scalar_exp ')' ENDX
		{
		  if (stricmp ($2, "POSITION"))
		    yyerror (scanner,"syntax error");
		  $$ = t_listst (3, CALL_STMT, $2,
		      t_listst (2, $4, $6));
		}
	| BEGIN_CALL_X function_name  '(' opt_scalar_exp_commalist ')' ENDX
		{ $$ = t_listst (3, CALL_STMT, $2, t_list_to_array ($4));
		  $$ = sqlp_patch_call_if_special_or_optimizable ($$);}
	| BEGIN_CALL_X function_name ENDX
		{ $$ = t_listst (3, CALL_STMT, $2, t_list_to_array (NULL)); }
	| BEGIN_FN_X USER '(' opt_scalar_exp_commalist ')' ENDX
		{ $$ = t_listst (3, CALL_STMT,
			t_sqlp_box_id_upcase ("get_user"), t_list_to_array ($4)); }
	| BEGIN_FN_X CHARACTER '(' opt_scalar_exp_commalist ')' ENDX
		{ $$ = t_listst (3, CALL_STMT,
			t_sqlp_box_id_upcase ("chr"), t_list_to_array ($4));
		  $$ = sqlp_patch_call_if_special_or_optimizable ($$);}
	| BEGIN_FN_X TIMESTAMP_FUNC '(' SQL_TSI ',' scalar_exp ',' scalar_exp ')' ENDX
		{
		  $$ = t_listst (3, CALL_STMT,
		      t_sqlp_box_id_upcase ($2 == SQL_FN_TIMESTAMPADD ? "timestampadd" : "timestampdiff"),
		      t_listst (3, t_box_num($4), $6, $8));
		  $$ = sqlp_patch_call_if_special_or_optimizable ($$);
		}
	| BEGIN_FN_X CONVERT '(' scalar_exp ',' NAME ')' ENDX
		{
		  caddr_t data_type = sqlc_convert_odbc_to_sql_type ($6);
		  if (!data_type)
		    yyerror (scanner,"Not valid data type in CONVERT ODBC Scalar function");
		  $$ = t_listst (3, CALL_STMT,
		      t_sqlp_box_id_upcase ("_cvt"),
		      t_listst (2, t_list (2, QUOTE, data_type), $4));
		  $$ = sqlp_patch_call_if_special_or_optimizable ($$);
		}
	| BEGIN_FN_X EXTRACT '(' NAME FROM scalar_exp ')' ENDX
		{
		  $$ = t_listst (3, CALL_STMT,
		      t_sqlp_box_id_upcase ("__extract"),
		      t_listst (2, t_box_string ($4), $6));
		  $$ = sqlp_patch_call_if_special_or_optimizable ($$);
		}
	| CALL '(' scalar_exp ')' '(' opt_arg_commalist ')'
		{ $$ = t_listst (3, CALL_STMT, t_list (1, $3),
			t_list_to_array ($6)); }
	| CURRENT_DATE opt_lpar_rpar
		{
		  $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("curdate"), t_list (0));
		}
	| CURRENT_TIME opt_lpar_rpar
		{
		  $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("curtime"), t_list (0));
		}
	| CURRENT_TIME '(' scalar_exp ')'
		{
		  $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("curtime"), t_list (1, $3));
		}
	| CURRENT_TIMESTAMP opt_lpar_rpar
		{
		  $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("curdatetime"), t_list (0));
		}
	| CURRENT_TIMESTAMP '(' scalar_exp ')'
		{
		  $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("curdatetime"), t_list (1, $3));
		}
	| GROUPING_L '(' column_ref ')'
		{
		  caddr_t bit = t_box_num (0);
		  caddr_t bit_index = t_box_num (0);
		  $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("__grouping"), t_list (3, $3, bit, bit_index));
		}
	;

opt_lpar_rpar
	: /* empty */
	| '(' ')'
	;

/* the call return statement {?=call x [()]} */
sql
	: BEGIN_EQCALL_X q_table_name ENDX
		{ $$ = t_listst (4, CALL_STMT, $2, t_list_to_array (NULL), $1); }
	| BEGIN_EQCALL_X q_table_name '(' opt_scalar_exp_commalist ')' ENDX
		{ $$ = t_listst (4, CALL_STMT, $2, t_list_to_array ($4), $1); }
	;

/*** pmn
proc_call_name
	: identifier						{ $$ = sqlp_proc_name (NULL, NULL, $1); }
	| identifier '.' '.' method_identifier			{ $$ = sqlp_proc_name ($1, NULL, $4); }
	| identifier '.' method_identifier			{ $$ = sqlp_proc_name (NULL, $1, $3); }
	| identifier '.' identifier '.' method_identifier	{ $$ = sqlp_proc_name ($1, $3, $5); }
	;
*/

/* ODBC Brace-Escaped Literal, for date & time(stamp) values
    given in ODBC style, e.g. {d '2038-01-18'}
    Actually we should have literal (or even string) in place of
    atom, but we are liberal here, allowing funny constructs
    like {ts ?}
  */
obe_literal
	: BEGINX identifier atom ENDX
		{ $$ = t_listst (3, CALL_STMT,
			t_sqlp_box_id_upcase (obe_keyword_to_bif_fun_name ($2)),
			t_list (1, $3));
		  $$ = sqlp_patch_call_if_special_or_optimizable ($$);
		}
	| BEGIN_U_X STRING ENDX
		{ $$ = (ST*) t_list (3, CALL_STMT, t_sqlp_box_id_upcase ("get_keyword"),
				   t_list (2, $2, t_list (3, COL_DOTTED, NULL, t_sqlp_box_id_upcase ("params")))); }
	;

scalar_exp_commalist
	: scalar_exp				{ $$ = t_CONS ($1, NULL); }
	| scalar_exp_commalist ',' scalar_exp	{ t_NCONC ($1, t_CONS ($3, NULL)); }
	;

select_scalar_exp_commalist
	: scalar_exp				{ $$ = t_CONS ($1, NULL); }
	| as_expression				{ $$ = t_CONS ($1, NULL); }
	| select_scalar_exp_commalist ',' scalar_exp	{ t_NCONC ($1, t_CONS ($3, NULL)); }
	| select_scalar_exp_commalist ',' as_expression { t_NCONC ($1, t_CONS ($3, NULL)); }
	;

atom_no_obe
	: parameter_ref
	| literal
	| USER		{ $$ = t_listbox (3, CALL_STMT,
				t_sqlp_box_id_upcase ("get_user"), t_list (0)); }
	;

atom
	: atom_no_obe
	| obe_literal	{ $$ = (caddr_t) $1; }
	;

simple_case
	: CASE scalar_exp simple_when_list ENDX
		{ $$ = (ST*) t_list (2, SIMPLE_CASE,
			t_list_to_array (t_CONS ($2, $3))); }
	;

searched_case
	: CASE searched_when_list ENDX
		{ $$ = (ST*) t_list (2, SEARCHED_CASE, t_list_to_array ($2)); }
	;

searched_when_list
	: searched_when { $$ =  $1; }
	| searched_when_list searched_when { $$ = t_NCONC ($1, $2); }
	;

simple_when_list
	: simple_when  { $$ = $1; }
	| simple_when_list simple_when { $$ = t_NCONC ($1, $2); }
	;

simple_when
	: WHEN scalar_exp THEN scalar_exp
		{ $$ = t_CONS ($2, t_CONS ($4, NULL)); }
	| ELSE scalar_exp
		{ $$ = t_CONS ( t_list (2, QUOTE, NULL), t_CONS ($2, NULL)); }
	;

searched_when
	: WHEN search_condition THEN scalar_exp
		{ $$ = t_CONS ($2, t_CONS ($4, NULL)); }
	| ELSE scalar_exp
		{ $$ = t_CONS ( t_list (2, QUOTE, NULL), t_CONS ($2, NULL)); }
	;

coalesce_exp
	: COALESCE '(' scalar_exp_commalist ')'
		{ $$ = (ST*) t_list (2, COALESCE_EXP, t_list_to_array ($3)); }
	;

nullif_exp
	: NULLIF '(' scalar_exp ',' scalar_exp ')'
		  { $$ = (ST*) t_list (2, SIMPLE_CASE,
		  	t_list (5, $3, $5, t_alloc_box (0, DV_DB_NULL),
			t_list (2, QUOTE, NULL), t_box_copy_tree ((caddr_t) $3))); }
	;

parameter_ref
	: parameter
	| parameter parameter
		{ $$ = t_listbox (3, PARAM_WITH_IND, $1, $2); }
	| parameter INDICATOR parameter
		{ $$ = t_listbox (3, PARAM_WITH_IND, $1, $3); }
	;

aggregate_ref
	: AGGREGATE function_name '(' opt_arg_commalist ')'
		{
		  ST **arglist = (ST **)(t_list_to_array ($4));
		  $$ = sqlp_make_user_aggregate_fun_ref ($2, arglist, 1);
		}
/*	| AMMSC '(' '*' ')'			{ FN_REF ($$, $1, 0, 0); }*/
| AMMSC '(' DISTINCT scalar_exp opt_sql_opt ')'	{ FN_REF ($$, $1, 1, $4); $$->_.fn_ref.fn_arglist = $5; }
	| AMMSC '(' ALL scalar_exp ')'		{ FN_REF ($$, $1, 0, $4) }
	| AMMSC '(' scalar_exp ')'		{ FN_REF ($$, $1, 0, $3) }
	;

literal
	: STRING
	| WSTRING
	| UNAME_LITERAL
	| INTNUM
	| APPROXNUM
	| BINARYNUM
	| IRI_LIT
	| NULLX		{ $$ = (caddr_t) t_NULLCONST; }
	| __TAG_L OF tail_of_tag_of { $$ = $3; }
	;

signed_literal
	: STRING
	| WSTRING
	| UNAME_LITERAL
	| INTNUM
	| '-' INTNUM %prec UMINUS { $$ = t_box_num_and_zero (-1 * unbox ($2)); }
	| '+' INTNUM %prec UMINUS { $$ = $2; }
	| APPROXNUM
	| '-' APPROXNUM %prec UMINUS
		{
		  switch (DV_TYPE_OF ($2))
		    {
		      case DV_NUMERIC:
			    {
			      numeric_t y = t_numeric_allocate ();
			      numeric_negate (y, (numeric_t) $2);
			      $$ = (caddr_t) y;
			      break;
			    }
		      case DV_DOUBLE_FLOAT:  $$ = t_box_double (-1.0 * unbox_double ($2)); break;
		    }
		}
	| '+' APPROXNUM %prec UMINUS { $$ = $2; }
	| BINARYNUM
	| NULLX		{ $$ = (caddr_t) t_NULLCONST; }
	| __TAG_L OF tail_of_tag_of { $$ = $3; }
	;

tail_of_tag_of
	: data_type { $$ = ((caddr_t *)$1)[0]; }
	| data_type HANDLE_L
		{
		  $$ = ((caddr_t *)$1)[0];
		  if (!IS_BLOB_DTP($$))
		    yyerror (scanner, "__TAG OF ... HANDLE is valid only for LONG datatypes");
		  $$ = DV_BLOB_HANDLE_DTP_FOR_BLOB_DTP($$);
		}
	| DICTIONARY_L REFERENCE_L { $$ = (caddr_t) DV_DICT_ITERATOR; }
	| STREAM_L { $$ = (caddr_t) DV_STRING_SESSION; }
	| XML { $$ = (caddr_t) DV_XML_ENTITY; }
	| RDF_BOX_L { $$ = (caddr_t) DV_RDF; }
	| VECTOR_L { $$ = (caddr_t) DV_ARRAY_OF_POINTER; }
	| UNAME_L { $$ = (caddr_t) DV_UNAME; }
	;

/* miscellaneous */

q_table_name
	: identifier			{ $$ = sqlp_table_name (NULL, 0, NULL, 0, $1, 1); }
	| identifier '.' identifier		{ $$ = sqlp_table_name (NULL, 0, $1, box_length ($1), $3, 1); }
	| identifier '.' identifier '.' identifier { $$ = sqlp_table_name ($1, box_length ($1), $3, box_length ($3), $5, 1); }
	| identifier '.'  '.' identifier	{ $$ = sqlp_table_name ($1, box_length ($1), NULL, 0, $4, 1); }
	;

attach_q_table_name
	: identifier			{ $$ = sqlp_table_name (NULL, 0, NULL, 0, $1, 0); }
	| identifier '.' identifier		{ $$ = sqlp_table_name (NULL, 0, $1, box_length ($1), $3, 0); }
	| identifier '.' identifier '.' identifier { $$ = sqlp_table_name ($1, box_length ($1), $3, box_length ($3), $5, 0); }
	| identifier '.'  '.' identifier	{ $$ = sqlp_table_name ($1, box_length ($1), NULL, 0, $4, 0); }
	;

new_proc_or_bif_name
	: identifier			 { $$ = (bif_find($1) ? $1 : sqlp_new_table_name (NULL, 0, NULL, 0, $1)); }
	| identifier '.' identifier		 { $$ = sqlp_new_table_name (NULL, 0, $1, box_length ($1), $3); }
	| identifier '.' identifier '.' identifier { $$ = sqlp_new_table_name ($1, box_length ($1), $3, box_length ($3), $5); }
	| identifier '.'  '.' identifier	 { $$ = sqlp_new_table_name ($1, box_length ($1), NULL, 0, $4); }
	;

new_table_name
	: identifier			 { $$ = sqlp_new_table_name (NULL, 0, NULL, 0, $1); }
	| identifier '.' identifier		 { $$ = sqlp_new_table_name (NULL, 0, $1, box_length ($1), $3); }
	| identifier '.' identifier '.' identifier { $$ = sqlp_new_table_name ($1, box_length ($1), $3, box_length ($3), $5); }
	| identifier '.'  '.' identifier	 { $$ = sqlp_new_table_name ($1, box_length ($1), NULL, 0, $4); }
	;

table
	: q_table_name opt_table_opt
		{ $$ = t_listbox (6, TABLE_DOTTED, $1, NULL, sqlp_view_u_id (), sqlp_view_g_id (), $2); }
	| q_table_name AS identifier opt_table_opt
		{
		  $$ = t_listbox (6, TABLE_DOTTED, $1, $3, sqlp_view_u_id (), sqlp_view_g_id (), $4);
		}
	| q_table_name identifier opt_table_opt
		{
		  $$ = t_listbox (6, TABLE_DOTTED, $1, $2, sqlp_view_u_id (), sqlp_view_g_id (), $3);
		}
	;


column_ref
	: identifier
		{ $$ = t_listst (3, COL_DOTTED, NULL, $1);
		}
	| identifier '.' identifier
		{ $$ = t_listst (3, COL_DOTTED, c_pref (NULL, 0, NULL, 0, $1), $3);
		}
	| identifier '.' identifier '.' identifier
		{ $$ = t_listst (3, COL_DOTTED, c_pref (NULL, 0, $1, box_length ($1), $3), $5);
		}
	| identifier '.' identifier '.' identifier '.' identifier
		{ $$ = t_listst (3, COL_DOTTED, c_pref ($1, box_length ($1), $3, box_length ($3), $5), $7);
		}
	| identifier '.' '.' identifier '.' identifier
		{ $$ = t_listst (3, COL_DOTTED, c_pref ($1, box_length ($1), NULL, 0, $4), $6);
		}
	| '*'
		{ $$ = t_listst (3, COL_DOTTED, (long) 0, STAR);
		}
	| identifier '.' '*'
		{ $$ = t_listst (3, COL_DOTTED, c_pref (NULL, 0, NULL, 0, $1), STAR);
		}
	| identifier '.' identifier '.' '*'
		{ $$ = t_listst (3, COL_DOTTED, c_pref (NULL, 0, $1, box_length ($1), $3), STAR);
		}
	| identifier '.' identifier '.' identifier '.' '*'
		{ $$ = t_listst (3, COL_DOTTED, c_pref ($1, box_length ($1), $3, box_length ($3), $5), STAR);
		}
	| identifier '.' '.' identifier '.' '*'
		{ $$ = t_listst (3, COL_DOTTED, c_pref ($1, box_length ($1), NULL, 0, $4), STAR);
		}
	;

/* data types */
base_data_type
	: NUMERIC
		{ $$ = sqlp_numeric (0, 0);
		}
	| NUMERIC '(' INTNUM ')'
		{ $$ = sqlp_numeric ($3, 0);
		}
	| NUMERIC '(' INTNUM ',' INTNUM ')'
		{ $$ = sqlp_numeric ($3, $5);
		}
	| DECIMAL_L
		{ $$ = sqlp_numeric (0, 0);
		}
	| DECIMAL_L '(' INTNUM ')'
		{ $$ = sqlp_numeric ($3, 0);
		}
	| DECIMAL_L '(' INTNUM ',' INTNUM ')'
		{ $$ = sqlp_numeric ($3, $5);
		}
	| INTEGER
		{ $$ = t_listst (2, (long) DV_LONG_INT, (long) 0);
		}
	| SMALLINT
		{ $$ = t_listst (2, (long) DV_SHORT_INT, (long) 0);
		}
	| BIGINT
		{ $$ = t_listst (3, (ptrlong) DV_INT64, t_box_num (19), t_box_num (0));
		}
	| FLOAT_L
		{ $$ = t_listst (2, (long) DV_DOUBLE_FLOAT, (long) 0);
		}
	| FLOAT_L '(' INTNUM ')'
		{ $$ = t_listst (2, (long) DV_DOUBLE_FLOAT, (long) 0);
		}
	| REAL
		{ $$ = t_listst (2, (long) DV_SINGLE_FLOAT, (long) 0);
		}
	| DOUBLE_L PRECISION
		{ $$ = t_listst (2, (long) DV_DOUBLE_FLOAT, (long) 0);
		}
	| LONG_L VARCHAR
		{ $$ = t_listst (2, (long) DV_BLOB, t_box_num (0x7fffffff));
		}
	| LONG_L VARBINARY
		{ $$ = t_listst (2, (long) DV_BLOB_BIN, t_box_num (0x7fffffff));
		}
	| VARBINARY
		{ $$ = t_listst (2, (long) DV_BIN, (long) 0);
		}
	| VARBINARY '(' INTNUM ')'
		{ $$ = t_listst (2, (long) DV_BIN, $3);
		}
	| BINARY '(' INTNUM ')'
		{ $$ = t_listst (2, (long) DV_BIN, $3);
		}
	| TIMESTAMP
		{ $$ = t_listst (3, (long) DV_TIMESTAMP, (long) 10, (long) 6);
		}
	| DATETIME
		{ $$ = t_listst (2, (long) DV_DATETIME, (long) 19);
		}
	| TIME
		{ $$ = t_listst (2, (long) DV_TIME, (long) 8);
		}
	| DATE_L
		{ $$ = t_listst (2, (long) DV_DATE, (long) 10);
		}
	| NCHAR
		{ $$ = t_listst (2, (long) DV_WIDE, (long) 1);
		}
	| NCHAR '(' INTNUM ')'
		{ $$ = t_listst (2, (long) DV_WIDE, $3);
		}
	| NVARCHAR
		{ $$ = t_listst (2, (long) DV_WIDE, (long) 0);
		}
	| NVARCHAR '(' INTNUM ')'
		{ $$ = t_listst (2, (long) DV_WIDE, $3);
		}
	| LONG_L NVARCHAR
		{ $$ = t_listst (2, (long) DV_BLOB_WIDE, t_box_num (0x7fffffff));
		}
	| ANY
		{ $$ = t_listst (2, (long) DV_ANY, (long) 0); }
	| ANY '(' INTNUM ')'
		{
		  assert_ms_compat("Columns of type ANY (length) may be created only in MS-compatibility mode");
		  $$ = t_listst (2, (long) DV_ANY, (long) 0);
		}
	| IRI_ID '(' INTNUM ')'
		{ $$ = t_listst (2, (ptrlong) DV_IRI_ID, $3);
		}
	| IRI_ID
		{ $$ = t_listst (2, (ptrlong) DV_IRI_ID, (ptrlong)12); /* #i+10digits */
		}
	| IRI_ID_8
		{ $$ = t_listst (2, (ptrlong) DV_IRI_ID_8, (ptrlong)22); /* #i+20digits */
		}
	;

data_type
	: base_data_type
	| CHARACTER
		{ $$ = t_listst (2, (long) DV_LONG_STRING, (long) 1);
		}
	| VARCHAR
		{ $$ = t_listst (2, (long) DV_LONG_STRING, (long) 0);
		}
	| CHARACTER '(' INTNUM ')'
		{ $$ = t_listst (2, (long) DV_LONG_STRING, $3);
		}
	| VARCHAR '(' INTNUM ')'
		{ $$ = t_listst (2, (long) DV_LONG_STRING, $3);
		}
/*	| UNAME_L
		{ $$ = t_listst (2, (long) DV_UNAME, (long) 0);
		}*/
	;

array_modifier
	: ARRAY { $$ = t_box_num (0x7fffffff); }
	| ARRAY '[' INTNUM ']' { $$ = $3; }
	;

data_type_ref
	: data_type_ref array_modifier
		{
		  $$ = t_listst (5, (long) DV_ARRAY_OF_POINTER, $2, 0, 0, $1);
		}
	| data_type   { $$ = $1; }
	| q_type_name { $$ = t_listst (4, (long) DV_OBJECT, 0, 0, $1); }
	;

column_data_type
	: base_data_type
	| CHARACTER
		{ $$ = t_listst (2, (long) DV_LONG_STRING, (long) 1);
		}
	| VARCHAR
		{ $$ = t_listst (2, (long) DV_LONG_STRING, (long) 0);
		}
	| VARCHAR '(' INTNUM ')'
		{ $$ = t_listst (2, (long) DV_LONG_STRING, $3);
		}
	| CHARACTER '(' INTNUM ')'
		{ $$ = t_listst (2, (long) DV_LONG_STRING, $3);
		}
	| q_type_name /* user defined type */
		{
		  if (!CASEMODESTRCMP ($1, xmltype_class_name))
		    {
		      $$ = t_listst (5, (long) DV_BLOB, t_box_num (0x7fffffff), NULL, NULL,
			t_list (2, t_box_string ("xml_col"), t_box_string ("1")) );
		    }
		  else
		    $$ = t_listst (4, (long) DV_OBJECT, 0, 0, $1);
		}
	| LONG_L q_type_name /* user defined type into long col */
		{
		  if (!CASEMODESTRCMP ($2, xmltype_class_name))
		    {
		      $$ = t_listst (5, (long) DV_BLOB, t_box_num (0x7fffffff), NULL, NULL,
			t_list (2, t_box_string ("xml_col"), t_box_string ("1")) );
		    }
		  else
		    $$ = t_listst (4, (long) DV_BLOB, t_box_num (0x7fffffff), NULL, $2);
		}
	| LONG_L ANY
		{
		  $$ = t_listst (4, (long) DV_BLOB, t_box_num (0x7fffffff), NULL, t_box_string ("DB.DBA.__ANY"));
		}
	| LONG_L XML /* user defined type into long col */
		{ $$ = t_listst (5, (long) DV_BLOB, t_box_num (0x7fffffff), NULL, NULL,
		    t_list (2, t_box_string ("xml_col"), t_box_string ("1")));
		}
	;
/* the various things you can name */
column
	: identifier
		{
		  if (strchr ($1, '.'))
		    yy_new_error ("Dots not allowed inside column names", "37000", "SQ137");
		  else
		    $$ = $1;
		}

	| identifier '.' identifier '.' identifier '.' identifier
		{
		  assert_ms_compat("Qualified column names are allowed only in MS-compatibility mode.");
		  $$ = $7;
		}
	;

index
	: identifier		{ $$ = $1; }
	;

cursor
	: identifier		{ $$ = $1; }
	;

parameter
	: PARAMETER_L	{ $$ = $1; }
	| NAMED_PARAMETER	{ $$ = $1; }
	;

user
	: identifier		{ $$ = $1; }
	;

opt_log
	: /* empty */	{ $$ = (ST *) 0; }
	| STRING	{ $$ = (ST *) $1; }
	;

comma_opt_log
	: /* empty */		{ $$ = (ST *) 0; }
	| ',' STRING		{ $$ = (ST *) $2; }
	;

admin_statement
	: SHUTDOWN opt_log
		{ $$ = t_listst (4, OP_SHUTDOWN, $2, NULL, NULL); }
	| CHECKPOINT opt_log
		{ $$ = t_listst (4, OP_CHECKPOINT, $2, NULL, NULL); }
	| CHECKPOINT STRING STRING
		{ $$ = t_listst (4, OP_CHECKPOINT, $2, $3, NULL); }
	| BACKUP STRING
		{ $$ = t_listst (4, OP_BACKUP, $2, NULL, NULL); }
	| CHECK
		{ $$ = t_listst (4, OP_CHECK, NULL, NULL, NULL); }
	| SYNC REPLICATION opt_log comma_opt_log
		{ $$ = t_listst (4, OP_SYNC_REPL, $3, $4, NULL); }
	| DISCONNECT REPLICATION opt_log
		{ $$ = t_listst (4, OP_DISC_REPL, $3, NULL, NULL); }
	| LOGX ON
		{ $$ = t_listst (4, OP_LOG_ON, NULL, NULL, NULL); }
	| LOGX OFF
		{ $$ = t_listst (4, OP_LOG_OFF, NULL, NULL, NULL); }
	;

/* SQL Procedures */

sql
	: user_aggregate_declaration
	| routine_declaration
	| module_declaration
	| method_declaration
	| trigger_def
	| drop_trigger
	| drop_proc
	;

user_aggregate_declaration
	: CREATE AGGREGATE new_table_name rout_parameter_list opt_return
	  FROM new_proc_or_bif_name ',' new_proc_or_bif_name ',' new_proc_or_bif_name
	  user_aggregate_merge_opt user_aggregate_order_opt
		{
		  $$ = t_listst (9, USER_AGGREGATE_DECL, $3, $4, $5,
				 $7, $9, $11, $12, $13 );
		}
	;

user_aggregate_merge_opt
	: /* empty */		{ $$ = NULL; }
	| ',' new_proc_or_bif_name	{ $$ = $2; }
	;

user_aggregate_order_opt
	: /* empty */		{ $$ = NULL; }
	| ORDER	{ $$ = (caddr_t)1; }
	;

routine_declaration
	: CREATE routine_head new_table_name rout_parameter_list
	  opt_return rout_alt_type compound_statement
		{ $$ = t_listst (7, ROUTINE_DECL, (ptrlong) $2, $3, $4, $5, $7, $6); }

	| ATTACH routine_head attach_q_table_name rout_parameter_list opt_return rout_alt_type opt_as FROM literal
		{
		  $$ = t_listst (8, REMOTE_ROUTINE_DECL, (ptrlong) $2, $3, $4, $5, $7, $9, $6);
		}
	| CREATE routine_head new_table_name rout_parameter_list
	  opt_return rout_alt_type LANGUAGE external_language_name EXTERNAL NAME_L STRING opt_type_option_list
		{ $$ = sqlp_udt_create_external_proc ((ptrlong) $2, $3,
		    $4, $5, $6, (ptrlong) $8, $11, (ST **) $12); }

	;

module_body_part
	: routine_head identifier rout_parameter_list
	  opt_return rout_alt_type compound_statement
		{ $$ = t_listst (7, ROUTINE_DECL, (ptrlong) $1, $2, $3, $4, $6, $5); }
	;

module_body
	: module_body_part ';'
		{ $$ = t_CONS ($1, NULL); }
	| module_body module_body_part ';'
		{ $$ = t_NCONC ($1, t_CONS ($2, NULL)); }
	;

module_declaration
	: CREATE MODULE new_table_name BEGINX module_body ENDX
		{
		  $$ = t_listst (3, MODULE_DECL, $3, t_list_to_array ($5));
		}
	;

routine_head
	: FUNCTION	{ $$ = FUNCTION; }
	| PROCEDURE	{ $$ = PROCEDURE; }
	;

opt_return
	: /* empty */		{ $$ = NULL; }
	| RETURNS data_type_ref	{ $$ = $2; }
	;

rout_parameter_list
	: '(' ')' { $$ = (caddr_t) t_list (0); }
	|  '(' parameter_commalist ')'	{ $$ = t_list_to_array_box ($2); }
	;

parameter_commalist
	: rout_parameter
		{ $$ = t_CONS ($1, NULL); }
	| parameter_commalist ',' rout_parameter
		{ $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

rout_parameter
	: parameter_mode column_ref data_type_ref rout_alt_type
		{ $$ = t_listst (6, LOCAL_VAR, (ptrlong) $1, $2, $3, NULL, $4); }
	| parameter_mode column_ref data_type_ref DEFAULT signed_literal rout_alt_type
		{ $$ = t_listst (6, LOCAL_VAR, (ptrlong) $1, $2, $3, $5, $6); }
	| parameter_mode column_ref data_type_ref EQUALS signed_literal rout_alt_type
		{ $$ = t_listst (6, LOCAL_VAR, (ptrlong) $1, $2, $3, $5, $6); }
	;

parameter_mode
	: IN_L	{ $$ = IN_MODE; }
	| OUT_L	{ $$ = OUT_MODE; }
	| INOUT_L	{ $$ = INOUT_MODE; }
	;

opt_parameter_mode
	: /* empty */ { $$ = IN_MODE; }
	| parameter_mode
	;

opt_soap_enc_mode
	: /* empty */ 			{ $$ = 0; }
	| __SOAP_DIME_ENC IN_L		{ $$ = SOAP_MSG_IN;    }
	| __SOAP_DIME_ENC OUT_L		{ $$ = SOAP_MSG_OUT;   }
	| __SOAP_DIME_ENC INOUT_L	{ $$ = SOAP_MSG_INOUT; }
	| __SOAP_ENC_MIME IN_L		{ $$ = SOAP_MMSG_IN;    }
	| __SOAP_ENC_MIME OUT_L		{ $$ = SOAP_MMSG_OUT;   }
	| __SOAP_ENC_MIME INOUT_L	{ $$ = SOAP_MMSG_INOUT; }
	;

soap_proc_opt_list
	: soap_proc_opt					{ $$ = $1; }
	| soap_proc_opt_list ',' soap_proc_opt		{ $$ = t_NCONC ($1, $3); }
	;

soap_proc_opt
	: NAME EQUALS signed_literal { $$ = t_CONS ($1, t_CONS ($3, NULL)); }
	;

soap_kwd
	: __SOAP_TYPE 		{ $$ = 0; }
	| __SOAP_HEADER		{ $$ = SOAP_MSG_HEADER; }
	| __SOAP_FAULT		{ $$ = SOAP_MSG_FAULT; }
	| __SOAP_DOC		{ $$ = SOAP_MSG_LITERAL; }
	| __SOAP_XML_TYPE	{ $$ = SOAP_MSG_XML; }
	| __SOAP_DOCW		{ $$ = (SOAP_MSG_LITERALW|SOAP_MSG_LITERAL); }
	| __SOAP_HTTP		{ $$ = SOAP_MSG_HTTP; }
	;

rout_alt_type
 	:  /* empty */ 		 		    { $$ = NULL; }
	| __SOAP_OPTIONS '(' soap_kwd EQUALS STRING opt_soap_enc_mode ',' soap_proc_opt_list ')'
						    { $$ = t_listbox (3, $5, (ptrlong) ($3|$6), t_list_to_array_box ($8)); }
	| soap_kwd STRING opt_soap_enc_mode 	    { $$ = t_listbox (3, $2, (ptrlong) ($1|$3), NULL); }
	;

cost_number
	: INTNUM {  $$ = t_box_float ((float) unbox ($1)); }
	| APPROXNUM { double d;
  switch (DV_TYPE_OF ($1))
    {
    case DV_SINGLE_FLOAT: $$ = $1; break;
    case DV_DOUBLE_FLOAT: $$ = t_box_float ((float) unbox_double ($1)); break;
    case DV_NUMERIC: numeric_to_double ((numeric_t) $1, &d); $$ = t_box_float ((float)d); break;
    }
}
	;

cost_number_list
	: cost_number { $$ = t_CONS ($1, NULL); }
	| cost_number_list ',' cost_number { $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

cost_decl
	: __COST '(' cost_number_list ')' { $$ = (ST*) t_list (2, PROC_COST, t_list_to_array ($3)); }
	;


vectored_decl
	: VECTORED { $$ = (ST *) t_list (1, OPT_VECTORED); }
	;


routine_statement
	: selectinto_statement
	| update_statement_positioned
	| update_statement_searched
	| insert_statement
	| delete_statement_positioned
	| delete_statement_searched
	| close_statement
	| fetch_statement
	| open_statement
	| rollback_statement
	| commit_statement
	| cost_decl
	| vectored_decl
	| /* empty */				{ $$ = t_listst (1, NULL_STMT); }
	;

compound_statement
	: BEGINX { BR_PUSH } statement_list ENDX
		 { $$ = t_listst (5, COMPOUND_STMT,
			   t_list_to_array ($3),
			   t_box_num (BR_GET),
			   t_box_num (BR_LGET),
                           t_box_string (scn3_get_file_name ())
			); BR_POP }
	;

statement_list
	: statement_in_cs		 { $$ = t_CONS ($1, NULL); }
	| statement_list statement_in_cs { $$ = t_NCONC ($1, t_CONS ($2, NULL)); }
	;

statement_in_cs
	: local_declaration ';'
	| compound_statement
	| { BR_PUSH } statement_in_cs_oper { $$ = BR_CSTM ($2); BR_POP }
	;

statement_in_cs_oper
	: routine_statement ';'
	| control_statement
	| identifier COLON statement_in_cs	{ $$ = t_listst (3, LABELED_STMT, $1, $3); }
	| HTMLSTR 			{ $$ = (ST*) t_list (3, CALL_STMT, t_sqlp_box_id_upcase ("http"), t_list (1, $1)); }
	| COMPARISON  scalar_exp HTMLSTR { $$ = (ST*) t_list (5, COMPOUND_STMT,
              t_list (2,
		t_list (3, CALL_STMT, t_sqlp_box_id_upcase ("http_value"), t_list (1, $2)),
		t_list (3, CALL_STMT, t_sqlp_box_id_upcase ("http"), t_list (1, $3))),
              t_box_num (global_scs->scs_scn3c.lineno),
              t_box_num (scn3_get_lineno ()),
              t_box_string (scn3_get_file_name ())
               ); }
	| '/' scalar_exp HTMLSTR { $$ = (ST*) t_list (5, COMPOUND_STMT,
              t_list (2,
		t_list (3, CALL_STMT, t_sqlp_box_id_upcase ("http_url"), t_list (1, $2)),
		t_list (3, CALL_STMT, t_sqlp_box_id_upcase ("http"), t_list (1, $3))),
              t_box_num (global_scs->scs_scn3c.lineno),
              t_box_num (scn3_get_lineno ()),
              t_box_string (scn3_get_file_name ())
              ); }
        | SPARQL_L sqlonly_query_exp ';' {
          ST *qry = $2;
          ST *scalar_qry = $$ = (ST *) t_list (2, SCALAR_SUBQ, sqlp_add_top_1 (qry));
          $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("isnull"), t_list (1, scalar_qry)); }
	;

statement
	: compound_statement
	| { BR_PUSH } routine_statement ';' { $$ = BR_CSTM ($2); BR_POP }
	| { BR_PUSH } control_statement { $$ = BR_CSTM ($2); BR_POP }
	;

local_declaration
	: cursor_def
	| variable_declaration
	| handler_declaration
	;

variable_declaration
	: DECLARE variable_list data_type_ref
		{
		  ST **temp = (ST **) t_list_to_array ($2);
		  $$ = t_listst (2, VARIABLE_DECL,
		      sqlp_local_variable_decls ((caddr_t *) temp, $3));
		}
	;

variable_list
	: identifier
		{ $$ = t_CONS (t_list (3, COL_DOTTED, NULL, $1), NULL); }
	| variable_list ',' identifier
		{ $$ = t_NCONC ($1, t_CONS (t_list (3, COL_DOTTED, NULL, $3), NULL)); }
	;

condition
	: NOT FOUND		{ $$ = (caddr_t) SQL_NO_DATA_FOUND; }
	| SQLSTATE_L STRING	{ $$ = (caddr_t) t_list (2, $2, sqlp_handler_star_pos ($2)); }
	| SQLSTATE_L VALUE STRING
		{
		  $$ = t_listbox (2, $3, sqlp_handler_star_pos ($3));
		}
	| SQLEXCEPTION		{ $$ = (caddr_t) SQL_SQLEXCEPTION; }
	| SQLWARNING		{ $$ = t_listbox (2, t_box_string ("01*"), 2); }
	;

handler_statement
	: compound_statement
	| routine_statement
	| call_statement
	| method_invocation
	| static_method_invocation
	| set_statement
	| RESIGNAL { $$ = sqlp_resignal (NULL); }
	| RESIGNAL scalar_exp { $$ = sqlp_resignal ($2); }
	| return_statement
	| assignment_statement
	| if_statement
	| goto_statement
	| for_statement
	| while_statement
	;

handler_declaration
	: WHENEVER condition GOTO identifier
		{ $$ = t_listst (4, HANDLER_DECL, HANDT_CONTINUE, t_list (1, $2), t_list (2, GOTO_STMT, $4)); }
	| WHENEVER condition GO TO identifier
		{ $$ = t_listst (4, HANDLER_DECL, HANDT_CONTINUE, t_list (1, $2), t_list (2, GOTO_STMT, $5)); }
	| WHENEVER condition DEFAULT
		{ $$ = t_listst (4, HANDLER_DECL, HANDT_CONTINUE, t_list (1, $2), sqlp_resignal (NULL)); }
	| DECLARE handler_type HANDLER FOR cond_value_list handler_statement
		{ $$ = t_listst (4, HANDLER_DECL, (ptrlong) $2, t_list_to_array ($5), $6); }
	;

handler_type
	: CONTINUE { $$ = HANDT_CONTINUE; }
	| EXIT { $$ = HANDT_EXIT; }
	;

cond_value_list
	: condition	{ $$ = t_CONS ($1, NULL); }
	| cond_value_list ',' condition	{ $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

control_statement
	: call_statement ';'
	| method_invocation ';'
	| static_method_invocation ';'
	| set_statement ';'
	| RESIGNAL ';' { $$ = sqlp_resignal (NULL); }
	| RESIGNAL scalar_exp ';' { $$ = sqlp_resignal ($2); }
	| return_statement ';'
	| assignment_statement ';'
	| if_statement
	| goto_statement ';'
	| for_statement
	| while_statement
	;

assignment_statement
	: lvalue EQUALS scalar_exp	{ $$ = t_listst (3, ASG_STMT, $1, sqlp_wrapper_sqlxml_assign((ST*)$3)); }
	| column_ref array_index_list EQUALS scalar_exp
					{ $$ = t_listst (3, CALL_STMT,
	    					t_sqlp_box_id_upcase ("aset"),
						t_list_to_array (t_CONS ($1, t_NCONC ($2, t_CONS ($4, NULL)))) ); }
/*	| lvalue '=' scalar_exp		{ $$ = t_listst (3, ASG_STMT, $1, $3); }*/
	;

array_index_list
	: '[' scalar_exp ']'			{ $$ = t_CONS ($2, NULL); }
	| array_index_list '[' scalar_exp ']'	{ $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

lvalue
	: column_ref
	| member_observer
/* pmn	| identifier '.' identifier	{ $$ = t_listst (3, COL_DOTTED, $1, $3); } */
/*	| array_ref	{ $$ = $1; } */
	;

/*** pmn
elseif_clause
	: ELSEIF search_condition THEN statement
		{ $$ = t_listst (3, (long) COND_CLAUSE, $2, $4); }
	;

elseif_list
	: / * empty * /			{ $$ = NULL; }
	| elseif_clause			{ $$ = t_CONS ($1, NULL); }
	| elseif_list elseif_clause	{ $$ = t_NCONC ($1, t_CONS ($2, NULL)); }
	;
*/

/*
if_statement
	: IF search_condition THEN statement elseif_list opt_else ENDX IF
		{ ST *first = t_listst (3, (long) COND_CLAUSE, $2, $4);
		  ST *cond_list = t_CONS (first, $5);
		  $$ = t_listst (3, (long) IF_STMT, cond_list, $6);
		}
	;
*/

if_statement
	: IF '(' search_condition ')' statement opt_else
		{ ST *first = t_listst (3, COND_CLAUSE, $3, $5);
		  ST *cond_list = t_listst (1, first);
		  $$ = t_listst (3, IF_STMT, cond_list, $6);
		}
	;

opt_else
	: /* empty */			{ $$ = NULL; }
	| ELSE statement		{ $$ = $2; }
	;

call_statement
	: CALL function_name '(' opt_arg_commalist ')'
		{ $$ = t_listst (3, CALL_STMT, $2, t_list_to_array ($4)); }
	| SPARQL_L function_call	{ $$ = $2; }
	| function_call			{ $$ = $1; }
	;

txn_isolation_level
	: READ_L UNCOMMITTED_L	{ $$ = t_box_string ($2); }
	| READ_L COMMITTED_L	{ $$ = t_box_string ($2); }
	| REPEATABLE_L READ_L   { $$ = t_box_string ($1); }
	| SERIALIZABLE_L	{ $$ = t_box_string ($1); }
	;

set_statement
	: SET identifier COMPARISON scalar_exp
		{ $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("__set"),
		      t_list (2, t_sqlp_box_upcase ($2), $4)); }
	| SET identifier ON
		{ $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("__set"),
		      t_list (2, t_sqlp_box_upcase ($2), t_box_num (1))); }
	| SET identifier OFF
		{ $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("__set"),
		      t_list (2, t_sqlp_box_upcase ($2), t_box_num (0))); }
	| SET TRANSACTION_L ISOLATION_L LEVEL_L txn_isolation_level
		{ $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("__set"),
		      t_list (2, t_sqlp_box_upcase ($3), $5)); }
	;

goto_statement
	: GOTO identifier	{ $$ = t_listst (2, GOTO_STMT, $2); }
	| GO TO identifier	{ $$ = t_listst (2, GOTO_STMT, $3); }
	;

return_statement
	: RETURN scalar_exp	{ $$ = t_listst (2, RETURN_STMT, sqlp_wrapper_sqlxml_assign((ST*)$2)); }
	| RETURN		{ $$ = t_listst (2, RETURN_STMT, NULL); }
	;

while_statement
	: WHILE '(' search_condition ')' statement
		{ $$ = t_listst (3, WHILE_STMT, $3, $5); }
	;

for_init_statement
        : assignment_statement
	| variable_declaration
        | call_statement
        | static_method_invocation
        ;

for_init_statement_list
	: /* empty */ { $$ = NULL; }
	| for_init_statement { $$ = t_CONS ($1, NULL); }
        | for_init_statement_list ',' for_init_statement { $$ = $3 ? t_NCONC ($1, t_CONS ($3, NULL)) : $1; }
	;

for_inc_statement
        : assignment_statement
        | call_statement
        | static_method_invocation
        ;

for_inc_statement_list
	: /* empty */ { $$ = NULL; }
	| for_inc_statement { $$ = t_CONS ($1, NULL); }
        | for_inc_statement_list ',' for_inc_statement { $$ = $3 ? t_NCONC ($1, t_CONS ($3, NULL)) : $1; }
	;

for_opt_search_cond
	: /* empty */ { NEGATE ($$, t_listst (3, BOP_EQ, t_box_num_and_zero (0), t_box_num (1))); }
	| search_condition { $$ = $1; }
	;

vectored_var
	: IN_L identifier data_type_ref EQUALS scalar_exp { $$ = t_listst (5, VECT_DECL, IN_MODE, t_listst (3, COL_DOTTED, NULL, $2), $3, $5); }
	| OUT_L identifier EQUALS scalar_exp { $$ = t_listst (5, VECT_DECL, OUT_MODE, t_listst (3, COL_DOTTED, NULL, $2), NULL, $4); }
	;

vectored_list
	: vectored_var
		{ $$ = t_CONS ($1, NULL); }
	| vectored_list ',' vectored_var
		{ $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;


opt_modify
	: /* empty */  { $$ = 0;}
	| MODIFY { $$ = 1; }
;

for_statement
	: FOR query_exp  DO statement
		{ $$ = sqlp_for_statement ($2, $4); }
	| FOR '(' for_init_statement_list ';' for_opt_search_cond ';' for_inc_statement_list ')' statement
		{ $$ = sqlp_c_for_statement ((ST **) t_list_to_array ($3), $5, (ST **) t_list_to_array ($7), $9); }
	| FOREACH '(' data_type_ref identifier IN_L scalar_exp ')' DO statement
		{ $$ = sqlp_foreach_statement ($3, $4, $6, $9); }
	| FOR VECTORED opt_modify '(' vectored_list ')' compound_statement { $$ = t_listst (4, FOR_VEC_STMT, t_list_to_array ($5), $7, (ptrlong) $3); }
	| NOT VECTORED compound_statement { $$ = t_listst (4, NOT_VEC_STMT, NULL, $3, NULL); }
	;

trigger_def
	: CREATE TRIGGER identifier action_time event ON q_table_name
			opt_order opt_old_ref trig_action
		{ $$ = t_listst (8, TRIGGER_DEF, $3, (ptrlong) $4, $5, $7, $8, $9, $10); }
	;

opt_order
	: { $$ = 0; }
	| ORDER INTNUM	{ $$ = $2; }
	;

trig_action
	: compound_statement
	;

action_time
	: BEFORE	{ $$ = TRIG_BEFORE; }
	| AFTER		{ $$ = TRIG_AFTER; }
	| INSTEAD OF	{ $$ = TRIG_INSTEAD; }
	;

event
	: INSERT			{ $$ = (caddr_t) TRIG_INSERT; }
	| UPDATE opt_column_commalist	{ $$ = (caddr_t) $2; }
			/* null is update of any */
	| DELETE_L			{ $$ = (caddr_t) TRIG_DELETE; }
	;

opt_old_ref
	: /* empty */			{ $$ = NULL; }
	| REFERENCING old_commalist	{ $$ = (caddr_t) t_list_to_array ($2); }
	;

old_commalist
	: old_alias			{ $$ = t_CONS ($1, NULL); }
	| old_commalist ',' old_alias	{ $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

old_alias
	: OLD AS identifier			{ $$ = t_listst (2, OLD_ALIAS, $3); }
	| NEW AS identifier			{ $$ = t_listst (2, NEW_ALIAS, $3); }
	;

drop_trigger
	: DROP TRIGGER q_table_name
		{ $$ = t_listst (3, CALL_STMT,
			t_sqlp_box_id_upcase ("DB.DBA.ddl_drop_trigger"),
			t_list (1, t_box_string ($3)));
		}
	;


drop_proc
	: DROP AGGREGATE q_table_name
		{ $$ = t_listst (3, CALL_STMT,
			t_sqlp_box_id_upcase ("DB.DBA.ddl_drop_proc"),
			t_list (2, t_box_string ($3), 4));
		}
	| DROP routine_head q_table_name
		{ $$ = t_listst (3, CALL_STMT,
			t_sqlp_box_id_upcase ("DB.DBA.ddl_drop_proc"),
			t_list (1, t_box_string ($3)));
		}
	| DROP MODULE q_table_name
		{ $$ = t_listst (3, CALL_STMT,
			t_sqlp_box_id_upcase ("DB.DBA.ddl_drop_proc"),
			t_list (2, t_box_string ($3), 0));
		}
	;



/* XML */




opt_element
	:   { $$ = NULL; }
	| AS identifier  { $$ = $2; }
	;

xml_col
	: column_ref	 {
	  if ($1->_.col_ref.name == STAR)
	    yyerror (scanner,"No stars allowed inside XML view definition");
	  else
/*mapping schema*/
	    $$ = (ST*) t_list (5, $1, box_dv_uname_string ($1->_.col_ref.name), XV_XC_ATTRIBUTE, NULL, NULL);
	}
	| scalar_exp AS identifier	 { $$ = (ST*) t_list (5, $1, box_dv_uname_string ($3), XV_XC_ATTRIBUTE, NULL, NULL); }
	| scalar_exp IN_L identifier { $$ = (ST*) t_list (5, $1, box_dv_uname_string ($3), XV_XC_SUBELEMENT, NULL, NULL); }
	;

/*end mapping schema*/
/*
	    $$ = (ST*) t_list (3, $1, t_box_copy ($1->_.col_ref.name), 0);
	}
	| scalar_exp AS identifier	 { $$ = (ST*) t_list (3, $1, $3, 0); }
	| scalar_exp IN_L identifier { $$ = (ST*) t_list (3, $1, $3, 1); }
	;

*/
xml_col_list
	: xml_col  { $$ = t_CONS ($1, NULL); }
	|  xml_col_list ',' xml_col   { $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;


opt_xml_col_list
	: '(' xml_col_list ')'  { $$ = (ST*) t_list_to_array ($2); }
	;

opt_pk
	: { $$ = NULL; }
	|  PRIMARY KEY '(' column_commalist ')' { $$ = (ST *) t_list_to_array ($4); }
	;



opt_join
	:	{ $$ = NULL; }
	| ON '(' search_condition ')'  { $$ = $3; }
	;


opt_elt
	:	 { $$ = 0; }
	| NAME { $$ = 1; }
	;


xml_join_elt
	: q_table_name identifier opt_element opt_xml_col_list opt_join opt_pk opt_elt opt_xml_child
	  {
/*mapping schema*/
	    $$ = (ST*) t_list (12,
			     $1, $2,
			     box_dv_uname_string ($3 ? (caddr_t) $3 : $1), $4,
			     $5, (ptrlong) 1, NULL /* no support for filter */,
			     $8, NULL /* parent will be filled later */,
			     $6, (ptrlong) $7, NULL);
/*end mapping schema*/
/*	    $$ = (ST*) t_list (11,
			     $1, $2,
			     ($3 ? (caddr_t) $3 : t_box_copy ($1)), $4,
			     $5, 1l, NULL / * no support for filter * /,
			     $8, NULL / * parent will be filled later * /,
			     $6, $7);*/
	  }
	;

opt_xml_child
	: /* empty */ { $$ = NULL; }
	| BEGINX xml_join_list ENDX { $$ = (ST*) t_list_to_array ($2); }
	;


top_xml_child
	: query_spec  { $$ = $1; }
	| BEGINX xml_join_list ENDX { ST * tmp  = (ST*) t_list_to_array ($2);
/*mapping schema*/
	$$ = (ST *) t_list (12, NULL, NULL, NULL, NULL, NULL, (ptrlong) 1, NULL, tmp, NULL, NULL, NULL, NULL); }
	;
/*end mapping schema*/
/*	$$ = (ST *) t_list (11, NULL, NULL, NULL, NULL, NULL, 1l, NULL, tmp, NULL, NULL, NULL); }
	;*/


xml_join_list
	:  xml_join_elt  { $$ = t_CONS ($1, NULL); }
	| xml_join_list ',' xml_join_elt { $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

opt_persist
	: { $$ = NULL; }
	| PERSISTENT { $$ = t_box_num (1); }
	;

opt_interval
	: { $$ = t_box_num (0); }
	| INTERVAL INTNUM  { $$ = $2; }
	;

/* IvAn/XmlView/000810 Options added for "create xml view" statement */
/*
opt_metas
	: { $$ = (ST*) list (2, box_num(0), box_string("")); }
	| DTD INTERNAL { $$ = (ST*) list (2, box_num(1), box_string("")); }
	| DTD EXTERNAL { $$ = (ST*) list (2, box_num(2), box_string("")); }
	| DTD STRING { $$ = (ST*) list (2, box_num(3), $2); }
	| SCHEMA INTERNAL { $$ = (ST*) list (2, box_num(4), box_string("")); }
	| SCHEMA EXTERNAL { $$ = (ST*) list (2, box_num(5), box_string("")); }
	| SCHEMA STRING { $$ = (ST*) list (2, box_num(6), $2); }
	;
*/
opt_metas
	: { $$ = (ST*) t_list (2, t_box_num(0), t_box_string("")); }
	| DTD INTERNAL { $$ = (ST*) t_list (2, t_box_num(1), t_box_string("")); }
	| DTD EXTERNAL { $$ = (ST*) t_list (2, t_box_num(2), t_box_string("")); }
	| DTD STRING { $$ = (ST*) t_list (2, t_box_num(3), $2); }
	| SCHEMA EXTERNAL { $$ = (ST*) t_list (2, t_box_num(5), t_box_string("")); }
	| SCHEMA STRING { $$ = (ST*) t_list (2, t_box_num(6), $2); }
	;

opt_publish
	: { $$ = NULL; }
	| PUBLIC STRING identifier STRING opt_persist opt_interval opt_metas
	   {
	     if (stricmp ($3, "OWNER") && stricmp ($3, "NAME"))
	       yyerror (scanner,"syntax error at WebDAV OWNER keyword");
	     $$ = (ST*) t_list (5, $2, $4, $5, $6, $7);
	   }
	;


xmlview_param_value
	: NAME
	| STRING
	;

xmlview_param
        : NAME COMPARISON xmlview_param_value
            {
              if ($2 != BOP_EQ)
		yyerror (scanner,"'=' expected");
	      $$ = (ST *) t_list (2, $1, $3);
            }
	;


xmlview_params
        : xmlview_param
/*           { $$ = (ST*) t_list (1, $1); } */
           { $$ = t_CONS ($1, NULL); }
        | xmlview_params xmlview_param
           { $$ = t_NCONC ($1, t_CONS ($2, NULL)); }
        ;


opt_xmlview_params
        : { $$ = NULL; }
        | '[' xmlview_params ']'
            { $$ = $2; }
        ;


xml_view
	: CREATE XML VIEW new_table_name AS opt_xmlview_params top_xml_child opt_elt opt_publish
	  { $$ = (ST*) t_list (12, XML_VIEW, $4, NULL, NULL, 0,
			     $7, (ptrlong) $8, $9, t_list_to_array ($6), NULL, NULL, NULL); }
	;


drop_xml_view
	: DROP XML VIEW q_table_name
	  { $$ = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("DB.DBA.xml_view_drop"), t_list (1, $4)); }
	;


/*
xml_doc
	: CREATE XML 'DOCUMENT' identifier AS opt_xml_child INTO STRING USER STRING
	    {
	      $$ = t_listst (2, COMPOUND_STMT,
			      t_list(2,
			  t_list (6, XML_VIEW, $4, NULL, NULL, 0,
			     t_list (8, NULL, NULL, NULL, NULL, NULL, NULL, $6, NULL)),
			      t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("DB.DBA.xml_create_doc"),
			     t_list (3, $4, $8, $10))));
	    }
	;
*/


string_concatenation_operator
	: scalar_exp STRING_CONCAT_OPERATOR scalar_exp
                {
		  $$ = t_listst (3, CALL_STMT,
		      t_sqlp_box_id_upcase ("concat"),
		      t_listst (2, $1, $3));
		}
	;

/* types */
q_type_name
	: identifier			{ $$ = sqlp_type_name (NULL, 0, NULL, 0, $1, 1); }
	| identifier '.' identifier		{ $$ = sqlp_type_name (NULL, 0, $1, box_length ($1), $3, 1); }
	| identifier '.' identifier '.' identifier { $$ = sqlp_type_name ($1, box_length ($1), $3, box_length ($3), $5, 1); }
	| identifier '.'  '.' identifier	{ $$ = sqlp_type_name ($1, box_length ($1), NULL, 0, $4, 1); }
	;

q_old_type_name
	: identifier			{ $$ = sqlp_type_name (NULL, 0, NULL, 0, $1, 0); }
	| identifier '.' identifier		{ $$ = sqlp_type_name (NULL, 0, $1, box_length ($1), $3, 0); }
	| identifier '.' identifier '.' identifier { $$ = sqlp_type_name ($1, box_length ($1), $3, box_length ($3), $5, 0); }
	| identifier '.'  '.' identifier	{ $$ = sqlp_type_name ($1, box_length ($1), NULL, 0, $4, 0); }
	;

new_type_name
	: identifier			{ $$ = sqlp_new_table_name (NULL, 0, NULL, 0, $1); }
	| identifier '.' identifier		{ $$ = sqlp_new_table_name (NULL, 0, $1, box_length ($1), $3); }
	| identifier '.' identifier '.' identifier { $$ = sqlp_new_table_name ($1, box_length ($1), $3, box_length ($3), $5); }
	| identifier '.'  '.' identifier	{ $$ = sqlp_new_table_name ($1, box_length ($1), NULL, 0, $4); }
	;

user_defined_type
	: CREATE TYPE new_type_name opt_subtype_clause opt_external_and_language_clause { sqlp_udt_current_type = $3; }
	     opt_as_type_representation opt_type_option_list opt_method_specification_list
	     {
	       $$ = t_listst (7, UDT_DEF,
		   $3, $4, $5, $7, $8, $9);
	       sqlp_udt_current_type = NULL;
	       sqlp_udt_current_type_lang = UDT_LANG_NONE;
	     }
	;

user_defined_type_drop
	: DROP TYPE q_old_type_name opt_drop_behavior
	     {
	       $$ = t_listst (3, UDT_DROP, $3, (ptrlong) $4);
	     }
	;

opt_external_and_language_clause
	: /* empty */ { $$ = NULL; }
	| LANGUAGE language_name EXTERNAL NAME_L STRING
	     {
	       $$ = t_listst (3, UDT_EXT,
		   (ptrlong) $2, $5);
	       sqlp_udt_current_type_lang = $2;
       	     }
	| EXTERNAL NAME_L STRING LANGUAGE language_name
	     {
	       $$ = t_listst (3, UDT_EXT,
		   (ptrlong) $5, $3);
	       sqlp_udt_current_type_lang = $5;
       	     }
	| LANGUAGE language_name
	     {
	       $$ = t_listst (3, UDT_EXT,
		   (ptrlong) $2, NULL);
	       sqlp_udt_current_type_lang = $2;
       	     }
	;

opt_subtype_clause
	: /* empty */ { $$ = NULL; }
	| UNDER q_type_name { $$ = $2; }
	;

opt_as_type_representation
	: /* empty */ { $$ = NULL; }
	| AS type_representation { $$ = $2; }
	;

type_representation
	: '(' type_member_list ')' { $$ = (ST *) t_list_to_array ($2); }
	/* | data_type { $$ = t_listst (1, $1); } */
	;

type_member_list
	: type_member                      { $$ = t_CONS ($1, NULL); }
	| type_member_list ',' type_member { $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

opt_external_clause
	: /* empty */ { $$ = NULL; }
	| EXTERNAL NAME_L STRING { $$ = t_listst (4, UDT_EXT, UDT_LANG_NONE, $3, NULL); }
	| EXTERNAL NAME_L STRING EXTERNAL TYPE STRING { $$ = t_listst (4, UDT_EXT, UDT_LANG_NONE, $3, $6); }
	| EXTERNAL TYPE STRING { $$ = t_listst (4, UDT_EXT, UDT_LANG_NONE, NULL, $3); }
	;

opt_soap_clause
	: /* empty */ { $$ = NULL; }
	| __SOAP_NAME STRING { $$ = t_listst (3, UDT_SOAP, NULL, $2); }
	| __SOAP_TYPE STRING { $$ = t_listst (3, UDT_SOAP, $2, NULL); }
	| __SOAP_TYPE STRING __SOAP_NAME STRING { $$ = t_listst (3, UDT_SOAP, $2, $4); }
	| __SOAP_NAME STRING __SOAP_TYPE STRING { $$ = t_listst (3, UDT_SOAP, $4, $2); }
	;

opt_external_type
	: /* empty */ { $$ = NULL; }
	| EXTERNAL TYPE STRING { $$ = (ST *) $3; }
	;

type_member
	: identifier data_type_ref opt_reference_scope_check opt_default_clause opt_collate_exp opt_external_clause opt_soap_clause
	    {
	      $$ = t_listst (8, UDT_MEMBER, $1, $2, $3, $4, $5, $6, $7);
	    }
	;

opt_reference_scope_check
	: /* empty */ { $$ = NULL; }
	| REFERENCES ARE CHECKED opt_on_delete_referential_rule { $$ = $4; }
	| REFERENCES ARE NOT CHECKED { $$ = NULL; }
	;

opt_default_clause
	: /* empty */ { $$ = t_alloc_box (0, DV_DB_NULL); }
	| DEFAULT signed_literal { $$ = $2; }
	;

opt_type_option_list
	: /* empty */ { $$ = NULL; }
	| type_option_list { $$ = (ST *) t_list_to_array ($1); }
	;

type_option_list
	: type_option { $$ = t_CONS ($1, NULL); }
	| type_option_list type_option { $$ = t_NCONC ($1, t_CONS ($2, NULL)); }
	;

type_option
	: FINAL_L       { $$ = t_listst (2, UDT_FINAL, 1); }
	| NOT FINAL_L       { $$ = t_listst (2, UDT_FINAL, 0); }
	| REF USING data_type_ref  { $$ = t_listst (2, UDT_REF, $3); }
	| REF FROM '(' column_commalist ')' { $$ = t_listst (2, UDT_REF, $4); }
	| REF IS SYSTEM GENERATED { $$ = t_listst (1, UDT_REF);  }
	| CAST '(' SOURCE AS REF ')' WITH identifier { $$ = t_listst (3, UDT_REFCAST, 0, $8); }
	| CAST '(' REF AS SOURCE ')' WITH identifier { $$ = t_listst (3, UDT_REFCAST, 1, $8); }
	| SELF_L AS REF { $$ = t_listst (2, UDT_REFCAST, 0); }
	| TEMPORARY { $$ = t_listst (2, UDT_REFCAST, 1); }
	| UNRESTRICTED_L { $$ = t_listst (2, UDT_UNRESTRICTED, 1); }
	| __SOAP_TYPE STRING { $$ = t_listst (2, UDT_SOAP, $2); }
	;

opt_method_specification_list
	: /* empty */  { $$ = NULL; }
	| method_specification_list { $$ = (ST *) t_list_to_array ($1); }
	;

method_specification_list
	: method_specification { $$ = t_CONS ($1, NULL); }
	| method_specification_list ',' method_specification { $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

method_type
	: /* empty */ { $$ = UDT_METHOD_INSTANCE; }
	| STATIC_L    { $$ = UDT_METHOD_STATIC;  }
	| INSTANCE_L  { $$ = UDT_METHOD_INSTANCE; }
	;

decl_parameter_list
	: '(' ')' { $$ = (caddr_t) t_list (0); }
	|  '(' decl_parameter_commalist ')'	{ $$ = t_list_to_array_box ($2); }
	;

decl_parameter_commalist
	: decl_parameter
		{ $$ = t_CONS ($1, NULL); }
	| decl_parameter_commalist ',' decl_parameter
		{ $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

decl_parameter
	: opt_parameter_mode column_ref data_type_ref opt_external_type
		{ $$ = t_listst (6, LOCAL_VAR, IN_L, $2, $3, NULL, $4); }
	;

partial_method_specification
	: method_type METHOD method_identifier decl_parameter_list RETURNS data_type_ref opt_specific_method_name
            {
	      $$ = t_listst (6, UDT_METHOD,
		  (ptrlong) $1, $3, $4, $6, $7);
	    }
	| CONSTRUCTOR METHOD method_identifier decl_parameter_list opt_specific_method_name
            {
	      $$ = t_listst (6, UDT_METHOD,
		  UDT_METHOD_CONSTRUCTOR, $3, $4, NULL, $5);
	    }
	;

method_specification
	: partial_method_specification opt_self_result opt_method_characteristics
	    {
	      $$ = t_listst (5, UDT_METHOD_DEF,
		  0, $1, (ptrlong) $2, $3);
	    }
	| OVERRIDING partial_method_specification
	    {
	      $$ = t_listst (5, UDT_METHOD_DEF,
		  1, $2, NULL, NULL);
	    }
	;

opt_self_result
	: /* empty */ { $$ = 0; }
	| SELF_L AS RESULT { $$ = 1; }
	| SELF_L AS LOCATOR { $$ = 2; }
	| SELF_L AS RESULT SELF_L AS LOCATOR { $$ = 3; }
	;

opt_specific_method_name
	: /* empty */ { $$ = NULL; }
	| SPECIFIC new_table_name { $$ = $2; }
	;

opt_method_characteristics
	: /* empty */ { $$ = NULL; }
	| method_characteristics { $$ = (ST *)t_list_to_array ($1); }
	;

method_characteristics
	: method_characteristic
            {
	      $$ = ($1 != NULL ? t_CONS ($1, NULL) : NULL);
	    }
	| method_characteristics method_characteristic
	    {
	      if ($2 != NULL)
		$$ = t_NCONC ($1, t_CONS ($2, NULL));
	    }
	;

method_characteristic
	: LANGUAGE language_name       { $$ = t_listst (4, UDT_EXT, (ptrlong) $2, NULL, NULL); }
	| PARAMETER STYLE SQL_L        { $$ = NULL; /* no action for now */ }
	| PARAMETER STYLE GENERAL      { $$ = NULL; /* no action for now */ }
	| DETERMINISTIC                { $$ = NULL; /* no action for now */ }
	| NOT DETERMINISTIC            { $$ = NULL; /* no action for now */ }
	| NO_L SQL_L                   { $$ = NULL; /* no action for now */ }
	| CONTAINS SQL_L               { $$ = NULL; /* no action for now */ }
	| READS SQL_L DATA             { $$ = NULL; /* no action for now */ }
	| MODIFIES SQL_L DATA          { $$ = NULL; /* no action for now */ }
	| RETURNS NULLX ON NULLX INPUT { $$ = NULL; /* no action for now */ }
	| CALLED ON NULLX INPUT        { $$ = NULL; /* no action for now */ }
	| EXTERNAL NAME_L STRING      { $$ = t_listst (4, UDT_EXT, UDT_LANG_NONE, $3, NULL); }
	| EXTERNAL VARIABLE NAME_L STRING  { $$ = t_listst (4, UDT_VAR_EXT, UDT_LANG_NONE, $4, NULL); }
	| EXTERNAL TYPE STRING        { $$ = t_listst (4, UDT_EXT, UDT_LANG_NONE, NULL, $3); }
	;

external_language_name
	: ADA     { yyerror (scanner,"Language ADA not supported"); }
	| C_L3    { $$ = UDT_LANG_C; }
	| COBOL   { yyerror (scanner,"Language COBOL not supported"); }
	| FORTRAN { yyerror (scanner,"Language FORTRAN not supported"); }
	| MUMPS   { yyerror (scanner,"Language MUMPS not supported"); }
	| PASCAL_L { yyerror (scanner,"Language PASCAL not supported"); }
	| PLI     { yyerror (scanner,"Language PLI not supported"); }
	| JAVA    { $$ = UDT_LANG_JAVA; }
	| CLR    { $$ = UDT_LANG_CLR; }
	;

language_name
	: external_language_name
	| SQL_L   { $$ = UDT_LANG_SQL; }
	;

opt_constructor_return
	: /* empty */		{ $$ = NULL; }
	| RETURNS new_type_name	{ $$ = (ST *) $2; }
	;

method_declaration
	: CREATE method_type METHOD method_identifier rout_parameter_list opt_return rout_alt_type FOR q_type_name
	    compound_statement
	   {
	     $$ = (ST *) sqlp_udt_method_decl (0, $2, $4, $5, (caddr_t) $6, $9, (caddr_t) $10, (caddr_t) $7);
	   }
	| CREATE CONSTRUCTOR METHOD q_table_name rout_parameter_list opt_constructor_return FOR q_type_name
	    compound_statement
	   {
	     $$ = (ST *) sqlp_udt_method_decl (0, UDT_METHOD_CONSTRUCTOR, $4, $5, (caddr_t) $6, $8, (caddr_t) $9, NULL);
	   }
	;

static_method_invocation
	: q_type_name DOUBLE_COLON method_identifier '(' opt_arg_commalist ')'
	   { $$ = t_listst (5, CALL_STMT, $3, t_list_to_array ($5), NULL, $1); }
	;

identifier_chain
	: identifier '.' identifier '.' identifier '.' method_identifier
          {
	    dk_set_t set = NULL;
	    t_set_push (&set, $1);
	    t_set_push (&set, $3);
	    t_set_push (&set, $5);
	    t_set_push (&set, $7);
	    $$ = dk_set_nreverse (set);
	  }
	| identifier '.' '.' identifier '.' method_identifier
	  {
	    dk_set_t set = NULL;
	    t_set_push (&set, $1);
	    t_set_push (&set, t_box_string (""));
	    t_set_push (&set, $4);
	    t_set_push (&set, $6);
	    $$ = dk_set_nreverse (set);
	  }
	| identifier '.' identifier_chain { $$ = t_NCONC (t_CONS ($1, NULL), $3); }
	;

identifier_chain_method
	: identifier '.' identifier '.' identifier '.' identifier '.' method_identifier
          {
	    dk_set_t set = NULL;
	    t_set_push (&set, $1);
	    t_set_push (&set, $3);
	    t_set_push (&set, $5);
	    t_set_push (&set, $7);
	    t_set_push (&set, $9);
	    $$ = dk_set_nreverse (set);
	  }
	| identifier '.' '.' identifier '.' identifier '.' method_identifier
	  {
	    dk_set_t set = NULL;
	    t_set_push (&set, $1);
	    t_set_push (&set, t_box_string (""));
	    t_set_push (&set, $4);
	    t_set_push (&set, $6);
	    t_set_push (&set, $8);
	    $$ = dk_set_nreverse (set);
	  }
	| identifier '.' identifier_chain_method { $$ = t_NCONC (t_CONS ($1, NULL), $3); }
	;

method_invocation
	: scalar_exp_no_col_ref_no_mem_obs_chain '.' method_identifier '(' opt_arg_commalist ')'
           { $$ = t_listst (5, CALL_STMT, $3, t_list_to_array (t_CONS ($1, $5)), NULL, (ptrlong) 1); }
	| identifier_chain_method '(' opt_arg_commalist ')'
           { $$ = (ST *) sqlp_udt_identifier_chain_to_member_handler ($1, (caddr_t) $3, 0); }
	| '(' scalar_exp_no_col_ref AS q_type_name ')' '.' method_identifier '(' opt_arg_commalist ')'
           { $$ = t_listst (5, CALL_STMT, $7, t_list_to_array (t_CONS ($2, $9)), NULL, t_list (1, $4)); }
	| '(' column_ref AS q_type_name ')' '.' method_identifier '(' opt_arg_commalist ')'
           { $$ = t_listst (5, CALL_STMT, $7, t_list_to_array (t_CONS ($2, $9)), NULL, t_list (1, $4)); }
	;

top_level_method_invocation
	: METHOD CALL scalar_exp_no_col_ref_no_mem_obs_chain '.' method_identifier '(' opt_arg_commalist ')'
           { $$ = t_listst (5, CALL_STMT, $5, t_list_to_array (t_CONS ($3, $7)), NULL, (ptrlong) 1); }
	| METHOD CALL identifier_chain_method '(' opt_arg_commalist ')'
           { $$ = (ST *) sqlp_udt_identifier_chain_to_member_handler ($3, (caddr_t) $5, 0); }
	| METHOD CALL '(' scalar_exp_no_col_ref AS q_type_name ')' '.' method_identifier '(' opt_arg_commalist ')'
           { $$ = t_listst (5, CALL_STMT, $9, t_list_to_array (t_CONS ($4, $11)), NULL, t_list (1, $6)); }
	| METHOD CALL '(' column_ref AS q_type_name ')' '.' method_identifier '(' opt_arg_commalist ')'
           { $$ = t_listst (5, CALL_STMT, $9, t_list_to_array (t_CONS ($4, $11)), NULL, t_list (1, $6)); }
	;

member_observer
	: member_observer_no_id_chain
        | identifier '.' identifier_chain
           { $$ = (ST *) sqlp_udt_identifier_chain_to_member_handler (t_NCONC (t_CONS ($1, NULL), $3), NULL, 1); }
	;

member_observer_no_id_chain
	: scalar_exp_no_col_ref_no_mem_obs_chain '.' method_identifier
           { $$ = t_listst (3, CALL_STMT, $3, t_list (1, $1)); }
	| '(' scalar_exp_no_col_ref AS q_type_name ')' '.' method_identifier
           { $$ = t_listst (3, CALL_STMT, t_list (2, $7, $4), t_list (1, $2)); }
	| '(' column_ref AS q_type_name ')' '.' method_identifier
           { $$ = t_listst (3, CALL_STMT, t_list (2, $7, $4), t_list (1, $2)); }
	;

method_identifier
	: identifier { $$ = $1; }
	| EXTRACT { $$ = t_sqlp_box_id_upcase_nchars (global_scs->scs_scn3c.last_keyword_yytext, global_scs->scs_scn3c.last_keyword_yyleng); }
	;

new_invocation
	: NEW q_type_name '(' opt_arg_commalist ')'
		{ $$ = t_listst (3, CALL_STMT, $2, t_list_to_array ($4)); }
	;

user_defined_type_alter
	: ALTER TYPE q_type_name alter_type_action { $$ = t_listst (3, UDT_ALTER, $3, $4); }
	;

alter_type_action
	: ADD ATTRIBUTE type_member { $$ = t_listst (2, UDT_MEMBER_ADD, $3); }
	| DROP ATTRIBUTE identifier opt_drop_behavior { $$ = t_listst (3, UDT_MEMBER_DROP, $3, (ptrlong) $4); }
	| ADD method_specification { $$ = t_listst (2, UDT_METHOD_ADD, $2); }
	| DROP partial_method_specification opt_drop_behavior { $$ = t_listst (3, UDT_METHOD_DROP, $2, (ptrlong) $3); }
	;

opt_with_permission_set
	: /* empty */ { $$ = NULL; }
	| WITH PERMISSION_SET COMPARISON SAFE_L { $$ = t_box_num (1); }
	| WITH PERMISSION_SET COMPARISON UNRESTRICTED_L { $$ = t_box_num (2); }
	;

opt_with_autoregister
	: /* empty */ { $$ = NULL; }
	| WITH AUTOREGISTER_L { $$ = t_box_num (1); }
	;

create_library
	: CREATE LIBRARY_L q_table_name AS scalar_exp opt_with_permission_set opt_with_autoregister
	   {
	     $$ = (ST*) t_list (3, CALL_STMT, t_sqlp_box_id_upcase ("DB.DBA.CLR_CREATE_LIBRARY"),
		 t_list (4, $5, $3, $7, $6));
	   }
        ;

create_assembly
	: CREATE ASSEMBLY_L q_table_name FROM scalar_exp opt_with_permission_set opt_with_autoregister
	   {
	     $$ = (ST*) t_list (3, CALL_STMT, t_sqlp_box_id_upcase ("DB.DBA.CLR_CREATE_ASSEMBLY"),
		 t_list (4, $5, $3, $7, $6));
	   }
        ;

drop_library
	: DROP LIBRARY_L q_table_name
	   {
	     $$ = (ST*) t_list (3, CALL_STMT, t_sqlp_box_id_upcase ("DB.DBA.CLR_DROP_LIBRARY"),
		 t_list (1, $3));
	   }
        ;

drop_assembly
	: DROP ASSEMBLY_L q_table_name
	   {
	     $$ = (ST*) t_list (3, CALL_STMT, t_sqlp_box_id_upcase ("DB.DBA.CLR_DROP_LIBRARY"),
		 t_list (1, $3));
	   }
        ;


/*Partitioning and cluster */


col_partition
	: INTEGER { $$ = t_listst (5, NULL, NULL, (ptrlong)CP_INT, t_box_num (0xffff), NULL); }
	| INTEGER '(' INTNUM ')' { $$ = t_listst (5, NULL, NULL, (ptrlong)CP_INT, $3, NULL); }
	| BIGINT { $$ = t_listst (5, NULL, NULL, (ptrlong)CP_INT, t_box_num (0xffff), NULL); }
	| BIGINT '(' INTNUM ')' { $$ = t_listst (5, NULL, NULL, (ptrlong)CP_INT, $3, NULL); }
	| VARCHAR  { $$ = t_listst (5, NULL, NULL, (ptrlong)CP_WORD, NULL, t_box_num (0xffff)); }
	| VARCHAR '(' INTNUM ',' INTNUM ')'  { $$ = t_listst (5, NULL, NULL, (ptrlong)CP_WORD, $3, $5); }
	| VARCHAR '(' '-' INTNUM ',' INTNUM ')'  { $$ = t_listst (5, NULL, NULL, (ptrlong)CP_WORD, t_box_num (- unbox ($4)), $6); }
	;


host
	: NAME { $$ = $1; if (!cl_name_to_host ($1)) yyerror (scanner,"undefined host name in cluster def"); }
	;

host_list
	: host { $$ = t_CONS ($1, NULL); }
	| host_list ',' host { $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

range
	: '(' INTNUM ',' INTNUM ')' { $$ = t_listbox (2, $2, $4); }
	;

range_list
	: range { $$ = t_CONS ($1, NULL); }
	| range_list ',' range { $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;


host_group
	: GROUP '(' host_list ')' { $$ = t_listst (3, NULL, t_list_to_array ($3), NULL); }
	| GROUP '(' host_list ')' HAVING range_list { $$ = t_listst (3, NULL, t_list_to_array ($3), t_list_to_array ($6)); }
	;


host_group_list
	: ALL { $$ = cl_all_host_group_list (); }
	| host_group { $$ = t_CONS ($1, NULL); }
	| host_group_list ',' host_group { $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
	;

opt_modulo
	: { $$ = NULL; }
	| __ELASTIC INTNUM INTNUM { $$ = list (3, OPT_ELASTIC, $2, $3); }
	| DEFAULT { $$ = (caddr_t) 1;}
	;

cluster_def
	: CREATE	 CLUSTER NAME opt_modulo host_group_list
	{ if (strlen ($3) >= DBS_NAME_MAX_LEN) yyerror (scanner,"cluster name too long");
	  $$ = t_listst (4, CLUSTER_DEF, t_box_string ($3), $4, t_list_to_array ($5)); }
	;

col_part_commalist
	: NAME col_partition { $$ = t_CONS ($2, NULL); $2->_.col_part.col = $1; }
	| col_part_list ',' NAME col_partition { $4->_.col_part.col = $3; $$ = t_NCONC ($1, $4);}
	;

col_part_list
	: /* empty */ { $$ = NULL;}
	| '(' col_part_commalist ')' { $$ = $2; }
	;
opt_cluster
	: { $$ = t_sym_string  (sqlp_default_cluster ()); }
	| CLUSTER  NAME { $$ = $2; }
	;


partition_def
	: ALTER INDEX NAME ON q_table_name PARTITION opt_cluster col_part_list
{ $$ = t_listst (5, PARTITION_DEF,  $5, $3, $7, t_list_to_array ($8)); }
	;


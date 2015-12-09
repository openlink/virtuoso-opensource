/*
 *  sqlparext.h
 *
 *  $Id$
 *
 *  SQL Parse Tree defines
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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

#ifndef _SQLPAREXT_H
#define _SQLPAREXT_H


/* SQL Tree Subtypes */


/* Binary Operations */

#define BOP_NOT			(ptrlong)1

#define BOP_OR			(ptrlong)3
#define BOP_AND			(ptrlong)4
#define BOP_PLUS		(ptrlong)5
#define BOP_MINUS		(ptrlong)6
#define BOP_TIMES		(ptrlong)7
#define BOP_DIV			(ptrlong)8
#define BOP_EQ			(ptrlong)9
#define BOP_NEQ			(ptrlong)10
#define BOP_LT			(ptrlong)11
#define BOP_LTE			(ptrlong)12
#define BOP_GT			(ptrlong)13
#define BOP_GTE			(ptrlong)14
#define BOP_LIKE		(ptrlong)15
#define BOP_NULL		(ptrlong)16
#define BOP_SAME		(ptrlong)17
#define BOP_NSAME		(ptrlong)18

#define BOP_AS			(ptrlong)21
#define BOP_IN_ATOM		(ptrlong)22
#define BOP_MOD			(ptrlong)23

#define BOP_MIN			BOP_NOT
#define BOP_MAX			BOP_MOD

/* subquery predicates */

#define ANY_PRED		(ptrlong)30
#define ALL_PRED		(ptrlong)31
#define SOME_PRED		(ptrlong)32
#define ONE_PRED		(ptrlong)33
#define EXISTS_PRED		(ptrlong)34
#define IN_SUBQ_PRED		(ptrlong)35
#define SUBQ_F_NOT_IN 1 /*marks not in of subq in the subq.flags */

#define SUBQ_PRED_MIN		ANY_PRED
#define SUBQ_PRED_MAX		IN_SUBQ_PRED

#define SCALAR_SUBQ		(ptrlong)36
#define ARRAY_REF		(ptrlong)40
#define FUN_REF			(ptrlong)41

#define SELECT_STMT		(ptrlong)100
#define UPDATE_SRC		(ptrlong)101
#define UPDATE_POS		(ptrlong)102
#define DELETE_SRC		(ptrlong)103
#define DELETE_POS		(ptrlong)104
#define PARAM_WITH_IND		(ptrlong)105
#define TABLE_EXP		(ptrlong)106
#define TABLE_REF		(ptrlong)107
#define TABLE_REF_RANGE		(ptrlong)108
#define PARAM_REF		(ptrlong)109
#define INSERT_STMT		(ptrlong)110
#define INSERT_VALUES		(ptrlong)111
#define JOINED_TABLE		(ptrlong)112
#define UNION_ST		(ptrlong)113
#define UNION_ALL_ST		(ptrlong)114
#define DERIVED_TABLE		(ptrlong)115
#define JC_USING		(ptrlong)116
#define EXCEPT_ST		(ptrlong)117
#define EXCEPT_ALL_ST		(ptrlong)118
#define INTERSECT_ST		(ptrlong)119
#define INTERSECT_ALL_ST	(ptrlong)120
#define PROC_TABLE		(ptrlong)121
#define SELECT_TOP		(ptrlong)122
#define SELECT_BREAKUP 		(ptrlong)123

#define TABLE_DOTTED		(ptrlong)200
#define COL_DOTTED		(ptrlong)201
#define QUOTE			(ptrlong)202
#define COMMA_EXP		(ptrlong)203

#define STAR			(caddr_t) 1L

#define OJ_LEFT			(ptrlong)1
#define OJ_FULL			(ptrlong)2
#define J_INNER			(ptrlong)3
#define J_CROSS			(ptrlong)4
#define OJ_RIGHT		(ptrlong)5

/* AMMSC */
#define AMMSC_NONE		(ptrlong)0
#define AMMSC_AVG		(ptrlong)1
#define AMMSC_MIN		(ptrlong)2
#define AMMSC_MAX		(ptrlong)3
#define AMMSC_COUNT		(ptrlong)4
#define AMMSC_SUM		(ptrlong)5
#define AMMSC_COUNTSUM		(ptrlong)6
#define AMMSC_USER		(ptrlong)7
#define AMMSC_ONE (long)8  /* return of scalar subq in vectored exec, align set no to calling outside subq  sets */

#define ORDER_BY		(ptrlong)111

#define TABLE_DEF		(ptrlong)500
#define INDEX_DEF		(ptrlong)501
#define INDEX_DROP		(ptrlong)502
#define INDEX_REBUILD		(ptrlong)503
#define TABLE_DROP		(ptrlong)504
#define TABLE_UNDER		(ptrlong)505
#define ADD_COLUMN		(ptrlong)506
#define TABLE_RENAME		(ptrlong)507
#define SCHEMA_ELEMENT_LIST	(ptrlong)508
#define MODIFY_COLUMN		(ptrlong)509
#define DDL_NONE (ptrlong)523
#define CO_IDENTITY		(ptrlong)510
#define VIEW_DEF		(ptrlong)511
#define FOREIGN_KEY		(ptrlong)512
#define CHECK_CONSTR		(ptrlong)513
#define COL_DEFAULT		(ptrlong)514
#define COL_NOT_NULL		(ptrlong)515
#define DROP_COL		(ptrlong)516
#define COL_COLLATE		(ptrlong)517
#define COL_XML_ID		(ptrlong)518
#define UNIQUE_DEF		(ptrlong)519
#define CO_ID_START		(ptrlong)520
#define CO_ID_INCREMENT_BY	(ptrlong)521
#define CHECK_XMLSCHEMA_CONSTR	(ptrlong)522
#define CO_COMPRESS ((ptrlong) 523)
#define CLUSTER_DEF ((ptrlong) 524)
#define PARTITION_DEF ((ptrlong) 525)
#define COLUMN_GROUP (ptrlong)526


/* Procedures */

#define COMPOUND_STMT		(ptrlong)600
#define LOCAL_VAR		(ptrlong)603
#define CURSOR_DEF		(ptrlong)604
#define ASG_STMT		(ptrlong)605
#define IF_STMT			(ptrlong)606
#define GOTO_STMT		(ptrlong)607
#define WHILE_STMT		(ptrlong)608
#define CALL_STMT		(ptrlong)609
#define RETURN_STMT		(ptrlong)610
#define OPEN_STMT		(ptrlong)611
#define FETCH_STMT		(ptrlong)612
#define CLOSE_STMT		(ptrlong)613
#define COND_CLAUSE		(ptrlong)614
#define ROUTINE_DECL		(ptrlong)615
#define VARIABLE_DECL		(ptrlong)616
#define HANDLER_DECL		(ptrlong)617
#define LABELED_STMT		(ptrlong)618
#define NULL_STMT		(ptrlong)619
#define TRIGGER_DEF		(ptrlong)620
#define OLD_ALIAS		(ptrlong)621
#define KWD_PARAM		(ptrlong)629
#define MODULE_DECL		(ptrlong)630
#define BREAKPOINT_STMT		(ptrlong)631
#define USER_AGGREGATE_DECL	(ptrlong)632
#define FOR_VEC_STMT (ptrlong)635
#define VECT_DECL ((ptrlong)636)
#define NOT_VEC_STMT ((ptrlong)637)
#define SIMPLE_CASE		(ptrlong)622
#define SEARCHED_CASE		(ptrlong)623
#define WHEN_CLAUSE		(ptrlong)624
#define ELSE_CLAUSE		(ptrlong)625
#define COALESCE_EXP		(ptrlong)626
#define NEW_ALIAS		(ptrlong)627
#define REMOTE_ROUTINE_DECL	(ptrlong)628
#define PROC_COST (ptrlong)633

#define IN_MODE			(ptrlong)1
#define OUT_MODE		(ptrlong)2
#define INOUT_MODE		(ptrlong)3

#define PREFETCH_OPT		(ptrlong)1
#define EXCLUSIVE_OPT		(ptrlong)2


/* Users */

#define GRANT_STMT		(ptrlong)700
#define REVOKE_STMT		(ptrlong)701
#define CREATE_USER_STMT	(ptrlong)702
#define DELETE_USER_STMT	(ptrlong)703
#define SET_PASS_STMT		(ptrlong)704
#define SET_GROUP_STMT		(ptrlong)705
#define ADD_GROUP_STMT		(ptrlong)706
#define DELETE_GROUP_STMT	(ptrlong)707
#define GRANT_ROLE_STMT		(ptrlong)708
#define REVOKE_ROLE_STMT	(ptrlong)709
#define CREATE_ROLE_STMT	(ptrlong)710
#define DROP_ROLE_STMT		(ptrlong)711

#define XML_VIEW		(ptrlong)800
#define XML_COL		(ptrlong)801

/* types */
#define UDT_DEF			(ptrlong)900
#define UDT_MEMBER		(ptrlong)901
#define UDT_EXT			(ptrlong)902
#define UDT_FINAL		(ptrlong)903
#define UDT_REF			(ptrlong)904
#define UDT_METHOD		(ptrlong)905
#define UDT_METHOD_DEF		(ptrlong)906
#define UDT_METHOD_DECL		(ptrlong)907
#define UDT_REFCAST		(ptrlong)908
#define UDT_DROP		(ptrlong)909
#define UDT_VAR_EXT		(ptrlong)910
#define UDT_SOAP		(ptrlong)911
#define UDT_UNRESTRICTED	(ptrlong)912

#define UDT_ALTER		(ptrlong)920
#define UDT_MEMBER_ADD		(ptrlong)921
#define UDT_MEMBER_DROP		(ptrlong)922
#define UDT_METHOD_ADD		(ptrlong)923
#define UDT_METHOD_DROP		(ptrlong)924

#define CREATE_TABLE_AS		(ptrlong)925

#define UDT_METHOD_INSTANCE	(ptrlong)0
#define UDT_METHOD_STATIC	(ptrlong)1
#define UDT_METHOD_CONSTRUCTOR	(ptrlong)2

#define UDT_LANG_NONE		0
#define UDT_LANG_SQL		1
#define UDT_LANG_JAVA		2
#define UDT_LANG_C		3
#define UDT_LANG_CLR		4
#define UDT_N_LANGS		UDT_LANG_CLR + 1


#define XML_COL_ATTR	(ptrlong) 0x00
#define XML_COL_ELEMENT	(ptrlong) 0x01
#define XML_COL_HIDE	(ptrlong) 0x02
#define XML_COL_XML	(ptrlong) 0x03
#define XML_COL_XMLTEXT	(ptrlong) 0x04
#define XML_COL_CDATA	(ptrlong) 0x05
#define XML_COL_ID	(ptrlong) 0x10
#define XML_COL_IDREF	(ptrlong) 0x20
#define XML_COL_IDREFS	(ptrlong) 0x30
#define XML_COL__FORMAT	(ptrlong) 0x0F
#define XML_COL__SCHEMA	(ptrlong) 0xF0
#define XML_COL_DEFAULT	XML_COL_ATTR

/* Bitmasks for columns of XML views
Note: bitwise OR of all these masks should be less than SMALLEST_POSSIBLE_POINTER */

#define XV_XC_SUBELEMENT	(ptrlong) 0x010
#define XV_XC_ATTRIBUTE		(ptrlong) 0x020
#define XV_XC_DESCENDANT	(ptrlong) 0x040
#define XV_XC_PARENT_OF_JOIN	(ptrlong) 0x100
#define XV_XC_CHILD_OF_JOIN	(ptrlong) 0x200

/* TIMESTAMP_FUNC */

#define SQL_FN_TIMESTAMPADD	(ptrlong)1
#define SQL_FN_TIMESTAMPDIFF	(ptrlong)2


/* SQL_TSI */

#define SQL_TSI_SECOND		(ptrlong)1
#define SQL_TSI_MINUTE		(ptrlong)2
#define SQL_TSI_HOUR		(ptrlong)3
#define SQL_TSI_DAY		(ptrlong)4
#define SQL_TSI_MONTH		(ptrlong)5
#define SQL_TSI_YEAR		(ptrlong)6


/* SQL_EXTRACT_PERIOD */

#define SQL_EXT_P_SECOND	(ptrlong)1
#define SQL_EXT_P_MINUTE	(ptrlong)2
#define SQL_EXT_P_HOUR		(ptrlong)3
#define SQL_EXT_P_DAY		(ptrlong)4
#define SQL_EXT_P_MONTH		(ptrlong)5
#define SQL_EXT_P_YEAR		(ptrlong)6


/* options */
#define OPT_ORDER  ((ptrlong) 900)
#define OPT_INDEX_ORDER ((ptrlong)968)
#define OPT_JOIN  ((ptrlong) 901)
#define OPT_INDEX ((ptrlong) 902)
#define OPT_SPARQL ((ptrlong) 907)
#define OPT_NO_CLUSTER ((ptrlong) 930)
#define OPT_INTO ((ptrlong) 931)
#define OPT_INS_FETCH ((ptrlong)933)
#define OPT_VECTORED ((ptrlong)934)
#define OPT_NOT_VECTORED ((ptrlong)935)
#define OPT_NO_IDENTITY ((ptrlong)936)
#define OPT_ELASTIC ((ptrlong)937)
#define OPT_NO_TRIGGER ((ptrlong)938)
#define OPT_PARTITION ((ptrlong)939)
#define OPT_PARALLEL ((ptrlong)947)
#define OPT_FROM_FILE ((ptrlong)953)
#define OPT_FILE_START  ((ptrlong)954)
#define OPT_FILE_END  ((ptrlong)955)

#define OPT_HASH ((ptrlong) 903)
#define OPT_INTERSECT ((ptrlong) 1015)
#define OPT_LOOP ((ptrlong) 904)
#define OPT_RANDOM_FETCH ((ptrlong) 905)
#define OPT_SUBQ_LOOP (ptrlong) 910
#define SUBQ_NO_LOOP 2
#define SUBQ_LOOP 1
#define OPT_VACUUM (ptrlong)913
#define OPT_RDF_INFERENCE ((ptrlong)1014)
#define OPT_SAME_AS ((ptrlong) 1016)
#define OPT_ARRAY ((ptrlong) 1017)
#define OPT_ANY_ORDER (ptrlong)1018
#define OPT_INDEX_ONLY (ptrlong)932
#define OPT_HASH_SET ((ptrlong)940)
#define OPT_HASH_PARTITION ((ptrlong)941)
#define OPT_HASH_REPLICATION ((ptrlong)942)
#define OPT_ISOLATION ((ptrlong)943)
#define OPT_CHECK ((ptrlong)944)
#define OPT_PART_GBY ((ptrlong)945)
#define OPT_NO_PART_GBY ((ptrlong)946)
#define OPT_NO_LOCK ((ptrlong)956)
#define OPT_TRIGGER ((ptrlong)957)

#define OPT_EST_TIME ((ptrlong)950)
#define OPT_EST_SIZE ((ptrlong)951)

/* GROUPING SETS */
#define GROUPING_FUNC	"__grouping"
#define GROUPING_SET_FUNC   "__grouping_set_bitmap"
#define MAX_GROUPBY_ELS	BITS_IN_LONG

/* Parse tree */

#define ST		struct sql_tree_s

#define listst		(ST *) list
#define t_listst	(ST *) t_list
#define t_listbox	(caddr_t) t_list
#define t_list_to_array_box	(caddr_t) t_list_to_array


typedef struct sql_tree_s
  {
    ptrlong type;
    union
      {
	struct
	  {
	    ST *	top;
	    caddr_t *	selection;
	    caddr_t *	target;
	    ST *	table_exp;
	  } select_stmt;
	struct
	{
	  ptrlong	all_distinct;
	  ST *	exp;
	  ST *	skip_exp;
	  ptrlong	percent;
	  ptrlong	ties;
	  ST *		trans;
	} top;
	struct
	  {
	    ST *	left;
	    ST *	subq;
	    ptrlong	cmp_op;
	    ptrlong	flags;
	    ST *	org; /* if rewritten, this is the original syntax */
	  } subq;
	struct
	  {
	    ST **	from;
	    ST *	where;
	    ST **	group_by;
	    ST *	having;
	    ST **	order_by;
	    ptrlong	flags;
	    caddr_t *	opts;
	    ST ***	group_by_full;
	  } table_exp;
#if 0
	struct
	  {
	    caddr_t *	exp_list;
	    ptrlong	all_distinct;
	  } selection;
#endif
	struct
	  {
	    ST *	left;
	    ST *	right;
	    caddr_t	more;	/* used by BETWEEN, ANY/ALL etc. */
	    caddr_t	serial; /* for dist identical constant pred trees in order to avoid inappropriate common predicate elimination in sqlo_df */
	  } bin_exp;
	struct
	  {
	    ST *	left;
	    ST *	 right;
	    caddr_t *	cols;
	    ptrlong	is_best;
	  } set_exp;
	struct
	  {
	    /* layout like bin_exp */
	    ST *	left;
	    ST *	right;
	    caddr_t	name;
	    ST *	type;
	    ST *	xml_col;
	  } as_exp;
	struct
	  {
	    caddr_t	value;
	  } literal;
	struct
	  {
	    caddr_t	name;
	  } param;
	struct
	  {
	    caddr_t	fn_name;
	    ptrlong	fn_code;
	    caddr_t	user_aggr_addr;
	    ptrlong	all_distinct;	/*!< 0 if aggregate ALL, 1 if aggregate DISTINCT */
	    ST *	fn_arg;		/*!< Single argument */
	    ST **	fn_arglist;	/*!< Array of arguments (for user aggregates) */
	  } fn_ref;
	struct
	  {
	    ST *	table;
	    ST **	cols;
	    ST **	vals;
	    ST *	table_exp;
	  } update_src;
	struct
	  {
	    ST *	table;
	    ST **	cols;
	    ST *	vals;
	    ptrlong	mode;
	    caddr_t	key;
	    caddr_t *	opts;
	  } insert;
	struct
	  {
	    ST **	vals;
	  } ins_vals;
	struct
	  {
	    ST *	table_exp;
	  } delete_src;
	struct
	  {
	    ST *	table;
	    ST **	cols;
	    ST **	vals;
	    caddr_t	cursor;
	    caddr_t *	opts;
	  } update_pos;
	struct
	  {
	    caddr_t	cursor;
	    ST *	table;
	    caddr_t *	opts;
	  } delete_pos;
	struct
	  {
	    caddr_t	name;
	    caddr_t	prefix;
	    caddr_t	u_id;
	    caddr_t	g_id;
	    caddr_t *	opts;
	  } table;
	struct
	  {
	    ST *	table;
	    caddr_t	range;
	  } table_ref;
	struct
	  {
	    ptrlong	is_natural;
	    ptrlong	type;
	    ST *	left;
	    ST *	right;
	    ST *	cond;
	  } join;
	struct
	  {
	    caddr_t *	cols;
	  } usage /*using*/;	/* "using" is a keyword! */
	struct
	  {
	    caddr_t	prefix;
	    caddr_t	name;
	  } col_ref;
	struct
	  {
	    caddr_t	arg_1;
	    caddr_t	arg_2;
	    caddr_t	arg_3;
	  } op;
	struct
	  {
	    char *	name;
	    ST **	opts;
	  } col_del;
	struct
	  {
	    char *	name;
	    ST **	cols;
	    ptrlong	flags;
	  } table_def;
	struct {
	  caddr_t	name;
	  caddr_t  *	inx_opts;
	  caddr_t *	cols;
	} col_group;
	struct
	  {
	    caddr_t	name;
	    ST *	exp;
	    caddr_t	text;	/* source text, put intp SYS_VIEWS */
	    ptrlong	check;
	  } view_def;
	struct
	  {
	    caddr_t *	fk_cols;
	    char *	pk_tb;
	    caddr_t *	pk_cols;
	    ptrlong	match;
	    ptrlong	u_rule;
	    ptrlong	d_rule;
	    char *	fk_name;
	    ptrlong	fk_state;
	  } fkey;
	struct {
	    caddr_t	proc;
	    ST **	params;
	    ST **	cols;
	    caddr_t *	opts;
	  } proc_table;
	struct
	  {
	    char *	name;
	    char *	table;
	    caddr_t *	cols;
	    caddr_t *	opts;
	  } index;
	struct
	  {
	    char *	table;
	  } under;
	struct
	  {
	    caddr_t	name;
	    ST **	params;
	    ST *	ret_type;
	    caddr_t	init_name;
	    caddr_t	acc_name;
	    caddr_t	final_name;
	    caddr_t	merge_name;
	    ptrlong	need_order;
	  } user_aggregate;
	struct
	  {
	    ptrlong	r_type;
	    caddr_t	name;
	    ST **	params;
	    ST *	ret;
	    ST *	body;
	    caddr_t 	alt_ret;
	    caddr_t 	udt_mtd_info;
	  } routine;
	struct
	  {
	    caddr_t	name;
	    ST **	procs;
	  } module;
	struct
	  {
	    caddr_t	name;
	    ptrlong	time;
	    caddr_t *	event;
	    caddr_t	table;
	    caddr_t     order;
	    ST **	old_alias;
	    ST *	body;
	  } trigger;
	struct
	  {
	    ptrlong	mode;
	    ST *	name;
	    ST *	type;
	    caddr_t	deflt;
	    caddr_t 	alt_type;
	  } var;			/* for proc parameters and local vars */
	struct
	  {
	    caddr_t	name;
	    ST *	spec;
	    ptrlong	type;
	    ST **	params;
	  } cr_def;
	struct
	  {
	    ST *	cond;
	    ST *	then;
	  } elseif;
	struct
	  {
	    ST **	elif_list;
	    ST *	else_clause;
	  } if_stmt;
	struct
	  {
	    caddr_t	name;
	    ST **	params;
	    ST *	ret_param;
	    caddr_t	type_name; /* for static methods */
	  } call;
	struct
	  {
	    long	type;
	    caddr_t *	sql_states;
	    ST *	code;
	  } handler;
	struct
	  {
	    ST *	cond;
	    ST *	body;
	  } while_stmt;
	struct
	  {
	    caddr_t	name;
	    ST **	options;
	    ST **	params;
	  } open_stmt;
	struct
	  {
	    ST *	arr;
	    ST *	inx;
	  } aref;
	struct
	  {
	    ptrlong	op;
	    caddr_t *	cols;
	  } priv_op;
	struct
	  {
	    ST **	ops;
	    ST *	table;
	    caddr_t *	grantees;
	  } grant;
	struct
	  {
	    ST *	col;
	    ptrlong	order;
	    ST *	gsopt;
	  } o_spec;
	struct
	  {
	    ST **	exps;
	  } comma_exp;
	struct
	  {
	    ptrlong	r_type;
	    caddr_t	remote_name;
	    ST **	params;
	    ST *	ret;
	    caddr_t	local_name;
	    caddr_t	dsn;
	    caddr_t *   alt_ret;
	  } remote_proc;
	struct
	  {
	    caddr_t	element;
	    caddr_t	tag;
	    caddr_t	attr_name;
	    ptrlong	directive;
	  } xml_col;
	struct
	  {
	    ST *	cursor;
	    ST **	targets;
	    caddr_t	scroll_type;
	    ST *	row_count;
	  } fetch;
	struct
	  {
	    ST **	body;
	    caddr_t	line_no;
	    caddr_t	l_line_no;
	    caddr_t	file_name;
	    caddr_t	skip;
	  }
	compound;
	struct {
	  caddr_t 	name;
	  caddr_t *	options;
	  ST **		hosts;
	} cluster;
	struct {
	  caddr_t **	hosts;
	  ST **	ranges;
	} host_group;
	struct {
	  caddr_t	table;
	  caddr_t	key;
	  caddr_t	cluster;
	  ST **	cols;
	} part_def;
	struct {
	  caddr_t	col;
	  ptrlong	type;
	  caddr_t	arg;
	  caddr_t	arg2;
	} col_part;
	struct {
	  ST *	min;
	  ST *	max;
	  ptrlong *	in;
	  ptrlong *	out;
	  ptrlong	end_flag;
	  caddr_t	final_as;
	  ptrlong	distinct;
	  ptrlong	no_cycles;
	  ptrlong	cycles_only;
	  ptrlong	exists;
	  ptrlong	no_order;
	  ptrlong	shortest_only;
	  ptrlong	direction;
	} trans;
	struct {
	  ptrlong		mode;
	  ST *		name;
	  ST *		type;
	  ST *	exp;
	} vect_decl;
	struct {
	  ST **	decl;
	  ST *	body;
	  ptrlong	modify;
	} for_vec;
    } _;
  } sql_tree_t;


#define TRANS_ANY 0
#define TRANS_LR 1
#define TRANS_RL 2
#define TRANS_LRRL 3


#define SEL_TOP(st) \
  (IS_BOX_POINTER (st->_.select_stmt.top) ? st->_.select_stmt.top : NULL)


#define SEL_IS_DISTINCT(st) \
  (!IS_BOX_POINTER (st->_.select_stmt.top) ? (ptrlong) st->_.select_stmt.top == 1 : st->_.select_stmt.top->_.top.all_distinct)


#define SEL_IS_TRANS(st) \
  (IS_BOX_POINTER (st->_.select_stmt.top) && box_length ((caddr_t)st->_.select_stmt.top) > (long)&((ST*)0)->_.top.trans && st->_.select_stmt.top->_.top.trans)


#define SEL_SET_DISTINCT(st, f) \
{ \
  if (!IS_BOX_POINTER (st->_.select_stmt.top))  st->_.select_stmt.top = (ST*) f; \
  else st->_.select_stmt.top->_.top.all_distinct = f; \
}

extern long sqlp_bin_op_serial;

#define IS_ARITM_BOP(opq) \
	((opq) == BOP_PLUS || \
	 (opq) == BOP_MINUS || \
	 (opq) == BOP_TIMES || \
	 (opq) == BOP_DIV)

#define BIN_OP(target,opq,l,r) \
  if (IS_ARITM_BOP (opq)) \
    { \
      target = (ST *) t_alloc_box (sizeof (sql_tree_t), DV_ARRAY_OF_POINTER); \
      memset (target, 0, sizeof (sql_tree_t)); \
      (target)->type = opq; \
      (target)->_.bin_exp.left = l; \
      (target)->_.bin_exp.right = r; \
    } \
  else \
    { \
      target = (ST *) t_alloc_box (sizeof (sql_tree_t), DV_ARRAY_OF_POINTER); \
      memset (target, 0, sizeof (sql_tree_t)); \
      (target)->type = opq; \
      (target)->_.bin_exp.left = l; \
      (target)->_.bin_exp.right = r; \
      (target)->_.bin_exp.serial = t_box_num (sqlp_bin_op_serial++); \
    }

#define UN_OP(target,opq,l) \
  target = (ST *) t_alloc_box (sizeof (sql_tree_t), DV_ARRAY_OF_POINTER); \
  memset (target, 0, sizeof (sql_tree_t)); \
  target->type = opq; \
  target->_.bin_exp.left = l;

#define FN_REF_1(target, n, all_dist, argp) \
  target = (sql_tree_t *) t_alloc_box (sizeof (sql_tree_t), DV_ARRAY_OF_POINTER); \
  memset (target, 0, sizeof (sql_tree_t)); \
  target->type = FUN_REF; \
  target->_.fn_ref.all_distinct = all_dist; \
  target->_.fn_ref.fn_arg = argp; \
  target->_.fn_ref.fn_code = n; \
  sqlp_complete_fun_ref (target);

#define FN_REF_2(target, n, all_dist, argp) \
  if (n == AMMSC_AVG) \
    { \
      ST * t1, * t2; \
      FN_REF_1 (t1, AMMSC_SUM, all_dist, (ST *) t_box_copy_tree ((caddr_t) argp)); \
      FN_REF_1 (t2, AMMSC_COUNT, all_dist, argp); \
      BIN_OP (target, BOP_DIV, t1, t2); \
    } \
  else \
    FN_REF_1 (target, n, all_dist, argp);

#define FN_REF(target, n, all_dist, argp) \
  if (ST_COLUMN (((ST *) (argp)), COL_DOTTED) && ((ST *) (argp))->_.col_ref.prefix == NULL && ((ST *) (argp))->_.col_ref.name == STAR) \
    { \
      FN_REF_2 (target, n, all_dist, NULL); \
    } \
  else \
    { \
      FN_REF_2 (target, n, all_dist, argp); \
    }



#define NEGATE(res, p) \
  BIN_OP (res, BOP_NOT, p, NULL)

#define SUBQ_PRED(pred, left, subq, cmp_, flags) \
  (ST *) t_list (6, \
		 (ptrlong) pred, (caddr_t) left, (ST *) subq, (ptrlong) cmp_, (ptrlong) flags, NULL)


#define ARRAYP(a) \
  (IS_BOX_POINTER(a) && DV_ARRAY_OF_POINTER == box_tag((caddr_t) a))

#define SYMBOLP(a) \
  (IS_BOX_POINTER(a) && DV_SYMBOL == box_tag((caddr_t) a))

#define LITERAL_P(a) \
  (! IS_BOX_POINTER (a) \
   || DV_SHORT_STRING == box_tag((caddr_t) a) \
   || DV_LONG_STRING == box_tag((caddr_t) a) \
   || DV_WIDE == box_tag((caddr_t) a) \
   || DV_LONG_WIDE == box_tag((caddr_t) a) \
   || DV_LONG_INT == box_tag((caddr_t) a) \
   || DV_DB_NULL == box_tag((caddr_t) a) \
   || DV_SINGLE_FLOAT == box_tag((caddr_t) a) \
   || DV_NUMERIC == box_tag((caddr_t) a) \
   || DV_DOUBLE_FLOAT == box_tag((caddr_t) a) \
   || DV_BIN == box_tag((caddr_t) a) \
   || DV_UNAME == box_tag((caddr_t) a) \
   || DV_IRI_ID == box_tag((caddr_t) a) \
   || DV_RDF == box_tag((caddr_t) a) \
   || DV_DATETIME == box_tag((caddr_t) a) \
   || DV_GEO == box_tag((caddr_t) a) \
   || DV_XPATH_QUERY == box_tag((caddr_t) a) )

#define ST_P(s, tp) \
  (ARRAYP (s) && BOX_ELEMENTS (s) > 0 && (s)->type == tp)

#define ST_COLUMN(s, tp) \
  (ARRAYP (s) && BOX_ELEMENTS (s) == 3 && (s)->type == COL_DOTTED && \
   	( IS_STRING_ALIGN_DTP (DV_TYPE_OF (((caddr_t *)(s))[2])) || STAR == ((caddr_t *)(s))[2] )  && \
   	( IS_STRING_ALIGN_DTP (DV_TYPE_OF (((caddr_t *)(s))[1])) || NULL == ((caddr_t *)(s))[1]) )

#define BIN_EXP_P(q) \
  (ARRAYP (q) && (q)->type >= BOP_MIN && (q)->type <= BOP_MAX)

#define SUBQ_P(q) \
  (ARRAYP (q) && (q)->type >= SUBQ_PRED_MIN && (q)->type <= SUBQ_PRED_MAX)


#ifndef NDEBUG
# define YYDEBUG 1
#endif


#define NULLCONST	dk_alloc_box (0, DV_DB_NULL)

#define t_NULLCONST	t_alloc_box (0, DV_DB_NULL)

#define t_dk_set_append_1(res,item) \
  *(res) = t_NCONC (*(res), t_CONS (item, NULL))

#define t_NCONCF1(l, n)	(l = t_NCONC (l, t_CONS (n, NULL)))

/* table_exp.flags values */
#define TEXP_LOCK(st) (st->_.table_exp.flags & 0x7)

#define XR_ROW 16
#define XR_AUTO 32
#define XR_EXPLICIT 64
#define XR_ELEMENT 128


/* table layout */
#define T_ROW 0
#define T_COLUMN 1
#define T_DISTINCT_COLUMNS 2


#endif

/*
 *  sqlo.h
 *
 *  $Id$
 *
 *  sql opt graph
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

#ifndef _SQLO_H
#define _SQLO_H

typedef struct df_elt_s df_elt_t;
typedef struct sqlo_s sqlo_t;
typedef struct locus_s locus_t;
#ifdef __cplusplus
typedef struct remote_ds_s remote_ds_t;
#endif


typedef struct ot_virt_col_s
{
  ST *vc_tree;
  dtp_t vc_dtp;
  int vc_is_out;
} op_virt_col_t;

typedef struct op_table_s
{
  caddr_t		ot_prefix;
  caddr_t	ot_new_prefix;
  dbe_table_t * 	ot_table;
#ifdef __cplusplus
  remote_ds_t *	ot_rds;
#else
  struct remote_ds_t *	ot_rds;
#endif
  ST *	ot_dt;
  ST *	ot_left_sel;
  ST *	ot_join_cond;
  int	ot_is_outer;
  oid_t	ot_u_id;
  oid_t	ot_g_id;
  dk_set_t		ot_table_refd_cols; /* if the ot is a table, which cols are refd. Use for knowing if index only is possible in costing */
  dk_set_t 	ot_fun_refs;
  dk_set_t	ot_exps;
  dk_set_t	ot_preds;
  dk_set_t	ot_from_ots;
  dk_set_t 		ot_join_preds;  /* when placing a dt, those preds of outer where which get inside the dt */
  dk_set_t 		ot_imported_preds;
  struct op_table_s *	ot_super;
  dk_set_t	ot_contained_ots;
  struct op_table_s *	ot_group_ot;
  dk_set_t	ot_from_dfes;
  int	ot_is_top;
  int	ot_is_top_ties;
  df_elt_t *	ot_dfe;
  df_elt_t *	ot_work_dfe;
  char 	ot_is_contradiction;
  char	ot_is_group_dummy;	/* fictive table corresponding to a group by's results. fun refs depend alone on this and this depends on all other tables */
  dk_set_t	ot_oby_ots;	/* for a dt, the component ots in the oby order */
  dk_set_t 	ot_order_cols; /* for a table in an ordered from, the subset of the oby pertaining to this table */
  char 	ot_order_dir;
  df_elt_t *	ot_oby_dfe;	/* for a dt, the dfe for the sorted oby */
  df_elt_t *	ot_group_dfe;
  locus_t *	ot_locus;

  dk_set_t	ot_virtual_cols;
  /* XPATH & FT members */
  op_virt_col_t *ot_main_range_out;	/* Only ranges in main text, e.g. for compatibility with existing applications. */
  op_virt_col_t *ot_attr_range_out;	/* Only ranges in attributes */
  int 		ot_text_desc;
  ST           *ot_text_start;
  ST           *ot_text_end;
  ST           *ot_text_score_limit;
  op_virt_col_t **ot_text_offband;
  op_virt_col_t *ot_text_score;
  ST 	       *ot_text;
  ST           *ot_base_uri;
  op_virt_col_t *ot_xpath_value;
  ST *		ot_contains_exp;

  /* hash join */
  setp_node_t * 	ot_hash_filler;
  int		ot_fixed_order;
  caddr_t *	ot_opts;
  int		ot_layouts_tried;
  int		ot_has_cols;
  char 		ot_is_proc_view;

  dk_set_t 	ot_invariant_preds;
  id_hash_t * 	ot_eq_hash; /* eq group of things, use for eq transitivity */
} op_table_t;

typedef struct jt_mark_s
{
  caddr_t jtm_prefix;
  op_table_t *jtm_first_ot;
  op_table_t *jtm_last_ot;
  ST **jtm_tree_ptr;
  ST **jtm_selection;
  ST *jtm_join_cond;
  dk_set_t jtm_where_conds;
} jt_mark_t;


#define OT_ORDER_MIXED 4

#define dk_set(dt) dk_set_t



typedef struct df_inx_op_s 
{
  char		dio_op;
  char		dio_is_join;  /* true if multiple tables, false if just using inx merge on keys of one table */
  dk_set_t	dio_terms;
  dbe_key_t *	dio_key;
  df_elt_t *	dio_table;
  dk_set (df_elt_t*)	dio_given_preds;
  dk_set (df_elt_t *)	dio_col_preds;
} df_inx_op_t;


/* markers for compile time known predicates */
#define DFE_FALSE ((df_elt_t*) -1)
#define DFE_TRUE ((df_elt_t*) NULL)

#define DFE_TABLE 1
#define DFE_PRED_BODY 2
#define DFE_GROUP 4
#define DFE_ORDER 5
#define DFE_DISTINCT 6
#define DFE_DT 8
#define DFE_CALL 9
#define DFE_BOP 10
#define DFE_CONST 11
#define DFE_COLUMN 12
#define DFE_BOP_PRED 13
#define DFE_QEXP 16
#define DFE_asg 17
#define DFE_VALUE_SUBQ 18
#define DFE_FUN_REF 19
#define DFE_EXISTS 20
#define DFE_CONTROL_EXP 21	/* coalesce, case-when */
#define DFE_HEAD 100
#define DFE_TEXT_PRED 101




#define DFE_PLACED 1	/* placed in a scenario */
#define DFE_GEN 2	/* placed in the executable graph */

struct df_elt_s
{
  short	dfe_type;
  char	dfe_is_placed;
  bitf_t	dfe_unit_includes_vdb:1;
  int32		dfe_hash;
  locus_t *	dfe_locus;
  dk_set_t	dfe_remote_locus_refs;
  dk_set_t	locus_content; /* (moved from .sub as refd with any dfe_type) 
				  in a scenario copy, the state of loci at time of copy in subtree rooted here */
  ST *	dfe_tree;
  df_elt_t *	dfe_super;
  sqlo_t *	dfe_sqlo;
  df_elt_t *	dfe_prev;
  df_elt_t * 	dfe_next;
  float	dfe_unit;
  float	dfe_arity;
  dk_set_t	dfe_tables;
  state_slot_t *	dfe_ssl;
  sql_type_t 		dfe_sqt;
  union
  {
    struct {
      op_table_t *	ot;
      dbe_key_t *	key;
      df_inx_op_t *	inx_op;
      dk_set_t 	col_pred_merges;
      dk_set_t	all_preds;
      dk_set_t 	inx_preds;
      dk_set_t	col_preds;
      df_elt_t **	join_test;
      df_elt_t **	after_join_test;
      df_elt_t **	vdb_join_test; /* the part of a remote table's join test that must be done on the vdb */
      dk_set (df_elt_t*)	out_cols;

      bitf_t is_unique:1;
      bitf_t is_arity_sure:4;  /* if unique or comes from inx sample or n distinct.  Value is no of key parts in sample */
      bitf_t is_oby_order:1;
      bitf_t single_locus:1;
      bitf_t is_text_order:1;
      bitf_t text_only:1;
      bitf_t is_xcontains:1;
      bitf_t is_locus_first:1;
      bitf_t is_leaf:1;
      bitf_t hash_role:3;
      /* XPATH & FT members */
      df_elt_t         *text_pred;
      df_elt_t         *xpath_pred;
      data_source_t *	text_node;
      data_source_t *	xpath_node;

      /* hash join */
      df_elt_t *	hash_filler;
      dk_set_t	hash_keys;
      dk_set_t	hash_refs;
      df_elt_t ** hash_filler_after_code;
      float	in_arity;
    } table;
    struct {
      /* dt select body, pred body, value subq */
      op_table_t *	ot; /* if select body, this is the dt ot.  AS aliases here. */
      df_elt_t *	first;
      df_elt_t *	last;
      df_elt_t **	dt_out;  /* internal dfe of the exp of the an outside refd col of a dt */
      dk_set_t	dt_imp_preds; /* preds of enclosing where imported into dt */
      dk_set_t	dt_preds;
      df_elt_t *	generated_dfe;
      df_elt_t **	after_join_test;
      df_elt_t **	vdb_join_test; /* when join preds are not imported into the dt in vdb */
      df_elt_t **	invariant_test;
      ST *		org_in; /* if in subnq, this is the pred that is the left and single col select */
      float 		in_arity;  /* estimate evaluation count of the dt's head node  */
      char	is_locus_first;
      char	is_contradiction;
    } sub;
    struct {
      /* union dt head, or union coming from a table + or */
      op_table_t *	ot;
      int 	op;
      df_elt_t **	terms;
      caddr_t *	corresponding;
      char	is_best;
    } qexp;
    struct {
      dbe_column_t *	col;
      op_virt_col_t *   vc;
    } col;
    struct {
      int 	op;
      df_elt_t *	left;
      df_elt_t* right;
      char 	escape;
    } bin;
    struct {
      int	op;
      caddr_t	func_name;
      df_elt_t *	func_exp;
      df_elt_t **	args;
    } call;
    struct {
      int 	is_linear;
      ST **	specs;
      dk_set_t 	fun_refs;
      dk_set_t	group_cols;
      df_elt_t **	after_test;
      dk_set_t 		having_preds;
      op_table_t *ot;
      ptrlong   top_cnt;
    } setp;
    struct {
      df_elt_t *	table;
    } oj;
    struct {
      df_elt_t **	terms;
    } set;
    struct {
      df_elt_t *	super;
    } head;
    struct {
      int type;
      ST ** args;
      dbe_column_t *col;
      state_slot_t *ssl;
      op_table_t *ot;
      df_elt_t **	after_test;
      dk_set_t		after_preds;
    } text;
    struct {
      df_elt_t ***	terms;
      id_hash_t **	private_elts;
    } control;
  } _;
};



/* table hash_role */
#define HR_NONE 0
#define HR_FILL 1
#define HR_REF 2


/* for table.gb_status.  Less ordered is numerically less. */
#define GB_NON_ORDERED 0
#define GB_ORDERED_NON_UNIQUE 1
#define GB_ORDERED_UNIQUE 2
#define GB_SINGLE 3
#define GB_INITIAL 4

#define MRG_EQ 1
#define MRG_MAX 1
#define MRG_MIN 2



#define TB_NOT_OBY -1


typedef struct sql_var_s
{
  caddr_t 	sv_name;
  ST *	sv_unq_name;
} sql_var_t;



typedef struct sql_scope_s  sql_scope_t;

struct sql_scope_s
{
  dk_set_t 	sco_tables;
  dk_set_t	sco_named_vars;
  sql_scope_t *	sco_super;
  int	sco_fun_refs_allowed;
  sqlo_t *	sco_so;
  dk_set_t 	sco_jts;
  int		sco_has_jt;
};





struct sqlo_s
{
  sql_comp_t *	so_sc; /* enclosing proc comp ctx */
  sqlo_t *	so_super;
  sql_scope_t *	so_scope;
  df_elt_t *	so_dfe;
  int	so_name_ctr;
  dk_set_t 	so_tables; /* all op tables, regardless of nesting */
  op_table_t *	so_this_dt;
  id_hash_t *	so_df_elts;
  id_hash_t *	so_df_private_elts;
  df_elt_t *	so_gen_pt;

  char	so_is_top_and;
  char	so_in_cond_exp;
  dk_set_t	so_placed; /*accumulate new prospective placements here */
  short	so_label_ctr;
  float		so_best_score;
  df_elt_t *	so_best;
  float 	so_top_best_score;
  float	so_dt_input_arity;
  float	so_cost_up_to_dt;
  locus_t *	so_target_locus;
  int		so_locus_ctr;
  remote_table_source_t * 	so_target_rts;
  df_elt_t *	so_copy_root; /* in sqlo_layout_copy, get the locus state into this dt dfe */
  df_elt_t *		so_vdb_top;  /* dummy top dfe for an all pas through top select. Used to reference the selection to bring outside of remote  */
  char 		so_is_rescope; /* if labeling generated subtree leave unresolved col refs as is */
  char		so_place_code_forr_cond;  /* inside cond exp, do not precalculate */
  dk_set_t 	so_hash_fillers;
  char		so_bin_op_is_negate;
  char		so_is_select;
  caddr_t	so_vdb_dml_prefix;
#ifndef NDEBUG
  char		so_dfe_unplace_pass; /* not generate errors in sqlo_dfe_unplace if dfe != sqlo_df ()*/
#endif
  dk_set_t	so_in_list_nodes;
  dk_set_t *	so_inx_int_tried_ret; /* ref to where dfes tried with an inx int go so that the same inx int does not get tried in all permutations */
  uint32	so_last_sample_time; /* used for stopping compilation if longer is elapsed since last sample than the best plan's time */
};


#define L2_APPEND(first, last, elt, pref) \
{ \
  if (!first) \
    { \
      first = elt; \
      last = elt; \
      elt->pref##next = NULL; \
      elt->pref##next = NULL; \
    } \
  else \
    { \
      elt->pref##prev = last; \
      last->pref##next = elt; \
      elt->pref##prev = last; \
      last = elt; \
      elt->pref##next = NULL; \
    } \
}




struct locus_s
{
  char *	loc_name;
  struct remote_ds_s *	loc_rds;
  dk_set (df_elt_t*) 	loc_params;
  dk_set (df_elt_t*) 	loc_results; /* list of df_elt_t */
  dk_set (df_elt_t*)	loc_def_dfes; /* tables, obys, bgys */
  dk_set (op_table_t*)	loc_ots; /* all ots that would be here, incl subq */
  locus_t *	loc_copy_of; /* original locus whose state is copied in this temp scenario copy */
} ;


typedef struct loc_output
{
  locus_t *	lr_locus;
  df_elt_t *	lr_required;
  df_elt_t *	lr_requiring;
} locus_result_t;

/*#define LOC_ANY ((locus_t *)1)*/
#define LOC_LOCAL ((locus_t *)2)



struct sqlo_ot_order_s
{
  op_table_t *	ord_ot;
  char	ord_is_unique;
  char	ord_is_single_dir;
  df_elt_t ** 	ord_cols;
};


int sqlo_oby_exp_cols (sqlo_t * so, ST * dt, ST** oby);

void sqlo_scope (sqlo_t * so, ST ** ptree);
df_elt_t * sqlo_df (sqlo_t * so, ST * tree);
df_elt_t * sqlo_df_virt_col (sqlo_t * so, op_virt_col_t * vc);
op_table_t * sqlo_find_dt (sqlo_t * so, ST * tree);
op_table_t * sqlo_cname_ot (sqlo_t *, char * cname);
op_table_t * sqlo_cname_ot_1 (sqlo_t *, char * cname, int gpf_if_not);
void sqlo_print_layout (sqlo_t * so);
df_elt_t * sqlo_layout_copy (sqlo_t * so, df_elt_t * dfe, df_elt_t * parent);
df_elt_t * sqlo_layout_copy_1 (sqlo_t * so, df_elt_t * dfe, df_elt_t * parent);

void sqlo_dt_unplace (sqlo_t * so, df_elt_t * tb_dfe);
void sqlo_dfe_unplace (sqlo_t * so, df_elt_t * dfe);
float sqlo_score (df_elt_t * dfe, float in_arity);
void sqlo_dfe_print (df_elt_t * dfe, int offset);
#define OFS_INCR 4
df_elt_t * sqlo_layout (sqlo_t * so, op_table_t * ot, int is_top, df_elt_t * super);
df_elt_t * sqlo_place_exp (sqlo_t * so, df_elt_t * super, df_elt_t * dfe);
df_elt_t * dfe_latest (sqlo_t * so, int n_dfes, df_elt_t ** dfes, int default_to_top);
void sqlo_scenario_summary (df_elt_t * dfe, float cost);
int sqlo_try_oby_order (sqlo_t * so, df_elt_t * tb_dfe);
void sqlo_ot_oby_seq (sqlo_t * so, op_table_t * top_ot);
#if 0
void sqlo_try_sorted_oby (sqlo_t * so, op_table_t * from_ot);
#endif
df_elt_t * sqlo_new_dfe (sqlo_t * so, int type, ST * tree);
void sqlo_tb_order (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t col_preds);
int dfe_defines (df_elt_t * defining, df_elt_t * defd);
int dfe_reqd_placed (df_elt_t * dfe);
void  sqlo_place_dfe_after (sqlo_t * so, locus_t * loc, df_elt_t * after_this, df_elt_t * dfe);
df_elt_t ** sqlo_and_list_body (sqlo_t * so, locus_t * loc, df_elt_t * tb, dk_set_t pred_dfes);
void sqlo_fun_ref_epilogue (sqlo_t * so, op_table_t * from_ot);
df_elt_t * sqlo_key_part_best (dbe_column_t * col, dk_set_t col_preds, int upper_only);
state_slot_t * sqlg_dfe_ssl (sqlo_t * so, df_elt_t * col);
code_vec_t sqlg_pred_body (sqlo_t * so, df_elt_t **  body);
code_vec_t sqlg_pred_body_1 (sqlo_t * so, df_elt_t **  body, dk_set_t append);
query_t * sqlg_dt_query (sqlo_t * so, df_elt_t * dt_dfe, query_t * fill_query, ST ** target_names);
void sqlg_top (sqlo_t * so, df_elt_t * top_dfe);
void sqlg_top_1 (sqlo_t * so, df_elt_t * dfe, state_slot_t ***sel_out_ret);
int sqlo_key_score (dbe_key_t * key, dk_set_t col_preds, int *is_unq);
df_elt_t * dfe_col_def_dfe (sqlo_t * so, df_elt_t * col_dfe);
void sqlo_table_locus (sqlo_t * so, df_elt_t * tb_dfe,
		  dk_set_t col_preds, dk_set_t * after_test, dk_set_t after_join_test, dk_set_t * vdb_join_test);
int sqlo_fits_in_locus (sqlo_t * so, locus_t * loc, df_elt_t * dfe);
locus_t * sqlo_dfe_preferred_locus (sqlo_t * so, df_elt_t * super, df_elt_t * dfe);
data_source_t * sqlg_locus_rts (sqlo_t * so, df_elt_t * first_dfe, dk_set_t pre_code);
locus_t * sqlo_dt_locus  (sqlo_t * so, op_table_t * ot, locus_t * outer_loc);
void dfe_loc_result (locus_t * loc_from, df_elt_t * requiring, df_elt_t * required);
df_elt_t * sqlo_df_elt (sqlo_t * so, ST * tree);
void sqlg_dfe_code (sqlo_t * so, df_elt_t * dfe, dk_set_t * code, int succ, int fail, int unk);
df_elt_t *sqlo_top_dfe (df_elt_t * dfe);
void sqlo_place_hash_filler (sqlo_t * so, df_elt_t * dfe, df_elt_t * filler);

int loc_supports_top_op (locus_t * loc, ST * tree);

void sqlo_box_print (caddr_t tree);
extern const char *sqlo_spec_predicate_name (ptrlong pred_type);

state_slot_t *sqlo_co_place (sql_comp_t * sc);
col_ref_rec_t *sqlo_col_or_param_1 (sql_comp_t * sc, ST * tree, int generate);
col_ref_rec_t * sqlo_find_col_ref (sql_comp_t *sc, ST * tree);
#define sqlo_col_or_param(sc,tree) sqlo_col_or_param_1 (sc, tree, 1)
void dfe_unit_cost (df_elt_t * dfe, float input_arity, float * u1, float * a1, float * overhead_ret);
void dfe_table_cost (df_elt_t * dfe, float * u1, float * a1, float * overhead_ret, int first_inx_only);
float  sqlo_inx_intersect_cost (df_elt_t * tb_dfe, dk_set_t col_preds, dk_set_t inxes, float * arity_ret);

/* sqloinx.c */
void sqlo_init_eqs (sqlo_t * so, op_table_t * ot);
void sqlo_find_inx_intersect (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t col_preds, float best);
void sqlo_place_inx_int_join (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t group,
			 dk_set_t * after_preds);
void sqlo_try_inx_int_joins (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t * group_ret, float * best_group);
void sqlo_prepare_inx_int_preds (sqlo_t * so);

void sqlo_dfe_type (sqlo_t * so, df_elt_t * dfe);

void sqlo_place_table (sqlo_t * so, df_elt_t * tb_dfe);
float dfe_arity_with_supers (df_elt_t * dfe);

df_elt_t *sqlo_top_1 (sqlo_t * so, sql_comp_t * sc, ST ** tree);

void sqlg_print_pred_and_list (sqlo_t * so, dk_set_t list, int force_local, int * is_first,
    char * text, size_t len, int * fill);
void sqlg_print_tb_pred_body (sqlo_t * so, df_elt_t ** body, int * first,
    char * text, size_t tlen, int * fill);

ptrlong sqlo_select_top_cnt (sqlo_t *so, ST *top_exp);

#define sqlo_print(f) printf f

#define TNCONCF1(p, d) p = dk_set_conc (p, t_cons ((void*) d, NULL))

#define dfe_is_lower(dfe) (dfe->_.bin.op == BOP_GT || dfe->_.bin.op == BOP_GTE)
#define dfe_is_UPPER(dfe) (dfe->_.bin.op == BOP_LT || dfe->_.bin.op == BOP_LTE)


#define OT_ID(ct, str) \
  snprintf (str, sizeof (str), "<%s %s>", ot->ot_table->tb_name, ot->ot_prefix ? ot->ot_prefix : "")

#define dfe_ot(dfe) (dfe->dfe_type == DFE_DT ? dfe->_.sub.ot : dfe->_.table.ot)

#define ST_NOT_LOCAL 0
#define ST_LOCAL 1
#define ST_LOCAL_PROCEED 2

/* for sqlo_layout is_top */
#define SQLO_LAY_EXISTS 0
#define SQLO_LAY_VALUES 1
#define SQLO_LAY_TOP 2

#define IS_UNION_ST(view) \
  (ST_P (view, UNION_ST) || \
   ST_P (view, UNION_ALL_ST) || \
   ST_P (view, EXCEPT_ST) || \
   ST_P (view, EXCEPT_ALL_ST) || \
   ST_P (view, INTERSECT_ST) || \
   ST_P (view, INTERSECT_ALL_ST))

#define DFE_IS_PARAM(dfe) \
	(dfe->dfe_type == DFE_CONST && (SYMBOLP (dfe->dfe_tree) || ST_P (dfe->dfe_tree, COL_DOTTED)))

#define DFE_IS_CONST(dfe) \
	(dfe->dfe_type == DFE_CONST && !DFE_IS_PARAM (dfe))


#define ST_OPT(tree, dtp, member) \
  (box_length ((caddr_t)tree) > (ptrlong) &((ST*)0)->member ? (dtp) tree->member : (dtp) NULL)

caddr_t sqlo_opt_value (caddr_t * opts, int opt);
int  sqlo_try_remote_hash (sqlo_t * so, df_elt_t * tb_dfe);

#define RHJ_NONE 0
#define RHJ_LOCAL 1
#define RHJ_REMOTE 2

int sqlo_remote_hash_filler (sqlo_t * so, df_elt_t * filler, df_elt_t * tb_dfe);

int sqlo_col_scope_1 (sqlo_t * so, ST * col_ref, int generate);
#define sqlo_col_scope(so,col_ref) sqlo_col_scope_1(so, col_ref, 1)

/* sqltype.h */
ST *sqlo_udt_check_method_call (sqlo_t *so, sql_comp_t *sc, ST *tree);
ST *sqlo_udt_check_observer (sqlo_t * so, sql_comp_t * sc, ST * tree);
ST *sqlo_udt_check_mutator (sqlo_t * so, sql_comp_t * sc, ST * tree);

ST *sqlo_udt_is_mutator (sqlo_t * so, sql_comp_t * sc, ST * lvalue);
ST *sqlo_udt_make_mutator (sqlo_t * so, sql_comp_t * sc, ST * lvalue, ST *rvalue, ST *var_to_be);

int64 dbe_key_count (dbe_key_t * key);

int sqlo_is_seq_in_oby_order (sqlo_t * so, df_elt_t * dfe, df_elt_t * last_tb);
void sqlg_find_aggregate_sqt (dbe_schema_t *schema, sql_type_t *arg_sqt, ST *fref, sql_type_t *res_sqt);
void sqlg_rdf_inf ( df_elt_t * tb_dfe, data_source_t * ts, data_source_t ** q_head);
void sqlg_outer_with_iters (df_elt_t * tb_dfe, data_source_t * ts, data_source_t ** head);
data_source_t * qn_next (data_source_t * qn);
caddr_t sqlo_iri_constant_name (ST* tree);
int sqlo_is_postprocess (sqlo_t * so, df_elt_t * dt_dfe, df_elt_t * last_tb_dfe);

#include "sqlofn.h"
#include "sqloinv.h"
#include "sqlcstate.h"


#ifdef BIF_XML
extern void
xr_auto_meta_data (sql_comp_t * sc, ST * tree);

#define IS_FOR_XML(tree) \
  (((sqlc_meta_hook_t) THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_META)) == xr_auto_meta_data)
#endif

ST * sinv_check_exp (sqlo_t *so, ST *tree);
ST * sinv_check_inverses (ST *tree, client_connection_t *cli);
void sinv_sqlo_check_col_val (ST **pcol, ST **pval, dk_set_t *acol, dk_set_t *aval);
sinv_map_t * sinv_call_map (ST * tree, client_connection_t * cli);
int sqlo_is_contains_vdb_tb (sqlo_t *so, op_table_t *ot, char ctype, ST **args);
int sel_n_breakup (ST* sel);
df_elt_t ** sqlo_in_list (df_elt_t * pred, df_elt_t *tb_dfe, caddr_t name);
dbe_column_t *  cp_left_col (df_elt_t * cp);
df_elt_t ** sqlo_pred_body (sqlo_t * so, locus_t * loc, df_elt_t * tb_dfe, df_elt_t * pred);
void qn_ins_before (sql_comp_t * sc, data_source_t ** head, data_source_t * ins_before, data_source_t * new_qn);


/* cost model constants */

#define COL_PRED_COST 0.02 /* itc_col_check */
#define ROW_SKIP_COST 0.04 /* itc_row_check and 1 iteration of itc_page_search */
#define INX_INIT_COST 1  /* fixed overhead of starting an index lookup */
#define INX_CMP_COST 0.25 /* one compare in random access lookup. Multiple by log2 of inx count to get cost of 1 random access */
#define ROW_COST_PER_BYTE (COL_PRED_COST / 200) /* 200 b of row cost 1 itc_col_check */
#define NEXT_PAGE_COST 5
#define INX_ROW_INS_COST 1 /* cost of itc_insert_dv into inx */
#define HASH_ROW_INS_COST 1.6 /* cost of adding a row to hash */
#define HASH_LOOKUP_COST 0.9
#define HASH_ROW_COST 0.3
#define CV_INSTR_COST 0.1   /* avg cost of instruction in code_vec_run */

#define HASH_COUNT_FACTOR(n)\
  (0.05 * log(n) / log (2)) 


#endif /* _SQLO_H */

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
 *  Copyright (C) 1998-2013 OpenLink Software
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
  char	ot_is_group_dummy;	/*!< Fictive table corresponding to a group by's results. fun refs depend alone on this and this depends on all other tables */
  dk_set_t	ot_oby_ots;	/*!< For a dt, the component ots in the oby order */
  dk_set_t 	ot_order_cols;	/*!< for a table in an ordered from, the subset of the oby pertaining to this table */
  char 	ot_order_dir;
  df_elt_t *	ot_oby_dfe;	/*!< For a dt, the dfe for the sorted oby */
  df_elt_t *	ot_group_dfe;
  locus_t *	ot_locus;

  dk_set_t	ot_virtual_cols;
  /* XPATH & FT members */
  op_virt_col_t *ot_main_range_out;	/*!< Only ranges in main text, e.g. for compatibility with existing applications. */
  op_virt_col_t *ot_attr_range_out;	/*!< Only ranges in attributes */
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
  ST *		ot_ext_fti;		/*!< Provider of external free-text index, such as SOLR, used instead of local index */
  ST *		ot_geo;
  ST *		ot_geo_rdf;
  ST *		ot_geo_prec;
  /* hash join */
  setp_node_t * 	ot_hash_filler;
  int		ot_fixed_order;
  caddr_t *	ot_opts;
  int		ot_layouts_tried;
  int		ot_tried_at_cutoff;
  int		ot_has_cols;
  char 		ot_is_proc_view;

  dk_set_t 	ot_invariant_preds;
  id_hash_t * 	ot_eq_hash; /* eq group of things, use for eq transitivity */
  ST *		ot_trans; /* if transitive dt, trans opts */
  df_elt_t *	ot_first_dfe; /* first dfe in current plan, one of ot from dfes */
  float		ot_initial_cost; /* cost of initial plan with this ot in first position */
  char		ot_any_plan; /* true if there is at least one full plan with this ot in first position */
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
#define DFE_FILTER 22
#define DFE_HEAD 100

#define DFE_TEXT_PRED 101




#define DFE_PLACED 1	/* placed in a scenario */
#define DFE_GEN 2	/* placed in the executable graph */
#define DFE_JP_PLACED 3 /* placed for join plan */

#define TN_FWD 1
#define TN_BWD 2

typedef struct trans_layout_s
{
  /* if dfe is transitive, details of trans layout here */
  dk_set_t	tl_params;
  dk_set_t	tl_target;
  df_elt_t *	tl_complement;
  char		tl_direction;
}trans_layout_t;

/* for setp. is_distinct */
#define DFE_S_DISTINCT 1
#define DFE_S_SAS_DISTINCT 2



struct df_elt_s
{
  short	dfe_type;
  char	dfe_is_placed;
  bitf_t	dfe_double_placed:1; /* can be a dfe is placed in many copies for restricting more than one hash build */
  bitf_t	dfe_unit_includes_vdb:1;
  bitf_t	dfe_is_joined:1; /* in planning next op, true if there is join to any previously placed dfe */
  bitf_t	dfe_is_planned:1; /* true if included in a multi-dfe next step in planning next dfe */
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
      dk_set_t	index_path;
      dk_set_t 	col_pred_merges;
      dk_set_t	all_preds;
      dk_set_t 	inx_preds;
      dk_set_t	col_preds;
      df_elt_t **	join_test;
      df_elt_t **	after_join_test;
      df_elt_t **	vdb_join_test; /* the part of a remote table's join test that must be done on the vdb */
      dk_set (df_elt_t*)	out_cols;

      bitf_t is_being_placed; /* true while laying out preds for this */
      bitf_t is_unique:1;
      bitf_t is_arity_sure:4;  /* if unique or comes from inx sample or n distinct.  Value is no of key parts in sample */
      bitf_t is_oby_order:1;
      bitf_t single_locus:1;
      bitf_t is_text_order:1;
      bitf_t text_only:1;
      bitf_t is_xcontains:1;
      bitf_t is_locus_first:1;
      bitf_t is_leaf:1;
      bitf_t is_cl_part_first:1;
      bitf_t in_order:1;
      bitf_t is_inf_col_given:1; /* if rdf inferred subclass/prop given and checked as after test, no itre over supers */
      bitf_t hash_role:3;
      bitf_t is_hash_filler_unique:1; /* if this is a hash filler and the key of the hash is unique, so guaranteed no dups in hash */
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
      df_elt_t *	hash_filler_of; /* ref from filler to hash source dfe */
      float	in_arity;
      float	inx_card;
      float	hit_spacing; /* 1 if consec rows, 2 if every 2nd, 0.5 if each repeats twice before mext */
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
      trans_layout_t *	trans;
      df_elt_t *	hash_filler_of; /* if dt is a hash filler this is the the table dfe that accesses the hash  dfe */
      ptrlong *	dist_pos; /* out cols at these positions make a distinct filter */
      float 		in_arity;  /* estimate evaluation count of the dt's head node  */
      char	is_locus_first;
      char	n_hash_fill_keys;
      bitf_t	is_hash_filler_unique:1;
      bitf_t	is_contradiction:1;
      bitf_t	is_complete:1; /* false if join order is being decided, true after fixed */
      bitf_t 	is_being_placed:1;
      bitf_t	to_be_trans:1; /* if will be transitive even though ot_trans is not set during placing */
      bitf_t	is_control:1; /* if set, do not place things inside into supers evenn if could by  dependency. */
    bitf_t	not_in_top_and:1; /* existence in a not or or, scalar subq. if hash probe outside of this subq, must not prefilter on bloom when fetching the probe col */
    } sub;
    struct {
      /* union dt head, or union coming from a table + or */
      op_table_t *	ot;
      int 	op;
      df_elt_t **	terms;
      caddr_t *	corresponding;
      char	is_best;
      char	is_in_fref;
    } qexp;
    struct {
      dbe_column_t *	col;
      op_virt_col_t *   vc;
      float		card; /* if from rdf quad, card is given by p stats and is not the card of the dbe_column_t */
      bitf_t		is_fixed:1; /* col eq to param or col imported from other dt, if all group cols fixed, gb can be dropped */
    } col;
    struct {
      int 	op;
      df_elt_t *	left;
      df_elt_t* right;
      dtp_t	eq_set;
      char 	escape;
      char      is_in_list;          /* top level lte of a x < one_of_these (...) */
      bitf_t	eq_other_dt:1; /* if following this eq, the joined is in a different dt/subq, the join is existence, card can only be restricted */
      bitf_t	no_subq:2;
    } bin;
    struct {
      df_elt_t **	body;
      dk_set_t		preds;
    } filter;
    struct {
      int	op;
      caddr_t	func_name;
      df_elt_t *	func_exp;
      df_elt_t **	args;
    } call;
    struct {
      char 	is_linear;
      char	is_distinct;
      bitf_t	is_being_placed:1;
      float	gb_card;
      ST **	specs;
      dk_set_t *	oby_dep_cols; /* if exps laid after oby, this is the list of all cols each exp depends on.  If exps generated, these must be in oby keys or deps */
      dk_set_t 	fun_refs;
      df_elt_t **	after_test;
      dk_set_t 		having_preds;
      op_table_t *ot;
      ptrlong   top_cnt;
      dk_set_t	gb_dependent;
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
      char geo;
      ST ** args;
      dbe_column_t *col;
      state_slot_t *ssl;
      op_table_t *ot;
      df_elt_t **	after_test;
      dk_set_t		after_preds;
      dbe_table_t *	inx_table; /* geo pred can specify different rtree tables for the same indexed col */
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
  char	sco_fun_refs_allowed;
  int		sco_has_jt;
  sqlo_t *	sco_so;
  dk_set_t 	sco_jts;
  dk_set_t	sco_scalar_subqs; /* if identical value subq many times in a scope, like in select and in oby, then rename just once, so get common subexp just once */
};





struct sqlo_s
{
  sql_comp_t *	so_sc; /* enclosing proc comp ctx */
  sqlo_t *	so_super;
  sql_scope_t *	so_scope;
  dk_set_t	so_with_decls;
  df_elt_t *	so_dfe;
  int	so_name_ctr;
  dk_set_t 	so_tables; /* all op tables, regardless of nesting */
  op_table_t *	so_this_dt;
  id_hash_t *	so_df_elts;
  id_hash_t *	so_df_private_elts;
  df_elt_t *	so_gen_pt;

  char	so_is_top_and;
  char	so_in_cond_exp;
  char	so_no_text_preds;
  char	so_any_with_this_first;  /* is there any plan that starts with the dfe this plan starts with  */
  char	so_plan_mode;
  dk_set_t	so_placed; /*accumulate new prospective placements here */
  short	so_label_ctr;
  float		so_best_score;
  df_elt_t *	so_best;
  float 	so_top_best_score;
  float	so_dt_input_arity;
  float	so_cost_up_to_dt;
  float	so_best_index_cost;
  float	so_best_index_card;
  char	so_best_index_card_sure;
  dk_set_t	so_best_index_path;
  dk_set_t	so_after_preds; /* during inx choice, the exps that are not col preds */
  locus_t *	so_target_locus;
  int		so_locus_ctr;
  remote_table_source_t * 	so_target_rts;
  df_elt_t *	so_copy_root; /* in sqlo_layout_copy, get the locus state into this dt dfe */
  df_elt_t *		so_vdb_top;  /* dummy top dfe for an all pas through top select. Used to reference the selection to bring outside of remote  */
  char 		so_is_rescope; /* if labeling generated subtree leave unresolved col refs as is */
  char		so_place_code_forr_cond;  /* inside cond exp, do not precalculate */
  char		so_inside_control_exp; /* if set, do not place things outside of the innermost enclosing control exp */
  dk_set_t 	so_hash_fillers;
  char		so_bin_op_is_negate;
  char		so_is_select;
  caddr_t	so_vdb_dml_prefix;
#ifndef NDEBUG
  char		so_dfe_unplace_pass; /* not generate errors in sqlo_dfe_unplace if dfe != sqlo_df ()*/
#endif
  dk_set_t	so_in_list_nodes;
  dk_set_t	so_all_list_nodes;
  dk_set_t *	so_inx_int_tried_ret; /* ref to where dfes tried with an inx int go so that the same inx int does not get tried in all permutations */
  id_hash_t *	so_subscore;
  id_hash_t *	so_subq_cache;
  df_elt_t *	so_crossed_oby; /* If placing exp and there is an oby that is crossed, then set this to be the oby so that the exp can be added to its deps */
  df_elt_t *	so_context_dt;
  uint32	so_last_sample_time; /* used for stopping compilation if longer is elapsed since last sample than the best plan's time */
  int32		so_max_layouts;
  int32		so_max_memory;
  int		so_nth_select_col; /* the position in select list for which an exp is being generated.  Used for adding dependent cols to oby when adding cols to dts  when doing ref from enclosing dt */
  char		so_identity_joins;
  char		so_cache_subqs;
  char		so_any_placed;
  char		so_mark_gb_dep;
  char		so_placed_outside_dt;
  char		so_no_dt_cache;
};


/* so_plan_mode */
#define SO_ALL_PLANS 0
#define SO_INITIAL_PLAN 1
#define SO_REFINE_PLAN 2

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

typedef struct tb_sample_s
{
  char		smp_is_leaf;
  int		smp_ref_count; /* on text_count_mtx or ric_mtx */
  int *		smp_sets;
  data_col_t *	smp_dcs;
  float		smp_card;
  float		smp_inx_card;
  int		smp_time;
  float *	smp_dep_sel; /* if contains samples on dependent cols, selectivity in order of dep conditions */
} tb_sample_t;



typedef struct ts_action_s
{
  /* operation done on a row in an index after inx preds are matched.  Can eval exps, compare columns and extract column values */
  df_elt_t *	tsa_exp;
  df_elt_t *	tsa_test_col;
  df_elt_t *	tsa_extract_col;
} ts_action_t;

/* for index choice being considered, for each index the below is filled in.
 * if looping over in or rdf subclass/subpred is involved, this is mentioned as ic_n_lookups
 * if checking indexable in or rdf subc/subp as after test is preferred, this is indicated by putting the removed col pred in ic_rm_col_preds and adding the corresponding after test in ic_after_test */
typedef struct index_choice_s
{
  dbe_key_t *	ic_key;
  float	ic_arity;
  float	ic_unit;
  float	ic_overhead;
  float	ic_spacing; /* this many rows between consecutive rows fetched on vectored index lookup. 1 means consecutive */
  char	ic_in_order; /* vectored index lookup in order with the previous index lookup */
  char	ic_is_cl_part_first; /* preceded by a cluster partitioning step, qf or dfg stage */ 
  char	ic_leading_constants; /* this many leading constants used for sampling */
  char	ic_is_unique;
  char	ic_not_applicable;
  char	ic_no_dep_sample;
  int	ic_op;
  int	ic_n_lookups;
  dk_set_t	ic_altered_col_pred;
  dk_set_t	ic_after_test;
  float 	ic_after_test_arity;
  float		ic_inx_card;
  float		ic_col_card_corr; /* if ic samples dependent cols, this is the correction factor to the for the  cols sampled to the dependent col card est */
  struct rdf_inf_ctx_s *	ic_ric;
  df_elt_t *	ic_inf_dfe;
  int		ic_inf_type;
  dk_set_t	ic_inx_preds;
  dk_set_t	ic_col_preds;
  df_inx_op_t *	ic_inx_op;
  dk_set_t	ic_ts_action; /* non key col extraction, comparison, expressions, eveld while page wired down  */
  dk_set_t	ic_after_preds;
  dk_set_t	ic_eliminated_after_preds; /* if an after is transformed into a col pred, mark it here */
  df_elt_t *		ic_o_range;
  struct index_choice_s *		ic_o_range_ref_ic;
  df_elt_t *	ic_text_pred;
  df_elt_t *	ic_geo_pred;
  char		ic_text_order;
  char		ic_geo_order;
  char		ic_o_string_range_lit; /* 1 if o is known to be a string 2 if literal strings */
  char		ic_set_sample_key;
  dk_set_t	ic_inx_sample_cols;
} index_choice_t;

typedef struct pred_score_s
{
  df_elt_t *		ps_pred;
  dbe_column_t *	ps_left_col;
  df_elt_t *		ps_right;
  caddr_t		ps_const;
  float			ps_card;
  char			ps_is_placeable;
  char			ps_is_const;
} pred_score_t;

#define JP_MAX_PREDS 16

typedef struct join_plan_s
{
  df_elt_t *	jp_tb_dfe;
  int		jp_n_preds;
  int		jp_n_joined;
  float		jp_fanout;
  float		jp_cost;
  float		jp_best_cost;
  float		jp_best_card;
  float			jp_reached; /* how many joined dfes in so many steps, recognize a star join, closer counts for more  */
  float		jp_fill_selectivity; /* for selective hash join, seeing if more joins should go in the build, this is the fraction selected by the first dfe on build side */
  dtp_t		jp_eq_set; /* joined to previous via this eq set */
  char		jp_not_for_hash_fill; /* set if jp_tb_dfe not suited for use in hash fill join */
  char		jp_hash_fill_non_unq;
  char		jp_is_exists;
  char		jp_unique;
  dk_set_t	jp_best_jp;
  dk_set_t	jp_extra_preds; /* if hash filler dt, preds that are redundant, covered by the join of the first to the probe */
  pred_score_t	jp_preds[JP_MAX_PREDS];
  df_elt_t *	jp_joined[JP_MAX_PREDS];
  struct join_plan_s *	jp_prev;
  dk_set_t		jp_hash_fill_dfes; /* other dfes that compose a join on the  fill side of hash join */
  dk_set_t		jp_hash_fill_preds;
} join_plan_t;


typedef struct linint_s
{
  int	li_n_points;
  float *	li_x;
  float *	li_y;
} lin_int_t;


#define IC_OPT_ITERS 0 /* can change in or rdf inf iters into after test */
#define IC_AS_IS 1 /* do not change in or rdf inf iteration into after test */


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
int dfe_try_ordered_key (df_elt_t * prev_tb, df_elt_t * dfe);
df_elt_t * dfe_prev_tb (df_elt_t * dfe, float * card_between_ret, int stop_on_new_order);
void dfe_revert_scan_order (df_elt_t * dfe, df_elt_t * prev_tb, dbe_key_t * prev_key);
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
query_t * sqlg_dt_subquery (sqlo_t * so, df_elt_t * dt_dfe, query_t * fill_query, ST ** target_names, state_slot_t * set_no);
#define sqlg_dt_query(so, dt_dfe, fill_query, target_names) sqlg_dt_subquery (so, dt_dfe, fill_query, target_names, NULL)
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
void dfe_table_cost_ic (df_elt_t * dfe, index_choice_t * ic, int inx_only);
void dfe_table_cost_ic_1 (df_elt_t * dfe, index_choice_t * ic, int inx_only);
float  sqlo_inx_intersect_cost (df_elt_t * tb_dfe, dk_set_t col_preds, dk_set_t inxes, float * arity_ret);
void dfe_top_discount (df_elt_t * dfe, float * u1, float * a1);


/* sqloinx.c */
void sqlo_init_eqs (sqlo_t * so, op_table_t * ot);
void sqlo_find_inx_intersect (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t col_preds, float best);
int sqlo_is_col_eq (op_table_t * ot, df_elt_t * col, df_elt_t * val);
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
	(dfe->dfe_type == DFE_CONST && (SYMBOLP (dfe->dfe_tree) || ST_COLUMN (dfe->dfe_tree, COL_DOTTED)))

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

#define COL_PRED_COST col_pred_cost
#define ROW_SKIP_COST row_skip_cost 
#define INX_INIT_COST inx_init_cost 
#define INX_CMP_COST inx_cmp_cost
#define ROW_COST_PER_BYTE row_cost_per_byte 
#define NEXT_PAGE_COST next_page_cost 
#define INX_ROW_INS_COST inx_row_ins_cost
#define HASH_ROW_INS_COST hash_row_ins_cost  /* cost of adding a row to hash */
#define HASH_MEM_INS_COST hash_mem_ins_cost
#define HASH_LOOKUP_COST hash_lookup_cost 
#define HASH_ROW_COST hash_row_cost
#define CV_INSTR_COST cv_instr_cost
extern float hash_log_multiplier;

#define HASH_COUNT_FACTOR(n)\
  (hash_log_multiplier * log(n) / log (2))


extern float hash_row_ins_cost;
extern float hash_lookup_cost;
extern float hash_row_cost;
extern float hash_log_multiplier;


char  sqlg_geo_op (sql_comp_t * sc, ST * op);

/* cluster compiler funcs */
int key_is_local_copy (dbe_key_t * key);
void clb_init (comp_context_t * cc, cl_buffer_t * clb, int is_select);

void  sqlg_cl_table_source (sqlo_t * so, df_elt_t * dfe, table_source_t * ts);
void sqlg_cl_save_env (sql_comp_t * sc, query_t * qr,  data_source_t * qn, dk_set_t env);
dpipe_node_t * sqlg_pre_code_dpipe (sqlo_t * so, dk_set_t  * code_ret, data_source_t * qn);
void sqlg_place_dpipes (sqlo_t * so, data_source_t ** qn_ptr);
void dk_set_ins_after (dk_set_t * s, void* point, void* new_elt);
void dk_set_ins_before (dk_set_t * s, void* point, void* new_elt);
void sqlg_cl_colocate (sql_comp_t * sc, data_source_t * qn, fun_ref_node_t * prev_fref);
void  sqlg_top_max (query_t * qr);
outer_seq_end_node_t * sqlg_cl_bracket_outer (sqlo_t * so, data_source_t * first);
data_source_t * qn_ensure_prev (sql_comp_t * sc, data_source_t ** head , data_source_t * qn);
int sqlo_is_col_eq (op_table_t * ot, df_elt_t * col, df_elt_t * val);
void sqlo_post_oby_ref (sqlo_t * so, df_elt_t * dt_dfe, df_elt_t * sel_dfe, int inx);
int sqlo_is_unq_preserving (caddr_t name);

#define SINV_DV_STRINGP(x) \
	(DV_STRINGP (x) || DV_TYPE_OF (x) == DV_SYMBOL)

int box_is_subtree (caddr_t box, caddr_t subtree);
void sqlg_unplace_ssl (sqlo_t * so, ST * tree);
char  sqlc_geo_op (sql_comp_t * sc, ST * op);
int sqlo_solve (sqlo_t * so, df_elt_t * tb_dfe, df_elt_t * cond, dk_set_t * cond_ret, dk_set_t * after_preds);

df_inx_op_t * inx_op_copy (sqlo_t * so, df_inx_op_t * dio,
			   df_elt_t * org_tb_dfe, df_elt_t * tb_dfe);
df_elt_t ** dfe_pred_body_copy (sqlo_t * so, df_elt_t ** body, df_elt_t * parent);
void sqlo_choose_index_path (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t * col_preds_ret, dk_set_t * after_preds_ret);
void dfe_text_cost (df_elt_t * dfe, float *u1, float * a1, int text_order_anyway);
void sqlo_choose_index_path (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t * col_preds_ret, dk_set_t * after_preds_ret);
void sqlg_text_node (sqlo_t * so, df_elt_t * tb_dfe, index_choice_t * ic);
void sqlg_xpath_node (sqlo_t * so, df_elt_t * tb_dfe);
inx_op_t * sqlg_inx_op (sqlo_t * so, df_elt_t * tb_dfe, df_inx_op_t * dio, inx_op_t * parent_iop);
key_source_t * sqlg_key_source_create (sqlo_t * so, df_elt_t * tb_dfe, dbe_key_t * key);
void sqlg_non_index_ins (df_elt_t * tb_dfe);
void sqlg_is_text_only (sqlo_t * so, df_elt_t *tb_dfe, table_source_t *ts);
data_source_t * sqlg_make_path_ts (sqlo_t * so, df_elt_t * tb_dfe);
int dfe_is_eq_pred (df_elt_t * pred);
float sqlo_index_path_cost (dk_set_t path, float * cost_ret, float * card_ret, char * sure_ret);
data_source_t * sqlg_make_ts (sqlo_t * so, df_elt_t * tb_dfe);
float dfe_group_by_card (df_elt_t * dfe);
int dfe_is_o_ro2sq_range (df_elt_t * pred, df_elt_t * tb_dfe, df_elt_t ** o_col_dfe_ret, df_elt_t ** exp_dfe_ret, int * op_ret);
int qn_is_iter (data_source_t  * qn);
int sqlo_has_col_ref (ST * tree);

void sqlg_cl_ts_split (sqlo_t * so, df_elt_t * tb_dfe, table_source_t * ts);
float dfe_exp_card (sqlo_t * so, df_elt_t * dfe);
void sqlo_rdf_col_card (sqlo_t * so, df_elt_t * td_dfe, df_elt_t * dfe);

#define PRED_IS_EQ(dfe) ((DFE_BOP_PRED == dfe->dfe_type || DFE_BOP == dfe->dfe_type) && BOP_EQ == dfe->_.bin.op)
#define PRED_IS_EQ_OR_IN(dfe) ((DFE_BOP_PRED == dfe->dfe_type || DFE_BOP == dfe->dfe_type) && (BOP_EQ == dfe->_.bin.op || 1 == dfe->_.bin.is_in_list))
int64 sqlo_inx_sample (df_elt_t * tb_dfe, dbe_key_t * key, df_elt_t ** lowers, df_elt_t ** uppers, int n_parts, index_choice_t * ic);
float arity_scale (float ar);
caddr_t sqlo_rdf_lit_const (ST * tree);
caddr_t sqlo_rdf_obj_const_value (ST * tree, caddr_t * val_ret, caddr_t *lang_ret);

float dfe_join_score_jp (sqlo_t * so, op_table_t * ot,  df_elt_t *tb_dfe, dk_set_t * res,
			 join_plan_t * prev_jp);
int  dfe_is_quad (df_elt_t * tb_dfe);
char * dfe_p_const_abbrev (df_elt_t * tb_dfe);
int sqlo_hash_fill_join (sqlo_t * so, df_elt_t * hash_ref_tb, df_elt_t ** fill_ret, dk_set_t org_preds, dk_set_t hash_keys, float ref_card);
void dfe_unplace_fill_join (df_elt_t * fill_dt, df_elt_t * tb_dfe, dk_set_t org_preds);
int st_is_call (ST * tree, char * f, int n_args);
df_elt_t * dfe_container (sqlo_t * so, int type, df_elt_t * super);
float dfe_hash_fill_cond_card (df_elt_t * tb_dfe);
float sqlo_hash_ins_cost (df_elt_t * dfe, float card, dk_set_t cols, float * size_ret);
float sqlo_hash_ref_cost (df_elt_t * dfe, float hash_card);

#define SQK_MAX_CHARS 2000
void dfe_cc_list_key (dk_set_t list, char * str, int * fill, int space);
void so_ensure_subq_cache (sqlo_t * so);
extern int enable_subq_cache;
df_elt_t * sqlo_dt_cache_lookup (sqlo_t * so, op_table_t * ot, dk_set_t imp_preds, caddr_t * cc_key_ret);
void sqlo_dt_cache_add (sqlo_t * so, caddr_t cc_key, df_elt_t * copy);

#define RQ_IS_COL(col, n)  (n == toupper (((dbe_column_t*)col)->col_name[0]))
int sqlg_is_multistate_gb (sqlo_t * so);

#ifdef DEBUG
void dbg_qi_print_row( query_instance_t *qi, dk_set_t slots, int nthset );
void dbg_qi_print_slots( query_instance_t *qi, state_slot_t** slots, int nthset );
#endif // DEBUG
dbe_key_t * tb_px_key (dbe_table_t * tb, dbe_column_t * col);
float dfe_scan_card (df_elt_t * dfe);
int sqlo_parse_tree_count_node (ST *tree, long *nodes, int n_nodes);
int dfe_init_p_stat (df_elt_t * dfe, df_elt_t * lower);

#endif /* _SQLO_H */

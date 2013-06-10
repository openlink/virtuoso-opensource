/*
 *  sqlcmps.h
 *
 *  $Id$
 *
 *  SQL Compiler Data Structures
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

#ifndef _SQLCMPS_H
#define _SQLCMPS_H

#define MAX_REMOTE_TEXT_SZ 20000

typedef struct comp_table_t
  {
    struct sql_comp_s *	ct_sc;
    caddr_t		ct_name;
    caddr_t		ct_prefix;
    caddr_t		ct_vdb_prefix;  /* fictional prefix for vdb tables in
					 * generated code */
    int			ct_is_vdb_dml; /* if table of update/delete in vdb */
    table_source_t *	ct_ts;
    remote_table_source_t *ct_rts;
    dbe_table_t *	ct_table;
    dbe_key_t *		ct_index;
    dk_set_t		ct_out_crrs;
    dk_set_t		ct_out_cols;
    dk_set_t		ct_col_preds;
    dk_set_t		ct_rlocal_preds; /* preds resolved locally on a remote
					    table */
    dk_set_t		ct_non_col_preds;
    dk_set_t		ct_join_preds;	/* if explicit JOIN cond */
    dk_set_t		ct_derived_preds; /* predicates moved into derived from
					     containing WHERE */
    ST *		ct_join_cond;
    dk_set_t		ct_precompute;
    dk_set_t		ct_after_test;
    dk_set_t		ct_after_join_test;
    ST *		ct_derived;	/* select_stmt tree of derived table
					   or view */
    int			ct_generated;
    int			ct_is_unique;
    dk_set_t		ct_order_cols;
    int			ct_order;
    ST *		ct_r_funrefs;
    dk_set_t		ct_fused_cts;  /* remote cts on same dsn handled in
					  same remote stmt */
    char		ct_is_outer;
    oid_t		ct_u_id; /* uid/gid of the view owner if table from view, else those of the user */
    oid_t		ct_g_id;

    struct predicate_s *	ct_ancestor_pred;
    char		ct_ancestor_order;
    char		ct_ancestor_refd;  /* mist join to main row if driving is non pk even if no other main row refs */

    struct predicate_s *	ct_text_pred;
    struct predicate_s *	ct_xpath_pred;
    char		ct_is_text_order;
    char		ct_text_only;
    data_source_t *	ct_text_node;
    data_source_t *	ct_xpath_node;
    state_slot_t *	ct_text_score_ssl;
    state_slot_t *	ct_main_range_out_ssl;	/* Only ranges in main text, e.g. for compatibility with existing applications. */
    state_slot_t *	ct_attr_range_out_ssl;	/* Only ranges in attributes */
    state_slot_t **	ct_text_offband_ssls;
    state_slot_t *	ct_text_start_ssl;
    state_slot_t *	ct_text_end_ssl;
    state_slot_t *	ct_text_score_limit_ssl;
    state_slot_t *	ct_text_desc_ssl;
    dk_set_t		ct_text_pre_code;
    state_slot_t *	ct_xpath_value_ssl;
    state_slot_t *	ct_text_ssl;
    state_slot_t *	ct_base_uri_ssl;
    int 		ct_is_xcontains;
    int			ct_gb_order;
    ST *		ct_jt_tree;
    dk_set_t		ct_jt_preds;	/* if outer join */
  } comp_table_t;



#define CT_ID(ct, str) \
  snprintf (str, sizeof (str), "<%s %s>", ct->ct_name ? ct->ct_name : "", ct->ct_prefix ? ct->ct_prefix : "")


typedef struct col_ref_rec_s
  {
    ST *		crr_col_ref;
    comp_table_t *	crr_ct;
    dbe_column_t *	crr_dbe_col;
    state_slot_t *	crr_ssl;
    int			crr_is_generated;
    int			crr_order;	/* if appears n order by, asc/desc */
    int			crr_is_as_alias;
    int			crr_proc_table_mode;
  } col_ref_rec_t;


/* crr_proc_table_mode, do predicates in the outer query get passed in */
#define CRR_PT_RESULT 0
#define CRR_PT_IN_EQU 1
#define CRR_PT_IN_ANY 2




typedef int (*sqlc_exp_print_hook_t) (struct sql_comp_s *, comp_table_t * ct, ST * exp,
				      char * text, size_t len, int * fill);

typedef struct rdf_inf_slots_s
{
  state_slot_t *	ris_s;
  state_slot_t *	ris_p;
  state_slot_t *	ris_o;
} rdf_inf_slots_t;


typedef struct sql_comp_s
  {
    comp_context_t *	sc_cc;
    struct sql_comp_s *	sc_super;
    struct predicate_s *sc_predicate;	/*!< The superquery's predicate this
					   subquery is part of */
    dk_set_t		sc_subq_compilations;
    					/*!< plist from the subq's 'select' node
					 to the query_t */
    comp_table_t **	sc_tables;

    dk_set_t		sc_temp_place;	/*!< state_slot_t's for interm. results */
    dk_set_t		sc_col_ref_recs;
    int			sc_last_label;
    dk_set_t		sc_preds;
    client_connection_t *sc_client;
    int			sc_is_proc;
    dk_set_t		sc_routine_code;
    id_hash_t *		sc_name_to_label;
    id_hash_t *		sc_decl_name_to_label;
    data_source_t *	sc_sorter;	/*!< a sort_node_t * if the ORDER BY
					   requires sorting */
    setp_node_t *	sc_sort_insert_node;
    data_source_t *	sc_sort_read_node;
    fun_ref_node_t *	sc_fref; /* when generating non-group aggregates this is the fref node */
    int			sc_no_current_of; /*!< no subsequent where current of
					     to cursor */
    dk_set_t		sc_fun_ref_defaults;
    dk_set_t		sc_fun_ref_default_ssls;
    dk_set_t		sc_fun_ref_temps;
    int			sc_temp_in_qst;
    comp_table_t *	sc_super_ct;	/*!< use in scope resolution in producing
					   a remote subq predicate for a
					   remote_table_source_t */
    dk_set_t		sc_subq_initial_crrs;
    					/*!< when this sc is a super_sc, the
					 subq gets the initial
					 sc_col_ref_recs from this */
    dk_set_t		sc_union_lists;	/*!< list of lists. The sublists are
					   combined in UNION ALL. The terms of
					   each sublist are joined by UNION */
    int			sc_store_procs;	/*!< true if generate code to store proc,
					   view, trigger etc definitions.
					   if not, just defines them in RAM */
    const char *	sc_text;	/*!< outermost sc, text of SQL source */
    key_id_t		sc_next_temp_key_id;
    dk_set_t		sc_gb_refs;	/*!< if group by, copy of selection w/
					   null for gb col & ammsc for f ref */
    ST **		sc_org_selection;/*!< org. selection, if group by */
    dk_set_t		sc_fun_ref_code;

    comp_table_t *	sc_generating_remote_ct; /*!< see sqlc_ct_is_local */
    int			sc_last_cn_no; /*!< last used vdb correlation name number */
    dk_set_t		sc_temp_trees; /*!< list of trees to free at free of sc */
    caddr_t		sc_exp_col_name;
    sql_type_t          sc_exp_sqt; /*!< in vdb, comp time type of generated exp */
    state_slot_t *	sc_exp_param;
    int			sc_no_remote; /*!< for a scroll crsr compile remotes as local for index selection */
    ST **		sc_select_as_list;
    int			sc_check_view_sec;
    sqlc_exp_print_hook_t 	sc_exp_print_hook;
    void *			sc_exp_print_cd;
    ST *			sc_top;
    select_node_t *		sc_top_sel_node;
    dk_set_t			sc_tie_oby;

    struct sql_comp_s * 	sc_scroll_super;
    dk_set_t *			sc_scroll_param_cols;
    ST *		sc_derived_opt;

    state_slot_t *		sc_sqlstate;
    state_slot_t *		sc_sqlmessage;
    struct sqlo_s *	sc_so;
    dk_set_t			sc_jt_preds;

    dk_set_t		sc_compound_scopes;
    int 		sc_is_trigger_decl;
    int 		sc_in_cursor_def;
    state_slot_t *	sc_grouping;
    ST **		sc_groupby_set;
    int		sc_is_update;
    char	sc_parallel_dml;
    char	sc_need_pk;
    char	sc_is_union;
    char	sc_order; /* If order of result rows is not important, like in filling a hash */
    char	sc_any_clb; /* any multi-state cluster node with a clb */
    dk_hash_t *	sc_qn_to_dpipe; /* if a dpipe is to be added before the node, it is marked here */
    dk_hash_t *	sc_ssl_eqs;
    update_node_t * 	sc_update_keyset;
    id_hash_t *	sc_sample_cache;
    state_slot_t **	sc_sel_out;
    dk_set_t		sc_agg_state_slot; /* when making an aggregate, this is the list of slots that hold the aggregation state */
    state_slot_t *	sc_set_no_ssl; /* for multistate qr with aggregate, top, distinct etc, set no of input */
    trans_node_t *	sc_trans; /* the tn while forming the step dt */
    dk_set_t		sc_dfg_stages;
    data_source_t *	sc_qf_first; /* the qn that has the loc ts for the first stage of qf/dfg */
    query_frag_t *	sc_qf;
    fun_ref_node_t *	sc_outer_fref;
    char		sc_in_dfg_subq;
    char		sc_fref_nesting; /* if nested gby/oby, true if colocating the gby */
    char		sc_qf_n_temp_trees; /* how many gb/oby temps in qf.  If many, make shorter batches to save mem */
    char		sc_is_scalar_agg; /* aggregation in scalar subq, no group by */
    char		sc_vec_in_outer; /* true if vectoring right side of left oj.  Fetched cols may not be aliased to others */
    char		sc_qf_in_outer; /* params for a qn in an outer sect inside a qf are nullable, a null there does not disqualify the qf param row  */
    char		sc_is_first_of_qf;
    char		sc_no_distinct_colocate; /* if distinct is for except or intersect, do not put inside a qf even if colocatable */
    char		sc_in_ins_replacing;
    char		sc_re_emit_code; /* in conditional expressions, repeating code must be generated for each branch even if overlap */
    char		sc_is_first_cond; /* true if doing 1st condition in a conditional exp, i.e. will always execute */
    rdf_inf_slots_t *	sc_rdf_inf_slots;
    caddr_t * sc_big_ssl_consts;	/*!< Vector of saved values for SSL consts of unusual types (like vectors) or just too big to fit into SQL text in a plain way */
    dk_set_t		sc_vec_pred;
    dk_hash_t *		sc_vec_ssl_def;
    dk_hash_t *		sc_vec_ssl_shadow;
    dk_hash_t *		sc_vec_prov_cast;
    dk_hash_t * 	sc_vec_last_ref;
    data_source_t *	sc_pre_code_of; /* when setting last ref ni vec, pre code does not set last ref to ts current */
    key_source_t * 	sc_ref_ks;
    dk_hash_t *		sc_vec_no_copy_ssls;
    query_frag_t *	sc_vec_qf; /* if inside a qf in sqlvec */
    dk_hash_t * 	sc_vec_cast_ssls; /* from the cast ssl to its original ssl */
    dk_set_t		sc_hash_fillers;
    data_source_t *	sc_vec_current;
    dbe_column_t *	sc_vec_current_col; /* set when looking for a comparison param for this col, implies null values get filterd out in cast  */
    data_source_t *	sc_vec_first_of_qf; /* qf or stn if setting vec ssls  partitioning  ks of it. */
    dk_set_t	sc_vec_new_ssls;
    dk_set_t 	sc_ssl_prereset_only;
    key_source_t *	sc_qf_ks;
    query_frag_t *	sc_in_qf;
    query_t *		sc_vec_qr;
  } sql_comp_t;



#define SC_UPD_PLACE 1
#define SC_UPD_INS 2

#define TS_ORDER_KEY 0 /* generate results in key order and add key cols */
#define TS_ORDER_DETERMINISTIC 1  /* Like key order but may sort for vectoring, i.e. no irder by coming from index order */
#define TS_ORDER_PLACE 2 /* generate the results in any order but add key cols for subsequent searched upd or del */
#define TS_ORDER_NONE 3  /* generate the results in any order */



#define SC_G_ID(sc) \
  (sc->sc_client->cli_user ? sc->sc_client->cli_user->usr_g_id : G_ID_DBA)

#define SC_U_ID(sc) \
  (sc->sc_client->cli_user ? sc->sc_client->cli_user->usr_id : U_ID_DBA)


#if 0
#define SC_NO_EXCEPT(sc) \
{ \
  dk_set_t olde = sc->sc_except; \
  sc->sc_except = NULL;

#define SC_OLD_EXCEPT(sc) \
  sc->sc_except = olde; \
}
#else
#define SC_NO_EXCEPT(sc)
#define SC_OLD_EXCEPT(sc)
#endif

typedef struct subq_compilation_s
  {
    ST *		sqc_tree;
    query_t *		sqc_query;
    caddr_t		sqc_name;	/* cursor name if this is a cursor made
					   with declare cursor */
    state_slot_t *	sqc_ssl;	/* state slot holding ts_current_of */
    state_slot_t *	sqc_cr_state_ssl;
    dk_set_t		sqc_fetches;	/* fetch instructions referencing this
					   cr */
    char		sqc_is_cursor;	/* in declare .. cursor for ... */
    char		sqc_is_current_of;
					/* if cursor ref'd in where current of
					 * in same proc. */
    char		sqc_is_generated;/* set when actually ref'd in open or
					    pred */
    dbe_table_t *	sqc_remote_co_table;
    					/* prime keys of this added to selection
					 * for use in where current of */
    caddr_t		sqc_remote_prefix;  /* corr. name for PK cols in remotes
					     * where c/of */
    state_slot_t **	sqc_scroll_params;	/* state slots holding the scrollable params */
  } subq_compilation_t;


typedef struct predicate_s
  {
    dk_set_t		pred_tables;
    sql_tree_t *	pred_text;
    int			pred_generated;
  } predicate_t;


typedef struct col_pred_s
  {
    int			colp_op;
    dbe_column_t *	colp_col;
    caddr_t		colp_name; /* if proc table arg, there is no dbe_col */
    state_slot_t *	colp_ssl;
    int			colp_is_generated;
    char 		colp_like_escape;
  } col_pred_t;


typedef struct trig_cols_s
  {
    int			tc_is_trigger;
    ST **		tc_selection;
    dbe_table_t *	tc_table;
    caddr_t *		tc_cols;
    ST **		tc_vals;
    state_slot_t **	tc_slots;
    int			tc_pk_added;
    int			tc_n_before_pk;
  } trig_cols_t;


int key_matches_index_opt (dbe_key_t * key, caddr_t opt);
dbe_key_t *  tb_key_by_index_opt (dbe_table_t * tb, caddr_t opt);

state_slot_t * col_ref_col (sql_comp_t * sc, caddr_t ref);

void comp_scalar_exp (sql_comp_t *sc, dk_set_t * code_vec, sql_tree_t * tree,
    state_slot_t * res);

comp_table_t * sqlc_is_col_pred (predicate_t * pred);
void sqlc_insert_view (sql_comp_t * sc, sql_tree_t * view, sql_tree_t * tree, dbe_table_t * tb);

void sqlc_make_and_list (sql_tree_t * tree, dk_set_t * res);

void pred_gen_1 (sql_comp_t * sc, ST* tree, dk_set_t * code,
    int succ, int fail, int unkn);

void sqlc_generate_preds (sql_comp_t * sc, comp_table_t * ct, dk_set_t * preds);

int ts_predicate_p (ptrlong p);

state_slot_t * scalar_exp_generate (sql_comp_t * sc, ST* tree,  dk_set_t * code);
void pred_list_generate (sql_comp_t * sc, dk_set_t pred_list, dk_set_t * code);


state_slot_t * select_ref_generate (sql_comp_t * sc, ST* tree,  dk_set_t * code,
    dk_set_t * fun_ref_acc_code, int * is_fun_ref);

col_ref_rec_t * sqlc_col_or_param (sql_comp_t * sc, ST * tree,
    int is_recursive);

col_ref_rec_t *  sqlc_col_ref_rec (sql_comp_t * sc, ST * col_ref,
    int err_if_not);

col_ref_rec_t * sqlc_find_crr (sql_comp_t * sc, ST * ref);


subq_compilation_t * sqlc_subquery_1 (sql_comp_t * super_sc, predicate_t * pred,
    ST** ptree, int mode, ST **params);

subq_compilation_t * sqlc_subquery (sql_comp_t * super_sc, predicate_t * pred,
    ST** ptree);

subq_compilation_t * sqlc_subq_compilation (sql_comp_t * sc, ST* tree,
    char * name);
subq_compilation_t *
sqlc_subq_compilation_1 (sql_comp_t * sc, ST * tree,
    char *name, int scrollables);

void sqlc_decl_variable_list (sql_comp_t * sc, ST ** params, int is_arg_list);
void sqlc_decl_variable_list_1 (sql_comp_t * sc, ST ** params, int is_arg_list, dk_set_t *ref_recs);
void sqlc_insert (sql_comp_t * sc, ST * tree);

void sqlc_update_pos (sql_comp_t * sc, ST * tree,
		      subq_compilation_t * cursor_sqc, ST ** src_ret);

void sqlc_update_searched (sql_comp_t * sc, ST * tree);

void sqlc_delete_pos (sql_comp_t * sc, ST * tree,
		      subq_compilation_t * cursor_sqc, ST ** src_ret);

void sqlc_delete_searched (sql_comp_t * sc, ST * tree);

void sqlc_routine_qr (sql_comp_t * sc);

void sqlc_proc_stmt (sql_comp_t * sc, ST ** pstmt);

code_vec_t code_to_cv (sql_comp_t * sc, dk_set_t code);
code_vec_t code_to_cv_1 (sql_comp_t * sc, dk_set_t code, int trim_one_long_cv);

dbe_table_t * table_ref_table (sql_comp_t * sc, ST* tref);

state_slot_t * sqlc_col_ref_ssl (sql_comp_t * sc, ST* col_ref);

setp_node_t *  sqlc_add_distinct_node (sql_comp_t * sc, data_source_t ** head,
				       state_slot_t ** ssl_out, long nrows, dk_set_t * code, ptrlong * dist_pos);


void ct_make_ts (sql_comp_t * sc, comp_table_t * ct);
void ct_generate_col_test (sql_comp_t * sc, comp_table_t * ct, predicate_t * pred);

void sqlc_mark_pred_deps (sql_comp_t * sc,  predicate_t * pred, sql_tree_t * tree);
void sql_node_append (data_source_t ** head, data_source_t * node);
void sqlc_copy_ssl_if_constant (sql_comp_t * sc, state_slot_t ** ssl_ret, dk_set_t * asg_code, setp_node_t * setp);

data_source_t *sqlc_add_sort_nodes (sql_comp_t * sc, data_source_t * old_head);

void sqlc_user_aggregate_decl (sql_comp_t * sc, ST * tree);
void sqlc_routine_decl (sql_comp_t * sc, ST * tree);
void sqlc_module_decl (sql_comp_t * sc, ST * tree);

void sqlc_trigger_decl (sql_comp_t * sc, ST * tree);

void sqlc_sch_list (sql_comp_t * sc, ST * tree);

void sqlc_call_exp (sql_comp_t * sc, dk_set_t * code, state_slot_t * ret,
    ST * tree);

void sqlc_table_ref (sql_comp_t *sc, ST* ref);

void sqlc_table_ref_list (sql_comp_t *sc, ST** refs);

caddr_t * sel_expand_stars (sql_comp_t * sc, ST ** selection, ST** from);

int qr_is_local (query_t * qr, int is_cluster);
int src_is_local (data_source_t * src, int is_cluster);
int cv_is_local_1 (code_vec_t cv, int is_cluster);
#define cv_is_local(cv) cv_is_local_1 (cv, 0)

#define CV_IS_LOCAL_CLUSTER 1 /* check funcs are partitionable and not aggregates */
#define CV_IS_LOCAL_AGG 2 /* check that funcs are partitionable, allow aggrs */
#define CV_IS_LOCAL_CN 3 /* when checking code node with subqs.  Accept the subqs but reject non locatable funcs */

dk_set_t cv_assigned_slots (code_vec_t cv, int no_subqs);
void sqlc_ct_generate (sql_comp_t * sc, comp_table_t * ct);

state_slot_t * sqlc_asg_stmt (sql_comp_t * sc, ST * stmt, dk_set_t * code);

state_slot_t * sqlc_new_temp (sql_comp_t * sc, const char * name, dtp_t dtp);

state_slot_t * sqlc_mark_param_ref (sql_comp_t * sc, ST* param);

state_slot_t * sqlc_col_ref_rec_ssl (sql_comp_t * sc, col_ref_rec_t * cr);

void sc_free (sql_comp_t * sc);

void sqlc_select_strip_as (ST** selection, caddr_t *** as_list, int keep);
ST * sqlc_strip_as (ST * tree);

void sqlc_select_as (state_slot_t ** sls, caddr_t ** as_list);

caddr_t * ins_tb_all_cols (dbe_table_t * tb);

void dk_set_append_1 (dk_set_t * res, void *item);
void st_and (ST ** cond, ST * pred);
void t_st_and (ST ** cond, ST * pred);



struct remote_table_s * find_remote_table (char * name, int create);


dbe_table_t *  sqlc_expand_remote_cursor (sql_comp_t * sc, ST * tree);



/* sqlview.c */
void sqlc_union_stmt (sql_comp_t * sc, ST** ptree);
void sqlc_union_order (sql_comp_t * sc, ST ** ptree);
ST * sqlc_union_dt_wrap (ST * tree);

void sqlc_ct_generate_derived (sql_comp_t * sc, comp_table_t * ct);

key_id_t sqlc_new_temp_key_id (sql_comp_t * sc);
void sqlc_update_view (sql_comp_t * sc, ST* view, ST * tree, dbe_table_t * tb);
void sqlc_delete_view (sql_comp_t * sc, ST* view, ST * tree);
void sqlc_derived_order_by (sql_comp_t * sc, comp_table_t * ct);
void sqlc_table_used (sql_comp_t * sc, dbe_table_t * tb);
void sqlc_trig_const_params (sql_comp_t * sc, state_slot_t ** params,
    dk_set_t * code);
void sqlc_update_set_keyset (sql_comp_t * sc, table_source_t * ts);


void tc_init (trig_cols_t * tc, int event, dbe_table_t * tb, caddr_t * cols,
    ST ** vals, dbe_key_t * add_pk);
void tc_free (trig_cols_t * tc);
int tc_new_value_inx (trig_cols_t * tc, char *col_name);
int tc_pk_value_inx (trig_cols_t * tc, char *col_name);

state_slot_t **sqlc_ins_triggers_1 (sql_comp_t * sc, dbe_table_t * tb,
    oid_t * col_ids, dk_set_t values, dk_set_t * code);
void sqlc_temp_tree (sql_comp_t * sc, caddr_t tree);

void ks_set_search_params (comp_context_t * cc, comp_table_t * ct, key_source_t * ks);
void inx_op_set_search_params (comp_context_t * cc, comp_table_t * ct, inx_op_t * iop);

ST * sqlc_ct_col_ref (comp_table_t * ct, char *col_name);

void sqlc_resignal (sql_comp_t * sc, caddr_t err);

void sql_stmt_comp (sql_comp_t * sc, ST ** ptree);
void qr_set_local_code_and_funref_flag (query_t * qr);


state_slot_t * scalar_exp_generate_typed (sql_comp_t * sc,
    ST * tree, dk_set_t * code, sql_type_t * expect);


sql_type_t * sqlc_stmt_nth_col_type (sql_comp_t * sc, dbe_table_t * tb, ST * tree, int nth);

void sqlc_union_constants (ST * sel);

/* sqlcr.c */
void sqlc_cursor (sql_comp_t * sc, ST ** ptree, int cr_type);

ST * sql_tree_and (ST * tree, ST * cond);
ptrlong cmp_op_inverse (ptrlong op);
caddr_t box_append_1 (caddr_t box, caddr_t elt);
caddr_t box_append_1_free (caddr_t box, caddr_t elt);
#define BOX_CONC_1(b, elt) \
  *(caddr_t*)&b = box_append_1_free ((caddr_t)b, (caddr_t)elt)

caddr_t t_box_append_1 (caddr_t box, caddr_t elt);

col_ref_rec_t * sqlc_virtual_col_crr (sql_comp_t * sc, comp_table_t * ct, char * name, dtp_t dtp);


typedef void (*sqlc_meta_hook_t) (sql_comp_t * sc, ST * tree);
#define TA_SQLC_META 1006
void sqlc_meta_data_hook (sql_comp_t * sc, ST * tree);
void sqlc_proc_table_cols (sql_comp_t * sc, comp_table_t * ct);

void sqlc_top_select_dt (sql_comp_t * sc, ST * tree);
ST ** sqlc_selection_names (ST * tree);

#define P_NO_MATCH 0
#define P_EXACT 1
#define P_PARTIAL 2


int sqlc_pref_match (char * crr_pref, char * ref_pref);
int indexable_predicate_p (int p);
unsigned char bop_to_dvc (int op);
void sqlc_select_top (sql_comp_t * sc, select_node_t * sel, ST * tree, 		 dk_set_t * code);
void sqlc_select_unique_ssls (sql_comp_t * sc, select_node_t * sel, dk_set_t *sel_set);
data_source_t * sqlc_make_sort_out_node (sql_comp_t * sc, dk_set_t out_cols, dk_set_t out_slots, dk_set_t out_always_null, int is_gb);
setp_node_t * setp_node_keys (sql_comp_t * sc, select_node_t * sel, caddr_t * cols);
void qr_replace_node (query_t * qr, data_source_t * to_replace,
		      data_source_t * replace_with, int move_after_code);

void setp_distinct_hash (sql_comp_t * sc, setp_node_t * setp, uint64 n_rows, int op);
void setp_after_deserialize (setp_node_t * setp);
void ha_free (hash_area_t * ha);

#ifdef BIF_XML
ST ** sqlc_ancestor_args (ST * tree);
ST ** sqlc_contains_args (ST * tree, int * ctype);
ST ** sqlc_geo_args (ST * tree, int * ctype);
char sqlc_contains_fn_to_char (const char *name);
void upd_arrange_misc (sql_comp_t * sc, update_node_t * upd);
void ins_arrange_misc (sql_comp_t * sc, insert_node_t * upd);
int sqlc_xpath (sql_comp_t * sc, char * str, caddr_t * err_ret);
void  sqlc_text_node (sql_comp_t * sc, comp_table_t * ct);
void sqlc_is_text_only (sql_comp_t * sc, comp_table_t * ct);
void  sqlc_xpath_node (sql_comp_t * sc, comp_table_t * ct);
void sqlc_implied_columns (sql_comp_t * sc);

void ks_ancestor_scan (sql_comp_t * sc, comp_table_t * ct, key_source_t * ks);
ST * sqlc_embedded_xpath (sql_comp_t * sc, char * str2, caddr_t * err_ret);

#endif

caddr_t sqlo_iri_constant_name_1 (ST* tree);
extern int32 sqlo_compiler_exceeds_run_factor;

/* sqlcr.c */
query_t *
sql_compile_st (ST ** ptree, client_connection_t * cli,
		caddr_t * err, sql_comp_t *super_sc);

/* sqltype.c */
query_t *sqlc_udt_store_method_def (sql_comp_t *sc, client_connection_t *cli,
    int cr_type, query_t *qr, const char * string2, caddr_t *err);
query_t *sqlc_make_proc_store_qr (client_connection_t * cli, query_t * proc_or_trig,
    const char * text);


#define CL_QF_BREAK 1 /* this qn can't pass to cluster remote inside a qf */

void qn_refd_slots (sql_comp_t * sc, data_source_t * qn, dk_hash_t * res, dk_hash_t * all_res, int * non_cl_local);
void sqlg_cl_dml (sql_comp_t * sc, data_source_t * dml);
void sqlg_qn_env (sql_comp_t * sc, data_source_t * qn, dk_set_t qn_stack, dk_hash_t * refs);
void sqlg_qr_env (sql_comp_t * sc, query_t * qr);
void cv_refd_slots (sql_comp_t * sc, code_vec_t cv, dk_hash_t * res, dk_hash_t * all_res, int * non_cl_local);
extern int sqlg_count_qr_global_refs;
void ins_assigned (instruction_t * ins, dk_set_t * res);

extern int sqlg_count_qr_global_refs;

#define REF_SSL(res, ssl) \
  {if (res && ssl && SSL_CONSTANT != ssl->ssl_type \
       && (sqlg_count_qr_global_refs||  !ssl->ssl_qr_global)  && SSL_PLACEHOLDER != ssl->ssl_type && SSL_ITC != ssl->ssl_type) \
sethash ((void*)ssl, res, (void*)1); }

void  ref_ssl_list (sql_comp_t * sc, dk_hash_t * ht, dk_set_t ssls);

#define ASG_SSL(res, all_res, ssl) \
  if (IS_REAL_SSL (ssl)) \
    { \
      sqlc_asg_mark (ssl); \
      sqlg_asg_ssl (res, all_res, ssl); \
    }


void sqlg_asg_ssl (dk_hash_t * res, dk_hash_t * all_res, state_slot_t * ssl);
void sqlc_asg_mark (state_slot_t * ssl);
void asg_ssl_array (dk_hash_t * res, dk_hash_t * all_res, state_slot_t ** ssls);
void ts_set_local_code (table_source_t * ts, int is_cluster);
void sqlg_cl_insert (sql_comp_t * sc, comp_context_t * cc, insert_node_t * ins, ST * tree, dk_set_t * code);
ST * sqlc_pos_to_searched_where (sql_comp_t * sc, subq_compilation_t * sqc, char * cr_name,
			    dbe_table_t * tb);
caddr_t * ht_keys_to_array (dk_hash_t * ht);
void sqlg_multistate_code (sql_comp_t * sc, data_source_t ** head, int in_order);
int qr_is_multistate (query_t * qr);
int qn_seq_is_multistate (data_source_t * qn);
data_source_t * qn_prev (data_source_t ** head , data_source_t * qn);
void sqlg_cl_multistate_simple_agg (sql_comp_t * sc,  dk_set_t * com_code);
void sqlg_multistate_query (sql_comp_t * sc, query_t * qr, set_ctr_node_t * sctr);
state_slot_t * sqlg_set_no_if_needed (sql_comp_t * sc, data_source_t ** head);
void setp_set_ssa (sql_comp_t * sc, setp_node_t * setp, dk_set_t * list_ret);
dk_set_t  ha_save (hash_area_t *);
void sqlg_cl_multistate_group (sql_comp_t * sc);
void ssa_init (sql_comp_t * sc, setp_save_t * ssa, state_slot_t * set_no_ssl);
dk_set_t  sqlg_continue_list (data_source_t * qn);


extern int cl_rdf_inf_inited;
extern du_thread_t * cl_rdf_inf_init_thread;

void sqlg_vector (sql_comp_t * sc, query_t * qr);
void sqlg_vector_params (sql_comp_t * sc, query_t * qr);
void sqlg_vector_subq (sql_comp_t * sc);
void sqlg_vec_qns (sql_comp_t * sc, data_source_t * qn, dk_set_t prev_nodes);
void qn_vec_slots (sql_comp_t * sc, data_source_t * qn, dk_hash_t * res, dk_hash_t * all_res, int * non_cl_local);
void qr_set_vec_ssls (query_t * qr);
#define sqlg_is_vector  (sc->sc_cc->cc_query->qr_proc_vectored)


void remhash_ssl (state_slot_t * ssl, dk_hash_t * ht);
void qr_no_copy_ssls (query_t * qr, dk_hash_t * no_copy);


#define OUTSIDE_PARSE_SEM \
  { \
      int is_sem = sqlc_inside_sem; \
      if (is_sem) \
	semaphore_leave (parse_sem);


#define END_OUTSIDE_PARSE_SEM \
      if (is_sem) \
	semaphore_enter (parse_sem); \
  }

dk_hash_t * hash_table_copy (dk_hash_t * ht);
dk_set_t sslr_set_member (dk_set_t ssls, state_slot_t * param);
void dk_set_replace (dk_set_t s, void * old, void * repl);
sql_comp_t * sc_top_select_sc (sql_comp_t * sc);
void sqlc_need_enlist (sql_comp_t * sc);
int sqlg_distinct_colocated  (sql_comp_t * sc, state_slot_t ** ssls, int n_ssls);
void stn_set_in_slots (sql_comp_t * sc, stage_node_t * stn);
void sqlc_code_dpipe (sql_comp_t * sc, dk_set_t * code);


#define  RDF_UNTYPED ((caddr_t) 1)
#define RDF_LANG_STRING ((caddr_t) 2)

caddr_t sqlo_rdf_obj_const_value (ST * tree, caddr_t * val_ret, caddr_t *lang_ret);
int rdf_obj_of_sqlval (caddr_t val, caddr_t * data_ret);
int rdf_obj_of_typed_sqlval (caddr_t val, caddr_t vtype, caddr_t lang, caddr_t * data_ret);

#endif /* _SQLCMPS_H */

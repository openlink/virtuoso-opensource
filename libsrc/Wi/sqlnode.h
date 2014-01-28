/*
 *  sqlnode.h
 *
 *  $Id$
 *
 *  SQL query nodes
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

#ifndef _SQLNODE_H
#define _SQLNODE_H

#include "odbcinc.h"
#include "wi.h"

typedef struct instruction_s	instruction_t;
typedef struct instruction_s	 * code_vec_t;
typedef struct data_source_s	data_source_t;
typedef struct proc_name_s proc_name_t;
typedef struct cl_thread_s cl_thread_t;
typedef struct query_s		query_t;
typedef struct query_frag_s		query_frag_t;
typedef struct user_aggregate_s user_aggregate_t;

typedef void (*qn_input_fn) (data_source_t *, caddr_t *, caddr_t *);
typedef void (*qn_advance_fn) (data_source_t *);
typedef void (*qn_free_fn) (data_source_t *);


typedef struct _src_stat_s
{
  unsigned int64	srs_start;
  unsigned int64	srs_cum_time;
  unsigned int64	srs_n_in;
  unsigned int64	srs_n_out;
} src_stat_t;

#define SRC_STAT(qn, inst)  ((src_stat_t*)&((caddr_t*)inst)[((data_source_t*)(qn))->src_stat])


struct data_source_s
  {
    dk_set_t		src_continuations;
    ssl_index_t		src_in_state;
    ssl_index_t		src_batch_size;
    ssl_index_t		src_sets;
    ssl_index_t 	src_out_fill;
    ssl_index_t		src_stat;
    qn_input_fn		src_input;
    qn_free_fn		src_free;
    code_vec_t		src_pre_code;
    code_vec_t		src_after_code;
    code_vec_t		src_after_test;
    query_t *		src_query;
    struct state_slot_s **	src_pre_reset;
    struct state_slot_s **	src_continue_reset;
    data_source_t *		src_prev;
    ssl_index_t *		src_vec_reuse; /* at last ref, can drop a big dc if none continuable between asg and last ref */
  };


#define SRC_OUT_STATE(src, inst) \
  * ((state_entry_t **) & inst [src->src_out_state])

#define SRC_IN_STATE(src, inst) \
  * ((caddr_t **) & ((caddr_t*)inst) [((data_source_t*)(src))->src_in_state])


#define SSL_PARAMETER		0
#define SSL_COLUMN		2
#define SSL_VARIABLE		3
#define SSL_PLACEHOLDER		4
#define SSL_ITC			5
#define SSL_CURSOR		6 /* a local_query_t * inside a SQL procedure */
#define SSL_TREE 7
#define SSL_REMOTE_STMT		9
#define SSL_VEC 90 /* value is a qi_mp allocated data_column_t */
#define SSL_REF 91 /* ref to  result of prior node in vectored exec */

#define SSL_CONSTANT		100
#define SSL_REF_PARAMETER	101
#define SSL_REF_PARAMETER_OUT	102 /* for the INOUT params */

#define IS_SSL_REF_PARAMETER(type)	\
	((type) >= SSL_REF_PARAMETER)

#define IS_UNNAMED_PARAM(ssl) 	\
	(ssl && ssl->ssl_name && ssl->ssl_name[0] == ':' && isdigit (ssl->ssl_name[1]))

#define SSL_IS_VEC(ssl) (SSL_VEC == (ssl)->ssl_type)
#define SSL_IS_VEC_OR_REF(ssl) \
  (SSL_REF == (ssl)->ssl_type || SSL_VEC == (ssl)->ssl_type)


#define SSL_FLAGS \
    char		ssl_type; \
  dtp_t			ssl_dc_dtp; \
    bitf_t		ssl_is_alias:1; \
    bitf_t		ssl_is_observer:1; \
    bitf_t		ssl_is_callret:1; \
    bitf_t		ssl_not_freeable:1; \
    bitf_t		ssl_qr_global:1; /* value either aggregating or invariant across qr */ \
  bitf_t	ssl_always_vec:1; \
  bitf_t	ssl_vec_param:2; /* in vectored proc in/inout/out */ \
  ssl_index_t	ssl_index; \
  ssl_index_t		ssl_box_index; /*if vectored and needs box for single state ops, place in qst for this */ \
  sql_type_t		ssl_sqt


struct state_slot_s
  {
    SSL_FLAGS;
    ssl_index_t		ssl_sets; /* if this is a cast or a search param where nulls can occur, there will be filtering.  Correlate the values to the rows of input */
    ssl_index_t		ssl_n_values;
    caddr_t	ssl_constant;
    char *		ssl_name;
    dbe_column_t *	ssl_column;
    struct state_slot_s *ssl_alias_of;
};


/* ssl_vec_param */
#define SSL_VP_IN 1
#define SSL_VP_OUT 2
#define SSL_VP_RET 3


struct state_slot_ref_s
  {
    SSL_FLAGS;
    short	sslr_distance;
    ssl_index_t *	sslr_set_nos;
    state_slot_t *	sslr_ssl;
};

#define sslr_index ssl_index
#define sslr_box_index ssl_box_index

#define ssl_dtp ssl_sqt.sqt_dtp
#define ssl_prec ssl_sqt.sqt_precision
#define ssl_scale ssl_sqt.sqt_scale
#define ssl_class ssl_sqt.sqt_class
#define ssl_non_null ssl_sqt.sqt_non_null


typedef state_slot_t state_const_slot_t;

#define ssl_next_const ssl_alias_of
#define ssl_const_val ssl_constant


#define SSL_HAS_NAME(ssl) (/*ssl->ssl_type != SSL_CONSTANT &&*/ ssl->ssl_name)

#define QST_GET(qst,ssl) \
  (ssl->ssl_type < SSL_VEC ? ((caddr_t*)qst)[ssl->ssl_index] : \
   (ssl->ssl_type < SSL_CONSTANT ? sslr_qst_get (qst, (state_slot_ref_t*)ssl, ((query_instance_t*)qst)->qi_set) : \
(ssl->ssl_type > SSL_CONSTANT ? ((caddr_t**)qst)[ssl->ssl_index][0] : ssl->ssl_constant)))

#define QST_GET_ADDR(qst,ssl) \
  (ssl->ssl_type < SSL_CONSTANT ? (((caddr_t*)qst) + ssl->ssl_index) : (ssl->ssl_type > SSL_CONSTANT ? ((caddr_t**)qst)[ssl->ssl_index] : &(ssl->ssl_constant)))

#define QST_GET_V(qst,ssl) \
  (((caddr_t*)qst)[ssl->ssl_index])


#define QST_INT(qst, inx) ((ptrlong*)qst)[inx]
#define QST_BOX(dt, qst, inx) ((dt*)qst)[inx]

#define SSL_IS_UNTYPED_PARAM(ssl) 	\
	(DV_UNKNOWN == (ssl)->ssl_dtp)


#define QST_PLONG(qst, inx) \
  (* ((ptrlong *) &qst[inx]))


typedef struct cl_buffer_s
{
  ssl_index_t		clb_fill; /*inx into qst */
  ssl_index_t		clb_nth_set; /* inx of long in qst, the set being received */
  ssl_index_t		clb_nth_context;
  bitf_t		clb_keep_itcl_after_end:1;
  int			clb_batch_size; /* set by compiler.  Do so many param rows */
  state_slot_t *	clb_params;
  state_slot_t **	clb_save; /* for a select, the stuff calculated earlier, to go together with each output */
  state_slot_t *	clb_clrg;
  state_slot_t *	clb_itcl;
} cl_buffer_t;


#define CLB_AT_END(clb, inst)\
  { if (!clb.clb_keep_itcl_after_end) qst_set (inst, clb.clb_itcl, NULL); }


#define CL_RUN_STARTED(qn, inst)		\
  { \
    data_source_t * __qn = (data_source_t *)qn;	\
    query_t * __qr = __qn->src_query; \
    if (__qr->qr_cl_run_started) \
      ((caddr_t*)inst)[__qr->qr_cl_run_started] = (caddr_t)(ptrlong)1; \
}

typedef struct setp_save_s
{
  /* save state for cluster batch  execution of setp/fref pairs */
  state_slot_t *	ssa_array;
  state_slot_t *	ssa_set_no; /* no of top level set that is on the qst */
  int			ssa_batch_size;
} setp_save_t;


typedef struct ssa_iter_node_s
{
  data_source_t 	src_gen;
  int		ssi_state;
  struct setp_node_s *	ssi_setp;
  state_slot_t *	ssi_set_no_shadow;
  state_slot_t *	ssi_org_set_no;
} ssa_iter_node_t;

#define IS_QN(qn, in) ((qn_input_fn)in == ((data_source_t*)qn)->src_input)
#define IS_SSI(qn) ((qn_input_fn)ssa_iter_input == ((data_source_t*)qn)->src_input)

typedef struct cl_fref_red_node_s
{
  /* on coordinator, node reading the sets from a partitioned gby/oby qf */
  data_source_t 	src_gen;
  cl_buffer_t		clb;
  struct fun_ref_node_s *	clf_fref;
  int			clf_status;
  char			clf_no_order;
  struct clo_comp_s **		clf_order;
  struct setp_node_s *		clf_setp;
  int			clf_set_no;
  int			clf_nth_in_set;
  dk_set_t		clf_out_slots;
} cl_fref_read_node_t;



struct proc_name_s
{
  int 		pn_ref_count;
  query_t *	pn_query;
  char		pn_name[1];
};

#define QI query_instance_t

struct query_s
  {
    int			qr_ref_count;
    int			qr_trig_order;
    int			qr_instance_length;
    int 		qr_dc_est;
    short		qr_cl_run_started; /*inx into qi, flag set when cl multistate qr running, no more input states allowed until outputs consumed */
    bitf_t		qr_is_ddl:1;
    bitf_t		qr_is_complete:1; /* false while trig being compiled */
    bitf_t 		qr_lock_mode:3;
    bitf_t		qr_no_cast_error:1;
    bitf_t		qr_to_recompile:1;
    bitf_t		qr_parse_tree_to_reparse:1;
    bitf_t		qr_no_co_if_no_cr_name:1;	/* if select stmt exec'd from client */
    bitf_t  		qr_text_is_constant:1;
    bitf_t		qr_is_bunion_term:1;
    bitf_t		qr_is_remote_proc:1;
    bitf_t		qr_unique_rows:1;
    bitf_t		qr_is_qf_agg:2;  /* true if this is clustered aggregate fragg's qr */
    bitf_t		qr_brk:1;
    bitf_t		qr_is_call:2; /* true if this is top level proc call */
    bitf_t		qr_remote_mode:2;
    bitf_t		qr_cursor_type:2;
    bitf_t		qr_trig_time:2;	/*!< If trigger, time of launch: before/after/instead */
    bitf_t		qr_trig_event:2;	/*!< If trigger, type of event: insert/delete/update */
    bitf_t		qr_cl_locatable:2; /* can run in aquery frag, yes/no/unknown */
    bitf_t		qr_cl_qf_freed:1; /* if freed but still around because of pending qi's */
    bitf_t		qr_last_qi_may_free:1; /* if freed but still around because of pending local qi's */
    bitf_t		qr_proc_vectored:2;
    bitf_t		qr_vec_opt_done:1;
    bitf_t		qr_need_enlist:1; /* in cluster, if run in read committed, still need enlist because of unknown function calls  which may update */
    bitf_t		qr_is_mt_insert:1;
    char			qr_hidden_columns;
    char			qr_n_stages; /* if represents distr frag */
    /* The query state array's description */
    dk_set_t		qr_state_map;
    state_slot_t **	qr_freeable_slots;
    state_slot_t **	qr_vec_ssls;
    state_slot_t **	qr_qp_copy_ssls;
    state_const_slot_t *	qr_const_ssls;
    dk_set_t 		qr_temp_spaces;
    dk_set_t		qr_ssl_refs;
    struct select_node_s *qr_select_node;

    /* The query's instantiation */
    dk_set_t		qr_parms;
    caddr_t *		qr_parm_default;
    caddr_t * 		qr_parm_alt_types; /* an alternative type */
    caddr_t *		qr_parm_soap_opts; /* SOAP options to params */
    caddr_t *		qr_parm_place;     /* where is it exposed (SOAP)*/
    dk_set_t		qr_nodes;
    dk_set_t		qr_bunion_reset_nodes; /* for a bunion term, nodes of enclosing qr that make up this term and are to be reset when resetting the bunion term, on error */
    dk_set_t		qr_used_cursors;
    data_source_t *	qr_head_node;
    query_t *		qr_super;


    caddr_t		qr_proc_name;	/*!< If SQL procedure, this is the name */
    proc_name_t *	qr_pn;
    caddr_t		qr_trig_table;	/*!< If trigger, name of table */
    user_aggregate_t *  qr_aggregate;	/*!< If user-defined aggregate, this points to the implementation */
    oid_t *		qr_trig_upd_cols;
    dbe_table_t *	qr_trig_dbe_table;
    caddr_t *		qr_trig_old_cols;
    state_slot_t **	qr_trig_old_ssl;
    oid_t		qr_proc_owner;
    dk_hash_t *		qr_proc_grants;
    caddr_t		qr_proc_ret_type;
    caddr_t		qr_proc_alt_ret_type;
    caddr_t *		qr_proc_soap_opts; /* SOAP options to procedure */
    long		qr_proc_place;

    /* client statement cache */
    query_t *		qr_next;
    query_t *		qr_prev;
    caddr_t		qr_text;
    dk_set_t		qr_used_tables;  /* ref'd tables' qualified names */
    dk_set_t		qr_used_udts;  /* ref'd udts' qualified names */
    dk_set_t		qr_used_jsos;  /* ref'd JSO IRIs (for SPARQL queries with quad maps) */
    caddr_t		qr_qualifier; /* qualifier current when this was compiled */
    caddr_t		qr_owner;
    struct union_node_s *	qr_bunion_node;

    struct query_cursor_s *	qr_cursor;
    state_slot_t **	qr_xp_temp;
    dk_set_t		qr_unrefd_data;	/* garbage, free when freeing qr */
    dk_set_t		qr_proc_result_cols; /* needed by SQLProcedureColumns */
    dk_set_t		qr_subq_queries;

    query_t		*qr_module;
    dk_set_t		qr_temp_keys;

#ifdef PLDBG
    caddr_t 		qr_source; 	 /* source file */
    int 		qr_line;	 /* offset from file */
    long 		qr_calls;	 /* how many times it called */
    dk_hash_t 		*qr_line_counts; /* test coverage line stats */
    id_hash_t 		*qr_call_counts;  /* test coverage caller stats */
    long		qr_time_cumulative; /* test coverage cumulative time for execution */
    long 		qr_self_time;
    dk_mutex_t		*qr_stats_mtx;	  /* for protection on stats hash tables see above */
#endif
    caddr_t		*qr_udt_mtd_info; /* not null if CREATE METHOD */
    long 		qr_obsolete_msec;
    caddr_t		qr_parse_tree;
    float *		qr_proc_cost; /* box of floats: 0. unit cost 1. result set rows 2...n+2 multiplier if param 0...n is not given */
    int64		qr_qf_id; /* if this is a frag qr, the id as in cll_id_to_qf */
    state_slot_t **	qr_qf_params;
    state_slot_t **	qr_qf_agg_res;
    state_slot_t **	qr_qf_multistate_agg_params;
    struct stage_node_s **	qr_stages;
#if defined (MALLOC_DEBUG) || defined (VALGRIND)
    const char *	qr_static_source_file;
    int			qr_static_source_line;
    struct query_s *	qr_static_prev;
    struct query_s *	qr_static_next;
    int			qr_chkmark;
#endif
  };
#define QF_AGG_MERGE 1 /* it is group by with std aggregates to be merged on  coordinator */
#define QF_AGG_PARTITIONED 2 /* the aggregations are distinct, no adding up */
#define QF_AGG_PARTITIONED_GBY 3 /* the aggregations are distinct, no adding up */

#if defined (MALLOC_DEBUG) || defined (VALGRIND)
#define DK_ALLOC_QUERY(qr) { \
  qr = (query_t *) dk_alloc (sizeof (query_t)); \
  memset (qr, 0, sizeof (query_t)); \
  qr->qr_chkmark = 0x269beef; }
#else
#define DK_ALLOC_QUERY(qr) { \
  qr = (query_t *) dk_alloc (sizeof (query_t)); \
  memset (qr, 0, sizeof (query_t)); }
#endif

/* qr_proc_vectored */
#define QR_VEC_PROC 1
#define QR_VEC_STMT 2

/* qr_remote_mode values */

#define QR_LOCAL	0
#define QR_MIXED	1
#define QR_PASS_THROUGH	2


#define QR_IS_MODULE_PROC(qr) (((qr)->qr_module != NULL && (qr)->qr_module != (query_t *) 1))
#define QR_IS_MODULE(qr) ((qr)->qr_module == (query_t *) 1)

typedef void (*row_callback_t) (caddr_t * state);


/* Query state array */

#define QST_FIRST_FREE	1


/* Query global slots in the query instance */

#define QI_ALL_GENERATED 0
#define QI_IS_DEAD 1

#define CALLER_LOCAL	((query_instance_t *) 1L)
#define CALLER_CLIENT	((query_instance_t *) 2L)


#define qi_space qi_thread  /* temp schemas etc are in function of this, not something else */
#define QI_NO_SLICE 0xffff /* indicates qi is not scoped to any slice in elastic cluster */


typedef struct query_instance_s
  {
    query_t *		qi_query;
    struct srv_stmt_s *	qi_stmt;
    caddr_t		qi_cursor_name;
    lock_trx_t *	qi_trx;
    struct query_instance_s *qi_caller;

    du_thread_t *	qi_thread;
    struct client_connection_s *qi_client;
    int			qi_ref_count;
    slice_id_t		qi_slice; /* if slice-specific qi in a dfg, this is the slice */
    char		qi_threads;
    char		qi_isolation;
    bitf_t              qi_lock_mode:3;
    bitf_t		qi_is_allocated:1;
    bitf_t		qi_autocommit:1;
    bitf_t		qi_no_triggers:1;
    bitf_t		qi_assert_found:1; /* gpf if next select gets 'not found */
    bitf_t 		qi_pop_user:1;
    bitf_t 		qi_no_cast_error:1;
    bitf_t		qi_non_txn_insert:1; /* make insert not subject to rb and log it immediately */
    bitf_t		qi_is_partial:1; /* was interrupted by anytime timeout */
    bitf_t		qi_dfg_anytimed:1;
    bitf_t		qi_vec_from_scalar:1;
    bitf_t		qi_is_branch:1;
    bitf_t		qi_is_dfg_slice:1;
    bitf_t		qi_slice_needs_init:1; /* if just created empty while reading dfg feed, init after processing the input, not in cll mtx */
    bitf_t		qi_slice_merits_thread:1;
    bitf_t		qi_is_cl_root; /* top level qi invoking cluster ops.  When freed, free the recursive cluster calls queue */
    bitf_t		qi_has_dfgs:1;
    bitf_t		qi_log_stats:1; /* log cli activity after this qi completes */
    char		qi_dfg_running;
    uint32		qi_root_id;
    int32		qi_rpc_timeout;
    int32		qi_prefetch_bytes;
    int32		qi_bytes_selected;
    oid_t		qi_u_id;
    oid_t		qi_g_id;

    int64		qi_n_affected;
    caddr_t		qi_proc_ret; /* if proc call and qi_caller == client, proc ret block */
    du_thread_t *	qi_thread_waiting_termination;
    struct local_cursor_s *qi_lc;
    struct icc_lock_s	*qi_icc_lock;	/* Pointer to an InterConnectionCommunication lock to be released at exit */
    struct object_space_s *qi_object_space;
    mem_pool_t *	qi_mp;
    dtp_t *		qi_set_mask; /* which places in vectors are active in a conditional branch of a cectored code vec */
    int			qi_set; /*inx of current  value in vectored code vec.  Use for scalar ops like function call */
    int			qi_n_sets; /* when running code vec, no of sets */
    struct select_node_s *	qi_branched_select; /* if a exists/scalar subq made this qi as a parallel branch, this is the select node ending the subq.  Need to know for results merge */
#ifdef PLDBG
    void * 		qi_last_break;
    int 		qi_step;
    int 		qi_child_time;
#endif
  } query_instance_t;


#define QST_INSTANCE(qi)	(qi)

#define QI_ROW_AFFECTED(qi)	\
{ \
  ((query_instance_t *) qi)->qi_n_affected++; \
  if (((query_instance_t*)qi)->qi_client->cli_row_autocommit) \
    ((query_instance_t *)qi)->qi_client->cli_n_to_autocommit++; \
}

#define QI_FIRST_FREE		(sizeof (query_instance_t) / sizeof (caddr_t) + 1)

#define QI_SPACE(qi)		((query_instance_t *) qi)->qi_space

#define QI_TRX(qi)		((query_instance_t *) qi)->qi_trx

#define QST_CHARSET(qi)		\
        (GET_IMMEDIATE_CLIENT_OR_NULL ? ((client_connection_t *)(GET_IMMEDIATE_CLIENT_OR_NULL))->cli_charset : \
	(!qi ? (((wcharset_t *) NULL) + GPF_T1 ("no QI")) : \
	(((query_instance_t *) qi)->qi_client ? \
	 ((query_instance_t *) qi)->qi_client->cli_charset : ((wcharset_t *) NULL))))


typedef struct hash_area_s
{
  state_slot_t *	ha_tree;
  state_slot_t *	ha_ref_itc;
  state_slot_t * 	ha_insert_itc;
  state_slot_t *	ha_set_no;
#ifdef NEW_HASH
  state_slot_t * 	ha_bp_ref_itc;
#endif
  dbe_key_t *		ha_key;
  dbe_col_loc_t *	ha_key_cols; /* the col locs of the hash temp, key fix, key var, dep fix, dep var */
  dbe_col_loc_t *	ha_cols;	/* cols of feeding table, correspond to ha_key_cols */
  state_slot_t **	ha_slots;	/* slots where values to feed come from if they do not come from columns direct */
  struct hash_area_s *	ha_org_ha; /* can be a temp ha on stack for merge of gby or such, must ref the originnal allocated ha in the ht */
  int			ha_n_keys;
  int			ha_n_deps;
  char 			ha_op;
  char			ha_allow_nulls;
  char			ha_memcache_only; /* flags if the hash may not reside on disk */
  long 			ha_row_size;
  uint64 			ha_row_count;
  /*chash fields */
  int	ha_ch_len;
  int	ha_ch_nn_flags; /* offset of non-null flags in chash row */
  char	ha_ch_unique;
} hash_area_t;

#define CHASH_GB_MAX_KEYS 20


#define HA_DISTINCT 1
#define HA_ORDER 2
#define HA_GROUP 3
#define HA_FILL 4
#define HA_PROC_FILL 5


typedef struct clo_comp_s
{
  short			nth;
  char			is_desc; /* in merging asc/desc mixed sorts , must know the order col by col */
  dbe_column_t *	col;
} clo_comp_t;


typedef int (*row_check_func_t) (it_cursor_t * itc, buffer_desc_t * buf);

struct key_source_s
  {
    dbe_key_t *		ks_key;
    clo_comp_t **	ks_cl_order; /* if results from many cluster nodes, given them in key order? If so, this is the compare order in result rows. */
    state_slot_t *	ks_init_place;
    key_spec_t 		ks_spec;
    unsigned char	ks_spec_nth;
    unsigned char	ks_n_vec_sort_cols; /* how many first search params participate in sorting of vectored param set */
    char		ks_copy_search_pars; /* in dfg, the itc's pars must be copies owned by the itc */
    int			ks_init_used;
    int			ks_param_nos; /* array for sorting params in vector exec */
    search_spec_t *	ks_row_spec;
    row_check_func_t	ks_row_check;
    dk_set_t		ks_out_cols;
    dk_set_t		ks_out_slots;
    caddr_t *		ks_out_col_ids; /* ready for cluster rpc */
    out_map_t *	ks_out_map; /* inline array of dbe_col_locs for each member of ks:_out_slots for the matching key */
    v_out_map_t *	ks_v_out_map;
    state_slot_t *	ks_from_temp_tree;	/* tree of group or order temp or such */
    state_slot_ref_t **	ks_vec_source; /* if need align or cast of searchh pars for vectored exec */
    state_slot_t **	ks_vec_cast;
    dc_val_cast_t *	ks_dc_val_cast;
    state_slot_t *	ks_last_vec_param; /* used for getting the count of param rows after casts */
    state_slot_t **	ks_cl_local_cast; /* can be a ssl in a qf or dfg is refd many times with different expected types, e.g. iri cast to any for a ks and used as typed iri in a gby.  If so, pass without cast in qf/dfg message and cast only at the receiving end.  This is pairs of source/target ssls.  Can only occur in 1st ks of qf or dfg since its ks_vec_cast is taken over by the cast and partitioning of the qf/dfg */
    char *		ks_cast_null; /* flags about what to do for a null (drop row of params, pass it or error  */
    state_slot_t **	ks_scalar_partition; /* non-vector ssls that go into partition hash if this is a loc ks of a partitioned op */
    col_partition_t **	ks_vec_cp;
    col_partition_t **	ks_scalar_cp;
    state_slot_t *	ks_first_row_vec_ssl;
    struct setp_node_s *	ks_from_setp;
    state_slot_t *		ks_set_no; /* if ks reading a gby/oby temp, this is ssl ref to the set no from the set ctr at the start of the qr */
    ssl_index_t			ks_pos_in_temp; /* if mem sort, pos in the sort while reading.  Inx in inst. if chash, pos inside the chash page  */
    ssl_index_t		ks_nth_cha_part;  /* when reading chash, nth partition */
    ssl_index_t		ks_cha_chp; /* when reading chash, the chash_page_t */

    code_vec_t		ks_local_test;
    code_vec_t		ks_local_code;
    char		ks_descending;	/* if reading from end to start */
    char		ks_is_vacuum;
    char		ks_isolation;
    char		ks_check;
    char		ks_is_last;	/* if last ks in join and no select or
					   postprocess follows.
					   True if fun ref query */
    bitf_t		ks_is_loc_of_txs:1; /* if dummy cluster location ks for a txs then ks_ts is the text_source_t */
    bitf_t		ks_is_qf_first:1; /* the first in a cluster partition has its ks vec params set by the partitioning node so the cast dcs are ready to be set as search params */
    bitf_t		ks_is_flood:2; /* partitioning ks of qf does not have eq on all partitioning columns, goes to all partitions.  If 2 is fill of replicated hash join temp, goes round tobin to any slice of recipient host */
    bitf_t		ks_vec_asc_eq:1;
    bitf_t		ks_oby_order:1;
    bitf_t		ks_is_deleting:1;
    bitf_t		ks_is_vec_plh:1;
    bitf_t		ks_is_proc_view:1;
    state_slot_t *	ks_proc_set_ctr;
/*    char 			ks_local_op; */
    struct setp_node_s *	ks_setp;
    state_slot_t *		ks_set_no_col_ssl; /* if reading gby temp with set no in gb key, ssl for retrieving this, use as set no of retrieved row */
#ifdef NEW_HASH
    hash_area_t *		ks_ha;
#endif
    dk_set_t	ks_always_null; /* cols which are always forced to be null */
    state_slot_t *  ks_grouping; /* ssl with grouping bitmap */
    /* cluster */
    state_slot_t **		ks_qf_output; /* if last ks of value producing qf, then send these as result row. */
    struct table_source_s *	ks_ts;
    dk_set_t	ks_hash_spec; /* hash fill frefs that cause this ts to filter out rows either as hash filler or as hash probe */
    ssl_index_t *	ks_hs_partition_spec;
};

/*ks_is_flood */
#define KS_FLOOD_HASH_FILL 2

#define ks_itcl ks_ts->clb.clb_itcl

#define KS_SPC_DFG 2 /* copy search pars local and remote */
#define KS_SPC_QF 1 /* copy search pars on local only */



typedef struct inx_locality_s
{
  int		il_n_read;
  int		il_last_dp;
  int		il_n_hits;
} inx_locality_t;

#define IOP_KS 1
#define IOP_AND 2
#define IOP_OR 3


#define IOP_INIT 0
#define IOP_ON_ROW 1
#define IOP_AT_END 2
#define IOP_NEW_VAL 4
#define IOP_READ_INDEX 5 /*for a bitmap iop, means must read inx because the cached bm does not have the range */

typedef struct inx_op_s
{
  /* Members of an operator node combining multiple indices */
  int		iop_op;
  struct inx_op_s *	iop_parent;
  struct inx_op_s ** 	iop_terms;
  state_slot_t **	iop_max;
  state_slot_t *	iop_state; /* pre-init, on row, at end */

  /* Members for the leaves, the actual indices */
  key_source_t * 	iop_ks;
  key_spec_t 	iop_ks_start_spec;
  key_spec_t 	iop_ks_full_spec;
  search_spec_t *	iop_ks_row_spec;
  state_slot_t **	iop_out;
  state_slot_t * 	iop_itc;
  struct inx_op_s *	iop_other; /* most selective term of the inx int */
  state_slot_t *	iop_target_ssl;
  dtp_t 		iop_target_dtp; /* dtp of the intersectable col */
  unsigned char	iop_ks_start_spec_nth;
  unsigned char	iop_ks_full_spec_nth;
  /* bitmap index */
  state_slot_t * 	iop_bitmap;
  inx_locality_t	iop_il;
  /* cluster */
  int		iop_nth_set;
  int		iop_nth_term; /* for the and node, the inx of the term currently being read */
  int		iop_cl_pending; /* unprocessed stuff in this cl iop? */
  int		iop_first_at_end; /* true if the leftmost term is read to end */
} inx_op_t;


typedef int (*ts_alt_func_t)(struct table_source_s * ts, caddr_t * inst, caddr_t * state);

typedef struct table_source_s
  {
    data_source_t	src_gen;
    cl_buffer_t		clb;
    float		ts_cardinality; /* cardinality estimate from compiler */
    float		ts_inx_cardinality; /* card est with only indexed preds counted, use for splitting a scan where some keading keys are given */
    float		ts_cost_after; /* cost of nodes after this, per row of output from this */
    float		ts_cost;
    key_source_t *	ts_order_ks;
    key_source_t *	ts_main_ks;
    state_slot_t *	ts_order_cursor;
    state_slot_t *	ts_current_of;
    int			ts_batch_sz;
    short		ts_qp_max;
    bitf_t		ts_is_unique:1;	/* Only one hit expected, do not look for more */
    bitf_t		ts_is_outer:1;
    bitf_t		ts_is_random:1; /* random search */
    bitf_t 		ts_no_blobs:1;
    bitf_t		ts_need_placeholder:1;
    bitf_t		ts_is_alternate:2;
    bitf_t 		ts_alternate_inited:1;
    bitf_t		ts_order:2;
    bitf_t		ts_card_measured:1; /* is cardinality baesd on sample, i.e. reliable */
    bitf_t		ts_branch_by_value:1; /* if parallelizing scan, divide at value boundaries so that if order col is group col groups are guaranteed distinct */
    bitf_t 		ts_no_mt_in_row_ac:1; /* set if mt ts before upd/del, must not commit while mt branches are pending */
    bitf_t		ts_in_index_path:1;
    caddr_t		ts_rnd_pcnt;
    code_vec_t		ts_after_join_test;
    struct inx_op_s *	ts_inx_op;
    state_slot_t *	ts_aq;
    state_slot_t *	ts_aq_qis; /* when this splits into many threads, this holds the per thread qis as an array */
    state_slot_t **	ts_branch_ssls;
    ssl_index_t *	ts_branch_sets;
    dbe_column_t *	ts_branch_col; /* if scan partitioned by range, this is the col */
    data_source_t *	ts_agg_node; /* if parallelizable in fref, this is the fref, if in scalar/exists subq, this is the select */
    ssl_index_t		ts_aq_state;
    ssl_index_t		ts_nth_slice; /* if group by reader with many known to be disjoint qi's, this is the inx of the branch being read */
    inx_locality_t	ts_il;
    hash_area_t *	ts_proc_ha; /* ha for temp of prov view res.  Keep here to free later */
    ts_alt_func_t 	ts_alternate_test;
    struct table_source_s *	ts_alternate;
    state_slot_t*		ts_alternate_cd;
    caddr_t			ts_sort_read_mask; /* array of char flags.  Set if in reading sort temp the item at the place goes into the output */
    short		ts_max_rows; /* if last of top n and a single state makes this many, then can end whole set */
    short		ts_prefetch_rows; /* recommend cluster end batch   after this many because top later */
  } table_source_t;

/* for alternate index path, flag whether ts is 1st or 2nd */
#define TS_ALT_PRE 1
#define TS_ALT_POST 2

/* ts_aq_state */
#define TS_AQ_NONE 0
#define TS_AQ_FIRST 1 /* this ts serves as an aq branch and should start the scan at the start. Alternately the scan bounds are in the search specs.  */
#define TS_AQ_PLACED 2 /* this ts serves as an aq branch and has a set initial position */
#define TS_AQ_SRV_RUN 3 /* aq server that is inited and running */
#define TS_AQ_COORD 4 /* this ts has aq branches. Going through its own slice of the row.  Not at end until aq branches  are */
#define TS_AQ_COORD_AQ_WAIT 5 /* this ts has aq branches.  The own part of the job is done but aq branches are not at end */



/* vectored alt index path */
typedef struct ts_alt_split_s
{
  data_source_t	src_gen;
  ssl_index_t	tssp_is_alt;
  char			tssp_inited;
  state_slot_t *	tssp_v1;
  state_slot_t *	tssp_v2;
  table_source_t *	tssp_alt_ts;
} ts_split_node_t;


typedef table_source_t sort_read_node_t;
typedef table_source_t chash_read_node_t;

typedef struct rdf_inf_node_s rdf_inf_pre_node_t;
typedef struct trans_node_s trans_node_t;


typedef struct iter_node_s
{
  state_slot_t *	in_output;
  state_slot_t *	in_values_array;
  state_slot_t *	in_vec_array; /* if each set of input iterates over different array */
  int			in_current_value;
  int		in_current_set;
  int		in_is_const;
} iter_node_t;


typedef struct  in_iter_node_s
{
  data_source_t	src_gen;
  iter_node_t	ii_iter;
  state_slot_t **	ii_values;
#define 	ii_output ii_iter.in_output
#define	ii_values_array ii_iter.in_values_array
#define ii_nth_set ii_iter.in_current_set
#define ii_nth_value ii_iter.in_current_value
  state_slot_t *	ii_outer_any_passed; /* if rhs of left outer, flag here to see if any answer. If not, do outer output when at end */
  void 	       *	ii_dfe;
} in_iter_node_t;


typedef struct outer_seq_end_s
{
  data_source_t	src_gen;
  struct set_ctr_node_s *	ose_sctr;
  state_slot_t *	ose_set_no;
  state_slot_t *	ose_prev_set_no;
  state_slot_t **	ose_out_slots; /* the ssls that are null for the outer row */
  state_slot_t **	ose_out_shadow; /* If vectored, ssl vec (not ref) ssls for the nullable columns.  Values are a solid copy of ose out slots */
  state_slot_t *	ose_bits;
  state_slot_t *	ose_buffered_row;
  int			ose_last_outer_set; /* set no of the last outer row.  inx of int in qi */
} outer_seq_end_node_t;


typedef struct set_ctr_node_s
{
  data_source_t	src_gen;
  cl_buffer_t	clb;
  state_slot_t *	sctr_set_no;
  state_slot_t *	sctr_ext_set_no; /* if run in a subq in a cond branch with qi set mask set, this is the external set no for each of the consecutive internal set nos in sctr_set_no */
  outer_seq_end_node_t *	sctr_ose;
  dk_set_t 			sctr_continuable; /* continuable nodes between the sctr and the ose */
  dk_set_t 			sctr_hash_spec; /* if before partitioned outer hash join, these sp's are the hash filler frefs that determine the partition */
  char				sctr_role;
  char				sctr_not_in_top_and;
} set_ctr_node_t;


/* sctr_role */
#define SCTR_TOP 0
#define SCTR_EXISTS SEL_VEC_EXISTS
#define SCTR_SCALAR SEL_VEC_SCALAR
#define SCTR_DT SEL_VEC_DT
#define SCTR_OJ 4


#define sctr_itcl clb.clb_itcl


typedef struct stage_sum_s
{
  int		ssm_n_empty_mores;
  char		ssm_state_recd;
  unsigned int64	ssm_n_states_recd;
  unsigned int64	ssm_in_sets; /* total input sets received by this stage of this node */
  unsigned int64	ssm_out_sets; /* total input sets processed to completion by this stage of this node */
  unsigned int64	ssm_produced_sets; /*total sent forward by this stage of this node */
  int64			ssm_recd_sets; /* sets reported as received by this stage of this host,  ssm_in_sets is the sets reported by senders as sent to this */
} stage_sum_t;


typedef struct stage_node_s
{
  data_source_t	src_gen;
  cl_buffer_t	clb;
  query_frag_t *	stn_qf;
  int		stn_nth; /* the stage number in the dfg */
  int	stn_coordinator_id; /* Host no of coordinator, slot in the inst, the node compiling the query will not always coordinate it */
  int		stn_state;
  float		stn_cost; /* cost per row of input from here to next stage */
  table_source_t *	stn_loc_ts; /* the ts that decides partition of next */
  state_slot_t *	stn_coordinator_req_no; /* the cm_req_no on coordinator which receives all coordinator targeted traffic. All cm's go out with this req no but this is used only by coordinator */
  state_slot_t * 	stn_dfg_state; /* dfg_stat clo with counts of locally done and forward sent */
  state_slot_t **	stn_params; /* the params to send to the next stage */
  state_slot_t **	stn_inner_params; /* ssls where the compact dc of the received params are, shadowing ssls in stn_params */
  state_slot_t *	stn_slice_qis;  /* array of per slice qis */
  state_slot_t *	stn_aq; /* aq for running the per slice qis */
  state_slot_t *	stn_bulk_input; /* array of arrays of cms, nned to be divided among the stn inputs before use */
  state_slot_t *	stn_input; /* array of cm clos that represent input from remote nodes for this stn */
  state_slot_t *	stn_dre; /* array of dres marking place in input dcsin the current param cm */
  ssl_index_t		stn_n_ins_in_out; /* count of fully consumed in batches in present out batch */
  ssl_index_t		stn_input_fill; /* qst int for last added in stn input array */
  ssl_index_t		stn_input_used;
  state_slot_t *	stn_current_input;
  int			stn_read_to; /* qst int, position in current input for the next clo of input */
  ssl_index_t			stn_out_bytes; /* qst int, bytes send to others by all non-first stn's of the dfg.  Cap on intm res size  */
  int			stn_reset_ctr;
  dk_set_t		stn_in_slots; /* same as stn params but now used to read rows in input into */
  char			stn_need_enlist; /* excl parts later in the chain, enlist from start */
} stage_node_t;

/* stn_state */
#define STN_INIT 1
#define STN_RUN 2



struct query_frag_s
{
  data_source_t		src_gen;
  cl_buffer_t		clb;
  state_slot_t *	qf_agg_org_itcl;
  state_slot_t * 	qf_set_no; /* if this is a dfg this is for keeping track of the set at the output */
  state_slot_t * 	qf_set_no_result; /* shadow of set no in return rows, correlate result to input row */
  dk_set_t		qf_nodes;
  data_source_t *	qf_head_node;
  table_source_t *	qf_loc_ts;
  state_slot_t **	qf_params;
  state_slot_t **	qf_inner_params; /* shadows of qf_params for use inside the qf.  Assign these from the clo params at exec */
  float			qf_cost;
  ssl_index_t		qf_wait_clocks;
  clo_comp_t **		qf_order;
  state_slot_t **	qf_inner_out_slots; /* the out slots of the qf before the shadow used for ref after qf - This is what running the qf sets */
  state_slot_t **	qf_result;
  dk_set_t 		qf_out_slots; /* set to itcl_out_slots */
  state_slot_t *	qf_slice_qis;
  state_slot_t *	qf_aq;
  int 			qf_dfg_state;
  state_slot_t *	qf_dfg_req_no; /* for the batch, the req no for getting results from all nodes */
  data_source_t *	qf_dml_node; /* if this is a wrapper on cluster upd/del, then this is the node that holds the clrg for the 2nd keys */
  state_slot_t *	qf_dfg_agg_map; /* in distr frag aggregation, string that gets a 1 at the place of every host with data */
  uint64		qf_id;
  short			qf_max_rows;
  char			qf_n_stages;
  char			qf_lock_mode;
  bitf_t		qf_is_update:1;
  bitf_t		qf_is_agg:2;
  char			qf_need_enlist; /* excl parts later in the chain, enlist from start */
  char			qf_nth; /* ordinal no of qf in qr, for debug */
  state_slot_t **	qf_agg_res;
  int			qf_agg_is_any;
  state_slot_t **	qf_trigger_args;
  int			qf_trigger_event; /* if this is i/d/u */
  dbe_table_t *	qf_trigger_table;
  oid_t *		qf_trigger_cols;

  state_slot_t **	qf_const_ssl; /* when ends in a group by, some slots must be inited.  If set, odd is value, next even is ssl to init to value */
  state_slot_t **		qf_local_save; /* for a result set making qf, (non agg, non upd), the save state that must be saved and restored between interrupting and continuing generating  a single result set from the qf */
  state_slot_t *		qf_keyset_state;
  stage_node_t **		qf_stages;

  /* during sql vec */
};

#define qf_itcl clb.clb_itcl

typedef struct qf_select_node_s
{
  data_source_t  	src_gen;
  state_slot_t *	qfs_itcl;
  state_slot_t **	qfs_out_slots;
  char			qfs_in_dfg;
} qf_select_node_t;


typedef struct dpipe_node_s
{
  data_source_t	src_gen;
  cl_buffer_t		clb;
  char			dp_is_order;
  char			dp_is_colocated; /* already in the right partition, just call the func locally */
  char			dp_is_read_only;
  struct cu_func_s **	dp_funcs;
  state_slot_t **	dp_inputs;
  state_slot_t **	dp_outputs;
  table_source_t *	dp_loc_ts;
  state_slot_t ***	dp_input_args;
  state_slot_t *	dp_local_cache; /* if this is colocated and has no dpipe, use this for remembering some results */
  state_slot_t *	dp_set_nos; /* if set mask is set, record which set no in dp corresponds to which in qi */
} dpipe_node_t;

#define dp_itcl clb.clb_itcl

typedef struct hash_source_s
{
  data_source_t		src_gen;
  cl_buffer_t		clb;
  ssl_index_t		hs_current_inx;
  ssl_index_t		hs_saved_hmk;
  ssl_index_t		hs_pos_in_set; /* If interrupted in mid resullt set, this is the position in the set */
  ssl_index_t 		hs_done_in_probe; /* set in inst if hash was unique on hash key and operation was merged into the node that produced the probe input */
  key_source_t *	hs_ks; /* for vectored casts, near same functionality so use ks */
  table_source_t *	hs_loc_ts;
  state_slot_t *	hs_hash_no;
  state_slot_t **	hs_ref_slots;
  hash_area_t *	hs_ha; /* shared with the filler setp */
  state_slot_t **	hs_out_slots;
  state_slot_t *	hs_cl_id;
  col_ref_t *		hs_col_ref;
  dbe_col_loc_t *	hs_out_cols;
  dk_set_t		hs_out_aliases;
  ptrlong *		hs_out_cols_indexes;
  char			hs_cl_part_opt; /* if explicit cluster partitioning option */
  char			hs_is_unique;
  char			hs_is_outer;
  char			hs_no_partition; /* if probe from inside exists/value subq/dt as outer then can't distinguish between not exists and out of partition so must not partition */
  char			hs_cl_partition; /* in cluster, is hash table replicated or partitioned on key or partitioned on key and colocated with probe */
  code_vec_t		hs_after_join_test;
  table_source_t *	hs_probe; /* the last ts in join order that binds a col that is input to here */
  ssl_index_t 		hs_is_partitioned; /* set by hash filler, indicates whether the probe must filter based on hash partitioning */
  struct fun_ref_node_s *	hs_filler;
  table_source_t *	hs_merged_into_ts;
  state_slot_t *	hs_part_ssl;
  float			hs_cardinality;
  ssl_index_t 	hs_part_min;
  ssl_index_t	hs_part_max;
  char 			hs_partition_filter_self; /* means that this hs will evaluate probe partition for each input because the place where the input is produced does not support filter in situ */
} hash_source_t;


/* hs_cl_partitioned */
#define HS_CL_REPLICATED 1 /* identical hash table is built on all hosts */
#define HS_CL_COLOCATED 2 /* hash table partitioned, same part key as probe */
#define HS_CL_PART 3 /* partitioned and not colocated, add a dfg stage or a new qf, split input on part key of hash */
#define HS_CL_COORD_ONLY 4 /* hash table exissts on coordinator only */
typedef struct hi_memcache_key_s {
  id_hashed_key_t hmk_hash;
  int hmk_var_len;
  hash_area_t *hmk_ha;
  caddr_t *hmk_data;
} hi_memcache_key_t;


typedef struct remote_table_source_s
  {
    data_source_t	src_gen;
    char *		rts_text;
    id_hashed_key_t	rts_text_hash_no;
    struct remote_ds_s *rts_rds;
    state_slot_t **     rts_out_slots;
    dk_set_t		rts_params;
    state_slot_t *	rts_remote_stmt;
    char		rts_is_outer;
    code_vec_t		rts_after_join_test;
    state_slot_t **	rts_trigger_args;
    int			rts_trigger_event; /* if this is i/d/u */
    dbe_table_t *	rts_trigger_table;
    oid_t *		rts_trigger_cols;
    state_slot_t *	rts_af_state;
    state_slot_t *	rts_param_rows;
    state_slot_t *	 rts_param_fill;
    state_slot_t *	rts_i_param;
    state_slot_t *	 rts_single_pending;
    int			rts_nth_set;
    caddr_t		 rts_remote_proc;
    int			rts_is_unique;
    query_t *		rts_policy_qr;
  } remote_table_source_t;


/* rts_parallel */
#define RTS_NO_PAR 0
#define RTS_PAR_RANGE 1 /* splits scan by range of a column */
#define RTS_PAR_SETS 2 /* is an index lookup that can be part in a parallel plan, may make new threads if many sets of input */

#define IS_RTS(n) 0

#define IS_TS(n) \
  ((qn_input_fn) table_source_input_unique == ((data_source_t*)(n))->src_input || \
   (qn_input_fn) table_source_input == ((data_source_t*)(n))->src_input)

#define IS_HS(qn) (((data_source_t *)qn)->src_input == (qn_input_fn)hash_source_input)

#define QNCAST(dt, v, q)  dt * v = (dt *) q


typedef struct subq_source_s
  {
    data_source_t	src_gen;
    state_slot_t **	sqs_out_slots;
    query_t *		sqs_query;
    char		sqs_is_outer;
    char		sqs_leading_of_qf;
    state_slot_t *	sqs_set_no;
    code_vec_t		sqs_after_join_test;
    int			sqs_batch_size;
  } subq_source_t;


typedef struct union_node_s
  {
    data_source_t	src_gen;
    state_slot_t *	uni_nth_output;
    dk_set_t		uni_successors;
    dk_hash_t *         un_refs_after;	/* in tracking ssl refs, do a union's continuation only once, remember the refd ssls here */
    short 		uni_op;
    char		uni_sequential; /* finish each branch before starting next.  Needed in except and intersect */
    char		uni_cl_colocate_delayed;
  } union_node_t;


#define TS_ORDER_ITC(ts, state) \
  * ((it_cursor_t **) &state[ts->ts_order_cursor->ssl_index])

#define TS_ORDER_RST(ts, state) \
  * ((remote_stmt_t **) &state[ts->rts_remote_stmt->ssl_index])



typedef void (*fnp_func_t) (data_source_t * fnp_node);



typedef struct ins_key_s
{
  dbe_key_t *		ik_key;
  dbe_column_t **	ik_cols;
  state_slot_t **	ik_slots;
  state_slot_t **	ik_del_slots;
  state_slot_t **	ik_del_cast;
  dc_val_cast_t *	ik_del_cast_func;
  ssl_index_t	ik_ins_slices;
  ssl_index_t	ik_del_slices;
} ins_key_t;


typedef struct insert_node_s
  {
    data_source_t	src_gen;
    cl_buffer_t		clb;
    dbe_table_t *	ins_table;
    oid_t *		ins_col_ids;
    dk_set_t		ins_values;
    char		ins_mode;
    char		ins_no_deps; /* true if all cols of tb are in pk */
    char		ins_vectored;
    state_slot_t **	ins_trigger_args;
    ins_key_t **	ins_keys;
    query_t *		ins_policy_qr;
    caddr_t		ins_key_only; /* key name, if inserting only this key, as in create index */
    state_slot_t *	ins_daq; /* in cluster, queue the insert here */
    state_slot_ref_t **	ins_vec_source;
    state_slot_t **	ins_vec_cast;
    dbe_col_loc_t **	ins_vec_cast_cl;
    state_slot_t *	ins_seq_val; /* if fetching ins, this is the col to be set after the existing value or filed from seq if new val made and inserted */
    state_slot_t *	ins_seq_name;
    state_slot_t *	ins_fetch_flag; /* set to 1 for the rows where there was insert */
    dbe_column_t *	ins_seq_col;
    v_out_map_t *	ins_v_out_map; /* output cols if fetching insert */
    ssl_index_t		ins_set_mask; /* in cluster local branch, indicates which rows in the cast in the iks are for delete, i.e. local */
    data_source_t *	ins_del_node; /* for replacing vectored */
  } insert_node_t;


#define INS_NORMAL	0
#define INS_SOFT	1 /* do not insert if prime key exists */
#define INS_REPLACING	2 /* replace row if prime key exists. */
#define INS_SOFT_QUIET 3 /* like soft but return end of set and not row if duplicate on cluster */

#define UPD_MAX_COLS 200
#define UPD_MAX_QUICK_COLS 30


typedef struct cl_mod_state_s
{
  state_slot_t *	cms_clrg;
  query_frag_t *	cms_qf; /* a cluster del/upd, if on criving node, refers to enclosing qf */
  int			cms_n_sets;
  int			cms_n_received;
  char			cms_is_cl_frag; /* true if containing upd/del is a part of a remote query frag execd as part of clustered upd/del */
} cl_mod_state_t;


typedef struct update_node_s
  {
    data_source_t	src_gen;
    cl_mod_state_t	cms;
    dbe_table_t *	upd_table;
    state_slot_t *	upd_place;
    oid_t *		upd_col_ids;
    state_slot_t **	upd_values;
    state_slot_ref_t **	upd_vec_source;
    state_slot_t **	upd_vec_cast;
    dbe_col_loc_t **	upd_vec_cast_cl;
    state_slot_t **	upd_pk_values; /* use for pk in txn log in col wise upd */
    state_slot_t **	upd_old_blobs; /* corresponds to upd_values , if blob col, uld value here */
    state_slot_t *	upd_cols_param;
    state_slot_t *	upd_values_param;
    char 		upd_no_keys;	/* if no key parts changed */
    /* opt for single col in row of known key */
    key_id_t		upd_exact_key; /* if no key parts */
    state_slot_t **	upd_quick_values;
    dbe_col_loc_t **	upd_fixed_cl;
    dbe_col_loc_t **	upd_var_cl;

    state_slot_t **	upd_trigger_args;
    int			upd_hi_id;  /* key for lookup of affected hi's in the lt */
    query_t *		upd_policy_qr;
    int 		upd_keyset; /* upd_cols intersects with the key cols of the
    				     ts_order_ks->ks_key of the  table_source_t before the update */
    state_slot_t *	upd_keyset_state; /* keeps an array of current pos, last pos and ht */
    ssl_index_t		upd_param_nos;
    char		upd_is_view;
    char		upd_pk_change;
    char		upd_row_only;
    char		upd_any_blob;
    ins_key_t **	upd_keys;
    ssl_index_t		upd_set_mask;
  } update_node_t;


typedef struct delete_node_s
  {
    data_source_t	src_gen;
    cl_mod_state_t	cms;
    dbe_table_t *	del_table;
    dbe_key_t *		del_key_only;
    state_slot_t *	del_daq;
    state_slot_t *	del_place;
    state_slot_t **	del_trigger_args;
    query_t *		del_policy_qr;
    ins_key_t **	del_keys;
    state_slot_t **	del_key_vals; /* the select before a searched delete gets values for all 2nd key parts.  Keep them here for cluster qf param passing */
    ssl_index_t		del_param_nos;
    ssl_index_t		del_set_mask; /* in cluster local branch, indicates which rows in the cast in the iks are for delete, i.e. local */
    char		del_is_view;
  } delete_node_t;


typedef struct end_node_s
  {
    data_source_t	src_gen;
  } end_node_t;


typedef struct code_node_s
{
  data_source_t	src_gen;
  cl_buffer_t	clb;
  code_vec_t	cn_code;
  dk_set_t	cn_continuable; /* value subq or existence tests, multistate */
  char		cn_is_order;
  char		cn_is_test;
  state_slot_t *	cn_set_no;
  state_slot_t **	cn_assigned;
  int 			cn_results; /* for each set, the assigned slots saved, in itcl pool */
  int			cn_state; /* whether gathering input, running the subqs or sending outputs */
} code_node_t;

#define cn_itcl clb.clb_itcl

typedef struct row_insert_node_s
  {
    data_source_t	src_gen;
    state_slot_t *	rins_row;
    int			rins_mode;	/* c.f. ins_node */
  } row_insert_node_t;


typedef struct key_insert_node_s
  {
    data_source_t	src_gen;
    state_slot_t *	kins_row;
    dbe_key_t *		kins_key;
  } key_insert_node_t;


typedef struct deref_node_s
  {
    data_source_t	src_gen;
    state_slot_t *	dn_ref;
    state_slot_t *	dn_row;
    state_slot_t *	dn_place;
    int dn_is_oid;		/* true if id is OID, 0 if id is a _ROW or
				   ruling part string. */
  } deref_node_t;


typedef struct pl_source_s
  {
    data_source_t	src_gen;
    state_slot_t *	pls_place;
    dbe_table_t *	pls_table;
    state_slot_t **	pls_values;
  } pl_source_t;


typedef struct current_of_node_s
  {
    data_source_t	src_gen;
    state_slot_t *	co_place;
    state_slot_t *	co_cursor_name;
    char *		co_cursor_place_name;
    dbe_table_t *	co_table;
  } current_of_node_t;


typedef struct select_node_s
  {
    data_source_t	src_gen;
    state_slot_t **	sel_out_slots;
    int			sel_n_value_slots; /* out cols, not counting
					      current ofs */
    int			sel_out_box;
    int			sel_out_fill;
    int			sel_out_quota;
    int			sel_current_of;
    int			sel_total_rows;
    char		sel_lock_mode;
    state_slot_t *	sel_top;
    state_slot_t *	sel_top_skip;
    state_slot_t *	sel_row_ctr;
    state_slot_t *	sel_row_ctr_array;
    state_slot_t **	sel_tie_oby;
    state_slot_t *	sel_set_no;
    state_slot_t *	sel_subq_org_set_no; /* if in cluster subq, the set no in the select node is shadowed by output of cl fref read or similar.  This is the unshadowed one for direct ref to subq start to know how many sets of input */
    state_slot_t *	sel_ext_set_no; /* if value subq in cond branch, local sets are consecutive but the set to assign the result is here, not consecutive */
    state_slot_t *	sel_prev_set_no; /* set no of prev row.  when changes, reset the top ctr */
    state_slot_t *	sel_cn_set_no; /* if in multistate exists or value subq, this is set no of containing code node.  As soon as one result is produced, advance the multistate qr to the next set as per this set no */
    state_slot_t *	sel_scalar_ret;
    set_ctr_node_t *	sel_set_ctr; /* if inlined subq ends here, this is the set ctr that marks the strat of the subq */
    ssl_index_t		sel_vec_set_mask; /* In vectored subq, if top = 1, bit mask where each exists marks a 1 at the set no.  If top > 1, array of ints with row count in the set in question. */
    ssl_index_t	sel_client_batch_start; /* set no of 1st result row in current batch of rows to sql client */
    char		sel_vec_role;
    char		sel_is_scalar_agg; /* scalar subq with aggregate and no group by */
    char		sel_subq_inlined;
  } select_node_t;

#define SEL_VEC_EXISTS 1
#define SEL_VEC_SCALAR 2
#define SEL_VEC_DT 3

#define SEL_NODE_INIT(cc, sel) \
  sel->sel_out_box = cc_new_instance_slot (cc); \
  sel->sel_out_fill = cc_new_instance_slot (cc); \
  sel->sel_current_of = cc_new_instance_slot (cc); \
  sel->sel_out_quota = cc_new_instance_slot (cc); \
  sel->sel_total_rows = cc_new_instance_slot (cc); \
  cc->cc_query->qr_select_node = sel;


typedef struct skip_node_s
{
  data_source_t 	src_gen;
  state_slot_t *	sk_top;
  state_slot_t *	sk_top_skip;
  state_slot_t *	sk_set_no;
  state_slot_t *	sk_row_ctr;
} skip_node_t;

typedef struct ddl_node_s
  {
    data_source_t	src_gen;
    caddr_t *		ddl_stmt;
  } ddl_node_t;


typedef struct gb_op_s
  {
    int			go_op;
    struct user_aggregate_s * go_user_aggr;
    state_slot_t **	go_ua_arglist;
    int go_ua_arglist_len;
    state_slot_t *	go_old_val;
    state_slot_t *	go_distinct;
    hash_area_t *	go_distinct_ha;
    instruction_t *	go_ua_init_setp_call;
    instruction_t *	go_ua_acc_setp_call;
  } gb_op_t;


typedef struct op_node_s
  {
    data_source_t	src_gen;
    long		op_code;
    state_slot_t *	op_arg_1;
    state_slot_t *	op_arg_2;
    state_slot_t *	op_arg_3;
    state_slot_t *	op_arg_4;
  } op_node_t;


typedef struct setp_node_s
  {
    data_source_t	src_gen;
    hash_area_t *	setp_ha;
    dk_set_t		setp_keys;
    dk_set_t		setp_key_is_desc;
    dk_set_t		setp_dependent;
    dk_set_t		setp_gb_ops;	/* AMMSC for group by */
    state_slot_t **	setp_merge_temps; /* temp ssls for adding up gnby/obys.  Same as the ssls where the result is read */
    char		setp_distinct;
    char		setp_set_op;
    char		setp_top_sort_distinct; /* when merging branches of top k obys, remove duplicates */
    char		setp_set_no_in_key;  /* multistate group by with set no as 1st grouping col */
    state_slot_t *	setp_top;
    state_slot_t *	setp_top_skip;
    state_slot_t *	 setp_row_ctr;
    state_slot_t **	setp_last_vals;
    state_slot_t **	setp_keys_box;
    state_slot_t *	setp_last;
    int			setp_ties;
    state_slot_t **	setp_dependent_box;
    state_slot_t *	setp_sorted;
    state_slot_t *	setp_flushing_mem_sort;
    struct fun_ref_node_s *	setp_ordered_gb_fref;
    struct fun_ref_node_s *	setp_fref;
    state_slot_t **	setp_ordered_gb_out;
    key_spec_t 	setp_insert_spec;
    hash_area_t *	setp_reserve_ha;
    char		setp_top_distinct; /* indicates combined distinct + top order by */
    char	                setp_any_distinct_gos;
    char			setp_any_user_aggregate_gos;
    char		setp_partitioned; /* oby or gby in needing no merge in cluster */
    char		setp_part_opt; /* 0 do what is best, 1 never partition, 2 partition always */
    char		setp_nth; /* ordinal number inside a set of grouping sets */
    char		setp_ignore_ua; /* when merging partitioned user aggregates, just copy */
    dk_set_t		setp_const_gb_args;
    dk_set_t		setp_const_gb_values;
    table_source_t *	setp_reader; /* node for sending the gby state in vectored cluster */
    setp_save_t	setp_ssa;
    table_source_t *	setp_loc_ts;
    float		setp_card;  /* for a group by, guess of how many distinct values of grouping cols */
    ssl_index_t 	setp_qfs_state;
    char		setp_is_qf_last; /* if set, the next can be a read node of partitioned setp but do not call it from the setp. */
    char		setp_is_streaming; /* a group by with ordering cols as grouping cols, results available in mid-grouping */
    char		setp_is_cl_gb_result;
    char		setp_in_union;
    state_slot_t *	setp_streaming_ssl; /* if grouping cols are ordering cols but have duplicates, this is the col to check for distinguishing known complete groups from possible incomplete groups */

    /* partitioned hash fill */
    state_slot_t *	setp_ht_id; /* id of ht for cluster hash fill */
    dk_set_t 	setp_hash_sources; /* hs nodes that ref the hash filled here */
    data_source_t *	setp_hash_part_filter; /* this filters out the rows that are not in partition.  Most often ts, sometimes the setp itself */
    search_spec_t *	setp_hash_part_spec; /* if hash join filler must make many partitions because too large, then this sp is applied to limit the probes si only stuff potentially in the hash is probed */
    state_slot_t *	setp_chash_clrg;
    state_slot_t *	setp_hash_part_ssl;
    ssl_index_t	setp_hash_fill_partitioned;
    ssl_index_t	setp_fill_cha; /* for chash join fill, the cha where the filler thread puts its rows */
    char	setp_no_bloom;
    char	setp_cl_partition;
} setp_node_t;

#define SETP_DISTINCT_MAX_KEYS 100
#define SETP_DISTINCT_NO_OP 2
#define IS_SETP(qn) IS_QN (qn, setp_node_input)

/* setp_set_op */
#define SO_NONE			0
#define SO_EXCEPT		1
#define SO_INTERSECT		2
#define SO_EXCEPT_ALL		3
#define SO_INTERSECT_ALL	4

typedef struct gs_union_node_s
  {
    data_source_t	src_gen;
    dk_set_t		gsu_cont;
    state_slot_t*	gsu_nth;
    int	is_outer;
  } gs_union_node_t;

typedef struct fun_ref_node_s
  {
    data_source_t	src_gen;
    cl_buffer_t		clb;
    data_source_t *	fnr_select;
    dk_set_t		fnr_select_nodes; /* continuable nodes in the fnr_select branch */
    int			fnr_is_any;
    char		fnr_is_top_level; /* true if at start of top level qr, false if inside loops.  Affects what anytime timeout does */
    char		fnr_is_cl_local_fake;
    dk_set_t		fnr_default_values;
    dk_set_t		fnr_default_ssls;
    dk_set_t		fnr_temp_slots;
    setp_node_t *	fnr_setp;
    dk_set_t	    fnr_setps;
    dk_set_t 		fnr_distinct_ha;
    hi_signature_t *	fnr_hi_signature;
    query_frag_t *	fnr_cl_qf; /* if the aggregation is done in remotes, this is the qf that holds the state */
    dk_set_t		fnr_cl_qfs; /* if a union followed by aggregation */
    dk_set_t		fnr_cl_merge_temps; /* for adding up aggs in cluster */
    setp_save_t		fnr_ssa; /* save for multiple set aggregation */
    char		fnr_partitioned;
    char		fnr_is_order; /* if partitioned setp, must read in order?*/
    char		fnr_is_set_ctr; /* if outermost multistate fref, double as a set ctr if no other set ctr */
    char		fnr_parallel_hash_fill;
    char		fnr_no_hash_partition;
    dk_set_t		fnr_prev_hash_fillers; /* This fun ref can produce output only when these hash fillers have gone through all partitions */
    state_slot_t *	fnr_cl_hash_id; /* id of the hash table filled by this fnr for ref in cluster hash join  */
    state_slot_t *	fnr_hash_part_ssl;
    ssl_index_t	fnr_n_part;
    ssl_index_t	fnr_nth_part;
    ssl_index_t fnr_hash_part_min;
    ssl_index_t fnr_hash_part_max;
    table_source_t *	fnr_stream_ts; /* the ts in select that parallelizes streaming group by */
    state_slot_t *		fnr_cha_surviving; /* in streaming group by, some groups can survive sending a batch of results. If they share the vallue of the latest grouping col, the next batch could update the groups */
    ssl_index_t	fnr_stream_state;
    ssl_index_t	fnr_current_branch; /* if parallel streaming, this branch was sent to output and must be continued next round */
    char	fnr_stream_ok_with_hash_part; /* true if streaming is still OK if hash join partitioning is applied.  True if stuff being agregated does not depend on the hash partition or if results depend on hash partitioning but are again aggregated without conditions  */
  } fun_ref_node_t;

/* fnr_partitioned */
#define FNR_PARTITIONED 1
#define FNR_REDUNDANT 2


/* fnr_is_streaming */
#define FNR_STREAM_DUPS 1 /* grouping cols come in order from the table they come from */
#define FNR_STREAM_UNQ 2 /* grouping cols do not repeat in the table where they come from */

#define IS_FREF(qn) ((qn_input_fn)fun_ref_node_input == ((data_source_t*)qn)->src_input)


#define FNR_NONE 0



typedef struct breakup_node_s
{
  data_source_t	src_gen;
  int		brk_current_slot;
  state_slot_t **	brk_output;
  state_slot_t **	brk_all_output;
} breakup_node_t;

#define SQL_NODE_INIT_NO_ALLOC(type, en, input, del) \
  data_source_init ((data_source_t *) en, sc->sc_cc, 0); \
  en->src_gen.src_input = (qn_input_fn) input; \
  en->src_gen.src_free = (qn_free_fn) del; \
  dk_set_push (&sc->sc_cc->cc_query->qr_nodes, (void *) en);

#define SQL_NODE_INIT(type, en, input, del) \
  NEW_VARZ (type, en); \
  SQL_NODE_INIT_NO_ALLOC(type, en, input, del) \

typedef struct comp_context_s
  {
    int			cc_instance_fill;
    char		cc_has_vec_subq;
    dk_set_t		cc_state_slots;
    id_hash_t *		cc_slots;
    query_t *		cc_query;
    dbe_schema_t *	cc_schema;
    caddr_t		cc_error;
    struct comp_context_s *cc_super_cc;
    dk_hash_t * 	cc_keep_ssl;
  } comp_context_t;

#define CC_INIT(cc, cli) \
  memset (&cc, 0, sizeof (cc)); \
  cc.cc_query = qr; \
  cc.cc_instance_fill = QI_FIRST_FREE; \
  cc.cc_schema = wi_inst.wi_schema; \
  if (cli->cli_new_schema) \
    cc.cc_schema = cli->cli_new_schema; \
  cc.cc_super_cc = &cc;


#define QR_POST_COMPILE(qr, cc) \
  qr->qr_instance_length = cc->cc_super_cc->cc_instance_fill * sizeof (caddr_t); \
  dk_free_box (qr->qr_qualifier); \
  qr->qr_qualifier = box_dv_short_string (sqlc_client ()->cli_qualifier); \
  qr_set_freeable (cc, qr);


/* Query node types */

#define QNT_TABLE 1
#define QNT_INSERT 2


/* Statement return codes - from ODBC */

#ifndef SQL_SUCCESS
# define SQL_ERROR		(-1)
# define SQL_INVALID_HANDLE	(-2)
# define SQL_NEED_DATA		99
# define SQL_NO_DATA_FOUND	100
# define SQL_SUCCESS		0
# define SQL_SUCCESS_WITH_INFO	1

# define SQL_CONCUR_READ_ONLY	1
# define SQL_CONCUR_LOCK	2
# define SQL_CONCUR_ROWVER	3

#endif

#define SQL_SQLEXCEPTION	101

#define HANDT_CONTINUE		1
#define HANDT_EXIT		0
/* Connections, Users etc */

typedef struct srv_stmt_s
  {
    caddr_t		sst_id;
    query_t *		sst_query;
    query_instance_t *	sst_inst;
/*  dk_mutex_t *	sst_mtx; */
    caddr_t *		sst_param_array;
    int			sst_parms_processed;
    struct cursor_state_s * sst_cursor_state;
    uint32		  sst_start_msec;

/* PL scrollable */
    int			sst_is_pl_cursor;
    caddr_t		sst_pl_error;
    /* multistate */
    caddr_t *		sst_qst; /* same as sst_inst */
    struct cl_call_stack_s *	sst_cl_stack; /* keep the top cluster req no between batches of a cursor */
    int		sst_vec_n_rows;
    char	sst_is_started;
  } srv_stmt_t;


typedef struct user_s
  {
    caddr_t		usr_name;		/*!< User's login name. */
    caddr_t		usr_pass;		/*!< User's password, non encrypted. The U_PASSWORD field is filled via xx_encrypt_passwd() of this password and user's name. */
    oid_t		usr_id;			/*!< The internal ID, stored as U_ID. */
    oid_t		usr_g_id;		/*!< The ID of the default group of the user. User belongs to his default group same style as to any other group. */
    dk_hash_t *		usr_grants;		/*!< Unused and set to NULL in the server, plugings may use for their internal data. The hashtable under the pointer is not freed or otherwise altered by the server if user is dropped. */
    caddr_t		usr_data;		/*!< Values of U_DATA field, typically of sort "Q DB" */
    ptrlong *		usr_g_ids;		/*!< Sorted vector of groups that contain the given user */
    ptrlong *		usr_member_ids;		/*!< Sorted vector of users and groups that are members of this group */
    oid_t *		usr_flatten_g_ids;	/*!< Sorted list of sources of permissions, transitively, including self. The vector can be longer than \c usr_flatten_g_ids_len, with spare place at the end. The vector is fileld on demand and its length is reset to zero in case of changes in related roles */
    int			usr_flatten_g_ids_len;	/*!< The length of used beginning of \c usr_flatten_g_ids. Zero means obsolete or missing data. */
    caddr_t		log_usr_name;		/*!< Username as it appears in log files. I don't know why, but some users are supposed to exist without the name set */
    int 		usr_is_role;		/*!< Flags if the record is about group, not a plain user */
    int 		usr_disabled;		/*!< Flags if the user is (temporarily) disabled */
    int 		usr_is_sql;		/*!< Flags if the user can log in from a client */
    id_hash_t *		usr_xenc_keys;
    id_hash_t *		usr_xenc_certificates;
    dk_set_t 		usr_xenc_temp_keys;
    dk_set_t 		usr_certs;
    dk_hash_64_t *	usr_rdf_graph_perms;	/*!< Permission on RDF Graphs (default permissions, as a value for #i0, permissions for private graphs and permissions for any individual graphs */
#ifdef WIN32
    caddr_t		usr_sys_name;
    caddr_t		usr_sys_pass;
    void *              usr_sec_token;
#endif
  } user_t;

typedef void (*pldbg_send) (void *cli);

typedef struct pldbg_s
  {
    dk_session_t *	pd_session; /* debug session */
    semaphore_t *  	pd_sem;     /* debug semaphore */
    pldbg_send		pd_send;    /* function to invoke for answer */
    query_instance_t *  pd_inst;    /* current instance */
    query_instance_t *  pd_frame;   /* some instance */
    caddr_t 		pd_id;	    /* debug session id */
    long 		pd_step;    /* step mode */
    int 		pd_is_step; /* within a break */
  } pldbg_t;

#define PLDS_INT	4 /* stop at next breakpoint */
#define PLDS_STEP	2 /* step into mode */
#define PLDS_NEXT	1 /* step over mode */
#define PLDS_NONE	0 /* no stepping mode */

#ifdef PLDBG
#define PLD_SEM_CLEAR(qi)   if (qi->qi_caller == CALLER_LOCAL || qi->qi_caller == CALLER_CLIENT) \
			      { \
			        if (qi->qi_client && qi->qi_client->cli_pldbg->pd_step && cli->cli_pldbg->pd_send) { \
				  qi->qi_client->cli_pldbg->pd_step = PLDS_NONE; \
				  qi->qi_client->cli_pldbg->pd_inst = NULL; \
				  qi->qi_client->cli_pldbg->pd_is_step = 0; \
 			          cli->cli_pldbg->pd_send (cli); \
				} \
			      }
#else
#define PLD_SEM_CLEAR(qi)
#endif

#ifdef PLDBG
void _br_push (void);
void _br_pop (void);
void _br_set (void);
int _br_get (void);
int _br_lget (void);
caddr_t _br_cstm (caddr_t stmt);
#define BR_PUSH 	_br_push ();
#define BR_POP  	_br_pop ();
#define BR_SET  	_br_set ()
#define BR_GET  	_br_get ()
#define BR_LGET  	_br_lget ()
#define BR_CSTM(stmt)  	(ST *) _br_cstm ((caddr_t) stmt)
#else
#define BR_PUSH
#define BR_POP
#define BR_SET
#define BR_GET		0
#define BR_LGET		0
#define BR_CSTM(stmt) (stmt)
#endif

#define G_ID_PUBLIC	1
#define G_ID_DBA	0
#define U_ID_PUBLIC	1
#define U_ID_DBA	0
#define U_ID_DAV	2
#define U_ID_DAV_ADMIN_GROUP	3
#define U_ID_WS		4 	/* the WS user is needed to define compatibile WebDAV views */
#define U_ID_NOBODY	5
#define U_ID_NOGROUP	6
#define U_ID_RDF_REPL	7
#define U_ID_FIRST	100 	/* first free U_ID, let reserve space for a future system accounts */

struct tp_data_s;


typedef struct da_enlist_s
{
  int 	dae_host;
  int	dae_change;
} da_enlist_t;


typedef struct db_activity_s
{
  int64	da_random_rows;
  int64	da_seq_rows;
  int64	da_same_seg;
  int64	da_same_page;
  int64	da_same_parent;
  int64	da_thread_time;
  int64	da_thread_disk_wait;
  int64	da_thread_cl_wait;
  int64	da_thread_pg_wait;
  int64	da_cl_bytes;
  int64	da_memory;
  int64	da_max_memory;
  int64	da_trans_rows; /* no of sets from non initial step of trans ops */
  int64 *	da_nodes; /* array of src_sets, n_in, n_out, clocks */
  da_enlist_t * 	da_fwd_enlist; /* string with host no and rw flag for each extra enlisted, when rec'd by coor lt makes sure these have a branch, else passed forward  */
  int		da_nodes_fill;
  int	da_cl_messages;
  int	da_qp_thread;
  int	da_disk_reads;
  int	da_spec_disk_reads;
  int	da_lock_waits;
  int	da_lock_wait_msec;
  int	da_batch_size_request;
  char		da_anytime_result; /* if set, this means the recipient has run out of time and should return an answer */
  char	da_trans_partial; /* if transitive ops incomplete due to time or mem limit */
} db_activity_t;


struct cl_slice_s
{
  /* unit of movable storage, several per server if elastic, else 1:1 to host groups */
  int	csl_id; /* dense sequence number of slice from 0 to cluuster-wide n slices - 1 */
  int	csl_ordinal;
  short	csl_threads; /* count of running threads scoped to this */
  char	csl_is_local; /* copy of this slice hosted in this process */
  char	csl_status;
  cl_host_group_t *csl_chg;
  cl_host_t *csl_primary; /* the host in the host group that gets primary upd/del and resolves locks and gets queries */
  dbe_storage_t *csl_storage;
  cluster_map_t *csl_clm;
  db_activity_t csl_activity;
};


/* csl_status */
#define CSL_OK 0
#define CSL_NO_ENTRY 1


typedef struct cl_call_stack_s
{
  uint32	clst_host;
  uint32	clst_req_no;
} cl_call_stack_t;

#define SQL_ANYTIME "S1TAT"


typedef struct _cl_aq_ctx
{
  /* in cluster when aq is used to do slices of a qf or dfg, this is the state that links the aq to the main context */
  struct cll_in_box_s *	claq_result_clib;
  struct cl_thread_s *	claq_main_clt;
  struct cl_thread_s *	claq_reply_clt;
  caddr_t *		claq_main_inst;
  query_t *		claq_qr;
  int64			claq_rc_w_id;
  int64			claq_main_trx_no;
  du_thread_t *	claq_rec_thread; /* if a claq becomes claq of parent due to wait interrupted by rec cm, this is the thread.  Use for debug to detect access to same claq from many threads */
  char			claq_enlist; /* If parallel read over uncommitted state, set this to make all branch threads forward enlist */
  char			claq_of_parent; /* if a qf runs on a dfg and a rec dfg comes inside a wait in the qf, there must be a claw in scope to know which clt queue.  So the former claq is left in scope for when the qf or dfg waits.  But this flag is set to mark that this is of the parent and does not determine where the response of a rec qf goes.  The innermost clt determines this */
  char			claq_is_allocated; /* if copy by dfg thread starting another */
} cl_aq_ctx_t;

typedef struct client_connection_s
  {
    dk_session_t *	cli_session;
    struct ws_connection_s *	cli_ws;
    char		cli_terminate_requested;
    bitf_t			cli_autocommit:1;
    bitf_t			cli_is_log:1;
    bitf_t		cli_in_daq:2; /* running invoked by daq on local? autcommitting? For cluster, data in cli_clt */
    bitf_t 		cli_non_txn_insert:1;
    bitf_t		cli_log_qi_stats:1;
    bitf_t		cli_keep_csl:1;
    bitf_t		cli_cl_dae_blob;
    char		cli_row_autocommit;
    slice_id_t 		cli_slice;
    int			cli_n_to_autocommit;
    cl_slice_t *	cli_csl;
    cl_call_stack_t *	cli_cl_stack;
    cl_aq_ctx_t *	cli_claq;
    //caddr_t *		cli_main_inst; /* if the cli is a dfg slice branch, this is the main qi of the dfg on this host.  The main qi waits for all branches, so ref secure */
    //struct cll_in_box_s *	cli_result_clib; /* for any thread of local qf or dfg, results go here */
    lock_trx_t *	cli_trx;
    int64		cli_cl_start_ts;
    int64		cli_run_clocks;
    int64		cli_csl_start_ts;
    db_activity_t	cli_activity;
    db_activity_t	cli_slice_activity;
    int			cli_anytime_started;
    int			cli_anytime_timeout;
    int			cli_anytime_checked;
    int			cli_anytime_qf_started; /* inside qf/dfg, start time of the slice thread, know when to finish */
    int 		cli_anytime_timeout_orig;
    uint32		cli_compile_msec;
    db_activity_t	cli_compile_activity;
    dk_session_t *	cli_ql_strses;
    user_t *		cli_user;
    caddr_t 		cli_user_info;
    char *		cli_password;
    id_hash_t *		cli_statements;
    id_hash_t *		cli_cursors;
    dk_mutex_t *	cli_mtx;
    id_hash_t *		cli_text_to_query;
    query_t *		cli_first_query;
    query_t *		cli_last_query;
    caddr_t *		cli_replicate;
    int			cli_repl_pending;
    dbe_schema_t *	cli_temp_schema;
    dbe_schema_t *	cli_repl_schema;
    dbe_schema_t *	cli_new_schema;	/* when an uncommitted txn has made a
					   schema change this is used to hold
					   the uncommitted schema if statements
					   have to be compiled in it.
					   e.g. create index stmt */
    caddr_t		cli_qualifier;

    char			cli_support_row_count;
    char		cli_no_triggers;
    int			cli_rpc_timeout;
    int			cli_version;
    caddr_t		cli_identity_value; /* last assigned identity col */

    dk_mutex_t *		cli_test_mtx;
    dk_session_t *		cli_http_ses;
    int		 cli_not_char_c_escape;
    dk_set_t		 *cli_resultset_data_ptr;
    caddr_t		 *cli_resultset_comp_ptr; /* stmt_compilation_t ** */
    long		 cli_resultset_max_rows;
    long		 cli_resultset_cols; /* number of cols defined for result */
    query_instance_t *	 cli_result_qi;
    table_source_t *	cli_result_ts;
    id_hash_t *		cli_globals;
    wcharset_t *	cli_charset;
    struct rcc_entry_s *	cli_rcons;
#if 0
    user_t *		cli_saved_user; /* when user changed this is original user */
    caddr_t		cli_saved_qualifier; /* and original qualifier */
#endif
    int			cli_globals_dirty; /* this indicate that connection variables are changed */
#ifdef VIRTTP
    struct tp_data_s*	  cli_tp_data;
#endif
    void *		cli_ra; /* the replication account to be reconnected */
    int			cli_sqlo_options; /* Currently unused, it's here instead of cli_sqlo_enable for binary compatibility. */
    int		        cli_utf8_execs;
    int		        cli_no_system_tables;
#ifdef PLDBG
    pldbg_t *		cli_pldbg; /* debug session */
#endif
    dtp_t	cli_start_dt[DT_LENGTH];
    struct icc_lock_s	*cli_icc_lock;	/* Pointer to an InterConnectionCommunication lock to be released at exit */
    dk_session_t	*cli_outp_worker; /* used by mono out-of-process hosting */
    dk_hash_t		*cli_module_attachments; /* used to enlist the hosted modules */

#ifdef INPROCESS_CLIENT
    int			cli_inprocess;
#endif
    uint32		cli_start_time;
    caddr_t *		cli_info;
    cl_thread_t *	cli_clt; /* if cli of a cluster server thread, this is the clt */
    struct aq_request_s *	cli_aqr; /* if the cli is running an aq func, this is the aqr */
    dk_session_t *	cli_blob_ses_save; /* save the cli_session here for the time of reading b.blobs from cluster as if they were from client */
    struct xml_ns_2dict_s      *cli_ns_2dict;
    dk_set_t		cli_dae_blobs;
  } client_connection_t;


#define CLI_CLAQ_CK(cli)
#define CLAQ_UNWIND_CK

#define CLI_IN_DAQ 1 /* inside transactional daq.  Must resignal txn errors */
#define CLI_IN_DAQ_AC 2 /* inside autocommitting daq.  May handle txn erros */



/* cli_terminate_requested. Latter means force result from anytime query */
#define CLI_TERMINATE 1
#define CLI_RESULT 2

#define CLI_NEXT_USER(cli) \
  {cli->cli_row_autocommit = 0; \
    cli->cli_n_to_autocommit = 0; }

#define ROW_AUTOCOMMIT_DUE(qi, tb, quota) \
  (qi->qi_client->cli_row_autocommit && !qi->qi_trx->lt_branch_of && ((cl_run_local_only || (tb && tb->tb_primary_key->key_partition)) \
    ? (qi->qi_client->cli_n_to_autocommit > quota) : 0))

#define ROW_AUTOCOMMIT(qi) \
  if (((query_instance_t *)qi)->qi_client->cli_row_autocommit)	\
    { \
      caddr_t err = NULL; \
      bif_commit ((caddr_t*) qi, &err, NULL); \
      if (err) \
	sqlr_resignal (err); \
    }


#ifdef INPROCESS_CLIENT
#define IS_INPROCESS_CLIENT(cli) (NULL != (cli) && (cli)->cli_inprocess)
#endif

#define IN_CLIENT(cli)		mutex_enter (cli -> cli_mtx)
#define LEAVE_CLIENT(cli)	mutex_leave (cli -> cli_mtx)

#define CLI_OWNER(cli)		cli_owner (cli)

#define cli_is_interactive(cli) (!cli->cli_is_log)

#define CLI_IS_ROLL_FORWARD(cli) ((cli) && !(cli)->cli_ws && !cli_is_interactive (cli))
#define CLI_SPACE(cli)		cli->cli_trx->lt_after_space

#define DKS_DB_DATA(s) \
  (* (client_connection_t **) & ((s)->dks_dbs_data))


#define PROC_SAVE_VARS \
    dk_set_t		*saved_proc_resultset = NULL; \
    caddr_t		*saved_proc_comp = NULL; \
    long		saved_proc_max = 0; \
    query_instance_t *	saved_proc_result_qi = NULL; \
    table_source_t *	saved_proc_result_ts = NULL; \
    ptrlong             saved_proc_resultset_cols = 0


#define PROC_RESTORE_SAVED \
do { \
      cli->cli_resultset_comp_ptr = saved_proc_comp; \
      cli->cli_resultset_data_ptr = saved_proc_resultset; \
      cli->cli_resultset_max_rows = saved_proc_max; \
      cli->cli_result_qi = saved_proc_result_qi; \
      cli->cli_result_ts = saved_proc_result_ts; \
      cli->cli_resultset_cols = saved_proc_resultset_cols; \
} while (0)


#define PROC_SAVE_PARENT \
do { \
  saved_proc_comp = cli->cli_resultset_comp_ptr; \
  saved_proc_resultset = cli->cli_resultset_data_ptr; \
  saved_proc_max = cli->cli_resultset_max_rows; \
  saved_proc_result_qi = cli->cli_result_qi; \
  saved_proc_result_ts = cli->cli_result_ts; \
  saved_proc_resultset_cols = cli->cli_resultset_cols; \
  cli->cli_resultset_comp_ptr = NULL; \
  cli->cli_resultset_data_ptr = NULL; \
  cli->cli_resultset_max_rows = -1; \
  cli->cli_result_qi = NULL; \
  cli->cli_result_ts = NULL; \
  cli->cli_resultset_cols = 0; \
} while (0)

#define CLI_QUAL_ZERO(cli)       (cli)->cli_qualifier = NULL;
#define CLI_SET_QUAL(cli,q)      { dk_free_box ((cli)->cli_qualifier); (cli)->cli_qualifier = box_string((q)); }
#define CLI_RESTORE_QUAL(cli,q)  if ((cli)->cli_qualifier != (q)) \
				   { dk_free_box ((cli)->cli_qualifier); (cli)->cli_qualifier = (q); }

typedef struct local_cursor_s
  {
    caddr_t *		lc_inst;
    int			lc_position;
    int			lc_vec_n_rows;
    char		lc_vec_at_end;
    caddr_t		lc_error;
    caddr_t		lc_proc_ret; /* if stmt is a SQL procedure, this is the QA_PROC_RET block */
    int			lc_is_allocated; /* 1 if dk_alloc'd */
    caddr_t		lc_cursor_name; /* if lc implements scroll crsr and qi occurs in cli_cursors */
    int			lc_row_count;
    data_col_t *	lc_ret_dc; /* in calling vectored proc, put return values in here. */
  } local_cursor_t;


void dbe_col_load_stats (client_connection_t *cli, query_instance_t *caller,
    dbe_table_t *tb, dbe_column_t *col);
typedef caddr_t (*bif_t) (caddr_t * qst, caddr_t * err_ret,
    state_slot_t ** args);

typedef void (*bif_vec_t) (caddr_t * qst, caddr_t * err_ret,
			   state_slot_t ** args, state_slot_t * ret);


struct user_aggregate_fun_s
  {
    caddr_t	uaf_name;	/*!< Name of function/BIF */
    caddr_t	uaf_bif;	/*!< box_num() with pointer to BIF or NULL for UDFs */
  };

typedef struct user_aggregate_fun_s user_aggregate_fun_t;

struct user_aggregate_s
  {
/*! Name of aggregate */
    caddr_t	ua_name;
/*! Initialization function, that gets 0 args and returns box of environment */
    user_aggregate_fun_t	ua_init;
/*! Accumulation function, that gets 1+N args (inout environment plus arguments from expression) updates environment and returns nothing */
    user_aggregate_fun_t	ua_acc;
/*! Finalization function, that gets inout box of environment and returns the result of aggregation */
    user_aggregate_fun_t	ua_final;
/*! Merge function or NULL, that gets two inout box of environments, merges them and saves the result to the first one; returns nothing
    If the name is NULL, then the parallelization of grouping is prohibited. */
    user_aggregate_fun_t	ua_merge;
/*! Flag whether the order of passing values to the aggregate is significant. */
    char			ua_need_order;
  };


extern int lite_mode;
extern client_connection_t *bootstrap_cli;
extern void sqls_define (void); /* generated from sql_code.c */
extern void sqls_define_adm (void);
extern void sqls_define_ddk (void);
extern void sqls_define_dav (void);
extern void sqls_define_vad (void);
extern void sqls_define_dbp (void);
extern void sqls_define_uddi (void);
extern void sqls_define_imsg (void);
extern void sqls_define_auto (void);
extern void sqls_define_sparql (void);
extern void sqls_define_sys (void);
extern void sqls_define_repl (void);
extern void sqls_define_ws (void);
extern void sqls_define_pldbg (void);
extern void sqls_arfw_define (void);
extern void sqls_arfw_define_adm (void);
extern void sqls_arfw_define_ddk (void);
extern void sqls_arfw_define_dav (void);
extern void sqls_arfw_define_vad (void);
extern void sqls_arfw_define_dbp (void);
extern void sqls_arfw_define_uddi (void);
extern void sqls_arfw_define_imsg (void);
extern void sqls_arfw_define_auto (void);
extern void sqls_arfw_define_sparql (void);
extern void sqls_arfw_define_sys (void);
extern void sqls_arfw_define_repl (void);
extern void sqls_arfw_define_ws (void);
extern void sqls_arfw_define_pldbg (void);
extern void cache_resources(void);
void sqls_bif_init (void);

extern float compiler_unit_msecs;
void srv_calculate_sqlo_unit_msec (char * stmt);



void qi_check_trx_error (query_instance_t * qi, int flags);
#define NO_TRX_SIGNAL 1 /*in above, just freze or reset but no signal for trx err */
void qi_signal_if_trx_error (query_instance_t * qi);

void hosting_clear_cli_attachments (client_connection_t *cli, int free_it);
void srv_client_session_died (dk_session_t * ses);
void srv_client_connection_died (client_connection_t * ses);
void cli_set_default_qual (client_connection_t * cli);
extern int upd_hi_id_ctr;
extern dk_set_t global_old_triggers;
extern dk_set_t global_old_procs;

extern long blob_releases;
extern long blob_releases_noread;
extern long blob_releases_dir;

extern client_connection_t *autocheckpoint_cli;
#include "sqlcomp.h"
#include "eqlcomp.h"
#include "sqlfn.h"
#include "lisprdr.h"
#include "cluster.h"

#define EXPLAIN_LINE_MAX 200
#define EXPLAIN_LINE_MAX_STR_FORMAT "%.200s"

extern int enable_vec;

#ifndef ITC_DFG_CK
#define ks_set_dfg_queue(ks, inst, itc)
#define ITC_DFG_CK(itc)
#endif


#endif /* _SQLNODE_H */

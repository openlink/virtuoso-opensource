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
 *  Copyright (C) 1998-2012 OpenLink Software
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

typedef unsigned short ssl_index_t;

struct data_source_s
  {
    dk_set_t		src_continuations;
    ssl_index_t		src_in_state;
    ssl_index_t		src_count;
    qn_input_fn		src_input;
    qn_free_fn		src_free;
    code_vec_t		src_pre_code;
    code_vec_t		src_after_code;
    code_vec_t		src_after_test;
    query_t *		src_query;
    struct state_slot_s **	src_local_save; /* When no clb, array with ssls to save + save places, values need to be preserved for correct op of continue of this qn */
  };


#define SRC_OUT_STATE(src, inst) \
  * ((state_entry_t **) & inst [src->src_out_state])

#define SRC_IN_STATE(src, inst) \
  * ((caddr_t **) & inst [((data_source_t*)(src))->src_in_state])


#define SSL_PARAMETER		0
#define SSL_COLUMN		2
#define SSL_VARIABLE		3
#define SSL_PLACEHOLDER		4
#define SSL_ITC			5
#define SSL_CURSOR		6 /* a local_query_t * inside a SQL procedure */
#define SSL_TREE 7
#define SSL_REMOTE_STMT		9

#define SSL_CONSTANT		100
#define SSL_REF_PARAMETER	101
#define SSL_REF_PARAMETER_OUT	102 /* for the INOUT params */

#define IS_SSL_REF_PARAMETER(type)	\
	((type) >= SSL_REF_PARAMETER)

#define IS_UNNAMED_PARAM(ssl) 	\
	(ssl && ssl->ssl_name && ssl->ssl_name[0] == ':' && isdigit (ssl->ssl_name[1]))



typedef struct state_slot_s
  {
    char		ssl_type;
    bitf_t		ssl_is_alias:1;
    bitf_t		ssl_is_observer:1;
    bitf_t		ssl_is_callret:1;
    bitf_t		ssl_not_freeable:1;
    bitf_t		ssl_qr_global:1; /* value either aggregating or invariant across qr */
    ssl_index_t		ssl_index;
    sql_type_t		ssl_sqt;
    caddr_t	ssl_constant;
    char *		ssl_name;
    dbe_column_t *	ssl_column;
    struct state_slot_s *ssl_alias_of;
  } state_slot_t;

#define ssl_dtp ssl_sqt.sqt_dtp
#define ssl_prec ssl_sqt.sqt_precision
#define ssl_scale ssl_sqt.sqt_scale
#define ssl_class ssl_sqt.sqt_class
#define ssl_non_null ssl_sqt.sqt_non_null


typedef struct state_const_slot_s
  {
    char		ssl_type;
    bitf_t		ssl_is_alias:1;
    bitf_t		ssl_is_observer:1;
    bitf_t		ssl_is_callret:1;
    bitf_t		ssl_not_freeable:1;
    bitf_t		ssl_qr_global:1; /* value either aggregating or invariant across qr */
    ssl_index_t		ssl_index;
    sql_type_t		ssl_sqt;
    caddr_t		ssl_const_val;
    char *		ssl_name;
    struct state_const_slot_s *ssl_next_const;
    struct state_slot_s *ssl_alias_of;
  } state_const_slot_t;


/* the const is at the place of teh name if it is const */
/* #define ssl_constant ssl_name */

#define SSL_HAS_NAME(ssl) (/*ssl->ssl_type != SSL_CONSTANT &&*/ ssl->ssl_name)

#define QST_GET(qst,ssl) \
  (ssl->ssl_type < SSL_CONSTANT ? ((caddr_t*)qst)[ssl->ssl_index] : (ssl->ssl_type > SSL_CONSTANT ? ((caddr_t**)qst)[ssl->ssl_index][0] : ssl->ssl_constant))

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
  state_slot_t **	ssa_save;
  state_slot_t *	ssa_set_no; /* no of top level set that is on the qst */
  state_slot_t *	ssa_current_set;
  int			ssa_batch_size;
} setp_save_t;


typedef struct ssa_iter_node_s
{
  data_source_t 	src_gen;
  int		ssi_state;
  struct setp_node_s *	ssi_setp;
} ssa_iter_node_t;

#define IS_QN(qn, in) ((qn_input_fn)in == ((data_source_t*)qn)->src_input)
#define IS_SSI(qn) ((qn_input_fn)ssa_iter_input == ((data_source_t*)qn)->src_input)

typedef struct cl_fref_red_node_s
{
  /* on coordinator, node reading the sets from a partitioned gby/oby qf */
  data_source_t 	src_gen;
  struct fun_ref_node_s *	clf_fref;
  int			clf_status;
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




struct query_s
  {
    int			qr_ref_count;
    int			qr_trig_order;
    int			qr_instance_length;
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
    char			qr_hidden_columns;
    char			qr_n_stages; /* if represents distr frag */
    /* The query state array's description */
    dk_set_t		qr_state_map;
    state_slot_t **	qr_freeable_slots;
    state_const_slot_t *	qr_const_ssls;
    dk_set_t 		qr_temp_spaces;
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
    int			qr_qf_agg_is_any;
    caddr_t		qr_qf_agg_defaults;
    state_slot_t **	qr_qf_agg_res;
    state_slot_t **	qr_qf_multistate_agg_params;
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


typedef struct query_instance_s
  {
    query_t *		qi_query;
    struct srv_stmt_s *	qi_stmt;
    caddr_t		qi_cursor_name;
    lock_trx_t *	qi_trx;
    struct query_instance_s *qi_caller;

    du_thread_t *	qi_thread;
    struct client_connection_s *qi_client;
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
#ifdef NEW_HASH
  state_slot_t * 	ha_bp_ref_itc;
#endif
  dbe_key_t *		ha_key;
  dbe_col_loc_t *	ha_key_cols; /* the col locs of the hash temp, key fix, key var, dep fix, dep var */
  dbe_col_loc_t *	ha_cols;	/* cols of feeding table, correspond to ha_key_cols */
  state_slot_t **	ha_slots;	/* slots where values to feed come from if they do not come from columns direct */
  int			ha_n_keys;
  int			ha_n_deps;
  char 			ha_op;
  char			ha_allow_nulls;
  char			ha_memcache_only; /* flags if the hash may not reside on disk */
  long 			ha_row_size;
  long 			ha_row_count;
} hash_area_t;


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


typedef struct key_source_s
  {
    dbe_key_t *		ks_key;
    clo_comp_t **	ks_cl_order; /* if results from many cluster nodes, given them in key order? If so, this is the compare order in result rows. */
    state_slot_t *	ks_init_place;
    key_spec_t 		ks_spec;
    unsigned char	ks_spec_nth;
    char		ks_copy_search_pars; /* in dfg, the itc's pars must be copies owned by the itc */
    int			ks_init_used;
    search_spec_t *	ks_row_spec;
    dk_set_t		ks_out_cols;
    dk_set_t		ks_out_slots;
    caddr_t *		ks_out_col_ids; /* ready for cluster rpc */
    out_map_t *	ks_out_map; /* inline array of dbe_col_locs for each member of ks:_out_slots for the matching key */
    state_slot_t *	ks_from_temp_tree;	/* tree of group or order temp or such */
    struct setp_node_s *	ks_from_setp;
    int			ks_pos_in_temp; /* if mem sort, pos in the sort while reading.  Inx in inst */
    query_frag_t *	ks_from_temp_qf; /* if reading cluster aggregates, this is the qf holding the stuff */
    code_vec_t		ks_local_test;
    code_vec_t		ks_local_code;
    char		ks_descending;	/* if reading from end to start */
    char		ks_is_vacuum;
    char		ks_is_last;	/* if last ks in join and no select or
					   postprocess follows.
					   True if fun ref query */
    bitf_t		ks_is_loc_of_txs:1; /* if dummy cluster location ks for a txs then ks_ts is the text_source_t */
    ssl_index_t		ks_count;
    state_slot_t *	ks_proc_set_ctr;
/*    char 			ks_local_op; */
    struct setp_node_s *	ks_setp;
#ifdef NEW_HASH
    hash_area_t *		ks_ha;
#endif
    dk_set_t	ks_always_null; /* cols which are always forced to be null */
    state_slot_t *  ks_grouping; /* ssl with grouping bitmap */
    /* cluster */
    data_source_t *	ks_next_clb; /* if cluster and no order and the next node has a cl buffer, feed the data direct in there if no intervening steps */
    state_slot_t **		ks_qf_output; /* if last ks of value producing qf, then send these as result row. */
    struct table_source_s *	ks_ts;
  } key_source_t;

#define ks_itcl ks_ts->clb.clb_itcl

#define KS_SPC_DFG 2 /* copy search pars local and remote */
#define KS_SPC_QF 1 /* copy search pars on local only */


#define KS_COUNT(ks, qst) \
  if (ks->ks_count) ((ptrlong*)qst)[ks->ks_count]++

#define SRC_COUNT(src, qst) \
  if ((src)->src_count) ((ptrlong*)qst)[(src)->src_count]++



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
    key_source_t *	ts_order_ks;
    key_source_t *	ts_main_ks;
    state_slot_t *	ts_order_cursor;
    state_slot_t *	ts_current_of;
    bitf_t		ts_is_unique:1;	/* Only one hit expected, do not look for more */
    bitf_t		ts_is_outer:1;
    bitf_t		ts_is_random:1; /* random search */
    bitf_t 		ts_no_blobs:1;
    bitf_t		ts_need_placeholder:1;
    bitf_t		ts_is_alternate:2;
    bitf_t 		ts_alternate_inited:1;
    caddr_t		ts_rnd_pcnt;
    code_vec_t		ts_after_join_test;
    struct inx_op_s *	ts_inx_op;
    inx_locality_t	ts_il;
    hash_area_t *	ts_proc_ha; /* ha for temp of prov view res.  Keep here to free later */
    ts_alt_func_t 	ts_alternate_test;
    struct table_source_s *	ts_alternate;
    state_slot_t*		ts_alternate_cd;
    short		ts_max_rows; /* if last of top n and a single state makes this many, then can end whole set */
    short		ts_prefetch_rows; /* recommend cluster end batch   after this many because top later */
  } table_source_t;

/* for alternate index path, flag whether ts is 1st or 2nd */
#define TS_ALT_PRE 1
#define TS_ALT_POST 2


typedef table_source_t sort_read_node_t;

typedef struct rdf_inf_node_s rdf_inf_pre_node_t;
typedef struct trans_node_s trans_node_t;

typedef struct  in_iter_node_s
{
  data_source_t	src_gen;
  state_slot_t **	ii_values;
  state_slot_t *	ii_output;
  state_slot_t *	ii_values_array;
  state_slot_t *	ii_outer_any_passed; /* if rhs of left outer, flag here to see if any answer. If not, do outer output when at end */
  int		ii_nth_value;
  void 	       *	ii_dfe;
} in_iter_node_t;


typedef struct outer_seq_end_s
{
  data_source_t	src_gen;
  struct set_ctr_node_s *	ose_sctr;
  state_slot_t *	ose_set_no;
  state_slot_t *	ose_prev_set_no;
  state_slot_t **	ose_out_slots; /* the ssls that are null for the outer row */
  state_slot_t *	ose_buffered_row;
  int			ose_last_outer_set; /* set no of the last outer row.  inx of int in qi */
} outer_seq_end_node_t;


typedef struct set_ctr_node_s
{
  data_source_t	src_gen;
  cl_buffer_t	clb;
  state_slot_t *	sctr_set_no;
  outer_seq_end_node_t *	sctr_ose;
  dk_set_t 			sctr_continuable; /* continuable nodes between the sctr and the ose */
} set_ctr_node_t;
#define sctr_itcl clb.clb_itcl


typedef struct stage_sum_s
{
  int		ssm_n_empty_mores;
  char		ssm_state_recd;
  unsigned int64	ssm_in_sets; /* total input sets received by this stage of this node */
  unsigned int64	ssm_out_sets; /* total input sets processed to completion by this stage of this node */
  unsigned int64	ssm_produced_sets; /*total sent forward by this stage of this node */
} stage_sum_t;


typedef struct stage_node_s
{
  data_source_t	src_gen;
  cl_buffer_t	clb;
  query_frag_t *	stn_qf;
  int		stn_nth; /* the stage number in the dfg */
  int	stn_coordinator; /* the host number owning the query */
  int		stn_state;
  table_source_t *	stn_loc_ts; /* the ts that decides partition of next */
  state_slot_t *	stn_coordinator_req_no; /* the cm_req_no on coordinator which receives all coordinator targeted traffic. All cm's go out with this req no but this is used only by coordinator */
  state_slot_t * 	stn_dfg_state; /* dfg_stat clo with counts of locally done and forward sent */
  state_slot_t **	stn_params; /* the params to send to the next stage */
  state_slot_t *	stn_input; /* array of cm clos that represent input from remote nodes for this stn */
  int		stn_input_fill; /* qst int for last added in stn input array */
  int		stn_input_used;
  state_slot_t *	stn_current_input;
  int			stn_read_to; /* qst int, position in current input for the next clo of input */
  int			stn_out_bytes; /* qst int, bytes send to others by all non-first stn's of the dfg.  Cap on intm res size  */
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
  state_slot_t * 	qf_set_no; /* if this is a dfg this is for keeping track of the set at the output */
  dk_set_t		qf_nodes;
  data_source_t *	qf_head_node;
  table_source_t *	qf_loc_ts;
  state_slot_t **	qf_params;
  clo_comp_t **		qf_order;
  state_slot_t **	qf_result;
  dk_set_t 		qf_out_slots; /* set to itcl_out_slots */
  int 			qf_dfg_state;
  state_slot_t *	qf_dfg_req_no; /* for the batch, the req no for getting results from all nodes */
  data_source_t *	qf_dml_node; /* if this is a wrapper on cluster upd/del, then this is the node that holds the clrg for the 2nd keys */
  state_slot_t *	qf_dfg_agg_map; /* in distr frag aggregation, string that gets a 1 at the place of every host with data */
  uint32		qf_id;
  short			qf_max_rows;
  char			qf_n_stages;
  char			qf_lock_mode;
  bitf_t		qf_is_update:1;
  bitf_t		qf_is_agg:2;
  char			qf_need_enlist; /* excl parts later in the chain, enlist from start */
  char			qf_nth; /* ordinal no of qf in qr, for debug */
  state_slot_t **	qf_agg_res;
  int			qf_agg_is_any;
  caddr_t		qf_agg_defaults;
  state_slot_t **	qf_trigger_args;
  int			qf_trigger_event; /* if this is i/d/u */
  dbe_table_t *	qf_trigger_table;
  oid_t *		qf_trigger_cols;

  state_slot_t **	qf_const_ssl; /* when ends in a group by, some slots must be inited.  If set, odd is value, next even is ssl to init to value */
  state_slot_t **		qf_local_save; /* for a result set making qf, (non agg, non upd), the save state that must be saved and restored between interrupting and continuing generating  a single result set from the qf */
  state_slot_t *		qf_keyset_state;
};

#define qf_itcl clb.clb_itcl

typedef struct qf_select_node_s
{
  data_source_t  	src_gen;
  state_slot_t *	qfs_itcl;
  state_slot_t **	qfs_out_slots;
} qf_select_node_t;


typedef struct dpipe_node_s
{
  data_source_t	src_gen;
  cl_buffer_t		clb;
  char			dp_is_order;
  char			dp_is_colocated; /* already in the right partition, just call the func locally */
  struct cu_func_s **	dp_funcs;
  state_slot_t **	dp_inputs;
  state_slot_t **	dp_outputs;
  table_source_t *	dp_loc_ts;
  state_slot_t ***	dp_input_args;
  state_slot_t *	dp_local_cache; /* if this is colocated and has no dpipe, use this for remembering some results */
} dpipe_node_t;

#define dp_itcl clb.clb_itcl

typedef struct hash_source_s
{
  data_source_t		src_gen;
  ssl_index_t		hs_current_inx;
  state_slot_t *	hs_tree;
  state_slot_t **	hs_ref_slots;
  hash_area_t *	hs_ha; /* shared with the filler setp */
  state_slot_t **	hs_out_slots;
  search_spec_t *	hs_col_specs;
  dbe_col_loc_t *	hs_out_cols;
  ptrlong *		hs_out_cols_indexes;
  char			hs_is_outer;
  code_vec_t		hs_after_join_test;
} hash_source_t;


typedef struct remote_table_source_s
  {
    data_source_t	src_gen;
    char *		rts_text;
    id_hashed_key_t	rts_text_hash_no;
    struct remote_ds_s *rts_rds;
    dk_set_t		rts_out_slots;
    dk_set_t		rts_params;
    state_slot_t *	rts_remote_stmt;
    char		rts_is_outer;
    code_vec_t		rts_after_join_test;
    state_slot_t **	rts_trigger_args;
    int			rts_trigger_event; /* if this is i/d/u */
    dbe_table_t *	rts_trigger_table;
    oid_t *		rts_trigger_cols;
    state_slot_t *	rts_af_state;
    state_slot_t **	rts_save_env;
    state_slot_t *	rts_param_rows;
    state_slot_t *	rts_environments;
    state_slot_t *	 rts_param_fill;
    state_slot_t *	rts_i_param;
    state_slot_t *	 rts_single_pending;
    state_slot_t *	 rts_single_env;
    caddr_t		 rts_remote_proc;
    int			rts_is_unique;
    query_t *		rts_policy_qr;
  } remote_table_source_t;

#define IS_RTS(n) \
  ((qn_input_fn) remote_table_source_input == ((remote_table_source_t *)(n))->src_gen.src_input)

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
    state_slot_t *	sqs_set_no;
    code_vec_t		sqs_after_join_test;
    int			sqs_batch_size;
  } subq_source_t;


typedef struct union_node_s
  {
    data_source_t	src_gen;
    state_slot_t *	uni_nth_output;
    dk_set_t		uni_successors;
    char		uni_sequential; /* finish each branch before starting next.  Needed in except and intersect */
  } union_node_t;


#define TS_ORDER_ITC(ts, state) \
  * ((it_cursor_t **) &state[ts->ts_order_cursor->ssl_index])

#define TS_ORDER_RST(ts, state) \
  * ((remote_stmt_t **) &state[ts->rts_remote_stmt->ssl_index])



typedef void (*fnp_func_t) (data_source_t * fnp_node);



typedef struct ins_key_s
{
  dbe_key_t *		ik_key;
  state_slot_t **	ik_slots;
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
    state_slot_t **	ins_trigger_args;
    ins_key_t **	ins_keys;
    query_t *		ins_policy_qr;
    caddr_t		ins_key_only; /* key name, if inserting only this key, as in create index */
    state_slot_t *	ins_daq; /* in cluster, queue the insert here */
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
  } delete_node_t;


typedef struct end_node_s
  {
    data_source_t	src_gen;
    int			en_send_rc;
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
    int			en_send_rc;
    state_slot_t *	rins_row;
    int			rins_mode;	/* c.f. ins_node */
  } row_insert_node_t;


typedef struct key_insert_node_s
  {
    data_source_t	src_gen;
    int			en_send_rc;
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
    state_slot_t *	sel_set_no; /* in array exec'd dt no if set this row belongs to */
    state_slot_t *	sel_prev_set_no; /* set no of prev row.  when changes, reset the top ctr */
    state_slot_t *	sel_cn_set_no; /* if in multistate exists or value subq, this is set no of containing code node.  As soon as one result is produced, advance the multistate qr to the next set as per this set no */
  } select_node_t;

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
  state_slot_t *	sk_top_skip;
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
    char		setp_distinct;
    char		setp_set_op;
    key_id_t		setp_temp_key;
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
    state_slot_t **	setp_ordered_gb_out;
    key_spec_t 	setp_insert_spec;
    hash_area_t *	setp_reserve_ha;
    char	                setp_any_distinct_gos;
    char			setp_any_user_aggregate_gos;
    char		setp_partitioned; /* oby or gby in needing no merge in cluster */
    dk_set_t		setp_const_gb_args;
    dk_set_t		setp_const_gb_values;

    setp_save_t	setp_ssa;
    table_source_t *	setp_loc_ts;
    float		setp_card;  /* for a group by, guess of how many distinct values of grouping cols */
    char		setp_is_qf_last; /* if set, the next can be a read node of partitioned setp but do not call it from the setp. */
} setp_node_t;

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
    dk_set_t		fnr_default_values;
    dk_set_t		fnr_default_ssls;
    dk_set_t		fnr_temp_slots;
    setp_node_t *	fnr_setp;
    dk_set_t	    fnr_setps;
    dk_set_t	    fnr_group_set_read;
    dk_set_t 		fnr_distinct_ha;
    hi_signature_t *	fnr_hi_signature;
    query_frag_t *	fnr_cl_qf; /* if the aggregation is done in remotes, this is the qf that holds the state */
    setp_save_t		fnr_ssa; /* save for multiple set aggregation */
    struct cl_fref_read_node_s *	fnr_cl_reader;
    int			fnr_cl_state;
    char		fnr_partitioned;
    char		fnr_is_order; /* if partitioned setp, must read in order?*/
    char		fnr_is_set_ctr; /* if outermost multistate fref, double as a set ctr if no other set ctr */
  } fun_ref_node_t;

/* fnr_partitioned */
#define FNR_PARTITIONED 1
#define FNR_REDUNDANT 2


#define IS_FREF(qn) ((qn_input_fn)fun_ref_node_input == ((data_source_t*)qn)->src_input)


#define FNR_NONE 0

/* in qst at the place of fnr_cl_state for multistate aggregate */
#define FNR_INIT 1
#define FNR_RUNNING 2
#define FNR_RESULTS 3


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
    dk_set_t		cc_state_slots;
    id_hash_t *		cc_slots;
    query_t *		cc_query;
    dbe_schema_t *	cc_schema;
    caddr_t		cc_error;
    int			cc_any_result_ind; /* used with function refs to see
					      if there's any output */
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
  qr->qr_instance_length = cc->cc_instance_fill * sizeof (caddr_t); \
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
    long		  sst_start_msec;

/* PL scrollable */
    int			sst_is_pl_cursor;
    caddr_t		sst_pl_error;
    /* multistate */
    caddr_t *		sst_qst; /* same as sst_inst */
    int		sst_batch_size;
  } srv_stmt_t;


typedef struct user_s
  {
    caddr_t		usr_name;
    caddr_t		usr_pass;
    oid_t		usr_id;
    oid_t		usr_g_id;
    dk_hash_t *		usr_grants;
    caddr_t		usr_data;
    caddr_t *		usr_g_ids;
    caddr_t		log_usr_name;
    int 		usr_is_role;
    int 		usr_disabled;
    int 		usr_is_sql;
    id_hash_t *		usr_xenc_keys;
    id_hash_t *		usr_xenc_certificates;
    dk_set_t 		usr_xenc_temp_keys;
    dk_set_t 		usr_certs;
    dk_hash_64_t *	usr_rdf_graph_perms;
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


typedef struct db_activity_s
{
  int64	da_random_rows;
  int64	da_seq_rows;
  int64	da_cl_bytes;
  int	da_cl_messages;
  int	da_disk_reads;
  int	da_spec_disk_reads;
  int	da_lock_waits;
  int	da_lock_wait_msec;
  char		da_anytime_result; /* if set, this means the recipient has run out of time and should return an answer */
} db_activity_t;

#define SQL_ANYTIME "S1TAT"

typedef struct client_connection_s
  {
    dk_session_t *	cli_session;
    struct ws_connection_s *	cli_ws;
    char		cli_terminate_requested;
    bitf_t			cli_autocommit:1;
    bitf_t			cli_is_log:1;
    bitf_t		cli_in_daq:2; /* running invoked by daq on local? autcommitting? For cluster, data in cli_clt */
    char		cli_row_autocommit;
    int			cli_n_to_autocommit;
    lock_trx_t *	cli_trx;
    db_activity_t	cli_activity;
    int			cli_anytime_started;
    int			cli_anytime_timeout;
    int			cli_anytime_checked;
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
    long		cli_started_msec;
    struct icc_lock_s	*cli_icc_lock;	/* Pointer to an InterConnectionCommunication lock to be released at exit */
    dk_session_t	*cli_outp_worker; /* used by mono out-of-process hosting */
    dk_hash_t		*cli_module_attachments; /* used to enlist the hosted modules */

#ifdef INPROCESS_CLIENT
    int			cli_inprocess;
#endif
    uint32		cli_start_time;
    caddr_t *		cli_info;
    cl_thread_t *	cli_clt; /* if cli of a cluster server thread, this is the clt */
    dk_session_t *	cli_blob_ses_save; /* save the cli_session here for the time of reading b.blobs from cluster as if they were from client */
    struct xml_ns_2dict_s      *cli_ns_2dict;
  } client_connection_t;
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
    caddr_t		lc_error;
    caddr_t		lc_proc_ret; /* if stmt is a SQL procedure, this is the QA_PROC_RET block */
    int			lc_is_allocated; /* 1 if dk_alloc'd */
    caddr_t		lc_cursor_name; /* if lc implements scroll crsr and qi occurs in cli_cursors */
    int			lc_row_count;
  } local_cursor_t;


void dbe_col_load_stats (client_connection_t *cli, query_instance_t *caller,
    dbe_table_t *tb, dbe_column_t *col);
typedef caddr_t (*bif_t) (caddr_t * qst, caddr_t * err_ret,
    state_slot_t ** args);

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
    char		ua_need_order;
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
extern void sqls_define_sparql_init (void);
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
void srv_calculate_sqlo_unit_msec (void);



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

#endif /* _SQLNODE_H */

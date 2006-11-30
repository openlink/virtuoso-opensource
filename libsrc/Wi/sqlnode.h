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

#ifndef _SQLNODE_H
#define _SQLNODE_H

#include "odbcinc.h"
#include "wi.h"

typedef struct instruction_s	instruction_t;
typedef struct instruction_s	 * code_vec_t;
typedef struct data_source_s	data_source_t;
typedef struct query_s		query_t;
typedef struct user_aggregate_s user_aggregate_t;

typedef void (*qn_input_fn) (data_source_t *, caddr_t *, caddr_t *);
typedef void (*qn_advance_fn) (data_source_t *);
typedef void (*qn_free_fn) (data_source_t *);


struct data_source_s
  {
    dk_set_t		src_continuations;
    short			src_in_state;
    short			src_count;
    qn_input_fn		src_input;
    qn_free_fn		src_free;
    code_vec_t		src_pre_code;
    code_vec_t		src_after_code;
    code_vec_t		src_after_test;
    query_t *		src_query;
  };


#define SRC_OUT_STATE(src, inst) \
  * ((state_entry_t **) & inst [src->src_out_state])

#define SRC_IN_STATE(src, inst) \
  * ((caddr_t **) & inst [src->src_in_state])

#define SSL_PARAMETER		0
#define SSL_COLUMN		2
#define SSL_VARIABLE		3
#define SSL_PLACEHOLDER		4
#define SSL_ITC			5
#define SSL_CURSOR		6 /* a local_query_t * inside a SQL procedure */
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
    unsigned short	ssl_index;
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


typedef unsigned short ssl_index_t;

typedef struct state_const_slot_s
  {
    char		ssl_type;
    bitf_t		ssl_is_alias:1;
    bitf_t		ssl_is_observer:1;
    bitf_t		ssl_is_callret:1;
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
#define SSL_IS_UNTYPED_PARAM(ssl) 	\
	(DV_UNKNOWN == (ssl)->ssl_dtp)


#define QST_PLONG(qst, inx) \
  (* ((ptrlong *) &qst[inx]))


struct query_s
  {
    int			qr_ref_count;

    /* The query state array's description */
    dk_set_t		qr_state_map;
    state_slot_t **	qr_freeable_slots;
    state_const_slot_t *	qr_const_ssls;
    dk_set_t 		qr_temp_spaces;
    struct select_node_s *qr_select_node;

    /* The query's instantiation */
    int			qr_instance_length;

    dk_set_t		qr_parms;
    caddr_t *		qr_parm_default;
    caddr_t * 		qr_parm_alt_types; /* an alternative type */
    caddr_t *		qr_parm_soap_opts; /* SOAP options to params */
    caddr_t *		qr_parm_place;     /* where is it exposed (SOAP)*/
    dk_set_t		qr_nodes;
    dk_set_t		qr_bunion_reset_nodes; /* for a bunion term, nodes of enclosing qr that make up this term and are to be reset when resetting the bunion ter, on error */
    dk_set_t		qr_used_cursors;
    data_source_t *	qr_head_node;

    state_slot_t *	qr_current_of;	/* if this is a cursor, use this in
					   SQL 'where current of' */

    caddr_t		qr_proc_name;	/*!< If SQL procedure, this is the name */
    caddr_t		qr_trig_table;	/*!< If trigger, name of table */
    bitf_t		qr_is_ddl:1;
    bitf_t		qr_is_complete:1; /* false while trig being compiled */
    bitf_t		qr_trig_time;	/*!< If trigger, time of launch: before/after/instead */
    bitf_t		qr_trig_event;	/*!< If trigger, type of event: insert/delete/update */
    user_aggregate_t *  qr_aggregate;	/*!< If user-defined aggregate, this points to the implementation */
    oid_t *		qr_trig_upd_cols;
    int			qr_trig_order;
    dbe_table_t *	qr_trig_dbe_table;
    caddr_t *		qr_trig_old_cols;
    state_slot_t **	qr_trig_old_ssl;
    bitf_t 		qr_lock_mode;
    bitf_t		qr_is_call; /* true if this is top level proc call */
    bitf_t		qr_no_cast_error:1;
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
    bitf_t		qr_to_recompile:1;
    bitf_t		qr_no_co_if_no_cr_name:1;	/* if select stmt exec'd from client */
    bitf_t  		qr_text_is_constant:1;
    bitf_t		qr_is_bunion_term:1;
    bitf_t		qr_is_remote_proc:1;
    bitf_t		qr_unique_rows:1;
    char		qr_remote_mode;
    caddr_t		qr_qualifier; /* qualifier current when this was compiled */
    caddr_t		qr_owner;
    struct union_node_s *	qr_bunion_node;

    struct query_cursor_s *	qr_cursor;
    int			qr_cursor_type;
    state_slot_t **	qr_xp_temp;
    dk_set_t		qr_unrefd_data;	/* garbage, free when freeing qr */
#ifdef REPLICATION_SUPPORT2
    caddr_t		qr_proc_repl_acct; /* transactional replication account name */
#endif
    dk_set_t		qr_proc_result_cols; /* needed by SQLProcedureColumns */
    dk_set_t		qr_subq_queries;

    query_t		*qr_module;
    dk_set_t		qr_temp_keys;
    long 		qr_brk;
    int			qr_hidden_columns;


#ifdef PLDBG
    caddr_t 		qr_source; 	 /* source file */
    int 		qr_line;	 /* offset from file */
    long 		qr_calls;	 /* how many times it called */
    dk_hash_t 		*qr_line_counts; /* test coverage line stats */
    id_hash_t 		*qr_call_counts;  /* test coverage caller stats */
    long		qr_time_cumulative; /* test coverage cumulative time for execution */
    long 		qr_self_time;
#endif
    caddr_t		*qr_udt_mtd_info; /* not null if CREATE METHOD */
    long 		qr_obsolete_msec;
    caddr_t		qr_parse_tree;
    float *		qr_proc_cost; /* box of floats: 0. unit cost 1. result set rows 2...n+2 multiplier if param 0...n is not given */
  };

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
    struct call_node_s *qi_caller_node;

    du_thread_t *	qi_thread;
    short		qi_threads;
    bitf_t		qi_terminate_requested:1;
    bitf_t		qi_is_allocated:1;
    bitf_t		qi_autocommit:1;
    bitf_t		qi_no_triggers:1;
    bitf_t              qi_lock_mode:3;
    bitf_t		qi_assert_found:1; /* gpf if next select gets 'not found */
    bitf_t 		qi_pop_user:1;
    bitf_t 		qi_no_cast_error:1;
    char		qi_isolation;
    struct client_connection_s *qi_client;

    long		qi_n_affected;
    long		qi_max_rows;

    caddr_t		qi_proc_ret; /* if proc call and qi_caller == client, proc ret block */
    oid_t		qi_u_id;
    oid_t		qi_g_id;

    du_thread_t *	qi_thread_waiting_termination;
    struct local_cursor_s *qi_lc;
    long		qi_rpc_timeout;

    long		qi_prefetch_bytes;
    long		qi_bytes_selected;

    struct icc_lock_s	*qi_icc_lock;	/* Pointer to an InterConnectionCommunication lock to be released at exit */
    struct object_space_s *qi_object_space;
#ifdef PLDBG
    void * 		qi_last_break;
    int 		qi_step;
    long 		qi_child_time;
#endif
  } query_instance_t;


#define QST_INSTANCE(qi)	(qi)

#define QI_ROW_AFFECTED(qi)	((query_instance_t *) qi)->qi_n_affected++

#define QI_FIRST_FREE		(sizeof (query_instance_t) / sizeof (caddr_t) + 1)

#define QI_SPACE(qi)		((query_instance_t *) qi)->qi_space

#define QI_TRX(qi)		((query_instance_t *) qi)->qi_trx

#define QST_CHARSET(qi)		\
        (GET_IMMEDIATE_CLIENT_OR_NULL ? ((client_connection_t *)(GET_IMMEDIATE_CLIENT_OR_NULL))->cli_charset : \
	(!qi ? (((wcharset_t *) NULL) + GPF_T1 ("no QI")) : \
	(((query_instance_t *) qi)->qi_client ? \
	 ((query_instance_t *) qi)->qi_client->cli_charset : NULL)))


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
  state_slot_t **	ha_slots;	/* slots where values to feed come from if they don't come from columns direct */
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


typedef struct key_source_s
  {
    dbe_key_t *		ks_key;
    state_slot_t *	ks_init_place;
    search_spec_t *	ks_spec;
    int			ks_init_used;
    search_spec_t *	ks_row_spec;

    dk_set_t		ks_out_cols;
    dk_set_t		ks_out_slots;
    out_map_t *	ks_out_map; /* inline array of dbe_col_locs for each member of ks:_out_slots for the matching key */
    state_slot_t *	ks_from_temp_tree;	/* tree of group or order temp or such */

    int			ks_descending;	/* if reading from end to start */
    code_vec_t		ks_local_test;
    code_vec_t		ks_local_code;
    char		ks_is_vacuum;
    char		ks_is_last;	/* if last ks in join and no select or
					   postprocess follows.
					   True if fun ref query */
    short			ks_count;
    struct text_search_s * ks_text;
    state_slot_t *	ks_proc_set_ctr;
/*    char 			ks_local_op; */
    struct setp_node_s *	ks_setp;
#ifdef NEW_HASH
    hash_area_t *		ks_ha;
#endif
    dk_set_t	ks_always_null; /* cols which are always forced to be null */
    state_slot_t *  ks_grouping; /* ssl with grouping bitmap */
  } key_source_t;


#if 0
/* ks_local_op */
#define KS_LOCAL_NONE 0
#define KS_LOCAL_FILL 1
#define KS_LOCAL_UPDATE 2
#define KS_LOCAL_CONTINUE 3  /* can call continuation without leaving the page */
#endif


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
#define IOP_READ_INDEX 5 /*for a bitmap iop, means must read inx because the cached bm does nothave the range */

typedef struct inx_op_s 
{
  /* Members of an operator node combining multiple indices */
  int		iop_op;
  struct inx_op_s *	iop_parent;
  struct inx_op_s ** 	iop_terms;
  state_slot_t **	iop_max;
  state_slot_t *	iop_state; /* pre-init, on row, at end */ 
  dk_set_t	iop_extra_copies; /* if operands from different tables, fill copies of equal cols for all ssl's. ((org1 cp1-1 cp1-2...)(org2 cp2-1 cp2-2...)...)  */

  /* Members for the leaves, the actual indices */
  key_source_t * 	iop_ks;
  search_spec_t *	iop_ks_start_spec;
  search_spec_t *	iop_ks_full_spec;
  search_spec_t *	iop_ks_row_spec;
  state_slot_t **	iop_out;
  state_slot_t * 	iop_itc;

  /* bitmap index */
  state_slot_t * 	iop_bitmap;
  inx_locality_t	iop_il;
} inx_op_t;


typedef struct table_source_s
  {
    data_source_t	src_gen;

    key_source_t *	ts_order_ks;
    key_source_t *	ts_main_ks;
    state_slot_t *	ts_order_cursor;
    state_slot_t *	ts_current_of;
    bitf_t		ts_is_unique;	/* Only one hit expected, don't look for more */
    bitf_t		ts_is_outer;
    bitf_t		ts_is_random:1; /* random search */
    caddr_t		ts_rnd_pcnt;
    bitf_t 		ts_no_blobs;
    bitf_t		 ts_ancestor_refd;
    code_vec_t		ts_after_join_test;
    struct inx_op_s *	ts_inx_op;
    inx_locality_t	ts_il;
  } table_source_t;


typedef struct hash_source_s
{
  data_source_t		src_gen;
  short			hs_current_inx;
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
  ((qn_input_fn) remote_table_source_input == n->src_gen.src_input)

#define IS_TS(n) \
  ((qn_input_fn) table_source_input_unique == n->src_gen.src_input ||\
   (qn_input_fn) table_source_input == n->src_gen.src_input)


typedef struct subq_source_s
  {
    data_source_t	src_gen;
    state_slot_t **	sqs_out_slots;
    query_t *		sqs_query;
    char		sqs_is_outer;
    code_vec_t		sqs_after_join_test;
    code_vec_t		rts_after_join_test;
  } subq_source_t;


typedef struct union_node_s
  {
    data_source_t	src_gen;
    state_slot_t *	uni_nth_output;
    dk_set_t		uni_successors;
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
    dbe_table_t *	ins_table;
    oid_t *		ins_col_ids;
    dk_set_t		ins_values;
    int			ins_mode;
    state_slot_t **	ins_trigger_args;
    ins_key_t **	ins_keys;
    query_t *		ins_policy_qr;
  } insert_node_t;


#define INS_NORMAL	0
#define INS_SOFT	1 /* don't insert if prime key exists */
#define INS_REPLACING	2 /* replace row if prime key exists. */


#define UPD_MAX_COLS 200

typedef struct update_node_s
  {
    data_source_t	src_gen;
    dbe_table_t *	upd_table;
    state_slot_t *	upd_place;
    oid_t *		upd_col_ids;
    state_slot_t **	upd_values;
    state_slot_t *	upd_cols_param;
    state_slot_t *	upd_values_param;
    char 		upd_no_keys;	/* if no key parts changed */
    /* opt for single col in row of known key */
    key_id_t		upd_exact_key; /* if no key parts */
    dbe_col_loc_t **	upd_fixed_cl;


    state_slot_t **	upd_trigger_args;
    int			upd_hi_id;  /* key for lookup of affected hi's in the lt */
    query_t *		upd_policy_qr;
  } update_node_t;


typedef struct delete_node_s
  {
    data_source_t	src_gen;
    dbe_table_t *	del_table;
    state_slot_t *	del_place;
    state_slot_t **	del_trigger_args;
    query_t *		del_policy_qr;
  } delete_node_t;


typedef struct end_node_s
  {
    data_source_t	src_gen;
    int			en_send_rc;
  } end_node_t;


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
    state_slot_t **	sel_tie_oby;
  } select_node_t;

#define SEL_NODE_INIT(cc, sel) \
  sel->sel_out_box = cc_new_instance_slot (cc); \
  sel->sel_out_fill = cc_new_instance_slot (cc); \
  sel->sel_current_of = cc_new_instance_slot (cc); \
  sel->sel_out_quota = cc_new_instance_slot (cc); \
  sel->sel_total_rows = cc_new_instance_slot (cc); \
  cc->cc_query->qr_select_node = sel;


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
    state_slot_t *	setp_temp_tree;
    hash_area_t *	setp_ha;
    dk_set_t		setp_keys;
    dk_set_t		setp_key_is_desc;
    dk_set_t		setp_dependent;
    dk_set_t		setp_gb_ops;	/* AMMSC for group by */
    int			setp_distinct;
    key_id_t		setp_temp_key;
    int			setp_set_op;
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
    search_spec_t *	setp_insert_specs;
    hash_area_t *	setp_reserve_ha;
    int	                setp_any_distinct_gos;
    int			setp_any_user_aggregate_gos;
  } setp_node_t;

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
    data_source_t *	fnr_select;
    int			fnr_is_any;
    dk_set_t		fnr_default_values;
    dk_set_t		fnr_default_ssls;
    dk_set_t		fnr_temp_slots;
    setp_node_t *	fnr_setp;
    dk_set_t	    fnr_setps;
    dk_set_t	    fnr_group_set_read;
    dk_set_t 		fnr_distinct_ha;
    hi_signature_t *	fnr_hi_signature;
  } fun_ref_node_t;

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
#define BR_GET
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
#define U_ID_FIRST	100 	/* first free U_ID, let reserve space for a future system accounts */

struct tp_data_s;

typedef struct client_connection_s
  {
    dk_session_t *	cli_session;
    user_t *		cli_user;
    caddr_t 		cli_user_info;
    char *		cli_password;
    id_hash_t *		cli_statements;
    id_hash_t *		cli_cursors;
    dk_mutex_t *	cli_mtx;
    id_hash_t *		cli_text_to_query;
    query_t *		cli_first_query;
    query_t *		cli_last_query;

    lock_trx_t *	cli_trx;
    int			cli_autocommit;
    caddr_t *		cli_replicate;
    int			cli_is_log;

    int			cli_repl_pending;
    dbe_schema_t *	cli_temp_schema;
    dbe_schema_t *	cli_repl_schema;
    dbe_schema_t *	cli_new_schema;	/* when an uncommitted txn has made a
					   schema change this is used to hold
					   the uncommitted schema if statements
					   have to be compiled in it.
					   e.g. create index stmt */
    index_space_t *	cli_temp_isp;
    caddr_t		cli_qualifier;

    int			cli_support_row_count;
    int			cli_version;
    char		cli_no_triggers;
    caddr_t		cli_identity_value; /* last assigned identity col */

    dk_mutex_t *		cli_test_mtx;
    dk_session_t *		cli_http_ses;
    struct ws_connection_s *	cli_ws;
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

    char		cli_terminate_requested;
    dk_hash_t		*cli_module_attachments; /* used to enlist the hosted modules */

#ifdef INPROCESS_CLIENT
    int			cli_inprocess;
#endif
    long		cli_start_time;
    caddr_t *		cli_info;
  } client_connection_t;

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
    dk_set_t		 *saved_proc_resultset = NULL; \
    caddr_t		 *saved_proc_comp = NULL; \
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
  };


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
extern void cache_resources(void);
void sqls_bif_init (void);

extern float compiler_unit_msecs;
void srv_calculate_sqlo_unit_msec (void);



void qi_check_trx_error (query_instance_t * qi, int only_termiante);
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
/* If you need this, load it separately.
#include "xmlnode.h" */

#define EXPLAIN_LINE_MAX 200
#define EXPLAIN_LINE_MAX_STR_FORMAT "%.200s"

#endif /* _SQLNODE_H */

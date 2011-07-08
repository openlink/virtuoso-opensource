/*
 *  $Id$
 *
 *  Cluster data structures
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2009 OpenLink Software
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

#ifndef _CLUSTER_H
#define _CLUSTER_H

#include "../Dk/Dkhash64.h"


typedef struct cl_message_s cl_message_t;


typedef struct cl_status_s
{
  int 		cst_host;
  int		cst_status;
  int		cst_ch_status;
  uint32	cst_ts;
  int64	cst_bytes_sent;
  int64	cst_messages_sent;
  int64		cst_cl_wait;
  int64		cst_txn_messages_sent;
  int64		cst_cl_wait_msec;
  int		cst_threads_running;
  int		cst_threads_waiting;
  int		cst_threads_io;
  int		cst_buffers_wired;
  int		cst_buffers_used;
  int		cst_buffers_dirty;
  int64		cst_read_msec;
  int32		cst_cpu;
  int32		cst_majflt;
  char	cst_status_line[40];
} cl_status_t;


#define CST_EMPTY 0
#define CST_OK 1
#define CST_DOWN 2

extern cl_status_t cl_local_cst;


/* dks_cluster_flags */
#define DKS_TO_CLUSTER 1


typedef struct cl_interface_s
{
  char		cin_is_local; /* this process */
  char		cin_disable; /* if unplugged, failed switch  or such */
  char		cin_is_local_host; /* other cluster process on same machine */
  caddr_t	cin_connect_string;
  caddr_t	cin_port_only;
  int		cin_n_connections; /* how many exist */
  short	cin_local_interface; /* when going to remote, through which local interface does it go? */
  resource_t *	cin_connections;
} cl_interface_t;

#define CIN_REQ 1
#define CIN_REPLY 2
#define CIN_SYNC_REQ 3 /* connection for log shipping.  Does not use cluster protocol. Upon init not put in the pool of connections of the accepting process */
#define CIN_TEST 4 /* test connection, high byte is interface no of target host. The server replies and disconnects */

struct cl_host_s
{
  int32			ch_id;
  caddr_t		ch_name;
  char 			ch_status;
  char			ch_disconnect_in_progress; /* set by listener thread for time of stopping and freeing activity on behalf of this.  Do not allow connects while this is set */
  char		ch_is_local_host; /* same machine, prefer unix domain */
  char		ch_nth_in_group;
  uint32	ch_offline_since;
  uint32		ch_atomic_since; /* if host in checkpoint or such, do not expect keep alives */
  uint32		ch_last_disconnect_query_sent; /* last msec time local complained about this host being offline */
  uint32		ch_last_disconnect_query_served; /* last msec time a disconnect query about this host was processed */
  cl_interface_t **	ch_interfaces;
  caddr_t		ch_connect_string;
  dk_set_t		ch_replica;
  /* resources kept locally for this host */
  dk_hash_t *	ch_id_to_cm; /*for suspended cm's for this host */
  dk_mutex_t *	ch_mtx;
  dk_hash_t *	ch_closed_qfs;
  dk_set_t	ch_cl_maps;
  cl_status_t	ch_prev_cst;
  cl_status_t	ch_current_cst;
};


typedef struct cl_config_s
{
  int32	ccf_req_batch_size;
  int32	ccf_batches_per_rpc;
  int32	ccf_res_buffer_bytes;
  int32	ccf_cl_threads;
  cl_host_t **	ccf_hosts; /* ((host<n> host:port ...) ...) */
} cl_config_t;

typedef struct cl_trx_s
{
  int64	ctrx_w_id;
  dk_set_t	ctrx_waits_for;
  dk_set_t 	ctrx_waiting_for_this;
} cl_trx_t;


#define CH_ONLINE 0
#define CH_REMOVED 1  /* do not connect to this until otherwise indicated.  Not kept insync, rejoin by special protocol */
#define CH_OFFLINE 2 /* Disconnected, can retry from time to time */
#define CH_SEEK_CONFIG 3
#define CH_RFWD 4 /* roll forward from own log */
#define CH_RFWD_GROUP 5 /* sync by roll forward of log from group peer if partitions in multiple copies */
#define CH_SYNC_SCHEMA 6
#define CH_NONE 7 /* indicates unused host number in a host map string */


typedef struct cl_inxop_s
{
  it_cursor_t *	cio_itc;
  caddr_t *	cio_values;
  int		cio_pos;
  int		cio_values_fill;
  char		cio_is_bitmap:1;
  char		cio_is_local:1;
  dtp_t		cio_dtp;
  short		cio_bm_len;
  int		cio_nth;
  placeholder_t * cio_bm_pl;
  db_buf_t	cio_bm;
  bitno_t	cio_bm_start;
  bitno_t	cio_bm_end;
  int		cio_n_results;
  dk_session_t *	cio_strses;
  caddr_t *		cio_local_params;
  caddr_t *		cio_results;
} cl_inxop_t;


typedef struct cl_op_s
{
  char		clo_op;
  int		clo_seq_no; /* seq no in the clrg */
  int		clo_nth_param_row; /* no of the param row of the calling sql node */
  uint32	clo_slice; /* if requesting clo, id of targeted partition, can be many per host  */
  data_col_t *	clo_set_no; /* number of the param row in vectored mode */
  mem_pool_t *		clo_pool;
  dk_set_t		clo_clibs; /* the set of hosts serving this */
  union {
    struct {
      it_cursor_t *	itc;
      caddr_t *	local_params; /* search pars, like in select_same when the clo is local */
      cl_message_t *	gb_cm; /* if reading a group by temp of a remote gb, this is the cm of the qf that has the temp */
      short		max_rows;
      char		is_text_seek; /* for given word and d_id <= x, desc seek and asc read */
      bitf_t		is_started:1; /* if local, indicates whether itc_reset or next */
      bitf_t		any_passed:1; /* for oj when te clo represents a set in a select batch */
      bitf_t	is_null_join:1; /* if oj, mark that the result is null because of null criteria or such */
    } select;
    struct {
      short	max_rows;
      caddr_t *	params;
    } select_same;
    struct {
      row_delta_t *	rd; /* must be first, same as delete */
      row_delta_t *	prev_rd; /* if rd non-unq, the conflicting pre-existing row is put here */
      char		ins_mode;
      char		ins_result; /* DVC_MATCH if non-unq */
      char		is_local;
      char 		is_autocommit;
    } insert;
    struct {
      row_delta_t *	rd; /* key and key parts for finding the key to delete, must be first, same as insert  */
    } delete;
    struct {
      query_frag_t *	qf;
      query_t *		qr;
      caddr_t *		params;
      caddr_t *		local_params;
      caddr_t *		qst;
      dk_set_t	alt_inputs; /* a dist frag with no qr can get multiple inputs.  Put them here while waiting for the qr */
      int		coord_host; /* host no of host coordinating the query */
      uint32		coord_req_no; /* req no to use form messages to coordinator */
      uint32		qf_id; /* if the qr is not known on recipient, use this to fetch it from the coordinator */
      short		max_rows;
      char		nth_stage; /* stage no of dist frag to which this is going */
      char		isolation;
      char		lock_mode;
      char		is_started;
      char		is_local_direct;
      char 		is_update;
      char		is_autocommit;
      bitf_t	is_null_join:1; /* if oj, marks empty because of null join cond or such */
      bitf_t	is_update_replica:1; /* if set and doing upd/del, do not bother with 2nd keys */
    } frag;
    struct {
      query_frag_t *	qf;
      query_t *		qr;
    } qf_prepare;
    struct {
      caddr_t	func;
      caddr_t *	params;
      int	u_id;
      char	is_txn;
      char	is_update;
    } call;
    struct {
      int filler;
    } blob;
    struct {
      caddr_t *	cols;
    } row;
    struct {
      char		type; /*table, proc, ... */
      caddr_t	name;
      caddr_t	trig_table;
    } ddl;
    struct {
      caddr_t	err;
    } error;
    struct {
      struct itc_cluster_s *	itcl;
    } itcl;
    struct {
      cl_status_t * cst;
    } cst;
    struct {
      cl_inxop_t *	cio;
    } inxop;
    struct {
      int	in_batches; /* messages recd for this stage node */
      int	in_local_sets;
      int	result_rows; /* rows in last stage's output set.  Not exact but means some progress */
      int64 *	out_counts; /* per host, how many inputs sent to date */
      int64	sets_completed; /* count of inputs processed to end since start */
    } dfg_stat;
    struct {
      int		host;
      struct cl_op_s **	stats;
    } dfg_array;
    struct {
      caddr_t	in;
      int	read_to;
      int	bytes;
    } stn_in;
    struct {
      int	req_no;
    } dfga;
    struct {
      int	op;
      int	master;
      caddr_t *	offline;
    } ctl;
  } _;
} cl_op_t;

/* is_started in qf clo */
#define QF_STARTED 1
#define QF_SETP_READ 2

struct cl_thread_s
{
  /* data for a thread serving a req from another host */
  basket_t		clt_queue;
  uint32			clt_now_running; /* matches cm_req_no */
  int				clt_cli_host;
  cl_message_t *	clt_current_cm;
  cl_op_t *		clt_clo;
  cl_host_t *	clt_client;
  du_thread_t *		clt_thread;
  client_connection_t *	clt_cli; /* largely dummy but sql ops want one */
  dk_session_t *	clt_reply_strses;
  dk_session_t *	clt_reply_ses; /* if a batch sends multiple reply messages, they are all on this ses to keep order */
  cl_host_t *		clt_disconnected; /* when set by listener, this clt is expected to finish and free all things and threads associated with the disconnected host */
  char			clt_is_error; /* Will  the reply message be with error flag set */
  char			clt_commit_scheduled; /* if a 2pc final is scheduled on this thread, set this flag to mark that this must complete even if the client disconnected */
  int			clt_n_bytes; /* total bytes sent by rpc */
  it_cursor_t *		clt_save_itc; /* allow reuse of itc between selects with same cond */
  int64			clt_n_affected;
  mem_pool_t *		clt_mp; /* alloc dcs of req being read here, will become mp of the qf later */
  int64			clt_sample_total;
  uint32		clt_start_time; /* approx time, use for keep alive */
  int			clt_prev_set_no; /*debug */
} ;


typedef struct dc_read_s
{
  int	dre_pos;
  int	dre_bytes;
  int	dre_n_values;
  dtp_t		dre_dtp;
  dtp_t		dre_type;
  dtp_t		dre_non_null;
  dtp_t		dre_any_null;
  db_buf_t	dre_nulls;
  db_buf_t	dre_data;
  caddr_t	dre_box;
} dc_read_t;


typedef struct cll_in_box
{
  char		clib_is_active; /* results may still come */
  char			clib_waiting; /* true if this clib is part of current wait for multiple */
  char			clib_is_error;
  char			clib_enlist; /* set when transactional clo's are queued, will enlist the branch when sending */
  char		clib_res_type; /* when select, the cm_res_type of last CL_RESULT */
  char			clib_is_update; /* requires 2pc at end of txn because changed something */
  char			clib_is_ac_update; /* autocommitting upd/del */
  char			clib_ac_batch_end; /* if autocommit upd, indicates end of batch.  Must not continue until all are at batch end and the autocommit can be done  */
  char			clib_agg_qf_pending; /* if set, when freeing clib, send a cancel to remote to free unread  temps */
  char			clib_batch_as_reply; /* if set, when sending a batch, use the reply cm op.  This is when going from other to query coordinator in distr frag */
  char			clib_dfg_any; /* set if used for dfg send, means must forward cancellations */
  char		clib_fake_req_no; /* the req no is not registered and expects no answer, so do not rm the clib with the req no when freeing.  Happens with dfg's  */
  char		clib_is_update_replica;
  int			clib_skip_target_set; /* if would ask for more, start the cl_more at clo with this row no or higher */
  int32			clib_row_low_water;  /*when less than this many and last cm is continuable, ask for more */
  int			clib_batches_requested; /* how many CL_MORE' s + 1 for the initial CL_BATCH */
  int			clib_batches_received; /* how many full batches recd */
  int			clib_batches_read;
  int			clib_rows_done; /* how many done from the batch?  Compare with low water mark */
  int			clib_n_local_rows; /* if local exec, no of rows in teh result dcs */
  uint32			clib_req_no;
  int			clib_n_selects;
  int			clib_n_selects_received; /* if less recd than requested, send a close when freeing the clrg */
  uint32		clib_keep_alive; /* for long running, time of last keep alive from server */
  int64			clib_n_affected; /* upd/del changed row count returned here */
  cl_host_t *	clib_host;
  query_frag_t *	clib_last_serialized_qf; /* when finding a series of qf invokes remember the qf, even if not yet compiled on remote so as not to send multiple times in one batch */
  struct cl_req_group_s * clib_group;
  basket_t		clib_in; /* raw strings from the remote */
  basket_t		clib_in_parsed; /* responses as cl_op_t's */
  int			clib_prev_read_to; /* debug to see prev msg */
  dk_session_t *	clib_req_strses;
  dk_session_t *	clib_out; /* the connect to the server.  If the req is sent in multiple messages, the same ses must be used to guarantee order */
  basket_t		clib_local_clo;
  int			clib_local_bytes; /* how many processed in local batch */
  int			clib_local_bytes_cum; /* metric.  How many bytes done local while remotes pending */
  int 		clib_n_dcs;
  mem_pool_t *		clib_local_pool;
  dk_set_t 		clib_vec_clos;
  cl_op_t *		clib_vec_clo;
  dc_read_t *		clib_dc_read;
  caddr_t *		clib_first_row;
  cl_op_t		clib_first;
  dk_session_t		clib_in_strses;
  scheduler_io_data_t	clib_in_siod;
} cll_in_box_t;

#define clib_has_data(clib) \
  (!basket_is_empty (&clib->clib_in) || !basket_is_empty (&clib->clib_in_parsed) \
   || (clib->clib_in_strses.dks_in_buffer && clib->clib_in_strses.dks_in_read < clib->clib_in_strses.dks_in_fill))

typedef struct cucurbit_s cucurbit_t;

#define CL_MAX_REPLICAS 3

#define clrg_csl_clib(clrg, csl_id, nth_host) \
  clrg->clrg_slice_clibs[(csl_id) * clrg->clrg_clm->clm_n_replicas + (nth_host)]


typedef struct cl_req_group_s
{
  int		clrg_ref_count;
  char		clrg_wait_all;
  char		clrg_sent; /* true after the first is sent */
  char		clrg_is_error;
  bitf_t	clrg_keep_local_clo:1; /* when adding local ops, put them in clib_local_clo ? */
  bitf_t	clrg_all_sent:1;
  bitf_t	clrg_select_same:1;  /* all clo's are the same select with different params */
  bitf_t	clrg_is_dfg:1;
  bitf_t	clrg_is_dfg_rcv:1;
  bitf_t	clrg_need_enlist;
  bitf_t	clrg_no_txn:1; /* for clrg call, do not enlist */
  bitf_t	clrg_retriable:2;
  bitf_t	clrg_best_effort:1;
  char	clrg_cm_control; /* send ops with this ored to cm_enlist, e.g. cm_control, cm_start_atomic */
  uint32	clrg_send_buffered; /* total waiting send in clibs */
  int		clrg_clo_seq_no;
  uint32	clrg_send_time;
  int32	clrg_timeout;
  uint32	clrg_dfg_req_no; /* if running a distr frag, use this req no and this host for cancel */
  int		clrg_dfg_host;
  dk_set_t 	clrg_clibs;
  cll_in_box_t **	clrg_slice_clibs;
  cluster_map_t *	clrg_clm;
  dk_mutex_t 	clrg_mtx;
  lock_trx_t *	clrg_lt;
  int64		clrg_trx_no; /* in cases of terminate the lt may be free but must still send cancels with the right id */
  du_thread_t *	volatile clrg_waiting;
  caddr_t	clrg_error; /* sql error struct for connection errors */
  mem_pool_t *	clrg_pool; /* for params */
  struct itc_cluster_s *	clrg_itcl;
  int		clrg_wait_msec;
  /* use for standalone call clrg */
  int		clrg_nth_param_row; /* count calls on standalone clrg */
  int		clrg_nth_set; /* no of sets received. One set per param row */
  int		clrg_n_sets_requested; /* clrg_nth_param_row at the time of last send.  Do not send  more until this many rec'd */
  int		clrg_u_id;
  char		clrg_error_end; /* transaction error in txn daq.  No more results */
  caddr_t *	clrg_param_rows;
  dk_set_t	clrg_last;
  cucurbit_t *	clrg_cu;
} cl_req_group_t;

#define CLRG_RETRY_SINGLY 1 /* clibs can be retried individually */
#define CLRG_RETRY_ALL 2 /* if a retry, all clibs retry */

typedef struct itc_cluster_s
{
  bitf_t	itc_in_order:1;
  bitf_t	itcl_desc_order:1;
  bitf_t	itcl_return_pl:1;
  short			itcl_n_clibs;
  int			itcl_nth_set;
  dbe_column_t **	itcl_out_cols;
  dk_set_t		itcl_out_slots;
  query_frag_t *	itcl_dfg_qf; /* the qf if this is the control itcl of a distributed frag */
  clo_comp_t **	itcl_order;
  cl_req_group_t *	itcl_clrg;
  caddr_t *		itcl_qst;
  mem_pool_t *		itcl_pool;
  cl_op_t ***		itcl_param_rows;
  cll_in_box_t *	itcl_last_returned; /* when getting non-first  next, pop the top row off this clib first */
  dk_set_t		itcl_last; /* round robin pointer into the clrg_clibs */
  cll_in_box_t *	itcl_local_when_idle; /*when not ordered, run this local clib whenever no remote data */
} itc_cluster_t;

#define ITCL_SHOULD_START(itcl, inst, clb) \
  ((QST_INT (inst, clb.clb_fill) == clb.clb_batch_size) || itcl->itcl_clrg->clrg_send_buffered > cl_send_high_water || itcl->itcl_pool->mp_bytes > 10000000 \
   || (0 == QST_INT (inst, clb.clb_fill) % 20  && ((query_instance_t*)inst)->qi_client->cli_anytime_timeout && qi_anytime_send_check (inst)))



/* itcs_wait_mode */
#define ITCS_WAIT_ALL 1 /* for merging of ordered result streams */
#define ITCS_WAIT_ANY 2 /* for unordered merge of unordered result streams */



typedef struct value_state_s
{
  dk_set_t	vs_references;
  caddr_t		vs_org_value;
  caddr_t		vs_result;
  int			vs_n_steps;
  char			vs_is_value; /* is already translated? */
} value_state_t;



typedef struct cu_return_s
{
  caddr_t	cur_value;
  caddr_t	cur_is_value;
  caddr_t	cur_step[10];
} cu_return_t;


typedef cu_return_t * (*cu_op_func_t) (cucurbit_t * cu, caddr_t arg, value_state_t * vs);


typedef struct cu_func_s
{
  caddr_t	cf_name;
  char	cf_is_upd;
  char	cf_1_arg;
  bitf_t	cf_single_action:1;
  caddr_t	cf_proc;
  cu_op_func_t		cf_dispatch;
  dbe_key_t *		cf_part_key;
  caddr_t		cf_call_bif;
  caddr_t		cf_call_proc;
  sql_type_t *		cf_arg_sqt;
  caddr_t		cf_extra;
} cu_func_t;


typedef struct cu_line_s
{
  cu_func_t *	cul_func;
  id_hash_t *	cul_values;
} cu_line_t;


struct cucurbit_s
{
  char		cu_is_distinct;
  char		cu_is_ordered;
  char		cu_is_in_dp; /* the cu_funcs are owned by a dpipe node */
  char		cu_allow_redo;
  int		cu_nth_set; /* no of result row */
  dk_set_t	cu_lines;
  int		cu_n_cols;
  char		cu_input_funcs_allocd;
  cu_func_t **	cu_input_funcs;
  cl_req_group_t *	cu_clrg;
  dk_hash_t * 		cu_seq_no_to_vs;
  caddr_t *		cu_rows;
  int *			cu_vec_set_nos; /* if vectored with sparse inputs, correlates input row no to col position for the result. */
  int			cu_fill;
  basket_t		cu_ready;
  caddr_t *		cu_qst; /* for duration of a dipipe_next call */
  void		(*cu_ready_cb) (cucurbit_t* cu, caddr_t * row);
  int		cu_n_redo; /* debug ctr */
  char		cu_rdf_load_mode;
  dk_hash_t *	cu_key_dup;
  caddr_t *	cu_cd;
};

#define DPIPE_MAX_ROWS 0xfffff

#if (SIZEOF_CHAR_P == 4)
#define DPIPE_MAX_LANES (4096 - 3)
#else
#define DPIPE_MAX_LANES (0xffff - 3)
#endif

#define RDF_LD_MULTIGRAPH 2
#define RDF_LD_DELETE 3

#define CU_ALLOW_REDO 4
#define CU_NO_TXN 2
#define CU_ORDERED 1

typedef struct cl_listener_s
{
  dk_hash_64_t *	cll_id_to_trx; /* serialized on wi_txn_mtx */
  dk_hash_64_t *	cll_w_id_to_trx; /* serialized on wi_txn_mtx */
  dk_hash_64_t *	cll_dead_w_id; /* The w ids of txns transacted in the last few minutes. Don't du stuff or record things about these.  in txn mtx. */
  dk_hash_64_t *	cll_trx_thread;
  dk_hash_t *		cll_id_to_clib;
  dk_mutex_t *	cll_mtx;
  dk_set_t		volatile cll_clients;
  dk_session_t *	cll_self; /* other threads on this host use this to signal the cluster listener thread */
  cl_host_t *		cll_local;
  volatile short *		cll_interface_threads; /* for each interface, how many threads writing */
  dk_session_t *	cll_listen;
  int32			cll_this_host;
  int32			cll_master_host;
  volatile uint32		cll_next_req_id;
  cl_host_t **			cll_master_group; /* masters in precedence order. */
  dk_set_t 	cll_cluster_maps;
  dk_hash_t *	cll_id_to_host;
  dk_hash_64_t *	cll_id_to_qf; /* query frags sent here by others */
  dk_hash_t *	cll_qf_hosts; /* hosts having each query frag sent by this */
  dk_hash_t *	cll_local_qf; /* local distr qfs by local id, for serving distr frags where remote asks for the qf */
  dk_hash_64_t * 	cll_replayed_w_ids;
  int64		cll_atomic_trx_id; /* if server in atomic mode, only this trx id is allowed */
  du_thread_t *	cll_atomic_owner;
  int32		cll_max_host; /* highest used host no */
  char		cll_no_ddl; /* during add of nodes, ddl is forbidden */
  char		cll_is_master; /* inh master group, must have master functions inited and in sync for fallback */
  char		cll_is_flt; /* some logical clusters in multiple copies, fault tolerannt.  Extra logging and 2pc consensus protocols on */
  char		cll_need_network_check; /* if one interface to peer works and the other not, should check  */
  char		cll_is_map_uncertain; /* between change of map and commit of same */
  uint32	cll_synced_time; /* msec time of receiving sync confirmation for flt rejoin */
  uint32	cll_no_disable_of_unavailable;
} cl_listener_t;

typedef int (*cl_ready_t) (dk_session_t * ses);

typedef struct cl_cli_s
{
  cl_ready_t 	clses_ready;
  cl_host_t *	clses_host;
  cl_interface_t *	clses_interface;
  char		clses_status;
  char			clses_is_log_sync;
  char		clses_held_for_write; /* a thread has checked this out and uses this to write a seq message to the host */
  cl_thread_t *	clses_clt; /* when serving req from this client, ref back to trx and other data for blob read */
  cl_message_t *	clses_reading_cm;
  int64			clses_read_to;
} cl_ses_t;

#define CLSES_NO_INIT 0 /* not logged in */
#define CLSES_OK 1 /* operational */
#define CLSES_DISCONNECTED 2 /* a read has failed.  Not yet free because a thread may hold this for write */


#define DKS_CL_DATA(ses)  (*((cl_ses_t **)&(ses)->dks_cluster_data))
#define DKS_QI_DATA(ses)  (*((query_instance_t **)&(ses)->dks_object_temp))

typedef struct cl_self_message_s
{
  void (*cls_func) (void* arg);
  void * 	cls_cd;
} cl_self_message_t;


/* Top level messages */
#define CL_INIT  0 /* client host id, pwd, version */
#define CL_BATCH  1
#define CL_RESULT 2
#define CL_MORE 3 /* batch id, sends more replies */
#define CL_ROLLBACK 4
#define CL_COMMIT 5
#define CL_PREPARE  6
#define CL_CANCEL  7
#define CL_WAIT_STATE 8  /* local tx waits for global deadlock detection */
#define CL_DISCONNECT 9 /* send for orderly shut of connection, else disconnect is considered host failure. */
#define CL_STATUS 10
#define CL_SELF_INIT 11
#define CL_1PC_COMMIT 12 /* a distr. commit with 1 changed remote */
#define CL_PING 13
#define CL_QF_PREPARED 14
#define CL_QF_FREE 15
#define CL_TRANSACTED 16  /* notification of completed commit /rb for the monitor */
#define CL_1PC_EXPEDITE 17 /* when killed during 1pc reply wait, use this message to make sure the 1pc does not hang.  */
#define CL_SEQ 18
#define CL_GET_CONFIG 19
#define CL_RECOV 20 /*during 2pc recov cycle,  did cm_trx commit? */
#define CL_BLOB 21
#define CL_BLOB_RESULT 22
#define CL_WAIT_QUERY 23 /* request to send all local wait edges to master */
#define CL_WAIT_QUERY_REQ 24
#define CL_GET_QF 25 /* when running distr frag and having no qf, this gets the query_t from the coordinator */
#define CL_COMMIT_MON 26 /* combines final commit and notify to monitor */
#define CL_KEEP_ALIVE 27 /* inform that the following req nos and lt w ids are pending */
#define CL_ATOMIC 28  /* signal or ask if a host is in atomic state */
#define CL_TXN_QUERY 29  /* Internal, to schedule async exec of final commit check for lt's refd in a keep alive.  Will send cl commits and rbs to the concerned */
#define CL_SEQ_REPL 31 /* message replicate seq ranges to standby master */
#define CL_ROLLBACK_SYNC 32 /* internal, indicate that a reply is expected for the rollback */
#define CL_DISCONNECT_QUERY 33  /* request that the master check availability of node and eventually disable it */
#define CL_ADMIN 34 /* internal admin action like resync or disable of failed */

/* or'ed to clo_seq_no of batch or set end to indicate db_activity_t for used resources follows */
#define CL_DA_FOLLOWS 0x80000000

/* Opcodes in batches */

#define CLO_NONE 0 /* in a static clo, this means there is no data.  Mist be 0 */
#define CLO_SELECT  22
#define CLO_INSERT 1
#define CLO_INSERT_SOFT 2
#define CLO_INSERT_REPL 3
#define CLO_DELETE 4
#define CLO_DELETE_PLACE 5
#define CLO_INXOP 6
#define CLO_CALL 9
#define CLO_BLOB  10
#define CLO_ROW 11 /* result set row */
#define CLO_BATCH_END 12 /* ask for more to get next batch of results */
#define CLO_SET_END 13 /* end of result set for present cl op */
#define CLO_DDL 14  /* shared schema info changed */
#define CLO_ERROR 15
#define CLO_ITCL 16 /* not a message.  A container for a local itc_cluster_t */
#define CLO_SELECT_SAME 18 /* like first CLO_SELECT, except for params.  So only params are given.  */
#define CLO_NON_UNQ 20 /* reply to non unq insert soft */
#define CLO_QF_PREPARE 21  /* sending a compilation frag */
#define CLO_QF_EXEC 23 /* exec a query frag */
#define CLO_AGG_SET_END 24 /* ret val when aggregating qf done, means that the qf must be left registered even though this is not an end of batch */
#define CLO_AGG_END 25 /* end of a full batch of aggregate inputs.  Send when the whole batch is processed, no set-by-set results */
#define CLO_STATUS 26
#define CLO_DFG_STATE 28 /* record with counts of processed and forwarded sets in a distributed frag */
#define CLO_STN_IN 29 /* input string and state for a dist frag */
#define CLO_DFG_ARRAY 30
#define CLO_DFG_AGG 31  /* request for simple aggregate result from dist frag */
#define CLO_CONTROL 32

/* action codes for ddl messages */
#define CLO_DDL_TABLE 1
#define CLO_DDL_PROC 2
#define CLO_DDL_CLUSTER 3
#define CLO_DDL_TYPE 4
#define CLO_DDL_TRIG 5
#define CLO_DDL_ATOMIC 6
#define CLO_DDL_ATOMIC_OVER 7

/* flags as 1st col of result row of clo_call */
#define CLO_CALL_ROW 1
#define CLO_CALL_RESULT 2
#define CLO_CALL_ERROR 3


/* select.is_text_seek */
#define CLO_TEXT_NONE 0 /* not a text inx op */
#define CLO_TEXT_INIT 1
#define CLO_TEXT_SEEK 2
#define CLO_TEXT_SEEK_NEXT 3
#define CLO_TEXT_SEEK_UNQ 4
#define CLO_TEXT_SAMPLE 5 /* not a text lookup at all but a stats sample */

/* CLO_CONTROL opcodes */
#define CLO_CTL_OFFLINES 1 /* notify list of offline hosts */
#define CLO_CTL_SEQ_REPL 2 /* replicate seq ranges between master and spare */
#define CLO_CTL_ONLINE 3 /* send to master, expect list of offlines as an async reply */


struct cl_message_s
{
  char		cm_op;
  char		cm_is_error;
  char		cm_enlist; /* the trx id is to be handled with 2pc.  The lt is for use with this id only */
  char		cm_cancelled; /* must read the incoming stuff from cm_client but must not do anything else */
  char		cm_registered; /*if suspended waiting for CL_MORE */
  char		cm_res_type; /* whether more is coming from same server */
  int		cm_from_host;
  uint32		cm_req_no;
  int64		cm_bytes;
  int64			cm_trx;
  int64			cm_trx_w_id;
  dk_session_t *	cm_strses;
  caddr_t		cm_in_string; /* str box containing message if message was read by dispatch thread */
  int			cm_in_read_to; /* when suspended between select batches, pointer to next clo in in string */
  int			cm_anytime_quota;
  cl_op_t *		cm_pending_clo; /* Holds select clo when suspended between batches */
  dk_session_t *	cm_client; /* the client detached from served set, worker thread must read the stuff and return this to served set */
  lock_trx_t *		cm_lt; /* While registered, remember the lt so that continuable qi's and itc's keep the lt across transacts */
};

#define cm_n_affected cm_trx_w_id  /* dual use.  n_affected on CL_RESULT */

/* cm_enlist */
#define CM_ENLIST 1
#define CM_LOG 2
#define CM_COMMIT_RESEND 4
#define CM_ENTER_ALWAYS 8 /* for ops that have to go through despite cpt or atomic, like seq range replication */
#define CM_CONTROL 16 /* if set, dispatch the op even if recipient not fully online */
#define CM_START_ATOMIC 32 /* at transaction enter, set the host to atomic if not yet, proceed then to rb */
#define CM_DIRECT_IO 64 /* the connection will continue with other protocol, the server func will read and write directly to this connection */


/* cm_res_type */
#define CM_NO_RES 0
#define CM_RES_INTERMEDIATE 1
#define CM_RES_FINAL 2
#define CM_RES_CONTINUABLE 3
#define CM_RES_CANCELLED 4 /* means that the clib is out of the waiting set and can't get results or even timeout */


/* api */





#define CLUSTER_PWD "clu"

#define CL_NO_THREADS "CLNTH"
/* values of clib_error and return codes */
#define CLE_OK 0
#define CLE_DISCONNECT 1 /* remote party dead */
#define CLE_SQL 2 /* misc sql error, later in the message */
#define CLE_TRX 3


int  clrg_destroy (cl_req_group_t * clrg);
cl_req_group_t * clrg_copy (cl_req_group_t * clrg);
void clrg_set_lt (cl_req_group_t * clrg, lock_trx_t * lt);
int clrg_wait (cl_req_group_t * clrg, int mode, caddr_t * qst);
#define CLRG_WAIT_ANY 0
#define CLRG_WAIT_ALL 1
int clrg_wait_1 (cl_req_group_t * clrg, int wait_all);
cl_op_t * clo_allocate (char op);
cl_op_t * clo_allocate_2 (char op);
cl_op_t * clo_allocate_3 (char op);
cl_op_t * clo_allocate_4 (char op);
void clo_local_copy (cl_op_t * clo, cl_req_group_t * clrg);
int clo_destroy  (cl_op_t * clop);
cl_op_t * clib_first (cll_in_box_t * clib);
cl_message_t * cl_deserialize_cl_message_t (dk_session_t * in);
cl_host_t * cl_name_to_host (char * name);
itc_cluster_t * itcl_allocate (lock_trx_t * lt, caddr_t * qst);

extern int32 cl_req_batch_size;
extern int32 cl_dfg_batch_bytes;
extern uint32 cl_send_high_water;
extern int32 cl_batches_per_rpc; /* no of rows to send before stopping to wait for a CL_MORE message */
extern int32  cl_res_buffer_bytes; /* no of bytes before sending to client */
extern long dbf_branch_transact_wait;
extern int32 cl_wait_query_delay;

int  clrg_send (cl_req_group_t * clrg);
void cl_table_source_input (table_source_t * ts, caddr_t * inst, caddr_t * state);
void cl_insert_node_input (insert_node_t * ins, caddr_t * inst, caddr_t * state);

extern cl_listener_t local_cll;
extern resource_t * cl_strses_rc;
extern int64 cl_cum_messages;
extern int64 cl_cum_txn_messages;
extern int64 cl_cum_bytes;
extern int64 cl_cum_wait;
extern int64 cl_cum_wait_msec;
cl_op_t * cl_deserialize_cl_op_t  (dk_session_t * in);
cl_req_group_t * cl_req_group (lock_trx_t * lt);
int clrg_result_array (cl_req_group_t * clrg, cl_op_t ** res, int * fill_ret, int max, caddr_t * qst);

/*
resource_t * cl_str_1;

resource_t * cl_str_2;
resource_t * cl_str_3;
*/
void cl_msg_string_free (caddr_t str);

void cm_free (cl_message_t * cm);
int cl_process_message (dk_session_t * ses, cl_message_t * cm);
void cl_self_cm_srv (void* cmv);
void clt_process_cm (cl_thread_t * clt, cl_message_t * cm);
void cm_send_reply (cl_message_t * cm, cl_op_t * reply, caddr_t err);
extern du_thread_t * cl_listener_thr;
void  cls_rollback (dk_session_t * ses, cl_message_t * cm);
cl_host_t * cl_id_to_host (int id);
cluster_map_t * cl_name_to_clm (char * name);
void cl_itc_free (it_cursor_t * itc);
void itc_cl_row (it_cursor_t * itc, buffer_desc_t * buf);
dk_session_t * ch_get_connection (cl_host_t * ch, int op, caddr_t * err_ret);
int  itc_insert_rd (it_cursor_t * itc, row_delta_t * rd, buffer_desc_t ** unq_buf);
int clrg_add_transact_1 (cl_req_group_t * clrg, cl_host_t * host, int op, caddr_t args);
#define clrg_add_transact(c,h,o) clrg_add_transact_1 (c, h, o, NULL)
int clrg_add (cl_req_group_t * clrg, cl_host_t * host, cl_op_t * clop);

void cl_serialize_cl_message_t (dk_session_t * out, cl_message_t * cl);
void cl_serialize_cl_op_t (dk_session_t * ses, cl_op_t * clo);
void  cl_serialize_db_activity_t (dk_session_t * out, db_activity_t * s);
void cl_deserialize_db_activity_t (dk_session_t * in);

void clib_parse (cll_in_box_t * clib);
void cluster_init ();
void cluster_schema ();
void cluster_built_in_schema ();
void cluster_listen ();
void cluster_online ();
void cluster_after_online ();

void cls_transact (cl_thread_t * clt, cl_message_t * cm);
int64 read_boxint (dk_session_t * ses);
void clib_local_next (cll_in_box_t * clib);
int rd_is_blob (row_delta_t * rd, int nth);
void  cl_check_in (dk_session_t * ses);
void cl_check_out (dk_session_t * ses);
void cl_self_signal (void (*f)(void* _cd), void* cd);

#define IN_CLL mutex_enter (local_cll.cll_mtx)
#define LEAVE_CLL mutex_leave (local_cll.cll_mtx)
void cl_write_done (dk_session_t * ses);
caddr_t clrg_error_ck (cl_req_group_t * clrg, int rc, int signal);
void itcl_error_ck (itc_cluster_t * itcl, int rc);
int cl_transact (lock_trx_t * lt, int op, int trx_free);
void cl_rollback_local_cms (lock_trx_t * lt);

#define CLO_HEAD(ses, op, seq, nth_param_row)			\
{ \
  session_buffered_write_char (op, ses); \
  print_int (seq, ses); \
  print_int (nth_param_row, ses); \
}


#define CLO_HEAD_STAT(ses, op, seq, nth_param_row)			\
{ \
  session_buffered_write_char (op, ses); \
  print_int ((uint32)(CL_DA_FOLLOWS | seq), ses);	\
  print_int (nth_param_row, ses); \
  cl_serialize_db_activity_t (ses, &sqlc_client()->cli_activity); \
}

#define CLO_HEAD_LAST_STAT(clt, ses, op, seq, nth) \
{ \
  if (clt->clt_current_cm->cm_in_read_to == clt->clt_current_cm->cm_bytes) { \
    CLO_HEAD_STAT (ses, op, seq, nth); } \
  else \
    CLO_HEAD (ses, op, seq, nth); \
}


caddr_t cl_ddl (query_instance_t * qi, lock_trx_t * lt, caddr_t name, int type, caddr_t trig_table);
caddr_t cl_start_atomic (query_instance_t * qi, caddr_t name, int type);
void cl_local_atomic_over ();
caddr_t cl_read_partition (query_instance_t * qi, caddr_t tb_name);
caddr_t cl_read_cluster (query_instance_t * qi, caddr_t name);
void  clib_more (cll_in_box_t * clib);
cl_op_t * mp_clo_allocate (mem_pool_t * mp, char op);

#ifdef MTX_DEBUG
#define cl_printf(a) printf a
#else
#define cl_printf(a)
#endif
void  clib_read_next (cll_in_box_t * clib, caddr_t * inst, dk_set_t out_slots);
void clib_rc_init ();

#define CL_CONN_ERROR(error, ses, host, errno_save)				\
  { if (CH_REMOVED != host->ch_status) host->ch_status = CH_OFFLINE; \
  if (&error) error = srv_make_new_error ("08C01", "CL...", "Cluster could not connect to host %d %s error %d", (int)host->ch_id, host->ch_connect_string, (int)errno_save);}

void cl_node_init (table_source_t * ts, caddr_t * inst);

#define IS_CL_NODE(ts) \
  (IS_TS (ts) || (qn_input_fn) insert_node_input == ts->src_gen.src_input \
   || (qn_input_fn) query_frag_input == ts->src_gen.src_input \
   || (qn_input_fn) dpipe_node_input == ts->src_gen.src_input \
   || (qn_input_fn) code_node_input == ts->src_gen.src_input \
   || (qn_input_fn) fun_ref_node_input == ts->src_gen.src_input \
   || IS_STN (ts) \
  )


int itc_cl_local (it_cursor_t * itc, buffer_desc_t * buf);
int itc_cl_others_ready (it_cursor_t * itc);
void cl_row_set_out_cols (dk_set_t slots, caddr_t * inst, cl_op_t * clo);
void cl_select_save_env (table_source_t * ts, itc_cluster_t * itcl, caddr_t * inst, cl_op_t * clo, int nth);
void cl_ts_set_context (table_source_t * ts, itc_cluster_t * itcl, caddr_t * inst, int nth_set);
extern dk_hash_t * cl_inx_to_ssl;
query_t * cl_set_id_qf (uint32 ch_id, uint32 qf_id, query_t * qf);
query_t * cl_id_qf (uint32 ch_id, uint32 qf_id);
void cl_serialize_query_frag_t (dk_session_t * out, query_frag_t * s);
int cl_send (cl_host_t * host, cl_message_t * cm, caddr_t * err_ret);
void cl_qf_free (query_frag_t * qf);
void cl_qr_done (query_t * qr);
void cl_dml_results (update_node_t * upd, caddr_t * inst);
void cl_delete_keys (delete_node_t * del, caddr_t * inst, row_delta_t * main_rd);
void itc_delete_rd (it_cursor_t * itc, row_delta_t * rd);
int32  strses_out_bytes (dk_session_t * ses);
int clt_flush (cl_thread_t * clt, int is_final);
void cl_update_keys (update_node_t * upd, caddr_t * inst, row_delta_t * main_rd, row_delta_t * new_rd, dk_set_t keys, int ins_new_rd);
void cl_dml_ac_check (query_instance_t * qi, dbe_key_t * key);
int cl_is_ac_dml (query_instance_t * qi);



#define QFID_HOST(i) ((int)(((unsigned int64) (i)) >> 32))

void cl_trx_init ();
extern basket_t cl_trx_queue;
extern semaphore_t * cl_trx_sem;
extern dk_mutex_t * cl_trx_mtx;
extern dk_mutex_t * cl_trx_graph_mtx;
extern dk_hash_64_t * cl_w_id_to_ctrx;
extern cl_host_t * cl_master;

void cl_notify_wait (gen_lock_t * pl, it_cursor_t * itc, buffer_desc_t * buf);
void cl_notify_transact (lock_trx_t * lt);
void cl_master_notify_transact (int64 w_id);
void lt_kill_while_2pc_prepare (lock_trx_t * lt);
void lt_expedite_1pc (lock_trx_t * lt);
void lt_send_rollbacks (lock_trx_t * lt, int sync);
extern int cl_trx_inited;
#define CTRX_H_ID(c) ((int) (c->ctrx_w_id >> 32))
#define CTRX_W_ID(c) ((int32) (c->ctrx_w_id))
#if 0
#define ctrx_printf(x) printf x
#else
#define ctrx_printf(x)
#endif
void cl_clear_dead_w_id ();

#define THR_DBG_CLRG_WAIT ((caddr_t) 1)

void cl_notify_disconnect (int host);
void clo_unlink_clib (cl_op_t * clo, cll_in_box_t * clib, int is_allocd);
void bif_daq_init ();
void cls_call (cl_thread_t * clt, cl_op_t * clo);
void clt_send_error (cl_thread_t * clt, caddr_t err);
uint32 col_part_hash (col_partition_t * cp, caddr_t val, int is_already_cast, int * cast_ret, int32 * rem_ret);
/* for is_already_cast */
#define CP_CAST 0
#define CP_NO_CAST 1
#define CP_CAST_NO_ERROR 2

cl_host_t * clm_choose_host (cluster_map_t * clm, cl_host_t ** group, cl_op_t * clo, int part_mode, int32 rem);
cl_host_t * chg_first (cl_host_t ** group);

cl_host_t **  clm_group (cluster_map_t * clm, uint32 hash, int op);
void  query_frag_run (query_frag_t * qf, caddr_t * inst, caddr_t * state);
int cls_wst_select (cl_thread_t * clt, cl_op_t * clo);
void clt_itc_error (cl_thread_t * clt, it_cursor_t * itc);
int64 itc_cl_sample (it_cursor_t * itc);
void itc_cl_sample_init (it_cursor_t * itc, cl_req_group_t ** clrg_ret);
int64 itc_cl_sample_result (it_cursor_t * itc, cl_req_group_t * clrg);

void cu_free (cucurbit_t * cu);
void dpipe_define (caddr_t name, dbe_key_t * key, caddr_t fn,
		   cu_op_func_t fn_disp, int l);
/* dpipe define flags */
#define CF_UPDATE 1
#define CF_1_ARG 2
#define CF_FIRST_RW 4 /* rw of the first partition of the value */
#define CF_REST_RW 8 /* update of replica partitions */
#define CF_READ_NO_TXN 16
#define CF_IS_BIF 32
#define CF_IS_DISPATCH 64
#define CF_SINGLE_ACTION 128 /* one call gets the job done, can be colocated as an ordinary proc call */

void dpipe_refresh_schema ();
void cl_rdf_init ();
void clrg_check_trx_error (cl_req_group_t * clrg, caddr_t * err);

#define SQLSTATE_IS_TXN(s) (0 == strncmp (s, "400", 3) || 0 == strncmp (s, "08", 2) || 0 == strncmp (s, "S1T0", 4))
void cl_read_dpipes ();
caddr_t * cu_next (cucurbit_t * cu, query_instance_t * qi, int is_flush);
void  dpipe_node_input (dpipe_node_t * dp, caddr_t * inst, caddr_t * state);
void dpipe_node_local_input (dpipe_node_t * dp, caddr_t * inst, caddr_t * stat);
void  dpipe_node_free (dpipe_node_t * dp);
#define IS_DP(xx) ((qn_input_fn)dpipe_node_input == ((data_source_t*)(xx))->src_input)
cu_func_t * cu_func (caddr_t name, int must_find);
void cu_ssl_row (cucurbit_t * cu, caddr_t * qst, state_slot_t ** args, int first_ssl);
void cl_fref_result (fun_ref_node_t * fref, caddr_t * inst, cl_op_t ** clo_ret);
void itc_ks_qf_result (it_cursor_t * itc, buffer_desc_t * buf, key_source_t * ks);
int cl_partitioned_fref_start (dk_set_t nodes, caddr_t * inst);
void ch_qf_closed (cl_host_t * ch, uint32 req_no, cl_message_t * cm);
void cl_timeout_closed_qfs ();
void cm_free_pending_clo (cl_message_t * cm);
void cl_lt_drop_ref (lock_trx_t * lt, int is_cancel);

extern int qf_trace;
int cls_autocommit (cl_thread_t * clt, cl_op_t * clo, caddr_t err, int recov_deadlock);
void  cl_local_insert (caddr_t * inst, cl_op_t * clo);
void  cl_local_delete (caddr_t * inst, cl_op_t * clo);
cl_req_group_t * dpipe_allocate (query_instance_t * qi, int flags, int n_ops, char ** ops);
void cu_row (cucurbit_t * cu, caddr_t * args);
caddr_t * cu_next (cucurbit_t * cu, query_instance_t * qi, int is_flush);
caddr_t cl_iri_to_id (query_instance_t * qi, caddr_t str, int make_new);
caddr_t cl_id_to_iri (query_instance_t * qi, caddr_t id);
void cu_set_value (cucurbit_t * cu, value_state_t * vs, caddr_t val);
cl_op_t * cl_key_insert_op_vec (caddr_t * qst, dbe_key_t * key, int ins_mode,
		      char ** col_names, caddr_t * values,
		      cl_req_group_t * clrg, int seq, int nth_set);
cl_op_t * cl_key_delete_op_vec (caddr_t * qst, dbe_key_t * key,
				char ** col_names, caddr_t * values,
				cl_req_group_t * clrg, int seq, int nth_set);

void array_add (caddr_t ** ap, int * fill, caddr_t elt);
void mp_array_add (mem_pool_t * mp, caddr_t ** ap, int * fill, caddr_t elt);
cl_req_group_t * bif_clrg_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func);
void cl_refresh_status (query_instance_t * qi, int mode);
#define CLST_REFRESH 0
#define CLST_SUMMARY 1
#define CLST_DETAILS 2
void cst_fill_local (cl_status_t * cst);
extern int32 cl_n_hosts;
extern int32 cl_max_hosts;
boxint cl_sequence_next (query_instance_t * qi, caddr_t seq, int step, boxint sz, int in_map, caddr_t * err_ret);

extern int32 cl_stage; /* during init, how far come, one of the values of ch_status */

caddr_t  cl_msg_string (int64 bytes);
int cm_read_in_string (cl_message_t * cm);
int cl_trx_check (int64 trx_no, int retry, int ask_host);
void cls_blob_send (cl_thread_t * clt, cl_message_t * cm);
int  cl_get_blob (lock_trx_t * lt, blob_handle_t * bh, int64 n, int64 skip, dk_session_t ** ses_ret);
dk_set_t  cl_bh_string_list (lock_trx_t * lt, blob_handle_t * bh, int64 n, int64 skip);
void  cls_timeouts (int flags);
#define CL_TIMEOUT_ALL 1 /* cls_timeouts will mark all as timed out to recover from arbitrary hang */
void cu_dispatch (cucurbit_t * cu, value_state_t * vs, cu_func_t * cf, caddr_t val);
void cl_send_kill (int64 lt_w_id, int host_id);
int cl_send_commit (int64 w_id, int to_host);
void cl_schedule_admin (caddr_t text);
void cl_disconnect_query (cl_host_t * ch);
void cl_send_all_atomic (int flag);
void cls_wait_query ();
void cls_seq_alloc (cl_thread_t * clt, cl_message_t * cm);
void lt_io_start (lock_trx_t * lt);
void lt_io_end (lock_trx_t * lt);

void cl_request_wait_query ();
int qn_has_clb_save (data_source_t * qn);
int itcl_fetch_to_set (itc_cluster_t * itcl, int nth);
caddr_t bif_cl_set_switch (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
void ssa_set_switch (setp_save_t * ssa, caddr_t * inst, int set);
void cl_set_switch (caddr_t * inst, state_slot_t * set_no, state_slot_t * current_set, state_slot_t * array, state_slot_t ** save, int n_save, int target_set, int cl_batch, state_slot_t ** defaults);
void cl_qr_skip_to_set (query_t * qr, caddr_t *  inst, state_slot_t * set_no_ssl, int target_set);
void cl_local_skip_to_set (cll_in_box_t * clib);
int itcl_skip_to_set (itc_cluster_t * itcl, int nth);
void cl_qr_async_flush (query_t * qr, caddr_t * inst, dk_set_t nodes);
void cl_co_flush (table_source_t * ts, caddr_t * inst);

#define IS_MAX_ROWS(m) ((m) && 0 == --(m))
void  cl_rdf_inf_init (client_connection_t * cli, caddr_t * err_ret);

int  itcl_dfg_set_end (itc_cluster_t * itcl, cll_in_box_t * clib);

#define IS_QF(qf) ((qn_input_fn)query_frag_input == ((data_source_t*)qf)->src_input)
#define IS_STN(qf) ((qn_input_fn)stage_node_input == ((data_source_t*)qf)->src_input)

void stage_node_input (stage_node_t * stn, caddr_t * inst, caddr_t * state);
void stage_node_free (stage_node_t * stn);
void dfg_resume_pending (query_t * subq, query_instance_t * qi, dk_set_t nodes, int * any_done, stage_node_t * successors_only);
void dfg_coord_batch (itc_cluster_t *itcl, cll_in_box_t * clib);
int  clib_enlist (cll_in_box_t * clib, cl_message_t * cm);
void clib_read_into_slots (cll_in_box_t * clib, caddr_t * qst, dk_set_t slots);
void itc_locate (it_cursor_t * itc, dk_set_t * hosts_ret, cl_op_t * op, int * is_local,
	    cl_req_group_t ** clrg_ret, lock_trx_t * lt);
void qf_locate (cl_op_t * op, caddr_t * qst, int * is_local,
	   cl_req_group_t ** clrg_ret, lock_trx_t * lt);
void rd_locate (row_delta_t * rd, dk_set_t * hosts_ret, cl_op_t * op, int * is_local,
	   cl_req_group_t ** clrg_ret, lock_trx_t * lt);

void rd_free_temp_blobs (row_delta_t * rd, lock_trx_t * lt, int is_local);
int cl_handle_reset (cl_op_t * clo, cl_thread_t * clt, query_instance_t * qi, int reset_code);
void clib_assign_req_no (cll_in_box_t * clib);
cll_in_box_t * itcl_local_start (itc_cluster_t * itcl);
cl_op_t * itcl_next (itc_cluster_t * itcl);
cl_op_t * itcl_next_no_order (itc_cluster_t * itcl, cl_buffer_t * clb);

void qf_trace_ret (query_frag_t * qf, itc_cluster_t * itcl, cl_op_t * clo);
void cl_dfg_start_search (query_frag_t * qf, caddr_t * inst);
void cl_dfg_results (query_frag_t * qf, caddr_t * inst);
int cl_dfg_continue (cl_thread_t * clt, cl_op_t * clo);
int cl_dfg_exec (cl_thread_t * clt, cl_op_t * clo);
void stn_set_in_slots (stage_node_t * stn);
void dfg_batch_end (dk_set_t nodes, caddr_t * inst, int n_stages, cll_in_box_t * local_clib);
void cl_dfg_flush (dk_set_t nodes, caddr_t * inst, caddr_t * err_ret);
void cm_unregister (cl_message_t * cm, cl_host_t * ch);
int dfg_coord_should_pause (itc_cluster_t * itcl);
table_source_t * sqlg_loc_ts (table_source_t * ts, table_source_t * prev_loc_ts);
void lt_free_branches (lock_trx_t * lt);
void cl_fref_dfg_done (dk_set_t nodes, caddr_t * inst);
stage_node_t * qf_nth_stage (dk_set_t nodes, int nth);

void cluster_bifs ();

#define CL_MARK_MSG(lt, bytes)			\
  {if (lt) {lt->lt_client->cli_activity.da_cl_messages++; lt->lt_client->cli_activity.da_cl_bytes += bytes;}}

void sel_multistate_top (select_node_t *sel, caddr_t * inst);
void cl_write_disconnect_srv (void* cd);
void cl_rdf_bif_check_init (bif_t bif);

#define QF_XML(qi,par) \
  { \
dtp_t dtp = DV_TYPE_OF (par); \
  if (DV_XML_ENTITY == dtp || DV_ARRAY_OF_POINTER == dtp) \
    xte_set_qi (par, qi); \
}

int qi_anytime_send_check (caddr_t * inst);
char *  cl_thr_stat ();

int  key_is_known_partition (dbe_key_t * key, caddr_t * qst, search_spec_t * ksp, search_spec_t * rsp, uint32 * hash_ret, it_cursor_t * itc, int32 * rem_ret);
#define KP_ALL 0
#define KP_ONE 1
#define KP_NULL 2


#define IS_CL_TXS(txs) \
  ((qn_input_fn)txs_input == ((data_source_t*)txs)->src_input   && ((text_node_t*)txs)->txs_loc_ts)

int key_is_d_id_partition (dbe_key_t * key);
void lt_set_w_id (lock_trx_t * lt, int64 w_id);
caddr_t cl_read_map ();
void cluster_after_online ();
void cl_qi_count_affected (query_instance_t * qi, cl_req_group_t * clrg);
void ch_qf_closed (cl_host_t * ch, uint32 req_no, cl_message_t * cm);


int cl_w_timeout_hook (dk_session_t * ses);
#if 1
#define io_printf(a)
#else
#define io_printf(a) printf a
#endif

#define CL_ONLINE_CK \
  {if (CH_ONLINE !=cl_stage && CL_RUN_CLUSTER == cl_run_local_only) sqlr_new_error ("08C06", "CLNJO", "Cluster operations not allowed until confirmed online");}

void cl_flt_init ();
void cl_flt_init_2 ();
extern cluster_map_t * clm_all;
dk_session_t * dks_file (char * name, int flags);
void clib_row_boxes (cll_in_box_t * clib);
void clib_prepare_read_rows (cll_in_box_t * clib);
void clrg_add_clib (cl_req_group_t * clrg, cll_in_box_t * clib);
uint32 cp_string_hash (col_partition_t * cp, caddr_t bytes, int len, int32 * rem_ret);

#define N_ONES(n) ((1 << (n)) - 1)


#define cp_int_hash(cp, i, rem_ret)				\
  ((*rem_ret = (cp->cp_shift << 24) | (cp->cp_shift ? (i & N_ONES (cp->cp_shift)) : -1)), \
   ((((unsigned int64)i) >> cp->cp_shift) & cp->cp_mask))



extern dk_mutex_t * clrg_ref_mtx;
extern long dbf_cpt_rb;
cll_in_box_t * clib_allocate ();
id_hash_t * dict_ht (id_hash_iterator_t * dict);
void dpipe_signature (caddr_t name, int n_args, ...);
#define CU_CLI(cu) ((cu)->cu_clrg->clrg_lt ? (cu)->cu_clrg->clrg_lt->lt_client : NULL)


#endif

/*
 *  ltrx.h
 *
 *  $Id$
 *
 *  Locking transaction structures
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

#ifndef _LTRX_H
#define _LTRX_H

#define LT_FREEZE 0
#define LT_PENDING		1
#define LT_COMMITTED		2
#define LT_BLOWN_OFF		ltbing (3) /* Marked to be rolled back */
#define LT_BLOWN_OFF_C 3
#define LT_CLOSING		4 /* locks being released, finalizing commit / rollback, inside lt_transact */
#define LT_DELTA_ROLLED_BACK	5 /* Only the trx object to be released */

#ifdef VIRTTP
#define LT_PREPARE_PENDING 	6
#define LT_PREPARED LT_COMMITTED
#define LT_FINAL_COMMIT_PENDING	7 /* when the commit came in, but there's a thread inside */
#endif

/* bit mask for lt_transact operation */
#define LT_CPT_WAIT 		0
#define LT_CPT_NO_WAIT 		0x8
#define LT_CPT_FLAG_MASK 	0x7

#define LT_CL_PREPARED 8 /* in cluster, first phase of commit started or finished.  Cancellable any time, during and after  */
#define LT_1PC_PENDING 9 /* waiting for cluster 1pc reply */
#define LT_2PC_PENDING 10 /* waiting for cluster 2pc replies */
#define LTE_OK		0
#define LTE_TIMEOUT	1
#define LTE_DEADLOCK	2
#define LTE_NO_DISK	3
#define LTE_LOG_FAILED	4
#define LTE_UNIQ	5
#define LTE_SQL_ERROR	6 /* Misc SQL STATE in log_replay_trx.  lt_error set
			     to this when misc. SQL error requires txn to be
			     rolled back.*/
#define LTE_2PC_ERROR	7
#define LTE_REMOTE_DISCONNECT 8 /* when the remote has disconnected it's connection */
#define LTE_CHECKPOINT 9 /* a checkpoint */
#define LTE_LOG_IMAGE 10
#define LTE_OUT_OF_MEM 11 /* out of memory */
#define LTE_REJECT    12  /* reject modifications */
#define LTE_CLUSTER 13 /* disconnect of peer */
#define LTE_CANCEL 14 /* async rollback from other thread */
#define LTE_CLUSTER_SYNC 15 /* unsynced async updates at time of transact */
#define LTE_PREPARED_NOT_COMMITTED 16 /* if a commit msg was dropped, then another action on same trx no, give this error */
#define LTE_UNSPECIFIED 17 /* use when not OK but no lte */

#define SET_DK_MEM_RESERVE_STATE(trx) \
     { \
       if (trx) \
	 { \
	   (trx)->lt_error = LTE_OUT_OF_MEM; \
	   (trx)->lt_status = LT_BLOWN_OFF; \
	 } \
     }

#define DK_MEM_RESERVE \
   DK_ALLOC_ON_RESERVE

#define CHECK_DK_MEM_RESERVE(trx) \
   if (DK_ALLOC_ON_RESERVE) \
     SET_DK_MEM_RESERVE_STATE (trx)


#ifndef SQL_ROLLBACK
# define SQL_COMMIT		0
# define SQL_ROLLBACK		1
#endif


#define REPL_NO_LOG	((caddr_t *) 1L)
#define REPL_LOG	((caddr_t *) 2L)

#define TM_LOCK		0
#define TM_SNAPSHOT	1



typedef struct rb_entry_s
  {
    db_buf_t	rbe_string;
    struct rb_entry_s * rbe_next;
    key_id_t	rbe_key_id;
    short	rbe_row;
    short	rbe_row_len;
    char	rbe_op;
    char	rbe_used;
  } rb_entry_t;

#define RB_INSERT ((char) -1)
#define RB_UPDATE ((char) 0)
struct lock_trx_s;
#ifdef VIRTTP
struct tp_dtrx_s;
#endif
typedef void (*trx_hook_t) (struct lock_trx_s *);

/* #define CHECK_LT_THREADS */

#ifdef CHECK_LT_THREADS
#define LT_ENTER_SAVE(lt) \
do { \
  (lt)->lt_enter_file = __FILE__; \
  (lt)->lt_enter_line = __LINE__; \
} while (0)
#define LT_CLOSE_ACK_THREADS(lt) \
    do { \
      if (!(lt)->lt_last_increase_file[0]) \
        { \
	  (lt)->lt_last_increase_file[0] = __FILE__; \
	  (lt)->lt_last_increase_line[0] = __LINE__; \
	} \
      else if (!(lt)->lt_last_increase_file[1]) \
	{ \
	  (lt)->lt_last_increase_file[1] = __FILE__; \
	  (lt)->lt_last_increase_line[1] = __LINE__; \
	} \
      else \
	{ \
	  (lt)->lt_last_increase_file[1] = (lt)->lt_last_increase_file[0]; \
	  (lt)->lt_last_increase_line[1] = (lt)->lt_last_increase_line[0]; \
	  (lt)->lt_last_increase_file[1] = __FILE__; \
	  (lt)->lt_last_increase_line[1] = __LINE__; \
	} \
    } while (0)
#define LT_THREADS_REPORT(lt, action) \
  log_debug_dummy ("%s:%d : lt_threads %s to %d for lt %p on thread %p",	\
	__FILE__, __LINE__, action, \
	lt->lt_threads, \
		 lt, THREAD_CURRENT_THREAD)
#define lt_log_debug(x)
#else
#define LT_ENTER_SAVE(lt)
#define LT_CLOSE_ACK_THREADS(lt)
#define LT_THREADS_REPORT(lt, action)
#define lt_log_debug(x)
#endif

typedef struct lt_cl_branch_s {
  char 		clbr_change;
  cl_host_t *	clbr_host;
} lt_cl_branch_t;

#define CLBR_READ 0
#define CLBR_WRITE 1
#define CLBR_DONE 2 /* a read branch that already got a commit needs no rb if commit fails */

#define LT_TRACE_SZ 10

#ifdef LT_TRACE_SZ
#define LT_TRACE(lt) \
  { if (LT_ID_FREE == lt->lt_trx_no) GPF_T1 ("ref to freed lt"); lt->lt_line[lt->lt_trace_ctr++ % LT_TRACE_SZ] = __LINE__;  }

#define LT_TRACE_2(lt, n)							\
  { if (LT_ID_FREE == lt->lt_trx_no) GPF_T1 ("ref to freed lt"); lt->lt_line[lt->lt_trace_ctr++ % LT_TRACE_SZ] = __LINE__ + 10000 * n;  }

#else
#define LT_TRACE(lt)
#endif


typedef struct log_merge_s
{
  dk_session_t *	lm_log;
  dk_set_t	lm_blob_log;
} log_merge_t;

typedef struct lock_trx_s
  {
    char			lt_status;
    char			lt_mode;  /* lock / snapshot  */
    char			lt_is_excl;
    char			lt_error;
    char		lt_cl_enlisted;
    char		lt_is_cl_server; /* serving a cluster req, whether enlisted or not */
    char		lt_cl_detached; /* cl branch may commit independently but not hold locks if waiting for further cl ops  */
    int			lt_threads;
    int			lt_cl_ref_count; /* no of cluster continuable itc's or qf's wit ref to this.  Don't free until all gone.  Under wi_txn_mtx. No resetting on lt_clear, also no writing outside of txn_mtx, also not in lt_clear */
    int64		lt_trx_no;
    struct client_connection_s *	lt_client;
    dk_mutex_t		lt_locks_mtx;
    dk_mutex_t		lt_rb_mtx;
    dk_mutex_t *	lt_log_mtx;
    dk_hash_t *		lt_rb_hash;
    dk_hash_t *		lt_dirty_blobs;	/* Hashtable of blobs modified by transaction, some are deld at commit, others at rollback */
    resource_t *	lt_alt_trx_nos; /* alternate trx_nos for use in identifying multiple threads per lt on the same cluster remote */

    dk_session_t *	lt_log;
    dk_set_t		lt_remotes;
    thread_t *		lt_thr;
#ifdef LT_TRACE_SZ
    unsigned int	lt_trace_ctr;
    int	lt_line[LT_TRACE_SZ];
#endif
    char		lt_has_branches;
    dk_hash_t 		lt_lock;
#define lt_has_locks(lt) ((lt)->lt_lock.ht_count)
    /* all below members are considered data area and cleared with memset in lt_cleare, saving individual ones as needed */
#define LT_DATA_AREA_FIRST lt_waits_for
    dk_set_t		lt_waits_for;
    dk_set_t		lt_waiting_for_this;
#ifdef CHECK_LT_THREADS
    const char *	lt_enter_file;
    int	        	lt_enter_line;
    const char *	lt_last_increase_file[2];
    int			lt_last_increase_line[2];
#endif
    int		lt_age;
    int		lt_n_col_locks;
    int			lt_lw_threads;
    int			lt_close_ack_threads;
    int			lt_vdb_threads;
    uint32		lt_timeout;
    uint32		lt_started;
    uint32		lt_last_enter_time;
    uint32		lt_wait_since;
    caddr_t *		lt_replicate;
    int                 lt_repl_is_raw;
    int			lt_log_fd;
    caddr_t		lt_log_name;
    dk_set_t		lt_blob_log; /* pdl of blob start addresses to log. Zero if overwritten in the same trx */
    dk_set_t	lt_log_merge;
    char		lt_timestamp[DT_LENGTH];
    char		lt_approx_dt[DT_LENGTH];
    char		lt_mt_waits; /* if branch or main lt of mt txn with writing branches with same rc w id.  Do not remove waits from wait graph, could be waiting on many threads */
    dk_session_t *	lt_backup;  /* if running an online backup,
				     * the session to the backup device */
    int64		lt_backup_length;

    db_buf_t		lt_rb_page;
    short		lt_rbp_fill;
    dk_set_t		lt_rb_pages;


    dk_set_t		lt_wait_end; /* threads waiting for commit / rollback to finalize */

    void *		lt_cd;
    trx_hook_t		lt_commit_hook;
    trx_hook_t		lt_rollback_hook;
    dk_set_t		lt_repl_logs;
    caddr_t		lt_replica_of;
    /* in repl feed replay this is the remote server name that originated the action */
    struct dbe_schema_s *	lt_pending_schema;

    /* External TP's transaction info */
#ifdef VIRTTP
    struct {
      int		_2pc_type;
      int		_2pc_params;
      struct tp_dtrx_s* _2pc_info;
      OFF_T		_2pc_logged;
      box_t		_2pc_log;
      caddr_t		_2pc_prepared;
      dk_set_t		_2pc_remotes;
      int		_2pc_invalid; /* is set if one of branches in unreachable  */
      box_t             _2pc_xid;
      char              _2pc_wait_commit;
    } lt_2pc;
#endif

    dk_hash_t *	lt_upd_hi;  /* for each update node active in txn, the set of affected hi's */
    dk_set_t		lt_hi_delta;
    int64		lt_w_id;
    int64		lt_rc_w_id; /* in a parallel query branch, set this to the lt_w_id of the starting lt so as to see the same uncommitted state in read committed */
    int64		lt_main_trx_no; /* in a branch for a dfg, must issue requests with this trx no, not the local one */
    dk_set_t 		lt_cl_branches; /* cl_host_t for cluster hosts in same commit */
    caddr_t		lt_2pc_hosts; /* list of host ids with prepared state.  Use for recov consensus */
    struct cl_host_s *	lt_branch_of;
    OFF_T		lt_commit_flag_offset; /* use for updating log record state in 2pc */
    char		lt_need_branch_consensus; /* prepared originating from self comes in log sync. Must ask other branches what became of it. */
    char		lt_cl_main_enlisted; /* set if branch of enlisted, forward enlist */
    char		lt_known_in_cl; /* if ever participated in wait or had remote branch, must notify monitor of transact, else not */
    char		lt_log_2pc;
    char		lt_transact_notify_sent; /* if non-monitor commits a branch on the monitor, no separate notify wanted */
    char		lt_cl_server_recd_rb;
    char		lt_at_end_of_aq_thread;
    struct cl_req_group_s *	lt_clrg;
    caddr_t		lt_error_detail; /* if non-zero fill it with details about the error at hand */
#ifdef MSDTC_DEBUG
    bitf_t 		lt_in_mts:1;
#endif
    char 		lt_name[20];
    struct name_id_cache_s *	lt_rdf_prefix;
    struct name_id_cache_s *	lt_rdf_iri;
  } lock_trx_t;

#define LT_LAST_RESERVED_NO 10 /* the first so many trx_no are reserved for temp use, no real transaction uses them */
#define LT_ID_FREE ((int64)-1) /* lt_w_id and lt_trx_no when lt is free in trx_rc */

#define LT_SEES_EFFECT(branch, owner) \
  (branch == owner || branch->lt_rc_w_id == owner->lt_w_id)

#define IS_MT_BRANCH(lt)  ((lt)->lt_rc_w_id && (lt)->lt_rc_w_id != (lt)->lt_w_id)

#define LT_MAIN_W_ID(lt) ((lt)->lt_rc_w_id ? (lt)->lt_rc_w_id : (lt)->lt_w_id)
#define LT_MAIN_TRX_NO(lt) ((lt)->lt_main_trx_no ? (lt)->lt_main_trx_no : (lt)->lt_trx_no)

#define LTN_HOST(ltn) ((uint32)((ltn) >> 32))
#define LTN_NO(ltn) ((uint32)((ltn) & 0xffffffff))

#define W_ID_GT(w1, w2) \
  (((uint32)(w1)) - ((uint32)(w2)) < 0x80000000)

#define LOCK_MAX_WAITS 1024 /* no more than this many queued on a single lock */

typedef struct lock_wait_s {
  lock_trx_t *	lw_trx;
  int		lw_mode;
} lock_wait_t;


/* use the below macro to portably set the lt_error_detail member of the LT */
#define LT_ERROR_DETAIL_SET(lt, det) \
  do \
    { \
      if ((lt)->lt_error_detail) \
	dk_free_box ((lt)->lt_error_detail); \
      (lt)->lt_error_detail = det; \
    } \
  while (0)

/* use the below macro to portably get the lt_error_detail member of the LT */
#define LT_ERROR_DETAIL(lt) \
    (lt)->lt_error_detail

#define LT_HAS_DELTA(lt) ((lt)->lt_rb_hash->ht_count)


#define TRX_NO(lt) lt->lt_trx_no
#define LT_W_NO(lt) QFID_HOST (lt->lt_w_id), (uint32)lt->lt_w_id

#define ITC_IS_LTRX(itc) \
  (itc->itc_ltrx)


#if defined (PAGE_TRACE) | defined (MTX_DEBUG)
#define ITC_FIND_PL(itc, buf) \
  if (ITC_IS_LTRX (itc)) \
    { \
      ITC_IN_KNOWN_MAP (itc, itc->itc_page);						\
      itc->itc_pl = (page_lock_t*) gethash (DP_ADDR2VOID (itc->itc_page), &IT_DP_MAP (itc->itc_tree, itc->itc_page)->itm_locks); \
      if ((buf)->bd_pl != itc->itc_pl) GPF_T1 ("bd_pl and itc_pl not in sync"); \
    }
#else
#define ITC_FIND_PL(itc, buf) \
  if (ITC_IS_LTRX (itc)) \
    itc->itc_pl = (buf)->bd_pl;
#endif


#define IT_DP_PL(it, dp) \
  ((page_lock_t *) gethash (DP_ADDR2VOID (dp), &IT_DP_MAP (it, dp)->itm_locks))

#define LT_NAME(lt) \
  (snprintf (lt->lt_name, sizeof (lt->lt_name), "%d:%u", QFID_HOST (lt->lt_w_id), (uint32)(0xffffffff & (lt)->lt_w_id) ), lt->lt_name)

#define LT_IS_TIMED_OUT(lt) \
  (lt->lt_started && approx_msec_real_time () - lt->lt_started > lt->lt_timeout)

#define LOCK \
    lock_trx_t *	pl_owner; \
    it_cursor_t *	pl_waiting; \
    char		pl_type; \
    char		pl_is_owner_list


typedef struct gen_lock_s
  {
    LOCK;
  } gen_lock_t;


/*#define CLK_DBG */

typedef struct col_lock_s
{
  LOCK;
  row_no_t	clk_pos;
  char		clk_change; /* row inserted/deleted/both by lock owner */
#ifdef CLK_DBG
  char		clk_rel_ctr;
  short		clk_init_inx;
  int64		clk_w_id;
#endif
  db_buf_t *	clk_rbe;
} col_row_lock_t;
/* clk_change */
#define CLK_INSERTED 1
#define CLK_DELETE_AT_COMMIT 2
#define CLK_DELETE_AT_ROLLBACK 4
#define CLK_REVERT_AT_ROLLBACK 8
#define CLK_FINALIZED 16
#define CLK_UC_UPDATE 32 /* set if the rb info of the clk holds an uncommitted update during checkpoint, after putting the pre-image back in the columns */

#define N_RLOCK_SETS 4


typedef struct row_lock_s
  {
    LOCK;
    short		rl_pos;
    row_no_t		rl_n_cols;
    struct row_lock_s *	rl_next;
    col_row_lock_t **	rl_cols; /* row locks for column projection segment for this row */
  } row_lock_t;


typedef struct page_lock_s
  {
    LOCK;
    short		pl_n_row_locks;
    short		pl_finish_ref_count;
    dp_addr_t		pl_page;
    index_tree_t *	pl_it;
    row_lock_t *	pl_rows[N_RLOCK_SETS];
  } page_lock_t;



/* lock type */
#define PL_FREE		0
#define PL_EXCLUSIVE	1
#define PL_SHARED	2
#define RL_FOLLOW	8
#define PL_PAGE_LOCK	16
#define PL_FINALIZE	32
#define PL_WHOLE_SEG 64 /* in row lock when the rl is escalated over all rows in the column proj seg */


#define PL_TYPE(pl) (pl->pl_type & 0x3)
#define RL_IS_FOLLOW(pl) (pl->pl_type & RL_FOLLOW)
#define PL_IS_PAGE(pl) (pl->pl_type & PL_PAGE_LOCK)
#define PL_IS_FINALIZE(pl) (pl->pl_type & PL_FINALIZE)
#define PL_IS_ESCALABLE(pl) (!(pl->pl_type & PL_NO_ESCALATION))

#define PL_SET_FLAG(pl, f) pl->pl_type |= f
#define PL_SET_TYPE(pl, f) pl->pl_type = (pl->pl_type & 0xfc) | f

/* put into pl_page after it is removed from the itm_locks.  Intermediate state, for a page lock, wait refs can be left hanging after the lock has no more owners and is thus free.
 * Relates to pl_finish_ref_count.  This is used to delay free of a pl until all the wait refs from already closing lt's are handled. */
#define PL_FINISHING ((dp_addr_t)-2)

#define ITC_PREFER_PAGE_LOCK(itc) \
  (!(itc)->itc_is_col && ((itc)->itc_n_lock_escalations > 2 || lock_escalation_pct < 0))




#define PL_RLS(pl, pos)  pl->pl_rows[(pos) & 0x3]


#define ITC_MAYBE_LOCK(itc, pos) \
  (itc->itc_pl \
   && (PL_RLS (itc->itc_pl, pos) || PL_IS_PAGE (itc->itc_pl)))


#define PL_RL_ADD(pl, rl, to) \
{ \
  if (PL_RLS (pl, to) == rl) GPF_T1 ("circular rl_next"); \
  rl->rl_next = PL_RLS (pl, to); PL_RLS(pl, to) = rl; }


#define DO_RLOCK(rl, pl) \
{ \
  int r_i; \
  for (r_i = 0; r_i < N_RLOCK_SETS; r_i++) \
    { \
      row_lock_t * rl, * _rl_next; \
      for (rl = pl->pl_rows[r_i]; rl; rl = _rl_next) \
	{ \
	  _rl_next = rl->rl_next;

#define END_DO_RLOCK \
	} \
    } \
}


#define PL_ANY_RLS(pl) \
  (pl->pl_rows[0] || pl->pl_rows[1] || pl->pl_rows[2] || pl->pl_rows[3])


#define PL_CAN_ESCALATE(itc, pl, buf) \
  (!itc->itc_is_col && (pl->pl_n_row_locks * 100) / (buf->bd_content_map->pm_count + 1) > lock_escalation_pct \
    && !PL_IS_PAGE (pl) \
    && !pl->pl_is_owner_list \
    && pl->pl_owner == itc->itc_lock_lt \
    && pl->pl_n_row_locks)



#define LT_CLEAR_ERROR_AFTER_RB(lt, max_thr) \
  { \
  ASSERT_IN_TXN; \
  if (lt->lt_threads <= max_thr && lt->lt_status == LT_DELTA_ROLLED_BACK) \
    lt_restart (lt, TRX_CONT);							\
}


int lock_wait (gen_lock_t * pl, it_cursor_t * it, buffer_desc_t * buf, int acquire);
int lock_add_owner (gen_lock_t * pl, it_cursor_t * it, int was_waiting);

/* return values for lock_wait */
#define WAIT_RESET	0
#define NO_WAIT		1
#define WAIT_OVER	2

void pl_release (page_lock_t * pl, lock_trx_t * lt, buffer_desc_t * buf);
void pl_page_deleted (page_lock_t * pl, buffer_desc_t * buf);
void lock_release (gen_lock_t * pl, lock_trx_t * lt);
page_lock_t * pl_allocate (void);
void pl_free (page_lock_t * pl);
row_lock_t * rl_allocate (void);
void rl_free (row_lock_t * rl);
row_lock_t * pl_row_lock_at (page_lock_t * pl, int pos);

extern resource_t * lock_rc;
extern resource_t * row_lock_rc;
extern resource_t * trx_rc;

void lt_done (lock_trx_t * lt);
lock_trx_t * lt_allocate (void);
void lt_free (lock_trx_t * lt);
void lt_clear (lock_trx_t * lt);
void lt_kill_other_trx (lock_trx_t * lt, it_cursor_t * itc, buffer_desc_t * buf, int May_freeze);
#define LT_KILL_FREEZE 0  /* will freeze the txn until cpt done if txn has no delta */
#define LT_KILL_ROLLBACK 1  /* Rollback always */

void lt_killall (lock_trx_t * lt, int lte);
int lock_enter (gen_lock_t * pl, it_cursor_t * it, buffer_desc_t * buf);
EXE_EXPORT (lock_trx_t *, lt_start, (void));
lock_trx_t * DBG_NAME(lt_start_inner) (DBG_PARAMS  int cpt_wait);
lock_trx_t * DBG_NAME(lt_start_outside_map) (DBG_PARAMS_0);
#ifdef MALLOC_DEBUG
extern lock_trx_t * DBG_NAME(lt_start) (DBG_PARAMS_0);
#define lt_start() dbg_lt_start (__FILE__, __LINE__)
#define lt_start_inner(cpt_wait) dbg_lt_start_inner (__FILE__, __LINE__, (cpt_wait))
#define lt_start_outside_map() dbg_lt_start_outside_map (__FILE__, __LINE__)
#endif
EXE_EXPORT (int, lt_commit, (lock_trx_t * lt, int free_trx));
EXE_EXPORT (int, lt_commit_cl_local_only, (lock_trx_t * lt));
EXE_EXPORT (void, lt_rollback, (lock_trx_t * lt, int free_trx));
void lt_rollback_1 (lock_trx_t * lt, int free_trx);
void lt_transact (lock_trx_t * lt, int op);
void lt_hi_transact (lock_trx_t * lt, int op);
void lt_resume_waiting_end (lock_trx_t * lt);
void log_cl_final(lock_trx_t* lt, int is_commit);
void lt_commit_schema_merge (lock_trx_t * lt);

extern dk_mutex_t * log_write_mtx;
void lt_wait_until_dead (lock_trx_t * lt);
void lt_ack_close (lock_trx_t * lt);
void lt_ack_freeze_inner (lock_trx_t * lt);
void lt_restart (lock_trx_t * lt, int leave_flag);
int itc_rollback_row (it_cursor_t * itc, buffer_desc_t ** buf_ret, int pos, row_lock_t * was_rl,
		  page_lock_t * pl, dk_set_t * rd_list);
void  rbe_page_row (rb_entry_t * rbe, row_delta_t * rd);


/* free_trx for lt_commit / lt_rollbak */
#define TRX_FREE 1
#define TRX_CONT 0
#define TRX_CONT_LT_LEAVE 2

void lt_clear_waits (lock_trx_t * lt);

void itc_bust_this_trx (it_cursor_t * it, buffer_desc_t ** buf, int may_return);
#define ITC_BUST_THROW 0
#define ITC_BUST_CONTINUABLE 1

void pl_rlock_table (page_lock_t * pl, row_lock_t ** locks, int *fill_ret);
void pg_move_lock (it_cursor_t * itc, row_lock_t ** locks, int n_locks, int from, int to,
	      page_lock_t * pl_to, int is_to_extend);
void itc_split_lock (it_cursor_t * itc, buffer_desc_t * left, buffer_desc_t * extend);
void itc_split_lock_waits (it_cursor_t * itc, buffer_desc_t * left, buffer_desc_t * extend);
row_lock_t * upd_refit_rlock (it_cursor_t * itc, int pos);
void lt_clear_pl_wait_ref (lock_trx_t * waiting, gen_lock_t * pl);
int itc_check_ins_deleted (it_cursor_t * itc, buffer_desc_t * buf, row_delta_t * rd, int may_replace);
void itc_insert_rl (it_cursor_t * itc, buffer_desc_t * buf, int pos, row_lock_t * rl, int do_not_escalate);
#define RL_NO_ESCALATE 1
#define RL_ESCALATE_OK 0


int itc_insert_lock (it_cursor_t * itc, buffer_desc_t * buf, int *res_ret, int may_wait);
int itc_landed_lock_check (it_cursor_t * itc, buffer_desc_t ** buf_ret);
lock_trx_t * lt_add_pl (lock_trx_t * lt, page_lock_t * pl, int flags);
#define LT_ADD_PL_NEW 1
#define LT_ADD_PL_IN_TXN 2
int pl_lt_is_owner (page_lock_t * pl, lock_trx_t * lt);
int itc_set_lock_on_row (it_cursor_t * itc, buffer_desc_t ** buf_ret);
int itc_serializable_land (it_cursor_t * itc, buffer_desc_t ** buf_ret);
int itc_read_committed_check (it_cursor_t * itc, buffer_desc_t * buf);
void pl_set_finalize (page_lock_t * pl, buffer_desc_t * buf);
void lt_blob_transact (it_cursor_t * itc, int op);

rb_entry_t * lt_rb_entry (lock_trx_t ** lt_ret, buffer_desc_t * buf, db_buf_t row, uint32 *code_ret, rb_entry_t ** prev_ret, int flags);
#define LT_RB_LEAVE_MTX 1
#define LT_RB_ONLY_OWN 2
#define LT_RB_BRANCH_AS_SELF 4

void lt_rb_insert (lock_trx_t * lt, buffer_desc_t * buf, db_buf_t key);
void lt_no_rb_insert (lock_trx_t * lt, db_buf_t row);
void lt_rb_update (lock_trx_t * lt, buffer_desc_t * buf, db_buf_t  row);
int pg_key_len (db_buf_t key1);
void lt_free_rb (lock_trx_t * lt, int is_rb);

void lt_close_snapshot (lock_trx_t * lt);
int lt_set_checkpoint (lock_trx_t * lt);



#define ITC_AGE_TRX(it, n) \
  if (it->itc_ltrx) \
    it->itc_ltrx->lt_age += n;

#define TRX_REMAP_SIZE		31
#define COMMIT_REMAP_SIZE	123


/*! Type of a callback to be executed by the_grim_lock_reaper() */
typedef void (* srv_background_task_t)(void *appdata);

int srv_add_background_task (srv_background_task_t task, void *appdata);
void the_grim_lock_reaper (void);

int lt_set_snapshot (lock_trx_t * lt);

#define LT_CHECK_RW(lt) \
  if (lt && lt->lt_mode == TM_SNAPSHOT) \
    { \
      sqlr_new_error ("42000", "SR107", "Read only transaction for modify operation."); \
    }


void lt_timestamp (lock_trx_t * lt, char * tv_ret);
caddr_t lt_timestamp_box (lock_trx_t * lt);
void itc_assert_lock (it_cursor_t * itc);




void lt_rb_new_entry (lock_trx_t * lt, uint32 rb_code, rb_entry_t * prev,
		 buffer_desc_t * buf, db_buf_t row, char op);
int32 rd_pos_key (row_delta_t * rd);

#define TRX_POISON(lt) \
{ \
  lt->lt_status = LT_BLOWN_OFF; \
  lt->lt_error = LTE_SQL_ERROR; \
}


#define it_title(it) \
  (!it ? " NULL IT " : ((it->it_key  && it->it_key->key_name) ? it->it_key->key_name : " unnamed key "))


#ifdef PAGE_TRACE

#define it_title(it) \
  (!it ? " NULL IT " : ((it->it_key  && it->it_key->key_name) ? it->it_key->key_name : " unnamed key "))

extern int page_trace_on;

#ifndef DBG_PT_PRINTF
# define DBG_PT_PRINTF(a) if (page_trace_on) { printf a; fflush (stdout); }
#endif

#define DBG_PT_READ(buf, lt) \
{ \
  DBG_PT_PRINTF (("READ L=%d P=%d FL=%d B=%p TX=%d SP=%s\n", \
      buf->bd_page, buf->bd_physical_page, SHORT_REF (buf->bd_buffer + DP_FLAGS), buf,lt ?  lt->lt_trx_no : -1, \
      it_title (buf->bd_tree))); \
  buf->bd_trx_no = lt? lt->lt_trx_no : -1; \
}

#define DBG_PT_WRITE(buf, overr) \
  DBG_PT_PRINTF (("WRITE L=%d P=%d B=%p TX=%d SP=%s PHYS=%d\n", \
      buf->bd_page, buf->bd_physical_page, buf, buf->bd_trx_no, \
      it_title (buf->bd_tree), overr))



#define DBG_PT_PRE_IMAGE(buf) \
  DBG_PT_PRINTF (("PREIMAGE L=%d P=%d B=%p\n", \
      buf->bd_page, buf->bd_physical_page, buf))

#define DBG_PT_COMMIT(lt) \
  DBG_PT_PRINTF (("COMMIT TX=%d\n", lt->lt_trx_no))

#define DBG_PT_COMMIT_END(lt) \
  /*DBG_PT_PRINTF (("COMMIT DONE TX=%d\n", lt->lt_trx_no)) */

#define DBG_PT_ROLLBACK(lt) \
  DBG_PT_PRINTF (("ROLLBACK START T=%d\n", lt->lt_trx_no))

#define DBG_PT_ROLLBACK_END(lt) \
  DBG_PT_PRINTF (("ROLLBACK DONE T=%d\n", lt->lt_trx_no))

#define DBG_PT_BUFFER_SCRAP(buf) \
  DBG_PT_PRINTF (("SCRAP L=%d P=%d B=%p TX=%d\n", \
      buf->bd_page, buf->bd_physical_page, buf, buf->bd_trx_no))

#define DBG_PT_NEW_PAGE(buf) \
{ \
  buf->bd_trx_no = buf->bd_space->isp_trx->trx_no; \
  DBG_PT_PRINTF (("NEW L=%d B=%p FL=%d TX=%d \n", \
	buf->bd_page, SHORT_REF (buf->bd_buffer + DP_FLAGS)buf, buf->bd_trx_no)) \
}

#define DBG_PT_NEW(lt, buf, new_dp) \
  DBG_PT_PRINTF (("L=%d P=%d NP=%d B=%x %TX=%d\n", \
      buf->bd_page, buf->bd_physical_page, new_dp, buf, buf->bd_trx_no))

#define DBG_PT_PRE_PAGE(dp) \
  DBG_PT_PRINTF (("PREV REMAP=%d ", dp))

#define DBG_PT_BUF_SCRAP(buf) \
  DBG_PT_PRINTF (("SCRAP L=%d P=%d B=%p TX=%d SP=%s\n", \
      buf->bd_page, buf->bd_physical_page, buf, buf->bd_trx_no, \
      it_title (buf->bd_tree)))

#endif



#ifndef DBG_PT_PRINTF
#define DBG_PT_PRINTF(a)
#endif

#ifndef DBG_PT_READ
#define DBG_PT_READ(buf, lt)
#endif

#ifndef DBG_PT_WRITE
#define DBG_PT_WRITE(buf, overr)
#endif

#ifndef DBG_PT_DELTA
#define DBG_PT_DELTA(buf, lt)
#endif

#ifndef DBG_PT_PRE_IMAGE
#define DBG_PT_PRE_IMAGE(buf)
#endif

#ifndef DBG_PT_COMMIT
#define DBG_PT_COMMIT(lt)
#endif

#ifndef DBG_PT_COMMIT_END
#define DBG_PT_COMMIT_END(lt)
#endif

#ifndef DBG_PT_ROLLBACK
#define DBG_PT_ROLLBACK(lt)
#endif

#ifndef DBG_PT_ROLLBACK_END
#define DBG_PT_ROLLBACK_END(lt)
#endif

#ifndef DBG_PT_BUFFER_SCRAP
#define DBG_PT_BUFFER_SCRAP(buf)
#endif

#ifndef DBG_PT_PRE_PAGE
#define DBG_PT_PRE_PAGE(dp)
#endif

#ifndef DBG_PT_DELTA_DIRTY
#define DBG_PT_DELTA_DIRTY(buf, old_dp)
#endif

#ifndef DBG_PT_BUF_SCRAP
#define DBG_PT_BUF_SCRAP(buf)
#endif

#ifndef DBG_PT_DELTA_CLEAN
#define DBG_PT_DELTA_CLEAN(buf, old_dp)
#endif


#define TC(f) f++


extern long  tc_try_land_write;
extern long  tc_try_land_reset;
extern  long tc_dp_changed_while_waiting_mtx;
extern long tc_dp_set_parent_being_read;
extern long tc_up_transit_parent_change;
extern long  tc_dive_split;
extern long  tc_dtrans_split;
extern long  tc_up_transit_wait;
extern long  tc_double_deletes;
extern long  tc_delete_parent_waits;
extern long  tc_wait_trx_self_kill;
extern long  tc_split_while_committing;
extern long  tc_rb_code_non_unique;
extern long  tc_set_by_pl_wait;
extern long  tc_split_2nd_read;
extern long  tc_read_wait;
extern long  tc_reentry_split;
extern long  tc_write_wait;
extern long tc_dive_would_deadlock;
extern long tc_cl_deadlocks;
extern long tc_cl_wait_queries;
extern long tc_cl_kill_1pc;
extern long tc_cl_kill_2pc;
extern long tc_get_buffer_while_stat;
extern long tc_autocompact_split;
extern long tc_bp_wait_flush;
extern long tc_page_fill_hash_overflow;
extern long tc_key_sample_reset;
extern long tc_pl_moved_in_reentry;
extern long tc_enter_transiting_bm_inx;
extern long tc_aio_seq_read;
extern long tc_aio_seq_write;
extern long tc_read_absent_while_finalize;
extern long tc_fix_outdated_leaf_ptr;
extern long tc_bm_split_left_separate_but_no_split;
extern long tc_unregister_enter;
extern long tc_root_write;
extern long tc_root_image_miss;
extern long tc_root_image_ref_deleted;
extern long tc_uncommit_cpt_page;
extern long tc_root_cache_miss;
extern long tc_aq_sleep;
extern long  tc_release_pl_on_deleted_dp;
extern long  tc_release_pl_on_absent_dp;
extern long  tc_cpt_lt_start_wait;
extern long  tc_cpt_rollback;
extern long  tc_wait_for_closing_lt;
extern long  tc_pl_non_owner_wait_ref_deld;
extern long  tc_pl_split;
extern long  tc_pl_split_multi_owner_page;
extern long  tc_pl_split_while_wait;
extern long  tc_insert_follow_wait;
extern long  tc_history_itc_delta_wait;
extern long  tc_page_wait_reset;
extern long  tc_posthumous_lock;
extern long  tc_finalize_while_being_read;
extern long  tc_rollback_cpt_page;
extern  long tc_kill_closing;
extern long  tc_dive_cache_hits;
extern long  tc_deadlock_win_get_lock;
extern long  tc_double_deadlock;
extern long  tc_update_wait_move;
extern long  tc_cpt_rollback_retry;
extern long  tc_repl_cycle;
extern long  tc_repl_connect_quick_reuse;

extern long  tc_no_thread_kill_idle;
extern long  tc_no_thread_kill_vdb;
extern long  tc_no_thread_kill_running;
extern long  tc_deld_row_rl_rb;

extern long  tc_blob_read;
extern long  tc_blob_write;
extern long  tc_blob_ra;
extern long  tc_blob_ra_size;
extern long  tc_get_buf_failed;
extern long  tc_read_wait_decoy;
extern long  tc_read_wait_while_ra_finding_buf;


extern int dive_cache_threshold; /* % consecutive for dive cache to be active */
extern int lock_escalation_pct;

extern resource_t * rb_page_rc;

#define STR_OR(s, n) ((s) ? (s) : (n))

#define dbg_pt_printf_2(a)
#if defined (PAGE_TRACE) || 0 /* off unless page trace */
#define rdbg_printf(a) printf a
#define rdbg_printf_2(a) printf a
#define rdbg_printf_if(c, a) if (c) printf a

#else
#define rdbg_printf(a)
#define rdbg_printf_2(a)
#define rdbg_printf_if(c, a)

#endif

#define LT_IS_RUNNING(lt) \
	(lt->lt_threads > 0 \
	  && !lt->lt_vdb_threads \
	  && !lt->lt_lw_threads \
	  && !lt->lt_close_ack_threads)


#define LW_CALL(it)  rdbg_printf (("    LW call it %p %s:%d\n", it, __FILE__, __LINE__));

lock_trx_t * itc_main_lt (it_cursor_t * itc, buffer_desc_t * buf);
lock_trx_t * lt_main_lt (lock_trx_t * lt);
int lt_has_delta (lock_trx_t * lt);
int lt_set_is_branch (dk_set_t list, lock_trx_t * lt, lock_trx_t ** main_lt_ret);
void log_merge_commit (lock_trx_t * lt, dk_set_t merges);
void lt_free_merge (dk_set_t merges);
int lt_log_merge (lock_trx_t * lt, int in_txn);
#define NO_LOCK_LT ((lock_trx_t*)-1L)

int ltbing (int s);
void ltbing2 ();
#endif /* _LTRX_H */

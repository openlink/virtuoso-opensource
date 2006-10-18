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

#ifndef _LTRX_H
#define _LTRX_H

#define LT_FREEZE 0
#define LT_PENDING		1
#define LT_COMMITTED		2
#define LT_BLOWN_OFF		3 /* Marked to be rolled back */
#define LT_CLOSING		4 /* locks being released, finalizing commit / rollback, inside lt_transact */
#define LT_DELTA_ROLLED_BACK	5 /* Only the trx object to be released */

#ifdef VIRTTP
#define LT_PREPARE_PENDING 	6
#define LT_PREPARED LT_COMMITTED
#define LT_FINAL_COMMIT_PENDING	7 /* when the commit came in, but there's a thread inside */
#endif

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
    short	rbe_row;
    short	rbe_row_len;
    char	rbe_op;
  } rb_entry_t;

#define RB_INSERT ((char) -1)
#define RB_UPDATE ((char) 0)
struct lock_trx_s;
#ifdef VIRTTP
struct tp_dtrx_s;
#endif
typedef void (*trx_hook_t) (struct lock_trx_s *);

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
    log_debug ("%s:%d : lt_threads %s to %d for lt %p on thread %p", \
	__FILE__, __LINE__, action, \
	lt->lt_threads, \
	lt, THREAD_CURRENT_THREAD)
#define lt_log_debug(x) log_debug x
#else
#define LT_ENTER_SAVE(lt)
#define LT_CLOSE_ACK_THREADS(lt)
#define LT_THREADS_REPORT(lt, action)
#define lt_log_debug(x)
#endif

typedef struct lock_trx_s
  {

    int			lt_status;
    int			lt_mode;  /* lock / snapshot  */
    int			lt_is_excl;
    int			lt_error;
    int			lt_isolation;
    int			lt_being_closed;
    dk_set_t		lt_locks;
    dk_set_t		lt_waits_for;
    dk_set_t		lt_waiting_for_this;
    long		lt_age;
    int			lt_threads;
#ifdef CHECK_LT_THREADS
    const char *	lt_enter_file;
    int	        	lt_enter_line;
    const char *	lt_last_increase_file[2];
    int			lt_last_increase_line[2];
#endif
    int			lt_lw_threads;
    int			lt_close_ack_threads;
    int			lt_vdb_threads;
    struct client_connection_s *	lt_client;
    long		lt_timeout;
    long		lt_started;

    dk_mutex_t *	lt_log_mtx;
    caddr_t *		lt_replicate;
    int                 lt_repl_is_raw;
    dk_session_t *	lt_log;
    int			lt_log_fd;
    caddr_t		lt_log_name;
    dk_set_t		lt_blob_log; /* pdl of blob start addresses to log. Zero if
				      * a blob in question is deleted later in the
				      * same trx */
    dk_hash_t *		lt_dirty_blobs;	/* Hashtable of blobs modified by transaction,
					 * which should be deleted at commit time
					 * and/or at rollback time */
    char		lt_timestamp[DT_LENGTH];
    dk_session_t *	lt_backup;  /* if running an online backup,
				     * the session to the backup device */
    unsigned long	lt_backup_length;

#if 0 /*GK: unused*/
    OFF_T		lt_blob_log_start; /* off_t for first logged blob in
					    * log file or 0 if no blobs */
#endif

    dk_set_t		lt_remotes;
    du_thread_t *	lt_thread_waiting_exclusive;


    dk_hash_t *		lt_rb_hash;
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
    } lt_2pc;
#endif

    dk_hash_t *	lt_upd_hi;  /* for each update node active in txn, the set of affected hi's */
    dk_set_t		lt_hi_delta;
#ifdef PAGE_TRACE
    long		lt_trx_no;
#endif
    caddr_t		lt_error_detail; /* if non-zero fill it with details about the error at hand */
#ifdef MSDTC_DEBUG
    bitf_t 		lt_in_mts:1;
#endif
  } lock_trx_t;

/* use the below macro to partably set the lt_error_detail member of the LT */
#define LT_ERROR_DETAIL_SET(lt, det) \
  do \
    { \
      if ((lt)->lt_error_detail) \
	dk_free_box ((lt)->lt_error_detail); \
      (lt)->lt_error_detail = det; \
    } \
  while (0)

/* use the below macro to partably get the lt_error_detail member of the LT */
#define LT_ERROR_DETAIL(lt) \
    (lt)->lt_error_detail

#define LT_HAS_DELTA(lt) ((lt)->lt_rb_hash->ht_count)


#ifdef PAGE_TRACE
#define TRX_NO(lt) lt->lt_trx_no
#else
#define TRX_NO(lt) 0
#endif


#define ITC_IS_LTRX(itc) \
  (!itc->itc_ltrx ||  !itc->itc_ltrx->lt_is_excl)


#if defined (PAGE_TRACE) | defined (MTX_DEBUG)
#define ITC_FIND_PL(itc, buf) \
  if (ITC_IS_LTRX (itc)) \
    { \
      ITC_IN_MAP (itc); \
      itc->itc_pl = (page_lock_t*) gethash (DP_ADDR2VOID (itc->itc_page), itc->itc_tree->it_locks); \
      if ((buf)->bd_pl != itc->itc_pl) GPF_T1 ("bd_pl and itc_pl not in sync"); \
    }
#else
#define ITC_FIND_PL(itc, buf) \
  if (ITC_IS_LTRX (itc)) \
    itc->itc_pl = (buf)->bd_pl;
#endif

#define IT_DP_PL(it, dp) \
  (page_lock_t *) gethash (DP_ADDR2VOID (dp), it->it_locks)

#define LT_NAME(lt) \
  (lt->lt_client->cli_session && !lt->lt_client->cli_ws ? \
      (lt->lt_client->cli_session->dks_peer_name ? \
       lt->lt_client->cli_session->dks_peer_name : "<NOT_CONN>") \
      : "INTERNAL")

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

#define N_RLOCK_SETS 4


typedef struct row_lock_s
  {
    LOCK;
    short		rl_pos;
    struct row_lock_s *	rl_next;

  } row_lock_t;


typedef struct page_lock_s
  {
    LOCK;
    short		pl_n_row_locks;
    dp_addr_t		pl_page;
    index_tree_t *	pl_it;
    row_lock_t *	pl_rows[N_RLOCK_SETS];
  } page_lock_t;



/* lock type */
#define PL_FREE		0
#define PL_EXCLUSIVE	1
#define PL_SHARED	2
#define PL_SNAPSHOT	3  /* Only appears in itc_lock_mode when the trx is
			      it TM_SNAPSHOT mode and no locks are used. */
#define RL_FOLLOW	8
#define PL_PAGE_LOCK	16
#define PL_FINALIZE	32



#define PL_TYPE(pl) (pl->pl_type & 0x3)
#define RL_IS_FOLLOW(pl) (pl->pl_type & RL_FOLLOW)
#define PL_IS_PAGE(pl) (pl->pl_type & PL_PAGE_LOCK)
#define PL_IS_FINALIZE(pl) (pl->pl_type & PL_FINALIZE)
#define PL_IS_ESCALABLE(pl) (!(pl->pl_type & PL_NO_ESCALATION))

#define PL_SET_FLAG(pl, f) pl->pl_type |= f
#define PL_SET_TYPE(pl, f) pl->pl_type = (pl->pl_type & 0xfc) | f

#define ITC_PREFER_PAGE_LOCK(itc) \
  ((itc)->itc_n_lock_escalations > 2 || lock_escalation_pct < 0)




#define PL_RLS(pl, pos)  pl->pl_rows[((pos >> 2) + (pos >> 10)) & 0x3]


#define ITC_MAYBE_LOCK(itc, pos) \
  (it->itc_pl \
   && (PL_RLS (it->itc_pl, pos) || PL_IS_PAGE (it->itc_pl)))


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
  ((pl->pl_n_row_locks * 100) / (buf->bd_content_map->pm_count + 1) > lock_escalation_pct \
    && !PL_IS_PAGE (pl) \
    && !pl->pl_is_owner_list \
    && pl->pl_owner == itc->itc_ltrx \
    && pl->pl_n_row_locks)



#define LT_CLEAR_ERROR_AFTER_RB(lt, max_thr) \
  ASSERT_IN_TXN; \
  if (lt->lt_threads <= max_thr && lt->lt_status == LT_DELTA_ROLLED_BACK) \
    lt_restart (lt); \



int lock_wait (gen_lock_t * pl, it_cursor_t * it, buffer_desc_t * buf, int acquire);
int lock_add_owner (gen_lock_t * pl, it_cursor_t * it, int was_waiting);

/* return values for lock_wait */
#define WAIT_RESET	0
#define NO_WAIT		1
#define WAIT_OVER	2

void pl_release (page_lock_t * pl, lock_trx_t * lt, buffer_desc_t * buf);
void pl_page_deleted (page_lock_t * pl, buffer_desc_t * buf);
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

void lt_killall (lock_trx_t * lt);
int lock_enter (gen_lock_t * pl, it_cursor_t * it, buffer_desc_t * buf);
EXE_EXPORT (lock_trx_t *, lt_start, (void));
lock_trx_t * lt_start_outside_map (void);
int lt_commit (lock_trx_t * lt, int free_trx);
void lt_rollback (lock_trx_t * lt, int free_trx);
void lt_transact (lock_trx_t * lt, int op);
void lt_hi_transact (lock_trx_t * lt, int op);
void lt_resume_waiting_end (lock_trx_t * lt);
void lt_wait_until_dead (lock_trx_t * lt);
void lt_ack_close (lock_trx_t * lt);
void lt_ack_freeze_inner (lock_trx_t * lt);
void lt_restart (lock_trx_t * lt);



/* free_trx for lt_commit / lt_rollbak */
#define TRX_FREE 1
#define TRX_CONT 0

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
int itc_check_ins_deleted (it_cursor_t * itc, buffer_desc_t * buf, db_buf_t dv);
void itc_insert_rl (it_cursor_t * itc, buffer_desc_t * buf, int pos, row_lock_t * rl, int do_not_escalate);
#define RL_NO_ESCALATE 1
#define RL_ESCALATE_OK 0


int itc_insert_lock (it_cursor_t * itc, buffer_desc_t * buf, int *res_ret);
int itc_landed_lock_check (it_cursor_t * itc, buffer_desc_t ** buf_ret);
void lt_add_pl (lock_trx_t * lt, page_lock_t * pl, int is_new_pl);
int pl_lt_is_owner (page_lock_t * pl, lock_trx_t * lt);
int itc_set_lock_on_row (it_cursor_t * itc, buffer_desc_t ** buf_ret);
int itc_serializable_land (it_cursor_t * itc, buffer_desc_t ** buf_ret);
void pl_set_finalize (page_lock_t * pl, buffer_desc_t * buf);
void lt_blob_transact (it_cursor_t * itc, int op);

rb_entry_t * lt_rb_entry (lock_trx_t * lt, db_buf_t row, long *code_ret, rb_entry_t ** prev_ret);

void lt_rb_insert (lock_trx_t * lt, db_buf_t key);
void lt_rb_update (lock_trx_t * lt, db_buf_t  row);
int pg_key_len (db_buf_t key1);
void lt_free_rb (lock_trx_t * lt);

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

#if UNIVERSE
int lt_remote_transact (lock_trx_t * lt, int is_commit);
#endif



void lt_free_rb (lock_trx_t * lt);


#define TRX_POISON(lt) \
{ \
  lt->lt_status = LT_BLOWN_OFF; \
  lt->lt_error = LTE_SQL_ERROR; \
}


#ifdef PAGE_TRACE

extern int page_trace_on;

#ifndef DBG_PT_PRINTF
# define DBG_PT_PRINTF(a) if (page_trace_on) { printf a; fflush (stdout); }
#endif

#define DBG_PT_READ(buf, lt) \
{ \
  DBG_PT_PRINTF (("READ L=%d P=%d FL=%d B=%p TX=%d SP=%s\n", \
      buf->bd_page, buf->bd_physical_page, SHORT_REF (buf->bd_buffer + DP_FLAGS), buf,lt ?  lt->lt_trx_no : -1, \
      isp_title (buf->bd_space))); \
  buf->bd_trx_no = lt? lt->lt_trx_no : -1; \
}

#define DBG_PT_WRITE(buf, overr) \
  DBG_PT_PRINTF (("WRITE L=%d P=%d B=%x TX=%d SP=%s PHYS=%d\n", \
      buf->bd_page, buf->bd_physical_page, buf, buf->bd_trx_no, \
      isp_title (buf->bd_space), overr))



#define DBG_PT_PRE_IMAGE(buf) \
  DBG_PT_PRINTF (("PREIMAGE L=%d P=%d B=%x\n", \
      buf->bd_page, buf->bd_physical_page, buf))

#define DBG_PT_COMMIT(lt) \
  DBG_PT_PRINTF (("COMMIT TX=%d\n", lt->lt_trx_no))

#define DBG_PT_COMMIT_END(lt) \
  DBG_PT_PRINTF (("COMMIT DONE TX=%d\n", lt->lt_trx_no))

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
  DBG_PT_PRINTF (("NEW L=%d B=%x FL=%d TX=%d \n", \
	buf->bd_page, SHORT_REF (buf->bd_buffer + DP_FLAGS)buf, buf->bd_trx_no)) \
}

#define DBG_PT_NEW(lt, buf, new_dp) \
  DBG_PT_PRINTF (("L=%d P=%d NP=%d B=%x %TX=%d\n", \
      buf->bd_page, buf->bd_physical_page, new_dp, buf, buf->bd_trx_no))

#define DBG_PT_PRE_PAGE(dp) \
  DBG_PT_PRINTF (("PREV REMAP=%d ", dp))

#define DBG_PT_BUF_SCRAP(buf) \
  DBG_PT_PRINTF (("SCRAP L=%d P=%d B=%x TX=%d SP=%s\n", \
      buf->bd_page, buf->bd_physical_page, buf, buf->bd_trx_no, \
      isp_title (buf->bd_space)))

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


#define rdbg_printf_2(a)
#define dbg_pt_printf_2(a)
#if defined (PAGE_TRACE) || 0 /* off unless page trace */
#define rdbg_printf(a) printf a
#else
#define rdbg_printf(a)
#endif


#define LW_CALL(it)  rdbg_printf (("    LW call it %x %s:%d\n", it, __FILE__, __LINE__));

#endif /* _LTRX_H */

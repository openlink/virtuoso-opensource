/*
 *  lock.c
 *
 *  $Id$
 *
 *  Locking concurrency control
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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

#if defined (__APPLE__)
#define  _lock_set_user_ 1
#endif

#include "sqlnode.h"
#include "sqlfn.h"
#include "repl.h"
#include "replsr.h"
#include "datesupp.h"
#include "statuslog.h"
#include "security.h"
#include "srvstat.h"
#ifdef DEBUG
#include "shuric.h"
#endif

resource_t *lock_rc;
resource_t *row_lock_rc;
resource_t *trx_rc;
resource_t *large_isps;

long lock_killed_by_force = 0;
long lock_deadlocks = 0;
long lock_2r1w_deadlocks;
long lock_waits = 0;
long lock_enters = 0;
long lock_leaves = 0;

dk_set_t all_trxs = NULL;

uint32 lt_counter = 0; /* 32 bits exact, lower half of trx no 64 bit id, must wrap around */
uint32 lt_w_counter = 0; /* 32 bits exact, lower half lt_w_id no 64 bit id, must wrap around */
void
lt_new_w_id (lock_trx_t * lt)
{
}


#ifdef VIRTTP
#include "2pc.h"
#endif

void
log_debug_dummy (char * str, ...)
{}

void lt_waits_for (lock_trx_t * before, lock_trx_t * after);
void dt_init ();
void remove_old_xmlview ();

page_lock_t *
pl_allocate (void)
{
  NEW_VARZ (page_lock_t, pl);
  return pl;
}


void
pl_free (page_lock_t * pl)
{
  dk_free ((caddr_t) pl, sizeof (page_lock_t));
}

row_lock_t *
rl_allocate (void)
{
  NEW_VARZ (row_lock_t, rl);
  return rl;
}


void
rl_free (row_lock_t * rl)
{
  dk_free ((caddr_t) rl, sizeof (row_lock_t));
}

void
lt_new_trx_no (lock_trx_t * lt)
{
  if (lt_counter <= LT_LAST_RESERVED_NO)
    lt_counter = LT_LAST_RESERVED_NO + 1;
  lt->lt_trx_no = ((int64)local_cll.cll_this_host) << 32 | lt_counter++;
}


lock_trx_t *
lt_allocate (void)
{
  NEW_VARZ (lock_trx_t, lt);

  lt->lt_log = strses_allocate ();
  lt->lt_log_mtx = mutex_allocate ();
  dk_mutex_init (&lt->lt_locks_mtx, MUTEX_TYPE_SHORT);
  mutex_option (&lt->lt_locks_mtx, "lt_locks", NULL, NULL);
  dk_mutex_init (&lt->lt_rb_mtx, MUTEX_TYPE_SHORT);
  mutex_option (&lt->lt_rb_mtx, "lt_rb", NULL, NULL);
  hash_table_init (&lt->lt_lock, 59);
#ifdef MTX_DEBUG
  lt->lt_lock.ht_required_mtx = &lt->lt_locks_mtx;
#endif
  lt->lt_rb_hash = hash_table_allocate (101);
  ASSERT_IN_TXN;
  dk_set_push (&all_trxs, (void *) lt);
  lt_new_trx_no (lt);
  lt_new_w_id (lt);
  LT_ENTER_SAVE (lt);

  return lt;
}


long tc_lt_free;

void
lt_free (lock_trx_t * lt)
{
  ASSERT_IN_TXN;
  TC (tc_lt_free);
#ifdef MSDTC_DEBUG
  if (lt->lt_in_mts)
    GPF_T1 ("Freeing txn that's in MTS");
#endif
  LT_THREADS_REPORT (lt, "LT_FREE");
  lt_free_rb (lt, 0);
  dk_set_free (lt->lt_waits_for);
  dk_set_free (lt->lt_waiting_for_this);
  dk_free_tree ((caddr_t) lt->lt_replicate);
  strses_free (lt->lt_log);
  blob_log_set_free (lt->lt_blob_log);
  dk_set_delete (&all_trxs, (void *) lt);
  mutex_free (lt->lt_log_mtx);
  dk_mutex_destroy (&lt->lt_locks_mtx);
  dk_mutex_destroy (&lt->lt_rb_mtx);
#ifdef MTX_DEBUG
  lt->lt_lock.ht_required_mtx = NULL;
#endif
  hash_table_destroy (&lt->lt_lock);
  hash_table_free (lt->lt_rb_hash);
#ifdef VIRTTP
  dk_free_tree (lt->lt_2pc._2pc_xid);
  dk_free_tree (lt->lt_2pc._2pc_log);
#endif
  dk_free ((caddr_t) lt, sizeof (lock_trx_t));
}


void
lt_clear (lock_trx_t * lt)
{
#ifdef PAGE_TRACE
  long no = TRX_NO (lt);
#endif

#ifdef MSDTC_DEBUG
  if (lt->lt_in_mts)
    GPF_T1 ("Clearing txn that's in MTS");
#endif
  if (lt->lt_client && lt->lt_client->cli_row_autocommit)
    lt->lt_client->cli_n_to_autocommit = 0;
  if (lt->lt_lock.ht_count)
    GPF_T1 ("lt not supposed to have locks in lt_clear");
  strses_flush (lt->lt_log);
  lt->lt_log->dks_bytes_sent = 0;
  clrhash (lt->lt_rb_hash);
#ifdef MTX_DEBUG
  lt->lt_lock.ht_required_mtx = NULL;
#endif
  if (lt->lt_lock.ht_actual_size > 80)
    {
      hash_table_destroy (&lt->lt_lock);
      hash_table_init (&lt->lt_lock, 59);
    }
  else if (lt->lt_lock.ht_count)
    clrhash (&lt->lt_lock);
#ifdef MTX_DEBUG
  lt->lt_lock.ht_required_mtx = &lt->lt_locks_mtx;
#endif
  if (lt->lt_waits_for || lt->lt_waiting_for_this)
    GPF_T1 ("Waits not cleared before trx clear");

  dk_free_tree ((caddr_t) lt->lt_replicate);
  blob_log_set_free (lt->lt_blob_log);
  lt->lt_error = 0;
  LT_ERROR_DETAIL_SET (lt, NULL);
  if (lt->lt_wait_end)
    GPF_T1 ("lt going clear but somebody still waiting for its end");
#ifdef VIRTTP
  dk_free_tree (lt->lt_2pc._2pc_xid);
  dk_free_tree (lt->lt_2pc._2pc_log);
#endif
  memset (&lt->LT_DATA_AREA_FIRST, 0, sizeof (lock_trx_t) - (size_t) &((lock_trx_t*) 0)->LT_DATA_AREA_FIRST);
  LT_ENTER_SAVE (lt);
  LT_THREADS_REPORT (lt, "LT_CLEAR");
}


void
lt_clear_waits (lock_trx_t * lt)
{
  ASSERT_IN_TXN;
  DO_SET (lock_trx_t *, waiting, &lt->lt_waiting_for_this)
  {
    if (!dk_set_delete (&waiting->lt_waits_for, lt))
      GPF_T1 ("unmatched waits/waits_for:this");
  }
  END_DO_SET ();
  DO_SET (lock_trx_t *, pred, &lt->lt_waits_for)
  {
    if (!dk_set_delete (&pred->lt_waiting_for_this, lt))
      GPF_T1 ("unmatched waits / waits_for_this");
    DO_SET (lock_trx_t *, succ, &lt->lt_waiting_for_this)
    {
      lt_waits_for (pred, succ);
      /* each that used to wait for the deceased now
         waits for its predecessors */
    }
    END_DO_SET ();
  }
  END_DO_SET ();

  dk_set_free (lt->lt_waits_for);
  dk_set_free (lt->lt_waiting_for_this);
  lt->lt_waits_for = NULL;
  lt->lt_waiting_for_this = NULL;
}


void
lt_clear_wait_if_only  (lock_trx_t * before, lock_trx_t * after)
{
  return;
#if 0
  if (1 == after->lt_lw_threads && 1 == after->lt_threads)
    {
      if (!dk_set_delete (&after->lt_waits_for, (void*) before))
	GPF_T1 ("unmatched lt_waits_for, waiting_for_THIS");
      if (!dk_set_delete (&before->lt_waiting_for_this, (void*) after))
	GPF_T1 ("unmatched lt_waits_for, waiting_for_THIS");
    }
#endif
}


void
lt_waits_for (lock_trx_t * before, lock_trx_t * after)
{
  if (!dk_set_member (before->lt_waiting_for_this, (void *) after))
    {
      dk_set_push (&before->lt_waiting_for_this, (void *) after);
      dk_set_push (&after->lt_waits_for, (void *) before);
    }
  ASSERT_IN_TXN;
}


int
lt_is_deadlock_1 (lock_trx_t * before, lock_trx_t * after, int *n_deadlocks,
    lock_trx_t ** deadlocked, int depth)
{
  if (before == after)
    {
      (*n_deadlocks) += depth + 1;
      *deadlocked = NULL;
      return 1;
    }
#ifdef DEBUG
  /* dk_set_check_straight (before -> lt_waits_for); */
#endif
  DO_SET (lock_trx_t *, pred, &before->lt_waits_for)
  {
    if (after == pred)
      {
	if (*deadlocked != before)
	  {
	    (*n_deadlocks) += depth + 1;
	    *deadlocked = before;
	  }
	else
	  TC (tc_double_deadlock);
	if (before->lt_status != LT_PENDING)
	  TC (tc_double_deadlock);
	return 1;
      }
    lt_is_deadlock_1 (pred, after, n_deadlocks, deadlocked, depth + 1);
  }
  END_DO_SET ();
  return (*n_deadlocks);
}


int
lt_is_deadlock (lock_trx_t * before, lock_trx_t * after, int *n_deadlocks,
    lock_trx_t ** deadlocked)
{
  int rc;
  ASSERT_IN_TXN;
  if (!(rc = lt_is_deadlock_1 (before, after, n_deadlocks, deadlocked, 0)))
    lt_waits_for (before, after);
  return rc;
}


lock_trx_t *
lt_start_outside_map ()
{
  lock_trx_t *lt;
  IN_TXN;
  lt = lt_start ();
  LEAVE_TXN;
  return lt;
}


lock_trx_t *
lt_start ()
{
  lock_trx_t *lt = (lock_trx_t *) resource_get (trx_rc);
  ASSERT_IN_TXN;
  LT_THREADS_REPORT(lt, "LT_START");
  lt_wait_checkpoint ();
  lt->lt_status = LT_PENDING;
  CHECK_DK_MEM_RESERVE (lt);
  lt->lt_started = 0;
  lt->lt_is_cl_server = 0;
  lt_new_trx_no (lt);
  DBG_PT_PRINTF (("Allocated T=%ld \n", lt->lt_trx_no));
  if (LT_ID_FREE == lt->lt_w_id || !lt->lt_w_id)
    lt_new_w_id (lt);
#ifdef VIRTTP
  lt->lt_2pc._2pc_logged = 0;
  lt->lt_2pc._2pc_info = 0;
  lt->lt_2pc._2pc_type = 0;
#endif
  return lt;
}


void
lt_restart (lock_trx_t * lt, int leave_flag)
{
  lt_threads_set_inner (lt, 0);
  if (TRX_CONT == leave_flag)
    {
      lt_wait_checkpoint_lt (lt);
      lt_threads_set_inner (lt, 1);
    }
  lt->lt_w_id = 0;
  LEAVE_TXN;
  {
    int excl = lt->lt_is_excl;
    client_connection_t * cli = lt->lt_client;
#ifdef CHECK_LT_THREADS
    const char *file_save = lt->lt_enter_file;
    int line_save = lt->lt_enter_line;
    const char *	lt_last_increase_file[2];
    int		lt_last_increase_line[2];
#endif
    caddr_t repl = (excl || cli->cli_row_autocommit) ? box_copy_tree ((box_t) lt->lt_replicate) : NULL;
    /* we we'll save the state of replication flag
       when  we're in atomic mode */
#ifdef VIRTTP
    caddr_t validness = lt->lt_2pc._2pc_prepared;
#endif

#ifdef CHECK_LT_THREADS
    memcpy (lt_last_increase_file, lt->lt_last_increase_file, sizeof (lt->lt_last_increase_file));
    memcpy (lt_last_increase_line, lt->lt_last_increase_line, sizeof (lt->lt_last_increase_line));
#endif
    lt_clear (lt);

    lt->lt_started = approx_msec_real_time ();
    if (excl || cli->cli_row_autocommit) /* therefore we'll set the saved one */
      lt->lt_replicate = (caddr_t*) repl;
    else
      lt->lt_replicate = (caddr_t*) box_copy_tree ((caddr_t) cli->cli_replicate);

    LT_THREADS_REPORT(lt, "LT_RESTART");
#ifdef CHECK_LT_THREADS
    lt->lt_enter_file = file_save;
    lt->lt_enter_line = line_save;
    memcpy (lt->lt_last_increase_file, lt_last_increase_file, sizeof (lt->lt_last_increase_file));
    memcpy (lt->lt_last_increase_line, lt_last_increase_line, sizeof (lt->lt_last_increase_line));
#endif
#ifdef VIRTTP
    lt->lt_2pc._2pc_logged = 0;
    lt->lt_2pc._2pc_info = 0;
    lt->lt_2pc._2pc_type = 0;
    lt->lt_2pc._2pc_prepared = validness;
#endif
    if (DO_LOG(LOG_TRANSACT))
      {
	LOG_GET;
	log_info ("LTRS_2 %s %s %s Restart transact %p", user, from, peer, lt);
      }
  }
  IN_TXN;
  lt_wait_checkpoint_lt (lt);
  if (TRX_CONT == leave_flag || TRX_CONT_LT_LEAVE == leave_flag)
    {
      lt->lt_status = LT_PENDING;
      lt->lt_error = LTE_OK;
    }
  lt_new_w_id (lt);
  if (TRX_CONT != leave_flag)
    LEAVE_TXN;
  DBG_PT_PRINTF (("Reallocated T=%ld \n", lt->lt_trx_no));
}


int
lt_set_checkpoint (lock_trx_t * lt)
{
  return 1;
}


void
lt_close_snapshot (lock_trx_t * lt)
{
}


void
lt_commit_schema_merge (lock_trx_t * lt)
{
  dbe_schema_t * old = wi_inst.wi_schema;
  wi_inst.wi_schema = lt->lt_pending_schema;
  dbe_schema_dead (old);
  lt->lt_pending_schema = NULL;
}


void
lt_done (lock_trx_t * lt)
{
  ASSERT_IN_TXN;
  if (lt->lt_waits_for || lt->lt_waiting_for_this || lt->lt_lock.ht_count)
    GPF_T1 ("lt done called with waiting, waits for or locks in lt");
  if (wi_inst.wi_checkpoint_atomic) lt_weird ();
#if defined (VALGRIND) || defined (MALLOC_DEBUG)
  lt_free (lt);
#else
  lt->lt_threads = 0;
#ifdef MTX_DEBUG
  {
    int64 plt = 0;
    int inx;
    if (local_cll.cll_id_to_trx)
      gethash_64 (plt, lt->lt_trx_no, local_cll.cll_id_to_trx);
    if (plt)
      GPF_T1 ("lt in id to trx  at lt_done");
    for (inx = 0; inx < trx_rc->rc_fill; inx++)
      if (trx_rc->rc_items[inx] == (void*)lt) GPF_T1 ("double lt_done");
  }
#endif
  lt->lt_trx_no = lt->lt_w_id = LT_ID_FREE;
  resource_store (trx_rc, (void *) lt);
#endif
}

dk_mutex_t * log_write_mtx;


void lt_rollback_1 (lock_trx_t * lt, int free_trx);

int
lt_commit (lock_trx_t * lt, int free_trx)
{
  ASSERT_IN_TXN;
  CHECK_DK_MEM_RESERVE (lt);
  if (lt->lt_status == LT_BLOWN_OFF
      || lt->lt_status == LT_DELTA_ROLLED_BACK)
    {
      int err = lt->lt_error;
      lt_rollback_1 (lt, free_trx);
      return err;
    }
  lt->lt_status = LT_COMMITTED;
#ifdef VIRTTP
  if (lt->lt_2pc._2pc_info)
    if (LTE_OK != lt->lt_2pc._2pc_info->vtbl->commit_1 (lt, 1))
      {
	lt_rollback_1 (lt, free_trx);
	return LTE_2PC_ERROR;
      }
#endif

  LEAVE_TXN;
  mutex_enter (log_write_mtx);
  if (LTE_OK != log_commit (lt))
    {
      mutex_leave (log_write_mtx);
      IN_TXN;
      lt_rollback_1 (lt, free_trx);
      LT_ERROR_DETAIL_SET (lt, box_dv_short_string (
	    "Problem writing to the transaction log"));
      return LTE_LOG_FAILED;
    }
  mutex_leave (log_write_mtx);
  IN_TXN;
  DBG_PT_COMMIT (lt);
      ASSERT_IN_TXN;
      LT_CLOSE_ACK_THREADS(lt);
      lt->lt_close_ack_threads++;
      lt_transact (lt, SQL_COMMIT);
  if (lt->lt_pending_schema)
    {
      lt_commit_schema_merge (lt);
    }
  if (lt->lt_commit_hook)
    {
      lt->lt_commit_hook (lt);
    }
  DBG_PT_COMMIT_END (lt);
  if (TRX_FREE == free_trx)
    {
#ifdef CHECK_LT_THREADS
      if (lt->lt_wait_end)
	GPF_T1 ("resource store with threads");
#endif
      LT_THREADS_REPORT(lt, "LT_COMMIT/RESOURCE_STORE");
      lt_done (lt);
    }
  else
    {
      lt_restart (lt, free_trx);
    }
  return LTE_OK;
}


int
lt_commit_cl_local_only (lock_trx_t * lt)
{
  /* even if remote branches exist, commit only locally, the branches will do the same */
  int rc;
  cl_host_t * branch_of = lt->lt_branch_of;
  dk_set_t branches = lt->lt_cl_branches;
  rc = lt_commit (lt, TRX_CONT);
  lt->lt_cl_branches = branches;
  lt->lt_branch_of = branch_of;
  return rc;
}


void
lt_rollback (lock_trx_t * lt, int free_trx)
{
  if (lt->lt_is_excl)
    lt_commit (lt, free_trx);
  else
    lt_rollback_1 (lt, free_trx);
}

/* Top level API */
void
lt_rollback_1 (lock_trx_t * lt, int free_trx)
{
  ASSERT_IN_TXN;
/* icc lock that is waiting for commit should be rolled back if the rollback happens first. */
#ifdef VIRTTP
  if (0 != lt->lt_client)
#endif /* VIRTTP */
  if (lt->lt_client->cli_icc_lock)
    {
      icc_lock_t *cli_lock = lt->lt_client->cli_icc_lock;
      if (cli_lock->iccl_waits_for_commit)
	{
	  cli_lock->iccl_waits_for_commit = 0;
	  lt->lt_client->cli_icc_lock = NULL;
	  if (NULL != cli_lock->iccl_qi)
	    cli_lock->iccl_qi->qi_icc_lock = NULL;
	  icc_lock_free (cli_lock);
	}
    }
#ifdef VIRTTP
  if (LT_PREPARE_PENDING == lt->lt_status)
    {
      if (LTE_OK == lt_2pc_prepare(lt))
      {
	lt->lt_status = LT_PREPARED;
      } else
	lt->lt_status = LT_BLOWN_OFF;
      ASSERT_IN_TXN;
      lt->lt_lw_threads = 0;
      lt_resume_waiting_end (lt);
      return;
    }
  if (lt->lt_2pc._2pc_logged)
    log_final_transact(lt,0);
#endif

  lt->lt_status = LT_BLOWN_OFF;
  LEAVE_TXN;
  log_cl_final (lt, SQL_ROLLBACK);
  IN_TXN;
  DBG_PT_ROLLBACK (lt);
  if (lt->lt_status != LT_DELTA_ROLLED_BACK)
    {
      ASSERT_IN_TXN;
      lt->lt_status = LT_BLOWN_OFF;
      LT_CLOSE_ACK_THREADS(lt);
      lt->lt_close_ack_threads++;
      lt_transact (lt, SQL_ROLLBACK);
    }
  if (lt_has_locks (lt))
    {
      GPF_T1 ("posthumous lock");
      rdbg_printf (("*** Posthumous locks on T=%ld \n", TRX_NO (lt)));
      TC (tc_posthumous_lock);
      lt->lt_status = LT_BLOWN_OFF;
      lt_transact (lt, SQL_ROLLBACK);
    }
  if (lt->lt_pending_schema)
    {
      dbe_schema_dead (lt->lt_pending_schema);
      lt->lt_pending_schema = NULL;
    }
  if (lt->lt_rollback_hook)
    {
      lt->lt_rollback_hook (lt);
    }
  DBG_PT_ROLLBACK_END (lt);
  if (TRX_FREE == free_trx)
    {
#ifdef CHECK_LT_THREADS
      if (lt->lt_wait_end)
	GPF_T1 ("resource store with threads");
#endif
      LT_THREADS_REPORT(lt, "LT_ROLLBACK_1/RESOURCE_STORE");
      lt_done (lt);
    }
  else
    {
      lt_restart (lt, free_trx);
    }
}


void
lt_ack_freeze_inner (lock_trx_t * lt)
{
  du_thread_t *self = THREAD_CURRENT_THREAD;
  ASSERT_IN_TXN;
  /* Can be called from lt_leave, no itc and bufs but must ack for cpt to proceed */
  lt->lt_status = LT_FREEZE;
  lt->lt_error = LTE_OK;
  LT_CLOSE_ACK_THREADS (lt);
  lt->lt_close_ack_threads = 1;
  lt_resume_waiting_end (lt);
  self->thr_lt = lt;
  lt_wait_checkpoint ();
  self->thr_lt = NULL;
  if (LT_FREEZE == lt->lt_status)
    {
      LT_CLOSE_ACK_THREADS (lt);
      lt->lt_close_ack_threads = 0;
      lt->lt_status = LT_PENDING;
    }
}



void
lt_ack_freeze (lock_trx_t * lt, it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  int landed = 0;
  if (buf_ret && *buf_ret)
    {
      ITC_IN_KNOWN_MAP (itc, (*buf_ret)->bd_page);
      if (!itc->itc_landed)
	{
	  if (itc->itc_is_registered)
	    GPF_T1 ("itc can't be registered in ack freeze");
	  page_leave_inner (*buf_ret);
	}
      else
	{
	  itc_register (itc, *buf_ret);
	  page_leave_inner (*buf_ret);
	  landed = 1;
	}
    }
  if (itc)
    ITC_LEAVE_MAPS (itc); /* can have itc but no buf, as in page_reenter_excl */
  IN_TXN;
  lt_ack_freeze_inner (lt);
  LEAVE_TXN;
  if (LT_PENDING != lt->lt_status)
    itc_bust_this_trx (itc, NULL, ITC_BUST_THROW);
  if (buf_ret && *buf_ret)
    {
      if (!landed)
	{
	  *buf_ret = itc_reset (itc);
	  DBG_PT_PRINTF (("cpt freeze reset of %p to L=%d\n", itc, itc->itc_page));
	}
      else
	{
	  *buf_ret = page_reenter_excl (itc);
	  DBG_PT_PRINTF (("cpt freeze reenter  of %p to L=%d\n", itc, itc->itc_page));

	}
      ITC_LEAVE_MAPS (itc);
    }
}


void
lt_ack_close (lock_trx_t * lt)
{
  ASSERT_IN_TXN;
  switch (lt->lt_status)
    {
      case LT_COMMITTED: /* 2pc : with until final commit or abort */
      case LT_CLOSING:
	  LT_CLOSE_ACK_THREADS(lt);
	  lt->lt_close_ack_threads++;
	  lt_wait_until_dead (lt);
	  break;

      case LT_BLOWN_OFF:
      case LT_FREEZE:
	  if (lt->lt_threads - (lt->lt_lw_threads + lt->lt_close_ack_threads) > 1)
	    {
	      LT_CLOSE_ACK_THREADS(lt);
	      lt->lt_close_ack_threads++;
	      lt_wait_until_dead (lt);
	    }
	  else
	    {
	      LT_CLOSE_ACK_THREADS(lt);
	      lt->lt_close_ack_threads++;
	      lt_transact (lt, SQL_ROLLBACK);
	    }
	  ASSERT_IN_TXN;
	  break;

#if 0
      case LT_DELTA_ROLLED_BACK:
	  break;
#endif

#ifdef VIRTTP
      case LT_PREPARE_PENDING:
	  lt_rollback(lt,TRX_CONT);
	  break;

      case LT_FINAL_COMMIT_PENDING:
	  lt_2pc_commit(lt);
	  break;
#endif
    }
}

void
itc_bust_this_trx (it_cursor_t * it, buffer_desc_t ** buf, int may_ret)
{
  /* if ITC_BUST_CONTINUABLE, this function may just freeze over checkpoint.
     * Otherwise this function must rollback the transaction and throw to the itc reset context */
  lock_trx_t *lt = it->itc_ltrx;
  int is_rb = may_ret == ITC_BUST_THROW;
  if (LT_FREEZE != lt->lt_status)
    is_rb = 1;
  if (is_rb)
    {
      ITC_LEAVE_MAPS (it);
      itc_free_hold (it);
      if (buf && *buf)
	{
	  /* the itc is not supposed to be registered.  If it still is, unregistered it by the book.  Could even be registered on a different buffer.  */
	  if (!it->itc_is_registered)
	    {
	      page_leave_outside_map (*buf);
	    }
	  else if (it->itc_buf_registered == *buf)
	    {
	      itc_unregister_inner (it, *buf, 0);
	      page_leave_outside_map (*buf);
	    }
	  else
	    {
	      page_leave_outside_map (*buf);
	      itc_unregister (it);
	    }
	}
      else
	itc_unregister (it);	/* Make sure. */
      rdbg_printf (("  Trx %s T=%ld killed itself at %ld, thr = %d itc=%x.\n",
		    LT_NAME (lt), TRX_NO (lt), lt->lt_age,
		    lt->lt_threads, it));

      IN_TXN;
      if (LT_PENDING == lt->lt_status)
	/* rollback may be in progress on other thread. Do not change statues if so. **/
	lt->lt_status = LT_BLOWN_OFF;

      thr_set_error_code (THREAD_CURRENT_THREAD, NULL);
      if (!it->itc_insert_key || it->itc_insert_key->key_id != KI_TEMP)
        lt_ack_close (lt);
      else
	{
	  rdbg_printf (("skipped lt_ack_close lt=%p itc=%p\n", lt, it));
	}
      LEAVE_TXN;
      if (!it->itc_fail_context)
	GPF_T1 ("No ITC fail context");			/* No fail context */
      longjmp_splice (it->itc_fail_context, RST_DEADLOCK);
    }
  else
    {
      if (lt != wi_inst.wi_cpt_lt)
	lt_ack_freeze (lt, it, buf);
    }
}


void
lt_rollback_other (lock_trx_t * lt)
{
  /* in killing somebody else's txn, must inc threads if no thread inside cause a duplicate kill of same will try waiting for the transact to finish, which presupposes that the finishing lt has a thread inside */
  int thr = lt->lt_threads;
  if (!thr)
    lt->lt_close_ack_threads = lt->lt_threads = 1;
  lt_transact (lt, SQL_ROLLBACK);
  if (!thr)
    lt->lt_threads = 0;
}


#define LT_NO_THREADS(lt) (!(lt)->lt_threads)


void
lt_kill_other_trx (lock_trx_t * lt, it_cursor_t * itc, buffer_desc_t * buf, int may_freeze)
{
  ASSERT_IN_TXN;
  if (itc)
    {
      if (! itc->itc_is_registered)
	itc_register (itc, buf);
      page_leave_outside_map (buf);
    }
  switch (lt->lt_status)
    {
#if 0 /* former xa 2pc */
    case LT_COMMITTED:
	if (lt->lt_threads > 0
	    && !lt->lt_vdb_threads
	    && !lt->lt_lw_threads
	    && !lt->lt_close_ack_threads)
	  {
	    lt->lt_status = LT_FINAL_COMMIT_PENDING;
	    lt_wait_until_dead (lt);
	  }
	else
	  {
	    lt_2pc_commit (lt);
	  }
	break;
#endif
    case LT_CLOSING:
    case LT_FINAL_COMMIT_PENDING:
      {
	TC (tc_kill_closing);
	rdbg_printf ((" host %d:  Kill closing lt %d:%d\n", local_cll.cll_this_host, LT_W_NO (lt)));
	lt_wait_until_dead (lt);
	break;
      }
    case LT_DELTA_ROLLED_BACK:
      {
	GPF_T1 ("Not supposed to kill rolled back transactions in lt_kill_other_trx");
      }
    case LT_1PC_PENDING:
    case LT_2PC_PENDING:
      GPF_T;
      lt_wait_until_dead (lt);
      break;
    case LT_COMMITTED:
    case LT_PENDING:
    case LT_BLOWN_OFF:
      if (LT_IS_RUNNING (lt))
	{
	  /* the transaction is running, not waiting for locks or vdb io */
#ifdef VIRTTP
	  if (LT_KILL_ROLLBACK == may_freeze && lt->lt_client->cli_tp_data && !lt->lt_2pc._2pc_prepared)
	    {
	      rdbg_printf (("setting LT_PREPARE_CHKPNT %x\n", lt));
	      lt->lt_2pc._2pc_prepared = (caddr_t) TP_PREPARE_CHKPNT;
	    }
#endif
	  rdbg_printf (("Host %d: Kill of running lt state %d w=%d:%d\n", local_cll.cll_this_host, lt->lt_status, LT_W_NO (lt)));
	  if (LT_KILL_FREEZE == may_freeze
	      && LT_PENDING == lt->lt_status)
	    lt->lt_status = LT_FREEZE;
	  else
	    lt->lt_status = LT_BLOWN_OFF;
	  lt_wait_until_dead (lt);
	}
      else
        {
	  if (LT_KILL_ROLLBACK == may_freeze)
	    {
	      /* send cluster rb's and roll back local delta, rest is done when the client next touches the transaction */
	      rdbg_printf (("Host %d: Kill non-running st=%d lw=%d vd=%d w=%d:%d\n", local_cll.cll_this_host, lt->lt_status, lt->lt_lw_threads, lt->lt_vdb_threads, LT_W_NO (lt)));
	      /* the rb can cause pending rpcs to return, the trx's thread must not think that it is ok to continue */
	      lt->lt_status = LT_BLOWN_OFF;
	      lt_rollback_other (lt);
	    }
	  else
	    {
	      if (lt->lt_threads)
		lt->lt_status = LT_FREEZE; /* acted on by resume of lock wait or vdb_leave (), waiting for cpt over.  If client txn with no delta and no threads do nothing. */
	    }
        }
      break;
    case LT_CL_PREPARED:
      ASSERT_IN_TXN;
      if (LT_IS_RUNNING (lt))
	{
	  /* the transaction is running, not waiting for locks or vdb io */
	  rdbg_printf (("Host %d: Kill running cl prepared w=%d:%\n", local_cll.cll_this_host, LT_W_NO (lt)));
	  if (LT_KILL_ROLLBACK == may_freeze)
	    lt->lt_status = LT_BLOWN_OFF;
	  lt_wait_until_dead (lt);
	}
      else
        {
	  if (LT_KILL_ROLLBACK == may_freeze)
	    {
	      /* send cluster rb's and roll back local delta, rest is done when the client next touches the transaction */
	      /* the rb can cause pending rpcs to return, the trx's thread must not think that it is ok to continue */
	      rdbg_printf (("Host %d: Kill non-running cl prepared w=%d:%d\n", local_cll.cll_this_host, LT_W_NO (lt)));
	      lt->lt_status = LT_BLOWN_OFF;
	      lt_rollback_other (lt);
	    }
        }
      break;

#ifdef VIRTTP
    case LT_PREPARE_PENDING:
      {
	ASSERT_IN_TXN;
	if (lt->lt_threads > 0
	    && !lt->lt_vdb_threads
	    && !lt->lt_lw_threads
	    && !lt->lt_close_ack_threads)
	  {
	    lt_wait_until_dead(lt);
	  }
	else
	  {
	    lt_rollback(lt,TRX_CONT);
	  }
        }
      break;
#endif
    case LT_FREEZE:
      if (LT_KILL_FREEZE == may_freeze) GPF_T1 ("not supposed to freeze a lt with freeze pending");
      /* a kill may come when freeze is pending.  If the freeze is not yet ack'ed, change it to bust and wait for the kill. */
      if (LT_NO_THREADS (lt))
	GPF_T1 ("lt freeze is not supposed to be in effect if there are no threads in the lt");
      if (LT_IS_RUNNING (lt))
	{
	  lt->lt_status = LT_BLOWN_OFF;
	  lt_wait_until_dead (lt);
	}
      else
	{
	  /* waiting for io or acked the freeze */
	}
      break;
    default: GPF_T1 ("transaction in unknown lt_status in lt_kill_other_trx");
    }
  ASSERT_IN_TXN;
}


void
lt_killall (lock_trx_t * exc, int lte)
{
  dk_set_t killed = NULL;
 again:
  DO_SET (lock_trx_t *, lt, &all_trxs)
    {
      ASSERT_IN_TXN;
      if (lt != exc && lt->lt_status == LT_PENDING
	  && (lt->lt_threads > 0 || lt_has_locks (lt) || lt->lt_cl_branches)
	  && !dk_set_member (killed, (void*)lt))
	{
	  lt->lt_error = lte;
	  dk_set_push (&killed, (void*) lt);
	  lt_kill_other_trx (lt, NULL, NULL, LT_KILL_ROLLBACK);
	  goto again;
	}
    }
  END_DO_SET ();
  dk_set_free (killed);
}


void
lock_new_owner_win (gen_lock_t * pl, it_cursor_t * itc, buffer_desc_t * buf,
		    lock_trx_t * deadlocked)
{
  GPF_T1 ("not in use");
#if 0
  du_thread_t * self = THREAD_CURRENT_THREAD;
  TC (tc_deadlock_win_get_lock);
  if (pl->pl_waiting
      || pl->pl_is_owner_list)
    GPF_T1 ("can't win deadlock were there's a queue or shared lock");
  lt_add_pl (itc->itc_ltrx, itc->itc_pl, 0);

  itc->itc_next_on_lock = NULL;
  itc_unregister (itc);
  pl->pl_waiting = itc;
  itc->itc_ltrx->lt_lw_threads++;
  itc->itc_thread = self;
  lt_kill_other_trx (deadlocked, itc, buf);
  semaphore_enter (self->thr_sem); /* count was incremented by lt_kill_other_trx */
  FAILCK (itc);
  ITC_IN_MAP (itc);

  CHECK_DK_MEM_RESERVE (itc->itc_ltrx);
  if (itc->itc_ltrx->lt_status != LT_PENDING)
    {
      itc_bust_this_trx (itc, NULL);
    }
#endif
}


void
lt_assert_waits (lock_wait_t * waits, lock_trx_t * waiting, int first_pred, int last_pred)
{
#if 0
  int inx;
#endif
  return;
#if 0
  /* the following assertion is incorrect when we have a queue of excl - shared non-acquiring - excl
   * The first excl gets in, the non-acquiring gets past and the second excl waits for the
   * first but there is no direct wait edge between the 2.  There is an extra wait edge that passes through the txn
   * of the non-acquiring txn that was in the queue. */
  if (-1 == last_pred || -1 == last_pred)
    return;
  for (inx = first_pred; inx <= last_pred; inx++)
    {
      if (!dk_set_member (waits[inx].lw_trx->lt_waiting_for_this, (void*) waiting))
	GPF_T1 ("missing wait edge in lt_assert_waits");
      if (!dk_set_member (waiting->lt_waits_for, (void*) waits[inx].lw_trx))
	GPF_T1 ("wait edge inconsistent in lt_assert_waits");
    }
#endif
}

#define LOCK_MAX_WAITS 1024

#define CK_MAX_FILL \
  if (fill >= LOCK_MAX_WAITS)  \
    { \
      (*n_dead)++;\
      return 1; \
    }


int
lock_check_deadlock_1 (gen_lock_t * pl, it_cursor_t * itc,
		       int * n_dead, lock_trx_t ** deadlocked)
{
  int inx;
  it_cursor_t * waiting = NULL;
  lock_wait_t waits[LOCK_MAX_WAITS];
  int fill = 0, first_pred = -1, last_pred = -1, last_excl = -1;
  int type = PL_TYPE (pl);
  ASSERT_IN_TXN;
  if (pl->pl_is_owner_list)
    {
      dk_set_t owners = (dk_set_t) pl->pl_owner;
      first_pred = 0;
      DO_SET (lock_trx_t *, owner, &owners)
	{
	  if (LT_CLOSING != owner->lt_status)
	    {
	      waits[fill].lw_trx = owner;
	      waits[fill].lw_mode = PL_SHARED;
	      last_pred = fill;
	      fill++;
	      CK_MAX_FILL;
	    }
	  else
	    TC (tc_wait_for_closing_lt);
	}
      END_DO_SET();
    }
  else
    {
      if (LT_CLOSING != pl->pl_owner->lt_status)
	{
	  waits[fill].lw_trx = pl->pl_owner;
	  waits[fill].lw_mode = type;
	  first_pred = fill;
	  last_pred = fill;
	  if (PL_EXCLUSIVE == type)
	    last_excl = fill;
	  fill++;
	}
      else
	TC (tc_wait_for_closing_lt);
    }
  waiting = pl->pl_waiting;
  while (waiting)
    {
      if (LT_CLOSING == waiting->itc_ltrx->lt_status)
	{
	  TC (tc_wait_for_closing_lt);
	}
      else if (PL_SHARED == waiting->itc_lock_mode)
	{
	  lt_assert_waits (waits, waiting->itc_ltrx, last_excl, last_excl);
	  if (-1 == last_pred || PL_EXCLUSIVE == waits[last_pred].lw_mode)
	    first_pred = fill;
	  waits[fill].lw_trx = waiting->itc_ltrx;
	  waits[fill].lw_mode = waiting->itc_lock_mode;
	  last_pred = fill;
	  fill++;
	}
      else
	{
	  lt_assert_waits (waits, waiting->itc_ltrx, first_pred, last_pred);
	  waits[fill].lw_trx = waiting->itc_ltrx;
	  waits[fill].lw_mode = waiting->itc_lock_mode;
	  first_pred = fill;
	  last_pred = fill;
	  last_excl = fill;
	  fill++;
	}
      waiting = waiting->itc_next_on_lock;
      CK_MAX_FILL;
    }
  if (PL_SHARED == itc->itc_lock_mode)
    {
      if (-1 == last_excl)
	return 0; /* shared with no live excl before can't block hence can't deadlock */
      first_pred = last_excl;
      last_pred = last_excl;
    }
  if (-1 == first_pred)
    return 0; /* no live predecessors, 'longest wait is duration of transact, no deadlock possible */
  for (inx = first_pred; inx <= last_pred; inx++)
    {
      int rc;
      rc = lt_is_deadlock_1 (waits[inx].lw_trx, itc->itc_ltrx, n_dead, deadlocked, 0);
      if (rc)
	return rc;
    }
  for (inx = first_pred; inx <= last_pred; inx++)
    lt_waits_for (waits[inx].lw_trx, itc->itc_ltrx);
  return 0;
}


void
lock_live_deadlocks (gen_lock_t * pl, it_cursor_t * itc, buffer_desc_t * buf,
		     int * n_dead, lock_trx_t ** deadlocked)
{
  lock_trx_t * new_trx = itc->itc_ltrx;
  ASSERT_IN_TXN;
  FAILCK (itc);
  if (pl->pl_is_owner_list)
    {
      if (dk_set_member ((dk_set_t) pl->pl_owner, (void *) new_trx))
	{
	  new_trx->lt_error = LTE_DEADLOCK;
	  lock_deadlocks++;
	  lock_2r1w_deadlocks++;
	  ITC_MARK_DEADLOCK (itc);
	  LEAVE_TXN;
	  itc_bust_this_trx (itc, &buf, ITC_BUST_THROW);
	}
    }
  lock_check_deadlock_1 (pl, itc, n_dead, deadlocked);
}


int
lock_check_deadlock (gen_lock_t * pl, it_cursor_t * it, buffer_desc_t * buf)
{
  /* Look at all before this. If the waiting table of this has any of the
     previous, we have a DEADLOCK. */
  int n_dead = 0;
  lock_trx_t *deadlocked = NULL;

  FAILCK (it);
  ASSERT_IN_TXN;
  if (LT_PENDING != it->itc_ltrx->lt_status && LT_FREEZE != it->itc_ltrx->lt_status)
    {
      LEAVE_TXN;
      itc_bust_this_trx (it, &buf, ITC_BUST_THROW);
    }
  lock_live_deadlocks (pl, it, buf, &n_dead, &deadlocked);
  if (n_dead == 0)
    {
      /* safe to go to wait. inc the wait count here inside the txn mtx.  Must be in the same txn sect w/ the lt_status check, c.f. lt_kill_other_trx */
      it->itc_ltrx->lt_lw_threads++;
      return 0;
    }
  LEAVE_TXN;
  lock_deadlocks++;
  ITC_MARK_DEADLOCK (it);

  rdbg_printf (("    deadlock n=%d ao=%d an=%d %s %s\n",
		n_dead, deadlocked->lt_age, it->itc_ltrx->lt_age, pl->pl_waiting ? "LQ" : "NQ",
		pl->pl_is_owner_list ? "OL" : "1O"));
  it->itc_ltrx->lt_error = LTE_DEADLOCK;
  itc_bust_this_trx (it, &buf, ITC_BUST_THROW);
  return 1;
}


#define PL_OWNER_NO(pl) \
  (pl->pl_is_owner_list ? 0 : TRX_NO (pl->pl_owner))



int
lock_wait (gen_lock_t * pl, it_cursor_t * it, buffer_desc_t * buf,
	   int acquire)
{
  long time;
  lock_trx_t * lt = it->itc_ltrx;
  ITC_LEAVE_MAPS (it);
  cl_enlist_ck (it);
  it->itc_acquire_lock = acquire;
  it->itc_thread = THREAD_CURRENT_THREAD;
  IN_TXN;
  if (LT_PENDING != lt->lt_status && LT_FREEZE != lt->lt_status)
    {
      LEAVE_TXN;
      itc_bust_this_trx (it, &buf, ITC_BUST_THROW);
    }
  lock_check_deadlock (pl, it, buf);
  if (LT_FREEZE == lt->lt_status)
    {
      /* printf ("lock wait freeze here\n"); */
      lt->lt_status = LT_PENDING;
      lt_resume_waiting_end (lt); /* this thread goes to wait.  lw is as good as freeze. The txn mtx is never left, so the lock will be there.  */
    }
  lock_waits++;
  if (it->itc_page != it->itc_pl->pl_page)
    GPF_T1 ("different itc_oage and pl_page in lock_wait");
  lt_add_pl (it->itc_ltrx, it->itc_pl, 0);
  lt->lt_wait_since = approx_msec_real_time (); /* first set approx inside the mtxm, then get real time outside of the mtx */
  if (!pl->pl_waiting)
    {
      pl->pl_waiting = it;
    }
  else
    {
      it_cursor_t *last = pl->pl_waiting;
      while (last->itc_next_on_lock)
	last = last->itc_next_on_lock;
      last->itc_next_on_lock = it;
    }
  it->itc_next_on_lock = NULL;
  LEAVE_TXN;

  if (it->itc_is_registered)
    GPF_T1 ("can't have registered itc in lock_wait.  lock_wait is supposed to register the itc");
  itc_register (it, buf);
  rdbg_printf (("    LW itc=%x L=%d T=%d pl %x owner T=%d LF=%x K=%s\n",
		it, it->itc_page,
		TRX_NO (it->itc_ltrx), it->itc_pl, PL_OWNER_NO (pl), (int) pl->pl_type, it->itc_insert_key->key_name));
  page_leave_outside_map (buf);
  time = get_msec_real_time ();
  it->itc_ltrx->lt_wait_since = time;
  it->itc_write_waits += 1000;
  FAILCK (it);
  ITC_SEM_WAIT (it);
  if (it->itc_ltrx->lt_lw_threads)
    GPF_T1 ("lock wait over or but lw_threads. Wrong party signalled the thr sem.");
  FAILCK (it);
  ITC_MARK_LOCK_WAIT (it, time);

  CHECK_DK_MEM_RESERVE (it->itc_ltrx);
  if (it->itc_ltrx->lt_status != LT_PENDING && it->itc_ltrx->lt_status != LT_FREEZE)
    {
      itc_bust_this_trx (it, NULL, ITC_BUST_THROW);
    }

  if (!it->itc_is_on_row)
    return WAIT_RESET;
  return WAIT_OVER;
}


int
lock_add_owner (gen_lock_t * pl, it_cursor_t * it, int was_waiting)
{
  if (PL_TYPE (pl) == PL_FREE)
    {
      PL_SET_TYPE (pl, it->itc_lock_mode);
      pl->pl_owner = it->itc_ltrx;
      pl->pl_is_owner_list = 0;
      if (!was_waiting)
	lt_add_pl (it->itc_ltrx, it->itc_pl, 0);
      ITC_MARK_LOCK_SET (it);
      return 1;
    }
  if (pl->pl_owner == it->itc_ltrx)
    {
      if (it->itc_lock_mode == PL_EXCLUSIVE)
	PL_SET_TYPE (pl, PL_EXCLUSIVE);
      return 1;
    }
  if (PL_TYPE (pl) == PL_EXCLUSIVE)
    return 0;

  if (it->itc_lock_mode == PL_EXCLUSIVE)
    {
      return 0;
    }

  /* If the lock is shared and there's a queue, do not bypass */

  if (!pl->pl_owner)
    GPF_T;			/* Lock with no owner */
  if (!pl->pl_is_owner_list)
    {
      if (pl->pl_waiting && !was_waiting)
	return 0;		/* There's others before. */
      pl->pl_is_owner_list = 1;
      pl->pl_owner = (lock_trx_t *) dk_set_cons ((caddr_t) pl->pl_owner,
	  NULL);
    }
  if (!dk_set_member ((dk_set_t) pl->pl_owner,
	  (void *) it->itc_ltrx))
    {
      if (pl->pl_waiting && !was_waiting)
	return 0;		/* There's others before */
      ITC_MARK_LOCK_SET (it);
      dk_set_push ((dk_set_t *) & pl->pl_owner,
	  (void *) it->itc_ltrx);
      if (!was_waiting)
	lt_add_pl (it->itc_ltrx, it->itc_pl, 0);
    }
  return 1;
}


int
lock_enter (gen_lock_t * pl, it_cursor_t * it, buffer_desc_t * buf)
{
  lock_enters++;
  if (lock_add_owner (pl, it, 0))
    {
      return NO_WAIT;
    }
  return (lock_wait (pl, it, buf, ITC_LOCK_IF_ON_ROW));
}


void
lt_clear_pl_wait_ref (lock_trx_t * waiting, gen_lock_t * pl)
{
  if (PL_IS_PAGE (pl))
    {
      IN_LT_LOCKS (waiting);
      if (remhash ((void*) pl, &waiting->lt_lock))
	{
	  TC (tc_pl_non_owner_wait_ref_deld);
	}
      LEAVE_LT_LOCKS (waiting);
    }
}


void
lt_drop_wait (lock_trx_t * before, lock_trx_t * after)
{
  int both_pending;
  IN_TXN;
  both_pending = after->lt_status == LT_PENDING && before->lt_status == LT_PENDING;
  if (1 == after->lt_threads)
    {
      if (1 != after->lt_lw_threads)
	GPF_T1 ("waiting trx w/ no lt_lw_threads");
      rdbg_printf (("   Non acq wait drop - before T=%ld after T=%ld \n",  TRX_NO (before), TRX_NO (after)));
      if (!dk_set_delete (&before->lt_waiting_for_this, (void*) after))
	{
	  log_error ("Missing wait edge between non-pending #1 after status = %d before status = %d",
		     after->lt_status, before->lt_status);
	  if (!wi_inst.wi_is_checkpoint_pending && both_pending)
	    GPF_T1 ("Missing wait edge outside of checkpoint ");
	}
      if (!dk_set_delete (&after->lt_waits_for, (void*) before))
	{
	  log_error ("Missing wait edge between non-pending #2 after status = %d before status = %d",
		     after->lt_status, before->lt_status);
	  if (!wi_inst.wi_is_checkpoint_pending && both_pending)
	    GPF_T1 ("Missing wait edge outside of checkpoint ");
	}
    }
  LEAVE_TXN;
}


void
lt_clear_non_acq_release_wait (it_cursor_t * waiting)
{
  /* when an excl non-acquiring crsr is released, the next txn on the lock has a wait edge to
   * the released txn.  If the next txn in the queue has 1 thread then it follows that there are no other wait edges between the waiting and the released except the one pertaining to the lock at hand.  Since the wait is over the edge is extra and will lead to false deadlock detection */
  it_cursor_t * next = waiting->itc_next_on_lock;
#if 0  /* not always true in checkpoint/rollback itc */
  if (waiting->itc_ltrx->lt_waits_for)
    GPF_T1 ("txn is released yet waits"); /*only applies if max 1 thread per txn */
#endif
  if (!next
      || waiting->itc_ltrx->lt_threads != 1)
    return;
  if (PL_EXCLUSIVE == waiting->itc_lock_mode)
    {
      if (PL_EXCLUSIVE == next->itc_lock_mode)
	lt_drop_wait (waiting->itc_ltrx, next->itc_ltrx);
      else
	{
	  while (next && PL_SHARED == next->itc_lock_mode)
	    {
	      lt_drop_wait (waiting->itc_ltrx, next->itc_ltrx);
	      next = next->itc_next_on_lock;
	    }
	}
    }
  else
    {
      while (next && PL_SHARED == next->itc_lock_mode)
	next = next->itc_next_on_lock;
      if (next && PL_EXCLUSIVE != next->itc_lock_mode)
	GPF_T1 ("next excl is not excl");
      if (next)
	lt_drop_wait (waiting->itc_ltrx, next->itc_ltrx);
    }
}


int
pl_is_owner (page_lock_t *pl, lock_trx_t * lt)
{
  if (pl->pl_is_owner_list)
    return NULL != dk_set_member ((dk_set_t)pl->pl_owner, (void*) lt);
  else
    return pl->pl_owner == lt;
}


void
pl_check_owners (page_lock_t * pl)
{
  DO_RLOCK (rl, pl)
    {
      it_cursor_t * waiting = rl->pl_waiting;
      if (rl->pl_is_owner_list)
	{
	  dk_set_t owners = (dk_set_t)rl->pl_owner;
	  DO_SET (lock_trx_t *, owner, &owners)
	    {
	      if (!pl_is_owner (pl, owner))
		GPF_T1 ("owner of rl is not owner of containing pl");
	    }
	  END_DO_SET();
	}
      else
	{
	  if (!pl_is_owner (pl, rl->pl_owner))
	    GPF_T1 ("owner of rl is not owner of containing pl");
	}
      while (waiting)
	{
	  if (!pl_is_owner (pl, waiting->itc_ltrx))
	    GPF_T1 ("txn waiting on rl is not owner of containing pl");
	  waiting = waiting->itc_next_on_lock;
	}
    }
  END_DO_RLOCK;
}

void
lock_release (gen_lock_t * pl, lock_trx_t * lt)
{
  lock_trx_t * prev_released;
  it_cursor_t *waiting;
  int was_owner = 0;

  lock_leaves++;
  if (pl->pl_owner == lt)
    {
      was_owner = 1;
      PL_SET_TYPE (pl, PL_FREE);
      pl->pl_owner = NULL;
    }
  if (pl->pl_is_owner_list)
    {
      dk_set_t owners = (dk_set_t) pl->pl_owner;
      if (dk_set_member (owners, (void *) lt))
	{
	  was_owner = 1;
	  dk_set_delete ((dk_set_t *) & pl->pl_owner, (void *) lt);
	  if (dk_set_member ((dk_set_t) pl->pl_owner, (void *) lt))
	    GPF_T1 ("Doubly owned lock");
	  if (!pl->pl_owner)
	    {
	      PL_SET_TYPE (pl, PL_FREE);
	    }
	  else
	    {
	      owners = (dk_set_t) pl->pl_owner;
	      if (!owners->next)
		{
		  pl->pl_is_owner_list = 0;
		  pl->pl_owner = (lock_trx_t *) owners->data;
		  dk_set_free (owners);
		}
	    }
	}
    }
  {
    it_cursor_t **prev = &pl->pl_waiting;
    it_cursor_t *waiting;
    waiting = pl->pl_waiting;
    /* Free cursors of the ending trx. */
    while (waiting)
      {
	it_cursor_t *next;
	if (waiting->itc_ltrx == lt)
	  {
	    *prev = waiting->itc_next_on_lock;
	    next = waiting->itc_next_on_lock;
	    FAILCK (waiting);
	    rdbg_printf (("released dead trx itc %x T=%ld\n", waiting, TRX_NO (lt)));
	    IN_TXN;
	    waiting->itc_ltrx->lt_lw_threads--;
	    LEAVE_TXN;
	    semaphore_leave (waiting->itc_thread->thr_sem);
	    waiting = next;
	  }
	else if (waiting->itc_ltrx->lt_status != LT_PENDING)
	  {
	    rdbg_printf (("Release itc of dead txn by third party. L=%d closing T=%ld released T=%ld \n",
			  waiting->itc_page, TRX_NO (lt), TRX_NO (waiting->itc_ltrx)));
	    lt_clear_pl_wait_ref (waiting->itc_ltrx, pl);
	    *prev = waiting->itc_next_on_lock;
	    next = waiting->itc_next_on_lock;
	    FAILCK (waiting);
	    IN_TXN;
	    waiting->itc_ltrx->lt_lw_threads--;
	    LEAVE_TXN;
	    semaphore_leave (waiting->itc_thread->thr_sem);
	    waiting = next;
	  }
	else
	  {
	    prev = &waiting->itc_next_on_lock;
	    waiting = waiting->itc_next_on_lock;
	  }
      }
  }

  waiting = pl->pl_waiting;
  prev_released = lt;
  while (pl->pl_waiting)
    {
      int acq;
      waiting = pl->pl_waiting;
      acq = !(waiting->itc_acquire_lock == ITC_NO_LOCK
	      || !waiting->itc_is_on_row);

      if (!acq && PL_SHARED == waiting->itc_lock_mode)
	{
	  if (PL_EXCLUSIVE != PL_TYPE (pl))
	    {
	      rdbg_printf (("release non-acq shared itc %lx T=%ld on %ld pos %d is_on_row %d\n",
			    waiting, TRX_NO (waiting->itc_ltrx), waiting->itc_page, waiting->itc_map_pos, waiting->itc_is_on_row));
	      pl->pl_waiting = waiting->itc_next_on_lock;
	      lt_clear_pl_wait_ref (waiting->itc_ltrx, pl);
	      lt_clear_non_acq_release_wait (waiting);
	      prev_released = waiting->itc_ltrx;
	      waiting->itc_pl = NULL;
	      IN_TXN;
	      waiting->itc_ltrx->lt_lw_threads--;
	      LEAVE_TXN;
	      semaphore_leave (waiting->itc_thread->thr_sem);
	    }
	  else
	    break;
	}
      else if (!acq && PL_EXCLUSIVE == waiting->itc_lock_mode)
	{
	  if (PL_FREE == PL_TYPE (pl))
	    {
	      rdbg_printf (("release non-acq exc itc %lx T=%ld on %ld pos %d is_on_row %d\n",
			    waiting, TRX_NO (waiting->itc_ltrx), waiting->itc_page, waiting->itc_map_pos, waiting->itc_is_on_row));
	      pl->pl_waiting = waiting->itc_next_on_lock;
	      lt_clear_pl_wait_ref (waiting->itc_ltrx, pl);
	      lt_clear_non_acq_release_wait (waiting);
	      prev_released = waiting->itc_ltrx;
	      waiting->itc_pl = NULL;
	      IN_TXN;
	      waiting->itc_ltrx->lt_lw_threads--;
	      LEAVE_TXN;
	      semaphore_leave (waiting->itc_thread->thr_sem);
	    }
	  else
	    break;
	}
      else if (lock_add_owner (pl, waiting, 1))
	{
	  pl->pl_waiting = waiting->itc_next_on_lock;
	  rdbg_printf (("release owner %x %s T=%ld on %ld pos %d ending T=%ld owner T=%ld \n",
			waiting, PL_SHARED == waiting->itc_lock_mode ? "S" : "E", TRX_NO (waiting->itc_ltrx), waiting->itc_page, waiting->itc_map_pos,
			TRX_NO (lt), TRX_NO (waiting->itc_ltrx)));
	  prev_released = waiting->itc_ltrx;
	  IN_TXN;
	  waiting->itc_ltrx->lt_lw_threads--;
	  LEAVE_TXN;
	  semaphore_leave (waiting->itc_thread->thr_sem);
	  if (PL_EXCLUSIVE == waiting->itc_lock_mode)
	    break; /* the lock was excl. acquired.  The queued non-acquiring itc's may wait until this owner is done */
	}
      else
	{
	  break;		/* Didn't get in */
	}
    }

  if (pl->pl_owner == NULL && pl->pl_waiting)
    GPF_T;			/* Lock free but cr waiting */

}


void
rl_release_list (row_lock_t ** rlist, lock_trx_t * lt, page_lock_t * pl)
{
  row_lock_t ** prev = rlist;
  row_lock_t * rl = *prev;
  while (rl)
    {
      row_lock_t * next = rl->rl_next;
      lock_release ((gen_lock_t *) rl, lt);
      if (PL_FREE == PL_TYPE (rl))
	{
	  *prev = next;
	  rl_free (rl);
	  pl->pl_n_row_locks--;
	}
      else
	prev = &rl->rl_next;
      rl = next;
    }
}


void
pl_remove_owner (page_lock_t * pl, lock_trx_t * lt)
{
  dk_set_t o_list;
  if (pl->pl_is_owner_list)
    {
      if (!dk_set_delete ((dk_set_t *) &pl->pl_owner, (void*) lt))
	GPF_T1 ("lt references pl whose owner it is not");
      if (dk_set_member ((dk_set_t) pl->pl_owner, (void*) lt))
	GPF_T1 ("Doubly owned pl");
      o_list = (dk_set_t) pl->pl_owner;
      if (! o_list->next)
	{
	  pl->pl_owner = (lock_trx_t *) o_list->data;
	  pl->pl_is_owner_list = 0;
	  dk_free ((caddr_t) o_list, sizeof (s_node_t));
	}
    }
  else
    {
      if (pl->pl_owner != lt)
	GPF_T1 ("not owner of pl");
      pl->pl_owner = NULL;
      PL_SET_TYPE (pl, PL_FREE);
    }
}


void
pl_release (page_lock_t * pl, lock_trx_t * lt, buffer_desc_t * buf)
{
  int inx;
  index_tree_t * it = pl->pl_it;
  it_map_t * itm = IT_DP_MAP (pl->pl_it, pl->pl_page);
  ASSERT_OUTSIDE_MTX (&itm->itm_mtx);
  mutex_enter (it->it_lock_release_mtx);
#if defined (MTX_DEBUG) || defined (PAGE_TRACE)
  pl_check_owners (pl);
#endif
  if (PL_IS_PAGE (pl))
    lock_release ((gen_lock_t *) pl, lt);
  else
    {
      if (pl->pl_waiting)
	GPF_T1 ("Can't wait at page when there's row locks");
      for (inx = 0; inx < N_RLOCK_SETS; inx++)
	{
	  rl_release_list (&pl->pl_rows[inx], lt, pl);
	}
      pl_remove_owner (pl, lt);
    }
  if (PL_TYPE (pl) == PL_FREE)
    {
      if (pl->pl_waiting)
	GPF_T1 ("Can't wait on a free pl");
      if (pl->pl_n_row_locks)
	GPF_T1 ("can't free pl with row locks");
      if (pl->pl_owner)
	GPF_T1 ("lock should not have an owner when it is getting freed");
      mutex_enter (&itm->itm_mtx);
      if (DP_DELETED != pl->pl_page && PL_FINISHING != pl->pl_page)
	{
	  if (!remhash (DP_ADDR2VOID (pl->pl_page),
			&itm->itm_locks))
	    {
	      fflush (stdout);
	      log_error ("freed page lock not in locks");
	      GPF_T1 ("freed page lock not in it_locks");
	    }

	  if (buf)
	    buf->bd_pl = NULL;
	  pl->pl_page = PL_FINISHING;
	}
      mutex_leave (&itm->itm_mtx);
      mutex_enter (pl_ref_count_mtx);
      pl->pl_finish_ref_count--;
      if (0 == pl->pl_finish_ref_count)
	pl_free (pl);
      else
	printf (" hold before free of pl L=%ld with finish ref count\n", (long) pl->pl_page);
      mutex_leave (pl_ref_count_mtx);
    }
  else
    {
      mutex_enter (pl_ref_count_mtx);
      pl->pl_finish_ref_count--;
      mutex_leave (pl_ref_count_mtx);
    }
  mutex_leave (it->it_lock_release_mtx);
}


void
pl_page_deleted (page_lock_t * pl, buffer_desc_t * buf)
{
  it_map_t * itm;
  if (!pl)
    return;
  itm = IT_DP_MAP (pl->pl_it, pl->pl_page);
  ASSERT_IN_MAP (pl->pl_it, pl->pl_page);
  if (!remhash (DP_ADDR2VOID (pl->pl_page),
		&itm->itm_locks))
    GPF_T1 ("freed page lock not in it_locks");
  pl->pl_page = DP_DELETED;
  if (buf)
    buf->bd_pl = NULL;
}

dk_mutex_t *srv_background_task_queue_mtx;
dk_set_t srv_background_task_queue;

int srv_add_background_task (srv_background_task_t task, void *appdata)
{
  dk_set_t iter;
  int res;
  if (NULL == srv_background_task_queue_mtx)
    srv_background_task_queue_mtx = mutex_allocate ();
  mutex_enter (srv_background_task_queue_mtx);
  for (iter = srv_background_task_queue; NULL != iter; iter=iter->next->next)
    {
      if (iter->data != appdata)
        continue;
      if (iter->next->data != (void *) task)
        GPF_T1 ("requests for different background tasks with same data");
      res = 0;
      goto leave;
    }
  dk_set_push (&srv_background_task_queue, (void *)task);
  dk_set_push (&srv_background_task_queue, (void *)appdata);
  res = 1;
leave:
  mutex_leave (srv_background_task_queue_mtx);
  return res;
}

static void srv_run_background_tasks (void)
{
  dk_set_t old_queue;
  if (NULL == srv_background_task_queue_mtx)
    return;
  mutex_enter (srv_background_task_queue_mtx);
  old_queue = srv_background_task_queue;
  srv_background_task_queue = NULL;
  mutex_leave (srv_background_task_queue_mtx);
  while (NULL != old_queue)
    {
      void *appdata = dk_set_pop (&old_queue);
      srv_background_task_t task = (srv_background_task_t) dk_set_pop (&old_queue);
      task (appdata);
    }
}

#define AUTO_FLUSH_DELAY 60000

unsigned long main_continuation_reason = 0; /* 0 - checkpoint; 1 - scheduler */


dk_mutex_t *time_mtx;

unsigned long checkpointed_last_time = 0;


#ifdef HAVE_GETRUSAGE
#include <sys/resource.h>
#endif

int last_majflt = 0;
int32 swap_guard_on = 0;
int process_is_swapping = 0;

void
the_grim_swap_guard ()
{
#ifdef HAVE_GETRUSAGE
  struct rusage ru;
  if (!swap_guard_on)
    return;
  if (wi_inst.wi_is_checkpoint_pending)
  return;
  getrusage (RUSAGE_SELF, &ru);
#ifdef GPF_ON_SWAPPING
  if (ru.ru_majflt - last_majflt > 300)
    GPF_T1 ("started swapping");
#endif
  if (virtuoso_server_initialized && ru.ru_majflt - last_majflt > 300)
    {
      if (!process_is_swapping)
	log_error ("The process started swapping, all pending transactions will be killed");
      process_is_swapping = 1;
    }
  else
    {
      if (process_is_swapping)
	process_is_swapping = 0;
  last_majflt = ru.ru_majflt;
    }
#endif
}


unsigned long cfg_resources_clear_interval = 0;
extern uint32 cl_last_wait_query;

uint32 prev_reaper_time;

void
clear_old_root_images ()
{
  long now = approx_msec_real_time ();
  mutex_enter (old_roots_mtx);
  {
    buffer_desc_t ** prev = &old_root_images;
    buffer_desc_t * old_img = old_root_images;
    while (old_img)
      {
	buffer_desc_t * next = old_img->bd_next;
	if ((bp_ts_t)now - old_img->bd_timestamp > 30000)
	  {
	    *prev = old_img->bd_next;
	    resource_store (PM_RC (old_img->bd_content_map->pm_size), (void*) old_img->bd_content_map);
	    buffer_free (old_img);
	  }
	else
	  prev = &old_img->bd_next;
	old_img = next;
      }
  }
  mutex_leave (old_roots_mtx);
}

void
the_grim_lock_reaper (void)
{
  static int auto_f_count = 0;
  static unsigned long schedule_last_time = 0;
  static unsigned long thread_clear_last_time = 0;
  static unsigned long resources_clear_last_time = 0;
  long now = approx_msec_real_time ();
  int server_is_idle = 1;
  dt_init ();
  if (CPT_CHECKPOINT == wi_inst.wi_is_checkpoint_pending)
    return;
  if (prev_reaper_time && now - prev_reaper_time > 2900)
    {
      /*printf ("lti = %d \n", now - prev_reaper_time);*/
    }
  prev_reaper_time = now;
  the_grim_swap_guard ();
 kill_next_txn:
  IN_TXN;
  DO_SET (lock_trx_t *, lt, &all_trxs)
    {
      client_connection_t * cli = lt->lt_client;
      CHECK_DK_MEM_RESERVE (lt);
      if (lt->lt_started &&
	  ( (lt->lt_timeout && now - lt->lt_started > lt->lt_timeout) || (process_is_swapping && LT_IS_RUNNING (lt)) ) &&
	  lt->lt_status == LT_PENDING)
	{
	  lt->lt_error = LTE_TIMEOUT;
	  dbg_printf (("  Trx %s timed out after %ld msec.\n",
		       LT_NAME (lt), now - lt->lt_started));
#ifndef NDEBUG
	  if (process_is_swapping)
	    ws_lt_trace (lt);
#endif
	  lt_kill_other_trx (lt, NULL, NULL, LT_KILL_ROLLBACK);
	  LEAVE_TXN;
	  goto kill_next_txn;
	}
      if (lt->lt_threads && cli && cli->cli_anytime_timeout && cli->cli_anytime_started
	  && now - cli->cli_anytime_started > cli->cli_anytime_timeout
	  && !cli->cli_terminate_requested)
	{
	  cli->cli_terminate_requested = CLI_RESULT;
	  cli->cli_activity.da_anytime_result = 1;
	  at_printf (("host %d set anytime flag\n", local_cll.cll_this_host));
	}
    }
  END_DO_SET ();
  LEAVE_TXN;

  IN_TXN;
  DO_SET (lock_trx_t *, lt, &all_trxs)
    {
      if (lt->lt_threads)
	server_is_idle = 0;
    }
  END_DO_SET ();
  if (!threads_is_fiber && server_is_idle)
    {
      wi_free_old_qrs ();
      srv_run_background_tasks();
      wi_free_schemas ();
    }
  LEAVE_TXN;
  if (now - last_exec_time > AUTO_FLUSH_DELAY &&
      now - last_flush_time > AUTO_FLUSH_DELAY
      && server_is_idle)
    {
      /* if DELAY elapsed since last stmt executed and
	 DELAY elapsed since last flushed */
      auto_f_count++;
      wi_check_all_compact (0);
      last_flush_time = now;
      mt_write_start (auto_f_count % 10 ? OLD_DIRTY : ALL_DIRTY);
    }


  failed_login_purge ();

  if (cfg_autocheckpoint > 0)	/* Autocheckpointing wanted? */
    {
      if (0 != checkpointed_last_time)	/* Not the first time here? */
	{
	  if (main_thread_ready && (((unsigned long int) now) - checkpointed_last_time)
	      >= cfg_autocheckpoint)
	    {
	      /* Okay do it. I.e. let the loop in main in chil.c to do it. */
	      main_continuation_reason = MAIN_CONTINUE_ON_CHECKPOINT;
	      checkpointed_last_time = (unsigned long int) now;
	      main_thread_ready = 0;
	      semaphore_leave (background_sem);
	    }
	}
      else
	/* First time here. Do it the next time, because we want to
	   give initialization routines some time to do their job. */
	{
	  checkpointed_last_time = (unsigned long int) now;
	}
    }

  if (cfg_scheduler_period) /* scheduler wanted? */
    {
      if (0 != schedule_last_time)
	{
	  if (main_thread_ready && (((unsigned long int)now) - schedule_last_time)
	      >= cfg_scheduler_period)
	    {
	      main_continuation_reason = MAIN_CONTINUE_ON_SCHEDULER;
	      schedule_last_time = (unsigned long int) now;
	      main_thread_ready = 0;
	      semaphore_leave (background_sem);
	    }
	}
      else
	{
	  schedule_last_time = (unsigned long int) now;
	}
    }
  clear_old_root_images ();
  http_reaper ();
  if (cfg_thread_live_period)
    {
      if (0 != thread_clear_last_time)
	{
	  if ((((unsigned long int)now) - thread_clear_last_time) >= cfg_thread_live_period)
	    {
	      int thread_killed = thread_release_dead_threads (cfg_thread_threshold);
	      if (DO_LOG(LOG_THR) && thread_killed)
		log_info ("THRD_1 %ld OS threads freed.", thread_killed);
	      thread_clear_last_time = now;
	    }
	}
      else
	{
	  thread_clear_last_time = (unsigned long int) now;
	}
    }
  if (cfg_resources_clear_interval)
    {
      if (0 != resources_clear_last_time)
	{
	  if ((((unsigned long int)now) - resources_clear_last_time) >= cfg_resources_clear_interval)
	    {
	      resources_reaper ();
	      resources_clear_last_time = now;
	    }
	}
      else
	{
	  resources_clear_last_time = (unsigned long int) now;
	}
    }
  DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_storage)
    {
      dbs_timeout_read_history (dbs);
    }
  END_DO_SET();
/*mapping schema*/
  remove_old_xmlview ();
  sqlo_timeout_text_count ();
#ifdef DEBUG
  shuric_validate_refcounters (0);
#endif
  if (DK_ALLOC_ON_RESERVE)
    dk_alloc_set_reserve_mode (DK_ALLOC_RESERVE_PREPARED); /* IvAn/OutOfMem/040513 If idle then it must have memory reserve. */
}


void
lt_timestamp (lock_trx_t * lt, char *dt_ret)
{
  if (0 == *(ptrlong *) &lt->lt_timestamp)
    {
      mutex_enter (time_mtx);
      dt_now (lt->lt_timestamp);
      mutex_leave (time_mtx);
    }
  memcpy (dt_ret, lt->lt_timestamp, DT_LENGTH);
}


caddr_t
lt_timestamp_box (lock_trx_t * lt)
{
  caddr_t box;
  if (!lt)
    return (dk_alloc_box (0, DV_DB_NULL));
  box = dk_alloc_box (DT_LENGTH, DV_DATETIME);
  lt_timestamp (lt, box);
  return box;
}

void
dbg_flush ()
{
  fflush (stdout);
  fflush (stderr);
}

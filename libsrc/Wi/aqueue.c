/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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

#ifdef NO_AQ_DEBUG
#undef DEBUG
#endif

#include "sqlnode.h"
#include "sqlbif.h"
#include "sqlfn.h"
#include "aqueue.h"
#include "security.h"

resource_t *aq_threads;
int aq_n_threads = 0;
int aq_max_threads = 20;

int aq_free (async_queue_t * aq);

long tc_aq_from_queue;
long tc_aq_from_other;
dk_hash_t *all_aqs;
dk_mutex_t *all_aq_mtx;

#define IN_AQ mutex_enter (all_aq_mtx)
#define LEAVE_AQ mutex_leave (all_aq_mtx)


void
aq_print (async_queue_t * aq)
{
  DO_HT (ptrlong, req_no, aq_request_t *, aqr, aq->aq_requests)
  {
    printf ("%ld state %d aqr %p\n", req_no, aqr->aqr_state, aqr);
  }
  END_DO_HT;
}


void
aq_lt_leave (lock_trx_t * lt, aq_request_t * aqr)
{
  int lte;
  lt_log_merge (lt, 1);
  lte = lt->lt_error;
  lt->lt_at_end_of_aq_thread = 1;
  if (aqr->aqr_error || LT_PENDING != lt->lt_status)
    {
      lt_rollback (lt, TRX_CONT);
      if (!aqr->aqr_error)
	MAKE_TRX_ERROR (lte, aqr->aqr_error, NULL);
    }
  else
    {
      lte = lt_commit (lt, TRX_CONT);
      if (LTE_OK != lte)
	MAKE_TRX_ERROR (lte, aqr->aqr_error, NULL);
    }
  lt_leave (lt);
}


aq_request_t *
aqt_other_aq (aq_thread_t * aqt)
{
  /* called when own aq is exhausted. See if another can be served */
  async_queue_t *best = NULL;
  uint32 best_time;
  uint32 now = 4000 + approx_msec_real_time ();
  ASSERT_IN_MTX (all_aq_mtx);
  DO_HT (async_queue_t *, aq, caddr_t, ign, all_aqs)
  {
    if (aq->aq_no_lt_enter && aq->aq_queue.bsk_count)
      {
	best = aq;
	break;
      }
    if (!aq->aq_deleted && aq->aq_queue.bsk_count
	&& aq->aq_n_threads < aq->aq_max_threads && (!best || best_time < now - aq->aq_ts))
      {
	best = aq;
	best_time = now - aq->aq_ts;
      }
  }
  END_DO_HT;
  if (best)
    {
      aqt->aqt_aq = best;
      best->aq_n_threads++;
      return basket_get (&best->aq_queue);
    }
  return NULL;
}


void
aq_thread_func (aq_thread_t * aqt)
{
  du_thread_t *self = THREAD_CURRENT_THREAD;
  aqt->aqt_thread = self;
  semaphore_enter (aqt->aqt_thread->thr_sem);
  SET_THR_ATTR (self, TA_IMMEDIATE_CLIENT, aqt->aqt_cli);
  sqlc_set_client (aqt->aqt_cli);
  for (;;)
    {
      int64 ts = rdtsc ();
      async_queue_t *aq = aqt->aqt_aq;
      aq_request_t *aqr = aqt->aqt_aqr;
      assert (AQR_QUEUED == aqr->aqr_state);
      aqt->aqt_thread->thr_tlsf = aqt->aqt_cli->cli_tlsf;
      if (!aq->aq_no_lt_enter)
	{
	  lt_enter_anyway (aqt->aqt_cli->cli_trx);
	  aqt->aqt_cli->cli_trx->lt_thr = self;
	  aqt->aqt_cli->cli_trx->lt_main_trx_no = aq->aq_main_trx_no;
	  aqt->aqt_cli->cli_trx->lt_rc_w_id = aq->aq_rc_w_id;
	  memcpy (aqt->aqt_cli->cli_trx->lt_timestamp, aq->aq_lt_timestamp, DT_LENGTH);
	}
      if (aqt->aqt_cli->cli_trx->lt_vdb_threads) GPF_T1 ("at lt not supposed to in io sect");
      if (IS_BOX_POINTER (aqt->aqt_cli->cli_trx->lt_replicate))
	dk_free_tree (aqt->aqt_cli->cli_trx->lt_replicate);
      aqt->aqt_cli->cli_trx->lt_replicate = (caddr_t *) aq->aq_replicate;
      aqt->aqt_cli->cli_row_autocommit = aq->aq_row_autocommit;
      aqt->aqt_cli->cli_non_txn_insert = aq->aq_non_txn_insert;
      aqt->aqt_cli->cli_no_triggers = aq->aq_no_triggers;
      aqt->aqt_cli->cli_terminate_requested = 0;
      aqt->aqt_cli->cli_anytime_started = aq->aq_anytime_started;
      aqt->aqt_cli->cli_anytime_timeout = aq->aq_anytime_timeout;
      aqt->aqt_cli->cli_anytime_qf_started = 0;
      aqt->aqt_cli->cli_cl_stack = (cl_call_stack_t *) box_copy ((caddr_t) aq->aq_cl_stack);
      aqt->aqt_cli->cli_aqr = aqr;
      if (AQR_QUEUED != aqr->aqr_state)
	GPF_T1 ("aqr_state is supposed to be AQR_QUEUEED here");
      mutex_enter (aq->aq_mtx);
      aqr->aqr_state = AQR_RUNNING;
      /* set the state inside the aq_mtx because it is tested with an or of queued and running and if this falls in the middle of this test, other thread can think it is neither queued nor running */
      mutex_leave (aq->aq_mtx);
      /* with privs of te owner of the aq being served */
      aqt->aqt_cli->cli_user = aq->aq_user;
      CLI_SET_QUAL (aqt->aqt_cli, aq->aq_qualifier);
      memzero (&aqt->aqt_cli->cli_activity, sizeof (db_activity_t));
      aqr->aqr_dbg_thread = THREAD_CURRENT_THREAD;
      if (0 && aq->aq_anytime_started && aq->aq_anytime_started + aq->aq_anytime_timeout < approx_msec_real_time ())
	aqr->aqr_error = srv_make_new_error (SQL_ANYTIME, "AQANY", "Aq request anytimed before starting execution");
      else
	aqr->aqr_value = aqr->aqr_func (aqr->aqr_args, &aqr->aqr_error);
      aqr->aqr_debug = NULL;
      assert (aqt->aqt_thread->thr_sem->sem_entry_count == 0);
      if (aqt->aqt_cli->cli_clt) GPF_T1 ("aq thread returning is not supposed to have a clt, not even if served rec dfg, would been clrd");
      aqr->aqr_args = NULL;
      dk_free_box (aqt->aqt_cli->cli_cl_stack);
      aqt->aqt_cli->cli_cl_stack = NULL;
      if (QI_NO_SLICE != aqt->aqt_cli->cli_slice)
	cli_set_slice (aqt->aqt_cli, NULL, QI_NO_SLICE, NULL);
      if (!aq->aq_no_lt_enter)
	{
	  IN_TXN;
	  aqt->aqt_cli->cli_trx->lt_main_trx_no = aq->aq_main_trx_no;
	  aq_lt_leave (aqt->aqt_cli->cli_trx, aqr);
	  LEAVE_TXN;

	}
      aqt->aqt_cli->cli_activity.da_thread_time += rdtsc () - ts;
      aqr->aqr_activity = aqt->aqt_cli->cli_activity;
      memzero (&aqt->aqt_cli->cli_activity, sizeof (db_activity_t));
      mutex_enter (aq->aq_mtx);
      aqr->aqr_state = AQR_DONE;
      if (aq->aq_waiting)
	semaphore_leave (aq->aq_waiting->thr_sem);
      else if (aqr->aqr_waiting)
	semaphore_leave (aqr->aqr_waiting->thr_sem);
      aqt->aqt_aqr = aqr = basket_get (&aq->aq_queue);
      if (aqr)
	{
	  mutex_leave (aq->aq_mtx);
	  TC (tc_aq_from_queue);
	  continue;
	}
      aq->aq_n_threads--;
      if (aq->aq_deleted && !aq->aq_n_threads)
	{
	  mutex_leave (aq->aq_mtx);
	  dk_free_box (aq);
	  IN_AQ;
	}

      aqt->aqt_aqr = aqr = aqt_other_aq (aqt);
      if (aqr)
	{
	  LEAVE_AQ;
	  TC (tc_aq_from_other);
	  continue;
	}
      LEAVE_AQ;
      TC (tc_aq_sleep);
      resource_store (aq_threads, (void *) aqt);
      semaphore_enter (self->thr_sem);
    }
}


aq_thread_t *
aqt_allocate ()
{
  if (aq_n_threads >= aq_max_threads)
    return NULL;
  aq_n_threads++;
  {
    dk_thread_t *thr;
    dk_session_t *ses = dk_session_allocate (SESCLASS_TCPIP);
    client_connection_t *cli = client_connection_create ();
    NEW_VARZ (aq_thread_t, aqt);
    aqt->aqt_cli = cli;
    aqt->aqt_cli->cli_session = ses;
    DKS_DB_DATA (ses) = cli;
    IN_TXN;
    cli_set_new_trx_no_wait_cpt (cli);
    LEAVE_TXN;
    thr = PrpcThreadAllocate ((init_func) aq_thread_func, http_thread_sz, (void *) aqt);
    if (!thr)
      {
	IN_TXN;
	lt_done (cli->cli_trx);
	LEAVE_TXN;
	client_connection_free (cli);
	PrpcSessionFree (ses);	/* not a box and not free in freeing cli */
	dk_free (aqt, sizeof (aq_thread_t));
	return NULL;
      }
    aqt->aqt_thread = thr->dkt_process;
    return aqt;
  }
}


void
aqr_call_w_ctx (aq_request_t * aqr)
{
  client_connection_t *cli = GET_IMMEDIATE_CLIENT_OR_NULL;
  async_queue_t *aq = aqr->aqr_aq;
  aq_request_t *old_aqr = cli->cli_aqr;
  int old_nt = cli->cli_non_txn_insert;
  int old_ntrig = cli->cli_no_triggers;
  int old_ac = cli->cli_row_autocommit;
  cl_aq_ctx_t *old_claq = cli->cli_claq;
  cl_slice_t *old_csl = cli->cli_csl;
  int old_qfs = cli->cli_anytime_qf_started;
  cli->cli_aqr = aqr;
  cli->cli_no_triggers = aq->aq_no_triggers;
  cli->cli_row_autocommit = aq->aq_row_autocommit;
  cli->cli_non_txn_insert = aq->aq_non_txn_insert;
  aqr->aqr_dbg_thread = THREAD_CURRENT_THREAD;
  if (0 && aq->aq_anytime_started && aq->aq_anytime_started + aq->aq_anytime_timeout < approx_msec_real_time ())
    aqr->aqr_error = srv_make_new_error (SQL_ANYTIME, "AQANY", "Aq request anytimed before starting execution");
  else
    aqr->aqr_value = aqr->aqr_func (aqr->aqr_args, &aqr->aqr_error);
  cli->cli_row_autocommit = old_ac;
  cli->cli_no_triggers = old_ntrig;
  cli->cli_non_txn_insert = old_nt;
  cli->cli_claq = old_claq;
  cli->cli_aqr = old_aqr;
  cli->cli_anytime_qf_started = old_qfs;
  if (old_csl)
    {
      caddr_t err = NULL;
      cli_set_slice (cli, old_csl->csl_clm, old_csl->csl_id, &err);
      dk_free_tree (err);
    }
  else
    cli_set_slice (cli, NULL, QI_NO_SLICE, NULL);
}


int
aq_request (async_queue_t * aq, aq_func_t f, caddr_t args)
{
  aq_thread_t *aqt;
  NEW_VARZ (aq_request_t, aqr);
  aqr->aqr_aq = aq;
  mutex_enter (aq->aq_mtx);
  do
    {
      aqr->aqr_req_no = ++aq->aq_req_no;
    }
  while (0 == aqr->aqr_req_no || gethash ((void *) (ptrlong) aqr->aqr_req_no, aq->aq_requests));
  aqr->aqr_func = f;
  aqr->aqr_args = args;
  /*aqr->aqr_debug = BOX_ELEMENTS (args) ? (caddr_t)unbox (((caddr_t*)args)[0]) : NULL; */
  sethash ((void *) (ptrlong) aqr->aqr_req_no, aq->aq_requests, (void *) aqr);
  aqr->aqr_state = AQR_QUEUED;
  if (aq->aq_n_threads == aq->aq_max_threads || !aq_max_threads || aq->aq_queue_only)
    {
      aq->aq_queue_only = 0;
      basket_add (&aq->aq_queue, (void *) aqr);
      mutex_leave (aq->aq_mtx);
      return aqr->aqr_req_no;
    }
  aqt = (aq_thread_t *) resource_get (aq_threads);
  if (!aqt && !(aq->aq_no_lt_enter && wi_inst.wi_is_checkpoint_pending))
    aqt = aqt_allocate ();
  if (!aqt && !aq->aq_do_self_if_would_wait && 2 != aq->aq_need_own_thread)
    {
      client_connection_t *cli = GET_IMMEDIATE_CLIENT_OR_NULL;
      mutex_leave (aq->aq_mtx);
      dbg_printf (("aq execution on requesting thread\n"));
      if (cli->cli_clt || aq->aq_need_own_thread)
	sqlr_new_error ("42000", "CLAQN",
	    "aq request could not get its own thread on a cluster server thread. The request would not get an independent transaction and therefore cannot be started on the caller thread.   If the request does not require an independent transaction then specify the do self if would wait flag to the aq (flag value 1)");
      aqr_call_w_ctx (aqr);
      aqr->aqr_args = NULL;
      aqr->aqr_state = AQR_DONE;
      return aqr->aqr_req_no;
    }
  if (!aqt)
    {
      basket_add (&aq->aq_queue, (void *) aqr);
      mutex_leave (aq->aq_mtx);
      return aqr->aqr_req_no;
    }
  aqt->aqt_aq = aq;
  aqt->aqt_aqr = aqr;
  aq->aq_n_threads++;
  mutex_leave (aq->aq_mtx);
  semaphore_leave (aqt->aqt_thread->thr_sem);
  return aqr->aqr_req_no;
}

void
aq_check_duplicate (async_queue_t * aq, caddr_t val)
{
  IN_AQ;
  DO_HT (ptrlong, req_no, aq_request_t *, aqr, aq->aq_requests)
  {
#if 0
    if (AQR_DONE != aqr->aqr_state && val == aqr->aqr_debug)
      GPF_T1 ("double aq request");
#endif
  }
  END_DO_HT;
  LEAVE_AQ;
}


void
aqr_free (aq_request_t * aqr)
{
  assert (AQR_DONE == aqr->aqr_state);
  dk_free_tree (aqr->aqr_args);
  dk_free_tree (aqr->aqr_error);
  dk_free_tree (aqr->aqr_value);
  dk_free ((caddr_t) aqr, sizeof (aq_request_t));
}


int
aq_do_self (async_queue_t * aq, caddr_t * err_ret)
{
  client_connection_t *cli;
  uint64 ts;
  caddr_t leave_err = NULL;
  query_instance_t *qi;
  aq_request_t *aqr;
  if (!aq->aq_queue.bsk_count || aq->aq_need_own_thread)
    return 0;
  if (!aq->aq_wait_qi && !aq->aq_no_lt_enter)
    return 0;
  cli = sqlc_client ();
  aqr = basket_get (&aq->aq_queue);
  mutex_leave (aq->aq_mtx);
  ts = rdtsc ();
  if (aq->aq_no_lt_enter)
    {
      aqr->aqr_dbg_thread = THREAD_CURRENT_THREAD;
      aqr->aqr_value = aqr->aqr_func (aqr->aqr_args, &aqr->aqr_error);
      if (cli)
	cli->cli_activity.da_thread_time += rdtsc () - ts;
      aqr->aqr_args = NULL;
      aqr->aqr_state = AQR_DONE;
      mutex_enter (aq->aq_mtx);
      return 1;
    }
  qi = aq->aq_wait_qi;
  vdb_leave_lt (qi->qi_trx, &leave_err);
  if (leave_err)
    {
      *err_ret = leave_err;
      vdb_enter_lt_1 (qi->qi_trx, err_ret, 1);
      IN_AQ;
      return 0;
    }
  aqr_call_w_ctx (aqr);
  aqr->aqr_args = NULL;
  aqr->aqr_state = AQR_DONE;
  if (aqr->aqr_error)
    {
      *err_ret = aqr->aqr_error;
      aqr->aqr_error = NULL;
    }
  vdb_enter_lt_1 (qi->qi_trx, err_ret, 1);
  mutex_enter (aq->aq_mtx);
  return *err_ret ? 0 : 1;
}


void
cli_aqr_add (client_connection_t * cli, aq_request_t * aqr)
{
  /* add up the exec stats and clutsre enlist forward */
  if (!cli)
    return;
  da_add (&cli->cli_activity, &aqr->aqr_activity);
}


caddr_t
aq_wait (async_queue_t * aq, int req_no, caddr_t * err, int wait)
{
  int64 wait_start;
  client_connection_t *cli = aq->aq_wait_qi ? aq->aq_wait_qi->qi_client : NULL;
  caddr_t val;
  aq_request_t *aqr;
  mutex_enter (aq->aq_mtx);
check_wait:
  aqr = gethash ((void *) (ptrlong) req_no, aq->aq_requests);
  if (!aqr)
    {
      mutex_leave (aq->aq_mtx);
      *err = AQ_NO_REQUEST;
      return (caddr_t) AQ_NO_REQUEST;
    }
  assert (AQR_DONE == aqr->aqr_state || AQR_RUNNING == aqr->aqr_state || AQR_QUEUED == aqr->aqr_state);
  if (AQR_RUNNING == aqr->aqr_state || AQR_QUEUED == aqr->aqr_state)
    {
      if (wait)
	{
	  if (aq_do_self (aq, err))
	    goto check_wait;
	  if (*err)
	    {
	      mutex_leave (aq->aq_mtx);
	      return NULL;
	    }
	  aqr->aqr_waiting = THREAD_CURRENT_THREAD;
	  mutex_leave (aq->aq_mtx);
	  wait_start = rdtsc ();
	  semaphore_enter (THREAD_CURRENT_THREAD->thr_sem);
	  if (cli)
	    cli->cli_activity.da_thread_time -= rdtsc () - wait_start;
	  mutex_enter (aq->aq_mtx);
	  if (!remhash ((void *) (ptrlong) req_no, aq->aq_requests))
	    GPF_T1 ("aqr was not in ar_requests for remove.");
	  mutex_leave (aq->aq_mtx);
	  val = aqr->aqr_value;
	  *err = aqr->aqr_error;
	  aqr->aqr_error = NULL;
	  aqr->aqr_value = NULL;
	  if (cli)
	    cli_aqr_add (cli, aqr);
	  aqr_free (aqr);
	  return val;
	}
      else
	{
	  mutex_leave (aq->aq_mtx);
	  *err = (caddr_t) AQR_RUNNING;
	  return (caddr_t) AQR_RUNNING;
	}
    }
  val = aqr->aqr_value;
  *err = aqr->aqr_error;
  aqr->aqr_error = NULL;
  if (cli)
    cli_aqr_add (cli, aqr);
  aqr->aqr_value = NULL;
  if (!remhash ((void *) (ptrlong) req_no, aq->aq_requests))
    GPF_T1 ("aqr not in aq_requests for remove");
  aqr_free (aqr);
  mutex_leave (aq->aq_mtx);
  return val;
}


caddr_t
aq_wait_any (async_queue_t * aq, caddr_t * err_ret, int wait, int *req_no_ret)
{
  client_connection_t *cli = aq->aq_wait_qi ? aq->aq_wait_qi->qi_client : NULL;
  IN_AQ;
check_wait:
  DO_HT (ptrlong, req_no, aq_request_t *, aqr, aq->aq_requests)
  {
    if (AQR_DONE == aqr->aqr_state)
      {
	caddr_t val = aqr->aqr_value;
	*err_ret = aqr->aqr_error;
	aqr->aqr_error = NULL;
	*req_no_ret = req_no;
	remhash ((void *) (ptrlong) aqr->aqr_req_no, aq->aq_requests);
	LEAVE_AQ;
	if (cli)
	  cli_aqr_add (cli, aqr);
	dk_free ((caddr_t) aqr, sizeof (aq_request_t));
	return val;
      }
  }
  END_DO_HT;
  if (wait)
    {
      if (aq_do_self (aq, err_ret))
	goto check_wait;
      if (*err_ret)
	{
	  LEAVE_AQ;
	  return NULL;
	}
      aq->aq_waiting = THREAD_CURRENT_THREAD;
      LEAVE_AQ;
      semaphore_enter (THREAD_CURRENT_THREAD->thr_sem);
      IN_AQ;
      goto check_wait;
    }
  else
    {
      LEAVE_AQ;
      *err_ret = (caddr_t) AQR_RUNNING;
      return (caddr_t) AQR_RUNNING;
    }
}


int aq_wait_last_first = 0;

caddr_t
aq_wait_all_1 (async_queue_t * aq, caddr_t * err_ret)
{
  caddr_t v, err = NULL;
  int waited;
  client_connection_t *cli = aq->aq_wait_qi ? aq->aq_wait_qi->qi_client : NULL;
  dk_hash_iterator_t hit;
  ptrlong req_no;
  aq_request_t *aqr;
  mutex_enter (aq->aq_mtx);
  if (aq_wait_last_first && aq->aq_queue.bsk_data.longval)
    {
      aq_request_t *last = aq->aq_queue.bsk_prev->bsk_data.ptrval;
      if (last && AQR_DONE != last->aqr_state)
	{
	  int last_req = last->aqr_req_no;
	  LEAVE_AQ;
	  v = aq_wait (aq, last_req, &err, 1);
	  dk_free_tree (v);
	  if (err_ret && err)
	    {
	      *err_ret = err;
	      return NULL;
	    }
	  dk_free_tree (err);
	  IN_AQ;
	}
    }
  do
    {
      dk_hash_iterator (&hit, aq->aq_requests);
      waited = 0;
      while (dk_hit_next (&hit, (void **) &req_no, (void **) &aqr))
	{
	  err = NULL;
	  if (AQR_DONE == aqr->aqr_state)
	    {
	      if (cli)
		{
		  cli_aqr_add (cli, aqr);
		  memzero (&aqr->aqr_activity, sizeof (db_activity_t));
		}
	      if (aqr->aqr_error && err_is_anytime (aqr->aqr_error))
		{
		  /* anytime termination does not stop the waiting.  The fact of anytime termination appears in the cli_activity of the waiting cli */
		  dk_free_tree (aqr->aqr_error);
		  aqr->aqr_error = NULL;
		}
	      if (aqr->aqr_error && err_ret)
		{
		  *err_ret = aqr->aqr_error;
		  aqr->aqr_error = NULL;
		  mutex_leave (aq->aq_mtx);
		  return NULL;
		}
	      continue;
	    }
	  mutex_leave (aq->aq_mtx);
	  err = NULL;
	  v = aq_wait (aq, (int) req_no, &err, 1);
	  dk_free_tree (v);
	  if (err && err_is_anytime (err))
	    {
	      dk_free_tree (err);
	      err = NULL;
	    }
	  if (err_ret && err)
	    {
	      *err_ret = err;
	      return NULL;
	    }
	  dk_free_tree (err);
	  waited = 1;
	  mutex_enter (aq->aq_mtx);
	  break;
	}
    }
  while (waited);
  if (aq->aq_queue.bsk_count)
    GPF_T1 ("aq wait all should have empty queue after waiting for all");
  dk_hash_iterator (&hit, aq->aq_requests);
  while (dk_hit_next (&hit, (void **) &req_no, (void **) &aqr))
    {
      if (AQR_DONE != aqr->aqr_state)
	GPF_T1 ("aqr supposed to be done after all have been waited for");
      aqr_free (aqr);
    }
  clrhash (aq->aq_requests);
  mutex_leave (aq->aq_mtx);
  return NULL;
}


#define AQ_WAIT_BATCH 100

caddr_t
aq_wait_all (async_queue_t * aq, caddr_t * err_ret)
{
  caddr_t v, err = NULL;
  client_connection_t *cli = aq->aq_wait_qi ? aq->aq_wait_qi->qi_client : NULL;
  aq_request_t *aqrs[AQ_WAIT_BATCH];
  dk_hash_iterator_t hit;
  ptrlong req_no;
  aq_request_t *aqr;
  int is_err = 0;
  IN_AQ;
  if (aq_wait_last_first && aq->aq_queue.bsk_data.longval)
    {
      aq_request_t *last = aq->aq_queue.bsk_prev->bsk_data.ptrval;
      if (last && AQR_DONE != last->aqr_state)
	{
	  int last_req = last->aqr_req_no;
	  LEAVE_AQ;
	  v = aq_wait (aq, last_req, &err, 1);
	  dk_free_tree (v);
	  if (err_ret && err)
	    {
	      *err_ret = err;
	      return NULL;
	    }
	  dk_free_tree (err);
	  IN_AQ;
	}
    }
  for (;;)
    {
      uint32 fill = 0, best = 0, inx;
      dk_hash_iterator (&hit, aq->aq_requests);

      while (dk_hit_next (&hit, (void **) &req_no, (void **) &aqr))
	{
	  if (req_no != aqr->aqr_req_no)
	    GPF_T1 ("aqr req no not as in aq_requests");
	  if (AQR_DONE == aqr->aqr_state)
	    {
	      aqrs[fill++] = aqr;
	      if (fill >= AQ_WAIT_BATCH)
		break;
	    }
	  else
	    {
	      if ((uint32) aqr->aqr_req_no > best)
		{
		  best = aqr->aqr_req_no;
		}
	    }
	}
      LEAVE_AQ;
      if (best)
	{
	  v = aq_wait (aq, best, &err, 1);
	  dk_free_tree (v);
	  if (err && err_is_anytime (err))
	    {
	      dk_free_tree (err);
	      err = NULL;
	    }
	  if (err_ret && err)
	    {
	      *err_ret = err;
	      return NULL;
	    }
	  dk_free_tree (err);
	  err = NULL;
	}
      for (inx = 0; inx < fill; inx++)
	{
	  aq_request_t *aqr = aqrs[inx];
	  if (cli)
	    {
	      cli_aqr_add (cli, aqr);
	      memzero (&aqr->aqr_activity, sizeof (db_activity_t));
	    }
	  if (aqr->aqr_error && err_is_anytime (aqr->aqr_error))
	    {
	      /* anytime termination does not stop the waiting.  The fact of anytime termination appears in the cli_activity of the waiting cli */
	      dk_free_tree (aqr->aqr_error);
	      aqr->aqr_error = NULL;
	    }
	  if (aqr->aqr_error && err_ret)
	    {
	      *err_ret = aqr->aqr_error;
	      aqr->aqr_error = NULL;
	      is_err = 1;
	      fill = inx + 1;
	    }
	  err = NULL;
	  aqrs[inx] = (aq_request_t *) (ptrlong) aqr->aqr_req_no;
	  aqr_free (aqr);
	  if (is_err)
	    break;
	}
      IN_AQ;
      for (inx = 0; inx < fill; inx++)
	{
	  if (!remhash ((void *) aqrs[inx], aq->aq_requests))
	    GPF_T1 ("bad req no for remhash in aq wait all");
	}
      if (is_err)
	{
	  LEAVE_AQ;
	  return NULL;
	}
      if (!best && fill < AQ_WAIT_BATCH)
	{
	  if (aq->aq_requests->ht_count || aq->aq_queue.bsk_count)
	    GPF_T1 ("aq supposed to be empty");
	  LEAVE_AQ;
	  return NULL;
	}
    }
}


async_queue_t *
aq_allocate (client_connection_t * cli, int n_threads)
{
  async_queue_t *aq = (async_queue_t *) dk_alloc_box_zero (sizeof (async_queue_t), DV_ASYNC_QUEUE);
  aq->aq_creator_cli = cli;
  aq->aq_ref_count = 1;
  aq->aq_requests = hash_table_allocate (101);
  aq->aq_mtx = all_aq_mtx;
#ifdef MTX_DEBUG
  aq->aq_requests->ht_required_mtx = aq->aq_mtx;
#endif
  aq->aq_cl_stack = (cl_call_stack_t *) box_copy ((caddr_t) cli->cli_cl_stack);
  aq->aq_main_trx_no = cli->cli_trx->lt_main_trx_no ? cli->cli_trx->lt_main_trx_no : cli->cli_trx->lt_trx_no;
  aq->aq_max_threads = n_threads;
  aq->aq_user = cli->cli_user;
  if (!aq->aq_user)
    aq->aq_user = sec_id_to_user (U_ID_DBA);
  aq->aq_qualifier = box_string (cli->cli_qualifier);
  aq->aq_row_autocommit = cli->cli_row_autocommit;
  aq->aq_no_triggers = cli->cli_no_triggers;
  aq->aq_replicate = box_copy_tree ((caddr_t) cli->cli_trx->lt_replicate);
  aq->aq_anytime_timeout = cli->cli_anytime_timeout;
  aq->aq_anytime_started = cli->cli_anytime_started;
  IN_AQ;
  sethash ((void *) aq, all_aqs, (void *) 1);
  LEAVE_AQ;
  return aq;
}


void
aqr_set_free (dk_set_t s)
{
  DO_SET (aq_request_t *, aqr, &s) aqr_free (aqr);
  END_DO_SET ();
  dk_set_free (s);
}

int
aq_free (async_queue_t * aq)
{
  dk_set_t aqrs = NULL;
  IN_AQ;
  if (!aq->aq_deleted)
    {
      aq->aq_ref_count--;
      if (aq->aq_ref_count)
	{
	  LEAVE_AQ;
	  return 1;
	}
      if (aq->aq_n_threads)
	{
	  aq_request_t *aqr;
	  while ((aqr = (aq_request_t *) basket_get (&aq->aq_queue)))
	    {
	      remhash ((void *) (ptrlong) aqr->aqr_req_no, aq->aq_requests);
	      aqr->aqr_state = AQR_DONE;
	      dk_set_push (&aqrs, (void *) aqr);
	    }
	  aq->aq_deleted = 1;
	  LEAVE_AQ;
	  /* free the reqs outside of mtx, args can have qis with aqs inside */
	  aqr_set_free (aqrs);
	  return 1;
	}
    }
  {
    dk_hash_iterator_t hit;
    aq_request_t *aqr;
    void *reqno;
    while (basket_get (&aq->aq_queue))
      ;
    dk_hash_iterator (&hit, aq->aq_requests);
    while (dk_hit_next (&hit, &reqno, (void **) &aqr))
      {
	aqr->aqr_state = AQR_DONE;
	dk_set_push (&aqrs, (void *) aqr);
      }
  }
  remhash ((void *) aq, all_aqs);
  LEAVE_AQ;
  aqr_set_free (aqrs);

#ifdef MTX_DEBUG
  aq->aq_requests->ht_required_mtx = NULL;
#endif
  hash_table_free (aq->aq_requests);
  dk_free_tree (aq->aq_qualifier);
  dk_free_box ((caddr_t) aq->aq_cl_stack);
  return 0;
}


async_queue_t *
aq_copy (async_queue_t * aq)
{
  aq->aq_ref_count++;
  return aq;
}


async_queue_t *
bif_aq_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp != DV_ASYNC_QUEUE)
    sqlr_new_error ("22023", "SR002",
	"Function %s needs an async queue as argument %d, not an arg of type %s (%d)", func, nth + 1, dv_type_title (dtp), dtp);
  return (async_queue_t *) arg;
}


caddr_t
bif_async_queue (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  QNCAST (query_instance_t, qi, qst);
  long n = bif_long_arg (qst, args, 0, "async_queue");
  int flags = BOX_ELEMENTS (args) > 1 ? bif_long_arg (qst, args, 1, "async_queue") : 0;
  async_queue_t *aq = aq_allocate (qi->qi_client, n);
  if (CL_RUN_CLUSTER == cl_run_local_only && !(AQ_DO_SELF_IF_WAIT & flags))
    flags |= AQ_SEPARATE_TXN;
  if (AQ_SEPARATE_TXN & flags)
    {
      aq->aq_need_own_thread = 1;
      aq->aq_main_trx_no = 0;
      flags &= ~AQ_DO_SELF_IF_WAIT;
    }
  if (flags & AQ_DO_SELF_IF_WAIT)
    {
      if (qi->qi_client->cli_clt && !qi->qi_client->cli_cl_stack)
	sqlr_new_error ("42000", "CLAQN",
	    "May not create a do self if would wait aq on a cluster server thread after cl_detach_thread ()");
      aq->aq_do_self_if_would_wait = 1;
    }
  if (AQ_TXN_BRANCH & flags)
    {
      aq->aq_rc_w_id = LT_MAIN_W_ID (qi->qi_client->cli_trx);
      qi->qi_client->cli_trx->lt_has_branches = 1;
      lt_timestamp (qi->qi_trx, (char *) &aq->aq_lt_timestamp);
    }
  if (!(flags & AQ_CLUSTER_RECURSIVE))
    {
      dk_free_box ((caddr_t) aq->aq_cl_stack);
      aq->aq_cl_stack = NULL;
    }
  if (srv_have_global_lock (THREAD_CURRENT_THREAD))
    aq->aq_max_threads = 0;	/* run on same thread in atomic */
  aq->aq_ts = get_msec_real_time ();
  return (caddr_t) aq;
}


caddr_t
aq_sql_func (caddr_t * av, caddr_t * err_ret)
{
  du_thread_t *self = THREAD_CURRENT_THREAD;
  caddr_t val = NULL;
  caddr_t *args = (caddr_t *) av;
  caddr_t fn = args[0];
  caddr_t *params = (caddr_t *) args[1];
  client_connection_t *cli = GET_IMMEDIATE_CLIENT_OR_NULL;
  caddr_t full_name = sch_full_proc_name (wi_inst.wi_schema, fn,
      cli_qual (cli), CLI_OWNER (cli));
  query_t *proc = full_name ? sch_proc_def (wi_inst.wi_schema, full_name) : NULL;
  dk_free_box (av);
  dk_free_box (fn);
  if (!proc)
    {
      dk_free_tree ((caddr_t) params);
      *err_ret = srv_make_new_error ("42001", "AQ...", "undefined procedure in aq %s", full_name ? full_name : "<no name>");
      return NULL;
    }
  if (proc->qr_to_recompile)
    {
      *err_ret = NULL;
      proc = qr_recompile (proc, err_ret);
      if (*err_ret)
	{
	  dk_free_tree ((caddr_t) params);
	  return NULL;
	}
    }
  if (!cli->cli_user || !sec_proc_check (proc, cli->cli_user->usr_id, cli->cli_user->usr_g_id))
    {
      user_t * usr = cli->cli_user;
      *err_ret = srv_make_new_error ("42000", "SR186:SECURITY", "No permission to execute %s in aq_request() with user ID %d, group ID %d",
        full_name, (int)(usr ? usr->usr_id : 0), (int)(usr ? usr->usr_g_id : 0) );
      dk_free_tree ((caddr_t) params);
      return NULL;
    }
  DO_SET (state_slot_t *, ssl, &proc->qr_parms)
  {
    if (SSL_REF_PARAMETER == ssl->ssl_type)
      {
	  *err_ret = srv_make_new_error ("42000", "AQ002", "Reference parameters not allowed in aq_request()");
	dk_free_tree ((caddr_t) params);
	return NULL;
      }
  }
  END_DO_SET ();
  *err_ret = qr_exec (cli, proc, CALLER_LOCAL, NULL, NULL, NULL, params, NULL, 0);
  dk_free_box ((caddr_t) params);
  val = self->thr_func_value;
  self->thr_func_value = NULL;
  return val;
}


caddr_t
bif_aq_request (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  async_queue_t *aq = bif_aq_arg (qst, args, 0, "aq_request");
  caddr_t f = bif_string_arg (qst, args, 1, "aq_request");
  caddr_t f_args = bif_strict_array_or_null_arg (qst, args, 2, "aq_request");
  caddr_t unsafe_subtree;
  caddr_t aq_args;
#ifdef NO_AQ_ATOMIC
  if (0 != server_lock.sl_count)
    sqlr_new_error ("22023", "SR567", "Function aq_request() can not be used inside atomic section");
#endif
  if (!f_args)
    sqlr_new_error ("42000", "AQ001", "Must have arguments for aq_request()");
  unsafe_subtree = box_find_mt_unsafe_subtree (f_args);
  if (NULL != unsafe_subtree)
    {
      dtp_t dtp = DV_TYPE_OF (unsafe_subtree);
      sqlr_new_error ("42000", "AQ004",
	  "Arguments for aq_request() contain data of type %s (%d) that can not be sent between server threads",
	  dv_type_title (dtp), dtp);
    }
  f_args = box_copy_tree (f_args);
  box_make_tree_mt_safe (f_args);
  aq_args = list (2, box_copy (f), f_args);
  return box_num (aq_request (aq, (aq_func_t) aq_sql_func, (caddr_t) aq_args));
}


caddr_t
bif_aq_request_zap_args (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  async_queue_t *aq = bif_aq_arg (qst, args, 0, "aq_request_zap_args");
  caddr_t f = bif_string_arg (qst, args, 1, "aq_request_zap_args");
  int aq_argctr, aq_argcount = BOX_ELEMENTS (args) - 2;
  caddr_t *f_args;
  caddr_t aq_args;
#ifdef NO_AQ_ATOMIC
  if (0 != server_lock.sl_count)
    sqlr_new_error ("22023", "SR567", "Function aq_request() can not be used inside atomic section");
#endif
  for (aq_argctr = 0; aq_argctr < aq_argcount; aq_argctr++)
    {
      caddr_t unsafe_subtree = box_find_mt_unsafe_subtree (bif_arg (qst, args, aq_argctr + 2, "aq_request_zap_args"));
      if (NULL != unsafe_subtree)
	{
	  dtp_t dtp = DV_TYPE_OF (unsafe_subtree);
	  sqlr_new_error ("42000", "AQ004",
	      "Argument %d for aq_request_zap_args() contain data of type %s (%d) that can not be sent between server threads",
	      aq_argctr + 2, dv_type_title (dtp), dtp);
	}
    }
  f_args = (caddr_t *) dk_alloc_box_zero (aq_argcount * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  for (aq_argctr = 0; aq_argctr < aq_argcount; aq_argctr++)
    {
      qst_swap_or_get_copy (qst, args[aq_argctr + 2], f_args + aq_argctr);
      box_make_tree_mt_safe (f_args[aq_argctr]);
    }
  aq_args = list (2, box_copy (f), f_args);
  return box_num (aq_request (aq, (aq_func_t) aq_sql_func, (caddr_t) aq_args));
}


caddr_t
bif_aq_wait (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  async_queue_t *aq = bif_aq_arg (qst, args, 0, "aq_wait");
  long req = bif_long_arg (qst, args, 1, "aq_wait");
  long wait = bif_long_arg (qst, args, 2, "aq_wait");
  caddr_t err = NULL;
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t val = NULL;
#ifdef NO_AQ_ATOMIC
  if (0 != server_lock.sl_count)
    sqlr_new_error ("22023", "SR568", "Function aq_wait() can not be used inside atomic section");
#endif
  if (!aq->aq_rc_w_id && lt_has_locks (qi->qi_trx))
    sqlr_new_error ("40010", "AQ003", "Not allowed to wait for AQ while holding locks");
  if (aq->aq_do_self_if_would_wait)
    aq->aq_wait_qi = qi;
  IO_SECT (qst);
  val = aq_wait (aq, req, &err, wait);
  aq->aq_wait_qi = NULL;
  END_IO_SECT (err_ret);
  if (*err_ret)
    {
#ifdef DEBUG
      printf ("aq_wait () has got error %s %s\n", ERR_STATE (err_ret[0]), ERR_MESSAGE (err_ret[0]));
#endif
      dk_free_tree (val);
      return NULL;
    }
  if (BOX_ELEMENTS (args) > 3 && ssl_is_settable (args[3]))
    qst_set (qst, args[3], err);
  else
    dk_free_tree (err);
  return val;
}


void
aq_wait_all_in_qi (async_queue_t * aq, caddr_t * inst, caddr_t * err_ret, aq_cleanup_t clup)
{
  QNCAST (QI, qi, inst);
  caddr_t err = NULL, err2 = NULL, err1 = NULL;
  vdb_enter_lt_1 (qi->qi_trx, &err1, 1);
  aq->aq_wait_qi = qi;
  aq_wait_all (aq, &err);
  aq->aq_wait_qi = NULL;
  if (err1)
    {
      dk_free_tree (err);
      err = err1;
    }
  if (err)
    {
      aq_request_t *aqr;
      IN_AQ;
      while ((aqr = basket_get (&aq->aq_queue)))
	{
	  if (clup)
	    clup (aqr->aqr_args);
	  aqr->aqr_state = AQR_DONE;
	}
      LEAVE_AQ;
      aq_wait_all (aq, NULL);
      if (aq->aq_n_threads)
	GPF_T1 ("aq wait for all finishes while aq has threads");
    }
  vdb_leave_lt (qi->qi_trx, &err2);
  if (err)
    *err_ret = err;
  else if (err2)
    *err_ret = err;
  aq->aq_no_more = 0;
}

caddr_t
bif_aq_wait_all (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t val = NULL;
  caddr_t err = NULL;
  async_queue_t *aq = bif_aq_arg (qst, args, 0, "aq_wait");
  long allow_locks = BOX_ELEMENTS (args) > 1 ? bif_long_arg (qst, args, 1, "aq_wait") : 0;
  query_instance_t *qi = (query_instance_t *) qst;
#ifdef NO_AQ_ATOMIC
  if (0 != server_lock.sl_count)
    sqlr_new_error ("22023", "SR569", "Function aq_wait_all() can not be used inside atomic section");
#endif
  if (!aq->aq_rc_w_id && !allow_locks && lt_has_locks (qi->qi_trx))
    sqlr_new_error ("40010", "AQ003", "Not allowed to wait for AQ while holding locks");
  IO_SECT (qst);
  aq->aq_wait_qi = qi;
  val = aq_wait_all (aq, &err);
  aq->aq_wait_qi = NULL;
  END_IO_SECT (err_ret);
#ifdef DEBUG
  if (*err_ret)
    printf ("aq_wait_all () has got error %s %s\n", ERR_STATE (err_ret[0]), ERR_MESSAGE (err_ret[0]));
#endif
  if (err)
    sqlr_resignal (err);
  return val;
}


caddr_t
bif_aq_queue_only (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  async_queue_t *aq = bif_aq_arg (qst, args, 0, "aq_wait");
  aq->aq_queue_only = 1;
  return NULL;
}

void
aq_serialize (caddr_t x, dk_session_t * ses)
{
  print_int (0, ses);
}

size_t dk_alloc_cache_total (void * cache);
void thr_alloc_cache_clear (thread_t * thr);

size_t 
aq_thr_mem_cache_total ()
{
  int i;
  size_t n = 0;
  resource_t * rc = aq_threads;
  if (!rc->rc_fill)
    return 0;
  mutex_enter (rc->rc_mtx);
  for (i = 0; i < rc->rc_fill; i++)
    {
      aq_thread_t * aqt = rc->rc_items[i];
      n += dk_alloc_cache_total (aqt->aqt_thread->thr_alloc_cache);
    }
  mutex_leave (rc->rc_mtx);
  return n;
}

void 
aq_thr_mem_cache_clear ()
{
  int i;
  resource_t * rc = aq_threads;
  if (!rc->rc_fill)
    return;
  mutex_enter (rc->rc_mtx);
  for (i = 0; i < rc->rc_fill; i++)
    {
      aq_thread_t * aqt = rc->rc_items[i];
      thr_alloc_cache_clear (aqt->aqt_thread);
    }
  mutex_leave (rc->rc_mtx);
}

void
bif_aq_init ()
{
  dk_mem_hooks (DV_ASYNC_QUEUE, (box_copy_f) aq_copy, (box_destr_f) aq_free, 0);
  PrpcSetWriter (DV_ASYNC_QUEUE, (ses_write_func) aq_serialize);
  bif_define ("async_queue", bif_async_queue);
  bif_define ("aq_request", bif_aq_request);
  bif_define ("aq_request_zap_args", bif_aq_request_zap_args);
  bif_define ("aq_wait", bif_aq_wait);
  bif_set_uses_index (bif_aq_wait);
  bif_define ("aq_wait_all", bif_aq_wait_all);
  bif_set_uses_index (bif_aq_wait_all);
  bif_define ("aq_queue_only", bif_aq_queue_only);
  aq_threads = resource_allocate (aq_max_threads, NULL, NULL, NULL, 0);
  all_aq_mtx = mutex_allocate ();
  mutex_option (all_aq_mtx, "AQ", NULL, NULL);
  all_aqs = hash_table_allocate (11);
  HT_REQUIRE_MTX (all_aqs, all_aq_mtx);
}

/*
 *  $Id$
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
int aq_max_threads = 10;

int aq_free (async_queue_t * aq);

long tc_aq_from_queue;

void
aq_lt_leave (lock_trx_t * lt, aq_request_t * aqr)
{
  int lte = lt->lt_error;
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
      async_queue_t *aq = aqt->aqt_aq;
      aq_request_t *aqr = aqt->aqt_aqr;
      assert (AQR_QUEUED == aqr->aqr_state);
      lt_enter_anyway (aqt->aqt_cli->cli_trx);
      if (IS_BOX_POINTER (aqt->aqt_cli->cli_trx->lt_replicate))
	dk_free_tree (aqt->aqt_cli->cli_trx->lt_replicate);
      aqt->aqt_cli->cli_trx->lt_replicate = REPL_LOG;
      aqt->aqt_cli->cli_row_autocommit = 0;
      if (AQR_QUEUED != aqr->aqr_state)
	GPF_T1 ("aqr_state is supposed to be AQR_QUEUEED here");
      mutex_enter (aq->aq_mtx);
      aqr->aqr_state = AQR_RUNNING;
      /* set the state inside the aq_mtx because it is tested with an or of queued and running and if this falls in the middle of this test, other thread can think it is neither queued nor running */
      mutex_leave (aq->aq_mtx);
      /* with privs of te owner of the aq being served */
      aqt->aqt_cli->cli_user = aq->aq_user;
      CLI_SET_QUAL (aqt->aqt_cli, aq->aq_qualifier);
      aqr->aqr_value = aqr->aqr_func (aqr->aqr_args, &aqr->aqr_error);
      assert (aqt->aqt_thread->thr_sem->sem_entry_count == 0);
      aqr->aqr_args = NULL;
      IN_TXN;
      aq_lt_leave (aqt->aqt_cli->cli_trx, aqr);
      LEAVE_TXN;

      mutex_enter (aq->aq_mtx);
      aqr->aqr_state = AQR_DONE;
      if (aqr->aqr_waiting)
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
	}
      else
	mutex_leave (aq->aq_mtx);
      TC (tc_aq_sleep);
      resource_store (aq_threads, (void *) aqt);
      semaphore_enter (self->thr_sem);
    }
}


aq_thread_t *
aqt_allocate (lock_trx_t * lt)
{
  if (aq_n_threads >= aq_max_threads)
    return NULL;
  aq_n_threads++;
  vdb_enter_lt (lt);
  {
    dk_thread_t *thr;
    dk_session_t *ses = dk_session_allocate (SESCLASS_TCPIP);
    client_connection_t *cli = client_connection_create ();
    NEW_VARZ (aq_thread_t, aqt);
    aqt->aqt_cli = cli;
    aqt->aqt_cli->cli_session = ses;
    DKS_DB_DATA (ses) = cli;
    IN_TXN;
    cli_set_new_trx (cli);
    LEAVE_TXN;
    vdb_leave_lt (lt, NULL);
    thr = PrpcThreadAllocate ((init_func) aq_thread_func, http_thread_sz, (void *) aqt);
    if (!thr)
      {
	IN_TXN;
	lt_done (cli->cli_trx);
	LEAVE_TXN;
	client_connection_free (cli);
	dk_free_tree (ses);
	dk_free (aqt, sizeof (aq_thread_t));
	return NULL;
      }
    aqt->aqt_thread = thr->dkt_process;
    return aqt;
  }
}


int
aq_request (async_queue_t * aq, aq_func_t f, caddr_t args, lock_trx_t * lt)
{
  int rc;
  client_connection_t * cli = NULL;
  aq_thread_t *aqt;
  NEW_VARZ (aq_request_t, aqr);
  mutex_enter (aq->aq_mtx);
  aqr->aqr_req_no = aq->aq_req_no++;
  aqr->aqr_func = f;
  aqr->aqr_args = args;
  sethash ((void *) (ptrlong) aqr->aqr_req_no, aq->aq_requests, (void *) aqr);
  aqr->aqr_state = AQR_QUEUED;
  if (aq->aq_n_threads == aq->aq_max_threads)
    {
      basket_add (&aq->aq_queue, (void *) aqr);
      mutex_leave (aq->aq_mtx);
      return aqr->aqr_req_no;
    }
  aqt = (aq_thread_t *) resource_get (aq_threads);
  if (!aqt)
    {
      aqt = aqt_allocate (lt);
    }
  if (!aqt)
    {
      mutex_leave (aq->aq_mtx);
      cli = GET_IMMEDIATE_CLIENT_OR_NULL;
      dbg_printf (("aq execution on requesting thread\n"));
      aqr->aqr_value = aqr->aqr_func (aqr->aqr_args, &aqr->aqr_error);
      aqr->aqr_args = NULL;
      aqr->aqr_state = AQR_DONE;
      IN_TXN;
      rc = lt_commit (cli->cli_trx, TRX_CONT);
      LEAVE_TXN;
      if (rc != LTE_OK)
	{
	  caddr_t err;
	  MAKE_TRX_ERROR (rc, err, LT_ERROR_DETAIL (cli->cli_trx));
	  sqlr_resignal (err);
	}
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
aqr_free (aq_request_t * aqr)
{
  assert (AQR_DONE == aqr->aqr_state);
  dk_free_tree (aqr->aqr_args);
  dk_free_tree (aqr->aqr_value);
  dk_free_tree (aqr->aqr_error);
  dk_free ((caddr_t) aqr, sizeof (aq_request_t));
}


caddr_t
aq_wait (async_queue_t * aq, int req_no, caddr_t * err, int wait)
{
  caddr_t val;
  aq_request_t *aqr;
  mutex_enter (aq->aq_mtx);
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
	  aqr->aqr_waiting = THREAD_CURRENT_THREAD;
	  mutex_leave (aq->aq_mtx);
	  semaphore_enter (THREAD_CURRENT_THREAD->thr_sem);
	  mutex_enter (aq->aq_mtx);
	  if (!remhash ((void *) (ptrlong) req_no, aq->aq_requests))
	    GPF_T1 ("aqr was not in ar_requests for remove.");
	  mutex_leave (aq->aq_mtx);
	  val = aqr->aqr_value;
	  *err = aqr->aqr_error;
	  aqr->aqr_error = NULL;
	  aqr->aqr_value = NULL;
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
  aqr->aqr_value = NULL;
  if (!remhash ((void *) (ptrlong) req_no, aq->aq_requests))
    GPF_T1 ("aqr not in aq_requests for remove");
  aqr_free (aqr);
  mutex_leave (aq->aq_mtx);
  return val;
}


int aq_wait_last_first = 1;

caddr_t
aq_wait_all (async_queue_t * aq, caddr_t * err_ret)
{
  caddr_t v, err;
  int waited;
  dk_hash_iterator_t hit;
  ptrlong req_no;
  aq_request_t *aqr;
  mutex_enter (aq->aq_mtx);
  if (aq_wait_last_first && aq->aq_queue.bsk_data.longval)
    {
      aq_request_t * last = aq->aq_queue.bsk_prev->bsk_data.ptrval;
      if (last && AQR_DONE != last->aqr_state)
	{
	  int last_req = last->aqr_req_no;
	  mutex_leave (aq->aq_mtx);
	  v = aq_wait (aq, last_req, &err, 1);
	  dk_free_tree (v);
	  if (err_ret && err)
	    {
	      *err_ret = err;
	      return NULL;
	    }
	  dk_free_tree (err);
	  mutex_enter (aq->aq_mtx);
	}
    }
  do
    {
      dk_hash_iterator (&hit, aq->aq_requests);
      waited = 0;
      while (dk_hit_next (&hit, (void **) &req_no, (void **) &aqr))
	{
	  if (AQR_DONE == aqr->aqr_state)
	    {
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
	  v = aq_wait (aq, (int) req_no, &err, 1);
	  dk_free_tree (v);
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


async_queue_t *
aq_allocate (client_connection_t * cli, int n_threads)
{
  async_queue_t *aq = (async_queue_t *) dk_alloc_box_zero (sizeof (async_queue_t), DV_ASYNC_QUEUE);
  aq->aq_ref_count = 1;
  aq->aq_requests = hash_table_allocate (101);
  aq->aq_mtx = mutex_allocate ();
#ifdef MTX_DEBUG
  aq->aq_requests->ht_required_mtx = aq->aq_mtx;
#endif
  aq->aq_max_threads = n_threads;
  mutex_option (aq->aq_mtx, "AQ", NULL, NULL);
  aq->aq_user = cli->cli_user;
  aq->aq_qualifier = box_string (cli->cli_qualifier);
  return aq;
}


int
aq_free (async_queue_t * aq)
{
  mutex_enter (aq->aq_mtx);
  if (!aq->aq_deleted)
    {
      aq->aq_ref_count--;
      if (aq->aq_ref_count)
	{
	  mutex_leave (aq->aq_mtx);
	  return 1;
	}
      if (aq->aq_n_threads)
	{
	  aq_request_t *aqr;
	  while ((aqr = (aq_request_t *) basket_get (&aq->aq_queue)))
	    {
	      remhash ((void *) (ptrlong) aqr->aqr_req_no, aq->aq_requests);
	      aqr->aqr_state = AQR_DONE;
	      aqr_free (aqr);
	    }
	  aq->aq_deleted = 1;
	  mutex_leave (aq->aq_mtx);
	  return 1;
	}
    }
  {
    dk_hash_iterator_t hit;
    aq_request_t *aqr;
    void *reqno;
    dk_hash_iterator (&hit, aq->aq_requests);
    while (dk_hit_next (&hit, &reqno, (void **) &aqr))
      aqr_free (aqr);
  }
  mutex_leave (aq->aq_mtx);
#ifdef MTX_DEBUG
  aq->aq_requests->ht_required_mtx = NULL;
#endif
  hash_table_free (aq->aq_requests);
  dk_free_tree (aq->aq_qualifier);
  mutex_free (aq->aq_mtx);
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
  async_queue_t *aq = aq_allocate (qi->qi_client, n);
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
  if (!proc)
    {
      *err_ret = srv_make_new_error ("42001", "AQ...", "undefined procedure %.300s in aq_request()", full_name ? full_name : ((DV_STRING == DV_TYPE_OF (fn)) ? fn : "<no name>"));
      dk_free_box (fn);
      dk_free_tree ((caddr_t) params);
      return NULL;
    }
  dk_free_box (fn);
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
  if (!cli || !cli->cli_user)
    {
      *err_ret = srv_make_new_error ("42000", "AQ005", "Bad context to execute %.300s in aq_request(), like a log replay", full_name);
      dk_free_tree ((caddr_t) params);
      return NULL;
    }
  if (!sec_proc_check (proc, cli->cli_user->usr_id, cli->cli_user->usr_g_id))
    {
      *err_ret = srv_make_new_error ("42000", "SR186", "No permission to execute %.300s in aq_request(), user ID %ld, group ID %ld", full_name, (long)(cli->cli_user->usr_id), (long)(cli->cli_user->usr_g_id));
      dk_free_tree ((caddr_t) params);
      return NULL;
    }
  DO_SET (state_slot_t *, ssl, &proc->qr_parms)
    {
      if (SSL_REF_PARAMETER == ssl->ssl_type)
	{
	  *err_ret = srv_make_new_error ("42000", "AQ002", "Reference parameters not allowed in aq_request(), procedure %.300s", full_name);
	  dk_free_tree ((caddr_t) params);
	  return NULL;
	}
    }
  END_DO_SET();
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
  if (0 != server_lock.sl_count)
    sqlr_new_error ("22023", "SR567", "Function aq_request() can not be used inside atomic section");
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
  return box_num (aq_request (aq, (aq_func_t) aq_sql_func, (caddr_t) aq_args, ((query_instance_t*)qst)->qi_trx));
}


caddr_t
bif_aq_request_zap_args (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  async_queue_t *aq = bif_aq_arg (qst, args, 0, "aq_request_zap_args");
  caddr_t f = bif_string_arg (qst, args, 1, "aq_request_zap_args");
  int aq_argctr, aq_argcount = BOX_ELEMENTS (args) - 2;
  caddr_t *f_args;
  caddr_t aq_args;
  if (0 != server_lock.sl_count)
    sqlr_new_error ("22023", "SR567", "Function aq_request() can not be used inside atomic section");
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
  return box_num (aq_request (aq, (aq_func_t) aq_sql_func, (caddr_t) aq_args, ((query_instance_t*)qst)->qi_trx));
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
  if (0 != server_lock.sl_count)
    sqlr_new_error ("22023", "SR568", "Function aq_wait() can not be used inside atomic section");
  if (lt_has_locks (qi->qi_trx))
    sqlr_new_error ("40010", "AQ003", "Not allowed to wait for AQ while holding locks");
  IO_SECT (qst);
  val = aq_wait (aq, req, &err, wait);
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


caddr_t
bif_aq_wait_all (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t val = NULL;
  caddr_t err = NULL;
  async_queue_t *aq = bif_aq_arg (qst, args, 0, "aq_wait");
  long allow_locks = BOX_ELEMENTS (args) > 1 ? bif_long_arg (qst, args, 1, "aq_wait") : 0;
  query_instance_t *qi = (query_instance_t *) qst;
  if (0 != server_lock.sl_count)
    sqlr_new_error ("22023", "SR569", "Function aq_wait_all() can not be used inside atomic section");
  if (!allow_locks && lt_has_locks (qi->qi_trx))
    sqlr_new_error ("40010", "AQ003", "Not allowed to wait for AQ while holding locks");
  IO_SECT (qst);
  val = aq_wait_all (aq, &err);
  END_IO_SECT (err_ret);
#ifdef DEBUG
  if (*err_ret)
    printf ("aq_wait_all () has got error %s %s\n", ERR_STATE (err_ret[0]), ERR_MESSAGE (err_ret[0]));
#endif
  if (err)
    sqlr_resignal (err);
  return val;
}


void
aq_serialize (caddr_t x, dk_session_t * ses)
{
  print_int (0, ses);
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
  aq_threads = resource_allocate (20, NULL, NULL, NULL, 0);
}

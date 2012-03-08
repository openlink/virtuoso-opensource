/*
 *  2pc.c
 *
 *  $Id$
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

#include "Dk.h"
#include "Dk/Dksestcp.h"
#include "wi.h"
#include "odbcinc.h"

#include "sqlnode.h"
#include "sqlbif.h"
#include "sqlopcod.h"
#include "remote.h"
#include "CLI.h"
#include "repl.h"
#include "replsr.h"
#include "eqlcomp.h"

#include "2pc.h"
#include "2pc_client.h"

#include "msdtc.h"

/* initial count number for dtransact,
	 to be erased at checkpoint */
unsigned long dtransact_count = 0;

tp_queue_t *tp_main_queue = 0;

#if 0
#define _2pc_printf(x) log_info x
#endif

/* system vars */
const char *virt_tp_started = "STARTED";
const char *virt_tp_prepare_pending = "PREPARE_PENDING";
const char *virt_tp_prepared = "PREPARED";
const char *virt_tp_rollback_pending = "ROLLBACK_PENDING";
const char *virt_tp_rollbacked = "ROLLBACKED";
const char *virt_tp_commit_pending = "COMMIT_PENDING";
const char *virt_tp_committed = "COMMITTED";

const char *virt_rmt_enlisted = "ENLISTED";
const char *virt_rmt_prepare_pending = "PREPARE_PENDING";
const char *virt_rmt_prepared = "PREPARED";
const char *virt_rmt_rollback_pending = "ROLLBACK_PENDING";
const char *virt_rmt_rollbacked = "ROLLBACKED";
const char *virt_rmt_commit_pending = "COMMIT_PENDING";
const char *virt_rmt_committed = "COMMITTED";
/* to be moved */

int vd_use_mts = 0;

long fail_after_prepare = -1;

void lt_commit_schema_merge (lock_trx_t *);

static int cli_2pc_prepare (lock_trx_t * client);
static int cli_2pc_transact (lock_trx_t * client, int operation);

int tp_trx_enlist (struct rds_connection_s *rcon, query_instance_t * qi);
int tp_trx_exclude (lock_trx_t * lt, struct rds_connection_s *rcon);
int tp_trx_exclude_001 (lock_trx_t * lt, struct rds_connection_s *rcon);
int tp_trx_commit_1 (lock_trx_t * lt, int is_commit);
int tp_trx_commit_2 (caddr_t distr_trx, int is_commit);

int virt_recover_status (client_connection_t * cli, struct in_addr *addr,
    unsigned long port, unsigned long trx_id);
static void global_xa_init ();
void DoSQLError (SQLHDBC hdbc, SQLHSTMT hstmt);
char *virt_2pc_format_error_string (caddr_t err);

caddr_t
log_replay_entry (lock_trx_t * lt, dtp_t op, dk_session_t * in,
    int is_pushback);


/*
  xa persistent info
*/

txa_info_t txi;

txa_entry_t *txa_create_entry (void *xid, char *path, ptrlong offset,
    char *res);
void txa_free_entry (txa_entry_t * e);
caddr_t *txa_read_entries (int fd);
void txa_write_info (int fd, caddr_t * info);
txa_entry_t **txa_parse_entries (caddr_t * info);
void txa_add_entry (txa_entry_t * e);
caddr_t *txa_serialize (txa_entry_t ** ppe);
static int txa_open (char *file_name);
static int txa_write ();

/* default 2pc message processing functions */
static unsigned long
def_prepare_done (void *res, int trx_status)
{
  tp_future_t *future = (tp_future_t *) res;
  _2pc_printf (("prepare_done... %d\n", trx_status));
  future->ft_result = trx_status;
  semaphore_leave (future->ft_sem);
  return 0;
}
static unsigned long
def_commit_done (void *res, int trx_status)
{
  tp_future_t *future = (tp_future_t *) res;
  _2pc_printf (("commit_done... %d\n", trx_status));
  future->ft_result = trx_status;
  semaphore_leave (future->ft_sem);
  return 0;
}

static unsigned long
def_abort_done (void *res, int trx_status)
{
  tp_future_t *future = (tp_future_t *) res;
  if (res)
    {
      if (!future->ft_release)
	semaphore_leave (future->ft_sem);
      else			/* the other end marked to be release as it will not wait for it */
	{
	  semaphore_free (future->ft_sem);
	  dk_free (future, sizeof (tp_future_t));
	}
    }
  _2pc_printf (("abort_done... %d\n", trx_status));
  return 0;
}

static unsigned long virt_prepare_set_log (tp_data_t * tpd);

static unsigned long
def_prep_log (tp_message_t * mm)
{
  return virt_prepare_set_log (mm->mm_tp_data);
}

static unsigned long
xa_prep_log (tp_message_t * mm)
{
  tp_data_t *tpd = mm->mm_tp_data;
  box_t info = dk_alloc_box (box_length (tpd->tpd_trx_cookie), DV_BIN);
  memcpy (info, tpd->tpd_trx_cookie, box_length (info));
  tpd->cli_tp_lt->lt_2pc._2pc_log = info;
  return 0;
}


static queue_vtbl_t tp_vtbl = {
  def_prepare_done,
  def_commit_done,
  def_abort_done,
  def_prep_log
};
static queue_vtbl_t xa_tp_vtbl = {
  def_prepare_done,
  def_commit_done,
  def_abort_done,
  xa_prep_log
};

int d_trx_no = 0;

tp_queue_t *
tp_queue_init ()
{
  NEW_VARZ (tp_queue_t, mq);

  mq->mq_mutex = mutex_allocate ();
  mq->mq_semaphore = semaphore_allocate (0);

  return mq;
}

void
tp_queue_free (tp_queue_t * queue)
{
  if (!basket_is_empty (&queue->mq_basket))
    GPF_T1 ("not proper cycle of tp messages");
  mutex_free (queue->mq_mutex);
  semaphore_free (queue->mq_semaphore);
  dk_free (queue, sizeof (tp_queue_t));
}

void
mq_add_message (tp_queue_t * mq, void *message_v)
{
  tp_message_t *mm = (tp_message_t *) message_v;

  mutex_enter (mq->mq_mutex);
  basket_add (&mq->mq_basket, (void *) mm);
  mutex_leave (mq->mq_mutex);
  semaphore_leave (mq->mq_semaphore);
}

tp_message_t *
mq_create_message (int type, void *resource, void *client_v)
{
  client_connection_t *client = (client_connection_t *) client_v;
  NEW_VARZ (tp_message_t, mm);

  mm->mm_type = type;
  mm->mm_resource = (tp_future_t *)resource;
  mm->mm_trx = client->cli_trx;
  mm->mm_tp_data = client->cli_tp_data;
  mm->vtbl = &tp_vtbl;

  if (((TP_COMMIT == type) ||
	  (TP_ABORT == type)) && (fail_after_prepare == 0))
    {
      log_error ("raw_exit for 2PC recovery test");
      call_exit (0);
    }
  if (TP_PREPARE == type && fail_after_prepare > 0)
    {
      fail_after_prepare--;
    }

  return mm;
}

tp_message_t *
mq_create_xa_message (int type, void *resource, void *tp_data)
{
  tp_data_t *tpd = (tp_data_t *) tp_data;
  NEW_VARZ (tp_message_t, mm);

  mm->mm_type = type;
  mm->mm_resource = (tp_future_t *)resource;
  mm->mm_trx = tpd->cli_tp_lt;
  mm->mm_tp_data = tpd;
  mm->vtbl = &xa_tp_vtbl;

#ifdef DEBUG
  if (((TP_COMMIT == type) ||
	  (TP_ABORT == type)) && (fail_after_prepare == 0))
    {
      GPF_T1 ("asked fail for testing purposes\n");
    }
  if (TP_PREPARE == type && fail_after_prepare > 0)
    {
      fail_after_prepare--;
    }
#endif

  return mm;
}


long tc_initial_while_closing = 0;
long tc_initial_while_closing_died = 0;
long tc_client_dropped_connection = 0;
long tc_no_client_in_tp_data = 0;


static void
tp_free_cli_after_unenlist (client_connection_t * client,
    struct tp_data_s *tp_data)
{
  int free_after_unenlist;

  free_after_unenlist = tp_data->cli_free_after_unenlist;
  if (free_after_unenlist == CFAU_DIED)
    {
#ifndef NDEBUG
      tc_initial_while_closing_died++;
#endif
      _2pc_printf (("deferred client_died of the client connection %p",
	      client));
      srv_client_connection_died (client);
    }
}

#ifndef NDEBUG
unsigned long tp_2pc_commits = 0;
unsigned long tp_2pc_prepares = 0;
unsigned long tp_2pc_aborts = 0;
#endif

int
tp_message_hook (void *queue_v)
{
  tp_queue_t *queue = (tp_queue_t *) queue_v;
  for (;;)
    {
      tp_message_t *mm;
      client_connection_t *client;
      tp_data_t *tp_data;

      semaphore_enter (queue->mq_semaphore);
      mutex_enter (queue->mq_mutex);
      mm = (tp_message_t *) basket_get (&queue->mq_basket);
      mutex_leave (queue->mq_mutex);

      tp_data = mm->mm_tp_data;
      client = mm->mm_trx->lt_client;


      if (tp_data && tp_data->cli_trx_type == TP_XA_TYPE)
	goto ready;

#ifndef NDEBUG
      switch (mm->mm_type)
	{
	case TP_COMMIT:
	  tp_2pc_commits++;
	  break;
	case TP_PREPARE:
	  tp_2pc_prepares++;
	  break;
	case TP_ABORT:
	  tp_2pc_aborts++;
	  break;
	}
#endif

      if (!tp_data)
	{
#ifdef MQ_DEBUG
	  queue->mq_errors++;
#endif
#ifndef NDEBUG
	  tc_no_client_in_tp_data++;
#endif
	  goto free;
	};

      _2pc_printf (("got message %s %x %x", (mm->mm_type == TP_COMMIT) ?
	      "commit" : ((mm->mm_type == TP_PREPARE) ?
		  "prepare" : "abort"), client, tp_data->cli_tp_lt));

      IN_TXN;
      if (!tp_data->tpd_client_is_reset)
	{
	  if (client)
	    {
	      lock_trx_t *lt;

	      lt = client->cli_trx;
	      tp_data->cli_tp_lt = lt;
	      if (lt->lt_status == LT_CLOSING)
		GPF_T;

	      lt_log_debug (("lt_start lt=%x, thrs=%d st=%d\n",
		      tp_data->cli_tp_lt, tp_data->cli_tp_lt->lt_threads,
		      tp_data->cli_tp_lt->lt_status));
	      tp_data->tpd_last_act = mm->mm_type;
	      tp_data->cli_tp_lt->lt_2pc._2pc_type = tp_data->cli_trx_type;
	      tp_data->tpd_client_is_reset = 1;
	    }
	  else
	    {
	      _2pc_printf (("client dropped connection\n"));
	      dk_free (tp_data, sizeof (tp_data_t));
#ifdef MQ_DEBUG
	      queue->mq_errors++;
#endif
#ifndef NDEBUG
	      tc_client_dropped_connection++;
#endif
	      LEAVE_TXN;
	      goto free;
	    }
	}

      LEAVE_TXN;
    ready:
      if (tp_data->cli_tp_enlisted == CONNECTION_LOCAL)
	{
	  lt_log_debug (("tp_msg_hook : msg %d on a non-enlisted lt. skip.\n",
		  (int) mm->mm_type));
	  goto free;
	}


      switch (mm->mm_type)
	{
	case TP_COMMIT:
	  {
	    lt_log_debug (
		("tp_msg_hook commit tp_data=%p client=%p cli_tp_data=%p type=%d, enlisted=%d\n",
		    tp_data, client, client ? client->cli_tp_data : NULL,
		    tp_data->cli_tp_lt->lt_2pc._2pc_type,
		    client->cli_tp_data->cli_tp_enlisted));
	    mm->vtbl->commit_done (mm->mm_resource,
		cli_2pc_transact (tp_data->cli_tp_lt, SQL_COMMIT));
	    lt_log_debug (
		("tp_msg_hook commit tp_data=%p client=%p cli_tp_data=%p done\n",
		    tp_data, client, client ? client->cli_tp_data : NULL));
	    tp_data->cli_tp_enlisted = CONNECTION_LOCAL;
	    semaphore_leave (tp_data->cli_tp_sem2);
#ifdef MQ_DEBUG
	    queue->mq_commits++;
#endif
	  };
	  break;
	case TP_PREPARE:
	  {
	    unsigned long res;
	    lt_log_debug (
		("tp_msg_hook prepare tp_data=%p client=%p cli_tp_data=%p type=%d, enlisted=%d\n",
		    tp_data, client, client ? client->cli_tp_data : NULL,
		    tp_data->cli_tp_lt->lt_2pc._2pc_type,
		    tp_data->cli_tp_enlisted));
	    mm->vtbl->prepare_set_log (mm);
	    res = cli_2pc_prepare (tp_data->cli_tp_lt);
	    mm->vtbl->prepare_done (mm->mm_resource, res);
#ifdef MQ_DEBUG
	    queue->mq_prepares++;
#endif
	    if (LTE_OK == res)
	      break;
	    else
	      {
#ifdef MQ_DEBUG
		queue->mq_errors++;
#endif
	      }
	  };
	  break;
	case TP_ABORT:
	  {
	    lt_log_debug (
		("tp_msg_hook abort tp_data=%p client=%p cli_tp_data=%p type=%d, enlisted=%d\n",
		    tp_data, client, client ? client->cli_tp_data : NULL,
		    tp_data->cli_tp_lt->lt_2pc._2pc_type,
		    tp_data->cli_tp_enlisted));
	    mm->vtbl->abort_done (mm->mm_resource,
		cli_2pc_transact (tp_data->cli_tp_lt, SQL_ROLLBACK));
	    lt_log_debug (
		("tp_msg_hook abort tp_data=%p client=%p cli_tp_data=%p done\n",
		    tp_data, client, client ? client->cli_tp_data : NULL));
	    tp_data->cli_tp_enlisted = CONNECTION_LOCAL;
	    semaphore_leave (tp_data->cli_tp_sem2);
#ifdef MQ_DEBUG
	    queue->mq_aborts++;
#endif
	  };
	  break;
	default:
	  GPF_T1 ("unknown type of tp message");
	}
    free:
      dk_free (mm, sizeof (tp_message_t));
#ifdef MQ_DEBUG
      _2pc_printf (("aborts %ld commits %ld prepares %ld errors %ld\n",
	      queue->mq_aborts, queue->mq_commits,
	      queue->mq_prepares, queue->mq_errors));
#endif
    }

  /*NOTREACHED*/
  return 0;
}

int
cli_2pc_prepare (lock_trx_t * lt)
{
  unsigned long prepared = 0;
  _2pc_printf (("cli_2pc_prepare... %x %d", lt->lt_2pc._2pc_prepared,
	  lt->lt_status));
  IN_TXN;
  if (LT_PENDING == lt->lt_status)
    lt->lt_status = LT_PREPARE_PENDING;
  else
    {
      LEAVE_TXN;
      return LTE_DEADLOCK;
    }
  if ((LTE_OK != lt->lt_error) ||
      ((caddr_t) TP_PREPARE_CHKPNT == lt->lt_2pc._2pc_prepared))
    {
      LEAVE_TXN;
      return LTE_DEADLOCK;
    }

  lt->lt_2pc._2pc_prepared = (caddr_t) & prepared;
  lt_kill_other_trx (lt, NULL, NULL, LT_KILL_ROLLBACK);
  LEAVE_TXN;

  _2pc_printf ((" done\n"));
  if (LT_PREPARED == prepared)
    return LTE_OK;
  else
    return LTE_DEADLOCK;
}

int
cli_2pc_transact (lock_trx_t * lt, int operation)
{
  _2pc_printf (("cli_2pc_transact %d\n", operation));
  IN_TXN;
  if (lt->lt_status != LT_PREPARED && operation != SQL_ROLLBACK)
    {
      lt_log_debug (("cli_2pc_transact wrong state %d for lt %p\n", lt->lt_status, lt));
      GPF_T;
      LEAVE_TXN;
      return LTE_DEADLOCK;
    }
  lt_wait_checkpoint ();
  lt->lt_2pc._2pc_prepared = 0;
  if (operation == SQL_ROLLBACK)
    lt->lt_status = LT_BLOWN_OFF;

  if (lt->lt_status == LT_COMMITTED && !LT_IS_RUNNING (lt))
    {
      lt_threads_inc_inner (lt);
      LT_CLOSE_ACK_THREADS(lt);
      lt->lt_close_ack_threads++;
    lt_2pc_commit (lt);
    }
  else
    lt_kill_other_trx (lt, NULL, NULL, LT_KILL_ROLLBACK);

  if (lt->lt_error != LTE_OK)
    {
      lt_log_debug (("cli_2pc_transact op=%d result=%d lt=%p cli=%p", operation,
	    (int) lt->lt_error, lt, lt->lt_client));
    }
  lt->lt_2pc._2pc_wait_commit = 0; /* commit happened */
  LEAVE_TXN;
  return lt->lt_error;
}

extern dk_mutex_t * log_write_mtx;

int
lt_2pc_prepare (lock_trx_t * lt)
{
  int rc = LTE_OK;
  ASSERT_IN_TXN;
  _2pc_printf (("lt_2pc_prepare\n"));
  lt->lt_status = LT_PREPARE_PENDING;


  LEAVE_TXN;
  mutex_enter (log_write_mtx);
  if (LTE_OK != log_commit (lt))
    {
      rc = LTE_LOG_FAILED;
      mutex_leave (log_write_mtx);
      IN_TXN;
      goto failed;
    }
  mutex_leave (log_write_mtx);
  IN_TXN;

  lt->lt_status = LT_COMMITTED;
  lt->lt_2pc._2pc_wait_commit = 1;
  if (lt->lt_2pc._2pc_prepared)
    {
      *((unsigned long *) lt->lt_2pc._2pc_prepared) = LT_PREPARED;
      lt->lt_2pc._2pc_prepared = 0;
    }

failed:
  if (rc != LTE_OK)
    {
      tp_data_t *tp_data = lt->lt_client->cli_tp_data;
      lt->lt_status = LT_PENDING;
      lt->lt_lw_threads--;
      lt_rollback (lt, TRX_CONT);
      semaphore_leave (tp_data->cli_tp_sem2);
    }
  return rc;
}

int
lt_2pc_commit (lock_trx_t * lt)
{
  int state;

  ASSERT_IN_TXN;
  state = lt->lt_status;
  if (lt->lt_status == LT_BLOWN_OFF || lt->lt_status == LT_DELTA_ROLLED_BACK)
    {
      int err = lt->lt_error;
      lt_rollback (lt, TRX_CONT);
      GPF_T1 ("2PC stage 2 failed\n");
      return err;
    };

  lt->lt_status = LT_COMMITTED;

  log_final_transact (lt, 1);
  if (lt->lt_mode == TM_SNAPSHOT)
    {
      lt_close_snapshot (lt);
    }
  else
    {
      if (state == LT_FINAL_COMMIT_PENDING)
	{ /* we're in lt_ack_close: set the treads */
	  LT_CLOSE_ACK_THREADS(lt);
	  lt->lt_close_ack_threads++;
	}
      lt_transact (lt, SQL_COMMIT);
    }
  if (lt->lt_pending_schema)
    {
      lt_commit_schema_merge (lt);
    }
  if (lt->lt_commit_hook)
    {
      lt->lt_commit_hook (lt);
    }
  DBG_PT_COMMIT_END (lt);
#ifdef CHECK_LT_THREADS
  if (lt->lt_wait_end)
    GPF_T1 ("resource store with threads");
#endif
#ifdef MSDTC_DEBUG
  lt->lt_in_mts = 0;
#endif
  lt_resume_waiting_end (lt);
  lt_restart (lt, TRX_CONT_LT_LEAVE);
  IN_TXN;

  return LTE_OK;
}

int
tp_wait_commit (client_connection_t * client)
{
  _2pc_printf (("********* wait commit..."));
  if (client->cli_tp_data && client->cli_tp_data->cli_tp_lt)
    {
      lt_log_debug (
	  ("tp_wait_commit before sem_enter cli=%p tp_data=%p lt=%p", client,
	      client->cli_tp_data, client->cli_tp_data->cli_tp_lt));
      semaphore_enter (client->cli_tp_data->cli_tp_sem2);
      lt_log_debug (("tp_wait_commit after sem_enter cli=%p tp_data=%p lt=%p",
	      client, client->cli_tp_data,
	      client->cli_tp_data ? client->cli_tp_data->cli_tp_lt : NULL));
      if (client->cli_tp_data)
	{
	  struct tp_data_s *tp_data;

	  IN_CLIENT (client);
	  tp_data = client->cli_tp_data;
	  client->cli_tp_data = NULL;
#ifdef MSDTC_DEBUG
	  client->cli_trx->lt_in_mts = 0;
#endif
	  LEAVE_CLIENT (client);
	  tp_free_cli_after_unenlist (client, tp_data);
	  tp_data_free (tp_data);
	}
      else
	GPF_T;
    }
  _2pc_printf ((" done\n"));
  return 0;
}

int
xa_wait_commit (tp_data_t * tpd)
{
  if (tpd)
    {
      semaphore_enter (tpd->cli_tp_sem2);
      tp_data_free (tpd);
    }
  return 0;
}

int
tp_retire (query_instance_t * qi)
{
  lock_trx_t *lt = qi->qi_client->cli_trx;
  _2pc_printf (("*** tp_retire cli %x lt %x st %d\n",
	  qi->qi_client, lt, lt->lt_status));
  if (LT_BLOWN_OFF == lt->lt_status || LT_DELTA_ROLLED_BACK == lt->lt_status)
    lt->lt_status = LT_PENDING;
  return 0;
}

int
tp_connection_state (client_connection_t * cli)
{
  tp_data_t *tpd = cli->cli_tp_data;
  if (!tpd)
    return 0;
  switch (tpd->cli_tp_enlisted)
    {
    case CONNECTION_LOCAL:
      break;
    case CONNECTION_FINISHED:
      /* should be error */
      return -1;
    case CONNECTION_ENLISTED:
      tpd->cli_tp_enlisted = CONNECTION_FINISHED;
      break;
    case CONNECTION_PREPARED:
      tpd->cli_tp_enlisted = CONNECTION_ENLISTED;
      break;
    default:
      /* wrong connection state */
      return -1;
    }
  return 0;
}

void
dtrx_dealloc (tp_dtrx_t * dtrx)
{
  dk_free (dtrx, sizeof (tp_dtrx_t));
}

tp_dtrx_t *
virt_trx_allocate ()
{
  static tp_trx_vtbl_t vtbl = {
    tp_trx_enlist,
    tp_trx_commit_1,
    tp_trx_commit_2,
    tp_trx_exclude,
    dtrx_dealloc
  };
  NEW_VARZ (tp_dtrx_t, dtrx);
  dtrx->vtbl = &vtbl;

  _2pc_printf (("allocated dtrx %x\n", dtrx));

  return dtrx;
}

void
tp_data_free (tp_data_t * tpd)
{
  lt_log_debug (("Tp_data_free %p", tpd));
  if (tpd->cli_tp_trx)
    {
      switch (tpd->cli_trx_type)
	{
	case TP_MTS_TYPE:
	  {
	    if (MSDTC_IS_LOADED)
	      mts_release_trx (tpd->cli_tp_trx);
	    break;
	  }
	case TP_XA_TYPE:
	  break;
	case TP_VIRT_TYPE:
	  break;
	default:
	  GPF_T1 ("Unknown distr. transaction type");
	}
    }

  dk_free_box (tpd->tpd_trx_cookie);
  if (tpd->cli_tp_sem2)
    semaphore_free (tpd->cli_tp_sem2);
  dk_free (tpd, sizeof (tp_data_t));
}

#define MSG_BUF_SIZE 300


static caddr_t
bif_2pc_enlist (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sqlr_error ("TP000", "Compatibility error");
  return NULL;			/* keeps compiler happy */
}

/* called from virt_tp_enlist_branch */
static caddr_t
bif_2pc_enlist_001 (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  client_connection_t *cli = qi->qi_client;
  caddr_t branch_cookie =
      bif_string_arg (qst, args, 0, "virt_tp_update_cli_001");
  NEW_VARZ (tp_data_t, tpd);
  _2pc_printf (("bif_2pc_enlist... %x %x", cli, cli->cli_trx));
  tpd->cli_tp_enlisted = CONNECTION_PREPARED;
  tpd->cli_tp_sem2 = semaphore_allocate (0);
  tpd->tpd_trx_cookie = box_string (branch_cookie);
  cli->cli_tp_data = tpd;
  tpd->cli_trx_type = cli->cli_trx->lt_2pc._2pc_type = TP_VIRT_TYPE;

  _2pc_printf ((" done\n"));
  _2pc_printf (("	received branch cookie %s\n", branch_cookie));
  return NEW_DB_NULL;
}



typedef tp_addr_t tp_srv_addr_t;
typedef SQLHDBC srv_connection_t;

virt_tp_t *_2pc_dtp;

int tp_l_enlist_remote (rds_connection_t * rcon, virt_rcon_t * vbranch);
int virt_tp_remove_trx (client_connection_t * cli, virt_trx_t * vtrx);
virt_rcon_t *virt_tp_add_remote (virt_trx_t * vtrx);
void tp_trx_set_uuid (virt_trx_t * vtrx);

static caddr_t
exec_trx_sql_1 (client_connection_t * cli, char *pl_call_text, int params,
    virt_trx_id_t trx_id, const char *state, char **err_ret, int global_lock)
{
  static query_t *qr = NULL;
  local_cursor_t *lc = NULL;
  caddr_t err = NULL;

  if (params > 2)
    return 0;

  qr = sql_compile (pl_call_text, cli, &err, SQLC_DEFAULT);
  if (SQL_SUCCESS != err)
    {
      if (err_ret)
	{
	  err_ret[0] = err;
	}
      qr = NULL;
      return 0;
    }

  if (global_lock)
    IN_TXN;
  lt_threads_inc_inner (cli->cli_trx);
  if (global_lock)
    LEAVE_TXN;

  err = qr_rec_exec (qr, cli, &lc, CALLER_LOCAL, NULL, params,
      ":0", (ptrlong) trx_id, QRP_INT, ":1", state, QRP_STR);
  if (SQL_SUCCESS != err)
    {
      if (err_ret)
	*err_ret = err;
      goto failed;
    }
  if (lc)
    {
      caddr_t ret = NULL;
      while (lc_next (lc));
      if (SQL_SUCCESS != lc->lc_error)
	{
	  if (err_ret)
	    *err_ret = lc->lc_error;
	  lc_free (lc);
	  goto failed;
	}
      ret = ((caddr_t *) lc->lc_proc_ret)[1];
      ((caddr_t *) lc->lc_proc_ret)[1] = NULL;
      lc_free (lc);
      if (global_lock)
	IN_TXN;
      lt_commit (cli->cli_trx, TRX_CONT);
      lt_threads_dec_inner (cli->cli_trx);
      if (global_lock)
	LEAVE_TXN;
      return ret;
    }
failed:
  if (global_lock)
    IN_TXN;
  lt_rollback (cli->cli_trx, TRX_CONT);
  lt_threads_dec_inner (cli->cli_trx);
  if (global_lock)
    LEAVE_TXN;
  return 0;
}

virt_trx_id_t
tp_add_transaction_entry (client_connection_t * cli, char **err_ret)
{
  static char *pl_call_text = "_2PC.DBA._0001_ADD_ENTRY()";
  return (virt_trx_id_t) (ptrlong) exec_trx_sql_1 (cli, pl_call_text, 0, 0, 0,
      err_ret, 1);
}

virt_branch_id_t
tp_add_remote (client_connection_t * cli, virt_trx_t * vtrx, char **err_ret)
{
  /*
     static char *pl_call_text = "_2PC.DBA._0001_ADD_REMOTE (?)";
     return (virt_branch_id_t) exec_trx_sql_1 (cli, pl_call_text, 1, vtrx->vtx_id, 0, err_ret); */
  return 1;
}

/* returns zero if failed */
int
virt_trx_set_state (client_connection_t * cli, virt_trx_id_t trx_id,
    const char *state_str)
{
  static char *pl_call_text = "_2PC.DBA._0001_TRX_SSTATE (?,?)";
  char *err = NULL;
  exec_trx_sql_1 (cli, pl_call_text, 2, trx_id, state_str, &err, 1);
  if (err)
    {
      _2pc_printf (
	  ("failed to set new state [%s] for transaction [%ld] err = %s",
	      state_str, trx_id, virt_2pc_format_error_string (err)));
      return 0;
    }
  return 1;
}

/* adds new entry in system table & returns id of new transaction */
virt_trx_t *
virt_tp_add_trx (client_connection_t * cli, lock_trx_t * lt)
{
  virt_trx_t *vtrx;
  char *err = NULL;
  virt_trx_id_t id = tp_add_transaction_entry (cli, &err);

  if (!id)
    {
      return NULL;
    }
  vtrx = (virt_trx_t *) dk_alloc (sizeof (virt_trx_t));
  memset (vtrx, 0, sizeof (virt_trx_t));

  vtrx->vtx_id = id;
  vtrx->vtx_curr_state = virt_tp_started;
  vtrx->vtx_transaction_processor = _2pc_dtp;
  vtrx->vtx_branch_factory = virt_tp_add_remote;
  vtrx->vtx_uuid = (uuid_t *) dk_alloc_box (sizeof (uuid_t), DV_BIN);
  tp_trx_set_uuid (vtrx);
  vtrx->vtx_cookie = uuid_bin_encode ((void *) vtrx->vtx_uuid);

  dk_set_push (&_2pc_dtp->vtp_trxs, vtrx);
  return vtrx;
}

/* there are two ways for creating new distr transaction */
/* the first one */
virt_rcon_t *
virt_tp_add_remote (virt_trx_t * vtrx)
{
  char *err;
  client_connection_t *cli = vtrx->vtx_transaction_processor->vtp_cli;
  virt_branch_id_t branch_id = tp_add_remote (cli, vtrx, &err);
  virt_rcon_t *vbranch;

  if (!branch_id)
    {
      return NULL;
    }
  vbranch = (virt_rcon_t *) dk_alloc (sizeof (virt_rcon_t));
  memset (vbranch, 0, sizeof (virt_rcon_t));
  vbranch->vtr_id = branch_id;
  vbranch->vtr_trx = vtrx;
/*   vbranch->vtr_cookie = tp_get_l_branch_cookie (vbranch); */

  dk_set_push (&vtrx->vtx_cons, vbranch);
  return vbranch;
}


/* virt TP */
/*
		  virt_tp_create ();
		  virt_tp_trx_create ();
		  virt_tp_trx_continue (virt_tp2hdbc, trx_id);
*/

/*	virt TRX
		  trx_enlist_remote (trx_id );
		  trx_transact (); -- commit or rollback --
		  trx_exclude ();
*/

#define VIRT_MSG_COMMIT
#define VIRT_MSG_ROLLBACK

typedef struct virt_tp_message_s
{
  ptrlong vtm_type;
  virt_trx_t *vtm_trx;
}
virt_tp_message_t;

#include "util/uuid.h"

typedef union trx_uuid_u
{
  uint8 raw[16];
  struct
  {
    unsigned char addr[4];
    uint32 port;
    uint32 trx_id;
    unsigned char zero[4];
  } p_uuid;
}
trx_uuid_t;

caddr_t
tp_get_server_uuid ()
{
#if defined (UUID_BY_PORT)

#if defined (_REENTRANT) && (defined (linux) || defined (SOLARIS))
  char buff[4096];
  int herrnop;
  struct hostent ht;
#endif
  char host[255];
  char *ip_addr = 0;
  struct hostent *local;
  if (0 != gethostname (host, sizeof (host)))
    strcpy_ck (host, "localhost");

#if defined (_REENTRANT) && defined (linux)
  gethostbyname_r (host, &ht, buff, sizeof (buff), &local, &herrnop);
#elif defined (_REENTRANT) && defined (SOLARIS)
  local = gethostbyname_r (host, &ht, buff, sizeof (buff), &herrnop);
#else
  local = gethostbyname (host);
#endif
  if (local && local->h_addr_list[0] && local->h_addrtype == AF_INET)
    {
      caddr_t srv_uuid = dk_alloc_box (sizeof (trx_uuid_t), DV_SHORT_STRING);
      trx_uuid_t trx_uuid;
      memset (&trx_uuid, 0, sizeof (trx_uuid_t));
      memcpy (trx_uuid.p_uuid.addr, (unsigned char *) (local->h_addr_list[0]),
	  sizeof (trx_uuid.p_uuid.addr));
      memcpy (srv_uuid, &trx_uuid.raw, sizeof (trx_uuid_t));
      return srv_uuid;
    }
  return ip_addr;
#else
  return NULL;
#endif
}

static void
tp_set_trx_id (caddr_t trx_uuid_rw, long trx_id)
{
  trx_uuid_t *trx_uuid = (trx_uuid_t *) trx_uuid_rw;
  trx_uuid->p_uuid.trx_id = htonl (trx_id);
}
static void
tp_set_port (caddr_t trx_uuid_rw, long port)
{
  trx_uuid_t *trx_uuid = (trx_uuid_t *) trx_uuid_rw;
  trx_uuid->p_uuid.port = htonl (port);
}

/* DTP transaction flow params */
#define TP_TRX_T_AUTO		0

tp_result_t
tp_trx_enlist (rds_connection_t * rcon, query_instance_t * qi)
{
  lock_trx_t *lt = qi->qi_trx;
  _2pc_printf (("tp_trx_enlist %x %x", rcon, lt));
  if (rcon->rc_is_enlisted == SHOULD_BE_ENLISTED)
    {
      virt_trx_t *vtrx;
      virt_rcon_t *vbranch;
      tp_result_t l_enl_res;
      if (!lt->lt_2pc._2pc_info->dtrx_info)
	{
	  if (lt->lt_2pc._2pc_params != TP_TRX_T_AUTO)
	    return TP_ERR_NO_DISTR_TRX;
	  else
	    {			/* adding distr. transaction */
	      virt_trx_t *virt_trx = virt_tp_add_trx (_2pc_dtp->vtp_cli, lt);
	      if (!virt_trx)
		{
		  return TP_ERR_DTRX_INIT;
		}
	      else
		{
		  lt->lt_2pc._2pc_info->dtrx_info = (caddr_t) virt_trx;
		}
	    }
	}
      vtrx = (virt_trx_t *) lt->lt_2pc._2pc_info->dtrx_info;
      vbranch = (*vtrx->vtx_branch_factory) (vtrx);
      if (!vbranch)
	{
	  virt_tp_remove_trx (_2pc_dtp->vtp_cli, vtrx);
	  return TP_ERR_SYS_TABLE;
	}
      /* notify remote server */
      l_enl_res = tp_l_enlist_remote (rcon, vbranch);

      if (l_enl_res <= TP_ERR_COMMON)
	{
	  return l_enl_res;
	}
      return 0;
    }
  return 0;
}

/* stage one commit */
tp_result_t
tp_trx_commit_1 (lock_trx_t * lt, int is_commit)
{
  return LTE_OK;
}

tp_result_t
tp_trx_commit_2 (caddr_t distr_trx, int is_commit)
{
  return LTE_OK;
}

int
tp_trx_exclude (lock_trx_t * lt, rds_connection_t * rcon)
{
  return 0;
}

int
tp_trx_exclude_001 (lock_trx_t * lt, rds_connection_t * rcon)
{
  CON (dbc, rcon->rc_hdbc);
  caddr_t res;
  future_t *f;

  _2pc_printf (("tp_trx_exclude... "));
  f = PrpcFuture (dbc->con_session, &s_sql_tp_transact, SQL_TP_UNENLIST,
      NULL);
  res = PrpcFutureNextResult (f);
  PrpcFutureFree (f);
  _2pc_printf ((" done.\n"));

  rcon->rc_is_enlisted = 0;
  return 0;
}


int
tp_l_set_server_uuid (rds_connection_t * rcon, virt_rcon_t * vbranch)
{
  vbranch->vtr_is_local = 1;
  vbranch->vtr_branch_handle.l_rmt = rcon;
  return 0;
}


void
tp_trx_set_uuid (virt_trx_t * vtrx)
{
  caddr_t srv_uuid = (caddr_t) vtrx->vtx_transaction_processor->vtp_uuid;
  memcpy ((void *) vtrx->vtx_uuid, srv_uuid, sizeof (trx_uuid_t));
  tp_set_trx_id ((caddr_t) vtrx->vtx_uuid, vtrx->vtx_id);
  tp_set_port ((caddr_t) vtrx->vtx_uuid, server_port);
}


int
tp_l_enlist_remote (rds_connection_t * rcon, virt_rcon_t * vbranch)
{
  return 0;
}

int
virt_tp_remove_trx (client_connection_t * cli, virt_trx_t * vtrx)
{
  _2pc_printf (("virt_tp_remove_trx IS NOT IMPLEMENTED!!"));
  return 0;
}

/* logging & recovery functions */
static unsigned long
virt_prepare_set_log (tp_data_t * tpd)
{
  box_t info_box = dk_alloc_box (sizeof (trx_uuid_t), DV_BIN);
  uuid_parse ((char *) tpd->tpd_trx_cookie, (unsigned char *) info_box);
  tpd->cli_tp_lt->lt_2pc._2pc_log = info_box;
  return 0;
}

int
virt_tp_recover (box_t recov_data)
{
  return SQL_ROLLBACK;
}

static virt_tp_t *
virt_tp_create ()
{
  virt_tp_t *virt_tp = (virt_tp_t *) dk_alloc (sizeof (virt_tp_t));
  memset (virt_tp, 0, sizeof (virt_tp_t));
  virt_tp->vtp_cli = client_connection_create ();
  virt_tp->vtp_uuid = (struct uuid *) tp_get_server_uuid ();
  IN_TXN;
  cli_set_new_trx (virt_tp->vtp_cli);
  LEAVE_TXN;
  return virt_tp;
}

static caddr_t
bif_mts_fail_after_prepare (caddr_t * qst, caddr_t * err_ret,
    state_slot_t ** args)
{
  _2pc_printf (("setting fail_after_prepare"));
  fail_after_prepare =
      (long) bif_long_arg (qst, args, 0, "mts_fail_after_prepare");
  return NEW_DB_NULL;
}

void
virt_tp_store_connections (lock_trx_t * lt)
{
}


/* utils */
char *
virt_2pc_format_error_string (caddr_t err)
{
  caddr_t *box_err = (caddr_t *) err;
  if (err == (caddr_t) SQL_ERROR)
    return "unknown error";
  if (box_err[0] == (caddr_t) QA_ERROR)
    {
      static char st_str[1024];
      snprintf (st_str, 1024, "[%s] %s", box_err[1], box_err[2]);
      return st_str;
    }
  return "";
}


/* XA funcs */

virt_xa_map_t *global_xa_map = 0;

static id_hashed_key_t
xid_hash (caddr_t xid_v)
{
  void *xid = *(void **) xid_v;
  int sz = sizeof (virtXID);
  uint32 *p = (uint32 *) xid;
  long code = 1001;

  while (sz)
    {
      if (p[0])
	code = (code * p[0]) ^ (code >> 23);
      else
	code = code << 2 | code >> 30;
      p++;
      sz -= sizeof (uint32);
    }
  return (code & ID_HASHED_KEY_MASK);
}

static int
xidhashcmp (caddr_t x1, caddr_t x2)
{
  return 0 == memcmp (((virtXID **) x1)[0], ((virtXID **) x2)[0],
      sizeof (uuid_t));
}

char *xa_persistent_file = "test.xa";

static void
global_xa_init ()
{
  global_xa_map = (virt_xa_map_t *) dk_alloc (sizeof (virt_xa_map_t));
  global_xa_map->xm_xids =
      id_hash_allocate (231, sizeof (caddr_t), sizeof (caddr_t), xid_hash,
      xidhashcmp);
  global_xa_map->xm_log_xids =
      id_hash_allocate (231, sizeof (caddr_t), sizeof (caddr_t), xid_hash,
      xidhashcmp);
  global_xa_map->xm_mtx = mutex_allocate ();
  if (-1 == txa_open (xa_persistent_file))
    log_error ("could not read/create XA persistent file %s",
	xa_persistent_file);

}

void
virt_xa_tp_set_xid (tp_data_t * tpd, void *xid)
{
  tpd->cli_tp_trx = xid;
  tpd->tpd_trx_cookie = box_copy ((caddr_t) xid);
}

int
virt_xa_add_trx (void *xid, lock_trx_t * lt)
{
  xa_id_t **x;
  int rc = 0;
  mutex_enter (global_xa_map->xm_mtx);

  x = (xa_id_t **) id_hash_get (global_xa_map->xm_xids, (caddr_t) & xid);
  if (x == 0)
    {
      xa_id_t *xx = (xa_id_t *) dk_alloc (sizeof (xa_id_t));
      tp_data_t * tpd = (tp_data_t*)dk_alloc (sizeof (tp_data_t));
      memset (tpd, 0, sizeof (tp_data_t));
      memcpy (&xx->xid, xid, sizeof (virtXID));
      virt_xa_tp_set_xid (tpd, xid);
      lt->lt_2pc._2pc_log = box_copy (xid);
      dk_free_tree (lt->lt_2pc._2pc_xid);
      lt->lt_2pc._2pc_xid = xid;
      xid = (void *) &xx->xid;
      xx->xid_sem = 0;
      xx->xid_cli = NULL;
      tpd->cli_tp_enlisted = CONNECTION_PREPARED;
      tpd->cli_tp_sem2 = semaphore_allocate (0);
      tpd->cli_tp_lt = lt;
      tpd->cli_trx_type = lt->lt_2pc._2pc_type = TP_XA_TYPE;
      xx->xid_tp_data = tpd;
      xx->xid_op = SQL_XA_ENLIST;
      id_hash_set (global_xa_map->xm_xids, (caddr_t) & xid, (caddr_t) & xx);
      rc = 0;
    }
  else
    {
      rc = 1;
    }
  mutex_leave (global_xa_map->xm_mtx);
  return rc;
}

int
virt_xa_set_client (void *xid, struct client_connection_s *cli)
{
  xa_id_t **x;
  mutex_enter (global_xa_map->xm_mtx);
  _2pc_printf (("setting xa transact %x", xid));

  x = (xa_id_t **) id_hash_get (global_xa_map->xm_xids, (caddr_t) & xid);

  if (x == 0)
    {
      xa_id_t *xx = (xa_id_t *) dk_alloc (sizeof (xa_id_t));
      memcpy (&xx->xid, xid, sizeof (virtXID));
      xid = (void *) &xx->xid;
      xx->xid_sem = 0;
      xx->xid_cli = cli;
      xx->xid_tp_data = cli->cli_tp_data;
      xx->xid_op = SQL_XA_ENLIST;
      id_hash_set (global_xa_map->xm_xids, (caddr_t) & xid, (caddr_t) & xx);
      mutex_leave (global_xa_map->xm_mtx);
      return 0;
    }
  else
    {
      if (x[0]->xid_sem)
	{
	  x[0]->xid_cli = cli;
	  x[0]->xid_tp_data = cli->cli_tp_data;
	  mutex_leave (global_xa_map->xm_mtx);
	  semaphore_leave (x[0]->xid_sem);
	  return 0;
	}
      else
	{
#if 0
	  int rc = -1;
	  if (x[0]->xid_op == SQL_XA_ROLLBACK)
	    rc = VXA_AGAIN;
	  mutex_leave (global_xa_map->xm_mtx);
	  return rc;
#else
	  mutex_leave (global_xa_map->xm_mtx);
	  return VXA_ERROR;
#endif
	}
    }
}

void
virt_xa_suspend_lt (void *xid, struct client_connection_s *cli)
{
  xa_id_t **x;
  mutex_enter (global_xa_map->xm_mtx);
  x = (xa_id_t **) id_hash_get (global_xa_map->xm_xids, (caddr_t) & xid);
  if (!x)
    GPF_T1 ("2PC: broken xids map");
  x[0]->xid_cli = NULL;
  mutex_leave (global_xa_map->xm_mtx);
}


int
virt_xa_client (void *xid, client_connection_t * cli, struct tp_data_s **tpd, int op)
{
  xa_id_t **xx, *x;

  if (!xid)
    return -1;

  mutex_enter (global_xa_map->xm_mtx);
  xx = (xa_id_t **) id_hash_get (global_xa_map->xm_xids, (caddr_t) & xid);

  if (!xx)
    {
      if ((op == SQL_XA_COMMIT) || (op == SQL_XA_WAIT) || (op == SQL_XA_RESUME) || (op == SQL_XA_ENLIST_END) || (op == SQL_XA_SUSPEND))
	{
	  mutex_leave (global_xa_map->xm_mtx);
	  return -1;
	}
      else
	{
	  x = (xa_id_t *) dk_alloc (sizeof (xa_id_t));
	  memcpy (&x->xid, xid, sizeof (virtXID));
	  xid = (void *) &x->xid;
	  x->xid_sem = semaphore_allocate (0);
	  id_hash_set (global_xa_map->xm_xids, (caddr_t) & xid, (caddr_t) & x);
	  mutex_leave (global_xa_map->xm_mtx);
	  semaphore_enter (x->xid_sem);

	  mutex_enter (global_xa_map->xm_mtx);
	  tpd[0] = x->xid_tp_data;
	  semaphore_free (x->xid_sem);
	  x->xid_sem = 0;
	  mutex_leave (global_xa_map->xm_mtx);
	}
      return 0;
    }
  x = xx[0];

  if (op == SQL_XA_ROLLBACK)
    x->xid_op = SQL_XA_ROLLBACK;

  tpd[0] = x->xid_tp_data;
  mutex_leave (global_xa_map->xm_mtx);

  IN_TXN;
  lt_wait_checkpoint ();
  if (cli->cli_trx != x->xid_tp_data->cli_tp_lt)
    {
      lt_kill_other_trx (cli->cli_trx, NULL, NULL, LT_KILL_ROLLBACK);
      lt_done (cli->cli_trx);
      cli->cli_trx = NULL;
      cli_set_trx (cli, x->xid_tp_data->cli_tp_lt);
    }
  cli->cli_tp_data = x->xid_tp_data;
  if (x->xid_cli && x->xid_cli != cli)
    {
      x->xid_cli->cli_tp_data = NULL;
      if (x->xid_cli->cli_trx == cli->cli_trx)
	{
	  x->xid_cli->cli_trx = NULL;
	  cli_set_new_trx (x->xid_cli);
	}
    }
  x->xid_cli = cli;
  LEAVE_TXN;
  return 0;
}

void
virt_xa_remove_xid (void *xid)
{
  xa_id_t **xx;
  if (!xid)
    return;

  mutex_enter (global_xa_map->xm_mtx);
  _2pc_printf (("removing xa transact %x", xid));
  xx = (xa_id_t **) id_hash_get (global_xa_map->xm_xids, (caddr_t) & xid);
  if (xx)
    {
      xa_id_t * x = xx[0];
      x->xid_cli->cli_tp_data = NULL;
      id_hash_remove (global_xa_map->xm_xids, (caddr_t) & xid);
      if (x->xid_sem)
	semaphore_free (x->xid_sem);
      dk_free (x, sizeof (xa_id_t));
    }
  mutex_leave (global_xa_map->xm_mtx);
}

void *
virt_xa_id (char *xid_str)
{
  return xid_bin_decode (xid_str);
}

caddr_t
virt_xa_xid_in_log (void *xid)
{
  caddr_t *trx;
  mutex_enter (global_xa_map->xm_mtx);
  trx = (caddr_t *) id_hash_get (global_xa_map->xm_log_xids, (caddr_t) & xid);
  mutex_leave (global_xa_map->xm_mtx);

  if (!trx)
    return 0;

  return trx[0];
}

static caddr_t
bif_get_rec_xid_beg (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  mutex_enter (global_xa_map->xm_mtx);
  id_hash_iterator (&global_xa_map->xm_hit, global_xa_map->xm_log_xids);
  return NEW_DB_NULL;
}

static caddr_t
bif_get_rec_xid (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  void **xid;
  caddr_t *transact;
  if (hit_next (&global_xa_map->xm_hit, (char **) &xid, (char **) &transact))
    {
      return xid_bin_encode (xid[0]);
    }
  return NEW_DB_NULL;
}

static caddr_t
bif_get_rec_xid_end (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  mutex_leave (global_xa_map->xm_mtx);
  return NEW_DB_NULL;
}

static int
replay_transact (caddr_t tr, int is_commit)
{
  lock_trx_t *lt;
  int rc;
  dk_session_t trx_ses;
  dk_session_t *in = &trx_ses;
  in->dks_in_buffer = tr;
  in->dks_in_read = 0;
  in->dks_in_fill = box_length (tr);

  IN_TXN;
  lt = lt_start ();
  LEAVE_TXN;

  CATCH_READ_FAIL (in)
  {
    while (1)
      {
	int op;
	caddr_t err;
	if (in->dks_in_read == in->dks_in_fill)
	  break;
	op = session_buffered_read_char (in);
	err = log_replay_entry (lt, op, in, 0);
	if (err == SQL_SUCCESS)
	  continue;
	/* does not matter what kind of error */
	dk_free_tree (err);

	IN_TXN;
	lt_rollback (lt, TRX_FREE);
	LEAVE_TXN;
	return LTE_DEADLOCK;
      }

  }
  FAILED
  {
    /* bad log record */
    IN_TXN;
    lt_rollback (lt, TRX_FREE);
    LEAVE_TXN;
    return LTE_SQL_ERROR;
  }
  END_READ_FAIL (in);

  IN_TXN;
  rc = LTE_OK;
  if (is_commit)
    rc = lt_commit (lt, TRX_FREE);
  else
    lt_rollback (lt, TRX_FREE);
  LEAVE_TXN;

  return rc;
}

int
virt_xa_replay_trx (void *xid, caddr_t trx, struct client_connection_s *cli)
{
  return replay_transact (trx, 1);
}

static caddr_t
bif_heuristic_transact (caddr_t * qst, caddr_t * err_ret,
    state_slot_t ** args)
{
  caddr_t tr_xid = bif_string_arg (qst, args, 0, "heuristic_transact");
  int is_commit = (int) bif_long_arg (qst, args, 1, "heuristic_transact");
  void *xid = xid_bin_decode (tr_xid);
  if (!xid)
    sqlr_error ("XAXXX", "wrong xid string");
  mutex_enter (global_xa_map->xm_mtx);
  {
    int result;
    caddr_t trlog =
	(caddr_t) id_hash_get (global_xa_map->xm_log_xids, (caddr_t) & xid);
    if (!trlog)
      {
	mutex_leave (global_xa_map->xm_mtx);
	dk_free_box ((box_t) xid);
	sqlr_error ("XAXXX", "Unknown XA transaction [%s]", tr_xid);
      }
    result = replay_transact (trlog, is_commit);
    dk_free_box (trlog);
    dk_free_box ((box_t) xid);

    mutex_leave (global_xa_map->xm_mtx);

    if (result != LTE_OK)
      {
	/* deadlock, return error */
	sqlr_error ("XAXXX", "Transaction could not be committed");
      }
  }
  return NEW_DB_NULL;
}

static void _txa_test ();

static caddr_t
bif_txa_test (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  _txa_test ();
  return NEW_DB_NULL;
}

static caddr_t
bif_txa_bin_encode (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t xid = bif_arg (qst, args, 0, "txa_bin_encode");
  return xid_bin_encode (xid);
}

static caddr_t
bif_txa_get_all_trx (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);

void
tp_bif_init ()
{
  /* compatibility */
  bif_define_typed ("tp_enlist", bif_2pc_enlist, &bt_integer);
  bif_define_typed ("virt_tp_update_cli_001", bif_2pc_enlist_001,
      &bt_integer);
  bif_define_typed ("__mts_fail_after_prepare", bif_mts_fail_after_prepare,
      &bt_integer);

  /* XA xid mapping init */
  global_xa_init ();
  bif_define_typed ("get_rec_xid_beg", bif_get_rec_xid_beg, &bt_any);
  bif_define_typed ("get_rec_xid", bif_get_rec_xid, &bt_any);
  bif_define_typed ("get_rec_xid_end", bif_get_rec_xid_end, &bt_any);
  bif_define ("heuristic_transact", bif_heuristic_transact);
  bif_define ("txa_get_all_trx", bif_txa_get_all_trx);
  bif_define ("txa_bin_encode", bif_txa_bin_encode);

  /* test */
  bif_define ("txa_test", bif_txa_test);
}

void
tp_main_queue_init ()
{
  _2pc_dtp = virt_tp_create ();

  tp_main_queue = tp_queue_init ();
  thread_create (tp_message_hook, 0, tp_main_queue);

}

tp_queue_t *
tp_get_main_queue ()
{
  return tp_main_queue;
}

static const char *_2pc_log_prefix = "2PC:";

void
twopc_log (int log_level, char *message)
{
  if (log_level == _LOG_ERROR)
    log_error ("%s %s", _2pc_log_prefix, message);
  if (log_level == _LOG_INFO)
    log_info ("%s %s", _2pc_log_prefix, message);
}

/* ---- xa transactions file */

txa_entry_t *
txa_create_entry (void *xid, char *path, ptrlong offset, char *res)
{
  NEW_VARZ (txa_entry_t, txe);
  txe->txe_id = (char *) box_copy ((box_t) xid);
  txe->txe_path = box_string (path);
  txe->txe_offset = box_num (offset);
  txe->txe_res = box_string (res);
  return txe;
}

void
txa_free_entry (txa_entry_t * e)
{
  dk_free_box (e->txe_id);
  dk_free_box (e->txe_offset);
  dk_free_box (e->txe_path);
  dk_free_box (e->txe_res);
  dk_free (e, sizeof (txa_entry_t));
}

caddr_t *
txa_read_entries (int fd)
{
  caddr_t *info;
  dk_session_t *file_in = dk_session_allocate (SESCLASS_TCPIP);
  tcpses_set_fd (file_in->dks_session, fd);

  if (!DKSESSTAT_ISSET (file_in, SST_OK))
    {
      PrpcSessionFree (file_in);
      return 0;
    }

  info = (caddr_t *) read_object (file_in);
  if (!DKSESSTAT_ISSET (file_in, SST_OK))
    {
      PrpcSessionFree (file_in);
      return 0;
    }
  PrpcSessionFree (file_in);
  if (DV_TYPE_OF (info) == DV_ARRAY_OF_POINTER)
    return info;
  dk_free_tree ((box_t) info);
  return 0;
}

void
txa_write_info (int fd, caddr_t * info)
{
  dk_session_t *file_out = dk_session_allocate (SESCLASS_TCPIP);
  tcpses_set_fd (file_out->dks_session, fd);

  CATCH_WRITE_FAIL (file_out)
  {
    print_object ((caddr_t) info, file_out, NULL, NULL);
    session_flush_1 (file_out);
  }
  FAILED
  {
    log_error ("Could not write XA transaction file");
  }
  END_WRITE_FAIL (file_out);
  PrpcSessionFree (file_out);
}

txa_entry_t **
txa_parse_entries (caddr_t * info)
{
  dk_set_t s = 0;
  int inx;
  DO_BOX (caddr_t *, entry_i, inx, info)
  {
    if (box_length (entry_i) / sizeof (caddr_t) != TXE_ITEMS)
      goto err;
    else
      {
	txa_entry_t *entry = txa_create_entry (entry_i[0],
	    entry_i[1],
	    unbox (entry_i[2]),
	    entry_i[3]);
	dk_set_push (&s, entry);
      }
  }
  END_DO_BOX;
  return (txa_entry_t **) list_to_array (s);
err:
  DO_SET (txa_entry_t *, e, &s)
  {
    txa_free_entry (e);
  }
  END_DO_SET ();
  return 0;
}

void
txa_add_entry (txa_entry_t * e)
{
  uint32 sz;
  txa_entry_t **new_pi;
  if (txi.txi_parsed_info)
    sz = box_length (txi.txi_parsed_info);
  else
    sz = 0;
  sz += sizeof (txa_entry_t *);
  new_pi = (txa_entry_t **) dk_alloc_box (sz, DV_ARRAY_OF_POINTER);
  if (txi.txi_parsed_info)
    memcpy (new_pi, txi.txi_parsed_info, box_length (txi.txi_parsed_info));
  new_pi[sz / sizeof (txa_entry_t *) - 1] = e;
  dk_free_box ((box_t) txi.txi_parsed_info);
  txi.txi_parsed_info = new_pi;
}

void
txa_remove_entry (void *xid, int check)
{
  txa_entry_t * e;
  mutex_enter (global_xa_map->xm_mtx);
  if (NULL != (e = txa_search_trx (xid)))
    {
      uint32 sz = box_length (txi.txi_parsed_info) - sizeof (txa_entry_t *);
      txa_entry_t **new_v = (txa_entry_t **) dk_alloc_box (sz, DV_ARRAY_OF_POINTER);
      int idx, nidx = 0;
      for (idx = 0; idx < (int) (sz / sizeof (txa_entry_t *) + 1); idx++)
	{
	  if (memcmp (xid, txi.txi_parsed_info[idx]->txe_id, box_length (xid)))
	    {
	      memcpy (new_v + nidx, txi.txi_parsed_info + idx, sizeof (txa_entry_t *));
	      nidx++;
	    }
	}
      if (nidx != (idx - 1))
	GPF_T1 ("Inconsistent XA info");
      dk_free_box ((box_t) txi.txi_parsed_info);
      txa_free_entry (e);
      txi.txi_parsed_info = new_v;
    }
#if 0
  else if (check)
    {
      char *xid_str = xid_bin_encode (xid);
      log_error ("trying to remove non existing xid %s", xid_str);
      dk_free_box (xid_str);
    }
#endif
  txa_write ();
  mutex_leave (global_xa_map->xm_mtx);
}

caddr_t *
txa_serialize (txa_entry_t ** ppe)
{
  caddr_t *i = (caddr_t *) dk_alloc_box (box_length (ppe), DV_ARRAY_OF_POINTER);
  int inx;
  DO_BOX (txa_entry_t *, e, inx, ppe)
  {
    caddr_t *ser_e =
	(caddr_t *) dk_alloc_box (4 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
    ser_e[0] = box_copy (e->txe_id);
    ser_e[1] = box_copy (e->txe_path);
    ser_e[2] = box_copy (e->txe_offset);
    ser_e[3] = box_copy (e->txe_res);
    i[inx] = (caddr_t) ser_e;
  }
  END_DO_BOX;
  return i;
}

static int
txa_open (char *file_name)
{
  int fd;
  file_set_rw (file_name);
  fd = fd_open (file_name, OPEN_FLAGS);
  if (fd >= 0)
    {
      txi.txi_trx_file = box_string (file_name);
      txi.txi_fd = fd;
      txi.txi_info = txa_read_entries (txi.txi_fd);
      fd_close (txi.txi_fd, txi.txi_trx_file);
      if ((txi.txi_parsed_info = txa_parse_entries (txi.txi_info)))
	return 0;
    }
  return -1;
}

static int
txa_write ()
{
  int fd;
  dk_free_tree ((box_t) txi.txi_info);
  txi.txi_info = txa_serialize (txi.txi_parsed_info);
  fd = fd_open (txi.txi_trx_file, OPEN_FLAGS);
  if (fd >= 0)
    {
      FTRUNCATE (fd, 0);
      txa_write_info (fd, txi.txi_info);
      fd_close (fd, txi.txi_trx_file);
      return 0;
    }
  else
    log_error ("Can not open %s file", txi.txi_trx_file);
  return -1;
}

txa_entry_t *
txa_search_trx (void *xid)
{
  if (txi.txi_parsed_info)
    {
      int idx;
      /* use hash later */
      for (idx = 0; idx < BOX_ELEMENTS_INT (txi.txi_parsed_info); idx++)
	{
	  if (!memcmp (xid, txi.txi_parsed_info[idx]->txe_id,
		  box_length (xid)))
	    return txi.txi_parsed_info[idx];
	}
    }
  return 0;
}

void
txa_from_trx (lock_trx_t * lt, char *log_file_name)
{
  txa_entry_t *e;
  e = txa_search_trx (lt->lt_2pc._2pc_xid);
  if (!e)
    {
      e = txa_create_entry (lt->lt_2pc._2pc_xid, log_file_name, (ptrlong) lt->lt_2pc._2pc_logged, (char *) "PRP");
      if (e)
	{
	  txa_add_entry (e);
	  txa_write ();
	}
    }
  else
    {
      dk_free_box (e->txe_offset);
      e->txe_offset = box_num (lt->lt_2pc._2pc_logged);
      txa_write ();
    }
}

static caddr_t
bif_txa_get_all_trx (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  if (txi.txi_parsed_info)
    return (caddr_t) txa_serialize (txi.txi_parsed_info);
  return NEW_DB_NULL;
}


static void
_txa_test ()
{
  int res = txa_open ("trx.xa");
  log_info ("txa_open result = %d", res);
  txa_add_entry (txa_create_entry (box_string ("hello"),
	  box_string ("virtuoso.trx"), 10001, box_string ("PRP")));
  txa_add_entry (txa_create_entry (box_string ("hello1"),
	  box_string ("virtuoso.trx"), 10002, box_string ("PRP")));
  txa_add_entry (txa_create_entry (box_string ("hello2"),
	  box_string ("virtuoso.trx"), 10003, box_string ("CMT")));
  res = txa_write ();
  log_info ("txa_write result = %d", res);
  txi.txi_parsed_info = 0;
  res = txa_open ("trx.xa");
  log_info ("txa_open result = %d", res);
  {
    int idx;
    for (idx = 0; idx < BOX_ELEMENTS_INT (txi.txi_parsed_info); idx++)
      {
	txa_entry_t **ppe = txi.txi_parsed_info;
	log_info ("txe_entry [ %s %s %d %s]",
	    ppe[idx]->txe_id,
	    ppe[idx]->txe_path,
	    unbox (ppe[idx]->txe_offset), ppe[idx]->txe_res);
      }
  }
}

int
server_logmsg_ap (int level, char *file, int line, int mask, char *format,
      va_list ap)
{
  return logmsg_ap (level, file, line, mask, format, ap);
}









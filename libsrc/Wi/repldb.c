/*
 *  repldb.c
 *
 *  $Id$
 *
 *  DB Server side replication support
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

#include "sqlnode.h"
#include "sqlfn.h"
#include "log.h"
#include "repl.h"
#include "replsr.h"
#include "wirpce.h"
#include "sqlbif.h"
#include "datesupp.h"

/* Receiving Replication */

#define REPL_FREE 0
#define REPL_TO_DISCONNECT -1
#define REPL_DO_RECONNECT -2  /* If the subscription is disconnected by full queue reason */

#define REPL_THREAD_SZ future_thread_sz

client_connection_t *repl_cli;
dk_session_t *repl_str_in;
basket_t repl_in_queue;
dk_thread_t *repl_thread;
dk_mutex_t *repl_in_q_mtx;
semaphore_t *repl_ready_sem;
dk_set_t servers;
dk_set_t repl_accounts;
dk_mutex_t *repl_accounts_mtx;
client_connection_t *repl_util_cli;
dk_mutex_t *repl_uc_mtx;

static void repl_sync (repl_acct_t * ra, char * usr, char * pwd);

static int
repl_input_ready (dk_session_t * ses)
{
  remove_from_served_sessions (ses);
  mutex_enter (repl_in_q_mtx);
  basket_add (&repl_in_queue, (void *) ses);
  mutex_leave (repl_in_q_mtx);
  semaphore_leave (repl_ready_sem);
  return 0;
}

/*Note: this macro suppose that header is an array an empty account is a signal for resync */
#define IS_REPL_DISC(h)		(h[LOGH_REPLICATION] && !(((caddr_t *) h [LOGH_REPLICATION]) [REPLH_ACCOUNT]))

#ifndef VIRTTP
#define MIN_LOG_HEADER_LENGTH LOG_HEADER_LENGTH
#else
#define MIN_LOG_HEADER_LENGTH LOG_HEADER_LENGTH_OLD
#endif

int
repl_check_header (caddr_t * header)
{
#if 1
  caddr_t * replh;
  if (!IS_BOX_POINTER(header) || BOX_ELEMENTS(header) < MIN_LOG_HEADER_LENGTH)
    {
      if (IS_BOX_POINTER (header))
	log_error ("Bad log replication header len (%d). The connection will be terminated.",
	    BOX_ELEMENTS(header));
      return 0;
    }
  replh = (caddr_t *)header[LOGH_REPLICATION];
  if (!IS_BOX_POINTER(replh) || BOX_ELEMENTS(replh) < REPLH_CIRCULATION)
    {
      if (IS_BOX_POINTER(replh))
	log_error ("Bad replication header len (%d). The connection will be terminated.",
	    BOX_ELEMENTS(replh));
      else
	log_error ("Bad replication header. The connection will be terminated.");
      return 0;
    }
#endif
  return 1;
}

static void
repl_process_message (dk_session_t * ses)
{
  scheduler_io_data_t trx_sio;
  size_t bytes;
  caddr_t *header;
  caddr_t trx_string;
  header = (caddr_t *) PrpcReadObject (ses);
  /* check for header length and replication structure if present */
  if (!header || DKSESSTAT_ISSET (ses, SST_BROKEN_CONNECTION)
      || !repl_check_header(header))
    {
      if (DKS_DB_DATA (ses)->cli_repl_pending != REPL_DO_RECONNECT) /*If isn't disconnected by full queue*/
        DKS_DB_DATA (ses)->cli_repl_pending = REPL_TO_DISCONNECT;
    }
  else
    {
      bytes = (size_t) unbox (header[LOGH_BYTES]);
      if (bytes)
	{
	  trx_string = dk_alloc (bytes);
	  CATCH_READ_FAIL (ses)
	    {
	      session_buffered_read (ses, trx_string, bytes);
	    }
	  END_READ_FAIL (ses);
	  memset (&trx_sio, 0, sizeof (trx_sio));
	  if (!SESSION_SCH_DATA (repl_str_in))
	    SESSION_SCH_DATA (repl_str_in) = &trx_sio;

	  if (DKSESSTAT_ISSET (ses, SST_BROKEN_CONNECTION))
	    {
	      dk_free_tree ((caddr_t) header);
	      DKS_DB_DATA (ses)->cli_repl_pending = REPL_TO_DISCONNECT;
	      dk_free (trx_string, bytes);
	      return;
	    }
	  else
	    {
              repl_acct_t *ra;

	      repl_str_in->dks_in_buffer = trx_string;
	      repl_str_in->dks_in_read = 0;
	      repl_str_in->dks_in_fill = bytes;
	      repl_cli->cli_session = ses;
              ra = (repl_acct_t *) DKS_DB_DATA(ses)->cli_ra;
              if (!set_user_id (repl_cli, ra->ra_sync_user, NULL))
                {
                  log_error ("Can't set user to '%s' for account '%s' from '%s'.",
                      ra->ra_sync_user, ra->ra_account, ra->ra_server);
                  dk_free_tree ((caddr_t) header);
                  DKS_DB_DATA (ses)->cli_repl_pending = REPL_TO_DISCONNECT;
	          dk_free (trx_string, bytes);
                  return;
                }
	      if (LTE_OK == log_replay_trx (repl_str_in, repl_cli,
					    (caddr_t) header, 1, 0))
		{
		}
	      else
		{
		  log_error ("(%s, %s): Can't replay replication feed.",
                      ra->ra_server, ra->ra_account);
		  DKS_DB_DATA (ses)->cli_repl_pending = REPL_TO_DISCONNECT;
		}

	      dk_free (trx_string, bytes);
	    }
	}
      else if (IS_REPL_DISC(header))
	{ /* if we receive queue full follow disconnect message then mark session to reconnect
	   and we will try one time to sync via replication log */
	  DKS_DB_DATA (ses)->cli_repl_pending = REPL_DO_RECONNECT;
	  dk_free_tree ((caddr_t) header);
	  return;
	}
      else
        {
          lock_trx_t *lt = NULL;
          caddr_t *replh = (caddr_t *) header[LOGH_REPLICATION];

          /*
           * there can be two cases here:
           * - sync notice (zero REPLH_LEVEL)
           * - no data (non-zero REPLH_LEVEL)
           */
          if (replh && replh[REPLH_LEVEL])
            {
              IN_TXN;
	      lt = cli_set_new_trx (repl_cli);
	      lt_threads_set_inner (lt, 1);
              lt->lt_replicate = REPL_LOG;
            }
	  logh_set_level (lt, header);
          if (lt)
            {
              lt_commit (lt, TRX_CONT);
	      lt_leave (lt);
              LEAVE_TXN;
            }
        }

      DKS_DB_DATA (ses)->cli_repl_pending = REPL_FREE;
    }
  dk_free_tree ((caddr_t) header);
}

static void
repl_base_loop (void)
{
  timeout_t zero_timeout = {0, 0};
  int ctr;
  dk_session_t *ses;
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_IMMEDIATE_CLIENT, repl_cli);
  for (;;)
    {
      semaphore_enter (repl_ready_sem);
      mutex_enter (repl_in_q_mtx);
      ses = (dk_session_t *) basket_get (&repl_in_queue);
      mutex_leave (repl_in_q_mtx);
      if (!_thread_sched_preempt)
	SESSION_SCH_DATA (ses)->sio_default_read_ready_action = NULL;

      for (ctr = 0; ; ctr++)
	{
          int pending;
          repl_acct_t *ra = (repl_acct_t *) DKS_DB_DATA (ses)->cli_ra;

          if (ra->ra_synced == RA_TO_DISCONNECT)
            {
              dbg_printf (("repl_base_loop: RA_TO_DISCONNECT: account '%s' (server '%s')",
                  ra->ra_account, ra->ra_server));
              ra->ra_synced = RA_DISCONNECTED;
              DKS_DB_DATA(ses)->cli_repl_pending = REPL_TO_DISCONNECT;
            }
          else
	    repl_process_message (ses);

          pending = DKS_DB_DATA (ses)->cli_repl_pending;
          if (pending == REPL_TO_DISCONNECT || pending == REPL_DO_RECONNECT)
	    {
	      log_info ("Replication server %s disconnected, level of %s is %d.",
		  ra->ra_server, ra->ra_account,
                  ra_trx_no (ra));
              if (ra->ra_synced != RA_DISCONNECTED)
		ra->ra_synced = RA_REMOTE_DISCONNECTED;
	      PrpcDisconnect (ses);
	      /* as client_connection_t is moved together with the session,
		 it must be freed */
	      client_connection_free (DKS_DB_DATA (ses));
	      DKS_DB_DATA (ses) = NULL;
	      PrpcSessionFree (ses);
	      if (pending == REPL_DO_RECONNECT) /* The publication was disconnected because replication queue is full on publisher server*/
		{
                  QR_RESET_CTX
                    {
		      repl_sync (ra, NULL, NULL); /* we will try to reconnect and send sync message
						       the sync will be done via replication log */
		      log_info ("Sync request sent to publishing server '%s' for account '%s' as '%s'.",
                          ra->ra_server, ra->ra_account, ra->ra_usr);
                    }
                  QR_RESET_CODE
                    {
                      du_thread_t * self = THREAD_CURRENT_THREAD;
                      caddr_t err = thr_get_error_code (self);
                      log_error ("repl_sync: SQL Error: %s : %s",
                          ((caddr_t *) err)[1], ((caddr_t *) err)[2]);
		      dk_free_tree (err);
                    }
                  END_QR_RESET
		}
	      break;
	    }
	  else if (ctr > 20)
	    {
	      if (!_thread_sched_preempt)
		SESSION_SCH_DATA (ses)->sio_default_read_ready_action =
		    repl_input_ready;
	      PrpcCheckInAsync (ses);
	      break;
	    }
	  else
	    {
              /*
               *  Because tcpses_is_read_ready with zero timeout with fibers
               *  always returns with ready, we need to cheat here.
               */
              if (!_thread_sched_preempt)
                {
                  zero_timeout = dks_fibers_blocking_read_default_to;
                }

	      tcpses_is_read_ready (ses->dks_session, &zero_timeout);
	      if (SESSTAT_ISSET (ses->dks_session, SST_TIMED_OUT))
		{
		  if (!_thread_sched_preempt)
		    SESSION_SCH_DATA (ses)->sio_default_read_ready_action =
			repl_input_ready;
		  PrpcCheckInAsync (ses);
		  break;
		}
	      TC (tc_repl_connect_quick_reuse);
	    }
	}
    }
}

char *
repl_peer_name (repl_acct_t * ra)
{
  char *p;

  /*
   * ra->ra_server + space + ra->ra_account + trailing NUL
   */
  p = dk_alloc_box (
      strlen (ra->ra_server) + 1 + strlen (ra->ra_account) + 1, DV_C_STRING);
  snprintf (p, box_length (p), "%s %s", ra->ra_server, ra->ra_account);
  return p;
}

static dk_session_t *
repl_connect (char * addr, repl_acct_t * ra)
{
  dk_session_t *ses = PrpcConnect (addr, SESCLASS_TCPIP);
  if (!DKSESSTAT_ISSET (ses, SST_OK))
    {
      PrpcDisconnect (ses);
      PrpcSessionFree (ses);
      log_error ("Failed connect to '%s'.", addr);
      return NULL;
    }

  if (!_thread_sched_preempt)
    ses->dks_read_block_timeout = dks_fibers_blocking_read_default_to;
  DKS_DB_DATA (ses) = client_connection_create ();
  DKS_DB_DATA (ses)->cli_ra = (void *) ra;

  SESSION_SCH_DATA (ses)->sio_default_read_ready_action = repl_input_ready;
  dk_free_box (ses->dks_peer_name);
  ses->dks_peer_name = repl_peer_name (ra);
  log_info ("Connected to replication server '%s'.", addr);
  return ses;
}

static char *read_repl_text =
"(seq (from SYS_REPL_ACCOUNTS (SERVER ACCOUNT LEVEL IS_MANDATORY IS_UPDATEABLE SYNC_USER P_MONTH P_DAY P_WDAY P_TIME) by SYS_REPL_ACCOUNTS prefix R)"
"     (select (R.SERVER R.ACCOUNT R.LEVEL R.IS_MANDATORY R.IS_UPDATEABLE R.SYNC_USER R.P_MONTH R.P_DAY R.P_WDAY R.P_TIME)))";

static char *ra_add_text =
"(seq (insert SYS_REPL_ACCOUNTS (NTH SERVER ACCOUNT LEVEL)(:N :SR :AC :L))(end))";

#if 0
static char *ra_upd_text =
"(seq (from SYS_REPL_ACCOUNTS (LEVEL) by SYS_REPL_ACCOUNTS prefix R "
"          where ((SERVER = :SR) (ACCOUNT = :AC)))"
"  (update SYS_REPL_ACCOUNTS R (LEVEL :L)) (end))";
#endif

static char *sa_read_text =
"(seq (from SYS_SERVERS (SERVER DB_ADDRESS REPL_ADDRESS) by SYS_SERVERS prefix S)"
"    (select (S.SERVER S.DB_ADDRESS S.REPL_ADDRESS)))";

static char *rs_read_text =
  "(seq (from SYS_REPL_SUBSCRIBERS (RS_SERVER RS_ACCOUNT RS_SUBSCRIBER RS_LEVEL RS_VALID) by SYS_REPL_SUBSCRIBERS prefix S)"
  "  (select (S.RS_SERVER S.RS_ACCOUNT S.RS_SUBSCRIBER S.RS_VALID S.RS_LEVEL)))";

static char *rs_save_text =
  "insert replacing SYS_REPL_SUBSCRIBERS"
  "    (RS_SERVER, RS_ACCOUNT, RS_SUBSCRIBER, RS_LEVEL, RS_VALID) "
  "values (?, ?, ?, ?, ?)";

static query_t *read_repl_qr;
static query_t *ra_add_qr;
static query_t *sa_read_qr;
static query_t *rs_read_qr;
static query_t *rs_save_qr;
#if 0
static query_t *ra_upd_qr;
#endif


repl_acct_t *
ra_find (char * server, char * account)
{
  if (!account)
    account = server;
  DO_SET (repl_acct_t *, ra, &repl_accounts)
  {
    if (0 == strcmp (ra->ra_server, server) &&
        0 == strcmp (ra->ra_account, account))
      return ra;
  }
  END_DO_SET ();
  return NULL;
}

repl_acct_t *
ra_find_pushback (char * server, char * account)
{
  if (!account)
    account = server;
  DO_SET (repl_acct_t *, ra, &repl_accounts)
  {
    if (0 == strcmp (ra->ra_server, server) &&
        RA_IS_PUSHBACK(ra->ra_account) &&
        0 == strcmp (ra->ra_account + 1, account))
      return ra;
  }
  END_DO_SET ();
  return NULL;
}

repl_acct_t *
ra_add (char *server, char *account, repl_level_t level, int mand, int is_updatable)
{
  char tmp[2000];
  NEW_VARZ (repl_acct_t, ra);
  if (!account)
    account = server;
  ra->ra_server = box_string (server);
  ra->ra_account = box_dv_short_string (account);
  ra->ra_level = level;
  ra->ra_is_mandatory = mand;
  ra->ra_is_updatable = is_updatable;
  ra->ra_synced = RA_OFF;
  snprintf (tmp, sizeof (tmp), "%s_%s_%s",
          RA_IS_PUSHBACK(ra->ra_account) ? "replback" : "repl",
          ra->ra_server, account);
  ra->ra_sequence = box_string (tmp);
  if (RA_IS_PUSHBACK(ra->ra_account))
    {
      snprintf (tmp, sizeof (tmp), "replbackpub_%s_%s", ra->ra_server, account);
      ra->ra_pub_sequence = box_string (tmp);
    }
  ra->ra_parent = NULL;
  ra->ra_subscribers = id_hash_allocate (
      101, sizeof (caddr_t), sizeof (caddr_t), strhash, strhashcmp);
  repl_accounts = dk_set_conc (repl_accounts, dk_set_cons ((caddr_t) ra, NULL));

#if 0
  dbg_printf_1 (("ra_server: '%s', ra_account: '%s', ra_sequence: '%s', ra_is_mandatory: %d, ra_is_updatable: %d",
          ra->ra_server, ra->ra_account, ra->ra_sequence, ra->ra_is_mandatory,
          ra->ra_is_updatable));
#endif

  return ra;
}

/*
 * Assumes that repl_accounts_mtx is held
 */
repl_subscriber_t *
rs_find (repl_acct_t *ra, char *subscriber)
{
  repl_subscriber_t **rs_ptr;
  if (!ra)
    return NULL;

  rs_ptr = (repl_subscriber_t **) id_hash_get (
      ra->ra_subscribers, (caddr_t) &subscriber);
  return rs_ptr == NULL ? NULL : *rs_ptr;
}

/*
 * Add new subscriber for replication account
 *
 * Assumes that repl_accounts_mtx is held.
 * Assumes that subscriber does not exist in ra->ra_subscribers
 */
static repl_subscriber_t *
rs_add (repl_acct_t *ra, char *subscriber, int level, int valid)
{
  NEW_VARZ (repl_subscriber_t, rs);

  subscriber = box_string (subscriber);
  rs->rs_subscriber = box_string (subscriber);
  rs->rs_level = level;
  rs->rs_valid = valid;
  id_hash_set (ra->ra_subscribers, (caddr_t) &subscriber, (caddr_t) &rs);
  dbg_printf_1 (("rs_add: (%s, %s) (%s, %d, %d)",
      ra->ra_server, ra->ra_account,
      rs->rs_subscriber, rs->rs_level, rs->rs_valid));
  rs = rs_find (ra, subscriber);
  assert (rs != NULL);
  return rs;
}

/*
 * Assumes that repl_accounts_mtx is held.
 * Assumes that rs does not exist in SYS_REPL_SUBSCRIBERS
 * and is already added to ra->ra_subscribers
 */
static void
save_subscriber (query_instance_t *qi,
    repl_acct_t *ra, repl_subscriber_t *rs)
{
  caddr_t err;

  dbg_printf_1 (("save_subscriber: (%s, %s) (%s, %d, %d)",
      ra->ra_server, ra->ra_account,
      rs->rs_subscriber, rs->rs_level, rs->rs_valid));
  if (qi)
    {
      err = qr_rec_exec (rs_save_qr, qi->qi_client, NULL, qi, NULL, 5,
          ":0", ra->ra_server, QRP_STR,
          ":1", ra->ra_account, QRP_STR,
          ":2", rs->rs_subscriber, QRP_STR,
          ":3", (ptrlong) rs->rs_level, QRP_INT,
          ":4", (ptrlong) rs->rs_valid, QRP_INT);
      if ((caddr_t) SQL_SUCCESS != err)
        sqlr_resignal (err);
    }
  else
    {
      lock_trx_t *lt;

      mutex_enter (repl_uc_mtx);
      IN_TXN;
      lt = cli_set_new_trx (repl_util_cli);
      lt_threads_set_inner (lt, 1);
      lt->lt_replicate = REPL_LOG;
      LEAVE_TXN;

      err = qr_quick_exec (rs_save_qr, repl_util_cli, "", NULL, 5,
          ":0", ra->ra_server, QRP_STR,
          ":1", ra->ra_account, QRP_STR,
          ":2", rs->rs_subscriber, QRP_STR,
          ":3", (ptrlong) rs->rs_level, QRP_INT,
          ":4", (ptrlong) rs->rs_valid, QRP_INT);
      if ((caddr_t) SQL_SUCCESS != err)
        {
          IN_TXN;
          lt_rollback (lt, TRX_CONT);
	  lt_leave (lt);
          LEAVE_TXN;
          log_error ("repl_sync_acct: SQL Error: %s : %s",
              ((caddr_t *) err)[1], ((caddr_t *) err)[2]);
        }
      else
        {
          IN_TXN;
          lt_commit (lt, TRX_CONT);
	  lt_leave (lt);
          LEAVE_TXN;
        }
      mutex_leave (repl_uc_mtx);
    }
}

repl_subscriber_t *
repl_save_subscriber (repl_acct_t *ra, char *subscriber, int level, int valid)
{
  repl_subscriber_t *rs;

  mutex_enter (repl_accounts_mtx);
  if ((rs = rs_find(ra, subscriber)) == NULL)
    rs = rs_add (ra, subscriber, level, valid);
  else
    {
      rs->rs_level = level;
      rs->rs_valid = valid;
      dbg_printf_1 (("repl_save_subscriber_1: (%d, %d)",
        rs->rs_level, rs->rs_valid));
    }
  save_subscriber (NULL, ra, rs);
  mutex_leave (repl_accounts_mtx);

  return rs;
}

repl_level_t
ra_new_trx_no (lock_trx_t * lt, repl_acct_t * ra)
{
  repl_level_t  no;
  ASSERT_IN_TXN;
  if (!ra)
    return 1;
  no = sequence_next (ra->ra_sequence, INSIDE_MAP);
  if (0 == no)
    no = sequence_next (ra->ra_sequence, INSIDE_MAP);
  if (REPL_WRAPAROUND == no)
    {
      caddr_t log_array;

      log_array = list (4, box_string ("sequence_set (?, ?, ?)"),
	    box_string (ra->ra_pub_sequence), box_num (1), box_num (SET_ALWAYS));
      sequence_set (ra->ra_sequence, 1, SET_ALWAYS, INSIDE_MAP);
      log_text_array (lt, log_array);
      dk_free_tree (log_array);
      no = sequence_next (ra->ra_sequence, INSIDE_MAP);
    }
#if 0
  log_info ("ra_new_trx_no: %s: account %s: level %ld",
      db_name, ra->ra_account, no);
#endif
  return no;
}

repl_level_t
ra_trx_no (repl_acct_t * ra)
{
  return (sequence_set (ra->ra_sequence, 0, SEQUENCE_GET, OUTSIDE_MAP));
}

repl_level_t
ra_pub_trx_no(repl_acct_t *ra)
{
  return (sequence_set (ra->ra_pub_sequence, 0, SEQUENCE_GET, OUTSIDE_MAP));
}

void
ra_set_pub_trx_no(repl_acct_t *ra, repl_level_t level)
{
  lock_trx_t *lt;
  caddr_t log_array;

  log_array = list (4, box_string ("sequence_set (?, ?, ?)"),
	box_string (ra->ra_pub_sequence), box_num (level), box_num (SET_ALWAYS));
  mutex_enter (repl_uc_mtx);
  IN_TXN;
  lt = cli_set_new_trx (repl_util_cli);
  lt_threads_set_inner (lt, 1);
  lt->lt_replicate = REPL_LOG;
  sequence_set (ra->ra_pub_sequence, level, SET_ALWAYS, INSIDE_MAP);
  log_text_array (lt, log_array);
  dk_free_tree (log_array);
  lt_commit (lt, TRX_CONT);
  lt_leave (lt);
  LEAVE_TXN;
  mutex_leave (repl_uc_mtx);
}

static server_addr_t *
sa_find (char *server)
{
  DO_SET (server_addr_t *, sa, &servers)
  {
    if (0 == strcmp (sa->sa_server, server))
      return sa;
  }
  END_DO_SET ();
  return NULL;
}

static local_cursor_t *
repl_qr_exec (query_t *qr, client_connection_t *cli, query_instance_t *qi)
{
  caddr_t err;
  local_cursor_t *lc;

  if (qi)
    err = qr_rec_exec (qr, qi->qi_client, &lc, qi, NULL, 0);
  else
    err = qr_quick_exec (qr, cli, "", &lc, 0);
  if ((caddr_t) SQL_SUCCESS != err)
    sqlr_resignal (err);

  return lc;
}

static void
sa_read_db (client_connection_t * cli, query_instance_t * qi)
{
  local_cursor_t *lc;

  if (!sa_read_qr)
    {
      sqlr_new_error ("08001", "TR072",
          "Can't read replication addresses: NULL qr.");
    }

  lc = repl_qr_exec (sa_read_qr, cli, qi);
  while (lc_next (lc))
    {
      char *server = lc_get_col (lc, "S.SERVER");
      server_addr_t *sa = sa_find (server);
      if (!sa)
	{
	  NEW_VARZ (server_addr_t, new_sa);
	  sa = new_sa;
	  dk_set_push (&servers, (void *) sa);
	}
      sa->sa_server = box_string (server);
      sa->sa_repl_address = box_string (lc_get_col (lc, "S.REPL_ADDRESS"));
      sa->sa_db_address = box_string (lc_get_col (lc, "S.DB_ADDRESS"));
    }
  lc_free (lc);
}

static ptrlong
unbox_null_ck (caddr_t box)
{
  if (IS_BOX_POINTER (box) && box_tag (box) != DV_LONG_INT)
    return 0;
  else
    return (unbox (box));
}

static void
rs_read_db (client_connection_t *cli, query_instance_t *qi)
{
  local_cursor_t *lc;

  if (!rs_read_qr)
    {
      sqlr_new_error ("08001", "TR072",
          "Can't read replication subscribers: NULL qr.");
    }

  lc = repl_qr_exec (rs_read_qr, cli, qi);

  DO_SET (repl_acct_t *, ra, &repl_accounts)
    {
      id_hash_clear (ra->ra_subscribers);
    }
  END_DO_SET ();

  while (lc_next (lc))
    {
      char *server = lc_get_col (lc, "S.RS_SERVER");
      char *account = lc_get_col (lc, "S.RS_ACCOUNT");
      repl_acct_t *ra = ra_find (server, account);
      repl_subscriber_t *rs;
      char *subscriber;

      if (!ra)
        {
          log_error ("rs_read_db: (%s, %s): No such replication account.",
              server, account);
          continue;
        }

      subscriber = lc_get_col (lc, "S.RS_SUBSCRIBER");
      mutex_enter (repl_accounts_mtx);
      if ((rs = rs_find (ra, subscriber)) == NULL)
        {
          rs_add (ra,
              lc_get_col (lc, "S.RS_SUBSCRIBER"),
              (int) unbox_null_ck (lc_get_col (lc, "S.RS_LEVEL")),
              (int) unbox_null_ck (lc_get_col (lc, "S.RS_VALID")));
        }
      else
        {
          rs->rs_level = (int) unbox_null_ck (lc_get_col (lc, "S.RS_LEVEL"));
          rs->rs_valid = (int) unbox_null_ck (lc_get_col (lc, "S.RS_VALID"));
        }
      mutex_leave (repl_accounts_mtx);
    }
  lc_free (lc);
}

static void
ra_read_db (client_connection_t * cli, query_instance_t * qi, int read_levels)
{
  local_cursor_t *lc;

  if (!read_repl_qr)
    {
      sqlr_new_error ("08001", "TR072",
          "Can't read replication accounts: NULL qr.");
    }

  lc = repl_qr_exec (read_repl_qr, cli, qi);
  while (lc_next (lc))
    {
      char *srv = lc_get_col (lc, "R.SERVER");
      char *acct = lc_get_col (lc, "R.ACCOUNT");
      repl_acct_t *ra = ra_find (srv, acct);
      caddr_t dt, sync_user;

      if (!repl_server_enable &&
	  (!db_name || !srv || strcmp (db_name, srv) || !acct || strcmp (db_name, acct)))
	{
	  log_error (
	      "The database has transactional replication roles defined, "
	      "but the Server is not enabled for transactional replication."
	      " Please re-enable the transactional replication support ("
	      " by setting the INI setting ServerEnable to 1) and restart"
	      " the server.");
	  call_exit (-1);
	}
      if (!ra)
	{
	  ra = ra_add (srv, acct,
	      (int) unbox_null_ck (lc_get_col (lc, "R.LEVEL")),
	      (int) unbox_null_ck (lc_get_col (lc, "R.IS_MANDATORY")),
	      (int) unbox_null_ck (lc_get_col (lc, "R.IS_UPDATEABLE")));
	}
      else if (read_levels)
        {
	  ra->ra_level = (int) unbox_null_ck (lc_get_col (lc, "R.LEVEL"));
	}

      if (ra->ra_sync_user)
        dk_free_box (ra->ra_sync_user);
      sync_user = lc_get_col (lc, "R.SYNC_USER");
      if (IS_STRING_DTP (DV_TYPE_OF (sync_user)) &&
          0 != strcmp (sync_user, ""))
        ra->ra_sync_user = box_string (sync_user);
      else
        ra->ra_sync_user = box_string ("dba");

      ra->ra_p_month = (int) unbox_null_ck (lc_get_col (lc, "R.P_MONTH"));
      ra->ra_p_day = (int) unbox_null_ck (lc_get_col (lc, "R.P_DAY"));
      ra->ra_p_wday = (int) unbox_null_ck (lc_get_col (lc, "R.P_WDAY"));
      dt = lc_get_col (lc, "R.P_TIME");
      if (ra->ra_p_time)
        {
          dk_free (ra->ra_p_time, sizeof (*ra->ra_p_time));
          ra->ra_p_time = NULL;
        }
      if (DV_TYPE_OF (dt) == DV_DATETIME)
        {
          ra->ra_p_time = (TIME_STRUCT *) dk_alloc (sizeof (*ra->ra_p_time));
          dt_to_time_struct (dt, ra->ra_p_time);
          dbg_printf_1 (("%s: %d:%d",
              acct, ra->ra_p_time->hour, ra->ra_p_time->minute));
        }
    }
  lc_free (lc);
  if (db_name)
    {
      if (!ra_find (db_name, db_name))
	{
          caddr_t err;

	  ra_add (db_name, db_name, LEVEL_0, 0, 0);
	  err = qr_quick_exec (ra_add_qr, cli, "", NULL, 4,
	      ":N", (ptrlong) 0, QRP_INT,
	      ":SR", db_name, QRP_STR,
	      ":AC", db_name, QRP_STR,
	      ":L", (ptrlong) 1, QRP_INT);
          if (err != (caddr_t) SQL_SUCCESS)
            sqlr_resignal (err);
	}

      /*
       * link parent
       */
      DO_SET (repl_acct_t *, ra, &repl_accounts)
        {
          if (ra->ra_is_updatable &&
              !RA_IS_PUSHBACK(ra->ra_account) &&
              !!strcmp (ra->ra_server, db_name))
            {
              DO_SET (repl_acct_t *, ra2, &repl_accounts)
                {
                  if (ra2->ra_is_updatable &&
                      RA_IS_PUSHBACK(ra2->ra_account) &&
                      !strcmp(ra->ra_server, ra2->ra_server) &&
                      !strcmp(ra->ra_account, ra2->ra_account + 1))
                    {
                      dbg_printf_1 (("(%s, %s) <- (%s, %s)",
                          ra->ra_server, ra->ra_account,
                          ra2->ra_server, ra2->ra_account));
                      ra2->ra_parent = ra;
                    }
                }
              END_DO_SET ();
            }
        }
      END_DO_SET ();
    }
}

#if 0
void
ra_update_db (client_connection_t * cli)
{
  DO_SET (repl_acct_t *, ra, &repl_accounts)
  {
    qr_quick_exec (ra_upd_qr, cli, "", NULL, 3,
	":SR", ra->ra_server, QRP_STR,
	":AC", ra->ra_account, QRP_STR,
	":L", (ptrlong) ra->ra_level, QRP_INT);
  }
  END_DO_SET ();
}
#endif

char *
repl_server_to_address (char * srv)
{
  server_addr_t *sa = sa_find (srv);
  if (sa)
    return (sa->sa_repl_address);
  else
    return NULL;
}

int
repl_sync_acct (repl_acct_t * ra, char * _usr, char * _pwd)
{
  char *usr, *pwd;
  char *addr = repl_server_to_address (ra->ra_server);
  int saved_stat = ra->ra_synced;
  char *hashed_pwd;
  char *subscriber_name;
  dk_session_t *ses = NULL; /* PrpcFindPeer (ra->ra_server); */

  if (!addr)
    return -1;

  usr = _usr ? _usr : ra->ra_usr;
  pwd = _pwd ? _pwd : ra->ra_pwd;
  if (!usr || !pwd) /* We must be sure that user/password are not null */
    return -1;

  if (RA_IN_SYNC == ra->ra_synced || RA_SYNCING == ra->ra_synced)
    return 0;

  ra->ra_synced = RA_SYNCING; /* because the connection can be slow we first set the status
				     if can't connect revert the status */
  if (!ses)
    {
      ses = repl_connect (addr, ra);
      if (!ses || !DKSESSTAT_ISSET (ses, SST_OK))
	{
	  ra->ra_synced = saved_stat;
	  sqlr_new_error ("08001", "TR072", "Replication connect to %s failed.", addr);
	}
    }

  log_info ("Requesting sync from '%s' for '%s' level %ld.",
      ra->ra_server, ra->ra_account, ra_trx_no (ra));
  hashed_pwd = dk_alloc_box (17, DV_SHORT_STRING);
  sec_login_digest (ses->dks_own_name, usr, pwd, (unsigned char *) hashed_pwd);
  hashed_pwd[16] = 0;
  subscriber_name = box_dv_short_string (db_name);
  PrpcFutureFree (PrpcFuture (ses, &s_resync_acct,
      ra->ra_account, ra_trx_no (ra), subscriber_name, usr, hashed_pwd));
  dk_free_box (hashed_pwd);
  dk_free_box (subscriber_name);

  if (_usr)
    {
      dk_free_box (ra->ra_usr);
      ra->ra_usr = box_copy (_usr);
    }
  if (_pwd)
    {
      dk_free_box (ra->ra_pwd);
      ra->ra_pwd = box_copy (_pwd);
    }
  return 0;
}

#if 0
static caddr_t *
repl_make_spec (caddr_t * spec)
{
  caddr_t *repl;
  int len;
  if (!spec || !IS_POINTER (spec))
    return spec;
  if (!db_name)
    return REPL_LOG;
  len = box_length ((caddr_t) spec);
  repl = (caddr_t *) dk_alloc_box (2 * sizeof (caddr_t) + len,
      DV_ARRAY_OF_POINTER);
  repl[REPLH_SERVER] = box_string (db_name);
  repl[REPLH_ACCOUNT] = spec[0];
  repl[REPLH_LEVEL] = 0;
  memcpy (&repl[REPLH_CIRCULATION], &spec[1], len - sizeof (caddr_t));
  dk_free_box (spec);
  return (repl);
}
#endif

void
repl_read_db_levels (void)
{
  ra_read_db (bootstrap_cli, NULL, 1);
  local_commit (bootstrap_cli);
  IN_TXN;
  lt_leave (bootstrap_cli->cli_trx);
  LEAVE_TXN;
}

/* DISCONNECT REPLICATION command */

static caddr_t
bif_repl_disconnect (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t server = bif_string_arg (qst, args, 0, "repl_disconnect");
  (void) err_ret;

  if (0 == strlen (server))
    server = NULL;

  DO_SET (repl_acct_t *, ra, &repl_accounts)
    {
      dk_set_t peers;
      char *peer_name;

      if (server && 0 != strcmp (server, ra->ra_server))
        goto next_acct;

      peers = PrpcListPeers ();
      peer_name = repl_peer_name (ra);
      DO_SET (dk_session_t *, ses, &peers)
        {
          if (!ses->dks_peer_name || !!strcmp (ses->dks_peer_name, peer_name))
            continue;

          if (RA_IS_PUSHBACK(ra->ra_account))
            repl_sub_dropped(&repl_push_queue, ses);
          else
            {
	      PrpcDisconnect (ses);
              ra->ra_synced = RA_DISCONNECTED;
            }
        }
      END_DO_SET ();
      dk_set_free (peers);
      dk_free_box (peer_name);

    next_acct:
      ;
    }
  END_DO_SET ();

  return 0;
}

static void
repl_sync (repl_acct_t * ra, char * usr, char * pwd)
{
  if (ra->ra_is_updatable && repl_sync_updatable_acct (ra, usr, pwd) < 0)
    return;

  repl_sync_acct (ra, usr, pwd);
}

/* bif interface */

static caddr_t
bif_repl_sync (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  repl_acct_t * ra;
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  char * server = bif_string_arg (qst, args, 0, "repl_sync");
  char * account = bif_string_arg (qst, args, 1, "repl_sync");
  char * usr = bif_string_arg (qst, args, 2, "repl_sync");
  char * pwd = bif_string_arg (qst, args, 3, "repl_sync");
  (void) err_ret;

  ra_read_db (NULL, qi, 0);
  ra = ra_find (server, account);
  if (!ra)
    {
      sqlr_new_error ("37000", "TR067",
          "No replication account '%s' (server '%s')", account, server);
    }

  repl_sync (ra, usr, pwd);
  return box_num (ra->ra_synced);
}

static caddr_t
bif_repl_status (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *source = bif_string_arg (qst, args, 0, "repl_status");
  char *account = bif_string_arg (qst, args, 1, "repl_status");
  repl_acct_t *ra;
  (void) err_ret;

  bif_arg (qst, args, 3, "repl_status"); /* check arg count */
  ra = ra_find (source, account);
  if (!ra)
    sqlr_new_error ("37000", "TR068", "No such account");
  if (RA_IS_PUSHBACK(ra->ra_account))
    qst_set (qst, args[2], box_num (ra_pub_trx_no (ra)));
  else
    qst_set (qst, args[2], box_num (ra_trx_no (ra)));
  qst_set (qst, args[3], box_num (ra->ra_synced));

  PROCESS_ALLOW_SCHEDULE();
  return NULL;
}

static caddr_t
bif_this_server (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  (void) qst;
  (void) err_ret;
  (void) args;

  if (db_name)
    {
      caddr_t box = box_dv_short_string (db_name);
      return box;
    }
  else
    sqlr_new_error ("37000", "TR069", "Server must have a DBName entry in its ini file for replication");
  return 0; /*dummy*/
}

static caddr_t
bif_repl_new_log (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t srv = bif_string_arg (qst, args, 0, "repl_new_log");
  caddr_t acct = bif_string_arg (qst, args, 1, "repl_new_log");
  caddr_t file = bif_string_arg (qst, args, 2, "repl_new_log");
  repl_acct_t *ra;
  (void) err_ret;

  if ((ra = ra_find (srv, acct)) == NULL)
    {
      sqlr_new_error ("42000", "TR098",
          "Replication account missing for server '%s', account '%s'.",
          srv, acct);
    }

  if (0 == strlen (file))
    file = NULL;
  repl_trail_new_file (ra, file, 1);
  return 0;
}

static caddr_t
bif_repl_changed (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  (void) err_ret;
  (void) args;

  sa_read_db (NULL, qi);
  ra_read_db (NULL, qi, 0);
  rs_read_db (NULL, qi);
  return 0;
}

static caddr_t
bif_repl_purge (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t srv = bif_string_arg (qst, args, 0, "repl_purge");
  caddr_t acct = bif_string_arg (qst, args, 1, "repl_purge");
  (void) err_ret;

  repl_purge (srv, acct);
  return 0;
}

static caddr_t
bif_repl_add_subscriber (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  caddr_t srv = bif_string_arg (qst, args, 0, "repl_add_subscriber");
  caddr_t acct = bif_string_arg (qst, args, 1, "repl_add_subscriber");
  caddr_t subscriber = bif_string_arg (qst, args, 2, "repl_add_subscriber");
  repl_acct_t *ra;
  repl_subscriber_t *rs;
  (void) err_ret;

  if ((ra = ra_find (srv, acct)) == NULL)
    {
      sqlr_new_error ("42000", "TR099",
          "Replication account '%s' from '%s' does not exist",
          acct, srv);
    }

  mutex_enter (repl_accounts_mtx);
  if (rs_find(ra, subscriber))
    {
      mutex_leave (repl_accounts_mtx);
      sqlr_new_error ("42000", "TR100",
          "Subscriber '%s' for account '%s' from '%s' already exists",
          subscriber, acct, srv);
    }
  rs = rs_add (ra, subscriber, 0, 1);
  save_subscriber (qi, ra, rs);
  mutex_leave (repl_accounts_mtx);
  return 0;
}

static caddr_t
bif_repl_update_subscriber (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  caddr_t srv = bif_string_arg (qst, args, 0, "repl_update_subscriber");
  caddr_t acct = bif_string_arg (qst, args, 1, "repl_update_subscriber");
  caddr_t subscriber = bif_string_arg (qst, args, 2, "repl_update_subscriber");
  repl_acct_t *ra;
  repl_subscriber_t *rs;
  (void) err_ret;

  if ((ra = ra_find (srv, acct)) == NULL)
    {
      sqlr_new_error ("42000", "TR101",
          "Replication account '%s' from '%s' does not exist",
          acct, srv);
    }

  if ((rs = rs_find (ra, subscriber)) == NULL)
    {
      sqlr_new_error ("42000", "TR102",
          "Subscriber '%s' for account '%s' from '%s' does not exist",
          subscriber, acct, srv);
    }

  rs->rs_level = (int) bif_long_arg (qst, args, 3, "repl_update_subscriber");
  rs->rs_valid = (int) bif_long_arg (qst, args, 4, "repl_update_subscriber");
  save_subscriber (qi, ra, rs);
  return 0;
}

static caddr_t
bif_repl_is_pushback (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t account = bif_string_arg (qst, args, 1, "repl_update_subscriber");
  (void) err_ret;

  if (!account)
    return 0;
  return box_num (RA_IS_PUSHBACK(account));
}

/* Replication grants */
#ifdef REPLICATION_SUPPORT2
id_hash_t * repl_grants;
static char *repl_grants_tbl =
" create table SYS_TP_GRANT ( "
"        TPG_ACCT 	varchar,"
"        TPG_GRANTEE 	varchar,"
" primary key (TPG_ACCT, TPG_GRANTEE))";

static caddr_t
bif_repl_grant (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t acct = bif_string_arg (qst, args, 0, "__repl_grants");
  caddr_t grnt = bif_string_or_null_arg (qst, args, 1, "__repl_grants");
  caddr_t gkey = NULL;
  caddr_t g_copy = box_copy (grnt);
  (void) err_ret;

  if (acct == NULL)
    sqlr_new_error ("22023", "TR065", "Replication account can not be empty");

  if (grnt != NULL)
    {
      gkey = dk_alloc_box (box_length (acct) + box_length (grnt), DV_SHORT_STRING);
      snprintf (gkey, box_length (gkey), "%s\n%s", acct, grnt);
    }
  else
    {
      gkey = dk_alloc_box (box_length (acct) + 1, DV_SHORT_STRING);
      snprintf (gkey, box_length (gkey), "%s", acct);
    }
  id_hash_set (repl_grants, (caddr_t) & gkey, (caddr_t) & g_copy);
  return (box_num (0));
}

static caddr_t
bif_repl_revoke (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t acct = bif_string_arg (qst, args, 0, "__repl_revoke");
  caddr_t grnt = bif_string_or_null_arg (qst, args, 1, "__repl_revoke");
  caddr_t gkey = NULL;
  caddr_t * kp = NULL;
  caddr_t k;
  caddr_t *place = NULL;
  (void) err_ret;

  if (acct == NULL)
    sqlr_new_error ("22023", "TR066", "Replication account can not be empty");

  if (grnt != NULL)
    {
      gkey = dk_alloc_box (box_length (acct) + box_length (grnt), DV_SHORT_STRING);
      snprintf (gkey, box_length (gkey), "%s\n%s", acct, grnt);
    }
  else
    {
      gkey = dk_alloc_box (box_length (acct) + 1, DV_SHORT_STRING);
      snprintf (gkey, box_length (gkey), "%s", acct);
    }
  place = (caddr_t*) id_hash_get (repl_grants, (caddr_t) & gkey);
  if (place && *place)
    {
      kp = (caddr_t *) id_hash_get_key (repl_grants, (caddr_t) & gkey);
      k = kp ? *kp : NULL;
      if (k)
	dk_free_box (k);
      dk_free_tree (*place);
      id_hash_remove (repl_grants, (caddr_t) & gkey);
    }
  dk_free_box (gkey);
  return (box_num (0));
}

int
get_repl_grants (char *acct, char *user)
{
  caddr_t * place;
  caddr_t gkey = NULL;

  place = (caddr_t *) id_hash_get (repl_grants, (caddr_t) & acct);
  if (place)
    return 1;
  if (user == NULL)
    return 0;
  gkey = dk_alloc_box (strlen (acct) + strlen (user) + 2, DV_SHORT_STRING);
  snprintf (gkey, box_length (gkey), "%s\n%s", acct, user);
  place = (caddr_t *) id_hash_get (repl_grants, (caddr_t) & gkey);
  dk_free_box (gkey);
  if (place)
    return 1;
  return 0;
}
/*End replication grants */
#endif

query_t *
repl_compile (char *text)
{
  caddr_t err = NULL;
  query_t *qr = eql_compile_2 (text, bootstrap_cli, &err, SQLC_DEFAULT);
  if (err)
    {
      log_error ("Error compiling a replication init statement: %s: %s -- %s",
	  ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING],
          text);
      dk_free_tree (err);
      return NULL;
    }
  return qr;
}

void
repl_init (void)
{

  if (!db_name)
    {
      db_name = box_string ("anonymous");
    }

  bif_define ("repl_sync", bif_repl_sync);
  bif_define ("repl_status", bif_repl_status);
  bif_define_typed ("repl_this_server", bif_this_server, &bt_varchar);
  bif_define ("repl_new_log", bif_repl_new_log);
  bif_define ("repl_changed", bif_repl_changed);
  bif_define ("repl_disconnect", bif_repl_disconnect);
  bif_define ("repl_purge", bif_repl_purge);
  bif_define ("repl_add_subscriber", bif_repl_add_subscriber);
  bif_define ("repl_update_subscriber", bif_repl_update_subscriber);
  bif_define ("repl_is_pushback", bif_repl_is_pushback);
#ifdef REPLICATION_SUPPORT2
  bif_define ("__repl_grant", bif_repl_grant);
  bif_define ("__repl_revoke", bif_repl_revoke);

  repl_grants = id_str_hash_create (101);
  ddl_ensure_table ("DB.DBA.SYS_TP_GRANT", repl_grants_tbl);
  ddl_sel_for_effect ("select count (*) from SYS_TP_GRANT where __repl_grant (TPG_ACCT, TPG_GRANTEE)");
#endif

  repl_str_in = strses_allocate ();
  repl_in_q_mtx = mutex_allocate ();
  repl_ready_sem = semaphore_allocate (0);
  repl_accounts_mtx = mutex_allocate ();

  repl_thread = PrpcThreadAllocate ((thread_init_func) repl_base_loop,
      REPL_THREAD_SZ, NULL);
  if (!repl_thread)
    {
      log_error ("Can's start the server because it can't create a system thread. Exiting.");
      GPF_T;
    }

  repl_cli = client_connection_create ();
  repl_cli->cli_is_log = 1;
  repl_util_cli = client_connection_create();
  repl_util_cli->cli_is_log = 1;
  repl_uc_mtx = mutex_allocate();

  read_repl_qr = repl_compile (read_repl_text);
  ra_add_qr = repl_compile (ra_add_text);
  sa_read_qr = repl_compile (sa_read_text);
  rs_read_qr = repl_compile (rs_read_text);
  rs_save_qr = repl_compile (rs_save_text);
#if 0
  ra_upd_qr = eql_compile (ra_upd_text, bootstrap_cli);
#endif

  QR_RESET_CTX
    {
      sa_read_db (bootstrap_cli, NULL);
      ra_read_db (bootstrap_cli, NULL, 0);
      rs_read_db (bootstrap_cli, NULL);
    }
  QR_RESET_CODE
    {
      du_thread_t * self = THREAD_CURRENT_THREAD;
      caddr_t err = thr_get_error_code (self);
      log_error ("repl_init: SQL Error: %s : %s",
          ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING]);
      dk_free_tree (err);
    }
  END_QR_RESET

  local_commit (bootstrap_cli);
  PrpcSuckAvidly (0);
}

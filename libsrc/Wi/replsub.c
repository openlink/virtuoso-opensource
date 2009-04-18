/*
 *  replsub.c
 *
 *  $Id$
 *
 *  Subscriptions routines.
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
 */

#include "sqlnode.h"
#include "log.h"
#include "repl.h"
#include "replsr.h"
#include "security.h"

repl_queue_t repl_queue;

static dk_set_t subscriptions;

static void send_sync_notice (subscription_t * sub, repl_level_t level);
static void sub_send_blobs (subscription_t * sub, repl_message_t * rm,
        dk_session_t * volatile log);
static void log_skip_blobs (dk_session_t * log);
static int subscriber_dropped (dk_session_t * ses);
static int is_in_circulation (subscription_t * sub, caddr_t * replh);
static int repl_trail_send (repl_acct_t *ra, subscription_t * sub,
        repl_level_t level);
#ifdef REPL_SAVE_SUBSCRIBER_LEVEL
static void sub_save (subscription_t *sub, repl_level_t level);
#endif

void
resend_thread_loop (void)
{
  repl_message_t *rm;
  caddr_t *header;
  dk_session_t *string;
  caddr_t *replh;
  for (;;)
    {
      repl_queue_t *rq = &repl_queue;
      dk_set_t sublist = subscriptions;
      subscription_t *sub;

      semaphore_enter (rq->rq_sem);
      mutex_enter (rq->rq_mtx);
      rm = (repl_message_t *) basket_get (&rq->rq_basket);
      header = rm->rm_header;
      string = rm->rm_string;
      if (IS_BOX_POINTER (header))
	rq->rq_bytes -= (long) unbox (header[LOGH_BYTES]);
      mutex_leave (rq->rq_mtx);

      if (header == REPL_QUEUE_FULL)
	{
          DO_SET (subscription_t *, sub, &subscriptions)
            {
              /* Send resync message before disconnect */
              repl_send_resync (sub->sub_session);
              sub_free (sub);
            }
          END_DO_SET ();
          dk_set_free (subscriptions);
          subscriptions = NULL;
          mutex_enter (rq->rq_mtx);
          rq->rq_to_disconnect = 0;
          mutex_leave (rq->rq_mtx);
	  rm_free (rm);
	  continue;
	}
      else if (header == REPL_QUEUE_SYNCED)
	{
          subscription_t *sub = rm->rm_synced_sub;

	  dk_set_push (&subscriptions, (void *) sub);
	  SESSION_SCH_DATA (sub->sub_session)->sio_default_read_ready_action = subscriber_dropped;
	  PrpcCheckIn (sub->sub_session);
	  rm_free (rm);
	  continue;
	}
      else if (header == REPL_QUEUE_DISCONNECT)
	{
	  DO_SET (subscription_t *, sub, &subscriptions)
	    {
	      if (sub->sub_session == rm->rm_data)
		{
		  dk_set_delete (&subscriptions, (void *) sub);
		  sub_free (sub);
		  break;
		}
	    }
	  END_DO_SET();
	  rm_free (rm);
	  continue;
	}
      else if (header == REPL_PURGE)
        {
          repl_acct_t *ra = ra_find (db_name, rm->rm_acct);
          if (!ra)
            {
              log_error ("Log purge for non-existent account '%s' requested.",
                  rm->rm_acct);
              continue;
            }
          rm_free (rm);
          repl_purge_run (ra);
        }
      else
	{
	  dk_set_t sub_next;

	  replh = (caddr_t *) header[LOGH_REPLICATION];

	  for (sublist = subscriptions; sublist; sublist = sub_next)
	    {
              int rc;
	      dk_session_t *ses;
              repl_level_t level;

              sub_next = sublist->next;
	      sub = (subscription_t *) sublist->data;

              level = (repl_level_t) unbox (replh [REPLH_LEVEL]);
	      if ((rc = is_in_circulation (sub, replh)) <= 0)
                {
                  if (rc < 0)
                    {
                      send_sync_notice (sub, level);
#ifdef REPL_SAVE_SUBSCRIBER_LEVEL
                      sub_save (sub, level);
#endif
                    }
                  continue;
                }

              ses = sub->sub_session;
	      mutex_enter (ses->dks_mtx);
	      CATCH_WRITE_FAIL (ses)
		{
		  if (DKSESSTAT_ISSET (ses, SST_OK))
		    print_object ((caddr_t) header, ses, NULL, NULL);
		  if (DKSESSTAT_ISSET (ses, SST_OK))
		    {
		      strses_write_out (string, ses);
		    }
		  if (rm->rm_blobs_start)
		    sub_send_blobs (sub, rm, NULL);
		  session_flush_1 (ses);
		  /* _1 because inside the ses mtx. */
#ifdef REPL_SAVE_SUBSCRIBER_LEVEL
                  sub_save (sub, level);
#endif
		}
	      END_WRITE_FAIL (ses);
	      /* if connection broken the select thread will send a disconnect message.
	       * disconnect when that arrives, not now so as to avoid double free */
	        mutex_leave (ses->dks_mtx);

	      sublist = sub_next;
	    }

	  rm_free (rm);
	}
    }
}

static int
dummy_read_ready_action (dk_session_t *ses)
{
  (void) ses;
  GPF_T1 ("dummy_read_ready_action");
  return 0;
}


void
sf_resync_acct (char *account, repl_level_t level, char *subscriber_name,
		caddr_t name, caddr_t digest)
{
  user_t * user;
  dk_session_t *client = IMMEDIATE_CLIENT;
  subscription_t *sub;
  repl_acct_t *ra;
  repl_subscriber_t *rs;
  repl_level_t level_at;

  user = sec_check_login (name, digest, client);
/* Check grants */
#ifdef REPLICATION_SUPPORT2
  if (!user)
    {
      log_info ("Bad replication login '%s' for account '%s' from '%s'.",
		name, account, subscriber_name);
      thrs_printf ((thrs_fo, "ses %p thr:%p in sf_resync_acct1\n", client, THREAD_CURRENT_THREAD));
      DKST_RPC_DONE (client);
      return;
    }
  if (!sec_user_has_group (G_ID_DBA, user->usr_id))
    {
      int kpg = 0;
      kpg = get_repl_grants (account, name);
      if (!kpg)
	{
	  log_info ("User '%s' does not have privileges for account '%s' requested from '%s'.",
	      name, account, subscriber_name);
	  thrs_printf ((thrs_fo, "ses %p thr:%p in sf_resync_acct2\n", client, THREAD_CURRENT_THREAD));
	  DKST_RPC_DONE (client);
          return;
	}
    }
#else
  if (!user || !sec_user_has_group (G_ID_DBA, user->usr_id))
    {
      log_info ("Bad replication login '%s' for account '%s' requested from '%s' (not in DBA group).",
	  name, account, subscriber_name);
      thrs_printf ((thrs_fo, "ses %p thr:%p in sf_resync_acct3\n", client, THREAD_CURRENT_THREAD));
      DKST_RPC_DONE (client);
      return;
    }
#endif
/* End check grants */

  /* Before any action we should be sure that account exists */
  if ((ra = ra_find (db_name, account)) == NULL)
    {
      log_info ("The account '%s' requested from %s does not exist.",
	  account, subscriber_name);
      thrs_printf ((thrs_fo, "ses %p thr:%p in sf_resync_acct4\n", client, THREAD_CURRENT_THREAD));
      DKST_RPC_DONE (client);
      return;
    }
  if (!ra->ra_rt)
    {
      log_info ("Replication trail missing for account '%s'.", account);
      thrs_printf ((thrs_fo, "ses %p thr:%p in sf_resync_acct5\n", client, THREAD_CURRENT_THREAD));
      DKST_RPC_DONE (client);
      return;
    }

  if ((rs = rs_find (ra, subscriber_name)) != NULL && !rs->rs_valid)
    {
      log_info ("Subscriber '%s' for '%s' is not valid",
	  subscriber_name, ra->ra_account);
      thrs_printf ((thrs_fo, "ses %p thr:%p in sf_resync_acct6\n", client, THREAD_CURRENT_THREAD));
      DKST_RPC_DONE (client);
      return;
    }
  level_at = ra_trx_no (ra);
  rs = repl_save_subscriber (
      ra, subscriber_name, level, REPL_LEVEL_OK (level, level_at));
  if (!rs->rs_valid)
    {
      log_info ("Subscriber '%s' for '%s' is not valid (level %d, requested level %d)",
	  subscriber_name, ra->ra_account, level_at, level);
      thrs_printf ((thrs_fo, "ses %p thr:%p in sf_resync_acct7\n", client, THREAD_CURRENT_THREAD));
      DKST_RPC_DONE (client);
      return;
    }

  sub = sub_allocate (subscriber_name, account, client);
  thrs_printf ((thrs_fo, "ses %p thr:%p in sf_resync_acct7.5\n", client, THREAD_CURRENT_THREAD));
  PrpcCheckOut (sub->sub_session);
  SESSION_SCH_DATA (client)->sio_default_read_ready_action = dummy_read_ready_action;
  /* the session is not in select while syncing. It will go back
   * there when in sync. */

  thrs_printf ((thrs_fo, "ses %p thr:%p in sf_resync_acct8\n", client, THREAD_CURRENT_THREAD));
  DKST_RPC_DONE (client);
  repl_trail_send (ra, sub, level);
}

void
repl_send_resync (dk_session_t * ses)
{
  caddr_t *header = (caddr_t *) dk_alloc_box_zero (LOG_HEADER_LENGTH * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  caddr_t *replh = (caddr_t *) dk_alloc_box_zero (REPLH_CIRCULATION * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  header[LOGH_REPLICATION] = (caddr_t) replh;
  replh[REPLH_ACCOUNT] = NULL;
  replh[REPLH_SERVER] = box_string (db_name);
  PrpcWriteObject (ses, (caddr_t) header);
  dk_free_tree ((box_t) header);
}

static void
send_sync_notice (subscription_t * sub, repl_level_t level)
{
  caddr_t *header = (caddr_t *) dk_alloc_box (
      LOG_HEADER_LENGTH * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  caddr_t *replh = (caddr_t *) dk_alloc_box (
      REPLH_CIRCULATION * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  memset (header, 0, box_length ((caddr_t) header));
  memset (replh, 0, box_length ((caddr_t) replh));
  header[LOGH_REPLICATION] = (caddr_t) replh;
  replh[REPLH_ACCOUNT] = box_string (sub->sub_account);
  replh[REPLH_SERVER] = box_string (db_name);
  replh[REPLH_LEVEL] = box_num (level);
  PrpcWriteObject (sub->sub_session, (caddr_t) header);
  dk_free_tree ((box_t) header);
}

#define session_buffered_unread_char(s)	(s->dks_in_read --)

static void
sub_send_blobs (subscription_t * sub, repl_message_t * rm,
    dk_session_t * volatile log)
{
  volatile int any = 1;
  OFF_T off;
  char page[PAGE_SZ];
  dtp_t dv;
  long len;
  volatile int fd = 0;
  if (rm)
    {
      log = dk_session_allocate (SESCLASS_TCPIP);
      fd = fd_open (rm->rm_log_file, OPEN_FLAGS_RO);
      tcpses_set_fd (log->dks_session, fd);
      off = LSEEK (fd, rm->rm_blobs_start, SEEK_SET);
    }
  CATCH_READ_FAIL (log)
  {

    for (;;)
      {
	dv = (dtp_t) session_buffered_read_char (log);
	if (dv == 0)
	  {
	    session_buffered_write_char (0, sub->sub_session);
	    dbg_printf_1 (("      Blob done."));
	  }
	else if (dv == DV_SHORT_STRING)
	  {
	    len = (dtp_t) session_buffered_read_char (log);
	    session_buffered_read (log, page, len);
	    session_buffered_write_char (dv, sub->sub_session);
	    session_buffered_write_char (len, sub->sub_session);
	    session_buffered_write (sub->sub_session, page, len);
	  }
	else if (dv == DV_LONG_STRING)
	  {
	    len = read_long (log);
	    session_buffered_read (log, page, len);
	    session_buffered_write_char (dv, sub->sub_session);
	    print_long (len, sub->sub_session);
	    session_buffered_write (sub->sub_session, page, len);
	  }
	else
	  {
	    session_buffered_unread_char (log);
	    any = 0;
	    break;
	  }
      }

  }
  END_READ_FAIL (log);
  if (any)
    {
      dbg_printf_1 (("      Txn blobs replicated"));
    }
  if (rm)
    {
      close (fd);
      PrpcSessionFree (log);
    }
}

static void
log_skip_blobs (dk_session_t * log)
{
  char page[PAGE_SZ];
  dtp_t dv;
  long len;

  CATCH_READ_FAIL (log)
  {
    for (;;)
      {
	dv = (dtp_t) session_buffered_read_char (log);
	if (dv == 0)
	  ;
	else if (dv == DV_SHORT_STRING)
	  {
	    len = (dtp_t) session_buffered_read_char (log);
	    session_buffered_read (log, page, len);
	  }
	else if (dv == DV_LONG_STRING)
	  {
	    len = read_long (log);
	    session_buffered_read (log, page, len);
	  }
	else
	  {
	    session_buffered_unread_char (log);
	    break;
	  }
      }
  }
  END_READ_FAIL (log);
}

static int
subscriber_dropped (dk_session_t * ses)
{
  repl_sub_dropped(&repl_queue, ses);
  return 0;
}

static int
subscriber_dropped_dead (dk_session_t * ses)
{
  repl_sub_dropped(&repl_queue, ses);
  log_debug ("subscriber_dropped_dead");
  fprintf (stderr, "subscriber_dropped_dead\n");
  srv_client_session_died (ses);
  return 0;
}

static int replh_print = 0;

static int
is_in_circulation (subscription_t * sub, caddr_t * replh)
{
  int inx;
  if ((unsigned long) (uptrlong) replh > 100)
    {

      long len = box_length ((caddr_t) replh) / sizeof (caddr_t);
      char *acct = replh[REPLH_ACCOUNT];
      char *from_server = replh[REPLH_SERVER];
      char *origin = replh[REPL_ORIGIN];

      if (replh_print)
        {
	  dbg_printf_1 (("replh from '%s' level " BOXINT_FMT,
              from_server, unbox (replh [REPLH_LEVEL])));
        }
      if (!from_server || 0 != strcmp (db_name, from_server))
	/* This replicated somebody else's transaction. Don't forward. */
	return 0;

      if (!origin || 0 == strcmp (sub->sub_subscriber_name, origin))
        {
#if 0
          dbg_printf_1 (("is_in_circulation: origin == sub->subscriber_name (%s)",
              sub->sub_subscriber_name));
#endif
          return -1;
        }

      if (!acct)
	/* if acct == server the acct field is compressed to null */
	acct = replh[REPLH_SERVER];

      if (0 != strcmp (acct, sub->sub_account))
	return 0;
      if (len == REPLH_CIRCULATION)
	return 1;
      for (inx = REPLH_CIRCULATION; inx < len; inx++)
	{
	  if (0 == strcmp (sub->sub_subscriber_name, replh[inx]))
	    return 1;
	}
      return 0;
    }
  else
    return 0;
}

static int
repl_trail_send (repl_acct_t *ra, subscription_t * sub, repl_level_t level)
{
  repl_level_t volatile level_at = level;
  repl_level_t volatile lvl_back;
  repl_trail_t *rt = ra->ra_rt;
  dk_set_t volatile rtf_list;
  dk_session_t *ses = dk_session_allocate (SESCLASS_TCPIP);

  rwlock_rdlock (rt->rt_lock);

  log_info ("Subscription of '%s' for '%s' sync starts at %ld.",
      sub->sub_subscriber_name, sub->sub_account, level);
  if ((rtf_list = rt->rt_files) == NULL)
    goto synced;

  while (rtf_list)
  {
    repl_trail_file_t * rtf = (repl_trail_file_t *) rtf_list->data;
    char * file = rtf->rtf_file;
    int fd;

    if ((fd = fd_open (file, OPEN_FLAGS_RO)) < 0)
      {
        log_error ("repl_trail_send: %s: %s", file, strerror (errno));
        goto err;
      }
    tcpses_set_fd (ses->dks_session, fd);

    for (;;)
      {
	caddr_t *header;
	volatile long bytes;
        int rc = 0;

	/* see if we're at the end of last log */
	mutex_enter (rt->rt_mtx);
	if (0 == strcmp (file, rt->rt_file_name))
	  {
	    OFF_T pos = LSEEK (fd, 0, SEEK_CUR);
	    if (pos == rt->rt_commit_length
		&& ses->dks_in_read == ses->dks_in_fill)
	      {
		mutex_leave (rt->rt_mtx);
	        fd_close (fd, file);
		goto synced;
	      }
	  }
	mutex_leave (rt->rt_mtx);
	header = (caddr_t *) PrpcReadObject (ses);
	if (!header || DKSESSTAT_ISSET (ses, SST_NOT_OK))
          break;
	bytes = (long) unbox (header[LOGH_BYTES]);
	lvl_back = level_at;
	level_at = (repl_level_t) LOGH_LEVEL (header);
	if (repl_is_below (level, level_at) &&
            (rc = is_in_circulation (sub, (caddr_t *) header[LOGH_REPLICATION])) > 0)
	  {
	    caddr_t string = (caddr_t) dk_alloc (bytes);

	    CATCH_READ_FAIL (ses)
	    {
	      session_buffered_read (ses, string, bytes);
	    }
	    FAILED
	    { /* If reading failed we are in commit area after commit length,
		 hence we send sync notice and go ahead */
	      dk_free_tree ((caddr_t) header);
	      dk_free (string, bytes);
              level_at = lvl_back;
	      fd_close (fd, file);
	      goto synced;
	    }
	    END_READ_FAIL (ses);

	    CATCH_WRITE_FAIL (sub->sub_session)
	    {
	      print_object ((caddr_t) header, sub->sub_session, NULL, NULL);
	      session_buffered_chunked_write (sub->sub_session, string, bytes);
	      sub_send_blobs (sub, NULL, ses);
	      session_flush_1 (sub->sub_session);
#ifdef REPL_SAVE_SUBSCRIBER_LEVEL
              sub_save (sub, level_at);
#endif
	    }
	    END_WRITE_FAIL (sub->sub_session);

	    dk_free_tree ((caddr_t) header);
	    dk_free (string, bytes);
	    if (DKSESSTAT_ISSET (sub->sub_session, SST_NOT_OK))
              {
		fd_close (fd, file);
                log_error ("repl_trail_send: Can't send replication log.");
                goto err;
              }
	  }
	else
	  {
	    OFF_T off;
	    dk_free_tree ((caddr_t) header);
	    if (ses->dks_in_read + bytes < ses->dks_in_fill)
	      {
		ses->dks_in_read += bytes;
		log_skip_blobs (ses);
	      }
	    else
	      {
		bytes -= ses->dks_in_fill - ses->dks_in_read;
		off = LSEEK (fd, bytes, SEEK_CUR);
		ses->dks_in_fill = 0;
		ses->dks_in_read = 0;
		log_skip_blobs (ses);
	      }
            if (repl_is_below (level, level_at) && rc < 0)
              {
                send_sync_notice (sub, level_at);
#ifdef REPL_SAVE_SUBSCRIBER_LEVEL
                sub_save (sub, level_at);
#endif
              }
	  }
      }

    fd_close (fd, file);

    mutex_enter (rt->rt_mtx);
    rtf_list = rtf_list->next;
    mutex_leave (rt->rt_mtx);
  }
  log_error ("No replication logs for level %ld.", level);

err:
  rwlock_unlock (rt->rt_lock);
  PrpcSessionFree (ses);
  sub->sub_session->dks_to_close = 1;
  sub->sub_session = NULL;  /* will be freed by future_wrapper */
  sub_free (sub);
  return -1;

synced:
  rwlock_unlock (rt->rt_lock);
  PrpcSessionFree (ses);
  sub->sub_session->dks_is_server = 0; /* no auto dealloc when dead hook called */
  PrpcSetPartnerDeadHook (sub->sub_session, subscriber_dropped_dead);
  send_sync_notice (sub, 0);
  repl_sub_synced (sub, level_at);
  return 0;
}

#ifdef REPL_SAVE_SUBSCRIBER_LEVEL
static void
sub_save (subscription_t *sub, repl_level_t level)
{
  repl_acct_t *ra;

  if ((ra = ra_find (db_name, sub->sub_account)) == NULL)
    {
      log_error ("Saving for non-existent account '%s' requested",
          sub->sub_account);
      return;
    }

  repl_save_subscriber (ra, sub->sub_subscriber_name, level, 1);
}
#endif

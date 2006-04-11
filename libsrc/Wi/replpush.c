/*
 *  replpush.c
 *
 *  $Id$
 *
 *  Push replication subscriptions.
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
#include "log.h"
#include "repl.h"
#include "replsr.h"
#include "wirpce.h"
#include "security.h"
#include "sqlbif.h"

#define DKS_REPL_DATA(s) (*(repl_acct_t **) &(s)->dks_dbs_data)

static int repl_push_log (void *);


repl_queue_t repl_replay_queue;   /* replay queue (on publisher side) */
repl_queue_t repl_push_queue;     /* push queue (on subscriber side) */
resource_t *replay_rc;
dk_session_t *replay_str_in;
client_connection_t *replay_cli;

static dk_set_t publishers;

replay_message_t *
rpm_allocate (void)
{
  NEW_VARZ (replay_message_t, rpm);
  return rpm;
}

void
rpm_free (replay_message_t * rpm)
{
  strses_free (rpm->rpm_ses);
  dk_free_box (rpm->rpm_msg);
  dk_free ((caddr_t) rpm, sizeof (replay_message_t));
}

void
rpm_clear (replay_message_t * rpm)
{
  rpm->rpm_mode = 0;
  rpm->rpm_ses = NULL;
  rpm->rpm_msg = NULL;
}

static int
publisher_dropped (dk_session_t * ses)
{
  repl_sub_dropped(&repl_push_queue, ses);
  return 0;
}

static void
repl_set_synced (repl_acct_t *ra, int synced, int disconnect_parent)
{
  if (disconnect_parent)
    {
      /* queue [publisher -> subscriber] disconnect */
      dbg_printf_1 (("repl_set_synced: queueing parent disconnect: account '%s' (server '%s')",
          ra->ra_account, ra->ra_server));
      ra->ra_parent->ra_synced = RA_TO_DISCONNECT;
    }
  ra->ra_synced = synced;
}

static void
repl_disconnect_publisher (subscription_t *sub, int synced, int disconnect_parent)
{
  repl_acct_t *ra = DKS_REPL_DATA(sub->sub_session);

  dbg_printf_1 (("repl_disconnect_publisher: account '%s' (server '%s')",
      ra->ra_account, ra->ra_server));
  repl_set_synced (ra, synced, disconnect_parent);
  sub_free (sub);
}

int
repl_sync_updateable_acct (repl_acct_t *ra, char * _usr, char * _pwd)
{
  subscription_t *sub;

  char *usr, *pwd;
  char *addr;
  char *hashed_pwd;
  char *subscriber_name;
  int saved_synced;
  dk_session_t *ses = NULL; /* PrpcFindPeer (ra->ra_server); */
  caddr_t res;
  repl_acct_t *ra2;
  repl_subscriber_t *rs;
  repl_level_t level_at, pub_level;

  ra2 = ra_find_pushback (ra->ra_server, ra->ra_account);
  if (ra2 == NULL)
    {
      log_info ("repl_sync_updateable_acct: Can't find pushback account for updateable replication account '%s' (server '%s')",
              ra->ra_account, ra->ra_server);
      return -1;
    }
  ra = ra2;
  if (ra->ra_parent == NULL)
    {
      log_info ("repl_sync_updateable_acct: NULL parent for account '%s' (server '%s')",
              ra->ra_account, ra->ra_server);
      return -1;
    }
  if (!ra->ra_rt)
    {
      log_info ("repl_sync_updateable_acct: No replication trail found for account '%s' (server '%s')\n",
          ra->ra_account, ra->ra_server);
      return -1;
    }

  usr = _usr ? _usr : ra->ra_usr;
  pwd = _pwd ? _pwd : ra->ra_pwd;
  if (!usr || !pwd) /* We must be sure that user/password are not null */
    return -1;

  addr = repl_server_to_address (ra->ra_server);
  if (!addr)
    return -1;

  saved_synced = ra->ra_synced;
  if (RA_IN_SYNC == ra->ra_synced || RA_SYNCING == ra->ra_synced)
    return 0;

  ra->ra_synced = RA_SYNCING; /* because the connection can be slow we first set the status
				     if can't connect revert the status */
  if (!ses)
    {
      ses = PrpcConnect (addr, SESCLASS_TCPIP);
      if (!DKSESSTAT_ISSET (ses, SST_OK))
        {
          repl_set_synced (ra, saved_synced, 0);
          PrpcDisconnect (ses);
          PrpcSessionFree (ses);
	  sqlr_new_error ("08001", "TR072", "Replication connect to '%s' failed.", addr);
        }

      if (!_thread_sched_preempt)
	ses->dks_read_block_timeout = dks_fibers_blocking_read_default_to;
      dk_free_box (ses->dks_peer_name);
      ses->dks_peer_name = repl_peer_name (ra);
      log_info ("repl_sync_updateable_acct: Connected to replication server '%s'.\n", addr);
    }

  pub_level = ra_pub_trx_no (ra);
  level_at = ra_trx_no (ra);
  log_info ("repl_sync_updateable_acct: Initiating sync for '%s' (server '%s') level %ld.",
      ra->ra_account, ra->ra_server, pub_level);

  hashed_pwd = dk_alloc_box (17, DV_SHORT_STRING);
  sec_login_digest (ses->dks_own_name, usr, pwd, (unsigned char *) hashed_pwd);
  hashed_pwd[16] = '\0';
  subscriber_name = box_dv_short_string (db_name);
  res = PrpcSync (PrpcFuture (ses, &s_resync_replay,
      ra->ra_parent->ra_account, subscriber_name, usr, hashed_pwd));
  PrpcCheckOut (ses);
  SESSION_SCH_DATA (ses)->sio_default_read_ready_action = NULL;
  dk_free_box (hashed_pwd);
  dk_free_box (subscriber_name);
  if (!unbox (res))
    {
      dk_free_box(res);
      repl_set_synced (ra, saved_synced, 0);
      PrpcDisconnect (ses);
      PrpcSessionFree (ses);
      sqlr_new_error ("08001", "TR080", "Login to '%s' as '%s' failed.",
          ra->ra_server, usr);
    }
  dk_free_box(res);

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

  if ((rs = rs_find (ra, ra->ra_server)) != NULL && !rs->rs_valid)
    {
      repl_set_synced (ra, saved_synced, 0);
      PrpcDisconnect (ses);
      PrpcSessionFree (ses);
      sqlr_new_error ("08001", "TR094",
          "Pushback account '%s' from '%s' is not valid (level %ld, pub level %ld)",
          ra->ra_account, ra->ra_server, (long)level_at, (long)pub_level);
    }
  rs = repl_save_subscriber (
      ra, ra->ra_server, pub_level, REPL_LEVEL_OK (pub_level, level_at));
  if (!rs->rs_valid)
    {
      repl_set_synced (ra, saved_synced, 0);
      PrpcDisconnect (ses);
      PrpcSessionFree (ses);
      sqlr_new_error ("08001", "TR095",
          "Pushback account '%s' from '%s' is not valid (level %ld, pub level %ld)",
          ra->ra_account, ra->ra_server, (long)level_at, (long)pub_level);
    }

  DKS_REPL_DATA (ses) = ra;
  sub = sub_allocate (ra->ra_server, ra->ra_account, ses);

  if (PrpcThreadAllocate (repl_push_log, future_thread_sz, sub) == NULL)
    {
       repl_disconnect_publisher (sub, saved_synced, 0);
       sqlr_new_error ("08001", "TR093",
          "Can's create a resync thread for '%s' (server '%s')",
          ra->ra_account, ra->ra_server);
    }

  return 0;
}

/*
 * Assumes that rt->rt_lock is acquired for read
 */
static dk_set_t
repl_trail_find_first (repl_trail_t * rt, repl_level_t level)
{
  dk_set_t rtf_list, rtf_prev = NULL;

  mutex_enter (rt->rt_mtx);
  for (rtf_list = rt->rt_files; rtf_list != NULL;
          rtf_prev = rtf_list, rtf_list = rtf_list->next)
    {
      repl_trail_file_t * rtf = (repl_trail_file_t *) rtf_list->data;

      if (repl_is_below (level, rtf->rtf_level))
        break;

#if 0
      dbg_printf_1 (("repl_trail_find_first: skipped '%s' (%ld <= %ld)",
          rtf->rtf_file, rtf->rtf_level, level));
#endif
    }

  if (rtf_prev == NULL)
    rtf_prev = rt->rt_files;
  mutex_leave (rt->rt_mtx);

  return rtf_prev;
}

static int
repl_push (repl_acct_t * ra, dk_session_t * ses, caddr_t * header,
    dk_session_t * str_ses, caddr_t string, long bytes)
{
  caddr_t res;
  int retval;
  caddr_t *replh;
  repl_level_t level;

  mutex_enter (ses->dks_mtx);
  CATCH_WRITE_FAIL (ses)
    {
      if (DKSESSTAT_ISSET (ses, SST_OK))
        print_object ((caddr_t) header, ses, NULL, NULL);
      if (DKSESSTAT_ISSET (ses, SST_OK))
        {
          if (str_ses != NULL)
            strses_write_out (str_ses, ses);
          else
            session_buffered_chunked_write (ses, string, bytes);
        }
      session_flush_1 (ses);
    }
  END_WRITE_FAIL (ses);
  mutex_leave (ses->dks_mtx);

  if (!DKSESSTAT_ISSET (ses, SST_OK))
    {
      log_error ("repl_push: Can't send replication log");
      return -1;
    }

  res = (caddr_t) PrpcReadObject (ses);
  if (!DKSESSTAT_ISSET (ses, SST_OK))
    {
      log_error ("repl_push: Can't read result");
      return -1;
    }

  if (0 == (retval = (int) unbox (res)))
    {
      log_error ("repl_push: Can't replay replication log on publisher");
      return -1;
    }
  dk_free_box(res);

  if (2 == retval)
    {
      /* handle resyncs here (XXX not implemented yet) */
      log_info (("repl_push: Resync is not implemented yet"));
    }

  replh = (caddr_t *) header[LOGH_REPLICATION];
#if 0
  dbg_printf_1 (("repl_push: setting pub trx no to %ld",
      unbox (replh[REPLH_LEVEL])));
#endif
  level = (repl_level_t) unbox (replh[REPLH_LEVEL]);
  ra_set_pub_trx_no (ra, level);
#ifdef REPL_SAVE_SUBSCRIBER_LEVEL
  repl_save_subscriber (ra, ra->ra_server, level, 1);
#endif
  return 0;
}

static int
repl_push_log (void *arg)
{
  subscription_t *sub = (subscription_t *) arg;
  repl_acct_t *ra = DKS_REPL_DATA(sub->sub_session);
  dk_session_t *ses = dk_session_allocate (SESCLASS_TCPIP);

  volatile dk_set_t rtf_list;
  volatile repl_level_t level_at;
  repl_level_t level, level_back;
  repl_trail_t *rt = ra->ra_rt;
  caddr_t *header;

  rwlock_rdlock (rt->rt_lock);
  level_at = level = ra_pub_trx_no (ra);
#if 0
  dbg_printf_1 (("repl_push_log: account '%s' (server '%s'), level %d",
      ra->ra_account, ra->ra_server, level));
#endif

  if ((rtf_list = repl_trail_find_first (rt, level)) == NULL)
    {
      log_info ("repl_push_log: No replication log files found for account '%s' (server '%s')\n",
          ra->ra_account, ra->ra_server);
      goto synced;
    }

  while (rtf_list)
    {
      repl_trail_file_t * rtf = (repl_trail_file_t *) rtf_list->data;
      char * file = rtf->rtf_file;
      int fd;

      if ((fd = fd_open (file, OPEN_FLAGS_RO)) < 0)
        {
          if (errno == ENOENT && !strcmp(file, rt->rt_file_name) && !rt->rt_out)
            {
              dbg_printf_1 (("repl_push_log: (last) trail file is not created yet, ok"));
              goto synced;
            }
          log_error ("repl_push_log: %s: %s", file, strerror (errno));
          goto err;
        }
      tcpses_set_fd (ses->dks_session, fd);

      for (;;)
        {
	  volatile long bytes;

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
	  level_back = level_at;
	  level_at = (repl_level_t) LOGH_LEVEL (header);
#if 0
          dbg_printf_1 (("repl_push_log: repl header: level %ld", level_at));
#endif
	  if (repl_is_below (level, level_at))
	    {
              int res;
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
                level_at = level_back;
	        fd_close (fd, file);
	        goto synced;
	      }
	      END_READ_FAIL (ses);

              res = repl_push (
                  ra, sub->sub_session, header, NULL, string, bytes);
              dk_free_tree ((caddr_t) header);
              dk_free (string, bytes);
              if (res < 0)
                {
                  fd_close(fd, file);
                  log_error ("repl_push_log: Can't push replication log");
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
	        }
	      else
	        {
		  bytes -= ses->dks_in_fill - ses->dks_in_read;
		  off = LSEEK (fd, bytes, SEEK_CUR);
		  ses->dks_in_fill = 0;
		  ses->dks_in_read = 0;
	        }
	    }
        }

      fd_close (fd, file);

      mutex_enter (rt->rt_mtx);
      rtf_list = rtf_list->next;
      mutex_leave (rt->rt_mtx);
    }
  log_error ("repl_push_log: No replication logs for level %ld", level);

err:
  rwlock_unlock (rt->rt_lock);
  PrpcSessionFree (ses);
  repl_disconnect_publisher (sub, RA_DISCONNECTED, 0);
  return -1;

synced:
  rwlock_unlock (rt->rt_lock);
  PrpcSessionFree (ses);
  ra->ra_synced = RA_IN_SYNC;
  sub->sub_session->dks_is_server = 0; /* no auto dealloc when dead hook called */
  PrpcSetPartnerDeadHook (sub->sub_session, publisher_dropped);
  repl_sub_synced (sub, level_at);
  return 0;
}

void
repl_push_loop (void)
{
  for (;;)
    {
      repl_message_t *rm;
      caddr_t *header;
      dk_session_t *string;
      caddr_t *replh;

      repl_queue_t *rq = &repl_push_queue;

      dk_set_t publist = publishers;

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
          DO_SET (subscription_t *, sub, &publishers)
            {
              repl_disconnect_publisher (sub, RA_DISCONNECTED, 1);
            }
          END_DO_SET ();
          dk_set_free (publishers);
          publishers = NULL;
          mutex_enter (rq->rq_mtx);
          rq->rq_to_disconnect = 0;
          mutex_leave (rq->rq_mtx);
	  rm_free (rm);
	  continue;
	}

      if (header == REPL_QUEUE_SYNCED)
	{
	  dk_set_push (&publishers, (void *) rm->rm_synced_sub);
	  PrpcCheckIn (rm->rm_synced_sub->sub_session);
	  rm_free (rm);
	  continue;
	}

      if (header == REPL_QUEUE_DISCONNECT)
	{
	  DO_SET (subscription_t *, sub, &publishers)
	    {
	      if (sub->sub_session == rm->rm_data)
		{
		  dk_set_delete (&publishers, (void *) sub);
                  repl_disconnect_publisher (sub, RA_DISCONNECTED, 1);
		  break;
		}
	    }
	  END_DO_SET();
	  rm_free (rm);
	  continue;
	}

      if (header == REPL_PURGE)
        {
          repl_acct_t *ra = ra_find (rm->rm_srv, rm->rm_acct);
          if (!ra)
            {
              log_error ("Log purge for non-existent account '%s' from '%s' requested.",
                  rm->rm_acct, rm->rm_srv);
              continue;
            }
          rm_free (rm);
          repl_purge_run (ra);
          continue;
        }

      replh = (caddr_t *) header[LOGH_REPLICATION];
      publist = publishers;
#if 0
      log_debug ("repl_push_loop: start");
#endif
      while (publist)
	{
	  dk_set_t pub_next = publist->next;
	  subscription_t *sub = (subscription_t *) publist->data;
          repl_acct_t *ra = DKS_REPL_DATA(sub->sub_session);

#if 0
          log_debug ("repl_push_loop: '%s' (%s)", sub->sub_account, sub->sub_subscriber_name);
#endif
	  if (0 == strcmp (sub->sub_subscriber_name, ra->ra_parent->ra_server) &&
              0 == strcmp (sub->sub_account, replh[REPLH_ACCOUNT]))
            {
              if (repl_push (ra, sub->sub_session, header, string, NULL, 0) < 0)
                {
#if 0
                  dbg_printf_1 (("repl_push_loop: repl_push failed: disconnecting publisher"));
#endif
		  dk_set_delete (&publishers, (void *) sub);
                  repl_disconnect_publisher (sub, RA_DISCONNECTED, 1);
                }
	    }

	  publist = pub_next;
	}
#if 0
      log_debug ("repl_push_loop: end");
#endif

      rm_free (rm);
    }
}

static int
repl_replay_session_dropped (dk_session_t * ses)
{
  if (DKSESSTAT_ISSET (ses, SST_NOT_OK))
    remove_from_served_sessions (ses);
  return 0;
}

static void
replay_message_add (int mode, dk_session_t * ses, caddr_t msg)
{
  repl_queue_t *rq = &repl_replay_queue;
  replay_message_t *rpm;

  rpm = (replay_message_t *) resource_get (replay_rc);
  rpm->rpm_mode = mode;
  rpm->rpm_ses = ses;
  rpm->rpm_msg = msg;

  mutex_enter (rq->rq_mtx);
  basket_add (&rq->rq_basket, (void *) rpm);
  mutex_leave (rq->rq_mtx);

  semaphore_leave (rq->rq_sem);
}

static int
repl_replay_input_ready (dk_session_t * ses)
{
  remove_from_served_sessions (ses);
  replay_message_add(RPM_IN, ses, NULL);
  return 0;
}


caddr_t
sf_resync_replay (char *account, char *subscriber_name,
        caddr_t name, caddr_t digest)
{
  user_t * user;
  dk_session_t *client = IMMEDIATE_CLIENT;
  repl_acct_t *ra;

  ra = ra_find (db_name, account);
  if (ra == NULL)
    {
      log_info ("Resync of non-existent account '%s' initiated by '%s'.",
          account, subscriber_name);
      PrpcDisconnect (client);
      return box_num(0);
    }
  DKS_REPL_DATA(client) = ra;

  user = sec_check_login (name, digest, client);
/* Check grants */
#ifdef REPLICATION_SUPPORT2
  if (!user)
    {
      log_info ("Bad replication login '%s' for account '%s' from '%s'.",
		name, account, subscriber_name);
      PrpcDisconnect (client);
      return box_num(0);
    }
  if (!sec_user_has_group (G_ID_DBA, user->usr_id))
    {
      int kpg = 0;
      kpg = get_repl_grants (account, name);
      if (!kpg)
	{
	  log_info ("User '%s' does not have privileges for account '%s' from '%s'.",
	      name, account, subscriber_name);
          PrpcDisconnect (client);
	  return box_num(0);
	}
    }
#else
  if (!user || !sec_user_has_group (G_ID_DBA, user->usr_id))
    {
      log_info ("Bad replication login '%s' for account '%s' from '%s' (not in DBA group).",
	  name, account, subscriber_name);
      PrpcDisconnect (client);
      return box_num(0);
    }
#endif
/* End check grants */

  client->dks_is_server = 0; /* no auto dealloc when dead hook called */
  PrpcSetPartnerDeadHook (client, repl_replay_session_dropped);
  SESSION_SCH_DATA (client)->sio_default_read_ready_action =
      repl_replay_input_ready;
  mutex_enter (thread_mtx);
  if (client->dks_thread_state == DKST_BURST)
    {
      thrs_printf ((thrs_fo, "ses %p thr:%p going from burst to idle for sf_resync_replay\n",
	    client, THREAD_CURRENT_THREAD));
      client->dks_thread_state = DKST_IDLE;
      PrpcCheckInAsync (client);
    }
  mutex_leave (thread_mtx);
  return box_num(1);
}

static void
replay_session_cleanup (dk_session_t *ses)
{
  DKS_REPL_DATA (ses) = NULL;
}

static int
replay_process_msg (dk_session_t * ses)
{
  scheduler_io_data_t trx_sio;
  caddr_t *header;
  volatile int bytes;
  volatile caddr_t trx_string = NULL;
  int res;
  volatile repl_acct_t *ra;

  header = (caddr_t *) PrpcReadObject (ses);
  if (!header || DKSESSTAT_ISSET (ses, SST_BROKEN_CONNECTION)
      || !repl_check_header(header))
    goto seserr;

  bytes = (long) unbox (header[LOGH_BYTES]);
  trx_string = (caddr_t) dk_alloc(bytes);
  CATCH_READ_FAIL (ses)
  {
    session_buffered_read (ses, trx_string, bytes);
  }
  FAILED
  {
    goto seserr;
  }
  END_READ_FAIL (ses);

  memset (&trx_sio, 0, sizeof (trx_sio));
  if (!SESSION_SCH_DATA (replay_str_in))
    SESSION_SCH_DATA (replay_str_in) = &trx_sio;
  replay_str_in->dks_in_buffer = trx_string;
  replay_str_in->dks_in_read = 0;
  replay_str_in->dks_in_fill = bytes;
  replay_cli->cli_session = ses;
  ra = DKS_REPL_DATA(ses);
  if (!set_user_id (replay_cli, ra->ra_sync_user, NULL))
    {
      log_error ("Can't set user to '%s' for account '%s'.",
          ra->ra_sync_user, ra->ra_account);
      goto seserr;
    }
  res = log_replay_trx (replay_str_in, replay_cli, (caddr_t) header, 1, 1);
  if (LTE_OK == res)
    {
      replay_message_add (RPM_OUT, ses, box_num(1));
    }
  else if (LTE_REJECT == res)
    {
      replay_message_add (RPM_OUT, ses, box_num(2));
    }
  else
    {
      replay_message_add (RPM_OUT, ses, box_num(0));
    }
  dk_free_tree ((caddr_t) header);
  dk_free (trx_string, bytes);
  return 0;

seserr:
  dk_free_tree ((caddr_t) header);
  if (trx_string != NULL)
    dk_free (trx_string, bytes);
  PrpcCheckOut (ses);
  PrpcDisconnect (ses);
  PrpcSessionFree (ses);
  return -1;
}

void
repl_replay_loop (void)
{
  for (; ;)
    {
      repl_queue_t *rq = &repl_replay_queue;
      replay_message_t *rpm;

      int mode;
      dk_session_t *ses;
      caddr_t msg;

      semaphore_enter (rq->rq_sem);
      mutex_enter (rq->rq_mtx);
      rpm = (replay_message_t *) basket_get (&rq->rq_basket);
      mode = rpm->rpm_mode;
      ses = rpm->rpm_ses;
      msg = rpm->rpm_msg;
      resource_store (replay_rc, (void *) rpm);
      mutex_leave (rq->rq_mtx);

      if (!DKSESSTAT_ISSET (ses, SST_OK))
	{
          replay_session_cleanup (ses);
          PrpcCheckOut (ses);
	  PrpcDisconnect (ses);
	  PrpcSessionFree (ses);
	  continue;
	}

      /* do operation */
      switch (mode)
	{
	  case RPM_IN:
            if (replay_process_msg(ses) == 0)
	      PrpcCheckInAsync (ses);
	    break;

	  case RPM_OUT:
	    PrpcWriteObject (ses, msg);
	    if (!DKSESSTAT_ISSET (ses, SST_OK))
              {
		replay_session_cleanup (ses);
                PrpcCheckOut (ses);
		PrpcDisconnect (ses);
		PrpcSessionFree (ses);
              }
	    break;

	  default:
	      break;
	}

      dk_free_tree (msg);
    }
}

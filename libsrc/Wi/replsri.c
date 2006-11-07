/*
 *  replsri.c
 *
 *  $Id$
 *
 *  Replication Server Process
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
#include "sqlbif.h"
#include "wirpce.h"
#include "security.h"
#include "datesupp.h"

#ifdef WIN32
#include "wiservic.h"
#endif


static resource_t * tr_rc;
static char REPL_CFG[] = "repl.cfg";
static char REPL_CFG_TMP[] = "repl.cfg~";
static dk_mutex_t *cfg_mtx;

static repl_trail_t *repl_trail_add (repl_acct_t *ra, char * file);

static void
repl_queue_init (repl_queue_t *rq)
{
  rq->rq_mtx = mutex_allocate ();
  rq->rq_sem = semaphore_allocate (0);
}

static int
repl_write_extra_log (repl_acct_t *ra, caddr_t * head, dk_session_t * string)
{
  volatile int rc = LTE_OK;
  OFF_T len_before;
  repl_trail_t *rt;

  if (!ra || (rt = ra->ra_rt) == NULL)
    return LTE_OK;

  if (!rt->rt_out)
    {
      repl_trail_file_t *rtf = (repl_trail_file_t *) dk_set_last (rt->rt_files)->data;
      char *f_name = rtf->rtf_file;
      int fd;

      file_set_rw (f_name);
      fd = fd_open (f_name, OPEN_FLAGS);
      if (-1 == fd)
	{
	  log_error ("Can't open replication log '%s'.", f_name);
	  return LTE_LOG_FAILED;
	}
      rt->rt_out = dk_session_allocate (SESCLASS_TCPIP);
      tcpses_set_fd (rt->rt_out->dks_session, fd);
      LSEEK (fd, 0, SEEK_END);
    }

  len_before = LSEEK (tcpses_get_fd (rt->rt_out->dks_session), 0, SEEK_CUR);
  CATCH_WRITE_FAIL (rt->rt_out)
    {
      print_object ((caddr_t) head, rt->rt_out, NULL, NULL);
      strses_write_out (string, rt->rt_out);
      session_flush_1 (rt->rt_out);
      if (rt->rt_out->dks_bytes_sent > rt->rt_bytes_per_file)
	repl_trail_new_file (ra, NULL, 1);
    }
  FAILED
    {
      FTRUNCATE (tcpses_get_fd (rt->rt_out->dks_session), len_before);
      rt->rt_out->dks_bytes_sent = len_before;
      rc = LTE_LOG_FAILED;
    }
  END_WRITE_FAIL (rt->rt_out);

  return rc;
}

void
rm_free (repl_message_t * rm)
{
  dk_session_t * strses = rm->rm_string;
  dk_free_box (rm->rm_srv);
  dk_free_box (rm->rm_acct);
  dk_free_tree ((box_t) rm->rm_header);
  if (rm->rm_log_file)
    dk_free_box (rm->rm_log_file);
  memset (rm, 0, sizeof (repl_message_t));
  rm->rm_string = strses;
  resource_store (tr_rc, (void*) rm);
}

int
repl_is_below (repl_level_t log, repl_level_t req)
{
  if (log <= req && req - log < REPL_MAX_DELTA)
    return log < req;
  if (log > REPL_WRAPAROUND - REPL_MAX_DELTA && req < REPL_MAX_DELTA)
    return 1;
  return 0;
}

#if 0
dk_set_t
repl_trail_start_pos (repl_trail_t * rt, repl_level_t level)
{
  repl_trail_file_t ** rtfs = (repl_trail_file_t **)
    dk_set_to_array (rt->rt_files);
  repl_trail_file_t * rtf = NULL;
  int n_files = BOX_ELEMENTS (rtfs);
  int inx;
  for (inx = n_files - 1; inx >= 0; inx--)
    {
      if (repl_is_below (rtfs[inx]->rtf_level, level))
	{
	  rtf = rtfs[inx];
	  break;
	}
    }
  dk_free_box ((caddr_t) rtfs);
  if (!rtf)
    return (rt->rt_files);
  return (dk_set_member (rt->rt_files, (void*) rtf));
}
#endif

#define MAX_TO_GO_UNCHUNKED   2048

int
session_buffered_chunked_write (dk_session_t * ses, char *buffer, int length)
{
  if (length <= MAX_TO_GO_UNCHUNKED)
    {
      return session_buffered_write (ses, buffer, length);
    }
  else
    {
      int chunk_sz, inx = 0;
      while (inx < length)
	{
	  chunk_sz = length - inx > MAX_TO_GO_UNCHUNKED ? MAX_TO_GO_UNCHUNKED : length - inx;
	/*  fprintf (stderr, "REPL write : %d bytes %d remaining\n", chunk_sz, length - inx);*/
	  session_buffered_write (ses, buffer + inx, chunk_sz);
/*	  session_flush_1 (ses);*/
	  inx += chunk_sz;
	}
      return 0;
    }
}

#if 0
static int
session_buffered_chunked_read (dk_session_t * ses, char *buffer, int length)
{
  if (length <= MAX_TO_GO_UNCHUNKED)
    {
      return session_buffered_read (ses, buffer, length);
    }
  else
    {
      int chunk_sz, inx = 0;
      while (inx < length)
	{
	  chunk_sz = length - inx > MAX_TO_GO_UNCHUNKED ? MAX_TO_GO_UNCHUNKED : length - inx;
	  session_buffered_read (ses, buffer + inx, chunk_sz);
	  inx += chunk_sz;
	}
      return 0;
    }
}
#endif

/**
 * Create new replication trail file description
 */
static repl_trail_file_t *
rtf_allocate (char * file, repl_level_t level)
{
  NEW_VARZ (repl_trail_file_t, rtf);
  rtf->rtf_file = box_string (file);
  rtf->rtf_level = level;
  return rtf;
}

static void
rtf_free (repl_trail_file_t *rtf)
{
  dk_free_box (rtf->rtf_file);
  dk_free (rtf, sizeof (*rtf));
}

static void
rtf_list_free (dk_set_t rtf_list)
{
  DO_SET (repl_trail_file_t *, rtf, &rtf_list)
    {
      rtf_free (rtf);
    }
  END_DO_SET ();
  dk_set_free (rtf_list);
}

static void
repl_cfg_writeln (FILE *cfg, repl_acct_t *ra, char *filename)
{
    if (0 == strcmp (db_name, ra->ra_server))
      fprintf (cfg, "%-20s %s\n", ra->ra_account, filename);
    else
      {
        fprintf (cfg, "%-20s %-20s %s\n",
            ra->ra_server, ra->ra_account, filename);
      }
}

void
repl_trail_new_file (repl_acct_t *ra, char *file, int lock)
{
  repl_trail_file_t * rtf = NULL;
  repl_trail_t *rt = ra->ra_rt;
  OFF_T len;

#if 0
  dbg_printf_1 (("repl_trail_new_file: srv '%s', acct '%s'",
      ra->ra_server, ra->ra_account));
#endif
  if (!rt)
    rt = repl_trail_add (ra, file);
  if (!file)
    file = log_new_name (rt->rt_file_name);
  if (lock)
    rwlock_rdlock (rt->rt_lock);
  mutex_enter (rt->rt_mtx);
  if (rt->rt_out)
    {
      int new_fd;
      int fd = tcpses_get_fd (rt->rt_out->dks_session);

      file_set_rw (file);
      new_fd = fd_open (file, OPEN_FLAGS);
      if (-1 == new_fd)
	{
	  log_error ("Cannot open new replication log '%s': %s (errno %d).",
              file, strerror(errno), errno);
	  mutex_leave (rt->rt_mtx);
          if (lock)
            rwlock_unlock (rt->rt_lock);
          return;
	}
      fd_close (fd, NULL);
      len = LSEEK (new_fd, 0, SEEK_END); /* if switched w/in 1 sec, the same file gets reopened. Append */
      tcpses_set_fd (rt->rt_out->dks_session, new_fd);
      rt->rt_out->dks_bytes_sent = len;
      rt->rt_commit_length = len;
    }

  rtf = rtf_allocate (
      file, sequence_set (ra->ra_sequence, 0, SEQUENCE_GET, INSIDE_MAP));
  rt->rt_files = dk_set_conc (rt->rt_files,
      dk_set_cons ((caddr_t) rtf, NULL));

  dk_free_box (rt->rt_file_name);
  rt->rt_file_name = box_string (file);
  log_info ("Started replication log '%s'.", rt->rt_file_name);
  {
    FILE *cfg;

    mutex_enter (cfg_mtx);
    cfg = fopen (REPL_CFG, "a");
    if (cfg == NULL)
      {
        log_error ("Can't open '%s' for append: %s (errno %d)",
            REPL_CFG, strerror (errno), errno);
      }
    else
      {
        repl_cfg_writeln (cfg, ra, rt->rt_file_name);
        fclose (cfg);
      }
    mutex_leave (cfg_mtx);
  }
  mutex_leave (rt->rt_mtx);
  if (lock)
    rwlock_unlock (rt->rt_lock);
}

/**
 * Add replication trail for specified account
 *
 * @param account account
 */
static repl_trail_t *
repl_trail_add (repl_acct_t *ra, char * file)
{
  NEW_VARZ (repl_trail_t, rt);

#if 0
  dbg_printf_1 (("repl_trail_add: srv '%s', account '%s'", srv, account));
#endif
  rt->rt_mtx = mutex_allocate ();
  rt->rt_lock = rwlock_allocate ();
  rt->rt_bytes_per_file = 10000000;
  if (file)
    rt->rt_file_name = box_string (file);
  else
    {
      char *prefix;
      char *account = ra->ra_account;

      /* skip first '!' */
      if (RA_IS_PUSHBACK(account))
        {
          prefix = "replback_";
          account++;
        }
      else
        prefix = "repl_";

      rt->rt_file_name = dk_alloc_box (
          strlen(prefix) + strlen (ra->ra_server) + 1 + strlen (account) + 1 + 1,
          DV_SHORT_STRING);
      strcpy_box_ck (rt->rt_file_name, prefix);
      strcat_box_ck (rt->rt_file_name, ra->ra_server);
      strcat_box_ck (rt->rt_file_name, "_");
      strcat_box_ck (rt->rt_file_name, account);
      strcat_box_ck (rt->rt_file_name, "_");
    }
  ra->ra_rt = rt;
  return rt;
}

/**
 * Read log start level from file
 */
static repl_level_t
repl_log_start_level (char * name)
{
  repl_level_t volatile level = -1;
  dk_session_t * ses;
  caddr_t * head;
  int fd;

  if ((fd = fd_open (name, O_RDONLY | O_BINARY)) < 0)
    return -1;
  ses = dk_session_allocate (SESCLASS_TCPIP);
  tcpses_set_fd (ses->dks_session, fd);
  CATCH_READ_FAIL (ses)
    {
      head = (caddr_t*) read_object (ses);
      if (IS_BOX_POINTER (head) && head[LOGH_REPLICATION])
	{
	  caddr_t * repl = (caddr_t*) head[LOGH_REPLICATION];
	  level = (repl_level_t) unbox (repl[REPLH_LEVEL]);
	}
    }
  FAILED
    {
      level = -1;
    }
  END_READ_FAIL (ses);
  close (fd);
  PrpcSessionFree (ses);
  return level;
}

/**
 * Read repl.cfg
 *
 * Read replication trails and set their log start level
 */
static void
repl_read_cfg (void)
{
  repl_trail_file_t * rtf;
  FILE *cfg_file;
  char cfg_line[100];
  char srv[100];
  char acct[100];
  char file[100];
  repl_trail_t * volatile rt;

  cfg_file = fopen (REPL_CFG, "r");
  if (cfg_file)
    {
      while (fgets (cfg_line, sizeof (cfg_line), cfg_file))
	{
          repl_level_t level;
          char *curr_db_name;
          repl_acct_t *ra;

	  if (1 == sscanf (cfg_line, "db_name: %s", acct))
	    {
              if (db_name)
                dk_free_box (db_name);
              db_name = box_string (acct);
	      continue;
	    }

          if (3 == sscanf (cfg_line, "%s %s %s", srv, acct, file))
            curr_db_name = srv;
          else if (2 == sscanf (cfg_line, "%s %s", acct, file))
	    {
	      if (!db_name)
		{
		  log_error ("Add a db_name: line to repl.cfg");
		  call_exit (1);
		}
              curr_db_name = db_name;
            }
          else
            continue;

	  if (!repl_server_enable)
	    {
	      log_error (
		  "The repl.cfg has transactional replication roles defined, "
		  "but the Server is not enabled for transactional replication."
		  " Please re-enable the transactional replication support ("
		  " by setting the INI setting ServerEnable to 1) and restart"
		  " the server.");
	      call_exit (-1);
	    }
          ra = ra_find (curr_db_name, acct);
          if (!ra)
            {
              log_error ("Non-existent account '%s' from '%s'.", acct, curr_db_name);
              continue;
            }
          rt = ra->ra_rt;
	  if (!rt)
	    rt = repl_trail_add (ra, file);
          else
            {
	      dk_free_box (rt->rt_file_name);
	      rt->rt_file_name = box_string (file);
            }
	  level = repl_log_start_level (file);
	  rtf = rtf_allocate (file, level);
	  rt->rt_files = dk_set_conc (rt->rt_files, dk_set_cons (rtf, NULL));
	}
      fclose (cfg_file);
    }

  DO_SET (repl_acct_t *, ra, &repl_accounts)
    {
      int fd;
      OFF_T len;
      repl_trail_t *rt = ra->ra_rt;

      if (!ra->ra_rt)
        continue;

      file_set_rw (rt->rt_file_name);
      if ((fd = fd_open (rt->rt_file_name, OPEN_FLAGS)) < 0)
	{
          if (errno == ENOENT)
            {
              dbg_printf_1 (("repl_read_cfg: %s: ENOENT, ok", rt->rt_file_name));
              continue;
            }
	  log_error ("Can't open replication log '%s' : %m.", rt->rt_file_name);
	}
      else
        {
	  rt->rt_out = dk_session_allocate (SESCLASS_TCPIP);
	  tcpses_set_fd (rt->rt_out->dks_session, fd);
	  len = LSEEK (fd, 0, SEEK_END);
	  rt->rt_out->dks_bytes_sent = len;
	  rt->rt_commit_length = len;
	}
    }
  END_DO_SET();
}

static repl_message_t *
rm_allocate (void)
{
  NEW_VARZ (repl_message_t, rm);
  rm->rm_string = strses_allocate ();
  return rm;
}

static void
rm_rc_free (repl_message_t * rm)
{
  dk_free_box (rm->rm_acct);
  strses_free (rm->rm_string);
  dk_free ((caddr_t) rm, sizeof (repl_message_t));
}

static void
rm_clear (repl_message_t * rm)
{
  dk_free_box (rm->rm_acct);
  rm->rm_acct = NULL;
  strses_flush (rm->rm_string);
}

/**
 * Find replication message for account in trx lock
 *
 * If no replication message for account found in trx lock
 * new one is created in tr_rc and added to trx lock
 *
 * @param lt transaction lock
 * @param acct account
 * @returns replication message
 */
static repl_message_t *
lt_find_rm (lock_trx_t * lt, char * srv, char * acct)
{
  repl_message_t * rm;

  DO_SET (repl_message_t *, tr, &lt->lt_repl_logs)
    {
      if (0 == strcmp (tr->rm_acct, acct) &&
          0 == strcmp (tr->rm_srv, srv))
	return tr;
    }
  END_DO_SET();

  rm = (repl_message_t *) resource_get (tr_rc);
  rm->rm_srv = box_string (srv);
  rm->rm_acct = box_string (acct);
  dk_set_push (&lt->lt_repl_logs, (void *) rm);
  return rm;
}

void
log_repl_text_array (lock_trx_t * lt, char * srv, char * acct, caddr_t box)
{
  repl_message_t * rm;
  repl_acct_t *ra;

  if (!srv)
    srv = db_name;

  if (lt->lt_replicate == REPL_NO_LOG)
    return;
  if (0 != strcmp(srv, db_name) && lt->lt_repl_is_raw)
    {
      /*
       * do not log raw txn on updatable subscriber
       */
      return;
    }

  mutex_enter (lt->lt_log_mtx);
  if ((ra = ra_find (srv, acct)) == NULL)
    {
      mutex_leave (lt->lt_log_mtx);
      sqlr_new_error ("42000", "TR071", "Replication account missing for server '%s', account '%s' in logging replication.", srv, acct);
    }
  if (!ra->ra_rt)
    {
      mutex_leave (lt->lt_log_mtx);
      sqlr_new_error ("42000", "TR071", "Replication trail missing for server '%s', account '%s' in logging replication.", srv, acct);
    }
  rm = lt_find_rm (lt, srv, acct);
  session_buffered_write_char (LOG_TEXT, rm->rm_string);
  print_object (box, rm->rm_string, NULL, NULL);
  mutex_leave (lt->lt_log_mtx);
}

/* GK:calls log_repl_text_array on all the publications the item is participating in */
void
log_repl_text_array_all (const char *obj_name, int obj_type, caddr_t text,
    client_connection_t *cli, query_instance_t *qi, ptrlong opt_mask)
{
  local_cursor_t *lc_item;
  static query_t *tp_item = NULL;
  if (!tp_item)
    tp_item =
	sql_compile ("select TI_OPTIONS, TI_ACCT from DB.DBA.SYS_TP_ITEM where \
	TI_SERVER = ? and TI_ITEM = ? and TI_TYPE = ?",
	    bootstrap_cli, NULL, SQLC_DEFAULT);

  /* If procedure definition published for replication */
  if (tp_item)
    {
      caddr_t ti_opt = NULL;
      char * repl_acct_name;
      caddr_t err;
      err = qr_rec_exec (tp_item, cli, &lc_item, qi, NULL, 3,
	  ":0", db_name, QRP_STR,
	  ":1", obj_name, QRP_STR,
	  ":2", (ptrlong) obj_type, QRP_INT);
      while (lc_next (lc_item))
	{
	  ti_opt = lc_nth_col (lc_item, 0);
	  repl_acct_name = lc_nth_col (lc_item, 1);
	  if ((ptrlong) ti_opt & opt_mask)
	    log_repl_text_array (qi->qi_trx, NULL, repl_acct_name, (caddr_t) box_copy_tree (text));
	}
      lc_free (lc_item);
    }
}


void
trx_repl_log_ddl_index_def (query_instance_t * qi, caddr_t name, caddr_t table, caddr_t * cols, caddr_t * opts)
{
  caddr_t * arr;

  arr = (caddr_t *) dk_alloc_box ((opts ? 5 : 4) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  arr [0] = box_string (opts ? "__ddl_index_def (?,?,?,?)" : "__ddl_index_def (?,?,?)");
  arr [1] = box_string (name);
  arr [2] = box_string (table);
  arr [3] = box_copy_tree ((box_t) cols);
  if (opts)
    {
      arr [4] = (caddr_t) box_copy_tree ((box_t) opts);
    }
  log_repl_text_array_all (table, 2, (caddr_t) arr, qi->qi_client, qi,
      LOG_REPL_TEXT_ARRAY_MASK_ALL);
  dk_free_tree ((box_t) arr);
}


static void
lt_repl_log_truncate (lock_trx_t * lt)
{
  /* if not all logs successful, truncate to previous committed length */
  /* done as part of log section of transact, so serialized on page map */
  ASSERT_IN_TXN;
  DO_SET (repl_message_t *, rm, &lt->lt_repl_logs)
    {
      repl_acct_t *ra = ra_find (rm->rm_srv, rm->rm_acct);
      repl_trail_t *rt;

      if (!ra)
        continue;
      if ((rt = ra->ra_rt) == NULL)
        continue;

      if (rt->rt_out)
	{
	  FTRUNCATE (tcpses_get_fd (rt->rt_out->dks_session), rt->rt_commit_length);
	  LSEEK (tcpses_get_fd (rt->rt_out->dks_session), 0, SEEK_END);
	        rt->rt_out->dks_bytes_sent = rt->rt_commit_length;

	}
    }
  END_DO_SET();
}

static void
repl_rm_commit (repl_message_t * rm)
{
  long trx_len = strses_length (rm->rm_string);
  repl_acct_t *ra = ra_find (rm->rm_srv, rm->rm_acct);
  repl_trail_t *rt;
  repl_queue_t *rq;

  if (!ra || (rt = ra->ra_rt) == NULL)
    return;

  rwlock_rdlock (rt->rt_lock);
  mutex_enter (rt->rt_mtx);
  rt->rt_commit_length = rt->rt_out->dks_bytes_sent;
  if (rm->rm_blobs_start)
    GPF_T1 ("no blobs allowed in replication");

  rq = RA_IS_PUSHBACK(rm->rm_acct) ?  &repl_push_queue : &repl_queue;
  mutex_enter (rq->rq_mtx);
  if (rq->rq_to_disconnect)
    {
      rm_free (rm);
      mutex_leave (rq->rq_mtx);
      mutex_leave (rt->rt_mtx);
      rwlock_unlock (rt->rt_lock);
      return;
    }

  basket_add (&rq->rq_basket, rm);
  rq->rq_bytes += trx_len;
  if (rq->rq_bytes > repl_queue_max)
    {
      repl_message_t * rm_end = (repl_message_t *) resource_get (tr_rc);
      log_info ("Sync queue exceeded %ld bytes, disconnecting all subscriptions.",
          repl_queue_max);
      rm_end->rm_header = REPL_QUEUE_FULL;
      basket_add (&rq->rq_basket, rm_end);
      rq->rq_to_disconnect = 1;
      semaphore_leave (rq->rq_sem);
    }

  mutex_leave (rq->rq_mtx);
  semaphore_leave (rq->rq_sem);
  mutex_leave (rt->rt_mtx);
  rwlock_unlock (rt->rt_lock);
}

static void
rm_log_head (lock_trx_t * lt, repl_message_t * rm)
{
  repl_acct_t * ra = ra_find (rm->rm_srv, rm->rm_acct);
  long bytes = strses_length (rm->rm_string);
  caddr_t * cbox;
  caddr_t * repl =
    (caddr_t *) dk_alloc_box (
			      REPLH_CIRCULATION * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  cbox = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * LOG_HEADER_LENGTH,
				   DV_ARRAY_OF_POINTER);

  memset (repl, 0, box_length ((caddr_t) repl));
  memset (cbox, 0, sizeof (caddr_t) * LOG_HEADER_LENGTH);
  cbox[LOGH_TIME] = 0;
  cbox[LOGH_USER] = box_string ("");
  cbox[LOGH_BYTES] = box_num (bytes);

  repl[REPLH_SERVER] = box_string (db_name);
  repl[REPLH_ACCOUNT] = box_string (ra->ra_account);
  repl[REPLH_LEVEL] = box_num (ra_new_trx_no (lt, ra));
  log_sequence (lt, ra->ra_sequence, (long) unbox (repl[REPLH_LEVEL]));
  repl[REPL_ORIGIN] = box_copy_tree (lt->lt_replica_of ? lt->lt_replica_of : db_name);
  cbox[LOGH_REPLICATION] = (caddr_t) repl;
  rm->rm_header = cbox;
}

int
lt_log_replication (lock_trx_t * lt)
{
  int rc = LTE_OK;
  if (REPL_NO_LOG == lt->lt_replicate)
    return LTE_OK;
  DO_SET (repl_message_t *, rm, &lt->lt_repl_logs)
    {
      repl_acct_t *ra = ra_find (rm->rm_srv, rm->rm_acct);
      rm_log_head (lt, rm);
      rc = repl_write_extra_log (ra, rm->rm_header, rm->rm_string);
      if (rc != LTE_OK)
	break;
    }
  END_DO_SET ();
  dk_free_box (lt->lt_replica_of);
  lt->lt_replica_of = NULL;
  return rc;
}

void
lt_send_repl_cast (lock_trx_t * lt)
{
  DO_SET (repl_message_t *, rm, &lt->lt_repl_logs)
    {
      repl_rm_commit (rm);
    }
  END_DO_SET();
  dk_set_free (lt->lt_repl_logs);
  lt->lt_repl_logs = NULL;
  return;
}

void
lt_repl_rollback (lock_trx_t * lt)
{
  lt_repl_log_truncate (lt);
  DO_SET (repl_message_t *, rm, &lt->lt_repl_logs)
    {
    }
  END_DO_SET();
  dk_set_free (lt->lt_repl_logs);
  lt->lt_repl_logs = NULL;
  dk_free_box (lt->lt_replica_of);
  lt->lt_replica_of = NULL;
}

subscription_t *
sub_allocate (char * subscriber, char * account, dk_session_t *ses)
{
  NEW_VARZ (subscription_t, sub);

  sub->sub_account = box_string (account);
  sub->sub_session = ses;
  sub->sub_subscriber_name = box_string (subscriber);
  return sub;
}

void
sub_free (subscription_t * sub)
{
#if 0
  dbg_printf_1 (("sub_free: Disconnect replication for '%s' (sub->sub_session %p)",
      sub->sub_subscriber_name, sub->sub_session));
#endif
  if (sub->sub_session)
    {
#if 0
      dbg_printf_1 (("sub_free: sub->sub_session %p", sub->sub_session));
#endif
      PrpcCheckOut (sub->sub_session);
      PrpcDisconnect (sub->sub_session);
      PrpcSessionFree (sub->sub_session);
    }
  dk_free_box (sub->sub_account);
  dk_free_box (sub->sub_subscriber_name);
  dk_free ((caddr_t) sub, sizeof (*sub));
}

void
repl_sub_synced (subscription_t * sub, repl_level_t level_at)
{
  repl_message_t * rm;
  repl_queue_t * rq = RA_IS_PUSHBACK(sub->sub_account) ?
      &repl_push_queue : &repl_queue;
  int rq_to_disconnect;

  mutex_enter (rq->rq_mtx);
  rq_to_disconnect = rq->rq_to_disconnect;
  log_info ("Subscription of '%s' for '%s' level %ld moved to sync set.%s",
     sub->sub_subscriber_name, sub->sub_account, level_at,
     rq_to_disconnect ?
        " General disconnect pending, disconnecting this subscription." : "");
  if (rq_to_disconnect)
    {
      mutex_leave (rq->rq_mtx);
      if (!RA_IS_PUSHBACK(sub->sub_account))
        {
          /* Send resync message before disconnect */
          repl_send_resync (sub->sub_session);
          sub->sub_session->dks_to_close = 1;
          sub->sub_session = NULL;  /* will be freed by future_wrapper */
        }
      sub_free (sub);
      return;
    }
  rm = (repl_message_t *) resource_get (tr_rc);
  rm->rm_header = REPL_QUEUE_SYNCED;
  rm->rm_synced_sub = sub;
  basket_add (&rq->rq_basket, (void *) rm);
  mutex_leave (rq->rq_mtx);
  semaphore_leave (rq->rq_sem);
}

void
repl_sub_dropped(repl_queue_t * rq, dk_session_t * ses)
{
  repl_message_t * rm = (repl_message_t *) resource_get (tr_rc);

  remove_from_served_sessions (ses);

  rm->rm_header = REPL_QUEUE_DISCONNECT;
  rm->rm_data = (void *) ses;

  mutex_enter (rq->rq_mtx);
  if (rq->rq_to_disconnect)
    {
      mutex_leave (rq->rq_mtx);
      rm_free (rm);
      return;
    }
  basket_add (&rq->rq_basket, (void*) rm);
  mutex_leave (rq->rq_mtx);

  semaphore_leave (rq->rq_sem);
}

void
repl_purge (char *srv, char *acct)
{
  repl_queue_t *rq;
  repl_message_t *rm;

  if (!ra_find (srv, acct))
    {
      sqlr_new_error ("42000", "TR096",
          "Replication account '%s' from '%s' does not exist",
          acct, srv);
    }

  rm = (repl_message_t *) resource_get (tr_rc);
  rm->rm_header = REPL_PURGE;
  rm->rm_srv = box_string (srv);
  rm->rm_acct = box_string (acct);

  rq = RA_IS_PUSHBACK(acct) ?  &repl_push_queue : &repl_queue;
  mutex_enter (rq->rq_mtx);
  basket_add (&rq->rq_basket, rm);
  mutex_leave (rq->rq_mtx);
  semaphore_leave (rq->rq_sem);
}

static query_t *sched_save_qr;

/*
 * sched next purger run
 */
static void
repl_sched_purger (query_instance_t *qi, repl_acct_t *ra)
{
  char dt[DT_LENGTH];
  char now_str[32], next_str[32];
  TIMESTAMP_STRUCT now_ts, next_ts;

  caddr_t err;

  if (!sched_save_qr)
    {
      log_error ("NULL sched_save_qr: can't sched next purger run");
      return;
    }

  if (!ra->ra_p_time)
    {
      dbg_printf_1 (("repl_purge_end: (%s, %s): null p_time: next purger run not scheduled",
          ra->ra_server, ra->ra_account));
      return;
    }

  dt_now(dt);
  dt_to_string (dt, now_str, sizeof (now_str));
  dbg_printf_1 (("repl_purge_end: (%s, %s): now: %s",
      ra->ra_server, ra->ra_account, now_str));
  dt_to_timestamp_struct(dt, &now_ts);
  dt_to_timestamp_struct(dt, &next_ts);
  if (ra->ra_p_month)
    {
      /*
       * purger should be run yearly on every specified month and day
       */
      if (!ra->ra_p_day)
        ra->ra_p_day = 1;
      if (ra->ra_p_month <= now_ts.month)
        ts_add (&next_ts, 1, "year");
      ts_add (&next_ts, ra->ra_p_month - now_ts.month, "month");
      ts_add (&next_ts, ra->ra_p_day - now_ts.day, "day");
    }
  else if (ra->ra_p_day)
    {
      /*
       * purger should be run monthly on every specified day of month
       */
      if (ra->ra_p_day <= now_ts.day)
        ts_add (&next_ts, 1, "month");
      ts_add (&next_ts, ra->ra_p_day - now_ts.day, "day");
    }
  else if (ra->ra_p_wday)
    {
      /*
       * purger should be run weekly on every specified week day
       */
      int now_wday = date2weekday (now_ts.year, now_ts.month, now_ts.day);

      if (ra->ra_p_wday <= now_wday)
        ts_add (&next_ts, 7, "day");
      ts_add (&next_ts, ra->ra_p_wday - now_wday, "day");
    }
  else
    {
      /*
       * purger should be run daily
       */
      if (ra->ra_p_time->hour < now_ts.hour ||
          (ra->ra_p_time->hour == now_ts.hour &&
           ra->ra_p_time->minute <= now_ts.minute))
        ts_add (&next_ts, 1, "day");
    }

  ts_add (&next_ts, ra->ra_p_time->hour - now_ts.hour, "hour");
  ts_add (&next_ts, ra->ra_p_time->minute - now_ts.minute, "minute");
  next_ts.second = 0;
  timestamp_struct_to_dt (&next_ts, dt);
  dt_to_string (dt, next_str, sizeof (next_str));
  dbg_printf_1 (("repl_purge_end: (%s, %s): next run: %s",
      ra->ra_server, ra->ra_account, next_str));

  if (qi)
    {
      err = qr_rec_exec (sched_save_qr, qi->qi_client, NULL, qi, NULL, 6,
          ":0", ra->ra_server, QRP_STR,
          ":1", ra->ra_account, QRP_STR,
          ":2", now_str, QRP_STR,
          ":3", next_str, QRP_STR,
          ":4", ra->ra_server, QRP_STR,
          ":5", ra->ra_account, QRP_STR);
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

      err = qr_quick_exec (sched_save_qr, repl_util_cli, "", NULL, 6,
          ":0", ra->ra_server, QRP_STR,
          ":1", ra->ra_account, QRP_STR,
          ":2", now_str, QRP_STR,
          ":3", next_str, QRP_STR,
          ":4", ra->ra_server, QRP_STR,
          ":5", ra->ra_account, QRP_STR);
      if ((caddr_t) SQL_SUCCESS != err)
        {
          IN_TXN;
          lt_rollback (lt, TRX_CONT);
	  lt_leave (lt);
          LEAVE_TXN;
          log_error ("repl_purge_end: SQL Error: %s : %s",
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

void
repl_purge_run (repl_acct_t *ra)
{
  repl_trail_t *rt = ra->ra_rt;
  dk_set_t rtf_list_new = NULL;
  dk_set_t rtf_list_purge = NULL;
  repl_level_t level_at;
  FILE *cfg;

  if (!rt)
    {
      log_error ("Log purger: Replication trail missing for server '%s', account '%s'.", ra->ra_server, ra->ra_account);
      return;
    }

  rwlock_wrlock (rt->rt_lock);
  level_at = ra_trx_no (ra);
  dbg_printf_1 (("repl_purge_run: (%s, %s): level %ld",
      ra->ra_server, ra->ra_account, level_at));

  /*
   * build new repl trail files list
   */
  DO_SET (repl_trail_file_t *, rtf, &rt->rt_files)
    {
      repl_trail_file_t *rtf_new = rtf_allocate (rtf->rtf_file, rtf->rtf_level);

      if (REPL_LEVEL_OK (rtf->rtf_level, level_at))
        {
          log_info ("Log purger: %s (start level %ld): ok",
              rtf->rtf_file, rtf->rtf_level);
	  rtf_list_new = dk_set_conc (
              rtf_list_new, dk_set_cons (rtf_new, NULL));
        }
      else
        {
          log_info ("Log purger: %s (start level %ld): added to purge list",
              rtf->rtf_file, rtf->rtf_level);
	  rtf_list_purge = dk_set_conc (
              rtf_list_purge, dk_set_cons (rtf_new, NULL));
        }
    }
  END_DO_SET ();

  if (!rtf_list_purge)
    {
      rtf_list_free (rtf_list_new);
      rwlock_unlock (rt->rt_lock);
      goto purge_done;
    }

  /*
   * write new config
   */
  cfg = fopen (REPL_CFG_TMP, "w");
  if (cfg == NULL)
    {
      log_error ("Log purger: Can't open '%s' for write: %s (errno %d)",
          REPL_CFG_TMP, strerror (errno), errno);
      rtf_list_free (rtf_list_new);
      goto purge_done;
    }
  DO_SET (repl_acct_t *, r, &repl_accounts)
    {
      repl_trail_t *t = r->ra_rt;
      dk_set_t rtf_list;

      if (!t)
        continue;

      rtf_list = r == ra ? rtf_list_new : t->rt_files;
      DO_SET (repl_trail_file_t *, rtf, &rtf_list)
        {
          repl_cfg_writeln (cfg, r, rtf->rtf_file);
        }
      END_DO_SET ();
    }
  END_DO_SET ();
  fclose (cfg);
#ifdef WIN32
  file_set_rw (REPL_CFG);
  if (unlink (REPL_CFG) < 0)
    {
      log_error ("Log purger: Can't unlink '%s': %s (errno %d).",
          REPL_CFG, strerror (errno), errno);
      rtf_list_free (rtf_list_new);
      goto purge_done;
    }
#endif
  if (rename (REPL_CFG_TMP, REPL_CFG) < 0)
    {
      log_error ("Log purger: Can't rename '%s' to '%s': %s (errno %d).",
          REPL_CFG_TMP, REPL_CFG, strerror (errno), errno);
      rtf_list_free (rtf_list_new);
      goto purge_done;
    }

  /*
   * cfg is written successfully: purge files now
   */
  rtf_list_free (rt->rt_files);
  rt->rt_files = rtf_list_new;
  repl_trail_new_file (ra, NULL, 0);

  DO_SET (repl_trail_file_t *, rtf, &rtf_list_purge)
    {
      file_set_rw (rtf->rtf_file);
      if (unlink (rtf->rtf_file) < 0)
        {
          log_warning ("Log purger: unlink: %s: %s (errno %d).",
              rtf->rtf_file, strerror (errno), errno);
        }
      log_info ("Log purger: %s (start level %d): purged.",
          rtf->rtf_file, rtf->rtf_level);
      rtf_free (rtf);
    }
  END_DO_SET ();
  dk_set_free (rtf_list_purge);

purge_done:
  rwlock_unlock (rt->rt_lock);
  repl_sched_purger (NULL, ra);
}

static caddr_t
bif_repl_sched_purger (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  caddr_t srv = bif_string_arg (qst, args, 0, "repl_add_subscriber");
  caddr_t acct = bif_string_arg (qst, args, 1, "repl_add_subscriber");
  repl_acct_t *ra;
  (void) err_ret;

  if ((ra = ra_find (srv, acct)) == NULL)
    {
      sqlr_new_error ("42000", "TR097",
          "Replication account '%s' from '%s' does not exist",
          acct, srv);
    }

  repl_sched_purger (qi, ra);
  return 0;
}

void
repl_serv_init (int make_thr)
{
  (void) make_thr;

  tr_rc = resource_allocate (100, (rc_constr_t) rm_allocate, (rc_destr_t) rm_rc_free, (rc_destr_t) rm_clear, 0);
  replay_rc = resource_allocate (100, (rc_constr_t) rpm_allocate, (rc_destr_t) rpm_free, (rc_destr_t) rpm_clear, 0);
  replay_str_in = strses_allocate ();
  replay_cli = client_connection_create ();
  replay_cli->cli_is_log = 1;

  bif_define ("repl_sched_purger", bif_repl_sched_purger);

  repl_queue_init (&repl_queue);
  repl_queue_init (&repl_replay_queue);
  repl_queue_init (&repl_push_queue);

  cfg_mtx = mutex_allocate ();
  repl_read_cfg ();

  if (!PrpcThreadAllocate ((thread_init_func) repl_push_loop, future_thread_sz, NULL))
    {
      log_error ("Can's start the server because it can't create replication push thread. Exiting.");
      GPF_T;
    }

  if (repl_server_enable)
    {
      sched_save_qr = repl_compile (
          "insert replacing SYS_SCHEDULED_EVENT"
          " (SE_NAME, SE_START, SE_LAST_COMPLETED, SE_INTERVAL, SE_SQL) "
          "values (concat ('repl_purge_', ?, '_', ?), now(), now(), "
                  "datediff ('minute', stringdate(?), stringdate(?)), "
                  "sprintf ('repl_purge (''%s'', ''%s'')', ?, ?))");
      PrpcRegisterServiceDesc (&s_resync_replay, (server_func) sf_resync_replay);
      PrpcRegisterServiceDesc (&s_resync_acct, (server_func) sf_resync_acct);
      if (!PrpcThreadAllocate ((thread_init_func) resend_thread_loop, future_thread_sz, NULL))
        {
          log_error ("Can's start the server because it can't create replication resend thread. Exiting.");
          GPF_T;
        }

      if (!PrpcThreadAllocate ((thread_init_func) repl_replay_loop, future_thread_sz, NULL))
        {
          log_error ("Can's start the server because it can't create replication replay thread. Exiting.");
          GPF_T;
        }
    }
}

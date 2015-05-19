/*
 *  log.c
 *
 *  $Id$
 *
 *  Transaction log write and recovery
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

#include "sqlnode.h"
#include "sqlfn.h"
#include "sqlver.h"
#include "log.h"
#include "repl.h"
#include "datesupp.h"
/* IvAn/XperUpdate/000904 Xper support added. */
#include "xmltree.h"
#include "security.h"
#include "aqueue.h"

#ifdef WIN32
# include "wiservic.h"
#endif

#ifdef VIRTTP

#include "2pc.h"
#include "msdtc.h"

#include "geo.h"

int virt_tp_recover (box_t recovery_data);

int log_2pc_count=0;
#endif


caddr_t list (long n, ...);
void tcpses_set_fd (session_t * ses, int fd);
int tcpses_get_fd (session_t * ses);

int is_old_log_type = 0;

int _xa_log_ctr = 0;


void
err_log_error (caddr_t err)
{
  if (err == (caddr_t) SQL_NO_DATA_FOUND)
    log_error ("SQL Error: No data found");
  else
    {
      log_error ("SQL Error: %s : %s",
          ((caddr_t *) err)[1], ((caddr_t *) err)[2]);
    }
}


extern uint32 lt_w_counter;


void
log_set_compatibility_check (int in_txn, char *strg)
{
  caddr_t * cbox;
  caddr_t cl_2pc = NULL;
  int64 trx_no;
  dk_session_t * ses;
  caddr_t box;
  dbe_storage_t * dbs = wi_inst.wi_master;
  caddr_t trx_string;
  ASSERT_IN_MTX (log_write_mtx);
  dbs->dbs_log_session->dks_bytes_sent = 0;
  cbox = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * LOG_HEADER_LENGTH,
				   DV_ARRAY_OF_POINTER);
  ses = strses_allocate();
  CATCH_WRITE_FAIL (dbs->dbs_log_session)
    {

      session_buffered_write_char (LOG_TEXT, ses);
      box = box_string (strg);
      print_object (box, ses, NULL, NULL);
      dk_free_box (box);

      trx_string = strses_string (ses);
      if (CL_RUN_LOCAL != cl_run_local_only)
	{
	  uint32 w_id = lt_w_counter++;
	  if (!w_id)
	    w_id = lt_w_counter++;
	  cl_2pc = dk_alloc_box (2 + sizeof (int64), DV_STRING);
	  cl_2pc[0] = LOG_2PC_COMMIT;
	  trx_no = (((int64)local_cll.cll_this_host) <  32) + w_id;
	  INT64_SET_NA (cl_2pc + 1, trx_no);
	}
      memset (cbox, 0, sizeof (caddr_t) * LOG_HEADER_LENGTH);
      cbox[LOGH_CL_2PC] = cl_2pc;
      cbox[LOGH_2PC] = box_num(LOG_2PC_DISABLED);
      cbox[LOGH_USER] = box_string ("");
      cbox[LOGH_BYTES] = box_num (strses_length (ses));

      print_object ((caddr_t) cbox, dbs->dbs_log_session, NULL, NULL);
      session_buffered_write (dbs->dbs_log_session, trx_string, strses_length (ses));
      dk_free_box (trx_string);
      strses_free (ses);
      dk_free_tree ((caddr_t) cbox);
      session_flush_1 (dbs->dbs_log_session);
      dbs->dbs_log_length += dbs->dbs_log_session->dks_bytes_sent;
    }
  END_WRITE_FAIL (dbs->dbs_log_session);
}


void
log_set_byte_order_check (int in_txn)
{
  dbe_storage_t * dbs = wi_inst.wi_master;
  char tmp[255];
  if (!dbs->dbs_log_session)
    return;

  sprintf (tmp, "byte_order_check (%d)", DB_SYS_BYTE_ORDER);
  log_set_compatibility_check (in_txn, tmp);
}


void
log_set_server_version_check (int in_txn)
{
  dbe_storage_t * dbs = wi_inst.wi_master;
  char tmp[255];
  if (!dbs->dbs_log_session)
    return;

  sprintf (tmp, "server_version_check ('%s')", DBMS_SRV_VER);
  log_set_compatibility_check (in_txn, tmp);
  if (wi_inst.wi_master->dbs_id[0])
    {
      int inx;
      char hex[33];
      for (inx = 0; inx < sizeof (wi_inst.wi_master->dbs_id); inx ++)
	{
	  sprintf (hex + (inx * 2), "%02x", (unsigned char) (wi_inst.wi_master->dbs_id[inx]));
	}
      hex[32] = 0;
      sprintf (tmp, "server_id_check ('%s')", hex);
      log_set_compatibility_check (in_txn, tmp);
    }
}


int
log_enable_segmented (int rewrite)
{
  int fd;
  dbe_storage_t * dbs = wi_inst.wi_master;
  log_segment_t *ls = dbs->dbs_log_segments;
  if (!ls)
    return LTE_OK;
  dbs->dbs_current_log_segment = ls;
  dbs->dbs_log_name = box_string (ls->ls_file);
  fd = fd_open (ls->ls_file, LOG_OPEN_FLAGS);
  if (fd < 0)
    return LTE_LOG_FAILED;
  if (!dbs->dbs_log_session)
    {
      dbs->dbs_log_session = dk_session_allocate (SESCLASS_TCPIP);
    }
  else
    {
      close (tcpses_get_fd (dbs->dbs_log_session->dks_session));
    }
  tcpses_set_fd (dbs->dbs_log_session->dks_session, fd);
  if (rewrite)
    {
    FTRUNCATE (fd, 0);
      log_set_byte_order_check (1);
      log_set_server_version_check (1);
    }
  return LTE_OK;
}


void
srv_report_errno_trx_error (lock_trx_t *lt, const char *text, const char *name, int eno)
{
  LT_ERROR_DETAIL_SET (lt,
        box_sprintf (300,
	"%.30s %.160s : %.100s", text, name, virt_strerror (eno)));
}

uint32 last_log_time_written = 0;
int log_in_cl_recov;


caddr_t *
log_time_header (caddr_t dt)
{
  caddr_t dtb = dk_alloc_box (DT_LENGTH, DV_DATETIME);
  caddr_t * box = (caddr_t*)dk_alloc_box_zero (LOG_HEADER_LENGTH * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  int64 w_id = ((int64)local_cll.cll_this_host) << 32 | lt_w_counter;
  memcpy (dtb, dt, DT_LENGTH);
  box[LOGH_USER] = list (2, dtb, box_num (w_id));
  return box;
}


int
log_time (caddr_t * box)
{
  /* add real time to log.  If the time entry is given in log sync write it as it is.  Else make time markers only if online */
  if (!box && CH_ONLINE != cl_stage)
    return LTE_OK;
  if (!box && log_in_cl_recov)
    return LTE_OK;
  if (!box && (!last_log_time_written
	       || approx_msec_real_time () - last_log_time_written > 30000))
    {
      char dt[DT_LENGTH];
      dt_now (dt);
      box = log_time_header (dt);
      last_log_time_written = approx_msec_real_time ();
    }
  ASSERT_IN_MTX (log_write_mtx);
  if (box)
    {
      dbe_storage_t * dbs = wi_inst.wi_master;
      OFF_T prev_length;
      dk_session_t * log_ses = dbs->dbs_log_session;
      prev_length = dbs->dbs_log_length;
      log_ses->dks_bytes_sent = 0;
      CATCH_WRITE_FAIL (log_ses)
	{
	  print_object ((caddr_t) box, log_ses, NULL, NULL);
	  session_flush_1 (log_ses);
	}
      END_WRITE_FAIL (log_ses);
      dk_free_tree ((caddr_t)box);
      if (!DKSESSTAT_ISSET (log_ses, SST_OK))
	{
	  log_ses->dks_out_fill = 0; /* clear maybe unflushed */
	  FTRUNCATE (tcpses_get_fd (log_ses->dks_session), prev_length);
	  return LTE_LOG_FAILED;
	}
      dbs->dbs_log_length += log_ses->dks_bytes_sent;
    }
  return LTE_OK;
}

int32 log_extent_if_needed = 1;

#ifdef WIN32
#define PATH_MAX	 MAX_PATH
#endif

int
log_change_if_needed (lock_trx_t * lt, int rewrite)
{
  int old_fd;
  int new_fd;
  static int ctr;
  dbe_storage_t * dbs = wi_inst.wi_master;
  log_segment_t *ls = dbs->dbs_current_log_segment;
  if (lt->lt_backup)
    return LTE_OK;
  if (!ls || !dbs->dbs_log_session)
    return LTE_OK;
  if (dbs->dbs_log_length > ls->ls_bytes)
    {
      old_fd = tcpses_get_fd (dbs->dbs_log_session->dks_session);
      if (!ls->ls_next && log_extent_if_needed)
	{
	  char * dot, tmp[PATH_MAX], fname[PATH_MAX];
	  NEW_VARZ (log_segment_t, nls);
	  ctr ++;
	  nls->ls_bytes = ls->ls_bytes;
	  strncpy (tmp, ls->ls_file, sizeof (tmp));
          dot = strrchr (tmp, '.');
	  if (atoi (dot+1) > 0)
	    *dot = 0;
	  snprintf (fname, sizeof (fname), "%s.%d", tmp, ctr);
	  nls->ls_file = box_string (fname);
	  ls->ls_next = nls;
	}
      ls = ls->ls_next;
      if (!ls)
	{
	  LT_ERROR_DETAIL_SET (lt, box_dv_short_string ("No more log segments"));
	  return LTE_LOG_FAILED;
	}
      dbs->dbs_current_log_segment = ls;
      new_fd = fd_open (ls->ls_file, LOG_OPEN_FLAGS);
      if (new_fd < 0)
	{
	  srv_report_errno_trx_error (lt, "Error opening the log segment file",
	      ls->ls_file, errno);
	  return LTE_LOG_FAILED;
	}
      close (old_fd);
      tcpses_set_fd (dbs->dbs_log_session->dks_session, new_fd);
      dbs->dbs_log_length = 0;
      dbs->dbs_log_name = box_string (ls->ls_file);
      if (rewrite)
	{
	  FTRUNCATE (new_fd, 0);
	  log_set_byte_order_check (1);
	  log_set_server_version_check (1);
	}
    }
  return LTE_OK;
}


int dbf_log_fsync = 0;

void
log_fsync (dk_session_t * ses)
{
  if (dbf_log_fsync)
    fd_fsync (tcpses_get_fd (ses->dks_session));
}


extern long dbf_log_no_disk;

int
log_commit (lock_trx_t * lt)
{
  int log_for_flt = 0;
  dbe_storage_t * dbs = wi_inst.wi_master;
  volatile OFF_T prev_length;
  dk_session_t * volatile log_ses;
  long bytes = strses_length (lt->lt_log);
  caddr_t *cbox;
  if (lt->lt_replicate == REPL_NO_LOG
      || (LT_CL_PREPARED != lt->lt_status && !bytes) || cl_non_logged_write_mode)
    return LTE_OK;
  if (dbf_log_no_disk)
    return LTE_LOG_FAILED;
  ASSERT_IN_MTX (log_write_mtx);
  prev_length = dbs->dbs_log_length;
  log_ses = dbs->dbs_log_session;
  if (!dbs->dbs_log_session)
    {
      OFF_T off;
      int fd;
      file_set_rw (dbs->dbs_log_name);
      fd = fd_open (dbs->dbs_log_name, LOG_OPEN_FLAGS);
      off = LSEEK (fd, 0, SEEK_END);
      if (strchr (wi_inst.wi_open_mode, 'D') && off)
	{
	  log_error ("There is a non-zero length log when starting crash dump.  Please move this log away, complete  the crash dump and recovery and then replay this log, using the -R or +restore-crash-dump command line option.  Exiting.\n");
	  exit (1);
	}
      log_ses = dbs->dbs_log_session = dk_session_allocate (SESCLASS_TCPIP);
      tcpses_set_fd (dbs->dbs_log_session->dks_session, fd);
      dbs->dbs_log_length = off;
      prev_length = off;
    }

  cbox = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * LOG_HEADER_LENGTH,
				   DV_ARRAY_OF_POINTER);
  memset (cbox, 0, sizeof (caddr_t) * LOG_HEADER_LENGTH);
  if (local_cll.cll_is_flt && !lt->lt_cl_branches && !lt->lt_cl_enlisted)
    log_for_flt = 1; /* If fault tolerance, log local only transactions as 2pc with commit since might need to ship for sync */
  if (lt->lt_log_2pc || log_for_flt)
    {
      caddr_t id = dk_alloc_box (10, DV_STRING);
      id[0] = log_for_flt ? LOG_2PC_COMMIT : LOG_CL_2PC_PREPARE;
      if (lt->lt_need_branch_consensus)
	id[0] = LOG_CL_2PC_PREPARE_FROM_SYNC;
      /* logging a 1pc needs only update of log if rollback */
      lt->lt_commit_flag_offset = dbs->dbs_log_length + LOGH_COMMIT_FLAG_OFFSET (lt);
      INT64_SET_NA (id + 1, lt->lt_w_id);
      if (lt->lt_2pc_hosts)
	id = list (2, id, box_copy_tree (lt->lt_2pc_hosts));
      cbox[LOGH_CL_2PC] = id;
    }
  else
    cbox[LOGH_CL_2PC] = 0;
  if (!lt->lt_branch_of && lt->lt_client && lt->lt_client->cli_user)
    cbox[LOGH_USER] = box_string (lt->lt_client->cli_user->usr_name);
  else
    cbox[LOGH_USER] = box_string ("");


#ifdef VIRTTP
  if ((LT_PREPARE_PENDING == lt->lt_status) &&
      lt->lt_2pc._2pc_log)
    {
      log_2pc_count++;
      if (lt->lt_2pc._2pc_type == TP_VIRT_TYPE)
	cbox[LOGH_2PC] = box_num(LOG_VIRT_2PC_PREPARE);
      else if (lt->lt_2pc._2pc_type == TP_MTS_TYPE)
	cbox[LOGH_2PC] = box_num(LOG_MTS_2PC_PREPARE);
      else if (lt->lt_2pc._2pc_type == TP_XA_TYPE)
	cbox[LOGH_2PC] = box_num(LOG_XA_2PC_PREPARE);
      else
	GPF_T1 ("unknown type of distributed transaction");
      cbox[LOGH_BYTES] = box_num (bytes + box_length(lt->lt_2pc._2pc_log)+2);
      /* log_info ("box.l=%d", box_length (lt->lt_2pc._2pc_log)); */
    } else
      {
	cbox[LOGH_2PC] = box_num(LOG_2PC_DISABLED);
	cbox[LOGH_BYTES] = box_num (bytes);
      }
#else
    cbox[LOGH_BYTES] = box_num (bytes);
#endif

  if (lt->lt_backup)
    {
      log_ses = lt->lt_backup;
      prev_length = lt->lt_backup_length;
    }
  log_ses->dks_bytes_sent = 0;
#if LOG_DEBUG_LEVEL>1
   long start_log_pos=log_ses->dks_out_fill; /* strses_length (log_ses); */
#endif
  CATCH_WRITE_FAIL (log_ses)
  {
    print_object ((caddr_t) cbox, log_ses, NULL, NULL);
#ifdef VIRTTP
    if (LT_PREPARE_PENDING == lt->lt_status)
      {
	lt->lt_2pc._2pc_logged = prev_length + log_ses->dks_bytes_sent
	    + log_ses->dks_out_fill - 1;
	if (lt->lt_2pc._2pc_log)
	  print_object ((caddr_t) lt->lt_2pc._2pc_log, log_ses, NULL, NULL);
	/* dk_free_box(lt->lt_2pc._2pc_log);
	lt->lt_2pc._2pc_log = 0; */
	if (lt->lt_2pc._2pc_type == TP_XA_TYPE)
	  {
	    mutex_enter (global_xa_map->xm_mtx);
	    txa_from_trx (lt, dbs->dbs_log_name);
	    mutex_leave (global_xa_map->xm_mtx);
	  }
      }
#endif
    strses_write_out (lt->lt_log, log_ses);
    session_flush_1 (log_ses);
    log_fsync (log_ses);
#if LOG_DEBUG_LEVEL>1
  fprintf(stderr, "** log_commit from %ld to %ld\n", start_log_pos, log_ses->dks_bytes_sent);
#endif
  }
  END_WRITE_FAIL (log_ses);
  if (lt->lt_blob_log)
    {
      lt_write_blob_log (lt, log_ses);
#if LOG_DEBUG_LEVEL>1
  long end_log_pos=log_ses->dks_out_fill+log_ses->dks_bytes_sent; /* strses_length (log_ses); */
  fprintf(stderr, "           blob added till %ld\n", end_log_pos);
#endif
    }

  if (!lt->lt_backup)
    {
      dk_free_tree ((caddr_t) cbox);
    }
  else
    dk_free_tree ((caddr_t) cbox);

  if (!DKSESSTAT_ISSET (log_ses, SST_OK))
    {
      log_ses->dks_out_fill = 0; /* clear maybe unflushed */
      FTRUNCATE (tcpses_get_fd (log_ses->dks_session), prev_length);
      log_fsync (log_ses);
      log_error ("Out of disk space for log");
      LT_ERROR_DETAIL_SET (lt, box_dv_short_string ("Out of disk space for log"));
      return LTE_LOG_FAILED;
    }

  {
      if (!lt->lt_backup)
	{
	dbs->dbs_log_length += log_ses->dks_bytes_sent;
	  log_time (NULL);
	}
      else
	{
	lt->lt_backup_length += log_ses->dks_bytes_sent;
	}
      if (autocheckpoint_log_size > 0 &&
	  dbs->dbs_log_length >= autocheckpoint_log_size &&
	  !auto_cpt_scheduled)
      {
	auto_cpt_scheduled = 1;
	semaphore_leave(background_sem);
      }
#ifndef VIRTTP
      return (log_change_if_needed (lt, 1));
#else
      if (!log_2pc_count)
	return (log_change_if_needed (lt, 1));
      else
	{
	  log_audit_trail = 0;
	  return LTE_OK;
	}
#endif
    }
}

extern dk_mutex_t * log_write_mtx;
dk_session_t * sync_log =  NULL;

int
log_text_array_sync (lock_trx_t * lt, caddr_t box)
{
  int rc;
  dk_session_t * lt_log;
  dk_set_t blob_log;
  if (!lt || lt->lt_replicate == REPL_NO_LOG || cl_non_logged_write_mode)
    return LTE_OK;
  ASSERT_IN_MTX (log_write_mtx);
  lt_log = lt->lt_log;
  blob_log = lt->lt_blob_log;
  lt->lt_blob_log = NULL;
  if(!sync_log)
    sync_log = strses_allocate ();
  lt->lt_log =sync_log;
  session_buffered_write_char (LOG_TEXT, lt->lt_log);
  print_object (box, lt->lt_log, NULL, NULL);
  rc = log_commit (lt);
  strses_flush (sync_log);
  sync_log->dks_bytes_sent = 0;

  lt->lt_log = lt_log;
  lt->lt_blob_log = blob_log;
  return rc;
}


int
log_insert_sync (lock_trx_t * lt, row_delta_t * rd, int flag)
{
  int rc;
  dk_session_t * lt_log;
  dk_set_t blob_log;
  if (!lt || lt->lt_replicate == REPL_NO_LOG || cl_non_logged_write_mode)
    return LTE_OK;
  mutex_enter (log_write_mtx);
  lt_log = lt->lt_log;
  blob_log = lt->lt_blob_log;
  lt->lt_blob_log = NULL;
  if(!sync_log)
    sync_log = strses_allocate ();
  lt->lt_log =sync_log;
  log_insert (lt, rd, flag);
  rc = log_commit (lt);
  strses_flush (sync_log);
  sync_log->dks_bytes_sent = 0;

  lt->lt_log = lt_log;
  lt->lt_blob_log = blob_log;
  mutex_leave (log_write_mtx);
  return rc;
}


int
log_sequence_sync (lock_trx_t * lt, caddr_t seq, boxint count)
{
  int rc;
  int64 old_w_id;
  dk_session_t * lt_log;
  dk_set_t blob_log;
  if (!lt || lt->lt_replicate == REPL_NO_LOG || cl_non_logged_write_mode)
    return LTE_OK;
  mutex_enter (log_write_mtx);
  lt_log = lt->lt_log;
  blob_log = lt->lt_blob_log;
  lt->lt_blob_log = NULL;
  if(!sync_log)
    sync_log = strses_allocate ();
  lt->lt_log =sync_log;
  log_sequence (lt, seq, count);
  old_w_id = lt->lt_w_id;
  lt->lt_w_id = 0; /* do not log a w id because it could collide with a real w id in replay if shipped from other log and shadow a real transaction */
  rc = log_commit (lt);
  lt->lt_w_id = old_w_id;
  strses_flush (sync_log);
  sync_log->dks_bytes_sent = 0;

  lt->lt_log = lt_log;
  lt->lt_blob_log = blob_log;
  mutex_leave (log_write_mtx);
  return rc;
}




#ifdef VIRTTP
int
log_final_transact(lock_trx_t* lt, int is_commit)
{
  dbe_storage_t * dbs = wi_inst.wi_master;
  if (lt->lt_2pc._2pc_logged)
    {
      STAT_T st;
      int fd = tcpses_get_fd(dbs->dbs_log_session->dks_session);
      V_FSTAT (fd, &st);
      LSEEK (fd, lt->lt_2pc._2pc_logged, SEEK_SET);
      write (fd, is_commit ? LOG_2PC_COMMIT_S : LOG_2PC_ABORT_S ,1);
      LSEEK (fd, 0, SEEK_END);
      lt->lt_2pc._2pc_logged = 0;
      if (!--log_2pc_count)
        return log_change_if_needed (lt, 1);
    }
  return log_change_if_needed (lt, 1);
}
#endif



void
log_skip_blobs_1 (dk_session_t * ses)
{
  /* when reading over log entries, may get blobs, read until there is an array for the header */
  CATCH_READ_FAIL (ses)
    {
      for (;;)
	{
	  dtp_t dtp = session_buffered_read_char (ses);
	  caddr_t xx;
	  if (!DKSESSTAT_ISSET (ses, SST_OK))
	    return;
	  if (DV_ARRAY_OF_POINTER == dtp)
	    {
	      ses->dks_in_read--;
	      return;
	    }
	  if (0 == dtp)
	    continue;
	  if (DV_BLOB == dtp || DV_BLOB_WIDE == dtp || DV_BLOB_XPER == dtp)
	    {
	      int bytes = read_long (ses);
	      caddr_t x = dk_alloc (bytes);
	      session_buffered_read (ses, x, bytes);
	      dk_free (x, bytes);
	      continue;
	    }
	  ses->dks_in_read--;
	  xx = read_object (ses);
	  dk_free_box (xx);
	}
    }
  FAILED
    {
      SESSTAT_SET (ses->dks_session, SST_BROKEN_CONNECTION);
      SESSTAT_CLR (ses->dks_session, SST_OK);
    }
  END_READ_FAIL (ses);
}

uint32 log_last_2pc_archive_time = 0;


int
log_2pc_archive (int64 trx_id)
{
  dbe_storage_t * dbs = wi_inst.wi_master;
  dk_session_t * ses = dbs->dbs_2pc_log_session;
  if (!dbs->dbs_2pc_file_name)
    return LTE_OK;
  if (!ses)
    {
      int fd;
      file_set_rw (dbs->dbs_2pc_file_name);
      fd = fd_open (dbs->dbs_2pc_file_name, LOG_OPEN_FLAGS);
      if (fd < 0)
	{
	  int errn = errno;
	  log_error ("Cannot open 2pc log %s, error : %s.  Exiting", dbs->dbs_2pc_file_name, virt_strerror (errn));
	  call_exit (-1);
	}
      ses = dbs->dbs_2pc_log_session = dk_session_allocate (SESCLASS_TCPIP);
      LSEEK (fd, 0, SEEK_END);
      tcpses_set_fd (ses->dks_session, fd);
    }
  CATCH_WRITE_FAIL (ses)
    {
      int64 bs = ses->dks_bytes_sent;
      if (!log_last_2pc_archive_time || approx_msec_real_time () - log_last_2pc_archive_time > 30000)
	{
	  caddr_t dt = dk_alloc_box (DT_LENGTH, DV_DATETIME);
	  if (in_log_replay || log_in_cl_recov)
	    memcpy (dt, wi_inst.wi_log_replay_dt, DT_LENGTH);
	  else
	    dt_now (dt);
	  print_object (dt, ses, NULL, NULL);
	  dk_free_box (dt);
	  log_last_2pc_archive_time = approx_msec_real_time ();
	}
      print_int (trx_id, ses);
      if (bs != ses->dks_bytes_sent)
	session_flush_1 (ses);
    }
  FAILED
    {
    }
  END_WRITE_FAIL (ses);
  return LTE_OK;
}


int
log_2pc_archive_check (int64 trx_id, int64 * max_id_ret)
{
  dbe_storage_t * dbs = wi_inst.wi_master;
  uint32 last_id = 0;
  int fd;
  dk_session_t * ses;
  ASSERT_IN_MTX (log_write_mtx);
  if (!dbs->dbs_2pc_file_name)
    return 0;
  file_set_rw (dbs->dbs_2pc_file_name);
  fd  = fd_open (dbs->dbs_2pc_file_name, OPEN_FLAGS_RO);
  if (fd < 0)
    {
      *max_id_ret = 0;
      return 0;
    }
  ses = dk_session_allocate (SESCLASS_TCPIP);
  tcpses_set_fd (ses->dks_session, fd);
  CATCH_READ_FAIL (ses)
    {
      while (DKSESSTAT_ISSET (ses, SST_OK))
	{
	  caddr_t item = read_object (ses);
	  if (DV_LONG_INT == DV_TYPE_OF (item))
	    {
	      int64 id = unbox (item);
	      if (id == trx_id)
		{
		  close (fd);
		  PrpcSessionFree (ses);
		  return 1;
		}
	      if (QFID_HOST (id) == local_cll.cll_this_host
		  && (!last_id || W_ID_GT ((uint32)id, last_id)))
		last_id = (uint32)id;
	    }
	  dk_free_box (item);
	}
    }
  FAILED
    {
    }
  END_READ_FAIL (ses);
  close (fd);
  PrpcSessionFree (ses);
  *max_id_ret = (((int64)local_cll.cll_this_host) << 32) + last_id;
  return 0;
}


void
log_cl_final(lock_trx_t* lt, int is_commit)
{
  dbe_storage_t * dbs = wi_inst.wi_master;
  if (lt->lt_commit_flag_offset)
    {
      STAT_T st;
      int fd;
      char s = SQL_COMMIT == is_commit ? LOG_2PC_COMMIT : LOG_2PC_ABORT;
      ASSERT_OUTSIDE_MTX (wi_inst.wi_txn_mtx);
      mutex_enter (log_write_mtx);
      /* second check inside the log write mtx */
      if (lt->lt_commit_flag_offset)
	{
	  OFF_T end;
	  fd = tcpses_get_fd(dbs->dbs_log_session->dks_session);
	  V_FSTAT(fd,&st);
	  if (lt->lt_commit_flag_offset !=  LSEEK(fd,lt->lt_commit_flag_offset,SEEK_SET))
	    GPF_T1 ("failed lseek in cl commit final");
	  write(fd, &s, 1);
	  if (dbs->dbs_log_length != (end = LSEEK(fd,0,SEEK_END)))
	    {
	      log_error ("Logging at offset " OFF_T_PRINTF_FMT " where end of log file is " OFF_T_PRINTF_FMT ".",
		  	(OFF_T_PRINTF_DTP) end, (OFF_T_PRINTF_DTP) dbs->dbs_log_length);
	      GPF_T1 ("dbs_log_length and end of log file differ");
	    }
	  lt->lt_commit_flag_offset = 0;
	  if (SQL_COMMIT == is_commit && (QFID_HOST (lt->lt_w_id) == local_cll.cll_this_host || local_cll.cll_is_flt))
	    log_2pc_archive (lt->lt_w_id);
	}
      mutex_leave (log_write_mtx);
    }
}


void
print_string_as_wide (caddr_t str, dk_session_t * ses)
{
  /* str is utf8 of a wide, print with wide tag */
  int l = box_length (str) - 1;
  if (l < 256)
    {
      session_buffered_write_char (DV_WIDE, ses);
      session_buffered_write_char (l, ses);
    }
  else
    {
      session_buffered_write_char (DV_LONG_WIDE, ses);
      print_long (l, ses);
    }
  session_buffered_write (ses, str, l);
}


void
print_string_as_any (caddr_t str, dk_session_t * ses)
{
  session_buffered_write (ses, str, box_length (str) - 1);
}


void
lt_log_prime_key (lock_trx_t * lt, row_delta_t * rd, int is_upd)
{
  dbe_col_loc_t * col_cl;
  dbe_key_t * key = rd->rd_key;
  int inx;
  dks_array_head (lt->lt_log, 1 + key->key_n_significant, DV_ARRAY_OF_POINTER);
  print_int (key->key_id, lt->lt_log);
  col_cl = key->key_key_fixed;
  if (!col_cl->cl_col_id)
    col_cl = key->key_key_var;
  for (inx = 0; inx < key->key_n_significant; inx++)
    {
      dtp_t col_dtp = col_cl->cl_sqt.sqt_col_dtp;
      if (DV_WIDE == col_dtp && DV_STRING == DV_TYPE_OF (rd->rd_values[inx]))
	print_string_as_wide (rd->rd_values[inx], lt->lt_log); /* col-wise will have wide from the dc, row-wise will have narrow utf8 from the row, either is logged so that read makes a wide box */
      else if (is_upd && DV_ANY == col_dtp && !rd->rd_key->key_is_col)
	print_string_as_any (rd->rd_values[inx], lt->lt_log); /* row-wise any keys are as a string with serialization inside, other anies are all with the box in the rd */
      else
    print_object (rd->rd_values[inx], lt->lt_log, NULL, NULL);
      col_cl++;
      if (!col_cl->cl_col_id)
	col_cl = key->key_key_var;
    }
}


size_t txn_after_image_limit = 50000000L;
#define TXN_CHECK_LOG_IMAGE(lt) \
  if (!lt->lt_backup && txn_after_image_limit > 0 && lt->lt_log->dks_bytes_sent > (OFF_T) txn_after_image_limit) \
    { \
      (lt)->lt_status = LT_BLOWN_OFF; \
      (lt)->lt_error = LTE_LOG_IMAGE; \
    }


int enable_log_key_count = 0;
dk_hash_t * ins_log_counts;
void
log_key_report ()
{
  DO_HT (ptrlong, key_id, ptrlong, ctr, ins_log_counts)
    {
      dbe_key_t * key = sch_id_to_key (wi_inst.wi_schema, key_id);
      printf ("%ld %s: %ld\n", key_id, key ? key->key_name : "- ", ctr);
    }
  END_DO_HT;
}

void
log_key_count (ptrlong key_id)
{
  ptrlong ctr;
  if (!ins_log_counts)
    ins_log_counts = hash_table_allocate (101);
  ctr = (ptrlong)gethash ((void*)(ptrlong)key_id, ins_log_counts);
  sethash ((void*)(ptrlong)key_id, ins_log_counts, (void*)(ctr + 1));
}

dbe_col_loc_t *
key_layout_nth_cl (dbe_key_t * key, int nth)
{
  int inx = 0;
  if (key->key_is_col && nth >= key->key_n_significant)
    {
      if (nth >= key->key_n_parts - key->key_n_significant)
	return NULL;
      return &key->key_row_var[nth];
    }
  DO_ALL_CL (cl, key)
    {
      if (nth == inx)
	return cl;
      inx++;
    }
  END_DO_ALL_CL;
  return NULL;
}


int
lt_log_merge (lock_trx_t * lt, int in_txn)
{
  ptrlong plt;
  lock_trx_t * main_lt;
  if (LT_PENDING != lt->lt_status || !lt->lt_rc_w_id || lt->lt_rc_w_id == lt->lt_w_id
      || !strses_out_bytes (lt->lt_log))
    return LTE_OK;
  if (!in_txn)
    IN_TXN;
  ASSERT_IN_TXN;
  gethash_64 (plt, lt->lt_rc_w_id, local_cll.cll_w_id_to_trx);
  main_lt = (lock_trx_t *)plt;
  if (!main_lt || LT_PENDING != main_lt->lt_status)
    {
      lt->lt_status = LT_BLOWN_OFF;
      lt->lt_error = LTE_CANCEL;
      if (!in_txn)
	LEAVE_TXN;
      return LTE_CANCEL;
    }
  mutex_enter (main_lt->lt_log_mtx);
  strses_write_out (lt->lt_log, main_lt->lt_log);
  mutex_leave (main_lt->lt_log_mtx);
  if (!in_txn)
    LEAVE_TXN;
  strses_flush (lt->lt_log);
  return LTE_OK;
}


void
log_insert (lock_trx_t * lt, row_delta_t * rd, int flag)
{
  int inx;
  dk_session_t *log;
  int op1 = -1, op2 = -1;
  lt_hi_row_change (lt, rd->rd_key->key_super_id, LOG_INSERT, NULL);
  if (enable_log_key_count)
    log_key_count (rd->rd_key->key_id);
  if (!lt || lt->lt_replicate == REPL_NO_LOG || cl_non_logged_write_mode)
    return;
  if (LOG_SYNC & flag)
    {
      log_insert_sync (lt, rd, flag & ~LOG_SYNC);
      return;
    }
  log = lt->lt_log;
  mutex_enter (lt->lt_log_mtx);
  if (flag & LOG_KEY_ONLY)
    {
      session_buffered_write_char (op1=LOG_KEY_INSERT, lt->lt_log);
      flag &= ~LOG_KEY_ONLY;
    }
  if (flag == INS_REPLACING)
    session_buffered_write_char (op2=LOG_INSERT_REPL, lt->lt_log);
  else if (flag == INS_SOFT)
    session_buffered_write_char (op2=LOG_INSERT_SOFT, lt->lt_log);
  else
    session_buffered_write_char (op2=LOG_INSERT, lt->lt_log);
  dks_array_head (lt->lt_log, 1 + rd->rd_n_values, DV_ARRAY_OF_POINTER);
  print_int (rd->rd_key->key_id, lt->lt_log);
  for (inx = 0; inx < rd->rd_n_values; inx++)
    {
      dbe_col_loc_t * cl = key_layout_nth_cl (rd->rd_key, inx);
      caddr_t val = rd->rd_values[inx];
      if ((cl->cl_sqt.sqt_col_dtp == DV_OBJECT || cl->cl_sqt.sqt_col_dtp == DV_ANY) && DV_STRINGP (val))
	print_string_as_any (val, lt->lt_log);
      else if (DV_WIDE == cl->cl_sqt.sqt_dtp && DV_STRINGP (val))
	print_string_as_wide (val, lt->lt_log);
      else
	print_object (val, lt->lt_log, NULL, NULL);
    }

  TXN_CHECK_LOG_IMAGE (lt);
  mutex_leave (lt->lt_log_mtx);
#if LOG_DEBUG_LEVEL>1
  {
  char *key_name = rd->rd_key->key_name;
  char * op_s= op1==LOG_KEY_INSERT?"LOG_KEY_INSERT":
	       op2==LOG_INSERT_REPL?"LOG_INSERT_REPL":
	       op2==LOG_INSERT_SOFT?"LOG_INSERT_SOFT":
	       "LOG_INSERT";
/*  fprintf(stderr, "log_insert %s %s\n", key_name, op_s); */
  }
#endif
}

void
log_delete (lock_trx_t * lt, row_delta_t * rd, int flags)
{
  int op;
  lt_hi_row_change (lt, rd->rd_key->key_super_id, LOG_DELETE, NULL);
  if (!lt || lt->lt_replicate == REPL_NO_LOG || cl_non_logged_write_mode)
    return;
  mutex_enter (lt->lt_log_mtx);

  if (flags & LOG_KEY_ONLY)
    session_buffered_write_char (op=LOG_KEY_DELETE, lt->lt_log);
  else
    session_buffered_write_char (op=LOG_DELETE, lt->lt_log);
  lt_log_prime_key (lt, rd, LOG_ANY_AS_STRING & flags);
  mutex_leave (lt->lt_log_mtx);
#if LOG_DEBUG_LEVEL>1
  fprintf(stderr, "log_delete %s\n", op==LOG_KEY_DELETE?"LOG_KEY_DELETE":"LOG_DELETE");
#endif
}


void
log_text (lock_trx_t * lt, char *text)
{
  caddr_t box;
  if (!lt || lt->lt_replicate == REPL_NO_LOG || cl_non_logged_write_mode)
    return;
  mutex_enter (lt->lt_log_mtx);

  session_buffered_write_char (LOG_TEXT, lt->lt_log);
  box = box_string (text);
  print_object (box, lt->lt_log, NULL, NULL);
  dk_free_box (box);
  TXN_CHECK_LOG_IMAGE (lt);
  mutex_leave (lt->lt_log_mtx);
}


void
log_text_print (lock_trx_t * lt, caddr_t box)
{
  caddr_t box2;
  if (QI_NO_SLICE == lt->lt_client->cli_slice)
    {
      print_object (box, lt->lt_log, NULL, NULL);
      return;
    }
  if (DV_STRINGP (box))
    box2 = list (3, box_num (lt->lt_client->cli_slice), lt->lt_client->cli_csl->csl_clm->clm_name, box);
  else
    {
      box2 = dk_alloc_box (box_length (box) + 2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      memcpy (box2 + 2 * sizeof (caddr_t), box, box_length (box));
      ((caddr_t*)box2)[0] = box_num (lt->lt_client->cli_slice);
      ((caddr_t*)box2)[1] = lt->lt_client->cli_csl->csl_clm->clm_name;
    }
  print_object (box2, lt->lt_log, NULL, NULL);
  dk_free_box (box2);
}


void
log_text_array (lock_trx_t * lt, caddr_t box)
{
  if (!lt || lt->lt_replicate == REPL_NO_LOG || cl_non_logged_write_mode)
    return;
  mutex_enter (lt->lt_log_mtx);
  session_buffered_write_char (LOG_TEXT, lt->lt_log);
  log_text_print (lt, box);
  TXN_CHECK_LOG_IMAGE (lt);
  mutex_leave (lt->lt_log_mtx);
}

void
log_text_array_as_user (user_t * usr, lock_trx_t * lt, caddr_t box)
{
  if (!lt || lt->lt_replicate == REPL_NO_LOG || cl_non_logged_write_mode)
    return;
  mutex_enter (lt->lt_log_mtx);
  session_buffered_write_char (LOG_USER_TEXT, lt->lt_log);
  print_long (usr->usr_id, lt->lt_log);
  log_text_print (lt, box);
  TXN_CHECK_LOG_IMAGE (lt);
  mutex_leave (lt->lt_log_mtx);
}



void
log_sequence (lock_trx_t * lt, char *text, boxint count)
{
  if (!lt || lt->lt_replicate == REPL_NO_LOG || cl_non_logged_write_mode)
    return;
  mutex_enter (lt->lt_log_mtx);
  session_buffered_write_char (LOG_SEQUENCE_64, lt->lt_log);
  print_object (text, lt->lt_log, NULL, NULL);
  print_int (count, lt->lt_log);
  TXN_CHECK_LOG_IMAGE (lt);
  mutex_leave (lt->lt_log_mtx);
}


void
log_sequence_remove (lock_trx_t * lt, char *text)
{
  log_text_array (lt, list (2,
	box_string ("sequence_remove (?)"),
	box_dv_short_string (text)));
}


void
log_update (lock_trx_t * lt, row_delta_t * rd,
    update_node_t * upd, caddr_t * qst)
{
  int inx;
  if (!lt || lt->lt_replicate == REPL_NO_LOG || cl_non_logged_write_mode)
    return;
  mutex_enter (lt->lt_log_mtx);
  session_buffered_write_char (LOG_UPDATE, lt->lt_log);
  lt_log_prime_key (lt, rd, 1);
  if (upd->upd_cols_param)
    {
      caddr_t * vals = (caddr_t*)qst_get (qst, upd->upd_values_param);
      caddr_t cols = qst_get (qst, upd->upd_cols_param);
      print_object (cols, lt->lt_log, NULL, NULL);
      session_buffered_write_char (DV_ARRAY_OF_POINTER, lt->lt_log);
      print_int (BOX_ELEMENTS (vals), lt->lt_log);
      for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (vals); inx++)
	{
	  caddr_t data = vals[inx];
	  switch (DV_TYPE_OF (data))
	    {
	    case DV_BLOB_HANDLE:
	    case DV_BLOB_WIDE_HANDLE:
	      {
		int from_c = ((blob_handle_t *) data)->bh_ask_from_client;
		((blob_handle_t *) data)->bh_ask_from_client = 1;
		print_object (data, lt->lt_log, NULL, NULL);
		((blob_handle_t *) data)->bh_ask_from_client = from_c;
		break;
	      }
/* IvAn/XperUpdate/000904 Xper support added.
   For trees, log update uses plain serialization xte_serialize(), file xmltree.c.
   For Xper, special handler (xp_log_update(), file bif_xper) needed, because
   it's necessary to record only the blob itself.
   */
            case DV_XML_ENTITY:
              {
                ((xml_entity_t *)data)->_->xe_log_update(((xml_entity_t *)data),lt->lt_log);
                break;
              }
	    default:
	      if (IS_BOX_POINTER (data))
		print_object (data, lt->lt_log, NULL, NULL);
	      else
		print_int ((long) (ptrlong) data, lt->lt_log);
	    }
	}

    }
  else
    {
      state_slot_t **vals = upd->upd_values;
      print_object ((caddr_t) upd->upd_col_ids, lt->lt_log, NULL, NULL);

      session_buffered_write_char (DV_ARRAY_OF_POINTER, lt->lt_log);
      print_int (BOX_ELEMENTS (upd->upd_col_ids), lt->lt_log);

      for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (upd->upd_col_ids); inx++)
	{
	  caddr_t data = qst_get (qst, vals[inx]);
	  switch (DV_TYPE_OF (data))
	    {
	    case DV_BLOB_HANDLE:
	    case DV_BLOB_WIDE_HANDLE:
	      {
		int from_c = ((blob_handle_t *) data)->bh_ask_from_client;
		((blob_handle_t *) data)->bh_ask_from_client = 1;
		print_object (data, lt->lt_log, NULL, NULL);
		((blob_handle_t *) data)->bh_ask_from_client = from_c;
		break;
	      }
/* IvAn/XperUpdate/000904 Xper support added.
   For trees, log update uses plain serialization xte_serialize(), file xmltree.c.
   For Xper, special handler (xp_log_update(), file bif_xper) needed, because
   it's necessary to record only the blob itself.
   */
            case DV_XML_ENTITY:
              {
                ((xml_entity_t *)data)->_->xe_log_update(((xml_entity_t *)data),lt->lt_log);
                break;
              }
	    default:
	      if (IS_BOX_POINTER (data))
		{
		  dbe_column_t * col = sch_id_to_column (wi_inst.wi_schema, upd->upd_col_ids[inx]);
		  if (col && DV_WIDE == col->col_sqt.sqt_col_dtp && DV_STRINGP (data))
		    print_string_as_wide (data,  lt->lt_log);
		  else
		print_object (data, lt->lt_log, NULL, NULL);
		}
	      else
		print_int ((long) (ptrlong) data, lt->lt_log);
	    }
	}
    }
  TXN_CHECK_LOG_IMAGE (lt);
  mutex_leave (lt->lt_log_mtx);
}


void
log_sc_change_1 (lock_trx_t * lt)
{
  session_buffered_write_char (LOG_SC_CHANGE_1, lt->lt_log);
}
void
log_sc_change_2 (lock_trx_t * lt)
{
  session_buffered_write_char (LOG_SC_CHANGE_2, lt->lt_log);
}

void
log_dd_change (lock_trx_t * lt, char * tb)
{
  if (!lt || lt->lt_replicate == REPL_NO_LOG || cl_non_logged_write_mode)
    return;

  if (tb)
    {
      caddr_t tmp = box_string (tb);
      caddr_t tree = list (2, box_string ("__ddl_changed (?)"), tmp);
      box_tag_modify (tree, DV_ARRAY_OF_POINTER);
      log_text_array (lt, tree);
      dk_free_tree (tree);
    }
  else
    session_buffered_write_char (LOG_DD_CHANGE, lt->lt_log);
}


void
log_dd_type_change (lock_trx_t * lt, char * udt_name, caddr_t tree)
{
  if (!lt || lt->lt_replicate == REPL_NO_LOG || cl_non_logged_write_mode)
    return;

  if (tree)
    {
      caddr_t tmp = box_string (udt_name);
      caddr_t tmp2 = box_copy_tree (tree);
      caddr_t tree = list (3, box_string ("__ddl_type_changed (?, ?)"), tmp, tmp2);
      box_tag_modify (tree, DV_ARRAY_OF_POINTER);
      log_text_array (lt, tree);
      dk_free_tree (tree);
    }
  else if (udt_name)
    {
      caddr_t tmp = box_string (udt_name);
      caddr_t tree = list (2, box_string ("__ddl_type_changed (?)"), tmp);
      box_tag_modify (tree, DV_ARRAY_OF_POINTER);
      log_text_array (lt, tree);
      dk_free_tree (tree);
    }
  else
    GPF_T;
}


/*
 */

#define MAX_BATCH_COUNT dc_batch_sz

long rfwd_ctr = 0;
static long op_ctr = 0;

key_id_t row_key_id(caddr_t * row) {
    return unbox (row[0]);
}

query_t *ins_replay;
query_t *s_ins_replay;
query_t *r_ins_replay;


char *ins_replay_text = "(seq (row_insert :PL replacing) (end))";
char *s_ins_replay_text = "(seq (row_insert :PL soft) (end))";
char *r_ins_replay_text = "(seq (row_insert :PL replacing) (end))";

caddr_t
log_replay_insert_row (client_connection_t * cli, int flag,  caddr_t * row)
{
  query_t *st;
  caddr_t err;

/*  log_info ("t%d:n%d sync op %d key_id=%d", rfwd_ctr, op_ctr, flag, row_key_id((caddr_t*)row));  */

  if (!ins_replay)
    {
      ins_replay = eql_compile (ins_replay_text, bootstrap_cli);
      s_ins_replay = eql_compile (s_ins_replay_text, bootstrap_cli);
      r_ins_replay = eql_compile (r_ins_replay_text, bootstrap_cli);
    }
  if (flag == LOG_INSERT_SOFT)
    st = s_ins_replay;
  else if (flag == LOG_INSERT_REPL)
    st = r_ins_replay;
  else
    st = ins_replay;
  err = qr_quick_exec (st, cli, "x", NULL, 1,
		       ":PL", row, QRP_RAW);
  return err;
}


caddr_t
log_replay_key_insert (lock_trx_t * lt, dk_session_t * in, int flag1)
{
  static query_t * ins_key_replay = NULL;
  char flag = session_buffered_read_char (in);
  caddr_t err;
  db_buf_t row = (db_buf_t) scan_session (in);

  if (!ins_key_replay)
    {
      ins_key_replay = sql_compile ("key_replay_insert (?, ?)", bootstrap_cli, &err, SQLC_DEFAULT);
    }
  if (flag == LOG_INSERT_SOFT)
    flag = INS_SOFT;
  else if (flag == LOG_INSERT_REPL)
    flag = INS_REPLACING;
  else
    flag = INS_NORMAL;
  err = qr_quick_exec (ins_key_replay, lt->lt_client, "x", NULL, 2,
		       ":0", row, QRP_RAW,
		       ":1", (caddr_t)(ptrlong)flag, QRP_INT);
  return err;
}

caddr_t
log_replay_key_insert_row (client_connection_t * cli, caddr_t * row, int flag)
{
  static query_t * ins_key_replay = NULL;
  caddr_t err;

  if (!ins_key_replay)
    {
      ins_key_replay = sql_compile ("key_replay_insert (?, ?)", bootstrap_cli, &err, SQLC_DEFAULT);
    }
  if (flag == LOG_INSERT_SOFT)
    flag = INS_SOFT;
  else if (flag == LOG_INSERT_REPL)
    flag = INS_REPLACING;
  else
    flag = INS_NORMAL;
  err = qr_quick_exec (ins_key_replay, cli, "x", NULL, 2,
		       ":0", row, QRP_RAW,
		       ":1", (caddr_t)(ptrlong)flag, QRP_INT);
  return err;
}

resource_t *del_rc;
char *del_replay_text = "(seq (row_deref :PL place P)(delete P) (end))";

resource_t *upd_rc;
char *upd_replay_text = "(seq (row_deref :PL place P)(update_ind P :COLS :VALS) (end))";


#define LOG_REPL_OPTIONS(opts) \
  char opts##_buf[sizeof(stmt_options_t) + 8]; \
  caddr_t opts_ptr; \
  stmt_options_t *opts; \
  BOX_AUTO(opts_ptr, opts##_buf, sizeof(stmt_options_t), DV_ARRAY_OF_LONG); \
  opts = (stmt_options_t *)opts_ptr; \
  memset (opts, 0, sizeof (stmt_options_t)); \
  opts->so_concurrency = SQL_CONCUR_LOCK; \
  opts->so_isolation = ISO_REPEATABLE;

caddr_t
log_replay_delete (lock_trx_t * lt, dk_session_t * in)
{
  db_buf_t row = (db_buf_t) scan_session (in);

  query_t *qr = (query_t *) resource_get (del_rc);
  caddr_t err;
  LOG_REPL_OPTIONS (opts);

  if (!qr)
    qr = eql_compile (del_replay_text, lt->lt_client);
  err = qr_rec_exec (qr, lt->lt_client, NULL, CALLER_LOCAL, opts, 1,
		     ":PL", row, QRP_RAW);
  resource_store (del_rc, (void *) qr);

  if (err != SQL_SUCCESS)
    {
      err_log_error (err);
    }
  return err;
}


char * key_del_replay_text = "key_delete_replay (?)";
caddr_t
log_replay_key_delete (lock_trx_t * lt, dk_session_t * in)
{
  db_buf_t row = (db_buf_t) scan_session (in);
  static query_t *qr = NULL;
  caddr_t err;
  LOG_REPL_OPTIONS (opts);

  if (!qr)
    qr = eql_compile (key_del_replay_text, lt->lt_client);
  err = qr_rec_exec (qr, lt->lt_client, NULL, CALLER_LOCAL, opts, 1,
		     ":0", row, QRP_RAW);

  if (err != SQL_SUCCESS)
    {
      err_log_error (err);
    }
  return err;
}


query_t * log_key_upd_qr (dbe_key_t * key, oid_t * col_ids, caddr_t * err_ret);
extern int dbf_rq_key;


caddr_t
log_replay_update (lock_trx_t * lt, dk_session_t * in)
{
  caddr_t * row = (caddr_t*) scan_session (in);
  key_id_t key_id = unbox (row[0]);
  dbe_key_t * key = sch_id_to_key (wi_inst.wi_schema, key_id);
  caddr_t * cols;
  int n_vals, n_keys;
  caddr_t * vals;
  query_t *qr;
  caddr_t err = NULL;
  caddr_t * params;
  LOG_REPL_OPTIONS (opts);
  if (dbf_rq_key > 1 && key_id != dbf_rq_key)
    return NULL;
  cols = (caddr_t*) scan_session (in);
  vals = (caddr_t*) scan_session (in);
  n_keys = BOX_ELEMENTS (row) - 1;
  n_vals = BOX_ELEMENTS (vals);
  if (!key)
    {
      log_error ("Replay update of key %d which does not exist", key_id);
      return NULL;
    }
  qr = log_key_upd_qr (key, (oid_t *)cols, &err);
  if (err)
    {
      log_error ("Erro in getting update replay query for %s", key->key_name);
      return err;
    }

  params = (caddr_t*)dk_alloc_box (sizeof (caddr_t) * (n_keys + n_vals), DV_ARRAY_OF_POINTER);
  memcpy (params, vals, sizeof (caddr_t) * n_vals);
  memcpy (&params[n_vals], &row[1], sizeof (caddr_t) * n_keys);
  err = qr_exec (lt->lt_client, qr, CALLER_LOCAL, "", NULL, NULL, params, opts, 0);
  dk_free_tree (cols);
  dk_free_box ((caddr_t)params);
  dk_free_box (row);
  dk_free_box (vals);
  cli_free_dae (lt->lt_client);
  if (err != SQL_SUCCESS)
    {
      err_log_error (err);
    }
  return err;
}

caddr_t
log_replay_text_1 (lock_trx_t * lt, caddr_t * entry, int is_pushback, int use_stmt_cache)
{
  int n_args = 0;
  dtp_t dtp = DV_TYPE_OF (entry);
  caddr_t text = DV_ARRAY_OF_POINTER == dtp && BOX_ELEMENTS (entry) > 0 ? entry[0] : (caddr_t) entry;
  caddr_t err = NULL;
  caddr_t text2;
  caddr_t stmt_id = box_dv_short_string ("repl_stmt");
  query_t *qr;
  int qr_is_allocated = 0;
  srv_stmt_t * sst;
  int inx;
  caddr_t *arr = NULL;
  LOG_REPL_OPTIONS (opts);

  if (!DV_STRINGP (text))
    {
      dk_free_box ((box_t) entry);
      return srv_make_new_error ("42000", "TR100", "log_replay_text: invalid query text dtp=%d", DV_TYPE_OF (entry));
    }

  if (!is_pushback)
    {
      if (dtp == DV_ARRAY_OF_POINTER)
        n_args = BOX_ELEMENTS (entry) - 1;
    }
  else
    {
      /*
       * do conflict resolution
       */
      int n_cols;     /* number of additional params in log record */
      int n_cr_args;  /* number of cr args */
      int i;

      char *p, *q, *table_name;
      static char cr_prefix[] = "\"replcr_";
      static char insert_stmt[] = "insert replacing ";
      static char update_stmt[] = "update ";
      static char delete_stmt[] = "delete from ";
      int cr_type;
      int dot;
      int in_quot;

      caddr_t stmt;
      local_cursor_t * lc = NULL;
      caddr_t *proc_ret;
      int retc = 0;
      LOG_REPL_OPTIONS (cr_opts);

      if (!strncmp (text, insert_stmt, sizeof(insert_stmt) - 1))
        {
          cr_type = 'I';
          table_name = text + sizeof (insert_stmt) - 1;
        }
      else if (!strncmp (text, update_stmt, sizeof(update_stmt) - 1))
        {
          cr_type = 'U';
          table_name = text + sizeof (update_stmt) - 1;
        }
      else if (!strncmp (text, delete_stmt, sizeof(delete_stmt) - 1))
        {
          cr_type = 'D';
          table_name = text + sizeof (delete_stmt) - 1;
        }
      else
        {
          dbg_printf_1 (("log_replay_text: '%s': unknown statement type, skipping conflict resolution",
              text));
          goto cr_done;
        }

      if (dtp != DV_ARRAY_OF_POINTER)
        {
          dk_free_box ((box_t) entry);
          return srv_make_new_error ("42000", "TR083",
              "log_replay_text: dtp is not DV_ARRAY_OF_POINTER (%d)", dtp);
        }
      n_args = BOX_ELEMENTS(entry) - 1;
      n_cols = 0;

      /*
       * 'I': stmt, all new cols
       * 'U': stmt, all new cols, old pk, all old cols, num
       * 'D': stmt, old pk, all old cols, num
       */
      if (cr_type == 'I')
        n_cols = n_args;
      else
        {
          /*
           * get n_cols
           */
          if ((dtp = DV_TYPE_OF(entry [n_args])) != DV_LONG_INT)
            {
              dk_free_tree ((box_t) entry);
              return srv_make_new_error ("42000", "TR084",
                 "log_replay_text: n_cols is not DV_LONG_INT (%d)", dtp);
            }
          n_cols = (int) unbox (entry [n_args]);
          if (n_cols <= 0)
            {
              dk_free_tree ((box_t) entry);
              return srv_make_new_error ("42000", "TR085",
                  "log_replay_text: invalid n_cols (%d)", n_cols);
            }
          n_args -= n_cols + 1;
          if (n_args < 0)
            {
              dk_free_tree ((box_t) entry);
              return srv_make_new_error ("42000", "TR086",
                  "log_replay_text: n_cols (%d) + 1 > n_args (%d)",
                  n_cols, n_args);
            }
        }
      if (cr_type == 'U')
        n_cr_args = n_cols + n_cols + 1;
      else
        n_cr_args = n_cols + 1;
#if 0
      dbg_printf_1 (("cr_type: '%c', n_cols: %d, n_args: %d, n_cr_args: %d",
          cr_type, n_cols, n_args, n_cr_args));
#endif

      /*
       * 3                   -- for '_X"'
       * 1                   -- for opening brace '('
       * (3 * n_cr_args - 2) -- for '?, ' (last arg does not have ', ')
       * 1                   -- for closing brace ')'
       * trailing NUL is counted in sizeof(cr_prefix);
       */
      if ((q = strchr (table_name, ' ')) == NULL)
        q = strchr (table_name, '\0');
      stmt = dk_alloc_box (
          sizeof(cr_prefix) + (q - table_name) * 2 +
          3 + 1 + (3 * n_cr_args - 2) + 1, DV_LONG_STRING);
      /* first two name parts */
      q = stmt;
      dot = 0;
      for (p = table_name; *p != ' ' && *p != '\0'; p++)
        {
          *q++ = *p;
          if (*p == '.' && ++dot == 2)
            break;
        }
      /* cr_prefix */
      strcpy_size_ck (q, cr_prefix, box_length (stmt) - (q - stmt));
      q += sizeof (cr_prefix) - 1;
      /* table name */
      in_quot = 0;
      for (p = table_name; *p != '\0'; p++)
        {
          if (*p == '"')
            {
              if (!in_quot)
                {
                  in_quot = 1;
                  continue;
                }

              if (*(p + 1) != '"')
                {
                  in_quot = 0;
                  continue;
                }

              *q++ = *p++;
              *q++ = *p;
              continue;
            }

          if (*p == ' ' && !in_quot)
            break;
          if (*p == '.')
            {
              *q++ = '_';
              continue;
            }
          *q++ = *p;
        }
      *q++ = '_';
      *q++ = cr_type;
      *q++ = '"';
      *q++ = '(';
      *q++ = '\0';
      for (inx = 0; inx < n_cr_args; inx++)
        {
          if (inx)
            strcat_box_ck (stmt, ", ");
          strcat_box_ck (stmt, "?");
        }
      strcat_box_ck (stmt, ")");
#if 0
      log_debug ("stmt: '%s'", stmt);
#endif

      /*
       * execute conflict resolving procedure
       */
      qr = sql_compile (stmt, lt->lt_client, &err, SQLC_DEFAULT);
      if (!qr)
        {
          dk_free_box (stmt);
          dk_free_tree ((box_t) entry);
          return err;
        }
      arr = (caddr_t *) dk_alloc_box (
          n_cr_args * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      inx = 0;
      if (cr_type == 'I' || cr_type == 'U')
        {
          /* copy all new cols */
          for (i = 0; i < n_cols; i++, inx++)
	    arr [inx] = box_copy (entry [1 + i]);
        }
      if (cr_type == 'D' || cr_type == 'U')
        {
          /* copy all old cols */
          for (i = 0; i < n_cols; i++, inx++)
            arr[inx] = box_copy (entry [1 + n_args + i]);
        }
      arr [inx++] = box_copy (lt->lt_replica_of);
      err = qr_exec (
          lt->lt_client, qr, CALLER_LOCAL, NULL, NULL, &lc,
          arr, cr_opts, 0);
      dk_free_box ((box_t) arr);
      qr_free (qr);
      dk_free_box (stmt);

      if (err != NULL)
        {
          dk_free_tree ((box_t) entry);
          return err;
        }
      if (!lc)
        {
          dk_free_tree ((box_t) entry);
          return srv_make_new_error ("42000", "TR087",
              "log_replay_text: NULL lc");
        }
      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (lc->lc_proc_ret))
        {
          dk_free_tree ((box_t) entry);
          lc_free (lc);
          return srv_make_new_error ("42000", "TR088",
              "log_replay_text: invalid lc type");
        }
      proc_ret = (caddr_t *) lc->lc_proc_ret;
      if (BOX_ELEMENTS(proc_ret) < 2)
        {
          dk_free_tree ((box_t) entry);
          lc_free (lc);
          return srv_make_new_error ("42000", "TR089",
              "log_replay_text: lc too short (want %d, have %ld)",
              2, (long)(BOX_ELEMENTS(proc_ret)));
        }
      retc = (int) unbox (proc_ret[1]);
#if 0
      log_debug ("server %s: Conflict resolver returned %d", db_name, retc);
#endif

      switch (retc)
        {
          case 2: /* copy out, apply, change origin */
            dk_free_tree (lt->lt_replica_of);
            lt->lt_replica_of = box_copy_tree (db_name);
            /* FALLTHROUGH */

          case 1: /* copy out, apply */
            if (cr_type == 'I' || cr_type == 'U')
              {
                /*
                 * copy out parameters
                 */
                if (BOX_ELEMENTS_INT(proc_ret) < 2 + n_cols)
                  {
                    dk_free_tree ((box_t) entry);
                    lc_free (lc);
                    return srv_make_new_error ("42000", "TR090",
                        "log_replay_text: lc too short (want %d, have %ld)",
                        2 + n_cols, (long)(BOX_ELEMENTS(proc_ret)));
                  }

                for (inx = 0; inx < n_cols; inx++)
                  {
                    dk_free_box (entry [1 + inx]);
                    entry [1 + inx] = proc_ret[2 + inx];
                    proc_ret[2 + inx] = NULL;
                  }
              }

            lc_free(lc);
            break;

          case 4: /* reject */
            lc_free(lc);
            dk_free_tree ((box_t) entry);
            return srv_make_new_error ("42000", "TR091",
                "log_replay_text: conflict resolver returned %d (reject)",

                retc);
	    break;

          case 5: /* ignore */
            lc_free(lc);
            dk_free_tree ((box_t) entry);
            return SQL_SUCCESS;
	    break;

          default:
            lc_free(lc);
            dk_free_tree ((box_t) entry);
            return srv_make_new_error ("42000", "TR092",
                "log_replay_text: conflict resolver returned %d (unknown)",
                retc);
	    break;
        }
    }

cr_done:
  if (use_stmt_cache)
    {
      sst = cli_get_stmt_access (lt->lt_client, stmt_id, GET_EXCLUSIVE, NULL);
      text2 = box_copy (text);
      err = stmt_set_query (sst, lt->lt_client, text, opts);
      LEAVE_CLIENT (lt->lt_client);
      if (err != NULL)
	{
	  if ((caddr_t)-1 == err)
	    err = srv_make_new_error ("37000",  "SNRFD", "error compiling %s in roll forward", text2);
	  if (DV_ARRAY_OF_POINTER == dtp)
	    entry[0] = NULL;
	  dk_free_tree ((box_t) entry);
	  dk_free_box (text2);
	  if (is_pushback)
	    return err;
	  err_log_error (err);
	  return ((caddr_t) SQL_SUCCESS);
	}
      dk_free_box (text2);
      qr = sst->sst_query;
      qr_is_allocated = 0;
    }
  else
    {
      int cr_type = (int) SO_CURSOR_TYPE (opts);
      qr = eql_compile_2 (text, lt->lt_client, &err, cr_type);
      if (!qr)
	{
	  dk_free_tree ((box_t) entry);
	  if (is_pushback)
	    return err;
	  err_log_error (err);
	  dk_free_tree (err);
	  return ((caddr_t) SQL_SUCCESS);
	}
      qr_is_allocated = 1;
    }
  if (n_args > 0)
    {
      arr = (caddr_t *) dk_alloc_box (n_args * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      for (inx = 0; inx < n_args; inx ++)
	arr [inx] = entry [inx + 1];
    }
  err = qr_exec (lt->lt_client, qr, CALLER_LOCAL, NULL, NULL, NULL, arr, opts, 0);
  if (arr != NULL)
    dk_free_box ((box_t) arr);

  if (dtp == DV_ARRAY_OF_POINTER)
    dk_free_box ((box_t) entry);  /* free top, params freed by exec, text kept in client stmt cache */
  if (IS_BOX_POINTER (err)) /* err != SQL_SUCCESS */
    {
      if (is_pushback)
	{
	  if (qr_is_allocated)
	    qr_free (qr);
          return err;
	}
      err_log_error (err);
    }
  if (qr_is_allocated)
    qr_free (qr);
  return ((caddr_t) SQL_SUCCESS);
}


caddr_t
log_replay_text (lock_trx_t * lt, dk_session_t * in, int is_pushback, int use_stmt_cache)
{
  caddr_t *entry = (caddr_t *) scan_session (in);
  return log_replay_text_1 (lt, entry, is_pushback, use_stmt_cache);
}


caddr_t
log_replay_text_as_user (lock_trx_t * lt, dk_session_t * in, int is_pushback)
{
  client_connection_t * cli = lt->lt_client;
  oid_t usr_id = (oid_t) read_long (in);
  user_t * save = cli->cli_user;
  caddr_t saved_qual = box_string (cli->cli_qualifier);
  user_t * usr = sec_id_to_user (usr_id);
  caddr_t ret = NULL;

  set_user_id (cli, usr->usr_name, NULL);
  ret = log_replay_text (lt, in, is_pushback, 0);
  cli->cli_user = save;
  dk_free_tree (cli->cli_qualifier);
  cli->cli_qualifier = saved_qual;
  return ret;
}


caddr_t
log_replay_sequence (lock_trx_t * lt, dk_session_t * in)
{
  caddr_t text = (caddr_t) scan_session (in);
  long count = read_long (in);
  sequence_set (text, count, SET_IF_GREATER, OUTSIDE_MAP);
  log_sequence (lt, text, count);
  dk_free_box (text);
  return ((caddr_t) SQL_SUCCESS);
}


caddr_t
log_replay_sequence_64 (lock_trx_t * lt, dk_session_t * in)
{
  caddr_t text = (caddr_t) scan_session (in);
  caddr_t count =  (caddr_t) scan_session_boxing (in);
  sequence_set (text, unbox (count), SET_IF_GREATER, OUTSIDE_MAP);
  dk_free_box (text);
  dk_free_box (count);
  return ((caddr_t) SQL_SUCCESS);
}


caddr_t
log_replay_entry (lock_trx_t * lt, dtp_t op, dk_session_t * in, int is_pushback)
{
  switch (op)
    {
    case LOG_INSERT:
    case LOG_INSERT_SOFT:
    case LOG_INSERT_REPL:
      return log_replay_insert_row (lt->lt_client, op, (caddr_t *) scan_session (in));
    case LOG_KEY_INSERT:
      return (log_replay_key_insert (lt, in, op));
    case LOG_DELETE:
      return (log_replay_delete (lt, in));
    case LOG_KEY_DELETE:
      return (log_replay_key_delete (lt, in));
    case LOG_UPDATE:
      return (log_replay_update (lt, in));
    case LOG_DD_CHANGE:
      if (!f_read_from_rebuilt_database)
	{
	  log_error ("Database must be started with -R to load a crashdump log");
	  exit (-1);
	}
      isp_read_schema (lt);
      break;
    case LOG_SC_CHANGE_1:
      if (!f_read_from_rebuilt_database)
	{
	  log_error ("Database must be started with -R to load a crashdump/backup log."
	     " Remove the (empty) database file and try replaying.");
	  exit (-1);
	}
      break;
    case LOG_SC_CHANGE_2:
      isp_read_schema (lt);
      break;
    case LOG_TEXT:
      return (log_replay_text (lt, in, is_pushback, 1));
    case LOG_USER_TEXT:
      return (log_replay_text_as_user (lt, in, is_pushback));
    case LOG_SEQUENCE:
      return (log_replay_sequence (lt, in));
    case LOG_SEQUENCE_64:
      return (log_replay_sequence_64 (lt, in));
    }
  return SQL_SUCCESS;
}

/* TODO move string_buffer to an utility file
 */
typedef struct {
  int sb_len;
  char *sb_buf;
  int sb_pos;
} string_buffer;

void
sb_init(string_buffer* sb) {
  sb->sb_len=120;
  sb->sb_buf=malloc(sb->sb_len);
  sb->sb_pos=0;
}

void
sb_free_buf(string_buffer* sb) {
  free(sb->sb_buf);
  sb->sb_len=0;
  sb->sb_buf=NULL;
  sb->sb_pos=0;
}

/** after pasprintf.c
 *  http://perfec.to/vsnprintf/
 */
int
sb_printf(string_buffer* sb, const char *fmt, ...) {
  int outsize;
  for (;;) {
    va_list args;
    char *newbuf;
    size_t nextsize;
    size_t bufsize=sb->sb_len - sb->sb_pos;
    va_start(args, fmt);
    outsize = vsnprintf(sb->sb_buf + sb->sb_pos, bufsize, fmt, args);
    va_end(args);
    if ((outsize != -1) && (outsize < bufsize - 1)) {/* Output was not truncated */
      break;
    }
    nextsize = sb->sb_len * 2;
    if ((newbuf = (char *)realloc(sb->sb_buf, nextsize)) != NULL) {
      sb->sb_buf = newbuf;
      sb->sb_len = nextsize;
    } else {
      /* free(buf); */
      GPF_T1 ("sb_printf(): could not realloc");
    }
  }
  sb->sb_pos+=outsize;
  return outsize;
}

typedef struct {
  key_id_t lr_key_id;
  async_queue_t* lrq_aq;
  dk_hash_t *	lrq_qrs; /** operation =>query_t* */
  struct lre_request_s* lrq_request; /** the batch being prepared */
  int		lrq_running_op;
} lre_queue_t;

typedef struct lre_request_s {
  lr_executor_t* lr_lre;
  lre_queue_t *lr_lrq;
  int lr_op;
  data_col_t **lr_params_vec;
  mem_pool_t* lr_pool;
  query_t* lr_qr;
  int lr_mb_blobs;
} lre_request_t;

long
lre_request_count (lre_request_t *request)
    {
  if (!request || !request->lr_params_vec || !request->lr_params_vec[0])
    return 0;
  return request->lr_params_vec[0]->dc_n_values;
    }


lr_executor_t*
lre_alloc ()
{
  lr_executor_t* executor=(lr_executor_t*)dk_alloc(sizeof(lr_executor_t));
  LOG_REPL_OPTIONS (opts);
  memzero (executor, sizeof (lr_executor_t));
  executor->lre_mtx = mutex_allocate();
  executor->lre_opts=opts;
  executor->lre_aqr_count=0;
  executor->lre_err=SQL_SUCCESS;
  executor->lre_stopped=0;
  executor->lre_aqs = hash_table_allocate(11);
  return executor;
}

void
lrq_free (lre_queue_t* lrq)
{
  if (lrq == NULL) return;
  dk_free_box (lrq->lrq_aq);
  DO_HT (ptrlong, op, query_t *, qr, lrq->lrq_qrs)
    {
      qr_free (qr);
    }
  END_DO_HT;
  hash_table_free (lrq->lrq_qrs);
  dk_free(lrq, sizeof(lre_queue_t));
}

/**
 * remember to call lre_wait_all(executor) first!
 */
void
lre_free(lr_executor_t* executor)
{
    if (executor==NULL) return;
    mutex_free(executor->lre_mtx);
    DO_HT (ptrlong, key_id, lre_queue_t *, lrq, executor->lre_aqs)
      {
	lrq_free (lrq);
      }
    END_DO_HT;
    hash_table_free (executor->lre_aqs);
    dk_free(executor, sizeof(lr_executor_t));
}

lre_queue_t *
lrq_alloc (lr_executor_t* executor, key_id_t key_id, lock_trx_t * lt)
    {
  lre_queue_t * lrq = gethash ((void*)(ptrlong)key_id, executor->lre_aqs);
  if (lrq)
    return lrq;
  lrq = (lre_queue_t*)dk_alloc(sizeof(lre_queue_t));
  memset (lrq, 0, sizeof(lre_queue_t));
  lrq->lr_key_id = key_id;
  lrq->lrq_aq = aq_allocate (lt->lt_client, 1);
  lrq->lrq_aq->aq_need_own_thread = 2;
  lrq->lrq_qrs = hash_table_allocate(11);
  sethash ((void*)(ptrlong)key_id, executor->lre_aqs, lrq);
  return lrq;
}

void
get_col_names (caddr_t ** names_res, int *n_cols_res, dbe_key_t * key)
	{
  caddr_t *names;
  int n_cols = 0;
  dk_set_t set = NULL;

  DO_CL (cl, key->key_key_fixed)
	    {
      dbe_column_t * col =  sch_id_to_column (wi_inst.wi_schema, cl->cl_col_id);
      dk_set_push (&set, col->col_name);
      n_cols++;
	    }
  END_DO_CL;
  DO_CL (cl, key->key_key_var)
	    {
      dbe_column_t * col =  sch_id_to_column (wi_inst.wi_schema, cl->cl_col_id);
      dk_set_push (&set, col->col_name);
      n_cols++;
	}
  END_DO_CL;
  DO_CL (cl, key->key_row_fixed)
	{
      dbe_column_t * col =  sch_id_to_column (wi_inst.wi_schema, cl->cl_col_id);
      dk_set_push (&set, col->col_name);
      n_cols++;
    }
  END_DO_CL;
  DO_CL (cl, key->key_row_var)
    {
      dbe_column_t * col =  sch_id_to_column (wi_inst.wi_schema, cl->cl_col_id);
      int pos = dk_set_position (key->key_parts, col);
      if (pos < key->key_n_significant)
	continue; /* col-wise key has key parts once again in row var for the ref to the cols */
      dk_set_push (&set, col->col_name);
      n_cols++;
    }
  END_DO_CL;
  names = (caddr_t *) list_to_array (dk_set_nreverse (set));
  *names_res = names;
  *n_cols_res = n_cols;
}

void
get_key_col_names_part(dbe_col_loc_t *key_set, dbe_key_t *key, char **names, int *inx)
	{
  int n_cols=key->key_n_significant;
  DO_CL (cl, key_set)
	    {
      oid_t oid=cl->cl_col_id;
      int position=0;
      DO_SET (dbe_column_t *, part, &key->key_parts)
                {
	  if (position++ == n_cols) break;
	  if (part->col_id == oid)
                    {
	      names[(*inx)++]=part->col_name;
		      break;
                    }
                    }
      END_DO_SET();
    }
  END_DO_CL;
                }

void
get_key_col_names(char ***names_res, int *n_cols_res, dbe_key_t * key)
{
  char **names;
  int inx=0;
  int n_cols=key->key_n_significant;
  names= (char **) dk_alloc (n_cols*sizeof(char*));
  memset (names, 0, sizeof(n_cols*sizeof(char*)));
  *names_res=names;
  *n_cols_res=n_cols;

  get_key_col_names_part(key->key_key_fixed, key, names, &inx);
  get_key_col_names_part(key->key_key_var, key, names, &inx);
  for (inx=0; inx<n_cols; inx++) {
    if (names[inx]==NULL)
      GPF_T1 ("get_key_col_names: not all names found");
  }
}

char *
log_qname_escape (char * name, char * buf, size_t max)
{
  int i, fill = 0, len = strlen (name);
  for (i = 0; i < len; i ++)
    {
      buf[fill++] = name[i];
      if (name[i] == '"')
        buf[fill++] = name[i];
      if (fill >= max)
	break;
    }
  buf[fill] = '\0';
  return buf;
}

#define ESC(x,n) log_qname_escape (x, &temp##n[0], sizeof (temp##n))

query_t *
log_key_ins_del_qr (dbe_key_t * key, caddr_t * err_ret, int op, int ins_mode, int is_rfwd)
{
  /* if is_rfwd this is roll forward and no cluster is not specified since the host may have multiple partitions (except for replicated tables)  if elastic cluster */
  query_t * res;
  dbe_table_t * key_table = key->key_table;
  string_buffer sb;
  caddr_t err;
  char temp1[MAX_NAME_LEN], temp2[MAX_NAME_LEN], temp3[MAX_NAME_LEN];
  key_id_t old_key = key->key_migrate_to;
  if (key->key_partition && clm_replicated == key->key_partition->kpd_map)
    is_rfwd = 0;
  while (key->key_migrate_to)
    key = sch_id_to_key (wi_inst.wi_schema, key->key_migrate_to);
  sb_init (&sb);
  switch (op)
    {
      case LOG_INSERT:
      case LOG_INSERT_SOFT:
      case LOG_INSERT_REPL:
      case LOG_KEY_INSERT:
	    {
	      int n_cols, k, need_comma = 0;
	      caddr_t * names;
	      sb_printf(&sb, "INSERT %s \"%s\".\"%s\".\"%s\"", ((LOG_INSERT_SOFT == op || INS_SOFT == ins_mode || -1 == ins_mode) ? "SOFT" : ((op == LOG_INSERT_REPL || ins_mode == LOG_INSERT_REPL) ? "REPLACING" : "INTO")),
		 ESC(key_table->tb_qualifier, 1), ESC(key_table->tb_owner, 2), ESC(key_table->tb_name_only,3));
	      if (op == LOG_KEY_INSERT && !old_key)
		{
		  sb_printf(&sb, " INDEX \"%s\"", key->key_name); /* FIXME */
		}
	      sb_printf(&sb, " OPTION (VECTORED, no identity %s) (", is_rfwd ? "" : ", no cluster");
	      get_col_names (&names, &n_cols, key);
	      for (k = 0; k < n_cols; k++)
		{
		  if (need_comma)
		    sb_printf(&sb, ", ");
		  else
		    need_comma = 1;
	          sb_printf(&sb, "\"%s\"", ESC(names[k],1));
		}

	      sb_printf(&sb, " ) VALUES (");
	      need_comma = 0;
	      for (k = 0; k < n_cols; k++)
		{
		  if (need_comma)
		    sb_printf (&sb, ", ");
		  else
		    need_comma = 1;
		  sb_printf (&sb, "?");
		}
	      sb_printf (&sb, ")");
	      dk_free_box (names);
	      break;
	    }
      case LOG_DELETE:
      case LOG_KEY_DELETE:
	    {
	      int n_cols, k, need_comma = 0;
	      char **names;
	      sb_printf (&sb, "DELETE FROM \"%s\".\"%s\".\"%s\"", ESC(key_table->tb_qualifier,1), ESC(key_table->tb_owner,2), ESC(key_table->tb_name_only,3));
	      if (op == LOG_KEY_DELETE)
		{
	    sb_printf(&sb, " table option (%s INDEX \"%s\") ", is_rfwd ? "": "no cluster, ", key->key_name);
		}
	      sb_printf(&sb, " WHERE (");
	      get_key_col_names(&names, &n_cols, key);
	      for (k=0; k<n_cols; k++)
		{
		  if (need_comma)
		    sb_printf (&sb, " AND ");
		  else
		    need_comma = 1;
	          sb_printf(&sb, "\"%s\"=?", ESC(names[k],1));
		}
	if (LOG_KEY_DELETE == op)
	  sb_printf(&sb, ") OPTION (%s index \"%s\", VECTORED) ", is_rfwd ? "" :  "no cluster, ", key->key_name);
	else
	  sb_printf(&sb, ") OPTION (no cluster, VECTORED) ");
	      dk_free (names, n_cols * sizeof(char*));
	      break;
	    }
      default:
      GPF_T1 ("log_key_ins_del_qr: invalid operation");
    }
  res = sql_compile (sb.sb_buf, bootstrap_cli, &err, SQLC_DEFAULT);
  if (err != SQL_SUCCESS)
    {
      err_log_error (err);
      if (err_ret)
	{
	  *err_ret = err;
	  return NULL;
	}
      GPF_T1 ("in get_vec_query() 2");
    }
  return res;
}

id_hash_t * upd_replay_cache;


query_t *
log_key_upd_qr (dbe_key_t * key, oid_t * col_ids, caddr_t * err_ret)
{
  query_t * res;
  dbe_table_t * key_table = key->key_table;
  string_buffer sb;
  caddr_t err;
  int n_cols, k, need_comma = 0, is_first, inx;
  query_t ** place;
  caddr_t h_key;
  char **names;
  while (key->key_migrate_to)
    key = sch_id_to_key (wi_inst.wi_schema, key->key_migrate_to);
  if (!upd_replay_cache)
    upd_replay_cache = id_hash_allocate (101, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
  h_key = list (2, box_num (key->key_id), box_copy_tree (col_ids));
  place = (query_t**)id_hash_get (upd_replay_cache, (caddr_t)&h_key);
  if (place)
    {
      query_t *qr = *place;
      if (!qr->qr_to_recompile)
	{
	  dk_free_tree (h_key);
	  return qr;
	}
    }

  sb_init (&sb);
  sb_printf (&sb, "update \"%s\".\"%s\".\"%s\" set ", key_table->tb_qualifier, key_table->tb_owner, key_table->tb_name_only);
  is_first = 1;
  DO_BOX (caddr_t, col_id_box, inx, col_ids)
    {
      oid_t col_id = unbox (col_id_box);
      dbe_column_t * col = sch_id_to_column (wi_inst.wi_schema, col_id);
      sb_printf (&sb, "%s\"%s\" = ? ", is_first ? "" : ",  ", col->col_name);
      is_first = 0;
    }
  END_DO_BOX;
  sb_printf(&sb, " WHERE ");
  get_key_col_names(&names, &n_cols, key);
  for (k=0; k<n_cols; k++)
    {
      if (need_comma)
	sb_printf (&sb, " AND ");
      else
	need_comma = 1;
      sb_printf(&sb, "\"%s\"=?", names[k]);
    }
  sb_printf (&sb, " option (no identity, no trigger)");
  dk_free (names, n_cols * sizeof(char*));

  res = sql_compile (sb.sb_buf, bootstrap_cli, &err, SQLC_DEFAULT);
  if (err != SQL_SUCCESS)
    {
      err_log_error (err);
      if (err_ret)
	{
	  *err_ret = err;
	  return NULL;
	}
      GPF_T1 ("in get_vec_query() 2");
    }
  id_hash_set (upd_replay_cache, (caddr_t)&h_key, (caddr_t)&res);
  return res;
}


query_t *
get_vec_query (lre_request_t *request, dbe_key_t * key, int flag, caddr_t * err_ret)
{
  lre_queue_t *lq = request->lr_lrq;
  int op = request->lr_op;
  query_t *res = gethash ((void*)(ptrlong)op, lq->lrq_qrs);
  if (res)
    {
      if (!res->qr_to_recompile)
	return res;
      qr_free (res);
      sethash ((void*)(ptrlong)op, lq->lrq_qrs, NULL);
      res = NULL;
    }
  while (key->key_migrate_to)
    key = sch_id_to_key (wi_inst.wi_schema, key->key_migrate_to);
  res = log_key_ins_del_qr (key, err_ret, op, flag, 1);
  sethash ((void*)(ptrlong)op, lq->lrq_qrs, (void*)res);
  return res;
}


void
log_exec_batch_vec (lre_request_t *request, caddr_t* err_ret, client_connection_t * cli)
{
  data_col_t **dcs = request->lr_params_vec;
  query_t *qr=request->lr_qr;
  stmt_options_t * opts=NULL;
  cli->cli_no_triggers = 1;
  switch (request->lr_op)
    {
      case LOG_DELETE:
      case LOG_KEY_DELETE:
	  opts=request->lr_lre->lre_opts;
    }

  request->lr_params_vec = NULL;
  *err_ret = qr_exec (cli, qr, CALLER_LOCAL, NULL, NULL,
      NULL, (caddr_t*)dcs, opts, 0);
  cli->cli_no_triggers = 0;
  if (*err_ret != SQL_SUCCESS)
    {
      err_log_error (*err_ret);
    }
  mp_free (request->lr_pool);
}

caddr_t
log_exec_batch(caddr_t av, caddr_t* err_ret)
{
  client_connection_t * cli = GET_IMMEDIATE_CLIENT_OR_NULL;
  int save_log = cli->cli_is_log;
  int lte = LTE_OK;
  lre_request_t *request = (lre_request_t*)unbox (((caddr_t*)av)[0]);
  lr_executor_t* executor = request->lr_lre;
  dk_session_t * save_ses = cli->cli_session;
  caddr_t * save_repl = cli->cli_trx->lt_replicate;
  cli->cli_trx->lt_replicate = REPL_NO_LOG;
  dk_free_box (av);
  cli->cli_session = executor->lre_in;
  cli->cli_is_log = 1;
  mutex_enter (executor->lre_mtx);
  if (executor->lre_stopped)
    {
      executor->lre_aqr_count--;
      mutex_leave(executor->lre_mtx);
      goto end;
    }
  mutex_leave (executor->lre_mtx);

  log_exec_batch_vec (request, err_ret, cli);
  IN_TXN;
  lte = lt_commit (cli->cli_trx, TRX_CONT);
  LEAVE_TXN;
  if (lte != LTE_OK)
    log_error ("In roll forward batch commit failed code %d", lte);
  dk_free (request, sizeof(lre_request_t));

  mutex_enter (executor->lre_mtx);
  executor->lre_aqr_count--;
  if (executor->lre_err == SQL_SUCCESS && *err_ret != SQL_SUCCESS)
    {
      executor->lre_err=*err_ret;
      executor->lre_stopped = 1;
    }
  mutex_leave (executor->lre_mtx);
 end:
  cli->cli_session = save_ses;
  cli->cli_is_log = save_log;
  cli->cli_trx->lt_replicate = save_repl;
  return NULL;
}

void
log_replay_err (caddr_t err)
{
  if (IS_BOX_POINTER (err) && ARRAYP (err) && BOX_ELEMENTS (err) > QC_ERROR_STRING && DV_STRINGP (((caddr_t *) err)[QC_ERRNO]))
    log_error ("Rfwd error: %s: %s", ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING]);
}


void
lrq_wait_all (lre_queue_t *lrq)
{
  caddr_t err = NULL, err2 = NULL, err3 = NULL;
  int lte;
  query_instance_t wait_qi;
  memzero (&wait_qi, sizeof (wait_qi));
  wait_qi.qi_client = GET_IMMEDIATE_CLIENT_OR_NULL;
  wait_qi.qi_trx = wait_qi.qi_client->cli_trx;
  if (wait_qi.qi_trx->lt_lock.ht_count)
    {
      IN_TXN;
      lte = lt_commit (wait_qi.qi_trx, TRX_CONT);
      LEAVE_TXN;
      if (LTE_OK != lte)
	log_error ("In roll forward main thread commit got eeror %d", lte);
    }
  lrq->lrq_aq->aq_wait_qi = &wait_qi;
  vdb_enter_lt_1 (wait_qi.qi_trx, &err2, 1);
  aq_wait_all (lrq->lrq_aq, &err);
  vdb_leave_lt (wait_qi.qi_trx, &err3);
  if (err)
    log_replay_err (err);
  if (err3)
    log_replay_err (err3);

}


void
flush_request(lr_executor_t* executor, lre_queue_t * lq)
{
  if (lre_request_count(lq->lrq_request)==0)
    return;
  mutex_enter (executor->lre_mtx);
  executor->lre_aqr_count++;
  mutex_leave (executor->lre_mtx);
  /* if different ops on same key, like ins and del then wait for the previous to finish */
  if (lq->lrq_running_op != lq->lrq_request->lr_op)
    lrq_wait_all (lq);
  lq->lrq_running_op = lq->lrq_request->lr_op;
  aq_request (lq->lrq_aq, log_exec_batch, (caddr_t)list (1, box_num ((ptrlong)lq->lrq_request)));
  lq->lrq_request = NULL;
}

caddr_t
lre_wait_all (lr_executor_t* executor)
{
  caddr_t err = SQL_SUCCESS;
  DO_HT (void*, key_id, lre_queue_t*, lrq, executor->lre_aqs)
      flush_request (executor, lrq);
  END_DO_HT;
  for (;;)
    {
      mutex_enter (executor->lre_mtx);
      if (executor->lre_aqr_count == 0)
	{
	  err=executor->lre_err;
	  executor->lre_err = SQL_SUCCESS;
	  mutex_leave (executor->lre_mtx);
	  return err;
	}
      mutex_leave(executor->lre_mtx);
      executor->lre_need_sync = 0;
      DO_HT (void*, key_id, lre_queue_t*, lrq, executor->lre_aqs)
	{
	  caddr_t err2 = SQL_SUCCESS;
	  lrq_wait_all (lrq);
	  if (err == SQL_SUCCESS && err2 != SQL_SUCCESS)
	    {
	      /* can have many errors possibly */
	      err=box_copy(err2);
	    }
	}
      END_DO_HT;
    }
}

typedef struct {
  int 		 lrm_pos;
  dbe_column_t * lrm_col;
} log_row_map_t;

void
log_map_row (log_row_map_t * map, dbe_key_t * key, int max)
{
  dbe_key_t * old_key = key;
  int inx;
  if (!key->key_migrate_to)
    {
      for (inx = 0; inx <= max; inx++)
	map[inx].lrm_pos = inx;
      return;
    }
  while (key->key_migrate_to)
    key = sch_id_to_key (wi_inst.wi_schema, key->key_migrate_to);
  inx = 0;
  DO_CL (cl, key->key_key_fixed)
    {
      dbe_column_t * col =  sch_id_to_column (wi_inst.wi_schema, cl->cl_col_id);
      map[inx].lrm_pos = key_col_in_layout_seq_1 (old_key, col, 0);
      map[inx].lrm_col = col;
      inx++;
    }
  END_DO_CL;
  DO_CL (cl, key->key_key_var)
    {
      dbe_column_t * col =  sch_id_to_column (wi_inst.wi_schema, cl->cl_col_id);
      map[inx].lrm_pos = key_col_in_layout_seq_1 (old_key, col, 0);
      map[inx].lrm_col = col;
      inx++;
    }
  END_DO_CL;
  DO_CL (cl, key->key_row_fixed)
    {
      dbe_column_t * col =  sch_id_to_column (wi_inst.wi_schema, cl->cl_col_id);
      map[inx].lrm_pos = key_col_in_layout_seq_1 (old_key, col, 0);
      map[inx].lrm_col = col;
      inx++;
    }
  END_DO_CL;
  DO_CL (cl, key->key_row_var)
    {
      dbe_column_t * col =  sch_id_to_column (wi_inst.wi_schema, cl->cl_col_id);
      int pos = dk_set_position (key->key_parts, col);
      if (pos < key->key_n_significant)
	continue; /* col-wise key has key parts once again in row var for the ref to the cols */
      map[inx].lrm_pos = key_col_in_layout_seq_1 (old_key, col, 0);
      map[inx].lrm_col = col;
      inx++;
    }
  END_DO_CL;
}


int
rd_find_val (caddr_t * arr, caddr_t val, int len)
{
  int inx;
  for (inx = 0; inx < len; inx++)
    if (arr[inx] == val)
      return inx;
  return -1;
}


caddr_t
repl_append_vec_entry_async (lre_queue_t *lq, client_connection_t * cli, lre_request_t *request, caddr_t *row, char flag)
{
  mem_pool_t *qr_pool = request->lr_pool;
  data_col_t **qr_params_vec = request->lr_params_vec;
  log_row_map_t row_map[TB_MAX_COLS];
  int n_pars = BOX_ELEMENTS(row) - 1; /* first is key_id */
  int k = 0, n_actual_params;
  caddr_t err = NULL;
  dbe_key_t * key = sch_id_to_key (wi_inst.wi_schema, unbox (row[0]));
  LOCAL_RD (rd);
  if (!key)
    {
      dk_free_tree ((caddr_t)row);
      return srv_make_new_error ("42000", "RFWNK", "No key %d", unbox (row[0]));
    }
  rd.rd_allocated = RD_AUTO;
  rd.rd_values = &row[1];
  rd.rd_n_values = BOX_ELEMENTS (row) - 1;
  rd.rd_key = key;
  memset (row_map, -1, sizeof (row_map));
  log_map_row (row_map, key, n_pars);

  if (!key)
    GPF_T1 ("No key in vectored log replay");

  if (qr_pool == NULL)
    {
      int inx = 0;
      int plen;
      query_t *qr = get_vec_query (request, key, flag, &err);
      plen = dk_set_length (qr->qr_parms);
      if (err)
	return err;
      request->lr_qr = qr;
      qr_pool = request->lr_pool = mem_pool_alloc ();
      qr_params_vec = request->lr_params_vec = (data_col_t**) mp_alloc_box(qr_pool, plen * sizeof (data_col_t*), DV_BIN);
      DO_SET (state_slot_t *, col_ssl, &qr->qr_parms)
	{
	  state_slot_t ssl;
	  data_col_t *dc;
	  ssl = *col_ssl;
	  ssl_set_dc_type (&ssl);
	  dc = mp_data_col (qr_pool, &ssl,  MAX_BATCH_COUNT);
	  qr_params_vec[inx] = dc;
	  inx++;
	}
      END_DO_SET();
#if LOG_DEBUG_LEVEL>1
      log_error ("starting batch %p: key_id=%d, op=%d, query=%s", qr_params_vec,
	  request->lr_lrq->lr_key_id, request->lr_op, qr->qr_text);
#endif
      if (inx != n_pars && !key->key_migrate_to)
	{
	  log_error ("in repl_append_vec_entry_async: key_id=%d, op=%d, query_params=%d, row_params=%d"
	      , request->lr_lrq->lr_key_id, request->lr_op, inx, n_pars);
	  GPF_T1("repl_append_vec_entry_async param count");
	}
    }
  n_actual_params = dk_set_length (request->lr_qr->qr_parms);
  /* check for blobs */
  if (key && key->key_row_var
      && request->lr_op != LOG_KEY_DELETE && request->lr_op != LOG_DELETE) /* delete log only PK */
    {
      DO_CL (cl, key->key_row_var)
	{
	  dtp_t dtp = cl->cl_sqt.sqt_col_dtp;
	  if (IS_BLOB_DTP (dtp))
	    {
	      if (key->key_is_col)
		{
		  int inx_in_rd = cl->cl_nth - key->key_n_significant;
		  caddr_t val = rd.rd_values[inx_in_rd];
		  caddr_t val2;
		  if (DV_COL_BLOB_SERIAL == (dtp_t)val[0])
		    {
		      blob_handle_t * bh = bh_alloc (DV_BLOB_HANDLE);
		      bh->bh_ask_from_client = 1;
		      val2 = (caddr_t)bh;
		      request->lr_mb_blobs = 1;
		  request->lr_lre->lre_need_sync = 1;
		    }
		  else
		    val2 = box_deserialize_string (val, INT32_MAX, 0);
		  dk_free_box (val);
		  rd.rd_values[inx_in_rd] = val2;
		}
	      else
		{
		  int inx_in_rd;
	      caddr_t val = rd_col (&rd, cl->cl_col_id, NULL);
		  caddr_t val2;
	      dtp_t dtp = DV_TYPE_OF (val);
	      if (DV_STRING != dtp)
		continue;
	      dtp = val[0];
	      if (IS_BLOB_DTP (dtp))
		{
		      blob_handle_t * bh = bh_alloc (DV_BLOB_HANDLE);
		      bh->bh_ask_from_client = 1;
		      val2 = (caddr_t)bh;
		  request->lr_mb_blobs = 1;
		      request->lr_lre->lre_need_sync = 1;
		    }
		  else
		    {
		      int len = box_length (val) - 1;
		      val2 = dk_alloc_box (len, DV_STRING);
		      memcpy (val2, val + 1, len);
		    }
		  inx_in_rd = rd_find_val (rd.rd_values, val, rd.rd_n_values);
		  if (-1 == inx_in_rd) GPF_T1 ("rd bad in blob ins replay");

		  dk_free_box (val);
		  rd.rd_values[inx_in_rd] = val2;
		}
	    }
	}
      END_DO_CL;
    }

  for (k = 0; k < n_actual_params; k++) 
    {
      caddr_t arg, to_free = NULL;
      dtp_t dtp;
      data_col_t *dc = qr_params_vec[k];
      int pos = row_map [k].lrm_pos;

      if (pos >= 0)
	arg = row [pos+1];
      else if (row_map [k].lrm_col != (void *)-1)
	to_free = arg = box_copy_tree (row_map [k].lrm_col->col_default);
      else
	continue;
      dtp = DV_TYPE_OF (arg);
      dc_append_box (dc, arg);
      dk_free_tree (to_free);
    }
 ret:
  dk_free_tree (row);
  return SQL_SUCCESS;
}

void geo_insert (query_instance_t * qi, dbe_table_t * tb, caddr_t g, boxint id, int is_del, int is_geo_box);

void
log_geo_replay (dbe_key_t * key, lock_trx_t * lt, caddr_t* row)
    {
  geo_t g;
  query_instance_t qi;
  boxint id = unbox (row[5]);
  g.geo_fill = 0;
  g.geo_flags = GEO_BOX;
  g.geo_srcode = 0;
  if (DV_TYPE_OF (row[1]) == DV_SINGLE_FLOAT)
    {
      g.XYbox.Xmin = unbox_float (row[4]);
      g.XYbox.Ymin = unbox_float (row[3]);
      g.XYbox.Xmax = unbox_float (row[2]);
      g.XYbox.Ymax = unbox_float (row[1]);
    }
  else if (DV_TYPE_OF (row[1]) == DV_DOUBLE_FLOAT)
    {
      g.XYbox.Xmin = unbox_double (row[4]);
      g.XYbox.Ymin = unbox_double (row[3]);
      g.XYbox.Xmax = unbox_double (row[2]);
      g.XYbox.Ymax = unbox_double (row[1]);
    }
  else
    GPF_T1 ("Unexected type of geo box");
  memset (&qi, 0, sizeof (query_instance_t));
  qi.qi_trx = lt;
  qi.qi_client = lt->lt_client;
  geo_insert (&qi, key->key_table, (caddr_t) &g, id, 0, 1);
}

caddr_t
log_replay_entry_async (lr_executor_t* executor, lock_trx_t * lt, dtp_t op, dk_session_t * in, int is_pushback)
{
  char flag = 0;
  caddr_t* row;
  key_id_t key_id;
  caddr_t err = SQL_SUCCESS, err2;
  lre_request_t* request;
  lre_queue_t * lq;

  switch (op)
    {
      case LOG_KEY_INSERT:
	  flag = session_buffered_read_char (in); /* not used in bif_key_replay_insert() */
	  /* no break! */
      case LOG_INSERT:
      case LOG_INSERT_SOFT:
	case LOG_INSERT_REPL:
      case LOG_DELETE:
      case LOG_KEY_DELETE:
	    {
	      dbe_key_t * key;
	      row = (caddr_t*) scan_session (in);
	      key_id = row_key_id(row);
	      if (LOG_KEY_INSERT == op && enable_log_key_count)
		log_key_count (key_id);
	      key = sch_id_to_key (wi_inst.wi_schema, unbox (row[0]));
	      if ((NULL != key) && key->key_is_geo /* || !strcmp (key->key_name, "RDF_GEO")*/)
		{
		  key->key_is_geo = 1;
		  log_geo_replay (key, lt, row);
		  return SQL_SUCCESS;
		}
	      break;
	    }
      default:
	  err = lre_wait_all (executor);
	  if (err != SQL_SUCCESS)
	    return err;
	  return log_replay_entry (lt, op, in, is_pushback);
    }

  if (dbf_rq_key > 1 && key_id != dbf_rq_key)
    {
      dk_free_tree (row);
      return SQL_SUCCESS;
    }
  mutex_enter (executor->lre_mtx);
  if (executor->lre_stopped)
    {
      err=executor->lre_err;
      executor->lre_err = SQL_SUCCESS; /** each error reported only once */
      mutex_leave (executor->lre_mtx);
      return err;
    }
  lq = lrq_alloc (executor, key_id, lt);
  mutex_leave (executor->lre_mtx);

  request = lq->lrq_request;
  if ((request != NULL) && (request->lr_op != 0) && (request->lr_op != op))
    {
      flush_request (executor, lq);
      request = NULL;
    }
  if (request == NULL)
    {
      request= (lre_request_t*) dk_alloc (sizeof (lre_request_t));
      memset (request, 0, sizeof (lre_request_t));
      request->lr_lre = executor;
      request->lr_lrq = lq;
      request->lr_op = op;
      lq->lrq_request = request;
    }
  err2 = repl_append_vec_entry_async (lq, lt->lt_client, request, row, flag);
  if (!err) err = err2;
  if (lre_request_count (request) == MAX_BATCH_COUNT || executor->lre_need_sync)
    flush_request (request->lr_lre, lq);
  if (executor->lre_need_sync)
    {
      lre_wait_all (executor);
      cli_free_dae (lt->lt_client);
    }
  return err;
}

caddr_t
log_cl_trx_id (caddr_t * header)
{
  caddr_t * cl2pc = (caddr_t*)header[LOGH_CL_2PC];
  if (!cl2pc)
    return NULL;
  return ARRAYP (cl2pc) ? cl2pc[0] : (caddr_t)cl2pc;
}


int
log_is_cl_prepared (caddr_t * header)
{
  caddr_t id = log_cl_trx_id (header);
  return id && (LOG_CL_2PC_PREPARE == id[0]
		|| LOG_CL_2PC_PREPARE_FROM_SYNC == id[0]);
}


caddr_t
log_2pc_hosts (caddr_t * header)
{
  caddr_t * cl2pc = (caddr_t*)header[LOGH_CL_2PC];
  return  ARRAYP (cl2pc) ? cl2pc[1] : NULL;
}



caddr_t
repl_origin (caddr_t * header)
{
  if (header)
    {
      caddr_t * repl = (caddr_t*) header[LOGH_REPLICATION];
      if (!repl)
	return NULL;
      return (repl[REPL_ORIGIN]);
    }
  else
    return NULL;
}

void
repl_cycle_message (caddr_t * header)
{
  caddr_t * repl = (caddr_t *) header[LOGH_REPLICATION];
  if (tc_repl_cycle < 5)
    {
      caddr_t srv = repl[REPLH_SERVER];
      caddr_t acct = repl[REPLH_ACCOUNT];
      if (!srv)
	srv = "<unknown>";
      if (!acct)
	acct = "<unknown>";
      log_info ("Replication cycle, (only 5 first occurrences reported)"
		":: server %s account %s transaction %ld has this server for origin.",
		srv, acct, unbox (repl[REPLH_LEVEL]));
    }
}


int
log_handle_double_sync (client_connection_t * repl_cli, caddr_t * repl_header, caddr_t trx_id)
{
  /* a txn can come in in first as prepared and then a second time as commit.  This is so when a cpt falls between prepare and final and relogs the txn in the new log.
   * If so, rb the previous with the w_id and replay this one.  Wil also deal with local w_id accidentally colliding with replay.  If a prepared that became rb is recd, branch wanted query will finish it. */
  int64 w_id = INT64_REF_NA (trx_id + 1);
  ptrlong plt;
  lock_trx_t * lt;
  if (!w_id)
    return 0;
  ASSERT_IN_TXN;
  gethash_64 (plt, w_id, local_cll.cll_w_id_to_trx);
  if (!plt)
    return 0; /* not seen before */
  lt = (lock_trx_t *)plt;
  if (lt == repl_cli->cli_trx)
    return 0; /* can be by chance. lt of the cli is always fresh here, so do nothing */
  if (lt->lt_threads || lt->lt_client)
    {
      log_info ("Host %d: Found w_id %d:%d in log sync with a client or thread.  First abort this and then replay the incoming", local_cll.cll_this_host, QFID_HOST (w_id), (int32)w_id);
      if (LT_DELTA_ROLLED_BACK != lt->lt_status)
	lt_kill_other_trx (lt, NULL, NULL, LT_KILL_ROLLBACK);
    }
  else
    {
      log_info ("Host %d: Getting a duplicate sync %d:%d, can happen if cpt relogged a prepared.", local_cll.cll_this_host, QFID_HOST (w_id), (int32)w_id);
      lt->lt_threads = 1;
      lt_rollback (lt, TRX_CONT);
      lt->lt_threads = 0;
      lt_done (lt);
    }
  return 1;
}


void
log_check_w_id_counter (int64 w_id)
{
  /* getting w_ids of self from log sync, set the counter so as not to reuse */
  if (local_cll.cll_this_host == QFID_HOST (w_id) && W_ID_GT (w_id, lt_w_counter))
{
      lt_w_counter = (uint32)(w_id + 1);
      if (!lt_w_counter)
	lt_w_counter = 1;
    }
}

void
log_remember_replay (caddr_t trx_id)
{
  int64 id;
  if (!IS_BOX_POINTER (trx_id))
    return;
  id = INT64_REF_NA (trx_id + 1);
  if (id && local_cll.cll_replayed_w_ids)
    {
      IN_CLL;
      sethash_64 (id, local_cll.cll_replayed_w_ids, 1);
      LEAVE_CLL;
    }
}

int
log_is_replayed (caddr_t trx_id)
{
  int64 f = 0, id;
  if (!local_cll.cll_replayed_w_ids || !IS_BOX_POINTER (trx_id))
    return 0;
  id = INT64_REF_NA (trx_id + 1);
  if (!id)
    return 0;
  IN_CLL;
  if (local_cll.cll_replayed_w_ids)
    gethash_64 (f, id, local_cll.cll_replayed_w_ids);
  LEAVE_CLL;
  return (int)f;
}


int
log_replay_trx (lr_executor_t * lr_executor, dk_session_t * in, client_connection_t * cli,
		caddr_t repl_header, int is_repl, int is_pushback, OFF_T log_rec_start)
{
  caddr_t trx_id = NULL;
  int64 w_id;
  caddr_t volatile org = repl_origin ((caddr_t*) repl_header);
  int rc, was_deadlock = 0;
  caddr_t err;
  dtp_t op;
  lock_trx_t *lt;
  int is_cl_prepared = log_is_cl_prepared ((caddr_t*)repl_header), is_xa = 0, lock_escalation_pct_save = lock_escalation_pct;

  rfwd_ctr++; op_ctr=0;
  IN_TXN;
  lt = cli_set_new_trx (cli);
  lt_threads_set_inner (lt, 1);
  lt->lt_replicate = (is_repl || is_cl_prepared) ? REPL_LOG : REPL_NO_LOG;
  lt->lt_repl_is_raw = 1;
  memcpy (lt->lt_approx_dt, wi_inst.wi_log_replay_dt, DT_LENGTH);
  LEAVE_TXN;
#ifdef VIRTTP
  if (!is_repl)
    {
      long st_2pc = (long) unbox(((caddr_t*)repl_header)[LOGH_2PC]);
      if ((LOG_VIRT_2PC_PREPARE == st_2pc) ||
	  (LOG_MTS_2PC_PREPARE == st_2pc))
	{
	  box_t recov_data = (box_t) read_object(in);
	  int recovery_res = 0;
	  if (LOG_VIRT_2PC_PREPARE == st_2pc)
	    recovery_res = virt_tp_recover (recov_data);
	  else if (MSDTC_IS_LOADED)
	    recovery_res = mts_recover (recov_data);
	  else
	    {
	      log_error ("MS DTC unfinished transaction has been found, but no MS DTC support had been loaded. Either remove log file, or load MS DTC support plugin. exit");
	      call_exit (1);
	    }
	  if (SQL_ROLLBACK == recovery_res)
	    {
	      caddr_t trash = (caddr_t) dk_alloc(in->dks_in_fill - in->dks_in_read);
	      session_buffered_read(in,trash,in->dks_in_fill - in->dks_in_read);
	      dk_free(trash,-1);
	      dk_free_box(recov_data);
	      IN_TXN;
	      lt_leave (lt);
	      LEAVE_TXN;
	      return LTE_OK;
	    }
	  dk_free_box(recov_data);
	}
      else if (LOG_XA_2PC_PREPARE == st_2pc)
	{
	  /* XA transaction */
	  caddr_t xid = (caddr_t) read_object (in);
	  /*caddr_t transact = dk_alloc_box (in->dks_in_fill - in->dks_in_read, DV_BIN);*/
	  _2pc_printf (("log: found xid [%s]\n", xid_bin_encode (xid)));
	  /*session_buffered_read(in,transact,in->dks_in_fill - in->dks_in_read);
	  id_hash_set (global_xa_map->xm_log_xids, (caddr_t) & xid, (caddr_t) & transact);*/
	  virt_xa_add_trx (xid, lt);
	  lt->lt_replicate = REPL_LOG;
	  is_xa = 1;
	  _xa_log_ctr++;
	}
      else if (LOG_2PC_DISABLED != st_2pc)
	  dk_free_box((box_t) read_object(in));
    }
#endif
  if (org && box_equal (org, db_name))
    {
      /* if a txn originated here comes back by repl we just record the level but do not do the action */
      TC (tc_repl_cycle);
      repl_cycle_message ((caddr_t *)repl_header);
    }
  else
    {
      lt->lt_replica_of = box_copy_tree (org);
      /* if XA set lock_escalation_pct to 200 */
      if (is_xa || is_cl_prepared)
	lock_escalation_pct = 2000;
      CATCH_READ_FAIL (in)
	{
	  int has_more=1;
	  while (has_more)
	    {
	      if (in->dks_in_read != in->dks_in_fill)
	        {
		  op_ctr++;
	      op = session_buffered_read_char (in);
		  if (dbf_rq_key && LOG_UPDATE == op)
		    return LTE_OK;
		  if (lr_executor)
		    err = log_replay_entry_async (lr_executor, lt, op, in, is_pushback);
	          else
	      err = log_replay_entry (lt, op, in, is_pushback);
	        }
	      else
	        {
		  has_more=0;
		  if (lr_executor)
		    {
	              caddr_t err2=lre_wait_all(lr_executor);
	              if (err2 != SQL_SUCCESS)
	                {
	      if (err == SQL_SUCCESS)
	    	            err=err2;
	    	          else
	    	            dk_free_tree (err2);
	                }
 	             }
	        }
	      if (err == SQL_SUCCESS || err == (caddr_t) SQL_NO_DATA_FOUND)
		continue;
	      if (is_xa || is_cl_prepared)
		lock_escalation_pct = lock_escalation_pct_save;
                  if (0 == strcmp ("40001", ((caddr_t *) err)[1]))
		was_deadlock = 1;
                  if (is_pushback && 0 == strcmp("TR091", ((caddr_t *) err)[2]))
                    {
                      dk_free_tree (err);
		      IN_TXN;
		      lt_leave (lt);
		      LEAVE_TXN;
                      return LTE_REJECT;
                    }

	      IN_TXN;
              err_log_error (err);
              dk_free_tree (err);
	      lt_rollback (lt, TRX_CONT);
	      lt_leave (lt);
	      LEAVE_TXN;
	      if (was_deadlock)
		return LTE_DEADLOCK;
	      return is_pushback ? LTE_SQL_ERROR : LTE_OK;
	    }
	}
      FAILED
	{
	  /* bad log record */
	  IN_TXN;
	  lt_rollback (lt, TRX_CONT);
	  lt_leave (lt);
	  LEAVE_TXN;
	  log_error ("Bad log record encountered during replay");
	  if (is_xa || is_cl_prepared)
	    lock_escalation_pct = lock_escalation_pct_save;
	  return LTE_SQL_ERROR;
	}
    }
  IN_TXN;
  if (is_cl_prepared)
    {
      /* In sync or rfwd, a prepared. Leave hanging to be resolved later.  If coordinated by self, needs branch consensus.  Can also come from own log if stop/start without intervening remove and sync */
      lt->lt_2pc_hosts = box_copy_tree (log_2pc_hosts ((caddr_t*)repl_header));
      log_info ("Host %d:  In log %s got prepared lt %d:%d, will resolve later from other branches", local_cll.cll_this_host, is_repl ? "resync": "rfwd",
		QFID_HOST (lt->lt_w_id), (int32)lt->lt_w_id);
      if (local_cll.cll_this_host == QFID_HOST (lt->lt_w_id))
	lt->lt_need_branch_consensus = 1; /* getting a prepared that originated here. Must ask others what to do with it */
      lt->lt_status = LT_CL_PREPARED;
      lt->lt_cl_enlisted = 1;
      lt->lt_started = approx_msec_real_time ();
      LEAVE_TXN;
      if (is_repl)
	{
	  mutex_enter (log_write_mtx);
	  lt->lt_log_2pc = 1;
	  rc = log_commit (lt);
	  mutex_leave (log_write_mtx);
	}
      else
	{
	  /* could be the trx is resolved without it being relogged by checkpoint, so give it a commit flag offset from the file */
	  lt->lt_log_2pc = 1;
	  lt->lt_commit_flag_offset = log_rec_start + LOGH_COMMIT_FLAG_OFFSET (lt);
	  rc = LTE_OK;
	}
      IN_TXN;
    }

  if (!is_pushback)
    logh_set_level (lt, (caddr_t *) repl_header);
  /* if XA do not commit, clear cli trx and start new transaction for cli */
  if (is_xa || is_cl_prepared)
    lock_escalation_pct = lock_escalation_pct_save;
  else
    {
    rc = lt_commit (lt, TRX_CONT);
      if (LTE_OK == rc)
	log_remember_replay (trx_id);
    }
  lt_leave (lt); /* 0 w_id is an exception for logging sequence ranges that are logged independently of the calling trx  and that must get replayed but must not shadow other w_ids.  A 2pc trx never has w id 0. */
  if (is_xa || is_cl_prepared)
    {
      cli->cli_trx = NULL;
      lt->lt_client = NULL;
      lt->lt_status = LT_PREPARED;
      lt->lt_2pc._2pc_wait_commit = 1;
      cli_set_new_trx (cli);
      rc = LTE_OK;
    }
  if (in_log_replay)
    {
      wi_free_old_qrs ();
      DO_SET (dbe_schema_t *, sc, &wi_inst.wi_free_schemas)
	{
	  dk_set_delete (&wi_inst.wi_free_schemas, (void *) sc);
	  dbe_schema_free (sc);
	}
      END_DO_SET ();
    }
  LEAVE_TXN;
  if (LTE_LOG_FAILED == rc)
    {
      return rc;
    }
  return LTE_OK;
}


int level_print = 0;

void
logh_set_level (lock_trx_t * lt, caddr_t * logh)
{
}

uint32 log_last_local_w_id = 0;


int
log_replay_time (caddr_t * header)
{
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (header[LOGH_USER]))
    {
      caddr_t * dta = (caddr_t*) header[LOGH_USER];
      if (BOX_ELEMENTS (dta) == 2 && DV_DATETIME == DV_TYPE_OF (dta[0]))
	{
	  int64 w_id = unbox (dta[1]);
	  if (DVC_LESS == dt_compare (wi_inst.wi_log_replay_dt, dta[0], 1))
	    memcpy (wi_inst.wi_log_replay_dt, dta[0], DT_LENGTH);
	  if (QFID_HOST (w_id) == local_cll.cll_this_host
	      &&  (!log_last_local_w_id || W_ID_GT ((int32)w_id, log_last_local_w_id)))
	    log_last_local_w_id = (int32)w_id;
	  dk_free_tree ((caddr_t)header);
	  return 1;
	}
    }
  return 0;
}


int
log_check_header (caddr_t * header)
{
  if (!IS_BOX_POINTER (header) || box_tag ((caddr_t) header) != DV_ARRAY_OF_POINTER)
    return 0;
  if (BOX_ELEMENTS (header) != LOG_HEADER_LENGTH)
    {
#ifdef VIRTTP
      if (BOX_ELEMENTS(header) == LOG_HEADER_LENGTH_OLD)
        {
	  if (!is_old_log_type)
	    {
	      log_info ("Old type of log is detected");
	      is_old_log_type = 1;
	    }
	  return 1;
	}
#endif
      return 0;
    }
  return 1;
}


int
log_report_time ()
{
  static unsigned int32 last_time = 0;
  unsigned int32 now = get_msec_real_time (), r = 0;
  if (now - last_time > 2000)
    {
      r = 1;
      last_time = now;
    }
  return r;
}


#define B_LOG_CK(n) \
  c = fgetc (f); \
  pos ++; \
  if (c < 0) break; \
  if (c != n) continue


int
log_replay_search_next_log_rec (dk_session_t *file_in)
{
  volatile OFF_T pos = file_in->dks_bytes_received -
       (file_in->dks_in_fill - file_in->dks_in_read);
  int fd = tcpses_get_fd (file_in->dks_session);
  FILE * f;
  int c = 0;

  log_error ("Searching for the next valid header signature starting at " OFF_T_PRINTF_FMT,
      (OFF_T_PRINTF_DTP) pos);

  f = fdopen (dup (fd), "r");
  if (!f)
    {
      log_error ("Failed duplicating the file descriptor : %m");
      return 0;
    }

  for (;;)
    {
      B_LOG_CK (193);
      B_LOG_CK (188);
      B_LOG_CK (5);
      B_LOG_CK (188);
      B_LOG_CK (0);
      pos -= 5;
      log_error ("Valid looking header found at offset " OFF_T_PRINTF_FMT ".",
	  (OFF_T_PRINTF_DTP) pos);
      break;
    }

  fclose (f);

  if (c < 0)
    {
      log_error ("No valid looking header found.");
      return 0;
    }
  else
    {
      file_in->dks_bytes_received = pos;
      file_in->dks_in_fill = file_in->dks_in_read = 0;
      if (((OFF_T)-1) == LSEEK (fd, -5, SEEK_CUR))
        {
          log_error ("File error seeking in the log file : %m");
          return 0;
        }
      else
	return 1;
    }
}



#define REPORT_PROGRESS \
  if (log_report_time ()) {			\
  if (total_size_bytes) \
    log_info ("    %ld transactions, " OFF_T_PRINTF_FMT " bytes replayed (%ld %%)", \
	rfwd_ctr, \
	      (OFF_T_PRINTF_DTP) file_in->dks_bytes_received - (file_in->dks_in_fill - file_in->dks_in_read), \
	(int) (file_in->dks_bytes_received * 100 / total_size_bytes)); \
  else \
    log_info ("    %ld transactions, " OFF_T_PRINTF_FMT " bytes replayed", \
	rfwd_ctr, \
	(OFF_T_PRINTF_DTP) file_in->dks_bytes_received - (file_in->dks_in_fill - file_in->dks_in_read)); \
}



int
log_check_trx (int64 trx_no)
{
  dbe_storage_t * dbs = wi_inst.wi_master;
  int64 max = 0;
  int fd;
  int ret = LOG_2PC_ABORT;
  volatile OFF_T log_rec_start = 0;
  dk_session_t *file_in;
  caddr_t trx_string;
  ASSERT_OUTSIDE_MTX (wi_inst.wi_txn_mtx);
  mutex_enter (log_write_mtx);
  if (log_2pc_archive_check (trx_no, &max))
    {
      mutex_leave (log_write_mtx);
      return LOG_2PC_COMMIT;
    }
  fd = fd_open (dbs->dbs_log_name, OPEN_FLAGS_RO);
  if (fd <= 0)
    {
      mutex_leave (log_write_mtx);
      return LOG_2PC_ABORT;
    }
  file_in = dk_session_allocate (SESCLASS_TCPIP);
  tcpses_set_fd (file_in->dks_session, fd);
  if (0 != LSEEK (fd, 0, SEEK_SET))
    GPF_T1 ("failed lseek in log_check_trx");

  while (DKSESSTAT_ISSET (file_in, SST_OK))
    {
      int bytes;
      caddr_t *header;
      log_rec_start = file_in->dks_bytes_received - (file_in->dks_in_fill - file_in->dks_in_read);
      header = (caddr_t *) read_object (file_in);
      if (!DKSESSTAT_ISSET (file_in, SST_OK))
	{
	  break;
	}
      if (!log_check_header (header))
	{
	  break;
	}
      bytes = (int) unbox (header[LOGH_BYTES]);
      trx_string = (char *) dk_alloc (bytes + 1);

      CATCH_READ_FAIL (file_in)
	session_buffered_read (file_in, trx_string, bytes);
      FAILED
      {
	END_READ_FAIL (file_in);
	break;
      }
      END_READ_FAIL (file_in);
	      dk_free (trx_string, bytes + 1);
	      dk_free_tree ((caddr_t) header);
      log_skip_blobs_1 (file_in);
    }
  mutex_leave (log_write_mtx);
  PrpcSessionFree (file_in);
  return ret;
}

int dbf_first_to_replay = 0;
int dbf_stop_rfwd;

client_connection_t *
log_set_immediate_client (client_connection_t * cli)
{
  dk_session_t * ses;
  client_connection_t * old;
  if ((ses = IMMEDIATE_CLIENT))
    {
      old = DKS_DB_DATA (ses);
      DKS_DB_DATA (ses) = cli;
    }
  else
    {
      old = GET_IMMEDIATE_CLIENT_OR_NULL;
      SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_IMMEDIATE_CLIENT, cli);
    }
  return old;
}


client_connection_t * rfwd_cli;
void
log_replay_file (int fd)
{
  int rc, do_replay;
  volatile OFF_T log_rec_start = 0;
  client_connection_t *cli = client_connection_create ();
  dk_session_t *file_in = dk_session_allocate (SESCLASS_TCPIP);
  dk_session_t trx_ses;
  client_connection_t * save_cli = log_set_immediate_client (cli);
  scheduler_io_data_t trx_sio;
  dk_session_t *str_in = &trx_ses;
  caddr_t trx_string;
#ifdef VIRTTP
  int is_2pc;
#endif
  OFF_T total_size_bytes;
  OFF_T good_log_rec_start = 0;
  lr_executor_t* lr_executor=NULL;

  cli->cli_user = sec_id_to_user (U_ID_DBA);
  total_size_bytes = LSEEK (fd, 0, SEEK_END);
  if (total_size_bytes == (OFF_T) -1)
    total_size_bytes = 0;
  else
    {
      if (0 != LSEEK (fd, 0, SEEK_SET))
	{
	  log_error ("Error seeking into the log file : %m");
	  call_exit (-1);
	}
    }

  tcpses_set_fd (file_in->dks_session, fd);
  rfwd_ctr = 0;
  /* comment out following line to switch off vectored log replay */
  lr_executor = lre_alloc();
  lr_executor->lre_in = file_in;

  log_info ("Roll forward started");
  if (!lite_mode)
    {
      dk_alloc_set_reserve_mode (DK_ALLOC_RESERVE_PREPARED); /* This is to GPF if already out of memory */
      dk_alloc_set_reserve_mode (DK_ALLOC_RESERVE_DISABLED); /* This is to GPF on out-of-memory instead of trying to recover */
    }
  memset (&trx_ses, 0, sizeof (trx_ses));
  memset (&trx_sio, 0, sizeof (trx_sio));
  SESSION_SCH_DATA (&trx_ses) = &trx_sio;
  cli->cli_session = file_in;
  cli->cli_is_log = 1;
  cli->cli_replicate = REPL_NO_LOG;
  while (DKSESSTAT_ISSET (file_in, SST_OK))
    {
      int bytes;
      caddr_t *header;
      log_rec_start = file_in->dks_bytes_received - (file_in->dks_in_fill - file_in->dks_in_read);
read_again:
#if LOG_DEBUG_LEVEL >1
log_error (" ** log_rec_start=" OFF_T_PRINTF_FMT, log_rec_start);
#endif
      header = (caddr_t *) read_object (file_in);
      if (!DKSESSTAT_ISSET (file_in, SST_OK)
	  || dbf_stop_rfwd)
	{
	  break;
	}
      if (!log_check_header (header))
	{
	  log_error ("Invalid log entry in replay. Delete transaction log %.500s or truncate at point of error."
		     " Valid data may exist after this record. A log record begins with bytes 193 188 5 188 0."
                     " Error at offset " OFF_T_PRINTF_FMT,
	      wi_inst.wi_master->dbs_log_name ? wi_inst.wi_master->dbs_log_name : "",
	      (OFF_T_PRINTF_DTP) log_rec_start);
#if LOG_DEBUG_LEVEL >1
	  log_error ("  good_log_rec_start=" OFF_T_PRINTF_FMT, good_log_rec_start);
#endif
	  GPF_T1("Bad incoming tag");
          if (!log_replay_search_next_log_rec (file_in))
	    {
	      call_exit (-1);
	    }
          else
	    {
	      goto read_again;
	    }
	}
      good_log_rec_start=log_rec_start;
      if (log_replay_time (header))
	continue;
      bytes = (int) unbox (header[LOGH_BYTES]);
      trx_string = (char *) dk_alloc (bytes + 1);

#ifdef WIN32
      wisvc_send_wait_hint (WISVC_SEND_WAIT_HINT_EVERY_N_MSEC, 2);
#endif

      CATCH_READ_FAIL (file_in)
	session_buffered_read (file_in, trx_string, bytes);
      FAILED
      {
	log_error ("Log reading error in replay. The log replay may be incomplete."
		   " Error at offset " OFF_T_PRINTF_FMT,
	    (OFF_T_PRINTF_DTP) log_rec_start);
	END_READ_FAIL (file_in);
	break;
      }
      END_READ_FAIL (file_in);
      str_in->dks_in_buffer = trx_string;
      str_in->dks_in_read = 0;
      str_in->dks_in_fill = bytes;
      do_replay = 1;
#ifdef VIRTTP
      is_2pc = is_old_log_type ? LOG_2PC_DISABLED : (int) unbox(header[LOGH_2PC]);
      if (LOG_2PC_ABORT != is_2pc)
	do_replay = 1;
      else
	do_replay = 0;
#else
	  do_replay = 1;
#endif
      if (rfwd_ctr < dbf_first_to_replay)
	{
	  rfwd_ctr++;
		do_replay = 0;
	}
      if (do_replay)
	{
	  lr_executor->lre_stopped = 0; /* reset the flag */
	  rc = log_replay_trx (lr_executor, str_in, cli, (caddr_t) header, 0, 0, log_rec_start);
	  rfwd_cli = cli;
	  /*rq_check (NULL);*/
	  if (LTE_DEADLOCK == rc || LTE_CHECKPOINT == rc)
	    {
	      /* deadlock retry must set the file pointer to start for the blobs. */
	      log_error ("Redoing transaction at offset " BOXINT_FMT " due to deadlock or atomic section", log_rec_start);
	      LSEEK (fd, log_rec_start, SEEK_SET);
	      file_in->dks_bytes_received = log_rec_start;
	      file_in->dks_in_fill = file_in->dks_in_read = 0;
	      goto read_again;
	    }
	  if (LTE_OK != rc)
	    {
	      log_error ("Roll forward txn error %d. Record between bytes "
			 OFF_T_PRINTF_FMT " and " OFF_T_PRINTF_FMT " in transaction log",
			 rc,
			 (OFF_T_PRINTF_DTP) log_rec_start,
			 (OFF_T_PRINTF_DTP) file_in->dks_bytes_received);
	    }
	  if (dbf_rq_key)
	    log_skip_blobs_1 (file_in);
	}
      else
	log_skip_blobs_1 (file_in);
      dk_free (trx_string, bytes + 1);
      dk_free_tree ((caddr_t) header);

      if (0 == rfwd_ctr % 1000)
	{
	  REPORT_PROGRESS;
	  clear_old_root_images ();
	}
    }
  lre_free (lr_executor);
  lr_executor = NULL;
  if (rfwd_ctr)
    REPORT_PROGRESS;
  PrpcSessionFree (file_in);
  IN_TXN;
  if (cli->cli_trx)
    lt_done (cli->cli_trx);
  LEAVE_TXN;
  log_set_immediate_client (save_cli);
  client_connection_free (cli);
  log_info ("Roll forward complete");
  if (!lite_mode)
    dk_alloc_set_reserve_mode (DK_ALLOC_RESERVE_PREPARED);
}


void
log_checkpoint (dbe_storage_t * dbs, char *new_log, int shutdown)
{
  if ((char*) -1 == new_log)
    return;
  mutex_enter (log_write_mtx);
  if (dbs->dbs_2pc_log_session)
    session_flush (dbs->dbs_2pc_log_session);
  last_log_time_written = 0;
  if (!new_log)
    {
      if (dbs->dbs_log_session)
	{
	  LSEEK (tcpses_get_fd (dbs->dbs_log_session->dks_session), 0, SEEK_SET);
	  FTRUNCATE (tcpses_get_fd (dbs->dbs_log_session->dks_session), (OFF_T) (0));
	  dbs->dbs_log_length = 0;
          if (CPT_SHUTDOWN != shutdown)
	    {
	      log_set_byte_order_check (1);
	      log_time (log_time_header (wi_inst.wi_master->dbs_cfg_page_dt));
	      log_set_server_version_check (1);
	    }
	  log_info ("Checkpoint finished, log reused");
	}
      else
	{
	  log_info ("Checkpoint finished, log off");
	}
    }
  else
    {
      if (dbs->dbs_log_session)
	{
	  int new_fd;
	  file_set_rw (new_log);
	  new_fd = fd_open (new_log, LOG_OPEN_FLAGS);
	  if (new_fd < 0)
	    {
	      log_error ("Cannot change to log file %s", new_log);
	      call_exit (1);
	    }
	  fd_close (tcpses_get_fd (dbs->dbs_log_session->dks_session),
		    dbs->dbs_log_name);
	  tcpses_set_fd (dbs->dbs_log_session->dks_session, new_fd);
	  dk_free_tree (dbs->dbs_log_name);
	  dbs->dbs_log_name = box_string (new_log);
	}
      else
	{
	  dk_free_tree (dbs->dbs_log_name);
	  dbs->dbs_log_name = box_string (new_log);
	}
      cfg_replace_log (new_log);
      dbs->dbs_log_length = 0;
      if (CPT_SHUTDOWN != shutdown)
	{
	  log_set_byte_order_check (1);
	  log_time (log_time_header (wi_inst.wi_master->dbs_cfg_page_dt));
	  log_set_server_version_check (1);
	}
      log_info ("Checkpoint finished, new log is %s", new_log);
    }
  DO_SET (lock_trx_t *, lt, &all_trxs)
    {
      if (((LT_PREPARED == lt->lt_status && lt->lt_2pc._2pc_wait_commit) || LT_2PC_PENDING == lt->lt_status)
	  && strses_length (lt->lt_log))
	{
	  int status = lt->lt_status;
	  int rc;
	  if (!dbs->dbs_log_length)
	    {
	      log_set_byte_order_check (1);
	      log_time (log_time_header (wi_inst.wi_master->dbs_cfg_page_dt));
	      log_set_server_version_check (1);
	    }
	  if (LT_PREPARED == status && lt->lt_2pc._2pc_wait_commit)
	    lt->lt_status = LT_PREPARE_PENDING;
	  lt->lt_log_2pc = 1;
	  rc = log_commit (lt);
	  lt->lt_status = status;
	  if (LTE_OK != rc)
	    log_error ("Checkpoint interrupted 2pc transaction between prepare and final.  The log of the prepared state could not be written to the post-checkpoint transaction log.  This means that, if the transaction commits and ought to be replayed from log, the transaction will be lost. trx no %d:%d", QFID_HOST (lt->lt_w_id), (uint32)lt->lt_w_id);
	}
      else if (lt->lt_log_2pc && lt->lt_commit_flag_offset)
	{
	  log_info ("2pc txn with status %d during cpt log", lt->lt_status);
	  lt->lt_commit_flag_offset = 0;
	}
    }
  END_DO_SET ();
  mutex_leave (log_write_mtx);
}

int in_log_replay = 0;

void
log_init (dbe_storage_t * dbs)
{
  int enter_bsc = 0;
  del_rc = resource_allocate (10, NULL, NULL, NULL, 0);
  upd_rc = resource_allocate (10, NULL, NULL, NULL, 0);
  if (dbs->dbs_log_name)
    {
      int log_fd;
      file_set_rw (dbs->dbs_log_name);
      log_fd = fd_open (dbs->dbs_log_name, LOG_OPEN_FLAGS);
      if (log_fd < 0)
	{
	  log_error ("Can't open log : %m");
	  call_exit (1);
	}
      if (bootstrap_cli->cli_trx->lt_threads)
	{
	  enter_bsc = 1;
	  IN_TXN;
	  lt_leave(bootstrap_cli->cli_trx);
	  LEAVE_TXN;
	}
      in_log_replay = 1;
      log_replay_file (log_fd);
      in_log_replay = 0;
      if (enter_bsc)
	lt_enter_anyway (bootstrap_cli->cli_trx);
      mutex_enter (log_write_mtx);
      /* the replay file becomes the log session unless a log session was made during replay for logging cluster config changes deliverdd as control messages */
      if (!dbs->dbs_log_session)
	{
      dbs->dbs_log_session = dk_session_allocate (SESCLASS_TCPIP);
      tcpses_set_fd (dbs->dbs_log_session->dks_session, log_fd);
      dbs->dbs_log_length = LSEEK (log_fd, 0, SEEK_END);
      if (!dbs->dbs_log_length)
        {
	  log_set_byte_order_check(0);
	  log_set_server_version_check (1);
        }
    }
      mutex_leave (log_write_mtx);
    }
  if (f_read_from_rebuilt_database)
    {
      log_segment_t *ls = dbs->dbs_log_segments;

      while (ls)
	{
	  int log_fd;

	  dbs->dbs_current_log_segment = ls;
	  log_info ("Processing log segment %s", ls->ls_file);
	  file_set_rw (ls->ls_file);
	  log_fd = fd_open (ls->ls_file, LOG_OPEN_FLAGS);
	  if (log_fd < 0)
	    {
	      log_error ("Can't open log segment : %m");
	      call_exit (1);
	    }
	  in_log_replay = 1;
	  log_replay_file (log_fd);
	  in_log_replay = 0;
	  close (log_fd);

	  ls = ls->ls_next;
	}
      dbs->dbs_current_log_segment = NULL;
    }
}

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
/* IvAn/XperUpdate/000904 Xper support added. */
#include "xmltree.h"
#include "security.h"

#ifdef WIN32
# include "wiservic.h"
#endif

#ifdef VIRTTP
#define LOG_CL_2PC_PREPARE 0x11
#define LOG_MTS_2PC_PREPARE	0x0E
#define LOG_VIRT_2PC_PREPARE	0x0F
#define LOG_XA_2PC_PREPARE	0x10
#define LOG_2PC_COMMIT		0x01
#define LOG_2PC_ABORT		0x02
#define LOG_MTS_ENABLED		0x03
#define LOG_2PC_DISABLED	0x04

#define LOG_2PC_COMMIT_S	"\001"
#define LOG_2PC_ABORT_S		"\002"

#include "2pc.h"
#include "msdtc.h"

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


int
log_change_if_needed (lock_trx_t * lt, int rewrite)
{
  int old_fd;
  int new_fd;
  dbe_storage_t * dbs = wi_inst.wi_master;
  log_segment_t *ls = dbs->dbs_current_log_segment;
  if (lt->lt_backup)
    return LTE_OK;
  if (!ls || !dbs->dbs_log_session)
    return LTE_OK;
  if (dbs->dbs_log_length > ls->ls_bytes)
    {
      old_fd = tcpses_get_fd (dbs->dbs_log_session->dks_session);
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


extern long dbf_log_no_disk;

int
log_commit (lock_trx_t * lt)
{
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
    }

  cbox = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * LOG_HEADER_LENGTH,
				   DV_ARRAY_OF_POINTER);
  memset (cbox, 0, sizeof (caddr_t) * LOG_HEADER_LENGTH);
  if (lt->lt_log_2pc)
    {
      caddr_t id = dk_alloc_box (10, DV_STRING);
      id[0] = LOG_CL_2PC_PREPARE;
      /* logging a 1pc needs only update of log if rollback */
      lt->lt_commit_flag_offset = dbs->dbs_log_length + LOGH_COMMIT_FLAG_OFFSET;
      INT64_SET_NA (id + 1, lt->lt_w_id);
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
  }
  END_WRITE_FAIL (log_ses);
  if (lt->lt_blob_log)
    {
      lt_write_blob_log (lt, log_ses);
    }

  if (!lt->lt_backup)
    {
      dk_free_tree ((caddr_t) cbox);
    }
  else
    dk_free_tree ((caddr_t) cbox);
  lt->lt_replicate = NULL;

  if (!DKSESSTAT_ISSET (log_ses, SST_OK))
    {
      log_ses->dks_out_fill = 0; /* clear maybe unflushed */
      FTRUNCATE (tcpses_get_fd (log_ses->dks_session), prev_length);
      log_error ("Out of disk space for log");
      LT_ERROR_DETAIL_SET (lt, box_dv_short_string ("Out of disk space for log"));
      return LTE_LOG_FAILED;
    }

  {
      if (!lt->lt_backup)
	dbs->dbs_log_length += log_ses->dks_bytes_sent;
      else
	lt->lt_backup_length += log_ses->dks_bytes_sent;
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
  rc = log_commit (lt);
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
log_skip_blobs (dk_session_t * ses)
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
		  && (uint32)id > last_id)
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
	  if (SQL_COMMIT == is_commit && QFID_HOST (lt->lt_w_id) == local_cll.cll_this_host)
	    log_2pc_archive (lt->lt_w_id);
	}
      mutex_leave (log_write_mtx);
    }
}


void
lt_log_prime_key (lock_trx_t * lt, row_delta_t * rd)
{
  dbe_key_t * key = rd->rd_key;
  int inx;
  dks_array_head (lt->lt_log, 1 + key->key_n_significant, DV_ARRAY_OF_POINTER);
  print_int (key->key_id, lt->lt_log);
  for (inx = 0; inx < key->key_n_significant; inx++)
    print_object (rd->rd_values[inx], lt->lt_log, NULL, NULL);
}


long txn_after_image_limit = 50000000L;
#define TXN_CHECK_LOG_IMAGE(lt) \
  if (txn_after_image_limit > 0 && lt->lt_log->dks_bytes_sent > (OFF_T) txn_after_image_limit) \
    { \
      (lt)->lt_status = LT_BLOWN_OFF; \
      (lt)->lt_error = LTE_LOG_IMAGE; \
    }

void
log_insert (lock_trx_t * lt, row_delta_t * rd, int flag)
{
  int inx;
  dk_session_t *log;
  lt_hi_row_change (lt, rd->rd_key->key_super_id, LOG_INSERT, NULL);
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
      session_buffered_write_char (LOG_KEY_INSERT, lt->lt_log);
      flag &= ~LOG_KEY_ONLY;
    }
  if (flag == INS_REPLACING)
    session_buffered_write_char (LOG_INSERT_REPL, lt->lt_log);
  else if (flag == INS_SOFT)
    session_buffered_write_char (LOG_INSERT_SOFT, lt->lt_log);
  else
    session_buffered_write_char (LOG_INSERT, lt->lt_log);
  dks_array_head (lt->lt_log, 1 + rd->rd_n_values, DV_ARRAY_OF_POINTER);
  print_int (rd->rd_key->key_id, lt->lt_log);
  for (inx = 0; inx < rd->rd_n_values; inx++)
    print_object (rd->rd_values[inx], lt->lt_log, NULL, NULL);

  TXN_CHECK_LOG_IMAGE (lt);
  mutex_leave (lt->lt_log_mtx);
}




void
log_delete (lock_trx_t * lt, row_delta_t * rd, int this_key_only)
{
  lt_hi_row_change (lt, rd->rd_key->key_super_id, LOG_DELETE, NULL);
  if (!lt || lt->lt_replicate == REPL_NO_LOG || cl_non_logged_write_mode)
    return;
  mutex_enter (lt->lt_log_mtx);

  if (this_key_only)
    session_buffered_write_char (LOG_KEY_DELETE, lt->lt_log);
  else
    session_buffered_write_char (LOG_DELETE, lt->lt_log);
  lt_log_prime_key (lt, rd);
  mutex_leave (lt->lt_log_mtx);
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
log_text_array (lock_trx_t * lt, caddr_t box)
{
  if (!lt || lt->lt_replicate == REPL_NO_LOG || cl_non_logged_write_mode)
    return;
  mutex_enter (lt->lt_log_mtx);
  session_buffered_write_char (LOG_TEXT, lt->lt_log);
  print_object (box, lt->lt_log, NULL, NULL);
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
  print_object (box, lt->lt_log, NULL, NULL);
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
  lt_log_prime_key (lt, rd);
  if (upd->upd_cols_param)
    {
      caddr_t vals = qst_get (qst, upd->upd_values_param);
      caddr_t cols = qst_get (qst, upd->upd_cols_param);
      print_object (cols, lt->lt_log, NULL, NULL);
      print_object (vals, lt->lt_log, NULL, NULL);
    }
  else
    {
      state_slot_t **vals = upd->upd_values;
      print_object ((caddr_t) upd->upd_col_ids, lt->lt_log, NULL, NULL);

      session_buffered_write_char (DV_ARRAY_OF_POINTER, lt->lt_log);
      print_int (BOX_ELEMENTS (vals), lt->lt_log);

      for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (vals); inx++)
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
		print_object (data, lt->lt_log, NULL, NULL);
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


query_t *ins_replay;
query_t *s_ins_replay;
query_t *r_ins_replay;


char *ins_replay_text = "(seq (row_insert :PL replacing) (end))";
char *s_ins_replay_text = "(seq (row_insert :PL soft) (end))";
char *r_ins_replay_text = "(seq (row_insert :PL replacing) (end))";

caddr_t
log_replay_insert (lock_trx_t * lt, dk_session_t * in, int flag)
{
  query_t *st;
  caddr_t err;
  db_buf_t row = (db_buf_t) scan_session (in);

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
  err = qr_quick_exec (st, lt->lt_client, "x", NULL, 1,
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
  opts->so_concurrency = SQL_CONCUR_LOCK;

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


caddr_t
log_replay_update (lock_trx_t * lt, dk_session_t * in)
{
  db_buf_t row = (db_buf_t) scan_session (in);
  caddr_t cols = (caddr_t) scan_session (in);
  caddr_t vals;

  query_t *qr = (query_t *) resource_get (upd_rc);
  caddr_t err;
  LOG_REPL_OPTIONS (opts);

  vals = (caddr_t) scan_session (in);
  if (!qr)
    qr = eql_compile (upd_replay_text, lt->lt_client);
  err = qr_rec_exec (qr, lt->lt_client, NULL, CALLER_LOCAL, opts, 3,
		     ":PL", row, QRP_RAW,
		     ":COLS", cols, QRP_RAW,
		     ":VALS", vals, QRP_RAW);
  resource_store (upd_rc, (void *) qr);

  if (err != SQL_SUCCESS)
    {
      err_log_error (err);
    }
  return err;
}

caddr_t
log_replay_text (lock_trx_t * lt, dk_session_t * in, int is_pushback, int use_stmt_cache)
{
  int n_args = 0;
  caddr_t *entry = (caddr_t *) scan_session (in);
  dtp_t dtp = DV_TYPE_OF (entry);
  caddr_t text = DV_ARRAY_OF_POINTER == dtp && BOX_ELEMENTS (entry) > 0 ? entry[0] : (caddr_t) entry;
  caddr_t err = NULL;
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
      return srv_make_new_error ("42000", "TR100", "log_replay_text: invalid query text");
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
      err = stmt_set_query (sst, lt->lt_client, text, opts);
      LEAVE_CLIENT (lt->lt_client);
      if (err != NULL)
	{
	  if (DV_ARRAY_OF_POINTER == dtp)
	    entry[0] = NULL;
	  dk_free_tree ((box_t) entry);
	  if (is_pushback)
	    return err;
	  err_log_error (err);
	  return ((caddr_t) SQL_SUCCESS);
	}
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
      return (log_replay_insert (lt, in, op));
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


long rfwd_ctr = 0;


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
log_replay_trx (dk_session_t * in, client_connection_t * cli,
    caddr_t repl_header, int is_repl, int is_pushback)
{
  caddr_t volatile org = repl_origin ((caddr_t*) repl_header);
  int rc;
  caddr_t err;
  dtp_t op;
  lock_trx_t *lt;
  int is_xa = 0, lock_escalation_pct_save = lock_escalation_pct;

try_again:

  rfwd_ctr++;
  IN_TXN;
  lt = cli_set_new_trx (cli);
  lt_threads_set_inner (lt, 1);
  lt->lt_replicate = is_repl ? REPL_LOG : REPL_NO_LOG;
  lt->lt_repl_is_raw = 1;
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
      if (is_xa)
	lock_escalation_pct = 2000;
      CATCH_READ_FAIL (in)
	{
	  while (1)
	    {
	      if (in->dks_in_read == in->dks_in_fill)
		break;
	      op = session_buffered_read_char (in);

	      err = log_replay_entry (lt, op, in, is_pushback);
	      if (err == SQL_SUCCESS)
		continue;
	      if (is_xa)
		lock_escalation_pct = lock_escalation_pct_save;

              if (err != (caddr_t) SQL_NO_DATA_FOUND)
                {
                  if (0 == strcmp ("40001", ((caddr_t *) err)[1]))
                    {
                      /* deadlock */
		      break;
                    }
                  if (is_pushback && 0 == strcmp("TR091", ((caddr_t *) err)[2]))
                    {
                      dk_free_tree (err);
		      IN_TXN;
		      lt_leave (lt);
		      LEAVE_TXN;
                      return LTE_REJECT;
                    }
                }

	      IN_TXN;
              err_log_error (err);
              dk_free_tree (err);
	      lt_rollback (lt, TRX_CONT);
	      lt_leave (lt);
	      LEAVE_TXN;
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
	  if (is_xa)
	    lock_escalation_pct = lock_escalation_pct_save;
	  return LTE_SQL_ERROR;
	}
    }
  IN_TXN;
  if (!is_pushback)
    logh_set_level (lt, (caddr_t *) repl_header);
  /* if XA do not commit, clear cli trx and start new transaction for cli */
  if (is_xa)
    lock_escalation_pct = lock_escalation_pct_save;
  else
    rc = lt_commit (lt, TRX_CONT);
  lt_leave (lt);
  if (is_xa)
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
  if (LTE_DEADLOCK == rc)
    {
      dbg_printf (("Log Recovery Deadlocked. Retrying.\n"));
      in->dks_in_read = 0;
      goto try_again;
    }
  return rc;
}


int level_print = 0;

void
logh_set_level (lock_trx_t * lt, caddr_t * logh)
{
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

#define B_LOG_CK(n) \
  c = fgetc (f); \
  pos ++; \
  if (c < 0) break; \
  if (c != n) continue


static int
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
do { \
  if (total_size_bytes) \
    log_info ("    %ld transactions, " OFF_T_PRINTF_FMT " bytes replayed (%ld %%)", \
	rfwd_ctr, \
	(OFF_T_PRINTF_DTP) file_in->dks_bytes_received, \
	(int) (file_in->dks_bytes_received * 100 / total_size_bytes)); \
  else \
    log_info ("    %ld transactions, " OFF_T_PRINTF_FMT " bytes replayed", \
	rfwd_ctr, \
	(OFF_T_PRINTF_DTP) file_in->dks_bytes_received); \
} while (0)

int
log_check_trx (int64 trx_no)
{
  dbe_storage_t * dbs = wi_inst.wi_master;
  int fd;
  int ret = 0;
  volatile OFF_T log_rec_start = 0;
  dk_session_t *file_in;
  caddr_t trx_string;
  int64 max;
  ASSERT_OUTSIDE_MTX (wi_inst.wi_txn_mtx);
  if (log_2pc_archive_check (trx_no, &max))
    return 1;
  fd = fd_open (dbs->dbs_log_name, OPEN_FLAGS_RO);
  if (fd < 0)
    return 0;
  file_in = dk_session_allocate (SESCLASS_TCPIP);
  tcpses_set_fd (file_in->dks_session, fd);
  mutex_enter (log_write_mtx);
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
      if (header[LOGH_CL_2PC])
	{
	  caddr_t id = header[LOGH_CL_2PC];
	  int64 trx_id = INT64_REF_NA (id + 1);
	  if (trx_id == trx_no && id[0] == LOG_2PC_COMMIT)
	    {
	      dk_free (trx_string, bytes + 1);
	      dk_free_tree ((caddr_t) header);
	      ret = 1;
	      break;
	    }
	}
      dk_free (trx_string, bytes + 1);
      dk_free_tree ((caddr_t) header);
      log_skip_blobs (file_in);
    }
  mutex_leave (log_write_mtx);
  PrpcSessionFree (file_in);
  return ret;
}

uint32 log_last_local_w_id = 0;

void
log_replay_file (int fd)
{
  int rc, do_replay;
  volatile OFF_T log_rec_start = 0;
  client_connection_t *cli = client_connection_create ();
  dk_session_t *file_in = dk_session_allocate (SESCLASS_TCPIP);
  dk_session_t trx_ses;
  scheduler_io_data_t trx_sio;
  dk_session_t *str_in = &trx_ses;
  caddr_t trx_string;
#ifdef VIRTTP
  int is_2pc;
#endif
  OFF_T total_size_bytes;

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
      header = (caddr_t *) read_object (file_in);
      if (!DKSESSTAT_ISSET (file_in, SST_OK))
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
          if (!log_replay_search_next_log_rec (file_in))
	    {
	      call_exit (-1);
	    }
          else
	    {
	      goto read_again;
	    }
	}
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
      if (header[LOGH_CL_2PC])
	{
	  caddr_t id = header[LOGH_CL_2PC];
	  int64 trx_id = INT64_REF_NA (id + 1);
	  if (CL_RUN_LOCAL != cl_run_local_only && QFID_HOST (trx_id) == local_cll.cll_this_host)
	    {
	      uint32 local_id = (uint32)trx_id;
	      /* start transaction numbering where left off, do not confuse sequence for purposes of 2pc recov */
	      if (local_id > log_last_local_w_id)
		log_last_local_w_id = local_id;
	    }

	  do_replay = id[0] != LOG_2PC_ABORT;
	  if (LOG_2PC_COMMIT == id[0] && QFID_HOST (trx_id) == local_cll.cll_this_host)
	    log_2pc_archive (trx_id);
	  if (LOG_CL_2PC_PREPARE == id[0])
	    {
	      int32 host = QFID_HOST (trx_id);
	      if (host == local_cll.cll_this_host) /* same host, not committed */
		do_replay = 0;
	      else
		{
		   GPF_T;
		}

	    }
	}
      if (do_replay)
	{
	  if (LTE_OK != (rc = log_replay_trx (str_in, cli, (caddr_t) header, 0, 0)))
	    {
	      log_error ("Roll forward txn error %d. Record between bytes "
			 OFF_T_PRINTF_FMT " and " OFF_T_PRINTF_FMT " in transaction log",
			 rc,
			 (OFF_T_PRINTF_DTP) log_rec_start,
			 (OFF_T_PRINTF_DTP) file_in->dks_bytes_received);
	    }
	}
      else
	log_skip_blobs (file_in);
      dk_free (trx_string, bytes + 1);
      dk_free_tree ((caddr_t) header);

      if (0 == rfwd_ctr % 1000)
	{
	  REPORT_PROGRESS;
	  clear_old_root_images ();
	}
    }
  if (rfwd_ctr)
    REPORT_PROGRESS;
  PrpcSessionFree (file_in);
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
  if (dbs->dbs_2pc_log_session)
    session_flush (dbs->dbs_2pc_log_session);
  if (!new_log)
    {
      if (dbs->dbs_log_session)
	{
	  mutex_enter (log_write_mtx);
	  LSEEK (tcpses_get_fd (dbs->dbs_log_session->dks_session), 0, SEEK_SET);
	  FTRUNCATE (tcpses_get_fd (dbs->dbs_log_session->dks_session), (OFF_T) (0));
	  dbs->dbs_log_length = 0;
          if (CPT_SHUTDOWN != shutdown)
	    {
	      log_set_byte_order_check (1);
	      log_set_server_version_check (1);
	    }
	  mutex_leave (log_write_mtx);
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
      mutex_enter (log_write_mtx);
      dbs->dbs_log_length = 0;
      if (CPT_SHUTDOWN != shutdown)
	{
	  log_set_byte_order_check (1);
	  log_set_server_version_check (1);
	}
      mutex_leave (log_write_mtx);
      log_info ("Checkpoint finished, new log is %s", new_log);
    }
  DO_SET (lock_trx_t *, lt, &all_trxs)
    {
      if (((LT_PREPARED == lt->lt_status && lt->lt_2pc._2pc_wait_commit) || LT_2PC_PENDING == lt->lt_status)
	  && strses_length (lt->lt_log))
	{
	  int status = lt->lt_status;
	  int rc;
	  mutex_enter (log_write_mtx);
	  if (!dbs->dbs_log_length)
	    {
	      log_set_byte_order_check (1);
	      log_set_server_version_check (1);
	    }
	  if (LT_PREPARED == status && lt->lt_2pc._2pc_wait_commit)
	    lt->lt_status = LT_PREPARE_PENDING;
	  rc = log_commit (lt);
	  lt->lt_status = status;
	  if (LTE_OK != rc)
	    log_error ("Checkpoint interrupted 2pc transaction between prepare and final.  The log of the prepared state could not be written to the post-checkpoint transaction log.  This means that, if the transaction commits and ought to be replayed from log, the transaction will be lost. trx no %d:%d", QFID_HOST (lt->lt_w_id), (uint32)lt->lt_w_id);
	  mutex_leave (log_write_mtx);
	}
      else if (lt->lt_log_2pc && lt->lt_commit_flag_offset)
	{
	  log_info ("2pc txn with status %d during cpt log", lt->lt_status);
	  lt->lt_commit_flag_offset = 0;
	}
    }
  END_DO_SET ();
}

int in_log_replay = 0;

void
log_init (dbe_storage_t * dbs)
{
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
      in_log_replay = 1;
      log_replay_file (log_fd);
      in_log_replay = 0;
      dbs->dbs_log_session = dk_session_allocate (SESCLASS_TCPIP);
      tcpses_set_fd (dbs->dbs_log_session->dks_session, log_fd);
      dbs->dbs_log_length = LSEEK (log_fd, 0, SEEK_END);
      if (!dbs->dbs_log_length)
        {
	  log_set_byte_order_check(0);
	  log_set_server_version_check (1);
        }
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

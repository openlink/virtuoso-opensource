/*
 *  obackup.c
 *
 *  $Id$
 *
 *  Online & Incremental Backup
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


#include "sqlnode.h"
#include "sqlbif.h"
#include "libutil.h"
#ifdef WIN32
# include "wiservic.h"
#endif

#include "zlib.h"

#include "recovery.h"

#include "security.h"


#ifdef WIN32
#include <windows.h>
#define HAVE_DIRECT_H
#endif

#ifdef HAVE_DIRECT_H
#include <direct.h>
#include <io.h>
#define mkdir(p,m)	_mkdir (p)
#define FS_DIR_MODE	0
#define PATH_MAX	 MAX_PATH
#define get_cwd(p,l)	_get_cwd (p,l)
#else
#include <dirent.h>
#define FS_DIR_MODE	 (S_IRWXU | S_IRWXG)
#endif

#undef DBG_BREAKPOINTS
#undef INC_DEBUG

typedef struct ob_err_ctx_s
{
  int		oc_inx;
  char		oc_file[FILEN_BUFSIZ];
} ob_err_ctx_t;

ol_backup_ctx_t bp_ctx = {
  {
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0
  }, /* prefix */
  0, /* ts */
  0, /* num */
  0, /* pages */
  0, /* date in sec */
  0, /* index of directory */
  0, /* written bytes */
};

typedef int (*file_check_f) (caddr_t file, caddr_t ctx, caddr_t dir);

const char* recover_file_prefix = 0;
static dp_addr_t dir_first_page = 0;

static time_t db_bp_date = 0;
static long ol_max_dir_sz = 0;
static dk_hash_t * ol_known_pages = 0;

static int read_backup_header (ol_backup_context_t* ctx, char ** header);
static void backup_path_init ();

static int ob_check_file (caddr_t elt, caddr_t ctx, caddr_t dir);
static int ob_foreach_dir (caddr_t * dirs, caddr_t ctx, ob_err_ctx_t* e_ctx, file_check_f func);
static int ob_get_num_from_file (caddr_t file, caddr_t prefix);
static int try_to_change_dir (ol_backup_context_t * ctx);
static void backup_context_flush (ol_backup_context_t * ctx);
void cpt_over (void);


typedef struct backup_status_s
{
  int is_running;
  int is_error;
  long pages;
  long processed_pages;
  char errcode[101];
  char errstring[1025];
} backup_status_t;

static backup_status_t backup_status;

caddr_t * backup_patha = 0;

static void ol_test_jmp (dk_session_t * ses)
{
  SESSTAT_CLR (ses->dks_session, SST_OK);
  SESSTAT_SET (ses->dks_session, SST_BROKEN_CONNECTION);
  longjmp_splice (&SESSION_SCH_DATA (ses)->sio_write_broken_context, 1);
}

char* format_timestamp (uint32 * ts)
{
  static char buf [200];
  unsigned int c1, c2, c3, c4;

  c1 = (ts[0] & 0xFF000000) >> 24;
  c2 = (ts[0] & 0x00FF0000) >> 16;
  c3 = (ts[0] & 0x0000FF00) >> 8;
  c4 = (ts[0] & 0x000000FF) >> 0;

  snprintf (buf, sizeof (buf), "0x%02X%02X-0x%02X-0x%02X", c1, c2, c3, c4);
  return box_dv_short_string (buf);
}

#if 0
char* bp_curr_timestamp ()
{
  char * ts;
  IN_CPT_1;
  ts = format_timestamp (&bp_ctx.db_bp_ts);
  LEAVE_CPT_1;

  return ts;
}

char* bp_curr_date ()
{
  if (bp_ctx.db_bp_date)
    {
      time_t tmp = bp_ctx.db_bp_date;
      char * static_str = ctime (&tmp);
      return box_dv_short_string (static_str ? static_str : "invalid");
    }
  else
    return box_dv_short_string ("unknown");
}

char* bp_curr_prefix ()
{
  char* prefix = 0;
  IN_CPT_1;
  if (bp_ctx.db_bp_prfx[0])
    prefix = box_dv_short_string (bp_ctx.db_bp_prfx);
  else
    prefix = NEW_DB_NULL;
  LEAVE_CPT_1;
  return prefix;
}

caddr_t bp_curr_num ()
{
  uint32 num;
  IN_CPT_1;
  num = bp_ctx.db_bp_num;
  LEAVE_CPT_1;

  return box_num (num);
}

caddr_t bp_curr_inx ()
{
  uint32 num;
  IN_CPT_1;
  num = bp_ctx.db_bp_index;
  LEAVE_CPT_1;

  return box_num (num);
}
#else
char* bp_curr_timestamp ()
{
  char * ts;
  ts = format_timestamp (&bp_ctx.db_bp_ts);
  return ts;
}

char* bp_curr_date ()
{
  if (bp_ctx.db_bp_date)
    {
      time_t tmp = bp_ctx.db_bp_date;
      char * static_str = ctime (&tmp);
      return box_dv_short_string (static_str ? static_str : "invalid");
    }
  else
    return box_dv_short_string ("unknown");
}

char* bp_curr_prefix ()
{
  char* prefix = 0;
  if (bp_ctx.db_bp_prfx[0])
    prefix = box_dv_short_string (bp_ctx.db_bp_prfx);
  else
    prefix = NEW_DB_NULL;
  return prefix;
}

caddr_t bp_curr_num ()
{
  uint32 num;
  num = bp_ctx.db_bp_num;
  return box_num (num);
}

caddr_t bp_curr_inx ()
{
  uint32 num;
  num = bp_ctx.db_bp_index;
  return box_num (num);
}
#endif

static
void make_log_error (ol_backup_context_t* ctx, const char* code, const char* msg, ...);

static
buffer_desc_t * incset_make_copy (buffer_desc_t * incset_orig_buf);

static void incset_rollback (ol_backup_context_t* ctx);
static void ctx_clear_backup_files (ol_backup_context_t* ctx);

/* online/incremental backup functions */

int ol_backup_page (it_cursor_t * itc, buffer_desc_t * buf, ol_backup_context_t * ctx);
caddr_t compressed_buffer (buffer_desc_t* buf);
int uncompress_buffer (caddr_t compr, unsigned char* page_buf);

dk_hash_t *
hash_reverse (dk_hash_t* hash)
{
  dk_hash_t* new_hash = hash_table_allocate (hash->ht_actual_size);
  dk_hash_iterator_t iter;

  dp_addr_t origin_dp;
  dp_addr_t remap_dp;
  uptrlong origin_dp_ptr, remap_dp_ptr;

  for (dk_hash_iterator (&iter, hash);
       dk_hit_next (&iter, (void**)&origin_dp_ptr, (void**)&remap_dp_ptr);
       /* */)
    {
      origin_dp = (dp_addr_t) origin_dp_ptr;
      remap_dp = (dp_addr_t) remap_dp_ptr;
      sethash (DP_ADDR2VOID(remap_dp), new_hash, DP_ADDR2VOID(origin_dp));
    }
  return new_hash;
}

void
ol_write_header (ol_backup_context_t * ctx)
{
  if (ctx->octx_is_tail)
    return;
  /* prefix */
  print_long ((long) strlen (ctx->octx_file_prefix), ctx->octx_file);
  session_buffered_write (ctx->octx_file, ctx->octx_file_prefix, strlen (ctx->octx_file_prefix));

  /* timestamp */
  print_long (ctx->octx_timestamp, ctx->octx_file);

  /* number of this file */
  print_long (ctx->octx_num, ctx->octx_file);

   /* size of all backup */
  print_long (ctx->octx_last_page, ctx->octx_file);
}

int ol_buf_disk_read (buffer_desc_t* buf)
{
  dbe_storage_t* dbs = buf->bd_storage;
  OFF_T off;
  OFF_T rc;
  if (!IS_IO_ALIGN (buf->bd_buffer))
    GPF_T1 ("ol_buf_disk_read (): The buffer is not io-aligned");
  if (dbs->dbs_disks)
    {
      disk_stripe_t *dst = dp_disk_locate (dbs, buf->bd_physical_page, &off);
      int fd = dst_fd (dst);

      rc = LSEEK (fd, off, SEEK_SET);

      if (rc != off)
	{
	  log_error ("Seek failure on stripe %s", dst->dst_file);
	  GPF_T;
	}
      rc = read (fd, buf->bd_buffer, PAGE_SZ);
      dst_fd_done (dst, fd);

      if (rc != PAGE_SZ)
	{
	  log_error ("Read failure on stripe %s", dst->dst_file);
	  GPF_T;
	}
    }
  else
    {
      mutex_enter (dbs->dbs_file_mtx);
      off = ((OFF_T)buf->bd_physical_page) * PAGE_SZ;
      rc = LSEEK (dbs->dbs_fd, off, SEEK_SET);
      if (rc != off)
	{
	  log_error ("Seek failure on database %s", dbs->dbs_file);
	  GPF_T;
	}
      rc = read (dbs->dbs_fd, (char *) buf->bd_buffer, PAGE_SZ);
      if (rc != PAGE_SZ)
	{
	  log_error ("Read failure on database %s", dbs->dbs_file);
	  GPF_T;
	}
      mutex_leave (dbs->dbs_file_mtx);
    }
  return WI_OK;
}


int
ol_write_cfg_page (ol_backup_context_t * ctx)
{
  wi_database_t db;
  buffer_desc_t * buf = buffer_allocate (DPF_CP_REMAP);
  int res = -1;

  buf->bd_page = buf->bd_physical_page = 0;
  buf->bd_storage = wi_inst.wi_master;

  if (WI_ERROR != ol_buf_disk_read (buf))
    {
      /* fix checkpoint page no */
      memcpy (&db, buf->bd_buffer, sizeof (wi_database_t));

      /* fix timestamp */
      if (!bp_ctx.db_bp_ts)
	GPF_T1 ("backup timestamp in not initialized");
      strncpy (db.db_bp_prfx, bp_ctx.db_bp_prfx, BACKUP_PREFIX_SZ);
      db.db_bp_ts =  bp_ctx.db_bp_ts;
      db.db_bp_pages =  bp_ctx.db_bp_pages;
      db.db_bp_num =  bp_ctx.db_bp_num;
      db.db_bp_date = bp_ctx.db_bp_date;
      db.db_bp_index = bp_ctx.db_bp_index;
      db.db_bp_wr_bytes = bp_ctx.db_bp_wr_bytes;

      memcpy (buf->bd_buffer, &db, sizeof (wi_database_t));
      ctx->octx_disable_increment = 1;
      res = ol_backup_page (NULL, buf, ctx);
      ctx->octx_disable_increment = 0;
    }
  buffer_free (buf);
  return res;
}


FILE * obackup_trace;
void
ol_remap_trace (ol_backup_context_t * ctx)
{
  buffer_desc_t * buf = ctx->octx_cpt_set;
  if (!obackup_trace)
    return;
  fprintf (obackup_trace, "Remaps follow:\n");
  while (buf)
    {
      int inx;
      for (inx = DP_DATA; inx < PAGE_SZ; inx += 8)
	{
	  dp_addr_t l = LONG_REF (buf->bd_buffer + inx);
	  dp_addr_t p = LONG_REF (buf->bd_buffer + inx + 4);
	  if (l)
	    fprintf (obackup_trace, "L=%ld P=%ld\n", (long)l, (long)p);
	}
      buf = buf->bd_next;
    }
  fflush (obackup_trace);
}


int
ol_write_page_set (ol_backup_context_t * ctx, buffer_desc_t * buf,  int clr)
{
  while (buf)
    {
      if (clr)
	{
	memset (buf->bd_buffer + DP_DATA, 0, PAGE_DATA_SZ);
	  page_set_checksum_init (buf->bd_buffer + DP_DATA);
	}
      if (-1 == ol_backup_page (NULL, buf, ctx))
	return -1;
      buf = buf->bd_next;
    }
  return 0;
}


int
ol_write_sets (ol_backup_context_t * ctx, dbe_storage_t * storage)
{
  int res, inx;
  res = ol_write_page_set (ctx, ctx->octx_dbs->dbs_incbackup_set, 1);
  res = ol_write_page_set (ctx, ctx->octx_cpt_set, 0);
  ol_remap_trace (ctx);
  res = ol_write_page_set (ctx, ctx->octx_ext_set, 0);
  res = ol_write_page_set (ctx, ctx->octx_free_set, 0);
  DO_BOX (caddr_t *, elt, inx, ctx->octx_registry)
    {
      caddr_t name = elt[0];
      caddr_t val = elt[1];
      buffer_desc_t * em;
      if (!DV_STRINGP (name) || !DV_STRINGP (val))
	continue;
      if (0 == strncmp (name, "__EM:", 5)
	  || 0 == strcmp (name, "__sys_ext_map"))
	{
	  dp_addr_t dp = atoi (val);
	  em = dbs_read_page_set (ctx->octx_dbs, dp, DPF_EXTENT_MAP);
	  res = ol_write_page_set (ctx, em, 0);
	  buffer_set_free (em);
	}
    }
  END_DO_BOX;
  return res;
}


int
ol_regist_unmark (it_cursor_t * itc, buffer_desc_t * buf, ol_backup_context_t * ctx)
{
  uint32* array;
  int inx, bit;
  dp_addr_t array_page;
  IN_DBS (buf->bd_storage);
  dbs_locate_incbackup_bit (buf->bd_storage, buf->bd_page,
			    &array, &array_page, &inx, &bit);

  if (array[inx] & 1<<bit)
    {
      page_set_update_checksum (array, inx, bit);
      array[inx] &= ~(1 << bit);
    }
  LEAVE_DBS (buf->bd_storage);
  return 0;
}

int
ol_write_registry (dbe_storage_t * dbs, ol_backup_context_t * ctx, ol_regist_callback_f callback)
{
  dp_addr_t first = dbs->dbs_registry;
  buffer_desc_t * buf = buffer_allocate (DPF_BLOB);

  buf->bd_storage = dbs;

  while (first)
    {
      buf->bd_physical_page = buf->bd_page = first;

      if (WI_ERROR == ol_buf_disk_read (buf))
	GPF_T1 ("Could not read registry during backup");

      if (-1 == (*callback)(0, buf, ctx))
	return -1;

      first = LONG_REF (buf->bd_buffer + DP_OVERFLOW);
    }

  buffer_free (buf);
  return 0;
}

long ch_c;
long cm_c;


int
ol_backup_page (it_cursor_t * itc, buffer_desc_t * buf, ol_backup_context_t * ctx)
{
  ol_backup_context_t * octx = (ol_backup_context_t*)ctx;
  dp_addr_t page = buf->bd_physical_page; /* unlike v5, all restores to same phys place, incl. remapped pages */
  int backuped = 0;
  int write_header_first = 0;

  if (octx->octx_is_invalid)
    return -1;
 again:
  if (DP_DELETED != page)
    {
      caddr_t compr_buf;
      compr_buf = compressed_buffer (buf);
      if (compr_buf)
	{
	  OFF_T prev_length = ctx->octx_file->dks_bytes_sent;
	  if (ctx->octx_file->dks_out_fill)
	    GPF_T1 ("file is not flushed");
	  CATCH_WRITE_FAIL (ctx->octx_file)
	    {
	      if (write_header_first)
		ol_write_header (octx);
	      print_long (page, octx->octx_file);
	      /* actually needed for testing purposes only */
	      if (!octx->octx_disable_increment &&
 	          octx->octx_max_wr_bytes &&
		  ((octx->octx_wr_bytes + octx->octx_file->dks_bytes_sent + octx->octx_file->dks_out_fill -1)
		   > octx->octx_max_wr_bytes))
		{
		  backup_context_flush (octx);
		  log_warning ("maximum size of directory reached, [" OFF_T_PRINTF_FMT "]",
		      (OFF_T_PRINTF_DTP) (octx->octx_wr_bytes +
					  octx->octx_file->dks_bytes_sent +
					  octx->octx_file->dks_out_fill - 1));
		  ol_test_jmp(octx->octx_file);
		}

	      print_object (compr_buf, octx->octx_file, 0,0);
	      dk_free_box (compr_buf);
	      backuped = page;
	      ch_c++;
	      backup_status.processed_pages = ++octx->octx_page_count;
	      dp_set_backup_flag (wi_inst.wi_master, buf->bd_page, 0);
	      if (buf->bd_physical_page && buf->bd_physical_page != buf->bd_page)
		dp_set_backup_flag (wi_inst.wi_master, buf->bd_physical_page, 0);
	      backup_context_flush (octx);
	      if (!octx->octx_disable_increment && (0 == octx->octx_page_count % octx->octx_max_pages))
		{
		  if (backup_context_increment (octx,0) < 0)
		    return -1;
		  ol_write_header (octx);
		  backup_context_flush(octx);
		  return backuped;
		}
	    }
	  FAILED
	    {
	      FTRUNCATE (tcpses_get_fd (octx->octx_file->dks_session), prev_length);
	      if (try_to_change_dir (octx))
		{
		  write_header_first = 1;
		  goto again;
		}
	      octx->octx_is_invalid = 1;
	      return -1;
	    }
	  END_WRITE_FAIL (octx->octx_file);
	}
      else
	{
	  make_log_error ((ol_backup_context_t*) ctx, COMPRESS_ERR_CODE, COMPRESS_ERR_STR, page);
	  octx->octx_is_invalid = 1;
	  return -1;
	}
    }
  return backuped;
}


void
ol_save_context (ol_backup_context_t * ctx)
{
  session_flush_1 (ctx->octx_file);
}


static int
is_in_backup_set  (ol_backup_context_t * octx, dp_addr_t page)
{
  uint32* array;
  int inx, bit;
  dp_addr_t array_page;
  int32 x;
  if (octx->octx_is_invalid)
    return 0;

  IN_DBS (octx->octx_dbs);
  dbs_locate_page_bit (octx->octx_dbs, &octx->octx_dbs->dbs_incbackup_set,
		       page, &array, &array_page, &inx, &bit, V_EXT_OFFSET_INCB_SET, 1);
  x = (array[inx] & (1 << bit));
  LEAVE_DBS (octx->octx_dbs);
  if (x)
    return 1;
  return 0;
}





dp_addr_t
db_backup_pages (ol_backup_context_t * backup_ctx, dp_addr_t start_dp, dp_addr_t end_dp)
{
  ALIGNED_PAGE_BUFFER (bd_buffer);
  buffer_desc_t stack_buf;
  buffer_desc_t *buf = &stack_buf;
  dp_addr_t end_page;
  dp_addr_t page_no;
  dbe_storage_t * storage = wi_inst.wi_master;
  stack_buf.bd_buffer = bd_buffer;


  if (!start_dp)
    start_dp = 1;
  end_page = backup_ctx->octx_last_page;

  log_info("Starting online backup from page %ld to %ld", start_dp, end_page);

  for (page_no = start_dp; page_no < end_page; page_no++)
    {
      dp_addr_t log_page = 0;
      if (0 == page_no%10000)
	log_info("Backing up page %ld", page_no);
      if (page_no == end_page - 1)
	goto backup; /* must always write this to make sure restored is at least as long as original */
      if (gethash (DP_ADDR2VOID(page_no), backup_ctx->octx_dbs->dbs_cpt_remap))
	continue; /* there is a cpt remap page for this, so do not write this */
      log_page = (uptrlong) gethash (DP_ADDR2VOID(page_no), backup_ctx->octx_cpt_remap_r);
      if (!is_in_backup_set (backup_ctx, log_page ? log_page : page_no))
	continue;
    backup:
      if (obackup_trace)
	fprintf (obackup_trace, "W L=%ld P=%ld\n", (long)log_page, (long)page_no);
      buf->bd_page = log_page ? log_page : page_no;
	  buf->bd_physical_page = page_no;
	  buf->bd_storage = storage;

	  if (WI_ERROR == ol_buf_disk_read (buf))
	    make_log_error (backup_ctx, READ_ERR_CODE, READ_ERR_STR, page_no);
	  else
	    {
	      ol_backup_page (NULL, buf, backup_ctx);
	      if (backup_ctx->octx_is_invalid)
		return -1;
	    }
    }

  /* these ones will be always written to the end backup file */
  if (-1 == ol_write_sets (backup_ctx, storage))
    return -1;
  if (-1 == ol_write_registry (backup_ctx->octx_dbs, backup_ctx, ol_backup_page))
    return -1;

  return 0;
}


void
backup_context_flush (ol_backup_context_t * ctx)
{
  session_flush_1 (ctx->octx_file);
}


void
backup_context_free (ol_backup_context_t * ctx)
{
  buffer_desc_t * incset  = ctx->octx_incset;
  if (ctx->octx_file)
    {
      fd_close (tcpses_get_fd (ctx->octx_file->dks_session),ctx->octx_curr_file);
      PrpcSessionFree (ctx->octx_file);
    }

  dk_free_box (ctx->octx_error_code);
  dk_free_box (ctx->octx_error_string);
  buffer_set_free (incset);
  dk_free_tree (list_to_array (ctx->octx_backup_files));
  buffer_set_free (ctx->octx_free_set);
  buffer_set_free (ctx->octx_ext_set);
  buffer_set_free (ctx->octx_cpt_set);
  dk_free_tree ((caddr_t) ctx->octx_registry);
  if (ctx->octx_cpt_remap_r)
    hash_table_free (ctx->octx_cpt_remap_r);
  dk_free (ctx, sizeof (ol_backup_context_t));
}

int
backup_context_increment (ol_backup_context_t* ctx, int is_restore)
{
  int fd;
  /* needed for marking backup file RW under XP/2000 */
  char curr_file[FILEN_BUFSIZ];
  long new_num = ctx->octx_num + 1;

  ctx->octx_is_tail = 0;
  memcpy (curr_file, ctx->octx_curr_file, FILEN_BUFSIZ);

 again:
  snprintf (ctx->octx_curr_file, FILEN_BUFSIZ, "%s/%s%ld.bp", ctx->octx_backup_patha[ctx->octx_curr_dir], ctx->octx_file_prefix, new_num);
  fd = fd_open (ctx->octx_curr_file,
		is_restore ? OPEN_FLAGS_RO : (OPEN_FLAGS | O_TRUNC));

  if (fd >= 0)
    {
      ctx->octx_num = new_num;
      dk_set_push (&ctx->octx_backup_files, box_string (ctx->octx_curr_file));
      if (ctx->octx_file)
	{
	  session_flush_1 (ctx->octx_file);
	  ctx->octx_wr_bytes += ctx->octx_file->dks_bytes_sent;
	  dir_first_page = ctx->octx_curr_page;
	  fd_close (tcpses_get_fd (ctx->octx_file->dks_session), curr_file);
	  tcpses_set_fd (ctx->octx_file->dks_session, fd);
	  ctx->octx_file->dks_bytes_sent = 0;
	}
      else
	{
	  ctx->octx_file = dk_session_allocate (SESCLASS_TCPIP);
	  tcpses_set_fd (ctx->octx_file->dks_session, fd);
	}
    }
  else
    {
      if (is_restore && (++ctx->octx_curr_dir < BOX_ELEMENTS (ctx->octx_backup_patha)) )
	goto again;
      ctx->octx_is_invalid = 1;
      return -1;
    }
  if (!is_restore)
    ctx->octx_wr_bytes = 0;
  return fd;
}


void
store_backup_context (ol_backup_context_t* ctx)
{
  /* log_info ("clear hash"); */
  clrhash (ctx->known);
  strncpy ( bp_ctx.db_bp_prfx, ctx->octx_file_prefix, BACKUP_PREFIX_SZ);
  bp_ctx.db_bp_ts = ctx->octx_timestamp;
  bp_ctx.db_bp_num = ctx->octx_num;
  bp_ctx.db_bp_pages = ctx->octx_page_count;
  bp_ctx.db_bp_date = (dp_addr_t) db_bp_date;
  bp_ctx.db_bp_index = ctx->octx_curr_dir;
  bp_ctx.db_bp_wr_bytes = ctx->octx_wr_bytes;
}

int
try_to_restore_backup_context (ol_backup_context_t* ctx)
{
  if (!bp_ctx.db_bp_ts)
    return 0;
  else
    {
      char * ts_str;

      strncpy (ctx->octx_file_prefix,  bp_ctx.db_bp_prfx, BACKUP_PREFIX_SZ);
      ctx->octx_timestamp =  bp_ctx.db_bp_ts;
      ctx->octx_num = bp_ctx.db_bp_num;
      /* ctx->octx_page_count = bp_ctx.db_bp_pages; */
      ctx->octx_page_count = 0;
      ctx->octx_curr_dir = bp_ctx.db_bp_index;
      ctx->octx_wr_bytes = bp_ctx.db_bp_wr_bytes;

      ts_str = format_timestamp (&ctx->octx_timestamp);

#ifdef DEBUG
      log_info ("Found backup info - prefix[%s], ts[%s], num[%ld], diridx[%ld]",
		ctx->octx_file_prefix, ts_str, ctx->octx_num, ctx->octx_curr_dir);
#endif
      dk_free_box (ts_str);

      return 1;
    }
}

ol_backup_context_t*
backup_context_allocate(const char* fileprefix,
	long pages, long timeout, caddr_t* backup_path_arr, caddr_t *err_ret)
{
  ol_backup_context_t* ctx;
  int fd;
  int restored;

  if (pages < MIN_BACKUP_PAGES)
    {
      *err_ret = srv_make_new_error ("42000", PAGE_NUMBER_ERR_CODE, "Number of backup pages is less than %ld", (long)MIN_BACKUP_PAGES);
      return NULL;
    }

  if (timeout < 0)
    {
      *err_ret = srv_make_new_error ("42000", TIMEOUT_NUMBER_ERR_CODE, "Timeout can not be negative");
      return NULL;
    }

  if (strlen(fileprefix) > FILEN_BUFSIZ)
    {
      *err_ret = srv_make_new_error ("42000", FILE_SZ_ERR_CODE, "Prefix name too long");
      return NULL;
    }

  ctx = (ol_backup_context_t*) dk_alloc (sizeof (ol_backup_context_t));
  memset (ctx, 0, sizeof (ol_backup_context_t));
  ctx->octx_backup_patha = backup_path_arr;
  ctx->octx_max_wr_bytes = (OFF_T) ol_max_dir_sz;
  if (!ol_known_pages)
    ol_known_pages = hash_table_allocate (101);
  ctx->known = ol_known_pages;

  ctx->octx_max_pages = pages;

  ctx->octx_incset = incset_make_copy (wi_inst.wi_master->dbs_incbackup_set);
  restored = try_to_restore_backup_context (ctx);

  if (!restored)
    memcpy (ctx->octx_file_prefix, fileprefix, strlen (fileprefix));

  fd = backup_context_increment (ctx,0);

  if (fd >= 0)
    {
      ctx->octx_dbs = wi_inst.wi_master;
      if (!restored)
	ctx->octx_timestamp = sqlbif_rnd (&rnd_seed_b) + approx_msec_real_time ();

      ctx->octx_cpt_remap_r = hash_reverse (ctx->octx_dbs->dbs_cpt_remap);
      if (!ctx->octx_cpt_remap_r)
	GPF_T1 ("wrong hash table");

      if (timeout)
	ctx->octx_deadline = get_msec_real_time () + timeout;
      ctx->octx_last_page = ctx->octx_dbs->dbs_n_pages;

      return ctx;
    }
  else
    {
      dk_free (ctx, sizeof (ol_backup_context_t));
      *err_ret = srv_make_new_error ("42000", BACKUP_FILE_CR_ERR_CODE, "Could not create backup file %s", ctx->octx_curr_file);
      return NULL; /* keeps compiler happy */
    }
}

#define CHECK_ERROR(ctx, error) \
	if (ctx->octx_error) \
	  goto error;

#define LOG_ERROR(ctx, x, error) \
	log_error x; \
	ctx->octx_error = 1;\
	ctx->octx_error_string = make_error_string x; \
	ctx->octx_error_code = box_string (FILE_ERR_CODE); \
	goto error;

static
char * make_error_string (char * msg, ...)
{
  char * message;
  char buf[1025];
  va_list list;

  va_start (list, msg);
  vsnprintf (buf, 1024, msg, list);
  va_end (list);

  message = dk_alloc_box (strlen (buf)+1, DV_STRING);
  strcpy_box_ck (message, buf);

  return message;
}

static
void make_log_error (ol_backup_context_t* ctx, const char* code, const char* msg, ...)
{
  char temp[2000];
  char* buf = temp;
  va_list list;

  if (ctx->octx_error)
    return;

  buf[0]='['; buf++;
  strcpy_size_ck (buf, code, sizeof (temp) - (buf - temp));
  buf+=strlen(code);
  buf[0]=']'; buf[1]=' '; buf+=2;

  va_start (list, msg);
  vsnprintf (buf, sizeof (temp) - (buf - temp), msg, list);
  va_end (list);

#ifdef TEST_ERR_REPORT
  log_error (temp);
  return;
#endif

  ctx->octx_error = 1;
  ctx->octx_error_code = box_string (code);
  ctx->octx_error_string = box_string (temp);
  log_error (temp);

  return;
}

#ifdef TEST_ERR_REPORT
caddr_t
bif_test_error (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ol_backup_context_t * ctx = dk_alloc (sizeof (ol_backup_context_t));
  memset (ctx, 0, sizeof (ol_backup_context_t));

  make_log_error (ctx, COMPRESS_ERR_CODE, COMPRESS_ERR_STR, 14);
  make_log_error (ctx, READ_ERR_CODE, READ_ERR_STR, 14);
  make_log_error (ctx, STORE_CTX_ERR_CODE, STORE_CTX_ERR_STR);
  make_log_error (ctx, READ_CTX_ERR_CODE, READ_CTX_ERR_STR);

  return NEW_DB_NULL;
}
#endif
#ifdef INC_DEBUG
caddr_t
bif_backup_rep (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char temp [128];
  long cnt = 0;
  dk_hash_iterator_t hit;
  ptrlong k,v;
  dbe_storage_t * dbs = wi_inst.wi_master;
  dp_addr_t page = dbs->dbs_cp_remap_pages ? (dp_addr_t) (unsigned long) dbs->dbs_cp_remap_pages->data : 0;


  for (dk_hash_iterator (&hit, wi_inst.wi_master->dbs_cpt_remap);
       dk_hit_next (&hit, (void**) &k, (void**) &v);
       /* */)
    {
      cnt++;
    }

  snprintf (temp, sizeof (temp), "remap pages = %ld [%ld]", cnt, page);
  return box_dv_short_string (temp);
}
#endif

static int try_to_change_dir (ol_backup_context_t * ctx)
{
  if (((ctx->octx_curr_dir)+1) < BOX_ELEMENTS (ctx->octx_backup_patha))
    {
      ++ctx->octx_curr_dir;
      if (0 < backup_context_increment (ctx, 0))
	return 1;
    }
  return 0;
}

#define OB_IN_CPT(need_mtx,qi) \
  if (need_mtx) \
    IN_CPT (qi->qi_trx); \
  else \
    { \
      IN_TXN; \
      lt_threads_dec_inner (qi->qi_trx); \
      LEAVE_TXN; \
    }

#define OB_LEAVE_CPT(need_mtx,qi) \
      if (need_mtx) \
	{ \
	  IN_TXN; \
	  cpt_over (); \
	  LEAVE_TXN; \
	  LEAVE_CPT(qi->qi_trx); \
	} \
      else \
	{ \
	  IN_TXN; \
	  lt_threads_inc_inner (qi->qi_trx); \
	  LEAVE_TXN; \
	}

#define OB_LEAVE_CPT_1(need_mtx,qi) \
      if (need_mtx) \
	{ \
	  LEAVE_CPT(qi->qi_trx); \
	} \
      else \
	{ \
	  IN_TXN; \
	  lt_threads_inc_inner (qi->qi_trx); \
	  LEAVE_TXN; \
	}

long ol_backup (const char* prefix, long pages, long timeout, caddr_t* backup_path_arr, query_instance_t *qi)
{
  dbe_storage_t * dbs = wi_inst.wi_master;
  dk_session_t * ses;
  int need_mtx = !srv_have_global_lock(THREAD_CURRENT_THREAD);
  ol_backup_context_t * ctx;
  long _pages;
  buffer_desc_t *cfg_buf = buffer_allocate (DPF_CP_REMAP);
  wi_database_t db;
  char * log_name;
  caddr_t err = NULL;

  OB_IN_CPT (need_mtx,qi);
  log_name = sf_make_new_log_name (wi_inst.wi_master);
  IN_TXN;
  dbs_checkpoint (log_name, CPT_INC_RESET);
  cpt_over ();
  LEAVE_TXN;

  cfg_buf->bd_page = cfg_buf->bd_physical_page = 0;
  cfg_buf->bd_storage = wi_inst.wi_master;
  if (WI_ERROR == ol_buf_disk_read (cfg_buf))
    GPF_T1 ("obackup can't read cfg page");
  memcpy (&db, cfg_buf->bd_buffer, sizeof (wi_database_t));
  buffer_free (cfg_buf);
  ctx = backup_context_allocate (prefix, pages, timeout, backup_path_arr, &err);
  if (err)
    {
      OB_LEAVE_CPT_1 (need_mtx,qi);
      sqlr_resignal (err);
    }
  ctx->octx_dbs = wi_inst.wi_master;
  _pages = ctx->octx_page_count;

  ctx->octx_free_set = dbs_read_page_set (dbs, db.db_free_set, DPF_FREE_SET);
  ctx->octx_ext_set = dbs_read_page_set (dbs, db.db_extent_set, DPF_EXTENT_SET);
  if (db.db_checkpoint_map)
    ctx->octx_cpt_set = dbs_read_page_set (dbs, db.db_checkpoint_map, DPF_CP_REMAP);
#if 0
  obackup_trace = fopen ("obackup.out", "a");
  fprintf (obackup_trace, "\n\n\Bakup file %s\n", "xx");
#endif
  ses = dbs_read_registry (ctx->octx_dbs, qi->qi_client);
  ctx->octx_registry = (caddr_t *) read_object (ses);
  dk_free_box ((caddr_t)ses);
  memset (&backup_status, 0, sizeof (backup_status_t));
  backup_status.is_running = 1;
  backup_status.pages = dbs_count_incbackup_pages (wi_inst.wi_master);

  time (&db_bp_date);
  dir_first_page = 0;
  CATCH_WRITE_FAIL (ctx->octx_file)
    {
      ol_write_header (ctx);
      backup_context_flush (ctx);
    }
  FAILED
    {
      LOG_ERROR (ctx, ("Backup file [%s] writing error", ctx->octx_curr_file), error);
    }
  db_backup_pages (ctx, 0, 0);
  CHECK_ERROR (ctx, error);

  /* flushed, so out_fill does not needed */
  ctx->octx_wr_bytes += ctx->octx_file->dks_bytes_sent;

  store_backup_context (ctx);
  CHECK_ERROR (ctx, error);

  ol_write_cfg_page (ctx);
  CHECK_ERROR (ctx, error);

  store_backup_context (ctx);
  CHECK_ERROR (ctx, error);
  IN_DBS (dbs);
  dbs_write_page_set (dbs, dbs->dbs_incbackup_set);
  LEAVE_DBS (dbs);

  if (obackup_trace)
    {
      fflush (obackup_trace);
      fclose (obackup_trace);
      obackup_trace = NULL;
    }
  log_info ("Backed up pages: [%ld]", ctx->octx_page_count - _pages);
#ifdef DEBUG
  log_info ("Log = %s", wi_inst.wi_master->dbs_log_name);
#endif

  OB_LEAVE_CPT_1 (need_mtx,qi);
  _pages = ctx->octx_page_count - _pages;
  backup_context_free(ctx);
  backup_status.is_running = 0;
  return _pages;

 error:
  db_bp_date = 0;
  incset_rollback (ctx);
  ctx_clear_backup_files (ctx);

  strncpy (backup_status.errcode, ctx->octx_error_code, 100);
  strncpy (backup_status.errstring, ctx->octx_error_string, 1024);
  backup_status.is_error = 1;
  backup_status.is_running = 0;

  OB_LEAVE_CPT_1 (need_mtx,qi);
  backup_context_free (ctx);

  sqlr_new_error ("42000", backup_status.errcode, "%s", backup_status.errstring);
  return 0; /* keeps compiler happy */
}


void bp_sec_user_check (query_instance_t * qi)
{
  if (!sec_user_has_group_name ("BACKUP", qi->qi_u_id) &&
      !sec_user_has_group_name ("dba", qi->qi_u_id))
    {
      user_t *u = sec_id_to_user (qi->qi_u_id);
      sqlr_new_error ("42000", USER_PERM_ERR_CODE , "user %s is not authorized to make online backup", u->usr_name);
    }
}

void
bp_sec_check_prefix (query_instance_t * qi, char *file_prefix)
{
  char * s;

  if (!file_prefix[0])
    sqlr_new_error ("42000", FILE_FORM_ERR_CODE , "Backup prefix must contains at least one char");

  if (file_prefix[0] == '/')
    sqlr_new_error ("42000", FILE_FORM_ERR_CODE, "Absolute path as backup prefix is not allowed");

  s = strchr (file_prefix, ':');
  if (s)
    sqlr_new_error ("42000", FILE_FORM_ERR_CODE , "Semicolon in backup prefix is not allowed");

    s = strchr (file_prefix, '.');
  while (s)
    {
      if (s[1] == '.')
      sqlr_new_error ("42000", FILE_FORM_ERR_CODE , "\"..\" substring in backup prefix is not allowed");
      s = strchr (s + 1, '.');
    }
}


static
caddr_t bif_backup_report (caddr_t* qst, caddr_t* err_ret, state_slot_t** args)
{
  dk_set_t s = 0;

  dk_set_push (&s, box_string ("seq"));
  dk_set_push (&s, box_num (bp_ctx.db_bp_num));
  dk_set_push (&s, box_string ("done"));
  dk_set_push (&s, box_num (backup_status.processed_pages));
  dk_set_push (&s, box_string ("all"));
  dk_set_push (&s, box_num (backup_status.pages));
  return list_to_array (dk_set_nreverse (s));
}



static
caddr_t* bif_backup_dirs_arg (caddr_t* qst, state_slot_t** args, int num, const char* func_name)
{
  caddr_t * ba = (caddr_t*) bif_arg (qst, args, num, func_name);
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (ba))
    {
      int inx;
      DO_BOX (caddr_t, elt, inx, ba)
	{
	  if (!IS_STRING_DTP(DV_TYPE_OF(elt)))
	    goto err;
	}
      END_DO_BOX;
      return ba;
    }
 err:
  sqlr_new_error ("42001", BACKUP_DIR_ARG_ERR_CODE, "The argument %d of %s must be array of strings", num+1, func_name);
  return 0; /* keeps compiler happy */
}

caddr_t
bif_backup_online (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t file_prefix;
  long pages ;
  long timeout = 0;
  long res = 0;
  caddr_t * backup_path_arr = backup_patha;
  ob_err_ctx_t e_ctx;
  memset (&e_ctx, 0, sizeof (ob_err_ctx_t));
  QI_CHECK_STACK (qi, &qi, OL_BACKUP_STACK_MARGIN);
  QR_RESET_CTX
    {
      file_prefix = bif_string_arg (qst, args, 0, "backup_online");
      pages = (long) bif_long_arg (qst, args, 1, "backup_online");

      bp_sec_user_check (qi);
      bp_sec_check_prefix (qi, file_prefix);

/*	timeout feature disabled */
/*      if (BOX_ELEMENTS (args) > 2)
	timeout = (long) bif_long_arg (qst, args, 2, "backup_online"); */
      if (BOX_ELEMENTS (args) > 3)
	backup_path_arr = bif_backup_dirs_arg (qst, args, 3, "backup_online");

      if (-1 == ob_foreach_dir (backup_path_arr, file_prefix, &e_ctx, ob_check_file))
	sqlr_new_error ("42000", DIR_CLEARANCE_ERR_CODE, "directory %s contains backup file %s, backup aborted", backup_path_arr[e_ctx.oc_inx], e_ctx.oc_file);

      ch_c = cm_c = 0;
      res = ol_backup (file_prefix, pages, timeout, backup_path_arr, qi);
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      caddr_t* err = (caddr_t*) thr_get_error_code (self);
      POP_QR_RESET;

      if ((DV_TYPE_OF (err) == DV_ARRAY_OF_POINTER) &&
	  BOX_ELEMENTS (err) == 3)
	{
	  backup_status.is_error = 1;
	  strncpy (backup_status.errcode, err[1], 100);
	  strncpy (backup_status.errstring, err[2], 1024);
	}
      sqlr_resignal ((caddr_t)err);
    }
  END_QR_RESET;
  return box_num (res);
}


static
int ob_unlink_file (caddr_t elt, caddr_t ctx, caddr_t dir)
{
  if (0 < ob_get_num_from_file (elt, ctx))
    {
      char path[PATH_MAX+1];
      char *path_tail = path;
      memset (path, 0, PATH_MAX+1);
      if ((strlen (dir) + strlen (elt) + 1)>PATH_MAX)
	return -1;
      strcpy (path, dir);
      path_tail = path + strlen(path);
      *path_tail = '/'; ++path_tail;
      while (elt[0])
	*(path_tail++) = *(elt++);
      unlink (path);
    }
  return 0;
}

static caddr_t
bif_backup_dirs_clear (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t * dirs = backup_patha;
  caddr_t prefix = bif_string_arg (qst, args, 0, "backup_dirs_clear");
  ob_err_ctx_t e_ctx;
  memset (&e_ctx, 0, sizeof (ob_err_ctx_t));

  if (BOX_ELEMENTS (args) > 1)
    dirs = bif_backup_dirs_arg (qst, args, 1, "backup_dirs_clear");

  ob_foreach_dir (dirs, prefix, &e_ctx, ob_unlink_file);
  return NEW_DB_NULL;
}

static caddr_t
bif_backup_def_dirs (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_copy_tree ((box_t) backup_patha);
}


static caddr_t
bif_backup_context_clear (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t*) qst;
  dbe_storage_t * dbs = wi_inst.wi_master;
  int make_cp = 1;
  int need_mtx = !srv_have_global_lock(THREAD_CURRENT_THREAD);

  if (BOX_ELEMENTS (args) > 0)
    make_cp = (int) bif_long_arg (qst, args, 0, "backup_context_clear");


  bp_sec_user_check (qi);

  OB_IN_CPT (need_mtx, qi);

  memset (&bp_ctx, 0, sizeof (ol_backup_ctx_t));

    {
      char * log_name = sf_make_new_log_name (wi_inst.wi_master);
      IN_TXN;
      dbs_checkpoint (log_name, CPT_INC_RESET);
      LEAVE_TXN;
    }
  {
    buffer_desc_t * is = dbs->dbs_incbackup_set;
    buffer_desc_t * fs = dbs_read_page_set (wi_inst.wi_master, wi_inst.wi_master->dbs_free_set->bd_page, DPF_FREE_SET);
    while (fs && is)
      {
	memcpy (is->bd_buffer + DP_DATA, fs->bd_buffer + DP_DATA, PAGE_DATA_SZ);
	page_set_checksum_init (is->bd_buffer + DP_DATA);
	fs = fs->bd_next;
	is = is->bd_next;
      }
    if (fs || is)
      log_error ("free set and incbackup set were found of uneven length in reset of backup ctx.  Only partly done.  Should restore db from crash dump.");

    ol_write_registry (wi_inst.wi_master, NULL, ol_regist_unmark);
    {
      dk_hash_iterator_t hit;
      void *dp, *remap_dp;
      dk_hash_iterator (&hit, dbs->dbs_cpt_remap);
      while (dk_hit_next (&hit, &dp, &remap_dp))
	dp_set_backup_flag (dbs, (dp_addr_t) (ptrlong) remap_dp, 0);
    }

    /* cp remap pages will be ignored, so do not leave trash
       for dbs_count_pageset_items_2 */
    DO_SET (caddr_t, _page, &dbs->dbs_cp_remap_pages)
      {
	dp_set_backup_flag (dbs, (dp_addr_t)(ptrlong) _page, 0);
      }
    END_DO_SET();
    buffer_set_free (fs);
  }
  dbs_write_page_set (dbs, dbs->dbs_incbackup_set);
  dbs_write_cfg_page (dbs, 0);
  OB_LEAVE_CPT (need_mtx, qi);

    return NEW_DB_NULL;
}


static caddr_t
bif_backup_context_info_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t param_name = bif_string_arg (qst, args, 0, "backup_context_info_get");
  caddr_t param = 0;
  /* param parsing section */
  if (!stricmp (param_name, "prefix"))
    param = bp_curr_prefix();
  else if (!stricmp (param_name, "date"))
    param = bp_curr_date ();
  else if (!stricmp (param_name, "ts"))
    param = bp_curr_timestamp ();
  else if (!stricmp (param_name, "num"))
    return bp_curr_num (); /* zero is allowed, so return here */
  else if (!stricmp (param_name, "dir_inx"))
    return bp_curr_inx ();
  else if (!stricmp (param_name, "run"))
    return box_num (backup_status.is_running);
  else if (!stricmp (param_name, "errorc"))
    {
      if (backup_status.is_error)
	return box_string (backup_status.errcode);
      else
	return NEW_DB_NULL;
    }
  else if (!stricmp (param_name, "errors"))
    {
      if (backup_status.is_error)
	return box_string (backup_status.errstring);
      else
	return NEW_DB_NULL;
    }

  if (param)
    return param;
  else
    return NEW_DB_NULL;
}

static caddr_t
bif_backup_online_header_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * fileprefix = bif_string_arg (qst, args, 0, "backup_online_header_get");
  long num = (long) bif_long_arg (qst, args, 1, "backup_online_header_get") - 1;
  ol_backup_context_t* ctx;
  char * header = 0;
  int fd;

  if (box_length (fileprefix) - 1 > BACKUP_PREFIX_SZ)
    sqlr_new_error ("42000", FILE_SZ_ERR_CODE , "file prefix too long");

  ctx = (ol_backup_context_t*) dk_alloc (sizeof (ol_backup_context_t));
  memset (ctx, 0, sizeof (ol_backup_context_t));

  memcpy (ctx->octx_file_prefix, fileprefix, strlen (fileprefix));
  ctx->octx_num = num;

  fd = backup_context_increment (ctx,1);
  if (fd < 0)
    goto fin;

  CATCH_READ_FAIL (ctx->octx_file)
    {
      read_backup_header (ctx, &header);
    }
  FAILED
    {
    }
  END_READ_FAIL (ctx->octx_file);

 fin:
  backup_context_free (ctx);
  if (header)
    return header;
  sqlr_new_error ("42000", FILE_OPEN_ERR_CODE , "could not open backup file with prefix %s num %ld", fileprefix, num);
  return 0; /* keeps compiler happy */
}


/* restore */



ol_backup_context_t*
restore_context_allocate(const char* fileprefix)
{
  ol_backup_context_t* ctx;
  int fd;

  ctx = (ol_backup_context_t*) dk_alloc (sizeof (ol_backup_context_t));
  memset (ctx, 0, sizeof (ol_backup_context_t));

  memcpy (ctx->octx_file_prefix, fileprefix, strlen (fileprefix));
  ctx->octx_backup_patha = backup_patha;

  fd = backup_context_increment (ctx,1);

  if (fd > 0)
    {
      int db_exists = 0;
      db_read_cfg (NULL, "-r");

      cp_buf = buffer_allocate (DPF_CP_REMAP);

      ctx->octx_dbs = dbs_from_file ("master", NULL, DBS_RECOVER, &db_exists);
      if (db_exists)
	{
	  log_error ("Remove database file before recovery");
	  /* leak, but program shuts down anyway */
	  return 0;
	}
      return ctx;
    }
  else
    {
      dk_free (ctx, sizeof (ol_backup_context_t));
      return NULL;
    }
}


void
buf_disk_raw_write (buffer_desc_t* buf)
{
  dbe_storage_t* dbs = buf->bd_storage;
  dp_addr_t dest = buf->bd_physical_page;
  OFF_T off;
  OFF_T rc;
  if (!IS_IO_ALIGN (buf->bd_buffer))
    GPF_T1 ("buf_disk_raw_write (): The buffer is not io-aligned");
  if (dbs->dbs_disks)
    {
      disk_stripe_t *dst;
      int fd;
      OFF_T rc;

      IN_DBS (dbs);
      while (dest >= dbs->dbs_n_pages)
	{
	  rc = dbs_seg_extend (dbs, EXTENT_SZ);
	  if (rc != EXTENT_SZ)
	    {
	      log_error ("Cannot extend database, please free disk space and try again.");
	      call_exit (-1);
	    }
	}
      LEAVE_DBS (dbs);

      dst = dp_disk_locate (dbs, dest, &off);
      fd = dst_fd (dst);

      rc = LSEEK (fd, off, SEEK_SET);
      if (rc != off)
	{
	  log_error ("Seek failure on stripe %s rc=" BOXINT_FMT " errno=%d off=" BOXINT_FMT ".", dst->dst_file, rc, errno, off);
	  GPF_T;
	}
      rc = write (fd, buf->bd_buffer, PAGE_SZ);
      if (rc != PAGE_SZ)
	{
	  log_error ("Write failure on stripe %s", dst->dst_file);
	  GPF_T;
	}
      dst_fd_done (dst, fd);
    }
  else
    {
      OFF_T off_dest = ((OFF_T) dest) * PAGE_SZ;
      if (off_dest >= dbs->dbs_file_length)
	{
	  /* Fill the gap. */
	  LSEEK (dbs->dbs_fd, 0, SEEK_END);
	  while (dbs->dbs_file_length <= off_dest)
	    {
	      if (PAGE_SZ != write (dbs->dbs_fd, (char *)(buf->bd_buffer),
		      PAGE_SZ))
		{
		  log_error ("Write failure on database %s", dbs->dbs_file);
		  GPF_T;
		}
	      dbs->dbs_file_length += PAGE_SZ;
	    }
	}
      else
	{
	  off = ((OFF_T)buf->bd_physical_page) * PAGE_SZ;
	  if (off != (rc = LSEEK (dbs->dbs_fd, off, SEEK_SET)))
	    {
	      log_error ("Seek failure on database %s rc=" BOXINT_FMT " errno=%d off=" BOXINT_FMT ".", dbs->dbs_file, rc, errno, off);
	      GPF_T;
	    }
	  rc = write (dbs->dbs_fd, (char *)(buf->bd_buffer), PAGE_SZ);
	  if (rc != PAGE_SZ)
	    {
	      log_error ("Write failure on database %s", dbs->dbs_file);
	      GPF_T;
	    }
	}
    }
}

int ob_just_report = 0;

static int
read_backup_header (ol_backup_context_t* ctx, char ** header)
{
  long len;
  char prefix[FILEN_BUFSIZ];
  uint32 timestamp;
  char * ts_str;
  long num;

  /* prefix */

  len = read_long (ctx->octx_file);

  if ((len == -1) || (len >= FILEN_BUFSIZ))
    {
      log_error ("Backup file %s is corrupted", ctx->octx_curr_file);
      return 0;
    }

  session_buffered_read (ctx->octx_file, prefix, len);
  prefix[len] = 0;

  if (!ob_just_report && strcmp (prefix, ctx->octx_file_prefix))
    {
      if (!header) log_error ("Prefix [%s] is wrong, should be [%s]", ctx->octx_file_prefix, prefix);
      return 0;
    }

  /* timestamp */
  timestamp = read_long (ctx->octx_file);
  if (!ctx->octx_timestamp)
    ctx->octx_timestamp = timestamp;
  else
    if (!ob_just_report && (timestamp != ctx->octx_timestamp))
      {
	if (!header)
	  log_error ("Timestamp [%lx] is wrong in file %s", timestamp, ctx->octx_curr_file);
	return 0;
      }

  /* number of this file */
  num = read_long (ctx->octx_file);
  if (!ob_just_report && (ctx->octx_num != num))
    {
      if (!header)
	log_error ("Number of file %s differs from internal number [%ld]", ctx->octx_curr_file, num);
      return 0;
    }

  /* size of all backup */
  ctx->octx_last_page = read_long (ctx->octx_file);

  ts_str = format_timestamp (&ctx->octx_timestamp);
  if (!header)
    log_info ("--> Backup file # %ld [%s]", num, ts_str);

  if (!header && ob_just_report)
    log_info ("----> %s %s %ld %ld", prefix, ts_str, num, ctx->octx_last_page);

  if (header)
    {
      char tmpstr_s[255];
      char * tmpstr = tmpstr_s;
      memset (tmpstr, 0, 255);
      memcpy (tmpstr, prefix, len);
      tmpstr+=len;
      *(tmpstr++) = ':';
      memcpy (tmpstr, ts_str, strlen (ts_str));
      tmpstr+=strlen(ts_str);
      *(tmpstr++) = ':';
      if (num > 999999)
	num = 999999;
      snprintf (tmpstr, 254 - strlen (tmpstr), "%ld", num);

      header[0] = box_dv_short_string (tmpstr_s);
    }
  dk_free_box (ts_str);
  return 1;
}

#ifdef DBG_BREAKPOINTS
static int ol_breakpoint()
{
  return  0;
}
#endif

static int
check_configuration (buffer_desc_t * buf)
{
  caddr_t page_buf = (caddr_t)buf->bd_buffer;
  wi_database_t db;
  memcpy (&db, page_buf, sizeof (wi_database_t));
  if (dbs_byte_order_cmp (db.db_byte_order))
    {
      log_error ("The backup was produced on a system with different byte order. Exiting.");
      return -1;
    }
  ((wi_database_t *)page_buf)->db_stripe_unit = buf->bd_storage->dbs_stripe_unit;
  return 0;
}

static int
insert_page (ol_backup_context_t* ctx, dp_addr_t page_dp)
{
  ALIGNED_PAGE_BUFFER (page_buf);
  buffer_desc_t buf;
  caddr_t compr_buf;

  compr_buf =  (caddr_t) read_object (ctx->octx_file);

  /* session_buffered_read (ctx->octx_file, page_buf, PAGE_SZ); */

  if (!compr_buf || (Z_OK != uncompress_buffer (compr_buf, page_buf)))
    log_error ("Could not recover page %ld from backup file %s", page_dp, ctx->octx_curr_file);

  buf.bd_page = buf.bd_physical_page = page_dp;
  buf.bd_buffer = page_buf;
  buf.bd_storage = ctx->octx_dbs;

  if (!page_dp) /* config page, check byte ordering */
    {
      if (-1 == check_configuration (&buf))
	return -1;
    }


  if (!ob_just_report)
    buf_disk_raw_write (&buf);
  else
    log_info ("-----> page %ld", page_dp);
  dk_free_box (compr_buf);
  return 0;
}

int restore_from_files (const char* prefix)
{
  ol_backup_context_t * ctx;
  int count = 0;
  int volatile hdr_is_read = 0;
  dp_addr_t page_dp = 0;

  backup_path_init ();

  ctx = restore_context_allocate (prefix);

  if (!ctx)
    {
      /* report error */
      log_error ("Could not restore database using prefix %s", prefix);
      return -1;
    }
  log_info ("Begin to restore with file prefix %s", ctx->octx_file_prefix);

  do
    {
    again:
      hdr_is_read = 0;
      CATCH_READ_FAIL (ctx->octx_file)
	{
	  if (read_backup_header (ctx, 0))
	    {
	      hdr_is_read = 1;
	      page_dp = read_long (ctx->octx_file);
	    }
	  else
	    {
	      log_error ("Unable to read backup file header, %s corrupted", ctx->octx_curr_file);
	      log_error ("Remove database file created by incomplete recovery");
	      backup_context_free (ctx);
	      return -1;
	    }
	}
      FAILED
	{
	  if (hdr_is_read == 0)
	    {
	      log_error ("Failed to restore from %s file after %ld pages", ctx->octx_curr_file, count);
	      backup_context_free (ctx);
	      return -1;
	    }
	  else
	    {
	      if (backup_context_increment (ctx,1) > 0)
		goto again;
	      goto end;
	    }
	}
      END_READ_FAIL (ctx->octx_file);

      while (1)
	{
	  if (-1 == insert_page (ctx, page_dp))
	    {
	      log_error ("Aborting");
	      backup_context_free (ctx);
	      return -1;
	    }

	  count++;
	  CATCH_READ_FAIL (ctx->octx_file)
	    {
	      page_dp = read_long (ctx->octx_file);
	    }
	  FAILED
	    {
	      if (backup_context_increment (ctx,1) > 0)
		goto again;
	      goto end;
	    }
	  END_READ_FAIL (ctx->octx_file);
	}
    } while (backup_context_increment (ctx,1) > 0);
 end:
  log_info ("End of restoring from backup, %ld pages", count);

  backup_context_free (ctx);

  return 0;
}

long dbs_count_incbackup_pages (dbe_storage_t * dbs);

static caddr_t
bif_backup_pages (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_num (dbs_count_incbackup_pages (wi_inst.wi_master));
}

static caddr_t
bif_checkpoint_pages (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int cc = 0;
  if (wi_inst.wi_master->dbs_cpt_remap)
    {
      dk_hash_iterator_t hit;
      ptrlong p, r;
      for (dk_hash_iterator (&hit, wi_inst.wi_master->dbs_cpt_remap);
	   dk_hit_next (&hit, (void **) &p, (void **) &r);
	   /* */)
	{
	  cc++;
	}
    }
  return box_num (cc);
}

static caddr_t
bif_backup_max_dir_size (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long sz = bif_long_arg (qst, args, 0, "backup_max_dir_size");
  ol_max_dir_sz = sz;
  return NEW_DB_NULL;
}

static caddr_t
bif_backup_check (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_set_t paths = 0;
  int inx = 0;
  caddr_t * patha, prefix;
  ob_err_ctx_t e_ctx;
  memset (&e_ctx, 0, sizeof (ob_err_ctx_t));

  while (inx < BOX_ELEMENTS (args))
    bif_string_arg (qst, args, inx++, "backup_check_test");
  inx = 0;
  prefix = bif_string_arg (qst, args, inx++, "backup_check_test");
  while (inx < BOX_ELEMENTS (args))
    dk_set_push (&paths, bif_string_arg (qst, args, inx++, "backup_check_test"));

  patha = (caddr_t*) list_to_array (dk_set_nreverse (paths));
  if (-1 == ob_foreach_dir (patha, prefix, &e_ctx, ob_check_file))
    {
      dk_free_box ((box_t) patha);
      sqlr_new_error ("42000", DIR_CLEARANCE_ERR_CODE, "directory %d contains backup file %s", e_ctx.oc_inx, e_ctx.oc_file);
    }
  return NEW_DB_NULL;
}

extern int acl_initilized;
extern void init_file_acl();
static void backup_path_init ()
{
  dk_set_t b_dirs = 0;

  if (!acl_initilized)
    init_file_acl();
  init_file_acl_set (backup_dirs, &b_dirs);

  if (b_dirs) /* +backup-paths xx1,xx2,xx3 */
    backup_patha = (caddr_t*) list_to_array (dk_set_nreverse (b_dirs));
  else
    {
      backup_patha = (caddr_t*) dk_alloc_box (sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      backup_patha [0] = box_string (".");
    }
}

char* backup_sched_get_info =
"create procedure \"BackupSchedInfo\" () {\n"
"  for select SE_START, SE_INTERVAL, SE_LAST_COMPLETED, SE_SQL\n"
"   from sys_scheduled_event\n"
"   where se_name = DB.DBA.BACKUP_SCHED_NAME ()\n"
"  do {\n"
"   return vector (SE_START, SE_INTERVAL, SE_LAST_COMPLETED, SE_SQL);\n"
"  }\n"
"  return NULL;\n"
"}";

char * backup_dir_tbl =
"create table DB.DBA.SYS_BACKUP_DIRS (	bd_id integer, \n"
"					bd_dir varchar not null, \n"
"					primary key (bd_id)) \n";

char * backup_proc0 =
"create procedure DB.DBA.BACKUP_SCHED_NAME ()\n"
"{\n"
"  return \'Backup Scheduled Task\';\n"
"}\n";

char * backup_proc1 =
"create procedure DB.DBA.BACKUP_MAKE (	in prefix varchar,\n"
"					in max_pages integer,\n"
"					in is_full integer) \n"
"{\n"
"  if (is_full) \n"
"    backup_context_clear();\n"
"  declare patha any;\n"
"  patha := null;\n"
"  for select bd_dir from DB.DBA.SYS_BACKUP_DIRS\n"
"	       order by bd_id\n"
"  do {	    \n"
"    if (patha is null)\n"
"      patha := vector (bd_dir);\n"
"    else\n"
"      patha := vector_concat (patha, vector (bd_dir));\n"
"  }\n"
"  \n"
"  if (patha is null)\n"
"    backup_online (prefix, max_pages);\n"
"  else\n"
"    backup_online (prefix, max_pages, 0, patha);\n"
"  if (__proc_exists ('DB.DBA.BACKUP_COMPLETED') is not null)\n"
"    DB.DBA.BACKUP_COMPLETED ();\n"
"  update DB.DBA.SYS_SCHEDULED_EVENT set\n"
"    SE_SQL = sprintf ('DB.DBA.BACKUP_MAKE (\\\'%s\\\', %d, 0)', prefix, max_pages)\n"
"   where SE_NAME = DB.DBA.BACKUP_SCHED_NAME ();\n"
"}\n";

void
backup_online_init (void)
{
  bif_define ("backup_online", bif_backup_online);
  bif_define ("backup_context_clear", bif_backup_context_clear);
  bif_define ("backup_context_info_get", bif_backup_context_info_get);
  bif_define ("backup_online_header_get", bif_backup_online_header_get);

#ifdef TEST_ERR_REPORT
  bif_define ("test_error", bif_test_error );
#endif
#ifdef INC_DEBUG
  bif_define ("backup_rep", bif_backup_rep);
#endif

  bif_define ("backup_pages", bif_backup_pages);
  bif_define ("cpt_remap_pages", bif_checkpoint_pages);

  /* test */
  bif_define ("backup_check", bif_backup_check);

  bif_define ("backup_max_dir_size", bif_backup_max_dir_size);
  bif_define ("backup_dirs_clear", bif_backup_dirs_clear);
  bif_define ("backup_def_dirs", bif_backup_def_dirs);
  bif_define ("backup_report", bif_backup_report);
  backup_path_init();
}

void
ddl_obackup_init (void)
{
  ddl_std_proc (backup_sched_get_info, 0);
  ddl_ensure_table ("DB.DBA.SYS_BACKUP_DIRS", backup_dir_tbl);
  ddl_ensure_table ("do this always", backup_proc0);
  ddl_ensure_table ("do this always", backup_proc1);
}

caddr_t compressed_buffer (buffer_desc_t* buf)
{
  z_stream c_stream; /* compression stream */
  int err;
  int comprLen = PAGE_SZ;
  Byte comp[PAGE_SZ*2];
  caddr_t ret_box;

  c_stream.zalloc = (alloc_func)0;
  c_stream.zfree = (free_func)0;
  c_stream.opaque = (voidpf)0;

  err = deflateInit(&c_stream, Z_DEFAULT_COMPRESSION);
  if (err != Z_OK)
    return 0;

  c_stream.next_in  = (Bytef*)buf->bd_buffer;
  c_stream.next_out = &comp[0];

  /*  while (c_stream.total_in != (uLong)len && c_stream.total_out < comprLen) */
    {
      c_stream.avail_in = PAGE_SZ;
      c_stream.avail_out = comprLen;
      err = deflate(&c_stream, Z_NO_FLUSH);
      if (err != Z_OK)
	return 0;
    }
  /* Finish the stream, still forcing small buffers: */
  for (;;)
    {
      c_stream.avail_out = 1;
      err = deflate(&c_stream, Z_FINISH);
      if (err == Z_STREAM_END)
	break;
      if (err !=Z_OK)
	return 0;
    }

  err = deflateEnd(&c_stream);
  if (err != Z_OK)
    return 0;

  ret_box = dk_alloc_box (c_stream.total_out, DV_BIN);
  memcpy (ret_box, comp, c_stream.total_out);

  return ret_box;
}

int
uncompress_buffer (caddr_t compr, unsigned char* page_buf)
{
  int err;
  z_stream d_stream; /* decompression stream */
  int compr_len = box_length (compr);

  d_stream.zalloc = (alloc_func)0;
  d_stream.zfree = (free_func)0;
  d_stream.opaque = (voidpf)0;

  d_stream.next_in  = (Bytef *) compr;
  d_stream.avail_in = 0;
  d_stream.next_out = page_buf;

  err = inflateInit(&d_stream);
  if (Z_OK != err)
    return err;

  /*  while (d_stream.total_out <= PAGE_SZ && d_stream.total_in <= compr_len) */
    {
      d_stream.avail_in = compr_len;
      d_stream.avail_out = PAGE_SZ;
      err = inflate(&d_stream, Z_NO_FLUSH);
      if (err == Z_STREAM_END)
	goto cont;
      if (err != Z_OK)
	return err;
      if (d_stream.total_out != PAGE_SZ)
	 GPF_T1 ("uncompressed buffer is not 8K");
    }

 cont:
  err = inflateEnd(&d_stream);
  if (err != Z_OK)
    return err;

  if (d_stream.total_out != PAGE_SZ)
    GPF_T1 ("Page is not recovered properly");

  return Z_OK;
}


/* transactions over incset */
static
buffer_desc_t * incset_make_copy (buffer_desc_t * incset_orig_buf)
{
  buffer_desc_t * incset_buf = buffer_allocate (~0);
  buffer_desc_t * incset_copy = incset_buf;
  buffer_desc_t * incset_prev_buf = incset_buf;
  memcpy (incset_buf->bd_buffer, incset_orig_buf->bd_buffer, PAGE_SZ);
  incset_orig_buf = incset_orig_buf->bd_next;

  while (incset_orig_buf)
    {
      incset_buf = buffer_allocate (~0);
      memcpy (incset_buf->bd_buffer, incset_orig_buf->bd_buffer, PAGE_SZ);
      incset_prev_buf->bd_next = incset_buf;
      incset_prev_buf = incset_buf;
      incset_orig_buf = incset_orig_buf->bd_next;
    }
  incset_buf->bd_next = 0;
  return incset_copy;
}

static
void incset_rollback (ol_backup_context_t* ctx)
{
  buffer_desc_t * buf = ctx->octx_incset;
  buffer_desc_t * incset = wi_inst.wi_master->dbs_incbackup_set;
  while (buf)
    {
      memcpy (incset->bd_buffer + DP_DATA, buf->bd_buffer + DP_DATA, PAGE_DATA_SZ);
      incset = incset->bd_next;
      buf = buf->bd_next;
    }
  return;
}

static
void ctx_clear_backup_files (ol_backup_context_t* ctx)
{
  DO_SET (caddr_t, file, &ctx->octx_backup_files)
    {
      int retcode = unlink (file);
      if (-1 == retcode)
	log_error ("Failed to unlink backup file %s", file);
    }
  END_DO_SET();
}

long
dbs_count_pageset_items_2 (dbe_storage_t * dbs, buffer_desc_t* pset)
{
  dk_hash_t * remaps = hash_table_allocate (dk_set_length (dbs->dbs_cp_remap_pages));
  int i_count = 0;
  dp_addr_t p_count = 0; /*pages*/
  DO_SET (void*, remap, &dbs->dbs_cp_remap_pages)
    {
      sethash (remap, remaps, (void*) 1);
    }
  END_DO_SET();
  while (pset)
    {
      size_t sz = PAGE_DATA_SZ;
      uint32 * ib_uint = (uint32*) (pset->bd_buffer + DP_DATA);

      while (sz)
	{
	  int idx;
	  for (idx = 0; idx < BITS_IN_LONG; idx++) /* since uint32 is used */
	    {
	      /* ignore zero page - it obviously goes to the backup */
	      if (!p_count++)
		continue;
	      /* cpt_remap pages does not go to backup */
	      if (gethash ((void*)((ptrlong)p_count - 1), remaps))
		continue;
	      if (p_count - 1 >= dbs->dbs_n_pages)
		goto fin;
	      if (ib_uint[0] & (1 << idx))
		{
		  i_count++;
		}
	    }
	  ib_uint++;
	  sz -= sizeof (uint32);
	}
      pset = pset->bd_next;
    }
 fin:
  hash_table_free (remaps);
  return i_count;
}

/* we make (I & B) to receive real page set ready to backup */
long dbs_count_incbackup_pages (dbe_storage_t * dbs)
{
  buffer_desc_t * incbps = incset_make_copy (dbs->dbs_incbackup_set);
  buffer_desc_t * ib_buf = incbps, * fs_buf = dbs->dbs_free_set;
  int n_pages = 0;
  long c;

  /*  printf ("--> %d %d\n", incbps->bd_page, incbps->bd_physical_page); */
  while (ib_buf)
    {
      uint32* ib_uint;
      uint32* fs_uint;
      size_t sz = PAGE_DATA_SZ;
      if (!fs_buf)
	break;

      ib_uint = (uint32*) (ib_buf->bd_buffer + DP_DATA);
      fs_uint = (uint32*) (fs_buf->bd_buffer + DP_DATA);

      while (sz)
	{
	  if (*ib_uint & ~*fs_uint)
	    log_error (
		"There are pages in the backup set that are actually free. "
	        "Should do backup_context_clear () and thus get a full backup. "
	        "This can indicate corruption around page %ld.",
		       (long) (n_pages * 8L * PAGE_DATA_SZ + (PAGE_DATA_SZ - sz) * 8));
	  ib_uint[0] &= fs_uint[0];
	  ib_uint++;
	  fs_uint++;
	  sz -= sizeof (uint32);
	}

      ib_buf = ib_buf->bd_next;
      fs_buf = fs_buf->bd_next;
      n_pages++;
    }

  c = dbs_count_pageset_items_2 (dbs, incbps);
  buffer_set_free (incbps);
  return c;
}

#ifndef HAVE_DIRECT_H
#define DIRNAME(de)	 de->d_name
#define CHECKFH(df)	 (df != NULL)
#else
#define DIRNAME(de)	 de->name
#define CHECKFH(df)	 (df != -1)
#define S_IFLNK	 S_IFREG
#endif

caddr_t * ob_file_list (char * fname)
{
  long files = 1;
  dk_set_t dir_list = NULL;
#ifndef HAVE_DIRECT_H
  DIR *df = 0;
  struct dirent *de;
#else
  char *fname_tail;
  ptrlong df = 0, rc = 0;
  struct _finddata_t fd, *de;
#endif
  char path[PATH_MAX + 1];
  STAT_T st;
  caddr_t lst;

#ifndef HAVE_DIRECT_H
  if (!is_allowed (fname))
    sqlr_new_error ("42000", "FA016",
	"Access to %s is denied due to access control in ini file", fname);
  df = opendir (fname);
#else
  if ((strlen (fname) + 3) >= PATH_MAX)
    sqlr_new_error ("39000", "FA017", "Path string is too long.");
  strcpy_ck (path, fname);
  for (fname_tail = path; fname_tail[0]; fname_tail++)
    {
      if ('/' == fname_tail[0])
	fname_tail[0] = '\\';
    }
  if (fname_tail > path && fname_tail[-1] != '\\')
    *(fname_tail++) = '\\';
  *(fname_tail++) = '*';
  fname_tail[0] = '\0';
  if (!is_allowed (path))
    sqlr_new_error ("42000", "FA018",
	"Access to %s is denied due to access control in ini file", path);
  df = _findfirst (path, &fd);
#endif
  if (CHECKFH (df))
    {
      do
	{
#ifndef HAVE_DIRECT_H
	  de = readdir (df);
#else
	  de = NULL;
	  if (rc == 0)
	    de = &fd;
#endif
	  if (de)
	    {
	      if (strlen (fname) + strlen (DIRNAME (de)) + 1 < PATH_MAX)
		{
		  snprintf (path, sizeof (path), "%s/%s", fname, DIRNAME (de));
		  V_STAT (path, &st);
		  if (((st.st_mode & S_IFMT) == S_IFDIR) && files == 0)
		    dk_set_push (&dir_list,
			box_dv_short_string (DIRNAME (de)));
		  else if (((st.st_mode & S_IFMT) == S_IFREG) && files == 1)
		    dk_set_push (&dir_list,
			box_dv_short_string (DIRNAME (de)));
#ifndef WIN32
		  else if (((st.st_mode & S_IFMT) == S_IFLNK) && files == 2)
		    dk_set_push (&dir_list,
			box_dv_short_string (DIRNAME (de)));
#endif
		  else if (((st.st_mode & S_IFMT) != 0) && files == 3)
		    dk_set_push (&dir_list,
			box_dv_short_string (DIRNAME (de)));
		}
	      else
		{
/* This bug is possible only in UNIXes, because it requires the use of links,
   but WIN32 case added too, due to paranoia. */
#ifndef HAVE_DIRECT_H
		  closedir (df);
#else
		  _findclose (df);
#endif
		  sqlr_new_error ("39000", "FA019",
		      "Path string is too long.");
		}
	    }
#ifdef HAVE_DIRECT_H
	  rc = _findnext (df, &fd);
#endif
	}
      while (de);
#ifndef HAVE_DIRECT_H
      closedir (df);
#else
      _findclose (df);
#endif
    }
  else
    {
      sqlr_new_error ("39000", "FA020", "%s", strerror (errno));
    }
  lst = list_to_array (dk_set_nreverse (dir_list));
  return (caddr_t*) lst;
}

static
int ob_get_num_from_file (caddr_t file, caddr_t prefix)
{
  if (!strncmp (file, prefix, strlen (prefix)))
    {
      char * pp = file+strlen(prefix);
      int postfix_check=0, digit_check=0;
      while (pp[0])
	{
	  if (isdigit (pp[0]) && ++digit_check && ++pp)
	    continue;
	  else
	    {
	      if ((!strcmp(pp, ".bp")) && ++postfix_check)
		break;
	      else
		return 0;
	    }
	}
      if (postfix_check && digit_check && (atoi (file+strlen(prefix)) > 0))
	return atoi (file+strlen(prefix));
    }
  return -1;
}

static
int ob_check_file (caddr_t elt, caddr_t ctx, caddr_t dir)
{
  caddr_t prefix = ctx;
  int num = 0;
  if (bp_ctx.db_bp_ts)
    {
      num = bp_ctx.db_bp_num;
      prefix = bp_ctx.db_bp_prfx;
    }
  if (ob_get_num_from_file (elt, prefix) > num)
    return -1;
  return 0;
}


static
int ob_foreach_file (caddr_t dir, caddr_t ctx, ob_err_ctx_t* e_ctx, file_check_f func)
{
  int inx;
  caddr_t * files = ob_file_list (dir);
  DO_BOX (caddr_t, elt, inx, files)
    {
      if (-1 == (func)(elt, ctx, dir))
	{
	  strncpy (e_ctx->oc_file, elt, FILEN_BUFSIZ);
	  dk_free_tree ((box_t) files);
	  return -1;
	}
    }
  END_DO_BOX;
  dk_free_tree ((box_t) files);
  return 0;
}

static
int ob_foreach_dir (caddr_t * dirs, caddr_t ctx, ob_err_ctx_t* e_ctx, file_check_f func)
{
  int inx;
  DO_BOX (caddr_t, elt, inx, dirs)
    {
      if (0 > ob_foreach_file (elt, ctx, e_ctx, func))
	{
	  e_ctx->oc_inx = inx;
	  return -1;
	}
    }
  END_DO_BOX;
  return 0;
}


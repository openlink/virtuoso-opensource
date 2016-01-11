/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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

#ifndef _RECOVERY_H
#define _RECOVERY_H

#define MIN_BACKUP_PAGES	100

#define COMPRESS_ERR_STR "Could not compress page %ld"
#define COMPRESS_ERR_CODE "IB001"

#define READ_ERR_STR "Read of page %ld failed"
#define READ_ERR_CODE "IB002"

#define STORE_CTX_ERR_STR "Could not store backup context"
#define STORE_CTX_ERR_CODE "IB003"

#define READ_CTX_ERR_STR "Could not read backup context"
#define READ_CTX_ERR_CODE "IB004"

#define FILE_ERR_CODE		"IB005"
#define PAGE_NUMBER_ERR_CODE	"IB006"
#define BACKUP_FILE_CR_ERR_CODE "IB007"
#define CLEAR_BP_CTX_ERR_CODE	"IB008"

#define TIMEOUT_ERR_STR "Timeout exceeded"
#define TIMEOUT_ERR_CODE "IB009"

#define TIMEOUT_NUMBER_ERR_CODE "IB010"
#define FILE_SZ_ERR_CODE	"IB011"
#define FILE_FORM_ERR_CODE	"IB012"
#define FILE_OPEN_ERR_CODE	"IB013"

#define USER_PERM_ERR_CODE	"IB014"
#define DIR_CLEARANCE_ERR_CODE	"IB015"
#define BACKUP_DIR_ARG_ERR_CODE	"IB015"
typedef struct ol_backup_context_s
{
  dk_session_t*	octx_file;
  dp_addr_t	page_dp;


  dbe_storage_t * octx_dbs;

  uint32	octx_timestamp;
  uint32	octx_num;

  char		octx_file_prefix[FILEN_BUFSIZ];
  char		octx_curr_file[FILEN_BUFSIZ];
  int		octx_curr_dir;

  long		octx_max_pages;
  long		octx_page_count;
  long		octx_last_page;

  int		octx_is_invalid;
  int		octx_is_tail; /* do not write header */

  dk_hash_t *	octx_cpt_remap_r;

  long		octx_last_backup; /* datetime of last backup */
  long		octx_max_uncomp_size; /* maximal uncompressed size of backup file */

  /* error reporting */
  long		octx_error;
  char *	octx_error_code;
  char *	octx_error_string;

  /* deadline time (in msecs) */
  long		octx_deadline;

  /* copy of wi_inst.wi_master->dbs_incbackup_set to rollback all changes over this set if error occurs (e.g. timeout). */
  buffer_desc_t *	octx_incset;
  buffer_desc_t *	octx_free_set;
  buffer_desc_t *	octx_ext_set;
  caddr_t *		octx_registry;
  buffer_desc_t *	octx_cpt_set;

  /* list of all created files */
  dk_set_t	octx_backup_files;
  /* must not be deallocated by destructor */
  caddr_t*	octx_backup_patha;
  OFF_T		octx_wr_bytes;
  OFF_T		octx_max_wr_bytes;
  dp_addr_t	octx_curr_page;

  dk_hash_t*	known;

  int		octx_disable_increment;
} ol_backup_context_t;


extern ol_backup_ctx_t bp_ctx;




typedef void (*page_func_t) (it_cursor_t *, buffer_desc_t *, void *);

void walk_dbtree ( it_cursor_t * it, buffer_desc_t ** buf_ret, int level,
      page_func_t func, void* ctx);

int backup_context_increment (ol_backup_context_t* ctx, int is_restore);

extern dk_mutex_t *checkpoint_mtx;

int lt_backup_flush (lock_trx_t * lt, int do_commit);

void wi_open_dbs ();

extern const char* recover_file_prefix; /* from obackup.c */
void ddl_obackup_init (void);
char* bp_curr_timestamp();
char* bp_curr_date();

extern caddr_t * backup_patha;

typedef int (*ol_regist_callback_f) (it_cursor_t * itc, buffer_desc_t * buf, ol_backup_context_t * ctx);
int ol_regist_unmark (it_cursor_t * itc, buffer_desc_t * buf, ol_backup_context_t * ctx);
int ol_write_registry (dbe_storage_t * dbs, ol_backup_context_t * ctx, ol_regist_callback_f callback);
extern ol_backup_ctx_t bp_ctx;

#endif

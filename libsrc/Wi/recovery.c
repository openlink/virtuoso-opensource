/*
 *  recovery.c
 *
 *  $Id$
 *
 *  Backup & Recovery procedures
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

#include "libutil.h"
#include "sqlnode.h"
#include "sqlbif.h"
#ifdef WIN32
# include "wiservic.h"
#endif

#include "recovery.h"
#include "security.h"
#include "log.h"

#define MAX_LEVELS 20


typedef struct _levstruct
{
  long lv_nodes;
  long lv_bytes;
  int lv_leaves;
  int lv_leaf_pointers;
} it_level_t;


dk_hash_t *recoverable_keys;
jmp_buf_splice structure_fault_ctx;
it_level_t levels[MAX_LEVELS];

dk_set_t old_backup_dirs;
dk_set_t curr_backup_dir;


int no_free_set = 0;
int is_crash_dump = 0;

static int bkp_check_and_recover_blobs = 0;

static void
walk_page_transit (it_cursor_t * itc, dp_addr_t dp, buffer_desc_t ** buf_ret)
{
  for (;;)
    {
      ITC_IN_MAP (itc);
      page_wait_access (itc, dp, NULL, *buf_ret, buf_ret,
	  bkp_check_and_recover_blobs ? PA_WRITE : PA_READ, RWG_WAIT_SPLIT);
      if (itc->itc_to_reset != RWG_WAIT_DECOY)
	break;
    }
  ITC_LEAVE_MAP (itc);
}




/*
 *  Calls a function on all db pages
 */
void
walk_dbtree ( it_cursor_t * it, buffer_desc_t ** buf_ret, int level,
    page_func_t func, void* ctx)
{
  dp_addr_t dp_from = (*buf_ret)->bd_page;
  dp_addr_t leaf;
  db_buf_t page;
  int pos;

  dp_addr_t up;
  int save_pos;

  levels[level].lv_nodes++;
  /*  levels[level].lv_bytes += PAGE_SZ - (*buf_ret)->bd_content_map->pm_bytes_free; */

  if (func)
    (*func) (it, *buf_ret, ctx);

  pos = SHORT_REF ((*buf_ret)->bd_buffer + DP_FIRST);
  page = (*buf_ret)->bd_buffer;
  while (pos)
    {
      if (pos > PAGE_SZ)
	break;

      leaf = leaf_pointer (page, pos);
      if (leaf)
	{
	  save_pos = pos;

	  walk_page_transit (it, leaf, buf_ret);
	  if ((uint32) (LONG_REF ((*buf_ret)->bd_buffer + DP_PARENT)) != dp_from)
	    {
	      log_error ("Bad parent link in %ld coming from %ld link %ld",
		  leaf, dp_from, LONG_REF ((*buf_ret)->bd_buffer + DP_PARENT));
	      if (!correct_parent_links)
		GPF_T1 ("Bad parent link in backup");
	    }
	  walk_dbtree (it, buf_ret, level + 1, func, ctx);
	  up = dp_from;
	  walk_page_transit (it, up, buf_ret);

	  if (it->itc_at_data_level)
	    {
	      it->itc_position = save_pos;
	      it->itc_page = (*buf_ret)->bd_page;
	      itc_read_ahead (it, buf_ret);
	    }
	  pos = save_pos;
	  page = (*buf_ret)->bd_buffer;
	}
      else
	{
	  it->itc_at_data_level = 1;
	  levels[level].lv_leaves++;

	  /* XXX PmN Should we modify the database here?
	   * Also called during backups
	   */
	  /*	  db_buf_length (page + pos, &hl, &l);
	  it->itc_position = pos;
	  if (0 != SHORT_REF ((*buf_ret)->bd_buffer + pos + hl + IE_KEY_ID))
	  itc_make_row_map (it, (*buf_ret)->bd_buffer); */

	}

      pos = IE_NEXT (page + pos);
    }
}


static void
walk_db (lock_trx_t * lt, page_func_t func)
{
  buffer_desc_t *buf;
  it_cursor_t *itc;

  memset (levels, 0, sizeof (levels));

  {
    DO_SET (index_tree_t * , it, &wi_inst.wi_master->dbs_trees)
      {
	if (it != wi_inst.wi_master->dbs_cpt_tree)
	  {
	    itc = itc_create (NULL , lt);
	    itc_from_it (itc, it);
	    itc->itc_isolation = ISO_UNCOMMITTED;
	    ITC_FAIL (itc)
	      {
		ITC_IN_MAP (itc);
		buf = itc_reset (itc);
		ITC_IN_MAP (itc);
		walk_dbtree (itc, &buf, 0, func, 0);
		itc_page_leave (itc, buf);
		ITC_LEAVE_MAP (itc);
	      }
	    ITC_FAILED
	      {
		itc_free (itc);
	      }
	    END_FAIL (itc);
	    itc_free (itc);
	  }
      }
    END_DO_SET()
  }
}


char *sys_tables[] =
{
  "SYS_CHARSETS",
  "SYS_COLS",
  "SYS_KEYS",
  "SYS_KEY_PARTS",
  "SYS_KEY_SUBKEY",
  "SYS_USER_TYPES",
  "SYS_COLLATIONS",
  "SYS_KEY_FRAGMENTS",
  NULL
};

static void log_row_blobs (it_cursor_t * itc, db_buf_t row);

static void
srv_dd_to_log (client_connection_t * cli)
{
  char temp[100];
  char **ptr;
  it_cursor_t *it;
  it = itc_create (NULL, cli->cli_trx);

  log_debug ("Dumping the schema tables");
  log_sc_change_1(cli->cli_trx);

  /* make a log entry with SYS_COLS, SYS_KEYS, SYS_KEY_PARTS *( */
  for (ptr = sys_tables; *ptr; ptr++)
    {
      local_cursor_t *lc;
      query_t *qr;
      snprintf (temp, sizeof (temp), "select _ROW from DB.DBA.%s", *ptr);
      qr = eql_compile (temp, cli);
      qr_quick_exec (qr, cli, "", &lc, 0);
      while (lc_next (lc))
	{
	  dbe_key_t * key;
	  caddr_t row = lc_nth_col (lc, 0);
	  key_id_t key_id = SHORT_REF ((db_buf_t)row + IE_KEY_ID);

	  key = sch_id_to_key (wi_inst.wi_schema, key_id);
	  if (!key)
	    GPF_T1("No key in row");
	  log_insert (cli->cli_trx, key, (db_buf_t) row, INS_REPLACING);
	  log_row_blobs (it, (db_buf_t) row);
	}
      lc_free (lc);
      qr_free (qr); /* PmN */
    }
  itc_free (it);
  log_sc_change_2 (cli->cli_trx);
  log_debug ("Dumping the registry");
  db_log_registry (cli->cli_trx->lt_log);

  lt_backup_flush (cli->cli_trx, 1);
  log_debug ("Dumping the schema done");
}

/*
static int
is_crash_recoverable_row (it_cursor_t * it, buffer_desc_t * buf, dbe_key_t * key)
{
  key_id_t k_id;
  int hl;
  hl = pg_cont_head_length (buf->bd_buffer + it->itc_position);
  k_id = SHORT_REF (buf->bd_buffer + it->itc_position + IE_KEY_ID + hl);

  if (recoverable_keys != NULL)
    {
      if (gethash ((void *) (long) k_id, recoverable_keys))
	return 1;
      else
	return 0;
    }
  if (key && key->key_is_primary && key->key_id > KI_SORT_TEMP)
    return 1;
  else
    return 0;
}
*/


static void
log_row_blobs (it_cursor_t * itc, db_buf_t row)
{
  key_id_t key_id = SHORT_REF (row + IE_KEY_ID);
  dbe_key_t * key = sch_id_to_key (wi_inst.wi_schema, key_id);
  /* dbe_key_t * key = itc->itc_row_key; */
  itc->itc_row_key = key;
  itc->itc_row_key_id = key_id;
  itc->itc_insert_key = key;
  itc->itc_row_data = row + IE_FIRST_KEY;
  /* printf ("### %ld >\n", key_id); */
  if (key && key->key_row_var)
    {
      int inx;
      for (inx = 0; key->key_row_var[inx].cl_col_id; inx++)
	{
	  dbe_col_loc_t * cl = &key->key_row_var[inx];
	  dtp_t dtp = cl->cl_sqt.sqt_dtp;
	  if (IS_BLOB_DTP (dtp))
	    {
	      int off, len;
	      if (ITC_NULL_CK (itc, (*cl)))
		continue;
	      ITC_COL (itc, (*cl), off, len);
	      dtp = itc->itc_row_data[off];
	      if (IS_BLOB_DTP (dtp))
		{
		  dp_addr_t start = LONG_REF_NA (itc->itc_row_data + off + BL_DP);
		  dp_addr_t dir_start = LONG_REF_NA (itc->itc_row_data + off + BL_PAGE_DIR);
		  long diskbytes = LONG_REF_NA (itc->itc_row_data + off + BL_BYTE_LEN);
		  blob_log_write (itc, start, dtp, dir_start, diskbytes,
				  key->key_row_var[inx].cl_col_id, key->key_table->tb_name);
		}
	    }
	}
    }
  fflush (stdout);
}


static int
bkp_check_blob_col (it_cursor_t *master_itc, dtp_t *col, dbe_key_t *key, dbe_col_loc_t *cl)
{
  lock_trx_t * lt = master_itc->itc_ltrx;
  index_tree_t *it = master_itc->itc_tree;
  dp_addr_t start = LONG_REF_NA (col + BL_DP);
  dp_addr_t bh_page = LONG_REF_NA (col + BL_DP);
  uint32 bh_timestamp = LONG_REF_NA (col + BL_TS);
  buffer_desc_t *buf = NULL;
  int status = 1, n_pages, pg_inx = 0;
  blob_handle_t * bh;
  it_cursor_t itc_auto, *itc = &itc_auto;
  ITC_INIT (itc, NULL, lt);
  itc_from_it (itc, it);

  bh = bh_from_dv (col, itc);
  if (!bh->bh_page_dir_complete)
    {
      bh_fetch_dir (itc->itc_tree->it_commit_space, lt, bh);
    }
  n_pages = box_length ((caddr_t) bh->bh_pages);
  if (BLOB_OK != blob_check (bh))
    return 0;
  bh_read_ahead (itc->itc_tree->it_commit_space, NULL, bh, 0, bh->bh_diskbytes);
  while (start)
    {
      uint32 timestamp;
      int type;

      if (pg_inx >= n_pages)
	{
	  ITC_LEAVE_MAP (itc);
	  log_warning ("blob has nmore pages than pages in page dir.  Can be cyclic.)  Start )= %d", bh->bh_page);
	  status = 0;
	  break;
	}
      if (start != bh->bh_pages[pg_inx])
	{
	  ITC_LEAVE_MAP (itc);
	  log_warning ("blob page dir dp  %d  differs from linked list dp = %d start = %d.",
		       bh->bh_pages[pg_inx], start, bh->bh_page);
	  status = 0;
	  break;
	}

      ITC_IN_MAP (itc);
      page_wait_access (itc, start, NULL, NULL, &buf, PA_READ, RWG_WAIT_ANY);
      if (!buf || PF_OF_DELETED == buf)
	{
	  ITC_LEAVE_MAP (itc);
	  log_warning ("Attempt to read deleted blob dp = %d start = %d.",
	      start, bh_page);
	  status = 0;
	  break;
	}
      ITC_IN_MAP (itc);
      type = SHORT_REF (buf->bd_buffer + DP_FLAGS);
      timestamp = LONG_REF (buf->bd_buffer + DP_BLOB_TS);

      if ((DPF_BLOB != type) &&
	  (DPF_BLOB_DIR != type))
	{
	  log_warning ("wrong blob type blob dp = %d start = %d\n", start, bh_page);
	  status = 0;
	  page_leave_inner (buf);
	  break;
	}

      if ((bh_timestamp != BH_ANY) && (bh_timestamp != timestamp))
	{
	  log_warning ("Dirty read of blob dp = %d start = %d.",
	      start, bh_page);
	  status = 0;
	  page_leave_inner (buf);
	  break;
	}
      start = LONG_REF (buf->bd_buffer + DP_OVERFLOW);
      ASSERT_IN_MAP (itc->itc_tree);
      if (buf)
	page_leave_inner (buf);
      pg_inx += 1;
    }
  ITC_LEAVE_MAP (itc);
  itc_free (itc);

  dk_free_box ((caddr_t) bh);
  return status;
}


static int
bkp_check_and_recover_blob_cols (it_cursor_t * itc, db_buf_t row)
{
  key_id_t key_id = SHORT_REF (row + IE_KEY_ID);
  dbe_key_t * key = sch_id_to_key (wi_inst.wi_schema, key_id);
  int updated = 0;


  itc->itc_row_key = key;
  itc->itc_row_key_id = key_id;
  itc->itc_insert_key = key;
  itc->itc_row_data = row + IE_FIRST_KEY;
  if (key && key->key_row_var)
    {
      int inx;
      for (inx = 0; key->key_row_var[inx].cl_col_id; inx++)
	{
	  dbe_col_loc_t * cl = &key->key_row_var[inx];
	  dtp_t dtp = cl->cl_sqt.sqt_dtp;
	  if (IS_BLOB_DTP (dtp))
	    {
	      int off, len;
	      if (ITC_NULL_CK (itc, (*cl)))
		continue;
	      ITC_COL (itc, (*cl), off, len);
	      dtp = itc->itc_row_data[off];
	      if (IS_BLOB_DTP (dtp))
		{
		  if (!bkp_check_blob_col (itc, itc->itc_row_data + off, key, cl))
		    {
		      char *col_name = __get_column_name (cl->cl_col_id, key);
		      dtp_t *col = itc->itc_row_data + off;
		      log_error ("will have to set blob for col %s in key %s to empty",
			  col_name, key->key_name);

		      LONG_SET_NA (col + BL_CHAR_LEN, 0);
		      LONG_SET_NA (col + BL_BYTE_LEN, 0);
		      updated = 1;
		    }
		}
	    }
	}
    }
  return updated;
}


int
lt_backup_flush (lock_trx_t * lt, int do_commit)
{
  int rc;
  IN_TXN;
  lt->lt_replicate = REPL_LOG;
  if (do_commit)
    rc = log_commit (lt);
  else
    rc = LTE_OK;
  blob_log_set_free (lt->lt_blob_log);
  lt->lt_blob_log = NULL;
  if (LTE_OK != rc)
    {
      LT_ERROR_DETAIL_SET (lt, box_dv_short_string ("Error writing the blobs to the transaction log"));
      lt->lt_error = LTE_LOG_FAILED;
      LEAVE_TXN;
      return rc;
    }
  LEAVE_TXN;

  lt->lt_blob_log = NULL;
  /* not in -d mode, only with backup () function */
  strses_flush (lt->lt_log);
  lt->lt_log->dks_bytes_sent = 0;
  return LTE_OK;
}

dbe_key_t *
get_crash_recoverable_row_key (key_id_t key_id)
{
  if (key_id == KI_LEFT_DUMMY || !key_id)
    return NULL;
  else
    {
      dbe_key_t * row_key = sch_id_to_key (wi_inst.wi_schema, key_id);
      if (recoverable_keys)
	{
	  if (gethash ((void*)(uptrlong) key_id, recoverable_keys))
	    {
	      if (!row_key)
		{
		  log_error ("Missing specified key definition for key_id %d", (int) key_id);
		  STRUCTURE_FAULT;
		}
	      return row_key;
	    }
	}
      else
	{
	  if (row_key && row_key->key_is_primary && row_key->key_id > KI_SORT_TEMP)
	    return row_key;
	  else if (!row_key)
	    {
	      log_error ("Missing key definition for key_id %d", (int) key_id);
	      STRUCTURE_FAULT;
	    }
	}
      return NULL;
    }
}


static int
dbe_row_is_valid_key (dbe_key_t *row_key, key_id_t k_id, dbe_key_t *page_key)
{
  if (row_key)
    {
      dbe_key_t *row_key_tmp = NULL;

      for (row_key_tmp = row_key; row_key_tmp;
	  row_key_tmp = row_key_tmp->key_migrate_to ?
	    get_crash_recoverable_row_key (row_key_tmp->key_migrate_to) : NULL)
	{
	  if (row_key_tmp)
	    {
	      if (row_key_tmp->key_id == k_id)
		return 1;
	      else if (page_key && dbe_row_is_valid_key (page_key, row_key_tmp->key_id, NULL))
		return 1;
	    }

	  DO_SET (dbe_key_t *, skey, &row_key_tmp->key_supers)
	    {
	      if (skey->key_id == k_id)
		return 1;
	      else if (page_key && dbe_row_is_valid_key (page_key, skey->key_id, NULL))
		return 1;
	    }
	  END_DO_SET();
	}
      return 0;
    }
  return 1;
}

int
dbe_cols_are_valid (db_buf_t row, dbe_key_t * key, int throw_error)
{
  db_buf_t orig_row = row;
  key_id_t key_id = SHORT_REF (orig_row + IE_KEY_ID);
  dbe_col_loc_t * cl;
  int inx = 0, off, len;
  dbe_key_t * row_key = key;
  int v_fill = 0;
  {
    if (key_id && key_id != key->key_id)
      {
        row_key = sch_id_to_key (wi_inst.wi_schema, key_id);
        if (!row_key)
          {
            if (key_id != KI_LEFT_DUMMY && key_id)
              {
                /*
		   looks like the page is inconsistent,
		   but previous check shows
		   row key is OK
		   true
		*/
                return 1;
              }
          }
      }
  }
  if (key_id)
    row += 4;
  else
    row += 8;

  if (KI_LEFT_DUMMY == key_id)
    {
      return 1;
    }
  DO_SET (dbe_column_t *, col, &row_key->key_parts)
    {
      if (!key_id && ++inx > key->key_n_significant)
	break;
      cl = key_find_cl (row_key,  col->col_id);
      if (!cl)
	{
	  if (throw_error)
	    sqlr_new_error ("42000", "SR440", "Key %ld [%s] does not contain column %d [%s]",
		   (long)(col->col_id), col->col_name,
		   row_key->key_id, row_key->key_name);
	  else
	    log_error ("Key %ld [%s] does not contain column %d [%s]",
		(long)(col->col_id), col->col_name,
		row_key->key_id, row_key->key_name);
	  return 0;
	}

      if (!key_id)
        {
          len = cl->cl_fixed_len;
          if (len > 0)
            {
              off = cl->cl_pos;
            }
          else if (CL_FIRST_VAR == len)
            {
              off = row_key->key_key_var_start;
              len = SHORT_REF (row + row_key->key_length_area) - off;
            }
          else
            {
              len = -len;
              off = SHORT_REF (row + len);
              len = SHORT_REF (row + len + 2) - off;
            }
        }
      else
        {
          KEY_COL_WITHOUT_CHECK (row_key, row, (*cl), off, len);

	  v_fill += len;
          if (cl->cl_null_mask && row[cl->cl_null_flag] & cl->cl_null_mask)
            {
	      goto next;
            }
        }
      if (((off) < 0) || ((len) < 0) || (((off) + (len)) > ROW_MAX_DATA
	    + 2 /*GK: this is actually a hack : the "old" wrong length was + 2 (unaligned)*/))
	{
	  if (throw_error)
	    sqlr_new_error ("42000", "SR441",
		"Column %ld [%s] has wrong len [%d] or offset [%d] in the key %d [%s]",
		(long)(col->col_id), col->col_name, len, off, row_key->key_id, row_key->key_name);
	  else
	    log_error ("Column %ld [%s] has wrong len [%d] or offset [%d] in the key %d [%s]",
		(long)(col->col_id), col->col_name, len, off, row_key->key_id, row_key->key_name);
	  return 0;
	}
    next: ;
    }
  END_DO_SET();
  v_fill = row_key->key_key_var_start;
  for (inx = 0; key->key_key_var[inx].cl_col_id; inx++)
    {
      dbe_col_loc_t * cl = &row_key->key_key_var[inx];
      KEY_COL_WITHOUT_CHECK (row_key, row, (*cl), off, len);
      v_fill += len;
    }

  if (v_fill > MAX_RULING_PART_BYTES)
    {
      if (throw_error)
	sqlr_new_error ("42000", "SR442",
	    "Ruling part too long (%d) for key %d [%s]", v_fill, row_key->key_id, row_key->key_name);
      else
	log_error ("Ruling part too long (%d) for key %d [%s]", v_fill, row_key->key_id, row_key->key_name);
      return 0;
    }
  return 1;
}

static void
log_page (it_cursor_t * it, buffer_desc_t * buf, void* dummy)
{
  db_buf_t page;
  int pos;
  key_id_t k_id;
  int rc;
  dp_addr_t parent_dp;
  int any = 0, n_bad_rows = 0, n_rows = 0;
  dbe_key_t *page_key = NULL;

  page = buf->bd_buffer;
  pos = SHORT_REF (page + DP_FIRST);
  k_id = SHORT_REF (page + DP_KEY_ID);
  page_key = (k_id != KI_LEFT_DUMMY && k_id) ? sch_id_to_key (wi_inst.wi_schema, k_id) : NULL;

  /* page consistence check */
  parent_dp = (dp_addr_t) LONG_REF (buf->bd_buffer + DP_PARENT);
  if (parent_dp && parent_dp > wi_inst.wi_master->dbs_n_pages)
    STRUCTURE_FAULT;

  /* internal rows consistence check */
  while (pos)
    {
      if (pos > PAGE_SZ)
	{
	  STRUCTURE_FAULT;
	}
      else
	{
	  key_id_t key_id = SHORT_REF (page + pos + IE_KEY_ID);
	  dbe_key_t * row_key = get_crash_recoverable_row_key (key_id);
	  if (row_key)
	    {
	      long l = row_length (page + pos, row_key);
	      if (pos+l > PAGE_SZ)
		{
		  n_rows++;
		  n_bad_rows++;
		  goto next;
		}

	      if (!dbe_row_is_valid_key (row_key, k_id, page_key))
		{
		  dbe_key_t *page_key = sch_id_to_key (wi_inst.wi_schema, k_id);
		  log_error ("Possible corruption : Page %lu contans rows with key id %d (%s) whereas it should contain only rows of key id %d (%s)",
		      (unsigned long) buf->bd_page, (int) key_id, row_key->key_name, (int) k_id, page_key ? page_key->key_name : "<Unknown>");
		  n_rows++;
		  n_bad_rows++;
		  goto next;
		}
	      if (!dbe_cols_are_valid (page + pos, page_key, 0))
		{
		  log_error ("Possible column layout error");
		  goto next;
		}
	      if (bkp_check_and_recover_blobs)
		{
		  ITC_LEAVE_MAP (it);
		  if (bkp_check_and_recover_blob_cols (it, page + pos))
		    buf_set_dirty (buf);
		  ITC_IN_MAP (it);
		}
	      log_insert (it->itc_ltrx, row_key, page+pos, INS_REPLACING);
	      log_row_blobs (it, page+pos);
	      any++;
	    }
	  n_bad_rows = 0;
	  n_rows++;
	}
next:
      if (n_rows > 1200 || n_bad_rows > 10)
	STRUCTURE_FAULT;
      pos = IE_NEXT (page + pos);
    }
  if (any)
    {
      if (!is_crash_dump)
	{
	  ITC_LEAVE_MAP (it);
	}
      rc = lt_backup_flush (it->itc_ltrx, 1);
      if (rc != LTE_OK)
	itc_bust_this_trx (it, &buf, ITC_BUST_THROW);
    }
}

void
db_recover_key (int k_id, int n_id)
{
  if (recoverable_keys == NULL)
    recoverable_keys = hash_table_allocate (11);

  log_info ("Will dump key id %d", k_id);
  sethash ((void *) (ptrlong) k_id, recoverable_keys, (void *) (ptrlong) n_id);
}


void
db_recover_keys (char *keys)
{
  if (!strcmp (keys, "schema"))
    {
      db_recover_key (KI_COLS_ID, 	KI_COLS_ID);
      db_recover_key (KI_KEYS, 		KI_KEYS);
      db_recover_key (KI_KEY_PARTS, 	KI_KEY_PARTS);
      db_recover_key (KI_COLLATIONS, 	KI_COLLATIONS);
      db_recover_key (KI_CHARSETS, 	KI_CHARSETS);
      db_recover_key (KI_SUB, 		KI_SUB);
      db_recover_key (KI_FRAGS, 	KI_FRAGS);
      db_recover_key (KI_UDT, 		KI_UDT);
    }
  else
    {
      char *key_id = NULL, *tok_s = NULL;
      key_id = strtok_r (keys, " ", &tok_s);
      while (key_id)
	{
	  int k = atoi (key_id);
	  if (k)
	    {
	      db_recover_key (k, k);
	    }
	  key_id = strtok_r (NULL, " ", &tok_s);
	}
    }
}

#ifdef DBG_BLOB_PAGES_ACCOUNT
dk_hash_t * blob_pages_hash = NULL;
void db_crash_to_log (char *mode);

void
db_dbg_account_add_page (dp_addr_t start)
{
  if (blob_pages_hash)
    {
      if (gethash (DP_ADDR2VOID (start), blob_pages_hash))
	{
	  log_error ("duplicate blob db :%ld", (long) start);
	}
      sethash (DP_ADDR2VOID (start), blob_pages_hash, DP_ADDR2VOID (1));
    }
}

void
db_dbg_account_check_page_in_hash (dp_addr_t start)
{
  if (blob_pages_hash)
    {
      if (!gethash (DP_ADDR2VOID (start), blob_pages_hash))
	{
	  log_error ("found a db not in the used set : %ld", (long) start);
	  call_exit (-1);
	}
    }
}

void
db_dbg_account_init_hash ()
{
  if (!blob_pages_hash)
    {
      blob_pages_hash = hash_table_allocate (1000000);
      dk_hash_set_rehash (blob_pages_hash, 5);
    }
  else
    clrhash (blob_pages_hash);
}
#endif

void
db_to_log (void)
{
  volatile int saved_sqlc_hook_enable = sqlc_hook_enable;
  log_info ("Database dump started");
  sqlc_hook_enable = 0;

  log_checkpoint (wi_inst.wi_master, NULL);
  bootstrap_cli->cli_replicate = REPL_LOG;
  IN_TXN;
  cli_set_new_trx (bootstrap_cli);
  LEAVE_TXN;
  srv_dd_to_log (bootstrap_cli);
  walk_db (bootstrap_cli->cli_trx, log_page);

  sqlc_hook_enable = saved_sqlc_hook_enable;
  log_info ("Database dump complete");
#ifdef DBG_BLOB_PAGES_ACCOUNT
  db_crash_to_log ("");
#endif
}

/*
 * these define's should be somewhere else
 */
#ifdef WIN32
#define PATH_SEP '\\'
#else
#define PATH_SEP '/'
#endif

#ifdef WIN32
#include <windows.h>
#ifndef __BORLANDC__
#define HAVE_DIRECT_H
#endif
#endif

#ifdef HAVE_DIRECT_H
#include <direct.h>
#include <io.h>
#define PATH_MAX	 MAX_PATH
#else
#include <dirent.h>
#endif

#ifdef __BORLANDC__
#include <dir.h>
#define PATH_MAX MAXPATH
#endif

void
backup_prepare (query_instance_t * qi, char * file)
{
  int fd = -1;
  dk_session_t *ses;
  lock_trx_t *lt = qi->qi_trx;
  char buf[PATH_MAX + 1];
  char *fname = file;
  /*  if (lt->lt_after_space != db_main_tree->it_checkpoint_space || qi->qi_autocommit) */
  if (!wi_inst.wi_is_checkpoint_pending || qi->qi_autocommit)
    {
      int rc;
#if 0
      if (qi->qi_caller != CALLER_CLIENT)
	sqlr_new_error ("42000", "SRXXX",
	    "backup () cannot be run from procedures "
	    "if the transaction is not read only");
#endif
      IN_TXN;
      rc = lt_set_checkpoint (lt);
      LEAVE_TXN;
      if (!rc)
	sqlr_new_error ("42000", "SR110",
	    "backup () must be the first operation in its transaction "
	    "if the transaction is not read only");
    }

  ses = dk_session_allocate (SESCLASS_TCPIP);
  if (ses == NULL)
    sqlr_new_error ("42000", "FA038", "Cannot open backup file (could not allocate session)");

  if (!srv_have_global_lock(THREAD_CURRENT_THREAD))
    IN_CPT (qi->qi_trx);

  if (strchr(file, PATH_SEP) == NULL)
    {
      /*
       * no path specified: select backup directory
       */

      dk_set_t bd;
      char *errmsg;

      if (curr_backup_dir == NULL)
        curr_backup_dir = old_backup_dirs;

      bd = curr_backup_dir;
      do
        {
	  char *dir = (char *) bd->data;
	  size_t dirlen = strlen(dir);

	  /* compose file name, check for overflows */
	  fname = file;
	  if (dirlen + 1 + strlen(file) > PATH_MAX)
	    {
	      errmsg = "filename too long";
	      log_warning ("backup_prepare: %s%c%s: %s",
		dirlen, PATH_SEP, file, errmsg);
	      bd = bd->next;
	      continue;
	    }

	  fname = buf;
	  strcpy_size_ck (fname, dir, sizeof (buf));
	  if (dirlen < sizeof (buf) - 1)
	    fname[dirlen] = PATH_SEP;
	  strcpy_size_ck (fname + dirlen + 1, file, sizeof (buf) - dirlen - 1);

	  /* try to open file */
	  file_set_rw(fname);
	  if ((fd = fd_open(fname, OPEN_FLAGS)) < 0)
            {
	      errmsg = strerror(errno);
	      log_warning ("backup_prepare: %s: %s",
		fname, errmsg);
	      bd = bd->next;
	      continue;
            }

	  /* got it */
	  curr_backup_dir = bd->next;
	  break;
        }
      while (bd != curr_backup_dir);

      if (fd < 0)
        {
	  PrpcSessionFree (ses);
	  if (!srv_have_global_lock(THREAD_CURRENT_THREAD))
	    LEAVE_CPT(qi->qi_trx);

	  sqlr_new_error ("42000", "FA038", "Cannot open backup file %s: %s",
	    fname, errmsg);
        }
    }
  else
    {
      /*
       * path specified: just try to open this file
       */

      file_set_rw (fname);
      if ((fd = fd_open (fname, OPEN_FLAGS)) == -1)
	{
	  char *errmsg = strerror(errno);

	  PrpcSessionFree (ses);
	  if (!srv_have_global_lock(THREAD_CURRENT_THREAD))
	    LEAVE_CPT(qi->qi_trx);

	  sqlr_new_error ("42000", "FA038", "Cannot open backup file %s: %s",
	    fname, errmsg);
        }
    }

  ftruncate (fd, 0);
  tcpses_set_fd (ses->dks_session, fd);

  log_info ("Backup to %s started", fname);

  lt->lt_backup = ses;
  lt->lt_backup_length = 0;
}


void
backup_close (lock_trx_t *lt)
{
  dk_session_t *ses = lt->lt_backup;
#if defined (WINDOWS) | defined (WINNT)
  char *file = NULL; /* TODO: add the real file name here */
#endif
  fd_close (tcpses_get_fd (ses->dks_session), file);
  PrpcSessionFree (ses);
  lt->lt_backup = NULL;
  lt->lt_backup_length = 0;
}


int
db_backup (query_instance_t *qi, char *file)
{
  lock_trx_t *lt = qi->qi_trx;
  long nodes;
  int n;

  sec_check_dba (qi, "backup");

  backup_prepare (qi, file);

  bkp_check_and_recover_blobs = 1;
  srv_dd_to_log (qi->qi_client);
  walk_db (qi->qi_trx, log_page);
  bkp_check_and_recover_blobs = 0;
  backup_close (lt);

  if (!srv_have_global_lock(THREAD_CURRENT_THREAD))
    LEAVE_CPT(qi->qi_trx);

  if (qi->qi_trx->lt_status != LT_PENDING)
    {
      log_info ("Backup transaction failed. Removed %s", file);
      unlink (file);
      sqlr_new_error ("40009", "SR111", "Backup transaction failed");
    }

  nodes = 0;
  for (n = 0; levels[n].lv_nodes && n < MAX_LEVELS; n++)
    nodes += levels[n].lv_nodes;

  log_info ("Backup to %s complete, processed %ld nodes on %d levels",
      file, nodes, n);

  return 1;
}


caddr_t
bif_backup_prepare (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t file = bif_string_arg (qst, args, 0, "backup_prepare");
  backup_prepare (qi, file);
  return NULL;
}


caddr_t
bif_backup_row (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dbe_key_t * key;
  long l;
  it_cursor_t itc_auto;
  it_cursor_t *itc = &itc_auto;
  query_instance_t *qi = (query_instance_t *) qst;
  lock_trx_t *lt = qi->qi_trx;
  caddr_t row = bif_arg (qst, args, 0, "backup_row");
  dtp_t tag = DV_TYPE_OF (row);
  ITC_INIT (itc, qi->qi_space, qi->qi_trx);
  if (!lt->lt_backup)
    sqlr_new_error ("42000", "SR112", "Transaction not in backup mode");
  if (tag != DV_SHORT_CONT_STRING && tag != DV_LONG_CONT_STRING)
    sqlr_new_error ("42000", "SR113", "backup_row needs a _ROW as argument");
  key = sch_id_to_key (wi_inst.wi_schema, SHORT_REF (row + IE_KEY_ID));
  l = row_length ((db_buf_t) row, key);
  log_insert (lt, key, (db_buf_t) row, INS_REPLACING);
  log_row_blobs (itc, (db_buf_t) row);
  if (BOX_ELEMENTS (args) > 1)
    {
      long written = qi->qi_trx->lt_backup_length;
      if (ssl_is_settable (args[1]))
	qst_set_long (qst, args[1], written);
    }

  return NULL;
}


caddr_t
bif_backup_flush (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int rc;
  query_instance_t *qi = (query_instance_t *) qst;
  lock_trx_t *lt = qi->qi_trx;
  if (!lt->lt_backup)
    sqlr_new_error ("42000", "SR114", "Transaction not in backup mode");

  if (BOX_ELEMENTS (args) > 0)
    {
      long written = qi->qi_trx->lt_backup_length;
      if (ssl_is_settable (args[0]))
	qst_set_long (qst, args[0], written);
    }

  rc = lt_backup_flush (qi->qi_trx, 1);
  if (rc != LTE_OK)
    sqlr_new_error ("42000", "SR115", "Error writing backup_flush");
  return NULL;
}


caddr_t
bif_backup_close (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  lock_trx_t *lt = qi->qi_trx;
  if (!lt->lt_backup)
    sqlr_new_error ("42000", "SR116", "Transaction not in backup mode");

  backup_close (qi->qi_trx);
  if (!srv_have_global_lock(THREAD_CURRENT_THREAD))
    LEAVE_CPT(qi->qi_trx);
  return NULL;
}



#if 0 /* GK : Such a security flaw */
static
caddr_t bif_crash_recovery_log_check (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  if (!f_read_from_rebuilt_database)
    {
      log_error ("The usage of crash recovery log without +restore-crash-dump argument is not allowed");
      call_exit (-1);
    }
  return 0; /* keeps compiler happy */
}
#endif

int ignore_remap = 0;
long dpf_count[11];

extern long blob_pages_logged;
void
db_pages_to_log (char *mode, volatile dp_addr_t start_dp, volatile dp_addr_t end_dp)
{
  int n_logged = 0, n_non_index = 0, n_bad_dpf = 0;
  buffer_desc_t *buf;
  volatile dp_addr_t page_no = 3;
  volatile dp_addr_t end_page;
  it_cursor_t *it;

  dbe_storage_t * storage = wi_inst.wi_master;
  it = itc_create (NULL, bootstrap_cli->cli_trx);

  no_free_set = strchr (mode, 'a') ? 1 : 0;
  is_crash_dump = 1;

  ITC_FAIL (it)
    {
      /*    ITC_IN_MAP (it); */
      buf = bp_get_buffer(NULL, BP_BUF_REQUIRED);
      /*      it->itc_is_in_map_sem = 1; */

      if (!start_dp) start_dp = 2;
      if (!end_dp)
	{
	  end_page = storage->dbs_n_pages;
	}
      else
	{
	  if (end_dp <= storage->dbs_n_pages)
	    {
	      end_page = end_dp;
	    }
	  else
	    {
	      log_error("crashdump_end_dp (%ld) larger than no. of pages.", end_dp);
	      call_exit(-1);
	    }
	}

      log_error("Starting crash dump from page %ld to %ld",
		start_dp, end_page);

      for (page_no = start_dp; page_no < end_page; page_no++)
	{
	  dp_addr_t page;
	  int inx, bit;
	  uint32 *array;

	  if (0 == page_no%10000)
	    log_error("Logging page %ld", page_no);

	  if (!no_free_set)
	    dbs_locate_free_bit (storage, page_no, &array, &page, &inx, &bit);
	  if ((no_free_set
	      || (0 != (array[inx] & (1 << bit))))
		  && (ignore_remap ||
		      !gethash (DP_ADDR2VOID (page_no),
			       storage->dbs_cpt_remap)))
	    {
	      buf->bd_page = buf->bd_physical_page = page_no;
	      buf->bd_storage = storage;
	      if (WI_ERROR == buf_disk_read (buf))
		{
		  log_error ("Read of page %ld failed", page_no);
		}
	      else
		{
		  buf->bd_readers = 1;
		  if (DPF_INDEX == SHORT_REF (buf->bd_buffer + DP_FLAGS))
		    {
		      if (0 == setjmp_splice (&structure_fault_ctx))
			{
			  n_logged++;
			  log_page (it, buf, 0);
			}
		      else
			{
			  log_error ("Structure inconsistent on page, "
				     "logical %ld, physical %ld",
				     buf->bd_page, buf->bd_physical_page);
			  lt_backup_flush (it->itc_ltrx, 0);
			  buf->bd_readers = 1;
			}
		    }
		  else
		    {
		      int fl = SHORT_REF (buf->bd_buffer + DP_FLAGS);
		      if (fl < 10)
			dpf_count[fl]++;
		      else
			n_bad_dpf++;
		      n_non_index++;
#ifdef DBG_BLOB_PAGES_ACCOUNT
                      if (fl == DPF_BLOB)
			db_dbg_account_check_page_in_hash (buf->bd_page);
#endif
		    }
		  page_leave_inner (buf);
		}
	    }
	}
      ITC_LEAVE_MAP (it);
    }
  ITC_FAILED
    {
      log_error("Out of configured dump space. Start next with config option crashdump_start_dp: %ld", page_no);
      call_exit(-1);
    }
  END_FAIL (it);

  itc_free (it);
  dbg_printf (("%d logged %d non index pages allocated, %d bad dpf.\n",
   n_logged, n_non_index, n_bad_dpf));
  dbg_printf (("%ld FREE_SET pages.\n", dpf_count[DPF_FREE_SET]));
  dbg_printf (("%ld DPF_EXTENSION pages.\n", dpf_count[DPF_EXTENSION]));
  dbg_printf (("%ld DPF_BLOB pages.\n", dpf_count[DPF_BLOB]));
  dbg_printf (("%ld DPF_FREE pages.\n", dpf_count[DPF_FREE]));
  dbg_printf (("%ld DPF_DB_HEAD pages.\n", dpf_count[DPF_DB_HEAD]));
  dbg_printf (("%ld DPF_CP_REMAP pages.\n", dpf_count[DPF_CP_REMAP]));
  dbg_printf (("%ld DPF_BLOB_DIR pages.\n", dpf_count[DPF_BLOB_DIR]));
  dbg_printf (("%ld DPF_INCBACKUP_SET pages.\n", dpf_count[DPF_INCBACKUP_SET]));
  dbg_printf (("%ld DPF_LAST_DPF pages.\n", dpf_count[DPF_LAST_DPF]));
}

char *f_crash_dump_data_ini = NULL;

void
db_crash_to_log (char *mode)
{
  volatile int saved_sqlc_hook_enable = sqlc_hook_enable;

  log_info ("Database crash recovery dump started");
  sqlc_hook_enable = 0;

  log_enable_segmented (1);
  log_checkpoint (wi_inst.wi_master, NULL);

  if (!bootstrap_cli)
    bootstrap_cli = client_connection_create ();

  bootstrap_cli->cli_replicate = REPL_LOG;
  IN_TXN;
  cli_set_new_trx (bootstrap_cli);
  lt_threads_set_inner (bootstrap_cli->cli_trx, 1);
  bootstrap_cli->cli_trx->lt_replicate = REPL_LOG;
  LEAVE_TXN;
  if (!f_crash_dump_data_ini && !recoverable_keys)
    {
#if 0
      log_text (bootstrap_cli->cli_trx, "crash_recovery_log_check()");
#endif
      is_crash_dump = 1;
      if (!strchr (mode, 'a') && !crashdump_start_dp /*&& !recoverable_keys*/)
	srv_dd_to_log (bootstrap_cli);
    }
  if (strchr (mode, 'l'))
    return;			/* schema only */
  assertion_on_read_fail = 0;

  if (f_crash_dump_data_ini)
    {
      dbe_schema_t *sc = wi_inst.wi_schema;
      log_debug ("Switching to database in %s to read the data", f_crash_dump_data_ini);
      f_config_file = f_crash_dump_data_ini;
      if (cfg_setup () == -1)
	{
	  call_exit (-1);
	}
      wi_open_dbs ();
      mt_write_init ();
      wi_inst.wi_schema = sc;
    }

  log_debug ("Dumping the data");
  db_pages_to_log (mode, crashdump_start_dp, crashdump_end_dp);
  log_debug ("Dumping data done");

  sqlc_hook_enable = saved_sqlc_hook_enable;
  log_info ("Database crash recovery dump complete");
}


int
db_check (query_instance_t * qi)
{
  lock_trx_t *lt = qi->qi_trx;
  int n;

  if (lt->lt_mode != TM_SNAPSHOT || qi->qi_autocommit)
    sqlr_new_error ("42000", "SR117",
	"db_check () must be in read only, non-autocommit transaction mode."
	" e.g. do it from isql in RO mode.");

  log_info ("Database check started");
  walk_db (qi->qi_trx, NULL);

  if (qi->qi_trx->lt_status != LT_PENDING)
    {
      char *err = "Database check transaction failed";
      log_info (err);
      sqlr_new_error ("40009", "SR118", err);
    }

  log_info ("Database check complete");
  for (n = 0; levels[n].lv_nodes && n < MAX_LEVELS; n++)
    {
      log_info ("  level %d, %ld nodes, %ld bytes, %ld bytes/node", n,
	  levels[n].lv_nodes, levels[n].lv_bytes,
	  levels[n].lv_bytes / levels[n].lv_nodes);
    }

  return 1;
}

void
recovery_init (void)
{
  bif_define ("backup_prepare", bif_backup_prepare);
  bif_define ("backup_row", bif_backup_row);
  bif_define ("backup_flush", bif_backup_flush);
  bif_define ("backup_close", bif_backup_close);
#if 0
  bif_define ("crash_recovery_log_check", bif_crash_recovery_log_check);
#endif
}


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
  buffer_desc_t * target = NULL;
  for (;;)
    {
      page_wait_access (itc, dp, *buf_ret, &target,
			PA_WRITE , RWG_WAIT_NO_ENTRY_IF_WAIT);
      if (target)
	break;
    }
  *buf_ret = target;
  itc->itc_page = dp;
}




/*
 *  Calls a function on all db pages
 */
void
walk_dbtree ( it_cursor_t * it, buffer_desc_t ** buf_ret, int level,
    page_func_t func, void* ctx)
{
  dp_addr_t dp_from = (*buf_ret)->bd_page;
  buffer_desc_t * buf_from = *buf_ret;
  dp_addr_t leaf;
  db_buf_t page;

  dp_addr_t up;
  int save_pos;

  if (level < MAX_LEVELS)
    {
      levels[level].lv_nodes++;
      /*  levels[level].lv_bytes += PAGE_SZ - (*buf_ret)->bd_content_map->pm_bytes_free; */
    }
  if (func)
    (*func) (it, *buf_ret, ctx);

  page = (*buf_ret)->bd_buffer;
  DO_ROWS ((*buf_ret), map_pos, row, NULL)
    {
      if ((*buf_ret)->bd_content_map->pm_entries[map_pos] > PAGE_SZ)
	break;

      leaf = leaf_pointer (row, it->itc_insert_key);
      if (leaf)
	{
	  buf_from = *buf_ret;
	  dp_from = buf_from->bd_page;
	  save_pos = map_pos;

	  walk_page_transit (it, leaf, buf_ret);
	  buf_ext_check (*buf_ret);
	  if ((uint32) (LONG_REF ((*buf_ret)->bd_buffer + DP_PARENT)) != dp_from)
	    {
	      log_error ("Bad parent link in %ld coming from %ld link %ld. Crash recovery recommended.",
		  leaf, buf_from->bd_page, LONG_REF ((*buf_ret)->bd_buffer + DP_PARENT));
	      if (!correct_parent_links)
		GPF_T1 ("Bad parent link in backup. Crash recovery recommended.");
	    }
	  walk_dbtree (it, buf_ret, level + 1, func, ctx);
	  up = dp_from;
	  walk_page_transit (it, up, buf_ret);

	  if (it->itc_at_data_level)
	    {
	      it->itc_map_pos = save_pos;
	      it->itc_page = (*buf_ret)->bd_page;
	      itc_read_ahead (it, buf_ret);
	    }
	  page = (*buf_ret)->bd_buffer;
	}
      else
	{
	  it->itc_at_data_level = 1;
	  if (level < MAX_LEVELS)
	    levels[level].lv_leaves++;


	}

    }
  END_DO_ROWS;
}

char * backup_ignore_keys;

void
split_string (caddr_t str, char * chrs, dk_set_t * set)
{
  char *tok_s = NULL, *tok, *tmp;
  caddr_t string = str ? box_dv_short_string (str) : NULL;
  if (NULL == chrs)
    chrs = ", "; 
  if (NULL == string)
    return;
  tok_s = NULL;
  tok = strtok_r (string, chrs, &tok_s);
  while (tok)
    {
      if (tok && strlen (tok) > 0)
	{
	  while (*tok && isspace (*tok))
	    tok++;
	  if (tok && strlen (tok) > 1)
	    tmp = tok + strlen (tok) - 1;
	  else
	    tmp = NULL;
	  while (tmp && tmp >= tok && isspace (*tmp))
	    *(tmp--) = 0;
	  dk_set_push (set, box_dv_short_string (tok));
	}
      tok = strtok_r (NULL, chrs, &tok_s);
    }
  dk_free_box (string);
}

static int
backup_key_is_ignored (dk_set_t * ign, dbe_key_t * key)
{
  DO_SET (caddr_t, kn, ign)
    {
      if (!stricmp (kn, key->key_name))
	return 1;
    }
  END_DO_SET ();
  return 0;
} 

static void
walk_db (lock_trx_t * lt, page_func_t func)
{
  buffer_desc_t *buf;
  it_cursor_t *itc;
  dk_set_t ign = NULL;
  split_string (backup_ignore_keys, NULL, &ign);

  memset (levels, 0, sizeof (levels));

  {
    DO_SET (index_tree_t * , it, &wi_inst.wi_master->dbs_trees)
      {
	if (it != wi_inst.wi_master->dbs_cpt_tree && !backup_key_is_ignored (&ign, it->it_key))
	  {
	    itc = itc_create (NULL , lt);
	    itc_from_it (itc, it);
	    itc->itc_isolation = ISO_UNCOMMITTED;
	    ITC_FAIL (itc)
	      {
		itc->itc_random_search = RANDOM_SEARCH_ON; /* do not use root image cache */
		buf = itc_reset (itc);
		itc->itc_random_search = RANDOM_SEARCH_OFF;
		itc_try_land (itc, &buf);
		/* the whole traversal is in landed (PA_WRITE() mode. page_transit_if_can will not allow mode change in transit */
		if (!buf->bd_content_map)
		  {
		    log_error ("Blog ref'referenced as index tree top node dp=%d key=%s\n", buf->bd_page, itc->itc_insert_key->key_name);
		  }
		else
		  walk_dbtree (itc, &buf, 0, func, 0);
		itc_page_leave (itc, buf);
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

static void log_rd_blobs (it_cursor_t * itc, row_delta_t * rd);

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
	  row_delta_t rd;
	  caddr_t * row = (caddr_t *) lc_nth_col (lc, 0);
	  memset (&rd, 0, sizeof (rd));
	  rd.rd_values = &row[1];
	  rd.rd_n_values = BOX_ELEMENTS (row) - 1;
	  rd.rd_key = sch_id_to_key (wi_inst.wi_schema, unbox (row[0]));
	  log_insert (cli->cli_trx, &rd, INS_REPLACING);
	  it->itc_tree = rd.rd_key->key_fragments[0]->kf_it;
	  log_rd_blobs (it, &rd);
	}
      lc_free (lc);
      qr_free (qr); /* PmN */
    }
  log_sc_change_2 (cli->cli_trx);
  log_debug ("Dumping the registry");
  db_log_registry (cli->cli_trx->lt_log);

  lt_backup_flush (cli->cli_trx, 1);
  mutex_enter (log_write_mtx);
  log_time (log_time_header (wi_inst.wi_master->dbs_cfg_page_dt));
  mutex_leave (log_write_mtx);
  if (1)
    {
      local_cursor_t *lc;
      query_t *qr;
      snprintf (temp, sizeof (temp), "select _ROW from DB.DBA.SYS_VT_INDEX");
      qr = eql_compile (temp, cli);
      qr_quick_exec (qr, cli, "", &lc, 0);
      while (lc_next (lc))
	{
	  row_delta_t rd;
	  caddr_t * row = (caddr_t *) lc_nth_col (lc, 0);
	  memset (&rd, 0, sizeof (rd));
	  rd.rd_values = &row[1];
	  rd.rd_n_values = BOX_ELEMENTS (row) - 1;
	  rd.rd_key = sch_id_to_key (wi_inst.wi_schema, unbox (row[0]));
	  log_insert (cli->cli_trx, &rd, INS_REPLACING);
	  it->itc_tree = rd.rd_key->key_fragments[0]->kf_it;
	  log_rd_blobs (it, &rd);
	}
      lc_free (lc);
      qr_free (qr); /* PmN */
      log_text_array (cli->cli_trx, list (1, box_string ("select count (*)  from SYS_VT_INDEX where "
	  "0 = __vt_index (VI_TABLE, VI_INDEX, VI_COL, VI_ID_COL, VI_INDEX_TABLE, "
	  "deserialize (VI_OFFBAND_COLS), VI_LANGUAGE, VI_ENCODING, deserialize (VI_ID_CONSTR), VI_OPTIONS)")));
    }
  itc_free (it);
  log_debug ("Dumping the schema done");
}


static void
log_rd_blobs (it_cursor_t * itc, row_delta_t * rd)
{
  dbe_key_t * key = rd->rd_key;
  int ctr = 0;
  itc->itc_row_key = key;
  itc->itc_insert_key = key;
  /* printf ("### %ld >\n", key_id); */
  DO_CL (cl, key->key_row_var)
    {
      dtp_t dtp = cl->cl_sqt.sqt_col_dtp;
      if (IS_BLOB_DTP (dtp))
	{
	  int nth = rd->rd_key->key_is_col ? ctr : cl->cl_nth;
	  caddr_t val = rd->rd_values[nth];
	  if (DV_DB_NULL == DV_TYPE_OF (val))
	    continue;
	  dtp = val[0];
	  if (DV_COL_BLOB_SERIAL == dtp)
	    dtp = cl->cl_sqt.sqt_col_dtp;
	  if (IS_BLOB_DTP (dtp))
	    {
		  dp_addr_t start = LONG_REF_NA (val + BL_DP);
		  dp_addr_t dir_start = LONG_REF_NA (val + BL_PAGE_DIR);
		  int64 diskbytes = INT64_REF_NA (val + BL_BYTE_LEN);
		  blob_log_write (itc, start, dtp, dir_start, diskbytes,
				  cl->cl_col_id, key->key_table->tb_name);
		}
	    }
      ctr++;
    }
  END_DO_CL;
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
      bh_fetch_dir (lt, bh);
    }
  n_pages = box_length ((caddr_t) bh->bh_pages);
  if (BLOB_OK != blob_check (bh))
    return 0;
  bh_read_ahead (NULL, bh, 0, bh->bh_diskbytes);
  while (start)
    {
      uint32 timestamp;
      int type;

      if (pg_inx >= n_pages)
	{
	  log_warning ("blob has nmore pages than pages in page dir.  Can be cyclic.)  Start )= %d", bh->bh_page);
	  status = 0;
	  break;
	}
      if (start != bh->bh_pages[pg_inx])
	{
	  log_warning ("blob page dir dp  %d  differs from linked list dp = %d start = %d.",
		       bh->bh_pages[pg_inx], start, bh->bh_page);
	  status = 0;
	  break;
	}

      ITC_IN_KNOWN_MAP (itc, start);
      page_wait_access (itc, start, NULL, &buf, PA_READ, RWG_WAIT_ANY);
      if (!buf || PF_OF_DELETED == buf)
	{
	  log_warning ("Attempt to read deleted blob dp = %d start = %d.",
	      start, bh_page);
	  status = 0;
	  break;
	}
      type = SHORT_REF (buf->bd_buffer + DP_FLAGS);
      timestamp = LONG_REF (buf->bd_buffer + DP_BLOB_TS);

      if ((DPF_BLOB != type) &&
	  (DPF_BLOB_DIR != type))
	{
	  log_warning ("wrong blob type blob dp = %d start = %d\n", start, bh_page);
	  status = 0;
	  page_leave_outside_map (buf);
	  break;
	}

      if ((bh_timestamp != BH_ANY) && (bh_timestamp != timestamp))
	{
	  log_warning ("Dirty read of blob dp = %d start = %d.",
	      start, bh_page);
	  status = 0;
	  page_leave_outside_map (buf);
	  break;
	}
      start = LONG_REF (buf->bd_buffer + DP_OVERFLOW);
      if (buf)
	page_leave_outside_map (buf);
      pg_inx += 1;
    }
  itc_free (itc);

  dk_free_box ((caddr_t) bh);
  return status;
}


static int
bkp_check_and_recover_blob_cols (it_cursor_t * itc, db_buf_t row)
{
  key_ver_t kv = IE_KEY_VERSION (row);
  dbe_key_t * key = itc->itc_insert_key->key_versions[kv];
  int updated = 0;


  itc->itc_row_key = key;
  itc->itc_row_data = row;
  DO_CL (cl, key->key_row_var)
    {
      dtp_t dtp = cl->cl_sqt.sqt_dtp;
      if (IS_BLOB_DTP (dtp))
	{
	  int off, len;
	      if (ITC_NULL_CK (itc, (*cl)))
		continue;
	      KEY_PRESENT_VAR_COL (key, row, (*cl), off, len);
	      dtp = itc->itc_row_data[off];
	      if (IS_BLOB_DTP (dtp))
		{
		  if (!bkp_check_blob_col (itc, itc->itc_row_data + off, key, cl))
		    {
		      char *col_name = __get_column_name (cl->cl_col_id, key);
		      dtp_t *col = itc->itc_row_data + off;
		      log_error ("will have to set blob for col %s in key %s to empty",
				 col_name, key->key_name);

		      INT64_SET_NA (col + BL_CHAR_LEN, 0L);
		      INT64_SET_NA (col + BL_BYTE_LEN, 0L);
		      updated = 1;
		    }
		}
	}
    }
  END_DO_CL;
  return updated;
}

extern dk_mutex_t * log_write_mtx;

int
lt_backup_flush (lock_trx_t * lt, int do_commit)
{
  int rc;
  mutex_enter (log_write_mtx);
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
      mutex_leave (log_write_mtx);
      return rc;
    }
  mutex_leave (log_write_mtx);

  lt->lt_blob_log = NULL;
  /* not in -d mode, only with backup () function */
  strses_flush (lt->lt_log);
  lt->lt_log->dks_bytes_sent = 0;
  return LTE_OK;
}


dbe_key_t *
key_migrate_to (dbe_key_t * key)
{
  key_id_t next = key->key_migrate_to;
  if (!next)
    return NULL;
  return sch_id_to_key (wi_inst.wi_schema, next);
}


int
key_is_recoverable (key_id_t key_id)
{
  dbe_key_t * migr, * key = sch_id_to_key (wi_inst.wi_schema, key_id);
  if (!key)
    return 0;
  if (!recoverable_keys)
    return 1;
  if (gethash ((void*)(ptrlong)key_id, recoverable_keys))
    return 1;
  for (migr = key_migrate_to (key); migr; migr = key_migrate_to (migr))
    {
      if (key_is_recoverable (migr->key_id))
	return 1;
    }
  DO_SET (dbe_key_t *, super, &key->key_supers)
    {
      if (key_is_recoverable (super->key_id))
	return 1;
    }
  END_DO_SET();
  return 0;
}


void
row_log (it_cursor_t * itc, buffer_desc_t * buf, int map_pos, dbe_key_t * row_key, row_delta_t * rd)
{
  union {
  void * dummy;
  dtp_t temp[4096];
  } temp_un;
  if (row_key->key_is_bitmap)
    {
      db_buf_t bm;
      int off;
      short bm_len;
      bitno_t bm_start;
      db_buf_t row = BUF_ROW (buf, map_pos);
      BIT_COL (bm_start, buf, row, row_key);
      KEY_PRESENT_VAR_COL (row_key, row, (*row_key->key_bm_cl), off, bm_len);
      bm = row + off;
      memset (&itc->itc_bp, 0, sizeof (itc->itc_bp));
      pl_set_at_bit ((placeholder_t *) itc, bm, bm_len, bm_start, BITNO_MIN, 0);
      itc->itc_bp.bp_at_end = 0;
      do {
	rd->rd_temp = &(temp_un.temp[0]);
	rd->rd_temp_max = sizeof (temp_un.temp);
	page_row_bm (buf, map_pos, rd, RO_ROW, itc);
	rd->rd_n_values--; /*no bitmap string */
	log_insert (itc->itc_ltrx, rd, LOG_KEY_ONLY | (rd->rd_key->key_id < DD_FIRST_PRIVATE_OID ? INS_REPLACING : INS_NORMAL));
	rd->rd_n_values++;
	pl_next_bit ((placeholder_t*)itc, bm, bm_len, bm_start, 0);
	rd_free (rd);
      } while (!itc->itc_bp.bp_at_end);
    }
  else
    {
	rd->rd_temp = &(temp_un.temp[0]);
	rd->rd_temp_max = sizeof (temp_un.temp);
      page_row (buf, map_pos, rd, RO_ROW);
      log_insert (itc->itc_ltrx, rd, LOG_KEY_ONLY | (rd->rd_key->key_id < DD_FIRST_PRIVATE_OID ? INS_REPLACING : INS_NORMAL));
      log_rd_blobs (itc, rd);
      rd_free (rd);
    }
}

void
log_recov_anyfy (caddr_t* values, mem_pool_t * mp)
{
  /* if an any column has string values these must be anified because a string in an any column in an rd will be mistaken for a dv serialization. */
  int inx;
  DO_BOX (caddr_t, val, inx, values)
    {
      dtp_t dtp = DV_TYPE_OF (val);
      if (DV_STRING == dtp || DV_WIDE == dtp)
	{
	  caddr_t err = NULL;
	  values[inx] = mp_box_to_any_1 (val, &err, mp, 0);
	  if (err)
	    {
	      dk_free_tree (err);
	      err = NULL;
	      values[inx] = mp_box_to_any_1 ((caddr_t)0, &err, mp, 0);
	    }
	}
    }
  END_DO_BOX;
}


int
col_row_log (it_cursor_t * itc, buffer_desc_t * buf, int map_pos, dbe_key_t * row_key, row_delta_t * rd)
{
  mem_pool_t * mp = mem_pool_alloc ();
  int row, n_rows = -1, n;
  itc->itc_map_pos = map_pos;
  itc->itc_row_data = BUF_ROW (buf, map_pos);
  itc_ensure_col_refs (itc);
  DO_CL (cl, row_key->key_row_var)
    {
      col_data_ref_t * cr = itc->itc_col_refs[cl->cl_nth - row_key->key_n_significant];
      if (!cr)
	itc->itc_col_refs[cl->cl_nth - row_key->key_n_significant] = cr = itc_new_cr (itc);
      itc_fetch_col (itc, buf, cl, 0, COL_NO_ROW);
      cr->cr_pages[0].cp_ceic = (ce_ins_ctx_t*)cr_mp_array (cr, mp, 0, COL_NO_ROW, 0);
      if (DV_ANY == cl->cl_sqt.sqt_col_dtp)
	log_recov_anyfy ((caddr_t*)cr->cr_pages[0].cp_ceic, mp);
      n = BOX_ELEMENTS (cr->cr_pages[0].cp_ceic);
      if (-1 == n_rows)
	n_rows = n;
      else if (n_rows != n)
	{
	  FILE * fp = fopen ("recovery.txt", "a");
	  log_error ("Columns of different length in seg key %s L=%d, r = %d", row_key->key_name, buf->bd_page, map_pos);
	  fprintf (fp, "error at map_pos: %d\n", map_pos);
	  fclose (fp);
	  mp_free (mp);
	  itc_col_leave (itc, 0);
	  return 1;
	  STRUCTURE_FAULT;
	}
    }
  END_DO_CL;
  rd->rd_key = row_key;
  rd->rd_n_values = row_key->key_n_parts - row_key->key_n_significant;
  for (row = 0; row < n_rows; row++)
    {
      int col = 0, rd_inx;
      DO_CL (cl, row_key->key_row_var)
	{
	  caddr_t val, err = NULL;
	  col_data_ref_t * cr = itc->itc_col_refs[cl->cl_nth - row_key->key_n_significant];
	  if (col < row_key->key_n_significant)
	    rd_inx = row_key->key_part_in_layout_order[col];
	  else
	    rd_inx = col;
	  val = ((caddr_t*)cr->cr_pages[0].cp_ceic)[row];
	  if (IS_BLOB_DTP (cl->cl_sqt.sqt_col_dtp))
	    {
	      if (IS_BLOB_HANDLE_DTP (DV_TYPE_OF (val)))
		{
		  caddr_t ser = mp_alloc_box (mp, DV_BLOB_LEN, DV_STRING);
		  bh_to_dv ((blob_handle_t *)val, (db_buf_t)ser, cl->cl_sqt.sqt_col_dtp);
		  val = ser;
		}
	      else
		val = mp_box_to_any_1 (val, &err, mp, 0);
	    }
	  rd->rd_values[rd_inx] = val;
	  col++;
	}
      END_DO_CL;
      log_insert (itc->itc_ltrx, rd, LOG_KEY_ONLY | INS_SOFT);
      log_rd_blobs (itc, rd);
    }
  mp_free (mp);
  itc_col_leave (itc, 0);
  return 0;
}


void
log_page (it_cursor_t * it, buffer_desc_t * buf, void* dummy)
{
  db_buf_t page;
  int l;
  key_id_t k_id;
  int rc;
  slice_id_t slice = buf->bd_storage->dbs_slice;
  dp_addr_t parent_dp;
  int any = 0, n_bad_rows = 0, n_rows = 0, colerr = 0;
  dbe_key_t * row_key, * page_key = NULL;
  LOCAL_RD (rd);
  page = buf->bd_buffer;
  k_id = LONG_REF (page + DP_KEY_ID);
  page_key = sch_id_to_key (wi_inst.wi_schema, k_id);
  if (!page_key)
    {
      if (!recoverable_keys)
	log_error ("Skipping page L=%d with unknown page key %d", buf->bd_page, k_id);
      return;
    }
  if (!key_is_recoverable (k_id))
    return;
  parent_dp = (dp_addr_t) LONG_REF (buf->bd_buffer + DP_PARENT);
  if (parent_dp && parent_dp > buf->bd_storage->dbs_n_pages)
    STRUCTURE_FAULT;

  buf->bd_tree = page_key->key_fragments[slice]->kf_it;
  itc_from_it (it, buf->bd_tree);
  if (!is_crash_dump)
    {
  /* internal rows consistence check */
      buf_order_ck (buf);
    }
  if (it->itc_insert_key != page_key)
    itc_col_free (it);
  if (page_key->key_is_col)
    {
      if (!it->itc_is_col)
	itc_col_init (it);
      itc_ce_check (it, buf, 0);
      it->itc_col_row = COL_NO_ROW;
    }
  DO_ROWS (buf, map_pos, row, NULL)
    {
      if (row - buf->bd_buffer  > PAGE_SZ)
	{
	  STRUCTURE_FAULT;
	}
      else
	{
	  key_ver_t kv = IE_KEY_VERSION (row);
	  if (KV_LEFT_DUMMY == kv)
	    goto next;
	  if (!pg_row_check (buf, map_pos, 0))
	    {
	      log_error ("Row failed row check on L=%d", buf->bd_page);
	      n_rows++;
	      n_bad_rows++;
	      goto next;
	    }
	  if (KV_LEAF_PTR == kv)
	    goto next;
	  row_key = page_key->key_versions[kv];
	  l = row_length (row, row_key);
	  if ((row - buf->bd_buffer) + l > PAGE_SZ)
	    {
	      n_rows++;
	      n_bad_rows++;
	      goto next;
	    }
	  if (page_key->key_is_col)
	    colerr += col_row_log (it, buf, map_pos, row_key, &rd);
	  else
	    {
	  if (bkp_check_and_recover_blobs)
	    {
	      if (bkp_check_and_recover_blob_cols (it, row))
		buf_set_dirty (buf);
	    }
	  row_log (it, buf, map_pos, row_key, &rd);
	    }
	  any++;
	  n_bad_rows = 0;
	  n_rows++;
	}
next:
      if (n_rows > PM_MAX_ENTRIES || n_bad_rows > 10)
	STRUCTURE_FAULT;
    }
  END_DO_ROWS;
  /* we dump buf here if have skipped rows */
  if (colerr)
    {
      FILE * fp = fopen ("recovery.txt", "a");
      dbg_page_map_f (buf, fp);
      fclose (fp);
    }
  if (any)
    {
      if (!is_crash_dump)
	{
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
      db_recover_key (KI_COLS, 	KI_COLS);
      db_recover_key (KI_COLS_ID, 	KI_COLS_ID);
      db_recover_key (KI_KEYS, 		KI_KEYS);
      db_recover_key (KI_KEYS_ID, 		KI_KEYS_ID);
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

  log_checkpoint (wi_inst.wi_master, NULL, CPT_DB_TO_LOG);
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
#define HAVE_DIRECT_H
#endif

#ifdef HAVE_DIRECT_H
#include <direct.h>
#include <io.h>
#define PATH_MAX	 MAX_PATH
#else
#include <dirent.h>
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
	  if ((fd = fd_open(fname, LOG_OPEN_FLAGS)) < 0)
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
      if ((fd = fd_open (fname, LOG_OPEN_FLAGS)) < 0)
	{
	  char *errmsg = strerror(errno);

	  PrpcSessionFree (ses);
	  if (!srv_have_global_lock(THREAD_CURRENT_THREAD))
	    LEAVE_CPT(qi->qi_trx);

	  sqlr_new_error ("42000", "FA038", "Cannot open backup file %s: %s",
	    fname, errmsg);
        }
    }

  FTRUNCATE (fd, 0);
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
  sec_check_dba (qi, "backup_prepare");
  backup_prepare (qi, file);
  return NULL;
}


caddr_t
bif_backup_row (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
#ifndef KEYCOMP
  dbe_key_t * key;
  long l;
  it_cursor_t itc_auto;
  it_cursor_t *itc = &itc_auto;
  query_instance_t *qi = (query_instance_t *) qst;
  lock_trx_t *lt = qi->qi_trx;
  caddr_t row = bif_arg (qst, args, 0, "backup_row");
  dtp_t tag = DV_TYPE_OF (row);
  ITC_INIT (itc, qi->qi_space, qi->qi_trx);
  sec_check_dba (qi, "backup_row");
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

#endif
  return NULL;
}


caddr_t
bif_backup_flush (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int rc;
  query_instance_t *qi = (query_instance_t *) qst;
  lock_trx_t *lt = qi->qi_trx;
  sec_check_dba (qi, "backup_flush");
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
  sec_check_dba (qi, "backup_close");
  if (!lt->lt_backup)
    sqlr_new_error ("42000", "SR116", "Transaction not in backup mode");

  backup_close (qi->qi_trx);
  if (!srv_have_global_lock(THREAD_CURRENT_THREAD))
    LEAVE_CPT(qi->qi_trx);
  log_info ("Backup finished.");
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
long dpf_count[14];

extern long blob_pages_logged;
void
dbs_pages_to_log (dbe_storage_t * storage, char *mode, volatile dp_addr_t start_dp, volatile dp_addr_t end_dp)
{
  int n_logged = 0, n_non_index = 0, n_bad_dpf = 0;
  buffer_desc_t *buf;
  volatile dp_addr_t page_no = 3;
  volatile dp_addr_t end_page;
  it_cursor_t *it;

  it = itc_create (NULL, bootstrap_cli->cli_trx);
  bootstrap_cli->cli_trx->lt_replicate = REPL_LOG;
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
	    {
	      IN_DBS (storage);
	      dbs_locate_free_bit (storage, page_no, &array, &page, &inx, &bit);
	      LEAVE_DBS (storage);
	    }
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
		      if (fl < 13)
			dpf_count[fl]++;
		      else
			n_bad_dpf++;
		      n_non_index++;
#ifdef DBG_BLOB_PAGES_ACCOUNT
                      if (fl == DPF_BLOB)
			db_dbg_account_check_page_in_hash (buf->bd_page);
#endif
		    }
		  buf->bd_is_write = 0;
		  buf->bd_readers = 0;
		}
	    }
	}
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
  log_checkpoint (wi_inst.wi_master, NULL, CPT_DB_TO_LOG);

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
      log_debug ("Dumping the registry");
      db_log_registry (bootstrap_cli->cli_trx->lt_log);
      lt_backup_flush (bootstrap_cli->cli_trx, 1);
    }

  log_debug ("Dumping the data");
  dbs_pages_to_log (wi_inst.wi_master, mode, crashdump_start_dp, crashdump_end_dp);
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
      sqlr_new_error ("40009", "SR118", "%s", err);
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

static caddr_t
bif_log_index (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  dbe_key_t * key = bif_key_arg (qst, args, 0, "log_index");
  buffer_desc_t *buf;
  it_cursor_t *itc;

  sec_check_dba (qi, "backup_index");
  memset (levels, 0, sizeof (levels));

  itc = itc_create (NULL , qi->qi_trx);
  itc_from (itc, key, qi->qi_client->cli_slice);
  itc->itc_isolation = ISO_UNCOMMITTED;
  ITC_FAIL (itc)
    {
      itc->itc_random_search = RANDOM_SEARCH_ON; /* do not use root image cache */
      buf = itc_reset (itc);
      itc->itc_random_search = RANDOM_SEARCH_OFF;
      itc_try_land (itc, &buf);
      /* the whole traversal is in landed (PA_WRITE() mode. page_transit_if_can will not allow mode change in transit */
      if (!buf->bd_content_map)
	{
	  log_error ("Blog ref'referenced as index tree top node dp=%d key=%s\n", buf->bd_page, itc->itc_insert_key->key_name);
	}
      else
	walk_dbtree (itc, &buf, 0, log_page, 0);
      itc_page_leave (itc, buf);
    }
  ITC_FAILED
    {
      itc_free (itc);
    }
  END_FAIL (itc);
  itc_free (itc);
  return NULL;
}

int
fds_same_file (int fd1, int fd2)
{
#ifndef WIN32
  struct stat stat1, stat2;
  if (fstat (fd1, &stat1) < 0)
    return -1;
  if (fstat (fd2, &stat2) < 0)
    return -1;
  return (stat1.st_dev == stat2.st_dev) && (stat1.st_ino == stat2.st_ino);
#else
  return 0;
#endif
}

static caddr_t
bif_read_log (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_session_t * in = (dk_session_t *) bif_strses_arg (qst, args, 0, "read_log");
  OFF_T off;
  int bytes;
  caddr_t *header;
  dk_session_t trx_ses;
  dk_session_t *str_in = &trx_ses;
  scheduler_io_data_t trx_sio;
  caddr_t trx_string;
  dk_set_t set = NULL;
  dbe_storage_t * dbs = wi_inst.wi_master;
  dk_session_t * volatile log_ses;
  int fd1, fd2, need_mtx = 0;

  log_ses = dbs->dbs_log_session;
  fd1 = tcpses_get_fd (log_ses->dks_session);
  fd2 = in->dks_session->ses_file ? in->dks_session->ses_file->ses_file_descriptor : -1;
  if (fd2 >= 0 && fds_same_file (fd1, fd2) > 0)
    {
      mutex_enter (log_write_mtx);
      need_mtx = 1;
    }
  memset (&trx_ses, 0, sizeof (trx_ses));
  memset (&trx_sio, 0, sizeof (trx_sio));
  SESSION_SCH_DATA (&trx_ses) = &trx_sio;

  header = (caddr_t *) read_object (in);
  if (!DKSESSTAT_ISSET (in, SST_OK))
    {
      if (need_mtx) mutex_leave (log_write_mtx);
      return NEW_DB_NULL;
    }
  if (!log_check_header (header))
    {
      dk_free_tree (header);
      if (need_mtx) mutex_leave (log_write_mtx);
      sqlr_new_error ("22023", "RL002", "Invalid log entry in replay.");
    }
  bytes = (int) unbox (header[LOGH_BYTES]);
  trx_string = (char *) dk_alloc (bytes + 1);
  CATCH_READ_FAIL (in)
      session_buffered_read (in, trx_string, bytes);
  FAILED
    {
      dk_free (trx_string, bytes + 1);
      dk_free_tree (header);
      if (need_mtx) mutex_leave (log_write_mtx);
      sqlr_new_error ("22023", "RL002", "Invalid log entry in replay.");
    }
  END_READ_FAIL (in);
  str_in->dks_in_buffer = trx_string;
  str_in->dks_in_read = 0;
  str_in->dks_in_fill = bytes;
  dk_set_push (&set, header);
  CATCH_READ_FAIL (str_in)
    {
      char op, flag;
      long u_id = 0, count;
      caddr_t count64 = 0;
      caddr_t row = NULL, cols = NULL, vals = NULL;
      dk_set_t res = NULL;
      dbe_key_t * key;

      while (str_in->dks_in_read != str_in->dks_in_fill)
	{
	  res = NULL;
	  op = session_buffered_read_char (str_in);
	  dk_set_push (&res, box_num (op));
	  switch (op)
	    {
	      case LOG_KEY_INSERT:
		  flag = session_buffered_read_char (str_in);
		  dk_set_push (&res, box_num (flag));
	      case LOG_INSERT:
	      case LOG_INSERT_SOFT:
	      case LOG_INSERT_REPL:
		  row = scan_session (str_in);
		  key = sch_id_to_key (wi_inst.wi_schema, unbox (((caddr_t *)row)[0]));
		  DO_CL (cl, key->key_row_var)
		    {
		      dtp_t dtp = cl->cl_sqt.sqt_col_dtp;
		      if (IS_BLOB_DTP (dtp))
			{
			  int inx = cl->cl_nth + 1; /* zero pos in row is the key id */
			  caddr_t val = ((caddr_t *)row)[inx];
			  dtp = DV_TYPE_OF (val);
			  if (DV_STRING != dtp)
			    continue;
			  dtp = val[0];
			  if (IS_BLOB_DTP (dtp))
			    {
			      dk_free_tree (val);
			      ((caddr_t *)row)[inx] = box_dv_short_string ("<BLOB>");
			    }
			}
		    }
		  END_DO_CL;
		  dk_set_push (&res, row);
		  break;
	      case LOG_DELETE:
	      case LOG_KEY_DELETE:
		  row = scan_session (str_in);
		  dk_set_push (&res, row);
		  break;
	      case LOG_UPDATE:
		    {
		      int inx;
		      row = scan_session (str_in);
		      cols = scan_session (str_in);
		      vals = scan_session (str_in);
		      DO_BOX (caddr_t, v, inx, (caddr_t *)vals)
			{
			  if (DV_TYPE_OF (v) == DV_BLOB_HANDLE)
			    {
			      dk_free_tree (v);
			      ((caddr_t *)vals)[inx] = box_dv_short_string ("<BLOB>");
			    }
			}
		      END_DO_BOX;
		      dk_set_push (&res, row);
		      dk_set_push (&res, cols);
		      dk_set_push (&res, vals);
		    }
		  break;
	      case LOG_TEXT:
		  row = scan_session (str_in);
		  dk_set_push (&res, row);
		  break;
	      case LOG_USER_TEXT:
		  u_id = read_long (str_in);
		  row = scan_session (str_in);
		  dk_set_push (&res, box_num (u_id));
		  dk_set_push (&res, row);
		  break;
	      case LOG_SEQUENCE:
		  row = scan_session (str_in);
		  count = read_long (str_in);
		  dk_set_push (&res, row);
		  dk_set_push (&res, box_num (count));
		  break;
	      case LOG_SEQUENCE_64:
		  row = scan_session (str_in);
		  count64 = scan_session_boxing (str_in);
		  dk_set_push (&res, row);
		  dk_set_push (&res, count64);
		  break;
	      case LOG_DD_CHANGE:
	      case LOG_SC_CHANGE_1:
	      case LOG_SC_CHANGE_2:
		  break;
	    }
	  dk_set_push (&set, list_to_array (dk_set_nreverse (res)));
	}
    }
  FAILED
    {
      dk_set_push (&set, box_dv_short_string ("Error reading trx string"));
    }
  END_READ_FAIL (str_in);
  log_skip_blobs_1 (in);
  if (need_mtx) mutex_leave (log_write_mtx);

  dk_free (trx_string, bytes + 1);
  if (BOX_ELEMENTS (args) > 1 && ssl_is_settable (args[1]))
    {
      off = in->dks_bytes_received - in->dks_in_fill + in->dks_in_read;
      qst_set (qst, args[1], box_num (off));
    }
  return list_to_array (dk_set_nreverse (set));
}

void
recovery_init (void)
{
  bif_define ("backup_prepare", bif_backup_prepare);
  bif_define ("backup_row", bif_backup_row);
  bif_define ("backup_flush", bif_backup_flush);
  bif_define ("backup_close", bif_backup_close);
  bif_define ("backup_index", bif_log_index);
  bif_define ("read_log", bif_read_log);
#if 0
  bif_define ("crash_recovery_log_check", bif_crash_recovery_log_check);
#endif
}


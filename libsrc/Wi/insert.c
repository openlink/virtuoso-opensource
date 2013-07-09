/*
 *  insert.c
 *
 *  $Id$
 *
 *  Insert
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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


#ifdef PAGE_TRACE
#define rdbg_printf_2(q) printf q
#endif


void
pg_map_clear (buffer_desc_t * buf)
{
#ifdef PAGE_TRACE
  memset (&buf->bd_content_map->pm_entries[0], 0, buf->bd_content_map->pm_size * sizeof (short));
  /* Looks nicer in debugger. */
#endif
  buf->bd_content_map->pm_filled_to = DP_DATA;
  buf->bd_content_map->pm_bytes_free = PAGE_SZ - DP_DATA;
  buf->bd_content_map->pm_count = 0;
  page_write_gap (buf->bd_buffer + DP_DATA, PAGE_DATA_SZ);
}


#define PG_ERR_OR_GPF_T \
  { if (assertion_on_read_fail) GPF_T; \
    else return WI_ERROR; }



void
map_resize (page_map_t ** pm_ret, int new_sz)
{
  page_map_t * pm = *pm_ret;
  page_map_t * new_pm = (page_map_t *) resource_get (PM_RC (new_sz));
#ifdef VALGRIND
  new_pm->pm_entries[new_sz - 1] = 0xc0c0; /* for valgrind */
#endif
  memcpy (new_pm, pm, PM_ENTRIES_OFFSET + sizeof (short) * pm->pm_count);
  *pm_ret = new_pm;
  resource_store (PM_RC (pm->pm_size), (void*) pm);
  new_pm->pm_size = new_sz;
}


void
map_append (page_map_t ** pm_ret, int ent)
{
  page_map_t * pm = *pm_ret;
  if (pm->pm_count + 1 > pm->pm_size)
    {
      int new_sz = PM_SIZE (pm->pm_size);
      if (pm->pm_count + 1 > PM_MAX_ENTRIES)
	GPF_T1 ("page map entry count overflow");
      map_resize (pm_ret, new_sz);
      pm = *pm_ret;
    }
  pm->pm_entries[pm->pm_count++] = ent;
}


#define dbg_page_map_to_file(buf) \
  dbg_page_map_log (buf, "bufdump.txt", "Inconsistent page");


row_size_t
page_gap_length (db_buf_t page, row_size_t pos)
{
  int n = 0;
  for (;;)
    {
      int prev_n = n;
      dtp_t kv;
      if (n + pos == PAGE_SZ)
	return n;
      if (n + pos >= PAGE_SZ)
	STRUCTURE_FAULT1 ("gap beyond end of page");
      if ((n + pos) & 1)
	STRUCTURE_FAULT1 ("odd pos in looking for gap");
      kv = page[n + pos];
      switch (kv)
	{
	case KV_GAP:
	  n += page[pos + n + 1];
	  break;
	case KV_LONG_GAP:
	  n += (page[pos + n + 1] << 8) + page[pos + n + 2];
	  break;
	default:
	  return n;
	}
      if (n == prev_n) STRUCTURE_FAULT1 ("zero length gap on page");
    }
}

int
pg_make_map (buffer_desc_t * buf)
{
  db_buf_t page = buf->bd_buffer;
  key_id_t k_id = LONG_REF (page + DP_KEY_ID);
  dbe_key_t * pg_key;
  int free = PAGE_SZ - DP_DATA, sz;
  int pos = DP_DATA;
  page_map_t *map = buf->bd_content_map;
  int len, inx = 0, fill = DP_DATA;

  buf->bd_content_map = NULL;
  if (!wi_inst.wi_schema)
    {
      log_error (
	  "Trying to access the database schema data before the schema has been initialized. "
	  "This is usually caused by an unrecoverable corrupted database file. ");
      call_exit (-1);
    }

  pg_key = KI_TEMP == k_id ?
      buf->bd_tree->it_key :
      sch_id_to_key (wi_inst.wi_schema, k_id);
  if (!map)
    {
      map = (page_map_t *) resource_get (PM_RC (PM_SZ_1));
    }
  if (pos && !pg_key)
    {
      if (assertion_on_read_fail)
	GPF_T1 ("page read with no key defd");
      map->pm_count = 0;
      buf->bd_content_map = map;
      return 0;
    }
  while (pos)
    {
      int gap;
      if (pos == PAGE_SZ)
	break;
      if (pos >= PAGE_SZ)
	PG_ERR_OR_GPF_T;	/* Link over end */
      gap = page_gap_length (page, pos);
      if (gap)
	{
	  pos += gap;
	  continue;
	}
      len = row_length (page + pos, pg_key);
      if (!len) STRUCTURE_FAULT1 ("zero len on page, gap marker missing");
      len = ROW_ALIGN (len);
      if (len < 0)
	{
	  log_error ("Structure inconsistent, negative row length,  on key=%s, dp=%ld, physical dp=%ld",
	      (pg_key && pg_key->key_name ? pg_key->key_name : "TEMP KEY"),
	      buf->bd_page, buf->bd_physical_page);
	  dbg_page_map_to_file (buf);
	  STRUCTURE_FAULT;
	}
      free -= len;
      if (inx >= map->pm_size)
	{
	  map->pm_count = inx;
	  map_resize (&map, PM_SIZE (map->pm_size));
	}
      map->pm_entries[inx++] = pos;
      if (pos + len > fill)
	fill = pos + len;
      if (fill > PAGE_SZ)
	{
	  log_error ("Structure inconsistent, page filled beyond page end, on key=%s, dp=%ld, physical dp=%ld",
	      (pg_key && pg_key->key_name ? pg_key->key_name : "TEMP KEY"),
	      buf->bd_page, buf->bd_physical_page);
	  dbg_page_map_to_file (buf);
	  STRUCTURE_FAULT;
	}
      pos += len;
      if (inx >= PM_MAX_ENTRIES)
	{
	  log_error ("Structure inconsistent, too many rows on page,  on key=%s, dp=%ld, physical dp=%ld",
	      (pg_key && pg_key->key_name ? pg_key->key_name : "TEMP KEY"),
	      buf->bd_page, buf->bd_physical_page);
	  dbg_page_map_to_file (buf);
	  STRUCTURE_FAULT;
	}
    }
  if (free < 0)
    {
      log_error ("Structure inconsistent, negative free space on page,  on key=%s, dp=%ld, physical dp=%ld",
	  (pg_key && pg_key->key_name ? pg_key->key_name : "TEMP KEY"),
	  buf->bd_page, buf->bd_physical_page);
      dbg_page_map_to_file (buf);
      STRUCTURE_FAULT;
    }
  map->pm_bytes_free = free;
  map->pm_count = inx;
  map->pm_filled_to = fill;
  sz = PM_SIZE (map->pm_count);
  if (sz < map->pm_size)
    {
      map_resize (&map, sz);
    }
  buf->bd_content_map = map;
  return 0;
}


#define REF_CK(buf, irow, ref) \
{\
  if ((ROW_NO_MASK & ref) >= irow) { log_error ("forward ref in compression entry %d\n", irow);error++; } \
  if ((ROW_NO_MASK & ref) >= buf->bd_content_map->pm_count) { log_error ("Beyond pm_count  ref in compression entry %d\n", irow); error++;} \
}

void pg_check_map_1 (buffer_desc_t * buf);

int n159;


void
b159ck ()
{
  int inx;
  n159++;
  return;
  for (inx = 0; inx < 4; inx++)
    {
      buffer_desc_t * buf = &wi_inst.wi_bps[inx]->bp_bufs[150];
      if (buf->bd_page == 840)
	{
	  if (LONG_REF (buf->bd_buffer + DP_PARENT) < 0) GPF_T1 ("the bad parent link");
	  pg_check_map_1 (buf);
	}
    }
}


int
pg_row_check (buffer_desc_t * buf, int irow, int gpf_on_err)
{
  db_buf_t row = buf->bd_buffer + buf->bd_content_map->pm_entries[irow];
  dbe_key_t * key = buf->bd_tree->it_key;
  row_ver_t rv = IE_ROW_VERSION (row);
  key_ver_t kv = IE_KEY_VERSION (row);
  int inx = 0, row_len, error = 0;
  if (KV_LEFT_DUMMY == kv)
    return 1;
  if (kv >= KEY_MAX_VERSIONS || !key->key_versions[kv])
    {
      log_error ("row %d with bad kv %d for key %s L=%d", irow, (int)kv, it_title (buf->bd_tree), buf->bd_page);
      error = 1;
      goto end;
    }
  key = key->key_versions[kv];
  row_len = row_length (row, key);
  if (row_len > MAX_ROW_BYTES)
    {
      error++;
      log_error ("row length %d in row %d over max", row_len, irow);
    }
  DO_ALL_CL (cl, key)
    {
      if (cl->cl_row_version_mask & rv)
	{
	  unsigned short ref = SHORT_REF (row + cl->cl_pos[rv]);
	  if (0 == (row[cl->cl_null_flag[rv]] & cl->cl_null_mask[rv]))
	    {
	      REF_CK (buf, irow, ref);
	    }
	}
      else if (dtp_is_var (cl->cl_sqt.sqt_dtp))
	{
	  short off, len;
	  KEY_PRESENT_VAR_COL (key, row, (*cl), off, len);
	  if (DV_ANY == cl->cl_sqt.sqt_dtp &&  0 == (row[cl->cl_null_flag[rv]] & cl->cl_null_mask[rv]))
	    {
	      if (row[off] < 180) STRUCTURE_FAULT1 ("any col with bad dtp");
	    }
	  if (len & COL_VAR_SUFFIX)
	    {
	      short ref = SHORT_REF_NA (row + off);
	      REF_CK (buf, irow, ref);
	      if (len > row_len)
		{
		  error++;
		  log_error ("len of cl %d in row %d over end %d > %d\n", cl->cl_col_id, irow, len, row_len);
		}
	    }
	}
      inx++;
      if (inx == key->key_n_significant && KV_LEAF_PTR == kv)
	goto done; /* the macro is 2 loops, no break */
    }
  END_DO_ALL_CL;
 done:
  if (key->key_is_bitmap && KV_LEAF_PTR != kv)
    {
      short off, len;
      KEY_PRESENT_VAR_COL (key, row, (*key->key_bm_cl), off, len);
      bm_ck (row + off, len);
    }
 end:
  if (error)
    {
      if (gpf_on_err)
	{
	  STRUCTURE_FAULT1 ("row format check failed");
	}
      else
	return 0;
    }
  return 1;
}


void
pg_check_map_1 (buffer_desc_t * buf)
{
  page_map_t org_map;
  int org_free = buf->bd_content_map->pm_bytes_free, org_fill;
#if 0
  int pos, ctr = 0;
#endif
  memcpy (&org_map, buf->bd_content_map, ((ptrlong)(&((page_map_t*)0)->pm_entries)) + 2 * buf->bd_content_map->pm_count);
  /* for debug, copy the entries, the whole struct may overflow addr space. */
  if (!buf->bd_is_write && !wi_inst.wi_checkpoint_atomic)
    GPF_T1 ("must have written access to buffer to check it");
#ifdef PAGE_DEBUG
  if (buf->bd_is_write && buf->bd_writer != THREAD_CURRENT_THREAD)
    GPF_T1 ("Must have write on buffer to check it");
#endif
  {
    short mx = 0;
    page_map_t * pm = buf->bd_content_map;
    int inx, ent;
    for (inx = 0; inx < pm->pm_count; inx++)
      {
	ent = pm->pm_entries[inx];
	if (ent > mx)
	  mx = ent;
      }
    if (mx)
      {
	int row_len = row_length (buf->bd_buffer + mx, buf->bd_tree->it_key);
	if (mx + row_len > pm->pm_filled_to) GPF_T1 ("pm_filled to not properly updated");
      }
  }
  pg_make_map (buf);
  if (org_free != buf->bd_content_map->pm_bytes_free)
    GPF_T1 ("map bytes free out of sync");
  org_map.pm_size = buf->bd_content_map->pm_size;
  if (org_map.pm_filled_to < buf->bd_content_map->pm_filled_to)
    GPF_T1 ("filled to of map is too low");
  org_fill = org_map.pm_filled_to;
  org_map.pm_filled_to = buf->bd_content_map->pm_filled_to;
  if (memcmp (&org_map, buf->bd_content_map, ((ptrlong)(&((page_map_t*)0)->pm_entries))
	      /* + 2 * buf->bd_content_map->pm_count */ ))
    GPF_T1 ("map not in sync with buf");
  org_map.pm_filled_to = org_fill;
  memcpy (buf->bd_content_map, &org_map, ((ptrlong)(&((page_map_t*)0)->pm_entries)) + 2 * org_map.pm_count);

#if 0
  /* debug code for catching insert/update of a particular row */
  page = buf->bd_buffer;
  pos = SHORT_REF (page + DP_FIRST);
  while (pos)
    {
      key_id_t ki = SHORT_REF (page + pos + IE_KEY_ID);
      if (1001 == ki)
	{
	  if (1000037 == LONG_REF (page + pos + 4)
	      && 1155072 == LONG_REF (page + pos + 12)
	      && 1369287 == LONG_REF_NA (page + pos + 4 +17))
	    ctr++;
	  if (ctr > 1)
	    printf ("bingbing\n");
	}
      pos = IE_NEXT (page + pos);
    }
#endif
  {
    int inx, error = 0;
    for (inx = 0; inx < buf->bd_content_map->pm_count; inx++)
      {
	if (!pg_row_check (buf, inx, 0))
	  error = 1;
      }
    if (error)
      {
	dbg_page_map_log (buf, "bad_page.log", "Page found bad in page_map_check_1\n");
	GPF_T1 ("pg_row_check errors, see bad_page.log and message log");
      }
  }
}

#ifndef pg_check_map
void
pg_check_map (buffer_desc_t * buf)
{
  pg_check_map_1 (buf);
}
#endif

void
pg_move_cursors (it_cursor_t ** temp_itc, int fill, buffer_desc_t * buf_from,
    int from, dp_addr_t page_to, int to, buffer_desc_t * buf_to)
{
  int n;
  it_cursor_t *it_list;
  if (!fill)
    return;
  assert (buf_from->bd_is_write && (!buf_to || buf_to->bd_is_write));
  for (n = 0; n < fill; n++)
    {
      it_list = temp_itc[n];
      if (!it_list)
	continue;
      if (ITC_DELETED == it_list->itc_map_pos
	  || (it_list->itc_page == buf_from->bd_page
	      && it_list->itc_map_pos == from))
	{
	  temp_itc[n] = NULL;
	  /* Once a cursor has been moved it will not move again
	     during the same pg_write_compact. Consider: x is moved to
	     future place, then the same place in pre-compacted is moved
	     someplace else.
	     If so the itc gets moved twice which is NEVER RIGHT */
	  it_list->itc_map_pos = to;
	  if (page_to != it_list->itc_page)
	    {
	      itc_unregister_inner (it_list, buf_from, 1);
	      it_list->itc_page = page_to;
	      itc_register (it_list, buf_to);
	    }
	}
    }
}


int
map_entry_after (page_map_t * pm, int at)
{
  int after = PAGE_SZ, inx;
  for (inx = 0; inx < pm->pm_count; inx++)
    {
      short ent = pm->pm_entries[inx];
      if (ent > at && ent < after)
	after = ent;
    }
  return after;
}


extern long  tc_pg_write_compact;
#define WRITE_NO_GAP ((buffer_desc_t *)1)







caddr_t
box_n_bin (dtp_t * bin, int len)
{
  caddr_t res = dk_alloc_box (len, DV_BIN);
  memcpy (res, bin, len);
  return res;
}



/* Statistics */
long right_inserts = 0;
long mid_inserts = 0;


/* Insert before entry at <at>, return pos of previous entry,
   0 if this is first */


int
map_insert (page_map_t ** map_ret, int at, int what)
{
  page_map_t * map = *map_ret;
  int inx, prev = 0, tmp;
  int ct = map->pm_count;
  if (map->pm_count == map->pm_size)
    {
      map_resize (map_ret, PM_SIZE (map->pm_size));
      map = *map_ret;
    }

  if (ct > PM_MAX_ENTRIES - 1)
    GPF_T1 ("Exceeded max entries in page map");
  if (at == 0 || ct == 0)
    {

      map->pm_entries[ct] = what;
      map->pm_count = ct + 1;
      if (ct)
	return (map->pm_entries[ct - 1]);
      else
	return 0;
    }
  else
    {
      for (inx = 0; inx < ct; inx++)
	{
	  tmp = map->pm_entries[inx];
	  if (tmp == at)
	    {

	      memmove (&map->pm_entries[inx + 1], &map->pm_entries[inx],
		  sizeof (short) * (ct - inx));

	      map->pm_count = ct + 1;
	      map->pm_entries[inx] = what;
	      return prev;
	    }
	  prev = tmp;
	}
      GPF_T;			/* Insert point not in the map  */
    }
  /*noreturn */
  return 0;
}


void
map_insert_pos (page_map_t ** map_ret, int pos, int what)
{
  page_map_t * map = *map_ret;
  int ct = map->pm_count;
  if (pos > ct)
    GPF_T1 ("map_insert_pos after end");
  if (map->pm_count == map->pm_size)
    {
      map_resize (map_ret, PM_SIZE (map->pm_size));
      map = *map_ret;
    }

  memmove (&map->pm_entries[pos + 1], &map->pm_entries[pos],
	   sizeof (short) * (ct - pos));
  map->pm_count++;
  map->pm_entries[pos] = what;
}


#ifdef MTX_DEBUG
void
ins_leaves_check (buffer_desc_t * buf)
{
  /* see if inserting a leaf on a non leaf page */
  int inx;
  page_map_t * map = buf->bd_content_map;
  for (inx = 0; inx < map->pm_count; inx++)
    {
      key_ver_t kv = IE_KEY_VERSION (buf->bd_buffer + map->pm_entries[inx]);
      if (!kv || (KV_LEFT_DUMMY == kv && LONG_REF (buf->bd_buffer + map->pm_entries[inx] +LD_LEAF)))
	{
	  printf ("non leaf\n");
	  break;
	}
    }
}
#endif



void
itc_insert_dv (it_cursor_t * it, buffer_desc_t ** buf_ret, row_delta_t * rd,
    int is_recursive, row_lock_t * new_rl)
{
  rd->rd_key = it->itc_insert_key;
  rd->rd_leaf = 0;
  rd->rd_op = RD_INSERT;
  if (ITC_AT_END == it->itc_map_pos)
    rd->rd_map_pos = (*buf_ret)->bd_content_map->pm_count;
  else
    rd->rd_map_pos = it->itc_map_pos;
  rd->rd_rl = new_rl;
  rd->rd_itc = it;
  page_apply (it, *buf_ret, 1, &rd, PA_MODIFY);
}

int enable_distinct_key_dup_no_lock = 0;

int
itc_insert_unq_ck (it_cursor_t * it, row_delta_t * rd, buffer_desc_t ** unq_buf)
{
  row_lock_t * rl_flag = KI_TEMP != it->itc_insert_key->key_id  ? INS_NEW_RL : NULL;
  int res, was_allowed_duplicate = 0;
  buffer_desc_t *buf;

  b159ck ();
  FAILCK (it);
  rd->rd_keep_together_pos = ITC_AT_END;
  if (it->itc_insert_key)
    {
      if (it->itc_insert_key->key_table && it->itc_insert_key->key_is_primary)
	it->itc_insert_key->key_table->tb_count_delta++;
      /* for key access statistics */
    }
  it->itc_row_key = it->itc_insert_key;
  it->itc_lock_mode = PL_EXCLUSIVE;
  if (SM_INSERT_AFTER == it->itc_search_mode || SM_INSERT_BEFORE == it->itc_search_mode)
    {
      GPF_T1 ("positioned insert is not enabled");
      buf = *unq_buf;
      if (SM_INSERT_AFTER == it->itc_search_mode)
	res = DVC_LESS;
      else
	res = DVC_GREATER;
      goto searched;
    }
  it->itc_search_mode = SM_INSERT;
 reset_search:
  buf = itc_reset (it);
  res = itc_search (it, &buf);
 searched:
  if (it->itc_insert_key->key_distinct && DVC_MATCH == res && enable_distinct_key_dup_no_lock)
    {
      /* if key is distinct values only hitting a duplicate does nothing and returns success */
      page_leave_outside_map (buf);
      return DVC_LESS;
    }

  if (NO_WAIT != itc_insert_lock (it, buf, &res))
    goto reset_search;
  if (it->itc_insert_key->key_distinct && DVC_MATCH == res)
    {
      /* if key is distinct values only hitting a duplicate does nothing and returns success */
      if (!itc_check_ins_deleted (it, buf, rd))
        page_leave_outside_map (buf);
      return DVC_LESS;
    }

 re_insert:
  if (BUF_NEEDS_DELTA (buf))
    {
      ITC_IN_KNOWN_MAP (it, it->itc_page);
      itc_delta_this_buffer (it, buf, DELTA_MAY_LEAVE);
      ITC_LEAVE_MAP_NC (it);
    }
  if (!buf->bd_is_write)
    GPF_T1 ("insert and no write access to buffer");
  switch (res)
    {
    case DVC_INDEX_END:
    case DVC_LESS:
      /* Insert at leaf end. The cursor's position is perfect. */
      itc_skip_entry (it, buf);
      ITC_AGE_TRX (it, 2);
      itc_insert_dv (it, &buf, rd, 0, rl_flag);
      break;

    case DVC_GREATER:
      /* Before the thing that is at cursor */

      ITC_AGE_TRX (it, 2);
      itc_insert_dv (it, &buf, rd, 0, rl_flag);
      break;

    case DVC_MATCH:

      if (!itc_check_ins_deleted (it, buf, rd))
	{
	  if (unq_buf == UNQ_ALLOW_DUPLICATES || unq_buf == UNQ_SORT)
	    {
	      if (!was_allowed_duplicate && UNQ_SORT == unq_buf)
		{
		  itc_page_leave (it, buf);
		  was_allowed_duplicate = 1;
		  it->itc_search_mode = SM_READ;
		  it->itc_desc_order = 1;
		  goto reset_search;
		}
	      res = DVC_LESS;
	      goto re_insert;
	    }
	  rdbg_printf (("  Non-unq insert T=%d on L=%d pos=%d \n", TRX_NO (it->itc_ltrx), buf->bd_page, it->itc_map_pos));
	  if (unq_buf)
	    {
	      *unq_buf = buf;
	      it->itc_is_on_row = 1;
	      return DVC_MATCH;
	    }
	  if (it->itc_ltrx)
	    {
	      if (it->itc_insert_key)
		{
		  caddr_t detail = dk_alloc_box (50 + MAX_NAME_LEN + MAX_QUAL_NAME_LEN, DV_SHORT_STRING);
		  snprintf (detail, box_length (detail) - 1,
		      "Violating unique index %.*s on table %.*s",
		      MAX_NAME_LEN, it->itc_insert_key->key_name,
		      MAX_QUAL_NAME_LEN, it->itc_insert_key->key_table->tb_name);
		  LT_ERROR_DETAIL_SET (it->itc_ltrx, detail);
		}
	      it->itc_ltrx->lt_error = LTE_UNIQ;
	    }
	  itc_bust_this_trx (it, &buf, ITC_BUST_THROW);
	}
      break;
    default:
      GPF_T1 ("Bad search result in insert");
    }
  KEY_TOUCH (it->itc_insert_key);
  ITC_LEAVE_MAPS (it);
  if (was_allowed_duplicate)
    return DVC_MATCH;
  return DVC_LESS;		/* insert OK, no duplicate. */
}


db_buf_t
strses_to_db_buf (dk_session_t * ses)
{
  long length = strses_length (ses);
  db_buf_t buffer;
  if (length < 256)
    {
      buffer = (db_buf_t) dk_alloc ((int) length + 2);
      buffer[0] = DV_SHORT_CONT_STRING;
      buffer[1] = (unsigned char) length;
      strses_to_array (ses, (char *) &buffer[2]);
    }
  else
    {
      buffer = (db_buf_t) dk_alloc ((int) length + 5);
      buffer[0] = DV_LONG_CONT_STRING;
      buffer[1] = (dtp_t) (length >> 24);
      buffer[2] = (dtp_t) (length >> 16);
      buffer[3] = (dtp_t) (length >> 8);
      buffer[4] = (dtp_t) length;
      strses_to_array (ses, (char *) &buffer[5]);
    }
  return buffer;
}


int
map_delete (page_map_t ** map_ret, int pos)
{
  page_map_t * map = *map_ret;
  int inx, prev_pos = 0, sz;
  for (inx = 0; inx < map->pm_count; inx++)
    {
      int ent = map->pm_entries[inx];
      if (ent == pos)
	{
	  for (inx = inx; inx < map->pm_count - 1; inx++)
	    {
	      map->pm_entries[inx] = map->pm_entries[inx + 1];
	    }
	  map->pm_count--;
	  sz = PM_SIZE (map->pm_count);
	  if (sz < map->pm_size && map->pm_count < ((sz / 10) * 8))
	    map_resize (map_ret, sz);
	  return prev_pos;
	}
      prev_pos = ent;
    }
  GPF_T;			/* Entry to delete not in the map */
  return 0;
}


#define ITC_ID_TO_KEY(itc, key_id) \
  itc->itc_row_key


void
itc_delete_blobs (it_cursor_t * itc, buffer_desc_t * buf)
{
  /* do a round of the row map and delete if you see a blob */
  db_buf_t page = buf->bd_buffer;
  row_ver_t rv = IE_ROW_VERSION (itc->itc_row_data);
  dbe_key_t * key = itc->itc_row_key;
  itc->itc_insert_key = key;
  itc->itc_row_data = page + buf->bd_content_map->pm_entries[itc->itc_map_pos];
  if (key && key->key_row_var)
    {
      DO_CL (cl, key->key_row_var)
	{
	  dtp_t dtp = cl->cl_sqt.sqt_dtp;
	  if (IS_BLOB_DTP (dtp)
	      && 0 == (itc->itc_row_data[cl->cl_null_flag[rv]] & cl->cl_null_mask[rv]))
	    {
	      int off, len;
	      KEY_PRESENT_VAR_COL (key, itc->itc_row_data, (*cl), off, len);
	      dtp = itc->itc_row_data[off];
	      if (IS_BLOB_DTP (dtp))
		{

		  blob_layout_t * bl = bl_from_dv (itc->itc_row_data + off, itc);
		  blob_log_replace (itc, bl);
		  blob_schedule_delayed_delete (itc,
						bl,
						BL_DELETE_AT_COMMIT );
		  /* do not log the del'd blob if it was written by this trx. */
		}
	    }
	}
      END_DO_CL;
    }
}


void
itc_delete (it_cursor_t * itc, buffer_desc_t ** buf_ret, int maybe_blobs)
{
  buffer_desc_t * buf = *buf_ret;
  db_buf_t page = buf->bd_buffer;
  db_buf_t row = page + buf->bd_content_map->pm_entries[itc->itc_map_pos];
  itc->itc_row_data = row;
  if (!buf->bd_is_write)
    GPF_T1 ("Delete w/o write access");
  if (!itc->itc_ltrx)
    GPF_T1 ("itc_delete with no transaction");
  if (BUF_NEEDS_DELTA (buf))
    {
      ITC_IN_KNOWN_MAP (itc, itc->itc_page);
      itc_delta_this_buffer (itc, buf, DELTA_MAY_LEAVE);
      ITC_LEAVE_MAP_NC (itc);
    }
  lt_rb_update (itc->itc_ltrx, buf, row);
  if (!itc->itc_no_bitmap && itc->itc_insert_key->key_is_bitmap)
    {
      if (BM_DEL_DONE == itc_bm_delete (itc, buf_ret))
	return;
    }
  pl_set_finalize (itc->itc_pl, buf);
  itc->itc_is_on_row = 0;
  if (IE_ISSET (row, IEF_DELETE))
    {
      /* multiple delete possible if several cr's first on row and then do co */
      TC (tc_double_deletes);
    }
  IE_ADD_FLAGS (row, IEF_DELETE);
  ITC_AGE_TRX (itc, 2);
  if (maybe_blobs)
    {
      itc_delete_blobs (itc, buf);
    }
}


long delete_parent_waits;

#ifdef PAGE_TRACE
#define rdbg_printf_m(a) printf a
#else
#define rdbg_printf_m(a)
#endif


void
itc_commit_delete (it_cursor_t * it, buffer_desc_t ** buf_ret, int pa_stay)
{
  /* Delete whatever the cursor is on. The cursor will be at the next entry */
  buffer_desc_t *buf = *buf_ret;
  row_delta_t rd;
  row_delta_t * rdp = &rd;
  memset (&rd, 0, sizeof (rd));
  rd.rd_op = RD_DELETE;
  rd.rd_map_pos = it->itc_map_pos;
  it->itc_buf = NULL; /* if goes to parent, page_apply sets this */
  page_apply (it, buf, 1, &rdp, pa_stay);
  if (it->itc_buf)
    *buf_ret = it->itc_buf;
  it->itc_buf = NULL;
}


typedef struct page_rel_s
{
  short		pr_lp_pos;
  dp_addr_t	pr_dp;
  buffer_desc_t *	pr_buf;
} page_rel_t;

#define MAX_CP_BATCH (PAGE_DATA_SZ / 8) /* min leaf ptr is 2 overhead, 2 data, 4 leaf dp. */
#define CP_NOP 0
#define CP_CHANGED 2
#define CP_LEAVE 3 /* when the parent splits, no more processing on this parent page */




#if 0
#define cmp_printf(a) printf a
#else
#define cmp_printf(a)
#endif


void
pr_free (page_rel_t * pr, int pr_fill, int leave_bufs)
{
  int inx;
  if (leave_bufs)
    {
      for (inx = 0; inx < pr_fill; inx++)
	{
	  page_leave_outside_map (pr[inx].pr_buf);
	}
    }
}


extern long ac_pages_in;
extern long ac_pages_out;
extern long ac_n_busy;


int
itc_compact (it_cursor_t * itc, buffer_desc_t * parent, page_rel_t * pr, int pr_fill, int target_fill, int *pos_ret)
{
  dp_addr_t prev_dp;
  index_tree_t *it = itc->itc_tree;
  int inx, n_leaves = 0, n_left;
  row_delta_t ** lp_box;
  page_fill_t pf;
  LOCAL_COPY_RD (rd);
  memset (&pf, 0, sizeof (pf));
  pf.pf_is_autocompact = 1;
  pf.pf_current = buffer_allocate (DPF_INDEX);
  pf.pf_current->bd_content_map = resource_get (PM_RC (PM_SZ_1));
  pg_map_clear (pf.pf_current);
  pf.pf_current->bd_tree = itc->itc_tree;
  pf.pf_itc = itc;
  pf.pf_hash = resource_get (pfh_rc);
  pfh_init (pf.pf_hash, pf.pf_current);
  for (inx = 0; inx < pr_fill; inx++)
    {
      buffer_desc_t * source = pr[inx].pr_buf;
      int map_pos;
      for (map_pos = 0; map_pos < source->bd_content_map->pm_count; map_pos++)
	{
	  row_size_t tf = target_fill; /* out param of pf_rd_append */
	  page_row (source, map_pos, &rd, RO_ROW);
	  pf_rd_append (&pf, &rd, &tf);
	  rd_free (&rd);
	}
    }
  resource_store (pfh_rc, (void*)pf.pf_hash);
  dk_set_append_1 (&pf.pf_left, (void*) pf.pf_current);
  if (dk_set_length (pf.pf_left) >= pr_fill)
    {
      /* not a full page saved.  Abort */
      inx = 0;
      DO_SET (buffer_desc_t *, buf, &pf.pf_left)
	{
	  resource_store (PM_RC (buf->bd_content_map->pm_size), (void*)buf->bd_content_map);
	  buffer_free (buf);
	  /*page_leave_outside_map (pr[inx].pr_buf);*/
	  inx++;
	}
      END_DO_SET();
      dk_set_free (pf.pf_left);
      cmp_printf (("autocompact failed to save space\n"));
      *pos_ret += pr_fill;
      return CP_NOP;
    }
  lp_box = (row_delta_t **) dk_alloc_box (pr_fill * sizeof (caddr_t), DV_BIN);
  inx = 0;
  DO_SET (buffer_desc_t *, buf, &pf.pf_left)
    {
      page_map_t * pm = pr[inx].pr_buf->bd_content_map;
      int copy_len = MIN (PAGE_DATA_SZ, buf->bd_content_map->pm_filled_to + MAX_KV_GAP_BYTES - DP_DATA);
      /* copy 3 extra for the gap marker, but no more than page, since can reach to end w/o gap marker */
      NEW_VARZ (row_delta_t, rd);
      rd->rd_allocated = RD_ALLOCATED;
      lp_box[inx] = rd;
      page_row (buf, 0, rd, RO_LEAF);
      rd->rd_op = RD_UPDATE;
      rd->rd_leaf = pr[inx].pr_buf->bd_page;
      rdbg_printf_2 (("reuse L=%d under L=%d \n", pr[inx].pr_buf->bd_page, parent->bd_page));
      rd->rd_map_pos = pr[inx].pr_lp_pos;
      n_leaves += buf->bd_content_map->pm_count;
      ITC_IN_KNOWN_MAP (itc, pr[inx].pr_buf->bd_page);
      itc_delta_this_buffer (itc, pr[inx].pr_buf, DELTA_STAY_INSIDE);
      ITC_LEAVE_MAP_NC (itc);
      memcpy (pr[inx].pr_buf->bd_buffer + DP_DATA, buf->bd_buffer + DP_DATA, copy_len);
      resource_store (PM_RC (pm->pm_size), (void*) pm);
      pr[inx].pr_buf->bd_content_map = buf->bd_content_map;
      pg_check_map (pr[inx].pr_buf);
      ITC_IN_KNOWN_MAP (itc, pr[inx].pr_buf->bd_page)
	page_mark_change (pr[inx].pr_buf, RWG_WAIT_SPLIT);
      page_leave_inner (pr[inx].pr_buf);
      ITC_LEAVE_MAP_NC (itc);
      buffer_free (buf);
      inx++;
    }
  END_DO_SET();
  dk_set_free (pf.pf_left);
  n_left = inx;
  *pos_ret = pr[inx - 1].pr_lp_pos + 1;
  ac_pages_in += pr_fill;
  ac_pages_out += inx;

  for (inx = inx; inx < pr_fill; inx++)
    {
      buffer_desc_t * buf = pr[inx].pr_buf;
      NEW_VARZ (row_delta_t, rd);
      rd->rd_op = RD_DELETE;
      rd->rd_map_pos = pr[inx].pr_lp_pos;
      lp_box[inx] = rd;
      itc->itc_page = buf->bd_page;
      ITC_IN_OWN_MAP (itc);
      itc_delta_this_buffer (itc, buf, DELTA_STAY_INSIDE);
      rdbg_printf_2 (("D=%d ", pr[inx].pr_buf->bd_page));
      it_free_page (it, pr[inx].pr_buf);
      ITC_LEAVE_MAP_NC (itc);
    }

  itc->itc_page = parent->bd_page;
  prev_dp = itc->itc_page;
  ITC_IN_KNOWN_MAP (itc, parent->bd_page);
  /* if doing vacuum, it can be that the parent is not deltaed */
  itc_delta_this_buffer (itc, parent, DELTA_MAY_LEAVE);
  ITC_LEAVE_MAP_NC (itc);
  itc->itc_ac_parent_deld = 0;
  page_apply (itc, parent, BOX_ELEMENTS (lp_box), lp_box, PA_AUTOCOMPACT);
  cmp_printf (("  Compact %d pages to %d under %d, first %d\n", pr_fill, n_left, parent->bd_page, pr[0].pr_lp_pos));
  if (prev_dp != itc->itc_page
      || itc->itc_ac_parent_deld)
    {
      rd_list_free (lp_box);
      *pos_ret =9999;
      if (itc->itc_ac_parent_deld)
        {
	  cmp_printf (("autocompact caused del of parent L=%d\n", itc->itc_page));
	}
      else
        {
	  cmp_printf (("autocompact caused split of parent\n"));
	}
      return CP_LEAVE;
    }
  if (!parent->bd_is_write) GPF_T1 ("parent not occupied in compact");
  rd_list_free (lp_box);
  return CP_CHANGED;
}


int
it_try_compact (index_tree_t *it, buffer_desc_t * parent, page_rel_t * pr, int pr_fill, int * pos_ret, int mode)
{
  /* look at the pr's and see if can rearrange so as to save one or more pages.
   * if so, verify the rearrange and update the pr array. */
  it_cursor_t itc_auto;
  it_cursor_t * itc = NULL;
  int total_fill = 0, n_leaves = 0;
  int target_fill, est_res_pages;
  int inx;
  int n_source_pages = 0;
  for (inx = 0; inx < pr_fill; inx++)
    {
      page_map_t * pm =  pr[inx].pr_buf->bd_content_map;
      int dp_fill = PAGE_DATA_SZ - pm->pm_bytes_free;
      total_fill += dp_fill;
      n_source_pages++;
    }
  est_res_pages = ((total_fill + (total_fill / 12)) / PAGE_DATA_SZ) + 1;
  if (est_res_pages>= n_source_pages)
    {
    return CP_NOP;
    }
  for (inx = 0; inx < pr_fill; inx++)
    {
      n_leaves += pr[inx].pr_buf->bd_content_map->pm_count;
    }
  /* could be savings.  Make precise relocation calculations */
  target_fill = MIN (PAGE_SZ, DP_DATA + (total_fill / est_res_pages));

  for (inx = 0; inx < pr_fill; inx++)
    {
      buffer_desc_t * source = pr[inx].pr_buf;
      int map_pos;
      for (map_pos = 0; map_pos < source->bd_content_map->pm_count; map_pos++)
	{
	  db_buf_t row = source->bd_buffer + source->bd_content_map->pm_entries[map_pos];
	  if (KV_LEAF_PTR == IE_KEY_VERSION (row))
	    return CP_NOP; /* no compact of non-leaf pages, would have to reloc parents link of children */
	}
    }

  itc = &itc_auto;
  ITC_INIT (itc, NULL, NULL);
  itc_from_it (itc, it);

  if (!LONG_REF (parent->bd_buffer + DP_PARENT))
    it_root_image_invalidate (parent->bd_tree);

  return itc_compact (itc, parent, pr, pr_fill, target_fill, pos_ret);
}



#define CHECK_COMPACT \
{  \
  if (!parent->bd_is_write) GPF_T1 ("parent not occupied in compact 1"); \
  if (pr_fill > 1) \
    {\
      compact_rc = it_try_compact (it, parent, pr, pr_fill, &map_pos, mode);	\
      if (CP_LEAVE == compact_rc) \
        return compact_rc; /* no need for pr_free, it just leaves the bufs and they are not occupied here */  \
      if (!parent->bd_is_write) GPF_T1 ("parent not occupied in compact 2"); \
      pr_free (pr, pr_fill, CP_CHANGED != compact_rc); /*if no change, the bufs are still occupied */ \
      if (CP_CHANGED == compact_rc) \
        any_change = CP_CHANGED; \
    } \
  else \
    pr_free (pr, pr_fill, 1);	\
  pr_fill = 0; \
}



#define BUF_COMPACT_ALL_READY(buf, leaf, itm) \
  (buf && !buf->bd_is_write && !buf->bd_readers  \
   && !buf->bd_being_read && !buf->bd_read_waiting && !buf->bd_write_waiting \
   && !buf->bd_registered \
   && !gethash (DP_ADDR2VOID (leaf), &itm->itm_locks))



#define COMPACT_DIRTY 0
#define COMPACT_ALL 1

int
it_cp_check_node (index_tree_t *it, buffer_desc_t *parent, int mode)
{
  it_map_t  * parent_itm;
  page_rel_t pr[MAX_CP_BATCH];
  int pr_fill = 0, any_change = 0, compact_rc, map_pos;
  if (!parent->bd_is_write) GPF_T1 ("compact expects write access");
  if (DPF_INDEX != SHORT_REF (parent->bd_buffer + DP_FLAGS))
    {
      page_leave_outside_map (parent);
      return 0;
    }
  pg_check_map (parent);
  /* loop over present and dirty children, find possible sequences to compact. Rough check first. */

  for (map_pos = 0; map_pos < parent->bd_content_map->pm_count; map_pos++)
    {
      db_buf_t row = parent->bd_buffer + parent->bd_content_map->pm_entries[map_pos];
      dp_addr_t leaf = leaf_pointer (row, parent->bd_tree->it_key);
      if (leaf && pr_fill < MAX_CP_BATCH)
	    {
	  it_map_t * itm = IT_DP_MAP (it, leaf);
	  buffer_desc_t * buf;
	  mutex_enter (&itm->itm_mtx);
	  buf = (buffer_desc_t*) gethash ((void*)(ptrlong) leaf, &itm->itm_dp_to_buf);
	  if (BUF_COMPACT_ALL_READY (buf, leaf, itm)
	       && (COMPACT_ALL == mode ? 1 : buf->bd_is_dirty))
	    {
	      if (mode == COMPACT_DIRTY && !gethash ((void*)(void*)(ptrlong)leaf, &itm->itm_remap))
		{
		  dbg_page_map_to_file (buf);
		  log_error ("dirty buffer flags: can reuse logical: %d, dp=%d, physical dp=%d", it_can_reuse_logical (it, buf->bd_page), buf->bd_page, buf->bd_physical_page);
		  GPF_T1 ("In compact, no remap dp for a dirty buffer");
		}
	      BD_SET_IS_WRITE (buf, 1);
	      mutex_leave (&itm->itm_mtx);
	      pg_check_map (buf);
	      memset (&pr[pr_fill], 0, sizeof (page_rel_t));
	      pr[pr_fill].pr_buf = buf;
	      pr[pr_fill].pr_dp = leaf;
	      pr[pr_fill].pr_lp_pos = map_pos;
	      pr_fill++;
	    }
	  else
	    {
	      mutex_leave (&itm->itm_mtx);
	      CHECK_COMPACT;
	    }
	}
      else
	{
	  CHECK_COMPACT;
	}
    }
  CHECK_COMPACT;
  if (CP_CHANGED == any_change)
    parent->bd_is_dirty = 1;
  if (COMPACT_DIRTY == mode)
    {
      parent_itm = IT_DP_MAP (it, parent->bd_page);
      mutex_enter (&parent_itm->itm_mtx);
    page_leave_inner (parent);
      mutex_leave (&parent_itm->itm_mtx);
    }
  return any_change;
}

#define DP_VACUUM_RESERVE ((PAGE_DATA_SZ / 12) + 1) /* max no of leaf pointers + parent */


int
itc_vacuum_compact (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  int rc;
  buffer_desc_t * buf = *buf_ret;
  if (buf->bd_registered
      || itc->itc_pl
      || buf->bd_read_waiting || buf->bd_write_waiting)
    {
      return DVC_MATCH;
    }
  itc_hold_pages (itc, buf, DP_VACUUM_RESERVE);
  ITC_LEAVE_MAPS (itc);
  rc = it_cp_check_node (itc->itc_tree, buf, COMPACT_ALL);
  ITC_LEAVE_MAPS (itc);
  itc_free_hold (itc);
  if (CP_LEAVE == rc)
    {
      *buf_ret = itc_reset (itc);
      return DVC_INDEX_END;
    }
  return DVC_MATCH;
}


dk_hash_t * dp_compact_checked;
dk_mutex_t * dp_compact_mtx;

void
dp_may_compact (dbe_storage_t *dbs, dp_addr_t dp)
{
  mutex_enter (dp_compact_mtx);
  remhash ((void*)(ptrlong)dp, dp_compact_checked);
  mutex_leave (dp_compact_mtx);
}


int
dp_is_compact_checked (dbe_storage_t * dbs, dp_addr_t dp)
{
  int rc;
  mutex_enter (dp_compact_mtx);
  rc = (int)(ptrlong) gethash ((void*)(ptrlong)dp, dp_compact_checked);
  if (!rc)
    sethash ((void*)(ptrlong) dp, dp_compact_checked, (void*) 1);
  mutex_leave (dp_compact_mtx);
  return rc;
}



void
it_check_compact (index_tree_t * it, int age_limit)
{
  int rc, inx;
  dk_hash_t * candidates = hash_table_allocate (101);
  for (inx = 0; inx < IT_N_MAPS; inx++)
    {
      it_map_t * itm = &it->it_maps[inx];
      mutex_enter (&itm->itm_mtx);
      DO_HT (void *, ignore, buffer_desc_t *, buf, &itm->itm_dp_to_buf)
    {
      if (buf->bd_pool && buf->bd_pool->bp_ts - buf->bd_timestamp >= age_limit)
	{
	  dp_addr_t parent_dp = LONG_REF (buf->bd_buffer + DP_PARENT);
	      if (!dp_is_compact_checked (it->it_storage, parent_dp))
		{
		  sethash (DP_ADDR2VOID (parent_dp), candidates, (void*) 1);
		}
		}
	    }
      END_DO_HT;
      mutex_leave (&itm->itm_mtx);
	}

  DO_HT (ptrlong, parent_dp, void *, ignore, candidates)
    {
      buffer_desc_t * parent;
      it_map_t * parent_itm = IT_DP_MAP (it, parent_dp);
      mutex_enter (&parent_itm->itm_mtx);
      parent = (buffer_desc_t *) gethash ((void*)(ptrlong) parent_dp, &parent_itm->itm_dp_to_buf);
      if (BUF_COMPACT_ALL_READY (parent, parent_dp, parent_itm) && parent->bd_is_dirty)
	{
	  BD_SET_IS_WRITE (parent, 1);
	  mutex_leave (&parent_itm->itm_mtx);
	  rc = it_cp_check_node (it, parent, COMPACT_DIRTY);
	}
      else
	{
	  mutex_leave (&parent_itm->itm_mtx);
	  dp_may_compact (it->it_storage, parent_dp);
	}
    }
  END_DO_HT;
  hash_table_free (candidates);
}


dk_mutex_t * dbs_autocompact_mtx;
int dbs_autocompact_in_progress;


void
wi_check_all_compact (int age_limit)
{
  /*  call before writing old dirty out. Also before pre-checkpoint flush of all things.
   * do not do many at the same time.  Also have in progress flag for background action which can autocompact and need a buffer, which can then recursively trigger autocompact which is not wanted */
  du_thread_t * self;
  dbe_storage_t * dbs = wi_inst.wi_master;
  /*return;*/
#ifndef AUTO_COMPACT
  return;
#endif
  if (!dbs || wi_inst.wi_checkpoint_atomic
      || dbs_autocompact_in_progress)
    return; /* at the very start of init */
  self = THREAD_CURRENT_THREAD;
  if (THR_IS_STACK_OVERFLOW (self, &dbs, AC_STACK_MARGIN))
    return;
  mutex_enter (dbs_autocompact_mtx);
  dbs_autocompact_in_progress = 1;
  DO_SET (index_tree_t *, it, &dbs->dbs_trees)
    {
	it_check_compact (it, age_limit);
    }
  END_DO_SET();
  dbs_autocompact_in_progress = 0;
  mutex_leave (dbs_autocompact_mtx);
}


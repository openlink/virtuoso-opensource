/*
 *  read.c
 *
 *  $Id$
 *
 *  I/O Scheduling
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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
#include "srvstat.h"

int enable_vec_ra = 1;
int enable_vec_ext_ra = 1;
int enable_iq_always = 0;	/* also single reads take elevator */

#define MAX_EXTS 14

extern long tc_read_aside;


int
itc_ra_extents (it_cursor_t * itc, ra_req_t * ra)
{
  /* for each distinct extent in the ra, see if access frequency justifies prereading the whole ext. */
  dbe_storage_t *dbs = itc->itc_tree->it_storage;
  int window, threshold, i, total = 0;
  extent_map_t *em = itc->itc_tree->it_extent_map;
  dk_hash_t *except = NULL;
  dp_addr_t exts[MAX_EXTS];
  short ext_n[MAX_EXTS];
  int ext_fill = 0;
  uint32 now;
  int inx;
  if (!enable_vec_ext_ra)
    return 0;
  if (disk_reads < main_bufs - 256)
    {
      threshold = em_ra_startup_threshold;
      window = em_ra_startup_window;
    }
  else
    {
      threshold = em_ra_threshold;
      window = em_ra_window;
    }
  for (inx = 0; inx < ra->ra_fill; inx++)
    {
      int e;
      dp_addr_t dp = ra->ra_dp[inx];
      dp_addr_t ext_dp = EXT_ROUND (dp);
      for (e = 0; e < ext_fill; e++)
	{
	  if (ext_dp == exts[e])
	    {
	      ext_n[e]++;
	      goto next_dp;
	    }
	}
      exts[ext_fill] = ext_dp;
      ext_n[ext_fill] = 1;
      ext_fill++;
      if (MAX_EXTS == ext_fill)
	break;
    next_dp:;
    }
  now = get_msec_real_time ();
  for (inx = 0; inx < ext_fill; inx++)
    {
      dp_addr_t dp = exts[inx];
      if (ra->ra_fill >= RA_MAX_BATCH)
	break;
      if (itc->itc_is_col)
	{
	  IN_DBS (dbs);
	  em = (extent_map_t *) gethash (DP_ADDR2VOID (dp), em->em_dbs->dbs_dp_to_extent_map);
	  LEAVE_DBS (dbs);
	}
      if (em_trigger_ra (em, dp, now, window, threshold))
	{
	  int fill;
	  if (!except)
	    {
	      except = hash_table_allocate (ra->ra_fill);
	      for (i = 0; i < ra->ra_fill; i++)
		sethash (DP_ADDR2VOID (ra->ra_dp[i]), except, (void *) 1);
	    }
	  fill = em_ext_ra_pages (em, itc, dp, &ra->ra_dp[ra->ra_fill], RA_MAX_BATCH - ra->ra_fill, -1, except);
	  if (fill + ra->ra_fill > RA_MAX_BATCH)
	    GPF_T1 ("impossible ra fill");
	  ra->ra_fill += fill;
	  tc_read_aside += fill;
	  if (itc->itc_ltrx)
	    itc->itc_ltrx->lt_client->cli_activity.da_spec_disk_reads += fill;
	  total += fill;
	}
    }
  if (except)
    hash_table_free (except);
  return total;
}


void
itc_ra_dps (it_cursor_t * itc, dp_addr_t * dps, int n)
{
  ra_req_t *ra;
  int n_spec;
  if (!dps)
    return;
  ra = (ra_req_t *) dk_alloc_box (sizeof (ra_req_t), DV_CUSTOM);
  memset (ra, 0, sizeof (*ra));
  memcpy (&ra->ra_dp, dps, n * sizeof (dp_addr_t));
  ra->ra_fill = n;
  n_spec = itc_ra_extents (itc, ra);
  itc_read_ahead_blob (itc, ra, n_spec ? RAB_SPECULATIVE : 0);
}


int sib_look_ahead_step = 10;
int sib_cmp_count;

int
itc_find_next_row_set (it_cursor_t * itc, buffer_desc_t * buf, int r)
{
  /* find first set that is after this row. Return the compare result */
  int at_or_below = itc->itc_n_sets - 1;
  int above = itc->itc_set;
  int at_or_below_res = DVC_GREATER, rc;
  int guess = MIN (at_or_below, above + sib_look_ahead_step);
  for (;;)
    {
      if (at_or_below - above <= 1)
	{
	  itc->itc_set = at_or_below;
	  return at_or_below_res;
	}
      itc->itc_set = guess;
      itc_set_param_row (itc, itc->itc_set);
      rc = itc->itc_key_spec.ksp_key_cmp (buf, r, itc);
      sib_cmp_count++;
      if (DVC_GREATER == rc)
	above = guess;
      else
	{
	  at_or_below_res = rc;
	  at_or_below = guess;
	}
      guess = (at_or_below + above) / 2;
    }
}



int
itc_rows_accessed (it_cursor_t * itc, buffer_desc_t * buf, row_no_t pos, row_no_t * rows)
{
  /* return row nos onward from pos which will get accessed from the page */
  page_map_t *pm = buf->bd_content_map;
  int set = itc->itc_set;
  int r, fill = 0, rc;
  int was_lt = 0, n_gts = 0;
  if (!itc->itc_key_spec.ksp_spec_array)
    {
      for (r = pos; r < pm->pm_count; r++)
	rows[fill++] = r;
      return fill;
    }
  for (r = pos + 1; r < pm->pm_count; r++)
    {
      rc = itc->itc_key_spec.ksp_key_cmp (buf, r, itc);
      sib_cmp_count++;
    check_rc:
      if (DVC_LESS == rc)
	{
	  n_gts = 0;
	  was_lt = 1;
	  continue;
	}
      if (was_lt && (DVC_MATCH == rc || DVC_GREATER == rc))
	{
	  rows[fill++] = r - 1;
	  was_lt = 0;
	}
      if (DVC_MATCH == rc)
	{
	  n_gts = 0;
	  rows[fill++] = r;
	  continue;
	}
      if (itc->itc_set + 1 >= itc->itc_n_sets)
	break;
      if (n_gts > 1 && itc->itc_n_sets - itc->itc_set > 10)
	{
	  rc = itc_find_next_row_set (itc, buf, r);
	  goto check_rc;
	}
      else
	itc->itc_set++;
      itc_set_param_row (itc, itc->itc_set);
      n_gts++;
      r--;
    }
  if (set != itc->itc_set)
    {
      itc->itc_set = set;
      itc_set_param_row (itc, set);
    }
  return fill;
}


void
itc_set_siblings (it_cursor_t * itc, buffer_desc_t * buf_from, dp_addr_t dp)
{
  /* when going down in the tree, record sibling pages to the right of pos that will later get visited */
  int n_sibs, sib_sz, inx;
  row_no_t rows[PAGE_DATA_SZ / 6];
  row_no_t pos;
  pos = itc->itc_landed ? itc->itc_map_pos : page_find_leaf (buf_from, dp);
  n_sibs = itc_rows_accessed (itc, buf_from, pos, rows);
  sib_sz = itc->itc_siblings ? box_length (itc->itc_siblings) / sizeof (dp_addr_t) : 0;
  if (sib_sz < n_sibs)
    {
      if (itc->itc_siblings)
	itc_free_box (itc, (caddr_t) itc->itc_siblings);
      itc->itc_siblings = (dp_addr_t *) itc_alloc_box (itc, (200 + n_sibs) * sizeof (dp_addr_t), DV_BIN);
    }
  for (inx = 0; inx < n_sibs; inx++)
    itc->itc_siblings[inx] = leaf_pointer (BUF_ROW (buf_from, rows[inx]), itc->itc_insert_key);
  itc->itc_n_siblings = n_sibs;
  itc->itc_siblings_parent = buf_from->bd_page;
  itc->itc_nth_sibling = -1;
}

int
itc_dive_read_hook (it_cursor_t * itc, buffer_desc_t * buf_from, dp_addr_t dp)
{
  /* In random access schedule sibling pages for read if accessed */
  if (!enable_vec_ra || !buf_from || !iq_is_on ())
    return 0;
  if (itc->itc_n_sets < 2 && !enable_iq_always)
    return 0;
  ITC_LEAVE_MAPS (itc);
  itc_set_siblings (itc, buf_from, dp);
  if (itc->itc_is_col)
    itc->itc_col_prefetch = 1;
  itc_ra_dps (itc, itc->itc_siblings, itc->itc_n_siblings);
  return 1;
}


void
itc_prefetch_col (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, row_no_t * rows, int n_rows, dp_addr_t * dps,
    int *dps_fill)
{
  int fill = *dps_fill;
  dtp_t dtp;
  int r, inx, n_pages;
  int n_keys = itc->itc_insert_key->key_n_significant;
  itc->itc_col_refs[cl->cl_nth - n_keys]->cr_is_prefetched = 1;
  for (r = 0; r < n_rows; r++)
    {
      if (buf->bd_content_map->pm_count <= rows[r])
	continue;		/* safety against wrong argumenst */
      {
      db_buf_t row = BUF_ROW (buf, rows[r]);
      db_buf_t xx, xx2;
      unsigned short vl1, vl2, offset;
      key_ver_t kv = IE_KEY_VERSION (row);
      if (KV_LEFT_DUMMY == kv || KV_LEAF_PTR == kv)
	continue;
      ROW_STR_COL (buf->bd_tree->it_key->key_versions[kv], buf, row, cl, xx, vl1, xx2, vl2, offset);
      if (vl2)
	GPF_T1 ("col ref string should nott be compressed");
      dtp = *xx;
      if (DV_STRING == dtp)
	GPF_T1 ("not supposed to have string in col ref string");
      n_pages = (vl1 - CPP_DP) / sizeof (dp_addr_t);
      for (inx = 0; inx < n_pages; inx++)
	{
	  dp_addr_t dp = LONG_REF_NA ((xx + CPP_DP) + sizeof (dp_addr_t) * inx);
	  if (!fill || dp != dps[fill - 1])
	    dps[fill++] = dp;
	}
    }
    }
  *dps_fill = fill;
}


int
itc_prefetch_col_leaf_page (it_cursor_t * itc, buffer_desc_t * buf)
{
  /* all the cols refd get into read ahead.  Alternately, only count how many reads would be needed. */
  int start_pos = (buf->bd_page == itc->itc_page && !itc->itc_is_ac) ? itc->itc_map_pos : 0;
  dp_addr_t dps[PAGE_DATA_SZ / sizeof (dp_addr_t)];
  row_no_t rows[PAGE_DATA_SZ / 6];
  int nth_key = 0, n_rows, n_out, any_pred = 0;
  search_spec_t *sp;
  int dps_fill = 0;
  int prev_reads;
  int n_keys = itc->itc_insert_key->key_n_significant;
  int inx;
  if (itc->itc_page == buf->bd_page && itc->itc_rows_selected < itc->itc_rows_on_leaves && !itc->itc_is_ac)
    {
      rows[0] = itc->itc_map_pos;	/* always the current row.  By definition, when this returns, the dp requested must be queued, else will recursively call the hook again */
      n_rows = 1 + itc_rows_accessed (itc, buf, start_pos, &rows[1]);
    }
  else
    {
      int pos = start_pos;
      n_rows = buf->bd_content_map->pm_count - pos;
      for (inx = 0; inx < n_rows; inx++)
	rows[inx] = pos + inx;
    }
  DO_BOX (col_data_ref_t *, cr, inx, itc->itc_col_refs)
  {
    if (cr)
      cr->cr_is_prefetched = 0;
  }
  END_DO_BOX;
  if (!itc->itc_ks || itc->itc_ks->ks_is_deleting)
    {
      int n_parts = itc->itc_insert_key->key_n_parts - itc->itc_insert_key->key_n_significant;
      for (inx = 0; inx < n_parts; inx++)
	{
	  if (!itc->itc_col_refs[inx])
	    itc->itc_col_refs[inx] = itc_new_cr (itc);
	  if (!itc->itc_col_refs[inx]->cr_is_prefetched)
	    itc_prefetch_col (itc, buf, &itc->itc_insert_key->key_row_var[inx], rows, n_rows, dps, &dps_fill);
	}
    }
  else
    {
      for (sp = itc->itc_key_spec.ksp_spec_array; sp; sp = sp->sp_next)
	{
	  if (!itc->itc_col_refs[nth_key]->cr_is_prefetched)
	    {
	      any_pred = 1;
	      itc_prefetch_col (itc, buf, &itc->itc_insert_key->key_row_var[nth_key], rows, n_rows, dps, &dps_fill);
	    }
	  nth_key++;
	}
      for (sp = itc->itc_row_specs; sp; sp = sp->sp_next)
	{
	  if (!itc->itc_col_refs[sp->sp_cl.cl_nth - n_keys]->cr_is_prefetched)
	    {
	      any_pred = 1;
	      itc_prefetch_col (itc, buf, &sp->sp_cl, rows, n_rows, dps, &dps_fill);
	    }
	}
      n_out = box_length (itc->itc_v_out_map) / sizeof (v_out_map_t);
      for (inx = 0; inx < n_out; inx++)
	{
	  if (!itc->itc_col_refs[itc->itc_v_out_map[inx].om_cl.cl_nth - n_keys]->cr_is_prefetched)
	    itc_prefetch_col (itc, buf, &itc->itc_v_out_map[inx].om_cl, rows, n_rows, dps, &dps_fill);
	}
      if (!any_pred && !n_out && itc->itc_col_refs[0] && !itc->itc_col_refs[0]->cr_is_prefetched)
	itc_prefetch_col (itc, buf, &itc->itc_insert_key->key_row_var[0], rows, n_rows, dps, &dps_fill);
    }
  prev_reads = itc->itc_n_reads;
  itc_ra_dps (itc, dps, dps_fill);
  if (itc->itc_n_reads == prev_reads)
    itc->itc_col_prefetch = 0;
  return 1;
}

int
itc_prefetch_other_col_leaf (it_cursor_t * itc, dp_addr_t dp)
{
  buffer_desc_t *buf;
  ITC_IN_KNOWN_MAP (itc, dp);
  buf = IT_DP_TO_BUF (itc->itc_tree, dp);
  if (!buf || buf->bd_is_write || buf->bd_being_read)
    {
      ITC_LEAVE_MAP_NC (itc);
      return 0;
    }
  buf->bd_readers++;
  ITC_LEAVE_MAP_NC (itc);
  if (buf->bd_tree == itc->itc_tree && DPF_INDEX == SHORT_REF (buf->bd_buffer + DP_FLAGS))
    itc_prefetch_col_leaf_page (itc, buf);
  page_leave_outside_map (buf);
  return 1;
}


int ra_n_col_leaves = 100;


void
itc_check_col_prefetch (it_cursor_t * itc, buffer_desc_t * buf)
{
  /* going to a sibling leaf page, see that enough sibling pages are in the read ahead pipeline */
  int last, inx;
  if (!itc->itc_is_col)
    return;
  itc->itc_nth_sibling++;
  if (itc->itc_nth_sibling > 3000)
    itc->itc_nth_sibling = 3000;
  if (itc->itc_nth_sibling >= itc->itc_n_siblings)
    return;
  last = MIN (itc->itc_nth_sibling + ra_n_col_leaves, itc->itc_n_siblings);
  for (inx = itc->itc_nth_sibling; inx < last; inx++)
    {
      if (!itc->itc_siblings[inx])
	continue;
      if (itc_prefetch_other_col_leaf (itc, itc->itc_siblings[inx]))
	{
	  itc->itc_siblings[inx] = 0;
	  if (last == itc->itc_nth_sibling + ra_n_col_leaves)
	    last = MIN (last + (ra_n_col_leaves / 2), itc->itc_n_siblings);
	}
    }
}


int
itc_col_read_hook (it_cursor_t * itc, buffer_desc_t * buf_from, dp_addr_t dp)
{
  int nth_sib = -1, inx, last;
  if (!enable_vec_ra)
    return 0;
  ITC_LEAVE_MAPS (itc);
  itc->itc_col_prefetch = 1;
  itc_prefetch_col_leaf_page (itc, itc->itc_col_leaf_buf);
  for (inx = 0; inx < itc->itc_n_siblings; inx++)
    {
      if (itc->itc_page == itc->itc_siblings[inx])
	{
	  nth_sib = inx;
	  break;
	}
    }
  if (-1 == nth_sib)
    {
      /* leftmost leaf. Siblings are all to the right from here. */
      last = MIN (itc->itc_n_siblings, ra_n_col_leaves);
      for (inx = 0; inx < last; inx++)
	{
	  if (!itc->itc_siblings[inx])
	    continue;
	  if (itc_prefetch_other_col_leaf (itc, itc->itc_siblings[inx]))
	    {
	      itc->itc_siblings[inx] = 0;
	    }
	}
    }
  ITC_IN_KNOWN_MAP (itc, dp);
  return 1;
}

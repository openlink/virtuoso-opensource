/*
 *  collock.c
 *
 *  $Id$
 *
 *  Locks for columnwise indices
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2011 OpenLink Software
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


int
itc_is_own_lock (it_cursor_t * itc, col_row_lock_t * clk)
{
  if (!clk || itc->itc_ltrx == clk->pl_owner
      || (clk->pl_is_owner_list && PL_SHARED == itc->itc_lock_mode
	  && dk_set_member ((dk_set_t) clk->pl_owner, (void *) itc->itc_ltrx)))
    return 1;
  return 0;
}


int
itc_first_col_lock (it_cursor_t * itc, col_row_lock_t ** clk_ret, buffer_desc_t * buf)
{
  /* restrict ranges to reach up to first locked row */
  char ser_check = ISO_SERIALIZABLE == itc->itc_isolation || !itc->itc_ks;
  char is_ins = !itc->itc_ks;
  row_no_t point = 0, next = 0;
  int inx;
  if (!itc->itc_rl)
    {
      *clk_ret = NULL;
      return CLK_NO_WAIT;
    }
  for (inx = 0; inx < itc->itc_range_fill; inx++)
    {
      col_row_lock_t *clk;
      int first = itc->itc_ranges[inx].r_first;
      int end = itc->itc_ranges[inx].r_end;
      if (COL_NO_ROW == end)
	end = itc_rows_in_seg (itc, buf);
      if (next && end <= next)
	continue;
      if (ser_check && first > 0)
	{
	  clk = itc_clk_at (itc, first - 1, &point, &next);
	  if (clk && (RL_FOLLOW & clk->pl_type) && !lock_add_owner ((gen_lock_t *) clk, itc, 0))
	    {
	      itc->itc_range_fill = inx;
	      *clk_ret = clk;
	      return CLK_WAIT_RND;
	    }
	}
      if (is_ins && first == end)
	continue;		/* insert has checked serializable and does not fall with eq match on a locked row, check next range */
      clk = itc_clk_at (itc, first, &point, &next);
      if (clk && !lock_add_owner ((gen_lock_t *) clk, itc, 0))
	{
	  /* first of range has a lock. */
	  *clk_ret = clk;
	  if (itc->itc_is_multiseg_set && 0 == itc->itc_ranges[0].r_first)
	    return CLK_WAIT_LANDED;
	  itc->itc_range_fill = inx;
	  return CLK_WAIT_RND;
	}
      if (next < end)
	{
	next_in_range:
	  clk = itc_clk_at (itc, next, &point, &next);
	  if (clk && !lock_add_owner ((gen_lock_t *) clk, itc, 0))
	    {
	      *clk_ret = clk;
	      itc->itc_ranges[inx].r_end = clk->clk_pos;
	      itc->itc_range_fill = inx + 1;
	      return CLK_WAIT_LANDED;
	    }
	  if (next < end)
	    {
	      goto next_in_range;
	    }
	}
      if (COL_NO_ROW == next)
	return CLK_NO_WAIT;
    }
  return CLK_NO_WAIT;
}


int
itc_is_own_del_clk (it_cursor_t * itc, row_no_t row, col_row_lock_t ** clk_ret, row_no_t * point, row_no_t * next)
{
  col_row_lock_t *clk;
  if (!itc->itc_rl)
    return 0;
  clk = itc_clk_at (itc, row, point, next);
  if (!clk)
    return 0;
  *clk_ret = clk;
  return (!clk->pl_is_owner_list && LT_SEES_EFFECT (itc->itc_ltrx, clk->pl_owner) && (clk->clk_change & CLK_DELETE_AT_COMMIT));
}


void
itc_col_wait (it_cursor_t * itc, buffer_desc_t ** buf_ret, col_row_lock_t * clk, int wait)
{
  if (CLK_WAIT_LANDED == wait)
    {
      int set = itc->itc_set - itc->itc_col_first_set;
      itc->itc_col_row = clk->clk_pos;
      itc->itc_ranges[set].r_end = COL_NO_ROW;
    }
  lock_wait ((gen_lock_t *) clk, itc, *buf_ret, ITC_NO_LOCK);
  if (CLK_WAIT_LANDED == wait)
    {
      *buf_ret = page_reenter_excl (itc);
      itc->itc_col_leaf_buf = *buf_ret;
      return;			/* itc_col_search will pick up at itc_col_row */
    }
  itc_set_param_row (itc, itc->itc_set);
again:
  itc->itc_dive_mode = PA_READ;
  *buf_ret = itc_reset (itc);
  itc_page_split_search (itc, buf_ret);
  itc_try_land (itc, buf_ret);
  if (!itc->itc_landed)
    goto again;
}



void
rl_empty_clks (row_lock_t * rl, int first_free)
{
  int fill = MAX (0, first_free), inx;
  for (inx = first_free + 1; inx < rl->rl_n_cols; inx++)
    {
      if (rl->rl_cols[inx])
	rl->rl_cols[fill++] = rl->rl_cols[inx];
    }
  rl->rl_n_cols = fill;
}


void
rl_col_release (row_lock_t * rl, lock_trx_t * lt)
{
  int inx, first_free = -1;
  for (inx = 0; inx < rl->rl_n_cols; inx++)
    {
      col_row_lock_t *clk = rl->rl_cols[inx];
      clk->pl_type &= ~CLK_FINALIZED;
      lock_release ((gen_lock_t *) clk, lt);
      if (PL_FREE == PL_TYPE (clk))
	{
	  clk_free (clk);
	  rl->rl_cols[inx] = NULL;
	  if (-1 == first_free)
	    first_free = inx;
	}
    }
  if (-1 != first_free)
    {
      rl_empty_clks (rl, first_free);
      if (!rl->rl_n_cols)
	PL_SET_TYPE (rl, PL_FREE);
    }
}


col_row_lock_t *
itc_new_clk (it_cursor_t * itc, int row)
{
  NEW_VARZ (col_row_lock_t, clk);
  if (!itc->itc_lock_lt || NO_LOCK_LT == itc->itc_lock_lt)
    GPF_T1 ("col lock lock owner not set");
  clk->pl_owner = itc->itc_lock_lt;
  clk->clk_pos = row;
  clk->pl_type = itc->itc_lock_mode;
  if (ISO_SERIALIZABLE == itc->itc_isolation)
    clk->pl_type |= RL_FOLLOW;
  if (!itc->itc_ks)
    clk->clk_change = CLK_INSERTED | CLK_DELETE_AT_ROLLBACK;
  else if (itc->itc_ks->ks_is_deleting)
    {
      itc->itc_ltrx->lt_n_col_locks++;
    clk->clk_change = CLK_DELETE_AT_COMMIT;
    }
  return clk;
}


void
clk_free (col_row_lock_t * clk)
{
  dk_free ((caddr_t) clk, sizeof (col_row_lock_t));
}


int dbf_clk_order_check = 0;

void
rl_add_clk (row_lock_t * rl, col_row_lock_t * clk, int inx, int is_ins)
{
  int len = BOX_ELEMENTS (rl->rl_cols), ctr;
  if (++rl->rl_n_cols >= len)
    {
      col_row_lock_t **new_cols = (col_row_lock_t **) dk_alloc_box (sizeof (caddr_t) * 2 * len, DV_BIN);
      memcpy_16 (new_cols, rl->rl_cols, sizeof (caddr_t) * (rl->rl_n_cols - 1));
      dk_free_box ((caddr_t) rl->rl_cols);
      rl->rl_cols = new_cols;
    }
  if (inx > rl->rl_n_cols)
    GPF_T1 ("attempt to add a clk past end of clk array");
  memmove_16 (&rl->rl_cols[inx + 1], &rl->rl_cols[inx], sizeof (caddr_t) * (rl->rl_n_cols - inx - 1));
  rl->rl_cols[inx] = clk;
  if (dbf_clk_order_check)
    {
      for (ctr = 1; ctr < rl->rl_n_cols; ctr++)
	{
	  if (rl->rl_cols[ctr - 1]->clk_pos > rl->rl_cols[ctr]->clk_pos)
	    GPF_T1 ("clks out of order");
	}
    }
  if (is_ins)
    {
      for (inx = inx + 1; inx < rl->rl_n_cols; inx++)
	rl->rl_cols[inx]->clk_pos++;
    }
}


void
itc_col_lock_1 (it_cursor_t * itc, buffer_desc_t * buf, int row, row_no_t * point, int before_range)
{
  int inx, at_or_above = *point;
  row_lock_t *rl = itc->itc_rl;
  col_row_lock_t *clk;
  if (!rl)
    {
      itc_set_lock_on_row (itc, &buf);
      itc->itc_rl = rl = pl_row_lock_at (itc->itc_pl, itc->itc_map_pos);
      rl->pl_owner = NULL;	/* column wise rl has no owners, the pl and clk's have owners */
    }
  else if (rl->rl_pos != itc->itc_map_pos)
    GPF_T1 ("itc_rl and itc_map_pos out of sync");
  else
    {
      if (!itc->itc_pl || itc->itc_pl->pl_page != itc->itc_page)
	GPF_T1 ("itc_pl and itc_page inconsistent in setting col lock");
      itc->itc_lock_lt = lt_add_pl (itc->itc_ltrx, itc->itc_pl, 0);
    }
  for (inx = at_or_above; inx < rl->rl_n_cols; inx++)
    {
      clk = rl->rl_cols[inx];
      if (clk->clk_pos == row)
	{
	  lock_add_owner ((gen_lock_t *) clk, itc, 0);
	  lock_add_owner ((gen_lock_t *) itc->itc_pl, itc, 0);
	  if (ISO_SERIALIZABLE == itc->itc_isolation)
	    clk->pl_type |= RL_FOLLOW;
	  if (itc->itc_ks->ks_is_deleting && !before_range)
	    {
	      itc->itc_ltrx->lt_n_col_locks++;
	    clk->clk_change |= CLK_DELETE_AT_COMMIT;
	    }
	  *point = inx;
	  return;
	}
      if (clk->clk_pos > row)
	{
	  clk = itc_new_clk (itc, row);
	  if (before_range)
	    clk->clk_change &= ~CLK_DELETE_AT_COMMIT;
	  rl_add_clk (rl, clk, inx, 0);
	  *point = inx;
	  return;
	}
    }
  clk = itc_new_clk (itc, row);
  if (before_range)
    clk->clk_change &= ~CLK_DELETE_AT_COMMIT;
  rl_add_clk (rl, clk, inx, 0);
  *point = inx;
}


void
itc_col_lock (it_cursor_t * itc, buffer_desc_t * buf, int n_used, int may_delete)
{
  /* set locks on selected rows, mark deletes if deleting  */
  row_no_t point = 0;
  int inx, n_done = 0;
  itc->itc_lock_lt = NO_LOCK_LT;
      if (itc->itc_ks->ks_is_deleting && BUF_NEEDS_DELTA (buf))
	{
	  ITC_IN_KNOWN_MAP (itc, buf->bd_page);
	  itc_delta_this_buffer (itc, buf, DELTA_MAY_LEAVE);
	  ITC_LEAVE_MAP_NC (itc);
	}
  if (itc->itc_n_matches)
    {
      for (inx = 0; inx < n_used; inx++)
	itc_col_lock_1 (itc, buf, itc->itc_matches[inx], &point, 0);
    }
  else
    {
      int set = itc->itc_set - itc->itc_col_first_set;
      int last = itc->itc_ranges[set].r_end;
      int lower = itc->itc_ranges[set].r_first;
      if (COL_NO_ROW == last)
	last = itc_rows_in_seg (itc, buf);
      /* if may delete, with range, do not lock past end of range if this is beyond the batch.  If did so, next batch would see already deleted and would not read them for 2nd keys etc.  If not deleting, serializable may lock till end of seg even if end of seg beyond the batch, may be filters that make the batch end unknown at first locking time */
      if (may_delete && last - lower > n_used)
	last = lower + n_used;
      if (ISO_SERIALIZABLE == itc->itc_isolation)
	{
	  /* serializable locks the row before the range unless this is a non-first page or there is a matchh on unique key */
	  if (lower && !(itc->itc_ks->ks_ts->ts_is_unique && lower != last))
	    {
	      lower--;
	      n_done--;
	    }
	}
      for (inx = lower; inx < last; inx++)
	{
	  if (n_done == n_used)
	    break;
	  itc_col_lock_1 (itc, buf, inx, &point, !may_delete || inx < itc->itc_ranges[set].r_first);
	  n_done++;
	}
    }
#if defined (MTX_DEBUG) || defined (PAGE_TRACE)
  if (!itc->itc_pl)
    GPF_T1 ("itc pl not set after setting col locks");
  pl_check_owners (itc->itc_pl);
#endif
}


int
itc_col_serializable (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  int set = itc->itc_set - itc->itc_col_first_set;
  row_no_t point = 0, next = 0;
  if (COL_NO_ROW == itc->itc_ranges[set].r_first)
    {
      /* landed at end of seg.  Put serializable lock on last row of the seg */
      int n_rows = itc_rows_in_seg (itc, *buf_ret);
      col_row_lock_t *clk = itc_clk_at (itc, n_rows - 1, &point, &next);
      if (!clk)
	{
	  itc_col_lock_1 (itc, *buf_ret, n_rows, &point, 1);
	  return CLK_NO_WAIT;
	}
      if (!lock_add_owner ((gen_lock_t *) clk, itc, 0))
	{
	  itc_col_wait (itc, buf_ret, clk, CLK_WAIT_RND);
	  return CLK_WAIT_RND;
	}
    }
  return CLK_NO_WAIT;
}


int
rl_clk_inx (row_lock_t * rl, int row)
{
  int at_or_above = 0, below = rl->rl_n_cols, guess;
  col_row_lock_t **clks = rl->rl_cols;
  if (!below)
    return 0;
  for (;;)
    {
      if (below - at_or_above <= 1)
	{
	  if (clks[at_or_above]->clk_pos < row)
	    return at_or_above + 1;
	  return at_or_above;
	}
      guess = (at_or_above + below) / 2;
      if (clks[guess]->clk_pos == row)
	return guess;
      if (clks[guess]->clk_pos > row)
	below = guess;
      else
	at_or_above = guess;
    }
}


void
itc_restore_col_reg_itcs (it_cursor_t * itc, buffer_desc_t * buf, row_no_t row, row_delta_t * rd)
{
  it_cursor_t *registered = rd->rd_keep_together_itcs;
  while (registered)
    {
      it_cursor_t *next = registered->itc_next_on_page;
      registered->itc_col_row = row;
      registered->itc_map_pos = itc->itc_map_pos;
      registered->itc_page = buf->bd_page;
      registered->itc_next_on_page = buf->bd_registered;
      buf->bd_registered = registered;
      registered->itc_buf_registered = buf;
      registered->itc_bp.bp_transiting = 0;	/* in leaf row split of col key, uses bp transiting and keep together itcs to maintain registered itcs.  This indicates that the move is complete */
      registered = next;
    }
}


void
itc_col_ins_locks (it_cursor_t * itc, buffer_desc_t * buf)
{
  /* put locks in place for inserted rows, move other locks accordingly, waits are already checked */
  int was_new = 0, was_added = 0, was_owner = 0;
  int ins_offset = 0;
  int inx;
  row_lock_t *rl = itc->itc_rl;
  itc->itc_lock_lt = NO_LOCK_LT;
  if (!rl)
    {
      itc_set_lock_on_row (itc, &buf);
      itc->itc_rl = rl = pl_row_lock_at (itc->itc_pl, itc->itc_map_pos);
      was_new = 1;
    }
  else
    {
      if (IS_MT_BRANCH (itc->itc_ltrx) || !pl_lt_is_owner (itc->itc_pl, itc->itc_ltrx))
	{
	  itc->itc_lock_lt = lt_add_pl (itc->itc_ltrx, itc->itc_pl, 0);
	  was_added = 1;
	}
      else
	{
	  was_owner = 1;
	  itc->itc_lock_lt = itc->itc_ltrx;
	}
    }
  for (inx = 0; inx < itc->itc_range_fill; inx++)
    {
      row_delta_t *rd;
      int row = itc->itc_ranges[inx].r_first + ins_offset;
      int is_eq = itc->itc_ranges[inx].r_first != itc->itc_ranges[inx].r_end;
      col_row_lock_t *clk;
      if (is_eq)
	continue;
      rd = itc->itc_vec_rds[itc->itc_param_order[itc->itc_col_first_set + inx]];
      if (rd->rd_rl && INS_NEW_RL != rd->rd_rl)
	{
	  clk = (col_row_lock_t *) rd->rd_rl;
	  clk->clk_pos = row;
	  itc_restore_col_reg_itcs (itc, buf, row, rd);
	}
      else
	clk = itc_new_clk (itc, row);
      rl_add_clk (rl, clk, rl_clk_inx (rl, row), 1);
      ins_offset++;
    }
#if defined (MTX_DEBUG) || defined (PAGE_TRACE)
  if (!itc->itc_pl)
    GPF_T1 ("itc pl not set after setting ins col locks");
  pl_check_owners (itc->itc_pl);
#endif
}


void
itc_col_ins_locks_nti (it_cursor_t * itc, buffer_desc_t * buf)
{
  /* Move locks for non txn insert */
  int ins_offset = 0;
  int inx;
  row_lock_t *rl = itc->itc_rl;
  if (!rl)
    return;
  for (inx = 0; inx < itc->itc_range_fill; inx++)
    {
      int row = itc->itc_ranges[inx].r_first + ins_offset;
      int is_eq = itc->itc_ranges[inx].r_first != itc->itc_ranges[inx].r_end, rli;
      if (is_eq)
	continue;
      for (rli = rl_clk_inx (rl, row); rli < rl->rl_n_cols; rli++)
	rl->rl_cols[rli]->clk_pos++;
    }
}


db_buf_t
lt_rb_bytes (lock_trx_t * lt, int bytes)
{
  db_buf_t ptr;
  mutex_enter (&lt->lt_rb_mtx);
  if (!lt->lt_rb_page || lt->lt_rbp_fill + bytes + 10 > PAGE_DATA_SZ)
    {
      lt->lt_rb_page = (db_buf_t) resource_get (rb_page_rc);
      lt->lt_rbp_fill = 0;
      dk_set_push (&lt->lt_rb_pages, (void *) lt->lt_rb_page);
    }
  lt->lt_rbp_fill += bytes;
  ptr = lt->lt_rb_page + lt->lt_rbp_fill - bytes;
  mutex_leave (&lt->lt_rb_mtx);
  return ptr;
}

void pl_remove_empty_rls (page_lock_t * pl);

void
ceic_split_locks (ce_ins_ctx_t * ceic, int *splits, int n_splits, row_delta_t ** rds)
{
  int target_fill = 0, any_empty = 0;
  int nth_split = 0;
  row_delta_t *target_rd = NULL;
  it_cursor_t *itc = ceic->ceic_itc;
  row_lock_t *rl = itc->itc_rl;
  int inx, org_n_clks;
  if (!rl)
    {
      if (itc->itc_non_txn_insert)
	return;
      GPF_T1 ("inserting col itc must have a itc_rl in split");
    }
  org_n_clks = rl->rl_n_cols;
  for (inx = 0; inx < org_n_clks; inx++)
    {
      col_row_lock_t *clk = rl->rl_cols[inx];
      if (clk->clk_pos < splits[0])
	continue;
      if (nth_split != n_splits && clk->clk_pos >= splits[nth_split])
	{
	  if (0 == nth_split)
	    {
	      rl->rl_n_cols = inx;
	      if (!inx)
		any_empty = 1;
	    }
	  do
	    {
	      nth_split++;
	      target_rd = rds[nth_split];
	      target_rd->rd_rl = NULL;
	      target_fill = 0;
	    }
	  while (nth_split < n_splits && clk->clk_pos >= splits[nth_split]);
	}
      if (!target_rd->rd_rl || INS_NEW_RL == target_rd->rd_rl)
	{
	  target_rd->rd_rl = rl_col_allocate ();
	}
      clk->clk_pos -= splits[nth_split - 1];
      rl_add_clk (target_rd->rd_rl, clk, target_fill, 0);
      target_fill++;
      rl->rl_cols[inx] = NULL;
    }
  if (any_empty)
    pl_remove_empty_rls (itc->itc_pl);
}


void
ceic_del_ins_rbe (ce_ins_ctx_t * ceic, int nth_range, db_buf_t dv)
{
  row_no_t point = 0, next = 0;
  it_cursor_t *itc = ceic->ceic_itc;
  db_buf_t dvc;
  int len, r = itc->itc_ranges[nth_range].r_first;
  col_row_lock_t *clk = itc_clk_at (itc, r, &point, &next);
  if (!clk)
    GPF_T1 ("setting a del+ins rb entry  where there is no clk");
  if (!clk->clk_rbe)
    {
      clk->clk_rbe = (db_buf_t *) lt_rb_bytes (itc->itc_lock_lt, sizeof (caddr_t) * itc->itc_insert_key->key_n_parts);
      memzero (clk->clk_rbe, sizeof (caddr_t) * itc->itc_insert_key->key_n_parts);
    }
  if (!wi_inst.wi_checkpoint_atomic)
    {
  if (clk->clk_rbe[ceic->ceic_nth_col])
    return;
  clk->clk_change |= CLK_REVERT_AT_ROLLBACK;
    }
  else
    {
      /* uncommitted update must put preimage in checkpoint.  Put the col value as rb anyway and complement the cpt_uc_update bit */
      if (COL_CPT_RESTORE == ceic->ceic_is_cpt_restore)
	clk->clk_change &= ~CLK_UC_UPDATE;
      else
	clk->clk_change |= CLK_UC_UPDATE;
    }
  DB_BUF_TLEN (len, dv[0], dv);
  dvc = lt_rb_bytes (clk->pl_owner, len);
  memcpy_16 (dvc, dv, len);
  clk->clk_rbe[ceic->ceic_nth_col] = dvc;
}


void
ceic_del_ins_rbe_int (ce_ins_ctx_t * ceic, int nth_range, int64 i, dtp_t dtp)
{
  dtp_t tmp[10];
  if (IS_IRI_DTP (dtp))
    dv_from_iri (tmp, i);
  else
    dv_from_int (tmp, i);
  ceic_del_ins_rbe (ceic, nth_range, tmp);
}


void
itc_delete_blob_array (it_cursor_t * itc, caddr_t * blobs, int fill)
{
  int inx;
  for (inx = 0; inx < fill; inx++)
    {
      blob_handle_t *bh = (blob_handle_t *) blobs[inx];
      if (IS_BLOB_HANDLE_DTP (DV_TYPE_OF (bh)))
	{
	  dtp_t tmp[DV_BLOB_LEN];
	  blob_layout_t *bl;
	  bh_to_dv (bh, tmp, DV_BLOB_DTP_FOR_BLOB_HANDLE_DTP (box_tag (bh)));
	  bl = bl_from_dv_it (tmp, itc->itc_tree);
	  blob_chain_delete (itc, bl);
	  blob_layout_free (bl);
	}
    }
}


int
ce_blob_result (col_pos_t * cpo, int row, dtp_t flags, db_buf_t val, int len, int64 offset, int rl)
{
  return ce_result (cpo, row, flags, val, len, offset, rl);
}


void
ceic_delete_blobs (ce_ins_ctx_t * ceic, buffer_desc_t * buf, int ice, row_no_t * matches, int matches_sz)
{
  it_cursor_t *itc = ceic->ceic_itc;
  row_no_t *save = itc->itc_matches;
  int ce_first_range = itc->itc_ce_first_range;
  col_pos_t cpo;
  data_col_t dc;
  mem_pool_t *mp = mem_pool_alloc ();
  int inx;
  memset (&cpo, 0, sizeof (cpo));
  itc->itc_match_in = 0;
  if (ceic->ceic_n_for_ce > matches_sz)
    itc->itc_matches = (row_no_t *) mp_alloc_box (mp, sizeof (row_no_t) * ceic->ceic_n_for_ce, DV_BIN);
  else
    itc->itc_matches = matches;
  itc->itc_n_matches = 0;
  for (inx = 0; inx < ceic->ceic_n_for_ce; inx++)
    {
      if (COL_NO_ROW == itc->itc_ranges[inx + ce_first_range].r_end)
	itc->itc_matches[itc->itc_n_matches++] = itc->itc_ranges[inx + ce_first_range].r_first - itc->itc_row_of_ce;
    }
  if (!itc->itc_n_matches)
    {
      mp_free (mp);
      return;
    }
  cpo.cpo_itc = itc;
  cpo.cpo_string = BUF_ROW (buf, ice);
  cpo.cpo_bytes = ce_total_bytes (cpo.cpo_string);
  memset (&dc, 0, sizeof (dc));
  dc.dc_mp = mp;
  dc.dc_dtp = DV_ANY;
  dc.dc_type = DCT_FROM_POOL;
  dc.dc_values = (db_buf_t) mp_alloc_box_ni (dc.dc_mp, ceic->ceic_n_for_ce * sizeof (caddr_t), DV_BIN);
  dc.dc_n_places = ceic->ceic_n_for_ce;
  cpo.cpo_dc = &dc;
  cpo.cpo_value_cb = ce_blob_result;
  cpo.cpo_ce_op = NULL;
  cpo.cpo_pm = NULL;
  cs_decode (&cpo, itc->itc_matches[0], ce_n_values (cpo.cpo_string));
  itc_delete_blob_array (itc, (caddr_t *) dc.dc_values, dc.dc_n_values);
  itc->itc_matches = save;
  mp_free (mp);
}


int ce_del_count[128];
extern int dbf_ce_del_mask;

int
ceic_delete_direct (ce_ins_ctx_t * ceic, buffer_desc_t * buf, int ice)
{
  /* for an all-delete finalization, ce format specific deletes may be implemented here.  Must update buf content map.  */
  page_map_t *pm;
  db_buf_t ce = BUF_ROW (buf, ice);
  dtp_t flags = ce[0];
  dtp_t ce_type = flags & CE_TYPE_MASK;
  dtp_t ce_dtp = flags & CE_DTP_MASK;
  db_buf_t ce_first;
  int bytes_delta = 0, space_after = -1, elt_sz = -1;
  int ce_bytes = 0;
  int n_values, new_len;
  ce_del_count[flags & 0x7f]++;
  switch (ce_type)
    {
    case CE_RL:
      if (CE_IS_SHORT & flags)
	ce[1] -= ceic->ceic_n_for_ce;
      else
	SHORT_SET_CA (ce + 1, SHORT_REF_CA (ce + 1) - ceic->ceic_n_for_ce);
      goto deleted;
    case CE_VEC:
      if (CET_ANY == ce_dtp || CET_CHARS == ce_dtp || CS_NO_VEC & dbf_ce_del_mask)
	return 0;
      n_values = (CE_IS_SHORT & flags) ? ce[1] : SHORT_REF_CA (ce + 1);
      elt_sz = (flags & CE_IS_64) ? 8 : 4;
      ce_bytes = elt_sz * n_values;
      space_after = ce_space_after (buf, ce);
      ce_del_array (ceic, ce + ((CE_IS_SHORT & flags) ? 2 : 3), n_values, elt_sz);
      bytes_delta = ceic->ceic_n_for_ce * elt_sz;
      if (CE_IS_SHORT & flags)
	ce[1] -= ceic->ceic_n_for_ce;
      else
	SHORT_SET_CA (ce + 1, n_values - ceic->ceic_n_for_ce);
      goto deleted;
    case CE_DICT:
      CE_2_LENGTH (ce, ce_first, ce_bytes, n_values);
      space_after = ce_space_after (buf, ce);
      if (!ce_del_dict (ceic, ce, &new_len))
	return 0;
      bytes_delta = ce_bytes - new_len;
      goto deleted;
    case CE_INT_DELTA:
      CE_2_LENGTH (ce, ce_first, ce_bytes, n_values);
      space_after = ce_space_after (buf, ce);
      if (!ce_del_int_delta (ceic, ce, &new_len))
  return 0;
      bytes_delta = ce_bytes - new_len;
      goto deleted;
    default:
      return 0;
    }
deleted:
  pm = buf->bd_content_map;
  pm->pm_entries[ice + 1] -= ceic->ceic_n_for_ce;
  if (bytes_delta)
    {
      int ce_head = ce_head_len (ce);
      if (!ce_bytes || -1 == space_after)
	GPF_T1 ("must have set ce_bytes");
      buf->bd_content_map->pm_bytes_free += bytes_delta;
      cs_write_gap (ce + ce_head + ce_bytes - bytes_delta, space_after + bytes_delta);
      if (ice == pm->pm_count - 1)
	pm->pm_filled_to -= bytes_delta;
    }
  return 1;
}


/* finalize action for a col row lock in commit or rb */
#define CEA_NONE 0
#define CEA_DELETE 1
#define CEA_UPDATE 2


int
clk_action (ce_ins_ctx_t * ceic, col_row_lock_t * clk, int is_rb)
{
  it_cursor_t *itc = ceic->ceic_itc;
  if (RB_CPT != is_rb && clk->pl_owner != itc->itc_ltrx)
    return CEA_NONE;
  if (CLK_FINALIZED & clk->clk_change)
    return CEA_NONE;
  if ((CLK_INSERTED & clk->clk_change) && is_rb)
    return CEA_DELETE;
  if ((CLK_DELETE_AT_COMMIT & clk->clk_change) && !is_rb)
    return CEA_DELETE;
  if (clk->clk_rbe && is_rb)
    return CEA_UPDATE;
  return CEA_NONE;
}


void
ce_recompress (ce_ins_ctx_t * ceic, compress_state_t * cs, data_col_t * dc)
{
  int n_in = 0;
  int inx;
  for (inx = 0; inx < dc->dc_n_values; inx++)
    {
      cs_compress (cs, ((caddr_t *) dc->dc_values)[inx]);
      n_in++;
    }
}




void
ceic_save_uci (ce_ins_ctx_t * ceic, buffer_desc_t * buf, int ice, row_no_t * uci, int n_uci)
{
  col_pos_t cpo;
  caddr_t vals[2048];
  data_col_t dc;
  it_cursor_t *itc = ceic->ceic_itc;
  int inx;
  memzero (&dc, sizeof (dc));
  memzero (&cpo, sizeof (cpo));
  if (DV_ANY == ceic->ceic_col->col_sqt.sqt_dtp || IS_BLOB_DTP (ceic->ceic_col->col_sqt.sqt_dtp))
    {
      dc.dc_dtp = DV_ANY;
      dc.dc_type = DCT_FROM_POOL;
    }
  else
    {
      dc.dc_dtp = DV_ARRAY_OF_POINTER;
      dc.dc_type = DCT_BOXES | DCT_FROM_POOL;
    }
  dc.dc_n_places = n_uci;
  dc.dc_mp = cpt_mp;
  if (n_uci > sizeof (vals) / sizeof (caddr_t))
    dc.dc_values = (db_buf_t) dk_alloc_box (n_uci * sizeof (caddr_t), DV_BIN);
  else
    dc.dc_values = (db_buf_t) & vals;
  itc->itc_matches = uci;
  itc->itc_n_matches = n_uci;
  itc->itc_match_in = 0;
  cpo.cpo_string = BUF_ROW (buf, ice);
  cpo.cpo_bytes = ce_total_bytes (cpo.cpo_string);
  cpo.cpo_dc = &dc;
  cpo.cpo_value_cb = ce_result;
  cpo.cpo_ce_op = NULL;
  cpo.cpo_pm = NULL;
  cpo.cpo_itc = itc;
  cpo.cpo_cl = cl_list_find (itc->itc_insert_key->key_row_var, ceic->ceic_col->col_id);
  cs_decode (&cpo, uci[0], uci[n_uci - 1] + 1);
  for (inx = 0; inx < dc.dc_n_values; inx++)
    {
      caddr_t val = ((caddr_t *) dc.dc_values)[inx];
      if (DV_ANY == dc.dc_dtp && DV_STRING == (dtp_t) val[0] && LONG_REF_NA (val + 1) > 4000)
	bing ();
      ceic->ceic_rb_rds[inx + ceic->ceic_nth_rb_rd]->rd_values[ceic->ceic_nth_col] = val;
    }
  ceic->ceic_nth_rb_rd += dc.dc_n_values;
  if ((db_buf_t) vals != dc.dc_values)
    dk_free_box ((caddr_t) dc.dc_values);
}


int
ceic_complement (ce_ins_ctx_t * ceic, buffer_desc_t * buf, int ice, int n_values, row_no_t * matches, int *any_rb)
{
  int fill = 0, del_fill = 0, row;
  row_no_t *deletes = ceic->ceic_deletes;
  row_no_t action;
  it_cursor_t *itc = ceic->ceic_itc;
  int nth_clk = itc->itc_ce_first_range;
  int last_for_ce = ceic->ceic_n_for_ce + nth_clk;
  int row_of_ce = itc->itc_row_of_ce;
  int place = itc->itc_ranges[nth_clk].r_first;
  action = itc->itc_ranges[nth_clk].r_end;
  for (row = 0; row < n_values; row++)
    {
      if (place == row + row_of_ce)
	{
	  if (COL_NO_ROW != action)
	    {
	      *any_rb = 1;
	      matches[fill++] = row;
	    }
	  else if (deletes)
	    {
	    deletes[del_fill++] = row;
	    }
	  nth_clk++;
	  if (nth_clk < last_for_ce)
	    {
	      place = itc->itc_ranges[nth_clk].r_first;
	      action = itc->itc_ranges[nth_clk].r_end;
	    }
	  else
	    place = -1;
	}
      else
	matches[fill++] = row;
    }
  if (RB_CPT == ceic->ceic_is_rb)
    {
      if (del_fill)
      ceic_save_uci (ceic, buf, ice, deletes, del_fill);
    }
  return fill;
}


#define NEED_CEIC \
{ \
  if (!col_ceic) \
    col_ceic = *col_ceic_ret = ceic_col_ceic (top_ceic); \
}

void
ceic_merge_finalize (ce_ins_ctx_t * top_ceic, ce_ins_ctx_t ** col_ceic_ret, buffer_desc_t * buf, int ice)
{
  row_no_t matches_auto[CE_VEC_MAX_VALUES];
  row_no_t *matches = &matches_auto[0];
  ce_ins_ctx_t *col_ceic = *col_ceic_ret;
  db_buf_t org_ce = BUF_ROW (buf, ice);
  it_cursor_t *itc = top_ceic->ceic_itc;
  int op = CE_REPLACE;
  compress_state_t *cs = top_ceic->ceic_cs;
  db_buf_t last_ce;
  int last_ce_len;
  col_pos_t cpo;
  data_col_t dc;
  int org_n_values = ce_n_values (org_ce);
  int any_rb = 0;
  int n_values;
  if (org_n_values > sizeof (matches_auto) / sizeof (row_no_t))
    matches = dk_alloc (sizeof (row_no_t) * org_n_values);
  ITC_DELTA (itc, buf);
  if (IS_BLOB_DTP (top_ceic->ceic_col->col_sqt.sqt_dtp) && RB_CPT != top_ceic->ceic_is_rb)
    ceic_delete_blobs (top_ceic, buf, ice, &matches_auto[0], sizeof (matches_auto) / sizeof (row_no_t));
  n_values = ceic_complement (top_ceic, buf, ice, org_n_values, matches, &any_rb);
  if (!n_values)
    {
      NEED_CEIC;
      top_ceic->ceic_finalize_needs_update = 1;
      mp_conc1 (col_ceic->ceic_mp, &col_ceic->ceic_delta_ce_op, (void *) (ptrlong) (CE_DELETE | ice));
      mp_conc1 (col_ceic->ceic_mp, &col_ceic->ceic_delta_ce, NULL);
      if (matches != &matches_auto[0])
	dk_free ((caddr_t) matches, -1);
      return;
    }
  if (!any_rb && ceic_delete_direct (top_ceic, buf, ice))
    {
      if (matches != &matches_auto[0])
	dk_free ((caddr_t) matches, -1);
    return;
    }
  NEED_CEIC;
  top_ceic->ceic_finalize_needs_update = 1;
  memset (&cpo, 0, sizeof (cpo));
  itc->itc_n_matches = n_values;
  itc->itc_match_in = 0;
  itc->itc_matches = matches;
  cpo.cpo_itc = itc;
  cpo.cpo_string = BUF_ROW (buf, ice);
  cpo.cpo_bytes = ce_total_bytes (cpo.cpo_string);
  memset (&dc, 0, sizeof (dc));
  dc.dc_mp = col_ceic->ceic_mp;
  dc.dc_dtp = DV_ANY;
  dc.dc_type = DCT_FROM_POOL;
  dc.dc_values = (db_buf_t) mp_alloc_box_ni (dc.dc_mp, n_values * sizeof (caddr_t), DV_BIN);
  dc.dc_n_places = n_values;
  col_ceic->ceic_mp->mp_block_size = 128 * 1024;
  if (cs)
    {
      cs->cs_n_values = 0;
      cs->cs_prev_ready_ces = cs->cs_ready_ces = NULL;
      cs_reset (cs);
      cs_clear (cs);
    }
  else
    {
      top_ceic->ceic_cs = cs = (compress_state_t *) mp_alloc_box_ni (dc.dc_mp, sizeof (compress_state_t), DV_BIN);
      memset (cs, 0, sizeof (compress_state_t));
      cs_init (cs, dc.dc_mp, 0, MIN (2000, n_values + top_ceic->ceic_n_for_ce));
    }
  ceic_cs_flags (col_ceic, cs, 0);
  cs->cs_exclude = dbf_compress_mask;
  cpo.cpo_dc = &dc;
  cpo.cpo_value_cb = ce_result;
  cpo.cpo_ce_op = NULL;
  cpo.cpo_pm = NULL;
  cs_decode (&cpo, itc->itc_matches[0], ce_n_values (cpo.cpo_string));
  itc->itc_matches = NULL;
  SET_THR_TMP_POOL (top_ceic->ceic_mp);
  if (any_rb && RB_CPT != top_ceic->ceic_is_rb)
    {
      /* checkpoint rb replaces uncommitted updates separately */
      int inx;
      int last = itc->itc_ce_first_range + top_ceic->ceic_n_for_ce;
      for (inx = itc->itc_ce_first_range; inx < last; inx++)
	{
	  row_no_t nth_clk = itc->itc_ranges[inx].r_end;
	  if (COL_NO_ROW != nth_clk)
	    {
	      col_row_lock_t *clk = itc->itc_rl->rl_cols[nth_clk];
	      int row = clk->clk_pos - itc->itc_row_of_ce;
	      db_buf_t rb = clk->clk_rbe[col_ceic->ceic_nth_col];
	      if (rb)
		((db_buf_t *) dc.dc_values)[row] = (db_buf_t) mp_box_any_dv (top_ceic->ceic_mp, rb);
	    }
	}
    }
  ce_recompress (col_ceic, cs, &dc);
  if (cs->cs_n_values)
    {
  cs_best (cs, &last_ce, &last_ce_len);
  mp_set_push (cs->cs_mp, &cs->cs_ready_ces, (void *) last_ce);
  cs_reset_check (cs);
    }
  SET_THR_TMP_POOL (NULL);
  cs_distinct_ces (cs);
  DO_SET (db_buf_t, prev_ce, &cs->cs_ready_ces)
  {
    mp_conc1 (col_ceic->ceic_mp, &col_ceic->ceic_delta_ce_op, (void *) (ptrlong) (op | (itc->itc_nth_ce)));
    prev_ce = ce_skip_gap (prev_ce);
    mp_conc1 (col_ceic->ceic_mp, &col_ceic->ceic_delta_ce, (void *) prev_ce);
    op = CE_INSERT;
  }
  END_DO_SET ();
  if (matches != &matches_auto[0])
    dk_free ((caddr_t) matches, -1);
}


void
ce_finalize (ce_ins_ctx_t * ceic, ce_ins_ctx_t ** col_ceic, col_data_ref_t * cr, int inx, int ice)
{
  buffer_desc_t *buf = cr->cr_pages[inx].cp_buf;
  ceic_merge_finalize (ceic, &cr->cr_pages[inx].cp_ceic, buf, ice);
}

extern int dbf_ignore_uneven_col;

void
cr_finalize (ce_ins_ctx_t * ceic, buffer_desc_t * buf, col_data_ref_t * cr)
{
  it_cursor_t *itc = ceic->ceic_itc;
  int inx;
  int place, nth_range = 0;
  int ice, itc_set_save = itc->itc_set;
  int row_of_ce = 0;
  int ces_left = cr->cr_n_ces;
  itc->itc_ce_first_set = itc->itc_set;
  for (inx = 0; inx < cr->cr_n_pages; inx++)
    {
      page_map_t *pm = cr->cr_pages[inx].cp_map;
      place = itc->itc_ranges[nth_range].r_first;
      for (ice = 0 == inx ? cr->cr_first_ce * 2 : 0; ice < pm->pm_count; ice += 2)
	{
	  int n_in_ce = pm->pm_entries[ice + 1];
	  if (place >= row_of_ce && place < row_of_ce + n_in_ce)
	    {
	      int ira, n_inserts = 1;
	      itc->itc_row_of_ce = row_of_ce;
	      for (ira = nth_range + 1; ira < itc->itc_range_fill; ira++)
		{
		  if (itc->itc_ranges[ira].r_first < row_of_ce + n_in_ce)
		    n_inserts++;
		  else
		    break;
		}
	      ceic->ceic_n_for_ce = n_inserts;
	      ceic->ceic_itc->itc_nth_ce = ice;
	      itc->itc_ce_first_range = nth_range;
	      ce_finalize (ceic, &cr->cr_pages[inx].cp_ceic, cr, inx, ice);
	      nth_range += n_inserts;
	      if (nth_range >= itc->itc_range_fill)
		goto done;
	      itc->itc_ce_first_set += n_inserts;
	      place = itc->itc_ranges[nth_range].r_first;
	    }
	  row_of_ce += n_in_ce;
	  if (0 == --ces_left)
	    goto done;
	}
    }
done:
  if (nth_range < itc->itc_range_fill)
    {
      if (!dbf_ignore_uneven_col)
    GPF_T1 ("Too few rows in seg for insert");
    }
  itc->itc_set = itc_set_save;
}


void
ceic_finalize_move (ce_ins_ctx_t * ceic, buffer_desc_t * buf)
{
  it_cursor_t *itc = ceic->ceic_itc, *reg;
  int deld_before = 0, inx, nth_range = 0;
  row_lock_t *rl = itc->itc_rl;
  int nth_rb_rd = ceic->ceic_nth_rb_rd;
  int is_cpt_rb = RB_CPT == ceic->ceic_is_rb;
  for (inx = 0; inx < rl->rl_n_cols; inx++)
    {
      if (nth_range < itc->itc_range_fill && rl->rl_cols[inx]->clk_pos == itc->itc_ranges[nth_range].r_first)
	{
	  if (COL_NO_ROW == itc->itc_ranges[nth_range].r_end)
	    {
	      deld_before++;
	      if (is_cpt_rb)
		{
		  buf_extract_registered (buf, itc->itc_map_pos, rl->rl_cols[inx]->clk_pos,
		      &ceic->ceic_rb_rds[nth_rb_rd]->rd_keep_together_itcs);
		  ceic->ceic_rb_rds[nth_rb_rd++]->rd_rl = (row_lock_t *) rl->rl_cols[inx];
		  rl->rl_cols[inx] = NULL;
		}
	    }
	  nth_range++;
	}
      else if (deld_before)
	rl->rl_cols[inx]->clk_pos -= deld_before;
    }
  if (is_cpt_rb && deld_before)
    rl_empty_clks (rl, -1);
  for (reg = buf->bd_registered; reg; reg = reg->itc_next_on_page)
    {
      if (itc->itc_map_pos != reg->itc_map_pos)
	continue;
      deld_before = 0;
      for (inx = 0; inx < itc->itc_range_fill; inx++)
	{
	  if (itc->itc_ranges[inx].r_first == reg->itc_col_row)
	    {
	      if (COL_NO_ROW == itc->itc_ranges[inx].r_end)
		{
		  reg->itc_is_on_row = 0;
		}
	      reg->itc_col_row -= deld_before;
	      goto next;
	    }
	  if (itc->itc_ranges[inx].r_first > reg->itc_col_row)
	    {
	      reg->itc_col_row -= deld_before;
	      goto next;
	    }
	  if (COL_NO_ROW == itc->itc_ranges[inx].r_end)
	    deld_before++;
	}
      if (deld_before)
	reg->itc_col_row -= deld_before;
    next:;
    }
}


void
ceic_finalize_ranges (ce_ins_ctx_t * ceic, int is_rb)
{
  it_cursor_t *itc = ceic->ceic_itc;
  int inx;
  row_lock_t *rl = itc->itc_rl;
  itc->itc_range_fill = 0;
  for (inx = 0; inx < rl->rl_n_cols; inx++)
    {
      col_row_lock_t *clk = rl->rl_cols[inx];
      int action = clk_action (ceic, clk, is_rb);
      if (CEA_DELETE == action)
	{
	  itc_range (itc, rl->rl_cols[inx]->clk_pos, COL_NO_ROW);
	  if (RB_CPT != is_rb)
	    clk->clk_change |= CLK_FINALIZED;
	}
      else if (CEA_UPDATE == action)
	{
	  itc_range (itc, rl->rl_cols[inx]->clk_pos, inx);
	  if (RB_CPT != is_rb)
	    clk->clk_change |= CLK_FINALIZED;
	}
    }
}

int
rl_any_action (row_lock_t * rl, it_cursor_t * itc, int is_rb)
{
  int inx;
  for (inx = 0; inx < rl->rl_n_cols; inx++)
    {
      col_row_lock_t *clk = rl->rl_cols[inx];
      if (clk->pl_owner != itc->itc_ltrx)
	continue;
      if (CLK_FINALIZED & clk->clk_change)
	continue;
      if (is_rb && (clk->clk_change & (CLK_INSERTED | CLK_DELETE_AT_ROLLBACK | CLK_REVERT_AT_ROLLBACK)))
	return 1;
      if (!is_rb && (clk->clk_change & CLK_DELETE_AT_COMMIT))
	return 1;
    }
  return 0;
}

void
ceic_finalize_check (ce_ins_ctx_t * ceic, buffer_desc_t * buf)
{
  it_cursor_t *itc = ceic->ceic_itc;
  int sz = -1, new_sz, bytes, cinx;
  DO_BOX (col_data_ref_t *, cr, cinx, itc->itc_col_refs)
  {
    if (!cr || !cr->cr_is_valid)
      continue;
    new_sz = cr_new_size (cr, &bytes);
    if (-1 != sz && sz != new_sz)
      {

	log_error ("In delete or rb of insert on %s dp %d seg %d,  col %d  is %d values and next %d", itc->itc_insert_key->key_name,
	    itc->itc_page, itc->itc_map_pos, cinx, sz, new_sz);
	if (!dbf_ignore_uneven_col)
	  GPF_T1 ("uneven length cols after delete, update or rollback of insert");
      }
    sz = new_sz;
  }
  END_DO_BOX;
}


void
ceic_col_finalize_row (ce_ins_ctx_t * ceic, buffer_desc_t * buf, int is_rb)
{
  int action = -1;
  it_cursor_t *itc = ceic->ceic_itc;
  dbe_key_t *key = itc->itc_insert_key;
  int nth = 0;
  int nth_rb_rd = ceic->ceic_nth_rb_rd;
  ceic->ceic_end_map_pos = itc->itc_map_pos;
  ceic->ceic_is_finalize = 1;
  ceic->ceic_is_rb = is_rb;
  ceic->ceic_finalize_needs_update = 0;
  ceic_finalize_ranges (ceic, is_rb);
  if (!itc->itc_range_fill)
    return;
  ceic_finalize_move (ceic, buf);
  itc->itc_buf = buf;
  DO_SET (dbe_column_t *, col, &key->key_parts)
  {
    col_data_ref_t *cr;
    int rdinx = nth < key->key_n_significant ? key->key_part_in_layout_order[nth] : nth;
    ceic->ceic_nth_rb_rd = nth_rb_rd;
    ceic->ceic_col = col;
    ceic->ceic_nth_col = rdinx;
    cr = itc->itc_col_refs[nth];
    if (!cr)
      itc->itc_col_refs[nth] = cr = itc_new_cr (itc);
    if (!cr->cr_is_valid)
      itc_fetch_col (itc, buf, &key->key_row_var[nth], FC_FROM_CEIC, (ptrlong) ceic);
    cr_finalize (ceic, buf, cr);
    nth++;
  }
  END_DO_SET ();
  ceic_finalize_check (ceic, buf);
  if (ceic->ceic_finalize_needs_update)
    {
      ceic_no_split (ceic, buf, &action);
    }
  else
    {
      row_delta_t *rd;
      rd = ceic_1st_changed (ceic);
      itc_asc_ck (itc);
      itc_col_leave (itc, 0);
    }
}


void
pl_remove_empty_rls (page_lock_t * pl)
{
  int inx;
  for (inx = 0; inx < N_RLOCK_SETS; inx++)
    {
      row_lock_t **prev = &pl->pl_rows[inx];
      row_lock_t *rl = *prev;
      while (rl)
	{
	  row_lock_t *next = rl->rl_next;
	  if (rl->rl_n_cols)
	    prev = &rl->rl_next;
	  else
	    {
	      *prev = next;
	      pl->pl_n_row_locks--;
	      rl_free (rl);
	    }
	  rl = next;
	}
    }
}


unsigned int
rl_sort_key (row_lock_t * rl)
{
  return rl->rl_pos;
}


void
itc_clear_col_refs (it_cursor_t * itc)
{
  int c, inx;
  DO_BOX (col_data_ref_t *, cr, c, itc->itc_col_refs)
  {
    if (!cr)
      continue;
    cr->cr_is_valid = 0;
    for (inx = 0; inx < cr->cr_pages_sz; inx++)
      memzero (&cr->cr_pages[inx], sizeof (col_page_t));
  }
  END_DO_BOX;
}


void
itc_ensure_col_refs (it_cursor_t * itc)
{
  if (!itc->itc_is_col)
    itc_col_init (itc);
  else
    {
      itc_clear_col_refs (itc);
      if (BOX_ELEMENTS (itc->itc_col_refs) < itc->itc_insert_key->key_n_parts)
	{
	  col_data_ref_t **old_refs = itc->itc_col_refs;
	  itc->itc_col_refs = (col_data_ref_t **) itc_alloc_box (itc, itc->itc_insert_key->key_n_parts * sizeof (caddr_t), DV_BIN);
	  memzero (itc->itc_col_refs, box_length (itc->itc_col_refs));
	  memcpy_16 (itc->itc_col_refs, old_refs, box_length (old_refs));
	  itc_free_box (itc, (caddr_t) old_refs);
	}
    }
}


int enable_rq_check_all = 0;

void
rq_check_all ()
{
  dbe_table_t *tb = sch_name_to_table (wi_inst.wi_schema, "DB.DBA.RDF_QUAD");
  DO_SET (dbe_key_t *, key, &tb->tb_keys)
  {
    if (!key->key_distinct)
      key_col_check (key);
  }
  END_DO_SET ();
}


int dbf_col_del_leaf;

void
ceic_del_leaf (ce_ins_ctx_t * ceic, buffer_desc_t * buf)
{
  it_cursor_t *itc = ceic->ceic_itc;
  itc_col_page_free (itc, buf, -1);
  ceic->ceic_mp = mem_pool_alloc ();
  itc->itc_buf = buf;
  DO_ROWS (buf, pos, row, NULL)
  {
    if (KV_LEFT_DUMMY != IE_KEY_VERSION (row))
      ceic_upd_rd (ceic, pos, 0, NULL);
  }
  END_DO_ROWS;
}


void
pl_col_finalize_page (page_lock_t * pl, it_cursor_t * itc, int is_rb)
{
  ce_ins_ctx_t ceic;
  row_lock_t *rls[COL_PAGE_MAX_ROWS];
  int rl_fill = 0, irl, inx;
  row_delta_t **rds;
  lock_trx_t *lt = itc->itc_ltrx;
  buffer_desc_t *buf = NULL;
  memset (&ceic, 0, sizeof (ce_ins_ctx_t));
  ceic.ceic_itc = itc;
  itc_ensure_col_refs (itc);
  if (DP_DELETED == pl->pl_page)
    {
      TC (tc_release_pl_on_deleted_dp);
      pl_release (pl, lt, NULL);
      return;
    }

  do
    {
      if (DP_DELETED == pl->pl_page)
	{
	  TC (tc_release_pl_on_deleted_dp);
	  ITC_LEAVE_MAPS (itc);
	  pl_release (pl, lt, NULL);
	  return;
	}
      ITC_IN_KNOWN_MAP (itc, pl->pl_page);
      page_wait_access (itc, pl->pl_page, NULL, &buf, PA_WRITE, RWG_WAIT_KEY);
    }
  while (itc->itc_to_reset > RWG_WAIT_KEY);

  if (PF_OF_DELETED == buf)
    {
      /* check needed here because the page could have gone out during the above wait and the wait itself could give 'a no wait status with bad timing  The page map does not serialize the whole delete as atomic. */
      TC (tc_release_pl_on_deleted_dp);
      ITC_LEAVE_MAPS (itc);
      pl_release (pl, lt, NULL);
      return;
    }
  ITC_LEAVE_MAPS (itc);
  itc->itc_page = pl->pl_page;
  if (pl->pl_n_row_locks > buf->bd_content_map->pm_count)
    GPF_T1 ("more locks than rows");
  pl_remove_empty_rls (pl);
  DO_RLOCK (rl, pl)
  {
    if (rl_any_action (rl, itc, is_rb) && rl->rl_pos >= 0)
      {
	rls[rl_fill++] = rl;
	if (rl_fill >= COL_PAGE_MAX_ROWS)
	  GPF_T1 ("more col leaf rows than possible in col finalize");
      }
  }
  END_DO_RLOCK;
  buf_sort ((buffer_desc_t **) rls, rl_fill, (sort_key_func_t) rl_sort_key);
  itc_ce_check (itc, buf, 1);
  if (dbf_col_del_leaf)
    ceic_del_leaf (&ceic, buf);
  else
    {
  for (irl = 0; irl < rl_fill; irl++)
    {
      row_lock_t *rl = rls[irl];
      itc->itc_map_pos = rl->rl_pos;
      itc->itc_rl = rl;
      ceic_col_finalize_row (&ceic, buf, is_rb);
    }
    }
  rds = ceic.ceic_rds;
  if (!rds || 0 == BOX_ELEMENTS (rds))
    {
      itc_ce_check (itc, buf, 1);
      pl_release (pl, lt, buf);
      page_leave_outside_map (buf);
    }
  else
    {
      DO_BOX (row_delta_t *, rd, inx, rds)
      {
	if (RD_UPDATE_LOCAL == rd->rd_op)
	  rd->rd_op = RD_UPDATE;
	if (RD_UPDATE == rd->rd_op)
	  {
	    rd->rd_keep_together_pos = rd->rd_map_pos;
	    rd->rd_keep_together_dp = pl->pl_page;
	    rd->rd_rl = NULL;
	  }
      }
      END_DO_BOX;
      ITC_DELTA (itc, buf);
      itc->itc_top_ceic = &ceic;
      page_apply (itc, buf, BOX_ELEMENTS (rds), rds, PA_RELEASE_PL | PA_SPLIT_UNLIKELY);
      itc->itc_top_ceic = NULL;
    }
  if (ceic.ceic_mp)
    mp_free (ceic.ceic_mp);
  if (enable_rq_check_all)
    rq_check_all ();
}


/* checkpoint rollback for col inxes */



mem_pool_t *cpt_mp;
dk_set_t cpt_col_uci;
row_no_t *cpt_uci_rows;


int
rl_any_cpt_rb (row_lock_t * rl, it_cursor_t * itc, int *uci_ctr)
{
  int inx, any = 0;
  for (inx = 0; inx < rl->rl_n_cols; inx++)
    {
      col_row_lock_t *clk = rl->rl_cols[inx];
      if (clk->clk_change & (CLK_INSERTED | CLK_DELETE_AT_ROLLBACK | CLK_REVERT_AT_ROLLBACK))
	any = 1;
      if (clk->clk_change & CLK_INSERTED)
	(*uci_ctr)++;
    }
  return any;
}

dbe_key_t *
key_newest (dbe_key_t * key)
{
  while (key->key_migrate_to)
    key = sch_id_to_key (wi_inst.wi_schema, key->key_migrate_to);
  return key;
}

void
pl_col_cpt_rb_page (page_lock_t * pl, it_cursor_t * itc)
{
  ce_ins_ctx_t ceic;
  row_lock_t *rls[COL_PAGE_MAX_ROWS];
  int rl_fill = 0, irl, inx, n_uci = 0;
  dbe_key_t *key;
  row_delta_t **rds;
  buffer_desc_t *buf = NULL;
  memset (&ceic, 0, sizeof (ce_ins_ctx_t));
  ceic.ceic_itc = itc;
  ceic.ceic_is_rb = RB_CPT;
  if (!itc->itc_is_col)
    itc_col_init (itc);
  else
    {
      itc_clear_col_refs (itc);
      if (BOX_ELEMENTS (itc->itc_col_refs) < itc->itc_insert_key->key_n_parts)
	{
	  col_data_ref_t **old_refs = itc->itc_col_refs;
	  itc->itc_col_refs = (col_data_ref_t **) itc_alloc_box (itc, itc->itc_insert_key->key_n_parts * sizeof (caddr_t), DV_BIN);
	  memzero (itc->itc_col_refs, box_length (itc->itc_col_refs));
	  memcpy_16 (itc->itc_col_refs, old_refs, box_length (old_refs));
	  itc_free_box (itc, (caddr_t) old_refs);
	}
    }
  if (DP_DELETED == pl->pl_page)
    return;

  do
    {
      if (DP_DELETED == pl->pl_page)
	{
	  ITC_LEAVE_MAPS (itc);
	  return;
	}
      ITC_IN_KNOWN_MAP (itc, pl->pl_page);
      page_wait_access (itc, pl->pl_page, NULL, &buf, PA_WRITE, RWG_WAIT_KEY);
    }
  while (itc->itc_to_reset > RWG_WAIT_KEY);

  if (PF_OF_DELETED == buf)
    {
      /* check needed here because the page could have gone out during the above wait and the wait itself could give 'a no wait status with bad timing  The page map does not serialize the whole delete as atomic. */
      ITC_LEAVE_MAPS (itc);
      return;
    }
  ITC_LEAVE_MAPS (itc);
  itc->itc_page = pl->pl_page;
  if (pl->pl_n_row_locks > buf->bd_content_map->pm_count)
    GPF_T1 ("more locks than rows");
  pl_remove_empty_rls (pl);
  key = key_newest (buf->bd_tree->it_key);
  DO_RLOCK (rl, pl)
  {
    if (rl_any_cpt_rb (rl, itc, &n_uci))
      {
	rls[rl_fill++] = rl;
	if (rl_fill >= COL_PAGE_MAX_ROWS)
	  GPF_T1 ("more col leaf rows than possible in col finalize");
      }
  }
  END_DO_RLOCK;
  buf_sort ((buffer_desc_t **) rls, rl_fill, (sort_key_func_t) rl_sort_key);
  if (n_uci)
    {
      rds = (row_delta_t **) mp_alloc_box_ni (cpt_mp, n_uci * sizeof (caddr_t), DV_BIN);
      for (inx = 0; inx < n_uci; inx++)
	{
	  row_delta_t *rd;
	  rds[inx] = rd = (row_delta_t *) mp_alloc_box (cpt_mp, sizeof (row_delta_t), DV_BIN);
	  memzero (rd, sizeof (row_delta_t));
	  rd->rd_key = key;
	  rd->rd_slice = itc->itc_tree->it_slice;
	  rd->rd_values = (caddr_t *) mp_alloc_box (cpt_mp, key->key_n_parts * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  memzero (rd->rd_values, box_length (rd->rd_values));
	}
      ceic.ceic_rb_rds = rds;
      mp_set_push (cpt_mp, &cpt_col_uci, (void *) rds);
      if (!cpt_uci_rows || box_length (cpt_uci_rows) / sizeof (row_no_t) < n_uci)
	cpt_uci_rows = (row_no_t *) mp_alloc_box (cpt_mp, 1000 + (n_uci * sizeof (row_no_t)), DV_BIN);
      ceic.ceic_deletes = cpt_uci_rows;
    }
  for (irl = 0; irl < rl_fill; irl++)
    {
      row_lock_t *rl = rls[irl];
      itc->itc_map_pos = rl->rl_pos;
      itc->itc_rl = rl;
      ceic_col_finalize_row (&ceic, buf, RB_CPT);
    }
  rds = ceic.ceic_rds;
  if (!rds || 0 == BOX_ELEMENTS (rds))
    {
      page_leave_outside_map (buf);
    }
  else
    {
      DO_BOX (row_delta_t *, rd, inx, rds)
      {
	if (RD_UPDATE_LOCAL == rd->rd_op)
	  rd->rd_op = RD_UPDATE;
	if (RD_UPDATE == rd->rd_op)
	  {
	    rd->rd_keep_together_pos = rd->rd_map_pos;
	    rd->rd_keep_together_dp = pl->pl_page;
	    rd->rd_rl = NULL;
	  }
      }
      END_DO_BOX;
      ITC_DELTA (itc, buf);
      itc->itc_top_ceic = &ceic;
      pl_remove_empty_rls (pl);	/* uncommitted inserts may have made some rls empty, these may end up on deleted rows which will confuse things if kept  */
      page_apply (itc, buf, BOX_ELEMENTS (rds), rds, PA_MODIFY | PA_SPLIT_UNLIKELY);
      itc->itc_top_ceic = NULL;
    }
  if (ceic.ceic_mp)
    mp_free (ceic.ceic_mp);
  itc->itc_matches = NULL;
}

#define NEED_CEIC \
{ \
  if (!col_ceic) \
    col_ceic = *col_ceic_ret = ceic_col_ceic (top_ceic); \
}


extern it_cursor_t *mcp_itc;


caddr_t
box_any_dv (db_buf_t dv)
{
  int l;
  DB_BUF_TLEN (l, *dv, dv);
  return box_n_chars (dv, l);
}

caddr_t
mp_box_any_dv (mem_pool_t * mp, db_buf_t dv)
{
  int l;
  DB_BUF_TLEN (l, *dv, dv);
  return mp_box_n_chars (mp, (caddr_t) dv, l);
}


void
itc_seg_uc_updates (it_cursor_t * itc, buffer_desc_t * buf, row_lock_t * rl, int is_restore)
{
  dk_set_t rds = NULL;
  int n_cols = itc->itc_insert_key->key_n_parts;
  int inx, cinx;
  itc->itc_map_pos = rl->rl_pos;
  itc->itc_n_matches = 0;
  itc->itc_matches = NULL;
  itc->itc_rl = rl;
  itc->itc_range_fill = 0;
  for (inx = 0; inx < rl->rl_n_cols; inx++)
    {
      col_row_lock_t *clk = rl->rl_cols[inx];
      if (clk->clk_rbe
	  && (is_restore ? (CLK_UC_UPDATE & clk->clk_change)
	      : (clk->pl_owner == itc->itc_ltrx && 0 == (CLK_UC_UPDATE & clk->clk_change))))
	{
	  NEW_VARZ (row_delta_t, rd);
	  rd->rd_allocated = RD_ALLOCATED;
	  rd->rd_values = dk_alloc_box_zero (n_cols * sizeof (caddr_t), DV_BIN);
	  cinx = 0;
	  DO_SET (dbe_column_t *, col, &itc->itc_insert_key->key_parts)
	  {
	    db_buf_t pre = clk->clk_rbe[cinx];
	    if (!pre)
	      rd->rd_values[cinx] = COL_UPD_NO_CHANGE;
	    else if (DV_ANY == col->col_sqt.sqt_col_dtp || IS_BLOB_DTP (col->col_sqt.sqt_col_dtp))
	      rd->rd_values[cinx] = box_any_dv (clk->clk_rbe[cinx]);
	    else
	      rd->rd_values[cinx] = box_deserialize_string ((caddr_t) clk->clk_rbe[cinx], INT32_MAX, 0);
	    cinx++;
	  }
	  END_DO_SET ();
	  dk_set_push (&rds, (void *) rd);
	  itc_range (itc, clk->clk_pos, clk->clk_pos + 1);
	}
    }
  itc->itc_vec_rds = (row_delta_t **) list_to_array (dk_set_nreverse (rds));
  if (!itc->itc_param_order || box_length (itc->itc_param_order) / sizeof (int) < itc->itc_range_fill)
    {
      itc_free_box (itc, itc->itc_param_order);
      itc->itc_param_order = (int *) itc_alloc_box (itc, sizeof (int) * (itc->itc_range_fill + 1000), DV_BIN);
    }
  int_asc_fill (itc->itc_param_order, itc->itc_range_fill, 0);
  itc->itc_col_first_set = 0;
  itc->itc_n_sets = itc->itc_range_fill;
  itc->itc_set = 0;
  itc_col_insert_rows (itc, buf, is_restore ? COL_CPT_RESTORE : COL_CPT_RB);
  rd_list_free (itc->itc_vec_rds);
  itc->itc_vec_rds = NULL;
  itc->itc_rl = NULL;
}


void
pl_cpt_col_page (page_lock_t * pl, it_cursor_t * itc, buffer_desc_t * buf, int is_restore)
{
  int is_on_page = 1;
  itc_ensure_col_refs (itc);
recheck:
  pl_remove_empty_rls (pl);
  DO_RLOCK (rl, pl)
  {
    int inx;
    for (inx = 0; inx < rl->rl_n_cols; inx++)
      {
	col_row_lock_t *clk = rl->rl_cols[inx];
	if (clk->clk_rbe)
	  {
	    if ((is_restore && (CLK_UC_UPDATE & clk->clk_change))
		|| (!is_restore && !(clk->clk_change & CLK_UC_UPDATE) && clk->pl_owner == itc->itc_ltrx))
	      {
		if (!is_on_page)
		  {
		    do
		      {
			if (DP_DELETED == pl->pl_page)
			  {
			    ITC_LEAVE_MAPS (itc);
			    return;
			  }
			ITC_IN_KNOWN_MAP (itc, pl->pl_page);
			page_wait_access (itc, pl->pl_page, NULL, &buf, PA_WRITE, RWG_WAIT_KEY);
		      }
		    while (itc->itc_to_reset > RWG_WAIT_KEY);
		    if (PF_OF_DELETED == buf)
		      {
			/* check needed here because the page could have gone out during the above wait and the wait itself could give 'a no wait status with bad timing  The page map does not serialize the whole delete as atomic. */
			ITC_LEAVE_MAPS (itc);
			return;
		      }
		    ITC_LEAVE_MAPS (itc);
		  }
		itc_seg_uc_updates (itc, buf, rl, is_restore);
		is_on_page = 0;
		goto recheck;
	      }
	  }
      }
  }
  END_DO_RLOCK;
  if (is_on_page)
    page_leave_outside_map (buf);
}


void
cpt_col_uncommitted (dbe_storage_t * dbs)
{
  cpt_mp = mem_pool_alloc ();
  cpt_col_uci = NULL;
  cpt_uci_rows = NULL;
  DO_SET (index_tree_t *, it, &dbs->dbs_trees)
  {
    int inx;
    if (!it->it_key || !it->it_key->key_is_col)
      continue;
    itc_from_it (mcp_itc, it);
    for (inx = 0; inx < IT_N_MAPS; inx++)
      {
	it_map_t *itm = &it->it_maps[inx];
	mutex_enter (&it->it_maps[inx].itm_mtx);
	DO_HT (ptrlong, dp, page_lock_t *, pl, &it->it_maps[inx].itm_locks)
	{
	  mutex_leave (&itm->itm_mtx);
	  pl_col_cpt_rb_page (pl, mcp_itc);
	  mutex_enter (&itm->itm_mtx);
	}
	END_DO_HT;
	mutex_leave (&itm->itm_mtx);
      }
  }
  END_DO_SET ();
  itc_col_free (mcp_itc);
}


void
dc_for_col (mem_pool_t * mp, row_delta_t ** rds, dbe_key_t * key, int nth_part, data_col_t * dc, int icol)
{
  int n_rds = BOX_ELEMENTS (rds), inx;
  state_slot_t ssl;
  dbe_column_t *col = (dbe_column_t *) dk_set_nth (key->key_parts, nth_part);
  if (!dc->dc_values)
    {
      memzero (&ssl, sizeof (state_slot_t));
      ssl.ssl_sqt = col->col_sqt;
      ssl.ssl_type = SSL_COLUMN;
      ssl_set_dc_type (&ssl);
      *dc = *mp_data_col (mp, &ssl, MAX (10000, n_rds));
    }
  dc_reset (dc);
  dc_convert_empty (dc, col->col_sqt.sqt_dtp);
  DC_CHECK_LEN (dc, n_rds - 1);
  for (inx = 0; inx < n_rds; inx++)
    {
      if (DV_ANY == col->col_sqt.sqt_dtp)
	{
	  ((caddr_t *) dc->dc_values)[dc->dc_n_values++] = rds[inx]->rd_values[icol];
	}
      else
	dc_append_box (dc, rds[inx]->rd_values[icol]);
    }
}



void
cpt_col_restore_uncommitted ()
{
  dtp_t right_temp[2000];
  it_cursor_t *itc = mcp_itc;
  data_col_t dcs[TB_MAX_COLS + 10];
  int inx;
  LEAVE_TXN;
  memzero (&dcs, sizeof (dcs));
  itc->itc_param_order = NULL;
  DO_SET (row_delta_t **, rds, &cpt_col_uci)
  {
    int n_rds = BOX_ELEMENTS (rds);
    row_delta_t *rd1 = rds[0];
    dbe_key_t *key = rd1->rd_key;
    LOCAL_RD (right_rd);
    right_rd.rd_temp = right_temp;
    right_rd.rd_temp_max = sizeof (right_temp);
    itc_free_owned_params (itc);
    ITC_START_SEARCH_PARS (itc);
    if (!itc->itc_param_order || box_length (itc->itc_param_order) / sizeof (int) < n_rds)
      {
	itc->itc_param_order = (int *) mp_alloc_box_ni (cpt_mp, (n_rds + 1000) * sizeof (int), DV_BIN);
	int_asc_fill (itc->itc_param_order, n_rds + 1000, 0);
      }
    itc_from (itc, key, rd1->rd_slice);
    if (itc->itc_is_col)
      itc_col_free (itc);
    itc_col_init (itc);
    itc->itc_right_leaf_key = &right_rd;
    itc->itc_keep_right_leaf = ITC_RL_INIT;
    itc->itc_vec_rds = rds;
    for (inx = 0; inx < key->key_n_significant; inx++)
      {
	dc_for_col (cpt_mp, rds, key, inx, &dcs[inx], key->key_part_in_layout_order[inx]);
	ITC_P_VEC (itc, inx) = &dcs[inx];
	itc_vec_box (itc, dcs[inx].dc_dtp, inx, &dcs[inx]);
      }
    itc->itc_set = 0;
    itc->itc_n_sets = n_rds;
    itc->itc_key_spec = key->key_insert_spec;
    itc_set_param_row (itc, 0);
    itc_col_vec_insert (itc, NULL);
  }
  END_DO_SET ();
  itc_col_free (itc);
  mp_free (cpt_mp);
  cpt_mp = NULL;
  IN_TXN;
}

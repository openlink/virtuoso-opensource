/*
 *  vecsearch.c
 *
 *  $Id$
 *
 *  Search
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
#include "arith.h"
#include "multibyte.h"
#include "srvmultibyte.h"
#include "xmlnode.h"
#include "sqlbif.h"
#include "srvstat.h"


#define dc_int_value(dc, inx)			\
  (dc->dc_is_32 ? (uint64)((uint32*)dc->dc_values)[inx] : ((uint64*)dc->dc_values)[inx])


void
itc_empty_set (it_cursor_t * itc)
{
}


int
itc_copy_last_set (it_cursor_t * itc)
{
  int inx, col_inx;
  int fill = itc->itc_n_results;
  int n_copied;
  int n_out = box_length ((caddr_t) itc->itc_vec_out_map) / sizeof (v_out_map_t);
  v_out_map_t *om = itc->itc_vec_out_map;
  caddr_t *inst = itc->itc_out_state;
  n_copied = fill - itc->itc_set_first;
  if (fill + n_copied > itc->itc_batch_size)
    return 0;
  for (col_inx = 0; col_inx < n_out; col_inx++)
    {
      data_col_t *dc = QST_BOX (data_col_t *, inst, om[col_inx].om_ssl->ssl_index);
      for (inx = itc->itc_set_first; inx < fill; inx++)
	{
	  dc_append (dc, dc, inx);
	}
    }
  itc->itc_set_first = itc->itc_n_results;
  itc->itc_n_results += n_copied;
  return 1;
}


int
itc_vec_split_search (it_cursor_t * itc, buffer_desc_t ** buf_ret, int at_or_above, dp_addr_t * leaf_ret)
{
new_page:
  {
    dp_addr_t leaf;
    buffer_desc_t *buf = *buf_ret;
    db_buf_t page = buf->bd_buffer, row;
    int res;
    page_map_t *map = buf->bd_content_map;
    int below = map->pm_count;
    int guess;
    int at_or_above_res = -100;
    key_ver_t kv;
    if (map->pm_count == 0)
      {
	itc->itc_map_pos = ITC_AT_END;
	return DVC_GREATER;
      }
    guess = (at_or_above + below) / 2;
    __builtin_prefetch (page + map->pm_entries[guess]);
    for (;;)
      {
	if ((below - at_or_above) <= 1)
	  {
	    if (at_or_above_res == -100)
	      {
		at_or_above_res = itc->itc_key_spec.ksp_key_cmp (buf, at_or_above, itc);
	      }
	    switch (at_or_above_res)
	      {
	      case DVC_MATCH:
	      case DVC_LESS:
		{
		  itc->itc_map_pos = at_or_above;
		  row = page + map->pm_entries[at_or_above];
		  kv = IE_KEY_VERSION (row);
		  if (KV_LEFT_DUMMY == kv)
		    leaf = LONG_REF (row + LD_LEAF);
		  else if (KV_LEAF_PTR == kv)
		    leaf = LONG_REF (row + itc->itc_insert_key->key_key_leaf[IE_ROW_VERSION (row)]);
		  else
		    leaf = 0;
		  if (leaf)
		    {
		      if (leaf_ret)
			{
			  *leaf_ret = leaf;
			  return DVC_LESS;
			}
		      itc_dive_transit (itc, buf_ret, leaf);
		      at_or_above = 0;
		      goto new_page;
		    }
		  itc->itc_row_data = row;
		  itc->itc_map_pos = at_or_above;
		  return at_or_above_res;
		}
	      case DVC_GREATER:
		{
		  /* The lower limit, 0 was greater. No way down. */
		  itc->itc_map_pos = at_or_above;
		  return DVC_GREATER;
		}
	      }
	  }
	/* OK, we have an interval to search */
	res = itc->itc_key_spec.ksp_key_cmp (buf, guess, itc);
	switch (res)
	  {
	  case DVC_LESS:
	    at_or_above = guess;
	    guess = at_or_above + ((below - at_or_above) / 2);
	    __builtin_prefetch (page + map->pm_entries[guess]);
	    at_or_above_res = res;
	    break;
	  case DVC_MATCH:	/* row found, dependent not checked */
	    if (SM_READ_EXACT == itc->itc_search_mode || SM_INSERT == itc->itc_search_mode)
	      {
		row = page + map->pm_entries[guess];
		kv = IE_KEY_VERSION (row);
		if (KV_LEAF_PTR == kv)
		  {
		    leaf = LONG_REF (row + itc->itc_insert_key->key_key_leaf[IE_ROW_VERSION (row)]);
		    if (leaf_ret)
		      {
			*leaf_ret = leaf;
			return DVC_LESS;
		      }
		    itc_dive_transit (itc, buf_ret, leaf);
		    at_or_above = 0;
		    goto new_page;
		  }
		itc->itc_map_pos = guess;
		itc->itc_row_data = row;
		return res;
	      }
	    else
	      {
		if (itc->itc_desc_order)
		  {
		    at_or_above = guess;
		    at_or_above_res = res;
		  }
		else
		  below = guess;
	      }
	    guess = at_or_above + ((below - at_or_above) / 2);
	    __builtin_prefetch (page + map->pm_entries[guess]);
	    break;

	  case DVC_GREATER:
	    below = guess;
	    guess = at_or_above + ((below - at_or_above) / 2);
	    __builtin_prefetch (page + map->pm_entries[guess]);
	    break;
	  default:
	    GPF_T1 ("key_cmp_t can't return that");
	  }
      }
  }
}


int
itc_temp_next_set (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  caddr_t *inst = itc->itc_out_state;
  QNCAST (query_instance_t, qi, inst);
  key_source_t *ks = itc->itc_ks;
  for (;;)
    {
      itc->itc_set++;
      if (itc->itc_set >= itc->itc_n_sets)
	return DVC_GREATER;
      qi->qi_set = qst_vec_get_int64 (inst, itc->itc_ks->ks_set_no, itc->itc_set);
      if (itc_from_sort_temp (itc, qi, ks->ks_from_temp_tree))
	{
	  page_leave_outside_map (*buf_ret);
	  *buf_ret = itc_reset (itc);
	  return DVC_MATCH;
	}
    }
}


long tc_same_parent;
long tc_same_page;
long tc_same_key;


int
itc_next_set_parent (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  /* if can access parent without wait, go there and see if key is before its end */
  page_map_t *pm;
  int rc = itc_up_transit (itc, buf_ret);
  if (DVC_MATCH != rc)
    return 0;
  pm = (*buf_ret)->bd_content_map;
  rc = itc->itc_key_spec.ksp_key_cmp (*buf_ret, pm->pm_count - 1, itc);
  if (DVC_LESS == rc)
    return 0;
  TC (tc_same_parent);
  itc->itc_ltrx->lt_client->cli_activity.da_same_parent++;
  itc->itc_landed = 0;
  if (PA_READ_ONLY != itc->itc_dive_mode)
    itc->itc_dive_mode = PA_WRITE;
  itc->itc_is_on_row = 0;
  if (!itc->itc_no_bitmap && itc->itc_insert_key->key_is_bitmap)
    itc_init_bm_search (itc);
  itc->itc_split_search_res = itc->itc_prev_split_search_res = itc_vec_split_search (itc, buf_ret, 0, NULL);
  if (itc->itc_is_registered)
    GPF_T1 ("itc should not be registered after search from same parent");
  itc->itc_rows_on_leaves += (*buf_ret)->bd_content_map->pm_count;
  itc->itc_landed = 1;
  itc->itc_nth_seq_page++;
  return DVC_MATCH;
}


#define    NEXT_SET_LAND_CHECK  \
{ \
  if (PA_READ == itc->itc_dive_mode) \
    { \
      if ((*buf_ret)->bd_is_write) \
        itc->itc_dive_mode = PA_WRITE; \
      itc->itc_landed = 0; \
      itc_try_land (itc, buf_ret); \
      if (!itc->itc_landed) \
	goto retry_landing; \
    } \
  else \
    { \
      itc->itc_landed = 1; \
      ITC_MARK_LANDED_NC (itc); \
      itc->itc_rows_on_leaves += (*buf_ret)->bd_content_map->pm_count; \
    } \
}


#define    NEXT_SET_SP_LAND_CHECK  \
{ \
  if (PA_READ == itc->itc_dive_mode) \
    { \
      if ((*buf_ret)->bd_is_write) \
        itc->itc_dive_mode = PA_WRITE; \
      itc->itc_landed = 0; \
      itc_try_land (itc, buf_ret); \
      if (!itc->itc_landed) \
	goto retry_landing; \
    } \
  else \
    { \
      itc->itc_landed = 1; \
      ITC_MARK_LANDED_NC (itc); \
    } \
}


int
itc_bm_next_set (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  /* next param row.  If same as previous, copy the results */
  page_map_t *pm;
  int rc, res, is_row_sp = 0;
  int sp2nd = 0;
  int n_pars, inx, all_eq = 0;
  search_spec_t *sp;
next_set:

  itc->itc_key_spec = itc->itc_ks->ks_spec;
  itc->itc_desc_order = 0;
  if (!itc->itc_key_spec.ksp_key_cmp)
    itc->itc_key_spec.ksp_key_cmp = pg_key_compare;
  sp2nd = 0;
  sp = itc->itc_key_spec.ksp_spec_array;
  if (!sp)
    {
      is_row_sp = 1;
      sp = itc->itc_row_specs;
    }
  else
    all_eq = 1;
  if (itc->itc_n_sets == itc->itc_set + 1)
    return DVC_GREATER;
  n_pars = itc->itc_search_par_fill;
  for (inx = 0; inx < n_pars; inx++)
    {
      char nnf, onf;
      data_col_t *dc = ITC_P_VEC (itc, inx);
      int ninx = itc->itc_param_order[itc->itc_set + 1];
      int64 new_v;
      if (!dc)
	goto next;
      new_v = dc_any_value_n (dc, ninx, &nnf);
      if (all_eq && !is_row_sp)
	{
	  int oinx = itc->itc_param_order[itc->itc_set];
	  int64 old_v = dc_any_value_n (dc, oinx, &onf);
	  if (onf && nnf)
	    ;
	  else if (nnf || onf || !((new_v == old_v && !dc->dc_any_null) || (DV_ANY == dc->dc_dtp
		      && DVC_MATCH == dc_cmp (dc, old_v, new_v))))
	    all_eq = 0;
	}
      if (DCT_NUM_INLINE & dc->dc_type)
	{
	  NEXT_SET_INL_NULL (dc, ninx, inx);
	  *(int64 *) itc->itc_search_params[inx] = new_v;
	}
      else if (DV_ANY == sp->sp_cl.cl_sqt.sqt_col_dtp)
	itc->itc_search_params[inx] = (caddr_t) (ptrlong) new_v;
      else if (DV_ANY == dc->dc_dtp)
	itc->itc_search_params[inx] = itc_temp_any_box (itc, inx, (db_buf_t) new_v);
      else if (DCT_BOXES & dc->dc_type)
	itc->itc_search_params[inx] = (caddr_t) (ptrlong) new_v;
      else if (!itc_vec_sp_copy (itc, inx, new_v, ninx))
	itc->itc_search_params[inx] = (caddr_t) (ptrlong) new_v;
    next:
      NEXT_SP_COL;
    }
  itc->itc_set++;
  if (all_eq)
    {
      TC (tc_same_key);
      if (itc->itc_is_pure)
	{
	  /* the next set is a copy of the previous */
	  if (-1 != itc->itc_set_first)
	    if (itc_copy_last_set (itc))
	      goto next_set;
	  goto start_at_reset;
	}
      else
	{
	  /* repeat of search params on thing with side effects, like aggregate */
	  rc = itc->itc_key_spec.ksp_key_cmp (*buf_ret, 0, itc);
	  if (DVC_LESS != rc)
	    goto start_at_reset;
	  itc->itc_map_pos = 0;
	}
    }
  itc->itc_set_first = itc->itc_n_results;
  if (!itc->itc_asc_eq)
    goto start_at_reset;
  pm = (*buf_ret)->bd_content_map;
  if (itc->itc_map_pos >= pm->pm_count)
    goto start_at_reset;
  rc = itc->itc_key_spec.ksp_key_cmp (*buf_ret, pm->pm_count - 1, itc);
  if (DVC_GREATER != rc)
    goto start_at_reset;
  if (0 == itc->itc_map_pos)
    {
      rc = itc->itc_key_spec.ksp_key_cmp (*buf_ret, 0, itc);
      if (DVC_GREATER == rc)
	goto start_at_reset;
    }
  TC (tc_same_page);
  itc->itc_ltrx->lt_client->cli_activity.da_same_page++;
  itc->itc_landed = 0;
  if (PA_READ_ONLY != itc->itc_dive_mode)
    itc->itc_dive_mode = PA_WRITE;
  itc->itc_is_on_row = 0;
  itc_init_bm_search (itc);
  itc->itc_split_search_res = itc_vec_split_search (itc, buf_ret, MAX (0, itc->itc_map_pos - 1), NULL);
  itc->itc_bp.bp_just_landed = 1;
  NEXT_SET_SP_LAND_CHECK;
  return DVC_MATCH;
start_at_reset:
  itc_page_leave (itc, *buf_ret);
retry_landing:
  if (PA_READ_ONLY != itc->itc_dive_mode)
    itc->itc_dive_mode = PA_READ;
  *buf_ret = itc_reset (itc);
  if (SM_READ == itc->itc_search_mode)
    res = itc_page_split_search (itc, buf_ret);
  else
    res = itc_page_insert_search (itc, buf_ret);
  NEXT_SET_LAND_CHECK;
  itc->itc_split_search_res = res;
  itc->itc_bp.bp_just_landed = 1;
  return DVC_MATCH;
}

int enable_next_set_neq = 1;

int
itc_next_set_neq (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  /* next param row.  If same as previous, copy the results */
  dp_addr_t parent, last_parent;
  page_map_t *pm;
  int rc, res, is_row_sp = 0, next_set;
  int sp2nd = 0;
  int n_pars, inx, all_eq = 0, first_diff, nth_part;
  search_spec_t *sp;
  if (itc->itc_n_results >= itc->itc_batch_size)
    return DVC_GREATER;
  if (KI_TEMP == itc->itc_insert_key->key_id)
    return itc_temp_next_set (itc, buf_ret);
  if (!itc->itc_set)
    itc->itc_rows_on_leaves += (*buf_ret)->bd_content_map->pm_count;
  if (!itc->itc_no_bitmap && itc->itc_insert_key->key_is_bitmap)
    return itc_bm_next_set (itc, buf_ret);
  itc->itc_col_row = COL_NO_ROW;
  itc->itc_is_multiseg_set = 0;
next_set:
  sp2nd = 0;
  sp = itc->itc_key_spec.ksp_spec_array;
  if (!sp)
    {
      is_row_sp = 1;
      sp = itc->itc_row_specs;
    }
  else
    all_eq = 1;
  first_diff = 0;
  nth_part = 0;
  if (itc->itc_n_sets == itc->itc_set + 1)
    return DVC_GREATER;
  next_set = itc->itc_set + 2;
  if (next_set >= itc->itc_n_sets)
    next_set--;
  next_set = itc->itc_param_order[next_set];
  n_pars = itc->itc_search_par_fill;
  for (inx = 0; inx < n_pars; inx++)
    {
      char nnf, onf;
      data_col_t *dc = ITC_P_VEC (itc, inx);
      int ninx = itc->itc_param_order[itc->itc_set + 1];
      int64 new_v;
      if (!dc)
	goto next;
      new_v = dc_any_value_n_prefetch (dc, ninx, next_set, &nnf);
      if (all_eq && !is_row_sp)
	{
	  int oinx = itc->itc_param_order[itc->itc_set];
	  int64 old_v = dc_any_value_n (dc, oinx, &onf);
	  if (nnf && onf)
	    ;
	  else if (nnf || onf || !((new_v == old_v && !dc->dc_any_null) || (DV_ANY == dc->dc_dtp
		      && DVC_MATCH == dc_cmp (dc, old_v, new_v))))
	    {
	      all_eq = 0;
	      first_diff = nth_part;
	    }
	}
      if (DCT_NUM_INLINE & dc->dc_type)
	{
	  NEXT_SET_INL_NULL (dc, ninx, inx);
	  *(int64 *) itc->itc_search_params[inx] = new_v;
	}
      else if (DV_ANY == sp->sp_cl.cl_sqt.sqt_col_dtp)
	itc->itc_search_params[inx] = (caddr_t) (ptrlong) new_v;
      else if (DV_ANY == dc->dc_dtp)
	itc->itc_search_params[inx] = itc_temp_any_box (itc, inx, (db_buf_t) new_v);
      else if (DCT_BOXES & dc->dc_type)
	itc->itc_search_params[inx] = (caddr_t) (ptrlong) new_v;
      else if (!itc_vec_sp_copy (itc, inx, new_v, ninx))
	itc->itc_search_params[inx] = (caddr_t) (ptrlong) new_v;
    next:
      NEXT_SP_COL;
      nth_part++;
    }
  itc->itc_set++;
  if (all_eq)
    {
      TC (tc_same_key);
      if (itc->itc_is_pure)
	{
	  /* the next set is a copy of the previous */
	  if (-1 != itc->itc_set_first)
	    if (itc_copy_last_set (itc))
	      goto next_set;
	  goto start_at_reset;
	}
      else
	{
	  if (SM_READ_EXACT == itc->itc_search_mode)
	    {
	      if (ITC_AT_END == itc->itc_map_pos)
		goto start_at_reset;
	      /* same exact keys as last set.  See if there is a result from ;last set.  If not, skip the set */
	      if (DVC_MATCH == itc->itc_prev_split_search_res)
		{
		  itc->itc_split_search_res = itc->itc_prev_split_search_res;
		  if (PA_READ_ONLY != itc->itc_dive_mode)
		    itc->itc_dive_mode = PA_WRITE;
		  itc->itc_landed = 1;
		  ITC_MARK_LANDED_NC (itc);
		  return DVC_MATCH;
		}
	    }
	  rc = itc->itc_key_spec.ksp_key_cmp (*buf_ret, 0, itc);
	  if (DVC_LESS != rc)
	    goto start_at_reset;
	  itc->itc_map_pos = 0;
	}
    }
  if (!itc->itc_asc_eq && first_diff >= itc->itc_n_vec_sort_cols)
    goto start_at_reset;
  itc->itc_set_first = itc->itc_n_results;
  pm = (*buf_ret)->bd_content_map;
  if (itc->itc_map_pos >= pm->pm_count)
    goto start_at_reset;
  rc = itc->itc_key_spec.ksp_key_cmp (*buf_ret, pm->pm_count - 1, itc);
  if (DVC_LESS == rc)
    {
      itc_check_col_prefetch (itc, *buf_ret);
      if (itc->itc_same_parent_miss > itc->itc_same_parent_hit)
	goto start_at_reset;
      if (itc_next_set_parent (itc, buf_ret))
	{
	  NEXT_SET_SP_LAND_CHECK;
	return DVC_MATCH;
	}
      goto start_at_reset;
    }
  TC (tc_same_page);
  itc->itc_ltrx->lt_client->cli_activity.da_same_page++;
  itc->itc_landed = 0;
  if (PA_READ_ONLY != itc->itc_dive_mode)
    itc->itc_dive_mode = PA_WRITE;
  itc->itc_is_on_row = 0;
  itc->itc_split_search_res = itc->itc_prev_split_search_res = itc_vec_split_search (itc, buf_ret, itc->itc_map_pos, NULL);
  NEXT_SET_SP_LAND_CHECK;
  return DVC_MATCH;
start_at_reset:
  last_parent = LONG_REF ((*buf_ret)->bd_buffer + DP_PARENT);
  itc_page_leave (itc, *buf_ret);
retry_landing:
  if (PA_READ_ONLY != itc->itc_dive_mode)
    itc->itc_dive_mode = PA_READ;
  *buf_ret = itc_reset (itc);
  if (SM_READ == itc->itc_search_mode)
    res = itc_page_split_search (itc, buf_ret);
  else
    res = itc_page_insert_search (itc, buf_ret);
  parent = LONG_REF ((*buf_ret)->bd_buffer + DP_PARENT);
  if (last_parent == parent)
    itc->itc_same_parent_hit++;
  else
    itc->itc_same_parent_miss++;
  itc->itc_split_search_res = itc->itc_prev_split_search_res = res;
  NEXT_SET_LAND_CHECK;
  return DVC_MATCH;
}


int
itc_next_set (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  /* next param row.  If same as previous, copy the results */
  dp_addr_t parent, last_parent;
  page_map_t *pm;
  int rc, res, is_row_sp = 0, next_set;
  int sp2nd = 0;
  int n_pars, inx, all_eq = 0;
  search_spec_t *sp;
  if (itc->itc_is_registered)
    GPF_T1 ("itc should not be registered when getting next set");
  if (itc->itc_n_results >= itc->itc_batch_size)
    return DVC_GREATER;
  if (KI_TEMP == itc->itc_insert_key->key_id)
    return itc_temp_next_set (itc, buf_ret);
  if (!itc->itc_set)
    itc->itc_rows_on_leaves += (*buf_ret)->bd_content_map->pm_count;
  if (!itc->itc_no_bitmap && itc->itc_insert_key->key_is_bitmap)
    return itc_bm_next_set (itc, buf_ret);
  if (!itc->itc_asc_eq && !itc->itc_desc_order && enable_next_set_neq && !itc->itc_ks->ks_oby_order)
    return itc_next_set_neq (itc, buf_ret);
  itc->itc_col_row = COL_NO_ROW;
  itc->itc_is_multiseg_set = 0;
next_set:
  sp2nd = 0;
  sp = itc->itc_key_spec.ksp_spec_array;
  if (!sp)
    {
      is_row_sp = 1;
      sp = itc->itc_row_specs;
    }
  else
    all_eq = 1;
  if (itc->itc_n_sets == itc->itc_set + 1)
    return DVC_GREATER;
  next_set = itc->itc_set + 2;
  if (next_set >= itc->itc_n_sets)
    next_set--;
  next_set = itc->itc_param_order[next_set];
  n_pars = itc->itc_search_par_fill;
  for (inx = 0; inx < n_pars; inx++)
    {
      char nnf, onf;
      data_col_t *dc = ITC_P_VEC (itc, inx);
      int ninx = itc->itc_param_order[itc->itc_set + 1];
      int64 new_v;
      if (!dc)
	goto next;
      new_v = dc_any_value_n_prefetch (dc, ninx, next_set, &nnf);
      if (all_eq && !is_row_sp)
	{
	  int oinx = itc->itc_param_order[itc->itc_set];
	  int64 old_v = dc_any_value_n (dc, oinx, &onf);
	  if (nnf && onf)
	    ;
	  else if (nnf || onf || !((new_v == old_v && !dc->dc_any_null) || (DV_ANY == dc->dc_dtp
		      && DVC_MATCH == dc_cmp (dc, old_v, new_v))))
	    all_eq = 0;
	}
      if (DCT_NUM_INLINE & dc->dc_type)
	{
	  NEXT_SET_INL_NULL (dc, ninx, inx);
	  *(int64 *) itc->itc_search_params[inx] = new_v;
	}
      else if (DV_ANY == sp->sp_cl.cl_sqt.sqt_col_dtp)
	itc->itc_search_params[inx] = (caddr_t) (ptrlong) new_v;
      else if (DV_ANY == dc->dc_dtp)
	itc->itc_search_params[inx] = itc_temp_any_box (itc, inx, (db_buf_t) new_v);
      else if (DCT_BOXES & dc->dc_type)
	itc->itc_search_params[inx] = (caddr_t) (ptrlong) new_v;
      else if (!itc_vec_sp_copy (itc, inx, new_v, ninx))
	itc->itc_search_params[inx] = (caddr_t) (ptrlong) new_v;
    next:
      NEXT_SP_COL;
    }
  itc->itc_set++;
  if (all_eq)
    {
      TC (tc_same_key);
      if (itc->itc_is_pure)
	{
	  /* the next set is a copy of the previous */
	  if (-1 != itc->itc_set_first)
	    if (itc_copy_last_set (itc))
	      goto next_set;
	  goto start_at_reset;
	}
      else
	{
	  if (SM_READ_EXACT == itc->itc_search_mode)
	    {
	      if (ITC_AT_END == itc->itc_map_pos)
		goto start_at_reset;
	      /* same exact keys as last set.  See if there is a result from ;last set.  If not, skip the set */
	      if (DVC_MATCH == itc->itc_prev_split_search_res)
		{
		  itc->itc_split_search_res = itc->itc_prev_split_search_res;
		  itc->itc_landed = 1;
		  ITC_MARK_LANDED_NC (itc);
		  if (PA_READ_ONLY != itc->itc_dive_mode)
		    itc->itc_dive_mode = PA_WRITE;
		  return DVC_MATCH;
		}
	    }
	  rc = itc->itc_key_spec.ksp_key_cmp (*buf_ret, 0, itc);
	  if (DVC_LESS != rc)
	    goto start_at_reset;
	  itc->itc_map_pos = 0;
	}
    }
  itc->itc_set_first = itc->itc_n_results;
  if (!itc->itc_asc_eq)
    goto start_at_reset;
  pm = (*buf_ret)->bd_content_map;
  if (itc->itc_map_pos >= pm->pm_count)
    goto start_at_reset;
  rc = itc->itc_key_spec.ksp_key_cmp (*buf_ret, pm->pm_count - 1, itc);
  if (DVC_LESS == rc)
    {
      itc_check_col_prefetch (itc, *buf_ret);
      if (itc->itc_same_parent_miss > itc->itc_same_parent_hit)
	goto start_at_reset;
      if (itc_next_set_parent (itc, buf_ret))
	{
	  NEXT_SET_SP_LAND_CHECK;
	return DVC_MATCH;
	}
      goto start_at_reset;
    }
  TC (tc_same_page);
  itc->itc_ltrx->lt_client->cli_activity.da_same_page++;
  itc->itc_landed = 0;
  itc->itc_is_on_row = 0;
  if (DVC_MATCH == rc && SM_READ_EXACT == itc->itc_search_mode)
    {
      itc->itc_map_pos = pm->pm_count - 1;
      itc->itc_prev_split_search_res = itc->itc_split_search_res = DVC_MATCH;
      NEXT_SET_SP_LAND_CHECK;
      return DVC_MATCH;
    }
  if (PA_READ_ONLY != itc->itc_dive_mode)
    itc->itc_dive_mode = PA_WRITE;
  itc->itc_split_search_res = itc->itc_prev_split_search_res = itc_vec_split_search (itc, buf_ret, itc->itc_map_pos, NULL);
  NEXT_SET_SP_LAND_CHECK;
  return DVC_MATCH;
start_at_reset:
  last_parent = LONG_REF ((*buf_ret)->bd_buffer + DP_PARENT);
  itc_page_leave (itc, *buf_ret);
retry_landing:
  if (PA_READ_ONLY != itc->itc_dive_mode)
    itc->itc_dive_mode = PA_READ;
  *buf_ret = itc_reset (itc);
  if (SM_READ == itc->itc_search_mode)
    res = itc_page_split_search (itc, buf_ret);
  else
    res = itc_page_insert_search (itc, buf_ret);
  parent = LONG_REF ((*buf_ret)->bd_buffer + DP_PARENT);
  if (last_parent == parent)
    itc->itc_same_parent_hit++;
  else
    itc->itc_same_parent_miss++;
  itc->itc_split_search_res = itc->itc_prev_split_search_res = res;
  NEXT_SET_LAND_CHECK;
  return DVC_MATCH;
}


#define ITC_OUT_MAP(itc) itc->itc_ks->ks_out_map

void
itc_pop_last_out (it_cursor_t * itc, caddr_t * inst, v_out_map_t * om, buffer_desc_t * buf)
{
  int n = box_length ((caddr_t) om) / sizeof (v_out_map_t), inx;
  for (inx = 0; inx < n; inx++)
    {
      data_col_t *dc;
      if (!om[inx].om_ssl)
	continue;
      dc = QST_BOX (data_col_t *, inst, om[inx].om_ssl->ssl_index);
      if (DCT_NUM_INLINE & dc->dc_type)
	{
	  dc->dc_n_values--;
	  if (dc->dc_nulls)
	    DC_CLR_NULL (dc, dc->dc_n_values);
	}
      else
	{
	  if (DCT_BOXES & dc->dc_type)
	    {
	      caddr_t box = ((caddr_t *) dc->dc_values)[dc->dc_n_values - 1];
	      /* this is in on the page where the placeholder was registered so unregister before the free because free would hang in reentering the page */
	      if (DV_ITC == DV_TYPE_OF (box))
		itc_unregister_inner ((it_cursor_t *) box, buf, 0);
	    }
	dc_pop_last (dc);
    }
    }
  if (RSP_CHANGED == itc->itc_hash_row_spec)
    {
      search_spec_t *sp;
      for (sp = itc->itc_row_specs; sp; sp = sp->sp_next)
	{
	  if (CMP_HASH_RANGE == sp->sp_min_op && CMP_HASH_RANGE_ONLY != sp->sp_max_op)
	    {
	      hash_range_spec_t *hrng = (hash_range_spec_t *) sp->sp_min_ssl;
	      hash_source_t *hs = hrng->hrng_hs;
	      if (hs && hs->hs_merged_into_ts && hs->hs_out_slots)
		{
		  int inx;
		  DO_BOX (state_slot_t *, ssl, inx, hrng->hrng_hs->hs_out_slots)
		  {
		    data_col_t *dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
		    dc_pop_last (dc);
		  }
		  END_DO_BOX;
		}
	    }
	}
    }
}


int
itc_vec_row_check (it_cursor_t * itc, buffer_desc_t * buf)
{
  v_out_map_t *om;
  int n_out, inx;
  key_source_t *ks;
  table_source_t *ts;
  dbe_key_t *row_key = NULL;
  /* Check the key id's and non-key columns. */
  search_spec_t *sp;
  caddr_t *inst = itc->itc_out_state;
  if (IE_KEY_VERSION (itc->itc_row_data) == itc->itc_insert_key->key_version)
    itc->itc_row_key = itc->itc_insert_key;
  else
    {
      ITC_REAL_ROW_KEY (itc);
      if (!sch_is_subkey (isp_schema (NULL), itc->itc_row_key->key_id, itc->itc_insert_key->key_id))
	return DVC_LESS;	/* Key specified but this ain't it */
      row_key = itc->itc_row_key;
    }

  sp = itc->itc_row_specs;
  if (sp)
    {
      do
	{
	  int op = sp->sp_min_op;
	  search_spec_t sp_auto;

	  if (row_key)
	    {
	      dbe_col_loc_t *cl = key_find_cl (row_key, sp->sp_cl.cl_col_id);
	      if (cl)
		{
		  memcpy (&sp_auto, sp, sizeof (search_spec_t));
		  sp = &sp_auto;
		  sp->sp_cl = *cl;
		}
	      else
		{
		  dbe_column_t *col = sch_id_to_column (wi_inst.wi_schema, sp->sp_cl.cl_col_id);
		  if (col && col->col_default)
		    {
		      if (DVC_CMP_MASK & op)
			{
			  if (0 == (op & cmp_boxes (col->col_default, itc->itc_search_params[sp->sp_min], sp->sp_collation,
				      sp->sp_collation)))
			    return DVC_LESS;
			}
		      else if (op == CMP_LIKE)
			{
			  caddr_t v = itc->itc_search_params[sp->sp_min];
			  int st = LIKE_ARG_CHAR, pt = LIKE_ARG_CHAR;
			  dtp_t rtype = DV_TYPE_OF (v);
			  dtp_t ltype = DV_TYPE_OF (col->col_default);
			  if (DV_WIDE == rtype || DV_LONG_WIDE == rtype)
			    pt = LIKE_ARG_WCHAR;
			  if (DV_WIDE == ltype || DV_LONG_WIDE == ltype)
			    st = LIKE_ARG_WCHAR;
			  if (DVC_MATCH != cmp_like (col->col_default, v, sp->sp_collation, sp->sp_like_escape, st, pt))
			    return DVC_LESS;
			}
		      if (sp->sp_max_op != CMP_NONE
			  && (0 == (sp->sp_max_op & cmp_boxes (col->col_default, itc->itc_search_params[sp->sp_max],
				      sp->sp_collation, sp->sp_collation))))
			return DVC_LESS;
		      goto next_sp;
		    }
		  return DVC_LESS;
		}
	    }

	  if (ITC_NULL_CK (itc, sp->sp_cl))
	    return DVC_LESS;
	  if (DVC_CMP_MASK & op)
	    {
	      int res = page_col_cmp_1 (buf, itc->itc_row_data, &sp->sp_cl, itc->itc_search_params[sp->sp_min]);
	      if (0 == (op & res) || (DVC_NOORDER & res))
		return DVC_LESS;
	    }
	  else if (op == CMP_LIKE)
	    {
	      if (DVC_MATCH != itc_like_compare (itc, buf, itc->itc_search_params[sp->sp_min], sp))
		return DVC_LESS;
	      goto next_sp;
	    }
	  else if (CMP_HASH_RANGE == op)
	    {
	      if (DVC_MATCH != itc_hash_compare (itc, buf, sp))
		return DVC_LESS;
	      goto next_sp;
	    }
	  if (sp->sp_max_op != CMP_NONE)
	    {
	      int res = page_col_cmp_1 (buf, itc->itc_row_data, &sp->sp_cl, itc->itc_search_params[sp->sp_max]);
	      if (0 == (sp->sp_max_op & res) || (DVC_NOORDER & res))
		return DVC_LESS;
	    }
	next_sp:
	  sp = sp->sp_next;
	}
      while (sp);
    }
  ks = itc->itc_ks;
  ts = ks->ks_ts;
  om = itc->itc_v_out_map;
  n_out = box_length ((caddr_t) om) / sizeof (v_out_map_t);
  if (!row_key)
    {
      for (inx = 0; inx < n_out; inx++)
	{
	  om[inx].om_ref (itc, buf, &om[inx].om_cl, itc->itc_out_state, om[inx].om_ssl);
	}
    }
  else
    {
      for (inx = 0; inx < n_out; inx++)
	{
	  data_col_t *dc;
	  dbe_col_loc_t *cl;
	  if (dc_itc_delete == om[inx].om_ref)
	    {
	      om[inx].om_ref (itc, buf, &om[inx].om_cl, itc->itc_out_state, om[inx].om_ssl);
	      continue;
	    }
	  dc = QST_BOX (data_col_t *, inst, om[inx].om_ssl->ssl_index);
	  cl = key_find_cl (row_key, om[inx].om_cl.cl_col_id);
	  if (dc_itc_placeholder == om[inx].om_ref)
	    {
	      om[inx].om_ref (itc, buf, &om[inx].om_cl, itc->itc_out_state, om[inx].om_ssl);
	      continue;
	    }
	  if (!cl)
	    {
	      dbe_column_t *col = sch_id_to_column (wi_inst.wi_schema, om[inx].om_cl.cl_col_id);
	      if (col && col->col_default)
		dc_append_box (dc, col->col_default);
	      else
		dc_append_null (dc);
	    }
	  else
	    om[inx].om_ref (itc, buf, cl, itc->itc_out_state, om[inx].om_ssl);
	}
    }
  itc->itc_n_results++;
  if (ks->ks_set_no_col_ssl)
    {
      data_col_t *dc = QST_BOX (data_col_t *, inst, ks->ks_set_no_col_ssl->ssl_index);
      int64 set_no = ((int64 *) dc->dc_values)[dc->dc_n_values - 1];
      if (ks->ks_is_proc_view)
	set_no = set_no >> 40;	/* in a proc view temp the setr no is in the high bits and the sequence no in the set is in the low bits */
      qn_result ((data_source_t *) ts, inst, set_no);
    }
  else
    qn_result ((data_source_t *) itc->itc_ks->ks_ts, inst, itc->itc_param_order[itc->itc_set]);
  if (ks->ks_local_test)
    {
      QNCAST (query_instance_t, qi, inst);
      qi->qi_set_mask = NULL;
      qi->qi_set = itc->itc_n_results - 1;
      if (!code_vec_run_no_catch (ks->ks_local_test, itc))
	{
	  QST_INT (inst, ts->src_gen.src_out_fill)--;
	  itc->itc_n_results--;
	  itc_pop_last_out (itc, inst, ks->ks_v_out_map, buf);
	  return DVC_LESS;
	}
    }
  KEY_TOUCH (itc->itc_insert_key);
  if (IS_QN (ts, table_source_input) && ts->ts_max_rows)
    {
      if (1 == ts->ts_max_rows)
    return DVC_GREATER;
      else if (1 == itc->itc_n_sets && itc->itc_n_results >= ts->ts_max_rows)
	return DVC_GREATER;
    }
  return DVC_MATCH;
}


int
itc_next_set_before_search (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  int res = itc_next_set (itc, buf_ret);
  /* itc_search wants itc_landed to be 0. Other uses of itc_next_set want the itc in a landed state */
  if (DVC_MATCH == res)
    {
      itc->itc_ltrx->lt_client->cli_activity.da_random_rows--;	/* the following itc search will again increment this, do not count twice */
      if (!itc->itc_tree->it_hi)
	{
	  itc->itc_landed = 0;
	  if ((*buf_ret)->bd_is_write)
	    itc->itc_dive_mode = PA_WRITE;
	}
    }
  return res;
}


int
itc_vec_next (it_cursor_t * it, buffer_desc_t ** buf_ret)
{
  key_source_t *ks;
  if (it->itc_is_on_row)
    {
      ITC_MARK_ROW (it);
      it->itc_is_on_row = 0;
      if (it->itc_insert_key->key_is_col)
	{
	  it->itc_col_row++;
	}
      else if (it->itc_insert_key->key_is_bitmap)
	{
	  itc_next_bit (it, *buf_ret);
	  if (!it->itc_bp.bp_is_pos_valid)
	    goto skip_bitmap;	/* If pos still not valid We are on a non-eaf and must get to a leaf before setting the bitmap stiff, sp dp as if no bm */
	  if (it->itc_bp.bp_at_end)
	    {
	      it->itc_bp.bp_new_on_row = 1;
	      if (it->itc_desc_order)
		itc_prev_entry (it, *buf_ret);
	      else
		itc_skip_entry (it, *buf_ret);
	    }
	}
      else if (it->itc_tree->it_hi)
	itc_hash_next (it, *buf_ret);
      else
	{
	  if (it->itc_desc_order)
	    itc_prev_entry (it, *buf_ret);
	  else
	    itc_skip_entry (it, *buf_ret);
	}
    }
skip_bitmap:
  ks = it->itc_ks;
  if (ks && (ks->ks_local_test || ks->ks_local_code || ks->ks_setp))
    {
      int rc;
      query_instance_t *volatile qi = (query_instance_t *) it->itc_out_state;
      QR_RESET_CTX_T (qi->qi_thread)
      {
	ITC_FAIL (it)
	{
	  do
	    {
	      rc = itc_search (it, buf_ret);
	      it->itc_desc_serial_landed = 0;
	    }
	  while (DVC_MATCH == itc_next_set_before_search (it, buf_ret));
	}
	ITC_FAILED
	{
	}
      END_FAIL_THR (it, qi->qi_thread)}
      QR_RESET_CODE
      {
	POP_QR_RESET;
	if (RST_ERROR == reset_code)
	  {
	    itc_page_leave (it, *buf_ret);	/* if comes out with deadlock or other txn error, the buffer is left already */
	    qi_check_trx_error (qi, 0);
	  }
	/* assert for buf */
	longjmp_splice (qi->qi_thread->thr_reset_ctx, reset_code);
      }
      END_QR_RESET;
      return rc;
    }
  else
    {
      int rc;
      do
	{
	  rc = itc_search (it, buf_ret);
	  it->itc_desc_serial_landed = 0;
	}
      while (DVC_MATCH == itc_next_set_before_search (it, buf_ret));
      return rc;
    }
}

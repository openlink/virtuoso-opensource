/*
 *  update.c
 *
 *  $Id$
 *
 *  UPDATE statements
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
 */

#include "sqlnode.h"
#include "sqlfn.h"
#include "xmltree.h"
#include "sqlopcod.h"


#define ALL_KEYS	((dk_set_t) -1L)
#define BLOB_ERROR	((dk_set_t) -2L)



void
upd_mark_change (dbe_table_t * tb, oid_t col, dk_set_t * keys)
{
  if (*keys == ALL_KEYS)
    return;
  DO_SET (dbe_key_t *, key, &tb->tb_keys)
  {
    int ctr, n_parts = key->key_n_significant;
    dk_set_t parts = key->key_parts;
    if (!dk_set_member (*keys, (void *) key))
      {
	for (ctr = 0; ctr < n_parts; ctr++)
	  {
	    dbe_column_t *kcol = (dbe_column_t *) parts->data;
	    if (kcol->col_id == col)
	      {
		if (key->key_is_primary)
		  {
		    dk_set_free (*keys);
		    *keys = ALL_KEYS;
		    return;
		  }
		dk_set_pushnew (keys, (void *) key);
		break;
	      }
	    parts = parts->next;
	  }
      }
  }
  END_DO_SET ();
}


#define COL_NO_CHANGE -1
#define COL_MISC -2

int
upd_col_to_update (update_node_t * upd, dbe_column_t * col, caddr_t * state,
		   dbe_table_t * row_tb, int is_rec)
{
  if (!upd->upd_cols_param)
    {
      int n, len = BOX_ELEMENTS (upd->upd_col_ids);
      for (n = 0; n < len; n++)
	if (upd->upd_col_ids[n] == col->col_id)
	  return n;
    }
  else
    {
      oid_t *cols = (oid_t *) qst_get (state, upd->upd_cols_param);
      int n, len = BOX_ELEMENTS (cols);
      for (n = 0; n < len; n++)
	{
	  if (cols[n] == col->col_id)
	    return n;
	}
    }
  return COL_NO_CHANGE;
}


int
upd_n_cols  (update_node_t * upd, caddr_t * state)
{
  if (!upd->upd_values_param)
    return (BOX_ELEMENTS (upd->upd_col_ids));
  else
    return (BOX_ELEMENTS (qst_get (state, upd->upd_cols_param)));
}


oid_t
upd_nth_col  (update_node_t * upd, caddr_t * state, int inx)
{
  if (!upd->upd_values_param)
    return (upd->upd_col_ids[inx]);
  else
    return (((oid_t *) qst_get (state, upd->upd_cols_param))[inx]);
}

caddr_t
upd_nth_value (update_node_t * upd, caddr_t * state, int nth)
{
  if (!upd->upd_values_param)
    return (QST_GET (state, upd->upd_values[nth]));
  else
    return (((caddr_t *) qst_get (state, upd->upd_values_param))[nth]);
}


void
upd_col_copy (dbe_key_t * key, dbe_col_loc_t * new_cl, db_buf_t new_image, int * v_fill, int max,
	      dbe_col_loc_t * old_cl, db_buf_t  old_image, int old_off, int old_len)
{
  if (old_cl->cl_null_mask && (old_image[old_cl->cl_null_flag] & old_cl->cl_null_mask))
    {
      new_image[new_cl->cl_null_flag] |= new_cl->cl_null_mask;
      if (new_cl->cl_fixed_len == CL_FIRST_VAR)
	SHORT_SET (new_image + key->key_length_area, *v_fill);
      else if (new_cl->cl_fixed_len <= 0)
	SHORT_SET ((new_image - new_cl->cl_fixed_len) + 2, *v_fill);
      return;
    }
  if (new_cl->cl_null_mask)
    new_image[new_cl->cl_null_flag] &= ~new_cl->cl_null_mask;
  if (new_cl->cl_fixed_len > 0)
    memcpy (new_image + new_cl->cl_pos, old_image + old_off, new_cl->cl_fixed_len);
  else
    {
      if (*v_fill + old_len > max)
	{
	  *v_fill = max + 1;
	  return;
	}
      memcpy (new_image + *v_fill, old_image + old_off, old_len);
      (*v_fill) += old_len;
      if (CL_FIRST_VAR == new_cl->cl_fixed_len)
	SHORT_SET (new_image + key->key_length_area, *v_fill);
      else
	SHORT_SET ((new_image - new_cl->cl_fixed_len) + 2, *v_fill);
    }
}

dk_set_t
upd_recompose_row (caddr_t * state, update_node_t * upd,
		   dbe_table_t * tb, dbe_table_t * new_tb, dtp_t * new_image,
		   dtp_t * old_image, it_cursor_t * itc,
		   caddr_t * err_ret,
		   int * any_blobs, dbe_key_t *row_key)
{
  db_buf_t old_blob;
  int old_off = 0, old_len = 0;
  int v_fill = new_tb->tb_primary_key->key_row_var_start;
  int nth_part = 0;
  dk_set_t changed_keys = NULL;
  int nth_val;


  SHORT_SET (&new_image[IE_KEY_ID], new_tb->tb_primary_key->key_id);
  SHORT_SET (&new_image[IE_NEXT_IE], 0);
  new_image += IE_FIRST_KEY;
  DO_SET (dbe_column_t *, col, &new_tb->tb_primary_key->key_parts)
    {
      dbe_col_loc_t * new_cl = key_find_cl (new_tb->tb_primary_key, col->col_id);
      dbe_col_loc_t * old_cl = key_find_cl (tb->tb_primary_key->key_id != row_key->key_id ?
	  row_key : tb->tb_primary_key, col->col_id);
      if (old_cl)
	{
	  KEY_COL (row_key, old_image, (*old_cl), old_off, old_len);
	}
      nth_val = upd_col_to_update (upd, col, state, new_tb, 0);
      if (COL_NO_CHANGE == nth_val)
	{
	  if (old_cl)
	    {
	      /* OE: a blob may get inlined. If does do not delete dp until commit in case
		 this were rolled back */
	      if (IS_BLOB_DTP (old_cl->cl_sqt.sqt_dtp))
		itc->itc_has_blob_logged = 1;
	      upd_col_copy (new_tb->tb_primary_key, new_cl, new_image,
		  &v_fill, ROW_MAX_DATA * 2, old_cl, old_image, old_off, old_len);
	    }
	  else
	    {
	      row_set_col (&new_image[0], new_cl, col->col_default, &v_fill, ROW_MAX_DATA * 2,
		  new_tb->tb_primary_key, err_ret, itc, (db_buf_t) "\000", state);
	    }
	  goto complete_key_column;
	}
      {
	caddr_t new_val_of_col = upd_nth_value (upd, state, nth_val);
	if (old_cl && 0 == (old_image[old_cl->cl_null_flag] & old_cl->cl_null_mask)
	    && IS_BLOB_DTP (old_cl->cl_sqt.sqt_dtp))
	  old_blob = old_image + old_off;  /* if col exists in prev row and is not null and is a blob */
	else
	  old_blob = (db_buf_t) "\000"; /* there was no old value for added col */
	if (IS_BLOB_DTP (new_cl->cl_sqt.sqt_dtp))
	  *any_blobs = 1;
	row_set_col (&new_image[0], new_cl, new_val_of_col, &v_fill, ROW_MAX_DATA * 2,
		     new_tb->tb_primary_key, err_ret, itc, old_blob, state);
	if (*err_ret)
	  {
	    if (changed_keys != ALL_KEYS && changed_keys != BLOB_ERROR)
	      dk_set_free (changed_keys);
	    return NULL;
	  }
	/* if old and new values are different... No real check */
	if (1)
	  {
	    upd_mark_change (tb, col->col_id, &changed_keys);
	  }
      }
    complete_key_column:
      nth_part++;
      if (nth_part <= new_tb->tb_primary_key->key_n_significant &&
	  (v_fill - new_tb->tb_primary_key->key_row_var_start + new_tb->tb_primary_key->key_key_var_start) >
	  MAX_RULING_PART_BYTES)
	{
	  *err_ret = srv_make_new_error ("42000", "SR437", "Ruling part too long in update");
	  if (changed_keys != ALL_KEYS && changed_keys != BLOB_ERROR)
	    dk_set_free (changed_keys);
	  return NULL;
	}
    }
  END_DO_SET ();
  if (v_fill > ROW_MAX_DATA * 2)
    {
      *err_ret = srv_make_new_error ("42000", "SR248", "Row too long in update");
      if (changed_keys != ALL_KEYS && changed_keys != BLOB_ERROR)
	dk_set_free (changed_keys);
      return NULL;
    }
  if (new_tb->tb_any_blobs)
    {
      itc->itc_row_key = new_tb->tb_primary_key;
      itc->itc_row_key_id = new_tb->tb_primary_key->key_id;
      upd_blob_opt (itc, new_image - IE_FIRST_KEY, err_ret, 0);
      if (NULL != err_ret[0])
	{
	  if (changed_keys != ALL_KEYS && changed_keys != BLOB_ERROR)
	    dk_set_free (changed_keys);
	  return NULL;
	}
    }
  else if (v_fill > ROW_MAX_DATA)
    {
      *err_ret = srv_make_new_error ("42000", "SR438", "Row too long in update");
      if (changed_keys != ALL_KEYS && changed_keys != BLOB_ERROR)
	dk_set_free (changed_keys);
      return NULL;
    }
  return changed_keys;
}


void
itc_insert_row_params (it_cursor_t * ins_itc, db_buf_t row)
{
  caddr_t val;
  int inx = 0;
  dbe_key_t * key = ins_itc->itc_insert_key;
  itc_free_owned_params (ins_itc);
  ins_itc->itc_position = 0;
  ins_itc->itc_row_key = ins_itc->itc_insert_key;
  ins_itc->itc_row_key_id = ins_itc->itc_row_key->key_id;
  ins_itc->itc_row_data = row + IE_FIRST_KEY;
  ins_itc->itc_key_spec = ins_itc->itc_insert_key->key_insert_spec;
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      if (++inx > key->key_n_significant)
	break;
      val = itc_box_column (ins_itc, row, col->col_id, NULL);
      if (DV_ANY == col->col_sqt.sqt_dtp ||
       DV_OBJECT == col->col_sqt.sqt_dtp)
	{
	  caddr_t err = NULL;
	  caddr_t box_val = box_to_any (val, &err);
	  dk_free_tree (val);
	  val = box_val;
	}
      ITC_SEARCH_PARAM (ins_itc, val);
      ITC_OWNS_PARAM (ins_itc, val);
    }
  END_DO_SET();
}


void
upd_insert_2nd_key (dbe_key_t * key, it_cursor_t * ins_itc,
		    dbe_key_t * img_key, dtp_t * new_image)
{
  caddr_t err = NULL;
  int v_fill = key->key_row_var_start;
  int nth = 0;
  union
   {
     dtp_t key_image[MAX_ROW_BYTES];
     double __align_dummy;
   } v;
#define key_image v.key_image



  SHORT_SET (&key_image[IE_KEY_ID], key->key_id);
  SHORT_SET (&key_image[IE_NEXT_IE], 0);
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      int main_len, main_off;
      dbe_col_loc_t * main_cl = key_find_cl (img_key, col->col_id);
      dbe_col_loc_t * new_cl = key_find_cl (key, col->col_id);
      if (main_cl)
	{
	  KEY_COL (img_key, new_image, (*main_cl), main_off, main_len);
	  upd_col_copy (key, new_cl, &key_image[IE_FIRST_KEY], &v_fill, ROW_MAX_DATA, main_cl, new_image, main_off, main_len);
	}
      else
	{
	  row_set_col (&key_image[IE_FIRST_KEY], new_cl, col->col_default, &v_fill, ROW_MAX_DATA,
	      key, &err, ins_itc, (db_buf_t) "\000", NULL);
	}

      nth++;
      if (err)
	break;
    }
  END_DO_SET ();


  if (err || v_fill + (IE_LP_FIRST_KEY - IE_FIRST_KEY) > MAX_RULING_PART_BYTES)
    {
      if (CLI_IS_ROLL_FORWARD (ins_itc->itc_ltrx->lt_client))
	return;
      TRX_POISON (ins_itc -> itc_ltrx);
      sqlr_new_error ("42000", "SR249", "Ruling part too long on %s.", key->key_name);
    }
  itc_from (ins_itc, key);
  ins_itc->itc_key_spec = key->key_insert_spec;
  ins_itc->itc_no_bitmap = 1;
  itc_insert_row_params (ins_itc, key_image);
  if (key->key_is_bitmap)
    {
      ITC_SAVE_FAIL (ins_itc);
      key_bm_insert (ins_itc, key_image);
      ITC_RESTORE_FAIL (ins_itc);
    }
  else
    itc_insert_unq_ck (ins_itc, &key_image[0], NULL);
}
#undef key_image

void
upd_refit_row (it_cursor_t * itc, buffer_desc_t ** buf,
	       dtp_t * new_image)
{
  row_lock_t * rl = NULL;
  int bytes_left;
  int ol, nl;
  db_buf_t page;
  key_id_t key_id = SHORT_REF (new_image + IE_KEY_ID);
  int is_leaf_ptr = (!key_id || KI_LEFT_DUMMY == key_id);
  dbe_key_t * new_key = is_leaf_ptr ? itc->itc_insert_key : sch_id_to_key (wi_inst.wi_schema, key_id);
  if (!(*buf)->bd_is_write)
    GPF_T1 ("update w/o write access");
  pg_check_map (*buf);
  if (BUF_NEEDS_DELTA (*buf))
    {
      ITC_IN_KNOWN_MAP (itc, itc->itc_page);
      itc_delta_this_buffer (itc, *buf, DELTA_MAY_LEAVE);
      ITC_LEAVE_MAP_NC (itc);
    }
  if (ITC_IS_LTRX (itc) && !is_leaf_ptr)
    {
      if ((*buf)->bd_page != itc->itc_page)
	GPF_T1 ("inconsistent bd_page and itc_page in upd_refit_row");
      if (itc->itc_pl)
	{
	  if (itc->itc_page != itc->itc_pl->pl_page)
	    GPF_T1 ("inconsistent itc_page and pl_page in refit row");
	}
      else
	GPF_T1 ("replacing a row without lock.  It is possible that delete flag is left on in a row even though the deleteing transaction commetted");
    }
  page = (*buf)->bd_buffer;
  ol = row_reserved_length (page + itc->itc_position, itc->itc_row_key);
  nl = row_length (new_image, new_key);
  if (!is_leaf_ptr && !itc->itc_ltrx->lt_is_excl)
    {
      lt_rb_update (itc->itc_ltrx, page + itc->itc_position);
    }
  bytes_left = ROW_ALIGN (ol) - ROW_ALIGN (nl);
  /* excl mode txn will always do delete+insert because it does not rely on commit to complete the op.  Leaf pointers are done inside commit so these are also ins+del.  */
  if (bytes_left >= 0 && (!itc->itc_ltrx || !itc->itc_ltrx->lt_is_excl) && !is_leaf_ptr)
    {
      int pos = itc->itc_position;
      int old_next = IE_NEXT (&page[pos + IE_NEXT_IE]);
      memcpy (page + pos, new_image, nl);
      if (bytes_left)
	{
	  /* bytes free increased only at commit, mark lock and row for this */
	  if (ITC_IS_LTRX (itc))
	    pl_set_finalize (itc->itc_pl, *buf);
	  IE_ADD_FLAGS (page + pos, IEF_UPDATE);
	  row_write_reserved (page + pos + nl, ROW_ALIGN (ol) - nl);
	}
      IE_SET_NEXT (&page[pos], old_next);
      pg_check_map (*buf);
      if (new_key->key_is_bitmap)
	{
	  itc_invalidate_bm_crs (itc, *buf, 0, NULL);
	}
      itc_page_leave (itc, *buf);
    }
  else
    {
      int prev_pos, insert_pos;
      int pos = itc->itc_position;
      if ((*buf)->bd_content_map->pm_bytes_free >= nl - ol && !is_leaf_ptr)
	{
	  /* if the page will not split, there could be space enough between this row and the start of the physically next one. */ 
	  int after = map_entry_after ((*buf)->bd_content_map, pos);
	  int old_next = IE_NEXT (&page[pos + IE_NEXT_IE]);
	  if (after - pos >= nl)
	    {
	      memcpy (page + pos, new_image, nl);
	      IE_SET_NEXT (&page[pos], old_next);
	      (*buf)->bd_content_map->pm_bytes_free -= ROW_ALIGN (nl) - ROW_ALIGN (ol);
	      if (PAGE_SZ == after)
		(*buf)->bd_content_map->pm_filled_to = pos + ROW_ALIGN (nl);
	      pg_check_map (*buf);
	      if (new_key->key_is_bitmap)
		{
		  itc_invalidate_bm_crs (itc, *buf, 0, NULL);
		}
	      itc_page_leave (itc, *buf);
	      return;
	    }
	}
      prev_pos = map_delete (&(*buf)->bd_content_map, pos);
      insert_pos = IE_NEXT (page + pos);
      if (prev_pos)
	{
	  IE_SET_NEXT (page + prev_pos, insert_pos);
	}
      else
	{
	  SHORT_SET (page + DP_FIRST, insert_pos);
	}

      itc->itc_keep_together_dp = itc->itc_page;
      itc->itc_keep_together_pos = pos;

      (*buf)->bd_content_map->pm_bytes_free += ROW_ALIGN (ol);

      itc->itc_position = insert_pos;
      if (!is_leaf_ptr && ITC_IS_LTRX (itc))
	{
	  rl = upd_refit_rlock (itc, pos);
	  if  (!rl && !PL_IS_PAGE (itc->itc_pl))
	    GPF_T1 ("update w/ no row lock on non locked page");
	}
      itc->itc_insert_key = new_key;
      itc->itc_row_key = new_key;
      itc->itc_row_key_id = new_key ? new_key->key_id : 0;
      pg_check_map (*buf);
      itc_insert_dv (itc, buf, new_image, is_leaf_ptr, rl);
      /* the recursive flag is is_leaf_ptr. This is set when changes leaf ptrs inside transact. Means the call will not bust and assumes the reserve is already held.  */
      ITC_LEAVE_MAPS (itc);
    }
}


long upd_quick_ctr = 0;

int
update_quick (update_node_t * upd, caddr_t * qst, it_cursor_t * cr_itc, buffer_desc_t * cr_buf,
	      db_buf_t image, caddr_t * err_ret)
{
  int inx;
  if (BUF_NEEDS_DELTA (cr_buf))
    {
      ITC_FAIL (cr_itc)
	{
	  ITC_IN_KNOWN_MAP (cr_itc, cr_buf->bd_page);
	  itc_delta_this_buffer (cr_itc, cr_buf, DELTA_MAY_LEAVE);
	  ITC_LEAVE_MAP_NC (cr_itc);
	}
      ITC_FAILED
	{
	  itc_free (cr_itc);
	}
      END_FAIL (cr_itc);
    }
  lt_rb_update (cr_itc->itc_ltrx, cr_buf->bd_buffer + cr_itc->itc_position);

  DO_BOX (dbe_col_loc_t *, cl, inx, upd->upd_fixed_cl)
    {
      caddr_t data = QST_GET (qst, upd->upd_values[inx]);
      row_set_col (cr_buf->bd_buffer + cr_itc->itc_position + IE_FIRST_KEY, cl, data,
		   NULL, 0, upd->upd_table->tb_primary_key,
		   err_ret, NULL, NULL, qst);
      if (*err_ret)
	{
	  /* XXX: test case !!!! */
	  itc_page_leave (cr_itc, cr_buf);
	  return 1;
	}
    }
  END_DO_BOX;
  log_update (cr_itc->itc_ltrx, cr_itc, cr_buf->bd_buffer, upd, qst);
  itc_page_leave (cr_itc, cr_buf);
  return 1;
}

void
update_node_run_1 (update_node_t * upd, caddr_t * inst, caddr_t * state)
{
  int any_blob = 0, main_pos_in_image = 0;
  caddr_t row_err = NULL;
  dk_set_t keys;
  dtp_t image[PAGE_SZ];
  dtp_t new_image[PAGE_SZ];
  key_id_t new_key;

  int res;
  placeholder_t *pl = (placeholder_t *) qst_place_get (state, upd->upd_place);
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (state);
  if (!pl)
    sqlr_new_error ("24000", "SR250", "Cursor not positioned on update. %s",
		upd->upd_place->ssl_name);
  {
    buffer_desc_t * volatile cr_buf = NULL;
    buffer_desc_t *main_buf, *del_buf;
    it_cursor_t cr_itc_auto;
    it_cursor_t main_itc_auto;
    it_cursor_t del_itc_auto;
    it_cursor_t *cr_itc = &cr_itc_auto;
    it_cursor_t * volatile main_itc = NULL;
    it_cursor_t * volatile del_itc = NULL;

    dbe_key_t * volatile cr_key = NULL;
    dbe_table_t * volatile tb = NULL, *new_tb;
    ITC_INIT (cr_itc, qi->qi_space, qi->qi_trx);

    ITC_FAIL (cr_itc)
    {
      cr_buf = itc_set_by_placeholder (cr_itc, pl);
      cr_itc->itc_lock_mode = PL_EXCLUSIVE;
      if (!cr_itc->itc_is_on_row)
	{
	  rdbg_printf (("Row to update deld before update T=%d L=%d pos=%d\n",
			TRX_NO (cr_itc->itc_ltrx), cr_itc->itc_page, cr_itc->itc_position));

	  itc_page_leave (cr_itc, cr_buf);
	  itc_free (cr_itc);
	  sqlr_new_error ("24000", "SR251", "Cursor not on row in positioned UPDATE");
	}
      /* allways true */
#if 0
      if (pl->itc_owns_page != cr_itc->itc_page || pl->itc_lock_mode != PL_EXCLUSIVE)
#endif
	{
	  cr_itc->itc_insert_key = pl->itc_tree->it_key; /* for debug info */
	  itc_set_lock_on_row (cr_itc, (buffer_desc_t **)&cr_buf);
	  if (!cr_itc->itc_is_on_row)
	  {
	    rdbg_printf (("Row to update deld during update lock  T=%d L=%d pos=%d\n",
			  TRX_NO (cr_itc->itc_ltrx), cr_itc->itc_page, cr_itc->itc_position));
	    itc_page_leave (cr_itc, cr_buf);
	    sqlr_new_error ("01001", "SR252", "Row deleted while waiting to update");
	  }
	}
      cr_key = itc_get_row_key (cr_itc, cr_buf);
      if (cr_key->key_id == upd->upd_exact_key
	  && upd->upd_fixed_cl
	  && !qi->qi_trx->lt_is_excl)
	{
	  cr_itc->itc_insert_key = cr_key;
	  cr_itc->itc_row_key = cr_key;
	  cr_itc->itc_row_key_id = cr_key ? cr_key->key_id : 0;
	  upd_hi_pre (upd, qi);
	  res = update_quick (upd, state, cr_itc, cr_buf, image, &row_err);
	  if (res)
	    {
	      if (row_err)
		sqlr_resignal (row_err);
	      QI_ROW_AFFECTED (inst);
	      return;
	    }
	  if (row_err)
	    {
	      itc_page_leave (cr_itc, cr_buf);
	      sqlr_resignal (row_err);
	    }
	}
      tb = cr_key->key_table;
      cr_itc->itc_row_key = cr_key;
      cr_itc->itc_row_key_id = cr_key ? cr_key->key_id : 0;
      itc_copy_row (cr_itc, cr_buf, image);
      if (!cr_key->key_is_primary)
	itc_page_leave (cr_itc, cr_buf);	/* do this inside the ITC_FAIL */

    }
    ITC_FAILED
    {
      itc_free (cr_itc);
    }
    END_FAIL (cr_itc);

    if (!cr_key->key_is_primary)
      {
	main_itc = &main_itc_auto;
	ITC_INIT (main_itc, QI_SPACE (inst), QI_TRX (inst));
	main_itc->itc_lock_mode = PL_EXCLUSIVE;

	ITC_LEAVE_MAPS (cr_itc);
	ITC_FAIL (main_itc)
	{
	  res = itc_get_alt_key (cr_itc, main_itc, NULL, &main_buf,
				 tb->tb_primary_key, image);
	  if (res == DVC_MATCH)
	    {
	      itc_copy_row (main_itc, main_buf, image);
	      main_pos_in_image = main_itc->itc_position;
	    }
	  else
	    {
	      itc_page_leave (main_itc, main_buf);
	      sqlr_new_error ("42S12", "SR253", "Could not find primary key on update.");
	    }
	}
	ITC_FAILED
	{
	  itc_free (main_itc);
	  itc_free (cr_itc);
	}
	END_FAIL (main_itc);
	itc_free (cr_itc);
      }
    else
      {
	main_itc = cr_itc;
	main_buf = cr_buf;
	main_pos_in_image = main_itc->itc_position;
      }

    cr_key = itc_get_row_key (main_itc, main_buf);
    main_itc->itc_insert_key = cr_key;
    main_itc->itc_row_key = cr_key;
    main_itc->itc_row_key_id = cr_key ? cr_key->key_id : 0;
    new_tb = tb = cr_key->key_table;

    if ((new_key = tb->tb_primary_key->key_migrate_to))
      {
	dbe_key_t *new_prim = sch_id_to_key (isp_schema (NULL), new_key);
	if (new_prim)
	  new_tb = new_prim->key_table;
      }
    QI_ROW_AFFECTED (inst);
    upd_hi_pre (upd, qi);
 /* The following ITC_LEAVE_MAP (main_itc) is added to avoid deadlock on
 update MYTABLE set LONG_XML_COL = LONG_VARCHAR_XML_COL;
 because conversion may read blob by blob_to_string() and its itc will enter map.
  */
    ITC_LEAVE_MAPS (main_itc);
#ifdef MTX_DEBUG
  if (main_buf->bd_writer != THREAD_CURRENT_THREAD)
    GPF_T1 ("Must have write on buffer to check it");
#endif

  /* blob ops in recompose row will use the itc to enter blobs and lose the pl.  Safe to save like this since the main_buf is never left in the process */
  mtx_assert (main_itc->itc_pl == main_buf->bd_pl);
    keys = upd_recompose_row (state, upd, tb, new_tb, new_image, &image[main_itc->itc_position + IE_FIRST_KEY],
			      main_itc, &row_err, &any_blob, cr_key);
  main_itc->itc_pl =main_buf->bd_pl;
    if (row_err)
      {
	itc_page_leave (main_itc, main_buf);
	if (keys && keys != BLOB_ERROR && keys != ALL_KEYS)
	  dk_set_free (keys);
	if (any_blob)
	  /* the txn can't commit because of half logged blob stuff that did not get completed */
	  TRX_POISON (qi->qi_trx);
	itc_free (main_itc);
	sqlr_resignal (row_err);
      }
    ITC_FAIL (main_itc)
    {
      dbe_key_t *row_key_saved;
      key_id_t row_key_id_saved;
      if (keys == BLOB_ERROR)
	{
	  itc_bust_this_trx (main_itc, &main_buf, ITC_BUST_THROW);	/* jumps into main_itc's fail ctr below */
	}

      row_key_saved = main_itc->itc_row_key;
      row_key_id_saved = main_itc->itc_row_key_id;
      main_itc->itc_row_key = cr_key;
      main_itc->itc_row_key_id = cr_key ? cr_key->key_id : 0;
      log_update (main_itc->itc_ltrx, main_itc, image, upd, state);
      main_itc->itc_row_key = row_key_saved;
      main_itc->itc_row_key_id = row_key_id_saved;
      if (keys == ALL_KEYS)
	{

	  itc_delete_this (main_itc, &main_buf, DVC_MATCH, NO_BLOBS);	/* blobs handled separately */

	  keys = tb->tb_keys;
	  itc_row_insert_1 (main_itc, &new_image[0], NULL, 1, 1);
	}
      else
	{
	  main_itc->itc_row_key_id = SHORT_REF (&image[main_pos_in_image + IE_KEY_ID]);
	  if (KI_TEMP == (ptrlong) main_itc->itc_row_key)
	    main_itc->itc_row_key = upd->upd_table->tb_primary_key;
	  else
	    main_itc->itc_row_key = sch_id_to_key (wi_inst.wi_schema, main_itc->itc_row_key_id);
	  upd_refit_row (main_itc, &main_buf, &new_image[0]);

	}
    }
    ITC_FAILED
    {
      itc_free (main_itc);
    }
    END_FAIL (main_itc);

    if (keys)
      {
	main_itc->itc_position = main_pos_in_image;
	main_itc->itc_row_key_id = SHORT_REF (&image[main_pos_in_image + IE_KEY_ID]);
	if (KI_TEMP == (ptrlong) main_itc->itc_row_key)
	  main_itc->itc_row_key = upd->upd_table->tb_primary_key;
	else
	  main_itc->itc_row_key = sch_id_to_key (wi_inst.wi_schema, main_itc->itc_row_key_id);
	del_itc = &del_itc_auto;
	ITC_INIT (del_itc, qi->qi_space, qi->qi_trx);
	del_itc->itc_lock_mode = PL_EXCLUSIVE;

	ITC_FAIL (del_itc)
	{
	  DO_SET (dbe_key_t *, key, &keys)
	  {
	    if (key == tb->tb_primary_key)
	      goto next_key;
	    res = itc_get_alt_key (main_itc, del_itc, main_buf, &del_buf,
				   key, image);
	    itc_delete_this (del_itc, &del_buf, res, NO_BLOBS);
	    upd_insert_2nd_key (key, del_itc,
				new_tb->tb_primary_key, &new_image[IE_FIRST_KEY]);
	  next_key:;
	  }
	  END_DO_SET ();
	}
	ITC_FAILED
	{
	  itc_free (main_itc);
	  itc_free (del_itc);
	  if (keys != tb->tb_keys)
	    dk_set_free (keys);
	}
	END_FAIL (del_itc);
	if (keys != tb->tb_keys)
	  dk_set_free (keys);
        itc_free (del_itc);
      }
    itc_free (main_itc);
  }
}

static void 
update_keyset_state_set (update_node_t * upd, caddr_t * state)
{
  id_hash_t * sht, * vht;
  caddr_t * upd_state;
  long pos, last;
  caddr_t v, n_box;
  int inx, cnt;
  state_slot_t ** sa[2], **slots;

  /* save update node state */
  /*fprintf (stderr, "update_keyset_state_set\n");*/

  upd_state = (caddr_t *)qst_get (state, upd->upd_keyset_state);
  if (!upd_state)
    {
      upd_state = (caddr_t *) dk_alloc_box_zero (3 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      upd_state[2] = (caddr_t) box_dv_dict_hashtable (1024);
      qst_set (state, upd->upd_keyset_state, (caddr_t) upd_state);
    }
 
  pos = unbox (upd_state[0]);
  last = unbox (upd_state[1]);
  sht = (id_hash_t *) upd_state[2]; 
  if (!sht)
    GPF_T;

  /* will keep upd_place, upd_values, upd_trigger_args */
  vht = (id_hash_t *) box_dv_dict_hashtable (31);

  v = qst_get (state, upd->upd_place);
  n_box = box_num ((ptrlong)upd->upd_place->ssl_index);
  id_hash_set (vht, (caddr_t)&n_box, (caddr_t)&v); 
  QST_GET_V (state, upd->upd_place) = NULL;

  sa[0] = upd->upd_values;
  sa[1] = upd->upd_trigger_args;
  
  for (cnt = 0; cnt < 2; cnt++)
    { 
      slots = sa[cnt];
      DO_BOX (state_slot_t *, sl, inx, slots)
	{
	  /*fprintf (stderr, "%02d idx=%d type=%d name=[%s]\n", cnt, sl->ssl_index, sl->ssl_type, sl->ssl_name);*/
	  n_box = box_num ((ptrlong) sl->ssl_index);
	  if (id_hash_get (vht, (caddr_t)&n_box) || sl->ssl_type >= SSL_CONSTANT)
	    {
	      dk_free_box (n_box);
	      continue;
	    }
	  if (SSL_VARIABLE == sl->ssl_type || SSL_PARAMETER == sl->ssl_type)
	    v = box_copy_tree (qst_get (state, sl));
	  else
	    {
	      v = qst_get (state, sl);
	      QST_GET_V (state, sl) = NULL;
	    }
	  id_hash_set (vht, (caddr_t)&n_box, (caddr_t)&v); 
	}
      END_DO_BOX;
    }
  last = ++pos;
  n_box = box_num ((ptrlong) pos);
  id_hash_set (sht, (caddr_t)&n_box, (caddr_t)&vht);
  dk_free_box (upd_state[0]);
  dk_free_box (upd_state[1]);
  upd_state[0] = box_num (pos);
  upd_state[1] = box_num (last);
}


static int 
update_keyset_state_restore (update_node_t * upd, caddr_t * state, int * start)
{
#define UPD_SET_FROM_HT(sl) \
    do { \
      n_box = box_num ((ptrlong)(sl)->ssl_index); \
      place = (caddr_t *) id_hash_get (vht, (caddr_t)&n_box); \
      if (place) { \
      k = place[-1]; \
      v = *place; \
      id_hash_remove (vht, (caddr_t)&n_box); \
      dk_free_box (k); \
      qst_set (state, sl, v); \
      } \
      dk_free_box (n_box); \
    } while (0)

  id_hash_t * sht, *vht;
  caddr_t v, *place, k;
  int inx, cnt;
  state_slot_t ** sa[2], **slots;
  caddr_t * upd_state, n_box;
  long pos, last;

  upd_state = (caddr_t *)qst_get (state, upd->upd_keyset_state);
  if (!upd_state)
    GPF_T;
  pos = unbox (upd_state[0]);
  last = unbox (upd_state[1]);
  if (*start) /* first call of restore */
    {
      *start = 0;
      pos = 0;
    }
  sht = (id_hash_t *) upd_state[2]; 
  if (!sht)
    GPF_T;
  pos++;
  if (pos > last) 
    {
      /* finished */
      dk_free_box (upd_state[0]);
      dk_free_box (upd_state[1]);
      upd_state[0] = box_num (0);
      upd_state[1] = box_num (0);
      dk_free_box (QST_GET_V (state, upd->upd_place));
      QST_GET_V (state, upd->upd_place) = NULL;
      return 0;
    }

  n_box = box_num ((ptrlong) pos);
  place = (caddr_t *) id_hash_get (sht, (caddr_t)&n_box);
  if (!place)
    GPF_T;

  vht = (id_hash_t *)(*place);
  k = place[-1];
  id_hash_remove (sht, (caddr_t)&n_box);
  dk_free_box (k);
  dk_free_box (n_box);

  /* restore update node state */
  UPD_SET_FROM_HT (upd->upd_place);

  sa[0] = upd->upd_values;
  sa[1] = upd->upd_trigger_args;
  
  for (cnt = 0; cnt < 2; cnt++)
    { 
      slots = sa[cnt];
      DO_BOX (state_slot_t *, sl, inx, slots)
	{
	  if (sl->ssl_type >= SSL_CONSTANT)
	    continue;
	  UPD_SET_FROM_HT (sl);
	}
      END_DO_BOX;
    }
  dk_free_box (vht);
  dk_free_box (upd_state[0]);
  upd_state[0] = box_num (pos);
  return 1;
}


/*
   update_node_run
   If the  upd_keyset is set and both inst and state are
   given, will remember the values in the ssls upd_place, upd_values,
   upd_trigger_args.  The placeholder is taken from the ssl and the ssl is set to
   null withouot free. QST_GET_V () = NULL.

   If the node remembers states, do SRC_IN_STATE (upd, inst) = inst to mark
   this.  This means the will be continued later.  Means the update is done
   then.

   When update_node_run is called for continue, ie inst is set and state is
   null, do the updates.  Loop over the remembered things, put them in the
   appropriate ssl and call the rest of update node run.  Do not copy the 
   remembered values, just set them with qst_set.  This frees the previous value.
*/

void 
update_node_run (update_node_t * upd, caddr_t * inst, caddr_t * state)
{
  if (upd->upd_keyset)
    {
      if (state)
	{
	  update_keyset_state_set (upd, state);
	  SRC_IN_STATE ((data_source_t *)upd, inst) = inst;
	  return;
        }
      else
	{
	  int start = 1;
	  state = inst;
	  SRC_IN_STATE ((data_source_t *)upd, inst) = NULL;
	  while (update_keyset_state_restore (upd, state, &start))
	    {
	      /* call update_node_run_1 for each state */
	      if (!upd->upd_trigger_args)
		{
		  update_node_run_1 (upd, inst, state);
		  ROW_AUTOCOMMIT (inst);
		}
	      else
		trig_wrapper (inst, upd->upd_trigger_args, upd->upd_table,
		    TRIG_UPDATE, (data_source_t *) upd, (qn_input_fn) update_node_run_1);
	    }
	  return;
	}
    }
  update_node_run_1 (upd, inst, state);
  ROW_AUTOCOMMIT (inst);
}


void
update_node_input (update_node_t * upd, caddr_t * inst, caddr_t * state)
{
  query_instance_t * qi = (query_instance_t *) inst;
  LT_CHECK_RW (((query_instance_t *) inst)->qi_trx);
  QI_CHECK_STACK (qi, &qi, UPD_STACK_MARGIN);

  if (upd->upd_policy_qr)
    trig_call (upd->upd_policy_qr, inst, upd->upd_trigger_args, upd->upd_table);

  if (!upd->upd_trigger_args || upd->upd_keyset)
    {
      update_node_run (upd, inst, state);
    }
  else
    {
      trig_wrapper (inst, upd->upd_trigger_args, upd->upd_table,
	  TRIG_UPDATE, (data_source_t *) upd, (qn_input_fn) update_node_run);
    }
  qn_send_output ((data_source_t *) upd, state);
}


placeholder_t *
qst_place_get (caddr_t * state, state_slot_t * ssl)
{
  /* the slot is either a SSL_CURSOR with a local_cursor_t or a SSL_PLACEHOLDER with a place. */
  if (ssl->ssl_type == SSL_CURSOR)
    {
      local_cursor_t *lc = (local_cursor_t *) QST_GET_V (state, ssl);


      caddr_t *cr_out_box, *cr_state;
      query_t *cr_query;
      placeholder_t *cr_place = NULL;
      query_instance_t *cr_qi = (query_instance_t *) lc->lc_inst;
      int cr_current_of, cr_out_fill;
      caddr_t *cr_inst;

      cr_inst = (caddr_t *) cr_qi;
      cr_query = cr_qi->qi_query;
      if (!cr_query->qr_select_node)
	sqlr_new_error ("42000", "SR254", "The cursor specified is not a SELECT.");
      cr_current_of = lc->lc_position;
      cr_out_fill = (int) (ptrlong) cr_inst[cr_query->qr_select_node->sel_out_fill];

      cr_out_box = (caddr_t *) cr_inst[cr_query->qr_select_node->sel_out_box];
      if (cr_current_of < 0 || cr_current_of >= cr_out_fill)
	sqlr_new_error ("24000", "SR255", "Cursor before first or after end. No current row.");
      cr_state = (caddr_t *) cr_out_box[cr_current_of];

      DO_SET (state_slot_t *, sl, &cr_query->qr_state_map)
      {
	if (sl->ssl_type == SSL_PLACEHOLDER)
	  {
	    cr_place = (placeholder_t *) (QST_GET (cr_state, sl));
	    break;
	  }
      }
      END_DO_SET ();
      if (!cr_place)
	sqlr_new_error ("HY109", "SR256", "Cursor does not have place.");
      return cr_place;
    }
  else
    return ((placeholder_t *) qst_get (state, ssl));
}


void
current_of_node_input (current_of_node_t * co, caddr_t * inst,
		       caddr_t * state)
{
  int inx;
  query_instance_t *qi = (query_instance_t *) inst;
  caddr_t *cr_out_box, *cr_state;
  query_t *cr_query;
  placeholder_t *cr_place = NULL, *place_copy;
  query_instance_t *cr_qi;
  int cr_current_of, cr_out_fill;
  caddr_t place;
  caddr_t *cr_inst;
  char *cr_name = qst_get (state, co->co_cursor_name);
  client_connection_t *cli = qi->qi_client;

  if (current_of_node_scrollable (co,qi, cr_name))
    return;
  mutex_enter (cli->cli_mtx);
  place = id_hash_get (cli->cli_cursors, (char *) &cr_name);
  mutex_leave (cli->cli_mtx);

  if (!place)
    sqlr_new_error ("34000", "SR257", "No cursor named %s.", cr_name);
  cr_qi = *(query_instance_t **) place;
  cr_inst = (caddr_t *) cr_qi;
  cr_query = cr_qi->qi_query;
  if (!cr_query->qr_select_node)
    sqlr_new_error ("42000", "SR258", "The cursor specified is not a SELECT.");
  cr_current_of = (int) (ptrlong) cr_inst[cr_query->qr_select_node->sel_current_of];
  cr_out_fill = (int) (ptrlong) cr_inst[cr_query->qr_select_node->sel_out_fill];

  cr_out_box = (caddr_t *) cr_inst[cr_query->qr_select_node->sel_out_box];
  if (cr_current_of < 0 || cr_current_of >= cr_out_fill)
    sqlr_new_error ("24000", "SR259", "Cursor %s before first or after end. No current row.",
		cr_name);
  cr_state = (caddr_t *) cr_out_box[cr_current_of];


  DO_BOX (state_slot_t *, sl, inx, cr_query->qr_select_node->sel_out_slots)
  {
    if (sl->ssl_type == SSL_PLACEHOLDER
	|| sl->ssl_type == SSL_ITC)
      {
	if (!co->co_cursor_place_name
	    || (sl->ssl_name
		&& 0 == strcmp (co->co_cursor_place_name, sl->ssl_name)))
	  {
	    cr_place = (placeholder_t *) (sel_out_get (cr_state, inx, sl));
	    break;
	  }
      }
  }
  END_DO_BOX;
  if (!cr_place)
    sqlr_new_error ("HY109", "SR260", "Cursor %s does not have place %s.",
		cr_name, co->co_cursor_place_name);
  place_copy = plh_copy (cr_place);
  qst_set (state, co->co_place, (caddr_t) place_copy);

  qn_send_output ((data_source_t *) co, state);
}


void
row_insert_node_input (row_insert_node_t * ins, caddr_t * inst,
		       caddr_t * state)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (state);
  db_buf_t row = (db_buf_t) qst_get (state, ins->rins_row);
  buffer_desc_t *buf = NULL;
  it_cursor_t *it;
  dbe_key_t * key;

  LT_CHECK_RW (qi->qi_trx);
  it = itc_create (NULL, qi->qi_trx);

  key = sch_id_to_key (wi_inst.wi_schema, SHORT_REF (row + IE_KEY_ID));
  ITC_FAIL (it)
  {
    if (DVC_MATCH == itc_row_insert (it, row, &buf))
      {
	switch (ins->rins_mode)
	  {
	  case INS_NORMAL:
	    itc_page_leave (it, buf);
	    itc_free (it);
	    sqlr_new_error ("23000", "SR261", "Non unique primary key.");
	  case INS_SOFT:
	    itc_page_leave (it, buf);
	    break;
	  case INS_REPLACING:
	    {
	      dbe_key_t *key =
	      sch_id_to_key (isp_schema (NULL),
		   (key_id_t) SHORT_REF (row + IE_KEY_ID));
	      itc_replace_row (it, buf, row, key, state);
	      log_insert (it->itc_ltrx, key, row, ins->rins_mode);
	    }
	  }
      }
    else
      {
	QI_ROW_AFFECTED (inst);
	log_insert (it->itc_ltrx, key, row, ins->rins_mode);
      }
  }
  ITC_FAILED
  {
    itc_free (it);
  }
  END_FAIL (it);
  itc_free (it);
  qn_send_output ((data_source_t *) ins, state);
}


void
key_insert_node_input (key_insert_node_t * ins, caddr_t * inst,
		       caddr_t * state)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (state);
  db_buf_t row = (db_buf_t) qst_get (state, ins->kins_row);
  it_cursor_t *it = itc_create (NULL, qi->qi_trx);

  ITC_FAIL (it)
  {
    itc_row_key_insert (it, row, ins->kins_key);
  }
  ITC_FAILED
  {
    itc_free (it);
  }
  END_FAIL (it);
  itc_free (it);
  qn_send_output ((data_source_t *) ins, state);
}





/* called when itc_insert_unq_ck finds existing row.
   The main_itc is inside the page on PA_READ and the lock is not set.
 */

int
itc_replace_row (it_cursor_t * main_itc, buffer_desc_t * main_buf, db_buf_t new_image,
		 dbe_key_t * new_key, caddr_t * state)
{
  int res;
  dtp_t image[PAGE_SZ];
  dbe_key_t *old_key = itc_get_row_key (main_itc, main_buf);

  itc_set_lock_on_row (main_itc, &main_buf);
  if (!main_itc->itc_is_on_row)
    return REPLACE_RETRY;

  itc_copy_row (main_itc, main_buf, image);
  ITC_LEAVE_MAPS (main_itc);
  {
    buffer_desc_t *del_buf;
    dbe_table_t *tb = old_key->key_table;
    it_cursor_t *del_itc;
    short save_pos = main_itc->itc_position;

    itc_delete (main_itc, &main_buf, MAYBE_BLOBS);
    itc_page_leave (main_itc, main_buf);
    main_itc->itc_position = save_pos;
    del_itc = itc_create (NULL
, main_itc->itc_ltrx);
    del_itc->itc_lock_mode = PL_EXCLUSIVE;
    ITC_FAIL (del_itc)
      {
	DO_SET (dbe_key_t *, key, &tb->tb_keys)
	  {
	    if (key->key_is_primary)
	      goto next_key;
	    res = itc_get_alt_key (main_itc, del_itc, main_buf, &del_buf,
				   key, image);
	    itc_delete_this (del_itc, &del_buf, res, NO_BLOBS);
	  next_key:;
	  }
	END_DO_SET ();
	itc_row_insert_1 (del_itc, new_image, UNQ_ALLOW_DUPLICATES, 1, 0);
      }
    ITC_FAILED
      {
	itc_free (main_itc);
	itc_free (del_itc);
      }
    END_FAIL (del_itc);
    itc_free (del_itc);
  }
  return REPLACE_OK;
}


void
pl_source_run (pl_source_t * pls, caddr_t * inst, caddr_t * state)
{
  volatile int inx = 0;
  dtp_t image[PAGE_SZ];
  int res;
  placeholder_t * volatile pl = (placeholder_t *) qst_place_get (state, pls->pls_place);
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (state);

start:
  if (!pl)
    sqlr_new_error ("24000", "SR262", "Cursor not positioned on positioned reference. %s",
	pls->pls_place->ssl_name);
  {
    buffer_desc_t *volatile cr_buf = NULL;
    buffer_desc_t *main_buf;
    it_cursor_t cr_itc_auto;
    it_cursor_t main_itc_auto;
    it_cursor_t *cr_itc = &cr_itc_auto;
    it_cursor_t *volatile main_itc = NULL;
    dbe_key_t *volatile cr_key = NULL;
    dbe_table_t *volatile tb = NULL;
    ITC_INIT (cr_itc, qi->qi_space, qi->qi_trx);

    ITC_FAIL (cr_itc)
    {
      cr_buf = itc_set_by_placeholder (cr_itc, pl);
      cr_itc->itc_lock_mode = PL_EXCLUSIVE;
      if (!cr_itc->itc_is_on_row)
	{
	  itc_page_leave (cr_itc, cr_buf);
	  itc_free (cr_itc);
	  sqlr_new_error ("24000", "SR263", "Cursor not on row in positioned UPDATE");
	}
      if (pl->itc_owns_page != cr_itc->itc_page ||
	  pl->itc_lock_mode != PL_EXCLUSIVE)
	{
	  itc_set_lock_on_row (cr_itc, (buffer_desc_t **)&cr_buf);
	  if (!cr_itc->itc_is_on_row)
	    {
	      itc_free (cr_itc);
	      goto start;
	    }
	}
      cr_key = itc_get_row_key (cr_itc, cr_buf);


      tb = cr_key->key_table;
      cr_itc->itc_row_key = cr_key;
      if (cr_key)
	cr_itc->itc_row_key_id = cr_key->key_id;
      itc_copy_row (cr_itc, cr_buf, image);
      if (!cr_key->key_is_primary)
	itc_page_leave (cr_itc, cr_buf); /* do this inside the ITC_FAIL */
    }
    ITC_FAILED
    {
      itc_free (cr_itc);
    }
    END_FAIL (cr_itc);

    if (!cr_key->key_is_primary)
      {
	main_itc = &main_itc_auto;
	ITC_INIT (main_itc, QI_SPACE (inst), QI_TRX (inst));
	main_itc->itc_lock_mode = PL_EXCLUSIVE;

	ITC_LEAVE_MAPS (cr_itc);
	ITC_FAIL (main_itc)
	{
	  res = itc_get_alt_key (cr_itc, main_itc, NULL, &main_buf,
	      tb->tb_primary_key, image);
	  if (res == DVC_MATCH)
	    {
	      itc_copy_row (main_itc, main_buf, image);
	    }
	  else
	    {
	      itc_page_leave (main_itc, main_buf);
	      sqlr_new_error ("42S12", "SR264", "Could not find primary key on update.");
	    }
	  itc_free (cr_itc);
	}
	ITC_FAILED
	{
	  itc_free (main_itc);
	  itc_free (cr_itc);
	}
	END_FAIL (main_itc);
      }
    else
      {
	main_itc = cr_itc;
	main_buf = cr_buf;
      }

    cr_key = itc_get_row_key (main_itc, main_buf);
    main_itc->itc_insert_key = cr_key;
    main_itc->itc_row_key = cr_key;
    main_itc->itc_row_key_id = cr_key->key_id;
    main_itc->itc_row_data = main_buf->bd_buffer + main_itc->itc_position + IE_FIRST_KEY;
    tb = cr_key->key_table;

    DO_SET (dbe_column_t *, col, &pls->pls_table->tb_primary_key->key_parts)
    {
      qst_set (inst, pls->pls_values[inx],
	  itc_box_column (main_itc, main_buf->bd_buffer, col->col_id, NULL));
      inx++;
    }
    END_DO_SET ();
    itc_page_leave (main_itc, main_buf);
    itc_free (main_itc);
  }
}


void
pl_source_input (pl_source_t * pls, caddr_t * inst, caddr_t * state)
{
  pl_source_run (pls, inst, state);
  qn_send_output ((data_source_t *) pls, state);
}



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
 *  Copyright (C) 1998-2014 OpenLink Software
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


#ifndef KEYCOMP
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
#endif


dbe_col_loc_t *
key_next_list (dbe_key_t * key, dbe_col_loc_t * list)
{
  if (list == key->key_key_fixed)
    return key->key_key_var;
  if (list == key->key_key_var)
    return key->key_row_fixed;
  if (list == key->key_row_fixed)
    return key->key_row_var;
  return NULL;
}


dk_set_t
upd_recompose_row (caddr_t * state, update_node_t * upd,
		   row_delta_t * rd, row_delta_t * new_rd,
		   caddr_t * err_ret, int * any_blobs)
{
  dbe_table_t * tb = rd->rd_key->key_table;
  dtp_t dummy_blob[] ={DV_DB_NULL};
  dbe_table_t * new_tb = new_rd->rd_key->key_table;
  int nth = 0;

  dk_set_t changed_keys = NULL;
  int nth_val;
  dbe_column_t * col;

  new_rd->rd_non_comp_len = new_tb->tb_primary_key->key_row_var_start[0];
  DO_ALL_CL (cl, new_tb->tb_primary_key)
    {
      int old_found = 0;
      caddr_t old_val = rd_col (rd, cl->cl_col_id, &old_found);
      col = sch_id_to_column (wi_inst.wi_schema, cl->cl_col_id);
      nth_val = upd_col_to_update (upd, col, state, new_tb, 0);
      if (COL_NO_CHANGE == nth_val)
	{
	  new_rd->rd_values[nth] = old_found ? old_val : col->col_default;
	  if  (dtp_is_var (cl->cl_sqt.sqt_dtp))
	    new_rd->rd_non_comp_len += box_col_len (new_rd->rd_values[nth]);
	}
      else
	{
	  caddr_t new_val_of_col = upd_nth_value (upd, state, nth_val);
	  db_buf_t old_blob = (IS_BLOB_DTP (cl->cl_sqt.sqt_dtp)  && old_found && DV_DB_NULL != DV_TYPE_OF (old_val) && IS_BLOB_DTP (((db_buf_t)old_val)[0]))
	    ? (db_buf_t)old_val : dummy_blob;
	  row_insert_cast (new_rd, cl, new_val_of_col, err_ret, old_blob);
	  if (*err_ret)
	    goto col_error;
	  new_val_of_col = new_rd->rd_itc->itc_search_params[new_rd->rd_itc->itc_search_par_fill - 1];
	  if (old_found)
	    {
	      if (box_equal (new_val_of_col, old_val))
		new_rd->rd_values[nth] = old_val;
	      else
		{
		  upd_mark_change (tb, col->col_id, &changed_keys);
		  new_rd->rd_values[nth] = new_val_of_col;
		}
	    }
	  else
	    {
	      new_rd->rd_values[nth] = new_val_of_col;
	    }
	}
      nth++;
      if (nth <= new_tb->tb_primary_key->key_n_significant &&
	  (new_rd->rd_non_comp_len - new_tb->tb_primary_key->key_row_var_start[0] + new_tb->tb_primary_key->key_key_var_start[0]) >
	  MAX_RULING_PART_BYTES)
	{
	  *err_ret = srv_make_new_error ("42000", "SR437", "Ruling part too long in update");
	  if (changed_keys != ALL_KEYS && changed_keys != BLOB_ERROR)
	    dk_set_free (changed_keys);
	  return NULL;
	}
    }
  END_DO_ALL_CL;
 col_error:
  new_rd->rd_n_values = nth;
  if (*err_ret)
    {
      if (changed_keys != ALL_KEYS && changed_keys != BLOB_ERROR)
	dk_set_free (changed_keys);
      return NULL;
    }
  if (new_rd->rd_non_comp_len  > ROW_MAX_DATA * 2)
    {
      *err_ret = srv_make_new_error ("42000", "SR248", "Row too long in update");
      if (changed_keys != ALL_KEYS && changed_keys != BLOB_ERROR)
	dk_set_free (changed_keys);
      return NULL;
    }
  if (new_tb->tb_any_blobs)
    {
      upd_blob_opt ((query_instance_t*) state, new_rd, err_ret);
      if (NULL != err_ret[0])
	{
	  if (changed_keys != ALL_KEYS && changed_keys != BLOB_ERROR)
	    dk_set_free (changed_keys);
	  return NULL;
	}
    }
  else if (new_rd->rd_non_comp_len > ROW_MAX_DATA)
    {
      *err_ret = srv_make_new_error ("42000", "SR438", "Row too long in update");
      if (changed_keys != ALL_KEYS && changed_keys != BLOB_ERROR)
	dk_set_free (changed_keys);
      return NULL;
    }
  return changed_keys;
}


int
box_col_len (caddr_t box)
{
  switch (DV_TYPE_OF (box))
    {
    case DV_DB_NULL: return 0;
    case DV_STRING: return box_length (box) - 1;
    default: return box_length (box);
    }
}


void
upd_insert_2nd_key (dbe_key_t * key, it_cursor_t * ins_itc,
		    row_delta_t * main_rd)
{
  caddr_t err = NULL;
  int nth = 0, inx;
  LOCAL_RD (rd);
    rd.rd_key = key;
  DO_CL (cl, key->key_key_fixed)
    {
      rd.rd_values[nth++] = rd_col (main_rd, cl->cl_col_id, NULL);
    }
  END_DO_CL;
  rd.rd_non_comp_len = key->key_row_var_start[0];
  DO_CL (cl, key->key_key_var)
    {
      rd.rd_values[nth++] = rd_col (main_rd, cl->cl_col_id, NULL);
      rd.rd_non_comp_len += box_col_len (rd.rd_values[nth - 1]);
    }
  END_DO_CL;

  if (err || rd.rd_non_comp_len > MAX_RULING_PART_BYTES)
    {
      if (CLI_IS_ROLL_FORWARD (ins_itc->itc_ltrx->lt_client))
	return;
      TRX_POISON (ins_itc -> itc_ltrx);
      sqlr_new_error ("42000", "SR249", "Ruling part too long on %s.", key->key_name);
    }

  DO_CL (cl, key->key_row_fixed)
    {
      rd.rd_values[nth++] = rd_col (main_rd, cl->cl_col_id, NULL);
    }
  END_DO_CL;

  DO_CL (cl, key->key_row_var)
    {
      if (CI_BITMAP == cl->cl_col_id)
	continue;
      rd.rd_values[nth++] = rd_col (main_rd, cl->cl_col_id, NULL);
      rd.rd_non_comp_len += box_col_len (rd.rd_values[nth - 1]);
    }
  END_DO_CL;
  rd.rd_n_values = nth;

  /* keep the owned params cause these can be casts owned by the itc when it made pk in ins replacing.  In update node, the casts are owned by another itc */
  itc_from_keep_params (ins_itc, key);
  ins_itc->itc_search_par_fill = 0;
  for (inx = 0; inx < key->key_n_significant; inx++)
    ITC_SEARCH_PARAM (ins_itc, rd.rd_values[key->key_part_in_layout_order[inx]]);


  ins_itc->itc_key_spec = key->key_insert_spec;
  rd.rd_make_ins_rbe = 1;
  if (key->key_is_bitmap)
    {
      ITC_SAVE_FAIL (ins_itc);
      key_bm_insert (ins_itc, &rd);
      ITC_RESTORE_FAIL (ins_itc);
    }
  else
    itc_insert_unq_ck (ins_itc, &rd, NULL);
}


void
upd_refit_row (it_cursor_t * itc, buffer_desc_t ** buf,
	       row_delta_t * rd, int mode)
{
  rd->rd_map_pos = itc->itc_map_pos;
  rd->rd_itc = itc;
  rd->rd_keep_together_dp = itc->itc_page;
  rd->rd_keep_together_pos = itc->itc_map_pos;
  rd->rd_rl = upd_refit_rlock (itc, itc->itc_map_pos);
  rd->rd_op = mode;
  if (BUF_NEEDS_DELTA (*buf))
    {
      ITC_IN_KNOWN_MAP (itc, itc->itc_page);
      itc_delta_this_buffer (itc, *buf, DELTA_MAY_LEAVE);
      ITC_LEAVE_MAP_NC (itc);
    }
  page_apply (rd->rd_itc, *buf, 1, &rd, 0);
}


long upd_quick_ctr = 0;


void
upd_quick_var (update_node_t * upd, caddr_t * qst, buffer_desc_t * cr_buf,
	      row_delta_t * rd, caddr_t * err_ret)
{
  /* put the new state in the rd and call refit with local update flags */
  int inx;
  dbe_col_loc_t * change[UPD_MAX_QUICK_COLS];
  int first_var = BOX_ELEMENTS (upd->upd_fixed_cl);
  it_cursor_t * itc = rd->rd_itc;
  page_row (cr_buf, itc->itc_map_pos, rd, RO_ROW);
  memset (change, 0, rd->rd_n_values * sizeof (caddr_t));
  DO_BOX (dbe_col_loc_t *, cl, inx, upd->upd_var_cl)
    {
      caddr_t data = QST_GET (qst, upd->upd_quick_values[inx + first_var]);
      db_buf_t old_blob = NULL;
      if (IS_BLOB_DTP (cl->cl_sqt.sqt_dtp))
	GPF_T1 ("var quick update not meant for blobs");
      row_insert_cast (rd, cl, data, err_ret, old_blob);
      if (*err_ret)
	{
	  itc_page_leave (itc, cr_buf);
	  rd_free (rd);
	  itc_free (itc);
	  return;
	}
      rd_free_box (rd, rd->rd_values[cl->cl_nth]);
      rd->rd_values[cl->cl_nth] = box_copy (itc->itc_search_params[itc->itc_search_par_fill - 1]);
      change[cl->cl_nth] = cl;
    }
  END_DO_BOX;
  rd->rd_upd_change = change;
  rd->rd_op = RD_UPDATE_LOCAL;
  upd_refit_row (itc, &cr_buf, rd, RD_UPDATE_LOCAL);
  log_update (itc->itc_ltrx, rd, upd, qst);
  rd_free (rd);
  itc_free (itc);
}


void
update_quick (update_node_t * upd, caddr_t * qst, buffer_desc_t * cr_buf,
	      row_delta_t * rd, caddr_t * err_ret)
{
  it_cursor_t * cr_itc = rd->rd_itc;
  int inx;
  row_fill_t rf;
  memset (&rf, 0, sizeof (rf));
  rf.rf_key = upd->upd_table->tb_primary_key;
  rf.rf_row = BUF_ROW (cr_buf, cr_itc->itc_map_pos);
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
  lt_rb_update (cr_itc->itc_ltrx, cr_buf, rf.rf_row);
  DO_BOX (dbe_col_loc_t *, cl, inx, upd->upd_fixed_cl)
    {
      caddr_t data = QST_GET (qst, upd->upd_quick_values[inx]);
      row_insert_cast (rd, cl, data, err_ret, NULL);
      if (*err_ret)
	{
	  /* XXX: test case !!!! */
	  itc_page_leave (cr_itc, cr_buf);
	  return;
	}
      row_set_col (&rf, cl, cr_itc->itc_search_params[cr_itc->itc_search_par_fill - 1]);
    }
  END_DO_BOX;
  if (upd->upd_var_cl && BOX_ELEMENTS (upd->upd_var_cl))
    {
      upd_quick_var (upd, qst, cr_buf, rd, err_ret);
    }
  else
    {
      page_row (cr_buf, cr_itc->itc_map_pos, rd, RO_LEAF);
      itc_page_leave (cr_itc, cr_buf);
      log_update (cr_itc->itc_ltrx, rd, upd, qst);
      rd_free (rd);
      itc_free (cr_itc);
    }
}


void
update_node_run_1 (update_node_t * upd, caddr_t * inst,
		 caddr_t * state)
{
  int any_blob = 0, is_cluster = 0;
  caddr_t row_err = NULL;
  dk_set_t keys;
  key_id_t new_key;
  int res;
  placeholder_t *pl = (placeholder_t *) qst_place_get (state, upd->upd_place);
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (state);
  union {
  void * dummy;
  dtp_t temp [2000];
  } temp_un;
  LOCAL_RD (rd);
  rd.rd_temp = &(temp_un.temp[0]);
  rd.rd_temp_max = sizeof (temp_un.temp);
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
    LOCAL_RD (new_rd);
    ITC_INIT (cr_itc, qi->qi_space, qi->qi_trx);

    ITC_FAIL (cr_itc)
      {
	cr_buf = itc_set_by_placeholder (cr_itc, pl);
	cr_itc->itc_lock_mode = PL_EXCLUSIVE;
	if (!cr_itc->itc_is_on_row)
	  {
	    rdbg_printf (("Row to update deld before update T=%d L=%d pos=%d\n",
			  TRX_NO (cr_itc->itc_ltrx), cr_itc->itc_page, cr_itc->itc_map_pos));

	    itc_page_leave (cr_itc, cr_buf);
	    itc_free (cr_itc);
	    sqlr_new_error ("24000", "SR251", "Cursor not on row in positioned UPDATE");
	  }
	/* always true */
	{
	  cr_itc->itc_insert_key = pl->itc_tree->it_key; /* for debug info */
	  itc_set_lock_on_row (cr_itc, (buffer_desc_t **)&cr_buf);
	  if (!cr_itc->itc_is_on_row)
	    {
	      rdbg_printf (("Row to update deld during update lock  T=%d L=%d pos=%d\n",
			    TRX_NO (cr_itc->itc_ltrx), cr_itc->itc_page, cr_itc->itc_map_pos));
	      itc_page_leave (cr_itc, cr_buf);
	      sqlr_new_error ("01001", "SR252", "Row deleted while waiting to update");
	    }
	}
	cr_key = itc_get_row_key (cr_itc, cr_buf);
	if (cr_key->key_id == upd->upd_exact_key
	    && (upd->upd_fixed_cl || upd->upd_var_cl)
	    && !qi->qi_trx->lt_is_excl)
	  {
	    cr_itc->itc_insert_key = cr_key;
	    cr_itc->itc_row_key = cr_key;
	    new_rd.rd_itc = cr_itc;
	    new_rd.rd_non_comp_max = MAX_ROW_BYTES;
	    new_rd.rd_key = cr_itc->itc_insert_key;
	    upd_hi_pre (upd, qi);
	    new_rd.rd_temp = &(temp_un.temp[0]);
	    new_rd.rd_temp_max = sizeof (temp_un.temp);
	    update_quick (upd, state, cr_buf, &new_rd, &row_err);
	    if (row_err)
	      sqlr_resignal (row_err);
	    QI_ROW_AFFECTED (inst);
	    return;
	  }
	tb = cr_key->key_table;
	cr_itc->itc_row_key = cr_key;
	page_row_bm (cr_buf, cr_itc->itc_map_pos, &rd, RO_ROW, cr_itc);
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
	    res = itc_get_alt_key (main_itc, &main_buf, tb->tb_primary_key, &rd);
	    if (res == DVC_MATCH)
	      {
		rd_free (&rd);
		page_row (main_buf, main_itc->itc_map_pos, &rd, RO_ROW);
	      }
	    else
	      {
		itc_page_leave (main_itc, main_buf);
		rd_free (&rd);
		sqlr_new_error ("42S12", "SR253", "Could not find primary key on update.");
	      }
	  }
	ITC_FAILED
	  {
	    rd_free (&rd);
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
      }

    cr_key = itc_get_row_key (main_itc, main_buf);
    main_itc->itc_insert_key = cr_key;
    main_itc->itc_row_key = cr_key;
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
#ifdef PAGE_DEBUG
    if (main_buf->bd_writer != THREAD_CURRENT_THREAD)
      GPF_T1 ("Must have write on buffer to check it");
#endif

    /* blob ops in recompose row will use the itc to enter blobs and lose the pl.  Safe to save like this since the main_buf is never left in the process */
    mtx_assert (main_itc->itc_pl == main_buf->bd_pl);
    new_rd.rd_itc = main_itc;
    new_rd.rd_non_comp_max = new_tb->tb_any_blobs ? MAX_ROW_BYTES  * 2 : MAX_ROW_BYTES;
    new_rd.rd_key = new_tb->tb_primary_key;
    if (new_tb->tb_primary_key->key_partition)
      is_cluster = (!cl_run_local_only && upd->cms.cms_clrg)
	|| qi->qi_client->cli_is_log
	|| upd->cms.cms_is_cl_frag;
    keys = upd_recompose_row (state, upd, &rd, &new_rd,
			      &row_err, &any_blob);
    main_itc->itc_pl =main_buf->bd_pl;
    if (row_err)
      {
	itc_page_leave (main_itc, main_buf);
	if (keys && keys != BLOB_ERROR && keys != ALL_KEYS)
	  dk_set_free (keys);
	if (any_blob)
	  /* the txn can't commit because of half logged blob stuff that did not get completed */
	  TRX_POISON (qi->qi_trx);
	rd_free (&rd);
	itc_free (main_itc);
	sqlr_resignal (row_err);
      }
    ITC_FAIL (main_itc)
      {
	if (keys == BLOB_ERROR)
	  {
	    rd_free (&rd);
	    itc_bust_this_trx (main_itc, &main_buf, ITC_BUST_THROW);	/* jumps into main_itc's fail ctr below */
	  }

	if (is_cluster && ALL_KEYS == keys)
	  log_delete (main_itc->itc_ltrx, &rd, LOG_KEY_ONLY);
	else
	  log_update (main_itc->itc_ltrx, &rd, upd, state);
	if (keys == ALL_KEYS)
	  {
	    int inx;
	    itc_delete_this (main_itc, &main_buf, DVC_MATCH, NO_BLOBS);	/* blobs handled separately */
	    main_itc->itc_insert_key = new_tb->tb_primary_key;
	    keys = tb->tb_keys;
	    new_rd.rd_make_ins_rbe = 1;
	    if (!is_cluster)
	      {
		ITC_START_SEARCH_PARS (main_itc);
		for (inx = 0; inx < main_itc->itc_insert_key->key_n_significant; inx++)
		  ITC_SEARCH_PARAM (main_itc, new_rd.rd_values[main_itc->itc_insert_key->key_part_in_layout_order[inx]]);
		main_itc->itc_key_spec = main_itc->itc_insert_key->key_insert_spec;
		itc_insert_unq_ck (main_itc, &new_rd, NULL);
	      }
	  }
	else
	  {
	    new_rd.rd_map_pos = rd.rd_map_pos;
	    if (!main_itc->itc_ltrx->lt_is_excl)
	      lt_rb_update (main_itc->itc_ltrx, main_buf, BUF_ROW (main_buf, main_itc->itc_map_pos));
	    upd_refit_row (main_itc, &main_buf, &new_rd, RD_UPDATE);
	  }
      }
    ITC_FAILED
      {
	rd_free (&rd);
	itc_free (main_itc);
      }
    END_FAIL (main_itc);

    if (keys)
      {
	del_itc = &del_itc_auto;
	ITC_INIT (del_itc, qi->qi_space, qi->qi_trx);
	del_itc->itc_lock_mode = PL_EXCLUSIVE;

	ITC_FAIL (del_itc)
	  {
	    DO_SET (dbe_key_t *, key, &keys)
	      {
		if (key == tb->tb_primary_key)
		  goto next_key;
		if (!key->key_distinct)
		  {
		    del_itc->itc_no_bitmap = 0; /* reset as prev ins may set it to true */
		    res = itc_get_alt_key (del_itc, &del_buf, key, &rd);
		    itc_delete_this (del_itc, &del_buf, res, NO_BLOBS);
		  }
		upd_insert_2nd_key (key, del_itc,
				    &new_rd);
	      next_key:;
	      }
	    END_DO_SET ();
	  }
	ITC_FAILED
	  {
	    rd_free (&rd);
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
    rd_free (&rd);
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
   null without free. QST_GET_V () = NULL.

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
  else
    GPF_T1 ("this func is for keyset upd only");
}


void
update_node_input (update_node_t * upd, caddr_t * inst, caddr_t * state)
{
  query_instance_t * qi = (query_instance_t *) inst;
  LT_CHECK_RW (((query_instance_t *) inst)->qi_trx);
  QI_CHECK_STACK (qi, &qi, UPD_STACK_MARGIN);
  if (upd->upd_keyset)
    {
      update_node_run (upd, inst, state);
      return;
    }
  if (upd->upd_policy_qr)
    trig_call (upd->upd_policy_qr, inst, upd->upd_trigger_args, upd->upd_table);

  if (!upd->upd_trigger_args)
    {
      update_node_run_1 (upd, inst, state);
    }
  else
    {
      trig_wrapper (inst, upd->upd_trigger_args, upd->upd_table,
	  TRIG_UPDATE, (data_source_t *) upd, (qn_input_fn) update_node_run_1);
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


int
itc_row_insert (it_cursor_t * itc, row_delta_t * rd, buffer_desc_t ** unq_buf,
		    int blobs_in_place, int pk_only)
{
  int rc, inx;
  if (!blobs_in_place)
    rd_fixup_blob_refs (itc, rd);
  itc_from_keep_params (itc, rd->rd_key);
  itc->itc_insert_key = rd->rd_key;
  itc->itc_key_spec = rd->rd_key->key_insert_spec;
  for (inx = 0; inx < rd->rd_key->key_n_significant; inx++)
    itc->itc_search_params[inx] = rd->rd_values[rd->rd_key->key_part_in_layout_order[inx]];
  rd->rd_make_ins_rbe = 1;
  rc = itc_insert_unq_ck (itc, rd, unq_buf);
  if (pk_only)
    return rc;
  if (DVC_MATCH == rc)
    return rc;
  DO_SET (dbe_key_t *, key, &rd->rd_key->key_table->tb_keys)
    {
      if (!key->key_is_primary)
	upd_insert_2nd_key (key, itc, rd);
    }
  END_DO_SET();
  return DVC_LESS;
}

void
row_insert_rd_len (row_delta_t * rd)
{
  dbe_key_t * key = rd->rd_key;
  int inx = 0;
  DO_ALL_CL (cl, key)
    {
      caddr_t val = rd->rd_values [inx];
      switch (cl->cl_sqt.sqt_dtp)
	{
	  case DV_STRING:
	  case DV_WIDE:
	  case DV_ANY:
	  case DV_OBJECT:
	      rd->rd_non_comp_len += (box_length (val) - 1);
	      break;
	  case DV_BIN:
	      rd->rd_non_comp_len += box_length (val);
	      break;
	  case DV_BLOB:
	  case DV_BLOB_BIN:
	  case DV_BLOB_WIDE:
	      rd->rd_non_comp_len += DV_BLOB_LEN;
	      break;
	}
      inx++;
    }
  END_DO_ALL_CL;
}

void
row_insert_node_input (row_insert_node_t * ins, caddr_t * inst,
		       caddr_t * state)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (state);
  caddr_t * row = (caddr_t *) qst_get (state, ins->rins_row);
  buffer_desc_t *buf = NULL;
  it_cursor_t *it;
  dbe_key_t * key;
  LOCAL_RD (rd);
  rd.rd_allocated = RD_AUTO;
  LT_CHECK_RW (qi->qi_trx);
  it = itc_create (NULL, qi->qi_trx);
  rd.rd_values = &row[1];
  rd.rd_n_values = BOX_ELEMENTS (row) - 1;
  key = sch_id_to_key (wi_inst.wi_schema, unbox (row[0]));
  if (!key)
    sqlr_new_error ("42000", "RFW..", "Key id " BOXINT_FMT " undefined in row insert", unbox (row[0]));
  rd.rd_key = key;
  rd.rd_non_comp_len = key->key_row_var_start[0];
  rd.rd_non_comp_max = MAX_ROW_BYTES;
  row_insert_rd_len (&rd);
  ITC_FAIL (it)
  {
    if (DVC_MATCH == itc_row_insert (it, &rd, &buf, 0, 0))
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
	      itc_replace_row (it, buf, &rd, state, 0);
	      log_insert (it->itc_ltrx, &rd, ins->rins_mode);
	    }
	  }
      }
    else
      {
	QI_ROW_AFFECTED (inst);
	log_insert (it->itc_ltrx, &rd, ins->rins_mode);
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
#ifndef KEYCOMP
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
#endif
}





/* called when itc_insert_unq_ck finds existing row.
   The main_itc is inside the page on PA_READ and the lock is not set.
 */

int
itc_replace_row (it_cursor_t * main_itc, buffer_desc_t * main_buf, row_delta_t * rd,
		 caddr_t * state, int this_key_only)
{
  int res;
  dbe_key_t *old_key = itc_get_row_key (main_itc, main_buf);
  LOCAL_RD (old_rd);

  itc_set_lock_on_row (main_itc, &main_buf);
  if (!main_itc->itc_is_on_row)
    return REPLACE_RETRY;

  page_row (main_buf, main_itc->itc_map_pos, &old_rd, RO_ROW);
  ITC_LEAVE_MAPS (main_itc);
  {
    buffer_desc_t *del_buf;
    dbe_table_t *tb = old_key->key_table;
    it_cursor_t *del_itc;

    itc_delete (main_itc, &main_buf, MAYBE_BLOBS);
    itc_page_leave (main_itc, main_buf);
    if (!this_key_only)
      {
	del_itc = itc_create (NULL, main_itc->itc_ltrx);
	del_itc->itc_lock_mode = PL_EXCLUSIVE;
	ITC_FAIL (del_itc)
	  {
	    DO_SET (dbe_key_t *, key, &tb->tb_keys)
	      {
		if (key->key_is_primary)
		  goto next_key;
		res = itc_get_alt_key (del_itc, &del_buf,
				       key, &old_rd);
		itc_delete_this (del_itc, &del_buf, res, NO_BLOBS);
	      next_key:;
	      }
	    END_DO_SET ();
	  }
	ITC_FAILED
	  {
	    itc_free (main_itc);
	    itc_free (del_itc);
	  }
	END_FAIL (del_itc);
	itc_free (del_itc);
      }
  }
  rd_free (&old_rd);
  itc_row_insert (main_itc, rd, UNQ_ALLOW_DUPLICATES, 1, this_key_only);
  return REPLACE_OK;
}


void
pl_source_run (pl_source_t * pls, caddr_t * inst, caddr_t * state)
{
  volatile int inx = 0;
  int res;
  placeholder_t * volatile pl = (placeholder_t *) qst_place_get (state, pls->pls_place);
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (state);
  LOCAL_RD (rd);
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
	page_row (cr_buf, cr_itc->itc_map_pos, &rd, RO_ROW);
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
	  res = itc_get_alt_key (main_itc, &main_buf,
				 tb->tb_primary_key, &rd);
	  if (res == DVC_MATCH)
	    {
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
    rd_free (&rd);
    cr_key = itc_get_row_key (main_itc, main_buf);
    main_itc->itc_insert_key = cr_key;
    main_itc->itc_row_key = cr_key;
    main_itc->itc_row_data = main_buf->bd_buffer + main_buf->bd_content_map->pm_entries[main_itc->itc_map_pos];
    tb = cr_key->key_table;

    DO_SET (dbe_column_t *, col, &pls->pls_table->tb_primary_key->key_parts)
    {
      qst_set (inst, pls->pls_values[inx],
	  itc_box_column (main_itc, main_buf, col->col_id, NULL));
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



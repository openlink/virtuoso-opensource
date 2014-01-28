/*
 *  vecins.c
 *
 *  $Id$
 *
 *  Vectored insert
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
#include "xmlnode.h"
#include "sqlfn.h"
#include "sqlcomp.h"
#include "lisprdr.h"
#include "sqlopcod.h"
#include "security.h"
#include "sqlbif.h"
#include "sqltype.h"
#include "libutil.h"
#include "aqueue.h"
#include "arith.h"
#include "rdf_core.h"
#include "mhash.h"


int
key_cmp_boxes (caddr_t box1, caddr_t box2, sql_type_t * sqt)
{
  /* compare the boxes for key order. */
  dtp_t dtp1 = DV_TYPE_OF (box1);
  dtp_t dtp2 = DV_TYPE_OF (box2);
  if (DV_DB_NULL == dtp1 && DV_DB_NULL == dtp2)
    return DVC_MATCH;
  if (DV_DB_NULL == dtp1)
    return DVC_LESS;
  if (DV_DB_NULL == dtp2)
    return DVC_GREATER;
  switch (sqt->sqt_dtp)
    {
    case DV_ANY:
      return dv_compare ((db_buf_t) box1, (db_buf_t) box2, NULL, 0);
    default:
      return cmp_boxes (box1, box2, sqt->sqt_collation, sqt->sqt_collation);
    }
}


int
rd_compare (row_delta_t * rd1, row_delta_t * rd2)
{
  /* compare the key parts in key order */
  dbe_key_t *key = rd1->rd_key;
  int inx = 0;
  DO_SET (dbe_column_t *, col, &rd1->rd_key->key_parts)
  {
    int nth = key->key_part_in_layout_order[inx];
    int rc = key_cmp_boxes (rd1->rd_values[nth], rd2->rd_values[nth], &col->col_sqt);
    if (DVC_MATCH != rc)
      return rc;
    if (++inx >= key->key_n_significant)
      break;
  }
  END_DO_SET ();
  return DVC_MATCH;
}


void itc_ins_fetch_duplicate (it_cursor_t * itc, insert_node_t * ins);


int
itc_ins_next_set (it_cursor_t * itc, buffer_desc_t ** buf_ret, insert_node_t * ins)
{
  /* next param row.  If same as prev, skip unless goint to temp space.  If not on this page, return dvc index end. */
  dp_addr_t leaf = 0;
  page_map_t *pm;
  int rc;
  int n_pars, inx, all_eq;
  search_spec_t *sp;
next_set:
  sp = itc->itc_key_spec.ksp_spec_array;
  all_eq = 1;
  if (itc->itc_n_sets <= itc->itc_set + 1)
    {
      itc->itc_set++;
      return DVC_INDEX_END;
    }
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
      if (all_eq)
	{
	  int oinx = itc->itc_param_order[itc->itc_set];
	  int64 old_v = dc_any_value_n (dc, oinx, &onf);
	  if (nnf && onf)
	    ;
	  else if (onf || nnf || !(new_v == old_v || (DV_ANY == dc->dc_dtp && DVC_MATCH == dc_cmp (dc, old_v, new_v))))
	    all_eq = 0;
	}
      if (DCT_NUM_INLINE & dc->dc_type)
	{
	  NEXT_SET_INL_NULL (dc, ninx, inx);
	  *(int64 *) itc->itc_search_params[inx] = new_v;
	}
      else if (DV_ANY == sp->sp_cl.cl_sqt.sqt_dtp)
	itc->itc_search_params[inx] = (caddr_t) (ptrlong) new_v;
      else if (DV_ANY == dc->dc_dtp && sp->sp_cl.cl_sqt.sqt_dtp != DV_ANY)
	itc->itc_search_params[inx] = itc_temp_any_box (itc, inx, (db_buf_t) new_v);
      else if (!itc_vec_sp_copy (itc, inx, new_v, ninx))
	itc->itc_search_params[inx] = (caddr_t) (ptrlong) new_v;
    next:
      sp = sp->sp_next;
    }
  itc->itc_set++;
  if (all_eq)
    {
      if (INS_SOFT == ins->ins_mode || itc->itc_insert_key->key_is_bitmap || ins->ins_seq_col || itc->itc_insert_key->key_distinct)
	{
	  if (ins->ins_seq_col)
	    itc_ins_fetch_duplicate (itc, ins);
	  goto next_set;
	}
      if (KI_TEMP == itc->itc_insert_key->key_id)
	return DVC_MATCH;
      itc->itc_ltrx->lt_error = LTE_UNIQ;
      itc_bust_this_trx (itc, buf_ret, ITC_BUST_THROW);
    }

  pm = (*buf_ret)->bd_content_map;
  rc = itc->itc_key_spec.ksp_key_cmp (*buf_ret, pm->pm_count - 1, itc);
  if (DVC_LESS == rc || (itc->itc_desc_order && DVC_MATCH == rc))
    {
      /* compare to right edge */
      itc->itc_map_pos = pm->pm_count - 1;
      if (ITC_RIGHT_EDGE == itc->itc_keep_right_leaf || ITC_RL_INIT == itc->itc_keep_right_leaf)
	return rc;
      if (0 && DVC_LESS == rd_compare (itc->itc_vec_rds[itc->itc_param_order[itc->itc_set]], itc->itc_right_leaf_key))
	return rc;
      return DVC_INDEX_END;
    }
  itc->itc_landed = 0;
  itc->itc_dive_mode = PA_WRITE;
  itc->itc_is_on_row = 0;
  if (!itc->itc_no_bitmap && itc->itc_insert_key && itc->itc_insert_key->key_is_bitmap)
    itc_init_bm_search (itc);
  itc->itc_split_search_res = itc_vec_split_search (itc, buf_ret, itc->itc_map_pos, &leaf);
  if (leaf)
    return DVC_INDEX_END;
  return itc->itc_split_search_res;
}


void
itc_insert_rd_range (it_cursor_t * itc, buffer_desc_t * buf, int first_set)
{
  int inx, fill = 0;
  row_delta_t *rds_auto[100];
  row_delta_t **rds;
  if (itc->itc_set - first_set < sizeof (rds_auto) / sizeof (caddr_t))
    rds = rds_auto;
  else
    rds = dk_alloc_box (sizeof (caddr_t) * (itc->itc_set - first_set), DV_BIN);
  for (inx = 0; inx < itc->itc_set - first_set; inx++)
    {
      row_delta_t *rd = itc->itc_vec_rds[itc->itc_param_order[inx + first_set]];
      if (-1 == rd->rd_map_pos)
	continue;
      rds[fill++] = rd;
      if (itc->itc_log_actual_ins)
	log_insert (itc->itc_ltrx, rd, itc->itc_ins_flags);
    }
  itc->itc_app_stay_in_buf = ITC_APP_LEAVE;
  page_apply (itc, buf, fill, rds, PA_MODIFY);
  if (rds != rds_auto)
    dk_free_box ((caddr_t) rds);
}


void
itc_ins_fetch_duplicate (it_cursor_t * itc, insert_node_t * ins)
{
  int set = itc->itc_set;
  caddr_t *inst = itc->itc_out_state;
  data_col_t *flag_dc = QST_BOX (data_col_t *, inst, ins->ins_fetch_flag->ssl_index);
  data_col_t *val_dc = QST_BOX (data_col_t *, inst, ins->ins_seq_val->ssl_index);
  int64 prev_val = dc_any_value (val_dc, itc->itc_param_order[set - 1]);
  dc_set_long (flag_dc, itc->itc_param_order[set], 1);	/* the 2nd occurrence of the id counts as fetched, not as assigned */
  dc_set_long (val_dc, itc->itc_param_order[set], prev_val);
}


int64
itc_new_seq_col (it_cursor_t * itc, buffer_desc_t * buf, caddr_t seq_box)
{
  caddr_t value_seq_name = NULL;
  int64 res;
  QNCAST (query_instance_t, qi, itc->itc_out_state);
  QR_RESET_CTX
  {
    if (0 == strcmp ("RDF_URL_IID_NAMED", seq_box))
      {
	res = rdf_new_iri_id (itc->itc_ltrx, &value_seq_name, itc->itc_ltrx->lt_trx_no, qi);
	log_sequence (itc->itc_ltrx, value_seq_name, res + 1);
      }
    else
      {
	caddr_t err = NULL;
	if (CL_RUN_LOCAL == cl_run_local_only)
	  res = sequence_next_inc (seq_box, OUTSIDE_MAP, 1);
	if (err)
	  sqlr_resignal (err);
	log_sequence (itc->itc_ltrx, seq_box, res + 1);
      }
  }
  QR_RESET_CODE
  {
    POP_QR_RESET;
    qi->qi_trx->lt_error = LTE_CLUSTER;
    itc_bust_this_trx (itc, &buf, ITC_BUST_THROW);
  }
  END_QR_RESET;
  return res;
}


int
itc_ins_fetch (it_cursor_t * itc, buffer_desc_t * buf, insert_node_t * ins, int res, row_delta_t * rd)
{
  /* if match, get the col value, else make a new value from the seq and put it in the rd.  Return 1 if fetched, 0 if will need insert  */
  caddr_t *inst = itc->itc_out_state;
  QNCAST (query_instance_t, qi, inst);
  mem_pool_t *mp = qi->qi_mp;
  data_col_t *dc = QST_BOX (data_col_t *, inst, ins->ins_seq_val->ssl_index);
  int dc_save = dc->dc_n_values, ret;
  if (!dc || !(DCT_NUM_INLINE & dc->dc_type))
    {
      itc_page_leave (itc, buf);
      sqlr_new_error ("42000", "COL..", "insert fetch column must be typed int or iri id");
    }
  if (DVC_MATCH == res)
    {
      db_buf_t row = BUF_ROW (buf, itc->itc_map_pos);
      key_ver_t kv = IE_KEY_VERSION (row);
      dbe_key_t *row_key = itc->itc_insert_key->key_versions[kv];
      dbe_col_loc_t *cl = key_find_cl (row_key, ins->ins_seq_col->col_id);
      caddr_t b = page_copy_col (buf, row, cl, NULL);
      dc->dc_n_values = itc->itc_param_order[itc->itc_set];
      dc_append_box (dc, b);
      dc->dc_n_values = MAX (dc_save, dc->dc_n_values);
      dk_free_box (b);
      ret = 1;
    }
  else
    {
      int icol;
      int64 res;
      caddr_t seq_box = qst_get (inst, ins->ins_seq_name);
      if (!DV_STRINGP (seq_box))
	goto seq_err;
      res = itc_new_seq_col (itc, buf, seq_box);
      dc->dc_n_values = itc->itc_param_order[itc->itc_set];
      dc_append_int64 (dc, res);
      dc->dc_n_values = MAX (dc_save, dc->dc_n_values);
      icol = key_col_in_layout_seq (itc->itc_insert_key, ins->ins_seq_col);
      rd->rd_values[icol] = IS_INT_DTP (ins->ins_seq_col->col_sqt.sqt_dtp) ? mp_box_num (mp, res) : mp_box_iri_id (mp, res);
      ret = 0;
    }
  dc = QST_BOX (data_col_t *, inst, ins->ins_fetch_flag->ssl_index);
  if (!dc || !(DCT_NUM_INLINE & dc->dc_type))
    {
      itc_page_leave (itc, buf);
      sqlr_new_error ("42000", "COL..", "insert fetch column must be typed int or iri id");
    }
  dc_save = dc->dc_n_values;
  dc->dc_n_values = itc->itc_param_order[itc->itc_set];
  dc_append_int64 (dc, ret);
  dc->dc_n_values = MAX (dc_save, dc->dc_n_values);
  return ret;
seq_err:
  itc_bust_this_trx (itc, &buf, ITC_BUST_THROW);
  return 0;
}


#define MAX_SETS_FOR_PAGE (0x7fff - (PAGE_DATA_SZ / 4))	/* this + max no of rows on page to fit in signed short */

void
itc_vec_insert (it_cursor_t * itc, insert_node_t * ins)
{
  row_lock_t *rl_flag = KI_TEMP != itc->itc_insert_key->key_id && !itc->itc_non_txn_insert ? INS_NEW_RL : NULL;
  row_delta_t *rd;
  int res, ins_offset, first_set, pos, prev_pos, is_ins_del = 0;
  buffer_desc_t *buf;
  FAILCK (itc);
  if (itc->itc_insert_key->key_table && itc->itc_insert_key->key_is_primary)
    itc->itc_insert_key->key_table->tb_count_delta += itc->itc_n_sets;
  itc->itc_row_key = itc->itc_insert_key;
  itc->itc_lock_mode = PL_EXCLUSIVE;
  itc->itc_search_mode = SM_INSERT;
reset_search:
  first_set = itc->itc_set;
  ins_offset = 0;
  itc->itc_split_search_res = 0;
  buf = itc_reset (itc);
  res = itc_search (itc, &buf);
  if (itc->itc_map_pos >= buf->bd_content_map->pm_count)
    GPF_T1 ("itc map pos out of whack");
searched:
  if (itc->itc_map_pos >= buf->bd_content_map->pm_count)
    GPF_T1 ("itc map pos out of whack");
  if (first_set == itc->itc_set)
    {
      if (NO_WAIT != itc_insert_lock (itc, buf, &res, 1))
	goto reset_search;
    }
  else
    {
      if (NO_WAIT != itc_insert_lock (itc, buf, &res, 0))
	{
	  itc_insert_rd_range (itc, buf, first_set);
	  goto reset_search;
	}
    }
  if (itc->itc_insert_key->key_distinct && DVC_MATCH == res)
    {
      /* if key is distinct values only hitting a duplicate does nothing and returns success */
      goto next_on_page;
    }

  if (BUF_NEEDS_DELTA (buf))
    {
      ITC_IN_KNOWN_MAP (itc, itc->itc_page);
      itc_delta_this_buffer (itc, buf, DELTA_MAY_LEAVE);
      ITC_LEAVE_MAP_NC (itc);
    }
  if (!buf->bd_is_write)
    GPF_T1 ("insert and no write access to buffer");
  KEY_TOUCH (itc->itc_insert_key);
  rd = itc->itc_vec_rds[itc->itc_param_order[itc->itc_set]];
  if (ins->ins_seq_col && itc_ins_fetch (itc, buf, ins, res, rd))
    goto next_on_page;

  switch (res)
    {
    case DVC_INDEX_END:
    case DVC_LESS:
      /* Insert at leaf end. The cursor's position is perfect. */
      prev_pos = itc->itc_map_pos;
      itc_skip_entry (itc, buf);
      pos = ITC_AT_END == itc->itc_map_pos ? buf->bd_content_map->pm_count : itc->itc_map_pos;
      ITC_AGE_TRX (itc, 2);
      rd->rd_map_pos = pos + ins_offset;
      rd->rd_rl = rl_flag;
      ins_offset++;
      itc->itc_map_pos = prev_pos;
      goto next_on_page;

    case DVC_GREATER:
      /* Before the thing that is at cursor */

      ITC_AGE_TRX (itc, 2);
      rd->rd_map_pos = itc->itc_map_pos + ins_offset;
      rd->rd_rl = rl_flag;
      ins_offset++;
      goto next_on_page;
    case DVC_MATCH:
      if (itc_check_ins_deleted (itc, buf, rd, 0))
	{
	  rd->rd_map_pos = itc->itc_map_pos + ins_offset;
	  rd->rd_op = RD_UPDATE;
	  rd->rd_keep_together_dp = itc->itc_page;
	  rd->rd_keep_together_pos = itc->itc_map_pos;
	  rd->rd_rl = upd_refit_rlock (itc, itc->itc_map_pos);
	  is_ins_del = 1;
	  goto next_on_page;
	}

      if (INS_SOFT == ins->ins_mode)
	goto next_on_page;
      if (KI_TEMP == itc->itc_insert_key->key_id)
	{
	  rd->rd_map_pos = itc->itc_map_pos + ins_offset;
	  ins_offset++;
	}
      else
	{
	  if (itc->itc_ltrx)
	    {
	      if (itc->itc_insert_key)
		{
		  caddr_t detail = dk_alloc_box (50 + MAX_NAME_LEN + MAX_QUAL_NAME_LEN, DV_SHORT_STRING);
		  snprintf (detail, box_length (detail) - 1,
		      "Violating unique index %.*s on table %.*s",
		      MAX_NAME_LEN, itc->itc_insert_key->key_name, MAX_QUAL_NAME_LEN, itc->itc_insert_key->key_table->tb_name);
		  LT_ERROR_DETAIL_SET (itc->itc_ltrx, detail);
		}
	      itc->itc_ltrx->lt_error = LTE_UNIQ;
	    }
	  itc_bust_this_trx (itc, &buf, ITC_BUST_THROW);
	}

    default:
      GPF_T1 ("Bad search result in insert");
    }
next_on_page:
  res = itc_ins_next_set (itc, &buf, ins);
  if (DVC_INDEX_END == res || itc->itc_set - first_set >= MAX_SETS_FOR_PAGE)
    {
      if (ins_offset || is_ins_del)
	itc_insert_rd_range (itc, buf, first_set);
      else
	itc_page_leave (itc, buf);

      if (itc->itc_set == itc->itc_n_sets)
	return;
      goto reset_search;
    }
  else
    goto searched;
}

extern int enable_pos_bm_ins;

#define GO_NEXT \
{  \
  if (ITC_APP_STAYED != itc->itc_app_stay_in_buf) \
    goto next_set_reset;\
  buf = itc->itc_buf; \
  if (itc->itc_page != buf->bd_page || !buf->bd_is_write) \
    GPF_T1 ("in bm vec ins should have buf on write and itc in buf"); \
  goto next_set_on_page;\
}


long tc_vec_bm_non_txn_reset;

void
itc_bm_vec_insert (it_cursor_t * itc, insert_node_t * ins)
{
  dbe_key_t *key = itc->itc_insert_key;
  row_delta_t *rd;
  int rc, rc2, n_waits = 0;
  buffer_desc_t *buf;
  int org_owned = itc->itc_owned_search_par_fill, inx;
  int first_set = itc->itc_set;
  FAILCK (itc);
  itc->itc_row_key = itc->itc_insert_key;
  itc->itc_lock_mode = PL_EXCLUSIVE;
reset_search:
  itc->itc_desc_order = 1;
  itc->itc_key_spec = key->key_bm_ins_spec;
  itc->itc_no_bitmap = 1;	/* all ops here will ignore any bitmap features of the inx */
  itc->itc_isolation = ISO_SERIALIZABLE;
  itc->itc_batch_size = 0;
  itc->itc_search_mode = SM_READ;
  rd = itc->itc_vec_rds[itc->itc_param_order[itc->itc_set]];
  itc->itc_split_search_res = 0;
  itc->itc_write_waits = itc->itc_read_waits = 0;
  buf = itc_reset (itc);
  itc->itc_bm_insert = 1;
  rc = itc_next (itc, &buf);
  if (itc->itc_non_txn_insert && (itc->itc_write_waits || itc->itc_read_waits))
    {
      TC (tc_vec_bm_non_txn_reset);
      itc_page_leave (itc, buf);
      n_waits++;
      if (n_waits > 7)
	{
	  virtuoso_sleep (0, 100);
	  n_waits = 0;
	}
      goto reset_search;
    }
searched:
  rd = itc->itc_vec_rds[itc->itc_param_order[itc->itc_set]];
  if (!itc->itc_is_on_row)
    {
      /* There is no row with the leading parts equal and bit field lte with the value being inserted */
      itc->itc_desc_order = 0;
      if (DVC_LESS == rc && enable_pos_bm_ins)
	{
	  itc->itc_app_stay_in_buf = ITC_APP_STAY;
	  itc_bm_insert_single (itc, buf, rd, rc);
	  GO_NEXT;
	}
      else
	{
	  itc->itc_key_spec = key->key_bm_ins_leading;
	  itc->itc_desc_order = 0;
	  rc2 = itc_next (itc, &buf);
	  if (DVC_MATCH != rc2)
	    {
	      /* no previous entry and no next entry.  The leading parts are unique.  Insert a singleton entry */
	      itc->itc_app_stay_in_buf = ITC_APP_STAY;
	      itc_bm_insert_single (itc, buf, rd, DVC_INDEX_END);
	      GO_NEXT;
	    }
	  else
	    {
	      itc->itc_app_stay_in_buf = ITC_APP_STAY;
	      itc_bm_insert_in_row (itc, buf, rd);
	      GO_NEXT;
	    }
	}
    }
  else
    {
      itc->itc_app_stay_in_buf = ITC_APP_STAY;
      itc_bm_insert_in_row (itc, buf, rd);
      GO_NEXT;
    }
  GPF_T1 ("should not come here");
next_set_on_page:
  for (inx = org_owned; inx < itc->itc_owned_search_par_fill; inx++)
    dk_free_box (itc->itc_owned_search_params[inx]);
  itc->itc_owned_search_par_fill = org_owned;
  itc->itc_key_spec = key->key_bm_ins_spec;
  itc->itc_no_bitmap = 1;	/* all ops here will ignore any bitmap features of the inx */
  itc->itc_desc_order = 1;
  rc = itc_ins_next_set (itc, &buf, ins);
  itc->itc_split_search_res = 0;
  if (DVC_INDEX_END == rc || itc->itc_set - first_set >= MAX_SETS_FOR_PAGE)
    {
      itc_page_leave (itc, buf);
      if (itc->itc_set >= itc->itc_n_sets)
	return;
      goto reset_search;
    }
  else
    {
      if (NO_WAIT != itc_serializable_land (itc, &buf))
	{
	  itc_page_leave (itc, buf);
	  goto reset_search;
	}
      if (DVC_MATCH == rc)
	itc->itc_is_on_row = 1;
      goto searched;
    }
next_set_reset:
  for (inx = org_owned; inx < itc->itc_owned_search_par_fill; inx++)
    dk_free_box (itc->itc_owned_search_params[inx]);
  itc->itc_owned_search_par_fill = org_owned;
  itc->itc_set++;
  if (itc->itc_set == itc->itc_n_sets)
    return;
  itc_set_param_row (itc, itc->itc_set);
  goto reset_search;
}


caddr_t
dc_mp_insert_copy_any (mem_pool_t * mp, data_col_t * dc, int inx, dbe_column_t * col)
{
  caddr_t b;
  db_buf_t dv = (db_buf_t) (ptrlong) dc_any_value (dc, inx);
  int l;
  if (DV_RDF == dv[0])
    {
      db_buf_t rdf_id = mp_dv_rdf_to_db_serial (mp, dv);
      return (caddr_t) rdf_id;
    }
  if ((DV_STRING == dv[0] || DV_SHORT_STRING_SERIAL == dv[0] || DV_DB_NULL == dv[0]) && col && 'O' == col->col_name[0]
      && tb_is_rdf_quad (col->col_defined_in) && !f_read_from_rebuilt_database)
    {
      if (THR_TMP_POOL == mp)
	SET_THR_TMP_POOL (NULL);
      mp_free (mp);
      sqlr_new_error ("42000", "RDFST", "Inserting a string into O in RDF_QUAD.  RDF box is expected");
    }
  DB_BUF_TLEN (l, dv[0], dv);
  b = mp_alloc_box (mp, l + 1, DV_STRING);
  memcpy (b, dv, l);
  return b;
}


int n_v_ins;

void
rd_vec_blob (it_cursor_t * itc, row_delta_t * rd, dbe_column_t * col, int icol, mem_pool_t * ins_mp)
{
  caddr_t data = rd->rd_values[icol];
  if (itc->itc_insert_key->key_is_col)
    {
      if (blob_col_inlined (&data, col->col_sqt.sqt_dtp, ins_mp))
	{
	  rd->rd_values[icol] = data;
	  return;
	}
    }
  if (DV_DB_NULL != DV_TYPE_OF (data))
    {
      int rc;
      sql_type_t sqt2 = col->col_sqt;
      caddr_t bl = mp_alloc_box (ins_mp, DV_BLOB_LEN + 1, DV_STRING);
      sqt2.sqt_class = NULL; /* if this is long udt or any, it is anified before now */
      rc = itc_set_blob_col (itc, (db_buf_t)bl, rd->rd_values[icol], NULL,
				 BLOB_IN_INSERT, &sqt2);
      rd->rd_values[icol] = bl;
      if (LTE_OK != rc)
	{
	  mp_free (ins_mp);
	  sqlr_new_error ("42000", ".....", "Error making blob in vectored insert");
	}
    }
}


caddr_t
mp_wide_utf8 (mem_pool_t * mp, caddr_t box)
{
  caddr_t u = box_wide_as_utf8_char (box, box_length (box) / sizeof (wchar_t) - 1, DV_LONG_STRING);
  caddr_t mu = mp_box_copy (mp, u);
  dk_free_box (u);
  return mu;
}


void
rd_vec_cast (it_cursor_t * itc, row_delta_t * rd, dbe_column_t * col, int icol, mem_pool_t * ins_mp)
{
  caddr_t err = NULL;
  caddr_t val = rd->rd_values[icol];
  dtp_t dtp = DV_TYPE_OF (val);
  if (col->col_sqt.sqt_non_null && DV_DB_NULL == DV_TYPE_OF (val))
    {
      mp_free (ins_mp);
      sqlr_new_error ("42000", ".....", "Cannot insert null to non-null column %s", col->col_name);
    }
  if (IS_BLOB_DTP (col->col_sqt.sqt_dtp))
    {
      rd_vec_blob (itc, rd, col, icol, ins_mp);
      return;
    }
  else if (DV_ANY == col->col_sqt.sqt_dtp)
    {
      rd->rd_values[icol] = mp_box_to_any_1 (val, &err, ins_mp, 0);
      if (err)
	{
	  mp_free (ins_mp);
	  sqlr_resignal (err);
	}
      return;
    }
  else if (DV_WIDE == col->col_sqt.sqt_dtp && DV_WIDE == dtp)
    {
      rd->rd_values[icol] = mp_wide_utf8 (ins_mp, val);
      return;
    }
  val = box_cast_to (NULL, val, dtp, col->col_sqt.sqt_dtp, col->col_sqt.sqt_precision, col->col_sqt.sqt_scale, &err);
  if (err)
    {
      mp_free (ins_mp);
      sqlr_resignal (err);
    }
  if (DV_WIDE == DV_TYPE_OF (val))
    rd->rd_values[icol] = mp_wide_utf8 (ins_mp, val);
  else
    rd->rd_values[icol] = mp_full_box_copy_tree (ins_mp, val);
  dk_free_tree (val);
}


int cmpf_strn_intn (buffer_desc_t * buf, int irow, it_cursor_t * itc);

#define IS_RO_VAL(key) \
  (0 == strcmp (key->key_name, "RO_VAL"))

void
itc_ro_val_special_case (it_cursor_t * itc)
{
  /* for fetching insert of ro_val of rdf_obj, compare with 2 parts out of 3.  The inx is not declared unique on 2 leading but will be considered such */
  if (IS_RO_VAL (itc->itc_insert_key))
    itc->itc_key_spec.ksp_key_cmp = cmpf_strn_intn;
}

void
itc_vec_ins_param_order (it_cursor_t * itc, row_delta_t ** rds)
{
  int fill = 0, inx;
  for (inx = 0; inx < itc->itc_n_sets; inx++)
    {
      ptrlong rd = ((ptrlong *) rds)[inx];
      if (!(rd & 1))
	itc->itc_param_order[fill++] = inx;
    }
  itc->itc_n_sets = fill;
}


#if 0
void
itc_ins_order_ck (it_cursor_t * itc)
{
  int inx;
  if (itc->itc_insert_key->key_id != 237)
    return;
  for (inx = 1; inx < itc->itc_n_sets; inx++)
    {
      if (*(iri_id_t *) itc->itc_vec_rds[itc->itc_param_order[inx]]->rd_values[0] <=
	  *(iri_id_t *) itc->itc_vec_rds[itc->itc_param_order[inx - 1]]->rd_values[0])
	GPF_T1 ("ins not sorted");
    }
}
#endif


col_partition_t cp_distinct_any;

id_hashed_key_t
ins_unq_hash (char *strp)
{
  /* for index order rbs with no id are eq if data is eq, type does not affect comparison, so same for hash or there are  duplicates in distinct indices */
  uint64 h = 1;
  row_delta_t *rd = *(row_delta_t **) strp;
  dbe_key_t *key = rd->rd_key;
  int nth = 0;
  uint32 hno;
  int ign;
  DO_CL_0 (cl, key->key_key_fixed)
  {
    hno = box_hash (rd->rd_values[nth++]);
    MHASH_STEP (h, hno);
  }
  END_DO_CL;
  DO_CL (cl, key->key_key_var)
  {
    if (DV_ANY == cl->cl_sqt.sqt_dtp)
      hno = cp_any_hash (&cp_distinct_any, (db_buf_t) rd->rd_values[nth], &ign);
    else
      hno = box_hash (rd->rd_values[nth]);
    MHASH_STEP (h, hno);
    nth++;
  }
  END_DO_CL;
  return ((uint32) h) & ID_HASHED_KEY_MASK;
}


int
ins_unq_hashcmp (char *x, char *y)
{
  /* compare keys of rds with proper any type */
  row_delta_t *rd1 = *(row_delta_t **) x;
  row_delta_t *rd2 = *(row_delta_t **) y;
  dbe_key_t *key = rd1->rd_key;
  int nth = 0;
  DO_CL_0 (cl, key->key_key_fixed)
  {
    if (!box_equal (rd1->rd_values[nth], rd2->rd_values[nth]))
      return 0;
    nth++;
  }
  END_DO_CL;
  DO_CL (cl, key->key_key_var)
  {
    if (DV_ANY == cl->cl_sqt.sqt_dtp)
      {
	if (DVC_MATCH != dv_compare ((db_buf_t) rd1->rd_values[nth], (db_buf_t) rd2->rd_values[nth], NULL, 0))
	  return 0;
      }
    else
      {
	if (!box_equal (rd1->rd_values[nth], rd2->rd_values[nth]))
	  return 0;
      }
    nth++;
  }
  END_DO_CL;
  return 1;
}

extern int enable_p_stat;

int
tb_is_rdf_quad (dbe_table_t * tb)
{
  int is_q;
  if (!tb)
    return 0;
  if (1 == tb->tb_is_rdf_quad)
    return 1;
  if (2 == tb->tb_is_rdf_quad)
    return 0;
  is_q = 0 == stricmp (tb->tb_name, "DB.DBA.RDF_QUAD");
  tb->tb_is_rdf_quad = is_q ? 1 : 2;
  if (is_q)
    {
      enable_p_stat = 1;
      DO_SET (dbe_key_t *, key, &tb->tb_keys)
	{
	  if (!stricmp (key->key_name, "RDF_QUAD_POGS") && key->key_decl_parts == 4)
	    {
	      dbe_column_t *c1 = dk_set_nth (key->key_parts, 0), *c2 = dk_set_nth (key->key_parts, 1), *c3 = dk_set_nth (key->key_parts, 2), *c4 = dk_set_nth (key->key_parts, 3);
	      if (!stricmp (c1->col_name, "P") && !stricmp (c2->col_name, "O") && !stricmp (c3->col_name, "S") && !stricmp (c4->col_name, "G"))
		enable_p_stat = 2;
	    }
	}
      END_DO_SET();
    }
  return is_q;
}


int dbf_ko_pk;
int dbf_ko_key;
sort_cmp_func_t itc_param_cmp_func (it_cursor_t * itc);

int
key_vec_insert (insert_node_t * ins, caddr_t * qst, it_cursor_t * itc, ins_key_t * ik)
{
  int *other;
  dtp_t right_temp[2000];
  caddr_t err = NULL;
  dk_set_t parts;
  int null_skipped = 0;
  int n_rows, log_needed;
  mem_pool_t *ins_mp = mem_pool_alloc ();
  row_delta_t rd;
  row_delta_t **rds;
  int icol;
  int inx = 0;
  dbe_key_t *key = ik->ik_key;
  int n_parts = BOX_ELEMENTS (ik->ik_slots);
  id_hash_t *dups = NULL;
  query_instance_t *qi = (query_instance_t *) qst;
  LOCAL_RD (right_rd);
  QI_CHECK_STACK (qi, &qst, INS_STACK_MARGIN);
  if (dbf_ko_pk && dbf_ko_pk == key->key_table->tb_primary_key->key_id && dbf_ko_key != key->key_id)
    return 0;
  right_rd.rd_temp = right_temp;
  right_rd.rd_temp_max = sizeof (right_temp);
  memset (&rd, 0, sizeof (row_delta_t));
  n_v_ins++;
  rd.rd_allocated = RD_AUTO;
  rd.rd_keep_together_pos = ITC_AT_END;
  rd.rd_key = key;
  rd.rd_op = RD_INSERT;
  rd.rd_n_values = n_parts;
  rd.rd_non_comp_len = key->key_row_var_start[0];
  rd.rd_non_comp_max = MAX_ROW_BYTES;
  rd.rd_itc = itc;
  rd.rd_qst = qst;
  rd.rd_map_pos = -1;
  if (KI_TEMP != key->key_id && !qi->qi_non_txn_insert)
    rd.rd_make_ins_rbe = 1;
  itc->itc_non_txn_insert = qi->qi_non_txn_insert;
  itc_from_keep_params (itc, key, qi->qi_client->cli_slice);	/* fragment needs to be known before setting blobs */
  itc->itc_key_spec = key->key_insert_spec;
  itc->itc_out_state = qst;
  if (ins->src_gen.src_prev)
    n_rows = QST_INT (qst, ins->src_gen.src_prev->src_out_fill);
  else
    n_rows = qi->qi_n_sets;
  ins_mp->mp_block_size = mp_block_size_sc (n_rows * 8 * n_parts);
  rds = (row_delta_t **) mp_alloc (ins_mp, n_rows * sizeof (caddr_t));
  if (!key->key_parts)
    sqlr_new_error ("42S11", "SR119", "Key %.300s has 0 parts. Create index probably failed", key->key_name);

  if (key->key_distinct || key->key_is_col)
    {
      SET_THR_TMP_POOL (ins_mp);
      dups = t_id_hash_allocate (n_rows, sizeof (caddr_t), sizeof (caddr_t), ins_unq_hash, ins_unq_hashcmp);
    }

  for (inx = 0; inx < n_rows; inx++)
    {
      int var_row = 0, var_key = 0;
      row_delta_t *rd1;
      if (!QI_IS_SET (qi, inx))
	{
	  rds[inx] = (row_delta_t *) - 1;
	  continue;
	}
      rd1 = rds[inx] = (row_delta_t *) mp_alloc (ins_mp, sizeof (row_delta_t));
      memcpy (rd1, &rd, sizeof (row_delta_t));
      rd1->rd_values = (caddr_t *) mp_alloc_box (ins_mp, sizeof (caddr_t) * n_parts, DV_ARRAY_OF_POINTER);
      for (icol = 0; icol < n_parts; icol++)
	{
	  dbe_column_t *col = ik->ik_cols[icol];
	  if (SSL_IS_VEC (ik->ik_slots[icol]))
	    {
	      data_col_t *dc = QST_BOX (data_col_t *, qst, ik->ik_slots[icol]->ssl_index);
	      if (DV_ANY == dc->dc_dtp && (DV_ANY == col->col_sqt.sqt_dtp || DV_OBJECT == col->col_sqt.sqt_dtp))
		{
		  rd1->rd_values[icol] = dc_mp_insert_copy_any (ins_mp, dc, inx, col);
		  goto len_ck;
		}
	      else if (col == ins->ins_seq_col)
		rd1->rd_values[icol] = NULL;	/* is assigned in insert. For valgrind init to null so as not to read uninited  */
	      else
		{
		  caddr_t val = dc_mp_box_for_rd (ins_mp, dc, inx);
		  if (DV_WIDE == col->col_sqt.sqt_col_dtp && DV_WIDE == DV_TYPE_OF (val))
		    val = mp_box_wide_as_utf8_char (ins_mp, val, (box_length (val) / sizeof (wchar_t)) - 1, DV_STRING);
		  rd1->rd_values[icol] = val;
		}
	    }
	  else
	    rd1->rd_values[icol] = qst_get (qst, ik->ik_slots[icol]);
	  if (IS_BLOB_DTP (col->col_sqt.sqt_dtp))
	    rd_vec_blob (itc, rd1, col, icol, ins_mp);

	len_ck:
	  if (key->key_not_null && !col->col_sqt.sqt_non_null && icol < key->key_n_significant
	      && DV_DB_NULL == DV_TYPE_OF (rd1->rd_values[icol]))
	    {
	      rds[inx] = (row_delta_t *) - 1;
	      null_skipped = 1;
	      goto next_rd;
	    }
	  if (dtp_is_var (col->col_sqt.sqt_dtp))
	    {
	      int l = box_col_len (rd1->rd_values[icol]);
	      if (key->key_is_col && l > COL_MAX_STR_LEN)
		{
		  SET_THR_TMP_POOL (NULL);
		  mp_free (ins_mp);
		  itc->itc_ltrx->lt_status = LT_BLOWN_OFF;
		  itc->itc_ltrx->lt_error = LTE_SQL_ERROR;
		  sqlr_new_error ("22026", "COL..", "Non blob column %s too long, key %s, %d bytes",
		      col->col_name, key->key_name, l);
		}
	      if (icol < key->key_n_significant)
		var_key += l;
	      else
		var_row += l;
	    }
	}
      rd1->rd_non_comp_len += var_key + var_row;
      if (var_key + rd.rd_non_comp_len - key->key_row_var_start[0] + key->key_key_var_start[0] > MAX_RULING_PART_BYTES)
	{
	  SET_THR_TMP_POOL (NULL);
	  mp_free (ins_mp);
	  sqlr_error ("22026", "Key is too long, index %.300s, ruling part is %d bytes that exceeds %d byte limit",
	      key->key_name, (var_key + rd.rd_non_comp_len - key->key_row_var_start[0] + key->key_key_var_start[0]),
	      MAX_RULING_PART_BYTES);
	}
      if (!key->key_is_col && rd1->rd_non_comp_len > MAX_ROW_BYTES)
	{
	  SET_THR_TMP_POOL (NULL);
	  mp_free (ins_mp);
	  itc->itc_ltrx->lt_status = LT_BLOWN_OFF;
	  itc->itc_ltrx->lt_error = LTE_SQL_ERROR;
	  sqlr_new_error ("42000", "COL..", "Row too long len=%d max=%d", rd1->rd_non_comp_len, (int) MAX_ROW_BYTES);
	}
      if (!key->key_is_col)
      rd_inline (qi, rd1, &err, BLOB_IN_INSERT);
      if (err)
	{
	  SET_THR_TMP_POOL (NULL);
	  mp_free (ins_mp);
	  sqlr_resignal (err);
	}
      if (dups)
	{
	  caddr_t *place;
	  id_hashed_key_t hash = ins_unq_hash ((caddr_t) & rd1);
	  place = (caddr_t *) id_hash_get_with_hash_number (dups, (caddr_t) & rd1, hash);
	  if (place)
	    {
	      if (key->key_distinct || INS_SOFT == ins->ins_mode)
	    rds[inx] = (row_delta_t *) * place;
	  else
	    {
		  SET_THR_TMP_POOL (NULL);
		  mp_free (ins_mp);
		  itc->itc_ltrx->lt_status = LT_BLOWN_OFF;
		  itc->itc_ltrx->lt_error = LTE_UNIQ;
		  sqlr_new_error ("23000", "COL..", "Non unique insert, detected in sorting insert batchj on key %s",
		      itc->itc_insert_key->key_name);
		}
	    }
	  else
	    {
	      ptrlong tmp = (inx * 2) + 1;
	      t_id_hash_set_with_hash_number (dups, (caddr_t) & rd1, (caddr_t) & tmp, hash);
	    }
	}
    next_rd:;
    }
  SET_THR_TMP_POOL (NULL);
  log_needed = REPL_NO_LOG != itc->itc_ltrx->lt_replicate && (key->key_is_primary || ins->ins_key_only || key->key_partition);
  itc->itc_ins_flags = (ins->ins_key_only || key->key_partition ? LOG_KEY_ONLY : 0) | (ins->ins_mode ? INS_SOFT : 0)
      | (qi->qi_non_txn_insert ? LOG_SYNC : 0);
  itc->itc_log_actual_ins = log_needed && !key->key_is_bitmap && (key->key_distinct || ins->ins_seq_col
      || (INS_SOFT == ins->ins_mode && !itc->itc_ltrx->lt_blob_log));
  if (!itc->itc_log_actual_ins && log_needed)
    {
      for (inx = 0; inx < n_rows; inx++)
	{
	  if (!(1 & (ptrlong) rds[inx]))
	    log_insert (itc->itc_ltrx, rds[inx], itc->itc_ins_flags);
	}
    }
  itc_free_owned_params (itc);
  ITC_START_SEARCH_PARS (itc);
  itc->itc_search_par_fill = key->key_n_significant;
  /* now the cols are in layout order, kf kv rf rv.  Put them now at the head in key order */
  memset (itc->itc_search_params, 0, sizeof (caddr_t) * key->key_n_significant);
  parts = key->key_parts;
  for (inx = 0; inx < key->key_n_significant; inx++)
    {
      state_slot_t *ssl = ik->ik_slots[key->key_part_in_layout_order[inx]];
      dbe_column_t *col = (dbe_column_t *) parts->data;
      if (SSL_IS_VEC (ssl))
	{
	  data_col_t *dc = QST_BOX (data_col_t *, qst, ssl->ssl_index);
	  ITC_P_VEC (itc, inx) = dc;
	  itc_vec_box (itc, col->col_sqt.sqt_dtp, inx, dc);
	}
      else
	{
	  ITC_P_VEC (itc, inx) = NULL;
	  itc->itc_search_params[inx] = qst_get (qst, ssl);
	}
      parts = parts->next;
    }

  itc->itc_vec_rds = rds;
  if (n_rows > 1)
    {
      itc->itc_right_leaf_key = &right_rd;
      itc->itc_keep_right_leaf = ITC_RL_INIT;
      itc->itc_read_hook = itc_dive_read_hook;
    }
  itc->itc_set = 0;
  itc->itc_n_sets = n_rows;
  itc->itc_batch_size = dc_batch_sz;
  itc->itc_search_par_fill = itc->itc_n_vec_sort_cols = key->key_n_significant;
  itc->itc_param_order = (int *) mp_alloc_box (ins_mp, sizeof (int) * n_rows, DV_BIN);
  if (dups || null_skipped)
    itc_vec_ins_param_order (itc, rds);
  else
    itc_make_param_order (itc, qi, n_rows);
  if (!itc->itc_n_sets)
    goto done;
  if (!itc_vec_digit_sort (itc))
    {
      int save = itc->itc_n_vec_sort_cols;
      other = QST_BOX (int *, qst, ins->src_gen.src_sets);
      if (box_length (other) < n_rows * sizeof (int))
	other = (int *) mp_alloc_box_ni (ins_mp, sizeof (int) * n_rows, DV_BIN);
      if (ins->ins_seq_col && IS_RO_VAL (itc->itc_insert_key))
	itc->itc_n_vec_sort_cols--;	/* if insert-fetch of ro_val, the 3rd dc (ro_id) is uninited, do not count this */
      gen_qsort (itc->itc_param_order, other, itc->itc_n_sets, 0, itc_param_cmp_func (itc), (void *) itc);
      itc->itc_n_vec_sort_cols = save;
    }
  /*itc_ins_order_ck (itc); */
  itc->itc_v_out_map = ins->ins_v_out_map;
  itc->itc_asc_eq = 1;
  itc_set_param_row (itc, 0);
  if (itc->itc_insert_key->key_is_primary)
    qi->qi_n_affected += itc->itc_n_sets;
  ITC_SAVE_FAIL (itc);
  ITC_FAIL (itc)
  {
    if (!itc->itc_non_txn_insert)
      cl_enlist_ck (itc, NULL);

    if (key->key_is_bitmap)
      itc_bm_vec_insert (itc, ins);
    else if (key->key_is_col)
      itc_col_vec_insert (itc, ins);
    else
      {
	if (ins->ins_seq_col)
	  itc_ro_val_special_case (itc);
	itc_vec_insert (itc, ins);
      }
  }
  ITC_FAILED
  {
    rd_free (&right_rd);
    mp_free (ins_mp);
    itc_free_owned_params (itc);
  }
  END_FAIL (itc);
  ITC_RESTORE_FAIL (itc);
done:
  rd_free (&right_rd);
  mp_free (ins_mp);
  itc_free_owned_params (itc);
  return DVC_LESS;
}

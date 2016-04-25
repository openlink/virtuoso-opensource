/*
 *  inxop.c
 *
 *  $Id$
 *
 *  SQL query execution
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
#include "arith.h"





#define QST_SET(qst, ssl, v) \
  ((caddr_t*)qst)[ssl->ssl_index] = (caddr_t) v



int
itc_near_random (it_cursor_t * itc, placeholder_t * pl, buffer_desc_t ** buf_ret,
		 ptrlong * n_hits, int is_asc)
{
  /* set by pl, see if on same page. If not,
   * do full lookup.  If asc order, a negative can be confirmed on local page if max of page less than key sought.*/
  int res;
  dp_addr_t target_dp;
#ifdef ADAPTIVE_LAND
  itc->itc_dive_mode = PA_WRITE;
  /* this is likely a leaf.  Get excl.  There will be no automatic registration in page_wait_access because there is no buf_from here */
#endif
  target_dp = pl->itc_page;
  ITC_IN_KNOWN_MAP (itc, target_dp);
  page_wait_access (itc, target_dp, NULL, buf_ret, itc->itc_dive_mode, RWG_WAIT_DATA);
  /* itc_page can change anytime.  Accept entry only if pl->itc_pagge agrees with entry after entry */
  if (PF_OF_DELETED == *buf_ret)
    goto entry_failed;
  if (itc->itc_to_reset <= RWG_WAIT_DATA
      && (*buf_ret)->bd_page != pl->itc_page)
    {
      page_leave_outside_map (*buf_ret)
      goto entry_failed;
    }
  if (itc->itc_to_reset <= RWG_WAIT_DATA)
    {
      page_map_t * pm;
      if ( !(*buf_ret)->bd_content_map || !(*buf_ret)->bd_content_map->pm_count)
	{
	  page_leave_outside_map (*buf_ret)
	    goto entry_failed;
	}
      pm = (*buf_ret)->bd_content_map;
      if (itc == (it_cursor_t *) pl)
	{
	  itc_unregister_inner (itc, *buf_ret, 0);
	}
      else
	{
	  itc->itc_page = pl->itc_page;
	}
      itc->itc_is_on_row = 0;
      itc->itc_landed = 0;
      if (is_asc)
	{
	  ITC_LEAVE_MAPS (itc);
	  res = pg_key_compare (*buf_ret, pm->pm_count - 1, itc);
	  if (DVC_GREATER == res || DVC_MATCH == res)
	    {
	      /* we know that it is asc order and max of page > value sought.  The result is valid without a full lookup */
	      res = itc_next (itc, buf_ret);
	      (*n_hits)++; /* hit for purposes of locality whether data found or not */
	      return res;
	    }
	  page_leave_outside_map (*buf_ret);
	}
      else
	{
	  res = itc_next (itc, buf_ret);
	  if (DVC_MATCH == res)
	    {
	      (*n_hits)++;
	      return res;
	    }
	  page_leave_outside_map (*buf_ret);
	}
    }
 entry_failed:
  if (itc == (it_cursor_t *) pl)
    itc_unregister (itc);
  *buf_ret = itc_reset (itc);
  res = itc_next (itc, buf_ret);
  return res;
}



int
itc_il_search (it_cursor_t * itc, buffer_desc_t ** buf_ret, caddr_t * qst,
	       inx_locality_t * il, placeholder_t * pl, int is_asc)
{
  ptrlong n = QST_PLONG (qst, il->il_n_read)++;
  ptrlong hits = QST_PLONG (qst, il->il_n_hits);
  int res;
  if (!il->il_n_read)
    GPF_T1 ("il not inited.");
  /* the locality trick simply does not work with inx int with lubm if non bm inx.  A bm inx does no il trick.  So the il trick is commented out */
  if (0 &&pl && pl->itc_is_registered
      && n > 3 && n / (hits | 1) < 3)
    {
      res = itc_near_random (itc, pl, buf_ret,
			     &QST_PLONG (qst, il->il_n_hits), is_asc);
      QST_PLONG (qst, il->il_last_dp) = itc->itc_page;
      return res;
    }
  else
    {
      *buf_ret = itc_reset (itc);
      res = itc_next (itc, buf_ret);
      if (itc->itc_page == QST_PLONG (qst, il->il_last_dp))
	QST_PLONG (qst, il->il_n_hits)++;
      else
	QST_PLONG (qst, il->il_last_dp) = itc->itc_page;
      return res;
    }
}





int
ssl_n_cmp (query_instance_t * qi, state_slot_t ** s1, state_slot_t ** s2)
{
  int inx;
  caddr_t * qst = (caddr_t *) qi;
  DO_BOX (state_slot_t *, ssl1, inx, s1)
    {
      int rc = cmp_boxes (qst_get (qst, ssl1), qst_get (qst, s2[inx]), NULL, NULL);
      if (DVC_MATCH != rc)
	return rc;
    }
  END_DO_BOX;
  return DVC_MATCH;
}


#define IOP_START 0
#define IOP_TARGET 1
#define IOP_NEXT 2


void
inx_op_set_params (inx_op_t * iop, it_cursor_t * itc)
{
  ITC_START_SEARCH_PARS (itc);
}



void
inxop_bm_leading_output (it_cursor_t * itc, buffer_desc_t * buf)
{
  dbe_key_t * key = itc->itc_insert_key;
  key_source_t * ks = itc->itc_ks;
  if (ks->ks_out_cols)
    {
      int inx = 0;
      out_map_t * om = itc->itc_ks->ks_out_map;
      DO_SET (state_slot_t *, ssl, &ks->ks_out_slots)
	{
	  if (om[inx].om_is_null)
	    {
	      if (OM_BM_COL == om[inx].om_is_null)
		{
		  /* we set the bitmapped col.  Note both iri ids are 64 bit boxes.  An int is 32 bit */
		  if (DV_IRI_ID == key->key_bit_cl->cl_sqt.sqt_dtp || DV_IRI_ID_8 == key->key_bit_cl->cl_sqt.sqt_dtp)
		    qst_set_bin_string (itc->itc_out_state, ssl, (db_buf_t) &itc->itc_bp.bp_value, sizeof (iri_id_t), DV_IRI_ID);
		  else
		    qst_set_long (itc->itc_out_state, ssl, itc->itc_bp.bp_value);
		}
	      else if (OM_NULL == om[inx].om_is_null)
		qst_set_bin_string (itc->itc_out_state, ssl, (db_buf_t) "", 0, DV_DB_NULL);
	      else
		qst_set (itc->itc_out_state, ssl, itc_box_row (itc, (buffer_desc_t *) buf->bd_buffer));
	    }
	  else
	    {
	      itc_qst_set_column (itc, buf, &om[inx].om_cl, itc->itc_out_state, ssl);
	    }
	  inx++;
	}
      END_DO_SET();
    }
}


typedef struct inxop_bm_s
{
  bitno_t	iob_start;
  bitno_t	iob_end;
  short		iob_bm_len;
  char		iob_is_inited;
  dtp_t		iob_bm[CE_MAX_LENGTH];
} inxop_bm_t;



void
inxop_set_iob (inx_op_t * iop, it_cursor_t *itc, buffer_desc_t * buf, caddr_t * qst)
{
  int off, len, is_single;
  dbe_key_t * key = itc->itc_insert_key;
  inxop_bm_t * iob = (inxop_bm_t *) QST_GET (qst, iop->iop_bitmap);
  KEY_PRESENT_VAR_COL (itc->itc_insert_key, itc->itc_row_data, (*key->key_bm_cl), off, len);
  if (!iob)
    {
      iob = (inxop_bm_t *) dk_alloc_box (sizeof (inxop_bm_t), DV_STRING);
      qst_set (qst, iop->iop_bitmap, (caddr_t) iob);
    }
  if (len > CE_MAX_LENGTH)
    GPF_T1 ("bad bm len in inxop bm");
  iob->iob_is_inited = 1;
  iob->iob_bm_len = len;
  itc_bm_ends (itc, buf, &iob->iob_start, &iob->iob_end, &is_single);
  memcpy (&iob->iob_bm[0], itc->itc_row_data + off, len);
}


void
inxop_set_bm_ssl (inx_op_t * iop, it_cursor_t *itc, caddr_t * qst)
{
  dbe_key_t * key = itc->itc_insert_key;
  DO_SET (state_slot_t *, ssl, &itc->itc_ks->ks_out_slots)
    {
      if (ssl->ssl_column && ssl->ssl_column->col_id == key->key_bit_cl->cl_col_id)
	{
	  if (DV_IRI_ID == key->key_bit_cl->cl_sqt.sqt_dtp || DV_IRI_ID_8 == key->key_bit_cl->cl_sqt.sqt_dtp)
	    qst_set_bin_string (itc->itc_out_state, ssl, (db_buf_t) &itc->itc_bp.bp_value, sizeof (iri_id_t), DV_IRI_ID);
	  else
	    qst_set_long (itc->itc_out_state, ssl, (int32) itc->itc_bp.bp_value);
	}
    }
  END_DO_SET();
}


void
itc_set_search_param (it_cursor_t * itc, int nth, caddr_t val, dtp_t dtp)
{
  int inx, found = 0;
  caddr_t err = NULL;
  caddr_t cast_val = NULL;
  if (DV_ANY == dtp)
    cast_val = box_to_any  (val, &err);
  for (inx = 0; inx < itc->itc_owned_search_par_fill; inx++)
    {
      if (itc->itc_search_params[nth] == itc->itc_owned_search_params[inx])
	{
	  dk_free_tree (itc->itc_owned_search_params[inx]);
	  itc->itc_owned_search_params[inx] = cast_val;
	  found = 1;
	}
    }
  if (!found && cast_val)
    {
      ITC_OWNS_PARAM (itc, cast_val);
      if (itc->itc_owned_search_par_fill > 10) GPF_T1 ("overflow owned params in inx int");
    }
  itc->itc_search_params[nth] = cast_val ? cast_val : val;
}


int enable_iop_other = 1;

int
inxop_bm_check_other (inx_op_t * iop, caddr_t * qst)
{
  /* see if the target is in the range of the other's bm.  If it is, advance the other by one.  Compare with this.  If this other is greater than the present, put the value of the other as new target and return 1. */
  caddr_t target_box = qst_get (qst, iop->iop_target_ssl);
  dtp_t target_dtp = DV_TYPE_OF (target_box);
  bitno_t target;
  inxop_bm_t * iob;
  it_cursor_t * itc;
  if (!enable_iop_other)
    return 0;
  if (DV_IRI_ID != target_dtp && DV_LONG_INT != target_dtp)
    return 0;
  target = unbox_iri_int64 (target_box);
  iob = (inxop_bm_t *)QST_GET (qst, iop->iop_other->iop_bitmap);

  if (!iob || !iob->iob_is_inited || 0 == iob->iob_bm_len)
    return 0;
  if (target < iob->iob_start || target >= iob->iob_end + CE_N_VALUES)
    return 0;
  itc = (it_cursor_t *)QST_GET (qst, iop->iop_other->iop_itc);
  if (!itc->itc_bp.bp_is_pos_valid || itc->itc_bp.bp_at_end)
    return 0;


  pl_next_bit ((placeholder_t *)itc, iob->iob_bm, iob->iob_bm_len, iob->iob_start, 0);
  if (itc->itc_bp.bp_at_end)
    return 0;
  if (itc->itc_bp.bp_value == target)
    return 0; /* the normal course will produce a match */
  if (itc->itc_bp.bp_value > target)
    {
      /* pick the value as the new target and loop */
      it_cursor_t * this_itc = (it_cursor_t *)QST_GET (qst, iop->iop_itc);
      inxop_set_bm_ssl (iop->iop_other, itc, qst);
      itc_set_search_param (this_itc, this_itc->itc_insert_key->key_n_significant - 1, qst_get (qst, iop->iop_target_ssl), iop->iop_target_dtp);
      return 1;
    }
  return 0;
}


int
inxop_check_other (inx_op_t * iop, caddr_t * qst)
{
  /* true if this iop must go to start because the other iop cannot match the present value.  If so
   * this sets the new target and the op on the next iteration is always IOP_TARGET */
  if (!iop->iop_other || !iop->iop_other->iop_bitmap)
    return 0;
  return inxop_bm_check_other (iop, qst);
}


#define INXOP_OTHER \
  if (inxop_check_other (iop, qst))		\
{ \
  op = IOP_TARGET; goto start; \
}



int
inxop_iob_next (inx_op_t * iop, it_cursor_t * itc, inxop_bm_t * iob, int op, caddr_t * qst)
{
  bitno_t target;
  if (!iob->iob_is_inited || 0 == iob->iob_bm_len)
    return IOP_READ_INDEX;
  switch (op)
    {
    case IOP_TARGET:
      target = unbox_iri_int64 (itc->itc_search_params[itc->itc_insert_key->key_n_significant - 1]);
      if (target < iob->iob_start || target >=  iob->iob_end + CE_N_VALUES)
	return IOP_READ_INDEX;
      pl_set_at_bit ((placeholder_t *) itc, iob->iob_bm, iob->iob_bm_len, iob->iob_start, target, 0);
      if (itc->itc_bp.bp_at_end)
	return IOP_READ_INDEX;
      inxop_set_bm_ssl (iop, itc, qst);
      if (itc->itc_bp.bp_value == target)
	return IOP_ON_ROW;
      return IOP_NEW_VAL;
    case IOP_NEXT:
      pl_next_bit ((placeholder_t *)itc, iob->iob_bm, iob->iob_bm_len, iob->iob_start, 0);
      if (itc->itc_bp.bp_at_end)
	return IOP_READ_INDEX;
      inxop_set_bm_ssl (iop, itc, qst);
      return IOP_NEW_VAL;
    }
  return IOP_READ_INDEX;
}


int next_ctr = 0;
int64 prev_target;
void
check_target (it_cursor_t * itc)
{
  int64 target = unbox_iri_int64 (itc->itc_search_params[3]);
#ifdef DEBUG
  if (target < prev_target) bing ();
#endif
  prev_target = target;
}

int
inxop_bm_next (inx_op_t * iop , query_instance_t * qi, int op,
	       table_source_t * ts, it_cursor_t * itc)
{
  caddr_t *qst = (caddr_t*)qi;
  int rc;
  buffer_desc_t * buf = NULL;
  inxop_bm_t * iob;
  next_ctr++;
 start:
  if (0 && IOP_TARGET == op)
    check_target (itc);
  iob = (inxop_bm_t *) QST_GET (qst, iop->iop_bitmap);
  if (iob &&  iob->iob_is_inited)
    {
      rc = inxop_iob_next (iop, itc, iob, op, qst);
      if (rc != IOP_READ_INDEX)
	{
	  if (IOP_NEW_VAL == rc)
	    {
	      INXOP_OTHER;
	    }
	  return rc;
	}
    }
  ITC_FAIL (itc)
    {
      switch (op)
	{
	case IOP_START:
	  itc->itc_search_mode = SM_READ;
	  buf = itc_reset (itc);
	  rc = itc_next (itc, &buf);
	  if (DVC_MATCH == rc)
	    {
	      inxop_set_iob (iop, itc, buf, qst);
	      itc_register (itc, buf);
	      itc_page_leave (itc, buf);
	      return IOP_ON_ROW;
	    }
	  else
	    {
	      itc_page_leave (itc, buf);
	      return IOP_AT_END;
	    }
	case IOP_TARGET:
	  itc->itc_search_mode = SM_READ;
	  itc->itc_key_spec = iop->iop_ks_full_spec; /* set here. May have looped because of checking with iop_other and the init speczs may have been the specs for next */
	  buf = itc_reset (itc);
	  rc = itc_search (itc, &buf);
	  if (DVC_LESS == rc)
	    {
	      /* the bm was not even checked, failed to find a match of leading parts.
	       * or Could be we got a match of leading and the first bm col was gt and we wanted lte.  So recheck one forward with just */
	      itc->itc_desc_order = 0;
	      itc->itc_bp.bp_value = BITNO_MIN;
	      itc->itc_is_on_row = 0;
	      itc_skip_entry (itc, buf);
	      itc->itc_key_spec = itc->itc_insert_key->key_bm_ins_leading;
	      itc->itc_bm_col_spec = NULL;
	      rc = itc_next (itc, &buf);
	      if (DVC_MATCH != rc)
		{
		  itc_page_leave (itc, buf);
		  return IOP_AT_END;
		}
	      inxop_set_iob (iop, itc, buf, qst);
	      itc_register (itc, buf);
	      itc_page_leave (itc, buf);
	      INXOP_OTHER;
	      return IOP_NEW_VAL;
	    }
	  if (!itc->itc_bp.bp_is_pos_valid)
	    {
	      /* bp not checked, must have changed so that hit gt right off */
	      itc_page_leave (itc, buf);
	      return IOP_AT_END;
	    }
	  inxop_set_iob (iop, itc, buf, qst);
	  if (DVC_MATCH == rc)
	    {
	      itc_register (itc, buf);
	      itc_page_leave (itc, buf);
	      return IOP_ON_ROW;
	    }

	  if (itc->itc_bp.bp_below_start)
	    itc->itc_bp.bp_at_end = 0; /* use the value it is at, since bp)value will be set to 1st of ce even if value sought was lt that */
	  if (DVC_INDEX_END == rc)
	    {
	      itc_page_leave (itc, buf);
	      return IOP_AT_END;
	    }
	  if (itc->itc_bp.bp_at_end)
	    {
	      /* now it could be landed past the last bit of the bitmap whose range corresponds to the spec.  Can be one after that.  If still no next then really at end of range. */
	      int rc2;
	      itc->itc_is_on_row = 1; /*force one step fwd */
	      itc->itc_key_spec = itc->itc_insert_key->key_bm_ins_leading;
	      itc->itc_bm_col_spec = NULL;
	      rc2 = itc_next (itc, &buf);
	      if (DVC_INDEX_END == rc2 || (DVC_GREATER == rc2 && itc->itc_bp.bp_at_end))
		{
		  itc_page_leave (itc, buf);
		  return IOP_AT_END;
		}
	      inxop_set_iob (iop, itc, buf, qst);
	    }
	  if (DVC_GREATER == rc)
	    {
	      /* the bp_value is the next higher.  Set the ssl by it. */
	      itc->itc_is_on_row = 1; /* set this so that next operation, should the other itc match, will advance and not repeat this same row */
	      inxop_bm_leading_output (itc, buf);
	      /*inxop_set_bm_ssl (iop, itc, qst); */
	      itc_register (itc, buf);
	      itc_page_leave (itc, buf);
	      INXOP_OTHER;
	      return IOP_NEW_VAL;
	    }
	  GPF_T1 ("bm inx and target seek rc impossible");
	case IOP_NEXT:
	  buf = page_reenter_excl (itc);
	  itc->itc_bm_col_spec = NULL;
	  rc = itc_next (itc, &buf);
	  if (DVC_GREATER == rc || DVC_INDEX_END == rc)
	    {
	      itc_page_leave (itc, buf);
	      return IOP_AT_END;
	    }
	  inxop_set_iob (iop, itc, buf, qst);
	  itc_register (itc, buf);
	  itc_page_leave (itc, buf);
	  return DVC_MATCH;
	}
    }
  ITC_FAILED
    {
    }
  END_FAIL (itc);
  return 0;			/* never executed */
}


int
inxop_next (inx_op_t * iop , query_instance_t * qi, int op,
	    table_source_t * ts)
{
  key_source_t * ks = iop->iop_ks;
  int is_nulls = 0, rc = 0, rc2 = 0;
  int is_random = 0;
  caddr_t * qst = (caddr_t *) qi;
  it_cursor_t * itc = (it_cursor_t *) QST_GET (qst, iop->iop_itc);
  buffer_desc_t *buf;


  if (!itc)
    {
      itc = itc_create (NULL, qi->qi_trx);
      QST_SET (qst, iop->iop_itc, itc);
    }
  if (!itc->itc_search_par_fill)
    {
      itc->itc_ks = ks;
      itc->itc_out_state = qst;

      itc_from (itc, ks->ks_key, QI_NO_SLICE);
      itc->itc_insert_key = ks->ks_key;
      itc->itc_desc_order = ks->ks_descending;

      itc_free_owned_params (itc);
      ITC_START_SEARCH_PARS (itc);
      switch (op)
	{
	case IOP_START:
	case IOP_NEXT:
	  is_nulls = ks_make_spec_list (itc, iop->iop_ks_start_spec.ksp_spec_array, qst);
	  itc->itc_search_params[itc->itc_insert_key->key_n_significant - 1] = NULL; /*otherwise uninited in itc_set_search_param later */
	  itc->itc_search_par_fill = itc->itc_insert_key->key_n_significant;
	  /* set the fill to be like full eq of all parts because the row spec is so laid out that it presupposes the full eq  search spec to precede it. */
	  is_nulls |= ks_make_spec_list (itc, iop->iop_ks_row_spec, qst);
	  itc->itc_key_spec = iop->iop_ks_start_spec;
	  itc->itc_row_specs = iop->iop_ks_row_spec;
	  break;
	case IOP_TARGET:
	  is_nulls = ks_make_spec_list (itc, iop->iop_ks_full_spec.ksp_spec_array, qst);
	  if (is_nulls)
	    {
	      int res;
	      if (itc->itc_is_registered)
		return IOP_AT_END; /*found something already, type no longer castable but was, so no more hits possible */
	      itc_free_owned_params (itc);
	      ITC_START_SEARCH_PARS (itc);
	      res = inxop_next (iop, qi, IOP_START, ts);
	      if (IOP_ON_ROW == res)
		return IOP_NEW_VAL;
	      return IOP_AT_END;
	    }
	  is_nulls |= ks_make_spec_list (itc, iop->iop_ks_row_spec, qst);
	  itc->itc_key_spec = iop->iop_ks_full_spec;
	  itc->itc_row_specs = iop->iop_ks_row_spec;
	  break;
	}
      if (is_nulls)
	return IOP_AT_END;
      if (IOP_START == op)
	{
	  if (ts->src_gen.src_query->qr_select_node
	      && ts->src_gen.src_query->qr_lock_mode != PL_EXCLUSIVE)
	    {
	      itc->itc_lock_mode = qi->qi_lock_mode;
	    }
	  else
	    itc->itc_lock_mode = PL_EXCLUSIVE;
	  /* if the statement is not a SELECT, take excl. lock */
	  itc->itc_isolation = qi->qi_isolation;
	}

      DO_SET (state_slot_t*, ssl, &ks->ks_always_null)
	{
	  qst_set_bin_string (itc->itc_out_state, ssl, (db_buf_t) "", 0, DV_DB_NULL);
	}
      END_DO_SET();
    }
  if (IOP_TARGET == op)
    {
      itc->itc_key_spec = iop->iop_ks_full_spec;
      itc_set_search_param (itc, itc->itc_insert_key->key_n_significant - 1, qst_get (itc->itc_out_state, iop->iop_target_ssl), iop->iop_target_dtp);
    }
  else
    itc->itc_key_spec = iop->iop_ks_start_spec;

  if (itc->itc_insert_key->key_is_bitmap)
    return inxop_bm_next (iop, qi, op, ts, itc);

  ITC_FAIL (itc)
    {
      switch (op)
	{
	case IOP_START:
	  is_random = 1;
	  itc->itc_search_mode = SM_READ;
	  buf = itc_reset (itc);
	  rc = itc_next (itc, &buf);
	  if (DVC_GREATER == rc || DVC_INDEX_END == rc)
	    {
	      itc_page_leave (itc, buf);
	      return IOP_AT_END;
	    }
	  break;
	case IOP_TARGET:
	  is_random = 1;
	  itc->itc_search_mode = SM_READ_EXACT;
	  rc = itc_il_search (itc, &buf, qst, &iop->iop_il, (placeholder_t*) itc,
			      0 /*!itc->itc_desc_order */
);
	  if (DVC_GREATER == rc || DVC_INDEX_END == rc)
	    {
	      itc_page_leave (itc, buf);
	      return IOP_AT_END;
	    }
	  break;
	case IOP_NEXT:
	  is_random = 0;
	  buf = page_reenter_excl (itc);
	  rc = itc_next (itc, &buf);
	  if (DVC_GREATER == rc || DVC_INDEX_END == rc)
	    {
	      itc_page_leave (itc, buf);
	      return IOP_AT_END;
	    }
	  break;
	}
      FAILCK (itc);

      if (DVC_MATCH == rc)
	{
	  itc_register (itc, buf);
	  itc_page_leave (itc, buf);
	  return IOP_ON_ROW;
	}

      switch (op)
	{
	case IOP_TARGET:
	  if (is_random)
	    {
	      if (DVC_LESS == rc)
		{
		  itc->itc_key_spec = iop->iop_ks_start_spec;
		  itc->itc_is_on_row = 1;  /* force it to go one forward */
		  rc2 = itc_next (itc, &buf);
		  if (DVC_GREATER == rc2 || DVC_INDEX_END == rc2)
		    {
		      itc_page_leave (itc, buf);
		      return IOP_AT_END;
		    }
		  if (DVC_MATCH == rc2)
		    {
		      /* the iop_out ssls are set because they are the ks:iouyt_ssls */
		      itc_register (itc, buf);
		      itc_page_leave (itc, buf);
		      return IOP_NEW_VAL;
		    }
		}
	      else
		GPF_T1 ("iop should not have dvc_les here");
	    }
	  else
	    {
	      /* serial seek to target */
	      GPF_T1 ("serial iop to target not done.");
	      if (DVC_GREATER == rc)
		{
		  /* if mismatch in given or in free parts */
		  itc->itc_key_spec = iop->iop_ks_start_spec;
		  rc2 = itc_next (itc, &buf);
		  if (DVC_GREATER == rc2)
		    {
		      itc_page_leave (itc, buf);
		      return IOP_AT_END;
		    }
		  else  if (DVC_MATCH == rc2)
		    {
		      itc_register (itc, buf);
		      itc_page_leave (itc, buf);
		      return IOP_NEW_VAL;
		    }
		  else
		    GPF_T1 ("dvc less not expected here.");
		}
	    }
	  break;
	case IOP_NEXT:
	case IOP_START:
	  itc_page_leave (itc, buf);
	  return IOP_AT_END;
	}
    }
  ITC_FAILED
    {
    }
  END_FAIL (itc);
  return 0;			/* never executed */
}


int
inx_op_and_next (inx_op_t * iop, query_instance_t * qi,
		int op, table_source_t * ts)
{
  int inx;
  int n_terms = BOX_ELEMENTS (iop->iop_terms);
  caddr_t * qst = (caddr_t *) qi;
  int rc, n_hits = 0;
  if (IOP_START == op)
    {
      DO_BOX (inx_op_t *, term, inx, iop->iop_terms)
	{
	  it_cursor_t * itc = (it_cursor_t*)QST_GET (qst, term->iop_itc);
	  if (itc)
	    {
	      itc_free_owned_params (itc);
	      itc->itc_search_par_fill = 0;
	      if (itc->itc_is_registered)
		itc_unregister (itc);
	    }
	  if (term->iop_bitmap)
	    {
	      inxop_bm_t * iob = (inxop_bm_t *) QST_GET (qst, term->iop_bitmap);
	      if (iob)
		iob->iob_is_inited = 0;
	    }
	}
      END_DO_BOX;
    }
  for (;;)
    {
      DO_BOX (inx_op_t *, term, inx, iop->iop_terms)
	{
	  rc = inxop_next (term, qi,  op, ts);
	  QST_SET (qst, term->iop_state, (ptrlong) rc);
	  switch (rc)
	    {
	    case IOP_AT_END:
	    {
	      QST_SET (qst, iop->iop_state, IOP_AT_END);
	      return rc;
	    }
	    case IOP_NEW_VAL:
	      op = IOP_TARGET;
	      n_hits = 1;
	      break;
	    case IOP_ON_ROW:
	      if (IOP_NEXT == op || IOP_START == op)
		{
		  n_hits = 1;
		  op = IOP_TARGET;
		  continue;
		}
	      n_hits++;
	      if (n_hits == n_terms)
		return  IOP_ON_ROW;
	      continue;
	    }
	}
      END_DO_BOX;
    }

  /*NOTREACHED*/
  return 0;
}



void
inx_op_source_input (table_source_t * ts, caddr_t * inst,
    caddr_t * volatile state)
{
  buffer_desc_t * main_buf;
  volatile int any_passed = 1;
  query_instance_t *qi = (query_instance_t *) inst;
  int rc, start;

  for (;;)
    {
      it_cursor_t *volatile main_itc = NULL;
      if (!state)
	{
	  start = 0;
	  state = qn_get_in_state ((data_source_t *) ts, inst);
	  if (!state)
	    return;
	}
      else
	start = 1;
      if (start)
	{
	  any_passed = 0;
	  rc = inx_op_and_next (ts->ts_inx_op, qi, IOP_START, ts);
	  if (IOP_AT_END == rc)
	    {
	      qn_record_in_state ((data_source_t *) ts, inst, NULL);
	      ts_outer_output (ts, inst);
	      return;
	    }
	  qn_record_in_state ((data_source_t *) ts, inst, state);
	}
      else
	{
	  rc = inx_op_and_next (ts->ts_inx_op, qi, IOP_NEXT, ts);
	  if (IOP_ON_ROW == rc)
	    {
	      qn_record_in_state ((data_source_t *) ts, inst, state);
	    }
	  else
	    {
	      if (!any_passed)
		ts_outer_output (ts, state);
	      return;
	    }
	}

      if (ts->ts_main_ks)
	{
	  it_cursor_t main_itc_auto;
	  int rc;
	  main_itc = &main_itc_auto;
	  ITC_INIT (main_itc, qi->qi_space, qi->qi_trx);
	  rc = ks_start_search (ts->ts_main_ks, inst, state, main_itc,
	      &main_buf, ts, SM_READ_EXACT);
	  itc_assert_lock (main_itc);
	  if (!rc)
	    {
#ifdef DEBUG
	      if (!ts->ts_main_ks->ks_row_spec &&
		  !ts->ts_main_ks->ks_local_test)
		{
		  /* no main row found, yet no special conditions on main rpw.
		     Integrity error */
		  dbg_printf (("Missed join to main row from %s\n",
		      ts->ts_order_ks->ks_key->key_name));
		}
#endif
	      state = NULL;
	      itc_free (main_itc);
	      continue;
	    }
	  else
	    {
	      /* We joined with the primary key row. */
	      ts_set_placeholder (ts, state, main_itc, &main_buf);
		itc_page_leave (main_itc, main_buf);
	      itc_free (main_itc);
	    }
	}
      if (!ts->src_gen.src_after_test
	  || code_vec_run (ts->src_gen.src_after_test, state))
	{
	  any_passed = 1;
	  qn_ts_send_output ((data_source_t *) ts, state, ts->ts_after_join_test);
	}
      state = NULL;
    }
}


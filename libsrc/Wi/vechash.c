/*
 *  vechash.c
 *
 *  $Id$
 *
 *  Vectored hash join and group by
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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
#include "sqlopcod.h"
#include "sqlopcod.h"
#include "sqlpar.h"
#include "arith.h"
#include "sqlbif.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "list2.h"
#include "date.h"
#include "xmltree.h"


typedef struct pre_hash_s
{
  int ph_n_sets;
  int ph_n_buckets;
  int *ph_distinct_rows;
  int *ph_hash;
  int *ph_buckets;
  setp_node_t *ph_setp;
  int ph_fill;
  int ph_size;
  int ph_data[1];
} pre_hash_t;


typedef struct Pre_bucket_s
{
  int pb_hash;
  int pb_next;
  int pb_row;
  int pb_more;
} pre_bucket_t;

#define PR_N_ROWS 3

typedef struct pre_rows_s
{
  int pr_next;
  int pr_row[PR_N_ROWS];
} pre_rows_t;


void
ph_init (pre_hash_t * ph, int n_sets)
{
  ph->ph_n_sets = n_sets;
  ph->ph_hash = &ph->ph_data[0];
  ph->ph_fill = sizeof (int) * n_sets;
  ph->ph_buckets = &ph->ph_data[ph->ph_fill];
  ph->ph_n_buckets = MAX (4, n_sets / 3);
  memset (ph->ph_buckets, 0xff, sizeof (int) * ph->ph_n_buckets);
  ph->ph_fill += ph->ph_n_buckets;
}


void
dc_hash (data_col_t * dc, int *hash_no, int n_sets, int allow_nulls, caddr_t * inst, ssl_index_t * steps, int n_steps)
{
  int inx, set_no, step;
  uint32 *flt, code;
  for (inx = 0; inx < n_sets; inx++)
    {
      if (-1 == hash_no[inx])
	continue;
      set_no = inx;
      for (step = 0; step < n_steps; step++)
	set_no = QST_BOX (int *, inst, steps[step])[set_no];
      if (dc->dc_nulls && DC_IS_NULL (dc, set_no))
	{
	  if (!allow_nulls)
	    hash_no[inx] = -1;
	  continue;
	}
      code = hash_no[inx];
      flt = (uint32 *) & ((int64 *) dc->dc_values)[set_no];
      if (flt[1])
	code = (code * flt[1]) ^ (code >> 23);
      else
	code = code << 2 | code >> 30;
      if (flt[0])
	code = (code * flt[0]) ^ (code >> 23);
      else
	code = code << 2 | code >> 30;
      hash_no[inx] = code;
    }
}


void
ph_add_row (pre_hash_t * ph, pre_bucket_t * pb, int row)
{
  /* pb is the right bucket. It has at least one row. If it has a next, check if full.  Else add a next in front */
  pre_rows_t *pr;
  int next = pb->pb_more, inx;
  if (next)
    {
      pr = (pre_rows_t *) & ph->ph_data[pb->pb_next];
      for (inx = 0; inx < PR_N_ROWS; inx++)
	{
	  if (-1 == pr->pr_row[inx])
	    {
	      pr->pr_row[inx] = row;
	      return;
	    }
	}
    }
  pb->pb_more = ph->ph_fill;
  pr = (pre_rows_t *) & ph->ph_data[ph->ph_fill];
  ph->ph_fill += sizeof (pre_rows_t) / sizeof (int);
  pr->pr_next = next;
  pr->pr_row[0] = row;
  for (inx = 1; inx < PR_N_ROWS; inx++)
    pr->pr_row[inx] = -1;
}


int
ph_is_hit (pre_hash_t * ph, pre_bucket_t * pb, hash_area_t * ha, caddr_t * inst, int row)
{
  int inx;
  DO_BOX (state_slot_t *, ssl, inx, ha->ha_slots)
  {
    if (inx == ha->ha_n_keys)
      break;
    if (SSL_VEC == ssl->ssl_type)
      {
	data_col_t *dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
	if (DVC_MATCH != dc->dc_sort_cmp (dc, pb->pb_row, row, row))
	  return 0;
      }
    else if (SSL_REF == ssl->ssl_type)
      {
	QNCAST (state_slot_ref_t, sslr, ssl);
	data_col_t *dc = QST_BOX (data_col_t *, inst, sslr->sslr_index);
	int set_no = row, step;
	for (step = 0; step < sslr->sslr_distance; step++)
	  set_no = QST_BOX (int *, inst, sslr->sslr_set_nos[step])[set_no];
	if (DVC_MATCH != dc->dc_sort_cmp (dc, set_no, row, row))
	  return 0;
      }
  }
  END_DO_BOX;
  return 1;
}


void
ph_fill (hash_area_t * ha, caddr_t * inst, pre_hash_t * ph, int n_rows)
{
  int inx, first;
  for (inx = 0; inx < n_rows; inx++)
    ph->ph_hash[inx] = HC_INIT;
  DO_BOX (state_slot_t *, ssl, inx, ha->ha_slots)
  {
    if (inx == ha->ha_n_keys)
      break;
    if (SSL_VEC == ssl->ssl_type)
      {
	data_col_t *dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
	dc_hash (dc, ph->ph_hash, n_rows, ha->ha_allow_nulls, inst, NULL, 0);
      }
    else if (SSL_REF == ssl->ssl_type)
      {
	QNCAST (state_slot_ref_t, sslr, ssl);
	data_col_t *dc = QST_BOX (data_col_t *, inst, sslr->sslr_index);
	dc_hash (dc, ph->ph_hash, n_rows, ha->ha_allow_nulls, inst, sslr->sslr_set_nos, sslr->sslr_distance);
      }
    else
      {
	caddr_t data = qst_get (inst, ssl);
	int r, var_len = 0;
	if (DV_DB_NULL == DV_TYPE_OF (data))
	  {
	    if (ha->ha_allow_nulls)
	      continue;

	    for (r = 0; r < n_rows; r++)
	      ph->ph_hash[r] = -1;
	    continue;
	  }
	for (r = 0; r < n_rows; r++)
	  {
	    uint32 h = key_hash_box (data, DV_TYPE_OF (data), ph->ph_hash[r], &var_len,
		ha->ha_cols[inx].cl_sqt.sqt_collation, ha->ha_cols[inx].cl_sqt.sqt_dtp, 1);
	    HASH_NUM_SAFE (h);
	    ph->ph_hash[r] = h;
	  }
      }
  }
  END_DO_BOX;
  for (inx = 0; inx < n_rows; inx++)
    {
      uint32 bucket, hash = ph->ph_hash[inx];
      if (-1 == hash)
	continue;
      bucket = hash % ph->ph_n_buckets;
      first = ph->ph_buckets[bucket];
      if (-1 == first)
	{
	  pre_bucket_t *n = (pre_bucket_t *) & ph->ph_data[ph->ph_fill];
	  ph->ph_buckets[bucket] = ph->ph_fill;
	  ph->ph_fill += sizeof (pre_bucket_t) / sizeof (int);
	  n->pb_hash = hash;
	  n->pb_row = inx;
	  n->pb_next = 0;
	}
      else
	{
	  for (;;)
	    {
	      pre_bucket_t *pb = (pre_bucket_t *) & ph->ph_data[first];
	      if (pb->pb_hash != hash || ph_is_hit (ph, pb, ha, inst, inx))
		{
		  int n = pb->pb_next;
		  if (n)
		    {
		      first = n;
		      continue;
		    }
		  pb->pb_next = ph->ph_fill;
		  pb = (pre_bucket_t *) & ph->ph_data[ph->ph_fill];
		  ph->ph_fill += sizeof (pre_bucket_t) / sizeof (int);
		  pb->pb_row = inx;
		  pb->pb_hash = hash;
		  pb->pb_next = 0;
		  goto next_row;
		}
	      /* add a row to a set of equals */
	      ph_add_row (ph, pb, inx);
	      goto next_row;
	    }
	}
    next_row:;
    }
}


void
hs_vec_outer_row (hash_source_t * hs, caddr_t * qst)
{
  int inx;
  DO_BOX (state_slot_t *, out, inx, hs->hs_out_slots)
  {
    if (SSL_VEC == out->ssl_type)
      dc_append_null (QST_BOX (data_col_t *, qst, out->ssl_index));
    else
      qst_set_bin_string (qst, out, (db_buf_t) "", 0, DV_DB_NULL);
  }
  END_DO_BOX;
}

void
ssl_array_reset (state_slot_t ** ssls, caddr_t * inst)
{
  int inx;
  DO_BOX (state_slot_t *, ssl, inx, ssls)
  {
    dc_reset (QST_BOX (data_col_t *, inst, ssl->ssl_index));
  }
  END_DO_BOX;
}


void
hash_source_vec_input_memcache (hash_source_t * hs, caddr_t * inst, caddr_t * state)
{
  QNCAST (query_instance_t, qi, inst);
  hi_memcache_key_t hmk;
  int n_sets, set;
  caddr_t hmk_data_buf[(BOX_AUTO_OVERHEAD / sizeof (caddr_t)) + 1 + MAX_STACK_N_KEYS];
  caddr_t *deps;
  int inx;
  hash_index_t *hi;
  hash_area_t *ha = hs->hs_ha;
  int n_keys = ha->ha_n_keys;
  int n_deps = ha->ha_n_deps;
  index_tree_t *it = NULL;
  it = (index_tree_t *) QST_GET_V (inst, ha->ha_tree);
  if (!it)
    return;
  if (state)
    {
      QST_INT (inst, hs->clb.clb_nth_set) = 0;
      inst[hs->hs_current_inx] = NULL;
    }
  hi = it->it_hi;
  n_sets = QST_INT (inst, hs->src_gen.src_prev->src_out_fill);
new_batch:
  set = QST_INT (inst, hs->clb.clb_nth_set);
  if (set >= n_sets)
    {
      SRC_IN_STATE (hs, inst) = NULL;
      return;
    }
  QST_INT (inst, hs->src_gen.src_out_fill) = 0;
  ssl_array_reset (hs->hs_out_slots, inst);
  for (;;)
    {
      hi_memcache_key_t *saved_hmk = NULL;
      uint32 code = HC_INIT;
      qi->qi_set = set;
      deps = (caddr_t *) inst[hs->hs_current_inx];
      if (!deps)
	{
	  BOX_AUTO ((((caddr_t *) (&(hmk.hmk_data)))[0]), hmk_data_buf, n_keys * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  inst[hs->hs_current_inx] = NULL;
	  DO_BOX (state_slot_t *, ref, inx, hs->hs_ref_slots)
	  {
	    int d = 0;
	    dtp_t dtp;
	    caddr_t k = QST_GET (inst, ref);
	    dtp = DV_TYPE_OF (k);
	    if (dtp != DV_DB_NULL && dtp != ha->ha_key_cols[inx].cl_sqt.sqt_dtp)
	      {
		k = hash_cast (qi, ha, inx, ref, k);
		dtp = DV_TYPE_OF (k);
	      }
	    code = key_hash_box (k, dtp, code, &d, ha->ha_key_cols[inx].cl_sqt.sqt_collation,
		ha->ha_key_cols[inx].cl_sqt.sqt_dtp, (HA_DISTINCT == ha->ha_op));
	    HASH_NUM_SAFE (code);
	    hmk.hmk_data[inx] = k;
	  }
	  END_DO_BOX;
	  code &= ID_HASHED_KEY_MASK;
	  hmk.hmk_hash = code;
	  hmk.hmk_ha = ha;
	  deps = (caddr_t *) id_hash_get (hi->hi_memcache, (caddr_t) (&hmk));
	  if (!deps)
	    {
	      set++;
	      goto next_set;
	    }
	  saved_hmk = (hi_memcache_key_t *) (((char *) (deps)) - hi->hi_memcache->ht_key_length);
	  inst[hs->hs_saved_hmk] = (caddr_t) saved_hmk;
	}
      else
	saved_hmk = (hi_memcache_key_t *) inst[hs->hs_saved_hmk];
      {
	caddr_t next;
	deps = (caddr_t *) (deps[0]);
	next = deps[n_deps];
	inst[hs->hs_current_inx] = next;
	DO_BOX (state_slot_t *, out, inx, hs->hs_out_slots)
	{
	  caddr_t val;
	  ptrlong col_idx = hs->hs_out_cols_indexes[inx];
	  if (col_idx >= n_keys)
	    val = deps[col_idx - n_keys];
	  else
	    val = saved_hmk->hmk_data[col_idx];
	  dc_append_box (QST_BOX (data_col_t *, inst, out->ssl_index), val);
	}
	END_DO_BOX;
	qn_result ((data_source_t *) hs, inst, set);
	if (!next)
	  set++;
	if (QST_INT (inst, hs->src_gen.src_out_fill) == dc_batch_sz)
	  {
	    SRC_IN_STATE (hs, inst) = inst;
	    QST_INT (inst, hs->clb.clb_nth_set) = set;
	    qn_send_output ((data_source_t *) hs, inst);
	    goto new_batch;
	  }
      }
    next_set:;
      if (set >= n_sets)
	break;
    }
  SRC_IN_STATE (hs, inst) = NULL;
  if (QST_INT (inst, hs->src_gen.src_out_fill))
    qn_send_output ((data_source_t *) hs, inst);
}


void
ha_fill_prehash (hash_area_t * ha, caddr_t * inst, pre_hash_t * ph, int n_sets)
{
  ph->ph_n_sets = n_sets;

}


void
hash_source_vec_input (hash_source_t * hs, caddr_t * inst, caddr_t * state)
{
  index_tree_t *it;
  hash_inx_b_ptr_t *hibp;
  int set, n_sets = QST_INT (inst, hs->src_gen.src_prev->src_out_fill);
  it_cursor_t *ref_itc;
  it_cursor_t *bp_ref_itc;
  QNCAST (query_instance_t, qi, inst);
  hash_index_t *hi;
  hash_area_t *ha = hs->hs_ha;
  if (enable_chash_join)
    {
      hash_source_chash_input (hs, inst, state);
      return;
    }
  it = (index_tree_t *) QST_GET_V (inst, ha->ha_tree);
  if (!it)
    return;
  hi = it->it_hi;
  if (hi->hi_memcache)
    {
      hash_source_vec_input_memcache (hs, inst, state);
      return;
    }

  ref_itc = (it_cursor_t *) QST_GET_V (inst, ha->ha_ref_itc);
  bp_ref_itc = (it_cursor_t *) QST_GET_V (inst, ha->ha_bp_ref_itc);
  if (!bp_ref_itc)
    {
      bp_ref_itc = itc_create (NULL, qi->qi_trx);
      itc_from_it (bp_ref_itc, it);
      qst_set (inst, ha->ha_bp_ref_itc, (caddr_t) bp_ref_itc);
    }

  if (!ref_itc)
    {
      ref_itc = itc_create (NULL, qi->qi_trx);
      itc_from_it_ha (ref_itc, (index_tree_t *) QST_GET_V (inst, ha->ha_tree), ha);
      qst_set (inst, ha->ha_ref_itc, (caddr_t) ref_itc);
    }
  if (state)
    {
      QST_INT (inst, hs->clb.clb_nth_set) = 0;
      memset (&ref_itc->itc_search_params, 0, sizeof (hash_inx_b_ptr_t));
    }
  hibp = (hash_inx_b_ptr_t *) & ref_itc->itc_search_params;

new_batch:
  QST_INT (inst, hs->src_gen.src_out_fill) = 0;
  set = QST_INT (inst, hs->clb.clb_nth_set);
  ssl_array_reset (hs->hs_out_slots, inst);
  if (set >= n_sets)
    {
      SRC_IN_STATE (hs, inst) = NULL;
      return;
    }
  for (;;)
    {
      int inx, pos = 0, rc;
      uint32 code = HC_INIT;
      buffer_desc_t *buf = NULL;
      qi->qi_set = set;
      if (!hibp->hibp_page)
	{
	  DO_BOX (state_slot_t *, ref, inx, hs->hs_ref_slots)
	  {
	    int d = 0;
	    dtp_t dtp;
	    caddr_t k = QST_GET (inst, ref);
	    dtp = DV_TYPE_OF (k);
	    if (dtp != DV_DB_NULL && dtp != ha->ha_key_cols[inx].cl_sqt.sqt_dtp)
	      {
		k = hash_cast (qi, ha, inx, ref, k);
		dtp = DV_TYPE_OF (k);
	      }
	    code = key_hash_box (k, dtp, code, &d, ha->ha_key_cols[inx].cl_sqt.sqt_collation,
		ha->ha_key_cols[inx].cl_sqt.sqt_dtp, 0);
	    HASH_NUM_SAFE (code);
	  }
	  END_DO_BOX;
	  code &= ID_HASHED_KEY_MASK;
	  hibp->hibp_no = code;
	  HI_BUCKET_PTR (hi, code, bp_ref_itc, hibp, PA_READ);
	  if (!hibp->hibp_page)
	    {
	      set++;
	      goto new_set;
	    }
	}
      else
	code = hibp->hibp_no;
      rc = itc_ha_disk_find_new (NULL, &buf, &pos, ha, inst, code, hibp->hibp_page, hibp->hibp_pos);
      if (DVC_MATCH == rc)
	{
	  dp_addr_t next_page_dp = hs->hs_is_unique ? 0 : LONG_REF (buf->bd_buffer + pos + HH_NEXT_DP - HASH_HEAD_LEN);
	  hibp->hibp_page = next_page_dp;
	  if (next_page_dp)
	    {
	      hibp->hibp_pos = SHORT_REF (buf->bd_buffer + pos + HH_NEXT_POS - HASH_HEAD_LEN) & 0x1FFF;
	      hibp->hibp_no = code;
	    }
	  ref_itc->itc_map_pos = pos;
	  ref_itc->itc_row_key = ha->ha_key;
	  ref_itc->itc_row_data = buf->bd_buffer + pos;
	  DO_BOX (state_slot_t *, out, inx, hs->hs_out_slots)
	  {
	    hs->hs_col_ref[inx] (ref_itc, buf, &hs->hs_out_cols[inx], inst, out);
	  }
	  END_DO_BOX;
	  page_leave_outside_map (ref_itc->itc_buf);
	  ref_itc->itc_buf = NULL;
	  qn_result ((data_source_t *) hs, inst, set);
	  if (!hibp->hibp_page)
	    set++;
	  if (dc_batch_sz == QST_INT (inst, hs->src_gen.src_out_fill))
	    {
	      SRC_IN_STATE (hs, inst) = inst;
	      QST_INT (inst, hs->clb.clb_nth_set) = set;
	      qn_send_output ((data_source_t *) hs, inst);
	      goto new_batch;
	    }
	}
      else
	{
	  hibp->hibp_page = 0;
	  if (ref_itc->itc_buf)
	    {
	      page_leave_outside_map (ref_itc->itc_buf);
	      ref_itc->itc_buf = NULL;
	    }
	  set++;
	}
    new_set:
      if (set >= n_sets)
	break;
    }
  SRC_IN_STATE (hs, inst) = NULL;
  if (QST_INT (inst, hs->src_gen.src_out_fill))
    qn_send_output ((data_source_t *) hs, inst);
}

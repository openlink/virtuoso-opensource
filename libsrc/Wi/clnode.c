/*
 *  clnode.c
 * 
 *  $Id$
 *
 *  Cluster versions of SQL nodes
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
#include "sqlbif.h"
#include "arith.h"
#include "eqlcomp.h"
#include "sqlfn.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlintrp.h"


#if 0
#define in_printf(a) printf a
#else
#define in_printf(a)
#endif




uint32
cp_string_hash (col_partition_t * cp, caddr_t bytes, int len, int32 * rem_ret)
{
  uint32 hash = 0;
  if (cp->cp_n_first < 0)
    {
      if (len <= -cp->cp_n_first)
	{
	  *rem_ret = -1;
	}
      else
	{
	  *rem_ret = ((-cp->cp_n_first * 8) << 24) | (SHORT_REF_NA (bytes + len - 2) & N_ONES (8 * -cp->cp_n_first));
	  len = len + cp->cp_n_first;
	}
    }
  else
    {
      *rem_ret = -1;
      if (cp->cp_n_first > 0)
	len = MIN (len, cp->cp_n_first);
    }
  BYTE_BUFFER_HASH (hash, bytes, len);
  return hash & cp->cp_mask;
}



uint32
cp_int_any_hash (col_partition_t * cp, unsigned int64 i, int32 * rem_ret)
{
  int shift;
  if (cp->cp_n_first < 0)
    {
      shift = MIN (32, -cp->cp_n_first * 8);
      *rem_ret = (shift << 24) | (i & N_ONES (shift));
      return (i >> shift) & cp->cp_mask;
    }
  else if (0 == cp->cp_n_first)
    {
      *rem_ret = -1;
      return i & cp->cp_mask;
    }
  else
    {
      shift = 8 * MAX (0, 8 - cp->cp_n_first);
      *rem_ret = -1;
      return (i >> shift) & cp->cp_mask;
    }
}


uint32
cp_double_hash (col_partition_t * cp, double d, int32 * rem_ret)
{
  /* if d is equal to some int64, then hash like this, else hash otherwise */
  char x[sizeof (double)];
  *rem_ret = -1;
  if (d > MIN_INT_DOUBLE && d < MAX_INT_DOUBLE)
    {
      double t = trunc (d);
      if (t == d)
	{
	  int64 i = (int64) d;
	  if (wi_inst.wi_master->dbs_initial_gen >= 3121)
	    return cp_int_any_hash (cp, i, rem_ret);
	  else
	    return cp_int_hash (cp, i, rem_ret);
	}
    }
  DOUBLE_TO_EXT (&x, &d);
  return cp_string_hash (cp, x, sizeof (double), rem_ret);
}


uint32
cp_numeric_hash (col_partition_t * cp, numeric_t n, int32 * rem_ret)
{
  int l;
  *rem_ret = -1;
  if (0 == n->n_scale && numeric_compare (n, num_int64_max) <= 0 && numeric_compare (n, num_int64_min) >= 0)
    {
      int64 i;
      numeric_to_int64 (n, &i);
      if (wi_inst.wi_master->dbs_initial_gen >= 3121)
	return cp_int_any_hash (cp, i, rem_ret);
      else
	return cp_int_hash (cp, i, rem_ret);
    }
  l = n->n_len + n->n_scale;
  if (l <= 15)
    {
      double d;
      numeric_to_double (n, &d);
      return cp_double_hash (cp, d, rem_ret);
    }
  return cp_string_hash (cp, (char *) &n->n_value, MAX (0, l - 2), rem_ret);
}


uint32
cp_any_hash (col_partition_t * cp, db_buf_t val, int32 * rem_ret)
{
  db_buf_t org_val;
  int is_string = 0, len, known_len = -1;
again:
  switch (val[0])
    {
    case DV_RDF:
      org_val = val;
      if (RBS_EXT_TYPE == val[1])
	return cp_int_any_hash (cp, (RBS_64 & val[1]) ? INT64_REF_NA (val + 4) : LONG_REF_NA (val + 4), rem_ret);
      rbs_hash_range (&val, &len, &is_string);
      if (is_string)
	return cp_string_hash (cp, (char *) val, len, rem_ret);
      if (wi_inst.wi_master->dbs_initial_gen >= 3120)
	{
	  /* the else branch is false but must be there for dbs partitioned wrong */
	  val = org_val + 2;	/* for non-string val, the dtp is at offset 2 */
	  known_len = -1;
	  goto again;
	}
      known_len = len;
      goto again;
    case DV_SHORT_STRING_SERIAL:
      return cp_string_hash (cp, (char *) val + 2, val[1], rem_ret);
    case DV_LONG_STRING:
      return cp_string_hash (cp, (char *) val + 5, LONG_REF_NA (val + 1), rem_ret);
    case DV_SHORT_INT:
      return cp_int_any_hash (cp, ((char *) val)[1], rem_ret);
    case DV_RDF_ID:
    case DV_IRI_ID:
    case DV_LONG_INT:
      return cp_int_any_hash (cp, LONG_REF_NA (val + 1), rem_ret);
    case DV_RDF_ID_8:
    case DV_IRI_ID_8:
    case DV_INT64:
      return cp_int_any_hash (cp, INT64_REF_NA (val + 1), rem_ret);
    case DV_DOUBLE_FLOAT:
      {
	double d;
	EXT_TO_DOUBLE (&d, val + 1);
	return cp_double_hash (cp, d, rem_ret);
      }
    case DV_SINGLE_FLOAT:
      {
	float f;
	EXT_TO_FLOAT (&f, val + 1);
	return cp_double_hash (cp, (double) f, rem_ret);
      }
    case DV_NUMERIC:
      {
	NUMERIC_VAR (num);
	numeric_from_buf ((numeric_t) num, val + 1);
	return cp_numeric_hash (cp, (numeric_t) num, rem_ret);
      }
    case DV_DB_NULL:
      *rem_ret = -1;
      return 0;
    case DV_DATETIME:
      if (wi_inst.wi_master->dbs_initial_gen >= 3120)
	return cp_string_hash (cp, (char *) val + 1, DT_COMPARE_LENGTH, rem_ret);
      /* Pre 3120 uses the dt's non comparing bits hor partition, logically equal vals would get different hashes */
    default:
      return cp_string_hash (cp, (char *) val, known_len != -1 ? known_len : box_length (val) - 1, rem_ret);
    }
}


int
clo_row_compare (cl_op_t * clo1, cl_op_t * clo2, clo_comp_t ** order)
{
  int inx;
  DO_BOX (clo_comp_t *, clo, inx, order)
  {
    caddr_t d1 = clo1->_.row.cols[clo->nth];
    caddr_t d2 = clo2->_.row.cols[clo->nth];
    dtp_t dtp1 = DV_TYPE_OF (d1);
    dtp_t dtp2 = DV_TYPE_OF (d2);
    int rc;
    if (DV_DB_NULL == dtp1 || DV_DB_NULL == dtp2)
      {
	if (DV_DB_NULL == dtp1 && DV_DB_NULL == dtp2)
	  continue;
	if (DV_DB_NULL == dtp1)
	  return DVC_LESS;
	return DVC_GREATER;
      }
    rc = cmp_boxes (d1, d2, clo->col->col_sqt.sqt_collation, clo->col->col_sqt.sqt_collation);
    if (DVC_MATCH != rc)
      return !clo->is_desc ? rc : (DVC_LESS == rc ? DVC_GREATER : DVC_LESS);
  }
  END_DO_BOX;
  return DVC_MATCH;
}

caddr_t
clo_detach_error (cl_op_t * clo)
{
  caddr_t err = clo->_.error.err;
  clo->_.error.err = NULL;
  return err;
}

void
clrg_check_trx_error (cl_req_group_t * clrg, caddr_t * err)
{
  if (!clrg->clrg_lt)
    return;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (err) && 3 <= BOX_ELEMENTS (err) && DV_STRINGP (err[1]))
    {
      if (SQLSTATE_IS_TXN (err[1]))
	{
	  lock_trx_t *lt = clrg->clrg_lt;
	  at_printf (("host %d mark lt busted because of err recd from cl\n", local_cll.cll_this_host));
	  IN_TXN;
	  ctrx_printf (("txn owner of %d:%d got a transaction aborting error %s, rb now\n", QFID_HOST (lt->lt_w_id),
		  (int) lt->lt_w_id, err[1]));
	  lt_rollback (lt, TRX_CONT);
	  LEAVE_TXN;
	}
    }
}


int n_local_rows;

cl_op_t *
clo_make_row (cll_in_box_t * clib, it_cursor_t * itc, buffer_desc_t * buf, cl_op_t * clo, int *len_ret)
{
  int inx, bytes = 11;
  cl_op_t *row = mp_clo_allocate (clib->clib_local_pool, CLO_ROW);
  int n_cols = itc->itc_out_map ? box_length (itc->itc_out_map) / sizeof (out_map_t) : 0;
  db_buf_t r = BUF_ROW (buf, itc->itc_map_pos);
  key_ver_t kv = IE_KEY_VERSION (r);
  caddr_t *cols = (caddr_t *) mp_alloc_box_ni (clib->clib_local_pool, n_cols * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  n_local_rows++;
  for (inx = 0; inx < n_cols; inx++)
    {
      out_map_t *om = &itc->itc_out_map[inx];
      if (OM_BM_COL == om->om_is_null)
	{
	  dtp_t dtp = itc->itc_insert_key->key_bit_cl->cl_sqt.sqt_dtp;
	  if (DV_IRI_ID == dtp || DV_IRI_ID_8 == dtp)
	    {
	      cols[inx] = mp_alloc_box (clib->clib_local_pool, sizeof (iri_id_t), DV_IRI_ID);
	      *(iri_id_t *) (cols[inx]) = itc->itc_bp.bp_value;
	    }
	  else
	    cols[inx] = mp_box_num (clib->clib_local_pool, itc->itc_bp.bp_value);
	}
      else if (OM_ROW == om->om_is_null)
	{
	  caddr_t _row = itc_box_row (itc, buf);
	  cols[inx] = mp_full_box_copy_tree (clib->clib_local_pool, _row);
	  dk_free_tree (_row);
	}
      else if (kv == itc->itc_insert_key->key_version)
	cols[inx] = itc_mp_box_column (itc, clib->clib_local_pool, buf, 0, &om->om_cl);
      else
	cols[inx] = itc_mp_box_column (itc, clib->clib_local_pool, buf, om->om_cl.cl_col_id, NULL);
      bytes += box_serial_length (cols[inx], 0);
    }
  row->_.row.cols = cols;
  row->clo_nth_param_row = clo->clo_nth_param_row;
  *len_ret = bytes;
  return row;
}

#define itc_cl_is_local_direct(itc) \
  (itc->itc_ks && (itc->itc_ks->ks_is_last || itc->itc_ks->ks_next_clb))

int
itc_cl_others_ready (it_cursor_t * itc)
{
  /* if reading a local itc of a cluster query, check now and then to see if should go get remote results */
  cll_in_box_t *clib = (cll_in_box_t *) itc->itc_search_params[itc->itc_search_par_fill];
  if (itc_cl_is_local_direct (itc))
    return 0;
  DO_SET (cll_in_box_t *, other, &clib->clib_group->clrg_clibs)
  {
    if (other != clib && clib_has_data (other))
      {
	itc->itc_cl_batch_done = 1;
	return 1;
      }
  }
  END_DO_SET ();
  return 0;
}




void
clo_unlink_clib (cl_op_t * clo, cll_in_box_t * clib, int is_allocd)
{
  dk_set_t *prev = &clo->clo_clibs;
  dk_set_t list = clo->clo_clibs;
  while (list)
    {
      if (list->data == (void *) clib)
	{
	  *prev = list->next;
	  if (is_allocd)
	    {
	      list->next = NULL;
	      dk_set_free (list);
	    }
	  return;
	}
      prev = &list->next;
      list = list->next;
    }
  log_error ("got the same end of set one too many times: set %d seq %d from host %d", clo->clo_nth_param_row, clo->clo_seq_no,
      clib->clib_host->ch_id);
}

int cn_ks_sets;

void
qf_select_node_input (qf_select_node_t * qfs, caddr_t * inst, caddr_t * state)
{
  /* sends a row of ssls when a qf does not end in a ts or setp */
  query_instance_t *qi = (query_instance_t *) inst;
  int batch_end = 0, inx, set_end;
  cl_op_t *qf_clo;
  cll_in_box_t *dbg_clib = NULL;
  cl_thread_t *clt = qi->qi_client->cli_clt;
  {
    /* add a local row to the local clib, if remote results ready, break the batch */
    cl_op_t *itcl_clo = (cl_op_t *) qst_get (inst, qfs->qfs_itcl);
    itc_cluster_t *itcl = itcl_clo->_.itcl.itcl;
    cll_in_box_t *clib = itcl->itcl_local_when_idle;
    int n = BOX_ELEMENTS (qfs->qfs_out_slots);
    caddr_t *row = (caddr_t *) mp_alloc_box_ni (clib->clib_local_pool, sizeof (caddr_t) * n, DV_ARRAY_OF_POINTER);
    cl_op_t *clo;
    int bytes = 11;
    dbg_clib = clib;
    for (inx = 0; inx < n; inx++)
      {
	row[inx] = mp_full_box_copy_tree (clib->clib_local_pool, qst_get (inst, qfs->qfs_out_slots[inx]));
	bytes += box_serial_length (row[inx], 0);
      }
    clo = mp_clo_allocate (clib->clib_local_pool, CLO_ROW);
    clo->_.row.cols = row;
    qf_clo = (cl_op_t *) basket_first (&clib->clib_local_clo);
    clo->clo_nth_param_row = qf_clo->clo_nth_param_row;
    clo->clo_seq_no = qf_clo->clo_seq_no;
    basket_add (&clib->clib_in_parsed, (void *) clo);
    clib->clib_local_bytes += bytes;
    clib->clib_local_bytes_cum += bytes;
    if (clib->clib_local_bytes_cum > 50000)
      {
	batch_end = 1;
	clib->clib_local_bytes = clib->clib_local_bytes_cum = 0;
      }
  }
  if (qf_clo->_.frag.max_rows)
    cn_ks_sets++;
  set_end = IS_MAX_ROWS (qf_clo->_.frag.max_rows);
  if (batch_end)
    {
      /* The qf batch is completed.  Throw with RST_ENOUGH.  Must also leave page and register itc if ts not unq */
      if (dbg_clib)
	/*cl_printf (("local batch at end %d rows\n", (int)dbg_clib->clib_in_parsed.bsk_count)) */ ;
      longjmp_splice (qi->qi_thread->thr_reset_ctx, set_end ? RST_AT_END : RST_ENOUGH);
    }
}


void
qf_resume_pending_nodes (query_frag_t * qf, caddr_t * inst, int *any_done, cl_op_t * clo)
{
  dk_set_t nodes = qf->qf_nodes;
cont_innermost_loop:
  DO_SET (data_source_t *, src, &nodes)
  {
    if (inst[src->src_in_state])
      {
	*any_done = 1;
	if (src->src_continue_reset)
	  dc_reset_array (inst, src, src->src_continue_reset, -1);
	src->src_input (src, inst, NULL);
	goto cont_innermost_loop;
      }
  }
  END_DO_SET ();
}


void
qf_set_local_save (query_frag_t * qf, caddr_t * inst)
{
  int n, inx;
  if (!qf->qf_local_save)
    return;
  n = BOX_ELEMENTS (qf->qf_local_save);
  for (inx = 0; inx < n; inx += 2)
    qst_set_over (inst, qf->qf_local_save[inx + 1], qst_get (inst, qf->qf_local_save[inx]));
}


void
qf_restore_local_save (query_frag_t * qf, caddr_t * inst)
{
  int n, inx;
  if (!qf->qf_local_save)
    return;
  n = BOX_ELEMENTS (qf->qf_local_save);
  for (inx = 0; inx < n; inx += 2)
    qst_set_over (inst, qf->qf_local_save[inx], qst_get (inst, qf->qf_local_save[inx + 1]));
}

void
qf_anytime (cl_op_t * clo, cll_in_box_t * clib, caddr_t err)
{
  /* when anytime interrupt, add an error at the end or a agg end if non-dfg aggregate */
  query_frag_t *qf = clo->_.frag.qf;
  caddr_t *inst = clo->_.frag.qst;
  QNCAST (query_instance_t, qi, inst);
  qi->qi_client->cli_activity.da_anytime_result = 1;
  if (qf->qf_is_agg && !qf->qf_n_stages)
    {
      cl_op_t *end = mp_clo_allocate (clib->clib_local_pool, CLO_AGG_END);
      dk_free_tree (err);
      end->clo_nth_param_row = clo->clo_nth_param_row;
      basket_add (&clib->clib_in_parsed, (void *) end);
    }
  else
    {
      cl_op_t *end = mp_clo_allocate (clib->clib_local_pool, CLO_ERROR);
      end->clo_nth_param_row = clo->clo_nth_param_row;
      end->_.error.err = err;
      basket_add (&clib->clib_in_parsed, (void *) end);
    }
}


void
qf_handle_reset (cl_op_t * clo, query_instance_t * qi, cll_in_box_t * clib, int reset_code)
{
  caddr_t err;
  QI_CHECK_ANYTIME_RST (qi, reset_code);
  switch (reset_code)
    {
    case RST_ENOUGH:
    case RST_AT_END:
      {
	query_frag_t *qf = clo->_.frag.qf;
	qf_set_local_save (qf, (caddr_t *) qi);
	return;
      }
    case RST_ERROR:
      err = thr_get_error_code (qi->qi_thread);
      if (err_is_anytime (err))
	{
	  qf_anytime (clo, clib, err);
	  return;
	}
      sqlr_resignal (err);
    case RST_KILLED:
      err = srv_make_new_error ("HY008", "SR189", "Async statement killed by SQLCancel.");
      sqlr_resignal (err);
    case RST_DEADLOCK:
      {
	int trx_code = qi->qi_trx->lt_error;
	SEND_TRX_ERROR_CALLER (err, qi->qi_caller, trx_code, LT_ERROR_DETAIL (qi->qi_trx));
	sqlr_resignal (err);
      }
    }
}


void
clib_local_qf_next (cll_in_box_t * clib)
{
}

void
clib_local_next (cll_in_box_t * clib)
{
  /* read some from the local itc or qf  and put results in the clib out box */
  int rc, batch_end = 0;
  cl_op_t *clo;
  buffer_desc_t *buf;
  it_cursor_t *itc;
  clib->clib_local_bytes = 0;
  if (clib->clib_in_parsed.bsk_count)
    GPF_T1 ("do not get next local batch before the prev is out");
  if (clib->clib_local_pool)
    mp_free (clib->clib_local_pool);
  clib->clib_local_pool = mem_pool_alloc ();
next_set:
  clo = (cl_op_t *) basket_first (&clib->clib_local_clo);
  if (CLO_QF_EXEC == clo->clo_op)
    {
      clib_local_qf_next (clib);
      return;
    }
  if (clo->_.select.is_null_join)
    goto end_of_set;
  itc = clo->_.select.itc;
  ITC_FAIL (itc)
  {
    if (clo->_.select.is_started)
      buf = page_reenter_excl (itc);
    else
      {
	itc->itc_search_par_fill = BOX_ELEMENTS ((caddr_t) clo->_.select.local_params);
	memcpy (&itc->itc_search_params, clo->_.select.local_params, itc->itc_search_par_fill * sizeof (caddr_t));
	itc->itc_key_spec = itc->itc_ks->ks_spec;	/* set here every time, bm inx select will change itc_key_spec */
	itc->itc_desc_order = itc->itc_ks->ks_descending;
	itc->itc_search_params[itc->itc_search_par_fill] = (caddr_t) clib;
	itc->itc_search_params[itc->itc_search_par_fill + 1] = (caddr_t) clo;
	buf = itc_reset (itc);
	clo->_.select.is_started = 1;
      }
    itc->itc_cl_batch_done = 0;
    while (DVC_MATCH == (rc = itc_next (itc, &buf)))
      {
	if (itc->itc_ks->ks_ts->ts_is_unique || itc->itc_cl_set_done)
	  break;
	if (itc->itc_cl_batch_done)
	  {
	    itc_register (itc, buf);
	    batch_end = 1;
	    break;
	  }
      }
    itc_page_leave (itc, buf);
    if (!batch_end)
      {
      end_of_set:
	if (itc_cl_is_local_direct (itc))
	  {
	    clo_unlink_clib (clo, clib, 0);
	    if (!clo->clo_clibs)
	      {
		itc_cluster_t *itcl = ((cl_op_t *) QST_GET_V (itc->itc_out_state, itc->itc_ks->ks_itcl))->_.itcl.itcl;
		itcl->itcl_nth_set++;
	      }
	  }
	else
	  {
	    cl_op_t *end = mp_clo_allocate (clib->clib_local_pool, CLO_SET_END);
	    end->clo_nth_param_row = clo->clo_nth_param_row;
	    basket_add (&clib->clib_in_parsed, (void *) end);
	    clo->_.select.itc = NULL;
	  }
	itc->itc_cl_set_done = 0;
	clib->clib_n_selects_received++;
	basket_get (&clib->clib_local_clo);	/* gets freed with the params of the ts */
	clo = (cl_op_t *) basket_first (&clib->clib_local_clo);
	if (clo)
	  goto next_set;
	return;			/* no end fail, itc freed */
      }
    else
      {
	if (!itc_cl_is_local_direct (itc))
	  {
	    cl_op_t *end = mp_clo_allocate (clib->clib_local_pool, CLO_BATCH_END);
	    end->clo_nth_param_row = clo->clo_nth_param_row;
	    basket_add (&clib->clib_in_parsed, (void *) end);
	  }
	return;
      }
  }
  ITC_FAILED
  {
  }
  END_FAIL (itc);
}

void
cl_row_set_out_cols (dk_set_t slots, caddr_t * inst, cl_op_t * clo)
{
  int inx = 0;
  DO_SET (state_slot_t *, ssl, &slots)
  {
    qst_set_over (inst, ssl, clo->_.row.cols[inx]);
    inx++;
  }
  END_DO_SET ();
}



cl_op_t *
itcl_next (itc_cluster_t * itcl)
{
  cl_op_t *first = NULL;
  cll_in_box_t *first_clib = NULL;

  int less = itcl->itcl_desc_order ? DVC_GREATER : DVC_LESS;
  if (itcl->itcl_last_returned)
    {
      cll_in_box_t *last_clib = itcl->itcl_last_returned;
      clib_read_next (last_clib, NULL, NULL);
      last_clib->clib_rows_done++;
      if (last_clib->clib_host->ch_id != local_cll.cll_this_host
	  && last_clib->clib_row_low_water > 0
	  && last_clib->clib_rows_done > last_clib->clib_row_low_water
	  && last_clib->clib_batches_requested - last_clib->clib_batches_received < 2 && last_clib->clib_res_type != CM_RES_FINAL)
	{
	  cl_printf (("Low water on %d, %d rows done\n", last_clib->clib_host->ch_id, last_clib->clib_rows_done));
	  clib_more (last_clib);
	}
    }
  itcl->itcl_last_returned = NULL;

  DO_SET (cll_in_box_t *, clib, &itcl->itcl_clrg->clrg_clibs)
  {
    cl_op_t *clo;
    if (!clib->clib_waiting)
      continue;
    for (;;)
      {
	clo = clib_first (clib);
	if (clo)
	  break;
      }
    if (CLO_ERROR == clo->clo_op)
      sqlr_resignal (clo_detach_error (clo));
    if (CLO_ROW != clo->clo_op)
      continue;
    if (!first || less == clo_row_compare (clo, first, itcl->itcl_order))
      {
	first = clo;
	first_clib = clib;
      }
  }
  END_DO_SET ();
  itcl->itcl_last_returned = first_clib;
  return first;
}

cll_in_box_t *
itcl_local_start (itc_cluster_t * itcl)
{
  /* when a clrg has started for queries remote queries, run local ones for a similar batch worth./
   * Also set the dks_qi_data needed for receiving xml from any of the clibs, so run through them all */
  cl_req_group_t *clrg = itcl->itcl_clrg;
  cll_in_box_t *ret = NULL;
  QNCAST (query_instance_t, qi, itcl->itcl_qst);
  qi = qi_top_qi (qi);
  DO_SET (cll_in_box_t *, clib, &clrg->clrg_clibs)
  {
    DKS_QI_DATA (&clib->clib_in_strses) = qi;
    if (clib->clib_host->ch_id == local_cll.cll_this_host)
      {
	if (itcl)
	  itcl->itcl_local_when_idle = clib;
	clib_more (clib);
	ret = clib;
      }
  }
  END_DO_SET ();
  return ret;
}

int set_ctr;



void
cl_node_init (table_source_t * ts, caddr_t * inst)
{
  if (!IS_CL_NODE (ts))
    return;
  SRC_IN_STATE ((data_source_t *) ts, inst) = NULL;
  if (IS_TS (ts) && !ts->clb.clb_fill)
    return;
  if (ts->clb.clb_itcl && !ts->clb.clb_keep_itcl_after_end)
    qst_set (inst, ts->clb.clb_itcl, NULL);
  if (ts->clb.clb_clrg)
    qst_set (inst, ts->clb.clb_clrg, NULL);
  if ((qn_input_fn) fun_ref_node_input == ts->src_gen.src_input)
    {
      QNCAST (fun_ref_node_t, fref, ts);
      if (fref->fnr_cl_state)
	{
	  QST_INT (inst, fref->fnr_cl_state) = FNR_NONE;
	  qst_set (inst, fref->fnr_ssa.ssa_array, NULL);
	  qst_set_long (inst, fref->fnr_ssa.ssa_current_set, 0);
	}
    }
  if ((qn_input_fn) code_node_input == ts->src_gen.src_input)
    {
      QNCAST (code_node_t, cn, ts);
      DO_SET (instruction_t *, ins, &cn->cn_continuable)
      {
	query_t *qr = INS_QUERY (ins);
	subq_init (qr, inst);
      }
      END_DO_SET ();
    }
  if ((qn_input_fn) query_frag_input == ts->src_gen.src_input)
    {
      QNCAST (query_frag_t, qf, ts);
      if (qf->qf_n_stages || qf->qf_is_agg)
	{
	  DO_SET (stage_node_t *, stn, &qf->qf_nodes)
	  {
	    if (IS_STN (stn))
	      cl_node_init ((table_source_t *) stn, inst);
	    else if (IS_QN (stn, ssa_iter_input))
	      {
		QNCAST (ssa_iter_node_t, ssi, stn);
		QST_INT (inst, ssi->ssi_state) = 0;
		qst_set (inst, ssi->ssi_setp->setp_ssa.ssa_array, NULL);
		qst_set (inst, ssi->ssi_setp->setp_ssa.ssa_current_set, 0);
	      }
	    else if (IS_QN (stn, setp_node_input))
	      {
		QNCAST (setp_node_t, setp, stn);
		setp_temp_clear (setp, setp->setp_ha, inst);
	      }
	    else if (IS_TS (stn))
	      {
		QNCAST (table_source_t, ts, stn);
		if (ts->ts_order_ks && ts->ts_order_ks->ks_setp)
		  setp_temp_clear (ts->ts_order_ks->ks_setp, ts->ts_order_ks->ks_setp->setp_ha, inst);
	      }
	  }
	  END_DO_SET ();
	}
    }
}

int
itc_rd_cluster_blobs (it_cursor_t * itc, row_delta_t * rd)
{
  /* if there is a blob handle to be had from cluster, get it here  and make the blob */
  DO_CL (cl, itc->itc_insert_key->key_row_var)
  {
    if (IS_BLOB_DTP (cl->cl_sqt.sqt_dtp))
      {
	caddr_t data = rd->rd_values[cl->cl_nth];
	blob_handle_t *bh = (blob_handle_t *) data;
	/* if this is a blob handle or if blobs were not made when reading the rd, make the blob now */
	if (IS_BLOB_HANDLE_DTP (DV_TYPE_OF (data)))
	  {
	    char str[DV_BLOB_LEN + 1];
	    int rc = itc_set_blob_col (itc, (db_buf_t) str, (caddr_t) bh, NULL, BLOB_IN_INSERT, &cl->cl_sqt);
	    if (LTE_OK != rc)
	      {
		return rc;
	      }
	    dk_free_box (data);
	    data = dk_alloc_box (DV_BLOB_LEN + 1, DV_STRING);
	    memcpy (data, &str[0], DV_BLOB_LEN);
	    str[DV_BLOB_LEN] = 0;
	    rd->rd_values[cl->cl_nth] = data;
	  }
      }
  }
  END_DO_CL;
  return LTE_OK;
  return LTE_OK;
}


int
itc_insert_rd (it_cursor_t * itc, row_delta_t * rd, buffer_desc_t ** unq_buf)
{
  int inx;
  dbe_key_t *key = itc->itc_insert_key;
  itc_from (itc, itc->itc_insert_key);
  for (inx = 0; inx < key->key_n_significant; inx++)
    ITC_SEARCH_PARAM (itc, rd->rd_values[key->key_part_in_layout_order[inx]]);
  if (key->key_is_bitmap)
    {
      ITC_SAVE_FAIL (itc);
      key_bm_insert (itc, rd);
      ITC_RESTORE_FAIL (itc);
      return DVC_LESS;
    }
  else
    {
      itc->itc_key_spec = itc->itc_insert_key->key_insert_spec;
      if (itc->itc_insert_key->key_table->tb_any_blobs)
	itc_rd_cluster_blobs (itc, rd);
      return itc_insert_unq_ck (itc, rd, unq_buf);
    }
}

void
itc_delete_rd (it_cursor_t * itc, row_delta_t * rd)
{
  buffer_desc_t *buf;
  int inx, rc;
  dbe_key_t *key = itc->itc_insert_key;
  itc_from (itc, itc->itc_insert_key);
  for (inx = 0; inx < key->key_n_significant; inx++)
    ITC_SEARCH_PARAM (itc, rd->rd_values[key->key_part_in_layout_order[inx]]);
  itc->itc_search_mode = SM_INSERT;
  itc->itc_key_spec = key->key_insert_spec;
  itc->itc_lock_mode = PL_EXCLUSIVE;
  buf = itc_reset (itc);
  rc = itc_search (itc, &buf);
  if (rc == DVC_MATCH)
    {
      itc->itc_is_on_row = 1;
      itc_set_lock_on_row (itc, &buf);
      if (!itc->itc_is_on_row)
	{
	  if (itc->itc_ltrx)
	    itc->itc_ltrx->lt_error = LTE_DEADLOCK;
	  /* not really, but just put something there. */
	  itc_bust_this_trx (itc, &buf, ITC_BUST_THROW);
	}
      itc->itc_is_on_row = 1;	/* flag not set in SM_INSERT search */
      itc_delete (itc, &buf, NO_BLOBS);
      itc_page_leave (itc, buf);
      log_delete (itc->itc_ltrx, rd, LOG_KEY_ONLY);
    }
  else
    itc_page_leave (itc, buf);
}

void
rd_free_temp_blobs (row_delta_t * rd, lock_trx_t * lt, int is_local)
{
  /* an rd gets made here wit blobs but does not get stored here.  Blobs away after the clo is sent to recipients.  Also not logged here.  Set the send flag to deflt for cluster blobs.  */
  it_cursor_t itc_auto;
  it_cursor_t *itc = &itc_auto;
  int inx;
  for (inx = 0; inx < rd->rd_n_values; inx++)
    {
      if (rd_is_blob (rd, inx))
	{
	  caddr_t str = rd->rd_values[inx];
	  dtp_t dtp = DV_TYPE_OF (str);
	  if (IS_BLOB_HANDLE_DTP (dtp))
	    ((blob_handle_t *) str)->bh_send_as_bh = 0;
	  else if (DV_STRING == dtp && IS_BLOB_DTP ((dtp_t) (str[0])) && !is_local)
	    {
	      blob_layout_t *bl = bl_from_dv_it ((db_buf_t) str, rd->rd_key->key_fragments[0]->kf_it);
	      blob_log_set_delete (&lt->lt_blob_log, LONG_REF_NA (str + BL_DP));
	      ITC_INIT (itc, NULL, lt);
	      itc_from (itc, rd->rd_key);
	      blob_schedule_delayed_delete (itc, bl, BL_DELETE_AT_COMMIT | BL_DELETE_AT_ROLLBACK);
	    }
	}
    }
}

#define INS_DUP 2

void
cl_local_insert (caddr_t * inst, cl_op_t * clo)
{
  query_instance_t *qi = (query_instance_t *) inst;
  buffer_desc_t *buf = NULL, **unq_buf = NULL;
  row_delta_t *volatile rd = clo->_.insert.rd;
  it_cursor_t itc_auto;
  it_cursor_t *itc = &itc_auto;
  ITC_INIT (itc, NULL, qi->qi_trx);
  itc_from (itc, rd->rd_key);
  if (INS_NORMAL != clo->_.insert.ins_mode)
    unq_buf = &buf;
  log_insert (itc->itc_ltrx, rd, LOG_KEY_ONLY | clo->_.insert.ins_mode);
  ITC_FAIL (itc)
  {
    int rc = itc_insert_rd (itc, rd, unq_buf);
    itc_free_owned_params (itc);
    rd->rd_itc = NULL;
    clo->_.insert.ins_result = rc;
    if (DVC_MATCH == rc)
      {
	if (INS_REPLACING == clo->_.insert.ins_mode)
	  {
	    cl_op_t *decoy = clo_allocate (CLO_INSERT);
	    NEW_VARZ (row_delta_t, prev_rd);
	    prev_rd->rd_allocated = RD_ALLOCATED;
	    page_row (buf, itc->itc_map_pos, prev_rd, RO_ROW);
	    itc_set_lock_on_row (itc, &buf);
	    if (!itc->itc_is_on_row)
	      GPF_T1 ("in insert replacing, setting the lock is supposed to be possible since insert already checked the lock");
	    lt_rb_update (itc->itc_ltrx, buf, BUF_ROW (buf, itc->itc_map_pos));
	    itc_delete_blobs (itc, buf);
	    upd_refit_row (itc, &buf, rd, RD_UPDATE);
	    clo->_.insert.prev_rd = prev_rd;
	    decoy->_.insert.rd = prev_rd;
	    mp_trash (clo->clo_pool, (caddr_t) decoy);
	  }
	else
	  {
	    clo->_.insert.is_local = INS_DUP;
	    itc_page_leave (itc, buf);
	  }
      }
  }
  ITC_FAILED
  {
    rd->rd_itc = NULL;
    itc_free_owned_params (itc);
    return;			/* no resignal */
  }
  END_FAIL (itc);
}


void
cl_local_delete (caddr_t * inst, cl_op_t * clo)
{
  query_instance_t *qi = (query_instance_t *) inst;
  it_cursor_t itc_auto;
  it_cursor_t *itc = &itc_auto;
  ITC_INIT (itc, NULL, qi->qi_trx);
  itc->itc_insert_key = clo->_.delete.rd->rd_key;
  ITC_FAIL (itc)
  {
    itc_delete_rd (itc, clo->_.delete.rd);
  }
  ITC_FAILED
  {
    itc_free (itc);
  }
  END_FAIL (itc);
}


void
cl_qi_count_affected (query_instance_t * qi, cl_req_group_t * clrg)
{
  DO_SET (cll_in_box_t *, clib, &clrg->clrg_clibs)
  {
    if (!clib->clib_is_update_replica)
      qi->qi_n_affected += clib->clib_n_affected;
  }
  END_DO_SET ();
}

void
dpipe_node_input (dpipe_node_t * dp, caddr_t * inst, caddr_t * state)
{
  if (dp->dp_is_colocated)
    {
      dpipe_node_local_input (dp, inst, state);
      return;
    }
}

caddr_t
cl_ddl (query_instance_t * qi, lock_trx_t * lt, caddr_t name, int type, caddr_t trig_table)
{
  return NULL;
}


void
query_frag_input (query_frag_t * qf, caddr_t * inst, caddr_t * state)
{
  GPF_T;
}

void
lt_expedite_1pc (lock_trx_t * lt)
{
  GPF_T;
}

void
cl_ts_set_context (table_source_t * ts, itc_cluster_t * itcl, caddr_t * inst, int nth_set)
{
  int inx;
  caddr_t *row = ((caddr_t **) itcl->itcl_param_rows)[nth_set];
  DO_BOX (state_slot_t *, ssl, inx, ts->clb.clb_save)
  {
    qst_set_over (inst, ssl, row[inx + 1]);
  }
  END_DO_BOX;
  if (ts->clb.clb_nth_context)
    QST_INT (inst, ts->clb.clb_nth_context) = nth_set;
}

itc_cluster_t *
itcl_allocate (lock_trx_t * lt, caddr_t * inst)
{
  NEW_VARZ (itc_cluster_t, itcl);
  itcl->itcl_qst = inst;
  itcl->itcl_pool = mem_pool_alloc ();
  return itcl;
}

#define CL_INIT_BATCH_SIZE 100

void
cl_select_save_env (table_source_t * ts, itc_cluster_t * itcl, caddr_t * inst, cl_op_t * clo, int nth)
{
  caddr_t **array = (caddr_t **) itcl->itcl_param_rows;
  caddr_t *row;
  int inx, n_save;
  if (!array)
    {
      itcl->itcl_param_rows = (cl_op_t ***) (array =
	  (caddr_t **) mp_alloc_box_ni (itcl->itcl_pool, CL_INIT_BATCH_SIZE * sizeof (caddr_t), DV_ARRAY_OF_POINTER));
    }
  else if (BOX_ELEMENTS (array) <= nth)
    {
      caddr_t new_array = mp_alloc_box_ni (itcl->itcl_pool, ts->clb.clb_batch_size * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      memcpy (new_array, array, box_length (array));
      itcl->itcl_param_rows = (cl_op_t ***) (array = (caddr_t **) new_array);
    }
  n_save = ts->clb.clb_save ? BOX_ELEMENTS (ts->clb.clb_save) : 0;
  row = (caddr_t *) mp_alloc_box_ni (itcl->itcl_pool, sizeof (caddr_t) * (1 + n_save), DV_ARRAY_OF_POINTER);
  row[0] = (caddr_t) clo;
  if (n_save)
    {
      DO_BOX (state_slot_t *, ssl, inx, ts->clb.clb_save)
      {
	row[inx + 1] = mp_full_box_copy_tree (itcl->itcl_pool, qst_get (inst, ssl));
      }
      END_DO_BOX;
    }
  array[nth] = row;
  if (ts->clb.clb_nth_context)
    QST_INT (inst, ts->clb.clb_nth_context) = -1;
}

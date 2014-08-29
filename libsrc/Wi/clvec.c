/*
 *  clvec.c
 *
 *  $Id$
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
#include "sqlbif.h"
#include "arith.h"
#include "eqlcomp.h"
#include "sqlfn.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "datesupp.h"

int enable_ksp_fast = 1;



caddr_t
box_deserialize_xml (db_buf_t dv, caddr_t * inst)
{
  scheduler_io_data_t iod;
  dk_session_t ses;
  memset (&ses, 0, sizeof (ses));
  memset (&iod, 0, sizeof (iod));
  ses.dks_in_buffer = (caddr_t) dv;
  ses.dks_in_fill = INT32_MAX;
  SESSION_SCH_DATA ((&ses)) = &iod;
  DKS_QI_DATA (&ses) = (QI *) inst;
  return (caddr_t) read_object (&ses);
}


#define dc_dtp_elt_size(dtp)  \
  (DV_SINGLE_FLOAT == dtp ? 4 : DV_DATETIME == dtp ? DT_LENGTH : 8)

caddr_t
dre_box (dc_read_t * dre, caddr_t reuse, caddr_t * inst)
{
  if (DV_ANY == dre->dre_dtp || (DCT_BOXES & dre->dre_type))
    {
      int l;
      DB_BUF_TLEN (l, dre->dre_data[0], dre->dre_data);
      if (DV_XML_ENTITY == dre->dre_data[0])
	{
	  dk_free_tree (reuse);
	  reuse = box_deserialize_xml (dre->dre_data, inst);
	}
      else
	reuse = box_deserialize_reusing (dre->dre_data, reuse);
      dre->dre_data += l;
      dre->dre_pos++;
      return reuse;
    }
  if (dre->dre_any_null && BIT_IS_SET (dre->dre_nulls, dre->dre_pos))
    {
      if (!IS_BOX_POINTER (reuse) || DV_DB_NULL != box_tag (reuse))
	{
	  dk_free_tree (reuse);
	  reuse = dk_alloc_box (0, DV_DB_NULL);
	}
      dre->dre_pos++;
      dre->dre_data += dc_dtp_elt_size (dre->dre_dtp);
      return reuse;
    }
  dre->dre_pos++;
  switch (dre->dre_dtp)
    {
    case DV_LONG_INT:
    case DV_IRI_ID:
    case DV_IRI_ID_8:
    case DV_DOUBLE_FLOAT:
      if (!IS_BOX_POINTER (reuse) || dre->dre_dtp != box_tag (reuse))
	{
	  dk_free_tree (reuse);
	  reuse = dk_alloc_box (8, dre->dre_dtp);
	}
      *(int64 *) reuse = INT64_REF_CA (dre->dre_data);
      dre->dre_data += 8;
      return reuse;
    case DV_SINGLE_FLOAT:
      if (!IS_BOX_POINTER (reuse) || dre->dre_dtp != box_tag (reuse))
	{
	  dk_free_tree (reuse);
	  reuse = dk_alloc_box (8, dre->dre_dtp);
	}
      *(int32 *) reuse = LONG_REF_CA (dre->dre_data);
      dre->dre_data += 4;
      return reuse;
    case DV_DATETIME:
      if (!IS_BOX_POINTER (reuse) || DV_DATETIME != box_tag (reuse))
	{
	  dk_free_box (reuse);
	  reuse = dk_alloc_box (DT_LENGTH, DV_DATETIME);
	}
      memcpy_dt (reuse, dre->dre_data);
      dre->dre_data += DT_LENGTH;
      return reuse;
    }
  GPF_T;
  return NULL;
}


void
clib_vec_read_into_clo (cll_in_box_t * clib)
{
  int len = clib->clib_n_dcs, inx;
  caddr_t *row;
  caddr_t *inst = clib->clib_group->clrg_inst;
  row = clib->clib_first._.row.cols = clib->clib_first_row;
  if (!row)
    row = clib->clib_first._.row.cols = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t) * clib->clib_n_dcs, DV_ARRAY_OF_POINTER);
  for (inx = 0; inx < len; inx++)
    row[inx] = dre_box (&clib->clib_dc_read[inx], row[inx], inst);
}


void
dc_any_trap (db_buf_t dv)
{
  if (DV_DATETIME == dv[0] && 11 == dv[1] && 48 == dv[2] && 37 == dv[3] && 23 == dv[4])
    bing ();
}

void
clib_vec_read_into_slots (cll_in_box_t * clib, caddr_t * inst, dk_set_t slots)
{
  int inx = 0, l;
  int64 i;
  itc_cluster_t *itcl = clib->clib_group ? clib->clib_group->clrg_itcl : clib->clib_itcl;
  int row, n_rows = itcl->itcl_batch_size - itcl->itcl_n_results;
  int n_avail = clib->clib_dc_read[0].dre_n_values - clib->clib_dc_read[0].dre_pos;
  int dc_fill, dre_pos;
  n_rows = MIN (n_rows, n_avail);
  clib->clib_first._.row.cols = NULL;	/* for safety when freeing */
  DO_SET (state_slot_t *, ssl, &slots)
  {
    data_col_t *dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
    dc_read_t *dre = &clib->clib_dc_read[inx];
    if (!inx)
      {
	dre_pos = dre->dre_pos;
	dc_fill = dc->dc_n_values;
      }
    else if (dre_pos != dre_pos || dc_fill != dc->dc_n_values)
      GPF_T1 ("reading clib into slits, uneven dc length or dre pos");
    if (!itcl->itcl_n_results)
      DC_CHECK_LEN (dc, n_rows - 1);
    if (DV_ANY == ssl->ssl_sqt.sqt_dtp)
      {
	if (0 == dc->dc_n_values && dc->dc_dtp != dre->dre_dtp)
	  dc_convert_empty (dc, dre->dre_dtp);
	if (dc->dc_dtp != dre->dre_dtp && DV_ANY != dc->dc_dtp)
	  dc_heterogenous (dc);
      }
    if (DCT_BOXES & dc->dc_type)
      {
	for (row = 0; row < n_rows; row++)
	  {
	    db_buf_t dv = dre->dre_data;
	    DB_BUF_TLEN (l, *dv, dv);
	    if (DV_DB_NULL == dv[0])
	      {
		((caddr_t *) dc->dc_values)[dc->dc_n_values++] = dk_alloc_box (0, DV_DB_NULL);
		dc->dc_any_null = 1;
	      }
	    else if (DV_XML_ENTITY == dv[0])
	      ((caddr_t *) dc->dc_values)[dc->dc_n_values++] = box_deserialize_xml (dv, clib->clib_group->clrg_inst);
	    else
	      ((caddr_t *) dc->dc_values)[dc->dc_n_values++] = box_deserialize_string ((caddr_t) dv, l, 0);
	    dre->dre_data += l;
	  }
      }
    else if (DV_ANY == dc->dc_dtp)
      {
	if (DV_ANY == dre->dre_dtp)
	  {
	    for (row = 0; row < n_rows; row++)
	      {
		db_buf_t dv = dre->dre_data;
		DB_BUF_TLEN (l, *dv, dv);
		if (DV_DB_NULL == *dv)
		  dc->dc_any_null = 1;
		/*dc_any_trap  (dv); */
		dc_append_bytes (dc, dv, l, NULL, 0);
		dre->dre_data += l;
	      }
	  }
	else
	  {
	    dtp_t tmp[20];
	    dtp_t nu = DV_DB_NULL;
	    for (row = 0; row < n_rows; row++)
	      {
		if (dre->dre_nulls && BIT_IS_SET (dre->dre_nulls, dre->dre_pos + row))
		  dc_append_bytes (dc, &nu, 1, NULL, 0);
		else
		  {
		    switch (dre->dre_dtp)
		      {
		      case DV_LONG_INT:
			i = INT64_REF_CA (dre->dre_data);
			dv_from_int (tmp, i);
			dre->dre_data += 8;
			dc_append_bytes (dc, tmp, db_buf_const_length[tmp[0]], NULL, 0);
			break;
		      case DV_IRI_ID:
			i = INT64_REF_CA (dre->dre_data);
			dv_from_iri (tmp, i);
			dre->dre_data += 8;
			dc_append_bytes (dc, tmp, db_buf_const_length[tmp[0]], NULL, 0);
			break;
		      case DV_DOUBLE_FLOAT:
			EXT_TO_DOUBLE (tmp, dre->dre_data);
			dc_append_bytes (dc, tmp, 8, &dre->dre_dtp, 1);
			dre->dre_data += 8;
			break;
		      case DV_SINGLE_FLOAT:
			EXT_TO_FLOAT (tmp, dre->dre_data);
			dc_append_bytes (dc, tmp, 4, &dre->dre_dtp, 1);
			dre->dre_data += 4;
			break;
		      case DV_DATETIME:
			dc_append_bytes (dc, dre->dre_data, DT_LENGTH, &dre->dre_dtp, 1);
			dre->dre_data += DT_LENGTH;
			break;
		      default:
			GPF_T1 ("recd unknown typed dc");
		      }
		  }
	      }
	  }
      }
    else
      {
	int elt_sz = dc_dtp_elt_size (dre->dre_dtp);
	int pos = dre->dre_pos;
	if (dtp_canonical[dre->dre_dtp] != dtp_canonical[dc->dc_dtp])
	  {
	    log_error ("receiving dre dtp %d for dc dtp %d ssl %d, indicates bad plan, should report query to support",
		dre->dre_dtp, dc->dc_dtp, ssl->ssl_index);
	    sqlr_new_error ("CLVEC", "MSDTP",
		"receiving dre dtp %d for dc dtp %d ssl %d, indicates bad plan, should report query to support", dre->dre_dtp,
		dc->dc_dtp, ssl->ssl_index);
	  }
	DC_CHECK_LEN (dc, dc->dc_n_values + n_rows - 1);
	memcpy_16 (dc->dc_values + dc->dc_n_values * elt_sz, dre->dre_data, elt_sz * n_rows);
	dre->dre_data += elt_sz * n_rows;
	if (!dre->dre_any_null && dc->dc_nulls)
	  {
	    for (row = 0; row < n_rows; row++)
	      BIT_CLR (dc->dc_nulls, dc->dc_n_values + row);
	  }
	else if (dre->dre_any_null)
	  {
	    if (!dc->dc_nulls)
	      dc_ensure_null_bits (dc);
	    for (row = 0; row < n_rows; row++)
	      {
		if (BIT_IS_SET (dre->dre_nulls, row + pos))
		  {
		    BIT_SET (dc->dc_nulls, dc->dc_n_values + row);
		  }
		else
		  BIT_CLR (dc->dc_nulls, dc->dc_n_values + row);
	      }
	    dc->dc_any_null = 1;
	  }
	dc->dc_n_values += n_rows;
      }
    dre->dre_pos += n_rows;
    inx++;
  }
  END_DO_SET ();
  clib->clib_first._.row.nth_val += n_rows;
  itcl->itcl_n_results += n_rows;
  clib->clib_rows_done += n_rows - 1;	/* caller increments one more time */
}


void
cl_row_append_out_cols (itc_cluster_t * itcl, caddr_t * inst, cl_op_t * clo)
{
  dk_set_t slots = itcl->itcl_out_slots;
  int n_rows = itcl->itcl_batch_size - itcl->itcl_n_results;
  int n_avail = clo->_.row.n_rows - clo->_.row.nth_val;
  int inx = 0;
  int first_row = clo->_.row.nth_val, last_row;
  if (n_avail < n_rows)
    n_rows = n_avail;
  last_row = first_row + n_rows;
  DO_SET (state_slot_t *, ssl, &slots)
  {
    int ctr;
    data_col_t *dc = clo->_.row.local_dcs[inx];
    data_col_t *target_dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
    DC_CHECK_LEN (target_dc, target_dc->dc_n_values + n_rows - 1);
    if (DV_ANY == ssl->ssl_sqt.sqt_dtp)
      {
	if (0 == target_dc->dc_n_values && dc->dc_dtp != target_dc->dc_dtp)
	  dc_convert_empty (target_dc, dc->dc_dtp);
	if (dc->dc_dtp != target_dc->dc_dtp && DV_ANY != target_dc->dc_dtp)
	  dc_heterogenous (target_dc);
      }
    if ((DCT_BOXES & target_dc->dc_type) && (DCT_BOXES & dc->dc_type))
      {
	for (ctr = first_row; ctr < last_row; ctr++)
	  {
	    dc_append_box (target_dc, ((caddr_t *) dc->dc_values)[ctr]);
	  }
      }
    else if (DV_ANY == dc->dc_dtp && DV_ANY == target_dc->dc_dtp)
      {
	for (ctr = first_row; ctr < last_row; ctr++)
	  {
	    db_buf_t dv = ((db_buf_t *) dc->dc_values)[ctr];
	    int l;
	    DB_BUF_TLEN (l, dv[0], dv);
	    dc_append_bytes (target_dc, dv, l, NULL, 0);
	  }
      }
    else if (dc->dc_dtp == target_dc->dc_dtp)
      {
	int elt_sz = dc_elt_size (dc);
	memcpy_16 (target_dc->dc_values + elt_sz * target_dc->dc_n_values, dc->dc_values + elt_sz * first_row, n_rows * elt_sz);
	if (target_dc->dc_any_null && !dc->dc_any_null)
	  {
	    for (ctr = first_row; ctr < last_row; ctr++)
	      BIT_CLR (target_dc->dc_nulls, ctr + target_dc->dc_n_values - first_row);
	  }
	else if (dc->dc_any_null)
	  {
	    if (!target_dc->dc_nulls)
	      dc_ensure_null_bits (target_dc);
	    target_dc->dc_any_null = 1;
	    for (ctr = first_row; ctr < last_row; ctr++)
	      {
		if (BIT_IS_SET (dc->dc_nulls, ctr))
		  {
		    BIT_SET (target_dc->dc_nulls, target_dc->dc_n_values + ctr - first_row);
		  }
		else
		  BIT_CLR (target_dc->dc_nulls, target_dc->dc_n_values + ctr - first_row);
	      }
	  }
	target_dc->dc_n_values += n_rows;
      }
    else
      {
	for (ctr = first_row; ctr < last_row; ctr++)
	  {
	    caddr_t box = dc_box (dc, ctr);
	    dc_append_box (target_dc, box);
	    dk_free_tree (box);
	  }
      }
    inx++;
  }
  END_DO_SET ();
  clo->_.row.nth_val += n_rows;
  itcl->itcl_n_results += n_rows;
}


void
dc_append_dre (data_col_t * dc, dc_read_t * dre)
{
}
int cl_low_water_default = 1;


int clib_trap_qf;
int clib_trap_col;

void
clib_row_boxes (cll_in_box_t * clib)
{
  /* Take current row of data from clib put in boxes and increment current */
  cl_req_group_t * clrg = clib->clib_group;
  caddr_t *inst = clrg->clrg_inst;
  caddr_t *       row = clib->clib_first._.row.cols;
  int inx;
  if (local_cll.cll_this_host == clib->clib_host->ch_id)
    {
      cl_op_t *clo = (cl_op_t *) basket_first (&clib->clib_in_parsed);
      row = clo->_.row.cols;
      DO_BOX (state_slot_t *, ssl, inx, clrg->clrg_itcl->itcl_dfg_qf->qf_inner_out_slots)
	{
	data_col_t *dc = (data_col_t *) clo->_.row.local_dcs[inx];
	caddr_t val = dc_box (dc, clo->_.row.nth_val);
	dk_free_tree (row[inx]);
	  row[inx] = val;
	}
      END_DO_BOX;
      return;
    }
  if (CLO_ROW == clib->clib_first.clo_op)
    {
      row = clib->clib_first._.row.cols;
      if (!row)
	clib->clib_first._.row.cols = row = dk_alloc_box_zero (sizeof (caddr_t) * clib->clib_n_dcs, DV_ARRAY_OF_POINTER);
    }
  else
    {
      row = clib->clib_first_row;
      if (!row)
	{
	  row = dk_alloc_box_zero (sizeof (caddr_t) * clib->clib_n_dcs, DV_ARRAY_OF_POINTER);
	  clib->clib_first._.row.cols = row;
	}
    }
  if (clib->clib_n_dcs && clib->clib_dc_read[0].dre_n_values != clib->clib_first._.row.n_rows)
    GPF_T1 ("clib and dre row counts do nott match");
  if (clib->clib_n_dcs && clib->clib_dc_read[0].dre_pos > clib->clib_first._.row.nth_val)
    {
      log_error ("dre read is ahead of clib read");
      bing ();
      return;
    }
  for (inx = 0; inx < clib->clib_n_dcs; inx++)
    {
      row[inx] = dre_box (&clib->clib_dc_read[inx], row[inx], inst);
      if (clib_trap_qf == clib->clib_group->clrg_dbg_qf && clib_trap_col == inx && unbox (row[inx]))
	bing ();
    }
}



void
cli_set_slice (client_connection_t * cli, cluster_map_t * clm, slice_id_t slice, caddr_t * err_ret)
{
  if (err_ret)
    *err_ret = NULL;
}

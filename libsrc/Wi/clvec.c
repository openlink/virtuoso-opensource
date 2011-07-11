/*
 *  clvec.c
 * 
 *  $Id$
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
#include "datesupp.h"


#define dc_dtp_elt_size(dtp)  \
  (DV_SINGLE_FLOAT == dtp ? 4 : DV_DATETIME == dtp ? DT_LENGTH : 8)

caddr_t
dre_box (dc_read_t * dre)
{
  if (DV_ANY == dre->dre_dtp || (DCT_BOXES & dre->dre_type))
    {
      int l;
      DB_BUF_TLEN (l, dre->dre_data[0], dre->dre_data);
      dre->dre_box = box_deserialize_reusing (dre->dre_data, dre->dre_box);
      dre->dre_data += l;
      dre->dre_pos++;
      return dre->dre_box;
    }
  if (dre->dre_any_null && BIT_IS_SET (dre->dre_nulls, dre->dre_pos))
    {
      if (!dre->dre_box ||  DV_DB_NULL != box_tag (dre->dre_box))
	{
	  dk_free_tree (dre->dre_box);
	  dre->dre_box = dk_alloc_box (0, DV_DB_NULL);
	}
      dre->dre_pos++;
      dre->dre_data += dc_dtp_elt_size (dre->dre_dtp);
      return dre->dre_box;
    }
  dre->dre_pos++;
  switch (dre->dre_dtp)
    {
    case DV_LONG_INT:
    case DV_IRI_ID:
    case DV_IRI_ID_8:
    case DV_DOUBLE_FLOAT:
      if (!dre->dre_box || sizeof (int64) != box_length (dre->dre_box))
	{
	  dk_free_box (dre->dre_box);
	  dre->dre_box = dk_alloc_box (8, dre->dre_dtp);
	}
      *(int64*)dre->dre_box = INT64_REF_CA (dre->dre_data);
      dre->dre_data += 8;
	return dre->dre_box;
    case DV_SINGLE_FLOAT:
      if (!dre->dre_box || sizeof (int64) != box_length (dre->dre_box))
	{
	  dk_free_box (dre->dre_box);
	  dre->dre_data = dk_alloc_box (8, dre->dre_dtp);
	}
      *(int32*)dre->dre_box = LONG_REF_CA (dre->dre_data);
      dre->dre_data += 4;
	return dre->dre_box;
    case DV_DATETIME:
      if (!dre->dre_box || DT_LENGTH != box_length (dre->dre_box))
	{
	  dk_free_box (dre->dre_box);
	  dre->dre_data = dk_alloc_box (DT_LENGTH, dre->dre_dtp);
	}
      memcpy_dt (dre->dre_box, dre->dre_data);
      dre->dre_data += DT_LENGTH;
	return dre->dre_box;
    }
  GPF_T;
  return NULL;
}


void
clib_row_boxes (cll_in_box_t * clib)
{
  /* Take current row of data from clib put in boxes and increment current */
  cl_req_group_t * clrg = clib->clib_group;
  caddr_t *       row = clib->clib_first._.row.cols;
  int inx;
  if (local_cll.cll_this_host == clib->clib_host->ch_id)
    {
      QNCAST (query_instance_t, qi, clrg->clrg_itcl->itcl_qst);
      row = clib->clib_first._.row.cols;
      qi->qi_set = clib->clib_rows_done;
      DO_BOX (state_slot_t *, ssl, inx, clrg->clrg_itcl->itcl_dfg_qf->qf_inner_out_slots)
	{
	  caddr_t val = qst_get (clrg->clrg_itcl->itcl_qst, ssl);
	  row[inx] = val;
	}
      END_DO_BOX;
      return;
    }
  for (inx = 0; inx < clib->clib_n_dcs; inx++)
    row[inx] = dre_box (&clib->clib_dc_read[inx]);
}


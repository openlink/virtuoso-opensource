/*
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

int
RANGE_NAME (col_pos_t * cpo, db_buf_t ce_first, int n_values, int n_bytes)
{
  it_cursor_t *itc = cpo->cpo_itc;
  search_spec_t *sp = itc->itc_col_spec;
  dtp_t min_op = sp->sp_min_op, max_op = sp->sp_max_op;
  ELT_T lower;
  ELT_T upper;
  int mfill = itc->itc_match_out, ce_row = cpo->cpo_ce_row_no, inx;
  dtp_t dtp;
  int last = MIN (n_values, cpo->cpo_to - ce_row);
  switch (sp->sp_cl.cl_sqt.sqt_col_dtp)
    {
    case DV_DOUBLE_FLOAT:
    case DV_SINGLE_FLOAT:
      return 0;
    case DV_LONG_INT:
    case DV_SHORT_INT:
    case DV_INT64:
      if (DTP != DV_LONG_INT)
	return 0;
      if (CMP_NONE != min_op)
	{
	  dtp = DV_TYPE_OF (cpo->cpo_cmp_min);
	  if (DV_LONG_INT != dtp)
	    return 0;
	  lower = unbox (cpo->cpo_cmp_min);
	}
      else
	lower = DTP_MIN;
      if (CMP_NONE != max_op)
	{
	  dtp = DV_TYPE_OF (cpo->cpo_cmp_max);
	  if (DV_LONG_INT != dtp)
	    return 0;
	  upper = unbox (cpo->cpo_cmp_max);
	}
      else
	upper = DTP_MAX;
      break;
    case DV_IRI_ID:
    case DV_IRI_ID_8:
      if (DTP != DV_IRI_ID)
	return 0;
      if (CMP_NONE != min_op)
	{
	  dtp = DV_TYPE_OF (cpo->cpo_cmp_min);
	  if (DV_IRI_ID != dtp)
	    return 0;
	  lower = unbox_iri_id (cpo->cpo_cmp_min);
	}
      else
	lower = 0;
      if (CMP_NONE != max_op)
	{
	  dtp = DV_TYPE_OF (cpo->cpo_cmp_max);
	  if (DV_IRI_ID != dtp)
	    return 0;
	  upper = unbox_iri_id (cpo->cpo_cmp_max);
	}
      else
	upper = 0xffffffffffffffff;
      break;
    case DV_ANY:
      if (min_op != CMP_NONE)
	{
	  lower = dv_int ((db_buf_t) cpo->cpo_cmp_min, &dtp);
	  if (DTP != dtp_canonical[dtp])
	    return 0;
	}
      else
	lower = DTP_MIN;
      if (max_op != CMP_NONE)
	{
	  upper = dv_int ((db_buf_t) cpo->cpo_cmp_max, &dtp);
	  if (DTP != dtp_canonical[dtp])
	    return 0;
	}
      else
	upper = DTP_MAX;
      break;
    default:
      return 0;
    }
  if (CMP_EQ == min_op)
    upper = lower;
  if (CMP_LT == max_op)
    upper--;
  if (CMP_GT == min_op)
    lower++;

  for (inx = cpo->cpo_skip; inx < last; inx++)
    {
      ELT_T elt = REF ((ce_first + sizeof (VEC_ELT_T) * inx));
      if (elt >= lower && elt <= upper)
	itc->itc_matches[mfill++] = ce_row + inx;
    }
  itc->itc_match_out = mfill;
  return ce_row + n_values;
}

#undef RANGE_NAME
#undef ELT_T
#undef VEC_ELT_T
#undef REF
#undef DTP_MIN
#undef DTP_MAX
#undef DTP

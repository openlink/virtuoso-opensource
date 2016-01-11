/*
 *  ceveci.c
 *
 *  $Id$
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


int
range_name (col_pos_t * cpo, db_buf_t ce_first, int n_values, int n_bytes)
{
  data_col_t *dc = cpo->cpo_dc;
  int skip = cpo->cpo_skip;
  int last = MIN (n_values, cpo->cpo_to - cpo->cpo_ce_row_no);

  int64 *values;
  int fill = dc->dc_n_values, inx;
  if (!fill && DV_ANY == dc->dc_sqt.sqt_col_dtp)
    dc_convert_empty (dc, dv_ce_dtp[ELT_DV]);
  if (ELT_DV != dc->dc_dtp && DV_ANY == dc->dc_sqt.sqt_col_dtp)
    return 0;
  if (4 == sizeof (VEC_ELT_T))
    {
      if (DV_SINGLE_FLOAT == dc->dc_dtp)
	{
	  int32 *values = (int32 *) dc->dc_values;
	  for (inx = skip; inx <= last - 4; inx += 4)
	    {
	      values[fill] = REF (ce_first + inx * sizeof (VEC_ELT_T));
	      values[fill + 1] = REF (ce_first + (inx + 1) * sizeof (VEC_ELT_T));
	      values[fill + 2] = REF (ce_first + (inx + 2) * sizeof (VEC_ELT_T));
	      values[fill + 3] = REF (ce_first + (inx + 3) * sizeof (VEC_ELT_T));
	      fill += 4;
	    }
	  for (inx = inx; inx < last; inx++)
	    values[fill++] = REF (ce_first + (inx * sizeof (VEC_ELT_T)));
	  dc->dc_n_values = fill;
	  return cpo->cpo_ce_row_no + n_values;
	}
    }
  values = (int64 *) dc->dc_values;
  for (inx = skip; inx <= last - 4; inx += 4)
    {
      values[fill] = REF (ce_first + inx * sizeof (VEC_ELT_T));
      values[fill + 1] = REF (ce_first + (inx + 1) * sizeof (VEC_ELT_T));
      values[fill + 2] = REF (ce_first + (inx + 2) * sizeof (VEC_ELT_T));
      values[fill + 3] = REF (ce_first + (inx + 3) * sizeof (VEC_ELT_T));
      fill += 4;
    }
  for (inx = inx; inx < last; inx++)
    values[fill++] = REF (ce_first + (inx * sizeof (VEC_ELT_T)));
  dc->dc_n_values = fill;
  return cpo->cpo_ce_row_no + n_values;
}


int
sets_name (col_pos_t * cpo, db_buf_t ce_first, int n_values, int n_bytes)
{
  it_cursor_t *itc = cpo->cpo_itc;
  data_col_t *dc = cpo->cpo_dc;
  int s1, s2, s3, s4;
  int ce_row = cpo->cpo_ce_row_no;
  int end_of_ce = n_values + ce_row;
  int64 *values;
  int fill = dc->dc_n_values;
  row_no_t *matches = itc->itc_matches;
  int n_matches = itc->itc_n_matches;
  int inx = itc->itc_match_in;
  if (!fill && DV_ANY == dc->dc_sqt.sqt_col_dtp)
    dc_convert_empty (dc, dv_ce_dtp[ELT_DV]);
  if (ELT_DV != dc->dc_dtp && DV_ANY == dc->dc_sqt.sqt_col_dtp)
    return 0;
  if (4 == sizeof (VEC_ELT_T))
    {
      if (DV_SINGLE_FLOAT == dc->dc_dtp)
	{
	  int32 *values = (int32 *) dc->dc_values;
	  while (inx + 4 <= n_matches && (s4 = matches[inx + 3]) < end_of_ce)
	    {
	      s1 = itc->itc_matches[inx] - ce_row;
	      s2 = itc->itc_matches[inx + 1] - ce_row;
	      s3 = itc->itc_matches[inx + 2] - ce_row;
	      s4 -= ce_row;
	      values[fill] = REF (ce_first + s1 * sizeof (VEC_ELT_T));
	      values[fill + 1] = REF (ce_first + s2 * sizeof (VEC_ELT_T));
	      values[fill + 2] = REF (ce_first + s3 * sizeof (VEC_ELT_T));
	      values[fill + 3] = REF (ce_first + s4 * sizeof (VEC_ELT_T));
	      fill += 4;
	      inx += 4;
	    }
	  while (inx < n_matches && (s1 = matches[inx]) < end_of_ce)
	    {
	      s1 -= ce_row;
	      values[fill++] = REF (ce_first + s1 * sizeof (VEC_ELT_T));
	      inx++;
	    }
	  itc->itc_match_in = inx;
	  dc->dc_n_values = fill;
	  return inx >= n_matches ? CE_AT_END : matches[inx];
	}
    }
  values = (int64 *) dc->dc_values;
  while (inx + 4 <= n_matches && (s4 = matches[inx + 3]) < end_of_ce)
    {
      s1 = itc->itc_matches[inx] - ce_row;
      s2 = itc->itc_matches[inx + 1] - ce_row;
      s3 = itc->itc_matches[inx + 2] - ce_row;
      s4 -= ce_row;
      values[fill] = REF (ce_first + s1 * sizeof (VEC_ELT_T));
      values[fill + 1] = REF (ce_first + s2 * sizeof (VEC_ELT_T));
      values[fill + 2] = REF (ce_first + s3 * sizeof (VEC_ELT_T));
      values[fill + 3] = REF (ce_first + s4 * sizeof (VEC_ELT_T));
      fill += 4;
      inx += 4;
    }
  while (inx < n_matches && (s1 = matches[inx]) < end_of_ce)
    {
      s1 -= ce_row;
      values[fill++] = REF (ce_first + s1 * sizeof (VEC_ELT_T));
      inx++;
    }
  itc->itc_match_in = inx;
  dc->dc_n_values = fill;
  return inx >= n_matches ? CE_AT_END : matches[inx];
}


int
dict_range_name (col_pos_t * cpo, db_buf_t ce_first, int n_values, int n_bytes)
{
  data_col_t *dc = cpo->cpo_dc;
  int skip = cpo->cpo_skip;
  int s1, s2, s3, s4;
  int last = MIN (n_values, cpo->cpo_to - cpo->cpo_ce_row_no);

  int64 *values;
  int fill = dc->dc_n_values, inx;
  unsigned char n_distinct = *ce_first;
  db_buf_t array;
  ce_first++;
  array = ce_first + n_distinct * sizeof (VEC_ELT_T);
  if (!fill && DV_ANY == dc->dc_sqt.sqt_col_dtp)
    dc_convert_empty (dc, dv_ce_dtp[ELT_DV]);
  if (ELT_DV != dc->dc_dtp && DV_ANY == dc->dc_sqt.sqt_col_dtp)
    return 0;
  if (4 == sizeof (VEC_ELT_T))
    {
      if (DV_SINGLE_FLOAT == dc->dc_dtp)
	{
	  int32 *values = (int32 *) dc->dc_values;
	  for (inx = skip; inx <= last - 4; inx += 4)
	    {
	      s1 = VEC_INX (array, inx);
	      s2 = VEC_INX (array, inx + 1);
	      s3 = VEC_INX (array, inx + 2);
	      s4 = VEC_INX (array, inx + 3);
	      values[fill] = REF (ce_first + s1 * sizeof (VEC_ELT_T));
	      values[fill + 1] = REF (ce_first + s2 * sizeof (VEC_ELT_T));
	      values[fill + 2] = REF (ce_first + s3 * sizeof (VEC_ELT_T));
	      values[fill + 3] = REF (ce_first + s4 * sizeof (VEC_ELT_T));
	      fill += 4;
	    }
	  for (inx = inx; inx < last; inx++)
	    {
	      s1 = VEC_INX (array, inx);
	      values[fill++] = REF (ce_first + (s1 * sizeof (VEC_ELT_T)));
	    }
	  dc->dc_n_values = fill;
	  return cpo->cpo_ce_row_no + n_values;

	  dc->dc_n_values = fill;
	  return cpo->cpo_ce_row_no + n_values;
	}
    }
  values = (int64 *) dc->dc_values;
  for (inx = skip; inx <= last - 4; inx += 4)
    {
      s1 = VEC_INX (array, inx);
      s2 = VEC_INX (array, inx + 1);
      s3 = VEC_INX (array, inx + 2);
      s4 = VEC_INX (array, inx + 3);
      values[fill] = REF (ce_first + s1 * sizeof (VEC_ELT_T));
      values[fill + 1] = REF (ce_first + s2 * sizeof (VEC_ELT_T));
      values[fill + 2] = REF (ce_first + s3 * sizeof (VEC_ELT_T));
      values[fill + 3] = REF (ce_first + s4 * sizeof (VEC_ELT_T));
      fill += 4;
    }
  for (inx = inx; inx < last; inx++)
    {
      s1 = VEC_INX (array, inx);
      values[fill++] = REF (ce_first + (s1 * sizeof (VEC_ELT_T)));
    }
  dc->dc_n_values = fill;
  return cpo->cpo_ce_row_no + n_values;
}


int
dict_sets_name (col_pos_t * cpo, db_buf_t ce_first, int n_values, int n_bytes)
{
  it_cursor_t *itc = cpo->cpo_itc;
  data_col_t *dc = cpo->cpo_dc;
  int s1, s2, s3, s4;
  int ce_row = cpo->cpo_ce_row_no;
  int end_of_ce = n_values + ce_row;
  int64 *values;
  int fill = dc->dc_n_values;
  row_no_t *matches = itc->itc_matches;
  int n_matches = itc->itc_n_matches;
  int inx = itc->itc_match_in;
  unsigned char n_distinct = *ce_first;
  db_buf_t array;
  ce_first++;
  array = ce_first + n_distinct * sizeof (VEC_ELT_T);
  if (!fill && DV_ANY == dc->dc_sqt.sqt_col_dtp)
    dc_convert_empty (dc, dv_ce_dtp[ELT_DV]);
  if (ELT_DV != dc->dc_dtp && DV_ANY == dc->dc_sqt.sqt_col_dtp)
    return 0;
  if (4 == sizeof (VEC_ELT_T))
    {
      if (DV_SINGLE_FLOAT == dc->dc_dtp)
	{
	  int32 *values = (int32 *) dc->dc_values;
	  while (inx + 4 <= n_matches && (s4 = matches[inx + 3]) < end_of_ce)
	    {
	      s1 = itc->itc_matches[inx] - ce_row;
	      s2 = itc->itc_matches[inx + 1] - ce_row;
	      s3 = itc->itc_matches[inx + 2] - ce_row;
	      s4 -= ce_row;
	      s1 = VEC_INX (array, s1);
	      s2 = VEC_INX (array, s2);
	      s3 = VEC_INX (array, s3);
	      s4 = VEC_INX (array, s4);
	      values[fill] = REF (ce_first + s1 * sizeof (VEC_ELT_T));
	      values[fill + 1] = REF (ce_first + s2 * sizeof (VEC_ELT_T));
	      values[fill + 2] = REF (ce_first + s3 * sizeof (VEC_ELT_T));
	      values[fill + 3] = REF (ce_first + s4 * sizeof (VEC_ELT_T));
	      fill += 4;
	      inx += 4;
	    }
	  while (inx < n_matches && (s1 = matches[inx]) < end_of_ce)
	    {
	      s1 -= ce_row;
	      s1 = VEC_INX (array, s1);
	      values[fill++] = REF (ce_first + s1 * sizeof (VEC_ELT_T));
	      inx++;
	    }
	  itc->itc_match_in = inx;
	  dc->dc_n_values = fill;
	  return inx >= n_matches ? CE_AT_END : matches[inx];
	}
    }
  values = (int64 *) dc->dc_values;
  while (inx + 4 <= n_matches && (s4 = matches[inx + 3]) < end_of_ce)
    {
      s1 = itc->itc_matches[inx] - ce_row;
      s2 = itc->itc_matches[inx + 1] - ce_row;
      s3 = itc->itc_matches[inx + 2] - ce_row;
      s4 -= ce_row;
      s1 = VEC_INX (array, s1);
      s2 = VEC_INX (array, s2);
      s3 = VEC_INX (array, s3);
      s4 = VEC_INX (array, s4);
      values[fill] = REF (ce_first + s1 * sizeof (VEC_ELT_T));
      values[fill + 1] = REF (ce_first + s2 * sizeof (VEC_ELT_T));
      values[fill + 2] = REF (ce_first + s3 * sizeof (VEC_ELT_T));
      values[fill + 3] = REF (ce_first + s4 * sizeof (VEC_ELT_T));
      fill += 4;
      inx += 4;
    }
  while (inx < n_matches && (s1 = matches[inx]) < end_of_ce)
    {
      s1 -= ce_row;
      s1 = VEC_INX (array, s1);
      values[fill++] = REF (ce_first + s1 * sizeof (VEC_ELT_T));
      inx++;
    }
  itc->itc_match_in = inx;
  dc->dc_n_values = fill;
  return inx >= n_matches ? CE_AT_END : matches[inx];
}


#undef range_name
#undef sets_name
#undef dict_range_name
#undef dict_sets_name
#undef REF
#undef VEC_ELT_T
#undef ELT_DV

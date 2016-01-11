/*
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
NAME (col_pos_t * cpo, db_buf_t ce_first, int n_values, int n_bytes)
{
  db_buf_t ce = cpo->cpo_ce;
  ELT_T first, value;
  dtp_t flags = ce[0];
  int bm_bytes;
  it_cursor_t *itc = cpo->cpo_itc;
  db_buf_t ce_first_val, ce_first2;
  int skip = cpo->cpo_skip;
  int offset, first_len, nb, nv;
  char dtp_match;
  CE_2_LENGTH (ce, ce_first2, nb, nv);
  CE_FIRST;
  value = cpo_iri_int64 (cpo, cpo->cpo_cmp_min, ELT_DV, &dtp_match);
  if (!dtp_match)
    return 0;
  bm_bytes = n_bytes - (ce_first - ce_first_val);
  if (value == first)
    {
      if (0 == skip)
	itc->itc_matches[itc->itc_match_out++] = cpo->cpo_ce_row_no;
      goto end;
    }
  offset = (value - 1) - first;
  if (value < first || value >= 1 + (first + bm_bytes * 8))
    goto end;
  if (BIT_IS_SET (ce_first, offset))
    {
      int cnt_ret = 0, n_ret = 0;
      int nth = ce_bm_nth (ce_first, offset + 1, &cnt_ret, &n_ret);
      if (nth >= skip && nth < cpo->cpo_to - cpo->cpo_ce_row_no)
	itc->itc_matches[itc->itc_match_out++] = cpo->cpo_ce_row_no + nth;
    }
end:
  return cpo->cpo_ce_row_no + n_values;
}


#undef ELT_T
#undef NAME

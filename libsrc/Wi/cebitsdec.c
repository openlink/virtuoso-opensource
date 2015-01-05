/*
 *  Column Compression
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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


#undef CE_BITS_TGT
#ifdef CE_BITS_RANGE
#define CE_BITS_TGT(repeating_place)		\
  {last_row++; if (last_row >= last_of_ce) return last_row; target = last_row;}

#else

#define CE_BITS_TGT(repeating_place)		\
{ \
  if (++itc->itc_match_in >= itc->itc_n_matches) \
    return CE_AT_END; \
  target = itc->itc_matches[itc->itc_match_in]; \
  if (target == last_row) \
    goto repeating_place; \
  if (target >= last_of_ce) \
    return target; \
  last_row++; \
}
#endif

int
CE_NAME (col_pos_t * cpo, db_buf_t ce_first, int n_values, int n_bytes)
{
  it_cursor_t * itc = cpo->cpo_itc;
  data_col_t * dc = cpo->cpo_dc;
  int64 base, base_1, first;
  uint32 date_base = 0;
  db_buf_t ce = cpo->cpo_ce;
  db_buf_t ce_first_val, ce_end = ce_first + n_bytes;
  int first_len, dtp_cmp;
  int skip = cpo->cpo_skip;
  dtp_t flags = *cpo->cpo_ce;
  int last_row = cpo->cpo_ce_row_no;
  db_buf_t body;
  int byte = 0, bit = 0;
  CED_VARS
  int to = cpo->cpo_to;
  int target;
#ifdef CE_BITS_RANGE
  int last_of_ce = MIN (last_row + n_values, cpo->cpo_to);
#else
  int last_of_ce = last_row + n_values;
#endif
  CE_FIRST;
  CED_CHECK;
  if (!enable_bits_dec)
    return 0;
  if (0 == skip)
    {
    repeat_first:
      CE_OUT (ce_first_val, first_len, first);
      CE_BITS_TGT (repeat_first);
      skip = target - last_row;
      byte = bit = 0;
      ce_skip_bits_2 (ce_first, skip, &byte, &bit);
      last_row += skip;
    }
  else
    {
      ce_skip_bits_2 (ce_first, skip - 1, &byte, &bit);
      last_row += skip;
    }
  for (;;)
    {
    repeat_val:
      CE_OUT (ce_first_val, first_len, first + byte * 8 + bit + 1);
      CE_BITS_TGT (repeat_val);
      bit++;
      skip = target - last_row;
      if (8 == bit)
	{
	  byte++;
	  bit = 0;
	}
      ce_skip_bits_2 (ce_first, skip, &byte, &bit);
#ifndef CE_BITS_RANGE
      last_row = target;
#endif
    }
}


#undef CE_NAME
#undef CE_BITS_RANGE
#undef CE_OUT
#undef CED_VARS
#undef ELT_DTP


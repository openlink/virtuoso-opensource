/*
 *  cedel.c
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
#include "date.h"


int dbf_ce_del_mask;


#if 0
int
ce_rld_n_for_place (ce_ins_ctx_t * ceic, int64 * values, int nth, int lower, int upper)
{
  /* how many consecutive of the same value going to the same row or rl range.  If many rl bytes with -0 delta consider them all and return how many were covered */
  it_cursor_t *itc = ceic->ceic_itc;
  int inx;
  for (inx = nth + 1; inx < ceic->ceic_n_for_ce; inx++)
    {
      int row_no = itc->itc_ranges[inx + itc->itc_ce_first_range].r_first - itc->itc_row_of_ce;
      if (values[inx] == values[nth] && row_no >= lower && row_no < upper)
	continue;
      if (row_no > lower && row_no < upper)
	return -1;		/* got a fuck that falls in the range but is not eq */
      return inx - nth;
    }
  return inx - nth;
}

void
ce_rld_inc_count (db_buf_t ce_cur, db_buf_t ce_end, int n_more, int *n_15s, dtp_t * a15, int *n_skip)
{
  int inx, fill = 0;
  for (inx = 0; inx < ce_end - ce_cur; inx++)
    {
      dtp_t byte = ce_cur[inx];
      if (0xf0 & byte && inx)
	break;
      if (!n_more)
	;
      else if (15 > (byte & 0xf))
	{
	  int avail = 15 - (byte & 0xf);
	  if (avail >= n_more)
	    {
	      ce_cur[inx] += n_more;
	      n_more = 0;
	    }
	  else if (avail)
	    {
	      ce_cur[inx] = (byte & 0xf0) | 15;
	      n_more -= avail;
	    }
	}
    }
  *n_skip = inx;
  while (n_more > 15)
    {
      a15[fill++] = 15;
      n_more -= 15;
      if (fill > 200)
	GPF_T1 ("cannot inc rld count by over 3000");
    }
  if (n_more)
    a15[fill++] = n_more;
  *n_15s = fill;
}

db_buf_t
ce_delete_rld (ce_ins_ctx_t * ceic, ce_ins_ctx_t ** col_ceic, db_buf_t ce, int space_after, int *split_at)
{
  dtp_t a15[300];
  it_cursor_t *itc = ceic->ceic_itc;
  db_buf_t ce_first, ce_end, ce_cur;
  int n_values, n_bytes, rl_inc_at_end, n_more, n_15s, n_skip, is_first;
  db_buf_t ce_first_val;
  dtp_t byte, flags = *ce, no_look = 0;
  int64 value, first;
  int n_deltas, first_len, nth, row_no, last_row = 0, delta, rl;
  CE_2_LENGTH (ce, ce_first, n_bytes, n_values);
  CE_FIRST;
  first_len = ce_first - ce_first_val;
  ce_first = ce_first_val;
  ce_end = ce_first + n_bytes;
  ce_cur = ce_first + first_len;
  nth = 0;
  first = 0;
  row_no = itc->itc_ranges[itc->itc_ce_first_range + nth].r_first - itc->itc_row_of_ce;
  end_row_no = itc->itc_ranges[itc->itc_ce_first_range + nth].r_end - itc->itc_row_of_ce;
  last_row = 0;
  while (ce_cur < ce_end)
    {
      rl_inc_at_end = 0;
      byte = *ce_cur;
      delta = byte >> 4;
      rl = byte & 0xf;
      if (row_no >= last_row && row_no < last_row + rl)
	{
	  /* del in the rl, see if it goes away. */
	  if (ce_cur < ce_end - 1)
	    {
	      dtp_t next = ce_cur[1];

	    }
	}
      while (last_row == row_no)
	{
	  if (value == first + delta)
	    goto rl_inc;
	  if (value == first)
	    {
	      if (ce_cur == ce_first + first_len)
		goto ins_1;
	      ce_cur--;
	      rl_inc_at_end = 1;
	      goto rl_inc;
	    }
	  if (value < first)
	    goto no_order;
	  if (value < first + delta)
	    goto ins_1;
	  if (rl && value > first + delta)
	    goto no_order;
	  if (ce_cur == ce_end - 1)
	    goto append;
	  first += delta;
	  ce_cur++;
	  byte = *ce_cur;
	  delta = byte >> 4;
	  rl = byte & 0xf;
	}
      if (last_row < row_no && last_row + rl > row_no)
	{
	  if (first + delta == value)
	    goto rl_inc;
	  goto no_order;
	}
      last_row += rl;
      first += delta;
      ce_cur++;
      if (!no_look && row_no - last_row > 10 && ce_end - ce_cur > 8)
	{
	  unsigned int64 r8 = *(unsigned int64 *) ce_cur;
	  unsigned int64 d8 = r8;
	  r8 &= 0x0f0f0f0f0f0f0f0f;
	  add8 (r8);
	  if (last_row + r8 < row_no)
	    {
	      d8 = d8 >> 4;
	      d8 &= 0x0f0f0f0f0f0f0f0f;
	      add8 (d8);
	      first += d8;
	      ce_cur += 8;
	      last_row += r8;
	      continue;
	    }
	  no_look = 1;
	}
      continue;
    next_v:
      nth++;
      if (nth >= ceic->ceic_n_for_ce)
	return ce;
      row_no = itc->itc_ranges[itc->itc_ce_first_range + nth].r_first - itc->itc_row_of_ce;
      value = values[nth];
      no_look = 0;
      continue;
    }
append:
  if (nth < n_deltas)
    {
      /* inserts at the end */
      int64 last_value = values[n_deltas - 1];
      if (value < first || value - first > 160)
	goto no_order;
      if ((last_value - first) / (n_deltas - nth) > 32)
	goto no_order;
      ce_rld_append (ceic, col_ceic, &ce, first, &values[nth], n_deltas - nth, ce_cur[-1], &space_after);
    }
  return ce;
no_order:
  itc->itc_ce_first_range += nth;
  itc->itc_ce_first_set += nth;
  itc->itc_row_of_ce -= nth;	/* in the merge insert, the ranges are applied this much later.  The row of ce can go negative but this is ok, it is int */
  return CE_INSERT_GEN;
rl_inc:
  if (!rl_inc_at_end)
    rl = ce_rld_rl (ce_cur, ce_end);
  n_more = ce_rld_n_for_place (ceic, values, nth, last_row, rl_inc_at_end ? last_row + 1 : last_row + rl + 1);
  if (-1 == n_more || n_more > 16 * (ce_first + first_len - ce))
    goto no_order;
  ce_rld_inc_count (ce_cur, ce_end, n_more, &n_15s, a15, &n_skip);
  if (-1 == n_15s)
    goto no_order;
  ce_inc_n_values (ceic, col_ceic, &ce, &ce_first, &ce_cur, &ce_end, &space_after, n_more);
  ce_cur += n_skip;
  if (n_15s)
    ce_insert_byte (ceic, col_ceic, &ce, &ce_first, &ce_cur, &ce_end, &space_after, ce_cur - ce_first, a15, n_15s, 0);
  ce_cur += n_15s;
  nth += n_more - 1;
  if (!rl_inc_at_end)
    {
      last_row += rl;
      first += delta;
    }
  goto next_v;

ins_1:
  n_more = ce_rld_n_for_place (ceic, values, nth, last_row, last_row + 1);
  if (-1 == n_more)
    GPF_T1 ("ce insert rld got rl seq break value where there is no rl seq");
  nth += n_more - 1;
  while (value - first > 15)
    {
      byte = 15 << 4;
      ce_insert_byte (ceic, col_ceic, &ce, &ce_first, &ce_cur, &ce_end, &space_after, ce_cur - ce_first, &byte, 1, 0);
      first += 15;
      ce_cur++;
    }
  is_first = 1;
  while (n_more)
    {
      int for_here = MIN (n_more, 15);
      byte = for_here + (is_first ? ((value - first) << 4) : 0);
      ce_insert_byte (ceic, col_ceic, &ce, &ce_first, &ce_cur, &ce_end, &space_after, ce_cur - ce_first, &byte, 1, for_here);
      ce_cur++;
      n_more -= for_here;
      is_first = 0;
    }
  if (ce_cur < ce_end)
    ce_cur[0] -= (value - first) << 4;
  first = value;
  delta = 0;
  goto next_v;
}

#endif



void
ce_del_array (ce_ins_ctx_t * ceic, db_buf_t array, int n_elt, int elt_sz)
{
  it_cursor_t *itc = ceic->ceic_itc;
  int nth, row, row2, end_row;
  for (nth = 0; nth < ceic->ceic_n_for_ce; nth++)
    {
      int deld_before = nth;
      row = itc->itc_ranges[nth + itc->itc_ce_first_range].r_first - itc->itc_row_of_ce;
      end_row = row + 1;
      while (nth + 1 < ceic->ceic_n_for_ce)
	{
	  row2 = itc->itc_ranges[itc->itc_ce_first_range + nth + 1].r_first - itc->itc_row_of_ce;
	  if (row2 != end_row)
	    break;
	  end_row = row2 + 1;
	  nth++;
	}
      if (nth + 1 >= ceic->ceic_n_for_ce)
	row2 = n_elt;
      memmove_16 (array + (row - deld_before) * elt_sz, array + elt_sz * end_row, elt_sz * (row2 - end_row));
    }
}


void
ce_del_bits (ce_ins_ctx_t * ceic, db_buf_t array, int n_elt, int elt_sz)
{
  it_cursor_t *itc = ceic->ceic_itc;
  int nth, row, row2, end_row;
  for (nth = 0; nth < ceic->ceic_n_for_ce; nth++)
    {
      int deld_before = nth;
      row = itc->itc_ranges[nth + itc->itc_ce_first_range].r_first - itc->itc_row_of_ce;
      end_row = row + 1;
      while (nth + 1 < ceic->ceic_n_for_ce)
	{
	  row2 = itc->itc_ranges[itc->itc_ce_first_range + nth + 1].r_first - itc->itc_row_of_ce;
	  if (row2 != end_row)
	    break;
	  end_row = row2 + 1;
	  nth++;
	}
      if (nth + 1 >= ceic->ceic_n_for_ce)
	row2 = n_elt;
      bit_delete (array, (row - deld_before) * elt_sz, elt_sz * end_row, elt_sz * (row2 - end_row));
    }
}


int
ce_del_dict (ce_ins_ctx_t * ceic, db_buf_t ce, int *len_ret)
{
  db_buf_t ce_first;
  int n_values, n_bytes;
  dtp_t flags = *ce;
  int n_del = ceic->ceic_n_for_ce;
  int new_bytes;
  db_buf_t dict;
  int n_distinct;
  if (CS_NO_DICT & dbf_ce_del_mask)
    return 0;
  CE_2_LENGTH (ce, ce_first, n_bytes, n_values);
  if (n_values - ceic->ceic_n_for_ce < n_values / 3)
    return 0;
  n_distinct = ce_first[0];
  dict = ce_dict_array (ce);
  new_bytes = n_distinct <= 16 ? ALIGN_2 (n_values - n_del) / 2 : n_values - n_del;
  if (n_distinct <= 16)
    ce_del_bits (ceic, dict, n_values, 4);
  else
    ce_del_array (ceic, dict, n_values, 1);

  n_bytes = (dict + new_bytes) - ce;
  if (CE_IS_SHORT & flags)
    {
      *len_ret = n_bytes - 3;
      ce[1] = n_bytes - 3;
      ce[2] -= n_del;
    }
  else
    {
      *len_ret = n_bytes - 5;
      SHORT_SET_CA (ce + 1, n_bytes - 5);
      SHORT_SET_CA (ce + 3, SHORT_REF_CA (ce + 3) - n_del);
    }
  return 1;
}


int
ce_del_int_delta (ce_ins_ctx_t * ceic, db_buf_t ce, int *len_ret)
{
  it_cursor_t *itc = ceic->ceic_itc;
  db_buf_t rl_ptr, run_ptr;
  db_buf_t ce_first = ce, ce_end, ce_cur, ce_first_val;
  int n_values, n_bytes, n_for_run, is_first_run = 1;
  int ce_first_range = itc->itc_ce_first_range, row_of_ce = itc->itc_row_of_ce;
  dtp_t flags = *ce;
  int64 first, base, base_1;
  int n_deltas, first_len, nth, inx, more, row_no, last_row = 0;
  uint32 d, run, run1;
  if (CS_NO_DELTA & dbf_ce_del_mask)
    return 0;
  CE_2_LENGTH (ce, ce_first, n_bytes, n_values);
  if (ceic->ceic_n_for_ce > n_values / 2)
    return 0;
  CE_FIRST;
  n_deltas = ceic->ceic_n_for_ce;
  first_len = ce_first - ce_first_val;
  ce_first = ce_first_val;
  ce_end = ce_first + n_bytes;
  ce_cur = ce_first + first_len;
  run_ptr = ce_first + first_len;
  nth = 0;

  if (!CE_INTLIKE (flags))
    {
      if (DV_DATE == any_ce_dtp (ce_first_val))
	{
	  base = DT_UDAY (ce_first_val + 1);
	  run1 = run = base & 0xff;
	  rl_ptr = ce_first_val + 3;
	  base_1 = base = (base & CLEAR_LOW_BYTE) - base + run1;
	}
      else
	{
	  first = LONG_REF_NA (run_ptr - 4);
	  rl_ptr = run_ptr - 1;
	  base = base_1 = 0;
	  run1 = run = first & 0xff;
	}
    }
  else
    {
      base_1 = base = first & CLEAR_LOW_BYTE;
      run1 = run = first & 0xff;
#if WORDS_BIGENDIAN
      rl_ptr = run_ptr - 1;
#else
      rl_ptr = ce_first_val;
#endif
    }
  ce_end = ce_first + n_bytes;
  while (nth < n_deltas)
    {
      for (inx = nth; inx < n_deltas; inx++)
	{
	  row_no = itc->itc_ranges[inx + ce_first_range].r_first - row_of_ce;
	  if (row_no >= last_row + run)
	    break;
	}
      n_for_run = inx - nth;
      more = 2 * (inx - nth);
      if (!n_for_run)
	;
      else if (n_for_run != run || is_first_run)
	{
	  itc->itc_row_of_ce = last_row + row_of_ce;
	  ceic->ceic_n_for_ce = n_for_run;
	  itc->itc_ce_first_range = nth + ce_first_range;
	  ce_del_array (ceic, run_ptr, run, 2);
	  *rl_ptr -= n_for_run;
	  memmove_16 (run_ptr + 2 * (run - n_for_run), run_ptr + (run * 2), ce_end - (run_ptr + run * 2));
	  n_bytes -= more;
	}
      else
	{

	  memmove_16 (run_ptr - 4, run_ptr + 2 * run, ce_end - (run_ptr + 2 * run));
	  n_bytes -= 4 + 2 * run;
	  run_ptr -= 4;
	}
      is_first_run = 0;
      ce_end = ce_first + n_bytes;
      last_row += run;
      nth += n_for_run;
      run_ptr += 2 * (run - n_for_run);
      if (run_ptr == ce_end)
	break;
      d = LONG_REF_NA (run_ptr);
      run = d & 0xff;
      base = base_1 + (d & CLEAR_LOW_BYTE);
      run_ptr += 4;
      rl_ptr = run_ptr - 1;
    }
  n_bytes = ce_end - ce;
  ceic->ceic_n_for_ce = n_deltas;
  itc->itc_ce_first_range = ce_first_range;
  if (CE_IS_SHORT & flags)
    {
      *len_ret = n_bytes - 3;
      ce[1] = n_bytes - 3;
      ce[2] -= n_deltas;
    }
  else
    {
      *len_ret = n_bytes - 5;
      SHORT_SET_CA (ce + 1, n_bytes - 5);
      SHORT_SET_CA (ce + 3, SHORT_REF_CA (ce + 3) - n_deltas);
    }
  return 1;
}

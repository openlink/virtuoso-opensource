/*
 *  cesearch.c
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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
ce_search_name (it_cursor_t * itc, db_buf_t ce, row_no_t row_of_ce, int rc, int nth_key)
{
  int set = itc->itc_set - itc->itc_col_first_set;
  int below, at_or_above, top_eq, end, upper, lower, guess;
  int ce_n_values, ce_bytes;
  COL_VAR;
  db_buf_t ce_first;
  CE_LEN;
  NEW_VAL;
  if (0 == nth_key)
    {
      at_or_above = CE_FIND_FIRST == rc ? 0 : itc->itc_ranges[set].r_first - row_of_ce;
      upper = end = below = ce_n_values;
    }
  else
    {
      lower = at_or_above = itc->itc_ranges[set].r_first - row_of_ce;
      upper = end = below = itc->itc_ranges[set].r_end - row_of_ce;
      if (below > ce_n_values)
	end = below = ce_n_values;
    }
  if (at_or_above < 0)
    lower = at_or_above = 0;
new_search:
  top_eq = -1;
  if (below == at_or_above)
    {
      if (CE_FIND_LAST == rc)
	itc->itc_ranges[set].r_end = at_or_above + row_of_ce;
      else
	itc->itc_ranges[set].r_first = itc->itc_ranges[set].r_end = at_or_above + row_of_ce;
      goto next_set;
    }
  for (;;)
    {
      if (below - at_or_above <= 1)
	{
	  if (CE_FIND_LAST == rc)
	    {
	      CEVC (at_or_above);
	      if (C_EQ && below == ce_n_values && (0 == nth_key || itc->itc_ranges[set].r_end - row_of_ce > ce_n_values))
		{
		  /* ends with match and is 1st key or later key with range extending after this ce */
		  goto more_after;
		}
	      if (C_GT)
		below--;
	      itc->itc_ranges[set].r_end = below + row_of_ce;
	      if (COL_NO_ROW == itc->itc_ranges[set].r_first)
		itc->itc_ranges[set].r_first = row_of_ce;
	      goto next_set;
	    }
	  if (0 == nth_key)
	    itc_range (itc, COL_NO_ROW, COL_NO_ROW);
	  CEVC (at_or_above);
	  if (C_LT)
	    {
	      at_or_above++;
	      if (at_or_above == end)
		{
		  itc->itc_ranges[set].r_first = at_or_above + row_of_ce;
		  if (at_or_above == ce_n_values)
		    {
		      itc->itc_ranges[set].r_first = COL_NO_ROW;
		      goto more_after;
		    }
		  itc->itc_ranges[set].r_end = at_or_above + row_of_ce;
		  goto next_set;
		}
	      CEVC (at_or_above);
	    }
	  if (C_GT)
	    {
	      itc->itc_ranges[set].r_first = itc->itc_ranges[set].r_end = at_or_above + row_of_ce;
	      if (below)
		below--;
	      goto next_set;
	    }
	  itc->itc_ranges[set].r_first = at_or_above + row_of_ce;
	  if (at_or_above >= end - 1)
	    {
	      if (itc->itc_ranges[set].r_end > end + row_of_ce)
		goto more_after;
	      itc->itc_ranges[set].r_end = at_or_above + 1 + row_of_ce;
	      goto next_set;
	    }
	  CEVC (at_or_above + 1);
	  if (C_EQ)
	    {
	      if (top_eq > at_or_above)
		at_or_above = top_eq;
	      below = end;
	      if (end == ce_n_values)
		{
		  CEVC (ce_n_values - 1);
		  if (C_EQ)
		    goto more_after;
		}
	      rc = CE_FIND_LAST;
	      continue;
	    }
	  itc->itc_ranges[set].r_end = at_or_above + 1 + row_of_ce;
	  goto next_set;
	}

      guess = at_or_above + ((below - at_or_above) / 2);
      CEVC (guess);
      if (C_EQ)
	{
	  if (CE_FIND_FIRST == rc)
	    {
	      below = guess;
	      if (-1 == top_eq)
		top_eq = guess;
	    }
	  else
	    at_or_above = guess;
	}
      else if (C_LT)
	at_or_above = guess;
      else
	below = guess;
    }
more_after:
  if (0 == itc->itc_nth_key)
    itc->itc_ranges[set].r_end = COL_NO_ROW;
  return CE_CONTINUES;
next_set:
  {
    int set_eq;
    if (itc->itc_reset_after_seg)
      return CE_DONE;
    rc = CE_FIND_FIRST;
    set++;
    if (itc->itc_n_sets <= set + itc->itc_col_first_set)
      return CE_SET_END;
    itc->itc_set = set + itc->itc_col_first_set;
    set_eq = itc_next_set_cmp (itc, nth_key);
    if (SET_EQ_RESET == set_eq)
      {
	itc->itc_set--;
	itc->itc_reset_after_seg = 1;
	return CE_DONE;
      }
    if (SET_ALL_EQ == set_eq)
      {
	set = itc->itc_set - itc->itc_col_first_set;
	if (0 == nth_key || set == itc->itc_range_fill)
	  itc_range (itc, 0, 0);
	itc->itc_ranges[set].r_first = itc->itc_ranges[set - 1].r_first;
	itc->itc_ranges[set].r_end = itc->itc_ranges[set - 1].r_end;
	goto next_set;
      }
    /* since key did not repeat, next set is to the right of the previous if 1. 1st key or initial range is eq */
    CE_END_CK;
    NEW_VAL;
    if (0 == nth_key)
      {
	at_or_above = below;
	below = ce_n_values;
	goto new_search;
      }
    if (SET_LEADING_EQ == set_eq && itc->itc_range_fill == set)
      {
	/* non 1st key part opens new range because open ended in previous key parts */
	itc_range (itc, COL_NO_ROW, COL_NO_ROW);
	at_or_above = below;
	end = below = ce_n_values;
	if (at_or_above == below)
	  return CE_DONE;	/* here this means at end of ce, in mid ce this means can go to next set */
	goto new_search;
      }
    at_or_above = itc->itc_ranges[set].r_first - row_of_ce;
    if (at_or_above < 0)
      at_or_above = 0;
    end = below = itc->itc_ranges[set].r_end - row_of_ce;
    if (below > ce_n_values)
      end = below = ce_n_values;
    goto new_search;
  }
}


#undef COL_VAR
#undef CE_LEN
#undef CEVC
#undef C_EQ
#undef C_GT
#undef C_LT
#undef NEW_VAL
#undef ce_search_name
#undef CE_DTP

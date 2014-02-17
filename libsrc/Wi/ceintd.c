/*
 *  ceintd.c
 *
 *  $Id$
 *
 *  Column Compression
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
ce_name (col_pos_t * cpo, db_buf_t ce_first, int n_values, int n_bytes)
{
  it_cursor_t *itc = cpo->cpo_itc;
  int64 base, base_1, first;
  db_buf_t ce = cpo->cpo_ce;
  db_buf_t ce_first_val, ce_end = ce_first + n_bytes;
  VALUE_VARS;
  int first_len;
  int skip = cpo->cpo_skip;
  uint32 d, run, run1;
  dtp_t flags = *cpo->cpo_ce;
  int last_row = cpo->cpo_ce_row_no;
#ifdef CEINTD_RANGE
  int last_of_ce = MIN (last_row + n_values, cpo->cpo_to);
#else
  int target, last_of_ce = last_row + n_values;
#endif
  CE_FIRST;
  FILTER_VALUES;
  if (!CE_INTLIKE (flags))
    {
      if (DV_DATE == any_ce_dtp (ce_first_val))
	{
	  run1 = run = ce_first_val[3];
	  base_1 = 0;
	}
      else
	{
	  base_1 = 0;
	  run1 = run = (dtp_t) ce_first[-1];
	}
    }
  else
    {
      base_1 = 0;
      run1 = run = ce_first_int_low_byte (ce, ce_first);
    }
  base = base_1;
  while (ce_first < ce_end)
    {
      if (!run)
	;
      else if (skip >= run)
	{
	  skip -= run;
	  last_row += run;
	}
      else
	{
	  /* get values from this run */
	  int last = MIN (run, cpo->cpo_to - last_row), inx;
	  int skip2 = skip;
	  last_row += skip;
	  skip = 0;
	  for (inx = skip2; inx < last; inx++)
	    {
	      uint64 n = SHORT_REF_CA (ce_first + 2 * inx);
	    repeating_place:
	      CE_OP;

#ifdef CEINTD_RANGE
	      last_row++;
	      if (last_row > last_of_ce)
		return last_row;
#else
	      if (++itc->itc_match_in >= itc->itc_n_matches)
		return CE_AT_END;
	      target = itc->itc_matches[itc->itc_match_in];
	      if (target == last_row)
		goto repeating_place;
	      if (target > last_of_ce)
		return target;
	      last_row++;
	      if (target > last_row)
		{
		  if (target - last_row < last - inx)
		    {
		      int fwd = target - last_row;
		      inx += fwd;
		      last_row += fwd;
		      continue;
		    }
		  skip = target - start_of_run - run;
		  last_row = start_of_run + run;
		  break;
		}
#endif
	    }
	}
      ce_first += run * 2;
      if (ce_first >= ce_end)
	break;
      d = LONG_REF_NA (ce_first);
      ce_first += 4;
      run = d & 0xff;
      base = base_1 + (d & CLEAR_LOW_BYTE);
    }
#ifdef CEINTD_RANGE
  return cpo->cpo_ce_row_no + n_values;
#else
  return itc->itc_match_in >= itc->itc_n_matches ? CE_AT_END : itc->itc_matches[itc->itc_match_in];
#endif
}



#undef ce_name
#undef CEINTD_RANGE

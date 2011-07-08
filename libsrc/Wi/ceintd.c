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


int
ce_name (col_pos_t * cpo, db_buf_t ce_first, int n_values, int n_bytes)
{
  it_cursor_t *itc = cpo->cpo_itc;
  int64 base, base_1, first;
  db_buf_t ce = cpo->cpo_ce;
  db_buf_t ce_first_val, ce_end;
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
  if (!CEINTD_INTLIKE)
    {
      if (DV_DATE == any_ce_dtp (ce_first_val))
	{
	  base = DT_DAY (ce_first_val + 1);
	  run1 = run = base & 0xff;
	  base_1 = base = (base & CLEAR_LOW_BYTE) - base + run1;
	}
      else
	{
	  first = LONG_REF_NA (ce_first - 4);
	  base = base_1 = 0;
	  run1 = run = first & 0xff;
	}
    }
  else
    {
      base_1 = base = first & CLEAR_LOW_BYTE;
      run1 = run = first & 0xff;
    }
  ce_end = ce + n_bytes;
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
	      uint32 n = SHORT_REF_CA (ce_first + 2 * inx);
	      CE_OP;

#ifdef CEINTD_RANGE
	      last_row++;
	      if (last_row > last_of_ce)
		return last_row;
#else
	      if (++itc->itc_match_in >= itc->itc_n_matches)
		return CE_AT_END;
	      target = itc->itc_matches[itc->itc_match_in];
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
  return cpo->cpo_ce_row_no + n_values;
}

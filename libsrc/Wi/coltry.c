/*
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

void
NAME (compress_state_t * cs, int from, int to, int *first_dtp_ret)
{
  int inx, n_asc = 0;
  int last_compressed = from - 1;
  int first_asc = -1;
  DTP prev = (DTP) cs->cs_numbers[from];
  for (inx = from + 1; inx < to; inx++)
    {
      DTP val = (DTP) cs->cs_numbers[inx];
      if (val >= prev)
	{
	  if (-1 == first_asc)
	    first_asc = inx - 1;
	  n_asc++;
	}
      else
	{
	  if (n_asc > min_asc)
	    {
	      cs_best_rnd (cs, last_compressed + 1, first_asc);
	      cs_best_asc (cs, first_asc, inx);
	      if (0 && cs->cs_asc_fill > cs->cs_asc_cutoff && cs->cs_asc_reset)
		return;
	      last_compressed = inx - 1;
	      n_asc = 0;
	      first_asc = -1;
	    }
	  else
	    {
	      first_asc = -1;
	      n_asc = 0;
	    }
	}
      prev = val;
    }
  if (n_asc > min_asc)
    {
      cs_best_rnd (cs, last_compressed + 1, first_asc);
      cs_best_asc (cs, first_asc, to);
    }
  else
    cs_best_rnd (cs, last_compressed + 1, to);
  *first_dtp_ret = from;
}

#undef NAME
#undef DTP

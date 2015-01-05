/*
 *  cedict1.c
 *
 *  $Id$
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


int
ce_search_name (db_buf_t ce, int below, int64 value, dtp_t dtp, dtp_t flags
#ifdef HAS_NCAST_EQ
    , int *is_ncast_eq		/* if insert into dict and val is binary different but artm eq, dict representation will not apply, set flag for this */
#endif
    )
{
  int at_or_above = 0, guess, end = below;
  COL_VAR;
  for (;;)
    {
      if (below - at_or_above <= 1)
	{
	  CEVC (at_or_above);
	  if (C_LT)
	    {
	      at_or_above++;
	      if (at_or_above == end)
		return end * 2 + 1;
	      CEVC (at_or_above);
	      if (C_EQ)
		return at_or_above * 2;
	      return at_or_above * 2 - 1;
	    }
	  if (C_GT)
	    return at_or_above * 2 - 1;
	  return at_or_above * 2;
	}
      guess = at_or_above + ((below - at_or_above) / 2);
      CEVC (guess);
      if (C_EQ)
	return guess * 2;
      if (C_LT)
	at_or_above = guess;
      else
	below = guess;
    }
}


#undef ce_search_name
#undef CEVC
#undef C_GT
#undef C_LT
#undef C_EQ
#undef COL_VAR

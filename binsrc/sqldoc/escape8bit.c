/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2013 OpenLink Software
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
 *  
*/
#include <stdio.h>

int main (void)
{
  int c, prev_esc = 0;
  while (EOF != (c = getchar()))
    {
      if ((c & 0x80) || 
	  (!(c & ~0x1f) && ('\r' != c) && ('\n' != c) && ('\t' != c)) ||
	  (prev_esc && (c >= '0') && (c <= '7')) )
        {
	  printf ("\\%d%d%d", (c >> 6), 7 & (c >> 3), 7 & c);
	  prev_esc = 1;
	}
      else
        {
	  putchar (c);
	  prev_esc = 0;
	}
    }
  return 0;
}

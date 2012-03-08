/*
 *  virt_wcsnrtombs.c
 *
 *  $Id$
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2012 OpenLink Software
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

#include "libutil.h"

size_t
virt_wcsnrtombs (unsigned char * dst, wchar_t ** src, size_t nwc, size_t len, virt_mbstate_t *ps)
{
  size_t written = 0;
  wchar_t *run = src[0];
  static virt_mbstate_t internal;

  if (ps == NULL)
    ps = &internal;

  if (dst == NULL)
    /* The LEN parameter has to be ignored if we don't actually write
       anything.  */
    len = ~0;

  while (written < len && nwc-- > 0)
    {
      wchar_t wc = run[0];
      run++;

      if (wc & ~0x7fffffff)
	{
	  /* This is no correct ISO 10646 character.  */
	  /* errno = (EILSEQ); */
#ifdef MULTIBYTE_SANITY
	  GPF_T;
#endif
	  return (size_t) -1;
	}
#ifdef MULTIBYTE_SANITY
      if (0 == wc)
	{
	  GPF_T;
	}
#endif
      if (!(wc & ~0x7f))
	{
	  /* It's an one byte sequence.  */
	  if (dst != NULL)
	    *dst++ = (char) wc;
	  ++written;
	}
      else
	{
	  size_t step;

	  for (step = 2; step < 6; ++step)
	    if ((wc & virt_utf8_encoding_mask[step - 2]) == 0)
	      break;

	  if (written + step >= len)
	    {
	      /* Too long.  */
	      run -= 1;
	      break;
	    }

	  if (dst != NULL)
	    {
	      size_t cnt = step;

	      dst[0] = virt_utf8_encoding_byte[cnt - 2];

	      --cnt;
	      do
		{
		  dst[cnt] = 0x80 | (wc & 0x3f);
		  wc >>= 6;
		}
	      while (--cnt > 0);
	      dst[0] |= wc;

	      dst += step;
	    }

	  written += step;
	}
    }

  /* Store position of first unprocessed word.  */
  *src = run;

  return written;
}



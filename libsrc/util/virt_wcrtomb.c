/*
 *  virt_wcrtomb.c
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
virt_wcrtomb (unsigned char *s, wchar_t wc, virt_mbstate_t *ps)
{
  char fake[1];
  size_t written = 0;
  static virt_mbstate_t internal;


  if (ps == NULL)
    ps = &internal;

  if (s == NULL)
    {
      s = (unsigned char *) fake;
      wc = L'\0';
    }

  /* Store the UTF8 representation of WC.  */
  if (wc < 0 || wc > 0x7fffffff)
    {
      /* This is no correct ISO 10646 character.  */
      /* errno  = (EILSEQ); */
      return (size_t) -1;
    }

  if (wc < 0x80)
    {
      /* It's a one byte sequence.  */
      if (s != NULL)
	*s = (char) wc;
      return 1;
    }

  for (written = 2; written < 6; ++written)
    if ((wc & virt_utf8_encoding_mask[written - 2]) == 0)
      break;

  if (s != NULL)
    {
      size_t cnt = written;
      s[0] = virt_utf8_encoding_byte[cnt - 2];

      --cnt;
      do
	{
	  s[cnt] = 0x80 | (wc & 0x3f);
	  wc >>= 6;
	}
      while (--cnt > 0);
      s[0] |= wc;
    }

  return written;
}



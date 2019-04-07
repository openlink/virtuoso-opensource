/*
 *  virt_mbsnrtowcs.c
 *
 *  $Id$
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2019 OpenLink Software
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
virt_mbsnrtowcs (wchar_t * dst, const unsigned char ** src, size_t nmc, size_t len, virt_mbstate_t * ps)
{
  size_t written = 0;
  char *run = (char *) *src;
  char *last = run + nmc;
  static virt_mbstate_t internal;

  if (ps == NULL)
    ps = &internal;

  if (dst == NULL)
    /* The LEN parameter has to be ignored if we don't actually write
       anything.  */
    len = ~0;

  /* Copy all words.  */
  while (written < len && run < last)
    {
      wchar_t value;
      size_t count;
      unsigned char byte = *run++;

      /* We expect a start of a new multibyte character.  */
      if (byte < 0x80)
	{
	  /* One byte sequence.  */
	  count = 0;
	  value = byte;
	}
      else if ((byte & 0xe0) == 0xc0)
	{
	  count = 1;
	  value = byte & 0x1f;
	}
      else if ((byte & 0xf0) == 0xe0)
	{
	  /* We expect three bytes.  */
	  count = 2;
	  value = byte & 0x0f;
	}
      else if ((byte & 0xf8) == 0xf0)
	{
	  /* We expect four bytes.  */
	  count = 3;
	  value = byte & 0x07;
	}
      else if ((byte & 0xfc) == 0xf8)
	{
	  /* We expect five bytes.  */
	  count = 4;
	  value = byte & 0x03;
	}
      else if ((byte & 0xfe) == 0xfc)
	{
	  /* We expect six bytes.  */
	  count = 5;
	  value = byte & 0x01;
	}
      else
	{
	  /* This is an illegal encoding.  */
	  /* errno = (EILSEQ); */
	  return (size_t) -1;
	}

      /* Read the possible remaining bytes.  */
      while (count-- > 0)
	{
	  byte = *run++;

	  if ((byte & 0xc0) != 0x80)
	    {
	      /* This is an illegal encoding.  */
	      /* errno = (EILSEQ); */
	      return (size_t) -1;
	    }

	  value <<= 6;
	  value |= byte & 0x3f;
	}

      /* Store value is required.  */
      if (dst != NULL)
	*dst++ = value;

      /* The whole sequence is read.  Check whether end of string is
	 reached.  */
/* This is an invalid 'if', it fails on reading
wide blob like
concat(UnicodeGammaSeq(128,3,65536), UnicodeGammSeq(64,3,127))
      if (value == L'\0')
	{
	  / * Found the end of the string.  * /
	  *src = NULL;
	  return written;
	}
The following 'if' should be used instead. */
      if (value == L'\0' && run == last)
	{
	  /* Found the end of the string.  */
	  *src = (unsigned char *) run;
	  return written;
	}

      /* Increment counter of produced words.  */
      ++written;
    }

  /* Store address of next byte to process.  */
  *src = (unsigned char *) run;

  return written;
}

/*
 *  virt_mbrlen_z.c
 *
 *  Variant of virt_mbrlen that treats zeroes as plain chars
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
 *  
*/

#include "libutil.h"

size_t
virt_mbrlen_z (const char *s, size_t n, virt_mbstate_t *ps)
{
  size_t used = 0;
  static virt_mbstate_t internal;

  if (ps == NULL)
    ps = &internal;

  if (s == NULL)
    {
      s = (unsigned char *) "";
      n = 1;
    }

  if (n > 0)
    {
      if (ps->count == 0)
        {
          unsigned char byte = (unsigned char) *s++;
          ++used;

          /* We must look for a possible first byte of a UTF8 sequence.  */
          if (!(byte & 0x80))
            return used;
          if ((byte & 0xc0) == 0x80 || (byte & 0xfe) == 0xfe)
            return (size_t) -1;
          if ((byte & 0xe0) == 0xc0)
            {
              /* We expect two bytes.  */
              ps->count = 1;
              ps->value = byte & 0x1f;
            }
          else if ((byte & 0xf0) == 0xe0)
            {
              /* We expect three bytes.  */
              ps->count = 2;
              ps->value = byte & 0x0f;
            }
          else if ((byte & 0xf8) == 0xf0)
            {
              /* We expect four bytes.  */
              ps->count = 3;
              ps->value = byte & 0x07;
            }
          else if ((byte & 0xfc) == 0xf8)
            {
              /* We expect five bytes.  */
              ps->count = 4;
              ps->value = byte & 0x03;
            }
          else
            {
              /* We expect six bytes.  */
              ps->count = 5;
              ps->value = byte & 0x01;
            }
        }
      /* We know we have to handle a multibyte character and there are
         some more bytes to read.  */
      while (used < n)
        {
          /* The second to sixths byte must be of the form 10xxxxxx.  */
          unsigned char byte = (unsigned char) *s++;
          ++used;

          if ((byte & 0xc0) != 0x80)
            {
              return (size_t) -1;
            }
          ps->value <<= 6;
          ps->value |= byte & 0x3f;
          if (--ps->count == 0)
            {
              return used;
            }
        }
    }
  return (size_t) -2;
}

/*
 *  wsclen.c
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

#ifdef __APPLE__
#include <stdlib.h>
size_t wcslen (s) const wchar_t *s;
{
  size_t len = 0;

  while (s[len] != L'\0')
    {
      if (s[++len] == L'\0')
	return len;
      if (s[++len] == L'\0')
	return len;
      if (s[++len] == L'\0')
	return len;
      ++len;
    }

  return len;
}

int wcscmp (s1, s2) const wchar_t *s1;  const wchar_t *s2;
{
  unsigned int c1, c2;

  do
    {
      c1 = *s1++;
      c2 = *s2++;
      if (c1 == L'\0')
	return c1 - c2;
    }
  while (c1 == c2);

  return c1 - c2;
}

wchar_t * wcscpy (dest, src) wchar_t *dest; const wchar_t *src;
{
  wchar_t *wcp = (wchar_t *) src;
  unsigned int c;
  int off = dest - src - 1;

  do
    {
      c = *wcp++;
      wcp[off] = c;
    }
  while (c != L'\0');

  return dest;
}

wchar_t * wcsncpy (dest, src, n) wchar_t *dest; const wchar_t *src; size_t n;
{
  unsigned int c;
  wchar_t *const s = dest;

  --dest;

  if (n >= 4)
    {
      size_t n4 = n >> 2;

      for (;;)
	{
	  c = *src++;
	  *++dest = c;
	  if (c == L'\0')
	    break;
	  c = *src++;
	  *++dest = c;
	  if (c == L'\0')
	    break;
	  c = *src++;
	  *++dest = c;
	  if (c == L'\0')
	    break;
	  c = *src++;
	  *++dest = c;
	  if (c == L'\0')
	    break;
	  if (--n4 == 0)
	    goto last_chars;
	}
      n = n - (dest - s) - 1;
      if (n == 0)
	return s;
      goto zero_fill;
    }

last_chars:
  n &= 3;
  if (n == 0)
    return s;

  do
    {
      c = *src++;
      *++dest = c;
      if (--n == 0)
	return s;
    }
  while (c != L'\0');

zero_fill:
  do
    *++dest = L'\0';
  while (--n > 0);

  return s;
}


wchar_t *
     wcscat (dest, src)
     wchar_t *dest;
     const wchar_t *src;
{
  register wchar_t *s1 = dest;
  register const wchar_t *s2 = src;
  wchar_t c;
  do
  c = *s1++;
  while (c != L'\0');
  s1 -= 2;
      
  do
     {
        c = *s2++;
        *++s1 = c;
     }
  while (c != L'\0');
      
  return dest;
}

wchar_t *
wcsncat (dest, src, n)
     wchar_t *dest;
     const wchar_t *src;
     size_t n;
{
  wchar_t c;
  wchar_t * const s = dest;

  /* Find the end of DEST.  */
  do
    c = *dest++;
  while (c != L'\0');

  /* Make DEST point before next character, so we can increment
     it while memory is read (wins on pipelined cpus).  */
  dest -= 2;

  if (n >= 4)
    {
      size_t n4 = n >> 2;
      do
        {
          c = *src++;
          *++dest = c;
          if (c == L'\0')
            return s;
          c = *src++;
          *++dest = c;
          if (c == L'\0')
            return s;
          c = *src++;
          *++dest = c;
          if (c == L'\0')
            return s;
          c = *src++;
          *++dest = c;
          if (c == L'\0')
            return s;
        } while (--n4 > 0);
      n &= 3;
    }
   while (n > 0)
    {
      c = *src++;
      *++dest = c;
      if (c == L'\0')
        return s;
      n--;
    }

  if (c != L'\0')
    *++dest = L'\0';

  return s;
}

#endif

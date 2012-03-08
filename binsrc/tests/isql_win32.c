/*
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
 */

#include <locale.h>
#include <stdlib.h>
#include <Dk.h>
#include "isql_tchar.h"

static wchar_t *
malloc_narrow_as_wide (char *narrow)
{
  wchar_t *ret;
  size_t sz;

  if (!narrow)
    return NULL;

  sz = MultiByteToWideChar (CP_OEMCP, 0, narrow, (int) strlen (narrow), NULL, 0);

  if (sz < 0)
    *((long *) -1) = -1;

  ret = calloc (sz + 1, sizeof (wchar_t));

  MultiByteToWideChar (CP_OEMCP, 0, narrow, (int) strlen (narrow), ret, sz);
  return ret;
}

static char *
malloc_wide_as_narrow (const wchar_t *wide)
{
  char *ret;
  size_t sz;

  if (!wide)
    return NULL;
  sz = WideCharToMultiByte (CP_OEMCP, 0, wide, (int) wcslen (wide), NULL, 0, NULL, NULL);

  if (sz < 0)
    *((long *) -1) = -1;

  ret = calloc (sz + 1, sizeof (char));

  WideCharToMultiByte (CP_OEMCP, 0, wide, (int) wcslen (wide), ret, sz, NULL, NULL);

  return ret;
}


int
isqlt_fwprintf(FILE *stream, const wchar_t *format, ...)
{
  va_list lst;
  int ret;
  wchar_t buffer[10000];
  char *nbuffer;

  va_start (lst, format);
  ret = _vsnwprintf (buffer, sizeof (buffer), format, lst);
  va_end (lst);
  nbuffer = malloc_wide_as_narrow (buffer);
  fprintf (stream, "%s", nbuffer);
  free (nbuffer);
  return (ret);
}

int
isqlt_wprintf(const wchar_t *format, ...)
{
  va_list lst;
  int ret;
  wchar_t buffer[10000];
  char *nbuffer;

  va_start (lst, format);
  ret = _vsnwprintf (buffer, sizeof (buffer), format, lst);
  va_end (lst);
  nbuffer = malloc_wide_as_narrow (buffer);
  printf ("%s", nbuffer);
  free (nbuffer);
  return (ret);
}

int
isqlt_fputws(const wchar_t *s, FILE *stream)
{
  char *nbuffer = malloc_wide_as_narrow (s);
  int ret;

  ret = fputs (nbuffer, stream);
  free (nbuffer);

  return ret;
}

int
isqlt_putwc(int c, FILE *stream)
{
  int ret;
  wchar_t buffer[2];
  char *nbuffer;

  buffer[0] = c;
  buffer[1] = 0;
  nbuffer = malloc_wide_as_narrow (buffer);
  ret = fputs (nbuffer, stream);
  free (nbuffer);
  return ret;
}

wchar_t *
isqlt_fgetws(wchar_t *s, int size, FILE *stream)
{
  char *buffer = malloc (size);
  wchar_t *wbuffer;

  if (buffer && fgets (buffer, size, stream))
    {
      wbuffer = malloc_narrow_as_wide (buffer);
      wcsncpy (s, wbuffer, size);
      free (wbuffer);
      return s;
    }

  if (wbuffer)
    free (wbuffer);

    return NULL;
}

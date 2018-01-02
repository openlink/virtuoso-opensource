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
  sz = mbstowcs (NULL, narrow, 0);

  if (sz < 0)
    *((long *) -1) = -1;

  ret = (wchar_t *) calloc (sz + 1, sizeof (wchar_t));

  mbstowcs (ret, narrow, sz);

  return ret;
}

static char *
malloc_wide_as_narrow (const wchar_t * wide)
{
  char *ret;
  size_t sz;

  if (!wide)
    return NULL;
  sz = wcstombs (NULL, wide, 0);

  if (sz < 0)
    *((long *) -1) = -1;

  ret = (char *) calloc (sz + 1, sizeof (char));

  wcstombs (ret, wide, sz);

  return ret;
}


extern int wmain (int argc, wchar_t * argv[]);

int
main (int argc, char *argv[])
{
  wchar_t **wargv = (wchar_t **) malloc (argc * sizeof (wchar_t *));
  int inx;
  char *locale = setlocale (LC_ALL, "");
  /* !!!!WARNING!!!! There's a GCC bug : if the *first* output call is not wide (wprintf/fwprintf)
     then *all* the subsequent wide output functions will *not* work */
  if (locale)
    wprintf (L"Locale=%s\n", setlocale (LC_ALL, ""));
  else
    wprintf (L"Can't apply the system locale. "
	L"Possibly wrong setting for LANG environment variable. " L"Using the C locale instead.\n");
  for (inx = 0; inx < argc; inx++)
    {
      wargv[inx] = malloc_narrow_as_wide (argv[inx]);
    }
  return wmain (argc, wargv);
}

#ifndef HAVE_SWPRINTF
int
isqlt_swprintf (wchar_t * str, const wchar_t * format, ...)
{
#if defined (linux) || defined (SOLARIS)
  va_list lst;
  int ret;
  va_start (lst, format);
  ret = vswprintf (str, 1000000, format, lst);
  va_end (lst);
  return ret;
#endif
}
#endif

#ifndef HAVE_WEXECVP
int
isqlt_wexecvp (const wchar_t * file, wchar_t * const argv[])
{
  char *nfile = malloc_wide_as_narrow (file);
  char **nargv;
  int inx, ret, argc = 0;

  for (inx = 0; argv[inx]; inx++)
    argc++;

  nargv = (char **) calloc (argc + 1, sizeof (char *));

  for (inx = 0; inx < argc; inx++)
    nargv[inx] = malloc_wide_as_narrow (argv[inx]);

  ret = execvp (nfile, nargv);
  for (inx = 0; nargv[inx]; inx++)
    free (nargv[inx]);
  free (nargv);
  return ret;
}
#endif

#ifndef HAVE_WSYSTEM
int
isqlt_wsystem (const wchar_t * string)
{
  int ret;
  char *nstring = malloc_wide_as_narrow (string);

  ret = system (nstring);
  free (nstring);

  return ret;
}
#endif

#ifndef HAVE_WTOI
int
isqlt_wtoi (const wchar_t * nptr)
{
  int ret;
  char *nstring = malloc_wide_as_narrow (nptr);

  ret = atoi (nstring);
  free (nstring);

  return ret;
}
#endif

#ifndef HAVE_WPERROR
void
isqlt_wperror (const wchar_t * s)
{
  char *nstring;
  int errno_save = errno;

  nstring = malloc_wide_as_narrow (s);
  errno = errno_save;

  perror (nstring);
  free (nstring);
}
#endif

#ifndef HAVE_WTOL
long
isqlt_wtol (const wchar_t * nptr)
{
  long ret;
  char *nstring = malloc_wide_as_narrow (nptr);

  ret = atol (nstring);
  free (nstring);

  return ret;
}
#endif

#ifndef HAVE_WFOPEN
FILE *
isqlt_wfopen (const wchar_t * path, const wchar_t * mode)
{
  FILE *ret;
  char *npath = malloc_wide_as_narrow (path);
  char *nmode = malloc_wide_as_narrow (mode);
  int errno_save;

  ret = fopen (npath, nmode);
  errno_save = errno;

  free (npath);
  free (nmode);
  errno = errno_save;
  return ret;
}
#endif

#ifndef HAVE_WGETENV
wchar_t *
isqlt_wgetenv (const wchar_t * name)
{
  char *nret;
  char *nname = malloc_wide_as_narrow (name);

  nret = getenv (nname);
  free (nname);

  return malloc_narrow_as_wide (nret);
}
#endif

#ifndef WIN32
#ifndef HAVE_WGETPASS
wchar_t *
isqlt_wgetpass (const wchar_t * prompt)
{
  char *nret;
  char *nprompt = malloc_wide_as_narrow (prompt);

  nret = getpass (nprompt);
  free (nprompt);

  return malloc_narrow_as_wide (nret);
}
#endif
#endif

#if defined (SOLARIS)
#ifndef HAVE_WGETPASSPHRASE
wchar_t *
isqlt_wgetpassphrase (const wchar_t * prompt)
{
  char *nret;
  char *nprompt = malloc_wide_as_narrow (prompt);

  nret = getpassphrase (nprompt);
  free (nprompt);

  return malloc_narrow_as_wide (nret);
}
#endif
#endif

#ifndef HAVE_WCSNICMP
int
isqlt_wcsnicmp (const wchar_t * s1, const wchar_t * s2, size_t n)
{
#if defined (HAVE_TOWLOWER) || defined (HAVE_TOWUPPER)
  int cmp;

  while (*s1 && n)
    {
      n--;
#if   defined (HAVE_TOWLOWER)
      if ((cmp = towlower (*s1) - towlower (*s2)) != 0)
	return cmp;
#elif defined (HAVE_TOWUPPER)
      if ((cmp = towupper (*s1) - towupper (*s2)) != 0)
	return cmp;
#endif
      s1++;
      s2++;
    }
  if (n)
    return (*s2) ? -1 : 0;
  return 0;
#else
  char *ns1 = malloc_wide_as_narrow (s1);
  char *ns2 = malloc_wide_as_narrow (s2);
  int ret;

  ret = strnicmp (ns1, ns2, n);
  free (ns1);
  free (ns2);
  return ret;
#endif
}
#endif


#ifndef HAVE_WCSICMP
int
isqlt_wcsicmp (const wchar_t * s1, const wchar_t * s2)
{
#if defined (HAVE_TOWLOWER) || defined (HAVE_TOWUPPER)
  int cmp;

  while (*s1)
    {
#if   defined (HAVE_TOWLOWER)
      if ((cmp = towlower (*s1) - towlower (*s2)) != 0)
	return cmp;
#elif defined (HAVE_TOWUPPER)
      if ((cmp = towupper (*s1) - towupper (*s2)) != 0)
	return cmp;
#endif
      s1++;
      s2++;
    }
  return (*s2) ? -1 : 0;
#else
  char *ns1 = malloc_wide_as_narrow (s1);
  char *ns2 = malloc_wide_as_narrow (s2);
  int ret;

  ret = stricmp (ns1, ns2);
  free (ns1);
  free (ns2);
  return ret;
#endif
}
#endif


#ifndef HAVE_WCSDUP
wchar_t *
isqlt_wcsdup (const wchar_t * s)
{
  int len = 0;
  wchar_t *ret, *ptr;

  if (!s)
    return NULL;

#ifdef HAVE_WCSLEN
  len = wcslen (s);
#else
  for (ptr = s; *ptr; ptr++)
    len++;
#endif
  len++;

  ret = malloc (len * sizeof (wchar_t));
  memcpy (ret, s, len * sizeof (wchar_t));
  return ret;
}
#endif

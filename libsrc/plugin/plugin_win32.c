/*
 *  plugin_win32.c
 *
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

#include <stdlib.h>
#include <stdio.h>
#include <windows.h>
#include "plugin.h"

static char *get_win_error (void)
{
  DWORD err;
  LPVOID errbuf = NULL;
  err = GetLastError();
  FormatMessage(
    FORMAT_MESSAGE_ALLOCATE_BUFFER |
    FORMAT_MESSAGE_FROM_SYSTEM |
    FORMAT_MESSAGE_IGNORE_INSERTS,
    NULL,
    err,
    MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
    (LPTSTR) &errbuf,
    0,
    NULL );
  if ((NULL != errbuf) && ('\0' != ((char *)errbuf)[0]))
    {
      char *last = (char *)errbuf;
      last += strlen(last)-1;
      if (('\n' == last[0]) || ('\r' == last[0]))
	last[0] = '\0';
    }
  return errbuf;
}

unit_version_t *uv_load_and_check_plugin(
  char *file_name, char *function_name,
  unit_version_t *dock_version, void *appdata)
{
  char fname[_MAX_PATH];
  int fnameidx;
  HMODULE dll;
  unit_check_t CALLBACK *check_callback;
  unit_version_t *res;
  FILE *test;
  for (fnameidx = 0; fnameidx < (_MAX_PATH-5); fnameidx++)
    {
      char c = file_name[fnameidx];
      if ('\0' == c)
	break;
      fname[fnameidx] = (('/' == c) ? '\\' : c);
    }
  strcpy (fname+fnameidx, ".dll");
  test = fopen (fname, "rb");
  if (NULL == test)
    {
      res = calloc (1, sizeof (unit_version_t));
      res->uv_filename = strdup (fname);
      res->uv_load_error = "Unable to locate file";
      return res;
    }
  fclose (test);
  dll = LoadLibrary (fname);
  if (NULL == dll)
    {
      res = calloc (1, sizeof (unit_version_t));
      res->uv_filename = strdup (fname);
      res->uv_load_error = get_win_error();
      return res;
    }
  if (NULL == function_name)
    {
      res = calloc (1, sizeof (unit_version_t));
      res->uv_filename = strdup (fname);
      res->uv_load_error = NULL;
      return res;
    }
  check_callback = (unit_check_t CALLBACK *) GetProcAddress (dll, function_name);
  if (NULL == check_callback)
    {
      FreeLibrary (dll);
      res = calloc (1, sizeof (unit_version_t));
      res->uv_filename = strdup (fname);
      res->uv_load_error = get_win_error();
      return res;
    }
  res = check_callback (dock_version, appdata);
  if (NULL == res)
    {
      FreeLibrary (dll);
      res = calloc (1, sizeof (unit_version_t));
      res->uv_filename = strdup (fname);
      res->uv_load_error = get_win_error();
      /* FreeLibrary (dll); -- result we will return now is in dll's address space */
      return res;
    }
  res->uv_filename = strdup (fname);
  if (NULL != res->uv_load_error)
    {
      /* FreeLibrary (dll); -- result we will return now is in dll's address space */
      return res;
    }
  if (NULL == res->uv_gate)
    {
      /* FreeLibrary (dll); -- result we will return now is in dll's address space */
      res->uv_load_error = "Loaded plugin is not compatible with your version of Windows";
      return res;
    }
  if (0 != _gate_export (res->uv_gate))
    {
      /* FreeLibrary (dll); -- result we will return now is in dll's address space */
      res->uv_load_error = "Loaded plugin requires core functionality not provided by main application";
      return res;
    }
  return res;
}

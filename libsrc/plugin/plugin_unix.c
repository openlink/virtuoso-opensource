/*
 *  plugin_unix.c
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
#include <string.h>
#include "Dk.h"
#include "plugin.h"
#include "dlf.h"

const char * so_extensions[] =
  { ".so", ".a" };
const int so_extensions_n = sizeof (so_extensions) / sizeof (const char*);

unit_version_t *uv_load_and_check_plugin(
  char *file_name, char *function_name,
  unit_version_t *dock_version, void *appdata)
{
  char fname[255];
  int fnameidx;
  unit_version_t *res;
  FILE *test;
  int so_ext_idx;
  void *dll;
  unit_check_t *check_callback;
  for (fnameidx = 0; fnameidx < (255-5); fnameidx++)
    {
      char c = file_name[fnameidx];
      if ('\0' == c)
	break;
      fname[fnameidx] = (('\\' == c) ? '/' : c);
    }
  for (so_ext_idx = 0; so_ext_idx < so_extensions_n; so_ext_idx++)
    {
      strcpy (fname+fnameidx, so_extensions[so_ext_idx]);
      test = fopen (fname, "rb");
      if (test)
	break;
    }
  if (NULL == test)
    {
      res = (unit_version_t *)calloc (1, sizeof (unit_version_t));
      res->uv_filename = (char *) strdup (fname);
      res->uv_load_error = "Unable to locate file";
      return res;
    }
  fclose (test);
  /* open so */
  dll = DLL_OPEN_GLOBAL (fname);
  if (NULL == dll)
    {
      res = (unit_version_t *)calloc (1, sizeof (unit_version_t));
      res->uv_filename = strdup (fname);
      res->uv_load_error = strdup (DLL_ERROR());
      return res;
    }
  if (NULL == function_name)
    {
      res = (unit_version_t *)calloc (1, sizeof (unit_version_t));
      res->uv_filename = strdup (fname);
      res->uv_load_error = NULL;
      return res;
    }
  check_callback = (unit_check_t *) DLL_PROC (dll, function_name);
  if (NULL == check_callback)
    {
      char * err = strdup (DLL_ERROR());
      DLL_CLOSE (dll);
      res = (unit_version_t *)calloc (1, sizeof (unit_version_t));
      res->uv_filename = strdup (fname);
      res->uv_load_error = err;
      return res;
    }
  res = check_callback (dock_version, appdata);
  res->uv_filename = strdup (fname);
  if (NULL != res->uv_load_error)
    {
      /* FreeLibrary (dll); -- result we will return now is in dll's address space */
      return res;
    }
  if (NULL == res->uv_gate)
    {
      /* FreeLibrary (dll); -- result we will return now is in dll's address space */
      res->uv_load_error = "Loaded plugin is not compatible with your version of OS";
      return res;
    }
  if (0 != _gate_export ((_gate_export_item_t *)(res->uv_gate)))
    {
      /* FreeLibrary (dll); -- result we will return now is in dll's address space */
      res->uv_load_error = "Loaded plugin requires core functionality not provided by main application";
      return res;
    }
  return res;
}

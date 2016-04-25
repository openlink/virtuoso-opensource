/*
 *  plugin.c
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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

#include <string.h>
#include "plugin.h"

#define MAX_PLUGIN_TYPES 32

struct plugin_type_s
{
  char *pt_name;
  plugin_load_callback *pt_loader;
  plugin_connect_callback *pt_connector;
};

typedef struct plugin_type_s plugin_type_t;

static plugin_type_t all_plugin_types[MAX_PLUGIN_TYPES];

int plugin_add_type(const char *plugin_type_name, plugin_load_callback *loader_for_type, plugin_connect_callback *connector)
{
  int ctr;
  for (ctr = 0; ctr < MAX_PLUGIN_TYPES; ctr++)
    {
      plugin_type_t *item = all_plugin_types+ctr;
      if (NULL == item->pt_name)
	{
	  item->pt_name = strdup (plugin_type_name);
	  item->pt_loader = loader_for_type;
	  item->pt_connector = connector;
	  return 0;
	}
      if (0 == strcmp(plugin_type_name, item->pt_name))
	{
	  item->pt_loader = loader_for_type;
	  item->pt_connector = connector;
	  return 0;
	}
    }
  /* Too many plugin types */
  return -1;
}

int plugin_load (
  const char *plugin_type, const char *plugin_dll_name, const char *plugin_load_path,
  int loadctr, plugin_log_callback *info_logger, plugin_log_callback *error_logger )
{
  int ctr;
  for (ctr = 0; ctr < MAX_PLUGIN_TYPES; ctr++)
    {
      plugin_type_t *item = all_plugin_types+ctr;
      if (NULL == item->pt_name)
	break;
      if (0 == strcmp (item->pt_name, plugin_type))
	{
	  unit_version_t *result;
	  char buf[1024];
	  int error;
	  info_logger ("{ Loading plugin %d: Type `%s', file `%s' in `%s'", loadctr, plugin_type, plugin_dll_name, plugin_load_path);
	  result = item->pt_loader (plugin_dll_name, plugin_load_path);
	  error = (NULL != result->uv_load_error);
	  buf[0] = '\0';
	  if (NULL != result->uv_title)
	    {
	      strcat (buf, result->uv_title);
	    }
	  if (NULL != result->uv_version)
	    {
	      strcat (buf, " version ");
	      strcat (buf, result->uv_version);
	    }
	  if (NULL != result->uv_companyname)
	    {
	      strcat (buf, " from ");
	      strcat (buf, result->uv_companyname);
	    }
	  if (buf[0] != '\0')
	    info_logger ("  %s", buf);
	  if ((NULL != result->uv_comments) && ('\0' != result->uv_comments[0]))
	    info_logger ("  %s", result->uv_comments);
	  if (!error)
	    item->pt_connector (result);
	  if (error)
	    error_logger ("  FAILED  plugin %d: %s }", loadctr, result->uv_load_error);
	  else
	    info_logger ("  SUCCESS plugin %d: loaded from %s }", loadctr, result->uv_filename);
	  return (error ? -2 : 0);
	}
    }
  error_logger ("{ Loading plugin %d: FAILED  plugin %d: Unknown type specified for plugin }", loadctr, loadctr);
  return -1;
}


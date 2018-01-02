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

#include "libutil.h"
#include "wi.h"
#include "sqlver.h"
#include <plugin.h>

#ifndef WIN32
#include <dirent.h>
#endif

#include "msdtc.h"

msdtc_version_t * msdtc_plugin = 0;

#define PLUGIN_DIR "plugin"

#ifndef HAVE_DIRECT_H
#define DIRNAME(de)	 de->d_name
#define CHECKFH(df)	 (df != NULL)
#else
#define DIRNAME(de)	 de->name
#define CHECKFH(df)	 (df != -1)
#define S_IFLNK	 S_IFREG
#endif

unit_version_t plain_plugin_version = {
  PLAIN_PLUGIN_TYPE,	 		/*!< Title of unit, filled by unit */
  DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR,/*!< Version number, filled by unit */
  "OpenLink Software",			/*!< Plugin's developer, filled by unit */
  NULL,					/*!< Any additional info, filled by unit */
  NULL, 					/*!< Error message, filled by unit loader */
  NULL, 					/*!< Name of file with unit's code, filled by unit loader */
  NULL, 					/*!< Pointer to connection function, cannot be NULL */
  NULL, 					/*!< Pointer to disconnection function, or NULL */
  NULL, 					/*!< Pointer to activation function, or NULL */
  NULL, 					/*!< Pointer to deactivation function, or NULL */
  NULL					/*!< Platform-specific data for run-time linking tricks */
};

unit_version_t msdtc_plugin_version = {
  MSDTC_PLUGIN_TYPE,	 		/*!< Title of unit, filled by unit */
  DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR,/*!< Version number, filled by unit */
  "OpenLink Software",			/*!< Plugin's developer, filled by unit */
  NULL,					/*!< Any additional info, filled by unit */
  NULL, 					/*!< Error message, filled by unit loader */
  NULL, 					/*!< Name of file with unit's code, filled by unit loader */
  NULL, 					/*!< Pointer to connection function, cannot be NULL */
  NULL, 					/*!< Pointer to disconnection function, or NULL */
  NULL, 					/*!< Pointer to activation function, or NULL */
  NULL, 					/*!< Pointer to deactivation function, or NULL */
  NULL					/*!< Platform-specific data for run-time linking tricks */
};

/* removes .so if file in form blabla.so or blabla.so.x*/
caddr_t make_plugin_name (const char * fullname)
{
  if (fullname)
    {
      const char * point = strrchr (fullname, '.');
      /* check .so\0 */
      if (point && point[1] == 's' && point[2] == 'o' && !point[3])
	return box_dv_short_nchars (fullname, point - fullname);
      if (point && point[1] == 's' && point[2] == 'o' && '.' == point[3])
	return box_dv_short_nchars (fullname, point - fullname);
      /* .dll */
      if (point && !stricmp (point, "dll"))
	return box_dv_short_nchars (fullname, point - fullname);
    }
  return box_string (fullname);
}

unit_version_t *plain_plugin_load (const char *plugin_dll_name, const char *plugin_load_path)
{
  char *filename, *funname;
  char *plugin_name = make_plugin_name (plugin_dll_name);
  filename = (char *) dk_alloc (strlen (plugin_load_path) + 1 + strlen (plugin_name) + 1);
  snprintf (filename, strlen (plugin_load_path) + 1 + strlen (plugin_name) + 1, "%s/%s", plugin_load_path, plugin_name);
  funname = (char *) dk_alloc (strlen (plugin_name) + 6 + 1 /* == strlen ("_check") */ + 1);
  snprintf (funname, strlen (plugin_name) + 6 + 1, "%s_check", plugin_name);
  dk_free_box (plugin_name);
  return uv_load_and_check_plugin (filename, funname, &plain_plugin_version, NULL);
}

unit_version_t *msdtc_plugin_load (const char *plugin_dll_name, const char *plugin_load_path)
{
  char *filename, *funname;
  char *plugin_name = make_plugin_name (plugin_dll_name);
  unit_version_t * res;
  filename = (char *) dk_alloc (strlen (plugin_load_path) + 1 + strlen (plugin_name) + 1);
  snprintf (filename, strlen (plugin_load_path) + 1 + strlen (plugin_name) + 1, "%s/%s", plugin_load_path, plugin_name);
  funname = (char *) dk_alloc (strlen (plugin_name) + 6 /* == strlen ("_check") */ + 1);
  snprintf (funname, strlen (plugin_name) + 6 + 1, "%s_check", plugin_name);
  dk_free_box (plugin_name);
  res = uv_load_and_check_plugin (filename, funname, (unit_version_t*) &msdtc_plugin_version, NULL);
  if (!res->uv_load_error)
    msdtc_plugin = (msdtc_version_t*) res;
  if (!msdtc_plugin)
    {
      log_warning ("2PC: MS DTC is not available, so plugin could not be loaded.");
    }
  return res;
}

unit_version_t *attach_plugin_load (const char *plugin_dll_name, const char *plugin_load_path)
{
  char *filename;
  char *plugin_name = make_plugin_name (plugin_dll_name);
  filename = (char *) dk_alloc (strlen (plugin_load_path) + 1 + strlen (plugin_name) + 1);
  snprintf (filename, strlen (plugin_load_path) + 1 + strlen (plugin_name) + 1, "%s/%s", plugin_load_path, plugin_name);
  dk_free_box (plugin_name);
  return uv_load_and_check_plugin (filename, NULL, NULL, NULL);
}


/*! \brief Type of function registered via plugin_add_type and used by
    plugin_load to invoke uv_connect of a plugin with proper appdata */
void plain_plugin_connect (const unit_version_t *plugin)
{
  UV_CALL (plugin, uv_connect, NULL);
}


/* the attach plugin is meant to attach shared libraries to the
   executable without further actions or checks. This helps to
   solve the situation where a (hosting) plugin depends on other
   local shared libraries that wouldn't load if Virtuoso is running
   on unix as root */
void attach_plugin_connect (const unit_version_t *plugin)
{
}


void plugin_loader_init()
{
  if (-1 == plugin_add_type(PLAIN_PLUGIN_TYPE, plain_plugin_load, plain_plugin_connect))
    {
      log_error ("Could not add plain plugin type");
      return;
    }
  if (-1 == plugin_add_type(MSDTC_PLUGIN_TYPE, msdtc_plugin_load, plain_plugin_connect))
    {
      log_error ("Could not add msdtc plugin type");
      return;
    }
  if (-1 == plugin_add_type(ATTACH_PLUGIN_TYPE, attach_plugin_load, attach_plugin_connect))
    {
      log_error ("Could not add attach plugin type");
      return;
    }
}


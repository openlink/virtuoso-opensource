/*
 *  plugin.h
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
 */

#ifndef _PLUGIN_H
#define _PLUGIN_H

/*! \file
\brief System-independent interface between dock (executable) and plugin (DLL)

There are many OS-specific APIs for loading DLLs to an executable. Similarly,
version info structures are vary from OS to OS. To write plugin/dock logic
easily, small system-independent interface is specified.

To attach a plugin, dock locates DLL file and loads it into memory. Then it
calls plugin check function, and passes dock's version info and some
application-specific data about dock's internal state. If check function
"agrees" that its plugin may be connected to given dock, it returns
plugin's version info with no error diagnostics inside, otherwise it returns
info with an error. Dock may call plugin check function more than
once, e.g. with different instances of dock's version info.

If plugin returns no errors, it may be connected to dock. At this time, plugin may
do some long initializations, sanity checks etc. If it still reports no
errors, it may be activated. For time-critical applications, it's good idea
to connect all pugins before starting time-critical operations, then
activate all of them.

Similarly, plugin may be deactivated and disconnected later.

Plugin's (dis-)connection and (de-)activation functions may be called more
than once, and in any order. There's only one rule: while function is listed
in plugin's unit_version_s structure, it may be called. To avoid calling of
the function, set the appropriate field of structure to NULL. */

struct unit_version_s;

typedef void unit_control_func_t (void *appdata);

struct unit_version_s
{
  char *uv_title;			/*!< Title of unit, filled by unit */
  char *uv_version;			/*!< Version number, filled by unit */
  char *uv_companyname;			/*!< Plugin's developer, filled by unit */
  char *uv_comments;			/*!< Any additional info, filled by unit */
  char *uv_load_error;			/*!< Error message, filled by unit loader */
  char *uv_filename;			/*!< Name of file with unit's code, filled by unit loader */
  unit_control_func_t *uv_connect;	/*!< Pointer to connection function, cannot be NULL */
  unit_control_func_t *uv_disconnect;	/*!< Pointer to disconnection function, or NULL */
  unit_control_func_t *uv_activate;	/*!< Pointer to activation function, or NULL */
  unit_control_func_t *uv_deactivate;	/*!< Pointer to deactivation function, or NULL */
  void *uv_gate;			/*!< Platform-specific data for run-time linking tricks */
};

typedef struct unit_version_s unit_version_t;

typedef unit_version_t *unit_check_t (unit_version_t *dock_info, void *appdata);

/*! \brief OS-dependent function for loading plugin's DLL and running its check function */
extern unit_version_t *uv_load_and_check_plugin(
  char *file_name, char *function_name,
  unit_version_t *dock_version, void *appdata);

/*! \brief Typical call of some member function of unit_version_s */
#define UV_CALL(uv,member,appdata) \
{ \
  if (uv->member && !uv->uv_load_error) \
    uv->member(appdata); \
}

/*! \brief Type of function registered via plugin_add_type and used by
    plugin_load to invoke uv_load_and_check_plugin */
typedef unit_version_t *plugin_load_callback (const char *plugin_dll_name, const char *plugin_load_path);

/*! \brief Type of function registered via plugin_add_type and used by
    plugin_load to invoke uv_connect of a plugin with proper appdata */
typedef void plugin_connect_callback (const unit_version_t *plugin);

/* \brief Type of function to call for logging messages or errors */
typedef void plugin_log_callback (char *format, ...);

/*! \brief Registers new type of plugin, as symbolic name for specific load callback, returns zero for success */
extern int plugin_add_type(const char *plugin_type, plugin_load_callback *loader_for_type, plugin_connect_callback *connector);

/*! \brief Tries to select proper plugin loader for given type, and invoke it
    to load and check given plugin DLL. Typical errors will be logged. Returns 0 for success. */
extern int plugin_load (
  const char *plugin_type, const char *plugin_dll_name, const char *plugin_load_path,
  int loadctr, plugin_log_callback *info_logger, plugin_log_callback *error_logger );

#if !defined(CALLBACK) && !defined(WIN32)
#define CALLBACK
#endif

/* list of supported plugins */
#define PLAIN_PLUGIN_TYPE	"plain"
#define MSDTC_PLUGIN_TYPE	"msdtc"
#define ATTACH_PLUGIN_TYPE	"attach"

#endif

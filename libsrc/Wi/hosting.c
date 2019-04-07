/*
 *  hosting.c
 *
 *  $Id$
 *
 *  hosting languages plugin type handler
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
 */

#define HOSTING_DEFINE_GLOBALS 1
#include "Dk.h"
#include "libutil.h"
#include "wi.h"
#include <plugin/dlf.h>
#include "hosting.h"
#include "sqlver.h"
#include "sqlnode.h"
#include "sqlbif.h"
#include "security.h"

#undef free

#ifndef __NO_LIBDK

#define SET_DLL_PROC(hres,ht,name,err_if_no) \
  hres->hv_##ht = (hv_##ht##_t) DLL_PROC (dll, name); \
  if (err_if_no && NULL == hres->hv_##ht) \
    { \
      char *err, *sys_err; \
      sys_err = DLL_ERROR (); \
      err = strdup (sys_err ? sys_err : ""); \
      res->uv_load_error = err; \
      return hres; \
    }

static hosting_version_t *
hosting_load_and_check_plugin (
  char *file_name, char *function_name,
  unit_version_t *dock_version, void *appdata)
{
  void *dll;
  unit_check_t *check_callback;
  unit_version_t *res;
  char *fname = file_name;
  hosting_version_t *hres;
  FILE *test;
  char *sys_err;
  test = fopen (fname, "rb");
  if (NULL == test)
    {
      hres = (hosting_version_t *) calloc (1, sizeof (hosting_version_t));
      res = &(hres->hv_pversion);
      res->uv_filename = strdup (fname);
      res->uv_load_error = "Unable to locate file";
      return hres;
    }
  fclose (test);
  dll = DLL_OPEN_GLOBAL (fname);
  if (NULL == dll)
    {
      hres = (hosting_version_t *) calloc (1, sizeof (hosting_version_t));
      res = &(hres->hv_pversion);
      res->uv_filename = strdup (fname);
      sys_err = DLL_ERROR ();
      res->uv_load_error = strdup (sys_err ? sys_err : "");
      return hres;
    }
  check_callback = (unit_check_t *) DLL_PROC (dll, function_name);
  if (NULL == check_callback)
    {
      char *err;
      sys_err = DLL_ERROR ();
      err = strdup (sys_err ? sys_err : "");
      DLL_CLOSE (dll);
      hres = (hosting_version_t *) calloc (1, sizeof (hosting_version_t));
      res = &(hres->hv_pversion);
      res->uv_filename = strdup (fname);
      res->uv_load_error = err;
      return hres;
    }
  res = check_callback (dock_version, appdata);
  if (!res)
    {
      hres = (hosting_version_t *) calloc (1, sizeof (hosting_version_t));
      res = &(hres->hv_pversion);
      res->uv_filename = strdup (fname);
      res->uv_load_error = "incorrect initialization";
      return hres;
    }
  res->uv_filename = strdup (fname);
  if (NULL != res->uv_load_error)
    {
      char *err = strdup (res->uv_load_error);
      DLL_CLOSE (dll);
      hres = (hosting_version_t *) calloc (1, sizeof (hosting_version_t));
      res = &(hres->hv_pversion);
      res->uv_filename = strdup (fname);
      res->uv_load_error = err;
      return hres;
    }

  if (strcmp (res->uv_title, HOSTING_TITLE))
    {
      DLL_CLOSE (dll);
      hres = (hosting_version_t *) calloc (1, sizeof (hosting_version_t));
      res = &(hres->hv_pversion);
      res->uv_filename = strdup (fname);
      res->uv_load_error = "Invalid hosting module loaded";
      return hres;
    }

  if (NULL != res->uv_gate)
    {
      if (_gate_export (res->uv_gate))
	{
	  DLL_CLOSE (dll);
	  hres = (hosting_version_t *) calloc (1, sizeof (hosting_version_t));
	  res = &(hres->hv_pversion);
	  res->uv_filename = strdup (fname);
	  res->uv_load_error = "Loaded plugin requires core functionality not provided by main application";
	  return hres;
	}
    }

  hres = (hosting_version_t *) res;

  SET_DLL_PROC (hres, http_handler, HOSTING_HTTP_HANDLER, 1);
  SET_DLL_PROC (hres, client_attach, HOSTING_CLIENT_ATTACH, 1);
  SET_DLL_PROC (hres, client_detach, HOSTING_CLIENT_DETACH, 1);
  SET_DLL_PROC (hres, client_free, HOSTING_CLIENT_FREE, 1);
  SET_DLL_PROC (hres, client_clone, HOSTING_CLIENT_CLONE, 0);
  return hres;
}


static unit_version_t
dock_hosting_version = {
  HOSTING_TITLE,			/*!< Title of unit, filled by unit */
  DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR,/*!< Version number, filled by unit */
  "OpenLink Software",			/*!< Plugin's developer, filled by unit */
  "",					/*!< Any additional info, filled by unit */
  NULL,					/*!< Error message, filled by unit loader */
  NULL,					/*!< Name of file with unit's code, filled by unit loader */
  NULL,					/*!< Pointer to connection function, cannot be NULL */
  NULL,					/*!< Pointer to disconnection function, or NULL */
  NULL,					/*!< Pointer to activation function, or NULL */
  NULL,					/*!< Pointer to deactivation function, or NULL */
  NULL
};

static id_hash_t *ext_hash;

static unit_version_t *
hosting_plugin_load (const char *plugin_dll_name, const char *plugin_load_path)
{
  char *filename, *funname;
  const char *dot;
  hosting_version_t *hver;
  int inx;
  size_t file_name_max_len = strlen (plugin_load_path) + 1 + strlen (plugin_dll_name) + 1;
  size_t funname_max_len;

  filename = (char *) dk_alloc (strlen (plugin_load_path) + 1 + strlen (plugin_dll_name) + 1);
  snprintf (filename, file_name_max_len, "%s/%s", plugin_load_path, plugin_dll_name);
  funname_max_len = strlen (plugin_dll_name) + 6 /* == strlen ("_check") */ + 1;

  filename = (char *) dk_alloc (file_name_max_len);
  snprintf (filename, file_name_max_len, "%s/%s", plugin_load_path, plugin_dll_name);
  funname = (char *) dk_alloc (funname_max_len);
  dot = strchr (plugin_dll_name, '.');
  if (!dot)
    dot = plugin_dll_name + strlen (plugin_dll_name);
  strncpy (funname, plugin_dll_name, dot - plugin_dll_name);
  funname[dot - plugin_dll_name] = 0;
  strncat_size_ck (funname, "_check", funname_max_len - strlen (funname) - 1, funname_max_len);
  hver = hosting_load_and_check_plugin (filename, funname, &dock_hosting_version, NULL);

  for (inx = 0; hver->hv_extensions && hver->hv_extensions[inx]; inx++)
    {
      caddr_t ext = box_dv_short_string (hver->hv_extensions[inx]);
      id_hash_set (ext_hash, (caddr_t) &ext, (caddr_t) &hver);
    }

  return &(hver->hv_pversion);
}


static void
hosting_plugin_connect (const unit_version_t *plugin)
{
  UV_CALL (plugin, uv_connect, NULL);
}
#endif

void
hosting_plugin_init (void)
{
  ext_hash = id_str_hash_create (10);
#ifndef __NO_LIBDK
  plugin_add_type (HOSTING_TITLE, hosting_plugin_load, hosting_plugin_connect);
#endif
}


static hosting_version_t *
hosting_plugin_find_by_ext (char *ext)
{
  hosting_version_t **ret;
  ret = (hosting_version_t **) id_hash_get (ext_hash, (caddr_t) & ext);
  return ret ? *ret : NULL;
}


static void *
hosting_client_attach (client_connection_t *cli, hosting_version_t * ver, char *err, int err_max)
{
  void *hcli = NULL;

  if (!cli->cli_module_attachments)
    cli->cli_module_attachments = hash_table_allocate (10);

  hcli = gethash (ver, cli->cli_module_attachments);

  err[0] = 0;
  if (hcli)
    return hcli;

  hcli = ver->hv_client_attach (err, err_max);
  if (err[0] != 0)
    return NULL;

  sethash (ver, cli->cli_module_attachments, hcli);

  return hcli;
}


static void
hosting_clear_attachment (const void *k, void *data)
{
  hosting_version_t *ver = (hosting_version_t *)k;

  ver->hv_client_detach (data);
}


void
hosting_clear_cli_attachments (client_connection_t *cli, int free)
{
  if (cli->cli_module_attachments)
    {
      maphash (hosting_clear_attachment, cli->cli_module_attachments);
      if (free)
	{
	  hash_table_free (cli->cli_module_attachments);
	  cli->cli_module_attachments = NULL;
	}
      else
	clrhash (cli->cli_module_attachments);
    }
}


static char **
hosting_make_string_array (caddr_t *qst, caddr_t *arr)
{
  char **ret = NULL;
  int inx;
  caddr_t err = NULL;

  if (!arr)
    return ret;

  ret = (char **) dk_alloc_box (BOX_ELEMENTS (arr) * sizeof (char *), DV_ARRAY_OF_POINTER);
  memset (ret, 0, BOX_ELEMENTS (arr) * sizeof (char *));
  DO_BOX (caddr_t, elt, inx, arr)
    {
      ret[inx] = box_cast_to (qst, elt, DV_TYPE_OF (elt),
	  DV_STRING, 0, 0, &err);
      if (err)
	{
	  dk_free_tree ((box_t) ret);
	  sqlr_resignal (err);
	}

    }
  END_DO_BOX;
  return ret;
}


static caddr_t
hosting_prepare_params (caddr_t params)
{
  caddr_t _params = NULL;
  if (params && !DV_STRINGP (params))
    {
      switch (DV_TYPE_OF (params))
	{
	  case DV_ARRAY_OF_POINTER:
		{
		  size_t pars_len = 1;
		  int inx;
		  char *_params_ptr;
		  for (inx = 0; inx < BOX_ELEMENTS_INT (params); inx += 2)
		    {
		      if (inx)
			pars_len += 1;
		      if (!DV_STRINGP (((caddr_t *)params)[inx]))
			{
			  sqlr_new_error ("22023", "HO002",
			      "Invalid value data type (%s (%d) not a string) for parameter element %d",
			      dv_type_title (DV_TYPE_OF (((caddr_t *)params)[inx])),
			      DV_TYPE_OF (((caddr_t *)params)[inx]),
			      inx + 1);
			}
		      if (!DV_STRINGP (((caddr_t *)params)[inx + 1]))
			{
			  sqlr_new_error ("22023", "HO003",
			      "Invalid value data type (%s (%d) not a string) for parameter element %d",
			      dv_type_title (DV_TYPE_OF (((caddr_t *)params)[inx + 1])),
			      DV_TYPE_OF (((caddr_t *)params)[inx + 1]),
			      inx + 2);
			}
		      pars_len += strlen (((caddr_t *)params)[inx]) + 1
			  + strlen (((caddr_t *)params)[inx + 1]);
		    }
		  _params = _params_ptr = dk_alloc_box (pars_len, DV_STRING);
		  for (inx = 0; inx < BOX_ELEMENTS_INT (params); inx += 2)
		    {
		      if (inx)
			*_params_ptr++ = '&';

		      _params_ptr = stpcpy (_params_ptr, ((caddr_t *)params)[inx]);
		      *_params_ptr++ = '=';
		      _params_ptr = stpcpy (_params_ptr, ((caddr_t *)params)[inx + 1]);
		    }
		  *_params_ptr = 0;
		  break;
		}

	  case DV_STRING_SESSION:
	      if (!STRSES_CAN_BE_STRING ((dk_session_t *) params))
		sqlr_resignal (STRSES_LENGTH_ERROR ("Hosting params handling"));
	      _params = strses_string ((dk_session_t *) params);
	      break;
	  default:
	      sqlr_new_error ("22023", "HO001", "Invalid params type %d (%s)",
		  DV_TYPE_OF (params), dv_type_title (DV_TYPE_OF (params)));
	}
    }
  return _params;
}


static caddr_t
bif_hosting_http_handler (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t params = NULL;
  caddr_t * lines = NULL, *head_ret = NULL, *diag_ret = NULL;
  caddr_t in_file, file, file_copy = NULL;
  caddr_t ext = bif_string_arg (qst, args, 0, "hosting_http_handler");
  hosting_version_t *ver;
  void *hcli;
  char err[512];
  caddr_t *options = NULL;
  char *_res = NULL;
  char *_head_ret = NULL;
  caddr_t res = NULL;
  char **_lines;
  char **_options;
  char *_params = NULL;
  char *_diag_ret = NULL;

  if (NULL == (ver = hosting_plugin_find_by_ext (ext)))
    sqlr_new_error ("22023", "HO001", "Unknown extension %s in hosting_http_handler", ext);

  in_file = bif_arg (qst, args, 1, "hosting_http_handler");
  if (DV_TYPE_OF (in_file) == DV_BLOB_HANDLE)
    {
      file_copy = file = blob_to_string (qi->qi_trx, in_file);
    }
  else
    file = in_file;

  if (BOX_ELEMENTS (args) > 2)
    {
      params = bif_arg (qst, args, 2, "hosting_http_handler");
    }

  if (BOX_ELEMENTS (args) > 3)
    {
      lines = (caddr_t *) bif_arg (qst, args, 3, "hosting_http_handler");
    }

  if (BOX_ELEMENTS (args) > 5)
    {
      options = (caddr_t *) bif_array_or_null_arg (qst, args, 5, "hosting_http_handler");
    }

  IO_SECT(qst);

  err[0] = 0;
  hcli = hosting_client_attach (qi->qi_client, ver, err, sizeof (err));
  if (err[0] != 0)
    sqlr_new_error ("42000", "HO004", "%s", err);

  err[0] = 0;
  _lines = hosting_make_string_array (qst, lines);
  _options = hosting_make_string_array (qst, options);

  _params = hosting_prepare_params (params);

  if (BOX_ELEMENTS (args) > 4 &&
      DV_TYPE_OF (bif_arg (qst, args, 4, "hosting_http_handler")) != DV_DB_NULL)
    {/* the 1-st parameter is a content of page not a file  */
      caddr_t what = bif_string_or_null_arg (qst, args, 4, "hosting_http_handler");

      _res = ver->hv_http_handler (hcli, err, sizeof (err) - 1,
	  (what ? what : file), (what ? file : NULL),
	  (const char *) _params ? _params : params,
	  (const char **) _lines, lines ? BOX_ELEMENTS (lines) : 0,
	  &_head_ret,
	  (const char **) _options, options ? BOX_ELEMENTS (options) : 0,
	  &_diag_ret, 0);
    }
  else
    {
      _res = ver->hv_http_handler (hcli, err, sizeof (err) - 1,
	  file, NULL,
	  (const char *) _params ? _params : params,
	  (const char **) _lines, lines ? BOX_ELEMENTS (lines) : 0,
	  &_head_ret,
	  (const char **) _options, options ? BOX_ELEMENTS (options) : 0,
	  &_diag_ret, 0);
    }

  dk_free_tree ((box_t) _lines);
  dk_free_tree ((box_t) _options);
  dk_free_tree ((box_t) file_copy);
  if (_params)
    dk_free_tree (_params);

  virtuoso_restore_sig_handlers ();

  if (ver->hv_client_using_boxes)
    {
      /* proposal - the hosting plugin needs to use boxes, otherwise
       * it can return string content only; failing in subtle cases.
       * When ruby/perl/python have been adapted, clean up this code.
       * PmN
       */
      if (err[0] != 0)
	{
	  caddr_t cerr;
	  dk_free_tree ((box_t) _res);
	  dk_free_tree ((box_t) _head_ret);
	  dk_free_tree ((box_t) _diag_ret);
	  cerr = srv_make_new_error ("42000", "HO002", "%s", err);
	  sqlr_resignal (cerr);
	}
      if (_head_ret)
	{
	  if (BOX_ELEMENTS (args) > 4 && ssl_is_settable (args[4]))
	    qst_set (qst, args[4], (caddr_t) _head_ret);
	  else
	    dk_free_tree ((box_t) _head_ret);
	}
      if (_diag_ret)
	{
	  if (BOX_ELEMENTS (args) > 6 && ssl_is_settable (args[6]))
	    qst_set (qst, args[6], (caddr_t) _diag_ret);
	  else
	    {
	      log_debug ("hosting: [%s]", _diag_ret);
	      dk_free_tree ((box_t) _diag_ret);
	    }
	}
      res = _res;
    }
  else
    {
      if (err[0] != 0)
	{
	  caddr_t cerr;
	  if (_res)
	    ver->hv_client_free (_res);
	  if (_head_ret)
	    ver->hv_client_free (_head_ret);
	  if (_diag_ret)
	    ver->hv_client_free (_diag_ret);
	  cerr = srv_make_new_error ("42000", "HO002", "%s", err);
	  sqlr_resignal (cerr);
	}
      if (_res)
	{
	  res = box_dv_short_string (_res);
	  ver->hv_client_free (_res);
	}
      if (_head_ret)
	{
	  if (BOX_ELEMENTS (args) > 4)
	    {
	      head_ret = (caddr_t *) box_dv_short_string ((box_t) _head_ret);
	      if (ssl_is_settable (args[4]))
		qst_set (qst, args[4], (caddr_t) head_ret);
	      else
		dk_free_tree ((box_t) head_ret);
	    }
	  ver->hv_client_free (_head_ret);
	}
      if (_diag_ret)
	{
	  if (BOX_ELEMENTS (args) > 6)
	    {
	      if (ssl_is_settable (args[6]))
		{
		  diag_ret = (caddr_t *) box_dv_short_string (_diag_ret);
		  qst_set (qst, args[6], (caddr_t) diag_ret);
		}
	      else
		{
		  log_debug ("hosting: [%s]", diag_ret);
		  dk_free_tree ((box_t) diag_ret);
		}
	    }
	  else
	    log_debug ("hosting: [%s]", _diag_ret);
	  ver->hv_client_free (_diag_ret);
	}
    }

  END_IO_SECT (err_ret);
  if (*err_ret)
    {
      dk_free_tree (res);
      res = NULL;
    }

  return res;
}


void
bif_hosting_init (void)
{
  bif_define_ex ("__hosting_http_handler", bif_hosting_http_handler, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
}

void
ddl_init_plugin (void)
{
  id_hash_iterator_t hit;
  char **pext;
  hosting_version_t **ppver;

  id_hash_iterator (&hit, ext_hash);

  while (hit_next (&hit, (caddr_t *) &pext, (caddr_t *) &ppver))
    {
      char cmd_buffer [2048];

      snprintf (cmd_buffer, sizeof (cmd_buffer),
         "create procedure \"WS\".\"WS\".\"__http_handler_%s\" (inout content any, inout params any, inout lines any, inout filename varchar)\n"
	 "{\n"
	 "  return __hosting_http_handler ('%s', content, params, lines, filename,\n"
	 " WS.WS.GET_CGI_VARS_VECTOR (lines));\n"
	 "}\n",
	 *pext, *pext);
      ddl_std_proc_1 (cmd_buffer, 1, 0);
    }
}

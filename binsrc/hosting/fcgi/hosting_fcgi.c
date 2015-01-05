/*
 *  hosting_fcgi.c
 *
 *  $Id$
 *
 *  Virtuoso FastCGI hosting plugin virtuoso iface
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2015 OpenLink Software
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
#include <stdarg.h>
#include "import_gate_virtuoso.h"
#include "hosting_fcgi.h"
#include <hosting.h>
#include <sqlver.h>

int
vfc_log_debug (char *format, ...)
{
  va_list ap;
  int rc;

  va_start (ap, format);
#if 0
  fprintf (stderr, "HOSTING_FCGI:");
  rc = vfprintf (stderr, format, ap);
  fprintf (stderr, "\n");
#endif
  rc = server_logmsg_ap (LOG_DEBUG, NULL, 0, 1, format, ap);
  va_end (ap);
  return rc;
}

static void
hosting_fcgi_connect (void *x)
{
  vfc_log_debug ("hosting_fcgi_connect");
  vfc_server_init ();
}

static hosting_version_t
hosting_fcgi_version = {
    {
      HOSTING_TITLE,			/*!< Title of unit, filled by unit */
      DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR,/*!< Version number, filled by unit */
      "OpenLink Software",			/*!< Plugin's developer, filled by unit */
      "FastCGI hosting plugin 0.1",		/*!< Any additional info, filled by unit */
      NULL,					/*!< Error message, filled by unit loader */
      NULL,					/*!< Name of file with unit's code, filled by unit loader */
      hosting_fcgi_connect,		/*!< Pointer to connection function, cannot be NULL */
      NULL,					/*!< Pointer to disconnection function, or NULL */
      NULL,					/*!< Pointer to activation function, or NULL */
      NULL,					/*!< Pointer to deactivation function, or NULL */
      &_gate,
    },
    NULL, NULL, NULL, NULL, NULL,
    NULL
};


unit_version_t *
hosting_fcgi_check (unit_version_t *in, void *appdata)
{
  static char *args[2];
  args[0] = "fpl";
  args[1] = NULL;
  hosting_fcgi_version.hv_extensions = args;

  return &hosting_fcgi_version.hv_pversion;
}


void *
virtm_client_attach (char *err, int max_err_len)
{
  return NULL;
}


void
virtm_client_detach (void *cli)
{
  vfc_log_debug ("virtm_client_detach");
}


void *
virtm_client_clone (void *cli, char *err, int max_err_len)
{
  return NULL;
}


void
virtm_client_free (void *cli)
{
  dk_free_tree (cli);
}

char *
virtm_http_handler (void *cli, char *err, int max_len,
      const char *base_uri, const char *content,
      const char *params, const char **lines, int n_lines,
      char **head_ret, const char **options, int n_options, char **diag_ret, int compile_only)
{
  void *srv, *req;
  caddr_t ret;

  if (content)
    {
      SET_ERR ("Unable to handle string requests for now");
      return NULL;
    }

  srv = vfc_find_fcgi_server (base_uri, err, max_len);
  if (!srv)
    {
      if (!*err)
	SET_ERR ("Unable to find or allocate an FCGI server : unspecified error");
      return NULL;
    }

  req = vfc_fcgi_request_create (srv, err, max_len,
      options, n_options, params, params ? strlen (params) : 0);
  if (!req)
    {
      if (!*err)
	SET_ERR ("Unable to make a request to the FCGI server : unspecified error");
      return NULL;
    }

  if (!vfc_fcgi_request_process (req, err, max_len))
    {
      vfc_fcgi_request_free (req);
      if (!*err)
	SET_ERR ("Unable to process the request to the FCGI server : unspecified error");
      return NULL;
    }

  *diag_ret = vfc_fcgi_request_get_diag (req);

  ret = vfc_fcgi_request_get_output (req, head_ret);
  vfc_fcgi_request_free (req);
  return  ret;
}

/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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

#include <config.h>
#include <stdio.h>
#include <hosting.h>
#include <sqlver.h>

/* compile as a shared object */
static void
hosting_sample_connect () {
};

/* TODO: change the strings below */
static hosting_version_t
hosting_sample_version = {
    {
      HOSTING_TITLE,			/*!< Title of unit, filled by unit */
      DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR,/*!< Version number, filled by unit */
      "OpenLink Software",			/*!< Plugin's developer, filled by unit */
      "sample plugin",			/*!< Any additional info, filled by unit */
      NULL,					/*!< Error message, filled by unit loader */
      NULL,					/*!< Name of file with unit's code, filled by unit loader */
      hosting_sample_connect,		/*!< Pointer to connection function, cannot be NULL */
      NULL,					/*!< Pointer to disconnection function, or NULL */
      NULL,					/*!< Pointer to activation function, or NULL */
      NULL,					/*!< Pointer to deactivation function, or NULL */
      NULL
    },
    NULL, NULL, NULL, NULL, NULL,
    NULL /* put an array of supported extensions here */
};

/* TODO: change name <shared_object_name>_check */
unit_version_t *
CALLBACK hosting_sample_check (unit_version_t *in, void *appdata)
{
  /* TODO: Put the supported extensions this way (if any)
     static char *args[2];
     args[0] = "sam";
     args[1] = NULL;
     hosting_sample_version.hv_extensions = args;
   */
  /* if (error) return NULL */
  return &hosting_sample_version.hv_pversion;
}


void *
virtm_client_attach (char *err, int max_err_len)
{
  /* TODO: cli = persistent per/client structure */
  return NULL; /* cli */
}


void
virtm_client_detach (void *cli)
{
  /* called to free the result from virtm_client_detach */
  /* destroy and free (cli) */
}


void *
virtm_client_clone (void *cli, char *err, int max_err_len)
{
  /* if (copying the per/client data is possible) return copy (cli); */
  return NULL; /* cli */
}


void
virtm_client_free (void *dta)
{
  /* free plugin allocated data returned to virtuoso from virtm_http_handler (dta); */
}


char *
virtm_http_handler (void *cli, char *err, int max_len,
      const char *base_uri, const char *content,
      const char *params, const char **lines, int n_lines,
      char **head_ret, const char **options, int n_options, char **diag_ret, int compile_only)
{
  return NULL; /* stdout content */
}

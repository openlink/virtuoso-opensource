/*
 *  hosting.h
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

#ifndef __HOSTING_H__
#define __HOSTING_H__ 1

#include <plugin.h>

/* hosting structs */

typedef char * (* hv_http_handler_t)
    (void *cli, char *err, int max_err_len,
     const char *base_uri, const char *content,
     const char *params, const char **lines, int n_lines,
     char **head_ret, const char **options, int n_options, char **diag_ret,
     int compile_only);

typedef void * (* hv_client_attach_t)
    (char *err, int max_err_len);

typedef char * (* hv_client_detach_t)
    (void *cli);

typedef void * (* hv_client_clone_t)
    (void *cli, char *err, int max_err_len);

typedef void (* hv_client_free_t)
    (void *cli);

typedef struct hosting_version_s
{
  unit_version_t hv_pversion;
  hv_http_handler_t hv_http_handler;
  hv_client_attach_t hv_client_attach;
  hv_client_detach_t hv_client_detach;
  hv_client_clone_t hv_client_clone;
  hv_client_free_t hv_client_free;
  char **hv_extensions;
  int hv_client_using_boxes;
} hosting_version_t;

void virtuoso_restore_sig_handlers (void);

#define HOSTING_TITLE "Hosting"
#define HOSTING_VERSION "Hosting"
# define HOSTING_HTTP_HANDLER "virtm_http_handler"
# define HOSTING_CLIENT_ATTACH "virtm_client_attach"
# define HOSTING_CLIENT_DETACH "virtm_client_detach"
# define HOSTING_CLIENT_FREE "virtm_client_free"
# define HOSTING_CLIENT_CLONE "virtm_client_clone"

#endif

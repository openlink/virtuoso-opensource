/*
 *  hosting_fcgi.h
 *
 *  $Id$
 *
 *  Virtuoso FastCGI hosting plugin header
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

#ifndef HOSTING_FCGI_H
#define HOSTING_RUBY_H
#include <stdio.h>

#define SET_ERR(str) \
      { \
	if (err && max_len > 0) \
	  { \
	    strncpy (err, str, max_len); \
	    err[max_len] = 0; \
	  } \
      }

/* hosting_fcgi.c */
int vfc_log_debug (char *format, ...);
void *vfc_find_fcgi_server (const char *base_uri, char *err, int max_len);
void * vfc_fcgi_request_create (void *_srv, char *err, int max_len,
    const char **options, int n_options, const char *params, int n_params);
void vfc_fcgi_request_free (void *_req);
int vfc_fcgi_request_process (void *_req, char *err, int max_len);
caddr_t vfc_fcgi_request_get_output (void *_req, char **head_ret);
caddr_t vfc_fcgi_request_get_diag (void *_req);

/* cgi_fcgi.c */
int vfc_server_init (void);

/*#define VFC_DEBUG*/
#ifdef VFC_DEBUG
#define vfc_fprintf(x) fprintf x
#else
#define vfc_fprintf(x)
#endif

#endif

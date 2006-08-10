/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#if defined (__cplusplus) && !defined (WIN32)
#include <strstream.h>
#endif

#define C_BEGIN()
#define C_END()

C_BEGIN ()
#define uint16  unsigned short
#define uint8   unsigned char
#include <ksrvext.h>
    C_END ()
#undef YYDEBUG
#ifdef _PHP
#ifdef __MINGW32__
#define storage _tempnam (NULL, NULL)
#elif defined (WIN32)
     typedef unsigned int uint;
     typedef unsigned long ulong;
     WINBASEAPI DWORD WINAPI
	 SignalObjectAndWait (HANDLE hObjectToSignal,
    HANDLE hObjectToWaitOn, DWORD dwMilliseconds, BOOL bAlertable);
#define storage _tempnam (NULL, NULL)
#else
#define storage tmpnam (NULL)
#endif
#define MAX_FILENAME_LEN 8096
#undef thread_s
#undef semaphore_s
#define semaphore_t semaphore_s
#define thread_t thread_s
#include "php.h"
#include "php_main.h"
#include "php_ini.h"
#include "rfc1867.h"
#include "php_globals.h"
#include "php_variables.h"
#include "php_content_types.h"
#include "ext/standard/info.h"
#include "ksrvextphp.h"
     int php_virt_module_shutdown_wrapper ()
{
  TSRMLS_FETCH ();
  php_module_shutdown (TSRMLS_C);
  return SUCCESS;
}

static int
sapi_virtuoso_deactivate (TSRMLS_D)
{
  return SUCCESS;
}

char *virt_env_lst[] = {
  "DOCUMENT_ROOT",
  "HTTP_ACCEPT",
  "HTTP_ACCEPT_CHARSET",
  "HTTP_ACCEPT_ENCODING",
  "HTTP_ACCEPT_LANGUAGE",
  "HTTP_HOST",
  "HTTP_KEEP_ALIVE",
  "HTTP_REFERER",
  "HTTP_USER_AGENT",
  "HTTP_VIA",
  "PATH",
  "REMOTE_ADDR",
  "REMOTE_PORT",
  "SCRIPT_FILENAME",
  "SERVER_ADDR",
  "SERVER_ADMIN",
  "SERVER_NAME",
  "SERVER_PORT",
  "SERVER_SIGNATURE",
  "SERVER_SOFTWARE",
  "GATEWAY_INTERFACE",
  "SERVER_PROTOCOL",
  "SERVER_VERSION",
  "REQUEST_METHOD",
  "QUERY_STRING",
  "REQUEST_URI",
  "SCRIPT_NAME",
  NULL
}

;

/*
   "REMOTE_HOST"
   "HTTP_CONNECTION"
   "PATH_TRANSLATED"
*/  

static sapi_module_struct virtuoso_sapi_module = {
  "Virtuoso",
  "VIRTUOSO",

  php_module_startup_int,
  php_module_shutdown_wrapper,

  sapi_virtuoso_activate,	/* activate */
  sapi_virtuoso_deactivate,	/* deactivate */

  sapi_virtuoso_ub_write,
  NULL,
  NULL,				/* get uid */
  php_virtuoso_getenv,

  php_error,

  sapi_virtuoso_handle_headers,
  sapi_virtuoso_send_headers,
  NULL,

  sapi_virtuoso_read_post,	/* POST request read function */
  sapi_virtuoso_read_cookies,	/* Cookie read function */

  sapi_virtuoso_register_variables,
  NULL,				/* Log message */

  NULL,				/* Block interruptions */
  NULL,				/* Unblock interruptions */

  STANDARD_SAPI_MODULE_PROPERTIES
};



static sapi_post_entry php_app_post_entry = {
  APP_POST_CONTENT_TYPE,
  sizeof (APP_POST_CONTENT_TYPE) - 1,
  sapi_read_standard_form_data,
  php_std_post_handler
};

static sapi_post_entry php_multi_post_entry = {
  MULTIPART_CONTENT_TYPE,
  sizeof (MULTIPART_CONTENT_TYPE) - 1,
  sapi_read_standard_form_data,
  rfc1867_post_handler
};


int
sapi_virtuoso_ub_write (const char *str, uint str_length TSRMLS_DC)
{
  dk_session_t *ret_res;
  thr_atrp *t1;

  TLS_FETCH ();

  t1 = (thr_atrp *) THR_ATTR (THREAD_CURRENT_THREAD, VIRT_PRINT_OUT);

  ret_res = t1->ret_val;

  session_buffered_write (ret_res, (char *) str, str_length);

  return 0;
}

static int
sapi_virtuoso_activate (TSRMLS_D)
{
  return 0;
}


static char *
ap_lines_get_http_ver (caddr_t * lines)
{
  char *http_ver, *p;

  if (!lines)
    return NULL;

  strncpy (req_http_ver, lines[0], 2047);

  http_ver = req_http_ver;
  p = strchr (http_ver, ' ');
  http_ver = ++p;
  p = strchr (http_ver, ' ');

  if (p)
    return p;

  return NULL;
}


static char *
ap_lines_get_req_mtd (caddr_t * lines)
{
  char *header_content, *p;

  if (!lines)
    return NULL;

  strncpy (req_mtd, lines[0], 15);

  header_content = req_mtd;
  p = strchr (req_mtd, ' ');

  if (p)
    {
      *p = 0;
      return header_content;
    }

  return NULL;
}


static char *
ap_lines_get_line0 (caddr_t * lines)
{
  char *header_content, *p;

  if (!lines)
    return NULL;

  strncpy (lines_0, lines[0], 2047);
  header_content = p = strchr (lines_0, ' ');
  if (p)
    {
      int len2;
      do
	{
	  header_content++;
	}
      while (*header_content == ' ');

      len2 = strlen (header_content);

      if (header_content[len2 - 1] == '\x0A')
	header_content[len2 - 2] = 0;

      p = strchr (header_content, ' ');

      if (p)
	{
	  len2 = strlen (header_content);
	  header_content[len2 - 9] = 0;
	}

      return header_content;
    }

  return NULL;
}


static char *
lookup_header (caddr_t * lines, char *key_int)
{
  int len, i;
  char *header_content, *p;

  if (lines)
    len = BOX_ELEMENTS (lines);
  else
    return NULL;

  for (i = 1; i < len; i++)
    {
      if (!strncasecmp (lines[i], key_int, strlen (key_int)))
	{
	  header_content = p = strchr (lines[i], ':');
	  if (p)
	    {
	      int len2;
	      do
		{
		  header_content++;
		}
	      while (*header_content == ' ');

	      len2 = strlen (header_content);

	      if (header_content[len2 - 1] == '\x0A')
		header_content[len2 - 2] = 0;

	      return header_content;
	    }
	}
    }

  return NULL;
}


static char *
ap_lines_get (caddr_t * lines, char *key)
{
  thr_atrp *thra =
      (thr_atrp *) THR_ATTR (THREAD_CURRENT_THREAD, VIRT_PRINT_OUT);
  caddr_t *qi = (caddr_t *) thra->qi;
  client_connection_t *cli = qi_client (qi);
  char *script_path = (char *) thra->org_file_name;
  char *in_header = NULL;

  if (key == NULL)
    return NULL;

  in_header = lookup_header (lines, key);

  if (in_header)
    return in_header;

  if (!strncasecmp (key, "HTTP_ACCEPT_LANGUAGE", 21))
    return lookup_header (lines, "Accept-Language");

  if (!strncasecmp (key, "HTTP_ACCEPT_ENCODING", 21))
    return lookup_header (lines, "Accept-Encoding");

  if (!strncasecmp (key, "HTTP_ACCEPT_CHARSET", 20))
    return lookup_header (lines, "Accept-Charset");

  if (!strncasecmp (key, "HTTP_ACCEPT", 11))
    return lookup_header (lines, "Accept");

  if (!strncasecmp (key, "HTTP_KEEP_ALIVE", 15))
    return lookup_header (lines, "Connection");

  if (!strncasecmp (key, "HTTP_USER_AGENT", 15))
    return lookup_header (lines, "User-Agent");

  if (!strncasecmp (key, "HTTP_REFERER", 12))
    return lookup_header (lines, "Referer");

  if (!strncasecmp (key, "HTTP_HOST", 9))
    return lookup_header (lines, "Host");

  if (!strncasecmp (key, "HTTP_VIA", 8))
    return lookup_header (lines, "Via");

  if (!strncasecmp (key, "DOCUMENT_ROOT", 13))
    return srv_www_root ();

  if (!strncasecmp (key, "REQUEST_METHOD", 14))
    return ap_lines_get_req_mtd (lines);

  if (!strncasecmp (key, "REQUEST_URI", 11))
    return ap_lines_get_line0 (lines);

  if (!strncasecmp (key, "QUERY_STRING", 12))
    return lines ? lines[0] : NULL;

  if (!strncasecmp (key, "SCRIPT_NAME", 11))
    {
      int len = strlen (srv_www_root ());
      strncpy (script_name, script_path + len * sizeof (char), 2048);
      return script_name;
    }

  if (!strncasecmp (key, "SERVER_PROTOCOL", 15))
    return ap_lines_get_http_ver (lines);

  if (!strncasecmp (key, "REMOTE_ADDR", 11))
    {
      char user[16];
      char peer[32];

      dks_client_ip (cli, remote_client_ip, user, peer,
	  sizeof (remote_client_ip), sizeof (user), sizeof (peer));

      return remote_client_ip;
    }

  if (!strncasecmp (key, "REMOTE_PORT", 11))
    {
      dks_client_port (cli, remote_client_port, sizeof (remote_client_port));
      return remote_client_port;
    }

  if (!strncasecmp (key, "SERVER_ADDR", 11))
    {
      srv_ip (server_ip, sizeof (server_ip), srv_dns_host_name ());
      return server_ip;
    }

  if (!strncasecmp (key, "SERVER_ADMIN", 12))
    {
      if (virtuoso_cfg_getstring ("PHP", "Admin", &php_ini_admin) == -1)
	return "dba";
      return php_ini_admin;
    }

  if (!strncasecmp (key, "SERVER_NAME", 11))
    return srv_dns_host_name ();

  if (!strncasecmp (key, "SERVER_PORT", 11))
    return srv_http_port ();

  if (!strncasecmp (key, "SCRIPT_FILENAME", 15))
    return script_path;

  if (!strncasecmp (key, "SERVER_SOFTWARE", 15))
    return srv_st_dbms_name ();

  if (!strncasecmp (key, "SERVER_SIGNATURE", 16))
    {
      sprintf (server_signature, "<ADDRESS>%s %s at %s Port %s</ADDRESS>",
	  srv_st_dbms_name (), srv_st_dbms_ver (), srv_dns_host_name (),
	  srv_http_port ());
      return server_signature;
    }

  if (!strncasecmp (key, "SERVER_VERSION", 14))
    return srv_st_dbms_ver ();

  if (!strncasecmp (key, "GATEWAY_INTERFACE", 17))
    return "CGI/1.1";

  if (!strncasecmp (key, "PATH", 4))
    return getenv ("PATH");

  return NULL;
}


static char *
php_virtuoso_getenv (char *name, size_t name_len TSRMLS_DC)
{

  thr_atrp *t1 =
      (thr_atrp *) THR_ATTR (THREAD_CURRENT_THREAD, VIRT_PRINT_OUT);
  return ap_lines_get (t1->in_lines, name);
}


int
sapi_virtuoso_handle_headers (sapi_header_struct * sapi_header,
    sapi_headers_struct * sapi_headers TSRMLS_DC)
{

  dk_session_t *headers;
  thr_atrp *t1 =
      (thr_atrp *) THR_ATTR (THREAD_CURRENT_THREAD, VIRT_PRINT_OUT);
  char *header_name, *header_content, *p;

  header_name = sapi_header->header;

  headers = t1->r_head;

  if (sapi_header && sapi_header->header_len && sapi_header->header)
    {
      session_buffered_write (headers, sapi_header->header,
	  sapi_header->header_len);
      session_buffered_write (headers, "\r\n", 2);
    }

  if (!strncasecmp (header_name, "Set-Cookie", 10))
    {
      header_content = p = strchr (header_name, ':');
      if (p)
	{
	  do
	    {
	      header_content++;
	    }
	  while (*header_content == ' ');

	  t1->coockie = header_content;
	}
    }

  sapi_free_header (sapi_header);

  return 0;

}


static int
sapi_virtuoso_send_headers (sapi_headers_struct * sapi_headers TSRMLS_DC)
{
  dk_session_t *headers;
  thr_atrp *t1 =
      (thr_atrp *) THR_ATTR (THREAD_CURRENT_THREAD, VIRT_PRINT_OUT);
  headers = t1->s_head;

  if (sapi_headers && sapi_headers->http_status_line)
    {
      SES_WRITE (headers, sapi_headers->http_status_line);
    }
  else if (sapi_headers && sapi_headers->http_response_code)
    {
      char tmp[100];
      sprintf (tmp, "HTTP/1.1 %d Something",
	  sapi_headers->http_response_code);
      SES_WRITE (headers, tmp);
    }
  if (sapi_headers)
    sapi_headers->http_response_code = 0;

  return SAPI_HEADER_SENT_SUCCESSFULLY;
}


static int
sapi_virtuoso_read_post (char *buffer, uint count_bytes TSRMLS_DC)
{
  size_t read_bytes = 0;
  thr_atrp *t1;
  caddr_t res = NULL;
  long from, to;
  TLS_FETCH ();

  t1 = (thr_atrp *) THR_ATTR (THREAD_CURRENT_THREAD, VIRT_PRINT_OUT);

  if (!t1 || !t1->post)
    return 0;

  read_bytes = strses_length (t1->post);

  from = t1->post_position;

  if (read_bytes - from < count_bytes)
    to = read_bytes - from;
  else
    to = count_bytes;

  res =
      (caddr_t) dk_alloc_box (count_bytes + 1 * sizeof (char),
      DV_LONG_STRING);
  memset (res, 0, count_bytes + 1 * sizeof (char));

  strses_get_part ((dk_session_t *) t1->post, res, from, to);

  memcpy (buffer, res, to);

  dk_free_tree (res);

  t1->post_position = t1->post_position + to;

  return to;
}


static char *
sapi_virtuoso_read_cookies (TSRMLS_D)
{
  thr_atrp *t1 =
      (thr_atrp *) THR_ATTR (THREAD_CURRENT_THREAD, VIRT_PRINT_OUT);
  return ap_lines_get (t1->in_lines, "Cookie");
}

static void
sapi_virtuoso_register_variables (zval * track_vars_array TSRMLS_DC)
{
  thr_atrp *t1 =
      (thr_atrp *) THR_ATTR (THREAD_CURRENT_THREAD, VIRT_PRINT_OUT);
  char *temp = ap_lines_get_line0 (t1->in_lines);
  int i = 0;

  if (temp)
    php_register_variable ("PHP_SELF", temp, track_vars_array TSRMLS_CC);
  while (NULL != virt_env_lst[i])
    {
      temp = ap_lines_get (t1->in_lines, virt_env_lst[i]);
      if (NULL != temp)
	php_register_variable (virt_env_lst[i], temp, track_vars_array TSRMLS_CC);
      i ++;
    }
}


caddr_t
virt_get_uri (caddr_t * qi, char *base, char *uri)
{
  local_cursor_t *lc = NULL;
  static query_t *qr = NULL;
  caddr_t ret = NULL, err = NULL;

  if (!base || !uri)
    return NULL;

  if (!qr)
    qr = sql_compile ("select blob_to_string("
	"DB.DBA.XML_URI_GET (NULL, WS.WS.EXPAND_URL(?, ?)))",
	qi_client (qi), &err, 0);

  if (!err && qr)
    {
      err = qr_rec_exec (qr, qi_client (qi), &lc, (query_instance_t *) qi,
	  NULL, 2, ":0", base, QRP_STR, ":1", uri, QRP_STR);
      if (err || !lc)
	return NULL;
      while (lc_next (lc))
	{
	  if (!ret)
	    ret = (caddr_t) box_copy (lc_nth_col (lc, 0));
	}
      if (0 != lc->lc_error)
	{
	  lc_free (lc);
	  return NULL;
	}
      lc_free (lc);
    }
  else if (err)
    {
      qr_free (qr);
      qr = NULL;
    }

  return ret;
};


zend_op_array *
virt_php_compile_file (zend_file_handle * file_handle, int type TSRMLS_DC)
{
  thr_atrp *thra =
      (thr_atrp *) THR_ATTR (THREAD_CURRENT_THREAD, VIRT_PRINT_OUT);
  zend_file_handle *fh = thra->fh;
  caddr_t *qi = (caddr_t *) thra->qi;
  char *org = (char *) thra->org_file_name;
  char *rm_name = (char *) thra->rm_name;
  FILE *inc;
  char fname[MAX_FILENAME_LEN];

  if (rm_name)
    {
      file_handle->type = ZEND_HANDLE_FILENAME;
      file_handle->filename = rm_name;
    }

  else if (fh && file_handle)
    {
      caddr_t cnt = NULL;

      if (fh->filename != file_handle->filename)
	cnt = virt_get_uri (qi, org, file_handle->filename);
      if (cnt)
	{
	  strncpy (fname, storage, MAX_FILENAME_LEN - 1);
	  inc = fopen (fname, "w");
	  fprintf (inc, "%s\n", (char *) cnt);
	  fflush (inc);
	  fclose (inc);
	  file_handle->type = ZEND_HANDLE_FILENAME;
	  file_handle->filename = fname;
	  thra->rm_name = fname;
	}
    }

  return php_compile_file (file_handle, type TSRMLS_CC);
};


/* The fopen wrapper
   If there is something to do, we'll do it and then will switch to the php wrapper
 */
static FILE *
virt_fopen_wrapper_for_zend (const char *filename, char **opened_path)
{
  thr_atrp *thra =
      (thr_atrp *) THR_ATTR (THREAD_CURRENT_THREAD, VIRT_PRINT_OUT);
  zend_file_handle *fh = thra->fh;
  caddr_t *qi = (caddr_t *) thra->qi;
  char *org = (char *) thra->org_file_name;
  char *rm_name = (char *) thra->rm_name;
  FILE *inc;
  char fname[MAX_FILENAME_LEN];

  if (fh && fh->filename != filename && !rm_name)
    {
      caddr_t cnt = NULL;
      strncpy (fname, filename, MAX_FILENAME_LEN - 1);
      cnt = virt_get_uri (qi, org, fname);

      if (cnt)
	{
	  strncpy (fname, storage, MAX_FILENAME_LEN - 1);
	  inc = fopen (fname, "w");
	  fprintf (inc, "%s\n", (char *) cnt);
	  fflush (inc);
	  fclose (inc);
	  thra->rm_name = fname;

	  return php_fopen_func (fname, opened_path);
	}
    }

  return php_fopen_func (filename, opened_path);
}

/* The file destructor wrapper */
static void
virt_zend_file_handle_dtor (zend_file_handle * fh)
{
  thr_atrp *thra =
      (thr_atrp *) THR_ATTR (THREAD_CURRENT_THREAD, VIRT_PRINT_OUT);
  char *name = (char *) thra->rm_name;

  if (name)
    {
      remove (name);
      thra->rm_name = NULL;
    }

  zend_file_handle_dtor (fh);
};

PHP_INI_BEGIN ()PHP_INI_END ()
     static
     PHP_MINIT_FUNCTION (virt)
{
  REGISTER_INI_ENTRIES ();
  return SUCCESS;
}


PHP_MINFO_FUNCTION (virt)
{
  int i;
  char *value;
  thr_atrp *t1 =
      (thr_atrp *) THR_ATTR (THREAD_CURRENT_THREAD, VIRT_PRINT_OUT);

  /* DISPLAY_INI_ENTRIES(); */

  SECTION ("Virtuoso Environment");
  php_info_print_table_start ();
  php_info_print_table_header (2, "Variable", "Value");
  i = 0;
  while (virt_env_lst[i])
    {
      value = ap_lines_get (t1->in_lines, virt_env_lst[i]);
/*    if (value) FIXME remove comment at end */
      php_info_print_table_row (2, virt_env_lst[i], value);
      i++;
    }
  php_info_print_table_end ();
}

zend_module_entry virt_module_entry = {
  STANDARD_MODULE_HEADER,
  "Virtuoso",
  NULL,
  PHP_MINIT (virt),
  NULL,
  NULL,
  NULL,
  PHP_MINFO (virt),
  NO_VERSION_YET,
  STANDARD_MODULE_PROPERTIES
};

#ifdef WIN32
#define VIRT_PHP_RUNTIME_NAME "DLL"
#else
#define VIRT_PHP_RUNTIME_NAME "shared object"
#endif

static int
php_module_startup_int (sapi_module_struct * sapi_module)
{
  if (php_module_startup (&virtuoso_sapi_module, &virt_module_entry,
	  1) == FAILURE)
    {
      return FAILURE;
    }
  return SUCCESS;
}


static void
check_php_version ()
{

  zval val;
  TSRMLS_FETCH ();
  if (virtuoso_cfg_getstring ("PHP", "Version", &php_ini_version) == -1)
    php_ini_version = PHP_VERSION;

  if (zend_get_constant ("PHP_VERSION", sizeof ("PHP_VERSION") - 1,
	  &val TSRMLS_CC) && Z_TYPE (val) == IS_STRING)
    {
      php_dll_version = Z_STRVAL (val);
      if (strncmp (php_dll_version, PHP_VERSION, Z_STRLEN (val)))
/*    if (php_version_compare (PHP_VERSION, &php_dll_version) == 1) */
	{
	  log_info ("PHP " VIRT_PHP_RUNTIME_NAME
	      " version %s does not match the compilation version %s; "
	      "unpredictable behaviour may result.", php_dll_version,
	      PHP_VERSION);
	}
    }
  else
    log_info ("PHP " VIRT_PHP_RUNTIME_NAME " version unknown. "
	"If your PHP " VIRT_PHP_RUNTIME_NAME
	" version is not %s, unpredictable behaiviour may follow",
	PHP_VERSION);
}


void
virtuoso_php_init (void)
{
  tsrm_startup (1, 1, 0, NULL);
  sapi_startup (&virtuoso_sapi_module);
  virtuoso_sapi_module.startup (&virtuoso_sapi_module);
  check_php_version ();
  zend_startup_module (&virt_module_entry);
  sapi_register_post_entry (&php_app_post_entry);
  sapi_register_post_entry (&php_multi_post_entry);
  php_fopen_func = zend_fopen;
  php_compile_file = zend_compile_file;
  zend_fopen = virt_fopen_wrapper_for_zend;
  zend_compile_file = virt_php_compile_file;

  if (php_ini_opened_path)
    log_debug ("PHP config path [%s]", php_ini_opened_path);
}



void
virtuoso_php_shutdown (void)	/*  XXX FIX add to server shutdown XXX */
{
}


/* this function checks the type of parameters and return string session with the
  URL encoded params, so it raises a flag to know caller
  is the session allocated and must be freed at the end of request */
static void
prepare_params (caddr_t * in, dk_session_t ** out, int *to_free)
{
  volatile int len, br;

  /* if the parameter is a string session then we do not needed to copy as
     thus will increase memory consumption
   */
  if (DV_TYPE_OF (in) == DV_STRING_SESSION)
    {
      *out = (dk_session_t *) in;
      *to_free = 0;
      return;
    }

  if (!out)
    return;

  *out = strses_allocate ();
  *to_free = 1;

  if (in)
    len = BOX_ELEMENTS (in);
  else
    return;

  for (br = 0; br < len; br = br + 2)
    {
      if (br)
	SES_WRITE (*out, "&");

      SES_WRITE (*out, in[br]);
      SES_WRITE (*out, "=");
      SES_WRITE (*out, in[br + 1]);
    }
}

caddr_t
http_handler_php (char *file, caddr_t * params, caddr_t * lines,
    caddr_t string, caddr_t ** head_ret, query_instance_t * qi)
{
  caddr_t ret_str = NULL;
  dk_session_t *ret = NULL, *post = NULL, *r_head = NULL, *s_head = NULL;
  char fname[MAX_FILENAME_LEN];
  int to_free = 0;
  FILE *fi;
  thr_atrp thr_atrp_php;
  zend_file_handle file_handle;

  TSRMLS_FETCH ();

  ret = strses_allocate ();
  r_head = strses_allocate ();
  s_head = strses_allocate ();

  /* INIT REQUEST */
  SG (request_info).query_string = NULL;
  if (string)
    {
      if (params)
	{
	  if (IS_BOX_POINTER (params))
	    {
	      if (DV_ARRAY_OF_POINTER == box_tag (params)
		  || DV_STRING_SESSION == box_tag (params))
		prepare_params ((caddr_t *) params, &post, &to_free);
	      else if (DV_LONG_STRING == box_tag (params)
		  || DV_SHORT_STRING == box_tag (params))
		{
		  to_free = 1;
		  post = strses_allocate ();
		  SES_WRITE (post, (caddr_t) params);
		}
	    }
	}
    }
  else
    {
      if (params)
	prepare_params ((caddr_t *) params, &post, &to_free);

      SG (request_info).path_translated = file;
    }

  thr_atrp_php.ret_val = ret;
  thr_atrp_php.post = post;
  thr_atrp_php.r_head = r_head;
  thr_atrp_php.s_head = s_head;
  thr_atrp_php.fh = NULL;
  thr_atrp_php.qi = qi;
  thr_atrp_php.org_file_name = file;
  thr_atrp_php.rm_name = NULL;
  thr_atrp_php.post_position = 0;
  thr_atrp_php.in_lines = lines;
  thr_atrp_php.coockie = NULL;


  SET_THR_ATTR (THREAD_CURRENT_THREAD, VIRT_PRINT_OUT, &thr_atrp_php);


  if (php_module_startup_int (&virtuoso_sapi_module) == FAILURE)
    {
      return (caddr_t) box_num (1);
    }

  if (string)
    {
      SG (request_info).request_method = "POST";
      SG (request_info).content_type = APP_POST_CONTENT_TYPE;
    }

  SG (server_context) = (void *) 1;
  SG (request_info).request_uri = "";

  if (lines)
    {
      int len, i;
      char *pmethod, meth[10], uri[4096], *p2;

      len = BOX_ELEMENTS (lines);

      /* 1 HTTP method lookup */
      pmethod = strchr (lines[0], '\x20');
      memset (meth, 0, sizeof (meth));
      if (pmethod)
	{
	  if ((unsigned) (pmethod - lines[0]) < sizeof (meth))
	    memcpy (meth, lines[0], pmethod - lines[0]);
	  else
	    strcpy (meth, "GET");
	  SG (request_info).request_method = meth;
	  /* 2 HTTP query string lookup (URL parameters) */
	  pmethod = strchr (pmethod, '?');
	  if (pmethod)
	    {
	      pmethod++;
	      p2 = pmethod;
	      pmethod = strchr (pmethod, '\x20');
	      if (pmethod && (unsigned) (pmethod - p2) < sizeof (uri))
		{
		  memset (uri, 0, sizeof (uri));
		  memcpy (uri, p2, pmethod - p2);
		  SG (request_info).query_string =
		      (char *) box_dv_short_string (uri);
		}
	    }
	}

      /* 3 lookup for content type */
      for (i = 1; i < len; i++)
	{
	  if (!strnicmp (lines[i], "Content-Type:", 13))
	    {
	      char *ctype = lines[i] + 13, ctype1[1024], *p1;
	      unsigned int l;
	      while (ctype && *ctype && *ctype == ' ')
		ctype++;
	      l = strlen (ctype);
	      p1 = ctype + l - 1;
	      /* strip the trailing CR/LF as PHP processor fakes */
	      while (p1 > ctype && *p1 && (*p1 == '\x0D' || *p1 == '\x0A'))
		p1--;
	      l = p1 - ctype + 1;
	      if (l > 0 && l < sizeof (ctype1))
		{
		  strncpy (ctype1, ctype, sizeof (ctype1));
		  ctype1[l] = 0;
		}
	      else
		ctype[0] = 0;

	      SG (request_info).content_type = ctype1;
	      break;
	    }
	}
    }

  /* EXECUTE th PHP request */

  if (string)
    {
      thr_atrp_php.fh = &file_handle;
      strncpy (fname, storage, MAX_FILENAME_LEN - 1);
      fi = fopen (fname, "w");
      fprintf (fi, "%s\n", (char *) string);
      fflush (fi);
      fclose (fi);
      SG (request_info).path_translated = fname;
      file_handle.type = ZEND_HANDLE_FILENAME;
      file_handle.filename = fname;
    }
  else
    {
      file_handle.type = ZEND_HANDLE_FILENAME;
      file_handle.filename = file;
    }

  file_handle.free_filename = 0;
  file_handle.opened_path = NULL;

  if (php_request_startup (TSRMLS_C) == FAILURE)
    {
      return (caddr_t) box_num (1);	/*  XXX make srv error XXX  */
    }
  else
    {
      (&CG (open_files))->dtor =
	  (void (*)(void *)) virt_zend_file_handle_dtor;
    }


  php_execute_script (&file_handle TSRMLS_CC);

  php_request_shutdown (NULL);

  if (string)
    remove (fname);

  ret_str = strses_string (ret);

  /* FREE the memory & handles */


  if (to_free)
    strses_free (post);

  strses_free (ret);

  if (SG (request_info).query_string)
    dk_free_box (SG (request_info).query_string);

  /*  free (SG(request_info).request_uri); */

  if (head_ret)
    {
      *head_ret =
	  (caddr_t *) dk_alloc_box (2 * sizeof (caddr_t),
	  DV_ARRAY_OF_POINTER);
      (*head_ret)[0] = strses_string (s_head);
      (*head_ret)[1] = strses_string (r_head);
    }

  strses_free (s_head);
  strses_free (r_head);

  if (string)
    {
      char *name = (char *) thr_atrp_php.rm_name;
      if (name)
	remove (name);
    }

  return ret_str;
}


caddr_t
bif_http_handler_php (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *params = NULL;
  caddr_t *lines = NULL, *head_ret = NULL;
  caddr_t in_file, file, res;
  int is_alocated = 0;

  in_file = bif_arg (qst, args, 0, "http_handler_php");

  if (DV_TYPE_OF (in_file) == DV_BLOB_HANDLE)
    {
      file = blob_to_string (qst, in_file);
      is_alocated = 1;
    }
  else
    file = in_file;

  if (BOX_ELEMENTS (args) > 1)
    {
      params = (caddr_t *) bif_arg (qst, args, 1, "http_handler_php");
    }

  if (BOX_ELEMENTS (args) > 2)
    {
      lines = (caddr_t *) bif_arg (qst, args, 2, "http_handler_php");
    }

  if (BOX_ELEMENTS (args) > 3)	/* the 1-st parameter is a content of PHP page not a file  */
    {
      caddr_t what =
	  bif_string_or_null_arg (qst, args, 3, "http_handler_php");
      res =
	  http_handler_php ((what ? what : file), params, lines,
	  (what ? file : NULL), &head_ret, (query_instance_t *) qst);
      if (ssl_is_settable (args[3]))
	qst_set (qst, args[3], (caddr_t) head_ret);
      else
	dk_free_tree (head_ret);
    }
  else
    res =
	http_handler_php (file, params, lines, NULL, NULL,
	(query_instance_t *) qst);

  if (is_alocated)
    dk_free_box (file);

  return res;
}


/* This function doing PHP processing from string
   select php_str ('<?php echo abs (-$a) ?>', vector ('a', '10')) ; */
static caddr_t
bif_php_str (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *params = NULL;
  caddr_t *lines = NULL;
  caddr_t in_string = bif_string_arg (qst, args, 0, "php_str");

  if (BOX_ELEMENTS (args) > 1)
    {
      params = (caddr_t *) bif_arg (qst, args, 1, "php_str");
    }

  if (BOX_ELEMENTS (args) > 2)
    {
      lines = (caddr_t *) bif_arg (qst, args, 2, "php_str");
    }

  /*XXX: We will not return headers for now */
  return http_handler_php (NULL, params, lines, in_string, NULL,
      (query_instance_t *) qst);
}
#endif

void
init_func_php (void)
{
#ifdef _PHP
  bif_define ("__http_handler_php", bif_http_handler_php);
  bif_define ("php_str", bif_php_str);
  virtuoso_php_init ();
  log_info ("Hosting Zend/PHP %s", php_dll_version);
#endif
}

#ifndef ONLY_PHP
int
main (int argc, char *argv[])
{
#ifdef MALLOC_DEBUG
  dbg_malloc_enable ();
#endif
  build_set_special_server_model ("PHP4");
  VirtuosoServerSetInitHook (init_func_php);
  return VirtuosoServerMain (argc, argv);
}
#endif

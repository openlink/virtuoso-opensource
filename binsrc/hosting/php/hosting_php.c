/*
 *  hosting_php.c
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
 */

#undef MALLOC_DEBUG

#include "import_gate_virtuoso.h"
#include "hosting.h"
#include "sqlver.h"

/* Remove conflicting defines from Virtuoso */
#define hash_func_t php_hash_func_t
#undef VIRTUAL_DIR
#undef XML_DTD

#ifdef _WIN32
#define HAVE_STRTOK_R 1
#define HAVE_SOCKLEN_T 1
#define C_BEGIN()
#define C_END()
#define _HSREGEX_H
#undef ssize_t
#undef strcasecmp
#undef strncasecmp
#else
#define strnicmp strncasecmp
#endif

#include "php.h"
#include "php_variables.h"
#include "php_main.h"
#include "php_ini.h"
#include "ext/standard/php_standard.h"

#if PHP_MAJOR_VERSION != 4 && PHP_MAJOR_VERSION != 5
#error Unsupported PHP version
#endif

#ifndef ZTS
#error You need to compile PHP with ZTS support
#endif

/****************************************************************************/

typedef struct
  {
    const char *base_uri;
    const char *content;
    const char *params;
    const char **lines;
    const char **options;
    char **head_ret;
    char **diag_ret;
    int n_lines;
    int n_options;
    int compile_only;

    dk_session_t *ret_session;
    dk_session_t *s_hdr_session;
    dk_session_t *r_hdr_session;
    ulong post_length;
    ulong post_position;

  } vreq_t;

/****************************************************************************/
/* Virtuoso plugin registration code */

/* Just to indicate the function is bound to by the Virtuoso plugin loader */
#define _VPLUGIN_

static void hosting_php_connect (void *x);
static caddr_t bif_php_str (caddr_t *qst, caddr_t *err, state_slot_t **args);
static void start_hosting (void);

static hosting_version_t hosting_php_version = {
  {
    HOSTING_TITLE,				/* Title */
    DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR,	/* Version */
    "OpenLink Software",			/* Plugin's developer */
    "PHP engine version " PHP_VERSION,		/* Any additional info */
    NULL,					/* Error message */
    NULL,					/* Filename with unit's code */
    hosting_php_connect,			/* Connect function */
    NULL,					/* Disconnect function */
    NULL,					/* Activation function */
    NULL,					/* Deactivation function */
    &_gate,
  },
  NULL, NULL, NULL, NULL, NULL, NULL,
  1						/* Using_boxes */
};


_VPLUGIN_ unit_version_t *
hosting_php_check (unit_version_t *in, void *appdata)
{
  static char *args[2];
  args[0] = "php";
  args[1] = NULL;
  hosting_php_version.hv_extensions = args;
  return &hosting_php_version.hv_pversion;
}


static void
hosting_php_connect (void *x)
{
  bif_define ("php_str", bif_php_str);

  start_hosting ();
}


_VPLUGIN_ void *
virtm_client_attach (char *err, int max_len)
{
  return (void *) 0x0dbcc0de;
}


_VPLUGIN_ void
virtm_client_detach (void *cli)
{
}


_VPLUGIN_ void *
virtm_client_clone (void *cli, char *err, int max_err_len)
{
  return cli;
}


_VPLUGIN_ void
virtm_client_free (void *ptr)
{
}


static char *
virt_get_env (const char *name TSRMLS_DC)
{
  vreq_t *r = ((vreq_t *) SG (server_context));
  int i;

  /* XXX hashtable */
  for (i = 0; i < r->n_options; i += 2)
    {
      if (!strcmp (r->options[i], name))
	{
	  const char *ret = r->options[i + 1];
	  if (ret && ret[0])
	    return (char *) ret;
	  break;
	}
    }

  return NULL;
}


static void
init_request_info (TSRMLS_D)
{
  char *clen;

  SG (request_info).query_string = virt_get_env ("QUERY_STRING" TSRMLS_CC);
  SG (request_info).path_translated = virt_get_env ("PATH_TRANSLATED" TSRMLS_CC);
  SG (request_info).request_uri = virt_get_env ("REQUEST_URI" TSRMLS_CC);
  SG (request_info).request_method = virt_get_env ("REQUEST_METHOD" TSRMLS_CC);
  SG (request_info).content_type = virt_get_env ("CONTENT_TYPE" TSRMLS_CC);
  clen = virt_get_env ("CONTENT_LENGTH" TSRMLS_CC);
  SG (request_info).content_length = clen ? atoi (clen) : 0;
  SG (sapi_headers).http_response_code = 200;
#if PHP_MAJOR_VERSION >= 5
  SG (request_info).proto_num = 1001;
#endif
  php_handle_auth_data (virt_get_env ("AUTHORIZATION" TSRMLS_CC) TSRMLS_CC);
}


_VPLUGIN_ char *
virtm_http_handler (void *cli, char *err, int max_len,
    const char *base_uri, const char *content,
    const char *params, const char **lines, int n_lines,
    char **head_ret, const char **options, int n_options, char **diag_ret,
    int compile_only)
{
  zend_file_handle file_handle;
  box_t *hret;
  vreq_t req;

  TSRMLS_FETCH ();

  /* cannot execute DAV content with this implementation of the PHP plugin */
  if (content)
    sqlr_new_error ("22023", "PHP01",
	"The PHP hosting module does not support execution of WebDAV content.");

  memset (&req, 0, sizeof (req));
  req.base_uri = base_uri;
  req.content = content;
  req.params = params;
  req.lines = lines;
  req.n_lines = n_lines;
  req.head_ret = head_ret;
  req.options = options;
  req.n_options = n_options;
  req.diag_ret = diag_ret;
  req.compile_only = compile_only;
  req.ret_session = strses_allocate ();
  req.s_hdr_session = strses_allocate ();
  req.r_hdr_session = strses_allocate ();
  req.post_length = box_length (params) - 1;

  SG (server_context) = &req;
  init_request_info (TSRMLS_C);

  memset (&file_handle, 0, sizeof (file_handle));
  file_handle.type = ZEND_HANDLE_FILENAME;
  file_handle.filename = SG (request_info).path_translated;
  file_handle.free_filename = 0;

  if (php_request_startup (TSRMLS_C) != FAILURE)
    {
      php_execute_script (&file_handle TSRMLS_CC);
      php_request_shutdown (NULL);
    }

  hret = (box_t *) dk_alloc_box (2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  hret[0] = (box_t) strses_string (req.s_hdr_session);
  hret[1] = (box_t) strses_string (req.r_hdr_session);
  *head_ret = (char *) hret;

  strses_free (req.s_hdr_session);
  strses_free (req.r_hdr_session);

  return (char *) req.ret_session;
}


static caddr_t
bif_php_str (caddr_t *qst, caddr_t *err, state_slot_t **args)
{
  int n_args = BOX_ELEMENTS (args);
  caddr_t in_string = bif_string_arg (qst, args, 0, "php_str");
  caddr_t params = (n_args > 1) ? bif_string_arg (qst, args, 1, "php_str") : "";
  caddr_t lines = (n_args > 2) ? bif_array_arg (qst, args, 2, "php_str") : NULL;
  zend_file_handle file_handle;
  char *tmpfn;
  FILE *tmpfd;
  char *ret_str;
  vreq_t req;
  char *options[4];
 
  TSRMLS_FETCH ();

  if ((tmpfn = tempnam (NULL, "virtmp")) == NULL)
    return NEW_DB_NULL;
  if ((tmpfd = fopen (tmpfn, "wb")) == NULL)
    {
      free (tmpfn);
      return NEW_DB_NULL;
    }
  fwrite (in_string, 1, box_length (in_string) - 1, tmpfd);
  fclose (tmpfd);

  memset (&req, 0, sizeof (req));
  req.lines = (const char **) lines;
  req.n_lines = lines ? BOX_ELEMENTS (lines) : 0;
  req.params = "";
  req.options = (const char **) options;
  req.n_options = 4;
  req.ret_session = strses_allocate ();

  SG (server_context) = &req;

  options[0] = "REQUEST_METHOD"; options[1] = "GET";
  options[2] = "QUERY_STRING"; options[3] = params;

  init_request_info (TSRMLS_C);

  if (php_request_startup (TSRMLS_C) == FAILURE)
    ret_str = NEW_DB_NULL;
  else
    {
      memset (&file_handle, 0, sizeof (file_handle));
      file_handle.type = ZEND_HANDLE_FILENAME;
      file_handle.filename = tmpfn;
      file_handle.free_filename = 0;

      php_execute_script (&file_handle TSRMLS_CC);

      php_request_shutdown (NULL);

      ret_str = strses_string (req.ret_session);
    }

  strses_free (req.ret_session);
  unlink (tmpfn);
  free (tmpfn);

  return ret_str;
}


static void
virt_log (int level, char *fmt, ...)
{
  va_list ap;

  va_start (ap, fmt);
  server_logmsg_ap (level, NULL, 0, 1, fmt, ap);
  va_end (ap);
}

/****************************************************************************/
/* SAPI callbacks */

extern zend_module_entry virtuoso_module_entry;

ZEND_BEGIN_MODULE_GLOBALS(virtuoso)
    /* configuration parameters */
    zend_bool logging;	/* if true, logging to virtuoso.log is enabled */
    /* for __virt_interal_dsn: */
    char *local_dsn;	/* default DSN to return */
    zend_bool allow_dba;/* allow 'dba'/'dav' */
ZEND_END_MODULE_GLOBALS(virtuoso)

int virtuoso_globals_id = -1;
#define VG(v) TSRMG(virtuoso_globals_id, zend_virtuoso_globals *, v)

static int sapi_virtuoso_startup (sapi_module_struct *sapi_module);
static int sapi_virtuoso_activate (TSRMLS_D);
static int sapi_virtuoso_deactivate (TSRMLS_D);
static int sapi_virtuoso_ub_write (const char *str, uint str_length TSRMLS_DC);
static void sapi_virtuoso_flush (void *server_context);
static char *sapi_virtuoso_getenv (char *name, size_t name_len TSRMLS_DC);
static int sapi_virtuoso_header_handler (
    sapi_header_struct *sapi_header,
#if PHP_VERSION_ID >= 50300
    sapi_header_op_enum op,
#endif
    sapi_headers_struct *sapi_headers TSRMLS_DC);
static int sapi_virtuoso_send_headers (
    sapi_headers_struct *sapi_headers TSRMLS_DC);
static int sapi_virtuoso_read_post(char *buffer, uint count_bytes TSRMLS_DC);
static char *sapi_virtuoso_read_cookies (TSRMLS_D);
static void sapi_virtuoso_register_server_variables (zval *track_vars_array TSRMLS_DC);
static void sapi_virtuoso_log_message (char *message);

static sapi_module_struct virtuoso_sapi_module =
  {
    "Virtuoso",				/* name */
    "Virtuoso Universal Server",	/* pretty name */

    sapi_virtuoso_startup,		/* startup */
    php_module_shutdown_wrapper,	/* shutdown */

    sapi_virtuoso_activate,		/* activate */
    sapi_virtuoso_deactivate,		/* deactivate */

    sapi_virtuoso_ub_write,		/* unbuffered write */
    sapi_virtuoso_flush,		/* flush */
    NULL,				/* get uid */
    sapi_virtuoso_getenv,		/* getenv */

    php_error,				/* error handler */

    sapi_virtuoso_header_handler,	/* header handler */
    sapi_virtuoso_send_headers,		/* send headers handler */
    NULL,				/* send header handler */

    sapi_virtuoso_read_post,		/* read POST data */
    sapi_virtuoso_read_cookies,		/* read Cookies */

    sapi_virtuoso_register_server_variables,/* register server variables */
    sapi_virtuoso_log_message,		/* log message */
#if PHP_MAJOR_VERSION >= 5
    NULL,				/* get request time */
#endif

    NULL,				/* php.ini path override */

    NULL,				/* block interruptions */
    NULL,				/* unblock interruptions */

    NULL,				/* default post reader */
    NULL,				/* treat data */
    NULL,				/* exe location */
    0,					/* ini ignore */
  };

static void
start_hosting (void)
{
  char *ini;

  tsrm_startup (1, 1, 0, NULL);
  if ((ini = getenv("PHP_INI_PATH")))
    virtuoso_sapi_module.php_ini_path_override = ini;
  sapi_startup (&virtuoso_sapi_module);
  sapi_virtuoso_startup (&virtuoso_sapi_module);
}


static int
sapi_virtuoso_startup (sapi_module_struct *sapi_module)
{
  if (php_module_startup (sapi_module, &virtuoso_module_entry, 1) == FAILURE)
    return FAILURE;

  return SUCCESS;
}


static int
sapi_virtuoso_activate (TSRMLS_D)
{
  return SUCCESS;
}


static int
sapi_virtuoso_deactivate (TSRMLS_D)
{
  return SUCCESS;
}


static int
sapi_virtuoso_ub_write (const char *str, uint str_length TSRMLS_DC)
{
  vreq_t *r = ((vreq_t *) SG (server_context));

  session_buffered_write (r->ret_session, (char *) str, str_length);

  return 0;
}


static void
sapi_virtuoso_flush (void *server_context)
{
}


static char *
sapi_virtuoso_getenv (char *name, size_t name_len TSRMLS_DC)
{
  return virt_get_env (name TSRMLS_CC);
}


static int
sapi_virtuoso_header_handler (
    sapi_header_struct *sapi_header,
#if PHP_VERSION_ID >= 50300
    sapi_header_op_enum op,
#endif
    sapi_headers_struct *sapi_headers TSRMLS_DC)
{
  vreq_t *r = ((vreq_t *) SG (server_context));

#if PHP_VERSION_ID >= 50300
  if (op != SAPI_HEADER_ADD && op != SAPI_HEADER_REPLACE)
    return SAPI_HEADER_ADD;
#endif

  if (sapi_header && sapi_header->header_len && sapi_header->header && r->r_hdr_session)
    {
      /* Custom Content-length headers seem to confuse Virtuoso...
       * Bad idea anyway. Use the correct calculated value instead.
       */
      static const char content_length[] = "content-length: ";
      if (sapi_header->header_len > sizeof(content_length) - 1 &&
	  !strnicmp (sapi_header->header, content_length, sizeof (content_length) - 1))
	{
	  return SAPI_HEADER_ADD;
	}

      session_buffered_write (r->r_hdr_session, sapi_header->header,
	  sapi_header->header_len);
      session_buffered_write (r->r_hdr_session, "\r\n", 2);
    }

  return SAPI_HEADER_ADD;
}


static int
sapi_virtuoso_send_headers (sapi_headers_struct *sapi_headers TSRMLS_DC)
{
  vreq_t *r = ((vreq_t *) SG (server_context));

  if (sapi_headers && r->s_hdr_session)
    {
      if (sapi_headers->http_status_line)
	{
	  session_buffered_write (r->s_hdr_session,
	      sapi_headers->http_status_line, strlen (sapi_headers->http_status_line));
	}
      else if (sapi_headers->http_response_code)
	{
	  char tmp [100];
	  sprintf (tmp, "HTTP/1.1 %d HTTP", sapi_headers->http_response_code);
	  session_buffered_write (r->s_hdr_session, tmp, strlen (tmp));
	}
      sapi_headers->http_response_code = 0;
    }

  return SAPI_HEADER_SENT_SUCCESSFULLY;
}


static int
sapi_virtuoso_read_post (char *buffer, uint count_bytes TSRMLS_DC)
{
  vreq_t *r = ((vreq_t *) SG (server_context));

  if (r->post_position + count_bytes > r->post_length)
    count_bytes = r->post_length - r->post_position;

  memcpy (buffer, r->params + r->post_position, count_bytes);
  r->post_position += count_bytes;

  return count_bytes;
}


static char *
sapi_virtuoso_read_cookies (TSRMLS_D)
{
  return virt_get_env ("HTTP_COOKIE" TSRMLS_CC);
}


static void
sapi_virtuoso_register_server_variables (zval *track_vars_array TSRMLS_DC)
{
  vreq_t *r = ((vreq_t *) SG (server_context));
  uint new_val_len;
  int i;
  char *name;
  char *val;
  int val_len;

  for (i = 0; i < r->n_options; i += 2)
    {
      name = (char *) r->options[i];
      val = (char *) r->options[i + 1];
      if (!val)
	val = "";
      val_len = (int) strlen (val);
      php_register_variable (name, val, track_vars_array TSRMLS_CC);
    }
  if ((val = virt_get_env ("SCRIPT_NAME" TSRMLS_CC)) != NULL)
    {
#if PHP_MAJOR_VERSION == 4
      php_register_variable ("PHP_SELF", val, track_vars_array TSRMLS_CC);
#else
      if (sapi_module.input_filter (PARSE_SERVER, "PHP_SELF", &val,
	    (uint) strlen (val), &new_val_len TSRMLS_CC))
	{
	  php_register_variable ("PHP_SELF", val, track_vars_array TSRMLS_CC);
	}
#endif
    }
}


static void
sapi_virtuoso_log_message (char *message)
{
  TSRMLS_FETCH ();

  if (-1 == virtuoso_globals_id || VG (logging))
    virt_log (LOG_ERR, "%s", message);
}

/****************************************************************************/
/* Zend callbacks */

#define SECTION(name)  PUTS("<h2>" name "</h2>\n")

#ifdef ZEND_ENGINE_2
#define OnUpdateInt OnUpdateLong
#endif

PHP_INI_BEGIN()
STD_PHP_INI_BOOLEAN ("virtuoso.logging", "1", PHP_INI_SYSTEM,
    OnUpdateBool, logging, zend_virtuoso_globals, virtuoso_globals)
STD_PHP_INI_ENTRY ("virtuoso.local_dsn",  "Local Virtuoso", PHP_INI_SYSTEM,
    OnUpdateString, local_dsn, zend_virtuoso_globals, virtuoso_globals)
STD_PHP_INI_ENTRY ("virtuoso.allow_dba", "0", PHP_INI_SYSTEM,
    OnUpdateInt, allow_dba, zend_virtuoso_globals, virtuoso_globals)
PHP_INI_END()


static void
php_virtuoso_globals_ctor (zend_virtuoso_globals *virtuoso_globals TSRMLS_DC)
{
  virtuoso_globals->logging = 1;
  virtuoso_globals->local_dsn = NULL;
  virtuoso_globals->allow_dba = 1;
}


static void
php_virtuoso_globals_dtor (zend_virtuoso_globals *virtuoso_globals TSRMLS_DC)
{
}


static
PHP_MINIT_FUNCTION (virtuoso)
{
  ZEND_INIT_MODULE_GLOBALS (virtuoso,
      php_virtuoso_globals_ctor, php_virtuoso_globals_dtor);
  REGISTER_INI_ENTRIES ();

  return SUCCESS;
}


static
PHP_MSHUTDOWN_FUNCTION (virtuoso)
{
  ts_free_id (virtuoso_globals_id);
  UNREGISTER_INI_ENTRIES ();

  return SUCCESS;
}


static
PHP_MINFO_FUNCTION (virtuoso)
{
  vreq_t *r = ((vreq_t *) SG (server_context));
  int i;

  php_info_print_table_start ();
  php_info_print_table_row (2, "Server Version", DBMS_SRV_VER);
  php_info_print_table_row (2, "Build Date", __DATE__);
  php_info_print_table_row (2, "Revision", "$Revision$");
  php_info_print_table_end ();

  DISPLAY_INI_ENTRIES ();

  SECTION ("Virtuoso Environment");
  php_info_print_table_start ();
  php_info_print_table_header (2, "Variable", "Value");
  for (i = 0; i < r->n_options; i += 2)
    {
      if (PG (safe_mode) && !strcasecmp (r->options[i], "AUTHORIZATION"))
	continue;
      php_info_print_table_row (2, r->options[i], r->options[i + 1]);
    }
  php_info_print_table_end ();

  SECTION ("HTTP Headers Information");
  php_info_print_table_start ();
  php_info_print_table_colspan_header (2, "HTTP Request Headers");
  if (r->n_lines > 0)
    php_info_print_table_row (2, "HTTP Request", r->lines[0]);
  php_info_print_table_header (2, "Variable", "Value");
  for (i = 1; i < r->n_lines; i++)
    {
      char *p = strdup (r->lines[i]);
      char *q = strchr (p, ':');
      if (q && q[1] == ' ' &&
	  (!PG (safe_mode) || (PG (safe_mode) && strcasecmp (q, "Authorization"))))
	{
	  char *r = strchr (q, '\r');
	  *q = 0;
	  if (r) *r = 0;
	  php_info_print_table_row (2, p, q + 2);
	}
      free (p);
    }
  php_info_print_table_end ();
}


static
PHP_FUNCTION (getallheaders)
{
  vreq_t *r = ((vreq_t *) SG (server_context));
  int i;

  array_init(return_value);
  for (i = 1; i < r->n_lines; i++)
    {
      char *p = strdup (r->lines[i]);
      char *q = strchr (p, ':');
      if (q && q[1] == ' ')
	{
	  char *r = strchr (q, '\r');
	  *q = 0;
	  if (r) *r = 0;
	  add_assoc_string (return_value, p, q + 2, 1);
	}
      free (p);
    }
}


/*
 *  This constructs an ODBC connect string suitable to talk back to
 *  the server using the credentials the php script is running under.
 *  These credentials are associated with the virtual directory of the
 *  application, and can be set through the Virtuoso conductor.
 *  usage: __virt_internal_dsn([dsn])
 */
static
PHP_FUNCTION (__virt_internal_dsn)
{
  client_connection_t *cli;
  user_t *usr;
  char *dsn = NULL;
  int dsn_len;
  char *connstr;

  /* get the dsn argument, or use the default ('Local Virtuoso') if not given */
  if (zend_parse_parameters (ZEND_NUM_ARGS () TSRMLS_CC, "|s", &dsn, &dsn_len) == FAILURE)
    RETURN_FALSE;

  if (dsn == NULL && (dsn = VG (local_dsn)) == NULL)
    RETURN_FALSE;

  /* get the user account associated with this endpoint */
  cli = GET_IMMEDIATE_CLIENT_OR_NULL;
  if (cli == NULL || (usr = cli->cli_user) == NULL || !usr->usr_name)
    {
      php_error_docref (NULL TSRMLS_CC, E_WARNING,
	  "The Virtuoso application endpoint has not been configured properly");
      RETURN_FALSE;
    }
  /* make sure user is regular and enabled for SQL access */
  if (usr->usr_disabled || !usr->usr_is_sql || usr->usr_is_role || !usr->usr_pass)
    {
      php_error_docref (NULL TSRMLS_CC, E_WARNING,
	  "The Virtuoso application endpoint has been configured to use the "
	  "disabled or invalid user '%s'",
	  usr->usr_name);
      RETURN_FALSE;
    }

  /* disallow 'dba', 'dav' and other system privileged users */
  if (usr->usr_id < (oid_t) 100 && !VG (allow_dba))
    {
      php_error_docref (NULL TSRMLS_CC, E_WARNING,
	  "Security settings prohibit internal connections as Virtuoso user '%s'",
	  usr->usr_name);
      RETURN_FALSE;
    }

  spprintf (&connstr, 0, "DSN=%s;UID=%s;PWD=%s", dsn, usr->usr_name, usr->usr_pass);
  RETURN_STRING (connstr, 0);
}


static zend_function_entry virtuoso_functions[] =
  {
    PHP_FE (getallheaders, NULL)
    PHP_FE (__virt_internal_dsn, NULL)
    PHP_FALIAS (apache_request_headers, getallheaders, NULL)
    { NULL, NULL, NULL }
  };

zend_module_entry virtuoso_module_entry =
  {
    STANDARD_MODULE_HEADER,
    "Virtuoso",
    virtuoso_functions,
    PHP_MINIT (virtuoso),
    PHP_MSHUTDOWN (virtuoso),
    NULL,
    NULL,
    PHP_MINFO (virtuoso),
    NO_VERSION_YET,
    STANDARD_MODULE_PROPERTIES
  };

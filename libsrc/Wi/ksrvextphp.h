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

static int sapi_virtuoso_ub_write(const char *str, uint str_length TSRMLS_DC);
static int sapi_virtuoso_send_headers(sapi_headers_struct *sapi_headers TSRMLS_DC);
static int sapi_virtuoso_read_post(char *buffer, uint count_bytes TSRMLS_DC);
static char *sapi_virtuoso_read_cookies(TSRMLS_D);
static void sapi_virtuoso_register_variables(zval *track_vars_array TSRMLS_DC);

long strses_get_part (dk_session_t *ses, void *buf2, int64 starting_ofs, long nbytes);
void php_register_variable(char *var, char *strval, zval *track_vars_array TSRMLS_DC);

ZEND_API int alloc_globals_id;
HashTable *global_function_table;
HashTable *global_class_table;
HashTable *global_constants_table;

int sapi_virtuoso_handle_headers (sapi_header_struct *sapi_header, sapi_headers_struct *sapi_headers TSRMLS_DC);

char remote_client_ip[16] = "";
char remote_client_port[16] = "";
char server_ip[16] = "";
char req_mtd[16] = "";
char req_http_ver[2048] = "";
char script_name[2048] = "";
char lines_0[2048] = "";
char server_signature[2048] = "";
char *php_ini_admin;
char * srv_http_port ();
char * srv_www_root ();
caddr_t srv_dns_host_name ();
char * srv_st_dbms_name ();
char * srv_st_dbms_ver ();
char *php_dll_version;
char *php_ini_version;
void srv_ip (char *ip_addr, size_t max_ip_addr, char *host);
void dks_client_ip (client_connection_t *cli, char *buf, char *user, char *peer, int buf_len, int user_len, int peer_len);
void dks_client_port (client_connection_t *cli, char *port, int len);

static int sapi_virtuoso_activate(TSRMLS_D);
static char *php_virtuoso_getenv(char *name, size_t name_len TSRMLS_DC);
static void sapi_virtuoso_register_variables(zval *track_vars_array TSRMLS_DC);
static int php_module_startup_int(sapi_module_struct *sapi_module);
extern PHPAPI char *php_ini_opened_path;
int log_error (char *format, ...);

#define SECTION(name)  PUTS("<H2 align=\"center\">" name "</H2>\n")

#define APP_POST_CONTENT_TYPE   "application/x-www-form-urlencoded"
#define MULTIPART_CONTENT_TYPE  "multipart/form-data"

#define VIRT_PRINT_OUT 77
#define TLS_FETCH()

#define BUF_SIZE_VIRT_PHP 512
#define ADD_STRING(name)										\

#define VSLS_FETCH() char *global_str = ts_resource(virt_globals_id)

#define VIRT_ISTERAM_FH 10 /* trick, we will overwrite the filehandle type with own type */

FILE * (*php_fopen_func)(const char *filename, char **opened_path);
zend_op_array *(*php_compile_file)(zend_file_handle *file_handle, int type TSRMLS_DC);

typedef struct
{
  dk_session_t *ret_val;
  dk_session_t *post;
  dk_session_t *r_head;
  dk_session_t *s_head;
  caddr_t *in_lines;
  char *cookie;
  zend_file_handle *fh;
  query_instance_t * qi;
  char *org_file_name;
  char *rm_name;
  int post_position;
} thr_atrp;

int virtuoso_cfg_getstring (char *section, char *key, char **pret);
void build_set_special_server_model (const char *new_model);

typedef void (*exit_hook_t) (void);
void VirtuosoServerSetInitHook (void (*hook) (void));
exit_hook_t VirtuosoServerSetExitHook (exit_hook_t exitf);
int VirtuosoServerMain (int argc, char **argv);


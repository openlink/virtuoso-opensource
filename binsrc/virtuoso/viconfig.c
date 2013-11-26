/*
 *  viconfig.c
 *
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

/*#define WIN95COMPAT*/ /*!!! To avoid using SetAffinityMask() */

#include "libutil.h"
#include "sqlnode.h"
#include "sqlver.h"


#include "util/sslengine.h"
#include "plugin.h"
#include "langfunc.h"
#include "msdtc.h"

#ifdef _RENDEZVOUS
#include "rendezvous.h"
#endif

#define s_strdup(X) strdup(X)
#define log   logit

#ifdef WIN32
#define __S_ISTYPE(mode, mask)  (((mode) & _S_IFMT) == (mask))
#define S_ISDIR(mode)    __S_ISTYPE((mode), _S_IFDIR)
#ifdef _MSC_VER
#define HAVE_DIRECT_H
#endif
#endif

#ifdef HAVE_DIRECT_H
#include <direct.h>
#include <io.h>
#define PATH_MAX   MAX_PATH
#else
#include <dirent.h>
#endif

#ifndef PATH_MAX
#ifdef _MAX_PATH
#define PATH_MAX _MAX_PATH
#endif
#endif

#if defined (HAVE_FLOCK_IN_SYS_FILE)
#include <sys/file.h>
#endif

extern PCONFIG pconfig;     /* configuration file */

/* Globals for libwi */
void it_make_buffer_list (index_tree_t * it, int n);

extern int cp_unremap_quota;
extern int correct_parent_links;
extern long repl_queue_max;
extern int main_bufs;
extern long file_extend;
extern char *db_name;
extern char *repl_server_enable;
extern int isdts_mode;
extern int n_oldest_flushable;
#if 0/*obsoleted*/
extern int atomic_dive;
extern int null_bad_dtp;
#endif
extern int prefix_in_result_col_names;
extern int disk_no_mt_write;
extern long vd_param_batch;
extern long vd_opt_arrayparams;
extern char *www_root;
extern char *dav_root;
extern long vsp_in_dav_enabled;
extern long http_proxy_enabled;
extern char *default_mail_server;
extern char *allowed_dirs;
extern char *init_trace;
extern char *denied_dirs;
extern char *safe_execs;
extern char *dba_execs;
extern char *temp_dir;
extern char *temp_ses_dir;
extern char *server_default_language_name;
extern long vdb_no_stmt_cache; /* from sqlrrun.c */
extern char *vdb_odbc_error_file; /* from sqlrrun.c */
extern char *vdb_trim_trailing_spaces; /* from sqlrrun.c */
extern long cfg_disable_vdb_stat_refresh;
extern char *www_maintenance_page;
extern char *http_proxy_address;
extern char *http_cli_proxy_server;
extern char *http_cli_proxy_except;
extern int32 http_enable_client_cache;
extern int32 log_proc_overwrite;

#ifdef _SSL
extern char *https_port;
extern char *https_cert;
extern char *https_key;
extern char *https_extra;
extern int32 https_client_verify;
extern int32 https_client_verify_depth;
extern char * https_client_verify_file;
extern char * https_client_verify_crl_file;

extern char *c_ssl_server_port;
extern char *c_ssl_server_cert;
extern char *c_ssl_server_key;
extern char *c_ssl_server_extra_certs;
extern int32 ssl_server_verify;
extern int32 ssl_server_verify_depth;
extern char *ssl_server_verify_file;
#endif
extern int spotlight_integration;
#ifdef BIF_XML
#ifdef _IMSG
extern int pop3_port;
extern int nntp_port;
extern int ftp_port;
extern int ftp_server_timeout;
#endif
#endif
extern int enable_gzip;
extern int http_ses_size;
extern long vt_batch_size_limit;
extern long rds_disconnect_timeout; /* from sqlrrun.c */
extern long vdb_use_global_pool; /* from sqlrrun.c */
extern unsigned long vdb_oracle_catalog_fix; /* from odbccat.c */
extern long vdb_attach_autocommit; /* from odbccat.c */
extern int32 http_keep_alive_timeout;
extern long http_max_keep_alives;
extern long http_max_cached_proxy_connections;
extern long http_proxy_connection_cache_timeout;
extern char * http_server_id_string;
extern char * http_client_id_string;
extern char * http_soap_client_id_string;
extern long http_ses_trap;
extern int http_check_rdf_accept;
extern int32 http_limited;

extern int vd_use_mts;

extern char *temp_aspx_dir;

extern char *java_classpath;
extern dk_set_t old_backup_dirs;
extern const char* recover_file_prefix;

/* Do automatic checkpoint approximately every N milliseconds. */
/* If zero, don't do it. */
/* Specified in minutes. Note that 1440 minutes = 24 hours. */
extern unsigned long cfg_autocheckpoint; /* from auxfiles.c */
extern int default_txn_isolation;
extern int c_col_by_default;
extern int c_use_aio;
extern long txn_after_image_limit; /* from log.c */
extern int iri_cache_size;
extern int32 iri_range_size;
extern int uriqa_dynamic_local;
extern int lite_mode;
extern int rdf_obj_ft_rules_size;
extern int it_n_maps;
extern int32 rdf_shorten_long_iri;
extern int32 ric_samples_sz;
extern int32 enable_p_stat;
extern int aq_max_threads;
extern int c_compress_mode;

char * http_log_file_check (struct tm *now); /* http log name checking */

int32 c_txn_after_image_limit;
int32 c_n_fds_per_file;
int32 c_syslog = 0;
char *c_syslog_facility = NULL;
/* These are the config variables as read here */
char *c_error_log_file;
char *c_database_file;
char *c_lock_file;
char *c_txfile;
char *c_serverport;
char *http_log_file = NULL;
extern FILE *http_log;
extern char *http_log_name;
int32 c_error_log_level;
int32 c_server_threads;
int32 c_number_of_buffers;
int32 c_lock_in_mem;
int32 c_max_dirty_buffers;
int32 c_max_checkpoint_remap;
int32 c_unremap_quota;
int32 c_file_extend;
int32 c_case_mode;
int32 c_isdts;
int32 c_null_unspecified_params;
int32 c_prefix_resultnames;
int32 c_disable_mt_write;
int32 c_bad_parent_links;
extern int32 dbs_check_extent_free_pages;
extern int32 dbs_cache_check_enable;
#if 0/*obsoleted*/
int32 c_bad_dtp;
int32 c_atomic_dive;
#endif
extern int32 c_checkpoint_interval;
int32 c_scheduler_period;
int32 c_oldest_flushable;
int32 c_striping;
int32 c_max_static_cursor_rows;
int32 c_min_checkpoint_size;
int32 c_autocheckpoint_log_size;
extern int32 c_checkpoint_sync;
int32 c_rds_disconnect_timeout;
int32 c_vdb_use_global_pool;
int32 c_vdb_oracle_catalog_fix;
int32 c_vdb_attach_autocommit;
int32 c_vd_use_mts;
int32 c_vdb_reconnect_on_vdb_error;
int32 c_vdb_client_fixed_thread;
int32 c_prpc_burst_timeout_msecs;
int32 c_vdb_serialize_connect;
int32 c_disable_listen_on_unix_sock;
int32 c_disable_listen_on_tcp_sock;
int32 c_default_txn_isolation;
int32 c_c_use_aio;
int32 c_aq_max_threads;

extern int disable_listen_on_unix_sock;
extern int disable_listen_on_tcp_sock;

extern long prpc_burst_timeout_msecs;

extern long reconnect_on_vdb_error;
extern int32 vdb_client_fixed_thread;
extern int32 vdb_serialize_connect;
extern int prpc_disable_burst_mode;
extern int prpc_forced_fixed_thread;
extern int prpc_force_burst_mode;

extern long sqlc_add_views_qualifiers;
int32 c_sqlc_add_views_qualifiers;

dk_set_t c_stripes;
int32 c_log_segments_num;
log_segment_t *c_log_segments;
int32 c_log_audit_trail;
int32 c_use_array_params = 0;
int32 c_num_array_params = 10;
int32 c_server_thread_sz = 60000;
int32 c_main_thread_sz = 140000;
int32 c_future_thread_sz = 140000;
int32 c_vdb_no_stmt_cache = 0;
int32 c_cfg_disable_vdb_stat_refresh = 0;
int32 c_skip_dml_primary_key = 0;
int32 c_remote_pk_not_unique = 0;
char *c_vdb_odbc_error_file = NULL;
char *c_vdb_trim_trailing_spaces = NULL;
extern int sqlc_no_remote_pk;
extern int remote_pk_not_unique;

unsigned long int c_cfg_thread_live_period = 0;
unsigned long int c_cfg_resources_clear_interval = 0;
unsigned long int c_cfg_thread_threshold = 10;

extern unsigned long int cfg_thread_live_period;
extern unsigned long int cfg_thread_threshold;
extern unsigned long cfg_resources_clear_interval;


char *c_default_collation_name;
char *c_default_charset_name;
char *c_ws_default_charset_name;
char *c_http_port = 0;
#ifdef _SSL
char *c_https_port = 0;
char *c_https_cert = 0;
char *c_https_key = 0;
int32 c_https_client_verify = 0;
int32 c_https_client_verify_depth = 0;
char *c_https_client_verify_file = 0;
#endif
#ifdef _IMSG
int32 c_pop3_port = 0;
int32 c_nntp_port = 0;
int32 c_ftp_port = 0;
int32 c_ftp_server_timeout = 0;
#endif
char *c_dav_root = 0;
long c_vsp_in_dav_enabled = 0;
long c_http_proxy_enabled = 0;
long c_gzip_enabled = 0;
long c_spotlight_integration = 0;
long c_http_ses_size = 0;
char *c_default_mail_server = 0;
char *c_init_trace = 0;
char *c_allowed_dirs = 0;
char *c_backup_dirs = 0;
char *c_temp_aspx_dir = 0;
char *c_java_classpath = 0;
char *c_denied_dirs = 0;
char *c_safe_execs = 0;
char *c_dba_execs = 0;
char *c_temp_dir = 0;
char *c_temp_ses_dir = 0;
char *c_server_default_language_name = 0;
int32 c_http_threads = 0;
int32 c_http_max_keep_alives = 0;
int32 c_http_keep_alive_timeout = 0;
int32 c_http_max_cached_proxy_connections = 0;
int32 c_http_proxy_connection_cache_timeout = 0;
int32 c_http_thread_sz = 280000;
int32 c_http_keep_hosting = 0;
extern long http_keep_hosting; /* from http.c */
char *c_ucm_load_path = 0;
int32 c_lh_xany_normalization_flags = 0;
int32 c_i18n_wide_file_names = 0;
char *c_i18n_volume_encoding = NULL;
char *c_i18n_volume_emergency_encoding = NULL;
extern int lh_xany_normalization_flags;
extern int i18n_wide_file_names;
extern struct encoding_handler_s *i18n_volume_encoding;
extern struct encoding_handler_s *i18n_volume_emergency_encoding;

char *c_plugin_load_path = 0;
int32 c_http_ses_trap = 0;
int32 c_http_check_rdf_accept = 0;
int32 c_iri_cache_size = 0;
int32 c_lite_mode = 0;
int32 c_uriqa_dynamic_local = 0;
int32 c_rdf_obj_ft_rules_size = 0;
int32 c_it_n_maps = 0;
extern int32 c_dense_page_allocation;

/* externs about client configuration */
extern int32 cli_prefetch;
extern int32 cli_prefetch_bytes;
extern int32 cli_query_timeout;
extern int32 cli_txn_timeout;
extern int32 cli_not_c_char_escape;
extern int32 cli_utf8_execs;
extern int32 cli_binary_timestamp;
extern int32 cli_no_system_tables;
extern int32 cli_max_cached_stmts;

int32 c_cli_encryption_on_password;
extern long cli_encryption_on_password;

extern caddr_t client_defaults;
void srv_client_defaults_init ();
extern void srv_plugins_init (void);

/* externals for duplicated functions */
extern void (*cfg_replace_log)(char *str);
extern void (*cfg_set_checkpoint_interval)(int32 f);

extern dp_addr_t crashdump_start_dp, crashdump_end_dp;

int32 c_vt_batch_size_limit = 0;

int32 c_callstack_on_exception = 0;
extern long callstack_on_exception; /* from sqlintrp.c */

int32 c_pl_debug_all = 0;
extern long pl_debug_all;

char *c_pl_debug_cov_file = NULL;
extern char * pl_debug_cov_file;

int32 c_log_file_line = 0;
extern unsigned long log_file_line; /* from Dkernel.c */

/*int32 c_sqlo_enable = 1;*/

int32 c_sqlo_max_layouts = 0;
extern int sqlo_max_layouts; /* from sqldf.c */
extern int32 sqlo_compiler_exceeds_run_factor;
extern int32 sqlo_max_mp_size;

int32 c_sql_proc_use_recompile = 0;
extern int sql_proc_use_recompile; /* from sqlcomp2.c */

int32 c_temp_allocation_pct = 0;
#ifdef WIN32
int32 c_single_processor = 0;
#endif


#define allow_pwd_magic_calc  ___C_CC_QQ_VERIFIED
extern int allow_pwd_magic_calc;
int32 c_allow_pwd_magic_calc;

char *c_pwd_magic_users_list;
extern char *pwd_magic_users_list;

extern int recursive_ft_usage; /* from meta.c - controls whether it check for FT indices in UNDER super tables */
int32 c_recursive_ft_usage;

extern int recursive_trigger_calls; /* from sqltrig.c - controls whether it calls triggers in UNDER super tables */
int32 c_recursive_trigger_calls;

extern long setp_top_row_limit; /* sort.c */
int32 c_setp_top_row_limit;

extern long sql_max_tree_depth;
int32 c_sql_max_tree_depth;

extern long hi_end_memcache_size; /* hash.c */
int32 c_hi_end_memcache_size;

char *c_run_as_os_uname = NULL;
int32 c_dbe_auto_sql_stats = 1;

long min_signal_handling = 0;
int32 c_min_signal_handling = 0;

char *c_xa_persistent_file = NULL;
extern char * xa_persistent_file;

int32 c_http_print_warnings_in_output = 0;
int32 c_sql_warning_mode = SQW_ON;
int32 c_sql_warnings_to_syslog = 0;
int32 c_temp_db_size = 0;
int32 c_dbev_enable = 1;

extern long sparql_result_set_max_rows;
extern long sparql_max_mem_in_use;
int32 c_sparql_result_set_max_rows = 0;
int32 c_sparql_max_mem_in_use = 0;

extern int32 enable_qp;
extern int32 dc_max_batch_sz;
extern int32 dc_batch_sz;
extern int32 enable_dyn_batch_sz;
extern int c_query_log;
extern char * c_query_log_file;
extern int64 chash_space_avail;
extern size_t c_max_large_vec;
extern int32 mon_enable;


/* for use in bif_servers */
int
virtuoso_cfg_getstring (char *section, char * key, char **pret)
{
  return cfg_getstring (pconfig, section, key, pret);
}

int
virtuoso_cfg_getlong (char *section, char * key, long *pret)
{
  int32 val;
  int ret = cfg_getlong (pconfig, section, key, &val);
  if (pret)
    *pret = (long) val;
  return ret;
}


int
virtuoso_cfg_first_string (char * section, char **pkey, char **pret)
{
  int at_section = 0;
  cfg_rewind (pconfig);
  while (!cfg_eof (pconfig))
    {
      if (!at_section)
	{
	  if (cfg_section (pconfig) && !strcmp (pconfig->section, section))
	    at_section = 1;
	}
      else
	{
	  if (cfg_section (pconfig))
	    return -1;
	  if (cfg_define (pconfig))
	    break;
	}
      if (0 != cfg_nextentry (pconfig))
	return -1;
    }
  if (cfg_eof (pconfig))
    return -1;
  if (!cfg_define (pconfig))
    return -1;

  *pkey = pconfig->id;
  *pret = pconfig->value;
  return 0;
}

int
virtuoso_cfg_next_string (char **pkey, char **pret)
{
  do
    {
      if (0 != cfg_nextentry (pconfig))
	return -1;
      if (cfg_section (pconfig) || cfg_eof (pconfig))
	return -1;
      if (cfg_define (pconfig))
	break;
    }
  while (!cfg_eof (pconfig));

  if (cfg_eof (pconfig))
    return -1;
  if (!cfg_define (pconfig))
    return -1;

  *pkey = pconfig->id;
  *pret = pconfig->value;
  return 0;
}

/*
 *  Called from main to parse the configuration file.
 *  Does some rudimentary checking and later on these
 *  variables are passed to the DBMS.
 */

LOG *startup_log = NULL;

#ifdef HAVE_SYSLOG
struct _syslog_code {
	char    *c_name;
	int     c_val;
} syslog_facilitynames[] =
{
#ifdef LOG_AUTH
	{ "AUTH",	LOG_AUTH },
#endif
#ifdef LOG_AUTHPRIV
	{ "AUTHPRIV",	LOG_AUTHPRIV },
#endif
#ifdef LOG_CRON
	{ "CRON",	LOG_CRON },
#endif
#ifdef LOG_DAEMON
	{ "DAEMON",	LOG_DAEMON },
#endif
#ifdef LOG_FTP
	{ "FTP",	LOG_FTP },
#endif
#ifdef LOG_INSTALL
	{ "INSTALL",	LOG_INSTALL },
#endif
#ifdef LOG_KERN
	{ "KERN",	LOG_KERN },
#endif
#ifdef LOG_LPR
	{ "LPR",	LOG_LPR },
#endif
#ifdef LOG_MAIL
	{ "MAIL",	LOG_MAIL },
#endif
#ifdef LOG_NETINFO
	{ "NETINFO",	LOG_NETINFO },
#endif
#ifdef LOG_NEWS
	{ "NEWS",	LOG_NEWS },
#endif
#ifdef LOG_RAS
	{ "RAS",	LOG_RAS },
#endif
#ifdef LOG_REMOTEAUTH
	{ "REMOTEAUTH",	LOG_REMOTEAUTH },
#endif
#ifdef LOG_SYSLOG
	{ "SYSLOG",	LOG_SYSLOG },
#endif
#ifdef LOG_USER
	{ "USER",	LOG_USER },
#endif
#ifdef LOG_UUCP
	{ "UUCP",	LOG_UUCP },
#endif
#ifdef LOG_LOCAL0
	{ "LOCAL0",	LOG_LOCAL0 },
#endif
#ifdef LOG_LOCAL1
	{ "LOCAL1",	LOG_LOCAL1 },
#endif
#ifdef LOG_LOCAL2
	{ "LOCAL2",	LOG_LOCAL2 },
#endif
#ifdef LOG_LOCAL3
	{ "LOCAL3",	LOG_LOCAL3 },
#endif
#ifdef LOG_LOCAL4
	{ "LOCAL4",	LOG_LOCAL4 },
#endif
#ifdef LOG_LOCAL5
	{ "LOCAL5",	LOG_LOCAL5 },
#endif
#ifdef LOG_LOCAL6
	{ "LOCAL6",	LOG_LOCAL6 },
#endif
#ifdef LOG_LOCAL7
	{ "LOCAL7",	LOG_LOCAL7 },
#endif
	{ "DEFAULT",	LOG_USER }
};
#endif


LOG *
cfg_open_syslog (int level, char *c_facility)
{
#ifdef HAVE_SYSLOG
  int facility = LOG_USER;
  int i;

  if (!c_facility) c_facility = "default";

  for (i = 0; i < sizeof (syslog_facilitynames) / sizeof (syslog_facilitynames[0]); i++)
    {
      if (!stricmp (syslog_facilitynames[i].c_name, c_facility))
	{
	  facility = syslog_facilitynames[i].c_val;
	  break;
	}
    }

      return log_open_syslog ("Virtuoso",
	  LOG_CONS | LOG_NOWAIT | LOG_PID,
      facility, level,
	L_MASK_ALL,
	f_debug ? L_STYLE_LEVEL | L_STYLE_GROUP : L_STYLE_GROUP);
#else
      return NULL;
#endif
}

int cfg_getsize (PCONFIG pc, char * sec, char * attr, size_t * sz);
int cfg2_getsize (PCONFIG pc,  char * sec, char * attr, size_t * sz);

extern LOG *virtuoso_log;
static char *prefix;
int
cfg_setup (void)
{
  char *savestr;
  char *section;
  int32 long_helper;

  if (f_config_file == NULL)
    f_config_file = "virtuoso.ini";

  f_config_file = s_strdup (setext (f_config_file, "ini", EXT_ADDIFNONE));

  if (cfg_init (&pconfig, f_config_file) == -1)
    {
      log (L_ERR, "There is no configuration file %s", f_config_file);
      return -1;
    }
#ifndef WIN32
  {
    /* Do this early, before the log file is created */
    unsigned int mask = 022;
    char *value;
    if (cfg_getstring (pconfig, "Parameters", "CreateMask", &value) == -1 || sscanf (value, "%o", &mask) == 0)
      {
	mask = 022;
      }
    /* Don't allow someone to create files we can't read ourselves */
    mask &= 077;
    umask (mask);
  }
#endif

  savestr = fnundos (s_strdup (f_config_file));
  prefix = strrchr (savestr, '/');
  if (prefix)
    prefix++;
  else
    prefix = savestr;
  setext (prefix, "", EXT_REMOVE);

  /*
   *  Parse [Database] section
   */
  section = "Database";

  /* just for check in use */
  if (cfg_getstring (pconfig, section, "DatabaseFile", &c_database_file) == -1)
    c_database_file = s_strdup (setext (prefix, "db", EXT_SET));

  if (cfg_getstring (pconfig, section, "ErrorLogFile", &c_error_log_file) == -1)
    c_error_log_file = s_strdup (setext (prefix, "log", EXT_SET));

  if (cfg_getstring (pconfig, section, "LockFile", &c_lock_file) == -1)
    c_lock_file = s_strdup (setext (c_database_file, "lck", EXT_SET));

  if (cfg_getlong (pconfig, section, "ErrorLogLevel", &c_error_log_level) == -1)
    c_error_log_level = LOG_NOTICE;

  if (cfg_getlong (pconfig, section, "Syslog", &c_syslog) == -1)
    c_syslog = 0;

  if (cfg_getstring (pconfig, section, "SyslogFacility", &c_syslog_facility) == -1)
    c_syslog_facility = "default";

  if (c_file_extend < DP_INSERT_RESERVE + 5)
    c_file_extend = DP_INSERT_RESERVE + 5;

  if (cfg_getlong (pconfig, section, "crashdump_start_dp", &long_helper) == -1)
    crashdump_start_dp = 0;
  else
    crashdump_start_dp = (dp_addr_t) long_helper;

  if (cfg_getlong (pconfig, section, "crashdump_end_dp", &long_helper) == -1)
    crashdump_end_dp = 0;
  else
    crashdump_end_dp = (dp_addr_t) long_helper;

  /* Now setup the log so that other errors go into the file as well */
  virtuoso_log = log_open_file (c_error_log_file, c_error_log_level, L_MASK_ALL,
      f_debug ? L_STYLE_LEVEL | L_STYLE_GROUP | L_STYLE_TIME : L_STYLE_GROUP | L_STYLE_TIME);
  if (startup_log)
    log_close (startup_log);
  startup_log = NULL;

  if (c_syslog)
    cfg_open_syslog (c_error_log_level, c_syslog_facility);

  if (cfg_getstring (pconfig, section, "xa_persistent_file", &c_xa_persistent_file) == -1)
    c_xa_persistent_file = s_strdup (setext (prefix, "pxa", EXT_SET));

  /*
   *  Parse [Parameters] section
   */
  section = "Parameters";

  if (cfg_getstring (pconfig, section, "ServerPort", &c_serverport) == -1)
    c_serverport = "1111";

  if (cfg_getlong (pconfig, section, "DisableUnixSocket", &c_disable_listen_on_unix_sock) == -1)
    c_disable_listen_on_unix_sock = 0;

  if (cfg_getlong (pconfig, section, "DisableTcpSocket", &c_disable_listen_on_tcp_sock) == -1)
    c_disable_listen_on_tcp_sock = 0;

#ifdef _SSL
  if (cfg_getstring (pconfig, section, "SSLServerPort", &c_ssl_server_port) == -1)
    c_ssl_server_port = NULL;

  if (cfg_getstring (pconfig, section, "SSLCertificate", &c_ssl_server_cert) == -1)
    if (cfg_getstring (pconfig, section, "SSLPublicKey", &c_ssl_server_cert) == -1)
      c_ssl_server_cert = NULL;

  if (cfg_getstring (pconfig, section, "SSLPrivateKey", &c_ssl_server_key) == -1)
    c_ssl_server_key = NULL;

  if (cfg_getstring (pconfig, section, "SSLExtraChainCertificate", &c_ssl_server_extra_certs) == -1)
    c_ssl_server_extra_certs = NULL;

  if (cfg_getlong (pconfig, section, "X509ClientVerify", &ssl_server_verify) == -1)
    ssl_server_verify = 0;

  if (cfg_getlong (pconfig, section, "X509ClientVerifyDepth", &ssl_server_verify_depth) == -1)
    ssl_server_verify_depth = 0;

  if (cfg_getstring (pconfig, section, "X509ClientVerifyCAFile", &ssl_server_verify_file) == -1)
    ssl_server_verify_file = NULL;
#endif

  if (cfg_getlong (pconfig, section, "ServerThreads", &c_server_threads) == -1)
    if (cfg_getlong (pconfig, section, "MaxClientConnections", &c_server_threads) == -1)
      c_server_threads = 10;

  if (cfg_getlong (pconfig, section, "CheckpointInterval", &c_checkpoint_interval) == -1)
    c_checkpoint_interval = 0;

  if (cfg_getlong (pconfig, section, "NumberOfBuffers", &c_number_of_buffers) == -1)
    c_number_of_buffers = 2000;
  if (c_number_of_buffers < 20000)
    c_number_of_buffers = 20000;

  if (cfg_getlong (pconfig, section, "LockInMem", &c_lock_in_mem) == -1)
    c_lock_in_mem = 0;

  if (cfg_getlong (pconfig, section, "MaxDirtyBuffers", &c_max_dirty_buffers) == -1)
    c_max_dirty_buffers = 0;

  if (cfg_getlong (pconfig, section, "UnremapQuota", &c_unremap_quota) == -1)
    c_unremap_quota = 0;

#if 0 /*GK: obosolete */
  if (cfg_getlong (pconfig, section, "AtomicDive", &c_atomic_dive) == -1)
    c_atomic_dive = 1;
#endif

  if (cfg_getlong (pconfig, section, "CaseMode", &c_case_mode) == -1)
    c_case_mode = 1;

  if (cfg_getlong (pconfig, section, "UseDaylightSaving", &c_isdts) == -1)
    c_isdts = 1;

  if (cfg_getlong (pconfig, section, "NullUnspecifiedParams", &c_null_unspecified_params) == -1)
    c_null_unspecified_params = 0;

  if (cfg_getlong (pconfig, section, "MaxStaticCursorRows", &c_max_static_cursor_rows) == -1)
    c_max_static_cursor_rows = 5000;
  max_static_cursor_rows = c_max_static_cursor_rows;

  if (cfg_getlong (pconfig, section, "PrefixResultNames", &c_prefix_resultnames) == -1)
    c_prefix_resultnames = 1;

  if (cfg_getlong (pconfig, section, "DisableMtWrite", &c_disable_mt_write) == -1)
    c_disable_mt_write = 0;

  if (cfg_getlong (pconfig, section, "MinAutoCheckpointSize", &c_min_checkpoint_size) == -1)
    {
      c_min_checkpoint_size = MIN_CHECKPOINT_SIZE;
      c_min_checkpoint_size = c_min_checkpoint_size * 1024;
    }
  min_checkpoint_size = c_min_checkpoint_size;

  if (cfg_getlong (pconfig, section, "AutoCheckpointLogSize", &c_autocheckpoint_log_size) == -1)
    c_autocheckpoint_log_size = 0;
  autocheckpoint_log_size = c_autocheckpoint_log_size;
  if (autocheckpoint_log_size > 0 && autocheckpoint_log_size < min_checkpoint_size)
    autocheckpoint_log_size = min_checkpoint_size + 1024;

  if (cfg_getlong (pconfig, section, "CheckpointAuditTrail", &c_log_audit_trail) == -1)
    c_log_audit_trail = 0;

  if (cfg_getlong (pconfig, section, "CheckpointSyncMode", &c_checkpoint_sync) == -1)
    c_checkpoint_sync = 2;
  if (c_checkpoint_sync < 0 || c_checkpoint_sync > 2)
    c_checkpoint_sync = 2;

  if (cfg_getlong (pconfig, section, "AllowOSCalls", &do_os_calls) == -1)
    do_os_calls = 0;

  if (cfg_getlong (pconfig, section, "SchedulerInterval", &c_scheduler_period) == -1)
    {
      if (cfg_getlong (pconfig, section, "Scheduler interval", &c_scheduler_period) == -1)
	c_scheduler_period = 0;
    }

  if (cfg_getstring (pconfig, section, "TraceOn", &c_init_trace) == -1)
    c_init_trace = 0;

  if (cfg_getlong (pconfig, section, "TraceLogFileLine", &c_log_file_line) == -1)
#ifdef WIN32
    c_log_file_line = 1;
#else
    c_log_file_line = 0;
#endif

  if (cfg_getstring (pconfig, section, "DirsAllowed", &c_allowed_dirs) == -1)
    c_allowed_dirs = 0;

  if (cfg_getstring (pconfig, section, "DirsDenied", &c_denied_dirs) == -1)
    c_denied_dirs = 0;

  if (cfg_getstring (pconfig, section, "BackupDirs", &c_backup_dirs) == -1)
    c_backup_dirs = 0;

  if (cfg_getstring (pconfig, section, "SafeExecutables", &c_safe_execs) == -1)
    c_safe_execs = 0;

  if (cfg_getstring (pconfig, section, "DbaExecutables", &c_dba_execs) == -1)
    c_dba_execs = 0;

  if (cfg_getstring (pconfig, section, "TempDir", &c_temp_dir) == -1)
    c_temp_dir = 0;

  if (cfg_getstring (pconfig, section, "TempSesDir", &c_temp_ses_dir) == -1)
    c_temp_ses_dir = 0;

  if (cfg_getstring (pconfig, section, "DefaultDataLanguage", &c_server_default_language_name) == -1)
    c_server_default_language_name = 0;

  if (cfg_getlong (pconfig, section, "ServerThreadSize", &c_server_thread_sz) == -1)
    c_server_thread_sz = 60000;
  if (c_server_thread_sz < 60000)
    c_server_thread_sz = 60000;

  if (cfg_getlong (pconfig, section, "MainThreadSize", &c_main_thread_sz) == -1)
    c_main_thread_sz = 140000;	/* was 100000 */
  if (c_main_thread_sz < 140000)	/* was 100000 */
    c_main_thread_sz = 140000;	/* was 100000 */

  if (cfg_getlong (pconfig, section, "FutureThreadSize", &c_future_thread_sz) == -1)
    c_future_thread_sz = 140000;
  if (c_future_thread_sz < 140000)
    c_future_thread_sz = 140000;

  if (cfg_getlong (pconfig, section, "ThreadCleanupInterval", &long_helper) == -1)
    c_cfg_thread_live_period = 0;
  else
    c_cfg_thread_live_period = (unsigned long) long_helper;

  if (cfg_getlong (pconfig, section, "ThreadThreshold", &long_helper) == -1)
    c_cfg_thread_threshold = 10;
  else
    c_cfg_thread_threshold = (unsigned long) long_helper;

  if (cfg_getlong (pconfig, section, "ResourcesCleanupInterval", &long_helper) == -1)
    c_cfg_resources_clear_interval = 0;
  else
    c_cfg_resources_clear_interval = (unsigned long) long_helper;

  if (cfg_getstring (pconfig, section, "Collation", &c_default_collation_name) == -1)
    c_default_collation_name = NULL;
  if (cfg_getstring (pconfig, section, "Charset", &c_default_charset_name) == -1)
    c_default_charset_name = NULL;
  else
    {
      int i, len = (int) strlen (c_default_charset_name);

      for (i = 0; i < len; i++)
	c_default_charset_name[i] = toupper (c_default_charset_name[i]);
    }

  if (cfg_getlong (pconfig, section, "FreeTextBatchSize", &c_vt_batch_size_limit) == -1)
    c_vt_batch_size_limit = 10000000;

  if (cfg_getlong (pconfig, section, "CallstackOnException", &c_callstack_on_exception) == -1)
    c_callstack_on_exception = 0;

  if (cfg_getlong (pconfig, section, "PLDebug", &c_pl_debug_all) == -1)
    c_pl_debug_all = 0;

  if (cfg_getlong (pconfig, section, "MacSpotlight", &long_helper) == -1)
    c_spotlight_integration = 0;
  else
    c_spotlight_integration = (long) long_helper;

  if (cfg_getstring (pconfig, section, "TestCoverage", &c_pl_debug_cov_file) == -1)
    c_pl_debug_cov_file = NULL;

  /*if (cfg_getlong (pconfig, section, "SQLOptimizer", &c_sqlo_enable) == -1) */
/*    c_sqlo_enable = 1;*/

  if (cfg_getlong (pconfig, section, "SQLOptimizeConstantConditions", &sql_const_cond_opt) == -1)
    sql_const_cond_opt = 1;

  if (cfg_getlong (pconfig, section, "AddViewColRefsQualifier", &c_sqlc_add_views_qualifiers) == -1)
    c_sqlc_add_views_qualifiers = 0;

  if (cfg_getlong (pconfig, section, "AllowPasswordEncryption", &c_allow_pwd_magic_calc) == -1)
    c_allow_pwd_magic_calc = 1;

  if (cfg_getstring (pconfig, section, "DecryptionAccess", &c_pwd_magic_users_list) == -1)
    c_pwd_magic_users_list = NULL;

  if (cfg_getlong (pconfig, section, "TransactionAfterImageLimit", &c_txn_after_image_limit) == -1)
    c_txn_after_image_limit = 50000000;
  if (c_txn_after_image_limit != 0 && c_txn_after_image_limit < 10000)
    c_txn_after_image_limit = 10000;

  if (cfg_getlong (pconfig, section, "FDsPerFile", &c_n_fds_per_file) == -1)
    c_n_fds_per_file = 1;
  if (c_n_fds_per_file < 1)
    c_n_fds_per_file = 1;

  if (cfg_getlong (pconfig, section, "MaxOptimizeLayouts", &c_sqlo_max_layouts) == -1)
    c_sqlo_max_layouts = 1000;

  if (cfg_getlong (pconfig, section, "StopCompilerWhenXOverRunTime", &sqlo_compiler_exceeds_run_factor) == -1)
    sqlo_compiler_exceeds_run_factor = 0;

  if (cfg_getlong (pconfig, section, "MaxMemPoolSize", &sqlo_max_mp_size) == -1)
    sqlo_max_mp_size = 200000000;

#ifdef POINTER_64
  if (sqlo_max_mp_size >= 0x40000000)
    sqlo_max_mp_size = INT32_MAX;
  else
    sqlo_max_mp_size *= 2;
#endif

  if (sqlo_max_mp_size != 0 && sqlo_max_mp_size < 5000000)
    sqlo_max_mp_size = 5000000;

  if (cfg_getlong (pconfig, section, "SkipStartupCompilation", &c_sql_proc_use_recompile) == -1)
    c_sql_proc_use_recompile = 1;

  if (cfg_getlong (pconfig, section, "TempAllocationPct", &c_temp_allocation_pct) == -1)
    c_temp_allocation_pct = 30;
  if (c_temp_allocation_pct < 0)
    c_temp_allocation_pct = 0;

  if (cfg_getstring (pconfig, section, "JavaClasspath", &c_java_classpath) == -1)
    c_java_classpath = 0;

  if (cfg_getlong (pconfig, section, "DefaultIsolation", &c_default_txn_isolation) == -1)
    {
      c_default_txn_isolation = ISO_COMMITTED;
    }
  if (c_default_txn_isolation != ISO_UNCOMMITTED &&
      c_default_txn_isolation != ISO_COMMITTED &&
      c_default_txn_isolation != ISO_REPEATABLE &&
      c_default_txn_isolation != ISO_SERIALIZABLE)
    c_default_txn_isolation = ISO_REPEATABLE;

  if (cfg_getlong (pconfig, section, "ColumnStore", &c_col_by_default) == -1)
    c_col_by_default = 0;

  if (0 != cfg_getsize (pconfig, section, "MaxQueryMem", &c_max_large_vec))
    c_max_large_vec = 0;

  if (0 != cfg_getsize (pconfig, section, "HashJoinSpace", &chash_space_avail))
    chash_space_avail = MAX (1000000000, main_bufs * 1000);

  if (cfg_getlong (pconfig, section, "UseAIO", &c_c_use_aio) == -1)
    c_c_use_aio = 0;

  if (cfg_getlong (pconfig, section, "AsyncQueueMaxThreads", &c_aq_max_threads) == -1)
    c_aq_max_threads = 10;

  if (cfg_getlong (pconfig, section, "BuffersAllocation", &malloc_bufs) == -1)
    malloc_bufs = 0;

  if (cfg_getlong (pconfig, section, "SwapGuard", &swap_guard_on) == -1)
    swap_guard_on = 0;

  /*  ExtentReadThreshold, ExtentReadWindow, ExtentReadStartupThreshold, ExtentReadStartupWindow */
  if (cfg_getlong (pconfig, section, "ExtentReadThreshold", &em_ra_threshold) == -1)
    em_ra_threshold = 2;
  if (cfg_getlong (pconfig, section, "ExtentReadWindow", &em_ra_window) == -1)
    em_ra_window = 1000;
  if (cfg_getlong (pconfig, section, "ExtentReadStartupThreshold", &em_ra_startup_threshold) == -1)
    em_ra_startup_threshold = 0;
  if (cfg_getlong (pconfig, section, "ExtentReadStartupWindow", &em_ra_startup_window) == -1)
    em_ra_startup_window = 40000;

  if (cfg_getlong (pconfig, section, "LogProcOverwrite", &log_proc_overwrite) == -1)
    log_proc_overwrite = 1;

  if (cfg_getlong (pconfig, section, "PageCompress", (int32 *) &c_compress_mode) == -1)
    c_compress_mode = 0;


  {
    int nbdirs;
    dk_set_t bd = NULL;

    old_backup_dirs = NULL;
    for (nbdirs = 1;; nbdirs++)
      {
	struct stat s;

	char keyname[32];
	char *c_backup_dir;

	sprintf (keyname, "BackupDir%d", nbdirs);
	if (cfg_getstring (pconfig, section, keyname, &c_backup_dir) != 0)
	  break;

	/* sanity checks */
	if (stat (c_backup_dir, &s) < 0)
	  {
	    log_warning ("BackupDir: %s: %s -- ignored", c_backup_dir, strerror (errno));
	    continue;
	  }
	if (!S_ISDIR (s.st_mode))
	  {
	    log_warning ("BackupDir: %s: Not a directory -- ignored", c_backup_dir);
	    continue;
	  }
	/* append */
#if 0
	log_debug ("BackupDir: '%s' added", c_backup_dir);
#endif
	old_backup_dirs = dk_set_conc (old_backup_dirs, dk_set_cons ((caddr_t) c_backup_dir, NULL));
      }

    /*
     * add default element if the set is empty
     * and make this set circular
     */
    if ((bd = dk_set_last (old_backup_dirs)) == NULL)
      {
#if 0
	log_debug ("BackupDir: '.' added (default)");
#endif
	bd = old_backup_dirs = dk_set_cons ((caddr_t) ".", NULL);
      }
    bd->next = old_backup_dirs;

    /* dump */
    bd = old_backup_dirs;
    do
      {
#if 0
	log_debug ("backup directory: [%s]", bd->data);
#endif
	bd = bd->next;
      }
    while (bd != old_backup_dirs);
  }

#ifndef WIN95COMPAT
#ifdef WIN32
  if (cfg_getlong (pconfig, section, "SingleCPU", &c_single_processor) == -1)
    c_single_processor = 0;
  if (c_single_processor)
    {
      if (!SetProcessAffinityMask (GetCurrentProcess (), 1))
	{
	  LPVOID lpMsgBuf;
	  FormatMessage (
	      FORMAT_MESSAGE_ALLOCATE_BUFFER |
	      FORMAT_MESSAGE_FROM_SYSTEM |
	      FORMAT_MESSAGE_IGNORE_INSERTS,
	      NULL,
	      GetLastError (),
	      MAKELANGID (LANG_NEUTRAL, SUBLANG_DEFAULT),
	      (LPTSTR) & lpMsgBuf,
	      0,
	      NULL);
	  log_error ("Error setting single CPU mode :%s", (char *) lpMsgBuf);
	  LocalFree (lpMsgBuf);
	}
      else
	log_info ("Running in single CPU mode");
    }
#endif
#endif

  if (cfg_getlong (pconfig, section, "RecursiveFreeTextUsage", &c_recursive_ft_usage) == -1)
    c_recursive_ft_usage = 1;

  if (cfg_getlong (pconfig, section, "RecursiveTriggerCalls", &c_recursive_trigger_calls) == -1)
    c_recursive_trigger_calls = 1;

  if (cfg_getlong (pconfig, section, "MaxSortedTopRows", &c_setp_top_row_limit) == -1)
    c_setp_top_row_limit = 10000;

  if (cfg_getlong (pconfig, section, "MaxSqlExpressionDepth", &c_sql_max_tree_depth) == -1)
    c_sql_max_tree_depth = 1000;

  if (cfg_getlong (pconfig, section, "MaxDistinctTempMemCacheRows", &c_hi_end_memcache_size) == -1)
    c_hi_end_memcache_size = 100000;

  if (cfg_getstring (pconfig, section, "RunAs", &c_run_as_os_uname) == -1)
    c_run_as_os_uname = NULL;

  if (cfg_getlong (pconfig, section, "AutoSqlStats", &c_dbe_auto_sql_stats) == -1)
    c_dbe_auto_sql_stats = 0;

#ifndef WIN32
  if (cfg_getlong (pconfig, section, "MinSignalHandling", &c_min_signal_handling) == -1)
    c_min_signal_handling = 0;
  min_signal_handling = c_min_signal_handling;	/* must be here because of init order */
#endif

  if (cfg_getlong (pconfig, section, "SqlWarningMode", &c_sql_warning_mode) == -1)
    c_sql_warning_mode = SQW_ON;
  if (c_sql_warning_mode != SQW_ON && c_sql_warning_mode != SQW_OFF && c_sql_warning_mode != SQW_ERROR)
    c_sql_warning_mode = SQW_ON;

  if (cfg_getlong (pconfig, section, "SqlWarningsToSyslog", &c_sql_warnings_to_syslog) == -1)
    c_sql_warnings_to_syslog = 0;
  if (c_sql_warnings_to_syslog < 0 || c_sql_warnings_to_syslog > 1)
    c_sql_warnings_to_syslog = 0;

  if (cfg_getlong (pconfig, section, "TempDBSize", &c_temp_db_size) == -1)
    c_temp_db_size = 10;	/* in MB */
  if (c_temp_db_size < 0)
    c_temp_db_size = 10;

  if (cfg_getlong (pconfig, section, "DbevEnable", &c_dbev_enable) == -1)
    c_dbev_enable = 1;

  if (cfg_getlong (pconfig, section, "IriCacheSize", &c_iri_cache_size) == -1)
    c_iri_cache_size = 0;

  if (cfg_getlong (pconfig, section, "IRIRangeSize", &iri_range_size) == -1)
    iri_range_size = 11 * 256 * 709;	/* far enough so as not to fall in same row wise leaf page and not a multiple of common slice count  so consecutive usually come on different host */

  if (cfg_getlong (pconfig, section, "LiteMode", &c_lite_mode) == -1)
    c_lite_mode = 0;

  if (cfg_getlong (pconfig, section, "RdfFreeTextRulesSize", &c_rdf_obj_ft_rules_size) == -1)
    c_rdf_obj_ft_rules_size = 0;

  if (cfg_getlong (pconfig, section, "RdfInferenceSampleCacheSize", &ric_samples_sz) == -1)
    ric_samples_sz = 1000;

  if (cfg_getlong (pconfig, section, "IndexTreeMaps", &c_it_n_maps) == -1)
    c_it_n_maps = 0;

  if (cfg_getlong (pconfig, section, "DensePageAllocation", &c_dense_page_allocation) == -1)
    c_dense_page_allocation = 0;

  if (cfg_getlong (pconfig, section, "PageMapCheck", &dbs_cache_check_enable) == -1)
    dbs_cache_check_enable = 0;

  if (cfg_getlong (pconfig, section, "MaxOpenClientStatements", &cli_max_cached_stmts) == -1)
    cli_max_cached_stmts = 10000;

  if (cfg_getstring (pconfig, section, "QueryLog", &c_query_log_file) == -1)
    c_query_log = 0;
  else
    c_query_log = 1;

  if (cfg_getlong (pconfig, section, "ThreadsPerQuery", &enable_qp) == -1)
    {
      enable_qp = 8;
    }

  if (cfg_getlong (pconfig, section, "MaxVectorSize", &dc_max_batch_sz) == -1)
    dc_max_batch_sz = 1000000;
  if (dc_max_batch_sz > (1024 * 1024 * 4) - 16)
    dc_max_batch_sz = (1024 * 1024 * 4) - 16;

  if (cfg_getlong (pconfig, section, "VectorSize", &dc_batch_sz) == -1)
    dc_batch_sz = 10000;

  if (cfg_getlong (pconfig, section, "AdjustVectorSize", &enable_dyn_batch_sz) == -1)
    enable_dyn_batch_sz = 1;


  /*
   *  Parse [HTTPServer] section
   */
  section = "HTTPServer";

  if (cfg_getstring (pconfig, section, "ServerPort", &c_http_port) == -1)
    c_http_port = NULL;

  if (cfg_getstring (pconfig, section, "HTTPLogFile", &http_log_file) == -1)
    http_log_file = NULL;

  if (cfg_getstring (pconfig, section, "ServerRoot", &www_root) == -1)
    www_root = ".";

  if (cfg_getstring (pconfig, section, "ServerIdString", &http_server_id_string) == -1)
    http_server_id_string = NULL;

  if (http_server_id_string && strlen (http_server_id_string) > 32)
    http_server_id_string = "Virtuoso";

  if (cfg_getstring (pconfig, section, "ClientIdString", &http_client_id_string) == -1)
    http_client_id_string = "Mozilla/4.0 (compatible; Virtuoso)";

  if (strlen (http_client_id_string) > 64)
    http_client_id_string = "Mozilla/4.0 (compatible; Virtuoso)";

  if (cfg_getstring (pconfig, section, "SOAPClientIdString", &http_soap_client_id_string) == -1)
    http_soap_client_id_string = "OpenLink Virtuoso SOAP";

  if (strlen (http_soap_client_id_string) > 64)
    http_soap_client_id_string = "OpenLink Virtuoso SOAP";

  if (cfg_getstring (pconfig, section, "DavRoot", &c_dav_root) == -1)
    c_dav_root = NULL;

  if (cfg_getlong (pconfig, section, "EnabledDavVSP", &long_helper) == -1)
    c_vsp_in_dav_enabled = 0;
  else
    c_vsp_in_dav_enabled = (long) long_helper;

  if (cfg_getlong (pconfig, section, "HTTPProxyEnabled", &long_helper) == -1)
    c_http_proxy_enabled = 0;
  else
    c_http_proxy_enabled = (long) long_helper;

  if (cfg_getlong (pconfig, section, "EnabledGzipContent", &long_helper) == -1)
    c_gzip_enabled = 0;
  else
    c_gzip_enabled = (long) long_helper;

  if (cfg_getlong (pconfig, section, "HttpSessionSize", &long_helper) == -1)
    c_http_ses_size = 10 * 1024 * 1024;
  else
    c_http_ses_size = (long) long_helper;

  if (cfg_getstring (pconfig, section, "TempASPXDir", &c_temp_aspx_dir) == -1)
    c_temp_aspx_dir = 0;

  if (cfg_getstring (pconfig, section, "DefaultMailServer", &c_default_mail_server) == -1)
    c_default_mail_server = NULL;

  if (cfg_getstring (pconfig, section, "Charset", &c_ws_default_charset_name) == -1)
    c_ws_default_charset_name = NULL;
  else
    {
      int i, len = (int) strlen (c_ws_default_charset_name);

      for (i = 0; i < len; i++)
	c_ws_default_charset_name[i] = toupper (c_ws_default_charset_name[i]);
    }

#ifdef _IMSG
  if (cfg_getlong (pconfig, section, "POP3ServerPort", &c_pop3_port) == -1)
    if (cfg_getlong (pconfig, section, "POP3Port", &c_pop3_port) == -1)
      c_pop3_port = 0;

  if (cfg_getlong (pconfig, section, "NewsServerPort", &c_nntp_port) == -1)
    c_nntp_port = 0;

  if (cfg_getlong (pconfig, section, "FTPServerPort", &c_ftp_port) == -1)
    c_ftp_port = 0;

  if (cfg_getlong (pconfig, section, "FTPServerTimeout", &c_ftp_server_timeout) == -1)
    c_ftp_server_timeout = 600;
#endif
  if (cfg_getlong (pconfig, section, "EnableMonitor", &mon_enable) == -1)
    mon_enable = 1;

#ifdef _SSL
  if (cfg_getstring (pconfig, section, "SSLPort", &c_https_port) == -1)
    c_https_port = NULL;

  if (cfg_getstring (pconfig, section, "SSLCertificate", &c_https_cert) == -1)
    if (cfg_getstring (pconfig, section, "SSLPublicKey", &c_https_cert) == -1)
      c_https_cert = NULL;

  if (cfg_getstring (pconfig, section, "SSLExtraChainCertificate", &https_extra) == -1)
    https_extra = NULL;

  if (cfg_getstring (pconfig, section, "SSLPrivateKey", &c_https_key) == -1)
    c_https_key = NULL;

  if (cfg_getlong (pconfig, section, "X509ClientVerify", &c_https_client_verify) == -1)
    c_https_client_verify = 0;

  if (cfg_getlong (pconfig, section, "X509ClientVerifyDepth", &c_https_client_verify_depth) == -1)
    c_https_client_verify_depth = 0;

  if (cfg_getstring (pconfig, section, "X509ClientVerifyCAFile", &c_https_client_verify_file) == -1)
    c_https_client_verify_file = NULL;
#endif

  if (cfg_getlong (pconfig, section, "ServerThreads", &c_http_threads) == -1)
    if (cfg_getlong (pconfig, section, "MaxClientConnections", &c_http_threads) == -1)
      c_http_threads = 0;

  if (c_http_threads < 1 && c_http_port)
    c_http_threads = 1;

  if (cfg_getlong (pconfig, section, "MaxRestrictedThreads", &http_limited) == -1)
    http_limited = c_http_threads;

  if (cfg_getlong (pconfig, section, "MaxKeepAlives", &c_http_max_keep_alives) == -1)
    c_http_max_keep_alives = 10;

  if (cfg_getlong (pconfig, section, "KeepAliveTimeout", &c_http_keep_alive_timeout) == -1)
    c_http_keep_alive_timeout = 10;

  if (cfg_getlong (pconfig, section, "MaxCachedProxyConnections", &c_http_max_cached_proxy_connections) == -1)
    c_http_max_cached_proxy_connections = 0;

  if (cfg_getlong (pconfig, section, "ProxyConnectionCacheTimeout", &c_http_proxy_connection_cache_timeout) == -1)
    c_http_proxy_connection_cache_timeout = 0;

  if (cfg_getlong (pconfig, section, "HTTPThreadSize", &c_http_thread_sz) == -1)
    c_http_thread_sz = 280000;
  if (c_http_thread_sz < 280000)
    c_http_thread_sz = 280000;
  if (c_http_thread_sz < c_future_thread_sz)
    c_http_thread_sz = c_future_thread_sz;
  if (c_http_thread_sz > c_future_thread_sz)
    c_future_thread_sz = c_http_thread_sz;

  if (cfg_getlong (pconfig, section, "PersistentHostingModules", &c_http_keep_hosting) == -1)
    c_http_keep_hosting = 0;

  if (cfg_getlong (pconfig, section, "EnableRequestTrap", &c_http_ses_trap) == -1)
    c_http_ses_trap = 0;

  if (cfg_getlong (pconfig, section, "HttpPrintWarningsInOutput", &c_http_print_warnings_in_output) == -1)
    c_http_print_warnings_in_output = 0;
  if (c_http_print_warnings_in_output < 0 || c_http_print_warnings_in_output > 1)
    c_http_print_warnings_in_output = 0;

  if (cfg_getstring (pconfig, section, "MaintenancePage", &www_maintenance_page) == -1)
    www_maintenance_page = NULL;

  if (cfg_getstring (pconfig, section, "GatewayIpAddress", &http_proxy_address) == -1)
    http_proxy_address = NULL;

  if (cfg_getlong (pconfig, section, "RDFContentNegotiation", &c_http_check_rdf_accept) == -1)
    c_http_check_rdf_accept = 1;

  if (cfg_getstring (pconfig, section, "HTTPProxyServer", &http_cli_proxy_server) == -1)
    http_cli_proxy_server = NULL;

  if (cfg_getstring (pconfig, section, "HTTPProxyExceptions", &http_cli_proxy_except) == -1)
    http_cli_proxy_except = NULL;

  if (cfg_getlong (pconfig, section, "HTTPClientCache", &http_enable_client_cache) == -1)
    http_enable_client_cache = 0;
  /*
   * FIXME: set meaningful default for c_http_proxy_connection_cache_timeout
   * if c_http_max_cached_proxy_connections is set to something whenever
   * this feature gets implemented...
   */


  /*
   *  Parse [AutoRepair] section
   */
  section = "AutoRepair";

  if (cfg_getlong (pconfig, section, "BadParentLinks", &c_bad_parent_links) == -1)
    c_bad_parent_links = 0;

  if (cfg_getlong (pconfig, section, "DuplicateCheckpointRemaps", &cpt_remap_recovery) == -1)
    cpt_remap_recovery = 0;

  if (cfg_getlong (pconfig, section, "CheckExtentFreePages", &dbs_check_extent_free_pages) == -1)
    dbs_check_extent_free_pages = 1;


#if 0				/*obsoleted */
  if (cfg_getlong (pconfig, section, "BadDTP", &c_bad_dtp) == -1)
    c_bad_dtp = 0;
#endif


  /*
   *  Parse [Client] section
   */
  section = "Client";

  if (cfg_getlong (pconfig, section, "SQL_PREFETCH_ROWS", &cli_prefetch) == -1)
    cli_prefetch = 2000;

  if (cfg_getlong (pconfig, section, "SQL_PREFETCH_BYTES", &cli_prefetch_bytes) == -1)
    cli_prefetch_bytes = 0;

  if (cfg_getlong (pconfig, section, "SQL_QUERY_TIMEOUT", &cli_query_timeout) == -1)
    cli_query_timeout = 0;

  if (cfg_getlong (pconfig, section, "SQL_TXN_TIMEOUT", &cli_txn_timeout) == -1)
    cli_txn_timeout = 0;

  if (cfg_getlong (pconfig, section, "SQL_NO_CHAR_C_ESCAPE", &cli_not_c_char_escape) == -1)
    cli_not_c_char_escape = 0;

  if (cfg_getlong (pconfig, section, "SQL_UTF8_EXECS", &cli_utf8_execs) == -1)
    cli_utf8_execs = 0;

  if (cfg_getlong (pconfig, section, "SQL_NO_SYSTEM_TABLES", &cli_no_system_tables) == -1)
    cli_no_system_tables = 0;

  if (cfg_getlong (pconfig, section, "SQL_BINARY_TIMESTAMP", &cli_binary_timestamp) == -1)
    cli_binary_timestamp = 1;

  if (cfg_getlong (pconfig, section, "SQL_ENCRYPTION_ON_PASSWORD", &c_cli_encryption_on_password) == -1)
    c_cli_encryption_on_password = -1;
  else
    {
      switch (c_cli_encryption_on_password)
	{
	case 1:
	  c_cli_encryption_on_password = 2;
	  break;
	case 0:
	  c_cli_encryption_on_password = 1;
	  break;
	default:
	  c_cli_encryption_on_password = 0;
	}
    }

#ifdef _RENDEZVOUS
  /*
   *  Parse [Zero Config] section
   */
  section = "Zero Config";

  if (cfg_find (pconfig, section, "ServerName") == 0)
    {
      NEW_VARZ (zeroconfig_t, zc);
      zc->zc_name = box_string (pconfig->value);
      zc->zc_dsn = box_string (cfg_find (pconfig, section, "ServerDSN") == 0 ? pconfig->value : "");
      zc->zc_port = atoi (c_serverport);
      dk_set_push (&zeroconfig_entries, zc);
    }
#ifdef _SSL
  if (c_ssl_server_port && cfg_find (pconfig, section, "SSLServerName") == 0)
    {
      NEW_VARZ (zeroconfig_t, zc);
      zc->zc_name = box_string (pconfig->value);
      zc->zc_dsn = box_string (cfg_find (pconfig, section, "SSLServerDSN") == 0 ? pconfig->value : "");
      zc->zc_port = atoi (c_ssl_server_port);
      zc->zc_ssl = 1;
      dk_set_push (&zeroconfig_entries, zc);
    }
#endif

#endif

  /*
   *  Parse [URIQA] section
   */
  section = "URIQA";

  if (cfg_getlong (pconfig, section, "DynamicLocal", &c_uriqa_dynamic_local) == -1)
    c_uriqa_dynamic_local = 0;


  /*
   *  Parse [SPARQL] section
   */
  section = "SPARQL";

  if (cfg_getlong (pconfig, section, "ResultSetMaxRows", &c_sparql_result_set_max_rows) == -1)
    c_sparql_result_set_max_rows = 0;

  if (cfg_getlong (pconfig, section, "MaxMemInUse", &c_sparql_max_mem_in_use) == -1)
    c_sparql_max_mem_in_use = 0;

  if (cfg_getlong (pconfig, section, "TransitivityCacheEnabled", &tn_cache_enable) == -1)
    tn_cache_enable = 0;

  if (cfg_getlong (pconfig, section, "ShortenLongURIs", &rdf_shorten_long_iri) == -1)
    rdf_shorten_long_iri = 1;

  if (cfg_getlong (pconfig, section, "EnablePstats", &enable_p_stat) == -1)
    enable_p_stat = 2;

  /* Initialize OpenSSL engines */
  ssl_engine_startup ();
#if 0
  if (cfg_find (pconfig, "SSLEngines", NULL) == 0)
    {
      while (cfg_nextentry (pconfig) == 0)
	{
	  if (cfg_section (pconfig))
	    break;
	  if (cfg_define (pconfig) && !cfg_continue (pconfig))
	    {
	      if (ssl_engine_configure (pconfig->value) == -1)
		{
		  log_error ("Failed to configure an OpenSSL engine with parameters '%s'", pconfig->value);
		}
	    }
	}
    }
#endif

  /* Now open the HTTP log */
  if (http_log_file)
    {
      char *new_name;
      time_t now;
      struct tm *tm;
      time (&now);
      tm = localtime (&now);
      strncpy (http_log_name, http_log_file, PATH_MAX - 10);
      new_name = http_log_file_check (tm);
      http_log = fopen (new_name ? new_name : http_log_file, "a");
      if (!http_log)
	log_error ("Can't open HTTP log file (%s)", http_log_file);
    }

  srv_client_defaults_init ();

  /*
   *  VDB related parameters
   */
  if (cfg_getlong (pconfig, "VDB", "ArrayOptimization", &c_use_array_params) == -1)
    c_use_array_params = 0;

  if (cfg_getlong (pconfig, "VDB", "NumArrayParameters", &c_num_array_params) == -1)
    c_num_array_params = 10;

  if (cfg_getlong (pconfig, "VDB", "VDBDisconnectTimeout", &c_rds_disconnect_timeout) == -1)
    c_rds_disconnect_timeout = 1000;

  if (cfg_getlong (pconfig, "VDB", "VDBOracleCatalogFix", &c_vdb_oracle_catalog_fix) == -1)
    c_vdb_oracle_catalog_fix = 0;

  if (cfg_getlong (pconfig, "VDB", "AttachInAutoCommit", &c_vdb_attach_autocommit) == -1)
    c_vdb_attach_autocommit = 0;

  if (cfg_getlong (pconfig, "VDB", "ReconnectOnFailure", &c_vdb_reconnect_on_vdb_error) == -1)
    c_vdb_reconnect_on_vdb_error = 1;

  if (cfg_getlong (pconfig, "VDB", "KeepConnectionOnFixedThread", &c_vdb_client_fixed_thread) == -1)
    c_vdb_client_fixed_thread = 1;

  if (cfg_getlong (pconfig, "VDB", "PrpcBurstTimeoutMsecs", &c_prpc_burst_timeout_msecs) == -1)
    prpc_burst_timeout_msecs = 100;

  if (cfg_getlong (pconfig, "VDB", "SerializeConnect", &c_vdb_serialize_connect) == -1)
    c_vdb_serialize_connect = 1;

  if (cfg_getlong (pconfig, "VDB", "DisableStmtCache", &c_vdb_no_stmt_cache) == -1)
    c_vdb_no_stmt_cache = 0;

  if (cfg_getstring (pconfig, "VDB", "SQLStateMap", &c_vdb_odbc_error_file) == -1)
    c_vdb_odbc_error_file = NULL;

  if (cfg_getlong (pconfig, "VDB", "SkipDMLPrimaryKey", &c_skip_dml_primary_key) == -1)
    c_skip_dml_primary_key = 0;

  if (cfg_getlong (pconfig, "VDB", "RemotePKNotUnique", &c_remote_pk_not_unique) == -1)
    c_remote_pk_not_unique = 0;

  if (cfg_getlong (pconfig, "VDB", "UseGlobalPool", &c_vdb_use_global_pool) == -1)
    c_vdb_use_global_pool = 0;

  if (cfg_getstring (pconfig, "VDB", "TrimTrailingSpacesForDSN", &c_vdb_trim_trailing_spaces))
    c_vdb_trim_trailing_spaces = NULL;

  if (cfg_getlong (pconfig, "VDB", "DisableVDBStatisticsRefresh", &c_cfg_disable_vdb_stat_refresh) == -1)
    c_cfg_disable_vdb_stat_refresh = 0;

  if (c_vdb_use_global_pool < 0 || c_vdb_use_global_pool > 1)
    c_vdb_use_global_pool = 0;

#if 0
  if (cfg_getlong (pconfig, "VDB", "UseMTS", &c_vd_use_mts) == -1)
    c_vd_use_mts = 0;
#else
  if (msdtc_plugin)
    c_vd_use_mts = 1;
#endif

  if (c_rds_disconnect_timeout < 1)
    c_rds_disconnect_timeout = 1;

  /*
   *  Checks
   */
  if (c_number_of_buffers < 256)
    c_number_of_buffers = 256;

  if (c_max_dirty_buffers > (c_number_of_buffers * 9) / 10)
    c_max_dirty_buffers = (c_number_of_buffers * 9) / 10;
  if (c_max_dirty_buffers == 0)
    c_max_dirty_buffers = (c_number_of_buffers * 2) / 3;

  c_oldest_flushable = c_number_of_buffers / 2;
  if (c_number_of_buffers - c_oldest_flushable > c_max_dirty_buffers)
    c_oldest_flushable = c_number_of_buffers - c_max_dirty_buffers / 2;

  if (c_unremap_quota == 0)
    c_unremap_quota = c_number_of_buffers / 3;
  else if (c_unremap_quota < 500)
    c_unremap_quota = 500;

  if (c_server_threads > MAX_THREADS - 3)
    c_server_threads = MAX_THREADS - 3;


  /* Initialization of UCMs */

  section = "Ucms";
  if (cfg_getstring (pconfig, section, "UcmPath", &c_ucm_load_path) == -1)
    c_ucm_load_path = 0;
  if (c_ucm_load_path)
    {
      int loadctr;
      for (loadctr = 1; loadctr < 100; loadctr++)
	{
	  char keyname[32];
	  char *ucm_file, *ucm_names;
	  char ucm_path[PATH_MAX];
	  encoding_handler_t *new_eh;
	  sprintf (keyname, "Ucm%d", loadctr);
	  if (cfg_find (pconfig, section, keyname) != 0)
	    continue;
	  if (2 != cslnumentries (pconfig->value))
	    {
	      log_error ("Ucm%d value is invalid and ignored; UCM file name and name(s) of encoding are expected", loadctr);
	      continue;
	    }
	  ucm_file = cslentry (pconfig->value, 1);
	  ucm_names = cslentry (pconfig->value, 2);
	  if (strlen (c_ucm_load_path) + 1 + strlen (ucm_file) >= PATH_MAX)
	    {
	      log_error ("UCM file name %s/%s is too long, skipped.", c_ucm_load_path, ucm_file);
	    }
	  else
	    {
	      sprintf (ucm_path, "%s/%s", c_ucm_load_path, ucm_file);
	      new_eh =
		  eh_create_ucm_handler (ucm_names, ucm_path, (eh_ucm_log_callback *) log_info, (eh_ucm_log_callback *) log_error);
	      if (NULL != new_eh)
		eh_load_handler (new_eh);
	    }
	  free (ucm_file);
	  free (ucm_names);
	}
    }


  /* Initialization of national filesystems */

  section = "I18N";

  if (cfg_getlong (pconfig, section, "XAnyNormalization", &c_lh_xany_normalization_flags) == -1)
    c_lh_xany_normalization_flags = 0;

  if (cfg_getlong (pconfig, section, "WideFileNames", &c_i18n_wide_file_names) == -1)
    c_i18n_wide_file_names = 0;

  if (cfg_getstring (pconfig, section, "VolumeEncoding", &c_i18n_volume_encoding) == -1)
    c_i18n_volume_encoding = NULL;

  if (cfg_getstring (pconfig, section, "VolumeEmergencyEncoding", &c_i18n_volume_emergency_encoding) == -1)
    c_i18n_volume_emergency_encoding = NULL;



  /*
   *  Parse [Plugins] section
   */
  section = "Plugins";

  if (cfg_getstring (pconfig, section, "LoadPath", &c_plugin_load_path) == -1)
    c_plugin_load_path = 0;

  /* Initialization of plugins */
  srv_plugins_init ();
  if (!c_lite_mode && c_plugin_load_path)
    {
      int loadctr;
      for (loadctr = 1; loadctr < 100; loadctr++)
	{
	  char keyname[32];
	  char *plugin_type, *plugin_dll;
	  sprintf (keyname, "Load%d", loadctr);
	  if (cfg_find (pconfig, section, keyname) != 0)
	    continue;
	  if (2 != cslnumentries (pconfig->value))
	    {
	      log_error ("Load%d value is invalid and ignored; type and name of plugin expected", loadctr);
	      continue;
	    }
	  plugin_type = cslentry (pconfig->value, 1);
	  plugin_dll = cslentry (pconfig->value, 2);
	  plugin_load (plugin_type, plugin_dll, c_plugin_load_path, loadctr, (plugin_log_callback *) log_info,
	      (plugin_log_callback *) log_error);
	  /*free (plugin_type); */
	  /*free (plugin_dll); */
	  if (msdtc_plugin)
	    c_vd_use_mts = 1;
	}
    }


  /* Finalization */
  PrpcSetThreadParams (c_server_thread_sz, c_main_thread_sz, c_future_thread_sz, c_server_threads);

  return 0;
}


/*
 *  Called from DBMS whenever it switches to a new transaction
 *  log file. Should change that scheme some day.
 */
void
new_cfg_replace_log (char *new_log)
{
  PCONFIG pconfig1;     /* local copy of the configuration file */
  if (cfg_init (&pconfig1, f_config_file) == -1)
    {
      log (L_ERR, "Cannot open config file file %s", f_config_file);
      return;
    }
  cfg_write (pconfig1, "Database", "TransactionFile", new_log);
  cfg_commit (pconfig1);
  cfg_done (pconfig1);
}

/*
 *  This gets called when the checkpoint interval is changed.
 */

void
new_cfg_set_checkpoint_interval (int32 f)
{
  char valbuf[10];
  PCONFIG pconfig1;     /* local copy of the configuration file */
  if (cfg_init (&pconfig1, f_config_file) == -1)
    {
      log (L_ERR, "Cannot open config file file %s", f_config_file);
      return;
    }

  sprintf(valbuf, "%ld", (long) f);
  cfg_write (pconfig1, "Parameters", "CheckpointInterval", valbuf);
  cfg_commit (pconfig1);
  cfg_done (pconfig1);
}

/*
 *  Called from DBMS to build the main dbs.
 *  Simply passes all configuration to the dbs.
 */
void
new_db_read_cfg (dbe_storage_t * ignore, char *mode)
{
  main_bufs = c_number_of_buffers;
  cf_lock_in_mem = c_lock_in_mem;
  cp_unremap_quota = c_unremap_quota;
  correct_parent_links = c_bad_parent_links;
  disable_listen_on_unix_sock = c_disable_listen_on_unix_sock;
  disable_listen_on_tcp_sock = c_disable_listen_on_tcp_sock;
#if 0/*obsoleted*/
  null_bad_dtp = c_bad_dtp;
  atomic_dive = c_atomic_dive;
#endif
  prefix_in_result_col_names = c_prefix_resultnames;
  disk_no_mt_write = c_disable_mt_write;
  case_mode = c_case_mode;
  isdts_mode = c_isdts;
  null_unspecified_params = c_null_unspecified_params;
  file_extend = c_file_extend;
  n_oldest_flushable = c_oldest_flushable;
  cfg_autocheckpoint = 60000L * c_checkpoint_interval;
  cfg_scheduler_period = 60000L * c_scheduler_period;
  vd_param_batch = c_num_array_params;
  vd_opt_arrayparams = c_use_array_params;
  rds_disconnect_timeout = c_rds_disconnect_timeout * 1000;
  vdb_use_global_pool = c_vdb_use_global_pool;
  vdb_oracle_catalog_fix = c_vdb_oracle_catalog_fix;
  vdb_attach_autocommit = c_vdb_attach_autocommit;
  reconnect_on_vdb_error = c_vdb_reconnect_on_vdb_error;

  vdb_client_fixed_thread = c_vdb_client_fixed_thread & 0x01;
  if (!prpc_disable_burst_mode)
    prpc_disable_burst_mode = c_vdb_client_fixed_thread & 0x02;
  if (!prpc_forced_fixed_thread)
    prpc_forced_fixed_thread = c_vdb_client_fixed_thread & 0x04;
  if (!prpc_force_burst_mode)
    prpc_force_burst_mode = c_vdb_client_fixed_thread & 0x08;
  prpc_burst_timeout_msecs = c_prpc_burst_timeout_msecs;

  vdb_serialize_connect = c_vdb_serialize_connect;
  vdb_no_stmt_cache = c_vdb_no_stmt_cache;
  cfg_disable_vdb_stat_refresh = c_cfg_disable_vdb_stat_refresh;
  vdb_odbc_error_file = c_vdb_odbc_error_file;
  vdb_trim_trailing_spaces = c_vdb_trim_trailing_spaces;
  sqlc_no_remote_pk = c_skip_dml_primary_key;
  remote_pk_not_unique = c_remote_pk_not_unique;
  default_collation_name = c_default_collation_name;
  default_charset_name = c_default_charset_name;
  ws_default_charset_name = c_ws_default_charset_name;
  http_port = c_http_port;
  dav_root = c_dav_root;
  vsp_in_dav_enabled = c_vsp_in_dav_enabled;
  http_proxy_enabled = c_http_proxy_enabled;
  enable_gzip = c_gzip_enabled;
  spotlight_integration = c_spotlight_integration;
  http_ses_size = c_http_ses_size;
  default_mail_server = c_default_mail_server;
  init_trace = c_init_trace;
  allowed_dirs = c_allowed_dirs;
  denied_dirs = c_denied_dirs;
  if (!recover_file_prefix) /* when recovering, we use backup_dirs passed from command line */
  backup_dirs = c_backup_dirs;
  safe_execs = c_safe_execs;
  dba_execs = c_dba_execs;
  temp_dir = c_temp_dir;
  temp_ses_dir = c_temp_ses_dir;
  server_default_language_name = c_server_default_language_name;
  http_threads = c_http_threads;
  http_thread_sz = c_http_thread_sz;
  http_keep_hosting = c_http_keep_hosting;
  log_audit_trail = c_log_audit_trail;

  temp_aspx_dir = c_temp_aspx_dir;

  java_classpath = c_java_classpath;
  default_txn_isolation = c_default_txn_isolation;
  c_use_aio = c_c_use_aio;
  aq_max_threads = c_aq_max_threads;
  if (aq_max_threads > 1000)
    aq_max_threads = 1000;
  if (aq_max_threads < 10 && aq_max_threads > 0)
    aq_max_threads = 10;
#ifdef _SSL
  https_port = c_https_port;
  https_cert = c_https_cert;
  https_key = c_https_key;
  https_client_verify_depth = c_https_client_verify_depth;
  https_client_verify = c_https_client_verify;
  https_client_verify_file = c_https_client_verify_file;
#endif

#ifdef BIF_XML
#ifdef _IMSG
  pop3_port = c_pop3_port;
  nntp_port = c_nntp_port;
  ftp_port = c_ftp_port;
  ftp_server_timeout = c_ftp_server_timeout;
#endif
#endif

  vd_use_mts = c_vd_use_mts;

  http_max_keep_alives = c_http_max_keep_alives;
  http_keep_alive_timeout = c_http_keep_alive_timeout;
  http_max_cached_proxy_connections = c_http_max_cached_proxy_connections;
  http_proxy_connection_cache_timeout = c_http_proxy_connection_cache_timeout;
  http_ses_trap = c_http_ses_trap;
  http_check_rdf_accept = c_http_check_rdf_accept;

  vt_batch_size_limit = c_vt_batch_size_limit;
  sqlc_add_views_qualifiers = c_sqlc_add_views_qualifiers;
  allow_pwd_magic_calc = c_allow_pwd_magic_calc;
  pwd_magic_users_list = c_pwd_magic_users_list;
  txn_after_image_limit = c_txn_after_image_limit;
  n_fds_per_file = c_n_fds_per_file;
  sqlo_max_layouts = c_sqlo_max_layouts;
  sql_proc_use_recompile = c_sql_proc_use_recompile;


  callstack_on_exception = c_callstack_on_exception;
  log_file_line = c_log_file_line;
  pl_debug_all = c_pl_debug_all;
  pl_debug_cov_file = c_pl_debug_cov_file;
  cfg_thread_live_period = c_cfg_thread_live_period * 60000L;
  cfg_thread_threshold = c_cfg_thread_threshold;
  cfg_resources_clear_interval = c_cfg_resources_clear_interval * 60000L;
  wi_inst.wi_max_dirty = c_max_dirty_buffers;

  wi_inst.wi_open_mode = mode;
  wi_inst.wi_temp_allocation_pct = (short) c_temp_allocation_pct;

  recursive_ft_usage = c_recursive_ft_usage;
  recursive_trigger_calls = c_recursive_trigger_calls;

  setp_top_row_limit = c_setp_top_row_limit;
  sql_max_tree_depth = c_sql_max_tree_depth;
  hi_end_memcache_size = c_hi_end_memcache_size;
  run_as_os_uname = c_run_as_os_uname;
  dbe_auto_sql_stats = c_dbe_auto_sql_stats;
  xa_persistent_file = c_xa_persistent_file;
  sql_warning_mode = (sqw_mode) c_sql_warning_mode;
  http_print_warnings_in_output = c_http_print_warnings_in_output;
  sql_warnings_to_syslog = c_sql_warnings_to_syslog;
  temp_db_size = c_temp_db_size;
  dbev_enable = c_dbev_enable;
  iri_cache_size = c_iri_cache_size;
  lite_mode = c_lite_mode;
  rdf_obj_ft_rules_size = c_rdf_obj_ft_rules_size;
  if (rdf_obj_ft_rules_size < 10)
    rdf_obj_ft_rules_size = lite_mode ? 10 : 100;
  it_n_maps = c_it_n_maps;
  if (it_n_maps < 2 || it_n_maps > 1024)
    {
      it_n_maps = lite_mode ? 8 : 256;
    }
  else if (0 != (it_n_maps % 2))
    {
      it_n_maps = 2 * (it_n_maps / 2);
    }
  uriqa_dynamic_local = c_uriqa_dynamic_local;
  sparql_result_set_max_rows = c_sparql_result_set_max_rows;
  sparql_max_mem_in_use = c_sparql_max_mem_in_use;
  cli_encryption_on_password = c_cli_encryption_on_password;

  lh_xany_normalization_flags = c_lh_xany_normalization_flags;
  i18n_wide_file_names = c_i18n_wide_file_names;
  if (NULL != c_i18n_volume_encoding)
    {
      i18n_volume_encoding = eh_get_handler (c_i18n_volume_encoding);
      if (NULL == i18n_volume_encoding)
        {
          log_error ("The value of VolumeEncoding parameter is not a valid encoding name");
          return;
        }
    }
  else
    i18n_volume_emergency_encoding = &eh__ISO8859_1;
  if (NULL != c_i18n_volume_emergency_encoding)
    {
      i18n_volume_emergency_encoding = eh_get_handler (c_i18n_volume_emergency_encoding);
      if (NULL == i18n_volume_emergency_encoding)
        {
          log_error ("The value of VolumeEmergencyEncoding parameter is not a valid encoding name");
          return;
        }
    }
  else
    i18n_volume_emergency_encoding = &eh__ISO8859_1;
}

/*
 * Parses string like "42K" which mean size of DB element (file, stripe etc).
 * On return sets `size', if stated, `modifier', if stated, and `n_pages', if stated.
 * returns 0 on success, nonzero on error.
 */
int
cfg_parse_size_with_modifier (const char *valstr, unsigned long *size, char *modifier, unsigned long *n_pages)
{
  unsigned long size_ = 0;
  char modifier_ = 0;
  unsigned long n_pages_ = 0;

  if (!valstr)
    GPF_T;

  size_ = (unsigned long) atol (valstr);
  if (size_ == 0)
    {
      return -1;
    }

  modifier_ = toupper (valstr[strlen (valstr) - 1]);
  switch (modifier_)
    {
    case 'K':
      n_pages_ = size_ / KILOS_PER_PAGE;
      size_ *= 1024;
      break;
    case 'M':
      n_pages_ = (1024 * size_) / KILOS_PER_PAGE;
      size_ *= 1024 * 1024;
      break;
    case 'G':
      n_pages_ = (1024 * 1024 * size_) / KILOS_PER_PAGE;
      size_ *= 1024 * 1024 * 1024;
      break;
    case 'B':
      n_pages_ = size_;
      break;
    default:
      if (!isdigit (modifier_))
	return -1;
    }

  if (size)
    *size = size_;
  if (modifier)
    *modifier = modifier_;
  if (n_pages)
    *n_pages = n_pages_;
  return 0;
}


int
cfg_getsize (PCONFIG pc, char * sec, char * attr, size_t * sz)
{
  char * str;
  if (-1 == cfg_getstring (pc, sec, attr, &str))
    return -1;
  if (-1 == cfg_parse_size_with_modifier (str, sz, NULL, NULL))
    return -1;
  return 0;
}

#define cslentry dk_cslentry
#define csl_free(f) dk_free_box (f)

void
new_dbs_read_cfg (dbe_storage_t * dbs, char *ignore_file_name)
{
  char temp_string[2048];
  char *section = dbs->dbs_name;
  char *c_database_file;
  char *s_db = "db";
  char *s_trx = "trx";

  if (dbs->dbs_type == DBS_PRIMARY)
    section = "Database";
  else if (dbs->dbs_type == DBS_TEMP)
    {
      section = "TempDatabase";
      s_db = "tdb";
      s_trx = "ttr";
    }
  else if (dbs->dbs_type == DBS_RECOVER)
    section = "Database";

  if (cfg_getstring (pconfig, section, "DatabaseFile", &c_database_file) == -1)
    c_database_file = s_strdup (setext (prefix, s_db, EXT_SET));

  if (cfg_getstring (pconfig, section, "TransactionFile", &c_txfile) == -1)
    c_txfile = s_strdup (setext (prefix, s_trx, EXT_SET));

  if (cfg_getlong (pconfig, section, "FileExtend", &c_file_extend) == -1)
    c_file_extend = 100;

  if (c_file_extend < DP_INSERT_RESERVE + 5)
    c_file_extend = DP_INSERT_RESERVE + 5;

  if (cfg_getlong (pconfig, section, "MaxCheckpointRemap", &c_max_checkpoint_remap) == -1)
    {
      if (dbs->dbs_type != DBS_PRIMARY || cfg_getlong (pconfig, "Parameters", "MaxCheckpointRemap", &c_max_checkpoint_remap) == -1)
	c_max_checkpoint_remap = 0;
    }

  /* from parameters */
  if (cfg_getlong (pconfig, section, "LogSegments", &c_log_segments_num) == -1)
    c_log_segments_num = 0;

  c_log_segments = NULL;
  if (c_log_segments_num)
    {
      int nlog_segments;
      char keyname[32];
      char s_name[100];
      unsigned long llen;
      log_segment_t **last_log = &c_log_segments;

      for (nlog_segments = 1;; nlog_segments++)
	{
	  sprintf (keyname, "Log%d", nlog_segments);
	  if (cfg_find (pconfig, section, keyname) != 0)
	    break;

	  if (sscanf (pconfig->value, "%s %s", s_name, keyname) != 2)
	    {
	      log_error ("The values for log segment %d are invalid", nlog_segments);
	      exit (-1);
	    }

	  if (cfg_parse_size_with_modifier (keyname, &llen, NULL, NULL))
	    {
	      log_error ("The values for log segment %d are invalid", nlog_segments);
	      exit (-1);
	    }

	  {
	    NEW_VARZ (log_segment_t, ls);
	    ls->ls_file = box_string (s_name);
	    ls->ls_bytes = llen;
	    *last_log = ls;
	    last_log = &ls->ls_next;
	  }
	}

      if (nlog_segments == 1)
	{
	  log_error ("Log segmentation is enabled, but no log segments are specified");
	  return;
	}
    }

  if (cfg_getlong (pconfig, section, "Striping", &c_striping) == -1)
    c_striping = 0;

  /*
   *  Parse [Striping] section
   */

  if ((dbs->dbs_type == DBS_PRIMARY) || (dbs->dbs_type == DBS_RECOVER))
    section = "Striping";
  else if (dbs->dbs_type == DBS_TEMP)
    section = "TempStriping";
  else
    {
      sprintf (temp_string, "%.2000s Striping", dbs->dbs_name);
      section = &(temp_string[0]);
    }
  c_stripes = NULL;
  if (c_striping)
    {
      int indx, nsegs;
      disk_segment_t *seg;
      disk_stripe_t *dst;
      char *segszstr;
      unsigned long segszvalue;
      char keyname[32];
      unsigned long n_pages;
      int n_stripes;
      char modifier;

      for (nsegs = 1;; nsegs++)
	{
	  sprintf (keyname, "Segment%d", nsegs);
	  if (cfg_find (pconfig, section, keyname) != 0)
	    break;

	  n_stripes = cslnumentries (pconfig->value) - 1;
	  segszstr = cslentry (pconfig->value, 1);

	  if (cfg_parse_size_with_modifier (segszstr, &segszvalue, &modifier, &n_pages))
	    {
	      log_error ("The size for strip segment %d is invalid", nsegs);
              csl_free (segszstr);
	      return;
	    }
	  if (modifier == 'K' && segszvalue % KILOS_PER_PAGE)
	    {
	      log_error ("The size for stripe segment %d must be a multiple of %d", nsegs, PAGE_SZ);
              csl_free (segszstr);
	      return;
	    }
	  if ((n_pages / n_stripes) > (LONG_MAX / PAGE_SZ))
	    {
#if (!defined (FILE64) && !defined (WIN32))
	      n_pages = (LONG_MAX / PAGE_SZ) * n_stripes;
	      log_error ("The size for stripe segment #%d exceeds 2G limit, setting to maximum allowed %d pages", nsegs, n_pages);
#endif
	    }
	  if (n_pages % (EXTENT_SZ * n_stripes) != 0)
	    {
	      int unit = EXTENT_SZ * n_stripes;
	      long old_pages = n_pages;
	      n_pages = ((n_pages / unit) + 1) * unit;
	      log_warning ("The size for stripe segment %d is %ld pages, not a multiple of %d, will use %d pages",
		  nsegs, old_pages, unit, n_pages);
	    }

          csl_free (segszstr);

	  seg = (disk_segment_t *) dk_alloc (sizeof (disk_segment_t));
	  seg->ds_size = n_pages;
	  seg->ds_n_stripes = n_stripes;
	  seg->ds_stripes = (disk_stripe_t **) dk_alloc_box (n_stripes * sizeof (caddr_t), DV_ARRAY_OF_LONG);

	  for (indx = 0; indx < n_stripes; indx++)
	    {
	      char *value = cslentry (pconfig->value, 2 + indx);
	      char *sep = NULL;
	      char *s_ioq = NULL;

	      /* TODO: we should be able to recover from this condition */
	      if (value == NULL || *value == 0)
		{
		  log_error ("Syntax error in Striping section");
		  return;
		}

	      /* Check for queue name */
	      if ((sep = strrchr (value, '=')) != NULL
#if ! defined (WIN32)
		  || (sep = strrchr (value, ':')) != NULL
#endif
		  )
		{
		  s_ioq = (char *) ltrim ((const char *) (sep + 1));
		  *sep = '\0';
		}
	      rtrim (value);

	      dst = (disk_stripe_t *) dk_alloc (sizeof (disk_stripe_t));
	      memset (dst, 0, sizeof (disk_stripe_t));
	      dst->dst_mtx = mutex_allocate ();
	      if (s_ioq && *s_ioq)
		dst->dst_iq_id = box_string (s_ioq);
	      dst->dst_file = box_string (value);
	      seg->ds_stripes[indx] = dst;

	      csl_free (value);
	    }
	  c_stripes = dk_set_conc (c_stripes, dk_set_cons ((caddr_t) seg, NULL));
	}
      if (nsegs == 1)
	{
	  log_error ("Striping is enabled, but no stripes are specified");
	  return;
	}
    }

  dbs->dbs_file = box_string (c_database_file);
  dbs->dbs_log_name = box_string (c_txfile);
  dbs->dbs_cpt_file_name = box_string (setext (s_strdup (c_database_file), "cpt", EXT_SET));
  dbs->dbs_extend = c_file_extend;
  dbs->dbs_max_cp_remaps = c_max_checkpoint_remap;
  dbs->dbs_log_segments = c_log_segments;
  dbs->dbs_disks = c_stripes;
}


dk_set_t
new_cfg_read_storages (caddr_t ** temp_storage)
{
  int n_storage;
  dk_set_t res = NULL;
  char storage_name[50];

  for (n_storage = 1;; n_storage++)
    {
      sprintf (storage_name, "Storage%d", n_storage);
      if (cfg_find (pconfig, "Database", storage_name) != 0)
	break;
      dk_set_push (&res, list (2, box_string (pconfig->value), NULL));
    }

  *temp_storage = (caddr_t *) list (2, box_string ("TempDatabase"), NULL);

  return res;
}


/*
 *  Checks if the database is in use
 */
static int lck_fd = -1;

#if !defined (WIN32)
# if defined (HAVE_FLOCK_IN_SYS_FILE) || defined (F_SETLK)
#  define LCK_O_FLAGS   O_CREAT|O_WRONLY
# else
#  define LCK_O_FLAGS	O_CREAT|O_EXCL|O_WRONLY
#  define LCK_CAN_CLOSE	1
# endif
#else
# define LCK_O_FLAGS	O_CREAT|O_EXCL|O_TEMPORARY|O_WRONLY
#endif


static int
db_lck_lock_fd (int fd, char *name)
{
#if defined (F_SETLK)
  struct flock fl;

  /* Get an advisory WRITE lock */
  fl.l_type = F_WRLCK;
  fl.l_whence = SEEK_SET;
  fl.l_start = 0;
  fl.l_len = 0;
  fl.l_pid = getpid ();

  if (fcntl (fd, F_SETLK, &fl) < 0)
    {
      log (L_ERR, "Unable to lock file %s (%m).", name);

      /* we could not get a lock, so who owns it? */
      fcntl (fd, F_GETLK, &fl);
      log (L_ERR, "Virtuoso is already runnning (pid %ld)", fl.l_pid);
      return -1;
    }
#elif defined (HAVE_FLOCK_IN_SYS_FILE)
  if (flock (fd, LOCK_EX | LOCK_NB))
    {
      log (L_ERR, "Unable to lock file %s (%m).", name);
      return -1;
    }
#endif

  return 0;
}


static void
db_lck_unlock_fd (int fd, char *name)
{
#if defined (F_SETLK)
  struct flock fl;

  /* Unlock */
  fl.l_type = F_UNLCK;
  fl.l_whence = SEEK_SET;
  fl.l_start = 0;
  fl.l_len = 0;
  fl.l_pid = getpid ();

  if (fcntl (fd, F_SETLK, &fl) < 0)
    log (L_WARNING, "Unable to unlock %s (%m)", name);
#elif defined (HAVE_FLOCK_IN_SYS_FILE)
  if (flock (fd, LOCK_UN | LOCK_NB))
    log (L_WARNING, "Unable to unlock %s (%m)", name);
#endif
}


static void
db_lck_write_pid (int fd)
{
  char pid_arr[50];
  int len;

  snprintf (pid_arr, sizeof (pid_arr), "VIRT_PID=%lu\n", (unsigned long) getpid ());
  len = (int) strlen (pid_arr);
  len = len > sizeof (pid_arr) ? sizeof (pid_arr) : len;

  if (len != write (fd, pid_arr, len))
    {
      log (L_ERR, "Unable to store the PID of the virtuoso process into the lock file : %m");
    }
}


int
db_check_in_use (void)
{
  /* OK, this is not fool proof, but it provides basic protection */
  if ((lck_fd = open (c_lock_file, LCK_O_FLAGS, 0644)) == -1)
    {
      log (L_ERR, "Unable to create file %s (%m).", c_lock_file);
      goto failed;
    }

  if (db_lck_lock_fd (lck_fd, c_lock_file))
    goto failed;

  db_lck_write_pid (lck_fd);

#if defined (LCK_CAN_CLOSE)
  close (lck_fd);
  lck_fd = -1;
#endif
  return 0;

failed:
  log (L_ERR, "This probably means you either do not have permission to start");
  log (L_ERR, "this server, or that %s is already running.", MYNAME);
  log (L_ERR, "If you are absolutely sure that this is not the case, please try");
  log (L_ERR, "to remove the file %s and start again.", c_lock_file);

  if (lck_fd >= 0)
    close (lck_fd);
  lck_fd = -1;

  return -1;
}


void
db_not_in_use (void)
{
  if (lck_fd != -1)
    {
      db_lck_unlock_fd (lck_fd, c_lock_file);
      close (lck_fd);
      lck_fd = -1;
    }

#if ! defined (WIN32)
  if (unlink (c_lock_file) == -1)
    log (L_WARNING, "Unable to remove %s (%m)", c_lock_file);
#endif
}


/* needed to access the server port in hosting binaries */
char *
virtuoso_odbc_port ()
{
  return c_serverport;
}

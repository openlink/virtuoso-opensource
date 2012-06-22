/*
 *  auxfiles.c
 *
 *  $Id$
 *
 *  License file (license.dat)
 *  Error logging (wi.err)
 *  Configuration file parsing (wi.cfg)
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

#include "sqlnode.h"
#include "sqlver.h"

/*
 *  These are the global variables that are set through the config file
 */

long server_port;
char * http_port;
char * https_port;
char * https_cert;
char * https_key;
char * https_extra;
int32 https_client_verify = 0;
int32 https_client_verify_depth = 0;
char * https_client_verify_file = NULL;
char * https_client_verify_crl_file = NULL;
char *f_old_dba_pass = NULL;
char *f_new_dba_pass = NULL;
char *f_new_dav_pass = NULL;

char *java_classpath = NULL;
int32 http_threads;
int32 ini_http_threads;
int32 http_thread_sz;
int32 http_keep_alive_timeout = 15;
long http_max_keep_alives = 200;
long http_max_cached_proxy_connections = 20;
long http_proxy_connection_cache_timeout = 15;
char * dav_root = 0;
long vsp_in_dav_enabled = 0;
long http_proxy_enabled = 0;
char * default_mail_server = 0;
char * init_trace = 0;
char * allowed_dirs = 0;
char * denied_dirs = 0;
char * backup_dirs = 0;
char * safe_execs = 0;
char * dba_execs = 0;
char * temp_dir = NULL;
char * pl_debug_cov_file = NULL;
int lite_mode = 0;
extern int it_n_maps;
extern int rdf_obj_ft_rules_size;

int cp_unremap_quota;
int correct_parent_links;
int main_bufs;
int n_fds_per_file = 1;
int32 cf_lock_in_mem;
long file_extend;
int n_threads = 10;
int t_server_sz = 0;
int t_main_sz = 0;
int t_future_sz = 0;
int n_oldest_flushable;
int null_bad_dtp;
int atomic_dive = 0;
int dive_pa_mode = PA_READ;
int32 c_compress_mode = 0;
int default_txn_isolation = ISO_REPEATABLE;
int prefix_in_result_col_names;
int disk_no_mt_write;
char *db_name;
char *repl_server_enable;
long repl_queue_max;
long vd_param_batch = 10;
long vd_opt_arrayparams = 0;
int dive_cache_enable = 0;
dp_addr_t crashdump_start_dp = 0;
dp_addr_t crashdump_end_dp = 0;

unsigned long int cfg_thread_live_period = 0;
unsigned long int cfg_thread_threshold = 10;

/* Do automatic checkpoint approximately every N milliseconds. */
/* If zero, do not do it. */
/* Specified in minutes. Note that 1440 minutes = 24 hours. */
unsigned long int cfg_autocheckpoint = 0;
int32 c_checkpoint_interval = 0;
int32 cl_run_local_only = CL_RUN_LOCAL;
int wi_blob_page_dir_threshold;
extern const char* recover_file_prefix;

char *run_as_os_uname = NULL;

/* Control use of sync after checkpoint
 *
 * 0 - no sync
 * 1 - sync
 * 2 - fsync
 */

int32 c_checkpoint_sync = 2;
int c_use_o_direct = 0;
int c_use_aio = 0;
int c_stripe_unit = 256;

extern int32 sqlo_compiler_exceeds_run_factor;

int32 c_dense_page_allocation = 0;
int32 log_proc_overwrite = 1;

void _db_read_cfg (dbe_storage_t * dbs, char *mode);
dk_set_t _cfg_read_storages (caddr_t **temp_storage);
void _dbs_read_cfg (dbe_storage_t * dbs, char *file);

void (*cfg_replace_log)(char *str) = _cfg_replace_log;
void (*cfg_set_checkpoint_interval)(int32) = _cfg_set_checkpoint_interval;
void (*db_read_cfg) (caddr_t *it, char *mode) = (void (*) (caddr_t *it, char *mode))_db_read_cfg;
void (*dbs_read_cfg) (caddr_t *it, char *mode) = (void (*) (caddr_t *it, char *mode)) _dbs_read_cfg;
dk_set_t (*dbs_read_storages) (caddr_t **temp_file) = _cfg_read_storages;

void
srv_set_cfg(
    void (*replace_log)(char *str),
    void (*set_checkpoint_interval)(int32 f),
    void (*read_cfg)(caddr_t * it, char *mode),
    void (*s_read_cfg)(caddr_t * it, char *mode),
    dk_set_t (*read_storages)(caddr_t **temp_file)
    )
{
  cfg_replace_log = replace_log;
  cfg_set_checkpoint_interval = set_checkpoint_interval;
  db_read_cfg = read_cfg;
  dbs_read_cfg = s_read_cfg;
  dbs_read_storages = read_storages;
}

void it_make_buffer_list (index_tree_t * it, int n);


/*
 *  log_error_list, log_error, log_info were isolated from log.c
 *  PmN
 */

#ifndef PMN_LOG
void
log_error_list (char *str, va_list list)
{
  FILE *dbg_out = fopen ("wi.err", "a");
  char tmp[100];
  char *eol;
  time_t tim = time (NULL);
  struct tm tms;
  struct tm *tm = &tms;

#if defined (PREEMPT) && !defined (WIN32) && !defined(SOLARIS)
  localtime_r (&tim, &tms);
  asctime_r (tm, tmp);
#else
  tm = localtime (&tim);
  strncpy (tmp, asctime (tm), sizeof (tmp));
#endif

  eol = strchr (tmp, '\n');
  if (eol)
    *eol = 0;

  if (dbg_out)
    {
      fprintf (dbg_out, "%s ", tmp);
      vfprintf (dbg_out, str, list);
      fprintf (dbg_out, "\n");
      fflush (dbg_out);
      fclose (dbg_out);
    }

  fprintf (stderr, "%s ", tmp);
  vfprintf (stderr, str, list);
  fprintf (stderr, "\n");
}
#endif


/*
 *  cfg_replace_log, db_read_cfg were isolated from disk.c
 *  PmN
 */
caddr_t srv_client_defaults ();


void
_cfg_replace_log (char *new_log)
{
  dk_set_t lines = NULL;
  char cfg_line[100];
  char log_file[100];
  FILE *cfg = fopen (CFG_FILE, "r");
  while (fgets (cfg_line, sizeof (cfg_line), cfg))
    {
      if (1 == sscanf (cfg_line, "\nlog_file: %s", log_file))
	snprintf (cfg_line, sizeof (cfg_line), "log_file: %s\n", new_log);
      dk_set_push (&lines, (void *) box_string (cfg_line));
    }
  fclose (cfg);
  lines = dk_set_nreverse (lines);
  cfg = fopen (CFG_FILE, "w");
  DO_SET (char *, ln, &lines)
  {
    fprintf (cfg, "%s", ln);
    dk_free_box (ln);
  }
  END_DO_SET ();
  dk_set_free (lines);
  fclose (cfg);
}


void
_cfg_set_checkpoint_interval (int32 f)
{
  dk_set_t lines = NULL;
  char cfg_line[100];
  int f_val;
  FILE *cfg = fopen (CFG_FILE, "r");
  while (fgets (cfg_line, sizeof (cfg_line), cfg))
    {
      if (1 == sscanf (cfg_line, "\nautocheckpoint: %d", &f_val))
	snprintf (cfg_line, sizeof (cfg_line), "autocheckpoint: %d\n", (int)f);
      dk_set_push (&lines, (void *) box_string (cfg_line));
    }
  fclose (cfg);
  lines = dk_set_nreverse (lines);
  cfg = fopen (CFG_FILE, "w");
  DO_SET (char *, ln, &lines)
  {
    fprintf (cfg, "%s", ln);
    dk_free_box (ln);
  }
  END_DO_SET ();
  dk_set_free (lines);
  fclose (cfg);
}


static char *
cfg_get_parm (const char *file, const char *parm, int is_string)
{
  char temp[100];
  long ntemp;
  const char *where = strstr (file, parm);
  if (where)
    {
      where += strlen (parm);
      if (is_string)
	{
	  if (1 == sscanf (where, "%s", temp))
	    return (box_string (temp));
	  else
	    return NULL;
	}
      else
	{
	  if (1 == sscanf (where, "%ld", &ntemp))
	    return ((char *) (ptrlong) ntemp);
	  else
	    return NULL;
	}
    }
  else
    {
      return NULL;
    }
}

int32 cli_prefetch;
int32 cli_prefetch_bytes;
int32 cli_query_timeout;
int32 cli_txn_timeout;
int32 cli_not_c_char_escape;
int32 cli_utf8_execs;
int32 cli_binary_timestamp = 1;
int32 cli_no_system_tables = 0;

caddr_t client_defaults;

caddr_t
srv_client_defaults (void)
{
  return (box_copy_tree (client_defaults));
}


void
srv_client_defaults_init (void)
{
  caddr_t old = client_defaults;
  client_defaults = (caddr_t)
    list (16,
	  box_string ("SQL_TXN_ISOLATION"),
	  box_num (default_txn_isolation),
	  box_string ("SQL_PREFETCH_ROWS"),
	  box_num (cli_prefetch),
	  box_string ("SQL_PREFETCH_BYTES"),
	  box_num (cli_prefetch_bytes),
	  box_string ("SQL_QUERY_TIMEOUT"),
	  box_num (cli_query_timeout),
	  box_string ("SQL_TXN_TIMEOUT"),
	  box_num (cli_txn_timeout),
	  box_string ("SQL_NO_CHAR_C_ESCAPE"),
	  box_num (cli_not_c_char_escape ? 1 : 0),
	  box_string ("SQL_UTF8_EXECS"),
	  box_num (cli_utf8_execs),
	  box_string ("SQL_BINARY_TIMESTAMP"),
	  box_num (cli_binary_timestamp)
	  );
  dk_free_tree (old);
}


static int
cfg_parse_disks (dbe_storage_t * dbs, char *err, int err_max, char * cfg_file)
{
  log_segment_t **last_log = &dbs->dbs_log_segments;
  long llen;
  int s_inx = 0;
  char s_name[100];
  char s_ioq[1000];
  FILE *cfg = fopen (cfg_file, "r");
  disk_segment_t *seg = NULL;
  char line_buf[2000];		/* Was 100 */
  dk_set_t segs = NULL;

  while (fgets (line_buf, sizeof (line_buf), cfg))
    {
      long n_stripes, n_pages;
      if (2 == sscanf (line_buf, "segment %ld pages %ld stripes",
	  &n_pages, &n_stripes))
	{
	  seg = (disk_segment_t *) dk_alloc (sizeof (disk_segment_t));
	  if (n_pages % (EXTENT_SZ * n_stripes) != 0)
	    {
	      log_error ("Size of a segment in a segmented db must be a multiple of 256 times the number of stripes\n");
	      call_exit (1);
	      return -1;
	    }
	  seg->ds_size = n_pages;
	  seg->ds_n_stripes = n_stripes;
	  s_inx = 0;
	  seg->ds_stripes = (disk_stripe_t **) dk_alloc_box (
	      n_stripes * sizeof (caddr_t), DV_ARRAY_OF_LONG);
	  segs = dk_set_conc (segs, dk_set_cons ((caddr_t) seg, NULL));
	}
      s_ioq[0] = 0;
      if (0 == strncmp (line_buf, "stripe_", 7))
	continue;
      if (2 == sscanf (line_buf, "stripe %s %s", s_name, s_ioq)
	  || 1 == sscanf (line_buf, "stripe %s", s_name))
	{
	  NEW_VARZ (disk_stripe_t, dst);
	  if (!seg)
	    return -1;
	  dst->dst_mtx = mutex_allocate_typed (MUTEX_TYPE_LONG);
	  mutex_option (dst->dst_mtx, s_name, NULL, NULL);
	  dst->dst_file = box_string (s_name);
	  if (s_ioq[0])
	    dst->dst_iq_id = box_string (s_ioq);
	  if (((uint32) s_inx) >= BOX_ELEMENTS (seg->ds_stripes))
	    return -1;
	  seg->ds_stripes[s_inx++] = dst;
	}
      if (2 == sscanf (line_buf, "log %s %ld", s_name, &llen))
	{
	  NEW_VARZ (log_segment_t, ls);
	  ls->ls_file = box_string (s_name);
	  ls->ls_bytes = llen;
	  *last_log = ls;
	  last_log = &ls->ls_next;
	}
    }
  fclose (cfg);
  dbs->dbs_cfg_file = box_string (cfg_file);
  dbs->dbs_disks = segs;
  return 0;
}

static void
cfg_parse_backup_dirs()
{
  old_backup_dirs = dk_set_cons ((caddr_t) ".", NULL);
  old_backup_dirs->next = old_backup_dirs;
}

/*
   We should check also here that config-file contains all the
   mandatory fields.
 */

#define COND_PARAM(string, name) \
  tmp_param = cfg_get_parm(wholefile, string, 1); \
  if (tmp_param) \
    { \
      name = atol(tmp_param); \
      dk_free_box(tmp_param); \
    }

#define COND_PARAM_WITH_DEFAULT(string, name, defaultValue) \
  tmp_param = cfg_get_parm(wholefile, string, 1); \
  if (tmp_param) \
    { \
      name = atol(tmp_param); \
      dk_free_box(tmp_param); \
    } \
  else \
    { \
      name = (defaultValue); \
    }



void
_db_read_cfg (dbe_storage_t * ignore, char *mode)
{
  /* int trx_bufs; */
  /* char * trx_file; */
  int max_dirty;
  int read_stat;
  char *http_log_name;
  char wholefile[6002 + 1];	/* Was 1000 */
  char *tmp_param;
  long helper;

  int fd = open (CFG_FILE, O_RDWR);
  if (fd < 0)
    {
    cfg_file_error:
      log_error ( "There must be a valid %s file in the server's working "
	  "directory. Exiting", CFG_FILE);
      call_exit (1);
    }

  memset (wholefile, 0, sizeof (wholefile));
  wholefile[0] = '\n';		/* Start it with newline so that all headers are found. */
  read_stat = read (fd, (wholefile + 1), (sizeof (wholefile) - 2));

  if (read_stat <= 0)
    {
      goto cfg_file_error;
    }
  if (read_stat >= (sizeof (wholefile) - 2))
    {
      /* Stupid static code, but better than silently ignoring something */
      /* important. */
      log_error ( "The configuration file %s in the server's working directory "
	  "is longer than %d bytes. Exiting",
	  CFG_FILE, (int) (sizeof (wholefile) - 3));
      call_exit (1);
    }
  fd_close (fd, NULL);

  http_log_name = cfg_get_parm (wholefile, "\nHTTPLogFile:", 1);
  if (http_log_name)
    {
      http_log = fopen (http_log_name, "a");
      if (!http_log)
	log_error ("Can't open HTTP log file (%s)", http_log_name);
    }

  file_extend = (long) (ptrlong) cfg_get_parm (wholefile, "\nfile_extend:", 0);
  if (file_extend < DP_INSERT_RESERVE)
    file_extend = DP_INSERT_RESERVE + 5;

  main_bufs = (int) (ptrlong) cfg_get_parm (wholefile, "\nnumber_of_buffers:", 0);
  if (main_bufs < 256)
    main_bufs = 256;
  cf_lock_in_mem = (int) (ptrlong) cfg_get_parm (wholefile, "\nlock_in_mem:", 0);
  atomic_dive = (int) (ptrlong) cfg_get_parm (wholefile, "\natomic_dive:", 0);
  if (2 == atomic_dive)
    {
      dive_pa_mode = PA_WRITE;
    }
  atomic_dive = 0;

    max_dirty = (int) (ptrlong) cfg_get_parm (wholefile, "\nmax_dirty_buffers:", 0);
  wi_inst.wi_max_dirty = max_dirty;
  if (cfg_get_parm (wholefile, "\nautocorrect_links:", 0))
    correct_parent_links = 1;
  if (cfg_get_parm (wholefile, "\nno_mt_write:", 0))
    disk_no_mt_write = 1;

  dbe_auto_sql_stats = (long) (ptrlong) cfg_get_parm (wholefile, "\nauto_sql_stats:", 0);
  callstack_on_exception = (long) (ptrlong) cfg_get_parm (wholefile, "\ncallstack_on_exception:", 0);

  pl_debug_all = (long) (ptrlong) cfg_get_parm (wholefile, "\npl_debug:", 0);
  pl_debug_cov_file = cfg_get_parm (wholefile, "\ntest_coverage:", 1);


  case_mode = (int) (ptrlong) cfg_get_parm (wholefile, "\ncase_mode:", 0);

  /* Specified in minutes, contains milliseconds. */
  cfg_autocheckpoint = 60000L * ((unsigned long) (uptrlong) cfg_get_parm (wholefile,
      "\nautocheckpoint:", 0));

#if 0 /*obsoleted*/
  null_bad_dtp = cfg_get_parm (wholefile, "\nnull_bad_dtp:", 0) ? 1 : 0;
#endif

  prefix_in_result_col_names = cfg_get_parm (wholefile,
      "\nprefix_in_result_col_names:", 0) ? 1 : 0;

  n_threads = (long) (ptrlong) cfg_get_parm (wholefile, "\nthreads:", 0);
  if (!n_threads)
    n_threads = 20;

  t_server_sz = (long) (ptrlong) cfg_get_parm (wholefile, "\nserver_thread_size:", 0);
  if (t_server_sz < 60000)
    t_server_sz = 60000;

  t_main_sz = (long) (ptrlong) cfg_get_parm (wholefile, "\nmain_thread_size:", 0);
  if (t_main_sz < 140000) /* was 100000 */
    t_main_sz = 140000; /* was 100000 */

  t_future_sz = (long) (ptrlong) cfg_get_parm (wholefile, "\nfuture_thread_size:", 0);
  if (t_future_sz < 140000) /* was 100000 */
    t_future_sz = 140000; /* was 100000 */


  /* reserved threads: mtwrite, server, main */
  n_threads = MIN (n_threads, MAX_THREADS - 3);

  sqlc_add_views_qualifiers = (long) (ptrlong) cfg_get_parm (wholefile, "\nsqlc_add_views_qualifiers:", 0);

  wi_inst.wi_open_mode = mode;

  PrpcSetThreadParams (t_server_sz, t_main_sz, t_future_sz, n_threads);

  cli_prefetch = (long) (ptrlong) cfg_get_parm (wholefile, "\nSQL_PREFETCH_ROWS:", 0);
  cli_prefetch_bytes = (long) (ptrlong) cfg_get_parm (wholefile, "\nSQL_PREFETCH_BYTES:", 0);
  cli_query_timeout = (long) (ptrlong) cfg_get_parm (wholefile, "\nSQL_QUERY_TIMEOUT:", 0);
  cli_txn_timeout = (long) (ptrlong) cfg_get_parm (wholefile, "\nSQL_TXN_TIMEOUT:", 0);
  cli_not_c_char_escape = (long) (ptrlong) cfg_get_parm (wholefile, "\nSQL_NO_CHAR_C_ESCAPE:", 0);
  cli_utf8_execs = (long) (ptrlong) cfg_get_parm (wholefile, "\nSQL_UTF8_EXECS:", 0);
  cli_no_system_tables = (long) (ptrlong) cfg_get_parm (wholefile, "\nSQL_NO_SYSTEM_TABLES:", 0);
  if (!cli_prefetch)
    cli_prefetch = 20;

  crashdump_start_dp = (dp_addr_t) (ptrlong) cfg_get_parm (wholefile, "\ncrashdump_start_dp:", 0);
  crashdump_end_dp = (dp_addr_t) (ptrlong) cfg_get_parm (wholefile, "\ncrashdump_end_dp:", 0);
  c_checkpoint_sync = (int) (ptrlong) cfg_get_parm (wholefile, "\ncheckpoint_sync_mode:", 0);
  c_use_o_direct = (int) (ptrlong) cfg_get_parm (wholefile, "\nuse_o_direct:", 0);
  c_use_aio = (int) (ptrlong) cfg_get_parm (wholefile, "\nuse_aio:", 0);
  COND_PARAM_WITH_DEFAULT("\nstripe_unit:", c_stripe_unit, 256);
  null_unspecified_params = (long) (ptrlong) cfg_get_parm(wholefile, "\nnull_unspecified_params:", 0);
  COND_PARAM("\ncase_mode:", case_mode);
  COND_PARAM("\ndo_os_calls:", do_os_calls);
  COND_PARAM("\nmax_static_cursor_rows:", max_static_cursor_rows);
  COND_PARAM("\ncheckpoint_audit_trail:", log_audit_trail);
  COND_PARAM_WITH_DEFAULT("\nmin_autocheckpoint_size:", min_checkpoint_size, MIN_CHECKPOINT_SIZE);
  COND_PARAM("\nautocheckpoint_log_size:", autocheckpoint_log_size);
  COND_PARAM("\nuse_daylight_saving:", isdts_mode);
  isdts_mode = (int) (ptrlong) cfg_get_parm (wholefile, "\nuse_daylight_saving:", 1);
  if (autocheckpoint_log_size > 0 && autocheckpoint_log_size < min_checkpoint_size)
    autocheckpoint_log_size = min_checkpoint_size + 1024;
  http_port = cfg_get_parm (wholefile, "\nhttp_port:", 1);
  if (NULL == (www_root = cfg_get_parm (wholefile, "\nhttp_root:", 1)))
    www_root = ".";
  http_threads = (int) (ptrlong) cfg_get_parm (wholefile, "\nhttp_threads:", 0);
  http_thread_sz = (int) (ptrlong) cfg_get_parm (wholefile, "\nhttp_thread_sz:", 0);
  dav_root = cfg_get_parm (wholefile, "\ndav_root:", 1);
  vsp_in_dav_enabled = (long) (ptrlong) cfg_get_parm (wholefile, "\nenabled_dav_vsp:", 0);
  http_proxy_enabled = (long) (ptrlong) cfg_get_parm (wholefile, "\nhttp_proxy_enabled:", 0);
  default_mail_server = cfg_get_parm (wholefile, "\ndefault_mail_server:", 1);
  init_trace = cfg_get_parm (wholefile, "\ntrace_on:", 1);
  allowed_dirs = cfg_get_parm (wholefile, "\ndirs_allowed:", 1);
  denied_dirs = cfg_get_parm (wholefile, "\ndirs_denied:", 1);
  if (!recover_file_prefix) /* when recovering backup_dirs is from command line */
    backup_dirs = cfg_get_parm (wholefile, "\nbackup_dirs:", 1);
  safe_execs = cfg_get_parm (wholefile, "\nsafe_executables:", 1);
  dba_execs = cfg_get_parm (wholefile, "\ndba_executables:", 1);
  default_charset_name = cfg_get_parm (wholefile, "\ncharset:", 1);

#ifdef _SSL
  https_port = cfg_get_parm (wholefile, "\nhttps_port:", 1);
  https_cert = cfg_get_parm (wholefile, "\nhttps_certificate:", 1);
  https_key = cfg_get_parm (wholefile, "\nhttps_private_key:", 1);

  c_ssl_server_port = cfg_get_parm (wholefile, "\nssl_server_port:", 1);
  c_ssl_server_cert = cfg_get_parm (wholefile, "\nssl_server_certificate:", 1);
  c_ssl_server_key = cfg_get_parm (wholefile, "\nssl_server_private_key:", 1);
#endif

#ifdef _IMSG
  pop3_port = (int) (ptrlong) cfg_get_parm (wholefile, "\npop3_port:", 0);
  nntp_port = (int) (ptrlong) cfg_get_parm (wholefile, "\nnews_port:", 0);
  ftp_port = (int) (ptrlong) cfg_get_parm (wholefile, "\nftp_port:", 0);
  ftp_server_timeout = (int) (ptrlong) cfg_get_parm (wholefile, "\nftp_port:", 600);
#endif

  enable_gzip = (int) (ptrlong) cfg_get_parm (wholefile, "\nEnabledGzipContent:", 0);

  if (http_threads < 1 && http_port)
    http_threads = 1;

  if (http_thread_sz < 140000)
    http_thread_sz = 140000;

  http_max_keep_alives =
    (int) (ptrlong) cfg_get_parm (wholefile, "\nhttp_max_keep_alives:", 0);

  if (http_max_keep_alives < 1)
    http_max_keep_alives = 10;

  http_keep_alive_timeout =
    (int) (ptrlong) cfg_get_parm (wholefile, "\nhttp_keep_alive_timeout:", 0);

  if (http_keep_alive_timeout < 1)
    http_keep_alive_timeout = 5;

  http_client_id_string = cfg_get_parm (wholefile, "\nhttp_client_id_string:", 0);
  if (!http_client_id_string || strlen (http_client_id_string) > 32)
    {
      http_client_id_string = "Mozilla/4.0 (compatible; Virtuoso)";
    }

  http_soap_client_id_string = cfg_get_parm (wholefile, "\nhttp_client_id_string:", 0);
  if (!http_soap_client_id_string || strlen (http_soap_client_id_string) > 32)
    {
      http_client_id_string = "OpenLink Virtuoso SOAP";
    }

  http_server_id_string = cfg_get_parm (wholefile, "\nhttp_server_id_string:", 0);
  if (!http_server_id_string || strlen (http_server_id_string) > 32)
    {
      http_server_id_string = "Virtuoso";
    }

  http_max_cached_proxy_connections =
    (int) (ptrlong) cfg_get_parm (wholefile,
			  "\nhttp_max_cached_proxy_connections:", 0);

  http_proxy_connection_cache_timeout =
    (int) (ptrlong) cfg_get_parm (wholefile,
			  "\nhttp_proxy_connection_cache_timeout:", 0);

  http_ses_trap =
    (int) (ptrlong) cfg_get_parm (wholefile,
			  "\nhttp_ses_trap:", 0);

  cfg_scheduler_period = 60000L * (int) (ptrlong) cfg_get_parm (wholefile, "\nscheduler_period:", 0);


  vt_batch_size_limit = (int) (ptrlong) cfg_get_parm (wholefile, "\nfree_text_batch:", 0);
  if (!vt_batch_size_limit )
    vt_batch_size_limit  = 1000000;
  vd_opt_arrayparams = (int) (ptrlong) cfg_get_parm (wholefile, "\nvd_array_params:", 0);;
  vd_param_batch = (int) (ptrlong) cfg_get_parm (wholefile, "\nvd_param_batch:", 0);;
  n_fds_per_file = (int) (ptrlong) cfg_get_parm (wholefile, "\nfds_per_file:", 0);
  if (!n_fds_per_file)
    n_fds_per_file = 1;

  txn_after_image_limit = (long) (ptrlong) cfg_get_parm (wholefile, "\ntxn_after_image_limit:", 0);
  if (!txn_after_image_limit)
    txn_after_image_limit = 50000000L;
  COND_PARAM_WITH_DEFAULT("\nmax_optimize_layouts:", sqlo_max_layouts, 1000);
  COND_PARAM_WITH_DEFAULT("\nstop_compiler_when_x_over_run:", sqlo_compiler_exceeds_run_factor, 0);
  COND_PARAM_WITH_DEFAULT("\nmax_optimize_memory:", sqlo_max_mp_size, 10000000);
  COND_PARAM_WITH_DEFAULT("\ntemp_allocation_pct:", helper, 30);
  wi_inst.wi_temp_allocation_pct = (short) helper;
  if (wi_inst.wi_temp_allocation_pct > 100)
    wi_inst.wi_temp_allocation_pct = 100;
  else if (wi_inst.wi_temp_allocation_pct < 0)
    wi_inst.wi_temp_allocation_pct = 30;

  COND_PARAM_WITH_DEFAULT("\ndefault_txn_isolation:", default_txn_isolation, ISO_REPEATABLE);
  COND_PARAM_WITH_DEFAULT("\nsql_compile_on_startup:", sql_proc_use_recompile, 1);
  COND_PARAM_WITH_DEFAULT("\nreqursive_ft_usage:", recursive_ft_usage, 1);
  COND_PARAM_WITH_DEFAULT("\nreqursive_trigger_calls:", recursive_trigger_calls, 1);
  COND_PARAM_WITH_DEFAULT("\nmem_hash_max:", hi_end_memcache_size, 100000);

  run_as_os_uname = cfg_get_parm (wholefile, "\nhttp_client_id_string:", 1);

  COND_PARAM_WITH_DEFAULT("\nauto_sql_stats:", dbe_auto_sql_stats, 0);
  COND_PARAM("\nlite_mode:", lite_mode);

  COND_PARAM("\nrdf_obj_ft_rules_size:", rdf_obj_ft_rules_size);
  if (rdf_obj_ft_rules_size < 10)
    rdf_obj_ft_rules_size = lite_mode ? 10 : 100;

  COND_PARAM("\nit_n_maps:", it_n_maps);
  if (it_n_maps < 2 || it_n_maps > 1024)
    {
      it_n_maps = lite_mode ? 8 : 256;
    }
  else if (0 != (it_n_maps % 2))
    {
      it_n_maps = 2 * (it_n_maps / 2);
    }

  srv_plugins_init();
  srv_client_defaults_init ();
}


caddr_t
dbs_log_derived_name (dbe_storage_t * dbs, char * ext)
{
  char *szExt, szNewName[255];
  int n, name_len;
  szExt = strrchr(dbs->dbs_log_name, '.');
  name_len = (int) (ptrlong) szExt ? (int) (ptrlong) (szExt - dbs->dbs_log_name)
      : (int) (ptrlong) strlen(dbs->dbs_log_name);

  if (name_len >= 14)
  {
    for (n = 0; n < 14; n++)
      if (!isdigit(dbs->dbs_log_name[name_len - n - 1]))
	break;
    if (n == 14)
      name_len -= 14;
  }

  if (name_len > 0)
    {
      strncpy(szNewName, dbs->dbs_log_name, name_len);
      szNewName[name_len] = 0;
    }
  else
    szNewName[0] = 0;
  strcat_ck(szNewName, ext);
  return box_dv_short_string (szNewName);
}


void
_dbs_read_cfg (dbe_storage_t * dbs, char *file)
{
  long max_cp = 0;
  /* int trx_bufs; */
  char *log_file;
  /* char * trx_file; */
  int read_stat, fd;
  char wholefile[6002 + 1];	/* Was 1000 */

  if (!file)
    file = "wi.cfg";

  fd = open (file, O_RDWR);
  if (fd < 0)
    {
    cfg_file_error:
      log_error ( "There must be a valid %s file in the server's working "
	  "directory. Exiting", CFG_FILE);
      exit (1);
    }

  memset (wholefile, 0, sizeof (wholefile));
  wholefile[0] = '\n';		/* Start it with newline so that all headers are found. */
  read_stat = read (fd, (wholefile + 1), (sizeof (wholefile) - 2));

  if (read_stat <= 0)
    {
      goto cfg_file_error;
    }
  if (read_stat >= (sizeof (wholefile) - 2))
    {
      /* Stupid static code, but better than silently ignoring something */
      /* important. */
      log_error ( "The configuration file %s in the server's working directory "
	  "is longer than %d bytes. Exiting",
	  CFG_FILE, (int) (sizeof (wholefile) - 3));
      exit (1);
    }
  fd_close (fd, NULL);

  dbs->dbs_file = cfg_get_parm (wholefile, "\ndatabase_file:", 1);
  log_file = cfg_get_parm (wholefile, "\nlog_file:", 1);
  if (log_file)
    {
      dbs->dbs_log_name = log_file;
      dbs->dbs_cpt_file_name = box_string (setext (log_file, "cpt", EXT_SET));
      if (CL_RUN_LOCAL != cl_run_local_only)
	dbs->dbs_2pc_file_name = dbs_log_derived_name (dbs, ".2pc");
    }

  file_extend = (long) (ptrlong) cfg_get_parm (wholefile, "\nfile_extend:", 0);
  if (file_extend < DP_INSERT_RESERVE + 1)
    file_extend = DP_INSERT_RESERVE + 1;
  dbs->dbs_extend = file_extend;
  max_cp = (long) (ptrlong) cfg_get_parm (wholefile, "\nmax_checkpoint_remap:", 0);
  dbs->dbs_max_cp_remaps = max_cp;

  cp_unremap_quota = (long) (ptrlong) cfg_get_parm (wholefile, "\nunremap_quota:", 0);
  if (!cp_unremap_quota)
    cp_unremap_quota = main_bufs / 3;
  else if (cp_unremap_quota < 500)
    cp_unremap_quota = 500;
  /* dbs->dbs_cp_unremap_quota = cp_unremap_quota; */

  cfg_parse_disks (dbs, NULL, 0, file);
  cfg_parse_backup_dirs();
}


char *
get_java_classpath (void)
{
  return java_classpath;
}

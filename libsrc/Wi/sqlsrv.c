/*
 *  sqlsrv.c
 *
 *  $Id$
 *
 *  SQL server functions
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

/*
   may 22, 97 - oui added this_trx_omly arg to cli_scrap_cursors.
   Case w/ 2 autocommitting cursors makes ending one close both although
   they're in different txm.

   may 21, 97 - oui err_printf as by AK fix 12
 */

#include "Dk.h"

#include "sqlnode.h"
#include "eqlcomp.h"
#include "security.h"
#include "wirpce.h"
#include "list2.h"
#include "sqlbif.h"
#include "sqlver.h"
#include "odbcinc.h"
#include "sqlfn.h"
#include "datesupp.h"
#include "multibyte.h"
#include "srvmultibyte.h"
#include "bif_text.h"
#include "statuslog.h"
#include "xml.h"
#include "xmlnode.h"
#include "sqltype.h"
#include "wi.h"
#include "recovery.h"
#include "shcompo.h"
#include "shuric.h"
#include "srvstat.h"
#include "sqloinv.h"
#include "uname_const_decl.h"

#ifdef WIN32
#include <windows.h>
#define HAVE_DIRECT_H
#endif

#ifdef HAVE_DIRECT_H
#include <direct.h>
#include <io.h>
#define mkdir(p,m)	_mkdir (p)
#define FS_DIR_MODE	0
#define PATH_MAX	 MAX_PATH
#define get_cwd(p,l)	_get_cwd (p,l)
#else
#include <dirent.h>
#define FS_DIR_MODE	 (S_IRWXU | S_IRWXG)
#endif

int mode_pass_change;

int in_srv_global_init = 0;

int it_n_maps = 256;
int rdf_obj_ft_rules_size;
extern int disable_listen_on_tcp_sock;
#ifdef VIRTTP
#include "2pc.h"
#endif

#define SERIAL_CLI

#ifdef SERIAL_CLI

#define CLI_WRAPPER(f, p, p1) \
caddr_t f##_w p \
{ \
  dk_session_t * ses = IMMEDIATE_CLIENT; \
  client_connection_t * cli; \
  cli = DKS_DB_DATA (ses); \
  if (!cli) \
    { \
      log_error ("SQL client operation on a connection which was not logged in.\n"); \
      ses->dks_to_close = 1; \
      return NULL; \
    } \
  CLI_ENTER; \
  f p1; \
  CLI_LEAVE; \
  return NULL; \
}

# ifdef INPROCESS_CLIENT

#  define CLI_ENTER \
  if (!cli->cli_inprocess) \
    {mutex_enter (cli->cli_test_mtx); cli->cli_cl_start_ts = rdtsc (); }

#  define CLI_LEAVE \
  if (!cli->cli_inprocess) \
    { CLI_THREAD_TIME (cli); mutex_leave (cli->cli_test_mtx); }

# else

#  define CLI_ENTER \
  mutex_enter (cli->cli_test_mtx);

#  define CLI_LEAVE \
  mutex_leave (cli->cli_test_mtx);

# endif

#endif

#if 0
#define _2pc_printf(x) log_info x
#define dbg_printf(x) log_info x
#define rdbg_printf(x) log_info x
#endif

/*
   Global variables
 */

du_thread_t *the_main_thread = NULL;
semaphore_t *background_sem = NULL;
int main_thread_ready = 0; /* true if main thread is waiting for wakeup for cpt or schedule round. */
dk_mutex_t * db_schema_mtx;

unsigned long log_stat = 0;

void cli_clear_globals (client_connection_t * cli);

#if 0
caddr_t
n_srv_make_error (const char* code, size_t buf_len, const char *msg, ...)
{
  size_t _n;
  va_list list;
  char* temp;
  caddr_t *box = (caddr_t *)
    dk_alloc_box (3 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  box[0] = (caddr_t) QA_ERROR;
  box[1] = box_dv_short_string (code);

  temp = (char *) dk_alloc (buf_len);

  va_start (list, msg);
  vsnprintf (temp, buf_len, msg, list);
  va_end (list);

  _n = strlen (temp);

  box[2] = dk_alloc_box (_n + 1, DV_LONG_STRING);
  memcpy (box[2], temp, _n);
  box[2][_n] = 0;
  dk_free (temp, buf_len);
  return (caddr_t)box;
}

caddr_t
n_srv_make_new_error (const char *code, const char *virt_code, size_t buf_len, const char *msg, ...)
{
  char *temp = (char *) dk_alloc (buf_len);
  va_list list;
#ifndef NDEBUG
  FILE *err_log;
#endif
  int msg_len;
  int code_len = virt_code ? (int) (ptrlong) strlen (virt_code) : 0;

  caddr_t *box = (caddr_t *) dk_alloc_box (3 * sizeof (caddr_t),
      DV_ARRAY_OF_POINTER);
  box[0] = (caddr_t) QA_ERROR;
  box[1] = box_dv_short_string (code);

  va_start (list, msg);
  vsnprintf (temp, buf_len, msg, list);
  va_end (list);
  msg_len = (int) (ptrlong) strlen (temp);
  if (virt_code)
    {
      box[2] = dk_alloc_box (msg_len + code_len + 3, DV_SHORT_STRING);
      memcpy (box[2], virt_code, code_len);
      memcpy (box[2] + code_len, ": ", 2);
      memcpy (box[2] + code_len + 2, temp, msg_len);
      box[2][code_len+msg_len+2] = 0;
    }
  else
    box[2] = box_dv_short_string (temp);
#ifndef NDEBUG
  err_log = fopen("srv_errors.txt","at");
  if (NULL != err_log)
    {
      fprintf (err_log, "%s | %s\n", box[1], box[2]);
      fclose (err_log);
    }
#endif

  if (DO_LOG(LOG_SRV_ERROR))
    {
      log_info ("ERRS_0 %s %.*s", box[1], LOG_PRINT_STR_L, box[2]);
    }

  dk_free (temp, buf_len);

  return ((caddr_t) box);
}
#endif


#ifdef WIN32
int change_thread_user (user_t * user)
{
  du_thread_t * self = THREAD_CURRENT_THREAD;
  PHANDLE old_thr_token = self->thr_sec_token;
  PHANDLE user_token = (user->usr_sec_token ? user->usr_sec_token : server_imp_token);

  if (old_thr_token != user_token)
    {

      if (!SetThreadToken (NULL, user_token))
	{
	  LPVOID lpMsgBuf;
	  FormatMessage (FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
	      NULL, GetLastError(), MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),(LPTSTR) &lpMsgBuf, 0, NULL);
	  srv_make_new_error ("22000", "SR377", "Can't Set Thread Token %s", lpMsgBuf);
	  return 0;
	}
#if 0
      else
	log_info ("The thread (%li) owner is changed to %s.", THREAD_CURRENT_THREAD, user->usr_name);
#endif

      self->thr_sec_token = user_token;
    }

  return 1;
}

int init_os_users (user_t * user, caddr_t u_sys_name, caddr_t u_sys_pwd)
{
  HANDLE token;

  user->usr_sec_token = server_imp_token;

  if (!user || !u_sys_name || !u_sys_pwd)
    return 0;

  if (!LogonUser (u_sys_name, "localhost", u_sys_pwd,
	LOGON32_LOGON_NETWORK, LOGON32_PROVIDER_DEFAULT, &token))
    {
      LPVOID lpMsgBuf;
      FormatMessage (FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
	  	     NULL, GetLastError(), MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),(LPTSTR) &lpMsgBuf, 0, NULL);
      if (!in_srv_global_init)
	log_info ("Can't login system user %s. %s", u_sys_name, lpMsgBuf);

      return 0;
    }

  user->usr_sec_token = token;

  return 1;
}

int check_os_user (caddr_t u_sys_name, caddr_t u_sys_pwd)
{
  HANDLE token = NULL;

  if (!LogonUser (u_sys_name, "localhost", u_sys_pwd,
	LOGON32_LOGON_NETWORK, LOGON32_PROVIDER_DEFAULT, &token))
    {
      LPVOID lpMsgBuf;
      FormatMessage (FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
	  	     NULL, GetLastError(), MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),(LPTSTR) &lpMsgBuf, 0, NULL);
      log_info ("Can't login system user %s. %s", u_sys_name, lpMsgBuf);

      return 0;
    }

  return 1;
}
#endif


void
lt_wait_until_alone (lock_trx_t * lt)
{
  while (lt->lt_threads > 1)
    {
      GPF_T1 ("Invalid lt_threads count on lt");
    }
}


int
#ifdef CHECK_LT_THREADS
lt_leave_real (lock_trx_t * lt)
#else
lt_leave (lock_trx_t * lt)
#endif
{
  int rc = lt->lt_error;
  ASSERT_IN_TXN;
#ifdef INPROCESS_CLIENT
  if (IS_INPROCESS_CLIENT (lt->lt_client))
    return lt->lt_error;
#endif
#if 0
  /* the below assertion is incorrect because a txn can be in a queue after cursors that wait
   * in non-acquiring mode and hence never hold the lock. Wait edges remaining from such waits can exist to live transactions from a running transaction */
  DO_SET (lock_trx_t *, wait, &lt->lt_waits_for)
    {
      if (wait->lt_status != LT_CLOSING)
	GPF_T1 ("single thread txn leaving while this txn waiting for live txns");
    }
  END_DO_SET();
#endif
  CHECK_DK_MEM_RESERVE (lt);
  if (LT_FREEZE == lt->lt_status)
    {
      rdbg_printf (("Trx T=%ld Freeze ack in lt_leave\n", TRX_NO (lt)));
      lt_ack_freeze_inner (lt);
      rc = LTE_OK;
    }
  else if (LT_BLOWN_OFF_C == lt->lt_status
      || LT_CLOSING == lt->lt_status
      || LT_COMMITTED == lt->lt_status
#ifdef VIRTTP
      || LT_PREPARE_PENDING == lt->lt_status
#endif
    )
    {
      rdbg_printf (("Trx T=%ld close ack in lt_leave\n", TRX_NO (lt)));
      lt_ack_close (lt);
    }

  ASSERT_IN_TXN;
  lt_threads_dec_inner (lt);
  return rc;
}


int
lt_close (lock_trx_t * lt, int fcommit)
{
  int rc;
  ASSERT_OUTSIDE_MTX (lt->lt_client->cli_mtx);
  ASSERT_IN_TXN;
  lt_threads_set_inner (lt, 1);
  if (SQL_COMMIT == fcommit)
    rc = lt_commit (lt, TRX_CONT_LT_LEAVE);
  else
    {
      rc = lt->lt_error;
      lt_rollback (lt, TRX_CONT_LT_LEAVE);
    }
  return rc;
}


void
cli_scrap_cursors (client_connection_t * cli, query_instance_t * exceptions,
    lock_trx_t * this_trx_only)
{
  /* Kill cursors of this client except the one <except.
   * If this_trx_only is non-NULL, only kill cursors of that transaction */
  int rc;
  id_hash_iterator_t it;
  char *k;
  char **kp;
  query_instance_t *qi;
  query_instance_t **qip;
  for (;;)
    {
      mutex_enter (cli->cli_mtx);
      id_hash_iterator (&it, cli->cli_cursors);
      qi = 0;
      while (hit_next (&it, (char **) &kp, (char **) &qip))
	{
	  qi = *qip;
	  k = *kp;
	  if (qi != exceptions)
	    {
	      if (!this_trx_only)
		break;
	      if (qi->qi_trx == this_trx_only)
		break;
	    }
	  qi = NULL;
	}
      if (qi)
	{
	  ASSERT_IN_MTX (cli->cli_mtx);
	  rc = id_hash_remove (cli->cli_cursors, (caddr_t) kp);
	  IN_TXN;
          lt_threads_set_inner (qi->qi_trx, 1);
	  LEAVE_TXN;
	  qi_enter (qi);
	  dbg_cli_printf (("cli_scrap_cursors - killing %s %d\n", *kp, rc));
	  mutex_leave (cli->cli_mtx);
	  qi_kill (qi, QI_ERROR);
	}
      else
	{
	  mutex_leave (cli->cli_mtx);
	  return;
	}
    }
}

client_connection_t *
client_connection_create (void)
{
  NEW_VARZ (client_connection_t, cli);
  cli->cli_statements = id_str_hash_create (31);
  cli->cli_cursors = id_str_hash_create (13);
  cli->cli_mtx = mutex_allocate ();
  cli->cli_text_to_query = id_str_hash_create (301);
  if (wi_inst.wi_master)
    cli->cli_replicate =
      wi_inst.wi_master->dbs_log_name ? REPL_LOG : REPL_NO_LOG;
  else
    cli->cli_replicate = REPL_NO_LOG;
  cli->cli_qualifier = box_string ("DB");
#ifdef SERIAL_CLI
  cli->cli_test_mtx = mutex_allocate ();
#endif
  cli->cli_not_char_c_escape = 0;
  cli->cli_utf8_execs = 0;
  cli->cli_no_system_tables = 0;
  cli->cli_globals = id_str_hash_create (11);
  id_hash_set_rehash_pct (cli->cli_globals, 300);
  cli->cli_charset = default_charset;
  /*cli->cli_sqlo_enable = sqlo_enable;*/
#ifdef PLDBG
  cli->cli_pldbg = (pldbg_t *) dk_alloc (sizeof (pldbg_t));
  memset (cli->cli_pldbg, 0, sizeof (pldbg_t));
  cli->cli_pldbg->pd_sem = semaphore_allocate (0);
#endif
  cli->cli_user_info = NULL;
  cli->cli_slice = QI_NO_SLICE;
  return cli;
}


void
cli_scrap_cached_statements (client_connection_t * cli)
{
  query_t **qr;
  caddr_t *text;
  id_hash_iterator_t it;
  srv_stmt_t **stmt;

  if (client_trace_flag)
    logit (L_DEBUG, "stmt trace:");

  id_hash_iterator (&it, cli->cli_statements);
  IN_CLIENT (cli);
  while (hit_next (&it, (caddr_t *) & text, (caddr_t *) & stmt))
    {
      srv_stmt_t * sst = *stmt;
      if (sst->sst_query)
	{
	  IN_CLL;
	  if (!sst->sst_query->qr_ref_count)
	    log_error ("Suspect to have query assigned to stmt but 0 ref count on query");
	  else
	    sst->sst_query->qr_ref_count--;
	  LEAVE_CLL;
	}
      if (client_trace_flag)
       {
	 if (79 < box_length (*text))
	   (* text)[79] = 0;
	 logit (L_DEBUG, "%s", *text);
       }

      if ((*stmt)->sst_cursor_state)
	stmt_scroll_close (*stmt);
      dk_free_box (*text);
      dk_free ((caddr_t) (*stmt), sizeof (srv_stmt_t));
    }
  LEAVE_CLIENT (cli);

  id_hash_iterator (&it, cli->cli_text_to_query);
  while (hit_next (&it, (caddr_t *) & text, (caddr_t *) & qr))
    {

      if (client_trace_flag)
       {
	 if (79 < box_length(*text))
	   (* text)[79] = 0;
	 logit (L_DEBUG, "%s", *text);
       }

      qr_free (*qr);

    }
}

lock_trx_t *
cli_set_new_trx (client_connection_t *cli)
{
  if (!cli->cli_trx)
    cli_set_trx (cli, lt_start ());
  else
    cli_set_trx (cli, cli->cli_trx);
  return cli->cli_trx;
}

void
cli_set_trx (client_connection_t * cli, lock_trx_t * trx)
{
  ASSERT_IN_TXN;
#ifndef NDEBUG
  if (cli == NULL)
    GPF_T1 ("No client in cli_set_trx");
  if (trx == NULL)
    GPF_T1 ("No trx in cli_set_trx");
#endif
  if (cli->cli_trx && cli->cli_trx != trx)
    {
      GPF_T1 ("cli_trx in cli_set_trx");
      LT_THREADS_REPORT(cli->cli_trx, "LT_COMMIT/RESOURCE_STORE");
      lt_done (cli->cli_trx);
    }

  cli->cli_trx = trx;
  trx->lt_client = cli;
  trx->lt_replicate = (caddr_t *) box_copy_tree ((caddr_t) cli->cli_replicate);
   if (DO_LOG(LOG_TRANSACT))
     {
       LOG_GET;
       log_info ("LTRS_0 %s %s %s Begin transact %p", user, from, peer, trx);
     }
}


static client_connection_reset_hook_type client_connection_reset_hook = NULL;

client_connection_reset_hook_type
client_connection_set_reset_hook (client_connection_reset_hook_type new_hook)
{
  client_connection_reset_hook_type old_hook = client_connection_reset_hook;
  client_connection_reset_hook = new_hook;
  return old_hook;
}

void
client_connection_set_worker_ses (client_connection_t *cli, dk_session_t *ses)
{
  cli->cli_outp_worker = ses;
}

void
client_connection_free (client_connection_t * cli)
{
  if (DO_LOG_INT(LOG_VUSER))
    {
      LOG_GET
#if 0
      if (cli->cli_saved_user)
	log_info ("USER_0 %li (%li) logout from %s", cli->cli_user->usr_id,
	    cli->cli_saved_user->usr_id, from);
      else
#endif
	if (cli->cli_user)
	  log_info ("USER_0 %s %s %s logout", user, from, peer);
    }

  if (cli->cli_tp_data)
    {
      lt_log_debug (("client_connection_free cli=%p type=%d, enlisted=%d lt=%p: deferred",
	  cli, cli->cli_tp_data->cli_trx_type, cli->cli_tp_data->cli_tp_enlisted, cli->cli_trx));
#ifndef NDEBUG
      if (cli->cli_tp_data->cli_tp_enlisted)
	GPF_T1 ("enlisted cli in client_connection_free");
#endif
      tp_data_free (cli->cli_tp_data);
      cli->cli_tp_data = NULL;
    }
#ifdef MSDTC_DEBUG
  else
    log_info ("client_connection_free %p\n", cli);
#endif
  if (client_trace_flag)
    {
      logit (L_DEBUG, "Post_mortem for client: version %d:", cli->cli_version);
      logit (L_DEBUG, "text trace:");
    }

  cli_scrap_cursors (cli, NULL, NULL);
  hosting_clear_cli_attachments (cli, 1);
  cli_scrap_cached_statements (cli);

  id_hash_free (cli->cli_text_to_query);
  id_hash_free (cli->cli_statements);
  id_hash_free (cli->cli_cursors);
  cli_clear_globals (cli);
  mutex_free (cli->cli_mtx);
#ifdef PLDBG
  if (cli->cli_pldbg) /* if it's debugged session */
    {
      if (cli->cli_pldbg->pd_session)
	DKS_DB_DATA (cli->cli_pldbg->pd_session) = NULL;
      semaphore_free (cli->cli_pldbg->pd_sem);
      dk_free_box (cli->cli_pldbg->pd_id);
      dk_free (cli->cli_pldbg, sizeof (pldbg_t));
    }
#endif
  /* !!! dk_free_box (cli->cli_qualifier); */
#ifdef SERIAL_CLI
  mutex_free (cli->cli_test_mtx);
#endif
  dk_free_box (cli->cli_qualifier);
  dk_free_box (cli->cli_user_info);
  dk_free_box (cli->cli_identity_value);
  if (client_connection_reset_hook)
    cli->cli_outp_worker = client_connection_reset_hook (cli->cli_outp_worker);
  if (cli->cli_outp_worker)
    {
      PrpcDisconnect (cli->cli_outp_worker);
      PrpcSessionFree (cli->cli_outp_worker);
    }
#if 0
  IN_TXN;
  if (cli->cli_trx)
    {
      lock_trx_t *lt = cli->cli_trx;
      cli->cli_trx = NULL;
      LT_THREADS_REPORT(lt, "LT_COMMIT/RESOURCE_STORE");
      lt_done (lt);
    }
  LEAVE_TXN;
#endif
  dk_free_tree (cli->cli_info);
  if (NULL != cli->cli_ns_2dict)
    {
      xml_ns_2dict_clean (cli->cli_ns_2dict);
      dk_free (cli->cli_ns_2dict, sizeof (xml_ns_2dict_t));
      cli->cli_ns_2dict = NULL;
    }
  dk_free_box ((caddr_t)cli->cli_ql_strses);
  dk_free ((caddr_t) cli, sizeof (client_connection_t));
}


void
client_connection_reset (client_connection_t * cli)
{
  thread_t *self = THREAD_CURRENT_THREAD;
  sql_warnings_clear ();
  thr_set_error_code (self, NULL);

  cli->cli_charset = default_charset;
  if (cli->cli_qualifier && strcmp (cli->cli_qualifier, "DB"))
    {
      dk_free_tree (cli->cli_qualifier);
      cli->cli_qualifier = box_string ("DB");
    }
  cli->cli_user = NULL;
  cli->cli_no_triggers = 0;
  cli->cli_not_char_c_escape = 0;
  cli->cli_utf8_execs = 0;
  cli->cli_no_system_tables = 0;
  cli->cli_start_time = 0;
  cli->cli_terminate_requested = 0;
  if (client_connection_reset_hook)
    cli->cli_outp_worker = client_connection_reset_hook (cli->cli_outp_worker);
  if (cli->cli_outp_worker)
    {
      PrpcDisconnect (cli->cli_outp_worker);
      PrpcSessionFree (cli->cli_outp_worker);
      cli->cli_outp_worker = NULL;
    }
  if (NULL != cli->cli_ns_2dict)
    {
      xml_ns_2dict_clean (cli->cli_ns_2dict);
      dk_free (cli->cli_ns_2dict, sizeof (xml_ns_2dict_t));
      cli->cli_ns_2dict = NULL;
    }
}


void
itc_flush_client (it_cursor_t * itc)
{
  client_connection_t *cli;
  if (itc->itc_ltrx && itc->itc_ltrx->lt_client)
    {
      cli = itc->itc_ltrx->lt_client;
      if (cli_is_interactive (cli)
	  && !cli->cli_ws
	  && cli->cli_session
	  && (!cli->cli_tp_data || !cli->cli_tp_data->cli_free_after_unenlist))
	/* cli can be inside server, e.g. bootstrap or repl cli, w/ no session */
	session_flush (cli->cli_session);
    }
}


long dbev_enable = 1;

void
dbev_disconnect (client_connection_t * cli)
{
  caddr_t err;
  caddr_t * params;
  query_t * proc;
  if (!dbev_enable)
    return;
  proc = sch_proc_exact_def (wi_inst.wi_schema, "DB.DBA.DBEV_DISCONNECT");
  if (!proc)
    return;
  if (proc->qr_to_recompile)
    proc = qr_recompile (proc, NULL);
  params = (caddr_t *) list (0);
  lt_enter_anyway (cli->cli_trx);
  err = qr_exec (cli, proc, CALLER_LOCAL, NULL, NULL, NULL,
		 params, NULL, 0);
  dk_free_box ((caddr_t) params);
  IN_TXN;
  lt_commit (cli->cli_trx, TRX_CONT);
  lt_leave (cli->cli_trx);
  LEAVE_TXN;
  if (IS_BOX_POINTER (err))
    log_error ("Error in DBEV_DISCONNECT: %s %s", ERR_STATE (err), ERR_MESSAGE (err));
}


void
cli_clear_globals (client_connection_t * cli)
{
  id_hash_iterator_t it;
  caddr_t * k;
  caddr_t * d;
  if (!cli->cli_globals)
    return;
  id_hash_iterator (&it, cli->cli_globals);
  while (hit_next (&it, (caddr_t *) &k, (caddr_t *) &d))
    {
      dk_free_tree (*d);
      dk_free_tree (*k);
    }
  id_hash_free (cli->cli_globals);
}


void
cli_set_default_qual (client_connection_t * cli)
{
  user_t *usr = cli->cli_user;
  if (usr->usr_data)
    {
      char *loc = strstr (usr->usr_data, "Q ");
      if (loc)
	{
	  int len;
	  LOG_GET;
	  len = strlen (loc + 2);
	  if (len < MAX_NAME_LEN)
	    cli->cli_qualifier = box_dv_short_string (loc + 2);
	  else
	    log_error ("Client from %s is trying to set invalid qualifier of length=%d", from, len);
	}
    }
}


long srv_connect_ctr = 0;
long srv_max_clients;

static dk_mutex_t *logins_mutex = NULL;
static dk_hash_t *logins_hash = NULL;

static void
logins_list_initialize (void)
{
  logins_mutex = mutex_allocate ();
  logins_hash = hash_table_allocate (50);
}


static void
srv_delete_login (client_connection_t *cli)
{
#ifndef NDEBUG
  volatile int res;
#endif
  mutex_enter (logins_mutex);
#ifndef NDEBUG
  res =
#endif
      remhash (cli, logins_hash);
  mutex_leave (logins_mutex);
#ifndef NDEBUG
  if (!res)
    GPF_T1 ("removing logon that is not in the list");
#endif
}


static void
srv_add_login (client_connection_t *cli)
{
  uint32 nlogons;

  mutex_enter (logins_mutex);
#ifndef NDEBUG
  if (gethash (cli, logins_hash))
    GPF_T1 ("adding a logon twice");
#endif
  sethash (cli, logins_hash, cli);
  srv_connect_ctr++;
  nlogons = logins_hash->ht_count;
  if ((long) nlogons > srv_max_clients)
    srv_max_clients = nlogons;
  mutex_leave (logins_mutex);
}


uint32
srv_get_n_logons ()
{
  uint32 res;
  mutex_enter (logins_mutex);
  res = logins_hash->ht_count;
  mutex_leave (logins_mutex);
  return res;
}


dk_set_t
srv_get_logons ()
{
  dk_set_t res = NULL;
  client_connection_t *p_cli, *p_cli2;
  dk_hash_iterator_t hit;

  mutex_enter (logins_mutex);
  dk_hash_iterator (&hit, logins_hash);
  while (dk_hit_next (&hit, (void **) &p_cli, (void **) &p_cli2))
    {
      dk_set_push (&res, p_cli->cli_session);
    }
  mutex_leave (logins_mutex);
  return res;
}


void
srv_client_connection_died (client_connection_t *cli)
{
  lock_trx_t *lt;

  if (!cli)
    return;

  IN_TXN;
  lt = cli->cli_trx;
  if (cli->cli_tp_data)
    {
      if (lt && lt->lt_2pc._2pc_type != cli->cli_tp_data->cli_trx_type)
        {
	  lt_log_debug (("srv_client_connection_died diff trx_type cli=%p cli_trx_type=%d, 2pc_type=%d, enlisted=%d",
	    cli, cli->cli_tp_data->cli_trx_type,
	    lt->lt_2pc._2pc_type,
	    cli->cli_tp_data->cli_tp_enlisted));
	}

      lt_log_debug (("srv_client_connection_died no lt cli=%p type=%d, enlisted=%d",
	  cli, cli->cli_tp_data->cli_trx_type,
	  cli->cli_tp_data->cli_tp_enlisted));

      /* xa or mts transaction is prepared, keep it live */
      if ((cli->cli_tp_data->cli_trx_type == TP_XA_TYPE && lt->lt_2pc._2pc_wait_commit) ||
	  (cli->cli_tp_data->cli_trx_type == TP_MTS_TYPE && cli->cli_tp_data->cli_tp_enlisted == CONNECTION_PREPARED))
	{
	  lt_log_debug (("srv_client_connection_died %p enlisted=%d : deferred", cli, cli->cli_tp_data->cli_tp_enlisted));
	  if (!cli->cli_tp_data->cli_free_after_unenlist)
	    cli->cli_tp_data->cli_free_after_unenlist = CFAU_DIED;
	  cli->cli_session = NULL;
	  LEAVE_TXN;
	  return;
	}
      /* client connection died before prepare, remove xid */
      if (cli->cli_tp_data->cli_trx_type == TP_XA_TYPE && !lt->lt_2pc._2pc_wait_commit)
	{
	  tp_data_free (cli->cli_tp_data);
	  cli->cli_tp_data = NULL;
	  virt_xa_remove_xid (lt->lt_2pc._2pc_xid);
	}
      lt_log_debug (("srv_client_connection_died cli=%p : done", cli));
    }
#ifdef MSDTC_DEBUG
  else
    lt_log_debug (("srv_client_connection_died cli=%p", cli));
#endif
  LEAVE_TXN;

  dbev_disconnect (cli);
  if (lt)
    {
      IN_TXN;
      lt_threads_set_inner (lt, 1);
      lt->lt_status = LT_BLOWN_OFF;
      lt_wait_until_alone (lt);
      lt_rollback (cli->cli_trx, TRX_CONT);
      LEAVE_TXN;
    }
  cli->cli_trx = NULL;
  srv_delete_login (cli);
  client_connection_free (cli);
  IN_TXN;
  if (lt)
    {
      lt->lt_threads = 1;
      LT_THREADS_REPORT(lt, "set to 1");
      LT_ENTER_SAVE (lt);
      lt_log_debug (("src_client_connection_died : lt_client=NULL lt=%p", lt));
      lt->lt_client = NULL; /* cli already is free */
      lt_resume_waiting_end (lt);
      lt_leave (lt);
#ifdef CHECK_LT_THREADS
      if (lt->lt_wait_end)
	GPF_T1 ("resource store with threads");
#endif
      LT_THREADS_REPORT(lt, "SRV_CLIENT_CONNECTION_DIED/RESOURCE_STORE");
      lt_done (lt);
    }
  LEAVE_TXN;
}


void
srv_client_session_died (dk_session_t * ses)
{
  client_connection_t *cli = DKS_DB_DATA (ses);

  srv_client_connection_died (cli);

  DKS_DB_DATA (ses) = NULL;
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_IMMEDIATE_CLIENT, NULL);
}


void
dbev_connect (client_connection_t * cli)
{
  caddr_t err;
  /*DELME: stmt_options_t * opts; */
  caddr_t * params;
  query_t * proc;
  if (!dbev_enable)
    return;
  proc = sch_proc_exact_def (wi_inst.wi_schema, "DB.DBA.DBEV_CONNECT");
  if (!proc)
    return;
  if (proc->qr_to_recompile)
    proc = qr_recompile (proc, NULL);
  params = (caddr_t *) list (0);
  lt_enter_anyway (cli->cli_trx);
  err = qr_exec (cli, proc, CALLER_LOCAL, NULL, NULL, NULL,
		 params, NULL, 0);
  dk_free_box ((caddr_t) params);
  IN_TXN;
  lt_commit (cli->cli_trx, TRX_CONT);
  lt_leave (cli->cli_trx);
  LEAVE_TXN;
  if (IS_BOX_POINTER (err))
    {
      PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, FINAL, 1);
      dk_free_tree (err);
      PrpcDisconnect (cli->cli_session);
    }
}

caddr_t *
make_login_answer (client_connection_t *cli)
{
  caddr_t *ret = (caddr_t *) dk_alloc_box (QA_LOGIN_FIELDS * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  ret[0] = (caddr_t) QA_LOGIN;
  ret[LG_QUALIFIER] = box_string (cli->cli_qualifier);
  ret[LG_DB_VER] = box_string (DBMS_SRV_VER);
  ret[LG_DB_CASEMODE] = box_num (case_mode);
  ret[LG_DEFAULTS] = srv_client_defaults ();
  ret[LG_CHARSET] = !cli->cli_charset ?
      box_num (0) :
      list (2,
	  box_string (cli->cli_charset->chrs_name),
	  box_wide_char_string ( (caddr_t) &(cli->cli_charset->chrs_table[1]),
	    sizeof (cli->cli_charset->chrs_table) - sizeof (wchar_t), DV_WIDE));
  return ret;
}

int
virtuoso_server_initialized = 0; /* DBMS online */
int prpc_forced_fixed_thread = 0;

caddr_t *
sf_sql_connect (char *username, char *password, char *cli_ver, caddr_t *info)
{
  caddr_t *ret;
  dk_session_t *client = IMMEDIATE_CLIENT;
  client_connection_t *cli;
  user_t *user = NULL;
  int to_shutdown;
  int res;

#ifdef INPROCESS_CLIENT
  if (SESSION_IS_INPROCESS (client))
    {
      cli = DKS_DB_DATA (client);
      return make_login_answer (cli);
    }
#endif

  while (!virtuoso_server_initialized)
    { /* suspend thread right here if the server isn't up */
      virtuoso_sleep (0, 100);
    }
  if (failed_login_to_disconnect (client))
    {
      dk_free_box (cli_ver);
      thrs_printf ((thrs_fo, "ses %p thr:%p in connect3\n", client, THREAD_CURRENT_THREAD));
      DKST_RPC_DONE (client);
      PrpcDisconnect (client);
      return 0;
    }

  /* check if the client is of the right version */
  if (cli_ver && ODBC_DRV_VER_G_NO (cli_ver) < 2303) /* was 3104 */
    {
      if (cli_ver && ODBC_DRV_VER_G_NO (cli_ver) >= 1619)
	{
	  caddr_t err = srv_make_new_error ("08004", "SR451",
	      "Not allowed to connect using client versions older than 2303");
	  PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, FINAL, 1);
	  dk_free_tree (err);
	}
      else
	PrpcAddAnswer ((caddr_t) 0, DV_ARRAY_OF_POINTER, FINAL, 1);
      dk_free_box (cli_ver);

      thrs_printf ((thrs_fo, "ses %p thr:%p in connect1\n", client, THREAD_CURRENT_THREAD));
      DKST_RPC_DONE (client);
      log_error ("Refused connection to an old client (pre 2303)");
      return 0;
    }

  if (lockdown_mode &&
      (!dks_is_localhost (client) || srv_get_n_logons () > 0))
    {
      caddr_t err = srv_make_new_error ("08004", "SR462",
	  "The server is in maintenance mode. Please try again later");
      PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, FINAL, 1);
      dk_free_tree (err);
      DKST_RPC_DONE (client);
      return 0;
    }

  if (!username)
    username = box_dv_short_string ("");
  if (!password)
    password = box_dv_short_string ("");

  cli = client_connection_create ();
  if (info)
    {
      cli->cli_user_info = box_dv_short_string (info[LGID_APP_NAME]);
      cli->cli_info = box_copy_tree (info);
    }
  DKS_DB_DATA (client) = cli;
  cli->cli_session = client;

  res = sec_call_login_hook (&username, password, client, cli);
  if (res != PLLH_INVALID)
    {
      if (res == PLLH_NO_AUTH)
	user = sec_check_login (username, password, client);
      else
	{
	  user = sec_name_to_user (username);
	  if (!user)
	    sec_log_login_failed (username, client, 1);
	}
    }
  else
    sec_log_login_failed (username, client, 1);
  if (user)
    failed_login_remove (client);
  to_shutdown = info && BOX_ELEMENTS (info) > LGID_SHUTDOWN ? (int) unbox (info[LGID_SHUTDOWN]) : 0;

  dk_free_box (username);
  dk_free_box (password);

  CHANGE_THREAD_USER(user);

  if (to_shutdown)
    {
      caddr_t err;
      client_connection_free (cli);
      DKS_DB_DATA (client) = NULL;
      dk_free_box (cli_ver);
      if (!user || !sec_user_has_group (0, user->usr_g_id))
	{
	  if (!user)
	    err = srv_make_new_error ("28000", "SR311",
		"Bad login");
	  else
	    err = srv_make_new_error ("08004", "SR311",
		"Shutting down the server permitted only to DBA group");
	  DKST_RPC_DONE (client);
	  PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, FINAL, 1);
	  dk_free_tree (err);
	  PrpcDisconnect (client);
	  return 0;
	}
      err = srv_make_new_error ("VIRTS", "SR312", "The server is shutting down");
      thrs_printf ((thrs_fo, "ses %p thr:%p in connect4\n", client, THREAD_CURRENT_THREAD));
      DKST_RPC_DONE (client);
      PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, FINAL, 1);
      dk_free_tree (err);
      sf_shutdown (sf_make_new_log_name (wi_inst.wi_master), NULL);
      return 0;
    }


  if (user)
    {
      if (!info && !sec_check_info (user, NULL, 0, NULL, NULL))
	user = NULL;
      else if (info && !sec_check_info (user, info[LGID_APP_NAME],
	      (long) unbox (info[LGID_PID]), info[LGID_MACHINE], info[LGID_OS]))
	{
	  thrs_printf ((thrs_fo, "ses %p thr:%p in connect5\n", client, THREAD_CURRENT_THREAD));
	  DKST_RPC_DONE (client);
	  if (cli_ver && ODBC_DRV_VER_G_NO (cli_ver) >= 1619)
	    {
	      caddr_t err = srv_make_new_error ("08004", "LI101",
		  "Application access not licensed");
	      PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, FINAL, 1);
	      dk_free_tree (err);
	    }
	  else
	    PrpcAddAnswer ((caddr_t) 0, DV_ARRAY_OF_POINTER, FINAL, 1);
	  dk_free_box (cli_ver);
	  PrpcDisconnect (client);

	  log_error ("Application access not licensed for %s@%s.%s",
		user->usr_name, info[LGID_MACHINE], info[LGID_APP_NAME]);
	  client_connection_free (cli);
	  DKS_DB_DATA (client) = NULL;
	  return 0;
	}
    }

  if (!user)
    {
      dk_free_box (cli_ver);
      thrs_printf ((thrs_fo, "ses %p thr:%p in connect6\n", client, THREAD_CURRENT_THREAD));
      DKST_RPC_DONE (client);
      PrpcAddAnswer ((caddr_t) 0, DV_SHORT_INT, 0, 1);
      PrpcDisconnect (client);
      client_connection_free (cli);
      DKS_DB_DATA (client) = NULL;
      return 0;
    }

  cli->cli_user = user;
  if (info && BOX_ELEMENTS (info) > LGID_CHARSET && info[LGID_CHARSET])
    {
      wcharset_t *charset = sch_name_to_charset (info[LGID_CHARSET]);
      if (charset)
	cli->cli_charset = charset;
    }
  IN_TXN;
  cli_set_new_trx (cli);
  LEAVE_TXN;
  if (cli_ver)
    {

      cli->cli_version = ODBC_DRV_VER_G_NO (cli_ver);
      cli->cli_support_row_count = 1;
      dk_free_box (cli_ver);

      /* meaning the version of the client as received by the server */
      cdef_add_param (&client->dks_caller_id_opts, "__SQL_CLIENT_VERSION", cli->cli_version);
    }
  cli_set_default_qual (cli);
  cli->cli_not_char_c_escape = cli_not_c_char_escape;
  cli->cli_utf8_execs = cli_utf8_execs;
  cli->cli_no_system_tables = cli_no_system_tables;
  PrpcSetPartnerDeadHook (client, (io_action_func) srv_client_session_died);
  dbev_connect (cli);

  ret = make_login_answer (cli);

  if (DO_LOG_INT(LOG_VUSER))
    {
      LOG_GET
      log_info ("USER_1 %s %s %s login", user, from, peer);
    }

  thrs_printf ((thrs_fo, "ses %p thr:%p in connect2\n", IMMEDIATE_CLIENT, THREAD_CURRENT_THREAD));
  DKST_RPC_DONE (IMMEDIATE_CLIENT);
  if (prpc_forced_fixed_thread)
    PrpcFixedServerThread ();

  dk_free_tree ((caddr_t) info);
  srv_add_login (cli);
  return ret;
}


void
qr_send_compilation (query_t * qr, client_connection_t *cli)
{
  caddr_t *box = (caddr_t *) dk_alloc_box (2 * sizeof (caddr_t),
      DV_ARRAY_OF_POINTER);
  caddr_t err = NULL;
  box[0] = (caddr_t) QA_COMPILED;
  box[1] = (caddr_t) qr_describe_1 (qr, &err, cli);
  if (err)
    {
      dk_free_tree ((box_t) box);
      box = (caddr_t *) err;
    }
  sql_warnings_send_to_cli ();
  PrpcAddAnswer ((caddr_t) box, DV_ARRAY_OF_POINTER, 1, 0);
  dk_free_tree ((box_t) box);
}


long qr_cache_hits;
long qr_cache_misses;
long qr_cache_entries = 100;


void
cli_qr_remove_from_stmt_cache (client_connection_t * cli, query_t * qr)
{
  id_hash_remove (cli->cli_text_to_query, (caddr_t) &qr->qr_text);
}


void
cli_drop_old_query (client_connection_t * cli)
{
  int cli_n_stmts =
      cli->cli_statements->ht_inserts - cli->cli_statements->ht_deletes;

  if (cli->cli_text_to_query->ht_inserts - cli->cli_text_to_query->ht_deletes
      > qr_cache_entries + cli_n_stmts)
    {
      query_t *last = cli->cli_last_query;
      while (last)
	{
	  if (0 == last->qr_ref_count)
	    {
	      L2_DELETE (cli->cli_first_query, cli->cli_last_query, last, qr_);
	      cli_qr_remove_from_stmt_cache (cli, last);
	      qr_free (last);
	      return;
	    }
	  last = last->qr_prev;
	}
    }
}


#define CORRECT_QUAL(qr, cli) \
  ((qr)->qr_qualifier && \
   0 == strcmp ((qr)->qr_qualifier, (cli)->cli_qualifier))


#define CORRECT_CR_TYPE(qr, cr_type) \
  (cr_type == (qr)->qr_cursor_type)

caddr_t
stmt_set_query (srv_stmt_t * stmt, client_connection_t * cli, caddr_t text,
		stmt_options_t * opts)
{
  int cr_type = (int) SO_CURSOR_TYPE (opts);
  int unique_rows = (int) SO_UNIQUE_ROWS (opts);
  caddr_t err = NULL;
  query_t **place;
  query_t *qr = NULL;
  place = (query_t **) id_hash_get (cli->cli_text_to_query, (caddr_t) & text);

  if (DO_LOG_INT(LOG_CLIENT_SQL))
    {
      char temp[LOG_PRINT_STR_L];
      LOG_GET

      strncpy (temp, text, LOG_PRINT_STR_L - 1);
      temp[LOG_PRINT_STR_L - 1] = 0;
      log_info ("CSLQ_0 %s %s %s %s %.*s", user, from, peer, stmt->sst_id, LOG_PRINT_STR_L, temp);
    }

  if (_SQL_CURSOR_FORWARD_ONLY == cr_type && unique_rows)
    cr_type = SQLC_UNIQUE_ROWS;

  ASSERT_IN_MTX (cli->cli_mtx);
  if (place && CORRECT_QUAL (*place, cli)
      && CORRECT_CR_TYPE ((*place), cr_type))
    {
      qr_cache_hits++;
      dk_free_box (text);
      text = NULL;
      qr = *place;
      prof_n_reused++;
    }
  if (qr && qr->qr_to_recompile)
    {
      query_t *old_qr = qr;
      qr_cache_hits++;
      qr = qr_recompile (qr, &err);
      if (err)
	{
	  if (cli->cli_http_ses || cli->cli_is_log)
	    return err;
	  PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
	  dk_free_tree (err);
	  return (caddr_t) SQL_ERROR;
	}
      id_hash_set (cli->cli_text_to_query, (caddr_t) &qr->qr_text, (caddr_t) &qr);
      L2_DELETE (cli->cli_first_query, cli->cli_last_query, old_qr, qr_);
      cli_drop_old_query (cli);
      L2_PUSH (cli->cli_first_query, cli->cli_last_query, qr, qr_);
    }
  if (!qr)
    {
      qr_cache_misses++;
      qr = eql_compile_2 (text, cli, &err, cr_type);
      if (!qr)
	{
	  dk_free_box (text);
	  if (cli->cli_http_ses || cli->cli_is_log)
	    return err;
	  PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
	  dk_free_tree (err);
	  return (caddr_t) SQL_ERROR;
	}
      if (!qr->qr_is_ddl)
	id_hash_set (cli->cli_text_to_query, (caddr_t) & qr->qr_text, (caddr_t) & qr);
      cli_drop_old_query (cli);
      L2_PUSH (cli->cli_first_query, cli->cli_last_query, qr, qr_);
    }
  dk_free_box (text);

  if (stmt->sst_query)
    stmt->sst_query->qr_ref_count--;
  stmt->sst_query = qr;
  qr->qr_ref_count++;
  if (qr != cli->cli_first_query)
    {
      /* set to first place in LRU queue */
      L2_DELETE (cli->cli_first_query, cli->cli_last_query, qr, qr_);
      L2_PUSH (cli->cli_first_query, cli->cli_last_query, qr, qr_);
    }

  if (!cli->cli_http_ses && !cli->cli_is_log)
    {
      CATCH (CATCH_LISP_ERROR)
	{
	  qr_send_compilation (qr, cli);
	}
      THROW_CODE
	{
	  caddr_t  cc_error = (caddr_t) THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR);
	  POP_CATCH;
	  PrpcAddAnswer (cc_error, DV_ARRAY_OF_POINTER, 1, 1);
	  dk_free_tree (cc_error);
	  return (caddr_t) SQL_ERROR;
	}
      END_CATCH;
    }

  return ((caddr_t) SQL_SUCCESS);

}

int32 cli_max_cached_stmts = 10000;

srv_stmt_t *
cli_get_stmt_access (client_connection_t * cli, caddr_t id, int mode, caddr_t * err_ret)
{
  caddr_t place;
  srv_stmt_t *stmt;
  IN_CLIENT (cli);
  place = id_hash_get (cli->cli_statements, (caddr_t) & id);
  if (!place && cli->cli_statements->ht_count >= cli_max_cached_stmts)
    {
      if (err_ret)
	*err_ret = srv_make_new_error ("HY013", "SR491", "Too many open statements");
      return NULL;
    }
  if (!place)
    {
      NEW_VARZ (srv_stmt_t, stmt);
      id_hash_set (cli->cli_statements, (caddr_t) & id, (caddr_t) & stmt);
      stmt->sst_id = id;

      return stmt;
    }
  else
    {
      dk_free_box (id);
    }

  stmt = *(srv_stmt_t **) place;

  if (stmt->sst_inst)
    {
      query_instance_t *qi = stmt->sst_inst;
      if (mode == GET_EXCLUSIVE)
	{
	  if (0 == qi->qi_threads)
	    {
	      qi->qi_threads = 1;
	      return stmt;
	    }
	  else
	    return NULL;
	}
      qi_enter (qi);
      return stmt;
    }
  return stmt;
}


query_t *
cli_cached_sql_compile (caddr_t query_text, client_connection_t *cli, caddr_t *err_ret, const char *stmt_id_name)
{
  srv_stmt_t *sst;
  int old_log_val;
  caddr_t err = NULL;
  caddr_t stmt_id = NULL;
  caddr_t stmt_boxed = box_dv_short_string (query_text);

  stmt_id = box_dv_short_string (stmt_id_name);
  sst = cli_get_stmt_access (cli, stmt_id, GET_EXCLUSIVE, NULL);
  old_log_val = cli->cli_is_log;
  cli->cli_is_log = 1;
  err = stmt_set_query (sst, cli, stmt_boxed, NULL);
  cli->cli_is_log = old_log_val;
  LEAVE_CLIENT (cli);
  if (err == (caddr_t) SQL_SUCCESS)
    err = NULL;
  if (err_ret)
    *err_ret = err;
  return err ? NULL : sst->sst_query;
}


void
sf_stmt_prepare (caddr_t stmt_id, char *text, long explain,
     stmt_options_t * opts)
{
  dk_session_t *client = IMMEDIATE_CLIENT;
  client_connection_t *cli = DKS_DB_DATA (client);
  caddr_t err = NULL;

  srv_stmt_t *stmt = cli_get_stmt_access (cli, stmt_id, GET_EXCLUSIVE, &err);
  if (!stmt && err)
    goto report_error;
  cli->cli_terminate_requested = 0;
  cli->cli_start_time = time_now_msec;
  if (!stmt || stmt->sst_cursor_state)
    {
      /* There's an instance. can't do it */
      err = srv_make_new_error ("S1010", "SR209", "Statement active");
report_error:
      mutex_leave (cli->cli_mtx);
      PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
      dk_free_tree (err);

      thrs_printf ((thrs_fo, "ses %p thr:%p in prepare1\n", client, THREAD_CURRENT_THREAD));
      DKST_RPC_DONE (client);
      return;
    }
  if (stmt->sst_inst)
    {
      query_instance_t *qi = (query_instance_t *) stmt->sst_inst;

#ifdef INPROCESS_CLIENT
      if (!IS_INPROCESS_CLIENT (cli))
#endif
	{
	  IN_TXN;
	  lt_threads_inc_inner (qi->qi_trx);
	  LEAVE_TXN;
	}

      LEAVE_CLIENT (cli);
      qi_kill (qi, QI_DONE);
      IN_CLIENT (cli);
      stmt->sst_inst = NULL;
    }

  stmt_set_query (stmt, cli, text, opts);
  dk_free_box ((caddr_t) opts);
  mutex_leave (cli->cli_mtx);
  thrs_printf ((thrs_fo, "ses %p thr:%p in prepare2\n", client, THREAD_CURRENT_THREAD));
  DKST_RPC_DONE (client);
  session_flush (client);
}


#ifdef SERIAL_CLI
CLI_WRAPPER (sf_stmt_prepare,
	(caddr_t stmt_id, char *text, long explain, stmt_options_t * opts),
	(stmt_id, text, explain, opts))
#define sf_stmt_prepare sf_stmt_prepare_w
#endif


void
cli_set_current_ofs (client_connection_t * cli, caddr_t * current_ofs)
{
  int inx;
  if (!current_ofs)
    return;
  ASSERT_IN_MTX (cli->cli_mtx);
  cli_set_scroll_current_ofs (cli, current_ofs);

  for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (current_ofs); inx += 2)
    {
      if (current_ofs[inx])
	{
	  caddr_t place = id_hash_get (cli->cli_cursors,
	      (caddr_t) &current_ofs[inx]);
	  if (place)
	    {
	      query_instance_t *qi = *(query_instance_t **) place;
	      query_t *qr = qi->qi_query;
	      select_node_t *sel = qr->qr_select_node;
	      if (!sel)
		continue;
	      ((ptrlong *) qi)[sel->sel_current_of] = unbox (current_ofs[inx + 1]);
	    }
	}
    }
  dk_free_tree ((caddr_t) current_ofs);
}


caddr_t
stmt_check_recompile (srv_stmt_t * stmt)
{
  if (stmt->sst_query && stmt->sst_query->qr_to_recompile)
    {
      query_t *qr;
      caddr_t err = NULL;
      qr = qr_recompile (stmt->sst_query, &err);
      if (err)
	{
	  PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
	  dk_free_tree (err);
	  return (caddr_t) SQL_ERROR;
	}
      stmt->sst_query->qr_ref_count--;
      qr->qr_ref_count++;
      stmt->sst_query = qr;
    }
  return (caddr_t) SQL_SUCCESS;
}


static int
sf_sql_execute_check_params (caddr_t stmt_id, char *text, char *cursor_name,
    caddr_t * params, caddr_t * current_ofs, stmt_options_t * options)
{
  dk_session_t *client = IMMEDIATE_CLIENT;

  if ((DV_TYPE_OF (options) != DV_ARRAY_OF_POINTER &&
	DV_TYPE_OF (options) != DV_ARRAY_OF_LONG &&
	DV_TYPE_OF (options) != DV_ARRAY_OF_LONG_PACKED
      ) ||
      box_length (options) < (ptrlong) & (((stmt_options_t*)0)->so_rpc_timeout))
    {
      sr_report_future_error (client, "EXEC", "Illformed options parameter");
      return 0;
    }
  if (current_ofs && DV_TYPE_OF (current_ofs) != DV_ARRAY_OF_POINTER)
    {
#if 0
      int inx;
#endif
      sr_report_future_error (client, "EXEC", "Illformed current_ofs parameter");
      return 0;
#if 0
      DO_BOX (caddr_t, elt, inx, ((caddr_t *)params))
	{
	  dtp_t text_dtp = DV_TYPE_OF (elt);
	  if (!IS_STRING_DTP (text_dtp) && text_dtp != DV_C_STRING)
	    {
	      sr_report_future_error (client, "EXEC", "Illformed current_ofs parameter");
	      return 0;
	    }
	}
      END_DO_BOX;
#endif
    }
  if (text)
    {
      dtp_t text_dtp = DV_TYPE_OF (text);
      if (!IS_STRING_DTP (text_dtp) && text_dtp != DV_C_STRING)
	{
	  sr_report_future_error (client, "EXEC", "Illformed text parameter");
	  return 0;
	}
    }
  if (cursor_name)
    {
      dtp_t text_dtp = DV_TYPE_OF (cursor_name);
      if (!IS_STRING_DTP (text_dtp) && text_dtp != DV_C_STRING)
	{
	  sr_report_future_error (client, "EXEC", "Illformed cursor_name parameter");
	  return 0;
	}
    }
  if (params)
    {
      int inx;
      DO_BOX (caddr_t, elt, inx, ((caddr_t *)params))
	{
	  if (DV_TYPE_OF (elt) != DV_ARRAY_OF_POINTER)
	    {
	      sr_report_future_error (client, "EXEC", "Illformed parameters parameter");
	      return 0;
	    }
	}
      END_DO_BOX;
    }
  return 1;
}


void
cli_set_start_times (client_connection_t * cli)
{
  if (prof_on)
    dt_now ((caddr_t)&cli->cli_start_dt);
  cli->cli_start_time = get_msec_real_time ();
  cli->cli_cl_start_ts = rdtsc ();
  cli->cli_activity.da_thread_time = 0;
}


void
sf_sql_execute (caddr_t stmt_id, char *text, char *cursor_name,
    caddr_t * params, caddr_t * current_ofs, stmt_options_t * options)
{
  long msecs = prof_on ? get_msec_real_time () : 0;
  query_instance_t *qi;
  int inx, first_set = 1, n_params = 0;
  caddr_t err = NULL;
  dk_session_t *client = IMMEDIATE_CLIENT;
  client_connection_t *cli = DKS_DB_DATA (client);
  srv_stmt_t *stmt;

  CHANGE_THREAD_USER(cli->cli_user);

  if (!sf_sql_execute_check_params (stmt_id, text,
	cursor_name, params, current_ofs, options))
    {
      err = srv_make_new_error ("41000", "SR344", "Malformed RPC");
      goto report_rpc_format_error;
    }

  stmt = cli_get_stmt_access (cli, stmt_id, GET_EXCLUSIVE, &err);
  if (err)
    goto report_error;
  if (prof_on)
    {
      cli->cli_log_qi_stats = 1;
      dt_now ((caddr_t)&cli->cli_start_dt);
    }
  if (params)
    n_params = BOX_ELEMENTS (params);

#ifdef DEBUG
  if (DO_LOG(LOG_EXEC))
    {
      LOG_GET;
      log_info ("EXEC_I %s %s %s %s Exec %d time(s) %.*s", user, from, peer, stmt->sst_id,
	  n_params, LOG_PRINT_STR_L, text ? text : "");
    }
#endif

  cli->cli_terminate_requested = 0;
  cli->cli_start_time = time_now_msec;
  if (!stmt || stmt->sst_cursor_state)
    {
      /* Busy */
      err = srv_make_new_error ("S1010", "SR210", "Async exec busy");
report_error:
      mutex_leave (cli->cli_mtx);
    report_rpc_format_error:
      PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
      DKST_RPC_DONE (client);
      dk_free_tree (err);

      dk_free_box (text);
      dk_free_box (cursor_name);
      dk_free_tree ((caddr_t) params);
      dk_free_box ((caddr_t) options);
      dk_free_tree ((box_t) current_ofs);

      if (DK_MEM_RESERVE)
	{
	  IN_CLIENT (cli);
	  cli_scrap_cached_statements (cli);
	  id_hash_clear (cli->cli_text_to_query);
	  id_hash_clear (cli->cli_statements);
	  LEAVE_CLIENT (cli);
	}
      return;
    }
  /* We're in on the statement on exclusive. We're in on the instance too
     if there is one */
#ifdef VIRTTP
  if (cli->cli_tp_data && (cli->cli_tp_data->cli_trx_type != TP_XA_TYPE))
    {
      dbg_printf(("execute %s\n",text));
      if (!cli->cli_tp_data->tpd_last_act)
	{
	  dbg_printf(("setting %p\n", (void *)(cli->cli_trx)));
	  cli->cli_tp_data->cli_tp_lt = cli->cli_trx;
	}
      else if (TP_ABORT == cli->cli_tp_data->tpd_last_act)
	{
	  caddr_t err = srv_make_new_error ("41000", "SR211", "Aborted");
	  mutex_leave (cli->cli_mtx);
	  PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
	  dk_free_tree (err);

	  dk_free_box (text);
	  dk_free_box (cursor_name);
	  dk_free_tree ((caddr_t) params);
	  dk_free_box ((caddr_t) options);
	  dk_free_tree ((box_t) current_ofs);

	  return;
	}
    }

#endif

  if ((qi = stmt->sst_inst))
    {
#ifdef INPROCESS_CLIENT
      if (!IS_INPROCESS_CLIENT (cli))
#endif
	{
	  IN_TXN;
	  lt_threads_inc_inner (qi->qi_trx);
	  LEAVE_TXN;
	}
      LEAVE_CLIENT (cli);
      dbg_printf (("Stmt reuse without clear %s\n", stmt->sst_id));
      /* not really an error condition */
      qi_kill (qi, QI_DONE);	/* uses cli_mtx */
      IN_CLIENT (cli);
      stmt->sst_inst = NULL;	/* Old instance scrapped */
    }


  if (text)
    {
      /* Exec direct RPC. Compile first */
      if (stmt_set_query (stmt, cli, text, options) != (caddr_t) SQL_SUCCESS)
	{
	  mutex_leave (cli->cli_mtx);
	  dk_free_tree ((caddr_t) params);
	  dk_free_box ((caddr_t) options);

	  if (DK_MEM_RESERVE)
	    {
	      IN_CLIENT (cli);
	      cli_scrap_cached_statements (cli);
	      id_hash_clear (cli->cli_text_to_query);
	      id_hash_clear (cli->cli_statements);
	      LEAVE_CLIENT (cli);
	    }
	  thrs_printf ((thrs_fo, "ses %p thr:%p in execute1\n", client, THREAD_CURRENT_THREAD));
	  DKST_RPC_DONE (client);
	  return;
	}
    }
  else
    {
      if (SQL_SUCCESS != stmt_check_recompile (stmt))
	{
	  mutex_leave (cli->cli_mtx);
	  if (DK_MEM_RESERVE)
	    {
	      IN_CLIENT (cli);
	      cli_scrap_cached_statements (cli);
	      id_hash_clear (cli->cli_text_to_query);
	      id_hash_clear (cli->cli_statements);
	      LEAVE_CLIENT (cli);
	    }
	  thrs_printf ((thrs_fo, "ses %p thr:%p in execute2\n", client, THREAD_CURRENT_THREAD));
	  DKST_RPC_DONE (client);
	  return;
	}
    }
  if (!stmt->sst_query)
    {
      caddr_t err = srv_make_new_error ("S1010", "SR212", "Statement not prepared.");
      mutex_leave (cli->cli_mtx);
      thrs_printf ((thrs_fo, "ses %p thr:%p in execute3\n", client, THREAD_CURRENT_THREAD));
      DKST_RPC_DONE (client);
      PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
      dk_free_tree (err);
      if (DK_MEM_RESERVE)
	{
	  IN_CLIENT (cli);
	  cli_scrap_cached_statements (cli);
	  id_hash_clear (cli->cli_text_to_query);
	  id_hash_clear (cli->cli_statements);
	  LEAVE_CLIENT (cli);
	}
      return;
    }


  cli_set_current_ofs (cli, current_ofs);
  if (stmt->sst_query->qr_select_node
      && n_params > 1 && options &&
      (box_length ((caddr_t) options) > (ptrlong) & (((stmt_options_t*)0)->so_prefetch)))
    {
      options->so_prefetch = PREFETCH_ALL;
    }

#ifdef DEBUG
  if (options && box_length ((caddr_t) options) > (ptrlong) & (((stmt_options_t*)0)->so_autocommit))
    {
      cli->cli_autocommit = options->so_autocommit;
    }
  else
    cli->cli_autocommit = 0;
#endif

  if (stmt->sst_query->qr_select_node
      && SO_CURSOR_TYPE (options) > _SQL_CURSOR_FORWARD_ONLY)
    {
      if (DO_LOG(LOG_EXEC))
	{
	  LOG_GET;
	  log_info ("EXEC_0 %s %s %s Exec cursor %s %*.*s", user, from, peer, stmt->sst_id,
	      LOG_PRINT_STR_L, LOG_PRINT_STR_L, stmt->sst_query->qr_text ? stmt->sst_query->qr_text:"");
	}

      stmt_start_scroll (cli, stmt, (caddr_t **)params, cursor_name, options);
      if (params)
	{
	  params[0] = NULL;
	  dk_free_tree ((box_t) params);
	}
      if (DK_MEM_RESERVE)
	{
	  IN_CLIENT (cli);
	  cli_scrap_cached_statements (cli);
	  id_hash_clear (cli->cli_text_to_query);
	  id_hash_clear (cli->cli_statements);
	  LEAVE_CLIENT (cli);
	}
      return;
    }

  if (DO_LOG(LOG_EXEC))
    {
      LOG_GET;
      log_info ("EXEC_1 %s %s %s %s Exec %d time(s) %.*s", user, from, peer, stmt->sst_id,
	  n_params, LOG_PRINT_STR_L, stmt->sst_query->qr_text ? ((stmt->sst_query->qr_text[0] == -35) ? "" : stmt->sst_query->qr_text) :"");
    }
  if (!stmt->sst_query->qr_select_node && !stmt->sst_query->qr_is_call)
    {
      err = qr_dml_array_exec (cli, stmt->sst_query, CALLER_CLIENT,
			       cursor_name ? box_string (cursor_name) : NULL,
			       stmt, (caddr_t**)params, options);
      dk_free_tree (err);
    }
  else
    {
      for (inx = 0; inx < n_params; inx++)
	{
	  caddr_t *par = (caddr_t *) params[inx];
	  params[inx] = NULL;

	  if (!first_set)
	    {
	      mutex_enter (cli->cli_mtx);
	    }
	  first_set = 0;
	  err = qr_exec (cli, stmt->sst_query, CALLER_CLIENT,
			 cursor_name ? box_string (cursor_name) : NULL,
			 stmt, NULL, par, options, 0);
	  dk_free_box ((caddr_t) par);
	  ASSERT_OUTSIDE_MTX (cli->cli_mtx);
	  if (err != (caddr_t) SQL_SUCCESS)
	    {
	      dk_free_tree (err);
	      break;
	    }
      else
	sql_warnings_send_to_cli ();
	  stmt->sst_parms_processed = inx;
	}
      if (!cli->cli_keep_csl)
	cli_set_slice (cli, NULL, QI_NO_SLICE, NULL);
      dk_free_tree ((caddr_t) params);
    }
  if (n_params == 0)
    mutex_leave (cli->cli_mtx);
  thrs_printf ((thrs_fo, "ses %p thr:%p in execute4\n", client, THREAD_CURRENT_THREAD));
  DKST_RPC_DONE (client);
  session_flush (client);
  if (msecs && prof_on)
    prof_exec (stmt->sst_query, NULL, get_msec_real_time () - msecs,
	       PROF_EXEC | (err != NULL ? PROF_ERROR : 0));

  ASSERT_OUTSIDE_TXN;
  dk_free_tree (cursor_name);
  stmt->sst_param_array = NULL;
  dk_free_tree ((caddr_t) options);
  if (DK_MEM_RESERVE)
    {
      IN_CLIENT (cli);
      cli_scrap_cached_statements (cli);
      id_hash_clear (cli->cli_text_to_query);
      id_hash_clear (cli->cli_statements);
      LEAVE_CLIENT (cli);
    }
}


#ifdef SERIAL_CLI
CLI_WRAPPER (sf_sql_execute,
	(caddr_t stmt_id, char *text, char *cursor_name,
	 caddr_t * params, caddr_t * current_ofs, stmt_options_t * options),
	(stmt_id, text, cursor_name, params,  current_ofs, options))
#define sf_sql_execute sf_sql_execute_w
#endif

#ifdef VIRTTP
void sf_sql_tp_transact(short op, char* xid_str)
{
  dk_session_t *client = IMMEDIATE_CLIENT;
  client_connection_t *cli = DKS_DB_DATA (client);
  caddr_t err;

  _2pc_printf(("sf_sql_tp_transact %x\n",op));
  if (((SQL_TP_ABORT == op) || (SQL_TP_COMMIT == op)) && !cli->cli_tp_data)
    {
      err = srv_make_new_error ("TP105", "XA001", "Unexpected operation in tp transact code: %d", op);
      DKST_RPC_DONE (client);
      PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
      dk_free_tree (err);
      dk_free_tree (xid_str);
      return;
    }

  _2pc_printf(("got a tp massage=%x cli %p, lt_threads: %d\n", op, cli, cli->cli_trx ? cli->cli_trx->lt_threads : -1));
  switch (op)
    {
    case SQL_TP_UNENLIST:
      {
	tp_wait_commit(cli);
      } break;
    case SQL_TP_PREPARE:
    case SQL_TP_COMMIT:
      {
	NEW_VAR(tp_future_t,future);
	tp_message_t * msg;


	msg = mq_create_message (op ^ SQL_TP_UNENLIST ,future,cli);
	future->ft_result = SQL_ERROR;
	future->ft_sem = semaphore_allocate(0);
	_2pc_printf(("tp pre/comm 0 =%x cli %p lt %p %d\n",op,cli,cli->cli_trx, cli->cli_trx->lt_status));
	mq_add_message(tp_main_queue,msg);
	_2pc_printf(("tp pre/comm 1 =%x cli %p\n",op,cli));
	semaphore_enter(future->ft_sem);
	_2pc_printf(("tp pre/comm 2 =%x cli %p\n",op,cli));
        DKST_RPC_DONE (client);
	PrpcAddAnswer ((caddr_t)future->ft_result, DV_ARRAY_OF_POINTER, 1, 1);
	_2pc_printf(("tp pre/comm 3 =%x cli %p\n",op,cli));

	semaphore_free(future->ft_sem);
	dk_free(future,sizeof(tp_future_t));
	_2pc_printf(("tp pre/comm 4 =%x cli %p\n",op,cli));

      }
      dk_free_tree (xid_str);
      return;
    case SQL_TP_ABORT:
      {
	tp_message_t* msg = mq_create_message (TP_ABORT,0,cli);
	mq_add_message(tp_main_queue,msg);
      } break;
    case SQL_XA_JOIN:
      {
	err = srv_make_new_error ("TP107", "XA002", "XA join is not supported");
	DKST_RPC_DONE (client);
	PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
	dk_free_tree (err);
	dk_free_tree (xid_str);
	return;
      }
    case SQL_XA_ENLIST:
      {
	void * xid;
	tp_data_t * tpd;
	int rc;

	xid = xid_bin_decode (xid_str);
	if (!xid)
	  {
	    err = srv_make_new_error ("TP108", "XA003", "XID identifier can not be decoded");
	    DKST_RPC_DONE (client);
	    PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
	    dk_free_tree (err);
	    dk_free_tree (xid_str);
	    return;
	  }

	tpd = (tp_data_t*)dk_alloc (sizeof (tp_data_t));
	memset (tpd, 0, sizeof (tp_data_t));
	cli->cli_tp_data = tpd;

      again:
	rc = virt_xa_set_client (xid, cli);
	if (rc == VXA_AGAIN)
	  goto again;
	if (rc == VXA_ERROR)
	  {
	    err = srv_make_new_error ("TP102", "XA004", "Duplicate global transaction identifier");
	    DKST_RPC_DONE (client);
	    PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
	    dk_free_tree (err);
	    cli->cli_tp_data = 0;
	    dk_free (tpd, sizeof (tp_data_t));
	    dk_free_tree (xid_str);
	    return;
	  }

	tpd->cli_tp_enlisted = CONNECTION_PREPARED;
	virt_xa_tp_set_xid (tpd, xid);
	/* must see if trx already has xid */
	if (cli->cli_trx->lt_2pc._2pc_xid && cli->cli_trx->lt_2pc._2pc_xid != xid)
	  {
	    IN_TXN;
	    if (!cli->cli_trx->lt_2pc._2pc_wait_commit)
	      lt_done (cli->cli_trx);
	    cli->cli_trx = NULL;
	    cli_set_new_trx (cli);
	    LEAVE_TXN;
	  }
	tpd->cli_tp_lt = cli->cli_trx;
	cli->cli_trx->lt_2pc._2pc_xid = xid;

	tpd->cli_tp_sem2 = semaphore_allocate (0);
	cli->cli_tp_data = tpd;
	tpd->cli_trx_type = cli->cli_trx->lt_2pc._2pc_type = TP_XA_TYPE;
	_2pc_printf (("xa enlist lt %x cli %x tpdata %p", cli->cli_trx, cli, cli->cli_tp_data));

      } break;
    case SQL_XA_RESUME:
      {
	void * xid;
	tp_data_t * tpd;

	xid = xid_bin_decode (xid_str);
	if (!xid)
	  {
	    err = srv_make_new_error ("TP108", "XA005", "XID identifier can not be decoded");
	    DKST_RPC_DONE (client);
	    PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
	    dk_free_tree (err);
	    dk_free_tree (xid_str);
	    return;
	  }
	if (virt_xa_client (xid, cli, &tpd, SQL_XA_RESUME) == -1)
	  {
	    err = srv_make_new_error ("TP109", "XA006", "XID identifier can not be decoded");
	    DKST_RPC_DONE (client);
	    PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1,1);
	    dk_free_tree (err);
	    dk_free_tree (xid_str);
	    return;
	  }
      } break;
    case SQL_XA_ENLIST_END:
    case SQL_XA_SUSPEND:
      {
	struct tp_data_s * tpd;
	void * xid = virt_xa_id (xid_str);

	if (virt_xa_client (xid, cli, &tpd, op) == -1)
	  {
	    err = srv_make_new_error ("TP109", "XA007", "XID identifier can not be decoded");
	    DKST_RPC_DONE (client);
	    PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1,1);
	    dk_free_box (xid);
	    dk_free_tree (err);
	    dk_free_tree (xid_str);
	    return;
	  }

	IN_TXN;
	if (1 || op == SQL_XA_SUSPEND)
	  {
	    virt_xa_suspend_lt (xid, cli);
	    cli->cli_trx = NULL;
	    cli->cli_tp_data = 0;
	  }
	cli_set_new_trx (cli);
	LEAVE_TXN;
	dk_free_box (xid);
      } break;
    case SQL_XA_PREPARE:
    case SQL_XA_COMMIT:
      {
	struct tp_data_s * tpd;
	void * xid = virt_xa_id (xid_str);
	_2pc_printf(("tp pre/comm 0 =%x cli %p\n",op,cli));
	if (virt_xa_client (xid, cli, &tpd, op) == -1)
	  {
	    caddr_t trx = virt_xa_xid_in_log (xid);
	    if (0 && trx)
	      {
		_2pc_printf(("tp pre/comm 1 =%x cli %p\n",op,cli));
		if (virt_xa_replay_trx (xid, trx, cli) != LTE_OK)
		  {
		    err = srv_make_new_error ("TP104", "XA008",
			"Could not commit transaction [%s] at recovery stage",
			xid_str);
		    PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
		    dk_free_tree (err);
		  }
		else
		  PrpcAddAnswer ((caddr_t) SQL_SUCCESS, DV_ARRAY_OF_POINTER, 1, 1);
		_2pc_printf(("tp pre/comm 2 =%x cli %p\n",op,cli));
	      }
	    else
	       {
		err = srv_make_new_error ("TP101", "XA009",
			"Unknown global transaction identifier [%s]", xid_str);
		PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
		dk_free_tree (err);
	       }
	  }
	else
	  {
	    NEW_VAR(tp_future_t,future);
	    tp_message_t * msg;
	    lock_trx_t * curr_lt;

	    if (!tpd)
	      GPF_T;
	    curr_lt = tpd->cli_tp_lt;

	    if (!curr_lt)
	      {
		virt_xa_remove_xid (xid);
		lt_enter_anyway (cli->cli_trx);
		IN_TXN;
		lt_rollback (cli->cli_trx, TRX_FREE);
		LEAVE_TXN;
		err = srv_make_new_error ("TP110", "XA010", "Wrong sequence [%s]", xid_str);
		DKST_RPC_DONE (client);
		PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
		dk_free_tree (err);
		dk_free_tree (xid_str);
		return;
	      }

	    if ((op == SQL_XA_COMMIT) && (curr_lt->lt_status == LT_PENDING))
	      {
	    	_2pc_printf(("unprepared lt %p cli %p st %d\n",curr_lt, cli, curr_lt->lt_status));
		msg = mq_create_message (TP_PREPARE, future, cli);
		future->ft_result = SQL_ERROR;
		future->ft_sem = semaphore_allocate(0);
		mq_add_message(tp_main_queue,msg);
		semaphore_enter(future->ft_sem);
		semaphore_free(future->ft_sem);
		if (future->ft_result != LTE_OK)
		  {
		    MAKE_TRX_ERROR (future->ft_result, err, LT_ERROR_DETAIL (curr_lt));
		    dk_free(future,sizeof(tp_future_t));
		    DKST_RPC_DONE (client);
		    PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
		    dk_free_tree (err);
		    dk_free_box ((box_t) xid);
		    dk_free_tree (xid_str);
		    return;
		  }
	      }

	    _2pc_printf(("tp pre/comm 3 =%x cli %p %d\n",op,cli,curr_lt->lt_status));
	    msg = mq_create_xa_message (op ^ SQL_XA_UNENLIST ,future,tpd);
	    future->ft_result = SQL_ERROR;
	    future->ft_sem = semaphore_allocate(0);
	    _2pc_printf(("tp pre/comm 4 =%x cli %p\n",op,cli));
	    mq_add_message(tp_main_queue,msg);
	    semaphore_enter(future->ft_sem);
	    PrpcAddAnswer ((caddr_t)future->ft_result, DV_ARRAY_OF_POINTER, 1, 1);
	    _2pc_printf(("tp pre/comm 5 =%x cli %p\n",op,cli));
	    if ( (op == SQL_XA_PREPARE) && (future->ft_result != LTE_OK))
	      {
		lt_enter_anyway (cli->cli_trx);
		IN_TXN;
		lt_rollback (cli->cli_trx, TRX_FREE);
		cli->cli_trx = NULL;
		LEAVE_TXN;
		virt_xa_remove_xid (xid);
		MAKE_TRX_ERROR (future->ft_result, err, NULL);
		dk_free(future,sizeof(tp_future_t));
		DKST_RPC_DONE (client);
		PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
		dk_free_tree (err);
		dk_free_box ((box_t) xid);
		dk_free_tree (xid_str);
		return;
	      }
	    if (op==SQL_XA_COMMIT)
	      {
		txa_remove_entry (xid, 1);
	      }
	    semaphore_free(future->ft_sem);
	    dk_free(future,sizeof(tp_future_t));
	    _2pc_printf(("tp pre/comm 6 =%x cli %p\n",op,cli));

	  }
	dk_free_box ((box_t) xid);
	DKST_RPC_DONE (client);
	dk_free_tree (xid_str);
	return;
      }
    case SQL_XA_ROLLBACK:
      {
	void * xid = virt_xa_id (xid_str);
	struct tp_data_s * tpd;
	if (virt_xa_client (xid, cli, &tpd, op) != -1)
	  {
	    NEW_VAR(tp_future_t,future);
	    tp_message_t* msg;
	    future->ft_sem = semaphore_allocate(0);
	    future->ft_release = 1; /* will not wait tp thread to finish, so mark it to release once done */
	    msg = mq_create_xa_message (TP_ABORT,future,tpd);
	    mq_add_message(tp_main_queue,msg);
	  }
	txa_remove_entry (xid, 0);
	dk_free_box ((box_t) xid);
      } break;
    case SQL_XA_WAIT:
      {
	void * xid = xid_bin_decode (xid_str);
	tp_data_t * tpd;
	if (virt_xa_client (xid, cli, &tpd, SQL_XA_WAIT) == -1)
	  {
	    err = srv_make_new_error ("TP109", "XA011", "XID identifier can not be decoded");
	    DKST_RPC_DONE (client);
	    PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1,1);
	    dk_free_tree (err);
	    dk_free_box (xid);
	    dk_free_tree (xid_str);
	    return;
	  }
	xa_wait_commit (tpd);
	virt_xa_remove_xid (xid);
	dk_free_box (xid);
	cli->cli_tp_data = NULL;
      } break;
    }
  DKST_RPC_DONE (client);
  PrpcAddAnswer (SQL_SUCCESS, DV_ARRAY_OF_POINTER, 1, 1);
  dk_free_tree (xid_str);
}

#ifdef SERIAL_CLI
CLI_WRAPPER (sf_sql_tp_transact,(short op, char* xid_str),(op,xid_str))
#define sf_sql_tp_transact sf_sql_tp_transact_w
#endif

#endif /* VIRTTP */




void
sf_sql_fetch (caddr_t stmt_id, long cond_no)
{
  long start = prof_on ? get_msec_real_time () : 0;
  dk_session_t *client = IMMEDIATE_CLIENT;
  caddr_t err;
  client_connection_t *cli = DKS_DB_DATA (client);
  srv_stmt_t *stmt = cli_get_stmt_access (cli, stmt_id, GET_EXCLUSIVE, NULL);

  CHANGE_THREAD_USER(cli->cli_user);

  if (!stmt || !stmt->sst_inst)
    {
      /* Busy */
      caddr_t err = srv_make_new_error ("S1010", "SR213", "SQLFetch of busy");
      mutex_leave (cli->cli_mtx);
      thrs_printf ((thrs_fo, "ses %p thr:%p in fetch1\n", client, THREAD_CURRENT_THREAD));
      DKST_RPC_DONE (client);
      PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
      dk_free_tree (err);
      return;
    }
  /* The statement is instantiated and we're in on exclusive. Do some more */

  THIS_COND_NO = cond_no;

  err = qr_more ((caddr_t *) stmt->sst_inst);
  ASSERT_OUTSIDE_MTX (cli->cli_mtx);
  cli_set_slice (cli, NULL, QI_NO_SLICE, NULL);
  thrs_printf ((thrs_fo, "ses %p thr:%p in fetch2\n", IMMEDIATE_CLIENT, THREAD_CURRENT_THREAD));
  DKST_RPC_DONE (IMMEDIATE_CLIENT);
  session_flush (client);
  if (start && prof_on)
    prof_exec (stmt->sst_query, NULL, get_msec_real_time () - start,
	       PROF_FETCH | (err != NULL ? PROF_ERROR : 0));
  dk_free_tree (err);
}

#ifdef SERIAL_CLI
CLI_WRAPPER (sf_sql_fetch,
	(caddr_t stmt_id, long cond_no),
	(stmt_id, cond_no))
#define sf_sql_fetch sf_sql_fetch_w
#endif


#ifdef SERIAL_CLI
CLI_WRAPPER (sf_sql_extended_fetch,
	(caddr_t stmt_id, long type, long irow, long n_rows,
	 long is_autocommit, caddr_t bookmark),
	(stmt_id, type, irow, n_rows, is_autocommit, bookmark))
#define sf_sql_extended_fetch sf_sql_extended_fetch_w
#endif


long sf_sql_set_cursor_name (caddr_t stmt_id, char *name);

#define SQL_DROP	       1


long
sf_sql_free_stmt (caddr_t stmt_id, int op)
{
  query_instance_t *qi = NULL;
  dk_session_t *client = IMMEDIATE_CLIENT;
  client_connection_t *cli = DKS_DB_DATA (client);
  srv_stmt_t *stmt = cli_get_stmt_access (cli, stmt_id, GET_ANY, NULL);
  dbg_printf (("sf_sql_free_stmt %s %d\n", stmt->sst_id, op));
  if (stmt->sst_cursor_state)
    stmt_scroll_close (stmt);
  if (stmt->sst_inst)
    {
      qi = stmt->sst_inst;
      /* off with the instance - INSIDE the mtx. */
      /* ensure next SQLFreeStmt does't get same qi */
      qi_detach_from_stmt (qi);
      if (qi->qi_threads > 1)
	{
	  du_thread_t *self = THREAD_CURRENT_THREAD;
	  cli->cli_terminate_requested = CLI_TERMINATE;
	  qi->qi_threads--;
	  qi->qi_thread_waiting_termination = self;
	  dbg_printf (("sf_sql_free_stmt going to wait for termination\n"));
	  LEAVE_CLIENT (cli);
	  semaphore_enter (self->thr_sem);
	}
      else
	{
#ifdef INPROCESS_CLIENT
	  if (!IS_INPROCESS_CLIENT (cli))
#endif
	    {
	      IN_TXN;
	      lt_threads_inc_inner (qi->qi_trx);
	      LEAVE_TXN;
	    }
	  LEAVE_CLIENT (qi->qi_client);
	  qi_kill (qi, QI_DONE);
	}
    }
  else
    {
      dbg_printf (("   sf_sql_free_stmt with no qi %s\n", stmt->sst_id));
      LEAVE_CLIENT (cli);
    }

  if (op == SQL_DROP)
    {

      mutex_enter (cli->cli_mtx);
      if (stmt->sst_query)
	stmt->sst_query->qr_ref_count--;
      id_hash_remove (cli->cli_statements, (caddr_t) & stmt->sst_id);
      mutex_leave (cli->cli_mtx);
      dk_free_box (stmt->sst_id);

      dk_free ((caddr_t) stmt, sizeof (srv_stmt_t));
    }
  thrs_printf ((thrs_fo, "ses %p thr:%p in free1\n", IMMEDIATE_CLIENT, THREAD_CURRENT_THREAD));
  DKST_RPC_DONE (IMMEDIATE_CLIENT);
  return 1;
}


#ifdef SERIAL_CLI
CLI_WRAPPER (sf_sql_free_stmt, (caddr_t stmt_id, int op), (stmt_id, op))
#define sf_sql_free_stmt sf_sql_free_stmt_w
#endif

/* in case of rollback don't report txn error as txn is already rolledback */
caddr_t
cli_transact (client_connection_t * cli, int op, caddr_t * replicate)
{
  int err = LTE_OK;
  caddr_t res;
  int rc;
  lock_trx_t *lt;

  IN_CLIENT (cli);

  IN_TXN;
  lt = cli->cli_trx;
  lt_wait_checkpoint ();

  lt_threads_inc_inner (lt);

  LEAVE_CLIENT (cli);
  rc = lt_close (lt, op);
  /* lt_close leaves the txn mtx */
  if (rc == LTE_OK || SQL_ROLLBACK == op)
    {
      res = SQL_SUCCESS;
    }
  else
    {
      if (LTE_OK != err)
	rc = err;
      MAKE_TRX_ERROR (rc, res, LT_ERROR_DETAIL (lt));
    }
  return res;
}

#ifdef INPROCESS_CLIENT
caddr_t
cli_inprocess_transact (client_connection_t * cli, int op, caddr_t * replicate)
{
  caddr_t res;
  int rc;
  lock_trx_t *lt;

  IN_CLIENT (cli);

  IN_TXN;
  lt = cli->cli_trx;

  LEAVE_CLIENT (cli);

  if (SQL_COMMIT == op)
    rc = lt_commit (lt, TRX_CONT);
  else
    {
      rc = lt->lt_error;
      lt_rollback (lt, TRX_CONT);
    }

  LEAVE_TXN;
  if (rc == LTE_OK)
    {
      res = SQL_SUCCESS;
    }
  else
    {
      MAKE_TRX_ERROR (rc, res, LT_ERROR_DETAIL (lt));
    }
  return res;
}
#endif

void
sf_sql_transact (long op, caddr_t * replicate)
{
  dk_session_t *client = IMMEDIATE_CLIENT;
  client_connection_t *cli = DKS_DB_DATA (client);
  caddr_t res;
#ifdef INPROCESS_CLIENT
  if (IS_INPROCESS_CLIENT (cli))
    res = cli_inprocess_transact (cli, op, replicate);
  else
#endif
    res = cli_transact (cli, op, replicate);
  thrs_printf ((thrs_fo, "ses %p thr:%p in transact1\n", client, THREAD_CURRENT_THREAD));
  DKST_RPC_DONE (client);
  PrpcAddAnswer (res, DV_ARRAY_OF_POINTER, 1, 1);
  dk_free_tree (res);
}


#ifdef SERIAL_CLI
CLI_WRAPPER (sf_sql_transact, (long op, caddr_t * replicate), (op, replicate))
#define sf_sql_transact sf_sql_transact_w
#endif


int
sp_lt_check_error (client_connection_t * cli)
{
  /* Check and report trx error in local procedures
     use after qr_quick_exec. */
  lock_trx_t *lt = cli->cli_trx;
  if (lt && lt->lt_error != LTE_OK)
    {
      caddr_t err;
      MAKE_TRX_ERROR (lt->lt_error, err, LT_ERROR_DETAIL (lt));
      PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
      dk_free_tree (err);
      return 1;
    }
  else
    return 0;
}

long log_audit_trail = 0;

/* constructs an log name based on the original log name (from the settings) by inserting a timestamp
   right after the file name (before the extension).
   if the old name contains a valid timestamp (12 digits) at that location, then it's replaced
   the function also checks for the configuration parameter (log file size) and does not generate a new
   name if the current log file size is lower then the value specified
   Return value : if it shouldn't change the log file's name, then it returns NULL
 */
caddr_t
sf_make_new_log_name(dbe_storage_t * dbs)
{
  char *szExt, szNewName[255], szTS[15];
  caddr_t new_name = NULL, now;
  int n, name_len;
  TIMESTAMP_STRUCT ts;

  IN_TXN;

  if (!log_audit_trail || !dbs->dbs_log_name)
    goto end;

  now = bif_curdatetime(NULL, NULL, NULL);
  dt_to_timestamp_struct(now, &ts);
  snprintf(szTS, sizeof (szTS), "%04d%02d%02d%02d%02d%02d",
	ts.year, ts.month, ts.day, ts.hour, ts.minute, ts.second);
  dk_free_box(now);

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
  strcat_ck(szNewName, szTS);
  if (szExt)
    strcat_ck(szNewName, szExt);

  new_name = box_string(szNewName);

end:
  LEAVE_TXN;
  return new_name;
}

caddr_t
log_new_name(char * log_name)
{
  char *szExt, szNewName[255], szTS[21];
  caddr_t now;
  int n = 0, name_len;
  TIMESTAMP_STRUCT ts;
  timeout_t tu;
  now = bif_curdatetime(NULL, NULL, NULL);
  dt_to_timestamp_struct(now, &ts);
  get_real_time (&tu);
do_again:
  snprintf(szTS, sizeof (szTS), "%04d%02d%02d%02d%02d%02d%06ld",
	ts.year, ts.month, ts.day, ts.hour, ts.minute, ts.second, (long)(tu.to_usec));

  szExt = strrchr(log_name, '.');

  name_len = (int) (ptrlong) szExt ? (int) (ptrlong) (szExt - log_name) : (int) (ptrlong) strlen(log_name);

  if (name_len >= 14)
  {
    for (n = 0; n < 14; n++)
      if (!isdigit(log_name[name_len - n - 1]))
	break;
    if (n == 14)
      name_len -= 14;
  }

  if (name_len >= 6 && n == 14) /* for compatibility if name of the log contains a useconds */
    {
      for (n = 0; n < 6; n++)
	if (!isdigit(log_name[name_len - n - 1]))
	  break;
      if (n == 6)
	name_len -= 6;
    }

  if (name_len > 0)
    {
      strncpy(szNewName, log_name, name_len);
      szNewName[name_len] = 0;
    }
  else
    szNewName[0] = 0;
  strcat_ck(szNewName, szTS);
  if (szExt)
    strcat_ck(szNewName, szExt);

  if (!strcmp (szNewName,log_name))
    {
      tu.to_usec++; /* we count that in one second the usec's cannot be equal */
      goto do_again;
    }

  dk_free_box(now);
  return (box_string(szNewName));
}


caddr_t
sf_make_new_main_log_name(void)
{
  return sf_make_new_log_name(wi_inst.wi_master);
}

unsigned long min_checkpoint_size = 2048 * 1024;
unsigned long autocheckpoint_log_size = 0;

void
sf_make_auto_cp(void)
{
  int make_cp = 0;
  IN_TXN;
  make_cp = (wi_inst.wi_master->dbs_log_length >= min_checkpoint_size ||
	     wi_inst.wi_master->dbs_log_length >= autocheckpoint_log_size)
    ? 1 : 0;
  if (server_lock.sl_owner || local_cll.cll_atomic_trx_id)
    make_cp = 0;
  LEAVE_TXN;
  if (make_cp)
    {
      long now;
      sf_makecp (sf_make_new_log_name(wi_inst.wi_master), NULL, 1, CPT_NORMAL);
      now = approx_msec_real_time ();
      checkpointed_last_time = (unsigned long int) now; /* the main thread still running so set last time auto cpt finished */
    }
}

long c_checkpoint_vdb_abort = 0;

client_connection_t *autocheckpoint_cli;

void
sf_makecp (char *log_name, lock_trx_t *trx, int fail_on_vdb, int shutdown)
{
  int need_mtx = !srv_have_global_lock(THREAD_CURRENT_THREAD);
  if (in_log_replay)
    {
      log_info ("Host %d: Checkpoint invoked during log replay, ignoring.", local_cll.cll_this_host);
      return;
    }
  if (need_mtx)
    IN_CPT (trx);
  else if (trx)
    {
      IN_TXN;
      lt_threads_dec_inner (trx);
      LEAVE_TXN;
    }

  if (c_checkpoint_interval == -1 && THREAD_CURRENT_THREAD  == the_main_thread)
    {
      if (need_mtx)
        LEAVE_CPT(trx);
      else if (trx)
	{
	  IN_TXN;
	  lt_threads_inc_inner (trx);
	  LEAVE_TXN;
	}

      return;
    }


  IN_TXN;
  dbs_checkpoint (log_name, shutdown);
  LEAVE_TXN;
  if (need_mtx && !shutdown)
    LEAVE_CPT(trx);
  else if (trx && !shutdown)
    {
      IN_TXN;
      lt_threads_inc_inner (trx);
      LEAVE_TXN;
    }
  return;
}

void (*db_exit_hook) (void);

#ifdef PLDBG

static void
cov_store (void)
{
  caddr_t err;
  caddr_t * params;
  query_t * proc;
  if (!(pl_debug_all & 2) || !pl_debug_cov_file)
    return;
  proc = sch_proc_def (wi_inst.wi_schema, "DB.DBA.COV_STORE");
  if (!proc)
    return;
  if (proc->qr_to_recompile)
    proc = qr_recompile (proc, NULL);
  lt_enter (bootstrap_cli->cli_trx);
  IN_TXN;
  lt_threads_set_inner (bootstrap_cli->cli_trx, 1);
  lt_rollback (bootstrap_cli->cli_trx, TRX_CONT);
  LEAVE_TXN;
  if (proc->qr_to_recompile)
    proc = qr_recompile (proc, NULL);
  params = (caddr_t *) list (2, box_dv_short_string (pl_debug_cov_file), box_num(0));
  err = qr_exec (bootstrap_cli, proc, CALLER_LOCAL, NULL, NULL, NULL,
		 params, NULL, 0);
  dk_free_box ((caddr_t) params);
  local_commit (bootstrap_cli);
  IN_TXN;
  lt_leave (bootstrap_cli->cli_trx);
  LEAVE_TXN;
  if (IS_BOX_POINTER (err))
    log_error ("Error in COV_STORE: %s %s", ERR_STATE (err), ERR_MESSAGE (err));
}
#endif

void
dbev_shutdown (void)
{
  caddr_t err;
  caddr_t * params;
  query_t * proc;
  proc = sch_proc_exact_def (wi_inst.wi_schema, "DB.DBA.DBEV_SHUTDOWN");
  if (!proc)
    return;
  if (proc->qr_to_recompile)
    proc = qr_recompile (proc, NULL);
  lt_enter (bootstrap_cli->cli_trx);
  IN_TXN;
  lt_threads_set_inner (bootstrap_cli->cli_trx, 1);
  lt_rollback (bootstrap_cli->cli_trx, TRX_CONT);
  LEAVE_TXN;
  params = (caddr_t *) list (0);
  err = qr_exec (bootstrap_cli, proc, CALLER_LOCAL, NULL, NULL, NULL,
		 params, NULL, 0);
  dk_free_box ((caddr_t) params);
  local_commit (bootstrap_cli);
  IN_TXN;
  lt_leave (bootstrap_cli->cli_trx);
  LEAVE_TXN;
  if (IS_BOX_POINTER (err))
    log_error ("Error in DBEV_SHUTDOWN: %s %s", ERR_STATE (err), ERR_MESSAGE (err));
}


void
sf_fastdown (lock_trx_t * trx)
{
  long ena = dbev_enable;
  dbev_enable = 0;
  PrpcDisconnectAll ();
#ifdef PLDBG
  cov_store ();
#endif
  if (ena)
    dbev_shutdown ();
  IN_CPT(trx);
  IN_TXN;
  PrpcLeave ();
  DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_storage)
    {
      /*dbs_close (wi_inst.wi_master);*/
      dbs_close (dbs);
    }
  END_DO_SET();
  if (db_exit_hook)
    (*db_exit_hook) ();
  call_exit (0);
}


void
sf_shutdown (char *log_name, lock_trx_t * trx)
{
  long ena = dbev_enable;
  dbev_enable = 0;

#ifdef PLDBG
  cov_store ();
#endif
  if (ena)
    dbev_shutdown ();

  sf_makecp (log_name, trx, 0, CPT_SHUTDOWN);

  PrpcDisconnectAll ();

  IN_TXN;
  PrpcLeave ();
#if defined (MALLOC_DEBUG) || defined (VALGRIND)
  while (NULL != static_qr_dllist)
    qr_free (static_qr_dllist);
#endif
  DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_storage)
  {
    dbs_close (dbs);
  }
  END_DO_SET ();

#if defined (MALLOC_DEBUG) || defined (VALGRIND)
  wi_close ();

  shuric_terminate_module ();
  dkbox_terminate_module ();

#endif

#ifdef MALLOC_DEBUG
   dbg_dump_mem ();
#endif

  if (db_exit_hook)
    (*db_exit_hook) ();
  call_exit (0);
}


void
sf_sql_get_data_trx_error (int code, caddr_t err_detail)
{
  caddr_t err;
  MAKE_TRX_ERROR (code, err, err_detail);
  PrpcAddAnswer ((caddr_t) err, DV_ARRAY_OF_POINTER, FINAL, 1);
  dk_free_tree ((caddr_t) err);
}


void
sf_sql_get_data (caddr_t stmt_id, long current_of, long nth_col,
    long how_much, long starting_at)
{
  int is_timeout;
  dk_session_t *client = IMMEDIATE_CLIENT_OR_NULL;
  client_connection_t *cli = DKS_DB_DATA (client);
  lock_trx_t *lt;
  srv_stmt_t *stmt = cli_get_stmt_access (cli, stmt_id, GET_ANY, NULL);
  if (stmt->sst_inst)
    {
      query_instance_t *qi = stmt->sst_inst;
      caddr_t val;
      qi->qi_threads--;		/* no further business w/ qi, only w/ trx */
      lt = qi->qi_trx;
      if (LTE_OK != (is_timeout = lt_enter (lt)))
	{
	  LEAVE_CLIENT (cli);
	  thrs_printf ((thrs_fo, "ses %p thr:%p in getdata1\n", client, THREAD_CURRENT_THREAD));
	  DKST_RPC_DONE (client);
	  sf_sql_get_data_trx_error (is_timeout, LT_ERROR_DETAIL (lt));
	  return;
	}
      val = qi_nth_col (qi, current_of, nth_col - 1);
      LEAVE_CLIENT (cli);
      if (IS_BLOB_HANDLE (val))
	{
	  blob_send_bytes (qi->qi_trx, val, how_much, 0);
	}
      else
	{
	  PrpcAddAnswer (val, DV_LONG_STRING, 0, 1);
	}
      IN_TXN;
      is_timeout = lt_leave (lt);
      LEAVE_TXN;
      if (LTE_OK != is_timeout)
	{
	  thrs_printf ((thrs_fo, "ses %p thr:%p in getdata2\n", client, THREAD_CURRENT_THREAD));
	  DKST_RPC_DONE (client);
	  return;
	}
      thrs_printf ((thrs_fo, "ses %p thr:%p in getdata3\n", client, THREAD_CURRENT_THREAD));
      DKST_RPC_DONE (client);
      session_flush (client);
      /* flush blob only after you've left the statement */
      return;
    }
  LEAVE_CLIENT (cli);
  thrs_printf ((thrs_fo, "ses %p thr:%p in getdata4\n", client, THREAD_CURRENT_THREAD));
  DKST_RPC_DONE (client);
  PrpcAddAnswer (0, DV_SHORT_STRING, 0, 1);
}

#ifdef SERIAL_CLI
CLI_WRAPPER (sf_sql_get_data,
	(caddr_t stmt_id, long current_of, long nth_col,
	 long how_much, long starting_at),
	(stmt_id, current_of,  nth_col, how_much, starting_at))
#define sf_sql_get_data sf_sql_get_data_w
#endif




int
#ifdef CHECK_LT_THREADS
lt_enter_real (lock_trx_t * lt)
#else
lt_enter (lock_trx_t * lt)
#endif
{
  int rc;
  IN_TXN;
  CHECK_DK_MEM_RESERVE (lt);
  if (LT_PENDING == lt->lt_status)
    {
      rc = LTE_OK;
#ifdef INPROCESS_CLIENT
      if (!IS_INPROCESS_CLIENT (lt->lt_client))
#endif
	{
	  lt_threads_inc_inner (lt);
	}
    }
  else
  {
    rc = lt->lt_error == LTE_OK ? LTE_DEADLOCK : lt->lt_error;
  }
  LEAVE_TXN;
  return rc;
}


int
lt_enter_anyway (lock_trx_t * lt)
{
  /* enter the trx.  If it is being rolled back, wait.  if it is not pending, roll back */
  int rc;
  IN_TXN;
  if (LT_CLOSING == lt->lt_status)
    {
      lt_wait_until_dead (lt);
      lt->lt_threads++;
      LEAVE_TXN;
      return LTE_DEADLOCK;
    }
  if (LT_PENDING == lt->lt_status)
    {
      rc = LTE_OK;
#ifdef INPROCESS_CLIENT
      if (!IS_INPROCESS_CLIENT (lt->lt_client))
#endif
	{
	  lt_threads_inc_inner (lt);
	}
    }
  else
  {
    rc = lt->lt_error == LTE_OK ? LTE_DEADLOCK : lt->lt_error;
    lt->lt_threads++;
    lt_rollback (lt, TRX_CONT);
  }
  LEAVE_TXN;
  return rc;
}


void
sf_sql_get_data_ac (long dp_from, long how_much, long starting_at, long bh_key_id, long bh_frag_no, long page_dir, caddr_t page_array, long is_wide, long timestamp)
{
  int is_timeout;
  dk_session_t *client = IMMEDIATE_CLIENT_OR_NULL;
  client_connection_t *cli = DKS_DB_DATA (client);
  lock_trx_t *trx;
  dtp_t bh_tag = is_wide ? DV_BLOB_WIDE_HANDLE : DV_BLOB_HANDLE;
  blob_handle_t * bh = bh_alloc (bh_tag);
  dbe_key_t *key;

  if (KI_TEMP == bh_key_id)
    {
      caddr_t err;
      err = srv_make_new_error ("37000", "SR486", "Ask data from client RPC is not supported for BLOB stored into the temp space");
      DKST_RPC_DONE (client);
      PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, FINAL, 1);
      dk_free_tree (err);
      bh_free (bh);
      session_flush (client);
      return;
    }

  bh->bh_page = dp_from;
  bh->bh_current_page = dp_from;
  bh->bh_dir_page = page_dir;
  bh->bh_pages = (dp_addr_t *) page_array;
  if (box_length ((caddr_t) page_array) / sizeof (dp_addr_t) > BL_DPS_ON_ROW
      && 0 == bh->bh_pages[BL_DPS_ON_ROW])
    bh->bh_page_dir_complete = 0;
  else
    bh->bh_page_dir_complete = 1;
  bh->bh_position = starting_at;
  bh->bh_key_id = (unsigned short) bh_key_id;
  bh->bh_frag_no = (short) bh_frag_no;
  bh->bh_timestamp = timestamp;
  key = sch_id_to_key (isp_schema (NULL), bh->bh_key_id);
  if (!key)
    GPF_T1 ("Non-valid key_id in sf_sql_get_data_ac");
  bh->bh_it = key->key_fragments[0]->kf_it;
  if (LTE_OK != (is_timeout = lt_enter (cli->cli_trx)))
    {
      caddr_t err;
      MAKE_TRX_ERROR (is_timeout, err, LT_ERROR_DETAIL (cli->cli_trx));
      thrs_printf ((thrs_fo, "ses %p thr:%p in getdata_ac1\n", client, THREAD_CURRENT_THREAD));
      DKST_RPC_DONE (client);
      PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, FINAL, 1);
      dk_free_tree (err);
      bh_free (bh);
      session_flush (client);
      return;
    }
  trx = cli->cli_trx;
  blob_send_bytes (trx, (caddr_t) bh, how_much, 1);

  IN_TXN;
  is_timeout = lt_leave (trx);
  LEAVE_TXN;
  thrs_printf ((thrs_fo, "ses %p thr:%p in getdata_ac2\n", client, THREAD_CURRENT_THREAD));
  DKST_RPC_DONE (client);
  session_flush (client);	/* flush blob only after you've left the statement */
  bh_free (bh);
  return;
}


#ifdef SERIAL_CLI
CLI_WRAPPER (sf_sql_get_data_ac,
	(long dp_from, long how_much, long starting_at, long bh_key_id, long bh_frag_no, long page_dir, caddr_t page_array, long is_wide, long timestamp),
	(dp_from, how_much, starting_at, bh_key_id, bh_frag_no, page_dir, page_array, is_wide, timestamp))
#define sf_sql_get_data_ac sf_sql_get_data_ac_w
#endif

SERVICE_1 (s_sql_no_threads, ssqlnth, "no_threads", DA_FUTURE_REQUEST, DV_SEND_NO_ANSWER, DV_LONG_INT, 1);

#define NO_THREADS_REPORT_PERIOD   10 * 60 /* 10 min */

uint32 n_total_no_threads = 0;

caddr_t
sf_sql_no_threads_reply (void)
{
  static long last_checked_time = 0;
  static uint32 n_hits_per_period = 0;
  long time_now;
  dk_session_t *client = IMMEDIATE_CLIENT_OR_NULL;
  caddr_t err = srv_make_new_error ("40001", "SR214",
      "Out of server threads. Server temporarily unavailable. Transaction rolled back.");
  thrs_printf ((thrs_fo, "ses %p thr:%p in sf_sql_no_threads_reply1\n", client, THREAD_CURRENT_THREAD));

  if (!DK_CURRENT_THREAD->dkt_requests[0]->rq_is_second)
    {
      mutex_enter (thread_mtx);
      DKST_RPC_DONE_NO_MTX (client);
      n_total_no_threads ++;
      n_hits_per_period ++;

      time_now = approx_msec_real_time ();
      if (!last_checked_time)
	last_checked_time = time_now;
      else if ((time_now - last_checked_time) / 1000 > NO_THREADS_REPORT_PERIOD)
	{
	  if (n_hits_per_period > 0)
	    log_warning ("The server was out of server threads %ld times for the last %ld secs."
		"Consider increasing the ServerThreads INI parameter (Parameters section)",
		(long) n_hits_per_period, (time_now - last_checked_time) / 1000);
	  last_checked_time = time_now;
	  n_hits_per_period = 0;
	}
      mutex_leave (thread_mtx);
    }

  PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
  dk_free_tree (err);

  return 0;
}


void
frq_no_thread_reply (future_request_t * frq)
{
#if 0
  dk_thread_t * self = DK_CURRENT_THREAD;
  caddr_t err = srv_make_new_error ("40001", "XXX", "Out of server threads. Server temporarily unavailable. Transaction rolled back.");
  self->dkt_request_count = 1;
  self->dkt_requests[0] = frq;
  PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
  self->dkt_request_count = 0;
  self->dkt_requests[0] = NULL;
  dk_free_tree (err);
#else
  dk_free_tree ((caddr_t) frq->rq_arguments);
  frq->rq_arguments = (long**) list (01, 0);
  frq->rq_service = find_service ("no_threads");
#endif
}


void
sf_overflow (future_request_t * frq)
{
  client_connection_t * cli = DKS_DB_DATA (frq->rq_client);
  lock_trx_t * lt;
  IN_TXN;
  lt = cli->cli_trx;
  if (0 == lt->lt_threads)
    {
      TC (tc_no_thread_kill_idle);
      lt_threads_set_inner (lt, 1);
      lt_rollback (lt, TRX_CONT);
      lt_leave (lt);
    }
  else
    {
      if (lt->lt_vdb_threads)
	{
	  TC (tc_no_thread_kill_vdb);
	  lt->lt_status = LT_BLOWN_OFF;
	  lt->lt_error = LTE_DEADLOCK;
	}
      else
	{
	  TC (tc_no_thread_kill_running);
	  if (LT_DELTA_ROLLED_BACK != lt->lt_status)
	    lt_kill_other_trx (lt, NULL, NULL, LT_KILL_ROLLBACK);
	}
    }
  LEAVE_TXN;
  frq_no_thread_reply (frq);
}


int
sf_no_threads (future_request_t * frq)
{
  service_t * sv = frq->rq_service;
  if (NULL != sv && (server_func) sf_sql_execute == sv->sr_func)
    {
      stmt_options_t * so = (stmt_options_t *) frq->rq_arguments[5];
      if (0 && so->so_autocommit)
	return 1;
      sf_overflow (frq);
      return 1;
    }
  if (NULL != sv && ((server_func) sf_sql_fetch == sv->sr_func
      ||  (server_func) sf_sql_extended_fetch == sv->sr_func
      ||  (server_func) sf_sql_transact == sv->sr_func
      ||  (server_func) sf_sql_free_stmt == sv->sr_func
      ||  (server_func) sf_sql_get_data_ac == sv->sr_func
      ))
    {
      sf_overflow (frq);
      return 1;
    }
  return 1;
}


#ifdef UNIX
unsigned ptrlong initbrk;
#endif


int
box_flags_serial_test (dk_session_t * ses)
{
  /* serialize box flags only for clients that are 3029 or newer.  Do not serialize this if going to non-client.  */
  client_connection_t *cli = DKS_DB_DATA (ses);
  if (ses->dks_cluster_flags & (DKS_TO_CLUSTER | DKS_TO_OBY_KEY | DKS_TO_HA_DISK_ROW | DKS_TO_DC | DKS_REPLICATION))
    return 1;
  if (!cli)
    return 0;
  if (cli && cli->cli_version < 3029)
    return 0;
  return 1;
}


void
numeric_serialize_client (caddr_t n, dk_session_t * ses)
{
  client_connection_t *cli = DKS_DB_DATA (ses);
  if (cli && cli->cli_version < 1731)
    {
      double d;
      numeric_to_double ((numeric_t) n, &d);
      print_double (d, ses);
    }
  else
    numeric_serialize ((numeric_t) n, ses);
}

void
int64_serialize_client (caddr_t n1, dk_session_t * session)
{
  client_connection_t *cli = DKS_DB_DATA (session);
  boxint n = *(boxint*)n1;
  union {
    int64 n64;
    struct {
      int32 n1;
      int32 n2;
    } n32;
  } num;
  if (cli && cli->cli_version < 3016)
    {
      NUMERIC_VAR(tnum);
      numeric_from_int64 ((numeric_t)&tnum, n);
      numeric_serialize_client ((caddr_t)&tnum, session);
    }
  else
    {
      session_buffered_write_char (DV_INT64, session);
      num.n64 = n;
#if WORDS_BIGENDIAN
      print_long (num.n32.n1, session);
      print_long (num.n32.n2, session);
#else
      print_long (num.n32.n2, session);
      print_long (num.n32.n1, session);
#endif
    }
}


void
wide_serialize_client (caddr_t n, dk_session_t * ses)
{
  client_connection_t *cli = DKS_DB_DATA (ses);
  if (cli && cli->cli_version < 1831)
    {
      caddr_t n1 = box_wide_string_as_narrow (n, NULL, 0, cli->cli_charset);
      print_string (n1, ses);
      dk_free_box (n1);
    }
  else
    wide_serialize (n, ses);
}


extern long dbf_cl_blob_autosend_limit;


int
bh_is_remote (blob_handle_t * bh)
{
  return 0;
}


void
bh_serialize_to_client (blob_handle_t *bh, dk_session_t *ses)
{
  client_connection_t *cli = DKS_DB_DATA (ses);
  int is_utf8 = DV_TYPE_OF (bh) == DV_BLOB_WIDE_HANDLE ? 1 : 0;

  if (bh->bh_send_as_bh)
    {
      bh_serialize (bh, ses);
      return;
    }
  if (!cli && BLOB_NULL_RECEIVED != bh->bh_all_received && !bh->bh_ask_from_client)
    { /* serialize as string when not on the ODBC connection */
      caddr_t obj;
      cli = sqlc_client ();
      if ((DKS_TO_CLUSTER & ses->dks_cluster_flags) && (bh->bh_diskbytes > dbf_cl_blob_autosend_limit || bh_is_remote (bh)))
	{
	  /* for cluster operands  over a limit length, send the bh and have the party ask for the data */
	  bh_serialize (bh, ses);
	  return;
	}
      if (bh->bh_length > MAX_READ_STRING / (is_utf8 ? (2 + sizeof (wchar_t)) : 1))
	obj = (caddr_t) blob_to_string_output (cli->cli_trx, (caddr_t) bh);
      else
	obj = blob_to_string (cli->cli_trx, (caddr_t) bh);

      print_object (obj, ses, NULL, NULL);

      dk_free_tree (obj);
    }
  else
    {
      if (is_utf8)
	bh_serialize_wide (bh, ses);
      else
	bh_serialize (bh, ses);
    }
}


void
bh_serialize_xper_to_client (blob_handle_t *bh, dk_session_t *ses)
{
  client_connection_t *cli = DKS_DB_DATA (ses);
  if (!cli && BLOB_NULL_RECEIVED != bh->bh_all_received && !bh->bh_ask_from_client)
    { /* it's an error to serialize a xper when not on the ODBC connection */
      SESSTAT_CLR (ses->dks_session, SST_OK);
      SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
      longjmp_splice (&SESSION_SCH_DATA (ses)->sio_write_broken_context, 1);
    }
  else
    bh_serialize_xper (bh, ses);
}


void
blobio_compatibility_init (void)
{
  PrpcSetWriter (DV_BLOB_HANDLE, (ses_write_func) bh_serialize_to_client);
  PrpcSetWriter (DV_BLOB_XPER_HANDLE, (ses_write_func) bh_serialize_xper_to_client);
  PrpcSetWriter (DV_BLOB_WIDE_HANDLE, (ses_write_func) bh_serialize_to_client);
}


void
srv_compatibility_init (void)
{
  PrpcSetWriter (DV_NUMERIC, (ses_write_func) numeric_serialize_client);
  PrpcSetWriter (DV_WIDE, (ses_write_func) wide_serialize_client);
  PrpcSetWriter (DV_LONG_WIDE, (ses_write_func) wide_serialize_client);
  int64_serialize_client_f = (ses_write_func) int64_serialize_client;
  box_flags_serial_test_hook = box_flags_serial_test;
  blobio_compatibility_init ();
}

long srv_pid = 0;
long srv_cpu_count = 4;


void
dbev_startup (void)
{
  caddr_t err;
  caddr_t * params;
  query_t * proc;
  if (!dbev_enable)
    return;
  proc = sch_proc_exact_def (wi_inst.wi_schema, "DB.DBA.DBEV_STARTUP");
  if (!proc)
    return;
  if (proc->qr_to_recompile)
    proc = qr_recompile (proc, NULL);
  params = (caddr_t *) list (0);
  err = qr_exec (bootstrap_cli, proc, CALLER_LOCAL, NULL, NULL, NULL,
		 params, NULL, 0);
  dk_free_box ((caddr_t) params);
  local_commit (bootstrap_cli);
  if (IS_BOX_POINTER (err))
    log_error ("Error in DBEV_startup: %s %s", ERR_STATE (err), ERR_MESSAGE (err));
}

#ifdef PLDBG
void
cov_load (void)
{
  caddr_t err;
  caddr_t * params;
  query_t * proc;
  if (!(pl_debug_all & 2) || !pl_debug_cov_file)
    return;
  proc = sch_proc_def (wi_inst.wi_schema, "DB.DBA.COV_LOAD");
  if (!proc)
    return;
  if (proc->qr_to_recompile)
    proc = qr_recompile (proc, NULL);
  params = (caddr_t *) list (1, box_dv_short_string (pl_debug_cov_file));
  err = qr_exec (bootstrap_cli, proc, CALLER_LOCAL, NULL, NULL, NULL,
		 params, NULL, 0);
  dk_free_box ((caddr_t) params);
  local_commit (bootstrap_cli);
  if (IS_BOX_POINTER (err))
    log_error ("Error in COV_LOAD: %s %s", ERR_STATE (err), ERR_MESSAGE (err));
}
#endif

char * bpel_check_proc =
"create procedure RESTART_ALL_BPEL_INSTANCES ()\n"
"{\n"
"  declare pkgs any;\n"
"  pkgs := \"VAD\".\"DBA\".\"VAD_GET_PACKAGES\" ();\n"
"  if (pkgs is not null)\n"
"    {\n"
"      declare idx int;\n"
"      while (idx < length (pkgs))\n"
"        {\n"
"          if (pkgs[idx][1] = 'bpel4ws')\n"
"            {\n"
"              BPEL..restart_all_instances();\n"
"            }\n"
"          idx := idx + 1;\n"
"        }\n"
"    }\n"
"}\n";

#define NO_LITE(f) if (!lite_mode) f ();
extern int cl_no_init;
extern int c_query_log;


void
sql_code_global_init ()
{
  if (0 && cluster_enable && cl_no_init)
    return;
  if (c_query_log)
    ddl_ensure_table ("do this always",  "prof_enable (1)");
  sqls_define_sys ();
  sqls_define ();
  sqls_define_sparql ();
  if (CL_RUN_LOCAL == cl_run_local_only)
    sas_ensure ();
  NO_LITE (sqls_define_ddk);
  NO_LITE (sqls_define_repl);
  NO_LITE (sqls_define_ws);
  NO_LITE (sqls_define_dav);
  sqls_define_1 ();
  cache_resources();
  NO_LITE (sqls_define_2pc);
  NO_LITE (sqls_define_blog);
  NO_LITE (sqls_define_pldbg);
  NO_LITE (sqls_define_adm);
#ifdef VAD
  NO_LITE (sqls_define_vad);
  ddl_ensure_table ("do this always", bpel_check_proc);
#endif
  NO_LITE (sqls_define_dbp);
  NO_LITE (sqls_define_uddi);
  NO_LITE (sqls_define_imsg);
  NO_LITE (sqls_define_auto);
  ddl_sel_for_effect ("select count (*) from DB.DBA.SYS_XPF_EXTENSIONS where xpf_extension (XPE_NAME, XPE_PNAME, 0)");
#ifdef _SSL
  /* do load of the persisted encryption keys */
  ddl_sel_for_effect ("select count (*) from DB.DBA.SYS_USERS where U_IS_ROLE = 0 and U_OPTS is not null and USER_KEYS_INIT (U_NAME, U_OPTS)");
#endif

  qr_dotnet_get_assembly_real = sql_compile ("SELECT VAC_REAL_NAME from DB.DBA.CLR_VAC where VAC_INTERNAL_NAME=?", bootstrap_cli, NULL, 0);

}


void
sql_code_arfw_global_init ()
{
  int was_col  = enable_col_by_default;
  enable_col_by_default = 0;
/*
  ddl_scheduler_arfw_init ();
*/
  sqls_arfw_define_sys ();
  sqls_arfw_define_sparql ();
  sqls_arfw_define ();
  NO_LITE (sqls_arfw_define_blog);
  sqls_arfw_define_1 ();
  NO_LITE (sqls_arfw_define_ddk);
  NO_LITE (sqls_arfw_define_repl);
  NO_LITE (sqls_arfw_define_ws);
  NO_LITE (sqls_arfw_define_dav);
  NO_LITE (sqls_arfw_define_pldbg);

  NO_LITE (sqls_arfw_define_adm);
#ifdef VAD
  NO_LITE (sqls_arfw_define_vad);
#endif
  NO_LITE (sqls_arfw_define_dbp);
  NO_LITE (sqls_arfw_define_uddi);
  NO_LITE (sqls_arfw_define_imsg);
  NO_LITE (sqls_arfw_define_auto);
  enable_col_by_default = was_col;
}


static srv_req_hook_func before_cancel_hook = NULL;


static void
lt_kill_waiting_trx (lock_trx_t *lt, int lt_error)
{
  ASSERT_IN_TXN;
  if (lt->lt_threads > 0 &&
      (lt->lt_lw_threads > 0 || lt->lt_vdb_threads > 0))
    {
#ifdef CHECK_LT_THREADS
      int			lt_threads;
      int			lt_lw_threads;
      int			lt_close_ack_threads;
      int			lt_vdb_threads;
      int 			lt_status;

      lt_status = lt->lt_status;
      lt_vdb_threads = lt->lt_vdb_threads;
      lt_close_ack_threads = lt->lt_close_ack_threads;
      lt_lw_threads = lt->lt_lw_threads;
      lt_threads = lt->lt_threads;
#endif

      lt_log_debug (("killing other trx %p (status %d) because of %d on thread %p",
	  lt, lt->lt_status, lt_error, THREAD_CURRENT_THREAD));
      lt->lt_error = lt_error;
      if (LT_DELTA_ROLLED_BACK != lt->lt_status)
	lt_kill_other_trx (lt, NULL, NULL, LT_KILL_ROLLBACK);
    }
}


static caddr_t
sf_sql_cancel_hook (dk_session_t* session, caddr_t _request)
{
  ptrlong *request  = (ptrlong *) _request;
  if (session && request && request[DA_MESSAGE_TYPE] == DA_FUTURE_REQUEST &&
      !strcmp ((char *) request[FRQ_SERVICE_NAME], "CANCEL"))
    {
      client_connection_t *cli = DKS_DB_DATA (session);
      if (cli)
	{
	  cli->cli_terminate_requested = CLI_TERMINATE;
	  IN_TXN;
	  if (cli->cli_trx)
	    lt_kill_waiting_trx (cli->cli_trx, LTE_TIMEOUT);
	  LEAVE_TXN;
	  dk_free_tree ((box_t) request);
	  return NULL;
	}
    }
  if (before_cancel_hook)
    return before_cancel_hook (session, _request);
  else
    return _request;
}

long msec_session_space_clear;

static void
futures_object_space_clear (caddr_t b, future_request_t *f)
{
  client_connection_t *cli;
  /* OBJECT_SPACE_CLEAR; This is wrong if DV_REFERENCE is not actually copied by box_copy */

  sql_warnings_clear ();
  msec_session_space_clear = get_msec_real_time ();
  cli = GET_IMMEDIATE_CLIENT_OR_NULL;
  if (cli && cli->cli_trx && cli->cli_trx->lt_is_excl)
    {
      while (srv_have_global_lock (THREAD_CURRENT_THREAD))
	srv_global_unlock (cli, cli->cli_trx);
    }
}

static void
PrpcRegisterServiceDesc1 (service_desc_t * desc, server_func f)
{
  PrpcRegisterService (desc->sd_name, f, NULL, desc->sd_return_type, futures_object_space_clear);
}

typedef void (*ddl_init_hook_t) (client_connection_t *cli);
ddl_init_hook_t ddl_init_hook = NULL;

ddl_init_hook_t
set_ddl_init_hook (ddl_init_hook_t new_ddl_init_hook)
{
  ddl_init_hook_t old_ddl_init_hook = ddl_init_hook;
  ddl_init_hook = new_ddl_init_hook;
  return old_ddl_init_hook;
}


void
srv_plugins_init (void)
{
  if (lite_mode)
    return;
  langfunc_plugin_init ();
  hosting_plugin_init ();
  /* init for common type plugin */
  plugin_loader_init();
}


#ifdef INPROCESS_CLIENT

static void *
sql_inprocess_enter (dk_session_t *inpses)
{
  client_connection_t * cli = GET_IMMEDIATE_CLIENT_OR_NULL;
  void ** data = (void **) dk_alloc (2 * sizeof (void *));

  data[0] = cli->cli_http_ses;
  data[1] = cli->cli_ws;
  cli->cli_http_ses = NULL;
  cli->cli_ws = NULL;
  DKS_DB_DATA (inpses) = cli;
  cli->cli_inprocess = 1;

  return data;
}

static void
sql_inprocess_leave (void * vp)
{
  client_connection_t * cli = GET_IMMEDIATE_CLIENT_OR_NULL;
  void ** data = (void **) vp;

  cli->cli_http_ses = (dk_session_t *) data[0];
  cli->cli_ws = (struct ws_connection_s *) data[1];
  cli->cli_inprocess = 0;

  dk_free (vp, 2 * sizeof (void *));
}

#endif

int threads_is_fiber = 0;

static void
srv_global_init_clear_table (char *stmt)
{
  caddr_t err = NULL;
  query_t *qr;

  qr = sql_compile (stmt, bootstrap_cli, &err, SQLC_DEFAULT);
  if (!err)
    {
      err = qr_quick_exec (qr, bootstrap_cli, NULL, NULL, 0);
      qr_free (qr);
    }
}


static void
srv_global_init_drop ()
{
  id_hash_iterator_t hit;
  char ** tn;
  caddr_t * piter;id_hash_iterator (&hit, wi_inst.wi_schema->sc_name_to_object[sc_to_table]);
  while (hit_next (&hit, (caddr_t*)&tn, (caddr_t*)&piter))
    {
      id_casemode_entry_llist_t *iter = *(id_casemode_entry_llist_t **)piter;
      for (iter = iter; iter; iter = iter->next)
	{
	  dbe_table_t * tb = (dbe_table_t*)iter->data;
	  if (tb->tb_primary_key->key_id <= KI_UDT)
	    continue;
	  tb_mark_affected (tb->tb_name);
	  DO_SET (dbe_key_t *, key, &tb->tb_keys)
	    {
	      it_cursor_t itc_auto;
	      it_cursor_t * itc = &itc_auto;
	      ITC_INIT (itc, NULL, bootstrap_cli->cli_trx);
	      itc_drop_index (itc, key);
	      itc_free (itc);
	      key_dropped (key);
	    }
	  END_DO_SET();
	}
    }
}

static void
srv_session_disconnect_action (dk_session_t *ses)
{
  client_connection_t *cli = DKS_DB_DATA (ses);
  if (cli && ses->dks_to_close)
    {
      cli->cli_terminate_requested = CLI_TERMINATE;
      IN_TXN;
      if (cli->cli_trx)
        lt_kill_waiting_trx (cli->cli_trx, LTE_REMOTE_DISCONNECT);
      LEAVE_TXN;
    }
}

void   rdf_key_comp_init ();
extern int enable_col_by_default, c_col_by_default;
long get_total_sys_mem ();

void
srv_global_init (char *mode)
{
/* Sanity check for list, to detect errors like errors catched by AMD Opteron port */
#ifdef DEBUG
  caddr_t *probe = list (7, NULL, 1, 2, 3L, 4L, box_dv_short_string("5"), box_dv_short_string("6"));
  if (probe[0] != NULL) GPF_T1("list probe 0");
  if (probe[1] != 1) GPF_T1("list probe 1");
  if (probe[2] != 2) GPF_T1("list probe 2");
  if (probe[3] != 3) GPF_T1("list probe 3");
  if (probe[4] != 4) GPF_T1("list probe 4");
  if (probe[5][0] != '5') GPF_T1("list probe 5");
  if (probe[6][0] != '6') GPF_T1("list probe 6");
#endif

  db_read_cfg (NULL, mode);
  PrpcInitialize1 (lite_mode ? DK_ALLOC_RESERVE_DISABLED : DK_ALLOC_RESERVE_PREPARED);
  background_sem = semaphore_allocate (0);

  logins_list_initialize ();
  log_info ("%s", DBMS_SRV_NAME);
  log_info ("Version " DBMS_SRV_VER "%s for %s as of %s",
      build_thread_model, build_opsys_id, build_date);

  log_info ("uses parts of OpenSSL, PCRE, Html Tidy");

  mode_pass_change = 0;
  in_srv_global_init = 1;

  if (f_old_dba_pass && f_new_dba_pass && f_new_dav_pass)
    {
      log_info ("Starting for DBA password change.");
      mode_pass_change = 1;
    }

  srv_pid = getpid ();
  init_server_cwd ();
#ifdef UNIX
  initbrk = (unsigned ptrlong) sbrk (9);
#endif

#ifdef WIN32

  if (!OpenThreadToken (GetCurrentThread(), TOKEN_QUERY, FALSE, &server_imp_token))
    {
      if ( GetLastError() == ERROR_NO_TOKEN)
	{
	  HANDLE acess_token = NULL;
	  LPVOID lpMsgBuf;

	  if (!OpenProcessToken (GetCurrentProcess(), TOKEN_DUPLICATE | TOKEN_IMPERSONATE, &acess_token))
	    {
	      FormatMessage (FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
		  FORMAT_MESSAGE_IGNORE_INSERTS, NULL, GetLastError(),
		  MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),(LPTSTR) &lpMsgBuf, 0, NULL);
	      log_info ("Can't get server access token %s ", lpMsgBuf);
	      call_exit (-1);
	    }

	  if (!DuplicateToken (acess_token, 2, &server_imp_token))
	    {
	      FormatMessage (FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
		  FORMAT_MESSAGE_IGNORE_INSERTS, NULL, GetLastError(),
		  MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),(LPTSTR) &lpMsgBuf, 0, NULL);
	      log_info ("Can't get server impersonate token %s ", lpMsgBuf);
	      call_exit (-1);
	    }
	}
    }

/* USERS CAN'T LOGIN AFTER THIS.
   if (!SetThreadToken (NULL, server_imp_token))
    {
      log_info ("Can't set server Thread Token");
      call_exit (-1);
    }
*/

#endif

  wi_init_globals ();

  if (recover_file_prefix)
    {
      if (restore_from_files (recover_file_prefix) == -1)
	{
	  call_exit (1);
 	}
      return;
    }
  uname_const_decl_init ();
#ifdef BIF_XML
  html_hash_init ();
#endif
  dt_init ();
  dt_now (srv_approx_dt);
  cluster_init ();
#ifdef PLDBG
  if (lite_mode)
    pl_debug_all = 0;
#endif
  wi_open (mode);
  sql_bif_init ();
  bif_daq_init ();
  if (lite_mode)
    log_info ("Entering Lite Mode");

#ifdef VIRTTP
  if (!lite_mode)
    tp_main_queue_init();
#endif
  sqlc_set_client (bootstrap_cli);
  /*if (sqlo_enable)*/
    {
      if (sqlo_max_layouts)
	log_info ("SQL Optimizer enabled (max %d layouts)", sqlo_max_layouts);
      else
	log_info ("SQL Optimizer enabled (unlimited layouts)");
    }
    if (strchr (mode, 'o') || strchr (mode, 'D') )
    {
      ddl_init_schema();
      return;
    }
  ddl_init_schema ();
#ifdef BYTE_ORDER_REV_SUPPORT
  if (dbs_reverse_db)
    {
      dbs_write_reverse_db (wi_inst.wi_master);
      call_exit (0);
    }
#endif /* BYTE_ORDER_REV_SUPPORT */

  remote_init ();
  srv_compatibility_init ();  /* AFTER remote_init */
  registry_exec ();
  if (!strchr (mode, 'n'))
    {
      ddl_init_proc ();
    }
  if (!f_read_from_rebuilt_database)
    {
      srv_calculate_sqlo_unit_msec ();
    }
  the_main_thread = current_process;	/* Used by the_grim_lock_reaper */

  sec_init ();
  PrpcRegisterService ("SCON", (server_func) sf_sql_connect, NULL,
      DV_ARRAY_OF_POINTER, (post_func) dk_free_tree);
  PrpcRegisterServiceDesc1 (&s_sql_prepare, (server_func) sf_stmt_prepare);
  PrpcRegisterServiceDesc1 (&s_sql_execute, (server_func) sf_sql_execute);
  PrpcRegisterServiceDesc1 (&s_sql_fetch, (server_func) sf_sql_fetch);
  PrpcRegisterServiceDesc1 (&s_sql_transact, (server_func) sf_sql_transact);
  PrpcRegisterServiceDesc1 (&s_sql_free_stmt, (server_func) sf_sql_free_stmt);
  PrpcRegisterServiceDesc1 (&s_get_data, (server_func) sf_sql_get_data);
  PrpcRegisterServiceDesc1 (&s_get_data_ac, (server_func) sf_sql_get_data_ac);
  PrpcRegisterServiceDesc1 (&s_sql_extended_fetch, (server_func) sf_sql_extended_fetch);
  PrpcRegisterServiceDesc1 (&s_sql_no_threads, (server_func) sf_sql_no_threads_reply);
#ifdef VIRTTP
  PrpcRegisterServiceDesc1 (&s_sql_tp_transact, (server_func) sf_sql_tp_transact);
#endif

  PrpcSetBackgroundAction ((background_action_func) the_grim_lock_reaper);
  PrpcSetSessionDisconnectCallback (srv_session_disconnect_action);
  PrpcSetQueueHook (sf_no_threads);
  PrpcSetServiceRequestHook ((srv_req_hook_func) sf_sql_cancel_hook);

#ifdef INPROCESS_CLIENT
  PrpcSetInprocessHooks (sql_inprocess_enter, sql_inprocess_leave);
#endif

  /* crashdump log_init (on the command line NEW) */
  if (f_read_from_rebuilt_database)
    {
      if (!db_exists)
	{
	  srv_global_init_clear_table ("delete from DB.DBA.SYS_KEYS");
	  srv_global_init_clear_table ("delete from DB.DBA.SYS_COLS");
	  srv_global_init_clear_table ("delete from DB.DBA.SYS_KEY_PARTS");
	  srv_global_init_clear_table ("delete from DB.DBA.SYS_COLLATIONS");
	  srv_global_init_clear_table ("delete from DB.DBA.SYS_CHARSETS");
	  srv_global_init_clear_table ("delete from DB.DBA.SYS_USER_TYPES");
	  srv_global_init_clear_table ("delete from DB.DBA.SYS_KEY_SUBKEY");
	  srv_global_init_clear_table ("delete from DB.DBA.SYS_KEY_FRAGMENTS");
	  srv_global_init_drop ();
	  local_commit (bootstrap_cli);
	}
      sec_users = id_str_hash_create (101);
      sec_user_by_id = hash_table_allocate (101);
      sec_new_user (NULL, "dba", "dba");
      if (strchr (mode, 'b'))
	db_replay_registry_sequences ();
      else
	id_hash_clear (registry);
      log_init (wi_inst.wi_master);
      local_commit (bootstrap_cli);
      c_checkpoint_interval = 0;
      sf_makecp (sf_make_new_log_name(wi_inst.wi_master), bootstrap_cli->cli_trx, 1, CPT_NORMAL);
      IN_TXN;
      lt_leave (bootstrap_cli->cli_trx);
      LEAVE_TXN;
      return;
    }
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_IMMEDIATE_CLIENT, bootstrap_cli);
  ddl_scheduler_init ();

  ddl_repl_init ();

  ddl_fk_init ();
  db_replay_registry_sequences ();
  local_commit (bootstrap_cli);
  shcompo_init ();
#ifdef BIF_XML
  shuric_init ();
  ddl_init_xml ();
  ddl_text_init ();
  local_commit (bootstrap_cli);
  rdf_core_init ();
  sparql_init ();
#endif
  http_init_part_one ();
  sqlbif_sequence_init ();
  ddl_init_plugin ();
  sqlc_set_client (bootstrap_cli);
  if (!strchr (mode, 'a'))
    {
      sec_read_users ();
      sec_read_grants (NULL, NULL, NULL, 0);
      sec_read_tb_rls (NULL, NULL, NULL);
      sinv_read_sql_inverses (NULL, bootstrap_cli);
      cl_read_dpipes ();
/*      sqls_define_sparql_init ();*/
      read_proc_and_trigger_tables (1);
      read_proc_and_trigger_tables (0);
      sec_read_grants (NULL, NULL, NULL, 1); /* call second time to do read of execute grants */
      ddl_standard_procs ();
    }
/*  else if (!in_crash_dump)
    sqls_define_sparql_init ();*/
  ddl_obackup_init ();

  ddl_ensure_stat_tables ();
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_IMMEDIATE_CLIENT, bootstrap_cli);
  bootstrap_cli->cli_user = sec_id_to_user (U_ID_DBA);
  if (!in_crash_dump)
    sql_code_global_init ();
  /* and a third time to process grants over the sqls_define procs */
  if (!strchr (mode, 'a'))
    sec_read_grants (NULL, NULL, NULL, 1);
  read_utd_method_tables ();
  if (ddl_init_hook)
    ddl_init_hook (bootstrap_cli);
  local_commit (bootstrap_cli);
  if (!in_crash_dump && !db_exists)
    {
      /* if brand new, flush out the basic state so that can reopen without gpf reading the page sets */
      bootstrap_cli->cli_trx->lt_threads = 0;
      IN_TXN;
      dbs_checkpoint ((char *)-1, 0);
      LEAVE_TXN;
      bootstrap_cli->cli_trx->lt_threads = 1;
    }
  if (!f_read_from_rebuilt_database)
    {
      log_init (wi_inst.wi_master);
    }
  if (strchr (mode, 'r'))
    return;
  sqlc_set_client (bootstrap_cli);
  if (!in_crash_dump && cl_run_local_only == CL_RUN_LOCAL)
    {
      sql_code_arfw_global_init();
    }
  local_commit (bootstrap_cli);
#ifdef PLDBG
  if (!lite_mode)
    {
      pldbg_init ();
      cov_load ();
    }
#endif
  dbev_startup ();
  sqlc_hook_enable = 1;
  rdf_key_comp_init ();
  if (default_charset_name && !default_charset)
    log_error ("Default charset %.200s not defined. Reverting to ISO-8859-1", default_charset_name);
  if (init_trace)
    set_ini_trace_option ();

  log_thread_initialize();
  hash_join_enable = 1;

  if (mode_pass_change)
    {
	  caddr_t err = NULL;
	  query_t *qr;
	  char e_text [200];

	  snprintf (e_text, sizeof (e_text),
	      "USER_CHANGE_PASSWORD ('dba', '%.20s', '%.20s')", f_old_dba_pass, f_new_dba_pass);

	  qr = sql_compile (e_text, bootstrap_cli, &err, SQLC_DEFAULT);
	  if (!err)
	    {
	      err = qr_quick_exec (qr, bootstrap_cli, NULL, NULL, 0);
	      qr_free (qr);
	    }

	  log_info ("The DBA password is changed.");
	  snprintf (e_text, sizeof (e_text),
	      "USER_CHANGE_PASSWORD ('dav', 'dav', '%.20s')", f_new_dav_pass);

	  qr = sql_compile (e_text , bootstrap_cli, &err, SQLC_DEFAULT);
	  if (!err)
	    {
	      err = qr_quick_exec (qr, bootstrap_cli, NULL, NULL, 0);
	      qr_free (qr);
	    }

	  log_info ("The DAV password is changed.");

	  local_commit (bootstrap_cli);
	  sf_shutdown (sf_make_new_log_name (wi_inst.wi_master), bootstrap_cli->cli_trx);
    }
  IN_TXN;
  lt_leave(bootstrap_cli->cli_trx);
  LEAVE_TXN;
#ifdef DBSE_TREES_DEBUG
  dbg_it_print_trees ();
#endif
#ifdef WIN32
  sec_set_user_os_struct ("dba", "", "");
#endif
  box_dv_uname_make_immortal_all ();
  while (srv_have_global_lock (THREAD_CURRENT_THREAD))
    {
      log_error ("The startup left global lock, unlocking");
      srv_global_unlock (bootstrap_cli, bootstrap_cli->cli_trx);
    }
  in_srv_global_init = 0;
  if (0 == strcmp (build_thread_model, "-fibers"))
    threads_is_fiber = 1;
  time (&st_started_since);
  st_sys_ram = get_total_sys_mem ();
  sqlc_set_client (NULL);
  enable_col_by_default = c_col_by_default;
}


caddr_t
srv_make_new_error (const char *code, const char *virt_code, const char *msg, ...)
{
  char temp[2000];
  va_list list;
#ifdef DEBUG
  FILE *err_log;
#endif
  int msg_len;
  int code_len = virt_code ? (int) strlen (virt_code) : 0;

  caddr_t *box = (caddr_t *) dk_alloc_box (3 * sizeof (caddr_t),
      DV_ARRAY_OF_POINTER);
  va_start (list, msg);
  vsnprintf (temp, 2000, msg, list);
  va_end (list);
  msg_len = (int) strlen (temp);

  if (code[1] == 'Y')
    virtuoso_sleep (0, 10000);

  {
    if ('S' == code[0] || '4' == code[0])
      {
        at_printf (("Host %d make err %s %s in %s\n", local_cll.cll_this_host, code, temp, cl_thr_stat ()));
      }
  }
  box[0] = (caddr_t) QA_ERROR;
  box[1] = box_dv_short_string (code);
  if (virt_code)
    {
      box[2] = dk_alloc_box (msg_len + code_len + 3, DV_SHORT_STRING);
      memcpy (box[2], virt_code, code_len);
      memcpy (box[2] + code_len, ": ", 2);
      memcpy (box[2] + code_len + 2, temp, msg_len);
      box[2][code_len+msg_len+2] = 0;
    }
  else
    box[2] = box_dv_short_string (temp);
#ifdef DEBUG
  err_log = fopen("srv_errors.txt","at");
  if (NULL != err_log)
    {
      fprintf (err_log, "%s | %s\n", box[1], box[2]);
      fclose (err_log);
    }
#endif

  if (DO_LOG(LOG_SRV_ERROR))
    {
      log_info ("ERRS_0 %s %s %s", code, virt_code, temp);
    }

  return ((caddr_t) box);
}


caddr_t
srv_make_trx_error (int code, caddr_t detail)
{
  caddr_t err = NULL;
  switch (code)
    {
      case LTE_TIMEOUT:
	  err = srv_make_new_error ("S1T00", "SR171",
	      "Transaction timed out%s%s",
	      detail ? " : " : "", detail ? detail : "");
	  break;
      case LTE_DEADLOCK:
	  err = srv_make_new_error ("40001", "SR172",
	      "Transaction deadlocked%s%s",
	      detail ? " : " : "", detail ? detail : "");
	  break;
      case LTE_NO_DISK:
	  err = srv_make_new_error ("40003", "SR173",
	      "Transaction out of disk%s%s",
	      detail ? " : " : "", detail ? detail : "");
	  break;
      case LTE_LOG_FAILED:
	  err = srv_make_new_error ("40004", "SR174",
	      "Log out of disk%s%s",
	      detail ? " : " : "", detail ? detail : "");
	  break;
      case LTE_UNIQ:
	  err = srv_make_new_error ("23000", "SR175",
	      "Uniqueness violation%s%s. Transaction killed.",
	      detail ? " : " : "", detail ? detail : "");
	  break;
      case LTE_SQL_ERROR:
        {
          du_thread_t *self = THREAD_CURRENT_THREAD;
          caddr_t *probable_err = (caddr_t *)thr_get_error_code (self);
          if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (probable_err))
            probable_err = NULL;
          if (NULL == probable_err)
            {
	      err = srv_make_new_error ("4000X", "SR176",
	        "Transaction rolled back due to previous SQL error%s%s",
	        detail ? " : " : "", detail ? detail : "");
	      break;
            }
          else
            {
	      err = srv_make_new_error ("4000X", "SR176",
	        "Transaction rolled back due to previous SQL error %s (((\n%s\n)))%s%s",
					probable_err[1], probable_err[2], detail ? " : " : "", detail ? detail : "");
	      break;
            }
        }
      case LTE_REMOTE_DISCONNECT:
	  err = srv_make_new_error ("08U01", "SR324",
	      "Remote server has disconnected making the transaction "
	      "uncommittable. Transaction has been rolled back%s%s",
	      detail ? " : " : "", detail ? detail : "");
	  break;
      case LTE_CHECKPOINT:
	  err = srv_make_new_error ("40001", "SR325",
	      "Transaction aborted due to a database checkpoint or "
	      "database-wide atomic operation. Please retry transaction%s%s",
	      detail ? " : " : "", detail ? detail : "");
	  break;
      case LTE_LOG_IMAGE:
	  err = srv_make_new_error ("40005", "SR325",
	      "Transaction aborted because it's log after image size "
	      "went above the limit%s%s",
	      detail ? " : " : "", detail ? detail : "");
	  break;
      case LTE_OUT_OF_MEM:
	  err = srv_make_new_error ("40006", "SR337",
	      "Transaction aborted because the server is out of memory%s%s",
	      detail ? " : " : "", detail ? detail : "");
	  break;
    case LTE_CLUSTER:
	  err = srv_make_new_error ("08C02", "SR337",
				    "Transaction aborted due to cluster connection failure");
	  break;
    case LTE_CANCEL:
	  err = srv_make_new_error ("40001", "SR337",
				    "Transaction aborted due to async rollback in cluster");
	  break;
    case LTE_CLUSTER_SYNC:
	  err = srv_make_new_error ("40007", "CLTSY",
				    "Transaction not committable because async update branch not synced before commit.  Commit has overtaken the branch message or the branch message was lost by the network");
	  break;
    case LTE_PREPARED_NOT_COMMITTED:
	  err = srv_make_new_error ("40007", "CLPNC",
				    "Transaction prepared but not committed.  Probably dropped commit message.  The branch will automatically query coordinator for the final status.  The situation will reset itself in a few seconds");
	  break;

    default:
	  err = srv_make_new_error ("4000X", "SR177", "Misc Transaction Error%s%s",
	      detail ? " : " : "", detail ? detail : "");
	  break;
    }
  return err;
}

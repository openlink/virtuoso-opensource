/*
 *  sqlbif2.c
 *
 *  $Id$
 *
 *  SQL Built In Functions. Part 2
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
#include "sqlfn.h"
#include "eqlcomp.h"
#include "lisprdr.h"
#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlbif.h"
#include "arith.h"
#include "security.h"
#include "sqlpfn.h"
#include "http.h"
#include "libutil.h"
#include "sqlo.h"
#include "sqlver.h"
#include "srvmultibyte.h"
#include "xmlparser.h"
#include "xmltree.h"

#ifdef HAVE_PWD_H
#include <pwd.h>
#endif
#ifdef HAVE_GRP_H
#include <grp.h>
#endif

#ifndef KEYCOMP
extern ptrlong itc_dive_transit_call_ctr;
extern ptrlong itc_try_land_call_ctr;

static caddr_t
bif_itc_dive_transit_call_ctr (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t res = box_num (itc_dive_transit_call_ctr);
  if ((0 < BOX_ELEMENTS (args)) && bif_long_arg (qst, args, 0, "itc_dive_transit_call_ctr"))
    itc_dive_transit_call_ctr = 0;
  return res;
}

static caddr_t
bif_itc_try_land_call_ctr (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t res = box_num (itc_try_land_call_ctr);
  if ((0 < BOX_ELEMENTS (args)) && bif_long_arg (qst, args, 0, "itc_try_land_call_ctr"))
    itc_try_land_call_ctr = 0;
  return res;
}

#endif

static caddr_t
bif_ddl_read_constraints (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t spec_tb_name = bif_string_or_null_arg (qst, args, 0, "__ddl_read_constraints");
  ddl_read_constraints (spec_tb_name, qst);
  return NULL;
}

static id_hash_t *name_to_pl_name;


void
pl_bif_name_define (const char *name)
{
  char buff[2 * MAX_NAME_LEN];
  caddr_t data;
  if (!name_to_pl_name)
    {
      name_to_pl_name = id_casemode_hash_create (101);
    }
  name = sqlp_box_id_upcase (name);
  if (strchr (name, NAME_SEPARATOR))
    strcpy_ck (buff, name);
  else
    snprintf (buff, sizeof (buff), "DB.DBA.%s", name);
  data = sym_string (buff);
  id_hash_set (name_to_pl_name, (char *) &name, (char *) &data);
}


caddr_t
find_pl_bif_name (caddr_t name)
{
  caddr_t *full = (caddr_t *) id_hash_get (name_to_pl_name, (caddr_t) &name);
  if (full)
    return *full;
  else if (case_mode == CM_MSSQL)
    {
      caddr_t name2 = sqlp_box_id_upcase (name);
      full = (caddr_t *) id_hash_get (name_to_pl_name, (caddr_t) &name2);
      dk_free_box (name2);
      if (full)
	return *full;
    }
  return name;
}

int lockdown_mode = 0;

typedef struct co_req_2_s {
   semaphore_t *sem;
   dk_set_t *set;
} co_req_2_t;

static void
collect_listeners (co_req_2_t *req)
{
  dk_set_t peers = PrpcListPeers ();
  DO_SET (dk_session_t *, peer, &peers)
    {
      if (SESSTAT_ISSET (peer->dks_session, SST_LISTENING) &&
	  !PrpcIsListen (peer))
	{
	  remove_from_served_sessions (peer);
	  dk_set_push (req->set, peer);
	}
    }
  END_DO_SET ();
  if (req->sem)
    semaphore_leave (req->sem);
}

static void
restore_listeners (co_req_2_t *req)
{
  DO_SET (dk_session_t *, listener, req->set)
    {
      add_to_served_sessions (listener);
    }
  END_DO_SET ();
  dk_set_free (*req->set);
  *req->set = NULL;
  if (req->sem)
    semaphore_leave (req->sem);
}


int
dks_is_localhost (dk_session_t *ses)
{
  if (ses->dks_session->ses_class == SESCLASS_UNIX)
    return 1;
  else if (ses->dks_session->ses_class == SESCLASS_TCPIP)
    {
      char buf[150];
      if (!tcpses_getsockname (ses->dks_session, buf, sizeof (buf)))
	{
	  if (!strncmp (buf, "127.0.0.1", 9))
	    return 1;
	}
    }
  return 0;
}


static caddr_t
bif_sys_lockdown (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong lockdown = bif_long_arg (qst, args, 0, "sys_lockdown");
  query_instance_t *qi = (query_instance_t *) qst;
  dk_set_t clients;
  static dk_set_t listeners = NULL;
  co_req_2_t req;
  ptrlong disconnect_mode = 0;
  static ptrlong last_disconnect_mode = 0;
  long res = 0;

  sec_check_dba (qi, "sys_lockdown");

  req.sem = THREAD_CURRENT_THREAD->thr_sem;
  req.set = &listeners;
  if (BOX_ELEMENTS (args) > 1)
    disconnect_mode = bif_long_arg (qst, args, 1, "sys_lockdown");

  if (lockdown && !lockdown_mode)
    {
      dk_session_t *this_client_ses = IMMEDIATE_CLIENT;
      char buffer[50];

      if (!qi->qi_client->cli_ws)
	tcpses_print_client_ip (qi->qi_client->cli_session->dks_session, buffer, sizeof (buffer));
      else
	strncpy (buffer, qi->qi_client->cli_ws->ws_client_ip, sizeof (buffer));
      buffer[sizeof (buffer) - 1] = 0;

      if (!dks_is_localhost (this_client_ses))
	this_client_ses = NULL;

      logmsg (LOG_EMERG, NULL, 0, 1,
	  "Security lockdown mode ON (listeners %s) via sys_lockdown() called by %s (IP:%s)",
	  disconnect_mode ? "OFF" : "UNSERVED",
	  qi->qi_client->cli_user ? qi->qi_client->cli_user->usr_name : "<internal>",
	  buffer);
      lockdown_mode = 1;
#ifndef NDEBUG
      if (listeners)
        GPF_T1 ("listeners already there on locking the system down");
#endif
      PrpcSelfSignal ((self_signal_func) collect_listeners, (caddr_t) &req);
      semaphore_enter (req.sem);

      mutex_enter (thread_mtx);
      clients = srv_get_logons ();
      DO_SET (dk_session_t *, ses, &clients)
	{
	  if (ses != this_client_ses)
	    {
	      client_connection_t *cli = DKS_DB_DATA (ses);
	      if (cli)
		{
		  cli->cli_terminate_requested = 1;
		  ses->dks_to_close = 1;
		}
	    }
	}
      END_DO_SET ();
      mutex_leave (thread_mtx);
      last_disconnect_mode = disconnect_mode;
      if (disconnect_mode)
	{
	  DO_SET (dk_session_t *, ses, &listeners)
	    {
	      session_disconnect (ses->dks_session);
	    }
	  END_DO_SET ();
	}
      res = 1;
    }
  else if (!lockdown && lockdown_mode)
    {
      if (last_disconnect_mode)
	{
	  DO_SET (dk_session_t *, ses, &listeners)
	    {
	      without_scheduling_tic ();
	      session_listen (ses->dks_session);
	      without_scheduling_tic ();
	    }
	  END_DO_SET ();
	}
      lockdown_mode = 0;
      PrpcSelfSignal ((self_signal_func) restore_listeners, (caddr_t) &req);
      semaphore_enter (req.sem);
      log_info ("Security lockdown mode ended via sys_lockdown()");
      res = 2;
    }
  return box_num (res);
}


int
tcpses_check_disk_error (dk_session_t *ses, caddr_t *qst, int throw_error)
{
  query_instance_t *qi = (query_instance_t *) qst;

  if (!ses || !ses->dks_session || !ses->dks_session->ses_class != SESCLASS_STRING
      || !ses->dks_session->ses_file->ses_max_blocks_init)
    return 0;

  if (SESSTAT_ISSET (ses->dks_session, SST_DISK_ERROR))
    {
      if (qst)
	{
	  qi->qi_trx->lt_status = LT_BLOWN_OFF;
	  qi->qi_trx->lt_error = LTE_NO_DISK;
	}
      if (throw_error)
	{
	  sqlr_new_error ("42000", "SR452", "Error in accessing temp file");
	}
      return 1;
    }
  else
    return 0;
}


caddr_t
bif_session_arg (caddr_t * qst, state_slot_t ** args, int nth, char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp != DV_STRING_SESSION && dtp != DV_CONNECTION)
    sqlr_new_error ("22023", "SR002",
	"Function %s needs a string output or a session as argument %d, not an arg of type %s (%d)",
	func, nth + 1, dv_type_title (dtp), dtp);
  return arg;
}


static caddr_t
bif_blob_handle_from_session (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t ses = bif_session_arg (qst, args, 0, "__blob_handle_from_session");
  blob_handle_t *bh;
  caddr_t dummy_null;

  if (!ssl_is_settable (args[0]))
    sqlr_new_error ("22023", "SR453", "__blob_handle_from_session argument 1 must be IN/OUT");

  bh = bh_alloc (DV_BLOB_HANDLE_DTP_FOR_BLOB_DTP (DV_BLOB_BIN));
  bh->bh_ask_from_client = 3;
  bh->bh_source_session = ses;
  dummy_null = NEW_DB_NULL;
  qst_swap (qst, args[0], &dummy_null);

  return (caddr_t) bh;
}

bif_type_t bt_blob_handle = {NULL, DV_BLOB_HANDLE, 0, 0};


static caddr_t
bif_os_chmod (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t fname = bif_string_or_wide_or_uname_arg (qst, args, 0, "os_chmod");
  long mod  = (long) bif_long_arg (qst, args, 1, "os_chmod");
  char *fname_cvt = NULL;
  caddr_t res;

  sec_check_dba ((query_instance_t *) qst, "os_chmod");
#if defined (HAVE_CHMOD)
  fname_cvt = file_native_name (fname);
  file_path_assert (fname_cvt, NULL, 1);
  if (0 != chmod (fname_cvt, mod))
    {
      int eno = errno;
      res = box_dv_short_string (strerror (eno));
    }
  else
    res = NEW_DB_NULL;
#else
  res = box_dv_short_string ("CHMOD feature not available in the host OS");
#endif

  dk_free_box (fname_cvt);
  return res;
}

static dk_mutex_t *pwnam_mutex;

caddr_t
os_get_uname_by_uid (long uid)
{
  caddr_t res = NULL;
#if defined (HAVE_GETPWUID)
  struct passwd *pwd;
  mutex_enter (pwnam_mutex);
  pwd = getpwuid ((uid_t) uid);
  if (pwd)
    res = box_dv_short_string (pwd->pw_name);
  mutex_leave (pwnam_mutex);
#endif

  if (!res)
    res = NEW_DB_NULL;
  return res;
}

caddr_t
os_get_gname_by_gid (long gid)
{
  caddr_t res = NULL;
#if defined (HAVE_GETPWUID)
  struct group *grp;
  mutex_enter (pwnam_mutex);
  grp = getgrgid ((gid_t) gid);
  if (grp)
    res = box_dv_short_string (grp->gr_name);
  mutex_leave (pwnam_mutex);
#endif

  if (!res)
    res = NEW_DB_NULL;
  return res;
}

#ifdef WIN32
#include <Aclapi.h>

caddr_t
os_get_uname_by_fname (char *fname)
{
  caddr_t ret = NULL;
  PSID owner = 0;

  if (ERROR_SUCCESS == GetNamedSecurityInfo (fname, SE_FILE_OBJECT, OWNER_SECURITY_INFORMATION, &owner, NULL, NULL, NULL, NULL))
    {
      char name[1000], dname[1000];
      DWORD l_name = sizeof (name);
      DWORD l_dname = sizeof (dname);
      SID_NAME_USE use;
      if (LookupAccountSid (NULL, owner, name, &l_name, dname, &l_dname, &use))
	{
	  ret = box_dv_short_string (name);
	}
    }
  return ret ? ret : NEW_DB_NULL;
}

caddr_t
os_get_gname_by_fname (char *fname)
{
  caddr_t ret = NULL;
  PSID owner = 0;

  if (ERROR_SUCCESS == GetNamedSecurityInfo (fname, SE_FILE_OBJECT, GROUP_SECURITY_INFORMATION, NULL, &owner, NULL, NULL, NULL))
    {
      char name[1000], dname[1000];
      DWORD l_name = sizeof (name);
      DWORD l_dname = sizeof (dname);
      SID_NAME_USE use;
      if (LookupAccountSid (NULL, owner, name, &l_name, dname, &l_dname, &use))
	{
	  ret = box_dv_short_string (name);
	}
    }
  return ret ? ret : NEW_DB_NULL;
}
#endif

static caddr_t
bif_os_chown (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t fname = bif_string_or_wide_or_uname_arg (qst, args, 0, "os_chown");
  caddr_t user  = bif_string_arg (qst, args, 1, "os_chown");
  caddr_t group = bif_string_arg (qst, args, 2, "os_chown");
  char *fname_cvt = NULL;
  caddr_t res = NULL;

  sec_check_dba ((query_instance_t *) qst, "os_chown");

  fname_cvt = file_native_name (fname);
  file_path_assert (fname_cvt, NULL, 1);

#if defined (HAVE_CHOWN) && defined (HAVE_GETPWNAM) && defined (HAVE_GETGRNAM)
    {
      char buffer[255];
      struct passwd *u_info = NULL;
      struct group *g_info = NULL;
      uid_t uid = -1;
      gid_t gid = -1;

      mutex_enter (pwnam_mutex);
      u_info = getpwnam (user);
      if (u_info)
	uid = u_info->pw_uid;

      g_info = getgrnam (group);
      if (g_info)
	gid = g_info->gr_gid;
      mutex_leave (pwnam_mutex);

      if (!res && !u_info)
	{
	  snprintf (buffer, sizeof (buffer), "User %.200s does not exist", user);
	  res = box_dv_short_string (buffer);
	}
      if (!res && !g_info)
	{
	  snprintf (buffer, sizeof (buffer), "Group %.200s does not exist", group);
	  res = box_dv_short_string (buffer);
	}

      if (!res)
	{
	  if (0 != chown (fname_cvt, uid, gid))
	    {
	      int eno = errno;
	      res = box_dv_short_string (strerror (eno));
	    }
	  else
	    res = NEW_DB_NULL;
	}
    }
#elif defined (WIN32)
    {
      SID_NAME_USE use_user = SidTypeUser, use_group = SidTypeGroup;
      char user_sid[SECURITY_MAX_SID_SIZE], group_sid[SECURITY_MAX_SID_SIZE], dom1[1000], dom2[1000];
      DWORD user_sid_sz = SECURITY_MAX_SID_SIZE, group_sid_sz = SECURITY_MAX_SID_SIZE, d1 = sizeof (dom1), d2 = sizeof (dom2);

      if (LookupAccountName (NULL, user, (PSID) user_sid, &user_sid_sz, dom1, &d1, &use_user) &&
	  LookupAccountName (NULL, group, (PSID) group_sid, &group_sid_sz, dom2, &d2, &use_group))
	{
	  if (ERROR_SUCCESS == SetNamedSecurityInfo (fname_cvt, SE_FILE_OBJECT, OWNER_SECURITY_INFORMATION | GROUP_SECURITY_INFORMATION,
		(PSID) user_sid, (PSID) group_sid, NULL, NULL))
	    res = NEW_DB_NULL;
	}
      if (!res)
	{
	  LPVOID lpMsgBuf;
	  if (FormatMessage(
		FORMAT_MESSAGE_ALLOCATE_BUFFER |
		FORMAT_MESSAGE_FROM_SYSTEM |
		FORMAT_MESSAGE_IGNORE_INSERTS,
		NULL,
		GetLastError(),
		MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), /* Default language */
		(LPTSTR) &lpMsgBuf,
		0,
		NULL ))
	    {
	      res = box_dv_short_string (lpMsgBuf);
	      LocalFree( lpMsgBuf );
	    }
	  else
	    res = box_dv_short_string ("Unknown Win32 error");
	}
    }
#else
  res = box_dv_short_string ("CHOWN feature not available in the host OS");
#endif

  dk_free_box (fname_cvt);
  return res;
}


float compiler_unit_msecs = 0;

#define SQLO_NITERS 1000

#define COL_COUNT "select count (*) from SYS_COLS a table option (index primary key) where  exists (select 1 from SYS_COLS b table option (loop) where a.\"TABLE\" = b.\"TABLE\" and a.\"COLUMN\" = b.\"COLUMN\")"

void
srv_calculate_sqlo_unit_msec (void)
{
  caddr_t err = NULL;
  caddr_t score_box;
  float score;
  float start_time, end_time;
  local_cursor_t *lc_tim = NULL;
  query_t *qr = NULL;
  dbe_table_t *sys_cols_tb = sch_name_to_table (isp_schema (NULL), "DB.DBA.SYS_COLS");
  long old_tb_count;
  int inx;
  client_connection_t *cli = bootstrap_cli;

  old_tb_count = sys_cols_tb->tb_count;
  sys_cols_tb->tb_count = wi_inst.wi_schema->sc_id_to_col->ht_count;

  qr = sql_compile (COL_COUNT, cli, &err, SQLC_DEFAULT);
  start_time = (float) get_msec_real_time ();
  for (inx = 0; inx < SQLO_NITERS; inx++)
    { /* repeat enough times as sys_cols is usually not very big */
      err = qr_quick_exec (qr, cli, NULL, &lc_tim, 0);
      lc_next (lc_tim);
      sys_cols_tb->tb_count = (long) unbox (lc_nth_col (lc_tim, 0));
      lc_next (lc_tim);
      lc_free (lc_tim);
      if (inx > 0 && inx % 10 == 0 && get_msec_real_time () - start_time > 1000)
        {
          inx += 1;
          break;
        }
    }
  end_time = (float) get_msec_real_time ();
  qr_free (qr);

  score_box = (caddr_t) sql_compile (COL_COUNT, cli, &err, SQLC_SQLO_SCORE);
  score = unbox_float (score_box);
  /*printf ("cu score = %f\n", score);*/
  dk_free_tree (score_box);
  compiler_unit_msecs = (end_time - start_time) / (score * inx);

  sys_cols_tb->tb_count = old_tb_count;
  local_commit (bootstrap_cli);
  log_info ("Compiler unit is timed at %f msec", (double) compiler_unit_msecs);
}


static caddr_t
bif_user_has_role (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t uname = bif_string_arg (qst, args, 0, "user_has_role");
  caddr_t rname = bif_string_arg (qst, args, 1, "user_has_role");
  user_t **place;
  user_t *usr;
  int inx;

  sec_check_dba ((query_instance_t *) qst, "user_has_role");
  place = (user_t **) id_hash_get (sec_users, (caddr_t) &uname);

  if (!place)
    sqlr_new_error ("22023", "SR390", "No such user %s in user_has_role", uname);

  usr = *place;
  DO_BOX (ptrlong, g_id, inx, usr->usr_g_ids)
    {
      user_t *gr = sec_id_to_user ((oid_t) g_id);
      if (!strcmp (gr->usr_name, rname))
	return box_num (1);
    }
  END_DO_BOX;
  return box_num (0);
}

static caddr_t
bif_user_is_dba (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t uname = bif_string_arg (qst, args, 0, "user_is_dba");
  user_t **place;
  user_t *usr;
  int rc;

  sec_check_dba ((query_instance_t *) qst, "user_is_dba");
  place = (user_t **) id_hash_get (sec_users, (caddr_t) &uname);
  if (!place)
    sqlr_new_error ("22023", "SR390", "No such user %s in user_is_dba", uname);
  usr = *place;
  rc = sec_user_has_group (G_ID_DBA, usr->usr_id);
  return box_num (rc);
}

static caddr_t
bif_client_attr (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  caddr_t mode = bif_string_arg (qst, args, 0, "client_attr");
  session_t *ses;

  if (!stricmp ("client_protocol", mode))
    {
      if (qi->qi_client->cli_ws && qi->qi_client->cli_ws->ws_proto)
	return box_dv_short_string (qi->qi_client->cli_ws->ws_proto);
      else
	return box_dv_short_string ("SQL");
    }
  else if (!stricmp ("client_ip", mode))
    {
      return int_client_ip (qi, 0);
    }
  else if (!stricmp ("accepting_ip", mode))
    {
      char buf[100];

      if (!qi->qi_client->cli_ws && !qi->qi_client->cli_session)
	return box_dv_short_string ("127.0.0.1");

      ses = qi->qi_client->cli_ws && qi->qi_client->cli_ws->ws_session ?
	  qi->qi_client->cli_ws->ws_session->dks_session : qi->qi_client->cli_session->dks_session;

      if (!tcpses_getsockname (ses, buf, sizeof (buf)))
	{
#ifdef COM_UNIXSOCK
	    {
	      int port;
	      if (!strncmp (buf, UNIXSOCK_ADD_ADDR, sizeof (UNIXSOCK_ADD_ADDR) - 1)
		  && (port = atoi (buf + sizeof (UNIXSOCK_ADD_ADDR) - 1)))
		snprintf (buf, sizeof (buf), "127.0.0.1:%d", port);
	    }
#endif
	  return box_dv_short_string (buf);
	}

      *err_ret = srv_make_new_error ("22005", "SR401", "Server address not known");
    }
  else if (!stricmp ("client_application", mode))
    {
      if (qi->qi_client->cli_user_info)
	return box_dv_short_string (qi->qi_client->cli_user_info);
    }
  else if (!stricmp ("client_ssl", mode))
    {
#ifdef _SSL
      SSL *ssl = (SSL *) tcpses_get_ssl (qi->qi_client->cli_ws ?
	  qi->qi_client->cli_ws->ws_session->dks_session :
	     qi->qi_client->cli_session->dks_session);
      if (ssl)
	return box_num (1);
#else
      sqlr_new_error ("22005", "SR403", "'client_ssl' value of client_attr option is not supported by this build of the Virtuoso server");
      return NULL;
#endif
    }
  else if (!stricmp ("client_certificate", mode))
    {
#ifdef _SSL
      caddr_t ret = NULL;
      char *ptr;
      SSL *ssl = (SSL *) tcpses_get_ssl (qi->qi_client->cli_ws ?
	  qi->qi_client->cli_ws->ws_session->dks_session :
	     qi->qi_client->cli_session->dks_session);
      X509 *cert = NULL;
      BIO *in = NULL;

      if (ssl)
        cert = SSL_get_peer_certificate (ssl);
      else
	return NULL;

      if (!cert)
	return NULL;

      in = BIO_new (BIO_s_mem());

      if (!in)
	{
	  char err_buf[512];
	  sqlr_new_error ("22005", "SR402", "Cannot allocate temp space. SSL error : %s",
	      get_ssl_error_text (err_buf, sizeof (err_buf)));
	  return NULL;
	}

      BIO_reset(in);

      PEM_write_bio_X509 (in, cert);
      ret = dk_alloc_box (BIO_get_mem_data (in, &ptr) + 1, DV_SHORT_STRING);
      memcpy (ret, ptr, box_length (ret) - 1);
      ret[box_length (ret) - 1] = 0;

      BIO_free (in);

      return ret;
#else
      sqlr_new_error ("22005", "SR403", "'client_certificate' value of client_attr option is not supported by this build of the Virtuoso server");
      return NULL;
#endif
    }
  else if (!stricmp ("transaction_log", mode))
    {
      int is_on = 1;
      if (srv_have_global_lock (THREAD_CURRENT_THREAD))
	is_on = 0;
      else if (qi->qi_trx->lt_replicate == REPL_NO_LOG)
        is_on = 0;
      return box_num (is_on);
    }
  else if (!stricmp ("connect_attrs", mode))
    {
      if (qi->qi_client->cli_info)
	return box_copy_tree (qi->qi_client->cli_info);
      else
	return NEW_DB_NULL;
    }
  else
    {
      *err_ret = srv_make_new_error ("22005", "SR403", " %s is not valid client_attr option", mode);
    }

  return NULL;
}

static caddr_t
bif_query_instance_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  long depth = bif_long_range_arg (qst, args, 0, "query_instance_id", 0, 0xffff);
  while ((depth-- > 0) && (NULL != qi)) qi = qi->qi_caller;
  if (NULL == qi)
    return NEW_DB_NULL;
  return box_num ((ptrlong)qi);
}

static caddr_t
bif_sql_warnings_resignal (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *warnings = (caddr_t *) bif_array_or_null_arg (qst, args, 0, "sql_warnings_resignal");

  if (warnings)
    {
      int inx;

      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (warnings))
	sqlr_new_error ("22023", "SR454", "Invalid warnings array");

      DO_BOX (caddr_t,  warning, inx, warnings)
	{
	  if (!IS_BOX_POINTER (warning) ||
	      DV_ARRAY_OF_POINTER != DV_TYPE_OF (warning) ||
	      BOX_ELEMENTS (warning) != 3 ||
	      (((caddr_t*) warning)[0]) != (caddr_t) QA_WARNING ||
	      (!DV_STRINGP (ERR_STATE (warning)) && DV_C_STRING != DV_TYPE_OF (ERR_STATE (warning))) ||
	      (!DV_STRINGP (ERR_MESSAGE (warning)) && DV_C_STRING != DV_TYPE_OF (ERR_MESSAGE (warning))))
	    sqlr_new_error ("22023", "SR455", "Invalid warning in the warnings array");

	  sql_warning_add (box_copy_tree (warning), 0);
	}
      END_DO_BOX;
    }
  return NEW_DB_NULL;
}


static caddr_t
bif_sql_warning (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t sql_state = bif_string_arg (qst, args, 0, "sql_warning");
  caddr_t virt_code = bif_string_arg (qst, args, 1, "sql_warning");
  caddr_t msg = bif_string_arg (qst, args, 2, "sql_warning");

  sqlr_warning (sql_state, virt_code, "%s", msg);
  return NEW_DB_NULL;
}


static caddr_t
bif_sec_uid_to_user (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  oid_t uid = (oid_t) bif_long_arg (qst, args, 0, "__sec_uid_to_user");
  user_t *user;

  user = sec_id_to_user (uid);
  if (user)
    return box_dv_short_string (user->usr_name);
  else
    return NEW_DB_NULL;
}

static caddr_t
bif_current_proc_name (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  long frames = BOX_ELEMENTS (args) > 0 ? bif_long_arg (qst, args, 0, "current_proc_name") : 0;

  while (frames && IS_POINTER (qi))
    {
      frames --;
      qi = qi->qi_caller;
    }
  if (IS_POINTER (qi) && qi->qi_query && qi->qi_query->qr_proc_name)
    return box_string (qi->qi_query->qr_proc_name);
  return NEW_DB_NULL;
}

static caddr_t
bif_host_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
	if (build_host_id)
		return box_string (build_host_id);
	return NEW_DB_NULL;
}

boxint
zorder_index (ptrlong x, ptrlong y)
{
  x = ((x & 0x00000000FFFF0000LL) << 16) | (x & 0x000000000000FFFFLL);
  x = ((x & 0x0000FF00FF00FF00LL) <<  8) | (x & 0x000000FF00FF00FFLL);
  x = ((x & 0x00F0F0F0F0F0F0F0LL) <<  4) | (x & 0x000F0F0F0F0F0F0FLL);
  x = ((x & 0x0CCCCCCCCCCCCCCCLL) <<  2) | (x & 0x0333333333333333LL);
  x = ((x & 0xAAAAAAAAAAAAAAAALL) <<  1) | (x & 0x5555555555555555LL);
  y = ((y & 0x00000000FFFF0000LL) << 16) | (y & 0x000000000000FFFFLL);
  y = ((y & 0x0000FF00FF00FF00LL) <<  8) | (y & 0x000000FF00FF00FFLL);
  y = ((y & 0x00F0F0F0F0F0F0F0LL) <<  4) | (y & 0x000F0F0F0F0F0F0FLL);
  y = ((y & 0x0CCCCCCCCCCCCCCCLL) <<  2) | (y & 0x0333333333333333LL);
  y = ((y & 0xAAAAAAAAAAAAAAAALL) <<  1) | (y & 0x5555555555555555LL);
  return (y << 1) | x;
}

static caddr_t
bif_zorder_index (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong x = bif_long_range_arg (qst, args, 0, "zorder_index", -2020000000, 202000000);
  ptrlong y = bif_long_range_arg (qst, args, 1, "zorder_index", -2020000000, 202000000);
  boxint res = zorder_index (x, y);
  return box_num (res);
}

/*! URI parser according RFC 1808 recommendations
Fills in array of twelve begin and past-the end indexes of elements */
void
rfc1808_parse_uri (const char *iri, rdf1808_split_t *split_ret)
{
  const char *delim;
  split_ret->schema_begin = split_ret->schema_end = split_ret->netloc_begin = 0;
  split_ret->fragment_end = strlen (iri);
/* Here we know Ss nn pp pp qq fF  t */
  delim = strchr (iri, '#');
  if (NULL != delim)
    {
      split_ret->query_end = delim-iri;
      split_ret->fragment_begin = delim+1-iri;
    }
  else
    split_ret->query_end = split_ret->fragment_begin = split_ret->fragment_end;
/* Here we know Ss nn pp pp qQ FF  t */
  delim = strchr (iri, ':');
  if ((NULL != delim) && (delim < iri+split_ret->query_end))
    {
      const char *scan = iri;
      while (scan <  delim)
        {
          if (!isalnum ((unsigned char) (scan[0])) && (NULL == strchr ("+-.", scan[0])))
            goto schema_done;
          scan++;
        }
      split_ret->schema_end = delim-iri;
      split_ret->netloc_begin = delim + 1 - iri;
    }
schema_done:
/* Here we know SS Nn pp pp qQ FF  t */
  if (('/' == iri[split_ret->netloc_begin]) && ('/' == iri[split_ret->netloc_begin+1]))
    {
      split_ret->netloc_begin += 2;
      split_ret->two_slashes = split_ret->netloc_begin;
      delim = strchr (iri + split_ret->netloc_begin, '/');
      if ((NULL != delim) && (delim < iri+split_ret->query_end))
        {
          split_ret->netloc_end = split_ret->path_begin = delim - iri;
        }
      else
        {
          split_ret->netloc_end = split_ret->path_begin = split_ret->path_end = split_ret->params_begin = split_ret->params_end = split_ret->query_begin = split_ret->query_end;
          return;
        }
    }
  else
    {
      split_ret->two_slashes = 0;
      split_ret->netloc_end = split_ret->path_begin = split_ret->netloc_begin;
    }
/* Here we know SS NN Pp pp qQ FF  T */
  delim = strchr (iri + split_ret->path_begin, '?');
  if ((NULL != delim) && (delim < iri+split_ret->query_end))
    {
      split_ret->query_begin = delim + 1 - iri;
      split_ret->params_end = delim - iri;
    }
  else
    {
      split_ret->params_end = split_ret->query_begin = split_ret->query_end;
    }
/* Here we know SS NN Pp pP QQ FF  T */
  delim = strchr (iri + split_ret->path_begin, ';');
  if ((NULL != delim) && (delim < iri+split_ret->params_end))
    {
      split_ret->params_begin = delim + 1 - iri;
      split_ret->path_end = delim - iri;
    }
  else
    {
      split_ret->path_end = split_ret->params_begin = split_ret->params_end;
    }
/* Here we know SS NN PP PP QQ FF  T */
  CHECK_RDF1808_SPLIT((split_ret[0]), strlen (iri))
}

void
rfc1808_parse_wide_uri (const wchar_t *iri, rdf1808_split_t *split_ret)
{
  const wchar_t *delim;
  split_ret->schema_begin = split_ret->schema_end = split_ret->netloc_begin = 0;
  split_ret->fragment_end = virt_wcslen (iri);
/* Here we know Ss nn pp pp qq fF  t */
  delim = virt_wcschr (iri, '#');
  if (NULL != delim)
    {
      split_ret->query_end = delim-iri;
      split_ret->fragment_begin = delim+1-iri;
    }
  else
    split_ret->query_end = split_ret->fragment_begin = split_ret->fragment_end;
/* Here we know Ss nn pp pp qQ FF  t */
  delim = virt_wcschr (iri, ':');
  if ((NULL != delim) && (delim < iri+split_ret->query_end))
    {
      const wchar_t *scan = iri;
      while (scan <  delim)
        {
          if (scan[0] & ~0x7f)
            goto schema_done;
          if (!isalnum ((unsigned char) (scan[0])) && (NULL == strchr ("+-.", ((char *)scan)[0])))
            goto schema_done;
          scan++;
        }
      split_ret->schema_end = delim-iri;
      split_ret->netloc_begin = delim + 1 - iri;
    }
schema_done:
/* Here we know SS Nn pp pp qQ FF  t */
  if (('/' == iri[split_ret->netloc_begin]) && ('/' == iri[split_ret->netloc_begin+1]))
    {
      split_ret->netloc_begin += 2;
      split_ret->two_slashes = split_ret->netloc_begin;
      delim = virt_wcschr (iri + split_ret->netloc_begin, '/');
      if ((NULL != delim) && (delim < iri+split_ret->query_end))
        {
          split_ret->netloc_end = split_ret->path_begin = delim - iri;
        }
      else
        {
          split_ret->netloc_end = split_ret->path_begin = split_ret->path_end = split_ret->params_begin = split_ret->params_end = split_ret->query_begin = split_ret->query_end;
          return;
        }
    }
  else
    {
      split_ret->two_slashes = 0;
      split_ret->netloc_end = split_ret->path_begin = split_ret->netloc_begin;
    }
/* Here we know SS NN Pp pp qQ FF  T */
  delim = virt_wcschr (iri + split_ret->path_begin, '?');
  if ((NULL != delim) && (delim < iri+split_ret->query_end))
    {
      split_ret->query_begin = delim + 1 - iri;
      split_ret->params_end = delim - iri;
    }
  else
    {
      split_ret->params_end = split_ret->query_begin = split_ret->query_end;
    }
/* Here we know SS NN Pp pP QQ FF  T */
  delim = virt_wcschr (iri + split_ret->path_begin, ';');
  if ((NULL != delim) && (delim < iri+split_ret->params_end))
    {
      split_ret->params_begin = delim + 1 - iri;
      split_ret->path_end = delim - iri;
    }
  else
    {
      split_ret->path_end = split_ret->params_begin = split_ret->params_end;
    }
/* Here we know SS NN PP PP QQ FF  T */
  CHECK_RDF1808_SPLIT((split_ret[0]), virt_wcslen (iri))
}

/*! URI parser according RFC 1808 recommendations
returns array of six past-the end indexes of elements */
static caddr_t
bif_rfc1808_parse_uri (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ccaddr_t uri = bif_string_or_wide_or_uname_arg (qst, args, 0, "rfc1808_parse_uri");
  dtp_t uri_dtp = DV_TYPE_OF (uri);
  size_t uri_len;
  rdf1808_split_t split;
  caddr_t res;
  uri_len = box_length (uri);
  if (SMALLEST_POSSIBLE_POINTER <= uri_len)
    {
      if (DV_WIDE == uri_dtp)
        sqlr_new_error ("22023", "SR571", "Function rfc1808_parse_uri() got abnormally long URI as argument (%ld chars)",
          (long)(uri_len - 1) );
      else
        sqlr_new_error ("22023", "SR570", "Function rfc1808_parse_uri() got abnormally long URI as argument (%ld chars, '%.50s ... %50s')",
          (long)(uri_len - 1), uri, uri + uri_len - 51 );
    }
  if (DV_WIDE == uri_dtp)
    rfc1808_parse_wide_uri ((const wchar_t *)uri, &split);
  else
    rfc1808_parse_uri (uri, &split);
  if ((1 < BOX_ELEMENTS(args)) && bif_long_arg (qst, args, 1, "rfc1808_parse_uri"))
    {
      res = dk_alloc_box (DV_ARRAY_OF_POINTER, sizeof (rdf1808_split_t));
      memcpy (res, &split, 13 * sizeof (rdf1808_split_t));
      return res;
    }
  if (DV_WIDE == uri_dtp)
    {
      wchar_t *wideuri = (wchar_t *)uri;
      return list (6,
        box_wide_char_string ((caddr_t)(wideuri + split.schema_begin)	, (split.schema_end - split.schema_begin) * sizeof (wchar_t)	, DV_WIDE),
        box_wide_char_string ((caddr_t)(wideuri + split.netloc_begin)	, (split.netloc_end - split.netloc_begin) * sizeof (wchar_t)	, DV_WIDE),
        (((split.path_end == split.path_begin) && (0 < split.two_slashes)) ?
          box_wide_char_string ((caddr_t)(L"/"), sizeof (wchar_t), DV_WIDE) :
          box_wide_char_string ((caddr_t)(wideuri + split.path_begin)	, (split.path_end - split.path_begin) * sizeof (wchar_t)	, DV_WIDE) ),
        box_wide_char_string ((caddr_t)(wideuri + split.params_begin)	, (split.params_end - split.params_begin) * sizeof (wchar_t)	, DV_WIDE),
        box_wide_char_string ((caddr_t)(wideuri + split.query_begin)	, (split.query_end - split.query_begin) * sizeof (wchar_t)	, DV_WIDE),
        box_wide_char_string ((caddr_t)(wideuri + split.fragment_begin)	, (split.fragment_end - split.fragment_begin) * sizeof (wchar_t), DV_WIDE) );
    }
  else
    {
      box_t (*box_x_nchars)(const char *buf, size_t len) =
        ((DV_UNAME == uri_dtp) ?
          box_dv_uname_nchars : box_dv_short_nchars );
      return list (6,
        box_x_nchars (uri + split.schema_begin	, split.schema_end - split.schema_begin),
        box_x_nchars (uri + split.netloc_begin	, split.netloc_end - split.netloc_begin),
        (((split.path_end == split.path_begin) && (0 < split.two_slashes)) ?
          box_x_nchars ("/", 1) :
          box_x_nchars (uri + split.path_begin	, split.path_end - split.path_begin) ),
        box_x_nchars (uri + split.params_begin	, split.params_end - split.params_begin),
        box_x_nchars (uri + split.query_begin	, split.query_end - split.query_begin),
        box_x_nchars (uri + split.fragment_begin, split.fragment_end - split.fragment_begin) );
   }
}

/*! URI expander according RFC 1808 recommendations */
caddr_t
rfc1808_expand_uri (/*query_instance_t *qi,*/ ccaddr_t base_uri, ccaddr_t rel_uri,
  ccaddr_t output_cs_name, int do_resolve_like_http_get,
  ccaddr_t base_string_cs_name, /* Encoding used for base_uri IFF it is a narrow string, neither DV_UNAME nor WIDE */
  ccaddr_t rel_string_cs_name, /* Encoding used for rel_uri IFF it is a narrow string, neither DV_UNAME nor WIDE */
  caddr_t * err_ret )
{
  caddr_t output_cs_upcase = output_cs_name ? sqlp_box_upcase (output_cs_name) : NULL;
  const char *buffer_cs_upcase = (((NULL == output_cs_name) || strcmp (output_cs_name, "_WIDE_")) ? output_cs_name : "UTF-8");
  const char *base_cs, *rel_cs;
  int buf_len;
  char *buf_tail = NULL, *buf_prev_tail = NULL;
  dtp_t base_uri_dtp = DV_TYPE_OF (base_uri);
  dtp_t rel_uri_dtp = DV_TYPE_OF (rel_uri);
  caddr_t buffer = NULL, res = NULL;
  int base_uri_is_temp = 0;
  int rel_uri_is_temp = 0;
  int buffer_is_temp = 0;
  int res_is_new = 0;
  rdf1808_split_t base_split, rel_split;
  err_ret[0] = NULL;
  switch (base_uri_dtp)
    {
    case DV_WIDE: base_cs = "_WIDE_"; break;
    case DV_UNAME: base_cs = "UTF-8"; break;
    case DV_STRING: base_cs = base_string_cs_name; break;
    default: base_cs = buffer_cs_upcase; break;
    }
  switch (rel_uri_dtp)
    {
    case DV_WIDE: rel_cs = "_WIDE_"; break;
    case DV_UNAME: rel_cs = "UTF-8"; break;
    case DV_STRING: rel_cs = rel_string_cs_name; break;
    default: rel_cs = buffer_cs_upcase; break;
    }
  if ((base_cs != buffer_cs_upcase) && !((NULL != base_cs) && (NULL != buffer_cs_upcase) && !strcmp (base_cs, buffer_cs_upcase)))
    {
      base_uri = charset_recode_from_named_to_named ((query_instance_t *)NULL, (caddr_t)base_uri, base_cs, buffer_cs_upcase, &base_uri_is_temp, err_ret);
      if (err_ret[0]) goto res_complete; /* see below */
    }
  if ((rel_cs != buffer_cs_upcase) && !((NULL != rel_cs) && (NULL != buffer_cs_upcase) && !strcmp (rel_cs, buffer_cs_upcase)))
    {
      rel_uri = charset_recode_from_named_to_named ((query_instance_t *)NULL, (caddr_t)rel_uri, rel_cs, buffer_cs_upcase, &rel_uri_is_temp, err_ret);
      if (err_ret[0]) goto res_complete; /* see below */
    }
  if ((NULL == base_uri) || ('\0' == base_uri[0]))
    {
      buffer = (caddr_t) rel_uri;
      buffer_is_temp = rel_uri_is_temp;
      rel_uri_is_temp = 0;
      goto buffer_ready; /* see below */
    }
  if ((NULL == rel_uri) ||
    (('\0' == rel_uri[0]) && (NULL == strchr (base_uri, '#')) && (NULL == strchr (base_uri, '?'))) )
    {
      buffer = (caddr_t) base_uri;
      buffer_is_temp = base_uri_is_temp;
      base_uri_is_temp = 0;
      goto buffer_ready; /* see below */
    }
  rfc1808_parse_uri (rel_uri, &rel_split);
  if (0 != rel_split.schema_end)
    {
      buffer = (caddr_t) rel_uri;
      buffer_is_temp = rel_uri_is_temp;
      rel_uri_is_temp = 0;
      goto buffer_ready; /* see below */
    }
  rfc1808_parse_uri (base_uri, &base_split);
  if ((0 == base_split.schema_end) && (0 != base_split.path_end) && do_resolve_like_http_get)
    {
      caddr_t fixed_base;
      int prefix_len = ((0 != base_split.two_slashes) ? 5 : 7);
      buf_len = base_split.fragment_end + prefix_len;
      fixed_base = dk_alloc_box (base_split.fragment_end + prefix_len + 1, DV_STRING);
      strcpy_box_ck (fixed_base, ((0 != base_split.two_slashes) ? "http:" : "http://"));
      strcat_box_ck (fixed_base, base_uri);
      buffer = rfc1808_expand_uri (/*qi,*/ fixed_base, rel_uri, buffer_cs_upcase, 0, buffer_cs_upcase, buffer_cs_upcase, err_ret);
      if (NULL != err_ret[0])
        {
          dk_free_box (fixed_base);
          goto res_complete;
        }
      if (buffer == fixed_base)
        buffer_is_temp = 1;
      else
        {
          dk_free_box (fixed_base);
          if (buffer == rel_uri)
            {
              buffer_is_temp = rel_uri_is_temp;
              rel_uri_is_temp = 0;
            }
          else
            buffer_is_temp = 1;
        }
      goto buffer_ready;
    }
  buf_len = base_split.fragment_end + rel_split.fragment_end + 20;
  buf_prev_tail = buf_tail = buffer = dk_alloc_box (buf_len, DV_STRING);
  buffer_is_temp = 1;

  if ((base_split.fragment_begin == base_split.fragment_end) && (base_split.query_end == base_split.fragment_begin-1))
    {
      if ((0 == rel_split.path_begin) && (rel_split.path_end == rel_split.fragment_end) && (NULL == strchr (rel_uri, '/')))
        {
          rel_split.path_end =
          rel_split.params_begin = rel_split.params_end =
          rel_split.query_begin = rel_split.query_end =
          rel_split.fragment_begin = 0;
        }
    }
#define TAIL_APPEND_CUT(pref,fld,prefix,prefix_len,suffix,suffix_len) \
    { \
      int cut_len = pref##_split.fld##_end - pref##_split.fld##_begin; \
      if (prefix_len) \
        { \
          memcpy (buf_tail, prefix, prefix_len); \
          buf_tail += prefix_len; \
        } \
      memcpy (buf_tail, pref##_uri + pref##_split.fld##_begin, cut_len); \
      buf_tail += cut_len; \
      if (suffix_len) \
        { \
          memcpy (buf_tail, suffix, suffix_len); \
          buf_tail += suffix_len; \
        } \
      buf_prev_tail = buf_tail; \
    }
#ifndef NDEBUG
#define IF_NONEMPTY_THEN_TAIL_APPEND_CUT(pref,fld,prefix,prefix_len,suffix,suffix_len) \
  if (pref##_split.fld##_end != pref##_split.fld##_begin) \
    { \
      if (pref##_split.fld##_end < pref##_split.fld##_begin) \
        GPF_T1("Ill boundaries"); \
      if ((buf_tail < buffer) || (buf_tail > buffer + box_length (buffer) - 5)) \
        GPF_T1("Ill buf_tail"); \
      if (buf_tail > buffer + buf_len) \
        GPF_T1("Dangerously big buf_tail"); \
      if (buf_tail + prefix_len + suffix_len + pref##_split.fld##_end - pref##_split.fld##_begin > buffer + buf_len) \
        GPF_T1("Dangerously big buf_tail forecast"); \
      TAIL_APPEND_CUT(pref,fld,prefix,prefix_len,suffix,suffix_len) \
    }
#else
#define IF_NONEMPTY_THEN_TAIL_APPEND_CUT(pref,fld,prefix,prefix_len,suffix,suffix_len) \
  if (pref##_split.fld##_end != pref##_split.fld##_begin) \
    TAIL_APPEND_CUT(pref,fld,prefix,prefix_len,suffix,suffix_len)
#endif
  IF_NONEMPTY_THEN_TAIL_APPEND_CUT(base,schema,"",0,":",1);

  IF_NONEMPTY_THEN_TAIL_APPEND_CUT(rel,netloc,"//",2,"",0)
  else
  IF_NONEMPTY_THEN_TAIL_APPEND_CUT(base,netloc,"//",2,"",0)

  if (0 == rel_split.path_end)
    {
      IF_NONEMPTY_THEN_TAIL_APPEND_CUT(base,path,"",0,"",0);
    }
  else if ((rel_split.path_begin != rel_split.path_end) && ('/' == rel_uri[rel_split.path_begin]))
    {
      IF_NONEMPTY_THEN_TAIL_APPEND_CUT(rel,path,"",0,"",0);
    }
  else if ((rel_split.path_begin == rel_split.path_end) && (0 != rel_split.path_end))
    {
      (buf_tail++)[0] = '/';
      buf_prev_tail = buf_tail;
    }
  else
    {
      char *base_lastslash = (char *) (base_uri + base_split.path_end);
      int base_beg_len, rel_len;
      char *hit;
      while (base_lastslash > base_uri + base_split.path_begin)
        {
          base_lastslash--;
          if ('/' == base_lastslash[0])
            break;
        }
      base_beg_len = base_lastslash - (base_uri + base_split.path_begin);
      if (base_beg_len > 0)
        {
          memcpy (buf_tail, base_uri + base_split.path_begin, base_beg_len);
          buf_tail += base_beg_len;
        }
      (buf_tail++)[0] = '/';
      rel_len = rel_split.path_end - rel_split.path_begin;
      memcpy (buf_tail, rel_uri + rel_split.path_begin, rel_len);
      buf_tail += rel_len;
      if (('.' == buf_tail[-1]) && (('/' == buf_tail[-2]) || (('.' == buf_tail[-2]) && ('/' == buf_tail[-3]))))
        (buf_tail++)[0] = '/';
      buf_tail[0] = '\0';
      hit = strstr (buf_prev_tail, "/./");
      while (NULL != hit)
        {
          char *shft = hit;
          while ('\0' != (shft[0] = shft[2])) shft++;
          buf_tail -= 2;
          hit = strstr (hit, "/./");
        }
      hit = strstr (buf_prev_tail, "/../");
      while (NULL != hit)
        {
          char *crop_end = hit+3;
          char *crop_begin;
          if (hit == buf_prev_tail)
            crop_begin = buf_prev_tail;
          else
            {
              crop_begin = hit-1;
              while ('/' != crop_begin[0] && crop_begin > buf_prev_tail) crop_begin--;
            }
          hit = crop_begin;
          while ('\0' != (crop_begin[0] = crop_end[0])) { crop_begin++; crop_end++; }
          buf_tail -= (crop_end - crop_begin);
          hit = strstr (hit, "/../");
        }
    }

  IF_NONEMPTY_THEN_TAIL_APPEND_CUT(rel,params,";",1,"",0)
  else if ((rel_split.schema_begin == rel_split.schema_end) &&
    (rel_split.netloc_begin == rel_split.netloc_end) &&
    (rel_split.path_begin == rel_split.path_end) )
    {
      IF_NONEMPTY_THEN_TAIL_APPEND_CUT(base,params,";",1,"",0);
    }
  IF_NONEMPTY_THEN_TAIL_APPEND_CUT(rel,query,"?",1,"",0)
  else if ((rel_split.schema_begin == rel_split.schema_end) &&
    (rel_split.netloc_begin == rel_split.netloc_end) &&
    (rel_split.path_begin == rel_split.path_end) &&
    (rel_split.params_begin == rel_split.params_end) )
    {
      IF_NONEMPTY_THEN_TAIL_APPEND_CUT(base,query,"?",1,"",0);
    }
  if (rel_split.fragment_end != rel_split.query_end)
    { /* This is an exception because empty "#" is also meaningful */
      TAIL_APPEND_CUT(rel,fragment,"#",1,"",0);
    }
  buf_tail[0] = '\0';

buffer_ready:
  if (NULL == buf_tail)
    {
      for (buf_tail = buffer; '\0' != buf_tail[0]; buf_tail++);
    }
  if ((buffer_cs_upcase != output_cs_upcase) &&
    ((NULL == buffer_cs_upcase) || (NULL == output_cs_upcase) || strcmp(buffer_cs_upcase, output_cs_upcase)) )
    {
      caddr_t boxed_buffer = box_dv_short_nchars (buffer, buf_tail - buffer);
      res = charset_recode_from_named_to_named ((query_instance_t *)NULL, boxed_buffer, buffer_cs_upcase, output_cs_upcase, &res_is_new, err_ret);
      if (res_is_new)
        dk_free_box (boxed_buffer);
      else
        res_is_new = 1;
      if (err_ret[0])
        goto res_complete; /* see below */
    }
  else
    {
      if (NULL != buf_prev_tail)
        {
          res = box_dv_short_nchars (buffer, buf_tail - buffer);
          res_is_new = 1;
        }
      else
        {
          res = buffer;
          res_is_new = buffer_is_temp;
          buffer_is_temp = 0;
        }
    }

res_complete:
  if (!res_is_new)
    res = box_copy (res);
  dk_free_box (output_cs_upcase);
  if (base_uri_is_temp)
    dk_free_box ((caddr_t) base_uri);
  if (rel_uri_is_temp)
    dk_free_box ((caddr_t) rel_uri);
  if (buffer_is_temp)
    dk_free_box (buffer);
  return res;
}


/*! URI expander according RFC 1808 recommendations */
static caddr_t
bif_rfc1808_expand_uri (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t base_uri = bif_string_or_uname_or_wide_or_null_arg (qst, args, 0, "rfc1808_expand_uri");
  caddr_t rel_uri = bif_string_or_uname_or_wide_or_null_arg (qst, args, 1, "rfc1808_expand_uri");
  ccaddr_t output_cs_name = ((2 < BOX_ELEMENTS(args)) ? bif_string_or_null_arg (qst, args, 2, "rfc1808_expand_uri") : NULL);
  int resolve_like_http_get = ((3 < BOX_ELEMENTS(args)) ? bif_long_arg (qst, args, 3, "rfc1808_expand_uri") : 0);
  ccaddr_t base_cs_name = ((4 < BOX_ELEMENTS(args)) ? bif_string_or_null_arg (qst, args, 4, "rfc1808_expand_uri") : NULL);
  ccaddr_t rel_cs_name = ((5 < BOX_ELEMENTS(args)) ? bif_string_or_null_arg (qst, args, 5, "rfc1808_expand_uri") : NULL);
  caddr_t err = NULL;
  caddr_t res = rfc1808_expand_uri (/*(query_instance_t *)qst,*/ base_uri, rel_uri, output_cs_name, resolve_like_http_get, base_cs_name, rel_cs_name, &err);
  int res_is_new = ((res != base_uri) && (res != rel_uri));
  if (NULL != err)
    {
      if (res_is_new)
        dk_free_box (res);
      sqlr_resignal (err);
    }
  if (res_is_new)
    return res;
  return box_copy (res);
}

static caddr_t
bif_patch_restricted_xml_chars (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
#define o 0
static char restricted_xml_chars[0x80] = {
/*0 1 2 3 4 5 6 7 8 9 A B C D E F */
  3,3,3,3,3,3,3,3,3,5,5,3,3,5,3,3,
/*0 1 2 3 4 5 6 7 8 9 A B C D E F */
  3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
/*  ! " # $ % & ' ( ) * + , - . / */
  o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
/*0 1 2 3 4 5 6 7 8 9 : ; < = > ? */
  o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
/*@ A B C D E F G H I J K L M N O */
  o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
/*P Q R S T U V W X Y Z [ \ ] ^ _ */
  o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
/*` a b c d e f g h i j k l m n o */
  o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,
/*p q r s t u v w x y z { | } ~   */
  o,o,o,o,o,o,o,o,o,o,o,o,o,o,o,o };
#undef o
  caddr_t src = bif_string_or_uname_or_wide_or_null_arg (qst, args, 0, "patch_restricted_xml_chars");
  int add_percents = bif_long_arg (qst, args, 1, "patch_restricted_xml_chars");
  dtp_t src_dtp;
  int src_box_length;
  int weird_char_ctr = 0;
  caddr_t dest_to_swap;
  if (NULL == src)
    return NULL;
  src_dtp = DV_TYPE_OF (src);
  src_box_length = box_length (src);
  if (!SSL_IS_REFERENCEABLE (args[0]))
    sqlr_new_error ("22023", "SR642", "The first argument of patch_restricted_xml_chars() should be a variable, not a constant or an expression");
  if (DV_WIDE == src_dtp)
    {
      wchar_t *tail = (wchar_t *)src;
      wchar_t *end = ((wchar_t *)(src + src_box_length)) - 1;
      wchar_t *dest, *dest_tail;
      if (add_percents)
        {
          for (;tail < end; tail++)
            {
              if (tail[0] & ~0x7F)
                continue;
              if (restricted_xml_chars[tail[0]])
                weird_char_ctr++;
            }
          if (0 == weird_char_ctr)
            return NULL;
          dest = dest_tail = dk_alloc_box ((sizeof (wchar_t) * 2 * weird_char_ctr) + src_box_length, src_dtp);
          dest_to_swap = (caddr_t) dest;
          for (tail = (wchar_t *)src; tail < end; tail++)
            {
              if ((tail[0] & ~0x7F) || (0 == restricted_xml_chars[(unsigned)(tail[0])]))
                (dest_tail++)[0] = tail[0];
              else
                {
                  (dest_tail++)[0] = '%';
                  (dest_tail++)[0] = "0123456789ABCDEF"[(tail[0] >> 4) & 0xf];
                  (dest_tail++)[0] = "0123456789ABCDEF"[tail[0] & 0xf];
                }
            }
          dest_tail[0] = 0;
        }
      else
        {
          for (;tail < end; tail++)
            {
              if (tail[0] & ~0x7F)
                continue;
              if (restricted_xml_chars[tail[0]] & 2)
                tail[0] = ' ';
            }
          return NULL;
        }
    }
  else
    {
      char *tail = src;
      char *end = src + src_box_length - 1;
      char *dest, *dest_tail;
      int dest_box_len;
      if (add_percents)
        {
          for (;tail < end; tail++)
            {
              if (tail[0] & ~0x7F)
                continue;
              if (restricted_xml_chars[(unsigned)(tail[0])])
                weird_char_ctr++;
            }
          if (0 == weird_char_ctr)
            return NULL;
          dest_box_len = (2 * weird_char_ctr) + src_box_length;
          dest_to_swap = dest = dest_tail = dk_alloc_box (dest_box_len, (DV_UNAME == src_dtp) ? DV_STRING : src_dtp);
          for (tail = src; tail < end; tail++)
            {
              if ((tail[0] & ~0x7F) || (0 == restricted_xml_chars[(unsigned)(tail[0])]))
                (dest_tail++)[0] = tail[0];
              else
                {
                  (dest_tail++)[0] = '%';
                  (dest_tail++)[0] = "0123456789ABCDEF"[(tail[0] >> 4) & 0xf];
                  (dest_tail++)[0] = "0123456789ABCDEF"[tail[0] & 0xf];
                }
            }
          dest_tail[0] = 0;
          if (DV_UNAME == src_dtp)
            {
              dest_to_swap = box_dv_uname_nchars (dest, dest_box_len - 1);
              dk_free_tree (dest);
            }
        }
      else
        {
          if (DV_UNAME == src_dtp)
            {
              for (;tail < end; tail++)
                {
                  if (tail[0] & ~0x7F)
                    continue;
                  if (restricted_xml_chars[(unsigned)(tail[0])])
                    weird_char_ctr++;
                }
              if (0 == weird_char_ctr)
                return NULL;
              tail = src = box_dv_short_nchars (src, src_box_length - 1);
              end = src + src_box_length - 1;
            }
          for (;tail < end; tail++)
            {
              if (tail[0] & ~0x7F)
                continue;
              if (restricted_xml_chars[(unsigned)(tail[0])] & 2)
                tail[0] = ' ';
            }
          if (DV_UNAME == src_dtp)
            {
              dest_to_swap = box_dv_uname_nchars (src, src_box_length - 1);
              dk_free_tree (src);
            }
          else
            return NULL;
        }
    }
  qst_swap (qst, args[0], &dest_to_swap);
  dk_free_tree (dest_to_swap);
  return NULL;
}



/*
   __stop_cpt (0,1,2,3)
   for testing cpt recovery only,
   the flag == 1 will cause server to exit after cpt recov file is done
   flag == 2 will exit before recov file is marked as complete
   flag == 3 will simulate out of space
 */
static caddr_t
bif_stop_cpt (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int flag = (int) bif_long_arg (qst, args, 0, "__stop_cpt");
  if (!QI_IS_DBA (qst))
    return 0;
  dbs_stop_cp = flag;
  return box_num (flag);
}

static caddr_t
bif_format_number (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * me = "format_number";
  NUMERIC_VAR (num_buf);
  numeric_t number = (numeric_t) num_buf;
  caddr_t number_box = bif_arg (qst, args, 0, me);
  caddr_t format = bif_string_arg (qst, args, 1, me);
  xslt_number_format_t *nf = xsnf_default;
  caddr_t res = NULL, err;

  NUMERIC_INIT (num_buf);

  if (NULL != (err = numeric_from_x (number, number_box, NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, "format_number",-1, NULL)))
    sqlr_resignal (err);
  res = xslt_format_number (number, format, nf);
  return res;
}


static caddr_t
bif_this_server (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return NEW_DB_NULL;
}
static caddr_t
bif_is_geometry (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_num (0);
}

void
sqlbif2_init (void)
{
  pwnam_mutex = mutex_allocate ();
  mutex_option (pwnam_mutex, "pwnam_mutex", NULL, NULL);
#ifndef KEYCOMP
  bif_define_typed ("itc_dive_transit_call_ctr", bif_itc_dive_transit_call_ctr, &bt_integer);
  bif_define_typed ("itc_try_land_call_ctr", bif_itc_try_land_call_ctr, &bt_integer);
#endif
  bif_define ("__ddl_read_constraints", bif_ddl_read_constraints);
  bif_define_typed ("sys_lockdown", bif_sys_lockdown, &bt_integer);
  bif_define_typed ("__blob_handle_from_session", bif_blob_handle_from_session, &bt_blob_handle);
  bif_define_typed ("os_chmod", bif_os_chmod, &bt_varchar);
  bif_define_typed ("host_id", bif_host_id, &bt_varchar);
  bif_define_typed ("os_chown", bif_os_chown, &bt_varchar);
  bif_define_typed ("user_has_role", bif_user_has_role, &bt_integer);
  bif_define_typed ("user_is_dba", bif_user_is_dba, &bt_integer);
  bif_define_typed ("client_attr", bif_client_attr, &bt_integer);
  bif_define_typed ("query_instance_id", bif_query_instance_id, &bt_integer);
  bif_define ("sql_warning", bif_sql_warning);
  bif_define ("sql_warnings_resignal", bif_sql_warnings_resignal);
  bif_define_typed ("__sec_uid_to_user", bif_sec_uid_to_user, &bt_varchar);
  bif_define ("current_proc_name", bif_current_proc_name);
  bif_define ("zorder_index", bif_zorder_index);
  bif_define ("rfc1808_parse_uri", bif_rfc1808_parse_uri);
  bif_define ("rfc1808_expand_uri", bif_rfc1808_expand_uri);
  bif_define ("patch_restricted_xml_chars", bif_patch_restricted_xml_chars);
  bif_define_typed ("format_number", bif_format_number, &bt_varchar);
  bif_define ("__stop_cpt", bif_stop_cpt);
  bif_define ("repl_this_server", bif_this_server);
  bif_define ("isgeometry", bif_is_geometry);
  /*sqls_bif_init ();*/
  sqls_bif_init ();
  sqlo_inv_bif_int ();
}

void
sqlbif_sequence_init (void)
{
  /* sequence_set bifs */
  bif_define_typed ("sequence_set", bif_sequence_set, &bt_integer);
}

/* This should stay the last part of the file */
#define YY_INPUT(buf, res, max) \
  res = yy_string_input (buf, max);

#define SCN3SPLIT
#include "scn3split.c"

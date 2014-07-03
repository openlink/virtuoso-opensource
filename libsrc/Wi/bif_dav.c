/*
 *  bif_dav.c
 *
 *  $Id$
 *
 *  DAV support
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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

/* IvAn/ParseDTD/000721 system parser is wiped out
#include <xmlparse.h> */

#include "sqlnode.h"
#include "sqlfn.h"
#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlbif.h"
#include "arith.h"
#include "security.h"
#include "sqlpfn.h"
#include "libutil.h"

#include "xml.h"
#include "http.h"

void
log_dav (ws_connection_t * ws, int where)
{
  char buf[1024], time_buf[100];
  time_t now;
  struct tm *tm;
#if defined (HAVE_LOCALTIME_R) && !defined (WIN32)
  struct tm tm1;
#endif
 long msec = get_msec_real_time ();

  if (!debug_log || !ws)
    return;

  time (&now);
#if defined (HAVE_LOCALTIME_R) && !defined (WIN32)
  tm = localtime_r (&now, &tm1);
#else
  tm = localtime (&now);
#endif

  strftime (time_buf, sizeof(time_buf), "%d/%b/%Y %T %z", tm);

  if (!where)
    {
      snprintf (buf, sizeof (buf), ">>> [%s] [%s] [%ld] %s", ws->ws_client_ip, time_buf, msec, ws->ws_lines[0]);
    }
  else
    {
      snprintf (buf, sizeof (buf), "<<< [%s] [%s] [%ld] %s\r\n", ws->ws_client_ip, time_buf, msec,
	  ws->ws_status_line ? ws->ws_status_line : "HTTP/1.1 200 OK");
    }

  mutex_enter (ws_http_log_mtx);
  fputs (buf, debug_log);
  fflush (debug_log);
  mutex_leave (ws_http_log_mtx);
}


long
bh_get_data_from_http_user (blob_handle_t * bh, client_connection_t * cli,
    db_buf_t to, int max_bytes)
{
  volatile int readed = 0;
  int to_read = (int) MIN (max_bytes, bh->bh_bytes_coming);
  dk_session_t *ses = bh->bh_source_session ?
      (DV_TYPE_OF (bh->bh_source_session) == DV_CONNECTION ?
       ((dk_session_t **)bh->bh_source_session)[0] : ((dk_session_t *)bh->bh_source_session)) :
      cli->cli_ws->ws_session;
  ws_connection_t * ws = cli->cli_ws;

  CATCH_READ_FAIL (ses)
    {
      session_buffered_read (ses, (char *) to, to_read);
      bh->bh_bytes_coming -= to_read;
      if (!bh->bh_bytes_coming)
	bh->bh_all_received = BLOB_ALL_RECEIVED;
      readed = to_read;
      if (ws && ws->ws_session == ses)
	ws->ws_req_len -= to_read;
    }
  FAILED
    {
      bh->bh_all_received = BLOB_ALL_RECEIVED;
      readed = 0;
      if (ws && ws->ws_session == ses)
	ws->ws_req_len = 0;
    }
  END_READ_FAIL (ses);
  if (bh->bh_all_received == BLOB_ALL_RECEIVED && bh->bh_source_session)
    {
      dk_free_box (bh->bh_source_session);
      bh->bh_source_session = NULL;
    }
  return readed;
}


long
bh_get_data_from_http_user_no_err (blob_handle_t * bh, client_connection_t * cli,
    db_buf_t to, int max_bytes)
{
  volatile int readed = 0;
  int to_read = max_bytes;
  dk_session_t *ses = bh->bh_source_session ?
      (DV_TYPE_OF (bh->bh_source_session) == DV_CONNECTION ?
       ((dk_session_t **)bh->bh_source_session)[0] : ((dk_session_t *)bh->bh_source_session)) :
      cli->cli_ws->ws_session;

  CATCH_READ_FAIL (ses)
    {
      session_buffered_read_n (ses, (char *) to, to_read, (int *) &readed);
    }
  FAILED
    {
      bh->bh_all_received = BLOB_ALL_RECEIVED;
    }
  END_READ_FAIL (ses);
  if (bh->bh_all_received == BLOB_ALL_RECEIVED && bh->bh_source_session)
    {
      dk_free_box (bh->bh_source_session);
      bh->bh_source_session = NULL;
    }
  return readed;
}


static caddr_t
ws_dav_put (ws_connection_t * ws, query_t * http_call)
{
  caddr_t err = NULL;
  dk_set_t parts = NULL;
  char *pmethod = NULL;
  size_t method_len = 0;
  char p_name [PATH_ELT_MAX_CHARS + 20];
  char method_name[100];
  int inx = 0;
  blob_handle_t *bh = NULL;
  caddr_t content_transfer_encoding = ws_mime_header_field (ws->ws_lines, "Transfer-Encoding", NULL, 0);
  pmethod = strchr (ws->ws_req_line, '\x20');
  if (pmethod)
    {
      method_len = pmethod - ws->ws_req_line;
      if (method_len > sizeof (method_name))
	method_len = sizeof (method_name) - 1;
      strncpy (method_name, ws->ws_req_line, method_len);
      method_name[method_len] = 0;
      snprintf (p_name, sizeof (p_name), "WS.WS.%s", method_name);
    }
  else
    strcpy_ck (p_name, "WS.WS.DEFAULT");

  if (!sch_proc_def (/*isp_schema (db_main_tree->it_commit_space)*/ wi_inst.wi_schema, p_name))
    strcpy_ck (p_name, "WS.WS.DEFAULT");
  else
   if (!strstr (p_name, "WS.WS.DEFAULT"))
    {
      caddr_t ts;
      caddr_t complete_name =
	  dk_alloc_box (strlen (p_name + 6) + strlen (www_root) + 2,
	  DV_C_STRING);
      caddr_t ts1;

      IN_TXN;
      ts1 = registry_get (p_name + 6);
      LEAVE_TXN;
      strcpy_box_ck (complete_name, www_root);
      strcat_box_ck (complete_name, p_name + 6);
      ts = file_stat (complete_name, 0);
      dk_free_box (complete_name);
      if (ts)
	{
	  if ((ts1 && strcmp (ts, ts1)) || !ts1)
	    strcpy_ck (p_name, "WS.WS.DEFAULT");
	  dk_free_box (ts);
	}
      if (ts1)
	dk_free_box (ts1);
    }

  dk_set_push (&parts, box_dv_short_string ("Content"));
  if (ws->ws_req_len == 0 && content_transfer_encoding &&  0 == strnicmp (content_transfer_encoding, "chunked", 7))
    {
       caddr_t chunks = http_read_chunked_content (ws->ws_session, &err, "", 1);
       if (err)
	 goto err_ret;
       dk_set_push (&parts, chunks);
    }
  else
    {
      bh = bh_alloc (DV_BLOB_HANDLE_DTP_FOR_BLOB_DTP (DV_BLOB_BIN));
      bh->bh_ask_from_client = 2;
      bh->bh_bytes_coming = ws->ws_req_len;
      dk_set_push (&parts, bh);
    }

  if (ws->ws_params != NULL)
    {
      DO_BOX (char *, line, inx, ws->ws_params)
	{
	  dk_set_push (&parts, line);
	}
      END_DO_BOX;
      dk_free_box ((box_t) ws->ws_params);
      ws->ws_params = NULL;
    }
  ws->ws_params = (caddr_t *) list_to_array (dk_set_nreverse (parts));

#ifndef VIRTUAL_DIR
  if (!strcmp ("/", dav_root))
    {
      /* adds DAV as a first path element to DAV (compatible with PL) */
      long path_len = box_length (ws->ws_path);
      caddr_t *new_path = (caddr_t *)
	  dk_alloc_box (path_len + sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      new_path[0] = box_dv_short_string ("DAV");
      if (path_len)
	memcpy (&(new_path[1]) , (caddr_t) ws->ws_path, path_len);
      dk_free_box (ws->ws_path);
      ws->ws_path = new_path;
    }
  else
    {
      /* substitutes the first path element to DAV (compatible with PL) */
      dk_free_box (ws->ws_path[0]);
      ws->ws_path[0] = box_dv_short_string ("DAV");
    }
  dk_free_box (ws->ws_path_string);
  ws_set_path_string (ws, 0);
#endif

  err = qr_quick_exec (http_call, ws->ws_cli, NULL, NULL, 4,
      ":0", p_name, QRP_STR,
#ifndef VIRTUAL_DIR
      ":1", box_copy_tree (ws->ws_path), QRP_RAW,
#else
      ":1", box_copy_tree ((box_t) ws->ws_p_path), QRP_RAW,
#endif
      ":2", ws->ws_params, QRP_RAW,
      ":3", box_copy_tree ((box_t) ws->ws_lines), QRP_RAW);

err_ret:
  if (IS_BOX_POINTER (err) && 0 != strcmp (ERR_STATE (err), "VSPRT"))
    {
      dk_free_box (ws->ws_header);
      ws->ws_header = NULL;
    };

  log_dav(ws, 1);

  ws->ws_try_pipeline = 0;

  ws->ws_params = NULL;
  dk_free_tree (content_transfer_encoding);
  return err;
}


caddr_t
ws_dav (ws_connection_t * ws, query_t * http_call)
{
  int n_deadlocks = 0;
  caddr_t err = NULL;
  dk_session_t * ses = NULL;
  dk_set_t parts = NULL;
  char *pmethod = NULL;
  size_t method_len = 0;
  char p_name [PATH_ELT_MAX_CHARS + 20];
  char method_name[100];
  int inx = 0;
  char *szContentType = ws_header_field (ws->ws_lines, "Content-type:", "application/octet-stream");
  log_dav (ws, 0);
  pmethod = strchr (ws->ws_req_line, '\x20');
  if (pmethod)
    {
      method_len = pmethod - ws->ws_req_line;
      if (method_len > sizeof (method_name))
	method_len = sizeof (method_name) - 1;
      strncpy (method_name, ws->ws_req_line, method_len);
      method_name[method_len] = 0;
      snprintf (p_name, sizeof (p_name), "WS.WS.%s", method_name);
/* The processing of request body does not depend on config or content of our server because the client forms it according to the HTTP specs, not according to our data or bugs */
      if (ws->ws_req_body && strcmp (p_name, "WS.WS.POST") && strcmp (p_name, "WS.WS.MPUT") && strcmp (p_name, "WS.WS.MDELETE"))
        {
          ses = ws->ws_req_body;
          ws->ws_req_body = NULL;
    }
  else
        ses = strses_allocate ();
      dk_set_push (&parts, box_dv_short_string ("Content"));
      dk_set_push (&parts, ses);
    }
  if (ws->ws_map->hm_exec_as_get || ws->ws_in_error_handler)
    {
      strcpy_ck (p_name, "WS.WS.GET");
      goto p_name_is_set;
    }
  if (!strcmp (ws->ws_method_name, "PUT"))
    return ws_dav_put (ws, http_call);
  else if (NULL == pmethod)
    strcpy_ck (p_name, "WS.WS.DEFAULT");
  if (!sch_proc_def (/*isp_schema (db_main_tree->it_commit_space)*/ wi_inst.wi_schema, p_name))
    strcpy_ck (p_name, "WS.WS.DEFAULT");
  else
   if (!strstr (p_name, "WS.WS.DEFAULT"))
    {
      caddr_t ts;
      caddr_t complete_name =
	  dk_alloc_box (strlen (p_name + 6) + strlen (www_root) + 2,
	  DV_C_STRING);
      caddr_t ts1;

      IN_TXN;
      ts1 = registry_get (p_name + 6);
      LEAVE_TXN;
      strcpy_box_ck (complete_name, www_root);
      strcat_box_ck (complete_name, p_name + 6);
      ts = file_stat (complete_name, 0);
      dk_free_box (complete_name);
      if (ts)
	{
	  if ((ts1 && strcmp (ts, ts1)) || !ts1)
	    strcpy_ck (p_name, "WS.WS.DEFAULT");
	  dk_free_box (ts);
	}
      if (ts1)
	dk_free_box (ts1);
    }

p_name_is_set:
  while (*szContentType && *szContentType <= '\x20')
    szContentType++;
  if (!strnicmp (szContentType, "multipart", 9))
    {
      dk_set_push (&parts, box_dv_short_string ("attr-Content"));
      dk_set_push (&parts, list (0));
    }
  if (ws->ws_params != NULL)
    {
      DO_BOX (char *, line, inx, ws->ws_params)
	{
	  dk_set_push (&parts, line);
	}
      END_DO_BOX;
      dk_free_box ((box_t) ws->ws_params);
      ws->ws_params = NULL;
    }
  ws->ws_params = (caddr_t *) list_to_array (dk_set_nreverse (parts));

#ifndef VIRTUAL_DIR
  if (!strcmp ("/", dav_root))
    {
      /* adds DAV as a first path element to DAV (compatible with PL) */
      long path_len = box_length (ws->ws_path);
      caddr_t *new_path = (caddr_t *)
	  dk_alloc_box (path_len + sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      new_path[0] = box_dv_short_string ("DAV");
      if (path_len)
	memcpy (&(new_path[1]) , (caddr_t) ws->ws_path, path_len);
      dk_free_box (ws->ws_path);
      ws->ws_path = new_path;
    }
  else
    {
      /* substitutes the first path element to DAV (compatible with PL) */
      dk_free_box (ws->ws_path[0]);
      ws->ws_path[0] = box_dv_short_string ("DAV");
    }
  dk_free_box (ws->ws_path_string);
  ws_set_path_string (ws, 0);
#endif

  do
    {
      caddr_t * newpars;
      dk_session_t * ses1 = NULL;

      ws->ws_params [1] = NULL;
      newpars = (caddr_t *) box_copy_tree ((box_t) ws->ws_params);
      ses1 = strses_allocate ();
      strses_write_out (ses, ses1);
      newpars [1] = (caddr_t) ses1;
      err = qr_quick_exec (http_call, ws->ws_cli, NULL, NULL, 4,
	  ":0", p_name, QRP_STR,
#ifndef VIRTUAL_DIR
	  ":1", box_copy_tree (ws->ws_path), QRP_RAW,
#else
	  ":1", box_copy_tree ((box_t) ws->ws_p_path), QRP_RAW,
#endif
	  ":2", newpars, QRP_RAW,
	  ":3", box_copy_tree ((box_t) ws->ws_lines), QRP_RAW);

     if (!IS_BOX_POINTER (err) || 0 != strcmp (ERR_STATE (err), "40001"))
	break;
     if (IS_BOX_POINTER (err) && 0 == strcmp (ERR_STATE (err), "40001"))
       {
         client_connection_t * cli = ws->ws_cli;
	 IN_TXN;
	 lt_rollback (cli->cli_trx, TRX_CONT);
	 LEAVE_TXN;
	 virtuoso_sleep (0, sqlbif_rnd (&rnd_seed_b) % 1000000 );
	 if (n_deadlocks++ > 5)
	   {
	     log_info ("More than 6 consecutive  deadlocks in DAV operation, returning error.");
	     break;
	   }
       }
    }
  while (1);

  if (IS_BOX_POINTER (err) && 0 != strcmp (ERR_STATE (err), "VSPRT"))
    {
      dk_free_box (ws->ws_header);
      ws->ws_header = NULL;
    };

  log_dav(ws, 1);

  dk_free_tree ((box_t) ws->ws_params);
  ws->ws_params = NULL;
  strses_flush (ses);
  dk_free_box ((box_t) ses);
  return err;
}


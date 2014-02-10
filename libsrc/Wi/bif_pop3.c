/*
 *  bif_pop3.c
 *
 *  $Id$
 *
 *  POP3 client function
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

#include "Dk.h"
#include "sqlnode.h"
#include "http.h"
#include "multibyte.h"
#include "srvmultibyte.h"
#include "sqlbif.h"
#include "libutil.h"
#include <stddef.h>
#include "xml.h"

#define IS_OK_NEXT(ses, resp, rc, err_c, err_t)  CATCH_READ_FAIL (ses) \
				     { \
				       resp[0] = 0; \
				       strncpy (err_text, err_t, sizeof(err_text)); \
                                       strncpy (err_code, err_c, sizeof(err_code)); \
            			       rc = dks_read_line (ses, resp, sizeof (resp)); \
				       if (is_ok (resp)) \
					 goto error_end; \
				     } \
				   FAILED \
				     { \
				       goto error_end; \
				     } \
				   END_READ_FAIL (ses)

#define SEND(ses, rc, cmd, var)	CATCH_WRITE_FAIL (ses) \
	                          { \
				     SES_PRINT (ses, cmd); \
				     SES_PRINT (ses, var); \
				     SES_PRINT (ses, "\r\n"); \
				     session_flush_1 (ses);\
				  } \
				FAILED \
				  { \
				    goto error_end; \
				  } \
				END_WRITE_FAIL (ses)

static int
is_ok (char *resp)
{
  if (strncmp ("+OK", resp, 3))
    return 1;
  return 0;
}


static void
pop3_get (char *host, caddr_t * err_ret, caddr_t user, caddr_t pass,
    long end_size, caddr_t mode, dk_set_t * ret_v, caddr_t * in, caddr_t * qst, long cert)
{
  int rc;
  volatile int inx, inx_mails;
  unsigned int number;
  volatile long size;
  dk_set_t uidl = NULL;
  caddr_t *volatile my_list = NULL;
  dk_session_t *ses = dk_session_allocate (SESCLASS_TCPIP);
  char num[11], resp[1024];
  char message[16], err_text[512], err_code[6];
  char end_msg[5] = ".\x0D\x0A\x00";
  dk_session_t *msg = NULL;
#ifdef _SSL
  SSL *ssl;
  SSL_CTX *ssl_ctx = NULL;
  SSL_METHOD *ssl_method;
#endif

  resp[0] = 0;
  err_code[0] = 0;
  if (!_thread_sched_preempt)
    {
      ses->dks_read_block_timeout = dks_fibers_blocking_read_default_to;
    }
  rc = session_set_address (ses->dks_session, host);
  if (SER_SUCC != rc)
    {
      PrpcSessionFree (ses);
      *err_ret = srv_make_new_error ("2E000", "PO001", "Cannot resolve host in pop3_get");
      return;
    }

  rc = session_connect (ses->dks_session);
  if (SER_SUCC != rc)
    {
      if (rc != SER_NOREC)
	session_disconnect (ses->dks_session);
      PrpcSessionFree (ses);
      *err_ret = srv_make_new_error ("08001", "PO002", "Cannot connect in pop3_get");
      return;
    }
  if (cert)
    {
      int ssl_err = 0;
      int fd = tcpses_get_fd (ses->dks_session);
      ssl_method = SSLv23_client_method ();
      ssl_ctx = SSL_CTX_new (ssl_method);
      ssl = SSL_new (ssl_ctx);
      SSL_set_fd (ssl, fd);
      ssl_err = SSL_connect (ssl);
      if (ssl_err != 1)
	{
	  strcpy_ck (err_code, "08006");
	  if (ERR_peek_error ())
	    cli_ssl_get_error_string (err_text, sizeof (err_text));
	  else
	    strcpy_ck (err_text, "Cannot connect via SSL");
	  goto error_end;
	}
      else
	tcpses_to_sslses (ses->dks_session, ssl);
    }

  msg = strses_allocate ();
  /* send AUTHORIZATION */

  IS_OK_NEXT (ses, resp, rc, "PO003", "No response from remote POP3 server");

  SEND (ses, rc, "USER ", user);
  IS_OK_NEXT (ses, resp, rc, "PO004", "Not valid user in remote POP3 server");
  SEND (ses, rc, "PASS ", pass);
  CATCH_READ_FAIL (ses)
    {
      resp[0] = 0;
      rc = dks_read_line (ses, resp, sizeof (resp));
      if (is_ok (resp))
	{
	  strncpy (err_text, resp, sizeof (err_text) - 1);
	  err_text[sizeof (err_text) - 1] = 0;
	  goto error_end;
	}
    }
  FAILED
    {
      goto error_end;
    }
  END_READ_FAIL (ses);
  /*  IS_OK_NEXT (ses, resp, rc, "Bad user name and password"); */

  inx_mails = 0;
  size = 0;

  /* get LIST of message and set size */

  SEND (ses, rc, "UIDL", "");
  IS_OK_NEXT (ses, resp, rc, "PO005", "UIDL command to remote POP3 server failed");

  CATCH_READ_FAIL (ses)
    {
      char next[101];
      volatile int l, br, fl;

      if (in)
	l = BOX_ELEMENTS (in);

      for (;;)
	{
	  rc = dks_read_line (ses, resp, sizeof (resp));
	  if (!strncmp (end_msg, resp, sizeof (end_msg)))
	    break;
	  sscanf (resp, "%i %100s", (int *) (&number), next);
	  if (in)
	    {
	      fl = 0;
	      for (br = 0; br < l; br++)
		{
		  if (!strcmp (in[br], next))
		    {
		      fl = 1;
		      break;
		    }
		}

	      if (fl)
		dk_set_push (&uidl, NULL);
	      else
		dk_set_push (&uidl, box_dv_short_string (next));
	    }
	  else
	    dk_set_push (&uidl, box_dv_short_string (next));
	}
    }
  FAILED
    {
      strncpy (err_code, "PO006", sizeof (err_code));
      strncpy (err_text, "Could not get output of UIDL from remote POP3 server.", sizeof (err_text));
      goto error_end;
    }
  END_READ_FAIL (ses);

  my_list = (caddr_t *) list_to_array (dk_set_nreverse (uidl));

  SEND (ses, rc, "LIST", "");
  IS_OK_NEXT (ses, resp, rc, "PO007", "LIST command to remote POP3 server failed.");

  CATCH_READ_FAIL (ses)
    {
      for (;;)
	{
	  long msg_size;
	  rc = dks_read_line (ses, resp, sizeof (resp));
	  if (!strncmp (end_msg, resp, sizeof (end_msg)))
	    break;
	  sscanf (resp, "%10s %li", num, &msg_size);

	  if (atoi (num) == 0)
	    if (num[0] != '.')
	      break;

	  if (my_list[atoi (num) - 1])
	    size = size + msg_size;

	  if (size < end_size)
	    {
	      inx_mails++;
	    }

	}
    }
  FAILED
    {
      strcpy_ck (err_code, "PO008");
      strncpy (err_text, "Could not get output of LIST from remote POP3 server.", sizeof (err_text));
      goto error_end;
    }
  END_READ_FAIL (ses);

  for (inx = 1; inx <= inx_mails; inx++)
    {
      snprintf (message, sizeof (message), "%i", inx);

      if (!my_list[inx - 1])
	continue;

      if (stricmp ("uidl", mode))
	{
	  /* READ message */

	  SEND (ses, rc, "RETR ", message);
	  IS_OK_NEXT (ses, resp, rc, "PO009", "Could not get a message from remote POP3 server");

	  strses_flush (msg);
	  strses_enable_paging (msg, http_ses_size);
	  CATCH_READ_FAIL (ses)
	    {
	      while (strncmp (end_msg, resp, sizeof (end_msg)))
		{
		  rc = dks_read_line (ses, resp, sizeof (resp));
		  if (strncmp (end_msg, resp, sizeof (end_msg)))
		    SES_PRINT (msg, resp);
		  if (tcpses_check_disk_error (msg, qst, 0))
		    {
		      strcpy_ck (err_text, "Server error in accessing temp file");
		      strcpy_ck (err_code, "PO010");
		      SESSION_SCH_DATA (ses)->sio_read_fail_on = 0;
		      goto error_end;
		    }
		}
	      session_flush_1 (msg);
	      if (tcpses_check_disk_error (msg, NULL, 0))
		{
		  strcpy_ck (err_text, "Server error in accessing temp file");
		  strcpy_ck (err_code, "PO010");
		  SESSION_SCH_DATA (ses)->sio_read_fail_on = 0;
		  goto error_end;
		}
	      if (!STRSES_CAN_BE_STRING (msg))
		{
		  dk_set_push (ret_v, list (2, my_list[inx-1], msg));
		  msg = strses_allocate ();
		}
	      else
		dk_set_push (ret_v, list (2, my_list[inx - 1], strses_string (msg)));
	      my_list[inx - 1] = NULL;
	    }
	  FAILED
	    {
	      strcpy_ck (err_code, "PO010");
	      strcpy_ck (err_text, "Failed reading output of LIST command on remote POP3 server");
	      goto error_end;
	    }
	  END_READ_FAIL (ses);
	}
      else
	{
	  dk_set_push (ret_v, my_list[inx - 1]);
	  my_list[inx - 1] = NULL;
	}

      if (!stricmp ("delete", mode))
	{
	  SEND (ses, rc, "DELE ", message);
	  IS_OK_NEXT (ses, resp, rc, "PO011",
		      "Could not DELE messages from remote POP3 server");
	}
    }

  /* QUIT from pop3 server */
  SEND (ses, rc, "QUIT", "");
  IS_OK_NEXT (ses, resp, rc, "PO012", "Could not QUIT from remote POP3 server");

  strses_free (msg);
  dk_free_tree ((box_t) my_list);
  PrpcDisconnect (ses);
  PrpcSessionFree (ses);
  SSL_CTX_free (ssl_ctx);
  return;

error_end:

  strses_free (msg);
  dk_free_tree ((box_t) my_list);
  PrpcDisconnect (ses);
  PrpcSessionFree (ses);
  SSL_CTX_free (ssl_ctx);

  if (err_code[0] != 0)
    *err_ret = srv_make_new_error ("08006", err_code, "%s", err_text);
  else
    *err_ret = srv_make_new_error ("08006", "PO014", "Misc. error in connection in pop3_get");
  return;
}

static caddr_t
bif_pop3_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *in_uidl = NULL;
  caddr_t addr = bif_string_arg (qst, args, 0, "pop3_get");
  caddr_t user = bif_string_arg (qst, args, 1, "pop3_get");
  caddr_t pass = bif_string_arg (qst, args, 2, "pop3_get");
  long end_size = (long) bif_long_arg (qst, args, 3, "pop3_get");
  caddr_t ret = NULL;

  caddr_t mode = "";
  caddr_t err = NULL;
  long cert = 0;
  dk_set_t volatile uidl_mes = NULL;
  IO_SECT (qst);

  if (BOX_ELEMENTS (args) > 4)
    mode = bif_string_arg (qst, args, 4, "pop3_get");

  if (BOX_ELEMENTS (args) > 5)
    {
      in_uidl = (caddr_t *) bif_array_or_null_arg (qst, args, 5, "pop3_get");

      if (in_uidl && DV_TYPE_OF (in_uidl) != DV_ARRAY_OF_POINTER)
	sqlr_new_error ("08000", "PO013", "Argument 6 to pop3_get must be a vector");
    }
  if (BOX_ELEMENTS (args) > 6)
    cert = bif_long_arg (qst, args, 6, "pop3_get");

  pop3_get (addr, &err, user, pass, end_size, mode, (dk_set_t *) & uidl_mes, in_uidl, qst, cert);

  if (err)
    {
      dk_free_tree (list_to_array (uidl_mes));
      uidl_mes = NULL;
      sqlr_resignal (err);
    }
  END_IO_SECT (err_ret);
  ret = list_to_array (dk_set_nreverse (uidl_mes));
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  return ret;
}

static caddr_t
bif_ses_write (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  dk_session_t *out;
  caddr_t string = bif_arg (qst, args, 0, "ses_write");
  dtp_t volatile dtp = DV_TYPE_OF (string);
  IO_SECT (qst);
  if (BOX_ELEMENTS (args) > 1)
    {
      out = http_session_arg (qst, args, 1, "ses_write");
    }
  else
    {
      if (!qi->qi_client->cli_ws)
	sqlr_new_error ("37000", "HT043",
	    "ses_write with no argument defaults it direct to the raw client connection.\nAllowed only inside HTTP request");
      out = qi->qi_client->cli_ws->ws_session;
    }

/*
    if (!qi->qi_client->cli_ws)
      sqlr_new_error ("37000", "HT043", "bif_ses_write not called inside HTTP context");

    out = qi->qi_client->cli_ws->ws_session; */

  CATCH_WRITE_FAIL (out)
    {
      if (dtp == DV_SHORT_STRING || dtp == DV_LONG_STRING ||
	  dtp == DV_C_STRING)
	session_buffered_write (out, string,
	    box_length (string) - (IS_STRING_DTP (DV_TYPE_OF (string)) ? 1 : 0));
      else if ((dtp == DV_BLOB_HANDLE) || (dtp == DV_BLOB_WIDE_HANDLE))
	{
	  blob_handle_t *bh = (blob_handle_t *) string;
	  if (!bh->bh_length)
	    {
	      if (bh->bh_ask_from_client)
		sqlr_new_error ("22023", "HT001",
		    "An interactive blob can't be passed as argument to ses_write");
	      goto endwrite;
	    }
	  bh->bh_current_page = bh->bh_page;
	  bh->bh_position = 0;
	  bh_write_out (qi->qi_trx, bh, out);
	  bh->bh_current_page = bh->bh_page;
	  bh->bh_position = 0;
	}
      else if (dtp == DV_STRING_SESSION)
	{
	  strses_write_out ((dk_session_t *) string, out);
	}
      else
	*err_ret = srv_make_new_error ("22023", "HT002",
	    "ses_write requires string, string_output or blob as argument 1");
    }
  FAILED
    {
      *err_ret = srv_make_new_error ("08003", "HT003", "cannot write to session");
    }
  END_WRITE_FAIL (out);
  session_flush (out);
endwrite:
  END_IO_SECT (err_ret);
  return NULL;

}

void
bif_pop3_init (void)
{
  bif_define_ex ("pop3_get", bif_pop3_get, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("ses_write", bif_ses_write, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
}

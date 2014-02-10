/*
 *  bif_smtp.c
 *
 *  $Id$
 *
 *  SMTP client function
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
#include "security.h"

#define RESP_OK '2' 		/*2xx ok response */
#define RESP_OK_MID '3'		/*3xx intermediary ok response */

#define IS_OK_GO(ses, resp, rc, rt)  CATCH_READ_FAIL (ses) \
			               { \
            				 rc = dks_read_line (ses, resp, sizeof (resp)); \
				         if (!is_smtp_ok (resp, rt)) \
				           goto error_end; \
				       } \
				     FAILED \
				       { \
				         goto error_end; \
				       } \
				     END_READ_FAIL (ses);

#define WRITE_CMD(ses, rc, cmd)	CATCH_WRITE_FAIL (ses) \
	                          { \
				     rc = session_buffered_write (ses, cmd, strlen (cmd)); \
				     session_flush_1 (ses); \
				  } \
				FAILED \
				  { \
				    goto error_end; \
				  } \
				END_WRITE_FAIL (ses);

caddr_t get_message_header_field (char *szMessage, long message_size, caddr_t szHeaderFld);

int
is_smtp_ok (char * resp, char c)
{
  if (strlen (resp) < 2)
    return 0;
  else if (resp [0] == c)
    return 1;
  return 0;
}

dk_session_t *
smtp_connect (char * host1, caddr_t * err_ret, caddr_t sender, caddr_t recipient, caddr_t msg_body)
{
  volatile int rc, inx, len, addr, at;
  dk_session_t * volatile ses = dk_session_allocate (SESCLASS_TCPIP);
  caddr_t cmd = NULL;
  char resp [1024];
  char tmp [1024], *ptmp;
  char c;
  caddr_t volatile hf = NULL, host;

  if (!strchr (host1, ':'))
    {
      host = dk_alloc_box (strlen (host1) + 4, DV_SHORT_STRING);
      strcpy_box_ck (host, host1);
      strcat_box_ck (host, ":25");
    }
  else
    {
      host = box_dv_short_string (host1);
    }

  rc = session_set_address (ses->dks_session, host);
  dk_free_box (host); host = NULL;

  if (SER_SUCC != rc)
    {
      PrpcSessionFree (ses);
      *err_ret = srv_make_new_error ("2E000", "SM002", "Cannot resolve host in smtp_send");
      return NULL;
    }
  rc = session_connect (ses->dks_session);
  if (SER_SUCC != rc)
    {
      if (rc != SER_NOREC)
	session_disconnect (ses->dks_session);
      PrpcSessionFree (ses);
      *err_ret = srv_make_new_error ("08001", "SM003", "Cannot connect in smtp_send");
      return NULL;
    }


  cmd = dk_alloc_box (MAX (MAX (box_length(sender), box_length(recipient)), 1000) + 24, DV_LONG_STRING);

  /* get initial line */
  IS_OK_GO (ses, resp, rc, RESP_OK)
  /* send HELO */
  if (gethostname (tmp, sizeof (tmp)))
    strcpy_ck (tmp, "localhost");
  snprintf (cmd, box_length (cmd), "HELO %s\r\n", tmp);
  /*WRITE_CMD (ses, rc, "HELO virtuoso.mail\r\n");*/
  WRITE_CMD (ses, rc, cmd);
  IS_OK_GO (ses, resp, rc, RESP_OK)

  /* send SENDER */
  len = box_length (sender);
  ptmp = tmp;
  addr = -1;
  at = 0;
  for (inx = 0; inx < len; inx++)
    {
      c = sender [inx];
      if (c == '<')
	addr = 1;
      else if (c == '>' && addr == 1)
	addr = 2;
      else if (c == '>' && addr == -1)
	{
	  strcpy_ck (resp, "Unbalanced <...> in sender e-mail address.");
	  goto error_end;
	}
      else if (c == '@')
	at = 1;
      if (((ptmp - tmp) < sizeof(tmp)) && (addr == 1 || addr == 2))
	*ptmp++ = c;
      else if ((ptmp - tmp) >= sizeof(tmp))
	{
	  strcpy_ck (resp, "Sender\'s e-mail address is too long.");
	  goto error_end;
	}

      if (addr == 2)
	{
	  *ptmp = 0;
	  snprintf (cmd, box_length (cmd), "MAIL FROM: %s\r\n", tmp);
	  WRITE_CMD (ses, rc, cmd);
	  IS_OK_GO (ses, resp, rc, RESP_OK)
	  break;
	}
    }
  if ((at == 0 && addr == -1) || addr == 1)
    { /*No any sender specified*/
      strcpy_ck (resp, "Bad sender e-mail address specified");
      goto error_end;
    }
  else if (at == 1 && addr == -1)
    {
      snprintf (cmd, box_length(cmd), "MAIL FROM: <%s>\r\n", sender);
      WRITE_CMD (ses, rc, cmd);
      IS_OK_GO (ses, resp, rc, RESP_OK)
    }

  /* send RECIPIENTS */
  len = box_length (recipient);
  ptmp = tmp;
  addr = -1;
  at = 0;
  for (inx = 0; inx < len; inx++)
    {
      c = recipient [inx];
      if (c == '<')
	addr = 1;
      else if (c == '>' && addr == 1)
	addr = 2;
      else if (c == '>' && (addr == -1 || addr == 0))
	{
	  strcpy_ck (resp, "Unbalanced <...> in recipient(s) e-mail address.");
	  goto error_end;
	}
      else if (c == '@')
	at = 1;
      if (((ptmp - tmp) < sizeof(tmp)) && (addr == 1 || addr == 2))
	*ptmp++ = c;
      else if ((ptmp - tmp) >= sizeof(tmp))
	{
	  strcpy_ck (resp, "Recipient\'s e-mail address is too long.");
	  goto error_end;
	}

      if (addr == 2)
	{
	  *ptmp = 0;
	  snprintf (cmd, box_length (cmd), "RCPT TO: %s\r\n", tmp);
          WRITE_CMD (ses, rc, cmd);
	  IS_OK_GO (ses, resp, rc, RESP_OK)
	  addr = 0;
	  ptmp = tmp;
	}
    }
  if ((at == 0 && addr == -1) || addr == 1)
    { /*No any recipient specified*/
      strcpy_ck (resp, "Bad recipient(s) e-mail address specified");
      goto error_end;
    }
  else if (at == 1 && addr == -1)
    {
      snprintf (cmd, box_length (cmd), "RCPT TO: <%s>\r\n", recipient);
      WRITE_CMD (ses, rc, cmd);
      IS_OK_GO (ses, resp, rc, RESP_OK)
    }

  /* send DATA command and message body */
  WRITE_CMD (ses, rc, "DATA\r\n");
  IS_OK_GO (ses, resp, rc, RESP_OK_MID)
  CATCH_WRITE_FAIL (ses)
    {
      hf = get_message_header_field (msg_body, box_length (msg_body) - 1, "From");
      if (hf[0] == 0)
	{
	  snprintf (cmd, box_length (cmd), "From: %s\r\n", sender);
	  rc = session_buffered_write (ses, cmd, strlen (cmd));
	  session_flush_1 (ses);
	}
      dk_free_box (hf); hf = NULL;
      hf = get_message_header_field (msg_body, box_length (msg_body) - 1, "To");
      if (hf[0] == 0)
	{
	  snprintf (cmd, box_length (cmd), "To: %s\r\n", recipient);
	  rc = session_buffered_write (ses, cmd, strlen (cmd));
	  session_flush_1 (ses);
	}
      dk_free_box (hf); hf = NULL;
      rc = session_buffered_write (ses, msg_body, box_length (msg_body) - 1);
      session_flush_1 (ses);
      /* end of message body */
      rc = session_buffered_write (ses, "\r\n.\r\n", 5);
      session_flush_1 (ses);
    }
  FAILED
    {
      dk_free_box (hf);
      strcpy_ck (resp, "Cannot send message body. Disconnect from the target mail server.");
      goto error_end;
    }
  END_WRITE_FAIL (ses);
  IS_OK_GO (ses, resp, rc, RESP_OK)
  /* EXIT from mail server */
  WRITE_CMD (ses, rc, "QUIT\r\n");
  IS_OK_GO (ses, resp, rc, RESP_OK)
  dk_free_box (cmd);

  return ses;
error_end:
  dk_free_box (cmd);
  session_disconnect (ses->dks_session);
  PrpcSessionFree (ses);
  *err_ret = srv_make_new_error ("08006", "SM001", "%s", resp);
  return NULL;
}

caddr_t
bif_smtp_send (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t mailer = bif_string_or_null_arg (qst, args, 0, "smtp_send");
  caddr_t err = NULL;
  dk_session_t * volatile ses = NULL;
  caddr_t sender = NULL;
  caddr_t recipient = NULL;
  caddr_t msg_body = NULL;
  IO_SECT(qst);

  sender = bif_string_arg (qst, args, 1, "smtp_send");
  recipient = bif_string_arg (qst, args, 2, "smtp_send");
  msg_body = bif_string_arg (qst, args, 3, "smtp_send");

  if (!mailer)
    mailer = default_mail_server;
  if (!mailer)
    sqlr_new_error ("22023", "SM004", "Default mail server and/or destination server should be specified");

  ses = smtp_connect (mailer, &err, sender, recipient, msg_body);

  if (err)
    sqlr_resignal (err);
  if (!ses)
    sqlr_new_error ("08006", "SM005", "Misc. error while connecting in smtp_send");
  session_disconnect (ses->dks_session);
  PrpcSessionFree (ses);
  END_IO_SECT (err_ret);
  return NULL;
}


static int
type_connection_destroy (caddr_t box)
{
  caddr_t *type = (caddr_t *)box;
  dk_session_t * ses;
  ptrlong to_close = 1;

  if (!IS_BOX_POINTER(type))
    return -1;

  ses = (dk_session_t *) type[0];

  if (BOX_ELEMENTS (type) > 1)
    to_close = (ptrlong) type[1];

  if (ses && to_close)
    {
      PrpcDisconnect (ses);
      PrpcSessionFree (ses);
    }
  if (BOX_ELEMENTS (type) > 2)
    dk_free_tree (type[2]);
  return 0;
}

caddr_t
bif_ses_connect (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  volatile dk_session_t * ses = NULL;
  caddr_t host = bif_string_arg (qst, args, 0, "ses_connect");
  long cert = BOX_ELEMENTS (args) > 1 ? bif_long_arg (qst, args, 1, "ses_connect") : 0;
  long id = BOX_ELEMENTS (args) > 2 ? bif_long_arg (qst, args, 2, "ses_connect") : 0;
  caddr_t *res, err = NULL;
#ifdef _SSL
  SSL *ssl;
  SSL_CTX *ssl_ctx = NULL;
  SSL_METHOD *ssl_method;
#endif

  IO_SECT(qst);
  sec_check_dba ((query_instance_t *) qst, "ses_connect");
  ses = http_dks_connect (host, &err);
#ifdef _SSL
  if (cert && ses)
    {
      int ssl_err = 0;
      int fd = tcpses_get_fd (ses->dks_session);
      char err_text[512], err_code[6];
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
	  *err_ret = srv_make_new_error (err_code, "CONNX", "%s", err_text);
	}
      else
	tcpses_to_sslses (ses->dks_session, ssl);
    }
#endif
  END_IO_SECT (err_ret);
  if (err)
    {
      if (err_ret && *err_ret)
	{
	  dk_free_tree (*err_ret);
	  *err_ret = NULL;
	}
      sqlr_resignal (err);
    }
  if (!id)
    {
  res = (caddr_t *) dk_alloc_box (sizeof (caddr_t), DV_CONNECTION);
  res[0] = (caddr_t) ses;
    }
  else
    {
      res = (caddr_t *) dk_alloc_box (3 * sizeof (caddr_t), DV_CONNECTION);
      res[0] = (caddr_t) ses;
      res[1] = (caddr_t) 1L;
      res[2] = box_num (id);
    }
  if (*err_ret)
    {
      dk_free_tree (res);
      res = NULL;
    }
  return (caddr_t)res;
}


void
ses_ready (dk_session_t * accept)
{
}


dk_session_t *
ses_listen (char * host)
{
  dk_session_t *listening = NULL;
  int rc = 0;

  listening = dk_session_allocate (SESCLASS_TCPIP);

  SESSION_SCH_DATA (listening)->sio_default_read_ready_action
      = (io_action_func) ses_ready;

  if (SER_SUCC != session_set_address (listening->dks_session, host))
    goto err_exit;

  rc = session_listen (listening->dks_session);

  if (!SESSTAT_ISSET (listening->dks_session, SST_LISTENING))
    {
      goto err_exit;
    };
  return listening;

err_exit:
  PrpcSessionFree (listening);
  return NULL;
}


caddr_t
bif_ses_accept (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int rc;
  dk_session_t * new_ses = NULL;
  dk_session_t * ses = http_session_arg (qst, args, 0, "ses_accept");
  caddr_t *res;

  new_ses = dk_session_allocate (SESCLASS_TCPIP);
  IO_SECT (qst);
  rc = session_accept (ses->dks_session, new_ses->dks_session);
  END_IO_SECT (err_ret);
  res = (caddr_t *) dk_alloc_box (sizeof (caddr_t), DV_CONNECTION);
  res[0] = (caddr_t) new_ses;
  if (*err_ret)
    {
      dk_free_tree (res);
      res = NULL;
    }
  return (caddr_t)res;
}

dk_session_t *http_listen (char * host, caddr_t * https_opts);

caddr_t
bif_ses_listen (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  volatile dk_session_t * ses = NULL;
  caddr_t port = bif_string_arg (qst, args, 0, "ses_listen");
  caddr_t *res;
  sec_check_dba ((query_instance_t *) qst, "ses_listen");
  IO_SECT (qst);
  ses = ses_listen (port);
  END_IO_SECT (err_ret);

  if (!ses || *err_ret)
    return NULL;

  res = (caddr_t *) dk_alloc_box (sizeof (caddr_t), DV_CONNECTION);
  res[0] = (caddr_t) ses;
  return (caddr_t)res;
}

caddr_t
bif_ses_disconnect (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_session_t * ses;
  caddr_t *ses_arg = (caddr_t *)bif_arg (qst, args, 0, "ses_disconnect");
  if (DV_TYPE_OF (ses_arg) != DV_CONNECTION)
    sqlr_new_error ("22023", "SSSSS", "The argument of ses_disconnect must be an valid session");
  ses = (dk_session_t *) ses_arg [0];
  IO_SECT (qst);
  PrpcDisconnect (ses);
  PrpcSessionFree (ses);
  END_IO_SECT (err_ret);
  ses_arg [0] = NULL;
  return box_num(0);
}

void
bif_smtp_init (void)
{
  dk_mem_hooks (DV_CONNECTION, box_non_copiable, type_connection_destroy, 0);
  bif_define_ex ("smtp_send", bif_smtp_send, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define ("ses_connect", bif_ses_connect);
  bif_define ("ses_accept", bif_ses_accept);
  bif_define ("ses_listen", bif_ses_listen);
  bif_define ("ses_disconnect", bif_ses_disconnect);
}


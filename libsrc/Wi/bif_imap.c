/*
 *  bif_imap.c
 *
 *  $Id$
 *
 *  IMAP4 client function
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

#include "Dk.h"
#include "sqlnode.h"
#include "http.h"
#include "multibyte.h"
#include "srvmultibyte.h"
#include "sqlbif.h"
#include "libutil.h"
#include <stddef.h>
#include "xml.h"

#define IS_OK_NEXT(ses, resp, rc, err_c, err_t, need_logout)  \
	CATCH_READ_FAIL (ses) \
	  { \
	    resp[0] = 0; \
	    rc = dks_read_line (ses, resp, sizeof (resp)); \
	    if (is_ok (resp)) \
		{ \
			strncpy (err_text, err_t, sizeof(err_text)); \
			strncpy (err_code, err_c, sizeof(err_code)); \
			if (need_logout) \
				goto logout; \
			else \
	      goto error_end; \
	  } \
	  } \
	FAILED \
	  { \
	    goto error_end; \
	  } \
	END_READ_FAIL (ses)

#define SEND(ses, rc, cmd, var)	\
	CATCH_WRITE_FAIL (ses) \
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

#define SENDP(ses, buf)	\
	CATCH_WRITE_FAIL (ses) \
	  { \
	  SES_PRINT (ses, buf); \
	  SES_PRINT (ses, "\r\n"); \
	  session_flush_1 (ses);\
	  } \
	  FAILED \
	  { \
	  goto error_end; \
	  } \
	  END_WRITE_FAIL (ses)

dk_session_t * strses_subseq (dk_session_t *ses, long from, long to);

static int
is_ok (char *resp)
{
  if (strlen (resp) > 2 && !strncmp ("OK", resp + 2, 2))
    return 0;
  if (strlen (resp) > 2 && !strncmp ("NO", resp + 2, 2))
    return 1;
  if (strlen (resp) > 2 && !strncmp ("BAD", resp + 2, 3))
    return 1;
  if (strlen (resp) > 2 && !strncmp ("CAPABILITY", resp + 2, 10))
    return 0;
  if (strlen (resp) > 2 && !strncmp ("BYE", resp + 2, 3))
    return 0;
  if (strlen (resp) > 2 && !strncmp ("LIST", resp + 2, 4))
    return 0;
	if (strlen (resp) > 2 && !strncmp ("LSUB", resp + 2, 4))
		return 0;
  if (strlen (resp) > 2 && !strncmp ("SELECT", resp + 2, 6))
    return 0;
  if (strlen (resp) > 2 && !strncmp ("FETCH", resp + 2, 5))
    return 0;
	if (strlen (resp) > 2 && !strncmp ("STATUS", resp + 2, 6))
		return 0;
  if (strlen (resp) > 2 && !strncmp ("RENAME", resp + 2, 6))
    return 0;
  if (strlen (resp) > 2 && !strncmp ("DELETE", resp + 2, 6))
    return 0;
  if (strlen (resp) > 2 && !strncmp ("CREATE", resp + 2, 6))
    return 0;
  if (strlen (resp) > 2 && !strncmp ("STORE", resp + 2, 5))
    return 0;
  if (strlen (resp) > 2 && !strncmp ("COPY", resp + 2, 4))
    return 0;
  if (strlen (resp) > 2 && !strncmp ("EXPUNGE", resp + 2, 7))
    return 0;
  return 0;
}

void
imap_quote_string (char *dest, size_t dlen, const char *src)
{
  char quote[] = "\"\\", *pt;
  const char *s;

  pt = dest;
  s = src;

  *pt++ = '"';
  /* save room for trailing quote-char */
  dlen -= 2;

  for (; *s && dlen; s++)
    {
      if (strchr (quote, *s))
	{
	  dlen -= 2;
	  if (!dlen)
	    break;
	  *pt++ = '\\';
	  *pt++ = *s;
	}
      else
	{
	  *pt++ = *s;
	  dlen--;
	}
    }
  *pt++ = '"';
  *pt = 0;
}

#define ISSPACE(c) isspace((unsigned char)c)
#define SKIPWS(c) while (*(c) && isspace ((unsigned char) *(c))) c++;

/* imap_next_word: return index into string where next IMAP word begins */
char *
imap_next_word (char *s)
{
  char *p;
  int quoted = 0;
  p = s;

  while (*p)
    {
      if (*p == '\\')
	{
	  p++;
	  if (*p)
	    p++;
	  continue;
	}
      if (*p == '\"')
	quoted = quoted ? 0 : 1;
      if (!quoted && ISSPACE (*p))
	break;
      p++;
    }

  SKIPWS (p);
  return p;
}

int
ascii_isupper (int c)
{
  return (c >= 'A') && (c <= 'Z');
}

int
ascii_islower (int c)
{
  return (c >= 'a') && (c <= 'z');
}

int
ascii_toupper (int c)
{
  if (ascii_islower (c))
    return c & ~32;

  return c;
}

int
ascii_tolower (int c)
{
  if (ascii_isupper (c))
    return c | 32;

  return c;
}

int
ascii_strncasecmp (const char *a, const char *b, int n)
{
  int i, j;

  if (a == b)
    return 0;
  if (a == NULL && b)
    return -1;
  if (b == NULL && a)
    return 1;

  for (j = 0; (*a || *b) && j < n; a++, b++, j++)
    {
      if ((i = ascii_tolower (*a) - ascii_tolower (*b)))
	return i;
    }

  return 0;
}

#define INIT_RESP \
	snprintf (msg_ok, sizeof (msg_ok), "%ld OK", id); \
	snprintf (msg_bad, sizeof (msg_ok), "%ld BAD", id); \
	snprintf (msg_no, sizeof (msg_ok), "%ld NO", id); \
	id ++

static void
imap_get (char *host, caddr_t * err_ret, caddr_t user, caddr_t pass,
	caddr_t mode, dk_set_t * ret_v, caddr_t folder_id, caddr_t * in, caddr_t * qst, long cert,
	ccaddr_t fetch_flags, dk_session_t * conn, long * pid)
{
	int rc, single_command;
  volatile int inx_mails;
  unsigned int uid, message_begin;
  volatile long size;
	long id = pid ? *pid : 1;
	dk_session_t *ses = NULL;
  char resp[1024];
	char message[128], err_text[512], err_code[6], buf[512], username[512], password[512];
  char *s, *ps;
  caddr_t target_folder_id = NULL;
  dk_session_t *msg = NULL;
  dk_session_t *msg2 = NULL;
	char msg_ok[64], msg_bad[64], msg_no[64];
#ifdef _SSL
  SSL *ssl;
  SSL_CTX *ssl_ctx = NULL;
  SSL_METHOD *ssl_method;
#endif
  resp[0] = 0;
  err_code[0] = 0;
	if (conn)
	{
		ses = conn;
		single_command = 0;
		goto command_start;
	}
	ses = dk_session_allocate (SESCLASS_TCPIP);
	single_command = 1;
  if (!_thread_sched_preempt)
    {
      ses->dks_read_block_timeout = dks_fibers_blocking_read_default_to;
    }
  rc = session_set_address (ses->dks_session, host);
  if (SER_SUCC != rc)
    {
      PrpcSessionFree (ses);
      *err_ret = srv_make_new_error ("2E000", "IM001", "Cannot resolve host in imap_get");
      return;
    }
  rc = session_connect (ses->dks_session);
  if (SER_SUCC != rc)
    {
      if (rc != SER_NOREC)
	session_disconnect (ses->dks_session);
      PrpcSessionFree (ses);
      *err_ret = srv_make_new_error ("08001", "IM002", "Cannot connect in imap_get");
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

	/* send AUTHORIZATION, when no session */

  IS_OK_NEXT (ses, resp, rc, "IM003", "No response from remote IMAP server", 0);

  imap_quote_string (username, sizeof (username), user);
  imap_quote_string (password, sizeof (password), pass);

	snprintf (buf, sizeof (buf), "%ld LOGIN %s %s", id++, username, password);
	SENDP (ses, buf);
  IS_OK_NEXT (ses, resp, rc, "IM004", "Could not login to remote IMAP server. Please check user or password parameters.", 0);

  inx_mails = 0;
  size = 0;

  /* get LIST of message and set size */
	snprintf (buf, sizeof (buf), "%ld CAPABILITY", id);
	SENDP (ses, buf);
	snprintf (buf, sizeof (buf), "%ld OK", id++);
  while (1)
    {
      IS_OK_NEXT (ses, resp, rc, "IM005", "CAPABILITY command to remote IMAP server failed", 1);
		if (strlen (resp) > 2 && !strncmp (buf, resp, 4))
	break;
    }

command_start:
	msg = strses_allocate ();
	msg2 = strses_allocate ();
  /* list of folders in folder or in root */
	if (!stricmp ("list", mode) || !stricmp ("lsub", mode))
    {
		strcpy_ck (buf, mode);
		sqlp_upcase (buf);
      if (folder_id && strlen (folder_id) > 0)
			snprintf (message, sizeof (message), "%ld %s \"\" \"%s\"", id, buf, folder_id);
      else
			snprintf (message, sizeof (message), "%ld %s \"\" \"%%\"", id, buf);
		SENDP (ses, message);
		INIT_RESP;
      message_begin = 0;
      strses_flush (msg);
      strses_enable_paging (msg, http_ses_size);
      CATCH_READ_FAIL (ses)
	{
	  rc = dks_read_line (ses, resp, sizeof (resp));
			while (strlen (resp) > 2 && strncmp (msg_ok, resp, strlen (msg_ok)))
	    {
	      ps = resp;
	      ps = imap_next_word (ps);
				if (!ascii_strncasecmp ("LIST", ps, 4) || !ascii_strncasecmp ("LSUB", ps, 4))
		ps = imap_next_word (ps);
	      else
		{
		  strcpy_ck (err_text, "Some error in the list of folders");
		  strcpy_ck (err_code, "IM006");
		  SESSION_SCH_DATA (ses)->sio_read_fail_on = 0;
		  goto logout;
		}
	      dk_set_push (ret_v, box_dv_short_string (ps));
	      rc = dks_read_line (ses, resp, sizeof (resp));
	    }
	}
      FAILED
	{
	  strcpy_ck (err_code, "IM010");
	  strcpy_ck (err_text, "Failed reading output of LIST command on remote IMAP server");
	  goto error_end;
	}
      END_READ_FAIL (ses);
      goto logout;
    }

  /* delete folder */
  if (!stricmp ("delete", mode))
    {
      if (folder_id && strlen (folder_id) > 0)
			snprintf (message, sizeof (message), "%ld DELETE \"%s\"", id, folder_id);
      else
	{
	  strcpy_ck (err_code, "IM011");
			strcpy_ck (err_text, "There must be folder name to delete (5th argument)");
	  goto logout;
	}
		SENDP (ses, message);
		INIT_RESP;
      while (1)
	{
	  IS_OK_NEXT (ses, resp, rc, "IM012", "DELETE command to remote IMAP server failed", 1);
			if (strlen (resp) > 2 && !strncmp (msg_ok, resp, strlen (msg_ok)))
	    break;
			if (strlen (resp) > 2 && !strncmp (msg_bad, resp, strlen (msg_bad)))
	    {
	      strcpy_ck (err_code, "IM013");
	      strcpy_ck (err_text, "Error during deletion");
	      break;
	    }
			if (strlen (resp) > 2 && !strncmp (msg_no, resp, strlen (msg_no)))
	    {
	      strcpy_ck (err_code, "IM014");
	      strcpy_ck (err_text, "Folder does not exist");
	      break;
	    }
	}
      goto logout;
    }

	if (!stricmp ("create", mode) || !stricmp ("subscribe", mode) || !stricmp ("unsubscribe", mode))
    {
		strcpy_ck (buf, mode);
		sqlp_upcase (buf);
      if (folder_id && strlen (folder_id) > 0)
			snprintf (message, sizeof (message), "%ld %s \"%s\"", id, buf, folder_id);
      else
	{
	  strcpy_ck (err_code, "IM015");
			strcpy_ck (err_text, "There must be folder name (5th argument)");
	  goto logout;
	}
		SENDP (ses, message);
		INIT_RESP;
      while (1)
	{
			IS_OK_NEXT (ses, resp, rc, "IM016", "command to remote IMAP server failed", 1);
			if (strlen (resp) > 2 && !strncmp (msg_ok, resp, strlen (msg_ok)))
	    break;
			if (strlen (resp) > 2 && !strncmp (msg_bad, resp, strlen (msg_bad)))
	    {
	      strcpy_ck (err_code, "IM017");
				strcpy_ck (err_text, "Unknown Error");
	      break;
	    }
			if (strlen (resp) > 2 && !strncmp (msg_no, resp, strlen (msg_no)))
	    {
	      strcpy_ck (err_code, "IM018");
	      strcpy_ck (err_text, "Folder does not exist");
	      break;
	    }
	}
      goto logout;
    }

  /* list all messages' headers from selected folder */
  if (!stricmp ("select", mode) || !stricmp ("expunge", mode))
    {
      if (folder_id && strlen (folder_id) > 0)
			snprintf (message, sizeof (message), "%ld SELECT \"%s\"", id, folder_id);
      else
			snprintf (message, sizeof (message), "%ld SELECT \"INBOX\"", id);
		SENDP (ses, message);
		INIT_RESP;
      while (1)
	{
	  IS_OK_NEXT (ses, resp, rc, "IM019", "SELECT command to remote IMAP server failed", 1);
	  ps = resp;
	  s = imap_next_word (ps);
	  ps = imap_next_word (s);
	  if (ascii_strncasecmp ("EXISTS", ps, 6) == 0)
	    inx_mails = atoi (s);
			if (strlen (resp) > 2 && !strncmp (msg_ok, resp, strlen (msg_ok)))
	    break;
	}
      if (!stricmp ("expunge", mode))
	{
			snprintf (message, sizeof (message), "%ld EXPUNGE", id);
			SENDP (ses, message);
			INIT_RESP;
	  while (1)
	    {
	      IS_OK_NEXT (ses, resp, rc, "IM020", "EXPUNGE command to remote IMAP server failed", 1);
				if (strlen (resp) > 2 && !strncmp (msg_ok, resp, strlen (msg_ok)))
		break;
				if (strlen (resp) > 2 && !strncmp (msg_bad, resp, strlen (msg_bad)))
		{
		  strcpy_ck (err_code, "IM021");
		  strcpy_ck (err_text, "Error during deletion");
		  break;
		}
				if (strlen (resp) > 2 && !strncmp (msg_no, resp, strlen (msg_no)))
		{
		  strcpy_ck (err_code, "IM022");
		  strcpy_ck (err_text, "Folder does not exist");
		  break;
		}
	    }
	  goto logout;
	}
      if (inx_mails > 0)
	{
			snprintf (message, sizeof (message), "%ld FETCH 1:* (UID FLAGS INTERNALDATE)", id);
			SENDP (ses, message);
			INIT_RESP;
	  while (1)
	    {
	      message_begin = 0;
	      strses_flush (msg2);
	      strses_enable_paging (msg2, http_ses_size);
	      CATCH_READ_FAIL (ses)
		{
		  rc = dks_read_line (ses, resp, sizeof (resp));
					if (strlen (resp) > 2 && !strncmp (msg_ok, resp, strlen (msg_ok)))
		    break;
		      ps = resp;
			  ps = imap_next_word (ps);
			  ps = imap_next_word (ps);
			  if (!ascii_strncasecmp ("FETCH", ps, 5))
			    {
			      ps = imap_next_word (ps);
			      if (ps[0] == '(')
				ps++;
			      if (ascii_strncasecmp ("UID", ps, 3) == 0)
				{
				  ps = imap_next_word (ps);
				  uid = atoi (ps);
				  ps = imap_next_word (ps);
				  SES_PRINT (msg2, ps);
				  if (tcpses_check_disk_error (msg2, qst, 0))
				    {
				      strcpy_ck (err_text, "Server error in accessing temp file");
				      strcpy_ck (err_code, "IM024");
				      SESSION_SCH_DATA (ses)->sio_read_fail_on = 0;
				      goto logout;
				    }
				}
			    }
			  else
			    {
			      strcpy_ck (err_text, "Some error");
			      strcpy_ck (err_code, "IM023");
			      SESSION_SCH_DATA (ses)->sio_read_fail_on = 0;
			      goto logout;
			    }
		  session_flush_1 (msg2);
					if (tcpses_check_disk_error (msg2, NULL, 0))
		    {
		      strcpy_ck (err_text, "Server error in accessing temp file");
		      strcpy_ck (err_code, "IM025");
		      SESSION_SCH_DATA (ses)->sio_read_fail_on = 0;
		      goto logout;
		    }
					if (strses_length(msg2) > 3)
		    {
						dk_session_t * out;
						out = strses_subseq (msg2, 0, strses_length (msg2) - 3);
						dk_free_box (msg2);
						msg2 = out;
		  }
					if (!STRSES_CAN_BE_STRING (msg2))
					{
						dk_set_push (ret_v, list (2, box_num (uid), msg2));
						msg2 = strses_allocate ();
		    }
					else
					dk_set_push (ret_v, list (2, box_num (uid), strses_string (msg2)));
		}
	      FAILED
		{
		  strcpy_ck (err_code, "IM027");
		  strcpy_ck (err_text, "Failed reading output of FETCH command on remote IMAP server");
		  goto error_end;
		}
	      END_READ_FAIL (ses);
	    }
	}
      goto logout;
    }
	/* status */
	/* list all messages' headers from selected folder */
	if (!stricmp ("status", mode))
	{
		if (folder_id && strlen (folder_id) > 0)
			snprintf (message, sizeof (message), "%ld STATUS \"%s\" (UIDVALIDITY UIDNEXT MESSAGES)", id, folder_id);
		else
			snprintf (message, sizeof (message), "%ld STATUS \"INBOX\" (UIDVALIDITY UIDNEXT MESSAGES)", id);
		SENDP (ses, message);
		INIT_RESP;
		message_begin = 0;
		strses_flush (msg);
		strses_enable_paging (msg, http_ses_size);
		CATCH_READ_FAIL (ses)
		{
			rc = dks_read_line (ses, resp, sizeof (resp));
			while (strlen (resp) > 2 && strncmp (msg_ok, resp, strlen (msg_ok)))
			{
				ps = resp;
				ps = imap_next_word (ps);
				if (!ascii_strncasecmp ("STATUS", ps, 6))
					ps = imap_next_word (ps);
				else
				{
					strcpy_ck (err_text, "Some error in STATUS of folders");
					strcpy_ck (err_code, "IM028");
					SESSION_SCH_DATA (ses)->sio_read_fail_on = 0;
					goto logout;
				}
				dk_set_push (ret_v, box_dv_short_string (ps));
				rc = dks_read_line (ses, resp, sizeof (resp));
			}
		}
		FAILED
		{
			strcpy_ck (err_code, "IM029");
			strcpy_ck (err_text, "Failed reading output of STATUS command on remote IMAP server");
			goto error_end;
		}
		END_READ_FAIL (ses);
		goto logout;
	}
  /* rename folder */
  if (!stricmp ("rename", mode))
    {
      volatile int l;
      dtp_t type1, type2;
      if (in)
	l = BOX_ELEMENTS (in);
      if (l != 2)
	{
	  strcpy_ck (err_code, "IM028");
			strcpy_ck (err_text, "There must be 2 string items in vector of argument 6 (old folder name to rename and a new name)");
	  goto logout;
	}
      type1 = DV_TYPE_OF (in[0]);
      type2 = DV_TYPE_OF (in[1]);
      if (!IS_STRING_DTP (type1) || !IS_STRING_DTP (type2))
	{
	  strcpy_ck (err_code, "IM029");
			strcpy_ck (err_text, "There must be 2 string items in vector of argument 6 (old folder name to rename and a new name)");
	  goto logout;
	}
		snprintf (message, sizeof (message), "%ld RENAME \"%s\" \"%s\"", id, in[0], in[1]);
		SENDP (ses, message);
		INIT_RESP;
      while (1)
	{
	  IS_OK_NEXT (ses, resp, rc, "IM030", "RENAME command to remote IMAP server failed", 1);
			if (strlen (resp) > 2 && !strncmp (msg_ok, resp, strlen (msg_ok)))
	    break;
			if (strlen (resp) > 2 && (!strncmp (msg_bad, resp, strlen (msg_bad)) || !strncmp (msg_no, resp, strlen (msg_no))))
	    {
	      strcpy_ck (err_code, "IM031");
	      strcpy_ck (err_text, "Re-naming failed");
	      goto logout;
	      break;
	    }
	}
      goto logout;
    }
  /*  manipuation with select messages in selected folder */
	if (!stricmp ("fetch", mode) || !stricmp ("message_delete", mode) || !stricmp ("message_copy", mode) || !stricmp ("set_message_read", mode) || !stricmp ("set_message_unread", mode))
    {
      if (folder_id && strlen (folder_id) > 0)
			snprintf (message, sizeof (message), "%ld SELECT \"%s\"", id, folder_id);
      else
			snprintf (message, sizeof (message), "%ld SELECT INBOX", id);
		SENDP (ses, message);
		INIT_RESP;
      while (1)
	{
	  IS_OK_NEXT (ses, resp, rc, "IM032", "SELECT command to remote IMAP server failed", 1);
	  ps = resp;
	  s = imap_next_word (ps);
	  ps = imap_next_word (s);
	  if (ascii_strncasecmp ("EXISTS", ps, 6) == 0)
	    inx_mails = atoi (s);
			if (strlen (resp) > 2 && !strncmp (msg_ok, resp, strlen (msg_ok)))
	    break;
	}
      if (inx_mails > 0)
	{
	  volatile int l, br;
	  int do_not_read, start = 0;
	  dtp_t type;
	  if (in)
	    l = BOX_ELEMENTS (in);
	  if (l < 1)
	    {
	      strcpy_ck (err_text, "No messages in list");
	      strcpy_ck (err_code, "IM033");
	      SESSION_SCH_DATA (ses)->sio_read_fail_on = 0;
	      goto logout;
	    }
	  if (!stricmp ("message_copy", mode))
	    {
	      target_folder_id = in[0];
	      start = 1;
	    }
	  for (br = start; br < l; br++)
	    {
	      type = DV_TYPE_OF (in[br]);
	      if (!IS_INT_DTP (type))
		{
		  strcpy_ck (err_code, "IM034");
					strcpy_ck (err_text, "There must be integer items in vector of argument 6");
		  goto logout;
		}
				if (!stricmp ("fetch", mode) && fetch_flags)
					snprintf (message, sizeof (message), "%ld UID FETCH " BOXINT_FMT " %s", id, unbox (in[br]), fetch_flags);
				else if (!stricmp ("fetch", mode))
					snprintf (message, sizeof (message), "%ld UID FETCH " BOXINT_FMT " BODY.PEEK[]", id, unbox (in[br]));
				else if (!stricmp ("message_delete", mode))
					snprintf (message, sizeof (message), "%ld UID STORE " BOXINT_FMT " +FLAGS (\\Deleted)", id, unbox (in[br]));
				else if (!stricmp ("set_message_read", mode))
					snprintf (message, sizeof (message), "%ld UID STORE " BOXINT_FMT " +FLAGS (\\Seen)", id, unbox (in[br]));
				else if (!stricmp ("set_message_unread", mode))
					snprintf (message, sizeof (message), "%ld UID STORE " BOXINT_FMT " -FLAGS (\\Seen)", id, unbox (in[br]));
				else if (!stricmp ("message_copy", mode))
					snprintf (message, sizeof (message), "%ld UID COPY " BOXINT_FMT " \"%s\"", id, unbox (in[br]), target_folder_id);
				SENDP (ses, message);
				INIT_RESP;
	      do_not_read = 0;
	      while (1)
		{
		  message_begin = 0;
		  strses_flush (msg);
		  strses_enable_paging (msg, http_ses_size);
		  CATCH_READ_FAIL (ses)
		    {
		      if (!do_not_read)
			rc = dks_read_line (ses, resp, sizeof (resp));
						if (strlen (resp) > 2 && !strncmp (msg_ok, resp, strlen (msg_ok)))
			break;
						if (strlen (resp) > 2 && !strncmp (msg_bad, resp, strlen (msg_bad)))
			{
			  strcpy_ck (err_text, "Error in IMAP command UID STORE");
			  strcpy_ck (err_code, "IM035");
			  break;
			}
						if (strlen (resp) > 2 && !strncmp (msg_no, resp, strlen (msg_no)))
			{
			  strcpy_ck (err_text, "Error in IMAP command UID STORE");
			  strcpy_ck (err_code, "IM036");
			  break;
			}
						while (1) /* XXX: was resp, but it is always true */
			{
			  ps = resp;
			  if (!message_begin)
			    {
			      message_begin = 1;
			      if (!ascii_strncasecmp ("* ", ps, 2))
				{
				  ps = imap_next_word (ps);
				  ps = imap_next_word (ps);
				  if (!ascii_strncasecmp ("FETCH", ps, 5))
				    {
				      ps = imap_next_word (ps);
				      if (ps[0] == '(')
					ps++;
				      if (ascii_strncasecmp ("UID", ps, 3) == 0)
					{
					  ps = imap_next_word (ps);
					  uid = atoi (ps);
					}
				    }
				}
			      else
				{
				  strcpy_ck (err_text, "Some error");
				  strcpy_ck (err_code, "IM037");
				  SESSION_SCH_DATA (ses)->sio_read_fail_on = 0;
				  goto logout;
				}
								if (!stricmp ("message_delete", mode) || !stricmp ("message_copy", mode) || !stricmp ("set_message_read", mode) || !stricmp ("set_message_unread", mode))
				break;
			      goto next_message;
			    }
			  SES_PRINT (msg, ps);
			  if (tcpses_check_disk_error (msg, qst, 0))
			    {
			      strcpy_ck (err_text, "Server error in accessing temp file");
			      strcpy_ck (err_code, "IM038");
			      SESSION_SCH_DATA (ses)->sio_read_fail_on = 0;
			      goto logout;
			    }
			next_message:
			  rc = dks_read_line (ses, resp, sizeof (resp));
							if (strlen (resp) > 2 &&
								(!strncmp (msg_ok, resp, strlen (msg_ok)) ||
								!strncmp (msg_bad, resp, strlen (msg_bad)) ||
								!strncmp (msg_no, resp, strlen (msg_no))))
			    {
			      do_not_read = 1;
			      break;
			    }
			}
		      session_flush_1 (msg);
		      if (tcpses_check_disk_error (msg, NULL, 0))
			{
			  strcpy_ck (err_text, "Server error in accessing temp file");
			  strcpy_ck (err_code, "IM039");
			  SESSION_SCH_DATA (ses)->sio_read_fail_on = 0;
			  goto logout;
			}
						if (uid > 0)
			{
							if (strses_length(msg) > 3)
							{
								dk_session_t * out;
								out = strses_subseq (msg, 0, strses_length (msg) - 3);
								dk_free_box (msg);
								msg = out;
			}
		    if (!STRSES_CAN_BE_STRING (msg))
			{
								dk_set_push (ret_v, list (2, box_num (uid), msg));
								msg = strses_allocate ();
							}
							else
							dk_set_push (ret_v, list (2, box_num (uid), strses_string (msg)));
			}
		    }
		  FAILED
		    {
		      strcpy_ck (err_code, "IM041");
		      strcpy_ck (err_text, "Failed reading output of FETCH command on remote IMAP server");
		      goto error_end;
		    }
		  END_READ_FAIL (ses);
		}
	    }
	}
      goto logout;
    }
  else if (strlen (mode) > 0 && stricmp ("", mode))
    {
      strcpy_ck (err_code, "IM042");
      strcpy_ck (err_text, "No such command (5th parameter) in protocol");
      *err_ret = srv_make_new_error ("08006", err_code, "%s: %s", err_text, mode);
    }
logout:
	if (single_command)
	{
		/* QUIT from imap4 server */
		snprintf (message, sizeof (message), "%ld LOGOUT", id);
		SENDP (ses, message);
		INIT_RESP;
  while (1)
    {
      IS_OK_NEXT (ses, resp, rc, "IM043", "Could not LOGOUT from remote IMAP server", 0);
			if (strlen (resp) > 2 && !strncmp (msg_ok, resp, strlen (msg_ok)))
	break;
    }
	}
error_end:
	if (pid)
		*pid = id;
  if (err_code[0] != 0)
    *err_ret = srv_make_new_error ("08006", err_code, "%s", err_text);
  strses_free (msg);
  strses_free (msg2);
	if (single_command)
	{
  PrpcDisconnect (ses);
  PrpcSessionFree (ses);
  SSL_CTX_free (ssl_ctx);
	}
  return;
  /* *err_ret = srv_make_new_error ("08006", "IM044", "Misc. error in connection in imap_get"); */
}

caddr_t bif_session_arg (caddr_t * qst, state_slot_t ** args, int nth, char *func);

static caddr_t
	bif_imap_login (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
	char * me = "imap_login";
	caddr_t * conn = (caddr_t *) bif_session_arg (qst, args, 0, me);
	caddr_t user = bif_string_arg (qst, args, 1, me);
	caddr_t pass = bif_string_arg (qst, args, 2, me);
	int rc;
	long id;
	char resp[1024];
	char err_text[512], err_code[6], buf[512], username[512], password[512];
	dk_session_t * ses;

	if (DV_TYPE_OF (conn) != DV_CONNECTION || BOX_ELEMENTS (conn) < 3)
		sqlr_new_error ("22023", "IMAP1", "Invalid session argument");

	resp[0] = 0;
	err_code[0] = 0;
	ses = (dk_session_t *) (conn[0]);
	id = unbox (conn[2]);

	IS_OK_NEXT (ses, resp, rc, "IM003", "No response from remote IMAP server", 0);
	imap_quote_string (username, sizeof (username), user);
	imap_quote_string (password, sizeof (password), pass);
	snprintf (buf, sizeof (buf), "%ld LOGIN %s %s", id++, username, password);
	SENDP (ses, buf);
	IS_OK_NEXT (ses, resp, rc, "IM004", "Could not login to remote IMAP server. Please check user or password parameters.", 0);

	snprintf (buf, sizeof (buf), "%ld CAPABILITY", id);
	SENDP (ses, buf);
	snprintf (buf, sizeof (buf), "%ld OK", id++);
	for (;;)
	{
		IS_OK_NEXT (ses, resp, rc, "IM005", "CAPABILITY command to remote IMAP server failed", 1);
		if (strlen (resp) > 2 && !strncmp (buf, resp, strlen (buf)))
			break;
	}
logout:
error_end:
	if (err_code[0] != 0)
		*err_ret = srv_make_new_error ("08006", err_code, "%s", err_text);
	dk_free_box (conn[2]);
	conn[2] = box_num (id);
	return NEW_DB_NULL;
}

static caddr_t
	bif_imap_logout (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
	char * me = "imap_logout";
	caddr_t * conn = (caddr_t *) bif_session_arg (qst, args, 0, me);
	int rc;
	long id;
	char resp[1024];
	char err_text[512], err_code[6], buf[512];
	dk_session_t * ses;

	if (DV_TYPE_OF (conn) != DV_CONNECTION || BOX_ELEMENTS (conn) < 3)
		sqlr_new_error ("22023", "IMAP1", "Invalid session argument");

	resp[0] = 0;
	err_code[0] = 0;
	ses = (dk_session_t *) (conn[0]);
	id = unbox (conn[2]);

	snprintf (buf, sizeof (buf), "%ld LOGOUT", id);
	SENDP (ses, buf);
	snprintf (buf, sizeof (buf), "%ld OK", id++);
	while (1)
	{
		IS_OK_NEXT (ses, resp, rc, "IM043", "Could not LOGOUT from remote IMAP server", 0);
		if (strlen (resp) > 2 && !strncmp (buf, resp, strlen (buf)))
			break;
	}

logout:
error_end:
	if (err_code[0] != 0)
		*err_ret = srv_make_new_error ("08006", err_code, "%s", err_text);
	dk_free_box (conn[2]);
	conn[2] = box_num (id);
	return NEW_DB_NULL;
}

static caddr_t
	bif_imap_command (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
	char * me = "imap4_command";
	caddr_t *in_uidl = NULL;
	caddr_t folder_id = NULL;
	caddr_t * conn = (caddr_t *) bif_session_arg (qst, args, 0, me);
	caddr_t ret = NULL;
	caddr_t mode = "";
	caddr_t err = NULL, fetch_flags = NULL;
	long id;
	dk_set_t volatile uidl_mes = NULL;
	dk_session_t * ses;

	if (DV_TYPE_OF (conn) != DV_CONNECTION || BOX_ELEMENTS (conn) < 3)
		sqlr_new_error ("22023", "IMAP1", "Invalid session argument");

	ses = (dk_session_t *) (conn[0]);
	id = unbox (conn[2]);

	IO_SECT (qst);
	if (BOX_ELEMENTS (args) > 1)
		mode = bif_string_arg (qst, args, 1, me);

	if (BOX_ELEMENTS (args) > 2)
		folder_id = bif_string_arg (qst, args, 2, me);

	if (BOX_ELEMENTS (args) > 3)
	{
		in_uidl = (caddr_t *) bif_array_or_null_arg (qst, args, 3, me);
		if (in_uidl && DV_TYPE_OF (in_uidl) != DV_ARRAY_OF_POINTER)
			sqlr_new_error ("08000", "IM013", "Argument 6 to imap4_command must be a vector");
	}

	if (BOX_ELEMENTS (args) > 4)
		fetch_flags = bif_string_or_null_arg (qst, args, 4, me);

	imap_get (NULL, &err, NULL, NULL, mode, (dk_set_t *) & uidl_mes, folder_id, in_uidl, qst, 0, fetch_flags, ses, &id);

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
	dk_free_box (conn[2]);
	conn[2] = box_num (id);
	return ret;
}

static caddr_t
bif_imap_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *in_uidl = NULL;
  caddr_t folder_id = NULL;
  caddr_t addr = bif_string_arg (qst, args, 0, "imap_get");
  caddr_t user = bif_string_arg (qst, args, 1, "imap_get");
  caddr_t pass = bif_string_arg (qst, args, 2, "imap_get");
  caddr_t ret = NULL;
  caddr_t mode = "";
	caddr_t err = NULL, fetch_flags = NULL;
  long cert = 0;
  dk_set_t volatile uidl_mes = NULL;
  IO_SECT (qst);
	if (BOX_ELEMENTS (args) > 3)
		mode = bif_string_arg (qst, args, 3, "imap_get");
  if (BOX_ELEMENTS (args) > 4)
		folder_id = bif_string_arg (qst, args, 4, "imap_get");
  if (BOX_ELEMENTS (args) > 5)
    {
		in_uidl = (caddr_t *) bif_array_or_null_arg (qst, args, 5, "imap_get");
      if (in_uidl && DV_TYPE_OF (in_uidl) != DV_ARRAY_OF_POINTER)
			sqlr_new_error ("08000", "IM013", "Argument 6 to imap_get must be a vector");
    }
	if (BOX_ELEMENTS (args) > 6)
		cert = bif_long_arg (qst, args, 6, "imap_get");
  if (BOX_ELEMENTS (args) > 7)
		fetch_flags = bif_string_or_null_arg (qst, args, 7, "imap_get");
	imap_get (addr, &err, user, pass, mode, (dk_set_t *) & uidl_mes, folder_id, in_uidl, qst, cert, fetch_flags, NULL, NULL);
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

void
bif_imap_init (void)
{
  bif_define_ex ("imap_get", bif_imap_get, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("imap4_login", bif_imap_login, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("imap4_command", bif_imap_command, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("imap4_logout", bif_imap_logout, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
}

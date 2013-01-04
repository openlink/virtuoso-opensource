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
  if (strlen (resp) > 2 && !strncmp ("SELECT", resp + 2, 6))
    return 0;
  if (strlen (resp) > 2 && !strncmp ("FETCH", resp + 2, 5))
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

static void
imap_get (char *host, caddr_t * err_ret, caddr_t user, caddr_t pass,
    long end_size, caddr_t mode, dk_set_t * ret_v, caddr_t folder_id, caddr_t * in, caddr_t * qst, long cert)
{
  int rc;
  volatile int inx_mails;
  unsigned int uid, message_begin;
  volatile long size;
  dk_session_t *ses = dk_session_allocate (SESCLASS_TCPIP);
  char resp[1024];
  char message[128], err_text[512], err_code[6], login_message[512], username[512], password[512];
  char end_msg[1] = ")";
  char end_msg3[3] = ")\r\n";
  char *s, *ps;
  caddr_t target_folder_id = NULL;
  dk_session_t *msg = NULL;
  dk_session_t *msg2 = NULL;
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

  msg = strses_allocate ();
  msg2 = strses_allocate ();
  /* send AUTHORIZATION */

  IS_OK_NEXT (ses, resp, rc, "IM003", "No response from remote IMAP server", 0);

  imap_quote_string (username, sizeof (username), user);
  imap_quote_string (password, sizeof (password), pass);

  snprintf (login_message, sizeof (login_message), " %s %s", username, password);

  SEND (ses, rc, "1 LOGIN ", login_message);
  IS_OK_NEXT (ses, resp, rc, "IM004", "Could not login to remote IMAP server. Please check user or password parameters.", 0);

  inx_mails = 0;
  size = 0;

  /* get LIST of message and set size */
  SEND (ses, rc, "2 CAPABILITY", "");
  while (1)
    {
      IS_OK_NEXT (ses, resp, rc, "IM005", "CAPABILITY command to remote IMAP server failed", 1);
      if (strlen (resp) > 2 && !strncmp ("2 OK", resp, 4))
	break;
    }
  /* list of folders in folder or in root */
  if (!stricmp ("list", mode))
    {
      if (folder_id && strlen (folder_id) > 0)
	snprintf (message, sizeof (message), "3 LIST \"\" \"%s\"", folder_id);
      else
	snprintf (message, sizeof (message), "3 LIST \"\" \"%%\"");
      SEND (ses, rc, message, "");
      message_begin = 0;
      strses_flush (msg);
      strses_enable_paging (msg, http_ses_size);
      CATCH_READ_FAIL (ses)
	{
	  rc = dks_read_line (ses, resp, sizeof (resp));
	  while (strlen (resp) > 2 && strncmp ("3 OK", resp, 4))
	    {
	      ps = resp;
	      ps = imap_next_word (ps);
	      if (!ascii_strncasecmp ("LIST", ps, 4))
		ps = imap_next_word (ps);
	      else
		{
		  strcpy_ck (err_text, "Some error in the list of folders");
		  strcpy_ck (err_code, "IM006");
		  SESSION_SCH_DATA (ses)->sio_read_fail_on = 0;
		  goto logout;
		}
	      dk_set_push (ret_v, box_dv_short_string (ps));
	      if (tcpses_check_disk_error (msg, qst, 0))
		{
		  strcpy_ck (err_text, "Server error in accessing temp file");
		  strcpy_ck (err_code, "IM007");
		  SESSION_SCH_DATA (ses)->sio_read_fail_on = 0;
		  goto logout;
		}
	      rc = dks_read_line (ses, resp, sizeof (resp));
	    }
	  if (tcpses_check_disk_error (msg, NULL, 0))
	    {
	      strcpy_ck (err_text, "Server error in accessing temp file");
	      strcpy_ck (err_code, "IM008");
	      SESSION_SCH_DATA (ses)->sio_read_fail_on = 0;
	      goto logout;
	    }
	  if (!STRSES_CAN_BE_STRING (msg))
	    {
	      strcpy_ck (err_text, "Server error in storing data into a string session");
	      strcpy_ck (err_code, "IM009");
	      SESSION_SCH_DATA (ses)->sio_read_fail_on = 0;
	      goto logout;
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
	snprintf (message, sizeof (message), "3 DELETE \"%s\"", folder_id);
      else
	{
	  strcpy_ck (err_code, "IM011");
	  strcpy_ck (err_text, "There must be folder name to delete (6th argument)");
	  goto logout;
	}
      SEND (ses, rc, message, "");
      while (1)
	{
	  IS_OK_NEXT (ses, resp, rc, "IM012", "DELETE command to remote IMAP server failed", 1);
	  if (strlen (resp) > 2 && !strncmp ("3 OK", resp, 4))
	    break;
	  if (strlen (resp) > 2 && !strncmp ("3 BAD", resp, 5))
	    {
	      strcpy_ck (err_code, "IM013");
	      strcpy_ck (err_text, "Error during deletion");
	      break;
	    }
	  if (strlen (resp) > 2 && !strncmp ("3 NO", resp, 4))
	    {
	      strcpy_ck (err_code, "IM014");
	      strcpy_ck (err_text, "Folder does not exist");
	      break;
	    }
	}
      goto logout;
    }

  if (!stricmp ("create", mode))
    {
      if (folder_id && strlen (folder_id) > 0)
	snprintf (message, sizeof (message), "3 CREATE \"%s\"", folder_id);
      else
	{
	  strcpy_ck (err_code, "IM015");
	  strcpy_ck (err_text, "There must be folder name to create (6th argument)");
	  goto logout;
	}
      SEND (ses, rc, message, "");
      while (1)
	{
	  IS_OK_NEXT (ses, resp, rc, "IM016", "CREATE command to remote IMAP server failed", 1);
	  if (strlen (resp) > 2 && !strncmp ("3 OK", resp, 4))
	    break;
	  if (strlen (resp) > 2 && !strncmp ("3 BAD", resp, 5))
	    {
	      strcpy_ck (err_code, "IM017");
	      strcpy_ck (err_text, "Error during creation");
	      break;
	    }
	  if (strlen (resp) > 2 && !strncmp ("3 NO", resp, 4))
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
	snprintf (message, sizeof (message), "4 SELECT \"%s\"", folder_id);
      else
	snprintf (message, sizeof (message), "4 SELECT \"INBOX\"");
      SEND (ses, rc, message, "");
      while (1)
	{
	  IS_OK_NEXT (ses, resp, rc, "IM019", "SELECT command to remote IMAP server failed", 1);
	  ps = resp;
	  s = imap_next_word (ps);
	  ps = imap_next_word (s);
	  if (ascii_strncasecmp ("EXISTS", ps, 6) == 0)
	    inx_mails = atoi (s);
	  if (strlen (resp) > 2 && !strncmp ("4 OK", resp, 4))
	    break;
	}
      if (!stricmp ("expunge", mode))
	{
	  snprintf (message, sizeof (message), "5 EXPUNGE");
	  SEND (ses, rc, message, "");
	  while (1)
	    {
	      IS_OK_NEXT (ses, resp, rc, "IM020", "EXPUNGE command to remote IMAP server failed", 1);
	      if (strlen (resp) > 2 && !strncmp ("5 OK", resp, 4))
		break;
	      if (strlen (resp) > 2 && !strncmp ("5 BAD", resp, 5))
		{
		  strcpy_ck (err_code, "IM021");
		  strcpy_ck (err_text, "Error during deletion");
		  break;
		}
	      if (strlen (resp) > 2 && !strncmp ("5 NO", resp, 4))
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
	  SEND (ses, rc,
	      "5 FETCH 1:* (UID FLAGS INTERNALDATE RFC822.SIZE BODY.PEEK[HEADER.FIELDS (DATE FROM SUBJECT TO CC MESSAGE-ID REFERENCES CONTENT-TYPE CONTENT-DESCRIPTION IN-REPLY-TO REPLY-TO LINES LIST-POST X-LABEL)])",
	      "");
	  while (1)
	    {
	      message_begin = 0;
	      strses_flush (msg);
	      strses_enable_paging (msg, http_ses_size);
	      strses_flush (msg2);
	      strses_enable_paging (msg2, http_ses_size);
	      CATCH_READ_FAIL (ses)
		{
		  rc = dks_read_line (ses, resp, sizeof (resp));
		  if (strlen (resp) > 2 && !strncmp ("5 OK", resp, 4))
		    break;
		  while (strncmp (end_msg, resp, sizeof (end_msg)))
		    {
		      ps = resp;
		      if (!message_begin)
			{
			  message_begin = 1;
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
				  goto next_statement;
				}
			    }
			  else
			    {
			      strcpy_ck (err_text, "Some error");
			      strcpy_ck (err_code, "IM023");
			      SESSION_SCH_DATA (ses)->sio_read_fail_on = 0;
			      goto logout;
			    }
			}
		      SES_PRINT (msg, ps);
		      if (tcpses_check_disk_error (msg, qst, 0))
			{
			  strcpy_ck (err_text, "Server error in accessing temp file");
			  strcpy_ck (err_code, "IM024");
			  SESSION_SCH_DATA (ses)->sio_read_fail_on = 0;
			  goto logout;
			}
		    next_statement:
		      rc = dks_read_line (ses, resp, sizeof (resp));
		    }
		  session_flush_1 (msg);
		  session_flush_1 (msg2);
		  if (tcpses_check_disk_error (msg, NULL, 0) || tcpses_check_disk_error (msg2, NULL, 0))
		    {
		      strcpy_ck (err_text, "Server error in accessing temp file");
		      strcpy_ck (err_code, "IM025");
		      SESSION_SCH_DATA (ses)->sio_read_fail_on = 0;
		      goto logout;
		    }
		  if (!STRSES_CAN_BE_STRING (msg) || !STRSES_CAN_BE_STRING (msg2))
		    {
		      strcpy_ck (err_text, "Server error in storing data into a string session");
		      strcpy_ck (err_code, "IM026");
		      SESSION_SCH_DATA (ses)->sio_read_fail_on = 0;
		      goto logout;
		    }
		  dk_set_push (ret_v, list (3, box_num (uid), strses_string (msg2), strses_string (msg)));
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
	  strcpy_ck (err_text, "There must be 2 string items in vector of argument 7 (old folder name to rename and a new name)");
	  goto logout;
	}
      type1 = DV_TYPE_OF (in[0]);
      type2 = DV_TYPE_OF (in[1]);
      if (!IS_STRING_DTP (type1) || !IS_STRING_DTP (type2))
	{
	  strcpy_ck (err_code, "IM029");
	  strcpy_ck (err_text, "There must be 2 string items in vector of argument 7 (old folder name to rename and a new name)");
	  goto logout;
	}
      snprintf (message, sizeof (message), "4 RENAME \"%s\" \"%s\"", in[0], in[1]);
      SEND (ses, rc, message, "");
      while (1)
	{
	  IS_OK_NEXT (ses, resp, rc, "IM030", "RENAME command to remote IMAP server failed", 1);
	  if (strlen (resp) > 2 && !strncmp ("4 OK", resp, 4))
	    break;
	  if (strlen (resp) > 2 && (!strncmp ("4 BAD", resp, 5) || !strncmp ("4 NO", resp, 4)))
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
  if (!stricmp ("fetch", mode) || !stricmp ("message_delete", mode) || !stricmp ("message_copy", mode))
    {
      if (folder_id && strlen (folder_id) > 0)
	snprintf (message, sizeof (message), "4 SELECT \"%s\"", folder_id);
      else
	snprintf (message, sizeof (message), "4 SELECT INBOX");
      SEND (ses, rc, message, "");
      while (1)
	{
	  IS_OK_NEXT (ses, resp, rc, "IM032", "SELECT command to remote IMAP server failed", 1);
	  ps = resp;
	  s = imap_next_word (ps);
	  ps = imap_next_word (s);
	  if (ascii_strncasecmp ("EXISTS", ps, 6) == 0)
	    inx_mails = atoi (s);
	  if (strlen (resp) > 2 && !strncmp ("4 OK", resp, 4))
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
		  strcpy_ck (err_text, "There must be integer items in vector of argument 7");
		  goto logout;
		}
	      if (!stricmp ("fetch", mode))
		snprintf (message, sizeof (message), "5 UID FETCH %d BODY.PEEK[]", (int) (in[br]));
	      if (!stricmp ("message_delete", mode))
		snprintf (message, sizeof (message), "5 UID STORE %d +FLAGS (\\Deleted)", (int) (in[br]));
	      if (!stricmp ("message_copy", mode))
		snprintf (message, sizeof (message), "5 UID COPY %d \"%s\"", (int) (in[br]), target_folder_id);
	      SEND (ses, rc, message, "");
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
		      if (strlen (resp) > 2 && !strncmp ("5 OK", resp, 4))
			break;
		      if (strlen (resp) > 2 && !strncmp ("5 BAD", resp, 5))
			{
			  strcpy_ck (err_text, "Error in IMAP command UID STORE");
			  strcpy_ck (err_code, "IM035");
			  break;
			}
		      if (strlen (resp) > 2 && !strncmp ("5 NO", resp, 4))
			{
			  strcpy_ck (err_text, "Error in IMAP command UID STORE");
			  strcpy_ck (err_code, "IM036");
			  break;
			}
		      while (resp)
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
			      if (!stricmp ("message_delete", mode) || !stricmp ("message_copy", mode))
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
			  if (strlen (resp) > 2 && (!strncmp ("5 OK", resp, 4) || !strncmp ("5 BAD", resp, 5)
				  || !strncmp ("5 NO", resp, 4)))
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
		      if (!STRSES_CAN_BE_STRING (msg))
			{
			  strcpy_ck (err_text, "Server error in storing data into a string session");
			  strcpy_ck (err_code, "IM040");
			  SESSION_SCH_DATA (ses)->sio_read_fail_on = 0;
			  goto logout;
			}
		      if (uid > 0)
			{
			  caddr_t result = NULL;
			  result = strses_string (msg);
			  if (!strncmp (result + strlen (result) - 3, end_msg3, sizeof (end_msg3)))
			    result[strlen (result) - 3] = 0;
			  dk_set_push (ret_v, list (2, box_num (uid), result));
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
  /* QUIT from pop3 server */
  SEND (ses, rc, "9 LOGOUT", "");
  while (1)
    {
      IS_OK_NEXT (ses, resp, rc, "IM043", "Could not LOGOUT from remote IMAP server", 0);
      if (strlen (resp) > 2 && !strncmp ("9 OK", resp, 4))
	break;
    }
error_end:
  if (err_code[0] != 0)
    *err_ret = srv_make_new_error ("08006", err_code, "%s", err_text);
  strses_free (msg);
  strses_free (msg2);
  PrpcDisconnect (ses);
  PrpcSessionFree (ses);
  SSL_CTX_free (ssl_ctx);
  return;
  /* *err_ret = srv_make_new_error ("08006", "IM044", "Misc. error in connection in imap_get"); */
}

static caddr_t
bif_imap_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *in_uidl = NULL;
  caddr_t folder_id = NULL;
  caddr_t addr = bif_string_arg (qst, args, 0, "imap_get");
  caddr_t user = bif_string_arg (qst, args, 1, "imap_get");
  caddr_t pass = bif_string_arg (qst, args, 2, "imap_get");
  long end_size = (long) bif_long_arg (qst, args, 3, "imap_get");
  caddr_t ret = NULL;
  caddr_t mode = "";
  caddr_t err = NULL;
  long cert = 0;
  dk_set_t volatile uidl_mes = NULL;
  IO_SECT (qst);
  if (BOX_ELEMENTS (args) > 4)
    mode = bif_string_arg (qst, args, 4, "imap_get");
  if (BOX_ELEMENTS (args) > 5)
    folder_id = bif_string_arg (qst, args, 5, "imap_get");
  if (BOX_ELEMENTS (args) > 6)
    {
      in_uidl = (caddr_t *) bif_array_or_null_arg (qst, args, 6, "imap_get");
      if (in_uidl && DV_TYPE_OF (in_uidl) != DV_ARRAY_OF_POINTER)
	sqlr_new_error ("08000", "IM013", "Argument 7 to imap_get must be a vector");
    }
  if (BOX_ELEMENTS (args) > 7)
    cert = bif_long_arg (qst, args, 7, "imap_get");
  imap_get (addr, &err, user, pass, end_size, mode, (dk_set_t *) & uidl_mes, folder_id, in_uidl, qst, cert);
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
  bif_define_typed ("imap_get", bif_imap_get, &bt_varchar);
}

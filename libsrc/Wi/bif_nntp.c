/*
 *  bif_nntp.c
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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
#include "sqlbif.h"
#include "libutil.h"
#include <stddef.h>

#define READ(ses, resp, rc) CATCH_READ_FAIL (ses) \
				     { \
				       resp[0] = 0; \
            			       rc = dks_read_line (ses, resp, sizeof (resp)); \
				     } \
				   FAILED \
				     { \
				       strcpy_ck (resp, "Lost connection with NNTP server"); \
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
				     strcpy_ck (resp, "Cannot send command to NNTP server"); \
				     goto error_end; \
				   } \
				END_WRITE_FAIL (ses)

static dk_session_t *
nntp_get (char *host, char *user, char *pass, char *mode, char *group, caddr_t * err_ret,
    dk_set_t * ret_val, volatile long u_first, volatile long u_end, char *id, caddr_t *qst, int error_ret)
{
  volatile int rc, last, first, all, inx, ans, num;
  char resp[2048], group_name[512];
  char resp1[2048];
  char pos[256];
  char stat[32], _id[256];
  dk_session_t *msg = NULL;
  char end_msg[] = ".\x0D\x0A\x00";
  dk_session_t *ses = dk_session_allocate (SESCLASS_TCPIP);

  if (id)
    if (strlen (id) > sizeof (pos))
      {
	*err_ret = srv_make_new_error ("22023", "NN001", "Large ID in nntp_id_get");
	return NULL;
      }

  resp[0] = 0;
  if (!_thread_sched_preempt)
    {
      ses->dks_read_block_timeout = dks_fibers_blocking_read_default_to;
    }
  rc = session_set_address (ses->dks_session, host);

  if (SER_SUCC != rc)
    {
      PrpcSessionFree (ses);
      *err_ret = srv_make_new_error ("2E000", "NN002", "Invalid address for News Server at %s", host);
      return NULL;
    }

  rc = session_connect (ses->dks_session);
  if (SER_SUCC != rc)
    {
      if (rc != SER_NOREC)
	session_disconnect (ses->dks_session);
      PrpcSessionFree (ses);
      *err_ret = srv_make_new_error ("08001", "NN003", "Unable to Contact News Server at %s", host);
      return NULL;
    }

  msg = strses_allocate ();

  READ (ses, resp, rc);		/* 200 server ready posting allowed -201 server ready no posting allowed */
  if (strncmp ("200", resp, 3) && strncmp ("201", resp, 3))
    goto error_end;

  SEND (ses, rc, "MODE READER", "");
  READ (ses, resp, rc);		/* 200 server ready posting allowed -201 server ready no posting allowed */
  if (strncmp ("200", resp, 3) && strncmp ("201", resp, 3))
    goto error_end;

  if (user)
    {
      SEND (ses, rc, "AUTHINFO USER ", user);
      READ (ses, resp, rc);	/* 381 */
      if (strncmp ("381", resp, 3))
	goto error_end;
      SEND (ses, rc, "AUTHINFO PASS ", pass);
      READ (ses, resp, rc);	/* *** */
      if (strncmp ("281", resp, 3))
	goto error_end;
    }

  if (!stricmp ("list", mode))
    {
      char s_last[20], s_first[20], post[3], *ptr;
      SEND (ses, rc, "LIST ", "");
      READ (ses, resp, rc);	/* 215 */
      if (strncmp ("215", resp, 3))
	goto error_end;

      CATCH_READ_FAIL (ses)
      {
	resp1[0] = 0;
	while (strcmp (resp1, end_msg))
	  {
	    rc = dks_read_line (ses, resp, sizeof (resp));
	    strcpy_ck (resp1, resp);
	    ptr = resp + rc - 1;
	    while (ptr >= resp && (*ptr == '\x0D' || *ptr == '\x0A'))
	      *ptr-- = 0;
	    if (resp[0] != '.')
	      {
		sscanf (resp, "%511s %10s %10s %2s", group_name, s_last, s_first,
		    post);
		dk_set_push (ret_val, list (4,
			box_dv_short_string (group_name),
			box_num (atoi (s_last)), box_num (atoi (s_first)),
			box_dv_short_string (post)));
	      }
	  }
      }
      FAILED
      {
        strcpy_ck (resp, "Lost connection with NNTP server");
	goto error_end;
      }
      END_READ_FAIL (ses);
    }

  if (!stricmp ("xover", mode))
    {
      char position, *ptr, *tok, *tok_s = NULL;
      dk_set_t vr = NULL;

      SEND (ses, rc, "GROUP ", group);
      READ (ses, resp, rc);	/* 211 */
      if (strncmp ("211", resp, 3))
	goto error_end;

      snprintf (pos, sizeof (pos), " %li-%li", u_first, u_end);	/* limits  */
      SEND (ses, rc, mode, pos);
      READ (ses, resp, rc);	/* 211 */
      if (strncmp ("224", resp, 3))
	goto error_end;

      CATCH_READ_FAIL (ses)
      {
	resp1[0] = 0;
	while (strcmp (resp1, end_msg))
	  {
	    rc = dks_read_line (ses, resp, sizeof (resp));
	    strcpy_ck (resp1, resp);
	    ptr = resp + rc - 1;
	    while (ptr >= resp && (*ptr == '\x0D' || *ptr == '\x0A'))
	      *ptr-- = 0;
	    if (resp[0] != '.')
	      {
		position = 0;
		tok = strtok_r (resp, "\t", &tok_s);
		while (tok)
		  {
		    if (position && (position-6) && (position-7))
		      dk_set_push (&vr, box_dv_short_string (tok));
		    else
		      dk_set_push (&vr, box_num (atoi (tok)));

		    tok = strtok_r (NULL, "\t", &tok_s);
		    position++;
		  }
		dk_set_push (ret_val, list_to_array (dk_set_nreverse (vr)));
		vr = NULL;
	      }
	  }
      }
      FAILED
      {
        strcpy_ck (resp, "Lost connection with NNTP server");
	goto error_end;
      }
      END_READ_FAIL (ses);
    }

  if (!stricmp ("group", mode))
    {
      SEND (ses, rc, "GROUP ", group);
      READ (ses, resp, rc);	/* 211 */
      if (strncmp ("211", resp, 3))
	goto error_end;

      sscanf (resp, "%3s %7i %7i %7i", stat, &all, &first, &last);

      dk_set_push (ret_val, box_num (all));

      if (first < last)
	{
	    dk_set_push (ret_val, box_num (first));
	    dk_set_push (ret_val, box_num (last));
	}
      else
	{
	    dk_set_push (ret_val, box_num (last));
	    dk_set_push (ret_val, box_num (first));
	}
    }

  if ((!stricmp ("body", mode) || !stricmp ("article", mode)
	  || !stricmp ("head", mode) || !stricmp ("stat", mode)))
    {
      if (!id)
	{
	  SEND (ses, rc, "GROUP ", group);
	  READ (ses, resp, rc);	/* 211 */
	  if (strncmp ("211", resp, 3))
	    goto error_end;

	  sscanf (resp, "%3s %7i %7i %7i", stat, &all, &first, &last);

	  if ((u_first < first) || (u_first == 0))
	    u_first = first;
	  if ((u_end > last) || (u_end == 0))
	    u_end = last;
	}

      for (inx = u_first; inx < u_end + 1; inx++)
	{
	  resp[0] = 0;

	  if (id)
	    {
	      snprintf (pos, sizeof (pos), " %.*s", 200, id);	/* nntp_id_get */
	      inx++;
	    }
	  else
	    snprintf (pos, sizeof (pos), " %i", inx);	/* nntp_get  */

	  SEND (ses, rc, mode, pos);
	  READ (ses, resp, rc);
	  sscanf (resp, "%3i %7i %255s %7s", &ans, &num, _id, stat);

	  if (ans < 220 || ans > 223)
	    continue;  /* Messages dont exist */

	  strses_flush (msg);
	  strses_enable_paging (msg, http_ses_size);
	  CATCH_READ_FAIL (ses)
	  {
	    if (stricmp ("stat", mode))
	      {
		while (strcmp (resp, end_msg))
		  {
		    rc = dks_read_line (ses, resp, sizeof (resp));
		    SES_PRINT (msg, resp);
		    if (tcpses_check_disk_error (msg, qst, 0))
		      {
			strcpy_ck (resp, "Server error in accessing temp file");
			SESSION_SCH_DATA(ses)->sio_read_fail_on = 0;
			goto error_end;
		      }
		  }
	      }
	    else
	      SES_PRINT (msg, _id);
	    if (tcpses_check_disk_error (msg, qst, 0))
	      {
		strcpy_ck (resp, "Server error in accessing temp file");
		SESSION_SCH_DATA(ses)->sio_read_fail_on = 0;
		goto error_end;
	      }
	    session_flush_1 (msg);
	  }
	  FAILED
	  {
            strcpy_ck (resp, "Lost connection with NNTP server");
	    goto error_end;
	  }
	  END_READ_FAIL (ses);

	  if (!STRSES_CAN_BE_STRING (msg))
	    {
	      dk_set_push (ret_val, list (2, box_num (num), msg));
	      msg = strses_allocate ();
	    }
	  else
	    dk_set_push (ret_val, list (2, box_num (num), strses_string (msg)));
	}
    }

  /* an addition to recognize what is the server */
  if (!stricmp ("xvirtid", mode))
    {
      char nn_identifier[512];
      nn_identifier [0] = 0;
      SEND (ses, rc, "XVIRTID", "");
      READ (ses, resp, rc);	/* 200 */
      if (!strncmp ("100", resp, 3))
	sscanf (resp, "%*3s %36s", nn_identifier);
      dk_set_push (ret_val, box_dv_short_string (nn_identifier));
    }

  SEND (ses, rc, "QUIT", "");
  READ (ses, resp, rc);		/* 205 OK */
/*  if (strncmp ("205", resp, 3))
    goto error_end;   */

  strses_free (msg);
  return ses;

error_end:
  strses_free (msg);
  *err_ret = srv_make_new_error ("08006", "NN004", "%s", resp);
  if (error_ret)
    return ses;
  session_disconnect (ses->dks_session);
  PrpcSessionFree (ses);
  return NULL;
}


static caddr_t
bif_nntp_get_new (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_session_t *ses = NULL;
  caddr_t gname = "", err = NULL;
  dk_set_t list = NULL;
  long u_first = 0, u_end = 0;
  int err_mode = 1;
  caddr_t addr = bif_string_arg (qst, args, 0, "nntp_get_new");
  caddr_t mode = bif_string_arg (qst, args, 1, "nntp_get_new");
  caddr_t ret = NULL;

  if (BOX_ELEMENTS (args) > 2)
    gname = bif_string_arg (qst, args, 2, "nntp_get_new");

  if (BOX_ELEMENTS (args) > 3)
    u_first = (long) bif_long_arg (qst, args, 3, "nntp_get_new");
  if (BOX_ELEMENTS (args) > 4)
    u_end = (long) bif_long_arg (qst, args, 4, "nntp_get_new");

  if ((!stricmp ("body", mode) || !stricmp ("article", mode)
	  || !stricmp ("head", mode) || !stricmp ("stat", mode)
	  || !stricmp ("list", mode) || !stricmp ("group", mode)
	  || !stricmp ("xover", mode) || !stricmp ("xvirtid", mode)))
    {
      dk_set_t new_ret = NULL;

      IO_SECT(qst);
      ses = nntp_get (addr, NULL, NULL, mode, gname, &err, &list, u_first, u_end, NULL, qst, err_mode);
      END_IO_SECT (err_ret);

      if (!ses)
	{
	  err = srv_make_new_error ("08006", "NN005", "Misc. error in connection in nntp_get");
	}
      else
	{
	  session_disconnect (ses->dks_session);
	  PrpcSessionFree (ses);
	}

      dk_set_push (&new_ret,  list_to_array (list));
      dk_set_push (&new_ret,  err);

      ret = list_to_array (new_ret);
    }
  else
    *err_ret = srv_make_new_error ("22023", "NN006", "the command is not recognized");
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  return ret;
}


static caddr_t
bif_nntp_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_session_t *ses = NULL;
  caddr_t gname = "", err = NULL;
  dk_set_t list = NULL;
  long u_first = 0, u_end = 0;
  caddr_t addr = bif_string_arg (qst, args, 0, "nntp_get");
  caddr_t mode = bif_string_arg (qst, args, 1, "nntp_get");
  caddr_t ret = NULL;

  if (BOX_ELEMENTS (args) > 2)
    gname = bif_string_arg (qst, args, 2, "nntp_get");

  if (BOX_ELEMENTS (args) > 3)
    u_first = (long) bif_long_arg (qst, args, 3, "nntp_get");
  if (BOX_ELEMENTS (args) > 4)
    u_end = (long) bif_long_arg (qst, args, 4, "nntp_get");

  if ((!stricmp ("body", mode) || !stricmp ("article", mode)
	  || !stricmp ("head", mode) || !stricmp ("stat", mode)
	  || !stricmp ("list", mode) || !stricmp ("group", mode)
	  || !stricmp ("xover", mode) || !stricmp ("xvirtid", mode)))
    {
      IO_SECT(qst);
      ses = nntp_get (addr, NULL, NULL, mode, gname, &err, &list, u_first, u_end, NULL, qst, 0);
      END_IO_SECT (err_ret);

      if (err_ret && *err_ret)
	{
	  if (err)
            dk_free_tree (err);
	  if (ses)
	    {
	      session_disconnect (ses->dks_session);
	      PrpcSessionFree (ses);
	    }
	  return NULL;
	}
      if (err)
	{
	  if (ses)
	    {
	      session_disconnect (ses->dks_session);
	      PrpcSessionFree (ses);
	    }
	  sqlr_resignal (err);
	}
      if (!ses)
	sqlr_new_error ("08006", "NN005", "Misc. error in connection in nntp_get");

      session_disconnect (ses->dks_session);
      PrpcSessionFree (ses);
      ret = list_to_array (dk_set_nreverse (list));
    }
  else
    *err_ret = srv_make_new_error ("22023", "NN006", "the command is not recognized");
  return ret;
}


static caddr_t
bif_nntp_auth_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_session_t *ses = NULL;
  caddr_t gname = NULL;
  caddr_t err = NULL;
  dk_set_t list = NULL;
  long u_first = 0, u_end = 0;
  caddr_t addr = bif_string_arg (qst, args, 0, "nntp_auth_get");
  caddr_t user = bif_string_arg (qst, args, 1, "nntp_auth_get");
  caddr_t pass = bif_string_arg (qst, args, 2, "nntp_auth_get");
  caddr_t mode = bif_string_arg (qst, args, 3, "nntp_auth_get");

  if (BOX_ELEMENTS (args) > 4)
    gname = bif_string_arg (qst, args, 4, "nntp_auth_get");

  if (BOX_ELEMENTS (args) > 5)
    u_first = (long) bif_long_arg (qst, args, 5, "nntp_auth_get");
  if (BOX_ELEMENTS (args) > 6)
    u_end = (long) bif_long_arg (qst, args, 6, "nntp_auth_get");

  if ((!stricmp ("body", mode) || !stricmp ("article", mode)
	  || !stricmp ("head", mode) || !stricmp ("stat", mode)
	  || !stricmp ("list", mode) || !stricmp ("group", mode)  || !stricmp ("xover", mode)))
    {
      IO_SECT(qst);
      ses = nntp_get (addr, user, pass, mode, gname, &err, &list, u_first, u_end, NULL, qst, 0);
      END_IO_SECT (err_ret);

      if (err_ret && *err_ret)
	{
	  if (err)
            dk_free_tree (err);
	  if (ses)
	    {
	      session_disconnect (ses->dks_session);
	      PrpcSessionFree (ses);
	    }
	  return NULL;
	}
      if (err)
	{
	  if (ses)
	    {
	      session_disconnect (ses->dks_session);
	      PrpcSessionFree (ses);
	    }
	  sqlr_resignal (err);
	}

      if (!ses)
	sqlr_new_error ("08006", "NN007", "Misc. error in connection in nntp_auth_get");

      session_disconnect (ses->dks_session);
      PrpcSessionFree (ses);
      return list_to_array (dk_set_nreverse (list));
    }
  else
    *err_ret = srv_make_new_error ("22023", "NN008", "the command is not recognized");
  return NULL;
}


static caddr_t
bif_nntp_id_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_session_t *ses = NULL;
  caddr_t err = NULL;
  dk_set_t list = NULL;
  caddr_t addr = bif_string_arg (qst, args, 0, "nntp_id_get");
  caddr_t mode = bif_string_arg (qst, args, 1, "nntp_id_get");
  caddr_t id = bif_string_arg (qst, args, 2, "nntp_id_get");

  if ((!stricmp ("body", mode) || !stricmp ("article", mode)
	  || !stricmp ("head", mode) || !stricmp ("stat", mode)))
    {
      IO_SECT(qst);
      ses = nntp_get (addr, NULL, NULL, mode, NULL, &err, &list, 0, 1, id, qst, 0);
      END_IO_SECT (err_ret);

      if (err_ret && *err_ret)
	{
	  if (err)
            dk_free_tree (err);
	  if (ses)
	    {
	      session_disconnect (ses->dks_session);
	      PrpcSessionFree (ses);
	    }
	  return NULL;
	}
      if (err)
	{
	  if (ses)
	    {
	      session_disconnect (ses->dks_session);
	      PrpcSessionFree (ses);
	    }
	  sqlr_resignal (err);
	}
      if (!ses)
	sqlr_new_error ("08006", "NN009", "Misc. error in connection in nntp_id_get");

      session_disconnect (ses->dks_session);
      PrpcSessionFree (ses);
      return list_to_array (dk_set_nreverse (list));
    }
  else
    *err_ret = srv_make_new_error ("22023", "NN010", "The command is not recognized");
  return NULL;
}

static caddr_t
nntp_post (caddr_t addr, caddr_t msg_body, caddr_t * err_ret)
{
  caddr_t err = NULL;
  char resp[1024] = "";
  int rc;
  dk_session_t *ses = dk_session_allocate (SESCLASS_TCPIP);

  if (!_thread_sched_preempt)
    {
      ses->dks_read_block_timeout = dks_fibers_blocking_read_default_to;
    }
  rc = session_set_address (ses->dks_session, addr);
  if (SER_SUCC != rc)
    {
      PrpcSessionFree (ses);
      *err_ret = srv_make_new_error ("2E000", "NN011", "Invalid address for the News Server at %s", addr);
      return NULL;
    }

  rc = session_connect (ses->dks_session);
  if (SER_SUCC != rc)
    {
      if (rc != SER_NOREC)
	session_disconnect (ses->dks_session);
      PrpcSessionFree (ses);
      *err_ret = srv_make_new_error ("08001", "NN012", "Unable Post to the News Server at %s", addr);
      return NULL;
    }

  READ (ses, resp, rc);		/* OK from server */
  if (strncmp ("200", resp, 3))
    goto error_end;
  SEND (ses, rc, "POST", "");
  READ (ses, resp, rc);		/* 340 OK */
  if (strncmp ("340", resp, 3))
    goto error_end;
  SEND (ses, rc, msg_body, "");
  READ (ses, resp, rc);		/*  Posted OK  */
  if (strncmp ("240", resp, 3))
    goto error_end;
  SEND (ses, rc, "QUIT ", "");
/*READ (ses, resp, rc);	*/	/* BAY */
/*if (strncmp ("205", resp, 3))
    goto error_end;*/

  if (err)
    sqlr_resignal (err);
  if (!ses)
    sqlr_new_error ("08007", "NN013", "Misc. error in connection in nntp_post");

  session_disconnect (ses->dks_session);
  PrpcSessionFree (ses);
  return box_num (1);
error_end:
  session_disconnect (ses->dks_session);
  PrpcSessionFree (ses);
  *err_ret = srv_make_new_error ("08007", "NN014", "%s", resp);
  return NULL;
}

static caddr_t
bif_nntp_post (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t addr = bif_string_arg (qst, args, 0, "nntp_post");
  caddr_t msg_body = bif_string_arg (qst, args, 1, "nntp_post");
  caddr_t ret = NULL;
  IO_SECT (qst);
  ret = nntp_post (addr, msg_body, err_ret);
  END_IO_SECT (err_ret);
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  return ret;
}


static caddr_t
nntp_auth_post (caddr_t addr, caddr_t user, caddr_t pass, caddr_t msg_body, caddr_t * err_ret)
{
  caddr_t err = NULL;
  char resp[1024] = "";
  int rc;
  dk_session_t *ses = dk_session_allocate (SESCLASS_TCPIP);

  if (!_thread_sched_preempt)
    {
      ses->dks_read_block_timeout = dks_fibers_blocking_read_default_to;
    }
  rc = session_set_address (ses->dks_session, addr);
  if (SER_SUCC != rc)
    {
      PrpcSessionFree (ses);
      *err_ret = srv_make_new_error ("2E000", "NN015", "Invalid address for the News Server at %s", addr);
      return NULL;
    }

  rc = session_connect (ses->dks_session);
  if (SER_SUCC != rc)
    {
      if (rc != SER_NOREC)
	session_disconnect (ses->dks_session);
      PrpcSessionFree (ses);
      *err_ret = srv_make_new_error ("08001", "NN016", "Unable Post to the News Server at %s", addr);
      return NULL;
    }

  READ (ses, resp, rc);		/* OK from server */
  if (strncmp ("200", resp, 3))
    goto error_end;
  SEND (ses, rc, "AUTHINFO USER ", user);
  READ (ses, resp, rc);	/* 381 */
  if (strncmp ("381", resp, 3))
    goto error_end;
  SEND (ses, rc, "AUTHINFO PASS ", pass);
  READ (ses, resp, rc);	/* *** */
  if (strncmp ("281", resp, 3))
    goto error_end;
  SEND (ses, rc, "POST", "");
  READ (ses, resp, rc);		/* 340 OK */
  if (strncmp ("340", resp, 3))
    goto error_end;
  SEND (ses, rc, msg_body, "");
  READ (ses, resp, rc);		/*  Posted OK  */
  if (strncmp ("240", resp, 3))
    goto error_end;
  SEND (ses, rc, "QUIT ", "");
/*READ (ses, resp, r);	*/	/* BYE */
/*if (strncmp ("205", resp, 3))
    goto error_end; */

  if (err)
    sqlr_resignal (err);
  if (!ses)
    sqlr_new_error ("08007", "NN017", "Misc. error in connection in nntp_auth_post");

  session_disconnect (ses->dks_session);
  PrpcSessionFree (ses);
  return box_num (1);
error_end:
  session_disconnect (ses->dks_session);
  PrpcSessionFree (ses);
  *err_ret = srv_make_new_error ("08007", "NN018", "%s", resp);
  return NULL;
}

static caddr_t
bif_nntp_auth_post (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t ret = NULL;
  caddr_t addr = bif_string_arg (qst, args, 0, "nntp_auth_post");
  caddr_t user = bif_string_arg (qst, args, 1, "nntp_auth_post");
  caddr_t pass = bif_string_arg (qst, args, 2, "nntp_auth_post");
  caddr_t msg_body = bif_string_arg (qst, args, 3, "nntp_auth_post");
  IO_SECT(qst);
  ret = nntp_auth_post (addr, user, pass, msg_body, err_ret);
  END_IO_SECT (err_ret);
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  return ret;
}

void
bif_nntp_init (void)
{
  bif_define_ex ("nntp_get", bif_nntp_get, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("nntp_get_new", bif_nntp_get_new, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("nntp_auth_get", bif_nntp_auth_get, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("nntp_id_get", bif_nntp_id_get, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("nntp_post", bif_nntp_post, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("nntp_auth_post", bif_nntp_auth_post, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
}


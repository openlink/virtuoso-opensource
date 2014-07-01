/*
 *  sqlprt.c
 *
 *  $Id$
 *
 *  SQL Statement Printer
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

#include "sqlnode.h"
#include "sqlbif.h"

#define REPORT_BUF_MAX		4000

void
trset_start (caddr_t * qst)
{
  state_slot_t sample;
  state_slot_t **sbox;
  caddr_t err;
  caddr_t buf;

  buf = dk_alloc_box (REPORT_BUF_MAX + 1, DV_LONG_STRING);
  buf[0] = 0;
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_REPORT_BUFFER, buf);
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_REPORT_PTR, buf);
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_REPORT_QST, qst);

  sbox = (state_slot_t **) dk_alloc_box (sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  memset (&sample, 0, sizeof (sample));
  sbox[0] = &sample;

  sample.ssl_name = box_dv_uname_string ("REPORT");
  sample.ssl_type = SSL_COLUMN;
  sample.ssl_dtp = DV_SHORT_STRING;
  sample.ssl_prec = REPORT_BUF_MAX;

  bif_result_names_impl (qst, &err, sbox, QT_PROC_CALL);

  dk_free_box ((caddr_t) sbox);
  dk_free_box (sample.ssl_name);
}


void
trset_printf (const char *str, ...)
{
  char *report_linebuf;
  char *report_ptr;
  char *line;
  char *eol;
  char *copy;
  va_list ap;
  size_t length;

  report_linebuf = (char *) THR_ATTR (THREAD_CURRENT_THREAD, TA_REPORT_BUFFER);
  report_ptr = (char *) THR_ATTR (THREAD_CURRENT_THREAD, TA_REPORT_PTR);

  va_start (ap, str);
  if (!report_ptr)
    {
      vprintf (str, ap);
      va_end (ap);
    }
  else
    {
      int used = report_ptr - report_linebuf;
      int len;
      int space = box_length (report_linebuf) - used;
      len = vsnprintf (report_ptr, space, str, ap);
      va_end (ap);
      if (len > space)
	{
	  caddr_t nxt = dk_alloc_box (box_length  (report_linebuf) + (len - space) + 1000, DV_STRING);
	  memcpy (nxt, report_linebuf, used);
	  dk_free_box (report_linebuf);
	  report_linebuf = nxt;
	  report_ptr = nxt + used;
	  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_REPORT_BUFFER, report_linebuf);
	  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_REPORT_PTR, report_ptr);
	  va_start (ap, str);
	  vsnprintf (report_ptr, box_length (report_linebuf) - used, str, ap);
	  va_end (ap);
	}
      if (!report_ptr)
	return;

      for (line = eol = report_linebuf; *line; line = eol)
	{
	  if ((eol = strchr (line, '\n')) == NULL)
	    break;
	  *eol++ = 0;
	  if (line[0] == 0)
	    line = " ";
	  copy = box_dv_short_string (line);
	  bif_result_inside_bif (1, copy);
	  dk_free_box (copy);
	}
      if (eol == NULL)
	{
	  length = strlen (line);
	  if (report_linebuf != line && length >= 0)
	    memmove (report_linebuf, line, length);
	}
      else
	length = 0;

      report_ptr = report_linebuf + length;
      if (length > REPORT_BUF_MAX - EXPLAIN_LINE_MAX)
	{
	  caddr_t copy = box_dv_short_string (report_linebuf);
	  bif_result_inside_bif (1, copy);
	  dk_free_box (copy);
	  report_ptr = report_linebuf;
	}

      SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_REPORT_BUFFER, report_linebuf);
      SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_REPORT_PTR, report_ptr);
    }
}

void
trset_end (void)
{
  client_connection_t * cli = GET_IMMEDIATE_CLIENT_OR_NULL;
  char *report_linebuf;
  char *report_ptr;
  char *line;
  caddr_t ret;

  report_linebuf = (char *) THR_ATTR (THREAD_CURRENT_THREAD, TA_REPORT_BUFFER);
  report_ptr = (char *) THR_ATTR (THREAD_CURRENT_THREAD, TA_REPORT_PTR);

  if (report_ptr > report_linebuf)
    {
      *report_ptr = 0;
      line = box_dv_short_string (report_linebuf);
      bif_result_inside_bif (1, line);
      dk_free_box (line);
    }
  dk_free_box (report_linebuf);

  if (cli && !cli->cli_ws && !cli->cli_resultset_comp_ptr)
    {
      ret = list (2, (caddr_t) QA_PROC_RETURN, (caddr_t) 0);
      PrpcAddAnswer ((caddr_t) ret, DV_ARRAY_OF_POINTER, PARTIAL, 0);
      dk_free_box (ret);
    }
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_REPORT_BUFFER, NULL);
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_REPORT_PTR, NULL);
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_REPORT_QST, NULL);
}

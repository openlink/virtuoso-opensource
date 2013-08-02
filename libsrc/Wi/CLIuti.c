/*
 *  CLIuti.c
 *
 *  $Id$
 *
 *  Auxiliary functions for the ODBC driver
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

#include "CLI.h"
#include "multibyte.h"
#if !defined (__APPLE__)
#include <wchar.h>
#endif

#define IN_ODBC_CLIENT
#include "wi.h"


caddr_t
stmt_param_place_ptr (parm_binding_t * pb, int nth, cli_stmt_t * stmt,
    SQLULEN length)
{
  /* bind type offset */
  SQLULEN p_offset = nth * (stmt->stmt_param_bind_type ? stmt->stmt_param_bind_type : length);

  /* quick rebinding offset */
  p_offset +=
      stmt ? (stmt->stmt_imp_param_descriptor ? (stmt->
	  stmt_imp_param_descriptor->d_bind_offset_ptr ? *(stmt->stmt_imp_param_descriptor->d_bind_offset_ptr) : 0) : 0) : 0;

  return pb->pb_place ? pb->pb_place + p_offset : NULL;
}


SQLLEN *
stmt_param_length_ptr (parm_binding_t * pb, int nth, cli_stmt_t * stmt)
{

  /* bind type offset */
  SQLLEN l_offset = nth * (stmt->stmt_param_bind_type ? stmt->stmt_param_bind_type : sizeof (SQLLEN));

  /* quick rebinding offset */
  l_offset += stmt ?
      (stmt->stmt_imp_param_descriptor ?
      (stmt->stmt_imp_param_descriptor->d_bind_offset_ptr ? *(stmt->stmt_imp_param_descriptor->d_bind_offset_ptr) : 0) : 0) : 0;

  return pb->pb_length ? ((SQLLEN *) (((caddr_t) pb->pb_length) + l_offset)) : NULL;
}


/*
#define PARAM_PLACE(pb, nth, stmt, type) (type *)(\
			(stmt->stmt_param_bind_type == 0 ? \
				(pb->pb_place + sizeof(type) * nth ): \
				(pb->pb_place + nth * stmt->stmt_param_bind_type ) \
			) \
		 + (stmt ? (stmt->stmt_imp_param_descriptor ? (stmt->stmt_imp_param_descriptor->d_bind_offset_ptr ? *(stmt->stmt_imp_param_descriptor->d_bind_offset_ptr) :0) : 0) : 0) \
		)

#define PARAM_LENGTH(pb, nth, stmt) \
	(stmt->stmt_param_bind_type == 0 ? pb->pb_length + nth : (SDWORD *)(((caddr_t)pb->pb_length) + nth * stmt->stmt_param_bind_type))
*/

/* How about SQL_BOX, SQL_C_BOX, SQL_OBJECT, SQL_C_OBJECT, SQL_C_OID and
   SQL_OID ? */

int
sql_type_to_sqlc_default (int sqlt)
{
  switch (sqlt)
    {
    case SQL_CHAR:
    case SQL_VARCHAR:
    case SQL_LONGVARCHAR:
    case SQL_DECIMAL:
      return SQL_C_CHAR;

    case SQL_WCHAR:
    case SQL_WVARCHAR:
    case SQL_WLONGVARCHAR:
      return SQL_C_WCHAR;

    case SQL_BIT:
      return SQL_C_BIT;

    case SQL_TINYINT:
      return SQL_C_TINYINT;

    case SQL_SMALLINT:
      return SQL_C_SHORT;

    case SQL_INTEGER:
      return SQL_C_LONG;

    case SQL_BIGINT:
      return SQL_C_LONG;

    case SQL_REAL:
      return SQL_C_FLOAT;

    case SQL_FLOAT:
    case SQL_DOUBLE:
      return SQL_C_DOUBLE;

    case SQL_BINARY:
    case SQL_VARBINARY:
    case SQL_LONGVARBINARY:
      return SQL_C_BINARY;

    case SQL_DATE:
      return SQL_C_DATE;

#if (defined (SQL_TYPE_DATE) && defined (SQL_C_TYPE_DATE))
    case SQL_TYPE_DATE:
      return SQL_C_TYPE_DATE;
#endif

#if (defined (SQL_TYPE_TIME) && defined (SQL_C_TYPE_TIME))
    case SQL_TYPE_TIME:
      return SQL_C_TYPE_TIME;
#endif

    case SQL_TIME:
      return SQL_C_TIME;

#if (defined (SQL_TYPE_TIMESTAMP) && defined (SQL_C_TYPE_TIMESTAMP))
    case SQL_TYPE_TIMESTAMP:
      return SQL_C_TYPE_TIMESTAMP;
#endif

    case SQL_TIMESTAMP:
      return SQL_C_TIMESTAMP;
    }

  return SQL_C_CHAR;
}


int
dv_to_sql_type (dtp_t dv, int cli_binary_timestamp)
{
  switch (dv)
    {
    case DV_SHORT_INT:
      return SQL_SMALLINT;

    case DV_LONG_INT:
      return SQL_INTEGER;

    case DV_DOUBLE_FLOAT:
      return SQL_DOUBLE;

    case DV_NUMERIC:
      return SQL_DECIMAL;

    case DV_SINGLE_FLOAT:
      return SQL_REAL;

    case DV_BLOB:
    case DV_BLOB_XPER:		/* IvAn/DvBlobXper/001212 case added */
      return SQL_LONGVARCHAR;

    case DV_BLOB_BIN:
      return SQL_LONGVARBINARY;

    case DV_BLOB_WIDE:
      return SQL_WLONGVARCHAR;

    case DV_DATE:
      return SQL_DATE;

    case DV_TIMESTAMP:
      return cli_binary_timestamp ? SQL_BINARY : SQL_TIMESTAMP;	/* AK 27-FEB-1997 */

    case DV_DATETIME:
      return SQL_TIMESTAMP;

    case DV_TIME:
      return SQL_TIME;

    case DV_BIN:
      return SQL_VARBINARY;

    case DV_WIDE:
    case DV_LONG_WIDE:
      return SQL_WVARCHAR;

    case DV_ANY:
      return SQL_LONGVARCHAR;

    case DV_INT64:
      return SQL_INTEGER;

    case DV_IRI_ID:
      return SQL_VARCHAR;

    default:
      return SQL_VARCHAR;
    }
}


/* SQL data type codes.
   These were taken from ../sqlcli.h and ../sqlcli2.h header files.
   Added by AK 22-MAR-1997. (Taken from test/isqlodbc.c)
 */
char *
sql_type_to_sql_type_name (int type, char *resbuf, int maxbytes)
{
  char *ret;

  switch (type)
    {
    case SQL_CHAR:
      ret = "CHAR";
      break;

    case SQL_NUMERIC:
      ret = "NUMERIC";
      break;

    case SQL_DECIMAL:
      ret = "DECIMAL";
      break;

    case SQL_INTEGER:
      ret = "INTEGER";
      break;

    case SQL_SMALLINT:
      ret = "SMALLINT";
      break;

    case SQL_FLOAT:
      ret = "FLOAT";
      break;

    case SQL_REAL:
      ret = "REAL";
      break;

    case SQL_DOUBLE:
      ret = "DOUBLE";
      break;

    case SQL_TYPE_DATE:
    case SQL_DATE:
      ret = "DATE";
      break;

    case SQL_TYPE_TIME:
    case SQL_TIME:
      ret = "TIME";
      break;

    case SQL_TYPE_TIMESTAMP:
    case SQL_TIMESTAMP:
      ret = "TIMESTAMP";
      break;

    case SQL_VARCHAR:
      ret = "VARCHAR";
      break;

    case SQL_BIT:
      ret = "BIT";
      break;

#if 0
    case SQL_BIT_VARYING:
      ret = "BIT VARYING";
      break;
#endif

    case SQL_LONGVARCHAR:
      ret = "LONG VARCHAR";
      break;

    case SQL_BINARY:
      ret = "BINARY";
      break;

    case SQL_VARBINARY:
      ret = "VARBINARY";
      break;

    case SQL_LONGVARBINARY:
      ret = "LONG VARBINARY";
      break;

    case SQL_BIGINT:
      ret = "BIGINT";
      break;

    case SQL_TINYINT:
      ret = "TINYINT";
      break;

    case SQL_WCHAR:
      ret = "NCHAR";
      break;

    case SQL_WVARCHAR:
      ret = "NVARCHAR";
      break;

    case SQL_WLONGVARCHAR:
      ret = "LONG NVARCHAR";
      break;

    default:
      {
	char tmp[33];
	snprintf (tmp, sizeof (tmp), "UNK_TYPE:%d", type);
	strncpy (resbuf, tmp, maxbytes);
	return resbuf;
      }
    }				/* switch */

  strncpy (resbuf, ret, maxbytes);

  return resbuf;
}


caddr_t
box_n_string (SQLCHAR * str, SQLLEN len)
{
  SQLLEN bytes = len == SQL_NTS ? strlen ((char *) str) + 1 : len + 1;
  caddr_t box = dk_alloc_box (bytes, DV_SHORT_STRING);

  memcpy (box, str, bytes - 1);
  box[bytes - 1] = 0;

  return box;
}


caddr_t
box_n_wstring (wchar_t * str, SDWORD len)
{
  SQLLEN bytes = (len == SQL_NTS ? wcslen (str) + 1 : len + 1) * sizeof (wchar_t);
  caddr_t box = dk_alloc_box (bytes, DV_WIDE);

  memcpy (box, str, bytes - sizeof (wchar_t));
  memset (box + bytes - sizeof (wchar_t), 0, sizeof (wchar_t));

  return box;
}


caddr_t
box_numeric_string (SQLCHAR * str, SQLLEN len1)
{
  caddr_t box;
  SQLLEN cpy;
  int rc;
  char tmp[NUMERIC_MAX_STRING_BYTES];
  SQLLEN len = len1 == SQL_NTS ? (int) strlen ((char *) str) : len1;

  if (len >= sizeof (tmp))
    return (box_n_string (str, len1));

  cpy = MIN (len, sizeof (tmp) - 1);
  memcpy (tmp, str, cpy);
  tmp[cpy] = 0;
  box = (caddr_t) numeric_allocate ();

  rc = numeric_from_string ((numeric_t) box, tmp);
  if (rc != NUMERIC_STS_SUCCESS)
    {
      numeric_free ((numeric_t) box);

      return (box_n_string (str, len1));
    }

  return box;
}


caddr_t
con_new_id (cli_connection_t * con)
{
  char *str;
  char temp[100];
  char *ptr = temp;

  snprintf (temp, sizeof (temp), "s%s_%ld", con && con->con_session ?
      con->con_session->dks_own_name : "<unconnected>", (long) con->con_last_id++);

  while (*ptr)
    {
      if (*ptr == ':')
	*ptr = '_';
      ptr++;
    }

  str = box_dv_short_string (temp);

  return str;
}


parm_binding_t *
stmt_nth_parm (cli_stmt_t * stmt, int n)
{
  parm_binding_t **last = &stmt->stmt_parms;
  parm_binding_t *next = NULL;
  int inx = -1;

  for (inx = 0; inx < n; inx++)
    {
      next = *last;
      if (!next)
	{
	  NEW_VARZ (parm_binding_t, xx);
	  *last = xx;
	  last = &xx->pb_next;
	  next = xx;
	}
      else
	last = &next->pb_next;
    }

  if (stmt->stmt_n_parms < n)
    stmt->stmt_n_parms = n;

  return next;
}


col_binding_t *
stmt_nth_col (cli_stmt_t * stmt, int n)
{
  col_binding_t **last = &stmt->stmt_cols;
  col_binding_t *next = NULL;
  int inx = -1;

  if (0 == n)
    {
      if (stmt->stmt_bookmark_cb)
	return (stmt->stmt_bookmark_cb);
      {
	NEW_VARZ (col_binding_t, cb);
	stmt->stmt_bookmark_cb = cb;

	return cb;
      }
    }

  for (inx = 0; inx < n; inx++)
    {
      next = *last;
      if (!next)
	{
	  /* This will clear all elements of new cb node to zeros, so also cb_next
	     is set to NULL, and cb_read_up_to is set to zero. */
	  NEW_VARZ (col_binding_t, xx);
	  *last = xx;
	  last = &xx->cb_next;
	  next = xx;
	}
      else
	last = &next->cb_next;
    }

  if (stmt->stmt_n_cols < n)
    stmt->stmt_n_cols = n;

  return next;
}


void
err_queue_append (sql_error_rec_t ** q1, sql_error_rec_t ** q2)
{
  while (*q1)
    q1 = &(*q1)->sql_error_next;
  *q1 = *q2;
  *q2 = NULL;
}

sql_error_rec_t *
cli_make_error (const char * state, const char *virt_state, const char * msg, int col)
{
  caddr_t msg_box;
  int msg_len = msg ? (int) strlen (msg) : 0;
  int virt_state_len = virt_state ? (int) strlen (virt_state) + 2 : 0;
  NEW_VARZ (sql_error_rec_t, rec);
  msg_box = dk_alloc_box (sizeof (ERR_STRING) + msg_len + virt_state_len, DV_SHORT_STRING);
  memcpy (msg_box, ERR_STRING, sizeof (ERR_STRING) - 1);
  if (virt_state_len)
    {
      memcpy (msg_box + sizeof (ERR_STRING) - 1, virt_state, virt_state_len - 2);
      memcpy (msg_box + sizeof (ERR_STRING) - 3 + virt_state_len, ": ", 2);
    }

  if (msg_len)
    memcpy (msg_box + sizeof (ERR_STRING) - 1 + virt_state_len, msg, msg_len);

  msg_box[sizeof (ERR_STRING) - 1 + virt_state_len + msg_len] = 0;
  rec->sql_state = box_string (state);
  rec->sql_error_msg = msg_box;
  rec->sql_error_col = col;

  return rec;
}

void
set_error_ext (sql_error_t * err, const char *state, const char *virt_state, const char *message, int col, int rc)
{
  if (NULL == state && NULL == message)
    {
      sql_error_rec_t *rec = err->err_queue;
      err->err_rc = SQL_SUCCESS;

      while (rec)
	{
	  sql_error_rec_t *next = rec->sql_error_next;
	  dk_free_box (rec->sql_state);
	  dk_free_box (rec->sql_error_msg);
	  dk_free ((caddr_t) rec, sizeof (sql_error_rec_t));
	  rec = next;
	}
      err->err_queue = NULL;
      err->err_queue_head = NULL;
    }
  else
    {
      sql_error_rec_t *rec = cli_make_error (state, virt_state, message, col);

      if (((unsigned int) err->err_rc) < ((unsigned int) rc))
	err->err_rc = rc;

      err_queue_append (&err->err_queue, &rec);
    }
}


void
set_error (sql_error_t * err, const char *state, const char *virt_state, const char *message)
{
  set_error_ext (err, state, virt_state, message, 0, SQL_ERROR);
}


void
set_success_info (sql_error_t * err, const char *state, const char *virt_state, const char *message, int col)
{
  set_error_ext (err, state, virt_state, message, col, SQL_SUCCESS_WITH_INFO);
}


void
set_data_truncated_success_info (cli_stmt_t *stmt, const char *virt_state, SQLUSMALLINT icol)
{
  char *base_col = NULL;
  char icol_buf[30];
  char base_tbl_col[MAX_QUAL_NAME_LEN + MAX_NAME_LEN + 20];
  char buf[MAX_QUAL_NAME_LEN + MAX_NAME_LEN + 100];
  int is_select = stmt->stmt_compilation && stmt->stmt_compilation->sc_is_select && (icol > 0);
  col_desc_t *jammed_col = NULL;
  char *alias_name = NULL;
  icol_buf[0] = '\0';
  base_tbl_col[0] = '\0';

  if (is_select)
    snprintf (icol_buf, sizeof (icol_buf), " in column %d of the result-set ", icol);

  if (is_select && BOX_ELEMENTS (stmt->stmt_compilation->sc_columns) >= icol)
    {
      jammed_col = (col_desc_t *) stmt->stmt_compilation->sc_columns[icol - 1];
      alias_name = jammed_col->cd_name;

      if (COL_DESC_IS_EXTENDED (jammed_col))
	{
	  base_col = jammed_col->cd_base_column_name;
	  if ((NULL != base_col) && (NULL != jammed_col->cd_base_table_name))
	    snprintf (base_tbl_col, sizeof (base_tbl_col),
		"\"%s\".\"%s\".\"%s\".\"%s\"", jammed_col->cd_base_schema_name,
		jammed_col->cd_base_catalog_name, jammed_col->cd_base_table_name, base_col);
	}
    }

  if ((NULL != base_col) && (NULL != alias_name) && !strcmp (base_col, alias_name))
    alias_name = NULL;

  if ('\0' != base_tbl_col[0])
    base_col = base_tbl_col;

  snprintf (buf, sizeof (buf), "Data truncated%s(%s%s%s, type %d)",
      icol_buf,
      ((NULL != base_col) ? base_col : ""),
      (((NULL != base_col) && (NULL != alias_name)) ? ", alias " : ""),
      ((NULL != alias_name) ? alias_name : ""), (int) ((NULL != jammed_col) ? jammed_col->cd_dtp : 0));

  set_success_info (&stmt->stmt_error, "01004", virt_state, buf, 0);
}


SQLRETURN
stmt_seq_error (cli_stmt_t * stmt)
{
  set_error (&stmt->stmt_error, "S1010", "CL063", "Async call in progress");

  return SQL_ERROR;
}


/* Handles the parameters bound either with
   SQLSetParam (always of the type SQL_PARAM_INPUT)
   or SQLBindParameter (type is either SQL_PARAM_INPUT, SQL_PARAM_OUTPUT,
   SQL_PARAM_INPUT_OUTPUT or SQL_RETURN_VALUE)
   (both are in wicli.c)
 */
void
stmt_set_proc_return (cli_stmt_t * stmt, caddr_t * res)
{
  long n_ret = BOX_ELEMENTS (res);
  int nth = (int) (stmt->stmt_parm_rows - stmt->stmt_parm_rows_to_go);
  parm_binding_t *pb;
  int inx = 2;

  if (stmt->stmt_return)
    {				/* If there has been SQL_RETURN_VALUE parameter given with
				   SQLBindParameter (in wicli.c) then handle it first */
      pb = stmt->stmt_return;
      dv_to_place (res[1], pb->pb_c_type, pb->pb_sql_type, pb->pb_max,
	  /* changed for ODBC 3 parameter offset. Original Line : pb->pb_place + nth * pb->pb_max_length, */
	  stmt_param_place_ptr (pb, nth, stmt, pb->pb_max_length), stmt_param_length_ptr (pb, nth, stmt), 0, stmt, -1, NULL);	/* Was: NULL */

    }

  pb = stmt->stmt_parms;
  while (pb)			/* Loop through the rest of the parameters. */
    {
      if (inx >= n_ret)
	break;

      if (pb->pb_param_type == SQL_PARAM_OUTPUT || pb->pb_param_type == SQL_PARAM_INPUT_OUTPUT)
	{
	  dv_to_place (res[inx], pb->pb_c_type, pb->pb_sql_type,
	      /* changed for ODBC 3 parameter offset. Original Line : pb->pb_max, pb->pb_place + nth * pb->pb_max_length, */
	      pb->pb_max, stmt_param_place_ptr (pb, nth, stmt, pb->pb_max_length),
	      stmt_param_length_ptr (pb, nth, stmt), 0, stmt, -1, NULL);
	}

      pb = pb->pb_next;
      inx++;
    }
}


#define STMT_IS_SELECT(stmt) \
	((stmt)->stmt_compilation && (stmt)->stmt_compilation->sc_is_select == QT_SELECT)


SQLRETURN
stmt_process_result (cli_stmt_t * stmt, int needs_evl)
{
  SQLRETURN rc = SQL_SUCCESS;
  stmt->stmt_is_proc_returned = 0;

  while (1)
    {
      caddr_t *res;
      int tag;

      cli_dbg_printf (("Before: Future = %p, res = %p, needs_evl=%d\n", stmt->stmt_future, res, needs_evl));

      cli_dbg_printf (("ft_request_no=%ld, ft_is_ready=%d, ft_error=%08lx,"
	      "ft_arguments=%08lx, ft_result=%08lx\n",
	      stmt->stmt_future->ft_request_no,
	      stmt->stmt_future->ft_is_ready,
	      ((unsigned long) stmt->stmt_future->ft_error),
	      ((unsigned long) stmt->stmt_future->ft_arguments), ((unsigned long) stmt->stmt_future->ft_result)));

      cli_dbg_printf (
	  ("stmt_n_rows_to_get=%d stmt_current_of=%d stmt_at_end=%d stmt_cursor_name=%s\n",
	      stmt->stmt_n_rows_to_get, stmt->stmt_current_of,
	      stmt->stmt_at_end, (stmt->stmt_cursor_name ? stmt->stmt_cursor_name : "NULL")));

      cli_dbg_printf (
	  ("ft_timeout=%lu,%lu ft_time_issued=%lu,%lu ft_time_received=%lu,%lu time_now=%lu,%lu\n",
	      stmt->stmt_future->ft_timeout.to_sec,
	      stmt->stmt_future->ft_timeout.to_usec,
	      stmt->stmt_future->ft_time_issued.to_sec,
	      stmt->stmt_future->ft_time_issued.to_usec,
	      stmt->stmt_future->ft_time_received.to_sec,
	      stmt->stmt_future->ft_time_received.to_usec, time_now.to_sec, time_now.to_usec));

      if (DKSESSTAT_ISSET (stmt->stmt_connection->con_session, SST_BROKEN_CONNECTION))
	{
	  set_error (&stmt->stmt_error, "08S01", "CL064", "Lost connection to server");

	  return SQL_ERROR;
	}

      stmt->stmt_co_last_in_batch = 0;
      res = (caddr_t *) PrpcFutureNextResult (stmt->stmt_future);

      if (DKSESSTAT_ISSET (stmt->stmt_connection->con_session, SST_BROKEN_CONNECTION))
	{
	  set_error (&stmt->stmt_error, "08S01", "CL065", "Lost connection to server");

	  return SQL_ERROR;
	}

      if (stmt->stmt_future->ft_error)
	{
	  set_error (&stmt->stmt_error, "S1T00", "CL066", "Virtuoso Communications Link Failure (timeout)");

	  return SQL_ERROR;
	}

      cli_dbg_printf (
	  ("ft_timeout=%lu,%lu ft_time_issued=%lu,%lu ft_time_received=%lu,%lu time_now=%lu,%lu\n",
	      stmt->stmt_future->ft_timeout.to_sec,
	      stmt->stmt_future->ft_timeout.to_usec,
	      stmt->stmt_future->ft_time_issued.to_sec,
	      stmt->stmt_future->ft_time_issued.to_usec,
	      stmt->stmt_future->ft_time_received.to_sec,
	      stmt->stmt_future->ft_time_received.to_usec, time_now.to_sec, time_now.to_usec));

      cli_dbg_printf (("After: Future = %p, res = %p\n", stmt->stmt_future, res));

      cli_dbg_printf (
	  ("ft_request_no=%ld, ft_is_ready=%d, ft_error=%08lx, ft_arguments=%08lx, ft_result=%08lx\n",
	      stmt->stmt_future->ft_request_no, stmt->stmt_future->ft_is_ready,
	      ((unsigned long) stmt->stmt_future->ft_error),
	      ((unsigned long) stmt->stmt_future->ft_arguments), ((unsigned long) stmt->stmt_future->ft_result)));

      cli_dbg_printf (
	  ("stmt_n_rows_to_get=%d stmt_current_of=%d stmt_at_end=%d stmt_cursor_name=%s\n",
	      stmt->stmt_n_rows_to_get, stmt->stmt_current_of,
	      stmt->stmt_at_end, (stmt->stmt_cursor_name ? stmt->stmt_cursor_name : "NULL")));

      if (DKSESSTAT_ISSET (stmt->stmt_connection->con_session, SST_BROKEN_CONNECTION))
	{
	  set_error (&stmt->stmt_error, "08S01", "CL067", "Lost connection to server");
	  return SQL_ERROR;
	}
      if (IS_BOX_POINTER (res) && ((ptrlong *) res)[0] == QA_ROWS_AFFECTED)
	{
	  /* Number of affected rows is known so start with 0 */
 	  if (stmt->stmt_rows_affected == -1)
	    stmt->stmt_rows_affected = 0;

	  stmt->stmt_rows_affected += (SDWORD) unbox (((caddr_t *) res)[1]);
	  if (BOX_ELEMENTS (res) > 2)
	    {
	      dk_free_box (stmt->stmt_identity_value);
	      stmt->stmt_identity_value = ((caddr_t *) res)[2];
	      ((caddr_t *) res)[2] = NULL;	/* prior to free */
	    }

	  dk_free_tree ((caddr_t) res);
	  res = (caddr_t *) (ptrlong) rc;	/* oui's change 1-NOV-1997? */
	}

      if (res == (caddr_t *) SQL_NO_DATA_FOUND)
	{
	  stmt->stmt_at_end = 1;
	  return SQL_NO_DATA_FOUND;
	}

      if (!IS_BOX_POINTER (res))
	{
#if 0				/*GK: why ? */
	  set_error (&stmt->stmt_error, NULL, NULL, NULL);
#endif
	  if (!stmt->stmt_compilation || stmt->stmt_compilation->sc_is_select != QT_PROC_CALL)
	    {
	      stmt->stmt_at_end = 1;
	      if (stmt->stmt_parm_rows_to_go &&
		  (!(STMT_IS_SELECT (stmt) &&
			  SQL_CURSOR_FORWARD_ONLY == stmt->stmt_opts->so_cursor_type) || stmt->stmt_on_first_row))
		{
		  stmt->stmt_parm_rows_to_go--;
		  if (stmt->stmt_pirow)
		    *(stmt->stmt_pirow) = stmt->stmt_parm_rows - stmt->stmt_parm_rows_to_go;
		  if (stmt->stmt_param_status)
		    stmt->stmt_param_status[stmt->stmt_parm_rows - stmt->stmt_parm_rows_to_go - 1] = SQL_PARAM_SUCCESS;
		}

	      if (stmt->stmt_compilation->sc_is_select == QT_SELECT)
		return SQL_NO_DATA_FOUND;

	      /* Number of affected rows is known so start with 0 */
	      if (stmt->stmt_rows_affected < 0)
		stmt->stmt_rows_affected = 0;

	      if (stmt->stmt_parm_rows_to_go)
		continue;
	      else
		return rc;
	    }
	  else
	    {
	      /* proc call. Result set ends, proc not returned. */
	      stmt->stmt_at_end = 1;
	      return SQL_NO_DATA_FOUND;
	    }
	}

      tag = (int) (ptrlong) res[0];
      switch (tag)
	{
	case QA_PROC_RETURN:
	  stmt_set_proc_return (stmt, res);
	  dk_free_tree ((caddr_t) res);
	  if (stmt->stmt_parm_rows_to_go)
	    {
	      stmt->stmt_parm_rows_to_go--;

	      if (stmt->stmt_pirow)
		*(stmt->stmt_pirow) = stmt->stmt_parm_rows - stmt->stmt_parm_rows_to_go;
	    }

	  stmt->stmt_at_end = 1;
	  stmt->stmt_is_proc_returned = 1;

	  if (0 == stmt->stmt_parm_rows_to_go)
	    {
	      if (stmt->stmt_param_status)
		stmt->stmt_param_status[stmt->stmt_parm_rows - stmt->stmt_parm_rows_to_go - 1] = SQL_PARAM_SUCCESS;

	      set_error (&stmt->stmt_error, NULL, NULL, NULL);

	      return rc;
	    }
	  else
	    {
	      if (stmt->stmt_param_status)
		stmt->stmt_param_status[stmt->stmt_parm_rows - stmt->stmt_parm_rows_to_go - 1] = SQL_PARAM_SUCCESS_WITH_INFO;

	      set_error (&stmt->stmt_error, "01000", "CL068", "Non last proc w/array params returned");

	      return SQL_SUCCESS_WITH_INFO;
	    }

	case QA_COMPILED:
	  dk_free_tree ((caddr_t) stmt->stmt_compilation);
	  stmt->stmt_compilation = ((stmt_compilation_t **) res)[1];
	  dk_free_box ((box_t) res);

	  if (stmt->stmt_opts->so_unique_rows && stmt->stmt_compilation != NULL && stmt->stmt_compilation->sc_columns != NULL)
	    {
	      int i, n, found_key = 0;
	      n = BOX_ELEMENTS (stmt->stmt_compilation->sc_columns);
	      for (i = 0; i < n; i++)
		{
		  col_desc_t *cd = (col_desc_t *) stmt->stmt_compilation->sc_columns[i];

		  if (COL_DESC_IS_EXTENDED (cd) && (unbox (cd->cd_flags) & CDF_KEY))
		    {
		      found_key = 1;
		      break;
		    }
		}
	      stmt->stmt_opts->so_unique_rows = found_key;
	    }

	  if (needs_evl)
	    {
	      SQLRETURN rc1 = stmt_process_result (stmt, 1);
	      return rc1 == SQL_SUCCESS ? rc : rc1;
	    }

	  set_error (&stmt->stmt_error, NULL, NULL, NULL);

	  return rc;

	case QA_ERROR:
	  if (stmt->stmt_parm_rows_to_go)
	    {
	      if (stmt->stmt_pirow)
		*(stmt->stmt_pirow) = stmt->stmt_parm_rows - stmt->stmt_parm_rows_to_go;

	      stmt->stmt_parm_rows_to_go--;

	      if (stmt->stmt_param_status)
		stmt->stmt_param_status[stmt->stmt_parm_rows - stmt->stmt_parm_rows_to_go - 1] = SQL_PARAM_ERROR;
	    }

	  stmt->stmt_at_end = 1;
	  {
	    caddr_t srv_msg = cli_box_server_msg (res[2]);
	    set_error (&stmt->stmt_error, res[1], NULL, srv_msg);
	    dk_free_box (srv_msg);
	  }
	  dk_free_tree ((box_t) res);

          /* In case of SQLSetPos returning SQL_ERROR */
	  if (stmt->stmt_compilation &&
	      QT_SELECT != stmt->stmt_compilation->sc_is_select &&
	      stmt->stmt_rows_affected == -1)
	      stmt->stmt_rows_affected = 0;

	  return SQL_ERROR;

	case QA_WARNING:
	  {
	    caddr_t srv_msg = cli_box_server_msg (res[2]);
	    set_success_info (&stmt->stmt_error, res[1], NULL, srv_msg, 0);
	    dk_free_box (srv_msg);
	  }
	  dk_free_tree ((box_t) res);
	  rc = SQL_SUCCESS_WITH_INFO;

	  continue;

	case QA_ROW_LAST_IN_BATCH:
	  stmt->stmt_co_last_in_batch = 1;

	case QA_ROW:
	case QA_ROW_ADDED:
	case QA_ROW_UPDATED:
	case QA_ROW_DELETED:
/*
	  if (stmt->stmt_parm_rows_to_go &&
	      SQL_CURSOR_FORWARD_ONLY == stmt->stmt_opts->so_cursor_type &&
	      STMT_IS_SELECT (stmt) &&
	      stmt->stmt_on_first_row)
	    {
	      if (stmt->stmt_param_status)
		stmt->stmt_param_status[stmt->stmt_parm_rows -
		    stmt->stmt_parm_rows_to_go] = SQL_PARAM_SUCCESS;
	      stmt->stmt_parm_rows_to_go--;
	      if (stmt->stmt_pirow)
		*(stmt->stmt_pirow) = stmt->stmt_parm_rows -
		    stmt->stmt_parm_rows_to_go;
	      stmt->stmt_on_first_row = 0;
	    }
*/
	  dk_free_tree (stmt->stmt_prefetch_row);
	  stmt->stmt_prefetch_row = (caddr_t) res;
	  set_error (&stmt->stmt_error, NULL, NULL, NULL);
	  stmt->stmt_at_end = 0;
	  stmt->stmt_on_first_row = 1;

	  return rc;

	case QA_NEED_DATA:
	  stmt->stmt_last_asked_param = (SDWORD) unbox (res[1]);
	  dk_free_tree ((caddr_t) res);

	  return SQL_NEED_DATA;

	case QA_LOGIN:
	  {
	    cli_connection_t *con = stmt->stmt_connection;
	    con->con_qualifier = (SQLCHAR *) res[LG_QUALIFIER];
	    dk_free_box ((caddr_t) res);
	  }
	}
    }
}


#if 0
void
stmt_check_at_end (cli_stmt_t * stmt)
{
  if (stmt->stmt_future && PrpcFutureIsResult (stmt->stmt_future))
    stmt_process_result (stmt, 0);
}
#endif


cli_stmt_t *
con_find_cursor (cli_connection_t * con, caddr_t id)
{
  DO_SET (cli_stmt_t *, cr, &con->con_statements)
  {
    if (cr->stmt_cursor_name && 0 == strcmp (cr->stmt_cursor_name, id))
      return cr;
  }
  END_DO_SET ();
  return NULL;
}


caddr_t
con_make_current_ofs (cli_connection_t * con, cli_stmt_t * stmt)
{
  dk_set_t res = NULL;
  caddr_t arr;
  IN_CON (con);
  DO_SET (cli_stmt_t *, cr, &con->con_statements)
  {
    if (cr->stmt_compilation
	&& cr->stmt_compilation->sc_is_select && cr->stmt_cursor_name && cr->stmt_current_of != -1 && !cr->stmt_at_end)
      {
	dk_set_push (&res, (void *) box_num (cr->stmt_current_of));
	dk_set_push (&res, (void *) cr->stmt_cursor_name);
      }
  }
  END_DO_SET ();
  LEAVE_CON (con);
  arr = (caddr_t) dk_set_to_array (res);
  dk_set_free (res);
  return arr;
}


#define TS ":. -/;,"

#define CKSTR(s) (s ? s : "0")


caddr_t
buffer_to_bin_dv (char * place, SQLLEN * len, int sql_type)
{
  dtp_t dtp = 0;
  SQLLEN data_len = -1;
  caddr_t res;
  SQLLEN len1 = len ? *len : SQL_NTS;

  if (SQL_NTS == len1)
    len1 = strlen (place);

  switch (sql_type)
    {
#if (ODBCVER >= 0x0300)
    case SQL_TYPE_TIMESTAMP:
    case SQL_TYPE_DATE:
    case SQL_TYPE_TIME:
#endif
    case SQL_TIMESTAMP:
    case SQL_DATE:
    case SQL_TIME:
      data_len = DT_LENGTH;
      dtp = DV_DATETIME;
      break;

    case SQL_INTEGER:
      data_len = sizeof (long);
      dtp = DV_LONG_INT;
      break;

    case SQL_REAL:
      data_len = sizeof (float);
      dtp = DV_SINGLE_FLOAT;
      break;

    case SQL_DOUBLE:
    case SQL_FLOAT:
      data_len = sizeof (double);
      dtp = DV_DOUBLE_FLOAT;
      break;

    case SQL_NUMERIC:
    case SQL_DECIMAL:
      data_len = _numeric_size ();
      dtp = DV_NUMERIC;
      break;

    case SQL_VARCHAR:
      res = dk_alloc_box (len1 + 1, DV_LONG_STRING);
      memcpy (res, place, len1);
      res[len1] = 0;
      return res;

    case SQL_BINARY:
    default:
      res = dk_alloc_box (len1, DV_BIN);
      memcpy (res, place, len1);
      return res;
    }

  res = dk_alloc_box (data_len, dtp);
  memcpy (res, place, DT_LENGTH);

  return res;
}


caddr_t numeric_struct_to_nt (SQL_NUMERIC_STRUCT * ns);

caddr_t
buffer_to_dv (caddr_t place, SQLLEN * len, int c_type, int sql_type, long bhid,
	      cli_stmt_t * err_stmt, int inprocess)
{
  if (len && (SQL_NULL_DATA == *len || SQL_IGNORE == *len))
    return dk_alloc_box (0, DV_DB_NULL);

  if (len && (*len == SQL_DATA_AT_EXEC || *len <= SQL_LEN_DATA_AT_EXEC_OFFSET))
    {
      if (!inprocess && (SQL_LONGVARCHAR == sql_type || SQL_LONGVARBINARY == sql_type || SQL_WLONGVARCHAR == sql_type))
	{
	  blob_handle_t *bh = bh_alloc ((sql_type == SQL_WLONGVARCHAR) ? DV_BLOB_WIDE_HANDLE : DV_BLOB_HANDLE);

	  bh->bh_ask_from_client = 1;
	  bh->bh_param_index = bhid;

	  return (caddr_t) bh;
	}
      else
	{
	  caddr_t temp = dk_alloc_box (sizeof (long), DV_DAE);
	  ((long *) temp)[0] = bhid;

	  return temp;
	}
    }

  switch (c_type)
    {
    case SQL_C_LONG:
    case SQL_C_SLONG:
    case SQL_C_ULONG:
      return box_num (*(long *) place);

    case SQL_C_SHORT:
    case SQL_C_SSHORT:
      return box_num (*(short *) place);

    case SQL_C_USHORT:
      return box_num (*(unsigned short *) place);

    case SQL_C_FLOAT:
    case SQL_FLOAT:
      return box_float (*(float *) place);

    case SQL_C_BIT:
      return box_num (*(char *) place);

    case SQL_C_DOUBLE:
      return box_double (*(double *) place);

    case SQL_C_BOX:
      return (box_copy_tree (*(caddr_t *) place));

    case SQL_C_NUMERIC:
      return numeric_struct_to_nt ((SQL_NUMERIC_STRUCT *) place);

#if (ODBCVER >= 0x0300)
    case SQL_C_TYPE_TIMESTAMP:
#endif
    case SQL_C_TIMESTAMP:
      {
	TIMESTAMP_STRUCT *par_ts = (TIMESTAMP_STRUCT *) place;
	caddr_t dv = dk_alloc_box (DT_LENGTH, DV_DATETIME);

	timestamp_struct_to_dt (par_ts, dv);

	return dv;
      }

#if (ODBCVER >= 0x0300)
    case SQL_C_TYPE_DATE:
#endif
    case SQL_C_DATE:
      {
	DATE_STRUCT *par_ts = (DATE_STRUCT *) place;
	caddr_t dv = dk_alloc_box (DT_LENGTH, DV_DATETIME);

	date_struct_to_dt (par_ts, dv);

	return dv;
      }

#if (ODBCVER >= 0x0300)
    case SQL_C_TYPE_TIME:
#endif
    case SQL_C_TIME:
      {
	caddr_t dv = dk_alloc_box (DT_LENGTH, DV_DATETIME);

	time_struct_to_dt ((TIME_STRUCT *) place, dv);

	return dv;
      }

    case SQL_C_BINARY:
      return buffer_to_bin_dv (place, len, sql_type);

    case SQL_C_WCHAR:
      {
	char temp[100];
	long nlen = (long) (len ? (*len >= 0 ? *len / sizeof (wchar_t) : wcslen ((wchar_t *) place)) : wcslen ((wchar_t *) place));

	switch (sql_type)
	  {
#if (ODBCVER >= 0x0300)
	  case SQL_TYPE_TIMESTAMP:
	  case SQL_TYPE_DATE:
	  case SQL_TYPE_TIME:
#endif
	  case SQL_TIMESTAMP:
	  case SQL_DATE:
	  case SQL_TIME:
	    {
              caddr_t err_msg = NULL;
	      caddr_t res = dk_alloc_box (DT_LENGTH, DV_DATETIME);

	      nlen = nlen > 100 ? 100 : nlen;
	      cli_wide_to_narrow (err_stmt->stmt_connection->con_charset,
		  0, (wchar_t *) place, nlen, (unsigned char *) temp, nlen, NULL, NULL);

	      odbc_string_to_any_dt (temp, res, &err_msg);
              if (NULL != err_msg)
		{
		  char err_buf[1000];
		  snprintf (err_buf, sizeof (err_buf), "Cannot convert the wide string to date/time : %s", err_msg);
                  dk_free_box (err_msg);
		  set_error (&err_stmt->stmt_error, "S1010", "CL095", err_buf);
		  dk_free_box (res);
		  return NULL;
		}

	      return res;
	    }

	  case SQL_NUMERIC:
	  case SQL_DECIMAL:
	    {			/* E.g. SQL_C_CHAR, SQL_C_BINARY, any other. */
	      nlen = nlen > 100 ? 100 : nlen;
	      cli_wide_to_narrow (err_stmt->stmt_connection->con_charset, 0,
		  (wchar_t *) place, nlen, (unsigned char *) temp, nlen, NULL, NULL);

	      return box_numeric_string ((SQLCHAR *) temp, nlen);
	    }

	  case SQL_SMALLINT:
	  case -7:
	  case SQL_INTEGER:
	    {
#if defined (__APPLE__)
	      char tmp[100];
	      cli_wide_to_narrow (NULL, 0, (wchar_t *) place, 100, tmp, sizeof (tmp), "?", NULL);

	      return (box_num (atoi (tmp)));
#else
	      long n = wcstol ((wchar_t *) place, (wchar_t **) NULL, 10);

	      return (box_num (n));
#endif
	    }

	  case SQL_FLOAT:
	  case SQL_REAL:
	  case SQL_DOUBLE:
	    {
#if defined (__APPLE__)
	      char tmp[100];
	      double d = 0;
	      cli_wide_to_narrow (NULL, 0, (wchar_t *) place, 100, tmp, sizeof (tmp), "?", NULL);
	      sscanf (tmp, "%lg", &d);

	      return (box_double (d));
#else
	      double d = wcstod ((wchar_t *) place, (wchar_t **) NULL);

	      return (box_double (d));
#endif
	    }

	  case SQL_CHAR:
	  case SQL_VARCHAR:
	  case SQL_LONGVARCHAR:
	    {
	      caddr_t res = dk_alloc_box (nlen + 1, DV_LONG_STRING);
	      cli_wide_to_narrow (err_stmt->stmt_connection->con_charset, 0,
		  (wchar_t *) place, nlen, (unsigned char *) res, nlen + 1, NULL, NULL);
	      res[nlen] = 0;

	      return res;
	    }

	  case SQL_BINARY:
	    {
	      caddr_t res;
	      res = dk_alloc_box (nlen * sizeof (wchar_t), DV_BIN);
	      memcpy (res, place, nlen * sizeof (wchar_t));

	      return res;
	    }

	  default:
	    return box_n_wstring ((wchar_t *) place, nlen);
	  }
      }

    case SQL_C_CHAR:
      switch (sql_type)
	{
#if (ODBCVER >= 0x0300)
	case SQL_TYPE_TIMESTAMP:
	case SQL_TYPE_DATE:
	case SQL_TYPE_TIME:
#endif
	case SQL_TIMESTAMP:
	case SQL_DATE:
	case SQL_TIME:
	  {
	    caddr_t res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
	    caddr_t err_msg = NULL;
	    odbc_string_to_any_dt (place, res, &err_msg);
            if (NULL != err_msg)
	      {
		char err_buf[1500];
		snprintf (err_buf, sizeof (err_buf), "Cannot convert the string \"%.500s\" to date/time: %s", place, err_msg);
                dk_free_box (err_msg);
		set_error (&err_stmt->stmt_error, "S1010", "CL096", err_buf);
		dk_free_box (res);

		return NULL;
	      }

	    return res;
	  }

	case SQL_NUMERIC:
	case SQL_DECIMAL:
	  {			/* E.g. SQL_C_CHAR, SQL_C_BINARY, any other. */
	    return box_numeric_string ((SQLCHAR *) place, len ? *len : SQL_NTS);
	  }

	case SQL_SMALLINT:
	case -7:
	case SQL_INTEGER:
	  {
	    long n = atoi (place);

	    return (box_num (n));
	  }

	case SQL_FLOAT:
	case SQL_DOUBLE:
	  {
	    double d = 0;

	    sscanf (place, "%lg", &d);

	    return (box_double (d));
	  }

	case SQL_REAL:
	  {
	    float f = 0;

	    sscanf (place, "%g", &f);

	    return (box_double (f));
	  }

	case SQL_WCHAR:
	case SQL_WVARCHAR:
	case SQL_WLONGVARCHAR:
	  {
	    SQLLEN box_len = len ? *len : SQL_NTS;
	    caddr_t res;

	    if (box_len == SQL_NTS)
	      box_len = wcslen ((wchar_t *) place);

	    res = dk_alloc_box ((box_len + 1) * sizeof (wchar_t), DV_WIDE);
	    cli_narrow_to_wide (err_stmt->stmt_connection->con_charset, 0,
		(unsigned char *) place, box_len, (wchar_t *) res, box_len + 1);
/*	    ((wchar_t *)res)[box_len] = 0; */

	    return res;
	  }

	case SQL_BINARY:
	  {
	    SQLLEN len1 = len ? *len : SQL_NTS;
	    caddr_t res;

#ifndef MAP_DIRECT_BIN_CHAR
	    unsigned char *ptr, *src = (unsigned char *) place, _lo, _hi, chr;
#endif

	    if (SQL_NTS == len1)
	      len1 = strlen (place);

#ifndef MAP_DIRECT_BIN_CHAR
	    if (len1 % 2)
	      {
		set_error (&err_stmt->stmt_error, "22002", "CL069",
		    "Invalid (odd) length in conversion from SQL_C_CHAR to SQL_BINARY");
		return NULL;
	      }

	    for (src = (unsigned char *) place; src - ((unsigned char *) place) < len1; src++)
	      {
		chr = toupper (*src);
		if ((chr < '0' || chr > '9') && (chr < 'A' || chr > 'F'))
		  {
		    set_error (&err_stmt->stmt_error, "S1010", "CL070",
			"Invalid buffer length (even) in passing character data to binary column in SQLPutData");
		    return NULL;
		  }
	      }

	    res = dk_alloc_box (len1 / 2, DV_BIN);
	    for (src = (unsigned char *) place, ptr = (unsigned char *) res;
		src - ((unsigned char *) place) < len1; src += 2, ptr++)
	      {
		_lo = toupper (src[1]);
		_hi = toupper (src[0]);
		*ptr = ((_hi - (_hi <= '9' ? '0' : 'A' + 10)) << 4) | (_lo - (_lo <= '9' ? '0' : 'A' + 10));
	      }
#else
	    res = dk_alloc_box (len1, DV_BIN);
	    memcpy (res, place, len1);
#endif
	    return res;
	  }
	}

      /* Otherwise fall through to the next (default) clause */

    default:
      if (len && *len > 10000000)
	{
	  set_error (&err_stmt->stmt_error, "S1010", "CL091", "Invalid buffer length (>10M) in passing character data to column");
	  return NULL;
	}
      else
	return box_n_string ((SQLCHAR *) place, len ? *len : SQL_NTS);
    }
}


SQLULEN
sqlc_sizeof (int sqlc, SQLULEN deflt)
{
  switch (sqlc)
    {

    case SQL_C_LONG:
    case SQL_C_SLONG:
    case SQL_C_ULONG:
      return sizeof (long);

    case SQL_C_SHORT:
    case SQL_C_SSHORT:
    case SQL_C_USHORT:
      return sizeof (short);

    case SQL_C_FLOAT:
    case SQL_FLOAT:
      return sizeof (float);

    case SQL_C_BIT:
      return 1;

    case SQL_C_DOUBLE:
      return sizeof (double);

    case SQL_C_BOX:
      return sizeof (caddr_t);

    case SQL_C_TIMESTAMP:
      return sizeof (TIMESTAMP_STRUCT);

    case SQL_C_DATE:
      return sizeof (DATE_STRUCT);

    case SQL_C_TIME:
      return sizeof (TIME_STRUCT);

    default:
      return deflt;
    }
}


caddr_t
stmt_parm_to_dv (parm_binding_t * pb, int nth, long bhid, cli_stmt_t *stmt)
{
  caddr_t place = stmt_param_place_ptr (pb, nth, stmt,
      sqlc_sizeof (pb->pb_c_type, pb->pb_max_length));
  SQLLEN *len = stmt_param_length_ptr (pb, nth, stmt);

  if (SQL_PARAM_OUTPUT == pb->pb_param_type || SQL_RETURN_VALUE == pb->pb_param_type)
    return NULL;

  if (place || (len &&
	  (SQL_NULL_DATA == *len || SQL_IGNORE == *len || *len == SQL_DATA_AT_EXEC || *len <= SQL_LEN_DATA_AT_EXEC_OFFSET)))
    return (buffer_to_dv (place, len, pb->pb_c_type, pb->pb_sql_type, bhid, stmt, CON_IS_INPROCESS (stmt->stmt_connection)));
  else
    return NULL;
}


/* Called by SQLExecDirect and SQLExecute in wicli.c */
caddr_t *
stmt_collect_parms (cli_stmt_t * stmt)
{
  caddr_t **arr = (caddr_t **) dk_alloc_box (stmt->stmt_parm_rows * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  int inx;
  int parm_count = 0;
  parm_binding_t *pb = stmt->stmt_parms;

  while (pb)
    {
      parm_count++;
      pb = pb->pb_next;
    }

  if (stmt->stmt_compilation && stmt->stmt_compilation->sc_params)
    {
      int parms_len = BOX_ELEMENTS (stmt->stmt_compilation->sc_params);
      if (parm_count > parms_len)
	parm_count = parms_len;
    }

  for (inx = 0; inx < (int) stmt->stmt_parm_rows; inx++)
    {
      caddr_t *row = (caddr_t *) dk_alloc_box (parm_count * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      int iparm = 0;

      arr[inx] = row;
      pb = stmt->stmt_parms;

      while (pb && iparm < parm_count)
	{
	  caddr_t v = stmt_parm_to_dv (pb, inx, BHID (inx, iparm + 1), stmt);
	  row[iparm] = v;

	  if (IS_BOX_POINTER (v) && DV_DAE == box_tag (v))
	    dk_set_push (&stmt->stmt_dae, (void *) &row[iparm]);

	  iparm++;
	  pb = pb->pb_next;
	}
    }

  return ((caddr_t *) arr);
}


SQLRETURN
str_box_to_buffer (
  char *box,
  char *buffer,
  int buffer_length,
  void *string_length_ptr,
  int length_is_long,
  sql_error_t *error
)
{
  SQLRETURN rc = SQL_SUCCESS;

  if (buffer_length < 0)
    {
      set_error (error, "HY090", "CL086", "Invalid buffer length (a negative value).");
      rc = SQL_ERROR;
    }
  else if (box != NULL)
    {
      int len = box_length (box) - 1;

      if (buffer != NULL)
	{
	  if (len < buffer_length)
	    memcpy (buffer, box, len + 1);
	  else
	    {
	      char msg_buf[100];

	      if (buffer_length > 0)
		{
		  memcpy (buffer, box, buffer_length - 1);
		  buffer[buffer_length - 1] = 0;
		}

	      snprintf (msg_buf, sizeof (msg_buf), "Data truncated (string is %d bytes long, buffer is only %d bytes long)", len + 1, buffer_length);

	      set_success_info (error, "01004", "CL087", msg_buf, 0);
	      rc = SQL_SUCCESS_WITH_INFO;
	    }
	}

      if (string_length_ptr != NULL)
	{
	  if (length_is_long)
	    *(SDWORD *) string_length_ptr = len;
	  else
	    *(SQLSMALLINT *) string_length_ptr = len;
	}
    }
  else
    {
      if (buffer != NULL)
	{
	  if (buffer_length > 0)
	    buffer[0] = 0;
	  else			/*if (buffer_length == 0) */
	    {
	      set_success_info (error, "01004", "CL088", "Data truncated (buffer for a string is 0 bytes long).", 0);
	      rc = SQL_SUCCESS_WITH_INFO;
	    }
	}

      if (string_length_ptr != NULL)
	{
	  if (length_is_long)
	    *(SDWORD *) string_length_ptr = 0;
	  else
	    *(SQLSMALLINT *) string_length_ptr = 0;
	}
    }

  return rc;
}


void
str_box_to_place (char *box, char *place, int max, int *sz)
{
  if (!box)
    {
      *place = 0;
      if (sz)
	*sz = 0;
    }
  else
    {
      int len = box_length (box) - 1;

      if (max < 1)
	max = 1;

      if (len > max - 1)
	len = max - 1;

      memcpy (place, box, len);
      place[len] = 0;

      if (sz)
	*sz = len;
    }
}


int
dv_to_sqlc_default (caddr_t xx)
{
  if (!IS_BOX_POINTER (xx))
    return SQL_C_LONG;

  switch (box_tag (xx))
    {
    case DV_LONG_INT:
      return SQL_C_LONG;

    case DV_STRING:
      return SQL_C_CHAR;

    case DV_SINGLE_FLOAT:
      return SQL_C_FLOAT;

    case DV_DOUBLE_FLOAT:
      return SQL_C_DOUBLE;

    case DV_NUMERIC:
      return SQL_C_CHAR;

    case DV_DATETIME:
      return SQL_C_TIMESTAMP;

    case DV_BIN:
      return SQL_C_BINARY;

    case DV_WIDE:
    case DV_LONG_WIDE:
    case DV_BLOB_WIDE:
      return SQL_C_WCHAR;
    }

/* IvAn/DvBlobXper/001212 DV_BLOB and DV_BLOB_XPER are both handled here: */
  return SQL_C_CHAR;
}


/* It should be guaranteed that dest_size is greater than zero when this
   is called, otherwise catastrophe will occur.
   &dest[dest_size-1] points to the last available character in dest.

   Returns non-zero if the resulting text was truncated.
 */
int
vector_to_text (caddr_t vec, size_t box_len, dtp_t vectype, char *dest, size_t dest_size)
{
  size_t n_elems = (box_len / get_itemsize_of_vector (vectype));
  const char *sprintf_formatter = get_sprintf_formatter_of_vector (vectype);
  int margin = 50;		/* What's the max. total width for double float? +1 for comma */
  unsigned long int inx = 0;
  size_t templen, copylen;
  int truncated = 0;
  char *dest_ptr = dest;
  char own_temp[100];

/*  dest_ptr[dest_size-1] = '\0'; */
  snprintf (own_temp, sizeof (own_temp), "%svector(", get_prefixletter_of_vector (vectype));

  templen = strlen (own_temp);
  copylen = ((dest + dest_size - 1) - dest_ptr);

  if (templen < copylen)
    {
      copylen = templen;
    }

  memcpy (dest_ptr, own_temp, copylen);
  dest_ptr += copylen;
  *dest_ptr = '\0';

  while ((inx < n_elems) && (dest_ptr < (dest + dest_size - margin)))
    {
      if (inx > 0)
	{
	  *dest_ptr++ = ',';
	}			/* Separating comma. */

      sprintf_vecitem (dest_ptr, (size_t)(dest_size - (dest_ptr - dest)), sprintf_formatter, vec, vectype, inx);
      inx++;
      dest_ptr += strlen (dest_ptr);
    }

  if (inx < n_elems)		/* This adds max 11+10 chars, plus trailing ) */
    {
      /* 12345678901 10  margin depends also on this. */
      snprintf (own_temp, sizeof (own_temp), ",TRUNC.LEN=%lu", (unsigned long) n_elems);
      templen = strlen (own_temp);

      /*    Or: ((dest_size-1)-(dest_ptr-dest)) */
      copylen = ((dest + dest_size - 1) - dest_ptr);

      if (templen < copylen)
	{
	  copylen = templen;
	}

      memcpy (dest_ptr, own_temp, copylen);
      dest_ptr += copylen;
      *dest_ptr = '\0';
      truncated = 1;
    }

  /* Closing parenthesis, and the terminating zero. */
  if (dest_ptr <= (dest + (dest_size - 2)))
    {
      *dest_ptr++ = ')';
    }
  else
    {
      truncated = 1;
    }

  if (dest_ptr <= (dest + (dest_size - 1)))
    {
      *dest_ptr = '\0';
    }
  else
    {
      truncated = 1;
    }

  return (truncated || (inx < n_elems));	/* Truncated or not? */
}


#ifndef MAP_DIRECT_BIN_CHAR
# ifdef ROLLBACK_XQ

void
bin_dv_to_str_place (unsigned char *str, char *place, size_t nbytes)
{
  unsigned char *ptr;

  for (ptr = str; ((size_t) (ptr - str)) < nbytes; ptr++, place += 2)
    {
      place[0] = ((*ptr & 0xF0) >> 4) + ((((*ptr & 0xF0) >> 4) < 10) ? '0' : 'A' - 10);
      place[1] = (*ptr & 0x0F) + (((*ptr & 0x0F) < 10) ? '0' : 'A' - 10);
    }
}


void
bin_dv_to_wstr_place (unsigned char *str, wchar_t *place, size_t nbytes)
{
  unsigned char *ptr;

  for (ptr = str; ((size_t) (ptr - str)) < nbytes; ptr++, place += 2)
    {
      place[0] = ((*ptr & 0xF0) >> 4) + ((((*ptr & 0xF0) >> 4) < 10) ? L'0' : L'A' - 10);
      place[1] = (*ptr & 0x0F) + (((*ptr & 0x0F) < 10) ? L'0' : L'A' - 10);
    }
}

# else

void
bin_dv_to_str_place (unsigned char *str, char *place, size_t nbytes)
{
  unsigned char *tail = str, *end = str + nbytes;

  while (tail < end)
    {
      (place++)[0] = "0123456789ABCDEF"[(tail[0] >> 4) & 0xF];
      (place++)[0] = "0123456789ABCDEF"[(tail++)[0] & 0xF];
    }
}


void
bin_dv_to_wstr_place (unsigned char *str, wchar_t *place, size_t nbytes)
{
  unsigned char *tail = str, *end = str + nbytes;

  while (tail < end)
    {
      (place++)[0] = L"0123456789ABCDEF"[(tail[0] >> 4) & 0xF];
      (place++)[0] = L"0123456789ABCDEF"[(tail++)[0] & 0xF];
    }
}

# endif
#endif


/* Returns the length of piece copied, usually the same as
   the whole length stored to *len_ret.
   With blobs stores the length to *len_ret and returns the length of blob,
   but does not try to fetch the blob in.
   If c_type is not SQL_C_CHAR (e.g. SQL_C_BINARY or SQL_C_OID) then
   copies the whole box.
   With SQL_C_BINARY copies also the terminating byte '\0' into the
   result (as opposed to previous implementation where termination
   byte was not included), with SQL_C_BINARY stores the length of
   whole box into len_ret, in contrast to SQL_C_CHAR in which case
   stores there a value which is one less. (terminating byte '\0'
   excluded).

   13-MAR-1997 AK  Changed back to the habit of excluding the termination
   byte '\0' from the copied stuff and from the length of it when copying
   stuff in SCL_C_BINARY format.

   Note how in *len_ret is always returned the original length of dv data
   (possibly - 1 if SQL_C_CHAR) without subtracting str_from_pos from it.

   31-MAR-1997 AK  Added the tenth argument sql_type. See comment at
   dv_to_place. Used for converting timestamp objects
   correctly.

 */

/*
   This comment is from ODBC API Help File, please keep it here for
   further references and perfectioning this interface.

   Converting timestamp SQL data to SQL_C_CHAR
   and converting DATE's and TIME's to anything...

   rgbValue	  pcbValue	SQL-STATE

   cbValueMax > Dispsize	 Data	      Length of data   N/A
   20 <= cbValueMax <= Dispsize  Truncated data b, Length of data??? 01004
   cbValueMax < 20		 Untouched	 Untouched	22003

   I guess Dispsize (Display size) means here 29 ?

   What does Length of data in the second case (when it is truncated)
   mean? The length before or after truncation?

   In the second case fractional seconds of the timestamp are truncated.

   When timestamp SQL data is converted to character C data, the resulting
   string is in the "yyyy-mm-dd hh:mm:ss[.f...]" format, where up to nine
   digits may be used for fractional seconds. (Except for the decimal point
   and fractional seconds, the entire format must be used, regardless of
   the precision of the timestamp SQL data type.)


   =======================================
   SQL to C: Date
   =======================================

   The date ODBC SQL data type is:

   SQL_DATE

   The following table shows the ODBC C data types to which date SQL data
   may be converted.

   fCType	   Test		      rgbValue    pcbValue  SQL-STATE
   SQL_C_CHAR       cbValueMax >= 11	  Data	10	N/A
   cbValueMax < 11	   Untouched   Untouched 22003
   SQL_C_BINARY  Len of data <= cbValueMax Data	Length of data N/A
   Len of data > cbValueMax  Untouched   Untouched 22003
   SQL_C_DATE	None a		    Data	6 c       N/A
   SQL_C_TIMESTAMP       None a		    Data b      16 c      N/A

   a The value of cbValueMax is ignored for this conversion.
   The driver assumes that the size of rgbValue is the size
   of the C data type.

   b The time fields of the timestamp structure are set to zero.

   c This is the size of the corresponding C data type.
   (I.e. DATE_STRUCT (size 6) and TIMESTAMP_STRUCT (size 16) defined
   in sqlext.h)

   When date SQL data is converted to character C data, the resulting
   string is in the "yyyy-mm-dd" format.

   =======================================
   SQL to C: Time
   =======================================

   The time ODBC SQL data type is:

   SQL_TIME

   The following table shows the ODBC C data types to which time SQL
   data may be converted.

   fCType	   Test		      rgbValue   pcbValue  SQL-STATE
   SQL_C_CHAR	cbValueMax >= 9	   Data       8	 N/A
   cbValueMax < 9	    Untouched  Untouched 22003
   SQL_C_BINARY     Len of data <= cbValueMax Data       Length of data N/A
   Len of data > cbValueMax  Untouched  Untouched 22003
   SQL_C_TIME       None a		    Data       6 c       N/A
   SQL_C_TIMESTAMP       None a		    Data b     16 c      N/A

   a The value of cbValueMax is ignored for this conversion. The driver
   assumes that the size of rgbValue is the size of the C data type.

   b The date fields of the timestamp structure are set to the current
   date and the fractional seconds field of the timestamp structure is
   set to zero.

   c This is the size of the corresponding C data type.
   (I.e. TIME_STRUCT (size 6) and TIMESTAMP_STRUCT (size 16) defined
   in sqlext.h)

   When time SQL data is converted to character C data, the resulting
   string is in the "hh:mm:ss" format.

   The meaning of SQL states 01004 and 22003 are:

   01004   Data truncated  The data returned for one or more columns was
   truncated. String values are right truncated. For numeric values,
   the fractional part of number was truncated.
   (Function returns SQL_SUCCESS_WITH_INFO.)

   22003   Numeric value out of range   Returning the numeric value
   (as numeric or string) for one or more columns would have
   caused the whole (as opposed to fractional) part of the number
   to be truncated.
   Returning the binary value for one or more columns would have
   caused a loss of binary significance. For more information,
   see Converting Data from SQL to C Data Types.

   Currently (version 0.99b 31-MAR-1997 and earlier versions) we are liberal,
   we never use state 22003 so that the client can grab as short piece of
   e.g. timestamp or date as (s)he ever wants.
   E.g., by using cbValueMax 11 the client can take just the date portion
   from the timestamp, if he is unable to supply SQL type info (SQL_DATE)
   here, as is case e.g. with SQLBindCol or SQLGetData, when sql_type will
   be simply zero.

 */

static long
strses_cp_narrow_to_wide (void *dest_ptr, void *src_ptr, long src_ofs,
    long copy_bytes, void *state_data)
{
  cli_narrow_to_wide ((wcharset_t *) state_data, 0, ((unsigned char *) (src_ptr)) + src_ofs, copy_bytes, (wchar_t *) dest_ptr, copy_bytes);

  return copy_bytes * sizeof (wchar_t);
}


static SQLLEN
dv_strses_to_str_place (caddr_t it, dtp_t dtp, SQLLEN max, caddr_t place,
    SQLLEN * len_ret, SQLLEN str_from_pos, cli_stmt_t * stmt, int nth_col,
    SQLLEN box_len, int c_type, SQLSMALLINT sql_type)
{
  dk_session_t *ses = (dk_session_t *) it;
  long len, ses_len;
  SQLLEN piece_len = 0;

  if (strses_is_utf8 (ses))
    {
      ses_len = len = strses_chars_length (ses);

      if (len_ret)
	*len_ret = (SDWORD) len *(c_type == SQL_C_WCHAR ? sizeof (wchar_t) : sizeof (char));

      if (max > 0)
	{
	  wchar_t *wide_ptr = ((wchar_t *) place);
	  caddr_t box = NULL;

	  if (SQL_C_CHAR == c_type)
	    {			/* TODO: GK: bit of a hack for now, refine later */
	      box = (caddr_t) dk_alloc ((max + 1) * sizeof (wchar_t));
	      wide_ptr = (wchar_t *) box;

	      max *= sizeof (wchar_t);
	      str_from_pos *= sizeof (wchar_t);
	    }

	  if (SQL_C_WCHAR == c_type || SQL_C_CHAR == c_type)
	    {
	      len -= str_from_pos / sizeof (wchar_t);

	      if (len >= ((SDWORD) (max / sizeof (wchar_t))))
		{
		  piece_len = max / sizeof (wchar_t) - 1;
		  if (piece_len >= 0)
		    {
		      strses_get_wide_part (ses, wide_ptr, str_from_pos / sizeof (wchar_t), piece_len);
		      wide_ptr[piece_len] = 0;
		    }
		  set_data_truncated_success_info (stmt, "CLXXX", nth_col);
		}
	      else
		{
		  piece_len = len;
		  strses_get_wide_part (ses, wide_ptr, str_from_pos / sizeof (wchar_t), len);
		  wide_ptr[len] = 0;
		}
	    }

	  if (SQL_C_CHAR == c_type)
	    {			/* TODO: GK: part of the above hack - remove later */
	      cli_wide_to_narrow (stmt->stmt_connection->con_charset, 0, wide_ptr, piece_len, (unsigned char *) place, max, NULL, NULL);
	      place[piece_len] = 0;
	      dk_free (box, ((size_t) - 1));
	    }
	  else
	    piece_len *= sizeof (wchar_t);

	}

      return piece_len;
    }
  else
    {
      ses_len = len = strses_length (ses);

      if (len_ret)
	*len_ret = (SDWORD) len *(c_type == SQL_C_WCHAR ? sizeof (wchar_t) : sizeof (char));

      if (max > 0)
	{
	  if (SQL_C_CHAR == c_type)
	    {
	      len -= str_from_pos;

	      if (len >= max)
		{
		  piece_len = max;
		  set_data_truncated_success_info (stmt, "CLXXX", nth_col);
		  strses_get_part (ses, place, str_from_pos, max - 1);
		  place[max - 1] = '\0';	/* and is null-terminated by the driver. */
		}
	      else if (len > 0)
		{
		  piece_len = len;
		  strses_get_part (ses, place, str_from_pos, len);
		  place[len] = '\0';	/* and is null-terminated by the driver. */
		}
	    }
	  else if (SQL_C_WCHAR == c_type)
	    {
	      len -= str_from_pos / sizeof (wchar_t);
	      if (len >= ((SDWORD) (max / sizeof (wchar_t))))
		{
		  piece_len = max / sizeof (wchar_t) - 1;

		  if (piece_len >= 0)
		    {
		      strses_get_part_1 (ses, place, str_from_pos / sizeof (wchar_t), piece_len, strses_cp_narrow_to_wide, stmt->stmt_connection->con_charset);
		      ((wchar_t *) place)[piece_len] = 0;
		    }

		  set_data_truncated_success_info (stmt, "CLXXX", nth_col);
		}
	      else
		{
		  piece_len = len / sizeof (wchar_t);
		  strses_get_part_1 (ses, place, str_from_pos / sizeof (wchar_t), len, strses_cp_narrow_to_wide, stmt->stmt_connection->con_charset);
		  ((wchar_t *) place)[len] = 0;
		}

	      piece_len *= sizeof (wchar_t);
	    }
	}

      return piece_len;
    }
}

#include "../langfunc/encoding_basic.c"

SQLLEN
dv_to_str_place (caddr_t it, dtp_t dtp, SQLLEN max, caddr_t place,
    SQLLEN *len_ret, SQLLEN str_from_pos, cli_stmt_t * stmt, int nth_col,
    SQLLEN box_len, int c_type, SQLSMALLINT sql_type, SQLLEN * out_chars)
{
  SQLLEN len = 0, piece_len = 0;
  char temp[500];		/* Enough? - greater than max length of numeric output by sprintf */
  char *str = temp;
#ifndef MAP_DIRECT_BIN_CHAR
  /*col_desc_t *col_desc = NULL; */
  int blob_to_char = 0;
#endif

  assert (sizeof (temp) > NUMERIC_MAX_STRING_BYTES);

#ifndef MAP_DIRECT_BIN_CHAR
/*  if (stmt && stmt->stmt_compilation && stmt->stmt_compilation->sc_columns &&
      BOX_ELEMENTS (stmt->stmt_compilation->sc_columns) >= ((uint32)nth_col) && nth_col > 0)
    col_desc = (col_desc_t *)stmt->stmt_compilation->sc_columns[nth_col - 1];
  blob_to_char = (dtp == DV_BIN || (col_desc && (col_desc->cd_dtp == DV_BIN || col_desc->cd_dtp == DV_BLOB_BIN)));*/
  blob_to_char = (dtp == DV_BIN && c_type == SQL_C_CHAR);
#endif

/* IvAn/DvBlobXper/001212 Case for XPER added */
  if (IS_BLOB_HANDLE_DTP (dtp))
    {
      blob_handle_t *bh = (blob_handle_t *) it;
      if (len_ret)
	*len_ret = (SDWORD) bh->bh_length * ((dtp == DV_BLOB_WIDE_HANDLE) ? sizeof (wchar_t) : sizeof (char));

      if (nth_col != -1)
	{
#ifndef MAP_DIRECT_BIN_CHAR
	  virtodbc__SQLGetData ((SQLHSTMT) stmt, (SQLUSMALLINT) nth_col,
	      (SQLSMALLINT) (c_type == SQL_C_WCHAR ? SQL_C_WCHAR : c_type ==
		  SQL_C_BINARY ? SQL_C_BINARY : SQL_C_CHAR), place, max, len_ret);
#else
	  virtodbc__SQLGetData ((SQLHSTMT) stmt, (SQLUSMALLINT) nth_col,
	      c_type == SQL_C_WCHAR ? SQL_C_WCHAR : SQL_C_CHAR, place, max, len_ret);
#endif
	  cli_dbg_printf (("Bound col %d to blob %ld bytes, got %ld, = %s\n",
		  nth_col, bh->bh_length, len_ret ? *len_ret : 0, place));

	}

      return (SDWORD) bh->bh_length;
    }
  else if (DV_STRING_SESSION == dtp)
    {
      return dv_strses_to_str_place (it, dtp, max, place, len_ret, str_from_pos, stmt, nth_col, box_len, c_type, sql_type);
    }

  temp[0] = '\0';

  if (SQL_C_CHAR != c_type && SQL_C_WCHAR != c_type)
    {
      len = box_len;
      str = ((char *) it);
      if (SQL_C_BINARY == c_type)
	switch (dtp)		/* Not SQL_C_CHAR/SQL_C_OID */
	  {
	  case DV_STRING:
	    len--;		/* Exclude the termination byte */
	    break;

	  case DV_WIDE:
	  case DV_LONG_WIDE:
	    len -= sizeof (wchar_t);	/* Exclude the termination byte */
	    break;
	  }
    }
  else
    switch (dtp)
      {
      case DV_STRING:
      case DV_SHORT_CONT_STRING:
      case DV_LONG_CONT_STRING:
      case DV_BIN:
	len = box_len;		/* box_length(it); */
	if (DV_SHORT_STRING == dtp || DV_LONG_STRING == dtp)
	  len--;		/* Terminating zero byte '\0' is excluded. */
	str = ((char *) it);
	break;

      case DV_SHORT_INT:
      case DV_LONG_INT:
	snprintf (temp, sizeof (temp), BOXINT_FMT, (boxint) unbox (it));
	break;

      case DV_IRI_ID:
        {
          iri_id_t iid = unbox_iri_id (it);
          if (iid >= MIN_64BIT_BNODE_IRI_ID)
	    snprintf (temp, sizeof (temp), "#ib" IIDBOXINT_FMT, (boxint)(iid-MIN_64BIT_BNODE_IRI_ID));
          else
	    snprintf (temp, sizeof (temp), "#i" IIDBOXINT_FMT, (boxint)(iid));
          break;
        }

      case DV_SINGLE_FLOAT:
	snprintf (temp, sizeof (temp), "%.16g", unbox_float (it));
	break;

      case DV_DOUBLE_FLOAT:
	snprintf (temp, sizeof (temp), "%.16g", unbox_double (it));
	break;

      case DV_NUMERIC:
	numeric_to_string ((numeric_t) it, temp, sizeof (temp));
	break;

      case DV_DATETIME:	/* This is the new type, from 27-FEB-97 on */
	{			/* See the comment before this function. */
	  dt_to_string (it, temp, sizeof (temp));

	  if (!sql_type && nth_col != -1)
	    virtodbc__SQLDescribeCol ((SQLHSTMT) stmt, (SQLUSMALLINT) nth_col,
		NULL, (SQLSMALLINT) 0, NULL, &sql_type, NULL, NULL, NULL);

	  switch (sql_type)
	    {
	    case SQL_TYPE_DATE:
	    case SQL_DATE:
	      temp[10] = 0;
	      break;

	    case SQL_TYPE_TIME:
	    case SQL_TIME:
              {
                char *tail = temp+11;
                do { tail[-11] = tail[0]; tail++; } while (tail[0]);
/*
	      strncpy (temp, temp + 11, 8);
	      temp[8] = 0;
	      temp[2] = temp[5] = ':';
*/
/*	      sprintf (temp, "%02d:%02d:%02d",
		  DT_HOUR (it), DT_MINUTE (it), DT_SECOND (it));
*/
	      break;
               }

	    default:		/* Including 0=unknown, and SQL_TIMESTAMP */
	      /*temp[19] = 0;*/
	      break;
	    }
	}
	break;

      case DV_ARRAY_OF_LONG:
      case DV_ARRAY_OF_FLOAT:
      case DV_ARRAY_OF_DOUBLE:
      case DV_ARRAY_OF_POINTER:
      case DV_LIST_OF_POINTER:
      case DV_ARRAY_OF_XQVAL:
      case DV_XTREE_HEAD:
      case DV_XTREE_NODE:
	{
/* str_from_pos is currently ignored with vectors:
   str += str_from_pos;
   len -= str_from_pos;
 */
	  if (max <= 0)
	    {
	      set_data_truncated_success_info (stmt, "CL071", nth_col);
	      piece_len = 0;

	      if (len_ret)
		*len_ret = 0;
	    }
	  else
	    {
	      if (vector_to_text (it, box_len, dtp, place, (max - 1)))
		{
		  /* Ascii-representation was truncated? */
		  piece_len = max - 1;
		  place[piece_len] = '\0';
		  set_data_truncated_success_info (stmt, "CL072", nth_col);
		}
	      else
		/* It fitted there all right. */
		piece_len = (SDWORD) strlen (place);

/* Currently len_ret is with vectors always the copied length, whether
   truncated or not. Otherwise vector_to_text should be recoded to
   count the total output length of vector also in case that it
   overflows the destination buffer. */
	      if (len_ret)
		*len_ret = piece_len;
	    }

	  return piece_len;
	}

      case DV_WIDE:
      case DV_LONG_WIDE:
	{
	  if (max <= 0)
	    {
	      set_data_truncated_success_info (stmt, "CL073", nth_col);
	      piece_len = 0;
	      if (len_ret)
		*len_ret = 0;
	    }
	  else
	    {
	      len = box_len;
	      len = len / sizeof (wchar_t) - 1;
	      if (place)
		switch (c_type)
		  {
		  case SQL_C_CHAR:
		    len -= str_from_pos;

		    if (len >= max)
		      {
			piece_len = max - 1;
			cli_wide_to_narrow (stmt->stmt_connection->con_charset,
					    0, ((wchar_t *) it) + str_from_pos, piece_len, (unsigned char *) place, piece_len, NULL, NULL);
			place[piece_len] = 0;
			set_data_truncated_success_info (stmt, "CL074", nth_col);
		      }
		    else
		      {
			cli_wide_to_narrow (stmt->stmt_connection->con_charset,
					    0, ((wchar_t *) it) + str_from_pos, len + 1, (unsigned char *) place, max - 1, NULL, NULL);
			piece_len = len;
		      }

		    if (len_ret)
		      *len_ret = (box_len / sizeof (wchar_t)) - 1;

		    break;

		  case SQL_C_WCHAR:
		    len -= str_from_pos / sizeof (wchar_t);
		    max /= sizeof (wchar_t);

		    if (len >= max)
		      {
			piece_len = max - 1;
			memcpy (place, (wchar_t *) (it + str_from_pos), piece_len * sizeof (wchar_t));
			((wchar_t *) place)[piece_len] = L'\x0';
			set_data_truncated_success_info (stmt, "CL075", nth_col);
			piece_len *= sizeof (wchar_t);
		      }
		    else
		      {
			if (stmt->stmt_connection->con_wide_as_utf16)
			  {
			    eh_encode_wchar_buffer__UTF16LE (
				(wchar_t *) (it + str_from_pos),
				(wchar_t *) (it + str_from_pos) + (len + 1),
				place,
				place + max);
			    if (out_chars)
			      *out_chars = len * sizeof (short);
			  }
			else
			memcpy (place, (wchar_t *) (it + str_from_pos), (len + 1) * sizeof (wchar_t));
			piece_len = len * sizeof (wchar_t);
		      }

		    if (len_ret)
		      *len_ret = box_len - sizeof (wchar_t);

		    break;
		  }
	    }

	  return piece_len;
	}
      case DV_RDF:
	{
	  rdf_box_t * rb = (rdf_box_t *) it;
          if (DV_STRING == DV_TYPE_OF (rb->rb_box))
            {
	      str = rb->rb_box;
	      len = box_length (rb->rb_box) - 1;
            }
          else if (!IS_BOX_POINTER (rb->rb_box))
            {
	      snprintf (temp, sizeof (temp), "%ld", (long)((ptrlong)(rb->rb_box)));
              break;
            }
          else
            return dv_to_str_place (rb->rb_box, DV_TYPE_OF (rb->rb_box), max, place,
              len_ret, str_from_pos, stmt, nth_col, box_length (rb->rb_box), c_type, sql_type, out_chars);
	  break;
	}

      default:
	snprintf (temp, sizeof (temp), "%u=dtp Unknown type in dv_to_str_place", dtp);
	break;
      }

  if (*temp)
    len = (SDWORD) strlen (temp);

  if (len_ret)
    *len_ret = len * (SQL_C_WCHAR == c_type ? sizeof (wchar_t) : sizeof (char));

  /* What if str_from_pos is greater than len ? */
#ifndef MAP_DIRECT_BIN_CHAR
  if (SQL_C_WCHAR == c_type)
    {
      str += str_from_pos / (sizeof (wchar_t) * (blob_to_char ? 2 : 1));
      len -= str_from_pos / (sizeof (wchar_t) * (blob_to_char ? 2 : 1));
    }
  else
    {
      str += str_from_pos / (blob_to_char ? 2 : 1);
      len -= str_from_pos / (blob_to_char ? 2 : 1);
    }
#else
  if (SQL_C_WCHAR == c_type)
    {
      str += str_from_pos / sizeof (wchar_t);
      len -= str_from_pos / sizeof (wchar_t);
    }
  else
    {
      str += str_from_pos;
      len -= str_from_pos;
    }
#endif

  cli_dbg_printf (
      ("dv_to_str_place: max=%d, str=%s, strlen(str)=%d, temp=%s, strlen(temp)=%d,"
	  " len=%d, len_ret=%08lx, place=%08lx, it=%08lx, str_from_pos=%d, "
	  " c_type=%d, sql_type=%d, dtp=%d, box_len=%d\n", max, str,
	  strlen (str), temp, strlen (temp), len, len_ret, place, it, str_from_pos, c_type, sql_type, dtp, box_len));

  if (max > 0)
    {
      if (SQL_C_CHAR == c_type)
	{
#ifndef MAP_DIRECT_BIN_CHAR
	  if (blob_to_char)
	    {
	      len *= 2;
	      *len_ret = len;

	      if (len >= max)
		{
		  piece_len = (max - 1) / 2;
		  bin_dv_to_str_place ((unsigned char *) str, place, piece_len);
		  set_data_truncated_success_info (stmt, "CL076", nth_col);
		}
	      else
		{
		  piece_len = len / 2;
		  bin_dv_to_str_place ((unsigned char *) str, place, piece_len);
		}

	      piece_len *= 2;
	      place[piece_len] = 0;	/* truncate this as well */
	    }
	  else
#endif
	    {
	      if (len >= max)
		{
		  piece_len = max - 1;
		  memcpy (place, str, piece_len);	/* Truncated to cbValueMax-1 bytes */
		  place[piece_len] = '\0';	/* and is null-terminated by the driver. */
		  set_data_truncated_success_info (stmt, "CL077", nth_col);
		}
	      else
		{
		  memcpy (place, str, (len + 1));	/* Also '\0' */
		  piece_len = len;
		}
	    }
	}
      else if (SQL_C_WCHAR == c_type)
	{
	  if (len >= ((SDWORD) (max / sizeof (wchar_t))))
	    {
	      piece_len = max / sizeof (wchar_t) - 1;
	      cli_narrow_to_wide (stmt->stmt_connection->con_charset, 0,
		  (unsigned char *) str, piece_len, (wchar_t *) place, piece_len);

	      if (piece_len >= 0)
		((wchar_t *) place)[piece_len] = 0;

	      set_data_truncated_success_info (stmt, "CL078", nth_col);
	    }
	  else
	    {
	      size_t wides;

	      if (stmt->stmt_connection->con_string_is_utf8)
		{
		  caddr_t wide;
		  long wlen;
		  wide = box_utf8_as_wide_char (str, NULL, len, 0, DV_WIDE);
		  wlen = box_length (wide) / sizeof (wchar_t) - 1;
		  if (stmt->stmt_connection->con_wide_as_utf16)
		    {
		      eh_encode_wchar_buffer__UTF16LE (
			  (wchar_t *) wide,
			  (wchar_t *) wide + wlen + 1,
			  place,
			  place + max);
		      if (out_chars)
			*out_chars = wlen * sizeof (short);
		    }
		  else
		    memcpy (place, wide, wlen + 1);
		  dk_free_box (wide);
		}
	      else
		{
		  wides = cli_narrow_to_wide (stmt->stmt_connection->con_charset, 0,
		  (unsigned char *) str, len, (wchar_t *) place,
		  max / sizeof (wchar_t));

	      if (wides >= 0 && wides < max / sizeof (wchar_t))
		((wchar_t *) place)[wides] = 0;
		}

	      piece_len = len;
	    }
	  piece_len *= sizeof (wchar_t);
	}
      else
	/* (SQL_C_BINARY == c_type) */
	{
	  if (len > max)
	    {
	      piece_len = max;
	      memcpy (place, str, max);	/* Truncated to cbValueMax bytes */
	      set_data_truncated_success_info (stmt, "CL079", nth_col);
	    }
	  else
	    {
	      memcpy (place, str, len);
	      piece_len = len;
	    }
	}
    }
  else
    {
      set_data_truncated_success_info (stmt, "CL080", nth_col);
      piece_len = 0;
    }

  return piece_len;
}


/* When the server is changed so that it stores its timestamps and dates
   with the types DV_TIMESTAMP or/and DV_DATE then also the latter part
   of the following macro has any effect.
   Now 27-FEB-1997 it is changed so that timestamps and dates have
   the type DV_TIMESTAMP_OBJ
 */
#define is_internal_time_type(X)\
  ((X) == DV_DATETIME)


#define check_for_no_data(X)\
  if(0 == box_length((X))) { return(SQL_NO_DATA_FOUND); }


void
num_bind_check (cli_stmt_t * stmt, int rc)
{
  if (rc != NUMERIC_STS_SUCCESS)
    {
      set_error (&stmt->stmt_error, "01S07", "CL081", "Numeric truncated by client");
    }
}


void nt_to_numeric_struct (char * dt, SQL_NUMERIC_STRUCT * ons);
 /*
    Via:
    SQLFetch (wicli.c)      -> stmt_set_columns (cliuti.c)
    SQLFetch (wicli.c)      -> stmt_process_result -> stmt_set_proc_return
    SQLPrepare (wicli.c)    -> stmt_process_result -> stmt_set_proc_return
    SQLSync (wicli.c)       -> stmt_process_result -> stmt_set_proc_return
    SQLExecDirect (wicli.c) -> stmt_process_result -> stmt_set_proc_return
    SQLParamData (sqlext.c) -> stmt_process_result -> stmt_set_proc_return

    Directly from:
    SqlGetData (sqlext.c)

    Now dv_to_place returns a length of the copied piece, normally
    same as what is stored to len_ret, except if the argument is of
    certain boxed types like strings or timestamps, etc, and less than
    the whole length is copied.
    Currently only SQLGetData uses this return value for anything.

    If dv_value 'it' is XXX, returns YYY and stores ZZZ to *len_ret

    NULL	 SQL_NULL_DATA  SQL_NULL_DATA
    box of length zero   SQL_NULL_DATA  0

    If max is 0 (c_type is
    SQL_C_BINARY or SQL_C_CHAR)
    or max is 1 and c_type
    is SQL_C_CHAR	   returns 0   and stores zero to *len_ret
    (in case c_type is SQL_C_CHAR and string is '')
    returns 0   and stores non-zero to *len_ret
    (in all other cases)

    If max is greater than 0 (with SQL_C_BINARY) or 1 (with SQL_C_CHAR)
    returns length of piece copied and stores to
    *len_ret the whole length of dv box (with
    SQL_C_BINARY) or one less (SQL_C_CHAR).

    If max is 777 and c_type is SQL_C_CHAR and box is '' (i.e. one byte '\0')
    then copies the terminating byte to place, returns zero, and stores
    zero to *len_ret.

    Otherwise, returns the size of data type (in bytes) and stores the
    same value to *len_ret (if len_ret is not NULL).

    Note how in *len_ret is always returned the original length of dv data
    (possibly - 1 if SQL_C_CHAR) without subtracting str_from_pos from it.
    It is the task of SQLGetData to calculate and store the correct value
    into its pcbValue pointer argument.
  */
SQLLEN
dv_to_place (caddr_t it,	/* Data in DV format  from the Kubl. */
    int c_type,			/* cb->cb_c_type,     from SQLBindCol fCType */
    SQLSMALLINT sql_type,		/* pb->pb_sql_type from stmt_set_proc_return,
				   0 elsewhere. New arg by AK 31-MAR-1997 */
    SQLLEN max,			/* cb->cb_max_length, from SQLBindCol cbValueMax */
    caddr_t place,		/* cb->cb_place,      from SQLBindCol rgbValue */
    SQLLEN *len_ret,		/* cb->cb_length,     from SQLBindCol pcbValue */
    SQLLEN str_from_pos,	/* Given as zero      from stmt_set_columns, and
				   stmt_set_proc_return
				   but as cb -> cb_read_up_to from SQLGetData */
    cli_stmt_t * stmt,		/* place error here if overflow */
    int nth_col,		/* use in possible SQLGetData of blob */
    SQLLEN *out_chars)
{
  SQLLEN len = 0, ret_len = 0;
  dtp_t its_type;

  if (c_type == SQL_C_DEFAULT)
    {
      if (nth_col != -1)
	{
	  SQLSMALLINT sql_type;

	  virtodbc__SQLDescribeCol ((SQLHSTMT) stmt, (SQLUSMALLINT) nth_col, NULL, (SQLSMALLINT) 0, NULL, &sql_type, NULL, NULL, NULL);
	  c_type = sql_type_to_sqlc_default (sql_type);
	}
      else
	c_type = dv_to_sqlc_default (it);
    }

  if (IS_BOX_POINTER (it) && DV_DB_NULL == box_tag (it))
    {
      ret_len = SQL_NULL_DATA;
      if (place && c_type == SQL_C_CHAR && max > 0)
	place[0] = 0;		/* If it's an NTS, make it empty */
    }
  else if (place)
    {
      /* General length check for all boxed types added here by AK 8-MAR-1997
         !is_somekind_of_vector_type(it) added 30-OCT-1997 so that empty vectors
         will be converted correctly to text.
         I DON'T EVEN KNOW WHETHER THIS ZERO-LENGTH CHECK IS EVEN NEEDED
         HERE. (IT MIGHT BE ACTUALLY HARMFUL IN OTHER WAYS ALSO).
         PREVIOUSLY I HAVE JUST SUPPOSED THAT RETURNING ZERO-LENGTH BOXES IS A
         SPECIAL WAY OF KUBL TO SIGNAL THAT IT IS FEELING BAD OR SOMETHING.
       */
      if (IS_BOX_POINTER (it))
	{			/* And if zero-length box encountered then make SQLGetData */
	  len = box_length (it);	/* to return SQL_NO_DATA_FOUND */
	  its_type = DV_TYPE_OF (it);

	  if ((0 == len) && !is_somekind_of_vector_type (its_type))
	    {
	      *len_ret = len;
	      return SQL_NULL_DATA;
	    }
	}
      else
	{
	  its_type = DV_TYPE_OF (it);
	}

      if (c_type == SQL_C_LONG && max == 2)
	c_type = SQL_C_SHORT;

      switch (c_type)
	{
	case SQL_C_CHAR:
	case SQL_C_BINARY:
	case SQL_C_WCHAR:
	  return dv_to_str_place (it, its_type, max, place, len_ret, str_from_pos, stmt, nth_col, len, c_type, sql_type, out_chars);

	case SQL_C_BOX:
	    {
	      ret_len = sizeof (caddr_t);
	      *((caddr_t *)place) = (caddr_t) it;
	      break;
	    }

	case SQL_C_SLONG:
	case SQL_C_LONG:
	  ret_len = sizeof (long);
	  switch (its_type)
	    {
	    case DV_LONG_INT:
	    case DV_SHORT_INT:
              {
		boxint n = unbox (it);
		if (n < (int64) INT32_MIN || n > (int64) INT32_MAX)
		  {
		    set_error (&stmt->stmt_error, "22003", "CL098", "Integer value out of range");
		  }
		*((long *) place) = (long) unbox (it);
		break;
	      }
	    case DV_SINGLE_FLOAT:
	      *((long *) place) = (long) unbox_float (it);
	      break;

	    case DV_DOUBLE_FLOAT:
	      *((long *) place) = (long) unbox_double (it);
	      break;

	    case DV_NUMERIC:
	      {
		int32 tl;
		num_bind_check (stmt, numeric_to_int32 ((numeric_t) it, &tl));
		*((long *) place) = tl;
		break;
	      }

	    case DV_STRING:
	      {
		long tl;
		tl = atol (it);
		*((long *) place) = tl;
		break;
	      }
	    }
	  break;

	case SQL_C_ULONG:
	  ret_len = sizeof (long);
	  switch (its_type)
	    {
	    case DV_LONG_INT:
	    case DV_SHORT_INT:
	      *((unsigned long *) place) = (unsigned long) unbox (it);
	      break;

	    case DV_SINGLE_FLOAT:
	      *((unsigned long *) place) = (long) unbox_float (it);
	      break;

	    case DV_DOUBLE_FLOAT:
	      *((unsigned long *) place) = (long) unbox_double (it);
	      break;

	    case DV_NUMERIC:
	      {
		int32 tl;
		num_bind_check (stmt, numeric_to_int32 ((numeric_t) it, &tl));
		*((unsigned long *) place) = tl;
		break;
	      }

	    case DV_STRING:
	      {
		long tl;
		tl = atol (it);
		*((unsigned long *) place) = (unsigned long) tl;
		break;
	      }
	    }
	  break;

	case SQL_C_SSHORT:
	case SQL_C_SHORT:
	  ret_len = sizeof (short);
	  switch (its_type)
	    {
	    case DV_LONG_INT:
	    case DV_SHORT_INT:
	      *((short *) place) = (short) unbox (it);
	      break;

	    case DV_SINGLE_FLOAT:
	      *((short *) place) = (short) unbox_float (it);
	      break;

	    case DV_DOUBLE_FLOAT:
	      *((short *) place) = (short) unbox_double (it);
	      break;

	    case DV_NUMERIC:
	      {
		int32 tl;
		num_bind_check (stmt, numeric_to_int32 ((numeric_t) it, &tl));
		*((short *) place) = (short) tl;
		break;
	      }

	    case DV_STRING:
	      {
		int32 tl;
		tl = atoi (it);
		*((short *) place) = (short) tl;
		break;
	      }
	    }
	  break;

	case SQL_C_USHORT:
	  ret_len = sizeof (short);
	  switch (its_type)
	    {
	    case DV_LONG_INT:
	    case DV_SHORT_INT:
	      *((unsigned short *) place) = (unsigned short) unbox (it);
	      break;

	    case DV_SINGLE_FLOAT:
	      *((unsigned short *) place) = (unsigned short) unbox_float (it);
	      break;

	    case DV_DOUBLE_FLOAT:
	      *((unsigned short *) place) = (unsigned short) unbox_double (it);
	      break;

	    case DV_NUMERIC:
	      {
		int32 tl;
		num_bind_check (stmt, numeric_to_int32 ((numeric_t) it, &tl));
		*((unsigned short *) place) = (unsigned short) tl;
		break;
	      }

	    case DV_STRING:
	      {
		int32 tl;
		tl = atoi (it);
		*((unsigned short *) place) = (unsigned short) tl;
		break;
	      }

	    }
	  break;

	case SQL_C_FLOAT:
	  ret_len = sizeof (float);
	  switch (its_type)
	    {
	    case DV_LONG_INT:
	    case DV_SHORT_INT:
	      *((float *) place) = (float) unbox (it);
	      break;

	    case DV_SINGLE_FLOAT:
	      *((float *) place) = unbox_float (it);
	      break;

	    case DV_DOUBLE_FLOAT:
	      *((float *) place) = (float) unbox_double (it);
	      break;

	    case DV_NUMERIC:
	      {
		double td;
		num_bind_check (stmt, numeric_to_double ((numeric_t) it, &td));
		*((float *) place) = (float) td;
		break;
	      }

	    case DV_STRING:
	      {
		double tl;
		tl = atof (it);
		*((float *) place) = (float) tl;
		break;
	      }
	    }
	  break;

	case SQL_C_DOUBLE:
	  ret_len = sizeof (double);
	  switch (its_type)
	    {
	    case DV_LONG_INT:
	    case DV_SHORT_INT:
	      *((double *) place) = (double) unbox (it);
	      break;

	    case DV_SINGLE_FLOAT:
	      *((double *) place) = (double) unbox_float (it);
	      break;

	    case DV_DOUBLE_FLOAT:
	      *((double *) place) = unbox_double (it);
	      break;

	    case DV_NUMERIC:
	      {
		double td;
		num_bind_check (stmt, numeric_to_double ((numeric_t) it, &td));
		*((double *) place) = td;
		break;
	      }

	    case DV_STRING:
	      {
		double tl;
		tl = atof (it);
		*((double *) place) = tl;
		break;
	      }
	    }
	  break;

	case SQL_C_TIMESTAMP:
#ifdef SQL_C_TYPE_TIMESTAMP
	case SQL_C_TYPE_TIMESTAMP:
#endif
	  {
	    TIMESTAMP_STRUCT *out_ts = (TIMESTAMP_STRUCT *) place;

	    if (is_internal_time_type (its_type))
	      {
		dt_to_timestamp_struct (it, out_ts);
		ret_len = sizeof (TIMESTAMP_STRUCT);
	      }

	    break;
	  }

#ifdef SQL_C_TYPE_TIME
	case SQL_C_TYPE_TIME:
#endif
	case SQL_C_TIME:
	  {
	    TIME_STRUCT *out_ts = (TIME_STRUCT *) place;

	    if (is_internal_time_type (its_type))
	      {
		dt_to_time_struct (it, out_ts);
		ret_len = sizeof (TIME_STRUCT);
	      }

	    break;
	  }

#ifdef SQL_C_TYPE_DATE
	case SQL_C_TYPE_DATE:
#endif
	case SQL_C_DATE:
	  {
	    DATE_STRUCT *out_ts = (DATE_STRUCT *) place;

	    if (is_internal_time_type (its_type))
	      {
		dt_to_date_struct (it, out_ts);
		ret_len = sizeof (DATE_STRUCT);
	      }

	    break;
	  }
	case SQL_C_NUMERIC:
	  {
	    SQL_NUMERIC_STRUCT *out_ns = (SQL_NUMERIC_STRUCT *) place;

	    nt_to_numeric_struct (it, out_ns);
	    ret_len = sizeof (SQL_NUMERIC_STRUCT);

	    break;
	  }
	}
    }

  if (len_ret)
    *len_ret = ret_len;

  return ret_len;
}


/* Convert dv type to SQL_NUMERIC_STRUCT type */
void
nt_to_numeric_struct (char * it, SQL_NUMERIC_STRUCT * ons)
{
  numeric_t nt = numeric_allocate ();
  dtp_t its_type = DV_TYPE_OF (it);

  if (!ons || !it)
    return;

  switch (its_type)		/* convert all other numeric types to DV_NUMERIC */
    {
    case DV_LONG_INT:
    case DV_SHORT_INT:
      numeric_from_double (nt, (double) unbox (it));
      break;

    case DV_SINGLE_FLOAT:
      numeric_from_double (nt, (double) unbox_float (it));
      break;

    case DV_DOUBLE_FLOAT:
      numeric_from_double (nt, unbox_double (it));
      break;

    case DV_NUMERIC:
      numeric_copy (nt, (numeric_t) it);
      break;

    case DV_STRING:
      numeric_from_string (nt, it);
      break;

    default:
      break;
    }

  if (nt)
    {
      ons->precision = numeric_precision (nt);
      ons->scale = numeric_scale (nt);
      ons->sign = numeric_sign (nt) > 0 ? 0 : 1;	/* 1 positive 0 negative numbers */

      memset (ons->val, '\x0', SQL_MAX_NUMERIC_LEN);	/* set all to zero */
      numeric_to_hex_array (nt, ons->val);
      numeric_free (nt);
    }
}


caddr_t
numeric_struct_to_nt (SQL_NUMERIC_STRUCT * ns)
{
  numeric_t n = numeric_allocate ();

  if (!ns)
    return dk_alloc_box (0, DV_DB_NULL);

  numeric_from_hex_array (n, ns->precision - ns->scale, ns->scale, (ns->sign > 0 ? 0 : 1), ns->val, SQL_MAX_NUMERIC_LEN);

  return (caddr_t) n;
}

void
stmt_reset_getdata_status (cli_stmt_t * stmt, caddr_t * row)
{
  int inx = 1;
  unsigned long nRowLength;
  col_binding_t *cb = stmt->stmt_cols;

  if (!row)
    return;

  nRowLength = BOX_ELEMENTS (row);

  while (cb)
    {
      cb->cb_read_up_to = 0;
      cb->cb_not_first_getdata = 0;

      if (row && ((unsigned long) inx) < nRowLength)
	{
	  caddr_t val = row[inx];
	  dtp_t dtp = DV_TYPE_OF (val);

/* IvAn/DvBlobXper/001212 Case for XPER added */
	  if (IS_BLOB_HANDLE_DTP (dtp))
	    {
	      blob_handle_t *bh = (blob_handle_t *) val;
	      bh->bh_current_page = bh->bh_page;
	      bh->bh_position = 0;
	    }
	}

      cb = cb->cb_next;
      inx++;
    }
}


void
stmt_set_columns (cli_stmt_t * stmt, caddr_t * row, int nth_in_set)
{
  int row_len = BOX_ELEMENTS (row);
  int inx = 1;
  col_binding_t *cb = stmt->stmt_cols;
  caddr_t *old_curr_row = stmt->stmt_current_row;

  while (cb)
    {
      caddr_t it;
      cb->cb_read_up_to = 0;
      cb->cb_not_first_getdata = 0;

      if (!cb->cb_place || inx >= row_len)
	{
	  cb = cb->cb_next;
	  inx++;
	  continue;
	}

      it = row[inx];
      if (cb->cb_place && stmt->stmt_retrieve_data == SQL_RD_ON)
	{
	  int rebind_offset =
	      stmt->stmt_imp_row_descriptor ? (stmt->stmt_imp_row_descriptor->
	      d_bind_offset_ptr ? *(stmt->stmt_imp_row_descriptor->d_bind_offset_ptr) : 0) : 0;
	  SQLLEN pl_offset = stmt->stmt_bind_type == 0 ? cb->cb_max_length * nth_in_set : nth_in_set * stmt->stmt_bind_type;
	  int l_offset = stmt->stmt_bind_type == 0 ? sizeof (long) * nth_in_set : nth_in_set * stmt->stmt_bind_type;
	  SQLLEN *len = cb->cb_length;

	  if (len)
	    len = (SQLLEN *) (((char *) len) + l_offset + rebind_offset);

	  /* dv_to_place calls virtodbc__SQLGetData for bound blob columns if any and
	     virtodbc__SQLGetData needs stmt_current_row to point to the right row. */
	  stmt->stmt_current_row = row;
	  dv_to_place (it, cb->cb_c_type, 0,
	      /* changed for ODBC 3 bind offsets - original line : cb->cb_max_length, cb->cb_place , cb->cb_length, */
	      cb->cb_max_length, cb->cb_place + pl_offset + rebind_offset, len, 0, stmt, inx, NULL);
	  stmt->stmt_current_row = old_curr_row;

	  /* clean up after dv_to_place to let later SQLGetData calls succeed (if for
	     whatever strange reason an app will do this for bound columns). */
	  cb->cb_read_up_to = 0;
	  cb->cb_not_first_getdata = 0;
	}

      cb = cb->cb_next;
      inx++;
    }

  if (stmt->stmt_bookmark_cb)
    {
      col_binding_t *cb = stmt->stmt_bookmark_cb;

      if (cb->cb_place)
	{
	  SQLLEN rebind_offset = stmt->stmt_imp_row_descriptor ?
	      (stmt->stmt_imp_row_descriptor->d_bind_offset_ptr ? *(stmt->stmt_imp_row_descriptor->d_bind_offset_ptr) : 0) : 0;
	  SQLLEN pl_offset = stmt->stmt_bind_type == 0 ? cb->cb_max_length * nth_in_set : nth_in_set * stmt->stmt_bind_type;
	  SQLLEN l_offset = stmt->stmt_bind_type == 0 ? sizeof (long) * nth_in_set : nth_in_set * stmt->stmt_bind_type;
	  SQLLEN *len = cb->cb_length;
	  if (len)
	    len = (SQLLEN *) (((char *) len) + l_offset + rebind_offset);
	  stmt->stmt_current_row = row;
	  virtodbc__SQLGetData ((SQLHSTMT) stmt, (SQLUSMALLINT) 0,
	      (SQLSMALLINT) cb->cb_c_type, cb->cb_place + pl_offset + rebind_offset, cb->cb_max_length, len);
	  stmt->stmt_current_row = old_curr_row;
	}
    }
}


/* ================================================================= */
/* Some new functions by AK for making changes to statement strings  */
/*		and generic string fiddling			*/
/* ================================================================= */


/* Few macros for strncasestr, which is used by SQLTables in sqlext.c */

/* This returns true for range '\100' - '\177'
   (from '@' via 'A' and 'Z' to 'a' and 'z' and DEL)
   and for range '\300' - '\377' (from ISO8859.1 Agrave to ydieresis)
   In this latter range are most of the accented vowels and some consonants
   of the ISO8859.1, and for the most the upper-lower-relation holds.
 */

#define is_a_letter(C)	((C) & 0100)	/* Bit-6 (64.) on */
/* This returns only true for 8-bit letters in range \300 - \377: */
#define is_a_iso_letter(C)    (((C) & 0300) == 0300)	/* Bit-7 and Bit-6 on */
#define is_a_lc_letter(C) (((C) & 0140) == 0140)	/* Both bits on */
#define is_a_uc_letter(C) (((C) & 0140) == 0100)	/* Bit-6 on, bit-5 off */
#define iso_to_lower(C) ((C) | 040)	/* Set bit-5 (32.) on */

/* Note that because these macros consider also the characters like
   @, [, \, ], and ^ to be 'letters', they will match against characters
   `, {, |, }, and ~ respectively, which is just all right, because
   in some older implementations of European character sets those
   characters mark the uppercase and lowercase variants of certain
   diacritic letters. And I think it's generally better to match
   too liberally and so maybe sometimes give something entirely off
   the mark to the user, than to miss something important because of
   too strict criteria.
 */



/* Returns pointer to that point of string1, where the first instance
   of string2 is found. Case does not matter. Checks max. maxbytes
   characters from the beginning of string1.
   Probably not the most optimal algorithm, but good enough for me.
   (Cleaned from nc_strstr function of string.c module.)
   If string1 is null terminated string (SQL_NTS) then maxbytes should
   be its length got with strlen(string1).
   Before the loop begins the length of string2 minus one is subtracted
   from it, so that string1 will not be unnecessarily scanned past the
   point where string2 cannot anymore occur as its tail.
 */
unsigned char *
strncasestr (unsigned char *string1, unsigned char *string2, size_t maxbytes)
{
  unsigned char first, d, e;
  unsigned char *s1, *s2;
  size_t str2len = strlen ((char *) string2);

  if (!str2len)
    {
      return string1;
    }				/* If string2 is an empty string "" */

  first = iso_to_lower (*string2);

  for (maxbytes -= (str2len - 1); (maxbytes > 0) && (d = *string1); maxbytes--)
    {
      if (is_a_uc_letter (d))
	{
	  d = iso_to_lower (d);
	}

      if (d == first)
	{
/*the_inner_loop: */
/* e have to be fetched and checked before d in and-clause, otherwise
   we won't find substrings from the end of string1: */
	  for (s1 = string1, s2 = string2; ((e = *++s2) && (d = *++s1));)
	    {
	      if (is_a_uc_letter (d))
		{
		  d = iso_to_lower (d);
		}

	      if (is_a_uc_letter (e))
		{
		  e = iso_to_lower (e);
		}

	      if (d != e)
		{
		  break;
		}		/* Found first differing character. */
	    }

/* If we exited the above loop with value of e as zero, then we have
   found that the whole string2 is contained in string1: */
	  if (!e)
	    {
	      return string1;
	    }

/* But if string1 was finished (although s2 still wasn't) then we return
   false, as the 'tail of string1' is now shorter than string2, so it's
   not anymore possible that string2 would fit into it:
   (Actually this case is not anymore possible because of new maxbytes
   counting done in the outer loop.)
 */
	  if (!d)
	    {
	      return 0;
	    }

/* Otherwise, it didn't match this time, let's try to find the next potential
   point of string1 where it would match: */
	}
      string1++;
    }

  return 0;			/* Return false as we didn't find it. */
}


static char *
skip_blankos (char *str)
{
  while (*str && isspace (*str))
    {
      str++;
    }				/* Skip blankos. */

  return str;
}


/*
   An extract from jdbc-spec-0120.pdf

   11.1 SQL Escape Syntax

   JDBC supports the same DBMS-independent escape syntax as ODBC for stored
   procedures, scalar functions, dates, times, and outer joins. A driver
   maps this escape syntax into DBMS-specific syntax, allowing portability
   of application programs that require these features. The DBMS-independent
   syntax is based on an escape clause demarcated by curly braces and a
   key-word:
   {keyword ... parameters ...}

   This ODBC-compatible escape syntax is in general not the same as has
   been adopted by ANSI in SQL-2 Transitional Level for the same
   functionality. In cases where all of the desired DBMSs support the
   standard SQL-2 syntax, the user is encouraged to use that syntax instead
   of these escapes. When enough DBMSs support the more advanced SQL-2 syntax
   and semantics these escapes should no longer be necessary.

   11.2 Stored Procedures

   The syntax for invoking a stored procedure in JDBC is:

   {call procedure_name[(argument1, argument2, ...)]}

   or, where a procedure returns a result parameter:

   {?= call procedure_name[(argument1, argument2, ...)]}


   11.3 Time and Date Literals

   DBMSs differ in the syntax they use for date, time, and timestamp literals.
   JDBC supports ISO standard format for the syntax of these literals, using
   an escape clause that the driver must translate to the DBMS representation.
   For example, a date is specified in a JDBC SQL statement with the syntax
   {d ‘yyyy-mm-dd’}
   where yyyy-mm-dd provides the year, month, and date, e.g. 1996-02-28.
   The driver will replace this escape clause with the equivalent
   DBMS-specific representation, e.g. ‘Feb 28, 1996’ for Oracle.

   There are analogous escape clauses for TIME and TIMESTAMP:

   {t ‘hh:mm:ss’}
   {ts ‘yyyy-mm-dd hh:mm:ss.f...’}

   The fractional seconds (.f...) portion of the TIMESTAMP can be omitted.

   11.4 Scalar Functions

   JDBC supports numeric, string, time, date, system, and conversion
   functions on scalar values.
   These functions are indicated by the keyword fn followed by the name of
   the desired function and its arguments. For example, two strings can be
   concatenated using the concat function

   {fn concat('Hot', 'Java')}

   The name of the current user can be obtained through the syntax
   {fn user()}

   11.5 LIKE Escape Characters

   The characters % and _ have special meaning in SQL LIKE clauses
   (to match zero or more characters, or exactly one character, respectively).
   In order to interpret them literally, they can be preceded with a special
   escape character in strings, e.g. \. In order to specify the escape
   character used to quote these characters, include the following syntax
   on the end of the query:

   {escape 'escape-character’}

   For example, the query
   SELECT NAME FROM IDENTIFIERS WHERE ID LIKE ‘\_%’ {escape ‘\’}
   finds identifier names that begin with an underline.

   11.6 Outer Joins

   The syntax for an outer join is

   {oj outer-join}

   where outer-join is of the form
   table LEFT OUTER JOIN {table | outer-join} ON search-condition

 */


/* convert_brace_escapes: a lazy attempt to implement the balderash above,
   started by AK 3-3-1997.
   Called from SQLPrepare and SQLExecDirect (in module wicli.c)

   Currently only the first case, invoking of a stored procedure is
   supported. That is, just brutally wipes off the beginning and
   ending curly braces, if they are the first and last non-white-space
   characters of the statement_text respectively.
   Does this in place, modifying destructively its string argument,
   which is returned back as a result.
   This should not affect any statements naturally containing
   curly braces, whether inside string literals, or as a part of
   procedure definitions.

   Note that the cases
   {d 'date-string'} {t 'time-string'} {ts 'timestamp-string'}
   {fn function-call} and {escape 'escape-char;}
   are now handled in server end (see sql2.y), and that leaves
   only {?=call fun(...)} which should be also implemented later
   in the server end, as well as {oj ...} for outer-joins, also
   sensible to implement in the server. Maybe this whole function
   will become unnecessary later.
 */

SQLCHAR *
stmt_convert_brace_escapes (SQLCHAR * statement_text, SQLINTEGER * newCB)
{
  SQLCHAR *ptr;

  /* Skip all white spaces. */
  ptr = (SQLCHAR *) skip_blankos ((char *) statement_text);

#if 0
  if ('{' == *ptr)		/* Left brace as first non-blank character? */
    {
      *ptr = ' ';		/* Overwrite it with a blank. */
      /* Find the last non-white-space character: (but only if the
         statement began with a left brace, do not do this for
         procedure definitions). */
      for (ptr = statement_text + strlen ((char *) statement_text) - 1;	/* From last */
	  (ptr >= statement_text) && isspace (*ptr); ptr--);
      if ((ptr >= statement_text) && ('}' == *ptr))
	{			/* Right brace as last non-blank character? */
	  *ptr = ' ';		/* Overwrite also it with a blank. */
	}
    }
#endif

  return statement_text;
}


/*
 *  Compute DISPLAY_SIZE from col_desc
 */
SQLLEN
col_desc_get_display_size (col_desc_t *cd, int cli_binary_timestamp)
{
   switch ((dtp_t) cd->cd_dtp)
    {
    case DV_SHORT_INT:
      return 6;

    case DV_LONG_INT:
      return 11;

    case DV_INT64:
      return 20;

    case DV_SINGLE_FLOAT:
    case DV_DOUBLE_FLOAT:
      return 22;

    case DV_NUMERIC:
      return 2 + unbox (cd->cd_precision);

    case DV_ANY:
    case DV_STRING:
    case DV_UNAME:
    case DV_BLOB:
    case DV_BLOB_WIDE:
    case DV_BLOB_XPER:
    case DV_WIDE:
    case DV_LONG_WIDE:
      return unbox (cd->cd_precision);

    case DV_BIN:
    case DV_BLOB_BIN:
      return 2 * unbox (cd->cd_precision);

    case DV_DATE:
      return 10;

    case DV_TIMESTAMP:
      {
	int scale = unbox (cd->cd_scale);

	if (cli_binary_timestamp)
	  return 2 * unbox (cd->cd_precision);	/* SQL_BINARY */
 	else if (scale)
	  return 20 + scale;
	else
	  return 19;
      }

    case DV_DATETIME:
      {
	int scale = unbox (cd->cd_scale);

 	if (scale)
	  return 20 + scale;
	else
	  return 19;
      }

    case DV_TIME:
      {
	int scale = unbox (cd->cd_scale);

 	if (scale)
	  return 9 + scale;
	else
	  return 8;
      }

    case DV_IRI_ID:
	return 23; /* i# + 20 digits precision */

    default:
      return SQL_NO_TOTAL;
    }
}

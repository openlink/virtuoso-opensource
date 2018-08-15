/*
 *  CLIcr.c
 *
 *  $Id$
 *
 *  Client API, ODBC Extensions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

#define SQL_ROW_SUCCESS 		0
#define SQL_ROW_DELETED 		1
#define SQL_ROW_UPDATED 		2
#define SQL_ROW_NOROW			3
#define SQL_ROW_ADDED			4
#define SQL_ROW_ERROR			5


int
qa_to_row_stat (int rstat)
{
  switch (rstat)
    {
    case QA_ROW:
      rstat = SQL_ROW_SUCCESS;
      break;

    case QA_ROW_ADDED:
      rstat = SQL_ROW_ADDED;
      break;

    case QA_ROW_UPDATED:
      rstat = SQL_ROW_UPDATED;
      break;

    case QA_ROW_DELETED:
      rstat = SQL_ROW_DELETED;
      break;
    }

  return rstat;
}


long
stmt_row_bookmark (cli_stmt_t * stmt, caddr_t * row)
{
  long *bmidp;
  long bmid;
  cli_connection_t *con = stmt->stmt_connection;
  caddr_t bm;
  int len;

  if (!stmt->stmt_opts->so_use_bookmarks)
    return 0;

  IN_CON (con);

  if (!con->con_bookmarks)
    con->con_bookmarks = hash_table_allocate (101);

  if (!stmt->stmt_bookmarks)
    {
      stmt->stmt_bookmarks = hash_table_allocate (101);
      stmt->stmt_bookmarks_rev = id_tree_hash_create (101);
    }

  con->con_last_bookmark++;
  len = BOX_ELEMENTS (row);
  bm = row[len - 2];

  bmidp = (long *) id_hash_get (stmt->stmt_bookmarks_rev, (caddr_t) & bm);
  if (bmidp)
    {
      LEAVE_CON (con);
      return (*bmidp);
    }

  bmid = con->con_last_bookmark;
  bm = box_copy_tree (bm);
  sethash ((void *) (ptrlong) bmid, stmt->stmt_bookmarks, (void *) bm);
  id_hash_set (stmt->stmt_bookmarks_rev, (caddr_t) & bm, (caddr_t) & bmid);
  sethash ((void *) (ptrlong) bmid, con->con_bookmarks, (void *) bm);

  LEAVE_CON (con);

  return bmid;
}


void
stmt_free_bookmarks (cli_stmt_t * stmt)
{
  caddr_t k, id;
  dk_hash_iterator_t hit;

  if (!stmt->stmt_bookmarks)
    return;

  IN_CON (stmt->stmt_connection);

  dk_hash_iterator (&hit, stmt->stmt_bookmarks);
  while (dk_hit_next (&hit, (void **) &k, (void **) &id))
    {
      remhash ((void *) k, stmt->stmt_connection->con_bookmarks);
      dk_free_tree (id);
    }

  hash_table_free (stmt->stmt_bookmarks);
  id_hash_free (stmt->stmt_bookmarks_rev);

  LEAVE_CON (stmt->stmt_connection);
}


RETCODE
stmt_process_rowset (cli_stmt_t * stmt, int ftype, SQLULEN * pcrow)
{
  int is_error = 0;
  int rc;
  SQLULEN rssz = stmt->stmt_rowset_size;
  int inx, nth;

  if (stmt->stmt_rowset)
    dk_free_tree ((box_t) stmt->stmt_rowset);

  stmt->stmt_rowset = (caddr_t **) dk_alloc_box (rssz * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  memset (stmt->stmt_rowset, 0, rssz * sizeof (caddr_t));
  stmt->stmt_current_row = NULL;

  for (nth = 0; nth < rssz; nth++)
    {
      rc = stmt_process_result (stmt, 1);

      if (SQL_ERROR == rc)
	{
	  is_error = 1;
	  break;
	}

      if (stmt->stmt_at_end)
	break;

      stmt->stmt_rowset[nth] = (caddr_t *) stmt->stmt_prefetch_row;
      stmt->stmt_prefetch_row = NULL;
    }

  for (inx = 0; inx < nth; inx++)
    {
      int rstat = qa_to_row_stat ((int) (ptrlong) stmt->stmt_rowset[inx][0]);

      stmt_set_columns (stmt, stmt->stmt_rowset[inx], inx);

      if (stmt->stmt_row_status)
	stmt->stmt_row_status[inx] = (SQLUSMALLINT) rstat;
    }

  if (pcrow)
    *pcrow = nth;

  if (stmt->stmt_row_status)
    for (inx = nth; inx < rssz; inx++)
      stmt->stmt_row_status[inx] = SQL_ROW_NOROW;

  if (nth > 0)
    {
      stmt->stmt_current_row = stmt->stmt_rowset[0];
      stmt->stmt_current_of = 0;
    }
  else
    {
      stmt->stmt_current_row = NULL;
      stmt->stmt_current_of = -1;
    }

  stmt->stmt_rowset_fill = nth;

  if (is_error)
    return SQL_ERROR;

  if (nth == 0)
    return SQL_NO_DATA_FOUND;

  return SQL_SUCCESS;
}


int
sql_ext_fetch_fwd (SQLHSTMT hstmt, SQLULEN * pcrow, SQLUSMALLINT * rgfRowStatus)
{
  int rc = 0;
  int row_count = 0;
  STMT (stmt, hstmt);
  int inx;
  SQLULEN rssz = stmt->stmt_rowset_size;

  dk_free_tree ((box_t) stmt->stmt_rowset);
  stmt->stmt_current_row = NULL;
  stmt->stmt_rowset = (caddr_t **) dk_alloc_box (rssz * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  memset (stmt->stmt_rowset, 0, rssz * sizeof (caddr_t));

  for (inx = 0; inx < rssz; inx++)
    {
      stmt->stmt_fwd_fetch_irow = inx;
      stmt->stmt_current_of = stmt->stmt_fetch_current_of;
      rc = virtodbc__SQLFetch (hstmt, 1);
      stmt->stmt_fetch_current_of = stmt->stmt_current_of;
      stmt->stmt_fwd_fetch_irow = 0;

      if (rc == SQL_ERROR)
	break;

      if (rc == SQL_NO_DATA_FOUND)
	break;

      row_count++;
      stmt->stmt_rowset[inx] = stmt->stmt_current_row;
      stmt->stmt_current_row = NULL;

      if (rgfRowStatus)
	rgfRowStatus[inx] = SQL_ROW_SUCCESS;
    }

  if (rgfRowStatus)
    for (inx = inx; inx < rssz; inx++)
      rgfRowStatus[inx] = SQL_ROW_NOROW;

  if (row_count)
    {
      stmt_reset_getdata_status (stmt, stmt->stmt_rowset[0]);
      stmt->stmt_current_row = stmt->stmt_rowset[0];
      stmt->stmt_current_of = 0;
    }

  stmt->stmt_rowset_fill = row_count;

  if (pcrow)
    *pcrow = row_count;

  stmt->stmt_row_status = rgfRowStatus;

  if (row_count > 0 && SQL_NO_DATA_FOUND == rc)
    rc = SQL_SUCCESS;

  return rc;
}


int
sql_fetch_scrollable (cli_stmt_t * stmt)
{
  int rc;
  int co;
  SQLULEN c;

  if (-1 == stmt->stmt_current_of || stmt->stmt_current_of >= stmt->stmt_rowset_fill - 1)
    {
      col_binding_t *old_cb = stmt->stmt_cols;
      rc = virtodbc__SQLExtendedFetch ((SQLHSTMT) stmt, SQL_FETCH_NEXT, 0, &c, 0, 0);
      stmt->stmt_cols = old_cb;

      if (SQL_ERROR == rc)
	return rc;

      if (SQL_NO_DATA_FOUND == rc)
	return rc;

      stmt->stmt_current_of = 0;
    }
  else
    stmt->stmt_current_of++;

  set_error (&stmt->stmt_error, NULL, NULL, NULL);
  co = stmt->stmt_current_of;
  stmt->stmt_current_row = stmt->stmt_rowset[co];
  stmt_set_columns (stmt, stmt->stmt_current_row, 0);

  if (stmt->stmt_error.err_queue)
    return SQL_SUCCESS_WITH_INFO;

  return SQL_SUCCESS;
}


RETCODE SQL_API
virtodbc__SQLExtendedFetch (
		     SQLHSTMT hstmt,
		     SQLUSMALLINT fFetchType,
		     SQLLEN irow,
		     SQLULEN * pcrow,
		     SQLUSMALLINT * rgfRowStatus,
		     SQLLEN bookmark_offset)
{
  caddr_t bookmark = NULL;
  int rc, rc2;
  STMT (stmt, hstmt);
  stmt_options_t *so = stmt->stmt_opts;
  cli_connection_t *con = stmt->stmt_connection;

#if defined (DEBUG)
  switch (fFetchType)
    {
    case SQL_FETCH_FIRST:
      cli_dbg_printf (("SQLExtendedFetch(..., FIRST, %ld)\n", irow));
      break;

    case SQL_FETCH_NEXT:
      cli_dbg_printf (("SQLExtendedFetch(..., NEXT, %ld)\n", irow));
      break;

    case SQL_FETCH_PRIOR:
      cli_dbg_printf (("SQLExtendedFetch(..., PRIOR, %ld)\n", irow));
      break;

    case SQL_FETCH_LAST:
      cli_dbg_printf (("SQLExtendedFetch(..., LAST, %ld)\n", irow));
      break;

    case SQL_FETCH_ABSOLUTE:
      cli_dbg_printf (("SQLExtendedFetch(..., ABSOLUTE, %ld)\n", irow));
      break;

    case SQL_FETCH_BOOKMARK:
      cli_dbg_printf (("SQLExtendedFetch(..., BOOKMARK, BM %ld, %ld)\n", irow, bookmark_offset));
      break;

    case SQL_FETCH_RELATIVE:
      cli_dbg_printf (("SQLExtendedFetch(..., RELATIVE, %ld)\n", irow));
      break;

    default:
      cli_dbg_printf (("Unknown fetch"));
      break;
    }
#endif

  VERIFY_INPROCESS_CLIENT (con);

  set_error (&stmt->stmt_error, NULL, NULL, NULL);

  if (!stmt->stmt_compilation)
    {
      set_error (&stmt->stmt_error, "HY010", "CL002", "Unprepared statement in SQLExtendedFetch");

      return SQL_ERROR;
    }

  if (SQL_CURSOR_FORWARD_ONLY == stmt->stmt_opts->so_cursor_type || stmt->stmt_compilation->sc_is_select != QT_SELECT)
    {
      if (fFetchType != SQL_FETCH_NEXT)
	{
	  set_error (&stmt->stmt_error, "HY106", "CL003", "Bad fetch type for forward only cursor");

	  return SQL_ERROR;
	}

      stmt->stmt_opts->so_cursor_type = SQL_CURSOR_FORWARD_ONLY;

      return (sql_ext_fetch_fwd (hstmt, pcrow, rgfRowStatus));
    }

  if (so->so_keyset_size && ((UDWORD) so->so_keyset_size) < stmt->stmt_rowset_size)
    {
      set_error (&stmt->stmt_error, "HY107", "CL004", "Specified keyset size must be >= the rowset size");

      return SQL_ERROR;
    }

  if (SQL_FETCH_BOOKMARK == fFetchType)
    {
      if (!stmt->stmt_opts->so_use_bookmarks || !con->con_bookmarks)
	{
	  set_error (&stmt->stmt_error, "HY106", "CL005", "Bookmarks not enabled or no bookmark retrieved");

	  return SQL_ERROR;
	}

      IN_CON (con);
      bookmark = (caddr_t) gethash ((void *) irow, con->con_bookmarks);
      LEAVE_CON (con);

      irow = bookmark_offset;

      if (!bookmark)
	{
	  set_error (&stmt->stmt_error, "HY111", "CL006", "Bad bookmark for SQLExtendedFetch");

	  return SQL_ERROR;
	}
    }

  if (stmt->stmt_future)
    {
      PrpcFutureFree (stmt->stmt_future);
    }

  stmt->stmt_future = PrpcFuture (stmt->stmt_connection->con_session,
      &s_sql_extended_fetch, stmt->stmt_id, fFetchType, irow, stmt->stmt_rowset_size, stmt->stmt_opts->so_autocommit, bookmark);

  if (stmt->stmt_opts->so_rpc_timeout)
    PrpcFutureSetTimeout (stmt->stmt_future, (long) stmt->stmt_opts->so_rpc_timeout);
  else
    PrpcFutureSetTimeout (stmt->stmt_future, 2000000000L); /* infinite, 2M s = 23 days  */

  stmt->stmt_row_status = rgfRowStatus;
  rc = stmt_process_rowset (stmt, fFetchType, pcrow);

  if (rc != SQL_ERROR)
    if (stmt->stmt_opts->so_autocommit)
      {
	rc2 = stmt_process_result (stmt, 1);
	if (rc2 == SQL_ERROR)
	  rc = SQL_ERROR;
      }

  stmt->stmt_at_end = 0;
  stmt->stmt_on_first_row = 1;

  /* AC return sets at end. Besides, a dynamic cr may get new data even if at end. Always ask server whether still at end */
  if (stmt->stmt_opts->so_rpc_timeout)
    PrpcSessionResetTimeout (stmt->stmt_connection->con_session);

  return rc;
}


caddr_t *
set_pos_param_row (cli_stmt_t * stmt, int nth)
{
  int btype = stmt->stmt_bind_type;
  int n_cols = BOX_ELEMENTS (stmt->stmt_compilation->sc_columns);
  int iparam = 0;
  caddr_t *row = (caddr_t *) dk_alloc_box_zero (n_cols * sizeof (caddr_t),
      DV_ARRAY_OF_POINTER);
  col_binding_t *cb = stmt->stmt_cols;

  for (iparam = 0; iparam < n_cols; iparam++)
    {
      if (cb && cb->cb_place)
	{
	  int c_type = cb->cb_c_type;
	  char *place = cb->cb_place;
	  SQLLEN *length = cb->cb_length;
	  int rebind_offset = stmt->stmt_imp_row_descriptor ?
	      (stmt->stmt_imp_row_descriptor->d_bind_offset_ptr ? *(stmt->stmt_imp_row_descriptor->d_bind_offset_ptr) : 0) : 0;

	  place += btype == 0 ? nth * sqlc_sizeof (c_type, cb->cb_max_length) : nth * btype;
	  place += rebind_offset;
	  if (length)
	    {
	      *((char **) &length) += btype == 0 ? nth * sizeof (SDWORD) : btype * nth;
	      *((char **) &length) += rebind_offset;
	    }
	  if (length && SQL_IGNORE == *length)
	    row[iparam] = (dk_alloc_box (0, DV_IGNORE));
	  else
	    {
	      caddr_t v = buffer_to_dv (place, length, c_type, c_type, BHID (nth, iparam + 1), NULL, CON_IS_INPROCESS (stmt->stmt_connection));
	      row[iparam] = v;

	      if (IS_BOX_POINTER (v) && DV_DAE == box_tag (v))
		dk_set_push (&stmt->stmt_dae, &row[iparam]);
	    }
	  /* never a BLOB handle, since c_type never == SQL_ONGxx */
	}
      else
	row[iparam] = dk_alloc_box (0, DV_IGNORE);

      if (cb)
	cb = cb->cb_next;
    }

  return row;
}


SQLRETURN SQL_API
SQLSetPos (
    SQLHSTMT		hstmt,
    SQLSETPOSIROW	irow,
    SQLUSMALLINT	fOption,
    SQLUSMALLINT	fLock)
{
  return virtodbc__SQLSetPos (hstmt, irow, fOption, fLock);
}


SQLRETURN SQL_API
virtodbc__SQLSetPos (
    SQLHSTMT		hstmt,
    SQLSETPOSIROW	_irow,
    SQLUSMALLINT	fOption,
    SQLUSMALLINT	fLock)
{
  sql_error_rec_t *err_queue = NULL;
  int irow = (int) _irow;
  STMT (stmt, hstmt);
  int n_rows = (int) (irow != 0 ? 1 : (fOption == SQL_ADD ? stmt->stmt_rowset_size : stmt->stmt_rowset_fill));
  /* insert irow==0 is by rowset sz, others are by rowset fill */
  int inx = 0, rc = 0, firstinx = 0, lastinx = 0;
  int co = irow == 0 ? 0 : irow - 1;
  cli_stmt_t *sps = NULL;
  long op = fOption;
  long row_no = irow;
  caddr_t *params = NULL;
  int all_errors = 1;

  stmt->stmt_pending.p_api = SQL_API_SQLSETPOS;
  stmt->stmt_pending.psp_op = fOption;
  stmt->stmt_pending.psp_irow = irow;
  set_error (&stmt->stmt_error, NULL, NULL, NULL);

  if (stmt->stmt_fetch_mode != FETCH_EXT)
    {
      if (!irow && fOption == SQL_POSITION && fLock == SQL_LOCK_NO_CHANGE)
	return SQL_SUCCESS;	/* this is NOP in fact */

      set_error (&stmt->stmt_error, "S1010", "CL007", "SQLSetPos only allowed after SQLExtendedFetch");

      return SQL_ERROR;
    }

  if (co >= stmt->stmt_rowset_fill && op != SQL_ADD)
    {
      set_error (&stmt->stmt_error, "HY092", "CL008", "SQLSetPos irow out of range");

      return SQL_ERROR;
    }

  if (fOption != SQL_REFRESH)
    {
      stmt->stmt_current_of = co;
      stmt_reset_getdata_status (stmt, stmt->stmt_rowset[co]);
      stmt->stmt_current_row = stmt->stmt_rowset[co];
    }

  if (fOption == SQL_POSITION)
    return SQL_SUCCESS;

  if (stmt->stmt_opts->so_cursor_type == SQL_CURSOR_FORWARD_ONLY)
    {
      set_error (&stmt->stmt_error, "HY109", "CL009", "Only SQL_POSITION SQLSetPos option supported for forward cursors");

      return SQL_ERROR;
    }

  if (!stmt->stmt_set_pos_stmt)
    {
      virtodbc__SQLAllocStmt ((SQLHDBC) stmt->stmt_connection, (SQLHSTMT *) & stmt->stmt_set_pos_stmt);
      virtodbc__SQLPrepare ((SQLHSTMT) stmt->stmt_set_pos_stmt, (SQLCHAR *) "__set_pos (?, ?, ?, ?)", SQL_NTS);
    }

  sps = stmt->stmt_set_pos_stmt;

  if (fOption == SQL_POSITION)
    {
      stmt->stmt_current_of = irow;

      return SQL_SUCCESS;
    }

  if (SQL_UPDATE == fOption || SQL_ADD == fOption)
    {
      params = stmt->stmt_param_array;

      if (!params)
	{
	  if (0 == irow)
	    {
	      params = (caddr_t *) dk_alloc_box_zero (n_rows * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	      for (inx = 0; inx < n_rows; inx++)
		{
		  if (NULL == (params[inx] = (caddr_t) set_pos_param_row (stmt, inx)))
		    {
		      dk_free_tree ((box_t) params);
		      return SQL_ERROR;
		    }
		}
	    }
	  else if (NULL == (params = set_pos_param_row (stmt, irow - 1)))
	    return SQL_ERROR;

	  if (stmt->stmt_dae)
	    {
	      stmt->stmt_status = STS_LOCAL_DAE;
	      stmt->stmt_param_array = params;

	      return SQL_NEED_DATA;
	    }
	}

      stmt->stmt_param_array = NULL;
    }

  memset (&stmt->stmt_pending, 0, sizeof (pending_call_t));

  virtodbc__SQLSetParam ((SQLHSTMT) sps, 1, SQL_C_CHAR, SQL_VARCHAR, 0, 0, stmt->stmt_id, NULL);
  virtodbc__SQLSetParam ((SQLHSTMT) sps, 2, SQL_C_LONG, SQL_INTEGER, 0, 0, &op, NULL);
  virtodbc__SQLSetParam ((SQLHSTMT) sps, 3, SQL_C_LONG, SQL_INTEGER, 0, 0, &row_no, NULL);
  virtodbc__SQLSetParam ((SQLHSTMT) sps, 4, SQL_C_BOX, SQL_VARCHAR, 0, 0, &params, NULL);

  stmt->stmt_status = STS_SERVER_DAE;
  rc = virtodbc__SQLExecDirect ((SQLHSTMT) sps, NULL, 0);
  dk_free_tree ((caddr_t) params);

  if (SQL_ERROR == rc)
    {
      err_queue_append (&stmt->stmt_error.err_queue, &sps->stmt_error.err_queue);
      return SQL_ERROR;
    }
  if (0 == irow)
    {
      firstinx = 0;
      lastinx = n_rows;
    }
  else
    {
      firstinx = irow - 1;
      lastinx = irow;
    }

  for (inx = firstinx; inx < lastinx; inx++)
    {
      rc = stmt_process_result ((cli_stmt_t *) sps, 1);

      if (SQL_ERROR == rc)
	{
	  sql_error_rec_t *err1 = cli_make_error ("01S01", "CL082", "Error in row in SQLSetPos", 0);

	  if (stmt->stmt_row_status)
	    stmt->stmt_row_status[inx] = SQL_ROW_ERROR;

	  err_queue_append (&err_queue, &err1);
	  err_queue_append (&err_queue, &sps->stmt_error.err_queue);
	}
      else if (rc == SQL_SUCCESS && sps->stmt_prefetch_row)
	{
	  long stat = (long) unbox (((caddr_t *) sps->stmt_prefetch_row)[0]);

	  if (stmt->stmt_row_status)
	    stmt->stmt_row_status[inx] = qa_to_row_stat (stat);

	  stmt_set_columns (stmt, (caddr_t *) sps->stmt_prefetch_row, inx);
	  dk_free_tree ((caddr_t) stmt->stmt_rowset[inx]);
	  stmt->stmt_rowset[inx] = (caddr_t *) sps->stmt_prefetch_row;
	  sps->stmt_prefetch_row = NULL;
	  all_errors = 0;
	}
      else
	{
	  int stat = SQL_ROW_SUCCESS;

	  all_errors = 0;
	  switch (op)
	    {
	    case SQL_UPDATE:
	      stat = SQL_ROW_UPDATED;
	      break;

	    case SQL_DELETE:
	      stat = SQL_ROW_DELETED;
	      break;

	    case SQL_ADD:
	      stat = SQL_ROW_ADDED;
	      break;
	    }

	  if (stmt->stmt_row_status)
	    stmt->stmt_row_status[inx] = stat;
	}
    }

  if (SQL_REFRESH == fOption)
    stmt->stmt_current_row = stmt->stmt_rowset[co];

  stmt->stmt_rows_affected = sps->stmt_rows_affected;
  rc = stmt_process_result (sps, 1);	/* the ret from the proc call, w/ possible autocommit txn error code */

  if (rc == SQL_ERROR)
    err_queue_append (&err_queue, &sps->stmt_error.err_queue);

  if (rc == SQL_NO_DATA_FOUND)
    rc = SQL_SUCCESS;

  if (SQL_SUCCESS == rc && err_queue)
    {
      if (all_errors)
	rc = SQL_ERROR;
      else
	rc = SQL_SUCCESS_WITH_INFO;
    }

  set_error (&stmt->stmt_error, NULL, NULL, NULL);
  stmt->stmt_error.err_queue = err_queue;
  stmt->stmt_error.err_queue_head = err_queue;

  return (rc);
}

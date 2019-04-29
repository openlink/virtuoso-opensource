/*
 *  CLIodbc3.c
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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
#include "sqlver.h"
#include "multibyte.h"

#ifndef WIN32
#define UNALIGNED
#endif


/**** SQLAllocHandle ****/

SQLRETURN SQL_API
SQLAllocHandle (SQLSMALLINT handleType,
    SQLHANDLE inputHandle,
    SQLHANDLE * outputHandlePtr)
{
  return virtodbc__SQLAllocHandle (handleType, inputHandle, outputHandlePtr);
}


SQLRETURN SQL_API
virtodbc__SQLAllocHandle (SQLSMALLINT handleType,
    SQLHANDLE inputHandle,
    SQLHANDLE * outputHandlePtr)
{
  SQLRETURN rc;

  switch (handleType)
    {

    case SQL_HANDLE_ENV:
      cli_dbg_printf (("SQLAllocHandle(ENV, ...) called\n"));
      return virtodbc__SQLAllocEnv ((SQLHENV *) outputHandlePtr);

    case SQL_HANDLE_DBC:
      cli_dbg_printf (("SQLAllocHandle(DBC, ...) called\n"));
      return virtodbc__SQLAllocConnect ((SQLHENV) inputHandle, (SQLHDBC *) outputHandlePtr);

    case SQL_HANDLE_STMT:
      cli_dbg_printf (("SQLAllocHandle(STMT, ...) called\n"));
      return virtodbc__SQLAllocStmt ((SQLHDBC) inputHandle, (SQLHSTMT *) outputHandlePtr);

    case SQL_HANDLE_DESC:
      cli_dbg_printf (("SQLAllocHandle(DESC, ...) called\n"));
      return SQL_ERROR;

    default:
      cli_dbg_printf (("SQLAllocHandle(UNKNOWN, ...) called\n"));
      break;

    }

  return (SQL_SUCCESS);
}


/**** SQLFreeHandle ****/

SQLRETURN SQL_API
SQLFreeHandle (SQLSMALLINT handleType,
    SQLHANDLE handle)
{
  return virtodbc__SQLFreeHandle (handleType, handle);
}


SQLRETURN SQL_API
virtodbc__SQLFreeHandle (SQLSMALLINT handleType,
    SQLHANDLE handle)
{
  STMT (stmt, handle);

  switch (handleType)
    {

    case SQL_HANDLE_ENV:
      cli_dbg_printf (("SQLFreeHandle(ENV, ...) called\n"));
      return virtodbc__SQLFreeEnv ((SQLHENV) handle);

    case SQL_HANDLE_DBC:
      cli_dbg_printf (("SQLFreeHandle(DBC, ...) called\n"));
      return virtodbc__SQLFreeConnect ((SQLHDBC) handle);

    case SQL_HANDLE_STMT:
      cli_dbg_printf (("SQLFreeHandle(STMT, ...) called\n"));
      return virtodbc__SQLFreeStmt ((SQLHSTMT) handle, SQL_DROP);

    case SQL_HANDLE_DESC:
      cli_dbg_printf (("SQLFreeHandle(DESC, ...) called\n"));
      return SQL_ERROR;

    default:
      cli_dbg_printf (("SQLFreeHandle(UNKNOWN, ...) called\n"));
      break;
    }

  return (SQL_SUCCESS);
}


/**** SQLSetEnvAttr ****/

SQLRETURN SQL_API
SQLSetEnvAttr (SQLHENV environmentHandle,
    SQLINTEGER Attribute,
    SQLPOINTER ValuePtr,
    SQLINTEGER StringLength)
{
  ENV (env, environmentHandle);
  if (!env)
    return (SQL_INVALID_HANDLE);
  set_error (&env->env_error, NULL, NULL, NULL);

  switch (Attribute)
    {
    case SQL_ATTR_CONNECTION_POOLING:

      cli_dbg_printf (("SQLSetEnvAttr(..., CONN_POOLING, ...)\n"));

      switch ((SQLINTEGER) (ptrlong) ValuePtr)
	{
	case SQL_CP_OFF:
	case SQL_CP_ONE_PER_DRIVER:
	case SQL_CP_ONE_PER_HENV:
	  env->env_connection_pooling = (SQLINTEGER) (ptrlong) ValuePtr;
	  break;
	}
      break;

    case SQL_ATTR_CP_MATCH:
      cli_dbg_printf (("SQLSetEnvAttr(..., CP_MATCH, ...)\n"));
      switch ((SQLINTEGER) (ptrlong) ValuePtr)
	{
	case SQL_CP_STRICT_MATCH:
	case SQL_CP_RELAXED_MATCH:
	  env->env_cp_match = (SQLINTEGER) (ptrlong) ValuePtr;
	  break;
	}
      break;

    case SQL_ATTR_ODBC_VERSION:
      cli_dbg_printf (("SQLSetEnvAttr(..., ODBC_VERSION, ...)\n"));
      switch ((SQLINTEGER) (ptrlong) ValuePtr)
	{
	case SQL_OV_ODBC2:
	case SQL_OV_ODBC3:
	  env->env_odbc_version = (SQLINTEGER) (ptrlong) ValuePtr;
	  break;
	}
      break;

    case SQL_ATTR_OUTPUT_NTS:
      cli_dbg_printf (("SQLSetEnvAttr(..., ATTR_OUTPUT_NTS, ...)\n"));
      switch ((SQLINTEGER) (ptrlong) ValuePtr)
	{
	case SQL_TRUE:
	  env->env_output_nts = SQL_TRUE;
	  break;

	case SQL_FALSE:
	  env->env_output_nts = SQL_FALSE;
	  break;
	}
      break;
    }

  return (SQL_SUCCESS);
}


/**** SQLGetEnvAttr ****/

SQLRETURN SQL_API
SQLGetEnvAttr (SQLHENV environmentHandle,
    SQLINTEGER Attribute,
    SQLPOINTER ValuePtr,
    SQLINTEGER BufferLength,
    SQLINTEGER * StringLengthPtr)
{
  ENV (env, environmentHandle);

  if (!env)
    return (SQL_INVALID_HANDLE);

  set_error (&env->env_error, NULL, NULL, NULL);

  switch (Attribute)
    {
    case SQL_ATTR_CONNECTION_POOLING:
      cli_dbg_printf (("SQLGetEnvAttr(..., CONN_POOLING, ...)\n"));
      *((SQLINTEGER *) ValuePtr) = SQL_CP_OFF;
      break;

    case SQL_ATTR_CP_MATCH:
      cli_dbg_printf (("SQLGetEnvAttr(..., CP_MATCH, ...)\n"));
      *((SQLINTEGER *) ValuePtr) = env->env_cp_match;
      break;

    case SQL_ATTR_ODBC_VERSION:
      cli_dbg_printf (("SQLGetEnvAttr(..., ODBC_VERSION, ...)\n"));
      *((SQLINTEGER *) ValuePtr) = env->env_odbc_version;
      break;

    case SQL_ATTR_OUTPUT_NTS:
      cli_dbg_printf (("SQLGetEnvAttr(..., ATTR_OUTPUT_NTS, ...)\n"));
      *((SQLINTEGER *) ValuePtr) = (env->env_output_nts ? SQL_TRUE : SQL_FALSE);
      break;
    }
  return (SQL_SUCCESS);
}


int
error_rec_count (sql_error_t * err)
{
  if (err)
    {
      sql_error_rec_t *rec;
      int nCount = 0;

      if (err->err_queue && !err->err_queue_head)
	err->err_queue_head = err->err_queue;

      if (!err->err_queue && err->err_queue_head)
	err->err_queue_head = NULL;

      rec = err->err_queue_head;
      while (rec)
	{
	  nCount += 1;
	  rec = rec->sql_error_next;
	}

      return nCount;
    }

  return 0;
}


sql_error_rec_t *
error_goto_record (sql_error_t * err, int nRecord)
{
  if (err)
    {
      sql_error_rec_t *rec;
      int nIndex = 1;

      if (err->err_queue && !err->err_queue_head)
	err->err_queue_head = err->err_queue;

      if (!err->err_queue && err->err_queue_head)
	err->err_queue_head = NULL;

      rec = err->err_queue_head;
      while (rec && nIndex < nRecord)
	{
	  nIndex += 1;
	  rec = rec->sql_error_next;
	}

      if (rec)
	{
	  err->err_queue = rec;
	  return rec;
	}
    }

  return (NULL);
}



/**** SQLGetDiagRec ****/

SQLRETURN SQL_API
virtodbc__SQLGetDiagRec (SQLSMALLINT HandleType,
    SQLHANDLE Handle,
    SQLSMALLINT RecNumber,
    SQLCHAR * Sqlstate,
    SQLINTEGER * NativeErrorPtr,
    SQLCHAR * MessageText,
    SQLSMALLINT BufferLength,
    SQLSMALLINT * TextLengthPtr)
{
  ENV (env, Handle);
  CON (con, Handle);
  STMT (stmt, Handle);
  DESC (desc, Handle);
  sql_error_t *err;
  int nRecs;
  SQLRETURN rc;
  SQLUSMALLINT pcbSqlstate;

  switch (HandleType)
    {
    case SQL_HANDLE_ENV:
      err = &env->env_error;
      break;

    case SQL_HANDLE_DBC:
      err = &con->con_error;
      break;

    case SQL_HANDLE_STMT:
      err = &stmt->stmt_error;
      break;

    case SQL_HANDLE_DESC:
      err = &desc->d_stmt->stmt_error;
      break;

    default:
      return SQL_INVALID_HANDLE;
    }

  nRecs = error_rec_count (err);

  cli_dbg_printf (("SQLGetDiagRec called\n"));

  if (RecNumber > nRecs)
    {
      V_SET_ODBC_STR ("00000", Sqlstate, 6, &pcbSqlstate, NULL);

      return SQL_NO_DATA_FOUND;
    }

  if (BufferLength < 0)
    return (SQL_ERROR);

  if (error_goto_record (err, RecNumber))
    return virtodbc__SQLError (
	(SQLHENV) (HandleType == SQL_HANDLE_ENV ? Handle : SQL_NULL_HANDLE),
	(SQLHDBC) (HandleType == SQL_HANDLE_DBC ? Handle : SQL_NULL_HANDLE),
	(SQLHSTMT) (HandleType == SQL_HANDLE_STMT ? Handle : (HandleType == SQL_HANDLE_DESC ? desc->d_stmt : SQL_NULL_HANDLE)),
	Sqlstate, NativeErrorPtr, MessageText, BufferLength, TextLengthPtr, SQL_FALSE);
  else
    {
      V_SET_ODBC_STR ("00000", Sqlstate, 6, &pcbSqlstate, NULL);

      return (SQL_NO_DATA_FOUND);
    }
}


SQLRETURN SQL_API
SQLGetDiagRec (SQLSMALLINT HandleType,
    SQLHANDLE Handle,
    SQLSMALLINT RecNumber,
    SQLCHAR * wszSqlState,
    SQLINTEGER * NativeErrorPtr,
    SQLCHAR * wszMessageText,
    SQLSMALLINT cbMessageText,
    SQLSMALLINT * pcbMessageText)
{
  CON (con, Handle);
  STMT (stmt, Handle);
  DESC (desc, Handle);
  SQLCHAR szSqlState[6];
  SQLRETURN rc;
  cli_connection_t *conn;

  switch (HandleType)
    {
    case SQL_HANDLE_DBC:
      conn = con;
      break;

    case SQL_HANDLE_STMT:
      conn = stmt->stmt_connection;
      break;

    case SQL_HANDLE_DESC:
      conn = desc->d_stmt->stmt_connection;
      break;

    default:
      conn = NULL;
      break;
    }

  if (conn)
    {
      NDEFINE_OUTPUT_CHAR_NARROW (MessageText, conn, SQLSMALLINT);

      NMAKE_OUTPUT_CHAR_NARROW (MessageText, conn);

      rc = virtodbc__SQLGetDiagRec (HandleType, Handle, RecNumber, szSqlState,
	  NativeErrorPtr, szMessageText, _cbMessageText, _pcbMessageText);

      NSET_AND_FREE_OUTPUT_CHAR_NARROW (MessageText, conn);
    }
  else
    {
      return virtodbc__SQLGetDiagRec (HandleType, Handle, RecNumber,
	  wszSqlState, NativeErrorPtr, wszMessageText, cbMessageText, pcbMessageText);
    }

  if (wszSqlState)
    memcpy (wszSqlState, szSqlState, 6);

  return rc;
}


static SQLINTEGER
__setStringValue (const char *szNewValue, char *szDest, SQLINTEGER destLength)
{

  SQLINTEGER len = (SQLINTEGER) strlen (szNewValue);

  if (destLength > 0)
    {
      strncpy (szDest, szNewValue, destLength);
      szDest[destLength - 1] = '\x0';
    }

  return len;
}

#define setStringValue(nv, dest, destlen, pdestlen) \
	if (pdestlen) \
	  *pdestlen = __setStringValue(nv,  (char *) dest, destlen); \
        else \
	  __setStringValue(nv,  (char *) dest, destlen)

#define setStringValueS(nv, dest, destlen, pdestlen) \
	if (pdestlen) \
	  *pdestlen = (SQLSMALLINT) __setStringValue(nv,  (char *) dest, (SQLSMALLINT) destlen); \
        else \
	  __setStringValue(nv, (char *) dest, (SQLSMALLINT) destlen)

/**** SQLGetDiagField ****/

SQLRETURN SQL_API
virtodbc__SQLGetDiagField (SQLSMALLINT nHandleType,
    SQLHANDLE Handle,
    SQLSMALLINT nRecNumber,
    SQLSMALLINT nDiagIdentifier,
    SQLPOINTER pDiagInfoPtr,
    SQLSMALLINT nBufferLength,
    SQLSMALLINT * pnStringLengthPtr)
{
  ENV (env, Handle);
  CON (con, Handle);
  STMT (stmt, Handle);
  DESC (desc, Handle);
  sql_error_t *err;
  SQLRETURN rc = SQL_SUCCESS;

  switch (nHandleType)
    {
    case SQL_HANDLE_ENV:
      err = &env->env_error;
      break;

    case SQL_HANDLE_DBC:
      err = &con->con_error;
      break;

    case SQL_HANDLE_STMT:
      err = &stmt->stmt_error;
      break;

    case SQL_HANDLE_DESC:
      err = &desc->d_stmt->stmt_error;
      stmt = desc->d_stmt;
      break;

    default:
      return SQL_INVALID_HANDLE;
    }

  cli_dbg_printf (("SQLGetDiagField called\n"));

  if (!Handle)
    return (SQL_INVALID_HANDLE);

  switch (nRecNumber)
    {
    case 0:			/* Header record */

      switch (nDiagIdentifier)
	{

	case SQL_DIAG_CURSOR_ROW_COUNT:
	  if (nHandleType != SQL_HANDLE_STMT)
	    return (SQL_ERROR);
	  if (!pDiagInfoPtr)
	    return (SQL_SUCCESS_WITH_INFO);

	  (*(SQLINTEGER *) pDiagInfoPtr) = stmt->stmt_rows_affected;
	  break;

	case SQL_DIAG_DYNAMIC_FUNCTION_CODE:

	  if (nHandleType != SQL_HANDLE_STMT)
	    return (SQL_ERROR);
	  if (!pDiagInfoPtr)
	    return (SQL_SUCCESS_WITH_INFO);

	  if (stmt->stmt_compilation)
	    {
	      switch (stmt->stmt_compilation->sc_is_select)
		{
		case QT_UPDATE:
		  *((SQLINTEGER *) pDiagInfoPtr) = SQL_DIAG_UPDATE_WHERE;
		  break;
		case QT_SELECT:
		  *((SQLINTEGER *) pDiagInfoPtr) = SQL_DIAG_SELECT_CURSOR;
		  break;
		case QT_PROC_CALL:
		  *((SQLINTEGER *) pDiagInfoPtr) = SQL_DIAG_CALL;
		  break;
		default:
		  *((SQLINTEGER *) pDiagInfoPtr) = SQL_DIAG_UNKNOWN_STATEMENT;
		}
	    }
	  else
	    return (SQL_NO_DATA_FOUND);

	  break;

	case SQL_DIAG_DYNAMIC_FUNCTION:

	  if (nHandleType != SQL_HANDLE_STMT)
	    return (SQL_ERROR);
	  if (!pDiagInfoPtr)
	    return (SQL_SUCCESS_WITH_INFO);

	  if (nHandleType == SQL_HANDLE_STMT && stmt->stmt_compilation)
	    {
	      switch (stmt->stmt_compilation->sc_is_select)
		{
		case QT_UPDATE:
		  setStringValueS ("UPDATE WHERE", (SQLCHAR *) pDiagInfoPtr, nBufferLength, pnStringLengthPtr);
		  break;

		case QT_SELECT:
		  setStringValueS ("SELECT CURSOR", (SQLCHAR *) pDiagInfoPtr, nBufferLength, pnStringLengthPtr);
		  break;

		case QT_PROC_CALL:
		  setStringValueS ("CALL", (SQLCHAR *) pDiagInfoPtr, nBufferLength, pnStringLengthPtr);
		  break;

		default:
		  setStringValueS ("", (SQLCHAR *) pDiagInfoPtr, nBufferLength, pnStringLengthPtr);
		  break;
		}
	    }
	  else
	    return (SQL_NO_DATA_FOUND);

	  break;

	case SQL_DIAG_RETURNCODE:
	  if (err)
	    *((SQLRETURN *) pDiagInfoPtr) = err->err_rc;
	  break;

	case SQL_DIAG_NUMBER:

	  (*(SQLINTEGER *) pDiagInfoPtr) = error_rec_count (err);
	  break;

	}
      return (SQL_SUCCESS);

    default:			/* status records */
      {
	sql_error_rec_t *rec = error_goto_record (err, nRecNumber);

	if (!rec)
	  return (SQL_NO_DATA_FOUND);

	switch (nDiagIdentifier)
	  {

	  case SQL_DIAG_SUBCLASS_ORIGIN:
	  case SQL_DIAG_CLASS_ORIGIN:
	    {
	      const char *szDiagInfo = !strncmp (rec->sql_state, "IM", 2) ? "ODBC 3.0" : "ISO 9075";

	      V_SET_ODBC_STR (szDiagInfo, pDiagInfoPtr, nBufferLength, pnStringLengthPtr, NULL);
	    }
	    break;

	  case SQL_DIAG_COLUMN_NUMBER:
	    if (nHandleType != SQL_HANDLE_STMT)
	      return (SQL_ERROR);

	    *((SQLINTEGER *) pDiagInfoPtr) = SQL_COLUMN_NUMBER_UNKNOWN;
	    break;

	  case SQL_DIAG_SERVER_NAME:
	  case SQL_DIAG_CONNECTION_NAME:
	    if (nHandleType == SQL_HANDLE_ENV)
	      {
		V_SET_ODBC_STR ("", pDiagInfoPtr, nBufferLength, pnStringLengthPtr, NULL);
	      }
	    else
	      {
		cli_connection_t *dest_conn = (nHandleType == SQL_HANDLE_DBC ? con : stmt->stmt_connection);
		V_SET_ODBC_STR (dest_conn->con_dsn ? dest_conn->con_dsn : (SQLCHAR *) "", pDiagInfoPtr, nBufferLength, pnStringLengthPtr, NULL);
	      }
	    break;

	  case SQL_DIAG_MESSAGE_TEXT:
	    V_SET_ODBC_STR (rec->sql_error_msg, pDiagInfoPtr, nBufferLength, pnStringLengthPtr, NULL);
	    break;

	  case SQL_DIAG_NATIVE:

	    *((SQLINTEGER *) pDiagInfoPtr) = -1;
	    break;

	  case SQL_DIAG_ROW_NUMBER:

	    if (nHandleType != SQL_HANDLE_STMT)
	      return (SQL_ERROR);
	    *((SQLINTEGER *) pDiagInfoPtr) = SQL_ROW_NUMBER_UNKNOWN;
	    break;

	  case SQL_DIAG_SQLSTATE:

	    V_SET_ODBC_STR (!rec->sql_state ? "00000" : rec->sql_state, pDiagInfoPtr, nBufferLength, pnStringLengthPtr, NULL);
	    break;

	  }
	break;
      }
    }

  return (rc);
}


SQLRETURN SQL_API
SQLGetDiagField (SQLSMALLINT nHandleType,
    SQLHANDLE Handle,
    SQLSMALLINT nRecNumber,
    SQLSMALLINT nDiagIdentifier,
    SQLPOINTER pDiagInfoPtr,
    SQLSMALLINT nBufferLength,
    SQLSMALLINT * pnStringLengthPtr)
{
  CON (con, Handle);
  STMT (stmt, Handle);
  DESC (desc, Handle);

  switch (nDiagIdentifier)
    {
    case SQL_DIAG_DYNAMIC_FUNCTION:
    case SQL_DIAG_SUBCLASS_ORIGIN:
    case SQL_DIAG_CLASS_ORIGIN:
    case SQL_DIAG_SERVER_NAME:
    case SQL_DIAG_CONNECTION_NAME:
    case SQL_DIAG_MESSAGE_TEXT:
    case SQL_DIAG_SQLSTATE:
      {
	SQLRETURN rc;
	cli_connection_t *conn = (nHandleType == SQL_HANDLE_DBC ? con :
	    (nHandleType == SQL_HANDLE_STMT ? stmt->stmt_connection :
		(nHandleType == SQL_HANDLE_DESC ? desc->d_stmt->stmt_connection : NULL)));

	NDEFINE_OUTPUT_NONCHAR_NARROW (pDiagInfoPtr, nBufferLength, pnStringLengthPtr, conn, SQLSMALLINT);

	NMAKE_OUTPUT_NONCHAR_NARROW (pDiagInfoPtr, nBufferLength, conn);

	rc = virtodbc__SQLGetDiagField (nHandleType, Handle, nRecNumber,
	    nDiagIdentifier, _pDiagInfoPtr, _nBufferLength, _pnStringLengthPtr);

	NSET_AND_FREE_OUTPUT_NONCHAR_NARROW (pDiagInfoPtr, nBufferLength, pnStringLengthPtr, conn);

	return rc;
      }

    default:
      return virtodbc__SQLGetDiagField (nHandleType, Handle, nRecNumber,
	  nDiagIdentifier, pDiagInfoPtr, nBufferLength, pnStringLengthPtr);
    }
}


/**** SQLGetStmtAttr ****/

SQLRETURN SQL_API
virtodbc__SQLGetStmtAttr (SQLHSTMT statementHandle,
    SQLINTEGER Attribute,
    SQLPOINTER ValuePtr,
    SQLINTEGER BufferLength,
    SQLINTEGER * StringLengthPtr)
{
  SQLLEN dummy = 0;
  STMT (stmt, statementHandle);
  if (!stmt)
    return (SQL_INVALID_HANDLE);
  if (!ValuePtr)
    ValuePtr = &dummy;

  set_error (&stmt->stmt_error, NULL, NULL, NULL);

  switch (Attribute)
    {
    case SQL_ATTR_IMP_PARAM_DESC:
      cli_dbg_printf (("SQLGetStmtAttr(..., IMP_PARAM_DESC, ...) called\n"));
      *((SQLHANDLE *) ValuePtr) = (SQLHANDLE *) stmt->stmt_imp_param_descriptor;
      if (StringLengthPtr)
	*StringLengthPtr = SQL_IS_POINTER;
      break;

    case SQL_ATTR_APP_PARAM_DESC:
      cli_dbg_printf (("SQLGetStmtAttr(..., APP_PARAM_DESC, ...) called\n"));
      *((SQLHANDLE *) ValuePtr) = (SQLHANDLE *) stmt->stmt_app_param_descriptor;
      if (StringLengthPtr)
	*StringLengthPtr = SQL_IS_POINTER;
      break;

    case SQL_ATTR_IMP_ROW_DESC:
      cli_dbg_printf (("SQLGetStmtAttr(..., IMP_ROW_DESC, ...) called\n"));
      *((SQLHANDLE *) ValuePtr) = (SQLHANDLE *) stmt->stmt_imp_row_descriptor;
      if (StringLengthPtr)
	*StringLengthPtr = SQL_IS_POINTER;
      break;

    case SQL_ATTR_APP_ROW_DESC:
      cli_dbg_printf (("SQLGetStmtAttr(..., APP_ROW_DESC, ...) called\n"));
      *((SQLHANDLE *) ValuePtr) = (SQLHANDLE *) stmt->stmt_app_row_descriptor;
      if (StringLengthPtr)
	*StringLengthPtr = SQL_IS_POINTER;
      break;

    case SQL_ATTR_ROW_ARRAY_SIZE:
      cli_dbg_printf (("SQLGetStmtAttr(..., ROW_ARRAY_SIZE, ...) called\n"));
      *((SQLULEN *) ValuePtr) = stmt->stmt_rowset_size;
      break;

    case SQL_ATTR_CURSOR_SCROLLABLE:
      cli_dbg_printf (("SQLGetStmtAttr(..., CURSOR_SCROLLABLE, ...) called\n"));
      *((SQLINTEGER *) ValuePtr) = SQL_NONSCROLLABLE;
      break;

    case SQL_ATTR_CURSOR_SENSITIVITY:
      cli_dbg_printf (("SQLGetStmtAttr(..., CURSOR_SENSITIVITY, ...) called\n"));
      *((SQLINTEGER *) ValuePtr) = SQL_UNSPECIFIED;
      break;

    case SQL_ATTR_ENABLE_AUTO_IPD:
      cli_dbg_printf (("SQLGetStmtAttr(..., ENABLE_AUTO_IPD, ...) called\n"));
      *((SQLINTEGER *) ValuePtr) = SQL_FALSE;
      break;

    case SQL_ATTR_FETCH_BOOKMARK_PTR:
      cli_dbg_printf (("SQLGetStmtAttr(..., FETCH_BOOKMARK_PTR, ...) called\n"));
      *((SQLPOINTER *) ValuePtr) = stmt->stmt_bookmark_ptr;
      break;

    case SQL_ATTR_METADATA_ID:
      cli_dbg_printf (("SQLGetStmtAttr(..., METADATA_ID, ...) called\n"));
      *((SQLINTEGER *) ValuePtr) = stmt->stmt_connection->con_db_casemode == 2 ? SQL_TRUE : SQL_FALSE;
      break;

    case SQL_ATTR_PARAM_BIND_OFFSET_PTR:
      cli_dbg_printf (("SQLGetStmtAttr(..., PARAM_BIND_OFFSET_PTR, ...) called\n"));
      (*(SQLINTEGER **) ValuePtr) = (stmt->stmt_imp_param_descriptor ? stmt->stmt_imp_param_descriptor->d_bind_offset_ptr : NULL);
      break;

    case SQL_ATTR_PARAM_BIND_TYPE:
      cli_dbg_printf (("SQLGetStmtAttr(..., PARAM_BIND_TYPE, ...) called\n"));
      *((SQLINTEGER *) ValuePtr) = stmt->stmt_param_bind_type;
      break;

    case SQL_ATTR_PARAM_OPERATION_PTR:
      cli_dbg_printf (("SQLGetStmtAttr(..., PARAM_OPERATION_PTR, ...) called\n"));
      *((SQLINTEGER **) ValuePtr) = NULL;
      break;

    case SQL_ATTR_PARAM_STATUS_PTR:
      cli_dbg_printf (("SQLGetStmtAttr(..., PARAM_STATUS_PTR, ...) called\n"));
      *((SQLSMALLINT **) ValuePtr) = (SQLSMALLINT *) stmt->stmt_param_status;
      break;

    case SQL_ATTR_PARAMS_PROCESSED_PTR:
      cli_dbg_printf (("SQLGetStmtAttr(..., PARAM_PROCESSED_PTR, ...) called\n"));
      *((SQLINTEGER **) ValuePtr) = (SQLINTEGER *) stmt->stmt_pirow;
      break;

    case SQL_ATTR_PARAMSET_SIZE:
      cli_dbg_printf (("SQLGetStmtAttr(..., PARAMSET_SIZE, ...) called\n"));
      *((SQLULEN *) ValuePtr) = (SQLULEN) stmt->stmt_parm_rows;
      break;

    case SQL_ATTR_ROW_BIND_OFFSET_PTR:
      cli_dbg_printf (("SQLGetStmtAttr(..., ROW_BIND_OFFSET_PTR, ...) called\n"));
      (*(SQLINTEGER **) ValuePtr) = (stmt->stmt_imp_row_descriptor ? stmt->stmt_imp_row_descriptor->d_bind_offset_ptr : NULL);
      break;

    case SQL_ATTR_ROW_OPERATION_PTR:
      cli_dbg_printf (("SQLGetStmtAttr(..., ROW_OPERATION_PTR, ...) called\n"));
      *((SQLINTEGER **) ValuePtr) = NULL;
      break;

    case SQL_ATTR_ROW_STATUS_PTR:
      cli_dbg_printf (("SQLGetStmtAttr(..., ROW_STATUS_PTR, ...) called\n"));
      *((SQLSMALLINT **) ValuePtr) = (SQLSMALLINT *) stmt->stmt_row_status;
      break;

    case SQL_ATTR_ROWS_FETCHED_PTR:
      cli_dbg_printf (("SQLGetStmtAttr(..., ROWS_FETCHED_PTR, ...) called\n"));
      *((SQLULEN **) ValuePtr) = stmt->stmt_rows_fetched_ptr;
      break;

    case SQL_ATTR_MAX_LENGTH:
      cli_dbg_printf (("SQLGetStmtAttr(..., MAX_LENGTH, ...) called\n"));
      *((SQLINTEGER *) ValuePtr) = 0;
      break;

    case SQL_ATTR_ASYNC_ENABLE:
    case SQL_ATTR_MAX_ROWS:
    case SQL_ATTR_QUERY_TIMEOUT:
    case SQL_TXN_TIMEOUT:
    case SQL_ATTR_CONCURRENCY:
    case SQL_ROWSET_SIZE:
    case SQL_ATTR_CURSOR_TYPE:
    case SQL_ATTR_KEYSET_SIZE:
    case SQL_ATTR_NOSCAN:
    case SQL_ATTR_RETRIEVE_DATA:
    case SQL_ATTR_ROW_BIND_TYPE:
    case SQL_ATTR_ROW_NUMBER:
    case SQL_ATTR_SIMULATE_CURSOR:
    case SQL_ATTR_USE_BOOKMARKS:
    case SQL_PREFETCH_SIZE:
    case SQL_UNIQUE_ROWS:
    case SQL_GETLASTSERIAL:
      cli_dbg_printf (("SQLGetStmtAttr(...) mapped to SQLGetStmtOption\n"));

      return virtodbc__SQLGetStmtOption ((SQLHSTMT) stmt, (SQLUSMALLINT) Attribute, ValuePtr);

    default:
      cli_dbg_printf (("SQLGetStmtAttr(..., UNKNOWN, ...) called\n"));
      break;
    }

  return (SQL_SUCCESS);
}


SQLRETURN SQL_API
SQLGetStmtAttr (SQLHSTMT statementHandle,
    SQLINTEGER Attribute,
    SQLPOINTER ValuePtr,
    SQLINTEGER BufferLength,
    SQLINTEGER * StringLengthPtr)
{
  return virtodbc__SQLGetStmtAttr (statementHandle, Attribute, ValuePtr, BufferLength, StringLengthPtr);
}


/**** SQLSetStmtAttr ****/

SQLRETURN SQL_API
virtodbc__SQLSetStmtAttr (SQLHSTMT statementHandle,
    SQLINTEGER Attribute,
    SQLPOINTER ValuePtr,
    SQLINTEGER StringLength)
{
  STMT (stmt, statementHandle);

  if (!stmt)
    return (SQL_INVALID_HANDLE);

  set_error (&stmt->stmt_error, NULL, NULL, NULL);

  switch (Attribute)
    {
    case SQL_ATTR_APP_PARAM_DESC:
      cli_dbg_printf (("SQLSetStmtAttr(..., APP_PARAM_DESC, ...) called\n"));
      if (ValuePtr != stmt->stmt_app_param_descriptor)
	{
	  set_error (&stmt->stmt_error, "01S02", "CL010", "Option value changed");
	  return (SQL_SUCCESS_WITH_INFO);
	}
      break;

    case SQL_ATTR_APP_ROW_DESC:
      cli_dbg_printf (("SQLSetStmtAttr(..., APP_ROW_DESC, ...) called\n"));
      if (ValuePtr != stmt->stmt_app_row_descriptor)
	{
	  set_error (&stmt->stmt_error, "01S02", "CL011", "Option value changed");
	  return (SQL_SUCCESS_WITH_INFO);
	}
      break;

    case SQL_ATTR_CURSOR_SCROLLABLE:
      cli_dbg_printf (("SQLSetStmtAttr(..., CURSOR_SCROLLABLE, ...) called\n"));
      if (((SQLINTEGER) (ptrlong) ValuePtr) != SQL_NONSCROLLABLE)
	{
	  set_error (&stmt->stmt_error, "01S02", "CL012", "Option value changed");
	  return (SQL_SUCCESS_WITH_INFO);
	}
      break;

    case SQL_ATTR_CURSOR_SENSITIVITY:
      cli_dbg_printf (("SQLSetStmtAttr(..., CURSOR_SENSITIVITY, ...) called\n"));
      if (((SQLINTEGER) (ptrlong) ValuePtr) != SQL_UNSPECIFIED)
	{
	  set_error (&stmt->stmt_error, "01S02", "CL013", "Option value changed");
	  return (SQL_SUCCESS_WITH_INFO);
	}
      break;

    case SQL_ATTR_ENABLE_AUTO_IPD:
      cli_dbg_printf (("SQLSetStmtAttr(..., ENABLE_AUTO_IPD, ...) called\n"));
      if (((SQLINTEGER) (ptrlong) ValuePtr) != SQL_FALSE)
	{
	  set_error (&stmt->stmt_error, "01S02", "CL014", "Option value changed");
	  return (SQL_SUCCESS_WITH_INFO);
	}
      break;

    case SQL_ATTR_FETCH_BOOKMARK_PTR:
      cli_dbg_printf (("SQLSetStmtAttr(..., FETCH_BOOKMARK_PTR, ...) called\n"));
      stmt->stmt_bookmark_ptr = (SQLLEN *) ValuePtr;
      break;

    case SQL_ATTR_METADATA_ID:
      cli_dbg_printf (("SQLSetStmtAttr(..., METADATA_ID, ...) called\n"));
      stmt->stmt_connection->con_db_casemode = ((SQLINTEGER) (ptrlong) ValuePtr) == SQL_TRUE ? 2 : 1;
      break;

    case SQL_ATTR_PARAM_BIND_OFFSET_PTR:
      cli_dbg_printf (("SQLSetStmtAttr(..., PARAM_BIND_OFFSET_PTR, ...) called\n"));
      if (stmt->stmt_imp_param_descriptor)
	{
	  stmt->stmt_imp_param_descriptor->d_bind_offset_ptr = (SQLINTEGER *) ValuePtr;
	  stmt->stmt_app_param_descriptor->d_bind_offset_ptr = (SQLINTEGER *) ValuePtr;
	}
      else
	{
	  set_error (&stmt->stmt_error, "IM001", "CL015", "Driver does not support this function");
	  return (SQL_ERROR);
	}
      break;

    case SQL_ATTR_PARAM_BIND_TYPE:
      cli_dbg_printf (("SQLSetStmtAttr(..., PARAM_BIND_TYPE, ...) called\n"));
      stmt->stmt_param_bind_type = (SQLINTEGER) (ptrlong) ValuePtr;
      break;

    case SQL_ATTR_PARAM_OPERATION_PTR:
      cli_dbg_printf (("SQLSetStmtAttr(..., PARAM_OPERATION_PTR, ...) called\n"));
      if ((SQLSMALLINT *) ValuePtr)
	{
	  set_error (&stmt->stmt_error, "01S02", "CL016", "Option value changed");
	  return (SQL_ERROR);
	}
      break;

    case SQL_ATTR_PARAM_STATUS_PTR:
      cli_dbg_printf (("SQLSetStmtAttr(..., PARAM_STATUS_PTR, ...) called\n"));
      stmt->stmt_param_status = (SQLUSMALLINT *) ValuePtr;
      break;

    case SQL_ATTR_PARAMS_PROCESSED_PTR:
      cli_dbg_printf (("SQLSetStmtAttr(..., PARAM_PROCESSED_PTR, ...) called\n"));
      stmt->stmt_pirow = (SQLULEN *) ValuePtr;
      break;

    case SQL_ATTR_PARAMSET_SIZE:
      cli_dbg_printf (("SQLSetStmtAttr(..., PARAMSET_SIZE, ...) called\n"));
      stmt->stmt_parm_rows = (SQLINTEGER) (ptrlong) ValuePtr;
      break;

    case SQL_ATTR_ROW_ARRAY_SIZE:
      cli_dbg_printf (("SQLSetStmtAttr(..., ROW_ARRAY_SIZE, ...) called\n"));
      stmt->stmt_is_deflt_rowset = 0;
      stmt->stmt_rowset_size = (SQLINTEGER) (ptrlong) ValuePtr;
      break;

    case SQL_ATTR_ROW_BIND_OFFSET_PTR:
      cli_dbg_printf (("SQLSetStmtAttr(..., ROW_BIND_OFFSET_PTR, ...) called\n"));
      if (stmt->stmt_imp_row_descriptor)
	stmt->stmt_imp_row_descriptor->d_bind_offset_ptr = (SQLINTEGER *) ValuePtr;
      else
	{
	  set_error (&stmt->stmt_error, "IM001", "CL017", "Driver does not support this function");
	  return (SQL_ERROR);
	}
      break;
      break;

    case SQL_ATTR_ROW_OPERATION_PTR:
      cli_dbg_printf (("SQLSetStmtAttr(..., ROW_OPERATION_PTR, ...) called\n"));
      if ((SQLSMALLINT *) ValuePtr)
	{
	  set_error (&stmt->stmt_error, "01S02", "CL018", "Option value changed");
	  return (SQL_SUCCESS_WITH_INFO);
	}
      break;

    case SQL_ATTR_ROW_STATUS_PTR:
      cli_dbg_printf (("SQLSetStmtAttr(..., ROW_STATUS_PTR, ...) called\n"));
      stmt->stmt_row_status = (SQLUSMALLINT *) ValuePtr;
      break;

    case SQL_ATTR_ROWS_FETCHED_PTR:
      cli_dbg_printf (("SQLSetStmtAttr(..., ROWS_FETCHED_PTR, ...) called\n"));
      stmt->stmt_rows_fetched_ptr = (SQLULEN *) ValuePtr;
      break;

    case SQL_ATTR_MAX_LENGTH:
      cli_dbg_printf (("SQLSetStmtAttr(..., MAX_LENGTH, ...) called\n"));
      set_error (&stmt->stmt_error, "01S02", "CL019", "Option Value Changed");
      return (SQL_SUCCESS_WITH_INFO);

    case SQL_ATTR_ASYNC_ENABLE:
    case SQL_ATTR_CONCURRENCY:
    case SQL_ATTR_CURSOR_TYPE:
    case SQL_ATTR_KEYSET_SIZE:
    case SQL_ATTR_MAX_ROWS:
    case SQL_ATTR_NOSCAN:
    case SQL_ATTR_QUERY_TIMEOUT:
    case SQL_ATTR_RETRIEVE_DATA:
    case SQL_ATTR_ROW_BIND_TYPE:
    case SQL_ATTR_ROW_NUMBER:
    case SQL_ATTR_SIMULATE_CURSOR:
    case SQL_ATTR_USE_BOOKMARKS:
    case SQL_ROWSET_SIZE:
    case SQL_PREFETCH_SIZE:
    case SQL_TXN_TIMEOUT:
    case SQL_NO_CHAR_C_ESCAPE:
    case SQL_UNIQUE_ROWS:
      cli_dbg_printf (("SQLSetStmtAttr(...) mapped to SQLSetStmtOption\n"));
      return virtodbc__SQLSetStmtOption ((SQLHSTMT) stmt, (SQLUSMALLINT) Attribute, (SQLULEN) ValuePtr);

    default:
      cli_dbg_printf (("SQLSetStmtAttr(..., UNKNOWN, ...) called\n"));
      break;
    }

  return (SQL_SUCCESS);
}


SQLRETURN SQL_API
SQLSetStmtAttr (SQLHSTMT statementHandle,
    SQLINTEGER Attribute,
    SQLPOINTER ValuePtr,
    SQLINTEGER StringLength)
{
  return virtodbc__SQLSetStmtAttr (statementHandle, Attribute, ValuePtr, StringLength);
}


/**** SQLSetConnectAttr ****/

SQLRETURN SQL_API
virtodbc__SQLSetConnectAttr (SQLHDBC connectionHandle,
    SQLINTEGER Attribute,
    SQLPOINTER ValuePtr,
    SQLINTEGER StringLength)
{
  CON (con, connectionHandle);

  if (!con)
    return (SQL_INVALID_HANDLE);

  set_error (&con->con_error, NULL, NULL, NULL);

  switch (Attribute)
    {
#if !defined (WINDOWS)
    case SQL_ATTR_APP_WCHAR_ID:
      {
        SQLUINTEGER val = (SQLUINTEGER) (ptrlong) ValuePtr;
        cli_dbg_printf (("SQLSetConnectAttr(..., SQL_ATTR_APP_WCHAR_ID, ...) called\n"));
        if (val == SQL_DM_CP_UTF16)
          con->con_wide_as_utf16 = TRUE;
        else if (val == SQL_DM_CP_UCS4)
          con->con_wide_as_utf16 = FALSE;
        else 
          return SQL_ERROR;
      }
      break;
#endif
    case SQL_ATTR_ASYNC_ENABLE:
      cli_dbg_printf (("SQLSetConnectAttr(..., ASYNC_ENABLE, ...) called\n"));
      con->con_async_mode = (SQLUINTEGER) (ptrlong) ValuePtr;
      break;

    case SQL_ATTR_QUERY_TIMEOUT:
    case SQL_ATTR_CONNECTION_TIMEOUT:
    case SQL_ATTR_LOGIN_TIMEOUT:
      cli_dbg_printf (("SQLSetConnectAttr(..., TIMEOUT, ...) called\n"));
      con->con_timeout = (SQLUINTEGER) (ptrlong) ValuePtr;
      break;

    case SQL_ATTR_METADATA_ID:
      cli_dbg_printf (("SQLSetConnectAttr(..., METADATA_ID, ...) called\n"));
      con->con_db_casemode = ((SQLINTEGER) (ptrlong) ValuePtr) == SQL_TRUE ? 2 : 1;
      break;

    case SQL_ATTR_MAX_ROWS:
      cli_dbg_printf (("SQLSetConnectAttr(..., MAX_ROWS, ...) called\n"));
      con->con_max_rows = (SQLUINTEGER) (ptrlong) ValuePtr;
      break;


#ifdef XA_IMPL
    case SQL_COPT_SS_ENLIST_IN_XA:
#endif
    case SQL_COPT_SS_ENLIST_IN_DTC:
      /* ODBC 2 */
    case SQL_ATTR_ACCESS_MODE:
    case SQL_ATTR_AUTOCOMMIT:
    case SQL_ATTR_ODBC_CURSORS:
    case SQL_ATTR_PACKET_SIZE:
    case SQL_ATTR_QUIET_MODE:
    case SQL_ATTR_TRACE:
    case SQL_ATTR_TRANSLATE_OPTION:
    case SQL_ATTR_TXN_ISOLATION:
    case SQL_ATTR_CURRENT_CATALOG:
    case SQL_ATTR_TRACEFILE:
    case SQL_ATTR_TRANSLATE_LIB:
    case SQL_NO_CHAR_C_ESCAPE:
    case SQL_CHARSET:
    case SQL_APPLICATION_NAME:
    case SQL_ENCRYPT_CONNECTION:
    case SQL_SERVER_CERT:
      cli_dbg_printf (("SQLSetConnectAttr(...) mapped to SQLSetConnectOption(...)\n"));
      return virtodbc__SQLSetConnectOption (connectionHandle, (SQLUSMALLINT) Attribute, (SQLULEN) ValuePtr);

    default:
      cli_dbg_printf (("SQLSetConnectAttr(..., UNKNOWN, ...) called\n"));
      break;
    }

  return (SQL_SUCCESS);
}


SQLRETURN SQL_API
SQLSetConnectAttr (SQLHDBC connectionHandle,
    SQLINTEGER Attribute,
    SQLPOINTER ValuePtr,
    SQLINTEGER StringLength)
{
  CON (con, connectionHandle);
  switch (Attribute)
    {
    case SQL_CURRENT_QUALIFIER:
    case SQL_CHARSET:
    case SQL_APPLICATION_NAME:
      {
	SQLRETURN rc;
	NDEFINE_INPUT_NONCHAR_NARROW (ValuePtr, StringLength);

	NMAKE_INPUT_NONCHAR_NARROW (ValuePtr, StringLength, con);

	rc = virtodbc__SQLSetConnectAttr (connectionHandle, Attribute, _ValuePtr, (SQLINTEGER) _StringLength);

	NFREE_INPUT_NONCHAR_NARROW (ValuePtr, StringLength);
	return rc;
      }

    default:
      return virtodbc__SQLSetConnectAttr (connectionHandle, Attribute, ValuePtr, StringLength);
    }
}


/**** SQLGetConnectAttr ****/

SQLRETURN SQL_API
virtodbc__SQLGetConnectAttr (SQLHDBC connectionHandle,
    SQLINTEGER Attribute,
    SQLPOINTER ValuePtr,
    SQLINTEGER StringLength,
    UNALIGNED SQLINTEGER * StringLengthPtr)
{
  CON (con, connectionHandle);

  if (!con)
    return (SQL_INVALID_HANDLE);

  set_error (&con->con_error, NULL, NULL, NULL);

  switch (Attribute)
    {

    case SQL_ATTR_ASYNC_ENABLE:
      cli_dbg_printf (("SQLGetConnectAttr(..., ASYNC_ENABLE, ...) called\n"));
      *((SQLUINTEGER *) ValuePtr) = con->con_async_mode;
      break;

    case SQL_ATTR_LOGIN_TIMEOUT:
    case SQL_ATTR_QUERY_TIMEOUT:
    case SQL_ATTR_CONNECTION_TIMEOUT:
      cli_dbg_printf (("SQLGetConnectAttr(..., CONN_TIMEOUT, ...) called\n"));
      *((SQLUINTEGER *) ValuePtr) = con->con_timeout;
      break;

    case SQL_ATTR_METADATA_ID:
      cli_dbg_printf (("SQLGetConnectAttr(..., METADATA_ID, ...) called\n"));
      *((SQLINTEGER *) ValuePtr) = con->con_db_casemode == 2 ? SQL_TRUE : SQL_FALSE;
      break;

    case SQL_ATTR_AUTO_IPD:
      cli_dbg_printf (("SQLGetConnectAttr(..., AUTO_IPD, ...) called\n"));
      *((SQLINTEGER *) ValuePtr) = SQL_FALSE;
      break;

#if defined(SQL_ATTR_CONNECTION_DEAD)
    case SQL_ATTR_CONNECTION_DEAD:
      cli_dbg_printf (("SQLGetConnectAttr(..., CONNECTION_DEAD, ...) called\n"));
      if (con->con_session && DKSESSTAT_ISSET (con->con_session, SST_BROKEN_CONNECTION))
	*((SQLINTEGER *) ValuePtr) = SQL_CD_TRUE;
      else
	*((SQLINTEGER *) ValuePtr) = SQL_CD_FALSE;
      break;
#endif

    case SQL_ATTR_MAX_ROWS:
      cli_dbg_printf (("SQLGetConnectAttr(..., MAX_ROWS, ...) called\n"));
      *((SQLUINTEGER *) ValuePtr) = con->con_max_rows;

      /* ODBC 2 */
    case SQL_ATTR_TRACEFILE:
    case SQL_ATTR_TRANSLATE_LIB:
    case SQL_ATTR_CURRENT_CATALOG:
    case SQL_APPLICATION_NAME:
    case SQL_ENCRYPT_CONNECTION:
    case SQL_SERVER_CERT:
    case SQL_NO_CHAR_C_ESCAPE:
      if (StringLengthPtr)
	*StringLengthPtr = SQL_NTS;
    case SQL_ATTR_ACCESS_MODE:
    case SQL_ATTR_AUTOCOMMIT:
    case SQL_ATTR_ODBC_CURSORS:
    case SQL_ATTR_PACKET_SIZE:
    case SQL_ATTR_QUIET_MODE:
    case SQL_ATTR_TRACE:
    case SQL_ATTR_TRANSLATE_OPTION:
    case SQL_ATTR_TXN_ISOLATION:
    case SQL_CHARSET:
    case SQL_INPROCESS_CLIENT:

#ifdef XA_IMPL
    case SQL_COPT_SS_ENLIST_IN_XA:
#endif
    case SQL_COPT_SS_ENLIST_IN_DTC:
      cli_dbg_printf (("SQLGetConnectAttr(...) mapped to SQLGetConnectOption(...)\n"));
      return virtodbc__SQLGetConnectOption (connectionHandle,
	  (SQLUSMALLINT) Attribute, (SQLPOINTER) ValuePtr, StringLength, StringLengthPtr);

    default:
      cli_dbg_printf (("SQLGetConnectAttr(..., UNKNOWN, ...) called\n"));
      break;
    }

  return (SQL_SUCCESS);
}


SQLRETURN SQL_API
SQLGetConnectAttr (SQLHDBC connectionHandle,
    SQLINTEGER Attribute,
    SQLPOINTER ValuePtr,
    SQLINTEGER StringLength,
    SQLINTEGER * StringLengthPtr)
{
  CON (con, connectionHandle);
  switch (Attribute)
    {
    case SQL_ATTR_CURRENT_CATALOG:
    case SQL_ATTR_TRACEFILE:
    case SQL_ATTR_TRANSLATE_LIB:
    case SQL_CHARSET:
    case SQL_APPLICATION_NAME:
      {
	SQLRETURN rc;
	NDEFINE_OUTPUT_NONCHAR_NARROW (ValuePtr, StringLength, StringLengthPtr, con, SQLINTEGER);

	NMAKE_OUTPUT_NONCHAR_NARROW (ValuePtr, StringLength, con);

	rc = virtodbc__SQLGetConnectAttr (connectionHandle, Attribute, _ValuePtr, _StringLength, _StringLengthPtr);

	NSET_AND_FREE_OUTPUT_NONCHAR_NARROW (ValuePtr, StringLength, StringLengthPtr, con);
	return rc;
      }

    default:
      return virtodbc__SQLGetConnectAttr (connectionHandle, Attribute, ValuePtr, StringLength, StringLengthPtr);
    }
}

static caddr_t
get_rdf_literal_prop (cli_connection_t * con, SQLSMALLINT ftype, short key)
{
  dk_hash_t * ht;
  caddr_t ret = NULL;

  /* the defaults (most often cases probably) have no records in tables */
  if ((ftype == SQL_DESC_COL_LITERAL_LANG && key == RDF_BOX_DEFAULT_LANG) ||
      (ftype == SQL_DESC_COL_LITERAL_TYPE && key == RDF_BOX_DEFAULT_TYPE))
    return NULL;

  IN_CON (con);
  if (ftype == SQL_DESC_COL_LITERAL_LANG)
    ht = con->con_rdf_langs;
  else
    ht = con->con_rdf_types;

  if (!ht) /* no cache used yet */
    {
      ht = hash_table_allocate (31);
      if (ftype == SQL_DESC_COL_LITERAL_LANG)
	con->con_rdf_langs = ht;
      else
	con->con_rdf_types = ht;
    }
  else
    ret = gethash ((void *)(ptrlong) key, ht);
  LEAVE_CON (con);

  if (!ret) /* not in cache */
    {
      static char * qr_lang = "select RL_ID from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = ?";
      static char * qr_type = "select RDT_QNAME from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = ?";
      char * qr = ((ftype == SQL_DESC_COL_LITERAL_LANG) ? qr_lang : qr_type);
      char buf[1000];
      SQLHSTMT hstmt;
      SQLLEN  m_ind = 0;
      SQLLEN flag;
      int rc;

      rc = virtodbc__SQLAllocHandle (SQL_HANDLE_STMT, con, &hstmt);
      if (rc != SQL_SUCCESS)
	{
	  return NULL;
	}
      rc = virtodbc__SQLBindParameter (hstmt, 1, SQL_PARAM_INPUT, SQL_C_SSHORT,
	  SQL_SMALLINT, 0, 0, &key, 0, &m_ind);
      rc = virtodbc__SQLExecDirect(hstmt, (UCHAR *) qr, SQL_NTS);
      if (rc != SQL_SUCCESS)
	{
	  virtodbc__SQLFreeHandle (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
	  goto err_cleanup;
	}

      rc = virtodbc__SQLFetch (hstmt, 0);
      if (SQL_SUCCESS != rc)
	goto err_cleanup;
      rc = virtodbc__SQLGetData (hstmt, 1, SQL_C_CHAR, buf, sizeof (buf), &flag);
      if (SQL_SUCCESS != rc)
	goto err_cleanup;
      ret = box_dv_short_string (buf);
      IN_CON (con);
      sethash ((void*)(ptrlong)key, ht, (void*) ret);
      LEAVE_CON (con);
err_cleanup:
      virtodbc__SQLFreeStmt (hstmt, SQL_CLOSE);
      virtodbc__SQLFreeHandle (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
    }
  return ret;
}

/**** SQLGetDescField ****/

SQLRETURN SQL_API
virtodbc__SQLGetDescField (SQLHDESC descriptorHandle,
    SQLSMALLINT RecNumber,
    SQLSMALLINT FieldIdentifier,
    SQLPOINTER ValuePtr,
    SQLINTEGER BufferLength,
    SQLINTEGER * StringLengthPtr)
{
  DESC (desc, descriptorHandle);
#if defined(DEBUG)
  char *szDescType;
  char szDebugBuffer[256];
#endif
  int bAppDesc = 0, bRowDesc = 0;
  SQLSMALLINT sqlType;
  SQLULEN def;
  SQLSMALLINT scale;
  SQLRETURN rc = SQL_SUCCESS;
  SQLSMALLINT desc_count = 0;

  if (!desc)
    return (SQL_INVALID_HANDLE);

  bAppDesc = (desc->d_type == ROW_APP_DESCRIPTOR || desc->d_type == PARAM_APP_DESCRIPTOR);
  bRowDesc = (desc->d_type == ROW_APP_DESCRIPTOR || desc->d_type == ROW_IMP_DESCRIPTOR);

#if defined(DEBUG)
  switch (desc->d_type)
    {
    case ROW_APP_DESCRIPTOR:
      szDescType = "ARD";
      break;

    case ROW_IMP_DESCRIPTOR:
      szDescType = "IRD";
      break;

    case PARAM_IMP_DESCRIPTOR:
      szDescType = "IPD";
      break;

    case PARAM_APP_DESCRIPTOR:
      szDescType = "APD";
      break;

    default:
      szDescType = "UNKNOWN_DESC";
    }

  cli_dbg_printf (("%s", szDescType));
#endif

  if (bRowDesc)
    {
      if (bAppDesc)
	desc_count = desc->d_stmt->stmt_n_cols;
      else if (desc->d_stmt->stmt_compilation)
	virtodbc__SQLNumResultCols ((SQLHSTMT) desc->d_stmt, &desc_count);
    }
  else
    {
      if (bAppDesc)
	desc_count = desc->d_stmt->stmt_n_parms;
      else
	{
	  /* avd: IPD fields can be set either through SQLBindParameter() or as
	     a result of ``automatic population'' (i.e. from the stmt compilation).
	     Parameters could be bound before any compilation is available. But
	     even if the compilation is available, my reading of the spec is that
	     SQLBindParameter() should override any data previously set, including
	     the data obtained from the ``automatic population''. */
	  if (desc->d_stmt->stmt_compilation &&
	      BOX_ELEMENTS (desc->d_stmt->stmt_compilation) > 3 && desc->d_stmt->stmt_compilation->sc_params)
	    desc_count = (SQLSMALLINT) BOX_ELEMENTS (desc->d_stmt->stmt_compilation->sc_params);

	  if (desc_count < desc->d_stmt->stmt_n_parms)
	    desc_count = desc->d_stmt->stmt_n_parms;
	}
    }

  switch (FieldIdentifier)
    {

    case SQL_DESC_ALLOC_TYPE:
      cli_dbg_printf ((": SQLGetDescField(..., HEADER, ALLOC_TYPE, ...) called\n"));
      *((SQLSMALLINT *) ValuePtr) = SQL_DESC_ALLOC_AUTO;
      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLSMALLINT);

      return (SQL_SUCCESS);

    case SQL_DESC_ARRAY_SIZE:
      cli_dbg_printf ((": SQLGetDescField(..., HEADER, ARRAY_SIZE, ...) called\n"));
      if (bAppDesc)
	*((SQLULEN *) ValuePtr) = bRowDesc ? desc->d_stmt->stmt_rowset_size : desc->d_stmt->stmt_parm_rows;
      else
	return (SQL_ERROR);
      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLUINTEGER);
      return (SQL_SUCCESS);

    case SQL_DESC_ARRAY_STATUS_PTR:
      cli_dbg_printf ((": SQLGetDescField(..., HEADER, ARRAY_STATUS_PTR, ...) called\n"));
      if (bAppDesc && ValuePtr)
	*((SQLSMALLINT **) ValuePtr) = (SQLSMALLINT *) (bRowDesc ? desc->d_stmt->stmt_row_status : desc->d_stmt->stmt_param_status);
      else
	*((SQLSMALLINT **) ValuePtr) = NULL;

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLSMALLINT *);

      return (SQL_SUCCESS);

    case SQL_DESC_BIND_OFFSET_PTR:
      cli_dbg_printf ((": SQLGetDescField(..., HEADER, BIND_OFFSET_PTR, ...) called\n"));
      if (bAppDesc)
	*((SQLINTEGER **) ValuePtr) = desc->d_bind_offset_ptr;
      else
	return (SQL_ERROR);

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLSMALLINT *);

      return (SQL_SUCCESS);

    case SQL_DESC_BIND_TYPE:
      cli_dbg_printf ((": SQLGetDescField(..., HEADER, BIND_OFFSET_PTR, ...) called\n"));
      if (bAppDesc)
	*((SQLUINTEGER *) ValuePtr) = bRowDesc ? desc->d_stmt->stmt_bind_type : desc->d_stmt->stmt_param_bind_type;
      else
	return (SQL_ERROR);

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLUINTEGER);

      return (SQL_SUCCESS);

    case SQL_DESC_COUNT:
      cli_dbg_printf ((": SQLGetDescField(..., HEADER, DESC_COUNT, ...) called\n"));
      *((SQLSMALLINT *) ValuePtr) = desc_count;

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLSMALLINT);

      return (SQL_SUCCESS);

    case SQL_DESC_ROWS_PROCESSED_PTR:
      cli_dbg_printf ((": SQLGetDescField(..., HEADER, ROWS_PROCESSED_PTR, ...) called\n"));
      if (!bAppDesc)
	{
	  *((SQLULEN **) ValuePtr) = bRowDesc ? desc->d_stmt->stmt_rows_fetched_ptr : desc->d_stmt->stmt_pirow;
	  if (StringLengthPtr)
	    *StringLengthPtr = sizeof (SQLPOINTER);

	  return (SQL_SUCCESS);
	}
      else
	{
	  set_error (&desc->d_stmt->stmt_error, "HY091", "CL020", "Invalid descriptor field identifier");

	  return (SQL_ERROR);
	}


/*   Record Fields */

    case SQL_DESC_SCALE:
      if (bRowDesc)
	{
	  if (RecNumber)	/* bookmark */
	    if (desc->d_stmt->stmt_compilation &&
		desc->d_stmt->stmt_compilation->sc_columns &&
		BOX_ELEMENTS (desc->d_stmt->stmt_compilation->sc_columns) >= ((uint32) RecNumber))
	      {
		col_desc_t *cd = (col_desc_t *) desc->d_stmt->stmt_compilation->sc_columns[RecNumber - 1];

		if (ValuePtr)
		  *((SQLSMALLINT *) ValuePtr) = (SQLSMALLINT) unbox (cd->cd_scale);
	      }

	  return (SQL_SUCCESS);
	}

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLSMALLINT);
      break;

    case SQL_DESC_NAME:
      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (!bAppDesc)
	{
	  if (bRowDesc)
	    {
	      if (!RecNumber)	/* bookmark */
		setStringValue ("Bookmark", ValuePtr, BufferLength, StringLengthPtr);
	      else if (desc->d_stmt->stmt_compilation
		  && desc->d_stmt->stmt_compilation->sc_columns
		  && BOX_ELEMENTS (desc->d_stmt->stmt_compilation->sc_columns) >= ((uint32) RecNumber))
		{
		  col_desc_t *cd = (col_desc_t *) desc->d_stmt->stmt_compilation->sc_columns[RecNumber - 1];
		  return str_box_to_buffer (cd->cd_name, (char *) ValuePtr,
		      BufferLength, StringLengthPtr, 1, &desc->d_stmt->stmt_error);
		}

	      return (SQL_SUCCESS);
	    }
	  else
	    {
	      if (RecNumber > 0 &&
		  desc->d_stmt->stmt_compilation &&
		  BOX_ELEMENTS (desc->d_stmt->stmt_compilation) > 3 &&
		  desc->d_stmt->stmt_compilation->sc_params &&
		  BOX_ELEMENTS (desc->d_stmt->stmt_compilation->sc_params) >= ((uint32) RecNumber))
		{
		  param_desc_t *pd = (param_desc_t *) desc->d_stmt->stmt_compilation->sc_params[RecNumber - 1];
		  if (PARAM_DESC_IS_EXTENDED (pd))
		    return str_box_to_buffer (pd->pd_name, (char *) ValuePtr,
			BufferLength, StringLengthPtr, 1, &desc->d_stmt->stmt_error);
		}
	    }
	}
      else
	return (SQL_ERROR);

      if (StringLengthPtr)
	*StringLengthPtr = 0;

      if (ValuePtr)
	*((SQLCHAR *) ValuePtr) = 0;

      break;

    case SQL_DESC_OCTET_LENGTH_PTR:
      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLPOINTER);

      if (!bAppDesc)
	return (SQL_ERROR);

      break;

    case SQL_DESC_PARAMETER_TYPE:
      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (!bAppDesc && !bRowDesc)
	{
	  SQLSMALLINT iotype = SQL_PARAM_INPUT;
	  if (RecNumber > 0)
	    {
	      /* As per the spec SQLBindParameter overrides data in the IPD.
	         Therefore first look for the parameter binding structure.
	         If not found examine the stmt compilation.
	         BUG: SQLSetParam() always sets parameter type to SQL_PARAM_INPUT
	         thus also inadvertently overriding the parameter type. */
	      parm_binding_t *pb = NULL;
	      if (RecNumber <= desc->d_stmt->stmt_n_parms)
		{
		  int i = 0;
		  for (pb = desc->d_stmt->stmt_parms; pb != NULL; pb = pb->pb_next)
		    {
		      if (++i == RecNumber)
			{
			  if (pb->pb_place == NULL && pb->pb_length == NULL)
			    pb = NULL;
			  break;
			}
		    }
		}

	      if (pb != NULL && pb->pb_param_type != SQL_PARAM_TYPE_UNKNOWN)
		iotype = pb->pb_param_type;
	      else if (desc->d_stmt->stmt_compilation &&
		  BOX_ELEMENTS (desc->d_stmt->stmt_compilation) > 3 &&
		  desc->d_stmt->stmt_compilation->sc_params &&
		  BOX_ELEMENTS (desc->d_stmt->stmt_compilation->sc_params) >= ((uint32) RecNumber))
		{
		  param_desc_t *pd = (param_desc_t *) desc->d_stmt->stmt_compilation->sc_params[RecNumber - 1];
		  if (PARAM_DESC_IS_EXTENDED (pd))
		    iotype = (SQLSMALLINT) unbox (pd->pd_iotype);
		}
	    }

	  if (ValuePtr)
	    *((SQLSMALLINT *) ValuePtr) = iotype;
	}
      else
	return (SQL_ERROR);

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLSMALLINT);

      break;

    case SQL_DESC_PRECISION:
      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLSMALLINT);

      break;

    case SQL_DESC_SCHEMA_NAME:
      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (!bAppDesc && bRowDesc)
	{
	  char *name = NULL;
	  if (RecNumber > 0 &&
	      desc->d_stmt->stmt_compilation &&
	      desc->d_stmt->stmt_compilation->sc_columns &&
	      BOX_ELEMENTS (desc->d_stmt->stmt_compilation->sc_columns) >= ((uint32) RecNumber))
	    {
	      col_desc_t *cd = (col_desc_t *) desc->d_stmt->stmt_compilation->sc_columns[RecNumber - 1];
	      if (COL_DESC_IS_EXTENDED (cd))
		name = cd->cd_base_schema_name;
	    }
	  return str_box_to_buffer (name, (char *) ValuePtr, BufferLength, StringLengthPtr, 1, &desc->d_stmt->stmt_error);
	}
      else
	return (SQL_ERROR);

      break;

    case SQL_DESC_AUTO_UNIQUE_VALUE:
      cli_dbg_printf ((": SQLGetDescField(..., FIELD %d, AUTO_UNIQUE_VALUE, ...) called\n", RecNumber));

      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (!bAppDesc && bRowDesc)
	{
	  if (ValuePtr)
	    {
	      *((SQLINTEGER *) ValuePtr) = SQL_FALSE;
	      if (RecNumber > 0 &&
		  desc->d_stmt->stmt_compilation &&
		  desc->d_stmt->stmt_compilation->sc_columns &&
		  BOX_ELEMENTS (desc->d_stmt->stmt_compilation->sc_columns) >= ((uint32) RecNumber))
		{
		  col_desc_t *cd = (col_desc_t *) desc->d_stmt->stmt_compilation->sc_columns[RecNumber - 1];
		  if (COL_DESC_IS_EXTENDED (cd) && (unbox (cd->cd_flags) & CDF_AUTOINCREMENT))
		    *((SQLINTEGER *) ValuePtr) = SQL_TRUE;
		}
	    }
	}
      else
	return (SQL_ERROR);

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLINTEGER);

      break;

    case SQL_DESC_BASE_COLUMN_NAME:
      cli_dbg_printf ((": SQLGetDescField(..., FIELD %d, BASE_COLUMN_NAME, ...) called\n", RecNumber));

      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (!bAppDesc && bRowDesc)
	{
	  char *name = NULL;
	  if (RecNumber > 0 &&
	      desc->d_stmt->stmt_compilation &&
	      desc->d_stmt->stmt_compilation->sc_columns &&
	      BOX_ELEMENTS (desc->d_stmt->stmt_compilation->sc_columns) >= ((uint32) RecNumber))
	    {
	      col_desc_t *cd = (col_desc_t *) desc->d_stmt->stmt_compilation->sc_columns[RecNumber - 1];
	      if (COL_DESC_IS_EXTENDED (cd))
		name = cd->cd_base_column_name;
	      else
		name = cd->cd_name;
	    }
	  return str_box_to_buffer (name, (char *) ValuePtr, BufferLength, StringLengthPtr, 1, &desc->d_stmt->stmt_error);
	}
      else
	return (SQL_ERROR);

      break;

    case SQL_DESC_BASE_TABLE_NAME:
    case SQL_DESC_TABLE_NAME:
      cli_dbg_printf ((": SQLGetDescField(..., FIELD %d, BASE_COLUMN_NAME, ...) called\n", RecNumber));

      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (!bAppDesc && bRowDesc)
	{
	  char *name = NULL;
	  if (RecNumber > 0 &&
	      desc->d_stmt->stmt_compilation &&
	      desc->d_stmt->stmt_compilation->sc_columns &&
	      BOX_ELEMENTS (desc->d_stmt->stmt_compilation->sc_columns) >= ((uint32) RecNumber))
	    {
	      col_desc_t *cd = (col_desc_t *) desc->d_stmt->stmt_compilation->sc_columns[RecNumber - 1];
	      if (COL_DESC_IS_EXTENDED (cd))
		name = cd->cd_base_table_name;
	    }

	  return str_box_to_buffer (name, (char *) ValuePtr, BufferLength, StringLengthPtr, 1, &desc->d_stmt->stmt_error);
	}
      else
	return (SQL_ERROR);

      break;

    case SQL_DESC_CASE_SENSITIVE:
      cli_dbg_printf ((": SQLGetDescField(..., FIELD %d, CASE_SENSITIVE, ...) called\n", RecNumber));

      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (!bAppDesc && ValuePtr)
	{
	  if (bRowDesc)
	    {
	      rc = virtodbc__SQLDescribeCol ((SQLHSTMT) desc->d_stmt, RecNumber, NULL, 0, NULL, &sqlType, NULL, NULL, NULL);
	      if (rc != SQL_SUCCESS)
		return (rc);

	      *((SQLINTEGER *) ValuePtr) = (sqlType == SQL_CHAR || sqlType == SQL_VARCHAR || sqlType == SQL_LONGVARCHAR) ? SQL_TRUE : SQL_FALSE;
	    }
	  else
	    *((SQLINTEGER *) ValuePtr) = SQL_TRUE;
	}
      else
	return (SQL_ERROR);

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLINTEGER);

      break;

    case SQL_DESC_CATALOG_NAME:
      cli_dbg_printf ((": SQLGetDescField(..., FIELD %d, CATALOG_NAME, ...) called\n", RecNumber));

      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);
      if (!bAppDesc && bRowDesc)
	{
	  char *name = NULL;
	  if (RecNumber > 0 &&
	      desc->d_stmt->stmt_compilation &&
	      desc->d_stmt->stmt_compilation->sc_columns &&
	      BOX_ELEMENTS (desc->d_stmt->stmt_compilation->sc_columns) >= ((uint32) RecNumber))
	    {
	      col_desc_t *cd = (col_desc_t *) desc->d_stmt->stmt_compilation->sc_columns[RecNumber - 1];

	      if (COL_DESC_IS_EXTENDED (cd))
		name = cd->cd_base_catalog_name;
	    }

	  return str_box_to_buffer (name, (char *) ValuePtr, BufferLength, StringLengthPtr, 1, &desc->d_stmt->stmt_error);
	}
      else
	return (SQL_ERROR);

      break;

    case SQL_DESC_DATA_PTR:
      cli_dbg_printf ((": SQLGetDescField(..., FIELD %d, DATA_PTR, ...) called\n", RecNumber));

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLPOINTER);

      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (!bAppDesc && bRowDesc)
	return (SQL_ERROR);

      break;

    case SQL_DESC_DATETIME_INTERVAL_CODE:
      cli_dbg_printf ((": SQLGetDescField(..., FIELD %d, DATE_TIME_INTERVAL_CODE, ...) called\n", RecNumber));

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLSMALLINT);

      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (ValuePtr)
	*((SQLPOINTER *) ValuePtr) = NULL;

      break;

    case SQL_DESC_DATETIME_INTERVAL_PRECISION:
      cli_dbg_printf ((": SQLGetDescField(..., FIELD %d, DATE_TIME_INTERVAL_PRECISION, ...) called\n", RecNumber));

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLINTEGER);

      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      break;

    case SQL_DESC_DISPLAY_SIZE:
      cli_dbg_printf ((": SQLGetDescField(..., FIELD %d, DISPLAY_SIZE, ...) called\n", RecNumber));

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLINTEGER);

      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (!bAppDesc && bRowDesc)
	{
	  return virtodbc__SQLColAttributes ((SQLHSTMT) desc->d_stmt,
	      RecNumber, SQL_COLUMN_DISPLAY_SIZE, NULL, 0, NULL, (SQLLEN *) ValuePtr);
	}
      else
	return (SQL_ERROR);

      break;

    case SQL_DESC_FIXED_PREC_SCALE:
      cli_dbg_printf ((": SQLGetDescField(..., FIELD %d, FIXED_PREC_SCALE, ...) called\n", RecNumber));

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLSMALLINT);

      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (!bAppDesc && bRowDesc && ValuePtr)
	{
	  rc = virtodbc__SQLDescribeCol ((SQLHSTMT) desc->d_stmt, RecNumber, NULL, 0, NULL, NULL, &def, &scale, NULL);
	  if (rc != SQL_SUCCESS)
	    return (rc);
	  *((SQLSMALLINT *) ValuePtr) = (scale > 0);
	  if (StringLengthPtr)
	    *StringLengthPtr = sizeof (SQLSMALLINT);
	}
      else if (bAppDesc)
	return (SQL_ERROR);

      break;

    case SQL_DESC_INDICATOR_PTR:
      cli_dbg_printf ((": SQLGetDescField(..., FIELD %d, INDICATOR_PTR, ...) called\n", RecNumber));

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLPOINTER);

      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (!bAppDesc)
	return (SQL_ERROR);

      break;

    case SQL_DESC_LABEL:
      cli_dbg_printf ((": SQLGetDescField(..., FIELD %d, LABEL, ...) called\n", RecNumber));

      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (!bAppDesc && bRowDesc)
	{
	  char *name = NULL;
	  if (RecNumber > 0 &&
	      desc->d_stmt->stmt_compilation &&
	      desc->d_stmt->stmt_compilation->sc_columns &&
	      BOX_ELEMENTS (desc->d_stmt->stmt_compilation->sc_columns) >= ((uint32) RecNumber))
	    {
	      col_desc_t *cd = (col_desc_t *) desc->d_stmt->stmt_compilation->sc_columns[RecNumber - 1];
	      name = cd->cd_name;
	    }

	  return str_box_to_buffer (name, (char *) ValuePtr, BufferLength, StringLengthPtr, 1, &desc->d_stmt->stmt_error);
	}
      else
	return (SQL_ERROR);

      break;

    case SQL_DESC_LENGTH:
    case SQL_DESC_OCTET_LENGTH:
      cli_dbg_printf ((": SQLGetDescField(..., FIELD %d, LENGTH, ...) called\n", RecNumber));

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLINTEGER);

      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (bRowDesc)
	return virtodbc__SQLDescribeCol ((SQLHSTMT) desc->d_stmt, RecNumber,
	    NULL, 0, NULL, NULL, NULL, (SQLSMALLINT *) ValuePtr, NULL);

      break;

    case SQL_DESC_LITERAL_PREFIX:
      cli_dbg_printf ((": SQLGetDescField(..., FIELD %d, LITERAL_PREFIX, ...) called\n", RecNumber));

      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (bRowDesc && !bAppDesc)
	{

	  SQLHSTMT helper_stmt;
	  SQLLEN strlen = StringLengthPtr ? *StringLengthPtr : 0;

	  rc = virtodbc__SQLDescribeCol ((SQLHSTMT) desc->d_stmt, RecNumber, NULL, 0, NULL, &sqlType, NULL, NULL, NULL);
	  if (rc != SQL_SUCCESS)
	    return (rc);
	  rc = virtodbc__SQLAllocHandle (SQL_HANDLE_STMT, desc->d_stmt->stmt_connection, (SQLHANDLE *) & helper_stmt);
	  if (rc != SQL_SUCCESS)
	    return (rc);
	  rc = virtodbc__SQLGetTypeInfo (helper_stmt, sqlType);
	  if (rc != SQL_SUCCESS)
	    {
	      virtodbc__SQLFreeHandle (SQL_HANDLE_STMT, (SQLHANDLE) helper_stmt);
	      return (rc);
	    }

	  rc = virtodbc__SQLFetch (helper_stmt, 0);

	  if (rc != SQL_SUCCESS)
	    {
	      virtodbc__SQLFreeHandle (SQL_HANDLE_STMT, (SQLHANDLE) helper_stmt);
	      return (rc);
	    }

	  rc = virtodbc__SQLGetData (helper_stmt, 4, SQL_C_CHAR, ValuePtr, BufferLength, StringLengthPtr ? &strlen : NULL);

	  if (StringLengthPtr)
	    *StringLengthPtr = (SQLINTEGER) strlen;

	  if (rc != SQL_SUCCESS)
	    {
	      virtodbc__SQLFreeHandle (SQL_HANDLE_STMT, (SQLHANDLE) helper_stmt);
	      return (rc);
	    }

	  rc = virtodbc__SQLFreeHandle (SQL_HANDLE_STMT, (SQLHANDLE) helper_stmt);
	  if (rc != SQL_SUCCESS)
	    return rc;

	  if (*StringLengthPtr == SQL_NULL_DATA)
	    {
	      *((SQLCHAR *) ValuePtr) = '\x0';
	      *StringLengthPtr = 0;
	    }
	}
      else
	return (SQL_ERROR);

      break;

    case SQL_DESC_LITERAL_SUFFIX:
      cli_dbg_printf ((": SQLGetDescField(..., FIELD %d, LITERAL_SUFFIX, ...) called\n", RecNumber));

      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (bRowDesc && !bAppDesc)
	{

	  SQLHSTMT helper_stmt;
	  SQLLEN strlen = StringLengthPtr ? *StringLengthPtr : 0;

	  rc = virtodbc__SQLDescribeCol ((SQLHSTMT) desc->d_stmt, RecNumber, NULL, 0, NULL, &sqlType, NULL, NULL, NULL);

	  if (rc != SQL_SUCCESS)
	    return (rc);

	  rc = virtodbc__SQLAllocHandle (SQL_HANDLE_STMT, desc->d_stmt->stmt_connection, (SQLHANDLE *) & helper_stmt);
	  if (rc != SQL_SUCCESS)
	    return (rc);

	  rc = virtodbc__SQLGetTypeInfo (helper_stmt, sqlType);
	  if (rc != SQL_SUCCESS)
	    {
	      virtodbc__SQLFreeHandle (SQL_HANDLE_STMT, (SQLHANDLE) helper_stmt);
	      return (rc);
	    }

	  rc = virtodbc__SQLFetch (helper_stmt, 0);
	  if (rc != SQL_SUCCESS)
	    {
	      virtodbc__SQLFreeHandle (SQL_HANDLE_STMT, (SQLHANDLE) helper_stmt);
	      return (rc);
	    }

	  rc = virtodbc__SQLGetData (helper_stmt, 5, SQL_C_CHAR, ValuePtr, BufferLength, StringLengthPtr ? &strlen : NULL);

	  if (StringLengthPtr)
	    *StringLengthPtr = (SQLINTEGER) strlen;

	  if (rc != SQL_SUCCESS)
	    {
	      virtodbc__SQLFreeHandle (SQL_HANDLE_STMT, (SQLHANDLE) helper_stmt);
	      return (rc);
	    }

	  rc = virtodbc__SQLFreeHandle (SQL_HANDLE_STMT, (SQLHANDLE) helper_stmt);
	  if (rc != SQL_SUCCESS)
	    return rc;

	  if (*StringLengthPtr == SQL_NULL_DATA)
	    {
	      *((SQLCHAR *) ValuePtr) = '\x0';
	      *StringLengthPtr = 0;
	    }
	}
      else
	return (SQL_ERROR);

      break;

    case SQL_DESC_TYPE_NAME:
    case SQL_DESC_LOCAL_TYPE_NAME:
      cli_dbg_printf ((": SQLGetDescField(..., FIELD %d, LOCAL_TYPE_NAME, ...) called\n", RecNumber));

      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (!bAppDesc)
	{
	  if (bRowDesc && ValuePtr)
	    {
	      int icol = RecNumber;
	      int n_cols, was_bm_col = (icol == 0);
	      STMT (stmt, desc->d_stmt);
	      stmt_compilation_t *sc = stmt->stmt_compilation;
	      char *type;
	      col_desc_t *cd;

	      icol--;
	      if (!sc)
		{
		  set_error (&stmt->stmt_error, "S1010", "CL037", "Statement not prepared.");
		  return SQL_ERROR;
		}
	      if (!sc->sc_is_select)
		{
		  set_error (&stmt->stmt_error, "07005", "CL038", "Statement does not have output cols.");
		  return SQL_ERROR;
		}
	      if (was_bm_col && !stmt->stmt_opts->so_use_bookmarks)
		{
		  set_error (&stmt->stmt_error, "07009", "CL039", "Bookmarks not enabled for statement");
		  return SQL_ERROR;
		}

	      n_cols = BOX_ELEMENTS (stmt->stmt_compilation->sc_columns);
	      if (!was_bm_col && icol >= n_cols)
		{
		  set_error (&stmt->stmt_error, "S1002", "CL040", "Column index too large.");
		  return SQL_ERROR;
		}

	      if (was_bm_col)
		cd = &bm_info;
	      else
		cd = (col_desc_t *) stmt->stmt_compilation->sc_columns[icol];

	      type = (char *) DV_TYPE_TITLE (cd->cd_dtp);

	      if (unbox (cd->cd_flags) && CDF_XMLTYPE)
		type = "XMLType";

	      V_SET_ODBC_STR (type, ValuePtr, BufferLength, StringLengthPtr, &desc->d_stmt->stmt_error);
	    }
	}
      else
	return (SQL_ERROR);

      break;

    case SQL_DESC_NULLABLE:
      cli_dbg_printf ((": SQLGetDescField(..., FIELD %d, NULLABLE, ...) called\n", RecNumber));

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLSMALLINT);

      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (bRowDesc && !bAppDesc)
	return virtodbc__SQLDescribeCol ((SQLHSTMT) desc->d_stmt,
	    RecNumber, NULL, 0, NULL, NULL, NULL, NULL, (SQLSMALLINT *) ValuePtr);
      else if (bAppDesc)
	return (SQL_ERROR);

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLSMALLINT);

      break;

    case SQL_DESC_SEARCHABLE:
      cli_dbg_printf ((": SQLGetDescField(..., FIELD %d, SEARCHABLE, ...) called\n", RecNumber));

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLSMALLINT);

      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLSMALLINT);

      if (bRowDesc && !bAppDesc)
	return virtodbc__SQLColAttributes ((SQLHSTMT) desc->d_stmt,
	    RecNumber, SQL_COLUMN_SEARCHABLE, NULL, 0, NULL, (SQLLEN *) ValuePtr);
      else
	return (SQL_ERROR);

      break;

#if defined (SQL_DESC_ROWVER)
    case SQL_DESC_ROWVER:
      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (!bAppDesc)
	{
	  if (ValuePtr)
	    {
	      *(SQLSMALLINT *) ValuePtr = SQL_FALSE;
	      if (bRowDesc)
		{
		  if (RecNumber > 0 &&
		      desc->d_stmt->stmt_compilation &&
		      desc->d_stmt->stmt_compilation->sc_columns &&
		      BOX_ELEMENTS (desc->d_stmt->stmt_compilation->sc_columns) >= ((uint32) RecNumber))
		    {
		      col_desc_t *cd = (col_desc_t *) desc->d_stmt->stmt_compilation->sc_columns[RecNumber - 1];
		      if (DV_TIMESTAMP == cd->cd_dtp)
			*((SQLSMALLINT *) ValuePtr) = SQL_TRUE;
		    }
		}
	    }
	}
      else
	return (SQL_ERROR);

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLSMALLINT);

      break;
#endif

    case SQL_DESC_CONCISE_TYPE:
    case SQL_DESC_TYPE:
      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (bRowDesc)
	{
	  SQLSMALLINT conciseType;

	  rc = virtodbc__SQLDescribeCol ((SQLHSTMT) desc->d_stmt, RecNumber, NULL, 0, NULL, &conciseType, NULL, NULL, NULL);

	  if (rc != SQL_SUCCESS)
	    return rc;

	  if (FieldIdentifier == SQL_DESC_TYPE)
	    {
	      switch (conciseType)
		{
		case SQL_TYPE_DATE:
		case SQL_TYPE_TIME:
		case SQL_TYPE_TIMESTAMP:
		case SQL_DATE:
		case SQL_TIME:
		case SQL_TIMESTAMP:
		  conciseType = SQL_DATETIME;
		  break;

		case SQL_INTERVAL_MONTH:
		case SQL_INTERVAL_YEAR:
		case SQL_INTERVAL_YEAR_TO_MONTH:
		case SQL_INTERVAL_DAY:
		case SQL_INTERVAL_HOUR:
		case SQL_INTERVAL_MINUTE:
		case SQL_INTERVAL_DAY_TO_HOUR:
		case SQL_INTERVAL_DAY_TO_MINUTE:
		case SQL_INTERVAL_HOUR_TO_MINUTE:
		case SQL_INTERVAL_SECOND:
		case SQL_INTERVAL_DAY_TO_SECOND:
		case SQL_INTERVAL_HOUR_TO_SECOND:
		case SQL_INTERVAL_MINUTE_TO_SECOND:
		  conciseType = SQL_INTERVAL;
		  break;

		default:
		  break;
		}
	    }

	  *(SQLSMALLINT *) ValuePtr = conciseType;
	  return rc;
	}
      break;

    case SQL_DESC_UNNAMED:
      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (!bAppDesc)
	{
	  if (bRowDesc)
	    {
	      if (ValuePtr && RecNumber > 0 &&
		  desc->d_stmt->stmt_compilation &&
		  desc->d_stmt->stmt_compilation->sc_columns &&
		  BOX_ELEMENTS (desc->d_stmt->stmt_compilation->sc_columns) >= ((uint32) RecNumber))
		{
		  col_desc_t *cd = (col_desc_t *) desc->d_stmt->stmt_compilation->sc_columns[RecNumber - 1];
		  if (COL_DESC_IS_EXTENDED (cd) && cd->cd_name != NULL)
		    *(SQLSMALLINT *) ValuePtr = 1;
		  else
		    *(SQLSMALLINT *) ValuePtr = 0;
		}
	    }
	  else
	    {
	      if (ValuePtr && RecNumber > 0 &&
		  desc->d_stmt->stmt_compilation &&
		  BOX_ELEMENTS (desc->d_stmt->stmt_compilation) > 3 &&
		  desc->d_stmt->stmt_compilation->sc_params &&
		  BOX_ELEMENTS (desc->d_stmt->stmt_compilation->sc_params) >= ((uint32) RecNumber))
		{
		  param_desc_t *pd = (param_desc_t *) desc->d_stmt->stmt_compilation->sc_params[RecNumber - 1];
		  if (PARAM_DESC_IS_EXTENDED (pd) && pd->pd_name != NULL)
		    *(SQLSMALLINT *) ValuePtr = 1;
		  else
		    *(SQLSMALLINT *) ValuePtr = 0;
		}
	    }
	}
      else
	return (SQL_ERROR);

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLSMALLINT);

      break;

    case SQL_DESC_UPDATABLE:
      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);

      if (!bAppDesc && bRowDesc)
	{
	  if (RecNumber > 0 &&
	      desc->d_stmt->stmt_compilation &&
	      desc->d_stmt->stmt_compilation->sc_columns &&
	      BOX_ELEMENTS (desc->d_stmt->stmt_compilation->sc_columns) >=
	      ((uint32) RecNumber))
	    {
	      col_desc_t *cd =
		  (col_desc_t *) desc->d_stmt->stmt_compilation->
		  sc_columns[RecNumber - 1];
	      if (ValuePtr)
		*((SQLSMALLINT *) ValuePtr) =
		    (SQLSMALLINT) unbox (cd->cd_updatable);
	    }
	}
      else
	return (SQL_ERROR);

      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLSMALLINT);

      break;

    case SQL_DESC_UNSIGNED:
      if (RecNumber > desc_count)
	return (SQL_NO_DATA_FOUND);
      if (bAppDesc)
	return (SQL_ERROR);
      if (ValuePtr)
	*((SQLSMALLINT *) ValuePtr) = 0;
      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLSMALLINT);
      break;

    case SQL_DESC_COL_DV_TYPE:
      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLINTEGER);

      if (RecNumber > desc_count || RecNumber == 0)
	return (SQL_NO_DATA_FOUND);

      if (!bAppDesc && bRowDesc)
	{
          caddr_t *row;
          caddr_t col;

          row = desc->d_stmt->stmt_current_row;
	  if (!row)  /* "Statement not fetched in SQLGetData."); */
	    return SQL_ERROR;

          col = row[RecNumber];
          *(SQLINTEGER *) ValuePtr = (int) DV_TYPE_OF(col);
        }
      else
	return (SQL_ERROR);
      break;

    case SQL_DESC_COL_DT_DT_TYPE:
      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLINTEGER);

      if (RecNumber > desc_count || RecNumber == 0)
	return (SQL_NO_DATA_FOUND);

      if (!bAppDesc && bRowDesc)
	{
          caddr_t *row;
          caddr_t col;

          row = desc->d_stmt->stmt_current_row;
	  if (!row)  /* "Statement not fetched in SQLGetData."); */
	    return SQL_ERROR;

          col = row[RecNumber];
          switch (DV_TYPE_OF(col))
            {
            case DV_TIMESTAMP: /* datetime */
            case DV_DATE:
            case DV_TIME:
            case DV_DATETIME:
               *(SQLINTEGER *) ValuePtr = (int) DT_DT_TYPE(col);
               break;
            default:
               *(SQLINTEGER *) ValuePtr = 0;
               break;
            }
        }
      else
	return (SQL_ERROR);
      break;


    case SQL_DESC_COL_LITERAL_ATTR:
      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLINTEGER);

      if (RecNumber > desc_count || RecNumber == 0)
	return (SQL_NO_DATA_FOUND);

      if (!bAppDesc && bRowDesc)
	{
          caddr_t *row;
          caddr_t col;

          row = desc->d_stmt->stmt_current_row;
	  if (!row)  /* "Statement not fetched in SQLGetData."); */
	    return SQL_ERROR;

          col = row[RecNumber];
          if (DV_TYPE_OF(col) == DV_RDF)
            {
              int val;
              unsigned short lang, type;
	      rdf_box_t * rb = (rdf_box_t *) col;
	      lang = rb->rb_lang;
	      type = rb->rb_type;
              val =lang << 16 | type;
              *(SQLINTEGER *) ValuePtr = val;
            }
          else
            {
              *(SQLINTEGER *) ValuePtr = 0;
            }
        }
      else
	return (SQL_ERROR);
      break;

    case SQL_DESC_COL_LITERAL_LANG:
    case SQL_DESC_COL_LITERAL_TYPE:
	{
	  cli_connection_t  * con = desc->d_stmt->stmt_connection;
	  if (RecNumber > desc_count || RecNumber == 0)
	    return (SQL_NO_DATA_FOUND);
	  if (!bAppDesc && bRowDesc)
	    {
	      caddr_t *row;
	      caddr_t col;
	      caddr_t val = NULL;

	      row = desc->d_stmt->stmt_current_row;
	      if (!row)  /* "Statement not fetched in SQLGetData."); */
		return SQL_ERROR;

	      col = row[RecNumber];
	      if (DV_TYPE_OF(col) == DV_RDF)
		{
		  rdf_box_t * rb = (rdf_box_t *) col;
		  val = get_rdf_literal_prop (con, FieldIdentifier, (FieldIdentifier == SQL_DESC_COL_LITERAL_LANG ? rb->rb_lang : rb->rb_type));
		}
	      V_SET_ODBC_STR (val, ValuePtr, BufferLength, StringLengthPtr, &desc->d_stmt->stmt_error);
	    }
	  else
	    return (SQL_ERROR);
	}
      break;

    case SQL_DESC_COL_BOX_FLAGS:
      if (StringLengthPtr)
	*StringLengthPtr = sizeof (SQLINTEGER);

      if (RecNumber > desc_count || RecNumber == 0)
	return (SQL_NO_DATA_FOUND);

      if (!bAppDesc && bRowDesc)
	{
          caddr_t *row;
          caddr_t col;

          row = desc->d_stmt->stmt_current_row;
	  if (!row)  /* "Statement not fetched in SQLGetData."); */
	    return SQL_ERROR;

          col = row[RecNumber];
          if (DV_TYPE_OF(col) == DV_STRING)
            {
              *(SQLINTEGER *) ValuePtr = box_flags(col);
            }
          else
            {
              *(SQLINTEGER *) ValuePtr = 0;
            }
        }
      else
	return (SQL_ERROR);
      break;


    default:
      cli_dbg_printf ((": SQLGetDescField(...,Field %d, UNKNOWN (%d), ...) called\n", RecNumber, FieldIdentifier));
      break;
    }

  return (rc);
}


SQLRETURN SQL_API
SQLGetDescField (SQLHDESC descriptorHandle,
    SQLSMALLINT RecNumber,
    SQLSMALLINT FieldIdentifier,
    SQLPOINTER ValuePtr,
    SQLINTEGER BufferLength,
    SQLINTEGER * StringLengthPtr)
{
  DESC (desc, descriptorHandle);
  switch (FieldIdentifier)
    {
    case SQL_DESC_NAME:
    case SQL_DESC_LABEL:
    case SQL_DESC_SCHEMA_NAME:
    case SQL_DESC_BASE_COLUMN_NAME:
    case SQL_DESC_BASE_TABLE_NAME:
    case SQL_DESC_TABLE_NAME:
    case SQL_DESC_CATALOG_NAME:
    case SQL_DESC_LITERAL_PREFIX:
    case SQL_DESC_LITERAL_SUFFIX:
    case SQL_DESC_TYPE_NAME:
    case SQL_DESC_LOCAL_TYPE_NAME:
      {
	SQLRETURN rc;
	NDEFINE_OUTPUT_NONCHAR_NARROW (ValuePtr, BufferLength, StringLengthPtr, desc->d_stmt->stmt_connection, SQLINTEGER);

	NMAKE_OUTPUT_NONCHAR_NARROW (ValuePtr, BufferLength, desc->d_stmt->stmt_connection);

	rc = virtodbc__SQLGetDescField (descriptorHandle, RecNumber, FieldIdentifier, _ValuePtr, _BufferLength, _StringLengthPtr);
	NSET_AND_FREE_OUTPUT_NONCHAR_NARROW (ValuePtr, BufferLength, StringLengthPtr, desc->d_stmt->stmt_connection);
	return rc;
      }

    default:
      return virtodbc__SQLGetDescField (descriptorHandle, RecNumber, FieldIdentifier, ValuePtr, BufferLength, StringLengthPtr);
    }
}


/* SQLSetDescField */

SQLRETURN SQL_API
virtodbc__SQLSetDescField (SQLHDESC descriptorHandle,
    SQLSMALLINT RecNumber,
    SQLSMALLINT FieldIdentifier,
    SQLPOINTER ValuePtr,
    SQLINTEGER BufferLength)
{
  DESC (desc, descriptorHandle);
#if defined(DEBUG)
  char *szDescType;
  char szDebugBuffer[256];
#endif
  int bAppDesc = 0, bRowDesc = 0;

  if (!desc)
    return (SQL_INVALID_HANDLE);

  bAppDesc = (desc->d_type == ROW_APP_DESCRIPTOR || desc->d_type == PARAM_APP_DESCRIPTOR);
  bRowDesc = (desc->d_type == ROW_APP_DESCRIPTOR || desc->d_type == ROW_IMP_DESCRIPTOR);
#if defined(DEBUG)
  switch (desc->d_type)
    {
    case ROW_APP_DESCRIPTOR:
      szDescType = "ARD";
      break;

    case ROW_IMP_DESCRIPTOR:
      szDescType = "IRD";
      break;

    case PARAM_IMP_DESCRIPTOR:
      szDescType = "IPD";
      break;

    case PARAM_APP_DESCRIPTOR:
      szDescType = "APD";
      break;

    default:
      szDescType = "UNKNOWN_DESC";
    }
  cli_dbg_printf ((szDescType));
#endif

  switch (FieldIdentifier)
    {

    case SQL_DESC_ARRAY_SIZE:
      cli_dbg_printf ((": SQLSetDescField(..., HEADER, ARRAY_SIZE, ...) called\n"));
      if (!bAppDesc)
	{
	  set_error (&(desc->d_stmt->stmt_error), "HY091", "CL021", "Invalid descriptor type");
	  return SQL_ERROR;
	}

      if (bRowDesc)
	desc->d_stmt->stmt_rowset_size = (SQLULEN) ValuePtr;
      else
	desc->d_stmt->stmt_parm_rows = (SQLULEN) ValuePtr;

      return (SQL_SUCCESS);

    case SQL_DESC_ARRAY_STATUS_PTR:
      cli_dbg_printf ((": SQLSetDescField(..., HEADER, ARRAY_STATUS_PTR, ...) called\n"));
      if (bRowDesc)
	desc->d_stmt->stmt_row_status = (SQLUSMALLINT *) ValuePtr;
      else
	desc->d_stmt->stmt_param_status = (SQLUSMALLINT *) ValuePtr;

      return SQL_SUCCESS;

    case SQL_DESC_BIND_OFFSET_PTR:
      cli_dbg_printf ((": SQLSetDescField(..., HEADER, BIND_OFFSET_PTR, ...) called\n"));
      if (!bAppDesc)
	{
	  set_error (&desc->d_stmt->stmt_error, "HY091", "CL022", "Invalid descriptor type");
	  return SQL_ERROR;
	}

      if (bRowDesc)
	desc->d_stmt->stmt_imp_row_descriptor->d_bind_offset_ptr = (SQLINTEGER *) ValuePtr;
      else
	desc->d_stmt->stmt_imp_param_descriptor->d_bind_offset_ptr = (SQLINTEGER *) ValuePtr;

      return SQL_SUCCESS;

    case SQL_DESC_BIND_TYPE:
      cli_dbg_printf ((": SQLSetDescField(..., HEADER, BIND_TYPE, ...) called\n"));
      if (!bAppDesc)
	{
	  set_error (&desc->d_stmt->stmt_error, "HY091", "CL023", "Invalid descriptor type");
	  return SQL_ERROR;
	}

      if (bRowDesc)
	desc->d_stmt->stmt_bind_type = (int) (ptrlong) ValuePtr;
      else
	desc->d_stmt->stmt_param_bind_type = (int) (ptrlong) ValuePtr;

      return SQL_SUCCESS;

    case SQL_DESC_COUNT:
      cli_dbg_printf ((": SQLSetDescField(..., HEADER, COUNT, ...) called\n"));
      set_error (&desc->d_stmt->stmt_error, "HY091", "CL024", "Not supported");

      return SQL_ERROR;

    case SQL_DESC_ROWS_PROCESSED_PTR:
      cli_dbg_printf ((": SQLSetDescField(..., HEADER, ROWS_PROCESSED_PTR, ...) called\n"));
      if (bAppDesc)
	{
	  set_error (&desc->d_stmt->stmt_error, "HY091", "CL025", "Invalid descriptor type");

	  return SQL_ERROR;
	}

      if (bRowDesc)
	desc->d_stmt->stmt_rows_fetched_ptr = (SQLULEN *) ValuePtr;
      else
	desc->d_stmt->stmt_pirow = (SQLULEN *) ValuePtr;

      return SQL_SUCCESS;

    case SQL_DESC_DATA_PTR:
      if (bAppDesc)
	{
	  if (bRowDesc)
	    {
	      col_binding_t *col = stmt_nth_col (desc->d_stmt, RecNumber);
	      col->cb_place = (caddr_t) ValuePtr;

	      return (SQL_SUCCESS);
	    }
	  else
	    {
	      parm_binding_t *pb = stmt_nth_parm (desc->d_stmt, RecNumber);
	      pb->pb_place = (caddr_t) ValuePtr;

	      return (SQL_SUCCESS);
	    }
	}
      break;

    case SQL_DESC_OCTET_LENGTH:
      if (bAppDesc)
	{
	  if (bRowDesc)
	    {
	      col_binding_t *col = stmt_nth_col (desc->d_stmt, RecNumber);
	      col->cb_max_length = (SQLLEN) ValuePtr;

	      return (SQL_SUCCESS);
	    }
	  else
	    {
	      parm_binding_t *pb = stmt_nth_parm (desc->d_stmt, RecNumber);
	      pb->pb_max_length = (SQLULEN) ValuePtr;

	      return (SQL_SUCCESS);
	    }
	}
      break;
    case SQL_DESC_OCTET_LENGTH_PTR:
      if (bAppDesc)
	{
	  if (bRowDesc)
	    {
	      col_binding_t *col = stmt_nth_col (desc->d_stmt, RecNumber);
	      col->cb_length = (SQLLEN *) ValuePtr;

	      return (SQL_SUCCESS);
	    }
	  else
	    {
	      parm_binding_t *pb = stmt_nth_parm (desc->d_stmt, RecNumber);
	      pb->pb_length = (SQLLEN *) ValuePtr;

	      return (SQL_SUCCESS);
	    }
	}
      break;

    case SQL_DESC_TYPE:
      if (bAppDesc)
	{
	  if (bRowDesc)
	    {
	      col_binding_t *col = stmt_nth_col (desc->d_stmt, RecNumber);
	      col->cb_c_type = (int) (ptrlong) ValuePtr;

	      return (SQL_SUCCESS);
	    }
	  else
	    {
	      parm_binding_t *pb = stmt_nth_parm (desc->d_stmt, RecNumber);
	      pb->pb_c_type = (int) (ptrlong) ValuePtr;

	      return (SQL_SUCCESS);
	    }
	}
      break;

    case SQL_DESC_DATETIME_INTERVAL_CODE:
    case SQL_DESC_DATETIME_INTERVAL_PRECISION:
    case SQL_DESC_DISPLAY_SIZE:
    case SQL_DESC_FIXED_PREC_SCALE:
    case SQL_DESC_INDICATOR_PTR:
    case SQL_DESC_LABEL:
    case SQL_DESC_LENGTH:
    case SQL_DESC_LITERAL_PREFIX:
    case SQL_DESC_LITERAL_SUFFIX:
    case SQL_DESC_LOCAL_TYPE_NAME:
    case SQL_DESC_NAME:
    case SQL_DESC_NULLABLE:
    case SQL_DESC_NUM_PREC_RADIX:
    case SQL_DESC_AUTO_UNIQUE_VALUE:
    case SQL_DESC_BASE_COLUMN_NAME:
    case SQL_DESC_BASE_TABLE_NAME:
    case SQL_DESC_CASE_SENSITIVE:
    case SQL_DESC_TABLE_NAME:
    case SQL_DESC_SCHEMA_NAME:
    case SQL_DESC_CATALOG_NAME:
    case SQL_DESC_CONCISE_TYPE:
    case SQL_DESC_TYPE_NAME:
    case SQL_DESC_UNNAMED:
    case SQL_DESC_UNSIGNED:
    case SQL_DESC_UPDATABLE:
    case SQL_DESC_SCALE:
      cli_dbg_printf ((": SQLSetDescField(..., FIELD %d, %d, ...) called\n", RecNumber, FieldIdentifier));
      return SQL_SUCCESS;

    default:
      cli_dbg_printf ((": SQLSetDescField(UNKNOWN, FIELD ? %d, %d, ...) called\n", RecNumber, FieldIdentifier));
      return (SQL_SUCCESS);
    }

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
SQLSetDescField (SQLHDESC descriptorHandle,
    SQLSMALLINT RecNumber,
    SQLSMALLINT FieldIdentifier,
    SQLPOINTER ValuePtr,
    SQLINTEGER BufferLength)
{
  DESC (desc, descriptorHandle);
  switch (FieldIdentifier)
    {
    case SQL_DESC_LITERAL_PREFIX:
    case SQL_DESC_LITERAL_SUFFIX:
    case SQL_DESC_LOCAL_TYPE_NAME:
    case SQL_DESC_NAME:
    case SQL_DESC_LABEL:
    case SQL_DESC_TABLE_NAME:
    case SQL_DESC_SCHEMA_NAME:
    case SQL_DESC_CATALOG_NAME:
    case SQL_DESC_BASE_COLUMN_NAME:
    case SQL_DESC_BASE_TABLE_NAME:
    case SQL_DESC_CONCISE_TYPE:
    case SQL_DESC_TYPE_NAME:
      {
	SQLRETURN rc;

	NDEFINE_INPUT_NONCHAR_NARROW (ValuePtr, BufferLength);

	NMAKE_INPUT_NONCHAR_NARROW (ValuePtr, BufferLength, desc->d_stmt->stmt_connection);

	rc = virtodbc__SQLSetDescField (descriptorHandle, RecNumber, FieldIdentifier, _ValuePtr, (SQLINTEGER) _BufferLength);

	NFREE_INPUT_NONCHAR_NARROW (ValuePtr, BufferLength);

	return rc;
      }

    default:
      return virtodbc__SQLSetDescField (descriptorHandle, RecNumber, FieldIdentifier, ValuePtr, BufferLength);
    }
}


/* SQLGetDescRec */

SQLRETURN SQL_API
virtodbc__SQLGetDescRec (SQLHDESC descriptorHandle,
    SQLSMALLINT RecNumber,
    SQLCHAR * Name,
    SQLSMALLINT BufferLength,
    SQLSMALLINT * StringLengthPtr,
    SQLSMALLINT * TypePtr,
    SQLSMALLINT * SubTypePtr,
    SQLLEN * LengthPtr,
    SQLSMALLINT * PrecisionPtr,
    SQLSMALLINT * ScalePtr,
    SQLSMALLINT * NullablePtr)
{
  DESC (desc, descriptorHandle);
  int bAppDesc = 0, bRowDesc = 0;

  cli_dbg_printf (("SQLGetDescRec called\n"));
  if (!desc)
    return (SQL_INVALID_HANDLE);

  bAppDesc = (desc->d_type == ROW_APP_DESCRIPTOR || desc->d_type == PARAM_APP_DESCRIPTOR);
  bRowDesc = (desc->d_type == ROW_APP_DESCRIPTOR || desc->d_type == ROW_IMP_DESCRIPTOR);

  if (bRowDesc)
    return virtodbc__SQLDescribeCol ((SQLHSTMT) desc->d_stmt, RecNumber, Name,
	BufferLength, StringLengthPtr, TypePtr, (SQLULEN *) LengthPtr, ScalePtr, NullablePtr);
  else
    return (SQL_SUCCESS);
}


SQLRETURN SQL_API
SQLGetDescRec (SQLHDESC descriptorHandle,
    SQLSMALLINT RecNumber,
    SQLCHAR * wszName,
    SQLSMALLINT cbName,
    SQLSMALLINT * pcbName,
    SQLSMALLINT * TypePtr,
    SQLSMALLINT * SubTypePtr,
    SQLLEN * LengthPtr,
    SQLSMALLINT * PrecisionPtr,
    SQLSMALLINT * ScalePtr,
    SQLSMALLINT * NullablePtr)
{
  SQLRETURN rc;
  DESC (desc, descriptorHandle);
  NDEFINE_OUTPUT_CHAR_NARROW (Name, desc->d_stmt->stmt_connection, SQLSMALLINT);

  NMAKE_OUTPUT_CHAR_NARROW (Name, desc->d_stmt->stmt_connection);

  rc = virtodbc__SQLGetDescRec (descriptorHandle, RecNumber, szName, _cbName,
      _pcbName, TypePtr, SubTypePtr, LengthPtr, PrecisionPtr, ScalePtr, NullablePtr);

  NSET_AND_FREE_OUTPUT_CHAR_NARROW (Name, desc->d_stmt->stmt_connection);

  return rc;
}


/* SQLSetDescRec */

SQLRETURN SQL_API
SQLSetDescRec (SQLHDESC arg0,
    SQLSMALLINT arg1,
    SQLSMALLINT arg2,
    SQLSMALLINT arg3,
    SQLLEN arg4,
    SQLSMALLINT arg5,
    SQLSMALLINT arg6,
    SQLPOINTER arg7,
    SQLLEN * arg8,
    SQLLEN * arg9)
{
  cli_dbg_printf (("SQLSetDescRec called\n"));

  return (SQL_SUCCESS);
}


/* SQLCopyDesc */

SQLRETURN SQL_API
SQLCopyDesc (SQLHDESC arg0,
    SQLHDESC arg1)
{
  DESC (desc, arg1);
  cli_dbg_printf (("SQLCopyDesc called\n"));

  set_error (&desc->d_stmt->stmt_connection->con_environment->env_error, "IM001", "CL026", "Driver does not support this function");

  return (SQL_ERROR);
}


/* SQLColAttribute */
SQLRETURN SQL_API
SQLColAttribute (SQLHSTMT statementHandle,
    SQLUSMALLINT ColumnNumber,
    SQLUSMALLINT FieldIdentifier,
    SQLPOINTER CharacterAttributePtr,
    SQLSMALLINT BufferLength,
    SQLSMALLINT * StringLengthPtr,
#if !defined (NO_UDBC_SDK) && !defined (WIN32)
    SQLPOINTER  NumericAttributePtr
#else
    SQLLEN *NumericAttributePtr
#endif
    )
{
  return virtodbc__SQLColAttribute (statementHandle,
      ColumnNumber, FieldIdentifier, CharacterAttributePtr, BufferLength, StringLengthPtr, NumericAttributePtr);
}


SQLRETURN SQL_API
virtodbc__SQLColAttribute (SQLHSTMT statementHandle,
    SQLUSMALLINT ColumnNumber,
    SQLUSMALLINT FieldIdentifier,
    SQLPOINTER CharacterAttributePtr,
    SQLSMALLINT BufferLength,
    SQLSMALLINT * StringLengthPtr,
#if !defined (NO_UDBC_SDK) && !defined (WIN32)
    SQLPOINTER  NumericAttributePtr
#else
    SQLLEN *NumericAttributePtr
#endif
    )
{
  STMT (stmt, statementHandle);

  switch (FieldIdentifier)
    {
    case SQL_DESC_NULLABLE:
      FieldIdentifier = SQL_COLUMN_NULLABLE;
      break;

    case SQL_DESC_SCALE:
      FieldIdentifier = SQL_COLUMN_SCALE;
      break;

    case SQL_DESC_LENGTH:
    case SQL_DESC_OCTET_LENGTH:
    case SQL_DESC_PRECISION:
      FieldIdentifier = SQL_COLUMN_PRECISION;
      break;

    case SQL_DESC_CONCISE_TYPE:
      FieldIdentifier = SQL_COLUMN_TYPE;
      break;

    case SQL_DESC_AUTO_UNIQUE_VALUE:
      FieldIdentifier = SQL_COLUMN_AUTO_INCREMENT;
      break;

    case SQL_DESC_CASE_SENSITIVE:
      FieldIdentifier = SQL_COLUMN_CASE_SENSITIVE;
      break;

    case SQL_DESC_DISPLAY_SIZE:
      FieldIdentifier = SQL_COLUMN_DISPLAY_SIZE;
      break;

      /* SQLCHAR */
    case SQL_DESC_LITERAL_SUFFIX:
    case SQL_DESC_LITERAL_PREFIX:
    case SQL_DESC_BASE_COLUMN_NAME:
    case SQL_DESC_BASE_TABLE_NAME:
    case SQL_DESC_CATALOG_NAME:
    case SQL_DESC_LABEL:
    case SQL_DESC_LOCAL_TYPE_NAME:
    case SQL_DESC_NAME:
    case SQL_DESC_TABLE_NAME:
    case SQL_DESC_TYPE_NAME:
    case SQL_DESC_SCHEMA_NAME:
      {
	SQLINTEGER datalen;
	SQLRETURN rc;

	rc = virtodbc__SQLGetDescField ((SQLHDESC) stmt->stmt_imp_row_descriptor, ColumnNumber, FieldIdentifier, CharacterAttributePtr, BufferLength, &datalen);

	if (StringLengthPtr)
	  *StringLengthPtr = (SQLSMALLINT) datalen;

	return rc;
      }

      /* SQLSMALLINT */
    case SQL_DESC_TYPE:
    case SQL_DESC_COUNT:
    case SQL_DESC_FIXED_PREC_SCALE:
    case SQL_DESC_SEARCHABLE:
    case SQL_DESC_UNNAMED:
    case SQL_DESC_UNSIGNED:
    case SQL_DESC_UPDATABLE:
      {
	SQLSMALLINT data = 0;
	SQLINTEGER datalen;
	SQLRETURN rc;

	rc = virtodbc__SQLGetDescField ((SQLHDESC) stmt->stmt_imp_row_descriptor, ColumnNumber, FieldIdentifier, &data, sizeof (data), &datalen);

	if (NumericAttributePtr)
	  *NumericAttributePtr = (SQLLEN) data;

	if (StringLengthPtr)
	  *StringLengthPtr = (SQLSMALLINT) datalen;

	return rc;
      }

      /* SQLINTEGER */
    case SQL_DESC_NUM_PREC_RADIX:
      {
	SQLINTEGER data = 0;
	SQLINTEGER datalen;
	SQLRETURN rc;

	rc = virtodbc__SQLGetDescField ((SQLHDESC) stmt->stmt_imp_row_descriptor, ColumnNumber, FieldIdentifier, &data, sizeof (data), &datalen);

	if (NumericAttributePtr)
	  *NumericAttributePtr = (SQLLEN) data;

	if (StringLengthPtr)
	  *StringLengthPtr = (SQLSMALLINT) datalen;

	return rc;
      }
    }

  return (virtodbc__SQLColAttributes (statementHandle, ColumnNumber, FieldIdentifier, CharacterAttributePtr, BufferLength, StringLengthPtr, (SQLLEN *) NumericAttributePtr));
}


/* SQLEndTran */

SQLRETURN SQL_API
SQLEndTran (SQLSMALLINT handleType,
    SQLHANDLE Handle,
    SQLSMALLINT completionType)
{
  cli_dbg_printf (("SQLEndTran called\n"));
  switch (handleType)
    {
    case SQL_HANDLE_DBC:
      {
	CON (con, Handle);

	if (!con)
	  return (SQL_INVALID_HANDLE);

	set_error (&con->con_error, NULL, NULL, NULL);

	return virtodbc__SQLTransact (SQL_NULL_HENV, (SQLHDBC) con, completionType);
      }

    case SQL_HANDLE_ENV:
      {
	ENV (env, Handle);

	if (!env)
	  return (SQL_INVALID_HANDLE);

	set_error (&env->env_error, NULL, NULL, NULL);

	return virtodbc__SQLTransact ((SQLHENV) env, SQL_NULL_HDBC, completionType);
      }
    }

  return (SQL_SUCCESS);
}


/* SQLBulkOperations */

SQLRETURN SQL_API
SQLBulkOperations (SQLHSTMT statementHandle,
    SQLSMALLINT Operation)
{
  STMT (stmt, statementHandle);

  if (!statementHandle)
    return (SQL_INVALID_HANDLE);

  switch (Operation)
    {
    case SQL_ADD:
      cli_dbg_printf (("SQLBulkOperations (..., SQL_ADD, ...) called\n"));
      stmt->stmt_fetch_mode = FETCH_EXT;

      if (!stmt->stmt_rowset)
	{
	  /* when SQLBulkOperations is called without prior call SQLExtendedFetch/SQLFetchScroll */
	  stmt->stmt_rowset = (caddr_t **) dk_alloc_box_zero (stmt->stmt_rowset_size * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  stmt->stmt_rowset_fill = 0;
	  stmt->stmt_current_row = NULL;
	}

      return virtodbc__SQLSetPos (statementHandle, 0, SQL_ADD, SQL_LOCK_NO_CHANGE);

    default:
      cli_dbg_printf (("SQLBulkOperations (..., Bookmark, ...) called - ERROR\n"));
      set_error (&stmt->stmt_error, "HYC00", "CL027", "Optional feature not supported");
      return (SQL_ERROR);
    }
}


/****** SQLFetchScroll ******/

SQLRETURN SQL_API
SQLFetchScroll (SQLHSTMT statementHandle,
    SQLSMALLINT fetchOrientation,
    SQLLEN fetchOffset)
{
  STMT (stmt, statementHandle);
  cli_dbg_printf (("SQLFetchScroll called\n"));

  if (!stmt)
    return (SQL_INVALID_HANDLE);

  stmt->stmt_fetch_mode = FETCH_EXT;

  if (fetchOrientation != SQL_FETCH_BOOKMARK)
    return virtodbc__SQLExtendedFetch (statementHandle, fetchOrientation,
	fetchOffset, stmt->stmt_rows_fetched_ptr, stmt->stmt_row_status, 0);
  else
    {
      return virtodbc__SQLExtendedFetch (statementHandle, fetchOrientation,
	  (stmt->stmt_bookmark_ptr ? *((SQLINTEGER *) stmt->stmt_bookmark_ptr) : 0),
	  stmt->stmt_rows_fetched_ptr, stmt->stmt_row_status, fetchOffset);
    }
}


/**** */

SQLRETURN SQL_API
SQLCloseCursor (SQLHSTMT hstmt)
{
  STMT (stmt, hstmt);

  if (stmt->stmt_compilation && stmt->stmt_compilation->sc_is_select)
    return virtodbc__SQLFreeStmt (hstmt, SQL_CLOSE);
  else
    {
      set_error (&stmt->stmt_error, "24000", "CL097", "Invalid cursor state.");

      return SQL_ERROR;
    }
}

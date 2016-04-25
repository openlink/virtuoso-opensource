/*
 *  CLIw.c
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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
#define WCHAR_CAST (wchar_t *)
#else
#define WCHAR_CAST
#endif

#define MAX_MESSAGE_LEN 0

#ifdef STD_N_BYTES_IN_PCB
#define N_BYTES_PER_CHAR  sizeof (wchar_t)
#else
#define N_BYTES_PER_CHAR  1
#endif

#define DEFINE_INPUT_NARROW(param) \
  SQLCHAR *sz##param = NULL

#define MAKE_INPUT_NARROW_N(param) \
  if (wsz##param) \
  { \
    len = cb##param > 0 ? cb##param : wcslen (WCHAR_CAST wsz##param); \
    sz##param = (SQLCHAR *) dk_alloc_box (len + 1, DV_LONG_STRING); \
    cli_wide_to_narrow (charset, 0, WCHAR_CAST wsz##param, len, sz##param, len, NULL, NULL); \
    sz##param[len] = 0; \
  }

#define MAKE_INPUT_NARROW(param, con) \
  if (!(con)->con_defs.cdef_utf8_execs) \
  { \
    MAKE_INPUT_NARROW_N(param); \
  } \
  else \
  { \
    if (wsz##param) \
      { \
	len = cb##param > 0 ? cb##param : wcslen (WCHAR_CAST wsz##param); \
	sz##param = (SQLCHAR *) box_wide_as_utf8_char ((caddr_t) wsz##param, len, DV_LONG_STRING); \
      } \
  }

#define MAKE_INPUT_ESCAPED_NARROW_N(param) \
  if (wsz##param) \
  { \
    unsigned out_len; \
    len = cb##param > 0 ? cb##param : wcslen (WCHAR_CAST wsz##param); \
    sz##param = (SQLCHAR *) dk_alloc_box (len * 9 + 1, DV_LONG_STRING); \
    out_len = (unsigned) cli_wide_to_escaped (charset, 0, WCHAR_CAST wsz##param, len, sz##param, len * 9, NULL, NULL); \
    sz##param[out_len] = 0; \
  }

#define MAKE_INPUT_ESCAPED_NARROW(param, con) \
  if (wsz##param) \
  { \
    if (!(con)->con_defs.cdef_utf8_execs) \
      { \
	MAKE_INPUT_ESCAPED_NARROW_N(param) \
      } \
    else \
      { \
	len = cb##param > 0 ? cb##param : wcslen (WCHAR_CAST wsz##param); \
	sz##param = (SQLCHAR *) box_wide_as_utf8_char ((caddr_t) wsz##param, len, DV_LONG_STRING); \
      } \
  }

#define FREE_INPUT_NARROW(param) \
  if (wsz##param) \
  { \
    dk_free_box ((box_t) sz##param); \
  }

#define DEFINE_OUTPUT_CHAR_NARROW_N(param, type) \
  SQLCHAR *sz##param = NULL; \
  type _vpcb##param, *_pcb##param = &_vpcb##param; \
  type _cb##param = MAX_MESSAGE_LEN + cb##param / sizeof (wchar_t)

#define MAKE_OUTPUT_CHAR_NARROW_N(param) \
  if (wsz##param) \
    { \
      sz##param = (SQLCHAR *) dk_alloc_box (cb##param, DV_LONG_STRING); \
    }

#define SET_AND_FREE_OUTPUT_CHAR_NARROW_N(param) \
  if (wsz##param) \
    { \
      if (cb##param > 0) \
	{ \
	  SQLSMALLINT len1 = (SQLSMALLINT) cli_narrow_to_wide (charset, 0, sz##param, *_pcb##param, WCHAR_CAST wsz##param, cb##param - 1); \
	  if (len1 >= 0) \
	    (WCHAR_CAST wsz##param)[len1] = 0; \
	  else \
	    (WCHAR_CAST wsz##param)[0] = 0; \
	  *_pcb##param = len1; \
	} \
      dk_free_box ((box_t) sz##param); \
    } \
  if (pcb##param) \
    *pcb##param = *_pcb##param * N_BYTES_PER_CHAR;

#define DEFINE_OUTPUT_CHAR_NARROW(param, con, type) \
  SQLCHAR *sz##param = NULL; \
  type _vpcb##param, *_pcb##param = &_vpcb##param; \
  type _cb##param = MAX_MESSAGE_LEN + cb##param * ((con)->con_defs.cdef_utf8_execs ? VIRT_MB_CUR_MAX : 1)

#define MAKE_OUTPUT_CHAR_NARROW(param, con) \
  if (wsz##param) \
    { \
      if ((con)->con_defs.cdef_utf8_execs) \
	sz##param = (SQLCHAR *) dk_alloc_box (cb##param * VIRT_MB_CUR_MAX, DV_LONG_STRING); \
      else \
	sz##param = (SQLCHAR *) dk_alloc_box (_cb##param, DV_LONG_STRING); \
    }

#define SET_AND_FREE_OUTPUT_CHAR_NARROW(param, con) \
  if (wsz##param) \
    { \
      SQLSMALLINT len1; \
      if ((con)->con_defs.cdef_utf8_execs) \
	{ \
	  virt_mbstate_t ps; \
	  unsigned char *src = sz##param; \
	  memset (&ps, 0, sizeof (virt_mbstate_t)); \
	  if (cb##param > 0) \
	    { \
	      len1 = (SQLSMALLINT) virt_mbsnrtowcs (WCHAR_CAST wsz##param, &src, *_pcb##param, cb##param - 1, &ps); \
	      if (len1 >= 0) \
		(WCHAR_CAST wsz##param)[len1] = 0; \
	      else \
		(WCHAR_CAST wsz##param)[0] = 0; \
	    } \
	  if (pcb##param) \
	    *pcb##param = *_pcb##param; \
	} \
      else \
	{ \
	  if (cb##param > 0) \
	    { \
	      len1 = (SQLSMALLINT) cli_narrow_to_wide (charset, 0, sz##param, *_pcb##param, WCHAR_CAST wsz##param, cb##param - 1); \
	      if (len1 >= 0) \
		(WCHAR_CAST wsz##param)[len1] = 0; \
	      else \
		(WCHAR_CAST wsz##param)[0] = 0; \
	      *_pcb##param = len1; \
	    } \
	} \
      dk_free_box ((box_t) sz##param); \
    } \
  if (pcb##param) \
    *pcb##param = *_pcb##param * N_BYTES_PER_CHAR;


#define DEFINE_OUTPUT_NONCHAR_NARROW(wide, len, pcb, con, type) \
  type _##len = (type) (len / sizeof (wchar_t) * (( (con) && (con)->con_defs.cdef_utf8_execs) ? VIRT_MB_CUR_MAX : 1)); \
  caddr_t _##wide = NULL; \
  type _v##pcb, * _##pcb = &_v##pcb


#define MAKE_OUTPUT_NONCHAR_NARROW(wide, len, con) \
  if (wide && len > 0) \
    { \
      if ((con) && (con)->con_defs.cdef_utf8_execs) \
	_##wide = (char *) dk_alloc_box (_##len * VIRT_MB_CUR_MAX + 1, DV_LONG_STRING); \
      else \
	_##wide = (char *) dk_alloc_box (_##len + 1, DV_LONG_STRING); \
    }

#define SET_AND_FREE_OUTPUT_NONCHAR_NARROW(wide, len, plen, con) \
  if (wide && len > 0) \
    { \
      size_t len2 = (!_##plen || *_##plen) == SQL_NTS ? strlen (_##wide) : *_##plen; \
      if ((con) && (con)->con_defs.cdef_utf8_execs) \
	{ \
	  virt_mbstate_t ps; \
	  SQLSMALLINT len1; \
	  unsigned char *src = (unsigned char *) _##wide; \
	  memset (&ps, 0, sizeof (virt_mbstate_t)); \
	  len1 = (SQLSMALLINT) virt_mbsnrtowcs (WCHAR_CAST wide, &src, len2, len, &ps); \
	  if (len1 >= 0) \
	    { \
	      if (plen) \
		*plen = len1 * /*N_BYTES_PER_CHAR */sizeof (wchar_t); \
	      ((wchar_t *) wide)[len1] = 0; \
	    } \
	  else \
	    { \
	      dk_free_box ((box_t) _##wide); \
	      return SQL_ERROR; \
	    } \
	} \
      else \
	{ \
	  size_t len1 = cli_narrow_to_wide (charset, 0, (unsigned char *) _##wide, len2, WCHAR_CAST wide, len); \
	  ((wchar_t *) wide)[len1] = 0; \
	  if (plen) \
	    *plen = (SQLSMALLINT) len2 * /*N_BYTES_PER_CHAR */sizeof (wchar_t); \
	} \
      dk_free_box ((box_t) _##wide); \
    } \
  else \
    { \
      if (plen) \
	*plen = (SQLSMALLINT) *_##plen * /*N_BYTES_PER_CHAR */sizeof (wchar_t); \
    }


#define DEFINE_INPUT_NONCHAR_NARROW(wide, len) \
  long _##len = (long) (len < 0 ? wcslen ((wchar_t *)wide) : len); \
      unsigned char * _##wide = NULL

#define MAKE_INPUT_NONCHAR_NARROW_N(wide, len) \
    if (_##len > 0 && wide) \
      { \
	_##wide = (unsigned char *) dk_alloc_box (_##len + 1, DV_LONG_STRING); \
	cli_wide_to_narrow (charset, 0, (wchar_t *)wide, _##len, _##wide, _##len, NULL, NULL); \
	_##wide[_##len] = 0; \
      }

#define MAKE_INPUT_NONCHAR_NARROW(wide, len, con) \
    if ((con)->con_defs.cdef_utf8_execs) \
      { \
	if (_##len > 0 && wide) \
	  { \
	    _##wide = (unsigned char *) box_wide_as_utf8_char ((caddr_t) wide, _##len, DV_LONG_STRING); \
	    _##len = (long) strlen ((const char *) _##wide); \
	  } \
      } \
    else \
      { \
	MAKE_INPUT_NONCHAR_NARROW_N(wide, len); \
      }

#define FREE_INPUT_NONCHAR_NARROW(wide, len) \
    if (_##len > 0 && wide) \
      { \
	dk_free_box ((box_t) _##wide); \
      }

#if 0
SQLRETURN SQL_API
SQLConnectW (
	SQLHDBC hdbc,
	SQLWCHAR * wszDSN,
	SQLSMALLINT cbDSN,
	SQLWCHAR * wszUID,
	SQLSMALLINT cbUID,
	SQLWCHAR * wszPWD,
	SQLSMALLINT cbPWD)
{
  long len;
  CON_CHARSET (hdbc);
  SQLRETURN rc;
  DEFINE_INPUT_NARROW (DSN);
  DEFINE_INPUT_NARROW (UID);
  DEFINE_INPUT_NARROW (PWD);

  MAKE_INPUT_NARROW_N (DSN);
  MAKE_INPUT_NARROW_N (UID);
  MAKE_INPUT_NARROW_N (PWD);

  rc = SQLConnect (hdbc, szDSN, SQL_NTS, szUID, SQL_NTS, szPWD, SQL_NTS);

  FREE_INPUT_NARROW (DSN);
  FREE_INPUT_NARROW (UID);
  FREE_INPUT_NARROW (PWD);

  return rc;
}
#endif


SQLRETURN SQL_API
SQLBrowseConnectW (
      SQLHDBC hdbc,
      SQLWCHAR * szConnStrIn,
      SQLSMALLINT cbConnStrIn,
      SQLWCHAR * szConnStrOut,
      SQLSMALLINT cbConnStrOutMax,
      SQLSMALLINT * pcbConnStrOut)
{
  NOT_IMPL_FUN (hdbc, "Function not supported: SQLBrowseConnect");
}


SQLRETURN SQL_API virtodbc__SQLColAttributesW(
    SQLHSTMT           hstmt,
    SQLUSMALLINT       icol,
    SQLUSMALLINT       fDescType,
    SQLPOINTER         rgbDesc,
    SQLSMALLINT        cbDescMax,
    SQLSMALLINT        *pcbDesc,
    SQLLEN             *pfDesc)
{
  STMT_CHARSET (hstmt);

  switch (fDescType)
    {
    case SQL_COLUMN_LABEL:
    case SQL_COLUMN_NAME:
    case SQL_COLUMN_TYPE_NAME:
    case SQL_COLUMN_TABLE_NAME:
    case SQL_COLUMN_OWNER_NAME:
    case SQL_COLUMN_QUALIFIER_NAME:
#if ODBCVER >= 0x0300
    case SQL_DESC_BASE_COLUMN_NAME:
    case SQL_DESC_BASE_TABLE_NAME:
    case SQL_DESC_LITERAL_PREFIX:
    case SQL_DESC_LITERAL_SUFFIX:
    case SQL_DESC_LOCAL_TYPE_NAME:
    case SQL_DESC_NAME:
#endif
      {
	DEFINE_OUTPUT_NONCHAR_NARROW (rgbDesc, cbDescMax, pcbDesc, stmt->stmt_connection, SQLSMALLINT);
	SQLRETURN rc;

	MAKE_OUTPUT_NONCHAR_NARROW (rgbDesc, cbDescMax, stmt->stmt_connection);

	rc = virtodbc__SQLColAttributes (hstmt, icol, fDescType, _rgbDesc, _cbDescMax, _pcbDesc, pfDesc);

	SET_AND_FREE_OUTPUT_NONCHAR_NARROW (rgbDesc, cbDescMax, pcbDesc, stmt->stmt_connection);

	return rc;
      }

    default:
      return virtodbc__SQLColAttributes (hstmt, icol, fDescType, rgbDesc, cbDescMax, pcbDesc, pfDesc);
    }
}


SQLRETURN SQL_API SQLColAttributesW(
    SQLHSTMT           hstmt,
    SQLUSMALLINT       icol,
    SQLUSMALLINT       fDescType,
    SQLPOINTER         rgbDesc,
    SQLSMALLINT        cbDescMax,
    SQLSMALLINT        *pcbDesc,
    SQLLEN             *pfDesc)
{
  return virtodbc__SQLColAttributesW (hstmt, icol, fDescType, rgbDesc, cbDescMax, pcbDesc, pfDesc);
}


SQLRETURN SQL_API SQLColAttributeW(
	SQLHSTMT	hstmt,
	SQLUSMALLINT	iCol,
	SQLUSMALLINT	iField,
	SQLPOINTER	wszCharAttr,
	SQLSMALLINT	cbCharAttr,
	SQLSMALLINT     *pcbCharAttr,
#if !defined (NO_UDBC_SDK) && !defined (WIN32)
	SQLPOINTER      pNumAttr
#else
	SQLLEN	        *pNumAttr
#endif
	)
{
  SQLRETURN rc;
  STMT_CHARSET (hstmt);

  DEFINE_OUTPUT_NONCHAR_NARROW (wszCharAttr, cbCharAttr, pcbCharAttr, stmt->stmt_connection, SQLSMALLINT);

  MAKE_OUTPUT_NONCHAR_NARROW (wszCharAttr, cbCharAttr, stmt->stmt_connection);

  rc = (virtodbc__SQLColAttribute (hstmt, iCol, iField, _wszCharAttr, _cbCharAttr, _pcbCharAttr, pNumAttr));

  SET_AND_FREE_OUTPUT_NONCHAR_NARROW (wszCharAttr, cbCharAttr, pcbCharAttr, stmt->stmt_connection);

  return rc;
}


SQLRETURN SQL_API
SQLColumnPrivilegesW (
	SQLHSTMT hstmt,
	SQLWCHAR * wszTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLWCHAR * wszTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLWCHAR * wszTableName,
	SQLSMALLINT cbTableName,
	SQLWCHAR * wszColumnName,
	SQLSMALLINT cbColumnName)
{
  size_t len;
  SQLRETURN rc;
  STMT_CHARSET (hstmt);
  DEFINE_INPUT_NARROW (TableQualifier);
  DEFINE_INPUT_NARROW (TableOwner);
  DEFINE_INPUT_NARROW (TableName);
  DEFINE_INPUT_NARROW (ColumnName);

  MAKE_INPUT_NARROW (TableQualifier, stmt->stmt_connection);
  MAKE_INPUT_NARROW (TableOwner, stmt->stmt_connection);
  MAKE_INPUT_NARROW (TableName, stmt->stmt_connection);
  MAKE_INPUT_NARROW (ColumnName, stmt->stmt_connection);

  rc = virtodbc__SQLColumnPrivileges (hstmt, szTableQualifier, cbTableQualifier, szTableOwner, cbTableOwner, szTableName, cbTableName, szColumnName, cbColumnName);

  FREE_INPUT_NARROW (TableQualifier);
  FREE_INPUT_NARROW (TableOwner);
  FREE_INPUT_NARROW (TableName);
  FREE_INPUT_NARROW (ColumnName);

  return rc;
}


SQLRETURN SQL_API
SQLColumnsW (
	SQLHSTMT hstmt,
	SQLWCHAR * wszTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLWCHAR * wszTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLWCHAR * wszTableName,
	SQLSMALLINT cbTableName,
	SQLWCHAR * wszColumnName,
	SQLSMALLINT cbColumnName)
{
  size_t len;
  SQLRETURN rc;
  STMT_CHARSET (hstmt);
  DEFINE_INPUT_NARROW (TableQualifier);
  DEFINE_INPUT_NARROW (TableOwner);
  DEFINE_INPUT_NARROW (TableName);
  DEFINE_INPUT_NARROW (ColumnName);

  MAKE_INPUT_NARROW (TableQualifier, stmt->stmt_connection);
  MAKE_INPUT_NARROW (TableOwner, stmt->stmt_connection);
  MAKE_INPUT_NARROW (TableName, stmt->stmt_connection);
  MAKE_INPUT_NARROW (ColumnName, stmt->stmt_connection);

  rc = virtodbc__SQLColumns (hstmt, szTableQualifier, cbTableQualifier, szTableOwner, cbTableOwner, szTableName, cbTableName, szColumnName, cbColumnName);

  FREE_INPUT_NARROW (TableQualifier);
  FREE_INPUT_NARROW (TableOwner);
  FREE_INPUT_NARROW (TableName);
  FREE_INPUT_NARROW (ColumnName);

  return rc;
}


#if 0
void ParseOptions (char *s, int clean_up);
SQLRETURN SQL_API
SQLDriverConnectW (
    SQLHDBC hdbc,
    HWND hwnd,
    SQLWCHAR * wszConnStrIn,
    SQLSMALLINT cbConnStrIn,
    SQLWCHAR * wszConnStrOut,
    SQLSMALLINT cbConnStrOut,
    SQLSMALLINT * pcbConnStrOut,
    SQLUSMALLINT fDriverCompletion)
{
  SQLRETURN rc;
  long len;
  wcharset_t *charset = NULL;
  DEFINE_INPUT_NARROW (ConnStrIn);
  DEFINE_OUTPUT_CHAR_NARROW_N (ConnStrOut);

  MAKE_INPUT_NARROW_N (ConnStrIn);
  MAKE_OUTPUT_CHAR_NARROW_N (ConnStrOut);

  rc = SQLDriverConnect (hdbc, hwnd, szConnStrIn, cbConnStrIn, szConnStrOut, cbConnStrOut, pcbConnStrOut, fDriverCompletion);

  FREE_INPUT_NARROW (ConnStrIn);
  SET_AND_FREE_OUTPUT_CHAR_NARROW_N (ConnStrOut);

  return rc;
}
#endif


SQLRETURN SQL_API
SQLDescribeColW (
	SQLHSTMT hstmt,
	SQLUSMALLINT icol,
	SQLWCHAR * wszColName,
	SQLSMALLINT cbColName,
	SQLSMALLINT * pcbColName,
	SQLSMALLINT * pfSqlType,
	SQLULEN * pcbColDef,
	SQLSMALLINT * pibScale,
	SQLSMALLINT * pfNullable)
{
  SQLRETURN rc;
  STMT_CHARSET (hstmt);
  DEFINE_OUTPUT_CHAR_NARROW (ColName, stmt->stmt_connection, SQLSMALLINT);

  MAKE_OUTPUT_CHAR_NARROW (ColName, stmt->stmt_connection);

  rc = virtodbc__SQLDescribeCol (hstmt, icol, szColName, _cbColName, _pcbColName, pfSqlType, pcbColDef, pibScale, pfNullable);

  SET_AND_FREE_OUTPUT_CHAR_NARROW (ColName, stmt->stmt_connection);

  return rc;
}


SQLRETURN SQL_API
SQLErrorW (
	SQLHENV henv,
	SQLHDBC hdbc,
	SQLHSTMT hstmt,
	SQLWCHAR * wszSqlState,
	SQLINTEGER * pfNativeError,
	SQLWCHAR * wszErrorMsg,
	SQLSMALLINT cbErrorMsg,
	SQLSMALLINT * pcbErrorMsg)
{
  STMT (stmt, hstmt);
  CON (con, hdbc);
  /*ENV (env, henv); */
  wcharset_t *charset = con ? con->con_charset : (stmt ? stmt->stmt_connection->con_charset : NULL);
  SQLCHAR szSqlState[6];
  SQLRETURN rc;

  if (con || stmt)
    {
      cli_connection_t *conn = con ? con : stmt->stmt_connection;
      DEFINE_OUTPUT_CHAR_NARROW (ErrorMsg, conn, SQLSMALLINT);

      MAKE_OUTPUT_CHAR_NARROW (ErrorMsg, conn);

      rc = virtodbc__SQLError (henv, hdbc, hstmt, szSqlState, pfNativeError, szErrorMsg, _cbErrorMsg, _pcbErrorMsg, 1);

      SET_AND_FREE_OUTPUT_CHAR_NARROW (ErrorMsg, conn);
    }
  else
    {
      DEFINE_OUTPUT_CHAR_NARROW_N (ErrorMsg, SQLSMALLINT);

      MAKE_OUTPUT_CHAR_NARROW_N (ErrorMsg);

      rc = virtodbc__SQLError (henv, hdbc, hstmt, szSqlState, pfNativeError, szErrorMsg, _cbErrorMsg, pcbErrorMsg, 1);

      SET_AND_FREE_OUTPUT_CHAR_NARROW_N (ErrorMsg);
    }

  if (wszSqlState)
    cli_narrow_to_wide (charset, 0, szSqlState, 6, WCHAR_CAST wszSqlState, 6);

  return rc;
}


SQLRETURN SQL_API
SQLExecDirectW (
	SQLHSTMT hstmt,
	SQLWCHAR * wszSqlStr,
	SQLINTEGER cbSqlStr)
{
  SQLRETURN rc;
  size_t len;
  STMT_CHARSET (hstmt);
  DEFINE_INPUT_NARROW (SqlStr);

  MAKE_INPUT_ESCAPED_NARROW (SqlStr, stmt->stmt_connection);

  rc = virtodbc__SQLExecDirect (hstmt, szSqlStr, SQL_NTS);

  FREE_INPUT_NARROW (SqlStr);

  return rc;
}


SQLRETURN SQL_API
SQLForeignKeysW (
	SQLHSTMT hstmt,
	SQLWCHAR * wszPkTableQualifier,
	SQLSMALLINT cbPkTableQualifier,
	SQLWCHAR * wszPkTableOwner,
	SQLSMALLINT cbPkTableOwner,
	SQLWCHAR * wszPkTableName,
	SQLSMALLINT cbPkTableName,
	SQLWCHAR * wszFkTableQualifier,
	SQLSMALLINT cbFkTableQualifier,
	SQLWCHAR * wszFkTableOwner,
	SQLSMALLINT cbFkTableOwner,
	SQLWCHAR * wszFkTableName,
	SQLSMALLINT cbFkTableName)
{
  size_t len;
  SQLRETURN rc;
  STMT_CHARSET (hstmt);
  DEFINE_INPUT_NARROW (PkTableQualifier);
  DEFINE_INPUT_NARROW (PkTableOwner);
  DEFINE_INPUT_NARROW (PkTableName);
  DEFINE_INPUT_NARROW (FkTableQualifier);
  DEFINE_INPUT_NARROW (FkTableOwner);
  DEFINE_INPUT_NARROW (FkTableName);


  MAKE_INPUT_NARROW (PkTableQualifier, stmt->stmt_connection);
  MAKE_INPUT_NARROW (PkTableOwner, stmt->stmt_connection);
  MAKE_INPUT_NARROW (PkTableName, stmt->stmt_connection);
  MAKE_INPUT_NARROW (FkTableQualifier, stmt->stmt_connection);
  MAKE_INPUT_NARROW (FkTableOwner, stmt->stmt_connection);
  MAKE_INPUT_NARROW (FkTableName, stmt->stmt_connection);

  rc = virtodbc__SQLForeignKeys (hstmt, szPkTableQualifier, cbPkTableQualifier, szPkTableOwner, cbPkTableOwner, szPkTableName, cbPkTableName, szFkTableQualifier, cbFkTableQualifier, szFkTableOwner, cbFkTableOwner, szFkTableName, cbFkTableName);

  FREE_INPUT_NARROW (PkTableQualifier);
  FREE_INPUT_NARROW (PkTableOwner);
  FREE_INPUT_NARROW (PkTableName);
  FREE_INPUT_NARROW (FkTableQualifier);
  FREE_INPUT_NARROW (FkTableOwner);
  FREE_INPUT_NARROW (FkTableName);

  return rc;
}


SQLRETURN SQL_API
SQLGetConnectAttrW (SQLHDBC connectionHandle,
    SQLINTEGER Attribute,
    SQLPOINTER ValuePtr,
    SQLINTEGER StringLength,
    SQLINTEGER * StringLengthPtr)
{
  CON_CHARSET (connectionHandle);

  switch (Attribute)
    {
    case SQL_ATTR_CURRENT_CATALOG:
    case SQL_ATTR_TRACEFILE:
    case SQL_ATTR_TRANSLATE_LIB:
    case SQL_CHARSET:
    case SQL_APPLICATION_NAME:
      {
	SQLRETURN rc;
	DEFINE_OUTPUT_NONCHAR_NARROW (ValuePtr, StringLength, StringLengthPtr, con, SQLINTEGER);

	MAKE_OUTPUT_NONCHAR_NARROW (ValuePtr, StringLength, con);

	rc = virtodbc__SQLGetConnectAttr (connectionHandle, Attribute, _ValuePtr, _StringLength, _StringLengthPtr);

	SET_AND_FREE_OUTPUT_NONCHAR_NARROW (ValuePtr, StringLength, StringLengthPtr, con);
	return rc;
      }

    default:
      return virtodbc__SQLGetConnectAttr (connectionHandle, Attribute, ValuePtr, StringLength, StringLengthPtr);
    }
}


SQLRETURN SQL_API
SQLGetConnectOptionW (
	SQLHDBC hdbc,
	SQLUSMALLINT fOption,
	SQLPOINTER pvParam)
{
  CON_CHARSET (hdbc);
  SQLRETURN rc;

  switch (fOption)
    {
    case SQL_ATTR_CURRENT_CATALOG:
    case SQL_ATTR_TRACEFILE:
    case SQL_ATTR_TRANSLATE_LIB:
      {
	SQLINTEGER StrLen = 512, *StrLenPtr = NULL;

	DEFINE_OUTPUT_NONCHAR_NARROW (pvParam, StrLen, StrLenPtr, con, SQLINTEGER);

	MAKE_OUTPUT_NONCHAR_NARROW (pvParam, StrLen, con);

	rc = virtodbc__SQLGetConnectOption (hdbc, fOption, _pvParam, _StrLen, _StrLenPtr);

	SET_AND_FREE_OUTPUT_NONCHAR_NARROW (pvParam, StrLen, StrLenPtr, con);

	return rc;
      }

    default:
      return virtodbc__SQLGetConnectOption (hdbc, fOption, pvParam, 65536, NULL);
    }
}


SQLRETURN SQL_API
SQLGetCursorNameW (
	SQLHSTMT hstmt,
	SQLWCHAR * wszCursor,
	SQLSMALLINT cbCursor,
	SQLSMALLINT * pcbCursor)
{
  SQLRETURN rc;
  STMT_CHARSET (hstmt);
  DEFINE_OUTPUT_CHAR_NARROW (Cursor, stmt->stmt_connection, SQLSMALLINT);

  MAKE_OUTPUT_CHAR_NARROW (Cursor, stmt->stmt_connection);

  rc = virtodbc__SQLGetCursorName (hstmt, szCursor, _cbCursor, _pcbCursor);

  SET_AND_FREE_OUTPUT_CHAR_NARROW (Cursor, stmt->stmt_connection);

  return rc;
}


SQLRETURN SQL_API
SQLGetDescFieldW (SQLHDESC descriptorHandle,
    SQLSMALLINT RecNumber,
    SQLSMALLINT FieldIdentifier,
    SQLPOINTER ValuePtr,
    SQLINTEGER BufferLength,
    SQLINTEGER * StringLengthPtr)
{
  DESC_CHARSET1 (descriptorHandle);

  switch (FieldIdentifier)
    {
    case SQL_DESC_NAME:
    case SQL_DESC_LABEL:
    case SQL_DESC_TABLE_NAME:
    case SQL_DESC_SCHEMA_NAME:
    case SQL_DESC_CATALOG_NAME:
    case SQL_DESC_BASE_COLUMN_NAME:
    case SQL_DESC_BASE_TABLE_NAME:
    case SQL_DESC_LITERAL_PREFIX:
    case SQL_DESC_LITERAL_SUFFIX:
    case SQL_DESC_TYPE_NAME:
    case SQL_DESC_LOCAL_TYPE_NAME:
      {
	SQLRETURN rc;
	DEFINE_OUTPUT_NONCHAR_NARROW (ValuePtr, BufferLength, StringLengthPtr, desc->d_stmt->stmt_connection, SQLINTEGER);

	MAKE_OUTPUT_NONCHAR_NARROW (ValuePtr, BufferLength, desc->d_stmt->stmt_connection);

	rc = virtodbc__SQLGetDescField (descriptorHandle, RecNumber, FieldIdentifier, _ValuePtr, _BufferLength, _StringLengthPtr);

	SET_AND_FREE_OUTPUT_NONCHAR_NARROW (ValuePtr, BufferLength, StringLengthPtr, desc->d_stmt->stmt_connection);

	return rc;
      }

    default:
      return virtodbc__SQLGetDescField (descriptorHandle, RecNumber, FieldIdentifier, ValuePtr, BufferLength, StringLengthPtr);
    }
}


SQLRETURN SQL_API
SQLGetDescRecW (SQLHDESC descriptorHandle,
    SQLSMALLINT RecNumber,
    SQLWCHAR * wszName,
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
  DESC_CHARSET1 (descriptorHandle);
  DEFINE_OUTPUT_CHAR_NARROW (Name, desc->d_stmt->stmt_connection, SQLSMALLINT);

  MAKE_OUTPUT_CHAR_NARROW (Name, desc->d_stmt->stmt_connection);

  rc = virtodbc__SQLGetDescRec (descriptorHandle, RecNumber, szName, _cbName, _pcbName, TypePtr, SubTypePtr, LengthPtr, PrecisionPtr, ScalePtr, NullablePtr);

  SET_AND_FREE_OUTPUT_CHAR_NARROW (Name, desc->d_stmt->stmt_connection);

  return rc;
}


SQLRETURN SQL_API
SQLGetDiagFieldW (SQLSMALLINT nHandleType,
    SQLHANDLE Handle,
    SQLSMALLINT nRecNumber,
    SQLSMALLINT nDiagIdentifier,
    SQLPOINTER pDiagInfoPtr,
    SQLSMALLINT nBufferLength,
    SQLSMALLINT * pnStringLengthPtr)
{
  DESC_CHARSET (Handle, nHandleType);

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

	DEFINE_OUTPUT_NONCHAR_NARROW (pDiagInfoPtr, nBufferLength, pnStringLengthPtr, conn, SQLSMALLINT);

	MAKE_OUTPUT_NONCHAR_NARROW (pDiagInfoPtr, nBufferLength, conn);

	rc = virtodbc__SQLGetDiagField (nHandleType, Handle, nRecNumber, nDiagIdentifier, _pDiagInfoPtr, _nBufferLength, _pnStringLengthPtr);

	SET_AND_FREE_OUTPUT_NONCHAR_NARROW (pDiagInfoPtr, nBufferLength, pnStringLengthPtr, conn);

	return rc;
      }

    default:
      return virtodbc__SQLGetDiagField (nHandleType, Handle, nRecNumber,
	  nDiagIdentifier, pDiagInfoPtr, nBufferLength, pnStringLengthPtr);
    }
}


SQLRETURN SQL_API
SQLGetDiagRecW (SQLSMALLINT HandleType,
    SQLHANDLE Handle,
    SQLSMALLINT RecNumber,
    SQLWCHAR * wszSqlstate,
    SQLINTEGER * NativeErrorPtr,
    SQLWCHAR * wszMessageText,
    SQLSMALLINT cbMessageText,
    SQLSMALLINT * pcbMessageText)
{
  DESC_CHARSET (Handle, HandleType);
  SQLCHAR szSqlState[6];
  SQLRETURN rc;
  cli_connection_t *conn = (HandleType == SQL_HANDLE_DBC ? con :
      (HandleType == SQL_HANDLE_STMT ? stmt->stmt_connection :
	  (HandleType == SQL_HANDLE_DESC ? desc->d_stmt->stmt_connection : NULL)));

  if (conn)
    {
      DEFINE_OUTPUT_CHAR_NARROW (MessageText, conn, SQLSMALLINT);

      MAKE_OUTPUT_CHAR_NARROW (MessageText, conn);

      rc = virtodbc__SQLGetDiagRec (HandleType, Handle, RecNumber, szSqlState, NativeErrorPtr, szMessageText, _cbMessageText, _pcbMessageText);

      SET_AND_FREE_OUTPUT_CHAR_NARROW (MessageText, conn);

      /*if (pcbMessageText) - explicit bug, _cbMessageText is a temp buffer length
       *pcbMessageText = ((SQLSMALLINT) _cbMessageText);*/
    }
  else
    {
      DEFINE_OUTPUT_CHAR_NARROW_N (MessageText, SQLSMALLINT);

      MAKE_OUTPUT_CHAR_NARROW_N (MessageText);

      rc = virtodbc__SQLGetDiagRec (HandleType, Handle, RecNumber, szSqlState, NativeErrorPtr, szMessageText, _cbMessageText, _pcbMessageText);

      SET_AND_FREE_OUTPUT_CHAR_NARROW_N (MessageText);
    }

  if (wszSqlstate)
    cli_narrow_to_wide (charset, 0, szSqlState, 6, WCHAR_CAST wszSqlstate, 6);

  return rc;
}


SQLRETURN SQL_API
SQLGetInfoW (
	SQLHDBC hdbc,
	SQLUSMALLINT fInfoType,
	SQLPOINTER rgbInfoValue,
	SQLSMALLINT cbInfoValueMax,
	SQLSMALLINT * pcbInfoValue)
{
  CON_CHARSET (hdbc);

  switch (fInfoType)
    {
    case SQL_DATABASE_NAME:
    case SQL_DATA_SOURCE_NAME:
    case SQL_DRIVER_NAME:
    case SQL_DRIVER_VER:
    case SQL_DBMS_NAME:
    case SQL_DBMS_VER:
    case SQL_SERVER_NAME:
    case SQL_ODBC_VER:
    case SQL_ROW_UPDATES:
    case SQL_SEARCH_PATTERN_ESCAPE:
    case SQL_ACCESSIBLE_TABLES:
    case SQL_ACCESSIBLE_PROCEDURES:
    case SQL_PROCEDURES:
    case SQL_DATA_SOURCE_READ_ONLY:
    case SQL_EXPRESSIONS_IN_ORDERBY:
    case SQL_IDENTIFIER_QUOTE_CHAR:
    case SQL_MULT_RESULT_SETS:
    case SQL_MULTIPLE_ACTIVE_TXN:
    case SQL_OUTER_JOINS:
    case SQL_OWNER_TERM:
    case SQL_PROCEDURE_TERM:
    case SQL_QUALIFIER_NAME_SEPARATOR:
    case SQL_QUALIFIER_TERM:
    case SQL_TABLE_TERM:
    case SQL_USER_NAME:
    case SQL_ODBC_SQL_OPT_IEF:
    case SQL_DRIVER_ODBC_VER:
    case SQL_COLUMN_ALIAS:
    case SQL_KEYWORDS:
    case SQL_ORDER_BY_COLUMNS_IN_SELECT:
    case SQL_SPECIAL_CHARACTERS:
    case SQL_MAX_ROW_SIZE_INCLUDES_LONG:
    case SQL_NEED_LONG_DATA_LEN:
    case SQL_LIKE_ESCAPE_CLAUSE:
    case SQL_CATALOG_NAME:
    case SQL_COLLATION_SEQ:
    case SQL_DESCRIBE_PARAMETER:
    case SQL_XOPEN_CLI_YEAR:
      {
	SQLRETURN rc;
	DEFINE_OUTPUT_NONCHAR_NARROW (rgbInfoValue, cbInfoValueMax, pcbInfoValue, con, SQLSMALLINT);

	MAKE_OUTPUT_NONCHAR_NARROW (rgbInfoValue, cbInfoValueMax, con);

	rc = virtodbc__SQLGetInfo (hdbc, fInfoType, _rgbInfoValue, _cbInfoValueMax, _pcbInfoValue);

	SET_AND_FREE_OUTPUT_NONCHAR_NARROW (rgbInfoValue, cbInfoValueMax, pcbInfoValue, con);

	return rc;
      }

    default:
      return virtodbc__SQLGetInfo (hdbc, fInfoType, rgbInfoValue, cbInfoValueMax, pcbInfoValue);
    }
}


SQLRETURN SQL_API
SQLGetStmtAttrW (SQLHSTMT statementHandle,
    SQLINTEGER Attribute,
    SQLPOINTER ValuePtr,
    SQLINTEGER BufferLength,
    SQLINTEGER * StringLengthPtr)
{
  return virtodbc__SQLGetStmtAttr (statementHandle, Attribute, ValuePtr, BufferLength, StringLengthPtr);
}


SQLRETURN SQL_API
SQLNativeSqlW (
	SQLHDBC hdbc,
	SQLWCHAR * wszSqlStrIn,
	SQLINTEGER cbSqlStrIn,
	SQLWCHAR * wszSqlStr,
	SQLINTEGER cbSqlStr,
	SQLINTEGER * pcbSqlStr)
{
  CON_CHARSET (hdbc);
  SQLRETURN rc;
  size_t len;
  DEFINE_INPUT_NARROW (SqlStrIn);
  DEFINE_OUTPUT_CHAR_NARROW (SqlStr, con, SQLINTEGER);

  MAKE_INPUT_NARROW (SqlStrIn, con);
  MAKE_OUTPUT_CHAR_NARROW (SqlStr, con);

  rc = virtodbc__SQLNativeSql (hdbc, szSqlStrIn, SQL_NTS, szSqlStr, _cbSqlStr, _pcbSqlStr);

  SET_AND_FREE_OUTPUT_CHAR_NARROW (SqlStr, con);
  FREE_INPUT_NARROW (SqlStrIn);

  return rc;
}


SQLRETURN SQL_API
SQLPrepareW (
	SQLHSTMT hstmt,
	SQLWCHAR * wszSqlStr,
	SQLINTEGER cbSqlStr)
{
  size_t len;
  SQLRETURN rc;
  STMT_CHARSET (hstmt);
  DEFINE_INPUT_NARROW (SqlStr);

  MAKE_INPUT_ESCAPED_NARROW (SqlStr, stmt->stmt_connection);

  rc = virtodbc__SQLPrepare (hstmt, szSqlStr, SQL_NTS);

  FREE_INPUT_NARROW (SqlStr);

  return rc;
}


SQLRETURN SQL_API
SQLPrimaryKeysW (
	SQLHSTMT hstmt,
	SQLWCHAR * wszTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLWCHAR * wszTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLWCHAR * wszTableName,
	SQLSMALLINT cbTableName)
{
  STMT_CHARSET (hstmt);
  SQLRETURN rc;
  size_t len;

  DEFINE_INPUT_NARROW (TableQualifier);
  DEFINE_INPUT_NARROW (TableOwner);
  DEFINE_INPUT_NARROW (TableName);

  MAKE_INPUT_NARROW (TableQualifier, stmt->stmt_connection);
  MAKE_INPUT_NARROW (TableOwner, stmt->stmt_connection);
  MAKE_INPUT_NARROW (TableName, stmt->stmt_connection);

  rc = virtodbc__SQLPrimaryKeys (hstmt, szTableQualifier, cbTableQualifier, szTableOwner, cbTableOwner, szTableName, cbTableName);

  FREE_INPUT_NARROW (TableQualifier);
  FREE_INPUT_NARROW (TableOwner);
  FREE_INPUT_NARROW (TableName);

  return rc;
}


SQLRETURN SQL_API
SQLProcedureColumnsW (
	SQLHSTMT hstmt,
	SQLWCHAR * wszProcQualifier,
	SQLSMALLINT cbProcQualifier,
	SQLWCHAR * wszProcOwner,
	SQLSMALLINT cbProcOwner,
	SQLWCHAR * wszProcName,
	SQLSMALLINT cbProcName,
	SQLWCHAR * wszColumnName,
	SQLSMALLINT cbColumnName)
{
  STMT_CHARSET (hstmt);
  SQLRETURN rc;
  size_t len;

  DEFINE_INPUT_NARROW (ProcQualifier);
  DEFINE_INPUT_NARROW (ProcOwner);
  DEFINE_INPUT_NARROW (ProcName);
  DEFINE_INPUT_NARROW (ColumnName);

  MAKE_INPUT_NARROW (ProcQualifier, stmt->stmt_connection);
  MAKE_INPUT_NARROW (ProcOwner, stmt->stmt_connection);
  MAKE_INPUT_NARROW (ProcName, stmt->stmt_connection);
  MAKE_INPUT_NARROW (ColumnName, stmt->stmt_connection);

  rc = virtodbc__SQLProcedureColumns (hstmt, szProcQualifier, cbProcQualifier, szProcOwner, cbProcOwner, szProcName, cbProcName, szColumnName, cbColumnName);

  FREE_INPUT_NARROW (ProcQualifier);
  FREE_INPUT_NARROW (ProcOwner);
  FREE_INPUT_NARROW (ProcName);
  FREE_INPUT_NARROW (ColumnName);

  return rc;
}


SQLRETURN SQL_API
SQLProceduresW (
	SQLHSTMT hstmt,
	SQLWCHAR * wszProcQualifier,
	SQLSMALLINT cbProcQualifier,
	SQLWCHAR * wszProcOwner,
	SQLSMALLINT cbProcOwner,
	SQLWCHAR * wszProcName,
	SQLSMALLINT cbProcName)
{
  STMT_CHARSET (hstmt);
  SQLRETURN rc;
  size_t len;

  DEFINE_INPUT_NARROW (ProcQualifier);
  DEFINE_INPUT_NARROW (ProcOwner);
  DEFINE_INPUT_NARROW (ProcName);

  MAKE_INPUT_NARROW (ProcQualifier, stmt->stmt_connection);
  MAKE_INPUT_NARROW (ProcOwner, stmt->stmt_connection);
  MAKE_INPUT_NARROW (ProcName, stmt->stmt_connection);

  rc = virtodbc__SQLProcedures (hstmt, szProcQualifier, cbProcQualifier, szProcOwner, cbProcOwner, szProcName, cbProcName);

  FREE_INPUT_NARROW (ProcQualifier);
  FREE_INPUT_NARROW (ProcOwner);
  FREE_INPUT_NARROW (ProcName);

  return rc;
}


SQLRETURN SQL_API
SQLSetConnectAttrW (SQLHDBC connectionHandle,
    SQLINTEGER Attribute,
    SQLPOINTER ValuePtr,
    SQLINTEGER StringLength)
{
  CON_CHARSET (connectionHandle);

  switch (Attribute)
    {
    case SQL_CURRENT_QUALIFIER:
    case SQL_CHARSET:
    case SQL_APPLICATION_NAME:
      {
	SQLRETURN rc;
	DEFINE_INPUT_NONCHAR_NARROW (ValuePtr, StringLength);

	MAKE_INPUT_NONCHAR_NARROW (ValuePtr, StringLength, con);

	rc = virtodbc__SQLSetConnectAttr (connectionHandle, Attribute, _ValuePtr, _StringLength);

	FREE_INPUT_NONCHAR_NARROW (ValuePtr, StringLength);

	return rc;
      }

    default:
      return virtodbc__SQLSetConnectAttr (connectionHandle, Attribute, ValuePtr, StringLength);
    }
}


SQLRETURN SQL_API
SQLSetConnectOptionW (
      SQLHDBC hdbc,
      SQLUSMALLINT fOption,
      SQLULEN vParam)
{
  CON_CHARSET (hdbc);
  switch (fOption)
    {
    case SQL_CURRENT_QUALIFIER:
      {
	SQLRETURN rc;
	int StringLength = SQL_NTS;
	DEFINE_INPUT_NONCHAR_NARROW (vParam, StringLength);

	MAKE_INPUT_NONCHAR_NARROW (vParam, StringLength, con);

	rc = virtodbc__SQLSetConnectOption (hdbc, fOption, (SQLLEN) _vParam);

	FREE_INPUT_NONCHAR_NARROW (vParam, StringLength);

	return rc;
      }

    default:
      return virtodbc__SQLSetConnectOption (hdbc, fOption, vParam);
    }
}


SQLRETURN SQL_API
SQLSetCursorNameW (
      SQLHSTMT hstmt,
      SQLWCHAR * wszCursor,
      SQLSMALLINT cbCursor)
{
  STMT_CHARSET (hstmt);
  SQLRETURN rc;
  size_t len;
  DEFINE_INPUT_NARROW (Cursor);

  MAKE_INPUT_NARROW (Cursor, stmt->stmt_connection);

  rc = virtodbc__SQLSetCursorName (hstmt, szCursor, cbCursor);

  FREE_INPUT_NARROW (Cursor);

  return rc;
}


SQLRETURN SQL_API
SQLSetDescFieldW (SQLHDESC descriptorHandle,
    SQLSMALLINT RecNumber,
    SQLSMALLINT FieldIdentifier,
    SQLPOINTER ValuePtr,
    SQLINTEGER BufferLength)
{
  DESC_CHARSET1 (descriptorHandle);

  switch (FieldIdentifier)
    {
    case SQL_DESC_LABEL:
    case SQL_DESC_LITERAL_PREFIX:
    case SQL_DESC_LITERAL_SUFFIX:
    case SQL_DESC_LOCAL_TYPE_NAME:
    case SQL_DESC_NAME:
    case SQL_DESC_BASE_COLUMN_NAME:
    case SQL_DESC_BASE_TABLE_NAME:
    case SQL_DESC_CONCISE_TYPE:
    case SQL_DESC_TYPE_NAME:
      {
	SQLRETURN rc;
	DEFINE_INPUT_NONCHAR_NARROW (ValuePtr, BufferLength);

	MAKE_INPUT_NONCHAR_NARROW (ValuePtr, BufferLength, desc->d_stmt->stmt_connection);

	rc = virtodbc__SQLSetDescField (descriptorHandle, RecNumber, FieldIdentifier, _ValuePtr, _BufferLength);

	FREE_INPUT_NONCHAR_NARROW (ValuePtr, BufferLength);

	return rc;
      }

    default:
      return virtodbc__SQLSetDescField (descriptorHandle, RecNumber, FieldIdentifier, ValuePtr, BufferLength);
    }
}


SQLRETURN SQL_API
SQLSetStmtAttrW (SQLHSTMT statementHandle,
    SQLINTEGER Attribute,
    SQLPOINTER ValuePtr,
    SQLINTEGER StringLength)
{
  return virtodbc__SQLSetStmtAttr (statementHandle, Attribute, ValuePtr, StringLength);
}


SQLRETURN SQL_API
SQLSpecialColumnsW (
	SQLHSTMT hstmt,
	SQLUSMALLINT fColType,
	SQLWCHAR * wszTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLWCHAR * wszTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLWCHAR * wszTableName,
	SQLSMALLINT cbTableName,
	SQLUSMALLINT fScope,
	SQLUSMALLINT fNullable)
{
  SQLRETURN rc;
  size_t len;
  STMT_CHARSET (hstmt);
  DEFINE_INPUT_NARROW (TableQualifier);
  DEFINE_INPUT_NARROW (TableOwner);
  DEFINE_INPUT_NARROW (TableName);

  MAKE_INPUT_NARROW (TableQualifier, stmt->stmt_connection);
  MAKE_INPUT_NARROW (TableOwner, stmt->stmt_connection);
  MAKE_INPUT_NARROW (TableName, stmt->stmt_connection);

  rc = virtodbc__SQLSpecialColumns (hstmt, fColType, szTableQualifier, cbTableQualifier, szTableOwner, cbTableOwner, szTableName, cbTableName, fScope, fNullable);

  FREE_INPUT_NARROW (TableQualifier);
  FREE_INPUT_NARROW (TableOwner);
  FREE_INPUT_NARROW (TableName);

  return rc;
}


SQLRETURN SQL_API
SQLStatisticsW (
	SQLHSTMT hstmt,
	SQLWCHAR * wszTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLWCHAR * wszTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLWCHAR * wszTableName,
	SQLSMALLINT cbTableName,
	SQLUSMALLINT fUnique,
	SQLUSMALLINT fAccuracy)
{
  SQLRETURN rc;
  size_t len;
  STMT_CHARSET (hstmt);
  DEFINE_INPUT_NARROW (TableQualifier);
  DEFINE_INPUT_NARROW (TableOwner);
  DEFINE_INPUT_NARROW (TableName);

  MAKE_INPUT_NARROW (TableQualifier, stmt->stmt_connection);
  MAKE_INPUT_NARROW (TableOwner, stmt->stmt_connection);
  MAKE_INPUT_NARROW (TableName, stmt->stmt_connection);

  rc = virtodbc__SQLStatistics (hstmt, szTableQualifier, cbTableQualifier, szTableOwner, cbTableOwner, szTableName, cbTableName, fUnique, fAccuracy);

  FREE_INPUT_NARROW (TableQualifier);
  FREE_INPUT_NARROW (TableOwner);
  FREE_INPUT_NARROW (TableName);

  return rc;
}


SQLRETURN SQL_API
SQLTablePrivilegesW (
	SQLHSTMT hstmt,
	SQLWCHAR * wszTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLWCHAR * wszTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLWCHAR * wszTableName,
	SQLSMALLINT cbTableName)
{
  SQLRETURN rc;
  size_t len;
  STMT_CHARSET (hstmt);
  DEFINE_INPUT_NARROW (TableQualifier);
  DEFINE_INPUT_NARROW (TableOwner);
  DEFINE_INPUT_NARROW (TableName);

  MAKE_INPUT_NARROW (TableQualifier, stmt->stmt_connection);
  MAKE_INPUT_NARROW (TableOwner, stmt->stmt_connection);
  MAKE_INPUT_NARROW (TableName, stmt->stmt_connection);

  rc = virtodbc__SQLTablePrivileges (hstmt, szTableQualifier, cbTableQualifier, szTableOwner, cbTableOwner, szTableName, cbTableName);

  FREE_INPUT_NARROW (TableQualifier);
  FREE_INPUT_NARROW (TableOwner);
  FREE_INPUT_NARROW (TableName);

  return rc;
}


SQLRETURN SQL_API
SQLTablesW (
	SQLHSTMT hstmt,
	SQLWCHAR * wszTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLWCHAR * wszTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLWCHAR * wszTableName,
	SQLSMALLINT cbTableName,
	SQLWCHAR * wszTableType,
	SQLSMALLINT cbTableType)
{
  SQLRETURN rc;
  size_t len;
  STMT_CHARSET (hstmt);
  DEFINE_INPUT_NARROW (TableQualifier);
  DEFINE_INPUT_NARROW (TableOwner);
  DEFINE_INPUT_NARROW (TableName);
  DEFINE_INPUT_NARROW (TableType);

  MAKE_INPUT_NARROW (TableQualifier, stmt->stmt_connection);
  MAKE_INPUT_NARROW (TableOwner, stmt->stmt_connection);
  MAKE_INPUT_NARROW (TableName, stmt->stmt_connection);
  MAKE_INPUT_NARROW (TableType, stmt->stmt_connection);

  rc = virtodbc__SQLTables (hstmt, szTableQualifier, cbTableQualifier, szTableOwner, cbTableOwner, szTableName, cbTableName, szTableType, cbTableType);

  FREE_INPUT_NARROW (TableQualifier);
  FREE_INPUT_NARROW (TableOwner);
  FREE_INPUT_NARROW (TableName);
  FREE_INPUT_NARROW (TableType);

  return rc;
}


SQLRETURN SQL_API
SQLGetTypeInfoW (
	SQLHSTMT hstmt,
	SQLSMALLINT fSqlType)
{
  return virtodbc__SQLGetTypeInfo (hstmt, fSqlType);
}

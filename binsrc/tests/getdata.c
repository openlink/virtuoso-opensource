/*
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

#if !defined (__APPLE__)
#include <wchar.h>
#endif
#include "odbcinc.h"
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <stdlib.h>
int is_mssql = 0;

char *dsn = "1111";
char *uid = "dba";
char *pwd = "dba";

HENV henv;
HDBC hdbc;


void
err_printf (const char *format, ...)
{
  va_list args;

  va_start (args, format);
  vfprintf (stderr, format, args);
  va_end (args);
  va_start (args, format);
  vfprintf (stdout, format, args);
  va_end (args);
}


void
error (SQLSMALLINT handle_type, SQLHANDLE handle)
{
  SQLCHAR sql_state[6], error_msg[SQL_MAX_MESSAGE_LENGTH];
  SQLSMALLINT i, error_msg_len;
  SQLINTEGER native_error;

  i = 1;
  while (SQL_NO_DATA != SQLGetDiagRec(handle_type, handle, i,
				      sql_state, &native_error,
				      error_msg, sizeof error_msg, &error_msg_len))
    {
      printf ("SQLSTATE:        %s\n", sql_state);
      printf ("Diagnostic Msg:  %s\n", error_msg);
      i++;
    }
}


void
create_table (char* type)
{
  HSTMT hstmt;
  SQLRETURN rc;
  char statement[1024];

  rc = SQLAllocHandle (SQL_HANDLE_STMT, (SQLHANDLE) hdbc, (SQLHANDLE *) &hstmt);
  if (rc != SQL_SUCCESS)
    {
    	err_printf ("SQLAllocHandle() failed.\n");
	exit (1);
    }

  rc = SQLExecDirect (hstmt, "drop table tab", SQL_NTS);
  if (rc != SQL_SUCCESS)
    {
    	printf ("drop table failed.\n");
        error (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
    }

  sprintf (statement, "create table tab (id int primary key, data %s)", type);
  rc = SQLExecDirect (hstmt, statement, SQL_NTS);
  if (rc != SQL_SUCCESS)
    {
    	err_printf ("create table failed.\n");
        error (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
	exit (1);
    }

  SQLFreeHandle (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
}

void
insert_row (char* type, long id)
{
  HSTMT hstmt;
  SQLRETURN rc;
  int i, n;
  SQLLEN size;
  char* data;
  wchar_t* wide_data;

  n = 1 << id;
  if (strstr (type, "NVARCHAR") != NULL || strstr (type, "NTEXT") != NULL)
    {
      size = n * sizeof (wchar_t);
      data = malloc (size);
      wide_data = (wchar_t*) data;
    }
  else
    {
      size = n;
      data = malloc (size);
      wide_data = NULL;
    }
  if (data == NULL)
    {
      err_printf ("SQLAllocHandle() failed.\n");
      exit (1);
    }
  for (i = 0; i < n; i++)
    {
      if (wide_data == NULL)
	data[i] = (32 + i % (127 - 32));
      else
	wide_data[i] = (32 + i % (127 - 32));
   }

  rc = SQLAllocHandle (SQL_HANDLE_STMT, (SQLHANDLE) hdbc, (SQLHANDLE *) &hstmt);
  if (rc != SQL_SUCCESS)
    {
      err_printf ("SQLAllocHandle() failed.\n");
      exit (1);
    }

  rc = SQLBindParameter (hstmt, 1, SQL_PARAM_INPUT, SQL_C_LONG, SQL_INTEGER, 0, 0, &id, 0, NULL);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      err_printf ("SQLBindParameter() failed.\n");
      exit (1);
    }

  if (strstr (type, "NTEXT") != NULL || strstr (type, "LONG NVARCHAR") != NULL)
    rc = SQLBindParameter (hstmt, 2, SQL_PARAM_INPUT, SQL_C_WCHAR, SQL_WLONGVARCHAR, n, 0, data, size, &size);
  else if (strstr (type, "NVARCHAR") != NULL)
    rc = SQLBindParameter (hstmt, 2, SQL_PARAM_INPUT, SQL_C_WCHAR, SQL_WCHAR, n, 0, data, size, &size);
  else if (strstr (type, "TEXT") != NULL || strstr (type, "LONG VARCHAR") != NULL)
    rc = SQLBindParameter (hstmt, 2, SQL_PARAM_INPUT, SQL_C_CHAR, SQL_LONGVARCHAR, n, 0, data, size, &size);
  else if (strstr (type, "VARCHAR") != NULL)
    rc = SQLBindParameter (hstmt, 2, SQL_PARAM_INPUT, SQL_C_CHAR, SQL_CHAR, n, 0, data, size, &size);
  else if (strstr (type, "IMAGE") != NULL || strstr (type, "LONG VARBINARY") != NULL)
    rc = SQLBindParameter (hstmt, 2, SQL_PARAM_INPUT, SQL_C_BINARY, SQL_LONGVARBINARY, n, 0, data, size, &size);
  else
    rc = SQLBindParameter (hstmt, 2, SQL_PARAM_INPUT, SQL_C_BINARY, SQL_BINARY, n, 0, data, size, &size);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      err_printf ("SQLBindParameter() failed.\n");
      error (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
      exit (1);
    }

  rc = SQLExecDirect (hstmt, "insert into tab values (?, ?)", SQL_NTS);
  if (rc != SQL_SUCCESS)
    {
      err_printf ("insert failed.\n");
      error (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
      exit (1);
    }

  SQLFreeHandle (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
  free (data);
}

void
test (char* type, int c_type)
{
  int i, n;
  HSTMT hstmt;
  SQLRETURN rc;

  printf ("=====================================================\n");
  printf ("%s -> %s\n", type,
	  c_type == SQL_C_BINARY ? "SQL_C_BINARY" :
	  c_type == SQL_C_CHAR ? "SQL_C_CHAR" :
	  c_type == SQL_C_WCHAR ? "SQL_C_WCHAR" : "???");

  if (strstr (type, "LONG") != NULL || strstr (type, "IMAGE") != NULL || strstr (type, "TEXT") != NULL)
    n = 16;
  else
    n = 12;

  create_table (type);
  for (i = 0; i < n; i++)
    insert_row (type, i);

  rc = SQLAllocHandle (SQL_HANDLE_STMT, (SQLHANDLE) hdbc, (SQLHANDLE *) &hstmt);
  if (rc != SQL_SUCCESS)
    {
    	err_printf ("SQLAllocHandle() failed.\n");
	return;
    }

  rc = SQLExecDirect (hstmt, "select id, data from tab", SQL_NTS);
  if (rc != SQL_SUCCESS)
    {
    	err_printf ("select failed.\n");
        error (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
	exit (1);
    }

  for (;;)
    {
      char buffer[1024];
      long id;
      SQLLEN offset, full_length, length;

      rc = SQLFetch (hstmt);
      if (rc != SQL_SUCCESS)
	{
	  if (rc == SQL_NO_DATA)
	    break;
	  err_printf ("SQLFetch() failed.\n");
	  error (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
	  exit (1);
	}

      rc = SQLGetData (hstmt, 1, SQL_C_LONG, &id, sizeof id,  &length);
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  err_printf ("SQLGetData failed.\n");
	  error (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
	  exit (1);
	}

      printf ("--- id: %ld, size: %ld\n", id, 1L << id);

      if (SQL_C_WCHAR == c_type)
	full_length = (1 << id) * sizeof (wchar_t);
      else
	full_length = (1 << id);

      offset = 0;
      for (;;)
	{
	  int size_in_buffer;

	  rc = SQLGetData (hstmt, 2, c_type, buffer, sizeof buffer, (void*) &length);
	  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	    {
	      if (rc == SQL_NO_DATA)
		break;
	      err_printf ("SQLGetData failed.\n");
	      error (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
	      exit (1);
	    }

	  if (offset + length != full_length)
	    {
	      err_printf ("offset: %ld\n", (long) offset);
	      err_printf ("length: %ld (should be %ld)\n", (long) length, (long) (full_length - offset));
	      err_printf ("***FAILED: SQLGetData() returned wrong length.\n");
	      exit (1);
	    }

	  if (SQL_C_WCHAR == c_type)
	    size_in_buffer = sizeof buffer - sizeof (wchar_t);
	  else if (SQL_C_CHAR == c_type)
	    size_in_buffer = sizeof buffer - sizeof (char);
	  else
	    size_in_buffer = sizeof buffer;
	  if (size_in_buffer > length)
	    size_in_buffer = length;

	  if ((size_in_buffer < length) != (rc == SQL_SUCCESS_WITH_INFO))
	    {
	      err_printf ("offset: %ld\n", (long) offset);
	      err_printf ("length: %ld\n", (long) length);
	      err_printf ("rc: %s (should be %s)\n",
		rc != SQL_SUCCESS ? "SQL_SUCCESS_WITH_INFO" : "SQL_SUCCESS",
		size_in_buffer < length ? "SQL_SUCCESS_WITH_INFO" : "SQL_SUCCESS");
	      err_printf ("***FAILED: SQLGetData() returned wrong return code.\n");
	      exit (1);
	    }

	  n = SQL_C_WCHAR == c_type ? size_in_buffer / sizeof (wchar_t) : size_in_buffer;
	  for (i = 0; i < n; i++)
	    {
	      int index = SQL_C_WCHAR == c_type ? offset / sizeof (wchar_t) + i : offset + i;
	      int exp_c = 32 + index % (127 - 32);
	      int act_c = SQL_C_WCHAR == c_type ? ((wchar_t*)buffer)[i] : buffer[i];
	      if (act_c != exp_c)
		{
		  err_printf ("buffer index: %d, data index: %d, data: %d ", i, index, act_c);
		  if (index < (1 << id))
		    err_printf ("(should be %d)\n", exp_c);
		  else
		    err_printf ("(should be no data)\n");
		  err_printf ("***FAILED: SQLGetData() returned wrong data.\n");
		  exit (1);
		}
	    }

	  offset += size_in_buffer;
	}
    }

  SQLFreeHandle (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
  err_printf ("PASSED: %s -> %s\n", type,
	  c_type == SQL_C_BINARY ? "SQL_C_BINARY" :
	  c_type == SQL_C_CHAR ? "SQL_C_CHAR" :
	  c_type == SQL_C_WCHAR ? "SQL_C_WCHAR" : "???");

}


static void
get_ti_type_name (HDBC hdbc, SQLSMALLINT data_type, char *buf, int buf_len)
{
  HSTMT ti_hstmt;
  RETCODE rc;

  rc = SQLAllocHandle (SQL_HANDLE_STMT, (SQLHANDLE) hdbc, (SQLHANDLE *) &ti_hstmt);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      err_printf ("SQLAllocHandle() failed.\n");
      exit (-1);
    }
  rc = SQLGetTypeInfo (ti_hstmt, data_type);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      err_printf ("SQLGetTypeInfo() failed.\n");
      exit (-1);
    }
  rc = SQLFetch (ti_hstmt);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      err_printf ("SQLFetch() failed.\n");
      exit (-1);
    }
  rc = SQLGetData (ti_hstmt, 1, SQL_C_CHAR,
      buf, buf_len, NULL);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      err_printf ("SQLGetData() failed.\n");
      exit (-1);
    }
  rc = SQLFreeStmt (ti_hstmt, SQL_CLOSE);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      err_printf ("SQLFreeStmt() failed.\n");
      exit (-1);
    }
  rc = SQLFreeHandle (SQL_HANDLE_STMT, (SQLHANDLE) ti_hstmt);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      err_printf ("SQLFreeHandle() failed.\n");
      exit (-1);
    }
  printf ("SQLGetTypeInfo for %d returned %.200s\n", data_type, buf);
}


static void
test_bug_7628 (HDBC hdbc)
{
  RETCODE rc;
  SQLCHAR qual[100];
  rc = SQLGetConnectOption (hdbc, SQL_CURRENT_QUALIFIER, qual);
}


int
main (int ac, char* av[])
{
  SQLRETURN rc;
  char ti_buffer[200];
  char long_varchar_buf[200], long_nvarchar_buf[200];

  if (ac < 3)
    {
      err_printf ("***FAILED: usage : %s dsn uid pwd\n", av[0]);
      return (-1);
    }
  dsn = av[1];
  uid = av[2];
  pwd = av[3];
  rc = SQLAllocHandle (SQL_HANDLE_ENV, SQL_NULL_HANDLE, (SQLHANDLE *) &henv);
  if (rc != SQL_SUCCESS)
    {
      err_printf ("SQLAllocHandle() failed.\n");
      return 1;
    }

  rc = SQLSetEnvAttr (henv, SQL_ATTR_ODBC_VERSION, (SQLPOINTER) SQL_OV_ODBC3, SQL_IS_INTEGER);
  if (rc != SQL_SUCCESS)
    {
      err_printf ("SQLSetEnvAttr() failed.\n");
      return 1;
    }

  rc = SQLAllocHandle (SQL_HANDLE_DBC, (SQLHANDLE) henv, (SQLHANDLE *) &hdbc);
  if (rc != SQL_SUCCESS)
    {
      err_printf ("SQLAllocHandle() failed.\n");
      return 1;
    }

  rc = SQLConnect (hdbc, dsn, SQL_NTS, uid, SQL_NTS, pwd, SQL_NTS);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      err_printf ("SQLDriverConnect() failed.\n");
      error (SQL_HANDLE_DBC, (SQLHANDLE) hdbc);
      return 1;
    }

  test_bug_7628 (hdbc);

  test ("VARBINARY(4000)", SQL_C_BINARY);
  get_ti_type_name (hdbc, SQL_LONGVARBINARY, ti_buffer, sizeof (ti_buffer));
  test (ti_buffer, SQL_C_BINARY);

  test ("VARCHAR(4000)", SQL_C_CHAR);
  test ("NVARCHAR(4000)", SQL_C_CHAR);

  get_ti_type_name (hdbc, SQL_LONGVARCHAR, ti_buffer, sizeof (ti_buffer));
  strcpy (long_varchar_buf, ti_buffer);
  test (long_varchar_buf, SQL_C_CHAR);
  get_ti_type_name (hdbc, SQL_WLONGVARCHAR, ti_buffer, sizeof (ti_buffer));
  strcpy (long_nvarchar_buf, ti_buffer);
  test (long_nvarchar_buf, SQL_C_CHAR);

  test ("VARCHAR(4000)", SQL_C_WCHAR);
  test ("NVARCHAR(4000)", SQL_C_WCHAR);
  test (long_varchar_buf, SQL_C_WCHAR);
  test (long_nvarchar_buf, SQL_C_WCHAR);

  return 0;
}

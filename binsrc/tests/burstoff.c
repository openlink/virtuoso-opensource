/*
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

#if !defined (__APPLE__)
#include <wchar.h>
#endif
#include "odbcinc.h"
#include <stdio.h>
#include <string.h>
#include <stdarg.h>

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
  while (SQL_NO_DATA != SQLGetDiagRec (handle_type, handle, i,
	  sql_state, &native_error,
	  error_msg, sizeof error_msg, &error_msg_len))
    {
      printf ("SQLSTATE:        %s\n", sql_state);
      printf ("Diagnostic Msg:  %s\n", error_msg);
      i++;
    }
}


void
create_proc ()
{
  HSTMT hstmt;
  SQLRETURN rc;

  rc = SQLAllocHandle (SQL_HANDLE_STMT, (SQLHANDLE) hdbc,
      (SQLHANDLE *) & hstmt);
  if (rc != SQL_SUCCESS)
    {
      err_printf ("SQLAllocHandle() failed.\n");
      exit (1);
    }

  rc = SQLExecDirect (hstmt, "create procedure burstoff_proc () { ; }",
      SQL_NTS);
  if (rc != SQL_SUCCESS)
    {
      printf ("drop table failed.\n");
      error (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
    }

  rc = SQLExecDirect (hstmt,
      "create procedure burstoff_rs_proc (in ntimes integer := 3)\n"
      "{\n"
      "  declare ret varchar;\n"
      "  result_names (ret);\n"
      "  declare i,x integer;\n"
      "  i := 0;\n"
      "  while (i < ntimes)\n"
      "    {\n"
      "      result (repeat (' ', 8000));\n"
      "      select count (*) into x from DB.DBA.SYS_COLS k1, DB.DBA.SYS_KEYS k2, DB.DBA.SYS_USERS k3;\n"
      "      i := i + 1;\n" "    }\n" "}", SQL_NTS);
  if (rc != SQL_SUCCESS)
    {
      printf ("drop table failed.\n");
      error (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
    }

  SQLFreeHandle (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
}


void
call_proc (int n_times)
{
  HSTMT hstmt;
  SQLRETURN rc;
  int i;


  rc = SQLAllocHandle (SQL_HANDLE_STMT, (SQLHANDLE) hdbc,
      (SQLHANDLE *) & hstmt);
  if (rc != SQL_SUCCESS)
    {
      err_printf ("SQLAllocHandle() failed.\n");
      exit (1);
    }

  rc = SQLPrepare (hstmt, "burstoff_proc()", SQL_NTS);
  if (rc != SQL_SUCCESS)
    {
      err_printf ("prepare failed.\n");
      error (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
      exit (1);
    }

  for (i = 0; i < n_times; i++)
    {
      rc = SQLExecute (hstmt);
      if (rc != SQL_SUCCESS)
	{
	  err_printf ("exec %d failed.\n", i + 1);
	  error (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
	  exit (1);
	}
    }

  SQLFreeHandle (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
}


void
test ()
{
  HSTMT hstmt;
  SQLRETURN rc;

  rc = SQLAllocHandle (SQL_HANDLE_STMT, (SQLHANDLE) hdbc,
      (SQLHANDLE *) & hstmt);
  if (rc != SQL_SUCCESS)
    {
      err_printf ("SQLAllocHandle() failed.\n");
      return;
    }

  rc = SQLPrepare (hstmt, "burstoff_rs_proc ()", SQL_NTS);
  if (rc != SQL_SUCCESS)
    {
      err_printf ("prepare failed.\n");
      error (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
      exit (1);
    }

  call_proc (10);
  printf ("test: SQLExecute\n");

  rc = SQLExecute (hstmt);
  if (rc != SQL_SUCCESS)
    {
      err_printf ("exec failed.\n");
      error (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
      exit (1);
    }
  printf ("test: SQLFetch\n");
  rc = SQLFetch (hstmt);
  if (rc != SQL_SUCCESS)
    {
      err_printf ("fetch failed.\n");
      error (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
      exit (1);
    }
  printf ("test: SQLCancel\n");
  rc = SQLCancel (hstmt);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      err_printf ("SQLCancel() failed.\n");
      exit (-1);
    }

  printf ("test: SQLFreeHandle\n");
  rc = SQLFreeHandle (SQL_HANDLE_STMT, (SQLHANDLE) hstmt);
}


int
main (int ac, char *av[])
{
  SQLRETURN rc;

  if (ac < 3)
    {
      err_printf ("***FAILED: usage : %s dsn uid pwd\n", av[0]);
      return (-1);
    }
  dsn = av[1];
  uid = av[2];
  pwd = av[3];
  rc = SQLAllocHandle (SQL_HANDLE_ENV, SQL_NULL_HANDLE, (SQLHANDLE *) & henv);
  if (rc != SQL_SUCCESS)
    {
      err_printf ("SQLAllocHandle() failed.\n");
      return 1;
    }

  rc = SQLSetEnvAttr (henv, SQL_ATTR_ODBC_VERSION, (SQLPOINTER) SQL_OV_ODBC3,
      SQL_IS_INTEGER);
  if (rc != SQL_SUCCESS)
    {
      err_printf ("SQLSetEnvAttr() failed.\n");
      return 1;
    }

  rc = SQLAllocHandle (SQL_HANDLE_DBC, (SQLHANDLE) henv,
      (SQLHANDLE *) & hdbc);
  if (rc != SQL_SUCCESS)
    {
      err_printf ("SQLAllocHandle() failed.\n");
      return 1;
    }

  rc = SQLConnect (hdbc, dsn, SQL_NTS, uid, SQL_NTS, pwd, SQL_NTS);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      err_printf ("SQLConnect() failed.\n");
      error (SQL_HANDLE_DBC, (SQLHANDLE) hdbc);
      return 1;
    }
  rc = SQLSetConnectOption (hdbc, SQL_AUTOCOMMIT, 0);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      err_printf ("autocommit off() failed.\n");
      error (SQL_HANDLE_DBC, (SQLHANDLE) hdbc);
      return 1;
    }

  create_proc ();

  printf ("=====================================================\n");
  printf ("starting test\n");
  test ();
  printf ("test1 done\n");
  printf ("=====================================================\n");
  return 0;
}

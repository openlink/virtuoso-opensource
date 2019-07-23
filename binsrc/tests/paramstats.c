/*
 *  paramstats.c
 *
 *  $Id$
 *
 *  param status pointer test (bug 1293)
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

#include "odbcinc.h"
#include <stdio.h>
#include <stdarg.h>

#define PARAMSET_SIZE 1
#define ROW_NUMBER 10

typedef struct
{
  SQLINTEGER length;
  SQLINTEGER value;
} PARAM;

typedef struct
{
  SQLUSMALLINT status[PARAMSET_SIZE];
  SQLUSMALLINT past_status[ROW_NUMBER];
} TESTDATA;

void
whine(SQLSMALLINT htype, SQLHANDLE h, const char* msg, ...)
{
  va_list args;
  SQLCHAR state[6], buffer[SQL_MAX_MESSAGE_LENGTH];
  SQLSMALLINT i, length;

  fprintf(stderr, "*** FAILED: ");
  fprintf(stdout, "*** FAILED: ");

  va_start(args, msg);
  vfprintf(stderr, msg, args);
  vfprintf(stdout, msg, args);
  va_end(args);

  fprintf(stderr, "\n");
  fprintf(stdout, "\n");

  for (i = 1; SQL_NO_DATA != SQLGetDiagRec(htype, h, i, state, NULL, buffer, sizeof buffer, &length); i++)
    {
      fprintf(stderr, "Error %s: %s\n", state, buffer);
      fprintf(stdout, "Error %s: %s\n", state, buffer);
    }
}

void
report (TESTDATA *testdata, char *message, int params_processed)
{
  int i;
  printf("%-30.30s%-30d", message, params_processed);
  for (i = 0; i < PARAMSET_SIZE; i++)
    printf("%d ", testdata->status[i]);
  for (i = 0; i < ROW_NUMBER; i++)
    printf("%d ", testdata->past_status[i]);
  printf("\n");
}

int
main(int argc, char *argv[])
{
  SQLHENV henv;
  SQLHDBC hdbc;
  SQLHSTMT hstmt;
  SQLRETURN rc;
  PARAM param[PARAMSET_SIZE];
  TESTDATA testdata;
  volatile SQLUINTEGER params_processed;
  int i, rows;

  rc = SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, (SQLHANDLE *) &henv);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      fprintf(stderr, "Cannot alloc environment.\n");
      return 1;
    }

  rc = SQLSetEnvAttr(henv, SQL_ATTR_ODBC_VERSION, (SQLPOINTER) SQL_OV_ODBC3, SQL_IS_INTEGER);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      fprintf(stderr, "Cannot set environment attribute.\n");
      return 1;
    }

  rc = SQLAllocHandle(SQL_HANDLE_DBC, (SQLHANDLE) henv, (SQLHANDLE *) &hdbc);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      fprintf(stderr, "Cannot alloc connection.\n");
      return 1;
    }

  rc = SQLConnect (hdbc, argv[1], SQL_NTS, argv[2], SQL_NTS, argv[3], SQL_NTS);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      fprintf(stderr, "Cannot connect.\n");
      return 1;
    }

  rc = SQLAllocHandle(SQL_HANDLE_STMT, (SQLHANDLE) hdbc, (SQLHANDLE *) &hstmt);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      fprintf(stderr, "Cannot alloc statement.\n");
      return 1;
    }

  rc = SQLSetStmtAttr(hstmt, SQL_ATTR_CONCURRENCY, (SQLPOINTER) SQL_CONCUR_LOCK, SQL_IS_INTEGER);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      whine(SQL_HANDLE_STMT, (SQLHANDLE) hstmt, "Cannot set concurrency type");
      return -1;
    }
  if (argc > 3)
    {
      rc = SQLSetStmtAttr(hstmt, SQL_ATTR_CURSOR_TYPE, (SQLPOINTER) SQL_CURSOR_KEYSET_DRIVEN, SQL_IS_INTEGER);
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  whine(SQL_HANDLE_STMT, (SQLHANDLE) hstmt, "Cannot set cursor type");
	  return -1;
	}
    }
  rc = SQLSetStmtAttr(hstmt, SQL_ATTR_PARAM_BIND_TYPE, (SQLPOINTER) sizeof(PARAM), SQL_IS_UINTEGER);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      whine(SQL_HANDLE_STMT, (SQLHANDLE) hstmt, "Cannot set statement attribute.\n");
      return 1;
    }
  rc = SQLSetStmtAttr(hstmt, SQL_ATTR_PARAMSET_SIZE, (SQLPOINTER) PARAMSET_SIZE, SQL_IS_UINTEGER);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      whine(SQL_HANDLE_STMT, (SQLHANDLE) hstmt, "Cannot set statement attribute.\n");
      return 1;
    }
  rc = SQLSetStmtAttr(hstmt, SQL_ATTR_PARAMS_PROCESSED_PTR, (SQLPOINTER) &params_processed, SQL_IS_POINTER);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      whine(SQL_HANDLE_STMT, (SQLHANDLE) hstmt, "Cannot set statement attribute.\n");
      return 1;
    }
  rc = SQLSetStmtAttr(hstmt, SQL_ATTR_PARAM_STATUS_PTR, testdata.status, SQL_IS_POINTER);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      whine(SQL_HANDLE_STMT, (SQLHANDLE) hstmt, "Cannot set statement attribute.\n");
      return 1;
    }

  rc = SQLPrepare (hstmt, (SQLCHAR *)"select * from foo where bar =?", SQL_NTS);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      whine(SQL_HANDLE_STMT, (SQLHANDLE) hstmt, "Cannot prepare");
      return 1;
    }
  rc = SQLBindParameter(hstmt, 1, SQL_PARAM_INPUT, SQL_INTEGER, SQL_C_LONG,
			0, 0, &param[0].value, 0, &param[0].length);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      whine(SQL_HANDLE_STMT, (SQLHANDLE) hstmt, "Cannot bind parameter");
      return 1;
    }

  params_processed = 0;
  param[0].length = sizeof param[0].value;
  param[0].value = 1;

  /*
   * Initailize test data.
   */
  for (i = 0; i < PARAMSET_SIZE; i++)
    testdata.status[i] = -1;
  for (i = 0; i < ROW_NUMBER; i++)
    testdata.past_status[i] = 1;

  report (&testdata, "Before SQLExecDirect", params_processed);
  rc = SQLExecute(hstmt);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      whine(SQL_HANDLE_STMT, (SQLHANDLE) hstmt, "Cannot execute statement.\n");
      return 1;
    }

  if (params_processed != 1)
    whine (SQL_HANDLE_STMT, (SQLHANDLE) hstmt, "No params processed after an exec");

  printf("%-30.30s%-30.30s%s\n", " ", "PARAMS_PROCESSED",  "PAST-PARAM-MEMORY");

  for (i = 0; i < PARAMSET_SIZE; i++)
    if (testdata.status[i] != SQL_PARAM_SUCCESS)
      {
	whine (SQL_HANDLE_STMT, (SQLHANDLE) hstmt, "Param %d not successfull = %d", i + 1, testdata.status[i]);
	break;
      }
  report (&testdata, "After SQLExecDirect", params_processed);

  rows = 0;
  for(;;rows ++)
    {
      rc = SQLFetchScroll(hstmt, SQL_FETCH_NEXT, 0);
      report (&testdata, "After SQLFetch", params_processed);
      if (rc == SQL_NO_DATA)
	break;
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  whine(SQL_HANDLE_STMT, (SQLHANDLE) hstmt, "Cannot execute statement.\n");
	  return 1;
	}
    }
  if (rows != 10)
    whine (SQL_HANDLE_STMT, (SQLHANDLE) hstmt, "Row count differs = %d", rows);
  for (i = 0; i < ROW_NUMBER; i++)
    if (testdata.past_status[i] != 1)
      {
	whine (SQL_HANDLE_STMT, (SQLHANDLE) hstmt, "Write after the param_status");
	break;
      }

  return 0;
}

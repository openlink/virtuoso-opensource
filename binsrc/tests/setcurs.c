/*
 *  setcurs.c
 *
 *  $Id$
 *
 *  Testsuite for SQLSetCursorName() call.
 *  In order it to work there should be the following statements :
 *  create table GOGO (NAME varchar (20) primary key, PHONE varchar (50));
 *  insert into GOGO values ('Smith, John', NULL);
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

#if defined (WIN32) | defined (WINDOWS)
#include <windows.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "odbcinc.h"

#define NAME_LEN 50
#define PHONE_LEN 20

SQLHENV henv;
SQLHDBC hdbc;

SQLHSTMT hstmtSelect;
SQLHSTMT hstmtUpdate;
SQLRETURN retcode;
SQLHDBC hdbc;
SQLCHAR szName[NAME_LEN], szPhone[PHONE_LEN];
SQLLEN cbName, cbPhone;
RETCODE rc;

#define CHK_ERR(stmt)  \
if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO) \
  { \
    SQLCHAR state[6], msg[200]; \
    int is_err = 0; \
    if (stmt != SQL_NULL_HSTMT) \
      while (SQL_SUCCESS == SQLError (SQL_NULL_HENV, SQL_NULL_HDBC, stmt, \
	    state, NULL, msg, sizeof (msg), NULL)) \
	{ \
	  fprintf (stderr, "stmt SQL ERR[%.5s] %.200s\n", state, msg); \
	      is_err = 1; \
	} \
    while (SQL_SUCCESS == SQLError (SQL_NULL_HENV, hdbc, SQL_NULL_HSTMT, \
	  state, NULL, msg, sizeof (msg), NULL)) \
      { \
	fprintf (stderr, "conn SQL ERR[%.5s] %.200s\n", state, msg); \
	    is_err = 1; \
      } \
    while (SQL_SUCCESS == SQLError (henv, SQL_NULL_HDBC, SQL_NULL_HSTMT, \
	  state, NULL, msg, sizeof (msg), NULL)) \
      { \
	fprintf (stderr, "env SQL ERR[%.5s] %.200s\n", state, msg); \
	    is_err = 1; \
      } \
    if (is_err) exit (-2); \
  }

int
main (int argc, char *argv[])
{
  if (argc < 4)
    {
      fprintf (stderr,
	  "ERR : called as setcurs <dsn> <uid> <pwd> [<scroll>=1]\n");
      exit (-3);
    }
  rc = SQLAllocEnv (&henv);
  if (rc != SQL_SUCCESS)
    {
      fprintf (stderr, "ERR : cannot alloc ODBC environment\n");
      exit (-3);
    }
  rc = SQLAllocConnect (henv, &hdbc);
  CHK_ERR (SQL_NULL_HSTMT);
  rc = SQLConnect (hdbc, argv[1], SQL_NTS, argv[2], SQL_NTS, argv[3],
      SQL_NTS);
  CHK_ERR (SQL_NULL_HSTMT);
  /* Allocate the statements and set the cursor name. */

  rc = SQLAllocStmt (hdbc, &hstmtSelect);
  CHK_ERR (SQL_NULL_HSTMT);
  rc = SQLAllocStmt (hdbc, &hstmtUpdate);
  CHK_ERR (SQL_NULL_HSTMT);
  if (argc <= 4 || atoi (argv[4]) != 0)
    {
      rc = SQLSetStmtOption (hstmtSelect, SQL_CURSOR_TYPE, SQL_CURSOR_STATIC);
      CHK_ERR (hstmtSelect);
      rc = SQLSetScrollOptions (hstmtSelect, SQL_CONCUR_READ_ONLY, 1, 1);
      CHK_ERR (hstmtSelect);
    }
  rc = SQLSetCursorName (hstmtSelect, "C1", SQL_NTS);
  CHK_ERR (hstmtSelect);

  /* SELECT the result set and bind its columns to local buffers. */

  rc = SQLExecDirect (hstmtSelect, "SELECT NAME,PHONE from GOGO", SQL_NTS);
  CHK_ERR (hstmtSelect);
  rc = SQLBindCol (hstmtSelect, 1, SQL_C_CHAR, szName, NAME_LEN, &cbName);
  CHK_ERR (hstmtSelect);
  rc = SQLBindCol (hstmtSelect, 2, SQL_C_CHAR, szPhone, PHONE_LEN, &cbPhone);
  CHK_ERR (hstmtSelect);

  /* Read through the result set until the cursor is */
  /* positioned on the row for John Smith. */

  do
    retcode = SQLFetch (hstmtSelect);
  while ((retcode == SQL_SUCCESS || retcode == SQL_SUCCESS_WITH_INFO) &&
      (strcmp (szName, "Smith, John") != 0));
  rc = retcode;
  CHK_ERR (hstmtSelect);
  /* Perform a positioned update of John Smith's name. */

  if (retcode == SQL_SUCCESS || retcode == SQL_SUCCESS_WITH_INFO)
    {
      rc = SQLExecDirect (hstmtUpdate,
	  "UPDATE GOGO SET PHONE='2064890154' WHERE CURRENT OF C1", SQL_NTS);
      CHK_ERR (hstmtUpdate);
    }
#if 0
  SQLFreeStmt (hstmtUpdate, SQL_DROP);
  SQLFreeStmt (hstmtSelect, SQL_DROP);
  SQLDisconnect (hdbc);
  SQLFreeConnect (hdbc);
#endif
  printf ("PASSED: SetCursorName Test\n");
  exit (0);
}

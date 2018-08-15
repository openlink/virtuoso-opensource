/*
 *  force_dbms_name.c
 *
 *  $Id$
 *
 *  Testsuite for FORCE_DBMS_NAME connect option.
 *  set the DBMS name to haha.
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

SQLRETURN retcode;
SQLHDBC hdbc;
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
  char dbms_name[501];
  char conn_str_out[2048];
  int is_dsn = (argc == 2);
  if (argc != 2 && argc < 4)
    {
      fprintf (stderr,
	  "ERR : called as force_dbms_name (<dsn> <uid> <pwd>) | <connect string>)\n");
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
  if (is_dsn)
    rc = SQLDriverConnect (hdbc,
#ifdef WIN32
	GetDesktopWindow(),
#else
	NULL,
#endif
	argv[1], SQL_NTS,
	conn_str_out, sizeof (conn_str_out), NULL, SQL_DRIVER_NOPROMPT);
  else
    rc = SQLConnect (hdbc, argv[1], SQL_NTS, argv[2], SQL_NTS, argv[3],
	SQL_NTS);
  CHK_ERR (SQL_NULL_HSTMT);

  rc = SQLGetInfo (hdbc, SQL_DBMS_NAME, dbms_name, sizeof (dbms_name), NULL);
  CHK_ERR (SQL_NULL_HSTMT);

  if (is_dsn)
    fprintf (stdout, "conn_str :%.2047s\n", conn_str_out);
  fprintf (stdout, "dbms_name :%.500s\n", dbms_name);
  if (!strcmp (dbms_name, "haha"))
    exit (0);
  else
    exit (-4);
}

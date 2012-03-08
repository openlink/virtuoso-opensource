/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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
#include "odbcuti.h"
#include <stdio.h>
#include <string.h>

HENV henv = SQL_NULL_HENV;
HDBC hdbc = SQL_NULL_HDBC;
HSTMT hstmt = SQL_NULL_HSTMT;
RETCODE rc;

int messages_off = 0;


void
print_error (HSTMT e1, HSTMT e2, HSTMT e3)
{
  SWORD len;
  char state[10];
  char message[1000];
  SQLError (e1, e2, e3, (UCHAR *) state, NULL,
      (UCHAR *) &message, sizeof (message), &len);
  printf ("\n*** Error %s: %s\n", state, message);
  if (0 == strcmp (state, "08S01"))
    exit (-1);
}

int
main (int argc, char *argv[])
{
   rc = SQLAllocEnv (&henv);
   IF_EERR_EXIT (henv, rc);

   rc = SQLAllocConnect (henv, &hdbc);
   IF_CERR_EXIT (hdbc, rc);

   rc = SQLConnect (hdbc,
       argc > 1 ? argv[1] : "1111", SQL_NTS,
       argc > 2 ? argv[2] : "dba", SQL_NTS,
       argc > 3 ? argv[3] : "dba", SQL_NTS);
   IF_CERR_EXIT (hdbc, rc);

   rc = SQLAllocStmt (hdbc, &hstmt);
   IF_CERR_EXIT (hdbc, rc);

   rc = SQLSetStmtOption (hstmt, SQL_ROWSET_SIZE, 10);
   rc = SQLSetStmtOption (hstmt, SQL_CURSOR_TYPE, SQL_CURSOR_KEYSET_DRIVEN);

   rc = SQLExecDirect (hstmt, "select distinct name_part (KEY_TABLE, 0) as DB from DB.DBA.SYS_KEYS", SQL_NTS);
   while (SQL_SUCCESS == (rc = SQLFetch (hstmt)))
     {
       char data[128];
       SDWORD len = sizeof (data);
       IF_ERR_EXIT (hstmt, rc);
       rc = SQLGetData (hstmt, 1, SQL_C_CHAR, data, sizeof (data), &len);
       IF_ERR_EXIT (hstmt, rc);
       if (rc == SQL_SUCCESS)
	 fprintf (stdout, "%s\n", data);
     }
   IF_ERR_EXIT (hstmt, rc);
   SQLDisconnect (hdbc);
   SQLFreeConnect (hdbc);
   SQLFreeEnv (henv);

   return 0;
}

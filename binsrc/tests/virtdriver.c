/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "odbcinc.h"
#include "timeacct.h"

char *replace_newline (char *s)
{
    char *z;
    z = strchr (s, '\n');
    *z = 0;
    return s;
}

#define BUFSIZE 1000

HENV henv = SQL_NULL_HENV;
HDBC hdbc = SQL_NULL_HDBC;
HSTMT hstmt = SQL_NULL_HSTMT;
RETCODE rc;
char state[10], message[1000];

void
odbc_error ()
{
  SWORD len;
  SQLError (hstmt || hdbc ? SQL_NULL_HENV : henv, hstmt ? SQL_NULL_HDBC : hdbc, hstmt, (UCHAR *) state, NULL,
      (UCHAR *) &message, sizeof (message), &len);
  printf ("\n*** Error %s: %s\n", state, message);
  fflush (stdout);
}

int main(int argc, char** argv)
{
    char buffer[BUFSIZE];
    char result[BUFSIZE];
    char *dsn = getenv("DSN");
    char *uid = getenv("UID");
    char *pwd = getenv("PWD");

    if (SQL_SUCCESS != (rc = SQLAllocEnv (&henv)))
      {
	odbc_error ();
	return -1;
      }
    if (SQL_SUCCESS != (rc = SQLAllocConnect (henv, &hdbc)))
      {
	odbc_error ();
	return -1;
      }
    if (SQL_SUCCESS != (rc = SQLConnect (hdbc,
	    dsn ? dsn : "1111", SQL_NTS,
	    uid ? uid : "dba", SQL_NTS,
	    pwd ? pwd : "dba", SQL_NTS)))
      {
	odbc_error ();
	return -1;
      }
    if (SQL_SUCCESS != (rc = SQLAllocStmt (hdbc, &hstmt)))
      {
	odbc_error ();
	return -1;
      }
    while (NULL != fgets (buffer, BUFSIZE, stdin))
    {
      if (SQL_SUCCESS != (rc = SQLBindParameter (hstmt, 3, SQL_PARAM_OUTPUT,
	      SQL_C_CHAR, SQL_CHAR,
	      sizeof (result), 0, result, sizeof (result), NULL)))
	{
	  odbc_error ();
	  break;
	}

        if (0 == strncmp ("chdir", buffer, 5))
        {
	  if (SQL_SUCCESS != (rc = SQLSetParam (hstmt, 1, SQL_C_CHAR, SQL_CHAR, 0, 0, replace_newline (buffer + 6), NULL)))
	    {
	      odbc_error ();
	      break;
	    }
	  if (SQL_SUCCESS != (rc = SQLSetParam (hstmt, 2, SQL_C_CHAR, SQL_CHAR, 0, 0, "", NULL)))
	    {
	      odbc_error ();
	      break;
	    }
	  if (SQL_SUCCESS != (rc = SQLExecDirect (hstmt, "XSLT_CHDIR (?, ?, ?)", SQL_NTS)))
	    {
	      odbc_error ();
	      break;
	    }

            /*change directory:*/
	    printf ("%s\n", result);
            fflush (stdout);
        }
        else if (0 == strncmp ("stylesheet", buffer, 10))
        {
            /*load stylesheet: */

	  if (SQL_SUCCESS != (rc = SQLSetParam (hstmt, 1, SQL_C_CHAR, SQL_CHAR, 0, 0,
		  replace_newline (&buffer[11]), NULL)))
	    {
	      odbc_error ();
	      break;
	    }
	  if (SQL_SUCCESS != (rc = SQLSetParam (hstmt, 2, SQL_C_CHAR, SQL_CHAR, 0, 0, "", NULL)))
	    {
	      odbc_error ();
	      break;
	    }
	  if (SQL_SUCCESS != (rc = SQLExecDirect (hstmt, "XSLT_STYLESHEET (?, ?, ?)", SQL_NTS)))
	    {
	      odbc_error ();
	      break;
	    }

	  printf ("%s\n", result);
	  fflush (stdout);
        }
        else if (0 == strncmp ("input", buffer, 5))
        {
	  if (SQL_SUCCESS != (rc = SQLSetParam (hstmt, 1, SQL_C_CHAR, SQL_CHAR, 0, 0,
		  replace_newline (&buffer[6]), NULL)))
	    {
	      odbc_error ();
	      break;
	    }
	  if (SQL_SUCCESS != (rc = SQLSetParam (hstmt, 2, SQL_C_CHAR, SQL_CHAR, 0, 0, "", NULL)))
	    {
	      odbc_error ();
	      break;
	    }

	  if (SQL_SUCCESS != (rc = SQLExecDirect (hstmt, "XSLT_INPUT (?, ?, ?)", SQL_NTS)))
	    {
	      odbc_error ();
	      break;
	    }

	  printf ("%s\n", result);
	  fflush (stdout);
        }
        else if (0 == strncmp ("transform", buffer, 9))
        {
            short iter = 1;
            char * c = buffer+10;
            char *filename;
	    timer_account_t ta;

            /* get output filename */
            while (*c != '\n' && *c != '\0' && *c != ' ')
            {
                c++;
            }
            if (*c == ' ')
            {
                *c = 0;
                c++;
                filename = buffer + 10;
            }

            /* get # of iterations */
            iter = atoi(c);
            if (iter <= 0)
              iter = 1;
/*            printf ("file: %s iter : %d buffer %s\n", filename, iter, buffer); */
	    ta_init (&ta, "test");
	    ta_enter (&ta);


	  if (SQL_SUCCESS != (rc = SQLSetParam (hstmt, 1, SQL_C_CHAR, SQL_CHAR, 0, 0,
		  filename, NULL)))
	    {
	      odbc_error ();
	      break;
	    }
	  if (SQL_SUCCESS != (rc = SQLSetParam (hstmt, 2, SQL_C_SHORT, SQL_INTEGER, 0, 0, &iter, NULL)))
	    {
	      odbc_error ();
	      break;
	    }
	  if (SQL_SUCCESS != (rc = SQLExecDirect (hstmt, "XSLT_TRANSFORM (?, ?, ?)", SQL_NTS)))
	    {
	      odbc_error ();
	      break;
	    }
	  ta_leave (&ta);

	  printf ("OK wallclock: %06ld ms; cpuclock: %06ld'\n", ta.ta_total, ta.ta_total);
	  fflush (stdout);
        }
        else if (0 == strncmp ("terminate", buffer, 9))
        {
            printf ("OK\n");
            break;
        }
	if (SQL_SUCCESS != (rc = SQLFreeStmt (hstmt, SQL_CLOSE)))
	  {
	    odbc_error ();
	    return -1;
	  }
	if (SQL_SUCCESS != (rc = SQLFreeStmt (hstmt, SQL_RESET_PARAMS)))
	  {
	    odbc_error ();
	    return -1;
	  }
    }

    if (SQL_SUCCESS != (rc = SQLFreeStmt (hstmt, SQL_DROP)))
      return -1;
    if (SQL_SUCCESS != (rc = SQLDisconnect (hdbc)))
      return -1;
    if (SQL_SUCCESS != (rc = SQLFreeConnect (hdbc)))
      return -1;
    if (SQL_SUCCESS != (rc = SQLFreeEnv (henv)))
      return -1;
    return 0;
}

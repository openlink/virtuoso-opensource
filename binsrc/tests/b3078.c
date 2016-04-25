/*
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

#include <stdio.h>
#include <string.h>

#include "odbcinc.h"

SQLHENV  henv = 0;
SQLHDBC  hdbc = 0;
SQLHSTMT hstmt = 0;

#define MAXCOLS  25
#define ARRAY_SIZE 3

int
ODBC_Connect (char *dsn, char *usr, char *pwd)
{
  SQLRETURN  retcode;

  retcode = SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &henv);

  if (retcode == SQL_SUCCESS || retcode == SQL_SUCCESS_WITH_INFO)
    {
      /* Set the ODBC version environment attribute */
      retcode = SQLSetEnvAttr(henv, SQL_ATTR_ODBC_VERSION, (void*)SQL_OV_ODBC3, 0);

      if (retcode == SQL_SUCCESS || retcode == SQL_SUCCESS_WITH_INFO)
	{
	  /* Allocate connection handle */
	  retcode = SQLAllocHandle(SQL_HANDLE_DBC, henv, &hdbc);

	  if (retcode == SQL_SUCCESS || retcode == SQL_SUCCESS_WITH_INFO)
	    {

	      /* Connect to data source */
	      retcode = SQLConnect(hdbc, dsn, SQL_NTS, usr, SQL_NTS, pwd, SQL_NTS);

	      if (retcode == SQL_SUCCESS || retcode == SQL_SUCCESS_WITH_INFO)
		{
		  /* Allocate statement handle */
		  retcode = SQLAllocHandle(SQL_HANDLE_STMT, hdbc, &hstmt);

		  if (retcode == SQL_SUCCESS || retcode == SQL_SUCCESS_WITH_INFO)
		    return 0;
		  SQLDisconnect(hdbc);
		}
	      SQLFreeHandle(SQL_HANDLE_DBC, hdbc);
	    }
	}
      SQLFreeHandle(SQL_HANDLE_ENV, henv);
    }
  return -1;
}


int
ODBC_Disconnect (void)
{
  if (hstmt)
    SQLFreeStmt (hstmt, SQL_DROP);

  if (hdbc)
    SQLDisconnect (hdbc);

  if (hdbc)
    SQLFreeHandle (SQL_HANDLE_DBC, hdbc);

  if (henv)
    SQLFreeHandle (SQL_HANDLE_ENV, henv);

  return 0;
}


int
ODBC_Errors (char *where)
{
  unsigned char buf[250];
  unsigned char sqlstate[15];

  /*
   *  Get statement errors
   */
  while (SQLError (henv, hdbc, hstmt, sqlstate, NULL,
	buf, sizeof(buf), NULL) == SQL_SUCCESS)
    {
      fprintf (stdout, "%s ||%s, SQLSTATE=%s\n", where, buf, sqlstate);
    }

  /*
   *  Get connection errors
   */
  while (SQLError (henv, hdbc, SQL_NULL_HSTMT, sqlstate, NULL,
	buf, sizeof(buf), NULL) == SQL_SUCCESS)
    {
      fprintf (stdout, "%s ||%s, SQLSTATE=%s\n", where, buf, sqlstate);
    }

  /*
   *  Get environmental errors
   */
  while (SQLError (henv, SQL_NULL_HDBC, SQL_NULL_HSTMT, sqlstate, NULL,
	buf, sizeof(buf), NULL) == SQL_SUCCESS)
    {
      fprintf (stdout, "%s ||%s, SQLSTATE=%s\n", where, buf, sqlstate);
    }

  return -1;
}


int
ODBC_PrintResult()
{
  char fetchBuffer[1000];
  short displayWidths[MAXCOLS];
  short displayWidth;
  short numCols;
  short colNum;
  char colName[50];
  short colType;
  UDWORD colPrecision;
  SDWORD colIndicator;
  short colScale;
  short colNullable;
  UDWORD totalRows;
  UDWORD totalSets;
  int i;

  totalSets = 0;
  do
    {

      /*
       *  Get the number of result columns for this cursor.
       *  If it is 0, then the statement was probably a select
       */
      if (SQLNumResultCols (hstmt, &numCols) != SQL_SUCCESS)
	{
	  ODBC_Errors ("SQLNumResultCols");
	  goto endCursor;
	}
      if (numCols == 0)
	{
	  printf ("Statement executed.\n");
	  goto endCursor;
	}

      if (numCols > MAXCOLS)
	numCols = MAXCOLS;

      /*
       *  Get the names for the columns
       */
      putchar ('\n');
      for (colNum = 1; colNum <= numCols; colNum++)
	{
	  /*
	   *  Get the name and other type information
	   */
	  if (SQLDescribeCol (hstmt, colNum, (UCHAR *) colName,
		sizeof (colName), NULL, &colType, &colPrecision,
		&colScale, &colNullable) != SQL_SUCCESS)
	    {
	      ODBC_Errors ("SQLDescribeCol");
	      goto endCursor;
	    }
	  /*
	   *  Calculate the display width for the column
	   */
	  switch (colType)
	    {
	      case SQL_VARCHAR:
	      case SQL_CHAR:
		  displayWidth = (short) colPrecision;
		  break;
	      case SQL_BIT:
		  displayWidth = 1;
		  break;
	      case SQL_TINYINT:
	      case SQL_SMALLINT:
	      case SQL_INTEGER:
	      case SQL_BIGINT:
		  displayWidth = colPrecision + 1;	/* sign */
		  break;
	      case SQL_DOUBLE:
	      case SQL_DECIMAL:
	      case SQL_NUMERIC:
	      case SQL_FLOAT:
	      case SQL_REAL:
		  displayWidth = colPrecision + 2;	/* sign, comma */
		  break;
	      case SQL_DATE:
		  displayWidth = 10;
		  break;
	      case SQL_TIME:
		  displayWidth = 8;
		  break;
	      case SQL_TIMESTAMP:
		  displayWidth = 19;
		  break;
	      default:
		  displayWidths[colNum - 1] = 0;	/* skip other data types */
		  continue;
	    }

	  if (displayWidth < strlen (colName))
	    displayWidth = strlen (colName);
	  if (displayWidth > sizeof (fetchBuffer) - 1)
	    displayWidth = sizeof (fetchBuffer) - 1;

	  displayWidths[colNum - 1] = displayWidth;

	  /*
	   *  Print header field
	   */
	  printf ("%-*.*s", displayWidth, displayWidth, colName);
	  if (colNum < numCols)
	    putchar ('|');
	}
      putchar ('\n');

      /*
       *  Print second line
       */
      for (colNum = 1; colNum <= numCols; colNum++)
	{
	  for (i = 0; i < displayWidths[colNum - 1]; i++)
	    putchar ('-');
	  if (colNum < numCols)
	    putchar ('+');
	}
      putchar ('\n');

      /*
       *  Print all the fields
       */
      totalRows = 0;
      while (1)
	{
	  int sts = SQLFetch (hstmt);

	  if (sts == SQL_NO_DATA_FOUND)
	    break;

	  if (sts != SQL_SUCCESS)
	    {
	      ODBC_Errors ("Fetch");
	      break;
	    }
	  for (colNum = 1; colNum <= numCols; colNum++)
	    {
	      /*
	       *  Fetch this column as character
	       */
	      if (SQLGetData (hstmt, colNum, SQL_CHAR, fetchBuffer,
		    sizeof (fetchBuffer), &colIndicator) != SQL_SUCCESS)
		{
		  ODBC_Errors ("SQLGetData");
		  goto endCursor;
		}

	      /*
	       *  Show NULL fields as ****
	       */
	      if (colIndicator == SQL_NULL_DATA)
		{
		  for (i = 0; i < displayWidths[colNum - 1]; i++)
		    fetchBuffer[i] = '*';
		  fetchBuffer[i] = '\0';
		}

	      printf ("%-*.*s", displayWidths[colNum - 1],
		  displayWidths[colNum - 1], fetchBuffer);
	      if (colNum < numCols)
		putchar ('|');
	    }
	  putchar ('\n');
	  totalRows++;
	}

      printf ("\n result set %lu returned %lu rows.\n\n",
	  totalSets, totalRows);
      totalSets++;
    }
  while (SQLMoreResults (hstmt) == SQL_SUCCESS);

endCursor:
  printf ("\n");
  fprintf (stderr, "\n");
  if (totalSets == ARRAY_SIZE)
    {
      printf ("PASSED: ");
      fprintf (stderr, "PASSED: ");
    }
  else
    {
      printf ("***FAILED: ");
      fprintf (stderr, "***FAILED: ");
    }
  printf ("B3078 : array parameters selects returned %lu resultsets\n", totalSets);
  fprintf (stderr, "B3078 : array parameters selects returned %lu resultsets\n", totalSets);
  SQLFreeStmt (hstmt, SQL_CLOSE);

  return 0;
}


int
ODBC_Execute()
{

  SQLCHAR *      Statement = "select * from BTEST where id > ?";
  SQLUINTEGER    IDArray[ARRAY_SIZE];

  SQLINTEGER     IDIndArray[ARRAY_SIZE];

  SQLUSMALLINT   i, ParamStatusArray[ARRAY_SIZE];
  SQLUINTEGER    ParamsProcessed;

  if (SQLParamOptions(hstmt, ARRAY_SIZE, &ParamsProcessed) != SQL_SUCCESS)
    {
      ODBC_Errors ("ODBC_Execute");
      return -1;
    }

  IDArray[0] = 3;  IDIndArray[0] = 0;
  IDArray[1] = 2;  IDIndArray[1] = 0;
  IDArray[2] = 1;  IDIndArray[2] = 0;

  /*    Bind the parameters in column-wise fashion. */
  if (SQLBindParameter(hstmt, 1, SQL_PARAM_INPUT, SQL_C_ULONG, SQL_INTEGER, 5, 0, IDArray, 0, IDIndArray) != SQL_SUCCESS)
    {
      ODBC_Errors ("ODBC_Execute");
      return -1;
    }


  /*   Execute the statement. */
  if (SQLExecDirect(hstmt, Statement, SQL_NTS) != SQL_SUCCESS)
    {
      ODBC_Errors ("ODBC_Execute");
      return -1;
    }

  /*    Check to see which sets of parameters were processed successfully. */
  printf("Parameter Sets Processed = %d\n",ParamsProcessed);
  printf("--------------------------------------\n");
  return 0;
}


int
main(int argc, char *argv[])
{
  /*   if (ODBC_Connect ("O_Sql2k", "sa", "") != 0) */
  if (ODBC_Connect (argv[1], argv[2], argv[3]) != 0)
    {
      ODBC_Errors ("ODBC_Connect");
    }
  else if (ODBC_Execute () != 0)
    {
      ODBC_Errors ("ODBC_Test");
    }
  else if (ODBC_PrintResult () != 0)
    {
      ODBC_Errors ("ODBC_Test");
    }
  /*
   *  End the connection
   */
  ODBC_Disconnect ();

  exit(0);
}


/*******************************************************************
The table for a test:

create table BTEST(id integer, name varchar(20));
insert into BTEST values(1, '11111111111');
insert into BTEST values(2, '22222222222');
insert into BTEST values(3, '33333333333');
insert into BTEST values(4, '44444444444');

*********************************************************************/

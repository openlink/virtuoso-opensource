/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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

#include       <stdio.h>
#include       <string.h>
#include       "odbcinc.h"
#include       "timeacct.h"
#include       "odbcuti.h"

SQLHENV  henv = 0;
SQLHDBC  hdbc = 0;
SQLHSTMT hstmt = 0;
int print_result = 0;
int max_univ = 1;
int n_times = 1;
int q_kind = 0; /* 0 - raw, 1 - inf, 2 - union */
timer_account_t ta_exec;
timer_account_t ta_qr[14];

#define MAXCOLS  25
#define ARRAY_SIZE 3

int
LUBM_Errors (char *where)
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
LUBM_Connect (char *dsn, char *usr, char *pwd)
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
	  if (SQLSetConnectOption(hdbc, SQL_ATTR_TXN_ISOLATION, (SQLULEN)SQL_TXN_READ_COMMITTED) == SQL_ERROR)
	    {
	      LUBM_Errors ("SQLSetConnectOption[SQL_ATTR_TXN_ISOLATION]");
	      exit (-1);
	    }

	  if (retcode == SQL_SUCCESS || retcode == SQL_SUCCESS_WITH_INFO)
	    {

	      /* Connect to data source */
	      retcode = SQLConnect(hdbc, (UCHAR *)dsn, SQL_NTS, (UCHAR *)usr, SQL_NTS, (UCHAR *)pwd, SQL_NTS);

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
LUBM_Disconnect (void)
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
LUBM_PrintResult()
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
	  LUBM_Errors ("SQLNumResultCols");
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
      /*putchar ('\n'); */
      for (colNum = 1; colNum <= numCols; colNum++)
	{
	  /*
	   *  Get the name and other type information
	   */
	  if (SQLDescribeCol (hstmt, colNum, (UCHAR *) colName,
		sizeof (colName), NULL, &colType, &colPrecision,
		&colScale, &colNullable) != SQL_SUCCESS)
	    {
	      LUBM_Errors ("SQLDescribeCol");
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

	  if (displayWidth < strlen ((char *) colName))
	    displayWidth = strlen (colName);
	  if (displayWidth > sizeof (fetchBuffer) - 1)
	    displayWidth = sizeof (fetchBuffer) - 1;

	  displayWidths[colNum - 1] = displayWidth;

	  /*
	   *  Print header field
	   */
	  /*
	  printf ("%-*.*s", displayWidth, displayWidth, colName);
	  if (colNum < numCols)
	    putchar ('|');
	    */
	}
      /*putchar ('\n');*/

      /*
       *  Print second line
       */
      /*
      for (colNum = 1; colNum <= numCols; colNum++)
	{
	  for (i = 0; i < displayWidths[colNum - 1]; i++)
	    putchar ('-');
	  if (colNum < numCols)
	    putchar ('+');
	}
      putchar ('\n');
      */

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
	      LUBM_Errors ("Fetch");
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
		  LUBM_Errors ("SQLGetData");
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

	      if (print_result > 1)
		{
		  printf ("%-.*s",
		      displayWidths[colNum - 1], fetchBuffer);
		  if (colNum < numCols)
		    putchar ('|');
		}
	    }
	  if (print_result > 1)
	    putchar ('\n');
	  totalRows++;
	}

      if (print_result)
	printf (" returned %lu rows.\n", totalRows);
      totalSets++;
    }
  while (SQLMoreResults (hstmt) == SQL_SUCCESS);

endCursor:
/*
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
  printf ("B3078 : array parameters selects returned %d resultsets\n", totalSets);
  fprintf (stderr, "B3078 : array parameters selects returned %d resultsets\n", totalSets);
*/
  SQLFreeStmt (hstmt, SQL_CLOSE);

  return 0;
}


char * q_pref = " prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#> select * from <lubm> where ";
char * q_count_pref = " prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#> select count (*) from <lubm> where ";
char * inf_pref = " define input:inference 'inft' ";

char *
get_University (char * buf)
{
  int univ;
  univ  = random_1 (max_univ);
  sprintf (buf, "http://www.University%d.edu", univ);
  return buf;
}

char *
get_Department (char * buf)
{
  int dept, univ;
  dept = random_1 (25);
  univ = random_1 (max_univ);
  sprintf (buf, "http://www.Department%d.University%d.edu", dept, univ);
  return buf;
}

char *
get_GraduateCourse (char * buf)
{
  int dept, univ, course;
  dept = random_1 (25);
  univ = random_1 (max_univ);
  course = random_1 (80);
  sprintf (buf, "http://www.Department%d.University%d.edu/GraduateCourse%d", dept, univ, course);
  return buf;
}

char *
get_AssistantProfessor (char * buf)
{
  int dept, univ, prof;
  dept = random_1 (25);
  univ = random_1 (max_univ);
  prof = random_1 (11);
  sprintf (buf, "http://www.Department%d.University%d.edu/AssistantProfessor%d",  dept, univ, prof);
  return buf;
}

char *
get_AssociateProfessor (char * buf)
{
  int dept, univ, prof;
  dept = random_1 (25);
  univ = random_1 (max_univ);
  prof = random_1 (14);
  sprintf (buf, "http://www.Department%d.University%d.edu/AssociateProfessor%d",  dept, univ, prof);
  return buf;
}

typedef char * (*rand_func) ();

typedef struct qr_s {
   int n_pars;
   char * pattern;
   void * func;
 } qr_t;

qr_t qrs[] =
{
  /* Q1 */
  {1, "{ ?x rdf:type ub:GraduateStudent . ?x ub:takesCourse <%s> }", &get_GraduateCourse },
  /* Q2 */
  {2, "{ ?x a ub:GraduateStudent . ?z a ub:Department . ?x ub:memberOf ?z . ?z ub:subOrganizationOf <%s> . ?x ub:undergraduateDegreeFrom <%s> }", &get_University},
  /* Q3 */
  {1, "{ ?x a ub:Publication . ?x ub:publicationAuthor <%s> }", &get_AssistantProfessor},
  /* Q4 */
  {1, "{ ?x a ub:Professor . ?x ub:worksFor <%s> . ?x ub:name ?y1 . ?x ub:emailAddress ?y2 . ?x ub:telephone ?y3 . }", &get_Department},
  /* Q5 */
  {1, "{ ?x a ub:Person . ?x ub:memberOf <%s> }", &get_University},
  /* Q6 */
  {1, "{ ?x a ub:Student . ?x ub:memberOf <%s> }", &get_Department },
  /* Q7 */
  {1, "{ ?x a ub:Student . ?y a ub:Course . <%s> ub:teacherOf ?y . ?x ub:takesCourse ?y . }", &get_AssociateProfessor},
  /* Q8 */
  {1, "{ ?x a ub:Student . ?y a ub:Department . ?x ub:memberOf ?y . ?y ub:subOrganizationOf <%s> . ?x ub:emailAddress ?z }", &get_University},
  /* Q9 */
  {1, "{ ?x a ub:Student . ?y a ub:Faculty . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . }", &get_Department },
  /* Q10 */
  {1, "{ ?x a ub:Student . ?x ub:takesCourse <%s> . }", &get_GraduateCourse},
  /* Q11 */
  {1, "{ ?x a ub:ResearchGroup . ?x ub:subOrganizationOf <%s> . }", &get_University},
  /* Q12 */
  {1, "{ ?x a ub:Professor . ?y a ub:Department . ?x ub:headOf ?y . ?y ub:subOrganizationOf <%s> . }", &get_University},
  /* Q13 */
  {1, "{ ?x a ub:Person . ?x ub:degreeFrom <%s> . }", &get_University},
  /* Q14 */
  {1, "{ ?x a ub:UndergraduateStudent . ?x ub:memberOf ?z . ?z ub:subOrganizationOf <%s> . }", &get_University }
};

/* union */
qr_t uqrs[] =
{
  /* Q1 */
  { 1, "{ ?x rdf:type ub:GraduateStudent . ?x ub:takesCourse <%s> }", &get_GraduateCourse },
  /* Q2 */
  { 2, "{ ?x a ub:GraduateStudent . ?z a ub:Department . ?x ub:memberOf ?z . ?z ub:subOrganizationOf <%s> . ?x ub:undergraduateDegreeFrom <%s> }", &get_University},
  /* Q3 */
  { 1, "{ ?x a ub:Publication . ?x ub:publicationAuthor <%s> }", &get_AssistantProfessor },

  /* Q4 */
  { 3, "{ { ?x a ub:AssociateProfessor . ?x ub:worksFor <%s> . ?x ub:name ?y1 . ?x ub:emailAddress ?y2 . ?x ub:telephone ?y3 . } union "
       "{ ?x a ub:AssistantProfessor . ?x ub:worksFor <%s> . ?x ub:name ?y1 . ?x ub:emailAddress ?y2 . ?x ub:telephone ?y3 . } union"
       "{ ?x a ub:FullProfessor . ?x ub:worksFor <%s> . ?x ub:name ?y1 . ?x ub:emailAddress ?y2 . ?x ub:telephone ?y3 . } }",
       &get_Department },

  /* Q5 */
  { 24,
    "{ { ?x a ub:AssociateProfessor . ?x ub:memberOf <%s> } union "
	"{ ?x a ub:FullProfessor . ?x ub:memberOf <%s> } union "
	"{ ?x a ub:AssistantProfessor . ?x ub:memberOf <%s> } union "
	"{ ?x a ub:Lecturer . ?x ub:memberOf <%s> } union "
	"{ ?x a ub:UndergraduateStudent . ?x ub:memberOf <%s> } union "
	"{ ?x a ub:GraduateStudent . ?x ub:memberOf <%s> } union "
	"{ ?x a ub:TeachingAssistant . ?x ub:memberOf <%s> } union "
	"{ ?x a ub:ResearchAssistant . ?x ub:memberOf <%s> } union "
	"{ ?x a ub:AssociateProfessor . ?x ub:worksFor <%s> } union "
	"{ ?x a ub:FullProfessor . ?x ub:worksFor <%s> } union "
	"{ ?x a ub:AssistantProfessor . ?x ub:worksFor <%s> } union "
	"{ ?x a ub:Lecturer . ?x ub:worksFor <%s> } union "
	"{ ?x a ub:UndergraduateStudent . ?x ub:worksFor <%s> } union "
	"{ ?x a ub:GraduateStudent . ?x ub:worksFor <%s> } union "
	"{ ?x a ub:TeachingAssistant . ?x ub:worksFor <%s> } union "
	"{ ?x a ub:ResearchAssistant . ?x ub:worksFor <%s> } union "
	"{ ?x a ub:AssociateProfessor . ?x ub:headOf <%s> } union "
	"{ ?x a ub:FullProfessor . ?x ub:headOf <%s> } union "
	"{ ?x a ub:AssistantProfessor . ?x ub:headOf <%s> } union "
	"{ ?x a ub:Lecturer . ?x ub:headOf <%s> } union "
	"{ ?x a ub:UndergraduateStudent . ?x ub:headOf <%s> } union "
	"{ ?x a ub:GraduateStudent . ?x ub:headOf <%s> } union "
	"{ ?x a ub:TeachingAssistant . ?x ub:headOf <%s> } union "
	"{ ?x a ub:ResearchAssistant . ?x ub:headOf <%s> } }",
    &get_Department },

  /* Q6 */
  { 3, "{ { ?x a ub:UndergraduateStudent . ?x ub:memberOf <%s> } union { ?x a ub:ResearchAssistant . ?x ub:memberOf <%s> } union { ?x a ub:GraduateStudent . ?x ub:memberOf <%s> } }", &get_Department },

  /* Q7 */
  { 6, "{ {  ?x a ub:UndergraduateStudent . ?y a ub:Course . <%s> ub:teacherOf ?y . ?x ub:takesCourse ?y . } union "
    "{  ?x a ub:UndergraduateStudent . ?y a ub:GraduateCourse . <%s> ub:teacherOf ?y . ?x ub:takesCourse ?y . } union "
    "{  ?x a ub:ResearchAssistant . ?y a ub:Course . <%s> ub:teacherOf ?y . ?x ub:takesCourse ?y . } union "
    "{  ?x a ub:ResearchAssistant . ?y a ub:GraduateCourse . <%s> ub:teacherOf ?y . ?x ub:takesCourse ?y . } union "
    "{  ?x a ub:GraduateStudent . ?y a ub:Course . <%s> ub:teacherOf ?y . ?x ub:takesCourse ?y . } union "
    "{  ?x a ub:GraduateStudent . ?y a ub:GraduateCourse . <%s> ub:teacherOf ?y . ?x ub:takesCourse ?y . } } ",
    &get_AssociateProfessor },

  /* Q8 */
  { 9, "{ { ?x a ub:UndergraduateStudent . ?y a ub:Department . ?x ub:memberOf ?y . ?y ub:subOrganizationOf <%s> . ?x ub:emailAddress ?z } union "
"{ ?x a ub:UndergraduateStudent . ?y a ub:Department . ?x ub:worksFor ?y . ?y ub:subOrganizationOf <%s> . ?x ub:emailAddress ?z } union"
" { ?x a ub:UndergraduateStudent . ?y a ub:Department . ?x ub:headOf ?y . ?y ub:subOrganizationOf <%s> . ?x ub:emailAddress ?z } union "
" { ?x a ub:ResearchAssistant . ?y a ub:Department . ?x ub:memberOf ?y . ?y ub:subOrganizationOf <%s> . ?x ub:emailAddress ?z } union "
" { ?x a ub:ResearchAssistant . ?y a ub:Department . ?x ub:worksFor ?y . ?y ub:subOrganizationOf <%s> . ?x ub:emailAddress ?z } union "
" { ?x a ub:ResearchAssistant . ?y a ub:Department . ?x ub:headOf ?y . ?y ub:subOrganizationOf <%s> . ?x ub:emailAddress ?z } union "
" { ?x a ub:GraduateStudent . ?y a ub:Department . ?x ub:memberOf ?y . ?y ub:subOrganizationOf <%s> . ?x ub:emailAddress ?z } union "
" { ?x a ub:GraduateStudent . ?y a ub:Department . ?x ub:worksFor ?y . ?y ub:subOrganizationOf <%s> . ?x ub:emailAddress ?z } union "
" { ?x a ub:GraduateStudent . ?y a ub:Department . ?x ub:headOf ?y . ?y ub:subOrganizationOf <%s> . ?x ub:emailAddress ?z } } ",
    &get_University },

  /* Q9 */
 { 36, "{ { ?x a ub:ResearchAssistant . ?y a ub:Lecturer . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:ResearchAssistant . ?y a ub:PostDoc . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:ResearchAssistant . ?y a ub:VisitingProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:ResearchAssistant . ?y a ub:AssistantProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:ResearchAssistant . ?y a ub:AssociateProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:ResearchAssistant . ?y a ub:FullProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:ResearchAssistant . ?y a ub:Lecturer . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:ResearchAssistant . ?y a ub:PostDoc . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:ResearchAssistant . ?y a ub:VisitingProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:ResearchAssistant . ?y a ub:AssistantProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:ResearchAssistant . ?y a ub:AssociateProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:ResearchAssistant . ?y a ub:FullProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:UndergraduateStudent . ?y a ub:Lecturer . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:UndergraduateStudent . ?y a ub:PostDoc . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:UndergraduateStudent . ?y a ub:VisitingProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:UndergraduateStudent . ?y a ub:AssistantProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z .?x ub:memberOf <%s> . } union "
"  { ?x a ub:UndergraduateStudent . ?y a ub:AssociateProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:UndergraduateStudent . ?y a ub:FullProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:UndergraduateStudent . ?y a ub:Lecturer . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:UndergraduateStudent . ?y a ub:PostDoc . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:UndergraduateStudent . ?y a ub:VisitingProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:UndergraduateStudent . ?y a ub:AssistantProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:UndergraduateStudent . ?y a ub:AssociateProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:UndergraduateStudent . ?y a ub:FullProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:GraduateStudent . ?y a ub:Lecturer . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:GraduateStudent . ?y a ub:PostDoc . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:GraduateStudent . ?y a ub:VisitingProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:GraduateStudent . ?y a ub:AssistantProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:GraduateStudent . ?y a ub:AssociateProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:GraduateStudent . ?y a ub:FullProfessor . ?z a ub:Course . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:GraduateStudent . ?y a ub:Lecturer . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:GraduateStudent . ?y a ub:PostDoc . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:GraduateStudent . ?y a ub:VisitingProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:GraduateStudent . ?y a ub:AssistantProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:GraduateStudent . ?y a ub:AssociateProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } union "
"  { ?x a ub:GraduateStudent . ?y a ub:FullProfessor . ?z a ub:GraduateCourse . ?x ub:advisor ?y . ?x ub:takesCourse ?z . ?y ub:teacherOf ?z . ?x ub:memberOf <%s> . } } ", &get_Department },

  /* Q10 */
 { 3, "{ { ?x a ub:ResearchAssistant . ?x ub:takesCourse <%s> . } union "
      "{ ?x a ub:UndergraduateStudent . ?x ub:takesCourse <%s> . } union "
      "{ ?x a ub:GraduateStudent . ?x ub:takesCourse <%s> . } } ",
	&get_GraduateCourse },

  /* Q11 */
 { 1, "{ ?x a ub:ResearchGroup . ?x ub:subOrganizationOf <%s> . }", &get_University },

  /* Q12 */
 { 3,
    " { { ?x a ub:FullProfessor . ?y a ub:Department . ?x ub:headOf ?y . ?y ub:subOrganizationOf <%s> . } union "
    " { ?x a ub:AssistantProfessor . ?y a ub:Department . ?x ub:headOf ?y . ?y ub:subOrganizationOf <%s> . } union "
    " { ?x a ub:AssociateProfessor . ?y a ub:Department . ?x ub:headOf ?y . ?y ub:subOrganizationOf <%s> . } } ",
	&get_University },

  /* Q13 */
 { 24,
    "{ { ?x a ub:AssociateProfessor . ?x ub:doctoralDegreeFrom <%s> . } union "
	"{ ?x a ub:FullProfessor . ?x ub:doctoralDegreeFrom <%s> . } union "
	"{ ?x a ub:AssistantProfessor . ?x ub:doctoralDegreeFrom <%s> . } union "
	"{ ?x a ub:Lecturer . ?x ub:doctoralDegreeFrom <%s> . } union "
	"{ ?x a ub:UndergraduateStudent . ?x ub:doctoralDegreeFrom <%s> . } union "
	"{ ?x a ub:GraduateStudent . ?x ub:doctoralDegreeFrom <%s> . } union "
	"{ ?x a ub:TeachingAssistant . ?x ub:doctoralDegreeFrom <%s> . } union "
	"{ ?x a ub:ResearchAssistant . ?x ub:doctoralDegreeFrom <%s> . } union "
	"{ ?x a ub:AssociateProfessor . ?x ub:mastersDegreeFrom <%s> . } union "
	"{ ?x a ub:FullProfessor . ?x ub:mastersDegreeFrom <%s> . } union "
	"{ ?x a ub:AssistantProfessor . ?x ub:mastersDegreeFrom <%s> . } union "
	"{ ?x a ub:Lecturer . ?x ub:mastersDegreeFrom <%s> . } union "
	"{ ?x a ub:UndergraduateStudent . ?x ub:mastersDegreeFrom <%s> . } union "
	"{ ?x a ub:GraduateStudent . ?x ub:mastersDegreeFrom <%s> . } union "
	"{ ?x a ub:TeachingAssistant . ?x ub:mastersDegreeFrom <%s> . } union "
	"{ ?x a ub:ResearchAssistant . ?x ub:mastersDegreeFrom <%s> . } union "
	"{ ?x a ub:AssociateProfessor . ?x ub:undergraduateDegreeFrom <%s> . } union "
	"{ ?x a ub:FullProfessor . ?x ub:undergraduateDegreeFrom <%s> . } union "
	"{ ?x a ub:AssistantProfessor . ?x ub:undergraduateDegreeFrom <%s> . } union "
	"{ ?x a ub:Lecturer . ?x ub:undergraduateDegreeFrom <%s> . } union "
	"{ ?x a ub:UndergraduateStudent . ?x ub:undergraduateDegreeFrom <%s> . } union "
	"{ ?x a ub:GraduateStudent . ?x ub:undergraduateDegreeFrom <%s> . } union "
	"{ ?x a ub:TeachingAssistant . ?x ub:undergraduateDegreeFrom <%s> . } union "
	"{ ?x a ub:ResearchAssistant . ?x ub:undergraduateDegreeFrom <%s> . } } ",
    &get_University },

  /* Q14 */
  {1, "{ ?x a ub:UndergraduateStudent . ?x ub:memberOf ?z . ?z ub:subOrganizationOf <%s> . }", &get_University }

};



int
LUBM_Execute(char * qr)
{

  SQLCHAR *      Statement =  (SQLCHAR *) qr;
  /*   Execute the statement. */
  if (SQLExecDirect(hstmt, Statement, SQL_NTS) != SQL_SUCCESS)
    {
      LUBM_Errors ("LUBM_Execute");
      return -1;
    }
  return 0;
}

int
LUBM_CheckIRI (char * iri)
{
  int rc;
  SDWORD colIndicator;
  char fetchBuffer [1000];
  if (SQLPrepare (hstmt, (UCHAR *)"select iri_to_id (?, 0)", SQL_NTS) != SQL_SUCCESS)
    {
      LUBM_Errors ("LUBM_CheckIRI");
      exit (-1);
    }
   SQLSetParam (hstmt, 1, SQL_C_CHAR, SQL_CHAR, 0, 0, iri, NULL);
   SQLExecute (hstmt);
   rc = SQLFetch (hstmt);

   if (rc == SQL_NO_DATA_FOUND)
     return 0;

   if (rc != SQL_SUCCESS)
     {
       LUBM_Errors ("Fetch");
       return 0;
     }
   if (SQLGetData (hstmt, 1, SQL_CHAR, fetchBuffer,
	 sizeof (fetchBuffer), &colIndicator) != SQL_SUCCESS)
     {
       LUBM_Errors ("SQLGetData");
       return 0;
     }
   if (colIndicator == SQL_NULL_DATA)
     {
       return 0;
     }
   /*printf ("%s\n", fetchBuffer);*/
   return 1;
}


int disp_interval = 20 * 1000;

void LUBM_DoOne ()
{
  int i;
  char buf [10000], tmp [10000], id[512];


  for (i = 0; i < 14; i++)
    {
      qr_t qrt = (q_kind != 2 ? qrs[i] : uqrs[i]);
      rand_func func = qrt.func;
      char * txt = qrt.pattern;
      int n_pars = qrt.n_pars;
      if (1118 == i)
	continue;
      /*printf ("len=%d pars=%d\n", strlen (txt), n_pars);*/

      if (func)
	{
	  char * rand_str;
	  int tries = 0;
	  do
	    {
	      rand_str = (*func)(id);
              tries ++;
              if (tries > 100)
		break;
	    }
	  while (!LUBM_CheckIRI (rand_str));

	  if (n_pars == 1)
	    sprintf (tmp, txt, rand_str);
	  else if (n_pars == 2)
	    sprintf (tmp, txt, rand_str, rand_str);
	  else if (n_pars == 3)
	    sprintf (tmp, txt, rand_str, rand_str, rand_str);
	  else if (n_pars == 6)
	    sprintf (tmp, txt,
			rand_str, rand_str, rand_str,
			rand_str, rand_str, rand_str
			);
	  else if (n_pars == 9)
	    sprintf (tmp, txt,
			rand_str, rand_str, rand_str,
			rand_str, rand_str, rand_str,
			rand_str, rand_str, rand_str
			);
	  else if (n_pars == 24)
	    sprintf (tmp, txt,
			rand_str, rand_str, rand_str, rand_str,
			rand_str, rand_str, rand_str, rand_str,
			rand_str, rand_str, rand_str, rand_str,
			rand_str, rand_str, rand_str, rand_str,
			rand_str, rand_str, rand_str, rand_str,
			rand_str, rand_str, rand_str, rand_str
			);
	  else if (n_pars == 36)
	    sprintf (tmp, txt,
			rand_str, rand_str, rand_str, rand_str, rand_str, rand_str,
			rand_str, rand_str, rand_str, rand_str, rand_str, rand_str,
			rand_str, rand_str, rand_str, rand_str, rand_str, rand_str,
			rand_str, rand_str, rand_str, rand_str, rand_str, rand_str,
			rand_str, rand_str, rand_str, rand_str, rand_str, rand_str,
			rand_str, rand_str, rand_str, rand_str, rand_str, rand_str
			);
	  else
	    {
	      printf ("unhandled number of parameters");
	      exit (-1);
	    }
	}
      else
        sprintf (tmp, "%s", txt);


      if (print_result)
        printf ("Q#%d:", i+1);
      sprintf (buf, "sparql %s %s %s", q_kind == 1 ? inf_pref : "", 12 == i ? q_count_pref : q_pref, tmp);
      if (print_result > 1)
        printf ("%s\n", buf);

      ta_enter (&ta_exec);
      ta_enter (&(ta_qr[i]));
      if (LUBM_Execute (buf) != 0)
	{
	  LUBM_Errors ("LUBM_Excute");
	  return;
	}
      else if (LUBM_PrintResult () != 0)
	{
	  LUBM_Errors ("LUBM_PrintResult");
	  return;
	}
      ta_leave (&ta_exec);
      ta_leave (&(ta_qr[i]));
      if ((get_msec_count () - ta_exec.ta_init_time) > disp_interval)
	{
	  int j;
	  for (j = 0; j < 14; j++)
	    ta_print_out (stdout, &(ta_qr[j]));
	  printf ("-- %ld msec elapsed %f per/sec %ld times\n",
	      ta_exec.ta_total, (float)(ta_exec.ta_n_samples*1000)/ta_exec.ta_total, ta_exec.ta_n_samples);
	  ta_init (&ta_exec, "LUBM metric");
	}
    }
}

void
LUBM_DoAll ()
{
  int i, j;

  ta_init (&ta_exec, "LUBM metric");
  for (i = 0; i < 14; i++)
    {
      char *name;
      name = malloc (10);
      sprintf (name, "Q%d", i+1);
      ta_init (&(ta_qr[i]), name);
    }
  printf ("Started LUBM metric (%s)\n", q_kind == 1 ? "inference" : q_kind == 2 ? "union" : "materialized" );
  for (i = 0; i < n_times; i++)
    {
      if (print_result)
	printf ("===== Batch #%d\n", i);
      LUBM_DoOne ();
    }
  for (j = 0; j < 14; j++)
    ta_print_out (stdout, &(ta_qr[j]));
  printf ("-- %ld msec elapsed %f per/sec %ld times\n",
      ta_exec.ta_total, (float)(ta_exec.ta_n_samples*1000)/ta_exec.ta_total, ta_exec.ta_n_samples);
}

int
main (int argc, char *argv[])
{
  if (argc < 4)
    {
      printf ("Usage: %s [DSN] [user] [pass] [n-universities] [n-times] [inf|union|raw] [debug|debug-results]\n", argv[0]);
      exit (0);
    }
  if (argc > 4)
    max_univ = atoi (argv[4]);
  if (max_univ < 1)
    max_univ = 1;

  if (argc > 5)
    n_times = atoi (argv[5]);
  if (n_times < 0)
    n_times = 1;

  if (argc > 6)
    {
      if (!strcmp ("inf", argv[6]))
	q_kind = 1;
      else if (!strcmp ("union", argv[6]))
	q_kind = 2;
      else
	q_kind = 0;
    }
  if (argc > 7 && !strcmp ("debug", argv[7]))
    print_result = 1;
  if (argc > 7 && !strcmp ("debug-results", argv[7]))
    print_result = 2;


  if (LUBM_Connect (argv[1], argv[2], argv[3]) != 0)
    {
      LUBM_Errors ("LUBM_Connect");
      exit (-1);
    }
  LUBM_DoAll ();
  /* End the connection */
  LUBM_Disconnect ();
  return 0;
}


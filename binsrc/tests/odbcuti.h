/*
 *  odbcuti.c
 *
 *  $Id$
 *
 *  ODBC utility macros
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

extern int messages_off;
extern int quiet;

#define ERRORS_OFF messages_off = 1
#define ERRORS_ON messages_off = 0
#define QUIET quiet = 1
#define QUIET_OFF quiet = 0

#define IS_ERR(stmt, foo) \
  if (SQL_ERROR == foo) \
    { \
      print_error (SQL_NULL_HENV, SQL_NULL_HDBC, stmt); \
      if (!messages_off) \
	printf ("\n    Line %d, file %s\n", __LINE__, __FILE__); \
    }

#define IF_ERR(stmt, foo) \
  if (SQL_ERROR == foo) \
    { \
	  print_error (SQL_NULL_HENV, SQL_NULL_HDBC, stmt); \
	  if (!messages_off) \
	    printf ("\n    Line %d, file %s\n", __LINE__, __FILE__); \
    }

#define IF_ERR_GO(stmt, tag, foo) \
  if (SQL_ERROR == (foo)) \
    { \
      print_error (SQL_NULL_HENV, SQL_NULL_HDBC, stmt); \
      if (!messages_off) \
	printf ("\n    Line %d, file %s\n", __LINE__, __FILE__); \
      goto tag; \
    }

#define DECLARE_FOR_SQLERROR \
  int len; \
  char state[10]; \
  char message[1000]

#define IF_DEADLOCK_OR_ERR_GO(stmt, tag, foo, deadlocktag) \
  if (SQL_ERROR == (foo)) \
    { \
      while (SQL_NO_DATA_FOUND != SQLError (SQL_NULL_HENV, SQL_NULL_HDBC, stmt, (UCHAR *) state, NULL, \
	    (UCHAR *) & message, sizeof (message), (SWORD *) & len)) \
	if (0 == strcmp(state, "40001") || 0 == strncmp(state, "S1T00", 5)) \
	  goto deadlocktag; \
	else \
	  { \
	    if (0 == strncmp(state, "40003", 5) && (try_out_of_disk++) < TRYS) \
	       goto deadlocktag; \
	    if (!messages_off) \
	      printf ("\n*** Error trx %s: %s\n", state, message); \
	    if (!messages_off) \
	      printf ("\n    Line %d, file %s\n", __LINE__, __FILE__); \
	    goto tag; \
	  } \
    }


#define IF_CERR_GO(con, tag, foo) \
  if (SQL_ERROR == (foo)) \
    { \
      print_error (SQL_NULL_HENV, con, SQL_NULL_HSTMT); \
      if (!messages_off) \
	printf ("\n    Line %d, file %s\n", __LINE__, __FILE__); \
      goto tag; \
    }


#define IF_ERR_EXIT(stmt, foo) \
  if (SQL_ERROR == foo) \
    { \
      print_error (SQL_NULL_HENV, SQL_NULL_HDBC, stmt); \
      if (!messages_off) \
	printf ("\n    Line %d, file %s\n", __LINE__, __FILE__); \
      exit (1); \
    }

#define IF_CERR_EXIT(hdbc, foo) \
  if (SQL_ERROR == foo)  { \
    print_error (SQL_NULL_HENV, hdbc, SQL_NULL_HSTMT);  \
    if (!messages_off) \
     printf ("\n    Line %d, file %s\n", __LINE__, __FILE__); \
    exit (1); \
 }

#define IF_EERR_EXIT(henv, foo) \
  if (SQL_ERROR == foo)  { \
    print_error (henv, SQL_NULL_HDBC, SQL_NULL_HSTMT);  \
    if (!messages_off) \
      printf ("\n    Line %d, file %s\n", __LINE__, __FILE__); \
    exit (1); \
 }

#define BINDN(stmt, n, v) \
  SQLSetParam (stmt, n, SQL_C_LONG, SQL_INTEGER, 0,0, &v, NULL);


#define IBINDNTS(stmt, n, nts) \
  SQLSetParam (stmt, n, SQL_C_CHAR, SQL_CHAR, 0,0, nts, NULL)


#define IBINDNTS_ARRAY(stmt, n, nts) \
  SQLSetParam (stmt, n, SQL_C_CHAR, SQL_CHAR, sizeof (nts [0]), 0, nts, NULL)


#define IBINDSTR_ARRAY(stmt, n, nts, len_arr) \
  SQLSetParam (stmt, n, SQL_C_CHAR, SQL_CHAR, sizeof (nts [0]),0, &nts, &len_arr)


#define IBINDOID(stmt, n, str, len_arr) \
  SQLSetParam (stmt, n, SQL_C_OID, SQL_OID, sizeof (str [0]), 0, str, &len_arr)


#define IBINDL(stmt, n, l) \
  SQLSetParam (stmt, n, SQL_C_LONG, SQL_INTEGER, 0,0, &l, NULL)

#define IBINDF(stmt, n, l) \
  SQLSetParam (stmt, n, SQL_C_FLOAT, SQL_DOUBLE, 0, 0, &l, NULL)


#define OBINDFIX(stmt, n, buf, len) \
  SQLBindCol (stmt, n, SQL_C_CHAR, buf, sizeof (buf), &len)

#define OBINDL(stmt, n, buf, len) \
  SQLBindCol (stmt, n, SQL_C_LONG, &buf, sizeof (buf) , &len)


#define INIT_STMT(hdbc, st, text) \
  SQLAllocStmt (hdbc, &st); \
  IF_ERR_EXIT (st, SQLPrepare (st, (UCHAR *) text, SQL_NTS));


#define HIST_READ(st) \
  SQLSetStmtOption (st, SQL_CONCURRENCY, SQL_CONCUR_ROWVER)

#ifdef WIN32
# define SQLSetParam(stmt, ipar, ct, sqlt, prec, sc, ptr, len) \
  SQLBindParameter (stmt, ipar, SQL_PARAM_INPUT, ct, sqlt, prec, sc, ptr, prec, len)
#endif

void print_error (HSTMT e1, HSTMT e2, HSTMT e3);

extern SDWORD sql_nts;
extern SDWORD long_len;

/*
 *  blobs.c
 *
 *  $Id$
 *
 *  BLOBS test
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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
#include <memory.h>
#include <stdlib.h>
#include <string.h>

#ifdef UNIX
#include <sys/time.h>
#endif

#if defined (WIN32) | defined (WINDOWS)
#include <windows.h>
#endif

#include "odbcinc.h"
#include "timeacct.h"
#include "odbcuti.h"
#include "libutil.h"


int messages_off = 0;
int quiet = 0;

HDBC hdbc;
HENV henv;
HSTMT b_stmt;

long read_msecs;
long write_msecs;
long read_bytes;
long write_bytes;


char *dd_stmt_text =
" create table BLOBS (ROW_NO integer, B1 long varchar, B2 long varchar, B3 long varchar, B4 long varchar, "
"                 primary key (ROW_NO))";


void
check_dd ()
{
  HSTMT ck_stmt;

  SQLAllocStmt (hdbc, &ck_stmt);

  SQLTables (ck_stmt, (UCHAR *) "%", SQL_NTS, (UCHAR *) "%", SQL_NTS,
      (UCHAR *) "BLOBS", SQL_NTS, (UCHAR *) "TABLE", SQL_NTS);

  if (SQL_SUCCESS != SQLFetch (ck_stmt))
    {
      SQLFreeStmt (ck_stmt, SQL_CLOSE);
      SQLExecDirect (ck_stmt, (UCHAR *) dd_stmt_text, SQL_NTS);
    }
  SQLFreeStmt (ck_stmt, SQL_DROP);
  SQLTransact (henv, hdbc, SQL_COMMIT);
}


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


HSTMT ins_stmt;

void
del_blobs ()
{
  IF_ERR_EXIT (b_stmt,
      SQLExecDirect (b_stmt, (UCHAR *) "delete from BLOBS", SQL_NTS));
  IF_CERR_EXIT (hdbc,
      SQLTransact (henv, hdbc, SQL_COMMIT));
}


/* SDWORD long_len_array[] = { 4, 4, 4, 4, 4, 4 }; */
HSTMT upd_stmt;

void
ins_blob (long row_no, int n_blocks)
{
  long w_start;
  long rc, n_param, c;
  SDWORD l1 = SQL_DATA_AT_EXEC, l2 = SQL_DATA_AT_EXEC, l3 = SQL_DATA_AT_EXEC, l4 = SQL_DATA_AT_EXEC;
  static char temp[10000], btemp[10000];
  static char wtemp[10000];
  if (!ins_stmt)
    {
      int inx;
      INIT_STMT (hdbc, ins_stmt,
	  "insert into BLOBS (ROW_NO, B1, B2, B3, B4) values (?,?,?,?,?)");
      for (inx = 0; inx < sizeof (temp); inx++)
	{
	  wtemp [inx] = (char)(temp[inx] = 'a' + (inx % ('z' + 1 - 'a')));
	  temp[inx] = 'A' + (inx % ('Z' + 1 - 'A'));
	  if (inx < sizeof (temp) / 2)
	    {
	      btemp [inx * 2] = ((temp[inx] & 0xF0) >> 4) + ((((temp[inx] & 0xF0) >> 4) < 10) ? '0' : 'A' - 10);
	      btemp [inx * 2 + 1] = (temp[inx] & 0x0F) + (((temp[inx] & 0x0F) < 10) ? '0' : 'A' - 10);
	    }
	}
    }
  IBINDL (ins_stmt, 1, row_no);
  IS_ERR (ins_stmt,
      SQLSetParam (ins_stmt, 2, SQL_C_CHAR, SQL_LONGVARCHAR, 10, 0, (void *) 2L, &l1));
  IS_ERR (ins_stmt,
      SQLSetParam (ins_stmt, 3, SQL_C_CHAR, SQL_LONGVARCHAR, 10, 0, (void *) 3L, &l2));
  IS_ERR (ins_stmt,
      SQLSetParam (ins_stmt, 4, SQL_C_CHAR, SQL_LONGVARCHAR, 10, 0, (void *) 4L, &l3));
  IS_ERR (ins_stmt,
      SQLSetParam (ins_stmt, 5, SQL_C_CHAR, SQL_LONGVARCHAR, 10, 0, (void *) 5L, &l4));

  w_start = get_msec_count ();
  rc = SQLExecute (ins_stmt);
  IF_ERR_GO (ins_stmt, err, rc);
  rc = SQLParamData (ins_stmt, (void **) &n_param);
  while (rc == SQL_NEED_DATA)
    {
      switch (n_param)
	{
	case 2:
	  for (c = 0; c < n_blocks; c++)
	    {
	      IF_ERR_GO (ins_stmt, i_err,
		  SQLPutData (ins_stmt, temp, sizeof (temp)));
	      write_bytes += sizeof (temp);
	    }
	  break;

	case 3:
	  for (c = 0; c < n_blocks; c++)
	    {
	      IF_ERR_GO (ins_stmt, i_err,
		  SQLPutData (ins_stmt, temp, sizeof (temp) / 2));
	      write_bytes += sizeof (temp) / 2;
	    }
	  break;

	case 4:
	  for (c = 0; c < n_blocks; c++)
	    {
	      IF_ERR_GO (ins_stmt, i_err,
		  SQLPutData (ins_stmt, wtemp, sizeof (wtemp)));
	      write_bytes += sizeof (wtemp);
	    }
	  break;

	case 5:
	  for (c = 0; c < n_blocks; c++)
	    {
	      IF_ERR_GO (ins_stmt, i_err,
		  SQLPutData (ins_stmt, btemp, sizeof (btemp)));
	      write_bytes += sizeof (btemp);
	    }
	  break;

	default:
	  printf ("Bad param number asked by SQLParamData.");
	}

    i_err:
      rc = SQLParamData (ins_stmt, (void **) &n_param);
    }

  IF_ERR_GO (ins_stmt, err, rc);
  write_msecs += get_msec_count () - w_start;

err:;
}


void
copy_blob (long from, long to)
{
  long rc;
  static HSTMT cp_stmt;

  if (!cp_stmt)
    {
      INIT_STMT (hdbc, cp_stmt,
	  "insert into BLOBS (ROW_NO, B1, B2, B3, B4) "
	  "  select ?, B1, B2, B3, B4 from BLOBS where ROW_NO = ?");
    }
  IBINDL (cp_stmt, 1, to);
  IBINDL (cp_stmt, 2, from);

  rc = SQLExecute (cp_stmt);
  IF_ERR_GO (cp_stmt, err, rc);
  return;

err:;
}


void
upd_blob (long row_no, int n_blocks)
{
  long w_start = get_msec_count ();
  long rc, n_param, c;
  SDWORD l1 = SQL_DATA_AT_EXEC, l2 = SQL_DATA_AT_EXEC, l3 = SQL_DATA_AT_EXEC, l4 = SQL_DATA_AT_EXEC;
  static char temp[10000], btemp[10000];
  static char wtemp[10000];

  if (!upd_stmt)
    {
      int inx;
      INIT_STMT (hdbc, upd_stmt,
	  "update BLOBS set B1 = ?, B2 = ?, B3 = ?, B4 = ? where ROW_NO = ?");
      for (inx = 0; inx < sizeof (temp); inx++)
	{
	  wtemp [inx] = (char)(temp[inx] = 'A' + (inx % ('Z' - 'A')));
	  temp[inx] = 'a' + (inx % ('z' - 'a'));
	  if (inx < sizeof (temp) / 2)
	    {
	      btemp [inx * 2] = ((temp[inx] & 0xF0) >> 4) + ((((temp[inx] & 0xF0) >> 4) < 10) ? '0' : 'A' - 10);
	      btemp [inx * 2 + 1] = (temp[inx] & 0x0F) + (((temp[inx] & 0x0F) < 10) ? '0' : 'A' - 10);
	    }
	}
    }

  SQLSetParam (upd_stmt, 1, SQL_C_CHAR, SQL_LONGVARCHAR, 0, 0, (void *) 1L, &l1);
  SQLSetParam (upd_stmt, 2, SQL_C_CHAR, SQL_LONGVARCHAR, 0, 0, (void *) 2L, &l2);
  SQLSetParam (upd_stmt, 3, SQL_C_CHAR, SQL_LONGVARCHAR, 0, 0, (void *) 3L, &l3);
  SQLSetParam (upd_stmt, 4, SQL_C_CHAR, SQL_LONGVARCHAR, 0, 0, (void *) 4L, &l4);
  IBINDL (upd_stmt, 5, row_no);

  rc = SQLExecute (upd_stmt);
  IF_ERR_GO (upd_stmt, err, rc);
  rc = SQLParamData (upd_stmt, (void **) &n_param);
  while (rc == SQL_NEED_DATA)
    {
      switch (n_param)
	{
	case 1:
	  for (c = 0; c < n_blocks; c++)
	    {
	      SQLPutData (upd_stmt, temp, sizeof (temp));
	      write_bytes += sizeof (temp);
	    }
	  break;

	case 2:
	  for (c = 0; c < n_blocks; c++)
	    {
	      SQLPutData (upd_stmt, temp, sizeof (temp) / 2);
	      write_bytes += sizeof (temp) / 2;
	    }
	  break;

	case 3:
	  for (c = 0; c < n_blocks; c++)
	    {
	      SQLPutData (upd_stmt, wtemp, sizeof (wtemp));
	      write_bytes += sizeof (wtemp);
	    }
	  break;
	case 4:
	  for (c = 0; c < n_blocks; c++)
	    {
	      SQLPutData (upd_stmt, btemp, sizeof (btemp));
	      write_bytes += sizeof (btemp);
	    }
	  break;

	default:
	  printf ("Bad param number asked by SQLParamData in update.");
	}

      rc = SQLParamData (upd_stmt, (void **) &n_param);
    }

  IF_ERR_GO (upd_stmt, err, rc);
  write_msecs += get_msec_count () - w_start;

err:;
}


char res[9001];

int
check_blob_col (HSTMT stmt, int n_col, long expect_bytes, int ctype)
{
  RETCODE rc;
  long r_start = get_msec_count ();
  long total = 0;
  int get_batch = 2 * (ctype == SQL_C_WCHAR ? sizeof (wchar_t) : 1) + ((n_col == 4) ? 1 : 0);
  SDWORD init_len;
  SDWORD rec_len;

  for (;;)
    {
      rc = SQLGetData (stmt, n_col, ctype, res, get_batch, &rec_len);
      if (rc == SQL_ERROR)
	{
	  IF_ERR_GO (stmt, err, rc)
	err: return 0;
	}
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	break;
      if (rec_len == SQL_NULL_DATA)
	{
	  total = 0;
	  break;
	}
      if (SQL_C_CHAR == ctype)
	total += rec_len > get_batch - 1 ? get_batch - 1 : rec_len;
      else if (SQL_C_WCHAR == ctype)
	total += rec_len > get_batch - sizeof (wchar_t) ?
	    get_batch - sizeof (wchar_t) : rec_len;
      else
	total += rec_len > get_batch ? get_batch : rec_len;
      get_batch = (SQL_C_WCHAR == ctype ?
	  ((long)(sizeof (res) / sizeof (wchar_t))) * sizeof (wchar_t) :
	  sizeof (res));
    }

  if (ctype == SQL_C_WCHAR)
    {
      if (total % sizeof (wchar_t))
	printf ("*** Received bytes not at wchar_t boundary\n");
      if (total != expect_bytes)
	printf ("*** ");
      printf ("Received %ld bytes (%ld chars), wanted %ld (%ld chars).\n",
	    total,
	    total / sizeof (wchar_t),
	    expect_bytes,
	    expect_bytes / sizeof (wchar_t));
    }
  else
    {
      if (total != expect_bytes)
	printf ("*** Received %ld bytes, wanted %ld.\n", total, expect_bytes);
      else
	printf ("Received %ld bytes, wanted %ld.\n", total, expect_bytes);
    }

  read_msecs += get_msec_count () - r_start;
  read_bytes += total;

  SQLGetData (stmt, n_col, SQL_C_CHAR, res, 10, &init_len);
  SQLGetData (stmt, n_col, SQL_C_CHAR, res, 10, &init_len);

  return 1;
}


void
read_bound_blobs ()
{
  SDWORD len1, len2;
  char temp[100];
  char wtemp[100];
  HSTMT st;

  SQLAllocStmt (hdbc, &st);
  IF_ERR_GO (st, err,
      SQLExecDirect (st, (UCHAR *) "select B1, B2 from BLOBS", SQL_NTS));
  SQLBindCol (st, 1, SQL_C_CHAR, temp, sizeof (temp), &len1);
  SQLBindCol (st, 2, SQL_C_CHAR, wtemp, sizeof (wtemp), &len2);

  for (;;)
    {
      RETCODE rc = SQLFetch (st);
      if (rc == SQL_NO_DATA_FOUND)
	break;
      if (rc == SQL_ERROR)
	{
	  IF_ERR_GO (st, err, rc);
	}
      temp[10] = 0;
      wtemp[10] = 0;
      printf (" Bound blob len %ld  %s\n", (long) len1, temp);
      printf (" Bound nlob len %ld  %s\n", (long) len2, wtemp);
    }

err:
  SQLFreeStmt (st, SQL_DROP);
}


void
sel_blob (long row_no, int expect_n_blocks)
{
  RETCODE rc;
  static HSTMT sel_stmt;
  if (!sel_stmt)
    {
      INIT_STMT (hdbc, sel_stmt,
	  "select B1, B2, B3, B4 from BLOBS where ROW_NO = ?");
    }

  IBINDL (sel_stmt, 1, row_no);
  IF_ERR_GO (sel_stmt, err, SQLExecute (sel_stmt));
  rc = SQLFetch (sel_stmt);

  if (rc == SQL_SUCCESS || rc == SQL_SUCCESS_WITH_INFO)
    {
      check_blob_col (sel_stmt, 1, expect_n_blocks * 10000, SQL_C_CHAR);
      check_blob_col (sel_stmt, 2, expect_n_blocks * 5000, SQL_C_CHAR);
      check_blob_col (sel_stmt, 3, expect_n_blocks * 10000, SQL_C_CHAR);
      check_blob_col (sel_stmt, 4, expect_n_blocks * 10000, SQL_C_CHAR);
    }

err:;
  SQLFreeStmt (sel_stmt, SQL_CLOSE);
}


#define MAX_INIT_STATEMENTS 52
char *init_texts[MAX_INIT_STATEMENTS + 2] = { NULL };
int it_index = 0;


char *
is_init_SQL_statement (char **argv, int nth_arg)
{
  if (!strnicmp (argv[nth_arg], "INIT=", 5))
    {
      if (it_index < MAX_INIT_STATEMENTS)
	return (init_texts[it_index++] = (argv[nth_arg] + 5));

      printf ("%s: More than max. %d allowed initial statements (%s)\n",
	  argv[0], MAX_INIT_STATEMENTS, argv[nth_arg]);
      exit (1);
    }
  else
    {
      return NULL;
    }
}


void
tb_array ()
{
  int rc;
  long nth;
  UDWORD n_rows = 0;
  long dae[2] = {SQL_DATA_AT_EXEC, SQL_DATA_AT_EXEC};
  HSTMT stmt;

  SQLSetConnectOption (hdbc, SQL_AUTOCOMMIT, 1);
  INIT_STMT (hdbc, stmt, "insert into BLOBS (ROW_NO, B1, B2) values (?, ?, ?)");

  SQLParamOptions (stmt, 2, &n_rows);
  SQLSetParam (stmt, 1, SQL_C_CHAR, SQL_INTEGER, 4, 0, NULL, dae);
  SQLSetParam (stmt, 2, SQL_C_CHAR, SQL_LONGVARCHAR, 4, 0, (void*) 100L, dae);
  SQLSetParam (stmt, 3, SQL_C_CHAR, SQL_LONGVARCHAR, 4, 0, (void*) 200L, dae);

  rc = SQLExecute (stmt);
  if (rc == SQL_NEED_DATA)
    {
      rc = SQLParamData (stmt, (void **) &nth);
      while (rc == SQL_NEED_DATA)
	{
	  switch (nth)
	    {
	    case 0:
	      SQLPutData (stmt, (PTR) "4", SQL_NTS);
	      SQLPutData (stmt, (PTR) "0", 1);
	      break;
	    case 4:
	      SQLPutData (stmt, (PTR) "5", SQL_NTS);
	      SQLPutData (stmt, (PTR) "0", 1);
	      break;

	    case 100:
	      SQLPutData (stmt, (PTR) "B1, row 40", SQL_NTS);
	      break;
	    case 104:
	      SQLPutData (stmt, (PTR) "B1, row 50", SQL_NTS);
	      break;

	    case 200:
	      SQLPutData (stmt, (PTR) "B2, row 40", SQL_NTS);
	      break;

	    case 204:
	      SQLPutData (stmt, (PTR) "B2, row 50", SQL_NTS);
	      break;
	    }
	  rc = SQLParamData (stmt, (void **) &nth);
	}
      IF_ERR_GO (stmt, err, rc);
    }
 err: ;
}


int
main (int argc, char **argv)
{
  char *uid = "dba", *pwd = "dba";
  int opt_ind;


  if (argc < 2)
    {
      printf ("Usage. blobs host:port [user [password]] "
	  "[\"INIT=initial SQL statement\"] ...\n");
      exit (1);
    }

  opt_ind = 2;

back2:
  if (argc > opt_ind)
    {
      if (is_init_SQL_statement (argv, opt_ind))
	{
	  opt_ind++;
	  goto back2;
	}
      uid = argv[opt_ind];
      opt_ind++;
    }

back3:
  if (argc > opt_ind)
    {
      if (is_init_SQL_statement (argv, opt_ind))
	{
	  opt_ind++;
	  goto back3;
	}
      pwd = argv[opt_ind];
      opt_ind++;
    }

back_rest:
  if (argc > opt_ind) /* Init statement(s) given after username and password? */
    {
      if (is_init_SQL_statement (argv, opt_ind))
	{
	  opt_ind++;
	  goto back_rest;
	}
    }

  SQLAllocEnv (&henv);
  SQLAllocConnect (henv, &hdbc);

  if (SQL_ERROR == SQLConnect (hdbc, (UCHAR *) argv[1], SQL_NTS,
	  (UCHAR *) uid, SQL_NTS, (UCHAR *) pwd, SQL_NTS))
    {
      print_error (SQL_NULL_HENV, hdbc, SQL_NULL_HSTMT);
      exit (1);
    }

  SQLSetConnectOption (hdbc, SQL_AUTOCOMMIT, 0);

  if (it_index)	/* User gave one or more initialization statements? */
    {		/* e.g. "USE kublbm" with MS SQL server benchmark test */
      HSTMT init_stmt;
      int i = 0;
      SQLAllocStmt (hdbc, &init_stmt);
      while (i < it_index)
	{
	  IF_ERR (init_stmt,
	      SQLExecDirect (init_stmt, (UCHAR *) init_texts[i++], SQL_NTS));
	  SQLFreeStmt (init_stmt, SQL_CLOSE);
	}
      SQLFreeStmt (init_stmt, SQL_DROP);
    }

  check_dd ();


  /* tb_array (); */
  SQLAllocStmt (hdbc, &b_stmt);
/*
  sel_blob (1, 50);
  sel_blob (2, 50);
*/
  del_blobs ();
  ins_blob (1, 2);
  SQLTransact (henv, hdbc, SQL_COMMIT);
  sel_blob (1, 2);

  upd_blob (1, 14);
  sel_blob (1, 14);
  upd_blob (1, 5);
  sel_blob (1, 5);
  upd_blob (1, 50);
  sel_blob (1, 50);
  copy_blob (1, 2);
  sel_blob (2, 50);

  IF_CERR_GO (hdbc, err, SQLTransact (henv, hdbc, SQL_COMMIT));
  sel_blob (1, 50);
  sel_blob (2, 50);

  upd_blob (1, 12);
  sel_blob (1, 12);
  SQLTransact (henv, hdbc, SQL_ROLLBACK);
  sel_blob (1, 50);
  read_bound_blobs ();
  SQLSetConnectOption (hdbc, SQL_AUTOCOMMIT, 1);
  read_bound_blobs ();
  sel_blob (1, 50);

  printf ("\nRead: %ld KB/s, %ld b,  %ld msec\nWrite %ld KB/s, %ld b, %ld msec\n",
      ((read_bytes / read_msecs) * 1000) / 1024, read_bytes, read_msecs,
      ((write_bytes / write_msecs) * 1000) / 1024, write_bytes, write_msecs);


  exit (0);

err:;
  return 1;
}

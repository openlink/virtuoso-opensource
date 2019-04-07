/*
 *  $Id$
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

#ifdef UNIX
#include <sys/time.h>
#endif

#include "timeacct.h"
#include <stdio.h>
#include <string.h>
#include <memory.h>

#include "odbcinc.h"

#include "odbcuti.h"

#include <stdlib.h>



int messages_off = 0;
int quiet = 0;



HDBC hdbc;
HENV henv;
HSTMT read_stmt;
HSTMT del_stmt;

timer_account_t del_ta;

#ifdef UDBC

#define ROWSET_SZ 20

UDWORD crow = 1;

void del_3 (char * cursor_text, int n_rows)
{
  long row_no [ROWSET_SZ];
  long fi2 [ROWSET_SZ];
  UWORD rowstat [ROWSET_SZ];
  int rc;
  int ctr = 0;
  printf ("%s\n", cursor_text);
  ta_init (& del_ta, cursor_text);
  ta_enter (& del_ta);
  SQLSetStmtOption (read_stmt, SQL_BIND_TYPE, SQL_BIND_BY_COLUMN);
  SQLSetStmtOption (read_stmt, SQL_KEYSET_SIZE, 2);
  SQLSetStmtOption (read_stmt, SQL_CONCURRENCY, SQL_CONCUR_VALUES);
  SQLSetCursorName (read_stmt, "CR", SQL_NTS);
  IF_ERR_GO (read_stmt, end, SQLExecDirect (read_stmt, cursor_text, SQL_NTS));

  while (1) {
    rc = SQLExtendedFetch (read_stmt, SQL_FETCH_NEXT, 1, & crow, rowstat);
    if (rc == SQL_NO_DATA_FOUND) break;
    IF_ERR_GO (read_stmt, end, rc);
    if (ctr % 3 == 0) {
      IF_ERR_GO (read_stmt, end, SQLSetPos (read_stmt, 1, SQL_DELETE, SQL_LOCK_NO_CHANGE));

      printf ("Delete OK\n");
    }
    ctr ++;
    if (ctr > n_rows)
      break;
  }
 end:
  SQLFreeStmt (read_stmt, SQL_CLOSE);
  SQLTransact (SQL_NULL_HENV, hdbc, SQL_COMMIT);
  ta_leave (& del_ta);
  ta_print_out (stdout, & del_ta);
}


long account [ROWSET_SZ];
long branch [ROWSET_SZ];
UWORD rowstat [ROWSET_SZ];
SDWORD len_array [ROWSET_SZ];


void acct_3 (char * cursor_text, int n_rows)
{
  UDWORD crow = 1;
  int rc;
  int ctr = 0;
  printf ("%s\n", cursor_text);
  ta_init (& del_ta, cursor_text);
  ta_enter (& del_ta);
  IF_ERR_GO (read_stmt, end, SQLSetStmtOption (read_stmt, SQL_BIND_TYPE, SQL_BIND_BY_COLUMN));
  SQLSetStmtOption (read_stmt, SQL_KEYSET_SIZE, 100);
  SQLSetStmtOption (read_stmt, SQL_ROWSET_SIZE, 4);

  IF_ERR_GO (read_stmt, end, SQLSetStmtOption (read_stmt, SQL_CONCURRENCY, SQL_CONCUR_TIMESTAMP));
  SQLSetCursorName (read_stmt, "CR", SQL_NTS);
  IF_ERR_GO (read_stmt, end, SQLExecDirect (read_stmt, cursor_text, SQL_NTS));


  SQLBindCol (read_stmt, 1, SQL_C_LONG, (void*) & account, sizeof (long), len_array);
  SQLBindCol (read_stmt, 2, SQL_C_LONG, (void*) & branch [0], sizeof (long), len_array);

  while (1) {
    rc = SQLExtendedFetch (read_stmt, SQL_FETCH_NEXT, 2, & crow, rowstat);
    if (rc == SQL_NO_DATA_FOUND) break;
    IF_ERR_GO (read_stmt, end, rc);

    branch [0] = 900;
    printf ("Update OK.\n");
    IF_ERR_GO (read_stmt, end, SQLSetPos (read_stmt, 1, SQL_UPDATE, SQL_LOCK_NO_CHANGE));
    branch [0] = -1;
    IF_ERR_GO (read_stmt, end, SQLSetPos (read_stmt, 1, SQL_REFRESH, SQL_LOCK_NO_CHANGE));
    if (branch [0] == 900) printf ("Refresh OK\n");
    else printf ("*** Refreshed to %ld.\n", branch [0]);
    IF_ERR_GO (read_stmt, end, SQLSetPos (read_stmt, 2, SQL_DELETE, SQL_LOCK_NO_CHANGE));
    printf ("Delete OK.\n");
    account [0] += 2000;
    IF_ERR_GO (read_stmt, end, SQLSetPos (read_stmt, 1, SQL_ADD, SQL_LOCK_NO_CHANGE));
    printf ("Add OK.\n");
    IF_ERR_GO (read_stmt, end, SQLSetPos (read_stmt, 1, SQL_POSITION, SQL_LOCK_NO_CHANGE));
    printf ("Position OK.\n");
    /* IF_ERR_GO (del_stmt, end, SQLExecDirect (del_stmt, "DELETE FROM ACCOUNT WHERE CURRENT OF CR", SQL_NTS)); */


    ctr ++;
    if (ctr > n_rows)
      break;
  }
 end:
  SQLFreeStmt (read_stmt, SQL_CLOSE);
  SQLTransact (SQL_NULL_HENV, hdbc, SQL_COMMIT);
  ta_leave (& del_ta);
  ta_print_out (stdout, & del_ta);
}


#else

void del_3 (char * cursor_text, int n_rows)
{
  int ctr = 0;
  printf ("%s\n", cursor_text);
  ta_init (& del_ta, cursor_text);
  ta_enter (& del_ta);
  IF_ERR_GO (read_stmt, end, SQLExecDirect (read_stmt, cursor_text, SQL_NTS));
  while (SQL_SUCCESS == SQLFetch (read_stmt)) {
    if (ctr % 3 == 0) {
      IF_ERR_GO (del_stmt, end, SQLExecute (del_stmt));
    }
    ctr ++;
    if (ctr > n_rows)
      break;
  }
 end:
  SQLFreeStmt (read_stmt, SQL_CLOSE);
  SQLTransact (SQL_NULL_HENV, hdbc, SQL_COMMIT);
  ta_leave (& del_ta);
  ta_print_out (stdout, & del_ta);
}

#endif

















void print_error (HSTMT e1, HSTMT e2, HSTMT e3)
{
  int len;
  char state [10];
  char message [1000];
  SQLError (e1, e2, e3, (UCHAR *) state, NULL,
	    (UCHAR *) & message, sizeof (message),
	    (SWORD *) & len);
  printf ("\n*** Error %s: %s\n", state, message);
}


#define ROWSET_SZ 20

void close_test (int autocommit, int batch, int read_n, char * text)
{
  int inx;
  HSTMT stmt;

  printf ("close test %d %d %d %s\n", autocommit, batch, read_n, text);
  SQLSetConnectOption (hdbc, SQL_AUTOCOMMIT, autocommit);
  SQLAllocStmt (hdbc, & stmt);
  if (batch > 10)
    SQLSetStmtOption (stmt, SQL_ROWSET_SIZE, 3);
  IF_ERR_GO (stmt, err, SQLPrepare (stmt, text, SQL_NTS));
  IF_ERR_GO (stmt, err, SQLExecute (stmt));
  for (inx = 0; inx < read_n; inx++) {
    IF_ERR_GO (stmt, err, SQLFetch (stmt));
  }
  SQLFreeStmt (stmt, SQL_DROP);
 err: ;
  SQLTransact (SQL_NULL_HENV, hdbc, SQL_COMMIT);
}

void close_sync_test (int autocommit, int batch, int read_n, char * text)
{
  int inx, cnt;
  HSTMT stmt;

  printf ("close sync test  %s\n", text);
  SQLSetConnectOption (hdbc, SQL_AUTOCOMMIT, autocommit);
  SQLAllocStmt (hdbc, & stmt);
  for (cnt = 0; cnt < 10; cnt ++) {

    if (batch > 10)
      SQLSetStmtOption (stmt, SQL_ROWSET_SIZE, batch);
    IF_ERR_GO (stmt, err, SQLPrepare (stmt, text, SQL_NTS));
    IF_ERR_GO (stmt, err, SQLExecute (stmt));
    for (inx = 0; inx < read_n; inx++) {
      IF_ERR_GO (stmt, err, SQLFetch (stmt));
    }
    SQLFreeStmt (stmt, SQL_CLOSE);
  }
 err: ;
  SQLFreeStmt (stmt, SQL_DROP);
  SQLTransact (SQL_NULL_HENV, hdbc, SQL_COMMIT);
}



char * inc_text = "create procedure inc (inout x integer) { x := x + 1; }";


void in_out_test ()
{

  long io = 1, iol = 4;
  HSTMT stmt;
  SQLAllocStmt (hdbc, & stmt);
  IF_ERR_GO (stmt, err, SQLExecDirect (stmt, inc_text, SQL_NTS));

  SQLBindParameter (stmt, 1, SQL_PARAM_INPUT_OUTPUT, SQL_C_LONG, SQL_INTEGER,
		    4, 0, & io, 4, & iol);
  IF_ERR_GO (stmt, err, SQLExecDirect (stmt, "inc (?)", SQL_NTS));
  printf ("Input output param set to %ld\n", io);
err: ;
}






int main (int argc, char ** argv)
{
  char cr_ret [16];
  SWORD cr_ret_len;
  char* uid = "dba", * pwd = "dba";
  long  times;

  if (argc < 2) {
    printf ("Usage: cursor dsn delete-n [user] [password]\n");
    exit (1);
  }
  times  = atoi (argv [2]);

  if (argc > 3) {
	  uid = argv [3]; pwd = argv [4];
  }

  SQLAllocEnv (& henv);
  SQLAllocConnect (henv, &hdbc);

  if (SQL_ERROR == SQLConnect (hdbc, (UCHAR *) argv [1], SQL_NTS,
				 (UCHAR *) uid, SQL_NTS,
				 (UCHAR *) pwd, SQL_NTS)) {
    print_error (SQL_NULL_HENV, hdbc, SQL_NULL_HSTMT);
    exit (1);
  }
  in_out_test ();

  INIT_STMT (hdbc, read_stmt, "select ROW_NO from T1");
  INIT_STMT (hdbc, del_stmt, "delete from T1 where current of CR");
  SQLSetStmtOption (read_stmt, SQL_CURSOR_TYPE, SQL_CURSOR_KEYSET_DRIVEN);
  SQLSetCursorName (read_stmt, "CR", SQL_NTS);
  SQLGetCursorName (read_stmt, cr_ret, sizeof (cr_ret), & cr_ret_len);
  if (cr_ret_len != 2 || 0 != strcmp ("CR", cr_ret))
    printf ("*** bad cu name %s, %d chars returned.\n", cr_ret, cr_ret_len);



  SQLSetConnectOption (hdbc, SQL_AUTOCOMMIT, 0);



#ifdef UDBC
  acct_3 ("select account, branch  from account where account > 10", times);
  acct_3 ("select ROW_NO, FI2 from T1", times);

  SQLSetConnectOption (hdbc, SQL_AUTOCOMMIT, 1);

  acct_3 ("select account, branch  from account where account > 10", times);

  exit (0);
#else
  del_3 ("select FS1 from T1 where ROW_NO > 1", times);
  del_3 ("select FS1 from T1 where ROW_NO = 1111", times);
  del_3 ("select FS1 from T1 where STRING1 > '1'", times);
  del_3 ("select ROW_NO from T1 where STRING1 > '2'", times);
  del_3 ("select ROW_NO from T1", times);
#endif

  close_test (0, 1000, 0, "select * from T1 where FS1 like 'qqq'");
  close_test (1, 1000, 0, "select * from T1 where FS1 like 'qqq'");
  close_test (0, 1000, 10, "select * from T1");
  close_test (1, 1000, 1002, "select * from T1");
  close_test (0, 20, 20, "select * from T1");
  close_test (1, 20, 20, "select * from T1");

  close_sync_test (0, 100, 0, "select ROW_NO from T1 where FS1 like 'xx'");
  close_sync_test (1, 100, 0, "select ROW_NO from T1 where FS1 like 'xx'");
  close_sync_test (0, 1000, 1, "select ROW_NO from T1");
  close_sync_test (1, 1000, 1, "select ROW_NO from T1");
  return 0;
}


/*
 *  scroll.c
 *
 *  $Id$
 *
 *  scroll test
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

#ifdef UNIX
#include <sys/time.h>
#endif

#include "timeacct.h"
#include <stdio.h>
#include <string.h>
#include <memory.h>


#include "odbcinc.h"

#define SQL_ROW_SUCCESS 		0
#define SQL_ROW_DELETED 		1
#define SQL_ROW_UPDATED 		2
#define SQL_ROW_NOROW			3
#define SQL_ROW_ADDED			4
#define SQL_ROW_ERROR			5


#include "odbcuti.h"

#include <stdlib.h>


int messages_off = 0;
int quiet = 0;

#define ERRORS_OFF messages_off = 1
#define ERRORS_ON messages_off = 0
#define QUIET quiet = 1
#define QUIET_OFF quiet = 0




HDBC hdbc1;
HDBC hdbc2;
HENV henv;
HSTMT read_stmt;
HSTMT del_stmt;

timer_account_t del_ta;





typedef struct option_s
  {
    long	o_f;
    long	o_v;
  } option_t;

typedef struct t1_s {
  long		t1_row_no;
  float		t1_freal;
  double	t1_fdouble;
  TIMESTAMP_STRUCT	t1_time;
  char		t1_string1[10];
  char		t1_string2[10];
  char		t1_fs1[20];
  long		t1_fi2;
  SQLLEN	t1_row_no_len;
  SQLLEN	t1_string1_len;
  SQLLEN	t1_string2_len;
  SQLLEN	t1_fs1_len;
  SQLLEN	t1_fi2_len;
} t1_t;


typedef struct t1_window_s {
  HDBC		tw_hdbc;
  HSTMT		tw_stmt;
  t1_t *		tw_set;
  UWORD *		tw_stat;
  SQLULEN		tw_fill;
  int			tw_size;
  char *		tw_name;
  int			tw_rc;
  SQLLEN		tw_row_count;
} t1_window_t;


#define T1_BASE_TEXT "select ROW_NO, STRING1, STRING2, FS1, FI2 from T1"



void t1_print (t1_t * t1, UWORD st)
{
  char * stat = "??";
  switch (st)
    {
    case SQL_ROW_SUCCESS: stat = "OK"; break;
    case SQL_ROW_DELETED: stat = "DE"; break;
    case SQL_ROW_UPDATED: stat = "UP"; break;
    case SQL_ROW_ERROR: stat = "***"; break;
    case SQL_ROW_ADDED: stat = "AD"; break;
    case SQL_ROW_NOROW: stat = "NO"; break;
    }
  printf ("%s   %8ld %6s %6s %10s %6ld\n",
	  stat, t1->t1_row_no, t1->t1_string1, t1->t1_string2, t1->t1_fs1, t1->t1_fi2);
}

void t1_set_print (t1_t * set, UWORD * stats, int n)
{
  int inx;
  for (inx = 0; inx < n; inx++)
    {
      printf ("%3d  ", inx);
      t1_print (&set[inx], stats[inx]);
    }
}

void tw_print (t1_window_t * tw)
{
  printf ("TW %s  -- %ld / %d\n", tw->tw_name, tw->tw_fill, tw->tw_size);
  t1_set_print (tw->tw_set, tw->tw_stat, tw->tw_fill);
}


void t1_bind (HSTMT stmt, t1_t * t1)
{
  OBINDL (stmt, 1, t1->t1_row_no, t1->t1_row_no_len);
  OBINDFIX (stmt, 2, t1->t1_string1, t1->t1_string1_len);
  OBINDFIX (stmt, 3, t1->t1_string2, t1->t1_string2_len);
  OBINDFIX (stmt, 4, t1->t1_fs1, t1->t1_fs1_len);
  OBINDL (stmt, 5, t1->t1_fi2, t1->t1_fi2_len);

  IF_ERR_GO (stmt, end, SQLSetStmtOption (stmt, SQL_BIND_TYPE, sizeof (t1_t)));
 end: ;
}


void
t1_window (t1_window_t * tw, char * name,  HDBC hdbc, char * text,
	   int cr_type, long kssz, long rssz, int conc,
	   option_t * opts)
{
  option_t * o = opts;
  SQLAllocStmt (hdbc, &tw->tw_stmt);
  tw->tw_name = name;


  IF_ERR_GO (tw->tw_stmt, cerr, SQLSetStmtOption (tw->tw_stmt, SQL_CONCURRENCY, conc));
 cerr: ;
  IF_ERR_GO (tw->tw_stmt, err, SQLSetStmtOption (tw->tw_stmt, SQL_CURSOR_TYPE, cr_type));
  IF_ERR_GO (tw->tw_stmt, err, SQLSetStmtOption (tw->tw_stmt, SQL_KEYSET_SIZE, kssz));
  IF_ERR_GO (tw->tw_stmt, err, SQLSetStmtOption (tw->tw_stmt, SQL_ROWSET_SIZE, rssz));
  IF_ERR_GO (tw->tw_stmt, err, SQLSetCursorName (tw->tw_stmt, (SQLCHAR *) name, SQL_NTS));

  if (o)
    {
      while (o->o_f != -1)
	{
	  IF_ERR_GO (tw->tw_stmt, err, SQLSetStmtOption (tw->tw_stmt, o->o_f, o->o_v));
	  o++;
	}
    }

  IF_ERR_GO (tw->tw_stmt, err, (tw->tw_rc = SQLExecDirect (tw->tw_stmt, (SQLCHAR *) text, SQL_NTS)));

  tw->tw_set = (t1_t*) malloc (sizeof (t1_t) * (rssz + 1));
  tw->tw_stat = (UWORD*) malloc (sizeof (UWORD) * (rssz + 1));
  tw->tw_size = rssz;
  t1_bind (tw->tw_stmt, tw->tw_set);

  printf ("\n\nWindow %s = %s\n", tw->tw_name, text);
  tw->tw_hdbc = hdbc;
 err: ;
}

void
tw_unset (t1_window_t * tw)
{
  int inx;
  memset (tw->tw_set, 0, sizeof (t1_t) * tw->tw_size);
  for (inx = 0; inx < tw->tw_size; inx++)
    {
      tw->tw_set[inx].t1_row_no = -1;
      strcpy (tw->tw_set[inx].t1_string1, "---");
      strcpy (tw->tw_set[inx].t1_string2, "---");
    }
}


void tw_fetch (t1_window_t * tw, int ftype, int n)
{
  int rc;
  tw_unset (tw);
  /* rc = SQLExtendedFetch (tw->tw_stmt, ftype, n, &tw->tw_fill, tw->tw_stat); */
  rc = SQLExtendedFetch (tw->tw_stmt, ftype, n, &tw->tw_fill, tw->tw_stat);
  tw->tw_rc = rc;
  printf ("\nFetch %s %d %d = %d\n", tw->tw_name, ftype, n, rc);
  IF_ERR_GO (tw->tw_stmt, err, rc);
  tw_print (tw);
 err: ;
}


void
t1_update (t1_window_t * tw, long row_no, char * fs1)
{
  int rc;
  HSTMT upd;
  SQLAllocStmt (tw->tw_hdbc, &upd);
  IBINDNTS (upd, 1, fs1);
  IBINDL (upd, 2, row_no);
  rc = SQLExecDirect (upd, (SQLCHAR *) "update T1 set FS1 = ? where ROW_NO = ?", SQL_NTS);
  printf ("Update T1 set FS1 = %s where ROW_NO = %ld == %d\n", fs1, row_no, rc);
  IF_ERR_GO (upd, err, rc);
 err:
  SQLFreeStmt (upd, SQL_DROP);
}


void
t1_delete (t1_window_t * tw, long row_no)
{
  int rc;
  HSTMT upd;
  SQLAllocStmt (tw->tw_hdbc, &upd);
  IBINDL (upd, 1, row_no);
  rc = SQLExecDirect (upd, (SQLCHAR *) "delete from T1 where  ROW_NO = ?", SQL_NTS);
  printf ("delete from T1 where ROW_NO = %ld == %d\n",row_no, rc);
  IF_ERR_GO (upd, err, rc);
 err:
  SQLFreeStmt (upd, SQL_DROP);
}


#define CK_ROWCNT(stmt, n) \
  check_row_count (stmt, n, __FILE__, __LINE__)

void
check_row_count (HSTMT stmt, int n, char * file, int line)
{
  SQLLEN c = -1;
  SQLRowCount (stmt, &c);
  if (c != n)
    fprintf (stderr, "*** Bad row count %ld should be %d, %s:%d\n", c, n, file, line);
}


void
tw_set_pos_l (t1_window_t * tw, int nth, int op, int line)
{
  int rc;
#if 0
  rc = SQLSetPos (tw->tw_stmt, nth, SQL_POSITION, SQL_LOCK_NO_CHANGE);
  tw->tw_rc = rc;
  if (rc != SQL_SUCCESS)
    print_error (SQL_NULL_HENV, SQL_NULL_HDBC, tw->tw_stmt);
#endif
  rc = SQLSetPos (tw->tw_stmt, nth, op, SQL_LOCK_NO_CHANGE);
  tw->tw_rc = rc;
  if (!quiet)
    printf ("SQLSetPos %s %d %d = %d  line %d\n", tw->tw_name, nth, op, rc, line);
  if (rc != SQL_SUCCESS)
    print_error (SQL_NULL_HENV, SQL_NULL_HDBC, tw->tw_stmt);
  if (!quiet && nth != 0 && op == SQL_REFRESH
      && rc != SQL_ERROR)
    {
      printf ("      = ");
      t1_print (&tw->tw_set [nth-1], SQL_ROW_SUCCESS);
    }
}


#define tw_set_pos(q,w,e) tw_set_pos_l (q,w,e, __LINE__)

void
tw_exec (t1_window_t * tw, char * text)
{
  HSTMT stmt;
  SQLAllocStmt (tw->tw_hdbc, &stmt);
  tw->tw_rc = SQLExecDirect (stmt, (SQLCHAR *) text, SQL_NTS);
  SQLRowCount (stmt, &tw->tw_row_count);
  if (!quiet)
    printf ("Exec %s = %d, %ld rows\n", text, tw->tw_rc, tw->tw_row_count);
  IF_ERR_GO (stmt, err, tw->tw_rc);
 err:
  SQLFreeStmt (stmt, SQL_DROP);
}



void print_error (HSTMT e1, HSTMT e2, HSTMT e3)
{
  int len;
  char state [10];
  char message [1000];
  while (SQL_SUCCESS ==
	 SQLError (e1, e2, e3, (UCHAR *) state, NULL,
		   (UCHAR *) & message, sizeof (message),
		   (SWORD *) & len))
    if (!messages_off)
      printf ("*** Error %s: %s\n", state, message);
}


void
tw_close (t1_window_t * tw)
{
  SQLFreeStmt (tw->tw_stmt, SQL_DROP);
  tw->tw_stmt = SQL_NULL_HSTMT;
}


t1_window_t  tw1;
t1_window_t  tw2;

int enable_ck = 1;

#define T_CCOL(tw,i,f,v) \
  if (enable_ck && 0 != strncmp ((tw)->tw_set[i].f, v, strlen (v))) { \
    fprintf (stderr, "*** row %d: column != %s,  line %d\n", i, v, __LINE__); \
  }

#define T_ICOL(tw,i,f,v) \
  if (enable_ck && v !=  (tw)->tw_set[i].f) { \
    fprintf (stderr, "*** row %d: column (%ld) != %ld,  line %d\n", i, (long)(tw)->tw_set[i].f, (long)(v), __LINE__); \
  }


#define T_RC(tw, rc) \
  if (enable_ck && (tw)->tw_rc != rc) \
    fprintf (stderr, "*** Bad rc = %d, expected %d, line = %d\n", (tw)->tw_rc, rc, __LINE__)

#define T_ROWCNT(tw, c) \
  if (enable_ck && (tw)->tw_row_count != c) \
    fprintf (stderr, "*** Bad row count = %ld, expected %d, line = %d\n", (tw)->tw_row_count, c, __LINE__)


#define T_RSTAT(tw, i, stat) \
  if (enable_ck && (tw)->tw_stat[i] != stat) \
    fprintf (stderr, "*** Bad rstat = row %d = %d expected %d, line %d\n", \
       i, (tw)->tw_stat[i], stat, __LINE__);


char *
cr_type_name (int ct)
{
  switch (ct)
    {
    case SQL_CURSOR_FORWARD_ONLY: return "FWD";
    case SQL_CURSOR_KEYSET_DRIVEN: return "KEYSET";
    case SQL_CURSOR_DYNAMIC: return "DYNAMIC";
    case SQL_CURSOR_STATIC: return "STATIC";
    }
  return "***";
}


void
tsc_fwd_ext_fetch (int ctype, int ac, char * text)
{
  long count = 0;
  int rc = SQL_SUCCESS;
  long t1 = get_msec_count ();
  long last_row_no = 0;
  int do_testing = (strcmp(text, T1_BASE_TEXT) == 0);

  SQLSetConnectOption (hdbc1, SQL_AUTOCOMMIT, ac);
  t1_window (&tw1, "CR1", hdbc1, text, ctype, 0, 20, SQL_CONCUR_READ_ONLY, NULL);
  for (;;)
    {
      rc = SQLExtendedFetch (tw1.tw_stmt, SQL_FETCH_NEXT, 0, &tw1.tw_fill, tw1.tw_stat);
      if (rc == SQL_NO_DATA_FOUND || rc == SQL_ERROR)
	break;
      if (do_testing)
	{
	  if (count && tw1.tw_set[0].t1_row_no <= last_row_no)
	    fprintf (stderr, "*** Error : Overlapping rowsets in SQL_FETCH_NEXT : mode = %s\n", cr_type_name (ctype));
	  last_row_no = tw1.tw_set[tw1.tw_fill - 1].t1_row_no;
	}
      count += tw1.tw_fill;
    }
  if (SQL_ERROR == rc)
    print_error (SQL_NULL_HENV, SQL_NULL_HDBC, tw1.tw_stmt);
  tw_close (&tw1);
  printf ("SQLExtendedFetch: %ld msec, mode = %s, AC=%d, %ld row\n", get_msec_count () - t1, cr_type_name (ctype), ac, count);
}


void
tsc_fwd_fetch (int ctype, int ac, char * text)
{
  long count = 0;
  int rc;
  long t1 = get_msec_count ();
  SQLSetConnectOption (hdbc1, SQL_AUTOCOMMIT, ac);
  t1_window (&tw1, "CR1", hdbc1, text, ctype, 0, 20, SQL_CONCUR_READ_ONLY, NULL);
  for (;;)
    {
      rc = SQLFetch (tw1.tw_stmt);
      if (rc == SQL_NO_DATA_FOUND || rc == SQL_ERROR)
	break;
      count++;
    }
  if (SQL_ERROR == rc)
    print_error (SQL_NULL_HENV, SQL_NULL_HDBC, tw1.tw_stmt);
  tw_close (&tw1);
  printf ("SQLFetch: %ld msec, mode = %s, AC=%d,  %ld row\n", get_msec_count () - t1, cr_type_name (ctype), ac, count);
}


#define TW_DEFAULT_LEN(t1) \
  t1.t1_row_no_len = sizeof (long); \
  t1.t1_fi2_len = sizeof (long);  \
  t1.t1_string1_len = SQL_NTS; \
  t1.t1_string2_len = SQL_NTS; \
  t1.t1_fs1_len = SQL_NTS;



void
t1_lines (t1_window_t * tw, int l1, int l2, int batch_sz)
{
  char head [100];
  timer_account_t ins_ta;
  int ctype = SQL_CURSOR_DYNAMIC;
  int inx, n;
  int rno = l1;
  char * text = T1_BASE_TEXT;

  sprintf (head, "ins %d into T1", batch_sz);
  ta_init (&ins_ta, head);
  QUIET;
  t1_window (tw, "CR1", hdbc1, text, ctype, 00, batch_sz, SQL_CONCUR_READ_ONLY, NULL);
  tw_fetch (tw, SQL_FETCH_NEXT, 0);
  inx = 0;
  for (rno = l1; rno < l2; rno++)
    {
      tw->tw_set[inx].t1_row_no = inx;
      tw->tw_set[inx].t1_row_no = rno;
      sprintf (tw->tw_set[inx].t1_string1, "%d", rno % 300);
      sprintf (tw->tw_set[inx].t1_string2, "%d", 300 - (rno % 300));
      tw->tw_set[inx].t1_fi2 = 11;
      strcpy (tw->tw_set[inx].t1_fs1, "ins");
      TW_DEFAULT_LEN (tw->tw_set[inx]);
      inx++;
      if (inx == batch_sz)
	{
	  ta_enter (&ins_ta);
	  tw_set_pos (tw, 0, SQL_ADD);
	  ta_leave (&ins_ta);
	  inx = 0;
	}
    }

  for (n = 0; n < inx; n++)
    tw_set_pos (tw, n + 1, SQL_ADD);
  tw_close (tw);
  QUIET_OFF;
  ta_print_out (stdout, &ins_ta);
}


#define N_BMS 100

void
bm_expected (long * a_no, long * b_no)
{
  int fill = 0;
  int a, b;
  for (a = 100; fill < N_BMS; a++)
    {
      for (b = a - 2; b <= a + 2; b++)
	{
	  if (b < 100)
	    continue;
	  a_no[fill] = a;
	  b_no [fill] = b;
	  fill ++;
	}
    }
}

void
tsc_bm (int ctype, int kssz, int ac)
{
  long bm1;
  int bmfill = 0;
  int bm_no;
  int c;
  option_t opts [] = {{SQL_USE_BOOKMARKS, 1}, {-1, 0L}};
  long bm[N_BMS];
  long a_row_no[N_BMS + 10];
  long b_row_no[N_BMS + 10];

  char * t = "select A.ROW_NO, A.STRING1, B.STRING1, '--', B.ROW_NO "
    "from T1 A join T1 B on B.ROW_NO between A.ROW_NO - 2 and A.ROW_NO + 2 order by a.row_no, b.row_no";

  printf ("========== Bookmark Fetch  cr=%s, keyset=%d AC=%d\n", cr_type_name (ctype), kssz, ac);
  bm_expected (a_row_no, b_row_no);
  SQLSetConnectOption (hdbc1, SQL_AUTOCOMMIT, ac);
  t1_window (&tw1, "CR1", hdbc1, t, ctype, kssz, 3, SQL_CONCUR_READ_ONLY,
	     opts);
  tw_fetch (&tw1, SQL_FETCH_NEXT, 0);
  for (c = 0; c < N_BMS / 3; c++)
    {
      SQLGetStmtOption (tw1.tw_stmt, SQL_GET_BOOKMARK, &bm[bmfill]);
      SQLGetStmtOption (tw1.tw_stmt, SQL_GET_BOOKMARK, &bm1);
      if (bm1 != bm[bmfill])
	fprintf (stderr, "Two consecutive bookmarks different for same row\n");
      tw_set_pos (&tw1, 2, SQL_POSITION);
      SQLGetStmtOption (tw1.tw_stmt, SQL_GET_BOOKMARK, &bm[bmfill + 1]);
      tw_set_pos (&tw1, 3, SQL_POSITION);
      SQLGetStmtOption (tw1.tw_stmt, SQL_GET_BOOKMARK, &bm[bmfill + 2]);
      T_ICOL (&tw1, 0, t1_row_no, a_row_no[bmfill]);
      T_ICOL (&tw1, 0, t1_fi2, b_row_no[bmfill]);
      bmfill += 3;
      tw_fetch (&tw1, SQL_FETCH_NEXT, 0);
    }
  for (bm_no = 2; bm_no < bmfill; bm_no += 2)
    {
      tw_fetch (&tw1, SQL_FETCH_BOOKMARK, bm[bm_no]);
      T_ICOL (&tw1, 0, t1_row_no, a_row_no[bm_no]);
      T_ICOL (&tw1, 0, t1_fi2, b_row_no[bm_no]);
    }
  SQLTransact (SQL_NULL_HENV, tw1.tw_hdbc, SQL_COMMIT);
  tw_close (&tw1);
}

void
tsc_pos (int ctype,
	 char * text)
{
  int inx;
  printf ("========== Positioned ops test\n");
  SQLSetConnectOption (hdbc1, SQL_AUTOCOMMIT, 1);
  t1_window (&tw1, "CR1", hdbc1, text, ctype, 00, 5, SQL_CONCUR_READ_ONLY, NULL);
  tw_fetch (&tw1, SQL_FETCH_FIRST, 0);

  for (inx = 0; inx < 5; inx++)
    {
      tw1.tw_set[inx].t1_row_no = inx;
      tw1.tw_set[inx].t1_row_no = inx;
      sprintf (tw1.tw_set[inx].t1_string1, "%d", inx);
      sprintf (tw1.tw_set[inx].t1_string2, "%d", 300 - inx);
      tw1.tw_set[inx].t1_fi2 = 11;
      strcpy (tw1.tw_set[inx].t1_fs1, "ins");
      TW_DEFAULT_LEN (tw1.tw_set[inx]);
    }
  tw_set_pos (&tw1, 0, SQL_ADD);
  CK_ROWCNT (tw1.tw_stmt, 5);

  ERRORS_OFF;
  tw_set_pos (&tw1, 0, SQL_ADD);
  ERRORS_ON;
  CK_ROWCNT (tw1.tw_stmt, 0);
  T_RSTAT (&tw1, 2, SQL_ROW_ERROR);

  if (ctype != SQL_CURSOR_DYNAMIC)
    {
      /* need reopen to show added if cr not dynamic */
      tw_close (&tw1);
      t1_window (&tw1, "CR1", hdbc1, text, ctype, 00, 5, SQL_CONCUR_READ_ONLY, NULL);
    }
  tw_fetch (&tw1, SQL_FETCH_FIRST, 0);

  strcpy (tw1.tw_set[1].t1_fs1, "upd");
  tw_set_pos (&tw1, 2, SQL_UPDATE);
  CK_ROWCNT (tw1.tw_stmt, 1);
  memset (tw1.tw_set, 0, sizeof (t1_t) * 5);
  tw_set_pos (&tw1, 0, SQL_REFRESH);
  tw_print (&tw1);

  tw1.tw_set[3].t1_row_no = -2;
  tw1.tw_set[3].t1_row_no_len = SQL_IGNORE;
  strcpy (tw1.tw_set[3].t1_fs1, "NNN");
  tw1.tw_set[3].t1_fs1_len = SQL_NTS;
  tw_set_pos (&tw1, 4, SQL_UPDATE);
  tw_set_pos (&tw1, 4, SQL_REFRESH);
  T_CCOL (&tw1, 3, t1_fs1, "NNN");
  tw_print (&tw1);


  tw_set_pos (&tw1, 0, SQL_DELETE);
  CK_ROWCNT (tw1.tw_stmt, 5);
  tw_close (&tw1);
}






void
tsc_co (int ctype, int kssz, int ac)
{
  int rc;
  char * text = "select ROW_NO, STRING1, STRING2, FS1, FI2 from T1 where ROW_NO >= 3000";

  printf ("\n========== WHERE CURRENT OF Test, type = %d, AC=%d\n", ctype, ac);
  SQLSetConnectOption (hdbc1, SQL_AUTOCOMMIT, ac);
  t1_lines (&tw1, 3000, 4000, 5);
  t1_window (&tw1, "CR1", hdbc1, text, SQL_CURSOR_DYNAMIC, kssz, 5, SQL_CONCUR_READ_ONLY, NULL);
  tw_fetch (&tw1, SQL_FETCH_NEXT, 0);
  tw_set_pos (&tw1, 3, SQL_POSITION);
  tw_exec (&tw1, "update T1 set FS1 = 'UUU' where current of CR1");
  tw_set_pos (&tw1, 3, SQL_REFRESH);
  T_CCOL (&tw1, 2, t1_fs1, "UUU");
  tw_exec (&tw1, "delete from T1 where current of CR1");
  tw_set_pos (&tw1, 3, SQL_REFRESH);
  T_RSTAT (&tw1, 2, SQL_ROW_DELETED);
  ERRORS_OFF;
  tw_exec (&tw1, "delete from T1 where current of CR1");
  ERRORS_ON;
  T_RC (&tw1, SQL_ERROR);
  tw_close (&tw1);

  t1_window (&tw1, "CR1", hdbc1, text, ctype, 0, 5, SQL_CONCUR_READ_ONLY, NULL);
  QUIET;
  for (;;)
    {
      rc = SQLExtendedFetch (tw1.tw_stmt, SQL_FETCH_NEXT, 0, &tw1.tw_fill, tw1.tw_stat);
      if (SQL_NO_DATA_FOUND == rc)
	break;
      IF_ERR_GO (tw1.tw_stmt, err, rc);
      tw_set_pos (&tw1, 1, SQL_POSITION);
      tw_exec (&tw1, "delete from T1 where current of CR1");
      if (tw1.tw_fill < 5)
	{
	  ERRORS_OFF;
	  tw_set_pos (&tw1, 5, SQL_POSITION);
	  T_RC (&tw1, SQL_ERROR);
	  tw_exec (&tw1, "delete from T1 where current of CR1");
	  ERRORS_ON;
	}
      else
	{
	  tw_set_pos (&tw1, 5, SQL_POSITION);
	  tw_exec (&tw1, "delete from T1 where current of CR1");
	}
    }
 err:
  QUIET_OFF;
  tw_exec (&tw1, "delete from T1 where ROW_NO >= 3000");
  T_ROWCNT (&tw1, 600);  /* 1000 rows - 1+199*2+1 deletes */

  if (!ac)
    SQLTransact (SQL_NULL_HENV, tw1.tw_hdbc, SQL_ROLLBACK);
  tw_close (&tw1);
}

void
tsc_readtable (int ctype, int kssz, int commit_each, int del_bounds,
	    int n_windows, char * text)
{
  int inx;
  printf ("Scroll Fetch pb Test, commit = %d, del = %d\n", commit_each, del_bounds);
  SQLSetConnectOption (hdbc1, SQL_AUTOCOMMIT, 0);
  fprintf (stdout, "\n========== Scroll Fetch pb Test\n\n");
  t1_window (&tw1, "CR1", hdbc1, text, ctype, kssz, 5, SQL_CONCUR_READ_ONLY, NULL);
  tw_fetch (&tw1, SQL_FETCH_FIRST, 0);
  for (inx = 0; inx < n_windows; inx++)
    {
      if (commit_each)
    	IF_CERR_GO (tw1.tw_hdbc, err, SQLTransact (SQL_NULL_HENV, tw1.tw_hdbc, SQL_COMMIT));
      tw_fetch (&tw1, SQL_FETCH_NEXT, 0);
      T_ICOL (&tw1, 0, t1_row_no, (inx+1) * 5);
    }
err:
  SQLSetConnectOption (tw1.tw_hdbc, SQL_AUTOCOMMIT, 1);
  tw_close (&tw1);
}

void
tsc_scroll (int ctype, int kssz, int commit_each, int del_bounds,
	    int n_windows, char * text)
{
  int inx;
  printf ("Scroll Test, commit = %d, del = %d\n", commit_each, del_bounds);
  SQLSetConnectOption (hdbc1, SQL_AUTOCOMMIT, 0);
  fprintf (stdout, "\n========== Scroll Test\n\n");
  t1_window (&tw1, "CR1", hdbc1, text, ctype, kssz, 5, SQL_CONCUR_READ_ONLY, NULL);
  tw_fetch (&tw1, SQL_FETCH_LAST, 0);
  T_ICOL (&tw1, 4, t1_row_no, 1099);
  tw_fetch (&tw1, SQL_FETCH_ABSOLUTE, -3);
  T_ICOL (&tw1, 2, t1_row_no, 1099);
  T_RSTAT (&tw1, 3, SQL_ROW_NOROW);

  tw_fetch (&tw1, SQL_FETCH_FIRST, 0);
  T_ICOL (&tw1, 0, t1_row_no, 100);

  for (inx = 0; inx < n_windows; inx++)
    {
      if (commit_each)
	IF_CERR_GO (tw1.tw_hdbc, err, SQLTransact (SQL_NULL_HENV, tw1.tw_hdbc, SQL_COMMIT));
      tw_fetch (&tw1, SQL_FETCH_NEXT, 0);
      T_ICOL (&tw1, 0, t1_row_no, 100 + (inx + 1) * 5);
    }
  tw_fetch (&tw1, SQL_FETCH_RELATIVE, -1);
  T_ICOL (&tw1, 0, t1_row_no, 109);
  T_ICOL (&tw1, 4, t1_row_no, 113);
  for (inx = 0; inx < n_windows + 2; inx++)
    {
      if (commit_each)
	IF_CERR_GO (tw1.tw_hdbc, err, SQLTransact (SQL_NULL_HENV, tw1.tw_hdbc, SQL_COMMIT));
      tw_fetch (&tw1, SQL_FETCH_PRIOR, 0);
      if (inx > 2)
	{
	  T_RC (&tw1, SQL_NO_DATA_FOUND);
	  T_ICOL (&tw1, 0, t1_row_no, -1);
	}
    }
  tw_fetch (&tw1, SQL_FETCH_NEXT, 0);
  T_ICOL (&tw1, 0, t1_row_no, 100);
  T_ICOL (&tw1, 4, t1_row_no, 104);
 err:
  SQLSetConnectOption (tw1.tw_hdbc, SQL_AUTOCOMMIT, 1);
  tw_close (&tw1);
}


void
tsc_update (int ctype, int conc, char * text)
{
  printf ("Update Test\n");
  t1_window (&tw1, "CR1", hdbc1, text, ctype, 00, 5, conc, NULL);
  t1_window (&tw2, "CR2", hdbc2, text, ctype, 00, 5, conc, NULL);

  tw_fetch (&tw1, SQL_FETCH_NEXT, 0);
  tw_fetch (&tw2, SQL_FETCH_NEXT, 0);

  SQLTransact (SQL_NULL_HENV, hdbc1, SQL_COMMIT);

  /*  strcpy (tw2.tw_set[1].t1_fs1, "upd1");
   * *tw_set_pos (&tw2, 2, SQL_UPDATE);
   */
  t1_update (&tw2, tw1.tw_set[1].t1_row_no, "upd1");
  t1_delete (&tw2, tw1.tw_set[2].t1_row_no);
  tw_fetch (&tw1, SQL_FETCH_RELATIVE, 0);
  T_CCOL (&tw1, 1, t1_fs1, "upd1");
  SQLTransact (SQL_NULL_HENV, hdbc1, SQL_COMMIT);
  tw_fetch (&tw1, SQL_FETCH_RELATIVE, 0);
  SQLTransact (SQL_NULL_HENV, hdbc1, SQL_COMMIT);

  tw_set_pos (&tw2, 2, SQL_ADD);
  t1_delete (&tw2, tw2.tw_set[0].t1_row_no);

  tw_fetch (&tw1, SQL_FETCH_RELATIVE, 0);
  SQLTransact (SQL_NULL_HENV, hdbc1, SQL_COMMIT);

  tw_fetch (&tw1, SQL_FETCH_NEXT, 0);
  tw_fetch (&tw1, SQL_FETCH_NEXT, 0);
  tw_fetch (&tw1, SQL_FETCH_NEXT, 0);
  tw_fetch (&tw1, SQL_FETCH_PRIOR, 0);
  tw_fetch (&tw1, SQL_FETCH_PRIOR, 0);
  tw_fetch (&tw1, SQL_FETCH_PRIOR, 0);
}


void
tsc_fwd ()
{
  printf ("\n========== Forward read timing\n");
  tsc_fwd_ext_fetch (SQL_CURSOR_DYNAMIC, 1,
		     "select sum (ROW_NO), STRING1, max (STRING2), max (FS1), max (FI2) from T1 group by STRING1");
  tsc_fwd_ext_fetch (SQL_CURSOR_DYNAMIC, 0,
		     T1_BASE_TEXT
		     " union all select ROW_NO, STRING1, STRING2, FS1, FI2 from T1");

  tsc_fwd_fetch (SQL_CURSOR_FORWARD_ONLY, 0, T1_BASE_TEXT);
  tsc_fwd_fetch (SQL_CURSOR_KEYSET_DRIVEN, 0, T1_BASE_TEXT);
  tsc_fwd_fetch (SQL_CURSOR_DYNAMIC, 0, T1_BASE_TEXT);
  tsc_fwd_fetch (SQL_CURSOR_STATIC, 0, T1_BASE_TEXT);

  tsc_fwd_ext_fetch (SQL_CURSOR_FORWARD_ONLY, 1, T1_BASE_TEXT);
  tsc_fwd_ext_fetch (SQL_CURSOR_FORWARD_ONLY, 0, T1_BASE_TEXT);

  tsc_fwd_ext_fetch (SQL_CURSOR_KEYSET_DRIVEN, 1, T1_BASE_TEXT);
  tsc_fwd_ext_fetch (SQL_CURSOR_KEYSET_DRIVEN, 0, T1_BASE_TEXT);

  tsc_fwd_ext_fetch (SQL_CURSOR_DYNAMIC, 1, T1_BASE_TEXT);
  tsc_fwd_ext_fetch (SQL_CURSOR_DYNAMIC, 0, T1_BASE_TEXT);

  tsc_fwd_ext_fetch (SQL_CURSOR_STATIC, 1, T1_BASE_TEXT);
  tsc_fwd_ext_fetch (SQL_CURSOR_STATIC, 0, T1_BASE_TEXT);
}


void
tsc_values (int ctype)
{
  char * text = T1_BASE_TEXT;
  int conc = SQL_CONCUR_VALUES;

  printf ("\n========== Optimistic Concurrency, type %s\n", cr_type_name (ctype));
  SQLSetConnectOption (hdbc1, SQL_AUTOCOMMIT, 1);
  SQLSetConnectOption (hdbc2, SQL_AUTOCOMMIT, 1);
  t1_window (&tw1, "CR1", hdbc1, text, ctype, 0, 5, conc, NULL);
  t1_window (&tw2, "CR2", hdbc2, text, ctype, 0, 5, conc, NULL);

  tw_fetch (&tw1, SQL_FETCH_NEXT, 0);
  tw_fetch (&tw2, SQL_FETCH_NEXT, 0);

  strcpy (tw2.tw_set[1].t1_fs1, "VAL");
  tw_set_pos (&tw2, 2, SQL_UPDATE);

  strcpy (tw1.tw_set[1].t1_fs1, "BAD");
  ERRORS_OFF;
  tw_set_pos (&tw1, 0, SQL_UPDATE);
  T_RC (&tw1, SQL_SUCCESS_WITH_INFO);
  T_RSTAT (&tw1, 1, SQL_ROW_ERROR);
  ERRORS_ON;

  tw_set_pos (&tw1, 0, SQL_REFRESH);
  T_CCOL (&tw1, 1, t1_fs1, "VAL");

  strcpy (tw2.tw_set[1].t1_fs1, "VA2");
  tw_set_pos (&tw2, 2, SQL_UPDATE);
  T_RC (&tw2, SQL_SUCCESS);
  tw_set_pos (&tw2, 2, SQL_REFRESH);
  T_CCOL (&tw2, 1, t1_fs1, "VA2");

  tw_set_pos (&tw1, 2, SQL_REFRESH);
  T_CCOL (&tw1, 1, t1_fs1, "VA2");
  T_RSTAT (&tw1, 1, SQL_ROW_UPDATED);

  tw_close (&tw1);
  tw_close (&tw2);
}


option_t c_opts [] =
{ {SQL_QUERY_TIMEOUT, 3},
    {-1, 0L}};


void
tsc_lock (int ctype)
{
  char * text = T1_BASE_TEXT;

  printf ("\n========== Locking,Cursors, type %s\n", cr_type_name (ctype));
  SQLSetConnectOption (hdbc1, SQL_AUTOCOMMIT, 0);
  SQLSetConnectOption (hdbc2, SQL_AUTOCOMMIT, 0);

  t1_window (&tw1, "CR1", hdbc1, text, ctype, 0, 5, SQL_CONCUR_READ_ONLY, c_opts);
  t1_window (&tw2, "CR2", hdbc2, text, ctype, 0, 5, SQL_CONCUR_LOCK, c_opts);

  tw_fetch (&tw1, SQL_FETCH_NEXT, 0);
  ERRORS_OFF;
  tw_fetch (&tw2, SQL_FETCH_NEXT, 0);
  T_RC (&tw2, SQL_ERROR);
  ERRORS_ON;
  SQLTransact (SQL_NULL_HENV, hdbc1, SQL_ROLLBACK);
  SQLTransact (SQL_NULL_HENV, hdbc2, SQL_ROLLBACK);
  tw_close (&tw1);
  tw_close (&tw2);

  t1_window (&tw1, "CR1", hdbc1, text, ctype, 0, 5, SQL_CONCUR_READ_ONLY, c_opts);
  t1_window (&tw2, "CR2", hdbc2, text, ctype, 0, 5, SQL_CONCUR_READ_ONLY, c_opts);

  tw_fetch (&tw1, SQL_FETCH_NEXT, 0);
  tw_fetch (&tw2, SQL_FETCH_NEXT, 0);

  ERRORS_OFF;
  tw_set_pos (&tw2, 0, SQL_UPDATE);
  /* tw_set_pos (&tw2, 0, SQL_UPDATE);
   * deadlock. First a 2r1w deadlock.  Then the updating tx gets rb.  Then the next just waits for the read that is by the same thread.  Bad test. */
  T_RC (&tw2, SQL_ERROR);
  ERRORS_ON;

  tw_close (&tw1);
  tw_close (&tw2);

  SQLTransact (SQL_NULL_HENV, hdbc1, SQL_ROLLBACK);
  SQLTransact (SQL_NULL_HENV, hdbc2, SQL_ROLLBACK);
  SQLSetConnectOption (hdbc1, SQL_AUTOCOMMIT, 1);
  SQLSetConnectOption (hdbc2, SQL_AUTOCOMMIT, 1);
}


void
t1_init ()
{
  SQLSetConnectOption (hdbc1, SQL_AUTOCOMMIT, 1);
  tw1.tw_hdbc = hdbc1;
  tw_exec (&tw1, "delete from T1");
   t1_lines (&tw1, 100, 1100, 100);
}


void
tsc_commit_cursor (t1_window_t * tw, int ctype, int commit)
{
  long count = 0;
  int rc = SQL_SUCCESS;
  long last_row_no = 0;

  printf ("STARTED: %s on open autocommit %s cursor\n",
      commit == SQL_COMMIT ? "commit" : "rollback", cr_type_name (ctype));
  SQLSetConnectOption (tw->tw_hdbc, SQL_AUTOCOMMIT, 1);
  t1_window (tw, "CR1", tw->tw_hdbc, T1_BASE_TEXT, ctype, 0, 20, SQL_CONCUR_READ_ONLY, NULL);
  for (count = 0; count < tw->tw_fill * 2; count += tw->tw_fill)
    {
      rc = SQLExtendedFetch (tw->tw_stmt, SQL_FETCH_NEXT, 0, &tw->tw_fill, tw->tw_stat);
      if (rc == SQL_NO_DATA_FOUND || rc == SQL_ERROR)
	break;

      if (count && tw->tw_set[0].t1_row_no <= last_row_no)
	fprintf (stderr,
	    "*** Error : Overlapping rowsets in SQL_FETCH_NEXT : mode = %s\n",
	    cr_type_name (ctype));
      last_row_no = tw->tw_set[tw->tw_fill - 1].t1_row_no;

      if (!count)
	{
	  printf ("SQLTransact (%s) on open autocommit %s cursor\n",
	       commit == SQL_COMMIT ? "commit" : "rollback", cr_type_name (ctype));
	  rc = SQLTransact (SQL_NULL_HENV, tw->tw_hdbc, commit);
	  if (rc == SQL_ERROR)
	    break;
	}
    }
  if (SQL_ERROR == rc)
    print_error (SQL_NULL_HENV, SQL_NULL_HDBC, tw->tw_stmt);
  tw_close (tw);
  printf ("DONE: %s on open autocommit %s cursor\n\n",
      commit == SQL_COMMIT ? "commit" : "rollback", cr_type_name (ctype));
}


int
main (int argc, char ** argv)
{
  char* uid = "dba", * pwd = "dba";

  if (argc < 2) {
    printf ("Usage: scroll dsn delete-n [user] [password]\n");
    exit (1);
  }

  if (argc > 2) {
    uid = argv [3];
    pwd = argv [4];
  }

  SQLAllocEnv (& henv);
  SQLAllocConnect (henv, &hdbc1);
  SQLAllocConnect (henv, &hdbc2);

  if (SQL_ERROR == SQLConnect (hdbc1, (UCHAR *) argv [1], SQL_NTS,
			       (UCHAR *) uid, SQL_NTS,
			       (UCHAR *) pwd, SQL_NTS)) {
    print_error (SQL_NULL_HENV, hdbc1, SQL_NULL_HSTMT);
    exit (1);
  }
  if (SQL_ERROR == SQLConnect (hdbc2, (UCHAR *) argv [1], SQL_NTS,
			       (UCHAR *) uid, SQL_NTS,
			       (UCHAR *) pwd, SQL_NTS)) {
    print_error (SQL_NULL_HENV, hdbc2, SQL_NULL_HSTMT);
    exit (1);
  }

  t1_init ();

  tsc_lock (SQL_CURSOR_DYNAMIC);

  tsc_bm (SQL_CURSOR_STATIC, 0, 1);
  tsc_bm (SQL_CURSOR_KEYSET_DRIVEN, 5, 1);
  tsc_bm (SQL_CURSOR_KEYSET_DRIVEN, 0, 1);
  tsc_bm (SQL_CURSOR_DYNAMIC, 0, 1);

  tsc_values (SQL_CURSOR_DYNAMIC);
  tsc_values (SQL_CURSOR_KEYSET_DRIVEN);

  tsc_pos (SQL_CURSOR_KEYSET_DRIVEN, T1_BASE_TEXT);
  tsc_pos (SQL_CURSOR_DYNAMIC, T1_BASE_TEXT);

#if 0
  tsc_co (SQL_CURSOR_DYNAMIC, 0, SQL_AUTOCOMMIT_ON);
  tsc_co (SQL_CURSOR_DYNAMIC, 0, 0);
  tsc_co (SQL_CURSOR_FORWARD_ONLY, 0, 0);
#endif

  tsc_fwd ();

  tsc_scroll (SQL_CURSOR_STATIC, 0, 1, 0, 2,
	      T1_BASE_TEXT);
  tsc_scroll (SQL_CURSOR_DYNAMIC, 0, 1, 0, 2,
	      T1_BASE_TEXT);
  tsc_scroll (SQL_CURSOR_DYNAMIC, 0, 0, 0, 2,
	      T1_BASE_TEXT);


  tsc_scroll (SQL_CURSOR_KEYSET_DRIVEN, 7, 1, 0, 2,
	      T1_BASE_TEXT);
  tsc_scroll (SQL_CURSOR_KEYSET_DRIVEN, 5, 1, 0, 2,
	      T1_BASE_TEXT);
  tsc_scroll (SQL_CURSOR_KEYSET_DRIVEN, 2000, 1, 0, 2,
	      T1_BASE_TEXT);

  tw_exec (&tw1, "delete from T1");
  t1_lines (&tw1, 0, 1100, 100);
  tsc_readtable (SQL_CURSOR_STATIC,0,1,0,2,T1_BASE_TEXT);
  tsc_readtable (SQL_CURSOR_DYNAMIC,0,1,0,2,T1_BASE_TEXT);


/*
  tsc_update (SQL_CURSOR_KEYSET_DRIVEN, SQL_CONCUR_VALUES,
	      T1_BASE_TEXT);
  */

  tsc_commit_cursor (&tw1, SQL_CURSOR_FORWARD_ONLY, SQL_COMMIT);
  tsc_commit_cursor (&tw2, SQL_CURSOR_FORWARD_ONLY, SQL_ROLLBACK);
  tsc_commit_cursor (&tw1, SQL_CURSOR_STATIC,  SQL_COMMIT);
  tsc_commit_cursor (&tw1, SQL_CURSOR_STATIC,  SQL_ROLLBACK);
  tsc_commit_cursor (&tw1, SQL_CURSOR_DYNAMIC, SQL_COMMIT);
  tsc_commit_cursor (&tw2, SQL_CURSOR_DYNAMIC, SQL_ROLLBACK);

  printf ("========== SCROLL TEST COMPLETE\n");

  SQLDisconnect (hdbc1);
  SQLDisconnect (hdbc2);
  SQLFreeConnect (hdbc1);
  SQLFreeConnect (hdbc2);

  return 0;
}

/*
 *  ins.c
 *
 *  $Id$
 *
 *  Insert test
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

#if defined (WIN32) | defined (WINDOWS) | defined (__WIN32__)
#define FD_SETSIZE 2048
#include <winsock2.h>
#include <windows.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <memory.h>

#ifdef UNIX
#include <sys/time.h>
#endif

#include "libutil.h"
#include "odbcinc.h"
#include "timeacct.h"
#include "butils.h"

/*
   Client 1.  Insert rows.
   Command line:  n_rows, from_no
 */

timer_account_t insert_times;
timer_account_t send_times;
timer_account_t real_times;


#define MAX_BATCH 100

typedef struct _parmsbm
  {
    int sp_fill;
    int sp_max_fill;
    HSTMT sp_stmt;
    SQLULEN sp_n_done;
    int sp_is_pending;
    long sp_row_no[MAX_BATCH];
    SQLLEN sp_row_no_len[MAX_BATCH];
    struct timeval sp_time[MAX_BATCH];
    SDWORD sp_time_len[MAX_BATCH];
    char sp_str1[MAX_BATCH][6];
    SQLLEN sp_str1_len[MAX_BATCH];
    char sp_str2[MAX_BATCH][6];
    SQLLEN sp_str2_len[MAX_BATCH];
  }
send_parms_t;


HENV env;
HDBC hdbc;
HENV henv;

char *dd_stmt_text_ts =
"create table T1 ( "
"     ROW_NO integer, TIME1 timestamp, STRING1 varchar (3), STRING2 varchar (3), "
"      FS1 varchar (4), FI2 integer, FI3 integer, FS4 varchar (13), FS5 varchar (16),  "
"      FI6 integer, FI7 integer, FREAL real, FDOUBLE double precision, FDEC decimal (30, 10) default 11.1111, FDATE date, "
"      primary key (ROW_NO)) "
"alter index T1 on T1 partition (ROW_NO int (0hexff00))";


char *dd_stmt_text_dt =
"create table T1 ( "
"     ROW_NO integer, TIME1 datetime, STRING1 varchar (3), STRING2 varchar (3), "
"      FS1 varchar (4), FI2 integer, FI3 integer, FS4 varchar (13), FS5 varchar (16),  "
"      FI6 integer, FI7 integer, FREAL real, FDOUBLE double precision, FDEC decimal (30, 10) default 11.1111, FDATE date, "
"      primary key (ROW_NO)) "
"alter index T1 on T1 partition (ROW_NO int (0hexff00))";

/* DBMS specific statements */

/*MS SQLServer DDL*/
char *dd_stmt_text_ms =
"create table T1 ( "
"     ROW_NO integer, TIME1 datetime null, STRING1 varchar (3) null, STRING2 varchar (3) null, "
"      FS1 varchar (4) null, FI2 integer null, FI3 integer null, FS4 varchar (13) null, FS5 varchar (16) null,  "
"      FI6 integer null, FI7 integer null, FREAL real null, FDOUBLE double precision null, "
"      FDEC decimal (28, 10) default 11.1111 null, FDATE datetime null, "
"      primary key (ROW_NO)) ";

/*Oracle DDL*/
char *dd_stmt_text_ora =
"create table T1 ( "
"     ROW_NO integer, TIME1 date, STRING1 varchar (3), STRING2 varchar (3), "
"      FS1 varchar (4), FI2 integer, FI3 integer, FS4 varchar (13), FS5 varchar (16),  "
"      FI6 integer, FI7 integer, FREAL real, FDOUBLE double precision, "
"      FDEC decimal (30, 10) default 11.1111, FDATE date, "
"      primary key (ROW_NO)) ";

char *dd_stmt_text;

char *dd_1 = "create index TIME1 on T1 (TIME1) partition (TIME1 varchar)";
char *dd_2 = "create index STR1 on T1 (STRING1) partition (STRING1 varchar)";
char *dd_3 = "create index STR2 on T1 (STRING2) partition (STRING2 varchar)";


char *insert_text_ts =
"insert into T1 (ROW_NO,  STRING1, STRING2, "
"                   FS1, FI2, FI3, FS4, FS5, FI6, FI7, FREAL, FDOUBLE, FDATE, FDEC)"
"      values (?, ?, ?, 'S1',  1111, 3333, 'FS4FS4FS4FS4',  'FS5FS5FS5FS5FS5', "
"              6666, 7777, 8.9, 9.9, {d '1999-5-1'}, 22.22 )";

char *insert_text_dt =
"insert into T1 (ROW_NO,  STRING1, STRING2, "
"                   FS1, FI2, FI3, FS4, FS5, FI6, FI7, FREAL, FDOUBLE, FDATE, TIME1, FDEC)"
"      values (?, ?, ?, 'S1',  1111, 3333, 'FS4FS4FS4FS4',  'FS5FS5FS5FS5FS5', "
"              6666, 7777, 8.9, 9.9, {d '1999-5-1'}, now(), 22.22)";

/* DBMS specific statements */

/*MS SQLServer DML*/
char *insert_text_ms =
"insert into T1 (ROW_NO,  STRING1, STRING2, "
"                   FS1, FI2, FI3, FS4, FS5, FI6, FI7, FREAL, FDOUBLE, FDATE, TIME1)"
"      values (?, ?, ?, 'S1',  1111, 3333, 'FS4FS4FS4FS4',  'FS5FS5FS5FS5FS5', "
"              6666, 7777, 8.9, 9.9, {d '1999-5-1'}, getdate())";

/*Oracle DML
  the {d 'yy-mm-dd'} is replaced with native function to_date as Oracle native driver
  do not supports this syntax
 */
char *insert_text_ora =
"insert into T1 (ROW_NO,  STRING1, STRING2, "
"                   FS1, FI2, FI3, FS4, FS5, FI6, FI7, FREAL, FDOUBLE, FDATE, TIME1)"
"      values (?, ?, ?, 'S1',  1111, 3333, 'FS4FS4FS4FS4',  'FS5FS5FS5FS5FS5', "
"              6666, 7777, 8.9, 9.9, to_date ('1999-5-1', 'YYYY-MM-DD'), sysdate)";

char *insert_text;

void
check_dd ()
{
  HSTMT ck_stmt;
  SQLAllocStmt (hdbc, &ck_stmt);

  SQLTables (ck_stmt, (UCHAR *) NULL, SQL_NTS, (UCHAR *) NULL, SQL_NTS,
      (UCHAR *) "T1", SQL_NTS, (UCHAR *) NULL, SQL_NTS);

  if (SQL_SUCCESS != SQLFetch (ck_stmt))
    {
      SQLFreeStmt (ck_stmt, SQL_CLOSE);
      IF_ERR_GO (ck_stmt, err,
	  SQLExecDirect (ck_stmt, (UCHAR *) dd_stmt_text, SQL_NTS));
      IF_ERR_GO (ck_stmt, err,
	  SQLExecDirect (ck_stmt, (UCHAR *) dd_1, SQL_NTS));
      IF_ERR_GO (ck_stmt, err,
	  SQLExecDirect (ck_stmt, (UCHAR *) dd_2, SQL_NTS));
      IF_ERR_GO (ck_stmt, err,
	  SQLExecDirect (ck_stmt, (UCHAR *) dd_3, SQL_NTS));
    }

err:
  SQLFreeStmt (ck_stmt, SQL_DROP);
  SQLTransact (henv, hdbc, SQL_COMMIT);
}


void
sp_flush (send_parms_t * sp)
{
  if (!sp->sp_stmt)
    {
      SQLAllocStmt (hdbc, &sp->sp_stmt);
      IS_ERR (sp->sp_stmt,
	  SQLPrepare (sp->sp_stmt, (UCHAR *) insert_text, SQL_NTS));
      /* SQLSetStmtOption (sp -> sp_stmt, SQL_ASYNC_ENABLE, 1); */
      SQLSetParam (sp->sp_stmt, 1, SQL_C_LONG, SQL_INTEGER,
	  0, 0, &sp->sp_row_no, &sp->sp_row_no_len[0]);
      SQLSetParam (sp->sp_stmt, 2, SQL_C_CHAR, SQL_VARCHAR,
	  6, 0, &sp->sp_str1, &sp->sp_str1_len[0]);
      SQLSetParam (sp->sp_stmt, 3, SQL_C_CHAR, SQL_VARCHAR,
	  6, 0, &sp->sp_str2, &sp->sp_str2_len[0]);
    }
#if 0
  if (sp->sp_is_pending)
    {
      ta_enter (&insert_times);
      /* IF_ERR_GO (sp -> sp_stmt, err,SQLSync (sp -> sp_stmt)); */
    err:
      ta_leave (&insert_times);
    }
#endif

  ta_enter (&send_times);
  SQLParamOptions (sp->sp_stmt,
      sp->sp_fill, (SQLULEN *) & sp->sp_n_done);

  SQLSetConnectOption (hdbc, SQL_AUTOCOMMIT, 1);
  if (sp->sp_fill > 0)
    {
      int sts;

      sts = SQLExecute (sp->sp_stmt);
      if (SQL_SUCCESS != sts)
        print_error (SQL_NULL_HENV, SQL_NULL_HDBC, sp->sp_stmt);
    }
  sp->sp_is_pending = 1;
  sp->sp_fill = 0;
  ta_leave (&send_times);
}


void
insert_one (long n, send_parms_t * sp)
{
  int fill = sp->sp_fill;
  long row_no = n;
  static struct timeval time;
  char s1[10];
  char s2[10];

  sprintf (s1, "%ld", n % 300);
  sprintf (s2, "%ld", 300 - (n % 300));

#ifdef NO_OS_TIME
  if (0 == time.tv_sec)
    gettimeofday (&time, NULL);
  TV_TO_STRING ((&time));
  time.tv_sec++;

#else
  gettimeofday (&time, NULL);
  TV_TO_STRING ((&time));
#endif

  sp->sp_row_no[fill] = row_no;
  sp->sp_row_no_len[fill] = 4;
  memcpy (&sp->sp_time[fill], &time, sizeof (time));
  sp->sp_time_len[fill] = sizeof (time);
  strcpy (sp->sp_str1[fill], s1);
  sp->sp_str1_len[fill] = strlen (s1);
  strcpy (sp->sp_str2[fill], s2);
  sp->sp_str2_len[fill] = strlen (s2);

  sp->sp_fill++;
  if (sp->sp_fill == sp->sp_max_fill)
    sp_flush (sp);
}


void
send_parm_init (send_parms_t * sp, int fill)
{
  sp->sp_fill = 0;
  sp->sp_max_fill = fill;
}


send_parms_t sps[10];


void
print_error (HSTMT e1, HSTMT e2, HSTMT e3)
{
  SWORD len;
  char state[10];
  char message[256];
  SQLError (e1, e2, e3, (UCHAR *) state, NULL,
      (UCHAR *) &message, sizeof (message), &len);
  printf ("\n*** Error %s: %s\n", state, message);
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
	{
	  return (init_texts[it_index++] = (argv[nth_arg] + 5));
	}
      else
	{
	  printf ("%s: More than max. %d allowed initial statements (%s)\n",
	      argv[0], MAX_INIT_STATEMENTS, argv[nth_arg]);
	  exit (1);
	}
    }
  return NULL;
}


int
main (int argc, char **argv)
{
  char *uid = "dba", *pwd = "dba";
  int rep_ctr = 0;
  int repn = 999;
  long n;
  long nrows;
  long from;
  int opt_ind;

  dd_stmt_text = dd_stmt_text_ts;
  insert_text = insert_text_ts;
  if (argc < 4)
    {
      printf (
	  "Usage: ins host:port count-of-rows first-row-no  [user [password [usedt]]] "
	  " [\"INIT=initial SQL statement\"] ...\n"
	  "   Create table T1 with 4 indices. Insert sequentially\n"
	  "   numbered rows starting at first-row-no.\n"
	  );
      exit (1);
    }

  nrows = atol (argv[2]);
  from = atol (argv[3]);

/* if (argc > 4) { uid = argv [4]; pwd = argv [5]; use_dt = argv[6] } */

  opt_ind = 4;

back_uid:
  if (argc > opt_ind)
    {
      if (is_init_SQL_statement (argv, opt_ind))
	{
	  opt_ind++;
	  goto back_uid;
	}
      uid = argv[opt_ind];
      opt_ind++;
    }

back_pwd:
  if (argc > opt_ind)
    {
      if (is_init_SQL_statement (argv, opt_ind))
	{
	  opt_ind++;
	  goto back_pwd;
	}
      pwd = argv[opt_ind];
      opt_ind++;
    }

back_usedt:
  if (argc > opt_ind)
    {
      if (is_init_SQL_statement (argv, opt_ind))
	{
	  opt_ind++;
	  goto back_usedt;
	}
      if (!strnicmp (argv[opt_ind], "usedt", 5))
	{
	  dd_stmt_text = dd_stmt_text_dt;
	  insert_text = insert_text_dt;
	}
      if (!strnicmp (argv[opt_ind], "usems", 5))
	{
	  dd_stmt_text = dd_stmt_text_ms;
	  insert_text = insert_text_ms;
	}
      if (!strnicmp (argv[opt_ind], "useora", 6))
	{
	  dd_stmt_text = dd_stmt_text_ora;
	  insert_text = insert_text_ora;
	}
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

#ifdef NO_OS_TIME
  ta_disable (&insert_times);
  ta_disable (&send_times);
#endif

  ta_init (&insert_times, "Times to insert");
  ta_init (&send_times, "Times to send");
  ta_init (&real_times, "Real Time");

  if (1)
    {
      send_parms_t *sp = &sps[0];
      send_parm_init (sp, 100);
      ta_enter (&real_times);
      for (n = 0; n < nrows; n++)
	{
	  if (rep_ctr == repn)
	    {

	      printf ("\nRecords %ld to %ld.\n", n - repn, n);
	      ta_print_out (stdout, &insert_times);
	      ta_init (&insert_times, "Insert times");
	      ta_print_out (stdout, &send_times);
	      ta_init (&send_times, "Send times");
	      ta_leave (&real_times);
	      ta_print_out (stdout, &real_times);
	      ta_enter (&real_times);
	      rep_ctr = 0;
	    }
	  else
	    {
	      rep_ctr++;
	    }
	  insert_one (n + from, sp);
	}
      sp_flush (sp);
      ta_print_out (stdout, &insert_times);
    }

  return 0;
}

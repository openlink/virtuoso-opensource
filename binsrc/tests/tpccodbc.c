/*
 *  tpccodbc.c
 *
 *  $Id$
 *
 *  TPC-C Transactions
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

#ifdef WIN32
# include <windows.h>
#include <sqlext.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <memory.h>
#ifdef UNIX
# include <sys/time.h>
# include <unistd.h>
#endif

#include "odbcinc.h"
#include "odbcuti.h"
#include "timeacct.h"

#include "tpcc.h"

int n_deadlocks;

#undef IF_DEADLOCK_OR_ERR_GO
#define IF_DEADLOCK_OR_ERR_GO(stmt, tag, foo, deadlocktag) \
  if (SQL_ERROR == (foo)) \
    { \
      while (SQL_NO_DATA_FOUND != SQLError (SQL_NULL_HENV, SQL_NULL_HDBC, stmt, (UCHAR *) state, NULL, \
					    (UCHAR *) & message, sizeof (message), (SWORD *) & len)) { \
	if (0 == strcmp(state, "40001") || 0 == strncmp(state, "S1T00", 5) || 0 == strncmp(state, "08C02", 5)) \
	  { n_deadlocks++; if (0 == n_deadlocks % 10) rnd_wait (); printf ("retry=%s %s\n", op, state);  goto deadlocktag;} \
	else if (0 == strncmp(state, "08", 2)) \
	    { printf ("disconnected\n"); error_exit (); }			\
	else  \
	  { \
	    if (0 == strncmp(state, "40003", 5) && (try_out_of_disk++) < TRYS) \
	       goto deadlocktag; \
	    if (!messages_off) \
	      printf ("\n*** Error trx %s: %s\n", state, message); \
	    if (!messages_off) \
	      printf ("\n op %s   Line %d, file %s\n", op, __LINE__, __FILE__); \
	    goto tag; \
	  }}	      \
    }




void
error_exit ()
{
  exit (-1);
}


void
rnd_wait ()
{
  long w = (rnd () & 0x7fffffff) % 1000000;
  struct timeval tv;
  tv.tv_sec = 0;
  tv.tv_usec = w;
  select (0, NULL, NULL, NULL, &tv);
}


#define OL_MAX 20
#define OL_PARS 3
#define NO_PARS 5

extern HDBC hdbc;
extern char dbms[40];
extern HSTMT misc_stmt;

extern SDWORD local_w_id;
extern char *new_order_text;
extern char *ostat_text;
extern char *slevel_text;
extern char *delivery_text;
extern char *payment_text;

extern timer_account_t new_order_ta;
extern timer_account_t payment_ta;
extern timer_account_t delivery_ta;
extern timer_account_t slevel_ta;
extern timer_account_t ostat_ta;

int try_out_of_disk = 0;
#define TRYS 10

void new_order ();
void payment ();
void ostat ();
void slevel ();
void delivery_1 (long w_id, long d_id);


typedef struct olsstruct
{
  int ol_no[OL_MAX];
  long ol_i_id[OL_MAX];
  long ol_qty[OL_MAX];
  long ol_supply_w_id[OL_MAX];
  char ol_data[OL_MAX][24];
}
olines_t;

int rnd_district ();
int make_supply_w_id ();
long NURand (int a, int x, int y);
void MakeNumberString (int sz, int sz2, char *str);


HSTMT new_order_stmt;
HSTMT payment_stmt;
HSTMT delivery_stmt;
HSTMT slevel_stmt;
HSTMT ostat_stmt;

void
login (HENV * henv_, HDBC * hdbc_, char *argv_, char *dbms_, int dbms_sz,
    HSTMT * misc_stmt, char *uid, char *pwd)
{
  SWORD ignore;
  SQLAllocEnv (henv_);
  SQLAllocConnect (*henv_, hdbc_);
  if (SQL_ERROR == SQLConnect (*hdbc_, (UCHAR *) argv_, SQL_NTS,
	  (UCHAR *) uid, SQL_NTS, (UCHAR *) pwd, SQL_NTS))
    {
      print_error (SQL_NULL_HENV, *hdbc_, SQL_NULL_HSTMT);
      exit (1);
    }
  SQLSetConnectOption (*hdbc_, SQL_AUTOCOMMIT, 0);
  SQLAllocStmt (*hdbc_, misc_stmt);

  SQLGetInfo (*hdbc_, SQL_DBMS_NAME, dbms_, dbms_sz, &ignore);

}

int
stmt_result_sets (HSTMT stmt, char * op)
{
  RETCODE rc;
  DECLARE_FOR_SQLERROR;
  /*
     To make procedures with equal # of parameters with Virtuoso & MS SQL Server,
     Oracle's procedures does'n return result.
   */
  if (strstr (dbms, "Oracle") || strstr (dbms, "SOAP"))
    return 0;
  do
    {
      do
	{
	  rc = SQLFetch (stmt);
	  IF_DEADLOCK_OR_ERR_GO (stmt, next_res, rc, deadlock_rs);
	next_res:
	  rc = rc;
	}
      while (rc != SQL_NO_DATA_FOUND && rc != SQL_ERROR);
      if (rc == SQL_ERROR)
	{
	  printf ("\n RC=%i   Line %d, file %s\n", rc, __LINE__, __FILE__);
	  print_error (SQL_NULL_HENV, SQL_NULL_HDBC, stmt);
	  return 0;
	}
      rc = SQLMoreResults (stmt);
    }
  while (rc != SQL_NO_DATA_FOUND && rc != SQL_ERROR);
  if (rc == SQL_ERROR)
    {
      print_error (SQL_NULL_HENV, SQL_NULL_HDBC, stmt);
      printf ("\n    Line %d, file %s\n", __LINE__, __FILE__);
    }

  SQLFreeStmt (stmt, SQL_CLOSE);
  return 0;
/*
   if (strstr (dbms, "SEL Server"))
   SQLFreeStmt (stmt, SQL_CLOSE);
 */
deadlock_rs:
  SQLFreeStmt (stmt, SQL_CLOSE);
  return 1;
}



void
new_order ()
{
  char * op = "new order";
  RETCODE rc;
  int n;
  static struct timeval tv;
  static olines_t ols;
  static int i;
  static long d_id;
  static long w_id;
  static long c_id;
  static char c_last[100];
  static long ol_cnt = 10;
  static long all_local = 1;
  DECLARE_FOR_SQLERROR;


  w_id = local_w_id;
  d_id = rnd_district ();
  c_id = random_c_id ();

  memset (c_last, 0, sizeof (c_last));
  gettimestamp (&tv);

  for (i = 0; i < 10; i++)
    {
      ols.ol_i_id[i] = random_i_id ();
      ols.ol_qty[i] = 5;
      ols.ol_supply_w_id[i] = make_supply_w_id ();
      ols.ol_no[i] = i + 1;
      MakeAlphaString (23, 23, ols.ol_data[i]);
    }

deadlock_no:

  if (!new_order_stmt)
    {
      INIT_STMT (hdbc, new_order_stmt, new_order_text);
      IBINDL (new_order_stmt, 1, w_id);
      IBINDL (new_order_stmt, 2, d_id);
      IBINDL (new_order_stmt, 3, c_id);
      IBINDL (new_order_stmt, 4, ol_cnt);
      IBINDL (new_order_stmt, 5, all_local);
      for (n = 0; n < 10; n++)
	{
	  IBINDL (new_order_stmt, NO_PARS + 1 + (n * OL_PARS),
	      ols.ol_i_id[n]);
	  IBINDL (new_order_stmt, NO_PARS + 2 + (n * OL_PARS),
	      ols.ol_supply_w_id[n]);
	  IBINDL (new_order_stmt, NO_PARS + 3 + (n * OL_PARS), ols.ol_qty[n]);
	}
    }
  SQLSetConnectOption (hdbc, SQL_AUTOCOMMIT, 1);
  ta_enter (&new_order_ta);
  rc = SQLExecute (new_order_stmt);
  IF_DEADLOCK_OR_ERR_GO (new_order_stmt, err, rc, deadlock_no);
  if (rc != SQL_NO_DATA_FOUND)
    if (stmt_result_sets (new_order_stmt, "new order"))
      goto deadlock_no;

err:
  ta_leave (&new_order_ta);

  return;
}

void
payment ()
{
  char * op = "payment";
  RETCODE rc;
  long w_id = local_w_id;
  long d_id = RandomNumber (1, DIST_PER_WARE);
  long c_id = random_c_id ();
  char c_last[50];
  float amount = 100.00;
  DECLARE_FOR_SQLERROR;

  strcpy (c_last, "");
deadlock_pay:
  if (!payment_stmt)
    {
      INIT_STMT (hdbc, payment_stmt, payment_text);
    }
  if (RandomNumber (0, 100) < 60)
    {
      c_id = 0;
      Lastname (RandomNumber (0, 999), c_last);
    }
  IBINDL (payment_stmt, 1, w_id);
  IBINDL (payment_stmt, 2, w_id);
  IBINDF (payment_stmt, 3, amount);
  IBINDL (payment_stmt, 4, d_id);
  IBINDL (payment_stmt, 5, d_id);
  IBINDL (payment_stmt, 6, c_id);
  IBINDNTS (payment_stmt, 7, c_last);

  ta_enter (&payment_ta);
  rc = SQLExecute (payment_stmt);
  IF_DEADLOCK_OR_ERR_GO (payment_stmt, err, rc, deadlock_pay);
  if (rc != SQL_NO_DATA_FOUND)
    if (stmt_result_sets (payment_stmt, op))
      goto deadlock_pay;

err:
  ta_leave (&payment_ta);
}

void
delivery_1 (long w_id, long d_id)
{
  char * op = "delivery";
  long carrier_id = 13;
  RETCODE rc;
  DECLARE_FOR_SQLERROR;
deadlock_del1:
  if (!delivery_stmt)
    {
      INIT_STMT (hdbc, delivery_stmt, delivery_text);
    }
  IBINDL (delivery_stmt, 1, w_id);
  IBINDL (delivery_stmt, 2, carrier_id);
  if (d_id)
    IBINDL (delivery_stmt, 3, d_id);
  rc = SQLExecute (delivery_stmt);
  SQLTransact (henv, hdbc, SQL_COMMIT);
  IF_DEADLOCK_OR_ERR_GO (delivery_stmt, err, rc, deadlock_del1);
  if (rc != SQL_NO_DATA_FOUND)
    if (stmt_result_sets (delivery_stmt, op))
      goto deadlock_del1;
err:;
}

void
slevel ()
{
  char * op = "slevel";
  RETCODE rc;
  long w_id = local_w_id;
  long d_id = RandomNumber (1, DIST_PER_WARE);
  long threshold = 20;
  long count;
  SDWORD count_len = sizeof (long);
  DECLARE_FOR_SQLERROR;

deadlock_sl:
  if (!slevel_stmt)
    {
      INIT_STMT (hdbc, slevel_stmt, slevel_text);
    }
  IBINDL (slevel_stmt, 1, w_id);
  IBINDL (slevel_stmt, 2, d_id);
  IBINDL (slevel_stmt, 3, threshold);
  SQLBindParameter (slevel_stmt, 4, SQL_PARAM_OUTPUT, SQL_C_LONG, SQL_INTEGER,
      0, 0, &count, sizeof (SDWORD), &count_len);

  SQLSetStmtOption (slevel_stmt, SQL_CONCURRENCY, SQL_CONCUR_ROWVER);
  ta_enter (&slevel_ta);
  rc = SQLExecute (slevel_stmt);
  IF_DEADLOCK_OR_ERR_GO (slevel_stmt, err, rc, deadlock_sl);
  if (rc != SQL_NO_DATA_FOUND)
    if (stmt_result_sets (slevel_stmt, "slevel"))
      goto deadlock_sl;

err:
  ta_leave (&slevel_ta);
}

void
ostat ()
{
  char * op = "ostat";
  RETCODE rc;
  long w_id = local_w_id;
  long d_id = RandomNumber (1, DIST_PER_WARE);
  long c_id = random_c_id ();
  char c_last[50];
  DECLARE_FOR_SQLERROR;
  memset (c_last, 0, sizeof (c_last));
deadlock_os:
  if (!ostat_stmt)
    {
      INIT_STMT (hdbc, ostat_stmt, ostat_text);
    }
  if (RandomNumber (0, 100) < 60)
    {
      c_id = 0;
      Lastname (RandomNumber (0, 999), c_last);
    }
  IBINDL (ostat_stmt, 1, w_id);
  IBINDL (ostat_stmt, 2, d_id);
  IBINDL (ostat_stmt, 3, c_id);
  IBINDNTS (ostat_stmt, 4, c_last);

  ta_enter (&ostat_ta);
  rc = SQLExecute (ostat_stmt);
  IF_DEADLOCK_OR_ERR_GO (ostat_stmt, err, rc, deadlock_os);
  if (rc != SQL_NO_DATA_FOUND)
    if (stmt_result_sets (ostat_stmt, op))
      goto deadlock_os;

err:
  ta_leave (&ostat_ta);
}

/* Only for OCI support */
void
logoff ()
{

}

/*
* Load tables
*/
void LoadItems ();
void LoadWare ();
void LoadCust ();
void LoadOrd ();
void Stock (long w_id_from, long w_id_to);
void District (long w_id);
void Customer (long, long);
void Orders (long d_id, long w_id);

extern char timestamp_array[BATCH_SIZE][20];
extern long count_ware;


/* Global Variables */
extern int i;
extern int option_debug;	/* 1 if generating debug output    */


#define CHECK_BATCH(stmt, fill) \
  if (fill >= BATCH_SIZE - 1) \
    { \
      SQLParamOptions (stmt, fill + 1, NULL); \
      IF_ERR_EXIT (stmt, SQLExecute (stmt)); \
      SQLTransact (henv, hdbc, SQL_COMMIT); \
      fill = 0; \
    } \
  else \
    fill++;

#define FLUSH_BATCH(stmt, fill) \
  if (fill > 0) \
    { \
      SQLParamOptions (stmt, fill, NULL); \
      IF_ERR_EXIT (stmt, SQLExecute (stmt)); \
      fill = 0; \
      SQLTransact (henv, hdbc, SQL_COMMIT); \
    }


extern SDWORD sql_timelen_array[BATCH_SIZE];


void
LoadItems ()
{
  static HSTMT item_stmt = SQL_NULL_HSTMT;
  long i;
  int fill = 0;
  long i_id_1;
  static long i_id[BATCH_SIZE];
  static char i_name[BATCH_SIZE][24];
  static float i_price[BATCH_SIZE];
  static char i_data[BATCH_SIZE][50];

  int idatasiz;
  static short orig[MAXITEMS];
  long pos;

  LOCAL_STMT (item_stmt,
      "insert into item (i_id, i_name, i_price, i_data) values (?, ?, ?, ?)");
  IBINDL (item_stmt, 1, i_id);
  IBINDNTS (item_stmt, 2, i_name);
  IBINDF (item_stmt, 3, i_price);
  IBINDNTS (item_stmt, 4, i_data);

#if defined (GUI)
  log (0, "Loading ITEM");
#else
  printf ("Loading ITEM\n");
#endif

  for (i = 0; i < MAXITEMS / 10; i++)
    orig[i] = 0;

#if 1
  for (i = 0; i < MAXITEMS / 10; i++)
    {
      do
	{
	  pos = RandomNumber (0L, MAXITEMS);
	}
      while (orig[pos]);
      orig[pos] = 1;
    }
#endif

#if defined (GUI)
  set_progress_max (MAXITEMS);
#endif
  for (i_id_1 = 1; i_id_1 <= MAXITEMS; i_id_1++)
    {

      /* Generate Item Data */
      i_id[fill] = i_id_1;
      MakeAlphaString (14, 24, i_name[fill]);
      i_price[fill] = ((float) RandomNumber (100L, 10000L)) / 100.0;
      idatasiz = MakeAlphaString (26, 50, i_data[fill]);
      if (orig[i_id_1])
	{
	  pos = RandomNumber (0L, idatasiz - 8);
	  i_data[fill][pos] = 'o';
	  i_data[fill][pos + 1] = 'r';
	  i_data[fill][pos + 2] = 'i';
	  i_data[fill][pos + 3] = 'g';
	  i_data[fill][pos + 4] = 'i';
	  i_data[fill][pos + 5] = 'n';
	  i_data[fill][pos + 6] = 'a';
	  i_data[fill][pos + 7] = 'l';
	}

      CHECK_BATCH (item_stmt, fill);

      if (!(i_id_1 % 100))
	{
#if defined (GUI)
	  progress (i_id_1);
#else
	  printf ("%6ld\r", i_id_1);
	  fflush (stdout);
#endif
	}
    }
#if defined (GUI)
  progress_done ();
#endif

  FLUSH_BATCH (item_stmt, fill);
  /* printf ("ITEM loaded.\n"); */

  return;
}


void
LoadWare ()
{
  long w_id;
  char w_name[10];
  char w_street_1[20];
  char w_street_2[20];
  char w_city[20];
  char w_state[2];
  char w_zip[9];
  float w_tax;
  float w_ytd;

  static HSTMT ware_stmt;

  LOCAL_STMT (ware_stmt,
      "insert into warehouse (w_id, w_name,"
      "    w_street_1, w_street_2, w_city, w_state, w_zip, w_tax, w_ytd)"
      "  values (?, ?, ?, ?, ?, ?, ?, ?, ?)");
  IBINDL (ware_stmt, 1, w_id);
  IBINDNTS (ware_stmt, 2, w_name);
  IBINDNTS (ware_stmt, 3, w_street_1);
  IBINDNTS (ware_stmt, 4, w_street_2);
  IBINDNTS (ware_stmt, 5, w_city);
  IBINDNTS (ware_stmt, 6, w_state);
  IBINDNTS (ware_stmt, 7, w_zip);
  IBINDF (ware_stmt, 8, w_tax);
  IBINDF (ware_stmt, 9, w_ytd);

#if defined (GUI)
  log (0, "Loading WAREHOUSE");
#else
  printf ("Loading WAREHOUSE\n");
#endif
  for (w_id = 1; w_id <= count_ware; w_id++)
    {
      /* Generate Warehouse Data */
      MakeAlphaString (6, 10, w_name);
      MakeAddress (w_street_1, w_street_2, w_city, w_state, w_zip);
      w_tax = ((float) RandomNumber (10L, 20L)) / 100.0;
      w_ytd = 3000000.00;

      if (option_debug)
#if defined (GUI)
	log (0, "WID = %ld, Name= %16s, Tax = %5.2f", w_id, w_name, w_tax);
#else
	printf ("WID = %ld, Name= %16s, Tax = %5.2f\n", w_id, w_name, w_tax);
#endif

      IF_ERR_EXIT (ware_stmt, SQLExecute (ware_stmt));

      /** Make Rows associated with Warehouse **/
      District (w_id);
    }
  Stock (1, count_ware);

  return;
}


void
LoadCust ()
{
  long w_id;
  long d_id;

  for (w_id = 1L; w_id <= count_ware; w_id++)
    for (d_id = 1L; d_id <= DIST_PER_WARE; d_id++)
      Customer (d_id, w_id);
  SQLTransact (henv, hdbc, SQL_COMMIT);

  return;
}


void
LoadOrd ()
{
  long w_id;
  /* float w_tax; */
  long d_id;
  /* float d_tax; */

  for (w_id = 1L; w_id <= count_ware; w_id++)
    for (d_id = 1L; d_id <= DIST_PER_WARE; d_id++)
      Orders (d_id, w_id);

  SQLTransact (henv, hdbc, SQL_COMMIT);
  return;
}


void
Stock (long w_id_from, long w_id_to)
{
  long w_id;
  long s_i_id_1;
  static long s_i_id[BATCH_SIZE];
  static long s_w_id[BATCH_SIZE];
  static long s_quantity[BATCH_SIZE];
  static char s_dist_01[BATCH_SIZE][24];
  static char s_dist_02[BATCH_SIZE][24];
  static char s_dist_03[BATCH_SIZE][24];
  static char s_dist_04[BATCH_SIZE][24];
  static char s_dist_05[BATCH_SIZE][24];
  static char s_dist_06[BATCH_SIZE][24];
  static char s_dist_07[BATCH_SIZE][24];
  static char s_dist_08[BATCH_SIZE][24];
  static char s_dist_09[BATCH_SIZE][24];
  static char s_dist_10[BATCH_SIZE][24];
  static char s_data[BATCH_SIZE][50];

  int fill = 0;
  int sdatasiz;
  long orig[MAXITEMS];
  long pos;
  int i;
  static HSTMT stock_stmt;

  LOCAL_STMT (stock_stmt,
      "insert into stock"
      "   (s_i_id, s_w_id, s_quantity,"
      "s_dist_01, s_dist_02, s_dist_03, s_dist_04, s_dist_05,"
      "s_dist_06, s_dist_07, s_dist_08, s_dist_09, s_dist_10,"
      "s_data, s_ytd, s_cnt_order, s_cnt_remote)"
      "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0,0,0)");

  IBINDL (stock_stmt, 1, s_i_id);
  IBINDL (stock_stmt, 2, s_w_id);
  IBINDL (stock_stmt, 3, s_quantity);

  IBINDNTS_ARRAY (stock_stmt, 4, s_dist_01);
  IBINDNTS_ARRAY (stock_stmt, 5, s_dist_02);
  IBINDNTS_ARRAY (stock_stmt, 6, s_dist_03);
  IBINDNTS_ARRAY (stock_stmt, 7, s_dist_04);
  IBINDNTS_ARRAY (stock_stmt, 8, s_dist_05);
  IBINDNTS_ARRAY (stock_stmt, 9, s_dist_06);
  IBINDNTS_ARRAY (stock_stmt, 10, s_dist_07);
  IBINDNTS_ARRAY (stock_stmt, 11, s_dist_08);
  IBINDNTS_ARRAY (stock_stmt, 12, s_dist_09);
  IBINDNTS_ARRAY (stock_stmt, 13, s_dist_10);
  IBINDNTS_ARRAY (stock_stmt, 14, s_data);

#if defined (GUI)
  log (0, "Loading STOCK for Wid=%ld-%ld", w_id_from, w_id_to);
  set_progress_max (MAXITEMS);
#else
  printf ("Loading STOCK for Wid=%ld-%ld\n", w_id_from, w_id_to);
#endif

  for (i = 0; i < MAXITEMS / 10; i++)
    orig[i] = 0;
  for (i = 0; i < MAXITEMS / 10; i++)
    {
      do
	{
	  pos = RandomNumber (0L, MAXITEMS);
	}
      while (orig[pos]);
      orig[pos] = 1;
    }

  for (s_i_id_1 = 1; s_i_id_1 <= MAXITEMS; s_i_id_1++)
    {
      for (w_id = w_id_from; w_id <= w_id_to; w_id++)
	{
	  if (s_i_id_1 % 100 == 0)
	    {
#if defined (GUI)
	      progress (s_i_id_1);
#else
	      printf ("%6ld\r", s_i_id_1);
	      fflush (stdout);
#endif
	    }
	  /* Generate Stock Data */
	  s_i_id[fill] = s_i_id_1;
	  s_w_id[fill] = w_id;
	  s_quantity[fill] = RandomNumber (10L, 100L);
	  MakeAlphaString (24, 24, s_dist_01[fill]);
	  MakeAlphaString (24, 24, s_dist_02[fill]);
	  MakeAlphaString (24, 24, s_dist_03[fill]);
	  MakeAlphaString (24, 24, s_dist_04[fill]);
	  MakeAlphaString (24, 24, s_dist_05[fill]);
	  MakeAlphaString (24, 24, s_dist_06[fill]);
	  MakeAlphaString (24, 24, s_dist_07[fill]);
	  MakeAlphaString (24, 24, s_dist_08[fill]);
	  MakeAlphaString (24, 24, s_dist_09[fill]);
	  MakeAlphaString (24, 24, s_dist_10[fill]);

	  sdatasiz = MakeAlphaString (26, 50, s_data[fill]);

	  if (orig[s_i_id_1])
	    {
	      pos = RandomNumber (0L, sdatasiz - 8);
	      s_data[fill][pos] = 'o';
	      s_data[fill][pos + 1] = 'r';
	      s_data[fill][pos + 2] = 'i';
	      s_data[fill][pos + 3] = 'g';
	      s_data[fill][pos + 4] = 'i';
	      s_data[fill][pos + 5] = 'n';
	      s_data[fill][pos + 6] = 'a';
	      s_data[fill][pos + 7] = 'l';
	    }

	  CHECK_BATCH (stock_stmt, fill);
	}
    }
#if defined (GUI)
  progress_done ();
#endif
  FLUSH_BATCH (stock_stmt, fill);

  /* printf ("STOCK loaded.\n"); */
  return;
}


void
District (long w_id)
{
  long d_id;
  long d_w_id;
  char d_name[10];
  char d_street_1[20];
  char d_street_2[20];
  char d_city[20];
  char d_state[2];
  char d_zip[9];
  float d_tax;
  float d_ytd;
  long d_next_o_id;

  static HSTMT dist_stmt;
  LOCAL_STMT (dist_stmt,
      "insert into district"
      " (d_id, d_w_id, d_name, "
      "d_street_1, d_street_2, d_city, d_state, d_zip,"
      "d_tax, d_ytd, d_next_o_id)" "values (?,?,?,?,?,  ?,?,?,?,?,  ?)");

  IBINDL (dist_stmt, 1, d_id);
  IBINDL (dist_stmt, 2, d_w_id);
  IBINDNTS (dist_stmt, 3, d_name);
  IBINDNTS (dist_stmt, 4, d_street_1);
  IBINDNTS (dist_stmt, 5, d_street_2);
  IBINDNTS (dist_stmt, 6, d_city);
  IBINDNTS (dist_stmt, 7, d_state);
  IBINDNTS (dist_stmt, 8, d_zip);
  IBINDF (dist_stmt, 9, d_tax);
  IBINDF (dist_stmt, 10, d_ytd);
  IBINDL (dist_stmt, 11, d_next_o_id);

#if defined (GUI)
  log (0, "Loading DISTRICT");
#else
  printf ("Loading DISTRICT\n");
#endif

  d_w_id = w_id;
  d_ytd = 300000.0;
  d_next_o_id = 3001L;
  for (d_id = 1; d_id <= DIST_PER_WARE; d_id++)
    {
      /* Generate District Data */
      MakeAlphaString (6, 10, d_name);
      MakeAddress (d_street_1, d_street_2, d_city, d_state, d_zip);
      d_tax = ((float) RandomNumber (10L, 20L)) / 100.0;

      IF_ERR_EXIT (dist_stmt, SQLExecute (dist_stmt));

      if (option_debug)
#if defined (GUI)
	log (0, "DID = %ld, WID = %ld, Name = %10s, Tax = %5.2f",
	    d_id, d_w_id, d_name, d_tax);
#else
	printf ("DID = %ld, WID = %ld, Name = %10s, Tax = %5.2f\n",
	    d_id, d_w_id, d_name, d_tax);
#endif
    }
  SQLTransact (henv, hdbc, SQL_COMMIT);
  /* printf ("DISTRICT loaded.\n"); */

  return;
}


void
Customer (long d_id_1, long w_id_1)
{
  long c_id_1;
  static long w_id[BATCH_SIZE];
  static long c_id[BATCH_SIZE];
  static long c_d_id[BATCH_SIZE];
  static long c_w_id[BATCH_SIZE];
  static char c_first[BATCH_SIZE][16];
  static char c_middle[BATCH_SIZE][2];
  static char c_last[BATCH_SIZE][16];
  static char c_street_1[BATCH_SIZE][20];
  static char c_street_2[BATCH_SIZE][20];
  static char c_city[BATCH_SIZE][20];
  static char c_state[BATCH_SIZE][2];
  static char c_zip[BATCH_SIZE][9];
  static char c_phone[BATCH_SIZE][16];
  static char c_credit[BATCH_SIZE][3];	/*initial 0's */
  static float c_credit_lim[BATCH_SIZE];
  static float c_discount[BATCH_SIZE];
  static float c_balance[BATCH_SIZE];
  static char c_data_1[BATCH_SIZE][250];
  static char c_data_2[BATCH_SIZE][250];
  static float h_amount[BATCH_SIZE];
  static char h_data[BATCH_SIZE][24];

  int fill = 0, h_fill = 0;
  static HSTMT cs_stmt;
  static HSTMT h_stmt;

  if (strstr (dbms, "Oracle"))
    {
      LOCAL_STMT (cs_stmt,
	  "insert into customer (c_id, c_d_id, c_w_id,"
	  "c_first, c_middle, c_last, "
	  "c_street_1, c_street_2, c_city, c_state, c_zip,"
	  "c_phone, c_since, c_credit, "
	  "c_credit_lim, c_discount, c_balance, c_data_1, c_data_2,"
	  "c_ytd_payment, c_cnt_payment, c_cnt_delivery) "
	  "values (?,?,?,?,?,   ?,?,?,?,?,   ?,?,sysdate,?, ?,   ?,?,?,?,"
	  "10.0, 1, 0)");
    }
  else
    {
      LOCAL_STMT (cs_stmt,
	  "insert into customer (c_id, c_d_id, c_w_id,"
	  "c_first, c_middle, c_last, "
	  "c_street_1, c_street_2, c_city, c_state, c_zip,"
	  "c_phone, c_since, c_credit, "
	  "c_credit_lim, c_discount, c_balance, c_data_1, c_data_2,"
	  "c_ytd_payment, c_cnt_payment, c_cnt_delivery) "
	  "values (?,?,?,?,?,   ?,?,?,?,?,   ?,?,getdate (),?, ?,   ?,?,?,?,"
	  "10.0, 1, 0)");
    }

  IBINDL (cs_stmt, 1, c_id);
  IBINDL (cs_stmt, 2, c_d_id);
  IBINDL (cs_stmt, 3, c_w_id);
  IBINDNTS_ARRAY (cs_stmt, 4, c_first);
  IBINDNTS_ARRAY (cs_stmt, 5, c_middle);
  IBINDNTS_ARRAY (cs_stmt, 6, c_last);
  IBINDNTS_ARRAY (cs_stmt, 7, c_street_1);
  IBINDNTS_ARRAY (cs_stmt, 8, c_street_2);
  IBINDNTS_ARRAY (cs_stmt, 9, c_city);
  IBINDNTS_ARRAY (cs_stmt, 10, c_state);
  IBINDNTS_ARRAY (cs_stmt, 11, c_zip);
  IBINDNTS_ARRAY (cs_stmt, 12, c_phone);
  IBINDNTS_ARRAY (cs_stmt, 13, c_credit);
  IBINDF (cs_stmt, 14, c_credit_lim);
  IBINDF (cs_stmt, 15, c_discount);
  IBINDF (cs_stmt, 16, c_balance);
  IBINDNTS_ARRAY (cs_stmt, 17, c_data_1);
  IBINDNTS_ARRAY (cs_stmt, 18, c_data_2);

  if (strstr (dbms, "Oracle"))
    {
      LOCAL_STMT (h_stmt,
	  "insert into history ("
	  "  h_c_id, h_c_d_id, h_c_w_id, h_w_id, h_d_id, h_date, h_amount, h_data)"
	  "values (?,?,?,?,  ?,sysdate,?,?)");
    }
  else
    {
      LOCAL_STMT (h_stmt,
	  "insert into history ("
	  "  h_c_id, h_c_d_id, h_c_w_id, h_w_id, h_d_id, h_date, h_amount, h_data)"
	  "values (?,?,?,?,  ?,getdate(),?,?)");
    }


  IBINDL (h_stmt, 1, c_id);
  IBINDL (h_stmt, 2, c_d_id);
  IBINDL (h_stmt, 3, c_w_id);
  IBINDL (h_stmt, 4, c_w_id);
  IBINDL (h_stmt, 5, c_d_id);
  IBINDF (h_stmt, 6, h_amount);
  IBINDNTS_ARRAY (h_stmt, 7, h_data);

#if defined (GUI)
  log (0, "Loading CUSTOMER for DID=%ld, WID=%ld", d_id_1, w_id_1);
#else
  printf ("Loading CUSTOMER for DID=%ld, WID=%ld\n", d_id_1, w_id_1);
#endif

  for (c_id_1 = 1; c_id_1 <= CUST_PER_DIST; c_id_1++)
    {
      /* Generate Customer Data */
      w_id[fill] = w_id_1;
      c_id[fill] = c_id_1;
      c_d_id[fill] = d_id_1;
      c_w_id[fill] = w_id_1;

      MakeAlphaString (8, 15, c_first[fill]);
      MakeAlphaString (240, 240, c_data_1[fill]);
      MakeAlphaString (240, 240, c_data_2[fill]);
      c_middle[fill][0] = 'J';
      c_middle[fill][1] = 0;
      if (c_id_1 <= 1000)
	Lastname (c_id_1 - 1, c_last[fill]);
      else
	Lastname (NURand (255, 0, 999), c_last[fill]);
      MakeAddress (c_street_1[fill], c_street_2[fill],
	  c_city[fill], c_state[fill], c_zip[fill]);
      MakeNumberString (16, 16, c_phone[fill]);
      if (RandomNumber (0L, 1L))
	c_credit[fill][0] = 'G';
      else
	c_credit[fill][0] = 'B';
      c_credit[fill][1] = 'C';
      c_credit_lim[fill] = 500;
      c_discount[fill] = ((float) RandomNumber (0L, 50L)) / 100.0;
      c_balance[fill] = 10.0;

      CHECK_BATCH (cs_stmt, fill);

      gettimestamp (timestamp_array[h_fill]);
      h_amount[h_fill] = 10.0;
      MakeAlphaString (12, 24, h_data[h_fill]);

      CHECK_BATCH (h_stmt, h_fill);
    }
  FLUSH_BATCH (cs_stmt, fill);
  FLUSH_BATCH (h_stmt, h_fill);

  /* printf ("CUSTOMER loaded.\n"); */

  return;
}


void
Orders (long d_id, long w_id)
{
  long ol_1;
  long o_id_1;
  static long o_id[BATCH_SIZE];
  static long o_c_id[BATCH_SIZE];
  static long o_d_id[BATCH_SIZE];
  static long o_w_id[BATCH_SIZE];
  static long o_carrier_id[BATCH_SIZE];
  static long o_ol_cnt[BATCH_SIZE];
  static long ol[BATCH_SIZE];
  static long ol_i_id[BATCH_SIZE];
  static long ol_supply_w_id[BATCH_SIZE];
  static long ol_quantity[BATCH_SIZE];
  static long ol_amount[BATCH_SIZE];
  static char ol_dist_info[BATCH_SIZE][24];
  static long ol_o_id[BATCH_SIZE];
  static long ol_o_d_id[BATCH_SIZE];
  static long ol_o_w_id[BATCH_SIZE];
  int fill = 0, ol_fill = 0;
  static HSTMT o_stmt;
  static HSTMT no_stmt;
  static HSTMT ol_stmt;

  if (strstr (dbms, "Oracle"))
    {
      LOCAL_STMT (o_stmt,
	  "insert into "
	  " orders (o_id, o_c_id, o_d_id, o_w_id, "
	  "o_entry_d, o_carrier_id, o_ol_cnt, o_all_local)"
	  "values (?,?,?,?,  sysdate,?,?, 1)");
    }
  else
    {
      LOCAL_STMT (o_stmt,
	  "insert into "
	  " orders (o_id, o_c_id, o_d_id, o_w_id, "
	  "o_entry_d, o_carrier_id, o_ol_cnt, o_all_local)"
	  "values (?,?,?,?,  getdate(),?,?, 1)");
    }

  IBINDL (o_stmt, 1, o_id);
  IBINDL (o_stmt, 2, o_c_id);
  IBINDL (o_stmt, 3, o_d_id);
  IBINDL (o_stmt, 4, o_w_id);
  IBINDL (o_stmt, 5, o_carrier_id);
  IBINDL (o_stmt, 6, o_ol_cnt);

  LOCAL_STMT (ol_stmt,
      "insert into "
      " order_line (ol_o_id, ol_d_id, ol_w_id, ol_number,"
      "ol_i_id, ol_supply_w_id, ol_quantity, ol_amount,"
      "ol_dist_info, ol_delivery_d)" "values (?,?,?,?,?,  ?,?,?,?,  NULL)");

  IBINDL (ol_stmt, 1, ol_o_id);
  IBINDL (ol_stmt, 2, ol_o_d_id);
  IBINDL (ol_stmt, 3, ol_o_w_id);
  IBINDL (ol_stmt, 4, ol);
  IBINDL (ol_stmt, 5, ol_i_id);
  IBINDL (ol_stmt, 6, ol_supply_w_id);
  IBINDL (ol_stmt, 7, ol_quantity);
  IBINDL (ol_stmt, 8, ol_amount);
  IBINDNTS_ARRAY (ol_stmt, 9, ol_dist_info);

  LOCAL_STMT (no_stmt,
      "insert into new_order (no_o_id, no_d_id, no_w_id) values (?,?,?)");

#if defined (GUI)
  log (0, "Loading ORDERS for D=%ld, W= %ld", d_id, w_id);
  set_progress_max (ORD_PER_DIST);
#else
  printf ("Loading ORDERS for D=%ld, W= %ld\n", d_id, w_id);
#endif

  for (o_id_1 = 1; o_id_1 <= ORD_PER_DIST; o_id_1++)
    {
      /* Generate Order Data */
      o_id[fill] = o_id_1;
      o_d_id[fill] = d_id;
      o_w_id[fill] = w_id;
      o_c_id[fill] = RandomNumber (1, CUST_PER_DIST);	/* GetPermutation(); */
      o_carrier_id[fill] = RandomNumber (1L, 10L);
      o_ol_cnt[fill] = RandomNumber (5L, 15L);

      /* the last 900 orders have not been delivered */
      if (o_id_1 > ORD_PER_DIST - 900)
	{
	  IBINDL (no_stmt, 1, o_id[fill]);
	  IBINDL (no_stmt, 2, o_d_id[fill]);
	  IBINDL (no_stmt, 3, o_w_id);

	  IF_ERR_EXIT (no_stmt, SQLExecute (no_stmt));
	}

      /* Generate Order Line Data */
      for (ol_1 = 1; ol_1 <= o_ol_cnt[fill]; ol_1++)
	{
	  ol[ol_fill] = ol_1;
	  ol[ol_fill] = ol_1;
	  ol_o_id[ol_fill] = o_id[fill];
	  ol_o_d_id[ol_fill] = o_d_id[fill];
	  ol_o_w_id[ol_fill] = o_w_id[fill];
	  ol_i_id[ol_fill] = RandomNumber (1L, MAXITEMS);
	  ol_supply_w_id[ol_fill] = o_w_id[fill];
	  ol_quantity[ol_fill] = 5;
	  ol_amount[ol_fill] = 0.0;

	  MakeAlphaString (24, 24, ol_dist_info[ol_fill]);

	  CHECK_BATCH (ol_stmt, ol_fill);
	}
      CHECK_BATCH (o_stmt, fill);

      if (!(o_id_1 % 100))
	{
#if defined (GUI)
	  progress (o_id_1);
#else
	  printf ("%6ld\r", o_id_1);
	  fflush (stdout);
#endif
	}
    }
#if defined (GUI)
  progress_done ();
#endif

  FLUSH_BATCH (o_stmt, fill);
  FLUSH_BATCH (ol_stmt, ol_fill);

  /* printf ("ORDERS loaded.\n"); */

  return;
}

void
scrap_log ()
{
  if (strstr (dbms, "SQL Server"))
    {
      IS_ERR (misc_stmt, SQLExecDirect (misc_stmt,
	      (UCHAR *)
	      "dump transaction tpcc to disk='null.dat' with no_log",
	      SQL_NTS));
    }
  else if (strstr (dbms, "Oracle"))
    {

      IS_ERR (misc_stmt, SQLExecDirect (misc_stmt,
	      (UCHAR *) "alter system checkpoint", SQL_NTS));

    }
  else if (strstr (dbms, "Virtuoso"))
    {
      IS_ERR (misc_stmt, SQLExecDirect (misc_stmt,
	      (UCHAR *) "checkpoint", SQL_NTS));
    }
}

void
remove_old_orders (int nCount)
{
  static HSTMT remove_stmt;
  LOCAL_STMT (remove_stmt, "{call oldord(?)}");
  IBINDL (remove_stmt, 1, nCount);
  IF_ERR_EXIT (remove_stmt, SQLExecute (remove_stmt));
}

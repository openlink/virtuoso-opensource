/*
 *  tpcc.c
 *
 *  $Id$
 *
 *  TPC-C Benchmark
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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#ifdef WIN32
# include <windows.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <memory.h>
#ifdef UNIX
# include <sys/time.h>
#endif

#include "odbcinc.h"
#include "timeacct.h"
#include "odbcuti.h"
#include "tpcc.h"

int messages_off = 0;
int quiet = 0;


void login (HENV * henv, HDBC * hdbc, char *argv_, char *dbms, int dbms_sz,
    HSTMT * misc_stmt, char *uid, char *pwd);

void logoff ();
void scrap_log ();

long
RandomNumber (long x, long y)
{
  return (random_1 ((y - x) + 1) + x);
}


long
NURand (int a, int x, int y)
{
  return ((((RandomNumber (0, a) |
		  RandomNumber (x, y)) + 1234567) % (y - x + 1)) + x);
}


int
MakeAlphaString (int sz1, int sz2, char *str)
{
  int sz = RandomNumber (sz1, sz2);
  int inx;
  for (inx = 0; inx < sz; inx++)
    str[inx] = 'a' + (inx % 24);
  str[sz - 1] = 0;
  return sz - 1;
}


void
MakeNumberString (int sz, int sz2, char *str)
{
  int inx;
  for (inx = 0; inx < sz; inx++)
    str[inx] = '0' + (inx % 10);
  str[sz - 1] = 0;
}


long
random_c_id ()
{
  return (NURand (1023, 1, 3000));
}


long
random_c_last (void)
{
  return (NURand (255, 0, 999));
}


long
random_i_id (void)
{
  return (NURand (8191, 1, 100000));
}



char dbms[40];
HSTMT misc_stmt;




HDBC hdbc;
HENV henv;


void
check_dd ()
{
#if 0
  int rc;
  HSTMT ck_stmt;
  SQLAllocStmt (hdbc, &ck_stmt);

  rc =
      SQLTables (ck_stmt, (UCHAR *) "%", SQL_NTS, (UCHAR *) "%", SQL_NTS,
      (UCHAR *) "ORDERS", SQL_NTS, (UCHAR *) "%", SQL_NTS);
  IF_ERR_EXIT (ck_stmt, rc);
  if (SQL_SUCCESS != SQLFetch (ck_stmt))
    {
      IS_ERR (ck_stmt, SQLFreeStmt (ck_stmt, SQL_CLOSE));
      IS_ERR (ck_stmt, SQLExecDirect (ck_stmt, (UCHAR *) dd_text, SQL_NTS));
    }
  SQLFreeStmt (ck_stmt, SQL_DROP);
  SQLTransact (henv, hdbc, SQL_COMMIT);
#endif
}


/*==================================================================+
 | Load TPCC tables
 +==================================================================*/


/* Functions */

void LoadItems ();
void LoadWare ();
void LoadCust ();
void LoadOrd ();
void Stock (long w_id_from, long w_id_to);
void District (long w_id);
void Customer (long, long);
void Orders (long d_id, long w_id);
void New_Orders ();
void Error ();

void remove_old_orders (int nCount);

char timestamp_array[BATCH_SIZE][20];
long count_ware;
SDWORD sql_timelen_array[BATCH_SIZE];

/* Global Variables */
int i;
int option_debug = 0;		/* 1 if generating debug output    */

/*==================================================================+
 |      main()
 | ARGUMENTS
 |      Warehouses n [Debug] [Help]

HENV henv;
HDBC hdbc;

 +==================================================================*/

void
gettimestamp_2 (char *ts)
{
  struct timeval tv;
  gettimestamp (&tv);
  memcpy (ts, &tv, sizeof (tv));
}


void
create_db ()
{
  int i;

  for (i = 0; i < BATCH_SIZE; i++)
    gettimestamp_2 (timestamp_array[i]);

#if defined (GUI)
  log (0, "TPCC Data Load Started...\n");
#else
  printf ("TPCC Data Load Started...\n");
#endif

  LoadWare ();
  scrap_log ();

  LoadItems ();
  scrap_log ();

  LoadCust ();
  scrap_log ();

  LoadOrd ();
  scrap_log ();

#if defined (GUI)
  log (0, "DATA LOADING COMPLETED SUCCESSFULLY.\n");
#else
  printf ("DATA LOADING COMPLETED SUCCESSFULLY.\n");
  exit (0);
#endif
}


/*==================================================================+
 | ROUTINE NAME
 |      MakeAddress()
 | DESCRIPTION
 |      Build an Address
 | ARGUMENTS
 +==================================================================*/
void
MakeAddress (char *str1, char *str2, char *city, char *state, char *zip)
{
  MakeAlphaString (10, 18, str1);	/* Street 1 */
  MakeAlphaString (10, 18, str2);	/* Street 2 */
  MakeAlphaString (10, 18, city);	/* City */
  MakeAlphaString (2, 2, state);	/* State */
  MakeNumberString (9, 9, zip);	/* Zip */
}


/*==================================================================+
 | ROUTINE NAME
 |      Lastname
 | DESCRIPTION
 |      TPC-C Lastname Function.
 | ARGUMENTS
 |      num  - non-uniform random number
 |      name - last name string
 +==================================================================*/
void
Lastname (int num, char *name)
{
  static char *n[] = {
    "BAR", "OUGHT", "ABLE", "PRI", "PRES",
    "ESE", "ANTI", "CALLY", "ATION", "EING"
  };

  strcpy (name, n[num / 100]);
  strcat (name, n[(num / 10) % 10]);
  strcat (name, n[num % 10]);

  return;
}


void
init_globals ()
{
  int i;
  for (i = 0; i < BATCH_SIZE; i++)
    {
      sql_timelen_array[i] = 8;
    }
}


#if defined(GUI)
#include <stdarg.h>
/*void
log(int nLevel, const char *szFormat, ...) {

	va_list ap;
	va_start(ap, szFormat);
	vlog(nLevel, szFormat, ap);
}
*/
#else
void
print_error (HSTMT e1, HSTMT e2, HSTMT e3)
{
  int len;
  char state[10];
  char message[1000];

  SQLError (e1, e2, e3, (UCHAR *) state, NULL,
      (UCHAR *) & message, sizeof (message), (SWORD *) & len);
#if defined (GUI)
  printf ("\n*** Error %s: %s\n", state, message);
  log (0, "*** Error %s: %s", state, message);
#else
  printf ("\n*** Error %s: %s\n", state, message);
  if (0 == strcmp (state, "08S01"))
    exit (2);
  if (0 == strcmp (state, "40003"))
    exit (2);
#endif
}


void
usage ()
{
  printf ("Usage: tpcc datasource flag num\n");
  exit (1);
}


int
main (int argc, char **argv)
{
  char *uid = "dba", *pwd = "dba";
  long del_start, del_total;

  printf ("Virtuoso TPC C Benchmark.\n"
      "\n"
      "This benchmark is modeled after the TPC C benchmark but does not in itself\n"
      "constitute a full implementation nor are the results obtained herewith\n"
      "necessarily comparable to the vendors' published results.\n\n");

  if (argc < 2)
    {
      printf ("Usage:\n"
	  "  tpcc <host:port> user pass i <n>\n"
	  "       - Create a database of n warehouses. Approx 100MB / warehouse.\n"
	  "  tpcc <host:port> user pass r <n> [<local_w> <n_ware>]]\n"
	  "       - Run n sets of 10 transactions, print results\n"
	  "   Running the benchmark requires the procedures in tpcc.sql and tpccddk.sql\n"
	  "   to be loaded\n into the database.\n");
      exit (1);
    }
  set_rnd_seed (2793);
  uid = argv[2];
  pwd = argv[3];


  login (&henv, &hdbc, argv[1], dbms, sizeof (dbms), &misc_stmt, uid, pwd);
  if (*argv[4] == 'S')
    printf ("Connected trough SOAP to DBMS %s\n", dbms);
  else
    printf ("Connected to DBMS %s\n", dbms);
  init_globals ();


  switch (*argv[4])
    {
    case 'i':
	{
	  int n = atoi (argv[5]);
	  if (!n)
	    {
	      usage ();
	      exit (-1);
	    }
	  count_ware = n;
	  create_db ();
	}
      break;

    case 'S':
      strcpy (dbms, "SOAP");
    case 'r':
      run_test (argc, argv);
      break;
    case 'R':
      run_timed_test (argc, argv);
      break;
    case 'd':
	{
	  int nCount = atoi (argv[5]);
	  if (!nCount)
	    {
	      usage ();
	      exit (-1);
	    }
	  del_start = get_msec_count ();
	  remove_old_orders (nCount);
	  del_total = get_msec_count () - del_start;
	  printf ("# Time for delete %d records - %ld msec\n", nCount,
	      del_total);
	}
      break;
    }
  logoff ();
  return 0;
}
#endif

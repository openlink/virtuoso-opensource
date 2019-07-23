/*
 *  tpcctrx.c
 *
 *  $Id$
 *
 *  TPC-C Transactions
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

void new_order ();
void payment ();
void ostat ();
void slevel ();
void delivery_1 (SDWORD, int);
void scrap_log ();

extern char dbms[40];

timer_account_t ten_pack_ta;
timer_account_t new_order_ta;
timer_account_t payment_ta;
timer_account_t delivery_ta;
timer_account_t slevel_ta;
timer_account_t ostat_ta;
timer_account_t total_ta;
timer_account_t check_point_ta;


#define TEN_PACK_TIME	120


SDWORD local_w_id = 1;
SDWORD n_ware = 1;
char *new_order_text;



char *new_order_text_kubl = " new_order (?, ?, ?, ?, ?,    "	/*  1, w_id, 2. d_id, 3. c_id, 4 ol_cnt, 5 all_local */
    "        ?, ?, ?, "		/* 1. i_id 2. 2. supply_w_id 3. qty */
    "        ?, ?, ?, "
    "        ?, ?, ?, "
    "        ?, ?, ?, "
    "        ?, ?, ?, "
    "        ?, ?, ?, "
    "        ?, ?, ?, "
    "        ?, ?, ?, " "        ?, ?, ?, " "        ?, ?, ?)";
char *new_order_text_mssql = " exec new_order_proc ?, ?, ?, ?, ?,    "	/*  1, w_id, 2. d_id, 3. c_id, 4 ol_cnt, 5 all_local */
    "        ?, ?, ?, "		/* 1. i_id 2. 2. supply_w_id 3. qty */
    "        ?, ?, ?, "
    "        ?, ?, ?, "
    "        ?, ?, ?, "
    "        ?, ?, ?, "
    "        ?, ?, ?, "
    "        ?, ?, ?, "
    "        ?, ?, ?, " "        ?, ?, ?, " "        ?, ?, ? ";

char *new_order_text_ora = "{call new_order_proc(?, ?, ?, ?, ?,    "	/*  1, w_id, 2. d_id, 3. c_id, 4 ol_cnt, 5 all_local */
    "        ?, ?, ?, "		/* 1. i_id 2. 2. supply_w_id 3. qty */
    "        ?, ?, ?, "
    "        ?, ?, ?, "
    "        ?, ?, ?, "
    "        ?, ?, ?, "
    "        ?, ?, ?, "
    "        ?, ?, ?, "
    "        ?, ?, ?, " "        ?, ?, ?, " "        ?, ?, ? )}";

char *new_order_text_SOAP = "soap_call (concat ('localhost:' , server_http_port()), '/SOAP', 'urn:openlinksw-com:virtuoso', 'new_order', vector ("
    "'_w_id', ?,"
    "'_d_id', ?,"
    "'_c_id', ?,"
    "'o_ol_cnt', ?,"
    "'o_all_local', ?,"
    "'i_id_1', ?, 's_w_id_1', ?, 'qty_1', ?,"
    "'i_id_2', ?, 's_w_id_2', ?, 'qty_2', ?,"
    "'i_id_3', ?, 's_w_id_3', ?, 'qty_3', ?,"
    "'i_id_4', ?, 's_w_id_4', ?, 'qty_4', ?,"
    "'i_id_5', ?, 's_w_id_5', ?, 'qty_5', ?,"
    "'i_id_6', ?, 's_w_id_6', ?, 'qty_6', ?,"
    "'i_id_7', ?, 's_w_id_7', ?, 'qty_7', ?,"
    "'i_id_8', ?, 's_w_id_8', ?, 'qty_8', ?,"
    "'i_id_9', ?, 's_w_id_9', ?, 'qty_9', ?,"
    "'i_id_10', ?, 's_w_id_10', ?, 'qty_10', ?))";

int
make_supply_w_id ()
{
  if (n_ware > 1 && RandomNumber (0, 99) < 10)
    {
      int n, n_tries = 0;
      do
	{
	  n = RandomNumber (1, n_ware);
	  n_tries++;
	}
      while (n == local_w_id && n_tries < 10);
      return local_w_id;
    }
  else
    return local_w_id;
}


int
rnd_district ()
{
  return (10 - (RandomNumber (0, 9999) / 1000));
}



char *payment_text_kubl = "payment (?, ?, ?, ?, ?, ?, ?)";
char *payment_text_mssql = "exec payment ?, ?, ?, ?, ?, ?, ?";
char *payment_text_ora = "{call payment(?, ?, ?, ?, ?, ?, ?)}";
char *payment_text_SOAP = "soap_call (concat ('localhost:' , server_http_port()), '/SOAP', 'urn:openlinksw-com:virtuoso', 'payment', vector ('_w_id', ?, '_c_w_id', ?, 'h_amount', ?, '_d_id', ?, '_c_d_id', ?, '_c_id', ?, '_c_last', ?))";
char *payment_text;


char *delivery_text_kubl = "delivery_1 (?, ?, ?)";
char *delivery_text_mssql = "exec delivery ?, ?";
char *delivery_text_ora = "{call delivery(?, ?)}";
char *delivery_text_SOAP = "soap_call (concat ('localhost:' , server_http_port()), '/SOAP', 'urn:openlinksw-com:virtuoso', 'delivery_1', vector ('w_id', ?, 'carrier_id', ?, 'd_id', ?))";
char *delivery_text;


char *slevel_text_kubl = "slevel (?, ?, ?)";
char *slevel_text_mssql = "exec slevel ?, ?, ?";
char *slevel_text_ora = "{call slevel(?, ?, ?)}";
char *slevel_text_SOAP = "soap_call (concat ('localhost:' , server_http_port()), '/SOAP', 'urn:openlinksw-com:virtuoso', 'slevel', vector ('w_id', ?, '_d_id', ?, 'threshold', ?))";
char *slevel_text;



char *ostat_text_kubl = "ostat (?, ?, ?, ?)";
char *ostat_text_mssql = "exec ostat ?, ?, ?, ?";
char *ostat_text_ora = "{call ostat(?, ?, ?, ?)}";
char *ostat_text_SOAP = "soap_call (concat ('localhost:' , server_http_port()), '/SOAP', 'urn:openlinksw-com:virtuoso', 'ostat', vector ('_w_id', ?, '_d_id', ?, '_c_id', ?, '_c_last', ?))";
char *ostat_text;


/* #define NO_ONLY */

void
do_10_pack ()
{
  int n;
  long start = get_msec_count (), duration;

  ta_enter (&ten_pack_ta);
  for (n = 0; n < 10; n++)
    {
      new_order ();
#ifndef NO_ONLY
      payment ();
#endif
    }

#ifndef NO_ONLY
  ta_enter (&delivery_ta);
  if (strstr (dbms, "Virtuoso") || strstr (dbms, "SOAP"))
    {
      for (n = 1; n <= 10; n++)
	delivery_1 (local_w_id, n);
    }
  else
    {
      delivery_1 (local_w_id, 0);
    }
  ta_leave (&delivery_ta);
  slevel ();
  ostat ();
#endif

  ta_leave (&ten_pack_ta);
  duration = get_msec_count () - start;
#if defined(GUI)
  log (1, "-- %ld tpmC\n", 600000 / duration);
#else
  printf ("-- %ld tpmC\n\n", 600000 / duration);
  fflush (stdout);
#endif
}

#define SAMPLE_CHECK 5000
#define CHECK_POINT_INTERVAL 15000
void
reset_times ()
{
  ta_init (&new_order_ta, "NEW ORDER");
  ta_init (&payment_ta, "PAYMENT");
  ta_init (&delivery_ta, "DELIVERY");
  ta_init (&slevel_ta, "STOCK LEVEL");
  ta_init (&ostat_ta, "ORDER STATUS");
  ta_init (&ten_pack_ta, "10 Pack");
}


void
print_times ()
{
#if !defined(GUI)
  ta_print_out (stdout, &new_order_ta);
  ta_print_out (stdout, &payment_ta);
  ta_print_out (stdout, &delivery_ta);
  ta_print_out (stdout, &slevel_ta);
  ta_print_out (stdout, &ostat_ta);
#endif
}

#if defined(GUI)
void
print_times_str (char *szBuffer)
{
  char szLine[512];
  ta_print_buffer (szLine, &new_order_ta);
  strncpy (szBuffer, szLine, 512);
  ta_print_buffer (szLine, &payment_ta);
  strncat (szBuffer, szLine, 512 - strlen (szBuffer));
  ta_print_buffer (szLine, &delivery_ta);
  strncat (szBuffer, szLine, 512 - strlen (szBuffer));
  ta_print_buffer (szLine, &slevel_ta);
  strncat (szBuffer, szLine, 512 - strlen (szBuffer));
  ta_print_buffer (szLine, &ostat_ta);
  strncat (szBuffer, szLine, 512 - strlen (szBuffer));
}
#endif

extern int n_deadlocks;
int
do_run_test (int n_rounds, int _local_w_id, int _n_ware)
{
  int i;
  long start_check_point = get_msec_count (), check_point;
  long start_total = get_msec_count (), total;
  if (strstr (dbms, "Virtuoso"))
    {
      new_order_text = new_order_text_kubl;
      payment_text = payment_text_kubl;
      delivery_text = delivery_text_kubl;
      slevel_text = slevel_text_kubl;
      ostat_text = ostat_text_kubl;
    }
  else if (strstr (dbms, "SQL Server"))
    {
      new_order_text = new_order_text_mssql;
      payment_text = payment_text_mssql;
      delivery_text = delivery_text_mssql;
      slevel_text = slevel_text_mssql;
      ostat_text = ostat_text_mssql;
    }
  else if (strstr (dbms, "Oracle"))
    {
      new_order_text = new_order_text_ora;
      payment_text = payment_text_ora;
      delivery_text = delivery_text_ora;
      slevel_text = slevel_text_ora;
      ostat_text = ostat_text_ora;
    }
  else if (strstr (dbms, "SOAP"))
    {
      new_order_text = new_order_text_SOAP;
      payment_text = payment_text_SOAP;
      delivery_text = delivery_text_SOAP;
      slevel_text = slevel_text_SOAP;
      ostat_text = ostat_text_SOAP;
    }
  else
    {
      return 0;
    }
  if (_local_w_id != -1)
    {
      local_w_id = _local_w_id;
      n_ware = _n_ware;
    }
  reset_times ();

#ifdef GUI
  set_progress_max (n_rounds);
#endif
  ta_init (&total_ta, "TOTAL");
  ta_init (&check_point_ta, "CHECK_POINT");
  ta_enter (&total_ta);
  ta_enter (&check_point_ta);
  for (i = 0; i < n_rounds; i++)
    {
      do_10_pack ();
      if (i && 0 == i % SAMPLE_CHECK)
	{
	  check_point = get_msec_count () - start_check_point;
	  total = get_msec_count () - start_total;
	  printf
	      ("# Transaction No:%d Last cycle:%ld tpmC  From start:%ld tpmC\n", \
	      i, 600000 / (check_point / SAMPLE_CHECK),
	      600000 / (total / i));
	  ta_init (&check_point_ta, "CHECK_POINT");
	  /*Do statistic */
	}
#if 0
      /* not the client's problem during test run */
      if (i && 0 == i % CHECK_POINT_INTERVAL)
	scrap_log ();
#endif
      if (i && 0 == i % 10)
	{
#if !defined(GUI)
	  print_times ();
	  reset_times ();
#endif
	}
#if defined(GUI)
      progress (i);
#endif
    }
#if defined(GUI)
  progress_done ();
#endif
  total = get_msec_count () - start_total;
  printf ("# Total transactions:%d %ld tpmC, %d retries\n", i, 600000 / (total / i), n_deadlocks);

  return 1;
}

void
run_test (int argc, char **argv)
{

  if (!do_run_test (atoi (argv[5]), argc == 8 ? atoi (argv[6]) : -1,
	  argc == 8 ? atoi (argv[7]) : -1))
    {
#if !defined(GUI)
      printf ("Unknown DBMS %s\n", dbms);
      exit (-1);
#else
      log (0, "Unknown DBMS %s\n", dbms);
#endif

    }
}


void
transaction_per_period (int nPeriodSeconds, void (*tr1) ())
{


  int start = get_msec_count (), duration, wait_secs;

  tr1 ();
  duration = (get_msec_count () - start) / 1000;
  wait_secs = nPeriodSeconds - duration;
  if (wait_secs > 0)
#ifdef WIN32
    Sleep (RandomNumber (1, wait_secs) * 1000);
#else
    sleep (RandomNumber (1, wait_secs));
#endif
}

void
delivery ()
{

  int n;

  ta_enter (&delivery_ta);
  if (strstr (dbms, "Virtuoso"))
    {
      for (n = 1; n <= 10; n++)
	delivery_1 (local_w_id, n);
    }
  else
    {
      delivery_1 (local_w_id, 0);
    }
  ta_leave (&delivery_ta);
}

void
run_timed_test (int argc, char **argv)
{
  int i, n_rounds = atoi (argv[5]);
  if (strstr (dbms, "Virtuoso"))
    {
      new_order_text = new_order_text_kubl;
      payment_text = payment_text_kubl;
      delivery_text = delivery_text_kubl;
      slevel_text = slevel_text_kubl;
      ostat_text = ostat_text_kubl;
    }
  else if (strstr (dbms, "SQL Server"))
    {
      new_order_text = new_order_text_mssql;
      payment_text = payment_text_mssql;
      delivery_text = delivery_text_mssql;
      slevel_text = slevel_text_mssql;
      ostat_text = ostat_text_mssql;
    }
  else if (strstr (dbms, "Oracle"))
    {
      new_order_text = new_order_text_ora;
      payment_text = payment_text_ora;
      delivery_text = delivery_text_ora;
      slevel_text = slevel_text_ora;
      ostat_text = ostat_text_ora;
    }
  else
    {
      printf ("Unknown DBMS %s\n", dbms);
      exit (-1);
    }
  if (argc == 8)
    {
      local_w_id = atoi (argv[6]);
      n_ware = atoi (argv[7]);
    }
  reset_times ();

  for (i = 0; i < n_rounds; i++)
    {
      int n;
      long start, duration;

      start = get_msec_count ();
      for (n = 0; n < 10; n++)
	{
	  transaction_per_period (TEN_PACK_TIME / 23, new_order);
	  transaction_per_period (TEN_PACK_TIME / 23, payment);
	}

      transaction_per_period (TEN_PACK_TIME / 23, delivery);
      transaction_per_period (TEN_PACK_TIME / 23, slevel);
      transaction_per_period (TEN_PACK_TIME / 23, ostat);

      duration = (get_msec_count () - start) / 1000;
      if (TEN_PACK_TIME - duration > 0)
#ifdef WIN32
	Sleep ((TEN_PACK_TIME - duration) * 1000);
#else
	sleep (TEN_PACK_TIME - duration);
#endif
      print_times ();
      if (i && 0 == i % 10)
	{
	  reset_times ();
	}
    }
}

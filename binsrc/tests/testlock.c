/*
 *  $Id$
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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#ifndef WINDOWS

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <memory.h>
#include "odbcinc.h"

#else

#include <windows.h>
#include <winsock.h>
#include <sql.h>
#include <sqlext.h>
// #include <sqltypes.h>

typedef void *pthread_attr_t;

#define pthread_t HANDLE
// #define pthread_attr_t void
#define sleep(time) \
	Sleep ((DWORD) (time))

#endif


struct thr_t
{
  pthread_t thr;
  pthread_attr_t pattr;
  int done, type;
  long num;
  SQLHDBC hdbc;
  SQLHSTMT hstmt;
  SQLHENV henv;
};

#ifndef WINDOWS
pthread_cond_t fire_c = PTHREAD_COND_INITIALIZER;
pthread_mutex_t fire_m = PTHREAD_MUTEX_INITIALIZER;
#endif

static int fire = 0;
static char *dsn = "";
static long nbupd = 0;
static long nbrea = 0;
static long loop = 0;
static SQLULEN isolation = 0;

void
print_error (struct thr_t *t)
{
  unsigned char buf[255];
  unsigned char sqlstate[15];

  printf ("Error detected : \n\r");

  while (SQLError (t->henv, t->hdbc, t->hstmt, sqlstate, NULL, buf, sizeof (buf), NULL) == SQL_SUCCESS)
    {
      printf ("%s, SQLSTATE=%s\n", buf, sqlstate);
    }

  while (SQLError (t->henv, t->hdbc, SQL_NULL_HSTMT, sqlstate, NULL, buf, sizeof (buf), NULL) == SQL_SUCCESS)
    {
      printf ("%s, SQLSTATE=%s\n", buf, sqlstate);
    }

  while (SQLError (t->henv, SQL_NULL_HDBC, SQL_NULL_HSTMT, sqlstate, NULL, buf, sizeof (buf), NULL) == SQL_SUCCESS)
    {
      printf ("%s, SQLSTATE=%s\n", buf, sqlstate);
    }
}

#ifdef WINDOWS
DWORD WINAPI
thread_rea (LPVOID * data)
#else
void *
thread_rea (void *data)
#endif
{
  struct thr_t *thr = (struct thr_t *) data;
  char szout[1024];
  SQLSMALLINT length;
  long i;

  /* Wait until not fired */
#ifdef WINDOWS
  pthread_mutex_lock (&fire_m);
  while (fire == 0)
    sleep (5);
#else
  pthread_mutex_lock (&fire_m);
  while (fire == 0)
    pthread_cond_wait (&fire_c, &fire_m);
  pthread_mutex_unlock (&fire_m);
#endif
  /*
     pthread_mutex_lock(&fire_m);
     while(fire == 0)
     {
     #ifdef WINDOWS
     sleep(5);
     #else
     pthread_cond_wait (&fire_c, &fire_m);
     #endif
     }
     pthread_mutex_unlock(&fire_m); */

  printf ("One Reader threads begin to attack ...\n");

  /* Prepare the connection */
  while (SQLAllocConnect (thr->henv, &thr->hdbc) == SQL_ERROR)
    {
      printf ("Allocation of the connection handle failed\n");
      print_error (thr);
    }
  /* Do the process now */
  while (SQLDriverConnect (thr->hdbc, NULL, (SQLCHAR *) dsn, SQL_NTS,
	  szout, sizeof (szout), &length, SQL_DRIVER_NOPROMPT) == SQL_ERROR)
    {
      printf ("Connection failed on dsn=%s\n", dsn);
      print_error (thr);
    }
  printf ("Connection success for Reader %ld\n", thr->num);
  /* No autocommit set perhaps */
  if (isolation)
    {
      if (SQLSetConnectOption (thr->hdbc, SQL_ATTR_AUTOCOMMIT, (SQLULEN) SQL_AUTOCOMMIT_OFF) == SQL_ERROR)
	{
	  print_error (thr);
	  goto end;
	}
      if (SQLSetConnectOption (thr->hdbc, SQL_ATTR_TXN_ISOLATION, isolation) == SQL_ERROR)
	{
	  print_error (thr);
	  goto end;
	}
    }
  /* Make a loop */
  for (i = 0; i < loop; i++)
    {
      if (SQLAllocStmt (thr->hdbc, &thr->hstmt) == SQL_ERROR)
	{
	  print_error (thr);
	  goto end;
	}
      if (SQLPrepare (thr->hstmt, "SELECT * FROM LOCKTEST ORDER BY SOME_DATETIME DESC", SQL_NTS) == SQL_ERROR)
	{
	  print_error (thr);
	  goto end;
	}
      switch (SQLExecute (thr->hstmt))
	{
	case SQL_ERROR:
	  print_error (thr);
	  goto end;
	default:
	  while (SQLFetch (thr->hstmt) == SQL_SUCCESS);
	}
      if (SQLFreeStmt (thr->hstmt, SQL_CLOSE) == SQL_ERROR)
	{
	  print_error (thr);
	  goto end;
	}
    }

end:
  /* Disconnect now */
  SQLDisconnect (thr->hdbc);
  printf ("One Reader thread less to attack ...\n");

  thr->done = 1;
/*  while(fire == 1) sleep(5);*/

#ifdef WINDOWS
  ExitThread (0);
#else
  pthread_exit (0);
#endif
}

#ifdef WINDOWS
DWORD WINAPI
thread_upd (LPVOID * data)
#else
void *
thread_upd (void *data)
#endif
{
  struct thr_t *thr = (struct thr_t *) data;
  char szout[1024];
  SQLSMALLINT length;
  long i;

  /* Wait until not fired */
#ifdef WINDOWS
  pthread_mutex_lock (&fire_m);
  while (fire == 0)
    sleep (5);
#else
  pthread_mutex_lock (&fire_m);
  while (fire == 0)
    pthread_cond_wait (&fire_c, &fire_m);
  pthread_mutex_unlock (&fire_m);
#endif

  printf ("One Updater threads begin to attack ...\n");

  /* Prepare the connection */
  while (SQLAllocConnect (thr->henv, &thr->hdbc) == SQL_ERROR)
    {
      printf ("Allocation of the connection handle failed\n");
      print_error (thr);
    }
  /* Do the process now */
  while (SQLDriverConnect (thr->hdbc, NULL, (SQLCHAR *) dsn, SQL_NTS,
	  szout, sizeof (szout), &length, SQL_DRIVER_NOPROMPT) == SQL_ERROR)
    {
      printf ("Connection failed on dsn=%s\n", dsn);
      print_error (thr);
    }
  printf ("Connection success for Updater %ld\n", thr->num);
  /* No autocommit set perhaps */
  if (isolation)
    {
      if (SQLSetConnectOption (thr->hdbc, SQL_ATTR_AUTOCOMMIT, (SQLULEN) SQL_AUTOCOMMIT_OFF) == SQL_ERROR)
	{
	  print_error (thr);
	  goto end;
	}
      if (SQLSetConnectOption (thr->hdbc, SQL_ATTR_TXN_ISOLATION, isolation) == SQL_ERROR)
	{
	  print_error (thr);
	  goto end;
	}
    }
  /* Make a loop */
  for (i = 0; i < loop; i++)
    {
      if (SQLAllocStmt (thr->hdbc, &thr->hstmt) == SQL_ERROR)
	{
	  print_error (thr);
	  goto end;
	}
      sprintf (szout, "INSERT INTO LOCKTEST(PK,SOME_CHAR,SOME_DATETIME) VALUES('%ld','CHAR:%ld',NULL)", thr->num * (loop + 1) + i,
	  thr->num * (loop + 1) + i);
      if (SQLPrepare (thr->hstmt, szout, SQL_NTS) == SQL_ERROR)
	{
	  print_error (thr);
	  goto end;
	}
      if (SQLExecute (thr->hstmt) == SQL_ERROR)
	{
	  print_error (thr);
	  goto end;
	}
      if (SQLPrepare (thr->hstmt, "SELECT * FROM LOCKTEST ORDER BY SOME_DATETIME DESC", SQL_NTS) == SQL_ERROR)
	{
	  print_error (thr);
	  goto end;
	}
      switch (SQLExecute (thr->hstmt))
	{
	case SQL_ERROR:
	  print_error (thr);
	  goto end;
	default:
	  while (SQLFetch (thr->hstmt) == SQL_SUCCESS);
	}
      sprintf (szout, "UPDATE LOCKTEST SET SOME_CHAR='CHAR: OK' WHERE PK=%ld", thr->num * (loop + 1) + i);
      if (SQLPrepare (thr->hstmt, szout, SQL_NTS) == SQL_ERROR)
	{
	  print_error (thr);
	  goto end;
	}
      if (SQLExecute (thr->hstmt) == SQL_ERROR)
	{
	  print_error (thr);
	  goto end;
	}
      if (isolation)
	{
	  if (SQLEndTran (SQL_HANDLE_DBC, thr->hdbc, SQL_COMMIT) == SQL_ERROR)
	    {
	      print_error (thr);
	      goto end;
	    }
	}
      if (SQLFreeStmt (thr->hstmt, SQL_CLOSE) == SQL_ERROR)
	{
	  print_error (thr);
	  goto end;
	}
    }

end:
  /* Disconnect now */
  SQLDisconnect (thr->hdbc);
  printf ("One Updater thread less to attack ...\n");

  thr->done = 1;
/*  while(fire == 1) sleep(5); */

#ifdef WINDOWS
  ExitThread (0);
#else
  pthread_exit (0);
#endif
}

int
main (int argc, char **argv)
{
  struct thr_t *array;
  HENV henv;
  long i;


  /* Allocat the environment  */
  SQLAllocEnv (&henv);
  /* Get the arguments */
  if (argc >= 5)
    {
      dsn = argv[1];
      nbupd = atol (argv[2]);
      nbrea = atol (argv[3]);
      loop = atol (argv[4]);
      isolation = atoi (argv[5]);

      array = (struct thr_t *) malloc (sizeof (struct thr_t) * (nbrea + nbupd));
      if (array == NULL)
	{
	  printf ("Allocation failed\n");
	  exit (-1);
	}

      for (i = 0; i < nbrea; i++)
	{
	  printf ("Thread Reader created so far : %ld/%ld\n", i + 1, nbrea);
#ifndef WINDOWS
	  pthread_attr_init (&array[i].pattr);
	  pthread_attr_setdetachstate (&array[i].pattr, PTHREAD_CREATE_JOINABLE);
#endif
	  /* Set some variables */
	  array[i].done = 0;
	  array[i].henv = henv;
	  array[i].hdbc = NULL;
	  array[i].hstmt = NULL;
	  array[i].type = 0;
	  array[i].num = i;
#ifdef WINDOWS
	  array[i].thr = CreateThread (NULL, 0, &thread_rea, &array[i], 0, NULL);
	  if (array[i].thr == NULL)
#else
	  if (pthread_create (&array[i].thr, &array[i].pattr, &thread_rea, &array[i]))
#endif
	    printf ("Problem creating thread number : %ld/%ld\n", i + 1, nbrea);
	}

      for (; i < nbrea + nbupd; i++)
	{
	  printf ("Thread Update created so far : %ld/%ld\n", i + 1 - nbrea, nbupd);
#ifndef WINDOWS
	  pthread_attr_init (&array[i].pattr);
	  pthread_attr_setdetachstate (&array[i].pattr, PTHREAD_CREATE_JOINABLE);
#endif
	  /* Set some variables */
	  array[i].done = 0;
	  array[i].henv = henv;
	  array[i].hdbc = NULL;
	  array[i].hstmt = NULL;
	  array[i].type = 1;
	  array[i].num = i - nbrea;
#ifdef WINDOWS
	  array[i].thr = CreateThread (NULL, 0, &thread_upd, &array[i], 0, NULL);
	  if (array[i].thr == NULL)
#else
	  if (pthread_create (&array[i].thr, &array[i].pattr, &thread_upd, &array[i]))
#endif
	    printf ("Problem creating thread number : %ld/%ld\n", i + 1, nbupd);
	}

      printf ("All threads created ... and fire\n");
      fire = 1;

      pthread_cond_broadcast (&fire_c);

      for (i = 0; i < nbrea + nbupd; i++)
	pthread_join (array[i].thr, NULL);
/*      if(array[i].done == 0)
        { i=-1; continue; }*/


      /* Clean up the mess */

      printf ("END fire\n");
      for (i = 0; i < nbrea + nbupd; i++)
#ifndef WINDOWS
	pthread_attr_destroy (&array[i].pattr);
#else
	CloseHandle (array[i].thr);
#endif
    }

  exit (0);
}

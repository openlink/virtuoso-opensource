/*
 *  mtest.c
 *
 *  $Id$
 *
 *  Fiber test program
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
 *  
*/

#include "Dk.h"


int t3 (void *);
semaphore_t *sem;

#define MY_NAME	(void *)1

/*
#define thread_sleep(X)	thread_wait_cond(NULL, NULL, X)
*/

void
id (void)
{
  time_t now;
  time (&now);
  printf ("%d [%s] ", (int) now,
      (char *) thread_getattr (current_thread, MY_NAME));
}


int
t1 (void *arg)
{
  thread_setattr (current_thread, MY_NAME, arg);
  thread_create (t3, 0, "t3");
  for (;;)
    {
      id ();
      puts ("here");
      thread_allow_schedule ();
      thread_sleep (3000);
    }
}


int
t2 (void *arg)
{
  int i;

  thread_setattr (current_thread, MY_NAME, arg);
  for (;;)
    {
      semaphore_enter (sem);
      for (i = 1; i <= 10; i++)
	{
	  id ();
	  printf ("%d...\n", i);
	  thread_sleep (1000);
	}
      semaphore_leave (sem);
    }
}


int
t3 (void *arg)
{
  int i, j;

  thread_setattr (current_thread, MY_NAME, arg);
  for (j = 0; j < 3; j++)
    {
      semaphore_enter (sem);
      for (i = 1; i <= 10; i++)
	{
	  id ();
	  printf ("%d...\n", i);
	  thread_sleep (100);
	}
      semaphore_leave (sem);
    }
}


int
main ()
{
  sem = semaphore_allocate (1);

  thread_initial (0);	 /* initialize main thread */
  thread_setattr (current_thread, MY_NAME, "Main");

  thread_create (t1, 0, "t1");
  thread_create (t2, 0, "t2");

  for (;;)
    {
      id ();
      printf ("total:%d, wait:%d, dead:%d, runnable:%d\n", _thread_num_total,
	  _thread_num_wait, _thread_num_dead, _thread_num_runnable);
      thread_sleep (500);
    }

  exit (1);
}

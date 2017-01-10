/*
 *  mtest1.c
 *
 *  $Id$
 *
 *  Fiber test program
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
 *  
*/

#include "Dk.h"

#define MY_NAME	(void *)1

char *ev;


void
logme (char *fmt, ...)
{
  char buf[250];
  time_t now;
  va_list (ap);

  va_start (ap, fmt);
  vsprintf (buf, fmt, ap);
  va_end (ap);
  time (&now);
  printf ("%d [%s] %s\n", (int) now,
      (char *) thread_getattr (current_thread, MY_NAME), buf);
}


int
t1 (void *arg)
{
  thread_setattr (current_thread, MY_NAME, arg);

  logme ("Started");
  for (;;)
    {
      logme ("sleep 2 secs");
      thread_sleep (2000);
      logme ("signal event");
      logme ("wakeup retd %d", thread_signal_cond (&ev));
    }
  return 0;
}


int
main ()
{
  thread_initial (0);

  thread_setattr (current_thread, MY_NAME, "Main");

  logme ("Started");
  thread_create (t1, 0, "t1");

  logme ("calling infinite thread_select");
  thread_select (0, NULL, NULL, &ev, TV_INFINITE);
  logme ("Woke up!");

  logme ("calling infinite thread_wait_cond");
  thread_wait_cond (&ev, NULL, TV_INFINITE);
  logme ("Woke up!");

  return 0;
}

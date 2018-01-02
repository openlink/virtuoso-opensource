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
 *  Copyright (C) 1998-2018 OpenLink Software
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

rwlock_t *l;

#if 1
void
thread_sleep (TVAL msec)
{
  sleep (msec / 1000);
}
#endif

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
reader (void *arg)
{
  thread_setattr (current_thread, MY_NAME, arg);

  logme ("Started");
  for (;;)
    {
      rwlock_rdlock (l);
      logme ("read lock acquired, sleeping 3 secs");
      thread_sleep (3000);
      rwlock_unlock (l);
    }
  return 0;
}

int
main ()
{
  l = rwlock_allocate ();

  thread_initial (0);
  thread_setattr (current_thread, MY_NAME, "w");

  logme ("Started");

  rwlock_wrlock (l);
  logme ("write lock acquired (1), sleeping 1 sec");
  thread_create (reader, 0, "r1");
  thread_create (reader, 0, "r2");
  thread_sleep (1000);
  rwlock_unlock (l);
  thread_sleep (1000); /* XXX */

  rwlock_wrlock (l);
  logme ("write lock acquired (2), sleeping 1 sec");
  rwlock_unlock (l);

  thread_sleep (1000);
  return 0;
}

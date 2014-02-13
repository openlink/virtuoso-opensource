/*
 *  thread_rwlock.c
 *
 *  $Id$
 *
 *  Read-write locks implementation
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
 *  
*/

#include "thread_int.h"

struct rwlock_s {
  dk_mutex_t *mtx;
  semaphore_t *read_sem;
  semaphore_t *write_sem;
  int state;        /* 0 = idle  >0 = # of readers  -1 = writer */
  int blocked_writers;
  int blocked_readers;
};

rwlock_t *
rwlock_allocate (void)
{
  NEW_VARZ (rwlock_t, l);

  l->mtx = mutex_allocate ();
  l->read_sem = semaphore_allocate (0);
  l->write_sem = semaphore_allocate (0);
  l->state = 0;
  l->blocked_writers = 0;
  l->blocked_readers = 0;

  return l;
}

void
rwlock_free (rwlock_t *l)
{
  mutex_free (l->mtx);
  semaphore_free (l->read_sem);
  semaphore_free (l->write_sem);
  dk_free (l, sizeof (*l));
}

void
rwlock_rdlock (rwlock_t *l)
{
  mutex_enter (l->mtx);
  while (l->blocked_writers || l->state < 0)
    {
      ++l->blocked_readers;
      mutex_leave (l->mtx);
      semaphore_enter (l->read_sem);
      mutex_enter (l->mtx);
      --l->blocked_readers;
    }
  ++l->state;
  mutex_leave (l->mtx);
}

int
rwlock_tryrdlock (rwlock_t *l)
{
  mutex_enter (l->mtx);
  if (l->blocked_writers || l->state < 0)
    {
      mutex_leave (l->mtx);
      return 0;
    }
  ++l->state;
  mutex_leave (l->mtx);
  return 1;
}

void
rwlock_wrlock (rwlock_t *l)
{
  mutex_enter (l->mtx);
  while (l->state)
    {
      ++l->blocked_writers;
      mutex_leave (l->mtx);
      semaphore_enter (l->write_sem);
      mutex_enter (l->mtx);
      --l->blocked_writers;
    }
  l->state = -1;
  mutex_leave (l->mtx);
}

int
rwlock_trywrlock (rwlock_t *l)
{
  mutex_enter (l->mtx);
  if (l->state)
    {
      mutex_leave (l->mtx);
      return 0;
    }
  l->state = -1;
  mutex_leave (l->mtx);
  return 1;
}

void
rwlock_unlock (rwlock_t *l)
{
  mutex_enter (l->mtx);
  if (l->state > 0)
    {
      if (--l->state == 0 && l->blocked_writers)
        semaphore_leave (l->write_sem);
    }
  else if (l->state < 0)
    {
      l->state = 0;

      if (l->blocked_writers)
        {
          /*
           * wake up a waiting writer
           */
          semaphore_leave (l->write_sem);
        }
      else
        {
          /*
           * wake up all the waiting readers
           */
          int i;

          for (i = 0; i < l->blocked_readers; i++)
            semaphore_leave (l->read_sem);
        }
    }
  mutex_leave (l->mtx);
}

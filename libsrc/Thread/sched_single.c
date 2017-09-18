/*
 *  sched_dummy.c
 *
 *  $Id$
 *
 *  Stubs for NO_THREAD implementation
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

const const char *build_thread_model = "-single";

int _thread_sched_preempt = 0;

int _thread_num_total = 1;	/* total threads in this model */
int _thread_num_runnable = 1;	/* # threads that can be run */
int _thread_num_wait;		/* # threads waiting for something */
int _thread_num_dead;		/* # threads on free list */

static thread_t *_main_thread;


/******************************************************************************
 *
 *  Threads
 *
 ******************************************************************************/

thread_t *
thread_current (void)
{
  return _main_thread;
}


/*
 *  The main thread must call this function to convert itself into a thread.
 */
thread_t *
thread_initial (unsigned long stack_size)
{
  if (_main_thread)
    return _main_thread;
  else
    {
      NEW_VARZ (thread_t, thr);
      _main_thread = thr;
      thr->thr_status = RUNNING;
      thr->thr_sem = semaphore_allocate (0);
      thr->thr_schedule_sem = semaphore_allocate (0);
      _thread_init_attributes (thr);
      thread_set_priority (thr, NORMAL_PRIORITY);
      return thr;
    }
}


thread_t *
thread_create (
    thread_init_func initial_function,
    unsigned long stack_size,
    void *init_arg)
{
  return NULL;
}


thread_t *
thread_attach (void)
{
  return NULL;
}


void
thread_allow_schedule (void)
{
}


void
thread_exit (int n)
{
  exit (n);
}


int *
thread_errno (void)
{
  return &current_thread->thr_err;
}


int
thread_set_priority (thread_t *self, int prio)
{
  int old_prio = self->thr_priority;

  if (prio < 0 && prio >= MAX_PRIORITY)
    return old_prio;

  self->thr_priority = prio;

  return old_prio;
}


int
thread_get_priority (thread_t *self)
{
  return self->thr_priority;
}


#ifdef EXPIRIMENTAL
int
thread_wait_cond (void *event, dk_mutex_t *holds, TVAL timeout)
{
  thread_sleep (timeout);
  return -1;
}


int
thread_signal_cond (void *event)
{
  return 0;
}


int
thread_select (int n, fd_set *rfds, fd_set *wfds, void *event, TVAL timeout)
{
  thread_t *thr = current_thread;
  struct timeval *ptv, tv;
  int rc;

  if (timeout == TV_INFINITE)
    ptv = NULL;
  else
    {
      tv.tv_sec = timeout / 1000;
      tv.tv_usec = (timeout % 1000) * 1000;
      ptv = &tv;
    }

  thr->thr_status = WAITEVENT;

  for (;;)
    {
      if ((rc = select (n, rfds, wfds, NULL, ptv)) == -1)
	{
	  switch (errno)
	    {
	    case EINTR:
	      continue;
	    default:
	      break;
	    }
	  thr_errno = errno;
	}
      else
	thr_errno = 0;
      break;
    }

  thr->thr_status = RUNNING;

  return rc;
}


void
thread_sleep (TVAL timeout)
{
  thread_select (0, NULL, NULL, NULL, timeout);
}
#endif


/******************************************************************************
 *
 *  Semaphores
 *
 ******************************************************************************/

semaphore_t *
semaphore_allocate (int entry_count)
{
  return (semaphore_t *) 1L;
}


void
semaphore_free (semaphore_t *sem)
{
}


int
semaphore_enter (semaphore_t * sem)
{
  return 0;
}


int
semaphore_try_enter (semaphore_t *sem)
{
  return 1;
}


#ifdef SEM_DEBUG
void
semaphore_leave_dbg (int ln, const char *file, semaphore_t *sem)
#else
void
semaphore_leave (semaphore_t *sem)
#endif
{
}

/******************************************************************************
 *
 *  Mutexes
 *
 ******************************************************************************/

dk_mutex_t *
mutex_allocate (void)
{
  return (dk_mutex_t *) 1L;
}

void 
dk_mutex_init (dk_mutex_t * m, int t)
{
}

#if defined (MTX_DEBUG) || defined (MTX_METER)
void
mutex_option (dk_mutex_t * mtx, char * name, mtx_entry_check_t ck, void * cd)
{
}
#endif

#ifdef WIN32
dk_mutex_t *
mutex_allocate_typed (int n)
{
  return mutex_allocate();
}
#endif

void
mutex_free (dk_mutex_t *mtx)
{
}

void
dk_mutex_destroy (dk_mutex_t *mtx)
{
}


#ifdef MTX_DEBUG
int
mutex_enter_dbg (int line, const char * file, dk_mutex_t *mtx)
#else
int
mutex_enter (dk_mutex_t *mtx)
#endif
{
  return 0;
}


int
mutex_try_enter (dk_mutex_t *mtx)
{
  return 1;
}

#ifdef MTX_DEBUG
void
mutex_leave_dbg (int ln, const char * file, dk_mutex_t *mtx)
#else
void
mutex_leave (dk_mutex_t *mtx)
#endif
{
}

/******************************************************************************
 *
 *  Spinlocks
 *
 ******************************************************************************/

/* Pthreads does not support spinlocks, so simulate them by using a mutexes */

spinlock_t *
spinlock_allocate (void)
{
  return (spinlock_t *) 1L;
}


void
spinlock_free (spinlock_t *self)
{
}


void
spinlock_enter (spinlock_t *self)
{
}


void
spinlock_leave (spinlock_t *self)
{
}

#ifdef MTX_DEBUG
#undef mutex_enter
int
mutex_enter (dk_mutex_t * mtx)
{
  return (mutex_enter_dbg (__LINE__, __FILE__, mtx));
}
#endif

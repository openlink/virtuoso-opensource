/*
 *  sched_pthread.c
 *
 *  $Id$
 *
 *  Scheduler for pthreads
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

#include <pthread.h>
#include "Dk.h"

#if defined(linux) && defined(VIRT_GPROF)
#define pthread_create gprof_pthread_create
#endif

char *build_thread_model = "-pthreads";

/* Indicate preemptive scheduling for this model */
int _thread_sched_preempt = 1;

int _thread_num_total;		/* total threads in this model */
int _thread_num_runnable;	/* # threads that can be run */
int _thread_num_wait;		/* # threads waiting for something */
int _thread_num_dead;		/* # threads on free list */


#define thr_event_pipe		thr_nfds

#define Q_LOCK()		pthread_mutex_lock ((pthread_mutex_t*) &_q_lock->mtx_mtx)
#define Q_UNLOCK()		pthread_mutex_unlock ((pthread_mutex_t*) &_q_lock->mtx_mtx)

#define CKRET(X) \
	if (X) \
	  { \
	    _pthread_call_failed (__FILE__, __LINE__, X); \
	    goto failed; \
	  }


static thread_t *_main_thread;
static pthread_key_t _key_current;
static pthread_mutexattr_t _mutex_attr;
static pthread_attr_t _thread_attr;
static thread_queue_t _deadq;
thread_queue_t _waitq;
static dk_mutex_t *_q_lock;
#ifdef EXPIRIMENTAL
static int _ev_pipes[2];
static char _ev_never;
#endif

dk_mutex_t * all_mtxs_mtx;
#ifdef MTX_METER
dk_hash_t * all_mtxs = NULL;
#endif

static void
_pthread_call_failed (const char *file, int line, int error)
{
  char msgbuf[200];

  snprintf (msgbuf, sizeof (msgbuf), "pthread operation failed (%d) %s", error, strerror (error));
#ifdef MTX_DEBUG
  gpf_notice (file, line, msgbuf);
#else
  fprintf (stderr, "%s:%d %s\n", file, line, msgbuf);
#endif
}


static void
_sched_init (void)
{
  _q_lock = mutex_allocate ();

  thread_queue_init (&_deadq);
  thread_queue_init (&_waitq);

  _thread_num_wait = 0;
  _thread_num_dead = 0;
  _thread_num_runnable = -1;	/* not counted */
  _thread_num_total = 1;

#ifdef EXPIRIMENTAL
  io_init ();

  pipe (_ev_pipes);
  thread_nb_fd (_ev_pipes[0]);
  thread_nb_fd (_ev_pipes[1]);
#endif
#ifdef MTX_METER
  all_mtxs_mtx = mutex_allocate ();
  all_mtxs = hash_table_allocate (10000);
  all_mtxs->ht_rehash_threshold = 2;
#endif
}


/******************************************************************************
 *
 *  Threads
 *
 ******************************************************************************/

thread_t *
thread_current (void)
{
#ifndef OLD_PTHREADS
  return (thread_t *) pthread_getspecific (_key_current);

#else
  void *value;

  if (pthread_getspecific (_key_current, &value) == -1)
    return NULL;

  return value;
#endif
}


/*
 *  Allocates a condition variable
 */
static void *
_alloc_cv (void)
{
  NEW_VAR (pthread_cond_t, cv);
  int rc;

  memset ((void *) cv, 0, sizeof (pthread_cond_t));
#ifndef OLD_PTHREADS
  rc = pthread_cond_init (cv, NULL);
#else
  rc = pthread_cond_init (cv, pthread_condattr_default);
#endif
  CKRET (rc);

  return (void *) cv;

failed:
  dk_free ((void *) cv, sizeof (pthread_cond_t));
  return NULL;
}


/*
 *  The main thread must call this function to convert itself into a thread.
 */
thread_t *
thread_initial (unsigned long stack_size)
{
  int rc;
  thread_t *thr = NULL;

  if (_main_thread)
    return _main_thread;

  /*
   *  Initialize pthread key
   */
#ifndef OLD_PTHREADS
  rc = pthread_key_create (&_key_current, NULL);
#else
  rc = pthread_keycreate (&_key_current, NULL);
#endif
  CKRET (rc);

  /*
   *  Start off with a value of NULL
   */
  rc = pthread_setspecific (_key_current, NULL);
  CKRET (rc);

  /*
   *  Initialize default thread/mutex attributes
   */
#ifndef OLD_PTHREADS
  /* attribute for thread creation */
  rc = pthread_attr_init (&_thread_attr);
  CKRET (rc);

  /* attribute for mutex creation */
  rc = pthread_mutexattr_init (&_mutex_attr);
  CKRET (rc);
#else
  rc = pthread_attr_create (&_thread_attr);
  CKRET (rc);

  rc = pthread_mutexattr_create (&_mutex_attr);
  CKRET (rc);
#endif

#if defined (PTHREAD_PROCESS_PRIVATE) && !defined(oldlinux) && !defined(__FreeBSD__)
  rc = pthread_mutexattr_setpshared (&_mutex_attr, PTHREAD_PROCESS_PRIVATE);
  CKRET (rc);
#endif

#if defined (MUTEX_FAST_NP) && !defined (_AIX)
  rc = pthread_mutexattr_setkind_np (&_mutex_attr, MUTEX_FAST_NP);
  CKRET (rc);
#endif

#ifdef PTHREAD_ADAPTIVE_MUTEX_INITIALIZER_NP
  rc = pthread_mutexattr_settype (&_mutex_attr, PTHREAD_MUTEX_ADAPTIVE_NP);
  CKRET (rc);
#endif

  /*
   *  Allocate a thread structure
   */
  thr = (thread_t *) dk_alloc (sizeof (thread_t));
  memset (thr, 0, sizeof (thread_t));

  assert (_main_thread == NULL);
  _main_thread = thr;

  _sched_init ();

  if (stack_size == 0)
    stack_size = MAIN_STACK_SIZE;

#if (SIZEOF_VOID_P == 8)
  stack_size *= 2;
#endif
#if defined (__x86_64 ) && defined (SOLARIS)
  /*GK: the LDAP on that platform requires that */
  stack_size *= 2;
#endif


  stack_size = ((stack_size / 8192) + 1) * 8192;

  thr->thr_stack_size = stack_size;
  thr->thr_stack_base = (void *) &stack_size;
  thr->thr_status = RUNNING;
  thr->thr_cv = _alloc_cv ();
  thr->thr_sem = semaphore_allocate (0);
  thr->thr_schedule_sem = semaphore_allocate (0);
  if (thr->thr_cv == NULL)
    goto failed;
  _thread_init_attributes (thr);
  thread_set_priority (thr, NORMAL_PRIORITY);

  rc = pthread_setspecific (_key_current, thr);
  CKRET (rc);

  return thr;

failed:
  if (thr)
    {
      _thread_free_attributes (thr);
      dk_free (thr, sizeof (thread_t));
    }
  return NULL;
}


static void *
_thread_boot (void *arg)
{
  thread_t *thr = (thread_t *) arg;
  int rc;

  rc = pthread_setspecific (_key_current, thr);
  CKRET (rc);

  /* Store the context so we can easily restart a dead thread */
  setjmp (thr->thr_init_context);

  thr->thr_status = RUNNING;
  _thread_init_attributes (thr);
  thr->thr_stack_base = (void *) &arg;

  rc = (*thr->thr_initial_function) (thr->thr_initial_argument);

  /* thread died, put it on the dead queue */
  thread_exit (rc);

  /* We should never come here */
  GPF_T;

failed:
  return (void *) 1L;
}


static thread_t *
thread_alloc ()
{
  thread_t *thr;

  thr = (thread_t *) dk_alloc (sizeof (thread_t));
  memset (thr, 0, sizeof (thread_t));
  thr->thr_status = RUNNABLE;
  thr->thr_handle = dk_alloc (sizeof (pthread_t));
  thr->thr_cv = _alloc_cv ();
  thr->thr_sem = semaphore_allocate (0);
  thr->thr_schedule_sem = semaphore_allocate (0);

  return thr;
}


thread_t *
thread_create (
    thread_init_func initial_function,
    unsigned long stack_size,
    void *initial_argument)
{
  thread_t *thr;
  int rc;

  assert (_main_thread != NULL);

  if (stack_size == 0)
    stack_size = THREAD_STACK_SIZE;

#if (SIZEOF_VOID_P == 8)
  stack_size *= 2;
#endif
#if defined (__x86_64 ) && defined (SOLARIS)
  /*GK: the LDAP on that platform requires that */
  stack_size *= 2;
#endif
#ifdef HPUX_ITANIUM64
  stack_size += 8 * 8192;
#endif

  stack_size = ((stack_size / 8192) + 1) * 8192;

#if defined (PTHREAD_STACK_MIN)
  if (stack_size < PTHREAD_STACK_MIN)
    {
      stack_size = PTHREAD_STACK_MIN;
    }
#endif
  /* Any free threads with the right stack size? */
  Q_LOCK ();
  for (thr = (thread_t *) _deadq.thq_head.thr_next;
       thr != (thread_t *) &_deadq.thq_head;
       thr = (thread_t *) thr->thr_hdr.thr_next)
    {
      if (thr->thr_stack_size >= stack_size) 
	break;
    }
  Q_UNLOCK ();

  /* No free threads, create a new one */
  if (thr == (thread_t *) &_deadq.thq_head)
    {
#ifndef OLD_PTHREADS
#if defined(HAVE_PTHREAD_ATTR_GETSTACKSIZE)
      size_t os_stack_size = stack_size;
#endif
#endif
      thr = thread_alloc ();
      thr->thr_initial_function = initial_function;
      thr->thr_initial_argument = initial_argument;
      thr->thr_stack_size = stack_size;
      if (thr->thr_cv == NULL)
	goto failed;

#ifdef HPUX_ITANIUM64
      if (stack_size > PTHREAD_STACK_MIN)
        {
	  size_t s, rses;
          pthread_attr_getstacksize (&_thread_attr, &s);
	  pthread_attr_getrsestacksize_np (&_thread_attr, &rses);
	  log_error ("default rses=%d stack=%d : %m", rses,s);
	}
#endif


#ifndef OLD_PTHREADS
# if  defined(HAVE_PTHREAD_ATTR_SETSTACKSIZE)
      rc = pthread_attr_setstacksize (&_thread_attr, stack_size);
      if (rc)
	{
          log_error ("Failed setting the OS thread stack size to %d : %m", stack_size);
	}
# endif

#if defined(HAVE_PTHREAD_ATTR_GETSTACKSIZE)
      if (0 == pthread_attr_getstacksize (&_thread_attr, &os_stack_size))
	{
	  if (os_stack_size > 4 * 8192)
	    stack_size = thr->thr_stack_size = ((unsigned long) os_stack_size) - 4 * 8192;
	}
#endif
#ifdef HPUX_ITANIUM64
      if (stack_size > PTHREAD_STACK_MIN)
        {
	  size_t rsestack_size = stack_size / 2;
          rc = pthread_attr_setrsestacksize_np (&_thread_attr, rsestack_size);
	  if (rc)
	    {
	      log_error ("Failed setting the OS thread 'rse' stack size to %d (plain stack size set to %d) : %m", rsestack_size, stack_size);
	    }
	  thr->thr_stack_size /= 2;
	}
#endif

      rc = pthread_create ((pthread_t *) thr->thr_handle, &_thread_attr,
	  _thread_boot, thr);
      CKRET (rc);

      /* rc = pthread_detach (*(pthread_t *) thr->thr_handle); */
      /* CKRET (rc); */

#else /* OLD_PTHREAD */
      rc = pthread_attr_setstacksize (&_thread_attr, stack_size);
      CKRET (rc);

      rc = pthread_create ((pthread_t *) thr->thr_handle, _thread_attr,
	  _thread_boot, thr);
      CKRET (rc);

      /* rc = pthread_detach ((pthread_t *) thr->thr_handle); */
      /* CKRET (rc); */
#endif

      _thread_num_total++;
#if 0
      if (DO_LOG(LOG_THR))
	log_info ("THRD_0 OS threads create (%i)", _thread_num_total);
#endif
      thread_set_priority (thr, NORMAL_PRIORITY);
    }
  else
    {
      Q_LOCK ();
      thread_queue_remove (&_deadq, thr);
      _thread_num_dead--;
      Q_UNLOCK ();
      assert (thr->thr_status == DEAD);
      /* Set new context for the thread and resume it */
      thr->thr_initial_function = initial_function;
      thr->thr_initial_argument = initial_argument;
      thr->thr_status = RUNNABLE;
      rc = pthread_cond_signal ((pthread_cond_t *) thr->thr_cv);
      CKRET (rc);
/*    if (DO_LOG(LOG_THR))
	log_info ("THRD_3 OS threads reuse. Info threads - total (%ld) wait (%ld) dead (%ld)",
            _thread_num_total, _thread_num_wait, _thread_num_dead);*/
    }

  return thr;

failed:
  if (thr->thr_status == RUNNABLE)
    {
      _thread_free_attributes (thr);
      dk_free (thr, sizeof (thread_t));
    }
  return NULL;
}


thread_t *
thread_attach (void)
{
  thread_t *thr;
  int rc;

  thr = thread_alloc ();
  thr->thr_stack_size = (unsigned long) -1;
  thr->thr_attached = 1;
  if (thr->thr_cv == NULL)
    goto failed;

  *((pthread_t *) thr->thr_handle) = pthread_self ();

  rc = pthread_setspecific (_key_current, thr);
  CKRET (rc);

  /* Store the context so we can easily restart a dead thread */
  setjmp (thr->thr_init_context);

  thr->thr_status = RUNNING;
  _thread_init_attributes (thr);
  thr->thr_stack_base = 0;

  return thr;

failed:
  if (thr->thr_sem)
    semaphore_free (thr->thr_sem);
  if (thr->thr_schedule_sem)
    semaphore_free (thr->thr_schedule_sem);
  if (thr->thr_handle)
    dk_free (thr->thr_handle, sizeof (pthread_t));
  dk_free (thr, sizeof (thread_t));
  return NULL;
}


void
thread_allow_schedule (void)
{
#if 0
  pthread_yield ();
#endif
}


void
thread_exit (int n)
{
  thread_t *thr = current_thread;
  volatile int is_attached = thr->thr_attached;

  if (thr == _main_thread)
    {
      call_exit (n);
    }

  thr->thr_retcode = n;
  thr->thr_status = DEAD;

  if (is_attached)
    {
      thr->thr_status = TERMINATE;
      goto terminate;
    }

  Q_LOCK ();
  thread_queue_to (&_deadq, thr);
  _thread_num_dead++;

  do
    {
      int rc = pthread_cond_wait ((pthread_cond_t *) thr->thr_cv, (pthread_mutex_t*) &_q_lock->mtx_mtx);
      CKRET (rc);
    } while (thr->thr_status == DEAD);
  Q_UNLOCK ();

  if (thr->thr_status == TERMINATE)
    goto terminate;
  /* Jumps back into _thread_boot */
  longjmp (thr->thr_init_context, 1);

failed:
  thread_queue_remove (&_deadq, thr);
  _thread_num_dead--;
  Q_UNLOCK ();
terminate:
  if (thr->thr_status == TERMINATE)
    {
#ifndef OLD_PTHREADS
      pthread_detach (* (pthread_t *)thr->thr_handle);
#else
      pthread_detach ( (pthread_t *)thr->thr_handle);
#endif
      _thread_free_attributes (thr);
      dk_free ((void *) thr->thr_cv, sizeof (pthread_cond_t));
      semaphore_free (thr->thr_sem);
      semaphore_free (thr->thr_schedule_sem);
      dk_free (thr->thr_handle, sizeof (pthread_t));
      thr_free_alloc_cache (thr);
      dk_free (thr, sizeof (thread_t));
    }
  if (!is_attached)
    {
      _thread_num_total--;
      pthread_exit ((void *) 1L);
    }
}

#if 1
int
thread_release_dead_threads (int leave_count)
{
  thread_t *thr;
  int rc;
  long thread_killed = 0;
  thread_queue_t term;

  Q_LOCK ();
  if (_deadq.thq_count <= leave_count)
    {
      Q_UNLOCK ();
      return 0;
    }
  thread_queue_init (&term);
  while (_deadq.thq_count > leave_count)
    {
      thr = thread_queue_from (&_deadq);
      if (!thr)
	break;
      _thread_num_dead--;
      thread_queue_to (&term, thr);
    }
  Q_UNLOCK ();

  while (NULL != (thr = thread_queue_from (&term)))
    {
      thr->thr_status = TERMINATE;
      rc = pthread_cond_signal ((pthread_cond_t *) thr->thr_cv);
      CKRET (rc);
      thread_killed++;
    }
#if 0
  if (thread_killed)
    log_info ("%ld OS threads released", thread_killed);
#endif
  return thread_killed;
failed:
  GPF_T1("Thread restart failed");
  return 0;
}
#endif

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

#if defined (PRI_RR_MIN) && !defined(__osf__)
  switch (prio)
    {
    case LOW_PRIORITY:
      prio = PRI_RR_MIN;
      break;
    case NORMAL_PRIORITY:
      prio = (PRI_RR_MIN + PRI_RR_MAX) / 2;
      break;
    case HIGH_PRIORITY:
      prio = PRI_RR_MAX;
      break;
    default:
      return old_prio;
    }

  /*
   *  Cannot set priority on main thread, because it does not have a handle
   */
  if (self != _main_thread &&
      pthread_setprio (*(pthread_t *) self->thr_handle, prio))
    {
	prio = old_prio;
    }
#endif

  self->thr_priority = prio;

  return old_prio;
}


int
thread_get_priority (thread_t *self)
{
  return self->thr_priority;
}


#ifdef EXPIRIMENTAL
/*
 *  Wait for an event to happen.
 *
 *  If holds != NULL, the caller holds the mutex, which will be released
 *  before going to sleep. The thread calling thread_signal_cond *must* hold
 *  the same mutex.
 *
 *  The holds mutex is reacquired after wakeup.
 */
int
thread_wait_cond (void *event, dk_mutex_t *holds, TVAL timeout)
{
  thread_t *thr = current_thread;
  dk_mutex_t *mtx;
  int ok;

  thr->thr_status = WAITEVENT;
  thr->thr_event = event ? event : &_ev_never;
  thr->thr_event_pipe = -1;

  mtx = holds ? holds : _q_lock;

  Q_LOCK ();
  do
    {
      thread_queue_to (&_waitq, thr);
      _thread_num_wait++;

      if (holds)
	Q_UNLOCK ();

      if (timeout == TV_INFINITE)
	ok = pthread_cond_wait (thr->thr_cv, &mtx->mtx_mtx);
      else
	{
	  struct timespec to;
	  struct timeval now;
	  gettimeofday (&now, NULL);
	  to.tv_sec = now.tv_sec + timeout / 1000;
	  to.tv_nsec = now.tv_usec + 1000 * (timeout % 1000);
	  if (to.tv_nsec > 1000000)
	    {
	      to.tv_nsec -= 1000000;
	      to.tv_sec++;
	    }
	  ok = pthread_cond_timedwait (thr->thr_cv, &mtx->mtx_mtx, &to);
	}
      if (holds)
	Q_LOCK ();
      thread_queue_remove (&_waitq, thr);
      _thread_num_wait--;
    } while (ok == 0 && thr->thr_event);
  Q_UNLOCK ();
  CKRET (ok);

failed:
  thr->thr_status = RUNNING;
  return thr->thr_event == NULL ? 0 : -1;
}


/*
 *  Wake up all threads waiting for an event.
 */
int
thread_signal_cond (void *event)
{
  thread_t *thr;
  thread_t *next;
  int count;
  char dummy;

  count = 0;
  Q_LOCK ();
  for (thr = (thread_t *) _waitq.thq_head.thr_next;
      thr != (thread_t *) &_waitq.thq_head;
      thr = next)
    {
      next = (thread_t *) thr->thr_hdr.thr_next;
      if (thr->thr_event == event)
	{
	  thr->thr_event = NULL;
	  if (thr->thr_event_pipe == -1)
	    pthread_cond_signal (thr->thr_cv);
	  else
	    /*
	     *  Wake up the select
	     *  XXX Should fix this - only one thread can safely wait
	     *  for an event in thread_select at a time.
	     */
	    write (thr->thr_event_pipe, &dummy, 1);
	  count++;
	}
    }
  Q_UNLOCK ();

  return count;
}


int
thread_select (int n, fd_set *rfds, fd_set *wfds, void *event, TVAL timeout)
{
  thread_t *thr = current_thread;
  struct timeval *ptv, tv;
  char dummy;
  int rc;

  if (timeout == TV_INFINITE)
    ptv = NULL;
  else
    {
      tv.tv_sec = timeout / 1000;
      tv.tv_usec = (timeout % 1000) * 1000;
      ptv = &tv;
    }

  if (event)
    {
      thr->thr_event = event;
      thr->thr_event_pipe = _ev_pipes[1];
      if (rfds == NULL)
	rfds = &thr->thr_rfds;
      FD_SET (_ev_pipes[0], rfds);
      if (_ev_pipes[0] >= n)
	n = _ev_pipes[0] + 1;
      Q_LOCK ();
      thread_queue_to (&_waitq, thr);
      Q_UNLOCK ();
    }

  _thread_num_wait++;
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
  _thread_num_wait--;

  if (event)
    {
      thr->thr_event = NULL;
      thr->thr_event_pipe = -1;
      if (rc > 0 && FD_ISSET (_ev_pipes[0], rfds))
	{
	  read (_ev_pipes[0], &dummy, 1);
	  rc = 0;
	}
      Q_LOCK ();
      thread_queue_remove (&_waitq, thr);
      Q_UNLOCK ();
    }

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
  NEW_VAR (pthread_mutex_t, ptm);
  NEW_VAR (semaphore_t, sem);
  int rc;

  memset ((void *) ptm, 0, sizeof (pthread_mutex_t));
#ifndef OLD_PTHREADS
  rc = pthread_mutex_init (ptm, &_mutex_attr);
#else
  rc = pthread_mutex_init (ptm, _mutex_attr);
#endif
  CKRET (rc);

  sem->sem_entry_count = entry_count;
  sem->sem_handle = (void *) ptm;
#ifdef SEM_NO_ORDER
  sem->sem_cv = _alloc_cv ();
  if (!sem->sem_cv) goto failed;
  sem->sem_n_signalled = 0;
  sem->sem_last_signalled = 0;
#endif
  thread_queue_init (&sem->sem_waiting);
  return sem;

failed:
  dk_free ((void *) ptm, sizeof (pthread_mutex_t));
  dk_free (sem, sizeof (semaphore_t));
  return NULL;
}


void
semaphore_free (semaphore_t *sem)
{
  pthread_mutex_destroy ((pthread_mutex_t*) sem->sem_handle);
  dk_free (sem->sem_handle, sizeof (pthread_mutex_t));
#ifdef SEM_NO_ORDER
  dk_free (sem->sem_cv, sizeof (pthread_cond_t));
#endif
  dk_free (sem, sizeof (semaphore_t));
}


int
semaphore_enter (semaphore_t * sem)
{
  thread_t *thr = current_thread;
  int rc;

  rc = pthread_mutex_lock ((pthread_mutex_t*) sem->sem_handle);
  CKRET (rc);

  if (sem->sem_entry_count)
    sem->sem_entry_count--;
  else
    {
#ifndef SEM_NO_ORDER
      thread_queue_to (&sem->sem_waiting, thr);
      _thread_num_wait++;
      thr->thr_status = WAITSEM;
      do
	{
	  rc = pthread_cond_wait ((pthread_cond_t *) thr->thr_cv, (pthread_mutex_t*) sem->sem_handle);
	  CKRET (rc);
	} while (thr->thr_status == WAITSEM);
#else      
      thread_queue_to (&sem->sem_waiting, thr);
      _thread_num_wait++;
      thr->thr_status = WAITSEM;
      do 
	{
	  rc = pthread_cond_wait ((pthread_cond_t *) sem->sem_cv, (pthread_mutex_t*) sem->sem_handle);
	  CKRET (rc);
	}
      while (sem->sem_n_signalled == sem->sem_last_signalled); 
      sem->sem_n_signalled --; /* this one is signalled */
      sem->sem_last_signalled = sem->sem_n_signalled;
      thr->thr_status = RUNNING;
      thread_queue_remove (&sem->sem_waiting, thr);
      if (sem->sem_n_signalled < 0) GPF_T1 ("The semaphore counter went wrong");
#endif
    }

  pthread_mutex_unlock ((pthread_mutex_t*) sem->sem_handle);

  return 0;

failed:
  GPF_T1 ("semaphore_enter() failed");
  return -1;
}


int
semaphore_try_enter (semaphore_t *sem)
{
  int rc;

  rc = pthread_mutex_lock ((pthread_mutex_t*) sem->sem_handle);
  CKRET (rc);

  if (sem->sem_entry_count)
    {
      sem->sem_entry_count--;	/* IvAn: this decrement was added. */
      pthread_mutex_unlock ((pthread_mutex_t*) sem->sem_handle);
      return 1;
    }

  pthread_mutex_unlock ((pthread_mutex_t*) sem->sem_handle);

failed:
  return 0;
}


#ifdef SEM_DEBUG
void
semaphore_leave_dbg (int ln, const char *file, semaphore_t *sem)
#else
void
semaphore_leave (semaphore_t *sem)
#endif
{
  thread_t *thr;
  int rc;

  rc = pthread_mutex_lock ((pthread_mutex_t*) sem->sem_handle);
  CKRET (rc);

#ifdef SEM_DEBUG
    {
      int inx;
      if (304 == ln && sem->sem_entry_count) GPF_T1 ("should have 0 count when signalling clrg_wait");
      for (inx = MAX_SEM_ENT - 1; inx > 0; inx--)
	{
	  sem->sem_last_left_line[inx] = sem->sem_last_left_line[inx - 1];
	  sem->sem_last_left_file[inx] = sem->sem_last_left_file[inx - 1];
	}
      sem->sem_last_left_line[0] = ln;
      sem->sem_last_left_file[0] = file;
    }
#endif
  if (sem->sem_entry_count)
    sem->sem_entry_count++;
  else
    {
#ifndef SEM_NO_ORDER
      thr = thread_queue_from (&sem->sem_waiting);
      if (thr)
	{
	  _thread_num_wait--;
	  assert (thr->thr_status == WAITSEM);
	  thr->thr_status = RUNNING;
	  pthread_cond_signal ((pthread_cond_t *) thr->thr_cv);
	}
      else
	sem->sem_entry_count++;
#else
      if (sem->sem_waiting.thq_count > sem->sem_n_signalled) /* we have a more waiting threads than already signalled */
	{
	  _thread_num_wait--;
	  sem->sem_n_signalled ++; /* one thread will be released */
	  pthread_cond_signal ((pthread_cond_t *) sem->sem_cv);
	}
      else
	sem->sem_entry_count++;
#endif
    }

  rc = pthread_mutex_unlock ((pthread_mutex_t*) sem->sem_handle);
  CKRET (rc);
  return;

failed:
  GPF_T1 ("semaphore_leave() failed");
}

/******************************************************************************
 *
 *  Mutexes
 *
 ******************************************************************************/


dk_mutex_t *
mutex_allocate_typed (int type)
{
  int rc;
  static int is_initialized = 0;
  NEW_VARZ (dk_mutex_t, mtx);
  mtx->mtx_type = type;
#if HAVE_SPINLOCK
  if (MUTEX_TYPE_SPIN == type)
    {
      pthread_spin_init (&mtx->l.spinl, 0);
    }
  else
#endif
    {
      memset ((void *) &mtx->mtx_mtx, 0, sizeof (pthread_mutex_t));
#ifndef OLD_PTHREADS
      if (!is_initialized)
	{
	  pthread_mutexattr_init (&_mutex_attr);
#if defined (PTHREAD_PROCESS_PRIVATE) && !defined(oldlinux) && !defined (__FreeBSD__)	  
	  rc = pthread_mutexattr_setpshared (&_mutex_attr, PTHREAD_PROCESS_PRIVATE);
	  CKRET (rc);
#endif

#ifdef PTHREAD_ADAPTIVE_MUTEX_INITIALIZER_NP
	  rc = pthread_mutexattr_settype (&_mutex_attr, PTHREAD_MUTEX_ADAPTIVE_NP);
	  CKRET (rc);
#endif
	  is_initialized = 1;
	}
      rc = pthread_mutex_init (&mtx->mtx_mtx, &_mutex_attr);
#else
      rc = pthread_mutex_init (&mtx->mtx_mtx, _mutex_attr);
#endif
      CKRET (rc);
    }
#ifdef MTX_DEBUG
  mtx->mtx_owner = NULL;
#endif
#ifdef MTX_METER
  if (all_mtxs_mtx)
    {
      mutex_enter (all_mtxs_mtx);
      sethash ((void*)mtx, all_mtxs, (void*)1);
      mutex_leave (all_mtxs_mtx);
    }
#endif
  return mtx;

failed:
  dk_free (mtx, sizeof (dk_mutex_t));
  return NULL;
}


void
dk_mutex_init (dk_mutex_t * mtx, int type)
{
  int rc;
  static int is_initialized = 0;
  static pthread_mutexattr_t _attr;
  memset (mtx, 0, sizeof (dk_mutex_t));

  mtx->mtx_type = type;
#if HAVE_SPINLOCK
  if (MUTEX_TYPE_SPIN == type)
    {
      pthread_spin_init (&mtx->l.spinl, 0);
    }
  else
#endif
    {
            memset ((void *) &mtx->mtx_mtx, 0, sizeof (pthread_mutex_t));
#ifndef OLD_PTHREADS
      if (!is_initialized) 
	{
	  pthread_mutexattr_init (&_attr);
#if defined (PTHREAD_PROCESS_PRIVATE) && !defined (__FreeBSD__) && !defined(oldlinux)
	  rc = pthread_mutexattr_setpshared (&_attr, PTHREAD_PROCESS_PRIVATE);
	  CKRET (rc);
#endif	  

#ifdef PTHREAD_ADAPTIVE_MUTEX_INITIALIZER_NP
	  rc = pthread_mutexattr_settype (&_attr, PTHREAD_MUTEX_ADAPTIVE_NP);
	  CKRET (rc);
#endif
	  is_initialized = 1;
	}
      rc = pthread_mutex_init (&mtx->mtx_mtx, &_attr);
#else
      rc = pthread_mutex_init (&mtx->mtx_mtx, _mutex_attr);
#endif
      CKRET (rc);
    }
#ifdef MTX_DEBUG
  mtx->mtx_owner = NULL;
#endif
#ifdef MTX_METER
  if (all_mtxs_mtx)
    {
      mutex_enter (all_mtxs_mtx);
      sethash ((void*)mtx, all_mtxs, (void*)1);
      mutex_leave (all_mtxs_mtx);
    }
#endif
  return;
 failed: ;
}


dk_mutex_t *
mutex_allocate ()
{
  return mutex_allocate_typed (MUTEX_TYPE_SHORT);
}


void
mutex_free (dk_mutex_t *mtx)
{
#if HAVE_SPINLOCK
  if (MUTEX_TYPE_SPIN == mtx->mtx_type)
    {
      pthread_spin_destroy (&mtx->l.spinl);
    }
  else
#endif
    {
      pthread_mutex_destroy ((pthread_mutex_t*) &mtx->mtx_mtx);
    }
#ifdef MTX_DEBUG
  dk_free_box (mtx->mtx_name);
#endif
#ifdef MTX_METER
  mutex_enter (all_mtxs_mtx);
  remhash ((void*) mtx, all_mtxs);
  mutex_leave (all_mtxs_mtx);
#endif
  dk_free (mtx, sizeof (dk_mutex_t));
}


void
dk_mutex_destroy (dk_mutex_t *mtx)
{
#if HAVE_SPINLOCK
  if (MUTEX_TYPE_SPIN == mtx->mtx_type)
    {
      pthread_spin_destroy (&mtx->l.spinl);
    }
  else
#endif
    {
      pthread_mutex_destroy ((pthread_mutex_t*) &mtx->mtx_mtx);
    }
#ifdef MTX_DEBUG
  dk_free_box (mtx->mtx_name);
#endif
#ifdef MTX_METER
  mutex_enter (all_mtxs_mtx);
  remhash ((void*) mtx, all_mtxs);
  mutex_leave (all_mtxs_mtx);
#endif
}

#if defined (MTX_DEBUG) || defined (MTX_METER)
void
mutex_option (dk_mutex_t * mtx, char * name, mtx_entry_check_t ck, void * cd)
{
  dk_free_box (mtx->mtx_name);
  mtx->mtx_name = box_dv_short_string (name);
#ifdef MTX_DEBUG

  mtx->mtx_entry_check = ck;
  mtx->mtx_entry_check_cd = cd;
#endif
}
#endif

#if defined(OLD_PTHREADS)
#define TRYLOCK_SUCCESS 1
#else
#define TRYLOCK_SUCCESS 0
#endif

#define MTX_MAX_SPINS 200 
#undef mutex_enter
#undef mutex_leave 

#ifdef APP_SPIN 
#ifdef MTX_DEBUG
int
mutex_enter_dbg (int line, const char * file, dk_mutex_t *mtx)
#else
int
mutex_enter (dk_mutex_t *mtx)
#endif
{
#ifdef MTX_DEBUG
  du_thread_t * self = thread_current ();
#endif
  int rc;

#ifdef MTX_DEBUG
  assert (mtx->mtx_owner !=  self || !self);
  if (mtx->mtx_entry_check
      && !mtx->mtx_entry_check (mtx, self, mtx->mtx_entry_check_cd))
    GPF_T1 ("Mtx entry check fail");
#endif
  if (mtx->mtx_spins < MTX_MAX_SPINS)
    {
      int ctr;
      for (ctr = 0; ctr < MTX_MAX_SPINS; ctr++)
	{
	  if (TRYLOCK_SUCCESS == pthread_mutex_trylock (&mtx->mtx_mtx))
	    {
#ifdef MTX_METER 
	      if (ctr > 0)
		mtx->mtx_spin_waits++;
#endif 
	      mtx->mtx_spins += (ctr - mtx->mtx_spins) / 8;
	      goto got_it;
	    }
	}
      mtx->mtx_spins = MTX_MAX_SPINS;
    }
  else 
    {
      if (++mtx->mtx_spins > 10 +  MTX_MAX_SPINS)
	mtx->mtx_spins = 0;
    }
  pthread_mutex_lock (&mtx->mtx_mtx);
#ifdef MTX_METER 
  mtx->mtx_waits++;
#endif
 got_it:
#ifdef MTX_METER
      mtx->mtx_enters++;
#endif

#ifdef MTX_DEBUG
  assert (mtx->mtx_owner == NULL);
  mtx->mtx_owner = self;
  mtx->mtx_entry_file = (char *) file;
  mtx->mtx_entry_line = line;
#endif
  return 0;

failed:
  GPF_T1 ("mutex_enter() failed");
  return -1;
}

#else
#ifdef MTX_DEBUG
int
mutex_enter_dbg (int line, const char * file, dk_mutex_t *mtx)
#else
int
mutex_enter (dk_mutex_t *mtx)
#endif
{
#ifdef MTX_DEBUG
  du_thread_t * self = thread_current ();
#endif
  int rc;

#ifdef MTX_DEBUG
  assert (mtx->mtx_owner !=  self || !self);
  if (mtx->mtx_entry_check
      && !mtx->mtx_entry_check (mtx, self, mtx->mtx_entry_check_cd))
    GPF_T1 ("Mtx entry check fail");
#endif
#ifdef MTX_METER
#if HAVE_SPINLOCK
  if (MUTEX_TYPE_SPIN == mtx->mtx_type)
    rc = pthread_spin_trylock (&mtx->l.spinl);
  else 
#endif
    rc = pthread_mutex_trylock ((pthread_mutex_t*) &mtx->mtx_mtx);
  if (TRYLOCK_SUCCESS != rc)
    {
      long long wait_ts = rdtsc ();
      static int unnamed_waits;
#if HAVE_SPINLOCK
      if (MUTEX_TYPE_SPIN == mtx->mtx_type)
	rc = pthread_spin_lock (&mtx->l.spinl);
      else
#endif
	rc = pthread_mutex_lock ((pthread_mutex_t*) &mtx->mtx_mtx);
      mtx->mtx_wait_clocks += rdtsc () - wait_ts;
      mtx->mtx_waits++;
      if (!mtx->mtx_name)
	unnamed_waits++; /*for dbg breakpoint */
      mtx->mtx_enters++;
    }
  else
    mtx->mtx_enters++;
#else
#if HAVE_SPINLOCK
  if (MUTEX_TYPE_SPIN == mtx->mtx_type)
    rc = pthread_spin_lock (&mtx->l.spinl);
  else
#endif
    rc = pthread_mutex_lock ((pthread_mutex_t*) &mtx->mtx_mtx);
#endif
  CKRET (rc);
#ifdef MTX_DEBUG
  assert (mtx->mtx_owner == NULL);
  mtx->mtx_owner = self;
  mtx->mtx_entry_file = (char *) file;
  mtx->mtx_entry_line = line;
#endif
  return 0;

failed:
  GPF_T1 ("mutex_enter() failed");
  return -1;
}
#endif /* APP_SPIN */



#ifdef MTX_DEBUG

#undef mutex_enter

int
mutex_enter (dk_mutex_t * mtx)
{
  return (mutex_enter_dbg (__LINE__, __FILE__, mtx));
}

#undef mutex_leave

void
mutex_leave (dk_mutex_t * mtx)
{
  mutex_leave_dbg (__LINE__, __FILE__, mtx);
}

#endif


int
mutex_try_enter (dk_mutex_t *mtx)
{
#ifndef MTX_DEBUG
#if HAVE_SPINLOCK
  if (MUTEX_TYPE_SPIN == mtx->mtx_type)
    return pthread_spin_trylock (&mtx->l.spinl) == TRYLOCK_SUCCESS ? 1 : 0;
  else
#endif
    return pthread_mutex_trylock ((pthread_mutex_t *) &mtx->mtx_mtx) == TRYLOCK_SUCCESS ? 1 : 0;
#else

  if (
#if HAVE_SPINLOCK
      MUTEX_TYPE_SPIN == mtx->mtx_type 
      ? pthread_spin_trylock (&mtx->l.spinl) == TRYLOCK_SUCCESS
      : 
#endif
      pthread_mutex_trylock ((pthread_mutex_t*) &mtx->mtx_mtx) == TRYLOCK_SUCCESS)
    {
      assert (mtx->mtx_owner == NULL);
      mtx->mtx_owner = thread_current ();
      return 1;
    }
  return 0;
#endif
}


#ifdef MTX_DEBUG
void
mutex_leave_dbg (int ln, const char * file, dk_mutex_t *mtx)
#else
void
mutex_leave (dk_mutex_t *mtx)
#endif
{
#ifdef MTX_DEBUG
  assert (mtx->mtx_owner == thread_current ());
  mtx->mtx_owner = NULL;
  mtx->mtx_leave_line = ln;
  mtx->mtx_leave_file = file;
#endif
#if HAVE_SPINLOCK 
  if (MUTEX_TYPE_SPIN == mtx->mtx_type)
    pthread_spin_unlock (&mtx->l.spinl);
  else
#endif
    pthread_mutex_unlock ((pthread_mutex_t*) &mtx->mtx_mtx);
}


void
mutex_stat ()
{
  #ifdef MTX_METER
  DO_HT (dk_mutex_t *, mtx, void*, ign, all_mtxs)
    {
      if (!mtx->mtx_enters)
	continue;
#ifdef APP_SPIN
      printf ("%s %p E: %ld W %ld  spinw: %ld spin: %d\n", mtx->mtx_name ? mtx->mtx_name : "<?>",  mtx,
	      mtx->mtx_enters, mtx->mtx_waits, mtx->mtx_spin_waits, mtx->mtx_spins);
#else
      printf ("%s %p E: %ld W %ld wclk %ld \n", mtx->mtx_name ? mtx->mtx_name : "<?>",  mtx,
	      mtx->mtx_enters, mtx->mtx_waits, mtx->mtx_wait_clocks);
      mtx->mtx_enters = mtx->mtx_waits = mtx->mtx_wait_clocks = 0;;
#endif
    }
  END_DO_SET();
  #else
  printf ("Mutex stats not enabled.}\n");
#endif
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
  return (spinlock_t *) mutex_allocate ();
}


void
spinlock_free (spinlock_t *self)
{
  mutex_free ((dk_mutex_t *) self);
}


void
spinlock_enter (spinlock_t *self)
{
  pthread_mutex_lock ((pthread_mutex_t*) &(((dk_mutex_t *)&self)->mtx_mtx));
}


void
spinlock_leave (spinlock_t *self)
{
  pthread_mutex_unlock ((pthread_mutex_t*) &(((dk_mutex_t *) &self)->mtx_mtx));
}


/*
 *  * pthread_create wrapper for gprof compatibility
*/
#if defined(linux) && defined(VIRT_GPROF)

#undef pthread_create

typedef struct wrapper_s
{
  void * (*start_routine)(void *);
  void * arg;

  pthread_mutex_t lock;
  pthread_cond_t  wait;

  struct itimerval itimer;

} wrapper_t;

static void * wrapper_routine(void *);

/* Same prototype as pthread_create; use some #define magic to
 *  * transparently replace it in other files */
int gprof_pthread_create(pthread_t * thread, pthread_attr_t * attr,
    void * (*start_routine)(void *), void * arg)
{
  wrapper_t wrapper_data;
  int i_return;

  /* Initialize the wrapper structure */
  wrapper_data.start_routine = start_routine;
  wrapper_data.arg = arg;
  getitimer(ITIMER_PROF, &wrapper_data.itimer);
  pthread_cond_init(&wrapper_data.wait, NULL);
  pthread_mutex_init(&wrapper_data.lock, NULL);
  pthread_mutex_lock(&wrapper_data.lock);

  /* The real pthread_create call */
  i_return = pthread_create(thread, attr, &wrapper_routine,
      &wrapper_data);

  /* If the thread was successfully spawned, wait for the data
   *      * to be released */
  if(i_return == 0)
    {
      pthread_cond_wait(&wrapper_data.wait, &wrapper_data.lock);
    }

  pthread_mutex_unlock(&wrapper_data.lock);
  pthread_mutex_destroy(&wrapper_data.lock);
  pthread_cond_destroy(&wrapper_data.wait);

  return i_return;
}

/* The wrapper function in charge for setting the itimer value */
static void * wrapper_routine(void * data)
{
  /* Put user data in thread-local variables */
  void * (*start_routine)(void *) = ((wrapper_t*)data)->start_routine;
  void * arg = ((wrapper_t*)data)->arg;

  /* Set the profile timer value */
  setitimer(ITIMER_PROF, &((wrapper_t*)data)->itimer, NULL);

  /* Tell the calling thread that we do not need its data anymore */
  pthread_mutex_lock(&((wrapper_t*)data)->lock);
  pthread_cond_signal(&((wrapper_t*)data)->wait);
  pthread_mutex_unlock(&((wrapper_t*)data)->lock);

  /* Call the real function */
  return start_routine(arg);
}
#endif


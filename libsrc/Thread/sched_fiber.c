/*
 *  sched_fiber.c
 *
 *  $Id$
 *
 *  Simulated threads, using fibers
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2015 OpenLink Software
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

char *build_thread_model = "-fibers";

typedef char event_t;

/* Indicate non-preemptive scheduling for this model */
int _thread_sched_preempt = 0;

int _thread_num_total;		/* total threads in this model */
int _thread_num_runnable;	/* # threads that can be run */
int _thread_num_wait;		/* # threads waiting for something */
int _thread_num_dead;		/* # threads on free list */

thread_t *_current_fiber;
static thread_queue_t _runq[MAX_PRIORITY];
static thread_queue_t _deadq;
thread_queue_t _waitq;
static thread_t *_main_thread;
#ifdef EXPIRIMENTAL
timer_queue_t *_timerq;
static char _ev_never;
#endif


static void
_sched_init (void)
{
  int i;

  for (i = 0; i < MAX_PRIORITY; i++)
    thread_queue_init (&_runq[i]);

  thread_queue_init (&_waitq);
  thread_queue_init (&_deadq);

  _thread_num_wait = 0;
  _thread_num_dead = 0;
  _thread_num_runnable = 0;
  _thread_num_total = 1;

#ifdef EXPIRIMENTAL
  _timerq = timer_queue_allocate ();
  timer_queue_update (_timerq, timer_queue_time_elapsed (_timerq));
  io_init ();
#endif
}


void
_fiber_status (thread_t *thr, int new_status)
{
  switch (thr->thr_status)
    {
    case RUNNABLE:
      thread_queue_remove (&_runq[thr->thr_priority], thr);
      _thread_num_runnable--;
      break;
    case WAITSEM:
      _thread_num_wait--;
      break;
    case WAITEVENT:
      thread_queue_remove (&_waitq, thr);
      _thread_num_wait--;
      break;
    case DEAD:
      thread_queue_remove (&_deadq, thr);
      _thread_num_dead--;
      break;
    }
  thr->thr_status = new_status;
  switch (thr->thr_status)
    {
    case RUNNABLE:
      thread_queue_to (&_runq[thr->thr_priority], thr);
      _thread_num_runnable++;
      break;
    case WAITSEM:
      _thread_num_wait++;
      break;
    case WAITEVENT:
      thread_queue_to (&_waitq, thr);
      _thread_num_wait++;
      break;
    case DEAD:
      thread_queue_to (&_deadq, thr);
      _thread_num_dead++;
      break;
    }
}


/*
 *  Schedule the next runnable fiber.
 *  Assumes the _runq is NOT empty
 */
void
_fiber_schedule_next (void)
{
  thread_t *thr;
  int i;

  if (_current_fiber->thr_status == RUNNING)
    _fiber_status (_current_fiber, RUNNABLE);

#ifdef EXPIRIMENTAL
  while (_thread_num_runnable == 0)
    _fiber_event_loop ();
#endif

  thr = NULL;
  for (i = MAX_PRIORITY; --i >= 0; )
    if (_runq[i].thq_count)
      {
	thr = (thread_t *) _runq[i].thq_head.thr_next;
	break;
      }
  assert (thr != NULL);
  _fiber_status (thr, RUNNING);
  if (_current_fiber != thr)
    _fiber_switch (thr);
}


#ifdef EXPIRIMENTAL
static void
_fiber_timeout (void *arg)
{
  thread_t *thr = (thread_t *) arg;

  thr->thr_retcode = -1;
#ifdef WIN32
  thr->thr_err = WSAETIMEDOUT;
#else
  thr->thr_err = ETIMEDOUT;
#endif

  _fiber_status (thr, RUNNABLE);
}


int
_fiber_sleep (void *event, TVAL timeout)
{
  thread_t *thr = _current_fiber;

  assert (thr->thr_status == RUNNING);

  thr->thr_err = 0;
  thr->thr_retcode = 0;

  /* set a timer */
  assert (thr->thr_timer == NULL);

  if (timeout != TV_INFINITE)
    thr->thr_timer = timer_queue_new_timer (_timerq, timeout, 0,
	_fiber_timeout, thr);

  if (event == NULL)
    event = &_ev_never;
  thr->thr_event = event;

  do
    {
      _fiber_status (thr, WAITEVENT);
      _fiber_schedule_next ();
    }
  while (thr->thr_event == event && thr->thr_err == 0);

  thr->thr_event = NULL;

  if (timeout != TV_INFINITE)
    {
      timer_deactivate (thr->thr_timer);
      timer_unref (thr->thr_timer);
      thr->thr_timer = NULL;
    }

  return thr->thr_retcode;
}
#endif


/******************************************************************************
 *
 *  Threads
 *
 ******************************************************************************/

thread_t *
thread_current (void)
{
  return _current_fiber;
}


/*
 *  The main thread must call this function to convert itself into a fiber.
 */
thread_t *
thread_initial (unsigned long stack_size)
{
  static unsigned int marker = THREAD_STACK_MARKER;

  if (_current_fiber)
    return _current_fiber;
  else
    {
      NEW_VARZ (thread_t, thr);

      assert (_current_fiber == NULL);
      _main_thread = _current_fiber = thr;

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

      thr->thr_stack_marker = &marker;
      thr->thr_sem = semaphore_allocate (0);
      thr->thr_schedule_sem = semaphore_allocate (0);
      thread_set_priority (thr, NORMAL_PRIORITY);
      _thread_init_attributes (thr);
      _fiber_for_thread (thr, stack_size);

      _fiber_status (thr, RUNNING);

      return thr;
    }
}


thread_t *
thread_allocate ()
{
  thread_t *thr;
  thr = (thread_t *) dk_alloc (sizeof (thread_t));
  memset (thr, 0, sizeof (thread_t));
  thr->thr_sem = semaphore_allocate (0);
  thr->thr_schedule_sem = semaphore_allocate (0);

  return thr;
}


thread_t *
thread_create (
    thread_init_func initial_function,
    unsigned long stack_size,
    void *init_arg)
{
  thread_t *thr;

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

  /* Any free threads with the right stack size? */
  for (thr = (thread_t *) _deadq.thq_head.thr_next;
       thr != (thread_t *) &_deadq.thq_head;
       thr = (thread_t *) thr->thr_hdr.thr_next)
    {
      if (thr->thr_stack_size >= stack_size)
	break;
    }

  if (thr == (thread_t *) &_deadq.thq_head)
    {
      /* No free fiber, create a new one */
      thr = thread_allocate ();
      _fiber_for_thread (thr, stack_size);
      _thread_num_total++;
    }
  else
    {
      /* Set new context for the thread */
      memcpy (thr->thr_context, thr->thr_init_context, sizeof (jmp_buf));
    }

  thr->thr_initial_function = initial_function;
  thr->thr_initial_argument = init_arg;
  thread_set_priority (thr, NORMAL_PRIORITY);
  _thread_init_attributes (thr);
  _fiber_status (thr, RUNNABLE);

  return thr;
}


thread_t *
thread_attach ()
{
  thread_t *thr = thread_allocate ();

  thr->thr_stack_size = (unsigned long) -1;
  thr->thr_status = RUNNABLE;
  thr->thr_priority = NORMAL_PRIORITY;
  thr->thr_attached = 1;

  return thr;
}


void
thread_allow_schedule (void)
{
  if (_thread_num_runnable)
    _fiber_schedule_next ();
}


void
thread_exit (int n)
{
  if (_current_fiber->thr_attached)
    return;

  _fiber_status (_current_fiber, DEAD);
  _thread_free_attributes (_current_fiber);
  if (_current_fiber == _main_thread)
    exit (n);
  _fiber_schedule_next ();
  /* could come here using win fibers */
  longjmp (_current_fiber->thr_init_context, 1);
}

int
thread_release_dead_threads (int leave_count)
{
  return 0;
}

int *
thread_errno (void)
{
  return &_current_fiber->thr_err;
}


int
thread_set_priority (thread_t *self, int prio)
{
  int old_prio = self->thr_priority;
  if (prio >= 0 && prio < MAX_PRIORITY)
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
  int rc;

  if (holds)
    {
      mutex_leave (holds);
      rc = _fiber_sleep (event, timeout);
      mutex_enter (holds);
    }
  else
    rc = _fiber_sleep (event, timeout);

  return rc;
}


int
thread_signal_cond (void *event)
{
  thread_t *thr;
  thread_t *next;
  int count = 0;

  /* Wake up waiting threads for which event occurred */
  for (thr = (thread_t *) _waitq.thq_head.thr_next;
      thr != (thread_t *) &_waitq.thq_head;
      thr = next)
    {
      next = (thread_t *) thr->thr_hdr.thr_next;
      if (thr->thr_event == event)
	{
	  thr->thr_event = NULL;
	  thr->thr_retcode = 0;
	  _fiber_status (thr, RUNNABLE);
	  count++;
	}
    }
  return count;
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
  NEW_VAR (semaphore_t, sem);
  sem->sem_entry_count = entry_count;
  thread_queue_init (&sem->sem_waiting);

  return sem;
}


void
semaphore_free (semaphore_t *sem)
{
  thread_t *thr;

  while ((thr = thread_queue_from (&sem->sem_waiting)) != NULL)
    _fiber_status (thr, RUNNABLE);

  dk_free (sem, sizeof (semaphore_t));
}


DK_INLINE int
semaphore_enter (semaphore_t * sem)
{
  if (sem->sem_entry_count)
    sem->sem_entry_count--;
  else
    {
      thread_queue_to (&sem->sem_waiting, _current_fiber);
      _fiber_status (_current_fiber, WAITSEM);
      _fiber_schedule_next ();
    }
  return 0;
}


DK_INLINE int
semaphore_try_enter (semaphore_t *sem)
{
  if (sem->sem_entry_count)
    {
      sem->sem_entry_count--;
      return 1;
    }
  else
    return 0;
}


#ifdef SEM_DEBUG
void
semaphore_leave_dbg (int ln, const char *file, semaphore_t *sem)
#else
DK_INLINE void
semaphore_leave (semaphore_t *sem)
#endif
{
  thread_t *thr;

  if (sem->sem_entry_count)
    sem->sem_entry_count++;
  else
    {
      thr = thread_queue_from (&sem->sem_waiting);
      if (thr)
	{
	  assert (thr->thr_status == WAITSEM);
	  _fiber_status (thr, RUNNABLE);
	}
      else
	sem->sem_entry_count++;
    }
}

/******************************************************************************
 *
 *  Mutexes
 *
 ******************************************************************************/


dk_set_t all_mtxs = NULL;

dk_mutex_t *
mutex_allocate (void)
{
  NEW_VARZ (dk_mutex_t, mtx);
  mtx->mtx_handle = semaphore_allocate (1);
#ifdef MTX_DEBUG
  mtx->mtx_owner = NULL;
  dk_set_push (&all_mtxs, (void*)mtx);
#endif
  return mtx;
}

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
  semaphore_free ((semaphore_t *) mtx->mtx_handle);
#ifdef MTX_DEBUG
  dk_free_box (mtx->mtx_name);
#endif
  dk_free (mtx, sizeof (dk_mutex_t));
  dk_set_delete (&all_mtxs, (void*) mtx);
}


#ifdef MTX_DEBUG
void
mutex_option (dk_mutex_t * mtx, char * name, mtx_entry_check_t ck, void * cd)
{
  dk_free_box (mtx->mtx_name);
  mtx->mtx_name = box_dv_short_string (name);
  mtx->mtx_entry_check = ck;
  mtx->mtx_entry_check_cd = cd;
}
#endif

#ifdef MALLOC_DEBUG
extern dk_mutex_t *		_dbgmal_mtx;
#endif


#ifdef MTX_DEBUG
int
mutex_enter_dbg (int line, const char * file, dk_mutex_t *mtx)
#else
int
mutex_enter (dk_mutex_t *mtx)
#endif
{
#ifndef MTX_DEBUG
  return semaphore_enter (mtx->mtx_handle);
#else
  semaphore_t *sem = (semaphore_t *) mtx->mtx_handle;
#ifdef MALLOC_DEBUG
  if (_current_fiber == NULL)
    {
      assert (mtx == _dbgmal_mtx);
      return semaphore_enter (sem);
    }
#endif
  assert (_current_fiber != NULL);
  if (sem->sem_entry_count)
    {
      assert (sem->sem_entry_count == 1);
      assert (mtx->mtx_owner == NULL);
      sem->sem_entry_count--;
    }
  else
    {
      assert (mtx->mtx_owner != _current_fiber);
      thread_queue_to (&sem->sem_waiting, _current_fiber);
      _fiber_status (_current_fiber, WAITSEM);
      _fiber_schedule_next ();
      assert (sem->sem_entry_count == 0);
    }
  assert (mtx->mtx_owner == NULL);
  if (mtx->mtx_entry_check
      && !mtx->mtx_entry_check (mtx, THREAD_CURRENT_THREAD, mtx->mtx_entry_check_cd))
    GPF_T1 ("Mtx entry check fail");

  mtx->mtx_owner = _current_fiber;
  mtx->mtx_entry_file = (char *) file;
  mtx->mtx_entry_line = line;

  return 0;
#endif
}


#ifdef MTX_DEBUG

#undef mutex_enter

int
mutex_enter (dk_mutex_t * mtx)
{
  return (mutex_enter_dbg (__LINE__, __FILE__, mtx));
}
#endif


int
mutex_try_enter (dk_mutex_t *mtx)
{
#ifndef MTX_DEBUG
  return semaphore_try_enter (mtx->mtx_handle);
#else
  mutex_enter (mtx);
  return 1;
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
#ifndef MTX_DEBUG
  semaphore_leave (mtx->mtx_handle);
#else
  semaphore_t *sem = (semaphore_t *) mtx->mtx_handle;
  thread_t *thr;
#ifdef MALLOC_DEBUG
  if (_current_fiber == NULL)
    {
      assert (mtx == _dbgmal_mtx);
      semaphore_leave (sem);
      return;
    }
#endif
  assert (mtx->mtx_owner == _current_fiber);
  assert (sem->sem_entry_count == 0);
  mtx->mtx_owner = NULL;

  if (sem->sem_entry_count)
    sem->sem_entry_count++;
  else
    {
      thr = thread_queue_from (&sem->sem_waiting);
      if (thr)
	{
	  assert (thr->thr_status == WAITSEM);
	  _fiber_status (thr, RUNNABLE);
	}
      else
	sem->sem_entry_count++;
    }
#endif
}


void
mutex_stat ()
{
#ifdef MTX_METER
  DO_SET (dk_mutex_t *, mtx, &all_mtxs)
    {
      printf ("%s %lx E: %ld W %ld \n", mtx->mtx_name ? mtx->mtx_name : "<?>", (unsigned long) mtx,
	      mtx->mtx_enters, mtx->mtx_waits);
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

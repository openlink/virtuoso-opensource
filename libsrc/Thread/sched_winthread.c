/*
 *  sched_winthread.c
 *
 *  $Id$
 *
 *  Scheduler for Win32 threads
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

// TODO XXX INITIAL ATTRIBUTES, RESTART

#if !defined (WIN95COMPAT)
#define _WIN32_WINNT 0x400
#endif
#include "Dk.h"

const char *build_thread_model = "-threads";

/* Indicate preemptive scheduling for this model */
int _thread_sched_preempt = 1;

int _thread_num_total;		/* total threads in this model */
int _thread_num_runnable;	/* # threads that can be run */
int _thread_num_wait;		/* # threads waiting for something */
int _thread_num_dead;		/* # threads on free list */

#define Q_LOCK()		mutex_enter (_q_lock)
#define Q_UNLOCK()		mutex_leave (_q_lock)

static thread_t *_main_thread;
static DWORD tlsCurrentThread;
static thread_queue_t _deadq;
thread_queue_t _waitq;
static dk_mutex_t *_q_lock;

dk_mutex_t * all_mtxs_mtx;

static void
sched_init (void)
{
  _q_lock = mutex_allocate_typed (MUTEX_TYPE_LONG);

  thread_queue_init (&_waitq);
  thread_queue_init (&_deadq);

  _thread_num_wait = 0;
  _thread_num_dead = 0;
  _thread_num_runnable = -1;	/* not counted */
  _thread_num_total = 1;

#ifdef EXPIRIMENTAL
  io_init ();
#endif
#ifdef MTX_METER
  all_mtxs_mtx = mutex_allocate ();
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
  return (thread_t *) TlsGetValue (tlsCurrentThread);
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

      tlsCurrentThread = TlsAlloc ();
      if (tlsCurrentThread == (DWORD) -1)
	{
	  fprintf (stderr, "TlsAlloc() failed (%d)\n", GetLastError ());
	  return NULL;
	}

      assert (_main_thread == NULL);
      _main_thread = thr;

      sched_init ();

      if (stack_size == 0)
	stack_size = MAIN_STACK_SIZE;
#ifdef _DEBUG
	stack_size *= 2;
#endif
      thr->thr_stack_size = stack_size;
      thr->thr_status = RUNNING;
      thr->thr_sem = semaphore_allocate (0);
      thr->thr_schedule_sem = semaphore_allocate (0);
      thr->thr_cv = CreateEvent (NULL, TRUE, FALSE, NULL);
      thr->thr_handle = (void*) (ptrlong) GetCurrentThreadId ();
      if (thr->thr_cv == NULL)
	goto failed;
      _thread_init_attributes (thr);
      thread_set_priority (thr, NORMAL_PRIORITY);

      if (!TlsSetValue (tlsCurrentThread, thr))
	{
	  fprintf (stderr, "TlsSetValue() failed (%d)\n", GetLastError ());
	  goto failed;
	}

      return thr;

    failed:
      _thread_free_attributes (thr);
      dk_free (thr, sizeof (thread_t));
      return NULL;
    }
}


static unsigned int WINAPI
_thread_boot (void *arg)
{
  thread_t *thr = (thread_t *) arg;
  int rc;

  TlsSetValue (tlsCurrentThread, thr);

  /*thr->thr_handle = (void*) GetCurrentThreadId (); this is a identifier not a handle*/

  thr->thr_stack_base = (void*) &arg;
  /* Store the context so we can easily restart a dead fiber */
  setjmp (thr->thr_init_context);

  thr->thr_status = RUNNING;
  _thread_init_attributes (thr);

  rc = (*thr->thr_initial_function) (thr->thr_initial_argument);

  /* thread died, put it on the dead queue */
  thread_exit (rc);

  /* We should never come here */
  GPF_T;

  /* dummy */
  return 0;
}


static thread_t *
thread_alloc (void)
{
  thread_t *thr;
  thr = (thread_t *) dk_alloc ( sizeof (thread_t));
  memset (thr, 0, sizeof (thread_t));
  thr->thr_status = RUNNABLE;
  thr->thr_cv = CreateEvent (NULL, TRUE, FALSE, NULL);
  thr->thr_sem = semaphore_allocate (0);
  thr->thr_schedule_sem = semaphore_allocate (0);
  return thr;
}

#ifdef GC_THREADS
typedef HANDLE (WINAPI *CreateThreadPtr)(
  LPSECURITY_ATTRIBUTES lpThreadAttributes,
  SIZE_T dwStackSize,
  LPTHREAD_START_ROUTINE lpStartAddress,
  LPVOID lpParameter,
  DWORD dwCreationFlags,
  LPDWORD lpThreadId
);
CreateThreadPtr ptrCreateThread = CreateThread;

void
virtuoso_set_create_thread (CreateThreadPtr ptr)
{
  ptrCreateThread = ptr;
}
#else
void
virtuoso_set_create_thread (void * ptr)
{
}
#endif

thread_t *
thread_create (
    thread_init_func initial_function,
    unsigned long stack_size,
    void *initial_argument)
{
  thread_t *thr;
#ifdef GC_THREADS
  DWORD thr_id;
  HANDLE thdl;
#else
  unsigned int thr_id;
  uptrlong thdl;
#endif

  assert (_main_thread != NULL);

  if (stack_size == 0)
    stack_size = THREAD_STACK_SIZE;

#ifdef _DEBUG
  stack_size *= 2;
#endif
#ifdef _WIN64
  stack_size *= 4;
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

  if (thr == (thread_t *) &_deadq.thq_head)
    {
      /* No free thread, create a new one */
      thr = thread_alloc ();
      thr->thr_stack_size = stack_size;
      thr->thr_initial_function = initial_function;
      thr->thr_initial_argument = initial_argument;
      if (thr->thr_cv == NULL)
	goto failed;
#ifdef GC_THREADS
      thdl = ptrCreateThread
#else
      thdl = _beginthreadex
#endif
	(
	  NULL,		// security
	  stack_size,	// stack size
	  _thread_boot,	// start address
	  thr,		// arglist
	  0,		// initflag
	  &thr_id);	// thrdaddr
      if (thdl == 0)
	{
	  log_error ("Can't create OS thread : %m");
	  goto failed;
	}
      thr->thr_handle = (void *) thdl;
      _thread_num_total++;
      thread_set_priority (thr, NORMAL_PRIORITY);
    }
  else
    {
      /* Set new context for the thread and resume it */
      Q_LOCK ();
      thread_queue_remove (&_deadq, thr);
      _thread_num_dead--;
      Q_UNLOCK ();
      assert (thr->thr_status == DEAD);
      /* Set new context for the thread and resume it */
      thr->thr_initial_function = initial_function;
      thr->thr_initial_argument = initial_argument;
      thr->thr_status = RUNNABLE;
      PulseEvent (thr->thr_cv);
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

  thr = thread_alloc ();
  thr->thr_stack_size = (unsigned long) -1;
  if (thr->thr_cv == NULL)
    goto failed;

  thr->thr_handle = GetCurrentThread ();
  thr->thr_attached = 1;

  TlsSetValue (tlsCurrentThread, thr);

  /*thr->thr_handle = (void*) GetCurrentThreadId (); this is a identifier not a handle*/

  thr->thr_stack_base = (void*) &thr;
  /* Store the context so we can easily restart a dead fiber */
  setjmp (thr->thr_init_context);

  thr->thr_status = RUNNING;
  _thread_init_attributes (thr);

  return thr;

failed:
  if (thr->thr_sem)
    semaphore_free (thr->thr_sem);
  if (thr->thr_schedule_sem)
    semaphore_free (thr->thr_schedule_sem);
  dk_free (thr, sizeof (thread_t));
  return NULL;
}


void
thread_allow_schedule (void)
{
}


void
thread_exit (int n)
{
  thread_t *thr = current_thread;
  int is_attached = thr->thr_attached;

  if (thr == _main_thread)
    call_exit (n);

  thr->thr_retcode = n;
  thr->thr_status = DEAD;

  ResetEvent (thr->thr_cv);

  if (is_attached)
    {
      thr->thr_status = TERMINATE;
      goto terminate;
    }
  Q_LOCK ();
  thread_queue_to (&_deadq, thr);
  _thread_num_dead++;

#ifdef WIN95COMPAT
  Q_UNLOCK ();
  if (WaitForSingleObject (thr->thr_cv, INFINITE) != WAIT_OBJECT_0)
#else
  if (SignalObjectAndWait (_q_lock->mtx_handle, thr->thr_cv,
      INFINITE, FALSE) != WAIT_OBJECT_0)
#endif
    {
      thread_queue_remove (&_deadq, thr);
      _thread_num_dead--;
      Q_UNLOCK ();
      _thread_num_total--;
      GPF_T1 ("SignalObjectAndWait() failed in thread_exit()\n");
      // _endthreadex ..
    }
  /* Woke up with a PulseEvent() */

#ifdef WIN95COMPAT
  Q_UNLOCK ();
#endif

  if (thr->thr_status == TERMINATE)
    goto terminate;

  /* Jumps back into _thread_boot */
  longjmp (thr->thr_init_context, 1);

terminate:
    {
      _thread_free_attributes (thr);
      semaphore_free (thr->thr_sem);
      semaphore_free (thr->thr_schedule_sem);
      CloseHandle (thr->thr_cv);
      CloseHandle (thr->thr_handle);
      thr_free_alloc_cache (thr);
      dk_free (thr, sizeof (thread_t));
    }
  if (!is_attached)
    {
      _thread_num_total--;
      _endthreadex (1);
    }
}

int
thread_release_dead_threads (int leave_count)
{
  thread_t *thr;
  thread_queue_t term;
  long thread_killed = 0;

  Q_LOCK ();
  /*fprintf (stderr, "Threads: total: %ld dead: %ld\n", _thread_num_total, _deadq.thq_count);*/
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
      PulseEvent (thr->thr_cv);
#if 0
      WaitForSingleObject (thr->thr_handle, INFINITE);
	{
	  _thread_free_attributes (thr);
	  semaphore_free (thr->thr_sem);
	  CloseHandle (thr->thr_cv);
	  CloseHandle (thr->thr_handle);
	  dk_free (thr, sizeof (thread_t));
	}
#endif
      thread_killed++;
    }
#if 0
  if (thread_killed)
    log_info ("%ld OS threads released", thread_killed);
#endif
  return thread_killed;
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

  if (prio < 0 || prio >= MAX_PRIORITY)
    return old_prio;

  switch (prio)
    {
    case LOW_PRIORITY:
    case NORMAL_PRIORITY:
    case HIGH_PRIORITY:
      break;
    default:
      return old_prio;
    }


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
  HANDLE mtx;
  DWORD to;

  thr->thr_status = WAITEVENT;
  thr->thr_event = event;

  mtx = holds ? mtxt : _q_lock;

  Q_LOCK ();
  thread_queue_to (&_waitq, thr);
  _thread_num_wait++;

  if (holds)
    Q_UNLOCK ();

  to = timeout == TV_INFINITE ? INFINITE : timeout;

#ifdef WIN95COMPAT
  WaitForSingleObject (thr->thr_cv, to);
#else
  SignalObjectAndWait (mtx, thr->thr_cv, to, FALSE);
#endif

  mutex_enter (mtx);

  if (holds)
    Q_LOCK ();

  thread_queue_remove (&_waitq, thr);
  _thread_num_wait--;
  Q_UNLOCK ();

  thr->thr_status = RUNNING;
  return thr->thr_event == NULL ? 0 : -1;
}


int
thread_signal_cond (void *event)
{
  thread_t *thr;
  thread_t *next;
  int count;

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
	  PulseEvent (thr->thr_cv);
	  count++;
	}
    }
  Q_UNLOCK ();

  return count;
}


int
thread_select (int n, fd_set *rfds, fd_set *wfds, void *event, TVAL timeout)
{
  struct timeval *ptv, tv;

  if (timeout == TV_INFINITE)
    ptv = NULL;
  else
    {
      tv.tv_sec = timeout / 1000;
      tv.tv_usec = (timeout % 1000) * 1000;
      ptv = &tv;
    }

#error TODO - handle event

  return select (n, rfds, wfds, NULL, ptv);
}


void
thread_sleep (TVAL timeout)
{
  Sleep (timeout);
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
  NEW_VARZ (semaphore_t, sem);
  sem->sem_handle = CreateSemaphore (NULL, entry_count, LONG_MAX, NULL);
  return sem;
}


void
semaphore_free (semaphore_t *self)
{
  CloseHandle (self->sem_handle);
  dk_free (self, sizeof (semaphore_t));
}


int
semaphore_enter (semaphore_t *self)
{
  _thread_num_wait++;
  WaitForSingleObject (self->sem_handle, INFINITE);
  _thread_num_wait--;
  return 0;
}


int
semaphore_try_enter (semaphore_t *self)
{
  if (WaitForSingleObject (self->sem_handle, 0) == WAIT_TIMEOUT)
    return 0;
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
#ifdef SEM_DEBUG
    {
      int inx;
      for (inx = MAX_SEM_ENT - 1; inx > 0; inx--)
	{
	  sem->sem_last_left_line[inx] = sem->sem_last_left_line[inx - 1];
	  sem->sem_last_left_file[inx] = sem->sem_last_left_file[inx - 1];
	}
      sem->sem_last_left_line[0] = ln;
      sem->sem_last_left_file[0] = file;
    }
#endif
  ReleaseSemaphore (sem->sem_handle, 1, NULL);
}

/******************************************************************************
 *
 *  Mutexes
 *
 ******************************************************************************/


#ifdef MTX_METER
dk_set_t all_mtxs = NULL;
#endif

dk_mutex_t *
mutex_allocate_typed (int mutex_type)
{
  NEW_VARZ (dk_mutex_t, mtx);
  mtx->mtx_type = mutex_type;
#ifdef MTX_DEBUG
  mtx->mtx_owner = NULL;
#endif
  if (mutex_type == MUTEX_TYPE_LONG)
    {
      mtx->mtx_handle = CreateMutex (NULL, FALSE, NULL);
      return mtx;
    }
  else
    {
      NEW_VAR (CRITICAL_SECTION, cs);
      mtx->mtx_handle = cs;
      InitializeCriticalSection(mtx->mtx_handle);
#ifdef MTX_METER
      if (all_mtxs_mtx)
	mutex_enter (all_mtxs_mtx);
      dk_set_push (&all_mtxs, (void*) mtx);
      if (all_mtxs_mtx)
	mutex_leave (all_mtxs_mtx);
#endif
      return mtx;
    }
}

dk_mutex_t *
mutex_allocate (void)
{
  return mutex_allocate_typed(MUTEX_TYPE_SHORT);
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

void
dk_mutex_init (dk_mutex_t * mtx, int type)
{
  memset (mtx, 0, sizeof (dk_mutex_t));
  mtx->mtx_type = type;
#ifdef MTX_DEBUG
  mtx->mtx_owner = NULL;
#endif
  if (type == MUTEX_TYPE_LONG)
    {
      mtx->mtx_handle = CreateMutex (NULL, FALSE, NULL);
    }
  else
    {
      NEW_VAR (CRITICAL_SECTION, cs);
      mtx->mtx_handle = cs;
      InitializeCriticalSection(mtx->mtx_handle);
#ifdef MTX_METER
      if (all_mtxs_mtx)
	mutex_enter (all_mtxs_mtx);
      dk_set_push (&all_mtxs, (void*) mtx);
      if (all_mtxs_mtx)
	mutex_leave (all_mtxs_mtx);
#endif
    }
  return;
}

void
dk_mutex_destroy (dk_mutex_t *mtx)
{
#ifdef MTX_METER
  mutex_enter (all_mtxs_mtx);
  dk_set_delete (&all_mtxs, (void*) mtx);
  mutex_leave (all_mtxs_mtx);
#endif
  if (mtx->mtx_type == MUTEX_TYPE_LONG)
    {
      CloseHandle (mtx->mtx_handle);
    }
  else
    {
      DeleteCriticalSection(mtx->mtx_handle);
      dk_free(mtx->mtx_handle, sizeof(CRITICAL_SECTION));
    }
#ifdef MTX_DEBUG
  dk_free_box (mtx->mtx_name);
#endif
}

void
mutex_free (dk_mutex_t *self)
{
#ifdef MTX_METER
  mutex_enter (all_mtxs_mtx);
  dk_set_delete (&all_mtxs, (void*) self);
  mutex_leave (all_mtxs_mtx);
#endif
  if (self->mtx_type == MUTEX_TYPE_LONG)
    {
      CloseHandle (self->mtx_handle);
    }
  else
    {
      DeleteCriticalSection(self->mtx_handle);
      dk_free(self->mtx_handle, sizeof(CRITICAL_SECTION));
    }
#ifdef MTX_DEBUG
  dk_free_box (self->mtx_name);
#endif
  dk_free (self, sizeof (dk_mutex_t));
}


#ifdef MTX_DEBUG
int
mutex_enter_dbg (int line, char * file, dk_mutex_t *mtx)
#else
int
mutex_enter (dk_mutex_t *mtx)
#endif
{
#ifdef MTX_DEBUG
  thread_t* thr = thread_current();
#endif
  _thread_num_wait++;

#ifdef MTX_DEBUG
  assert (mtx->mtx_owner != self || !self);
  if (mtx->mtx_entry_check
      && !mtx->mtx_entry_check (mtx, thr, mtx->mtx_entry_check_cd))
    GPF_T1 ("Mtx entry check fail");
#endif

  if (mtx->mtx_type == MUTEX_TYPE_LONG)
    WaitForSingleObject (mtx->mtx_handle, INFINITE);
  else
    EnterCriticalSection(mtx->mtx_handle);
  _thread_num_wait--;
#ifdef MTX_DEBUG
  assert (mtx->mtx_owner == NULL);
  mtx->mtx_owner = thr;
  mtx->mtx_entry_file = file;
  mtx->mtx_entry_line = line;
#endif
  return 0;
}


int
mutex_try_enter (dk_mutex_t *mtx)
{
#ifdef MTX_DEBUG
  thread_t* thr = thread_current();
#endif
  if (mtx->mtx_type == MUTEX_TYPE_LONG)
    {
      if (WaitForSingleObject (mtx->mtx_handle, 0) == WAIT_TIMEOUT)
	return 0;
    }
  else
    {
      if (!TryEnterCriticalSection (mtx->mtx_handle))
	return 0;
    }

#ifdef MTX_DEBUG
  assert (mtx->mtx_owner == NULL);
  mtx->mtx_owner = thr;
  mtx->mtx_entry_file = __FILE__;
  mtx->mtx_entry_line = __LINE__;
#endif
  return 1;
}


#ifdef MTX_DEBUG
void mutex_leave_dbg (int line, const char * file, dk_mutex_t *self)
#else
void mutex_leave (dk_mutex_t *self)
#endif
{
#ifdef MTX_DEBUG
  assert (self->mtx_owner == thread_current ());
  self->mtx_owner = NULL;
  self->mtx_leave_line = line;
  self->mtx_leave_file = file;
#endif
  if (self->mtx_type == MUTEX_TYPE_LONG)
    ReleaseMutex (self->mtx_handle);
  else
    LeaveCriticalSection(self->mtx_handle);
  return;
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

struct spinlock_s
  {
    CRITICAL_SECTION cs;
  };

spinlock_t *
spinlock_allocate (void)
{
  NEW_VAR (spinlock_t, sl);
  InitializeCriticalSection (&sl->cs);
  return sl;
}


void
spinlock_free (spinlock_t *self)
{
  dk_free (self, sizeof (spinlock_t));
}


void
spinlock_enter (spinlock_t *self)
{
  EnterCriticalSection (&self->cs);
}


void
spinlock_leave (spinlock_t *self)
{
  LeaveCriticalSection (&self->cs);
}


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

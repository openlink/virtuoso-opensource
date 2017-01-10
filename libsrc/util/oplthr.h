/*
 *  oplthr.h
 *
 *  $Id$
 *
 *  Macros for locking & multihreading
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

#ifndef _OPLTHR_H
#define _OPLTHR_H

/*
 *  NOTES:
 *    OPL_THREADING is defined if building in multi threaded environment
 *
 *    OLD_THREAD_IDENT (if defined) returns an identifier for the
 *       current thread - only for debugging
 *
 *  The OPL_MUTEX_... and OPL_SPINLOCK_... macros are pretty straightforward,
 *  no error checking is done
 */

/*
 *  Threading in Virtuoso
 *  
 *  Disabled to avoid circular dependency between util, Dk and Thread libs
 *  Now we just use OS native mutex calls.
 */
#if 0 /* Originally: _DKTHREAD_H */

#define OPL_THREADING

# define OPL_MUTEX_DECLARE(M)		dk_mutex_t *M
# define OPL_MUTEX_INIT(M)		M = mutex_allocate ()
# define OPL_MUTEX_DONE(M)		mutex_free (M)
# define OPL_MUTEX_LOCK(M)		mutex_enter (M)
# define OPL_MUTEX_UNLOCK(M)		mutex_leave (M)

# define OPL_SPINLOCK_DECLARE(M)	spinlock_t *M
# define OPL_SPINLOCK_INIT(M)		M = spinlock_allocate ()
# define OPL_SPINLOCK_DONE(M)		spinlock_free (M)
# define OPL_SPINLOCK_LOCK(M)		spinlock_enter (M)
# define OPL_SPINLOCK_UNLOCK(M)		spinlock_leave (M)

# define OPL_SEMAPHORE_DECLARE(M)	semaphore_t *M
# define OPL_SEMAPHORE_INIT(M,V,MX)	M = semaphore_allocate (V)
# define OPL_SEMAPHORE_DONE(M)		semaphore_free (M)
# define OPL_SEMAPHORE_WAIT(M)		semaphore_enter (M)
# define OPL_SEMAPHORE_TRYWAIT(M)	(semaphore_try_enter (M) ? 0 : -1)
# define OPL_SEMAPHORE_SIGNAL(M)	semaphore_leave (M)


/*
 *  Threading under windows
 */
#elif defined (WIN32) && !defined (NO_THREADING)

# define OPL_THREADING

# define OPL_THREAD_IDENT		GetCurrentThreadId ()

# define OPL_MUTEX_DECLARE(M)		HANDLE M
# define OPL_MUTEX_INIT(M)		M = CreateMutex (NULL, FALSE, NULL)
# define OPL_MUTEX_DONE(M)		CloseHandle (M)
# define OPL_MUTEX_LOCK(M)		WaitForSingleObject (M, INFINITE)
# define OPL_MUTEX_UNLOCK(M)		ReleaseMutex (M)

# define OPL_SPINLOCK_DECLARE(M)	CRITICAL_SECTION M
# define OPL_SPINLOCK_INIT(M)		InitializeCriticalSection (&M)
# define OPL_SPINLOCK_DONE(M)		DeleteCriticalSection (&M)
# define OPL_SPINLOCK_LOCK(M)		EnterCriticalSection (&M)
# define OPL_SPINLOCK_UNLOCK(M)		LeaveCriticalSection (&M)

# define OPL_SEMAPHORE_DECLARE(M)	HANDLE M
# define OPL_SEMAPHORE_INIT(M,V,MX)	M = CreateSemaphore (NULL, V, MX, NULL)
# define OPL_SEMAPHORE_DONE(M)		CloseHandle (M)
# define OPL_SEMAPHORE_TRYWAIT(M)	(WaitForSingleObject (M, 0) == WAIT_OBJECT_0 ? 0 : -1)
# define OPL_SEMAPHORE_WAIT(M)		WaitForSingleObject (M, INFINITE)
# define OPL_SEMAPHORE_SIGNAL(M)	ReleaseSemaphore (M, 1, NULL)


/*
 *  Threading with pthreads
 */
#elif defined (WITH_PTHREADS) && !defined (NO_THREADING)

#ifndef _REENTRANT
# error Add -D_REENTRANT to your compiler flags
#endif

#include <pthread.h>

#ifdef PTHREAD_NATIVE_SEMAPHORES
# include <semaphore.h>
#else

typedef struct
  {
    pthread_mutex_t mtx;
    pthread_cond_t cond;
    int count;
    int max;
  } oplsem_t;

BEGIN_CPLUSPLUS
int OPL_sema_init (oplsem_t *psema, int count, int max);
int OPL_sema_done (oplsem_t *psema);
int OPL_sema_signal (oplsem_t *psema);
int OPL_sema_wait (oplsem_t *psema);
END_CPLUSPLUS
#endif

#define OPL_THREADING

# define OPL_MUTEX_DECLARE(M)		pthread_mutex_t M
# ifndef OLD_PTHREADS
#  define OPL_THREAD_IDENT		((long) (pthread_self ()))
#  define OPL_MUTEX_INIT(M)		pthread_mutex_init (&M, NULL)
# else
#  undef OPL_THREAD_IDENT
#  define OPL_MUTEX_INIT(M)		pthread_mutex_init (&M, pthread_mutexattr_default)
# endif
# define OPL_MUTEX_DONE(M)		pthread_mutex_destroy (&M)
# define OPL_MUTEX_LOCK(M)		pthread_mutex_lock (&M)
# define OPL_MUTEX_UNLOCK(M)		pthread_mutex_unlock (&M)

# define OPL_SPINLOCK_DECLARE(M)	OPL_MUTEX_DECLARE (M)
# define OPL_SPINLOCK_INIT(M)		OPL_MUTEX_INIT (M)
# define OPL_SPINLOCK_DONE(M)		OPL_MUTEX_DONE (M)
# define OPL_SPINLOCK_LOCK(M)		OPL_MUTEX_LOCK (M)
# define OPL_SPINLOCK_UNLOCK(M)		OPL_MUTEX_UNLOCK (M)

#ifdef PTHREAD_NATIVE_SEMAPHORES
# define OPL_SEMAPHORE_DECLARE(M)	sem_t M
# define OPL_SEMAPHORE_INIT(M,V,MX)	sem_init (&M, 0, V)
# define OPL_SEMAPHORE_DONE(M)		sem_destroy (&M)
# define OPL_SEMAPHORE_WAIT(M)		sem_wait (&M)
# define OPL_SEMAPHORE_TRYWAIT(M)	sem_trywait (&M)
# define OPL_SEMAPHORE_SIGNAL(M)	sem_post (&M)
#else
# define OPL_SEMAPHORE_DECLARE(M)	oplsem_t M
# define OPL_SEMAPHORE_INIT(M,V,MX)	OPL_sema_init (&M, V, MX)
# define OPL_SEMAPHORE_DONE(M)		OPL_sema_done (&M)
# define OPL_SEMAPHORE_WAIT(M)		OPL_sema_wait (&M)
# define OPL_SEMAPHORE_TRYWAIT(M)	OPL_sema_wait (&M)
# define OPL_SEMAPHORE_SIGNAL(M)	OPL_sema_signal (&M)
#endif


/*
 *  No threading
 */
#else
# undef OPL_THREADING

# undef OPL_THREAD_IDENT

# define OPL_MUTEX_DECLARE(M)		int M
# define OPL_MUTEX_INIT(M)		M = 1
# define OPL_MUTEX_DONE(M)		M = 1
# define OPL_MUTEX_LOCK(M)		M = 1
# define OPL_MUTEX_UNLOCK(M)		M = 1

# define OPL_SPINLOCK_DECLARE(M)	OPL_MUTEX_DECLARE (M)
# define OPL_SPINLOCK_INIT(M)		OPL_MUTEX_INIT (M)
# define OPL_SPINLOCK_DONE(M)		OPL_MUTEX_DONE (M)
# define OPL_SPINLOCK_LOCK(M)		OPL_MUTEX_LOCK (M)
# define OPL_SPINLOCK_UNLOCK(M)		OPL_MUTEX_UNLOCK (M)

# define OPL_SEMAPHORE_DECLARE(M)	OPL_MUTEX_DECLARE (M)
# define OPL_SEMAPHORE_INIT(M,V,MX)	OPL_MUTEX_INIT (M)
# define OPL_SEMAPHORE_DONE(M)		OPL_MUTEX_DONE (M)
# define OPL_SEMAPHORE_WAIT(M)		abort()
# define OPL_SEMAPHORE_TRYWAIT(M)	abort()
# define OPL_SEMAPHORE_SIGNAL(M)

# define OPL_THREAD_IDENT		0
#endif


#ifndef _DKTHREAD_H /* Virtuoso already defines these */

#define thread_t	opl_thread_t
#define thread_create	OPL_thread_create
#define thread_exit	OPL_thread_exit

typedef struct thread_s thread_t;

BEGIN_CPLUSPLUS

typedef int (*thread_init_func) (void *arg);

thread_t *thread_create (thread_init_func init, unsigned long stack_size, void *init_arg);
void thread_exit (int n);

END_CPLUSPLUS

#endif /* _DKTHREAD_H */

#endif

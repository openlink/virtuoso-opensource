/*
 *  thread_int.h
 *
 *  $Id$
 *
 *  Thread internals
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

#ifndef _THREAD_INT_H
#define _THREAD_INT_H

#include "Dk.h"
#include "util/listmac.h"
#include "Thread/timer_queue.h"
#include "Thread/tvmac.h"
#include <assert.h>
#define _THREAD_INT_HS
/*#include <Wi/statuslog.h>*/
#undef _THREAD_INT_HS

#if defined (__APPLE__)
#include <AvailabilityMacros.h>

# if defined (MAC_OS_X_VERSION_10_7) && (MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_7)
#  define SEM_NO_ORDER 1
# endif
#endif

/* Default stack size for the main thread */
#define MAIN_STACK_SIZE		800000

/* Default stack size for auxiliary threads */
#define THREAD_STACK_SIZE	100000

/* Thread attributes hash table size */
#define THREAD_ATTRIBUTE_HASH	17

typedef struct thread_hdr_s	thread_hdr_t;
typedef struct thread_queue_s	thread_queue_t;

/*
 *  Thread queue
 */
struct thread_hdr_s
  {
    thread_hdr_t *	thr_next;
    thread_hdr_t *	thr_prev;
  };

struct thread_queue_s
  {
    thread_hdr_t	thq_head;
    int			thq_count;
  };

/*
 *  Thread
 */
struct thread_s
{
    /* pointers for a thread queue */
    thread_hdr_t	thr_hdr;

    /* running status, see below */
    int			thr_status;

    /* current priority */
    int			thr_priority;

    /* thread specific attributes (thread local storage) */
    void *		thr_attributes;

    /* thread specific errno */
    int			thr_err;

    /* if WAITING, thr_timer can interrupt */
    void *		thr_event;
    timer_t *		thr_timer;

    /* used in thread_select */
    int			thr_retcode;
    int			thr_nfds;
    fd_set		thr_rfds;
    fd_set		thr_wfds;

    /* restart context for a "dead" or new thread */
    jmp_buf		thr_init_context;
    thread_init_func	thr_initial_function;
    void *		thr_initial_argument;

    /* stack size, if applicable */
    unsigned long	thr_stack_size;
    void *		thr_stack_base; /* address near bottom, use for overflow detection */

    /* saved during a context switch */
    jmp_buf		thr_context;		/* simulated threads */

    /* stack protection */
    unsigned int *	thr_stack_marker;	/* simulated threads */

    void *		thr_cv;			/* condition variable */

    void *		thr_handle;		/* os specific handle */

#ifdef WIN32
    void *		thr_sec_token;		/* Win security token */
#endif

    /* Compatibility dk_thread */
    semaphore_t	*	thr_sem;
    semaphore_t	*	thr_schedule_sem;
    void *		thr_client_data;
    void *		thr_alloc_cache;
  struct TLSF_struct *	thr_tlsf;
  struct TLSF_struct *	thr_own_tlsf;
  /* preallocated thread attributes */
  jmp_buf_splice *	thr_reset_ctx;
  caddr_t		thr_reset_code;
  caddr_t		thr_func_value;
  void *		thr_tmp_pool;
  void *		thr_sql_scs;
  int                   thr_attached;
  caddr_t		thr_dbg;
  struct lock_trx_s *	thr_lt; /* use to access lt during checkpoint wait */
#ifndef NDEBUG
  void *		thr_pg_dbg;
#endif  
};


#define THR_IS_STACK_OVERFLOW(thr, addr, margin) \
  (thr->thr_stack_base ? (((char*) addr < (char *) thr->thr_stack_base) \
      ? (((unsigned long) ((char *) thr->thr_stack_base - (char *) addr)) > thr->thr_stack_size - margin) \
      : (((unsigned long) ((char *) addr - (char *) thr->thr_stack_base)) > thr->thr_stack_size - margin)) \
   : 0)




/*
 *  Thread status values (thr_status)
 */
#define RUNNING		1	/* Currently running */
#define RUNNABLE	2	/* Can be run, on _runq */
#define WAITSEM		3	/* Waiting on a semaphore */
#define WAITEVENT	4	/* Waiting in _thread_sleep, on _waitq */
#define DEAD		5	/* Exitted, on _deadq */
#define TERMINATE	6	/* Should terminate */

/*
 *  thr_stack_marker points at this value
 *  Only used in simulated threads
 */
#define THREAD_STACK_MARKER	0xdeadc0de

#ifdef SEM_DEBUG
#define MAX_SEM_ENT 8
#endif
/*
 *  Semaphore
 */
struct semaphore_s
  {
    /* os specific handle */
    void *		sem_handle;

    /* simulated threads */
    int			sem_entry_count;
    thread_queue_t	sem_waiting;
#ifdef SEM_NO_ORDER
    void *		sem_cv;			/* condition variable */
    unsigned long 	sem_n_signalled;
    unsigned long 	sem_last_signalled;
#endif
#ifdef SEM_DEBUG
    int			sem_last_left_line[MAX_SEM_ENT];
    char *		sem_last_left_file[MAX_SEM_ENT];
#endif
  };

/*
 *  Mutex
 */
#define MUTEX_TYPE_SHORT 0
#define MUTEX_TYPE_LONG	 1
#define MUTEX_TYPE_SPIN 2

struct mutex_s
  {
    /* os specific handle */
#ifdef WITH_PTHREADS
#ifdef HAVE_SPINLOCK
#define mtx_mtx l.mtx
    union {
      pthread_mutex_t	mtx;
      pthread_spinlock_t 	spinl;
    } l;
#else
    pthread_mutex_t	mtx_mtx;
#endif
#endif
    void *		mtx_handle;
#ifdef APP_SPIN
    int			mtx_spins;
#endif
#if defined (MTX_DEBUG) || defined (MTX_METER)
    caddr_t		mtx_name;
#endif

#ifdef MTX_DEBUG
    thread_t *		mtx_owner;
    char *	mtx_entry_file;
    int		mtx_entry_line;
    char *	mtx_leave_file;
    int		mtx_leave_line;
    mtx_entry_check_t	mtx_entry_check;
    void *		mtx_entry_check_cd;
#endif
#ifdef MTX_METER
    long		mtx_spin_waits;
    long		mtx_waits;
    long		mtx_enters;
    long long		mtx_wait_clocks;
#endif
    int			mtx_type;
  };

#ifdef MTX_METER
#define MTX_TS_T(m) long m;
#define MTX_TS_SET(m, mtx) m = mtx->mtx_enters
#else
#define MTX_TS_T(m)
#define MTX_TS_SET(m, mtx)
#endif
/* thread_queue.c */
void thread_queue_init (thread_queue_t *thq);
void thread_queue_to (thread_queue_t *thq, thread_t *thr);
thread_t *thread_queue_remove (thread_queue_t *thq, thread_t *thr);
thread_t *thread_queue_from (thread_queue_t *thq);

/* thread_attr.c */
void _thread_init_attributes (thread_t *self);
void _thread_free_attributes (thread_t *self);

/* fiberXXX.c */
void _fiber_boot (thread_t * volatile self);
void _fiber_switch (thread_t *new_thread);
void _fiber_for_thread (thread_t *self, unsigned long stack_size);
void _fiber_status (thread_t *thr, int new_status);
void _fiber_schedule_next (void);
int _fiber_sleep (void *event, TVAL timeout);
void _fiber_event_loop (void);
TVAL msecs_elapsed (void);


/* io_unix.c */
void io_init (void);

extern thread_t *_current_fiber;	/* simulated threads only */
extern thread_queue_t _waitq;		/* simulated threads only */
extern timer_queue_t *_timerq;		/* simulated threads only */
extern int _num_runnables;		/* simulated threads only */

extern char *build_thread_model;
#endif

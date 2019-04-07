/*
 *  Dkthread.h
 *
 *  $Id$
 *
 *  Threads, Mutexes and Semaphores
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

#ifndef _DKTHREAD_H
#define _DKTHREAD_H

#define _OPL_THREADS	1
/*#define JMP_CKSUM*/

typedef struct jmp_buf_splice_s
  {
    jmp_buf buf;
#ifdef JMP_CKSUM
    uint32	j_cksum;
#endif
#ifdef SIGNAL_DEBUG
    const char *j_file;
    int j_line;
    struct jmp_buf_splice_s *j_parent;
#endif
  } jmp_buf_splice;


#ifdef JMP_CKSUM
#define longjmp_splice(b,f)	longjmp_brk ((b), f)
uint32 j_cksum (jmp_buf j);
int j_set_cksum (jmp_buf_splice * j, int rc);

#define setjmp_splice(b)	j_set_cksum (b, setjmp ((b)->buf))

void longjmp_brk (jmp_buf_splice * j, int rc);

#else
#define setjmp_splice(b)	setjmp ((b)->buf)
#define longjmp_splice(b,f)	longjmp ((b)->buf, f)
#endif

#if defined (__APPLE__)
#define thread_t opl_thread_t
#define semaphore_t opl_semaphore_t
#elif defined (GC_SOLARIS_THREADS)
#define thread_t opl_thread_t
#define rwlock_t opl_rwlock_t
#endif

#ifdef HAVE_PTHREAD_RWLOCK_INIT
#undef  rwlock_t
#define rwlock_t pthread_rwlock_t
#else
typedef struct rwlock_s rwlock_t;
#endif

typedef struct thread_s thread_t;
typedef struct semaphore_s semaphore_t;
typedef struct mutex_s dk_mutex_t;
typedef struct spinlock_s spinlock_t;

typedef int (*mtx_entry_check_t) (dk_mutex_t * mtx, thread_t * self, void * cd);

typedef int (*thread_init_func) (void *arg);

typedef int32 TVAL;
#define TV_INFINITE	((TVAL)-1)

#define thread_create  oplthread_create


/*
 *  Thread priority (thr_priority)
 */
#define LOW_PRIORITY	0	/* Priority below normal */
#define NORMAL_PRIORITY	1	/* Normal priority (default) */
#define HIGH_PRIORITY	2	/* Priority above normal */
#ifdef _MSC_VER
#undef MAX_PRIORITY
#endif
#define MAX_PRIORITY	3


#if defined (USING_TIKS)
# define without_scheduling_tic() \
  {  \
    int oldsig = sigblock(sigmask(SIGALRM));
# define restore_scheduling_tic() \
    sigsetmask(oldsig); \
  };
#else
# define without_scheduling_tic()
# define restore_scheduling_tic()
#endif


#define current_thread	thread_current()
#define thr_errno	(*thread_errno())

#define THREAD_CURRENT_THREAD	current_thread
#define THREAD_ALLOW_SWITCH()	thread_allow_schedule()
#define PROCESS_ALLOW_SCHEDULE() thread_allow_schedule()

/* Rename */
#define du_thread_t		thread_t
#define init_func		thread_init_func
#define current_process		thread_current()
#define THR_ATTR(th,a)		thread_getattr(th, (void *)(ptrlong) a)
#define SET_THR_ATTR(th,a,v)	thread_setattr(th, (void *)(ptrlong) a, v)
#define du_thread_init(sz)	thread_initial(sz)


#ifdef MTX_DEBUG
# define ASSERT_IN_MTX(mtx)  \
  if (THREAD_CURRENT_THREAD != (mtx)->mtx_owner) GPF_T1 ("Not inside mutex.");

# define ASSERT_OUTSIDE_MTX(mtx)  \
  if (THREAD_CURRENT_THREAD == (mtx)->mtx_owner) GPF_T1 ("Not outside mutex.");

#else
# define ASSERT_IN_MTX(mtx)
# define ASSERT_OUTSIDE_MTX(mtx)
#endif

BEGIN_CPLUSPLUS

extern int _thread_sched_preempt;
extern int _thread_num_total;
extern int _thread_num_runnable;
extern int _thread_num_wait;
extern int _thread_num_dead;

/* sched_fiber.c, sched_pthread.c, sched_winthread.c */
EXE_EXPORT (thread_t *, thread_current, (void));
EXE_EXPORT (thread_t *, thread_initial, (unsigned long stack_size));
EXE_EXPORT (thread_t *, thread_create, (thread_init_func init, unsigned long stack_size, void *init_arg));
EXE_EXPORT (thread_t *, thread_attach, (void));

EXE_EXPORT (void, thread_allow_schedule, (void));
EXE_EXPORT (void, thread_exit, (int n));
EXE_EXPORT (int *, thread_errno, (void));
EXE_EXPORT (int, thread_set_priority, (thread_t *self, int prio));
EXE_EXPORT (int, thread_get_priority, (thread_t *self));
EXE_EXPORT (void *, thread_setattr, (thread_t *self, void *key, void *value));
EXE_EXPORT (void *, thread_getattr, (thread_t *self, void *key));
extern void thread_freeze (void);
extern int thread_unfreeze (thread_t *self);
extern int thread_wait_cond (void *event, dk_mutex_t *holds, TVAL timeout);
extern int thread_signal_cond (void *event);
EXE_EXPORT (int, thread_release_dead_threads, (int leave_count));

/* fiber_unix.c, sched_pthread.c, sched_winthread.c */
extern int thread_select (int n, fd_set *rfds, fd_set *wfds, void *event, TVAL timeout);
extern void thread_sleep (TVAL msec);

EXE_EXPORT (caddr_t, thr_get_error_code, (thread_t *thr));
EXE_EXPORT (void, thr_set_error_code, (thread_t *thr, caddr_t err));
#ifdef MALLOC_DEBUG
extern caddr_t dbg_thr_get_error_code (const char *file, int line, thread_t *thr);
extern void dbg_thr_set_error_code (const char *file, int line, thread_t *thr, caddr_t err);
#define thr_get_error_code(thr) dbg_thr_get_error_code (__FILE__, __LINE__, (thr))
#define thr_set_error_code(thr,err) dbg_thr_set_error_code (__FILE__, __LINE__, (thr), (err))
#endif

struct sockaddr;

/* io_unix.c */
int thread_nb_fd (int fd);
int thread_open (char *fname, int mode, int perms);
int thread_close (int fd);
ssize_t thread_read (int fd, void *buffer, size_t length);
ssize_t thread_write (int fd, void *buffer, size_t length);
int thread_socket (int family, int type, int proto);
int thread_closesocket (int sock);
int thread_bind (int sock, struct sockaddr *addr, int len);
int thread_listen (int sock, int n);
int thread_accept (int sock, struct sockaddr *addr, int *plen, TVAL timeout);
int thread_connect (int sock, struct sockaddr *addr, int len);
ssize_t thread_send (int sock, void *buffer, size_t length, TVAL timeout);
ssize_t thread_recv (int sock, void *buffer, size_t length, TVAL timeout);

/* sched_fiber.c, sched_pthread.c, sched_winthread.c */
EXE_EXPORT (semaphore_t *, semaphore_allocate, (int entry_count));
EXE_EXPORT (void, semaphore_free, (semaphore_t *sem));
EXE_EXPORT (int, semaphore_enter, (semaphore_t *sem));
EXE_EXPORT (int, semaphore_try_enter, (semaphore_t *sem));
EXE_EXPORT (void, semaphore_leave, (semaphore_t *sem));
#ifdef SEM_DEBUG
void semaphore_leave_dbg (int ln, const char *file, semaphore_t *sem);
#define semaphore_leave(s) semaphore_leave_dbg (__LINE__, __FILE__, s)
#endif

EXE_EXPORT (dk_mutex_t *, mutex_allocate, (void));
dk_mutex_t *mutex_allocate_typed (int mutex_type);
void dk_mutex_init (dk_mutex_t * mtx, int type);
void dk_mutex_destroy (dk_mutex_t * mtx);
EXE_EXPORT (void, mutex_free, (dk_mutex_t *mtx));
EXE_EXPORT (int, mutex_enter, (dk_mutex_t *mtx));
EXE_EXPORT (void, mutex_leave, (dk_mutex_t *mtx));

#ifdef MTX_DEBUG
int mutex_enter_dbg (int ln, const char * file, dk_mutex_t *mtx);
void mutex_leave_dbg (int ln, const char * file, dk_mutex_t *mtx);
#ifndef _USRDLL
#ifndef EXPORT_GATE
#define mutex_enter(m) mutex_enter_dbg (__LINE__, __FILE__, m)
#define mutex_leave(m) mutex_leave_dbg (__LINE__, __FILE__, m)
#endif
#endif
#endif
#if defined (MTX_DEBUG) || defined (MTX_METER)
void mutex_option (dk_mutex_t * mtx, char * name, mtx_entry_check_t ck, void * cd);
#else
#define MUTEX_OPTION_NOP
#define mutex_option(mtx,name,ck,cd) do { ; } while (0)
#endif
EXE_EXPORT (int, mutex_try_enter, (dk_mutex_t *mtx));
void mutex_stat (int mode, int max);

spinlock_t * spinlock_allocate (void);
void spinlock_free (spinlock_t *self);
void spinlock_enter (spinlock_t *self);
void spinlock_leave (spinlock_t *self);

EXE_EXPORT (rwlock_t *, rwlock_allocate, (void));
EXE_EXPORT (void, rwlock_free, (rwlock_t *));
EXE_EXPORT (void, rwlock_rdlock, (rwlock_t *));
EXE_EXPORT (int, rwlock_tryrdlock, (rwlock_t *));
EXE_EXPORT (void, rwlock_wrlock, (rwlock_t *));
EXE_EXPORT (int, rwlock_trywrlock, (rwlock_t *));
EXE_EXPORT (void, rwlock_unlock, (rwlock_t *));



END_CPLUSPLUS

#endif /* _DKTHREAD_H */

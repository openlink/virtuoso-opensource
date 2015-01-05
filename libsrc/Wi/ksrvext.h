/*
 *  ksrvext.h
 *
 *  $Id$
 *
 *  Virtuoso Server Extension API
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
 */

#ifndef _KSRVEXT_H
#define _KSRVEXT_H


#include "exe_export.h"
#include <limits.h>
#include <sys/types.h>
#include <setjmp.h>
#include "Dksystem.h"
#include "Dktypes.h"
#include "Dkbox.h"
#include "widv.h"
#include "sqlparext.h"

#ifdef __cplusplus
# define BEGIN_CPLUSPLUS        extern "C" {
# define END_CPLUSPLUS          }
#else
# define BEGIN_CPLUSPLUS
# define END_CPLUSPLUS
#endif

#ifdef __MINGW32__
#define VIRTVARCLASS extern
#include <winsock2.h>
#elif defined (WIN32)
#define VIRTVARCLASS __declspec (dllimport)
#include <winsock2.h>
#else
#define VIRTVARCLASS extern
#endif

#define timer_t opl_timer_t

typedef unsigned char * db_buf_t;

typedef struct query_s query_t;

typedef struct client_connection_s client_connection_t;

typedef struct ws_connection_s ws_connection_t;

typedef void * state_slot_t;

typedef struct query_instance_s query_instance_t;

typedef caddr_t (*bif_t) (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);


typedef struct local_cursor_s
  {
    caddr_t *		lc_inst;
    int			lc_position;
    caddr_t		lc_error;
    caddr_t		lc_proc_ret; /* if stmt is a SQL procedure, this is the QA_PROC_RET block */
    int			lc_is_allocated; /* 1 if dk_alloc'd */
    caddr_t		lc_cursor_name; /* if lc implements scroll crsr and qi occurs in cli_cursors */
    int			lc_row_count;
  } local_cursor_t;


typedef struct stmt_options_s {
  ptrlong            so_concurrency;
  ptrlong            so_is_async;
  ptrlong            so_max_rows;
  ptrlong            so_timeout;
  ptrlong            so_prefetch;
  ptrlong            so_autocommit;
  ptrlong            so_rpc_timeout;
  ptrlong		  so_cursor_type;
  ptrlong		  so_keyset_size;
  ptrlong		  so_use_bookmarks;
  ptrlong		  so_isolation;
  ptrlong		  so_prefetch_bytes;
  ptrlong		so_unique_rows;
} stmt_options_t;

typedef void (*bif_type_func_t) (state_slot_t ** args, long *dtp, long *prec,
    long *scale, caddr_t *collation);

typedef struct
  {
    bif_type_func_t	bt_func;
    long		bt_dtp;
    long		bt_prec;
    long		bt_scale;
  } bif_type_t;

VIRTVARCLASS bif_type_t bt_varchar;
VIRTVARCLASS bif_type_t bt_any;
VIRTVARCLASS bif_type_t bt_integer;
VIRTVARCLASS bif_type_t bt_double;
VIRTVARCLASS bif_type_t bt_float;
VIRTVARCLASS bif_type_t bt_numeric;
VIRTVARCLASS bif_type_t bt_convert;
VIRTVARCLASS bif_type_t bt_timestamp;
VIRTVARCLASS bif_type_t bt_time;
VIRTVARCLASS bif_type_t bt_date;
VIRTVARCLASS bif_type_t bt_datetime;
VIRTVARCLASS bif_type_t bt_bin;


#define QRP_INT (long)0
#define QRP_STR (long)1
#define QRP_RAW (long)2

#define QST_INSTANCE(st)  ((caddr_t*) qst)


void bif_define (const char *name, bif_t bif);
void bif_define_typed (const char * name, bif_t bif, bif_type_t *bt);

caddr_t bif_arg (caddr_t * qst, state_slot_t ** args, int nth, const char * func);
caddr_t bif_string_arg (caddr_t * qst, state_slot_t ** args, int nth,
    const char * func);
caddr_t bif_strses_arg (caddr_t * qst, state_slot_t ** args, int nth,
    const char * func);
struct xml_entity_s *bif_entity_arg (caddr_t * qst, state_slot_t ** args, int nth,
    const char * func);
struct xml_tree_ent_s *bif_tree_ent_arg (caddr_t * qst, state_slot_t ** args, int nth,
    const char * func);
caddr_t bif_bin_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func);

caddr_t bif_string_or_null_arg (caddr_t * qst, state_slot_t ** args, int nth,
    const char * func);
caddr_t bif_string_or_wide_or_null_arg (caddr_t * qst, state_slot_t ** args, int nth,
    const char * func);
boxint bif_long_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func);
float bif_float_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func);
double bif_double_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func);
long bif_long_or_char_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func);
caddr_t bif_array_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func);
caddr_t bif_strict_array_or_null_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func);
caddr_t bif_array_or_null_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func);
void bif_result_inside_bif (int n, ...);

#ifndef srv_make_new_error
extern caddr_t srv_make_new_error (const char *code, const char *virt_code, const char *msg,...);
#endif
void sqlr_error (const char *code, const char *msg,...);
void sqlr_new_error (const char *code, const char *virt_code, const char *msg,...);
void sqlr_resignal (caddr_t err);

query_t * sql_compile (char *string2, client_connection_t * cli, caddr_t * err,
    int store_procs);
void qr_free (query_t * qr);

caddr_t qr_rec_exec (query_t * qr, client_connection_t * cli,
    local_cursor_t ** lc_ret, query_instance_t * caller, stmt_options_t * opts,
    long n_pars, ...);

long lc_next (local_cursor_t * lc);
caddr_t lc_nth_col (local_cursor_t * lc, int n);
void lc_free (local_cursor_t * lc);

client_connection_t * qi_client (caddr_t * qi);

caddr_t row_str_column (caddr_t * qst, db_buf_t str, char *tb_name,
    char *col_name, int *exists);

caddr_t row_str_table (caddr_t * qst, db_buf_t str);

void qst_free (caddr_t * qst);

void qst_set (caddr_t * state, state_slot_t * sl, caddr_t v);

int ssl_is_settable (state_slot_t * ssl);

caddr_t list (long n, ...);
caddr_t sc_list (long n, ...);
/* server start */

void srv_global_init (void);
void srv_plugins_init (void);

void db_crash_to_log (char *mode);

void db_to_log (void);

void db_recover_key (int k_id, int id);
void db_recover_keys (char *keys);

caddr_t row_str_column (caddr_t * qst, db_buf_t str, char *tb_name,
    char *col_name, int *exists);

char * dv_type_title (int type);

typedef void (*exit_hook_t) (void);

void VirtuosoServerSetInitHook (void (*hook) (void));
exit_hook_t VirtuosoServerSetExitHook (exit_hook_t exitf);
int VirtuosoServerMain (int argc, char **argv);

typedef int32 TVAL;
typedef struct timer_s timer_t;
typedef struct timer_queue_s timer_queue_t;
typedef int (*thread_init_func) (void *arg);
typedef struct mutex_s dk_mutex_t;
typedef struct semaphore_s semaphore_t;
typedef struct dk_thread_s dk_thread_t;
typedef void (*timer_callback_t) (void *arg);
typedef struct timeval timeval_t;

BEGIN_CPLUSPLUS

extern int _thread_sched_preempt;
extern int _thread_num_total;
extern int _thread_num_runnable;
extern int _thread_num_wait;
extern int _thread_num_dead;

int log_info (char *format, ...);
int log_debug (char *format, ...);
void thread_allow_schedule (void);
void thread_exit (int n);
int *thread_errno (void);
void thread_freeze (void);
int thread_wait_cond (void *event, dk_mutex_t *holds, TVAL timeout);
int thread_signal_cond (void *event);

int thread_select (int n, fd_set *rfds, fd_set *wfds, void *event, TVAL timeout);
void thread_sleep (TVAL msec);

struct sockaddr;

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
semaphore_t *semaphore_allocate (int entry_count);
void semaphore_free (semaphore_t *sem);
int semaphore_enter (semaphore_t *sem);
int semaphore_try_enter (semaphore_t *sem);
#ifdef SEM_DEBUG
void semaphore_leave_dbg (int ln, const char *file, semaphore_t *sem);
#define semaphore_leave(s) semaphore_leave_dbg (__LINE__, __FILE__, s)
#else
void semaphore_leave (semaphore_t *sem);
#endif

dk_mutex_t *mutex_allocate (void);
#ifdef WIN32
dk_mutex_t *mutex_allocate_typed (int mutex_type);
#else
#define mutex_allocate_typed(value) mutex_allocate()
#endif
void mutex_free (dk_mutex_t *mtx);
int mutex_enter (dk_mutex_t *mtx);
int mutex_try_enter (dk_mutex_t *mtx);
void mutex_leave (dk_mutex_t *mtx);


END_CPLUSPLUS

struct timer_s
  {
    timer_t *		tmr_next;	/* chain for activated timers */
    timer_t *		tmr_prev;	/* chain for activated timers */
    timer_queue_t *	tmr_queue;	/* owner */
    int			tmr_ref;	/* reference counter */
    int32		tmr_remain;	/* remaining time, if activated */
    TVAL		tmr_interval;	/* interval time for autorepeat */
    int			tmr_calling;	/* to avoid recursive locks */
    timer_callback_t	tmr_callout;	/* function to call when fired */
    void *		tmr_call_arg;	/* argument to tmr_callout */
  };

typedef struct thread_hdr_s thread_hdr_t;

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

typedef struct
  {
    jmp_buf buf;
  } jmp_buf_splice;

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
  /* preallocated thread attributes */
  jmp_buf_splice *	thr_reset_ctx;
  caddr_t		thr_reset_code;
  caddr_t		thr_func_value;
  void *		thr_tmp_pool;
  int                   thr_attached;
  caddr_t		thr_dbg;
#ifndef NDEBUG
  void *		thr_pg_dbg;
#endif
};

#define MAX_NESTED_FUTURES      20
typedef struct future_request_s future_request_t;
typedef struct thread_s thread_t;
#define du_thread_t             thread_t

struct dk_thread_s
{
  du_thread_t *       dkt_process;
  int                 dkt_request_count;
  future_request_t *  dkt_requests[MAX_NESTED_FUTURES];
};

typedef int (*mtx_entry_check_t) (dk_mutex_t * mtx, thread_t * self, void * cd);

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
#endif
    int			mtx_type;
  };

dk_thread_t * PrpcThreadAllocate (thread_init_func init, unsigned long stack_size, void *init_arg);
dk_thread_t * PrpcThreadAttach (void);
void PrpcThreadDetach (void);
int strses_aref (caddr_t ses1, int idx);

caddr_t box_narrow_string_as_utf8 (caddr_t _str, caddr_t narrow, long max_len,
    caddr_t _charset);
caddr_t box_wide_as_utf8_char (caddr_t _wide, long wide_len, dtp_t dtp);
caddr_t box_utf8_string_as_narrow (ccaddr_t _str, caddr_t narrow, long max_len,
    caddr_t _charset);
extern caddr_t box_utf8_as_wide_char (ccaddr_t _utf8, caddr_t _wide_dest,
    long utf8_len, long max_wide_len, dtp_t dtp);
caddr_t box_wide_char_string (caddr_t data, size_t len, dtp_t dtp);
caddr_t box_varchar_string (db_buf_t place, int len, dtp_t dtp);
caddr_t box_cast_to (caddr_t * qst, caddr_t data, dtp_t data_dtp,
    dtp_t to_dtp, ptrlong prec, ptrlong scale, caddr_t * err_ret);
void dt_to_parts (char *dt, int *year, int *month, int *day, int *hour,
    int *minute, int *second, int *fraction);
void dt_from_parts (char *dt, int year, int month, int day, int hour,
    int minute, int second, int fraction, int tz);

thread_t * thread_current (void);

#define NUMERIC_MAX_PRECISION		40
#define NUMERIC_MAX_SCALE		15

typedef struct dk_session_s dk_session_t;
typedef struct request_rec_t request_rec;

typedef struct buffer_elt_s buffer_elt_t;
struct buffer_elt_s
  {
    char *		data;
    int			fill;
    int			read;
    buffer_elt_t *	next;
  };

typedef enum { DKST_IDLE = 0, DKST_RUN, DKST_FINISH, DKST_BURST } dks_thread_state_t;

typedef struct basket_s basket_t;

struct basket_s
  {
    basket_t *		bsk_next;
    basket_t *		bsk_prev;
    union
      {
        long		longval;
	void *		ptrval;
      }			bsk_data;
  };

typedef struct hash_elt_s hash_elt_t;

struct hash_elt_s
  {
    const void *	key;
    void *		data;
    hash_elt_t *	next;
  };

typedef struct
  {
    hash_elt_t *	ht_elements;
    uint32		ht_count;
    uint32		ht_actual_size;
    uint32		ht_rehash_threshold;
#ifdef MTX_DEBUG
    dk_mutex_t *	ht_required_mtx;
#endif
#ifdef HT_STATS
    uint32		ht_max_colls;
    uint32		ht_stats[30];
    uint32		ht_ngets;
    uint32		ht_nsets;
#endif
  } dk_hash_t;

struct dk_session_s
  {
    session_t *		dks_session;

    dk_mutex_t *	dks_mtx;

    int			dks_refcount;
    int			dks_in_length;
    int			dks_in_fill;
    int			dks_in_read;

    char *		dks_in_buffer;

    buffer_elt_t *	dks_buffer_chain;
    buffer_elt_t *	dks_buffer_chain_tail;

    char *		dks_out_buffer;
    int			dks_out_length;
    int			dks_out_fill;

    struct scheduler_io_data_s *dks_client_data;	/*!< Used by scheduler */
    void *		dks_object_data;  /*!< Used by Distributed Objects */
    void *		dks_object_temp;  /*!< Used by Distributed Objects */
    OFF_T		dks_bytes_sent;   /*!< Used by Administration server */
    OFF_T		dks_bytes_received;/*!< Used by Administration server */


    char *		dks_peer_name;
    char *		dks_own_name;
    caddr_t *		dks_caller_id_opts;

    void *		dks_dbs_data;
    void *		dks_cluster_data; /* cluster interconnect state.  Not the same as dks_dbs_data because dks_dbs_data when present determines protocol versions and cluster is all the same version */
    void *		dks_write_temp;	/* Used by Distributed Objects */

        /*! max msecs to block on a read */
    timeout_t		dks_read_block_timeout;
    /*! Is this a client or server initiated session */
    char		dks_is_server;
    char		dks_cluster_flags;
    char		dks_to_close;
    char		dks_is_read_select_ready; /*! Is the next read known NOT to block */
    char		dks_ws_status;

    short		dks_n_threads;
    /*! time of last usage (get_msec_real_time) - use for dropping idle HTTP keep alives */
    uint32		dks_last_used;
    /*! burst mode */
    dks_thread_state_t  dks_thread_state;
    /*! web server thread associated to this if ws computation pending. Used to cancel upon client disconnect */
    void *		dks_ws_pending;

    /*! fixed server thread per client */
    du_thread_t *	dks_fixed_thread; /*!< note: also used to pass the http ses for chunked write */
    basket_t		dks_fixed_thread_reqs;

    du_thread_t *	dks_waiting_http_recall_session;
    dk_hash_t *		dks_pending_futures;
  };


void session_buffered_write_char (int c, dk_session_t * ses);
void print_long (long l, dk_session_t * session);
typedef int    (*ses_write_func) (void * obj, dk_session_t * session);
void PrpcSetWriter (dtp_t dtp, ses_write_func f);

#define SESSION_DK_SESSION(session) \
	(*((dk_session_t **) (&((session)->ses_client_data))))

#define DKSESSTAT_ISSET(x,y) \
	SESSTAT_ISSET(x->dks_session, y)

#define SES_WRITE(ses, s) session_buffered_write (ses, s, strlen (s))

#define current_thread  thread_current()
#define THREAD_CURRENT_THREAD   current_thread
#define SET_THR_ATTR(th,a,v)    thread_setattr(th, (void *)(long) a, v)
#define THR_ATTR(th,a)          thread_getattr(th, (void *)(long) a)

void strses_flush (dk_session_t *ses);
long strses_length (dk_session_t *ses);
void strses_free (dk_session_t *ses);
dk_session_t *strses_allocate (void);
int session_buffered_write (dk_session_t * ses, char *buffer, size_t length);
void * thread_getattr (thread_t *self, void *key);
thread_t * thread_current (void);
void * thread_setattr (thread_t *self, void *key, void *value);
int strnicmp (const char *s1, const char *s2, size_t n);

#ifdef MALLOC_DEBUG
#define DBG_NAME(nm) dbg_##nm
#define DBG_PARAMS char *file, int line,
#define DBG_ARGS file, line,
#define DK_ALLOC(SIZE) dbg_malloc(DBG_ARGS (SIZE))
#define DK_FREE(BOX,SIZE) dbg_free(DBG_ARGS (BOX))
#else
#define DBG_NAME(nm) nm
#define DBG_PARAMS
#define DBG_ARGS
#define DK_ALLOC dk_alloc
#define DK_FREE dk_free
#endif

typedef struct s_node_s s_node_t, *dk_set_t;
struct s_node_s
{
   void *              data;
   s_node_t *          next;
};

EXE_EXPORT (caddr_t, list_to_array, (dk_set_t l));
#ifdef MALLOC_DEBUG
caddr_t dbg_strses_string (DBG_PARAMS dk_session_t * ses);
caddr_t dbg_list_to_array (char *file, int line, dk_set_t l);
#define strses_string(S) dbg_strses_string (__FILE__, __LINE__, (S))
#ifndef _USRDLL
#ifndef EXPORT_GATE
#define list_to_array(S)	dbg_list_to_array (__FILE__, __LINE__, (S))
#endif
#endif
#else
caddr_t strses_string (dk_session_t * ses);
caddr_t list_to_array (dk_set_t l);
#endif

void dk_set_push (dk_set_t *ret, void *item);
dk_set_t dk_set_nreverse (dk_set_t set);

#define DV_EXTENSION_OBJ 255

#define DO_SET(type, var, set) \
	{ \
	  type var; \
	  s_node_t *iter = *set; \
	  s_node_t *nxt; \
	  for ( ; (NULL != iter); iter = nxt) \
	    { \
	      var = (type) (iter->data); \
	      nxt = iter->next;

#define END_DO_SET()   \
	    } \
	}

extern void (*ddl_init_hook) (client_connection_t *cli);


char *get_java_classpath (void);

int virtuoso_cfg_getstring (char *section, char *key, char **pret);
int virtuoso_cfg_getlong (char *section, char *key, long *pret);
int virtuoso_cfg_first_string (char * section, char **pkey, char **pret);
int virtuoso_cfg_next_string (char **pkey, char **pret);

void build_set_special_server_model (const char *new_model);void qi_check_trx_error (query_instance_t * qi, int only_terminate);
void qi_signal_if_trx_error (query_instance_t * qi);
#define isp_schema(x) isp_schema_1(x)
extern int http_ses_size;
void strses_enable_paging (dk_session_t *ses, int max_bytes_in_mem);

#endif /* _KSRVEXT_H */

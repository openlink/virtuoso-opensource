/*
 *  Dkernel.h
 *
 *  $Id$
 *
 *  RPC Kernel
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
 */

#ifndef _DKERNEL_H
#define _DKERNEL_H

typedef struct buffer_elt_s buffer_elt_t;
struct buffer_elt_s
{
  char *		data;
  int 			fill;
  int 			read;
  int 			fill_chars;
  unsigned 		space_exausted:1;
  buffer_elt_t *	next;
};

typedef struct dk_session_s dk_session_t;

typedef enum { DKST_IDLE = 0, DKST_RUN, DKST_FINISH, DKST_BURST } dks_thread_state_t;

#if 0
#define thrs_printf(x) 		fprintf x
#define thrs_fo 		stderr
#else
#define thrs_printf(x)
#endif

struct dk_session_s
{
  session_t *			dks_session;

  dk_mutex_t *			dks_mtx;

  int 				dks_refcount;
  int 				dks_in_length;
  int 				dks_in_fill;
  int 				dks_in_read;

  char *			dks_in_buffer;

  buffer_elt_t *		dks_buffer_chain;
  buffer_elt_t *		dks_buffer_chain_tail;

  char *			dks_out_buffer;
  int 				dks_out_length;
  int 				dks_out_fill;

  struct scheduler_io_data_s *	dks_client_data;	/*!< Used by scheduler */
  void *			dks_object_data;	/*!< Used by Distributed Objects */
  void *			dks_object_temp;	/*!< Used by Distributed Objects */
  OFF_T 			dks_bytes_sent;		/*!< Used by Administration server */
  OFF_T 			dks_bytes_received;	/*!< Used by Administration server */


  char *			dks_peer_name;
  char *			dks_own_name;
  caddr_t *			dks_caller_id_opts;

  void *			dks_dbs_data;
  void *			dks_cluster_data;	/* cluster interconnect state.  Not the same as dks_dbs_data because dks_dbs_data when present determines protocol vrsions and cluster is all the same version */
  void *			dks_write_temp;		/* Used by Distributed Objects */

  /*! max msecs to block on a connect */
  timeout_t 			dks_connect_timeout;
  /*! max msecs to block on a read */
  timeout_t 			dks_read_block_timeout;
  /*! max msecs to block on a write */
  timeout_t 			dks_write_block_timeout;
  /*! Is this a client or server initiated session */
  char 				dks_is_server;
  char 				dks_cluster_flags;
  char 				dks_to_close;
  char 				dks_is_read_select_ready;	/*! Is the next read known NOT to block */
  char 				dks_ws_status;
  char 				dks_error;		/* error here, because dks_session is empty for strses */
  short				dks_n_threads;

  /*! time of last usage (get_msec_real_time) - use for dropping idle HTTP keep alives */
  uint32 			dks_last_used;

  /*! burst mode */
  dks_thread_state_t 		dks_thread_state;

  /*! web server thread associated to this if ws computation pending. Used to cancel upon client disconnect */
  void *			dks_ws_pending;

  /*! fixed server thread per client */
  du_thread_t *			dks_fixed_thread;	/*!< note: also used to pass the http ses for chunked write */
  basket_t 			dks_fixed_thread_reqs;

  du_thread_t *			dks_waiting_http_recall_session;
  dk_hash_t *			dks_pending_futures;
  caddr_t			dks_top_obj;
  dk_set_t			dks_pending_obj;
};

/* dks_error */
#define DKSE_BAD_TAG 		1


#define SESSION_DK_SESSION(session) \
	(*((dk_session_t **) (&((session)->ses_client_data))))

#define DKSESSTAT_ISSET(x,y) \
	SESSTAT_ISSET(x->dks_session, y)

extern dk_mutex_t *thread_mtx;

#define DKST_RPC_DONE_NO_MTX(dks) \
            if (!dks->dks_fixed_thread) \
	      { \
		if (dks->dks_thread_state == DKST_RUN) \
		  { \
		    dks->dks_thread_state = DKST_FINISH; \
		    thrs_printf ((thrs_fo, "ses %p thr:%p to finish\n", dks, THREAD_CURRENT_THREAD)); \
		  } \
		else if (dks->dks_thread_state != DKST_BURST) \
		  GPF_T; \
	      }

#define DKST_RPC_DONE(dks) \
        if (!DK_CURRENT_THREAD->dkt_requests[0]->rq_is_second) \
	  { \
	    mutex_enter (thread_mtx); \
            DKST_RPC_DONE_NO_MTX (dks); \
	    mutex_leave (thread_mtx); \
	  }

typedef struct future_request_s future_request_t;
typedef struct service_s service_t;
typedef struct dk_thread_s dk_thread_t;

struct future_request_s
{
  service_t *		rq_service;
#ifndef PMN_MODS
  jmp_buf_splice 	rq_start_context;
#endif
  long **		rq_arguments;
  dk_session_t *	rq_client;
  long 			rq_condition;
#ifndef PMN_MODS
  int 			rq_ancestor_count;
  future_request_t **	rq_ancestors;
#endif
  dk_thread_t *		rq_thread;
  future_request_t *	rq_next_waiting;
  int 			rq_is_direct_io;

#ifndef NDEBUG
  caddr_t 		rq_peer_name;
#endif
  int 			rq_to_close;
  int 			rq_is_second;
};

typedef char *(*server_func) (caddr_t x, ...);
typedef void (*post_func) (caddr_t b, future_request_t * f);

/*
 * struct dk_thread_t
 *
 * This represents the high level data on a thread.
 * The action of the thread is represented by the initial_funcion and
 * initial_argument.
 *
 * The status is either RUNNABLE or STOPPED. These tell the scheduler
 * whether to resume the thread when it comes to the execution turn.
 *
 * The wait_func and wait_arg allow temporarily setting the thread in busy wait
 * The scheduler will call this function if it is supplied before
 * resuming the thread. If the wait_func returns true the thread is resumable.
 *
 * The array of future requests represents the future computations in progress.
 * Computations may be nested if an outgoing service request
 * causes a follow up request on the server. If no parallel threads are
 * available the nested request is scheduled onto the ancestor thread.
 */

struct dk_thread_s
{
  du_thread_t *		dkt_process;
  int 			dkt_request_count;
  future_request_t *	dkt_requests[MAX_NESTED_FUTURES];
  int 			dkt_fixed_thread;
};

#define DK_THREAD_PROCESS(x) \
	((x)->dkt_process)

#define DK_THREAD_SEM(x) \
	(DK_THREAD_PROCESS(x)->thr_sem)

#define PROCESS_TO_DK_THREAD(p) \
	((dk_thread_t *) ((p)->thr_client_data))

#define DK_CURRENT_THREAD \
	    PROCESS_TO_DK_THREAD (THREAD_CURRENT_THREAD)

#define IMMEDIATE_CLIENT \
	(DK_CURRENT_THREAD->dkt_requests[0]->rq_client)

#define IMMEDIATE_CLIENT_OR_NULL \
	(DK_CURRENT_THREAD->dkt_requests[0] ? IMMEDIATE_CLIENT : NULL)

#define THIS_COND_NO \
	(DK_CURRENT_THREAD->dkt_requests \
	 [DK_CURRENT_THREAD->dkt_request_count-1]->rq_condition)


/*
 * struct service_desc_t
 *
 * This structure represents a service that a dis kit client uses.
 * This structure exists on the client. The arg_types is an array
 * that holds values from the DV<xxx> group. See messages.h.
 */
typedef struct
{
  char *		sd_name;
  int 			sd_arg_count;
  long *		sd_arg_types;
  int 			sd_type;
  dtp_t 		sd_return_type;
  char *		sd_arg_nullable;
} service_desc_t;

#define SERVICE_0(name1, str, send, ret_dtp) \
  service_desc_t name1 = { str, 0, NULL, send, ret_dtp }

#define SERVICE_1(name1, name2, str, send, ret_dtp, a1, n1) \
  static long _args_##name1 [1] = { a1 }; \
  static char _args_null_##name1 [1] = { n1 }; \
  service_desc_t name1 = { str, 1, _args_##name1, send, ret_dtp, _args_null_##name1 }

#define SERVICE_2(name1, name2, str, send, ret_dtp, a1, n1, a2, n2) \
  static long _args_##name1 [2] = { a1,a2 }; \
  static char _args_null_##name1 [2] = { n1,n2 }; \
  service_desc_t name1 = { str, 2, _args_##name1, send, ret_dtp, _args_null_##name1 }

#define SERVICE_3(name1, name2, str, send, ret_dtp, a1,n1,a2,n2,a3,n3) \
  static long _args_##name1 [3] = { a1,a2,a3 }; \
  static char _args_null_##name1 [3] = { n1,n2,n3 }; \
  service_desc_t name1 = { str, 3, _args_##name1, send, ret_dtp, _args_null_##name1 }

#define SERVICE_4(name1, name2, str, send, ret_dtp, a1,n1,a2,n2,a3,n3,a4,n4) \
  static long _args_##name1 [4] = { a1,a2,a3,a4 }; \
  static char _args_null_##name1 [4] = { n1,n2,n3,n4 }; \
  service_desc_t name1 = { str, 4, _args_##name1, send, ret_dtp, _args_null_##name1 }

#define SERVICE_5(name1, name2, str, send, ret_dtp, a1,n1,a2,n2,a3,n3,a4,n4,a5,n5) \
  static long _args_##name1 [5] = { a1,a2,a3,a4,a5 }; \
  static char _args_null_##name1 [5] = { n1,n2,n3,n4,n5 }; \
  service_desc_t name1 = { str, 5, _args_##name1, send, ret_dtp, _args_null_##name1 }

#define SERVICE_6(name1, name2, str, send, ret_dtp, a1,n1,a2,n2,a3,n3,a4,n4,a5,n5,a6,n6) \
  static long _args_##name1 [6] = { a1,a2,a3,a4,a5,a6 }; \
  static char _args_null_##name1 [6] = { n1,n2,n3,n4,n5,n6 }; \
  service_desc_t name1 = { str, 6, _args_##name1, send, ret_dtp, _args_null_##name1 }

#define SERVICE_7(name1, name2, str, send, ret_dtp, a1,n1,a2,n2,a3,n3,a4,n4,a5,n5,a6,n6,a7,n7) \
  static long _args_##name1 [7] = { a1,a2,a3,a4,a5,a6,a7 }; \
  static char _args_null_##name1 [7] = { n1,n2,n3,n4,n5,n6,n7 }; \
  service_desc_t name1 = {str, 7, _args_##name1, send, ret_dtp, _args_null_##name1 }

#define SERVICE_8(name1, name2, str, send, ret_dtp, a1,n1,a2,n2,a3,n3,a4,n4,a5,n5,a6,n6,a7,n7,a8,n8) \
  static long _args_##name1 [8] = { a1,a2,a3,a4,a5,a6,a7,a8 }; \
  static char _args_null_##name1 [8] = { n1,n2,n3,n4,n5,n6,n7,n8 }; \
  service_desc_t name1 = {str, 8, _args_##name1, send, ret_dtp, _args_null_##name1 }

#define SERVICE_9(name1, name2, str, send, ret_dtp, a1,n1,a2,n2,a3,n3,a4,n4,a5,n5,a6,n6,a7,n7,a8,n8,a9,n9) \
  static long _args_##name1 [9] = { a1,a2,a3,a4,a5,a6,a7,a8,a9 }; \
  static char _args_null_##name1 [9] = { n1,n2,n3,n4,n5,n6,n7,n8,n9 }; \
  service_desc_t name1 = {str, 9, _args_##name1, send, ret_dtp, _args_null_##name1 }


/*
 *  struct service_t
 *
 *  This represents a service offered by a server on the server.
 *
 *  The return type is a value in the DV<xxx> group.
 */
struct service_s
{
  char *		sr_name;
  void *		sr_client_data;
  server_func 		sr_func;
  post_func 		sr_postprocess;
  int 			sr_return_type;
  service_t *		sr_next;
};

/*
 *  struct future_t
 *
 * This represents a pending or complete future request on the client.
 * The request_no matches the condition member in the server's
 * future_request_t struct.
 */

typedef struct future_s
{
  dk_session_t *	ft_server;
  ptrlong 		ft_request_no;
  service_desc_t *	ft_service;
  caddr_t *		ft_arguments;
  caddr_t 		ft_result;
  caddr_t 		ft_error;
  int 			ft_is_ready;
  timeout_t 		ft_timeout;
  timeout_t 		ft_time_issued;
  timeout_t 		ft_time_received;
  future_request_t *	ft_waiting_requests;
} future_t;

/* Value stored in ft_error member of future_t struct upon time out */
#define FE_TIMED_OUT		1

/*  possible values of ft_is_ready flag */
#define FS_FALSE		0
#define FS_SINGLE_COMPLETE	1
#define FS_RESULT_LIST		2
#define FS_RESULT_LIST_COMPLETE	3


#define FUTURE_IS_READY(future) \
	(future->ft_is_ready)

#define FUTURE_IS_NEXT_RESULT(future) \
	(future->ft_result)

#define FUTURE_IS_EXHAUSTED(future) \
	(!(future->ft_result) && \
	  (future->ft_is_ready == FS_RESULT_LIST_COMPLETE))

#define FUTURE_IS_TIMED_OUT(f) \
	(f->ft_error == (caddr_t) FE_TIMED_OUT)

/* Future results are of type DV_ARRAY_OF_POINTER.
   usually we are only interested in the first one. */
#define FUTURE_RESULT_FIRST(future_result) \
	(future_result ? ((caddr_t) unbox_ptrlong (((caddr_t *)(future_result))[0])) : NULL)



/*
 *  struct scheduler_io_data_t
 *
 * This is an extension to the dk_session_t structure used to hold
 * scheduling data.
 *
 * The default_read_ready_action is invoked when the session is ready
 * for input and there is no random_read_ready_action.
 * If there is a random_write_ready_action it is invoked when the session
 * is ready for output.
 *
 * The random actions are mostly used when the session blocks.
 * The thread then stops and the scheduler will wake it up when the
 * blocking condition is part.
 * Hence the reading and writing threads that are passed to the above functions.
 *
 */
typedef int (*io_action_func) (dk_session_t * ses);

typedef struct scheduler_io_data_s
{
  io_action_func 	sio_default_read_ready_action;
  io_action_func 	sio_random_read_ready_action;
  io_action_func 	sio_random_write_ready_action;
  du_thread_t *		sio_writing_thread;
  du_thread_t *		sio_reading_thread;
  int 			sio_is_served;
  /* Index in served sessions table, if it is there */
  int 			sio_is_regular_input;
  /* true if regularly checked for client input */
  io_action_func 	sio_partner_dead_action;
  int 			sio_read_fail_on;
  int 			sio_write_fail_on;
  io_action_func	sio_w_timeout_hook;
  io_action_func	sio_r_timeout_hook;
  jmp_buf_splice 	sio_read_broken_context;
  jmp_buf_splice 	sio_write_broken_context;
  void *		sio_client_data;	/* For application use */
} scheduler_io_data_t;

#if defined (NO_THREAD)
#define read_service_request read_service_request_1t
#endif


#define SESSION_SCH_DATA(ses) \
	(*((scheduler_io_data_t **) (&((ses)->dks_client_data))))

/* The session will not be listened to by check_inputs() */
#define SESSION_CHECK_OUT(session) \
	SESSION_SCH_DATA(session)->sio_default_read_ready_action = \
		(io_action_func) random_read_ready_while_direct_io

/* Re-enable services reading */
#define SESSION_CHECK_IN(session) \
	SESSION_SCH_DATA(session)->sio_default_read_ready_action = \
		read_service_request

#define CATCH_READ_FAIL(ses) \
  SESSION_SCH_DATA (ses)->sio_read_fail_on = 1; \
  if (0 == setjmp_splice (&SESSION_SCH_DATA (ses)->sio_read_broken_context))


#define SAVE_READ_FAIL(ses) \
{ \
  scheduler_io_data_t __siod, *__siod_save = SESSION_SCH_DATA(ses); \
  memset (&__siod, 0, sizeof (__siod));				    \
  SESSION_SCH_DATA (ses) = &__siod;


#define RESTORE_READ_FAIL(ses) \
  SESSION_SCH_DATA(ses) = __siod_save; \
}

#define CATCH_READ_FAIL_S(ses) \
	{ \
	  jmp_buf_splice old_ctx; \
	  int volatile have_old_ctx = 0; \
	  if (SESSION_SCH_DATA (ses)->sio_read_fail_on == 1) { \
	    memcpy (&old_ctx, &SESSION_SCH_DATA (ses)->sio_read_broken_context, sizeof (jmp_buf_splice)); \
	    have_old_ctx = 1;\
	  } \
	  SESSION_SCH_DATA (ses)->sio_read_fail_on = 1; \
	  if (0 == setjmp_splice (&SESSION_SCH_DATA (ses)->sio_read_broken_context))

#define END_READ_FAIL_S(ses) \
	  if (!have_old_ctx) \
  	    SESSION_SCH_DATA(ses)->sio_read_fail_on = 0; \
	  else \
	    memcpy (&SESSION_SCH_DATA (ses)->sio_read_broken_context, &old_ctx, sizeof (jmp_buf_splice)); \
	}

#define THROW_READ_FAIL_S(ses) \
	  if (have_old_ctx) \
	   { \
	     memcpy (&SESSION_SCH_DATA (ses)->sio_read_broken_context, &old_ctx, sizeof (jmp_buf_splice)); \
	     longjmp_splice (&old_ctx, 1); \
	   }

#define CATCH_WRITE_FAIL(ses) \
  SESSION_SCH_DATA (ses)->sio_write_fail_on = 1; \
  if (0 == setjmp_splice (&SESSION_SCH_DATA (ses)->sio_write_broken_context))

#ifdef _MSC_VER
#undef FAILED
#endif
#define FAILED else

#define END_READ_FAIL(ses) \
  SESSION_SCH_DATA(ses)->sio_read_fail_on = 0;

#define END_WRITE_FAIL(ses) \
  SESSION_SCH_DATA(ses)->sio_write_fail_on = 0;


#define CHECK_READ_FAIL(ses) \
  if (SESSION_SCH_DATA (ses) && !SESSION_SCH_DATA (ses)->sio_read_fail_on) \
    GPF_T1("No read fail ctx");

#define CHECK_WRITE_FAIL(ses) \
  if (ses->dks_session && ses->dks_session->ses_class != SESCLASS_STRING && SESSION_SCH_DATA (ses) && !SESSION_SCH_DATA (ses)->sio_write_fail_on) \
    GPF_T1("No write fail ctx");


#ifndef NDEBUG
# define DBG_CHECK_READ_FAIL(ses) CHECK_READ_FAIL(ses)
# define DBG_CHECK_WRITE_FAIL(ses) CHECK_WRITE_FAIL(ses)
#else
# define DBG_CHECK_READ_FAIL(ses)
# define DBG_CHECK_WRITE_FAIL(ses)
#endif


/*
 *  Codes for Remote Actions
 */

#define DA_FUTURE_REQUEST		1
#define DA_FUTURE_ANSWER		2
#define DA_FUTURE_PARTIAL_ANSWER	3
#define DA_DIRECT_IO_FUTURE_REQUEST	4
#define DA_CALLER_IDENTIFICATION	5

/*
 * The below constants are the offsets of message parts
 * inside an ARRAY_OF_POINTER format.
 */

#define DA_MESSAGE_TYPE			0			   /* futur, answer or something else */

/*
 * FRQ = future request
 */
#define FRQ_COND_NUMBER			1
#define FRQ_ANCESTRY			2
#define FRQ_SERVICE_NAME		3
#define FRQ_ARGUMENTS			4

#define DA_FRQ_LENGTH			5

#define IS_FRQ(r) ((r) && IS_BOX_POINTER ((r)) && BOX_ELEMENTS_0 ((r)) >= DA_FRQ_LENGTH && (r)[DA_MESSAGE_TYPE] == DA_FUTURE_REQUEST && IS_STRING_DTP (DV_TYPE_OF ((r)[FRQ_SERVICE_NAME])))

/*
 * RRC = remote realize condition = future answer.
 */
#define RRC_COND_NUMBER			1
#define RRC_VALUE			2
#define RRC_ERROR			3

#define DA_ANSWER_LENGTH		4


typedef caddr_t (*srv_req_hook_func) (dk_session_t * session, caddr_t request);

typedef void (*sch_hook_func) (void);

typedef void (*background_action_func) (void);

typedef int (*printer_ext_func) (caddr_t obj, dk_session_t * ses, void *ext, caddr_t ea);

typedef void (*disconnect_callback_func) (dk_session_t * ses);

#if 0							   /* moved to Dkmarshal.h */
typedef caddr_t (*macro_char_func) (dk_session_t * ses, char macro);

typedef int (*ses_write_func) (caddr_t thing, dk_session_t * session, printer_ext_func extension, void *ea, int flush);
#else
#include "Dkmarshal.h"
#endif

/*
 *  Global data
 */
#ifdef GSTATE
typedef struct dkstat
{
  du_thread_t 			ds_threads[MAX_THREADS];
  /*du_thread_t *ds_current_process; */
  du_thread_t *			ds_initial_process;
  long 				ds_stack_limit;
  long 				ds_stack_allocation;

  dk_session_t *		ds_served_sessions[MAX_SESSIONS];
  unsigned long 		ds_last_future;
  service_t *			ds_services;

  int 				ds_is_initialized;
  basket_t 			ds_in_basket;
  basket_t 			ds_continue_basket;
  dk_hash_t *			ds_protocols;
  dk_hash_t *			ds_pending_futures;
  background_action_func 	ds_background_action;

  long 				ds_main_thread_sz;
  long 				ds_future_thread_sz;
  long 				ds_server_thread_sz;
  int 				ds_last_session;
  int 				ds_atomic_ctr;
  timeout_t 			ds_atomic_timeout;
  dk_mutex_t *			ds_value_mtx;

  resource_t *			ds_free_threads;
  int 				ds_future_thread_count;
  int 				ds_max_future_threads;
  ses_write_func 		ds_write_in_session;
  sch_hook_func 		ds_scheduler_hook;
  srv_req_hook_func 		ds_service_request_hook;
  macro_char_func 		ds_readtable[256];
  long 				ds_connection_count;
  char *			ds_i_am;
  int *				ds_client_ds;
  int 				ds_select_set_changed;
} dkstat_t;

#define threads dkstat->ds_threads
/*#define current_process dkstat->ds_current_process */
#define initial_process 	dkstat->ds_initial_process
#define StackLimit 		dkstat->ds_stack_limit
#define stack_allocation 	dkstat->ds_stack_allocation

#define served_sessions 	dkstat->ds_served_sessions
#define last_future 		dkstat->ds_last_future
#define services 		dkstat->ds_services

#define prpcinitialized 	dkstat->ds_is_initialized
#define in_basket 		dkstat->ds_in_basket
#define continue_basket 	dkstat->ds_continue_basket
#define protocols 		dkstat->ds_protocols
#define pending_futures 	dkstat->ds_pending_futures
#define background_action 	dkstat->ds_background_action

#define main_thread_sz 		dkstat->ds_main_thread_sz
#define future_thread_sz 	dkstat->ds_future_thread_sz
#define server_thread_sz 	dkstat->ds_server_thread_sz
#define last_session 		dkstat->ds_last_session
#define atomic_ctr 		dkstat->ds_atomic_ctr
#define atomic_timeout 		dkstat->ds_atomic_timeout
#define value_mtx 		dkstat->ds_value_mtx

#define free_threads 		dkstat->ds_free_threads
#define future_thread_count 	dkstat->ds_future_thread_count
#define max_future_threads 	dkstat->ds_max_future_threads
#define write_in_session 	dkstat->ds_write_in_session
#define scheduler_hook 		dkstat->ds_scheduler_hook
#define service_request_hook 	dkstat->ds_service_request_hook
#define readtable  		dkstat->ds_readtable
#define connection_count  	dkstat->ds_connection_count
#define i_am 			dkstat->ds_i_am
#define select_set_changed  	dkstat->ds_select_set_changed

#define USE_GLOBAL \
	dkstat_t *dkstat = get_global_state ();

#define TAKE_G			dkstat_t *dkstat,
#define TAKE_G1			dkstat_t *dkstat
#define PASS_G			dkstat,
#define PASS_G1			dkstat
#define GSTATE

dkstat_t *get_global_state (void);

#else
#define USE_GLOBAL
#define TAKE_G
#define TAKE_G1			void
#define PASS_G
#define PASS_G1


extern dk_mutex_t *value_mtx;

extern background_action_func background_action;
extern long sesclass_default;

extern timeout_t time_now;
extern timeout_t atomic_timeout;
extern timeout_t dks_fibers_blocking_read_default_to;

extern ses_write_func write_in_session;
extern dk_hash_t *pending_futures;

extern basket_t continue_basket;
extern basket_t in_basket;

extern resource_t *free_threads;
extern dk_session_t *served_sessions[MAX_SESSIONS];

extern du_thread_t *initial_process;

extern int atomic_ctr;

/* extern macro_char_func readtable [256]; */

extern long connection_count;

extern char *i_am;

extern char *c_ssl_server_port;
extern char *c_ssl_server_cert;
extern char *c_ssl_server_key;
extern long future_thread_sz;	/* from dkernel.c */
#endif

#define CB_PREPARE
#define CB_DONE

/* PrpcAddAnswer */
#define FINAL 			0
#define PARTIAL			1

#define PRPC_ANSWER_START(thr, is_partial) \
{ \
  future_request_t * frq = ((dk_thread_t *) thr -> thr_client_data) -> dkt_requests [0]; \
  dk_session_t * __ses = frq -> rq_client; \
  mutex_enter (__ses -> dks_mtx); \
  CATCH_WRITE_FAIL (__ses) { \
    PrpcAnswerHead (thr, is_partial);


#define PRPC_ANSWER_END(flush) \
    PrpcAnswerTail (__ses, flush); \
  } \
  mutex_leave (__ses -> dks_mtx); \
}

typedef void (*self_signal_func) (caddr_t);


typedef struct self_signal_s
{
  self_signal_func 		ss_func;
  caddr_t 			ss_cd;
} self_signal_t;


/* Dksesinp.c */
dk_session_t *inpses_allocate (void);
int inpses_unread_data (dk_session_t * ses);
#if defined(_MSC_VER) && defined(_DEBUG)
void inpses_verify (dk_session_t * ses);
#endif
#define SESSION_IS_INPROCESS(ses) 	(SESSION_IS_STRING (ses) && ses->dks_mtx != NULL)

/* Dksesstr.c */

typedef size_t strses_dump_callback_t (const void *ptr, size_t size, size_t nmemb, void *app_env);

device_t *strdev_allocate (void);
void strses_rewind (dk_session_t * ses);
void strses_map (dk_session_t * ses, void (*func) (buffer_elt_t * e, caddr_t arg), caddr_t arg);
void strses_file_map (dk_session_t * ses, void (*func) (buffer_elt_t * e, caddr_t arg), caddr_t arg);
EXE_EXPORT (void, strses_flush, (dk_session_t * ses));
EXE_EXPORT (int64, strses_length, (dk_session_t * ses));
int64 strses_chars_length (dk_session_t * ses);
EXE_EXPORT (void, strses_write_out, (dk_session_t * ses, dk_session_t * out));
void strses_set_int32 (dk_session_t * ses, int64 offset, int32 val);
void strses_to_array (dk_session_t * ses, char *buffer);
size_t strses_fragment_to_array (dk_session_t * ses, char *buffer, size_t fragment_offset, size_t fragment_size);
#if 0							   /* No longer in use */
extern void strses_read_by_callbacks (dk_session_t * ses, char *tmp_buf, size_t tmp_buf_len, strses_dump_callback_t * cbk, void *app_env);
#endif

int strses_is_ws_chunked_output (dk_session_t * ses);
void strses_ws_chunked_state_set (dk_session_t * ses, dk_session_t * http_ses);
void strses_ws_chunked_state_reset (dk_session_t * ses);
extern char *ses_tmp_dir;
extern timeout_t time_now;

EXE_EXPORT (dk_session_t *, strses_allocate, (void));
EXE_EXPORT (caddr_t, strses_string, (dk_session_t * ses));
EXE_EXPORT (caddr_t, strses_wide_string, (dk_session_t * ses));
extern caddr_t t_strses_string (dk_session_t * ses);
void strses_set_utf8 (dk_session_t * ses, int is_utf8);
int strses_is_utf8 (dk_session_t * ses);

#ifdef MALLOC_DEBUG
dk_session_t *dbg_strses_allocate (DBG_PARAMS_0);
caddr_t dbg_strses_string (DBG_PARAMS dk_session_t * ses);
caddr_t dbg_strses_wide_string (DBG_PARAMS dk_session_t * ses);
#ifndef _USRDLL
#ifndef EXPORT_GATE
#define strses_allocate() 		dbg_strses_allocate (__FILE__, __LINE__)
#define strses_string(S) 		dbg_strses_string (__FILE__, __LINE__, (S))
#define strses_wide_string(S) 		dbg_strses_wide_string (__FILE__, __LINE__, (S))
#endif
#endif
#endif
EXE_EXPORT (void, strses_free, (dk_session_t * ses));
typedef long (*copy_func_ptr_t) (void *dest_ptr, void *src_ptr, long src_ofs, long copy_bytes, void *state_data);
long strses_get_part_1 (dk_session_t * ses, void *buf2, int64 starting_ofs, long nbytes, copy_func_ptr_t cpf, void *state_data);
long strses_get_part (dk_session_t * ses, void *buffer, int64 starting_ofs, long nbytes);
long strses_get_wide_part (dk_session_t * ses, wchar_t * buf, long starting_ofs, long nchars);

void strses_serialize (caddr_t strses, dk_session_t * ses);
long strses_cp_utf8_to_utf8 (unsigned char *dest_ptr, unsigned char *src_ptr, long src_ofs, long copy_chars, void *state_data);
#define SESSION_IS_STRING(ses) 		(ses->dks_session && SESCLASS_STRING == ses->dks_session->ses_class)

/* Dksestcp.c */
device_t *tcpdev_allocate (void);
void strses_enable_paging (dk_session_t * ses, int max_bytes_in_mem);
char *dk_parse_address (char *str);
int alldigits (char *string);
EXE_EXPORT (void, tcpses_set_fd, (session_t * ses, int fd));
EXE_EXPORT (int, tcpses_get_fd, (session_t * ses));
EXE_EXPORT (int, tcpses_get_last_w_errno, (void));
EXE_EXPORT (int, tcpses_get_last_r_errno, (void));
unsigned int tcpses_get_port (session_t * ses);
int tcpses_client_port (session_t * ses);
int tcpses_getsockname (session_t * ses, char *buf_out, int buf_out_len);
void tcpses_set_reuse_address (int f);
int tcpses_is_read_ready (session_t * ses, timeout_t * to);
int tcpses_is_write_ready (session_t * ses, timeout_t * to);
int tcpses_select (int ses_count, session_t ** reads, session_t ** writes, timeout_t * timeout);
int tcpses_addr_info (session_t * ses, char *buf, size_t max_buf, int deflt, int from);
void tcpses_print_client_ip (session_t * ses, char *buf, int buf_len);
void tcpses_error_message (int saved_errno, char *msgbuf, int size);
dk_session_t *tcpses_make_unix_session (char *address);
#ifdef COM_UNIXSOCK
#define UNIXSOCK_ADD_ADDR 		"/tmp/virt_"
#endif

#ifdef _SSL
void sslses_to_tcpses (session_t * ses);
void tcpses_to_sslses (session_t * ses, void *s_ssl);
caddr_t tcpses_get_ssl (session_t * ses);
caddr_t ssl_new_connection (void);
int cli_ssl_get_error_string (char *out_data, int out_data_len);
caddr_t ssl_get_x509_error (caddr_t ssl);
#endif

/* Dkses2.c */
void random_read_ready_while_direct_io (void);
EXE_EXPORT (int, service_write, (dk_session_t * ses, char *buffer, int bytes));
EXE_EXPORT (int, session_flush_1, (dk_session_t * ses));
EXE_EXPORT (int, session_flush, (dk_session_t * session));
EXE_EXPORT (int, session_buffered_write, (dk_session_t * ses, const char *buffer, size_t length));
EXE_EXPORT (void, session_buffered_write_char, (int c, dk_session_t * ses));
/*void session_buffered_write_char (unsigned char ch, dk_session_t *ses); */
EXE_EXPORT (int, service_read, (dk_session_t * ses, char *buffer, int req_bytes, int need_all));
EXE_EXPORT (int, session_buffered_read, (dk_session_t * ses, char *buffer, int req_bytes));
EXE_EXPORT (dtp_t, session_buffered_read_char, (dk_session_t * ses));
/*char session_buffered_read_char (dk_session_t *ses);*/

#define SES_PRINT(ses, s) 		session_buffered_write (ses, s, strlen (s))

/* Dkmarshal.c */
#if 0							   /* moved to Dkmarshal.h */
void * scan_session (dk_session_t * ses);
void * scan_session_boxing (dk_session_t * ses);
long read_long (dk_session_t * ses);
caddr_t read_float (dk_session_t * session);
double read_double (dk_session_t * session);
caddr_t read_short_string (dk_session_t * session, dtp_t dtp);
caddr_t read_ref_box (dk_session_t * session, dtp_t dtp);
caddr_t read_db_null (dk_session_t * ses);
caddr_t read_long_string (dk_session_t * session);
caddr_t read_short_cont_string (dk_session_t * session);
caddr_t read_long_cont_string (dk_session_t * session);
caddr_t read_short_int (dk_session_t * ses, unsigned char macro);
caddr_t read_array (dk_session_t * ses, unsigned char macro);
caddr_t read_array_of_double (dk_session_t * ses, unsigned char macro);
caddr_t read_array_of_float (dk_session_t * ses, unsigned char macro);
caddr_t read_array_of_long (dk_session_t * ses, unsigned char macro);
caddr_t read_null (dk_session_t * ses, char c);
void macro_character_error (dk_session_t * ses, char c);
void init_readtable (void);
caddr_t read_object (dk_session_t * ses);
void print_long (long n1, dk_session_t * session);
void print_float (float f, dk_session_t * session);
void print_double (double n, dk_session_t * session);
void print_raw_float (float f, dk_session_t * session);
void print_raw_double (double n, dk_session_t * session);
void print_int (long n, dk_session_t * session);
void dks_array_head (dk_session_t * ses, int n_elements, dtp_t type);
void print_string (const char *string, dk_session_t * session);
void print_uname (const char *string, dk_session_t * session);
void print_ref_box (const char *string, dk_session_t * session);
void PrpcSetWriter (dtp_t dtp, ses_write_func f);
void print_object (caddr_t object, dk_session_t * session, printer_ext_func extension, caddr_t ea);
int srv_write_in_session (caddr_t thing, dk_session_t * session, printer_ext_func extension, void *xx, int flush);
int PrpcWriteObject (dk_session_t * ses, caddr_t thing);
caddr_t PrpcReadObject (dk_session_t * ses);
void set_write_in_session (ses_write_func f);
macro_char_func *get_readtable (void);
#endif

/* Dkernel.c */
int add_to_served_sessions (dk_session_t * ses);
void remove_from_served_sessions (dk_session_t * ses);
service_t *find_service (char *name);
int is_protocol (session_t * ses, int proto);
int check_inputs (TAKE_G timeout_t * timeout, int is_recursive);
int read_service_request (dk_session_t * ses);
EXE_EXPORT (dk_session_t *, dk_session_allocate, (int sesclass));
dk_session_t * dk_session_alloc_box (int sesclass, int in_len);

void timeout_round (TAKE_G dk_session_t * ses);
void PrpcSuckAvidly (int mode);
void PrpcAddAnswer (caddr_t result, int ret_type, int is_partial, int flush);
void PrpcAnswerHead (du_thread_t * thr, int is_partial);
void PrpcAnswerTail (dk_session_t * ses, int flush);
srv_req_hook_func PrpcSetServiceRequestHook (srv_req_hook_func new_function);
io_action_func PrpcSetPartnerDeadHook (dk_session_t * ses, io_action_func new_function);
sch_hook_func PrpcSetSchedulerHook (sch_hook_func new_function);
EXE_EXPORT (void, PrpcSessionFree, (dk_session_t * ses));
dk_thread_t *PrpcThreadAllocate (thread_init_func init, unsigned long stack_size, void *init_arg);
dk_thread_t *PrpcThreadAttach (void);
void PrpcThreadDetach (void);
void PrpcSetThreadParams (long srv_sz, long main_sz, long future_sz, int nmaxfutures);
dk_session_t *PrpcFindPeer (char *name);
dk_set_t PrpcListPeers (void);
void PrpcRegisterService (char *name, server_func func, void *client_data, int ret_type, post_func postprocess);
void PrpcRegisterServiceDesc (service_desc_t * desc, server_func f);
void PrpcProtocolInitialize (int sesclass);
dk_session_t *PrpcListen (char *addr, int sesclass);
int PrpcIsListen (dk_session_t * ses);
char *PrpcIAm (char *name);
void timeout_round_loop (void);
void PrpcInitialize (void);
void PrpcInitialize1 (int mem_mode);
void PrpcStatus (char *out, int max);
future_t *PrpcFuture (dk_session_t * server, service_desc_t * service, ...);
void PrpcFutureFree (future_t * future);
future_t *PrpcFutureSetTimeout (future_t * future, long msecs);
void PrpcSessionResetTimeout (dk_session_t * ses);
caddr_t PrpcValueOrWait1T (future_t * future);
caddr_t PrpcValueOrWait (future_t * future);
caddr_t PrpcFutureNextResult (future_t * future);
int PrpcFutureIsResult (future_t * future);
caddr_t PrpcSync (future_t * f);
dk_session_t *PrpcConnect (char *address, int sesclass);
dk_session_t *PrpcConnect1 (char *address, int sesclass, char *use_ssl, char *passwd, char *ca_list);
dk_session_t *PrpcInprocessConnect (char *address);
void PrpcDisconnect (dk_session_t * session);
void PrpcDisconnectAll (void);
long PrpcSetTimeoutResolution (long milliseconds);
void PrpcSetBackgroundAction (background_action_func f);
void PrpcLeave (void);
void sun_rpc_loop (void);
void sun_rpc_ready (void);
void PrpcSunRPCInitialize (long sz);
void dk_set_resource_usage (void);
void PrpcSelfSignalInit (char *addr);
void PrpcSelfSignal (self_signal_func f, caddr_t cf);
void PrpcCheckIn (dk_session_t * ses);
void PrpcCheckInAsync (dk_session_t * ses);
void PrpcCheckOut (dk_session_t * ses);
void remove_from_served_sessions (dk_session_t * ses);
long dks_housekeeping_session_count (void);
void dks_housekeeping_session_count_change (int delta);
void PrpcFixedServerThread (void);
void PrpcSetSessionDisconnectCallback (disconnect_callback_func f);

typedef int (*frq_queue_hook_t) (future_request_t *);
void PrpcSetQueueHook (frq_queue_hook_t h);

void PrpcSetFuturePreprocessHook (void (*prepro) (void));

extern void (*process_exit_hook) (int);


/* This macro calls the exit hook if defined */
#define call_exit(s) if (!process_exit_hook) \
                       exit(s); \
		     else \
		       (*process_exit_hook) (s);
void call_exit_outline (int status);

void call_disconnect_callback_func (dk_session_t * ses);

void PrpcSetCallerIDServerHook (caddr_t (*f) (void));

void PrpcSetInprocessHooks (void *(*enter) (dk_session_t * ses), void (*leave) (void *));

#ifdef _SSL
#  ifndef NO_THREAD
typedef struct ssl_ctx_info_s
{
  int32 *		ssci_depth_ptr;
  char *		ssci_name_ptr;
} ssl_ctx_info_t;
int ssl_cert_verify_callback (int ok, void *ctx);
#  endif
#endif

#ifndef NO_THREAD
void ssl_server_listen (void);
#endif

long cdef_param (caddr_t * cdefs, char *name, long deflt);
void cdef_add_param (caddr_t ** cdefs_ptr, const char *name, long val);
void dk_thread_free (void *data);
void sr_report_future_error (dk_session_t * ses, const char *service_name, const char *reason);
int dk_report_error (const char *format, ...);


#ifdef NO_THREAD
#define NO_DK_ALLOC_RESERVE
#endif

#define DK_ALLOC_RESERVE_DISABLED	0
#define DK_ALLOC_RESERVE_PREPARED	1
#define DK_ALLOC_RESERVE_IN_USE		2

#ifndef NO_DK_ALLOC_RESERVE
extern dk_mutex_t *dk_alloc_reserve_mutex;
extern volatile void *dk_alloc_reserve;	/* Don't access it directly. */
extern int dk_alloc_reserve_maxthreads;
extern volatile int dk_alloc_reserve_mode;
#define DK_ALLOC_ON_RESERVE 		((dk_alloc_reserve_mode != DK_ALLOC_RESERVE_DISABLED && NULL == dk_alloc_reserve) || MP_LARGE_SOFT_CK)
void dk_alloc_set_reserve_mode (int mode);
#else
#define DK_ALLOC_ON_RESERVE 		0
#define dk_alloc_set_reserve_mode(M) 	do { ; } while (0)
#endif

void *dk_alloc_reserve_malloc (size_t size, int gpf_if_not);

#ifndef NO_THREAD
#define BURST_STOP_TIMEOUT 		1000		   /* 1 sec to switch off burst mode */
extern uint32 time_now_msec;
void dks_stop_burst_mode (dk_session_t * ses);
#endif

extern long client_trace_flag;

#ifdef PCTCP
int init_pctcp ();
#endif

#ifdef UNIX
extern long init_brk;
#endif

void strses_mem_initalize (void);
void strses_readtable_initialize (void);
void dk_box_initialize (void);
void log_thread_initialize (void);
int bytes_in_read_buffer (dk_session_t * ses);
long read_wides_from_utf8_file (dk_session_t * ses, long nchars, unsigned char *dest, int copy_as_utf8, unsigned char **dest_ptr_out);

#endif /* _DKERNEL_H */

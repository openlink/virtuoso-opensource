/*
 *  Dkernel.c
 *
 *  $Id$
 *
 *  RPC Kernel
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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

/* Sorry, this still is a mess - merge not complete yet - PmN */

#undef DBG_PRINTF

#include "Dk.h"
#include "Dk/Dksystem.h"
#include "util/logmsg.h"

#define BASKET_PEEK(b) basket_peek(b)

#ifdef OS2
#include <process.h>
#endif
/*
#ifdef PCTCP
#ifdef WIN32
#include <winsock2.h>
#else
#include <winsock.h>
#endif
#endif
*/
#ifdef SRV_DEBUG
#define PRINT_DEBUG
#define LEVEL_VAR srv_debug_level
int LEVEL_VAR = 4;
#endif


#ifdef _SSL
#include <openssl/rsa.h>
#include <openssl/crypto.h>
#include <openssl/x509.h>
#include <openssl/pem.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/bio.h>
#include <openssl/asn1.h>
#include <openssl/pkcs12.h>
#include <openssl/rand.h>

static void ssl_server_init ();

#ifndef NO_THREAD
static int ssl_server_accept (dk_session_t * listen, dk_session_t * ses);
static unsigned int ssl_server_port = 0;
#endif
static SSL_CTX *ssl_server_ctx = NULL;
int32 ssl_server_verify = 0;
int32 ssl_server_verify_depth = 0;
char *ssl_server_verify_file = NULL;
#endif

#ifndef NO_THREAD
long burst_reqs = 0;
long second_rpcs = 0;
#endif

void (*process_exit_hook) (int);
future_request_t *frq_create (dk_session_t * ses, caddr_t * request);


void
call_exit_outline (int status)
{
  call_exit (status);
}


#ifdef PMN_THREADS
int time_slice = 100;
#define process_is_quiescent(X) \
	(_thread_sched_preempt || _thread_num_runnable < 1)
#else
extern int time_slice;
#endif


#ifndef GSTATE

int last_session;
dk_session_t *served_sessions[MAX_SESSIONS];
service_t *services;

resource_t *free_threads;
int future_thread_count = 0;
int max_future_threads = 10;

int select_set_changed;

long future_thread_sz = FUTURE_THREAD_SIZE;
long server_thread_sz = FUTURE_THREAD_SIZE;
long main_thread_sz = 0;	/* use values from thread_int.h */

dk_hash_t *protocols = (dk_hash_t *) NULL;
sch_hook_func scheduler_hook = NULL;

timeout_t atomic_timeout = { ATOMIC_TIMEOUT, 0 };
timeout_t dks_fibers_blocking_read_default_to = { 0, 1 };

basket_t in_basket;
long client_trace_flag;

srv_req_hook_func service_request_hook = NULL;

int prpcinitialized = 0;

dk_mutex_t *value_mtx;
#ifndef NO_THREAD
#define IN_VALUE	mutex_enter (value_mtx)
#define LEAVE_VALUE	mutex_leave (value_mtx)
#else
#define IN_VALUE			 /* no value_mtx for single thread */
#define LEAVE_VALUE
#endif

long connection_count;
char *i_am = NULL;
background_action_func background_action;

ptrlong last_future = 0;
#ifdef NO_THREAD
#define PENDING_FUTURES(ses) (ses)->dks_pending_futures
#else
dk_hash_t *pending_futures;
#define PENDING_FUTURES(ses) pending_futures
#endif

#ifndef NO_THREAD
char *c_ssl_server_port;
char *c_ssl_server_cert;
char *c_ssl_server_key;
char *c_ssl_server_extra_certs;
#endif
#endif /* GSTATE */

typedef int (*select_func_t) (int ses_count, session_t ** reads, session_t ** writes, timeout_t * timeout);

static caddr_t PrpcFutureNextResult1T (future_t * future);


#ifdef PMN_THREADS
static dk_thread_t *dk_thread_alloc (void);
#ifndef NO_THREAD
static int future_wrapper (void *dkt);
#endif
#endif


#ifndef NO_THREAD
/* The count of threads started past queue during a check_inputs cycle
   This is a global flag used to launch a scheduling round.  */
static int check_inputs_action_count = 0;
#endif

/* true when some thread is running a scheduling cycle */
static int scheduling_in_progress = 0;	/* XXX remove this */


static int suck_avidly = 0;

/* Protects the free threads table */
dk_mutex_t *thread_mtx;


#ifdef SUNRPC
static int fd_set_or (fd_set * s1, fd_set * s2);
static int fd_sets_intersect (fd_set * s1, fd_set * s2);
#endif

SERVICE_0 (s_sql_cancel, "CANCEL", DA_FUTURE_REQUEST, DV_SEND_NO_ANSWER);

long
cdef_param (caddr_t * cdefs, char *name, long deflt)
{
  int len = cdefs ? BOX_ELEMENTS (cdefs) : 0;
  int inx;
  for (inx = 0; inx < len; inx += 2)
    if (0 == strcmp (name, cdefs[inx]))
      return (long) (unbox (cdefs[inx + 1]));
  return deflt;
}


void
cdef_add_param (caddr_t ** cdefs_ptr, const char *name, long val)
{
  caddr_t *cdefs = *cdefs_ptr;
  if (cdefs)
    {
      int n_opts = BOX_ELEMENTS (cdefs);
      caddr_t *new_opts = (caddr_t *) dk_alloc_box ((n_opts + 2) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      memcpy (new_opts, cdefs, n_opts * sizeof (caddr_t));
      /* meaning the version of the server as stored in the client */
      new_opts[n_opts] = box_dv_short_string (name);
      new_opts[n_opts + 1] = box_num (val);
      dk_free_box ((box_t) cdefs);
      *cdefs_ptr = new_opts;
    }
  else
    {
      cdefs = (caddr_t *) dk_alloc_box (2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      /* meaning the version of the server as stored in the client */
      cdefs[0] = box_dv_short_string (name);
      cdefs[1] = box_num (val);
      *cdefs_ptr = cdefs;
    }
}


static void
call_service_cancel (dk_session_t * ses)
{
  /* meaning the version of the server as stored in the client */
  long ver = cdef_param (ses->dks_caller_id_opts, "__SQL_CLIENT_VERSION", 0);
  if ((ver >= 2175 && ver < 2200) || ver >= 2238)
    PrpcFutureFree (PrpcFuture (ses, &s_sql_cancel));
}


/*
 * The Notion of Served Sessions
 *
 * Any session the scheduler checks is called a served session.
 * The session_sch_data specifies in more detail how this session is to be
 * served.
 */
int
add_to_served_sessions (dk_session_t * ses)
{
  USE_GLOBAL
  int n;

  select_set_changed = 1;
  if (SESSION_SCH_DATA (ses)->sio_is_served != -1)
    return (0);
#ifndef WIN32
  if (tcpses_get_fd (ses->dks_session) >= FD_SETSIZE)
    return -1;
#endif
  for (n = 0; n < MAX_SESSIONS; n++)
    {
      if (served_sessions[n] == NULL)
	{
	  served_sessions[n] = ses;
	  SESSION_SCH_DATA (ses)->sio_is_served = n;
	  if (n >= last_session)
	    last_session = n + 1;
	  return (0);
	}
    }
  return (-1);
}


void
remove_from_served_sessions (dk_session_t * ses)
{
  USE_GLOBAL
  int n = SESSION_SCH_DATA (ses)->sio_is_served;
  select_set_changed = 1;
  ss_dprintf_2 (("\n Removing session %p.\n", ses));
  if (n != -1)
    {
      SESSION_SCH_DATA (ses)->sio_is_served = -1;
      served_sessions[n] = NULL;
      if (n == last_session)
	{
	  while (last_session > 0)
	    {
	      if (served_sessions[--last_session] != NULL)
		{
		  last_session++;
		  break;
		}
	    }
	}
    }
}


#ifndef NO_THREAD
/* The Internal Services Table

   The data structure is a linearly searched list. Should be a
   hash table on the name of the service
*/


service_t *
find_service (char *name)
{
  USE_GLOBAL
  service_t * srv = services;
  while (srv)
    {
      if (0 == strcmp (srv->sr_name, name))
	return (srv);
      srv = srv->sr_next;
    }
  return (NULL);
}


/*##**********************************************************************
 *
 *              get_free_thread.
 *
 *  Finding a thread to run a future on
 * - Take a thread that's allocated and not active.
 * - If none, check if the maximum number of threads
 *   have been allocated. If not, allocate a new thread.
 * - If no threads are free and no new ones can be made, return NULL..
 *
 * Input params :  *
 *
 * Output params:    -
 *
 * Return value :    - A reset, stopped dk_thread_t or NULL if there are
 *                     no free threads and the maximum thread count has been
 *                     allocated.
 * Limitations  :
 *
 * Globals used :    future_thread_count, max_future_threads
 */
static dk_thread_t *
get_free_thread (TAKE_G dk_session_t * for_ses)
{
  dk_thread_t *dkt;
  du_thread_t *thr;

  ASSERT_IN_MTX (thread_mtx);
  if ((dkt = (dk_thread_t *) resource_get (free_threads)))
    {
      if (for_ses)
	for_ses->dks_n_threads++;
    }
  else
    {
      if (future_thread_count < max_future_threads)
	{
	  dkt = dk_thread_alloc ();
	  future_thread_count++;

	  if (for_ses)
	    for_ses->dks_n_threads++;
	}
    }

  if (dkt)
    {
      if ((thr = thread_create (future_wrapper, future_thread_sz, NULL)) != NULL)
	{
	  thr->thr_client_data = dkt;
	  dkt->dkt_process = thr;
	  dbg_printf_2 (("+ Created thread %p", thr));
	}
      else
	{
	  if (for_ses)
	    for_ses->dks_n_threads--;
	  if (NULL != dkt->dkt_requests[0])
	    dk_free (dkt->dkt_requests[0], sizeof (future_request_t));
	  dk_free (dkt, sizeof (dk_thread_t));
	  max_future_threads = --future_thread_count;
	  dkt = NULL;
	}
    }

  return dkt;
}
#endif


/*##**********************************************************************
 *
 *               check_inputs
 *
 * Do a select on all serviced sessions. If the session is ready,
 * invoke its random_write_ready_action, random_read_ready_action
 * or default_read_ready_action, whichever are applicable.  This function
 * is called only on the scheduler thread that monitors all i/o. This is
 * usually called non-recursively. A recursive call may occur if a read
 * called from within this function blocks. Such a call will not initiate
 * further reads or accept clients (call the default_read_ready_action).
 * It will however call the random read/write ready actions. These are
 * assumed to return rapidly and not to block this thread. They will typically
 * resume other threads blocked on i/o.
 *
 * If a timeout is specified and there is data in some input
 * session's read buffer, the select is performed but with a zero timeout.
 *
 * Input params :        - timeout, is_recursive
 *                       - The function that performs a session_select on
			   the sessions of a certain protocol.
 *                       - protocol - only consider session of this SESCLASS
 *
 *
 * Output params:    -
 *
 * Return value :    number of served sessions ready for i/o. 0 if timed out.
 *
 * Limitations  :
 *
 * Globals used :    served_sessions, scheduling_in_progress.
 */
int
is_protocol (session_t * ses, int proto)
{
  return (ses->ses_class == proto
#if defined (COM_UDPIP) || defined (COM_UNIXSOCK)
      || ((proto == SESCLASS_TCPIP ||
	   proto == SESCLASS_UDPIP ||
	   proto == SESCLASS_UNIX) &&
	  (ses->ses_class == SESCLASS_TCPIP ||
	   ses->ses_class == SESCLASS_UDPIP ||
	   ses->ses_class == SESCLASS_UNIX))
#endif
      );
}


int
bytes_in_read_buffer (dk_session_t * ses)
{
  return (ses->dks_in_fill - ses->dks_in_read);
}


#ifndef NO_COMBINED_SELECT

struct connectionstruct
{
  int con_s;			/* socket descriptor */
};

#define DKS_SOCK(ses) \
	ses->dks_session->ses_device->dev_connection->con_s

static void
call_default_read (dk_session_t * ses, int is_recursive, int *did_call)
{
  if (!is_recursive && SESSION_SCH_DATA (ses)->sio_default_read_ready_action)
    {
      if (!bytes_in_read_buffer (ses))
	ses->dks_is_read_select_ready = 1;

      SESSION_SCH_DATA (ses)->sio_default_read_ready_action (ses);

      if (did_call)
	*did_call = 1;
    }
}


int prpc_disable_burst_mode = 0;
int prpc_force_burst_mode = 0;
int prpc_self_signal_initialized = 0;

static void
check_inputs_for_errors (int eno, int protocol)
{
#ifndef WIN32
  int s, n;
again:
  for (n = 0; eno == EBADF && n < last_session; n++)
    {
      dk_session_t *ses = served_sessions[n];
      if (ses && is_protocol (ses->dks_session, protocol))
	{
	  if (SESSION_SCH_DATA (ses)->sio_random_read_ready_action ||
	      SESSION_SCH_DATA (ses)->sio_default_read_ready_action ||
	      SESSION_SCH_DATA (ses)->sio_random_write_ready_action)
	    {
	      s = DKS_SOCK (ses);
	      if (-1 == fcntl (s, F_GETFL))
		{
		  log_error ("Bad file descriptor (%d) in served sessions, removing", s);
		  remove_from_served_sessions (ses);
		  goto again;
		}
	    }
	}
    }
#endif
}

static int
check_inputs_low (TAKE_G timeout_t * timeout_org, int is_recursive, select_func_t select_fun, int protocol)
{
  struct timeval to_2;
  int buffered_left;
  int s, n, rc;
  int s_max;
  int unread_data;
  fd_set reads;
  fd_set writes;

  memset (&to_2, 0, sizeof (to_2));
  to_2.tv_sec = timeout_org->to_sec;
  to_2.tv_usec = timeout_org->to_usec;
  FD_ZERO (&reads);
  FD_ZERO (&writes);

  if (!is_recursive)
    scheduling_in_progress = 1;

  if (is_recursive)
    {
      ss_dprintf_3 (("Recursive check_inputs"));
    }

  unread_data = 0;
  s_max = 0;

  for (n = 0; n < last_session; n++)
    {
      dk_session_t *ses = served_sessions[n];
      if (ses && is_protocol (ses->dks_session, protocol))
	{
	  if (SESSION_SCH_DATA (ses)->sio_random_read_ready_action ||
	      SESSION_SCH_DATA (ses)->sio_default_read_ready_action)
	    {
	      if (bytes_in_read_buffer (ses))
		{
		  to_2.tv_sec = 0;
		  to_2.tv_usec = 0;
		  unread_data = 1;
		}
	      s = DKS_SOCK (ses);
	      FD_SET (s, &reads);
	      s_max = MAX (s, s_max);
	    }
	  if (SESSION_SCH_DATA (ses)->sio_random_write_ready_action)
	    {
	      s = DKS_SOCK (ses);
	      FD_SET (s, &writes);
	      s_max = MAX (s, s_max);
	    }
	}
    }

#ifdef SUNRPC
  s = fd_set_or (&reads, &svc_fdset);
  s_max = MAX (s, s_max);
#endif

#ifdef SOLARIS
  thr_yield ();
#endif

  without_scheduling_tic ();
  rc = select (s_max + 1, &reads, &writes, NULL, &to_2);
  restore_scheduling_tic ();

  if (rc < 0)
    {
      int eno = errno;
      check_inputs_for_errors (eno, protocol);
      PROCESS_ALLOW_SCHEDULE ();
      return 0;
    }

  if (rc != 0 || unread_data)
    {
#ifdef SUNRPC
      if (fd_sets_intersect (&reads, &svc_fdset))
	sun_rpc_ready ();
#endif

      for (n = 0; n < last_session; n++)
	{
	  dk_session_t *ses = served_sessions[n];
	  if (ses && FD_ISSET (DKS_SOCK (ses), &writes))
	    {
	      SESSTAT_CLR (ses->dks_session, SST_BLOCK_ON_WRITE);
	      SESSION_SCH_DATA (ses)->sio_random_write_ready_action (ses);
	    }
	}

      /*
       *  Check read ready conditions even on a zero rc because there may be
       *  unread bytes in some read buffer. if there are bytes in a read buffer,
       *  increment the rc to indicate that the select was not timed out.
       *  Some sessions may get counted twice in this manner but this does no
       *  harm.
       */
      for (n = 0; n < last_session; n++)
	{
	  dk_session_t *ses = served_sessions[n];
	  if (!ses)
	    continue;
	  if (FD_ISSET (DKS_SOCK (ses), &reads) || bytes_in_read_buffer (ses))
	    {
#ifndef NO_THREAD
	      if (!prpc_disable_burst_mode)
		{
		  mutex_enter (thread_mtx);
		  if (!ses->dks_fixed_thread &&
		      ses->dks_thread_state == DKST_FINISH &&
		      ses->dks_n_threads == 1)
		    {
		      if (SESSION_SCH_DATA (ses)->sio_default_read_ready_action == read_service_request)
			{
			  thrs_printf ((thrs_fo, "ses %p thr:%p from finish to burst\n", ses, THREAD_CURRENT_THREAD));
			  ses->dks_thread_state = DKST_BURST;
			  burst_reqs++;
			  remove_from_served_sessions (ses);
			  mutex_leave (thread_mtx);
			  continue;
			}
		      else
			{
			  thrs_printf ((thrs_fo, "ses %p thr:%p tried burst, but it's not RPC thread\n", ses, THREAD_CURRENT_THREAD));
			  mutex_leave (thread_mtx);
			}
		    }
		  else
		    mutex_leave (thread_mtx);
		}
#endif
	      SESSTAT_CLR (ses->dks_session, SST_BLOCK_ON_READ);
	      if (DKSESSTAT_ISSET (ses, SST_LISTENING))
		SESSTAT_SET (ses->dks_session, SST_CONNECT_PENDING);

	      if (SESSION_SCH_DATA (ses)->sio_random_read_ready_action)
		{
		  SESSION_SCH_DATA (ses)->sio_random_read_ready_action (ses);
		}
	      else
		call_default_read (ses, is_recursive, NULL);
	    }
	}

      buffered_left = 1;
      while (buffered_left)
	{
	  buffered_left = 0;
	  for (n = 0; n < last_session; n++)
	    {
	      dk_session_t *ses = served_sessions[n];

	      if (ses && bytes_in_read_buffer (ses))
		{
		  SESSTAT_CLR (ses->dks_session, SST_BLOCK_ON_READ);

		  if (SESSION_SCH_DATA (ses)->sio_random_read_ready_action)
		    {
		      SESSION_SCH_DATA (ses)->sio_random_read_ready_action (ses);
		      buffered_left = 1;
		    }
		  else
		    {
		      if (client_trace_flag)
			logit (L_DEBUG, "calling default read based on data left in buffer, ses: %lx", ses);

		      call_default_read (ses, is_recursive, &buffered_left);
		    }
		}
	    }
	  if (!suck_avidly)
	    break;
	}
    }

  if (!is_recursive)
    scheduling_in_progress = 0;

  return (rc);
}


#else /* NO_COMBINED_SELECT */


static int
check_inputs_low (TAKE_G timeout_t * timeout, int is_recursive, select_func_t select_fun, int protocol)
{
  session_t *reads[MAX_SESSIONS];
  session_t *writes[MAX_SESSIONS];
  int n, last_write = 0, last_read = 0;
  int rc;

  if (!is_recursive)
    scheduling_in_progress = 1;

  if (is_recursive)
    {
      ss_dprintf_3 (("Recursive check_inputs"));
    }

  memset (reads, 0, sizeof (reads));
  memset (writes, 0, sizeof (reads));

  for (n = 0; n < MAX_SESSIONS; n++)
    {
      dk_session_t *ses = served_sessions[n];
      if (ses && is_protocol (served_sessions[n]->dks_session, protocol))
	{
	  if (SESSION_SCH_DATA (ses)->sio_random_read_ready_action ||
	      SESSION_SCH_DATA (ses)->sio_default_read_ready_action)
	    {
	      if (bytes_in_read_buffer (ses))
		timeout = &zero_timeout;
	      reads[last_read] = ses->dks_session;
	      last_read++;
	    }
	  if (SESSION_SCH_DATA (ses)->sio_random_write_ready_action)
	    {
	      writes[last_write] = ses;
	      last_write++;
	    }
	}
    }

again:
  /* Temporary. Wait until final version of select.
     This case corresponds to the operation interrupted condition. */

  without_scheduling_tic ();
  rc = select_fun ((last_read > last_write ? last_read : last_write), reads, writes, timeout);
  restore_scheduling_tic ();

  if (rc < 0)
    {
      PROCESS_ALLOW_SCHEDULE ();
      return 0;
    }

  /*
   *  See which writes are ready.
   *  Enable the threads waiting on write before reading the ready inputs
   *  because the inputs may take several time slices to process and the
   *  writes must advance as fast as possible to complete service requests.
   *  This happens only if there is a non-zero return code.
   */
  if (rc != 0)
    {
      for (n = 0; n < last_write; n++)
	{
	  session_t *ses = writes[n];
	  if (!SESSTAT_ISSET (ses, SST_BLOCK_ON_WRITE))
	    {
	      SESSION_SCH_DATA (SESSION_DK_SESSION (ses))->sio_random_write_ready_action (SESSION_DK_SESSION (ses));
	    }
	}
    }

  /*
   *  Check read ready conditions even on a zero rc because there may be unread
   *  bytes in some read buffer. if there are bytes in a read buffer, increment
   *  the rc to indicate that the select was not timed out. Some sessions may
   *  get counted twice in this manner but this does no harm.
   */
  for (n = 0; n < last_read; n++)
    {
      session_t *ses = writes[n];
      if (!SESSTAT_ISSET (ses, SST_BLOCK_ON_READ) ||
	  SESSTAT_ISSET (ses, SST_CONNECT_PENDING) ||
	  bytes_in_read_buffer (SESSION_DK_SESSION (ses)))
	{
	  io_action_func act = SESSION_SCH_DATA (SESSION_DK_SESSION (ses))->sio_random_read_ready_action ;
	  if (act)
	    (*act) (SESSION_DK_SESSION (ses));
	  else
	    {
	      if (!is_recursive)
		{
		  (SESSION_SCH_DATA (SESSION_DK_SESSION (ses))->sio_default_read_ready_action) (SESSION_DK_SESSION (reads[n]));
		}
	    }
	}
    }

  if (!is_recursive)
    scheduling_in_progress = 0;

  return (rc);
}
#endif


#ifndef COM_TCPIP
#error COM_TCPIP required
#endif


int
check_inputs (TAKE_G timeout_t * timeout, int is_recursive)
{
  return (check_inputs_low (PASS_G timeout, is_recursive, (select_func_t) tcpses_select, SESCLASS_TCPIP)
#ifdef COM_UDPIP
      || check_inputs_low (PASS_G timeout, is_recursive, udpses_select, SESCLASS_UDP)
#endif
#ifdef COM_NMPIPE
      || check_inputs_low (PASS_G timeout, is_recursive, nmpses_select, SESCLASS_NMP)
#endif
      );
}


long msec_session_dead_time;
dk_session_t *session_dead;

/*
 *  Called when the client is disconnected
 */
static void
session_is_dead (dk_session_t * ses)
{
  int is_server = ses->dks_is_server;
  io_action_func dead = SESSION_SCH_DATA (ses)->sio_partner_dead_action;
  if (dead)
    {
      mutex_leave (thread_mtx);
      dead (ses);
      mutex_enter (thread_mtx);
    }
  if (is_server)
    {
      PrpcDisconnect (ses);

      if (client_trace_flag)

#ifndef NDEBUG
	logit (L_DEBUG, "Freeing session %lx, peer: %s, n_threads: %d\n", ses, ses->dks_peer_name ? ses->dks_peer_name : "(NIL)", ses->dks_n_threads);
#else
	logit (L_DEBUG, "Freeing session %lx, n_threads: %d\n", ses, ses->dks_n_threads);
#endif /* NDEBUG */

      msec_session_dead_time = get_msec_real_time ();
      session_dead = ses;
      PrpcSessionFree (ses);
    }
}


#ifdef NO_THREAD
int
dk_report_error (const char *format, ...)
{
  return 0;
}


void
sr_report_future_error (dk_session_t * ses, const char *service_name, const char *reason)
{
  /* does nothing client-side */
}
#endif

#ifndef NO_THREAD

volatile long future_n_calls;
volatile long future_n_returns;
long future_max_conc;

#define F_CALLED future_n_calls++;
#define F_RETURNED \
  { \
    long c =  future_n_calls - future_n_returns; \
    future_n_returns ++; \
    if (c > future_max_conc) \
     future_max_conc = c; \
  }


long reqs_on_the_fly = 0;
long queued_reqs = 0;

void
PrpcStatus (char *out, int max)
{
  char tmp[300];
  snprintf (tmp, sizeof (tmp),
	"RPC: %ld calls, %ld pending, %ld max until now, %ld queued, %ld burst reads (%d%%), %ld second",
	future_n_calls, future_n_calls - future_n_returns, future_max_conc,
	queued_reqs, burst_reqs, (int) (burst_reqs * 100 / future_n_calls),
	second_rpcs);
  strncpy (out, tmp, max);
  if (max > 0)
    out[max - 1] = 0;
}


static void (*f_future_preprocess) (void) = NULL;

void
PrpcSetFuturePreprocessHook (void (*prepro) (void))
{
  if (thread_mtx)
    mutex_enter (thread_mtx);
  f_future_preprocess = prepro;
  if (thread_mtx)
    mutex_leave (thread_mtx);
}


int
dk_report_error (const char *format, ...)
{
  va_list ap;
  int rc;

  va_start (ap, format);
  rc = logmsg_ap (LOG_ERR, NULL, 0, 1, (char *) format, ap);
  va_end (ap);

  return rc;
}

int dbf_assert_on_malformed_data;


void
sr_report_future_error (dk_session_t * ses, const char *service_name, const char *reason)
{
  if (ses && ses->dks_session &&
      (ses->dks_session->ses_class == SESCLASS_TCPIP ||
       ses->dks_session->ses_class == SESCLASS_UDPIP))
    {
      char ip_buffer[16];
      tcpses_print_client_ip (ses->dks_session, ip_buffer, sizeof (ip_buffer));
      if (service_name && strlen (service_name) > 0)
	log_error ("Malformed RPC %.10s received from IP [%.256s] : %.255s. Disconnecting the client", service_name, ip_buffer, reason);
      else
	log_error ("Malformed data received from IP [%.256s] : %.255s. Disconnecting the client", ip_buffer, reason);
    }
/* do not report - it's usually an internal session - like txn log, deserialize etc
  else
    {
      if (service_name && strlen (service_name) > 0)
	log_error ("Malformed RPC %.10s received : %.255s. Disconnecting the client",
	    service_name, reason);
      else
	log_error ("Malformed data received : %.255s. Disconnecting the client",
	    reason);
    }
*/
  if (dbf_assert_on_malformed_data)
    GPF_T1 ("Malformed data serialization");
}

#define is_string_type(type)\
  ((DV_SHORT_STRING == (type)) || (DV_LONG_STRING == (type)) || (DV_C_STRING == (type)))

static int
sr_check_and_set_args (future_request_t * future, caddr_t * arguments, int argcount, caddr_t * arg_array)
{
  service_desc_t *desc = (service_desc_t *) future->rq_service->sr_client_data;
  int inx;
  char *reason = "";
  char buffer[256];

  if (argcount != desc->sd_arg_count)
    {
      reason = "invalid argument count";
      goto error;
    }

  for (inx = 0; inx < argcount; inx++)
    {
      dtp_t arg_dtp = DV_TYPE_OF (arguments[inx]);
      if (!desc || !desc->sd_arg_types[inx])
	arg_array[inx] = (caddr_t) unbox_ptrlong (arguments[inx]);
      else if (arg_dtp == desc->sd_arg_types[inx] ||
	       (is_string_type (arg_dtp) && is_string_type (desc->sd_arg_types[inx])) ||
	       (is_array_of_long (arg_dtp) && is_array_of_long (desc->sd_arg_types[inx])) ||
	       (!arguments[inx] && (!desc->sd_arg_nullable || desc->sd_arg_nullable[inx])))
	arg_array[inx] = (caddr_t) unbox_ptrlong (arguments[inx]);
      else
	{
	  snprintf (buffer, sizeof (buffer), "invalid argument type (%d instead of %d) for arg %d",
	  	(int) DV_TYPE_OF (arguments[inx]), (int) desc->sd_arg_types[inx], inx + 1);
	  reason = buffer;
	  goto error;
	}
    }
  if (argcount < MAX_FUTURE_ARGUMENTS)
    memset (&(arg_array[argcount]), 0, (MAX_FUTURE_ARGUMENTS - argcount) * sizeof (caddr_t));

  return 0;
error:
  sr_report_future_error (future->rq_client, future->rq_service->sr_name, reason);
  PrpcDisconnect (future->rq_client);
  return 1;
}


/* callback called when the session is detected to be disconnected */

static disconnect_callback_func session_disconnect_callback = NULL;

void
PrpcSetSessionDisconnectCallback (disconnect_callback_func f)
{
  USE_GLOBAL
  session_disconnect_callback = f;
}


void
call_disconnect_callback_func (dk_session_t * ses)
{
  if (session_disconnect_callback)
    session_disconnect_callback (ses);
}


/*##**********************************************************************
 *
 *        future_wrapper ()
 *
 * This function is the outermost function to run on a future-
 * servicing thread. It has some housekeeping things to do.
 * it notably sets the start_contect jump context so that a future
 * can be aborted.
 & The data on the future computation in progress is retrieved from the
 * current thread. (e.g. client, request number etc).
 *
 *
 * Input params :
 *
 * Output params:
 *
 * Return value : void
 *
 * Limitations  :
 *
 * Globals used : current_thread
 */
long prpc_burst_timeout_msecs = 10;

uint32 n_in_basket_putbacks = 0;

static int
future_wrapper (void *ignore)
{
  USE_GLOBAL
  dk_thread_t * volatile c_thread;
  future_request_t *future, *fixed_thread_future;
  volatile caddr_t result = NULL;
  dk_session_t *client;
  int error;
  caddr_t *arguments;
  caddr_t arg_array[MAX_FUTURE_ARGUMENTS];
  int argcount, finx, was_second = 0;

  du_thread_t *this_thread = THREAD_CURRENT_THREAD;

  {

    dbg_printf_2 (("future wrapper point 1 thread %p", this_thread));
    semaphore_enter (this_thread->thr_schedule_sem);	/* XXX: schedule_sem */
    dbg_printf_1 (("future wrapper activated thread %p", this_thread));
    c_thread = PROCESS_TO_DK_THREAD (this_thread);
  }

  for (;;)
    {
      int client_freed = 0;
      future = c_thread->dkt_requests[0];
      client = future->rq_client;
      if (future->rq_to_close)
	{
	  dbg_printf_3 (("\nserving a close event for ses %p in thread %p\n", client, this_thread));
	  goto free_the_future;
	}
      arguments = (caddr_t *) future->rq_arguments;
      argcount = arguments ? (int) (box_length ((caddr_t) arguments) / sizeof (caddr_t)) : (int) 0;

      error = 0;

      if (future->rq_service->sr_client_data)
	error = sr_check_and_set_args (future, arguments, argcount, arg_array);
      else
	{
	  for (finx = 0; finx < MAX_FUTURE_ARGUMENTS; finx++)
	    if (finx < argcount)
	      arg_array[finx] = (caddr_t) unbox_ptrlong (arguments[finx]);
	    else
	      arg_array[finx] = NULL;
	}

      dk_free_box_and_int_boxes ((caddr_t) arguments);

      /* Free this now. If freed after RPC func the references items may have been
         freed and reallocated and could be erroneously re-freed. */


      if (f_future_preprocess)
	f_future_preprocess ();
      if (0 == error)
	{
	  ss_dprintf_3 (("Starting future %ld, %s", future->rq_condition, future->rq_service->sr_name));

	  F_CALLED;				 /* not serialized, does not have to be exact. */
	  CB_PREPARE;
	  result = (caddr_t) future->rq_service->sr_func (
	  	arg_array[0], arg_array[1], arg_array[2], arg_array[3],
		arg_array[4], arg_array[5], arg_array[6], arg_array[7],
		arg_array[8]);
	  CB_DONE;
	}

      /* If this was a direct io future, request reading was disabled
         upon receipt of now processed request. Re-enable services reading */

      if (future->rq_is_direct_io)
	{
	  SESSION_CHECK_IN (future->rq_client);
	}

      /* Send the answer if needed. */
      {
	int ret_type = future->rq_service->sr_return_type;
	if (DV_SEND_NO_ANSWER != ret_type)
	  {
	    /* Box the result */
	    caddr_t *ret_box;
	    caddr_t *ret_block = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * DA_ANSWER_LENGTH, DV_ARRAY_OF_POINTER);
	    if (ret_type == DV_MULTIPLE_VALUES)
	      ret_box = (caddr_t *) result;
	    else
	      {
		ret_box = (caddr_t *) dk_alloc_box (sizeof (caddr_t), DV_ARRAY_OF_POINTER);
		if (ret_type == DV_LONG_INT || ret_type == DV_SHORT_INT)
		  ret_box[0] = box_num ((ptrlong) result);
		else if (ret_type == DV_C_STRING)
		  ret_box[0] = box_string (result);
		else
		  ret_box[0] = result;
	      }
	    ret_block[DA_MESSAGE_TYPE] = (caddr_t) (long) DA_FUTURE_ANSWER;
	    ret_block[RRC_COND_NUMBER] = box_num (future->rq_condition);
	    ret_block[RRC_VALUE] = (caddr_t) ret_box;
	    ret_block[RRC_ERROR] = box_num (error);
	    CB_PREPARE;
#ifdef PMN_NMARSH
	    srv_write_in_session (ret_block, future->rq_client, 1);
#else
	    write_in_session ((caddr_t) ret_block, future->rq_client, NULL, NULL, 1);
#endif
	    CB_DONE;
	    if (ret_type == DV_C_STRING)
	      dk_free_box ((caddr_t) ret_box[0]);	/* mty HUHTI */
	    dk_free_box_and_numbers ((caddr_t) ret_block);	/* mty HUHTI */
	    dk_free_box_and_numbers ((caddr_t) ret_box);	/* mty HUHTI */
	  }
      }

      /* epilogue */
      if (future->rq_service->sr_postprocess)
	{
	  CB_PREPARE;
	  future->rq_service->sr_postprocess (result, future);
	  CB_DONE;
	}
    free_the_future:
      if (this_thread->thr_reset_code)
	thr_set_error_code (this_thread, NULL);
      dbg_printf_2 (("Done Future %ld on thread %p", future->rq_condition, this_thread));
      mutex_enter (thread_mtx);
      F_RETURNED;
      client->dks_n_threads--;
      if (client->dks_n_threads < 0 || client->dks_n_threads > MAX_THREADS)
	{
	  dk_report_error ("dks_n_threads=%d mode=%d dks_to_close=%d in_basket_bsk_next=%p dks_fixed_thread=%p",
	  	client->dks_n_threads, client->dks_thread_state,
		client->dks_to_close, in_basket.bsk_next,
		client->dks_fixed_thread);
	  GPF_T1 ("dks_n_threads out of range");
	}


      fixed_thread_future = NULL;
      if (client->dks_fixed_thread && c_thread->dkt_fixed_thread && !client->dks_to_close)
	{
	  mutex_leave (thread_mtx);
	  dbg_printf_2 (("Check next ft future on thread %p", this_thread));
	  semaphore_enter (this_thread->thr_schedule_sem);	/* XXX: schedule_sem */
	  mutex_enter (thread_mtx);
	  fixed_thread_future = (future_request_t *) basket_get (&client->dks_fixed_thread_reqs);
	  if (!fixed_thread_future)
	    {
	      client->dks_to_close = 1;
	      call_disconnect_callback_func (client);
	      c_thread->dkt_fixed_thread = 0;
	    }
	  else
	    {
	      dbg_printf_2 (("Found ft future on thread %p", this_thread));
#ifndef NDEBUG
	      dk_free_box (future->rq_peer_name);
#endif /* NDEBUG */
	      dk_free (future, sizeof (future_request_t));
	      c_thread->dkt_requests[0] = fixed_thread_future;
	      c_thread->dkt_request_count = 1;
	      client->dks_n_threads++;
	      mutex_leave (thread_mtx);
	      continue;
	    }
	}
      if (client->dks_to_close && 0 == client->dks_n_threads)
	{
	  session_is_dead (client);
	  client_freed = 1;
	}

      c_thread->dkt_request_count--;
      c_thread->dkt_requests[0] = NULL;
#ifndef NDEBUG
      dk_free_box (future->rq_peer_name);
#endif /* NDEBUG */
      was_second = future->rq_is_second;
      dk_free (future, sizeof (future_request_t));
      future = (future_request_t *) basket_get (&in_basket);

      if (future)
	{					 /* got a future from the in_basket */
	  thrs_printf ((thrs_fo, "future from in_basket on ses %p thr:%p  ft=%p. Going to idle\n", client, THREAD_CURRENT_THREAD, future));
	  if (future->rq_client->dks_n_threads)
	    {					 /* there's another thread running on the same session */
	      basket_add (&in_basket, future);
	      future = NULL;
	      n_in_basket_putbacks++;
	    }
	  else
	    {
	      if (future->rq_client != client && future->rq_client->dks_thread_state != DKST_IDLE)
		{
		  thrs_printf ((thrs_fo, "ses %p thr:%p is in %d\n", client, THREAD_CURRENT_THREAD, (int) client->dks_thread_state));
		  GPF_T;
		}
	      else
		{
		  thrs_printf ((thrs_fo, "future from in_basket on ses %p thr:%p  ft=%p. Going to run\n", future->rq_client, THREAD_CURRENT_THREAD, future));
		  future->rq_client->dks_thread_state = DKST_RUN;
		}
	    }

	  if (future && !client_freed && !was_second && !client->dks_fixed_thread && future->rq_client != client)
	    {
	      if (client->dks_thread_state == DKST_BURST)
		{
		  client->dks_thread_state = DKST_IDLE;
		  PrpcCheckInAsync (client);
		}
	      else if (client->dks_thread_state == DKST_FINISH)
		client->dks_thread_state = DKST_IDLE;
	      else
		{
		  thrs_printf ((thrs_fo, "ses %p thr:%p is in %d\n", client, THREAD_CURRENT_THREAD, (int) client->dks_thread_state));
		  GPF_T;
		}
	    }

	}

      if (!future && !client_freed && !was_second && !client->dks_fixed_thread)
	{
	  if (client->dks_thread_state == DKST_BURST)
	    {
	      timeout_t zero_timeout = { 0, 10000 };
	      zero_timeout.to_usec = prpc_burst_timeout_msecs * 1000;
	      if (SESSION_SCH_DATA (client)->sio_default_read_ready_action != read_service_request)
		{
		  thrs_printf ((thrs_fo, "burst read on ses %p thr:%p changed rr action.releasing ft=%p\n", client, THREAD_CURRENT_THREAD, future));
		  client->dks_thread_state = DKST_IDLE;
		  PrpcCheckInAsync (client);
		  goto state_check_done;
		}

	      mutex_leave (thread_mtx);
	      if (!bytes_in_read_buffer (client))
		{
		  tcpses_is_read_ready (client->dks_session, prpc_force_burst_mode ? NULL : &zero_timeout);
		  client->dks_is_read_select_ready = 1;
		}
	      if (!SESSTAT_ISSET (client->dks_session, SST_TIMED_OUT))
		{
		  caddr_t *req;

		  req = (caddr_t *) read_object (client);
		  if (service_request_hook)
		    {
		      CB_PREPARE;
		      req = (caddr_t *) service_request_hook (client, (caddr_t) req);
		      CB_DONE;
		    }
		  if (!req)
		    {
		      if (!SESSTAT_ISSET (client->dks_session, SST_OK))
			{
			  future_request_t dummy_rq;

			  memset (&dummy_rq, 0, sizeof (future_request_t));
			  thrs_printf ((thrs_fo, "burst read on ses %p thr:%p not returned future.ses error\n", client, THREAD_CURRENT_THREAD));
			  mutex_enter (thread_mtx);
			  c_thread->dkt_request_count = 1;
			  c_thread->dkt_requests[0] = &dummy_rq;
			  dummy_rq.rq_thread = c_thread;
			  dummy_rq.rq_client = client;
			  session_is_dead (client);
			  future = NULL;
			  c_thread->dkt_request_count = 0;
			  client_freed = 1;
			}
		      else
			{
			  thrs_printf ((thrs_fo, "burst read on ses %p thr:%p not returned future.\n", client, THREAD_CURRENT_THREAD));
			  mutex_enter (thread_mtx);
			  client->dks_thread_state = DKST_IDLE;
			  PrpcCheckInAsync (client);
			}
		    }
		  else
		    {
		      future = frq_create (client, req);
		      if (future)
			{
			  thrs_printf ((thrs_fo, "burst read on ses %p thr:%p returned future (%s to_close=%d)\n",
			  	client, THREAD_CURRENT_THREAD,
				future->rq_service ? future->rq_service->sr_name : "<no-service>",
				(int) future->rq_to_close));
			  burst_reqs++;
			  future->rq_thread = c_thread;

			  dk_free_box (req[FRQ_SERVICE_NAME]);
			  req[FRQ_SERVICE_NAME] = NULL;
			  dk_free_box_and_numbers ((box_t) req);	/* mty HUHTI */
			}
		      else
			{
			  thrs_printf ((thrs_fo, "burst read on ses %p thr:%p returned future NULL\n", client, THREAD_CURRENT_THREAD));
			}
		      mutex_enter (thread_mtx);
		    }
		}
	      else
		{
		  SESSTAT_CLR (client->dks_session, SST_TIMED_OUT);
		  mutex_enter (thread_mtx);
		  thrs_printf ((thrs_fo, "no future on burst ses %p thr:%p. making idle\n", client, THREAD_CURRENT_THREAD));
		  client->dks_thread_state = DKST_IDLE;
		  PrpcCheckInAsync (client);
		}

	    }
	  else if (SESSION_SCH_DATA (client)->sio_default_read_ready_action == read_service_request)
	    {
	      if (client->dks_thread_state == DKST_FINISH)
		{
		  thrs_printf ((thrs_fo, "ses %p thr:%p from finish to idle\n", client, THREAD_CURRENT_THREAD));
		  client->dks_thread_state = DKST_IDLE;
		}
	      else
		{
		  thrs_printf ((thrs_fo, "ses %p thr:%p is in %d\n", client, THREAD_CURRENT_THREAD, (int) client->dks_thread_state));
		  GPF_T;
		}
	    }
	}
    state_check_done:

      if (!future)
	{
	  if (c_thread->dkt_request_count)
	    log_error ("c_thread->dkt_request_count != 0.  Leak but not dangerous");
	  c_thread->dkt_request_count = 0;
	  resource_store (free_threads, (void *) c_thread);
	  mutex_leave (thread_mtx);
	  dbg_printf_2 (("No future in basket on thread %p", this_thread));
	  break;
	}
      if (client_trace_flag)
	logit (L_DEBUG, "Got a future from basket, rq_client: %lx, service_name: %s", future->rq_client, future->rq_service->sr_name);
      c_thread->dkt_request_count = 1;
      c_thread->dkt_requests[0] = future;
      future->rq_client->dks_n_threads++;
      mutex_leave (thread_mtx);
      PROCESS_ALLOW_SCHEDULE ();
    }
  dbg_printf_2 (("future_wrapper exiting on thread %p", this_thread));
  return 0;
}


void
PrpcFixedServerThread ()
{
  dk_session_t *ses = IMMEDIATE_CLIENT;
  du_thread_t *self = THREAD_CURRENT_THREAD;
  dk_thread_t *c_thread = PROCESS_TO_DK_THREAD (self);
  if (ses)
    {
      if (ses->dks_fixed_thread && ses->dks_fixed_thread != self)
	GPF_T1 ("client with fixed server thread gets alternate server thread");
      ses->dks_fixed_thread = self;
      if (c_thread)
	c_thread->dkt_fixed_thread = 1;
      mutex_enter (thread_mtx);
      if (ses->dks_thread_state == DKST_BURST)
	{
	  ses->dks_thread_state = DKST_IDLE;
	  PrpcCheckInAsync (ses);
	}
      mutex_leave (thread_mtx);
    }
}


frq_queue_hook_t frq_queue_hook;


void
PrpcSetQueueHook (frq_queue_hook_t h)
{
  frq_queue_hook = h;
}


void
frq_free (future_request_t * frq)
{
  dk_free_tree ((caddr_t) frq->rq_arguments);
  dk_free ((void *) frq, sizeof (future_request_t));
}


/*
  This function creates a future_request_t structure based on a raw
  future request message.
  NOTE: This function copies the original FRQ_ARGUMENTS pointer into
  the newly created structure so be careful not to free it twice!!!
*/
future_request_t *
frq_create (dk_session_t * ses, caddr_t * request)
{
  future_request_t *future_request = (future_request_t *) dk_alloc (sizeof (future_request_t));
  memset (future_request, 0, sizeof (*future_request));

  future_request->rq_client = ses;

#ifndef NDEBUG
  future_request->rq_peer_name = NULL;		 /* box_copy(ses->dks_peer_name); */
#endif /* NDEBUG */

  future_request->rq_to_close = 0;
  if (request == ((caddr_t *) - 1))
    {
      dbg_printf_2 (("\nScheduling a close event for ses %p\n", ses));
      future_request->rq_to_close = 1;
      return future_request;
    }
  if (BOX_ELEMENTS (request) != DA_FRQ_LENGTH)
    {
      sr_report_future_error (ses, "", "invalid future request length");
      PrpcDisconnect (ses);
      dk_free (future_request, sizeof (future_request_t));
      return NULL;
    }

  future_request->rq_is_direct_io = (request[DA_MESSAGE_TYPE] == (caddr_t) (long) DA_DIRECT_IO_FUTURE_REQUEST);

  future_request->rq_service = find_service ((char *) request[FRQ_SERVICE_NAME]);

  if (!future_request->rq_service)
    {
      printf ("\nUnknown service %s requested. req no = %d", request[FRQ_SERVICE_NAME], (int) unbox (request[FRQ_COND_NUMBER]));
      dk_free (future_request, sizeof (future_request_t));
      return NULL;
    }

  future_request->rq_condition = (long) unbox (request[FRQ_COND_NUMBER]);	/* mty HUHTI */
  future_request->rq_arguments = (long **) request[FRQ_ARGUMENTS];

  return future_request;
}


/*##**********************************************************************
 *
 *        schedule_request ()
 *
 * Takes the raw request as returned by read_object.

 *  Creates the request and places it in the
 *  in basket or the recursive in basket.

 *  This expects the request to be an array of the following format: *
 *
 *  0 condition number
 *  1 service name (0 -terminates string)
 *  2. pointer to array of ancestors.
 *  4. argument-1
 *  5. argument 2
 *  .. argument n
 *
 *   --------------
 *
 &  (   For test purposes this does not care about
 &   ancestry and always passes 5 arguments to the
 *   service function
 *
 *
 * Input params :
 *
 *       request - the request block as read by read_object.
 *
 * Output params:
 *
 * Return value : void
 *
 * Limitations  :
 *
 * Globals used : in_basket
 */


static void
schedule_request (TAKE_G dk_session_t * ses, caddr_t * request)
{
  dk_thread_t *thread /* = NULL */ ;

  future_request_t *future_request = frq_create (ses, request);
  if (future_request == NULL)
    return;
  if (future_request->rq_to_close)
    goto schedule_future;

  dk_free_box (request[FRQ_SERVICE_NAME]);
  request[FRQ_SERVICE_NAME] = NULL;
  dk_free_box_and_numbers ((box_t) request);	 /* mty HUHTI */
#if 1						 /*!!! */
  ss_dprintf_2 (("Starting future %ld with thread %p", future_request->rq_condition,
	  /*future_request->rq_service->sr_name, */ thread));
#else
  ss_dprintf_2 (("Received request %ld, %s", future_request->rq_condition, future_request->rq_service->sr_name));
#endif
schedule_future:
  mutex_enter (thread_mtx);
  if (ses->dks_fixed_thread)
    {
      ss_dprintf_2 (("Starting future %ld with ft thread %p", future_request->rq_condition,
	      /*future_request->rq_service->sr_name, */ ses->dks_fixed_thread));
      future_request->rq_thread = PROCESS_TO_DK_THREAD (ses->dks_fixed_thread);
      basket_add (&ses->dks_fixed_thread_reqs, (void *) future_request);
      mutex_leave (thread_mtx);
      semaphore_leave (ses->dks_fixed_thread->thr_schedule_sem);	/* XXX: schedule_sem */
      return;
    }
  thread = get_free_thread (PASS_G ses);
  /* If there is a thread for the request, put it underway right off
     without queuing - oui 020693 */
  if (thread)
    {
      ss_dprintf_4 (("found free thread %p", thread->dkt_process));
      reqs_on_the_fly++;
      thread->dkt_requests[0] = future_request;
      thread->dkt_request_count = 1;
      future_request->rq_thread = thread;
#if 1						 /*!!! */
      ss_dprintf_2 (("Starting future %ld with thread %p", future_request->rq_condition,
	      /*future_request->rq_service->sr_name, */ thread->dkt_process));
#else
      ss_dprintf_2 (("Starting future %ld %s with thread %p", future_request->rq_condition, future_request->rq_service->sr_name, thread->dkt_process));
#endif
      if (ses->dks_thread_state != DKST_BURST)
	{
	  if (ses->dks_thread_state != DKST_IDLE)
	    {
	      thrs_printf ((thrs_fo, "second rq (%s, to_close:%d) on ses %p thr:%p\n", future_request->rq_service ? future_request->rq_service->sr_name : "<no-service>", future_request->rq_to_close, ses, THREAD_CURRENT_THREAD));
	      future_request->rq_is_second = 1;
	      second_rpcs += 1;
	    }
	  else
	    {
	      if (prpc_force_burst_mode && prpc_self_signal_initialized)
		{
		  thrs_printf ((thrs_fo, "ses %p thr:%p forced boost to burst\n", ses, THREAD_CURRENT_THREAD));
		  ses->dks_thread_state = DKST_BURST;
		  burst_reqs++;
		  remove_from_served_sessions (ses);
		}
	      else
		{
		  thrs_printf ((thrs_fo, "ses %p thr:%p to run\n", ses, THREAD_CURRENT_THREAD));
		  ses->dks_thread_state = DKST_RUN;
		}
	    }
	}
      else
	{
	  thrs_printf ((thrs_fo, "ses %p thr:%p still burst (%s, to_close:%d)\n", ses, THREAD_CURRENT_THREAD, future_request->rq_service ? future_request->rq_service->sr_name : "<no-service>", future_request->rq_to_close));
	}
      mutex_leave (thread_mtx);

      semaphore_leave (thread->dkt_process->thr_schedule_sem);	/* XXX: schedule_sem */
      check_inputs_action_count++;
    }
  else
    {
      thrs_printf ((thrs_fo, "**ses %p thr:%p have no thread\n", ses, THREAD_CURRENT_THREAD));
      if (frq_queue_hook)
	{
	  if (!frq_queue_hook (future_request))
	    {
	      frq_free (future_request);
	      mutex_leave (thread_mtx);
	      return;
	    }
	}
      ss_dprintf_4 (("found no free thread - queueing"));
      queued_reqs++;
      if (client_trace_flag)
	logit (L_DEBUG, "adding to in_basket client: %lx service: %s", future_request->rq_client, future_request->rq_service->sr_name);
      thrs_printf ((thrs_fo, "**ses %p thr:%p req to basket\n", ses, THREAD_CURRENT_THREAD));
      basket_add (&in_basket, future_request);
      mutex_leave (thread_mtx);
    }
}


#else
void
call_disconnect_callback_func (dk_session_t * ses)
{
}
#endif /* NO_THREAD */

#ifdef INPROCESS_CLIENT

#define INPROCESS_NO_THREAD

static dk_session_t *(*make_inprocess_session_p) ();
static void (*free_inprocess_session_p) (dk_session_t * ses);
static void (*do_inprocess_request_p) (TAKE_G dk_session_t * ses, caddr_t * request);

#ifndef NO_THREAD

typedef struct request_context_s
{
  int rc_request_count;
  future_request_t *rc_future_request;
  void *rc_hook_data;
} request_context_t;

static void *(*inprocess_enter_hook) (dk_session_t * ses);
static void (*inprocess_leave_hook) (void *);

void
PrpcSetInprocessHooks (void *(*enter) (dk_session_t * ses), void (*leave) (void *))
{
  inprocess_enter_hook = enter;
  inprocess_leave_hook = leave;
}


void
inprocess_request_enter (request_context_t * context, dk_thread_t * thread, dk_session_t * ses, future_request_t * future)
{
  if (inprocess_enter_hook)
    context->rc_hook_data = (*inprocess_enter_hook) (ses);

  context->rc_request_count = thread->dkt_request_count;
  context->rc_future_request = thread->dkt_requests[0];

  thread->dkt_requests[0] = future;
  thread->dkt_request_count = 1;
  future->rq_thread = thread;
}


void
inprocess_request_leave (request_context_t * context, dk_thread_t * thread)
{
  thread->dkt_request_count = context->rc_request_count;
  thread->dkt_requests[0] = context->rc_future_request;

  if (inprocess_leave_hook)
    (*inprocess_leave_hook) (context->rc_hook_data);
}


void
inprocess_request (TAKE_G dk_session_t * ses, caddr_t * request)
{
  du_thread_t *this_thread;
  dk_thread_t *thread;
  int argcount, finx, error, ret_type;
  caddr_t *arguments;
  caddr_t arg_array[MAX_FUTURE_ARGUMENTS];
  volatile caddr_t result = NULL;
  request_context_t context = {0};
  future_request_t *future;

  future = frq_create (ses, request);
  if (future == NULL)
    return;
  if (future->rq_to_close)
    return;

  dk_free_box (request[FRQ_SERVICE_NAME]);
  request[FRQ_SERVICE_NAME] = NULL;
  dk_free_box_and_numbers ((box_t) request);	 /* mty HUHTI */

  this_thread = THREAD_CURRENT_THREAD;
  thread = PROCESS_TO_DK_THREAD (this_thread);
  future->rq_thread = thread;
  inprocess_request_enter (&context, thread, ses, future);

  arguments = (caddr_t *) future->rq_arguments;
  argcount = (arguments ? (int) (box_length ((caddr_t) arguments) / sizeof (caddr_t)) : (int) 0);

  error = 0;
  strses_flush (ses);
  mutex_enter (thread_mtx);
  if (ses->dks_thread_state != DKST_BURST)
    {
      if (ses->dks_thread_state != DKST_IDLE)
	{
	  thrs_printf ((thrs_fo, "second rq (%s, to_close:%d) on ses %p thr:%p\n",
	  	future->rq_service ? future->rq_service->sr_name : "<no-service>",
		future->rq_to_close, ses, THREAD_CURRENT_THREAD));
	  future->rq_is_second = 1;
	  second_rpcs += 1;
	}
      else
	{
	  /*if (prpc_force_burst_mode && prpc_self_signal_initialized)
	     {
	     thrs_printf ((thrs_fo, "ses %p thr:%p forced boost to burst\n", ses, THREAD_CURRENT_THREAD));
	     ses->dks_thread_state = DKST_BURST;
	     burst_reqs ++;
	     remove_from_served_sessions (ses);
	     }
	     else */
	  {
	    thrs_printf ((thrs_fo, "ses %p thr:%p to run\n", ses, THREAD_CURRENT_THREAD));
	    ses->dks_thread_state = DKST_RUN;
	  }
	}
    }
  else
    {
      thrs_printf ((thrs_fo, "ses %p thr:%p still burst (%s, to_close:%d)\n",
	ses, THREAD_CURRENT_THREAD,
	future->rq_service ? future->rq_service->sr_name : "<no-service>",
	future->rq_to_close));
    }
  mutex_leave (thread_mtx);

  if (future->rq_service->sr_client_data)
    error = sr_check_and_set_args (future, arguments, argcount, arg_array);
  else
    {
      for (finx = 0; finx < MAX_FUTURE_ARGUMENTS; finx++)
	if (finx < argcount)
	  arg_array[finx] = (caddr_t) unbox_ptrlong (arguments[finx]);
	else
	  arg_array[finx] = NULL;
    }

  dk_free_box_and_int_boxes ((caddr_t) arguments);
  /* Free this now. If freed after RPC func the references items may have been
     freed and reallocated and could be erroneously re-freed. */

  if (f_future_preprocess)
    f_future_preprocess ();
  if (0 == error)
    {
      ss_dprintf_3 (("Starting future %ld, %s", future->rq_condition, future->rq_service->sr_name));

      F_CALLED;					 /* not serialized, does not have to be exact. */
      CB_PREPARE;
      result = (caddr_t) future->rq_service->sr_func (
		arg_array[0], arg_array[1], arg_array[2], arg_array[3],
		arg_array[4], arg_array[5], arg_array[6], arg_array[7],
		arg_array[8]);
      CB_DONE;
    }

  /* Send the answer if needed. */
  ret_type = future->rq_service->sr_return_type;
  if (DV_SEND_NO_ANSWER != ret_type)
    {
      /* Box the result */
      caddr_t *ret_box;
      caddr_t *ret_block = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * DA_ANSWER_LENGTH, DV_ARRAY_OF_POINTER);
      if (ret_type == DV_MULTIPLE_VALUES)
	ret_box = (caddr_t *) result;
      else
	{
	  ret_box = (caddr_t *) dk_alloc_box (sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  if (ret_type == DV_LONG_INT || ret_type == DV_SHORT_INT)
	    ret_box[0] = box_num ((ptrlong) result);
	  else if (ret_type == DV_C_STRING)
	    ret_box[0] = box_string (result);
	  else
	    ret_box[0] = result;
	}
      ret_block[DA_MESSAGE_TYPE] = (caddr_t) (long) DA_FUTURE_ANSWER;
      ret_block[RRC_COND_NUMBER] = box_num (future->rq_condition);
      ret_block[RRC_VALUE] = (caddr_t) ret_box;
      ret_block[RRC_ERROR] = box_num (error);
      CB_PREPARE;
      {
#ifdef PMN_NMARSH
	srv_write_in_session (ret_block, future->rq_client, 1);
#else
	write_in_session ((caddr_t) ret_block, future->rq_client, NULL, NULL, 1);
#endif
      }
      CB_DONE;
      if (ret_type == DV_C_STRING)
	dk_free_box ((caddr_t) ret_box[0]);	 /* mty HUHTI */
      dk_free_box_and_numbers ((caddr_t) ret_block);	/* mty HUHTI */
      dk_free_box_and_numbers ((caddr_t) ret_box);	/* mty HUHTI */
    }

  /* epilogue */
  if (future->rq_service->sr_postprocess)
    {
      CB_PREPARE;
      future->rq_service->sr_postprocess (result, future);
      CB_DONE;
    }

  dbg_printf_2 (("Done Future %ld on thread %p", future->rq_condition, this_thread));
  F_RETURNED;

#ifndef NDEBUG
  dk_free_box (future->rq_peer_name);
#endif /* NDEBUG */
  dk_free (future, sizeof (future_request_t));

  inprocess_request_leave (&context, thread);
  return;
}


dk_session_t *
make_inprocess_session ()
{
  char buffer[100];
  dk_session_t *session = inpses_allocate ();

  snprintf (buffer, sizeof (buffer), "inproc:%ld", ++connection_count);
  session->dks_peer_name = box_string (buffer);
  session->dks_own_name = box_string (buffer);

  return session;
}


void
free_inprocess_session (dk_session_t * ses)
{
  mutex_free (ses->dks_mtx);
  dk_free_box (ses->dks_peer_name);
  dk_free_box (ses->dks_own_name);
  /* dks_caller_id_opts is set by the client and should be freed by it as well.
     dk_free_tree (ses->dks_caller_id_opts);
   */
  dk_free_box ((box_t) ses);
}


dk_session_t *
make_tmp_inprocess_session (dk_session_t * ses)
{
  dk_session_t *session = inpses_allocate ();

  session->dks_peer_name = ses->dks_peer_name;
  session->dks_own_name = ses->dks_own_name;
  session->dks_caller_id_opts = ses->dks_caller_id_opts;

  return session;
}


void
free_tmp_inprocess_session (dk_session_t * ses)
{
  mutex_free (ses->dks_mtx);

  ses->dks_peer_name = 0;
  ses->dks_own_name = 0;
  ses->dks_caller_id_opts = 0;

  dk_free_box ((box_t) ses);
}


void
do_inprocess_request (TAKE_G dk_session_t * ses, caddr_t * request)
{
#ifndef INPROCESS_NO_THREAD
  dk_session_t *tmpses = make_tmp_inprocess_session (ses);
#endif

  request = (caddr_t *) box_copy_tree ((box_t) request);

#if defined(_MSC_VER) && defined(_DEBUG)
  inpses_verify (ses);
#endif

#ifdef INPROCESS_NO_THREAD
  inprocess_request (PASS_G ses, (caddr_t *) request);
#else
  inprocess_request (PASS_G tmpses, (caddr_t *) request);
  mutex_enter (ses->dks_mtx);
  strses_write_out (tmpses, ses);
  mutex_leave (ses->dks_mtx);
  free_tmp_inprocess_session (tmpses);
#endif

#if defined(_MSC_VER) && defined(_DEBUG)
  inpses_verify (ses);
#endif
}


void
read_inprocess_request (dk_session_t * ses)
{
  USE_GLOBAL
  ptrlong * request = (ptrlong *) read_object (ses);
  inprocess_request (PASS_G ses, (caddr_t *) request);
}


caddr_t *
sf_inprocess_ep ()
{
  int pid;
  dk_session_t *client = IMMEDIATE_CLIENT;
  caddr_t *ret = (caddr_t *) dk_alloc_box (5 * sizeof (caddr_t) + 1, DV_SHORT_STRING);

  pid = getpid ();
  ret[0] = (caddr_t) (ptrlong) pid;
  ret[1] = (caddr_t) & make_inprocess_session;
  ret[2] = (caddr_t) & free_inprocess_session;
  ret[3] = (caddr_t) & do_inprocess_request;
  ret[4] = (caddr_t) & read_inprocess_request;

  thrs_printf ((thrs_fo, "ses %p thr:%p in sf_inprocess_ep1\n", client, THREAD_CURRENT_THREAD));
  DKST_RPC_DONE (client);
  return ret;
}


# endif	/* NO_THREAD */

/* Inprocess client entry points */
SERVICE_0 (s_inprocess_ep, "ICEP", DA_FUTURE_REQUEST, DV_ARRAY_OF_POINTER);
#endif /* INPROCESS_CLIENT */

/*
 *  realize_condition()
 *
 * This gets the future identified by the cond number from the
 * pending_futures table and stores the value and error into it.
 *
 * This enables all threads waiting for the future.
 * Adds the token to the continue basket or enables directly,
 * depending on whether the enabled token is the topmost on
 * its thread or not.
 *
 * possible values of ft_is_ready flag:
 * FS_RESULT_LIST_COMPLETE
 * FS_SINGLE_COMPLETE
 * FS_RESULT_LIST
 * FS_FALSE = false
 */
static int
realize_condition (dk_session_t * ses, long cond, caddr_t value, caddr_t error, int is_in_value_mtx)
{
  USE_GLOBAL
  future_t * future;
  future_request_t *waiting;

  if (!is_in_value_mtx)
    IN_VALUE;

  future = (future_t *) gethash ((void *) (ptrlong) cond, PENDING_FUTURES (ses));

/*
   puts("Realize condition");
   fflush(stdout);
*/

  if (!future)
    {
/*
      printf ("The condition %d was realized but had no future.\n", cond);
*/
      if (!is_in_value_mtx)
	LEAVE_VALUE;
      return (-1);
    }
  if (future->ft_result)			 /* (future->ft_is_ready == FS_RESULT_LIST) */
    {
      future->ft_result = (caddr_t) dk_set_conc ((dk_set_t) (future->ft_result), dk_set_cons (value, NULL));
/*
      dk_set_push ( (dk_set_t *)&  future->ft_result, (void *) value);
*/
      future->ft_is_ready = FS_RESULT_LIST_COMPLETE;
    }
  else
    {
      future->ft_result = value;
      future->ft_is_ready = FS_SINGLE_COMPLETE;
    }
  future->ft_error = error;
  if (future->ft_timeout.to_sec || future->ft_timeout.to_usec)
    {
      get_real_time (&future->ft_time_received);
    }
  waiting = future->ft_waiting_requests;
  while (waiting)
    {
      dk_thread_t *thread = waiting->rq_thread;
      future_request_t *top_of_thread = thread->dkt_requests[thread->dkt_request_count - 1];
      future_request_t *next = waiting->rq_next_waiting;
      future->ft_waiting_requests = next;
      if (waiting == top_of_thread)
	semaphore_leave (thread->dkt_process->thr_sem);
      else
	GPF_T;
      waiting = next;
    }
  remhash ((void *) (ptrlong) cond, PENDING_FUTURES (ses));
  if (!is_in_value_mtx)
    LEAVE_VALUE;
  return (0);
}


static void
unfreeze_waiting (TAKE_G future_t * future)
{
  future_request_t *waiting = future->ft_waiting_requests;
  while (waiting)
    {
      dk_thread_t *thread = waiting->rq_thread;
      future_request_t *top_of_thread = thread->dkt_requests[thread->dkt_request_count - 1];
      future_request_t *next = waiting->rq_next_waiting;
      future->ft_waiting_requests = next;
      if (waiting == top_of_thread)
	semaphore_leave (thread->dkt_process->thr_sem);
      else
	GPF_T;
      waiting = next;
    }
}


/*
 *  partial_realize_condition()
 */
static int
partial_realize_condition (dk_session_t * ses, long cond, caddr_t value)
{
  USE_GLOBAL;

  IN_VALUE;
  {
    future_t *future = (future_t *) gethash ((void *) (ptrlong) cond, PENDING_FUTURES (ses));

    if (!future)
      {
/*
   printf ("The condition %d was realized but had no future", cond);
   #ifndef DLL
   fflush(stdout);
   #endif
 */
	LEAVE_VALUE;
	return (-1);
      }

    future->ft_result = (caddr_t) dk_set_conc ((dk_set_t) (future->ft_result), dk_set_cons (value, NULL));

/*
   dk_set_push ((dk_set_t *) & future->ft_result, (void *) value);
 */
    future->ft_is_ready = FS_RESULT_LIST;
    if (future->ft_timeout.to_sec || future->ft_timeout.to_usec)
      {
	get_real_time (&future->ft_time_received);
      }
    unfreeze_waiting (PASS_G future);
    LEAVE_VALUE;
    return (0);
  }
}


/*##**********************************************************************
 *
 *              realize_all_waiting, is_this_disconnected
 *
 *  When a session has dropped mark all the futures on it as timed out.
 *
 * Input params :
 *
 *      ses       - The disconnected session.
 *
 * Output params:
 *
 * Return value : void
 *
 * Limitations  :
 *
 * Globals used : disconnected
 */

#ifndef NO_THREAD
static dk_session_t *disconnected = NULL;
#endif

static void
is_this_disconnected (long cond, future_t * future)
{
#ifndef NO_THREAD
  if (future->ft_server == disconnected)
#endif
    realize_condition (future->ft_server, future->ft_request_no, (caddr_t) NULL, (caddr_t) (ptrlong) FE_TIMED_OUT, 1);
}


static void
realize_all_waiting (dk_session_t * ses)
{
  USE_GLOBAL

  IN_VALUE;
#ifndef NO_THREAD
  disconnected = ses;
#endif
  maphash ((maphash_func) is_this_disconnected, PENDING_FUTURES (ses));
  LEAVE_VALUE;
}


/*##**********************************************************************
 *
 *              dks_remove_pending
 *
 *  Remove all queued requests from the session.
 *  return true if the session is free, e.g.
 *  all queued requests have been removed and there are no executing
 *  requests for that session.
 *
 *
 * Input params :
 *
 *      ses       - The dropped session.

 *
 * Return value :  true if the session is clear to be freed.
 *
 *
 * Limitations  : run atomically on server thread.
 *
 * Globals used : in_basket, threads.
 */
static int
dks_remove_pending (dk_session_t * ses)
{
#if 0
  USE_GLOBAL
  dk_set_t it;
  dk_set_t *prev;

  prev = &in_basket.first_token;
  for (it = in_basket.first_token; it;)
    {
      dk_set_t next = it->next;
      future_request_t *frq = (future_request_t *) it->data;
      if (frq->rq_client == ses)
	{
	  *prev = it->next;
	  dk_free (it, sizeof (s_node_t));
	  dk_free (frq, sizeof (future_request_t));
	}
      else
	{
	  prev = &it->next;
	}
      it = next;
    }
  in_basket.last_token = dk_set_last (in_basket.first_token);
#else
  if (in_basket.bsk_count)
    {
      basket_t *bsk;

      bsk = in_basket.bsk_next;
      while (bsk != &in_basket)
	{
	  future_request_t *frq = (future_request_t *) bsk->bsk_pointer;
	  if (frq->rq_client == ses)
	    {
	      basket_t *b_nxt = bsk->bsk_next;

	      LISTDELETE (bsk, bsk_next, bsk_prev);
	      in_basket.bsk_count--;
	      dk_free (bsk, sizeof (basket_t));
	      dk_free (frq, sizeof (future_request_t));
	      bsk = b_nxt;
	    }
	  else
	    bsk = bsk->bsk_next;
	}
    }
#endif

  return 1;
}


/*##**********************************************************************
 *
 *              read_service_request
 *
 *  This function is called when a client session is ready for reading.
 *  This reads the message coming in and dispatches it according to its type
 *  DA_<xx>.
 *  Tj the session is disconnected and frees  the closes the session.
 *
 *
 * Input params :
 *
 *      ses       - The session found ready for reading.

 *
 * Output params:
 *
 * Return value : void
 *
 *
 * Limitations  :
 *
 * Globals used : session_request_hook services
 */
int
read_service_request (dk_session_t * ses)
{
  USE_GLOBAL
  ptrlong * request = (ptrlong *) read_object (ses);

  if (!SESSTAT_ISSET (ses->dks_session, SST_TIMED_OUT) && !SESSTAT_ISSET (ses->dks_session, SST_BROKEN_CONNECTION) && (DV_TYPE_OF (request) != DV_ARRAY_OF_POINTER || BOX_ELEMENTS (request) < 1))
    {
      sr_report_future_error (ses, "", "invalid future box");
      SESSTAT_CLR (ses->dks_session, SST_OK);
      SESSTAT_SET (ses->dks_session, SST_BROKEN_CONNECTION);
    }

  dbg_printf_2 (("new request"));
  if (SESSTAT_ISSET (ses->dks_session, SST_TIMED_OUT) || SESSTAT_ISSET (ses->dks_session, SST_BROKEN_CONNECTION))
    {
      without_scheduling_tic ();
      if (!ses->dks_is_server)
	{
	  mutex_enter (thread_mtx);
	  session_is_dead (ses);
	  mutex_leave (thread_mtx);
	  realize_all_waiting (ses);
	  return 0;
	}
      mutex_enter (thread_mtx);

      dks_remove_pending (ses);
      remove_from_served_sessions (ses);
      restore_scheduling_tic ();

      if (ses->dks_fixed_thread && 0 == ses->dks_n_threads)
	{
	  basket_add (&ses->dks_fixed_thread_reqs, (void *) 0);
	  mutex_leave (thread_mtx);
	  semaphore_leave (ses->dks_fixed_thread->thr_schedule_sem);	/* XXX: schedule_sem */
	  return 0;
	}
      if (ses->dks_n_threads)
	{
	  dk_thread_t *c_thread = ses->dks_fixed_thread ? PROCESS_TO_DK_THREAD (ses->dks_fixed_thread) : NULL;
	  ses->dks_to_close = 1;		 /* The last quitting thread will close */
	  call_disconnect_callback_func (ses);
	  if (c_thread)
	    c_thread->dkt_fixed_thread = 0;
	  if (client_trace_flag)
	    {
	      logit (L_DEBUG, "read_service_request: session %lx scheduled for closing.", ses);
	    }
	}
      else
	{
#ifdef NO_THREAD
	  session_is_dead (ses);
#else
	  if (!ses->dks_is_server)
	    session_is_dead (ses);
	  else
	    {
	      dbg_printf_2 (("\nsession %p is about to close.Schedule it\n", ses));
	      ses->dks_to_close = 1;		 /* The last quitting thread will close */
	      call_disconnect_callback_func (ses);
	      mutex_leave (thread_mtx);
	      schedule_request (PASS_G ses, (caddr_t *) - 1);
	      return (0);
	    }
#endif
	}

      mutex_leave (thread_mtx);

      ss_dprintf_1 (("Dropping client. Session=%p", ses));

      return (0);
    }

  if (!request)					 /* mty MAALIS 23.3.93 */
    return (0);

  if (service_request_hook)
    {
      CB_PREPARE;
      request = (ptrlong *) service_request_hook (ses, (caddr_t) request);
      CB_DONE;
    }
  if (!request)
    return (0);

  switch (request[DA_MESSAGE_TYPE])
    {
#ifndef NO_THREAD
    case DA_FUTURE_REQUEST:
      schedule_request (PASS_G ses, (caddr_t *) request);
      break;

    case DA_DIRECT_IO_FUTURE_REQUEST:
      SESSION_CHECK_OUT (ses);
/*
      SESSION_SCH_DATA (ses)->sio_default_read_ready_action = NULL;
*/
      /* The session will not for now be listened to by check_inputs() */
      schedule_request (PASS_G ses, (caddr_t *) request);
      break;
#endif

    case DA_FUTURE_ANSWER:
      if (BOX_ELEMENTS (request) != DA_ANSWER_LENGTH)
	{
	  sr_report_future_error (ses, "", "invalid future answer length");
	  PrpcDisconnect (ses);
	  dk_free_tree ((box_t) request);
	  return 0;
	}

      ss_dprintf_2 (("received answer %ld", (long) unbox ((caddr_t) request[RRC_COND_NUMBER])));

      if (-1 == realize_condition (ses, (long) unbox ((caddr_t) request[RRC_COND_NUMBER]), (caddr_t) request[RRC_VALUE],	/* mty HUHTI */
	      (caddr_t) request[RRC_ERROR], 0))
	dk_free_tree ((caddr_t) request);
      else
	{
	  request[RRC_VALUE] = 0;		 /* receiving future_t will free this */
	  dk_free_box_and_numbers ((caddr_t) request);
	}
      break;

    case DA_FUTURE_PARTIAL_ANSWER:
      if (BOX_ELEMENTS (request) != DA_ANSWER_LENGTH)
	{
	  sr_report_future_error (ses, "", "invalid future partial answer length");
	  PrpcDisconnect (ses);
	  dk_free_tree ((box_t) request);
	  return 0;
	}

      ss_dprintf_2 (("received partial answer %ld", (long) unbox ((caddr_t) request[RRC_COND_NUMBER])));
      if (-1 == partial_realize_condition (ses, (long) unbox ((caddr_t) request[RRC_COND_NUMBER]), (caddr_t) request[RRC_VALUE]))
	dk_free_tree ((caddr_t) request);
      else
	{
	  request[RRC_VALUE] = 0;		 /* receiving future_t will free this */
	  dk_free_box_and_numbers ((caddr_t) request);
	}
      break;

    default:
      sr_report_future_error (ses, "", "invalid future type");
      PrpcDisconnect (ses);
      dk_free_tree ((box_t) request);
      return 0;

    }
  return 0;
}


resource_t *tcpses_rc;

/*##**********************************************************************
 *
 *              dk_session_allocate
 *
 * Allocate a server level session. Allocates the session level session
 * buffers and the scheduling control block used buy the server level.
 *
 * Input params :
 *
 *      class     - The session level session class.

 *
 * Output params:
 *
 * Return value : The server level session (dk_session_t)
 *
 *
 * Limitations  :
 *
 * Globals used :
 */
dk_session_t *
dk_session_allocate (int sesclass)
{
  dk_session_t *dk_ses = NULL;
  session_t *ses;

#if 0
  if (SESCLASS_TCPIP == sesclass)
    dk_ses = (dk_session_t *) resource_get (tcpses_rc);
  if (dk_ses)
    return dk_ses;
#endif

  dk_ses = (dk_session_t *) dk_alloc (sizeof (dk_session_t));
  memset (dk_ses, 0, sizeof (dk_session_t));

  ses = session_allocate (sesclass);
  SESSION_SCH_DATA (dk_ses) = (scheduler_io_data_t *) dk_alloc (sizeof (scheduler_io_data_t));
  memset (SESSION_SCH_DATA (dk_ses), 0, sizeof (scheduler_io_data_t));
  SESSION_SCH_DATA (dk_ses)->sio_is_served = -1;

  dk_ses->dks_session = ses;
  SESSION_DK_SESSION (ses) = dk_ses;		 /* two way link. */
  dk_ses->dks_mtx = mutex_allocate ();

  dk_ses->dks_in_buffer = (char *) dk_alloc (DKSES_IN_BUFFER_LENGTH);
  dk_ses->dks_in_length = DKSES_IN_BUFFER_LENGTH;

  dk_ses->dks_out_buffer = (char *) dk_alloc (DKSES_OUT_BUFFER_LENGTH);
  dk_ses->dks_out_length = DKSES_OUT_BUFFER_LENGTH;
  dk_ses->dks_read_block_timeout.to_sec = 100;

  return dk_ses;
}


void
dk_session_clear (dk_session_t * ses)
{
  session_t *dks_ses = ses->dks_session;
  dk_mutex_t *mtx = ses->dks_mtx;
  char *in = ses->dks_in_buffer;
  char *out = ses->dks_out_buffer;
  scheduler_io_data_t *sc = SESSION_SCH_DATA (ses);

  dk_free_box (ses->dks_peer_name);
  dk_free_box (ses->dks_own_name);
  dk_free_tree ((box_t) ses->dks_caller_id_opts);

  memset (ses, 0, sizeof (dk_session_t));
  memset (sc, 0, sizeof (scheduler_io_data_t));
  sc->sio_is_served = -1;
  SESSION_SCH_DATA (ses) = sc;
  ses->dks_in_buffer = in;
  ses->dks_in_length = DKSES_IN_BUFFER_LENGTH;
  ses->dks_out_buffer = out;
  ses->dks_out_length = DKSES_OUT_BUFFER_LENGTH;
  ses->dks_read_block_timeout.to_sec = 100;
  ses->dks_mtx = mtx;
  ses->dks_session = dks_ses;
  tcpses_set_fd (dks_ses, -1);
  dks_ses->ses_status = SST_OK;
}


/*
  accept_client ()

  This function is applied to the listening session when a
  connect is pending. This accepts the connect and adds the session to
  the served sessions set.
*/
#ifndef NO_THREAD
static int
accept_client (dk_session_t * ses)
{
  dk_session_t *newses = dk_session_allocate (ses->dks_session->ses_class);
  without_scheduling_tic ();
  session_accept (ses->dks_session, newses->dks_session);
  restore_scheduling_tic ();

  SESSION_SCH_DATA (newses)->sio_default_read_ready_action = read_service_request;
  SESSION_SCH_DATA (newses)->sio_random_read_ready_action = NULL;
  SESSION_SCH_DATA (newses)->sio_random_write_ready_action = NULL;

#ifdef _SSL
  if (!ssl_server_accept (ses, newses))
    return 0;
#endif
  newses->dks_read_block_timeout.to_sec = 50;
  newses->dks_is_server = 1;
  if (-1 == add_to_served_sessions (newses))
    {
      PrpcDisconnect (newses);
      PrpcSessionFree (newses);
#ifdef UNIX
      log_error ("Exceeded maximum number of file descriptors in FD_SET.\n");
#endif
    }

  ss_dprintf_1 (("Accepted client. Session=%p", newses));

  return 0;
}


static select_func_t
sesclass_select_func (int sesclass)
{
  select_func_t f = NULL;
#ifdef COM_TCPIP
  if (SESCLASS_TCPIP == sesclass || SESCLASS_UDPIP == sesclass)
    f = (tcpses_select);
#endif
#ifdef COM_NMPIPE
  if (SESCLASS_NMP == sesclass)
    f = (nmpses_select);
#endif
  return f;
}
#endif /* NO_THREAD */

timeout_t time_now;
uint32 time_now_msec;


static int
is_this_timed_out (void *key, future_t * future)	/* MAALIS mty */
{
  timeout_t due;
  USE_GLOBAL
#ifndef PMN_MODS
  /* mty MAALIS 7 lines below */
  timeout_t tmptime;
  tmptime.to_sec = time_now.to_sec;
  tmptime.to_usec = time_now.to_usec;

  /* Test if clock wrapped around */
  if (time_gt (&future->ft_time_issued, &time_now))
    {
      tmptime.to_sec += 60;
    }
#endif

  due = future->ft_time_issued;
  time_add (&due, &future->ft_timeout);
  if ((future->ft_timeout.to_sec || future->ft_timeout.to_usec) && time_gt (&time_now, &due))
    {
      ss_dprintf_3 (("Future %ld Timed out.", future->ft_request_no));

#ifdef NOT
      printf ("Future %ld timed out\n", future->ft_request_no);
      printf ("Current time %ld %ld \n", time_now.to_sec, time_now.to_usec);
      printf ("Future start %ld %ld \n", future->ft_time_issued.to_sec, future->ft_time_issued.to_usec);
      printf ("Future timeout %ld %ld \n", future->ft_timeout.to_sec, future->ft_timeout.to_usec);
      printf ("Tmptime %ld %ld \n", tmptime.to_sec, tmptime.to_usec);
#endif
      realize_condition (future->ft_server, future->ft_request_no, (caddr_t) NULL, (caddr_t) (long) FE_TIMED_OUT, 1);	/* mty MAALIS */
    }
  return (0);					 /* mty MAALIS */
}


void
timeout_round (TAKE_G dk_session_t * ses)
{
  static int32 last_time_msec;
  int32 atomic_msec;
  ss_dprintf_2 (("Timeout round."));
#ifdef NO_THREAD
  if (NULL == ses)				 /* if single thread session must be passed */
    GPF_T;
#endif
  get_real_time (&time_now);
  time_now_msec = time_now.to_sec * 1000 + time_now.to_usec / 1000;
  atomic_msec = atomic_timeout.to_sec * 1000 + (atomic_timeout.to_usec / 1000);
  if (atomic_msec < 100)
    atomic_msec = 100;
  if ((uint32)time_now_msec - (uint32)last_time_msec < atomic_msec)
    return;
  last_time_msec = time_now_msec;

  if (background_action)
    {
      CB_PREPARE;
      background_action ();
      CB_DONE;
    }

  IN_VALUE;
  maphash ((maphash_func) is_this_timed_out, PENDING_FUTURES (ses));
  LEAVE_VALUE;
}


#ifndef NO_THREAD
#define DKT_THREAD_INIT() \
  { \
    dk_thread_t *dkt = dk_thread_alloc (); \
    du_thread_t *thr = thread_current (); \
    thr->thr_client_data = dkt; \
    dkt->dkt_process = thr; \
  }

/*##**********************************************************************
 *
 *              server_loop
 *
 * An infinite loop executed on the reading thread.  This scans all
 * pending reads and writes. If there are no other runnable threads
 * this blocks for a period of atomic_timeout. This calls timeout_round
 * at intervals of approximately atomic_timeout.
 *
 * Input params :        - none
 *
 * Output params:    - none
 *
 * Return value :
 *
 * Limitations  :
 *
 * Globals used :    atomic_timeout
 */
static int
server_loop (void *arg)
{
  int sesclass = (int) (ptrlong) arg;
  timeout_t zero_timeout = { 0, 0 };

  USE_GLOBAL
  long time_spent = 0;
  long time_between_rounds = (atomic_timeout.to_sec * 1000 + atomic_timeout.to_usec / 1000) / time_slice;

  DKT_THREAD_INIT ();
  DK_CURRENT_THREAD->dkt_request_count = 0;

  while (1)
    {
      if (!process_is_quiescent (PASS_G1))
	check_inputs_low (PASS_G & zero_timeout, 0, sesclass_select_func (sesclass), sesclass);
      else
	check_inputs_low (PASS_G & atomic_timeout, 0, sesclass_select_func (sesclass), sesclass);

      time_spent += time_between_rounds;

      PROCESS_ALLOW_SCHEDULE ();

      if (time_spent >= time_between_rounds)
	{
	  time_spent = 0;
	  timeout_round (PASS_G NULL);
	}
    }

  /*NOTREACHED*/
  return 0;
}
#endif /* NO_THREAD */



static dk_thread_t *
dk_thread_alloc (void)
{
  future_request_t *rq;
  dk_thread_t *dkt;

  rq = (future_request_t *) dk_alloc (sizeof (future_request_t));
  dkt = (dk_thread_t *) dk_alloc (sizeof (dk_thread_t));

  if (dkt == NULL || rq == NULL)
    return NULL;

  memset (rq, 0, sizeof (future_request_t));
  memset (dkt, 0, sizeof (dk_thread_t));

  rq->rq_thread = dkt;

  dkt->dkt_requests[0] = rq;
  dkt->dkt_request_count = 1;

  return dkt;
}


void
dk_thread_free (void *data)
{
  dk_thread_t *dkt = (dk_thread_t *) data;
  ASSERT_IN_MTX (thread_mtx);
  if (dkt && dkt->dkt_requests[0] && dkt->dkt_request_count)
    dk_free (dkt->dkt_requests[0], sizeof (future_request_t));
  dk_free (dkt, sizeof (dk_thread_t));
  --future_thread_count;
}


void
PrpcSuckAvidly (int mode)
{
  suck_avidly = mode;
}


#ifndef NO_THREAD
/*##**********************************************************************
 *
 *      PrpcAddAnswer
 *
 * This is used inside a service function of a future to send an answer
 * to the client.
 & The data on the future computation in progress is retrieved from the
 * current thread. (e.g. client, request number etc).
 *
 *  This function sends partial answers to future requests.
 *  Used when an application function eg. a query has a long execution time
 *  and we want to speed things by sending parts of the of the result to the
 * client as soon as they are obtained.
 *  Typical call chain: future_wrapper -->application_function -->PrpcAddAnswer.
 * The last answer is sent by future_wrapper after the application function
 * returns.
 *
 * Input params :
 *
 *      result    - The value to send
 *      result_type - The data type of  the value to send.
 *
 * Output params:
 *
 * Return value : void
 *
 * Limitations  :
 *
 * Globals used : current_thread
 */
void
PrpcAddAnswer (caddr_t result, int ret_type, int is_partial, int flush)
{
  caddr_t rbtmp;
  USE_GLOBAL
  dk_thread_t * c_thread = DK_CURRENT_THREAD;
  future_request_t *future = c_thread->dkt_requests[c_thread->dkt_request_count - 1];
  {
    /* Box the result */
    caddr_t *ret_box;
    caddr_t ret_block_auto[10];
    caddr_t *ret_block;

    BOX_AUTO (rbtmp, ret_block_auto, sizeof (caddr_t) * DA_ANSWER_LENGTH, DV_ARRAY_OF_POINTER);
    ret_block = (caddr_t *) rbtmp;
    if (ret_type == DV_MULTIPLE_VALUES)
      ret_box = (caddr_t *) result;
    else
      {
	ret_box = (caddr_t *) dk_alloc_box (sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	if (ret_type == DV_LONG_INT || ret_type == DV_SHORT_INT)
	  ret_box[0] = box_num ((ptrlong) result);
	else if (ret_type == DV_C_STRING)
	  ret_box[0] = box_string (result);
	else
	  ret_box[0] = result;
      }

    ret_block[DA_MESSAGE_TYPE] = (caddr_t) (ptrlong) (is_partial ? DA_FUTURE_PARTIAL_ANSWER : DA_FUTURE_ANSWER);

    ret_block[RRC_COND_NUMBER] = box_num (future->rq_condition);
    ret_block[RRC_VALUE] = (caddr_t) ret_box;
    ret_block[RRC_ERROR] = NULL;
    CB_PREPARE
#ifdef PMN_NMARSH
	srv_write_in_session (ret_block, future->rq_client, flush);
#else
	write_in_session ((caddr_t) ret_block, future->rq_client, NULL, NULL, flush);
#endif
    CB_DONE;
    if (ret_type == DV_C_STRING)
      dk_free_box ((caddr_t) ret_box[0]);	 /* mty HUHTI */
    dk_free_box (ret_block[RRC_COND_NUMBER]);
    BOX_DONE (ret_block, ret_block_auto);
    dk_free_box_and_numbers ((caddr_t) ret_box); /* mty HUHTI */
  }
}


void
PrpcAnswerHead (du_thread_t * thr, int is_partial)
{
  USE_GLOBAL
  dk_thread_t * c_thread = (dk_thread_t *) thr->thr_client_data;
  future_request_t *future = c_thread->dkt_requests[c_thread->dkt_request_count - 1];
  dk_session_t *ses = future->rq_client;

  dks_array_head (ses, DA_ANSWER_LENGTH, DV_ARRAY_OF_POINTER);

  if (is_partial)
    print_int (DA_FUTURE_PARTIAL_ANSWER, ses);
  else
    print_int (DA_FUTURE_ANSWER, ses);
  print_int (future->rq_condition, ses);
  dks_array_head (ses, 1, DV_ARRAY_OF_POINTER);
}


void
PrpcAnswerTail (dk_session_t * ses, int flush)
{
  session_buffered_write_char (DV_NULL, ses);
  if (flush)
    session_flush_1 (ses);
}


/*##**********************************************************************
 *
 *      PrpcSetServiceRequestHook()
 *
 * This function sets a hook function which is called inside read_service_request.
 * The hook function gets two arguments, the session and the raw request and
 * has return value void.
 *
 *
 * Input params :
 *
 *      new_function      - The new hook function.

 *
 * Output params:
 *
 * Return value : The prior value of the hook
 *
 * Limitations  :
 *
 * Globals used : service_request_hook
 */
srv_req_hook_func
PrpcSetServiceRequestHook (srv_req_hook_func new_function)
{
  USE_GLOBAL
  srv_req_hook_func old = service_request_hook;
  service_request_hook = new_function;
  return (old);
}
#endif /* NO_THREAD */


/*##**********************************************************************
 *
 *      PrpcSetPartnerDeadHook
 *
 * This function sets the partner dead action for a session.
 * The hook function is called when this process finds that the
 * remote party has disconnected.
 *
 *
 * Input params :
 *
 *      session   - The session
 *      hook      - The new hook function.
 *
 *
 * Output params:
 *
 * Return value : The prior value of the hook
 *
 * Limitations  :
 *
 * Globals used : service_request_hook
 */
io_action_func
PrpcSetPartnerDeadHook (dk_session_t * ses, io_action_func new_function)
{
  io_action_func old = SESSION_SCH_DATA (ses)->sio_partner_dead_action;
  SESSION_SCH_DATA (ses)->sio_partner_dead_action = new_function;
  return (old);
}


sch_hook_func
PrpcSetSchedulerHook (sch_hook_func new_function)
{
  USE_GLOBAL
  sch_hook_func old = scheduler_hook;
  scheduler_hook = new_function;
  return (old);
}


/*
 *  A value of 0 means leaving it to the OS to sort out send/receive sizes
 */
int socket_buf_sz = 0;


#ifdef NOT
dk_thread_t *timeout_checker;
#endif


void
PrpcSessionFree (dk_session_t * ses)
{
  if (client_trace_flag)
    logit (L_DEBUG, "PrpcSessionFree called for %lx", ses);
  if (SESSION_SCH_DATA (ses) && SESSION_SCH_DATA (ses)->sio_is_served != -1)
    GPF_T1 ("can't free if in served sessions");
  if (ses->dks_is_server && ses->dks_n_threads > 0)
    GPF_T1 ("can't free if threads on the session");
#ifdef INPROCESS_CLIENT
  if (SESSION_IS_INPROCESS (ses))
    {
      /* dks_caller_id_opts is set by the client and should be
         freed by it as well. */
      dk_free_tree ((box_t) ses->dks_caller_id_opts);
      (*free_inprocess_session_p) (ses);
      return;
    }
#endif
#if 0
  if (ses->dks_session && SESCLASS_TCPIP == ses->dks_session->ses_class)
    {
      dk_session_clear (ses);
      if (resource_store (tcpses_rc, (void *) ses))
	return;
    }
#endif
  mutex_free (ses->dks_mtx);
  dk_free_box (ses->dks_peer_name);
  dk_free_box (ses->dks_own_name);
  dk_free_tree ((box_t) ses->dks_caller_id_opts);
  if (ses->dks_in_buffer)
    dk_free (ses->dks_in_buffer, ses->dks_in_length);
  if (ses->dks_out_buffer)
    dk_free (ses->dks_out_buffer, ses->dks_out_length);
  dk_free (SESSION_SCH_DATA (ses), sizeof (scheduler_io_data_t));
  session_free (ses->dks_session);
#ifdef NO_THREAD
  if (NULL != ses->dks_pending_futures)
    hash_table_free (ses->dks_pending_futures);
#endif
  dk_free (ses, sizeof (dk_session_t));
}


#ifndef NO_THREAD
dk_thread_t *
PrpcThreadAllocate (thread_init_func init, unsigned long stack_size, void *init_arg)
{
  du_thread_t *thr;
  dk_thread_t *dkt;

  thr = thread_create (init, stack_size, init_arg);
  if (!thr)
    return NULL;
  dkt = dk_thread_alloc ();
  thr->thr_client_data = dkt;
  dkt->dkt_process = thr;

  return dkt;
}


dk_thread_t *
PrpcThreadAttach (void)
{
  du_thread_t *thr;
  dk_thread_t *dkt;

  thr = thread_attach ();
  if (!thr)
    return NULL;
  dkt = dk_thread_alloc ();
  thr->thr_client_data = dkt;
  dkt->dkt_process = thr;

  return dkt;
}


void
PrpcThreadDetach (void)
{
  du_thread_t *thr = THREAD_CURRENT_THREAD;
  if (thr)
    {
      dk_thread_t *dkt = (dk_thread_t *) thr->thr_client_data;
      if (dkt)
	{
	  dk_thread_free (dkt);
	  thr->thr_client_data = NULL;
	}
      thread_exit (0);
    }
}


void
PrpcSetThreadParams (long srv_sz, long main_sz, long future_sz, int nmaxfutures)
{
  USE_GLOBAL
  server_thread_sz = srv_sz;
  main_thread_sz = main_sz;
  future_thread_sz = future_sz;
  max_future_threads = nmaxfutures;
}


dk_session_t *
PrpcFindPeer (char *name)
{
  USE_GLOBAL
  int n;

  for (n = 0; n < MAX_SESSIONS; n++)
    {
      if (served_sessions[n] && served_sessions[n]->dks_peer_name)
	{
	  if (0 == strcmp (name, served_sessions[n]->dks_peer_name) ||
	      0 == strcmp (name, served_sessions[n]->dks_own_name))
	    return (served_sessions[n]);
	}
    }
  return (NULL);
}


dk_set_t
PrpcListPeers (void)
{
  USE_GLOBAL
  dk_set_t list = NULL;
  int n;

  for (n = 0; n < MAX_SESSIONS; n++)
    {
      if (served_sessions[n])
	{
	  dk_set_push (&list, (void *) served_sessions[n]);
	}
    }
  return list;
}


void
PrpcRegisterService (char *name, server_func func, void *client_data, int ret_type, post_func postprocess)
{
  USE_GLOBAL
  service_t * new_sr = find_service (name);
  if (!new_sr)
    {
      new_sr = (service_t *) dk_alloc (sizeof (service_t));
      new_sr->sr_next = services;
      services = new_sr;
    }
  new_sr->sr_name = name;
  new_sr->sr_func = func;
  new_sr->sr_postprocess = postprocess;
  new_sr->sr_return_type = ret_type;
  new_sr->sr_client_data = client_data;
}


void
PrpcRegisterServiceDesc (service_desc_t * desc, server_func f)
{
  PrpcRegisterService (desc->sd_name, f, desc, desc->sd_return_type, NULL);
}


void
PrpcRegisterServiceDescPostProcess (service_desc_t * desc, server_func f, post_func postprocess)
{
  PrpcRegisterService (desc->sd_name, f, desc, desc->sd_return_type, postprocess);
}
#endif /* NO_THREAD */


void
PrpcProtocolInitialize (int sesclass)
{
  USE_GLOBAL
#ifndef NO_THREAD
  if (sesclass == SESCLASS_UDPIP)
    sesclass = SESCLASS_TCPIP;
  if (!protocols)
    protocols = hash_table_allocate (4);
  if (!gethash ((void *) (ptrlong) sesclass, protocols))
    {
#ifdef PMN_THREADS
      du_thread_t *server_process;
      server_process = thread_create (server_loop, server_thread_sz, (void *) (ptrlong) sesclass);

      sethash ((void *) (ptrlong) sesclass, protocols, (void *) server_process);
#else
      du_thread_t *server_process;
      server_process = process_allocate (server_thread_sz);

      server_process->thr_attributes = hash_table_allocate (11);

      process_set_init_function (server_process, (init_func) server_loop, (void *) sesclass);

      sethash ((void *) (ptrlong) sesclass, protocols, (void *) server_process);

      semaphore_leave (server_process->thr_sem);
#endif /* PMN_THREADS */
    }
#endif /* NO_THREAD */
}


#ifndef NO_THREAD

static long dks_n_housekeeping_sessions = 0;
int disable_listen_on_unix_sock = 0;
int disable_listen_on_tcp_sock = 0;

dk_session_t *
PrpcListen (char *addr, int sesclass)
{
  USE_GLOBAL
  dk_session_t * listening_session = NULL;

  dks_n_housekeeping_sessions++;
  dk_set_resource_usage ();
  PrpcProtocolInitialize (sesclass);
  if (!disable_listen_on_tcp_sock)
    {
      listening_session = dk_session_allocate (sesclass);
#ifdef COM_UDPIP
      if (sesclass == SESCLASS_UDPIP)
	SESSION_SCH_DATA (listening_session)->sio_default_read_ready_action = read_service_request;
      else
#endif
	SESSION_SCH_DATA (listening_session)->sio_default_read_ready_action = accept_client;

      if (SER_SUCC != session_set_address (listening_session->dks_session, addr))
	{
	  return listening_session;
	}
      SESSION_SCH_DATA (listening_session)->sio_reading_thread = (du_thread_t *) gethash ((void *) (ptrlong) sesclass, protocols);

      without_scheduling_tic ();
      session_listen (listening_session->dks_session);
      restore_scheduling_tic ();

      if (!SESSTAT_ISSET (listening_session->dks_session, SST_LISTENING))
	{
#ifdef PCTCP
	  int eno = WSAGetLastError ();
	  char message[255];
	  tcpses_error_message (eno, message, sizeof (message));
	  ss_dprintf_2 ((" error = %s(%d)", message, eno));
#else
	  perror ("Failed to start listening");
#endif
	  return (listening_session);
	}

      add_to_served_sessions (listening_session);
    }
  else
    {
      disable_listen_on_unix_sock = 0;		 /* if tcp listen is off, we make sure we have unix socket  */
    }
/*  if (! listening_address)
   listening_address = box_string (addr);
 */
  if (!disable_listen_on_unix_sock && sesclass == SESCLASS_TCPIP)
    {
      dk_session_t *unix_listening_session = tcpses_make_unix_session (addr);
      if (unix_listening_session)
	{
	  dks_n_housekeeping_sessions++;
	  SESSION_SCH_DATA (unix_listening_session)->sio_default_read_ready_action = accept_client;

	  SESSION_SCH_DATA (unix_listening_session)->sio_reading_thread = (du_thread_t *) gethash ((void *) (ptrlong) sesclass, protocols);

	  without_scheduling_tic ();
	  session_listen (unix_listening_session->dks_session);
	  restore_scheduling_tic ();

	  if (!SESSTAT_ISSET (unix_listening_session->dks_session, SST_LISTENING))
	    {
	      perror ("Failed to start listening");
	      return (unix_listening_session);
	    }

	  add_to_served_sessions (unix_listening_session);
	  if (disable_listen_on_tcp_sock)
	    listening_session = unix_listening_session;
	}
    }

  if (!i_am)
    i_am = box_string (addr);
  PrpcSelfSignalInit (addr);
  return (listening_session);
}


int
PrpcIsListen (dk_session_t * ses)
{
  return (SESSION_SCH_DATA (ses)->sio_default_read_ready_action == accept_client);
}


dk_mutex_t *sig_mtx;
basket_t sig_queue;


void
dk_self_signalled (dk_session_t * ses)
{
  self_signal_t *ss;
  CATCH_READ_FAIL (ses)
  {
    session_buffered_read_char (ses);
  }
  END_READ_FAIL (ses);
  for (;;)
    {
      mutex_enter (sig_mtx);
      ss = (self_signal_t *) basket_get (&sig_queue);
      mutex_leave (sig_mtx);
      ss->ss_func (ss->ss_cd);
      dk_free ((caddr_t) ss, sizeof (self_signal_t));
      if (ses->dks_in_fill > ses->dks_in_read)
	{
	  ses->dks_in_read++;
	  continue;
	}
      else
	break;
    }
}


dk_session_t *sig_session = NULL;
void
PrpcSelfSignal (self_signal_func f, caddr_t cd)
{
  NEW_VAR (self_signal_t, ss);
  ss->ss_func = f;
  ss->ss_cd = cd;
  mutex_enter (sig_mtx);
  basket_add (&sig_queue, (caddr_t) ss);
  mutex_leave (sig_mtx);
  mutex_enter (sig_session->dks_mtx);
  session_write (sig_session->dks_session, " ", 1);
  mutex_leave (sig_session->dks_mtx);
}


long
dks_housekeeping_session_count (void)
{
  return dks_n_housekeeping_sessions;
}


void
dks_housekeeping_session_count_change (int delta)
{
  dks_n_housekeeping_sessions += delta;
}


long
sf_signal_init ()
{
  dk_session_t *sig_listen = IMMEDIATE_CLIENT;
  SESSION_SCH_DATA (sig_listen)->sio_default_read_ready_action = (io_action_func) dk_self_signalled;
  thrs_printf ((thrs_fo, "ses %p thr:%p in sf_signal_init\n", sig_listen, THREAD_CURRENT_THREAD));
  return 0;
}


SERVICE_0 (s_self_signal_init, "_SSI", DA_FUTURE_REQUEST, DV_LONG_INT);

static dk_session_t *PrpcConnect2 (char *address, int sesclass, char *ssl_usage, char *pass, char *ca_list, int do_caller_id);

void
PrpcSelfSignalInit (char *addr)
{
  char addr2[100];
  static int initialized = 0;

  if (initialized)
    return;
  if (!strchr (addr, ':'))
    snprintf (addr2, sizeof (addr2), "localhost:%s", addr);
  else
    strcpy_ck (addr2, addr);
  initialized = 1;
  sig_session = PrpcConnect2 (addr2, SESCLASS_TCPIP, NULL, NULL, NULL, 0);
  if (!sig_session || !DKSESSTAT_ISSET (sig_session, SST_OK))
    {
      log_error ("Can listen but can't connect to self");
      call_exit (1);
    }
  PrpcRegisterServiceDesc (&s_self_signal_init, (server_func) sf_signal_init);
  PrpcSync (PrpcFuture (sig_session, &s_self_signal_init));
  sig_mtx = mutex_allocate ();
  remove_from_served_sessions (sig_session);
  dks_n_housekeeping_sessions += 2;
  prpc_self_signal_initialized = 1;
}


typedef struct co_req_s
{
  dk_session_t *r_dks;
  semaphore_t *r_sem;
  int r_is_dynamic;
} co_req_t;


void
check_out_server (co_req_t * req)
{
  remove_from_served_sessions (req->r_dks);
  thrs_printf ((thrs_fo, "ses %p in check_out_server1\n", req->r_dks));
  semaphore_leave (req->r_sem);
}


dk_set_t served_sessions_overflow = NULL;

void
check_in_server (co_req_t * req)
{
  int is_dynamic = req->r_is_dynamic;
  /* record r_is_dynamic before freeing the waiting thread since in the event of an
   * automatic req the r_is_dynamic will become undefined after the thread resumes  */
  if (-1 == add_to_served_sessions (req->r_dks))
    {
      log_error ("Exceeded maximum number of FD_SETSIZE inside check_in_server");
      PrpcDisconnect (req->r_dks);
      dk_set_push (&served_sessions_overflow, req->r_dks);
    }

  if (req->r_sem)
    semaphore_leave (req->r_sem);
  if (is_dynamic)
    dk_free ((caddr_t) req, sizeof (co_req_t));
}


void
PrpcCheckOut (dk_session_t * ses)
{
  semaphore_t *sem = THREAD_CURRENT_THREAD->thr_sem;
  co_req_t r;
  r.r_dks = ses;
  r.r_sem = sem;
  r.r_is_dynamic = 0;
  thrs_printf ((thrs_fo, "ses %p thr:%p in PrpcCheckOut1\n", ses, THREAD_CURRENT_THREAD));
  PrpcSelfSignal ((self_signal_func) check_out_server, (caddr_t) & r);
  semaphore_enter (sem);
  thrs_printf ((thrs_fo, "ses %p thr:%p in PrpcCheckOut2\n", ses, THREAD_CURRENT_THREAD));
}


void
PrpcCheckIn (dk_session_t * ses)
{
  semaphore_t *sem = THREAD_CURRENT_THREAD->thr_sem;
  co_req_t r;
  r.r_dks = ses;
  r.r_sem = sem;
  r.r_is_dynamic = 0;
  PrpcSelfSignal ((self_signal_func) check_in_server, (caddr_t) & r);
  semaphore_enter (sem);
}


void
PrpcCheckInAsync (dk_session_t * ses)
{
  NEW_VARZ (co_req_t, r);
  r->r_dks = ses;
  r->r_is_dynamic = 1;
  PrpcSelfSignal ((self_signal_func) check_in_server, (caddr_t) r);
}
#endif /* NO_THREAD */


char *
PrpcIAm (char *name)
{
  USE_GLOBAL
  if (name)
    {
      if (i_am)
	dk_free_box (i_am);
      i_am = box_string (name);
    }
  return (i_am);
}


#ifdef NOT					 /*PREEMPT, formerly */
void
timeout_round_loop ()
{
  while (1)
    {
      timeout_round (PASS_G NULL);
      process_sleep (&atomic_timeout);
    }
}
#endif


#ifndef NO_THREAD
static caddr_t (*caller_id_server_hook) (void) = NULL;

void
PrpcSetCallerIDServerHook (caddr_t (*f) (void))
{
  caller_id_server_hook = f;
}


/*##**********************************************************************
 *
 *              sf_caller_identification
 *
 * A connecting client uses this to identify itself to the server.
 * The client gives its name. if any as argument. This returns
 * two strings: The server's name and the client's name.
 *
 * Input params :
 *
 *      name    - The client's name. NULL if the client does not have a name.
 *
 * Return value :  An array of 2 strings: The server's name and the
 *          client's name.
 */
static caddr_t *
sf_caller_identification (char *name)
{
  int tmp_len;
  time_t tim;
  USE_GLOBAL
  char buffer[100];
  caddr_t *ret = (caddr_t *) dk_alloc_box ((caller_id_server_hook ? 3 : 2) * sizeof (caddr_t),
      DV_ARRAY_OF_POINTER);
  dk_session_t *client = IMMEDIATE_CLIENT;

  ss_dprintf_2 (("caller_identification: %s /n", name));
  client->dks_own_name = box_dv_short_string (i_am);
  if (!name)
    {
      snprintf (buffer, sizeof (buffer), "%s:%ld", i_am, ++connection_count);
    }
  else
    {
      snprintf (buffer, sizeof (buffer), "%s:-%ld", name, ++connection_count);
      dk_free_box (name);
    }
  time (&tim);
  tmp_len = (int) strlen (buffer);
  snprintf (&buffer[tmp_len], sizeof (buffer) - tmp_len, " %ld", (long) tim);
  name = box_dv_short_string (buffer);
  name[tmp_len] = 0;
  client->dks_peer_name = name;
  ret[0] = box_string (i_am);
  ret[1] = box_copy (name);
  ret[2] = caller_id_server_hook ();
  thrs_printf ((thrs_fo, "ses %p thr:%p in sf_caller_id\n", client, THREAD_CURRENT_THREAD));
  DKST_RPC_DONE (client);
  return (ret);
}
#endif /* NO_THREAD */

#if !defined (NO_THREAD)			 /*&& defined (WIN32) */
LOG *virtuoso_log = NULL;
LOG *stderr_log = NULL;
unsigned long log_file_line = 0;

/* the logging queue & threads */
basket_t log_bsk;
dk_mutex_t *log_queue_mtx;
du_thread_t *log_worker_thr;
typedef struct log_queue_elt_s
{
  FILE *fp;
  char buf[8196];
} log_queue_elt_t;

static void
log_worker_func (void *param)
{
  log_queue_elt_t *elt;

  log_worker_thr = THREAD_CURRENT_THREAD;
  semaphore_enter (log_worker_thr->thr_sem);
  for (;;)
    {

      mutex_enter (log_queue_mtx);
      elt = (log_queue_elt_t *) basket_get (&log_bsk);
      if (!elt)
	{
	  mutex_leave (log_queue_mtx);
	  semaphore_enter (log_worker_thr->thr_sem);
	  continue;
	}
      else
	mutex_leave (log_queue_mtx);

      if (elt->fp)
	{
	  fputs (elt->buf, elt->fp);
	  fflush (elt->fp);
	}
      free (elt);
    }
}


void
log_queue_add_msg (LOG * log, int level, char *buf)
{
  log_queue_elt_t *elt = (log_queue_elt_t *) malloc (sizeof (log_queue_elt_t));
  memset (elt, 0, sizeof (log_queue_elt_t));
  elt->fp = (FILE *) log->user_data;
  strncpy (elt->buf, buf, sizeof (elt->buf));
  elt->buf[sizeof (elt->buf) - 1] = 0;


  mutex_enter (log_queue_mtx);
  basket_add (&log_bsk, elt);
  mutex_leave (log_queue_mtx);

  semaphore_leave (log_worker_thr->thr_sem);
}


void
log_thread_initialize ()
{
  if (!virtuoso_log || !stderr_log || (log_file_line & 0x1) == 0)	/*if no logs then do not use a thread */
    return;
  log_queue_mtx = mutex_allocate ();
  log_worker_thr = PrpcThreadAllocate ((init_func) log_worker_func, 100000, NULL)->dkt_process;
  virtuoso_log->emitter = log_queue_add_msg;
  stderr_log->emitter = log_queue_add_msg;
}
#endif

#ifndef NO_THREAD
void PrpcRegisterServiceDescPostProcess (service_desc_t * desc, server_func f, post_func postprocess);
#endif

SERVICE_1 (s_caller_identification, _sci, "caller_identification", DA_FUTURE_REQUEST, DV_ARRAY_OF_POINTER, DV_C_STRING, 1);

#ifndef NO_THREAD
extern char *build_thread_model;
#endif

void
PrpcInitialize (void)
{
#ifndef NO_THREAD
  PrpcInitialize1 (DK_ALLOC_RESERVE_PREPARED);
#else
  PrpcInitialize1 (DK_ALLOC_RESERVE_DISABLED);
#endif
}


int enable_malloc_cache = 1;

void
PrpcInitialize1 (int mem_mode)
{
  USE_GLOBAL
#if (!defined (PREEMPT) && !defined (NO_THREAD)) || (defined (PMN_THREADS) && !defined (NO_THREAD))
  int zero = 0;
#endif

  if (prpcinitialized)
    return;

#if defined (WINDOWS) && !defined (NO_THREAD)
  if (!main_thread_sz)
    {
      printf ("Call PrpcSetThreadParams before PrpcInitialize. Unpredictable behavior will follow.\n");
      PrpcSetThreadParams (5000, 5000, 5000, 1);
    }
#endif

  prpcinitialized = 1;

#ifndef PMN_NMARSH
  write_in_session = srv_write_in_session;
#endif

  du_thread_init (main_thread_sz);

  dk_memory_initialize (
#ifndef NO_THREAD
			enable_malloc_cache
#else
      0
#endif
      );

  free_threads = resource_allocate (MAX_THREADS, (rc_constr_t) NULL, (rc_destr_t) NULL, (rc_destr_t) NULL, 0);
  resource_no_sem (free_threads);
  tcpses_rc = resource_allocate (50, (rc_constr_t) NULL, (rc_destr_t) NULL, (rc_destr_t) NULL, 0);

#ifndef NO_THREAD
  pending_futures = hash_table_allocate (201);
#endif

  value_mtx = mutex_allocate ();
  thread_mtx = mutex_allocate ();
  mutex_option (thread_mtx, "THREAD_MTX", NULL, NULL);

#ifdef PCTCP
  init_pctcp ();
#endif

#ifdef PMN_THREADS
# ifndef NO_THREAD
  if (!_thread_sched_preempt)
    session_set_default_control (SC_BLOCKING, (char *) (&zero), sizeof (int));
# endif

#else
# if !defined (PREEMPT) && !defined (NO_THREAD)
  session_set_default_control (SC_BLOCKING, (char *) (&zero), sizeof (int));
# endif
#endif

  session_set_default_control (SC_MSGLEN, (char *) (&socket_buf_sz), sizeof (int));

#ifdef PMN_THREADS
  {
    dk_thread_t *dkt = dk_thread_alloc ();
    du_thread_t *thr = thread_current ();
    thr->thr_client_data = dkt;
    dkt->dkt_process = thr;
  }
#else
  process_futures_initialize (initial_process);

  start_scheduler ();
#endif

  init_readtable ();

#ifndef NO_DK_ALLOC_RESERVE
  dk_alloc_reserve_maxthreads = max_future_threads;
  dk_alloc_set_reserve_mode (mem_mode);
#endif

#ifndef NO_THREAD
  PrpcRegisterServiceDescPostProcess (&s_caller_identification, (server_func) sf_caller_identification, (post_func) dk_free_tree);
# ifdef INPROCESS_CLIENT
  PrpcRegisterServiceDescPostProcess (&s_inprocess_ep, (server_func) sf_inprocess_ep, (post_func) dk_free_tree);
# endif

  if (0 == strcmp (build_thread_model, "-fibers"))
    {
      prpc_disable_burst_mode = 1;
      thrs_printf ((thrs_fo, "disable burst mode\n"));
    }
#endif

#ifdef NOT					 /*PREEMPT, formerly */
/* Start the timeout checker */
  timeout_checker = PrpcThreadAllocate (6000);
  process_set_init_function (timeout_checker->dkt_process, (init_func) timeout_round_loop, 0);
  process_futures_initialize (timeout_checker->dkt_process);
  semaphore_leave (timeout_checker->dkt_process->thr_sem);
#endif

#ifdef _SSL
  ssl_server_init ();
#endif
}


/*
   Writes a future request. Allocates and returns the matching future object.
   Registers the request number into the pending_futures table.
 */
future_t *
PrpcFuture (dk_session_t * server, service_desc_t * service, ...)
{
  USE_GLOBAL
  future_t * future;
  ptrlong **request_v;
  caddr_t *argv;
  va_list ap;
  int n;

  future = (future_t *) dk_alloc (sizeof (future_t));
  memset (future, 0, sizeof (future_t));
  future->ft_server = server;
  future->ft_service = service;

  IN_VALUE;
  future->ft_request_no = last_future++;
  sethash ((void *) (ptrlong) future->ft_request_no, PENDING_FUTURES (server), (void *) future);
  LEAVE_VALUE;

  va_start (ap, service);
  argv = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * service->sd_arg_count, DV_ARRAY_OF_POINTER);

  for (n = 0; n < service->sd_arg_count; n++)
    {
      switch (service->sd_arg_types[n])
	{
#if defined (macintosh) || \
    defined (__FreeBSD__) || \
    defined (__bsdi__) || \
    (defined (__sgi) && defined (_ABIO32)) || \
    (defined (DGUX) && defined (m88k)) || \
    (defined (linux) && defined (__powerpc)) || \
    (defined (linux) && defined (__ia64)) || \
    (defined (linux) && __GLIBC__ >=2 && __GLIBC_MINOR__ >= 2) || \
    (__GNUC__ >= 3) || \
    defined (__STACK_ALIGN)
	case DV_SHORT_INT:
	case DV_CHARACTER:
	  argv[n] = (caddr_t) box_num (va_arg (ap, int));
	  break;
#else
	case DV_SHORT_INT:
	  argv[n] = (caddr_t) box_num (va_arg (ap, short));
	  break;

	case DV_CHARACTER:
	  argv[n] = (caddr_t) box_num (va_arg (ap, char));
	  break;
#endif
	case DV_LONG_INT:
	  argv[n] = (caddr_t) box_num (va_arg (ap, long));
	  break;

	case DV_C_STRING:
	  argv[n] = (caddr_t) box_string (va_arg (ap, char *));
	  break;

	case DV_SINGLE_FLOAT:
	  argv[n] = (caddr_t) box_float (*va_arg (ap, float *));
	  break;

	case DV_DOUBLE_FLOAT:
	  argv[n] = (caddr_t) box_double (*va_arg (ap, double *));
	  break;

	default:
	  argv[n] = (caddr_t) va_arg (ap, void *);
	}
    }

  request_v = (ptrlong **) dk_alloc_box (sizeof (caddr_t *) * DA_FRQ_LENGTH, DV_ARRAY_OF_POINTER);

  if (service->sd_type == DA_DIRECT_IO_FUTURE_REQUEST)
    {
      request_v[DA_MESSAGE_TYPE] = (ptrlong *) (ptrlong) DA_DIRECT_IO_FUTURE_REQUEST;
      SESSION_CHECK_OUT (server);
    }
  else
    request_v[DA_MESSAGE_TYPE] = (ptrlong *) (ptrlong) DA_FUTURE_REQUEST;

  request_v[FRQ_COND_NUMBER] = (ptrlong *) box_num (future->ft_request_no);
  request_v[FRQ_ANCESTRY] = NULL;
  request_v[FRQ_SERVICE_NAME] = (ptrlong *) box_string (service->sd_name);

  request_v[FRQ_ARGUMENTS] = (ptrlong *) argv;
  CB_PREPARE
#if defined(INPROCESS_CLIENT)			 /*&& !defined(NO_THREAD) */
      if (SESSION_IS_INPROCESS (server))
    {
# ifdef INPROCESS_NO_THREAD
      while (inpses_unread_data (server))
	read_service_request (server);
# endif
# ifdef USE_DYNAMIC_LOADER
      do_inprocess_request (PASS_G server, request_v);
# else
      (*do_inprocess_request_p) (PASS_G server, (caddr_t *) request_v);
#endif
    }
  else
#endif
    {
#ifdef PMN_NMARSH
      srv_write_in_session (request_v, server, 1);
#else
      write_in_session ((caddr_t) request_v, server, NULL, NULL, 1);
#endif
    }
  CB_DONE;

  dk_free_box_and_numbers ((box_t) argv);
  dk_free_box ((caddr_t) request_v[FRQ_COND_NUMBER]);
  dk_free_box ((caddr_t) request_v[FRQ_SERVICE_NAME]);
  dk_free_box ((box_t) request_v);

  return (future);
}


/*
 * Address the case of multiple answers. Free the queue
 * Remove the future from the futures hash too.
 */
void
PrpcFutureFree (future_t * future)
{
  USE_GLOBAL

  /* MAALIS mty needed for futures, which are not waited for */
  IN_VALUE;
  remhash ((void *) (ptrlong) future->ft_request_no, PENDING_FUTURES (future->ft_server));

  switch (future->ft_is_ready)
    {
    case FS_SINGLE_COMPLETE:
      dk_free_box_and_numbers (future->ft_result);
      break;

    case FS_RESULT_LIST:
    case FS_RESULT_LIST_COMPLETE:
      DO_SET (caddr_t, elt, ((dk_set_t *) & future->ft_result))
      {
	dk_free_tree (elt);
      }
      END_DO_SET ();
      dk_set_free ((dk_set_t) future->ft_result);
    }

  dk_free (future, sizeof (future_t));
  LEAVE_VALUE;
}


future_t *
PrpcFutureSetTimeout (future_t * future, long msecs)
{
  USE_GLOBAL
  timeout_t time;

  get_real_time (&time);

  future->ft_timeout.to_sec = msecs / 1000;
  future->ft_timeout.to_usec = (msecs % 1000) * 1000;
  future->ft_time_issued.to_sec = time.to_sec;
  future->ft_time_issued.to_usec = time.to_usec;
  future->ft_server->dks_read_block_timeout = future->ft_timeout;	/* if hangs in mid-message for longer than timeout, then assume broken connection */
  return (future);
}


void
PrpcSessionResetTimeout (dk_session_t * ses)
{
  if (ses)
    ses->dks_read_block_timeout.to_sec = 10000;
}


#ifdef INPROCESS_CLIENT
# define IS_SESINP(ses) SESSION_IS_INPROCESS(ses)
#else
# define IS_SESINP(ses) 0
#endif


#define FT_CHECK_TIMEOUT_1T(ft) \
  if (!IS_SESINP (ft->ft_server) \
      && !bytes_in_read_buffer (ft->ft_server) \
      && (ft->ft_timeout.to_sec || ft->ft_timeout.to_usec)) { \
    tcpses_is_read_ready (ft->ft_server->dks_session, &ft->ft_timeout); \
    if (SESSTAT_ISSET (ft->ft_server->dks_session, SST_TIMED_OUT)) { \
     SESSTAT_CLR (ft->ft_server->dks_session, SST_TIMED_OUT); \
     ft->ft_error = (caddr_t) (long) FE_TIMED_OUT; \
     call_service_cancel (ft->ft_server); \
     return NULL; \
   } \
 }


/*  PrpcValueOrWait ()

   Returns the value of the future if the answer is here.
   If not, blocks the calling thread.
   Differs from future_next_result() in that this function
   always returns the same value when called multiple times.
 */
caddr_t
PrpcValueOrWait1T (future_t * future)
{
  USE_GLOBAL
  caddr_t result;
#ifdef NO_THREAD
again:
#endif
  IN_VALUE;
  switch (future->ft_is_ready)
    {
    case FS_SINGLE_COMPLETE:
      result = FUTURE_RESULT_FIRST (future->ft_result);
      LEAVE_VALUE;
      return result;

    case FS_FALSE:
      LEAVE_VALUE;
      FT_CHECK_TIMEOUT_1T (future);
      read_service_request (future->ft_server);

      if (DKSESSTAT_ISSET (future->ft_server, SST_NOT_OK))
	{
	  future->ft_error = (caddr_t) (long) FE_TIMED_OUT;
	  return NULL;
	}
      if (future->ft_error)
	return NULL;
      else
#ifdef NO_THREAD
	goto again;
#else
	return PrpcValueOrWait (future);
#endif

    case FS_RESULT_LIST:
    case FS_RESULT_LIST_COMPLETE:
      /* In this case there is an error in the application.
         future_next_result should have been used as more than
         one value may be coming. */
      if (FUTURE_IS_EXHAUSTED (future))
	result = NULL;
      else
	result = FUTURE_RESULT_FIRST (DK_SET_FIRST (&(future->ft_result)));
      LEAVE_VALUE;
      return result;
    }

  return NULL;
}


caddr_t
PrpcValueOrWait (future_t * future)
{
#ifdef NO_THREAD
  return PrpcValueOrWait1T (future);
#else
# ifdef INPROCESS_CLIENT
  if (SESSION_IS_INPROCESS (future->ft_server))
    return PrpcValueOrWait1T (future);
# endif
  {
    USE_GLOBAL
    caddr_t result;

    IN_VALUE;
    switch (future->ft_is_ready)
      {
      case FS_SINGLE_COMPLETE:
	result = FUTURE_RESULT_FIRST (future->ft_result);
	LEAVE_VALUE;
	return result;

      case FS_FALSE:
	{
	  dk_thread_t *c_thread;
	  future_request_t *request;

	  if (DKSESSTAT_ISSET (future->ft_server, SST_NOT_OK))
	    {
	      future->ft_error = (caddr_t) (long) FE_TIMED_OUT;
	      LEAVE_VALUE;
	      call_service_cancel (future->ft_server);
	      return NULL;
	    }
	  c_thread = DK_CURRENT_THREAD;
	  if (!c_thread || 0 == c_thread->dkt_request_count)
	    {
	      LEAVE_VALUE;
	      return (PrpcValueOrWait1T (future));
	    }

	  request = c_thread->dkt_requests[c_thread->dkt_request_count - 1];

	  request->rq_next_waiting = future->ft_waiting_requests;
	  future->ft_waiting_requests = request;

	  LEAVE_VALUE;
	  semaphore_enter (current_process->thr_sem);
	  if (future->ft_error)
	    return NULL;
	  else
	    return PrpcValueOrWait (future);
	}

      case FS_RESULT_LIST:
      case FS_RESULT_LIST_COMPLETE:
	/* In this case there is an error in the application.
	   future_next_result should have been used as more than
	   one value may be coming. */
	if (FUTURE_IS_EXHAUSTED (future))
	  result = NULL;
	else
	  result = FUTURE_RESULT_FIRST (DK_SET_FIRST (&(future->ft_result)));
	LEAVE_VALUE;
	return result;
      }

    return NULL;
  }
#endif
}


/*  PrpcFutureNextResult ()

   Like value_or_wait
   Returns the value of the last answer if there is one.
   If not, blocks the calling thread.
 */
caddr_t
PrpcFutureNextResult (future_t * future)
{
#ifdef NO_THREAD
  return PrpcFutureNextResult1T (future);

#else
# ifdef INPROCESS_CLIENT
  if (SESSION_IS_INPROCESS (future->ft_server))
    return PrpcFutureNextResult1T (future);
# endif
  {
    USE_GLOBAL
    caddr_t result;

    IN_VALUE;
    switch (future->ft_is_ready)
      {
      case FS_SINGLE_COMPLETE:
	result = FUTURE_RESULT_FIRST (future->ft_result);
	future->ft_result = NULL;
	future->ft_is_ready = FS_RESULT_LIST_COMPLETE;
	LEAVE_VALUE;
	return result;

      case FS_RESULT_LIST_COMPLETE:
	if (FUTURE_IS_NEXT_RESULT (future))
	  {
	    caddr_t r_box = (caddr_t) dk_set_pop ((dk_set_t *) & (future->ft_result));
	    result = FUTURE_RESULT_FIRST (r_box);
	    dk_free_box_and_numbers (r_box);
	    LEAVE_VALUE;
	    return result;
	  }
	LEAVE_VALUE;
	return NULL;

      case FS_RESULT_LIST:
	if (FUTURE_IS_NEXT_RESULT (future))
	  {
	    caddr_t r_box = (caddr_t) dk_set_pop (((dk_set_t *) & future->ft_result));
	    result = FUTURE_RESULT_FIRST (r_box);
	    dk_free_box_and_numbers (r_box);
	    LEAVE_VALUE;
	    return result;
	  }
	/* If no result is ready fall through to the next case to wait. */

      case FS_FALSE:
	{
	  dk_thread_t *c_thread = DK_CURRENT_THREAD;
	  future_request_t *request;
	  if (!c_thread || 0 == c_thread->dkt_request_count)
	    {
	      LEAVE_VALUE;
	      return PrpcFutureNextResult1T (future);
	    }
	  if (DKSESSTAT_ISSET (future->ft_server, SST_NOT_OK))
	    {
	      LEAVE_VALUE;
	      call_service_cancel (future->ft_server);
	      future->ft_error = (caddr_t) (long) FE_TIMED_OUT;
	      return NULL;
	    }
	  request = c_thread->dkt_requests[c_thread->dkt_request_count - 1];
	  request->rq_next_waiting = future->ft_waiting_requests;
	  future->ft_waiting_requests = request;
	  LEAVE_VALUE;
	  semaphore_enter (current_process->thr_sem);
	  if (future->ft_error)
	    return NULL;
	  else
	    return PrpcFutureNextResult (future);
	}
	break;
      }
    return NULL;
  }
#endif
}


int
PrpcFutureIsResult (future_t * future)
{
#ifdef NO_THREAD
  timeout_t zero_timeout = { 0, 0 };
#endif
  IN_VALUE;
  if (future->ft_result)
    {
      LEAVE_VALUE;
      return 1;
    }
  LEAVE_VALUE;
#ifdef NO_THREAD
  if (!bytes_in_read_buffer (future->ft_server))
    {
      tcpses_is_read_ready (future->ft_server->dks_session, &zero_timeout);
      if (SESSTAT_ISSET (future->ft_server->dks_session, SST_TIMED_OUT))
	{
	  SESSTAT_CLR (future->ft_server->dks_session, SST_TIMED_OUT);
	  return 0;
	}
    }

  read_service_request (future->ft_server);
#else
  PROCESS_ALLOW_SCHEDULE ();
#endif
  if (future->ft_result)
    return 1;
  return 0;
}


caddr_t
PrpcSync (future_t * f)
{
  if (f)
    {
      caddr_t r = PrpcValueOrWait (f);
      PrpcFutureFree (f);
      return (r);
    }
  return NULL;
}


static caddr_t
PrpcFutureNextResult1T (future_t * future)
{
  USE_GLOBAL
  caddr_t result;

again:
  IN_VALUE;
  switch (future->ft_is_ready)
    {
    case FS_SINGLE_COMPLETE:
      result = FUTURE_RESULT_FIRST (future->ft_result);
      future->ft_result = NULL;
      future->ft_is_ready = FS_RESULT_LIST_COMPLETE;
      LEAVE_VALUE;
      return result;

    case FS_RESULT_LIST_COMPLETE:
      if (FUTURE_IS_NEXT_RESULT (future))
	{
	  caddr_t r_box = (caddr_t) dk_set_pop ((dk_set_t *) & (future->ft_result));
	  result = FUTURE_RESULT_FIRST (r_box);
	  dk_free_box_and_numbers (r_box);
	  LEAVE_VALUE;
	  return result;
	}
      LEAVE_VALUE;
      return NULL;

    case FS_RESULT_LIST:
      if (FUTURE_IS_NEXT_RESULT (future))
	{
	  caddr_t r_box = (caddr_t) dk_set_pop (((dk_set_t *) & future->ft_result));
	  result = FUTURE_RESULT_FIRST (r_box);
	  dk_free_box_and_numbers (r_box);
	  LEAVE_VALUE;
	  return result;
	}
      /* If no result is ready fall through to the next case to wait. */

    case FS_FALSE:
      LEAVE_VALUE;
      FT_CHECK_TIMEOUT_1T (future);
      read_service_request (future->ft_server);
      if (future->ft_error)
	return (NULL);
      goto again;
    }

  return NULL;
}


#ifdef _SSL
int ssl_client_use_pkcs12 (SSL * ssl, char *pkcs12file, char *passwd, char *ca);
#endif

static dk_session_t *
PrpcConnect2 (char *address, int sesclass, char *ssl_usage, char *pass, char *ca_list, int do_caller_id)
{
  USE_GLOBAL
  int rc;
  caddr_t *ret;
  dk_session_t *session = NULL;
  int use_ssl = ssl_usage && strlen (ssl_usage) > 0;
  char *pkcs12_file = ssl_usage && strlen (ssl_usage) > 0 && atoi (ssl_usage) == 0 ? ssl_usage : NULL;

  if (sesclass == SESCLASS_TCPIP && !use_ssl)
    {						 /* try UNIX sockets */
      session = tcpses_make_unix_session (address);

      if (session)
	{
	  without_scheduling_tic ();
	  rc = session_connect (session->dks_session);
	  restore_scheduling_tic ();

	  if (rc != SER_SUCC)
	    {
	      PrpcSessionFree (session);
	      session = NULL;
	    }
	}
    }
  if (!session)
    {
      session = dk_session_allocate (sesclass);
      PrpcProtocolInitialize (sesclass);
      PrpcSessionResetTimeout (session);
      rc = session_set_address (session->dks_session, address);
      if (rc != SER_SUCC)
	return session;

      without_scheduling_tic ();
      rc = session_connect (session->dks_session);
      restore_scheduling_tic ();

      if (rc != SER_SUCC)
	return (session);

#ifdef _SSL
      if (use_ssl)
	{
	  SSL *ssl = NULL;
	  int ssl_err = 0;
	  int dst = tcpses_get_fd (session->dks_session);
	  const SSL_METHOD *ssl_method = SSLv23_client_method ();
	  SSL_CTX *ssl_ctx = SSL_CTX_new (ssl_method);
	  ssl = SSL_new (ssl_ctx);
	  SSL_set_fd (ssl, dst);
	  if (pkcs12_file)
	    {
	      int session_id_context = 12;
	      if (!ssl_client_use_pkcs12 (ssl, pkcs12_file, pass, ca_list))
		{
		  SSL_free (ssl);
		  SSL_CTX_free (ssl_ctx);
		  SESSTAT_CLR (session->dks_session, SST_OK);
		  SESSTAT_SET (session->dks_session, SST_BROKEN_CONNECTION);
		  return session;
		}

	      SSL_set_verify (ssl, SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT | SSL_VERIFY_CLIENT_ONCE, NULL);
	      SSL_set_verify_depth (ssl, -1);
	      SSL_CTX_set_session_id_context (ssl_ctx, (unsigned char *) &session_id_context, sizeof session_id_context);
	    }
	  else if (ca_list)
	    {
	      int session_id_context = 12;
	      if (SSL_CTX_load_verify_locations (ssl_ctx, ca_list, NULL) <= 0)
		{
		  SSL_free (ssl);
		  SSL_CTX_free (ssl_ctx);
		  SESSTAT_CLR (session->dks_session, SST_OK);
		  SESSTAT_SET (session->dks_session, SST_BROKEN_CONNECTION);
		  return session;
		}
#if 0
	      SSL_set_verify (ssl, SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT | SSL_VERIFY_CLIENT_ONCE, NULL);
	      SSL_set_verify_depth (ssl, -1);
#endif
	      SSL_CTX_set_session_id_context (ssl_ctx, (unsigned char *) &session_id_context, sizeof session_id_context);
	    }

	  ssl_err = SSL_connect (ssl);
	  if (ssl_err != 1)
	    {
	      SSL_free (ssl);
	      SSL_CTX_free (ssl_ctx);
	      SESSTAT_CLR (session->dks_session, SST_OK);
	      SESSTAT_SET (session->dks_session, SST_BROKEN_CONNECTION);
	      return session;
	    }
	  else
	    tcpses_to_sslses (session->dks_session, ssl);
	}
#endif
    }

#ifdef NO_THREAD
  session->dks_pending_futures = hash_table_allocate (21);
#endif

  SESSION_SCH_DATA (session)->sio_default_read_ready_action = read_service_request;
  SESSION_SCH_DATA (session)->sio_random_read_ready_action = NULL;
  SESSION_SCH_DATA (session)->sio_random_write_ready_action = NULL;

  add_to_served_sessions (session);

  if (sesclass != SESCLASS_UDPIP && do_caller_id)
    {
      ret = (caddr_t *) PrpcSync (PrpcFuture (session, &s_caller_identification, i_am));
      if (ret)
	{
	  session->dks_peer_name = box_copy (ret[0]);
	  session->dks_own_name = box_copy (ret[1]);
	  if (BOX_ELEMENTS (ret) > 2)
	    session->dks_caller_id_opts = (caddr_t *) box_copy_tree (ret[2]);
	  else
	    session->dks_caller_id_opts = NULL;
	  if (!i_am)
	    i_am = box_dv_short_string (ret[1]);
	  dk_free_tree ((box_t) ret);
	}
      else
	{
	  /* died in connect handshake or such */
	  session->dks_peer_name = box_dv_short_string ("<failed connect>");
	  session->dks_own_name = box_dv_short_string ("<failed connect>");
	  session->dks_caller_id_opts = NULL;
	}
    }
  return (session);
}


dk_session_t *
PrpcConnect1 (char *address, int sesclass, char *ssl_usage, char *pass, char *ca_list)
{
  return PrpcConnect2 (address, sesclass, ssl_usage, pass, ca_list, 1);
}


dk_session_t *
PrpcConnect (char *address, int sesclass)
{
  return PrpcConnect1 (address, sesclass, NULL, NULL, NULL);
}


#ifdef INPROCESS_CLIENT

#ifndef USE_DYNAMIC_LOADER
static char *inprocess_address = NULL;

static int
init_inprocess_entry_points (char *address)
{
  int rc;
  caddr_t *ret;
  dk_session_t *session;

  if (do_inprocess_request_p != NULL)
    {
      if (strcmp (address, inprocess_address) != 0)
	return -1;
      return 0;
    }
  inprocess_address = strdup (address);

  session = dk_session_allocate (SESCLASS_TCPIP);
  PrpcProtocolInitialize (SESCLASS_TCPIP);
  PrpcSessionResetTimeout (session);
  rc = session_set_address (session->dks_session, address);
  if (rc != SER_SUCC)
    {
      session_disconnect (session->dks_session);
      PrpcSessionFree (session);
      return -1;
    }

  without_scheduling_tic ();
  rc = session_connect (session->dks_session);
  restore_scheduling_tic ();

  if (rc != SER_SUCC)
    {
      session_disconnect (session->dks_session);
      PrpcSessionFree (session);
      return -1;
    }

  SESSION_SCH_DATA (session)->sio_default_read_ready_action = read_service_request;
  SESSION_SCH_DATA (session)->sio_random_read_ready_action = NULL;
  SESSION_SCH_DATA (session)->sio_random_write_ready_action = NULL;

  add_to_served_sessions (session);
  ret = (caddr_t *) PrpcSync (PrpcFuture (session, &s_inprocess_ep));
  remove_from_served_sessions (session);

  session_disconnect (session->dks_session);
  PrpcSessionFree (session);

  rc = -1;
  if (ret && (box_length (ret) / sizeof (caddr_t)) >= 5)
    {
      /* disable pid check for now because it fails on linux where
         different threads in the same process have different pids. */
#if 0
      int pid = (int) ret[0];
      if (pid == getpid ())
#endif
	{
	  make_inprocess_session_p = (dk_session_t * (*)())ret[1];
	  free_inprocess_session_p = (void (*)(dk_session_t *)) ret[2];
	  do_inprocess_request_p = (void (*)(TAKE_G dk_session_t *, caddr_t *)) ret[3];
	  rc = 0;
	}
    }
  dk_free_tree ((box_t) ret);

  return rc;
}
#endif /* USE_DYNAMIC_LOADER */

dk_session_t *
PrpcInprocessConnect (char *address)
{
#ifndef USE_DYNAMIC_LOADER
  if (init_inprocess_entry_points (address) < 0)
    return NULL;
  return (*make_inprocess_session_p) ();
#else
  return make_inprocess_session ();
#endif
}
#endif /* INPROCESS_CLIENT */

void
PrpcDisconnect (dk_session_t * session)
{
#ifdef INPROCESS_CLIENT
  if (SESSION_IS_INPROCESS (session))
    return;
#endif
  remove_from_served_sessions (session);
  session_disconnect (session->dks_session);
}


void
PrpcDisconnectAll ()
{
  USE_GLOBAL
  int i;
  for (i = 0; i < MAX_SESSIONS; i++)
    {
      if (served_sessions[i])
	PrpcDisconnect (served_sessions[i]);
    }
}


#define TIMEOUT_TO_MILLISECONDS(timeout) \
	(timeout.to_sec * 1000 + timeout.to_usec / 1000);

#define SET_TIMEOUT_TO_MILLISECONDS(timeout, milliseconds) \
	(timeout.to_sec = (milliseconds / 1000), \
	 timeout.to_usec =  (milliseconds % 1000));


long
PrpcSetTimeoutResolution (long milliseconds)
{
  USE_GLOBAL
  long old = TIMEOUT_TO_MILLISECONDS (atomic_timeout);

  SET_TIMEOUT_TO_MILLISECONDS (atomic_timeout, milliseconds);
  return (old);
}


void
PrpcSetBackgroundAction (background_action_func f)
{
  USE_GLOBAL
  background_action = f;
}


void
PrpcLeave (void)
{
}


#ifdef SUNRPC
extern int sun_rpc_pending;
extern fd_set svc_fdset;
extern void svc_run_3 (timeout_t * to);

static dk_thread_t *sun_rpc_thread;


static int
fd_set_or (fd_set * s1, fd_set * s2)
{
  long *p1 = (long *) s1;
  long *p2 = (long *) s2;
  int n, res = 0;
  for (n = 0; n < sizeof (fd_set) / sizeof (long); n++)
    {
      if (p1[n] |= p2[n])
	res = (n + 1) * 32;
    }
  return res;
}


static int
fd_sets_intersect (fd_set * s1, fd_set * s2)
{
  long *p1 = (long *) s1;
  long *p2 = (long *) s2;
  int n;
  for (n = 0; n < sizeof (fd_set) / sizeof (long); n++)
    {
      if (p1[n] & p2[n])
	return 1;
    }
  return 0;
}


void
sun_rpc_loop ()
{
  du_thread_t *this_thread = THREAD_CURRENT_THREAD;
  timeout_t to;
  to.to_sec = 0;
  to.to_usec = 0;
  while (1)
    {
      semaphore_enter (this_thread->thr_sem);
      svc_run_3 (&to);
    }
}


void
sun_rpc_ready ()
{
  if (sun_rpc_thread)
    semaphore_leave (sun_rpc_thread->dkt_process->thr_sem);
}


void
PrpcSunRPCInitialize (long sz)
{
  if (sun_rpc_thread)
    return;

  sun_rpc_thread = PrpcThreadAllocate (sz);
  process_set_init_function (sun_rpc_thread->dkt_process, (init_func) sun_rpc_loop, 0);
  semaphore_leave (sun_rpc_thread->dkt_process->thr_sem);
}
#endif /* SUNRPC */

#ifdef _SSL

#ifndef NO_THREAD
void
ssl_report_errors (char *client_ip)
{
  unsigned long l;
  const char *file, *data;
  int line, flags;

  while ((l = ERR_get_error_line_data (&file, &line, &data, &flags)) != 0)
    {
      char buf[256];
#if 0
      ERR_error_string_n (l, buf, sizeof (buf));
#else
      ERR_error_string (l, buf);
#endif
      if (flags & ERR_TXT_STRING)
	log_warning ("SSL error accepting connection from %s %s:%s", client_ip, buf, data);
      else
	log_warning ("SSL error accepting connection from %s %s", client_ip, buf);
    }
}
#endif
int
cli_ssl_get_error_string (char *out_data, int out_data_len)
{
  unsigned long err = ERR_get_error ();
  const char *reason = ERR_reason_error_string (err);
  const char *lib = ERR_lib_error_string (err);
  const char *func = ERR_func_error_string (err);
  out_data[out_data_len - 1] = 0;
  snprintf (out_data, out_data_len - 1, "%s (%s:%s)",
      reason ? reason : (err == 0 ? "No error" : "Unknown error"),
      lib ? lib : "?",
      func ? func : "?");
  return 0;
}


caddr_t
ssl_new_connection (void)
{
  return (caddr_t) SSL_new (ssl_server_ctx);
}


caddr_t
ssl_get_x509_error (caddr_t _ssl)
{
  SSL *ssl = (SSL *) _ssl;
  X509 *err_cert;
  int err, len;
  char buf[256];
  BIO *bio_err;
  caddr_t ret;
  void *data_ptr;

  if (!ssl || SSL_get_verify_result (ssl) == X509_V_OK)
    return NULL;
  bio_err = BIO_new (BIO_s_mem ());
  err_cert = SSL_get_peer_certificate (ssl);
  err = SSL_get_verify_result (ssl);

  if (err_cert)
    {
      X509_NAME_oneline (X509_get_subject_name (err_cert), buf, sizeof (buf));
      BIO_printf (bio_err, "%s : %s", X509_verify_cert_error_string (err), buf);
      switch (err)
	{
	case X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT:
	  X509_NAME_oneline (X509_get_issuer_name (err_cert), buf, 256);
	  BIO_printf (bio_err, " Invalid issuer= %s", buf);
	  break;

	case X509_V_ERR_CERT_NOT_YET_VALID:
	case X509_V_ERR_ERROR_IN_CERT_NOT_BEFORE_FIELD:
	  BIO_printf (bio_err, " not Before=");
	  ASN1_UTCTIME_print (bio_err, X509_get_notBefore (err_cert));
	  break;

	case X509_V_ERR_CERT_HAS_EXPIRED:
	case X509_V_ERR_ERROR_IN_CERT_NOT_AFTER_FIELD:
	  BIO_printf (bio_err, " notAfter=");
	  ASN1_UTCTIME_print (bio_err, X509_get_notAfter (err_cert));
	  break;
	}
    }
  else
    BIO_printf (bio_err, "%s", X509_verify_cert_error_string (err));
  len = BIO_get_mem_data (bio_err, &data_ptr);
  if (len > 0)
    {
      ret = dk_alloc_box (len + 1, DV_SHORT_STRING);
      memcpy (ret, data_ptr, len);
      ret[len] = 0;
    }
  else
    ret = box_dv_short_string ("General error");
  BIO_free (bio_err);
  return ret;
}


#ifndef NO_THREAD
int
ssl_cert_verify_callback (int ok, void *_ctx)
{
  X509_STORE_CTX *ctx;
  SSL *ssl;
  X509 *xs;
  int errnum;
  int errdepth;
  char *cp, cp_buf[1024];
  char *cp2, cp2_buf[1024];
  SSL_CTX *ssl_ctx;
  ssl_ctx_info_t *app_ctx;

  ctx = (X509_STORE_CTX *) _ctx;
  ssl = (SSL *) X509_STORE_CTX_get_app_data (ctx);
  ssl_ctx = SSL_get_SSL_CTX (ssl);
  app_ctx = (ssl_ctx_info_t *) SSL_CTX_get_app_data (ssl_ctx);

  xs = X509_STORE_CTX_get_current_cert (ctx);
  errnum = X509_STORE_CTX_get_error (ctx);
  errdepth = X509_STORE_CTX_get_error_depth (ctx);

  cp = X509_NAME_oneline (X509_get_subject_name (xs), cp_buf, sizeof (cp_buf));
  cp2 = X509_NAME_oneline (X509_get_issuer_name (xs), cp2_buf, sizeof (cp2_buf));

  if (( errnum == X509_V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT
	|| errnum == X509_V_ERR_SELF_SIGNED_CERT_IN_CHAIN
	|| errnum == X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY
#if OPENSSL_VERSION_NUMBER >= 0x00905000
	|| errnum == X509_V_ERR_CERT_UNTRUSTED
#endif
	|| errnum == X509_V_ERR_UNABLE_TO_VERIFY_LEAF_SIGNATURE)
      && ssl_server_verify == 3)
    {
      SSL_set_verify_result(ssl, X509_V_OK);
      ok = 1;
    }

#if 0
  log_debug ("%s Certificate Verification: depth: %d, subject: %s, issuer: %s",
  	app_ctx->ssci_name_ptr, errdepth, cp != NULL ? cp : "-unknown-",
	cp2 != NULL ? cp2 : "-unknown");
#endif
  /*
   * Additionally perform CRL-based revocation checks
   *
   if (ok) {
   ok = ssl_callback_SSLVerify_CRL(ok, ctx, s);
   if (!ok)
   errnum = X509_STORE_CTX_get_error(ctx);
   }
   */

  if (!ok)
    {
      log_error ("%s Certificate Verification: Error (%d): %s",
      	app_ctx->ssci_name_ptr, errnum, X509_verify_cert_error_string (errnum));
    }

  if (errdepth > *app_ctx->ssci_depth_ptr)
    {
      log_error ("%s Certificate Verification: Certificate Chain too long (chain has %d certificates, but maximum allowed are only %ld)",
	app_ctx->ssci_name_ptr, errdepth, *app_ctx->ssci_depth_ptr);
      ok = 0;
    }

  return (ok);
}


ssl_ctx_info_t ssl_server_ctx_info = { &ssl_server_verify_depth, "ODBC SSL" };
#endif


#ifdef SSL_DK_ALLOC
static void *
dk_ssl_alloc (size_t n)
{
  caddr_t ret = dk_alloc_box (n, DV_CUSTOM);
#ifdef NO_THREAD
  fprintf (stderr, "CLIENT:ssl_alloc (%lu) = %p\n", (unsigned long) n, ret);
#else
  fprintf (stderr, "SERVER:ssl_alloc (%lu) = %p\n", (unsigned long) n, ret);
#endif
  return ret;
}


static void *
dk_ssl_realloc (void *old, size_t n)
{
  int old_size = IS_BOX_POINTER (old) ? box_length (old) : 0;
  int copy_size = old_size > n ? n : old_size;
  void *new = dk_alloc_box (n, DV_CUSTOM);
#ifdef NO_THREAD
  fprintf (stderr, "CLIENT:ssl_realloc (%p(%lu), %lu) = %p\n", old, (unsigned long) old_size, (unsigned long) n, new);
#else
  fprintf (stderr, "SERVER:ssl_realloc (%p(%lu), %lu) = %p\n", old, (unsigned long) old_size, (unsigned long) n, new);
#endif
  if (old && copy_size)
    memcpy (new, old, copy_size);
  if (old)
    dk_free_box (old);
  return new;
}


static void
dk_ssl_free (void *old)
{
#ifdef NO_THREAD
  fprintf (stderr, "CLIENT:ssl_free (%p)\n", old);
#else
  fprintf (stderr, "SERVER:ssl_free (%p)\n", old);
#endif
  dk_free_box (old);
}
#endif

#if defined (_SSL) && !defined (NO_THREAD)
int ssl_server_set_certificate (SSL_CTX * ssl_ctx, char *cert_name, char *key_name, char *extra);

static int
ssl_server_key_setup ()
{
  if (!c_ssl_server_cert || !c_ssl_server_key)
    {
      log_error ("SSL: Server certificate and private key must both be specified");
      return 0;
    }

  if (!ssl_server_set_certificate (ssl_server_ctx, c_ssl_server_cert, c_ssl_server_key, c_ssl_server_extra_certs))
    return 0;

  if (ssl_server_verify)
    {
      int i, session_id_context = 2, verify = SSL_VERIFY_NONE;
      STACK_OF (X509_NAME) * skCAList = NULL;

      if (ssl_server_verify_file && ssl_server_verify_file[0])
	{
	  SSL_CTX_load_verify_locations (ssl_server_ctx, ssl_server_verify_file, NULL);
	  SSL_CTX_set_client_CA_list (ssl_server_ctx, SSL_load_client_CA_file (ssl_server_verify_file));
	}
      SSL_CTX_set_app_data (ssl_server_ctx, &ssl_server_ctx_info);
      if (ssl_server_verify == 1)	/* required */
	verify |= SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT | SSL_VERIFY_CLIENT_ONCE;
      else			/* 2 optional OR 3 optional no ca */
	verify |= SSL_VERIFY_PEER | SSL_VERIFY_CLIENT_ONCE;
      SSL_CTX_set_verify (ssl_server_ctx, verify, (int (*)(int, X509_STORE_CTX *)) ssl_cert_verify_callback);
      SSL_CTX_set_verify_depth (ssl_server_ctx, (int) ssl_server_verify_depth);
      SSL_CTX_set_session_id_context (ssl_server_ctx, (unsigned char *) &session_id_context, sizeof session_id_context);

      skCAList = SSL_CTX_get_client_CA_list (ssl_server_ctx);
      if (ssl_server_verify != 3 && sk_X509_NAME_num (skCAList) == 0)
	log_warning ("SSL: Client authentication requested but no CA known for verification");
      for (i = 0; i < sk_X509_NAME_num (skCAList); i++)
	{
	  char ca_buf[1024];
	  X509_NAME *ca_name = (X509_NAME *) sk_X509_NAME_value (skCAList, i);
	  if (X509_NAME_oneline (ca_name, ca_buf, sizeof (ca_buf)))
	    log_debug ("SSL: Using X509 client CA %s", ca_buf);
	}
    }

  return 1;
}
#endif

#if !defined(OPENSSL_THREADS)
#error Must have openssl configures with threads support
#endif

static dk_mutex_t ** lock_cs;

void
ssl_locking_callback (int mode, int type, char *file, int line)
{
  if (mode & CRYPTO_LOCK)
    mutex_enter (lock_cs [type]);
  else
    mutex_leave (lock_cs [type]);
}

unsigned long
ssl_thread_id (void)
{
  return (unsigned long) (ptrlong) THREAD_CURRENT_THREAD;
}

void
ssl_thread_setup ()
{
  int i;
  lock_cs = dk_alloc (CRYPTO_num_locks() * sizeof (dk_mutex_t *));
  for (i = 0; i < CRYPTO_num_locks (); i ++)
    {
      lock_cs [i] = mutex_allocate ();
    }
  CRYPTO_set_locking_callback ((void (*) (int, int, char *, int)) ssl_locking_callback);
  CRYPTO_set_id_callback ((unsigned long (*)()) ssl_thread_id);
}

static void
ssl_server_init ()
{
  const SSL_METHOD *ssl_server_method;

#ifdef SSL_DK_ALLOC
  CRYPTO_set_mem_functions (dk_ssl_alloc, dk_ssl_realloc, dk_ssl_free);
  CRYPTO_set_locked_mem_functions (dk_ssl_alloc, dk_ssl_free);
#endif
  SSL_load_error_strings ();
  ERR_load_crypto_strings ();
#ifndef WIN32
  {
    unsigned char tmp[1024];
    RAND_bytes (tmp, sizeof (tmp));
    RAND_add (tmp, sizeof (tmp), (double) (sizeof (tmp)));
  }
#endif
# if (OPENSSL_VERSION_NUMBER >= 0x00908000L)
  SSL_library_init ();
# endif
  SSLeay_add_all_algorithms ();
  PKCS12_PBE_add ();		/* stub */

#ifdef NO_THREAD
  ssl_server_method = SSLv23_client_method ();
#else
  ssl_server_method = SSLv23_server_method ();
#endif
  ssl_server_ctx = SSL_CTX_new (ssl_server_method);
  if (!ssl_server_ctx)
    {
      ERR_print_errors_fp (stderr);
      call_exit (-1);
    }
  ssl_thread_setup ();
}


/*##***************************
 * PEM analogue of PKCS12_parse
 *
 *****************************/
static EVP_PKEY *
PEM_load_key (const char *file, const char *pass)
{
  BIO *key = NULL;
  EVP_PKEY *pkey = NULL;

  key = BIO_new (BIO_s_file ());
  if (key == NULL)
    {
      goto end;
    }
  if (BIO_read_filename (key, file) <= 0)
    {
      goto end;
    }
  pkey = PEM_read_bio_PrivateKey (key, NULL, (pem_password_cb *) NULL, (void *) pass);
end:
  if (key != NULL)
    BIO_free (key);
  return pkey;
}


static
STACK_OF (X509) *
PEM_load_certs (const char *file, const char *pass)
{
  BIO *certs;
  int i;
  STACK_OF (X509) * othercerts = NULL;
  STACK_OF (X509_INFO) * allcerts = NULL;
  X509_INFO *xi;

  if ((certs = BIO_new (BIO_s_file ())) == NULL)
    {
      goto end;
    }

  if (BIO_read_filename (certs, file) <= 0)
    {
      goto end;
    }

  othercerts = sk_X509_new_null ();
  if (!othercerts)
    {
      sk_X509_free (othercerts);
      othercerts = NULL;
      goto end;
    }
  allcerts = PEM_X509_INFO_read_bio (certs, NULL, (pem_password_cb *) NULL /*password_callback */ , NULL);
  for (i = 0; i < sk_X509_INFO_num (allcerts); i++)
    {
      xi = sk_X509_INFO_value (allcerts, i);
      if (xi->x509)
	{
	  sk_X509_push (othercerts, xi->x509);
	  xi->x509 = NULL;
	}
    }
end:
  if (allcerts)
    sk_X509_INFO_pop_free (allcerts, X509_INFO_free);
  if (certs != NULL)
    BIO_free (certs);
  return (othercerts);
}


static int
PEM_parse (const char *file, const char *passwd, EVP_PKEY ** pkey, X509 ** cert, STACK_OF (X509) ** ca)
{
  EVP_PKEY *key = NULL;
  STACK_OF (X509) * certs = NULL;
  X509 *ucert = NULL;
  int i, found = 0;

  if (pkey)
    *pkey = NULL;
  if (cert)
    *cert = NULL;
  if (ca)
    *ca = NULL;

  if (NULL == (key = PEM_load_key (file, passwd)))
    goto end;
  certs = PEM_load_certs (file, passwd);
  for (i = 0; i < sk_X509_num (certs); i++)
    {
      ucert = sk_X509_value (certs, i);
      if (X509_check_private_key (ucert, key))
	{
	  sk_X509_delete_ptr (certs, ucert);
	  found = 1;
	  break;
	}
    }

  if (!found)
    {
      ucert = NULL;
      goto end;
    }
end:
  if (pkey)
    *pkey = key;
  if (cert)
    *cert = ucert;
  if (ca)
    *ca = certs;

  if (!key || !ucert)
    return 0;
  return 1;
}


/* end of PEM_parse */

int
ssl_client_use_pkcs12 (SSL * ssl, char *pkcs12file, char *passwd, char *ca)
{
  int /*session_id_context = 2, */ i;
  FILE *fi;
  PKCS12 *p12 = NULL;
  EVP_PKEY *pkey;
  X509 *cert;
  STACK_OF (X509) * ca_list = NULL;
  SSL_CTX *ssl_ctx = SSL_get_SSL_CTX (ssl);

  if (0 == PEM_parse (pkcs12file, passwd, &pkey, &cert, &ca_list))
    {
      if ((fi = fopen (pkcs12file, "rb")) != NULL)
	{
	  p12 = d2i_PKCS12_fp (fi, NULL);
	  fclose (fi);
	}
      if (p12)
	{
	  i = PKCS12_parse (p12, passwd, &pkey, &cert, &ca_list);
	  PKCS12_free (p12);
	  if (!i)
	    return 0;
	}
    }

  if (ca && ca[0] != 0)
    {
      sk_X509_pop_free (ca_list, X509_free);
      ca_list = PEM_load_certs (ca, passwd);
    }

  i = SSL_use_certificate (ssl, cert);
  if (i)
    i = SSL_use_PrivateKey (ssl, pkey);
  if (i)
    i = SSL_check_private_key (ssl);
  if (i)
    {
      for (i = 0; i < sk_X509_num (ca_list); i++)
	{
	  X509 *ca = (X509 *) sk_X509_value (ca_list, i);
	  SSL_add_client_CA (ssl, ca);
	  X509_STORE_add_cert (SSL_CTX_get_cert_store (ssl_ctx), ca);
	}
    }
  X509_free (cert);
  EVP_PKEY_free (pkey);
  sk_X509_pop_free (ca_list, X509_free);
  return i ? 1 : 0;
}


#ifndef NO_THREAD

static int
ssl_server_accept (dk_session_t * listen, dk_session_t * ses)
{
  unsigned int port = tcpses_get_port (listen->dks_session);
  if (ses->dks_session->ses_class != SESCLASS_UNIX && ssl_server_port == port && ssl_server_ctx)
    {
      int dst = 0;
      int ssl_err = 0;
      SSL *new_ssl = NULL;
      if (NULL != tcpses_get_ssl (ses->dks_session))
	SSL_free ((SSL *) tcpses_get_ssl (ses->dks_session));
      dst = tcpses_get_fd (ses->dks_session);
      new_ssl = SSL_new (ssl_server_ctx);
      SSL_set_fd (new_ssl, dst);
      ssl_err = SSL_accept (new_ssl);
      if (ssl_err == -1)	/* the SSL_accept do the certificate verification */
	{
	  char client_ip[16];
	  caddr_t err;
	  tcpses_print_client_ip (ses->dks_session, client_ip, sizeof (client_ip));
	  ssl_report_errors (client_ip);
	  err = ssl_get_x509_error ((caddr_t) new_ssl);
	  if (err)
	    {
	      log_error ("X509 error accepting connection from %s : %s", client_ip, err);
	      dk_free_box (err);
	    }

	  SSL_free (new_ssl);
	  PrpcDisconnect (ses);
	  PrpcSessionFree (ses);
	  return 0;
	}
      tcpses_to_sslses (ses->dks_session, (void *) (new_ssl));
    }
  return 1;
}
#endif

#endif

#ifndef NO_DK_ALLOC_RESERVE

#define DK_ALLOC_RESERVE_OUT_CHECK 50

int dk_alloc_reserve_maxthreads = 10;
volatile void *dk_alloc_reserve = NULL;
dk_mutex_t *dk_alloc_reserve_mutex = NULL;
volatile int dk_alloc_reserve_mode = DK_ALLOC_RESERVE_DISABLED;
#define DK_ALLOC_RESERVE_SIZE ((0x8000 + 0x1000 * dk_alloc_reserve_maxthreads) * sizeof (void *))


#if 0						 /* IvAn/OutOfMem/040513 bytes_allocated can't be correct! */
extern size_t bytes_allocated;
extern size_t bytes_allocated_max;
#endif

void
dk_alloc_set_reserve_mode (int new_mode)
{
#if 0
  int first_run = 0;
#endif
  if (NULL == dk_alloc_reserve_mutex)
    {
      dk_alloc_reserve_mutex = mutex_allocate ();
    }
  if (new_mode == dk_alloc_reserve_mode)
    return;
  mutex_enter (dk_alloc_reserve_mutex);
  switch (new_mode)
    {
    case DK_ALLOC_RESERVE_PREPARED:
      if (NULL == dk_alloc_reserve)
	{
	  dk_alloc_reserve = malloc (DK_ALLOC_RESERVE_SIZE);
	  if (NULL == dk_alloc_reserve)
	    GPF_T1 ("Unable to allocate the memory reserve");
	  if (dk_alloc_reserve_mode == DK_ALLOC_RESERVE_IN_USE)
	    log_error ("Switching back from memory reserve to normal mode");
	}
      break;

    case DK_ALLOC_RESERVE_IN_USE:
      if (dk_alloc_reserve_mode == DK_ALLOC_RESERVE_DISABLED)
	GPF_T1 ("Server is out of memory and should be killed to prevent data corruption.");
      if (NULL == dk_alloc_reserve)
	GPF_T1 ("Fatal out of memory. Unable to consume memory reserve because the memory reserve is totally missing.");
      free (( /* non-volatile here */ void *) dk_alloc_reserve);
      dk_alloc_reserve = NULL;
      log_error ("Memory low! Using memory reserve to terminate current activities properly");
#if defined (UNIX) && !defined (MALLOC_DEBUG)
      log_error ("Current location of the program break %ld", (long) sbrk (0) - init_brk);
#endif
      break;

    case DK_ALLOC_RESERVE_DISABLED:
      break;

    default:
      GPF_T;
    }
  dk_alloc_reserve_mode = new_mode;
  mutex_leave (dk_alloc_reserve_mutex);
}


void *
dk_alloc_reserve_malloc (size_t size, int gpf_if_not)
{
#if 0						 /* IvAn/OutOfMem/040513 bytes_allocated can't be correct! */
  void *thing = NULL;
  if (!bytes_allocated_max || bytes_allocated < bytes_allocated_max)
    thing = malloc (size);
#else
  void *thing = malloc (size);
#endif
  if (thing)
    {
#if 0						 /* IvAn/OutOfMem/040503 there must be no automatic return from reserve mode */
      if (dk_alloc_reserve_mutex && dk_alloc_on_reserve)
	{
	  mutex_enter (dk_alloc_reserve_mutex);
	  if (dk_alloc_reserve_out_cnt++ >= DK_ALLOC_RESERVE_OUT_CHECK)
	    {
	      dk_alloc_reserve = malloc (DK_ALLOC_RESERVE_SIZE);
	      if (dk_alloc_reserve)
		{
#if 0						 /* IvAn/OutOfMem/040513 bytes_allocated can't be correct! */
		  bytes_allocated += DK_ALLOC_RESERVE_SIZE;
#endif
		  dk_alloc_on_reserve = 0;
		  mutex_leave (dk_alloc_reserve_mutex);
		  log_error ("Switching back from memory reserve to normal mode");
		  return thing;
		}
	      else
		dk_alloc_reserve_out_cnt = 0;
	    }
	  mutex_leave (dk_alloc_reserve_mutex);
	}
#endif
      return thing;
    }
#if 0						 /* IvAn/OutOfMem/040503 there must be no automatic return from reserve mode */
  if (dk_alloc_reserve_mutex && gpf_if_not)
    {
      if (!dk_alloc_on_reserve && size < DK_ALLOC_RESERVE_SIZE)
	{
	  mutex_enter (dk_alloc_reserve_mutex);
	  free (dk_alloc_reserve);
#if 0						 /* IvAn/OutOfMem/040513 bytes_allocated can't be correct! */
	  bytes_allocated -= DK_ALLOC_RESERVE_SIZE;
#endif
	  dk_alloc_reserve = NULL;
	  dk_alloc_reserve_out_cnt = 0;
	  mutex_leave (dk_alloc_reserve_mutex);

	  dk_alloc_on_reserve = 1;
	  log_error ("Running on memory reserve");
#if 0						 /* IvAn/OutOfMem/040513 bytes_allocated can't be correct! */
	  if (!bytes_allocated_max || bytes_allocated < bytes_allocated_max)
#endif
	    thing = malloc (size);
	  if (thing)
	    return thing;
	  return malloc (size);
	}
    }
  if (gpf_if_not)
    GPF_T1 ("Out of memory");
  return NULL;					 /* dummy */
#else
  if (!gpf_if_not)
    return NULL;
  dk_alloc_set_reserve_mode (DK_ALLOC_RESERVE_IN_USE);
  thing = malloc (size);
  if (NULL == thing)
    {
#if defined (UNIX) && !defined (MALLOC_DEBUG)
      log_error ("Current location of the program break %ld", (long) sbrk (0) - init_brk);
#endif
#ifdef MALLOC_DEBUG
      dbg_dump_mem();
#endif
      GPF_T1 ("Out of memory");
    }
  return thing;
#endif
}


#else

void *
dk_alloc_reserve_malloc (size_t size, int gpf_if_not)
{
  void *thing = malloc (size);
  if (!thing && gpf_if_not)
    {
#if defined (UNIX) && !defined (MALLOC_DEBUG)
      log_error ("Current location of the program break %ld", (long) sbrk (0) - init_brk);
#endif
#ifdef MALLOC_DEBUG
      dbg_dump_mem();
#endif
      GPF_T1 ("Out of memory");
    }
  return thing;
}
#endif



#ifndef NO_THREAD
void
ssl_server_listen ()
{
#ifdef _SSL
  dk_session_t *listening;
  if (!c_ssl_server_port)
    return;

  if (!ssl_server_key_setup ())
    goto failed;

  listening = PrpcListen (c_ssl_server_port, SESCLASS_TCPIP);
      if (!SESSTAT_ISSET (listening->dks_session, SST_LISTENING))
	{
    failed:
      log_error ("SSL: Failed listen at %s", c_ssl_server_port);
      return;
    }
      ssl_server_port = tcpses_get_port (listening->dks_session);

  log_info ("SSL server online at %s", c_ssl_server_port);
#endif
}


void
dks_stop_burst_mode (dk_session_t * ses)
{
  if (DKST_RUN == ses->dks_thread_state)
    return;
  if (!prpc_disable_burst_mode /*&& !prpc_force_burst_mode */ )
    {
      mutex_enter (thread_mtx);
      if (!ses->dks_fixed_thread && ses->dks_thread_state == DKST_BURST)
	{
	  thrs_printf ((thrs_fo, "ses %p thr:%p long running ! from burst to run.\n", ses, THREAD_CURRENT_THREAD));
	  ses->dks_thread_state = DKST_RUN;
	  PrpcCheckInAsync (ses);
	}
      mutex_leave (thread_mtx);
    }
}
#endif

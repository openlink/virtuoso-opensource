/*
 *  clsrv.c
 *
 *  $Id$
 *
 *  Cluster server end
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2026 OpenLink Software
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

#include "sqlnode.h"
#include "sqlver.h"
#include "sqlparext.h"
#include "sqlbif.h"
#include "security.h"
#include "log.h"

#ifdef unix
#include <sys/resource.h>
#include <netdb.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#endif

cl_listener_t local_cll;
du_thread_t * cl_listener_thr;
int32 cl_stage;
int32 cl_max_hosts = 100;
cl_host_t * cl_master;
dk_set_t cluster_hosts;
resource_t * cluster_threads;
resource_t *cl_strses_rc;	/* strses structs used for receiving and sending cluster messages */
dk_mutex_t * cluster_thread_mtx;
int64 cl_cum_messages, cl_cum_bytes, cl_cum_txn_messages;
int64 cll_entered;
int64 cll_lines[1000];
int cll_counts[1000];
resource_t *cl_buf_rc;
resource_t *cll_rbuf_rc;
int64 cl_cum_wait, cl_cum_wait_msec;
char * c_cluster_listen;
int32 c_cluster_threads;
int32 cl_keep_alive_interval = 3000;
int32 cl_max_keep_alives_missed = 4;
int32 cl_batches_per_rpc;
int32 cl_req_batch_size; /* no of request clo's per message */
int32 cl_dfg_batch_bytes = 10000000;
int32 cl_mt_read_min_bytes = 10000000;	/* if more than this much, read the stuff on the worker thread, not the dispatch thread */
uint32 cl_send_high_water;
int32  cl_res_buffer_bytes; /* no of bytes before sending to client */
int c_cl_no_unix_domain;
char * c_cluster_local;
char * c_cluster_master;
caddr_t cl_map_file_name;
int cluster_enable = 0;
int32 cl_n_hosts;
cluster_map_t * clm_replicated;
cluster_map_t * clm_all;
cl_thread_t * listen_clt;
int cl_n_clt_running, cl_n_clt_start, clt_n_late_cancel;
int32 cl_wait_query_delay = 20000; /* wait 20s before requesting forced sync of cluster wait graph */
int32 cl_non_logged_write_mode;
int32 cl_batch_bytes = 10 * PAGE_SZ;
rbuf_t cll_undelivered;
int64 cll_bytes_undelivered;
int64 cll_max_undelivered = 150000000;
int enable_cll_nb_read;
char cll_stay_in_cll_mtx;
long tc_over_max_undelivered;
long tc_cll_undelivered;
long tc_cll_mt_read;
extern long tc_cl_disconnect;
extern long tc_cl_disconnect_in_clt;
int cl_no_init = 0;



typedef struct cll_line_s
{
  int64 cll_time;
  int cll_count;
  int cll_line;
} cll_line_t;


int
cll_cmp (const void *l1, const void *l2)
{
  if (((cll_line_t *) l1)->cll_time > ((cll_line_t *) l2)->cll_time)
    return 1;
  return -1;
}

void
cll_times (void)
{
  cll_line_t l[1000];
  int inx, fill = 0;
  for (inx = 0; inx < 1000; inx++)
    {
      if (cll_lines[inx])
	{
	  l[fill].cll_time = cll_lines[inx];
	  l[fill].cll_count = cll_counts[inx];
	  l[fill++].cll_line = inx;
	}
    }
  qsort (l, fill, sizeof (cll_line_t), cll_cmp);
  for (inx = 0; inx < fill; inx++)
    printf ("%d:  " BOXINT_FMT " %d\n", l[inx].cll_line, l[inx].cll_time, l[inx].cll_count);
#ifdef MTX_METER
  printf ("cll waits: %ld w: %Ld e: %ld\n", local_cll.cll_mtx->mtx_wait_clocks, local_cll.cll_mtx->mtx_waits,
      local_cll.cll_mtx->mtx_enters);
  local_cll.cll_mtx->mtx_wait_clocks = local_cll.cll_mtx->mtx_enters = local_cll.cll_mtx->mtx_waits = 0;
#endif
  memzero (cll_counts, sizeof (cll_counts));
  memzero (cll_lines, sizeof (cll_lines));
}




extern int32 dk_tcp_ai_ipv4_enable;
extern int32 dk_tcp_ai_ipv6_enable;

caddr_t
cl_host_addr (char *host_and_port)
{
  char host[NI_MAXHOST];
  char ip[INET6_ADDRSTRLEN];
  char *col;
  struct addrinfo hints = { 0 };
  struct addrinfo *res = NULL;
  struct addrinfo *p = NULL;
  int rc;

  /* extract host name without port */
  strcpy_ck (host, host_and_port);
  col = strchr (host, ':');
  if (col)
    col[0] = '\0';

  hints.ai_family = AF_UNSPEC;		/* Allow IPv4 or IPv6 */
  hints.ai_socktype = SOCK_STREAM;

#if defined(AI_ADDRCONFIG)
  hints.ai_flags |= AI_ADDRCONFIG;
#endif

  if ((rc = getaddrinfo (host, NULL, &hints, &res)) != 0)
    {
      log_error ("Could not resolve host \"%s\" in cluster host list: %s", host, gai_strerror (rc));
      call_exit (1);
      return NULL;
    }

  ip[0] = '\0';
  for (p = res; p != NULL; p = p->ai_next)
    {
      const void *src = NULL;

      if (dk_tcp_ai_ipv4_enable && p->ai_family == AF_INET)
	src = &((struct sockaddr_in *) p->ai_addr)->sin_addr;
      else if (dk_tcp_ai_ipv6_enable && p->ai_family == AF_INET6)
	src = &((struct sockaddr_in6 *) p->ai_addr)->sin6_addr;
      else
	continue;

      if (inet_ntop (p->ai_family, src, ip, sizeof (ip)))
	break;			/* success */

      ip[0] = '\0';
    }

  freeaddrinfo (res);

  if (ip[0] == '\0')
    {
      log_error ("Could not resolve host \"%s\" in cluster host list", host);
      call_exit (1);
      return NULL;
    }

  return box_dv_short_string (ip);
}



#ifdef MTX_METER
int
cll_try_enter (void)
{
  if (mutex_try_enter (local_cll.cll_mtx))
    {
      cll_entered = rdtsc ();
      return 1;
    }
  return 0;
}
#endif


dk_session_t *
cl_strses_allocate (void)
{
  dk_session_t *ses;
  /* the head and 1st buffer of strses come from common, the extension will come from the user thread */
  WITH_TLSF (dk_base_tlsf) 
    ses = strses_allocate ();
  END_WITH_TLSF;
  ses->dks_cluster_flags = DKS_TO_CLUSTER;
  return ses;
}


void
cl_strses_free (dk_session_t * ses)
{
  dk_free_box ((caddr_t) ses);
}


void
null_serialize (caddr_t x, dk_session_t * ses)
{
  session_buffered_write_char (DV_DB_NULL, ses);
}


cl_host_t *
cl_name_to_host (char * name)
{
  return NULL;
}

cl_host_t *
cl_id_to_host (int id)
{
  return local_cll.cll_local;
}

caddr_t
cl_buf_str_alloc (void)
{
  return dk_alloc (DKSES_OUT_BUFFER_LENGTH);
}

void
cl_buf_str_free (caddr_t str)
{
  dk_free (str, DKSES_OUT_BUFFER_LENGTH);
}


void
cluster_init (void)
{
  local_cll.cll_mtx = mutex_allocate ();
  dk_mem_hooks (DV_CLOP, box_non_copiable, (box_destr_f) clo_destroy, 0);
  cl_strses_rc = resource_allocate (30, (rc_constr_t) cl_strses_allocate, (rc_destr_t) cl_strses_free, (rc_destr_t) strses_flush, NULL);
  clib_rc_init ();
  dk_mem_hooks (DV_CLRG, (box_copy_f) clrg_copy, (box_destr_f) clrg_destroy, 1);
  PrpcSetWriter (DV_CLRG, (ses_write_func) null_serialize);
}

char *
cl_thr_stat (void)
{
  return "";
}

int32 cl_ac_interval = 100000;

void
cluster_after_online (void)
{
}

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
 *  Copyright (C) 1998-2011 OpenLink Software
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
#include <sys/socket.h>

#endif

cl_listener_t local_cll;
du_thread_t * cl_listener_thr;
int32 cl_stage;
int32 cl_max_hosts = 100;
cl_host_t * cl_master;
dk_set_t cluster_hosts;
resource_t * cluster_threads;
dk_mutex_t * cluster_thread_mtx;
int64 cl_cum_messages, cl_cum_bytes, cl_cum_txn_messages;

int64 cl_cum_wait, cl_cum_wait_msec;
char * c_cluster_listen;
int32 c_cluster_threads;
int32 cl_keep_alive_interval = 3000;
int32 cl_max_keep_alives_missed = 4;
int32 cl_batches_per_rpc;
int32 cl_req_batch_size; /* no of request clo's per message */
int32 cl_dfg_batch_bytes = 10000000;
uint32 cl_send_high_water;
int32  cl_res_buffer_bytes; /* no of bytes before sending to client */
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

extern long tc_cl_disconnect;
extern long tc_cl_disconnect_in_clt;

dk_mutex_t * clrg_ref_mtx;

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

void
cluster_init ()
{
  local_cll.cll_mtx = mutex_allocate ();
  clrg_ref_mtx = mutex_allocate ();
  dk_mem_hooks (DV_CLOP, box_non_copiable, (box_destr_f) clo_destroy, 0);
}

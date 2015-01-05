/*
 *  $Id$
 *
 *  Cluster data structures
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

#ifndef _CLUSTER_H
#define _CLUSTER_H

#include "../Dk/Dkhash64.h"



typedef void cl_req_group_t;
typedef struct cl_listener_s
{
  int32			cll_this_host;
  int32			cll_master_host;
  int32			cll_max_host; /* highest used host no */
} cl_listener_t;
extern cl_listener_t local_cll;
extern int64 cl_cum_messages;
extern int64 cl_cum_txn_messages;
extern int64 cl_cum_bytes;
extern int64 cl_cum_wait;
extern int64 cl_cum_wait_msec;
caddr_t cl_ddl (query_instance_t * qi, lock_trx_t * lt, caddr_t name, int type, caddr_t trig_table);
void cl_rdf_inf_init (client_connection_t * cli, caddr_t * err_ret);

/* action codes for ddl messages */
#define CLO_DDL_TABLE 1
#define CLO_DDL_PROC 2
#define CLO_DDL_CLUSTER 3
#define CLO_DDL_TYPE 4
#define CLO_DDL_TRIG 5
#define CLO_DDL_ATOMIC 6
#define CLO_DDL_ATOMIC_OVER 7

typedef struct cl_op_s
{
  char		clo_op;
  int		clo_seq_no; /* seq no in the clrg */
  int		clo_nth_param_row; /* no of the param row of the calling sql node */
  mem_pool_t *		clo_pool;
  dk_set_t		clo_clibs; /* the set of hosts serving this */
  union {
    struct {
      struct itc_cluster_s *	itcl;
    } itcl;
  } _;
} cl_op_t;

typedef struct itc_cluster_s
{
  bitf_t	itc_in_order:1;
  bitf_t	itcl_desc_order:1;
  bitf_t	itcl_return_pl:1;
  short			itcl_n_clibs;
  int			itcl_nth_set;
  dbe_column_t **	itcl_out_cols;
  dk_set_t		itcl_out_slots;
  query_frag_t *	itcl_dfg_qf;
  caddr_t *		itcl_qst;
  mem_pool_t *		itcl_pool;
  cl_op_t ***		itcl_param_rows;
  dk_set_t		itcl_last;
} itc_cluster_t;

#define QFID_HOST(i) ((int)(((unsigned int64) (i)) >> 32))

#define CLST_REFRESH 0
#define CLST_SUMMARY 1
#define CLST_DETAILS 2

extern int32 cl_n_hosts;
extern int32 cl_max_hosts;
extern int32 cl_req_batch_size;
extern int32 cl_dfg_batch_bytes;
extern uint32 cl_send_high_water;
extern int32 cl_batches_per_rpc; /* no of rows to send before stopping to wait for a CL_MORE message */
extern int32  cl_res_buffer_bytes; /* no of bytes before sending to client */
extern long dbf_branch_transact_wait;
extern int32 cl_wait_query_delay;
extern int32 enable_dfg;

typedef void cu_func_t;

#define CLO_ITCL 16 /* not a message.  A container for a local itc_cluster_t */
#define DKS_TO_CLUSTER 1

#define DKS_QI_DATA(ses)  (*((query_instance_t **)&(ses)->dks_object_temp))
#define DKS_CL_DATA(ses)  NULL
void cl_ts_set_context (table_source_t * ts, itc_cluster_t * itcl, caddr_t * inst, int nth_set);
cl_op_t * clo_allocate (char op);
itc_cluster_t * itcl_allocate (lock_trx_t * lt, caddr_t * inst);
void cl_select_save_env (table_source_t * ts, itc_cluster_t * itcl, caddr_t * inst, cl_op_t * clo, int nth);
int clo_destroy  (cl_op_t * clo);
cl_host_t * cl_name_to_host (char * name);
cu_func_t * cu_func (caddr_t name, int must_find);
caddr_t cl_id_to_iri (query_instance_t * qi, caddr_t id);


extern long dbf_cpt_rb;

#endif

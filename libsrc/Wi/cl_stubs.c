/*
 *  $Id$
 *
 *  Cluster stubs
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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

#include "libutil.h"
#include "sqlnode.h"
#include "sqlver.h"

#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlbif.h"
#include "arith.h"
#include "security.h"
#include "sqlo.h"


#define NO_CLUSTER 	GPF_T1 ("This build does not include cluster support.")


/*
 *  Globals
 */
cl_listener_t local_cll;
cluster_map_t *clm_replicated;

int cluster_enable = 0;
int enable_dfg_print = 0;
int32 enable_dfg = 1;
int enable_setp_partition;
int enable_multistate_code = 0;
int enable_g_replace_log = 0;

int32 c_cluster_threads;
int32 cl_batches_per_rpc;
int32 cl_con_drop_rate;
int32 cl_dead_w_interval = 12000;
int32 cl_dfg_batch_bytes = 10000000;
int32 cl_keep_alive_interval = 3000;
int32 cl_max_hosts = 100;
int32 cl_max_keep_alives_missed = 4;
int32 cl_msg_drop_rate;
int32 cl_n_hosts;
int32 cl_non_logged_write_mode;
int32 cl_req_batch_size;	/* no of request clo's per message */
int32 cl_res_buffer_bytes;	/* no of bytes before sending to client */
int32 cl_stage;
int32 cl_wait_query_delay = 20000;	/* wait 20s before requesting forced sync of cluster wait graph */
int32 cl_dead_w_interval;

int64 cl_cum_messages, cl_cum_bytes, cl_cum_txn_messages;
int64 cl_cum_wait, cl_cum_wait_msec;

resource_t *cluster_threads;

uint32 cl_last_wait_query;
uint32 cl_send_high_water;




/*
 *  Stub functions
 */

cl_op_t *
clo_allocate (char op)
{
  cl_op_t *clo = dk_alloc_box_zero (sizeof (cl_op_t), DV_CLOP);
  clo->clo_op = op;
  return clo;
}


int
clo_destroy (cl_op_t * clo)
{
  dk_set_free (clo->clo_clibs);
  switch (clo->clo_op)
    {
    case CLO_ITCL:
      if (!clo->_.itcl.itcl)
	break;
      mp_free (clo->_.itcl.itcl->itcl_pool);
      dk_free ((caddr_t) clo->_.itcl.itcl, sizeof (itc_cluster_t));
      break;

    default:
      NO_CLUSTER;
    }
  return 0;
}


cu_func_t *
cu_func (caddr_t name, int must_find)
{
  return NULL;
}


caddr_t
cl_ddl (query_instance_t * qi, lock_trx_t * lt, caddr_t name, int type, caddr_t trig_table)
{
  return NULL;
}


void
lt_send_rollbacks (lock_trx_t * lt, int sync)
{
}


void
query_frag_input (query_frag_t * qf, caddr_t * inst, caddr_t * state)
{
  NO_CLUSTER;
}


void
lt_expedite_1pc (lock_trx_t * lt)
{
  NO_CLUSTER;
}


void
cl_ts_set_context (table_source_t * ts, itc_cluster_t * itcl, caddr_t * inst, int nth_set)
{
  int inx;
  caddr_t *row = ((caddr_t **) itcl->itcl_param_rows)[nth_set];
  DO_BOX (state_slot_t *, ssl, inx, ts->clb.clb_save)
  {
    qst_set_over (inst, ssl, row[inx + 1]);
  }
  END_DO_BOX;
  if (ts->clb.clb_nth_context)
    QST_INT (inst, ts->clb.clb_nth_context) = nth_set;
}


itc_cluster_t *
itcl_allocate (lock_trx_t * lt, caddr_t * inst)
{
  NEW_VARZ (itc_cluster_t, itcl);
  itcl->itcl_qst = inst;
  itcl->itcl_pool = mem_pool_alloc ();
  return itcl;
}


#define CL_INIT_BATCH_SIZE 100


void
cl_select_save_env (table_source_t * ts, itc_cluster_t * itcl, caddr_t * inst, cl_op_t * clo, int nth)
{
  caddr_t **array = (caddr_t **) itcl->itcl_param_rows;
  caddr_t *row;
  int inx, n_save;
  if (!array)
    {
      itcl->itcl_param_rows = (cl_op_t ***) (array =
	  (caddr_t **) mp_alloc_box_ni (itcl->itcl_pool, CL_INIT_BATCH_SIZE * sizeof (caddr_t), DV_ARRAY_OF_POINTER));
    }
  else if (BOX_ELEMENTS (array) <= nth)
    {
      caddr_t new_array = mp_alloc_box_ni (itcl->itcl_pool, ts->clb.clb_batch_size * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      memcpy (new_array, array, box_length (array));
      itcl->itcl_param_rows = (cl_op_t ***) (array = (caddr_t **) new_array);
    }
  n_save = ts->clb.clb_save ? BOX_ELEMENTS (ts->clb.clb_save) : 0;
  row = (caddr_t *) mp_alloc_box_ni (itcl->itcl_pool, sizeof (caddr_t) * (1 + n_save), DV_ARRAY_OF_POINTER);
  row[0] = (caddr_t) clo;
  if (n_save)
    {
      DO_BOX (state_slot_t *, ssl, inx, ts->clb.clb_save)
      {
	row[inx + 1] = mp_full_box_copy_tree (itcl->itcl_pool, qst_get (inst, ssl));
      }
      END_DO_BOX;
    }
  array[nth] = row;
  if (ts->clb.clb_nth_context)
    QST_INT (inst, ts->clb.clb_nth_context) = -1;
}


caddr_t
cl_id_to_iri (query_instance_t * qi, caddr_t id)
{
  NO_CLUSTER;
  return NULL;
}


dpipe_node_t *
sqlg_pre_code_dpipe (sqlo_t * so, dk_set_t * code_ret, data_source_t * qn)
{
  return NULL;
}


void
sqlg_cl_multistate_simple_agg (sql_comp_t * sc, dk_set_t * cum_code)
{
}


void
sqlg_cl_multistate_group (sql_comp_t * sc)
{
}


int
qn_seq_is_multistate (data_source_t * qn)
{
  return 0;
}


void
sqlg_cl_insert (sql_comp_t * sc, comp_context_t * cc, insert_node_t * ins, ST * tree, dk_set_t * code)
{
}


int
qr_is_multistate (query_t * qr)
{
  return 0;
}


void
clb_init (comp_context_t * cc, cl_buffer_t * clb, int is_select)
{
  clb->clb_batch_size = 1;
  clb->clb_fill = cc_new_instance_slot (cc);
  clb->clb_nth_set = cc_new_instance_slot (cc);
  clb->clb_params = ssl_new_variable (cc, "clb_params", DV_ARRAY_OF_POINTER);
  if (is_select)
    {
    }
  else
    {
      clb->clb_clrg = ssl_new_variable (cc, "clrg", DV_ANY);
    }
}


cl_host_t *
cl_name_to_host (char *name)
{
  return NULL;
}

void
cluster_init ()
{
  dk_mem_hooks (DV_CLOP, box_non_copiable, (box_destr_f) clo_destroy, 0);
}


void
partition_def_bif_define (void)
{
  return;
}

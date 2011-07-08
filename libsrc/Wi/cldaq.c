/*
 *  cldaq.c
 *
 *  $Id$
 *
 *  Cluster RPC for PL
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
#include "sqlbif.h"
#include "security.h"



#if 0
#define daq_printf(a) printf a
#define daq_print_box(a) sqlo_box_print a
#else
#define daq_printf(a)
#define daq_print_box(a)
#endif

void
array_add (caddr_t ** ap, int *fill, caddr_t elt)
{
  if (!*ap)
    {
      *ap = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t) * 10, DV_ARRAY_OF_POINTER);
      (*ap)[0] = (caddr_t) elt;
      *fill = 1;
    }
  else if (BOX_ELEMENTS (*ap) <= *fill)
    {
      int len = BOX_ELEMENTS (*ap);
      caddr_t *nb = dk_alloc_box_zero (sizeof (caddr_t) * (len < 2000 ? 4 : 2) * len, DV_ARRAY_OF_POINTER);
      memcpy (nb, *ap, sizeof (caddr_t) * len);
      dk_free_box (*ap);
      *ap = nb;
      nb[*fill] = (caddr_t) elt;
      (*fill)++;
    }
  else
    (*ap)[(*fill)++] = (caddr_t) elt;
}


void
mp_array_add (mem_pool_t * mp, caddr_t ** ap, int *fill, caddr_t elt)
{
  if (!*ap)
    {
      *ap = (caddr_t *) mp_alloc_box (mp, sizeof (caddr_t) * 10, DV_ARRAY_OF_POINTER);
      (*ap)[0] = (caddr_t) elt;
      *fill = 1;
    }
  else if (BOX_ELEMENTS (*ap) <= *fill)
    {
      int len = BOX_ELEMENTS (*ap);
      int new_len = (len < 2000 ? 4 : 2) * len;
      caddr_t *nb;

      if (new_len <= (*fill))
	sqlr_new_error ("42000", "CL...", "The array extend %d is less than requested %d", new_len, (*fill));

      nb = (caddr_t *) mp_alloc_box (mp, sizeof (caddr_t) * new_len, DV_ARRAY_OF_POINTER);
      memcpy (nb, *ap, sizeof (caddr_t) * len);
      *ap = nb;
      nb[*fill] = (caddr_t) elt;
      (*fill)++;
    }
  else
    (*ap)[(*fill)++] = (caddr_t) elt;
}


extern int enable_daq_trace;


void
clib_local_call_error (cll_in_box_t * clib, cl_op_t * clo, caddr_t err)
{
  cl_op_t *err_clo = clo_allocate (CLO_ROW);
  err_clo->clo_seq_no = clo->clo_seq_no;
  err_clo->clo_nth_param_row = clo->clo_nth_param_row;
  err_clo->_.row.cols = (caddr_t *) list (2, box_num (CLO_CALL_ERROR), err);
  basket_add (&clib->clib_in_parsed, (void *) err_clo);
}


int
clib_local_autocommit (cll_in_box_t * clib, query_instance_t * qi, cl_op_t * clo, caddr_t err)
{
  client_connection_t *cli;
  caddr_t detail = NULL;
  if (!qi)
    return LTE_OK;		/* if run inside compiler */
  cli = qi->qi_client;
  if (err)
    {
      IN_TXN;
      lt_rollback (cli->cli_trx, TRX_CONT);
      LEAVE_TXN;
    }
  else
    {
      int rc;
      IN_TXN;
      detail = cli->cli_trx->lt_error_detail;
      cli->cli_trx->lt_error_detail = NULL;
      rc = lt_commit (cli->cli_trx, TRX_CONT);
      LEAVE_TXN;
      if (LTE_OK != rc)
	{
	  caddr_t lt_err = srv_make_trx_error (rc, detail);
	  dk_free_box (detail);
	  clib_local_call_error (clib, clo, lt_err);
	  return rc;
	}
    }
  return LTE_OK;
}


void
cl_local_call (query_instance_t * qi, cll_in_box_t * clib, cl_op_t * clo)
{
  int old_ac;
  cl_op_t *row;
  caddr_t err;
  du_thread_t *self = THREAD_CURRENT_THREAD;
  caddr_t val = NULL;
  caddr_t *params = clo->_.call.params, *params_copy;
  caddr_t fn = clo->_.call.func;
  client_connection_t *cli = qi ? qi->qi_client : sqlc_client ();
  user_t *usr, *old_usr;
  caddr_t full_name = sch_full_proc_name (wi_inst.wi_schema, fn,
      cli_qual (cli), CLI_OWNER (cli));
  query_t *proc = full_name ? sch_proc_def (wi_inst.wi_schema, full_name) : NULL;
  if (!proc)
    {
      err = srv_make_new_error ("42000", "CL...", "Undefined proc %s in cluster call", fn);
      clib_local_call_error (clib, clo, err);
      return;
    }
  if (proc->qr_to_recompile)
    {
      err = NULL;
      proc = qr_recompile (proc, &err);
      if (err)
	{
	  clib_local_call_error (clib, clo, err);
	  return;
	}
    }
  /* if no cli_user this means internal call so do as dba */
  usr = sec_id_to_user (clo->_.call.u_id);
  if (cli->cli_user && !sec_proc_check (proc, usr->usr_id, usr->usr_g_id))
    {
      err =
	  srv_make_new_error ("42000", "CL...", "Exec permission denied in daq proc %s user %s", proc->qr_proc_name, usr->usr_name);
      clib_local_call_error (clib, clo, err);
      return;
    }
  DO_SET (state_slot_t *, ssl, &proc->qr_parms)
  {
    if (SSL_REF_PARAMETER == ssl->ssl_type)
      {
	err = srv_make_new_error ("42000", "AQ002", "Reference parameters not allowed in aq_request");
	clib_local_call_error (clib, clo, err);
	return;
      }
  }
  END_DO_SET ();
  self->thr_func_value = NULL;
  /* make a copy of params for local call since the original is in a pool */
  params_copy = box_copy_tree ((caddr_t) params);
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (params_copy))
    params_copy = (caddr_t *) list (1, params_copy);
  cli->cli_in_daq = clo->_.call.is_txn ? CLI_IN_DAQ : CLI_IN_DAQ_AC;
  old_ac = cli->cli_row_autocommit;
  cli->cli_row_autocommit = 0;
  old_usr = cli->cli_user;
  cli->cli_user = usr;
  err = qr_exec (cli, proc, CALLER_LOCAL, NULL, NULL, NULL, params_copy, NULL, 0);
  cli->cli_user = old_usr;
  cli->cli_in_daq = 0;
  cli->cli_row_autocommit = old_ac;
  dk_free_box ((caddr_t) params_copy);
  val = self->thr_func_value;
  self->thr_func_value = NULL;
  if (LT_PENDING != cli->cli_trx->lt_status && LT_FREEZE != cli->cli_trx->lt_status)
    {
      caddr_t lt_err = srv_make_trx_error (cli->cli_trx->lt_error, cli->cli_trx->lt_error_detail);
      if (clo->_.call.is_txn)
	{
	  dk_free_tree (val);
	  dk_free_tree (err);
	  sqlr_resignal (lt_err);
	  return;
	}
      IN_TXN;
      lt_rollback (cli->cli_trx, TRX_CONT);
      LEAVE_TXN;
      clib_local_call_error (clib, clo, lt_err);
      return;
    }

  if (!clo->_.call.is_txn)
    {
      /* not transactional, autocommit or rb */
      clib_local_autocommit (clib, qi, clo, err);
    }
  if (err)
    {
      dk_free_tree (val);
      if (clo->_.call.is_txn && SQLSTATE_IS_TXN (ERR_STATE (err)))
	sqlr_resignal (err);
      clib_local_call_error (clib, clo, err);
      return;
    }
  row = clo_allocate_2 (CLO_ROW);
  row->clo_seq_no = clo->clo_seq_no;
  row->clo_nth_param_row = clo->clo_nth_param_row;
  row->_.row.cols = (caddr_t *) list (2, box_num (CLO_CALL_RESULT), val);
  basket_add (&clib->clib_in_parsed, (void *) row);
}


void
dpipe_node_local_input (dpipe_node_t * dp, caddr_t * inst, caddr_t * stat)
{
  /* this is a dpipe colocated with the previous node inside a qf.  Call the func */

  caddr_t err;
  du_thread_t *self = THREAD_CURRENT_THREAD;
  QNCAST (query_instance_t, qi, inst);
  caddr_t val = NULL;
  caddr_t *params = (caddr_t *) qst_get (inst, dp->dp_inputs[0]), *params_copy;
  caddr_t fn = dp->dp_funcs[0]->cf_proc;
  client_connection_t *cli = qi ? qi->qi_client : sqlc_client ();
  caddr_t full_name = sch_full_proc_name (wi_inst.wi_schema, fn,
      cli_qual (cli), CLI_OWNER (cli));
  query_t *proc = full_name ? sch_proc_def (wi_inst.wi_schema, full_name) : NULL;
  if (!proc)
    sqlr_new_error ("42000", "CL...", "Undefined proc %s in colocated cluster dpipe call", fn);
  if (proc->qr_to_recompile)
    {
      err = NULL;
      proc = qr_recompile (proc, &err);
      if (err)
	sqlr_resignal (err);
    }
  /* if no cli_user this means internal call so do as dba */
  if (cli->cli_user && !sec_proc_check (proc, cli->cli_user->usr_id, cli->cli_user->usr_g_id))
    sqlr_new_error ("42000", "CL...", "Exec permission denied in daq proc %s user %s", proc->qr_proc_name, cli->cli_user->usr_name);

  DO_SET (state_slot_t *, ssl, &proc->qr_parms)
  {
    if (SSL_REF_PARAMETER == ssl->ssl_type)
      sqlr_new_error ("42000", "AQ002", "Reference parameters not allowed in colocated dpipe");
  }
  END_DO_SET ();
  self->thr_func_value = NULL;
  params_copy = box_copy_tree ((caddr_t) params);
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (params_copy))
    params_copy = (caddr_t *) list (1, params_copy);
  err = qr_exec (cli, proc, CALLER_LOCAL, NULL, NULL, NULL, params_copy, NULL, 0);
  cli->cli_in_daq = 0;
  dk_free_box ((caddr_t) params_copy);
  val = self->thr_func_value;
  self->thr_func_value = NULL;


  if (err)
    {
      dk_free_tree (val);
      sqlr_resignal (err);
    }
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (val) || BOX_ELEMENTS (val) < 2 || !unbox (((caddr_t *) val)[1]))
    sqlr_new_error ("42000", "CL...",
	"A cpipe function with the single action bit (128) must return a result and no follow up actions on the first call");
  qst_set (inst, dp->dp_outputs[0], ((caddr_t *) val)[0]);
  ((caddr_t *) val)[0] = NULL;
  dk_free_tree (val);
  qn_send_output ((data_source_t *) dp, inst);
}

int
clrg_check_local_calls (cl_req_group_t * clrg, query_instance_t * qi)
{
  DO_SET (cll_in_box_t *, clib, &clrg->clrg_clibs)
  {
    if (clib->clib_host->ch_id == local_cll.cll_this_host && clib->clib_local_clo.bsk_count)
      {
	cl_op_t *clo = (cl_op_t *) basket_get (&clib->clib_local_clo);
	switch (clo->clo_op)
	  {
	  case CLO_CALL:
	    cl_local_call (qi, clib, clo);
	    break;
	  case CLO_INSERT:
	    {
	      cl_op_t *row;
	      if (!clo->_.insert.rd->rd_values)
		GPF_T1 ("supposed to have values in local insert in daq");
	      cl_local_insert ((caddr_t *) qi, clo);
	      if (clo->_.insert.is_autocommit)
		if (LTE_OK != clib_local_autocommit (clib, qi, clo, NULL))
		  return 1;	/* if error, result added, go on */
	      row = clo_allocate_2 (CLO_SET_END);
	      row->clo_seq_no = clo->clo_seq_no;
	      row->clo_nth_param_row = clo->clo_nth_param_row;
	      basket_add (&clib->clib_in_parsed, (void *) row);
	      break;
	    }
	  case CLO_DELETE:
	    {
	      cl_op_t *row;
	      if (!clo->_.delete.rd->rd_values)
		GPF_T1 ("supposed to have values in local delete in daq");
	      cl_local_delete ((caddr_t *) qi, clo);
	      row = clo_allocate_2 (CLO_SET_END);
	      row->clo_seq_no = clo->clo_seq_no;
	      row->clo_nth_param_row = clo->clo_nth_param_row;
	      basket_add (&clib->clib_in_parsed, (void *) row);
	      break;
	    }
	  }
	return 1;
      }
  }
  END_DO_SET ();
  return 0;
}


void
clrg_mark_best_effort (cl_req_group_t * clrg)
{
  /* mark the clibs for which send failed as realized */
  int inx;
  DO_SET (cll_in_box_t *, clib, &clrg->clrg_clibs)
  {
    if (!clib->clib_is_error)
      continue;
    for (inx = 0; inx < clrg->clrg_nth_param_row; inx++)
      {
	cl_op_t *set_clo = (cl_op_t *) clrg->clrg_param_rows[inx];
	dk_set_t clibs = set_clo->clo_clibs;
	clo_unlink_clib (set_clo, clib, 0);
	if (clibs && !set_clo->clo_clibs)
	  clrg->clrg_nth_set++;
      }
  }
  END_DO_SET ();
  dk_free_tree (clrg->clrg_error);
  clrg->clrg_error = NULL;
  clrg->clrg_is_error = CLE_OK;
}


void
clrg_call_flush_if_due (cl_req_group_t * clrg)
{

  if (clrg->clrg_nth_set == clrg->clrg_n_sets_requested && clrg->clrg_nth_param_row > clrg->clrg_nth_set)
    {
      clrg->clrg_n_sets_requested = clrg->clrg_nth_param_row;
      if (clrg->clrg_is_error && clrg->clrg_best_effort)
	clrg_mark_best_effort (clrg);
    }
}

cl_op_t *
clrg_call_next (cl_req_group_t * clrg, query_instance_t * qi, cll_in_box_t ** clib_ret)
{
  int n_checked = 0;
  dk_set_t iter;
  cl_op_t *clo;
  if (clrg->clrg_error_end)
    return NULL;
  clrg_call_flush_if_due (clrg);
  if (!clrg->clrg_last)
    clrg->clrg_last = clrg->clrg_clibs;
  for (iter = clrg->clrg_last; iter; iter = iter->next ? iter->next : clrg->clrg_clibs)
    {
      cll_in_box_t *clib = (cll_in_box_t *) iter->data;
      if (clib_has_data (clib))
	{
	  n_checked = 0;
	  dk_free_tree ((caddr_t) clib->clib_first_row);
	  clib->clib_first_row = NULL;
	  *clib_ret = clib;
	  if (clib->clib_host->ch_id == local_cll.cll_this_host)
	    {
	      clo = (cl_op_t *) basket_get (&clib->clib_in_parsed);
	    }
	  else
	    {
	      clib_read_next (clib, NULL, NULL);
	      clo = &clib->clib_first;
	    }
	  if (clo->clo_nth_param_row >= clrg->clrg_nth_param_row)
	    GPF_T1 ("param row no too high");
	  switch (clo->clo_op)
	    {
	    case CLO_ROW:
	      clrg->clrg_last = iter->next;
	      if (CLO_CALL_ROW != unbox (clo->_.row.cols[0]))
		{
		  cl_op_t *set_clo;
		  if (CLO_CALL_ERROR == unbox (clo->_.row.cols[0]))
		    {
		      if (enable_daq_trace)
			{
			  printf ("daq error from %d recd %d ", clib->clib_host->ch_id, clo->clo_nth_param_row);
			  sqlo_box_print ((caddr_t) clo->_.row.cols);
			}
		    }

		  /* this is error or ret val and counts for the end of this clo_call */
		  set_clo = (cl_op_t *) clrg->clrg_param_rows[clo->clo_nth_param_row];
		  clo_unlink_clib (set_clo, clib, 0);
		  if (!set_clo->clo_clibs)
		    {
		      clrg->clrg_nth_set++;
		      return clo;
		    }
		}
	      return clo;
	    case CLO_SET_END:
	      {
		/* this is success of insert and counts towards end of a set */
		cl_op_t *set_clo = (cl_op_t *) clrg->clrg_param_rows[clo->clo_nth_param_row];
		clo_unlink_clib (set_clo, clib, 0);
		if (!set_clo->clo_clibs)
		  {
		    clrg->clrg_nth_set++;
		    return clo;
		  }
		if (clib->clib_host->ch_id == local_cll.cll_this_host)
		  /* local clo's are allocated, so if one is popped off the must free.  Else the caller frees if the lco is local */
		  dk_free_box ((caddr_t) clo);
	      }
	      break;
	    case CLO_ERROR:
	      {
		caddr_t err = clo->_.error.err;
		clo->_.error.err = NULL;
		if (clib->clib_host->ch_id == local_cll.cll_this_host)
		  dk_free_box ((caddr_t) clo);
		clrg->clrg_error_end = 1;
		clrg_check_trx_error (clrg, (caddr_t *) err);
		sqlr_resignal (err);
	      }
	    default:
	      GPF_T1 ("bad clo type returned for a daq");
	    }
	}
      else
	{
	  n_checked++;
	  if (n_checked == dk_set_length (clrg->clrg_clibs))
	    {
	      if (clrg->clrg_nth_set == clrg->clrg_nth_param_row)
		{
		  return NULL;	/* done, as many sets as ordered */
		}
	      /* before waiting, see if there is local calls to do */
	      clrg_call_flush_if_due (clrg);
	      if (clrg_check_local_calls (clrg, qi))
		{
		  n_checked = 0;
		  continue;
		}
	      n_checked = 0;
	      continue;
	    }
	}
    }
  return NULL;
}



#define PART_READ 0		/* reading op, use closest or random, always use local if local has the data */
#define PART_UPD_ALL  1		/* general update to all replicas */
#define PART_UPD_FIRST 2	/* update to primary replica only */
#define PART_UPD_REST 3		/* update non-primary replicas */

void
cl_part_hosts (cluster_map_t * map, cl_host_t ** group, uint32 hash, int32 rem, int is_upd, dk_set_t * hosts)
{
}


caddr_t *
cl_key_locate (dbe_key_t * key, caddr_t * values, int is_upd)
{
  return NULL;
}


cl_req_group_t *
bif_clrg_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp != DV_CLRG)
    sqlr_new_error ("22023", "SR014",
	"Function %s needs a daq as argument %d, not an arg of type %s (%d)", func, nth + 1, dv_type_title (dtp), dtp);
  return (cl_req_group_t *) arg;
}



caddr_t
bif_partition (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* key, part col values, upd flag, returns host list */
  dbe_key_t *key = bif_key_arg (qst, args, 0, "partition");
  caddr_t *vec = bif_array_of_pointer_arg (qst, args, 2, "partition");
  int is_upd = bif_long_arg (qst, args, 3, "partition");
  return (caddr_t) cl_key_locate (key, vec, is_upd);
}


caddr_t
bif_partition_group (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* key, part col values, returns the zero based host group handling the partition */
  dbe_key_t *key = bif_key_arg (qst, args, 0, "partition");
  caddr_t *vec = bif_array_of_pointer_arg (qst, args, 2, "partition");
  caddr_t *hosts = cl_key_locate (key, vec, PART_UPD_FIRST);
  int no, inx, inx2;
  if (!hosts || !key->key_partition || !BOX_ELEMENTS (hosts))
    {
      dk_free_box (hosts);
      return dk_alloc_box (0, DV_DB_NULL);
    }
  no = unbox (hosts[0]);
  dk_free_tree (hosts);
  DO_BOX (cl_host_group_t *, chg, inx, key->key_partition->kpd_map->clm_hosts)
  {
    DO_BOX (cl_host_t *, ch, inx2, chg->chg_hosts)
    {
      if (ch->ch_id == no)
	return box_num (inx);
    }
    END_DO_BOX;
  }
  END_DO_BOX;
  sqlr_new_error ("42000", "CLBAL",
      "partition_group func gets a host number that is not in the groups of the cluster map of the key.");
  return NULL;
}




caddr_t
bif_key_n_partitions (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dbe_key_t *key = bif_key_arg (qst, args, 0, "partition");
  return box_num (key_n_partitions (key));
}


caddr_t
bif_daq (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  int is_txn = bif_long_arg (qst, args, 0, "daq");
  cl_req_group_t *clrg = cl_req_group (qi->qi_trx);
  clrg->clrg_timeout = qi->qi_rpc_timeout;
  clrg->clrg_pool = mem_pool_alloc ();
  clrg->clrg_keep_local_clo = 1;
  if (qi->qi_client->cli_row_autocommit)
    is_txn = 0;
  if (qi->qi_trx->lt_is_excl)
    is_txn = 1;
  clrg->clrg_no_txn = !is_txn;
  return (caddr_t) clrg;
}


#define DAQ_CALL_UPD_MASK 3
#define DAQ_CALL_COPY_FUNC 4
#define DAQ_CALL_COPY_PARAMS 8
#define DAQ_CALL_COPY_IF_LOCAL 16
#define DAQ_CALL_BEST_EFFORT 32
#define DAQ_CALL_CONTROL 64
#define DAQ_CALL_CLI_PERMS 128

#define DAQ_CALL_U_OPT_MASK (DAQ_CALL_UPD_MASK | DAQ_CALL_BEST_EFFORT | DAQ_CALL_CONTROL | DAQ_CALL_CLI_PERMS)

oid_t
qst_effective_u_id (caddr_t * qst)
{
  QNCAST (query_instance_t, qi, qst);
  if (!qi->qi_query->qr_proc_name)
    return qi->qi_u_id;
  else
    return qi->qi_query->qr_proc_owner;
}


caddr_t
daq_call_1 (cl_req_group_t * clrg, dbe_key_t * key, caddr_t fn, caddr_t * vec, int flags, int *first_seq_ret, caddr_t * host_nos)
{
  int is_set = 0;
  dk_set_t res = NULL;
  int inx;
  caddr_t *hosts;
  cl_op_t *clo = mp_clo_allocate (clrg->clrg_pool, CLO_CALL);
  if ((DAQ_CALL_BEST_EFFORT & flags))
    clrg->clrg_best_effort = 1;
  if ((DAQ_CALL_CONTROL & flags))
    clrg->clrg_cm_control = CM_CONTROL;
  if (!host_nos)
    hosts = cl_key_locate (key, vec, DAQ_CALL_UPD_MASK & flags);
  else
    hosts = host_nos;
  if (!BOX_ELEMENTS (hosts))
    {
      if (!host_nos)
	dk_free_box ((caddr_t) hosts);
      return NULL;
    }
  if (!host_nos && !key->key_partition)
    sqlr_new_error ("42000", "CL...", "Key %s must be partition for use with daq", key->key_name);
  if (DAQ_CALL_COPY_FUNC & flags)
    clo->_.call.func = mp_full_box_copy_tree (clrg->clrg_pool, fn);
  else
    clo->_.call.func = fn;
  clo->_.call.is_txn = !clrg->clrg_no_txn;
  clo->_.call.u_id = clrg->clrg_u_id;
  if (DAQ_CALL_COPY_PARAMS & flags)
    clo->_.call.params = (caddr_t *) mp_full_box_copy_tree (clrg->clrg_pool, (caddr_t) vec);
  else
    clo->_.call.params = vec;
  clo->_.call.is_update = flags & DAQ_CALL_UPD_MASK;
  clo->clo_nth_param_row = clrg->clrg_nth_param_row;
  mp_array_add (clrg->clrg_pool, &clrg->clrg_param_rows, &clrg->clrg_nth_param_row, (caddr_t) clo);
  DO_BOX (ptrlong, host, inx, hosts)
  {
    cl_host_t *ch;
    host = unbox ((caddr_t) host);
    if (DAQ_CALL_COPY_IF_LOCAL & flags && host == local_cll.cll_this_host)
      clo->_.call.params = (caddr_t *) mp_full_box_copy_tree (clrg->clrg_pool, (caddr_t) (caddr_t) clo->_.call.params);
    ch = cl_id_to_host (host);
    if (!ch)
      sqlr_new_error ("42000", "CL...", "Bad host no %d in daq_call", (int) host);
    clrg_add (clrg, ch, clo);
    if (first_seq_ret)
      {
	if (!is_set)
	  {
	    *first_seq_ret = clo->clo_seq_no;
	    is_set = 1;
	  }
      }
    else
      dk_set_push (&res, (void *) list (3, box_num (clo->clo_nth_param_row), box_num (host), box_num (clo->clo_seq_no)));
  }
  END_DO_BOX;
  if (!host_nos)
    dk_free_tree (hosts);
  if (res)
    return list_to_array (res);
  return NULL;
}


caddr_t
bif_daq_call (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* clrg, func, args, key */
  caddr_t *host_nos = NULL;
  cl_req_group_t *clrg = bif_clrg_arg (qst, args, 0, "daq_call");
  caddr_t hno = bif_arg (qst, args, 2, "daq_call");
  caddr_t cl_name;
  dbe_key_t *key;
  caddr_t fn = bif_string_arg (qst, args, 3, "daq_call");
  caddr_t *vec = bif_array_of_pointer_arg (qst, args, 4, "daq_call");
  QNCAST (query_instance_t, qi, qst);
  int is_upd = bif_long_arg (qst, args, 5, "daq_call");

  if (CL_RUN_CLUSTER != cl_run_local_only)
    sqlr_new_error ("42000", "CL...", "Cluster operation is not allowed when running as single mode");

  if ((DAQ_CALL_CONTROL & is_upd))
    sec_check_dba (qi, "daq_call with cm_control option");
  else
    CL_ONLINE_CK;
  if (DV_STRINGP (hno))
    key = bif_key_arg (qst, args, 1, "daq_call");
  else
    {
      key = NULL;
      cl_name = bif_string_arg (qst, args, 1, "daq_call");
      host_nos = (caddr_t *) bif_array_of_pointer_arg (qst, args, 2, "daq_call");
    }
  clrg->clrg_u_id = DAQ_CALL_CLI_PERMS & is_upd ? qi->qi_client->cli_user->usr_id : qst_effective_u_id (qst);
  return daq_call_1 (clrg, key, fn, vec, DAQ_CALL_COPY_PARAMS | DAQ_CALL_COPY_FUNC | (is_upd & DAQ_CALL_U_OPT_MASK), NULL,
      host_nos);
}


caddr_t
bif_daq_next (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  cl_req_group_t *clrg = bif_clrg_arg (qst, args, 0, "daq_next");
  query_instance_t *qi = (query_instance_t *) qst;
  cll_in_box_t *clib;
  caddr_t ret = NULL;
  cl_op_t *clo;

  if (CL_RUN_CLUSTER != cl_run_local_only)
    sqlr_new_error ("42000", "CL...", "Cluster operation is not allowed when running as single mode");

  if (clrg->clrg_no_txn && qi->qi_trx->lt_cl_branches)
    sqlr_new_error ("42000", "CL...",
	"Daq call in non-transactional daq not allowed when the transaction has uncommitted cluster branches");

  clo = clrg_call_next (clrg, qi, &clib);
  if (!clo)
    return NULL;
  switch (clo->clo_op)
    {
    case CLO_ROW:
      ret = list (3, box_num (clo->clo_nth_param_row), box_num (clib->clib_host->ch_id), clo->_.row.cols);
      clo->_.row.cols = NULL;
      clib->clib_first_row = NULL;
      break;
    case CLO_SET_END:
      ret = list (2, box_num (clo->clo_nth_param_row), box_num (clib->clib_host->ch_id));
      break;
    }
  if (clib->clib_host->ch_id == local_cll.cll_this_host)
    dk_free_box ((caddr_t) clo);
  return ret;
}


caddr_t
bif_daq_send (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  cl_req_group_t *clrg = bif_clrg_arg (qst, args, 0, "daq_next");
  clrg_call_flush_if_due (clrg);
  return NULL;
}


caddr_t
bif_daq_buffered_bytes (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  cl_req_group_t *clrg = bif_clrg_arg (qst, args, 0, "daq_next");
  int bytes = 0;
  if (clrg->clrg_pool)
    bytes = clrg->clrg_pool->mp_bytes;
  return box_num (clrg->clrg_send_buffered + bytes);
}

caddr_t
daq_call_next_1 (cl_req_group_t * clrg, query_instance_t * qi)
{
  cll_in_box_t *clib;
  cl_op_t *clo;
  for (;;)
    {
      caddr_t ret = NULL;
      clo = clrg_call_next (clrg, qi, &clib);
      if (!clo)
	return NULL;
      switch (clo->clo_op)
	{
	case CLO_ROW:
	  ret = list (3, box_num (clo->clo_seq_no), box_num (clib->clib_host->ch_id), clo->_.row.cols);
	  clo->_.row.cols = NULL;
	  clib->clib_first_row = NULL;
	  if (clib->clib_host->ch_id == local_cll.cll_this_host)
	    dk_free_box ((caddr_t) clo);
	  return ret;
	case CLO_SET_END:
	  {
	    if (clib->clib_host->ch_id == local_cll.cll_this_host)
	      dk_free_box ((caddr_t) clo);
	    return (caddr_t) CLO_SET_END;
	  }
	default:
	  GPF_T1 ("got bad clo op from daq");
	}
    }
}



id_hash_t *name_to_cu_func;
id_hash_t *func_name_to_cu_func;

cu_func_t *
cu_func (caddr_t name, int must_find)
{
  cu_func_t **place;
  if (!name_to_cu_func)
    return NULL;
  place = (cu_func_t **) id_hash_get (name_to_cu_func, (caddr_t) & name);
  if (!place)
    {
      if (must_find)
	sqlr_new_error ("42000", "CL...", "Unknown dpipe operator %s.", name);
      else
	return NULL;
    }
  return *place;
}


cu_line_t *
cu_line (cucurbit_t * cu, cu_func_t * func)
{
  /* is it seen yet */
  DO_SET (cu_line_t *, cul, &cu->cu_lines)
  {
    if (cul->cul_func == func)
      return cul;
  }
  END_DO_SET ();
  {
    NEW_VARZ (cu_line_t, cul);
    memset (cul, 0, sizeof (cu_line_t));
    dk_set_push (&cu->cu_lines, (void *) cul);
    cul->cul_func = func;
    cul->cul_values = id_hash_allocate (141, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
    id_hash_set_rehash_pct (cul->cul_values, 150);
    return cul;
  }
}


void cu_process_return (cucurbit_t * cu, cu_return_t * cur, value_state_t * vs, int seq_no);


void
cu_dispatch (cucurbit_t * cu, value_state_t * vs, cu_func_t * cf, caddr_t val)
{
  int first_seq_no = -1;
  if (cf->cf_dispatch)
    {
      cu_return_t *disp_ret = cf->cf_dispatch (cu, val, vs);
      cu_process_return (cu, disp_ret, vs, 0);
      return;
    }
  /* add a clo_call to the clrg.  Mark that the vs depends on the reply seq nos. */
  if (!cf->cf_1_arg && DV_ARRAY_OF_POINTER != DV_TYPE_OF (val))
    sqlr_new_error ("23023", "CLDPI", "dpipe call of %s needs a vector for argument", cf->cf_name);
  daq_call_1 (cu->cu_clrg, cf->cf_part_key, cf->cf_proc, (caddr_t *) val,
      DAQ_CALL_COPY_IF_LOCAL | cf->cf_is_upd, &first_seq_no, NULL);
  vs->vs_n_steps++;
  if (-1 != first_seq_no)
    sethash ((void *) (ptrlong) first_seq_no, cu->cu_seq_no_to_vs, (void *) vs);
}


void cu_value_known (cucurbit_t * cu, int irow, caddr_t * row, caddr_t * val_ret, caddr_t val);


#if 4 == SIZEOF_CHAR_P

#define VPLACE(cu, ret, irow) \
  ((irow << 12) | ((caddr_t*) ret - (caddr_t*)(cu->cu_rows[irow])))

#define VPLACE_IROW(vp) (((uptrlong)vp) >> 12)
#define VPLACE_ICOL(vp) (((uptrlong)vp) & 0xfff)

#else
#define VPLACE(cu, ret, irow) \
  ( irow < 0 || irow > DPIPE_MAX_ROWS ? (GPF_T1 ("irow out of rng"), 0) : \
((((unsigned int64)irow) << 16) | ((caddr_t*) ret - (caddr_t*)(cu->cu_rows[irow]))))


#define VPLACE_IROW(vp) (((uptrlong)vp) >> 16)
#define VPLACE_ICOL(vp) (((uptrlong)vp) & 0xffff)

#endif

void
cu_set_value (cucurbit_t * cu, value_state_t * vs, caddr_t value)
{
  if (vs->vs_is_value)
    sqlr_new_error ("42000", "CL...", "Only one operation for a dpipe value  may return a result.");
  vs->vs_is_value = 1;
  vs->vs_result = value;
  DO_SET (uptrlong, place, &vs->vs_references)
  {
    int irow = VPLACE_IROW (place);
    int icol = VPLACE_ICOL (place);
    caddr_t *ref = &((caddr_t **) cu->cu_rows)[irow][icol];
    cu_value_known (cu, irow, (caddr_t *) cu->cu_rows[irow], ref, vs->vs_result);
  }
  END_DO_SET ();
}

void
cu_process_return (cucurbit_t * cu, cu_return_t * cur, value_state_t * vs, int seq_no)
{
  int n, inx;
  if (!cur || !unbox ((caddr_t) cur))
    {
      dk_free_tree ((caddr_t) cur);
      return;
    }
  if (!vs)
    vs = (value_state_t *) gethash ((void *) (ptrlong) seq_no, cu->cu_seq_no_to_vs);
  if (!vs)
    sqlr_new_error ("42000", "CL...", "Dpipe internal error, seq no %d received does not correspond to any sent", seq_no);
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (cur) || BOX_ELEMENTS (cur) < 2)
    sqlr_new_error ("42000", "CL...", "A dpipe func's return value must be an array of at least 2 elements");
  if (unbox (cur->cur_is_value))
    {
      if (vs->vs_is_value)
	sqlr_new_error ("42000", "CL...", "Only one operation for a dpipe value  may return a result.");
      vs->vs_is_value = 1;
      vs->vs_result = cur->cur_value;
      cur->cur_value = NULL;
      DO_SET (uptrlong, place, &vs->vs_references)
      {
	int irow = VPLACE_IROW (place);
	int icol = VPLACE_ICOL (place);
	caddr_t *ref = &((caddr_t **) cu->cu_rows)[irow][icol];
	cu_value_known (cu, irow, (caddr_t *) cu->cu_rows[irow], ref, vs->vs_result);
      }
      END_DO_SET ();
    }
  n = BOX_ELEMENTS ((caddr_t *) cur);
  for (inx = 2; inx < n; inx++)
    {
      /* for each next step, dispatch it with the value */
      caddr_t *step = (caddr_t *) cur->cur_step[inx - 2];
      caddr_t step_name = DV_STRINGP (step) ? (caddr_t) step : step[0];
      caddr_t step_args = DV_STRINGP (step) ? vs->vs_result : step[1];
      cu_func_t *cf = cu_func (step_name, 1);
      if (!cf)
	sqlr_new_error ("42000", "CL...", "Unknown dpipe op in dpipe intermediate result %s", cur->cur_step[inx - 2]);
      if (!cf->cf_1_arg && DV_ARRAY_OF_POINTER != DV_TYPE_OF (step_args))
	sqlr_new_error ("42000", "CL...", "step argument in dpipe must be an array");
      cu_dispatch (cu, vs, cf, step_args);
    }
  dk_free_tree ((caddr_t) cur);
}


void cu_clear (cucurbit_t * cu);


caddr_t *
cu_next (cucurbit_t * cu, query_instance_t * qi, int is_flush)
{
  int seq;
  caddr_t *list, val, *daq_ret;
  cl_req_group_t *clrg = cu->cu_clrg;
  for (;;)
    {
      if (!is_flush)
	{
	  if (cu->cu_nth_set == cu->cu_fill)
	    return NULL;	/* all values returned, can still be side effects to process */
	  if (cu->cu_is_ordered)
	    {
	      caddr_t *next = (caddr_t *) cu->cu_rows[cu->cu_nth_set];
	      if (0 == ((ptrlong *) next)[0])
		{
		  if (!cu->cu_allow_redo)
		    cu->cu_rows[cu->cu_nth_set] = NULL;
		  cu->cu_nth_set++;
		  return next;
		}
	    }
	  else
	    {
	      if (cu->cu_ready.bsk_count)
		{
		  caddr_t next = (caddr_t) basket_get (&cu->cu_ready);
		  cu->cu_nth_set++;
		  return (caddr_t *) next;
		}
	    }
	}
      else
	{
	  if (clrg->clrg_nth_param_row == clrg->clrg_nth_set)
	    {
	      return NULL;
	    }
	}
      daq_ret = (caddr_t *) daq_call_next_1 (cu->cu_clrg, qi);
      /*printf ("daq_ret = "); sqlo_box_print (daq_ret); printf ("\n"); */
      if (!daq_ret)
	{
	  /* all responses to sent stuff received.  Send  rest.  If nothing to send, we are fully at end */
	  if (clrg->clrg_all_sent)
	    {
	      sqlr_new_error ("42000", "CL...",
		  "A dpipe has run out of actions but not all rows are realized.  Some action must have terminated without producing a value");
	    }
	  continue;
	}
      if (CLO_SET_END == (ptrlong) daq_ret)
	continue;
      list = (caddr_t *) daq_ret[2];
      if (CLO_CALL_ERROR == unbox (list[0]))
	{
	  val = list[1];
	  list[1] = NULL;
	  dk_free_tree ((caddr_t) daq_ret);
	  if (NULL == val)
	    val = srv_make_new_error ("42000", "CL...", "Unspecified error during dpipe operation");
	  sqlr_resignal (val);
	}
      val = list[1];
      list[1] = NULL;
      seq = unbox (daq_ret[0]);
      dk_free_tree ((caddr_t) daq_ret);
      cu_process_return (cu, (cu_return_t *) val, NULL, seq);
    }
}


void
cu_row_ready (cucurbit_t * cu, int irow)
{
  if (cu->cu_ready_cb)
    {
      if (!cu->cu_rows[irow])
	GPF_T1 ("cu row becomes ready twice");
      cu->cu_ready_cb (cu, (caddr_t *) cu->cu_rows[irow]);
      if (!cu->cu_allow_redo)
	cu->cu_rows[irow] = NULL;
      cu->cu_nth_set++;
      return;
    }
  if (!cu->cu_is_ordered && cu->cu_rows[irow])
    {
      basket_add (&cu->cu_ready, (void *) cu->cu_rows[irow]);
      if (!cu->cu_allow_redo)
	cu->cu_rows[irow] = NULL;
    }
}

void
cu_value_known (cucurbit_t * cu, int irow, caddr_t * row, caddr_t * val_ret, caddr_t val)
{
  int n_unknown;
  if (!row)
    sqlr_new_error ("42000", "CL...", "In a dpipe a value can be returned only once for a given input");
  if (irow != ((ptrlong *) row)[1])
    GPF_T1 ("bad place of value in dpipe");
  n_unknown = --((ptrlong *) row)[0];
  *val_ret = val;
  daq_printf (("known row %d col %d unk left %d v=", irow, (int) ((caddr_t *) val_ret - 2 - (caddr_t *) row), n_unknown));
  daq_print_box ((val));
  if (!n_unknown)
    cu_row_ready (cu, irow);
}

#define V_DONE 0
#define V_PENDING 1


int
cu_value (cucurbit_t * cu, cu_func_t * cf, caddr_t arg, int irow, caddr_t * row, caddr_t * ret)
{
  /* the value comes in.  Register it in its line and if new make a value desc */
  mem_pool_t *pool = cu->cu_clrg->clrg_pool;
  cu_line_t *cul = cu_line (cu, cf);
  value_state_t **place = (value_state_t **) id_hash_get (cul->cul_values, (caddr_t) & arg);
  if (place)
    {
      value_state_t *vs = *place;
      if (vs->vs_is_value)
	{
	  mp_set_push (pool, &vs->vs_references, (void *) VPLACE (cu, ret, irow));
	  cu_value_known (cu, irow, row, ret, vs->vs_result);
	  return V_DONE;
	}
      mp_set_push (pool, &vs->vs_references, (void *) VPLACE (cu, ret, irow));
      return V_PENDING;
    }
  {
    value_state_t *vs = (value_state_t *) mp_alloc (pool, sizeof (value_state_t));
    memset (vs, 0, sizeof (value_state_t));
    vs->vs_org_value = mp_full_box_copy_tree (pool, arg);
    id_hash_set (cul->cul_values, (caddr_t) & vs->vs_org_value, (caddr_t) & vs);
    mp_set_push (pool, &vs->vs_references, (void *) VPLACE (cu, ret, irow));
    cu_dispatch (cu, vs, cf, arg);
    return V_PENDING;
  }
}


void
cu_free (cucurbit_t * cu)
{
  /* called from clrg_destroy */
  caddr_t x;
  DO_SET (cu_line_t *, cul, &cu->cu_lines)
  {
    caddr_t *val;
    value_state_t **vsp, *vs;
    id_hash_iterator_t hit;
    id_hash_iterator (&hit, cul->cul_values);
    while (hit_next (&hit, (caddr_t *) & val, (caddr_t *) & vsp))
      {
	vs = *vsp;
	dk_free_tree (vs->vs_result);
      }
    id_hash_free (cul->cul_values);
    dk_free ((caddr_t) cul, sizeof (cu_line_t));
  }
  END_DO_SET ();
  dk_set_free (cu->cu_lines);
  hash_table_free (cu->cu_seq_no_to_vs);
  while ((x = (caddr_t) basket_get (&cu->cu_ready)));
  if (cu->cu_input_funcs_allocd)
    dk_free_box ((caddr_t) cu->cu_input_funcs);
  if (cu->cu_key_dup)
    hash_table_free (cu->cu_key_dup);
  dk_free ((caddr_t) cu, sizeof (cucurbit_t));
}


void
cu_clear (cucurbit_t * cu)
{
  /* going to reuse with different values */
  cl_req_group_t *clrg = cu->cu_clrg;
  caddr_t x;
  DO_SET (cu_line_t *, cul, &cu->cu_lines)
  {
    caddr_t *val;
    value_state_t **vsp, *vs;
    id_hash_iterator_t hit;
    id_hash_iterator (&hit, cul->cul_values);
    while (hit_next (&hit, (caddr_t *) & val, (caddr_t *) & vsp))
      {
	vs = *vsp;
	dk_free_tree (vs->vs_result);
      }
    id_hash_clear (cul->cul_values);
  }
  END_DO_SET ();
  clrhash (cu->cu_seq_no_to_vs);
  while ((x = (caddr_t) basket_get (&cu->cu_ready)));

  cu->cu_rows = NULL;
  cu->cu_fill = 0;
  cu->cu_nth_set = 0;
  cu->cu_n_redo = 0;
  clrg->clrg_param_rows = NULL;
  clrg->clrg_nth_param_row = 0;
  clrg->clrg_nth_set = 0;
  clrg->clrg_n_sets_requested = 0;
  clrg->clrg_clo_seq_no = 0;
  mp_free (clrg->clrg_pool);
  clrg->clrg_pool = mem_pool_alloc ();
  if (cu->cu_key_dup)
    clrhash (cu->cu_key_dup);
}


caddr_t
bif_dpipe_redo (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  QNCAST (query_instance_t, qi, qst);
  cl_req_group_t *clrg = bif_clrg_arg (qst, args, 0, "dpipe_redo");
  cucurbit_t *cu = clrg->clrg_cu;
  caddr_t *val;
  value_state_t **vsp, *vs;
  id_hash_iterator_t hit;
  if (!cu)
    sqlr_new_error ("42000", "CL...", "Not a dpipe daq");
  if (!cu->cu_allow_redo)
    sqlr_new_error ("42000", "CL...", "dpipe_redo on a dpipe with no redo option");
  cu->cu_n_redo++;
  {
    int ref = clrg->clrg_ref_count;
    int no_txn = clrg->clrg_no_txn;
    mem_pool_t *mp = clrg->clrg_pool;
    clrg->clrg_pool = NULL;
    clrg->clrg_ref_count = 1;
    clrg->clrg_cu = NULL;
    clrg_destroy (clrg);
    memset (clrg, 0, sizeof (cl_req_group_t));
    clrg->clrg_ref_count = ref;
    clrg->clrg_lt = qi->qi_trx;
    clrg->clrg_pool = mp;
    clrg->clrg_cu = cu;
    clrg->clrg_timeout = qi->qi_rpc_timeout;
    clrg->clrg_keep_local_clo = 1;
    clrg->clrg_no_txn = no_txn;

  }
  clrhash (cu->cu_seq_no_to_vs);
  while (basket_get (&cu->cu_ready));

  cu->cu_nth_set = 0;
  clrg->clrg_param_rows = NULL;
  clrg->clrg_nth_param_row = 0;
  clrg->clrg_nth_set = 0;
  clrg->clrg_n_sets_requested = 0;
  /* first loop clears all values, marks all unknown.  2nd loop redispatches all.
   * Must be 2 loops so that rows do not get ready more than once.  Otherwise mark one col unknown, then make it known by dispatch, mark another unknown, then known by dispatch and the row becomes ready twice */
  DO_SET (cu_line_t *, cul, &cu->cu_lines)
  {
    id_hash_iterator (&hit, cul->cul_values);
    while (hit_next (&hit, (caddr_t *) & val, (caddr_t *) & vsp))
      {
	vs = *vsp;
	dk_free_tree (vs->vs_result);
	vs->vs_result = NULL;
	vs->vs_n_steps = 0;
	if (vs->vs_is_value)
	  {
	    DO_SET (uptrlong, place, &vs->vs_references)
	    {
	      int irow = VPLACE_IROW (place);
	      int icol = VPLACE_ICOL (place);
	      caddr_t *row = (caddr_t *) cu->cu_rows[irow];
	      if (!row)
		sqlr_new_error ("42000", "CL...", "In a dpipe a value can be returned only once for a given input");
	      if (irow != ((ptrlong *) row)[1])
		GPF_T1 ("bad place of value in dpipe");
	      ++((ptrlong *) row)[0];
	      row[icol] = NULL;
	    }
	    END_DO_SET ();
	  }
	vs->vs_is_value = 0;
      }
  }
  END_DO_SET ();
  DO_SET (cu_line_t *, cul, &cu->cu_lines)
  {
    id_hash_iterator (&hit, cul->cul_values);
    while (hit_next (&hit, (caddr_t *) & val, (caddr_t *) & vsp))
      {
	vs = *vsp;
	cu_dispatch (cu, vs, cul->cul_func, vs->vs_org_value);
      }
  }
  END_DO_SET ();
  if (cu->cu_key_dup)
    clrhash (cu->cu_key_dup);
  return NULL;
}


caddr_t
bif_dpipe (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int inx, flags;
  query_instance_t *qi = (query_instance_t *) qst;
  cl_req_group_t *clrg = cl_req_group (qi->qi_trx);
  NEW_VARZ (cucurbit_t, cu);
  clrg->clrg_timeout = qi->qi_rpc_timeout;
  clrg->clrg_pool = mem_pool_alloc ();
  clrg->clrg_keep_local_clo = 1;
  clrg->clrg_u_id = qst_effective_u_id (qst);
  cu->cu_clrg = clrg;
  clrg->clrg_cu = cu;
  flags = bif_long_arg (qst, args, 0, "dpipe");
  cu->cu_allow_redo = 0 != (flags & CU_ALLOW_REDO);
  cu->cu_is_ordered = 0 != (flags & CU_ORDERED);
  if (qi->qi_client->cli_row_autocommit)
    flags |= CU_NO_TXN;
  clrg->clrg_no_txn = 0 != (flags & CU_NO_TXN);
  cu->cu_input_funcs = (cu_func_t **) dk_alloc_box (sizeof (caddr_t) * (BOX_ELEMENTS (args) - 1), DV_STRING);
  cu->cu_input_funcs_allocd = 1;
  for (inx = 1; inx < BOX_ELEMENTS (args); inx++)
    {
      caddr_t func_name = bif_string_arg (qst, args, inx, "dpipe");
      cu_func_t *cf = cu_func (func_name, 1);
      cu->cu_input_funcs[inx - 1] = cf;
    }
  cu->cu_seq_no_to_vs = hash_table_allocate (101);
  return (caddr_t) clrg;
}


void
cu_row (cucurbit_t * cu, caddr_t * args)
{
  cl_req_group_t *clrg = cu->cu_clrg;
  mem_pool_t *pool = clrg->clrg_pool;
  int inx;
  caddr_t *row = (caddr_t *) mp_alloc_box_ni (pool, sizeof (caddr_t) * (2 + BOX_ELEMENTS (args)), DV_ARRAY_OF_POINTER);
  ((ptrlong *) row)[0] = BOX_ELEMENTS (args);
  ((ptrlong *) row)[1] = cu->cu_fill;
  mp_array_add (pool, &cu->cu_rows, &cu->cu_fill, (caddr_t) row);
  for (inx = 0; inx < BOX_ELEMENTS (args); inx++)
    {
      int vinx = 2 + inx;
      caddr_t arg = args[inx];
      if (!cu->cu_input_funcs[inx] || DV_DB_NULL == DV_TYPE_OF (arg))
	{
	  row[vinx] = mp_full_box_copy_tree (pool, arg);
	  ((ptrlong *) row)[0]--;
	  if (((ptrlong *) row)[0] == 0)
	    cu_row_ready (cu, cu->cu_fill - 1);
	}
      else
	{
	  cu_value (cu, cu->cu_input_funcs[inx], arg, cu->cu_fill - 1, row, &row[vinx]);
	}
    }
}


cl_req_group_t *
dpipe_allocate (query_instance_t * qi, int flags, int n_ops, char **ops)
{
  int inx;
  cl_req_group_t *clrg = cl_req_group (qi ? qi->qi_trx : NULL);
  NEW_VARZ (cucurbit_t, cu);
  clrg->clrg_pool = mem_pool_alloc ();
  clrg->clrg_keep_local_clo = 1;
  cu->cu_clrg = clrg;
  clrg->clrg_cu = cu;
  if (!qi || qi->qi_client->cli_row_autocommit)
    flags |= CU_NO_TXN;
  cu->cu_is_ordered = 0 != (flags & CU_ORDERED);
  clrg->clrg_no_txn = 0 != (flags & CU_NO_TXN);
  cu->cu_input_funcs = (cu_func_t **) mp_alloc_box (clrg->clrg_pool, sizeof (caddr_t) * n_ops, DV_BIN);
  for (inx = 0; inx < n_ops; inx++)
    {
      caddr_t func_name = ops[inx];
      cu_func_t *cf = cu_func (func_name, 1);
      cu->cu_input_funcs[inx] = cf;
    }
  cu->cu_seq_no_to_vs = hash_table_allocate (101);
  return clrg;
}


void
cu_ssl_row (cucurbit_t * cu, caddr_t * qst, state_slot_t ** args, int first_ssl)
{
  int inx, zeros = 0;
  mem_pool_t *pool = cu->cu_clrg->clrg_pool;
  caddr_t *row = (caddr_t *) mp_alloc_box (pool, sizeof (caddr_t) * (2 + BOX_ELEMENTS (args) - first_ssl), DV_ARRAY_OF_POINTER);
  ((ptrlong *) row)[0] = BOX_ELEMENTS (args) - first_ssl;
  ((ptrlong *) row)[1] = cu->cu_fill;
  mp_array_add (pool, &cu->cu_rows, &cu->cu_fill, (caddr_t) row);
  if (BOX_ELEMENTS (args) - first_ssl > DPIPE_MAX_LANES)
    sqlr_new_error ("42000", "CL...", "Dpipe cannot have more than %d operators", DPIPE_MAX_LANES);
  if (BOX_ELEMENTS (cu->cu_input_funcs) != BOX_ELEMENTS (args) - first_ssl)
    sqlr_new_error ("07000", "CL...", "Bad number of arguments for dpipe");

  for (inx = first_ssl; inx < BOX_ELEMENTS (args); inx++)
    {
      int vinx = 2 + inx - first_ssl;	/* inx of value on the cu row */
      caddr_t arg = qst_get (qst, args[inx]);
      if (!cu->cu_input_funcs[inx - first_ssl] || DV_DB_NULL == DV_TYPE_OF (arg))
	{
	  row[vinx] = mp_full_box_copy_tree (pool, arg);
	  ((ptrlong *) row)[0]--;
	  if (((ptrlong *) row)[0] == 0)
	    {
	      cu_row_ready (cu, cu->cu_fill - 1);
	    }
	}
      else
	{
	  cu_value (cu, cu->cu_input_funcs[inx - first_ssl], arg, cu->cu_fill - 1, row, &row[vinx]);
	}
    }
  for (inx = 2; inx < BOX_ELEMENTS (row); inx++)
    if (!row[inx])
      zeros++;
  daq_printf (("Row %d added: ", (int) ((ptrlong *) row)[1]));
  daq_print_box ((row));
}


caddr_t
bif_dpipe_input (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  cl_req_group_t *clrg = bif_clrg_arg (qst, args, 0, "dpipe_input");
  cucurbit_t *cu = clrg->clrg_cu;
  CL_ONLINE_CK;
  if (!cu)
    sqlr_new_error ("42000", "CL...", "Not a dpipe daq");
  cu->cu_qst = qst;
  cu_ssl_row (cu, qst, args, 1);
  return NULL;
}


caddr_t
bif_dpipe_next (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *row;
  cl_req_group_t *clrg = bif_clrg_arg (qst, args, 0, "dpipe_next");
  cucurbit_t *cu = clrg->clrg_cu;
  int is_flush = bif_long_arg (qst, args, 1, "dpipe_next");
  if (!cu)
    sqlr_new_error ("42000", "CL...", "Not a dpipe daq");
  cu->cu_qst = qst;
  row = cu_next (cu, (query_instance_t *) qst, is_flush);
  if (row)
    {
      int len = BOX_ELEMENTS (row) - 2, inx;
      caddr_t *copy = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * len, DV_ARRAY_OF_POINTER);
      for (inx = 0; inx < len; inx++)
	copy[inx] = box_copy_tree (row[inx + 2]);
      return (caddr_t) copy;
    }
  return NULL;
}


caddr_t
bif_dpipe_count (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  cl_req_group_t *clrg = bif_clrg_arg (qst, args, 0, "dpipe_count");
  cucurbit_t *cu = clrg->clrg_cu;
  if (!cu)
    sqlr_new_error ("42000", "CL...", "Not a dpipe daq");
  return box_num (cu->cu_fill);
}


caddr_t
bif_dpipe_reuse (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  cl_req_group_t *clrg = bif_clrg_arg (qst, args, 0, "dpipe_reuse");
  cucurbit_t *cu = clrg->clrg_cu;
  if (!cu)
    sqlr_new_error ("42000", "CL...", "Not a dpipe daq");
  cu_clear (cu);
  return NULL;
}


#define CF_UPD_FLAGS(f) ( f & CF_UPDATE ? PART_UPD_ALL : \
			  f & CF_FIRST_RW ? PART_UPD_FIRST : \
			  f & CF_REST_RW ? PART_UPD_REST : PART_READ)

caddr_t
bif_dpipe_define (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "dpipe_define");
  dbe_key_t *key = bif_key_arg (qst, args, 1, "dpipe_define");
  caddr_t fn = bif_string_arg (qst, args, 3, "dpipe_define");
  int l = bif_long_arg (qst, args, 4, "dpipe_define");
  NEW_VARZ (cu_func_t, cf);
  cf->cf_name = box_copy (name);
  cf->cf_part_key = key;
  cf->cf_proc = box_copy (fn);
  cf->cf_is_upd = CF_UPD_FLAGS (l);
  if (CF_SINGLE_ACTION & l)
    cf->cf_single_action = 1;
  if (BOX_ELEMENTS (args) > 5)
    {
      cf->cf_call_proc = box_copy (bif_string_or_null_arg (qst, args, 5, "dpipe_define"));
      cf->cf_call_bif = box_copy (bif_string_or_null_arg (qst, args, 6, "dpipe_define"));
      cf->cf_extra = box_copy_tree (bif_arg (qst, args, 7, "dpipe_define"));
    }
  id_hash_set (name_to_cu_func, (caddr_t) & cf->cf_name, (caddr_t) & cf);
  return NULL;
}


caddr_t
bif_cl_is_autocommit (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* true if running inside a daq called proc in non transactional daq */
  query_instance_t *qi = (query_instance_t *) qst;
  client_connection_t *cli = qi->qi_client;
  return box_num (CLI_IN_DAQ_AC == cli->cli_in_daq);
}


caddr_t
bif_cl_daq_client (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* true if running inside a daq called proc in non transactional daq */
  query_instance_t *qi = (query_instance_t *) qst;
  client_connection_t *cli = qi->qi_client;
  cl_thread_t *clt = cli->cli_clt;
  if (!clt)
    {
      if (cli->cli_in_daq)
	return box_num (local_cll.cll_this_host);
      return box_num (-1);
    }
  if (!clt->clt_current_cm)
    return box_num (-1);
  return box_num (clt->clt_current_cm->cm_from_host);
}


void
dpipe_refresh_schema ()
{
  DO_IDHASH (caddr_t, name, cu_func_t *, cf, name_to_cu_func)
  {
    if (cf)
      {
	dbe_key_t *old = cf->cf_part_key;
	if (old)
	  cf->cf_part_key = sch_id_to_key (wi_inst.wi_schema, old->key_id);
      }
  }
  END_DO_IDHASH;
}


void
dpipe_define (caddr_t name, dbe_key_t * key, caddr_t fn, cu_op_func_t fn_disp, int l)
{
  NEW_VARZ (cu_func_t, cf);
  cf->cf_name = box_dv_short_string (name);
  cf->cf_dispatch = fn_disp;
  cf->cf_part_key = key;
  cf->cf_proc = box_dv_short_string (fn);
  cf->cf_is_upd = CF_UPD_FLAGS (l);
  cf->cf_1_arg = l & CF_1_ARG;
  id_hash_set (name_to_cu_func, (caddr_t) & cf->cf_name, (caddr_t) & cf);
}


void
dpipe_signature (caddr_t name, int n_args, ...)
{
  sql_type_t *box;
  va_list ap;
  int inx;
  cu_func_t *cf = cu_func (name, 1);
  va_start (ap, n_args);
  box = (sql_type_t *) dk_alloc_box_zero (sizeof (sql_type_t) * n_args, DV_BIN);
  for (inx = 0; inx < n_args; inx++)
    {
      int dtp = va_arg (ap, int);
      box[inx].sqt_dtp = dtp;
    }
  va_end (ap);
  cf->cf_arg_sqt = box;
}



char *dp_no_err =
    "create procedure dpipe_define_no_err (in DP_NAME any, in DP_PART_TABLE any, in DP_PART_KEY any, in DP_SRV_PROC any, in DP_IS_UPD any, in DP_CALL_PROC any, in DP_CALL_BIF any, in DP_EXTRA any)\n"
    "{\n"
    "  declare exit handler for sqlstate '*' {\n"
    "   log_message (sprintf ('error in dpipe init %s %s', __sql_state, __sql_message)); return;\n"
    "};\n"
    "dpipe_define_1 (DP_NAME, DP_PART_TABLE, DP_PART_KEY, DP_SRV_PROC, DP_IS_UPD, DP_CALL_PROC, DP_CALL_BIF, DP_EXTRA);\n" "}\n";


void
cl_read_dpipes ()
{
  ddl_std_proc (dp_no_err, 0);
  ddl_ensure_table ("do_this_always",
      "select count (*) from SYS_DPIPE where 0 = dpipe_define_no_err (DP_NAME, DP_PART_TABLE, DP_PART_KEY, DP_SRV_PROC, DP_IS_UPD, DP_CALL_PROC, DP_CALL_BIF, DP_EXTRA)");
}


void
bif_daq_init ()
{
  bif_define ("daq", bif_daq);
  bif_define ("daq_call", bif_daq_call);
  bif_define ("daq_next", bif_daq_next);
  bif_define ("daq_send", bif_daq_send);
  bif_define ("daq_buffered_bytes", bif_daq_buffered_bytes);
  name_to_cu_func = id_casemode_hash_create (11);
  func_name_to_cu_func = id_casemode_hash_create (11);
  bif_define ("dpipe", bif_dpipe);
  bif_set_no_cluster ("dpipe");
  bif_define ("dpipe_input", bif_dpipe_input);
  bif_set_no_cluster ("dpipe_input");
  bif_define ("dpipe_next", bif_dpipe_next);
  bif_set_no_cluster ("dpipe_next");
  bif_define ("dpipe_define_1", bif_dpipe_define);
  bif_define ("dpipe_count", bif_dpipe_count);
  bif_define ("dpipe_reuse", bif_dpipe_reuse);
  bif_define ("dpipe_redo", bif_dpipe_redo);
  bif_set_no_cluster ("dpipe_redo");
  bif_define ("cl_is_autocommit", bif_cl_is_autocommit);
  bif_define ("cl_daq_client", bif_cl_daq_client);
  {
    /* define identity as identity op for dpipe */
    caddr_t es = box_dv_short_string ("identity");
    caddr_t n = NULL;
    id_hash_set (name_to_cu_func, (caddr_t) & es, (caddr_t) & n);
  }
}

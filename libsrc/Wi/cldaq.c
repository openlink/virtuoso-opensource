/*
 *  $Id$
 *
 *  Cluster RPC for PL
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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
#include "sqlparext.h"


#if 0
#define daq_printf(a) printf a
#define daq_print_box(a) sqlo_box_print a
#else
#define daq_printf(a)
#define daq_print_box(a)
#endif


#define DAQ_CALL_UPD_MASK 3
#define DAQ_CALL_COPY_FUNC 4
#define DAQ_CALL_COPY_PARAMS 8
#define DAQ_CALL_COPY_IF_LOCAL 16
#define DAQ_CALL_BEST_EFFORT 32
#define DAQ_CALL_CONTROL 64
#define DAQ_CALL_CLI_PERMS 128
#define DAQ_CALL_VEC 256
#define DAQ_CALL_U_OPT_MASK (DAQ_CALL_UPD_MASK | DAQ_CALL_BEST_EFFORT | DAQ_CALL_CONTROL | DAQ_CALL_CLI_PERMS)


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
  int64 main_trx_no;
  caddr_t detail = NULL;
  if (!qi)
    return LTE_OK;		/* if run inside compiler */
  cli = qi->qi_client;
  main_trx_no = cli->cli_trx->lt_main_trx_no;
  if (err)
    {
      IN_TXN;
      lt_rollback (cli->cli_trx, TRX_CONT);
      LEAVE_TXN;
    }
  else
    {
      int rc;
      if (LT_PENDING == cli->cli_trx->lt_status && (cli->cli_trx->lt_cl_branches || cli->cli_trx->lt_cl_enlisted
	      || cli->cli_trx->lt_cl_main_enlisted))
	return LTE_OK;		/* if for other reasons this has enlisted contenty do not commit the enclosing txn.  makes half transactions and really fucks over remote branches */
      if (cli->cli_trx->lt_remotes)
	return LTE_OK; /* if local daq call, whether recursive or not there is an enclosing context hat will transact the remotes, transacting remote in mid qr w open cursor will kill the cursor */
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
  cli->cli_trx->lt_main_trx_no = main_trx_no;
  return LTE_OK;
}

extern state_slot_t ssl_set_no_dummy;


cl_op_t *
clrg_vec_call_clo (cl_req_group_t * clrg, caddr_t full_name, int add_set_no, dbe_key_t * key, int flags, int make_new)
	{
  /* make a call clo with dcs corresponding to proc params.  if add set no, add an extra int dc at the end to correlate result rows with daq/dp set nos */
  if (!make_new)
  {
      DO_SET (cl_op_t *, clo, &clrg->clrg_vec_clos)
      {
	if (CLO_CALL == clo->clo_op && !stricmp (full_name, clo->_.call.func))
	  return clo;
  }
  END_DO_SET ();
    }
{
    mem_pool_t *mp = clrg->clrg_pool;
    query_t *qr = sch_proc_def (wi_inst.wi_schema, full_name);
    int n;
    cl_op_t *clo = mp_clo_allocate (mp, CLO_CALL);
    int fill = 0;
    if (!qr)
      sqlr_new_error ("42001", "CLVEC", "Undefd proc in vectored daq call %s", full_name);
    if (qr->qr_to_recompile)
    {
	caddr_t err = NULL;
	qr = qr_recompile (qr, &err);
      if (err)
	sqlr_resignal (err);
    }
    mp_set_push (mp, &clrg->clrg_vec_clos, (void *) clo);
    n = dk_set_length (qr->qr_parms) + add_set_no;
    clo->_.call.func = mp_full_box_copy_tree (mp, qr->qr_proc_name);
    clo->_.call.params = (caddr_t *) mp_alloc_box (mp, n * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
    clo->_.call.is_update = flags & DAQ_CALL_UPD_MASK;
    clo->_.call.non_txn_insert = clrg->clrg_no_txn;
    DO_SET (state_slot_t *, par, &qr->qr_parms)
  {
      clo->_.call.params[fill++] = (caddr_t) mp_data_col (mp, par, 1000);
  }
  END_DO_SET ();
    if (add_set_no)
      clo->_.call.params[fill] = (caddr_t) mp_data_col (mp, &ssl_set_no_dummy, 1000);
    clo->_.call.key = key;
    clo->_.call.is_txn = !clrg->clrg_no_txn;
    clo->_.call.u_id = clrg->clrg_u_id;
    clo->_.call.is_update = flags & DAQ_CALL_UPD_MASK;
    clo->clo_nth_param_row = clrg->clrg_nth_param_row;
    mp_array_add (clrg->clrg_pool, &clrg->clrg_param_rows, &clrg->clrg_nth_param_row, (caddr_t) clo);
    return clo;
    }
}

void
ssl_from_dc (state_slot_t * ssl, data_col_t * dc, ssl_index_t * ctr)
	  {
  memzero (ssl, sizeof (state_slot_t));
  ssl->ssl_type = SSL_VEC;
  ssl->ssl_sqt.sqt_dtp = dc->dc_dtp;
  ssl->ssl_index = (*ctr)++;
  ssl->ssl_box_index = (*ctr)++;
}


#define CL_NONE_IN_SLICE ((caddr_t)0x11)
#define CL_MAX_PARAMS 16

caddr_t
cl_vec_exec (query_t * qr, client_connection_t * cli, mem_pool_t * mp, caddr_t * params, slice_id_t * slices, slice_id_t slid,
    db_buf_t * set_mask_ret, data_col_t ** dc_ret, int set_no_in_params)
  {
  char temp[sizeof (query_instance_t) + 2 * CL_MAX_PARAMS * sizeof (caddr_t)];
  state_slot_t ssls[CL_MAX_PARAMS];
  query_instance_t *qi = (query_instance_t *) & temp;
  db_buf_t set_mask = NULL;
  caddr_t *inst = (caddr_t *) qi, err = NULL;
  ssl_index_t ssl_inx = sizeof (query_instance_t) / sizeof (caddr_t);
  int n = BOX_ELEMENTS (params) - set_no_in_params;
  state_slot_t **ssl_pars;
  state_slot_t *ret_ssl = NULL;
  int n_sets = ((data_col_t **) params)[0]->dc_n_values, inx, any = 0;
  AUTO_POOL (sizeof (caddr_t) * 2 * CL_MAX_PARAMS);
  if (slices)
    {
      int set_bytes = ALIGN_8 (n_sets) / 8, set;
      set_mask = *set_mask_ret;
      if (!set_mask || box_length (set_mask) < set_bytes)
	*set_mask_ret = set_mask = (db_buf_t) mp_alloc_box (mp, set_bytes, DV_BIN);
      memzero (set_mask, set_bytes);
      for (set = 0; set < n_sets; set++)
	{
	  if (slid == slices[set])
	    {
	      any = 1;
	      BIT_SET (set_mask, set);
	    }
	}
      if (!any)
	return CL_NONE_IN_SLICE;
    }
  if (n > CL_MAX_PARAMS - 4)
    return srv_make_new_error ("42000", "CLVEC", "Too many params/cols in cluster daq exec");
  if (dc_ret)
    n--;			/* if ret dc, the last param is an array of set nos that is not passed to the func */
  ssl_pars = (state_slot_t **) ap_alloc_box (&ap, n * sizeof (caddr_t), DV_BIN);
  memzero (inst, sizeof (query_instance_t) + (n * 2 + 2) * sizeof (caddr_t));
  qi->qi_set_mask = set_mask;
  qi->qi_isolation = default_txn_isolation;
  for (inx = 0; inx < n; inx++)
    {
      data_col_t *dc = (data_col_t *) params[inx];
      ssl_pars[inx] = &ssls[inx];
      ssl_from_dc (&ssls[inx], dc, &ssl_inx);
      n_sets = dc->dc_n_values;
      QST_BOX (data_col_t *, inst, ssls[inx].ssl_index) = dc;
    }
  if (dc_ret)
    {
      caddr_t *proc_ret = (caddr_t *) qr->qr_proc_ret_type;
      if (!proc_ret)
	return srv_make_new_error ("42000", "CLVEC", "daq/dpipe func does not specify a return type");
      ret_ssl = &ssls[n + 1];
      memzero (ret_ssl, sizeof (state_slot_t));
      ret_ssl->ssl_index = ssl_inx++;
      ret_ssl->ssl_box_index = ssl_inx++;
      ret_ssl->ssl_type = SSL_VEC;
      ret_ssl->ssl_sqt.sqt_dtp = unbox (((caddr_t *) proc_ret)[0]);
      ssl_set_dc_type (ret_ssl);
      inst[ret_ssl->ssl_index] = (caddr_t) (*dc_ret = mp_data_col (mp, ret_ssl, n_sets));
    }
  qi->qi_n_sets = n_sets;
  qi->qi_thread = THREAD_CURRENT_THREAD;
  qi->qi_trx = cli->cli_trx;
  qi->qi_non_txn_insert = cli->cli_non_txn_insert;
  qi->qi_client = cli;
  err = qr_subq_exec_vec (cli, qr, qi, NULL, 0, ssl_pars, ret_ssl, NULL, NULL);
  cli_set_slice (cli, NULL, QI_NO_SLICE, NULL);
  DO_BOX (state_slot_t *, ssl, inx, ssl_pars) dk_free_tree (inst[ssl->ssl_box_index]);
  END_DO_BOX;
  return err;
}


cll_in_box_t *clrg_ensure_single_clib (cl_req_group_t * clrg);


void
clrg_local_ins_del_single (cl_req_group_t * clrg)
			{
  cll_in_box_t *deflt_clib = clrg_ensure_single_clib (clrg);
  QNCAST (query_instance_t, qi, clrg->clrg_inst);
  db_buf_t set_mask = NULL;
  DO_SET (cl_op_t *, clo, &clrg->clrg_vec_clos)
		    {
    if (CLO_INSERT == clo->clo_op || CLO_DELETE == clo->clo_op)
	      {
	row_delta_t *rd = clo->_.insert.rd;
	caddr_t err = NULL;
	query_t *qr = cl_ins_del_qr (rd->rd_key, clo->clo_op, clo->_.insert.ins_mode, &err);
	if (err)
		  {
	    clrg_dml_free (clrg);
		sqlr_resignal (err);
	      }
	if (CLO_DELETE == clo->clo_op)
	  cls_vec_del_rd_layout (clo->_.delete.rd);
	err = NULL;
	qi->qi_client->cli_non_txn_insert = CLO_INSERT == clo->clo_op && clo->_.insert.non_txn;
	err = cl_vec_exec (qr, qi->qi_client, clrg->clrg_pool, clo->_.insert.rd->rd_values, NULL, QI_NO_SLICE, &set_mask, NULL, 0);
	qi->qi_client->cli_non_txn_insert = 0;
	if (err)
		{
	    clrg_dml_free (clrg);
	    return;
	    sqlr_resignal (err);
	    }
	}
    }
  END_DO_SET ();
  clrg_dml_free (clrg);
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
cl_key_locate (dbe_key_t * key, caddr_t * values, int is_upd, slice_id_t * slid_ret)
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
bif_cl_set_slice (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* key, slice no, opt keep setting  */
  QNCAST (query_instance_t, qi, qst);
  dbe_key_t *key = bif_key_arg (qst, args, 0, "cl_set_slice");
  caddr_t slid = bif_arg (qst, args, 2, "cl_set_slice");
  int keep = BOX_ELEMENTS (args) > 3 ? bif_long_arg (qst, args, 3, "cl_set_slice") : 0;
  if (!key->key_partition || !key->key_partition->kpd_map->clm_is_elastic)
    return NULL;
  if (DV_LONG_INT == DV_TYPE_OF (slid))
    {
      cli_set_slice (qi->qi_client, key->key_partition->kpd_map, unbox (slid), NULL);
      if (keep)
	qi->qi_client->cli_keep_csl = 1;
    }
  else
    {
      cli_set_slice (qi->qi_client, NULL, QI_NO_SLICE, NULL);
      qi->qi_client->cli_keep_csl = 0;
    }
  return NULL;
}


caddr_t
bif_partition (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* key, part col values, upd flag, returns host list */
  dbe_key_t *key = bif_key_arg (qst, args, 0, "partition");
  caddr_t *vec = bif_array_of_pointer_arg (qst, args, 2, "partition");
  int is_upd = bif_long_arg (qst, args, 3, "partition");
  slice_id_t slid;
  caddr_t *hosts = cl_key_locate (key, vec, is_upd, &slid);
  if (BOX_ELEMENTS (args) > 4 && ssl_is_settable (args[4]))
    qst_set (qst, args[4], box_num (slid));
  return (caddr_t) hosts;
}


caddr_t
bif_partition_group (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* key, part col values, returns the zero based host group handling the partition */
  dbe_key_t *key = bif_key_arg (qst, args, 0, "partition");
  caddr_t *vec = bif_array_of_pointer_arg (qst, args, 2, "partition");
  slice_id_t slid;
  caddr_t *hosts = NULL;
  int no;
  if (!key->key_partition)
    return dk_alloc_box (0, DV_DB_NULL);
  hosts = cl_key_locate (key, vec, PART_UPD_FIRST, &slid);
  if (!hosts || !BOX_ELEMENTS (hosts))
    {
      dk_free_box (hosts);
      return dk_alloc_box (0, DV_DB_NULL);
    }
  no = unbox (hosts[0]);
  dk_free_tree (hosts);
  return box_num (slid);
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
  clrg_top_check (clrg, qi_top_qi ((QI *) qst));
  if (qi->qi_client->cli_row_autocommit)
    is_txn = 0;
  if (qi->qi_trx->lt_is_excl)
    is_txn = 1;
  clrg->clrg_no_txn = !is_txn;
  return (caddr_t) clrg;
}


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
bif_daq_buffered_bytes (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  cl_req_group_t *clrg = bif_clrg_arg (qst, args, 0, "daq_next");
  int bytes = 0;
  if (clrg->clrg_pool)
    bytes = clrg->clrg_pool->mp_bytes;
  return box_num (clrg->clrg_send_buffered + bytes);
}



id_hash_t *name_to_cu_func;
//id_hash_t * func_name_to_cu_func;

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
    cul->cul_values->ht_allow_dups = 1;
    id_hash_set_rehash_pct (cul->cul_values, 150);
    return cul;
  }
}


void cu_process_return (cucurbit_t * cu, cu_return_t * cur, value_state_t * vs, int seq_no);


void
cf_set_vec (cu_func_t * cf)
{
  query_t *proc = sch_proc_def (wi_inst.wi_schema, cf->cf_proc);
  if (!proc)
    sqlr_new_error ("42000", "CL...", "Undefined proc %s in dpipe call", cf->cf_proc);
  if (proc->qr_to_recompile)
    {
      caddr_t err = NULL;
      proc = qr_recompile (proc, &err);
      if (err)
	sqlr_resignal (err);
    }
  cf->cf_vec_checked = 1;
  cf->cf_is_vec = 0 != proc->qr_proc_vectored;
}


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
  NO_CL;
}


void cu_value_known (cucurbit_t * cu, int irow, caddr_t * row, caddr_t * val_ret, caddr_t val);


#if (SIZEOF_VOID_P == 4)

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
  caddr_t *next;
  if (cu->cu_nth_set == cu->cu_fill)
    return NULL;
  next = (caddr_t *) cu->cu_rows[cu->cu_nth_set];
  cu->cu_nth_set++;
  return next;
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
  if (cu->cu_rdf_last_g)
    dk_free_tree (cu->cu_rdf_last_g);
  dk_free ((caddr_t) cu, sizeof (cucurbit_t));
}


void
cu_clear (cucurbit_t * cu)
{
  /* going to reuse with different values */
  mem_pool_t *new_pool;
  cl_req_group_t *clrg = cu->cu_clrg;
  caddr_t x;
  clrg->clrg_send_time = 0;
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
  clrg->clrg_vec_clos = NULL;
  DO_SET (cll_in_box_t *, clib, &clrg->clrg_clibs)
  {
      clib->clib_keep_alive = 0;
    clib->clib_dc_read = NULL;
    clib->clib_vec_clos = NULL;
  }
  END_DO_SET ();
  new_pool = mem_pool_alloc ();
  clrg->clrg_slice_clibs = (cll_in_box_t **) mp_box_copy (new_pool, (caddr_t) clrg->clrg_slice_clibs);
  mp_free (clrg->clrg_pool);
  clrg->clrg_pool = new_pool;
  clrg->clrg_host_clibs = NULL;
  if (cu->cu_key_dup)
    clrhash (cu->cu_key_dup);
  cu->cu_qst = NULL;
  cu->cu_clrg->clrg_inst = NULL;
}


caddr_t
dpipe_redo (cl_req_group_t * clrg, caddr_t * qst)
{
  QNCAST (query_instance_t, qi, qst);
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
bif_dpipe_redo (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  cl_req_group_t *clrg = bif_clrg_arg (qst, args, 0, "dpipe_redo");
  return dpipe_redo (clrg, qst);
}


caddr_t
bif_dpipe (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int inx, flags, is_upd = 0;
  query_instance_t *qi = (query_instance_t *) qst;
  cl_req_group_t *clrg = cl_req_group (qi->qi_trx);
  NEW_VARZ (cucurbit_t, cu);
  clrg->clrg_timeout = qi->qi_rpc_timeout;
  clrg->clrg_pool = mem_pool_alloc ();
  clrg->clrg_keep_local_clo = 1;
  clrg->clrg_u_id = qst_effective_u_id (qst);
  clrg_top_check (clrg, qi_top_qi (qi));
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
      if (cf->cf_is_upd)
	is_upd = 1;
    }
  if (!is_upd)
    cu->cu_clrg->clrg_no_txn = 1;
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
  if (qi)
    clrg_top_check (clrg, qi);
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
	  if ((cu->cu_fill - 1) > DPIPE_MAX_ROWS)
	    sqlr_new_error ("42000", "CL...", "Dpipe cannot have more than %d rows", DPIPE_MAX_ROWS);
	  cu_value (cu, cu->cu_input_funcs[inx - first_ssl], arg, cu->cu_fill - 1, row, &row[vinx]);
	}
    }
  for (inx = 2; inx < BOX_ELEMENTS (row); inx++)
    if (!row[inx])
      zeros++;
  daq_printf (("Row %d added: ", (int) ((ptrlong *) row)[1]));
  daq_print_box ((row));
}

void cl_rdf_call_insert_cb (cucurbit_t * cu, caddr_t * qst, caddr_t * err_ret);
caddr_t bif_rollback (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
void rb_id_serialize (rdf_box_t * rb, dk_session_t * ses);
void cu_rl_local_exec (cucurbit_t * cu);

/* deserialize GSPO string into an array */
caddr_t *
cu_ld_row (caddr_t str)
{
  int i;
  dk_session_t ses;
  scheduler_io_data_t sio;
  dk_set_t set = NULL;
  ROW_IN_SES_2 (ses, sio, str, box_length (str) - 1);
  for (i = 0; i < 4; i++)
    dk_set_push (&set, read_object (&ses));
  return (caddr_t *) list_to_array (dk_set_nreverse (set));
}

/* serialize GSPO as a string */
caddr_t
cu_ld_str (caddr_t * row, int tmp)
{
  char buf[64];
  dk_session_t ses;
  caddr_t ret;
  ROW_OUT_SES (ses, buf);
  ses.dks_out_fill = 0;
  iri_id_write ((iri_id_t *) (row[0]), &ses);
  iri_id_write ((iri_id_t *) (row[1]), &ses);
  iri_id_write ((iri_id_t *) (row[2]), &ses);
  if (DV_TYPE_OF (row[3]) == DV_RDF)
    rb_id_serialize ((rdf_box_t *) (row[3]), &ses);
  else
    print_object (row[3], &ses, NULL, NULL);
  if (!tmp)
    ret = box_dv_short_nchars (buf, ses.dks_out_fill);
  else
    ret = t_box_dv_short_nchars (buf, ses.dks_out_fill);
  return ret;
}

void
cu_ld_store_rows (cucurbit_t * cu, caddr_t * qst, caddr_t * err_ret)
{
  ptrlong one = 1;
  caddr_t tmp[64];
  caddr_t *row;
  int inx;
  QNCAST (query_instance_t, qi, qst);
  BOX_AUTO_TYPED (caddr_t *, row, tmp, 4 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);

  cu->cu_clrg->clrg_inst = cu->cu_qst = qst;
fetch_again:
  QR_RESET_CTX
  {
    if (CL_RUN_LOCAL == cl_run_local_only)
      cu_rl_local_exec (cu);
  }
  QR_RESET_CODE
  {
    caddr_t err = subq_handle_reset (qi, reset_code);
    POP_QR_RESET;
    /*log_error ("RDF CB COMPLETE: %s %s", ERR_STATE (err), ERR_MESSAGE (err)); */
    if (ARRAYP (err) && !strcmp (ERR_STATE (err), "40001"))
      {
	dk_free_tree (err);
	err = NULL;
	bif_rollback (qst, &err, NULL);
	if (CLI_IN_DAQ_AC == qi->qi_client->cli_in_daq)
	  goto fetch_again;
	dpipe_redo (cu->cu_clrg, qst);
	goto fetch_again;
      }
    sqlr_resignal (err);
  }
  END_QR_RESET;
  bif_commit (qst, err_ret, NULL);
  if (*err_ret)
    {
      log_error ("CL RDF: %s %s", ERR_STATE (*err_ret), ERR_MESSAGE (*err_ret));
      dk_free_tree (*err_ret);
      *err_ret = NULL;
    }
  for (inx = 0; inx < cu->cu_fill; inx++)
    {
      caddr_t *cu_row = (caddr_t *) cu->cu_rows[inx];
      row[1] = cu_row[2];
      row[2] = cu_row[3];
      if (DV_DB_NULL == DV_TYPE_OF (cu_row[5]))
	row[3] = cu_row[4];
      else
	row[3] = cu_row[5];
      row[0] = cu_row[6];
      if (!cu->cu_ld_graphs)
	{
	  cu->cu_ld_graphs = id_hash_allocate (100, sizeof (caddr_t), sizeof (caddr_t), boxint_hash, boxint_hashcmp);
	  id_hash_set_rehash_pct (cu->cu_ld_graphs, 200);
	}
      if (!id_hash_get (cu->cu_ld_graphs, (caddr_t) (row[0])))
	id_hash_set (cu->cu_ld_graphs, (caddr_t) (row[0]), (caddr_t) & one);
      /* push dv string */
      dk_set_push (&cu->cu_ld_rows, cu_ld_str (row, 0));
    }
  cu_clear (cu);
}

extern int32 rdf_ld_batch_sz;

caddr_t
bif_dpipe_input (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  cl_req_group_t *clrg = bif_clrg_arg (qst, args, 0, "dpipe_input");
  cucurbit_t *cu = clrg->clrg_cu;
  CL_ONLINE_CK;
  if (!cu)
    sqlr_new_error ("42000", "CL...", "Not a dpipe daq");
  cu->cu_clrg->clrg_inst = cu->cu_qst = qst;
  if ((cu->cu_rdf_load_mode & RDF_LD_DEL_INS) && BOX_ELEMENTS (args) == 6)
    {
      caddr_t g = bif_arg (qst, args, 5, "dpipe_input");
      if (cu->cu_rdf_last_g && cu->cu_fill >= (1.5 * rdf_ld_batch_sz))
	{
	  cu_ld_store_rows (cu, qst, err_ret);
	  if (strcmp (cu->cu_rdf_last_g, g))
	    cl_rdf_call_insert_cb (cu, qst, err_ret);
	}
      if (!cu->cu_rdf_last_g || strcmp (cu->cu_rdf_last_g, g))
	{
	  dk_free_tree (cu->cu_rdf_last_g);
	  cu->cu_rdf_last_g = box_copy_tree (g);
	}
    }
  cu_ssl_row (cu, qst, args, 1);
  return NULL;
}


caddr_t
bif_dpipe_next (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
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
  cu_func_t *cf, *prev_cf = NULL;
  prev_cf = cu_func (name, 0);
  if (prev_cf && prev_cf->cf_dispatch)
    return NULL;		/* no redef of builtin cf with dispatch */
  if (prev_cf)
    cf = prev_cf;
  else
    {
      NEW_VARZ (cu_func_t, cf2);
      cf = cf2;
    }
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
bif_dpipe_drop (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "dpipe_drop");
  cu_func_t *oldfn = NULL;
  caddr_t oldkey = NULL;
  if (BOX_ELEMENTS (args) > 1)
    sqlr_new_error ("42000", "CL...", "dpipe_drop() takes only one string parameter, dpipe name.");
  id_hash_get_and_remove (name_to_cu_func, (caddr_t) & name, (caddr_t) & oldkey, (caddr_t) & oldfn);
  if (oldfn)
    dk_free (oldfn, sizeof (cu_func_t));
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


caddr_t
bif_cl_detach_thread (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  QNCAST (QI, qi, qst);
  client_connection_t *cli = qi->qi_client;
  if (!cli->cli_cl_stack || box_length (cli->cli_cl_stack) == sizeof (cl_call_stack_t))
    return NULL;
  dk_free_box (cli->cli_cl_stack);
  cli->cli_cl_stack = NULL;
  return box_num (1);
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
  cu_func_t *cf, *prev_cf = NULL;
  prev_cf = cu_func (name, 0);
  if (prev_cf)
    cf = prev_cf;
  else
    {
      NEW_VARZ (cu_func_t, cf2);
      cf = cf2;
    }
  cf->cf_name = box_dv_short_string (name);
  cf->cf_dispatch = fn_disp;
  cf->cf_part_key = key;
  cf->cf_proc = box_dv_short_string (fn);
  cf->cf_is_upd = CF_UPD_FLAGS (l);
  cf->cf_1_arg = l & CF_1_ARG;
  id_hash_set (name_to_cu_func, (caddr_t) & cf->cf_name, (caddr_t) & cf);
}

void
dpipe_drop (caddr_t name)
{
  cu_func_t *oldfn = NULL;
  caddr_t oldkey = NULL;
  id_hash_get_and_remove (name_to_cu_func, (caddr_t) & name, (caddr_t) & oldkey, (caddr_t) & oldfn);
  if (oldfn)
    dk_free (oldfn, sizeof (cu_func_t));
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


caddr_t
bif_cl_current_slice (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  QNCAST (QI, qi, qst);
  if (CL_RUN_LOCAL == cl_run_local_only)
    return box_num (QI_NO_SLICE);
  return box_num (qi->qi_client->cli_slice);
}


void
bif_daq_init ()
{
  static int bif_daq_init_done = 0;
  if (bif_daq_init_done)
    return;
  bif_daq_init_done = 1;
  bif_define ("daq_buffered_bytes", bif_daq_buffered_bytes);
  bif_define ("cl_set_slice", bif_cl_set_slice);
  name_to_cu_func = id_casemode_hash_create (11);
/*  func_name_to_cu_func = id_casemode_hash_create (11); */
  bif_define_ex ("dpipe", bif_dpipe, BMD_OUT_OF_PARTITION, BMD_DONE);
  bif_define_ex ("dpipe_input", bif_dpipe_input, BMD_OUT_OF_PARTITION, BMD_DONE);
  bif_define_ex ("dpipe_next", bif_dpipe_next, BMD_OUT_OF_PARTITION, BMD_DONE);
  bif_define ("dpipe_define_1", bif_dpipe_define);
  bif_define ("dpipe_drop_1", bif_dpipe_drop);
  bif_define ("dpipe_count", bif_dpipe_count);
  bif_define ("dpipe_reuse", bif_dpipe_reuse);
  bif_define_ex ("dpipe_redo", bif_dpipe_redo, BMD_OUT_OF_PARTITION, BMD_DONE);
  bif_define ("cl_is_autocommit", bif_cl_is_autocommit);
  bif_define ("cl_daq_client", bif_cl_daq_client);
  bif_define_ex ("cl_current_slice", bif_cl_current_slice, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define ("cl_detach_thread", bif_cl_detach_thread);
  {
    /* define identity as identity op for dpipe */
    caddr_t es = box_dv_short_string ("identity");
    caddr_t n = NULL;
    id_hash_set (name_to_cu_func, (caddr_t) & es, (caddr_t) & n);
  }
  cl_rdf_init ();
}

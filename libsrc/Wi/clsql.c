/*
 *  clsql.c
 *
 *  $Id$
 *
 *  SQL compiler specifics for cluster
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
#include "eqlcomp.h"
#include "sqlfn.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlo.h"
#include "sqlo.h"
#include "rdfinf.h"
#include "xmlnode.h"


int enable_hash_colocate = 0;
int enable_dfg = 1;
int enable_multistate_code = 1;
int enable_last_qf_dml = 1;
int enable_rec_qf = 1;
int enable_trans_colocate = 1;
int enable_setp_partition = 1;



void
ssl_ht_print (dk_hash_t * ht)
{
  DO_HT (state_slot_t *, ssl, ptrlong, f, ht)
  {
    printf ("<$%d %s> ", ssl->ssl_index, ssl->ssl_name ? ssl->ssl_name : "unnamed");
  }
  END_DO_HT;
  printf ("\n");
}


void
ssl_arr_print (state_slot_t ** arr)
{
  int inx;
  DO_BOX (state_slot_t *, ssl, inx, arr)
  {
    printf ("<$%d %s> ", ssl->ssl_index, ssl->ssl_name ? ssl->ssl_name : "unnamed");
  }
  END_DO_BOX;
  printf ("\n");
}

void
dk_set_replace (dk_set_t s, void *old, void *repl)
{
  for (s = s; s; s = s->next)
    {
      if (old == s->data)
	s->data = repl;
    }
}



int
key_is_local_copy (dbe_key_t * key)
{
  /* can read all from local */
  int inx;
  key_partition_def_t *kpd = key->key_partition;
  cl_host_group_t **groups;
  if (!kpd)
    return 1;
  groups = kpd->kpd_map->clm_hosts;
  if (1 != BOX_ELEMENTS (groups))
    return 0;
  DO_BOX (cl_host_t *, host, inx, groups[0]->chg_hosts)
  {
    if (host->ch_id == local_cll.cll_this_host)
      return 1;
  }
  END_DO_BOX;
  return 0;
}


void
clb_init (comp_context_t * cc, cl_buffer_t * clb, int is_select)
{
  clb->clb_batch_size = MAX (1, cl_req_batch_size);
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


void
sqlg_cl_insert (sql_comp_t * sc, comp_context_t * cc, insert_node_t * ins, ST * tree, dk_set_t * code)
{
  int inx;
  int any_part = 0, any_non_part = 0;
  caddr_t *opts = tree ? tree->_.insert.opts : NULL;
  ST *daq;
  if (sqlo_opt_value (opts, OPT_NO_CLUSTER))
    return;
  daq = (ST *) sqlo_opt_value (opts, OPT_INTO);
  if (daq)
    {
      if (INS_REPLACING == ins->ins_mode
	  || (INS_SOFT == ins->ins_mode && !(ins->ins_no_deps || !ins->ins_table->tb_keys->next || ins->ins_key_only)))
	sqlc_new_error (sc->sc_cc, "37000", "CL...",
	    "insert in daq does not support replacing and soft is only allowed for tables with no dependent part or tables with pk index only");
      sqlc_mark_pred_deps (sc, NULL, daq);
      ins->ins_daq = scalar_exp_generate (sc, daq, code);
    }
  DO_BOX (ins_key_t *, ik, inx, ins->ins_keys)
  {
    if (ik->ik_key->key_partition)
      any_part = 1;
    else
      any_non_part = 1;
  }
  END_DO_BOX;
  if (any_part && any_non_part)
    sqlc_new_error (sc->sc_cc, "37000", "CL...",
	"Table %s has both partitioned and non-partitioned keys.  Must either be all  partitioned or none partitioned.",
	ins->ins_table ? ins->ins_table->tb_name : "no name");
  if (!any_part)
    {
      if (daq)
	sqlc_new_error (sc->sc_cc, "37000", "CL...", "insert into daq is not allowed for a non-partitioned table");
      return;			/*not partitioned */
    }
  clb_init (cc, &ins->clb, 0);
}




state_slot_t **
sqlg_env_remove_globals (state_slot_t ** env)
{
  int inx;
  DO_BOX (state_slot_t *, ssl, inx, env)
  {
    if (ssl->ssl_qr_global)
      {
	dk_set_t s = NULL;
	DO_BOX (state_slot_t *, ssl, inx, env)
	{
	  if (!ssl->ssl_qr_global)
	    dk_set_push (&s, (void *) ssl);
	}
	END_DO_BOX;
	dk_free_box ((caddr_t) env);
	return (state_slot_t **) list_to_array (s);
      }
  }
  END_DO_BOX;
  return env;
}


void
cl_qn_set_save (data_source_t * qn, state_slot_t ** env)
{
#if 0				/* no clb saves in vectored exec but itcl_params is still used for the clo  */
  if (IS_TS (((table_source_t *) qn)))
    {
      table_source_t *ts = (table_source_t *) qn;
      if (ts->ts_order_ks && ts->ts_order_ks->ks_key->key_partition)
	ts->clb.clb_save = sqlg_env_remove_globals (env);
      else
	dk_free_box ((caddr_t) env);
    }
  else if ((qn_input_fn) dpipe_node_input == qn->src_input)
    {
      ((dpipe_node_t *) qn)->clb.clb_save = sqlg_env_remove_globals (env);
    }
  else if ((qn_input_fn) set_ctr_input == qn->src_input)
    {
      ((set_ctr_node_t *) qn)->clb.clb_save = sqlg_env_remove_globals (env);
    }
  else if ((qn_input_fn) code_node_input == qn->src_input)
    {
      ((code_node_t *) qn)->clb.clb_save = sqlg_env_remove_globals (env);
    }
  else if ((qn_input_fn) remote_table_source_input == qn->src_input)
    {
      ((remote_table_source_t *) qn)->rts_save_env = env;
    }
  else if ((qn_input_fn) fun_ref_node_input == qn->src_input)
    {
      QNCAST (fun_ref_node_t, fref, qn);
      fref->clb.clb_save = sqlg_env_remove_globals (env);
    }
  else if ((qn_input_fn) query_frag_input == qn->src_input)
    {
      query_frag_t *qf = (query_frag_t *) qn;
      if (!qf->qf_is_update)
	qf->clb.clb_save = env;
      else
	dk_free_box ((caddr_t) env);
    }
  else if ((qn_input_fn) trans_node_input == qn->src_input)
    {
      ((trans_node_t *) qn)->clb.clb_save = sqlg_env_remove_globals (env);
    }
  else
	    {
	  }
#endif
}


int
qn_has_clb_save (data_source_t * qn)
{
  /* non-last multistate node with a clb.  One that needs clb_save set */
  if (IS_RTS ((table_source_t *) qn)
      || (qn_input_fn) dpipe_node_input == qn->src_input
      || (qn_input_fn) code_node_input == qn->src_input
      || (qn_input_fn) stage_node_input == qn->src_input
      || (qn_input_fn) set_ctr_input == qn->src_input || (qn_input_fn) trans_node_input == qn->src_input)
    {
      return 1;
    }
  if (IS_TS ((table_source_t *) qn) || (qn_input_fn) fun_ref_node_input == qn->src_input)
    {
      QNCAST (table_source_t, ts, qn);
      return 0 != ts->clb.clb_fill;
    }
  if ((qn_input_fn) query_frag_input == qn->src_input)
    {
      QNCAST (query_frag_t, qf, qn);
      return !qf->qf_is_update;
    }
  return 0;
}

int
qf_any_ks_order (query_frag_t * qf)
{
  DO_SET (table_source_t *, ts, &qf->qf_nodes)
  {
    if (IS_TS (ts) && ts->ts_order_ks && ts->ts_order_ks->ks_cl_order)
      return 1;
    if (IS_CL_TXS (ts) && ((text_node_t *) ts)->txs_order)
      return 1;
  }
  END_DO_SET ();
  return 0;
}


void sqlg_dfg_env (sql_comp_t * sc, query_frag_t * qf);


void
qfs_free (qf_select_node_t * qfs)
{
  dk_free_box ((caddr_t) qfs->qfs_out_slots);
}

#define IS_INNER_TS(ts) (IS_TS (ts) && !((table_source_t*)(ts))->ts_is_outer)

void
sqlg_qf_end (sql_comp_t * sc, query_frag_t * qf)
{
  /* if this is a qf that produces a value and does not end with a partitioned ks with no after code or test, add a qf select at the end */
  data_source_t *qn = qf->qf_head_node;
  if (QF_AGG_MERGE == qf->qf_is_agg || qf->qf_is_update)
    return;
  while (qn_next (qn))
    qn = qn_next (qn);
  if ((0 && IS_INNER_TS (qn) && !qn->src_after_test && !qn->src_after_code)
      || (IS_QN (qn, setp_node_input) && !((setp_node_t *) qn)->setp_distinct))
    return;
  {
    SQL_NODE_INIT (qf_select_node_t, qfs, qf_select_node_input, qfs_free);
    dk_set_delete (&sc->sc_cc->cc_query->qr_nodes, (void *) qfs);
    dk_set_push (&qf->qf_nodes, (void *) qfs);
    qfs->qfs_itcl = qf->clb.clb_itcl;
    qfs->qfs_out_slots = (state_slot_t **) box_copy ((caddr_t) qf->qf_result);
    qn->src_continuations = dk_set_cons ((void *) qfs, NULL);
    if (IS_TS (qn) && ((table_source_t *) qn)->ts_order_ks)
      ((table_source_t *) qn)->ts_order_ks->ks_is_last = 0;
  }
}


int enable_qf_dfg_scope = 1;

void
sqlg_qf_nodes_env (sql_comp_t * sc, query_frag_t * qf, dk_hash_t * local_refs, dk_hash_t * refs, state_slot_t ** refd_after_qf,
    dk_set_t * output)
{
  int inx, ign;
  du_thread_t *self = THREAD_CURRENT_THREAD;
  dk_hash_t *prev_asg = (dk_hash_t *) THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ASG_SET);
  state_slot_t **sel_out = sc->sc_sel_out;
  dk_hash_t *asg = hash_table_allocate (23), *asg_before_post = NULL, *refd_before_post = NULL;
  dk_hash_t *tmp_res = hash_table_allocate (11);
  dk_hash_t *tmp_res2 = hash_table_allocate (11);
  dk_set_t s, non_postprocess_nodes = NULL;
  int prev_gr = sqlg_count_qr_global_refs;
  SET_THR_ATTR (self, TA_SQLC_ASG_SET, asg);

  /* in a qf with postprocessing of partitioned aggregate count the postprocess and the part before separately.  Only assignments before postprocess are subtracted from refs to get the parameters.  For output, all assignments are counted */
  for (s = qf->qf_nodes; s; s = s->next)
    {
      if (IS_QN (s->data, ssa_iter_input))
	non_postprocess_nodes = s->next;
    }
  if (!non_postprocess_nodes)
    non_postprocess_nodes = qf->qf_nodes;
  DO_SET (data_source_t *, qn, &non_postprocess_nodes)
  {
    qn_refd_slots (sc, qn, tmp_res, tmp_res2, &ign);
    cv_refd_slots (sc, qn->src_pre_code, tmp_res, tmp_res2, &ign);
  }
  END_DO_SET ();
  if (non_postprocess_nodes != qf->qf_nodes)
    {
      refd_before_post = hash_table_allocate (11);
      asg_before_post = hash_table_allocate (11);
      dk_hash_copy (refd_before_post, tmp_res);
      dk_hash_copy (asg_before_post, asg);
      for (s = qf->qf_nodes; s != non_postprocess_nodes; s = s->next)
	{
	  qn_refd_slots (sc, (data_source_t *) s->data, tmp_res, tmp_res2, &ign);
	  cv_refd_slots (sc, ((data_source_t *) s->data)->src_pre_code, tmp_res, tmp_res2, &ign);
	}
    }
  SET_THR_ATTR (self, TA_SQLC_ASG_SET, prev_asg);
  *output = NULL;
  DO_BOX (state_slot_t *, refd, inx, refd_after_qf)
  {
    if (gethash ((void *) refd, asg) && (!qf->qf_agg_res || -1 == box_position_no_tag ((caddr_t *) qf->qf_agg_res, (caddr_t) refd)))
      dk_set_push (output, (void *) refd);
  }
  END_DO_BOX;
  sc->sc_sel_out = (state_slot_t **) t_list_to_array (*output);
  sc->sc_qf = qf;
  sqlg_count_qr_global_refs = 1;
  sqlg_qn_env (sc, qf->qf_head_node, NULL, local_refs);
  sqlg_count_qr_global_refs = prev_gr;
  sc->sc_qf = NULL;
  sc->sc_sel_out = sel_out;
  DO_HT (state_slot_t *, asg_ssl, void *, ign, asg_before_post ? asg_before_post : asg)
  {
    remhash_ssl (asg_ssl, refs);
    remhash_ssl (asg_ssl, local_refs);
  }
  END_DO_HT;
  if (asg_before_post)
    {
      DO_HT (state_slot_t *, asg_ssl, void *, ign, asg)
      {
	if (!gethash ((void *) asg_ssl, refd_before_post))
	  {
	    remhash_ssl (asg_ssl, refs);
	    remhash_ssl (asg_ssl, local_refs);
	  }
      }
      END_DO_HT;
      hash_table_free (asg_before_post);
    }
  hash_table_free (asg);
  hash_table_free (tmp_res);
  hash_table_free (tmp_res2);
  if (refd_before_post)
    hash_table_free (refd_before_post);
}

void ref_ssls (dk_hash_t * ht, state_slot_t ** ssls);


void
sqlg_qf_ctx (sql_comp_t * sc, query_frag_t * qf, dk_hash_t * local_refs, dk_hash_t * refs)
{
  /* for a query frag: 1. the output is what is refd after the qf and is not refd before the qf.
   * The save ctx is what is refd after and before.  The input is what is refd by the qf alone. */
  int is_order = 0;
  dk_set_t qf_order = NULL;
  dk_set_t outputs = NULL;
  dk_set_t save = NULL;
  state_slot_t **refd_after_qf;
  int i = 0, inx, cl_flag = 0, sets_order = 0;
  cv_refd_slots (sc, qf->src_gen.src_after_code, refs, NULL, &cl_flag);

  if (qf_any_ks_order (qf))
    {
      /* if the qf is for values and is ordered, then all the ordering cols are implicitly refd after the qf and the qf gets a qf_clo_order */
      is_order = 1;		/* order flag needed even if no ordering cols, i.e. all unique so as to keep result sets separate */
      DO_SET (table_source_t *, ts, &qf->qf_nodes)
      {
	/* the ordering output ssls of the qf are generated here in reverse.  The result is in proper order, most significant first */
	if (IS_TS (ts) && ts->ts_order_ks && ts->ts_order_ks->ks_cl_order)
	  {
	    int inx, n = BOX_ELEMENTS (ts->ts_order_ks->ks_cl_order);
	    sets_order |= ts->ts_order_ks->ks_oby_order;
	    for (inx = n - 1; inx >= 0; inx--)
	      {
		clo_comp_t *clo = ts->ts_order_ks->ks_cl_order[inx];
		state_slot_t *out = (state_slot_t *) dk_set_nth (ts->ts_order_ks->ks_out_slots, clo->nth);
		REF_SSL (refs, out);
		dk_set_push (&qf_order, (void *) list (2, clo, out));
	      }
	  }
	if (IS_CL_TXS (ts))
	  {
	    QNCAST (text_node_t, txs, ts);
	    if (txs->txs_is_driving)
	      {
		t_NEW_VAR (clo_comp_t, clo);
		memset (clo, 0, sizeof (clo_comp_t));
		clo->col = (dbe_column_t *) txs->txs_table->tb_primary_key->key_parts->next->data;
		clo->is_desc = txs->txs_desc ? 1 : 0;
		dk_set_push (&qf_order, (void *) list (2, clo, txs->txs_d_id));
		sethash ((void *) txs->txs_d_id, refs, (void *) (ptrlong) 1);
	      }
	  }
      }
      END_DO_SET ();
      if (sets_order)
	{
	  t_NEW_VAR (clo_comp_t, clo);
	  memset (clo, 0, sizeof (clo_comp_t));
	  NCONCF1 (qf_order, list (2, clo, qf->qf_set_no));
	}
    }
  refd_after_qf = (state_slot_t **) ht_keys_to_array (refs);
  if (enable_qf_dfg_scope)
    sqlg_qf_nodes_env (sc, qf, local_refs, refs, refd_after_qf, &outputs);
  else
  qn_refd_slots (sc, (data_source_t *) qf, local_refs, refs, &i);
  if (qf->qf_agg_res)
    {
      /*if a non grouped aggregate, the state of the aggregate is not a param even through it is  refd before assigned  */
      DO_BOX (state_slot_t *, state, inx, qf->qf_agg_res)
      {
	remhash ((void *) state, local_refs);
      }
      END_DO_BOX;
    }
  if (qf->qf_set_no && !qf->qf_is_agg)
    sethash ((void *) qf->qf_set_no, local_refs, (void *) 1);
  qf->qf_params = (state_slot_t **) ht_keys_to_array (local_refs);
  DO_BOX (state_slot_t *, ref_after_qf, inx, refd_after_qf)
  {
    if (gethash ((void *) ref_after_qf, refs))
      dk_set_push (&save, (void *) ref_after_qf);
    else if (!enable_qf_dfg_scope)
      dk_set_push (&outputs, (void *) ref_after_qf);
  }
  END_DO_BOX;
  dk_free_box ((caddr_t) refd_after_qf);
  qf->clb.clb_save = (state_slot_t **) list_to_array (save);
  if (qf->qf_set_no && !qf->qf_is_agg)
    dk_set_push (&outputs, (void *) qf->qf_set_no);
  qf->qf_result = (state_slot_t **) dk_set_to_array (outputs);
  qf->qf_out_slots = outputs;
  if (!qf->qf_is_update && QF_AGG_MERGE != qf->qf_is_agg)
    {
      table_source_t *last_ts = (table_source_t *) qf->qf_nodes->data;
      if (IS_TS (last_ts))
	{
	  if (!last_ts->ts_is_outer && !last_ts->src_gen.src_after_test && !last_ts->src_gen.src_after_code)
	    {
	      last_ts->ts_order_ks->ks_is_last = 1;
	      last_ts->ts_order_ks->ks_qf_output = (state_slot_t **) dk_set_to_array (outputs);
	      last_ts->ts_order_ks->ks_ts = last_ts;
	    }
	  last_ts->clb.clb_itcl = qf->qf_itcl;
	}
    }
  DO_BOX (state_slot_t *, param, inx, qf->qf_params)
  {
    /* if it is a parameter of the qf, then it is refd and must be in the save ctxs of nodes before the qf */
    if (param != qf->qf_set_no)
    sethash ((void *) param, refs, (void *) (ptrlong) 1);
  }
  END_DO_BOX;
  if (qf->qf_set_no)
    {
      remhash ((void *) qf->qf_set_no, refs);
      remhash ((void *) qf->qf_set_no, local_refs);
    }
  cv_refd_slots (sc, qf->src_gen.src_pre_code, refs, NULL, &i);
  if (qf->qf_trigger_args)
    ref_ssls (refs, qf->qf_trigger_args);
  if (is_order && !qf_order)
    qf->qf_order = (clo_comp_t **) list (0);
  else if (qf_order)
    {
      clo_comp_t **qfo = (clo_comp_t **) dk_alloc_box_zero (sizeof (caddr_t) * dk_set_length (qf_order), DV_ARRAY_OF_POINTER);
      int inx = 0;
      DO_SET (caddr_t *, elt, &qf_order)
      {
	clo_comp_t *org_clo = (clo_comp_t *) elt[0];
	qfo[inx] = dk_alloc (sizeof (clo_comp_t));
	qfo[inx]->nth = dk_set_position (outputs, (void *) elt[1]);
	qfo[inx]->is_desc = org_clo->is_desc;
	qfo[inx]->col = org_clo->col;
	inx++;
	dk_free_box ((caddr_t) elt);
      }
      END_DO_SET ();
      qf->qf_order = qfo;
      dk_set_free (qf_order);
    }
  sqlg_qf_end (sc, qf);
  if (!enable_qf_dfg_scope && qf->qf_n_stages)
    sqlg_dfg_env (sc, qf);
  if (!qf->qf_is_update)
    {
      DO_SET (table_source_t *, ts, &qf->qf_nodes)
      {
	if (IS_TS (ts))
	  ts->ts_current_of = NULL;
      }
      END_DO_SET ();
    }
}


int
cl_is_simple_ts (data_source_t * qn)
{
  /* is cluster ts with no local test or local code.  Does not have to save its own refd ssls because it uses them only at init, not at next row */
  QNCAST (table_source_t, ts, qn);
  if (IS_TS (ts) && ts->clb.clb_fill && ts->ts_order_ks
      && !ts->src_gen.src_after_test && !ts->src_gen.src_after_code
      && !ts->ts_order_ks->ks_local_test && !ts->ts_order_ks->ks_local_code && !ts->ts_after_join_test && !ts->ts_order_ks->ks_setp)
    return 1;
  return 0;
}

dk_hash_t *
hash_table_copy (dk_hash_t * ht)
{
  dk_hash_t *cp = hash_table_allocate (ht->ht_actual_size);
  DO_HT (void *, k, void *, d, ht)
  {
    sethash (k, cp, d);
  }
  END_DO_HT;
  return cp;
}

void
cl_simple_ts_save (table_source_t * ts, dk_hash_t * local_refs, dk_hash_t * prev_refs, dk_hash_t * refs)
{
  /* what is refd after this and not assigned here */
  dk_set_t res = NULL;
  DO_HT (state_slot_t *, ssl, ptrlong, ignore, prev_refs)
  {
    if (gethash ((void *) ssl, refs))
      dk_set_push (&res, (void *) ssl);
  }
  END_DO_HT;
  ts->clb.clb_save = (state_slot_t **) list_to_array (res);
}


void
cn_set_results (code_node_t * cn, dk_hash_t * refs)
{
  /* the result buffer of an in order multistate code node is the intersection of what it assigns and what the query later accesses */
  dk_set_t asg;
  dk_set_t res = NULL;
  asg = cv_assigned_slots (cn->cn_code, 0);
  DO_SET (state_slot_t *, r, &asg)
  {
    if (gethash ((void *) r, refs))
      dk_set_push (&res, (void *) r);
  }
  END_DO_SET ();
  dk_set_free (asg);
  cn->cn_assigned = (state_slot_t **) list_to_array (res);
}


void
sqlg_dp_ctx (sql_comp_t * sc, dpipe_node_t * dp, dk_hash_t * local_refs, dk_hash_t * refs)
{
  int cl_flag;
  cv_refd_slots (sc, dp->src_gen.src_after_code, refs, NULL, &cl_flag);
  cv_refd_slots (sc, dp->src_gen.src_after_test, refs, NULL, &cl_flag);
  asg_ssl_array (local_refs, refs, dp->dp_outputs);
  dp->clb.clb_save = sqlg_env_remove_globals ((state_slot_t **) ht_keys_to_array (refs));
  qn_refd_slots (sc, (data_source_t *) dp, refs, refs, &cl_flag);
  /* pass the refs twice, no copy from local to refs cause no use for local refs for a dp node */
}


void
sqlg_qn_ctx (sql_comp_t * sc, data_source_t * qn, dk_hash_t * refs)
{
  dk_hash_t *local_refs = hash_table_allocate (11);
  int cl_flag = 0, is_simple_ts = 0;
  if ((qn_input_fn) query_frag_input == qn->src_input)
    {
      sqlg_qf_ctx (sc, (query_frag_t *) qn, local_refs, refs);
      hash_table_free (local_refs);
      return;
    }
  if ((qn_input_fn) dpipe_node_input == qn->src_input)
    {
      sqlg_dp_ctx (sc, (dpipe_node_t *) qn, local_refs, refs);
      hash_table_free (local_refs);
      return;
    }
  is_simple_ts = cl_is_simple_ts (qn);
  if (is_simple_ts)
    {
      dk_hash_t *prev_refs = hash_table_copy (refs);
      qn_refd_slots (sc, qn, local_refs, refs, &cl_flag);
      cl_simple_ts_save ((table_source_t *) qn, local_refs, prev_refs, refs);
      hash_table_free (prev_refs);
    }
  else
    {
      if ((qn_input_fn) code_node_input == qn->src_input)
	cn_set_results ((code_node_t *) qn, refs);
      qn_refd_slots (sc, qn, local_refs, refs, &cl_flag);
    }
  DO_HT (state_slot_t *, ssl, void *, ignore, local_refs)
  {
    sethash ((void *) ssl, refs, (void *) 1);
  }
  END_DO_HT;
  hash_table_free (local_refs);
  if (qn_has_clb_save (qn) && !is_simple_ts)
    {
      QNCAST (table_source_t, ts, qn);
      if (!IS_TS (ts) || (ts->clb.clb_fill))
	cl_qn_set_save (qn, (state_slot_t **) ht_keys_to_array (refs));
    }
  cv_refd_slots (sc, qn->src_pre_code, refs, NULL, &cl_flag);
}


void
sqlg_part_fref_refs (sql_comp_t * sc, fun_ref_node_t * fref, dk_hash_t * res)
{
  QNCAST (cl_fref_read_node_t, clf, qn_next ((data_source_t *) fref));
  if (!clf || !IS_QN (clf, cl_fref_read_input))
    return;
  REF_SSL (res, clf->clf_fref->fnr_ssa.ssa_set_no);
  ref_ssl_list (sc, res, clf->clf_out_slots);
}


void
sqlg_part_fref_order (sql_comp_t * sc, fun_ref_node_t * fref)
{
  static dbe_column_t fake_int_col;
  query_frag_t *qf = fref->fnr_cl_qf;
  QNCAST (cl_fref_read_node_t, clf, qn_next ((data_source_t *) fref));
  setp_node_t *setp;

  if (!qf || !clf || !fref->fnr_setp || !IS_QN (clf, cl_fref_read_input))
    return;
  setp = clf->clf_setp;
  /* the slots of the clf are 1:1 the output of the qf */
  dk_set_free (clf->clf_out_slots);
  clf->clf_out_slots = dk_set_copy (qf->qf_out_slots);
  if (0 && !fref->fnr_is_order)
    return;
  {
    dk_set_t ord = NULL;
    dk_set_t is_desc = setp->setp_key_is_desc;
    int inx = 0;
    NEW_VARZ (clo_comp_t, clo1);
    if (!fake_int_col.col_sqt.sqt_dtp)
      fake_int_col.col_sqt.sqt_dtp = DV_LONG_INT;
    clo1->nth = dk_set_position (qf->qf_out_slots, setp->setp_ssa.ssa_set_no);
    clo1->col = &fake_int_col;
    dk_set_push (&ord, (void *) clo1);
    DO_SET (state_slot_t *, key, &setp->setp_keys)
    {
      NEW_VARZ (clo_comp_t, clo);
      clo->nth = dk_set_position (qf->qf_out_slots, (void *) key);
      if (-1 == clo->nth)
	sqlc_new_error (sc->sc_cc, "37000", "CL...",
	    "SQL internal error with partitioned grou or order reader.  Can do __dbf_set ('enable_setp_partition', 0) to disable the feature, which will remove this error.");
      clo->col = (dbe_column_t *) dk_set_nth (setp->setp_ha->ha_key->key_parts, inx);
      if (is_desc && ORDER_DESC == (ptrlong) is_desc->data)
	clo->is_desc = 1;
      dk_set_push (&ord, (void *) clo);
      inx++;
      is_desc = is_desc ? is_desc->next : NULL;
    }
    END_DO_SET ();
    clf->clf_order = (clo_comp_t **) list_to_array (dk_set_nreverse (ord));
    clf->clf_set_no = cc_new_instance_slot (sc->sc_cc);
    clf->clf_nth_in_set = cc_new_instance_slot (sc->sc_cc);
  }
}


void
sqlg_un_refs (sql_comp_t * sc, union_node_t * un, dk_hash_t * refs)
{
  DO_HT (state_slot_t *, ssl, ptrlong, igm, un->un_refs_after)
    {
      REF_SSL (refs, ssl);
    }
  END_DO_HT;
}


void
sqlg_qn_env (sql_comp_t * sc, data_source_t * qn, dk_set_t qn_stack, dk_hash_t * refs)
{
  int cl_flag;
  if (!qn)
    {
      if (qn_stack)
	{
	  /* here we are at end of a subq and call the next of the caller.  The caller of the subq is either a sqs or a union node.  Mind the sqs's or union's after tests so that upon return, when the subq is processed, they are properly in the refs */
	  int cl_flag = 0;
	  QNCAST (data_source_t, sqs, qn_stack->data);
	  if (IS_QN (sqs, union_node_input))
	    {
	      QNCAST (union_node_t, un, sqs);
	      if (un->un_refs_after)
		{
		  /* the union's  continuation has been seen. Redo the same refs, no need to get them again  */
		  sqlg_un_refs (sc, un, refs);
		  return;
		}
	    }
	  sqlg_qn_env (sc, qn_next (sqs), qn_stack->next, refs);
	  cv_refd_slots (sc, sqs->src_after_code, refs, NULL, &cl_flag);
	  cv_refd_slots (sc, sqs->src_after_test, refs, NULL, &cl_flag);
	  if (IS_QN (sqs,  union_node_input))
	    {
	      QNCAST (union_node_t, un, sqs);
	      if (!un->un_refs_after)
		un->un_refs_after = hash_table_copy (refs); 
	    }
	}
      else
	{
	  if (sc->sc_sel_out)
	    {
	      int inx;
	      DO_BOX (state_slot_t *, ssl, inx, sc->sc_sel_out)
	      {
		REF_SSL (refs, ssl);
	      }
	      END_DO_BOX;
	      if (sc->sc_qf && !sc->sc_qf->qf_is_agg)
		REF_SSL (refs, sc->sc_qf->qf_set_no);
	      /* the sel out is for the top level context.  This is hit at the deepest recursion level. On the returning edge there are qfs and frefs that are inside subqs.  These will also hit this point later but at this point the sel out should not be added to the refs a second time.  Makes for refs to unassigned */
	      sc->sc_sel_out = NULL;
	    }
	}
      return;
    }
  if ((qn_input_fn) fun_ref_node_input == qn->src_input || IS_QN (qn, hash_fill_node_input))
    {
      QNCAST (fun_ref_node_t, fref, qn);
      sqlg_qn_env (sc, qn_next (qn), qn_stack, refs);
      cv_refd_slots (sc, qn->src_after_code, refs, NULL, &cl_flag);
      sqlg_part_fref_refs (sc, fref, refs);
      sqlg_qn_env (sc, fref->fnr_select, NULL, refs);
      sqlg_part_fref_order (sc, fref);
      ASG_SSL (refs, NULL, fref->fnr_ssa.ssa_set_no);
      cv_refd_slots (sc, qn->src_pre_code, refs, NULL, &cl_flag);
      return;
    }
  else if ((qn_input_fn) subq_node_input == qn->src_input)
    {
      QNCAST (subq_source_t, sqs, qn);
      if (sqs->sqs_after_join_test)
	{
	  sqs->src_gen.src_after_test = sqs->sqs_after_join_test;
	  sqs->sqs_after_join_test = NULL;
	}
      sqlg_qn_env (sc, sqs->sqs_query->qr_head_node, t_cons ((void *) qn, qn_stack), refs);
    }
  else if ((qn_input_fn) trans_node_input == qn->src_input && ((trans_node_t *) qn)->tn_inlined_step)
    {
      QNCAST (trans_node_t, tn, qn);
      sqlg_qn_env (sc, tn->tn_inlined_step->qr_head_node, t_cons ((void *) qn, qn_stack), refs);
      if (tn->tn_complement)
	sqlg_qn_env (sc, tn->tn_complement->tn_inlined_step->qr_head_node, t_cons ((void *) qn, qn_stack), refs);
    }
  else if ((qn_input_fn) union_node_input == qn->src_input)
    {
      QNCAST (union_node_t, un, qn);
      un->un_refs_after = NULL;
      DO_SET (query_t *, term, &un->uni_successors)
      {
	sqlg_qn_env (sc, term->qr_head_node, t_cons ((void *) qn, qn_stack), refs);
      }
      END_DO_SET ();
      if (un->un_refs_after)
	hash_table_free (un->un_refs_after);
      un->un_refs_after = NULL;
    }
  else
    {
      sqlg_qn_env (sc, qn_next (qn), qn_stack, refs);
    }
  /* now we know what is refd after this node */
  sqlg_qn_ctx (sc, qn, refs);
  cv_refd_slots (sc, qn->src_pre_code, refs, NULL, &cl_flag);
}


void
sqlg_dfg_env (sql_comp_t * sc, query_frag_t * qf)
{
  dk_hash_t *refs = hash_table_allocate (11);
  state_slot_t **sel_out = sc->sc_sel_out;
  sc->sc_sel_out = qf->qf_result;
  sc->sc_qf = qf;
  sqlg_count_qr_global_refs = 1;
  sqlg_qn_env (sc, qf->qf_head_node, NULL, refs);
  sqlg_count_qr_global_refs = 0;
  sc->sc_qf = NULL;
  hash_table_free (refs);
  sc->sc_sel_out = sel_out;
}


void
sqlg_qn_mark_globals (data_source_t * qn)
{
  if (!qn)
    return;
  if (qn->src_pre_code && qn->src_input != (qn_input_fn) trans_node_input)	/* special case for trans node */
    {
      dk_set_t asg = cv_assigned_slots (qn->src_pre_code, 1);
      DO_SET (state_slot_t *, ssl, &asg)
      {
	if (ssl->ssl_always_vec)
	  continue;
	ssl->ssl_qr_global = 1;
	if (SSL_VEC == ssl->ssl_type)
	  ssl->ssl_type = SSL_VARIABLE;
      }
      END_DO_SET ();
      dk_set_free (asg);
    }
  if ((qn_input_fn) fun_ref_node_input == qn->src_input)
    {
      QNCAST (fun_ref_node_t, fref, qn);
      fref->fnr_is_top_level = 1;
      sqlg_qn_mark_globals (fref->fnr_select);
      sqlg_qn_mark_globals (qn_next (qn));
    }
  else if ((qn_input_fn) end_node_input == qn->src_input || (qn_input_fn) set_ctr_input == qn->src_input)
    {
      sqlg_qn_mark_globals (qn_next (qn));
    }
  else if ((qn_input_fn) dpipe_node_input == qn->src_input)
    {
      int inx;
      QNCAST (dpipe_node_t, dp, qn);
      DO_BOX (state_slot_t *, ssl, inx, dp->dp_outputs)
      {
	ssl->ssl_qr_global = 1;
	if (SSL_VEC == ssl->ssl_type)
	  ssl->ssl_type = SSL_VARIABLE;
      }
      END_DO_BOX;
      sqlg_qn_mark_globals (qn_next (qn));
    }
  else if ((qn_input_fn) subq_node_input == qn->src_input)
    {
      /* consider beginning of first suqb as global.  sparql queries often begin with subq with all inside.  Must flag the leading frefs as top level for anytime timeouts */
      QNCAST (subq_source_t, sqs, qn);
      sqlg_qn_mark_globals (sqs->sqs_query->qr_head_node);
    }
}


void
sqlg_qr_env (sql_comp_t * sc, query_t * qr)
{
  dk_hash_t *refs = hash_table_allocate (11);
  if (!sc->sc_super || !sc->sc_super->sc_cc->cc_query->qr_proc_vectored)
  sqlg_qn_mark_globals (qr->qr_head_node);
  sqlg_qn_env (sc, qr->qr_head_node, NULL, refs);
  hash_table_free (refs);
}


int sqlg_ts_order_anyway;


int
ks_col_has_eq (key_source_t * ks, dbe_column_t * col)
{
  /* if a col is equal, it does not have to be in the ordering */
  search_spec_t *sp;
  for (sp = ks->ks_spec.ksp_spec_array; sp; sp = sp->sp_next)
    {
      if (sp->sp_cl.cl_col_id == col->col_id && CMP_EQ == sp->sp_min_op)
	return 1;
    }
  return 0;
}


void
ks_ordering_cols (sql_comp_t * sc, table_source_t * ts, int do_anyway)
{
  int nth = 0;
  key_source_t *ks = ts->ts_order_ks;
  dk_set_t prev_out = ks->ks_out_slots;
  if (!ks->ks_key->key_partition)
    return;
  if (TS_ORDER_NONE == sc->sc_order && !sqlg_ts_order_anyway && !do_anyway && !ks->ks_oby_order)
    return;
  if (!ts->ts_order_ks && !do_anyway)
    return;
  if (ts->ts_is_unique && !do_anyway)
    {
      /* only one per set.  No intra-set comparisons */
      ts->ts_order_ks->ks_cl_order = (clo_comp_t **) list (0);
      return;
    }
  DO_SET (dbe_column_t *, col, &ks->ks_key->key_parts)
  {
    if ((do_anyway || !ks_col_has_eq (ks, col)) && !dk_set_member (ks->ks_out_cols, (void *) col))
      {
	dk_set_push (&ks->ks_out_cols, (void *) col);
	dk_set_push (&ks->ks_out_slots, (void *) ssl_new_column (sc->sc_cc, "ordering", col));
      }
    nth++;
    if (nth >= ks->ks_key->key_n_significant)
      break;
  }
  END_DO_SET ();
  if (ks->ks_out_slots != prev_out)
    {
      dk_free_box ((caddr_t) ks->ks_out_map);
      key_source_om (sc->sc_cc, ks);
    }
  if (TS_ORDER_KEY == sc->sc_order || sqlg_ts_order_anyway || ks->ks_oby_order)
    {
      dk_set_t cl_order = NULL;
      nth = 0;
      DO_SET (dbe_column_t *, col, &ks->ks_key->key_parts)
      {
	if (!ks_col_has_eq (ks, col))
	  {
	    NEW_VARZ (clo_comp_t, clo);
	    dk_set_push (&cl_order, (void *) clo);
	    clo->nth = dk_set_position (ks->ks_out_cols, (void *) col);
	    clo->col = col;
	    clo->is_desc = ks->ks_descending;
	  }
	nth++;
	if (nth >= ks->ks_key->key_n_significant)
	  break;
      }
      END_DO_SET ();
      ks->ks_cl_order = (clo_comp_t **) list_to_array (dk_set_nreverse (cl_order));
    }
}

void
sqlg_cl_ts_split (sqlo_t * so, df_elt_t * tb_dfe, table_source_t * ts)
{
  /* if a ts has a main ks in cl, make it two ts's.  Too complex otherwise */
  sql_comp_t *sc = so->so_sc;
  SQL_NODE_INIT (table_source_t, main_ts, table_source_input_unique, ts_free);

  main_ts->ts_order_ks = ts->ts_main_ks;
  ts->ts_main_ks = NULL;
  main_ts->src_gen.src_after_code = ts->src_gen.src_after_code;
  main_ts->src_gen.src_after_test = ts->src_gen.src_after_test;
  ts->src_gen.src_after_code = NULL;
  ts->src_gen.src_after_test = NULL;
  main_ts->src_gen.src_continuations = ts->src_gen.src_continuations;
  ts->src_gen.src_continuations = dk_set_cons ((void *) main_ts, NULL);
  main_ts->ts_is_unique = 1;
  main_ts->ts_order_cursor = ssl_new_itc (sc->sc_cc);
  main_ts->ts_current_of = ts->ts_current_of;
  main_ts->ts_in_index_path = 1;
  ts->ts_current_of = NULL;
  sqlg_cl_table_source (so, tb_dfe, main_ts);
}

void
sqlg_cl_table_source (sqlo_t * so, df_elt_t * tb_dfe, table_source_t * ts)
{
  /* fill in the cluster stuff in the ts if the keys require so */
  op_table_t *ot = tb_dfe->_.table.ot;
  if (ts->ts_inx_op)
    return;
  if (!sqlo_opt_value (ot->ot_opts, OPT_NO_CLUSTER) && !key_is_local_copy (ts->ts_order_ks->ks_key))
    {
  clb_init (so->so_sc->sc_cc, &ts->clb, 1);
  so->so_sc->sc_any_clb = 1;
  ts->clb.clb_itcl = ssl_new_variable (so->so_sc->sc_cc, "itcl", DV_UNKNOWN);
  ks_ordering_cols (so->so_sc, ts, 0);
    }
  ts->ts_order_ks->ks_ts = ts;
  if (ts->ts_main_ks)
    sqlg_cl_ts_split (so, tb_dfe, ts);
}




cu_func_t *
cu_func_qual (char *name)
{
  cu_func_t *cf = cu_func (name, 0);
  if (cf)
    return cf;
  if (!cf)
    {
      client_connection_t *cli = sqlc_client ();
      char complete[MAX_QUAL_NAME_LEN];
      complete_proc_name (name, complete, cli->cli_qualifier ? cli->cli_qualifier : "DB", CLI_OWNER (cli));
      cf = cu_func (complete, 0);
    }
  return cf;
}


int
is_pipe_call (instruction_t * ins, dk_set_t assigned)
{
  if (INS_CALL == ins->ins_type || INS_CALL_BIF == ins->ins_type)
    {

      cu_func_t *cf = cu_func_qual (ins->_.call.proc);
      if (cf)
	{
	  /* func exists and does not depend on results of this code vec */
	  int inx;
	  DO_BOX (state_slot_t *, ssl, inx, ins->_.call.params)
	  {
	    if (dk_set_member (assigned, (void *) ssl))
	      return 0;
	  }
	  END_DO_BOX;
	  return 1;
	}
    }
  return 0;
}


caddr_t bif_vector (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);

dk_set_t
dk_set_last_member (dk_set_t code, dk_set_t calls)
{
  dk_set_t iter = code;
  dk_set_t last = NULL;
  for (iter = code; iter; iter = iter->next)
      {
      if (dk_set_member (calls, iter->data))
	last = iter;
      }
  return last;
  }

dk_set_t
dk_set_prev (dk_set_t code, dk_set_t point)
	{
  dk_set_t iter = code;
  for (iter = code; iter; iter = iter->next)
	    {
      if (iter->next == point)
	return iter;
	    }
  return NULL;
	}



dpipe_node_t *
sqlg_pre_code_dpipe (sqlo_t * so, dk_set_t * code_ret, data_source_t * qn)
	{
  return NULL;
}

#define RI_MODE(ri) ((rdf_inf_pre_node_t*)ri)->ri_mode
#define IS_RI(qn) ((qn_input_fn)rdf_inf_pre_input == qn->src_input)

int
is_pre_node (data_source_t * qn)
{
  if (IS_RI (qn))
    return (RI_SUBCLASS == RI_MODE (qn) || RI_SUBPROPERTY == RI_MODE (qn) || ((rdf_inf_pre_node_t *) qn)->ri_sas_follow);
  if ((qn_input_fn) in_iter_input == qn->src_input)
    return 1;
  if ((qn_input_fn) trans_node_input == qn->src_input)
    return ((trans_node_t *) qn)->tn_is_pre_iter;
  return 0;
}


data_source_t *
qn_skip_pre_nodes (data_source_t * qn)
{
  while (qn && is_pre_node (qn))
    qn = qn_next (qn);
  return qn;
}


void
sqlg_place_dpipes (sqlo_t * so, data_source_t ** qn_ptr)
{
  /* place dpipe nodes and qf nodes for colocation fragments */
  data_source_t *qn = *qn_ptr;
  data_source_t *org_qn = qn;
  dpipe_node_t *dp;
  qn = qn_skip_pre_nodes (qn);
  dp = so->so_sc->sc_qn_to_dpipe ? (dpipe_node_t *) gethash ((void *) qn, so->so_sc->sc_qn_to_dpipe) : NULL;
  if (dp)
    {
      dk_set_push (&dp->src_gen.src_continuations, (void *) org_qn);
      *qn_ptr = (data_source_t *) dp;
      dk_set_delete (&qn->src_query->qr_nodes, (void *) dp);
      dk_set_ins_after (&qn->src_query->qr_nodes, (void *) org_qn, (void *) dp);
    }
  if ((qn_input_fn) fun_ref_node_input == qn->src_input)
    {
      fun_ref_node_t *fref = (fun_ref_node_t *) qn;
      sqlg_place_dpipes (so, &fref->fnr_select);
    }
  if (qn->src_continuations)
    {
      sqlg_place_dpipes (so, (data_source_t **) & qn->src_continuations->data);
    }
}


void
dpipe_node_free (dpipe_node_t * dp)
{
  clb_free (&dp->clb);
  dk_free_box ((caddr_t) dp->dp_funcs);
  dk_free_box ((caddr_t) dp->dp_outputs);
  dk_free_box ((caddr_t) dp->dp_inputs);
  dk_free_tree ((caddr_t) dp->dp_input_args);
}


#define IS_CO_DP(dp) (dp_can_dfg ((dpipe_node_t*)dp))

int
dp_can_dfg (dpipe_node_t * dp)
{
  if (IS_DP (dp) && 1 == BOX_ELEMENTS (dp->dp_funcs) && dp->dp_funcs[0]->cf_single_action)
    return 1;
  return 0;
}


void
dp_loc_ts (sql_comp_t * sc, dpipe_node_t * dp)
{
  /* make a fake ts to serve for partitioning a qf with a dpipe */
  search_spec_t **prev = NULL;
  cu_func_t *cf = dp->dp_funcs[0];
  dbe_key_t *key = cf->cf_part_key;
  key_source_t *ks = (key_source_t *) dk_alloc (sizeof (key_source_t));
  int inx;
  SQL_NODE_INIT (table_source_t, ts, table_source_input, ts_free);
  memset (ks, 0, sizeof (key_source_t));
  ts->ts_order_ks = ks;
  ks->ks_key = key;
  prev = &ks->ks_spec.ksp_spec_array;
  DO_BOX (col_partition_t *, cp, inx, key->key_partition->kpd_cols)
  {
    dbe_column_t *col = sch_id_to_col (wi_inst.wi_schema, cp->cp_col_id);
    int nth_arg = dk_set_position (key->key_parts, col);
    NEW_VARZ (search_spec_t, sp);
    *prev = sp;
    prev = &sp->sp_next;
    sp->sp_min_op = CMP_EQ;
    sp->sp_col = (dbe_column_t *) col;
    sp->sp_cl = *key_find_cl (key, sp->sp_col->col_id);
    sp->sp_min_ssl = dp->dp_input_args[0][nth_arg];
  }
  END_DO_BOX;
  dp->dp_loc_ts = ts;
}

/* Multistate code vectors */


int
qr_is_multistate (query_t * qr)
{
  return 1;
  DO_SET (data_source_t *, qn, &qr->qr_nodes)
  {
    if (qn_has_clb_save (qn))
      return 1;
    if ((qn_input_fn) subq_node_input == qn->src_input && qr_is_multistate (((subq_source_t *) qn)->sqs_query))
      return 1;
  }
  END_DO_SET ();
  return 0;
}


int
qr_begins_with_iter_or_test (query_t * qr, data_source_t ** first_clb_ret)
{
  data_source_t *first = NULL, *first_pre = NULL;
  DO_SET (data_source_t *, qn, &qr->qr_nodes)
  {
    if (qn_has_clb_save (qn))
      {
	first = qn;
	first_pre = NULL;
      }
    if (is_pre_node (qn))
      {
	first = NULL;
	first_pre = qn;
      }
  }
  END_DO_SET ();
  *first_clb_ret = first;
  if (!first)
    return 0;
  if ((qn_input_fn) set_ctr_input == first->src_input)
    return 0;
  if (!first_pre)
    {
      /* even if this begins with a qf or ts, it is possible that every set does not get stored if there are skipped rows from cast failures.  The real condition woul have to exclude cast failures and nulls.  */
      return 1;
    }
  return first_pre ? 1 : 0;
}


data_source_t *
sqlg_cv_subq_set_ctr (sql_comp_t * sc, query_t * qr)
{
  /* when there is a value subq or exists in a code vec and the clb node thereof is not the first because of some iter in front, must put a set ctr in front.  Return what is to be the clb_node of the subq */
  data_source_t *first_clb = NULL;
  if (qr_begins_with_iter_or_test (qr, &first_clb))
    {
      comp_context_t *cc = sc->sc_cc;
      NEW_VARZ (set_ctr_node_t, sctr);
      sctr->src_gen.src_in_state = cc_new_instance_slot (cc);
      sctr->src_gen.src_input = (qn_input_fn) set_ctr_input;
      sctr->src_gen.src_free = (qn_free_fn) set_ctr_free;
      sctr->src_gen.src_query = qr;
      clb_init (cc, &sctr->clb, 1);
      sctr->clb.clb_itcl = ssl_new_variable (cc, "itcl", DV_ANY);
      sctr->sctr_set_no = ssl_new_variable (cc, "set_no", DV_LONG_INT);
      qr->qr_nodes = dk_set_conc (qr->qr_nodes, dk_set_cons ((void *) sctr, NULL));
      sctr->src_gen.src_continuations = dk_set_cons ((void *) qr->qr_head_node, NULL);
      qr->qr_head_node = (data_source_t *) sctr;
      return (data_source_t *) sctr;
    }
  return first_clb;
}


void
cn_qr_set_no (sql_comp_t * sc, query_t * qr, code_node_t * cn, data_source_t ** clb_node, short *set_inx_ret)
{
  /* in a value or exists subq, find the headmost node which has a clb.  If there iters before this, make a set ctr in front.
   * the idea is that the clb must have exactly one state per invocation of the subq */
  cl_buffer_t *clb = NULL;
  data_source_t *first = NULL;
  first = sqlg_cv_subq_set_ctr (sc, qr);
  if (!first)
    {
      *clb_node = NULL;
      *set_inx_ret = 0;
      return;
    }
  *clb_node = first;
  clb = &((table_source_t *) first)->clb;
  clb->clb_keep_itcl_after_end = 1;
}


int
sqlg_qr_no_skip (query_t * qr)
{
  /* if the qr has unions or subqs with unions, the skipping to next set will not work.  Must get all the rows and only return the 1st of each set */
  DO_SET (data_source_t *, qn, &qr->qr_nodes)
  {
    if (IS_QN (qn, union_node_input))
      return 1;
    if (IS_QN (qn, subq_node_input) && sqlg_qr_no_skip (((subq_source_t *) qn)->sqs_query))
      return 1;
    if (IS_QN (qn, code_node_input))
      return 1;
  }
  END_DO_SET ();
  return 0;
}


void
qn_code_node (sql_comp_t * sc, data_source_t ** head, code_vec_t cv, dk_set_t ms_ins, int is_test, int in_order)
{
  query_t *qr = sc->sc_cc->cc_query;
  SQL_NODE_INIT (code_node_t, cn, code_node_input, cn_free);
  clb_init (sc->sc_cc, &cn->clb, 1);
  sc->sc_any_clb = 1;
  cn->cn_code = cv;
  cn->cn_continuable = ms_ins;
  cn->cn_state = cc_new_instance_slot (sc->sc_cc);
  cn->cn_results = cc_new_instance_slot (sc->sc_cc);
  cn->cn_itcl = ssl_new_variable (sc->sc_cc, "cn_itcl", DV_ANY);
  cn->cn_set_no = ssl_new_variable (sc->sc_cc, "set_no", DV_LONG_INT);
  cn->cn_is_test = is_test;
  cn->cn_is_order = in_order;
  DO_SET (instruction_t *, ins, &ms_ins)
  {
    switch (ins->ins_type)
      {
      case INS_SUBQ:
	ins->_.subq.cl_cn = cn;
	ins->_.subq.cl_run = ssl_new_variable (sc->sc_cc, "in", DV_STRING);
	ins->_.subq.cl_out = ssl_new_variable (sc->sc_cc, "out", DV_STRING);
	cn_qr_set_no (sc, ins->_.subq.query, cn, &ins->_.subq.cl_clb, &ins->_.subq.cl_set_no_in_clb);
	ins->_.subq.query->qr_select_node->sel_cn_set_no = cn->cn_set_no;
	if (sqlg_qr_no_skip (ins->_.subq.query))
	  ins->_.subq.query->qr_select_node->sel_row_ctr_array = ssl_new_variable (sc->sc_cc, "set_ctr_arr", DV_STRING);
	sqlg_top_max (ins->_.subq.query);
	break;
      case IN_PRED:
	{
	  subq_pred_t *subp = (subq_pred_t *) ins->_.pred.cmp;
	  subp->subp_cl_cn = cn;
	  subp->subp_cl_run = ssl_new_variable (sc->sc_cc, "in", DV_STRING);
	  subp->subp_cl_out = ssl_new_variable (sc->sc_cc, "out", DV_STRING);
	  cn_qr_set_no (sc, subp->subp_query, cn, &subp->subp_cl_clb, &subp->subp_cl_set_no_in_clb);
	  subp->subp_query->qr_select_node->sel_cn_set_no = cn->cn_set_no;
	  if (sqlg_qr_no_skip (subp->subp_query))
	    subp->subp_query->qr_select_node->sel_row_ctr_array = ssl_new_variable (sc->sc_cc, "set_ctr_arr", DV_STRING);
	  sqlg_top_max (subp->subp_query);
	  break;
	}
      }
  }
  END_DO_SET ();
  dk_set_delete (&qr->qr_nodes, (void *) cn);
  dk_set_ins_after (&qr->qr_nodes, *head, (void *) cn);
  dk_set_pushnew (&qr->qr_nodes, (void *) cn);	/* if no next node, put at the start of continue list */
  if (*head)
    dk_set_push (&cn->src_gen.src_continuations, (void *) *head);

  *head = (data_source_t *) cn;
}



void
sqlg_multistate_code (sql_comp_t * sc, data_source_t ** head, int in_order)
{
}


/* Multistate dt.  Used for derived tables, any subq with aggregation */


void
ssa_init (sql_comp_t * sc, setp_save_t * ssa, state_slot_t * set_no_ssl)
{
  ssa->ssa_set_no = set_no_ssl;
  ssa->ssa_array = ssl_new_variable (sc->sc_cc, "multistate_save", DV_ARRAY_OF_POINTER);
  ssa->ssa_current_set = ssl_new_variable (sc->sc_cc, "last_set_no", DV_LONG_INT);
  ssa->ssa_batch_size = cl_req_batch_size;
}

state_slot_t *
sqlg_set_no_if_needed (sql_comp_t * sc, data_source_t ** head)
{
  if (sc->sc_set_no_ssl)
    return sc->sc_set_no_ssl;
  if (!sqlg_is_vector)
    return NULL;
  sc->sc_set_no_ssl = ssl_new_variable (sc->sc_cc, "set_ctr", DV_LONG_INT);
  sc->sc_set_no_ssl->ssl_sqt.sqt_non_null = 1;
  {
    SQL_NODE_INIT (set_ctr_node_t, sctr, set_ctr_input, set_ctr_free);
    if (*head)
      dk_set_push (&sctr->src_gen.src_continuations, (void *) *head);
    *head = (data_source_t *) sctr;
    if (!sqlg_is_vector)
      {
	clb_init (sc->sc_cc, &sctr->clb, 1);
	sctr->clb.clb_itcl = ssl_new_variable (sc->sc_cc, "itcl", DV_ANY);
      }
    sctr->sctr_set_no = sc->sc_set_no_ssl;
    dk_set_delete (&sc->sc_cc->cc_query->qr_nodes, (void *) sctr);
    sc->sc_cc->cc_query->qr_nodes = dk_set_conc (sc->sc_cc->cc_query->qr_nodes, dk_set_cons ((void *) sctr, NULL));
  }
  return sc->sc_set_no_ssl;
}

dk_set_t
sqlg_const_ssl_list (sql_comp_t * sc, dk_set_t vals)
{
  dk_set_t r = NULL;
  DO_SET (caddr_t, v, &vals)
  {
    dk_set_push (&r, (void *) ssl_new_constant (sc->sc_cc, v));
  }
  END_DO_SET ();
  return dk_set_nreverse (r);
}


void
sqlg_cl_multistate_group (sql_comp_t * sc)
{
  /* add a clb to the fref, to the setps */
  fun_ref_node_t *fref = sc->sc_fref;
  setp_node_t *setp = fref->fnr_setp;
      clb_init (sc->sc_cc, &fref->clb, 1);
      fref->clb.clb_itcl = ssl_new_variable (sc->sc_cc, "itcl", DV_ANY);

  if (sc->sc_order != TS_ORDER_NONE || (setp && setp->setp_ha && HA_ORDER == setp->setp_ha->ha_op))
    fref->fnr_is_order = 1;
  return;			/* below os only for non vectored cluster */
  if (!sc->sc_set_no_ssl)
    {
      sc->sc_set_no_ssl = ssl_new_variable (sc->sc_cc, "set_ctr", DV_LONG_INT);
      fref->fnr_is_set_ctr = 1;
    }
  ssa_init (sc, &fref->fnr_ssa, sc->sc_set_no_ssl);
  if (!fref->fnr_setps)
    dk_set_push (&fref->fnr_setps, (void *) fref->fnr_setp);
  DO_SET (setp_node_t *, setp, &fref->fnr_setps)
  {
    setp->setp_ssa.ssa_set_no = fref->fnr_ssa.ssa_set_no;
  }
  END_DO_SET ();
}

void
qf_set_max_rows (query_frag_t * qf, int max)
{
  data_source_t *qn;
  table_source_t *last_ts = NULL;
  qf->qf_max_rows = max;
  for (qn = qf->qf_head_node; qn; qn = qn_next (qn))
    {
      if (IS_TS (qn))
	{
	  if (!qn->src_after_test)
	    last_ts = (table_source_t *) qn;
	  else
	    last_ts = NULL;
	}
      else if (IS_QN (qn, qf_select_node_input))
	break;
      else
	last_ts = NULL;
    }
  if (last_ts)
    last_ts->ts_max_rows = max;
}


void
sqlg_top_max (query_t * qr)
{
  /* if last is cluster ts or qf and next is a select with top and no tests in between, set the set the max in the ts/qf */
  data_source_t *qn, *last_cl = NULL;
  if (!qr->qr_select_node || (!qr->qr_select_node->sel_top && !qr->qr_select_node->sel_cn_set_no))
    return;
  for (qn = qr->qr_head_node; qn; qn = qn_next (qn))
    {
      if (qn->src_after_test)
	{
	  last_cl = NULL;
	  continue;
	}
      if (IS_TS ((table_source_t *) qn))
	{
	  QNCAST (table_source_t, ts, qn);
	  if (ts->clb.clb_fill && !ts->ts_after_join_test && !ts->ts_inx_op && !ts->ts_order_ks->ks_local_test)
	    last_cl = qn;
	  else
	    last_cl = NULL;
	}
      else if ((qn_input_fn) query_frag_input == qn->src_input)
	last_cl = qn;
      else if ((qn_input_fn) end_node_input == qn->src_input)
	{
	  if (qn->src_after_test)
	    last_cl = NULL;
	}
      else if ((qn_input_fn) dpipe_node_input == qn->src_input)
	continue;
      else if ((qn_input_fn) code_node_input == qn->src_input)
	{
	  QNCAST (code_node_t, cn, qn);
	  if (cn->cn_is_test)
	    last_cl = NULL;
	  else
	    continue;
	}
      else if ((qn_input_fn) select_node_input == qn->src_input || (qn_input_fn) select_node_input_subq == qn->src_input)
	break;
      else
	last_cl = NULL;
    }
  if (last_cl)
    {
      select_node_t *sel = qr->qr_select_node;
      int max = 20;
      if (sel->sel_cn_set_no)
	max = 1;
      else
	{
	  int top = SSL_CONSTANT == sel->sel_top->ssl_type ? unbox (sel->sel_top->ssl_constant) : 0;
	  int skip = sel->sel_top_skip && SSL_CONSTANT == sel->sel_top_skip->ssl_type ? unbox (sel->sel_top_skip->ssl_constant) : 0;
	  max = top + skip;
	  if (max > 10000)
	    max = 0;
	}
      if (IS_TS ((table_source_t *) last_cl))
	((table_source_t *) last_cl)->ts_max_rows = max;
      else
	qf_set_max_rows ((query_frag_t *) last_cl, max);
    }
}



int
sqlg_distinct_colocated (sql_comp_t * sc, state_slot_t ** ssls, int n_ssls)
{
  return 0;
}

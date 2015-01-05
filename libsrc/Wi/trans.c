/*
 *  trans.c
 *
 *  $Id$
 *
 *  Transitive Node
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

#include "sqlnode.h"
#include "sqlbif.h"
#include "eqlcomp.h"
#include "sqlfn.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlo.h"
#include "list2.h"
#include "xmlnode.h"
#include "xmltree.h"
#include "arith.h"
#include "rdfinf.h"
#include "rdf_core.h"


#define TN_INIT 1
#define TN_RUN 2
#define TN_RESULTS 3



void
ht_free_no_content (id_hash_t * ht)
{
}


int
lc_set_no (srv_stmt_t * lc)
{
  if (1 == lc->sst_batch_size)
    return 0;
  return unbox (QST_GET_V (lc->sst_qst, lc->sst_query->qr_select_node->sel_set_no));
}


int
qr_batch_size (query_t * qr)
{
  return 1;
}


caddr_t *
lc_t_row (srv_stmt_t * lc)
{
  select_node_t * sn = lc->sst_query->qr_select_node;
  state_slot_t ** sel  = sn->sel_out_slots;
  caddr_t * out = (caddr_t*) t_alloc_box (sn->sel_n_value_slots * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  int inx;
  for (inx = 0; inx < sn->sel_n_value_slots; inx++)
    {
      out[inx] = t_full_box_copy_tree (qst_get (lc->sst_qst, sel[inx]));
    }
  return out;
}


int
lc_exec (srv_stmt_t * lc, caddr_t * row, caddr_t last, int is_exec)
{
  int inx = 0;
  QNCAST (query_instance_t, qi, lc->sst_qst);
  NO_TMP_POOL;
  if (is_exec)
    {
      DO_SET (state_slot_t *, ssl, &lc->sst_query->qr_parms)
	{
	  if (inx < BOX_ELEMENTS (row))
	    qst_set (lc->sst_qst, ssl, box_copy_tree (row[inx++]));
	  else
	    qst_set (lc->sst_qst, ssl, box_copy_tree (last));
	}
      END_DO_SET();
    }
  qi->qi_thread = THREAD_CURRENT_THREAD; /* a cursor may continue on a different thread and the lc may have been created on a prior thread */
  QR_RESET_CTX
    {
      if (is_exec)
	{
	  if (lc->sst_query->qr_select_node)
	    lc->sst_query->qr_select_node->src_gen.src_input = (qn_input_fn)select_node_input_subq;
	  qn_input (lc->sst_query->qr_head_node, lc->sst_qst, lc->sst_qst);
	  if (1 == lc->sst_batch_size)
	    {
	      qr_resume_pending_nodes (lc->sst_query, lc->sst_qst);
	      POP_QR_RESET;
	      return LC_AT_END;
	    }
	  if (lc->sst_query->qr_cl_run_started
	      && lc->sst_qst[lc->sst_query->qr_cl_run_started])
	    {
	      qr_resume_pending_nodes (lc->sst_query, lc->sst_qst);
	      POP_QR_RESET;
	      return LC_AT_END;
	    }
	  else
	    {
	      POP_QR_RESET;
	      return LC_INIT;
	    }
	}
      else
	{
	  qr_resume_pending_nodes (lc->sst_query, lc->sst_qst);
	  POP_QR_RESET;
	  return LC_AT_END;
	}
    }
  QR_RESET_CODE
    {
      POP_QR_RESET;
      if (reset_code != RST_ENOUGH)
	{
	  lc->sst_pl_error = subq_handle_reset ((query_instance_t*)lc->sst_qst, reset_code);
	  return LC_ERROR;
	}
      return LC_ROW;
    }
  END_QR_RESET;
}


srv_stmt_t *
qr_multistate_lc (query_t * qr, query_instance_t * caller)
{
  caddr_t *inst = (caddr_t *) qi_alloc (qr, NULL, NULL, 0);
  query_instance_t *qi = (query_instance_t *) inst;
  srv_stmt_t * lc = dk_alloc_box_zero (sizeof (srv_stmt_t), DV_PL_CURSOR);
  qi->qi_query = qr;
  qi->qi_no_cast_error = qr->qr_no_cast_error;
  qi->qi_caller = caller;
  qi->qi_client = caller->qi_client;
  qi->qi_thread = THREAD_CURRENT_THREAD;
  qi->qi_threads = 1;
  qi->qi_u_id = caller->qi_u_id;
  qi->qi_g_id = caller->qi_g_id;
  qi->qi_isolation = caller->qi_isolation;
  qi->qi_lock_mode = caller->qi_lock_mode;
  qi->qi_no_triggers = caller->qi_no_triggers;

  qi->qi_trx = caller->qi_trx;

  lc->sst_query = qr;
  lc->sst_batch_size = qr_batch_size (qr);
  lc->sst_qst = (caddr_t *) qi;
  return lc;
}


void
tn_read_lc (trans_node_t * tn, caddr_t * inst, srv_stmt_t * lc, caddr_t * arr, caddr_t any, int fill, int rc)
{
  /* update tn_relation to contain the fetched results */
  id_hash_t * relation = (id_hash_t*)qst_get (inst, tn->tn_relation);
  if (LC_INIT == rc)
    WITHOUT_TMP_POOL {
      rc = lc_exec (lc, NULL, NULL, 0);
    } END_WITHOUT_TMP_POOL;
  for (;;)
    {
      if (LC_ERROR == rc)
	{
	  caddr_t err = lc->sst_pl_error;
	  lc->sst_pl_error = NULL;
	  SET_THR_TMP_POOL (NULL);
	  dk_free_box (any);
	  dk_free_box ((caddr_t)arr);
	  sqlr_resignal (err);
	}
      if (LC_ROW == rc)
	{
	  int set_no = lc_set_no (lc);
	  dk_set_t * place = (dk_set_t*) id_hash_get (relation, (caddr_t)&arr[set_no]);
	  any[set_no] = 1;
	  if (THR_TMP_POOL->mp_bytes > tn->tn_max_memory)
	    {
	      SET_THR_TMP_POOL (NULL);
	      sqlr_new_error ("42000", "TN...", "Exceeded " BOXINT_FMT " bytes in transitive temp memory.  This was detected in expanding a owl:sameAs or IFP implied identity.", (boxint) tn->tn_max_memory);
	    }
	  if (place)
	    t_set_push (place, (void*) lc_t_row (lc));
	  else
	    {
	      dk_set_t init = t_cons ((void*)lc_t_row (lc), NULL);
	      id_hash_set (relation, (caddr_t)&arr[set_no], (caddr_t)&init);
	    }
	}
      if (LC_AT_END == rc)
	{
	  int inx;
	  for (inx = 0; inx < fill; inx++)
	    {
	      caddr_t n = NULL;
	      if (!any[inx]
		  && !id_hash_get (relation, (caddr_t)&arr[inx]))
		id_hash_set (relation, (caddr_t)&arr[inx], (caddr_t)&n);
	    }
	  return;
	}
      WITHOUT_TMP_POOL {
	rc = lc_exec (lc, NULL, NULL, 0);
      } END_WITHOUT_TMP_POOL;
    }
}


int
tn_inlined_exec (trans_node_t * tn, caddr_t * inst, caddr_t * value, int is_exec, caddr_t * err_ret)
{
  query_t * qr = tn->tn_inlined_step;
  int inx;
  NO_TMP_POOL;
  QR_RESET_CTX
    {
      if (is_exec)
	{
	  DO_BOX (state_slot_t *, ssl, inx, tn->tn_input)
	    {
	      qst_set (inst, ssl, box_copy_tree (value[inx]));
	    }
	  END_DO_BOX;
	  qn_input (qr->qr_head_node, inst, inst);
	  if (!qr->qr_cl_run_started )
	    {
	      qr_resume_pending_nodes (qr, inst);
	      POP_QR_RESET;
	      return LC_AT_END;
	    }
	  else if (inst[qr->qr_cl_run_started])
	    {
	      qr_resume_pending_nodes (qr, inst);
	      POP_QR_RESET;
	      return LC_AT_END;
	    }
	  POP_QR_RESET;
	  return LC_INIT;
	}
      qr_resume_pending_nodes (qr, inst);
      POP_QR_RESET;
      return LC_AT_END;
    }
  QR_RESET_CODE
    {
      POP_QR_RESET;
      if (reset_code != RST_ENOUGH)
	{
	  *err_ret = subq_handle_reset ((query_instance_t*)inst, reset_code);
	  return LC_ERROR;
	}
      return LC_ROW;
    }
  END_QR_RESET;
}


int
subq_set_no (query_t * qr, caddr_t * inst)
{
  if (!qr->qr_select_node->sel_set_no)
    return 0;
  return unbox (qst_get (inst, qr->qr_select_node->sel_set_no));
}


caddr_t *
tn_t_row (trans_node_t * tn, caddr_t * inst)
{
  caddr_t * out = (caddr_t*) t_alloc_box (BOX_ELEMENTS (tn->tn_output) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  int inx;
  DO_BOX (state_slot_t *, ssl, inx, tn->tn_output)
    {
      out[inx] = t_full_box_copy_tree (qst_get (inst, ssl));
    }
  END_DO_BOX;
  if (tn->tn_data || tn->tn_end_flag)
    {
      caddr_t * tuple = (caddr_t*)t_alloc_box (3 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      tuple[0] = (caddr_t)out;
      tuple[2] = tn->tn_end_flag ? t_full_box_copy_tree (qst_get (inst, tn->tn_end_flag)) : NULL;
      if (tn->tn_data)
	{
	  tuple[1] = t_box_copy ((caddr_t)tn->tn_data);
	  DO_BOX (state_slot_t *, dt, inx, tn->tn_data);
	  {
	    ((caddr_t*)tuple[1])[inx] = t_full_box_copy_tree (qst_get (inst, dt));
	  }
	  END_DO_BOX;
	}
      else
	tuple[1] = NULL;
      out = tuple;
    }
  return out;
}


void
tn_read_inlined (trans_node_t * tn, caddr_t * inst, caddr_t * arr, caddr_t any, int fill, int rc)
{
  /* update tn_relation to contain the fetched results */
  id_hash_t * relation = (id_hash_t*)qst_get (inst, tn->tn_relation);
  caddr_t err = NULL;
  if (LC_INIT == rc)
    {
      WITHOUT_TMP_POOL {
	rc = tn_inlined_exec (tn, inst, NULL, 0, &err);
      } END_WITHOUT_TMP_POOL;
    }
  for (;;)
    {
      if (LC_ERROR == rc)
	{
	  dk_free_box (any);
	  dk_free_box ((caddr_t)arr);
	  SET_THR_TMP_POOL (NULL);
	  sqlr_resignal (err);
	}
      if (LC_ROW == rc)
	{
	  int set_no = subq_set_no (tn->tn_inlined_step, inst);
	  dk_set_t * place = (dk_set_t*) id_hash_get (relation, (caddr_t)&arr[set_no]);
	  any[set_no] = 1;
	  if (THR_TMP_POOL->mp_bytes > tn->tn_max_memory)
	    {
	      SET_THR_TMP_POOL (NULL);
	      sqlr_new_error ("42000", "TN...", "Exceeded " BOXINT_FMT " bytes in transitive temp memory.  use t_distinct, t_max or more T_MAX_memory options to limit the search or increase the pool", (boxint) tn->tn_max_memory);
	    }
	  if (place)
	    t_set_push (place, (void*) tn_t_row (tn, inst));
	  else
	    {
	      dk_set_t init = t_cons ((void*)tn_t_row (tn, inst), NULL);
	      id_hash_set (relation, (caddr_t)&arr[set_no], (caddr_t)&init);
	    }
	}
      if (LC_AT_END == rc)
	{
	  int inx;
	  for (inx = 0; inx < fill; inx++)
	    {
	      caddr_t n = NULL;
	      if (!any[inx]
		  && !id_hash_get (relation, (caddr_t)&arr[inx]))
		id_hash_set (relation, (caddr_t)&arr[inx], (caddr_t)&n);
	    }
	  return;
	}
      WITHOUT_TMP_POOL {
      rc = tn_inlined_exec (tn, inst, NULL, 0, &err);
      } END_WITHOUT_TMP_POOL;
    }
}


int
tn_ifp_step (trans_node_t * tn, caddr_t * inst, srv_stmt_t * lc, caddr_t value)
{
  caddr_t tmp[10];
  caddr_t * row, r2;
  int len = tn->tn_ifp_g_list ? 3 : 2, rc;
  BOX_AUTO (r2, tmp, len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  row = (caddr_t*)r2;
  row[0] = ((caddr_t*)value)[0];
  row[1] = tn->tn_ifp_ctx_name;
  if (tn->tn_ifp_g_list)
    {
      caddr_t l = qst_get (inst, tn->tn_ifp_g_list);
      if (!l)
	{
	  int inx;
	  l = box_copy ((caddr_t)tn->tn_sas_g);
	  DO_BOX (state_slot_t *, ssl, inx, tn->tn_sas_g)
	    {
	      ((caddr_t*)l)[inx] = box_copy_tree (qst_get (inst, ssl));
	    }
	  END_DO_BOX;
	  qst_set (inst, tn->tn_ifp_g_list, l);
	}
      row[2] = l;
    }
  WITHOUT_TMP_POOL
    {
      rc = lc_exec (lc, row, NULL, 1);
    }
  END_WITHOUT_TMP_POOL;
  return rc;
}


void
tn_fetch (trans_node_t * tn, caddr_t * inst)
{
  id_hash_t * to_fetch = (id_hash_t*)qst_get (inst, tn->tn_to_fetch);
  caddr_t *p_value;
  ptrlong ignore;
  id_hash_iterator_t hit;
  int rc;
  if (!to_fetch)
    return;
  if (tn->tn_prepared_step)
    {
      query_t * qr = tn->tn_prepared_step;
      srv_stmt_t * lc = (srv_stmt_t*)qst_get (inst, tn->tn_lc);
      int batch_size = qr_batch_size (qr);
      int fill = 0;
      caddr_t * arr = dk_alloc_box (sizeof (caddr_t) * batch_size, DV_BIN);
      caddr_t any = dk_alloc_box_zero (batch_size, DV_BIN);
      id_hash_iterator (&hit, to_fetch);
      if (!lc)
	{
	  lc = qr_multistate_lc (tn->tn_prepared_step, (query_instance_t *)inst);
	  qst_set (inst, tn->tn_lc, (caddr_t)lc);
	}
      else
	subq_init (lc->sst_query, lc->sst_qst);
      lc->sst_qst[tn->tn_prepared_step->qr_select_node->sel_out_quota] = 0; /* make no local out buffer of rows */
      rc = LC_AT_END;
      while (hit_next (&hit, (caddr_t*)&p_value, (caddr_t*)&ignore))
	{
	  caddr_t value = *p_value;
	  if (tn->tn_ifp_ctx_name)
	    {
	      arr[fill++] = value;
	      rc = tn_ifp_step (tn, inst, lc, value);
	      if (LC_INIT == rc)
		continue;
	      if (LC_ERROR == rc)
		{
		  caddr_t err = lc->sst_pl_error;
		  lc->sst_pl_error = NULL;
		  dk_free_box ((caddr_t)arr);
		  dk_free_box (any);
		  SET_THR_TMP_POOL (NULL);
		  sqlr_resignal (err);
		}
	    }
	  else if (tn->tn_sas_g)
	    {
	      int nth_g;
	      for (nth_g = 0; nth_g < BOX_ELEMENTS (tn->tn_sas_g); nth_g++)
		{
		  arr[fill++] = value;
		  WITHOUT_TMP_POOL
		    {
		      rc = lc_exec (lc, (caddr_t*)value, qst_get (inst, tn->tn_sas_g[nth_g]), 1);
		    }
		  END_WITHOUT_TMP_POOL;
		  if (LC_INIT == rc)
		    continue;
		  tn_read_lc (tn, inst, lc, arr, any, fill, rc);
		  fill = 0;
		  rc = LC_AT_END;
		  memset (any, 0, box_length (any));
		  continue;
		}
	      goto next_value;
	    }
	  else
	    {
	      arr[fill++] = value;
	      WITHOUT_TMP_POOL {
		rc = lc_exec (lc, (caddr_t*)value, NULL, 1);
	      } END_WITHOUT_TMP_POOL;
	      if (LC_INIT == rc)
		continue;
	    }
	  tn_read_lc (tn, inst, lc, arr, any, fill, rc);
	  rc = LC_AT_END;
	  fill = 0;
	  memset (any, 0, box_length (any));
	next_value: ;
	}
      if (LC_AT_END != rc)
	tn_read_lc (tn, inst, lc, arr, any, fill, rc);
      id_hash_clear (to_fetch);
      dk_free_box (any);
      dk_free_box ((caddr_t)arr);
    }
  else
    {
      query_t * qr = tn->tn_inlined_step;
      int batch_size = qr_batch_size (qr);
      int fill = 0;
      caddr_t * arr = dk_alloc_box (sizeof (caddr_t) * batch_size, DV_BIN);
      caddr_t any = dk_alloc_box_zero (batch_size, DV_BIN);
      id_hash_iterator (&hit, to_fetch);
      subq_init (qr, inst);
      rc = LC_AT_END;
      while (hit_next (&hit, (caddr_t*)&p_value, (caddr_t*)&ignore))
	{
	  caddr_t value = *p_value;
	  caddr_t err= NULL;
	  qst_set_long (inst, tn->tn_step_set_no, fill);
	  arr[fill++] = value;
	  WITHOUT_TMP_POOL {
	    rc = tn_inlined_exec (tn, inst, (caddr_t*)value, 1, &err);
	  } END_WITHOUT_TMP_POOL;
	  if (LC_INIT == rc && fill < batch_size)
	    continue;
	  if (LC_ERROR == rc)
	    {
	      dk_free_box ((caddr_t)arr);
	      dk_free_box (any);
	      SET_THR_TMP_POOL (NULL);
	      sqlr_resignal (err);
	    }
	  tn_read_inlined (tn, inst, arr, any, fill, rc);
	  rc = LC_AT_END;
	  fill = 0;
	  memset (any, 0, box_length (any));
	}
      if (LC_AT_END != rc)
	tn_read_inlined (tn, inst, arr, any, fill, rc);
      id_hash_clear (to_fetch);
      dk_free_box (any);
      dk_free_box ((caddr_t)arr);
    }
}


void
tn_fetchable (trans_node_t * tn, caddr_t * inst, caddr_t value)
{
  id_hash_t * to_fetch = (id_hash_t *)qst_get (inst, tn->tn_to_fetch);
  ptrlong one = 1;
  if (!to_fetch)
    {
      to_fetch = (id_hash_t*)box_dv_dict_hashtable (61);
      to_fetch->ht_free_hook = ht_free_no_content;
      id_hash_set_rehash_pct  (to_fetch, 300);
      qst_set (inst, tn->tn_to_fetch, (caddr_t)to_fetch);
    }
  if (id_hash_get (to_fetch, (caddr_t)&value))
    return;
  id_hash_set (to_fetch, (caddr_t)&value, (caddr_t)&one);
}


void
ts_new_result (trans_node_t * tn, caddr_t * inst, trans_set_t * ts, trans_state_t * tst)
{
  if (tn->tn_path_ctr)
    tst->tst_path_no = QST_INT (inst, tn->tn_path_ctr)++;
  if (!ts->ts_last_result)
    ts->ts_last_result = ts->ts_result = t_cons ((void*)tst, NULL);
  else
    {
      ts->ts_last_result->next = t_cons ((void*)tst, NULL);
      ts->ts_last_result = ts->ts_last_result->next;
    }
}


int
path_member (trans_state_t * tst, caddr_t value)
{
  for (tst = tst; tst; tst = tst->tst_prev)
    if (box_equal (tst->tst_value, value))
      return 1;
  return 0;
}


trans_state_t *
tn_rl_shifted_copy (trans_state_t * rl, caddr_t data)
{
  if (!rl)
    return NULL;
  if (!data)
    return tn_rl_shifted_copy (rl->tst_prev, rl->tst_data);
  else
    {
      t_NEW_VAR (trans_state_t, rl2);
      memcpy (rl2, rl, sizeof (trans_state_t));
      rl2->tst_data = data;
      rl2->tst_prev = tn_rl_shifted_copy (rl->tst_prev, rl->tst_data);
      return rl2;
    }
}


void
tn_merge_path (trans_node_t * tn, caddr_t * inst, trans_set_t * ts, trans_state_t * lr, trans_state_t * rl)
{
  /* when a lr and rl path meet, a composite rl path is made by putting the reversed lr in front.  The operand which was not advancing when the paths met is shortened by one.  By convention, the primary goes rl and the complement lr */
  trans_node_t * primary_tn = tn->tn_is_primary ? tn : tn->tn_complement;
  if (tn->tn_data)
    {
      /* if there is step data, present the steps as lr.  So the step data of the rl path gets shifted one towards the start of the path. */
      rl = tn_rl_shifted_copy (rl, NULL);
    }
  else
    {
      if (tn->tn_is_primary)
	lr = lr->tst_prev;
      else
	rl = rl->tst_prev;
    }
  while (lr)
    {
      t_NEW_VAR (trans_state_t, new_rl);
      memcpy (new_rl, lr, sizeof (trans_state_t));
      new_rl->tst_prev = rl;
      new_rl->tst_depth = rl ? rl->tst_depth + 1 : 0;
      rl = new_rl;
      lr = lr->tst_prev;
    }
  ts_new_result (primary_tn, inst, ts, rl);
}


int
ts_check_target (trans_node_t * tn, caddr_t * inst, trans_set_t * ts, trans_state_t * tst)
{
  /* if looking for a specific node or an intersection with another trans set, check if this is the case
   * If intersecting trans sets, set the max depth in both to be equal to the depth at the time of finding the first common element */
  dk_set_t complements;
  if (ts->ts_target_ts)
    {
      dk_set_t * place;
      if ((place = (dk_set_t*)id_hash_get (ts->ts_target_ts->ts_traversed, (caddr_t)&tst->tst_value)))
	{
	  if (tn->tn_distinct )
	    complements = t_CONS ((void*)*place, NULL);
	  else
	    complements = *place;
	  DO_SET (trans_state_t *, complement, &complements)
	    {
	      if (tn->tn_is_primary)
		tn_merge_path (tn, inst, ts, complement, tst);
	      else
		tn_merge_path (tn, inst, ts->ts_target_ts, tst, complement);
	    }
	  END_DO_SET();
	  return 1;
	}
      else
	return 0;
    }
  if (ts->ts_target)
    {
      if (box_equal (ts->ts_target, tst->tst_value))
	{
	  ts_new_result (tn, inst, ts, tst);
	  return 1;
	}
      return 0;
    }
  return 0;
}


void
tst_next_states (trans_node_t * tn, caddr_t * inst, trans_set_t * ts, trans_state_t * tst, dk_set_t * new_ret)
{
  id_hash_t * relation = (id_hash_t*)qst_get (inst, tn->tn_relation);
  dk_set_t * rel_place;
  if (tn->tn_max_depth
      && tst->tst_depth >= ts->ts_max_depth)
    return;
  rel_place = (dk_set_t*)id_hash_get (relation, (caddr_t)&tst->tst_value);
  if (!rel_place)  GPF_T1 ("should have been fetched");
  DO_SET (caddr_t *, related_tuple, rel_place)
    {
      trans_state_t * rel;
      caddr_t related = (!tn->tn_data && !tn->tn_end_flag) ? (caddr_t)related_tuple : related_tuple[0];;

      if (tn->tn_distinct
	  && id_hash_get (ts->ts_traversed, (caddr_t)&related))
	continue;
      if (tn->tn_no_cycles
	  && path_member (tst, related))
	continue;
      if (THR_TMP_POOL->mp_bytes > tn->tn_max_memory)
	{
	  SET_THR_TMP_POOL (NULL);
	  sqlr_new_error ("42000", "TN...", "Exceeded " BOXINT_FMT " bytes in transitive temp memory.  use t_distinct, t_max or more T_MAX_memory options to limit the search or increase the pool", (boxint) tn->tn_max_memory);
	}
      rel = (trans_state_t*)t_alloc (sizeof (trans_state_t));
      memset (rel, 0, sizeof (trans_state_t));
      rel->tst_value = related;
      if (tn->tn_data)
	rel->tst_data = related_tuple[1];
      rel->tst_prev = tst;
      rel->tst_depth = 1 + tst->tst_depth;
      if (tn->tn_distinct)
	t_id_hash_set (ts->ts_traversed, (caddr_t)&related, (caddr_t)&rel);
      else if (tn->tn_complement)
	{
	  dk_set_t * set_place = (dk_set_t*) id_hash_get (ts->ts_traversed, (caddr_t)&related);
	  if (set_place)
	    t_set_push (set_place, (void*)rel);
	  else
	    {
	      dk_set_t f = t_CONS (rel, NULL);
	      t_id_hash_set (ts->ts_traversed, (caddr_t)&rel->tst_value, (caddr_t)&f);
	    }
	}

      if (tn->tn_end_flag && unbox (related_tuple[2]))
	{
	  ts_new_result (tn, inst, ts, rel);
	  continue;
	}
      if (tn->tn_cycles_only)
	{
	  if (path_member (rel->tst_prev, rel->tst_value))
	    ts_new_result (tn,  inst, ts, rel);
	  if (!ts->ts_max_depth || rel->tst_depth < ts->ts_max_depth)
	    t_set_push (new_ret, (void*)rel);
	  continue;
	}
      if (ts_check_target (tn, inst, ts, rel))
	continue;

      if (!ts->ts_max_depth || rel->tst_depth < ts->ts_max_depth)
	t_set_push (new_ret, (void*)rel);
      if (tn->tn_min_depth && rel->tst_depth < unbox (qst_get (inst, tn->tn_min_depth)))
	continue;
      if (!ts->ts_target && !ts->ts_target_ts)
	ts_new_result (tn, inst, ts, rel);
    }
  END_DO_SET();
}


void
ts_advance (trans_node_t * tn, caddr_t * inst, trans_set_t * ts)
{
  dk_set_t next = NULL;
  if (tn->tn_shortest_only && (ts->ts_result || (ts->ts_target_ts && ts->ts_target_ts->ts_result)))
    {
      ts->ts_new = NULL;
      return;
    }
  DO_SET (trans_state_t *, tst, &ts->ts_new)
    {
      tst_next_states (tn, inst, ts, tst, &next);
    }
  END_DO_SET ();
  ts->ts_new = next;
}


int
tn_count (trans_node_t * tn, caddr_t * inst, int * new_ret)
{
  int ctr = 0, new_ctr = 0;
  id_hash_t * sets = QST_BOX (id_hash_t *, inst, tn->tn_input_sets);
  DO_IDHASH (caddr_t, in, trans_set_t *, ts, sets)
    {
      ctr += ts->ts_traversed->ht_count;
      new_ctr += dk_set_length (ts->ts_new);
    }
  END_DO_IDHASH;
  *new_ret = new_ctr;
  return ctr;
}


void
tn_dec_depth (trans_node_t * tn, caddr_t * inst)
{
  /* when one side takes a step towards the other, the other side's max depth decreases by one */
  id_hash_t * sets = QST_BOX (id_hash_t *, inst, tn->tn_input_sets);
  DO_IDHASH (caddr_t, in, trans_set_t *, ts, sets)
    {
      if (ts->ts_max_depth)
	ts->ts_max_depth--;
    }
  END_DO_IDHASH;
}


void
tn_get_fetchable (trans_node_t * tn, caddr_t * inst)
{
  id_hash_iterator_t hit;
  id_hash_t * sets = QST_BOX (id_hash_t *, inst, tn->tn_input_sets);
  id_hash_t * relation = (id_hash_t *)qst_get (inst, tn->tn_relation);
  ptrlong ignore;
  trans_set_t ** p_ts;
  id_hash_iterator (&hit, sets);
  while (hit_next (&hit, (caddr_t*)&ignore, (caddr_t*) &p_ts))
    {
      trans_set_t * ts = *p_ts;
      DO_SET (trans_state_t *, tst, &ts->ts_new)
	{
	  if (! id_hash_get (relation, (caddr_t)&tst->tst_value))
	    tn_fetchable (tn, inst, tst->tst_value);
	}
      END_DO_SET();
    }
}


int
tn_advance (trans_node_t * tn, caddr_t * inst)
{
  /* for all the new states in all the sets, find if the step must be fetched and fetch the steps */
  int any = 0;
  id_hash_t * sets = QST_BOX (id_hash_t*, inst, tn->tn_input_sets);
  tn_get_fetchable (tn, inst);
  tn_fetch (tn, inst);
  DO_IDHASH (caddr_t *, in, trans_set_t *, ts, sets)
    {
      ts_advance (tn, inst, ts);
      if (ts->ts_new)
	any = 1;
    }
  END_DO_IDHASH;
  return any;
}


void
tn_init_pair (trans_node_t * tn, caddr_t * inst)
{
  if (tn->tn_complement)
    {
      tn_get_fetchable (tn, inst);
      tn_get_fetchable (tn->tn_complement, inst);
    }
}


int
tn_advance_pair (trans_node_t * tn, caddr_t * inst)
{
  int new1, new2, rc;
  trans_node_t * tn2 = tn->tn_complement, *adv = NULL;
  int n1 = tn_count (tn, inst, &new1);
  int n2 = tn_count (tn2, inst, &new2);
  if (!new1 && !new2)
    return 0;
  if (!new1)
    adv = tn2;
  else if (!new2)
    adv = tn;
  else
    adv = new1 > new2 ? tn2 : tn;
  rc = tn_advance (adv, inst);
  tn_dec_depth (adv == tn ? tn2 : tn, inst);
  if (!rc)
    {
      rc = tn_advance (adv == tn ? tn2 : tn, inst);
      tn_dec_depth (adv, inst);
      return rc;
    }
  return rc;
}


trans_state_t *
tst_succ (trans_state_t * path, trans_state_t * point)
{
  /* return the tst on path whose prev the point is */
  while (path)
    {
      if (path->tst_prev == point)
	return path;
      path = path->tst_prev;
    }
  return NULL;
}


void
tn_result_row (trans_node_t * tn, caddr_t * inst, trans_state_t * tst, trans_state_t * path_end_tst, int res_depth, int path_no, int last_of_set)
{
  int inx;
  itc_cluster_t * itcl = ((cl_op_t*)qst_get (inst, tn->clb.clb_itcl))->_.itcl.itcl;
  cl_ts_set_context ((table_source_t *)tn, itcl, inst, QST_INT (inst, tn->clb.clb_nth_set) - (last_of_set ? 1 : 0));
  if (tn->tn_inlined_step)
    {
      trans_state_t * zero = tst;
      DO_BOX (state_slot_t *, out, inx, tn->tn_output)
	{
	  qst_set_over (inst, out, ((caddr_t*)path_end_tst->tst_value)[inx]);
	}
      END_DO_BOX;

      while (zero->tst_prev)
	zero = zero->tst_prev;

      DO_BOX (caddr_t , pos, inx, tn->tn_input_pos)
	{
	  state_slot_t * ssl = tn->tn_inlined_step->qr_select_node->sel_out_slots[unbox (pos)];
	  qst_set_over (inst, ssl, ((caddr_t*)zero->tst_value)[inx]);
	}
      END_DO_BOX;
      if (tn->tn_step_out)
	{
	  DO_BOX (state_slot_t *, out, inx, tn->tn_step_out)
	    {
	      if (NULL == out)
	        continue;
	      qst_set_over (inst, out, ((caddr_t*)tst->tst_value)[inx]);
	    }
	  END_DO_BOX;
	}
      if (tn->tn_data)
	{
	  /* if rl direction and not two way, then show the data as if was a lr direction, so shifted by one */
	  trans_state_t * data_tst;
	  if (!tn->tn_complement && TRANS_RL == tn->tn_direction)
	    data_tst = tst_succ (path_end_tst, tst);
	  else
	    data_tst = tst;
	  DO_BOX (state_slot_t *, out, inx, tn->tn_data)
	    {
	      if (data_tst && data_tst->tst_data)
		qst_set_over (inst, out, ((caddr_t*)data_tst->tst_data)[inx]);
	      else
		qst_set_bin_string (inst, out, (db_buf_t)"", 0, DV_DB_NULL);
	    }
	  END_DO_BOX;
	}
    }
  else
    {
      DO_BOX (state_slot_t *, out, inx, tn->tn_output)
	{
	  qst_set_over (inst, out, ((caddr_t*)tst->tst_value)[inx]);
	}
      END_DO_BOX;
    }
  if (tn->tn_path_no_ret)
    qst_set_long (inst, tn->tn_path_no_ret, path_no);
  if (tn->tn_step_no_ret)
    qst_set_long (inst, tn->tn_step_no_ret, res_depth);
  qn_send_output ((data_source_t*)tn, inst);
}


trans_state_t *
tst_nth_pred (trans_state_t * tst, int nth)
{
  int inx;
  for (inx = 0; inx < nth; inx++)
    tst = tst->tst_prev;
  return tst;
}


void
ts_send_path (trans_node_t * tn, caddr_t * inst, trans_set_t * ts)
{
  trans_state_t * tst = (trans_state_t*)ts->ts_current_result->data;
  int depth, last_of_set = 0;
  for (depth = ts->ts_current_result_step; depth <=tst->tst_depth; depth++)
    {
      trans_state_t * res_tst;
      int res_depth;
      ts->ts_current_result_step = depth + 1;
      if (tn->tn_min_depth && depth < unbox (qst_get (inst, tn->tn_min_depth)))
	continue;
      if (TRANS_RL == tn->tn_direction)
	{
	  res_tst = tst_nth_pred (tst, depth);
	  res_depth = depth;
	}
      else
	{
	  res_tst = tst_nth_pred (tst, tst->tst_depth - depth);
	  res_depth = res_tst->tst_depth;
	}
      last_of_set = 0;
      if (depth == tst->tst_depth)
	{
	  ts->ts_current_result = ts->ts_current_result->next;
	  ts->ts_current_result_step = 0;
	  if (!ts->ts_current_result)
	    {
	      last_of_set = 1;
	      QST_INT (inst, tn->clb.clb_nth_set)++;
	    }
	  if (QST_INT (inst, tn->clb.clb_nth_set) == QST_INT (inst, tn->clb.clb_fill))
	    SRC_IN_STATE ((data_source_t*)tn, inst) = NULL;
	}
      tn_result_row (tn, inst, res_tst, tst, res_depth, tst->tst_path_no, last_of_set);
    }
}


void
tn_lowest_sas_result (trans_node_t * tn, caddr_t * inst, trans_set_t * ts)
{
  itc_cluster_t * itcl = ((cl_op_t*)qst_get (inst, tn->clb.clb_itcl))->_.itcl.itcl;
  iri_id_t res = 0;
  DO_SET (trans_state_t *,  tst, &ts->ts_result)
    {
      caddr_t r = ((caddr_t*)tst->tst_value)[0];
      if (DV_IRI_ID != DV_TYPE_OF (r))
	continue;
      if (!res || res > unbox_iri_id (r))
	res = unbox_iri_id (r);
    }
  END_DO_SET();
  if (!res)
    {
      if (tn->tn_input[0] == tn->tn_output[0])
	qn_send_output ((data_source_t*)tn, inst);
      return;
    }
  cl_ts_set_context ((table_source_t *)tn, itcl, inst, QST_INT (inst, tn->clb.clb_nth_set) - 1);
  qst_set (inst, tn->tn_output[0], box_iri_id (res));
  qn_send_output ((data_source_t*)tn, inst);
}

int32 tn_cache_enable = 0;

void
tn_cache_results (trans_node_t * tn, caddr_t * inst)
{
  int nth;
  itc_cluster_t * itcl = ((cl_op_t*)qst_get (inst, tn->clb.clb_itcl))->_.itcl.itcl;
  id_hash_t * ht = tn_hash_table_get (tn);
  caddr_t key = qst_get (inst, tn->tn_input[0]), data;
  dk_set_t set = NULL;
  if (!ht || !tn_cache_enable || cl_run_local_only != CL_RUN_LOCAL)
    return;
  for (nth = 0; nth < QST_INT (inst, tn->clb.clb_fill); nth ++)
    {
      int inx;
      caddr_t * arr = NULL;
      trans_set_t * ts = (trans_set_t*) itcl->itcl_param_rows[nth][0];
      if (ts->ts_result)
	{
	  DO_SET (trans_state_t *,  tst, &ts->ts_result)
	    {
	      arr = dk_alloc_box (BOX_ELEMENTS (tn->tn_output) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	      DO_BOX (state_slot_t *, out, inx, tn->tn_output)
		{
		  caddr_t v = ((caddr_t*)tst->tst_value)[inx];
		  arr[inx] = box_copy_tree (v);
		}
	      END_DO_BOX;
	      dk_set_push (&set, (void *) arr);
	    }
	  END_DO_SET ();
	}
      else
	{
	  dk_set_push (&set, (void *) arr);
	}
    }
  key = box_copy_tree (key);
  data = list_to_array (dk_set_nreverse (set));
  mutex_enter (tn_cache_mtx);
  id_hash_set (ht, (caddr_t) &key, (caddr_t) &data);
  mutex_leave (tn_cache_mtx);
}

long tn_n_cache_hits;

int
tn_cache_lookup (trans_node_t * tn, caddr_t * inst, caddr_t * state)
{
  int nth;
  id_hash_t * ht = tn_hash_table_get (tn);
  caddr_t key = qst_get (inst, tn->tn_input[0]);
  caddr_t ** place;
  if (!tn_cache_enable || !ht || cl_run_local_only != CL_RUN_LOCAL)
    return 0;
  mutex_enter (tn_cache_mtx);
  place = (caddr_t **) id_hash_get (ht, (caddr_t) &key);
  mutex_leave (tn_cache_mtx);
  if (!place || !place[0])
    return 0;
  if (state && !SRC_IN_STATE ((data_source_t *)tn, inst))
    {
      /* init */
      SRC_IN_STATE ((data_source_t*)tn, inst) = inst;
      QST_INT (inst, tn->tn_nth_cache_result) = 0;
    }
  for (nth = QST_INT (inst, tn->tn_nth_cache_result); nth < BOX_ELEMENTS (place[0]); nth ++)
    {
      int inx;
      caddr_t * row = (caddr_t *) (place[0][nth]);
      if (!row)
	{
	  QST_INT (inst, tn->tn_nth_cache_result)++;
	  continue;
	}
      DO_BOX (state_slot_t *, out, inx, tn->tn_output)
	{
	  qst_set_over (inst, out, row[inx]);
	}
      END_DO_BOX;
      QST_INT (inst, tn->tn_nth_cache_result)++;
      TC (tn_n_cache_hits);
      if (QST_INT (inst, tn->tn_nth_cache_result) == BOX_ELEMENTS (place[0]))
	SRC_IN_STATE ((data_source_t*)tn, inst) = NULL; /* not continuable */
      qn_send_output ((data_source_t*) tn, inst);
    }
  return 1;
}

void
tn_results (trans_node_t * tn, caddr_t * inst)
{
  /* next result in order.  Advance all to the end, then start sending */
  int nth;
  trans_set_t * ts;
  itc_cluster_t * itcl = ((cl_op_t*)qst_get (inst, tn->clb.clb_itcl))->_.itcl.itcl;
  if (-1 == QST_INT (inst, tn->clb.clb_nth_set))
    {
      SET_THR_TMP_POOL (itcl->itcl_pool);
      if (tn->tn_complement)
	tn_init_pair (tn, inst);
      while (tn->tn_complement ? tn_advance_pair (tn, inst) : tn_advance (tn, inst));
      SET_THR_TMP_POOL (NULL);
      QST_INT (inst, tn->clb.clb_nth_set) = 0;
    }
  tn_cache_results (tn, inst);
  /* find the ts corresponding to the set now going and send its content */
  for (;;)
    {
      nth = QST_INT (inst, tn->clb.clb_nth_set);
      if (nth >= QST_INT (inst, tn->clb.clb_fill))
	{
	  SRC_IN_STATE ((data_source_t*)tn, inst) = NULL;
	  return;
	}
      ts = (trans_set_t*) itcl->itcl_param_rows[nth][0];
      if (!ts->ts_result)
	{
	  QST_INT (inst, tn->clb.clb_nth_set)++;
	  continue;
	}
      if (tn->tn_lowest_sas)
	{
	  QST_INT (inst, tn->clb.clb_nth_set)++;
	  tn_lowest_sas_result (tn, inst, ts);
	  continue;
	}
      if (!ts->ts_current_result)
	ts->ts_current_result = ts->ts_result;
      if (tn->tn_keep_path)
	ts_send_path (tn, inst, ts);
      else
	{
	  int last_of_set = 0;
	  trans_state_t * tst = (trans_state_t*)ts->ts_current_result->data;
	  ts->ts_current_result = ts->ts_current_result->next;
	  if (!ts->ts_current_result)
	    {
	      last_of_set = 1;
	      QST_INT (inst, tn->clb.clb_nth_set)++;
	      if (QST_INT (inst, tn->clb.clb_nth_set) == QST_INT (inst, tn->clb.clb_fill))
		{
		  SRC_IN_STATE ((data_source_t*)tn, inst) = NULL;
		}
	    }
	  tn_result_row (tn, inst, tst, tst, tst->tst_depth, tst->tst_path_no, last_of_set);
	}
    }
}

void
tn_reset (trans_node_t * tn, caddr_t * inst)
{
  query_instance_t * qi = (query_instance_t *)inst;
  cl_op_t * itcl_clo;
  itc_cluster_t * itcl;
  id_hash_t * sets, *rel;

  QST_INT (inst, tn->clb.clb_fill) = 0;
  itcl_clo = clo_allocate (CLO_ITCL);
  itcl_clo->_.itcl.itcl = itcl = itcl_allocate (qi->qi_trx, inst);
  qst_set (inst, tn->clb.clb_itcl, (caddr_t)itcl_clo);
  SET_THR_TMP_POOL (itcl->itcl_pool);
  sets = t_id_hash_allocate (tn->clb.clb_batch_size, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
  QST_BOX (id_hash_t *, inst, tn->tn_input_sets) = sets;
  rel = (id_hash_t*)box_dv_dict_hashtable (61);
  rel->ht_free_hook = ht_free_no_content;
  id_hash_set_rehash_pct  (rel, 300);
  qst_set (inst, tn->tn_relation, (caddr_t)rel);
  QST_INT (inst, tn->clb.clb_nth_set) = -1;
  QST_INT (inst, tn->tn_nth_cache_result) = 0;
}

void
trans_node_start (trans_node_t * tn, caddr_t * inst, caddr_t * state)
{
  int inx;
  id_hash_t * sets, *rel;
  trans_set_t * ts, **place;
  int nth;
  query_instance_t * qi = (query_instance_t *)inst;
  cl_op_t * itcl_clo = (cl_op_t *)qst_get (inst, tn->clb.clb_itcl);
  itc_cluster_t * itcl;
  if (TN_RESULTS == QST_INT (inst, tn->tn_state))
    GPF_T1 ("a tn node should not get new states while it is producing results");
  QST_INT (inst, tn->tn_state) = TN_INIT;
  if (!SRC_IN_STATE ((data_source_t *)tn, inst))
    {
      /* first input, init. */
      QST_INT (inst, tn->clb.clb_fill) = 0;
      itcl_clo = clo_allocate (CLO_ITCL);
      itcl_clo->_.itcl.itcl = itcl = itcl_allocate (qi->qi_trx, inst);
      qst_set (inst, tn->clb.clb_itcl, (caddr_t)itcl_clo);
      SET_THR_TMP_POOL (itcl->itcl_pool);
      sets = t_id_hash_allocate (tn->clb.clb_batch_size, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
      QST_BOX (id_hash_t *, inst, tn->tn_input_sets) = sets;
      rel = (id_hash_t*)box_dv_dict_hashtable (61);
      rel->ht_free_hook = ht_free_no_content;
      id_hash_set_rehash_pct  (rel, 300);
      qst_set (inst, tn->tn_relation, (caddr_t)rel);
      SRC_IN_STATE ((data_source_t*)tn, inst) = inst;
      QST_INT (inst, tn->clb.clb_nth_set) = -1;
      QST_INT (inst, tn->tn_nth_cache_result) = 0;
      nth = 0;
      if (tn->tn_complement && tn->tn_is_primary)
	{
	  tn_reset (tn->tn_complement, inst);
	  SET_THR_TMP_POOL (itcl->itcl_pool);
	}
    }
  else
    {
      itcl_clo = (cl_op_t*)QST_GET_V (inst, tn->clb.clb_itcl);
      itcl = itcl_clo->_.itcl.itcl;
      SET_THR_TMP_POOL (itcl->itcl_pool);
      nth = QST_INT (inst, tn->clb.clb_fill);
      sets = QST_BOX (id_hash_t*, inst, tn->tn_input_sets);
      rel = (id_hash_t*)QST_GET_V (inst, tn->tn_relation);
    }
  QST_INT (inst, tn->clb.clb_fill) = nth + 1;
  {
    caddr_t * in = (caddr_t*)t_alloc_box (BOX_ELEMENTS (tn->tn_input) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
    DO_BOX (state_slot_t *, ssl, inx, tn->tn_input)
      {
	in[inx] = t_full_box_copy_tree (qst_get (inst, ssl));
      }
    END_DO_BOX;
    if (tn->tn_target)
      {
	caddr_t * target = (caddr_t*)t_alloc_box (BOX_ELEMENTS (tn->tn_input) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	DO_BOX (state_slot_t *, ssl, inx, tn->tn_target)
	  {
	    target[inx] = t_full_box_copy_tree (qst_get (inst, ssl));
	  }
	END_DO_BOX;
	in = t_list (2, in, target);
      }
    place = (trans_set_t**) id_hash_get (sets, (caddr_t)&in);
    if (!place)
      {
	trans_state_t * tst;
	ts = (trans_set_t *) t_alloc (sizeof (trans_set_t));
	memset (ts, 0, sizeof (trans_set_t));
	if (tn->tn_distinct || tn->tn_complement)
	  {
	    ts->ts_traversed = t_id_hash_allocate (61, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
	    id_hash_set_rehash_pct (ts->ts_traversed, 200);
	  }
	if (tn->tn_max_depth)
	  ts->ts_max_depth = unbox (qst_get (inst, tn->tn_max_depth));
	ts->ts_value = tn->tn_target ? in[0] : (caddr_t)in;
	if (tn->tn_target)
	  {
	    ts->ts_target = in[1];
	    if (tn->tn_complement && !tn->tn_is_primary)
	      {
		/* doing ends against the middle.  Mark the two ts's for this set to be each other's targets */
		trans_node_t * ctn = tn->tn_complement;
		itc_cluster_t * citcl = ((cl_op_t*)qst_get (inst, ctn->clb.clb_itcl))->_.itcl.itcl;
		trans_set_t * cts = (trans_set_t*)citcl->itcl_param_rows[nth][0];
		ts->ts_target_ts = cts;

		cts->ts_target_ts = ts;
	      }
	  }
	t_id_hash_set (sets, (caddr_t)&in, (caddr_t)&ts);
	tst = (trans_state_t*)t_alloc (sizeof (trans_state_t));
	memset (tst, 0, sizeof (trans_state_t));
	tst->tst_value = tn->tn_target ? in[0] : (caddr_t)in;
	tst->tst_data = NULL;
	tst->tst_depth = 0;
	tst->tst_prev = NULL;
	t_set_push (&ts->ts_new, (void*)tst);
	if (tn->tn_min_depth && 0 == unbox (qst_get (inst, tn->tn_min_depth)))
	  {
	    if (ts->ts_target || ts->ts_target_ts)
	      ts_check_target (tn, inst, ts, tst);
	    else
	      ts_new_result (tn, inst, ts,tst);
	  }
	if (tn->tn_distinct)
	  t_id_hash_set (ts->ts_traversed, (caddr_t)&tst->tst_value, (caddr_t)&tst);
	else if (tn->tn_complement)
	  {
	    dk_set_t f = t_CONS (tst, NULL);
	    t_id_hash_set (ts->ts_traversed, (caddr_t)&tst->tst_value, (caddr_t)&f);
	  }
      }
    else
      ts = *place;
    t_set_push (&ts->ts_input_set_nos, (void*)(ptrlong)nth);
    cl_select_save_env ((table_source_t *)tn, itcl, inst, (cl_op_t*)ts, nth);
  }
  SET_THR_TMP_POOL (NULL);
  if (tn->tn_complement && tn->tn_is_primary)
    trans_node_start (tn->tn_complement, inst, state);
  if (tn->tn_is_primary && (QST_INT (inst, tn->clb.clb_fill) == tn->clb.clb_batch_size || tn->tn_end_flag))
    tn_results (tn, inst);
}


void
trans_node_input (trans_node_t * tn, caddr_t * inst, caddr_t * state)
{
  if (THR_TMP_POOL)
    GPF_T1 ("not supposed to run trans node with tmp pool set on entry");
  if (tn_cache_lookup (tn, inst, state))
    return;
  if (state)
    trans_node_start (tn, inst, state);
  else
    tn_results (tn, inst);
}


void
tn_free (trans_node_t * tn)
{
  dk_free_tree ((caddr_t)tn->tn_input_pos);
  dk_free_box ((caddr_t)tn->tn_input);
  dk_free_box ((caddr_t)tn->tn_output);
  dk_free_box ((caddr_t)tn->tn_out_slots);
  dk_free_tree ((caddr_t)tn->tn_output_pos);
  dk_free_box ((caddr_t)tn->tn_data);
  dk_free_box ((caddr_t)tn->tn_target);
  dk_free_box ((caddr_t)tn->tn_sas_g);
  dk_free_box ((caddr_t)tn->tn_step_out);
  cv_free (tn->tn_after_join_test);
  dk_free_box (tn->tn_ifp_ctx_name);
}


trans_node_t *
sqlg_trans_node (sql_comp_t * sc)
{
  SQL_NODE_INIT (trans_node_t, tn, trans_node_input, tn_free);
  clb_init (sc->sc_cc, &tn->clb, 1);
  tn->tn_max_memory = TN_DEFAULT_MAX_MEMORY;
  tn->clb.clb_itcl = ssl_new_variable (sc->sc_cc, "itcl", DV_ANY);
  tn->tn_state = cc_new_instance_slot (sc->sc_cc);
  tn->tn_nth_cache_result = cc_new_instance_slot (sc->sc_cc);
  tn->tn_relation = ssl_new_variable (sc->sc_cc, "rel", DV_ANY);
  tn->tn_input_sets = cc_new_instance_slot (sc->sc_cc);
  tn->tn_to_fetch = ssl_new_variable (sc->sc_cc, "to_fetch", DV_ANY);
  tn->tn_lc = ssl_new_variable (sc->sc_cc, "lc", DV_ANY);
  return tn;
}

extern query_t * sas_tn_qr;
extern query_t * sas_tn_no_graph_qr;
extern query_t * tn_ifp_qr;
extern query_t * tn_ifp_no_graph_qr;
extern query_t * tn_ifp_dist_qr;
extern query_t * tn_ifp_dist_no_graph_qr;


state_slot_t *
sqlg_tn_in_out_ssl (state_slot_t ** save, df_elt_t * dfe, state_slot_t * out)
{
  state_slot_t * tmp;
  if (!*save)
    {
      *save = out;
      return dfe->dfe_ssl;
    }
  tmp = *save;
  *save = out;
  return tmp;
}


state_slot_t *
sqlg_sas_input_ssl (sql_comp_t * sc, df_elt_t * s_dfe, df_elt_t * p_dfe, df_elt_t * o_dfe, state_slot_t * out, int mode)
{
  if (RI_SAME_AS_O == mode)
    return sqlg_tn_in_out_ssl (&sc->sc_rdf_inf_slots->ris_o, o_dfe, out);
  else if (RI_SAME_AS_S == mode)
    return sqlg_tn_in_out_ssl (&sc->sc_rdf_inf_slots->ris_s, s_dfe, out);
  else if (RI_SAME_AS_P == mode)
    return sqlg_tn_in_out_ssl (&sc->sc_rdf_inf_slots->ris_p, p_dfe, out);
  else
    GPF_T1 ("unknown sas inf mode");
  return NULL;
}


void
sqlg_leading_multistate_same_as (sqlo_t * so, data_source_t ** q_head, data_source_t * ts,
    df_elt_t * g_dfe, df_elt_t * s_dfe, df_elt_t * p_dfe,  df_elt_t * o_dfe, int org_mode,
    rdf_inf_ctx_t * ctx, df_elt_t * tb_dfe, int inxop_inx, rdf_inf_pre_node_t ** ri_ret)
{
  sql_comp_t * sc = tb_dfe->dfe_sqlo->so_sc;
  int mode = org_mode & 0xf;
  int is_ifp = org_mode & RI_SAME_AS_IFP;
  df_elt_t ** in_list;
  trans_node_t * tn;
  if (!is_ifp && !sqlg_rdf_inf_same_as_opt (tb_dfe))
    return;
  if (is_ifp && (!ctx || !ctx->ric_ifp_list))
    return;
  tn = sqlg_trans_node (so->so_sc);
  *ri_ret = (rdf_inf_pre_node_t*)tn;
  qn_ins_before (tb_dfe->dfe_sqlo->so_sc, q_head, (data_source_t *)ts, (data_source_t *)tn);
  tn->tn_output = (state_slot_t**)list (1, ssl_new_variable (tb_dfe->dfe_sqlo->so_sc->sc_cc, ssl_inf_name (/*RI_SAME_AS_P == mode ? p_dfe : */ RI_SAME_AS_O == mode ? o_dfe : s_dfe), DV_IRI_ID));
  if (!g_dfe)
    ;
  else if ((in_list = sqlo_in_list (g_dfe, NULL, NULL)))
    {
      int n = BOX_ELEMENTS (in_list) - 1, ginx;
      state_slot_t ** gs = (state_slot_t **) dk_alloc_box (sizeof (caddr_t) * n, DV_BIN);
      for (ginx = 1; ginx <= n; ginx++)
	{
	  gs[ginx - 1] = in_list[ginx]->dfe_ssl;
	}
      tn->tn_sas_g = gs;
    }
  else
    tn->tn_sas_g = (state_slot_t **) list (1, g_dfe->_.bin.right->dfe_ssl);

  tn->tn_input = (state_slot_t**) list (1, sqlg_sas_input_ssl (sc, s_dfe, p_dfe, o_dfe, tn->tn_output[0], mode));
  sqlg_rdf_ts_replace_ssl ((table_source_t*) ts, tn->tn_input[0], tn->tn_output[0], 0, inxop_inx);
  tn->tn_is_pre_iter = 1;
  tn->tn_distinct = 1;
  tn->tn_commutative = 1;
  tn->tn_is_primary = 1;
  tn->tn_min_depth = ssl_new_constant (so->so_sc->sc_cc, 0);
  if (is_ifp)
    {
      tn->tn_ifp_ctx_name = box_copy (ctx->ric_name);
      tn->tn_max_depth = ssl_new_constant (so->so_sc->sc_cc, box_num (1));
      if (g_dfe)
	{
	  tn->tn_prepared_step = tn_ifp_qr;
	  tn->tn_ifp_g_list = ssl_new_variable (so->so_sc->sc_cc, "ifp_g_list", DV_ANY);
	}
      else
	tn->tn_prepared_step = tn_ifp_no_graph_qr;
    }
  else
    {
      if (g_dfe)
	tn->tn_prepared_step = sas_tn_qr;
      else
	tn->tn_prepared_step = sas_tn_no_graph_qr;
    }
  if (!tn->tn_prepared_step)
    sqlc_new_error (so->so_sc->sc_cc, "42000", "RDFSA", "internal: same as query not prepared");
  if ((qn_input_fn)select_node_input == tn->tn_prepared_step->qr_select_node->src_gen.src_input)
    tn->tn_prepared_step->qr_select_node->src_gen.src_input = (qn_input_fn)select_node_input_subq;
}


int enable_distinct_sas = 1;

data_source_t *
sqlg_distinct_same_as_1 (sqlo_t * so, data_source_t ** q_head,
		       ST ** col_sts, df_elt_t * dt_dfe,
		       dk_set_t * pre_code, int is_ifp)
{
  op_table_t * tb_ot;
  dk_set_t col_preds;
  df_elt_t * g_dfe = NULL;
  int inx;
  data_source_t * any = NULL;
  df_elt_t ** in_list;
  trans_node_t * tn;
  if (!enable_distinct_sas)
    return NULL;
  DO_BOX (ST *, col, inx, col_sts)
    {
      df_elt_t * col_dfe;
      caddr_t ctx_name = NULL;
      if (ST_P (col, ORDER_BY))
	col = col->_.o_spec.col;
      col_dfe = sqlo_df (so, col);
      if (DFE_COLUMN != col_dfe->dfe_type)
	continue;
      tb_ot = (op_table_t *)col_dfe->dfe_tables->data;
      if (!is_ifp && !sqlo_opt_value (tb_ot->ot_opts, OPT_SAME_AS)
	  && !sqlg_rdf_inf_same_as_opt (dt_dfe))
	continue;
      if (is_ifp)
	{
	  rdf_inf_ctx_t * ctx = rdf_inf_ctx (sqlo_opt_value (tb_ot->ot_opts, OPT_RDF_INFERENCE));
	  if (!ctx || !ctx->ric_ifp_list)
	    continue;
	  ctx_name = ctx->ric_name;
	}
      col_preds = dt_dfe->_.sub.ot->ot_preds;
      DO_SET (df_elt_t *, cp, &col_preds)
	{
	  df_elt_t * col_dfe;
	  df_elt_t ** g_in_list = sqlo_in_list (cp, NULL, NULL);
	  dbe_column_t * col;
	  if (!g_in_list && DFE_BOP_PRED != cp->dfe_type && DFE_BOP != cp->dfe_type)
	    continue;

	  col_dfe = g_in_list ? g_in_list[0] : cp->_.bin.left;
	  if (DFE_COLUMN != col_dfe->dfe_type || !col_dfe->_.col.col)
	    continue;
	  col = col_dfe->_.col.col;
	  if (BOP_EQ != cp->_.bin.op)
	    continue;
	  if (g_in_list && col->col_name[0] != 'G')
	    continue;
	  switch (col->col_name[0])
	    {
	    case 'G': g_dfe = cp; break;
	    }
	}
      END_DO_SET();

      tn = sqlg_trans_node (so->so_sc);
      sqlg_pre_code_dpipe (so, pre_code, (data_source_t *) tn);
      tn->tn_input = (state_slot_t **) list (1, scalar_exp_generate (so->so_sc, col_dfe->dfe_tree, pre_code));
      tn->tn_output = (state_slot_t**)list (1, tn->tn_input[0]);
      if (!g_dfe)
	;
      else if ((in_list = sqlo_in_list (g_dfe, NULL, NULL)))
	{
	  int n = BOX_ELEMENTS (in_list) - 1, ginx;
	  state_slot_t ** gs = (state_slot_t **) dk_alloc_box (sizeof (caddr_t) * n, DV_BIN);
	  for (ginx = 1; ginx <= n; ginx++)
	    {
	      gs[ginx - 1] = in_list[ginx]->dfe_ssl;
	    }
	  tn->tn_sas_g = gs;
	}
      else
	tn->tn_sas_g = (state_slot_t **) list (1, g_dfe->_.bin.right->dfe_ssl ? g_dfe->_.bin.right->dfe_ssl : g_dfe->_.bin.left->dfe_ssl);
      tn->tn_lowest_sas = 1;
      tn->tn_distinct = 1;
      tn->tn_commutative = 1;
      tn->tn_is_primary = 1;
      tn->tn_min_depth = ssl_new_constant (so->so_sc->sc_cc, 0);
      if (is_ifp)
	{
	  tn->tn_ifp_ctx_name = box_copy_tree (ctx_name);
	  tn->tn_max_depth = ssl_new_constant (so->so_sc->sc_cc, box_num (1));
	  tn->tn_ifp_g_list = g_dfe ? ssl_new_variable (so->so_sc->sc_cc, "g_list", DV_ANY) : NULL;
	  tn->tn_prepared_step = g_dfe ? tn_ifp_dist_qr : tn_ifp_dist_no_graph_qr;
	}
      else
	tn->tn_prepared_step = g_dfe ? sas_tn_qr : sas_tn_no_graph_qr;
      if (!tn->tn_prepared_step)
	sqlc_new_error (so->so_sc->sc_cc, "42000", "RDFSA", "internal: same as query not prepared");
      if ((qn_input_fn)select_node_input == tn->tn_prepared_step->qr_select_node->src_gen.src_input)
	tn->tn_prepared_step->qr_select_node->src_gen.src_input = (qn_input_fn)select_node_input_subq;
      tn->src_gen.src_pre_code = code_to_cv (so->so_sc, *pre_code);
      *pre_code = NULL;
      sql_node_append (q_head, (data_source_t*)tn);
      any = (data_source_t *)tn;
    }
  END_DO_BOX;
  return any;
}


data_source_t *
sqlg_distinct_same_as (sqlo_t * so, data_source_t ** q_head,
		       ST ** col_sts, df_elt_t * dt_dfe,
		       dk_set_t pre_code)
{
  data_source_t * a1, *a2;
  a1 = sqlg_distinct_same_as_1 (so, q_head, col_sts, dt_dfe, &pre_code, 1);
  a2 = sqlg_distinct_same_as_1 (so, q_head, col_sts, dt_dfe, &pre_code, 0);
  return a2 ? a2 : a1;
}



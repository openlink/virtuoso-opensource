/*
 *  cldt.c
 *
 *  $Id$
 *
 *  Cluster parallel multiple set derived tables, subquery, existence,
 *  aggregates
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
#include "arith.h"

#include "eqlcomp.h"
#include "sqlfn.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlo.h"
#include "rdfinf.h"


void
cl_set_aggregate_set (caddr_t * inst, state_slot_t * set_ctr, state_slot_t * current_set, state_slot_t * arr, state_slot_t ** save,
    int n_save)
{
}


int
cn_any_started (code_node_t * cn, caddr_t * inst)
{
  /* check whether any multistate code vec has started run.  If so, all the cn's state must be exhausted before more in states are received */
  DO_SET (instruction_t *, ins, &cn->cn_continuable)
  {
    query_t *qr = NULL;
    switch (ins->ins_type)
      {
      case IN_PRED:
	qr = ((subq_pred_t *) (ins->_.pred.cmp))->subp_query;
	break;
      case INS_SUBQ:
	qr = ins->_.subq.query;
	break;
      }
    if (qr->qr_cl_run_started && inst[qr->qr_cl_run_started])
      return 1;
  }
  END_DO_SET ();
  return 0;
}


void
cl_restore_cn_set_no (query_t * qr, caddr_t * inst, data_source_t * clb_qn, int set_no_inx, int set_no)
{
  itc_cluster_t *itcl;
  caddr_t **rows;
  cl_op_t *itcl_clo;
  int at_or_above = 0, below;
  cl_buffer_t *clb;
  QNCAST (table_source_t, ts, clb_qn);
  clb = &ts->clb;
  itcl_clo = (cl_op_t *) QST_GET (inst, clb->clb_itcl);
  itcl = itcl_clo->_.itcl.itcl;
  rows = (caddr_t **) itcl->itcl_param_rows;
  below = QST_INT (inst, clb->clb_fill);
  for (;;)
    {
      int guess, elt;
      guess = at_or_above + ((below - at_or_above) / 2);
      elt = unbox (rows[guess][set_no_inx + 1]);
      if (elt == set_no)
	{
	  cl_ts_set_context ((table_source_t *) clb_qn, itcl, inst, guess);
	  return;
	}
      if (at_or_above + 1 >= below)
	GPF_T1 ("missed finding set in multistate code");
      if (elt > set_no)
	below = guess;
      else
	at_or_above = guess;
    }
}



int
ins_cl_exists (subq_pred_t * subp, caddr_t * inst)
{
  QNCAST (query_instance_t, qi, inst);
  code_node_t *cn = subp->subp_cl_cn;
  caddr_t in = QST_GET (inst, subp->subp_cl_run);
  int set_no = unbox (QST_GET (inst, subp->subp_cl_cn->cn_set_no));
  if (!in)
    {
      in = dk_alloc_box_zero (cn->clb.clb_batch_size + 1, DV_STRING);
      qst_set (inst, subp->subp_cl_run, in);
      if (subp->subp_query->qr_no_cast_error)
	qi->qi_no_cast_error = 1;
    }
  in[set_no] = 1;
  QR_RESET_CTX_T (qi->qi_thread)
  {
    qn_input (subp->subp_query->qr_head_node, inst, inst);
    /* if returns, either one was queued or run started but produced nothing.  The continue stage will find out if there is something */
    POP_QR_RESET;
    return DVC_QUEUED;
  }
  QR_RESET_CODE
  {
    int set_no;
    caddr_t out = QST_GET (inst, subp->subp_cl_out);
    POP_QR_RESET;
    if (RST_ENOUGH != reset_code)
      {
	caddr_t err = subq_handle_reset (qi, reset_code);
	sqlr_resignal (err);
      }
    set_no = unbox (QST_GET_V (inst, cn->cn_set_no));
    if (!out)
      {
	out = dk_alloc_box_zero (cn->clb.clb_batch_size + 1, DV_STRING);
	qst_set (inst, subp->subp_cl_out, out);
      }
    out[set_no] = 1;
  }
  END_QR_RESET;
  return 1;
}


#define CN_INIT 0		/* input sets are being made */
#define CN_RUNNING 1		/* the subqs are being advanced */
#define CN_RESULT 2		/* All subqs of the sets are run, sending gathered output */
int cn_in, cn_out, cn_res, cn_true, cn_second;


void
cn_result (code_node_t * cn, caddr_t * inst, int flag)
{
  /* the code vec has returned, record the assigned values for this set no */
  caddr_t **out = ((caddr_t ***) inst)[cn->cn_results];
  itc_cluster_t *itcl = ((cl_op_t *) QST_GET_V (inst, cn->clb.clb_itcl))->_.itcl.itcl;
  caddr_t *row;
  int set_no = unbox (QST_GET (inst, cn->cn_set_no));
  int n_out = cn->cn_assigned ? BOX_ELEMENTS (cn->cn_assigned) + 1 : 1;
  cn_res++;
  if (flag)
    cn_true++;
  if (out[set_no])
    {
      cn_second++;
      return;			/* a second result for this set no, not supposed to but ignored here */
    }
  row = (caddr_t *) mp_alloc_box (itcl->itcl_pool, sizeof (caddr_t) * n_out, DV_ARRAY_OF_POINTER);
  row[0] = (caddr_t) (ptrlong) flag;
  if (cn->cn_assigned)
    {
      int inx;
      DO_BOX (state_slot_t *, asg, inx, cn->cn_assigned)
      {
	row[inx + 1] = mp_full_box_copy_tree (itcl->itcl_pool, qst_get (inst, asg));
      }
      END_DO_BOX;
    }
  out[set_no] = row;
}


void
cn_send_results (code_node_t * cn, caddr_t * inst)
{
  /* for an ordered cn, iterate through the sets after all the subqs are evaluated to finish */
  cl_op_t *itcl_clo = (cl_op_t *) QST_GET_V (inst, cn->clb.clb_itcl);
  itc_cluster_t *itcl = itcl_clo->_.itcl.itcl;
  caddr_t **results = ((caddr_t ***) inst)[cn->cn_results];
  int n_sets = QST_INT (inst, cn->clb.clb_fill);
  for (;;)
    {
      int state = QST_INT (inst, cn->cn_state), set_no;
      if (CN_RESULT != state)
	{
	  qst_set_long (inst, cn->cn_set_no, 0);
	  set_no = 0;
	  QST_INT (inst, cn->cn_state) = CN_RESULT;
	}
      else
	{
	  set_no = unbox (QST_GET_V (inst, cn->cn_set_no)) + 1;
	  qst_set_long (inst, cn->cn_set_no, set_no);
	}
      if (set_no >= n_sets - 1)
	{
	  SRC_IN_STATE ((data_source_t *) cn, inst) = NULL;
	}
      if (!cn->cn_is_test || results[set_no][0])
	{
	  cl_ts_set_context ((table_source_t *) cn, itcl, inst, set_no);
	  if (!cn->cn_is_test)
	    {
	      int inx, n = BOX_ELEMENTS (cn->cn_assigned);
	      for (inx = 0; inx < n; inx++)
		qst_set_over (inst, cn->cn_assigned[inx], results[set_no][inx + 1]);
	    }
	  if (!SRC_IN_STATE ((data_source_t *) cn, inst))
	    CLB_AT_END (cn->clb, inst);
	  cn_out++;
	  qn_send_output ((data_source_t *) cn, inst);
	}
      if (!SRC_IN_STATE ((data_source_t *) cn, inst))
	{
	  CLB_AT_END (cn->clb, inst);
	  break;
	}
    }
}


int
cn_advance_empty_sets (code_node_t * cn, caddr_t * inst)
{
  /* for all subqs, run the output for sets that are empty */
  cl_buffer_t *clb;
  int any_queued = 0, fill, inx, rc, offset;
  data_source_t *clb_qn;
  caddr_t out, in;
  query_t *qr;
  int set_no_in_clb;
  state_slot_t *out_ssl, *in_ssl;
  DO_SET (instruction_t *, ins, &cn->cn_continuable)
  {
    if (INS_SUBQ == ins->ins_type)
      {
	in_ssl = ins->_.subq.cl_run;
	out_ssl = ins->_.subq.cl_out;
	clb_qn = ins->_.subq.cl_clb;
	set_no_in_clb = ins->_.subq.cl_set_no_in_clb;
	qr = ins->_.subq.query;
      }
    else
      {
	subq_pred_t *subp = (subq_pred_t *) ins->_.pred.cmp;
	clb_qn = subp->subp_cl_clb;
	in_ssl = subp->subp_cl_run;
	out_ssl = subp->subp_cl_out;
	qr = subp->subp_query;
	set_no_in_clb = subp->subp_cl_set_no_in_clb;
      }
    clb = &cn->clb;
    in = QST_GET_V (inst, in_ssl);
    if (!in)
      continue;			/* this instr was never execd within the sets at hand */
    out = QST_GET_V (inst, out_ssl);
    fill = QST_INT (inst, clb->clb_fill);
    for (inx = 0; inx < fill; inx++)
      {
	if (in[inx] && (!out || !out[inx]))
	  {
	    if (!out)
	      {
		out = dk_alloc_box_zero (cn->clb.clb_batch_size + 1, DV_STRING);
		qst_set (inst, out_ssl, out);
	      }
	    out[inx] = 1;
	    qst_set_long (inst, cn->cn_set_no, inx);
	    cl_restore_cn_set_no (qr, inst, clb_qn, set_no_in_clb, inx);
	    if (INS_SUBQ == ins->ins_type)
	      {
		qst_set_bin_string (inst, qr->qr_select_node->sel_out_slots[0], (db_buf_t) "", 0, DV_DB_NULL);
		offset = BOFS_TO_OFS ((ptrlong) ins + INS_LEN (ins) - (ptrlong) cn->cn_code);
	      }
	    else
	      offset = ins->_.pred.fail;
	    rc = (ptrlong) code_vec_run_1 (cn->cn_code, inst, offset);
	    if (DVC_QUEUED == rc)
	      {
		any_queued = 1;
		continue;
	      }
	    cn_result (cn, inst, rc);
	  }
      }
    qst_set (inst, ((table_source_t *) clb_qn)->clb.clb_itcl, NULL);
    memset (in, 0, box_length (in));
    memset (out, 0, box_length (out));
  }
  END_DO_SET ();
  return any_queued;
}


int
qr_is_continuable (query_t * qr, caddr_t * inst)
{
  DO_SET (data_source_t *, qn, &qr->qr_nodes)
  {
    if (SRC_IN_STATE (qn, inst))
      return 1;
  }
  END_DO_SET ();
  return 0;
}


instruction_t *
cn_next_continue (code_node_t * cn, caddr_t * inst)
{
  DO_SET (instruction_t *, ins, &cn->cn_continuable)
  {
    query_t *qr = INS_QUERY (ins);
    if (qr->qr_cl_run_started && inst[qr->qr_cl_run_started])
      return ins;
  }
  END_DO_SET ();
  DO_SET (instruction_t *, ins, &cn->cn_continuable)
  {
    query_t *qr = INS_QUERY (ins);
    if (qr_is_continuable (qr, inst))
      return ins;
  }
  END_DO_SET ();
  return NULL;
}


void
cn_advance (code_node_t * cn, caddr_t * inst)
{
  /* advance any subqs that have state, run code */
  int any_queued, offset, rc;
  state_slot_t *out_ssl;
  query_t *qr;
  QNCAST (query_instance_t, qi, inst);
  if (CN_INIT == QST_INT (inst, cn->cn_state))
    QST_INT (inst, cn->cn_state) = CN_RUNNING;
  else if (CN_RESULT == QST_INT (inst, cn->cn_state))
    {
      cn_send_results (cn, inst);
      return;
    }
  for (;;)
    {
      instruction_t *ins;
      any_queued = 0;
      while ((ins = cn_next_continue (cn, inst)))
	{
	  if (!ins)
	    break;
	  if (INS_SUBQ == ins->ins_type)
	    {
	      out_ssl = ins->_.subq.cl_out;
	      qr = ins->_.subq.query;
	    }
	  else
	    {
	      out_ssl = ((subq_pred_t *) (ins->_.pred.cmp))->subp_cl_out;
	      qr = ((subq_pred_t *) (ins->_.pred.cmp))->subp_query;
	    }
	  for (;;)
	    {
	      QR_RESET_CTX_T (qi->qi_thread)
	      {
		qr_resume_pending_nodes (qr, inst);
		/* if this returned, all sets are done, else would have thrown per each row */
		POP_QR_RESET;
		goto next_ins;
	      }
	      QR_RESET_CODE
	      {
		int set_no;
		caddr_t out = QST_GET (inst, out_ssl);
		POP_QR_RESET;
		if (RST_ENOUGH != reset_code)
		  {
		    caddr_t err = subq_handle_reset (qi, reset_code);
		    sqlr_resignal (err);
		  }
		set_no = unbox (QST_GET_V (inst, cn->cn_set_no));
		if (!out)
		  {
		    out = dk_alloc_box_zero (cn->clb.clb_batch_size + 1, DV_STRING);
		    qst_set (inst, out_ssl, out);
		  }
		out[set_no] = 1;
		if (INS_SUBQ == ins->ins_type)
		  offset = BOFS_TO_OFS ((ptrlong) ins + INS_LEN (ins) - (ptrlong) cn->cn_code);
		else
		  offset = ins->_.pred.succ;
		rc = (ptrlong) code_vec_run_1 (cn->cn_code, inst, offset);
		if (DVC_QUEUED == rc)
		  {
		    any_queued = 1;
		    continue;
		  }
		cn_result (cn, inst, rc);
	      }
	      END_QR_RESET;
	    }
	next_ins:;
	}
      if (any_queued)
	continue;
      if (!cn_advance_empty_sets (cn, inst))
	break;
    }
  cn_send_results (cn, inst);
}


#define CN_ARR_CLR(inst, ssl) \
{ \
  caddr_t b = QST_GET_V (inst, ssl); \
  if (b) \
    memset (b, 0, box_length (b)); \
}


void
code_node_input (code_node_t * cn, caddr_t * inst, caddr_t * state)
{
  int cn_state;
  if (!cn->clb.clb_fill)
    {
      /* may have been decommissioned by colocating with another.  If so, no multistate logic */
      caddr_t res = code_vec_run (cn->cn_code, inst);
      if (!cn->cn_is_test || res)
	qn_send_output ((data_source_t *) cn, inst);
      return;
    }
  if (state)
    {
      caddr_t **out;
      caddr_t res;
      query_instance_t *qi = (query_instance_t *) inst;
      cl_op_t *itcl_clo = (cl_op_t *) qst_get (inst, cn->cn_itcl);
      itc_cluster_t *itcl;
      int nth;
      cn_in++;
      QST_INT (inst, cn->cn_state) = CN_INIT;
      if (!SRC_IN_STATE ((data_source_t *) cn, inst))
	{
	  /* first input, init. */
	  QST_INT (inst, cn->clb.clb_fill) = 0;
	  itcl_clo = clo_allocate (CLO_ITCL);
	  itcl_clo->_.itcl.itcl = itcl = itcl_allocate (qi->qi_trx, inst);
	  qst_set (inst, cn->cn_itcl, (caddr_t) itcl_clo);
	  out = (caddr_t **) (inst[cn->cn_results] =
	      mp_alloc_box (itcl->itcl_pool, sizeof (caddr_t) * cn->clb.clb_batch_size, DV_ARRAY_OF_POINTER));
	  DO_SET (instruction_t *, ins, &cn->cn_continuable)
	  {
	    /* subq instrs have arrays of flags for the presence of input and output.  These may be left from a previous batch. Reset */
	    if (INS_SUBQ == ins->ins_type)
	      {
		subq_init (ins->_.subq.query, inst);
		CN_ARR_CLR (inst, ins->_.subq.cl_run);
		CN_ARR_CLR (inst, ins->_.subq.cl_out);
	      }
	    else
	      {
		QNCAST (subq_pred_t, subp, ins->_.pred.cmp);
		subq_init (subp->subp_query, inst);
		CN_ARR_CLR (inst, subp->subp_cl_run);
		CN_ARR_CLR (inst, subp->subp_cl_out);
	      }
	  }
	  END_DO_SET ();
	}
      else
	{
	  itcl_clo = (cl_op_t *) QST_GET_V (inst, cn->clb.clb_itcl);
	  itcl = itcl_clo->_.itcl.itcl;
	  out = ((caddr_t ***) inst)[cn->cn_results];
	}
      nth = QST_INT (inst, cn->clb.clb_fill);
      QST_INT (inst, cn->clb.clb_fill) = nth + 1;
      qst_set_long (inst, cn->cn_set_no, nth);
      out[nth] = NULL;
      cl_select_save_env ((table_source_t *) cn, itcl, inst, NULL, nth);
      res = code_vec_run_1 (cn->cn_code, inst, 0);
      if (DVC_QUEUED != (ptrlong) res)
	cn_result (cn, inst, (ptrlong) res);
      SRC_IN_STATE ((data_source_t *) cn, inst) = inst;
      if (nth + 1 < cn->clb.clb_batch_size && !cn_any_started (cn, inst))
	return;
      cn_advance (cn, inst);
      return;
    }
  else
    {
      /* cn being continued.  Either make more results or send what you have */
      cn_state = QST_INT (inst, cn->cn_state);
      if (CN_INIT == cn_state)
	QST_INT (inst, cn->cn_state) = CN_RUNNING;
      cn_advance (cn, inst);
    }
}


void
cn_free (code_node_t * cn)
{
  clb_free (&cn->clb);
  if (cn->cn_assigned)
    dk_free_box ((caddr_t) cn->cn_assigned);
  dk_set_free (cn->cn_continuable);
  cv_free (cn->cn_code);
}



void
cl_set_switch (caddr_t * inst, state_slot_t * set_no, state_slot_t * current_set, state_slot_t * array, state_slot_t ** save,
    int n_save, int target_set, int cl_batch, state_slot_t ** defaults)
{
  int set = -1 == target_set ? unbox (QST_GET_V (inst, set_no)) : target_set;
  int inx, current = unbox (QST_GET_V (inst, current_set));
  caddr_t **arr = (caddr_t **) QST_GET_V (inst, array);
  int is_new = 0;
  if (!arr)
    {
      arr = (caddr_t **) dk_alloc_box_zero (cl_batch * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      qst_set (inst, array, (caddr_t) arr);
    }
  if (!arr[set])
    {
      arr[set] = dk_alloc_box_zero (sizeof (caddr_t) * n_save, DV_ARRAY_OF_POINTER);
      is_new = 1;
    }
  if (set != current)
    {
      /* put the now current set in its place in the array and put the new set in the ssls from the array */
      for (inx = 0; inx < n_save; inx++)
	{
	  if (arr[current])
	    arr[current][inx] = QST_GET_V (inst, save[inx]);
	  inst[save[inx]->ssl_index] = arr[set][inx];
	  arr[set][inx] = NULL;
	}
      qst_set_long (inst, current_set, set);
    }
  if (is_new && defaults)
    {
      for (inx = 0; inx < n_save; inx++)
	{
	  caddr_t def = qst_get (inst, defaults[inx]);
	  if (!unbox (def))
	    def = NULL;		/* a zero is a null pointer not a boxed zero, must be for distinct temps */
	  qst_set (inst, save[inx], box_copy_tree (def));
	}
    }
}


void
ssa_set_switch (setp_save_t * ssa, caddr_t * inst, int set)
{
  cl_set_switch (inst, ssa->ssa_set_no, ssa->ssa_current_set, ssa->ssa_array, ssa->ssa_save, BOX_ELEMENTS (ssa->ssa_save), set,
      ssa->ssa_batch_size, NULL);
}

void
cl_fref_resume (fun_ref_node_t * fref, caddr_t * inst)
{
  /* continue the fnr_select branch so it is all finished */
  query_t *qr = fref->src_gen.src_query;
again:
  DO_SET (data_source_t *, qn, &fref->fnr_select_nodes)
  {
    if (SRC_IN_STATE (qn, inst))
      {
	qn->src_input (qn, inst, NULL);
	goto again;
      }
  }
  END_DO_SET ();
  /* this does not mark the containing qr's run as over since there can be results in nodes that read the aggregation */
}


/* ssa_iter and cl_fref_read nodes.  Used with partitioned oby/gby temps */

void
ssa_iter_input (ssa_iter_node_t * ssi, caddr_t * inst, caddr_t * state)
{
  setp_save_t *ssa = &ssi->ssi_setp->setp_ssa;
  int set = unbox (QST_GET_V (inst, ssa->ssa_set_no));
  int first = 1;
  caddr_t *array = (caddr_t *) QST_GET_V (inst, ssa->ssa_array);
  if (!array)
    {
      SRC_IN_STATE (ssi, inst) = NULL;
      return;
    }
  if (set + 1 >= BOX_ELEMENTS (array))
    {
      SRC_IN_STATE (ssi, inst) = NULL;
      QST_INT (inst, ssi->ssi_state) = 0;
      return;
    }
  while (set + 1 < BOX_ELEMENTS (array))
    {
      set++;
      qst_set_long (inst, ssa->ssa_set_no, set);
      if ((!array[set]))
	{
	  if (first)
	    {
	      ssa_set_switch (ssa, inst, set);	/* do not overwrite the set that is in the inst now */
	      first = 0;
	    }
	}
      else
	ssa_set_switch (ssa, inst, set);
      if (set + 1 == BOX_ELEMENTS (array))
	{
	  SRC_IN_STATE (ssi, inst) = NULL;
	}
      if (array[set])
	qn_send_output ((data_source_t *) ssi, inst);
    }
}

int
cl_partitioned_fref_start (dk_set_t nodes, caddr_t * inst)
{
  /* for aqf with a partitioned setp or two, find the ssa_iter that is after the last setp with content where the setp has not already been read */
  ssa_iter_node_t *last_ssi = NULL;
  DO_SET (data_source_t *, qn, &nodes)
  {
    if (IS_SSI (qn))
      {
	QNCAST (ssa_iter_node_t, ssi, qn);
	int state = QST_INT (inst, ssi->ssi_state);
	if (!state)
	  last_ssi = ssi;
      }
  }
  END_DO_SET ();
  if (!last_ssi)
    return 0;			/* no uncontinued ssi */
  QST_INT (inst, last_ssi->ssi_state) = 1;
  SRC_IN_STATE (last_ssi, inst) = inst;
  ssa_set_switch (&last_ssi->ssi_setp->setp_ssa, inst, 0);
  qst_set_long (inst, last_ssi->ssi_setp->setp_ssa.ssa_set_no, -1);
  return 1;
}


void
clf_local_start (cl_fref_read_node_t * clf, caddr_t * inst, itc_cluster_t * read_itcl)
{
  /* Req for partitioned fref results from others is sent, now run the local ones */
  fun_ref_node_t *fref = clf->clf_fref;
  query_frag_t *qf = fref->fnr_cl_qf;
  if (cl_partitioned_fref_start (qf->qf_nodes, inst))
    {
      /* there is local aggregation to be fetched.  Make a clib and clo that will fetch it */
      cl_op_t *local_clo = mp_clo_allocate (read_itcl->itcl_pool, CLO_QF_EXEC);
      local_clo->_.frag.qf = qf;
      local_clo->_.frag.qst = inst;
      local_clo->_.frag.is_started = QF_SETP_READ;
      clrg_add (read_itcl->itcl_clrg, cl_id_to_host (local_cll.cll_this_host), local_clo);
      DO_SET (cll_in_box_t *, clib, &read_itcl->itcl_clrg->clrg_clibs)
      {
	if (clib->clib_host->ch_id == local_cll.cll_this_host)
	  clib->clib_waiting = 1;
      }
      END_DO_SET ();
      itcl_local_start (read_itcl);
    }
}

void
cl_fref_read_input (cl_fref_read_node_t * clf, caddr_t * inst, caddr_t * state)
{
  cl_op_t *itcl_clo;
  itc_cluster_t *itcl = NULL;
  fun_ref_node_t *fref = clf->clf_fref;
  setp_node_t *setp = clf->clf_setp;
  query_frag_t *qf = fref->fnr_cl_qf;
  itc_cluster_t *fref_itcl = ((cl_op_t *) QST_GET (inst, fref->clb.clb_itcl))->_.itcl.itcl;
  int top = -1, skip = 0, nth_in_set;
  int set_no, started = QST_INT (inst, clf->clf_status);
  itcl_clo = (cl_op_t *) qst_get (inst, qf->clb.clb_itcl);
  if (!itcl_clo)
    {
      /* the qf has never been run.  Possible if there is a thing between the fref and qf.  This means the agg will be empty by definition */
      QST_INT (inst, clf->clf_status) = 1;
      SRC_IN_STATE (clf, inst) = NULL;
      return;
    }
  itcl = itcl_clo->_.itcl.itcl;

  if (!started)
    {
      QST_INT (inst, clf->clf_status) = 1;
      itcl->itcl_order = clf->clf_order;
      clf_local_start (clf, inst, itcl);
      at_printf (("Host %d starting read of partitioned fref results\n", local_cll.cll_this_host));
      SRC_IN_STATE (clf, inst) = inst;
      QST_INT (inst, clf->clf_set_no) = 0;
      QST_INT (inst, clf->clf_nth_in_set) = 0;
    }
  if (setp->setp_top)
    {
      top = unbox (qst_get (inst, setp->setp_top));
      if (setp->setp_top_skip)
	skip = unbox (qst_get (inst, setp->setp_top_skip));
    }
  for (;;)
    {
      cl_op_t *clo = itcl_next (itcl);
      if (!clo)
	break;
      if (CLO_ROW != clo->clo_op)
	GPF_T1 ("order clf expects rows only");
      set_no = unbox (clo->_.row.cols[clf->clf_order[0]->nth]);
      if (set_no < QST_INT (inst, clf->clf_set_no))
	continue;
      if (top != -1)
	{
	  if (set_no != QST_INT (inst, clf->clf_set_no))
	    {
	      QST_INT (inst, clf->clf_set_no) = set_no;
	      nth_in_set = QST_INT (inst, clf->clf_nth_in_set) = 1;
	    }
	  else
	    nth_in_set = ++QST_INT (inst, clf->clf_nth_in_set);
	}
      if (-1 == top || (nth_in_set <= top + skip && nth_in_set > skip))
	{
	  cl_ts_set_context ((table_source_t *) fref, fref_itcl, inst, set_no);
	  cl_row_set_out_cols (clf->clf_out_slots, inst, clo);
	  qn_send_output ((data_source_t *) clf, inst);
	}
    }
  cl_qi_count_affected ((query_instance_t *) inst, itcl->itcl_clrg);
  DO_SET (ssa_iter_node_t *, ssi, &qf->qf_nodes)
  {
    if (IS_QN (ssi, ssa_iter_input))
      QST_INT (inst, ssi->ssi_state) = 0;
  }
  END_DO_SET ();
  qst_set (inst, qf->clb.clb_itcl, NULL);
  qst_set (inst, fref->clb.clb_itcl, NULL);
  SRC_IN_STATE (clf, inst) = NULL;
  QST_INT (inst, clf->clf_status) = 0;
}

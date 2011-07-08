/*
 *  cldfg.c
 *
 *  $Id$
 *
 *  Cluster non-colocated query frag
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

#define in_printf(q)
#if 1
int enable_dfg_print = 0;
#define dfg_printf(q) {if (enable_dfg_print) printf q; }
#else
#define dfg_printf(q)
#endif



extern long tc_dfg_coord_pause;
extern long tc_dfg_more;

int
dfg_error (cl_thread_t * clt, cl_host_t * ch, char *msg)
{
  return CLO_ERROR;
}


cl_op_t *
dfg_state_allocate ()
{
  cl_op_t *clo = clo_allocate (CLO_DFG_STATE);
  clo->_.dfg_stat.sets_completed = 0;
  clo->_.dfg_stat.out_counts = (int64 *) dk_alloc_box (sizeof (int64) * (local_cll.cll_max_host + 1), DV_BIN);
  memset (clo->_.dfg_stat.out_counts, 0, box_length ((caddr_t) clo->_.dfg_stat.out_counts));
  return clo;
}

stage_node_t *
qf_nth_stage (dk_set_t nodes, int nth)
{
  DO_SET (stage_node_t *, stn, &nodes)
  {
    if ((qn_input_fn) stage_node_input == stn->src_gen.src_input && nth == stn->stn_nth)
      return stn;
  }
  END_DO_SET ();
  GPF_T1 ("supposed to find stage node with given no when getting input batch");
  return NULL;
}


void
dfg_more (query_frag_t * qf, caddr_t * inst, int host)
{
  caddr_t err = NULL;
  cll_in_box_t *clib;
  cl_op_t *itcl_clo = (cl_op_t *) qst_get (inst, qf->clb.clb_itcl);
  cl_host_t *ch;
  cl_req_group_t *clrg = itcl_clo->_.itcl.itcl->itcl_clrg;
  cl_host_t *old_h;
  cl_message_t cm;
  int rc;
  TC (tc_dfg_more);
  if (host == local_cll.cll_this_host)
    {
      cll_in_box_t *local_clib = (cll_in_box_t *) clrg->clrg_clibs->next->data;
      if (!local_clib->clib_in_parsed.bsk_count)
	{
	  stage_node_t *stn = qf_nth_stage (qf->qf_nodes, 1);
	  dfg_printf ((" host %d local dfg more\n", local_cll.cll_this_host));
	  QST_INT (inst, stn->stn_out_bytes) = 0;
	  clib_more (local_clib);
	}
      return;
    }
}


int
ssm_host_any (stage_sum_t ** ssms, int host)
{
  int inx;
  DO_BOX (stage_sum_t *, ssm, inx, ssms)
  {
    if (ssm[host].ssm_in_sets)
      return 1;
  }
  END_DO_BOX;
  return 0;
}


int
ssm_pending_sets (stage_sum_t ** ssms, int host)
{
  int inx;
  DO_BOX (stage_sum_t *, ssm, inx, ssms)
  {
    if (ssm[host].ssm_in_sets > ssm[host].ssm_out_sets)
      return 1;
  }
  END_DO_BOX;
  return 0;
}


int64
ssm_unprocessed (stage_sum_t ** ssms, int host)
{
  int inx;
  int64 sum = 0;
  DO_BOX (stage_sum_t *, ssm, inx, ssms)
  {
    sum += ssm[host].ssm_in_sets - ssm[host].ssm_out_sets;
  }
  END_DO_BOX;
  return sum;
}


void
dfg_ensure_lt (query_frag_t * qf, caddr_t * inst, int host)
{
  QNCAST (query_instance_t, qi, inst);
  if (qf->qf_is_agg)
    {
      caddr_t agg_map = QST_GET_V (inst, qf->qf_dfg_agg_map);
      if (!agg_map)
	QST_GET_V (inst, qf->qf_dfg_agg_map) = agg_map = dk_alloc_box_zero (local_cll.cll_max_host + 1, DV_BIN);
      agg_map[host] = 1;
    }
  if (qi->qi_isolation >= ISO_REPEATABLE || PL_EXCLUSIVE == qf->qf_lock_mode)
    {
      lock_trx_t *lt = qi->qi_trx;
      int done = 0;
      DO_SET (lt_cl_branch_t *, br, &lt->lt_cl_branches)
      {
	if (br->clbr_host->ch_id == host)
	  {
	    if (PL_EXCLUSIVE == qf->qf_lock_mode)
	      br->clbr_change = CLBR_WRITE;
	    done = 1;
	    break;
	  }
      }
      END_DO_SET ();
      if (!done)
	{
	  NEW_VARZ (lt_cl_branch_t, br);
	  br->clbr_change = PL_EXCLUSIVE == qf->qf_lock_mode ? CLBR_WRITE : CLBR_READ;
	  br->clbr_host = cl_id_to_host (host);
	  dk_set_push (&lt->lt_cl_branches, (void *) br);
	  lt->lt_known_in_cl = 1;
	}
    }
}


int
dfg_process_counts (query_frag_t * qf, caddr_t * inst, cl_op_t * clo)
{
  /* get an array of stage states from a node.  Update the consolidated state */
#if 0
  int any_pending = 0, any_unrecd = 0;
#endif
  QNCAST (query_instance_t, qi, inst);
  int inx, host, more_asked = 0;
  int any_progress = 0;
  int from_host = clo->_.dfg_array.host;
  stage_sum_t **ssm = QST_BOX (stage_sum_t **, inst, qf->qf_dfg_state);
  DO_BOX (cl_op_t *, stat, inx, clo->_.dfg_array.stats)
  {
    ssm[0][from_host].ssm_state_recd = 1;
    if (stat->_.dfg_stat.result_rows)
      any_progress = 1;
    for (host = 0; host <= local_cll.cll_max_host; host++)
      {
	ssm[inx][host].ssm_in_sets += stat->_.dfg_stat.out_counts[host];
	if (stat->_.dfg_stat.out_counts[host])
	  any_progress = 1;
	if (inx > 0)
	  ssm[inx - 1][from_host].ssm_produced_sets += stat->_.dfg_stat.out_counts[host];
      }
    ssm[inx][from_host].ssm_out_sets += stat->_.dfg_stat.sets_completed;
    if (stat->_.dfg_stat.sets_completed)
      any_progress = 1;
  }
  END_DO_BOX;
  if (!any_progress)
    {
      ssm[0][from_host].ssm_n_empty_mores++;
      if (ssm[0][from_host].ssm_n_empty_mores > 3)
	{
	  virtuoso_sleep (0, 10000);
	}
      if (ssm[0][from_host].ssm_n_empty_mores > 10)
	sqlr_new_error ("42000", "CL...",
	    "cluster distributed fragment message went missing for too long, probable network error sending to %d", from_host);
    }
  else
    {
      if (ssm[0][from_host].ssm_n_empty_mores)
	dfg_printf (("progress after empty more on %d\n", from_host));
      ssm[0][from_host].ssm_n_empty_mores = 0;
    }

  if (from_host == local_cll.cll_this_host)
    dk_free_box ((caddr_t) clo);	/* locals are allocd, ones from elsewhere are static in the clib */
  /* now the coordinator state is updated.  See if more states are needed. */
  if (qi->qi_isolation >= ISO_REPEATABLE || qf->qf_lock_mode == PL_EXCLUSIVE || qf->qf_is_agg)
    {
      /* if transactional, make sure each node that has allegedly received something has a transaction branch
       * Also if aggregate, use this same thing to keep track of which nodes must get a query for final state. */
      for (host = 0; host <= local_cll.cll_max_host; host++)
	{
	  int nth;
	  if (host == local_cll.cll_this_host)
	    continue;
	  for (nth = 0; nth < qf->qf_n_stages; nth++)
	    {
	      if (ssm[nth][host].ssm_in_sets)
		{
		  dfg_ensure_lt (qf, inst, host);
		  break;
		}
	    }
	}
    }
#if 0
  /* debug code for cases which hang after the last answer is recd */
  for (host = 0; host <= local_cll.cll_max_host; host++)
    {
      if (!ssm[0][host].ssm_state_recd)
	any_unrecd = 1;
      if (ssm_pending_sets (ssm, host))
	any_pending = 1;
    }
  if (!any_pending && any_unrecd)
    printf ("dfg reply from %d completes all but others still unrecd\n", from_host);
#endif
  for (host = 0; host <= local_cll.cll_max_host; host++)
    if (!ssm[0][host].ssm_state_recd && ssm_host_any (ssm, host))
      return CLO_BATCH_END;
  for (host = 0; host <= local_cll.cll_max_host; host++)
    {
      if (ssm[0][host].ssm_state_recd && ssm_pending_sets (ssm, host))
	{
	  ssm[0][host].ssm_state_recd = 0;
	  /* if local has more, do not advance here but only later after processing any incoming from others.  Still count this as asking for more, so as not to end prematurely.  The reason to read incoming before advance is not running out of memory due to never processing incoming until 1st stage of local is at end */
	  if (host != local_cll.cll_this_host)
	    dfg_more (qf, inst, host);
	  more_asked = 1;
	}
    }
  if (!more_asked)
    dfg_printf (("dfg %d done\n", (int) unbox (qst_get (inst, qf->qf_dfg_req_no))));
  return more_asked ? CLO_BATCH_END : CLO_SET_END;
}


void
ssm_print (stage_sum_t ** ssm)
{
  int host, inx;
  for (host = 0; host <= local_cll.cll_max_host; host++)
    {
      printf (" host %d:", host);
      for (inx = 0; inx < BOX_ELEMENTS (ssm); inx++)
	{
	  printf (" stage %d " BOXINT_FMT " " BOXINT_FMT " prod. " BOXINT_FMT ", ", inx, ssm[inx][host].ssm_in_sets,
	      ssm[inx][host].ssm_out_sets, ssm[inx][host].ssm_produced_sets);
	}
      printf ("\n");
    }
}


void
dfga_print (cl_op_t * arr)
{
  int inx, inx2, n = BOX_ELEMENTS (arr->_.dfg_array.stats);
  printf ("From %d:", arr->_.dfg_array.host);
  for (inx = 0; inx < n; inx++)
    {
      cl_op_t *stat = arr->_.dfg_array.stats[inx];
      printf ("stage %d: %d done recd %d remote batches %d local sets \n", inx, (int) stat->_.dfg_stat.sets_completed,
	  stat->_.dfg_stat.in_batches, stat->_.dfg_stat.in_local_sets);
      for (inx2 = 0; inx2 <= local_cll.cll_max_host; inx2++)
	{
	  printf ("  to %d: %d out\n", inx2, (int) stat->_.dfg_stat.out_counts[inx2]);
	}
    }
}

void
dfg_stat_print (cl_op_t * clo)
{
  int host, inx;
  printf ("Stat from %d: ", clo->_.dfg_array.host);
  for (host = 0; host <= local_cll.cll_max_host; host++)
    {
      printf ("host %d:", host);
      DO_BOX (cl_op_t *, stat, inx, clo->_.dfg_array.stats)
      {
	printf ("done " BOXINT_FMT " ", clo->_.dfg_array.stats[inx]->_.dfg_stat.sets_completed);
      }
      END_DO_BOX;
      DO_BOX (cl_op_t *, stat, inx, clo->_.dfg_array.stats)
      {
	printf ("out: " BOXINT_FMT " ", clo->_.dfg_array.stats[inx]->_.dfg_stat.out_counts[host]);
      }
      END_DO_BOX;
    }
}


stage_sum_t **
qf_ssm_init (query_frag_t * qf, caddr_t * inst)
{
  itc_cluster_t *itcl = ((cl_op_t *) QST_GET_V (inst, qf->clb.clb_itcl))->_.itcl.itcl;
  stage_sum_t **stat = (stage_sum_t **) mp_alloc_box_ni (itcl->itcl_pool, sizeof (caddr_t) * qf->qf_n_stages, DV_ARRAY_OF_POINTER);
  int inx;
  for (inx = 0; inx < qf->qf_n_stages; inx++)
    {
      stat[inx] = (stage_sum_t *) mp_alloc_box_ni (itcl->itcl_pool, sizeof (stage_sum_t) * (local_cll.cll_max_host + 1), DV_BIN);
      memset (stat[inx], 0, box_length ((caddr_t) stat[inx]));
    }
  QST_BOX (stage_sum_t **, inst, qf->qf_dfg_state) = stat;
  return stat;
}


cl_op_t *
dfg_batch_counts (dk_set_t nodes, caddr_t * inst, int n_stages)
{
  int inx;
  cl_op_t *arr = clo_allocate (CLO_DFG_ARRAY);
  arr->_.dfg_array.host = local_cll.cll_this_host;
  arr->_.dfg_array.stats = dk_alloc_box (sizeof (caddr_t) * n_stages, DV_ARRAY_OF_POINTER);
  for (inx = 0; inx < n_stages; inx++)
    {
      stage_node_t *stn = qf_nth_stage (nodes, inx + 1);
      cl_op_t *stat = (cl_op_t *) qst_get (inst, stn->stn_dfg_state);
      if (!stat)
	qst_set (inst, stn->stn_dfg_state, (caddr_t) (stat = dfg_state_allocate ()));
      if (stn->stn_coordinator == local_cll.cll_this_host)
	{
	  cl_op_t *stat2 = clo_allocate (CLO_DFG_STATE);
	  *stat2 = *stat;
	  stat2->_.dfg_stat.out_counts = (int64 *) box_copy ((caddr_t) stat2->_.dfg_stat.out_counts);
	  memset (stat->_.dfg_stat.out_counts, 0, box_length ((caddr_t) stat->_.dfg_stat.out_counts));
	  stat->_.dfg_stat.sets_completed = 0;
	  stat = stat2;
	}
      arr->_.dfg_array.stats[inx] = stat;
    }
  return arr;
}


void
dfg_batch_end (dk_set_t nodes, caddr_t * inst, int n_stages, cll_in_box_t * local_clib)
{
  stage_node_t *stn = qf_nth_stage (nodes, 1);
  cl_op_t *arr = dfg_batch_counts (nodes, inst, n_stages);
  if (stn->stn_coordinator == local_cll.cll_this_host)
    {
      arr->_.dfg_array.stats[0]->_.dfg_stat.result_rows = local_clib->clib_in_parsed.bsk_count;
      basket_add (&local_clib->clib_in_parsed, (void *) arr);
    }
}


void
stn_in_batch (stage_node_t * stn, caddr_t * inst, caddr_t in, int read_to, int bytes)
{
  /* add a batch string to the in queue of the stn */
  cl_op_t *clo = clo_allocate (CLO_STN_IN);
  cl_op_t *dfg_state;
  caddr_t **q;
  int fill;
  if (!(dfg_state = (cl_op_t *) QST_GET_V (inst, stn->stn_dfg_state)))
    dfg_state = (cl_op_t *) (QST_GET_V (inst, stn->stn_dfg_state) = (caddr_t) dfg_state_allocate ());
  dfg_state->_.dfg_stat.in_batches++;
  clo->_.stn_in.in = in;
  clo->_.stn_in.read_to = read_to;
  clo->_.stn_in.bytes = bytes;
  q = (caddr_t **) & inst[stn->stn_input->ssl_index];
  fill = QST_INT (inst, stn->stn_input_fill);
  array_add (q, &fill, (caddr_t) clo);
  QST_INT (inst, stn->stn_input_fill) = fill;
  SRC_IN_STATE ((data_source_t *) stn, inst) = inst;
}


void
dfg_coord_batch (itc_cluster_t * itcl, cll_in_box_t * clib)
{
  /* the coordinator node gets a batch of ops for a stage of a dfg.  The coord's state in the ssm is no longer known, must do another batch followed by dfg state message.   */
  caddr_t *inst = itcl->itcl_qst;
  query_frag_t *qf = itcl->itcl_dfg_qf;
  stage_node_t *stn = qf_nth_stage (qf->qf_nodes, clib->clib_first._.frag.nth_stage);
  stage_sum_t **ssm = QST_BOX (stage_sum_t **, inst, qf->qf_dfg_state);
  ssm[0][local_cll.cll_this_host].ssm_state_recd = 0;
  stn_in_batch (stn, inst, clib->clib_in_strses.dks_in_buffer, 0, clib->clib_in_strses.dks_in_fill);
  clib->clib_in_strses.dks_in_buffer = NULL;
  clib->clib_in_strses.dks_in_fill = 0;
  clo_destroy (&clib->clib_first);
  clib->clib_first.clo_op = CLO_NONE;
}


int
dfg_is_more_next ()
{
  client_connection_t *cli = sqlc_client ();
  cl_thread_t *clt = cli->cli_clt;
  cl_message_t *next_cm;
  int is_next = 0;
  /*return 0; */
  if (!clt->clt_queue.bsk_count)
    return 0;
  IN_CLL;
  next_cm = basket_first (&clt->clt_queue);
  if (next_cm && next_cm->cm_req_no == clt->clt_current_cm->cm_req_no)
    is_next = 1;
  LEAVE_CLL;
  if (is_next)
    dfg_printf (("host %d skip dfg flush because more queued\n", local_cll.cll_this_host));
  return is_next;
}


int32
str_int (char **str)
{
  if (DV_SHORT_INT == **(dtp_t **) str)
    {
      (*str) += 2;
      return (*str)[-1];
    }
  else if (DV_LONG_INT == **(dtp_t **) str)
    {
      (*str) += 5;
      return LONG_REF_NA (((*str) - 4));
    }
  GPF_T1 ("expected int in serialization");
  return 0;
}


int
cm_dfg_target_stage (cl_message_t * cm)
{
  /* see if a cm is meant for this dfg and return which stage it should go to */
  char *str;
  int coord;
  if (!cm || CL_BATCH != cm->cm_op || cm->cm_in_string)
    return 0;
  if (CLO_QF_EXEC != cm->cm_in_string[0])
    return 0;
  str = cm->cm_in_string + 1;
  str_int (&str);		/* seq no and param row no */
  str_int (&str);
  coord = str_int (&str);
  if (!coord)
    return 0;
  return str_int (&str);
}


int
dfg_batch_from_queue (stage_node_t * stn, caddr_t * inst)
{
  /* if a stage node is at end, could be more batches for this or other stages in the queue.  For coord, this is the results queue of the qf's itcl.  For non-coord, this is the clt's queue.  If find, pop one off and put it into the suitable stage's input */
  /* the idea is to prefer processing batches for later stages to continuing earlier stages */
  stage_node_t *target_stn = NULL;
  cl_message_t *cm = NULL;
  int stage = 0;
  if (stn->stn_coordinator == local_cll.cll_this_host)
    {
      query_frag_t *qf = stn->stn_qf;
      itc_cluster_t *itcl = ((cl_op_t *) QST_GET_V (inst, qf->clb.clb_itcl))->_.itcl.itcl;
      DO_SET (cll_in_box_t *, clib, &itcl->itcl_clrg->clrg_clibs)
      {
	if (clib->clib_in.bsk_count)
	  {
	    mutex_enter (&itcl->itcl_clrg->clrg_mtx);
	    cm = (cl_message_t *) basket_first (&clib->clib_in);
	    stage = cm_dfg_target_stage (cm);
	    if (stage)
	      basket_get (&clib->clib_in);
	    else
	      cm = NULL;
	    mutex_leave (&itcl->itcl_clrg->clrg_mtx);
	  }
	if (cm)
	  break;
      }
      END_DO_SET ();
      if (cm)
	{
	  stage_sum_t **ssm = QST_BOX (stage_sum_t **, inst, qf->qf_dfg_state);
	  target_stn = qf_nth_stage (stn->stn_qf->qf_nodes, stage);
	  ssm[0][local_cll.cll_this_host].ssm_state_recd = 0;
	}
    }
  else
    {
      client_connection_t *cli = sqlc_client ();
      cl_thread_t *clt = cli->cli_clt;
      if (clt->clt_queue.bsk_count)
	{
	  uint32 req_no = unbox (QST_GET_V (inst, stn->stn_coordinator_req_no));
	  IN_CLL;
	  cm = (cl_message_t *) basket_first (&clt->clt_queue);
	  stage = cm_dfg_target_stage (cm);
	  if (stage && cm->cm_req_no == req_no)
	    basket_get (&clt->clt_queue);
	  else
	    cm = NULL;
	  LEAVE_CLL;
	  if (cm)
	    target_stn = qf_nth_stage (stn->src_gen.src_query->qr_nodes, stage);
	}
    }
  if (!cm)
    return 0;
  stn_in_batch (target_stn, inst, cm->cm_in_string, 0, cm->cm_bytes);
  cm->cm_in_string = NULL;
  GPF_T;
  return 1;
}


int
dfg_coord_should_pause (itc_cluster_t * itcl)
{
  /* when getting results of a dfg, check whether local state should be advanced.  Hold advancing local state if
   * can only advance before stage 2 and if remotes have over 2 batches of unprocessed states and have not returned a state */
  int64 unprocessed = 0;
  caddr_t *inst = itcl->itcl_qst;
  query_frag_t *qf = itcl->itcl_dfg_qf;
  stage_sum_t **ssm = QST_BOX (stage_sum_t **, inst, qf->qf_dfg_state);
  int host, n_running = 0;
  for (host = 0; host <= local_cll.cll_max_host; host++)
    {
      if (host == local_cll.cll_this_host)
	continue;
      if (!ssm[0][host].ssm_state_recd)
	{
	  n_running++;
	  unprocessed += ssm_unprocessed (ssm, host);
	}
    }
  if (!n_running)
    return 0;
  DO_SET (stage_node_t *, stn, &qf->qf_nodes)
  {
    if (SRC_IN_STATE ((data_source_t *) stn, inst))
      return 0;			/* there is continuable state late enough */
    if (IS_STN (stn))
      {
	break;
      }
  }
  END_DO_SET ();
  if (unprocessed < qf->clb.clb_batch_size * n_running * 2)
    return 0;
  dfg_printf (("coord too far in advance, %d pending elsewhere\n", (int) unprocessed));
  TC (tc_dfg_coord_pause);
  return 1;
}


void
dfg_coord_send (stage_node_t * stn, caddr_t * inst, cl_req_group_t * clrg)
{
  /* when sending reqs from coordinator, mark the recipients as having unknown state in ssm */
  query_frag_t *qf = stn->stn_qf;
  stage_sum_t **ssm = QST_BOX (stage_sum_t **, inst, qf->qf_dfg_state);
  cl_op_t *rcv_clo = (cl_op_t *) QST_GET_V (inst, qf->clb.clb_itcl);
  rcv_clo->_.itcl.itcl->itcl_clrg->clrg_send_time = get_msec_real_time () | 1;	/* for purposes of timeout the send time is recorded on the receiving clrg not the sending */
  DO_SET (cll_in_box_t *, clib, &clrg->clrg_clibs)
  {
    if (clib->clib_req_strses && strses_length (clib->clib_req_strses))
      ssm[0][clib->clib_host->ch_id].ssm_state_recd = 0;
  }
  END_DO_SET ();
}


void
stn_flush (stage_node_t * stn, caddr_t * inst, caddr_t * err_ret)
{
  itc_cluster_t *itcl = ((cl_op_t *) QST_GET_V (inst, stn->clb.clb_itcl))->_.itcl.itcl;
  itcl->itcl_clrg->clrg_dfg_req_no = unbox (QST_GET_V (inst, stn->stn_coordinator_req_no));
  itcl->itcl_clrg->clrg_dfg_host = stn->stn_coordinator;
  DO_SET (cll_in_box_t *, clib, &itcl->itcl_clrg->clrg_clibs)
  {
    /* this clib was never registered because it gets req no before first send.  The one that is registered is the coordinator qf's clib, no other */
    clib->clib_req_no = unbox (QST_GET_V (inst, stn->stn_coordinator_req_no));
    clib->clib_fake_req_no = 1;
    dfg_printf (("host %d:%d %d sets for %d\n", local_cll.cll_this_host, clib->clib_req_no, clib->clib_n_selects,
	    clib->clib_host->ch_id));
    clib->clib_n_selects = 0;
    clib->clib_dfg_any = 1;
    if (clib->clib_host->ch_id == stn->stn_coordinator)
      clib->clib_batch_as_reply = 1;
    else
      QST_INT (inst, stn->stn_out_bytes) += strses_length (clib->clib_req_strses);
  }
  END_DO_SET ();
  if (stn->stn_coordinator == local_cll.cll_this_host)
    dfg_coord_send (stn, inst, itcl->itcl_clrg);
}


void
stn_reset_if_enough (stage_node_t * stn, caddr_t * inst, cl_req_group_t * clrg)
{
  /*return; */
  DO_SET (cll_in_box_t *, clib, &clrg->clrg_clibs)
  {
    int n;
    if ((n = clib->clib_n_selects) > ((stn->clb.clb_batch_size / 4) + 1) * 5)
      {
	caddr_t err = NULL;
	QNCAST (query_instance_t, qi, inst);
	stn_flush (stn, inst, &err);
	if (err)
	  sqlr_resignal (err);
	dfg_printf (("host %d resets after sending %d to %d\n", local_cll.cll_this_host, n, clib->clib_host->ch_id));
	longjmp_splice (qi->qi_thread->thr_reset_ctx, RST_ENOUGH);
      }
  }
  END_DO_SET ();
}


void
stage_node_input (stage_node_t * stn, caddr_t * inst, caddr_t * state)
{
}

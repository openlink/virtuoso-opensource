/*
 *  sqlvnode.c
 *
 *  $Id$
 *
 *  Vectored versions of common nodes
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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
#include "sqlfn.h"
#include "lisprdr.h"
#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlbif.h"
#include "arith.h"
#include "security.h"
#include "sqltype.h"
#include "repl.h"
#include "replsr.h"


db_buf_t
sel_extend_bits (select_node_t * sel, caddr_t * inst, int row_no, int *bits_max)
{
  QNCAST (query_instance_t, qi, inst);
  db_buf_t bits;
  db_buf_t prev_bits = QST_BOX (db_buf_t, inst, sel->sel_vec_set_mask);
  int next_sz = MIN (ALIGN_8 (row_no + dc_batch_sz), ALIGN_8 (dc_max_batch_sz));
  *bits_max = next_sz - 1;
  bits = (db_buf_t) mp_alloc_box_ni (qi->qi_mp, next_sz / 8, DV_BIN);
  memcpy_16 (bits, prev_bits, box_length (prev_bits));
  memzero (bits + box_length (prev_bits), box_length (bits) - box_length (prev_bits));
  QST_BOX (db_buf_t, inst, sel->sel_vec_set_mask) = bits;
  return bits;
}


void
select_node_input_subq_vec (select_node_t * sel, caddr_t * inst, caddr_t * state)
{
  QNCAST (query_instance_t, qi, inst);
  db_buf_t bits = NULL;
  int n_rows, prev_set, row, top = 0, top_ctr, skip = 0;
  int bits_max;
  if (sel->src_gen.src_prev)
    n_rows = QST_INT (inst, sel->src_gen.src_prev->src_out_fill);
  else
    n_rows = 1;
  QST_INT (inst, sel->src_gen.src_out_fill) = n_rows;
  if (sel->sel_subq_inlined)
    {
      /* a select node after a group by reader, flattened into containing query.  Set the output sets according to the set no ssl  */
      data_col_t * dc = sel->sel_set_no ? QST_BOX (data_col_t *, inst, sel->sel_set_no->ssl_index) : NULL;
      int64 * nos = dc ? (int64*)dc->dc_values : NULL;
      int * out_sets;
      QN_CHECK_SETS (sel, inst, n_rows);
      out_sets = QST_BOX (int *, inst, sel->src_gen.src_sets);
      if (sel->sel_set_no && SSL_REF == sel->sel_set_no->ssl_type)
	{
	  int sets[ARTM_VEC_LEN];
	  int inx, inx2;
	  for (inx = 0; inx < n_rows; inx += ARTM_VEC_LEN)
	    {
	      int to = MIN (n_rows, inx + ARTM_VEC_LEN);
	      sslr_n_consec_ref (inst, (state_slot_ref_t*)sel->sel_set_no, sets, inx, to - inx);
	      to -= inx;
	      for (inx2 = 0; inx2 < to; inx2++)
		out_sets[inx + inx2] = nos[sets[inx2]];
	    }
	}
      else
	{
	  int inx2;
	  for (inx2 = 0; inx2 < n_rows; inx2++)
	    out_sets[inx2] = nos ? nos[inx2] : 0;
	}
      qn_send_output ((data_source_t*)sel, inst);
      return;
    }
  if (sel->sel_top)
    {
      top = unbox (qst_get (inst, sel->sel_top));
      if (sel->sel_top_skip)
	skip = unbox (qst_get (inst, sel->sel_top_skip));
      prev_set = unbox (QST_GET (inst, sel->sel_prev_set_no));
      top_ctr = state ? QST_INT (inst, sel->src_gen.src_out_fill) : 0;
    }
  if (sel->sel_vec_set_mask)
    {
      bits = QST_BOX (db_buf_t, inst, sel->sel_vec_set_mask);
      if (!bits)
	{
	  bits = (db_buf_t) mp_alloc_box_ni (qi->qi_mp, ALIGN_8 (dc_batch_sz) / 8, DV_BIN);
	  QST_BOX (db_buf_t, inst, sel->sel_vec_set_mask) = bits;
	  memzero (bits, box_length (bits));
	}
      bits_max = (box_length (bits) * 8) - 1;
    }
  if (SEL_VEC_EXISTS == sel->sel_vec_role)
    {
      int row2;
      for (row2 = 0; row2 + 8 <= n_rows; row2 += 8)
	{
	  int refs[8];
	  data_col_t *dc = QST_BOX (data_col_t *, inst, sel->sel_set_no->ssl_index);
	  int64 *vals = (int64 *) dc->dc_values;
	  sslr_n_consec_ref (inst, (state_slot_ref_t *) sel->sel_set_no, refs, row2, 8);
	  for (row = 0; row < 8; row++)
	    {
	      int set_no = vals[refs[row]];
	      if (set_no > bits_max)
		bits = sel_extend_bits (sel, inst, set_no, &bits_max);
	      bits[set_no >> 3] |= 1 << (set_no & 7);
	    }
	}
      for (row = row2; row < n_rows; row++)
	{
	  int set_no = qst_vec_get_int64 (inst, sel->sel_set_no, row);
	  if (set_no > bits_max)
	    bits = sel_extend_bits (sel, inst, set_no, &bits_max);
	  bits[set_no >> 3] |= 1 << (set_no & 7);
	}
    }
  else if (SEL_VEC_SCALAR == sel->sel_vec_role && sel->sel_scalar_ret)
    {
      int64 * ext_sets = (int64*)QST_BOX (data_col_t *, inst, sel->sel_ext_set_no->ssl_index)->dc_values;
      db_buf_t bits = QST_BOX (db_buf_t, inst, sel->sel_vec_set_mask);
      for (row = 0; row < n_rows; row++)
	{
	  int set_no = sslr_set_no (inst, sel->sel_set_no, row);
	  int ext_set_no = ext_sets[set_no];
	  if (ext_set_no > bits_max)
	    bits = sel_extend_bits (sel, inst, ext_set_no, &bits_max);
	  if (!(bits[ext_set_no >> 3] & (1 << (ext_set_no & 7))))
	    {
	      bits[ext_set_no >> 3] |= 1 << (ext_set_no & 7);
	      dc_assign_copy (inst, sel->sel_scalar_ret, ext_set_no, sel->sel_out_slots[0], row);
	    }
	}
    }
  else if (SEL_VEC_DT == sel->sel_vec_role)
    {
      QST_INT (inst, sel->src_gen.src_out_fill) = n_rows;
    }
  if (qi->qi_branched_select != sel)
    {
      SRC_RETURN (((data_source_t *) sel), inst);
      longjmp_splice (qi->qi_thread->thr_reset_ctx, RST_ENOUGH);
    }
}

void
select_node_lc_input (select_node_t * sel, query_instance_t * qi, int n_rows, int top, int top_skip)
{
  caddr_t *inst = (caddr_t *) qi;
  local_cursor_t *lc = qi->qi_lc;
  int top_ctr;
  lc->lc_vec_n_rows = n_rows;
  if (top)
    {
      top_ctr = unbox (qst_get (inst, sel->sel_row_ctr));
      if (top_ctr + n_rows >= top)
	{
	  lc->lc_vec_n_rows = top - top_ctr;
	  lc->lc_vec_at_end = 2;
	  SRC_RETURN (((data_source_t *) sel), inst);
	  longjmp_splice (qi->qi_thread->thr_reset_ctx, RST_AT_END);
	}
      qst_set_long (inst, sel->sel_row_ctr, n_rows + top_ctr);
    }
  SRC_RETURN (((data_source_t *) sel), inst);
  longjmp_splice (qi->qi_thread->thr_reset_ctx, RST_ENOUGH);
}


void
select_node_input_vec (select_node_t * sel, caddr_t * inst, caddr_t * state)
{
  QNCAST (query_instance_t, qi, inst);
  int quota = (int) (ptrlong) inst[sel->sel_out_quota];
  int n_rows, row, skip = 0, top = 0, top_ctr = 0, fill = 0;
  int pos_in_batch = QST_INT (inst, sel->sel_out_fill);
  if (state)
    {
      QST_INT (inst, sel->src_gen.src_out_fill) = 0;
    }
  if (sel->src_gen.src_prev)
    n_rows = QST_INT (inst, sel->src_gen.src_prev->src_out_fill);
  else
    n_rows = 1;
  if (sel->sel_top)
    {
      top = unbox (qst_get (inst, sel->sel_top));
      if (sel->sel_top_skip)
	skip = unbox (qst_get (inst, sel->sel_top_skip));
      if (top < 0 || skip < 0)
	sqlr_new_error ("42000", "TOPSK", "select skip, top has a negative top or skip value");
      top += skip;
      top_ctr = unbox (qst_get (inst, sel->sel_row_ctr));
    }
  if (qi->qi_lc)
    {
      select_node_lc_input (sel, qi, n_rows, top, skip);
      return;
    }
  if (CALLER_CLIENT != qi->qi_caller || !qi->qi_client->cli_session)
    return;

  if (top && top_ctr + n_rows < skip)
    {
      qst_set_long (inst, sel->sel_row_ctr, top_ctr + n_rows);
      return;
    }
  if (top && top_ctr < skip)
    {
      int n_skipped = skip - top_ctr;
      qst_set_long (inst, sel->sel_row_ctr, skip);
      top_ctr = skip;
      QST_INT (inst, sel->src_gen.src_out_fill) += n_skipped;
    }
  QST_INT (inst, sel->sel_client_batch_start) = QST_INT (inst, sel->src_gen.src_out_fill);
  for (row = QST_INT (inst, sel->src_gen.src_out_fill); row < n_rows; row++)
    {
      int set_no;
      qi->qi_set = row;
      set_no = sel->sel_set_no ? unbox (qst_get (inst, sel->sel_set_no)) : 0;
      if (!top || top_ctr < top)
	{
	  int is_full = qi->qi_prefetch_bytes && qi->qi_bytes_selected > qi->qi_prefetch_bytes;
	  int slots = sel->sel_n_value_slots;
	  int inx;
	  OFF_T b1 = 0, b2 = 0;
	  PRPC_ANSWER_START (qi->qi_thread, PARTIAL);
	  b1 = __ses->dks_bytes_sent;
	  dks_array_head (__ses, slots + 1, DV_ARRAY_OF_POINTER);
	  print_int (is_full ? QA_ROW_LAST_IN_BATCH : QA_ROW, __ses);
	  for (inx = 0; inx < slots; inx++)
	    {
	      caddr_t value = QST_GET (inst, sel->sel_out_slots[inx]);
	      print_object (value, __ses, NULL, NULL);
	    }
	  b2 = __ses->dks_bytes_sent;
	  PRPC_ANSWER_END (0);
	  qi->qi_bytes_selected += b2 - b1;
	  top_ctr++;
	  fill++;
	  pos_in_batch++;
	  if (top && top_ctr >= top)
	    {
	      subq_init (sel->src_gen.src_query, inst);
	      SRC_RETURN (((data_source_t *) sel), inst);
	      longjmp_splice (qi->qi_thread->thr_reset_ctx, RST_AT_END);
	    }
	  if (PREFETCH_ALL == quota)
	    continue;
	  if (is_full || pos_in_batch >= quota)
	    {
	      QST_INT (inst, sel->sel_out_fill) = 0;
	      QST_INT (inst, sel->src_gen.src_out_fill) = row + 1;
	      if (sel->sel_row_ctr)
		qst_set_long (inst, sel->sel_row_ctr, top_ctr);
	      SRC_IN_STATE (sel, inst) = (row < n_rows - 1) ? inst : NULL;
	      SRC_RETURN (((data_source_t *) sel), inst);
	      longjmp_splice (qi->qi_thread->thr_reset_ctx, RST_ENOUGH);
	    }
	}
    }
  QST_INT (inst, sel->sel_out_fill) = pos_in_batch;
  if (sel->sel_top)
    {
      QST_INT (inst, sel->src_gen.src_out_fill) = top_ctr;
      qst_set_long (inst, sel->sel_row_ctr, top_ctr);
    }
  SRC_IN_STATE (sel, inst) = NULL;
}


#define n_ones(n)  ((1 << (n)) - 1)

int bits_print_limit = 20;
void
bits_print (db_buf_t bits, int n, int ones)
{
  int inx, ctr = 0, n_out = 0;
  for (inx = 0; inx < n; inx++)
    {
      int bit = bits[inx >> 3] & 1 << (inx & 7);
      if (2 == ones && bit)
	ctr++;
      if ((1 == ones && bit) || (0 == ones && !bit))
	{
	  printf (" %d", inx);
	  n_out++;
	  if (n_out > bits_print_limit)
	    {
	      printf ("...");
	      break;
	    }
	}
    }
  if (2 == ones)
    printf ("%d\n", ctr);
  else
    printf ("\n");
}


int
bits_mix (db_buf_t bits, db_buf_t mask, int n_bits)
{
  /*consider bits of bits where mask has a 1 bit.  2 if both 0 and 1 exist, 1 if all 1, 0 if all 0 */
  int n_bytes = ALIGN_8 (n_bits) / 8;
  int rem = 8 - (n_bytes * 8 - n_bits), inx, zeros = 0, ones = 0;
  dtp_t last_ones = n_ones (rem);
  if (!mask)
    {
      for (inx = 0; inx < n_bytes; inx++)
	{
	  dtp_t w = bits[inx];
	  /* in last byte, where only low rem bits are significant, take out the high bits */
	  if (inx == n_bytes - 1)
	    {
	      w &= last_ones;
	      if (w == last_ones)
		ones++;
	      else  if (0 == w)
	    zeros++;
	      else
		return 2;
	      break;
	    }
	  if (0xff == w)
	    ones++;
	  else if (0 == w)
	    zeros++;
	  else
	    return 2;
	  if (zeros && ones)
	    return 2;
	}
    }
  else
    {
      for (inx = 0; inx < n_bytes; inx++)
	{
	  dtp_t w = ((dtp_t *) bits)[inx];
	  dtp_t m = ((dtp_t *) mask)[inx];
	  if (inx ==  n_bytes - 1)
	    {
	      w &= last_ones;
	      m &= last_ones;
	    }
	  if (w == m)
	    {
	      if (w)
	    ones++;
	    }
	  else if (0 == w)
	    zeros++;
	  else
	    return 2;
	  if (zeros && ones)
	    return 2;
	}
    }
  if (zeros && ones)
    return 2;
  return ones != 0;
}


void
ins_vec_exists (instruction_t * ins, caddr_t * inst, db_buf_t next_mask, int *n_true, int *n_false)
{
  int st = CR_INITIAL;
  caddr_t err;
  int mix;
  QNCAST (query_instance_t, qi, inst);
  db_buf_t input_mask = qi->qi_set_mask;
  subq_pred_t *subp = (subq_pred_t *) ins->_.pred.cmp;
  query_t *qr = subp->subp_query;
  int n_sets = qi->qi_n_sets;
  QST_BOX (db_buf_t, inst, qr->qr_select_node->sel_vec_set_mask) = next_mask;
  subq_init (qr, inst);
  do
    {
      err = subq_next (qr, inst, st);
      st = CR_OPEN;
      if (IS_BOX_POINTER (err))
	sqlr_resignal (err);
    }
  while ((caddr_t) SQL_SUCCESS == err);
  qi->qi_n_sets = n_sets;
  mix = bits_mix (next_mask, input_mask, qi->qi_n_sets);
  if (2 == mix)
    {
      *n_false = *n_true = 1;
    }
  else if (1 == mix)
    {
      *n_false = 0;
      *n_true = qi->qi_n_sets;
    }
  else
    {
      *n_false = qi->qi_n_sets;
      *n_true = 0;
    }
}


void
ins_vec_subq (instruction_t * ins, caddr_t * inst)
{
  int st = CR_INITIAL, inx;
  caddr_t err;
  QNCAST (query_instance_t, qi, inst);
  query_t *qr = ins->_.subq.query;
  int n_sets = qi->qi_n_sets;
  db_buf_t set_mask = qi->qi_set_mask, bits = NULL;
  char save_lock = qi->qi_lock_mode;
  int n_bytes = ALIGN_8 (n_sets) / 8;
  select_node_t *sel = qr->qr_select_node;
  if (sel && sel->sel_scalar_ret)
    {
      data_col_t *scalar_ret = QST_BOX (data_col_t *, inst, sel->sel_scalar_ret->ssl_index);
      dc_reset (scalar_ret);
    }
  if (sel)
    {
      bits = QST_BOX (db_buf_t, inst, qr->qr_select_node->sel_vec_set_mask);
      if (!bits || box_length (bits) < n_bytes)
	{
	  bits = QST_BOX (db_buf_t, inst, qr->qr_select_node->sel_vec_set_mask) = (db_buf_t)mp_alloc_box (qi->qi_mp, n_bytes, DV_BIN);
	}
      if (set_mask)
	{
	  for (inx = 0; inx < n_bytes; inx++)
	    bits[inx] &= ~set_mask[inx];
	}
      else
	memset (bits, 0, n_bytes);
    }
  subq_init (qr, inst);
  do
    {
      err = subq_next (qr, inst, st);
      st = CR_OPEN;
      if (IS_BOX_POINTER (err))
	{
	  qi->qi_lock_mode = save_lock;
	sqlr_resignal (err);
    }
    }
  while ((caddr_t) SQL_SUCCESS == err);
  qi->qi_lock_mode = save_lock;
  if (sel)
    {
      int set;
      for (set = 0; set < n_sets; set++)
	{
	  if (!(bits[set >> 3] & 1 << (set & 0x7)))
	    {
	      qi->qi_set = set;
	      qst_set_null (inst, ins->_.subq.scalar_ret);
	    }
	}
    }
  qi->qi_n_sets = n_sets;
  qi->qi_set_mask = set_mask;
}


void
ose_vec_outer_rows (outer_seq_end_node_t * ose, caddr_t * inst)
{
  int inx, set;
  db_buf_t bits = (db_buf_t) QST_GET_V (inst, ose->ose_bits);
  data_col_t *dc;
  int first = 1;
  set_ctr_node_t *sctr = ose->ose_sctr;
  int n_in_sctr = QST_INT (inst, sctr->src_gen.src_out_fill);
  QST_INT (inst, ose->src_gen.src_out_fill) = 0;
  DO_BOX (state_slot_t *, ssl, inx, ose->ose_out_slots)
  {
    if (ose->ose_out_shadow[inx])
      ssl = ose->ose_out_shadow[inx];
    dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
    dc_reset (dc);
    for (set = 0; set < n_in_sctr; set++)
      {
	if (!bits || 0 == (bits[set >> 3] & 1 << (set & 7)))
	  {
	    if (first)
	      qn_result ((data_source_t *) ose, inst, set);
	    dc_append_null (dc);
	  }
      }
    first = 0;
  }
  END_DO_BOX;
  if (first)
    {
      for (set = 0; set < n_in_sctr; set++)
	{
	  if (!bits || 0 == (bits[set >> 3] & 1 << (set & 7)))
	    qn_result ((data_source_t *) ose, inst, set);
	}
    }
  if (QST_INT (inst, ose->src_gen.src_out_fill))
    qn_send_output ((data_source_t *) ose, inst);
}


void
set_ctr_vec_input (set_ctr_node_t * sctr, caddr_t * inst, caddr_t * state)
{
  int fill = 0;
  outer_seq_end_node_t * ose = sctr->sctr_ose;
  QNCAST (query_instance_t, qi, inst);
  int n_sets = 0, inx;
  data_col_t *dc = QST_BOX (data_col_t *, inst, sctr->sctr_set_no->ssl_index);
  data_col_t * ext_dc = sctr->sctr_ext_set_no ? QST_BOX (data_col_t *, inst, sctr->sctr_ext_set_no->ssl_index) : NULL;
  /* XXX: test the sctr_trans_recursive and get n_sets from qi_n_sets */
  if (sctr->src_gen.src_prev)
    n_sets = QST_INT (inst, sctr->src_gen.src_prev->src_out_fill);
  else
    {
      if (!qi->qi_n_sets)
	{
	  n_sets = qi->qi_n_sets = 1;
      SRC_N_IN (((data_source_t *) sctr), inst, n_sets);
    }
      n_sets = qi->qi_n_sets;
    }
  if (!state)
    {
      SRC_IN_STATE (sctr, inst) = NULL;
      ose_vec_outer_rows (ose, inst);
      return;
    }
  if (ose)
    {
      db_buf_t bits = (db_buf_t)QST_GET_V (inst, ose->ose_bits);
      if (!bits || box_length (bits) < ALIGN_8 (n_sets) / 8)
	{
	  if (n_sets > dc_max_batch_sz) GPF_T1 ("over max batch sz in oj");
	  bits = (db_buf_t)dk_alloc_box (ALIGN_8 (MIN (n_sets * 2, dc_max_batch_sz)) / 8, DV_BIN);
	  qst_set (inst, ose->ose_bits, (caddr_t)bits);
	}
      memzero (bits, box_length (bits));
      SRC_IN_STATE (sctr, inst) = inst;
    }
  QST_INT (inst, sctr->src_gen.src_out_fill) = 0;
  DC_CHECK_LEN (dc, n_sets - 1);
  if (ext_dc)
    DC_CHECK_LEN (ext_dc, n_sets - 1);
  QN_CHECK_SETS (sctr, inst, n_sets);
  if (sctr->sctr_hash_spec)
    {
      for (inx = 0; inx < n_sets; inx++)
	{
	  if (!QI_IS_SET (qi, inx))
	    continue;
	  qi->qi_set = inx;
	  DO_SET (search_spec_t *, sp, &sctr->sctr_hash_spec)
	  {
	    if (!sctr_hash_range_check (inst, sp))
	      goto next_hash_set;
	  }
	  END_DO_SET ();
	  if (ext_dc)
	    {
	      ((int64*)ext_dc->dc_values)[fill] = inx;
	      ((int64*)dc->dc_values)[fill] = fill;
	    }
	  else
	    ((int64*)dc->dc_values)[fill] = inx;

	  fill++;
	  qn_result ((data_source_t *) sctr, inst, inx);
	next_hash_set:;
	}
    }
  else
    {
      for (inx = 0; inx < n_sets; inx++)
	{
	  if (QI_IS_SET (qi, inx))
	    {
	      if (ext_dc)
		{
		  ((int64*)ext_dc->dc_values)[fill] = inx;
		  ((int64*)dc->dc_values)[fill] = fill;
		}
	      else
		((int64*)dc->dc_values)[fill] = inx;

	      fill++;
	      qn_result ((data_source_t *) sctr, inst, inx);
	    }
	}
    }
  QST_INT (inst, sctr->src_gen.src_out_fill) = fill;
  if (ext_dc)
    ext_dc->dc_n_values = fill;
  dc->dc_n_values = fill;
  qi->qi_set_mask = NULL;
  if (fill)
    {
      qn_send_output ((data_source_t *) sctr, inst);
      if (sctr->sctr_ose)
	set_ctr_vec_input (sctr, inst, NULL);
    }
}


void
sqs_out_sets (subq_source_t * sqs, caddr_t * inst)
{
  /* if a sqs is resumed after anytime timeout, get the set nos from the partially filled select node */
  query_t *qr = sqs->sqs_query;
  select_node_t *sel = qr->qr_select_node;
  union_node_t *uni = (union_node_t *) (IS_QN (qr->qr_head_node, union_node_input) ? qr->qr_head_node : NULL);
  int inx, n_res;
  if (!sqs->src_gen.src_out_fill)
    return;
  if (uni)
    {
      int nth = unbox (qst_get (inst, uni->uni_nth_output)) - 1;
      sel = ((query_t *) dk_set_nth (uni->uni_successors, nth))->qr_select_node;
    }
  n_res = QST_INT (inst, sel->src_gen.src_out_fill);
  QST_INT (inst, sqs->src_gen.src_out_fill) = 0;
  for (inx = 0; inx < n_res; inx++)
    {
      int set = qst_vec_get_int64 (inst, sel->sel_set_no, inx);
      qn_result ((data_source_t *) sqs, inst, set);
    }
}

void
subq_node_vec_input (subq_source_t * sqs, caddr_t * inst, caddr_t * state)
{
  int n_res;
  caddr_t err;
  QNCAST (query_instance_t, qi, inst);
  query_t *qr = sqs->sqs_query;
  union_node_t *uni = (union_node_t *) (IS_QN (qr->qr_head_node, union_node_input) ? qr->qr_head_node : NULL);
  int flag, inx;
  data_col_t *set_nos = QST_BOX (data_col_t *, inst, sqs->sqs_set_no->ssl_index);
  select_node_t *sel = qr->qr_select_node;
  int n_sets = sqs->src_gen.src_prev ? QST_INT (inst, sqs->src_gen.src_prev->src_out_fill) : qi->qi_n_sets;

  for (;;)
    {
      if (state)
	{
	  subq_init (sqs->sqs_query, state);
	  SRC_IN_STATE (sqs, inst) = inst;
	  flag = CR_INITIAL;
	  dc_reset (set_nos);
	  for (inx = 0; inx < n_sets; inx++)
	    dc_append_int64 (set_nos, inx);
	}
      else
	flag = CR_OPEN;
      if (!uni)
	QST_INT (inst, sel->src_gen.src_out_fill) = 0;
      else
	{
	  DO_SET (query_t *, uni_q, &uni->uni_successors)
	  {
	    if (uni_q->qr_select_node->src_gen.src_out_fill)	/* except or intersect 1st term has no vectored select, so not inited */
	      QST_INT (inst, uni_q->qr_select_node->src_gen.src_out_fill) = 0;
	  }
	  END_DO_SET ();
	}
      qi->qi_set_mask = NULL;
      qi->qi_n_sets = set_nos->dc_n_values;
      err = subq_next (sqs->sqs_query, inst, flag);
      flag = CR_OPEN;
      if (IS_BOX_POINTER (err))
	sqlr_resignal (err);
      if ((caddr_t) SQL_NO_DATA_FOUND == err)
	{
	  SRC_IN_STATE (sqs, inst) = NULL;
	  return;
	}
      if (uni)
	{
	  int nth = unbox (qst_get (inst, uni->uni_nth_output)) - 1;
	  sel = ((query_t *) dk_set_nth (uni->uni_successors, nth))->qr_select_node;
	}
      n_res = QST_INT (inst, sel->src_gen.src_out_fill);
      QST_INT (inst, sqs->src_gen.src_out_fill) = 0;
      for (inx = 0; inx < n_res; inx++)
	{
	  int set = qst_vec_get_int64 (inst, sel->sel_set_no, inx);
	  qn_result ((data_source_t *) sqs, inst, set);
	}
      if (QST_INT (inst, sqs->src_gen.src_out_fill))
	{
	  SRC_IN_STATE (sqs, inst) = inst;
	  qn_send_output ((data_source_t *) sqs, inst);
	}
      state = NULL;
    }
}


void
outer_seq_end_vec_input (outer_seq_end_node_t * ose, caddr_t * inst, caddr_t * state)
{
  data_col_t *nos_dc;
  int n_sets = QST_INT (inst, ose->src_gen.src_prev->src_out_fill);
  int set, inx;
  db_buf_t bits = (db_buf_t) QST_GET_V (inst, ose->ose_bits);
  int n_in_sctr;
  set_ctr_node_t *sctr = ose->ose_sctr;
  n_in_sctr = QST_INT (inst, sctr->src_gen.src_out_fill);
  if (!bits || box_length (bits) < ALIGN_8 (n_in_sctr) / 8)
    GPF_T1 ("in outer seq end, inner bit mask  too short");
  QST_INT (inst, ose->src_gen.src_out_fill) = 0;
  nos_dc = QST_BOX (data_col_t *, inst, ose->ose_set_no->ssl_index);
  for (set = 0; set < n_sets; set += 64)
    {
      int set2, upper = MIN (n_sets, set + 64);
      int sets[64];
      sslr_n_consec_ref (inst, (state_slot_ref_t *) ose->ose_set_no, sets, set, upper - set);
      for (set2 = set; set2 < upper; set2++)
	{
	  int no = ((int64 *) nos_dc->dc_values)[sets[set2 - set]];
	  bits[no >> 3] |= 1 << (no & 7);
	  qn_result ((data_source_t *) ose, inst, no);
	}
    }
  DO_BOX (state_slot_t *, out, inx, ose->ose_out_shadow)
  {
    state_slot_t *ssl = ose->ose_out_slots[inx];
    data_col_t *out_dc, *shadow_dc;
    int len;
    if (!out)
      continue;
    out_dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
    shadow_dc = QST_BOX (data_col_t *, inst, ose->ose_out_shadow[inx]->ssl_index);
    len = dc_elt_size (out_dc);
    dc_reset (shadow_dc);
      if (shadow_dc->dc_dtp != out_dc->dc_dtp)
	{
	  if (DV_ANY == out_dc->dc_dtp)
	    dc_heterogenous (shadow_dc);
	  else
	    dc_convert_empty (shadow_dc, out_dc->dc_dtp);
	}
    DC_CHECK_LEN (shadow_dc, n_sets - 1);
    shadow_dc->dc_n_values = n_sets;
    if (out_dc->dc_nulls)
      dc_ensure_null_bits (shadow_dc);
    for (set = 0; set < n_sets; set++)
      {
	int sinx = sslr_set_no (inst, ssl, set);
	if (DCT_BOXES & shadow_dc->dc_type)
	  ((caddr_t *) shadow_dc->dc_values)[set] = box_copy_tree (((caddr_t *) out_dc->dc_values)[sinx]);
	else
	  {
	    memcpy_16 (shadow_dc->dc_values + len * set, out_dc->dc_values + len * sinx, len);
	    if (out_dc->dc_nulls)
	      {
		if (DC_IS_NULL (out_dc, sinx))
		  DC_SET_NULL (shadow_dc, set);
	      }
	  }
      }
  }
  END_DO_BOX;
  if (n_sets)
    qn_send_output ((data_source_t *) ose, inst);
}


void
del_vec_log (delete_node_t * del, ins_key_t * ik, it_cursor_t * itc)
{
  caddr_t * inst = itc->itc_out_state;
  int nth = 0, inx, save_set = ((query_instance_t *) (itc->itc_out_state))->qi_set;
  dbe_key_t *key = ik->ik_key;
  LOCAL_RD (rd);
  rd.rd_key = key;
  rd.rd_itc = itc;
  /* loop from initial set to n to get all dc values */
  for (inx = 0; inx < itc->itc_n_sets; inx++)
    {
      for (nth = 0; nth < key->key_n_significant; nth++)
	{
	  state_slot_t *ssl = ik->ik_del_cast[nth] ? ik->ik_del_cast[nth] : ik->ik_del_slots[nth];
	    if (ik->ik_del_cast[nth])
	      {
		/* it can happen that the cast ssl is not used if the source is not a ref and types already match */
		data_col_t * cast_dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
		if (!cast_dc->dc_n_values)
		  ssl = ik->ik_del_slots[nth];
	      }
	    ((query_instance_t*)(itc->itc_out_state))->qi_set = itc->itc_param_order[inx];
	  rd.rd_values[key->key_part_cls[nth]->cl_nth] = QST_GET (itc->itc_out_state, ssl);
	}
      rd.rd_n_values = nth;
	log_delete (itc->itc_ltrx, &rd, ik->ik_key->key_partition ? LOG_KEY_ONLY : 0);
    }
  ((query_instance_t *) (itc->itc_out_state))->qi_set = save_set;
}


#if 0 /* check consistent delete */
#define RQ_CHECK_TEXT "select count (*) from orders a table option (index c_o_ck) where not exists (select 1 from orders b table option (loop, index orders)  where a.o_orderkey = b.o_orderkey)"

extern int rq_check_min, rq_check_mod, rq_check_ctr, rq_batch_sz;

void
ord_check (query_instance_t * qi)
{
  int n = -1, bs;
  caddr_t err = NULL;
  static query_t * qr;
  local_cursor_t * lc = NULL;
  if (!qr)
    {
      qr = sql_compile (RQ_CHECK_TEXT, bootstrap_cli, &err, SQLC_DEFAULT);
    }
  rq_check_ctr++;
  if (rq_check_ctr < rq_check_min
      || (rq_check_ctr % rq_check_mod) != 0)
    return;
  bs = dc_batch_sz;
  dc_batch_sz = rq_batch_sz;
  qr_rec_exec (qr, qi->qi_client, &lc, qi, NULL, 0);
  if (lc)
    {
      lc_next (lc);
      dc_batch_sz = bs;
      n = unbox (lc_nth_col (lc, 0));
      lc_free (lc);
    }
  if (n)
    {
      bing ();
      sqlr_new_error ("xxxxx", ".....", "orders del oow %d", (int)n);
    }
}
#endif

void
cl_local_deletes (delete_node_t * del, caddr_t * inst, caddr_t * part_inst)
{
  it_cursor_t itc_auto;
  it_cursor_t *itc = &itc_auto;
  int inx, inx2;
  key_source_t ks;
  QNCAST (query_instance_t, qi, inst);
  cl_slice_t * prev_csl = qi->qi_client->cli_csl;
  v_out_map_t * om, *empty_om;
  caddr_t *omx[(sizeof (v_out_map_t) / sizeof (caddr_t)) + 4];
  caddr_t e_omx[4];
  int n_sets = QST_INT (inst, del->src_gen.src_prev->src_out_fill);
  memset (&ks, 0, sizeof (ks));
  ITC_INIT (itc, NULL, qi->qi_trx);
  itc->itc_out_state = inst;
  itc->itc_ks = &ks;
  ks.ks_ts = (table_source_t *) del;
  ks.ks_is_deleting = 1;
  ks.ks_param_nos = del->del_param_nos;
  BOX_AUTO_TYPED (v_out_map_t *, om, omx, sizeof (v_out_map_t), DV_BIN);
  ks.ks_v_out_map = om;
  memset (om, 0, sizeof (v_out_map_t));
  om->om_ref = dc_itc_delete;
  BOX_AUTO_TYPED (v_out_map_t *, empty_om, e_omx, 0, DV_BIN);
  ks.ks_vec_asc_eq = 1;
  itc->itc_lock_mode = PL_EXCLUSIVE;
  DO_BOX (ins_key_t *, ik, inx, del->del_keys)
  {
    if (!ik)
      continue;
      itc->itc_isolation = ISO_SERIALIZABLE == qi->qi_isolation ? ISO_SERIALIZABLE : ISO_REPEATABLE;
    itc_free_owned_params (itc);
      itc_col_free (itc);
      itc->itc_insert_key = ik->ik_key;
      ks.ks_v_out_map = itc->itc_v_out_map = ik->ik_key->key_is_col ? empty_om : om;
      ITC_START_SEARCH_PARS (itc);
      DO_BOX (state_slot_t *, ssl, inx2, ik->ik_del_slots)
	{
	  data_col_t * source_dc = QST_BOX (data_col_t *, inst, ik->ik_del_slots[inx2]->ssl_index);
	  dc_val_cast_t f = ik->ik_del_cast_func[inx2];
	  char is_vec = SSL_IS_VEC_OR_REF (ssl);
	  if (!f && is_vec && DV_ANY != source_dc->dc_dtp && ik->ik_del_cast[inx2] && DV_ANY == ik->ik_del_cast[inx2]->ssl_sqt.sqt_dtp)
	    f = vc_to_any (source_dc->dc_dtp);

	  if (SSL_VEC != ssl->ssl_type || f)
	    {
	      data_col_t * target_dc = QST_BOX (data_col_t *, inst, ik->ik_del_cast[inx2]->ssl_index);
	      ITC_P_VEC (itc, inx2) = target_dc;
	      itc_vec_box (itc, target_dc->dc_dtp, inx2, target_dc);
	    }
	  else
	    {
	      ITC_P_VEC (itc, inx2) = source_dc;
	      itc_vec_box (itc, source_dc->dc_dtp, inx2, source_dc);
	    }
	}
      END_DO_BOX;
    itc->itc_search_mode = (ik->ik_key->key_is_bitmap || ik->ik_key->key_is_col) ? SM_READ : SM_READ_EXACT;
    itc->itc_insert_key = ik->ik_key;
    ks.ks_key = ik->ik_key;
      ks.ks_row_check = ks.ks_key->key_is_col ? itc_col_row_check_dummy
	: ks.ks_key->key_is_bitmap ? itc_bm_vec_row_check : itc_vec_row_check;
    ks.ks_n_vec_sort_cols = BOX_ELEMENTS (ik->ik_del_slots);
      itc->itc_n_sets = n_sets;
      itc->itc_n_results = 0;
      itc->itc_set = 0;
      itc->itc_key_spec = ks.ks_spec = ik->ik_key->key_insert_spec;
      if (ks.ks_key->key_is_col)
	itc->itc_v_out_map = NULL;
	{
	  itc_from_keep_params (itc, itc->itc_insert_key, qi->qi_client->cli_slice);
	  itc_param_sort (&ks, itc, ik->ik_key->key_not_null);
	  if (!itc->itc_n_sets)
	    continue;
	  itc_set_param_row (itc, 0);
	  ITC_FAIL (itc)
	  {
	    buffer_desc_t * buf = itc_reset (itc);
	    if (ks.ks_key->key_is_col)
	      itc->itc_v_out_map = NULL;
	    itc_vec_next (itc, &buf);
	    itc_page_leave (itc, buf);
	    if (itc->itc_is_col)
	      itc_col_free (itc);
	    if (REPL_NO_LOG != qi->qi_trx->lt_replicate && (ik->ik_key->key_is_primary || ik->ik_key->key_partition))
	      del_vec_log (del, ik, itc);
	  }
	  ITC_FAILED
	    {
	    }
	  END_FAIL (itc);

	}
    }
  END_DO_BOX;
  itc_free_owned_params (itc);
  itc_col_free (itc);
  qi->qi_n_affected += n_sets;
  if (qi->qi_client->cli_row_autocommit)
    qi->qi_client->cli_n_to_autocommit += n_sets;
}


void
dbg_del_check (data_col_t * source_dc, int source_row)
{
  caddr_t box = dc_box (source_dc, source_row);
  if (DV_IRI_ID == DV_TYPE_OF (box) && 7000064 == *(long*)box)
    bing ();
  dk_free_tree (box);
}

#define   CL_AC_RESET_CK(is_reset, del, qi) \
{ \
  if (del->cms.cms_clrg && qi->qi_client->cli_n_to_autocommit > dc_batch_sz) \
    { \
      qi->qi_client->cli_n_to_autocommit = 0; \
      is_reset = 1; \
    } \
}

void
delete_node_vec_run (delete_node_t * del, caddr_t * inst, caddr_t * state, int in_update)
{
  int inx, inx2, row;
  cl_req_group_t * clrg = NULL;
  QNCAST (query_instance_t, qi, inst);
  int n_sets = QST_INT (inst, del->src_gen.src_prev->src_out_fill), is_reset = 0, any_cl = 0;
  int is_replica = 0;
  if (del->del_is_view)
    {
      qi->qi_n_affected+= n_sets;
      return;
    }
  if (-1 == (ptrlong)del->del_keys || is_replica)
    return;
  DO_BOX (ins_key_t *, ik, inx, del->del_keys)
    {
      if (!ik)
	continue;
    DO_BOX (state_slot_t *, ssl, inx2, ik->ik_del_slots)
    {
	  data_col_t * source_dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
	  char is_vec = SSL_IS_VEC_OR_REF (ssl);
	  int elt_sz = is_vec ? dc_elt_size (source_dc) : -1;
      dc_val_cast_t f = ik->ik_del_cast_func[inx2];
	  data_col_t * target_dc = NULL;
	  if (ik->ik_del_cast[inx2])
	    {
	      /* there can be a target dc for value cast but it may not get used if the source has the right type and is not a ref.  Anyway must reset it even if not using because logging checks this */
	      target_dc = QST_BOX (data_col_t *, inst, ik->ik_del_cast[inx2]->ssl_index);
	      dc_reset (target_dc);
	    }
	  if (!f && is_vec && DV_ANY != source_dc->dc_dtp && ik->ik_del_cast[inx2] && DV_ANY == ik->ik_del_cast[inx2]->ssl_sqt.sqt_dtp)
	f = vc_to_any (source_dc->dc_dtp);

	  if (SSL_VEC != ssl->ssl_type || f)
	{
	  caddr_t err = NULL;
	  DC_CHECK_LEN (target_dc, n_sets - 1);
	  for (row = 0; row < n_sets; row++)
	    {
	      int source_row = row;
	      QNCAST (state_slot_ref_t, ref, ssl);
	      int step, n_values;
	      if (SSL_REF == ssl->ssl_type)
		{
		  for (step = 0; step < ref->sslr_distance; step++)
		    {
		      int *set_nos = (int *) inst[ref->sslr_set_nos[step]];
		      source_row = set_nos[source_row];
		    }
		}
		  else if (SSL_VEC != ssl->ssl_type)
		    {
		      qi->qi_set = row;
		      dc_append_box (target_dc, qst_get (inst, ssl));
		      continue;
		    }
	      n_values = target_dc->dc_n_values;
	      if (dc_is_null (source_dc, source_row))
		dc_append_null (target_dc);
	      else
		{
		      /*dbg_del_check (source_dc, source_row);*/
		  if (f)
		    {
		      f (target_dc, source_dc, source_row, &err);
		      if (err)
			sqlr_resignal (err);
		    }
		  else
			{
			  if (target_dc->dc_type & DCT_BOXES)
			    ((caddr_t*)target_dc->dc_values)[target_dc->dc_n_values] = box_copy_tree (((caddr_t*)source_dc->dc_values)[source_row]);
			  else
			memcpy_16 (target_dc->dc_values + elt_sz * target_dc->dc_n_values, source_dc->dc_values + source_row * elt_sz, elt_sz);
			}
		  target_dc->dc_n_values = n_values + 1;
		}
	    }
	}
	}
      END_DO_BOX;
    }
    END_DO_BOX;
  cl_local_deletes (del, inst, clrg ? clrg->clrg_inst : inst);
  if (!in_update && qi->qi_client->cli_row_autocommit)
    qi->qi_client->cli_n_to_autocommit += n_sets;
  if (!in_update)
    CL_AC_RESET_CK (is_reset, del, qi);
  if (is_reset)
    longjmp_splice (qi->qi_thread->thr_reset_ctx, RST_ENOUGH);
}


void update_node_run_1 (update_node_t * upd, caddr_t * inst, caddr_t * state);

void
update_node_vec_run (update_node_t * upd, caddr_t * inst, caddr_t * state)
    {
  db_buf_t sets_save;
  cl_req_group_t * clrg = NULL;
  QNCAST (query_instance_t, qi, inst);
  cl_slice_t * prev_csl = qi->qi_client->cli_csl;
  int k, set, is_reset = 0;
  dbe_table_t *tb = upd->upd_table;
  insert_node_t insd;
  delete_node_t deld;
  delete_node_t * del = &deld;
  insert_node_t * ins = &insd;
  it_cursor_t auto_itc;
  it_cursor_t *itc;
  int inx;
  int n_sets = upd->src_gen.src_prev ? QST_INT (inst, upd->src_gen.src_prev->src_out_fill) : qi->qi_n_sets, is_replica = 0;
  caddr_t err = NULL;
  int64 n_aff = qi->qi_n_affected;
  LOCAL_RD (rd);
  if (upd->upd_is_view)
    return;
  LT_CHECK_RW (((query_instance_t *) inst)->qi_trx);
  itc = &auto_itc;
  memzero (ins, sizeof (insert_node_t));
  memzero (del, sizeof (delete_node_t));
  ins->src_gen = upd->src_gen;
  ins->ins_vec_source = upd->upd_vec_source;
  ins->ins_vec_cast = upd->upd_vec_cast;
  ins->ins_vec_cast_cl = upd->upd_vec_cast_cl;
  ins->ins_mode = INS_NORMAL;
  ITC_INIT (itc, QI_SPACE (inst), QI_TRX (inst));
  rd.rd_itc = itc;
  rd.rd_non_comp_max = PAGE_DATA_SZ;
  rd.rd_key = tb->tb_primary_key;
  itc->itc_insert_key = tb->tb_primary_key;
  DO_BOX (state_slot_t *, ssl, inx, ins->ins_vec_cast)
    {
      data_col_t * dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
      DC_CHECK_LEN (dc, n_sets - 1);
    }
  END_DO_BOX;

  if (qi->qi_set_mask)
    sqlr_new_error ("VECUP", "VECUP",  "vectored update node expects no set masks");
  DO_BOX (state_slot_ref_t *, ref, inx, upd->upd_vec_source)
    {
      ssl_insert_cast (ins, inst, inx, &err, &rd, 0, n_sets, 1);
      if (err)
	sqlr_resignal (err);
    }
  END_DO_BOX;
  del->del_keys = upd->upd_keys;
  del->del_table = upd->upd_table;
  del->cms = upd->cms;
  del->del_param_nos = upd->upd_param_nos;
  del->src_gen = upd->src_gen;
#if 0
  DO_BOX (ins_key_t *, ik, inx, del->del_keys)
    {
      if (!ik)
	continue;
      ik->ik_del_slots = box_copy (ik->ik_slots);
  }
  END_DO_BOX;
#endif
  delete_node_vec_run (del, inst, inst, 1);
  qi->qi_n_affected = n_aff; /* do not count del of keys */
  for (k = 0; k < BOX_ELEMENTS_INT (upd->upd_keys); k++)
    {
      ins_key_t * ik = upd->upd_keys[k];
      if (!upd->upd_keys[k])
	continue;
	{
	  key_vec_insert (ins, state, itc, upd->upd_keys[k]);
	  qi->qi_n_affected = n_aff;
	  itc_free_owned_params (itc);
	  itc_col_free (itc);
	}
    }
  qi->qi_n_affected = n_aff;
  if (itc->itc_siblings)
    {
      itc_free_box (itc, (caddr_t)itc->itc_siblings);
      itc->itc_siblings = NULL;
    }
 skip_2nd:
  if (upd->upd_pk_change)
    {
      qi->qi_n_affected += n_sets;
      return;
    }
  upd->upd_row_only = 1;
  if (upd->upd_table->tb_primary_key->key_is_col)
    {
      upd_col_pk (upd, inst);
    }
  else
    {
      for (set = 0; set < n_sets; set++)
	{
	  qi->qi_set = set;
	  update_node_run_1 (upd, inst, inst);
    }
}
  if (is_replica)
    qi->qi_n_affected = n_aff;
  if (qi->qi_client->cli_row_autocommit)
    qi->qi_client->cli_n_to_autocommit += n_sets;
  CL_AC_RESET_CK (is_reset, upd, qi);

  if (is_reset)
    longjmp_splice (qi->qi_thread->thr_reset_ctx, RST_ENOUGH);
}





/*
 *  sort.c
 *
 *  $Id$
 *
 *  SQL ORDER BY sort and DISTINCT
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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
#include "sqlopcod.h"
#include "sqlopcod.h"
#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "arith.h"


int
setp_comp_array (setp_node_t * setp, caddr_t * qst, caddr_t * left, state_slot_t ** right)
{
  int inx;
  dk_set_t is_rev = setp->setp_key_is_desc;
  _DO_BOX (inx, right)
    {
      collation_t * coll = setp->setp_keys_box[inx]->ssl_sqt.sqt_collation;
      caddr_t right_v;
      int rc;

      right_v = qst_get (qst, right[inx]);
      rc = cmp_boxes (left[inx], right_v, coll, coll);
      if (rc == DVC_UNKNOWN)
	{ /* GK: the NULLs sort high */
	  dtp_t dtp1 = DV_TYPE_OF (left[inx]);
	  dtp_t dtp2 = DV_TYPE_OF (right_v);

	  if (dtp1 == DV_DB_NULL)
	    {
	      if (dtp2 == DV_DB_NULL)
		rc = DVC_MATCH;
	      else
		rc = DVC_LESS;
	    }
	  else
	    rc = DVC_GREATER;
        }
      else if (DVC_NOORDER == rc)
        rc = DVC_UNKNOWN;
/*
        {
	  dtp_t dtp1 = DV_TYPE_OF (left[inx]);
	  dtp_t dtp2 = DV_TYPE_OF (right_v);
          if (dtp1 < dtp2)
            rc = DVC_LESS;
          else if (dtp1 > dtp2)
            rc = DVC_GREATER;
	}
*/
      if (is_rev && ORDER_DESC == (ptrlong) is_rev->data)
	DVC_INVERT_CMP (rc);
      if (rc != DVC_MATCH)
	return rc;
      is_rev = is_rev ? is_rev->next : NULL;

    }
  END_DO_BOX;
  return DVC_MATCH;
}


int
setp_key_comp (setp_node_t * setp, caddr_t * qst, state_slot_t ** left, state_slot_t ** right)
{
  int inx;
  dk_set_t is_rev = setp->setp_key_is_desc;
  DO_BOX (state_slot_t *, l, inx, left)
    {
      collation_t * coll = setp->setp_keys_box[inx]->ssl_sqt.sqt_collation;
      int rc = cmp_boxes (qst_get (qst, l), qst_get (qst, right[inx]), coll, coll);
      if (is_rev && ORDER_DESC == (ptrlong) is_rev->data)
	DVC_INVERT_CMP (rc);
      if (rc != DVC_MATCH)
	return rc;
      is_rev = is_rev ? is_rev->next : NULL;

    }
  END_DO_BOX;
  return DVC_MATCH;
}


int
mem_sort_dist_cmp (caddr_t * arr, caddr_t * new_row, int n_keys)
{
  /* 1 if eq, -1 if differs in first n_keys, if differs after that */
  int inx;
  if (!arr)
    return 0;
  DO_BOX (caddr_t, elt, inx, arr)
    {
      if (!box_equal (elt, new_row[inx]))
	return inx < n_keys ? -1 : 0;
    }
  END_DO_BOX;
  return 1;
}


int
setp_top_duplicate (caddr_t ** arr, int pos, int fill, caddr_t * new_row, int n_keys)
{
  int inx;
  if (!fill)
    return 0;
  for (inx = pos - 1; inx >= 0; inx--)
    {
      int rc = mem_sort_dist_cmp (arr[inx], new_row, n_keys);
      if (1 == rc)
	return 1;
      if (-1 == rc)
	break;
    }
  for (inx = pos; inx < fill; inx++)
    {
      int rc = mem_sort_dist_cmp (arr[inx], new_row, n_keys);
      if (1 == rc)
	return 1;
      if (-1 == rc)
	break;
    }
  return 0;
}


caddr_t *
setp_mem_sort_row (setp_node_t * setp, caddr_t * qst)
{
  int inx, n_keys = BOX_ELEMENTS (setp->setp_keys_box);
  caddr_t * row = (caddr_t *) dk_alloc_box ((n_keys + BOX_ELEMENTS (setp->setp_dependent_box)) * sizeof (caddr_t),
					    DV_ARRAY_OF_POINTER);
  for (inx = 0; inx < n_keys; inx++)
    row[inx] = box_copy_tree (qst_get (qst, setp->setp_keys_box[inx]));
  for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (setp->setp_dependent_box); inx++)
    row[inx + n_keys] = box_copy_tree (qst_get (qst, setp->setp_dependent_box[inx]));
  return row;
}


void
setp_mem_insert (setp_node_t * setp, caddr_t * qst, int pos, caddr_t ** arr, int fill, int set_no)
{
  caddr_t * new_row = NULL;
  QNCAST (query_instance_t, qi, qst);
  int n_keys = BOX_ELEMENTS (setp->setp_keys_box);
  int top = BOX_ELEMENTS (arr);
#ifdef DEBUG
  if ((pos < 0) || (pos >= top))
    GPF_T1 ("bad pos in setp_mem_insert");
#endif
  if (setp->setp_top_distinct)
    {
      new_row = setp_mem_sort_row (setp, qst);
      if (setp_top_duplicate (arr, pos, fill, new_row, n_keys))
	{
	  dk_free_tree (new_row);
	  return;
	}
    }
  if (fill == top)
    dk_free_tree ((caddr_t) arr[fill - 1]);
  else
    {
      int save = qi->qi_set;
      qi->qi_set = set_no;
    qst_set_long (qst, setp->setp_row_ctr, fill + 1);
      qi->qi_set = save;
    }
  if (pos < fill)
    memmove_16 (&arr[pos + 1], &arr[pos], sizeof (caddr_t) * (fill - pos - (fill == top ? 1 : 0)));
  if (!new_row)
    new_row = setp_mem_sort_row (setp, qst);
  arr[pos] = new_row;
}


long setp_top_row_limit = 10000;

void
setp_mem_sort (setp_node_t * setp, caddr_t * qst, int n_sets, int merge_set)
{
  /* accumulates one or more rows into a top order by.  If merge set is given, merging parallel branches, in which case the merge set is the set no of the oby temp, else the set no of the oby temp is taken from the setp ssa set no ref to the fref set no */
  int set, prev_set;
  QNCAST (query_instance_t, qi, qst);
  caddr_t ** arr;
  ptrlong top = unbox (qst_get (qst, setp->setp_top));
  ptrlong skip = setp->setp_top_skip ? unbox (qst_get (qst, setp->setp_top_skip)) : 0;
  ptrlong fill;
  ptrlong rc, guess, at_or_above, below;
  int skip_only = (top == -1 && skip >= 0 ? 1 : 0);

  if (skip < 0)
    sqlr_new_error ("22023", "SR351", "SKIP parameter < 0");
  if (skip_only)
    top = setp_top_row_limit - skip;
  if (top < 0)
    sqlr_new_error ("22023", "SR352", "TOP parameter < 0");
  if (top + skip == 0)
    return;
      if ((setp_top_row_limit < top) || (setp_top_row_limit < skip) || (setp_top_row_limit < top + skip))
	sqlr_new_error ("22023", "SR353",
	     "Sorted TOP clause specifies more then %ld rows to sort. "
	     "Only %ld are allowed. "
	     "Either decrease the offset and/or row count or use a scrollable cursor",
	     (long) (top + skip), setp_top_row_limit);

  if (!n_sets)
    {
      if (!setp->src_gen.src_prev)
	n_sets = 1;
      else
	n_sets = QST_INT (qst, setp->src_gen.src_prev->src_out_fill);
    }
  prev_set = -1;
  qi->qi_n_affected += n_sets;

  for (set = 0; set < n_sets; set++)
    {
      int set_no = merge_set != -1 ? merge_set : setp->setp_ssa.ssa_set_no ? qst_vec_get_int64 (qst, setp->setp_ssa.ssa_set_no, set) : 0;
      if (prev_set != set_no)
	{
	  qi->qi_set = set_no;
	  arr = (caddr_t **) qst_get (qst, setp->setp_sorted);
	  if (!arr)
	    {
      arr = (caddr_t **) dk_alloc_box (sizeof (caddr_t) * (top + skip), DV_ARRAY_OF_POINTER);
      memset (arr, 0, (top + skip) * sizeof (caddr_t));
      qst_set (qst, setp->setp_sorted, (caddr_t) arr);
	      qst_set_long (qst, setp->setp_row_ctr, 0);
    }
	  prev_set = set_no;
	}
      qi->qi_set = set_no;
      below = fill  = unbox (qst_get (qst, setp->setp_row_ctr));
      at_or_above = 0;
      qi->qi_set = set;
  if (fill == (top + skip) && DVC_GREATER != setp_comp_array (setp, qst, arr[fill - 1], setp->setp_keys_box))
	continue;
  if (!fill || DVC_GREATER == setp_comp_array (setp, qst, arr[0], setp->setp_keys_box))
    {
	  setp_mem_insert (setp, qst, 0, arr, (int) fill, set_no);
	  continue;
    }
  guess = fill / 2;
  for (;;)
    {
      rc = setp_comp_array (setp, qst, arr[guess], setp->setp_keys_box);
      if (below - guess <= 1)
	{
	  if (DVC_MATCH == rc || DVC_LESS == rc || (guess < 0) /* safety */)
            {
              if ((guess >= (top + skip - 1)) || (guess >= fill)) /* safety check if comparisons are not transitive: */
		    goto next_set;
	      guess++;
            }
	      setp_mem_insert (setp, qst, (int) guess, arr, (int) fill, set_no);
	      goto next_set;
	}
      if (DVC_LESS == rc || DVC_MATCH == rc)
	at_or_above = guess;
      else
	below = guess;
      guess = at_or_above + ((below - at_or_above) / 2);
    }
    next_set: ;
    }
}


int
setp_top_pre (setp_node_t * setp, caddr_t * qst, int * is_ties_edge)
{
  int rc;
  if (!setp->setp_top)
    return 0;
  if (!setp->setp_keys_box)
    {
      setp->setp_keys_box = (state_slot_t **) dk_set_to_array (setp->setp_keys);
      setp->setp_dependent_box = (state_slot_t **) dk_set_to_array (setp->setp_dependent);
    }
  if (unbox (qst_get (qst, setp->setp_flushing_mem_sort)))
    return 0;
  if (!setp->setp_ties)
    {
      setp_mem_sort (setp, qst, 0, -1);
      return 1;
    }
  GPF_T1 ("with ties not supported");
  if (unbox (qst_get (qst, setp->setp_row_ctr)) <= unbox (qst_get (qst, setp->setp_top)))
    return 0;
  rc = setp_key_comp (setp, qst, setp->setp_keys_box, setp->setp_last_vals);
  if (DVC_GREATER == rc)
    return 1;
  if (!setp->setp_ties && DVC_MATCH == rc)
    {
      *is_ties_edge = 1;
      return 1;
    }
  return 0;
}


int
setp_node_run (setp_node_t * setp, caddr_t * inst, caddr_t * state, int print_blobs)
{
  QNCAST (query_instance_t, qi, inst);
  int is_ties_edge = 0;
  if (HA_FILL == setp->setp_ha->ha_op)
    {
      itc_ha_feed_ret_t ihfr;
      if (!setp->src_gen.src_sets)
      itc_ha_feed (&ihfr, setp->setp_ha, inst, 0);
      else
	{
	  int set, n_sets;
	  /* can be first in a qf, so no prev if filling replicated hash */
	  n_sets = setp->src_gen.src_prev ? QST_INT (inst, setp->src_gen.src_prev->src_out_fill) : qi->qi_n_sets;
	  if (enable_chash_join)
	    {
	      setp_chash_fill (setp, inst);
	      return 1; /* XXX: check with Orri */
	    }
	  for (set = 0; set < n_sets; set++)
	    {
	      qi->qi_set = set;
	      itc_ha_feed (&ihfr, setp->setp_ha, inst, 0);
	    }
	}
	return DVC_MATCH;
    }
  if (setp->setp_distinct)
    {
      itc_ha_feed_ret_t ihfr;
      if (!setp->src_gen.src_out_fill)
	return DVC_MATCH != itc_ha_feed (&ihfr, setp->setp_ha, inst, 0);
      else
	{
	  int set, n_sets = QST_INT (inst, setp->src_gen.src_prev->src_out_fill);
	  QST_INT (inst, setp->src_gen.src_out_fill) = 0;
	  if (setp_chash_distinct (setp, inst))
	    return QST_INT (inst, setp->src_gen.src_out_fill);
	  for (set = 0; set < n_sets; set++)
	    {
	      int match = 0;
	      qi->qi_set = set;
	      if (SETP_DISTINCT_NO_OP != setp->setp_distinct)
	      match = DVC_MATCH == itc_ha_feed (&ihfr, setp->setp_ha, inst, 0);
	      if (setp->setp_set_op == INTERSECT_ST || setp->setp_set_op == INTERSECT_ALL_ST)
		match = !match;
	      if (!match)
		qn_result ((data_source_t*)setp, inst, set);
	    }
    }
      return QST_INT (inst, setp->src_gen.src_out_fill);
    }
  if (setp->setp_top)
    {
      setp_top_pre (setp, state, &is_ties_edge);
    return 0;
    }
  if (setp->setp_ha->ha_op != HA_GROUP)
    {
      int set, n_sets;
      if (setp->src_gen.src_prev)
	n_sets = QST_INT (inst, setp->src_gen.src_prev->src_out_fill);
      else
	n_sets = 1;
      qi->qi_n_sets = n_sets;
      for (set = 0; set < n_sets; set++)
	{
	  qi->qi_set = set;
    setp_order_row (setp, inst);
	}
    }
  else
    {
      dk_set_t vals = setp->setp_const_gb_values;
      int set, n_sets;
      if (setp->src_gen.src_prev)
	n_sets = QST_INT (inst, setp->src_gen.src_prev->src_out_fill);
      else  if (!setp->setp_is_cl_gb_result)
	n_sets = 1; /* in cluster adding up of partitions the qi_n_sets gives the row count */
      else
	n_sets = qi->qi_n_sets;
      qi->qi_n_sets = n_sets;
      if (vals)
	{
	  /* inputs to group by counts etc must be variable ssls.  Set them here if the arg val is a const */
	  DO_SET (state_slot_t *, arg, &setp->setp_const_gb_args)
	    {
	      caddr_t val = ((state_slot_t*)vals->data)->ssl_constant;
	      if (SSL_VEC == arg->ssl_type && qi->qi_n_sets <= QST_BOX (data_col_t*, inst, arg->ssl_index)->dc_n_values)
		break;
	      qst_set_all (inst, arg, val);
	      if (SSL_VEC == arg->ssl_type)
		QST_BOX (data_col_t*, inst, arg->ssl_index)->dc_n_values = qi->qi_n_sets;

	      vals = vals->next;
	    }
	  END_DO_SET();
	}
      if (setp->setp_ha->ha_ch_len
	  && setp_chash_group (setp, inst))
	return 1;
      for (set = 0; set < n_sets; set++)
	{
	  qi->qi_set = set;
      setp_group_row (setp, inst);
    }
    }
  return 1;
}


void
setp_filled (setp_node_t * setp, caddr_t * qst)
{
  hash_area_t * ha = setp->setp_ha;
  if (HA_GROUP == ha->ha_op
      || HA_ORDER == ha->ha_op
      || HA_DISTINCT == ha->ha_op
      || HA_FILL == ha->ha_op)
    {
      it_cursor_t * ins_itc, * ref_itc;
#ifdef NEW_HASH
      it_cursor_t *bp_ref_itc;
#endif
      index_tree_t * it = (index_tree_t *) QST_GET (qst, ha->ha_tree);
      if (!it)
	return;
      ins_itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_insert_itc);
      ref_itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_ref_itc);
#ifdef NEW_HASH
      bp_ref_itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_bp_ref_itc);
#endif
      if (ins_itc && ins_itc->itc_hash_buf)
	{
	  page_leave_outside_map (ins_itc->itc_hash_buf);
	  ins_itc->itc_hash_buf = NULL;
	}
      if (ref_itc && ref_itc->itc_buf)
	{
	  page_leave_outside_map (ref_itc->itc_buf);
	  ref_itc->itc_buf = NULL;
	}
#ifdef NEW_HASH
      if (bp_ref_itc && bp_ref_itc->itc_buf)
	{
	  page_leave_outside_map (bp_ref_itc->itc_buf);
	  bp_ref_itc->itc_buf = NULL;
	}
#endif

    }
}


void
qst_clr (caddr_t * inst, state_slot_t * ssl)
{
  if (SSL_IS_VEC_OR_REF (ssl))
    dc_reset (QST_BOX (data_col_t*, inst, ssl->ssl_index));
  else
    qst_set (inst, ssl, NULL);
}


void
setp_temp_clear (setp_node_t * setp, hash_area_t * ha, caddr_t * qst)
{
  it_cursor_t * ins_itc = (it_cursor_t*) QST_GET_V (qst, ha->ha_insert_itc);
  it_cursor_t * ref_itc = (it_cursor_t*) QST_GET_V (qst, ha->ha_ref_itc);
#ifdef NEW_HASH
  it_cursor_t * bp_ref_itc = (it_cursor_t*) QST_GET_V (qst, ha->ha_bp_ref_itc);
#endif
  index_tree_t * it;
  qst[ha->ha_insert_itc->ssl_index] = NULL;
  qst[ha->ha_ref_itc->ssl_index] = NULL;
#ifdef NEW_HASH
  qst[ha->ha_bp_ref_itc->ssl_index] = NULL;
#endif
  if (ins_itc)
    itc_free (ins_itc);
  if (ref_itc)
    itc_free (ref_itc);
#ifdef NEW_HASH
  if (bp_ref_itc)
    itc_free (bp_ref_itc);
#endif
  if (SSL_VEC == ha->ha_tree->ssl_type)
    {
      data_col_t * dc = QST_BOX (data_col_t *, qst, ha->ha_tree->ssl_index);
      dc_reset (dc);
    }
  else
    {
      it = (index_tree_t*) QST_GET_V (qst, ha->ha_tree);
      qst[ha->ha_tree->ssl_index] = NULL;
  if (it)
    it_temp_free (it);
    }
  if (!setp)
    return;
  if (setp->setp_sorted)
    qst_clr (qst, setp->setp_sorted);
  if (setp->setp_row_ctr)
    qst_clr (qst, setp->setp_row_ctr);
}


void
setp_mem_sort_flush (setp_node_t * setp, caddr_t * qst)
{
  caddr_t ** arr;
  int fill;
  if (!setp->setp_sorted || setp->setp_top)
    return;
  GPF_T1 ("mem sort flush not su[supposed to ne called");
  arr = (caddr_t **) qst_get (qst, setp->setp_sorted);
  fill = (int)  unbox (qst_get (qst, setp->setp_row_ctr));
  if (fill && arr)
    {
      int col;
      ptrlong row;
      int n_keys = BOX_ELEMENTS (setp->setp_keys_box);
      int n_deps = BOX_ELEMENTS (setp->setp_dependent_box);
      ptrlong skip = setp->setp_top_skip ? unbox (qst_get (qst, setp->setp_top_skip)) : 0;
      qst_set_long (qst, setp->setp_flushing_mem_sort, 1);
      for (row = 0; row < fill; row++)
	{
	  for (col = 0; col < n_keys; col++)
	    {
	      qst_set (qst, setp->setp_keys_box[col], arr[row][col]);
	      arr[row][col] = NULL;
	    }
	  for (col = 0; col < n_deps; col++)
	    {
	      qst_set (qst, setp->setp_dependent_box[col], arr[row][col + n_keys]);
	      arr[row][col + n_keys] = NULL;
	    }
	  if (skip)
	    {
	      skip--;
	      continue;
	    }
	  setp_node_run (setp, qst, qst, 0);
	}
      qst_set_long (qst, setp->setp_flushing_mem_sort, 0);
      qst_set_long (qst, setp->setp_row_ctr, 0);
    }
}


void
setp_node_input (setp_node_t * setp, caddr_t * inst, caddr_t * state)
{
  int cont = setp_node_run (setp, inst, state, 0);
  if (!setp->src_gen.src_out_fill && (setp->setp_set_op == INTERSECT_ST || setp->setp_set_op == INTERSECT_ALL_ST))
    cont = !cont;
  if (cont && !setp->setp_is_qf_last)
    qn_send_output ((data_source_t *) setp, state);
}


void
qr_union_reset (query_t * qr, dk_set_t nodes, caddr_t * inst)
{
  if (!nodes)
    nodes = qr->qr_nodes;
  DO_SET (data_source_t *, qn, &nodes)
    {
      if (IS_QN (qn, subq_node_input))
	{
	    QNCAST (subq_source_t, sqs, qn);
	    qr_union_reset (sqs->sqs_query, NULL, inst);
	}
    }
  END_DO_SET ();

  DO_SET (query_t *, subq, &qr->qr_subq_queries)
    {
      qr_union_reset (subq, NULL, inst);
    }
  END_DO_SET ();
}


void
union_node_input (union_node_t * un, caddr_t * inst, caddr_t * state)
{
  int inx;
  for (;;)
    {
      dk_set_t out_list = un->uni_successors;
      int nth;
      if (!state)
	{
	  state = qn_get_in_state ((data_source_t *) un, inst);
	  nth = (int) unbox (qst_get (state, un->uni_nth_output));
	}
      else
	{
	  qst_set (inst, un->uni_nth_output, box_num (0));
	  nth = 0;
	}
      for (inx = 0; inx < nth; inx++)
	{
	  if (out_list)
	    out_list = out_list->next;
	  if (!out_list)
	    break;
	}
      if (!out_list)
	{
	  qr_union_reset (un->src_gen.src_query, NULL, inst);
	  qn_record_in_state ((data_source_t *) un, inst, NULL);
	  qst_set (inst, un->uni_nth_output, box_num (0));
	  return;
	}
      qst_set (inst, un->uni_nth_output, box_num (nth + 1));
      qr_union_reset (un->src_gen.src_query, NULL, inst);
      qn_record_in_state ((data_source_t *) un, inst, inst);
      qn_input (((query_t *) out_list->data)->qr_head_node, inst, inst);
      if (!un->src_gen.src_query->qr_cl_run_started || CL_RUN_LOCAL == cl_run_local_only
	  || un->uni_sequential)
	qr_resume_pending_nodes ((query_t*) out_list->data, inst); /* only if not multistate */
      state = NULL;
      /* now for multistate union, if at full batch - 1 and all nodes have their inputs and have not yet started, flush them all and have the containing subnq then continue */
    }
}


void
subq_node_input (subq_source_t * sqs, caddr_t * inst, caddr_t * state)
{
  int any_passed = 0;
  int inx;
  caddr_t err;
  int flag;
  if (sqs->src_gen.src_sets)
    {
      subq_node_vec_input (sqs, inst, state);
      return;
    }
  for (;;)
    {
      if (!state)
	{
	  state = SRC_IN_STATE (sqs, inst);
	  flag = CR_OPEN;
	  any_passed = 1;
	}
      else
	{
	  subq_init (sqs->sqs_query, state);
	  SRC_IN_STATE (sqs, inst) = inst;
	  flag = CR_INITIAL;
	}
      err = subq_next (sqs->sqs_query, inst, flag);

      if (err == (caddr_t) SQL_NO_DATA_FOUND
	  && !any_passed && sqs->sqs_is_outer)
	{
	  /* no data on first call and outer node. Set to null and continue */
	  SRC_IN_STATE (sqs, inst) = NULL;
	  DO_BOX (state_slot_t *, out, inx, sqs->sqs_out_slots)
	  {
	    qst_set_bin_string (inst, out, (db_buf_t) "", 0, DV_DB_NULL);
	  }
	  END_DO_BOX;
	  qn_ts_send_output ((data_source_t *) sqs, inst,
	      sqs->sqs_after_join_test);
	  return;
	}

      if (err == SQL_SUCCESS)
	{
	  if (!sqs->src_gen.src_after_test
	      || code_vec_run (sqs->src_gen.src_after_test, inst))
	    {
	      any_passed = 1;
	      qn_ts_send_output ((data_source_t *) sqs, inst,
	          sqs->sqs_after_join_test);
	    }
	}
      else
	{
	  if (err != (caddr_t) SQL_NO_DATA_FOUND)
	    sqlr_resignal (err);
	  /* for anytime timeout, resignal the err while leaving the in state so anytime knows where to reset */
	  SRC_IN_STATE (sqs, inst) = NULL;
	  return;
	}
      state = NULL;
    }
}


void
breakup_node_input (breakup_node_t * brk, caddr_t * inst, caddr_t * state)
{
  QNCAST (query_instance_t, qi, inst);
  ptrlong current;
  int set, n_sets, oinx;
  int inx, n_per_set = BOX_ELEMENTS (brk->brk_output);
  int n_total = BOX_ELEMENTS (brk->brk_all_output);
  if (brk->src_gen.src_prev)
    n_sets = QST_INT (inst, brk->src_gen.src_prev->src_out_fill);
  else
    GPF_T1 ("breakup not vectored");
  for (;;)
    {
      QST_INT (inst, brk->src_gen.src_out_fill) = 0;
      if (state)
	{
	  inst[brk->brk_current_slot] = (caddr_t) 0;
	  if (n_total > n_per_set)
	    SRC_IN_STATE ((data_source_t *) brk, inst) = inst;
	}
      current = (ptrlong) inst[brk->brk_current_slot];
      current += n_per_set;
      inst[brk->brk_current_slot] = (caddr_t) current;
      if (current == n_total)
	SRC_IN_STATE ((data_source_t *) brk, inst) = NULL;
      if (current > n_total)
	return;
      DO_BOX (state_slot_t *, out, oinx, brk->brk_output) 
	dc_reset (QST_BOX (data_col_t *, inst, out->ssl_index));
      END_DO_BOX;
      for (set = 0; set < n_sets; set++)
	{
	  qi->qi_set = set;
	  if (unbox (qst_get (inst, brk->brk_all_output[current - 1])))
	    {
	      qn_result ((data_source_t *) brk, inst, set);
	      for (inx = 0; inx < n_per_set; inx++)
		{
		  if (ssl_is_settable (brk->brk_output[inx]))
		    qst_set (inst, brk->brk_output[inx], box_copy_tree (qst_get (inst, brk->brk_all_output[inx + current - n_per_set])));
		}
	    }
	}
      if (QST_INT (inst, brk->src_gen.src_out_fill))
	qn_send_output ((data_source_t *) brk, inst);
      state = NULL;
    }
}


void
breakup_node_free (breakup_node_t * brk)
{
  dk_free_box ((caddr_t) brk->brk_all_output);
  dk_free_box ((caddr_t) brk->brk_output);
}


void
iter_node_vec_input (data_source_t * qn, iter_node_t * in, caddr_t * inst, caddr_t * state, caddr_t * array)
{
  /* start or continue generic vectored iter. Calls continue when full. After all calls done, may have unsent outputs */
  QNCAST (query_instance_t, qi, inst);
  int all_same = QST_INT (inst, in->in_is_const);
  int nth_set, nth_val, batch;
  data_col_t * out_dc = QST_BOX (data_col_t *, inst, in->in_output->ssl_index);
  int n_sets = QST_INT (inst, qn->src_prev->src_out_fill);
 again:
  batch = QST_INT (inst, qn->src_batch_size);
  dc_reset (out_dc);
  QST_INT (inst, qn->src_out_fill) = 0;
  if (state)
    {
      nth_val = QST_INT (inst, in->in_current_value) = 0;
      nth_set = QST_INT (inst, in->in_current_set) = 0;
      if (all_same)
	{
	  qi->qi_set = 0;
	  qst_set (inst, in->in_vec_array, (caddr_t)array);
	}
    }
  else
    {
      if (all_same)
	{
	  qi->qi_set = 0;
	  array = (caddr_t*)qst_get (inst, in->in_vec_array);
	}
      nth_val = QST_INT (inst, in->in_current_value);
      nth_set = QST_INT (inst, in->in_current_set);
    }
  if (all_same)
    {
      for (nth_val = nth_val; nth_val < BOX_ELEMENTS (array); nth_val++)
	{
	  for (nth_set = nth_set; nth_set < n_sets; nth_set++)
	    {
	      if (QST_INT (inst, qn->src_out_fill) >= batch)
		{
		  SRC_IN_STATE (qn, inst) = inst;
		  QST_INT (inst, in->in_current_value) = nth_val;
		  QST_INT (inst, in->in_current_set) = nth_set;
		  qn_send_output (qn, inst);
		  state = NULL;
		  goto again;
		}
	      dc_append_box (out_dc, array[nth_val]);
	      qn_result (qn, inst, nth_set);
	    }
	  nth_set = 0;
	}
    }
  else
    {
      for (nth_set = nth_set; nth_set < n_sets; nth_set++)
	{
	  caddr_t *array;
	  qi->qi_set = nth_set;
	  array = (caddr_t*)qst_get (inst, in->in_vec_array);
	  for (nth_val = nth_val; nth_val < BOX_ELEMENTS (array); nth_val++)
	    {
	      if (QST_INT (inst, qn->src_out_fill) >= batch)
		{
		  SRC_IN_STATE (qn, inst) = inst;
		  QST_INT (inst, in->in_current_value) = nth_val;
		  QST_INT (inst, in->in_current_set) = nth_set;
		  qn_send_output (qn, inst);
		  state = NULL;
		  goto again;
		}
	      dc_append_box (out_dc, array[nth_val]);
	      qn_result (qn, inst, nth_set);
	    }
	  nth_val = 0;
	}
    }
  SRC_IN_STATE (qn, inst) = NULL;
  if (QST_INT (inst, qn->src_out_fill))
    qn_send_output (qn, inst);
}


void
in_iter_vec_input (in_iter_node_t * ii, caddr_t * inst, caddr_t * state)
{
  QNCAST (query_instance_t, qi, inst);
  int all_same = 1;
  int n_sets = QST_INT (inst, ii->src_gen.src_prev->src_out_fill);
  int set;

  if (!state)
    {
      iter_node_vec_input ((data_source_t*)ii, &ii->ii_iter, inst, NULL, NULL);
      return;
    }

  dc_reset (QST_BOX (data_col_t*, inst, ii->ii_iter.in_vec_array->ssl_index));
  for (set = 0; set < n_sets; set++)
    {
      caddr_t * arr = NULL;
      if (state)
	{
	  dk_set_t members = NULL;
	  int inx;
	  qi->qi_set = set;
	  inst[ii->ii_nth_value] = (caddr_t) 0;
	  DO_BOX (state_slot_t *, ssl, inx, ii->ii_values)
	    {
	      caddr_t vals = qst_get (inst, ssl), val;
	      int is_array = DV_ARRAY_OF_POINTER == DV_TYPE_OF (vals);
	      int nth, n_vals = is_array ? BOX_ELEMENTS (vals) : 1;
	      if (!qi_sets_identical (inst, ssl))
		all_same = 0;
	      for (nth = 0; nth < n_vals; nth++)
		{
		  val = is_array ? ((caddr_t*)vals)[nth] : vals;
		  DO_SET (caddr_t, member, &members)
		    {
		      if (DVC_MATCH == cmp_boxes (val, member, ii->ii_output->ssl_sqt.sqt_collation, ii->ii_output->ssl_sqt.sqt_collation))
			goto next;
		    }
		  END_DO_SET();
		  dk_set_push (&members, (void*) box_copy_tree (val));
		next: ;
		}
	    }
	  END_DO_BOX;
	  QST_INT (inst, ii->ii_iter.in_is_const) = all_same;
	  if (!members && all_same)
	    {
	      SRC_IN_STATE (ii, inst) = NULL;
	      qi->qi_set = set;
	      qst_set (inst, ii->ii_values_array, NULL);
	      return;
	    }
	  arr = (caddr_t*)list_to_array (dk_set_nreverse (members));
	  if (all_same)
	    {
	      iter_node_vec_input ((data_source_t*)ii, &ii->ii_iter, inst, state, arr);
	      return;
	    }
	  qst_set (inst, ii->ii_iter.in_vec_array, (caddr_t)arr);
	}
    }
  /* not all same */
  iter_node_vec_input ((data_source_t*)ii, &ii->ii_iter, inst, state, NULL);
}



void
in_iter_input (in_iter_node_t * ii, caddr_t * inst, caddr_t * state)
{
  ptrlong current, n_total;
  if (ii->src_gen.src_sets)
    {
      in_iter_vec_input (ii, inst, state);
      return;
    }
  for (;;)
    {
      caddr_t * arr = NULL;
      if (state)
	{
	  dk_set_t members = NULL;
	  int inx;
	  inst[ii->ii_nth_value] = (caddr_t) 0;
	  if (ii->ii_outer_any_passed)
	    qst_set (inst, ii->ii_outer_any_passed, NULL);
	  DO_BOX (state_slot_t *, ssl, inx, ii->ii_values)
	    {
	      caddr_t vals = qst_get (inst, ssl), val;
	      int is_array = DV_ARRAY_OF_POINTER == DV_TYPE_OF (vals);
	      int nth, n_vals = is_array ? BOX_ELEMENTS (vals) : 1;
	      for (nth = 0; nth < n_vals; nth++)
		{
		  val = is_array ? ((caddr_t*)vals)[nth] : vals;
		  DO_SET (caddr_t, member, &members)
		    {
		      if (DVC_MATCH == cmp_boxes (val, member, ii->ii_output->ssl_sqt.sqt_collation, ii->ii_output->ssl_sqt.sqt_collation))
			goto next;
		    }
		  END_DO_SET();
		  dk_set_push (&members, (void*) box_copy_tree (val));
		next: ;
		}
	    }
	  END_DO_BOX;
	  if (!members)
	    {
	      SRC_IN_STATE (ii, inst) = NULL;
	      qst_set (inst, ii->ii_values_array, NULL);
	      return;
	    }
	  arr = (caddr_t*)list_to_array (dk_set_nreverse (members));
	  qst_set (inst, ii->ii_values_array, (caddr_t)arr);
	  n_total = BOX_ELEMENTS (arr);
	  if (n_total > 1)
	    SRC_IN_STATE ((data_source_t *) ii, inst) = inst;
	  qst_set (inst, ii->ii_output, box_copy_tree (arr[0]));
	  qn_send_output ((data_source_t*) ii, inst);
	  state = NULL;
	  continue;
	}
      current = (ptrlong) inst[ii->ii_nth_value];
      current ++;
      inst[ii->ii_nth_value] = (caddr_t) current;
      arr = (caddr_t *) QST_GET (inst, ii->ii_values_array);
      if (current >= BOX_ELEMENTS (arr))
	{
	  SRC_IN_STATE ((data_source_t *) ii, inst) = NULL;
	  ri_outer_output ((rdf_inf_pre_node_t *) ii, ii->ii_outer_any_passed, inst);
		  return;
	}
      if (current == BOX_ELEMENTS (arr) - 1)
	SRC_IN_STATE ((data_source_t *) ii, inst) = NULL;
      qst_set (inst, ii->ii_output, box_copy_tree (arr[current]));
      qn_send_output ((data_source_t*) ii, inst);
      if (current == BOX_ELEMENTS (arr) - 1)
	{
	  ri_outer_output ((rdf_inf_pre_node_t *) ii, ii->ii_outer_any_passed, inst);
	  return;
	}
    }
}

void
in_iter_free (in_iter_node_t * ii)
{
  dk_free_box ((caddr_t) ii->ii_values);
}

void
sort_read_vec_input (table_source_t * ts, caddr_t * inst, caddr_t * state)
{
  QNCAST (query_instance_t, qi, inst);
  key_source_t * ks = ts->ts_order_ks;
  setp_node_t * setp = ts->ts_order_ks->ks_from_setp;
  int n_results = 0, last_set, batch;
  caddr_t ** arr;
  ptrlong top = unbox (qst_get (inst, setp->setp_top));
  ptrlong skip = setp->setp_top_skip ? unbox (qst_get (inst, setp->setp_top_skip)) : 0;
  ptrlong fill;
  int set, n_sets = QST_INT (inst, ts->src_gen.src_prev->src_out_fill);
  if (setp->setp_partitioned)
    {
      top += skip;
      skip = 0;
    }
  if (state)
    {
      QST_INT (inst, ts->clb.clb_nth_set) = 0;
      last_set = QST_INT (inst, ts->clb.clb_nth_set) = 0;
    }
 next_batch:
  batch = QST_INT (inst, ts->src_gen.src_batch_size);
  n_results = 0;
  ks_vec_new_results (ks, inst, NULL);
  last_set = QST_INT (inst, ts->clb.clb_nth_set);
  for (set = last_set; set < n_sets; set++)
    {
      data_col_t * dc;
      qi->qi_set = qst_vec_get_int64 (inst, ks->ks_set_no, set);
      if (qi->qi_set < 0 || qi->qi_set >= n_sets)
	{
	  qi->qi_set = 0;
	  sqlr_new_error ("MISCI", "SORTI",  "set no in reading top order by out of range..  Reprt the query to support");
	}
      dc = QST_BOX (data_col_t *, inst, setp->setp_sorted->ssl_index);
      if (dc->dc_n_values <= qi->qi_set)
	break;
      fill = unbox (qst_get (inst, setp->setp_row_ctr));
      arr = (caddr_t **) qst_get (inst, setp->setp_sorted);
      QST_INT (inst, ts->clb.clb_nth_set) = set;
      if (!arr)
	continue;
  if (state)
    QST_INT (inst, ks->ks_pos_in_temp) = skip;
  for (;;)
    {
      int nth = QST_INT (inst, ks->ks_pos_in_temp);
      int k_inx = 0, inx;
      if (nth >= fill)
	    goto next_set;
	  DO_BOX (state_slot_t *, ssl, inx, setp->setp_keys_box )
	{
	      if (!ts->ts_sort_read_mask[k_inx])
		{ /* not all sort temp cols may be output cols */
		  k_inx++;
		  continue;
	}
	      if (SSL_IS_VEC_OR_REF (ssl))
		dc_append_box (QST_BOX (data_col_t*, inst, ssl->ssl_index), arr[nth][k_inx]);
	      else
	{
	  qst_set (inst, ssl, arr[nth][k_inx]);
	  arr[nth][k_inx] = NULL;
		}
	  k_inx++;
	}
      END_DO_BOX;
      DO_BOX (state_slot_t *, ssl, inx, setp->setp_dependent_box)
	{
	      if (!ts->ts_sort_read_mask[k_inx])
		{
		  k_inx++;
		  continue;
		}
	      if (SSL_IS_VEC_OR_REF (ssl))
		dc_append_box (QST_BOX (data_col_t*, inst, ssl->ssl_index), arr[nth][k_inx]);
	      else
		{
	  qst_set (inst, ssl, arr[nth][k_inx]);
	  arr[nth][k_inx] = NULL;
		}
	  k_inx++;
	}
      END_DO_BOX;
	  qn_result ((data_source_t*)ts, inst, set);
      QST_INT (inst, ks->ks_pos_in_temp) = nth + 1;
	  if (++n_results == batch)
	    {
	      SRC_IN_STATE (ts, inst) = inst;
	      QST_INT (inst, ts->clb.clb_nth_set) = set;
	      ts_always_null (ts, inst);
	      qn_send_output ((data_source_t*)ts, inst);
	      state = NULL;
	      dc_reset_array (inst, (data_source_t*)ts, ts->src_gen.src_continue_reset, -1);
	      goto next_batch;
	    }
    }
    next_set:
      QST_INT (inst, ks->ks_pos_in_temp) = 0;
    }
  SRC_IN_STATE ((data_source_t*)ts, inst) = NULL;
  ts_always_null (ts, inst);
  if (QST_INT (inst, ts->src_gen.src_out_fill))
    qn_ts_send_output ((data_source_t *)ts, inst, ts->ts_after_join_test);
}


void
sort_read_input (table_source_t * ts, caddr_t * inst, caddr_t * state)
{
  ptrlong fill, skip, top;
  key_source_t * ks = ts->ts_order_ks;
  setp_node_t * setp = ts->ts_order_ks->ks_from_setp;
  caddr_t ** arr;
  if (ts->src_gen.src_out_fill)
    {
      sort_read_vec_input (ts, inst, state);
      return;
    }
  /* below never done, do not init the vars because the read of a dc might read past end and gpf */
  arr = (caddr_t **) qst_get (inst, setp->setp_sorted);
  top = unbox (qst_get (inst, setp->setp_top));
  skip = setp->setp_top_skip ? unbox (qst_get (inst, setp->setp_top_skip)) : 0;
  fill = unbox (qst_get (inst, setp->setp_row_ctr));
  if (setp->setp_partitioned)
	{
      top += skip;
      skip = 0;
	}
  if (!arr)
    {
      SRC_IN_STATE (ts, inst) = NULL;
    return;
    }
  if (state)
    QST_INT (inst, ks->ks_pos_in_temp) = skip;
  for (;;)
    {
      int nth = QST_INT (inst, ks->ks_pos_in_temp);
      int k_inx = 0, inx;
      if (nth >= fill)
	{
	  SRC_IN_STATE ((data_source_t *)ts, inst) = NULL;
	  return;
	}
      DO_BOX (state_slot_t *, ssl, inx, setp->setp_keys_box )
	{
	  qst_set (inst, ssl, arr[nth][k_inx]);
	  arr[nth][k_inx] = NULL;
	  k_inx++;
	}
      END_DO_BOX;
      DO_BOX (state_slot_t *, ssl, inx, setp->setp_dependent_box)
	{
	  qst_set (inst, ssl, arr[nth][k_inx]);
	  arr[nth][k_inx] = NULL;
	  k_inx++;
	}
      END_DO_BOX;
      QST_INT (inst, ks->ks_pos_in_temp) = nth + 1;
      SRC_IN_STATE ((data_source_t*)ts, inst) = inst;
      qn_ts_send_output ((data_source_t *)ts, inst, ts->ts_after_join_test);
    }
}


void
ose_send_rows (outer_seq_end_node_t * ose, caddr_t * inst)
{
  GPF_T1 ("ose non vectored");
}


void
outer_seq_end_input (outer_seq_end_node_t * ose, caddr_t * inst, caddr_t * state)
{
  /* if there is input, this means that there is a set.  If there is a gap in the set no sequence, then send as many sets with nulls for the outer join rows, then the row itself *
   * If getting a continue, send the next due null row and if sending last null row, set the ose to have no more continue state  */
  if (ose->src_gen.src_prev)
    {
      outer_seq_end_vec_input (ose, inst, state);
      return;
    }
  if (state)
    {
      int set_no = unbox (QST_GET_V (inst, ose->ose_set_no));
      int prev_set_no = unbox (QST_GET_V (inst, ose->ose_prev_set_no));
      if (set_no - prev_set_no > 1)
	{
	  /* put so many null rows in between for the outer rows not produced */
	  int inx;
	  caddr_t * buf = (caddr_t *) dk_alloc_box (BOX_ELEMENTS (ose->ose_out_slots) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  DO_BOX (state_slot_t *, out, inx, ose->ose_out_slots)
	    {
	      buf[inx] = box_copy_tree (qst_get (inst, out));
	    }
	  END_DO_BOX;
	  qst_set (inst, ose->ose_buffered_row, (caddr_t)buf);
	  QST_INT (inst, ose->ose_last_outer_set) = set_no - 1;
	  ose_send_rows (ose, inst);
	  return;
	}
      else
	{
	  qst_set_long (inst, ose->ose_prev_set_no, set_no);
	  SRC_IN_STATE ((data_source_t *)ose, inst) = NULL;
	  qn_send_output ((data_source_t*) ose, inst);
	}
    }
  else
    ose_send_rows (ose, inst);
}


void
ose_free (outer_seq_end_node_t * ose)
{
  dk_free_box ((caddr_t)ose->ose_out_slots);
  dk_free_box ((caddr_t)ose->ose_out_shadow);
}


void
sctr_continue_to_ose (set_ctr_node_t * sctr, caddr_t * inst)
{
  /* continue nodes between the set counter and the end of the outer seq so that the ose has got all the sets that were to come.  After this, the null sets are known and can be sent  */
  if (!sctr->sctr_ose)
    return;
 again:
  DO_SET (data_source_t *, qn, &sctr->sctr_continuable)
    {
      if (SRC_IN_STATE (qn, inst))
	{
	  qn->src_input (qn, inst, NULL);
	  goto again;
	}
    }
  END_DO_SET();
}

void
set_ctr_input (set_ctr_node_t * sctr, caddr_t * inst, caddr_t * state)
{
  /* the input increments the set no and continues next.  The continue resets this
   * and if outer, flushes the matching outer seq end */
  if (sctr->src_gen.src_sets)
    {
      set_ctr_vec_input (sctr, inst, state);
      return;
    }
  if (state)
    {
      query_instance_t * qi = (query_instance_t *)inst;
      cl_op_t * itcl_clo = (cl_op_t *)qst_get (inst, sctr->sctr_itcl);
      itc_cluster_t * itcl;
      boxint nth;
      if (!SRC_IN_STATE ((data_source_t *)sctr, inst))
	{
	  itcl_clo = clo_allocate (CLO_ITCL);
	  itcl_clo->_.itcl.itcl = itcl = itcl_allocate (qi->qi_trx, inst);
	  qst_set (inst, sctr->sctr_itcl, (caddr_t)itcl_clo);
	  nth = -1;
	  if (sctr->sctr_ose)
	    qst_set_long (inst, sctr->sctr_ose->ose_prev_set_no, -1);
	}
      else
	{
	  itcl = itcl_clo->_.itcl.itcl;
	  nth = unbox (QST_GET_V (inst, sctr->sctr_set_no));
	}
      QST_INT (inst, sctr->clb.clb_fill) = nth + 2;
      qst_set_long (inst, sctr->sctr_set_no, nth + 1);
      cl_select_save_env ((table_source_t *)sctr, itcl, inst, NULL, nth + 1);
      SRC_IN_STATE ((data_source_t*) sctr, inst) = inst;
      qn_send_output ((data_source_t *)sctr, inst);
      if (nth + 2 == sctr->clb.clb_batch_size)
	sctr_continue_to_ose (sctr, inst);
      else
	return;
    }
  {
    boxint nth = unbox (QST_GET_V (inst, sctr->sctr_set_no));
    SRC_IN_STATE ((data_source_t*) sctr, inst) = NULL;
    qst_set_long (inst, sctr->sctr_set_no, 0);
    if (sctr->sctr_ose)
      {
	outer_seq_end_node_t * ose = sctr->sctr_ose;
	int last = unbox (QST_GET_V (inst, ose->ose_prev_set_no));
	if (last < nth)
	  {
	    QST_INT (inst, ose->ose_last_outer_set) = nth;
	    qst_set (inst, ose->ose_buffered_row, NULL);
	    ose_send_rows (ose, inst);
	  }
	else
	  CLB_AT_END (sctr->clb, inst);
      }
    else
      CLB_AT_END (sctr->clb, inst);
  }
}


void
set_ctr_free (set_ctr_node_t * sctr)
{
  clb_free (&sctr->clb);
  dk_set_free (sctr->sctr_continuable);
  sp_list_free (sctr->sctr_hash_spec);
}


void
tssp_alt_init (ts_split_node_t * tssp)
{
  data_source_t * alt = (data_source_t*)tssp->tssp_alt_ts;
  data_source_t * main = qn_next ((data_source_t*)tssp);
  while (qn_next (alt))
    alt = qn_next (alt);
  alt->src_continuations = dk_set_cons (qn_next (main), NULL);
  alt->src_after_code =main->src_after_code;
  tssp->tssp_inited = 1;
}


void
ts_split_input (ts_split_node_t * tssp, caddr_t * inst, caddr_t * state)
{
  /* send sets with a string in tssp_v1 to tssp_alt and others to to successor */
  QNCAST (query_instance_t, qi, inst);
  int n_sets = QST_INT (inst, tssp->src_gen.src_prev->src_out_fill);
  int strings = 0, inx, is_str;
  if (!tssp->tssp_inited)
    tssp_alt_init (tssp);
 again:
  if (state)
    {
      strings = 0;
      SRC_IN_STATE (tssp, inst) = inst;
    }
  else
    {
      strings = 1;
      SRC_IN_STATE (tssp, inst) = NULL;
}
  QST_INT (inst, tssp->src_gen.src_out_fill) = 0;
  for (inx = 0; inx < n_sets; inx++)
    {
      caddr_t v;
      qi->qi_set = inx;
      v = qst_get (inst, tssp->tssp_v1);
      is_str = DV_STRINGP (v) || (DV_RDF == DV_TYPE_OF (v) && DV_STRINGP (((rdf_box_t*)v)->rb_box));
      if ((is_str && strings) || (!is_str && !strings))
	qn_result ((data_source_t*)tssp, inst, inx);
    }
  if (strings)
    {
      if (QST_INT (inst, tssp->src_gen.src_out_fill))
	qn_input ((data_source_t*)tssp->tssp_alt_ts, inst, inst);
}
  else
    {
      if (QST_INT (inst, tssp->src_gen.src_out_fill))
	qn_send_output ((data_source_t*)tssp, inst);
    }
  if (SRC_IN_STATE (tssp, inst))
    {
      state = NULL;
      goto again;
    }
}



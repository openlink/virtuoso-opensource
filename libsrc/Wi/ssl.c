/*
 *  $Id$
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

state_slot_t *
ssl_with_info (comp_context_t * cc, state_slot_t * ssl)
{
  cc = cc->cc_super_cc;
  if (!cc->cc_keep_ssl)
    cc->cc_keep_ssl = hash_table_allocate (11);
  sethash ((void*) ssl, cc->cc_keep_ssl, (void*) ssl);
  return ssl;
}


dk_hash_t * ssl_stock;

state_slot_t *
ssl_get_stock (ptrlong inx)
{
  state_slot_t *ssl;
  if (!ssl_stock)
    ssl_stock = hash_table_allocate (101);
  ssl = (state_slot_t *) gethash ((void*) (ptrlong) inx, ssl_stock);
  if (ssl)
    return ssl;
  else
    {
      NEW_VARZ (state_slot_t, sl);
      sl->ssl_index = (ssl_index_t) inx;
      sl->ssl_name = box_string ("tmp");
      sl->ssl_type = SSL_VARIABLE;
      sl->ssl_dtp = DV_ANY;
      return sl;
    }
}

state_slot_t *
ssl_use_stock  (comp_context_t * cc, state_slot_t * ssl)
{
  cc = cc->cc_super_cc;

#if 0
  if (!cc->cc_keep_ssl)
    cc->cc_keep_ssl = hash_table_allocate (11);

  if (!ssl || !IS_REAL_SSL (ssl)  )
    return ssl;
  if (SSL_VARIABLE == ssl->ssl_type
      && !gethash ((void*) ssl, cc->cc_keep_ssl))
    return ssl_get_stock (ssl->ssl_index);
#endif

  return ssl;
}

#define STSSL(v) v = ssl_use_stock (cc, v)

#define STSSL_ARTM \
  STSSL (ins->_.artm.result); STSSL (ins->_.artm.left); STSSL (ins->_.artm.right)


void
ssl_use_stock_array (comp_context_t * cc, state_slot_t ** arr)
{
  int inx;
  if (!arr)
    return;
  DO_BOX (state_slot_t *, ssl, inx, arr)
    {
      arr[inx] = ssl_use_stock (cc, ssl);
    }
  END_DO_BOX;
}



void
stssl_sp (comp_context_t * cc, search_spec_t *sp)
{
  while (sp)
    {
      STSSL (sp->sp_min_ssl);
      STSSL (sp->sp_max_ssl);
      sp = sp->sp_next;
    }
}

#define stssl_arr(a) ssl_use_stock_array (cc, a)

void
stssl_list2 (comp_context_t * cc, dk_set_t it)
{
  while (it)
    {
      it->data = (void*)ssl_use_stock (cc, (state_slot_t *) it->data);
      it = it->next;
    }
}

void
stssl_ha (comp_context_t * cc, hash_area_t * ha)
{
  if (!ha)
    return;
  stssl_arr (ha->ha_slots);
}


#define stssl_list(l) stssl_list2(cc, l)


void
stssl_ks (comp_context_t * cc, key_source_t * ks)
{
  STSSL (ks->ks_proc_set_ctr);
  STSSL (ks->ks_from_temp_tree);
  STSSL (ks->ks_init_place);
  STSSL (ks->ks_grouping);
  stssl_sp (cc, ks->ks_spec.ksp_spec_array);
  stssl_sp (cc, ks->ks_row_spec);
  stssl_list (ks->ks_out_slots);
  stssl_cv (cc, ks->ks_local_code);
  stssl_cv (cc, ks->ks_local_test);
}


void
stssl_inx_op (comp_context_t * cc, inx_op_t * iop)
{
  STSSL (iop->iop_bitmap);
  if (iop->iop_ks)
    stssl_ks (cc, iop->iop_ks);
  stssl_arr (iop->iop_max);
  stssl_sp (cc, iop->iop_ks_start_spec.ksp_spec_array);
  stssl_sp (cc, iop->iop_ks_full_spec.ksp_spec_array);
  stssl_sp (cc, iop->iop_ks_row_spec);
  if (iop->iop_terms)
    {
      int inx;
      DO_BOX (inx_op_t *, term, inx, iop->iop_terms)
	{
	  stssl_inx_op (cc, term);
	}
      END_DO_BOX;
    }
}


#define IS_NODE(f, n) \
  ((qn_input_fn)f == ((data_source_t*) n)->src_input)

void
stssl_qnode (comp_context_t * cc, table_source_t * node)
{
  int inx;
  stssl_cv (cc, node->src_gen.src_pre_code);
  stssl_cv (cc, node->src_gen.src_after_code);
  stssl_cv (cc, node->src_gen.src_after_test);

  if (IS_TS (node))
    {
      table_source_t * ts = (table_source_t *) node;
      if (ts->ts_order_ks)
	stssl_ks (cc, ts->ts_order_ks);
      else
	{
	  stssl_inx_op (cc, ts->ts_inx_op);
	}
      if (ts->ts_main_ks)
	stssl_ks (cc, ts->ts_main_ks);
      stssl_cv (cc, ts->ts_after_join_test);
    }
  else if (IS_NODE (hash_source_input, node))
    {
      hash_source_t * hs = (hash_source_t *) node;
      stssl_arr (hs->hs_ref_slots);
      stssl_arr (hs->hs_out_slots);
      stssl_ha (cc, hs->hs_ha);
      stssl_cv (cc, hs->hs_after_join_test);
    }
  else if (IS_NODE (subq_node_input, node))
    {
      subq_source_t  * sqs = (subq_source_t *) node;
      stssl_query (cc, sqs->sqs_query);
      stssl_arr (sqs->sqs_out_slots);
      stssl_cv (cc, sqs->sqs_after_join_test);
    }
  else if (IS_RTS (node))
    {
      remote_table_source_t * rts = (remote_table_source_t *) node;
      stssl_list (rts->rts_out_slots);
      stssl_list (rts->rts_params);
      STSSL (rts->rts_remote_stmt);
      stssl_arr (rts->rts_trigger_args);
      STSSL (rts->rts_af_state);
      stssl_arr (rts->rts_save_env);
      STSSL (rts->rts_param_rows);
      STSSL (rts->rts_environments);
      STSSL (rts->rts_param_fill);
      STSSL (rts->rts_i_param);
      STSSL (rts->rts_single_pending);
      STSSL (rts->rts_single_env);
      stssl_cv (cc, rts->rts_after_join_test);
    }
  else if (IS_NODE (union_node_input, node))
    {
      union_node_t * un = (union_node_t *) node;
      STSSL (un->uni_nth_output);
      DO_SET (query_t *, qr, &un->uni_successors)
	{
	  stssl_query (cc, qr);
	}
      END_DO_SET ();
    }
  else if (IS_NODE (insert_node_input, node))
    {
      insert_node_t * ins = (insert_node_t *) node;
      stssl_list (ins->ins_values);
            stssl_arr (ins->ins_trigger_args);
	    DO_BOX (ins_key_t *, ik, inx, ins->ins_keys)
	      {
		stssl_arr (ik->ik_slots);
	      }
	    END_DO_BOX;
    }
  else if (IS_NODE (update_node_input, node))
    {
      update_node_t * upd = (update_node_t *) node;
      STSSL (upd->upd_place);
      stssl_arr (upd->upd_values);
      STSSL (upd->upd_cols_param);
      STSSL (upd->upd_values_param);
      stssl_arr (upd->upd_trigger_args);
    }
  else if (IS_NODE (delete_node_input, node))
    {
      delete_node_t * del = (delete_node_t *) node;
      STSSL (del->del_place);
      stssl_arr (del->del_trigger_args);
    }
  else if (IS_NODE (row_insert_node_input, node))
    {
      row_insert_node_t * rins = (row_insert_node_t *) node;
      STSSL (rins->rins_row);
    }
  else if (IS_NODE (key_insert_node_input, node))
    {
      key_insert_node_t * rins = (key_insert_node_t *) node;
      STSSL (rins->kins_row);
    }
  else if (IS_NODE (deref_node_input, node))
    {
      deref_node_t * dn = (deref_node_t *) node;
      STSSL (dn->dn_ref);
      STSSL (dn->dn_row);
      STSSL (dn->dn_place);
    }
  else if (IS_NODE (pl_source_input, node))
    {
      pl_source_t * pls = (pl_source_t *) node;
      STSSL (pls->pls_place);
      stssl_arr (pls->pls_values);
    }
  else if (IS_NODE (current_of_node_input, node))
    {
      current_of_node_t * co = (current_of_node_t*) node;
      STSSL (co->co_place);
      STSSL (co->co_cursor_name);
    }
  else if (IS_NODE (select_node_input, node) || IS_NODE (select_node_input_subq, node))
    {
      select_node_t * sel = (select_node_t *) node;
      stssl_arr (sel->sel_out_slots);
      STSSL (sel->sel_top);
      STSSL (sel->sel_top_skip);
      STSSL (sel->sel_row_ctr);
      stssl_arr (sel->sel_tie_oby);
    }
  else if (IS_NODE (op_node_input, node))
    {
      op_node_t * op = (op_node_t *) node;
      STSSL (op->op_arg_1);
      STSSL (op->op_arg_2);
      STSSL (op->op_arg_3);
      STSSL (op->op_arg_4);
    }
  else if (IS_NODE (setp_node_input, node))
    {
      setp_node_t * setp = (setp_node_t *) node;
      stssl_ha (cc, setp->setp_ha);
      stssl_list (setp->setp_keys);
      stssl_list (setp->setp_dependent);
      DO_SET (gb_op_t *, go, &setp->setp_gb_ops)
	{
	  stssl_ha (cc, go->go_distinct_ha);
	  stssl_arr (go->go_ua_arglist);
	  STSSL (go->go_old_val);
	  STSSL (go->go_distinct);
	  stssl_cv (cc, go->go_ua_init_setp_call);
	  stssl_cv (cc, go->go_ua_acc_setp_call);
	}
      END_DO_SET();
      STSSL (setp->setp_top);
      STSSL (setp->setp_top_skip);
      STSSL (setp->setp_row_ctr);
      stssl_arr (setp->setp_last_vals);
      stssl_arr (setp->setp_keys_box);
      STSSL (setp->setp_last);
      stssl_arr (setp->setp_dependent_box);
      STSSL (setp->setp_sorted);
      STSSL (setp->setp_flushing_mem_sort);
      stssl_arr (setp->setp_ordered_gb_out);
      stssl_sp (cc, setp->setp_insert_spec.ksp_spec_array);
      stssl_ha (cc, setp->setp_reserve_ha);
    }
  else if (IS_NODE (gs_union_node_input, node))
    {
      gs_union_node_t * su = (gs_union_node_t *) node;
      STSSL (su->gsu_nth);
    }
  else if (IS_NODE (fun_ref_node_input, node))
    {
      fun_ref_node_t * fref = (fun_ref_node_t *) node;
      stssl_list (fref->fnr_default_ssls);
      stssl_list (fref->fnr_temp_slots);
    }

}


void
stssl_query (comp_context_t * cc, query_t * qr)
{
  DO_SET (data_source_t *, node, &qr->qr_nodes)
    {
      stssl_qnode (cc, (table_source_t *) node);
    }
  END_DO_SET();
}

void
stssl_ins (comp_context_t * cc, instruction_t * ins)
{
  switch (ins->ins_type)
    {
    case IN_ARTM_PLUS:	STSSL_ARTM; break;
    case IN_ARTM_MINUS:	STSSL_ARTM; break;
    case IN_ARTM_TIMES:	STSSL_ARTM; break;
    case IN_ARTM_DIV:		STSSL_ARTM; break;
    case IN_ARTM_IDENTITY:	STSSL_ARTM; break;
    case IN_ARTM_FPTR:	STSSL_ARTM; break;

    case IN_PRED:
      {
	if (ins->_.pred.func == distinct_comp_func)
	  {
	    stssl_ha  (cc, (hash_area_t *) ins->_.pred.cmp);
	  }
	else if (ins->_.pred.func == subq_comp_func)
	  {
	    subq_pred_t * sp = (subq_pred_t *) ins->_.pred.cmp;
	    stssl_query (cc, sp->subp_query);
	  }
	else if (ins->_.pred.func == bop_comp_func)
	  {
	    bop_comparison_t * cmp = (bop_comparison_t *) ins->_.pred.cmp;
	    STSSL (cmp->cmp_left);
	    STSSL (cmp->cmp_right);
	  }
	else
	  GPF_T1 ("ins pred with unknown comp func");
	break;
      }
    case IN_COMPARE:
      {
	STSSL (ins->_.cmp.left);
	STSSL (ins->_.cmp.right);
	break;
      }
    case INS_CALL:
    case INS_CALL_IND:
      stssl_arr (ins->_.call.params);
      STSSL (ins->_.call.ret);
      STSSL (ins->_.call.proc_ssl);
      break;
    case INS_CALL_BIF:
      stssl_arr (ins->_.bif.params);
      STSSL (ins->_.bif.ret);
      break;
    case INS_SUBQ:
      stssl_query (cc, ins->_.subq.query);
      break;
	      case INS_QNODE:
		stssl_qnode (cc, (table_source_t *) ins->_.qnode.node);
		break;
    case INS_OPEN:
      STSSL (ins->_.open.cursor);
      stssl_query (cc, ins->_.open.query);
      break;
    case INS_FETCH:
      STSSL (ins->_.fetch.cursor);
      stssl_query (cc, ins->_.fetch.query);
      ssl_use_stock_array (cc, ins->_.fetch.targets);
      break;
    case INS_CLOSE:
      STSSL (ins->_.close.cursor);
      break;
    case INS_HANDLER:
      STSSL (ins->_.handler.throw_location);
      STSSL (ins->_.handler.throw_nesting_level);
      STSSL (ins->_.handler.state);
      STSSL (ins->_.handler.message);
      break;
    case INS_HANDLER_END:
      STSSL (ins->_.handler_end.throw_nesting_level);
      STSSL (ins->_.handler_end.throw_location);
      break;
    case IN_VRET:
      STSSL (ins->_.vret.value);
      break;
    }
}


void
stssl_cv (comp_context_t * cc, instruction_t * cv)
{
  if (!cv)
    return;
  DO_INSTR (ins, 0, cv)
    {
      stssl_ins (cc, ins);
    }
  END_DO_INSTR;
}


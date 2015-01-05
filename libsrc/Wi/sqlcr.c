/*
 *  sqlstmts.c
 *
 *  $Id$
 *
 *  Dynamic SQL Statement Compilations
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
#include "eqlcomp.h"
#include "lisprdr.h"
#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlfn.h"
#include "security.h"
#include "sqlpfn.h"
#include "sqlintrp.h"
#include "arith.h"
#include "crsr.h"
#include "sqlo.h"
#include "sqlocr.h"
#include "sqlcstate.h"




#ifndef DEBUG
#define box_tree_check(q)
#endif


query_t *
sql_compile_st (ST ** ptree, client_connection_t * cli,
		caddr_t * err, sql_comp_t *super_sc)
{
  ST *tree = *ptree;
  caddr_t cc_error;
  comp_context_t cc;
  SCS_STATE_FRAME;
  sql_comp_t sc;
  query_t *volatile qr;
  client_connection_t *old_cli = sqlc_client ();
  DK_ALLOC_QUERY (qr);
  memset (&sc, 0, sizeof (sc));

  CC_INIT (cc, cli);
  sc.sc_cc = &cc;
  sc.sc_client = cli;
  cc.cc_query = qr;

  sqlc_set_client (cli);
  SCS_STATE_PUSH;
  top_sc = &sc;
  qr->qr_qualifier = box_string (sqlc_client ()->cli_qualifier);
  qr->qr_owner = box_string (CLI_OWNER (sqlc_client ()));

  if (super_sc->sc_cc->cc_query->qr_module)
    qr->qr_brk = super_sc->sc_cc->cc_query->qr_brk;

  sc.sc_scroll_super = super_sc->sc_scroll_super;
  sc.sc_scroll_param_cols = super_sc->sc_scroll_param_cols;

  t_check_tree ((caddr_t) tree);

  CATCH (CATCH_LISP_ERROR)
  {
    SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR, NULL);
    sql_stmt_comp (&sc, ptree);
    qr_set_local_code_and_funref_flag (sc.sc_cc->cc_query);
    if (sc.sc_cc->cc_query->qr_proc_vectored || sc.sc_cc->cc_has_vec_subq)
      sqlg_vector (&sc, sc.sc_cc->cc_query);
    qr_resolve_aliases (qr);
    qr_set_freeable (&cc, qr);
    qr->qr_instance_length = cc.cc_instance_fill * sizeof (caddr_t);

  }
  THROW_CODE
  {
    if (qr->qr_proc_name)
      query_free (qr);
    else
      qr_free (qr);
    cc_error = (caddr_t) THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR);
    if (err)
      {
	if (cc_error)
	  *err = cc_error;
	else
	  *err = srv_make_new_error ("42000", "SQ078", "Unclassified SQL compilation error.");
      }
    qr = NULL;
  }
  END_CATCH;
  tree = *ptree;
  t_check_tree ((caddr_t)tree);

  sc_free (&sc);
  SCS_STATE_POP;

  if (qr)
    qr->qr_is_complete = 1;
  sqlc_set_client (old_cli);
  return qr;
}


query_t *
sqlc_cr_method (sql_comp_t * sc, ST ** ptree, int pass_state, int no_err)
{
  caddr_t err = NULL;
  query_t *qr = sql_compile_st (ptree, sc->sc_client, &err, pass_state ? sc : NULL);
  if (err)
    {
      /* do this only if is compiling update, delete or insert parts of sc */
      if (no_err && !strncmp(ERR_STATE(err), "42000", 5))
	{
	  dk_free_tree (err);	/* IvAn/010411/LeakOnError */
	  return qr;
	}
      else
	sqlc_resignal (sc, err);
    }
  if (qr->qr_select_node)
    qr->qr_select_node->src_gen.src_input = (qn_input_fn) select_node_input_scroll;
  return qr;
}

int
sqlc_is_updatable (sql_comp_t * sc, ST * tree)
{
  ST * tb;
  if (sc->sc_scroll_super)
    return 0;
  if (tree->_.select_stmt.table_exp->_.table_exp.group_by
      || SEL_IS_DISTINCT (tree)
      || 1 < BOX_ELEMENTS (tree->_.select_stmt.table_exp->_.table_exp.from))
    return 0;
  tb = tree->_.select_stmt.table_exp->_.table_exp.from[0];
  if (!ST_P (tb->_.table_ref.table, TABLE_DOTTED))
    return 0;
  return 1;
}

int
sqlc_cr_is_identifiable (sql_comp_t * sc, ST * tree)
{
  int inx;
  if (!ST_P (tree, SELECT_STMT))
    return 0;
  if (!tree->_.select_stmt.table_exp)
    return 0;
  if (tree->_.select_stmt.table_exp->_.table_exp.group_by)
    return 0;
  if (sc->sc_fun_ref_defaults)
    return 0;
  if (SEL_IS_DISTINCT (tree))
    return 0;
  DO_BOX (comp_table_t *, ct, inx, sc->sc_tables)
  {
    if (ct->ct_derived)
      return 0;
  }
  END_DO_BOX;
  return 1;
}


int
qc_make_cols (sql_comp_t * sc, query_cursor_t * qc, ST * tree)
{
  long n_select_cols = BOX_ELEMENTS (tree->_.select_stmt.selection);
  long col_pos = n_select_cols;
  int nth;
  dk_set_t new_order_by = NULL;
  dk_set_t new_sel = NULL;
  dk_set_t id_col_list = NULL;
  dk_set_t order_pos = NULL;
  caddr_t order_cols;

  int inx;

  qc->qc_n_select_cols = n_select_cols;
  DO_BOX (comp_table_t *, ct, inx, sc->sc_tables)
  {
    dbe_key_t *order_key = ct->ct_index;
    if (!order_key)
      return -1;
    if (!ct->ct_order_cols)
      {
	nth = 0;
	DO_SET (dbe_column_t *, col, &order_key->key_parts)
	{
	  ST *ref = sqlc_ct_col_ref (ct, col->col_name);
	  ST *spec = (ST *) t_list (4, ORDER_BY, ref, (ptrlong) ORDER_ASC, NULL);
	  t_NCONCF1 (new_sel, ref);
	  NCONCF1 (new_order_by, spec);
	  t_NCONCF1 (order_pos, (ptrlong) col_pos);
	  col_pos++;
	  nth++;
	  if (nth == order_key->key_decl_parts)
	    break;
	}
	END_DO_SET ();
      }
    else
      {
	nth = 0;
	DO_SET (col_ref_rec_t *, crr, &ct->ct_order_cols)
	{
	  ST *ref = crr->crr_col_ref;
	  ptrlong ord = ct->ct_order;
	  ST *spec = (ST *) t_list (4, ORDER_BY, ref, ord, NULL);
	  t_NCONCF1 (new_sel, ref);
	  NCONCF1 (new_order_by, spec);
	  nth++;
	  t_NCONCF1 (order_pos, (ptrlong) col_pos);
	  col_pos++;
	}
	END_DO_SET ();
      }
  }
  END_DO_BOX;

  qc->qc_order_by = (ST **) t_list_to_array (new_order_by);
  order_cols = (caddr_t) dk_set_to_array (order_pos);
  box_tag_modify (order_cols, DV_ARRAY_OF_LONG);
  qc->qc_order_cols = (ptrlong *) order_cols;

  DO_BOX (comp_table_t *, ct, inx, sc->sc_tables)
  {
    dbe_key_t *pk = ct->ct_table->tb_primary_key;

    id_cols_t *idc = (id_cols_t *) dk_alloc_box (sizeof (id_cols_t), DV_ARRAY_OF_POINTER);
    idc->idc_table = box_string (ct->ct_table->tb_name);
    idc->idc_pos = (ptrlong *) dk_alloc_box (pk->key_n_significant * sizeof (ptrlong),
					  DV_ARRAY_OF_LONG);
    nth = 0;
    qc->qc_n_id_cols += pk->key_n_significant;
    DO_SET (dbe_column_t *, col, &pk->key_parts)
    {
      ST *ref = sqlc_ct_col_ref (ct, col->col_name);
      t_NCONCF1 (new_sel, ref);
      idc->idc_pos[nth] = col_pos;
      col_pos++;
      nth++;
      if (nth >= pk->key_n_significant)
	break;
    }
    END_DO_SET ();
    t_NCONCF1 (id_col_list, idc);
  }
  END_DO_BOX;

  qc->qc_id_cols = (id_cols_t **) dk_set_to_array (id_col_list);
  qc->qc_org_text = tree;
  qc->qc_id_order_col_refs = (ST **) t_list_to_array (new_sel);
  return 0;
}

void
t_st_and (ST ** cond, ST * pred)
{
  if (!*cond)
    *cond = pred;
  else
    {
      ST *res;
      BIN_OP (res, BOP_AND, *cond, pred);
      *cond = res;
    }
}



void
qc_make_refresh (sql_comp_t * sc, query_cursor_t * qc)
{
  ST **from = (ST **) t_alloc_box (sizeof (caddr_t) * BOX_ELEMENTS (sc->sc_tables),
				    DV_ARRAY_OF_POINTER);
  int inx;
  int pinx = 1000;
  ST *texp = (ST *) t_list (9, TABLE_EXP, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
  qc->qc_refresh_text = (ST *)
    t_list (5, SELECT_STMT, (ptrlong)0, t_box_copy_tree ((caddr_t) qc->qc_org_text->_.select_stmt.selection),
	  NULL, texp);
  DO_BOX (comp_table_t *, ct, inx, sc->sc_tables)
  {
    int nth = 0;
    from[inx] = (ST *) t_list (3, TABLE_REF, t_list (6, TABLE_DOTTED, t_box_string (ct->ct_table->tb_name),
						 t_box_copy (ct->ct_prefix),
						 t_box_num (ct->ct_u_id),
						     t_box_num (ct->ct_g_id), NULL), NULL);
    DO_SET (dbe_column_t *, col, &ct->ct_table->tb_primary_key->key_parts)
    {
      char tmp[10];
      snprintf (tmp, sizeof (tmp), ":%d", pinx++);
      t_st_and (&texp->_.table_exp.where,
	      (ST *) t_list (4, BOP_EQ, sqlc_ct_col_ref (ct, col->col_name), t_sym_string (tmp), NULL));
      nth++;
      if (nth >= ct->ct_table->tb_primary_key->key_n_significant)
	break;
    }
    END_DO_SET ();
  }
  END_DO_BOX;
  texp->_.table_exp.from = from;
  sqlp_infoschema_redirect (texp);
  qc->qc_refresh = sqlc_cr_method (sc, &(qc->qc_refresh_text), 1, 0);
}

ST *
qc_make_1_continue (sql_comp_t * sc, query_cursor_t * qc, int n_specs, int is_innermost, int is_reverse)
{
  ST *spec = NULL;
  int inx, nth;
  ptrlong op;
  char tmp[10];
  int pinx = 1000;
  ST *tree = (ST *) t_box_copy_tree ((caddr_t) qc->qc_text_with_ids);
  ST **order_by = (ST **) t_box_copy_tree ((caddr_t) qc->qc_order_by);
  if (is_reverse)
    {
      DO_BOX (ST *, spec, inx, order_by)
      {
	spec->_.o_spec.order = spec->_.o_spec.order == ORDER_ASC ? ORDER_DESC : ORDER_ASC;
      }
      END_DO_BOX;
    }

/*  dk_free_tree ((caddr_t) tree->_.select_stmt.table_exp->_.table_exp.order_by);*/
  tree->_.select_stmt.table_exp->_.table_exp.order_by = order_by;
  if (0 == n_specs)
    return tree;


  for (nth = 0; nth < n_specs - 1; nth++)
    {
      spec = qc->qc_order_by[nth];
      snprintf (tmp, sizeof (tmp), ":%d", pinx++);
      t_st_and (&tree->_.select_stmt.table_exp->_.table_exp.where,
	      (ST *) t_list (4, BOP_EQ, t_box_copy_tree ((caddr_t) spec->_.o_spec.col), t_sym_string (tmp), NULL));
    }
  spec = order_by[n_specs - 1];
  op = spec->_.o_spec.order == ORDER_ASC ? BOP_GT : BOP_LT;
  if (is_innermost)
    {
      if (op == BOP_LT)
	op = BOP_LTE;
      else
	op = BOP_GTE;
    }
  snprintf (tmp, sizeof (tmp), ":%d", pinx++);
  t_st_and (&tree->_.select_stmt.table_exp->_.table_exp.where,
	  (ST *) t_list (4, op, t_box_copy_tree ((caddr_t) spec->_.o_spec.col), t_sym_string (tmp), NULL));
  return tree;
}


void
qc_make_continues (sql_comp_t * sc, query_cursor_t * qc)
{
  int inx;
  ST **order_by = qc->qc_order_by;
  int n_specs = BOX_ELEMENTS (order_by) + 1;
  ST **fwd = (ST **) t_alloc_box (sizeof (caddr_t) * n_specs, DV_ARRAY_OF_POINTER);
  ST **bwd = (ST **) t_alloc_box (sizeof (caddr_t) * n_specs, DV_ARRAY_OF_POINTER);

  qc->qc_next = (query_t **) dk_alloc_box_zero (sizeof (caddr_t) * n_specs, DV_ARRAY_OF_POINTER);
  qc->qc_prev = (query_t **) dk_alloc_box_zero (sizeof (caddr_t) * n_specs, DV_ARRAY_OF_POINTER);



  fwd[0] = (ST *) t_box_copy_tree ((caddr_t) qc->qc_text_with_ids);
  bwd[0] = qc_make_1_continue (sc, qc, 0, 0, 1);
  qc->qc_next[0] = sqlc_cr_method (sc, &(fwd[0]), 1, 0);
  qc->qc_prev[0] = sqlc_cr_method (sc, &(bwd[0]), 1, 0);

  for (inx = 1; inx < n_specs; inx++)
    {
      int is_inner = inx == (n_specs - 1);
      fwd[inx] = qc_make_1_continue (sc, qc, inx, is_inner, 0);
      bwd[inx] = qc_make_1_continue (sc, qc, inx, is_inner, 1);
      qc->qc_next[inx] = sqlc_cr_method (sc, &(fwd[inx]), 1, 0);
      qc->qc_prev[inx] = sqlc_cr_method (sc, &(bwd[inx]), 1, 0);
    }
  qc->qc_next_text = fwd;
  qc->qc_prev_text = bwd;
}


ST *
qc_position_texp (sql_comp_t * sc, query_cursor_t * qc)
{
  ST **from = (ST **) t_alloc_box (sizeof (caddr_t),
				    DV_ARRAY_OF_POINTER);
  int pinx = 0;
  ST *texp = (ST *) t_list (9, TABLE_EXP, NULL, NULL, NULL, NULL, NULL, NULL, NULL,NULL);
  comp_table_t *ct = sc->sc_tables[0];
  int nth = 0;
  from[0] = (ST *) t_list (6, TABLE_DOTTED, t_box_string (ct->ct_table->tb_name), NULL,
			 t_box_num (ct->ct_u_id),
			   t_box_num (ct->ct_g_id), NULL);

  DO_SET (dbe_column_t *, col, &ct->ct_table->tb_primary_key->key_parts)
  {
    char tmp[10];
    snprintf (tmp, sizeof (tmp), ":%d", pinx++);
    t_st_and (&texp->_.table_exp.where,
	    (ST *) t_list (4, BOP_EQ, t_list (3, COL_DOTTED, NULL, t_box_string (col->col_name)), t_sym_string (tmp), NULL));
    nth++;
    if (nth >= ct->ct_table->tb_primary_key->key_n_significant)
      break;
  }
  END_DO_SET ();
  texp->_.table_exp.from = from;
  return sqlp_infoschema_redirect (texp);
}


ST *
qc_make_update (sql_comp_t * sc, query_cursor_t * qc)
{
  ST *upd;
  int inx;
  char temp[10];
  int pinx = 1000;
  ST *org_sel = qc->qc_org_text;
  ST *tb_ref = org_sel->_.select_stmt.table_exp->_.table_exp.from[0];
  caddr_t tb_name = tb_ref->_.table_ref.table->_.table.name;
  ST **cols = (ST **) t_box_copy ((caddr_t) org_sel->_.select_stmt.selection);
  ST **vals = (ST **) t_box_copy ((caddr_t) cols);
  memset (cols, 0, box_length ((caddr_t) cols));
  memset (vals, 0, box_length ((caddr_t) vals));
  DO_BOX (ST *, col_ref, inx, org_sel->_.select_stmt.selection)
  {
    if (!ST_P (col_ref, COL_DOTTED))
      {
/*	dk_free_tree ((caddr_t) cols);
	dk_free_tree ((caddr_t) vals);*/
	return NULL;
      }
    snprintf (temp, sizeof (temp), ":%d", pinx++);
    vals[inx] = (ST *) t_sym_string (temp);
    cols[inx] = (ST *) t_full_box_copy_tree (col_ref->_.col_ref.name);
  }
  END_DO_BOX;

  upd = (ST *) t_list (5, UPDATE_SRC, t_list (6, TABLE_DOTTED, t_full_box_copy_tree (tb_name), NULL,
					  t_full_box_copy_tree (tb_ref->_.table_ref.table->_.table.u_id),
					      t_full_box_copy_tree (tb_ref->_.table_ref.table->_.table.g_id), NULL), cols, vals,
		     qc_position_texp (sc, qc));
  qc->qc_update = sqlc_cr_method (sc, &upd, 1, 1);
  qc->qc_update_text = upd;
  return upd;
}


ST *
qc_make_insert (sql_comp_t * sc, query_cursor_t * qc)
{
  ST *ins;
  int inx;
  char temp[10];
  int pinx = 0;
  ST *org_sel = qc->qc_org_text;
  ST *tb_ref = org_sel->_.select_stmt.table_exp->_.table_exp.from[0];
  caddr_t tb_name = tb_ref->_.table_ref.table->_.table.name;
  ST **cols = (ST **) t_box_copy ((caddr_t) org_sel->_.select_stmt.selection);
  ST **vals = (ST **) t_box_copy ((caddr_t) cols);
  memset (cols, 0, box_length ((caddr_t) cols));
  memset (cols, 0, box_length ((caddr_t) vals));
  DO_BOX (ST *, col_ref, inx, org_sel->_.select_stmt.selection)
  {
    if (!ST_P (col_ref, COL_DOTTED))
      {
/*	dk_free_tree ((caddr_t) cols);
	dk_free_tree ((caddr_t) vals);*/
	return NULL;
      }
    snprintf (temp, sizeof (temp), ":%d", pinx++);
    vals[inx] = (ST *) t_sym_string (temp);
    cols[inx] = (ST *) t_box_copy (col_ref->_.col_ref.name);
  }
  END_DO_BOX;

  ins = (ST *) t_list (7, INSERT_STMT, t_list (6, TABLE_DOTTED, t_box_copy (tb_name), NULL,
					   t_box_copy (tb_ref->_.table_ref.table->_.table.u_id),
					       t_box_copy (tb_ref->_.table_ref.table->_.table.g_id), NULL), cols,
		       t_list (2, INSERT_VALUES, vals), (ptrlong)INS_NORMAL, NULL, NULL);

  qc->qc_insert = sqlc_cr_method (sc, &ins, 1, 1);
  qc->qc_insert_text = ins;
  return ins;
}


void
qc_make_delete (sql_comp_t * sc, query_cursor_t * qc)
{
  ST *del;


  del = (ST *) t_list (2, DELETE_SRC, qc_position_texp (sc, qc));
  qc->qc_delete = sqlc_cr_method (sc, &del, 1, 1);
  qc->qc_delete_text = del;
}


caddr_t
box_conc (caddr_t b1, caddr_t b2)
{
  int l1 = box_length (b1);
  int l2 = box_length (b2);
  dtp_t tag = box_tag (b1);
  caddr_t res;
  if (tag == DV_LONG_STRING || tag == DV_SHORT_STRING)
    l1--;			/* trailing 0 */
  res = dk_alloc_box (l1 + l2, tag);
  memcpy (res, b1, l1);
  memcpy (res + l1, b2, l2);
  return res;
}

caddr_t
t_box_conc (caddr_t b1, caddr_t b2)
{
  int l1 = box_length (b1);
  int l2 = box_length (b2);
  dtp_t tag = box_tag (b1);
  caddr_t res;
  if (tag == DV_LONG_STRING || tag == DV_SHORT_STRING)
    l1--;			/* trailing 0 */
  res = t_alloc_box (l1 + l2, tag);
  memcpy (res, b1, l1);
  memcpy (res + l1, b2, l2);
  return res;
}

void
qc_make_stmts (sql_comp_t * sc, query_cursor_t * qc)
{
  caddr_t id_copy;
  ST *text = qc->qc_org_text;
  ST **old_sel;
  qc->qc_text_with_ids = (ST *) t_box_copy_tree ((caddr_t) qc->qc_org_text);
  old_sel = (ST **) qc->qc_text_with_ids->_.select_stmt.selection;
  id_copy = t_box_copy_tree ((caddr_t) qc->qc_id_order_col_refs);
  qc->qc_text_with_ids->_.select_stmt.selection = (caddr_t *)
    t_box_conc ((caddr_t) old_sel, id_copy);
/*  dk_free_box ((caddr_t) old_sel);
  dk_free_box (id_copy);*/

  qc_make_refresh (sc, qc);
  qc_make_continues (sc, qc);
  if (sqlc_is_updatable (sc, text))
    {
      if (qc_make_update (sc, qc))
	qc_make_insert (sc, qc);
      qc_make_delete (sc, qc);
    }
}


void
qc_make_static (sql_comp_t * sc, query_cursor_t * qc, ST ** ptree)
{
  qc->qc_next = (query_t **) sc_list (1, sqlc_cr_method (sc, ptree, 1, 0));
  qc->qc_cursor_type = _SQL_CURSOR_STATIC;
  qc->qc_n_select_cols = BOX_ELEMENTS ((*ptree)->_.select_stmt.selection);
}

void
sqlc_top_select_wrap_dt (sql_comp_t * sc, ST * tree)
{
  /* given select top xx ...) splices it to be select ... from (select top xx... ) __ */
  ST * top, * texp, * sel;
  if (!ST_P (tree, SELECT_STMT))
    return;
  top = SEL_TOP (tree);
  if (top)
    {
      ST * out_names = (ST *) sqlc_selection_names (tree);
      ST ** oby = tree->_.select_stmt.table_exp->_.table_exp.order_by;
      if (oby)
	{
	  sel = (ST*) /*list*/ t_list (5, SELECT_STMT, NULL, tree->_.select_stmt.selection, NULL,
	      tree->_.select_stmt.table_exp);
	  texp = (ST*) /*list*/ t_list (9, TABLE_EXP,
	      /*list*/ t_list (1, /*list*/ t_list (3, DERIVED_TABLE, sel, t_box_string ("__"))),
	      NULL, NULL, NULL, NULL, NULL,NULL, NULL);
	  tree->_.select_stmt.table_exp = sqlp_infoschema_redirect (texp);
	  tree->_.select_stmt.selection = (caddr_t *) out_names;
	  tree->_.select_stmt.top = top;
	}
      sqlc_top_select_dt (sc, tree);
    }
}

void
sqlc_cursor (sql_comp_t * sc, ST ** ptree, int cr_type)
{
  ST *tree = *ptree;
  int is_id;
  int cr_forced_static = 0;

  sc->sc_no_remote = 1;

  if (IS_UNION_ST (tree))
    {
      tree = sqlp_view_def (NULL, tree, 1);
      tree = sqlc_union_dt_wrap (tree);
      *ptree = tree;
    }
  sqlc_top_select_wrap_dt (sc, tree);
  sql_stmt_comp (sc, ptree);
  tree = *ptree;

  if (sc->sc_so)
    is_id = sqlo_cr_is_identifiable (sc->sc_so, tree);
  else
    is_id = sqlc_cr_is_identifiable (sc, tree);
  if (!is_id)
    cr_forced_static = 1;
  {
    NEW_VARZ (query_cursor_t, qc);
    if (sc->sc_cc->cc_query->qr_cursor)
      {
	qc_free (sc->sc_cc->cc_query->qr_cursor);
	fprintf (stderr, "Freeing qc in sqlc_cursor\n");
      }
    sc->sc_cc->cc_query->qr_cursor = qc;
    sc->sc_cc->cc_query->qr_cursor_type = cr_type;

    if (sc->sc_so)
      {
	if (!cr_forced_static
	    && -1 == sqlo_qc_make_cols (sc->sc_so, qc, tree))
	  cr_forced_static = 1;
      }
    else
      {
	if (!cr_forced_static
	    && -1 == qc_make_cols (sc, qc, tree))
	  cr_forced_static = 1;
      }
    if (!cr_forced_static)
      {
	qc->qc_cursor_type = cr_type;
	if (sc->sc_so)
	  sqlo_qc_make_stmts (sc->sc_so, qc);
	else
	  qc_make_stmts (sc, qc);
      }
    else
      {
	qc_make_static (sc, qc, ptree);
	tree = *ptree;
      }
  }
}


void
qr_box_free (query_t ** box)
{
  int inx;
  DO_BOX (query_t *, qr, inx, box)
  {
    qr_free (qr);
  }
  END_DO_BOX;
  dk_free_box ((caddr_t) box);
}


void
qc_free (query_cursor_t * qc)
{
  dk_free_tree ((caddr_t) qc->qc_order_cols);
  dk_free_tree ((caddr_t) qc->qc_id_cols);
  /*dk_free_tree ((caddr_t) qc->qc_id_order_col_refs);
  dk_free_tree ((caddr_t) qc->qc_org_text);
  dk_free_tree ((caddr_t) qc->qc_order_by);

  dk_free_tree ((caddr_t) qc->qc_referesh_text);
  dk_free_tree ((caddr_t) qc->qc_update_text);
  dk_free_tree ((caddr_t) qc->qc_delete_text);
  dk_free_tree ((caddr_t) qc->qc_insert_text);
  dk_free_tree ((caddr_t) qc->qc_pos_where);
  dk_free_tree ((caddr_t) qc->qc_next_text);
#if 1
  box_tree_check ((caddr_t) qc->qc_prev_text);
  dk_free_tree ((caddr_t) qc->qc_prev_text);
#endif
  dk_free_tree ((caddr_t) qc->qc_text_with_ids);
  dk_free_tree ((caddr_t) qc->qc_refresh_text);

  */
  qr_free (qc->qc_refresh);
  qr_free (qc->qc_update);
  qr_free (qc->qc_delete);
  qr_free (qc->qc_insert);
  qr_box_free (qc->qc_prev);
  qr_box_free (qc->qc_next);
  dk_free ((caddr_t) qc, sizeof (query_cursor_t));
}


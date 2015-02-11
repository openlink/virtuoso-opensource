/*
 *  sqlocr.c
 *
 *  $Id$
 *
 *  sql opt cursors inference
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

#include "libutil.h"

#include "sqlnode.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlbif.h"
#include "arith.h"
#include "security.h"
#include "crsr.h"
#include "sqlo.h"
#include "sqlocr.h"

int
sqlo_cr_is_identifiable (sqlo_t * so, ST * tree)
{
  df_elt_t *dfe = so->so_copy_root;
  if (!dfe || !dfe->dfe_type == DFE_DT)
    return 0;
  if (!ST_P (tree, SELECT_STMT))
    return 0;
  if (!tree->_.select_stmt.table_exp)
    return 0;
  if (tree->_.select_stmt.table_exp->_.table_exp.group_by)
    return 0;
  if (so->so_sc->sc_fun_ref_defaults)
    return 0;
  if (SEL_IS_DISTINCT (tree))
    return 0;
  DO_SET (op_table_t *, ot, &dfe_ot (dfe)->ot_from_ots)
  {
    if (ot->ot_dt)
      return 0;
    if (ot->ot_text_score || ot->ot_xpath_value)
      return 0;
  }
  END_DO_SET ();
  return 1;
}


int
sqlo_qc_make_cols (sqlo_t * so, query_cursor_t * qc, ST * tree)
{
  int n_select_cols = BOX_ELEMENTS (tree->_.select_stmt.selection);
  long col_pos = n_select_cols;
  int nth;
  df_elt_t *dfe = so->so_copy_root, *elt;
  dk_set_t new_order_by = NULL;
  dk_set_t new_sel = NULL;
  dk_set_t id_col_list = NULL;
  dk_set_t order_pos = NULL;

  qc->qc_n_select_cols = n_select_cols;
  for (elt = dfe->_.sub.first; elt; elt = elt->dfe_next)
    {
      op_table_t *ot;
      dbe_key_t *order_key;

      if (elt->dfe_type != DFE_TABLE || elt->_.table.hash_role == HR_FILL)
	continue;
      order_key = elt->_.table.key;
      ot = dfe_ot (elt);
      if (!order_key)
	return -1;
      if (!ot->ot_order_cols)
	{
	  nth = 0;
	  DO_SET (dbe_column_t *, col, &order_key->key_parts)
	  {
	    ST *ref =
		t_listst (3, COL_DOTTED, ot->ot_new_prefix, col->col_name);
	    ST *spec = (ST *) t_list (4, ORDER_BY, ref, (ptrlong) ORDER_ASC, NULL);
	    t_NCONCF1 (new_sel, ref);
	    t_NCONCF1 (new_order_by, spec);
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
	  DO_SET (df_elt_t *, col_dfe, &ot->ot_order_cols)
	  {
	    ST *ref = col_dfe->dfe_tree;
	    ptrlong ord = ot->ot_order_dir;
	    ST *spec = (ST *) t_list (4, ORDER_BY, ref, ord, NULL);
	    t_NCONCF1 (new_sel, ref);
	    t_NCONCF1 (new_order_by, spec);
	    nth++;
	    t_NCONCF1 (order_pos, (ptrlong) col_pos);
	    col_pos++;
	  }
	  END_DO_SET ();
	}
    }

  qc->qc_order_by = (ST **) t_list_to_array (new_order_by);
  qc->qc_order_cols = (ptrlong *) dk_set_to_array (order_pos);
  box_tag_modify (qc->qc_order_cols, DV_ARRAY_OF_LONG);

  DO_SET (op_table_t *, ot, &dfe_ot (dfe)->ot_from_ots)
  {
    dbe_key_t *pk = ot->ot_table->tb_primary_key;

    id_cols_t *idc =
	(id_cols_t *) dk_alloc_box (sizeof (id_cols_t), DV_ARRAY_OF_POINTER);
    idc->idc_table = box_string (ot->ot_table->tb_name);
    idc->idc_pos =
	(ptrlong *) dk_alloc_box (pk->key_n_significant * sizeof (ptrlong),
	DV_ARRAY_OF_LONG);
    nth = 0;
    qc->qc_n_id_cols += pk->key_n_significant;
    DO_SET (dbe_column_t *, col, &pk->key_parts)
    {
      ST *ref = t_listst (3, COL_DOTTED, ot->ot_new_prefix, col->col_name);
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
  END_DO_SET ();

  qc->qc_id_cols = (id_cols_t **) dk_set_to_array (id_col_list);
  qc->qc_org_text = tree;
  qc->qc_id_order_col_refs = (ST **) t_list_to_array (new_sel);
  return 0;
}


static void
sqlo_qc_make_refresh (sqlo_t * so, query_cursor_t * qc)
{
  df_elt_t *dfe = so->so_copy_root;
  ST **from =
      (ST **) t_alloc_box (sizeof (caddr_t) *
      dk_set_length (dfe_ot (dfe)->ot_from_ots),
      DV_ARRAY_OF_POINTER);
  int inx = 0;
  int pinx = 1000;
  ST *texp = (ST *) t_list (9, TABLE_EXP, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
  qc->qc_refresh_text = (ST *)
      t_list (5, SELECT_STMT, (long) 0,
      t_box_copy_tree ((caddr_t) qc->qc_org_text->_.select_stmt.selection),
      NULL, texp);
  DO_SET (op_table_t *, ot, &dfe_ot (dfe)->ot_from_ots)
  {
    int nth = 0;
    from[inx] =
	t_listst (3, TABLE_REF, t_list (6, TABLE_DOTTED,
	    t_box_string (ot->ot_table->tb_name),
	    t_box_copy (ot->ot_new_prefix), t_box_num (ot->ot_u_id),
					t_box_num (ot->ot_g_id), ot->ot_opts), NULL);
    DO_SET (dbe_column_t *, col, &ot->ot_table->tb_primary_key->key_parts)
    {
      char tmp[10];
      snprintf (tmp, sizeof (tmp), ":%d", pinx++);
      t_st_and (&texp->_.table_exp.where,
	  t_listst (4, BOP_EQ, t_list (3, COL_DOTTED, ot->ot_new_prefix,
		  col->col_name), t_sym_string (tmp), NULL));
      nth++;
      if (nth >= ot->ot_table->tb_primary_key->key_n_significant)
	break;
    }
    END_DO_SET ();
    inx++;
  }
  END_DO_SET ();
  texp->_.table_exp.from = from;
  sqlp_infoschema_redirect (texp);
  qc->qc_refresh = sqlc_cr_method (so->so_sc, &(qc->qc_refresh_text), 1, 0);
}


static ST *
sqlo_qc_position_texp (sqlo_t * so, query_cursor_t * qc)
{
  df_elt_t *dfe = so->so_copy_root;
  ST **from = (ST **) t_alloc_box (sizeof (caddr_t),
      DV_ARRAY_OF_POINTER);
  int pinx = 0;
  ST *texp = (ST *) t_list (9, TABLE_EXP, NULL, NULL, NULL, NULL, NULL, NULL,NULL, NULL);
  op_table_t *ot = (op_table_t *) dfe_ot (dfe)->ot_from_ots->data;
  int nth = 0;
  from[0] =
      (ST *) t_list (6, TABLE_DOTTED, t_box_string (ot->ot_table->tb_name),
		     NULL, t_box_num (ot->ot_u_id), t_box_num (ot->ot_g_id), ot->ot_opts);

  DO_SET (dbe_column_t *, col, &ot->ot_table->tb_primary_key->key_parts)
  {
    char tmp[10];
    snprintf (tmp, sizeof (tmp), ":%d", pinx++);
    t_st_and (&texp->_.table_exp.where,
	(ST *) t_list (4, BOP_EQ, t_list (3, COL_DOTTED, NULL,
		t_box_string (col->col_name)), t_sym_string (tmp), NULL));
    nth++;
    if (nth >= ot->ot_table->tb_primary_key->key_n_significant)
      break;
  }
  END_DO_SET ();
  texp->_.table_exp.from = from;

  return sqlp_infoschema_redirect (texp);
}


static ST *
sqlo_qc_make_update (sqlo_t * so, query_cursor_t * qc)
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
	return NULL;
      }
    snprintf (temp, sizeof (temp), ":%d", pinx++);
    vals[inx] = (ST *) t_sym_string (temp);
    cols[inx] = (ST *) t_full_box_copy_tree (col_ref->_.col_ref.name);
  }
  END_DO_BOX;

  upd = (ST *) t_list (5, UPDATE_SRC,
      t_list (6, TABLE_DOTTED,
	  t_full_box_copy_tree (tb_name), NULL,
	  t_full_box_copy_tree (tb_ref->_.table_ref.table->_.table.u_id),
	      t_full_box_copy_tree (tb_ref->_.table_ref.table->_.table.g_id), tb_ref->_.table_ref.table->_.table.opts),
      cols, vals, sqlo_qc_position_texp (so, qc));
  qc->qc_update = sqlc_cr_method (so->so_sc, &upd, 1, 1);
  qc->qc_update_text = upd;
  return upd;
}


static void
sqlo_qc_make_delete (sqlo_t * so, query_cursor_t * qc)
{
  ST *del;

  del = (ST *) t_list (2, DELETE_SRC, sqlo_qc_position_texp (so, qc));
  qc->qc_delete = sqlc_cr_method (so->so_sc, &del, 1, 1);
  qc->qc_delete_text = del;
}


void
sqlo_qc_make_stmts (sqlo_t * so, query_cursor_t * qc)
{
  caddr_t id_copy;
  ST *text = qc->qc_org_text;
  ST **old_sel;
  qc->qc_text_with_ids = (ST *) t_box_copy_tree ((caddr_t) qc->qc_org_text);
  old_sel = (ST **) qc->qc_text_with_ids->_.select_stmt.selection;
  id_copy = t_box_copy_tree ((caddr_t) qc->qc_id_order_col_refs);
  qc->qc_text_with_ids->_.select_stmt.selection = (caddr_t *)
      t_box_conc ((caddr_t) old_sel, id_copy);

  sqlo_qc_make_refresh (so, qc);
  qc_make_continues (so->so_sc, qc);
  if (sqlc_is_updatable (so->so_sc, text))
    {
      if (sqlo_qc_make_update (so, qc))
	qc_make_insert (so->so_sc, qc);
      sqlo_qc_make_delete (so, qc);
    }
}

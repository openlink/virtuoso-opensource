/*
 *  $Id$
 *
 *  Index selection
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

#include <string.h>
#include "Dk.h"
#include "Dk/Dkpool.h"
#include "libutil.h"
#include "sqlnode.h"
#include "eqlcomp.h"
#include "sqlfn.h"
#include "lisprdr.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlbif.h"
#include "arith.h"
#include "security.h"
#include "sqlpfn.h"
#include "sqlo.h"
#include "list2.h"
#include "remote.h"
#include "sqlrcomp.h"
#include "sqloinv.h"



void
dfe_list_set_placed (dk_set_t list, int f)
{
  DO_SET (df_elt_t *, dfe, &list)
    dfe->dfe_is_placed = f;
  END_DO_SET();
}


#define DFE_NEED_RECHECK 3



int
sqlo_is_key_used (dk_set_t path, dbe_key_t * key)
{
  DO_SET (index_choice_t *, ic, &path)
    {
      if (key == ic->ic_key)
	return 1;
      if (ic->ic_inx_op)
	{
	  DO_SET (df_inx_op_t *, term, &ic->ic_inx_op->dio_terms)
	    {
	      if (key == term->dio_key)
		return 1;
	    }
	  END_DO_SET();
	}
    }
  END_DO_SET();
  return 0;
}

int
sqlo_after_test_placeable (df_elt_t * tb, dk_set_t path, ST * tree)
{
  /* true if all cols of the table concerned in the tree are covered in the inxes on the path */
  if (ST_COLUMN (tree, COL_DOTTED))
    {
      df_elt_t * col;
      if (!tree->_.col_ref.prefix || strcmp (tree->_.col_ref.prefix, tb->_.table.ot->ot_new_prefix))
	return 1;
      col = sqlo_df (tb->dfe_sqlo, tree);
      DO_SET (index_choice_t *, ic, &path)
	{
	  if (ic->ic_key && dk_set_member (ic->ic_key->key_parts, (void*)col->_.col.col))
	    return 1;
	  if (ic->ic_inx_op)
	    {
	      DO_SET (df_inx_op_t *, term, &ic->ic_inx_op->dio_terms)
		{
		  if (dk_set_member (term->dio_key->key_parts, (void*)col->_.col.col))
		    return 1;
		}
	      END_DO_SET();
	    }
	}
      END_DO_SET();
      return 0;
    }
  else if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree))
    {
      int inx;
      DO_BOX (ST*, exp, inx, tree)
	if (!sqlo_after_test_placeable (tb, path, exp))
	  return 0;
      END_DO_BOX;
      return 1;
    }
  else
    return 1;
}


int
sqlo_inx_path_complete (df_elt_t * tb_dfe, dk_set_t path)
{
  /* true if all conds and columns are covered by the inxes on the path */
  index_choice_t * first;
  if (!path)
    return 0;
  if (sqlo_opt_value (tb_dfe->_.table.ot->ot_opts, OPT_INDEX_ONLY))
    return 1;
  DO_SET (dbe_column_t *, refd , &tb_dfe->_.table.ot->ot_table_refd_cols)
    {
      DO_SET (index_choice_t *, ic, &path)
	{
	  if (ic->ic_key && dk_set_member (ic->ic_key->key_parts, (void*) refd))
	    goto found;
	  if (ic->ic_inx_op)
	    {
	      DO_SET (df_inx_op_t *, dio, &ic->ic_inx_op->dio_terms)
		if (dk_set_member (dio->dio_key->key_parts, (void*)refd))
		  goto found;
	      END_DO_SET();
	    }
	}
      END_DO_SET();
      return 0;
    found: ;
    }
  END_DO_SET();

  first = (index_choice_t*)path->data;
  if (first->ic_key && first->ic_key->key_distinct)
    return 0; /* a partial distinct key cannot be the last, its cardinality is not right */
  if (first->ic_inx_op)
    {
      DO_SET (df_inx_op_t *, dio, &first->ic_inx_op->dio_terms)
	if (dio->dio_key && !dio->dio_key->key_no_pk_ref)
	  return 0;
      END_DO_SET();
    }
  return 1;
}


void
sqlo_ic_unplace (sqlo_t * so, index_choice_t * ic)
{
  DO_SET (ts_action_t *, tsa, &ic->ic_ts_action)
    {
      if (tsa->tsa_extract_col)
	tsa->tsa_extract_col->dfe_is_placed = 0;
      if (tsa->tsa_test_col)
	tsa->tsa_test_col->dfe_is_placed = 0;
    }
  END_DO_SET();
  dfe_list_set_placed (ic->ic_inx_preds, 0);
  if (ic->ic_text_pred)
    ic->ic_text_pred->dfe_is_placed = 0;
}


int
sqlo_key_any_refd (df_elt_t * dfe, dbe_key_t * key)
{
  DO_SET (dbe_column_t *, refd , &dfe->_.table.ot->ot_table_refd_cols)
    {
      if (dk_set_member (key->key_parts, (void*) refd))
	return 1;
    }
  END_DO_SET();
  return 0;
}

int
sqlo_pred_in_path (dk_set_t path, df_elt_t * pred)
{
  DO_SET (index_choice_t *, ic, &path)
    if (dk_set_member (ic->ic_after_preds, (void*)pred))
      return 1;
  END_DO_SET();
  return 0;
}

int
sqlo_pred_eliminated_in_path (dk_set_t path, df_elt_t * pred)
{
  DO_SET (index_choice_t *, ic, &path)
    if (dk_set_member (ic->ic_eliminated_after_preds, (void*)pred))
      return 1;
  END_DO_SET();
  return 0;
}


void
sqlo_ic_set_tsa (df_elt_t * tb_dfe, dk_set_t path)
{
  /* set the order of single col dependent preds and col value extraction and finally complex after test */
  index_choice_t * ic = (index_choice_t*)path->data;
  int pos = 0;
  dk_set_t local = NULL;
  DO_SET (df_elt_t *, pred, &tb_dfe->dfe_sqlo->so_after_preds)
    {
      pos++;
      if (sqlo_pred_in_path (path, (void *)(ptrlong)(pos - 1))
	  || sqlo_pred_eliminated_in_path (path, pred))
	continue;
      if (sqlo_after_test_placeable (tb_dfe, path, pred->dfe_tree))
	t_set_push (&local, (void *)(ptrlong)(pos - 1));
    }
  END_DO_SET();
  ic->ic_after_preds = local;
}


dk_set_t
sqlo_ip_copy (df_elt_t * tb_dfe, dk_set_t path)
{
  /* copy index shoices, copy is in rev order */
  sqlo_t * so = tb_dfe->dfe_sqlo;
  dk_set_t res = NULL;
  DO_SET (index_choice_t *, ic, &path)
    {
      t_NEW_VAR (index_choice_t, ic2);
      *ic2 = *ic;
      if (ic2->ic_inx_op)
	ic2->ic_inx_op = inx_op_copy (so, ic2->ic_inx_op, tb_dfe, tb_dfe);
      t_set_push (&res, (void*)(void*)ic2);
    }
  END_DO_SET();
  return res;
}


float
sqlo_index_path_cost (dk_set_t path, float * cost_ret, float * card_ret, char * sure_ret)
{
  float cost = -1, card = 1;
  int n_sure = 0;
  DO_SET (index_choice_t *, ic, &path)
    {
      if (-1 == cost)
	{
	  cost = ic->ic_unit;
	  card = ic->ic_arity;
	  n_sure = ic->ic_leading_constants;
	}
      else
	{
	  cost += card * ic->ic_unit;
	  card *= ic->ic_arity;
	}
    }
  END_DO_SET();
  if (n_sure >= *sure_ret)
    {
      if (-1 == *cost_ret || 0 == *card_ret)
	*card_ret = card;
      else
	*card_ret = MIN (*card_ret, card);
      *sure_ret = n_sure;
    }
  *cost_ret = cost;
  return cost;
}


int
dfe_is_eq_pred (df_elt_t * pred)
{
  return (pred && (
		((DFE_BOP_PRED  == pred->dfe_type || DFE_BOP == pred->dfe_type) && BOP_EQ == pred->_.bin.op)
		|| sqlo_in_list (pred, NULL, NULL))) ;
}


int
dfe_is_range_pred (df_elt_t * pred)
{
  return (pred && (DFE_BOP_PRED  == pred->dfe_type || DFE_BOP == pred->dfe_type)
	  && BOP_EQ != pred->_.bin.op);
}


int
sqlo_ip_leading_text (df_elt_t * tb_dfe, dbe_key_t * key, index_choice_t * ic, df_elt_t ** text_id_pred)
{
  /* put a text/geo in leading pos if it fits with the key we have.
   * Is the text key col a part and are all the parts before this eqs? */
  ST * tree;
  caddr_t prefix;
  float text_cost = 0, text_card;
  df_elt_t * text_pred = tb_dfe->_.table.text_pred;
  dbe_key_t * id_key = tb_text_key (tb_dfe->_.table.ot->ot_table);
  dbe_column_t * id_col;
  df_elt_t * eq_pred;
  if (!text_pred || !id_key)
    return 0;
  id_col = (dbe_column_t*)id_key->key_parts->data;
  eq_pred = sqlo_key_part_best ( id_col, tb_dfe->_.table.col_preds, 0);
  if (dfe_is_eq_pred (eq_pred))
    return 0;
  DO_SET (dbe_column_t *, prev_col, &key->key_parts)
    {
      if (prev_col == id_col)
	break;
      eq_pred = sqlo_key_part_best (prev_col, tb_dfe->_.table.col_preds, 0);
      if (!dfe_is_eq_pred (eq_pred))
	return 0;
    }
  END_DO_SET();
  text_pred->dfe_is_placed = DFE_PLACED;
  text_card = dfe_scan_card (tb_dfe);
  ic->ic_key = key;
  ic->ic_text_pred = text_pred;
  ic->ic_text_order = 1;
  dfe_text_cost (tb_dfe, &text_cost, &text_card, 1);
  ic->ic_unit = text_cost;
  ic->ic_arity = text_card;
  prefix = tb_dfe->_.table.ot->ot_new_prefix;
  tree = t_listst (5, BOP_EQ, t_listst (3, COL_DOTTED, prefix, id_col->col_name), t_listst (3, COL_DOTTED, prefix, id_col->col_name), NULL, NULL);
  *text_id_pred = sqlo_df (tb_dfe->dfe_sqlo, tree);
  return 1;
}


int
sqlo_ip_trailing_text (df_elt_t * tb_dfe, index_choice_t * ic)
{
  float text_cost = 0, text_card = ic->ic_arity;
  df_elt_t * text_pred =  tb_dfe->_.table.text_pred;
  if (!text_pred || text_pred->dfe_is_placed)
    return 0;
  dfe_text_cost (tb_dfe, &text_cost, &text_card, 0);
  ic->ic_unit += text_cost;
  ic->ic_arity *= text_card;
  ic->ic_text_pred = text_pred;
  return 1;
}


int
key_is_first_cond (df_elt_t * tb_dfe, dbe_key_t * key)
{
  QNCAST (dbe_column_t, part, key->key_parts->data);
  df_elt_t * pred = sqlo_key_part_best (part, tb_dfe->_.table.col_preds, 0);
  return dfe_is_eq_pred (pred) || dfe_is_range_pred (pred);
}


ts_action_t *
ic_col_tsa (df_elt_t * col_dfe)
{
  t_NEW_VARZ (ts_action_t, tsa);
  tsa->tsa_extract_col = col_dfe;
  return tsa;
}


int
tb_is_pk_part (dbe_table_t * tb, dbe_column_t * col)
{
  dbe_key_t * pk = tb->tb_primary_key;
  int n = pk->key_n_significant;
  DO_SET (dbe_column_t *, part, &pk->key_parts)
    {
      if (part == col)
	return 1;
      if (--n == 0)
	return 0;
    }
  END_DO_SET();
  return 0;
}


int
sqlo_tb_pk_given (df_elt_t * tb_dfe)
{
  /* true if there is an equality on each pk part */
  dbe_key_t * pk = tb_dfe->_.table.ot->ot_table->tb_primary_key;
  int n = pk->key_n_significant;
  DO_SET (dbe_column_t *, part, &pk->key_parts)
    {
      DO_SET (df_elt_t *, cp, &tb_dfe->_.table.col_preds)
	{
	  if (cp->_.bin.left->dfe_type != DFE_COLUMN)
	    continue;
	  if (cp->_.bin.left->_.col.col == part)
	    goto found;
	}
      END_DO_SET();
      return 0;
    found: ;
      if (--n == 0)
	return 1;
    }
  END_DO_SET();
  return 1;
}


op_table_t *
sqlo_ot_by_name (sqlo_t * so, char * pref, dbe_table_t * tb)
{
  op_table_t * ot;
  DO_SET (op_table_t *, ot, &so->so_tables)
    if (!strcmp (ot->ot_new_prefix, pref))
      return ot;
  END_DO_SET();
  ot = (op_table_t*)t_alloc (sizeof (op_table_t));
  memset (ot, 0, sizeof (op_table_t));
  ot->ot_table = tb;
  t_set_push (&so->so_tables, (void*)ot);
  ot->ot_new_prefix = t_box_string (pref);
  return ot;
}


int
sqlo_eqs_leading (df_elt_t * tb_dfe, dbe_key_t * key, dbe_column_t * part)
{
  /* true if all parts of key before col have an eq condition and col is in significant cols */
  int nth = 0;
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      df_elt_t * pred;
      if (part == col)
	return 1;
      pred = sqlo_key_part_best (col, tb_dfe->_.table.col_preds, 0);
      if (!dfe_is_eq_pred (pred))
	return 0;
      nth++;
      if (nth >= key->key_n_significant)
	return 0;
    }
  END_DO_SET();
  return 0;
}


df_elt_t *
sqlo_first_range_col (df_elt_t * tb_dfe, dbe_key_t * key, df_elt_t ** lower_ret, df_elt_t ** upper_ret)
{
  /* loop over key parts and return the col dfe of the first one that has a range cond */
  int nth = 0;
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      df_elt_t * pred = sqlo_key_part_best (col, tb_dfe->_.table.col_preds, 0);
      df_elt_t * upper = sqlo_key_part_best (col, tb_dfe->_.table.col_preds, 1);
      nth++;
      if (!pred && !upper)
	return NULL;
      if (nth > key->key_n_significant)
	return NULL;
      if (dfe_is_eq_pred (pred))
	continue;
      if (dfe_is_range_pred (pred) || dfe_is_range_pred (upper))
	      {
		*lower_ret = pred;
		*upper_ret = upper;
		return pred ? pred->_.bin.left : upper->_.bin.left;
	      }
    }
  END_DO_SET();
  return NULL;
}


dk_set_t
sqlo_key_applicable_preds (dk_set_t preds, dbe_key_t * key)
{
  dk_set_t res = NULL;
  DO_SET (df_elt_t *, pred, &preds)
    if (dk_set_member (key->key_parts, (void*)pred->_.bin.left->_.col.col))
      t_set_push (&res, (void*)pred);
  END_DO_SET();
  return res;
}


ST *
sqlo_rdf_string (ST * tree, int min)
{
  ST * c = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("rdf_box_data"),
		   t_listst (1, t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("__ro2sq"), t_listst (1, tree))));
  if (min)
    return t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("__RDF_RNG_MIN"), t_listst (1, c));
  return c;
}


ST *
sqlo_rdf_dt_lang_ck (char * r_prefix, char * dt_col_name, df_elt_t * lower, df_elt_t * upper)
{
  ST * ro = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("__ro2sq"), t_listst (1,
								     lower ? lower->dfe_tree->_.bin_exp.right : upper->dfe_tree->_.bin_exp.right));
  return t_listst (5, BOP_EQ, t_listst (3, COL_DOTTED, r_prefix, t_box_string (dt_col_name)), t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("rdf_box_dt_and_lang"), t_listst (1, ro)), NULL, NULL);
}


ST *
sqlo_rdf_range_ck (char * r_prefix, char * dt_col_name, df_elt_t * lower, df_elt_t * upper)
{
  ST * call = t_listst (3, CALL_STMT, sqlp_box_id_upcase ("__rdf_range_check"),
      t_listst (6,
	  t_listst (3, COL_DOTTED, r_prefix, t_box_string ("RS_START")),
	  t_listst (3, COL_DOTTED, r_prefix, t_box_string ("RS_RO_ID")),
				  lower ? lower->_.bin.right->dfe_tree : NULL,
	  lower ? (ptrlong) lower->_.bin.op : (ptrlong) 0,
	  upper ? upper->_.bin.right->dfe_tree : NULL,
	  upper ? (ptrlong) upper->_.bin.op : (ptrlong) 0));
  return t_listst (5, BOP_EQ, (ptrlong)1, call, NULL, NULL);
}


void
sqlo_rdf_string_range (df_elt_t * tb_dfe, index_choice_t * ic)
{
  /* make a dfe for string range lookup on o and another for joining to quad on o.  If the strings are literal, set the cost by the actual card  */
  df_elt_t * r_id_col_dfe, *ck;
  index_choice_t * ref_ic;
  ST * id_tree;
  caddr_t r_range_col_name;
  df_elt_t * r_range_col_dfe;
  sqlo_t * so = tb_dfe->dfe_sqlo;
  char r_pref[20];
  char * id_col_name, * dt_col_name;
  op_table_t * r_ot;
  caddr_t r_prefix;
  dbe_table_t * range_tb = sch_name_to_table (wi_inst.wi_schema, "DB.DBA.RO_START");
  dbe_key_t * first_key = ic->ic_key;
  df_elt_t *lower, *upper, *r_tb_dfe;
  df_elt_t * range_col_dfe = sqlo_first_range_col (tb_dfe, first_key, &lower, &upper);
  dbe_column_t * range_col;
  if (!range_tb || !range_col_dfe)
    return;
  id_col_name = ((dbe_column_t*) range_tb->tb_primary_key->key_parts->next->next->data)->col_name;
  dt_col_name = ((dbe_column_t*) range_tb->tb_primary_key->key_parts->next->data)->col_name;
  range_col = range_col_dfe->_.col.col;
  r_tb_dfe = sqlo_new_dfe (so, DFE_TABLE, NULL);
  snprintf (r_pref, sizeof (r_pref), "r%s", tb_dfe->_.table.ot->ot_new_prefix);
  r_ot = sqlo_ot_by_name (so, r_pref, range_tb);
  r_prefix = r_ot->ot_new_prefix;
  t_set_pushnew (&so->so_this_dt->ot_from_ots, (void*)r_ot);
  r_tb_dfe->_.table.ot = r_ot;
  r_range_col_name = ((dbe_column_t*)range_tb->tb_primary_key->key_parts->data)->col_name;
  r_range_col_dfe = sqlo_df (so, t_listst (3, COL_DOTTED, r_prefix, r_range_col_name));
  r_id_col_dfe = sqlo_df (so, t_listst (3, COL_DOTTED, r_prefix, id_col_name));
  if (lower)
    t_set_push (&r_tb_dfe->_.table.col_preds, (void*)sqlo_df (so, t_listst (5, lower->_.bin.op, r_range_col_dfe->dfe_tree, sqlo_rdf_string (lower->_.bin.right->dfe_tree, 1), NULL, NULL)));
  if (upper)
    t_set_push (&r_tb_dfe->_.table.col_preds, (void*)sqlo_df (so, t_listst (5, upper->_.bin.op, r_range_col_dfe->dfe_tree, sqlo_rdf_string (upper->_.bin.right->dfe_tree, 0), NULL, NULL)));
  t_set_push (&r_tb_dfe->_.table.col_preds, sqlo_df (so, sqlo_rdf_dt_lang_ck (r_prefix, dt_col_name, lower, upper)));
  id_tree = t_listst (3, COL_DOTTED, r_prefix, id_col_name);
  r_id_col_dfe = sqlo_df (so, id_tree);
  t_set_push (&r_tb_dfe->_.table.out_cols, (void*)r_id_col_dfe);
  r_tb_dfe->_.table.key = range_tb->tb_primary_key;
  DO_SET (df_elt_t *, pred, &r_tb_dfe->_.table.col_preds)
    sqlo_place_exp (so, tb_dfe, pred->_.bin.right);
  END_DO_SET();
  ck = sqlo_df (so, sqlo_rdf_range_ck (r_prefix, id_col_name, lower, upper));
  r_tb_dfe->_.table.join_test = sqlo_pred_body (so, LOC_LOCAL, r_tb_dfe, ck);
  ic->ic_o_range = r_tb_dfe;
  ref_ic = ic->ic_o_range_ref_ic = (index_choice_t *)t_alloc (sizeof (index_choice_t));
  *ref_ic = *ic;
  ref_ic->ic_o_range = NULL;
  ref_ic->ic_o_range_ref_ic = NULL;
  ref_ic->ic_col_preds = sqlo_key_applicable_preds (tb_dfe->_.table.col_preds, ic->ic_key);
  t_set_delete (&ref_ic->ic_col_preds, (void*)lower);
  t_set_delete (&ref_ic->ic_col_preds, (void*)upper);
  t_set_push (&ref_ic->ic_col_preds, (void*)sqlo_df (so, t_listst (5, BOP_EQ, range_col_dfe->dfe_tree, id_tree,NULL, NULL)));
}


int
sqlo_ip_has_s_or_o_range (dk_set_t path)
{
  DO_SET (index_choice_t *, ic, &path)
    {
      if (ic->ic_inx_op
	  || ic->ic_o_range
	  || ic->ic_text_pred)
	return 1;
      DO_SET (dbe_column_t *, part, &ic->ic_key->key_parts)
	if (!stricmp (part->col_name, "S"))
	  return 1;
      END_DO_SET();
    }
  END_DO_SET();
  return 0;
}


int
sqlo_key_has_s_before_o (dbe_key_t * key)
{
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      if (!stricmp (col->col_name, "S"))
	return 1;
      if (!stricmp (col->col_name, "O"))
	return 0;
    }
  END_DO_SET();
  return 0;
}


int
dfe_tb_o_range_comp (df_elt_t * left, df_elt_t * right, df_elt_t * tb_dfe)
{
  /* left is __ro2sq (tb.o) and right is independent of tb */
  ST * tree = left->dfe_tree;
  if (dk_set_member (right->dfe_tables, (void*)tb_dfe))
    return 0;
  if (ST_P (tree, CALL_STMT) && DV_STRINGP (tree->_.call.name)
      && !stricmp (tree->_.call.name, "__ro2sq")
      && 1 == BOX_ELEMENTS (tree->_.call.params)
      && DFE_COLUMN == left->_.call.args[0]->dfe_type
      && !stricmp ("O", tree->_.call.params[0]->_.col_ref.name)
      && dk_set_member (left->_.call.args[0]->dfe_tables, (void*)tb_dfe->_.table.ot))
    return 1;
  return 0;
}


int
dfe_is_o_ro2sq_range (df_elt_t * pred, df_elt_t * tb_dfe, df_elt_t ** o_col_dfe_ret, df_elt_t ** exp_dfe_ret, int * op_ret)
{
  /* if pred is __ro2sq (tb.o) <=> exp or exp <=> __ro2sq (tb.o) then return the o col dfe, the exp and the comparison */
  df_elt_t * left, * right;
  int op = pred->_.bin.op;
  if (!((DFE_BOP == pred->dfe_type || DFE_BOP_PRED == pred->dfe_type)
	&& (BOP_LT == op || BOP_LTE == op || BOP_GT == op || BOP_GTE == op)))
    return 0;
  left = pred->_.bin.left;
  right = pred->_.bin.right;
  if (dfe_tb_o_range_comp (left, right, tb_dfe))
    {
      *o_col_dfe_ret = left->_.call.args[0];
      *exp_dfe_ret = right;
      *op_ret = op;
      return 1;
    }
  if (dfe_tb_o_range_comp (right, left, tb_dfe))
    {
      *o_col_dfe_ret = right->_.call.args[0];
      *exp_dfe_ret = left;
      *op_ret = cmp_op_inverse (op);
      return 1;
    }
  return 0;
}


void
sqlo_rdf_o_range (df_elt_t * tb_dfe, dbe_key_t * key, dk_set_t path, index_choice_t * ic)
{
  /* if range cond on __ro2sq (o) and no spec on s, drop the __ro2sq's, mark these as eliminated and set the ic flag for rdf range opt
   * The new col preds drop after this index path branch returns */
  sqlo_t * so =tb_dfe->dfe_sqlo;
  if (sqlo_ip_has_s_or_o_range (path)
      || sqlo_key_has_s_before_o (key))
    return;
  DO_SET (df_elt_t *, pred, &so->so_after_preds)
    {
      df_elt_t * o_col_dfe, *exp_dfe;
      int op;
      if (dfe_is_o_ro2sq_range (pred, tb_dfe, &o_col_dfe, &exp_dfe, &op)
	  && sqlo_eqs_leading (tb_dfe, key, o_col_dfe->_.col.col))
	{
	  ST * tree = t_listst (5, (ptrlong)op, t_listst (3, COL_DOTTED, tb_dfe->_.table.ot->ot_new_prefix, o_col_dfe->_.col.col->col_name), exp_dfe->dfe_tree, NULL, NULL);
	  df_elt_t * col_dfe = sqlo_df (so, tree);
	  t_set_push (&ic->ic_eliminated_after_preds, (void*)pred);
	  t_set_push (&tb_dfe->_.table.col_preds, (void*)col_dfe);
	}
    }
  END_DO_SET();
  if (ic->ic_eliminated_after_preds)
    sqlo_rdf_string_range (tb_dfe, ic);
}


void
sqlo_key_add_pk_eqs (df_elt_t * tb_dfe, dbe_key_t * key, index_choice_t * ic, dk_set_t * col_preds_save)
{
  /* for each so far un-eq pk part given by key, put an extra pred dfe in the col preds for use in next inx on the path */
  /* if a partial key had a range cond, take the range cond out and put an eq in its place */
  DO_SET (dbe_column_t *, part, &key->key_parts)
    {
      df_elt_t * pred;
      if (!tb_is_pk_part (tb_dfe->_.table.ot->ot_table, part))
	continue;
      pred = sqlo_key_part_best (part, tb_dfe->_.table.col_preds, 0);
      if (!dfe_is_eq_pred (pred))
	{
	  /* the best is not an eq. Make an eq and remove all non-eq preds */
	  caddr_t pref = tb_dfe->_.table.ot->ot_new_prefix;
	  ST * col_tree;
	  ST * tree = t_listst (5, BOP_EQ, col_tree = t_listst (3, COL_DOTTED, pref, part->col_name), t_listst (3, COL_DOTTED, pref, part->col_name), NULL, NULL);
	  df_elt_t * eq_pred = sqlo_df (tb_dfe->dfe_sqlo, tree);
	  df_elt_t * col_dfe = sqlo_df (tb_dfe->dfe_sqlo, col_tree);
	  dk_set_t old_col_preds = tb_dfe->_.table.col_preds;
	  tb_dfe->_.table.col_preds = t_set_copy (old_col_preds);
	  DO_SET (df_elt_t *, range_pred, &old_col_preds)
	    if (range_pred->_.bin.left == col_dfe)
	      t_set_delete (&tb_dfe->_.table.col_preds, (void*)range_pred);
	  END_DO_SET();
	  t_set_push (&tb_dfe->_.table.col_preds, (void*)eq_pred);
	  t_set_push (&ic->ic_ts_action, (void*)ic_col_tsa (col_dfe));
	}
    }
  END_DO_SET ();
}


void
sqlo_index_path (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t path, int pk_given)
{
  op_table_t *ot = dfe_ot (tb_dfe);
  char * opt_inx_name = !path ? sqlo_opt_value (ot->ot_opts, OPT_INDEX) : NULL;
  DO_SET (dbe_key_t *, key, &tb_dfe->_.table.ot->ot_table->tb_keys)
    {
      df_elt_t * text_id_pred = NULL;
      dk_set_t old_cp = tb_dfe->_.table.col_preds;
      index_choice_t ic;
      if (opt_inx_name && !path)
	{
	  if (!key_matches_index_opt (key, opt_inx_name))
	    continue;
	}
      if (pk_given && !key->key_is_primary)
	continue;
      if (tb_dfe->_.table.ot->ot_table_refd_cols && !sqlo_key_any_refd (tb_dfe, key))
	continue;
      if (sqlo_is_key_used (path, key))
	continue;
      memset (&ic, 0, sizeof (ic));
      ic.ic_key = key;
      sqlo_rdf_o_range (tb_dfe, key, path, &ic);
      if (key->key_no_pk_ref && !key_is_first_cond (tb_dfe, key)
	  && !(tb_dfe->_.table.text_pred && !path) && !opt_inx_name)
	{
	  tb_dfe->_.table.col_preds = old_cp;
	  continue;
	}
      tb_dfe->_.table.key = key;
      if (!path && sqlo_ip_leading_text (tb_dfe, key, &ic, &text_id_pred))
	;
      else
	dfe_table_cost_ic (tb_dfe, &ic, 1);
      if (ic.ic_unit < so->so_best_index_cost || -1 == so->so_best_index_cost)
	{
	  t_set_push (&path, (void*)&ic);
	  ic.ic_col_preds = tb_dfe->_.table.col_preds;
	  sqlo_ic_set_tsa (tb_dfe, path);
	  if (sqlo_inx_path_complete (tb_dfe, path))
	    {
	      float best_cost = so->so_best_index_cost;
	      float cost;
	      if (text_id_pred)
		t_set_push (&ic.ic_col_preds, (void*)text_id_pred);
	      sqlo_ip_trailing_text (tb_dfe, &ic);
	      path = dk_set_nreverse (path);
	      cost = sqlo_index_path_cost (path, &best_cost, &so->so_best_index_card, &so->so_best_index_card_sure);
	      path = dk_set_nreverse (path);
	      if (cost < so->so_best_index_cost || -1 == so->so_best_index_cost)
		{
		  so->so_best_index_path = sqlo_ip_copy (tb_dfe, path);
		  so->so_best_index_cost = cost;
		}
	    }
	  else
	    {
	      if (text_id_pred)
		{
		  t_set_push (&tb_dfe->_.table.col_preds, (void*)text_id_pred);
		  t_set_pushnew (&ic.ic_col_preds, (void*)text_id_pred);
		}
	      if (!pk_given)
		{
		  sqlo_key_add_pk_eqs (tb_dfe, key, &ic, &old_cp);
		  pk_given = sqlo_tb_pk_given (tb_dfe);
		}
	      sqlo_index_path (so, tb_dfe, path, pk_given);
	    }
	  path = path->next;
	  tb_dfe->_.table.col_preds = old_cp;
	}
      sqlo_ic_unplace (tb_dfe->dfe_sqlo, &ic);
    }
  END_DO_SET();
}


void
sqlo_choose_index_path (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t * col_preds_ret, dk_set_t * after_preds_ret)
{
  dk_set_t col_preds = *col_preds_ret;
  dk_set_t after_preds = *after_preds_ret;
  dfe_list_set_placed (col_preds, 0);
  if (tb_dfe->_.table.text_pred)
    tb_dfe->_.table.text_pred->dfe_is_placed = 0;
  so->so_after_preds = after_preds;
  so->so_best_index_card_sure = 0;
  so->so_best_index_cost = -1;
  so->so_best_index_path = NULL;
  tb_dfe->_.table.index_path = NULL;
  sqlo_index_path (so, tb_dfe, NULL, 0);
  if (!so->so_best_index_path)
    sqlc_new_error (so->so_sc->sc_cc, "42000", "NOINP", "Table options specify an non-existent index or index path cannot be constructed");
  tb_dfe->_.table.index_path = so->so_best_index_path;
  tb_dfe->dfe_unit = so->so_best_index_cost;
  tb_dfe->dfe_arity = so->so_best_index_card;
  if (tb_dfe->_.table.text_pred)
    tb_dfe->_.table.text_pred->dfe_is_placed = DFE_PLACED;

  dfe_list_set_placed (col_preds, DFE_PLACED);
}


dk_mutex_t * alt_ts_mtx;

int
table_source_input_rdf_range (table_source_t * ts, caddr_t * inst, caddr_t * state)
{
  state_slot_t * rng = ts->ts_alternate_cd;
  caddr_t rng_val = qst_get (inst, rng);
  dtp_t dtp = DV_TYPE_OF (rng_val);
  if (DV_STRING == dtp || (DV_RDF == dtp && DV_STRINGP (((rdf_box_t*)rng_val)->rb_box)))
    {
      table_source_t * alt = ts->ts_alternate;
      mutex_enter (alt_ts_mtx);
      if (!alt->ts_alternate_inited)
	{
	  table_source_t * next = (table_source_t*)qn_next ((data_source_t*)alt);
	  if (!next) GPF_T1 ("alt ts must always have a next");
	  next->src_gen.src_after_test =ts->src_gen.src_after_test;
	  next->src_gen.src_after_code =ts->src_gen.src_after_code;
	  next->ts_order_ks->ks_local_code = ts->ts_order_ks->ks_local_code;
	  next->ts_order_ks->ks_local_test = ts->ts_order_ks->ks_local_test;
	  next->ts_order_ks->ks_setp = ts->ts_order_ks->ks_setp;
	  next->ts_order_ks->ks_is_last = ts->ts_order_ks->ks_is_last;
	  next->src_gen.src_continuations = dk_set_copy (ts->src_gen.src_continuations);
	  alt->ts_alternate_inited = 1;
	}
      mutex_leave (alt_ts_mtx);
      table_source_input (ts->ts_alternate, inst, state);
      return 1;
    }
  return 0;
}


data_source_t * sqlg_make_1_ts (sqlo_t * so, df_elt_t * tb_dfe, index_choice_t * ic, df_elt_t ** jt, int last);


table_source_t *
sqlg_rdf_string_range (df_elt_t * tb_dfe, table_source_t *org_ts, index_choice_t * ic)
{
    /* Make a ts that resolves a range cond on a string valued O from the leading chars table */
  key_source_t * ref_ks;
  search_spec_t * sp;
  table_source_t * r_ts, * range_ref_ts;
  sqlo_t * so = tb_dfe->dfe_sqlo;
  r_ts = (table_source_t*)sqlg_make_ts (so, ic->ic_o_range);
  r_ts->ts_is_alternate = TS_ALT_PRE;
  dfe_list_set_placed (ic->ic_o_range_ref_ic->ic_col_preds, DFE_PLACED);
  range_ref_ts = (table_source_t*)sqlg_make_1_ts (so, tb_dfe, ic->ic_o_range_ref_ic, tb_dfe->_.table.join_test, 0);
  range_ref_ts->ts_is_alternate = TS_ALT_POST;
  ref_ks = range_ref_ts->ts_order_ks;
  ref_ks->ks_out_cols = dk_set_copy (org_ts->ts_order_ks->ks_out_cols);
  ref_ks->ks_out_slots = dk_set_copy (org_ts->ts_order_ks->ks_out_slots);
  key_source_om (so->so_sc->sc_cc, ref_ks);
  dk_set_push (&r_ts->src_gen.src_continuations, (void*)range_ref_ts);
  org_ts->ts_alternate = r_ts;
  sp = r_ts->ts_order_ks->ks_spec.ksp_spec_array;
  org_ts->ts_alternate_cd = sp->sp_min_ssl ? sp->sp_min_ssl : sp->sp_max_ssl;
  org_ts->ts_alternate_test = table_source_input_rdf_range ;
  return r_ts;
}


df_elt_t **
sqlo_and_list_body_from_positions (sqlo_t * so, dk_set_t pred_pos, df_elt_t ** jt, dk_set_t in_list)
{
  int len = dk_set_length (pred_pos) + (in_list ? dk_set_length (in_list) : 0);
  if (len)
    {
      int inx = 1;
      df_elt_t ** terms = (df_elt_t **) t_alloc_box (sizeof (caddr_t) * (1 + len), DV_ARRAY_OF_POINTER);
      terms[0] = (df_elt_t*) BOP_AND;
      DO_SET (ptrlong, pos, &pred_pos)
	{
	  terms[inx++] = jt[pos + 1];
	}
      END_DO_SET();
      if (in_list)
	{
	  DO_SET (df_elt_t *, in, &in_list)
	    {
	      terms[inx++] = (df_elt_t*) t_list (2, DFE_PRED_BODY, in);
	    }
	  END_DO_SET();
	}
      return terms;
    }
  else
    return NULL;
}


void
sqlg_ic_tsa_out_cols (df_elt_t * tb_dfe, index_choice_t * ic)
{
  DO_SET (ts_action_t *, tsa, &ic->ic_ts_action)
    {
      if (tsa->tsa_extract_col)
	t_set_pushnew (&tb_dfe->_.table.out_cols, (void*)tsa->tsa_extract_col);
    }
  END_DO_SET();
}

void
sqlg_get_non_index_ins (df_elt_t * tb_dfe, dk_set_t * set)
{
  /* get the in preds that are not indexed in the after test */
  DO_SET (df_elt_t *, cp, &tb_dfe->_.table.col_preds)
    {
      if (DFE_GEN != cp->dfe_is_placed && sqlo_in_list (cp, NULL, NULL))
	{
	  t_set_push (set, (void *)cp);
	}
    }
  END_DO_SET();
}


void
sqlg_in_iter_add_after_test (sqlo_t * so, dk_set_t prev_in_iters, key_source_t * ks)
{
  /* videte et credite.  A fucking in iter over a key of a previous ks. If no pk ref inx, got to recheck the fucking col of the in pred. cause not joined on a unique key between inxes. */
  DO_SET (in_iter_node_t *, ii, &prev_in_iters)
    {
      df_elt_t ** in_list = sqlo_in_list (ii->ii_dfe, NULL, NULL);
      DO_SET (dbe_column_t *, col, &ks->ks_key->key_parts)
	{
	  if (col == in_list[0]->_.col.col)
	    {
	      NEW_VARZ (search_spec_t, sp);
	      sp->sp_min_ssl = ii->ii_output;
	      sp->sp_min_op = CMP_EQ;
	      sp->sp_next = ks->ks_row_spec;
	      ks->ks_row_spec = sp;
	      if (ks->ks_key->key_is_col)
		sp->sp_cl = *cl_list_find (ks->ks_key->key_row_var, col->col_id);
	      else
	      sp->sp_cl = *key_find_cl (ks->ks_key, col->col_id);
	    }
	}
      END_DO_SET();
    }
  END_DO_SET();
}

data_source_t *
sqlg_make_1_ts (sqlo_t * so, df_elt_t * tb_dfe, index_choice_t * ic, df_elt_t ** jt, int last)
{
  sql_comp_t * sc = so->so_sc;
  comp_context_t *cc = so->so_sc->sc_cc;
  char ord =so->so_sc->sc_order;
  key_source_t * order_ks;
  op_table_t * ot = tb_dfe->_.table.ot;
  dbe_table_t *table = ot->ot_table;
  dbe_key_t *order_key = ic->ic_key;
  dk_set_t in_list = NULL;
  dk_set_t prev_in_iters = so->so_in_list_nodes;
  SQL_NODE_INIT (table_source_t, ts, table_source_input, ts_free);
  sqlg_ic_tsa_out_cols (tb_dfe, ic);
  tb_dfe->_.table.col_preds = ic->ic_col_preds;
  if (HR_FILL == tb_dfe->_.table.hash_role)
    so->so_sc->sc_order = TS_ORDER_NONE;
  DO_SET (op_virt_col_t *, vc, &ot->ot_virtual_cols)
    {
      df_elt_t *vc_dfe =  sqlo_df_virt_col (so, vc);
      vc_dfe->dfe_ssl = sqlg_dfe_ssl (so, vc_dfe);
    }
  END_DO_SET ();
  if (ic->ic_text_pred)
    {
      if (!tb_dfe->_.table.text_pred)
	SQL_GPF_T1 (cc, "The contains pred present and not placed");
      tb_dfe->_.table.is_text_order = ic->ic_text_order;
      sqlg_text_node (so, tb_dfe, ic);
      if (ic->ic_text_order)
	{
	  /* the ts is after the text node.  Set the order in qr_nodes to reflect this */
	  dk_set_delete (&sc->sc_cc->cc_query->qr_nodes, (void*)ts);
	  dk_set_push (&sc->sc_cc->cc_query->qr_nodes, (void*)ts);
	}
    }
  if (ic->ic_key == table->tb_primary_key && (tb_dfe->_.table.xpath_pred || tb_dfe->_.table.is_xcontains))
    sqlg_xpath_node (so, tb_dfe);

  ts->ts_order = sc->sc_order;
  if (ic->ic_inx_op)
    {
      ts->ts_inx_op = sqlg_inx_op (so, tb_dfe, ic->ic_inx_op, NULL);
    }
  else
    {
      ts->ts_order_ks = sqlg_key_source_create (so, tb_dfe, order_key);
      ts->ts_order_ks->ks_descending = ot->ot_order_dir == ORDER_DESC && tb_dfe->_.table.is_oby_order;
    }
  if (!sc->sc_no_current_of)
    {
      char ct_id[MAX_NAME_LEN * 2 + 10];
      OT_ID (ot, ct_id);
      ts->ts_current_of = ssl_new_placeholder (cc, ct_id);
    }
  ts->ts_order_cursor = ssl_new_itc (cc);

  if (!last)
  sqlg_non_index_ins (tb_dfe);

  ts->ts_is_outer = tb_dfe->_.table.ot->ot_is_outer;
  order_ks = ts->ts_order_ks;
  if (order_ks && order_ks->ks_spec.ksp_spec_array)
    ts->ts_is_unique = ic->ic_is_unique;

  if (order_ks)
  sqlg_in_iter_add_after_test (so, prev_in_iters, order_ks);
    ks_set_search_params (cc, NULL, order_ks);
  if (ic->ic_text_pred)
    {
      sqlg_is_text_only (so, tb_dfe, ts);
      /* if in text order put the text node first, otherwise second */
      if (ic->ic_text_order && !tb_dfe->_.table.text_only)
	sql_node_append (&tb_dfe->_.table.text_node, (data_source_t*) ts);
      else if (!tb_dfe->_.table.text_only)
	sql_node_append ((data_source_t**) &ts, tb_dfe->_.table.text_node);
    }
  if (tb_dfe->_.table.xpath_node)
    sql_node_append ((data_source_t**) &ts, tb_dfe->_.table.xpath_node);
  /* list of all ins that are not iterators */
  if (last)
    sqlg_get_non_index_ins (tb_dfe, &in_list);
  else
  sqlg_non_index_ins (tb_dfe);
  ts->src_gen.src_after_test = sqlg_pred_body (so, sqlo_and_list_body_from_positions (tb_dfe->dfe_sqlo, ic->ic_after_preds, jt, in_list));
  if (ts->ts_is_unique)
    ts->src_gen.src_input = (qn_input_fn) table_source_input_unique;

  sqlc_update_set_keyset (sc, ts);
  sqlc_ts_set_no_blobs (ts);
  if (SC_UPD_PLACE != sc->sc_is_update && !sc->sc_in_cursor_def)
    ts->ts_current_of = NULL;
  if (!sc->sc_update_keyset && !sqlg_is_vector)
    ts_alias_current_of (ts);
  else if (!ts->ts_main_ks)
    ts->ts_need_placeholder = 1;
  table_source_om (sc->sc_cc, ts);

  if (ot->ot_opts && sqlo_opt_value (ot->ot_opts, OPT_RANDOM_FETCH))
    {
      caddr_t res = sqlo_opt_value (ot->ot_opts, OPT_RANDOM_FETCH);
      ts->ts_is_random = 1;
      ts->ts_rnd_pcnt = res;
    }
  if (ts->ts_order_ks && ot->ot_opts && sqlo_opt_value (ot->ot_opts, OPT_VACUUM))
    {
      sqlo_opt_value (ot->ot_opts, OPT_VACUUM);
      ts->ts_order_ks->ks_is_vacuum = 1;
    }
  ts->ts_cardinality = ic->ic_arity;
  ts->ts_inx_cardinality = ic->ic_inx_card;
  ts->ts_cost = ic->ic_unit;
  ts->ts_card_measured = 0 != ic->ic_leading_constants;
  so->so_sc->sc_order = ord;
  if (ic->ic_key->key_distinct || ic->ic_key->key_no_pk_ref)
    dfe_list_set_placed (ic->ic_col_preds, DFE_PLACED); /* if partial inx, must recheck the preds with a real inx, could be out of date */
  if (ic->ic_o_range)
    sqlg_rdf_string_range (tb_dfe, ts, ic);
  return (data_source_t *) ts;
}


data_source_t *
sqlg_make_path_ts (sqlo_t * so, df_elt_t * tb_dfe)
{
  data_source_t * ts, * ret_ts = NULL;
  table_source_t * last_ts = NULL;
  char ord =so->so_sc->sc_order;
  df_elt_t ** jt = tb_dfe->_.table.join_test; /* we store the join test before to execute sqlg_make_1_ts as ic_after_preds look at position */
  so->so_sc->sc_order = ord;
  so->so_in_list_nodes = NULL;
  DO_SET (index_choice_t *, ic, &tb_dfe->_.table.index_path)
    {
      ts = sqlg_make_1_ts (so, tb_dfe, ic, jt, nxt ? 0 : 1);
      last_ts = (table_source_t *) ts;
      if (!ret_ts)
	ret_ts = ts;
      else
	{
	sql_node_append (&ret_ts, ts);
	  if (IS_TS (ts))
	    ((table_source_t*)ts)->ts_in_index_path = 1;
	}
    }
  END_DO_SET();
  if (tb_dfe->_.table.after_join_test)
    last_ts->ts_after_join_test =  sqlg_pred_body (so, tb_dfe->_.table.after_join_test);
  return ret_ts;
}



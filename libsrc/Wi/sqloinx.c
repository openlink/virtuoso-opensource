/*
 *  sqloinx.c
 *
 *  $Id$
 *
 *  sql expression dependencies and code layout
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

#include <string.h>
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




int
sqlo_inx_int_eq_distinct_cols (dbe_key_t * key, int n_eqs, dk_set_t * eq_cols)
{
  /* when doing inx int on keys of a single table, make sure the leading eq's are on distinct cols.
   * Do not consider keys with an eq on all significant part, i.e. unique. */
  int nth = 0;
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      if (dk_set_member (*eq_cols, (void*) col))
	return 0;
      if (++nth >= n_eqs)
	break;
    }
  END_DO_SET();
  if (nth == key->key_n_significant)
    return 0;
  nth = 0;
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      t_set_push (eq_cols, (void*) col);
      if (++nth >= n_eqs)
	break;
    }
  END_DO_SET();
  return 1;
}


int
sqlo_key_is_intersectable (dk_set_t col_preds, dbe_key_t * k1, dbe_key_t * k2, int n_eqs, dk_set_t * eq_cols)
{
  /* does k2 have n_eqs leading eqs and after these n eqs the same parts as k1 */
  int nth, n_parts;
  for (nth = 0; nth < n_eqs; nth++)
    {
      df_elt_t * best;
      dbe_column_t * col = (dbe_column_t *)dk_set_nth (k2->key_parts, nth);
      if (!col)
	return 0;
      best = sqlo_key_part_best (col, col_preds, 0);
      if (!best || BOP_EQ != best->_.bin.op)
	return 0;
    }
  n_parts = dk_set_length (k1->key_parts);
  for (nth = n_eqs; nth < n_parts; nth++)
    {
      if (dk_set_nth (k1->key_parts, nth) != dk_set_nth (k2->key_parts, nth))
	return 0;
    }
  if (!sqlo_inx_int_eq_distinct_cols (k2, n_eqs, eq_cols))
    return 0;
  return 1;
}

int
sqlo_leading_eqs (dbe_key_t * key, dk_set_t col_preds)
{
  int n = 0;
  if (key->key_partition)
    return 0; /* inx int temp disabled for cluster */
  DO_SET(dbe_column_t *, col, &key->key_parts)
    {
      df_elt_t * pred = sqlo_key_part_best (col, col_preds, 0);
      if (!pred || BOP_EQ != pred->_.bin.op)
	return n;
      n++;
    }
  END_DO_SET();
  return n;
}


df_inx_op_t *
df_inx_op (df_elt_t * tb_dfe, dbe_key_t * key, dk_set_t key_preds)
{
  t_NEW_VARZ (df_inx_op_t, dio);
  dio->dio_op = IOP_KS;
  dio->dio_key = key;
  dio->dio_table = tb_dfe;
  dio->dio_given_preds = key_preds;
  return dio;
}



static void
sqlo_print_inx_intersect (df_elt_t * tb_dfe, dk_set_t group, float cost)
{
  dbe_table_t * tb = tb_dfe->_.table.ot->ot_table;
  printf ("Inx intersect  on %s: (", tb->tb_name);
  DO_SET (df_inx_op_t *, dio, &group)
    {
      printf (" %s ", dio->dio_key->key_name);
    }
  END_DO_SET();
  printf (") \n cost %f \n", cost);
}


void
sqlo_find_inx_intersect (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t col_preds, float best)
{
  dk_set_t best_group = NULL;
  float a1, cost, best_arity = 0;
  dbe_table_t * tb = tb_dfe->_.table.ot->ot_table;
  int n_eqs;
  return;
#if 0
  if (so->so_sc->sc_cc->cc_query && so->so_sc->sc_cc->cc_query->qr_proc_vectored)
    return;
  if (LOC_LOCAL != tb_dfe->dfe_locus)
    return;
  DO_SET (dbe_key_t *, k1, &tb->tb_keys)
    {
      if (k1 != tb->tb_primary_key && !k1->key_no_pk_ref)
	{
	  dk_set_t group = NULL, eq_cols = NULL;
	  n_eqs = sqlo_leading_eqs (k1, col_preds);
	  if (!n_eqs || n_eqs == k1->key_n_significant)
	    goto next;
	  sqlo_inx_int_eq_distinct_cols (k1, n_eqs, &eq_cols);
	  DO_SET (dbe_key_t *, k2, &tb->tb_keys)
	    {
	      if (k1 != k2 && !k2->key_is_primary && !k2->key_no_pk_ref
		  && sqlo_key_is_intersectable (col_preds, k1, k2, n_eqs, &eq_cols))
		{
		  if (!group)
		    t_set_push (&group, (void*) df_inx_op (tb_dfe,k1, NULL));
		  t_set_push (&group, (void*) df_inx_op (tb_dfe, k2, NULL));
		}
	      END_DO_SET();
	      /* group is now a set of intersectable inxes */
	      if (group)
		{
		  cost = sqlo_inx_intersect_cost (tb_dfe, col_preds, group, &a1);
		  if (sqlo_print_debug_output)
		    sqlo_print_inx_intersect (tb_dfe, group, cost);
		  if (cost < best)
		    {
		      best_group = group;
		      best = cost;
		      best_arity = a1;
		    }
		}
	    }
	next: ;
	}
    }
  END_DO_SET();
  if (best_group)
    {
      t_NEW_VARZ (df_inx_op_t, dio);
      dio->dio_terms = best_group;
      dio->dio_op = IOP_AND;
      tb_dfe->_.table.inx_op = dio;
      tb_dfe->dfe_unit = best;
      tb_dfe->dfe_arity = best_arity;
    }
#endif
}



/* functions for multiple table inx intersection */



int
sqlo_is_col_eq (op_table_t * ot, df_elt_t * col, df_elt_t * val)
{
  dk_set_t *place;
  if (col == val)
    return 1;
  if (!ot->ot_eq_hash)
    return 0;
  place = (dk_set_t *) id_hash_get (ot->ot_eq_hash, (caddr_t) &col->dfe_tree);
  if (!place)
    return 0;
  DO_SET (df_elt_t *, eq, place)
    {
      if (box_equal ((box_t) val->dfe_tree, (box_t) eq->dfe_tree))
	return 1;
    }
  END_DO_SET();
  return 0;
}


void
sqlo_col_eq (op_table_t * ot, df_elt_t * col, df_elt_t * val)
{
  dk_set_t *place, v = NULL;
  if (!ot->ot_eq_hash)
    {
      ot->ot_eq_hash =
	t_id_hash_allocate (33,
			    sizeof (caddr_t), sizeof (caddr_t),
			    treehash, treehashcmp);
    }
  place = (dk_set_t *) id_hash_get (ot->ot_eq_hash, (caddr_t) &col->dfe_tree);
  if (place)
    v = *place;
  t_set_pushnew (&v, (void *) val);
  if (DFE_COLUMN == val->dfe_type)
    {
      dk_set_t * eqs_place = (dk_set_t *) id_hash_get (ot->ot_eq_hash, (caddr_t) &val->dfe_tree);
      if (eqs_place)
	{
	  v = t_set_union (*eqs_place, v);
	}
    }
  t_id_hash_set (ot->ot_eq_hash, (caddr_t)&col->dfe_tree, (caddr_t) &v);
}


void
sqlo_init_eqs (sqlo_t * so, op_table_t * ot)
{
  if (!ot->ot_from_dfes || !ot->ot_from_dfes->next)
    return;
  DO_SET (df_elt_t *, pred, &ot->ot_preds)
    {
      if (DFE_BOP_PRED == pred->dfe_type && BOP_EQ == pred->_.bin.op)
	{
	  df_elt_t * left = pred->_.bin.left;
	  df_elt_t * right = right = pred->_.bin.right;
	  if (DFE_COLUMN == left->dfe_type && DFE_COLUMN == right->dfe_type)
	    {
	      sqlo_col_eq (ot, left, right);
	      sqlo_col_eq (ot, right, left);
	    }
	  else if (DFE_COLUMN == left->dfe_type)
	    sqlo_col_eq (ot, left, right);
	  else if (DFE_COLUMN == right->dfe_type)
	    sqlo_col_eq (ot, right, left);
	}
    }
  END_DO_SET();
}


df_elt_t *
dfe_col_placed_eq (sqlo_t *so, op_table_t * ot, df_elt_t * col_dfe)
{
  /* if this is a col and this is eq to a constant or an equal col exists that is placed, return it */
  dk_set_t * eqs_place;
  if (DFE_COLUMN != col_dfe->dfe_type)
    return col_dfe;
  if (!ot->ot_eq_hash)
    return col_dfe;
  eqs_place = (dk_set_t*) id_hash_get (ot->ot_eq_hash, (caddr_t) &col_dfe->dfe_tree);
  DO_SET (df_elt_t *, c, eqs_place)
    {
      if (DFE_CONST == c->dfe_type)
	return c;
      if (DFE_COLUMN == c->dfe_type)
	{
	  df_elt_t * def = dfe_col_def_dfe (so, c);
	  if (def)
	    return c;
	}
    }
  END_DO_SET();
  return col_dfe;
}

df_elt_t *
dfe_trans_rewrite (sqlo_t * so, df_elt_t * tb_dfe, df_elt_t * pred)
{
  op_table_t * ot = so->so_this_dt;
  if (DFE_BOP == pred->dfe_type
      && pred->_.bin.right)
    {
      df_elt_t * left = pred->_.bin.left;
      df_elt_t * right = pred->_.bin.right;
      df_elt_t * left2 = dfe_col_placed_eq (so, ot, left);
      df_elt_t * right2 = dfe_col_placed_eq (so, ot, right);
      if (left != left2 || right != right2)
	{
	  ST * pred_tree;
	  BIN_OP (pred_tree, pred->_.bin.op, left->dfe_tree, right->dfe_tree);
	  return sqlo_df (so, pred_tree);
	}
    }
  return NULL;
}


int
dfe_reqd_placed_tb (df_elt_t * dfe, df_elt_t * tb)
{
  /* true if pred depends on tb plus all other required are placed */
  int tb_found = 0;
  DO_SET (op_table_t *, req, &dfe->dfe_tables)
    {
      if (req == tb->_.table.ot)
	tb_found = 1;
      else if (req->ot_dfe
	       || !req->ot_dfe->dfe_is_placed)
	return 0;
    }
  END_DO_SET();
  return tb_found;
}


void
sqlo_tb_inx_int_preds (sqlo_t *so, df_elt_t * tb_dfe)
{
  /* col preds that depend on the table plus previously placed */
  op_table_t * ot = so->so_this_dt;
  dk_set_t col_preds = NULL;
  dk_set_t all_preds = NULL;
  tb_dfe->_.table.col_preds = NULL;
  tb_dfe->_.table.all_preds = NULL;
  DO_SET (df_elt_t *, pred, &ot->ot_preds)
    {
      if (dfe_reqd_placed_tb (pred, tb_dfe))
	{
	  if (DFE_TEXT_PRED == pred->dfe_type)
	    return;
	}
      else
	{
	  pred = NULL; /*dfe_trans_rewrite  (so, tb_dfe, pred); */
	  if (!pred)
	    continue;
	}
      t_set_push (&all_preds, pred);
      if (DFE_BOP_PRED == pred->dfe_type)
	{
	  if (pred->_.bin.left->dfe_type == DFE_COLUMN
	      && ts_predicate_p (pred->_.bin.op)
	      && (op_table_t *) pred->_.bin.left->dfe_tables->data == tb_dfe->_.table.ot
	      && !dk_set_member (pred->_.bin.right->dfe_tables, (void*) tb_dfe->_.table.ot))
	    {
	      t_set_push (&col_preds, pred);
	    }
	  else if (pred->_.bin.right->dfe_type == DFE_COLUMN
	      && ts_predicate_p (pred->_.bin.op)
	      && (op_table_t *) pred->_.bin.right->dfe_tables->data == tb_dfe->_.table.ot
	      && -1 != cmp_op_inverse (pred->_.bin.op)
	      && !dk_set_member (pred->_.bin.left->dfe_tables, (void*) tb_dfe->_.table.ot))
	    {
	      ptrlong op = cmp_op_inverse (pred->_.bin.op);
	      ST * inv_tree = (ST *) t_list (4, op, pred->_.bin.right->dfe_tree, pred->_.bin.left->dfe_tree, NULL);
	      df_elt_t * inv_pred = sqlo_df (so, inv_tree);
	      /* make the inv pred with a real tree for use in vdb locality analysis etc. */
	      inv_pred->_.bin.left = pred->_.bin.right;
	      inv_pred->_.bin.right = pred->_.bin.left;
	      inv_pred->_.bin.op = (int) cmp_op_inverse (pred->_.bin.op);
	      t_set_push (&col_preds, inv_pred);
	    }

	}
    }
  END_DO_SET();
  tb_dfe->_.table.col_preds = col_preds;
}


void
sqlo_prepare_inx_int_preds (sqlo_t * so)
{
  op_table_t * ot = so->so_this_dt;
  DO_SET (df_elt_t *, tb_dfe, &ot->ot_from_dfes)
    {
      if (DFE_TABLE == tb_dfe->dfe_type && !tb_dfe->dfe_is_placed && !tb_dfe->_.table.is_leaf)
	sqlo_tb_inx_int_preds (so, tb_dfe);
    }
  END_DO_SET();
}

int
sqlo_tb_inx_intersectable (sqlo_t * so, df_elt_t * tb_dfe, df_elt_t * joined, int n_eqs)
{
  /* tb_dfe is placed and has in inx with leading eqs.  See if joined can be inx intersected */
  if (tb_dfe->_.table.ot->ot_rds  || joined->_.table.ot->ot_rds)
    return 0;
  tb_dfe->dfe_is_placed = 0; /* consider only preds that do not depend on the first table */
  DO_SET (dbe_key_t *, key, &joined->_.table.ot->ot_table->tb_keys)
    {
      if (key->key_no_pk_ref)
	continue;
      if (dk_set_is_subset (key->key_parts, joined->_.table.ot->ot_table_refd_cols))
	{
	  int n_eqs2 = sqlo_leading_eqs (key, joined->_.table.col_preds);
	  if (n_eqs2 && key->key_n_significant - n_eqs2 == tb_dfe->_.table.key->key_n_significant - n_eqs
	      && key->key_n_significant > n_eqs2
	      && (!key->key_is_bitmap || n_eqs2 == key->key_n_significant - 1))
	    {
	      /* equal and non-zero no of free vars.  But if bm inx, then only one free var allowed. */
	      int nth;
	      for (nth = 0; nth < key->key_n_significant - n_eqs2; nth++)
		{
		  dbe_column_t * tb_col = (dbe_column_t *) dk_set_nth (tb_dfe->_.table.key->key_parts, nth + n_eqs);
		  dbe_column_t * joined_col = (dbe_column_t *) dk_set_nth (key->key_parts, nth + n_eqs2);
		  df_elt_t * col_dfe = sqlo_df (so, (ST*) t_list (3, COL_DOTTED, tb_dfe->_.table.ot->ot_new_prefix, tb_col->col_name));
		  df_elt_t * joined_col_dfe = sqlo_df (so, (ST*) t_list (3, COL_DOTTED, joined->_.table.ot->ot_new_prefix, joined_col->col_name));
		  if (!sqlo_is_col_eq (so->so_this_dt, col_dfe, joined_col_dfe))
		    goto next_key;
		}
	      /* found key that starts with eq of given and ends with eqs to free key parts of the first table */
	      joined->_.table.key = key;
	      return 1;
	    }
	}
    next_key: ;
    }
  END_DO_SET();
  return 0;
}


int
sqlo_opts_inx_int (caddr_t * opts)
{
  int inx, len;
  if (!opts)
    return 1;
  len = BOX_ELEMENTS (opts);
  for (inx = 0; inx < len; inx += 2)
    {
      switch ((ptrlong)opts[inx])
	{
	case OPT_JOIN: case OPT_INDEX:
	case OPT_RANDOM_FETCH:
	  return 0;
	}
    }
  return 1;
}


void
inx_int_add (dk_set_t * group_ret, df_inx_op_t * ins_dio)
{
  /* add in order of asc cardinality */
  dk_set_t *prev = group_ret;
  dk_set_t list = *group_ret;
  float ov;
  if (0 == ins_dio->dio_table->dfe_unit)
    {
      ins_dio->dio_table->dfe_locus = LOC_LOCAL; /* always local since inx int not done otherwise but set here cause cost func does not use a sample if not set */
      dfe_table_cost (ins_dio->dio_table, &ins_dio->dio_table->dfe_unit, &ins_dio->dio_table->dfe_arity, &ov, 1);
    }
  while (list)
    {
      df_inx_op_t * dio = (df_inx_op_t *)list->data;
      if (ins_dio->dio_table->dfe_arity < dio->dio_table->dfe_arity)
	{
	  t_set_push (prev, (void*)ins_dio);
	  return;
	}
      prev = &list->next;
      list = list->next;
    }
  t_set_push (prev, (void*)ins_dio);
}


int inx_int_join = 1;

void
sqlo_try_inx_int_joins (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t * group_ret, float * best_group)
{
  /* the key of tb_dfe is non-unq and begins with eqs and coers all cols */
  op_table_t * ot = so->so_this_dt;
  int n_eqs;
  dk_set_t group = NULL;
  if (!inx_int_join || (so->so_sc->sc_cc->cc_query && so->so_sc->sc_cc->cc_query->qr_proc_vectored))
    return;
  if (tb_dfe->_.table.is_unique
      || tb_dfe->_.table.ot->ot_rds
      || tb_dfe->_.table.index_path)
    return;
  n_eqs = sqlo_leading_eqs (tb_dfe->_.table.key, tb_dfe->_.table.col_preds);
  if (!n_eqs
      || (n_eqs != tb_dfe->_.table.key->key_n_significant - 1 && tb_dfe->_.table.key->key_is_bitmap)
      || !dk_set_is_subset (tb_dfe->_.table.key->key_parts, tb_dfe->_.table.ot->ot_table_refd_cols))
    return;


  DO_SET (df_elt_t *, joined, &ot->ot_from_dfes)
    {
      if (!joined->dfe_is_placed
	  && joined != tb_dfe
	  && DFE_TABLE == joined->dfe_type
	  && !joined->_.table.ot->ot_is_outer
	  && !joined->_.table.ot->ot_rds
	  && sqlo_opts_inx_int (joined->_.table.ot->ot_opts))
	{
	  if (sqlo_tb_inx_intersectable (so, tb_dfe, joined, n_eqs))
	    {
	      if (!group)
		t_set_push (&group, (void*) df_inx_op (tb_dfe, tb_dfe->_.table.key, NULL));
	      inx_int_add (&group, df_inx_op (joined, joined->_.table.key, NULL));
	    }
	}
    }
  END_DO_SET();
  tb_dfe->dfe_is_placed = DFE_PLACED;
  if (dk_set_length (group) > dk_set_length (*group_ret))
    *group_ret = group;
}


int inx_int_prune = 1; /* if true, do not try other permutations of the inx ints */

void
sqlo_place_inx_int_join (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t group,
			 dk_set_t * after_preds)
{
  /* tb_dfe is placed.  The group is it and inx anded tables with it.  and as Take all preds and place their merge
   */
  op_table_t * ot = so->so_this_dt;
  dk_set_t all_preds = NULL;
  t_NEW_VARZ (df_inx_op_t, dio);
  dio->dio_terms = group;
  dio->dio_op = IOP_AND;
  dio->dio_is_join = 1;
  tb_dfe->_.table.inx_op = dio;
  DO_SET (df_inx_op_t *, dio, &group)
    {
      if (!dio->dio_table->dfe_is_placed)
	{/* one of them is already placed, preds and all. */
	  if (inx_int_prune && so->so_inx_int_tried_ret)
	    t_set_push (so->so_inx_int_tried_ret, (void*)dio->dio_table);
	  DO_SET (df_elt_t *, cp, &dio->dio_table->_.table.col_preds)
	    {
	      cp->dfe_is_placed = DFE_PLACED;
	      t_set_pushnew (&dio->dio_table->_.table.all_preds, (void*)cp);
	      sqlo_place_exp (so, tb_dfe, cp->_.bin.right);
	    }
	  END_DO_SET();
	}
      dio->dio_table->dfe_is_placed = DFE_PLACED;
      DO_SET (df_elt_t *, cp, &dio->dio_table->_.table.all_preds)
	{
	  if (!dk_set_member (dio->dio_table->_.table.col_preds, (void*)cp))
	    t_set_push (&all_preds, (void*) cp);
	  cp->dfe_is_placed = DFE_PLACED;
	}
      END_DO_SET();

    }
  END_DO_SET();
  /* now place all preds that depend on the intersected tables */
  DO_SET (df_elt_t *, pred, &ot->ot_preds)
    {
      if (!pred->dfe_is_placed
	  && dfe_reqd_placed (pred))
	t_set_push (&all_preds, (void*) pred);
    }
  END_DO_SET();
  /* special thing.  Add the preds that join the branches of the inx int join to all preds of the first tb dfe cause if not, these are marked placed but never unplaced when the inx int join is unplaced, hence the rest of the compilation will proceed with these preds missing and produce an incorrect result. */
  tb_dfe->_.table.all_preds = t_set_union (all_preds, tb_dfe->_.table.all_preds);
  *after_preds = all_preds;
}








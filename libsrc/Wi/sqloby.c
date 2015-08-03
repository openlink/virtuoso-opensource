/*
 *  sqloby.c
 *
 *  $Id$
 *
 *  sql order and group compilation
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
#include "sqlo.h"
#include "list2.h"







#define SPEC_ALL_COLS 1
#define SPEC_MIXED 0

int
sqlo_oby_exp_cols (sqlo_t * so, ST * dt, ST** oby)
{
  int inx;
  int res = SPEC_ALL_COLS;
  DO_BOX (ST *, spec, inx, oby)
    {
      if (INTEGERP (spec->_.o_spec.col))
	{
	  ptrlong nth = unbox ((box_t) spec->_.o_spec.col) - 1;
	  if ((uint32)nth >= (ptrlong) BOX_ELEMENTS (dt->_.select_stmt.selection))
	    sqlc_error (so->so_sc->sc_cc, "37000", "index of column in order by out of range");
	  spec->_.o_spec.col = (ST*) t_box_copy_tree (dt->_.select_stmt.selection[nth]);
	  while (ST_P (spec->_.o_spec.col, BOP_AS))
	    spec->_.o_spec.col = spec->_.o_spec.col->_.as_exp.left;
	}
      if (!ST_COLUMN (spec->_.o_spec.col, COL_DOTTED))
	res = SPEC_MIXED;
    }
  END_DO_BOX;
  return res;
}


void
sqlo_ot_group (sqlo_t * so, op_table_t * from_ot)
{
  /* if there are fun refs and no group, take out the oby
   * if there is an oby */
  ST * dt = from_ot->ot_dt;
  ST * texp = dt->_.select_stmt.table_exp;
  int inx;
  if (!from_ot->ot_fun_refs)
    {
      if (texp->_.table_exp.group_by)
	{
	  op_table_t * ot = so->so_this_dt;
	  if (!ot->ot_group_ot)
	    {
	      ST *dt = ot->ot_dt;
	      t_NEW_VARZ (op_table_t, got);
	      ot->ot_group_ot = got;
	      got->ot_is_group_dummy = 1;
	      ot->ot_group_dfe = sqlo_new_dfe (so, DFE_GROUP, NULL);
	      ot->ot_group_dfe->_.setp.specs = dt->_.select_stmt.table_exp->_.table_exp.group_by;
	      ot->ot_group_dfe->_.setp.top_cnt = sqlo_select_top_cnt (so, SEL_TOP (dt));
	    }
	}
      return;
    }

#if 0 /* - not so correct duplicate of sqlo_select_scope - does not count aggr in oby */
  if (!from_ot->ot_group_ot && texp->_.table_exp.order_by)
    {
      /* no group but fun refs means 1 row hence no point in oby */
      texp->_.table_exp.order_by = NULL;
    }
#endif
  if (!texp->_.table_exp.group_by)
    {
      DO_BOX (ST *, exp, inx, dt->_.select_stmt.selection)
	{
	  df_elt_t * dfe = sqlo_df (so, exp);
	  op_table_t * dep = CAR (op_table_t *, dfe->dfe_tables);
	  if (dep && (dep != from_ot->ot_group_ot || CDR (dfe->dfe_tables)))
	    sqlc_error (so->so_sc->sc_cc, "37000", "A selection which has aggregates but no group by must consist of aggregates only.");
	}
      END_DO_BOX;
      return;
    }
  sqlo_oby_exp_cols (so, dt, texp->_.table_exp.group_by);
}


ptrlong
sqlo_select_top_cnt (sqlo_t *so, ST *top_exp)
{
  ptrlong res = 0;
  if (top_exp)
    {
      if (DFE_IS_CONST (sqlo_df (so, top_exp->_.top.exp)) &&
	  DFE_IS_CONST (sqlo_df (so, top_exp->_.top.skip_exp)) &&
	  DV_TYPE_OF (top_exp->_.top.exp) == DV_LONG_INT &&
	  DV_TYPE_OF (top_exp->_.top.skip_exp) == DV_LONG_INT)
	{
	  res = MAX (0, unbox ((box_t) top_exp->_.top.exp) - unbox ((box_t) top_exp->_.top.skip_exp));
	}
      else
	res = 200;
    }
  return res;
}


void
sqlo_ot_oby_seq (sqlo_t * so, op_table_t * top_ot)
{
  ST * col;
  dk_set_t new_tables = NULL, tables = NULL;
  ST * texp, **oby;
  ST * dt = top_ot->ot_dt;
  op_table_t * col_ot, * prev_ot = NULL;
  int inx;
  df_elt_t * col_dfe;
  ST *top_exp = SEL_TOP (dt);

  if (!ST_P (dt, SELECT_STMT))
    return;
  texp = dt->_.select_stmt.table_exp;
  if (texp->_.table_exp.group_by)
    sqlo_ot_group (so, top_ot);
  oby = texp->_.table_exp.order_by;
  if (!oby)
    return;

  top_ot->ot_oby_dfe = sqlo_new_dfe (so, DFE_ORDER, NULL);
  top_ot->ot_oby_dfe->_.setp.specs = oby;
  top_ot->ot_oby_dfe->_.setp.top_cnt = sqlo_select_top_cnt (so, top_exp);
  DO_BOX (ST *, spec, inx, texp->_.table_exp.order_by)
    {
      df_elt_t * oby_dfe = sqlo_df (so, spec->_.o_spec.col);
      tables = t_set_union (oby_dfe->dfe_tables, tables);
    }
  END_DO_BOX;
  top_ot->ot_oby_dfe->dfe_tables = tables;

  DO_BOX (ST *, spec, inx, oby)
    {
      if (!ST_COLUMN (spec->_.o_spec.col, COL_DOTTED))
	return;
      col = spec->_.o_spec.col;
      col_ot = sqlo_cname_ot (so, col->_.col_ref.prefix);
      if (col_ot != prev_ot && col_ot->ot_order_cols)
      {
	/* there's order cols from same table non-contiguous in ordering */
	return;
      }
      if (col_ot != prev_ot)
	{
	  prev_ot = col_ot;
	  col_ot->ot_order_dir = (char) spec->_.o_spec.order;
	  TNCONCF1 (new_tables, col_ot);
	}
      col_dfe = sqlo_df (so, col);
      TNCONCF1 (prev_ot->ot_order_cols, col_dfe);
      if (col_ot->ot_order_dir != spec->_.o_spec.order)
	{
	  col_ot->ot_order_dir = OT_ORDER_MIXED;
	  return;
	}
    }
  END_DO_BOX;
  /* we have an oby composed of columns which are grouped by table.  */

  top_ot->ot_oby_ots = new_tables;
}


int
sqlo_is_seq_in_oby_order (sqlo_t * so, df_elt_t * dfe, df_elt_t * last_tb)
{
  op_table_t * from_ot = so->so_this_dt;
  int n_ordered = from_ot ? dk_set_length (from_ot->ot_oby_ots) : -1;
  int n_in_order = 0;
  for (dfe = dfe; dfe; dfe = dfe->dfe_next)
    {
      if (dfe == last_tb)
	return 1;
      if (dfe->dfe_type == DFE_TABLE)
	{
	  if (dfe->_.table.hash_role == HR_REF && !dfe->_.table.is_unique)
	    return 0;
	  if (dfe->_.table.ot->ot_is_outer)
	    return 0; /* vectored outer puts all the nulls at the end, not in key order */
	  if (! (dfe->_.table.is_oby_order
		 || dfe->_.table.is_unique))
	    return 0;
	  if (dfe->_.table.is_oby_order)
	    {
	      n_in_order++;
	      if (n_in_order == n_ordered)
		return 1;
	    }
	}
      else if (DFE_DT == dfe->dfe_type)
	return 0; /* a dfe found before all ordered ones were found */
    }
  return 1;
}


int
sqlo_all_explicit_oby_placed (dk_set_t dfes, df_elt_t * last_tb, dk_set_t oby_ots)
{
  op_table_t *last_ot = dfe_ot (last_tb);
  if (-1 == dk_set_position (oby_ots, last_ot))
    {
      DO_SET (df_elt_t *, dfe, &dfes)
	{
	  if (dfe->dfe_type == DFE_TABLE || dfe->dfe_type == DFE_DT)
	    {
	      op_table_t *ot = dfe_ot (dfe);
	      if (!dfe->dfe_is_placed && -1 != dk_set_position (oby_ots, ot))
		return 0;
	    }
	}
      END_DO_SET ();
    }
  return 1;
}


int
sqlo_is_key_in_order (sqlo_t * so, df_elt_t * dfe, dbe_key_t * key)
{
  int n_parts = key->key_is_primary ? key->key_n_significant : dk_set_length (key->key_parts);
  int nth_part = 0;
  op_table_t * ot = dfe->_.table.ot;
  dk_set_t oby_cols = ot->ot_order_cols;
  DO_SET (dbe_column_t *, col,&key->key_parts)
    {
      dbe_column_t * oby_col;
      if (!oby_cols)
	return 1;
      if (nth_part == n_parts)
	break;
      oby_col = ((df_elt_t *) oby_cols->data)->_.col.col;
      DO_SET (df_elt_t *, pred, &dfe->_.table.col_preds)
	{
	  df_elt_t ** in_list;
	  if ((in_list = sqlo_in_list (pred, NULL, NULL))
	      && col == in_list[0]->_.col.col)
	    return 0;
	  if (BOP_EQ == pred->_.bin.op
	      && col == pred->_.bin.left->_.col.col)
	    {
	      if (col == oby_col)
		goto check_next_key_part;
	      else
		goto part_had_eq_pred;
	    }
	}
      END_DO_SET();
      if (col != oby_col)
	return 0;
    check_next_key_part:
      oby_cols = oby_cols->next;
    part_had_eq_pred:
      nth_part++;
    }
  END_DO_SET();
  /* exhausted key parts. If index non-unique and more order needed, fail */
  if (!key->key_is_unique)
    return 1;
  if (oby_cols)
    return 0;
  return 1; /* as many key parts as order cols */
}


float
sqlo_tb_key_cost (df_elt_t * tb_dfe, dbe_key_t * key, dk_set_t preds, int * is_unq)
{
  float u, a, o;
  dbe_key_t * old_key = tb_dfe->_.table.key;
  int unq = tb_dfe->_.table.is_unique;
  dk_set_t old_preds = tb_dfe->_.table.col_preds;
  tb_dfe->_.table.key = key;
  tb_dfe->_.table.col_preds = preds;
  tb_dfe->dfe_unit = 0;
  dfe_table_cost (tb_dfe, &u, &a, &o, 0);
  *is_unq = tb_dfe->_.table.is_unique;
  tb_dfe->_.table.col_preds = old_preds;
  tb_dfe->_.table.is_unique = unq;
  tb_dfe->_.table.key = old_key;
  return u;
}

int
sqlo_try_oby_order (sqlo_t * so, df_elt_t * tb_dfe)
{
  op_table_t * from_ot = so->so_this_dt;
  op_table_t * ot = tb_dfe->_.table.ot;
  float best_cost = -1;
  dbe_key_t *best = NULL;
  int is_unq, oby_nth;
  dk_set_t col_preds = tb_dfe->_.table.all_preds;

  caddr_t opt_inx_name;
  int is_pk_inx = 0, is_txt_inx = 0, was_col_desc = 0;

  /* dbe_key_t * prev_key = tb_dfe->_.table.key; */
  if (from_ot->ot_group_dfe)
    return 0;
  if (DFE_TABLE != tb_dfe->dfe_type)
    return 0;
  if (!from_ot->ot_oby_ots)
    return 0;
  if (!sqlo_is_seq_in_oby_order (so, from_ot->ot_work_dfe->_.sub.first, tb_dfe))
    return 0;
  if (OT_ORDER_MIXED == ot->ot_order_dir)
    return 0;
  if (!sqlo_all_explicit_oby_placed (from_ot->ot_from_dfes, tb_dfe, from_ot->ot_oby_ots))
    return 0;
  if (!ot->ot_table)
    return 0;
  if (!ot->ot_order_cols)
    return 0;
  if (-1 != (oby_nth = dk_set_position (from_ot->ot_oby_ots, ot)))
    {
      /* not allow index order in cases where the first oby col is not in the driving table */
      df_elt_t *prev = tb_dfe;
      int tb_found = 0;
      while (NULL != (prev = prev->dfe_prev))
	{
	  if (prev->dfe_type == DFE_TABLE && prev->_.table.ot)
	    {
	      int prev_nth = dk_set_position (from_ot->ot_oby_ots, prev->_.table.ot);
	      if (prev_nth == -1 || prev_nth > oby_nth)
		return 0;
	      else
		tb_found = 1;
	    }
	}
      /* not allow tables to be placed in index order if no tables were palced
	 and the table does not have the first oby col */
      if (!tb_found && oby_nth > 0)
	return 0;
    }

  opt_inx_name = sqlo_opt_value (ot->ot_opts, OPT_INDEX);

  if (opt_inx_name && !strcmp (opt_inx_name, "PRIMARY KEY"))
    {
    is_pk_inx = 1;
      opt_inx_name = tb_dfe->_.table.ot->ot_table->tb_primary_key->key_name;
    }
  else if (opt_inx_name && !strcmp (opt_inx_name, "TEXT KEY"))
    is_txt_inx = 1;

  if (is_pk_inx)
    {
      if (!sqlo_is_key_in_order (so, tb_dfe, ot->ot_table->tb_primary_key))
	return 0;
      else
	{
	  sqlo_tb_key_cost (tb_dfe, ot->ot_table->tb_primary_key, col_preds, &is_unq);
	  if (is_unq)
	    tb_dfe->_.table.is_unique = 1;
	  if (!is_unq && ot->ot_table->tb_primary_key->key_is_col && ORDER_DESC == ot->ot_order_dir)
	    best = NULL; /* can't read col inx backwards */
	  else
	  best = ot->ot_table->tb_primary_key;
	}
    }
  else if (is_txt_inx || tb_dfe->_.table.index_path)
    return 0;

  DO_SET (dbe_key_t *, key, &ot->ot_table->tb_keys)
    {
      if (key->key_no_pk_ref)
	continue;
      if (opt_inx_name)
	{
	  if (key_matches_index_opt (key, opt_inx_name))
	    {
	      if (!sqlo_is_key_in_order (so, tb_dfe, key))
		return 0;
	      else
		{
		  sqlo_tb_key_cost (tb_dfe, key, col_preds, &is_unq);
		  if (is_unq)
		    tb_dfe->_.table.is_unique = 1;
		  if (!is_unq && key->key_is_col  && ORDER_DESC == tb_dfe->_.table.ot->ot_order_dir)
		    {
		      was_col_desc = 1;
		    best = NULL;
		    }
		  else
		  best = key;
		  break;
		}
	    }
	}
      else if (sqlo_is_key_in_order (so, tb_dfe, key))
	{
	  if (1 /*key != prev_key */)
	    {
	      float cost  = sqlo_tb_key_cost (tb_dfe, key, tb_dfe->_.table.all_preds, &is_unq);
	      if (key->key_is_col && ORDER_DESC == tb_dfe->_.table.ot->ot_order_dir)
		was_col_desc = 1;
	      if ((is_unq || cost < best_cost || -1 == best_cost)
		  && !(key->key_is_col && ORDER_DESC == tb_dfe->_.table.ot->ot_order_dir))
		{
		  best_cost = cost;
		  best = key;
		  if (is_unq)
		    {
		      tb_dfe->_.table.is_unique = is_unq;
		      break;
		    }
		}
	    }
	}
    }
  END_DO_SET();

  if (opt_inx_name && !best && !was_col_desc)
    sqlc_new_error (so->so_sc->sc_cc, "22023", "SQ189", "TABLE OPTION index %s not defined for table %s",
	opt_inx_name, ot->ot_table->tb_name);

  if (best)
    {
/*      if (tb_dfe->_.table.key != best)
	{*/
	  so->so_gen_pt = tb_dfe->dfe_prev;
	  sqlo_dt_unplace (so, tb_dfe);
	  tb_dfe->_.table.key = best;
	  tb_dfe->dfe_unit = 0; /*recalc the cost next time */
	  sqlo_place_table (so, tb_dfe);
/*	}
      else if (tb_dfe->dfe_next)
	sqlo_dt_unplace (so, tb_dfe->dfe_next);*/
      tb_dfe->_.table.is_oby_order = 1;
      return 1;
    }
  return 0;
}


void
sqlo_place_oby_specs (sqlo_t * so, op_table_t * from_ot, ST ** specs)
{
  int inx;
  DO_BOX (ST *, spec, inx, specs)
    {
      df_elt_t *dfe_spec = sqlo_df (so, spec->_.o_spec.col);
      sqlo_place_exp (so, from_ot->ot_work_dfe, dfe_spec);
    }
  END_DO_BOX;
}



#if 0
void
sqlo_try_sorted_oby (sqlo_t * so, op_table_t * from_ot)
{
  return;
  /* if all oby requisites are placed, place the oby sorter node */
  if (from_ot->ot_group_dfe)
    return;
  if (!from_ot->ot_oby_dfe)
    return;
  if (from_ot->ot_oby_dfe->dfe_is_placed)
    return;
  if (!dfe_reqd_placed (from_ot->ot_oby_dfe))
    return;
  if (sqlo_is_seq_in_oby_order  (so, from_ot->ot_work_dfe->_.sub.first, NULL))
    return;
  sqlo_place_oby_specs (so, from_ot, from_ot->ot_oby_dfe->_.setp.specs);
  sqlo_place_dfe_after (so, LOC_LOCAL, so->so_gen_pt, from_ot->ot_oby_dfe);
}
#endif


int
sqlo_are_non_inx_gb_cols (op_table_t * from_ot, df_elt_t * tb_dfe, int nth)
{
  /* loop over the group specs and see if there are any from this table which are not in the n first of the order index */
  int inx;
  DO_BOX (ST *, spec, inx, from_ot->ot_group_dfe->_.setp.specs)
    {
      ST * col = spec->_.o_spec.col;
      if (0 == strcmp (col->_.col_ref.prefix, tb_dfe->_.table.ot->ot_new_prefix))
	{
	  /* col of this table. Is it in the n leading order key parts? */
	  int ctr = 0;
	  DO_SET (dbe_column_t *, inxcol, &tb_dfe->_.table.key->key_parts)
	    {
	      if (0 == stricmp (col->_.col_ref.name, inxcol->col_name))
		goto next_spec;
	      ctr++;
	      if (ctr >= nth)
		return 1; /* a col in the specs that is of this table but not in the n first parts of order key */
	    }
	  END_DO_SET();
	}
    next_spec: ;
    }
  END_DO_BOX;
  return 0;
}


int
sqlo_tb_is_col_eq (df_elt_t * tb_dfe, dbe_column_t * col)
{
  DO_SET (df_elt_t *, pred, &tb_dfe->_.table.col_preds)
    {
      if (BOP_EQ == pred->_.bin.op
	  && col == pred->_.bin.left->_.col.col)
	return 1;
    }
  END_DO_SET();
  return 0;
}


int
sqlo_is_col_in_gb (op_table_t * ot, df_elt_t * tb_dfe, dbe_column_t * col)
{
  int inx;
  DO_BOX (ST *, spec, inx, ot->ot_group_dfe->_.setp.specs)
    {
      ST * spec_col = spec->_.o_spec.col;
      if (0 == stricmp (spec_col->_.col_ref.prefix, tb_dfe->_.table.ot->ot_new_prefix)
	  && 0 == stricmp (spec_col->_.col_ref.name, col->col_name))
	return 1;
    }
  END_DO_BOX;
  return 0;
}



int
sqlo_tb_gb_status (sqlo_t * so, op_table_t * from_ot, df_elt_t * tb_dfe)
{
  /* the table is non-ordered if no group cols in it.
   * the table is gb_single if it has full unique equality on the ordering key e
   * if equalities and group cols together cover the full unique key it is ordered
   * if equalities and group cols cover part of the key AND no more group cols in this table then
   * the table is partially ordered */
  dbe_key_t * key = tb_dfe->_.table.key;
  int n_parts = key->key_n_significant;
  int nth = 0;

  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      if (nth == n_parts)
	return GB_NON_ORDERED;
      if (sqlo_is_col_in_gb (from_ot, tb_dfe, col))
	break;
      nth++;
    }
  END_DO_SET();

  nth = 0;
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      if (nth == n_parts)
	return GB_SINGLE;
      if (!sqlo_tb_is_col_eq (tb_dfe, col))
	break;
      nth++;
    }
  END_DO_SET();

      nth = 0;
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      if (nth == n_parts)
	break;
      if (! (sqlo_tb_is_col_eq (tb_dfe, col)
	     || sqlo_is_col_in_gb (from_ot, tb_dfe, col)))
	{
	  /* if leading non-unq determined, then there must be no non-index cols of this table in the gb spec */
	  if (0 == nth)
	    return GB_NON_ORDERED;
	  if (sqlo_are_non_inx_gb_cols (from_ot, tb_dfe, nth))
	    return GB_NON_ORDERED;
	  else
	    return GB_ORDERED_NON_UNIQUE;
	}
      nth++;
    }
  END_DO_SET();
  return GB_ORDERED_UNIQUE;
}


int
sqlo_is_group_linear (sqlo_t * so, op_table_t * from_ot)
{
  /* the group is linear if all leading are unique ordered followed by max one non unique ordered followed by n unordered *
   * anything else is not linear  ord-unq* ord-non-unq? non-ord*  */
  df_elt_t * dfe;
  int prev_stat = GB_INITIAL;
  for (dfe = from_ot->ot_work_dfe->_.sub.first; dfe; dfe = dfe->dfe_next)
    {
      if (DFE_TABLE == dfe->dfe_type)
	{
	  int stat = sqlo_tb_gb_status (so, from_ot, dfe);
	  if (GB_SINGLE == stat)
	    continue;
	  if (GB_NON_ORDERED == stat && GB_INITIAL == prev_stat)
	    return 0;
	  if (stat == prev_stat && stat == GB_ORDERED_NON_UNIQUE)
	    return 0;  /* 2 partials not allowed */
	  if (stat > prev_stat)
	    return 0;
	  prev_stat = stat;
	}
      if (DFE_DT == dfe->dfe_type)
	return 0;
    }
  return 1;
}


int
sqlo_early_distinct (sqlo_t * so, op_table_t * ot)
{
  /* take the selection.  Strip identity preserving funcs from the exps. Add a distinct node */
  df_elt_t * dist_dfe;
  ST ** keys;
  int inx;
  ST ** sel;
  if (!SEL_IS_DISTINCT (ot->ot_dt) || LOC_LOCAL != ot->ot_work_dfe->dfe_locus)
    return 0;

  sel = (ST**)ot->ot_dt->_.select_stmt.selection;
  keys = (ST**)t_box_copy ((caddr_t)sel);
  DO_BOX (ST *, exp, inx, sel)
    {
      df_elt_t * exp_dfe;
      exp = sqlc_strip_as (exp);
      while (ST_P (exp, CALL_STMT) && sqlo_is_unq_preserving (exp->_.call.name)
	     && 1 <= BOX_ELEMENTS (exp->_.call.params))
	exp = exp->_.call.params[0];
      exp_dfe = sqlo_df (so, exp);
      keys[inx] = exp;
      sqlo_place_exp (so, ot->ot_work_dfe, exp_dfe);
    }
  END_DO_BOX;
  dist_dfe = sqlo_new_dfe (so, DFE_GROUP, NULL);
  dist_dfe->_.setp.specs = keys;
  dist_dfe->_.setp.is_distinct = DFE_S_DISTINCT;
  sqlo_place_dfe_after (so, ot->ot_work_dfe->dfe_locus, so->so_gen_pt, dist_dfe);
  return 1;
}

int enable_dfe_filter = 1;

void
sqlo_fun_ref_epilogue (sqlo_t * so, op_table_t * from_ot)
{
  int all_cols_p = 0;
  dk_set_t having_preds = NULL;
  df_elt_t * group_dfe = from_ot->ot_group_dfe;
  ST * texp = from_ot->ot_dt->_.select_stmt.table_exp;
  ST ** group = texp ? texp->_.table_exp.group_by : NULL;

  if (from_ot->ot_invariant_preds && !from_ot->ot_invariant_placed)
    {
      df_elt_t * gen_pt = so->so_gen_pt;
      df_elt_t * filter = sqlo_new_dfe (so, DFE_FILTER, NULL);
      df_elt_t ** after_test;
      filter->_.filter.invariant_of_ot = from_ot;
      from_ot->ot_invariant_placed = 1;
      so->so_gen_pt = from_ot->ot_work_dfe->_.sub.first;
      after_test = sqlo_and_list_body (so, LOC_LOCAL, so->so_gen_pt, from_ot->ot_invariant_preds);
      filter->_.filter.body = after_test;
      filter->_.filter.preds = from_ot->ot_invariant_preds;
      sqlo_place_dfe_after  (so, LOC_LOCAL, so->so_gen_pt, filter);
      so->so_gen_pt = gen_pt;
    }

  if (!from_ot->ot_fun_refs && !group_dfe)
    {
      int is_dist = sqlo_early_distinct (so, from_ot);
      if (sqlo_is_seq_in_oby_order  (so, from_ot->ot_work_dfe->_.sub.first, NULL))
	return;
      if (!from_ot->ot_oby_dfe || from_ot->ot_oby_dfe->dfe_is_placed)
	return;
      if (is_dist)
	so->so_place_code_forr_cond = 1;
      sqlo_place_oby_specs (so, from_ot, from_ot->ot_oby_dfe->_.setp.specs);
      so->so_place_code_forr_cond = 0;
      sqlo_place_dfe_after (so, from_ot->ot_work_dfe->dfe_locus, so->so_gen_pt, from_ot->ot_oby_dfe);
      return;
    }
  if (group_dfe)
    {
    group_dfe->dfe_locus = from_ot->ot_work_dfe->dfe_locus; /* if dt passed through then group too */
      group_dfe->_.setp.is_being_placed = 1;
    }
  if (group)
    {
      int inx;
      all_cols_p = sqlo_oby_exp_cols (so, from_ot->ot_dt, group);
      sqlo_place_oby_specs (so, from_ot, group);
      _DO_BOX (inx, texp->_.table_exp.group_by_full)
	{
	  sqlo_place_oby_specs (so, from_ot, texp->_.table_exp.group_by_full[inx]);
	}
      END_DO_BOX;
    }
  if (from_ot->ot_group_dfe)
    sqlo_place_dfe_after (so, from_ot->ot_work_dfe->dfe_locus,
			  from_ot->ot_work_dfe->_.sub.last, from_ot->ot_group_dfe);
  DO_SET (ST *, fref, &from_ot->ot_fun_refs)
    {
      df_elt_t * fref_dfe = sqlo_df (so, fref);
      df_elt_t * arg_dfe = NULL;
      int locus_to_loclocal = 0;
      if (AMMSC_USER != fref->_.fn_ref.fn_code)
	arg_dfe = sqlo_df (so, fref->_.fn_ref.fn_arg);
/*      if (group_dfe->_.setp.specs
	  && fref->_.fn_ref.all_distinct
	  && !IS_BOX_POINTER (from_ot->ot_work_dfe->dfe_locus))
	sqlc_new_error (so->so_sc->sc_cc, "37000", "SQ111", "Distinct not allowed with an aggregate with group by.");
*/
      fref_dfe->dfe_locus = from_ot->ot_work_dfe->dfe_locus;
      if (AMMSC_USER == fref->_.fn_ref.fn_code)
	{
	  int argidx;
	  DO_BOX_FAST (ST *, arg, argidx, fref->_.fn_ref.fn_arglist)
	    {
	      df_elt_t * arg_dfe = sqlo_df (so, arg);
	      sqlo_place_exp (so, from_ot->ot_work_dfe, arg_dfe);
	      if (DFE_CONST != arg_dfe->dfe_type && arg_dfe->dfe_locus != from_ot->ot_work_dfe->dfe_locus)
		locus_to_loclocal = 1;
	    }
	  END_DO_BOX_FAST;
	}
      else
	{
	  if (IS_BOX_POINTER (from_ot->ot_work_dfe->dfe_locus) &&
	      AMMSC_COUNTSUM == fref->_.fn_ref.fn_code &&
	      ST_P (fref->_.fn_ref.fn_arg, SEARCHED_CASE))
	    {
	      ST *stree = fref->_.fn_ref.fn_arg;
	      if ((4 == BOX_ELEMENTS (stree->_.comma_exp.exps)) &&
		  ST_P (stree->_.comma_exp.exps [0], BOP_NULL) &&
		  ST_P (stree->_.comma_exp.exps [2], QUOTE) &&
		  (0 == unbox ((box_t) stree->_.comma_exp.exps [1])) &&
		  (1 == unbox ((box_t) stree->_.comma_exp.exps [3])))
		{
		  sqlo_place_exp (so, from_ot->ot_work_dfe,
		      sqlo_df (so, stree->_.comma_exp.exps [0]->_.bin_exp.left));
		  arg_dfe->dfe_locus = from_ot->ot_work_dfe->dfe_locus;
		}
	      else
		sqlo_place_exp (so, from_ot->ot_work_dfe, arg_dfe);
	    }
	  else
	    sqlo_place_exp (so, from_ot->ot_work_dfe, arg_dfe);
	  if (fref->_.fn_ref.fn_code == AMMSC_COUNT || fref->_.fn_ref.fn_code == AMMSC_COUNTSUM)
	    fref_dfe->dfe_sqt.sqt_dtp = DV_LONG_INT;
	  else
	    fref_dfe->dfe_sqt = arg_dfe->dfe_sqt;
	  if (DFE_CONST != arg_dfe->dfe_type && arg_dfe->dfe_locus != from_ot->ot_work_dfe->dfe_locus)
	    locus_to_loclocal = 1;
	}
      if (arg_dfe)
	sqlg_find_aggregate_sqt (wi_inst.wi_schema, &(arg_dfe->dfe_sqt), fref, &(fref_dfe->dfe_sqt));
      if (locus_to_loclocal)
	{
	  fref_dfe->dfe_locus = LOC_LOCAL;
	  group_dfe->dfe_locus = LOC_LOCAL;
	}
      t_set_push (&group_dfe->_.setp.fun_refs, fref);
    }
  END_DO_SET();
  if (group_dfe)
    group_dfe->_.setp.is_being_placed = 0;

  /* all the predicates not done so far are from the HAVING clause, even if not mentioned in the texp since they could hav been added to the ot from an enclosing context */
  so->so_gen_pt = from_ot->ot_group_dfe;
  DO_SET (df_elt_t *, pred, &from_ot->ot_preds)
    {
      if (!pred->dfe_is_placed)
	t_set_push (&having_preds, (void*) pred);
    }
  END_DO_SET();
  if (having_preds)
    {
      df_elt_t * filter;
      df_elt_t ** after_test = sqlo_and_list_body (so,
						   from_ot->ot_work_dfe ? from_ot->ot_work_dfe->dfe_locus : LOC_LOCAL,
						   from_ot->ot_group_dfe, having_preds);
      if (enable_dfe_filter)
	{
	  filter = sqlo_new_dfe (so, DFE_FILTER, NULL);
	  filter->_.filter.body = after_test;
	  filter->_.filter.preds = having_preds;
	  sqlo_place_dfe_after  (so, group_dfe->dfe_locus, so->so_gen_pt,  filter);
	}
      else
	{
	  group_dfe->_.setp.after_test = after_test;
	  group_dfe->_.setp.having_preds = having_preds;
	}
    }
  if (group_dfe && all_cols_p)
    group_dfe->_.setp.is_linear = sqlo_is_group_linear (so, from_ot);
  if (from_ot->ot_oby_dfe)
    {
      sqlo_place_oby_specs (so, from_ot, from_ot->ot_oby_dfe->_.setp.specs);
      if (!from_ot->ot_oby_dfe->dfe_is_placed)
	sqlo_place_dfe_after (so, from_ot->ot_work_dfe->dfe_locus,
	    so->so_gen_pt->dfe_type == DFE_DT ? so->so_gen_pt->_.sub.last : so->so_gen_pt, from_ot->ot_oby_dfe);
    }
}

int
sqlo_is_postprocess (sqlo_t *so, df_elt_t * dt_dfe, df_elt_t * last_tb_dfe)
{
  op_table_t *ot = dfe_ot (dt_dfe);

  if (ot->ot_group_dfe)
    return 1;
  if (!ot->ot_oby_dfe)
    return 0;

  return (!sqlo_is_seq_in_oby_order (so, dt_dfe->_.sub.first, NULL)) ? 1 :0;
}

void
sqlo_exp_cols_from_dt (sqlo_t * so, ST * tree, df_elt_t * dt_dfe, df_elt_t * oby_dfe, dk_set_t * ret)
{
  /* traverse exp and return all cols that exp depends on which are defined in dt_dfe */
  df_elt_t * dfe;
  int inx;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree)
      && (dfe = sqlo_df_elt (so, tree)))
    {
      int crossed = 0;
      df_elt_t * pt;
      for (pt = dt_dfe->_.sub.last; pt; pt = pt->dfe_prev)
	{
	  if (dfe_defines (pt, dfe))
	    break;
	  if (pt == oby_dfe)
	    crossed = 1;
	}
      if (pt && crossed)
	t_set_pushnew (ret, dfe);
    }
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
    return;
  if (ST_P (tree, FUN_REF))
    return;
  DO_BOX (ST*, x, inx, (ST**)tree)
    {
      sqlo_exp_cols_from_dt (so, x, dt_dfe, oby_dfe, ret);
    }
  END_DO_BOX;
}


int
dfe_is_after (df_elt_t * after, df_elt_t * before)
{
  while (after)
    {
      if (after == before)
	return 1;
      after = after->dfe_prev;
    }
  return 0;
}


void
sqlo_post_oby_ref (sqlo_t * so, df_elt_t * dt_dfe, df_elt_t * sel_dfe, int inx)
{
  /* if exps laid out after oby, add the cols refd therein to oby deps */
  dk_set_t deps = NULL;
  df_elt_t * oby_dfe = dt_dfe->_.sub.last;
  int __i;
  while (oby_dfe)
    {
      if (DFE_ORDER == oby_dfe->dfe_type)
	break;
      oby_dfe = oby_dfe->dfe_prev;
    }
  if (!oby_dfe)
    return;
  DO_BOX (ST *, spec, __i, oby_dfe->_.setp.specs)
    {
      df_elt_t * spec_dfe = sqlo_df (so, spec->_.o_spec.col);
      if (spec_dfe == sel_dfe)
	return;
    }
  END_DO_BOX;
  if (!dfe_is_after (sel_dfe, oby_dfe))
    return;
  sqlo_exp_cols_from_dt (so, sel_dfe->dfe_tree, dt_dfe, oby_dfe, &deps);
  if (!oby_dfe->_.setp.oby_dep_cols)
    {
      oby_dfe->_.setp.oby_dep_cols = (dk_set_t*)t_box_copy ((caddr_t)dt_dfe->_.sub.dt_out);
      memset (oby_dfe->_.setp.oby_dep_cols, 0, box_length ((caddr_t)oby_dfe->_.setp.oby_dep_cols));
    }
  oby_dfe->_.setp.oby_dep_cols[inx] = deps;
}

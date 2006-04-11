/*
 *  sqlcost.c
 *
 *  $Id$
 *
 *  sql cost functions
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
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
 *  
*/

#include "sqlnode.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlbif.h"
#include "arith.h"
#include "security.h"
#include "remote.h"
#include "sqlo.h"
#include "list2.h"





void dfe_list_cost (df_elt_t * dfe, float * unit_ret, float * arity_ret, float * overhead_ret, locus_t *loc);


long
dbe_key_count (dbe_key_t * key)
{
  if (key->key_table->tb_count != DBE_NO_STAT_DATA)
    return MAX (key->key_table->tb_count, 1);
#ifdef SQLO_STATISTICS
  else if (key->key_table->tb_path_count > 0)
    return (long) MIN ((key->key_table->tb_global_rows / key->key_table->tb_path_count), 1);
#endif
  else
    return 1000;
}


#define COL_PRED_COST 0.02 /* itc_col_check */
#define ROW_SKIP_COST 0.04 /* itc_row_check and 1 iteration of itc_page_search */
#define INX_CMP_COST 0.25 /* one compare in random access lookup. Multiple by log2 of inx count to get cost of 1 random access */
#define ROW_COST_PER_BYTE (COL_PRED_COST / 200) /* 200 b of row cost 1 itc_col_check */
#define NEXT_PAGE_COST 5
#define INX_ROW_INS_COST 1 /* cost of itc_insert_dv into inx */
#define HASH_ROW_INS_COST 0.7 /* cost of adding a row to hash */
#define HASH_LOOKUP_COST 0.6
#define CV_INSTR_COST 0.1   /* avg cost of instruction in code_vec_run */

#define HASH_COUNT_FACTOR(n)\
  (0.05 * log(n) / log (2)) 


float
dbe_key_unit_cost (dbe_key_t * key)
{
  long count = dbe_key_count (key);
  if (count)
    {
      double lc = log (count);
      double l2 = log (2);
      return (float) (INX_CMP_COST  * lc / l2);
    }
  else
    return 0;
}


static float
dbe_key_row_cost (dbe_key_t * key, float * rpp)
{
  int row_len = 0;
  /* weight the length of the column in the cost model */
  DO_SET (dbe_column_t *, k_col, &key->key_parts)
    {
      int col_len = 100, fixed_len;
      if (-1 != (fixed_len = sqt_fixed_length (&k_col->col_sqt)))
	col_len = fixed_len;
      else if (k_col->col_sqt.sqt_dtp == DV_LONG_STRING ||
	  k_col->col_sqt.sqt_dtp == DV_WIDE ||
	  k_col->col_sqt.sqt_dtp == DV_BIN ||
	  k_col->col_sqt.sqt_dtp == DV_ANY)
	{ /* precision contious ones */
	  if (k_col->col_avg_len)
	    col_len = k_col->col_avg_len;
	  else if (k_col->col_sqt.sqt_precision > 0)
	    col_len = k_col->col_sqt.sqt_precision;
	}
      else if (IS_BLOB_DTP (k_col->col_sqt.sqt_dtp))
	col_len = 120;
      row_len += col_len;
    }
  END_DO_SET ();
  if (rpp)
    *rpp = 6000.0 / row_len ;
  return (float) row_len * ROW_COST_PER_BYTE;
}


void
sqlo_pred_unit (df_elt_t * lower, df_elt_t * upper, float * u1, float * a1)
{
  *u1 = (float) COL_PRED_COST;
  if (BOP_EQ == lower->_.bin.op)
    *a1 = (float) 0.1;
  else
    *a1 = 0.5;

  if (lower->dfe_type != DFE_TEXT_PRED &&
      lower->_.bin.left->dfe_type == DFE_COLUMN &&
      lower->_.bin.left->_.col.col &&
      lower->_.bin.left->_.col.col->col_count != DBE_NO_STAT_DATA)
    {
      dbe_column_t *left_col = lower->_.bin.left->_.col.col;
      if (lower->_.bin.op == BOP_EQ)
	{

	  if (DFE_IS_CONST (lower->_.bin.right) &&
	      left_col->col_min && left_col->col_max &&
	      DV_TYPE_OF (left_col->col_min) != DV_DB_NULL && DV_TYPE_OF (left_col->col_max) != DV_DB_NULL &&
	      (DVC_LESS == cmp_boxes ((caddr_t) lower->_.bin.right->dfe_tree, left_col->col_min,
		 left_col->col_collation, left_col->col_collation) ||
	       DVC_GREATER == cmp_boxes ((caddr_t) lower->_.bin.right->dfe_tree, left_col->col_max,
		 left_col->col_collation, left_col->col_collation)))
	    { /* the boundry is constant and its outside min/max */
	      *a1 = 0.0001; /* out of range.  Because unsure, do not make  it exact 0 */
	    }
	  else if (DFE_IS_CONST (lower->_.bin.right) && left_col->col_hist)
	    { /* the boundry is constant and there is a column histogram */
	      int inx, n_level_buckets = 0;

	      DO_BOX (caddr_t *, bucket, inx, ((caddr_t **)left_col->col_hist))
		{
		  if (DVC_MATCH == cmp_boxes ((caddr_t) lower->_.bin.right->dfe_tree, bucket[1],
			left_col->col_collation, left_col->col_collation))
		    {
		      n_level_buckets ++;
		    }
		}
	      END_DO_BOX;

	      if (n_level_buckets > 1)
		{ /* there are buckets where top=bottom=const */
		  *a1 = (n_level_buckets - (float) 1.00) / BOX_ELEMENTS (left_col->col_hist);
		}
	      else
		{
		  if (left_col->col_n_distinct < BOX_ELEMENTS_INT (left_col->col_hist))
		    { /* it's a rare value */
		      *a1 = (float) (1.00 / (BOX_ELEMENTS (left_col->col_hist) * 2));
		    }
		  else
		    *a1 = (float) (1.00 / left_col->col_n_distinct);
		}
	    }
	  else
	    {
	      if (left_col->col_n_distinct > 0)
		{
		  *a1 = (float) (1.00 / left_col->col_n_distinct);
		}
	      else
		{
		  *a1 = 0;
		}
	    }
	}
      else if (lower->_.bin.op == BOP_GT || lower->_.bin.op == BOP_GTE)
	{
	  if (DFE_IS_CONST (lower->_.bin.right) &&
	      left_col->col_max && DV_TYPE_OF (left_col->col_max) != DV_DB_NULL &&
	      DVC_GREATER == cmp_boxes ((caddr_t) lower->_.bin.right->dfe_tree, left_col->col_max,
		left_col->col_collation, left_col->col_collation))
	    { /* lower boundry is a constant and it's above the max */
	      *a1 = 0;
	    }
	  else if (DFE_IS_CONST (lower->_.bin.right) && left_col->col_hist)
	    { /* lower bondry is a constant and there's a col histogram */
	      int inx;

	      DO_BOX (caddr_t *, bucket, inx, ((caddr_t **)left_col->col_hist))
		{
		  if (DVC_GREATER == cmp_boxes ((caddr_t) lower->_.bin.right->dfe_tree, bucket[1],
			left_col->col_collation, left_col->col_collation))
		    {
		      *a1 = (float) (1.00 - ((float) inx + 1) / BOX_ELEMENTS (left_col->col_hist));
		      break;
		    }
		}
	      END_DO_BOX;
	    }
	}
      else if (lower->_.bin.op == BOP_LT || lower->_.bin.op == BOP_LTE)
	{
	  if (DFE_IS_CONST (lower->_.bin.right) &&
	      left_col->col_min && DV_TYPE_OF (left_col->col_min) != DV_DB_NULL &&
	      DVC_LESS == cmp_boxes ((caddr_t) lower->_.bin.right->dfe_tree, left_col->col_min,
		left_col->col_collation, left_col->col_collation))
	    { /* upper boundry is a constant and it's below the min */
	      *a1 = 0;
	    }
	  else if (DFE_IS_CONST (lower->_.bin.right) && left_col->col_hist)
	    { /* upper bondry is a constant and there's a col histogram */
	      int inx;

	      DO_BOX (caddr_t *, bucket, inx, ((caddr_t **)left_col->col_hist))
		{
		  if (DVC_LESS == cmp_boxes ((caddr_t) lower->_.bin.right->dfe_tree, bucket[1],
			left_col->col_collation, left_col->col_collation))
		    {
		      *a1 = ((float)inx) / BOX_ELEMENTS (left_col->col_hist);
		      break;
		    }
		}
	      END_DO_BOX;
	    }
	}
      else if (lower->_.bin.op == BOP_LIKE)
	{
	  if (left_col->col_n_distinct > 0)
	    {
	      *a1 = (float) (1.00 / left_col->col_n_distinct);
	    }
	  else
	    {
	      *a1 = 0;
	    }
	}
    }
  else if (lower->dfe_type != DFE_TEXT_PRED &&
      lower->_.bin.left->dfe_type == DFE_COLUMN &&
      lower->_.bin.left->_.col.col &&
      lower->_.bin.op == BOP_LIKE)
    {
      dbe_column_t *left_col = lower->_.bin.left->_.col.col;
      *a1 = (float) (1.00 / dbe_key_count (left_col->col_defined_in->tb_primary_key));
    }
  *a1 = MIN (1, *a1);
}


int
sqlo_table_any_nonkey_out (df_elt_t * dfe)
{
  DO_SET (df_elt_t *, out, &dfe->_.table.out_cols)
    {
      if (!dk_set_member (dfe->_.table.key->key_parts, (void*) out->_.col.col))
	return 1;
    }
  END_DO_SET();
  return 0;
}


int
sqlo_table_any_nonkey_refd (df_elt_t * dfe)
{
  DO_SET (dbe_column_t *, refd , &dfe->_.table.ot->ot_table_refd_cols)
    {
      if (!dk_set_member (dfe->_.table.key->key_parts, (void*) refd))
	return 1;
    }
  END_DO_SET();
  return 0;
}

static float
rds_locus_rpc_units (locus_t *loc)
{
  float res = 200; /* the default */

  if (IS_BOX_POINTER (loc) && compiler_unit_msecs != 0.0)
    {
      caddr_t rds_locus_cost = rds_get_info (loc->loc_rds, -200);
      if (rds_locus_cost)
	res = unbox_float (rds_locus_cost) / compiler_unit_msecs;
    }

  return res;
}


float
sqlo_dfe_locus_rpc_cost (locus_t *loc, df_elt_t *dfe)
{ /* calculates the overhead of changing locus */

  float u1, a1 = 1, cum = 0, arity = 1, overhead;

  /* calculate the number of rows to be produced by the locus group */
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (dfe))
    {
      int inx;
      df_elt_t ** dfe_arr = (df_elt_t **) dfe;
      DO_BOX (df_elt_t *, elt, inx, dfe_arr)
	{
	  dfe_unit_cost (elt, 1, &u1, &a1, &overhead);
	  if ((DFE_TABLE == elt->dfe_type || DFE_DT == elt->dfe_type)
	      && elt->dfe_locus)
	    {
	      if (elt->dfe_locus != loc)
		break;
	    }
	  cum += arity * u1;
	  arity *= a1;
	}
      END_DO_BOX;
    }
  else
    {
      while (dfe)
	{
	  dfe_unit_cost (dfe, arity, &u1, &a1, &overhead);
	  if ((DFE_TABLE == dfe->dfe_type || DFE_DT == dfe->dfe_type)
	      && dfe->dfe_locus)
	    {
	      if (dfe->dfe_locus != loc)
		break;
	    }
	  cum += arity * u1;
	  arity *= a1;
	  dfe = dfe->dfe_next;
	}
    }

  /* assumes 1 initial RPC + 1 RPC per 20 rows of output */
  return (float) (rds_locus_rpc_units (loc) * ( 1 + arity / 20.00 ));
}


void
dfe_pred_body_cost (df_elt_t **body, float * unit_ret, float * arity_ret, float * overhead_ret)
{
  int inx;
  if (DV_TYPE_OF (body) == DV_ARRAY_OF_POINTER)
    {
      ptrlong op = (ptrlong) body[0];
      float u1, a1 = 1, cum = 0, arity = 1;
      int n_terms = BOX_ELEMENTS (body);
      switch (op)
	{
	  case BOP_NOT:
	      dfe_pred_body_cost ((df_elt_t **) body[1], &u1, &a1, overhead_ret);
	      *unit_ret = u1;
	      *arity_ret = 1 - a1;
	      break;
	  case BOP_OR:
	      for (inx = 1; inx < n_terms; inx++)
		{
		  dfe_pred_body_cost ((df_elt_t **) body[inx], &u1, &a1, overhead_ret);
		  cum += (1 - arity) * u1;
		  arity *= 1 - a1;
		}
	      *arity_ret = arity;
	      *unit_ret = cum;
	      break;
	  case BOP_AND:
	  case DFE_PRED_BODY:
	      for (inx = 1; inx < n_terms; inx++)
		{
		  dfe_pred_body_cost ((df_elt_t **) body[inx], &u1, &a1, overhead_ret);
		  cum += arity * u1;
		  arity *= a1;
		}
	      *arity_ret = arity;
	      *unit_ret = cum;
	      break;
	  default:
	      *arity_ret = 1;
	      *unit_ret = CV_INSTR_COST;
	}
    }
  else if (IS_BOX_POINTER (body))
    {
      df_elt_t *pred = (df_elt_t *) body;
      if (pred->dfe_type == DFE_BOP_PRED || pred->dfe_type == DFE_BOP)
	sqlo_pred_unit (pred, NULL, unit_ret, arity_ret);
      else
	dfe_unit_cost ((df_elt_t *) body, 1, unit_ret, arity_ret, overhead_ret);
    }
}


float
dfe_hash_fill_unit (df_elt_t * dfe, float arity)
{
  return HASH_ROW_INS_COST + HASH_COUNT_FACTOR (arity);
}


float 
sqlo_inx_intersect_cost (df_elt_t * tb_dfe, dk_set_t col_preds, dk_set_t group, float * arity_ret)
{
  dbe_table_t * tb = tb_dfe->_.table.ot->ot_table;
  dbe_key_t * prev_key = tb_dfe->_.table.key;
  int n_inx = dk_set_length (group);
  float arity, ov, cost, min = -1, total_cost, p_cost, p_arity;
  float n_rows = dbe_key_count (tb_dfe->_.table.ot->ot_table->tb_primary_key);
  float selectivity = 1;
  DO_SET (df_inx_op_t *, dio, &group)
    {
      dbe_key_t * key = dio->dio_key;
      tb_dfe->_.table.key = key;
      dfe_table_cost (tb_dfe, &cost, &arity, &ov, 1);
      selectivity = selectivity * (arity / n_rows);
      if (-1 == min ||   cost < min)
	min = cost;
    }
  END_DO_SET();
  tb_dfe->_.table.key = prev_key;
  *arity_ret = n_rows * selectivity;
  /* must get the main row? If cols refd that are not in any of the inxes. */
  DO_SET (dbe_column_t *, col, &tb_dfe->_.table.ot->ot_table_refd_cols)
    {
      DO_SET (dbe_key_t *, key, &group)
	{
	  if (dk_set_member (key->key_parts, (void*) col))
	    goto next_col;
	}
      END_DO_SET();
      /* found a col that is in none of the inxes */
	  goto get_main_row;
    next_col: ;
    }
  END_DO_SET ();
  return (n_inx * min);
 get_main_row:
  min = min * n_inx;
  arity = n_rows * selectivity;
  total_cost = min + (arity * 
	  (dbe_key_unit_cost (tb->tb_primary_key) 
	   + dbe_key_row_cost (tb->tb_primary_key, NULL)));
    
  DO_SET (df_elt_t *, pred, &tb_dfe->_.table.col_preds)
    {
      DO_SET (df_inx_op_t *, dio, &group)
	{
	  dbe_key_t * key = dio->dio_key;
	  if (dk_set_member (key->key_parts, (void*) pred->_.bin.left->_.col.col))
	    goto next_pred;
	}
      END_DO_SET();
      sqlo_pred_unit (pred, NULL, &p_cost, &p_arity);
      arity *= p_arity;
      total_cost += p_cost * arity;
    next_pred: ;
    }
  END_DO_SET();
  *arity_ret = arity;
  return total_cost;
}


void
dfe_table_cost (df_elt_t * dfe, float * u1, float * a1, float * overhead_ret, int inx_only)
{
  int nth_part = 0;
  dbe_key_t * key = dfe->_.table.key;
  int n_significant = dfe->_.table.key->key_n_significant;
  int unique = 0;
  int unq_limit = key->key_is_unique ? key->key_decl_parts : key->key_n_significant;
  dbe_table_t * tb = dfe->_.table.ot->ot_table;
  float p_cost, p_arity, rows_per_page;
  float inx_cost = 0;
  float inx_arity = (float) dbe_key_count (dfe->_.table.key);
  float col_arity = 1;
  float col_cost = (float) 0.12;
  float total_cost, total_arity;
  int is_indexed = 1;


  if (!inx_only && dfe->_.table.inx_op)
    {
      *u1 = sqlo_inx_intersect_cost (dfe, dfe->_.table.col_preds, dfe->_.table.inx_op->dio_terms, a1);
      dfe->_.table.is_unique = 0;
      overhead_ret = 0;
      return;
    }

  inx_cost = dbe_key_unit_cost (dfe->_.table.key);
  DO_SET (dbe_column_t *, part, &dfe->_.table.key->key_parts)
    {
      df_elt_t * lower = sqlo_key_part_best (part, dfe->_.table.col_preds, 0);
      df_elt_t * upper = sqlo_key_part_best (part, dfe->_.table.col_preds, 1);
      if (lower || upper)
	{
	  sqlo_pred_unit (lower, upper, &p_cost, &p_arity);
	  if (is_indexed)
	    {
	      inx_arity *= p_arity;
	      inx_cost += (float) COL_PRED_COST * log (dbe_key_count (key)) / log (2);  /*cost of compare * log2 of inx count */
	      if (!lower || BOP_EQ != lower->_.bin.op)
		is_indexed = 0;
	    }
	  else
	    {
	      col_cost += (float) p_cost;
	      col_arity *= p_arity;
	    }
	}
      else if (nth_part < n_significant)
	is_indexed = 0;
      nth_part++;
      if (is_indexed && nth_part == unq_limit )
	unique = 1;
      if (nth_part == n_significant)
	{
	  if (is_indexed)
	    unique = 1;
	  is_indexed = 0;
	}
    }
  END_DO_SET();

  if (unique)
    inx_arity = 1;
  dfe->_.table.is_unique = unique;
  total_cost = inx_cost + (col_cost + ROW_SKIP_COST) * inx_arity 
    + dbe_key_row_cost (dfe->_.table.key, &rows_per_page) * inx_arity;
  total_cost += NEXT_PAGE_COST * inx_arity / rows_per_page;
  total_arity = inx_arity * col_arity;

  if (inx_only )
    {
      *u1 = total_cost;
      *a1 = total_arity;
      *overhead_ret = 0;
      return;
    }
  if (dfe->_.table.is_unique &&
      (!dfe->_.table.key ||
	dfe->_.table.key->key_table->tb_count == DBE_NO_STAT_DATA))
    total_arity = inx_arity = 1;


  /* the ordering key is now done. See if you need to join to the main row  */
  if (sqlo_table_any_nonkey_refd (dfe)
      || (dfe->dfe_sqlo->so_sc->sc_is_update && 0 == strcmp (dfe->_.table.ot->ot_new_prefix, "t1")))
    {
      /* if cols are refd that are not on the key or if upd/del, in which case join to main row always needed */
      if (dfe->_.table.key != tb->tb_primary_key)
	total_cost += inx_arity * (
	    dbe_key_unit_cost (tb->tb_primary_key) +
	    dbe_key_row_cost (tb->tb_primary_key, NULL));
      DO_SET (df_elt_t *, pred, &dfe->_.table.col_preds)
	{
	  if (DFE_TEXT_PRED == pred->dfe_type)
	    continue;
	  if (DFE_BOP_PRED == pred->dfe_type && !dk_set_member (key->key_parts, (void*) pred->_.bin.left->_.col.col))
	    {
	      sqlo_pred_unit (pred, NULL, &p_cost, &p_arity);
	      total_arity *= p_arity;
	      total_cost += p_cost * inx_arity;
	    }
	}
      END_DO_SET();
    }
  if (dfe->_.table.join_test)
    {
      dfe_pred_body_cost (dfe->_.table.join_test, &p_cost, &p_arity, overhead_ret);
      total_cost += p_cost * total_arity;
      total_arity *= p_arity;
    }
  if (HR_FILL == dfe->_.table.hash_role)
    {
      *a1 = 1;
      *u1 = total_cost + total_arity * dfe_hash_fill_unit (dfe, total_arity);
      if (dfe->dfe_locus && IS_BOX_POINTER (dfe->dfe_locus))
	{
	  dfe->_.table.hash_role = HR_NONE;
	  *u1 += sqlo_dfe_locus_rpc_cost (dfe->dfe_locus, dfe);
	  dfe->_.table.hash_role = HR_FILL;
	}
    }
  else if (dfe->_.table.hash_role == HR_REF)
    {
      float fu1, fa1, fo1;
      dfe_unit_cost (dfe->_.table.hash_filler, 0, &fu1, &fa1, &fo1);
      *overhead_ret += fu1;
      *a1 = total_arity;
      *u1 = (float) HASH_LOOKUP_COST;
    }
  else
    {
      *a1 = total_arity;
      *u1 = total_cost;
    }
}


void
sqlo_set_cost (df_elt_t * dfe, float * u1, float * a1, float * overhead_ret)
{
  int inx;
  float csum = 0, asum = 0;
  float a_t0, a_t1;
  DO_BOX (df_elt_t *, term, inx, dfe->_.qexp.terms)
    {
      float arity, unit;
      dfe_unit_cost (term, 1,  &unit, &arity, overhead_ret);
      csum += unit;
      asum += arity;
      if (0 == inx)
	a_t0 = arity;
      else if (1 == inx)
	a_t1 = arity;

    }
  END_DO_BOX;
  switch (dfe->_.qexp.op)
    {
    case UNION_ALL_ST:
      break;
    default:
      csum += (float) (asum * (log (asum) / log (2)));
    }
  switch (dfe->_.qexp.op)
    {
    case INTERSECT_ST:
    case INTERSECT_ALL_ST:
      asum = MIN (a_t0, a_t1);
    }
  *a1 = asum;
  *u1 = csum;
}


void
dfe_unit_cost (df_elt_t * dfe, float input_arity, float * u1, float * a1, float * overhead_ret)
{
  switch (dfe->dfe_type)
    {
    case DFE_TABLE:
      dfe_table_cost (dfe, u1, a1, overhead_ret, 0);
      dfe->_.table.in_arity = input_arity;
      break;
    case DFE_DT:
    case DFE_EXISTS:
      if (dfe->_.sub.generated_dfe)
	dfe_unit_cost (dfe->_.sub.generated_dfe, 1, u1, a1, overhead_ret);
      else
	{
	  if (dfe->_.sub.is_contradiction)
	    {
	      *a1 = 0;
	      *u1 = 1;
	    }
	  dfe_list_cost (dfe->_.sub.first, u1, a1, overhead_ret, dfe->dfe_locus);
	  if (dfe_ot (dfe) && ST_P (dfe_ot (dfe)->ot_dt, SELECT_STMT) &&
	      !sqlo_is_postprocess (dfe->dfe_sqlo, dfe, NULL))
	    {
	      ST *top_exp = SEL_TOP (dfe_ot (dfe)->ot_dt);
	      ptrlong top_cnt = sqlo_select_top_cnt (dfe->dfe_sqlo, top_exp);

	      if (top_cnt && top_cnt < *a1)
		{
		  *u1 /= *a1 / top_cnt;
		}
	    }
	  if (dfe->dfe_type == DFE_EXISTS)
	    { /* accesses never more than 1 */
	      if (*a1 > 1)
		*u1 /= *a1;
	    }
	}
      break;
    case DFE_QEXP:
      sqlo_set_cost (dfe, u1, a1, overhead_ret);
      break;
    case DFE_ORDER:
      /* order unit is log of count of inputs. One out for each. */
	{
	  int is_oby_order = sqlo_is_seq_in_oby_order (dfe->dfe_sqlo, dfe->dfe_super->_.sub.first, NULL);
	  if (is_oby_order)
	    *u1 = 0;
	  else if (dfe->_.setp.top_cnt)
	    /* with a top sort node, it is log2 of the top cnt and half the cost of the inx sprt temp */
	    *u1 = (float) 0.5 * (INX_ROW_INS_COST * INX_CMP_COST *  log ((double) dfe->_.setp.top_cnt) / log (2));
	  else
	    *u1 = (float) INX_ROW_INS_COST + MAX (1, 1 + INX_CMP_COST * log (input_arity) / log (2));
	  if (!is_oby_order)
	    *overhead_ret += 1;
	  *a1 = 1;
	}
      break;
    case DFE_GROUP:
      /* group is either log (n_in/in_per_group) or linear. Arity is 1/n_per_group */
      /* assume 2 per group, for out arity of 0,5 */
      *a1 = 0.5;
      if (!dfe->_.setp.group_cols && dfe->_.setp.fun_refs)
	{ /* pure fun ref node */
	  *u1 = (float) (dk_set_length (dfe->_.setp.fun_refs) * 0.03);
	  *a1 = 1 / input_arity;
	}
      else if (dfe->_.setp.is_linear)
	*u1 = 1;
      else
	*u1 = (float) MAX (1, 1 + log (input_arity / *a1) / log (2));
      break;

    default:
      *u1 = CV_INSTR_COST;
      *a1 = 1;
      break;
    }
  dfe->dfe_unit = *u1;
  dfe->dfe_arity = *a1;
}


void
dfe_list_cost (df_elt_t * dfe, float * unit_ret, float * arity_ret, float * overhead_ret, locus_t *loc)
{
  float u1, a1 = 1, cum = 0, arity = 1;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (dfe))
    {
      int inx;
      df_elt_t ** dfe_arr = (df_elt_t **) dfe;
      DO_BOX (df_elt_t *, elt, inx, dfe_arr)
	{
	  dfe_unit_cost (elt, 1, &u1, &a1, overhead_ret);
	  if ((DFE_TABLE == elt->dfe_type || DFE_DT == elt->dfe_type)
	      && elt->dfe_locus)
	    {
	      if (loc && loc != elt->dfe_locus)
		{
		  sqlo_print (("\nlocus change 1 from %s to %s\n",
			IS_BOX_POINTER (loc) ? loc->loc_name : "<local>",
			IS_BOX_POINTER (dfe->dfe_locus) ? dfe->dfe_locus->loc_name : "<local>"));
		  if (elt->dfe_locus != LOC_LOCAL &&
		      (DFE_TABLE != elt->dfe_type || HR_REF != elt->_.table.hash_role))
		    u1 += sqlo_dfe_locus_rpc_cost (elt->dfe_locus, elt);
		}
	      loc = elt->dfe_locus;
	    }
	  cum += arity * u1;
	  arity *= a1;
	  dfe->dfe_arity = arity;
	  dfe->dfe_unit = u1;
	}
      END_DO_BOX;
    }
  else
    {
      while (dfe)
	{
	  dfe_unit_cost (dfe, arity, &u1, &a1, overhead_ret);
	  if ((DFE_TABLE == dfe->dfe_type || DFE_DT == dfe->dfe_type)
	      && dfe->dfe_locus)
	    {
	      if (loc && loc != dfe->dfe_locus)
		{
		  if (sqlo_print_debug_output)
		    {
		      sqlo_print (("\nlocus change 2 from %s to %s\n",
			    IS_BOX_POINTER (loc) ? loc->loc_name : "<local>",
			    IS_BOX_POINTER (dfe->dfe_locus) ? dfe->dfe_locus->loc_name : "<local>"));
		    }
		  if (dfe->dfe_locus != LOC_LOCAL &&
		      (DFE_TABLE != dfe->dfe_type || HR_REF != dfe->_.table.hash_role))
		    u1 += sqlo_dfe_locus_rpc_cost (dfe->dfe_locus, dfe);
		}
	      loc = dfe->dfe_locus;
	    }
	  cum += arity * u1;
	  arity *= a1;
	  dfe->dfe_arity = arity;
	  dfe->dfe_unit = u1;
	  dfe = dfe->dfe_next;
	}
    }
  *arity_ret = arity;
  *unit_ret = cum;
}


float
sqlo_score (df_elt_t * dfe, float in_arity)
{
  float u1, a1, overhead = 0;
  if (0 == in_arity)
    in_arity = 1;
  dfe_list_cost (dfe, &u1, &a1, &overhead, dfe->dfe_locus);
/*  if (sqlo_print_debug_output)
    sqlo_print (("Unit : %f Arity : %f\n", (double) u1, (double) a1));*/
  dfe->dfe_unit = u1 + overhead ;
  return (in_arity * u1 + overhead);
}

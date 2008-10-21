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
#include "rdfinf.h"




void dfe_list_cost (df_elt_t * dfe, float * unit_ret, float * arity_ret, float * overhead_ret, locus_t *loc);
#define ABS(x) (x < 0 ? -(x) : x)


int64
dbe_key_count (dbe_key_t * key)
{
  dbe_table_t * tb = key->key_table;
  /*  if (!strcmp (tb->tb_name, "DB.DBA.RDF_QUAD"))
      printf ("snaap\n"); */
  if (key->key_table->tb_count != DBE_NO_STAT_DATA)
    return MAX (key->key_table->tb_count, 1);
  else if (tb->tb_count_estimate == DBE_NO_STAT_DATA
	   || ABS (tb->tb_count_delta ) > tb->tb_count_estimate / 5)
    {
      if (find_remote_table (tb->tb_name, 0))
      return 10000; /* if you know nothing, assume a remote table is 10K rows */
      tb->tb_count_estimate = key_count_estimate (tb->tb_primary_key, 3, 1);
      tb->tb_count_delta = 0;
      return MAX (1, tb->tb_count_estimate);
    }
  else 
    return MAX (1, ((long)(tb->tb_count_estimate + tb->tb_count_delta)));
}



float
dbe_key_unit_cost (dbe_key_t * key)
{
  long count = dbe_key_count (key);
  if (count)
    {
      double lc = log (count);
      double l2 = log (2);
      return INX_INIT_COST + (float) (INX_CMP_COST  * lc / l2);
    }
  else
    return INX_INIT_COST;
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
  if (key->key_is_bitmap)
    row_len = row_len / 3; /* assume three bits on the average, makes this less costly than regular */
  if (rpp)
    *rpp = 6000.0 / row_len ;
  return (float) row_len * ROW_COST_PER_BYTE;
}


caddr_t sqlo_iri_constant_name (ST* tree);

float arity_scale (float ar);


#if 1
#define CARD_ADJUST(x) x
#else
#define CARD_ADJUST(x) ((x) < 1 ? (x) + ((1 - (x)) * 0.01) : (x))
#endif


int 
sqlo_enum_col_arity (df_elt_t * pred, dbe_column_t * left_col, float * a1)
{
  int is_allocd = 0;
  df_elt_t * right;
  ptrlong * place;
  caddr_t name, data;
  if (!left_col->col_stat || BOP_EQ != pred->_.bin.op)
    return 0;
  right = pred->_.bin.right;
  data = (caddr_t) pred->_.bin.right->dfe_tree;
  if ((name = sqlo_iri_constant_name ((ST*) data)))
    {
      data = key_name_to_iri_id (NULL, name, 0);
      if (!data)
	goto unknown;
      is_allocd = 1;
    }
  else if (DFE_IS_CONST (right))
    data = (caddr_t) right->dfe_tree;
  else 
    return 0;
  place = (ptrlong*) id_hash_get (left_col->col_stat->cs_distinct, (caddr_t)&data);
  if (is_allocd)
    dk_free_box (data);
  if (place)
    {
      ptrlong count = *place;
      *a1 = ((float)count) / left_col->col_stat->cs_n_values;
      *a1 = CARD_ADJUST (*a1);
      return 1;
    }
 unknown:
  /* it is a constant but it is not mentioned in the sample.  Must be a rare value.  We guess that the vals mentioned in the sampole cover 90% of rows.  */
  if (!left_col->col_defined_in || !left_col->col_defined_in->tb_primary_key)
    return 0;
  {
    float n_unsampled = left_col->col_stat->cs_distinct->ht_count / 10.0;
    float n_rows = dbe_key_count (left_col->col_defined_in->tb_primary_key);
    *a1 =  n_unsampled / (n_rows / 10);
    *a1 = CARD_ADJUST (*a1);
    return 1;
  }
}


void
sqlo_eq_cost (dbe_column_t * left_col, df_elt_t * right, df_elt_t * lower, float * a1)
{
      if (lower && sqlo_enum_col_arity (lower, left_col, a1))
	return;
  if (DFE_IS_CONST (right) &&
	      left_col->col_min && left_col->col_max &&
	      DV_TYPE_OF (left_col->col_min) != DV_DB_NULL && DV_TYPE_OF (left_col->col_max) != DV_DB_NULL &&
      (DVC_LESS == cmp_boxes ((caddr_t) right->dfe_tree, left_col->col_min,
		 left_col->col_collation, left_col->col_collation) ||
       DVC_GREATER == cmp_boxes ((caddr_t) right->dfe_tree, left_col->col_max,
		 left_col->col_collation, left_col->col_collation)))
	    { /* the boundary is constant and its outside min/max */
	      *a1 = 0.1 / left_col->col_n_distinct; /* out of range.  Because unsure, do not make  it exact 0 */
	    }
  else if (DFE_IS_CONST (right) && left_col->col_hist)
	    { /* the boundary is constant and there is a column histogram */
	      int inx, n_level_buckets = 0;

	      DO_BOX (caddr_t *, bucket, inx, ((caddr_t **)left_col->col_hist))
		{
	  if (DVC_MATCH == cmp_boxes ((caddr_t) right->dfe_tree, bucket[1],
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
		  *a1 = 0.1;
		}
	    }
}


#define TA_NTH_IN_ITEM 5001
#define TA_N_IN_ITEMS 5002





int
sqlo_in_list_unit (df_elt_t * pred, float * u1, float * a1)
{
  du_thread_t * thr;
  int n_items, nth;
  df_elt_t ** in_list = sqlo_in_list (pred, NULL, NULL);
  if (!in_list)
    return 0;
  thr = THREAD_CURRENT_THREAD;
  nth = (ptrlong) THR_ATTR (thr, TA_NTH_IN_ITEM);
  n_items = (ptrlong) THR_ATTR (thr, TA_N_IN_ITEMS);
  if (-1 == n_items)
    {
      SET_THR_ATTR (thr, TA_N_IN_ITEMS, (caddr_t)(ptrlong) BOX_ELEMENTS (in_list) - 1);
      nth = 0;
    }
  else if (nth >= BOX_ELEMENTS (in_list) - 1)
    nth = 0;
  sqlo_eq_cost (in_list[0]->_.col.col, in_list[nth + 1], NULL, a1);
  return 1;
}


void
sqlo_pred_unit (df_elt_t * lower, df_elt_t * upper, float * u1, float * a1)
{
  *u1 = (float) COL_PRED_COST;
  if (sqlo_in_list_unit (lower, u1, a1))
    return;
  if (upper == lower)
    upper = NULL;
  if (BOP_EQ == lower->_.bin.op)
    {
      *a1 = (float) 0.03;
      if (lower->_.bin.left == lower->_.bin.right)
	{
	  *a1 = 1; /* recognize the dummy 1=1 */
	  return;
	}
    }
  else if (!upper)
    *a1 = 0.3;
  else
    *a1 = 0.3 * 0.3;

  if (lower->dfe_type != DFE_TEXT_PRED &&
      lower->_.bin.left->dfe_type == DFE_COLUMN &&
      lower->_.bin.left->_.col.col &&
      lower->_.bin.left->_.col.col->col_count != DBE_NO_STAT_DATA)
    {
      dbe_column_t *left_col = lower->_.bin.left->_.col.col;
      if (lower->_.bin.op == BOP_EQ)
	{
      	  sqlo_eq_cost (left_col, lower->_.bin.right, lower, a1);
	}
      else if (lower->_.bin.op == BOP_GT || lower->_.bin.op == BOP_GTE)
	{
	  if (DFE_IS_CONST (lower->_.bin.right) &&
	      left_col->col_max && DV_TYPE_OF (left_col->col_max) != DV_DB_NULL &&
	      DVC_GREATER == cmp_boxes ((caddr_t) lower->_.bin.right->dfe_tree, left_col->col_max,
		left_col->col_collation, left_col->col_collation))
	    { /* lower boundary is a constant and it's above the max */
	      *a1 = 0.001;
	    }
	  else if (DFE_IS_CONST (lower->_.bin.right) && left_col->col_hist)
	    { /* lower boundary is a constant and there's a col histogram */
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
	    { /* upper boundary is a constant and it's below the min */
	      *a1 = 0.001;
	    }
	  else if (DFE_IS_CONST (lower->_.bin.right) && left_col->col_hist)
	    { /* upper boundary is a constant and there's a col histogram */
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
	      if (DV_ANY == left_col->col_sqt.sqt_dtp)
		*a1 = 1; /* in rdf, sometimes a type check isiri_id becomes a like.  It is always true.  Almost needless test. */
	      else
	      *a1 = MIN (5.0 / left_col->col_n_distinct, 0.8);
	    }
	  else
	    {
	      *a1 = 0.00001;
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
  *a1 = CARD_ADJUST (*a1);
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


caddr_t
sqlo_iri_constant_name_1 (ST* tree)
{
  if (DV_STRINGP (tree))
    return (caddr_t)tree;
  if (ST_P (tree, CALL_STMT) && 1 <= BOX_ELEMENTS (tree->_.call.params)
      && DV_STRINGP (tree->_.call.name) 
#ifdef NDEBUG
      && 0 == stricmp (tree->_.call.name, "__BFT")
#else
      && 0 == stricmp (tree->_.call.name, "__box_flags_tweak")
#endif      
      && DV_STRINGP (tree->_.call.params[0]))
    return (caddr_t) tree->_.call.params[0];
  return NULL;
}


caddr_t
sqlo_iri_constant_name (ST* tree)
{
  caddr_t name;
  if (DV_IRI_ID == DV_TYPE_OF (tree))
    return (caddr_t)tree;
  if (ST_P (tree, CALL_STMT) && 1 <= BOX_ELEMENTS (tree->_.call.params)
      && DV_STRINGP (tree->_.call.name) 
      && 0 == strnicmp (tree->_.call.name, "__I2ID", 6)
      && DV_STRINGP ((name = sqlo_iri_constant_name_1 (tree->_.call.params[0]))))
    return name;
  return NULL;
}


#define  RDF_UNTYPED ((caddr_t) 1)
#define RDF_LANG_STRING ((caddr_t) 2)

caddr_t
sqlo_rdf_obj_const_value (ST * tree, caddr_t * val_ret, caddr_t *lang_ret)
{
  if (ST_P (tree, CALL_STMT) && 1 == BOX_ELEMENTS (tree->_.call.params)
      && DV_STRINGP (tree->_.call.name) && nc_strstr (tree->_.call.name, "obj_of_sqlval")
      && DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree->_.call.params[0]))
    {
      if (val_ret) 
	*val_ret = (caddr_t) tree->_.call.params[0];
      return RDF_UNTYPED;
    }
  if (ST_P (tree, CALL_STMT) && 3 == BOX_ELEMENTS (tree->_.call.params)
      && DV_STRINGP (tree->_.call.name) && nc_strstr (tree->_.call.name, "RDF_MAKE_OBJ_OF_TYPEDSQLVAL")
      && DV_STRINGP (tree->_.call.params[0])
      && DV_STRINGP (tree->_.call.params[2]))
    {
      if (val_ret) 
	*val_ret = (caddr_t) tree->_.call.params[0];
      if (lang_ret)
	*lang_ret = (caddr_t) tree->_.call.params[2];
      return RDF_LANG_STRING;
    }
  return 0;
}





#define KS_CAST_UNDEF 16



int
rdf_obj_of_sqlval (caddr_t val, caddr_t * data_ret)
{
  dtp_t dtp = DV_TYPE_OF (val);
  int len;
  if (IS_NUM_DTP (dtp))
    {
      *data_ret = box_copy (val);
      return 1;
    }
  if (DV_STRING == dtp
      && (len = box_length (val)) <= 21)
    {
      caddr_t box = dk_alloc_box (len + 5, DV_STRING);
      box[0] = 1;
      box[1] = 1;
      memcpy (box + 2, val, len - 1);
      box[len + 1] = 0;
      box[len + 2] = 1;
      box[len + 3] = 1;
      box[len + 4] = 0;
      *data_ret =  box;
      return 1;
    }
  return 0;
}


int
rdf_obj_of_typed_sqlval (caddr_t val, caddr_t vtype, caddr_t lang, caddr_t * data_ret)
{
  dtp_t dtp = DV_TYPE_OF (val);
  int len;
  if (RDF_LANG_STRING != vtype)
    return 0;
  if (DV_STRING == dtp
      && (len = box_length (val)) <= 21)
    {
      int lang_id = key_rdf_lang_id (lang);
      caddr_t box;
      if (!lang_id)
	return 0;
      box = dk_alloc_box (len + 5, DV_STRING);
      box[0] = 1;
      box[1] = 1;
      memcpy (box + 2, val, len - 1);
      box[len + 1] = 0;
      box[len + 2] = lang_id & 0xff;
      box[len + 3] = lang_id >> 8;
      box[len + 4] = 0;
      *data_ret =  box;
      return 1;
    }
  return 0;
}



int
sample_search_param_cast (it_cursor_t * itc, search_spec_t * sp, caddr_t data)
{
  caddr_t err = NULL;
  dtp_t target_dtp = sp->sp_cl.cl_sqt.sqt_dtp;
  dtp_t dtp = DV_TYPE_OF (data);
  caddr_t name, vtype, lang;
  if ((name = sqlo_iri_constant_name ((ST*) data)))
    {
      data = key_name_to_iri_id (NULL, name, 0);
      if (!data)
	return KS_CAST_NULL;
      if (IS_IRI_DTP (sp->sp_col->col_sqt.sqt_dtp))
	{
	  ITC_SEARCH_PARAM (itc, data);
	  ITC_OWNS_PARAM (itc, data);
	  return KS_CAST_OK;
      	}
      else if (DV_ANY == sp->sp_col->col_sqt.sqt_dtp)
	{
	  caddr_t any_data  = box_to_any (data, &err);
	  if (err)
	    {
	      dk_free_tree (err);
	      return KS_CAST_UNDEF;
	    }
	  ITC_SEARCH_PARAM (itc, any_data);
	  ITC_OWNS_PARAM (itc, any_data);
	  dk_free_box (data);
	  return KS_CAST_OK;
	}
      else
	{
	  dk_free_box (data);
	  return KS_CAST_NULL;
	}
    }
  if ((vtype = sqlo_rdf_obj_const_value ((ST*) data, &name, &lang)))
    {
      if (RDF_UNTYPED == vtype)
	{
	  if (!rdf_obj_of_sqlval  (name, &data))
	    return KS_CAST_UNDEF;
	}
      else  if (RDF_LANG_STRING == vtype)
	{
	  if (!rdf_obj_of_typed_sqlval  (name, vtype, lang,  &data))
	    return KS_CAST_UNDEF;

	}
      else 
	return KS_CAST_UNDEF;
      if (IS_IRI_DTP (sp->sp_col->col_sqt.sqt_dtp))
	{
	  ITC_SEARCH_PARAM (itc, data);
	  ITC_OWNS_PARAM (itc, data);
	  return KS_CAST_OK;
      	}
      else if (DV_ANY == sp->sp_col->col_sqt.sqt_dtp)
	{
	  caddr_t any_data  = box_to_any (data, &err);
	  if (err)
	    {
	      dk_free_tree (err);
	      return KS_CAST_UNDEF;
	    }
	  ITC_SEARCH_PARAM (itc, any_data);
	  ITC_OWNS_PARAM (itc, any_data);
	  dk_free_box (data);
	  return KS_CAST_OK;
	}
      else
	{
	  dk_free_box (data);
	  return KS_CAST_NULL;
	}
    }
  if (DV_DB_NULL == dtp)
    return KS_CAST_NULL;
  DTP_NORMALIZE (dtp);
  DTP_NORMALIZE (target_dtp);
  if (IS_UDT_DTP (target_dtp))
    return KS_CAST_NULL;
  else if (dtp == target_dtp)
    {
      ITC_SEARCH_PARAM (itc, data);
    }
  else if (DV_ANY == target_dtp)
    {
      data = box_to_any (data, &err);
      if (err)
	{
	  dk_free_tree (err);
	  return KS_CAST_UNDEF;
	}
      ITC_SEARCH_PARAM (itc, data);
      ITC_OWNS_PARAM (itc, data);
      return KS_CAST_OK;
    }
  else
    {
      if (IS_BLOB_DTP (target_dtp))
	return KS_CAST_NULL;

      if (IS_NUM_DTP (dtp) && IS_NUM_DTP (target_dtp))
	{
	  /* compare different number types.  If col more precise than arg, cast to col here, otherwise the cast is in itc_col_check */
	  switch (target_dtp)
	    {
	    case DV_LONG_INT:
	      ITC_SEARCH_PARAM (itc, data); /* all are more precise, no cast down */
	      return 0;
	    case DV_SINGLE_FLOAT:
	      if (DV_LONG_INT == dtp)
		goto cast_param_up;
	      ITC_SEARCH_PARAM (itc, data);
	      return 0;
	    case DV_DOUBLE_FLOAT:
	      goto cast_param_up;
	    case DV_NUMERIC:
	      if (DV_DOUBLE_FLOAT == dtp)
		{
		  ITC_SEARCH_PARAM (itc, data);
		  return 0;
		}
	      goto cast_param_up;
	    }
	  return 0;
	}
    cast_param_up:
      data = box_cast_to (NULL, data, dtp, target_dtp,
			  sp->sp_cl.cl_sqt.sqt_precision, sp->sp_cl.cl_sqt.sqt_scale, &err);
      if (err)
	{
	  dk_free_tree (err);
	  return KS_CAST_UNDEF;
	}
      ITC_SEARCH_PARAM (itc, data);
      ITC_OWNS_PARAM (itc, data);
    }
  return KS_CAST_OK;
}



int
dfe_const_rhs (search_spec_t * sp, df_elt_t * pred, it_cursor_t * itc, int * v_fill)
{
  df_elt_t ** in_list = sqlo_in_list (pred, NULL, NULL);
  df_elt_t * right;
  if (in_list)
    {
      int nth = (ptrlong) THR_ATTR (THREAD_CURRENT_THREAD, TA_NTH_IN_ITEM);
      right = in_list[nth + 1 >= BOX_ELEMENTS(in_list) ? 0 : nth + 1];
    }
  else
    right = pred->_.bin.right;
  if (DFE_CONST == right->dfe_type
      || sqlo_iri_constant_name (right->dfe_tree)
      || sqlo_rdf_obj_const_value (right->dfe_tree, NULL, NULL))
    {
      int res = sample_search_param_cast (itc, sp, (caddr_t) right->dfe_tree);
      *v_fill = itc->itc_search_par_fill;
      return res;
    }
  return KS_CAST_UNDEF;
}

int
dfe_const_to_spec (df_elt_t * lower, df_elt_t * upper, dbe_key_t * key,
		   search_spec_t *sp, it_cursor_t * itc, int * v_fill)
{
  int res = 0;
  df_elt_t ** in_list = sqlo_in_list (lower, NULL, NULL);
  dbe_column_t * left_col;
  if (in_list)
    left_col = in_list[0]->_.col.col;
  else 
    left_col = lower->_.bin.left->_.col.col;
  if (left_col == (dbe_column_t *) CI_ROW)
    SQL_GPF_T(NULL);
  sp->sp_cl = *key_find_cl (key, left_col->col_id);
  sp->sp_col = left_col;
  sp->sp_collation = sp->sp_col->col_sqt.sqt_collation;

  if (!upper || lower == upper)
    {
      int op = in_list ? CMP_EQ : bop_to_dvc (lower->_.bin.op);

      if (op == CMP_LT || op == CMP_LTE)
	{
	  sp->sp_min_op = CMP_NONE;
	  sp->sp_max_op = op;
	  res  =dfe_const_rhs (sp, lower, itc, v_fill);
	  sp->sp_max = *v_fill - 1;
	}
      else
	{
	  sp->sp_max_op = CMP_NONE;
	  sp->sp_min_op = op;
	  res = dfe_const_rhs (sp, lower, itc, v_fill);
	  sp->sp_min = *v_fill - 1;
	}
    }
  else
    {
      sp->sp_min_op = bop_to_dvc (lower->_.bin.op);
      sp->sp_max_op = bop_to_dvc (upper->_.bin.op);
      res = dfe_const_rhs (sp, upper, itc, v_fill);
	  sp->sp_max = *v_fill - 1;
	  res |=  dfe_const_rhs (sp, lower, itc, v_fill);
	  sp->sp_min = *v_fill - 1;
    }
  return res;
}


caddr_t 
itc_sample_cache_key (it_cursor_t * itc)
{
  int inx;
  int64 conds = 0;
  caddr_t * box = (caddr_t*) dk_alloc_box (sizeof (caddr_t) * (2 + itc->itc_search_par_fill), DV_ARRAY_OF_POINTER);
  search_spec_t * sp;
  box[0] = box_num (itc->itc_insert_key->key_id);
  for (sp = itc->itc_key_spec.ksp_spec_array; sp; sp = sp->sp_next)
    {
      conds= (conds << 3) | sp->sp_min_op;
      if (CMP_NONE != sp->sp_max_op)
	conds = (conds << 3) | sp->sp_max_op;
    }
  box[1] = box_num (conds);
  for (inx = 0; inx < itc->itc_search_par_fill; inx++)
    box[inx + 2] = box_copy_tree (itc->itc_search_params[inx]);
  return (caddr_t) box;
}


int64
sqlo_inx_sample_1 (dbe_key_t * key, df_elt_t ** lowers, df_elt_t ** uppers, int n_parts)
{
  sqlo_t * so = NULL;
  caddr_t sc_key = NULL, num, *place;
  int64 res, tb_count;
  buffer_desc_t * buf;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  search_spec_t specs[10];
  int v_fill = 0, inx;
  search_spec_t ** prev_sp;
  ITC_INIT (itc, key->key_fragments[0]->kf_it, NULL);
  dbe_key_count (key); /* this is the max of the sample so must be up to date */
  itc_clear_stats (itc);
  itc_from (itc, key);
  memset (&specs,0,  sizeof (specs));
  prev_sp = &itc->itc_key_spec.ksp_spec_array;
  itc->itc_key_spec.ksp_key_cmp = NULL;
  for (inx = 0; inx < n_parts; inx++)
    {
      res = dfe_const_to_spec (lowers[inx], uppers[inx], key, &specs[inx],
			       itc, &v_fill);
      if (KS_CAST_OK != res)
	{
	  itc_free (itc);
	  return KS_CAST_NULL == res ? 0 : -1;
	}
      if (!so)
	so = lowers[inx] ? lowers[inx]->dfe_sqlo : uppers[inx]->dfe_sqlo;
      *prev_sp = &specs[inx];
      prev_sp = &specs[inx].sp_next;
    }
  sc_key = itc_sample_cache_key (itc);
  if (so->so_sc->sc_sample_cache)
    place = (caddr_t*) id_hash_get (so->so_sc->sc_sample_cache, (caddr_t) &sc_key);
  else 
    {
      so->so_sc->sc_sample_cache = id_hash_allocate (61, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
      place = NULL;
    }
  if (place)
    {
      dk_free_tree (sc_key);
      itc_free (itc);
      return unbox (*place);
    }
  if (so && sqlo_compiler_exceeds_run_factor)
    so->so_last_sample_time = get_msec_real_time ();
  itc->itc_random_search = RANDOM_SEARCH_ON; /* disable use of root cache by itc_reset */
  buf = itc_reset (itc);
  itc->itc_random_search = RANDOM_SEARCH_OFF;
  res = itc_sample (itc, &buf);
  itc_page_leave (itc, buf);
  itc_free (itc);
  num = box_num (res);
  if (so->so_sc->sc_sample_cache)
    id_hash_set (so->so_sc->sc_sample_cache, (caddr_t)&sc_key, (caddr_t)&num);

  tb_count = dbe_key_count (key->key_table->tb_primary_key);
  return MIN (tb_count, res);
}

extern caddr_t rdfs_type;

int64
sqlo_inx_sample (df_elt_t * tb_dfe, dbe_key_t * key, df_elt_t ** lowers, df_elt_t ** uppers, int n_parts)
{
  rdf_inf_ctx_t * ctx = rdf_name_to_ctx (sqlo_opt_value (tb_dfe->_.table.ot->ot_opts, OPT_RDF_INFERENCE));
  if (ctx && 0 == stricmp ("DB.DBA.RDF_QUAD", tb_dfe->_.table.ot->ot_table->tb_name))
    {
      rdf_sub_t * sub;
      caddr_t p_const = NULL, o_const = NULL;
      int inx;
      df_elt_t * o_dfe = NULL, *p_dfe = NULL;
      ST * org_o = NULL, * org_p = NULL;
      for (inx = 0; inx < n_parts; inx++)
	{
	  dbe_column_t * left_col = cp_left_col (lowers[inx]);
	  switch (left_col->col_name[0])
	    {
	    case 'P': p_dfe = lowers[inx]->_.bin.right; org_p = p_dfe->dfe_tree; break;
	    case 'O': o_dfe = lowers[inx]->_.bin.right; org_o = o_dfe->dfe_tree; break;
	    }
	}
      p_const = dfe_iri_const (p_dfe);
      if (box_equal (rdfs_type, p_const)
	  && (o_const = dfe_iri_const (o_dfe))
	  && (sub = ric_iri_to_sub (ctx, o_const))
	  && sub->rs_subclasses)
	{
	  /* the p is rdfstype and o given.  See about counts of subcs */
	  int64 s, est = 0;
	  int any_est = 0;
	  DO_SET (caddr_t, sub_iri, &sub->rs_subclasses)
	    {
	      o_dfe->dfe_tree = (ST*)sub_iri;
	      s = sqlo_inx_sample_1 (key, lowers, uppers, n_parts);
	      if (s >= 0)
		{
		  est += s;
		  any_est = 1;
		}
	    }
	  END_DO_SET();
	  o_dfe->dfe_tree = org_o;
	  return any_est ? est : -1;
	}
      if (p_const && (sub = ric_iri_to_sub (ctx, p_const))
	  && sub->rs_subproperties)
	{
	  /* the p is given and has subproperties */
	  int64 s, est = 0;
	  int any_est = 0;
	  DO_SET (caddr_t, sub_iri, &sub->rs_subproperties)
	    {
	      p_dfe->dfe_tree = (ST*) sub_iri;
	      s = sqlo_inx_sample_1 (key, lowers, uppers, n_parts);
	      if (s >= 0)
		{
		  est += s;
		  any_est = 1;
		}
	    }
	  END_DO_SET();
	  p_dfe->dfe_tree = org_p;
	  return any_est ? est : -1;
	}
    }
  return sqlo_inx_sample_1 (key, lowers, uppers, n_parts);
}


float
dfe_hash_fill_unit (df_elt_t * dfe, float arity)
{
  return HASH_ROW_INS_COST + HASH_COUNT_FACTOR (arity);
}


float 
sqlo_inx_intersect_cost (df_elt_t * tb_dfe, dk_set_t col_preds, dk_set_t group, float * arity_ret)
{
  /* Complicated.  Cost of inx int is the cost of the smallest term times no of terms.
   * card is the card of the term with the least card times product of theselectivities of the rest.  The selectivity is the arity/count of the table */
  int smallest_term = -1, inx;
  float cf = 0;
  int nth_term = 0;
  dbe_table_t * tb = tb_dfe->_.table.ot->ot_table;
  int n_inx = dk_set_length (group);
  float arity[10], ov, cost[10], min = -1, total_cost, p_cost, p_arity, min_rows = -1, a, min_arity = -1;
  float n_rows[10];
  DO_SET (df_inx_op_t *, dio, &group)
    {
      dbe_key_t * prev_key = dio->dio_table->_.table.key;
      dbe_key_t * key = dio->dio_key;
      n_rows[nth_term] = dbe_key_count (dio->dio_table->_.table.ot->ot_table->tb_primary_key);
      dio->dio_table->_.table.key = key;
      dfe_table_cost (tb_dfe, &cost[nth_term], &arity[nth_term], &ov, 1);
      if (-1 == smallest_term || min_arity > arity[nth_term])
	{
	  smallest_term = nth_term;
	  min_arity = arity[nth_term];
	}
      if (-1 == min ||   cost[nth_term] < min)
	min = cost[nth_term];
      cf = cf + log (arity[nth_term]) * ROW_SKIP_COST * 0.1;
      dio->dio_table->_.table.key = prev_key;
      nth_term++;
      if (nth_term > 10)
	break;
    }
  END_DO_SET();
  a = arity[smallest_term];
  for (inx = 0; inx < nth_term; inx++)
    {
      if (inx != smallest_term)
	a *= arity_scale (arity[inx] / n_rows[inx]);
    }
  *arity_ret = a;
  /* must get the main row? If cols refd that are not in any of the inxes. */
  DO_SET (dbe_column_t *, col, &tb_dfe->_.table.ot->ot_table_refd_cols)
    {
      DO_SET (df_inx_op_t *, dio, &group)
	{
	  if (dk_set_member (dio->dio_key->key_parts, (void*) col))
	    goto next_col;
	}
      END_DO_SET();
      /* found a col that is in none of the inxes */
	  goto get_main_row;
    next_col: ;
    }
  END_DO_SET ();
  return cf + (n_inx * min * 0.7);
 get_main_row:
  min = min * n_inx * 0.7;
  total_cost = min + (*arity_ret *
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
      (*arity_ret) *= p_arity;
      total_cost += p_cost * *arity_ret;
    next_pred: ;
    }
  END_DO_SET();
  return cf + total_cost;
}


int
pred_const_rhs (df_elt_t * pred)
{
  df_elt_t * r;
  df_elt_t ** in_list = sqlo_in_list (pred, NULL, NULL);
  if (in_list)
    {
      int nth_in = (ptrlong) THR_ATTR (THREAD_CURRENT_THREAD, TA_NTH_IN_ITEM);
      if (nth_in < 0)
	nth_in = 0;
      r = in_list[nth_in + 1 >= BOX_ELEMENTS (in_list) ? 0 : nth_in + 1];
    }
  else 
    r = pred->_.bin.right;
  if (!r)
    return 0;
  if (DFE_CONST == r->dfe_type )
    {
      dtp_t dtp = DV_TYPE_OF (r->dfe_tree);
      if (DV_SYMBOL != dtp && DV_ARRAY_OF_POINTER != dtp)
	return 1;
    }
  if (sqlo_iri_constant_name (r->dfe_tree)
      || sqlo_rdf_obj_const_value (r->dfe_tree, NULL, NULL))
    return 1;
  return 0;
}

float
arity_scale (float ar)
{

  /*For whom hath ears to hear, listen: Cards of tables like rdf quad
    with full match are too small, like 1e-7 because 1/(product of
    n_distinct of all cols) is good only if all combinations exist and
    they never do.  So, when a card falls under 1, slow down its fall.
    Else after a few tables float underflows and we get no distinction
    between good and bad plans because they both get execd 0 times.  So when
    card goes under 1, scale it between 1 and 0.1.  Increasing
    mapping, less stays less but logarithmically slowed down.  Ad hoc
    formula */ 

  float l;
  if (ar > 1) 
    return ar;
  l = log (10/ar) / log (10);
  return  0.1 + (0.9 * (1 / l));
}


void
dfe_table_cost_1 (df_elt_t * dfe, float * u1, float * a1, float * overhead_ret, int inx_only)
{
  int nth_part = 0;
  dbe_key_t * key = dfe->_.table.key;
  int n_significant = dfe->_.table.key->key_n_significant;
  int unique = 0;
  int unq_limit = key->key_is_unique ? key->key_decl_parts : key->key_n_significant;
  dbe_table_t * tb = dfe->_.table.ot->ot_table;
  float p_cost, p_arity, rows_per_page;
  float inx_cost = 0;
  float inx_arity, inx_arity_guess_for_const_parts = -1;
  float col_arity = 1;
  float col_cost = (float) 0.12;
  float total_cost, total_arity;
  int is_indexed = 1;
  df_elt_t * inx_uppers[5];
  df_elt_t * inx_lowers[5];
  int is_inx_const = 1, inx_const_fill = 0;

  inx_arity = (float) dbe_key_count (dfe->_.table.key);
  dfe->_.table.is_arity_sure = 0;
  if (!inx_only && dfe->_.table.inx_op)
    {
      *u1 = sqlo_inx_intersect_cost (dfe, dfe->_.table.col_preds, dfe->_.table.inx_op->dio_terms, a1);
      dfe->_.table.is_unique = 0;
      overhead_ret = 0;
      return;
    }

  if (!inx_only && dfe->dfe_unit > 0)
    {
      /* do not recompute if already known */
      *a1 = dfe->dfe_arity;
      *u1 = dfe->dfe_unit;
      if (dfe->_.table.hash_role == HR_REF)
	{
	  float fu1, fa1, fo1;
	  dfe_unit_cost (dfe->_.table.hash_filler, 0, &fu1, &fa1, &fo1);
	  *overhead_ret += fu1;
	}
      if (dfe->_.table.join_test)
	{
	  dfe_pred_body_cost (dfe->_.table.join_test, &p_cost, &p_arity, overhead_ret);
	}
      return;
    }
  inx_cost = dbe_key_unit_cost (dfe->_.table.key);
  DO_SET (dbe_column_t *, part, &dfe->_.table.key->key_parts)
    {
      df_elt_t * lower = NULL;
      df_elt_t * upper = NULL;
      lower = sqlo_key_part_best (part, dfe->_.table.col_preds, 0);
      upper = sqlo_key_part_best (part, dfe->_.table.col_preds, 1);
      if (lower || upper)
	{
	  sqlo_pred_unit (lower, upper, &p_cost, &p_arity);
	  if (is_indexed)
	    {
	      inx_cost += (float) COL_PRED_COST * log (dbe_key_count (key)) / log (2);  /*cost of compare * log2 of inx count */
	      inx_arity *= p_arity;
	      if (is_inx_const && inx_const_fill < 4
		  && (lower ? pred_const_rhs (lower) : 1)
		  && (upper ? pred_const_rhs (upper) : 1))
		{
		  inx_lowers[inx_const_fill] = lower;
		  inx_uppers[inx_const_fill] = upper;
		  inx_const_fill++;
		}
	      else 
		{
		  is_inx_const = 0;
		  if (inx_const_fill && nth_part == inx_const_fill)
		    inx_arity_guess_for_const_parts = inx_arity / p_arity; /* inx_arity before being multiplied by the p_arity of the non-const part.  Set exactly once, after seeing the first non-constant key part. */
		}
	      if (!lower || BOP_EQ != lower->_.bin.op)
		is_indexed = 0;
	    }
	  else
	    {
	      col_arity *= p_arity;
	      col_cost += p_cost * col_arity;
	    }
	}
      else
	is_indexed = 0;
      if (!(lower && BOP_EQ == lower->_.bin.op))
	{
	  /* if there is already an eq on the col, we do not give extra selectivity for more conds.  The multiple eqs are mutually eq as generated by sparql */
      DO_SET (df_elt_t *, pred, &dfe->_.table.col_preds)
	{
	  df_elt_t ** in_list = sqlo_in_list (pred, NULL, NULL);
	  dbe_column_t * left_col = in_list ? in_list[0]->_.col.col : 
	    (pred->_.bin.left->dfe_type == DFE_COLUMN ? pred->_.bin.left->_.col.col : NULL);
	  if (DFE_TEXT_PRED == pred->dfe_type)
	    continue;
	  if (DFE_BOP_PRED == pred->dfe_type && part == left_col && pred != lower && pred != upper)
	    {
	      sqlo_pred_unit (pred, NULL, &p_cost, &p_arity);
	      col_arity *= p_arity;
	      col_cost += p_cost * col_arity;
	    }
	}
      END_DO_SET();
	}
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
    inx_arity = MIN (1, inx_arity);
  else if (LOC_LOCAL == dfe->dfe_locus && inx_const_fill
	   && !(dfe->dfe_sqlo->so_sc->sc_is_update && 0 == strcmp (dfe->_.table.ot->ot_new_prefix, "t1")))
    {
      int64 inx_sample = sqlo_inx_sample (dfe, key, inx_lowers, inx_uppers, inx_const_fill);
      if (-1 == inx_sample)
	goto no_sample;
      else if (0 == inx_sample)
	inx_arity = 0.01;
      else 
	inx_arity = inx_sample * inx_arity / (inx_arity_guess_for_const_parts != -1 ? inx_arity_guess_for_const_parts : inx_arity);
      /* Consider if 2 first key parts are const and third is var.  Get the real arity for the const but do not forget the guess  for  the 3rd*/
      dfe->_.table.is_arity_sure = inx_const_fill;
    no_sample: ;
    }
  inx_arity = arity_scale (inx_arity);
  dfe->_.table.is_unique = unique;
  if (key->key_is_bitmap)
    inx_cost *= 0.9; /* tree usually a bit less deep and anyway better working set. */
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
	  dbe_column_t * left_col;
	  df_elt_t ** in_list = sqlo_in_list (pred, NULL, NULL);
	  if (DFE_TEXT_PRED == pred->dfe_type)
	    continue;
	  left_col = in_list ? in_list[0]->_.col.col : pred->_.bin.left->_.col.col;
	  if (DFE_BOP_PRED == pred->dfe_type && !dk_set_member (key->key_parts, (void*) left_col))
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
    }
  else
    {
      p_cost = 0;
      p_arity = 1;
    }

  if (dfe->_.table.is_text_order)
    {
      /* very rough. 1/1000 selected, cost is 1.5*unit of text inx * 1/1000 of indexed table count.
       * no accounting for whether text inx joins with main table or offband ops */
      dbe_table_t *ot_tbl = dfe->_.table.ot->ot_table;
      float text_selectivity;
      float text_key_cost = dbe_key_unit_cost (tb_text_key (ot_tbl)->key_text_table->tb_primary_key);
      int64 ot_tbl_size = dbe_key_count (ot_tbl->tb_primary_key);
      if (dfe->_.table.is_unique)
        text_selectivity = 0.001;
      else
        {
          text_selectivity = (1 + 0.1 * (log (1024 | ot_tbl_size) / log (2))) / (1024 | ot_tbl_size);
        }
      total_arity *= text_selectivity;
      total_cost = 1.5 * text_key_cost + text_key_cost * ot_tbl_size * text_selectivity
	+ total_cost * text_selectivity;
    }
  if (HR_FILL == dfe->_.table.hash_role)
    {
      float fill_arity = total_arity * p_arity; /* join pred may filter before hash insertion */
      total_cost = total_cost + fill_arity * dfe_hash_fill_unit (dfe, fill_arity);
      if (dfe->dfe_locus && IS_BOX_POINTER (dfe->dfe_locus))
	{
	  dfe->_.table.hash_role = HR_NONE;
	  total_cost += sqlo_dfe_locus_rpc_cost (dfe->dfe_locus, dfe);
	  dfe->_.table.hash_role = HR_FILL;
	}
    }
  else if (dfe->_.table.hash_role == HR_REF)
    {
      float fu1, fa1, fo1;
      dfe_unit_cost (dfe->_.table.hash_filler, 0, &fu1, &fa1, &fo1);
      *overhead_ret += fu1;
      total_cost = (float) HASH_LOOKUP_COST + HASH_ROW_COST * MAX (0,  total_arity - 1);
    }
  total_cost += p_cost * total_arity;
  total_arity *= p_arity;
  if (dfe->_.table.ot->ot_is_outer)
    total_arity = MAX (1, total_arity);
  /* the right of left outer has never cardinality < 1.  But the join tests etc are costed at cardinality that can be < 1. So adjust this as last.*/
      dfe->dfe_arity = *a1 = total_arity;
      dfe->dfe_unit = *u1 = total_cost;
}


void
dfe_table_cost (df_elt_t * dfe, float * u1, float * a1, float * overhead_ret, int inx_only)
{
  int n_in, inx;
  du_thread_t * thr = THREAD_CURRENT_THREAD;
  SET_THR_ATTR  (thr, TA_N_IN_ITEMS, (caddr_t) -1);
  SET_THR_ATTR (thr, TA_NTH_IN_ITEM, 0);
  dfe_table_cost_1 (dfe, u1, a1, overhead_ret, inx_only);
  n_in = (ptrlong) THR_ATTR (thr, TA_N_IN_ITEMS);
  if (-1 == n_in)
    return;
  for (inx = 1; inx < n_in; inx++)
    {
      float ov_dum, in_u1, in_a1;
      SET_THR_ATTR (thr, TA_NTH_IN_ITEM, (caddr_t) (ptrlong) inx);
      dfe_table_cost_1 (dfe, &in_u1, &in_a1, &ov_dum, inx_only);
      (*u1) += in_u1;
      (*a1) += in_a1;
    }
  dfe->dfe_unit = *u1;
  dfe->dfe_arity = *a1;
}


void
sqlo_set_cost (df_elt_t * dfe, float * u1, float * a1, float * overhead_ret)
{
  int inx;
  float csum = 0, asum = 0;
  float a_t0 = 0, a_t1 = 0;
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
sqlo_proc_table_cost (df_elt_t * dt_dfe, float * u1, float * a1)
{
  /* See  )what params are given.  Multiply cost by coefficient of each missing param */
  op_table_t *ot = dfe_ot (dt_dfe);
  ST * tree = ot->ot_dt;
  caddr_t * formal = (caddr_t *) ot->ot_dt->_.proc_table.params;
  caddr_t full_name = sch_full_proc_name (wi_inst.wi_schema, tree->_.proc_table.proc,
					  cli_qual (sqlc_client ()), CLI_OWNER (sqlc_client ()));
  query_t * proc = full_name ? sch_proc_def (wi_inst.wi_schema, full_name) : NULL;
  float * costs = proc ? proc->qr_proc_cost : NULL;
  int n_costs = costs ? (box_length ((caddr_t)costs) / sizeof (float )) - 2 : 0;
  int inx;
  if (costs)
    {
      *u1 = costs[0];
      *a1 = costs[1];
    }
  else 
    {
      *u1 = 200;
      *a1 = 10;
    }
  DO_BOX (caddr_t, name, inx, formal)
    {
      dtp_t name_dtp = DV_TYPE_OF (name);
      if (!IS_STRING_DTP (name_dtp) && name_dtp != DV_SYMBOL)
	goto not_given;
	    
      DO_SET (df_elt_t *, colp_dfe, &dt_dfe->_.sub.dt_preds)
	{
	  if (ST_P (colp_dfe->dfe_tree->_.bin_exp.left, COL_DOTTED) &&
	      (!CASEMODESTRCMP (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)
	       || box_equal (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)))
	    goto next_arg;
	  else if (ST_P (colp_dfe->dfe_tree->_.bin_exp.right, COL_DOTTED) &&
		   (!CASEMODESTRCMP (name, colp_dfe->dfe_tree->_.bin_exp.right->_.col_ref.name)
		    || box_equal (name, colp_dfe->dfe_tree->_.bin_exp.right->_.col_ref.name)))
	    goto next_arg;
	}
      END_DO_SET();
      DO_SET (df_elt_t *, colp_dfe, &dt_dfe->_.sub.dt_imp_preds)
	{
	  if (ST_P (colp_dfe->dfe_tree->_.bin_exp.left, COL_DOTTED) &&
	      (!CASEMODESTRCMP (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)
	       || box_equal (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)))
	    goto next_arg;
	  else if (ST_P (colp_dfe->dfe_tree->_.bin_exp.right, COL_DOTTED) &&
		   (!CASEMODESTRCMP (name, colp_dfe->dfe_tree->_.bin_exp.right->_.col_ref.name)
		    || box_equal (name, colp_dfe->dfe_tree->_.bin_exp.right->_.col_ref.name)))
	    goto next_arg;
	}
      END_DO_SET();
      DO_SET (df_elt_t *, colp_dfe, &dt_dfe->_.sub.ot->ot_join_preds)
	{
	  if (ST_P (colp_dfe->dfe_tree->_.bin_exp.left, COL_DOTTED) &&
	      (!CASEMODESTRCMP (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)
	       || box_equal (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)))
	    goto next_arg;
	  else if (ST_P (colp_dfe->dfe_tree->_.bin_exp.right, COL_DOTTED) &&
		   (!CASEMODESTRCMP (name, colp_dfe->dfe_tree->_.bin_exp.right->_.col_ref.name)
		    || box_equal (name, colp_dfe->dfe_tree->_.bin_exp.right->_.col_ref.name)))
	    goto next_arg;
	}
      END_DO_SET();
    not_given:
      if (costs && inx < n_costs)
	{
	  *u1 *= costs[inx+2];
	  *a1 *= costs[inx+2];
	}
      else
	{
	  *u1 *=  2;
	  *a1 *= 2;
	}
    next_arg: ;
    }
  END_DO_BOX;
}


void
sqlo_proc_cost (df_elt_t * dfe, float * u1, float * a1)
{
  ST * tree = dfe->dfe_tree;
  *a1 = 1;
  if (!ARRAYP (tree->_.call.name))
    {
      caddr_t full_name = sch_full_proc_name (wi_inst.wi_schema, tree->_.call.name,
					      cli_qual (sqlc_client ()), CLI_OWNER (sqlc_client ()));
      query_t * proc = full_name ? sch_proc_def (wi_inst.wi_schema, tree->_.call.name) : NULL;
      float * costs = proc ? proc->qr_proc_cost : NULL;
      if (bif_find (tree->_.call.name))
	*u1 = 1;
      else
	*u1 = costs ? costs[0] : 20;
    }
  else
    *u1 = 100;
}


void
dfe_unit_cost (df_elt_t * dfe, float input_arity, float * u1, float * a1, float * overhead_ret)
{
  if (THR_IS_STACK_OVERFLOW (THREAD_CURRENT_THREAD, &dfe, 8000))
    sqlc_error (dfe->dfe_sqlo->so_sc->sc_cc, "42000", "Stack Overflow in cost model");

  switch (dfe->dfe_type)
    {
    case DFE_TABLE:
      dfe_table_cost (dfe, u1, a1, overhead_ret, 0);
      dfe->_.table.in_arity = input_arity;
      break;
    case DFE_DT:
    case DFE_EXISTS:
      /* does not work - breaks ods load case DFE_VALUE_SUBQ: */
      if (dfe->_.sub.generated_dfe)
	dfe_unit_cost (dfe->_.sub.generated_dfe, 1, u1, a1, overhead_ret);
      else
	{
	  if (dfe->_.sub.is_contradiction)
	    {
	      *a1 = 0;
	      *u1 = 1;
	    }
	  if (ST_P (dfe->_.sub.ot->ot_dt, PROC_TABLE))
	    {
	      sqlo_proc_table_cost (dfe, u1, a1);
	      return;
	    }
	  dfe_list_cost (dfe->_.sub.first, u1, a1, overhead_ret, dfe->dfe_locus);
	  if (dfe_ot (dfe) && ST_P (dfe_ot (dfe)->ot_dt, SELECT_STMT) &&
	      !sqlo_is_postprocess (dfe->dfe_sqlo, dfe, NULL))
	    {
	      int is_distinct = SEL_IS_DISTINCT (dfe_ot (dfe)->ot_dt);
	      ST *top_exp = SEL_TOP (dfe_ot (dfe)->ot_dt);
	      ptrlong top_cnt = sqlo_select_top_cnt (dfe->dfe_sqlo, top_exp);

	      if (top_cnt && top_cnt < *a1)
		{
		  *u1 /= *a1 / top_cnt;
		}
	      if (is_distinct)
		{
		  /* assume 10% are dropped, 1.2 * hash ref cost per incoming */
		  *u1 += *a1 * HASH_LOOKUP_COST * 1.3;
		  *a1 *= 0.9;
		}
	    }
	  if (dfe->dfe_type == DFE_EXISTS || dfe->dfe_type == DFE_VALUE_SUBQ)
	    { /* accesses never more than 1 */
	      if (*a1 > 1)
		*u1 /= *a1;
	      if (dfe->dfe_type == DFE_EXISTS)
		{
		  /* an exists never has arity > 1.  If 1, guess 0.5.  If over 1, scale between 0.5 and 1 */
		  *a1 = *a1 < 1 ? *a1 / 2 
		    : 0.99 - (1 / (2 * *a1));
		}
	      else
		*a1 = 1; /*for scalar subq */
	    }
	}
      if (dfe->dfe_type == DFE_DT 
	  && dfe->_.sub.ot->ot_is_outer)
	*a1 = MAX (1, *a1); /* right siode of left oj has min cardinality 1 */

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

    case DFE_CALL:
      sqlo_proc_cost (dfe, u1, a1);
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
	  dfe->dfe_arity = a1;
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
		    {
		      if (!dfe->dfe_unit_includes_vdb)
		    u1 += sqlo_dfe_locus_rpc_cost (dfe->dfe_locus, dfe);
		      dfe->dfe_unit_includes_vdb = 1;
		    }
		}
	      loc = dfe->dfe_locus;
	    }
	  cum += arity * u1;
	  arity *= a1;
	  dfe->dfe_arity = a1;
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

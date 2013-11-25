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


float col_pred_cost = 0.02; /* itc_col_check */
float row_skip_cost = 0.035; /* itc_row_check and 1 iteration of itc_page_search */
float inx_init_cost = 1;  /* fixed overhead of starting an index lookup */
float inx_cmp_cost = 0.25; /* one compare in random access lookup. Multiple by log2 of inx count to get cost of 1 random access */
float row_cost_per_byte = 0.001; /* 200 b of row cost 1 itc_col_check */
float next_page_cost = 5;
float inx_row_ins_cost = 1; /* cost of itc_insert_dv into inx */
float hash_row_ins_cost = 5; /* cost of adding a row to hash */
float hash_mem_ins_cost = 0.7;
float hash_lookup_cost = 0.9;
float hash_row_cost = 0.5;
float cv_instr_cost = 0.1;   /* avg cost of instruction in code_vec_run */
float hash_log_multiplier = 0.05;
float sqlo_agg_cost = 0.0166; /* count, sum etc with no group by */
float sqlo_cs_col_pred_cost = 0.003;
float sqlo_cs_row_cost = 0.00374;
float sqlo_cs_col_ref_cost = 0.0024;
float sqlo_cs_seg_page_cost = 0.2;
float sqlo_cs_intra_seg_cmp_cost = 0.28;
float sqlo_cs_next_set_cost = 0.12;
float sqlo_cl_part_cost = 0.1; /* cluster dfg stage per row cost */

float segc_x[] = {1, 100, 500, 1000, 2000, 10000 };
float segc_y[] = {0.28, 0.45, 0.7, 0.9, 1.2, 2.2};
lin_int_t li_cs_seg_cost = { sizeof (segc_x) / sizeof (float), segc_x, segc_y};

float sm_x[] = {0, 10000, 1000000};
float sm_y[] = {0,  0.11, 0.22 };
lin_int_t li_dc_sort_cost = {3, sm_x, sm_y};


float hm_x[] = {1, 10000, 1000000, 5000000, 30000000, 100000000, 200000000};
float hm_y[] = { 0.042, 0.045, 0.09, 0.15, 0.24, 0.34, 0.4};
lin_int_t li_hash_mem_cost = {sizeof (hm_x) /sizeof  (float), hm_x, hm_y};



float
lin_int (lin_int_t * li, float x)
{
  /* linear interpolation */
  int pt, n = li->li_n_points;
  float k;
  if (x <= li->li_x[0])
    pt = 0;
  else if (x > li->li_x[n - 1])
    pt = n - 1;
  else
    {
      for (pt = 0; pt < n; pt++)
	if (x <= li->li_x[pt + 1])
	  break;
    }
  k =  (li->li_y[pt + 1] - li->li_y[pt]) / (li->li_x[pt + 1] - li->li_x[pt]);
  return li->li_y[pt] + k * (x - li->li_x[pt]);
}

void dfe_list_cost (df_elt_t * dfe, float * unit_ret, float * arity_ret, float * overhead_ret, locus_t *loc);
#define ABS(x) (x < 0 ? -(x) : x)


int
key_n_partitions (dbe_key_t * key)
{
  if (!key->key_partition)
    return 1;
  else
    {
      cluster_map_t * clm = key->key_partition->kpd_map;
      int n_hosts;
      return clm->clm_distinct_slices;
      n_hosts = BOX_ELEMENTS (key->key_partition ->kpd_map->clm_hosts);
      return n_hosts;
    }
}

int64
dbe_key_count (dbe_key_t * key)
{
  dbe_table_t * tb = key->key_table;
  if (key->key_table->tb_count != DBE_NO_STAT_DATA)
    return MAX (1, key->key_table->tb_count);
  else if (tb->tb_count_estimate == DBE_NO_STAT_DATA
	   || ABS (tb->tb_count_delta / key_n_partitions (tb->tb_primary_key)) > tb->tb_count_estimate / 5)
    {
      if (find_remote_table (tb->tb_name, 0))
	return 10000; /* if you know nothing, assume a remote table is 10K rows */
      tb->tb_count_estimate = key_count_estimate (tb->tb_primary_key, tb->tb_primary_key->key_is_elastic ? 1 : 3, 1);
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


float
dfe_cs_row_cost (df_elt_t * dfe, float inx_card, float col_card)
{
  dbe_key_t * key = dfe->_.table.key;
  float ref_cost = 0, cost;
  DO_SET (df_elt_t *, col, &dfe->_.table.out_cols)
    {
      int nth = dk_set_position (key->key_parts, col->_.col.col);
      if (nth != -1 && nth < key->key_n_significant)
	ref_cost += sqlo_cs_col_ref_cost * ((1.0 + nth) / (1.0 + key->key_n_significant ));
      else
	ref_cost += sqlo_cs_col_ref_cost;
    }
  END_DO_SET();
  cost = inx_card * ref_cost;
  cost += inx_card * sqlo_cs_row_cost;
  return cost;
}


float
dbe_key_row_cost (dbe_key_t * key, float * rpp, int * key_len)
{
  int is_col = key->key_is_col, nth = 0;
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
	{ /* precision continues ones */
	  if (k_col->col_avg_len)
	    col_len = k_col->col_avg_len;
	  else if (k_col->col_sqt.sqt_precision > 0)
	    col_len = k_col->col_sqt.sqt_precision;
	}
      else if (IS_BLOB_DTP (k_col->col_sqt.sqt_dtp))
	col_len = 120;
      row_len += col_len;
      nth++;
      if (nth == key->key_n_significant)
	{
	  if (key_len)
	    *key_len = row_len;
	  if (is_col)
	    break;
	}
    }
  END_DO_SET ();
  /* for column-wise , approx 16 bytes per col ref */
  if (is_col)
    row_len += dk_set_length (key->key_parts) * 16;
  if (key->key_is_bitmap)
    row_len = row_len / 3; /* assume three bits on the average, makes this less costly than regular */
  if (rpp)
    *rpp = (PAGE_DATA_SZ * 0.9) / row_len ;
  return (float) row_len * ROW_COST_PER_BYTE;
}


caddr_t
pred_rhs_iri (df_elt_t * pred)
{
  df_elt_t * right = pred->_.bin.right;
  if (DFE_CONST == right->dfe_type && DV_IRI_ID == DV_TYPE_OF (right->dfe_tree))
    return (caddr_t)right->dfe_tree;
  return NULL;
}


float 
dfe_scan_card (df_elt_t * dfe)
{
  /* count  of rows in the index or if rdf quad with fixed p then the count of quads with the p. */
  dbe_table_t * tb = dfe->_.table.ot->ot_table;
  caddr_t p = NULL;
  float card = 0;
  float * place;
  dbe_key_t * key = dfe->_.table.key;
  if (!tb_is_rdf_quad (tb))
    return dbe_key_count (key);
  DO_SET (df_elt_t *, pred, &dfe->_.table.col_preds)
    {
      if (((DFE_BOP_PRED  == pred->dfe_type || DFE_BOP == pred->dfe_type) && BOP_EQ == pred->_.bin.op)
	  && 'P' == toupper (pred->_.bin.left->_.col.col->col_name[0])
	  && (p = pred_rhs_iri (pred)))
	break;
    }
  END_DO_SET();
  if (!p || !key->key_p_stat)
    return dbe_key_count (key);
  mutex_enter (alt_ts_mtx);
  place = (float*)id_hash_get (key->key_p_stat, (caddr_t)&((iri_id_t*)p)[0]);
  if (place)
    card = place[0];
  mutex_leave (alt_ts_mtx);
  if (!card)
    return dbe_key_count (key);
  return card;
}


df_elt_t *
dfe_prev_tb_up (df_elt_t * pt)
{
  while (pt)
    {
      if (DFE_TABLE == pt->dfe_type && HR_NONE == pt->_.table.hash_role)
	return pt;
      if (pt->dfe_prev)
	return pt->dfe_prev;
      pt = pt->dfe_super;
    }
  return NULL;
}


int
dfe_is_index_ord_subq (df_elt_t * dfe)
{
  if (dfe->_.sub.generated_dfe)
    dfe = dfe->_.sub.generated_dfe;
  for (dfe = dfe; dfe; dfe = dfe->dfe_next)
    {
      if (DFE_TABLE == dfe->dfe_type && !dfe->_.table.hash_role
	  && dfe->_.table.in_order)
	return 1;
    }
  return 0;
}


int
pred_has_inx_subq (df_elt_t ** body)
{
  dtp_t dtp;
  if (!IS_BOX_POINTER (body))
    return 0;
  dtp = DV_TYPE_OF (body);
  if (DV_ARRAY_OF_POINTER == dtp)
    {
      int inx;
      for (inx = 1; inx < BOX_ELEMENTS (body); inx++)
	{
	  df_elt_t * elt = body[inx];
	  if ((DFE_EXISTS == elt->dfe_type || DFE_VALUE_SUBQ == elt->dfe_type)
	      && dfe_is_index_ord_subq ((df_elt_t*)elt))
	    return 1;
	  if ((BOP_AND == elt->dfe_type || BOP_OR == elt->dfe_type  || BOP_NOT == elt->dfe_type)
	      && pred_has_inx_subq  ((df_elt_t**)elt))
	    return 1;
	}
    }
  return 0;
}


df_elt_t *
dfe_prev_tb (df_elt_t * dfe, float * card_between_ret, int stop_on_new_order)
{
  /* returns the previous index accessing table (not hash probe) in join order.  If stop_on_new_order, does not go beyond possibly order sensitive subqs */
  df_elt_t * pt;
  pt = dfe->dfe_prev;
  while (pt)
    {
      if (stop_on_new_order)
	{
	  if (DFE_DT == pt->dfe_type 
	      || (DFE_VALUE_SUBQ == pt->dfe_type && dfe_is_index_ord_subq (pt)))
	    return NULL;
	  if (DFE_TABLE == pt->dfe_type && pred_has_inx_subq (pt->_.table.join_test))
	    return NULL;
	}
      if (pt->dfe_arity)
	(*card_between_ret) *= pt->dfe_arity;
      if (DFE_TABLE == pt->dfe_type && HR_NONE == pt->_.table.hash_role)
	return pt;
      if (DFE_ORDER == pt->dfe_type || DFE_GROUP == pt->dfe_type)
	return NULL;
      if (pt->dfe_prev)
	pt = pt->dfe_prev;
      else
	{
	  df_elt_t * sup = dfe_prev_tb_up (pt);
	  if (!sup)
	    return NULL;
	  pt = sup;
	}
    }
  return NULL;
}

int pred_const_rhs (df_elt_t * pred);


int
dfe_lead_const (df_elt_t * dfe)
{
  int n = 0;
  dbe_key_t * key = dfe->_.table.key;
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      df_elt_t * lower = sqlo_key_part_best (col, dfe->_.table.col_preds, 0);
      if (!(lower &&  BOP_EQ == lower->_.bin.op && pred_const_rhs (lower)))
	break;
      n++;
      if (n == key->key_n_significant)
	return n;
    }
  END_DO_SET ();
  return n;
}

df_elt_t *
dfe_key_nth_dfe (df_elt_t * dfe, int nth)
{
  caddr_t col_name = ((dbe_column_t *)dk_set_nth (dfe->_.table.key->key_parts, nth))->col_name;
  ST * st 
= t_listst (3, COL_DOTTED, dfe->_.table.ot->ot_new_prefix, col_name);
  return sqlo_df_elt (dfe->dfe_sqlo, st);
}

#define CL_NO_CLUSTER 0
#define CL_COLOCATED 1
#define CL_NOT_COLOCATED 2


df_elt_t *
dfe_col_by_id (df_elt_t * dfe, oid_t col_id)
{
  dbe_column_t * col = sch_id_to_column (wi_inst.wi_schema, col_id);
  caddr_t col_name;
  ST * st;
  if (!col)
    return NULL;
  col_name = col->col_name;
    st = t_listst (3, COL_DOTTED, dfe->_.table.ot->ot_new_prefix, col_name);
  return sqlo_df_elt (dfe->dfe_sqlo, st);
}


int
dfe_cl_colocated (df_elt_t * prev, df_elt_t * dfe)
{
  return CL_NO_CLUSTER;
}


int 
dfe_n_in_order (df_elt_t * dfe, df_elt_t * prev_tb, df_elt_t ** prev_ret, float * card_between, int * eq_on_ordering, int * cl_colocated)
{
  int c1, c2, n1, n2, mx, nth;
  int n_col_eqs = 0;
  df_elt_t * col1, *col2, *lower1, *upper1;
  if (HR_FILL != dfe->_.table.hash_role);
  if (!prev_tb)
    prev_tb = dfe_prev_tb (dfe, card_between, 0);
  *prev_ret = prev_tb;
  if (!prev_tb)
    {
      *cl_colocated = dfe->_.table.key->key_partition ? CL_NOT_COLOCATED : CL_NO_CLUSTER;
      return 0;
    }
  *cl_colocated = dfe_cl_colocated (prev_tb, dfe);
  c1 = dfe_lead_const (prev_tb);
  c2 = dfe_lead_const (dfe);
  n1 = prev_tb->_.table.key->key_n_significant;
  n2 = dfe->_.table.key->key_n_significant;
  mx = MIN (n1 - c1, n2 - c2);
  for (nth = 0; nth < mx; nth++)
    {
      col1 =  dfe_key_nth_dfe (prev_tb, c1 + nth);
      if (!col1)
	break;
      col2 = dfe_key_nth_dfe (dfe, c2 + nth);
      if (!col2)
	break;
      if (!sqlo_is_col_eq (dfe->dfe_sqlo->so_this_dt, col1, col2))
	break;
      lower1 = sqlo_key_part_best (col1->_.col.col, prev_tb->_.table.col_preds, 0);
      upper1 = sqlo_key_part_best (col1->_.col.col, prev_tb->_.table.col_preds, 1);
      if (lower1 && dfe_is_eq_pred (lower1))
	n_col_eqs++;
      else  if (lower1)
	*card_between *= lower1->dfe_arity;
      if (upper1)
	*card_between *= upper1->dfe_arity;
    }
  *eq_on_ordering = n_col_eqs;
  return nth;
}


df_elt_t *
cp_left_col_dfe (df_elt_t * lower)
{
  df_elt_t ** in_list = sqlo_in_list (lower, NULL, NULL);
  if (in_list)
    return in_list[0];
  else
    return lower->_.bin.left;
}


float
dfe_cs_seg_cost (df_elt_t * dfe)
{
  /* cost of first row from a column wise seg */
  float cost = 0;
  DO_SET (df_elt_t *, col, &dfe->_.table.out_cols)
    {
      cost += sqlo_cs_seg_page_cost;
    }
  END_DO_SET();
  DO_SET (df_elt_t *, cp, &dfe->_.table.col_preds)
    {
      df_elt_t * left_col = cp_left_col_dfe (cp);
      if (dk_set_member (dfe->_.table.out_cols, left_col))
	continue;
      cost += sqlo_cs_seg_page_cost;
    }
  END_DO_SET();
  return cost;
}


float
dfe_key_next_cost (df_elt_t *dfe, float spacing, int is_same_parent)
{
  /* cost in row wise index to look for next set so much fwd.  If col wise, the distance is in logical rows, so divide by rows in seg */
  float lg, col_seg_time = 0;
  dbe_key_t * key = dfe->_.table.key;
  spacing += 2; /* never under 1 comparison */
  if (key->key_is_col)
    {
      /* one comparison cover as many rows as in seg, overhead is more since seg must be entered, i.e. accessed cols must be fetched */
      float rows_per_seg = key->key_segs_sampled ? key->key_rows_in_sampled_segs  / key->key_segs_sampled : 10000;
    spacing /= rows_per_seg;
    col_seg_time = dfe_cs_seg_cost (dfe);
    }
  if (is_same_parent)
    col_seg_time += 1.9; /* one up and one down transit if going to sibling under same parent */
  else  if (spacing > 4)
    spacing /= 2;
    
  lg = log (spacing) / log (2);
  return  (lg * key->key_n_significant * inx_cmp_cost) + col_seg_time;
}

float 
dfe_key_seg_next_cost (df_elt_t * dfe, float spacing)
{
  /* cost in column wise seg to search the next row so far  fwd */
  spacing += 2; /*log2 is never under one comparison */
  return sqlo_cs_next_set_cost + lin_int (&li_cs_seg_cost, spacing);
}


float
dfe_vec_index_unit (df_elt_t * dfe, float spacing)
{
  dbe_key_t * key = dfe->_.table.key;
  float rows_per_page;
  int key_len;
  float inx_cost = dbe_key_unit_cost (key);
  float fanout;
  float n_from_top, n_sib, n_in_sibs, n_page, n_seg;
  dbe_key_row_cost (key, &rows_per_page, &key_len);
  fanout = PAGE_DATA_SZ * 0.9 /key_len;
  n_in_sibs = fanout * rows_per_page;
  if (key->key_is_col)
    {
      float n_in_seg = key->key_segs_sampled ? key->key_rows_in_sampled_segs / key->key_segs_sampled : 16000 ;
      n_in_sibs *= n_in_seg;
      rows_per_page *= n_in_seg;
      if (spacing > n_in_sibs)
	return dbe_key_unit_cost (key);
      if (spacing > rows_per_page)
	{
	  n_from_top = spacing / n_in_sibs;
	  return  inx_cost * n_from_top + (1 - n_from_top) * dfe_key_next_cost (dfe, spacing, 1);
	}
      else if (spacing > n_in_seg)
	{
	  n_from_top = spacing / n_in_sibs;
	  n_sib = (1 - n_from_top) * (spacing / rows_per_page);
	  n_page = (1 - n_from_top - n_sib);
	  return inx_cost * n_from_top + dfe_key_next_cost (dfe, n_in_sibs, 1) + n_page * dfe_key_next_cost (dfe, spacing, 0);
	}
      else
	{
	  n_from_top = spacing / n_in_sibs;
	  n_sib = (1 - n_from_top) * (spacing / rows_per_page);
	  n_page = (1 - n_from_top - n_sib) * (spacing / n_in_seg);
	  n_seg = 1 - n_from_top - n_sib - n_page;
	  return inx_cost * n_from_top + n_sib * dfe_key_next_cost (dfe, n_in_sibs, 1) + n_page * dfe_key_next_cost (dfe, rows_per_page, 0) + dfe_key_seg_next_cost (dfe, spacing);
	}
    }
  else
    {
      if (spacing > n_in_sibs)
	return dbe_key_unit_cost (key);
      if (spacing > rows_per_page)
	{
	  float n_from_top = spacing / n_in_sibs;
	  return  inx_cost * n_from_top + (1 - n_from_top) * dfe_key_next_cost (dfe, spacing, 1);
	}
      else
	{
	  n_from_top = spacing / n_in_sibs;
	  n_sib = (1 - n_from_top) * (spacing / rows_per_page);
	  n_page = (1 - n_from_top - n_sib);
	  return inx_cost * n_from_top + n_sib * dfe_key_next_cost (dfe, n_in_sibs, 1) + n_page * dfe_key_next_cost (dfe, spacing, 0);
	}
    }
}

int enable_vec_cost = 1;

float 
dfe_vec_inx_cost (df_elt_t * dfe, index_choice_t * ic, int64 sample)
{
  /* determine distance between consecutive hits.  If in order with previous, will be distance of previous times hanout of this if fanout > 1.
   * if not in order, will be card of the table as selected by leading constants divided by min of expected inputs and max vector size */
  float sort_cost = 0;
  df_elt_t * prev_tb;
  float card_between = 1;
  int eq_on_ordering = 0;
  int order, cl_colocated = 0;
  float spacing;
  dbe_key_t * key = dfe->_.table.key;
  float ref_card = 1;
  if (HR_NONE != dfe->_.table.hash_role)
    return 8; /* hash fillers and refs do not take this into account */
  order = dfe_n_in_order  (dfe, NULL, &prev_tb, &card_between, &eq_on_ordering, &cl_colocated);
  ic->ic_in_order = order;
  ref_card = dfe_arity_with_supers (dfe->dfe_prev);;
  if (!order)
    {
      float t_card;
      int slices;
      float vec_sz, max_vec;
      int64 key_card = dbe_key_count (dfe->_.table.key);
      if (ic->ic_leading_constants)
	t_card = -1 != sample ? sample : key_card;
      else
	t_card = key_card;
      slices = key->key_partition ? key->key_partition->kpd_map->clm_distinct_slices : 1;
      max_vec = dc_max_batch_sz / slices;
      if (1 == slices && ref_card < enable_qp * dc_max_batch_sz && ref_card > dc_batch_sz * enable_qp)
	max_vec = ref_card / enable_qp;
      vec_sz = MIN (max_vec, ref_card);
      vec_sz = MAX (1, vec_sz);
      spacing = t_card / vec_sz;
      dfe->_.table.hit_spacing = spacing;
      vec_sz = MIN (ref_card, max_vec);
      sort_cost = lin_int (&li_dc_sort_cost, vec_sz);
    }
  else
    {
      if (eq_on_ordering)
	{
	  dfe->_.table.hit_spacing = prev_tb->_.table.hit_spacing / card_between;
	  /* if many matches, distance to next set of matches is as less by as many */
	  if (ic->ic_inx_card > 1)
	    dfe->_.table.hit_spacing -= MAX (0.1, MIN (dfe->_.table.hit_spacing - 1, ic->ic_inx_card));
	}
      else
	{
	  float t_card = dfe_scan_card (prev_tb);
	  dfe->_.table.hit_spacing = t_card / prev_tb->dfe_arity;
	}
    }
  if (CL_NOT_COLOCATED == cl_colocated)
    {
      dfe->_.table.is_cl_part_first = 1;
      ic->ic_is_cl_part_first = 1;
      sort_cost += sqlo_cl_part_cost;
    }
  else
    dfe->_.table.is_cl_part_first = 0;
  ic->ic_spacing = dfe->_.table.hit_spacing;
  return  dfe_vec_index_unit (dfe, dfe->_.table.hit_spacing) + sort_cost;
}


void
dfe_clear_prev_cost (df_elt_t * from_dfe, df_elt_t * prev_dfe)
{
  /* loop over previous dfes starting with from_dfe's until prev_dfe and clear the cost of them */
  while (from_dfe && from_dfe != prev_dfe)
    {
      from_dfe->dfe_unit = 0;
      if (from_dfe->dfe_prev)
	from_dfe = from_dfe->dfe_prev;
      else
	from_dfe = from_dfe->dfe_super;
      if (from_dfe)
	from_dfe->dfe_unit = 0;
    }
}


void
dfe_revert_scan_order (df_elt_t * dfe, df_elt_t * prev_tb, dbe_key_t * prev_key)
{
  float alt_unit, alt_card, alt_ov;
  prev_tb->_.table.key = prev_key;
  dfe_clear_prev_cost (dfe, prev_tb);
  dfe_list_cost (prev_tb, &alt_unit, &alt_card, &alt_ov, prev_tb->dfe_locus);
}




int
dfe_try_ordered_key (df_elt_t * prev_tb, df_elt_t * dfe)
{
  int any_tried = 0;
  float prev_card, prev_unit, prev_ov, card_between;
  dbe_key_t * save_key = prev_tb->_.table.key;
  dbe_table_t * tb = prev_tb->_.table.ot->ot_table;
  int in_order;
  if (sqlo_opt_value (prev_tb->_.table.ot->ot_opts, OPT_INDEX))
    return 0;
  DO_SET (dbe_key_t *, key, &tb->tb_keys)
    {
      int cl_colocated = 0, eq_on_ordering = 0;
      if (key == save_key || key->key_distinct)
	continue;
      prev_tb->_.table.key = key;
      in_order = dfe_n_in_order (dfe, prev_tb, &prev_tb, &card_between, &eq_on_ordering, &cl_colocated);
      if (in_order)
	{
	  float alt_card, alt_unit, alt_ov;
	  any_tried = 1;
	  dfe_list_cost (prev_tb, &prev_unit, &prev_card, &prev_ov, prev_tb->dfe_locus);
	  dfe_clear_prev_cost (dfe, prev_tb);
	  dfe_list_cost (prev_tb, &alt_unit, &alt_card, &alt_ov, prev_tb->dfe_locus);
	  if (alt_unit < prev_unit)
	    return 1;

	}
    }
  END_DO_SET();
  prev_tb->_.table.key = save_key;
  if (any_tried)
    {
      dfe_clear_prev_cost (dfe, prev_tb);
      dfe_list_cost (prev_tb, &prev_unit, &prev_card, &prev_ov, prev_tb->dfe_locus);
    }
  return 0;
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
      ptrlong count = CS_N_VALUES (*place);
      *a1 = ((float)count) / left_col->col_stat->cs_n_values;
      *a1 = CARD_ADJUST (*a1);
      return 1;
    }
 unknown:
  /* it is a constant but it is not mentioned in the sample.  Must be a rare value.  We guess that the vals mentioned in the sample cover 90% of rows.  */
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
	  dbe_column_t * right_col = DFE_COLUMN == right->dfe_type ? right->_.col.col : NULL;
	  float n_dist = left_col->col_n_distinct;
	  int is_rdf_col = (tb_is_rdf_quad (left_col->col_defined_in) || (right_col && tb_is_rdf_quad (right_col->col_defined_in)));
	  if (!is_rdf_col && right_col && right_col->col_n_distinct && right_col->col_n_distinct < left_col->col_n_distinct)
	    n_dist = right_col->col_n_distinct;
	  if (!is_rdf_col && right_col && COL_KP_UNQ != left_col->col_is_key_part &&  COL_KP_UNQ == right_col->col_is_key_part)
	    n_dist = right_col->col_n_distinct;
	  *a1 = 1.0 / n_dist;
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


int dfe_range_card (df_elt_t * tb_dfe, df_elt_t * lower, df_elt_t * upper, float * card);



void
sqlo_pred_unit_1 (df_elt_t * lower, df_elt_t * upper, df_elt_t * in_tb, float * u1, float * a1)
{
  if (lower && lower->dfe_arity && lower->dfe_unit)
    {
      *u1 = lower->dfe_unit;
      *a1 = lower->dfe_arity;
      return;
    }
  if (!in_tb)
    *u1 = col_pred_cost * 2;
  else if (in_tb->_.table.key->key_is_col)
    *u1 = sqlo_cs_col_pred_cost;
  else
    *u1 = COL_PRED_COST;
  if (sqlo_in_list_unit (lower, u1, a1))
    return;
  if (upper == lower)
    upper = NULL;
  if (BOP_EQ == lower->_.bin.op)
    {
      *a1 = (float) 0.03;
      if (lower->_.bin.left == lower->_.bin.right
	  && DFE_COLUMN != lower->_.bin.left->dfe_type)
	{
	  /* x=x is always true except if x is a column.  This idiom is used for joining between different keys on an index path */
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
		*a1 = MIN (0.1 / (1.0 + log (2.0 + left_col->col_n_distinct)), 0.8);
	    }
	  else
	    {
	      *a1 = 0.01;
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


void
sqlo_pred_unit (df_elt_t * lower, df_elt_t * upper, df_elt_t * in_tb, float * u1, float * a1)
{
  sqlo_pred_unit_1 (lower, upper, in_tb, u1, a1);
  if (lower)
    {
      lower->dfe_arity = *a1;
      if (upper)
	upper->dfe_arity = 1;
    }
  else if (upper)
    upper->dfe_arity = *a1;
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



typedef struct pred_sort_s
{
  int 	pso_nth;
  float	pso_card;
  float	pso_cost;
  char	pso_is_placed;
} pred_sort_t;


typedef struct pred_sort_stat_s {
  float 	pst_best_cost;
  int *	pst_order;
  int *	pst_best_order;
} pred_sort_stat_t;


void
pst_pred_sort_1 (pred_sort_stat_t * pst, pred_sort_t * pso, int n_preds, float cost, float card, int level)
{
  int inx;
  if (level == n_preds)
    {
      pst->pst_best_cost = cost;
      memcpy (pst->pst_best_order, pst->pst_order, n_preds * sizeof (int));
      return;
    }
  for (inx = 0;  inx < n_preds; inx++)
    {
      pred_sort_t * ps = &pso[inx];
      if (!ps->pso_is_placed)
	{
	  float cost1 = cost + card * ps->pso_cost;
	  float card1 = card * ps->pso_card;
	  if (-1 == pst->pst_best_cost || cost1 < pst->pst_best_cost)
	    {
	      ps->pso_is_placed = 1;
	      pst->pst_order[level] = ps->pso_nth;
	      pst_pred_sort_1 (pst, pso, n_preds, cost1, card1, level + 1);
	      ps->pso_is_placed = 0;
	    }
	}
    }
}


int enable_pred_sort = 1;

#define PRED_SORT_MAX 100


void
pst_pred_sort (pred_sort_stat_t * pst, pred_sort_t * pso, df_elt_t ** body, int n_preds)
{
  df_elt_t * reorder[PRED_SORT_MAX];
  int inx;
  if (!enable_pred_sort || n_preds > 8)
    return;
  pst->pst_best_cost  = -1;
  pst_pred_sort_1 (pst, pso, n_preds,  0, 1, 0);
  for (inx = 0; inx < n_preds; inx++)
    reorder[inx] = body[pst->pst_best_order[inx]];
  memcpy (&body[1], reorder, n_preds * sizeof (caddr_t));
}


void
dfe_pred_body_cost (df_elt_t **body, float * unit_ret, float * arity_ret, float * overhead_ret)
{
  pred_sort_t pso_auto[PRED_SORT_MAX];
  int order_auto[PRED_SORT_MAX];
  int best_order_auto[PRED_SORT_MAX];
  pred_sort_stat_t pst;
  pred_sort_t * pso = pso_auto;
  int inx;
  memset (&best_order_auto, 0, sizeof (best_order_auto));
  memset (&order_auto, 0, sizeof (order_auto));
  if (DV_TYPE_OF (body) == DV_ARRAY_OF_POINTER)
    {
      ptrlong op = (ptrlong) body[0];
      float u1, a1 = 1, cum = 0, arity = 1;
      int n_terms = BOX_ELEMENTS (body);
      pst.pst_order = order_auto;
      pst.pst_best_order = best_order_auto;
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
	      if (inx < PRED_SORT_MAX + 1)
		{
		  pso[inx - 1].pso_cost = u1;
		  pso[inx - 1].pso_card = 1 - a1;
		  pso[inx - 1].pso_nth = inx;
		  pso[inx - 1].pso_is_placed = 0;
		}
		  cum += (1 - arity) * u1;
		  arity *= 1 - a1;
		}
	  pst.pst_best_cost = cum;
	  pst_pred_sort (&pst, pso, body, n_terms - 1);
	  *arity_ret = 1 - arity;
	  *unit_ret = pst.pst_best_cost;
	      break;
	  case BOP_AND:
	  for (inx = 1; inx < n_terms; inx++)
	    {
	      dfe_pred_body_cost ((df_elt_t **) body[inx], &u1, &a1, overhead_ret);
	      if (inx < PRED_SORT_MAX + 1)
		{
		  pso[inx - 1].pso_cost = u1;
		  pso[inx - 1].pso_card = a1;
		  pso[inx - 1].pso_nth = inx;
		  pso[inx - 1].pso_is_placed = 0;
		}
	      cum += arity * u1;
	      arity *= a1;
	    }
	  pst.pst_best_cost = cum;
	  pst_pred_sort (&pst, pso, body, n_terms - 1);
	  *arity_ret = arity;
	  *unit_ret = pst.pst_best_cost;
	  break;
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
      if (pred->dfe_type == DFE_BOP_PRED || (pred->dfe_type == DFE_BOP && pred->_.bin.op >= BOP_EQ && pred->_.bin.op <= BOP_GTE))
	sqlo_pred_unit (pred, NULL, NULL, unit_ret, arity_ret);
      else
	dfe_unit_cost ((df_elt_t *) body, 1, unit_ret, arity_ret, overhead_ret);
    }
}

caddr_t sqlo_rdf_obj_const_value (ST * tree, caddr_t * val_ret, caddr_t *lang_ret);


/* geo hits estimate */

#include "geo.h"
#include "math.h"

double
sqlo_double_literal (ST * tree, int * is_lit)
{
  *is_lit = 1;
  switch (DV_TYPE_OF (tree))
    {
    case DV_LONG_INT:
      return (double) unbox ((caddr_t) tree);
    case DV_SINGLE_FLOAT: return unbox_float ((caddr_t)tree);
    case DV_DOUBLE_FLOAT: return unbox_double ((caddr_t)tree);
    case DV_NUMERIC:
      {
	double d;
	numeric_to_double ((numeric_t)tree, &d);
	return d;
      }
    case DV_ARRAY_OF_POINTER:
      {
	caddr_t val = NULL;
	if (sqlo_rdf_obj_const_value (tree, &val, NULL))
	  return sqlo_double_literal ((ST *) val, is_lit);
      }
    default:
      *is_lit = 0;
      return 0;
    }
}


slice_id_t
key_one_slice (dbe_key_t * key)
{
  if (key->key_is_elastic)
    {
      DO_LOCAL_CSL (csl, key->key_partition->kpd_map)
	return csl->csl_id;
      END_DO_LOCAL_CSL;
}
return QI_NO_SLICE;
}


float
sqlo_geo_count (df_elt_t * tb_dfe, df_elt_t * pred)
{
  char * str;
  dbe_key_t * id_key = tb_text_key (tb_dfe->_.table.ot->ot_table);
  dbe_table_t * tb = id_key->key_geo_table;
  float card;
  int gt;
  ST ** args = sqlc_geo_args (pred->dfe_tree, &gt);
  int prec_literal = 0;
  double prec = 0;
  geo_t * geo = NULL;
  if (BOX_ELEMENTS (args) > 2)
    prec = sqlo_double_literal (args[2], &prec_literal);
  if (DV_GEO == DV_TYPE_OF (args[0]))
    geo = (geo_t*) args[0];
  else if (DV_GEO == DV_TYPE_OF (args[1]))
    geo = (geo_t*)args[1];
  if (prec_literal && !geo)
    {
      /* precision is given but geometry is unknown.  Estimate card by ratio of surfaces */
      int64 ct = dbe_key_count (tb->tb_primary_key);
      if (tb_is_rdf_quad (tb_dfe->_.table.ot->ot_table))
	prec *= KM_TO_DEG;
      card = (M_PI * prec * prec) / tb->tb_geo_area;
      card = MIN (card, 1) * ct;
    }
  else if (geo && prec_literal)
    card = geo_estimate (tb, geo, gt, prec, key_one_slice (tb->tb_primary_key)) * key_n_partitions (tb->tb_primary_key);
  else
    card = 2;
  card = MAX (card, 2);
  if (tb_dfe->_.table.text_pred)
    tb_dfe->_.table.text_pred->dfe_arity = card;
  return  pred->dfe_arity = card;
}


void
smp_destroy (tb_sample_t * smp)
{
  /* empty.  If keeps samples from actual rows, free them here */
}


/* Text hits estimate */

dk_mutex_t *text_count_mtx;
id_hash_t * text_counts;


void
sqlo_tc_init ()
{
  text_count_mtx = mutex_allocate ();
  text_counts = id_hash_allocate (1001, sizeof (caddr_t), sizeof (tb_sample_t), strhash, strhashcmp);
}


caddr_t
lc_ret (local_cursor_t * lc)
{
  caddr_t r = NULL;
  if (!lc)
    return NULL;
  if (!lc->lc_proc_ret)
    return NULL;
  r = ((caddr_t*)lc->lc_proc_ret)[1];
  ((caddr_t*)lc->lc_proc_ret)[1] = NULL;
  return r;
}

int64
sqlo_eval_text_count (dbe_table_t * tb, caddr_t str, caddr_t ext_fti)
{
  char * tn, *tn_full;
  caddr_t ret = NULL;
  int rc;
  int entered = 0;
  int64 ct = -1;
  client_connection_t * cli = sqlc_client ();
  lock_trx_t * lt = cli->cli_trx;
  user_t * usr = cli->cli_user;
  int at_start = cli->cli_anytime_started;
  int rpc_timeout = cli->cli_rpc_timeout;
  query_t * proc;
  static query_t * call, *call2;
  static query_t * make_proc;
  local_cursor_t * lc = NULL;
  caddr_t err = NULL;
  char cn[500];
  if (cli->cli_clt)
    return -1; /* if in a cluster transaction branch, can't do partitioned ops */
  if (!lt->lt_threads)
    {
      entered = 1;
      rc = lt_enter (lt);
      if (LTE_OK != rc)
	{
	  return -1;
	}
    }
  cli->cli_anytime_started = 0;
  if (!make_proc)
    {
      call = sql_compile ("call (?)(?)", cli, &err, SQLC_DEFAULT);
      if (err)
	goto err;
      call2 = sql_compile ("call (?)(?,?)", cli, &err, SQLC_DEFAULT);
      if (err)
	goto err;
      make_proc = sql_compile ("DB.DBA.TEXT_EST_TEXT (?,?)", cli, &err, SQLC_DEFAULT);
      if (err)
	goto err;
    }
  if (tb_is_rdf_quad (tb))
    {
      tn = "RDF_OBJ";
      tn_full = "DB.DBA.RDF_OBJ";
    }
  else
    {
      tn = tb->tb_name_only;
      tn_full = tb->tb_name;
    }
  if (NULL != ext_fti)
    snprintf (cn, sizeof (cn), "%s.%s.TEXT_EST2_%s", tb->tb_qualifier, tb->tb_owner, tn);
  else
  snprintf (cn, sizeof (cn), "%s.%s.TEXT_EST_%s", tb->tb_qualifier, tb->tb_owner, tn);
  cli->cli_user = sec_name_to_user ("dba");
  cli->cli_rpc_timeout = 10000; /* cap on time for cluster ops, must not hang */
  proc = sch_proc_def (wi_inst.wi_schema, cn);
  if (!proc)
    {
      err = qr_rec_exec (make_proc, cli, &lc, CALLER_LOCAL, NULL, 2,
        ":0", tn_full, QRP_STR, ":1", (ptrlong)((NULL != ext_fti) ? 1 : 0), QRP_INT);
      if (err)
	goto err;
      ret = lc_ret (lc);
      if (DV_STRINGP (ret))
	ddl_std_proc (ret, DDL_STD_REENTRANT);
      else
	goto err;
      lc_free (lc);
    }
  if (NULL != ext_fti)
    err = qr_rec_exec (call2, cli, &lc, CALLER_LOCAL, NULL, 3,
		   ":0", cn, QRP_STR,
		   ":1", str, QRP_STR,
		   ":2", ext_fti, QRP_STR);
  else
  err = qr_rec_exec (call, cli, &lc, CALLER_LOCAL, NULL, 2,
		   ":0", cn, QRP_STR,
		   ":1", str, QRP_STR);
  if (err)
    goto err;
  ct = unbox (lc_ret (lc));
  lc_free (lc);
  cli->cli_user = usr;
  cli->cli_anytime_started = at_start;
  cli->cli_rpc_timeout = rpc_timeout;
  if (entered)
    {
      IN_TXN;
      lt_leave (lt);
      LEAVE_TXN;
    }
  return ct;
 err:
  cli->cli_user = usr;
  cli->cli_anytime_started = at_start;
  cli->cli_rpc_timeout = rpc_timeout;
  log_error ("compiler text card estimate got error %s %s, assuming unknown count", !err ? "" : ERR_STATE (err), !err ? "no message:" : ERR_MESSAGE (err));
  if (entered)
    {
      IN_TXN;
      lt_leave (lt);
      LEAVE_TXN;
    }
  return -1;
}


int64
sqlo_text_count (dbe_table_t * tb, caddr_t str, caddr_t ext_fti)
{
  int64 ct;
  char tn[1000];
  char * tns = &tn[0];
  tb_sample_t * place;
  if (2 == cl_run_local_only)
    return -1;
  snprintf (tn, sizeof (tn), "%s:%s", tb->tb_name, str);
  mutex_enter (text_count_mtx);
  place = (tb_sample_t *)id_hash_get (text_counts, (caddr_t)&tns);
  if (place)
    {
      mutex_leave (text_count_mtx);
      return place->smp_card;
    }
  mutex_leave (text_count_mtx);

  WITHOUT_TMP_POOL
    {
      int is_sem = sqlc_inside_sem;
      if (is_sem)
	semaphore_leave (parse_sem);
      ct = sqlo_eval_text_count (tb, str, ext_fti);
      if (is_sem)
	semaphore_enter (parse_sem);
    }
  END_WITHOUT_TMP_POOL;

  if (-1 == ct)
    return -1;
  if (!ct)
    ct = 1;
  mutex_enter (text_count_mtx);
  {
    tb_sample_t smp;
    caddr_t strc = box_dv_short_string (tn);
    memset (&smp, 0, sizeof (smp));
    smp.smp_card = ct;
    smp.smp_time = approx_msec_real_time ();
    id_hash_set (text_counts, (caddr_t)&strc, (caddr_t)&smp);
  }
  mutex_leave (text_count_mtx);
  return ct;
}

int
sqlo_text_estimate (df_elt_t * tb_dfe, df_elt_t ** text_pred, float * text_sel_ret )
{
  DO_SET (df_elt_t *, dfe, &tb_dfe->_.table.all_preds)
    {
      caddr_t str;
      if (DFE_TEXT_PRED == dfe->dfe_type)
	{
	  if (dfe->_.text.geo)
	    {
	      *text_pred = dfe;
	      *text_sel_ret = dfe->dfe_arity ? dfe->dfe_arity : sqlo_geo_count (tb_dfe, dfe);
	      return 1;
	    }
	  if ('c' == dfe->_.text.type && DV_STRINGP ((str = (caddr_t)dfe->_.text.args[1])))
	    {
              ST *ext_fti_st = NULL;
	      caddr_t ext_fti = NULL;
              int64 ct;
              unsigned inx, argcount = BOX_ELEMENTS(dfe->_.text.args);
              for (inx = 2; inx < argcount-1; inx++)
                {
                  ST *arg = dfe->_.text.args[inx];
                  if (!DV_STRINGP (arg))
                    continue;
                  if (0 != stricmp ((char *) arg, "EXT_FTI"))
                    continue;
                  ext_fti_st = dfe->_.text.args[inx+1];
                  if (DV_STRINGP (ext_fti_st))
                    ext_fti = (caddr_t)ext_fti_st;
                  break;
                }
	      ct = sqlo_text_count (tb_dfe->_.table.ot->ot_table, str, ext_fti);
	      *text_pred = dfe;
	      if (-1 == ct)
		return 0;
	      *text_sel_ret = (float)ct;
	      return 1;
	    }
	  else
	    {
	      *text_pred = dfe;
	      return 0;
	    }
	}
    }
  END_DO_SET();
  return 0;
}


void
sqlo_timeout_text_count ()
{
  int now = approx_msec_real_time (), inx;
  static int last_time;
  if (last_time && now - last_time < 60000)
    return;
  last_time = now;
  mutex_enter (text_count_mtx);
  for (;;)
    {
      caddr_t strings[100];
      int fill = 0;
      id_hash_iterator_t hit;
      caddr_t *  stringp;
      tb_sample_t * countp;
      id_hash_iterator (&hit, text_counts);
      while (hit_next (&hit, (caddr_t*)&stringp, (caddr_t*)&countp))
	{
	  if (now - countp->smp_time > 600000)
	    {
	      strings[fill++] = *stringp;
	      smp_destroy (countp);
	      if (fill >= 100)
		break;
	    }
	}
      if (!fill)
	break;
      for (inx = 0; inx < fill; inx++)
	{
	  id_hash_remove (text_counts, (caddr_t)&strings[inx]);
	  dk_free_box (strings[inx]);
	}
    }
  mutex_leave (text_count_mtx);
}


int
dfe_non_text_id_refd (df_elt_t * dfe, dbe_column_t * text_id_col)
{
  DO_SET (df_elt_t *, col, &dfe->_.table.out_cols)
    {
      if (col->_.col.col != text_id_col)
	return 1;
    }
  END_DO_SET()
  DO_SET (df_elt_t *, pred, &dfe->_.table.all_preds)
    {
      if (DFE_TEXT_PRED == pred->dfe_type)
	continue;
      if ((DFE_BOP_PRED == dfe->dfe_type || DFE_BOP == dfe->dfe_type)
	  && DFE_COLUMN == pred->_.bin.left->dfe_type && pred->_.bin.left->_.col.col == text_id_col)
	continue;
      return 1;
    }
  END_DO_SET()
    return 0;
}

int
sqlo_is_text_after_test (df_elt_t * tb_dfe, df_elt_t * text_pred)
{
  /* text or geo is an after test if there is 1. a unique non-text cond
   * the key is not the key with the text id col leading 3. the key is the text id key and there is a non-text eq on the first key part */
  dbe_key_t * id_key = tb_text_key (tb_dfe->_.table.ot->ot_table);
  if (tb_dfe->_.table.is_unique || tb_dfe->_.table.key != id_key)
    return 1;
  DO_SET (df_elt_t *, pred, &tb_dfe->_.table.col_preds)
    {
      if ((DFE_BOP_PRED == pred->dfe_type || DFE_BOP == pred->dfe_type)
	  && BOP_EQ == pred->_.bin.op && pred->_.bin.left->dfe_type == DFE_COLUMN && pred->_.bin.left->_.col.col == (dbe_column_t*)id_key->key_parts->data)
	return 1;
    }
  END_DO_SET();
  return 0;
}


void
dfe_text_cost (df_elt_t * dfe, float *u1, float * a1, int text_order_anyway)
{
  /* text predicate cost.  If by non-pk, this is always a check for whether text occurs.  If by unq this is a check for whether text occurs.
   * If by pk and no unq, this is driven by text node. */
  df_elt_t * text_pred = NULL;
  float total_cost = *u1, total_card = *a1;
  int text_known;
  dbe_table_t *ot_tbl = dfe->_.table.ot->ot_table;
  float text_selectivity, n_text_hits;
  float text_key_cost;
  int64 ot_tbl_size = dfe_scan_card (dfe);
  dbe_key_t * text_key = tb_text_key (ot_tbl);
  text_known = sqlo_text_estimate (dfe, &text_pred, &text_selectivity);
  if (text_pred)
    {
      if (text_known)
	text_selectivity = text_selectivity / (ot_tbl_size | 1);
      else
	text_selectivity = 0.001;
      n_text_hits = ot_tbl_size * text_selectivity;
      if (text_pred->_.text.geo)
	text_key_cost = dbe_key_unit_cost (text_key->key_geo_table->tb_primary_key);
      else
	text_key_cost = dbe_key_unit_cost (text_key->key_text_table->tb_primary_key);
      if (!text_order_anyway && sqlo_is_text_after_test (dfe, text_pred))
	{
	  /* the id is given, text match is an after test */
	  total_cost += 1.5 * text_key_cost * total_card;
	  total_card *= text_selectivity;
	}
      else
	{
	  /* the text index is driving.  Take into account card computed above for the rest */
	  float non_text_selectivity = total_card / ot_tbl_size;
	  float non_text_row_cost = total_cost / total_card;
	  total_card = n_text_hits;
	  total_cost = 0.5 * text_key_cost * n_text_hits;
	  if (dfe_non_text_id_refd (dfe, (dbe_column_t*)text_key->key_parts->data))
	    {
	      /* if need a join to the table, so not only text inx */
	      total_cost = n_text_hits * dbe_key_unit_cost (dfe->_.table.key);
	    }
	  total_card *= non_text_selectivity;
	  total_cost += non_text_row_cost;
	}
      if (1 != cl_run_local_only)
	total_cost += 10; /* a little latency, lookups are batched */
      *u1 = total_cost;
      *a1 = total_card;
    }
}


caddr_t
sqlo_iri_constant_name_1 (ST* tree)
{
  if (DV_STRINGP (tree))
    return (caddr_t)tree;
  if (ST_P (tree, CALL_STMT) && 1 <= BOX_ELEMENTS (tree->_.call.params)
      && DV_STRINGP (tree->_.call.name)
      && (0 == stricmp (tree->_.call.name, "__BFT") || 0 == stricmp (tree->_.call.name, "__box_flags_tweak")
	 || 0 == strnicmp (tree->_.call.name, "__I2ID", 6) || 0 == strnicmp (tree->_.call.name, "IRI_TO_ID", 9)))
    return (caddr_t) sqlo_iri_constant_name_1  (tree->_.call.params[0]);
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
      && (0 == strnicmp (tree->_.call.name, "__I2ID", 6) || 0 == strnicmp (tree->_.call.name, "IRI_TO_ID", 9))
      && DV_STRINGP ((name = sqlo_iri_constant_name_1 (tree->_.call.params[0]))))
    return name;
  return NULL;
}

caddr_t
sqlo_rdf_lit_const (ST * tree)
{
  if (DV_RDF == DV_TYPE_OF (tree))
    return (caddr_t)tree;
  if (ST_P (tree, CALL_STMT) && 1 == BOX_ELEMENTS (tree->_.call.params)
      && SINV_DV_STRINGP (tree->_.call.name) && 0 == strnicmp (tree->_.call.name, "__rdflit", 8))
    {
      caddr_t p1 = (caddr_t)tree->_.call.params[0];
      dtp_t dtp = DV_TYPE_OF (p1);
      if (DV_RDF == dtp)
	return p1;
    }
  return NULL;
}


caddr_t
sqlo_rdf_obj_const_value (ST * tree, caddr_t * val_ret, caddr_t *lang_ret)
{
  caddr_t lit = sqlo_rdf_lit_const (tree);
  if (lit)
    {
      if (val_ret)
	*val_ret = lit;
      return RDF_UNTYPED;
    }
  if (ST_P (tree, CALL_STMT) && 1 == BOX_ELEMENTS (tree->_.call.params)
      && DV_STRINGP (tree->_.call.name) && nc_strstr ((dtp_t*)tree->_.call.name, (dtp_t*)"OBJ_OF_SQLVAL")
      && DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree->_.call.params[0]))
    {
      dtp_t dtp = DV_TYPE_OF (tree->_.call.params[0]);
      if (DV_SYMBOL == dtp)
	return 0;
      if (val_ret)
	*val_ret = (caddr_t) tree->_.call.params[0];
      return RDF_UNTYPED;
    }
  if (ST_P (tree, CALL_STMT) && 3 == BOX_ELEMENTS (tree->_.call.params)
      && DV_STRINGP (tree->_.call.name) && nc_strstr ((dtp_t*)tree->_.call.name, (dtp_t*)"RDF_MAKE_OBJ_OF_TYPEDSQLVAL")
      && DV_STRINGP (tree->_.call.params[0])
      && DV_STRINGP (tree->_.call.params[2]))
    {
      dtp_t dtp = DV_TYPE_OF (tree->_.call.params[0]);
      if (DV_SYMBOL == dtp)
        return 0;
      if (val_ret)
        *val_ret = (caddr_t) tree->_.call.params[0];
      if (lang_ret)
        *lang_ret = (caddr_t) tree->_.call.params[2];
      return RDF_LANG_STRING;
    }
  if (ST_P (tree, CALL_STMT) && 3 == BOX_ELEMENTS (tree->_.call.params)
      && DV_STRINGP (tree->_.call.name) && nc_strstr ((dtp_t*)tree->_.call.name, (dtp_t*)"RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS")
      && DV_STRINGP (tree->_.call.params[0])
      && DV_STRINGP (tree->_.call.params[2]))
    {
      dtp_t dtp = DV_TYPE_OF (tree->_.call.params[0]);
      if (DV_SYMBOL == dtp)
        return 0;
      if (val_ret)
        *val_ret = (caddr_t) tree->_.call.params[0];
      if (lang_ret)
        *lang_ret = (caddr_t) tree->_.call.params[2];
      return RDF_LANG_STRING;
    }
  return 0;
}


int
rdf_obj_of_sqlval (caddr_t val, caddr_t * data_ret)
{
  dtp_t dtp = DV_TYPE_OF (val);
  if (DV_RDF == dtp)
    {
      *data_ret = box_copy (val);
      return 1;
    }
  if (IS_NUM_DTP (dtp))
    {
      *data_ret = box_copy (val);
      return 1;
    }
  if (DV_STRING == dtp)
    {
      caddr_t r;
      rdf_box_t * rb;
      rb = (rdf_box_t*)rbb_allocate ();
      rb->rb_lang = RDF_BOX_DEFAULT_LANG;
      rb->rb_type = RDF_BOX_DEFAULT_TYPE;
      rb->rb_box = box_copy_tree (val);
      OUTSIDE_PARSE_SEM;
      r = (caddr_t)key_find_rdf_obj (NULL, rb);
      END_OUTSIDE_PARSE_SEM;
      *data_ret =  r;
      return r != NULL;
    }
  return 0;
}


int
rdf_obj_of_typed_sqlval (caddr_t val, caddr_t vtype, caddr_t lang, caddr_t * data_ret)
{
  dtp_t dtp = DV_TYPE_OF (val);
  if (IS_NUM_DTP (dtp))
    {
      *data_ret = box_copy (val);
      return 1;
    }
  if (RDF_LANG_STRING != vtype)
    return 0;
  if (DV_STRING == dtp)
    {
      int lang_id = DV_DB_NULL == DV_TYPE_OF (lang) ? RDF_BOX_DEFAULT_LANG
	: key_rdf_lang_id (lang);
      caddr_t r;
      rdf_box_t * rb;
      if (!lang_id)
	return 0;
      rb = (rdf_box_t*)rbb_allocate ();
      rb->rb_lang = lang_id;
      rb->rb_type = RDF_BOX_DEFAULT_TYPE;
      rb->rb_box = box_copy_tree (val);
      OUTSIDE_PARSE_SEM;
      r = (caddr_t)key_find_rdf_obj (NULL, rb);
      END_OUTSIDE_PARSE_SEM;
      *data_ret =  r;
      return r != NULL;
    }
  return 0;
}



int
sample_search_param_cast (it_cursor_t * itc, search_spec_t * sp, caddr_t data)
{
  caddr_t err = NULL;
  dtp_t target_dtp = sp->sp_cl.cl_sqt.sqt_col_dtp;
  dtp_t dtp = DV_TYPE_OF (data);
  caddr_t name, vtype, lang;
  if ((name = sqlo_iri_constant_name ((ST *) data)))
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
	  caddr_t any_data = box_to_any (data, &err);
	  if (err)
	    {
	      dk_free_tree (err);
	      dk_free_box (data);
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
  if ((vtype = sqlo_rdf_obj_const_value ((ST *) data, &name, &lang)))
    {
      if (RDF_UNTYPED == vtype)
	{
	  if (!rdf_obj_of_sqlval (name, &data))
	    return KS_CAST_UNDEF;
	}
      else if (RDF_LANG_STRING == vtype)
	{
	  if (!rdf_obj_of_typed_sqlval (name, vtype, lang, &data))
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
	  caddr_t any_data = box_to_any (data, &err);
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
  if (dtp == target_dtp)
    {
      ITC_SEARCH_PARAM (itc, data);
      return KS_CAST_OK;
    }
  if (DV_ANY == target_dtp)
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
  if (IS_BLOB_DTP (target_dtp))
    return KS_CAST_NULL;
  switch (target_dtp)
    {
/* compare different number types.  If col more precise than arg, cast to col here, otherwise the cast is in itc_col_check */
    case DV_LONG_INT:
      if (!IS_NUM_DTP (dtp))
	break;
      ITC_SEARCH_PARAM (itc, data);	/* all are more precise, no cast down */
      return KS_CAST_OK;
    case DV_SINGLE_FLOAT:
      if ((DV_LONG_INT == dtp) || (!IS_NUM_DTP (dtp)))
	break;
      ITC_SEARCH_PARAM (itc, data);
      return KS_CAST_OK;
    case DV_DOUBLE_FLOAT:
      break;
    case DV_NUMERIC:
      if (DV_DOUBLE_FLOAT == dtp)
	{
	  ITC_SEARCH_PARAM (itc, data);
	  return KS_CAST_OK;
	}
      break;
    case DV_DATE:
      if (DV_DATETIME != dtp)
	break;
      ITC_SEARCH_PARAM (itc, data);
      return KS_CAST_OK;
    }
  if (DV_ARRAY_OF_POINTER == dtp || DV_SYMBOL == dtp)
    return KS_CAST_UNDEF;
  data = box_cast_to (NULL, data, dtp, target_dtp, sp->sp_cl.cl_sqt.sqt_precision, sp->sp_cl.cl_sqt.sqt_scale, &err);
  if (err)
    {
      dk_free_tree (err);
      return KS_CAST_UNDEF;
    }
  ITC_SEARCH_PARAM (itc, data);
  ITC_OWNS_PARAM (itc, data);
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
      sp->sp_min_op = in_list ? CMP_EQ : bop_to_dvc (lower->_.bin.op);
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
  /* do same for itc->itc_row_specs */
  for (sp = itc->itc_row_specs; sp; sp = sp->sp_next)
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

#define SMPL_QUEUED -2 /* return when queued in cluster clrg */

typedef struct sample_opt_s
{
  cl_req_group_t *	sop_clrg;
  rdf_inf_ctx_t *	sop_ric;
  caddr_t *		sop_sc_key_ret;
  dk_hash_t *		sop_cols;
  int			sop_n_sample_rows;
  char			sop_is_cl;
  char			sop_res_from_ric_cache;
  char			sop_use_sc_cache;
} sample_opt_t;

extern rdf_inf_ctx_t * empty_ric;

#define SMPL_QUEUE 1
#define SMPL_RESULT 2

int32 sqlo_sample_dep_cols = 1;
search_spec_t * dfe_to_spec (df_elt_t * lower, df_elt_t * upper, dbe_key_t * key);


float
itc_row_selectivity (it_cursor_t * itc, int64 inx_est)
{
  if (itc->itc_row_specs && itc->itc_st.n_rows_sampled)
    {
      if (itc->itc_st.n_row_spec_matches)
	
return (float)itc->itc_st.n_row_spec_matches / (float)itc->itc_st.n_rows_sampled;
      else
	return MAX (1e-3, 1.0 / itc->itc_st.n_rows_sampled);
    }
  return 1;
}


int64
sqlo_inx_sample_1 (df_elt_t * tb_dfe, dbe_key_t * key, df_elt_t ** lowers, df_elt_t ** uppers, int n_parts,
    sample_opt_t * sop, index_choice_t * ic)
{
  int64 c;
  float col_predicted = 1;
  sqlo_t * so = tb_dfe->dfe_sqlo;
  caddr_t sc_key = NULL;
  tb_sample_t * place;
  int64 res, tb_count;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  search_spec_t specs[10], row_specs[10];
  int v_fill = 0, inx;
  search_spec_t ** prev_sp;
  dk_set_t added_cols = NULL;
  float row_sel = 1;
  itc_clear_stats (itc);
  if (sop)
    sop->sop_res_from_ric_cache = 0;
  ITC_INIT (itc, key->key_fragments[0]->kf_it, NULL);
  dbe_key_count (key); /* this is the max of the sample so must be up to date */
  itc_clear_stats (itc);
  itc->itc_insert_key = key;
  if (!key->key_is_elastic)
    itc_from (itc, key, QI_NO_SLICE);
  else
    {
      client_connection_t * cli = sqlc_client ();
      if (CL_RUN_LOCAL == cl_run_local_only && cli->cli_keep_csl)
	itc_from (itc, key, cli->cli_csl->csl_id);
    }
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
      t_set_push (&added_cols, (void *) (*prev_sp)->sp_col);
      prev_sp = &specs[inx].sp_next;
    }
  if (sqlo_sample_dep_cols)
    {
      /* make row specs */
      memset (&row_specs, 0, sizeof (row_specs));
      prev_sp = &itc->itc_row_specs;
      inx = 0;
      ic->ic_inx_sample_cols = NULL;
      DO_SET (df_elt_t *, cp, &tb_dfe->_.table.col_preds)
	{
	  if (cp->dfe_type != DFE_TEXT_PRED && !sqlo_in_list (cp, NULL, NULL) &&
	      dk_set_member (key->key_parts, (void *) cp->_.bin.left->_.col.col) &&
	      !dk_set_member (added_cols, (void *) cp->_.bin.left->_.col.col))
	    {
	      if (key->key_bit_cl && key->key_bit_cl->cl_col_id == cp->_.bin.left->_.col.col->col_id)
		continue;
	      res = dfe_const_to_spec (cp, NULL, key, &row_specs[inx], itc, &v_fill);
	      if (KS_CAST_OK != res)
		continue;
	      *prev_sp = &row_specs[inx];
	      col_predicted *= cp->dfe_arity;
	      if (key->key_is_col)
		(*prev_sp)->sp_cl = *cl_list_find (key->key_row_var, cp->_.bin.left->_.col.col->col_id);
	      prev_sp = &row_specs[inx].sp_next;
	      /* push into a set inside ic so we know to exclude when calculate cost */
	      t_set_push (&ic->ic_inx_sample_cols, cp);
	      inx ++;
	    }
	}
      END_DO_SET ();
    }
  sc_key = itc_sample_cache_key (itc);
  if (sop && sop->sop_sc_key_ret)
    *sop->sop_sc_key_ret = box_copy_tree (sc_key);
  if (sop && sop->sop_cols)
    itc->itc_st.cols = sop->sop_cols;
  if (sop && sop->sop_ric)
    {
      tb_sample_t * place;
      mutex_enter (sop->sop_ric->ric_mtx);
      place = (tb_sample_t*) id_hash_get (sop->sop_ric->ric_samples, (caddr_t) &sc_key);
      if (place)
	{
	  c = place->smp_card;
	  if (sop->sop_cols && c)
	    goto sample_for_cols; /* if this is a non-zero cached sample and col samples are wanted then go get them but if 0 then return this */
	  ic->ic_inx_card = place->smp_inx_card;
	  mutex_leave (sop->sop_ric->ric_mtx);
	  dk_free_tree (sc_key);
	  itc_free (itc);
	  sop->sop_res_from_ric_cache = 1;
	  ic->ic_col_card_corr = col_predicted / (c / ic->ic_inx_card);
	  return c;
	}
    sample_for_cols: ;
      mutex_leave (sop->sop_ric->ric_mtx);
    }
  if (so->so_sc->sc_sample_cache)
    place = (tb_sample_t*) id_hash_get (so->so_sc->sc_sample_cache, (caddr_t) &sc_key);
  else
    {
      so->so_sc->sc_sample_cache = id_hash_allocate (61, sizeof (caddr_t), sizeof (tb_sample_t), treehash, treehashcmp);
      place = NULL;
    }
  if (place)
    {
      dk_free_tree (sc_key);
      itc_free (itc);
      c = place->smp_card;
      ic->ic_inx_card = place->smp_inx_card;
      ic->ic_col_card_corr = col_predicted / (c / ic->ic_inx_card);
      return c;
    }
  if (sop)
    itc->itc_st.cols = sop->sop_cols;
    {
    res = itc_sample (itc);
      row_sel = itc_row_selectivity (itc, res);
    }
  if (sop)
    sop->sop_n_sample_rows += itc->itc_st.n_sample_rows;
  itc->itc_st.cols = NULL;
  itc_free (itc);
  tb_count = dbe_key_count (key->key_table->tb_primary_key);
  res = MIN (tb_count, res);
  if (!sop || sop->sop_ric || sop->sop_use_sc_cache)
    {
      tb_sample_t smp;
      memset (&smp, 0, sizeof (tb_sample_t));
      smp.smp_card = res * row_sel;
      smp.smp_inx_card = res;
      if (so->so_sc->sc_sample_cache)
	id_hash_set (so->so_sc->sc_sample_cache, (caddr_t)&sc_key, (caddr_t)&smp);
    }
  c = res * row_sel;
  ic->ic_inx_card = res;
  ic->ic_col_card_corr = col_predicted / (c / ic->ic_inx_card);
  return c;
}

int32 ric_samples_sz = 10000;
int32 ric_rnd_seed;

void
ric_set_sample (rdf_inf_ctx_t * ctx, caddr_t sc_key, int64 est, float inx_card)
{
  tb_sample_t smp;
  memset (&smp, 0, sizeof (smp));
  smp.smp_card = est;
  smp.smp_inx_card = inx_card;
  smp.smp_time = approx_msec_real_time ();
  mutex_enter (ctx->ric_mtx);
  if (ctx->ric_samples->ht_count > ric_samples_sz)
    {
      caddr_t key = NULL;
      tb_sample_t old_smp;
      int32 rnd  = sqlbif_rnd (&ric_rnd_seed);
      if (id_hash_remove_rnd (ctx->ric_samples, rnd, (caddr_t)&key, (caddr_t)&old_smp))
	{
	  dk_free_tree (key);
	}
    }
  id_hash_set (ctx->ric_samples, (caddr_t)&sc_key, (caddr_t)&smp);
  mutex_leave (ctx->ric_mtx);
}


extern caddr_t rdfs_type;


int64
sqlo_inx_inf_sample (df_elt_t * tb_dfe, dbe_key_t * key, df_elt_t ** lowers, df_elt_t ** uppers, int n_parts, rdf_inf_ctx_t * ctx, rdf_sub_t * sub,
		     caddr_t * variable, index_choice_t * ic, dk_hash_t * cols)
{
  sample_opt_t sop;
  int is_first = 1;
  caddr_t org_o = *variable;
  int64 s, est = 0;
  int any_est = 0;
ri_iterator_t * rit = ri_iterator (sub, ic->ic_inf_type, 1);
  rdf_sub_t * sub_iri;
  caddr_t sc_key = NULL;
  int n_subs = 0;
  memset (&sop, 0, sizeof (sop));
  sop.sop_cols = cols;
  sop.sop_is_cl = (!cl_run_local_only && key->key_partition && clm_replicated != key->key_partition->kpd_map) ? SMPL_QUEUE : 0;
  sop.sop_ric = ctx;
  sop.sop_sc_key_ret = &sc_key;
  while ((sub_iri = rit_next (rit)))
    {
      *variable = sub_iri->rs_iri;
      s = sqlo_inx_sample_1 (tb_dfe, key, lowers, uppers, n_parts, &sop, ic);
      if (s >= 0)
	{
	  est += s;
	  any_est = 1;
	  if (sop.sop_res_from_ric_cache)
	    {
	      rit->rit_next_sibling = 1;
	      n_subs += sub_iri->rs_n_subs - 1;
	    }
	}
      if (is_first)
	{
	  if (any_est && sop.sop_res_from_ric_cache)
	    {
	      dk_free_box ((caddr_t)rit);
	      dk_free_tree (sc_key);
	      *variable = org_o;
	      ic->ic_n_lookups = sub->rs_n_subs;
	      return s;
	    }
	  sop.sop_sc_key_ret = NULL;
	  is_first = 0;
	}
      n_subs++;
    }
  if (sop.sop_is_cl)
    {
      sop.sop_is_cl = SMPL_RESULT;
      s = sqlo_inx_sample_1 (tb_dfe, key, lowers, uppers, n_parts, &sop, ic);
      if (s >= 0)
	{
	  est += s;
	  any_est = 1;
	}
    }
  if (sc_key)
    {
      if (any_est)
	{
	  ric_set_sample (sop.sop_ric, sc_key, est, ic->ic_inx_card);
	}
      else
	dk_free_tree (sc_key);
      sub->rs_n_subs = n_subs;
    }
  dk_free_box ((caddr_t)rit);
  *variable = org_o;
  ic->ic_n_lookups = sub->rs_n_subs;
  return any_est ? est : -1;
}


int enable_p_stat = 2;
#define RDF_NO_P_STAT 0
#define RDF_P_STAT_NEW 3
#define RDF_P_STAT_EXISTS 2


int
sqlo_is_rdf_p (dbe_key_t * key, caddr_t p_const, float * prev_est)
{
  iri_id_t p;
  if (enable_p_stat)
    {
      float * place;
      if (!key->key_p_stat)
	return RDF_P_STAT_NEW;
      if (DV_IRI_ID != DV_TYPE_OF (p_const))
	return RDF_NO_P_STAT;
      p = unbox_iri_id (p_const);
      place = (float*)id_hash_get (key->key_p_stat, (caddr_t)&p);
      if (!place)
	return RDF_P_STAT_NEW;
      *prev_est = place[0];
      return RDF_P_STAT_EXISTS;
    }
  return RDF_NO_P_STAT;
}


int
sqlo_record_rdf_p (sample_opt_t * sop, dbe_key_t * key, caddr_t p_const, int64 est, float prev_est, int * is_rdf_p)
{
  /* store the stats of the sog fpr the given p. */
  float distincts[4];
  iri_id_t p = unbox_iri_id (p_const);
  int fill = 1, completed = 0;
  col_stat_t * cs;
  if (RDF_P_STAT_EXISTS == *is_rdf_p)
    {
      float ratio = prev_est / ((float)est + 0.001);
      if (est < 3 && prev_est < 3)
	return 0;
      if (ratio > 0.9 && ratio < 1.1)
	return 0;
      *is_rdf_p = RDF_P_STAT_NEW;
      return 1;
    }
  if (0 == est)
    est = 1;
  if (0 == sop->sop_n_sample_rows)
    sop->sop_n_sample_rows = 1;
  mutex_enter (alt_ts_mtx); /*any mtx that is never enterd, not worth one of its own */
  if (!key->key_p_stat)
    {
      key->key_p_stat = id_hash_allocate (201, sizeof (iri_id_t), 4 * sizeof (float), boxint_hash, boxint_hashcmp);
      id_hash_set_rehash_pct (key->key_p_stat, 200);
    }
  distincts[0] = est;
  DO_SET (dbe_column_t *, col, &key->key_parts->next)
    {
      cs = gethash ((void*)col, sop->sop_cols);
      if (!cs)
	goto end;
      distincts[fill++] = (float)cs->cs_distinct->ht_count * (float)est / sop->sop_n_sample_rows;
      DO_IDHASH (caddr_t, k, caddr_t, ign,  cs->cs_distinct)
	dk_free_box (k);
      END_DO_IDHASH;
      id_hash_free (cs->cs_distinct);
      dk_free ((caddr_t)cs, sizeof (col_stat_t));
      if (fill >= 4)
	break;
    }
  END_DO_SET();
  /* free stats on P */
  cs = gethash (key->key_parts->data, sop->sop_cols);
  if (!cs)
    goto end;
  DO_IDHASH (caddr_t, k, caddr_t, ign,  cs->cs_distinct)
      dk_free_box (k);
  END_DO_IDHASH;
  id_hash_free (cs->cs_distinct);
  dk_free ((caddr_t)cs, sizeof (col_stat_t));
  completed = 1;
 end:
  hash_table_free (sop->sop_cols);
  sop->sop_cols = NULL;
  if (completed)
    id_hash_set (key->key_p_stat, (caddr_t)&p, (caddr_t)&distincts);
  mutex_leave (alt_ts_mtx);
  return 0;
}



int
rs_sub_count (rdf_sub_t * rs)
{
  ri_iterator_t * rit;
  rdf_sub_t * sub;
  int n_subs = 0;
  if (rs->rs_n_subs)
    return rs->rs_n_subs;
  rit = ri_iterator (rs, RI_SUBCLASS, 1);
  while ((sub = rit_next (rit)))
    {
      if (sub->rs_n_subs)
	{
	  rit->rit_next_sibling = 1;
	  n_subs += sub->rs_n_subs;
	}
      else
	n_subs++;
    }
  rs->rs_n_subs = n_subs;
  return n_subs;
}


void
sqlo_non_leading_const_inf_cost (df_elt_t * tb_dfe, df_elt_t ** lowers, df_elt_t ** uppers, index_choice_t * ic)
{
  /* take a col eq to const iterated over subs.  Se how many subs */
    rdf_inf_ctx_t * ctx = ic->ic_ric;
  if (ctx && tb_is_rdf_quad (tb_dfe->_.table.ot->ot_table))
    {
      rdf_sub_t * sub;
      caddr_t p_const = NULL, o_const = NULL;
      int inx;
      df_elt_t * o_dfe = NULL, *p_dfe = NULL, * o_dfe_2 = NULL, * p_dfe_2 = NULL;
      ST * org_o = NULL, * org_p = NULL;
      for (inx = 0; inx < ic->ic_leading_constants; inx++)
	{
	  dbe_column_t * left_col;
	  if (!lowers[inx])
	    break;
	  left_col = cp_left_col (lowers[inx]);
	  switch (left_col->col_name[0])
	    {
	    case 'P': p_dfe = lowers[inx]->_.bin.right; org_p = p_dfe->dfe_tree; break;
	    case 'O': o_dfe = lowers[inx]->_.bin.right; org_o = o_dfe->dfe_tree; break;
	    }
	}
      if (o_dfe && p_dfe)
	return; /* both p and o inf were covered in the inx sample with leading constants */
      DO_SET (df_elt_t *, pred, &tb_dfe->_.table.col_preds)
	{
	  dbe_column_t * left_col = cp_left_col (pred);
	  switch (left_col->col_name[0])
	    {
	    case 'P':
	      if (!p_dfe)
		{
		  p_dfe_2 = pred->_.bin.right;
		  org_p = p_dfe_2->dfe_tree;
		}
	      break;
	    case 'O':
	      if (!o_dfe)
		{
		  o_dfe_2 = pred->_.bin.right;
		  org_o = o_dfe_2->dfe_tree;
		}
	      break;
	    }
	}
      END_DO_SET();
      /* o_dfe_2 and p_dfe_2 are the inferred p and o that were not accounted for by the sample with leading constants */
      p_const = dfe_iri_const (p_dfe_2);
      o_const = dfe_iri_const (o_dfe_2);
      if (box_equal (rdfs_type, p_const)
	  && o_const
	  && (sub = ric_iri_to_sub (ctx, o_const, RI_SUBCLASS, 0))
	  && sub->rs_sub)
	{
	  /* the p is rdfstype and o given.  See about counts of subcs */
	  ic->ic_inf_type = RI_SUBCLASS;
	  ic->ic_inf_dfe = o_dfe_2;
	  ic->ic_n_lookups = rs_sub_count (sub);
	  dk_free_box (p_const);
	  dk_free_box (o_const);
	  return;
	}
      if (p_const && (sub = ric_iri_to_sub (ctx, p_const, RI_SUBPROPERTY, 0))
	  && sub->rs_sub)
	{
	  /* the p is given and has subproperties */
	  ic->ic_inf_dfe = p_dfe_2;
	  ic->ic_inf_type = RI_SUBPROPERTY;
	  ic->ic_n_lookups = rs_sub_count (sub);
	  dk_free_box (p_const);
	  dk_free_box (o_const);
	  return;
	}
      dk_free_box (p_const);
      dk_free_box (o_const);
    }
  return;
}

void
sqlo_try_inf_filter (df_elt_t * tb_dfe, index_choice_t * ic)
{
  /* there is eq on a col with inf.  Try the eq on the inf col as an after test */
  df_elt_t * tst_dfe = NULL;
  rdf_inf_ctx_t * ric = ic->ic_ric;
  dk_set_t no_inf_cp = NULL;
  dk_set_t inf_after_test = NULL;
  dk_set_t old_cp = tb_dfe->_.table.col_preds;
  sqlo_t * so = tb_dfe->dfe_sqlo;
  index_choice_t filter_ic;
  if (IC_AS_IS == ic->ic_op || ic->ic_n_lookups < 2)
    return;
  DO_SET (df_elt_t *, cp, &tb_dfe->_.table.col_preds)
    {
      if (DFE_BOP_PRED == cp->dfe_type && ic->ic_inf_dfe == cp->_.bin.right)
	{
	  ST * tst = (ST*)t_list (4, BOP_EQ, (caddr_t)(ptrlong)1, t_list (3, CALL_STMT, t_sqlp_box_id_upcase ("rdf_is_sub"),
									  t_list (4, ric->ric_name, cp->_.bin.left->dfe_tree, ic->ic_inf_dfe->dfe_tree, (caddr_t)(ptrlong)ic->ic_inf_type)), NULL);
	  tst_dfe = sqlo_df (so, tst);
	  t_set_push (&inf_after_test, (void*)tst_dfe);
	}
      else
	t_set_push (&no_inf_cp, (void*)cp);
    }
  END_DO_SET();
  memset (&filter_ic, 0, sizeof (filter_ic));
  filter_ic.ic_op = IC_AS_IS;
  tb_dfe->_.table.col_preds = no_inf_cp;
  tb_dfe->dfe_unit = tb_dfe->dfe_arity = 0;
  dfe_table_cost_ic_1 (tb_dfe, &filter_ic, 0);
  tb_dfe->_.table.col_preds = old_cp;
  if (filter_ic.ic_unit < ic->ic_unit * ic->ic_n_lookups)
    {
      ic->ic_n_lookups = 1;
      ic->ic_unit = filter_ic.ic_unit;
      ic->ic_altered_col_pred = no_inf_cp;
      ic->ic_after_test = inf_after_test;
      ic->ic_after_test_arity = tst_dfe->dfe_arity = ic->ic_arity / filter_ic.ic_arity;
      tst_dfe->dfe_unit = COL_PRED_COST;
      tb_dfe->dfe_arity = ic->ic_arity; /* the filter is taken into account here */
      return;
    }
  tb_dfe->dfe_unit = ic->ic_unit;
  tb_dfe->dfe_arity = ic->ic_arity;
  tb_dfe->_.table.is_arity_sure = ic->ic_leading_constants;
}


int64
dfe_int_const (df_elt_t * dfe)
{
  if (DFE_CONST != dfe->dfe_type)
    return 0;
  return unbox_iri_int64 ((caddr_t)dfe->dfe_tree);
}

int64
sqlo_inx_sample (df_elt_t * tb_dfe, dbe_key_t * key, df_elt_t ** lowers, df_elt_t ** uppers, int n_parts, index_choice_t * ic)
{
  rdf_inf_ctx_t * ctx = ic->ic_ric;
  ic->ic_inx_card = 0;
  if (tb_is_rdf_quad (tb_dfe->_.table.ot->ot_table))
    {
      rdf_sub_t * sub;
      caddr_t p_const = NULL, o_const = NULL;
      int inx;
      df_elt_t * o_dfe = NULL, *p_dfe = NULL;
      ST * org_o = NULL, * org_p = NULL;
      float prev_est;
      int is_p = 1 == n_parts && 'P' == ((dbe_column_t*)key->key_parts->data)->col_name[0];
	  sample_opt_t sop;
      int64 c;
	  memset (&sop, 0, sizeof (sop));
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
      if (is_p)
	is_p = sqlo_is_rdf_p (key, p_const, &prev_est);

    redo:
      if (RDF_P_STAT_NEW == is_p && !sop.sop_cols)
	sop.sop_cols = hash_table_allocate (11);
      if (!ctx)
	{
	  caddr_t sc_key = NULL;
	  sop.sop_ric = empty_ric;
	  sop.sop_sc_key_ret = &sc_key;
	  c = sqlo_inx_sample_1 (tb_dfe, key, lowers, uppers, n_parts, &sop, ic);
	  if (!sop.sop_res_from_ric_cache && c >= 0)
	    {
	      ric_set_sample (empty_ric, sc_key, c, ic->ic_inx_card);
	    }
	  else
	    dk_free_tree (sc_key);
	}
      else
	    {
      if (box_equal (rdfs_type, p_const)
	  && (o_const = dfe_iri_const (o_dfe))
	  && (sub = ric_iri_to_sub (ctx, o_const, RI_SUBCLASS, 0))
	  && sub->rs_sub)
	{
	  /* the p is rdfstype and o given.  See about counts of subcs */
	  ic->ic_inf_type = RI_SUBCLASS;
	  ic->ic_inf_dfe = o_dfe;
	      c = sqlo_inx_inf_sample (tb_dfe, key, lowers, uppers, n_parts, ctx, sub, (caddr_t*)&o_dfe->dfe_tree, ic, sop.sop_cols);
	}
	  else if (p_const && (sub = ric_iri_to_sub (ctx, p_const, RI_SUBPROPERTY, 0))
	  && sub->rs_sub)
	{
	  /* the p is given and has subproperties */
	  ic->ic_inf_dfe = p_dfe;
	  ic->ic_inf_type = RI_SUBPROPERTY;
	      c =  sqlo_inx_inf_sample (tb_dfe, key, lowers, uppers, n_parts, ctx, sub, (caddr_t*)&p_dfe->dfe_tree, ic, sop.sop_cols);
	    }
	  else
	    {
	      ic->ic_n_lookups = 1;
	      c = sqlo_inx_sample_1 (tb_dfe, key, lowers, uppers, n_parts, NULL, ic);
	    }
	}
      dk_free_box (o_const);
      if (is_p && sqlo_record_rdf_p (&sop, key, p_const, c, prev_est, &is_p))
	goto redo;
      dk_free_box (p_const);
      return c;
    }
  else
    {
      int64 c;
      caddr_t sc_key = NULL;
      sample_opt_t sop;
      memzero (&sop, sizeof (sop));
      sop.sop_ric = empty_ric;
      sop.sop_sc_key_ret = &sc_key;
      c = sqlo_inx_sample_1 (tb_dfe, key, lowers, uppers, n_parts, &sop, ic);
      if (!sop.sop_res_from_ric_cache && c >= 0 && sop.sop_ric)
	{
	  ric_set_sample (empty_ric, sc_key, c, ic->ic_inx_card);
	}
      else
	dk_free_tree (sc_key);
      return c;
}
}


int enable_range_card = 1;

int
dfe_range_card (df_elt_t * tb_dfe, df_elt_t * lower, df_elt_t * upper, float * card)
{
  dbe_table_t * tb = tb_dfe->_.table.ot->ot_table;
  if (!enable_range_card)
    return 0;
  DO_SET (dbe_key_t *, key, &tb->tb_keys)
    {
      if (key->key_distinct)
	continue;
      if (DFE_COLUMN == lower->_.bin.left->dfe_type && lower->_.bin.left->_.col.col == (dbe_column_t*)key->key_parts->data)
	{
	  index_choice_t ic;
	  int64 s;
	  float total = dbe_key_count (key);
	  memzero (&ic, sizeof (ic));
	  s = sqlo_inx_sample (tb_dfe, key, &lower, &upper, 1, &ic);
	  if (s < 0)
	    return 0;
	  *card = MIN (1, s / total);
	  return 1;
	}
    }
  END_DO_SET();
  return 0;
}


float 
sqlo_hash_mem_cost (float hash_card)
{
  return lin_int (&li_hash_mem_cost, hash_card);
}



float
dfe_hash_fill_unit (df_elt_t * dfe, float arity)
{
  return HASH_ROW_INS_COST + HASH_COUNT_FACTOR (arity);
}


extern int enable_p_stat;

caddr_t
sqlo_const_iri (sqlo_t * so, df_elt_t * dfe)
{
  caddr_t name;
  if ((name = sqlo_iri_constant_name (dfe->dfe_tree)))
    {
      return key_name_to_iri_id (NULL, name, 0);
    }
  return NULL;
}


void
sqlo_rdf_col_card (sqlo_t * so, df_elt_t * tb_dfe, df_elt_t * dfe)
{
  int nth;
  caddr_t p = NULL;
  dbe_key_t * key = tb_dfe->_.table.key;
  float * place;
  if (!key || !key->key_p_stat)
    return;
  DO_SET (df_elt_t *, pred, &tb_dfe->_.table.col_preds)
    {
      dbe_column_t * left_col = DFE_BOP_PRED == pred->dfe_type && BOP_EQ == pred->_.bin.op
	? (pred->_.bin.left->dfe_type == DFE_COLUMN ? pred->_.bin.left->_.col.col : NULL) : NULL;
      if (!left_col || 'P'!= left_col->col_name[0])
	continue;
      p = sqlo_const_iri (so, pred->_.bin.right);
      break;
    }
  END_DO_SET();
  if (!p || DV_IRI_ID != DV_TYPE_OF (p))
    return;
  mutex_enter (alt_ts_mtx);
  place = (float*)id_hash_get (key->key_p_stat, (caddr_t)&((iri_id_t*)p)[0]);
  dk_free_box (p);
  if (!place)
    {
      mutex_leave (alt_ts_mtx);
      return;
    }
  nth = 1;
  DO_SET (dbe_column_t *, part, &key->key_parts->next)
    {
      if (part == dfe->_.col.col)
	{
	  dfe->_.col.card = place[nth];
	  break;
	}
      nth++;
    }
  END_DO_SET();
  mutex_leave (alt_ts_mtx);
}


float
dfe_hash_fill_cond_card (df_elt_t * tb_dfe)
{
  /* if a join on hash build side and this restricts card, how much?  This is the card of the build dt divided by of the build side dfe with all non-join conditions*/
  if (DFE_DT == tb_dfe->_.table.hash_filler->dfe_type)
    {
      index_choice_t ic;
      df_elt_t tb_dfe_c = *tb_dfe;
      tb_dfe_c.dfe_unit = 0;
      tb_dfe_c._.table.col_preds = NULL;
      tb_dfe_c._.table.all_preds = NULL;
      tb_dfe_c._.table.hash_role = 0;
      tb_dfe_c._.table.hash_filler = NULL;
      tb_dfe_c._.table.join_test = NULL;
      DO_SET (df_elt_t *, pred, &tb_dfe->_.table.col_preds)
	{
	  if (pred_const_rhs (pred))
	    t_set_push (&tb_dfe_c._.table.col_preds, (void*)pred);
	}
      END_DO_SET();
      memzero (&ic, sizeof (ic));
      dfe_table_cost_ic (&tb_dfe_c, &ic, 0);
      return tb_dfe->_.table.hash_filler->dfe_arity / ic.ic_arity;
    }
  else
    return 1;
}


int64
dfe_col_n_distinct (df_elt_t * dfe)
{
  if (dfe->dfe_tables)
    {
      op_table_t * ot = dfe->dfe_tables->data;
      if (dfe_is_quad (ot->ot_dfe))
	{
	  /* fill in code to get constant p and card for this */
	}
    }
  return dfe->_.col.col->col_n_distinct;
}

static dbe_column_t *
key_find_col (dbe_key_t * key, char * name)
{
  DO_SET (dbe_column_t *, col, &key->key_parts)
    if (!CASEMODESTRCMP (col->col_name, name))
      return col;
  END_DO_SET();
  return NULL;
}



#define RQ_UNBOUND 0
#define RQ_CONST_EQ 1
#define RQ_CONST_RANGE 2
#define RQ_BOUND_EQ 3
#define RQ_BOUND_RANGE 4

typedef struct rq_pred_s
{
  df_elt_t *	rqp_lower;
  df_elt_t *	rqp_upper;
  int	rqp_op;
} rq_pred_t;

typedef struct rq_cols_s 
{
  dbe_table_t *rq_table;
  dbe_column_t * rq_p_col;
  dbe_column_t * rq_s_col;
  dbe_column_t * rq_o_col;
  dbe_column_t * rq_g_col;
  rq_pred_t	rq_p;
  rq_pred_t	rq_s;
  rq_pred_t	rq_o;
  rq_pred_t	rq_g;
} rq_cols_t;


void
rq_cols_init (df_elt_t * dfe, rq_cols_t * rq)
{
  dbe_key_t * key = dfe->_.table.key;
  rq_pred_t * rqp;
  rq->rq_table = dfe->_.table.ot->ot_table;
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {

      switch (col->col_name[0])
	{
	case 'P': case 'p':
	  rq->rq_p_col = col;
	  rqp = &rq->rq_p;
	  break;
	case 'S': case 's':
	  rq->rq_s_col = col;
	  rqp = &rq->rq_s;
	  break;
	case 'O': case 'o':
	  rq->rq_o_col = col;
	  rqp = &rq->rq_o;
	  break;
	case 'G': case 'g':
	  rq->rq_g_col = col;
	  rqp = &rq->rq_g;
	  break;
	}
      rqp->rqp_lower = sqlo_key_part_best (col, dfe->_.table.col_preds, 0);
      rqp->rqp_upper = sqlo_key_part_best (col, dfe->_.table.col_preds, 1);
      if (rqp->rqp_lower && PRED_IS_EQ (rqp->rqp_lower))
	rqp->rqp_op = pred_const_rhs  (rqp->rqp_lower) ? RQ_CONST_EQ : RQ_BOUND_EQ;
      else if (rqp->rqp_lower || rqp->rqp_upper)
	{
	  if ((!rqp->rqp_lower || pred_const_rhs (rqp->rqp_lower)) && (!rqp->rqp_upper || pred_const_rhs (rqp->rqp_upper)))
	    rqp->rqp_op = RQ_CONST_RANGE;
	  else 
	    rqp->rqp_op = RQ_BOUND_RANGE;
	}
      else 
	rqp->rqp_op = RQ_UNBOUND;
    }
  END_DO_SET();
}




rq_pred_t *
rq_rqp (rq_cols_t * rq, dbe_column_t * col)
{
  switch (col->col_name[0])
    {
    case 'P':  case 'p': return &rq->rq_p;
    case 'S':  case 's': return &rq->rq_s;
    case 'O':  case 'o': return &rq->rq_o;
    case 'G':  case 'g': return &rq->rq_g;
    }
  return NULL;  
}


dbe_key_t *
rq_best_key (df_elt_t * dfe, rq_cols_t * rq)
{
  float best_score = 0;
  float score;
  dbe_key_t * best = NULL;
  int nth_key;
  if (RQ_CONST_EQ == rq->rq_p.rqp_op && RQ_UNBOUND == rq->rq_s.rqp_op && RQ_UNBOUND == rq->rq_o.rqp_op)
    return dfe->_.table.key;
  DO_SET (dbe_key_t *, key, &rq->rq_table->tb_keys)
    {
      score = 0;
      if (key->key_distinct)
	continue;
      nth_key = 1;
      DO_SET (dbe_column_t *, col, &key->key_parts)
	{
	  rq_pred_t * rqp = rq_rqp (rq, col);
	  if (&rq->rq_s == rqp)
	    score += 1.0 / nth_key;
	  if (!rqp)
	    continue;
	switch (rqp->rqp_op)
	  {
	  case RQ_CONST_EQ: score += 3; break;
	  case RQ_CONST_RANGE: score += 1; goto key_done;
	  default: goto key_done;
	  }
	}
      END_DO_SET();
    key_done:
      if (score > best_score)
	{

	  best = key;
	  best_score = score;
	}
	}
  END_DO_SET();
  return best;
}


float
rq_sample (df_elt_t * dfe, rq_cols_t * rq, index_choice_t * ic)
{
  df_elt_t * lower[4];
  df_elt_t * upper[4];
  dbe_key_t * save_key = dfe->_.table.key;
  dbe_key_t * best_key = rq_best_key (dfe, rq);
  int fill = 0;
  int64 res;
  DO_SET (dbe_column_t *, col, &best_key->key_parts)
    {
      rq_pred_t * rqp = rq_rqp (rq, col);
      if (RQ_CONST_EQ == rqp->rqp_op || RQ_CONST_RANGE == rqp->rqp_op)
	{
	  lower[fill] = rqp->rqp_lower;
	  upper[fill] = rqp->rqp_upper;
	  fill++;
	}
      else
	break;
    }
  END_DO_SET();
  dfe->_.table.key = best_key;
  res = sqlo_inx_sample (dfe, best_key, lower, upper, fill, ic);
  dfe->_.table.key = save_key;
  return MAX (0.3, res);
}


dbe_key_t *
tb_px_key (dbe_table_t * tb, dbe_column_t * col)
{
  int  best_pos = 1111;
  dbe_key_t * best_key = NULL;
  DO_SET (dbe_key_t *, key, &tb->tb_keys)
    {
      int nth;
      if (key->key_distinct)
	continue;
      nth = dk_set_position (key->key_parts, (void*)col);
      if (nth < best_pos)
	{
	  best_pos = nth;
	  best_key = key;
	}
    }
  END_DO_SET();
  return best_key;
}

#define SO_CURRENT 0
#define SO_S 1
#define SO_O 2

int64 
dfe_p_card (df_elt_t * dfe, rq_cols_t * rq, float * p_stat, index_choice_t * ic, int so_ord)
{
  dbe_key_t * save_key;
  caddr_t p;
  int64 sample;
  float * place;
  int checked = 0;
  dbe_key_t * key = dfe->_.table.key;
  if (RQ_CONST_EQ != rq->rq_p.rqp_op)
    return -1;
  if (SO_S == so_ord)
    key = tb_px_key (dfe->_.table.ot->ot_table, rq->rq_s_col);
  else if (SO_O == so_ord)
    key = tb_px_key (dfe->_.table.ot->ot_table, rq->rq_o_col);
  if (!key)
    key = dfe->_.table.key;
 p_stat_again:
  p = dfe_iri_const (rq->rq_p.rqp_lower->_.bin.right);
  if (!p)
    return -1;
  mutex_enter (alt_ts_mtx);
  place = (float*)id_hash_get (key->key_p_stat, (caddr_t)&((iri_id_t*)p)[0]);
  if (place)
    memcpy_16 (p_stat, place, 4 * sizeof (float));
  mutex_leave (alt_ts_mtx);
  dk_free_box (p);
  if (!place)
    {
      rq_cols_t rq2 = *rq;
      rq2.rq_s.rqp_op = RQ_UNBOUND;
      rq2.rq_o.rqp_op = RQ_UNBOUND;
      rq2.rq_g.rqp_op = RQ_UNBOUND;
      save_key = dfe->_.table.key;
      dfe->_.table.key = key;
      sample = rq_sample (dfe, &rq2, ic);
      dfe->_.table.key = save_key;
      if (sample <= 0)
	return -1;
      if (checked)
	{
	  p_stat[0] = p_stat[1] = p_stat[2] = p_stat[3] = 1.0;
	  return 1;
	}
      checked = 1;
      goto p_stat_again;
    }
  return p_stat[0];
}

int
sqlo_use_p_stat_2 (df_elt_t * dfe, float *inx_card, float * col_card, index_choice_t * ic, int64 * sample_ret)
{
  int is_unq = ic->ic_is_unique;
  rq_pred_t * col2, *col3;
  df_elt_t * g_dfe;
  int64 p_card, rc;
  dbe_key_t * key = dfe->_.table.key;
  rq_cols_t rq;
  float p_stat[4];
  if (!key->key_p_stat  || ic->ic_ric)
    return 0;
  memzero (&rq, sizeof (rq));
  rq_cols_init (dfe, &rq);
  if (RQ_CONST_EQ != rq.rq_p.rqp_op)
    return 0;
  p_stat[0] = p_stat[1] = p_stat[2] = p_stat[3] = 10;
  p_card = dfe_p_card (dfe, &rq, p_stat, ic, SO_CURRENT);
  *sample_ret = p_card;
  if (-1 == p_card)
    p_card = 10; /* suppose 10 if no estimate */
  if (RQ_CONST_EQ == rq.rq_g.rqp_op && RQ_UNBOUND == rq.rq_s.rqp_op && RQ_UNBOUND == rq.rq_o.rqp_op)
    {
      /* there is only p and g, no s or o */
      dbe_column_t * g_col = rq.rq_g_col;
      if (!g_col)
	return 0;
      g_dfe = rq.rq_g.rqp_lower;
      if (!g_dfe)
	return 0;
      /* if p and g are given, do not guess under 1 because if used together not in error there must be at least one.  Moore common will estimate higher */
      if (!p_card)
	return 0;
      *inx_card = p_card;
      *col_card = arity_scale (*col_card);
      return 1;
    }
  if (RQ_BOUND_RANGE == rq.rq_s.rqp_op)
    return 0;
  col2 = rq_rqp (&rq, key->key_parts->next->data);
  col3 = rq_rqp (&rq, key->key_parts->next->next->data);
  if (RQ_UNBOUND == col2->rqp_op && RQ_UNBOUND == col3->rqp_op)
    {
      *inx_card = p_card;
      return 1;
    }
  if (RQ_BOUND_EQ == col2->rqp_op && RQ_UNBOUND == col3->rqp_op)
    {
      df_elt_t * fk_col = col2->rqp_lower->_.bin.right;
      float col2_card = p_stat[1];
      /* like in sql, if the referencing column has a lower card than the referenced then use the lower of the cards to estimate selectivity of the cond.  Else guessing too many distincts wil get cards out of whack */
      if (DFE_COLUMN == fk_col->dfe_type && (fk_col->_.col.col == rq.rq_s_col || fk_col->_.col.col == rq.rq_o_col)
	  && fk_col->_.col.card && fk_col->_.col.card < col2_card)
	col2_card = fk_col->_.col.card;
      *inx_card = p_card / col2_card;
      return 1;
    }
  *col_card = 1;
  if ((RQ_CONST_EQ == rq.rq_s.rqp_op && RQ_UNBOUND == rq.rq_o.rqp_op)
      || (RQ_CONST_EQ == rq.rq_o.rqp_op && RQ_UNBOUND == rq.rq_s.rqp_op))
    {
      *inx_card = rq_sample (dfe, &rq, ic);
      return 1;
    }
  if (RQ_BOUND_EQ == rq.rq_s.rqp_op && (RQ_CONST_EQ == rq.rq_o.rqp_op || RQ_CONST_RANGE == rq.rq_o.rqp_op))
    {
      float o_sel = p_card / rq_sample (dfe, &rq, ic);
      float s_card;
      if (o_sel < 0)
	return 0;
      if (col2 == &rq.rq_s)
	s_card = p_stat[1];
      else 
	{
	  float p_s_stat[4];
	  rc = dfe_p_card (dfe, &rq, p_s_stat, ic, SO_S);
	  if (-1 != rc)
	    s_card = p_s_stat[1];
	  else
	    s_card = p_stat[2];
	}
      if (col2 == &rq.rq_s || RQ_CONST_EQ == rq.rq_o.rqp_op)
	*inx_card = (p_card / s_card) / MAX (1, o_sel);
      else
	{
	  *inx_card = p_card / o_sel;
	  *col_card = 1 / s_card;
	}
      if (is_unq)
	*inx_card = MIN (1, *inx_card);
      return 1;
    }
  if (RQ_CONST_EQ == rq.rq_s.rqp_op && RQ_BOUND_EQ == rq.rq_o.rqp_op)
    {
      float s_sel = p_card / rq_sample (dfe, &rq, ic);
      float o_card;
      if (s_sel < 0)
	return 0;
      if (col2 == &rq.rq_o)
	o_card = p_stat[1];
      else
	{
	  float p_o_stat[4];
	  if (-1 != dfe_p_card (dfe, &rq, p_o_stat, ic, SO_O))
	    o_card = p_o_stat[1];
	  else
	    o_card = p_stat[2];
	}
      *inx_card = (p_card / o_card) / s_sel;
      if (is_unq)
	*inx_card = MIN (1, *inx_card);
      return 1;
    }
  if (RQ_BOUND_EQ == rq.rq_s.rqp_op && RQ_BOUND_EQ == rq.rq_o.rqp_op)
    {
      float o_stat[4];
      if (col2 == &rq.rq_s)
	rc = dfe_p_card (dfe, &rq, o_stat, ic, SO_O);
      else
		rc = dfe_p_card (dfe, &rq, o_stat, ic, SO_S);
      if (-1 == rc)
	return 0;
      *inx_card = p_card / p_stat[1] / o_stat[1];
      return 1;
    }
  return 0;
}


int32 enable_pg_card = 1;

int
sqlo_use_p_stat (df_elt_t * dfe, df_elt_t ** lowers, int inx_const_fill, int64 est, float *inx_arity, float *col_arity)
{
  /* if there is a sample with leading constant p and the rest variable, consult the key_p_stat for the p in question */
  caddr_t p;
  float * place;
  dbe_key_t * key = dfe->_.table.key;
  df_elt_t * so_dfe, * g_dfe;
  df_elt_t * lower3 = NULL, * upper3 = NULL;
  dbe_column_t * col2, * col3 = NULL;
  if (!enable_p_stat || !inx_const_fill)
    return 0;
  if (!key->key_p_stat || 0 != strcmp (((dbe_column_t*)key->key_parts->data)->col_name, "P")
      || !strstr (key->key_table->tb_name, "RDF_QUAD"))
    return 0;
  col2 = (dbe_column_t*)key->key_parts->next->data;
  so_dfe = sqlo_key_part_best (col2, dfe->_.table.col_preds, 0);
  if ('S'== col2->col_name[0])
    col3 = key_find_col (key, "O");
  else
    col3 = key_find_col (key, "S");
  g_dfe = NULL;
  if (col3)
    {
      lower3 = sqlo_key_part_best (col3, dfe->_.table.col_preds, 0);
       upper3 = sqlo_key_part_best (col3, dfe->_.table.col_preds, 1);
    }
  if (so_dfe && BOP_EQ!= so_dfe->_.bin.op)
    so_dfe = NULL;
  if ((!so_dfe || BOP_EQ != so_dfe->_.bin.op) && !lower3 && enable_pg_card)
    {
      /* there is only p and g, no s or o */
      dbe_column_t * g_col = key_find_col (dfe->_.table.key,  "G");
      if (!g_col)
	return 0;
      g_dfe = sqlo_key_part_best (g_col,  dfe->_.table.col_preds, 0);
      if (!g_dfe)
	return 0;
      /* if p and g are given, do not guess under 1 because if used together not in error there must be at least one.  Moore common will estimate higher */
      if (!est)
	return 0;
      *inx_arity = est;
      *col_arity = arity_scale (*col_arity);
      return 1;
    }
  if (!so_dfe)
    return 0;
  p = dfe_iri_const (lowers[0]->_.bin.right);
  if (!p)
    return 0;
  mutex_enter (alt_ts_mtx);
  place = (float*)id_hash_get (key->key_p_stat, (caddr_t)&((iri_id_t*)p)[0]);
  dk_free_box (p);
  if (!place)
    {
      mutex_leave (alt_ts_mtx);
      return 0;
    }
  *inx_arity = est / place[1];
  mutex_leave (alt_ts_mtx);
  if (lower3 || upper3)
    {
      float p_cost, p_arity;
      sqlo_pred_unit (lower3, upper3, dfe, &p_cost, &p_arity);
	  *inx_arity *= p_arity;
	}
  return 1;
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


int enable_arity_scale = 1;


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
  if (!enable_arity_scale)
    return ar;
  if (ar > 1)
    return ar;
  l = log (10/ar) / log (10);
  return  0.1 + (0.9 * (1 / l));
}


float 
sqlo_hash_ins_cost (df_elt_t * dfe, float card, dk_set_t cols)
{
  float mem_cost = sqlo_hash_mem_cost (card);
  if (dfe->_.table.is_unique && !cols)
    return 3 * mem_cost  * card;
  return card * (6 * mem_cost + (mem_cost * 0.2 * (1 + dk_set_length (cols))));
}
 

float
sqlo_hash_ref_cost (df_elt_t * dfe, float hash_card)
{
  float mem_cost, total_cost;
  float total_arity = dfe->dfe_arity;
  total_cost = mem_cost = sqlo_hash_mem_cost (hash_card);
  if (!dfe->_.table.is_unique || dfe->_.table.out_cols)
    total_cost *= 2;
  if (dfe->_.table.out_cols)
    total_cost += mem_cost * 0.5 * (dk_set_length (dfe->_.table.out_cols) - 1);
  if (!dfe->_.table.is_unique)
    total_cost += 2 * mem_cost * MAX (0,  total_arity - 1);
  return total_cost;
} 

void
dfe_hash_fill_cost (df_elt_t * dfe, float * unit, float * card, float * overhead_ret)
{
  float ov = 0;
  df_elt_t * fill_dfe = dfe->_.table.hash_filler;
  dfe_unit_cost (fill_dfe, 0, unit, card, &ov);
  *unit += sqlo_hash_ins_cost (dfe, *card, dfe->_.table.out_cols);
  *unit += ov;
}


void
dfe_table_ip_cost (df_elt_t * tb_dfe, index_choice_t * ic)
{
  sqlo_index_path_cost (tb_dfe->_.table.index_path, &ic->ic_unit, &ic->ic_arity, &ic->ic_leading_constants);
}


int
dfe_rq_col_pos (df_elt_t * dfe, char cn)
{
  int nth = 0;
  DO_SET (dbe_column_t *, col, &dfe->_.table.key->key_parts)
    {
      if (toupper (col->col_name[0]) == cn)
	return nth;
      nth++;
    }
  END_DO_SET();
  GPF_T1 ("bad col for rdf quad ni looking for col pos in cost model");
  return 0;
}


int
dfe_sample_dep_only (df_elt_t * dfe, float col_card)
{
  if (tb_is_rdf_quad (dfe->_.table.ot->ot_table))
    return 0;
  if (sqlo_sample_dep_cols && dfe->_.table.col_preds && 1 != col_card)
    return 1;
  return 0;
}


void
dfe_table_unq_card (df_elt_t * dfe, index_choice_t * ic, float tb_card, float * inx_card_ret, df_elt_t ** eq_preds, int eq_fill, float * col_card_ret)
{
  /* adjust card of joini to a non rdf table where unique keys are given.  If this is a multipart fk, then the card guess is 1, if the parts come from different tables these are considered independent and the card is the product of the selectivities */
  int inx;
  dbe_key_t * key = dfe->_.table.key;
  float inx_card = *inx_card_ret;
  float col_card = *col_card_ret;
  caddr_t pref = NULL;
  if (sqlo_sample_dep_cols && col_card < 0.9)
    {
      int64 est = sqlo_inx_sample (dfe, dfe->_.table.key, NULL, NULL, 0, ic);
      *col_card_ret /= ic->ic_col_card_corr;
    }
  if (1 == key->key_n_significant)
    goto independent;
  for (inx = 0; inx < eq_fill; inx++)
    {
      df_elt_t * eq = eq_preds[inx];
      df_elt_t * rhs;
      if (!eq)
	goto independent;
      rhs = eq->_.bin.right;
      if (DFE_COLUMN != rhs->dfe_type)
	goto independent;
      if (!pref)
	pref = rhs->dfe_tree->_.col_ref.prefix;
      else if (strcmp (pref, rhs->dfe_tree->_.col_ref.prefix))
	goto independent;
    }
  if (eq_fill == key->key_n_significant)
    {
      *inx_card_ret = 1;
      return;
    }
 independent:
  inx_card = MIN (1, inx_card);
  *inx_card_ret = inx_card;
}


int
dfe_rdfs_type_check_card (df_elt_t * dfe, index_choice_t * ic, df_elt_t ** eqs, int n_eqs, float * inx_cost_ret)
{
  /* recognize p = rdfs:type and s and o given, s not constant. Favor use of pogs  */
  dbe_key_t * key;
  caddr_t name;
  int s_pos, o_pos;
  if (n_eqs < 3 || !dfe_is_quad (dfe))
    return 0;
  key = dfe->_.table.key;
  if (!RQ_IS_COL (key->key_parts->data, 'P') || !eqs[0])
    return 0;
  name = sqlo_iri_constant_name (eqs[0]->_.bin.right->dfe_tree);
  if (!name)
    return 0;
  if (strcmp (name, RDFS_TYPE_IRI))
    return 0;
  s_pos = dfe_rq_col_pos (dfe, 'S');
  o_pos = dfe_rq_col_pos (dfe, 'O');
  if (o_pos >= n_eqs || s_pos >= n_eqs || !eqs[s_pos] || !eqs[o_pos])
    return 0;
  if (!eqs[2])
    return 0;
  if (3 == s_pos)
    *inx_cost_ret *= 0.8;
  ic->ic_inx_card = 0.8;
  dfe->_.table.is_arity_sure = 6; /* set this so that this will be believed rather than a sample with less parts */
  return 1;
}


void
dfe_table_cost_ic_1 (df_elt_t * dfe, index_choice_t * ic, int inx_only)
{
  float * u1 = &ic->ic_unit;
  float * a1 = &ic->ic_arity;
  float * overhead_ret = &ic->ic_overhead;
  int64 inx_sample = -1;
  int nth_part = 0, eq_fill = 0;
  df_elt_t * eq_preds[10];
  dbe_key_t * key = dfe->_.table.key;
  int n_significant = dfe->_.table.key->key_n_significant;
  int unique = 0;
  int unq_limit = key->key_is_unique ? key->key_decl_parts : key->key_n_significant;
  dbe_table_t * tb = dfe->_.table.ot->ot_table;
  float p_cost, p_arity, rows_per_page, inx_arity_sc;
  float inx_cost = 0;
  float inx_arity, inx_arity_guess_for_const_parts = -1, tb_count;
  float col_arity = 1;
  float col_cost = (float) 0.12;
  float total_cost, total_arity;
  int is_indexed = 1;
  df_elt_t * inx_uppers[5] = {0,0,0,0,0};
  df_elt_t * inx_lowers[5] = {0,0,0,0,0};
  int is_inx_const = 1, inx_const_fill = 0, p_stat = 0;
  if (dfe->_.table.index_path)
    {
      dfe_table_ip_cost (dfe, ic);
	return;
    }
  ic->ic_key = key;
  tb_count = inx_arity = (float) dbe_key_count (dfe->_.table.key);
  tb_count = MAX (1, tb_count);
  ic->ic_leading_constants = dfe->_.table.is_arity_sure = 0;
  if (!inx_only && dfe->dfe_unit > 0)
    {
      /* do not recompute if already known */
      *a1 = dfe->dfe_arity;
      *u1 = dfe->dfe_unit;
      if (dfe->_.table.hash_role == HR_REF)
	{
	  float fu1, fa1, fo1;
	  dfe_hash_fill_cost (dfe, &fu1, &fa1, &fo1);
	  *overhead_ret += fu1;
	}
      if (dfe->_.table.join_test)
	{
	  dfe_pred_body_cost (dfe->_.table.join_test, &p_cost, &p_arity, overhead_ret);
	}
      return;
    }
  inx_cost = dbe_key_unit_cost (dfe->_.table.key);
  ic->ic_ric = rdf_name_to_ctx (sqlo_opt_value (dfe->_.table.ot->ot_opts, OPT_RDF_INFERENCE));
  DO_SET (dbe_column_t *, part, &dfe->_.table.key->key_parts)
    {
      df_elt_t * lower = NULL;
      df_elt_t * upper = NULL;
      lower = sqlo_key_part_best (part, dfe->_.table.col_preds, 0);
      upper = sqlo_key_part_best (part, dfe->_.table.col_preds, 1);
      if (is_indexed && eq_fill < sizeof (eq_preds) / sizeof (caddr_t))
	eq_preds[eq_fill++] = (lower && PRED_IS_EQ (lower)) ? lower : NULL;
      if (lower || upper)
	{
	  sqlo_pred_unit (lower, upper, dfe, &p_cost, &p_arity);
	  if (is_indexed)
	    {
	      inx_cost += (float) COL_PRED_COST * log (inx_arity) / log (2);  /*cost of compare * log2 of inx count */
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
		  float r_card;
		  is_inx_const = 0;
		  if (inx_const_fill && nth_part == inx_const_fill)
		    inx_arity_guess_for_const_parts = inx_arity / p_arity; /* inx_arity before being multiplied by the p_arity of the non-const part.  Set exactly once, after seeing the first non-constant key part. */
		  if (dfe_range_card (dfe, lower, upper, &r_card))
		      inx_arity = (inx_arity / p_arity ) * r_card;
		}
	      if (!lower || BOP_EQ != lower->_.bin.op)
		is_indexed = 0;
	    }
	  else
	    {
	      /* here we should check if row spec was used to take samples */
	      if (!(sqlo_sample_dep_cols &&
		    (lower ? !sqlo_in_list (lower, NULL, NULL) && pred_const_rhs (lower) : 1) &&
		    (upper ? !sqlo_in_list (upper, NULL, NULL) && pred_const_rhs (upper) : 1)))
		{
		  dfe_range_card (dfe, lower, upper, &p_arity);
		}
	      col_cost += p_cost * col_arity;
	      col_arity *= p_arity;
	    }
	}
      else
	{
	  if (is_indexed && key->key_not_null && !part->col_sqt.sqt_non_null)
	    {
	      ic->ic_not_applicable = 1;
	    }
	is_indexed = 0;
	}
      if (!(lower && BOP_EQ == lower->_.bin.op))
	{
	  /* if there is already an eq on the col, we do not give extra selectivity for more conds.  The multiple eqs are mutually eq as generated by sparql */
	  DO_SET (df_elt_t *, pred, &dfe->_.table.col_preds)
	    {
	      df_elt_t ** in_list = sqlo_in_list (pred, NULL, NULL);
	      dbe_column_t * left_col;
	      if (DFE_TEXT_PRED == pred->dfe_type)
		continue;
	      left_col = in_list ? in_list[0]->_.col.col :
		(pred->_.bin.left->dfe_type == DFE_COLUMN ? pred->_.bin.left->_.col.col : NULL);
	      if (DFE_BOP_PRED == pred->dfe_type && part == left_col && pred != lower && pred != upper)
		{
		  sqlo_pred_unit (pred, NULL, dfe, &p_cost, &p_arity);
		  col_cost += p_cost * col_arity;
		  col_arity *= p_arity;
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
  ic->ic_is_unique = unique;
  ic->ic_inx_card = inx_arity;

  if (dfe_rdfs_type_check_card (dfe, ic, eq_preds, eq_fill, &inx_cost))
    inx_arity = ic->ic_inx_card;
  else if (2 == enable_p_stat && tb_is_rdf_quad (dfe->_.table.ot->ot_table) && sqlo_use_p_stat_2 (dfe, &inx_arity, &col_arity, ic, &inx_sample))
    {
      p_stat = 2;
      ic->ic_inx_card = inx_arity;
      ic->ic_leading_constants = dfe->_.table.is_arity_sure = inx_const_fill * 2 + (0 != p_stat);
    }
  else if (unique && !ic->ic_ric)
    {
      dfe_table_unq_card (dfe, ic, tb_count, &inx_arity, eq_preds, eq_fill, &col_arity);
    }
  else if (LOC_LOCAL == dfe->dfe_locus && (inx_const_fill || dfe_sample_dep_only (dfe, col_arity))
	   && !(dfe->dfe_sqlo->so_sc->sc_is_update && 0 == strcmp (dfe->_.table.ot->ot_new_prefix, "t1")))
    {
      inx_sample = sqlo_inx_sample (dfe, key, inx_lowers, inx_uppers, inx_const_fill, ic);
      if (inx_sample > 1 && sqlo_sample_dep_cols)
	{
	  col_arity /= ic->ic_col_card_corr;
	  inx_sample = ic->ic_inx_card;
	}
      if (-1 == inx_sample)
	goto no_sample;
      else if (0 == inx_sample)
	inx_arity = 10 / tb_count;
      else if (sqlo_use_p_stat (dfe, inx_lowers, inx_const_fill, inx_sample, &inx_arity, &col_arity))
	p_stat = 1;
      else
	{
	  if (inx_const_fill)
	    inx_arity = inx_sample * inx_arity / (inx_arity_guess_for_const_parts != -1 ? inx_arity_guess_for_const_parts : inx_arity);
	  /* Consider if 2 first key parts are const and third is var.  Get the real arity for the const but do not forget the guess  for  the 3rd*/
	}
      ic->ic_leading_constants = dfe->_.table.is_arity_sure = inx_const_fill * 2 + (0 != p_stat);
    no_sample: ;
    }
  if (-INFINITY == inx_arity) bing ();
  if (enable_vec_cost)
    inx_cost = dfe_vec_inx_cost (dfe, ic, inx_sample);
  if (unique && ic->ic_ric)
    inx_arity = MIN (1, inx_arity);
  if (ic->ic_ric)
    sqlo_non_leading_const_inf_cost (dfe, inx_lowers, inx_uppers, ic);
  inx_arity_sc = 2 == p_stat ? inx_arity : arity_scale (inx_arity);
    
  ic->ic_is_unique = dfe->_.table.is_unique = unique;
  if (key->key_is_bitmap)
    {
      col_cost *= 0.6; /* cols packed closer together, more per page in bm inx */
    }
  if (dfe->_.table.key->key_is_col)
    {
      total_cost = inx_cost + dfe_cs_row_cost (dfe, inx_arity, col_arity);
    }
  else
    {
      total_cost = inx_cost + (col_cost + ROW_SKIP_COST) * (3 + inx_arity_sc)
	+ dbe_key_row_cost (dfe->_.table.key, &rows_per_page, NULL) * inx_arity_sc;
      /* count col compare cost at least twice, else you get a case where a key with 1 leading part matched + 1 non contiguous part matched is better than 2 leading parts as long as the selectivity of the 1st part is near one row.  This is the case with empty tables so procs compiled w no data will get this fucked up */
      total_cost += NEXT_PAGE_COST * inx_arity_sc / rows_per_page;
    }
  total_arity = inx_arity * col_arity;

  if (inx_only )
    {
      *u1 = total_cost;
      if (p_stat != 2)
	*a1 = arity_scale (total_arity);
      else
	*a1 = total_arity;
      *overhead_ret = 0;
      return;
    }

  /* the ordering key is now done. See if you need to join to the main row  */
  if (sqlo_table_any_nonkey_refd (dfe)
      || (dfe->dfe_sqlo->so_sc->sc_is_update && 0 == strcmp (dfe->_.table.ot->ot_new_prefix, "t1")))
    {
      /* if cols are refd that are not on the key or if upd/del, in which case join to main row always needed */
      dbe_key_t * pk = tb->tb_primary_key;
      if (dfe->_.table.key != pk)
	total_cost += inx_arity_sc * (
	    dbe_key_unit_cost (tb->tb_primary_key) +
	    dbe_key_row_cost (tb->tb_primary_key, NULL, NULL));
      DO_SET (df_elt_t *, pred, &dfe->_.table.col_preds)
	{
	  dbe_column_t * left_col;
	  df_elt_t ** in_list = sqlo_in_list (pred, NULL, NULL);
	  if (DFE_TEXT_PRED == pred->dfe_type)
	    continue;
	  left_col = in_list ? in_list[0]->_.col.col : DFE_COLUMN == pred->_.bin.left->dfe_type ? pred->_.bin.left->_.col.col : NULL;
	  if (DFE_BOP_PRED == pred->dfe_type &&
	      !dk_set_member (key->key_parts, (void*) left_col) &&
	      !dk_set_member (ic->ic_inx_sample_cols, (void*) left_col))
	    {
	      dfe->_.table.key = pk;
	      sqlo_pred_unit (pred, NULL, dfe, &p_cost, &p_arity);
	      dfe->_.table.key = key;
	      total_arity *= p_arity;
	      total_cost += p_cost * inx_arity_sc;
	    }
	}
      END_DO_SET();
    }
  if (dfe->_.table.join_test)
    {
      dfe_pred_body_cost (dfe->_.table.join_test, &p_cost, &p_arity, overhead_ret);
      p_arity = arity_scale (p_arity);
    }
  else
    {
      p_cost = 0;
      p_arity = 1;
    }
  if (tb_text_key (dfe->_.table.ot->ot_table))
    dfe_text_cost (dfe, &total_cost, &total_arity, 0);

  if (HR_FILL == dfe->_.table.hash_role)
    {
#if 0
      float fill_arity = total_arity * p_arity; /* join pred may filter before hash insertion */
      total_cost = total_cost + fill_arity * dfe_hash_fill_unit (dfe, fill_arity);
      if (dfe->dfe_locus && IS_BOX_POINTER (dfe->dfe_locus))
	{
	  dfe->_.table.hash_role = HR_NONE;
	  total_cost += sqlo_dfe_locus_rpc_cost (dfe->dfe_locus, dfe);
	  dfe->_.table.hash_role = HR_FILL;
	}
#endif
    }
  else if (dfe->_.table.hash_role == HR_REF)
    {
      float fu1, fa1, fo1, mem_cost;
      dfe_hash_fill_cost (dfe, &fu1, &fa1, &fo1);
      *overhead_ret += fu1;
      total_cost = mem_cost = sqlo_hash_mem_cost (fa1);
      if (!dfe->_.table.is_unique || dfe->_.table.out_cols)
	total_cost *= 2;
      if (dfe->_.table.out_cols)
	total_cost += mem_cost * 0.5 * (dk_set_length (dfe->_.table.out_cols) - 1);
      if (!dfe->_.table.is_unique)
	total_cost += 2 * mem_cost * MAX (0,  total_arity - 1);
      p_arity *= dfe_hash_fill_cond_card (dfe);
    }
  total_cost += p_cost * arity_scale (total_arity);
  total_arity *= p_arity;
  if (dfe->_.table.ot->ot_is_outer)
    total_arity = MAX (1, total_arity);
  /* the right of left outer has never cardinality < 1.  But the join tests etc are costed at cardinality that can be < 1. So adjust this as last.*/
  dfe->dfe_arity = *a1 = total_arity;
  dfe->dfe_unit = *u1 = total_cost;
  if (IC_AS_IS != ic->ic_op && ic->ic_ric)
    sqlo_try_inf_filter (dfe, ic);
}


void
dfe_table_cost_1 (df_elt_t * dfe, float * u1, float * a1, float * overhead_ret, int inx_only)
{
  index_choice_t ic;
  memset (&ic, 0, sizeof (ic));
  ic.ic_op = IC_AS_IS;
  dfe_table_cost_ic_1 (dfe, &ic, inx_only);
  *u1 = ic.ic_unit;
  *a1 = ic.ic_arity;
  *overhead_ret += ic.ic_overhead;
}


void
dfe_table_cost_ic (df_elt_t * dfe, index_choice_t * ic, int inx_only)
{
  int n_in, inx;
  du_thread_t * thr = THREAD_CURRENT_THREAD;
  SET_THR_ATTR  (thr, TA_N_IN_ITEMS, (caddr_t) -1);
  SET_THR_ATTR (thr, TA_NTH_IN_ITEM, 0);
  dfe_table_cost_ic_1 (dfe, ic, inx_only);
  n_in = (ptrlong) THR_ATTR (thr, TA_N_IN_ITEMS);
  if (-1 == n_in)
    return;
  for (inx = 1; inx < n_in; inx++)
    {
      index_choice_t in_ic;
      memset (&in_ic, 0, sizeof (in_ic));
      SET_THR_ATTR (thr, TA_NTH_IN_ITEM, (caddr_t) (ptrlong) inx);
      dfe->dfe_unit = 0;
      dfe_table_cost_ic_1 (dfe, &in_ic, inx_only);
      ic->ic_unit += in_ic.ic_unit;
      ic->ic_arity += in_ic.ic_arity;
    }
  dfe->dfe_unit = ic->ic_unit;
  dfe->dfe_arity = ic->ic_arity;
}


void
dfe_table_cost (df_elt_t * dfe, float * u1, float * a1, float * overhead_ret, int inx_only)
{
  index_choice_t ic;
  if (!dfe->_.table.key)
    {
      *a1 = 1;
      *u1 = 0.1;
      return;
    }
  memset (&ic, 0, sizeof (ic));
  ic.ic_op = IC_AS_IS;
  dfe_table_cost_ic (dfe, &ic, inx_only);
  *u1 = ic.ic_unit;
  *a1 = ic.ic_arity;
  *overhead_ret += ic.ic_overhead;
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
	  if (ST_COLUMN (colp_dfe->dfe_tree->_.bin_exp.left, COL_DOTTED) &&
	      (!CASEMODESTRCMP (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)
	       || box_equal (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)))
	    goto next_arg;
	  else if (ST_COLUMN (colp_dfe->dfe_tree->_.bin_exp.right, COL_DOTTED) &&
		   (!CASEMODESTRCMP (name, colp_dfe->dfe_tree->_.bin_exp.right->_.col_ref.name)
		    || box_equal (name, colp_dfe->dfe_tree->_.bin_exp.right->_.col_ref.name)))
	    goto next_arg;
	}
      END_DO_SET();
      DO_SET (df_elt_t *, colp_dfe, &dt_dfe->_.sub.dt_imp_preds)
	{
	  if (ST_COLUMN (colp_dfe->dfe_tree->_.bin_exp.left, COL_DOTTED) &&
	      (!CASEMODESTRCMP (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)
	       || box_equal (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)))
	    goto next_arg;
	  else if (ST_COLUMN (colp_dfe->dfe_tree->_.bin_exp.right, COL_DOTTED) &&
		   (!CASEMODESTRCMP (name, colp_dfe->dfe_tree->_.bin_exp.right->_.col_ref.name)
		    || box_equal (name, colp_dfe->dfe_tree->_.bin_exp.right->_.col_ref.name)))
	    goto next_arg;
	}
      END_DO_SET();
      DO_SET (df_elt_t *, colp_dfe, &dt_dfe->_.sub.ot->ot_join_preds)
	{
	  if (ST_COLUMN (colp_dfe->dfe_tree->_.bin_exp.left, COL_DOTTED) &&
	      (!CASEMODESTRCMP (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)
	       || box_equal (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)))
	    goto next_arg;
	  else if (ST_COLUMN (colp_dfe->dfe_tree->_.bin_exp.right, COL_DOTTED) &&
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
dfe_top_discount (df_elt_t * dfe, float * u1, float * a1)
{
  /* applied to dts with top, value subqs, existences after they are laid out.  Not applied during layout selection so as not to minimize sizes of intermediate results */
  if (dfe_ot (dfe) && ST_P (dfe_ot (dfe)->ot_dt, SELECT_STMT))
    {
      int is_sort = sqlo_is_postprocess (dfe->dfe_sqlo, dfe, NULL);
      int is_distinct = SEL_IS_DISTINCT (dfe_ot (dfe)->ot_dt);
      ST *top_exp = SEL_TOP (dfe_ot (dfe)->ot_dt);
      ptrlong top_cnt = sqlo_select_top_cnt (dfe->dfe_sqlo, top_exp);
      if (top_cnt && top_cnt < *a1)
	{
	  if (!is_sort)
	    *u1 /= *a1 / top_cnt;
	  *a1 = top_cnt;
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


float
dfe_exp_card (sqlo_t * so, df_elt_t * dfe)
{
  if (!dfe)
    return 1;
  switch (dfe->dfe_type)
    {
    case DFE_COLUMN:
      if (dfe->_.col.card)
	return dfe->_.col.card;
      if (dfe->_.col.col)
	return dfe->_.col.col->col_n_distinct;
      return 1000;
    case DFE_BOP:
      return dfe_exp_card (so, dfe->_.bin.left) * dfe_exp_card (so, dfe->_.bin.right);
    case DFE_CALL:
      {
	float c = 1;
	int inx;
	DO_BOX (df_elt_t *, arg, inx, dfe->_.call.args)
	  {
	    c *= dfe_exp_card (so, arg);
	  }
	END_DO_BOX;
	return c;
      }
    default: return 1;
    }
}


float
dfe_group_by_card (df_elt_t * dfe)
{
  sqlo_t * so = dfe->dfe_sqlo;
  int inx;
  float c = 1;
  DO_BOX (ST *, spec, inx, dfe->_.setp.specs)
    {
      df_elt_t * exp = sqlo_df (so, dfe->_.setp.is_distinct ? (ST*)spec : spec->_.o_spec.col);
      c *= dfe_exp_card (so, exp);
    }
  END_DO_BOX;
  return c;
}


int enable_value_subq_cost = 1;
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
    case DFE_VALUE_SUBQ:
      if (!enable_value_subq_cost)
	goto deflt;

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
	  if (ST_P (dfe->_.sub.ot->ot_dt, PROC_TABLE))
	    {
	      sqlo_proc_table_cost (dfe, u1, a1);
	      return;
	    }
	  dfe_list_cost (dfe->_.sub.first, u1, a1, overhead_ret, dfe->dfe_locus);
	  if (dfe->_.sub.is_complete)
	    dfe_top_discount (dfe, u1, a1);
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
	    /* with a top sort node, it is log2 of the top cnt and half the cost of the inx sprt temp.  Add 1 because log (1) is zero  */
	    *u1 = (float) 0.5 * (INX_ROW_INS_COST + INX_CMP_COST *  log ((double) dfe->_.setp.top_cnt + 1) / log (2));
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
      if (!dfe->_.setp.specs && dfe->_.setp.fun_refs)
	{ /* pure fun ref node */
	  *u1 = (float) dk_set_length (dfe->_.setp.fun_refs) * sqlo_agg_cost;
	  *a1 = 1 / input_arity;
	}
      else
	{
	  dfe->_.setp.gb_card = dfe_group_by_card (dfe);
	  if (dfe->_.setp.is_linear)
	*u1 = 1;
	  else if (dfe->_.setp.gb_card < 1000000 || input_arity < 1000000)
	    *u1 = HASH_MEM_INS_COST;
      else
	    *u1 = (float) HASH_ROW_INS_COST;
	  *a1 = input_arity < 1 ? 1
	    : dfe->_.setp.gb_card > input_arity ? 0.5 : dfe->_.setp.gb_card / input_arity;
	}
      break;

    case DFE_CALL:
      sqlo_proc_cost (dfe, u1, a1);
      break;
    case DFE_FILTER:
      dfe_pred_body_cost (dfe->_.filter.body,  u1, a1,  overhead_ret);
	break;
    default:
    deflt:
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

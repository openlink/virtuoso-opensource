/*
 *  colsearch.c
 *
 *  $Id$
 *
 *  Random access for column compressed data
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2011 OpenLink Software
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
#include "arith.h"
#include "date.h"
#include "xmltree.h"
#include "sqltype.h"


caddr_t
itc_alloc_box (it_cursor_t * itc, int len, dtp_t dtp)
{
  if (itc && itc->itc_temp_max)
    {
      db_buf_t ptr;
      int fill = itc->itc_temp_fill;
      int bytes = 8 + ALIGN_8 (len);
#if defined(WORDS_BIGENDIAN) && defined(SOLARIS)
      if (0 == fill)
	{
	  fill = (uptrlong) itc->itc_temp % 8;
	  if (fill)
	    fill = 8 - fill;
	  itc->itc_temp_max -= fill;
	  itc->itc_temp_fill += fill;
	}
#endif
      if (fill + bytes > itc->itc_temp_max)
	{
	  return dk_alloc_box (len, dtp);
	}
      ptr = itc->itc_temp + fill + 4;
      WRITE_BOX_HEADER (ptr, len, dtp);
      itc->itc_temp_fill += bytes;
      return (caddr_t) itc->itc_temp + fill + 8;
    }
  return dk_alloc_box (len, dtp);
}

col_data_ref_t *
itc_new_cr (it_cursor_t * itc)
{
  col_data_ref_t *cr = (col_data_ref_t *) itc_alloc_box (itc, sizeof (col_data_ref_t), DV_BIN);
  memset (cr, 0, sizeof (col_data_ref_t));
  cr->cr_pages = &cr->cr_pre_pages[0];
  cr->cr_pages_sz = sizeof (cr->cr_pre_pages) / sizeof (col_page_t);
  return cr;
}


void
itc_set_sp_stat (it_cursor_t * itc)
{
  search_spec_t *sp;
  int n = 0;
  for (sp = itc->itc_row_specs; sp; sp = sp->sp_next)
    n++;
  itc->itc_n_row_specs = n;
  if (itc->itc_sp_stat && itc->itc_is_col && itc->itc_sp_stat != &itc->itc_pre_sp_stat[0])
    itc_free_box (itc, (caddr_t) itc->itc_sp_stat);
  if (!itc->itc_n_row_specs)
    {
      itc->itc_sp_stat = NULL;
      return;
    }
  if (n <= sizeof (itc->itc_pre_sp_stat) / sizeof (sp_stat_t))
    itc->itc_sp_stat = &itc->itc_pre_sp_stat[0];
  else
    itc->itc_sp_stat = (sp_stat_t *) itc_alloc_box (itc, n * sizeof (sp_stat_t), DV_BIN);
  memzero (itc->itc_sp_stat, n * sizeof (sp_stat_t));
  n = 0;
  for (sp = itc->itc_row_specs; sp; sp = sp->sp_next)
    {
      itc->itc_sp_stat[n].spst_sp = sp;
      n++;
    }
}


void
itc_col_init (it_cursor_t * itc)
{
  search_spec_t *sp;
  it_cursor_t *zero = NULL;
  db_buf_t tmp = itc->itc_temp;
  int nth = 0;
  int n_keys = itc->itc_insert_key->key_n_significant;
  int first = (ptrlong) & zero->itc_col_first_set;
  int last = (ptrlong) & zero->itc_owned_search_params;
  short mx = itc->itc_temp_max;
  memset (((caddr_t) itc) + first, 0, last - first);
  itc->itc_temp = tmp;
  itc->itc_temp_max = mx;
  itc->itc_is_col = 1;
  itc->itc_col_refs = (col_data_ref_t **) itc_alloc_box (itc, itc->itc_insert_key->key_n_parts * sizeof (caddr_t), DV_BIN);
  memset (itc->itc_col_refs, 0, box_length (itc->itc_col_refs));
  for (sp = itc->itc_key_spec.ksp_spec_array; sp; sp = sp->sp_next)
    {
      col_data_ref_t *cr = itc_new_cr (itc);
      itc->itc_col_refs[nth] = cr;
      nth++;
    }
  for (sp = itc->itc_row_specs; sp; sp = sp->sp_next)
    {
      if (!itc->itc_col_refs[sp->sp_cl.cl_nth - n_keys])
	{
	  col_data_ref_t *cr = itc_new_cr (itc);
	  itc->itc_col_refs[sp->sp_cl.cl_nth - n_keys] = cr;
	}
    }
  if (itc->itc_ks && itc->itc_ks->ks_v_out_map)
    {
      int inx, n = box_length (itc->itc_ks->ks_v_out_map) / sizeof (v_out_map_t);
      for (inx = 0; inx < n; inx++)
	{
	  dbe_col_loc_t *cl = &itc->itc_ks->ks_v_out_map[inx].om_cl;
	  if (cl->cl_col_id && !itc->itc_col_refs[cl->cl_nth - n_keys])
	    {
	      col_data_ref_t *cr = itc_new_cr (itc);
	      itc->itc_col_refs[cl->cl_nth - n_keys] = cr;
	    }
	}
    }
  itc_set_sp_stat (itc);
}


void
itc_col_free (it_cursor_t * itc)
{
  int inx;
  if (!itc->itc_is_col)
    return;
  itc_free_box (itc, itc->itc_ranges);
  itc_free_box (itc, itc->itc_matches);
  itc_free_box (itc, itc->itc_set_eqs);
  DO_BOX (col_data_ref_t *, cr, inx, itc->itc_col_refs)
  {
    if (!cr)
      continue;
    if (cr->cr_pages != &cr->cr_pre_pages[0])
      itc_free_box (itc, cr->cr_pages);
    itc_free_box (itc, cr);
  }
  END_DO_BOX;
  itc_free_box (itc, (caddr_t) itc->itc_col_refs);
  if (itc->itc_sp_stat && itc->itc_sp_stat != &itc->itc_pre_sp_stat[0])
    itc_free_box (itc, (caddr_t) itc->itc_sp_stat);
  itc->itc_is_col = 0;
}


void
col_make_map (page_map_t ** pm_ret, db_buf_t str, int head, int buf_len)
{
  page_map_t *pm = *pm_ret;
  int fill = 0;
  if (!pm)
    pm = (page_map_t *) resource_get (PM_RC (PM_SZ_1));
  pm->pm_bytes_free = buf_len;
  pm->pm_filled_to = head;
  DO_CE (ce, bytes, values, ce_type, flags, str + head, buf_len)
  {
    if (CE_GAP == ce_type)
      goto next;
    if (fill + 1 >= pm->pm_size)
      {
	pm->pm_count = fill;
	map_resize (&pm, PM_SIZE (fill + 2));
      }
    pm->pm_entries[fill] = ce - str;
    pm->pm_entries[fill + 1] = values;
    fill += 2;
    pm->pm_bytes_free -= bytes + __hl;
    pm->pm_filled_to = ce + bytes + __hl - str;
  next:;
  }
  END_DO_CE (ce, n_bytes);
  pm->pm_count = fill;
  *pm_ret = pm;
}

void
pg_make_col_map (buffer_desc_t * buf)
{
  col_make_map (&buf->bd_content_map, buf->bd_buffer, DP_DATA, PAGE_DATA_SZ);
}


int enable_strcmp8 = 1;

int
strcmp8 (unsigned char *s1, unsigned char *s2, int l1, int l2)
{
  int inx, min_l = MIN (l1, l2);
  memcmp_8l (s1, s2, min_l, neq, inx);
  return l1 == l2 ? DVC_MATCH : l1 < l2 ? DVC_LESS : DVC_GREATER;
neq:
  if (min_l - inx > 4 && *(int32 *) (s1 + inx) == *(int32 *) (s2 + inx))
    inx += 4;
  for (inx = inx; inx < min_l; inx++)
    if (s1[inx] < s2[inx])
      return DVC_LESS;
    else if (s1[inx] > s2[inx])
      return DVC_GREATER;
  GPF_T1 ("should not come here in strcmp8");
  return 0;
}



int
str_cmp_offset (db_buf_t dv1, db_buf_t dv2, int n1, int n2, int64 offset)
{
  int inx = 0;
  dtp_t c1;
  dtp_t last4[4];
  if (!offset && enable_strcmp8)
    return strcmp8 (dv1, dv2, n1, n2);
  if (!offset)
    {
      int min_len = MIN (n1, n2);
#if defined(__GNUC__)
      int rc = __builtin_memcmp (dv1, dv2, min_len);
#else
      int rc = memcmp (dv1, dv2, min_len);
#endif
      if (0 == rc)
	return n1 == n2 ? DVC_MATCH : n1 < n2 ? DVC_LESS : DVC_GREATER;
      return rc < 0 ? DVC_LESS : DVC_GREATER;
    }
  while (1)
    {
      if (inx == n1)
	{
	  if (inx == n2)
	    return DVC_MATCH;
	  else
	    return DVC_LESS;
	}
      if (inx == n2)
	return DVC_GREATER;
      c1 = dv1[inx];
      if (offset)
	{
	  if (inx < n1 - 4)
	    ;
	  else if ((0 == inx && n1 < 4))
	    {
	      uint32 last = LONG_REF_NA (dv1 + (n1 - 4));
	      last += offset;
	      LONG_SET_NA (&last4, last);
	      c1 = last4[4 - (n1 - inx)];
	    }
	  else if (inx == n1 - 4)
	    {
	      uint32 last = LONG_REF_NA (dv1 + inx);
	      last += offset;
	      LONG_SET_NA (&last4, last);
	      c1 = last4[0];
	    }
	  else
	    c1 = last4[4 - (n1 - inx)];
	}
      if (c1 < dv2[inx])
	return DVC_LESS;
      if (c1 > dv2[inx])
	return DVC_GREATER;
      inx++;
    }
}

#define CE_CMP_IS_NULL(cl, param) \
  ((DV_ANY == (cl)->cl_sqt.sqt_col_dtp) ? DV_DB_NULL == ((db_buf_t)param)[0] : DV_IS_NULL ((caddr_t)param))


int
ce_col_cmp (db_buf_t any, int64 offset, dtp_t ce_flags, dbe_col_loc_t * cl, caddr_t value)
{
  collation_t *collation;
  dtp_t tmp[COL_MAX_BYTES];
  int res;
  db_buf_t dv1, dv2, dv3;
  int inx;
  row_size_t l1, l3;
  int l2;
  boxint n1, n2;
  if (CET_ANY == (ce_flags & CE_DTP_MASK) && DV_DB_NULL == any[0])
    {
      return DVC_UNKNOWN;
    }
  else
    {
      if (CE_CMP_IS_NULL (cl, value))
	return DVC_GREATER;
    }
  switch (cl->cl_sqt.sqt_col_dtp)
    {
    case DV_SHORT_INT:
    case DV_INT64:
    case DV_LONG_INT:
      if (CET_ANY == (ce_flags & CE_DTP_MASK))
	n1 = any_num_f (any) + offset;
      else
	n1 = offset;
      switch (DV_TYPE_OF (value))
	{
	case DV_LONG_INT:
	  n2 = unbox_inline (value);
	  return NUM_COMPARE (n1, n2);
	case DV_SINGLE_FLOAT:
	  return cmp_double (((float) n1), *(float *) value, DBL_EPSILON);
	case DV_DOUBLE_FLOAT:
	  return cmp_double (((double) n1), *(double *) value, DBL_EPSILON);
	case DV_NUMERIC:
	  {
	    NUMERIC_VAR (n);
	    numeric_from_int64 ((numeric_t) & n, n1);
	    return (numeric_compare_dvc ((numeric_t) & n, (numeric_t) value));
	  }
	default:
	  {
	    log_error ("Unexpected param dtp=[%d]", DV_TYPE_OF (value));
	    GPF_T;
	  }
	}
    case DV_DATETIME:
    case DV_TIMESTAMP:
    case DV_DATE:
    case DV_TIME:
      any_add ((db_buf_t) (ptrlong) any, DT_LENGTH + 1, offset, tmp, ce_flags);
      dv1 = tmp;
      dv2 = (db_buf_t) value;
      for (inx = 0; inx < DT_COMPARE_LENGTH; inx++)
	{
	  if (dv1[inx + 1] == dv2[inx])
	    continue;
	  if (dv1[inx + 1] > dv2[inx])
	    return DVC_GREATER;
	  else
	    return DVC_LESS;
	}
      return DVC_MATCH;

    case DV_NUMERIC:
      {
	NUMERIC_VAR (n);
	dv1 = any;
	numeric_from_dv ((numeric_t) & n, dv1, sizeof (n));
	if (DV_DOUBLE_FLOAT == DV_TYPE_OF (value))
	  {
	    double d;
	    numeric_to_double ((numeric_t) & n, &d);
	    return cmp_double (d, *(double *) value, DBL_EPSILON);
	  }
	return (numeric_compare_dvc ((numeric_t) & n, (numeric_t) value));
      }
    case DV_SINGLE_FLOAT:
      {
	int32 fi;
	float flt;
	if (CE_INTLIKE (ce_flags))
	  {
	    fi = (int32) offset;
	    flt = *(float *) &fi;
	  }
	else
	  {
	    dtp_t tmp[4];
	    uint32 x = LONG_REF_NA (any + 1);
	    LONG_SET_NA (&tmp[0], x + offset);
	    EXT_TO_FLOAT (&flt, tmp);
	  }
	switch (DV_TYPE_OF (value))
	  {
	  case DV_SINGLE_FLOAT:
	    return (cmp_double (flt, *(float *) value, FLT_EPSILON));
	  case DV_DOUBLE_FLOAT:
	    return (cmp_double (((double) flt), *(double *) value, DBL_EPSILON));
	  case DV_NUMERIC:
	    {
	      NUMERIC_VAR (n);
	      numeric_from_double ((numeric_t) & n, (double) flt);
	      return (numeric_compare_dvc ((numeric_t) & n, (numeric_t) value));
	    }
	  }
      }
    case DV_DOUBLE_FLOAT:
      {
	double dbl;
	if (CE_INTLIKE (ce_flags))
	  {
	    if (ce_flags & CE_IS_64)
	      dbl = *(double *) &offset;
	    else
	      dbl = *(double *) &offset;
	  }
	else
	  {
	    dtp_t tmp[8];
	    uint32 x = LONG_REF_NA (any + 5);
	    memcpy (&tmp[0], any + 1, 4);
	    LONG_SET_NA (&tmp[4], x + offset);
	    EXT_TO_DOUBLE (&dbl, tmp);
	  }
	/* if the col is double, any arg is cast to double */
	return (cmp_double (dbl, *(double *) value, DBL_EPSILON));
      }
    case DV_IRI_ID:
    case DV_IRI_ID_8:
      {
	iri_id_t i1;
	iri_id_t i2 = unbox_iri_id (value);
	if (CE_INTLIKE (ce_flags))
	  i1 = offset;
	else
	  i1 = any_num (any) + offset;
	res = NUM_COMPARE (i1, i2);
	return res;
      }
    default:
      if (CET_ANY == (ce_flags & CE_DTP_MASK))
	{
	  long hl, l;
	  dtp_t dtp = any[0];
	  if (-1 == db_buf_const_length[dtp])
	    {
	      hl = 2;
	      l = any[1];
	    }
	  else
	  db_buf_length (any, &hl, &l);
	  dv1 = any + hl;
	  l1 = l;
	  l3 = 0;
	  dv3 = NULL;
	}
      else if (CET_CHARS == (ce_flags & CE_DTP_MASK))
	{
	  dv1 = any;
	  l1 = *(dv1++);
	  if (l1 > 127)
	    l1 = (l1 - 128) * 256 + *(dv1++);
	  l3 = 0;
	  dv3 = NULL;
	}
    }
  switch (cl->cl_sqt.sqt_col_dtp)
    {

    case DV_BIN:
      dv2 = (db_buf_t) value;
      l2 = box_length (dv2);
      return str_cmp_offset (dv1, dv2, l1, l2, offset);
    case DV_STRING:
      collation = cl->cl_sqt.sqt_collation;
      dv2 = (db_buf_t) value;
      l2 = box_length_inline (dv2) - 1;
      inx = 0;
      if (collation)
	{
	  while (1)
	    {
	      if (inx == l1)
		{
		  if (inx == l2)
		    return DVC_MATCH;
		  else
		    return DVC_LESS;
		}
	      if (inx == l2)
		return DVC_GREATER;
	      if (collation->co_table[(unsigned char) dv1[inx]] < collation->co_table[(unsigned char) dv2[inx]])
		return DVC_LESS;
	      if (collation->co_table[(unsigned char) dv1[inx]] > collation->co_table[(unsigned char) dv2[inx]])
		return DVC_GREATER;
	      inx++;
	    }
	}
      else
	return str_cmp_offset (dv1, dv2, l1, l2, offset);
    case DV_WIDE:
    case DV_LONG_WIDE:
      {
	/* the param is cast to narrow utf8 */
	dv2 = (db_buf_t) value;
	l2 = box_length (dv2) - 1;
	return str_cmp_offset (dv1, dv2, l1, l2, offset);
      }
    case DV_ANY:
      dv2 = (db_buf_t) value;
      if (CE_INTLIKE (ce_flags))
	{
	  tmp[0] = CE_IS_IRI & ce_flags ? DV_IRI_ID_8 : DV_INT64;
	  INT64_SET_NA (&tmp[1], offset);
	  dv1 = tmp;
	  offset = 0;
	}
      else if (CET_CHARS == (ce_flags & CE_DTP_MASK))
	{
	  int hl, len;
	  CET_CHARS_LEN (any, hl, len);
	  any_add (any, len, offset, tmp, ce_flags);
	  dv1 = tmp;
	  offset = 0;
	}
      else
	{
	  dv1 = any;
	  if (DV_DATETIME == *dv1)
	    {
	      any_add (dv1, DT_LENGTH + 1, offset, tmp, ce_flags);
	      dv1 = tmp;
	      offset = 0;
	    }
	}
      return (dv_compare_so (dv1, dv2, cl->cl_sqt.sqt_collation, offset));
    default:
      GPF_T1 ("type not supported in comparison");
    }
  return 0;
}


int64
ce_int_nn_value (db_buf_t ce, row_no_t row_no)
{
  dtp_t flags = *ce;
  int hl;
  switch (flags & ~CE_IS_SHORT)
    {
    case CE_VEC:
      hl = CE_IS_SHORT & flags ? 2 : 3;
      return (int32) LONG_REF_CA (ce + hl + 4 * row_no);
    case CE_VEC | CE_IS_IRI:
      hl = CE_IS_SHORT & flags ? 2 : 3;
      return (uint32) LONG_REF_CA (ce + hl + 4 * row_no);
    case CE_VEC | CE_IS_64:
    case CE_VEC | CE_IS_64 | CE_IS_IRI:
      hl = CE_IS_SHORT & flags ? 2 : 3;
      return INT64_REF_CA (ce + hl + 8 * row_no);
    case CE_VEC | CET_ANY:
      {
	db_buf_t ce_first_val;
	db_buf_t ce_first;
	int n_values, first_len;
	dtp_t off = 0;
	hl = CE_IS_SHORT & flags ? 3 : 5;
	ce_first = ce + hl;
	n_values = CE_ANY_VEC_N_VALUES (ce);
	ce_vec_nth (ce_first, flags, n_values, row_no, &ce_first_val, &first_len, 0);
	if (ce_first_val[0] < DV_ANY_FIRST)
	  {
	    short inx = ce_first_val[0] <= MAX_1_BYTE_CE_INX ? (off = ce_first_val[1], ce_first_val[0])
		: (off = ce_first_val[2], (ce_first_val[0] - MAX_1_BYTE_CE_INX - 1) * 256 + ce_first_val[1]);
	    db_buf_t org;
	    int org_len;
	    ce_vec_nth (ce_first, flags, n_values, inx, &org, &org_len, 0);
	    off -= org[org_len - 1];
	    ce_first_val = org;
	  }
	switch (*ce_first_val)
	  {
	  case DV_SHORT_INT:
	    return ((signed char *) ce_first_val)[1] + off;
	  case DV_LONG_INT:
	    return (int32) LONG_REF_NA (ce_first_val + 1) + off;
	  case DV_IRI_ID_8:
	  case DV_INT64:
	    return INT64_REF_NA (ce_first_val + 1) + off;
	  case DV_IRI_ID:
	    return (uint32) LONG_REF_NA (ce_first_val + 1) + off;
	  }
      }

    default:
      GPF_T1 ("unsupported int ce");
    }
  return 0;
}


int enable_last_gt_cache = 1;

int
ce_search_cmp (db_buf_t ce, int row_no, int64 n, dtp_t dtp, it_cursor_t * itc)
{
  /* presupposes that the ce type and dtp are compatible. n and dtp must come from itc_ce_search_param */
  int64 ti[2];
  int64 first;
  db_buf_t ce_first;
  dbe_key_t *key;
  col_pos_t cpo;
  dtp_t flags = ce[0];
  dtp_t cet = flags & CE_DTP_MASK;
  dtp_t ce_type = flags & CE_TYPE_MASK;
  if ( /*enable_last_gt_cache && */ CE_INTLIKE (flags) && ce == itc->itc_last_cmp_ce && row_no == itc->itc_last_cmp_row)
    {
      if (DV_IRI_ID == dtp)
	return NUM_COMPARE ((iri_id_t) itc->itc_last_cmp_value, (iri_id_t) n);
      else if (DV_LONG_INT == dtp)
	return NUM_COMPARE ((int64) itc->itc_last_cmp_value, (int64) n);
      else
	goto gen;
    }
  if (!CE_INTLIKE (flags) || (0 != row_no && CE_VEC != ce_type))
    goto gen;
  switch (ce_type)
    {
    case CE_RL:
      ce_first = ce + (CE_IS_SHORT & flags ? 2 : 3);
      goto get_first;
    case CE_BITS:
    case CE_RL_DELTA:
      ce_first = ce + (CE_IS_SHORT & flags ? 3 : 5);
    get_first:
      if (CE_IS_IRI & flags ? DV_IRI_ID != dtp : DV_LONG_INT != dtp)
	goto gen;
      if (CE_IS_64 & flags)
	{
	  first = INT64_REF_CA (ce_first);
	  ce_first += 8;
	}
      else
	{
	  if (CE_IS_IRI & flags)
	    first = (iri_id_t) (uint32) LONG_REF_CA (ce_first);
	  else
	    first = LONG_REF_CA (ce_first);
	  ce_first += 4;
	}
      if (CE_RL_DELTA == ce_type && (0xf0 & ce_first[0]))
	goto gen;		/* rld ce starts witha non-zero delta */
      if (CE_IS_IRI & flags)
	return NUM_COMPARE (((iri_id_t) first), ((iri_id_t) n));
      return NUM_COMPARE (((int64) first), ((int64) n));
    case CE_VEC:
      if (CET_INT == cet)
	{
	  int64 c;
	  if (DV_LONG_INT != dtp)
	    goto gen;
	  c = ce_int_nn_value (ce, row_no);
	  return NUM_COMPARE (c, n);
	}
      if (CET_IRI == cet)
	{
	  iri_id_t c;
	  if (DV_IRI_ID != dtp)
	    goto gen;
	  c = ce_int_nn_value (ce, row_no);
	  return NUM_COMPARE ((iri_id_t) c, (iri_id_t) n);
	}
      break;
    default:
      goto gen;
    }
gen:
  cpo.cpo_string = ce;
  cpo.cpo_ce_row_no = 0;
  cpo.cpo_bytes = 1;
  cpo.cpo_value_cb = ce_cmp_1;
  key = itc->itc_insert_key;
  cpo.cpo_cl = &key->key_row_var[itc->itc_nth_key];
  if (DV_LONG_INT == dtp || DV_IRI_ID == dtp || DV_IRI_ID_8 == dtp)
    {
      if (DV_ANY == itc->itc_col_spec->sp_cl.cl_sqt.sqt_dtp)
	{
	  dtp_t ctmp[MAX_FIXED_DV_BYTES];
	  cpo.cpo_cmp_min = (caddr_t) (ptrlong) dv_if_needed (n, dtp, ctmp);
	}
      else
	{
	  cpo.cpo_cmp_min = (caddr_t) & ti[1];
	  ti[1] = n;
	  ((dtp_t *) & ti[0])[7] = dtp;
	}
    }
  else
    cpo.cpo_cmp_min = (caddr_t) (ptrlong) n;
  cpo.cpo_ce_op = NULL;
  cpo.cpo_itc = itc;
  cpo.cpo_pm = NULL;
  cs_decode (&cpo, row_no, row_no + 1);
  if (DVC_GREATER == cpo.cpo_rc && CE_INTLIKE (flags))
    {
      itc->itc_last_cmp_ce = ce;
      itc->itc_last_cmp_row = row_no;
    }
  return cpo.cpo_rc;
}



page_map_t *
itc_temp_map (it_cursor_t * itc)
{
  page_map_t *pm = (page_map_t *) itc_alloc_box (itc, PM_ENTRIES_OFFSET + 20 * sizeof (short), DV_BIN);
  memset (pm, 0, PM_ENTRIES_OFFSET);
  pm->pm_size = 20;
  return pm;
}


void
itc_extend_array (it_cursor_t * itc, int *sz, int elt_sz, void ***arr)
{
  void **prev = *arr;
  int prev_sz = *sz;
  *arr = (void **) itc_alloc_box (itc, 2 * *sz * elt_sz, DV_BIN);
  *sz *= 2;
  memcpy_16 (*arr, prev, prev_sz * elt_sz);
  itc_free_box (itc, prev);
}


dp_addr_t
cr_nth_dp (col_data_ref_t * cr, int inx)
{
  buffer_desc_t *buf = cr->cr_pages[inx].cp_buf;
  if (buf)
    return buf->bd_page;
  return (dp_addr_t) (uptrlong) cr->cr_pages[inx].cp_string;
}


long tc_col_rewait;
int enable_col_fetch_vec = 1;

void
itc_fetch_col_vec (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, int from_row, ptrlong to_row)
{
  /* read and wire the buffers for the seg/col */
  dp_addr_t dps[1000];
  dbe_key_t * key = itc->itc_insert_key;
  unsigned short vl1, vl2, offset;
  int n_pages, cr_inx, ces_left;
  db_buf_t xx, xx2;
  db_buf_t row = NULL;
  page_lock_t * pl = itc->itc_pl;
  col_data_ref_t * cr = itc->itc_col_refs[cl->cl_nth - key->key_n_significant];
  dtp_t dtp;
  index_tree_t * tree = itc->itc_tree;
  it_map_t * maps = tree->it_maps;
  cr->cr_n_pages = 0;
  if (n_pages > sizeof (dps) / sizeof (dp_addr_t)) 
    GPF_T1 ("over 1000 pages in col in segment");
  row = BUF_ROW (buf, itc->itc_map_pos);
  ROW_STR_COL (buf->bd_tree->it_key->key_versions[IE_KEY_VERSION (row)], buf, row, cl, xx, vl1, xx2, vl2, offset); \
  if (vl2) GPF_T1 ("col ref string should nott be compressed");
  dtp = *xx;
  if (DV_STRING == dtp)
    GPF_T1 ("ces inlined on leaf page are not supported");
  cr->cr_n_access++;
  cr->cr_n_pages = n_pages = (vl1 - CPP_DP) / sizeof (dp_addr_t);
  if (cr->cr_pages_sz < n_pages)
    {
      col_page_t * old_pages = cr->cr_pages;
      cr->cr_pages_sz = n_pages + 4;
      cr->cr_pages = (col_page_t*)itc_alloc_box (itc, cr->cr_pages_sz * sizeof (col_page_t), DV_BIN);
      if (old_pages != &cr->cr_pre_pages[0])
	itc_free_box (itc, (caddr_t)old_pages);
    }
  cr->cr_first_ce_page = 0;
  cr->cr_first_ce = SHORT_REF_NA (xx + CPP_FIRST_CE);
  ces_left = cr->cr_n_ces = SHORT_REF_NA (xx + CPP_N_CES);
  cr->cr_limit_ce = -1;

  for (cr_inx = 0; cr_inx < n_pages; cr_inx++)
    {
      dp_addr_t dp = LONG_REF_NA ((xx + CPP_DP) + sizeof (dp_addr_t) * cr_inx);
      it_map_t * itm = IT_DP_MAP (tree, dp);
      dk_hash_t * ht = &itm->itm_dp_to_buf;
      uint32 hno = HASH_INX (ht, (void*)(ptrlong)dp);
      __builtin_prefetch (&ht->ht_elements[hno]);
      dps[cr_inx] = dp;
    }
  for (cr_inx = 0; cr_inx < n_pages; cr_inx++)
    {
      dp_addr_t dp = dps[cr_inx];
      do {
	ITC_IN_KNOWN_MAP (itc, dp);
	page_wait_access (itc, dp, 
			  NULL, &cr->cr_pages[cr_inx].cp_buf, ITC_LANDED_PA (itc), RWG_WAIT_ANY);
	if (itc->itc_to_reset > RWG_WAIT_ANY) TC (tc_col_rewait);
      } 	while (itc->itc_to_reset > RWG_WAIT_ANY);
      ITC_LEAVE_MAPS (itc);
      if (PF_OF_DELETED == cr->cr_pages[cr_inx].cp_buf)
	GPF_T1 ("ref to deld col page");
      cr->cr_pages[cr_inx].cp_string = cr->cr_pages[cr_inx].cp_buf->bd_buffer;
      cr->cr_pages[cr_inx].cp_map = cr->cr_pages[cr_inx].cp_buf->bd_content_map;
      cr->cr_pages[cr_inx].cp_ceic = NULL;
    }
  for (cr_inx = 0; cr_inx < n_pages; cr_inx++) 
    {
      int ces_here;
      page_map_t * pm = cr->cr_pages[cr_inx].cp_map;
      if (cr_inx < n_pages - 2)
	__builtin_prefetch (&cr->cr_pages[cr_inx + 2].cp_map->pm_count);
      ces_here = (pm->pm_count / 2) - (0 == cr_inx ? cr->cr_first_ce  : 0);
      if (ces_left < ces_here)
	{
	  if (cr_inx != cr->cr_n_pages - 1) 
	    log_error ("out of whack to have col ref where the last ce is not on the last refd page");
	  cr->cr_limit_ce = 2 * ((0 == cr_inx ? cr->cr_first_ce : 0) + ces_left);
	  if (0 == cr->cr_limit_ce)
	    log_error ("out of whack to have 0 as limit ce.  Means that the col string refs a page that has no ce of this seg");
	}
      ces_left -= ces_here;
    }
  if (-1 == cr->cr_limit_ce)
    cr->cr_limit_ce = cr->cr_pages[cr->cr_n_pages - 1].cp_map->pm_count;
  cr->cr_is_valid = 1;
  itc->itc_pl = pl;
}


void
itc_fetch_col (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, int from_row, ptrlong to_row)
{
  /* read and wire the buffers for the seg/col */
  int is_append = 0, present_only = 0;
  ac_col_stat_t *ac = NULL;
  dbe_key_t *key = itc->itc_insert_key;
  unsigned short vl1, vl2, offset;
  int n_pages, inx, ces_left;
  db_buf_t xx, xx2;
  db_buf_t row = NULL;
  ce_ins_ctx_t *ceic = NULL;
  page_lock_t *pl = itc->itc_pl;
  col_data_ref_t *cr = itc->itc_col_refs[cl->cl_nth - key->key_n_significant];
  dtp_t dtp;
  if (FC_APPEND == from_row || FC_APPEND_PRESENT == from_row)
    {
      if (FC_APPEND_PRESENT == from_row)
	{
	  present_only = 1;
	  ac = (ac_col_stat_t *) to_row;
	  to_row = COL_NO_ROW;
	}
      from_row = 0;
      is_append = 1;
    }
  else if (FC_FROM_CEIC == from_row)
    {
      from_row = 0;
      ceic = (ce_ins_ctx_t *) to_row;
      to_row = COL_NO_ROW;
    }
  else if (enable_col_fetch_vec)
    {
      itc_fetch_col_vec (itc, buf, cl, from_row, to_row);
      return;
    }
  if (!is_append)
    cr->cr_n_pages = 0;
  if (ceic && ceic->ceic_rds)
    {
      xx = ceic_updated_col (ceic, buf, itc->itc_map_pos, cl);
      vl1 = box_length (xx) - 1;
    }
  else
    {
      row = BUF_ROW (buf, itc->itc_map_pos);
      ROW_STR_COL (buf->bd_tree->it_key->key_versions[IE_KEY_VERSION (row)], buf, row, cl, xx, vl1, xx2, vl2, offset);
      if (vl2)
	GPF_T1 ("col ref string should nott be compressed");
      dtp = *xx;
      if (DV_STRING == dtp)
	GPF_T1 ("ces inlined on leaf page are not supported");
      cr->cr_n_access++;
    }
  n_pages = (vl1 - CPP_DP) / sizeof (dp_addr_t);
  if (ac)
    ac->acs_n_pages = n_pages;
  if (cr->cr_pages_sz < n_pages + cr->cr_n_pages)
    {
      col_page_t *old_pages = cr->cr_pages;
      cr->cr_pages_sz = cr->cr_n_pages + n_pages + (is_append ? 40 : 4);
      cr->cr_pages = (col_page_t *) itc_alloc_box (itc, cr->cr_pages_sz * sizeof (col_page_t), DV_BIN);
      if (is_append)
	memcpy_16 (cr->cr_pages, old_pages, sizeof (col_page_t) * cr->cr_n_pages);
      if (old_pages != &cr->cr_pre_pages[0])
	itc_free_box (itc, (caddr_t) old_pages);
    }
  cr->cr_first_ce_page = 0;
  if (!is_append)
    {
      cr->cr_first_ce = SHORT_REF_NA (xx + CPP_FIRST_CE);
      ces_left = cr->cr_n_ces = SHORT_REF_NA (xx + CPP_N_CES);
    }
  else
    {
      ces_left = SHORT_REF_NA (xx + CPP_N_CES);
      cr->cr_n_ces += ces_left;
    }
  cr->cr_limit_ce = -1;
  for (inx = 0; inx < n_pages; inx++)
    {
      page_map_t *pm;
      int cr_inx;
      int ces_here;
      dp_addr_t dp = LONG_REF_NA ((xx + CPP_DP) + sizeof (dp_addr_t) * inx);
      if (is_append && cr->cr_n_pages && dp == cr_nth_dp (cr, cr->cr_n_pages - 1))
	continue;
      if (ac)
	ac->acs_own_pages++;
      cr_inx = cr->cr_n_pages++;
      do
	{
	  ITC_IN_KNOWN_MAP (itc, dp);
	  if (present_only)
	    {
	      buffer_desc_t *buf = IT_DP_TO_BUF (itc->itc_tree, dp);
	      if (!buf)
		{
		  ITC_LEAVE_MAPS (itc);
		  cr->cr_pages[cr_inx].cp_buf = NULL;
		  cr->cr_pages[cr_inx].cp_string = (db_buf_t) (ptrlong) dp;
		  if (ac)
		    ac->acs_absent_pages++;
		  goto next_buf;
		}
	    }
	  page_wait_access (itc, dp, NULL, &cr->cr_pages[cr_inx].cp_buf, ITC_LANDED_PA (itc), RWG_WAIT_ANY);
	  if (itc->itc_to_reset > RWG_WAIT_ANY)
	    TC (tc_col_rewait);
	  if (buf && itc->itc_is_ac && buf->bd_pool)	/* if stuff is read for ac only, mark it old dirty for flush soon */
	    buf->bd_timestamp -= buf->bd_pool->bp_stat_ts - buf->bd_pool->bp_bucket_limit[BP_N_BUCKETS - 1];

	}
      while (itc->itc_to_reset > RWG_WAIT_ANY);
      ITC_LEAVE_MAPS (itc);
      if (PF_OF_DELETED == cr->cr_pages[cr_inx].cp_buf)
	GPF_T1 ("ref to deld col page");
      cr->cr_pages[cr_inx].cp_string = cr->cr_pages[cr_inx].cp_buf->bd_buffer;
      pm = cr->cr_pages[cr_inx].cp_map = cr->cr_pages[cr_inx].cp_buf->bd_content_map;
      cr->cr_pages[cr_inx].cp_ceic = NULL;
      if (ac && cr->cr_pages[cr_inx].cp_buf->bd_is_dirty)
	ac->acs_n_dirty++;
      if (!is_append)
	{
	  ces_here = (pm->pm_count / 2) - (0 == cr_inx ? cr->cr_first_ce : 0);
	  if (ces_left < ces_here)
	    {
	      if (inx != cr->cr_n_pages - 1)
		log_error ("out of whack to have col ref where the last ce is not on the last refd page");
	      cr->cr_limit_ce = 2 * ((0 == inx ? cr->cr_first_ce : 0) + ces_left);
	      if (0 == cr->cr_limit_ce)
		log_error ("out of whack to have 0 as limit ce.  Means that the col string refs a page that has no ce of this seg");
	    }
	  ces_left -= ces_here;
	}
    next_buf:;
    }
  if (-1 == cr->cr_limit_ce && !present_only)
    cr->cr_limit_ce = cr->cr_pages[cr->cr_n_pages - 1].cp_map->pm_count;
  if (is_append && !present_only)
    {
      cr_limit_ce (cr, &cr->cr_limit_ce);
    }
  cr->cr_is_valid = 1;
  itc->itc_pl = pl;
}


void
itc_range (it_cursor_t * itc, row_no_t lower, row_no_t upper)
{
  int rf = itc->itc_range_fill;
  int sz;
  if (!itc->itc_ranges)
    itc->itc_ranges = (row_range_t *) itc_alloc_box (itc, sizeof (row_range_t) * (itc->itc_n_sets + 4), DV_BIN);
  sz = box_length (itc->itc_ranges) / sizeof (row_range_t);
  if (rf + 1 == sz)
    itc_extend_array (itc, &sz, sizeof (row_range_t), (void ***) &itc->itc_ranges);
  itc->itc_ranges[rf].r_first = lower;
  itc->itc_ranges[rf].r_end = upper;
  itc->itc_range_fill = rf + 1;
}


void
itc_col_leave (it_cursor_t * itc, int flags)
{
  /* leave the col buffers held by itc */
  int inx;
  DO_BOX (col_data_ref_t *, cr, inx, itc->itc_col_refs)
  {
    int n_buf;
    if (!cr || !cr->cr_is_valid)
      continue;
    cr->cr_is_valid = 0;
    for (n_buf = 0; n_buf < cr->cr_n_pages; n_buf++)
      {
	if (cr->cr_pages[n_buf].cp_buf)
	  page_leave_outside_map (cr->cr_pages[n_buf].cp_buf);
	if (ITC_NO_CEIC_CLEAR != flags)
	  memzero (&cr->cr_pages[n_buf], sizeof (col_page_t));
      }
  }
  END_DO_BOX;
}


int
itc_n_sets_before (it_cursor_t * itc, buffer_desc_t * buf, int pos)
{
  /* return how many sets, including current set, before the key value at pos */
  return 0;
}

int
itc_n_sets_in_seg (it_cursor_t * itc, buffer_desc_t * buf)
{
  /* return how many sets start at or below the last row in the seg */
  return 0;
}


int
pm_n_rows (page_map_t * pm, int first_ce)
{
  int n = 0, inx;
  for (inx = first_ce * 2; inx < pm->pm_count; inx += 2)
    n += pm->pm_entries[inx + 1];
  return n;
}


dtp_t
ce_dtp_f (db_buf_t ce)
{
  /* if a ce is single dtp, e.g. bitmap, rl, rld, typed vec return the type. Does not apply to mixed ce like any vec or any dict */
  dtp_t ce_dtp;
  dtp_t cet = ce[0] & ~CE_IS_SHORT;
  if ((CE_DICT | CET_ANY) == cet || (CE_VEC || CET_ANY) == cet)
    GPF_T1 ("ce_dtp does not apply to mixed type ces");
  switch (ce[0] & CE_DTP_MASK)
    {
    case CE_IS_IRI:
      ce_dtp = DV_IRI_ID;
      break;
    case 0:
      ce_dtp = DV_LONG_INT;
      break;
    case CET_CHARS:
      ce_dtp = DV_STRING;
      break;
    case CET_ANY:
      ce_dtp = dtp_canonical[ce[(CE_IS_SHORT & ce[0]) ? 3 : 5]];
      break;
    default:
      GPF_T1 ("unknown dtp for ce_is_dtp_less");
    }
  return ce_dtp;
}


int
ce_dtp_compare (db_buf_t ce, dtp_t dtp)
{
  /* if a ce is single dtp, e.g. bitmap, rl, rld, typed vec return the type. Does not apply to mixed ce like any vec or any dict */
  dtp_t ce_dtp;
  dtp_t cet = ce[0] & ~CE_IS_SHORT;
  if ((CE_DICT | CET_ANY) == cet || (CE_VEC | CET_ANY) == cet)
    return DVC_MATCH;		/* mixed dtps, compare actual values */
  switch (ce[0] & CE_DTP_MASK)
    {
    case CE_IS_IRI | CE_IS_64:
    case CE_IS_IRI:
      ce_dtp = DV_IRI_ID;
      break;
    case CET_INT | CE_IS_64:
    case CET_INT:
      ce_dtp = DV_LONG_INT;
      break;
    case CET_CHARS:
      ce_dtp = DV_STRING;
      break;
    case CET_ANY:
      {
	int first;
	if ((cet & CE_TYPE_MASK) <= CE_RL)
	  ce_dtp = dtp_canonical[ce[first = (CE_IS_SHORT & ce[0]) ? 2 : 3]];
	else
	  ce_dtp = dtp_canonical[ce[first = (CE_IS_SHORT & ce[0]) ? 3 : 5]];
	if (DV_RDF == ce_dtp)
	  ce_dtp = dtp_canonical[ce[first + 2]];
	break;
      }
    default:
      ce_dtp = 0;
      GPF_T1 ("unknown dtp for ce_is_dtp_less");
    }
  if (ce_dtp == dtp)
    return DVC_MATCH;
  if (IS_NUM_DTP (ce_dtp))
    ce_dtp = DV_LONG_INT;
  if (IS_NUM_DTP (dtp))
    dtp = DV_LONG_INT;
  return ce_dtp == dtp ? DVC_MATCH : ce_dtp < dtp ? DVC_DTP_LESS : DVC_DTP_GREATER;
}


int
ce_typed_vec_dtp_compare (db_buf_t ce, dtp_t dtp)
{
  /* for a typed vec check if value type is the same.  If it is a different number type it is not the same */
  dtp_t ce_dtp;
  switch (ce[0] & CE_DTP_MASK)
    {
    case CE_IS_IRI | CE_IS_64:
    case CE_IS_IRI:
      ce_dtp = DV_IRI_ID;
      break;
    case CET_INT | CE_IS_64:
    case CET_INT:
      ce_dtp = DV_LONG_INT;
      break;
    default:
      ce_dtp = 0;		/*uninited warning */
      GPF_T1 ("unknown dtp for ce_is_dtp_less");
    }
  if (ce_dtp == dtp)
    return DVC_MATCH;
  if (IS_NUM_DTP (ce_dtp))
    ce_dtp = DV_LONG_INT;
  if (IS_NUM_DTP (dtp))
    dtp = DV_LONG_INT;
  if (DV_LONG_INT == ce_dtp && DV_LONG_INT == dtp)
    return ASC_NUMBERS;
  return ce_dtp == dtp ? DVC_MATCH : ce_dtp < dtp ? DVC_DTP_LESS : DVC_DTP_GREATER;
}

int64
itc_anify_param (it_cursor_t * itc, caddr_t box)
{
  /* for a non int, non-iri the returned is a dv string owned by the itc.  One is kept at a time */
  caddr_t err = NULL;
  int inx;
  dtp_t dtp = DV_TYPE_OF (box);
  if (DV_LONG_INT == dtp || DV_IRI_ID == dtp)
    {
      if (IS_BOX_POINTER (box))
	return *(int64 *) box;
      return (ptrlong) box;
    }
  for (inx = 0; inx < itc->itc_anify_fill; inx += 2)
    if (itc->itc_anify_cache[inx] == box)
      return (int64) (uptrlong) itc->itc_anify_cache[inx + 1];
  array_add (&itc->itc_anify_cache, &itc->itc_anify_fill, box);
  array_add (&itc->itc_anify_cache, &itc->itc_anify_fill, box_to_any (box, &err));
  return (int64) (uptrlong) itc->itc_anify_cache[itc->itc_anify_fill - 1];
}


caddr_t
itc_ce_box_param (it_cursor_t * itc, int nth_key)
{
  int64 new_v;
  int ninx;
  data_col_t *dc;
  if (!itc->itc_n_sets || !(dc = ITC_P_VEC (itc, nth_key)))
    return itc->itc_search_params[nth_key];
  ninx = itc->itc_param_order[itc->itc_set];
  new_v = dc_any_value (dc, ninx);
  if (DCT_NUM_INLINE & dc->dc_type)
    *(int64 *) itc->itc_search_params[nth_key] = new_v;
  else if (DV_ANY == itc->itc_col_spec->sp_cl.cl_sqt.sqt_col_dtp)
    itc->itc_search_params[nth_key] = (caddr_t) (ptrlong) new_v;
  else if (DV_ANY == dc->dc_dtp)
    itc->itc_search_params[nth_key] = itc_temp_any_box (itc, nth_key, (db_buf_t) new_v);
  else if (DCT_BOXES & dc->dc_type)
    itc->itc_search_params[nth_key] = (caddr_t) (ptrlong) new_v;
  else if (!itc_vec_sp_copy (itc, nth_key, new_v, ninx))
    itc->itc_search_params[nth_key] = (caddr_t) (ptrlong) new_v;
  return itc->itc_search_params[nth_key];
}


int64
itc_ce_search_param (it_cursor_t * itc, int nth_key, dtp_t * dtp_ret)
{
  if (DV_ANY == itc->itc_col_spec->sp_cl.cl_sqt.sqt_dtp)
    {
      /* if the col is an any, the search param is a dv string and this needs decoding */
      db_buf_t dv;
      if (!itc->itc_n_sets)
	dv = (db_buf_t) itc->itc_search_params[nth_key];
      else
	{
	  data_col_t *dc = ITC_P_VEC (itc, nth_key);
	  if (!dc)
	    dv = (db_buf_t) itc->itc_search_params[nth_key];
	  else
	    dv = ((db_buf_t *) dc->dc_values)[itc->itc_param_order[itc->itc_set]];
	}
      *dtp_ret = dtp_canonical[*dv];
      if (DV_RDF == *dtp_ret)
	{
	  dv += 2;
	  *dtp_ret = dtp_canonical[*dv];
	}
      if (DV_LONG_INT == *dtp_ret || DV_IRI_ID == *dtp_ret)
	return dv_int (dv, dtp_ret);
      return (int64) dv;
    }
  {
    caddr_t box = itc_ce_box_param (itc, nth_key);
    *dtp_ret = DV_TYPE_OF (box);
    return unbox_iri_int64 (box);
  }
}


int64
itc_any_param (it_cursor_t * itc, int nth_key, dtp_t * dtp_ret)
{
  if (DV_ANY == itc->itc_col_spec->sp_cl.cl_sqt.sqt_col_dtp)
    {
      /* if the col is an any, the search param is a dv string and this needs decoding */
      db_buf_t dv;
      if (!itc->itc_n_sets)
	dv = (db_buf_t) itc->itc_search_params[nth_key];
      else
	{
	  data_col_t *dc = ITC_P_VEC (itc, nth_key);
	  if (!dc)
	    dv = (db_buf_t) itc->itc_search_params[nth_key];
	  else
	    dv = ((db_buf_t *) dc->dc_values)[itc->itc_param_order[itc->itc_set]];
	}
      *dtp_ret = dtp_canonical[*dv];
      if (DV_RDF == *dtp_ret)
	{
	  dv += 2;
	  *dtp_ret = dtp_canonical[*dv];
	}
      if (DV_LONG_INT == *dtp_ret || DV_IRI_ID == *dtp_ret)
	return dv_int (dv, dtp_ret);
      return (int64) dv;
    }
  if (!itc->itc_n_sets)
    {
      *dtp_ret = DV_TYPE_OF (itc->itc_search_params[nth_key]);
      return itc_anify_param (itc, itc->itc_search_params[nth_key]);
    }
  {
    dtp_t dtp;
    data_col_t *dc = ITC_P_VEC (itc, nth_key);
    if (!dc)
      {
	*dtp_ret = DV_TYPE_OF (itc->itc_search_params[nth_key]);
	return itc_anify_param (itc, itc->itc_search_params[nth_key]);
      }
    dtp = dc->dc_sqt.sqt_dtp;
    dtp = *dtp_ret = dtp_canonical[dtp];
    switch (dtp)
      {
      case DV_DATETIME:
      {
	db_buf_t tmp = (db_buf_t) & itc->itc_owned_search_params[itc->itc_owned_search_par_fill];
	if (itc->itc_owned_search_par_fill * sizeof (caddr_t) > sizeof (itc->itc_owned_search_params) - (DT_LENGTH + 1))
	  GPF_T1 ("no space for temp dt anify in itc");
	tmp[0] = DV_DATETIME;
	memcpy_dt (tmp + 1, dc->dc_values + DT_LENGTH * itc->itc_param_order[itc->itc_set]);
	return (int64) tmp;
      }
      case DV_SINGLE_FLOAT:
      {
	db_buf_t tmp = (db_buf_t) & itc->itc_owned_search_params[itc->itc_owned_search_par_fill];
	uint32 i = ((uint32 *) dc->dc_values)[itc->itc_param_order[itc->itc_set]];
	if (itc->itc_owned_search_par_fill * sizeof (caddr_t) > sizeof (itc->itc_owned_search_params) - (DT_LENGTH + 1))
	  GPF_T1 ("no space for temp dt anify in itc");
	tmp[0] = DV_SINGLE_FLOAT;
	LONG_SET_NA (&tmp[1], i);
	return (int64) tmp;
      }
      case DV_DOUBLE_FLOAT:
      {
	db_buf_t tmp = (db_buf_t) & itc->itc_owned_search_params[itc->itc_owned_search_par_fill];
	int64 i = ((int64 *) dc->dc_values)[itc->itc_param_order[itc->itc_set]];
	if (itc->itc_owned_search_par_fill * sizeof (caddr_t) > sizeof (itc->itc_owned_search_params) - (DT_LENGTH + 1))
	  GPF_T1 ("no space for temp dt anify in itc");
	tmp[0] = DV_SINGLE_FLOAT;
	INT64_SET_NA (&tmp[1], i);
	return (int64) tmp;
      }
      case DV_NUMERIC:
	{
	  db_buf_t tmp = (db_buf_t) & itc->itc_owned_search_params[itc->itc_owned_search_par_fill];
	  caddr_t n = ((caddr_t *) dc->dc_values)[itc->itc_param_order[itc->itc_set]];
	  if (itc->itc_owned_search_par_fill * sizeof (caddr_t) >
	      sizeof (itc->itc_owned_search_params) - (NUMERIC_MAX_PRECISION_INT))
	    GPF_T1 ("no space for temp dt anify in itc");
	  numeric_to_dv ((numeric_t) n, tmp, NUMERIC_MAX_PRECISION_INT);
	  return (int64) tmp;
	}
      default:
    return ((int64 *) dc->dc_values)[itc->itc_param_order[itc->itc_set]];
  }
}
}

int64 ns_trap_value = 0x80000000;

int
itc_next_set_cmp (it_cursor_t * itc, int nth_key)
{
  /* check if prev set search params eq next set. If all equal and range starts before the seg, then must take next set with random access from the start since must refind the start of the range in the previous seg.
   * Also if the previous set was the first of batch and was continued from a previous batch, even eq of part 0 requires  a fresh random access because the start of the range according to part - is lost.  Even the range refined with all key parts is lost.
   * Else if all eq up to nth key return all eq, if params differ only in the nth but not before return leading eq */
  int was_multiseg = itc->itc_is_multiseg_set;
  int key, set = itc->itc_set, nth_rng;
  int prefetch_set = set + 2 < itc->itc_n_sets ? set + 2 : set;
  itc->itc_is_multiseg_set = 0;
  if (itc->itc_set_eqs)
    {
      dtp_t n_eq = itc->itc_set_eqs[itc->itc_set];
      if (!n_eq)
	return SET_NOT_EQ;
      if (n_eq >= 1 && nth_key >= 1 && itc->itc_range_fill == 1 && COL_NO_ROW != itc->itc_col_row)
	return SET_EQ_RESET;
      if (n_eq == nth_key)
	return SET_LEADING_EQ;
      if (n_eq > nth_key)
	{
	  if (was_multiseg)
	    goto ck_multiseg;
	  return SET_ALL_EQ;
	}
      if (n_eq < nth_key)
	return SET_NOT_EQ;
    }
  prefetch_set = itc->itc_param_order[prefetch_set];
  for (key = 0; key <= nth_key; key++)
    {
      data_col_t *dc = ITC_P_VEC (itc, key);
      if (key == 1 && itc->itc_range_fill == 1 && COL_NO_ROW != itc->itc_col_row)
	return SET_EQ_RESET;
      if (!dc)
	continue;
#if 0
      if (0x800000000 != ns_trap_value)
	{
	  dtp_t ign;
	  int64 val =
	      (DV_ANY == dc->dc_dtp) ? dv_int (((db_buf_t *) dc->dc_values)[itc->itc_param_order[set]],
	      &ign) : ((int64 *) dc->dc_values)[itc->itc_param_order[itc->itc_set]];
	  if (val == ns_trap_value)
	    bing ();
	}
#endif
      if (DVC_MATCH != dc->dc_sort_cmp (dc, itc->itc_param_order[set], itc->itc_param_order[set - 1], prefetch_set))
	{
	  if (key == nth_key)
	    return SET_LEADING_EQ;
	  return SET_NOT_EQ;
	}
    }
  if (key == 1 && itc->itc_range_fill == 1 && COL_NO_ROW != itc->itc_col_row)
    return SET_EQ_RESET;
  nth_rng = itc->itc_set - itc->itc_col_first_set;
ck_multiseg:
  if (was_multiseg)
    {
      int n_eqs = 0;
      search_spec_t *sp;
      for (sp = itc->itc_key_spec.ksp_spec_array; sp; sp = sp->sp_next)
	n_eqs++;
      for (key = nth_key + 1; key < n_eqs; key++)
	{
	  data_col_t *dc = ITC_P_VEC (itc, key);
	  if (!dc)
	    continue;
	  if (DVC_MATCH != dc->dc_sort_cmp (dc, itc->itc_param_order[set], itc->itc_param_order[set - 1], prefetch_set))
	    return SET_ALL_EQ;
	}
      itc->itc_is_multiseg_set = 1;
      return SET_EQ_RESET;
    }
  return SET_ALL_EQ;
}





int64 trap_value[4] = { 0x8000000000, 0x8000000000, 0x8000000000, 0x8000000000 };


void
itc_init_ranges (it_cursor_t * itc, row_no_t row)
{
  if (COL_NO_ROW == row)
    itc->itc_range_fill = 0;
  else
    {
      itc->itc_range_fill = 1;
      itc->itc_ranges[0].r_first = itc->itc_col_row;
      itc->itc_ranges[0].r_end = COL_NO_ROW;
    }
}


#define CE_LAST 1
#define CE_AFTER_LAST 2
#define CE_RANGE_READY 3	/* no match, ins point given based on dtp comparison only */

int
itc_is_last_ce (it_cursor_t * itc, col_data_ref_t * cr)
{
  return (itc->itc_nth_col_string == cr->cr_n_pages - 1 && cr->cr_limit_ce <= itc->itc_nth_ce + 2) ? CE_LAST : 0;
}


db_buf_t
itc_first_ce (it_cursor_t * itc, buffer_desc_t * buf, int *is_last_ce)
{
  /* find the 1st ce that can have a match for the current set/key.  If itc has a position in the seg, this ce is to the right of the position ce.
   * If ranges are filled, use the range corresponding to the set to limit the scope */
  int set = itc->itc_set - itc->itc_col_first_set;
  dtp_t dtp;
  int nth_key = itc->itc_nth_key;
  page_map_t *pm;
  int strinx, cinx, rc;
  int prev_ce_row, prev_strinx = -1, prev_ce_inx = -1, prev_ce_n_rows = 0;
  int initial_ce_inx, first_in_range;
  int64 value;
  col_data_ref_t *cr;
  row_no_t row_no = itc->itc_row_of_ce;
  row_no_t lower, upper;
  db_buf_t prev_ce = NULL, ce;
  int last_ce = 0;
  if (nth_key)
    {
      lower = itc->itc_ranges[itc->itc_set - itc->itc_col_first_set].r_first;
      upper = itc->itc_ranges[itc->itc_set - itc->itc_col_first_set].r_end;
    }
  else
    {
      lower = itc->itc_col_row;
      if (COL_NO_ROW == lower)
	lower = 0;
      upper = COL_NO_ROW;
    }
  value = itc_ce_search_param (itc, nth_key, &dtp);
  cr = itc->itc_col_refs[nth_key];
  strinx = itc->itc_nth_col_string;
  initial_ce_inx = itc->itc_nth_ce;
  row_no = itc->itc_row_of_ce;
  for (strinx = itc->itc_nth_col_string; strinx < cr->cr_n_pages; strinx++)
    {
      db_buf_t page = cr->cr_pages[strinx].cp_string;
      pm = cr->cr_pages[strinx].cp_map;
      last_ce = strinx == cr->cr_n_pages - 1 ? cr->cr_limit_ce : pm->pm_count;
      for (cinx = initial_ce_inx; cinx < last_ce; cinx += 2)
	{
	  int ce_rows = pm->pm_entries[cinx + 1];
	  if (lower >= row_no + ce_rows)
	    {
	      row_no += ce_rows;
	      continue;
	    }
	  if (cinx + 2 < last_ce)
	    __builtin_prefetch (page + pm->pm_entries[cinx + 2]);
	  ce = page + pm->pm_entries[cinx];
	  if (row_no + ce_rows >= upper)
	    {
	      if (-1 != prev_strinx)
		{
		  if (DVC_MATCH != ce_dtp_compare (ce, dtp))
		    goto ret_prev;
		  rc = ce_search_cmp (ce, 0, value, dtp, itc);
		  if (DVC_LESS == rc)
		    goto ret_this;
		  goto ret_prev;
		}
	      if (nth_key)
		{
		  /* there is no prev ce and this ce contains the end of range or the range ends before the first of this.  */
		  if (itc->itc_ranges[set].r_first < row_no)
		    itc->itc_ranges[set].r_first = row_no;
		  if (row_no == itc->itc_ranges[set].r_end)
		    {
		      *is_last_ce = 0;
		      return NULL;
		    }
		  goto ret_this;
		}
	      goto ret_this;
	    }
	  first_in_range = lower > row_no ? lower - row_no : 0;
	  rc = ce_dtp_compare (ce, dtp);
	  if (DVC_DTP_LESS == rc)
	    {
	      if (nth_key)
		itc->itc_ranges[set].r_first = MIN (itc->itc_ranges[set].r_end, row_no + ce_rows);
	      if (prev_strinx != -1)
		goto was_lt;	/* a match can be preceded by ces of a lesser dtp where some are dtp less and some are dtp match because they are any vecs.  So once there has been a lt, consider dtp lts also as lt so as to return the ce right before an eq even if this ce was dtp lt */
	      row_no += ce_rows;
	      goto next_ce;
	    }
	  if (DVC_DTP_GREATER == rc)
	    {
	      if (nth_key)
		{
		  itc->itc_ranges[set].r_end = first_in_range + row_no;
		  /* can be prev ce looked at this value and saw it after end.  If next ce is gt, then range is between end of prev and start of this. if range starts after the start of this, consider first_in_range */
		  if (!prev_ce)
		    itc->itc_ranges[set].r_first = first_in_range + row_no;
		}
	      else
		{
		  if (-1 != prev_strinx)
		    goto ret_prev;
		  itc_range (itc, row_no, row_no);
		  *is_last_ce = CE_RANGE_READY;
		  return NULL;
		}
	      goto ret_prev;
	    }
	  rc = 7 & ce_search_cmp (ce, first_in_range, value, dtp, itc);	/* and off the dvc dtp lt/gt.  dtp incompatible is checked before.  If dtp lt/gt here, does not disqualify because ce may is mixed dtps in that event */
	  if (DVC_LESS == rc)
	    {
	    was_lt:
	      prev_strinx = strinx;
	      prev_ce_inx = cinx;
	      prev_ce_row = row_no;
	      prev_ce = ce;
	      prev_ce_n_rows = ce_rows;
	      row_no += ce_rows;
	      continue;
	    }
	  if (DVC_MATCH == rc)
	    {
	      if (-1 != prev_strinx)
		goto ret_prev;
	      goto ret_this;
	    }
	  if (DVC_GREATER == rc)
	    {
	      if (nth_key)
		{
		  itc->itc_ranges[set].r_end = first_in_range + row_no;
		  /* can be that the previous ce had hits and also looked at this value and found that this value was after end.  If so, the first one looked at here is the next and this may start with a gt.  If so, null will be returned but we also know the start of the range */
		  if (!prev_ce)
		    itc->itc_ranges[set].r_first = first_in_range + row_no;
		  goto ret_prev;
		}
	      else
		{
		  if (-1 != prev_strinx)
		    goto ret_prev;
		  itc_range (itc, row_no, row_no);
		  *is_last_ce = CE_RANGE_READY;
		  return NULL;
		}
	    }
	next_ce:;
	}
      initial_ce_inx = 0;
    }
ret_prev:
  if (nth_key && -1 != prev_strinx && itc->itc_ranges[set].r_first >= prev_ce_row + prev_ce_n_rows)
    {
      /* prev ce was seen to be dtp lt.  If there is a current one return it, else null */
      if (strinx == cr->cr_n_pages && cinx == last_ce)
	{
	  *is_last_ce = CE_AFTER_LAST;
	  return NULL;
	}
      goto ret_this;
    }
  if (-1 == prev_strinx)
    {
      *is_last_ce = 0;
      if (strinx == cr->cr_n_pages && cinx == last_ce)
	*is_last_ce = CE_AFTER_LAST;
      else
	{
	  itc->itc_nth_col_string = strinx;
	  itc->itc_nth_ce = cinx;
	  itc->itc_row_of_ce = row_no;
	}
      return NULL;
    }
  itc->itc_nth_col_string = prev_strinx;
  itc->itc_nth_ce = prev_ce_inx;
  itc->itc_row_of_ce = prev_ce_row;
  *is_last_ce = itc_is_last_ce (itc, cr);
  return prev_ce;
ret_this:
  itc->itc_nth_col_string = strinx;
  itc->itc_nth_ce = cinx;
  itc->itc_row_of_ce = row_no;
  *is_last_ce = itc_is_last_ce (itc, cr);
  return ce;
}

int enable_ce_next_skip = 1;


db_buf_t
itc_next_ce_skip (it_cursor_t * itc, int * is_last_ce,   int64 value, dtp_t dtp, db_buf_t prev_ce)
{
  /* After getting next ce, if access pattern is sparse and next ce starts with lt, see the ce's after next to skip to last in range that starts with lt */
  int set = itc->itc_set - itc->itc_col_first_set;
  int nth_key = itc->itc_nth_key;
  page_map_t * pm;
  int strinx, cinx, rc, ce_rows;
  int prev_ce_row = itc->itc_row_of_ce, prev_strinx = itc->itc_nth_col_string, prev_ce_inx = itc->itc_nth_ce;
  col_data_ref_t * cr;
  row_no_t row_no = itc->itc_row_of_ce;
  row_no_t upper;
  db_buf_t ce;
  int last_ce = 0, initial_ce_inx;
  if (nth_key)
    upper = itc->itc_ranges[set].r_end;
  else 
    upper = COL_NO_ROW;
  cr = itc->itc_col_refs[nth_key];
  strinx = itc->itc_nth_col_string;
  initial_ce_inx = itc->itc_nth_ce + 2;
  row_no = itc->itc_row_of_ce;
  pm = cr->cr_pages[strinx].cp_map;
  ce_rows = pm->pm_entries[prev_ce_inx + 1];
  row_no += ce_rows;
  if (upper <= row_no)
    return prev_ce;
  for (strinx = itc->itc_nth_col_string; strinx < cr->cr_n_pages; strinx++)
    {
      db_buf_t page = cr->cr_pages[strinx].cp_string;
      pm = cr->cr_pages[strinx].cp_map;
      last_ce = strinx == cr->cr_n_pages - 1 ? cr->cr_limit_ce : pm->pm_count;
      for (cinx = initial_ce_inx; cinx < last_ce; cinx += 2)
	{
	  if (cinx + 2 < last_ce)
	    __builtin_prefetch (page + pm->pm_entries[cinx + 2]);
	  ce_rows = pm->pm_entries[cinx + 1];
	  ce = page + pm->pm_entries[cinx];
	  if (row_no + ce_rows >= upper)
	    {
	      if (DVC_MATCH != ce_dtp_compare (ce, dtp))
		goto ret_prev;
	      rc = ce_search_cmp (ce, 0, value, dtp, itc);
	      if (DVC_LESS == rc)
		goto ret_this;
	      goto ret_prev;
	    }
	  rc = ce_dtp_compare (ce, dtp);
	  if (DVC_MATCH != rc)
	    goto ret_prev;
	  rc = 7 & ce_search_cmp (ce, 0, value, dtp, itc); /* and off the dvc dtp lt/gt.  dtp incompatible is checked before.  If dtp lt/gt here, does not disqualify because ce may is mixed dtps in that event */
	  if (DVC_LESS == rc)
	    {
	      prev_strinx = strinx;
	      prev_ce_inx = cinx;
	      prev_ce_row = row_no;
	      prev_ce = ce;
	      row_no += ce_rows;
	      continue;
	    }
	  goto ret_prev;
	}
      initial_ce_inx = 0;
    }
 ret_prev:
  itc->itc_nth_col_string = prev_strinx;
  itc->itc_nth_ce = prev_ce_inx;
  itc->itc_row_of_ce = prev_ce_row;
  *is_last_ce = itc_is_last_ce (itc, cr);
  return prev_ce;
 ret_this:
  itc->itc_nth_col_string = strinx;
  itc->itc_nth_ce = cinx;
  itc->itc_row_of_ce = row_no;
  *is_last_ce = itc_is_last_ce (itc, cr);
  return ce;
}


db_buf_t
itc_next_ce (it_cursor_t * itc, int *is_last)
{
  int64 value;
  int rc;
  db_buf_t ce;
  dtp_t dtp;
  col_data_ref_t *cr = itc->itc_col_refs[itc->itc_nth_key];
  page_map_t *pm = cr->cr_pages[itc->itc_nth_col_string].cp_map;
  itc->itc_row_of_ce += pm->pm_entries[itc->itc_nth_ce + 1];
  if (itc->itc_nth_col_string == cr->cr_n_pages - 1 && itc->itc_nth_ce == cr->cr_limit_ce - 2)
    return NULL;
  if (itc->itc_nth_ce + 2 < pm->pm_count)
    {
      itc->itc_nth_ce += 2;
      ce = cr->cr_pages[itc->itc_nth_col_string].cp_string + pm->pm_entries[itc->itc_nth_ce];
    }
  else
    {
      if (itc->itc_nth_col_string + 1 >= cr->cr_n_pages)
	return NULL;
      itc->itc_nth_col_string++;
      itc->itc_nth_ce = 0;
      ce = cr->cr_pages[itc->itc_nth_col_string].cp_string + cr->cr_pages[itc->itc_nth_col_string].cp_map->pm_entries[0];
    }
  value = itc_ce_search_param (itc, itc->itc_nth_key, &dtp);
  rc = ce_dtp_compare (ce, dtp);
  if (DVC_DTP_GREATER == rc)
    return NULL;
  if (DVC_DTP_LESS == rc)
    {
      *is_last = itc_is_last_ce (itc, itc->itc_col_refs[itc->itc_nth_key]);
      return ce;
    }
  /* can be the next ce is dtp compatible but is delta-based (rld, bm, intd) with starting point above the param.  This is as good as incompatible dtp */
  rc = 7 & ce_search_cmp (ce, 0, value, dtp, itc);	/* and off the dvc dtp lt/gt.  dtp incompatible is checked before.  If dtp lt/gt here, does not disqualify because ce may is mixed dtps in that event */
  if (DVC_GREATER == rc)
    return NULL;
  *is_last = itc_is_last_ce (itc, itc->itc_col_refs[itc->itc_nth_key]);
  if (enable_ce_next_skip && DVC_LESS == rc && !*is_last)
    return itc_next_ce_skip (itc, is_last, value, dtp, ce); 
  return ce;
}


int
cr_n_rows (col_data_ref_t * cr)
{
  int p, r, rows = 0, n_ces = 0;
  for (p = 0; p < cr->cr_n_pages; p++)
    {
      page_map_t *pm = cr->cr_pages[p].cp_map;
      for (r = (0 == p ? cr->cr_first_ce * 2 : 0); r < pm->pm_count; r += 2)
	{
	  rows += pm->pm_entries[r + 1];
#ifdef PAGE_DEBUG
	  {
	    buffer_desc_t *buf = cr->cr_pages[p].cp_buf;
	    db_buf_t ce = buf->bd_buffer + pm->pm_entries[r];
	    int ce_cnt = ce_n_values (ce);
	    if (ce_cnt != pm->pm_entries[r + 1])
	      GPF_T1 ("pm and ce lengths do not match");
	  }
#endif
	  if (++n_ces == cr->cr_n_ces)
	    return rows;
	}
    }
  GPF_T1 ("less ces in seg than indicated in leaf col ref");
  return 0;
}


int
itc_rows_in_seg (it_cursor_t * itc, buffer_desc_t * buf)
{
  col_data_ref_t *cr;
  dbe_col_loc_t *cl;
  if (itc->itc_col_refs[0] || (!itc->itc_v_out_map || 0 == box_length (itc->itc_v_out_map)))
    {
      cr = itc->itc_col_refs[0];
      cl = &itc->itc_insert_key->key_row_var[0];
      if (!cr)
	cr = itc->itc_col_refs[0] = itc_new_cr (itc);
    }
  else
    {
      cl = &itc->itc_v_out_map[0].om_cl;
      cr = itc->itc_col_refs[cl->cl_nth - itc->itc_insert_key->key_n_significant];
    }
  if (!cr->cr_is_valid)
    itc_fetch_col (itc, buf, cl, 0, COL_NO_ROW);
  return cr_n_rows (cr);
}


int
cr_n_bytes (col_data_ref_t * cr)
{
  int p, r, b = 0, n_ces = 0;
  for (p = 0; p < cr->cr_n_pages; p++)
    {
      page_map_t *pm = cr->cr_pages[p].cp_map;
      for (r = (0 == p ? cr->cr_first_ce * 2 : 0); r < pm->pm_count; r += 2)
	{
	  db_buf_t ce = cr->cr_pages[p].cp_string + pm->pm_entries[r];
	  b += ce_total_bytes (ce);
	  if (++n_ces == cr->cr_n_ces)
	    return b;
	}
    }
  GPF_T1 ("less ces in seg than indicated in leaf col ref");
  return 0;
}


db_buf_t
itc_ce_at_row (it_cursor_t * itc, buffer_desc_t * buf, int *is_last_ce)
{
  int nth_key = itc->itc_nth_key, inx, cinx, row = 0;
  col_data_ref_t *cr;
  if (!(cr = itc->itc_col_refs[nth_key]) || !cr->cr_n_pages || !cr->cr_is_valid)
    itc_fetch_col (itc, buf, &itc->itc_insert_key->key_row_var[nth_key], 0, COL_NO_ROW);
  for (inx = 0; inx < cr->cr_n_pages; inx++)
    {
      page_map_t *pm = cr->cr_pages[inx].cp_map;
      int limit = cr->cr_n_pages - 1 == inx ? cr->cr_limit_ce : pm->pm_count;
      for (cinx = 0 == inx ? cr->cr_first_ce * 2 : 0; cinx < limit; cinx += 2)
	{
	  if (row <= itc->itc_col_row && row + pm->pm_entries[cinx + 1] > itc->itc_col_row)
	    {
	      itc->itc_nth_col_string = inx;
	      itc->itc_nth_ce = cinx;
	      itc->itc_row_of_ce = row;
	      *is_last_ce = itc_is_last_ce (itc, cr);
	      return cr->cr_pages[inx].cp_string + pm->pm_entries[cinx];
	    }
	  row += pm->pm_entries[cinx + 1];
	}
    }
  /*GPF_T1 ("row in col seg after last of seg"); */
  return NULL;
}

int enable_sp_stat = 2;


float
spst_selectivity (sp_stat_t * spst)
{
  if (0 == spst->spst_in)
    return 1;
  if (2 == enable_sp_stat)
    {
      return (float) spst->spst_time / (1 + spst->spst_in - spst->spst_out);
    }
  return (float) spst->spst_out / (float) spst->spst_in;
}

int
spst_cmp (const void *s1, const void *s2)
{
  float sel1 = spst_selectivity ((sp_stat_t *) s1);
  float sel2 = spst_selectivity ((sp_stat_t *) s2);
  return sel1 < sel2 ? -1 : sel1 == sel2 ? 0 : 1;
}


void
itc_sp_stat_check (it_cursor_t * itc)
{
  int n_orderable = itc->itc_n_row_specs - itc->itc_value_ret_hash_spec;
  int n;
  int n_in = itc->itc_sp_stat[0].spst_in;
  if (!enable_sp_stat)
    return;
  for (n = 0; n < n_orderable - 1; n++)
    {
      if (spst_selectivity (&itc->itc_sp_stat[n]) > spst_selectivity (&itc->itc_sp_stat[n + 1]))
	{
	  qsort (itc->itc_sp_stat, n_orderable, sizeof (sp_stat_t), spst_cmp);
	  break;
	}
    }
  if (n_in > 200000)
    {
      for (n = 0; n < itc->itc_n_row_specs; n++)
	itc->itc_sp_stat[n].spst_in = itc->itc_sp_stat[n].spst_out = itc->itc_sp_stat[n].spst_time = 0;
    }
}


void
itc_col_search (it_cursor_t * itc, buffer_desc_t * buf)
{
  col_data_ref_t *cr;
  search_spec_t *sp = itc->itc_key_spec.ksp_spec_array;
  int nth_key = 0, set_eq;
  int first_set = itc->itc_set, set;
  int is_last_ce;
  int rc = itc->itc_col_row == COL_NO_ROW ? CE_FIND_FIRST : CE_CONTINUES;
  db_buf_t ce;
  itc->itc_reset_after_seg = 0;
  if (COL_NO_ROW == itc->itc_col_row)
    itc->itc_range_fill = 0;
  else
    {
      itc->itc_range_fill = 1;
      itc->itc_ranges[0].r_first = itc->itc_col_row;
      itc->itc_ranges[0].r_end = COL_NO_ROW;
    }
  itc->itc_col_first_set = itc->itc_set;
  itc->itc_last_cmp_ce = NULL;
  if (!sp || CMP_EQ != sp->sp_min_op)
    {
      if (COL_NO_ROW == itc->itc_col_row)
	itc_range (itc, 0, COL_NO_ROW);
      return;
    }
  for (sp = sp; sp && CMP_EQ == sp->sp_min_op; sp = sp->sp_next)
    {
      itc->itc_nth_col_string = 0;
      itc->itc_nth_key = nth_key;
      itc->itc_col_spec = sp;
      itc->itc_row_of_ce = 0;
      cr = itc->itc_col_refs[nth_key];
      if (!cr->cr_is_valid)
	itc_fetch_col (itc, buf, &itc->itc_insert_key->key_row_var[nth_key], 0, COL_NO_ROW);
      itc->itc_nth_ce = cr->cr_first_ce * 2;
      if (COL_NO_ROW == itc->itc_col_row || itc->itc_set > first_set)
	{
	again:
	  rc = CE_FIND_FIRST;
	  if (nth_key > 0 && !itc->itc_range_fill)
	    GPF_T1 ("should have at least one range after 1st key");
	  set = itc->itc_set - first_set;
	  if (nth_key > 0 && set < itc->itc_range_fill && itc->itc_ranges[set].r_first == itc->itc_ranges[set].r_end)
	    goto next_set;
	  if (set >= itc->itc_range_fill && nth_key > 0)
	    goto next_key;
	  ce = itc_first_ce (itc, buf, &is_last_ce);
	  if (!ce)
	    {
	    no_first_ce:
	      if (0 == nth_key)
		{
		  if (CE_RANGE_READY == is_last_ce)
		    goto next_set;
		  if (first_set == itc->itc_set)
		    {
		      if (CE_AFTER_LAST == is_last_ce)
			{
			  int n_in_cr = cr_n_rows (cr);
			  itc_range (itc, n_in_cr, SM_INSERT == itc->itc_search_mode ? n_in_cr : COL_NO_ROW);
			  return;
			}
		      else
			{
			  itc_range (itc, 0, 0);
			  goto next_set;
			}
		    }
		  else
		    {
		      /* not first set, first key, no ce */
		      if (0 == is_last_ce)
			{
			  itc_range (itc, 0, 0);
			  goto next_set;
			}
		      if (CE_RANGE_READY == is_last_ce)
			goto next_set;
		      goto next_key;
		    }
		}
	      else
		{
		  /* no ce, not first key */
		  if (first_set == itc->itc_set)
		    {
		      if (CE_AFTER_LAST == is_last_ce)
			{
			  itc->itc_ranges[set].r_first = cr_n_rows (cr);
			  itc->itc_ranges[set].r_end =
			      SM_INSERT == itc->itc_search_mode ? itc->itc_ranges[set].r_first : COL_NO_ROW;
			  return;
			}
		      goto next_set;	/* the range end was set in itc_first_ce */
		    }
		  else
		    {
		      /* no ce, not first set, not first key */
		      if (CE_AFTER_LAST == is_last_ce)
			{
			  itc->itc_ranges[set].r_first = itc->itc_ranges[set].r_end = COL_NO_ROW;
			  itc->itc_range_fill--;
			  goto next_key;	/* hit beyond this range, must be first set to deduce non-existence of hit */
			}
		      goto next_set;	/* the range end was set in itc_first_set */
		    }
		}
	      GPF_T1 ("no ce in itc_col_search and no action taken");
	    }
	}
      else
	{
	  ce = itc_ce_at_row (itc, buf, &is_last_ce);
	  if (!ce)
	    {
	      set = itc->itc_set - itc->itc_col_first_set;
	      itc->itc_ranges[set].r_first = cr_n_rows (cr);
	      itc->itc_ranges[set].r_end = COL_NO_ROW;
	      return;
	    }
	  rc = CE_FIND_LAST;
	}
    search:
      rc = ce_search (itc, ce, itc->itc_row_of_ce, rc, nth_key);
      if (CE_SET_END == rc)
	goto next_key;
      if (itc->itc_reset_after_seg)
	{
	  if (itc->itc_set > first_set + 1)
	    GPF_T1 ("reset due to multi-seg range reoccurring should not be set expect after ffirst set of seg");
	  if (CE_CONTINUES != rc)
	    goto next_key;
	}
      if (CE_NEXT_SET == rc)
	goto next_set;

      set = itc->itc_set - first_set;
      if (set < itc->itc_range_fill && COL_NO_ROW == itc->itc_ranges[set].r_first)
	{
	  db_buf_t ce2;
	  rc = CE_FIND_FIRST;
	  if (is_last_ce)
	    {
	      /* target starts after this ce.  If at end of seg and 1st set here, this means that it does not exist.  If not 1st set, do random lookup.  If random lookup gives the same seg, then the 1st set of that seg will hit end and conclusion will be that the thing does not exist */
	      if (first_set == itc->itc_set)
		{
		  if (SM_INSERT == itc->itc_search_mode)
		    return;
		  itc->itc_ranges[set].r_first = itc->itc_row_of_ce + ce_n_values (ce);
		  itc->itc_ranges[set].r_end = SM_READ == itc->itc_search_mode ? COL_NO_ROW : itc->itc_ranges[set].r_first;
		  return;
		}
	      itc->itc_range_fill--;
	      goto next_key;
	    }
	  else
	    {
	      /* not found and not last ce */
	      int n_in_ce = cr->cr_pages[itc->itc_nth_col_string].cp_map->pm_entries[itc->itc_nth_ce + 1];
	      if (0 == nth_key)
		{
		  /* itc_first_ce may have returned one before the hit if nnext ce starts with an eq.  So look up the ce: Could be anywhere.  If getting the same, then take next.  If no ce then the hit is beyond this seg.  If non 1st key part and the next ce started with gt then the check above makes the range empty at end of present ce */
		  itc->itc_range_fill--;
		  ce2 = itc_first_ce (itc, buf, &is_last_ce);
		  if (ce == ce2)
		    {
		      int prev_ce_row = itc->itc_row_of_ce;
		      ce = itc_next_ce (itc, &is_last_ce);
		      if (!ce)
			{
			  /* no next and not last. Must be due to bad dtp.  End right after the prev ce */
			  itc_range (itc, prev_ce_row + n_in_ce, prev_ce_row + n_in_ce);
			  goto next_set;
			}
		      goto search;
		    }
		  ce = ce2;
		  if (ce)
		    goto search;
		  goto no_first_ce;
		}
	      else
		{
		  /* not first key, itc_first_ce may have returned one before the hit if nnext ce starts with an eq.  Alter the range to start after end of this ce and look in next.  The range at hand does overlap with this ce because if it did not ce_search would have returned done and not marked the range as starting with no row */
		  int prev_ce_row = itc->itc_row_of_ce;
		  if (itc->itc_row_of_ce + n_in_ce >= itc->itc_ranges[set].r_end)
		    {
		      /* itc_ce_first may have determined an upper bound or a range given by prior key part ends before the end of this ce.  Only for non-1st key parts */
		      itc->itc_ranges[set].r_first = itc->itc_ranges[set].r_end;
		      goto next_set;
		    }
		  itc->itc_ranges[set].r_first = prev_ce_row + n_in_ce;
		  ce = itc_next_ce (itc, &is_last_ce);
		  if (!ce)
		    {
		      /* no next and not last. Must be due to bad dtp.  End right after the prev ce */
		      itc->itc_ranges[set].r_first = itc->itc_ranges[set].r_end = prev_ce_row + n_in_ce;
		      goto next_set;
		    }
		  goto search;
		}
	    }
	  GPF_T1 ("should have decided where to go before now");
	}
      if (CE_CONTINUES == rc)
	{
	  int prev_ce_row, n_in_ce;
	  if (is_last_ce)
	    goto next_key;
	  prev_ce_row = itc->itc_row_of_ce;
	  n_in_ce = cr->cr_pages[itc->itc_nth_col_string].cp_map->pm_entries[itc->itc_nth_ce + 1];
	  if (itc->itc_ranges[set].r_end <= prev_ce_row + n_in_ce)
	    ce = NULL;
	  else
	    ce = itc_next_ce (itc, &is_last_ce);
	  if (!ce)
	    {
	      /* next ce was dtp incompatible.  Ends after last of prev */
	      itc->itc_ranges[set].r_end = prev_ce_row + n_in_ce;
	      goto next_set;
	    }
	  rc = CE_FIND_LAST;
	  goto search;
	}
      else
	{
	  if (is_last_ce)
	    goto next_key;
	  goto again;
	}
    next_key:
      nth_key++;
      rc = CE_FIND_FIRST;
      itc->itc_set = first_set;
    }
  return;
next_set:
  set = 1 + itc->itc_set - first_set;
  if (itc->itc_n_sets <= set + first_set)
    goto next_key;
  itc->itc_set++;
  set_eq = itc_next_set_cmp (itc, nth_key);
  if (SET_EQ_RESET == set_eq)
    {
      itc->itc_set--;
      itc->itc_reset_after_seg = 1;
      if (itc->itc_set > first_set + 1)
	GPF_T1 ("reset due to multi-seg range reoccurring should not be set expect after ffirst set of seg");
      goto next_key;
    }
  if (SET_ALL_EQ == set_eq)
    {
      if (0 == nth_key || set == itc->itc_range_fill)
	itc_range (itc, 0, 0);
      itc->itc_ranges[set].r_first = itc->itc_ranges[set - 1].r_first;
      itc->itc_ranges[set].r_end = itc->itc_ranges[set - 1].r_end;
      goto next_set;
    }
  if (0 == nth_key)
    goto again;
  if (nth_key && SET_LEADING_EQ == set_eq && itc->itc_range_fill == set)
    {
      /* non 1st key part opens new range because open ended in previous key parts */
      itc_range (itc, itc->itc_ranges[set - 1].r_end, COL_NO_ROW);
      goto again;
    }
  if (set == itc->itc_range_fill)
    goto next_key;
  goto again;
}


void
dc_wide_tags (data_col_t * dc, int from)
{
  int inx;
  if (DV_ANY != dc->dc_dtp)
    GPF_T1 ("a wide column must be returned in an any dc");
  for (inx = from; inx < dc->dc_n_values; inx++)
    {
      db_buf_t dv = ((db_buf_t *) dc->dc_values)[inx];
      if (DV_SHORT_STRING_SERIAL == dv[0])
	dv[0] = DV_WIDE;
      else if (DV_STRING == dv[0])
	dv[0] = DV_LONG_WIDE;
    }
}


void
dc_xml_entities (it_cursor_t * itc, dbe_col_loc_t * cl, data_col_t * dc, int from)
{
  int inx;
  if (!(DCT_BOXES & dc->dc_type))
    return;
  for (inx = from; inx < dc->dc_n_values; inx++)
    {
      caddr_t str = ((caddr_t *) dc->dc_values)[inx];
      caddr_t res;
      if (cl->cl_sqt.sqt_class)
	{
	  if (DV_OBJECT == DV_TYPE_OF (str))
	    continue;
	  res = udt_deserialize_from_blob (str, itc->itc_ltrx);
	}
      else
	res = xml_deserialize_from_blob (str, itc->itc_ltrx, itc->itc_out_state, NULL);

      ((caddr_t *) dc->dc_values)[inx] = res;
      dk_free_box (str);
    }
}

caddr_t *
itc_key_del_values (it_cursor_t * itc, buffer_desc_t * buf, int end, int n_used, int cinx)
{
  /* if a column in deleting ks needs to be logged but is not fetched fetch it with this as an array of boxes for the selected rows */
  int target, row, nth_page, r;
  data_col_t dc;
  col_pos_t cpo;
  dbe_key_t *key = itc->itc_insert_key;
  int n_keys = key->key_n_significant;
  dbe_col_loc_t *cl = &key->key_row_var[cinx];
  col_data_ref_t *cr = itc->itc_col_refs[cl->cl_nth - n_keys];
  if (!cr)
    cr = itc->itc_col_refs[cl->cl_nth - n_keys] = itc_new_cr (itc);
  if (!cr->cr_is_valid)
    itc_fetch_col (itc, buf, cl, 0, COL_NO_ROW);
  memzero (&dc, sizeof (dc));
  memzero (&cpo, sizeof (cpo));
  cpo.cpo_dc = &dc;
  dc.dc_values = dk_alloc_box (sizeof (caddr_t) * n_used, DV_ARRAY_OF_POINTER);
  dc.dc_dtp = DV_ARRAY_OF_POINTER;
  dc.dc_n_places = n_used;
  dc.dc_type = DCT_BOXES;
  cpo.cpo_cl = cl;
  cpo.cpo_itc = itc;
  cpo.cpo_value_cb = ce_result;
  if (!itc->itc_n_matches)
    cpo.cpo_range = &itc->itc_ranges[itc->itc_set - itc->itc_col_first_set];
  target = itc->itc_n_matches ? itc->itc_matches[0] : cpo.cpo_range->r_first;
  row = 0;
  itc->itc_match_in = 0;
  for (nth_page = 0; nth_page < cr->cr_n_pages; nth_page++)
    {
      page_map_t *pm = cr->cr_pages[nth_page].cp_map;
      int rows_on_page = 0;
      for (r = 0 == nth_page ? cr->cr_first_ce * 2 : 0; r < pm->pm_count; r += 2)
	{
	  int is_last = 0, end2, r2, ces_on_page;
	  if (row + pm->pm_entries[r + 1] <= target)
	    {
	      row += pm->pm_entries[r + 1];
	      continue;
	    }
	  if (itc->itc_n_matches ? row >= end : row >= cpo.cpo_range->r_end)
	    goto next_col;
	  ces_on_page = nth_page == cr->cr_n_pages - 1 ? cr->cr_limit_ce : pm->pm_count;
	  cpo.cpo_pm = pm;
	  cpo.cpo_pm_pos = r;
	  for (r2 = r; r2 < ces_on_page; r2 += 2)
	    rows_on_page += pm->pm_entries[r2 + 1];
	  end2 = MIN (end, row + rows_on_page);
	  if (end2 >= end)
	    is_last = 1;
	  cpo.cpo_ce_row_no = row;
	  cpo.cpo_string = cr->cr_pages[nth_page].cp_string + pm->pm_entries[r];
	  cpo.cpo_bytes = pm->pm_filled_to - pm->pm_entries[r];
	  target = cs_decode (&cpo, target, end2);
	  if (is_last || target >= end)
	    goto next_col;
	  break;
	}
      row += rows_on_page;
    }
next_col:;
  return (caddr_t *) dc.dc_values;
}


#if 1
#define CK_LOCK(itc, r)
#else
#define CK_LOCK(itc, r) \
  { int i1 = 0, i2 = 0; if (!itc_clk_at (itc, r, &i1, &i2)) GPF_T1 ("no lock at position returned as upd place");}
#endif

void
itc_col_placeholders (it_cursor_t * itc, buffer_desc_t * buf, int n_used)
{
  caddr_t *inst = itc->itc_out_state;
  table_source_t *ts = itc->itc_ks->ks_ts;
  data_col_t *dc = QST_BOX (data_col_t *, inst, ts->ts_current_of->ssl_index);
  int inx;
  if (!buf->bd_is_write)
    GPF_T1 ("cannot set a placeholder without write access on buffer");
  DC_CHECK_LEN (dc, dc->dc_n_values + n_used - 1);
  itc->itc_is_on_row = 1;
  if (itc->itc_n_matches)
    {
      for (inx = 0; inx < n_used; inx++)
	{
	  placeholder_t *pl = plh_landed_copy ((placeholder_t *) itc, buf);
	  pl->itc_col_row = itc->itc_matches[inx];
	  CK_LOCK (itc, pl->itc_col_row);
	  ((placeholder_t **) dc->dc_values)[dc->dc_n_values++] = pl;
	}
    }
  else
    {
      int start = itc->itc_ranges[itc->itc_set - itc->itc_col_first_set].r_first;
      for (inx = 0; inx < n_used; inx++)
	{
	  placeholder_t *pl = plh_landed_copy ((placeholder_t *) itc, buf);
	  pl->itc_col_row = start + inx;
	  CK_LOCK (itc, pl->itc_col_row);
	  ((placeholder_t **) dc->dc_values)[dc->dc_n_values++] = pl;
	}
    }
}


col_row_lock_t *
itc_clk_at (it_cursor_t * itc, row_no_t pos, row_no_t * point, row_no_t * next_ret)
{
  /* find col row lock in rl.  Binary search if nostarting point, else sequential from starting point.  Return the position of the col lock in rl_cols in *point and the row no of the next one in *next */
  int inx;
  row_lock_t *rl = itc->itc_rl;
  int below = rl->rl_n_cols;
  int at_or_above = *point;
  col_row_lock_t **clks = rl->rl_cols, *clk;
  if (at_or_above == below)
    {
      *point = 0;
      *next_ret = COL_NO_ROW;
      return NULL;
    }
  if (0 == at_or_above)
    {
      int guess, end = below;
      for (;;)
	{
	  if (below - at_or_above <= 1)
	    {
	      if (pos == clks[at_or_above]->clk_pos)
		{
		  *point = at_or_above;
		  *next_ret = at_or_above + 1 < end ? clks[at_or_above + 1]->clk_pos : COL_NO_ROW;
		  return clks[at_or_above];
		}
	      if (pos < clks[at_or_above]->clk_pos)
		{
		  *point = at_or_above;
		  *next_ret = clks[at_or_above]->clk_pos;
		  return NULL;
		}
	      *point = at_or_above;
	      *next_ret = at_or_above + 1 < end ? clks[at_or_above + 1]->clk_pos : COL_NO_ROW;
	      return NULL;
	    }
	  guess = (at_or_above + below) / 2;
	  clk = clks[guess];
	  if (pos == clk->clk_pos)
	    {
	      *point = guess;
	      *next_ret = (guess + 1) < end ? clks[guess + 1]->clk_pos : COL_NO_ROW;
	      return clk;
	    }
	  if (clk->clk_pos > pos)
	    below = guess;
	  else
	    at_or_above = guess;
	}
    }

  for (inx = at_or_above; inx < below; inx++)
    {
      col_row_lock_t *clk = rl->rl_cols[inx];
      int clk_pos = clk->clk_pos;
      if (pos > clk_pos)
	continue;
      if (pos == clk_pos)
	{
	  *point = inx;
	  if (inx + 1 < below)
	    *next_ret = rl->rl_cols[inx + 1]->clk_pos;
	  else
	    *next_ret = COL_NO_ROW;
	  return clk;
	}
      *point = inx;
      *next_ret = clk->clk_pos;
      return NULL;
    }
  *next_ret = COL_NO_ROW;
  *point = below;
  return NULL;
}


int
itc_row_visible (it_cursor_t * itc, col_row_lock_t * clk)
{
  if (!clk->clk_change)
    return 1;
  if (CLK_INSERTED & clk->clk_change && !LT_SEES_EFFECT (itc->itc_ltrx, clk->pl_owner))
    return 0;
  if (CLK_DELETE_AT_COMMIT & clk->clk_change)
    {
      int visible = !LT_SEES_EFFECT (itc->itc_ltrx, clk->pl_owner);
      if (visible && clk->clk_rbe)
	itc->itc_col_need_preimage = 1;
      return visible;
    }
  if ((CLK_REVERT_AT_ROLLBACK & clk->clk_change) && !LT_SEES_EFFECT (itc->itc_ltrx, clk->pl_owner))
    {
      itc->itc_col_need_preimage = 1;
      return 1;
    }
  return 1;
}

row_no_t *itc_opt_extend_matches (it_cursor_t * itc, int n_more);
int *itc_opt_extend_sets (it_cursor_t * itc, data_source_t * qn, caddr_t * inst, int sets_fill, int n_more, int max_sets,
    int *is_extended);


#define CHECK_SETS(n_more) \
  if (sets_max < sets_fill + n_more) {				\
  int is_extended = 1; \
  sets = itc_opt_extend_sets (itc, qn, inst, sets_fill, n_more, sets_max, &is_extended); \
  if (!is_extended) goto end_of_batch; \
    sets_max = box_length (sets) / sizeof (int); }

#define CHECK_MATCHES(n_more) \
  if (matches_max <= match_fill + n_more) {				\
    matches = itc_opt_extend_matches (itc, n_more); \
    matches_max = itc->itc_match_sz; }		    \



int
itc_matches_by_locks (it_cursor_t * itc, buffer_desc_t * buf, int *n_rows_ret)
{
  /* set itc matches so that uncommitted inserts of others are out and uncommitted deletes of self are out.  If preimages are needed, set the preimages flag. */
  row_no_t *matches = itc->itc_matches;
  int matches_max, match_fill = 0, row, any_skipped = 0;
  data_source_t *qn = (data_source_t *) itc->itc_ks->ks_ts;
  caddr_t *inst = itc->itc_out_state;
  int *sets = QST_BOX (int *, inst, qn->src_sets);
  int sets_max = box_length (sets) / sizeof (int32);
  int sets_fill = itc->itc_n_results;
  row_no_t next = 0;
  row_no_t point = 0;
  row_range_t rng = itc->itc_ranges[itc->itc_set - itc->itc_col_first_set];
  col_row_lock_t *clk = itc_clk_at (itc, rng.r_first, &point, &next);
  itc->itc_col_need_preimage = 0;
  if (COL_NO_ROW == rng.r_end)
    {
      rng.r_end = itc_rows_in_seg (itc, buf);
      if (n_rows_ret)
	*n_rows_ret = rng.r_end;
    }
  itc->itc_n_matches = 0;
  if (!clk && rng.r_end <= next)
    {
      return 1;
    }
  if (!matches)
    itc->itc_matches = matches = (row_no_t *) itc_alloc_box (itc, (200 + rng.r_end - rng.r_first) * sizeof (row_no_t), DV_BIN);
  matches_max = box_length (matches) / sizeof (row_no_t);
  for (row = rng.r_first; row < rng.r_end; row++)
    {
      int visible;
      clk = itc_clk_at (itc, row, &point, &next);
      if (!clk && !any_skipped)
	continue;
      visible = !clk || itc_row_visible (itc, clk);
      if (!visible && any_skipped)
	continue;
      if (visible && !any_skipped)
	continue;
      if (!visible && any_skipped)
	continue;
      if (!any_skipped && !visible)
	{
	  int r2;
	  CHECK_SETS (row - rng.r_first);
	  CHECK_MATCHES (row - rng.r_first);
	  any_skipped = 1;
	  for (r2 = rng.r_first; r2 < row; r2++)
	    {
	      itc->itc_matches[match_fill++] = r2;
	      sets[sets_fill++] = itc->itc_param_order[itc->itc_set];
	    }
	  continue;
	}
      CHECK_SETS (1);
      CHECK_MATCHES (1);
      sets[sets_fill++] = itc->itc_param_order[itc->itc_set];
      matches[match_fill++] = row;
    }
end_of_batch:
  if (any_skipped)
    {
      itc->itc_n_matches = match_fill;
      if (!match_fill)
	return 0;
    }
  return 1;
}


void
itc_filter_sets_reconcile (it_cursor_t * itc, int from_set, int from_match)
{
  /* Looky fucky.  Ranges are represented as row nos. Multi-row ranges are non-overlapping.  Single row ranges may repeat.  Some rows from the ranges have been fileterd out.  Now figure for each remaining row what set it came from.
   *  At the end set itc_set to be the set of the last selected row.  So if ended with a single row set, the range inx is incremented and is one too high.  If ended in middle of a multi-row range, the range inx is right */
  int ended_with_single = 0;
  int sets_fill = QST_INT (itc->itc_out_state, itc->itc_ks->ks_ts->src_gen.src_out_fill);
  int range_inx = from_set;
  int match_inx = 0;
  int *sets = QST_BOX (int *, itc->itc_out_state, itc->itc_ks->ks_ts->src_gen.src_sets);
  row_no_t *matches = itc->itc_matches;
  row_range_t *ranges = itc->itc_ranges;
  int n_matches = itc->itc_n_matches;
  while (match_inx < n_matches)
    {
      if (matches[match_inx] >= ranges[range_inx].r_end)
	{
	  range_inx++;
	  continue;
	}
      if (!(matches[match_inx] >= ranges[range_inx].r_first && matches[match_inx] < ranges[range_inx].r_end))
	GPF_T1 ("sets reconciliation out of whack, a match must always be inside in a range");
      sets[sets_fill++] = itc->itc_param_order[itc->itc_col_first_set + range_inx];
      match_inx++;
      if (1 == ranges[range_inx].r_end - ranges[range_inx].r_first)
	{
	  range_inx++;
	  ended_with_single = 1;
	  continue;
	}
      ended_with_single = 0;
    }
  itc->itc_set = range_inx + itc->itc_col_first_set - ended_with_single;
}


int allow_non_unq_range = 0;
int non_unq_printed = 0;

#define NON_UNQ_RANGE \
{ \
  if (allow_non_unq_range) \
    { \
  if (!non_unq_printed) \
    { \
      non_unq_printed = 1;		     \
      log_error ("non unq range for unq ts key %s slice %d page %d pos %d", itc->itc_insert_key->key_name, itc->itc_tree->it_slice, itc->itc_page, itc->itc_map_pos); \
      } \
      bing (); \
      WAIT_IF (allow_non_unq_range);; \
    } \
  else \
    GPF_T1 ("for unique ts, getting range with more than 1 rows"); \
}

extern int dbf_ignore_uneven_col;

int
itc_col_seg (it_cursor_t * itc, buffer_desc_t * buf, int is_singles, int n_sets_in_singles)
{
  col_data_ref_t *cr;
  col_pos_t cpo;
  search_spec_t *sp;
  data_col_t *prev_dc = NULL;
  row_range_t rng;
  int n_keys = itc->itc_insert_key->key_n_significant, n_out, row, n, init_out_dc_fill;
  int col_inx, n_used, stop_in_mid_seg = 0, nth_page, r, target;
  int end, rows_in_seg = -1;
  int initial_set = itc->itc_set, initial_n_matches = 0, nth_sp;
  int64 check_start_ts = 0;
  //memzero (&cpo, sizeof (cpo));
  cpo.cpo_range = &itc->itc_ranges[itc->itc_set - itc->itc_col_first_set];
  if (!is_singles && itc->itc_rl)
    {
      if (itc_matches_by_locks (itc, buf, &rows_in_seg))
	{
	  if (itc->itc_n_matches)
	    {
	      itc->itc_ltrx->lt_client->cli_activity.da_seq_rows += itc->itc_n_matches;
	      is_singles = 1 | ((itc->itc_set - itc->itc_col_first_set) << 1);
	      n_sets_in_singles = 1;
	    }
	}
      else
	{
	  itc->itc_col_row = 0;	/* start at 0 on next pagge, nothing here */
	return DVC_LESS;
    }
    }
  if (!is_singles)
    {
      n = cpo.cpo_range->r_end - cpo.cpo_range->r_first;
      itc->itc_n_matches = 0;
      if (ISO_SERIALIZABLE == itc->itc_isolation)
	{
	  if (COL_NO_ROW == cpo.cpo_range->r_end)
	    {
	      rows_in_seg = itc_rows_in_seg (itc, buf);
	      n = rows_in_seg - cpo.cpo_range->r_first;
	    }
	  if (itc->itc_batch_size - itc->itc_n_results < n)
	    n = itc->itc_batch_size - itc->itc_n_results;
	  itc_col_lock (itc, buf, n, !itc->itc_row_specs);
	}
      if (n <= 0)
	{
	  itc->itc_col_row = 0;
	return DVC_LESS;
	}
      if (COL_NO_ROW == cpo.cpo_range->r_end)
	itc->itc_is_multiseg_set = 1;
      if (n > 1 && cpo.cpo_range->r_end != COL_NO_ROW && itc->itc_ks && itc->itc_ks->ks_ts->ts_is_unique)
	NON_UNQ_RANGE;
    }
  else
    {
      initial_n_matches = itc->itc_n_matches;
      rng.r_first = itc->itc_matches[0];
      rng.r_end = itc->itc_matches[itc->itc_n_matches - 1] + 1;
      cpo.cpo_range = &rng;
    }
  cpo.cpo_itc = itc;
  cpo.cpo_value_cb = ce_filter;
  itc->itc_match_in = 0;
  if (!is_singles)
    itc->itc_n_matches = 0;
  for (nth_sp = 0; nth_sp < itc->itc_n_row_specs; nth_sp++)
    {
      int row = 0;
      sp = itc->itc_sp_stat[nth_sp].spst_sp;
      itc->itc_is_last_col_spec = nth_sp == itc->itc_n_row_specs - 1;
      if (!itc->itc_n_matches)
	target = cpo.cpo_range->r_first;
      else
	target = itc->itc_matches[0];
      cpo.cpo_clk_inx = 0;
      cpo.cpo_cl = &sp->sp_cl;
      cpo.cpo_ce_op = ce_op[(sp->sp_col_filter << 1) + (itc->itc_n_matches > 0)];
      itc->itc_col_spec = sp;
      cpo.cpo_min_op = sp->sp_min_op;
      cpo.cpo_max_op = sp->sp_max_op;
      itc->itc_match_out = 0;
      if (cpo.cpo_min_op != CMP_NONE)
	{
	  if (CMP_HASH_RANGE == cpo.cpo_min_op)
	    {
	      caddr_t *inst = itc->itc_out_state;
	      hash_range_spec_t *hrng = (hash_range_spec_t *) sp->sp_min_ssl;
	      if (hrng->hrng_ht_id)
		{
		  index_tree_t *it = qst_get_chash (inst, hrng->hrng_ht, hrng->hrng_ht_id, NULL);
		  cpo.cpo_chash = it->it_hi->hi_chash;
		  cpo.cpo_chash_dtp = cpo.cpo_chash->cha_sqt[0].sqt_dtp;
		}
	      else if (hrng->hrng_hs)
		{
		  cpo.cpo_chash = QST_BOX (index_tree_t *, inst, hrng->hrng_hs->hs_ha->ha_tree->ssl_index)->it_hi->hi_chash;
		  cpo.cpo_chash_dtp = cpo.cpo_chash->cha_sqt[0].sqt_dtp;
		}
	      else if (hrng->hrng_ht)
		{
		  cpo.cpo_chash = QST_BOX (index_tree_t *, inst, hrng->hrng_ht->ssl_index)->it_hi->hi_chash;
		  cpo.cpo_chash_dtp = cpo.cpo_chash->cha_sqt[0].sqt_dtp;
		}
	      else
		{
		  cpo.cpo_max_op = CMP_HASH_RANGE_ONLY;
		  cpo.cpo_chash = NULL;
		  cpo.cpo_chash_dtp = sp->sp_cl.cl_sqt.sqt_col_dtp;
		}
	      cpo.cpo_cmp_max = (caddr_t) hrng->hrng_hs;
	      cpo.cpo_hash_min = QST_INT (inst, hrng->hrng_min);
	      cpo.cpo_hash_max = QST_INT (inst, hrng->hrng_max);
	    }
	  else
	    cpo.cpo_cmp_min = itc->itc_search_params[sp->sp_min];
	  cpo.cpo_min_spec = sp;
	}
      if (cpo.cpo_max_op != CMP_NONE)
	cpo.cpo_cmp_max = itc->itc_search_params[sp->sp_max];
      cr = itc->itc_col_refs[sp->sp_cl.cl_nth - n_keys];
      if (!cr->cr_is_valid)
	itc_fetch_col (itc, buf, &sp->sp_cl, 0, COL_NO_ROW);
      if (-1 == rows_in_seg)
	{
	  rows_in_seg = cr_n_rows (cr);
	  if (!is_singles)
	    {
	      itc->itc_rows_selected += MIN (rows_in_seg, cpo.cpo_range->r_end) - cpo.cpo_range->r_first - 1;
	      if (cpo.cpo_range->r_first >= rows_in_seg)
		{
		  itc->itc_is_multiseg_set = 0;
		  itc->itc_col_row = 0;
		  return DVC_LESS;
		}
	    }
	}
      if (0 == itc->itc_n_matches && itc->itc_match_sz < rows_in_seg)
	{
	  if (itc->itc_matches)
	    itc_free_box (itc, (caddr_t) itc->itc_matches);
	  itc->itc_match_sz = rows_in_seg + 400;
	  itc->itc_matches = (row_no_t *) itc_alloc_box (itc, sizeof (row_no_t) * itc->itc_match_sz, DV_BIN);
	}
      if (itc->itc_n_row_specs > 1)
	{
	  check_start_ts = rdtsc ();
	  if (!itc->itc_n_matches && !is_singles)
	    itc->itc_sp_stat[nth_sp].spst_in += MIN (rows_in_seg, cpo.cpo_range->r_end) - cpo.cpo_range->r_first;
	  else
	    itc->itc_sp_stat[nth_sp].spst_in += itc->itc_n_matches;
	}
      for (nth_page = 0; nth_page < cr->cr_n_pages; nth_page++)
	{
	  int limit;
	  page_map_t *pm = cr->cr_pages[nth_page].cp_map;
	  for (r = 0 == nth_page ? cr->cr_first_ce * 2 : 0; r < pm->pm_count; r += 2)
	    {
	      int ce_rows = pm->pm_entries[r + 1];
	      if (row + ce_rows <= target)
		{
		  row += ce_rows;
		  continue;
		}
	      if (row >= cpo.cpo_range->r_end || row >= rows_in_seg)
		goto next_spec;
	      cpo.cpo_ce_row_no = row;
	      cpo.cpo_string = cr->cr_pages[nth_page].cp_string + pm->pm_entries[r];
	      cpo.cpo_pm = pm;
	      cpo.cpo_pm_pos = r;
	      cpo.cpo_bytes = pm->pm_filled_to - pm->pm_entries[r];
	      limit = nth_page == cr->cr_n_pages - 1 ? cr->cr_limit_ce : pm->pm_count;
	      for (r = r; r < limit; r += 2)
		row += pm->pm_entries[r + 1];
	      end = MIN (row, cpo.cpo_range[0].r_end);
	      target = cs_decode (&cpo, target, end);
	      if (target >= cpo.cpo_range[0].r_end)
		goto next_spec;
	      goto next_page;
	    }
	next_page:;
	}
    next_spec:
      if (itc->itc_n_row_specs > 1)
	{
	  itc->itc_sp_stat[nth_sp].spst_out += itc->itc_match_out;
	  itc->itc_sp_stat[nth_sp].spst_time += rdtsc () - check_start_ts;
	}
      if (itc->itc_match_out <= 0)
	{
	  itc->itc_col_row = 0;
	  if (is_singles)
	    itc->itc_set += n_sets_in_singles - 1;
	  return DVC_LESS;
	}
      itc->itc_n_matches = itc->itc_match_out;
      itc->itc_match_in = 0;
    }
  itc->itc_is_last_col_spec = 0;
  if (itc->itc_n_row_specs > 1 && itc->itc_sp_stat[0].spst_in > 10000)
    itc_sp_stat_check (itc);
  if (RANDOM_SEARCH_COND == itc->itc_random_search)
    return DVC_LESS;
  n_out = itc->itc_v_out_map ? box_length (itc->itc_v_out_map) / sizeof (v_out_map_t) : 0;
  if (itc->itc_n_matches)
    {
      n_used = itc->itc_n_matches;
      if (n_used >= itc->itc_batch_size - itc->itc_n_results)
	{
	  n_used = itc->itc_batch_size - itc->itc_n_results;
	  itc->itc_col_row = itc->itc_matches[n_used - 1];
	  itc->itc_n_matches = n_used;
	  stop_in_mid_seg = 1;
	}
      end = itc->itc_matches[n_used - 1] + 1;
    }
  else
    {
      if (COL_NO_ROW == cpo.cpo_range->r_end)
	{
	  if (-1 == rows_in_seg)
	    rows_in_seg = itc_rows_in_seg (itc, buf);
	  if (cpo.cpo_range->r_first >= rows_in_seg)
	    itc->itc_is_multiseg_set = 0;
	  end = rows_in_seg;
	}
      else
	end = cpo.cpo_range->r_end;
      n_used = end - cpo.cpo_range->r_first;
      if (n_used < 0)
	{
	  bing ();
	  n_used = 0;
	}
      if (n_used >= itc->itc_batch_size - itc->itc_n_results)
	{
	  stop_in_mid_seg = 1;
	  n_used = itc->itc_batch_size - itc->itc_n_results;
	}
      end = cpo.cpo_range->r_first + n_used;
      itc->itc_col_row = end - 1;
      itc->itc_rows_selected = end - cpo.cpo_range->r_first - 1;
    }
  if (!is_singles)
    {
      int range_end;
      if (stop_in_mid_seg)
	range_end = itc->itc_col_row;
      else if (COL_NO_ROW != cpo.cpo_range->r_end)
	range_end = cpo.cpo_range->r_end;
      else
	range_end = -1 != rows_in_seg ? rows_in_seg : (rows_in_seg = itc_rows_in_seg (itc, buf));
      itc->itc_ltrx->lt_client->cli_activity.da_seq_rows += range_end - cpo.cpo_range->r_first - 1;
    }
  init_out_dc_fill = itc->itc_n_results;
  itc->itc_n_results += n_used;
  itc->itc_insert_key->key_touch += n_used;
  if (itc->itc_n_results < 0)
    GPF_T1 ("neg n_results");
  if (!n_used)
    {
      if (itc->itc_n_results < itc->itc_batch_size)
	itc->itc_col_row = 0;
      return DVC_LESS;
    }
  {
    data_source_t *qn = (data_source_t *) itc->itc_ks->ks_ts;
    int fill = QST_INT (itc->itc_out_state, qn->src_out_fill);
    int *sets = QST_BOX (int *, itc->itc_out_state, qn->src_sets);
    if (fill + n_used > box_length (sets) / sizeof (int))
      sets = qn_extend_sets (qn, itc->itc_out_state, fill + n_used);
    if (!is_singles)
      int_fill (&sets[fill], itc->itc_param_order[initial_set], n_used);
    else
      {
	if (stop_in_mid_seg)
	  itc_filter_sets_reconcile (itc, is_singles >> 1, initial_n_matches);
	else if (itc->itc_n_matches < initial_n_matches)
	  {
	    int save_set = itc->itc_set;
	    itc_filter_sets_reconcile (itc, is_singles >> 1, initial_n_matches);
	    itc->itc_set = save_set + n_sets_in_singles - 1;
	  }
	else
	  itc->itc_set += n_sets_in_singles - 1;
      }
    QST_INT (itc->itc_out_state, qn->src_out_fill) = fill + n_used;
  }
  if (itc->itc_n_results == itc->itc_batch_size)
    stop_in_mid_seg = 1;
  cpo.cpo_value_cb = ce_result;
  if (ISO_REPEATABLE == itc->itc_isolation || (ISO_COMMITTED == itc->itc_isolation && PL_EXCLUSIVE == itc->itc_lock_mode)
      || (ISO_SERIALIZABLE == itc->itc_isolation && itc->itc_row_specs))
    {
      if (!itc->itc_n_matches && -1 == rows_in_seg)
	rows_in_seg = itc_rows_in_seg (itc, buf);
      itc_col_lock (itc, buf, n_used, 1);
    }
  for (col_inx = 0; col_inx < n_out; col_inx++)
    {
      v_out_map_t *om = &itc->itc_ks->ks_v_out_map[col_inx];
      col_data_ref_t *cr = itc->itc_col_refs[om->om_cl.cl_nth - n_keys];
      if (!cr->cr_is_valid)
	itc_fetch_col (itc, buf, &om->om_cl, 0, COL_NO_ROW);
      cpo.cpo_clk_inx = 0;
      cpo.cpo_dc = QST_BOX (data_col_t *, itc->itc_out_state, om->om_ssl->ssl_index);
      if (!cpo.cpo_dc->dc_sqt.sqt_col_dtp)
	GPF_T1 ("a dc fetched from a column must have a col dtp set");
      cpo.cpo_cl = &om->om_cl;
      cpo.cpo_ce_op = ce_op[(om->om_ce_op << 1) + (itc->itc_n_matches > 0)];
      DC_CHECK_LEN (cpo.cpo_dc, cpo.cpo_dc->dc_n_values + n_used - 1);
      target = itc->itc_n_matches ? itc->itc_matches[0] : cpo.cpo_range->r_first;
      row = 0;
      itc->itc_match_in = 0;
      for (nth_page = 0; nth_page < cr->cr_n_pages; nth_page++)
	{
	  page_map_t *pm = cr->cr_pages[nth_page].cp_map;
	  int rows_on_page = 0;
	  for (r = 0 == nth_page ? cr->cr_first_ce * 2 : 0; r < pm->pm_count; r += 2)
	    {
	      int is_last = 0, end2, r2, ces_on_page, prev_fill;
	      if (row + pm->pm_entries[r + 1] <= target)
		{
		  row += pm->pm_entries[r + 1];
		  continue;
		}
	      if (row >= cpo.cpo_range->r_end)
		goto next_col;
	      ces_on_page = nth_page == cr->cr_n_pages - 1 ? cr->cr_limit_ce : pm->pm_count;
	      cpo.cpo_pm = pm;
	      cpo.cpo_pm_pos = r;
	      for (r2 = r; r2 < ces_on_page; r2 += 2)
		rows_on_page += pm->pm_entries[r2 + 1];
	      end2 = MIN (end, row + rows_on_page);
	      if (end2 >= end)
		is_last = 1;
	      cpo.cpo_ce_row_no = row;
	      cpo.cpo_string = cr->cr_pages[nth_page].cp_string + pm->pm_entries[r];
	      cpo.cpo_bytes = pm->pm_filled_to - pm->pm_entries[r];
	      prev_fill = cpo.cpo_dc->dc_n_values;
	      target = cs_decode (&cpo, target, end2);
	      if (DV_WIDE == cpo.cpo_cl->cl_sqt.sqt_col_dtp)
		dc_wide_tags (cpo.cpo_dc, prev_fill);
	      else if (cpo.cpo_cl->cl_sqt.sqt_is_xml || cpo.cpo_cl->cl_sqt.sqt_class)
		dc_xml_entities (itc, cpo.cpo_cl, cpo.cpo_dc, prev_fill);
	      if (is_last || target >= end)
		goto next_col;
	      break;
	    }
	  row += rows_on_page;
	}
    next_col:;
      if (cpo.cpo_dc->dc_n_values > cpo.cpo_dc->dc_n_places)
	GPF_T1 ("filled dc past end");
      if (prev_dc && prev_dc->dc_n_values != cpo.cpo_dc->dc_n_values)
	{
	  log_error ("Uneven column value count in search, key %s slice %d dp %d seg %d  -- previos has %d this has %d",
	      itc->itc_insert_key->key_name, itc->itc_tree->it_slice, itc->itc_page, itc->itc_map_pos, prev_dc->dc_n_values,
	      cpo.cpo_dc->dc_n_values);
	  if (!dbf_ignore_uneven_col)
	GPF_T1 ("finding in col seg that cols of same seg have different no of values");
	}
      prev_dc = cpo.cpo_dc;
    }
  if (itc->itc_ks->ks_is_vec_plh)
    itc_col_placeholders (itc, buf, n_used);
  itc->itc_is_on_row = 1;
  if (itc->itc_ks->ks_is_deleting && REPL_NO_LOG != itc->itc_ltrx->lt_replicate
      && (itc->itc_insert_key->key_is_primary || (CL_RUN_LOCAL != cl_run_local_only && itc->itc_insert_key->key_partition))
      && !IS_QN (itc->itc_ks->ks_ts, delete_node_input))
    {				/* log delete if pk and if not coming from delete node.  Deleting read of pk not from del node will always select all secondary index keys */
      int nth = 0, inx = 0, save_set = ((query_instance_t *) (itc->itc_out_state))->qi_set;
      dbe_key_t *key = itc->itc_ks->ks_key;
      v_out_map_t *ks_om = &itc->itc_ks->ks_v_out_map[nth];
      v_out_map_t om[10];
      caddr_t *key_vals[10];
      LOCAL_RD (rd);
      rd.rd_key = key;
      rd.rd_itc = itc;
      DO_SET (dbe_column_t *, col, &key->key_parts)
      {
	int cinx;
	for (cinx = 0; cinx < n_out; cinx++)
	  {
	    if (ks_om[cinx].om_cl.cl_col_id == col->col_id)
	      {
		om[inx] = ks_om[cinx];
		goto om_found;
	      }
	  }
	om[inx].om_ssl = NULL;
	key_vals[inx] = itc_key_del_values (itc, buf, end, n_used, inx);
      om_found:
	if (++inx >= key->key_n_significant)
	  break;
      }
      END_DO_SET ();
      /* loop from initial set to n to get all dc values */
      for (inx = 0; inx < n_used; inx++)
	{
	  for (nth = 0; nth < n_keys; nth++)
	    {
	      if (om[nth].om_ssl)
		{
		  ((query_instance_t *) (itc->itc_out_state))->qi_set = inx + init_out_dc_fill;
		  rd.rd_values[key->key_part_cls[nth]->cl_nth] = QST_GET (itc->itc_out_state, om[nth].om_ssl);
		}
	      else
		rd.rd_values[key->key_part_cls[nth]->cl_nth] = key_vals[nth][inx];
	    }
	  rd.rd_n_values = nth;
	  log_delete (itc->itc_ltrx, &rd, itc->itc_insert_key->key_partition ? LOG_KEY_ONLY : 0);
	}
      ((query_instance_t *) (itc->itc_out_state))->qi_set = save_set;
      for (nth = 0; nth < n_keys; nth++)
	{
	  if (!om[nth].om_ssl)
	    dk_free_box (key_vals[nth]);
	}
    }
  if (!stop_in_mid_seg)
    {
      cpo.cpo_range->r_first = 0;
      itc->itc_col_row = 0;
      return DVC_LESS;
    }
  return DVC_MATCH;
}


int enable_col_set_merge = 1;


row_no_t *
itc_opt_extend_matches (it_cursor_t * itc, int n_more)
{
  row_no_t *matches;
  int prev_sz = box_length (itc->itc_matches) / sizeof (row_no_t);
  int new_sz = prev_sz * 2 + n_more;
  matches = (row_no_t *) itc_alloc_box (itc, new_sz * sizeof (row_no_t), DV_BIN);
  memcpy (matches, itc->itc_matches, prev_sz * sizeof (row_no_t));
  itc_free_box (itc, (caddr_t) itc->itc_matches);
  itc->itc_match_sz = new_sz;
  return itc->itc_matches = matches;
}


int *
itc_opt_extend_sets (it_cursor_t * itc, data_source_t * qn, caddr_t * inst, int sets_fill, int n_more, int max_sets,
    int *is_extended)
{
  int prev_fill = QST_INT (inst, qn->src_out_fill);
  int *sets;
  int batch_sz = qn->src_batch_size ? QST_INT (inst, qn->src_batch_size) : dc_batch_sz;
  int new_sz;
  if (itc->itc_row_specs)
    batch_sz = dc_max_batch_sz;	/* if there is filtering, the matches will cover the whole seg, else may find no matches in first n if n is less than seg length and falsely conclude the seg does not contain any */
  new_sz = MIN (batch_sz, 2 * (max_sets + n_more));
  if (sets_fill + n_more > batch_sz)
    {
      *is_extended = 0;
      return QST_BOX (int *, inst, qn->src_sets);
    }
  QST_INT (inst, qn->src_out_fill) = max_sets;
  sets = qn_extend_sets (qn, inst, new_sz);
  QST_INT (inst, qn->src_out_fill) = prev_fill;
  return sets;
}


int
itc_single_row_opt (it_cursor_t * itc, buffer_desc_t * buf, int set, int *done)
{
  int is_unq = itc->itc_ks->ks_ts->ts_is_unique;
  int match_fill = 0;
  data_source_t *qn = (data_source_t *) itc->itc_ks->ks_ts;
  caddr_t *inst = itc->itc_out_state;
  int *sets = QST_BOX (int *, inst, qn->src_sets);
  int initial_set = set;
  int sets_fill = QST_INT (inst, qn->src_out_fill);
  int initial_sets_fill = sets_fill;
  int sets_max = box_length (sets) / sizeof (int32);
  row_no_t *matches = itc->itc_matches;
  int matches_max;
  int inx, n_singles, prev = 0;
  const row_range_t *ranges = itc->itc_ranges;
  if (itc->itc_rl || itc->itc_range_fill < 2 || !enable_col_set_merge || ISO_SERIALIZABLE == itc->itc_isolation)
    return 0;
  itc->itc_n_matches = 0;
  if (!matches)
    {
      matches = itc->itc_matches = (row_no_t *) itc_alloc_box (itc, 2000 * sizeof (row_no_t), DV_BIN);
      itc->itc_match_sz = matches_max = 2000;
    }
  else
    matches_max = box_length (matches) / sizeof (row_no_t);
  for (inx = set; inx < itc->itc_range_fill; inx++)
    {
      int ctr, this_set;
      row_no_t r_end = ranges[inx].r_end, r_first = ranges[inx].r_first;
      int sz = r_end - r_first;
      if (1 > sz)
	continue;
      if (1 == sz)
	{
	  CHECK_SETS (1);
	  CHECK_MATCHES (1);
	  sets[sets_fill++] = itc->itc_param_order[itc->itc_col_first_set + inx];
	  matches[match_fill++] = r_first;
	  continue;
	}
      else
	{
	  if (is_unq && itc->itc_ranges[inx].r_end != COL_NO_ROW)
	    NON_UNQ_RANGE;
	  if (sz > 30 || r_first < prev)
	    {
	      if (inx == initial_set)
		return 0;
	      break;
	    }
	}
      CHECK_SETS (sz);
      CHECK_MATCHES (sz);
      this_set = itc->itc_param_order[itc->itc_col_first_set + inx];
      for (ctr = 0; ctr < sz; ctr++)
	{
	  sets[sets_fill++] = this_set;
	  matches[match_fill++] = ctr + r_first;
	}
      itc->itc_ltrx->lt_client->cli_activity.da_seq_rows += sz - 1;
      prev = r_end;
    }
end_of_batch:
  n_singles = sets_fill - initial_sets_fill;
  if (!n_singles)
    {
      if (inx == initial_set)
	return 0;
      itc->itc_set += inx - initial_set - 1;
      *done = 1;
      return inx - 1;
    }
  itc->itc_rows_selected += match_fill - (set - initial_set);
  itc->itc_n_matches = match_fill;
  itc->itc_set = itc->itc_col_first_set + set;
  *done = 1;
  if (DVC_MATCH == itc_col_seg (itc, buf, initial_set << 1 | 1, inx - initial_set))
    return -1;
  return itc->itc_set - itc->itc_col_first_set;
}


int
itc_col_row_check (it_cursor_t * itc, buffer_desc_t ** buf_ret, dp_addr_t * leaf_ret)
{
  int rc = DVC_LESS, inx, wait, first_set, rnd_inc;
  col_row_lock_t *clk;
  db_buf_t row;
  key_ver_t kv;
  buffer_desc_t *buf;
  CHECK_TRX_DEAD (itc, buf_ret, ITC_BUST_CONTINUABLE);
  ITC_DFG_CK (itc);
  itc->itc_col_need_preimage = 0;
start:
  buf = *buf_ret;
  clk = NULL;
  wait = CLK_NO_WAIT;
  first_set = itc->itc_set;
  row = BUF_ROW (buf, itc->itc_map_pos);
  kv = IE_KEY_VERSION (row);
  itc->itc_col_leaf_buf = buf;
  *leaf_ret = 0;
  if (KV_LEFT_DUMMY == kv || KV_LEAF_PTR == kv)
    {
      dp_addr_t leaf = leaf_pointer (row, itc->itc_insert_key);
      if (leaf)
	{
	  *leaf_ret = leaf;
	  return DVC_MATCH;
	}
      return DVC_LESS;
    }
  if (!itc->itc_is_col)
    return DVC_MATCH;
  itc->itc_read_hook = itc_col_read_hook;
  if (!itc->itc_ks->ks_oby_order)
  itc_col_search (itc, buf);
  else
    {
      /* if params not reordered asc, then do a single set at a time, itc_next_set will do random seek */
      int n_save = itc->itc_n_sets;
      itc->itc_n_sets = itc->itc_set + 1;
      itc_col_search (itc, buf);
      itc->itc_n_sets = n_save;
    }
  if (ISO_SERIALIZABLE == itc->itc_isolation)
    {
      wait = itc_col_serializable (itc, buf_ret);
      if (wait)
	goto start;
    }
  if (ITC_MAYBE_LOCK (itc, itc->itc_map_pos))
    {
      itc->itc_rl = pl_row_lock_at (itc->itc_pl, itc->itc_map_pos);
      if (itc->itc_rl && (itc->itc_isolation > ISO_COMMITTED || PL_EXCLUSIVE == itc->itc_lock_mode))
	wait = itc_first_col_lock (itc, &clk, buf);
    }
  else
    itc->itc_rl = NULL;
  for (inx = 0; inx < itc->itc_range_fill; inx++)
    {
      if (itc->itc_multistate_row_specs)
	{
	  if (itc->itc_set != first_set + inx)
	    itc_set_row_spec_param_row (itc, first_set + inx);
	}
      else
	{
	  int done = 0;
	  int new_inx = itc_single_row_opt (itc, buf, inx, &done);
	  if (done && new_inx != -1)
	    {
	      rc = DVC_LESS;	/* means not stopped in the middle with full batch */
	      inx = new_inx;
	      continue;
	    }
	  if (-1 == new_inx)
	    {
	      rc = DVC_MATCH;
	      break;
	    }
	}
      itc->itc_set = first_set + inx;
      rc = itc_col_seg (itc, buf, 0, 0);
      if (DVC_MATCH == rc)
	break;
    }
  if (DVC_MATCH == rc || COL_NO_ROW == itc->itc_ranges[itc->itc_range_fill - 1].r_end)
    rnd_inc = itc->itc_set - first_set ? itc->itc_set - first_set - 1 : 0;
  else
    rnd_inc = itc->itc_range_fill - 1;
  itc->itc_ltrx->lt_client->cli_activity.da_same_seg += rnd_inc;
  itc->itc_ltrx->lt_client->cli_activity.da_random_rows += rnd_inc;

  if (CLK_NO_WAIT != wait && DVC_MATCH != rc)
    {
      /* All rows before lock to wait for are done and the batch did not go full before reaching the lock  */
      itc_col_wait (itc, buf_ret, clk, wait);
      goto start;
    }
  itc_col_leave (itc, 0);
  itc->itc_read_hook = itc_dive_read_hook;
  if (inx == itc->itc_range_fill)
    {
      if (!inx)
	return DVC_LESS;
      if (COL_NO_ROW == itc->itc_ranges[inx - 1].r_end && COL_NO_ROW != itc->itc_ranges[inx - 1].r_first)
	return DVC_LESS;
      return DVC_GREATER;
    }
  return rc;
}


int enable_col_dep_sample = 1;



extern int32 sqlo_sample_dep_cols;
int
itc_col_count (it_cursor_t * itc, buffer_desc_t * buf, int *row_match_ctr)
{
  /* Take a sample of rows.  If the last index spec is not equality this becomes the first row spec.  There may be other row specs.  The count returned is the matches in the seg according to index.  The row matchh ctr is matches in index after row specs evaluated */
  db_buf_t row;
  int inx, row_matches;
  int inx_spec_in_row_spec = 0;
  search_spec_t *prev_row_sp = itc->itc_row_specs;
  itc->itc_col_row = COL_NO_ROW;
#if 0
  for (inx = 0; inx < itc->itc_search_par_fill; inx++)
    ITC_P_VEC (itc, inx) = NULL;
#endif
  row = BUF_ROW (buf, itc->itc_map_pos);
  if (KV_LEFT_DUMMY == IE_KEY_VERSION (row) || KV_LEAF_PTR == IE_KEY_VERSION (row))
    return 0;
  itc_col_search (itc, buf);
  if (COL_NO_ROW == itc->itc_ranges[0].r_end && COL_NO_ROW == itc->itc_ranges[0].r_first)
    inx = 0;
  if (COL_NO_ROW == itc->itc_ranges[0].r_end)
    {
      int rows_in_seg;
      col_data_ref_t *cr = itc->itc_col_refs[0];
      if (!cr)
	cr = itc->itc_col_refs[0] = itc_new_cr (itc);
      if (!cr->cr_is_valid)
	itc_fetch_col (itc, buf, &itc->itc_insert_key->key_row_var[0], 0, COL_NO_ROW);
      rows_in_seg = cr_n_rows (cr);
      itc->itc_st.segs_sampled++;
      itc->itc_st.rows_in_segs += rows_in_seg;
	  itc->itc_ranges[0].r_end = rows_in_seg;
    }
  inx = row_matches = itc->itc_ranges[0].r_end - itc->itc_ranges[0].r_first;
  if (enable_col_dep_sample)
    {
      search_spec_t tmp_sp;
      search_spec_t *sp = itc->itc_key_spec.ksp_spec_array;
      int nth_key = 0;
      ITC_SAVE_ROW_SPECS (itc);
      ITC_NO_ROW_SPECS (itc);
      if (sp)
	{
	  while (sp->sp_next)
	    {
	      nth_key++;
	      sp = sp->sp_next;
	    }
	  if (CMP_EQ != sp->sp_min_op)
	    {
	      inx_spec_in_row_spec = 1;
	      tmp_sp = *sp;
	      tmp_sp.sp_cl = itc->itc_insert_key->key_row_var[nth_key];
	      tmp_sp.sp_next = sqlo_sample_dep_cols ? prev_row_sp : NULL;
	      itc->itc_row_specs = &tmp_sp;
	    }
	}
      else if (sqlo_sample_dep_cols )
	{
	  itc->itc_row_specs = prev_row_sp;
	}
      if (itc->itc_row_specs)
	{
	  itc->itc_random_search = RANDOM_SEARCH_COND;
	  itc_set_sp_stat (itc);
	  itc_col_seg (itc, buf, 0, 0);
	  itc->itc_random_search = RANDOM_SEARCH_OFF;
	  if (inx_spec_in_row_spec)
	    {
	      if (itc->itc_n_row_specs > 1)
		{
		  inx = itc->itc_sp_stat[0].spst_out;
		  row_matches = itc->itc_n_matches;
		}
	      else
		inx = row_matches = itc->itc_n_matches;
	    }
	  else
	    {
	      row_matches = itc->itc_n_matches;
	    }
	}
      ITC_RESTORE_ROW_SPECS (itc);
    }
  itc_col_leave (itc, 0);
  *row_match_ctr += row_matches;
  return inx;
}


int
itc_col_row_check_dummy (it_cursor_t * itc, buffer_desc_t * buf)
{
  if (!itc->itc_is_col)
    return DVC_MATCH;
  GPF_T1 ("Must call itc_col_row_check instead");
  return 0;
}

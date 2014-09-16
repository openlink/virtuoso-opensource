/*
 *  vec.c
 *
 *  $Id$
 *
 *  Vectored execution
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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
#include "xmlnode.h"
#include "sqlfn.h"
#include "sqlcomp.h"
#include "lisprdr.h"
#include "sqlopcod.h"
#include "security.h"
#include "sqlbif.h"
#include "sqltype.h"
#include "libutil.h"
#include "arith.h"
#include "datesupp.h"
#include "datesupp.h"


int64
dc_any_value (data_col_t * dc, int inx)
{
  if (DCT_BOXES & dc->dc_type)
    return (ptrlong) ((caddr_t *) dc->dc_values)[inx];
  switch (dc->dc_dtp)
    {
    case DV_ANY:
      return (uptrlong) ((caddr_t *) dc->dc_values)[inx];
    case DV_SHORT_INT:
    case DV_DOUBLE_FLOAT:
    case DV_LONG_INT:
    case DV_IRI_ID:
    case DV_INT64:
    case DV_IRI_ID_8:
      return ((int64 *) dc->dc_values)[inx];
    case DV_SINGLE_FLOAT:
      return (unsigned int64) ((uint32 *) dc->dc_values)[inx];
    case DV_DATETIME:
    case DV_DATE:
    case DV_TIME:
    case DV_TIMESTAMP:
      return ((int64) (ptrlong) dc->dc_values) + DT_LENGTH * inx;
    }
  GPF_T1 ("dc of no dtp in dc_any_value");
  return 0;
}


int64
dc_any_value_n (data_col_t * dc, int inx, char *nf)
{
  if (DCT_BOXES & dc->dc_type)
    {
      caddr_t b = ((caddr_t *) dc->dc_values)[inx];
      *nf = IS_BOX_POINTER (b) && DV_DB_NULL == box_tag (b);
      return (ptrlong) b;
    }
  switch (dc->dc_dtp)
    {
    case DV_ANY:
      {
	db_buf_t a = ((db_buf_t *) dc->dc_values)[inx];
	*nf = DV_DB_NULL == a[0];
	return (uptrlong) a;
      }
    case DV_SHORT_INT:
    case DV_DOUBLE_FLOAT:
    case DV_LONG_INT:
    case DV_IRI_ID:
    case DV_INT64:
    case DV_IRI_ID_8:
      *nf = DC_IS_NULL (dc, inx);
      return ((int64 *) dc->dc_values)[inx];
    case DV_SINGLE_FLOAT:
      *nf = DC_IS_NULL (dc, inx);
      return (unsigned int64) ((uint32 *) dc->dc_values)[inx];
    case DV_DATETIME:
    case DV_DATE:
    case DV_TIME:
    case DV_TIMESTAMP:
      *nf = DC_IS_NULL (dc, inx);
      return ((int64) (ptrlong) dc->dc_values) + DT_LENGTH * inx;
    }
  GPF_T1 ("dc of no dtp in dc_any_value");
  return 0;
}

int64
dc_any_value_prefetch (data_col_t * dc, int inx, int inx2)
{
  if (DCT_BOXES & dc->dc_type)
    {
      __builtin_prefetch (&((caddr_t *) dc->dc_values)[inx2]);
      return (ptrlong) ((caddr_t *) dc->dc_values)[inx];
    }
  switch (dc->dc_dtp)
    {
    case DV_ANY:
      {
	__builtin_prefetch (((caddr_t *) dc->dc_values)[inx2]);
	return (uptrlong) ((caddr_t *) dc->dc_values)[inx];
      }
    case DV_SHORT_INT:
    case DV_DOUBLE_FLOAT:
    case DV_LONG_INT:
    case DV_IRI_ID:
    case DV_INT64:
    case DV_IRI_ID_8:
      __builtin_prefetch (&((int64 *) dc->dc_values)[inx2]);
      return ((int64 *) dc->dc_values)[inx];
    case DV_SINGLE_FLOAT:
      __builtin_prefetch (&((int32 *) dc->dc_values)[inx2]);
      return (unsigned int64) ((uint32 *) dc->dc_values)[inx];
    case DV_DATETIME:
    case DV_DATE:
    case DV_TIME:
    case DV_TIMESTAMP:
      __builtin_prefetch (dc->dc_values + inx2 * DT_LENGTH);
      return ((int64) (ptrlong) dc->dc_values) + DT_LENGTH * inx;
    }
  GPF_T1 ("dc of no dtp in dc_any_value");
  return 0;
}


int64
dc_any_value_n_prefetch (data_col_t * dc, int inx, int inx2, char *nf)
{
  if (DCT_BOXES & dc->dc_type)
    {
      caddr_t b = ((caddr_t *) dc->dc_values)[inx];
      __builtin_prefetch (&((caddr_t *) dc->dc_values)[inx2]);
      *nf = IS_BOX_POINTER (b) && DV_DB_NULL == box_tag (b);
      return (ptrlong) b;
    }
  switch (dc->dc_dtp)
    {
    case DV_ANY:
      {
	db_buf_t a = ((db_buf_t *) dc->dc_values)[inx];
	__builtin_prefetch (&((caddr_t *) dc->dc_values)[inx2]);
	*nf = DV_DB_NULL == a[0];
	return (uptrlong) a;
      }
    case DV_SHORT_INT:
    case DV_DOUBLE_FLOAT:
    case DV_LONG_INT:
    case DV_IRI_ID:
    case DV_INT64:
    case DV_IRI_ID_8:
      __builtin_prefetch (&((int64 *) dc->dc_values)[inx2]);
      *nf = DC_IS_NULL (dc, inx);
      return ((int64 *) dc->dc_values)[inx];
    case DV_SINGLE_FLOAT:
      __builtin_prefetch (&((int32 *) dc->dc_values)[inx2]);
      *nf = DC_IS_NULL (dc, inx);
      return (unsigned int64) ((uint32 *) dc->dc_values)[inx];
    case DV_DATETIME:
    case DV_DATE:
    case DV_TIME:
    case DV_TIMESTAMP:
      __builtin_prefetch (dc->dc_values + inx2 * DT_LENGTH);
      *nf = DC_IS_NULL (dc, inx);
      return ((int64) (ptrlong) dc->dc_values) + DT_LENGTH * inx;
    }
  GPF_T1 ("dc of no dtp in dc_any_value");
  return 0;
}

caddr_t dc_mp_box_for_rd (mem_pool_t * mp, data_col_t * dc, int inx)
{
  /* return box for insert/update of column via rd. */
  if (DCT_BOXES & dc->dc_type)
    {
      caddr_t box = ((caddr_t *) dc->dc_values)[inx];
      return box;
    }
  if (dc->dc_nulls && DC_IS_NULL (dc, inx))
    return mp_alloc_box (mp, 0, DV_DB_NULL);
  switch (dc->dc_dtp)
    {
    case DV_ANY:
      {
	db_buf_t dv = ((db_buf_t *) dc->dc_values)[inx];
	return mp_box_deserialize_string (mp, (caddr_t) dv, INT32_MAX, 0);
      }
    case DV_SHORT_INT:
    case DV_LONG_INT:
    case DV_INT64:
      return mp_box_num (mp, ((int64 *) dc->dc_values)[inx]);
    case DV_IRI_ID:
    case DV_IRI_ID_8:
      return mp_box_iri_id (mp, ((int64 *) dc->dc_values)[inx]);
    case DV_DOUBLE_FLOAT:
      return mp_box_double (mp, ((double *) dc->dc_values)[inx]);
    case DV_SINGLE_FLOAT:
      return mp_box_float (mp, ((float *) dc->dc_values)[inx]);
    case DV_DATETIME:
    case DV_DATE:
    case DV_TIME:
    case DV_TIMESTAMP:
      {
	caddr_t b = mp_alloc_box (mp, DT_LENGTH, DV_DATETIME);
	memcpy_dt (b, dc->dc_values + DT_LENGTH * inx);
	return b;
      }
    }
  GPF_T1 ("unsupported dc dtp");
  return NULL;
}

void
dc_ensure_null_bits (data_col_t * dc)
{
  /* called for adding null bitmap to a num inline or date dc.  Use a previously existing one if it is large enough, else make a new one */
  int null_len = ALIGN_8 (dc->dc_n_places) / 8;
  if (dc->dc_nulls && box_length (dc->dc_nulls) >= null_len)
    return;
  if (dc->dc_org_nulls && box_length (dc->dc_org_nulls) >= null_len)
    {
      dc->dc_nulls = dc->dc_org_nulls;
    }
  else
    {
      dc->dc_nulls = (db_buf_t) mp_alloc_box_ni (dc->dc_mp, null_len, DV_BIN);
      dc->dc_org_nulls = dc->dc_nulls;
    }
  memset (dc->dc_nulls, 0, null_len);
}


#ifdef DC_BOXES_DBG
#define DC_FREE_BOX(dc, nth) \
  { caddr_t __v = ((caddr_t*)(dc)->dc_values)[nth]; dk_free_tree (__v); if (dc->dc_mp->mp_box_to_dc) remhash ((void*)__v, dc->dc_mp->mp_box_to_dc); }
#else
#define DC_FREE_BOX(dc, nth) \
  dk_free_tree (((caddr_t*)(dc)->dc_values)[nth])
#endif


void
dc_set_null (data_col_t * dc, int set)
{
  DC_CHECK_LEN (dc, set);
  dc->dc_any_null = 1;
  if (DCT_NUM_INLINE & dc->dc_type || DV_DATETIME == dc->dc_dtp)
    {
      if (!dc->dc_nulls)
	dc_ensure_null_bits (dc);
      DC_SET_NULL (dc, set);
      if (dc->dc_n_values <= set)
	dc->dc_n_values = set + 1;
      return;
    }
  if (DCT_BOXES & dc->dc_type)
    {
      if (dc->dc_n_values > set)
	{
	  DC_FREE_BOX (dc, set);
	}
      DC_FILL_TO (dc, int64, set);
      ((caddr_t *) dc->dc_values)[set] = dk_alloc_box (0, DV_DB_NULL);
      if (dc->dc_n_values <= set)
	dc->dc_n_values = set + 1;
      return;
    }
  if (DV_ANY == dc->dc_dtp)
    {
      dtp_t d = DV_DB_NULL;
      int save = dc->dc_n_values;
      DC_FILL_TO (dc, caddr_t, set);
      dc->dc_n_values = set;
      dc_append_bytes (dc, &d, 1, NULL, 0);
      dc->dc_n_values = MAX (set + 1, save);
    }
  else
    GPF_T1 ("dc of undefined type for setting null");
}

int
dc_is_null (data_col_t * dc, int set)
{
  if (set >= dc->dc_n_values)
    return 0;
  if (DCT_BOXES & dc->dc_type)
    return DV_DB_NULL == DV_TYPE_OF (((caddr_t *) dc->dc_values)[set]);
  if (DV_ANY == dc->dc_dtp)
    return DV_DB_NULL == (((db_buf_t *) dc->dc_values)[set])[0];
  if (dc->dc_nulls)
    return DC_IS_NULL (dc, set);
  return 0;
}


void
dc_reserve_bytes (data_col_t * dc, int len)
{
  if (dc->dc_buf_fill + len >= dc->dc_buf_len)
    {
      int l = 0;
      if (len > 100000)
	l = len;
      else if (len > dc_str_buf_unit)
	l = (len + 10) * 2;
      else
	l = dc_str_buf_unit;
      dc_get_buffer (dc, l);
    }
  ((db_buf_t *) dc->dc_values)[dc->dc_n_values++] = dc->dc_buffer + dc->dc_buf_fill;
  dc->dc_buf_fill += len;
}


void
dc_append_bytes (data_col_t * dc, db_buf_t bytes, int len, db_buf_t pref_bytes, int pref_len)
{
  len += pref_len;
  DC_CHECK_LEN (dc, dc->dc_n_values);
  if (dc->dc_buf_fill + len >= dc->dc_buf_len)
    {
      int l = 0;
      if (len > 100000)
	l = len;
      else if (len > dc_str_buf_unit)
	l = (len + 10) * 2;
      else
	l = dc_str_buf_unit;
      dc_get_buffer (dc, l);
    }
  ((db_buf_t *) dc->dc_values)[dc->dc_n_values++] = dc->dc_buffer + dc->dc_buf_fill;
  if (pref_len)
    memcpy_16 (dc->dc_buffer + dc->dc_buf_fill, pref_bytes, pref_len);
  memcpy_16 (dc->dc_buffer + dc->dc_buf_fill + pref_len, bytes, len - pref_len);
  dc->dc_buf_fill += len;
}


int64
unbox_inline_num (caddr_t n)
{
  if (!IS_BOX_POINTER (n))
    return (ptrlong) n;
  switch (box_tag (n))
    {
    case DV_LONG_INT:
    case DV_IRI_ID:
    case DV_DOUBLE_FLOAT:
      return *(int64 *) n;
    case DV_SINGLE_FLOAT:
      {
	float f = *(float *) n;
	return *(uint32 *) & f;
      }
    default:
      return (ptrlong) n;
    }
}


void
dc_append_box (data_col_t * dc, caddr_t box)
{
  caddr_t str;
  dtp_t dtp = DV_TYPE_OF (box);
  DC_CHECK_LEN (dc, dc->dc_n_values);
  if (DV_DB_NULL == dtp)
    {
      dc_set_null (dc, dc->dc_n_values);
      return;
    }
  if (DCT_BOXES & dc->dc_type)
    {
      ((caddr_t *) dc->dc_values)[dc->dc_n_values++] = box_copy_tree (box);
#ifdef DC_BOXES_DBG
      {
	caddr_t value = ((caddr_t *) dc->dc_values)[dc->dc_n_values - 1];
	mem_pool_t *mp = dc->dc_mp;
	if (IS_BOX_POINTER (value))
	  {
	    if (!mp->mp_box_to_dc)
	      {
		mp->mp_box_to_dc = hash_table_allocate (10001);
		mp->mp_box_to_dc->ht_rehash_threshold = 3;
	      }
	    sethash ((void *) value, mp->mp_box_to_dc, (void *) dc);
	  }
      }
#endif
      return;
    }
  if (dc->dc_min_places && DV_ANY != dc->dc_dtp && dc->dc_dtp != dtp_canonical[dtp])
    dc_heterogenous (dc);
  switch (dc->dc_dtp)
    {
    case DV_LONG_INT:
    case DV_INT64:
    case DV_SHORT_INT:
    case DV_IRI_ID:
    case DV_IRI_ID_8:
    case DV_DOUBLE_FLOAT:
      ((int64 *) dc->dc_values)[dc->dc_n_values++] = unbox_inline_num (box);
      break;
    case DV_SINGLE_FLOAT:
      if (IS_BOX_POINTER (box))
      ((float *) dc->dc_values)[dc->dc_n_values++] = unbox_float (box);
      else
	((float *) dc->dc_values)[dc->dc_n_values++] = (float) (int64) box;
      break;
    case DV_ANY:
      {
	caddr_t err = NULL;
	dtp_t dtp = DV_TYPE_OF (box);
	dtp_t header[10];
	int len, head_len;
	AUTO_POOL (500);
	switch (dtp)
	  {
	  case DV_STRING:
	    if (box_flags (box))
	      goto general;
	    len = box_length (box) - 1;
	    if (len < 256)
	      {
		header[0] = DV_SHORT_STRING_SERIAL;
		header[1] = len;
		head_len = 2;
	      }
	    else
	      {
		header[0] = DV_STRING;
		LONG_SET_NA (&header[1], len);
		head_len = 5;
	      }
	    dc_append_bytes (dc, (db_buf_t) box, len, header, head_len);
	    break;
	  case DV_RDF:
	    {
	      QNCAST (rdf_box_t, rb, box);
	      if (rb->rb_is_complete)
		{
		  dc_append_rb (dc, box);
		  break;
		}
	      goto general;
	    }
	  default:
	  general:
	    str = box_to_any_1 (box, &err, &ap, DKS_TO_DC);
	    if (err)
	      sqlr_resignal (err);
	    dc_append_bytes (dc, (db_buf_t) str, box_length (str) - 1, NULL, 0);
	    if (str < ap.ap_area || str > ap.ap_area + ap.ap_fill)
	      dk_free_box (str);
	  }
	break;
      }
    case DV_DATETIME:
    case DV_DATE:
    case DV_TIME:
    case DV_TIMESTAMP:
      memcpy_dt (dc->dc_values + dc->dc_n_values * DT_LENGTH, box);
      dc->dc_n_values++;
      break;
    default:
      GPF_T1 ("unknown dc dtp in dc append box");
    }
}


void
dc_append_null (data_col_t * dc)
{
  dc_set_null (dc, dc->dc_n_values);
}


caddr_t
box_deserialize_reusing (db_buf_t string, caddr_t box)
{
  boxint n;
  iri_id_t iid;
  int len, head_len;
  dtp_t old_dtp;
  if (!IS_BOX_POINTER (box))
    return box_deserialize_string ((caddr_t) string, INT32_MAX, 0);
  old_dtp = box_tag (box);
  switch (string[0])
    {
    case DV_SINGLE_FLOAT:
      if (DV_SINGLE_FLOAT == old_dtp)
	{
	  EXT_TO_FLOAT (box, string + 1);
	  return box;
	}
      goto no_reuse;
    case DV_DOUBLE_FLOAT:
      if (DV_DOUBLE_FLOAT == old_dtp)
	{
	  EXT_TO_DOUBLE (box, string + 1);
	  return box;
	}
      goto no_reuse;
    case DV_SHORT_INT:
      n = (signed char) string[1];
      goto int_data;
    case DV_LONG_INT:
      n = LONG_REF_NA (string + 1);
      goto int_data;
    case DV_INT64:
      n = INT64_REF_NA (string + 1);
    int_data:
      if (DV_LONG_INT != old_dtp)
	{
	  dk_free_tree (box);
	  return box_num (n);
	}
      *(int64 *) box = n;
      return box;
    case DV_DB_NULL:
      if (DV_DB_NULL == old_dtp)
	return box;
      else
	{
	  dk_free_tree (box);
	  return dk_alloc_box (0, DV_DB_NULL);
	}
    case DV_IRI_ID:
      iid = (unsigned int32) LONG_REF_NA (string + 1);
      goto iri_data;
    case DV_IRI_ID_8:
      iid = INT64_REF_NA (string + 1);
    iri_data:
      if (DV_IRI_ID == old_dtp)
	{
	  *(iri_id_t *) box = iid;
	  return box;
	}
      dk_free_tree (box);
      return box_iri_id (iid);
    case DV_RDF:
    case DV_RDF_ID:
    case DV_RDF_ID_8:
	{
	  rdf_box_t * x = (rdf_box_t *)box_deserialize_string ((caddr_t)string, INT32_MAX, 0);
	  if (old_dtp == DV_RDF && NULL != x && 0 != x->rb_ro_id && x->rb_ro_id == ((rdf_box_t *)box)->rb_ro_id)
	    {
	      dk_free_box (x);
	      return box;
	    }
	  dk_free_tree (box);
	  return (caddr_t) x;
	}
    case DV_SHORT_STRING_SERIAL:
      len = (unsigned char) string[1];
      head_len = 2;
      goto str_data;
    case DV_LONG_STRING:
      len = LONG_REF_NA (string + 1);
      head_len = 5;
    str_data:
      if (DV_STRING == old_dtp && ALIGN_STR ((len + 1)) == ALIGN_STR (box_length (box)))
	{
	  box_reuse (box, (caddr_t) string + head_len, len + 1, DV_STRING);
	  box[len] = 0;
	  return box;
	}
      goto no_reuse;
    case DV_DATETIME:
      if (DV_DATETIME == old_dtp)
	{
	  memcpy_dt (box, string + 1);
	  return box;
	}
      goto no_reuse;
    default:
    no_reuse:
      {
	/* read first so that there's no ref to freed if throw from read */
	caddr_t x = box_deserialize_string ((caddr_t) string, INT32_MAX, 0);
	dk_free_tree (box);
	return x;
      }
    }
}

caddr_t
dc_box (data_col_t * dc, int inx)
{
  if (dc->dc_nulls)
    {
      if (dc->dc_nulls[inx / 8] & (1 << (inx & 7)))
	return dk_alloc_box (0, DV_DB_NULL);
    }
  if (DCT_BOXES & dc->dc_type)
    return box_copy_tree (((caddr_t *) dc->dc_values)[inx]);
  switch (dc->dc_dtp)
    {
    case DV_LONG_INT:
      return box_num (((boxint *) dc->dc_values)[inx]);
    case DV_IRI_ID:
      return box_iri_id (((boxint *) dc->dc_values)[inx]);
    case DV_SINGLE_FLOAT:
      return box_float (((float *) dc->dc_values)[inx]);
    case DV_DOUBLE_FLOAT:
      return box_double (((double *) dc->dc_values)[inx]);
    case DV_ANY:
      return box_deserialize_string (((caddr_t *) dc->dc_values)[inx], INT32_MAX, 0);
    case DV_DATETIME:
    case DV_DATE:
    case DV_TIME:
    case DV_TIMESTAMP:
      {
	caddr_t b = dk_alloc_box (DT_LENGTH, DV_DATETIME);
	memcpy_dt (b, dc->dc_values + DT_LENGTH * inx);
	return b;
      }
    }
  GPF_T1 ("dc with no type in dc_box");
  return 0;
}


void
dc_append (data_col_t * target, data_col_t * source, int inx)
{
  GPF_T1 ("dc_append not impl");
}


void
itc_result (it_cursor_t * itc)
{
  caddr_t *inst = itc->itc_out_state;
  data_source_t *qn = (data_source_t *) itc->itc_ks->ks_ts;
  int *sets = QST_BOX (int *, inst, qn->src_sets);
  sets[itc->itc_n_results++] = itc->itc_set;
}


void
dc_itc_append_int64_nn (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, caddr_t * inst, state_slot_t * ssl)
{
  data_col_t *dc = (data_col_t *) inst[ssl->ssl_index];
  int64 ln;
  dtp_t *row = itc->itc_row_data;
  row_ver_t rv = IE_ROW_VERSION (row);
  ROW_INT_COL (buf, row, rv, (*cl), INT64_REF, ln);
  ((int64 *) dc->dc_values)[dc->dc_n_values++] = ln;
}


void
dc_itc_append_bm_value (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, caddr_t * inst, state_slot_t * ssl)
{
  data_col_t *dc = (data_col_t *) inst[ssl->ssl_index];
  if (DCT_NUM_INLINE & dc->dc_type)
    ((int64 *) dc->dc_values)[dc->dc_n_values++] = itc->itc_bp.bp_value;
  else
    {
      caddr_t box =
	  DV_LONG_INT == dtp_canonical[cl->cl_sqt.sqt_dtp] ? box_num (itc->itc_bp.bp_value) : box_iri_id (itc->itc_bp.bp_value);
      dc_append_box (dc, box);
      dk_free_box (box);
    }
}


void
dc_itc_append_int64 (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, caddr_t * inst, state_slot_t * ssl)
{
  data_col_t *dc = (data_col_t *) inst[ssl->ssl_index];
  int64 ln;
  dtp_t *row = itc->itc_row_data;
  row_ver_t rv = IE_ROW_VERSION (row);
  if (row[cl->cl_null_flag[rv]] & cl->cl_null_mask[rv])
    {
      dc_append_null (dc);
      return;
    }
  ROW_INT_COL (buf, row, rv, (*cl), INT64_REF, ln);
  ((int64 *) dc->dc_values)[dc->dc_n_values++] = ln;
}

void
dc_itc_append_int_nn (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, caddr_t * inst, state_slot_t * ssl)
{
  data_col_t *dc = (data_col_t *) inst[ssl->ssl_index];
  int32 ln;
  dtp_t *row = itc->itc_row_data;
  row_ver_t rv = IE_ROW_VERSION (row);
  ROW_INT_COL (buf, row, rv, (*cl), LONG_REF, ln);
  ((int64 *) dc->dc_values)[dc->dc_n_values++] = ln;
}

void
dc_itc_append_int (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, caddr_t * inst, state_slot_t * ssl)
{
  data_col_t *dc = (data_col_t *) inst[ssl->ssl_index];
  int32 ln;
  dtp_t *row = itc->itc_row_data;
  row_ver_t rv = IE_ROW_VERSION (row);
  if (row[cl->cl_null_flag[rv]] & cl->cl_null_mask[rv])
    {
      dc_append_null (dc);
      return;
    }
  ROW_INT_COL (buf, row, rv, (*cl), LONG_REF, ln);
  ((int64 *) dc->dc_values)[dc->dc_n_values++] = ln;
}


void
dc_itc_append_iri32 (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, caddr_t * inst, state_slot_t * ssl)
{
  data_col_t *dc = (data_col_t *) inst[ssl->ssl_index];
  uint32 ln;
  dtp_t *row = itc->itc_row_data;
  row_ver_t rv = IE_ROW_VERSION (row);
  if (row[cl->cl_null_flag[rv]] & cl->cl_null_mask[rv])
    {
      dc_append_null (dc);
      return;
    }
  ROW_INT_COL (buf, row, rv, (*cl), LONG_REF, ln);
  ((int64 *) dc->dc_values)[dc->dc_n_values++] = ln;
}


void
dc_itc_append_short (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, caddr_t * inst, state_slot_t * ssl)
{
  data_col_t *dc = (data_col_t *) inst[ssl->ssl_index];
  int32 ln;
  dtp_t *row = itc->itc_row_data;
  row_ver_t rv = IE_ROW_VERSION (row);
  if (row[cl->cl_null_flag[rv]] & cl->cl_null_mask[rv])
    {
      dc_append_null (dc);
      return;
    }
  ln = SHORT_REF (row + cl->cl_pos[rv]);
  ((int64 *) dc->dc_values)[dc->dc_n_values++] = ln;
}


void
dc_itc_append_datetime (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, caddr_t * inst, state_slot_t * ssl)
{
  data_col_t *dc = (data_col_t *) inst[ssl->ssl_index];
  dtp_t *row = itc->itc_row_data;
  row_ver_t rv = IE_ROW_VERSION (row);
  if (row[cl->cl_null_flag[rv]] & cl->cl_null_mask[rv])
    {
      dc_append_null (dc);
      return;
    }
  memcpy_dt (dc->dc_values + dc->dc_n_values * DT_LENGTH, row + cl->cl_pos[rv]);
  dc->dc_n_values++;
}


void
dc_itc_append_double (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, caddr_t * inst, state_slot_t * ssl)
{
  data_col_t *dc = (data_col_t *) inst[ssl->ssl_index];
  dtp_t *row = itc->itc_row_data, *xx, *col;
  row_ver_t rv = IE_ROW_VERSION (row);
  if (row[cl->cl_null_flag[rv]] & cl->cl_null_mask[rv])
    {
      dc_append_null (dc);
      return;
    }
  xx = row + cl->cl_pos[rv];
  col = dc->dc_values + dc->dc_n_values * sizeof (double);
  EXT_TO_DOUBLE (col, xx);
  dc->dc_n_values++;
}


void
dc_itc_append_float (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, caddr_t * inst, state_slot_t * ssl)
{
  data_col_t *dc = (data_col_t *) inst[ssl->ssl_index];
  dtp_t *row = itc->itc_row_data, *xx, *col;
  row_ver_t rv = IE_ROW_VERSION (row);
  if (row[cl->cl_null_flag[rv]] & cl->cl_null_mask[rv])
    {
      dc_append_null (dc);
      return;
    }
  xx = row + cl->cl_pos[rv];
  col = dc->dc_values + dc->dc_n_values * sizeof (float);
  EXT_TO_FLOAT (col, xx);
  dc->dc_n_values++;
}

void
dc_itc_append_box (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, caddr_t * inst, state_slot_t * ssl)
{
  data_col_t *dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
  caddr_t b = itc_box_column (itc, buf, 0, cl);
  if (DCT_BOXES & dc->dc_type)
    {
    ((caddr_t *) dc->dc_values)[dc->dc_n_values++] = b;
      if (IS_BOX_POINTER (b) && DV_DB_NULL == box_tag (b))
	dc->dc_any_null = 1;
    }
  else
    {
      dc_append_box (dc, b);
      dk_free_tree (b);
    }
}



#define VLI \
{ \
  dbe_key_t * key = buf->bd_tree->it_key ? buf->bd_tree->it_key : itc->itc_row_key; \
  ROW_STR_COL (key->key_versions[IE_KEY_VERSION (row)], buf, row, cl, xx, vl1, xx2, vl2, offset); \
}


void
dc_reset (data_col_t * dc)
{
  if (DCT_BOXES & dc->dc_type && dc->dc_values)
    {
      int inx;
      for (inx = 0; inx < dc->dc_n_values; inx++)
	{
	  DC_FREE_BOX (dc, inx);
	  ((caddr_t *) dc->dc_values)[inx] = NULL;
	}
    }
  dc_reset_alloc (dc);
  dc->dc_n_values = 0;
  dc->dc_any_null = 0;
  if (dc->dc_nulls)
    {
      dc->dc_org_nulls = dc->dc_nulls;
      dc->dc_nulls = NULL;
    }
  if (dc->dc_org_values)
    {
      if (dc->dc_dtp != dc->dc_org_dtp)
	GPF_T1 ("should not have a dc that is retyped after being aliased");
      dc->dc_values = dc->dc_org_values;
      dc->dc_org_values = NULL;
      dc->dc_n_places = dc->dc_org_places;
      dc->dc_org_dtp = 0;
    }
}


void
dc_reset_array (caddr_t * inst, data_source_t * qn, state_slot_t ** ssls, int new_sz)
{
  int inx, size = 0;
  if (qn->src_batch_size)
    {
      if (-1 != new_sz)
	size = new_sz;
      else
	size = QST_INT (inst, qn->src_batch_size);
      if (!size || -1 != new_sz)
	{
	  int prev_size = QST_INT (inst, qn->src_batch_size);
	  if (size > prev_size || !prev_size)
	size = QST_INT (inst, qn->src_batch_size) = MAX (size, dc_batch_sz);
	  else
	    size = prev_size;
	}
      if (qn->src_sets)
      QN_CHECK_SETS (qn, inst, size);
    }
  if (!ssls)
    return;

  DO_BOX (state_slot_t *, ssl, inx, ssls)
  {
    data_col_t *dc;
    if (!ssl || SSL_VEC != ssl->ssl_type)
      continue;			/* can be omitted/aliased out slots in hs out slots */
    dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
    dc_reset (dc);
    DC_CHECK_LEN (dc, (size ? size : dc->dc_n_places) - 1);
  }
  END_DO_BOX;
}


void
dc_get_buffer (data_col_t * dc, int bytes)
{
  db_buf_t new_buf = NULL;
  DO_SET (db_buf_t, buf, &dc->dc_buffers)
  {
    if (0 == box_tag (buf) && box_length (buf) >= bytes)
      {
#ifdef MALLOC_DEBUG
	buf[-1] = DV_CUSTOM;
#else
	box_tag_modify (buf, DV_CUSTOM);
#endif
	new_buf = buf;
	break;
      }
  }
  END_DO_SET ();
  if (!new_buf)
    {
      new_buf = (db_buf_t) mp_alloc_box_ni (dc->dc_mp, MAX (bytes, 0xfff8), DV_CUSTOM);
      mp_set_push (dc->dc_mp, &dc->dc_buffers, (void *) new_buf);
    }
  dc->dc_buffer = new_buf;
  dc->dc_buf_fill = 0;
  dc->dc_buf_len = box_length (new_buf);
}

db_buf_t
dc_alloc (data_col_t * dc, int bytes)
{
  db_buf_t buf;
  if (dc->dc_buffer && dc->dc_buf_fill + bytes <= dc->dc_buf_len)
    {
      db_buf_t r = dc->dc_buffer + dc->dc_buf_fill;
      dc->dc_buf_fill += bytes;
      return r;
    }
  dc_get_buffer (dc, bytes);
  buf = dc->dc_buffer;
  dc->dc_buf_fill = bytes;
  return buf;
}


void
dc_reset_alloc (data_col_t * dc)
{
  DO_SET (db_buf_t, buf, &dc->dc_buffers)
  {
#ifdef MALLOC_DEBUG
    buf[-1] = 0;		/* bypess the check preventing this in box tag modify */
#else
    box_tag_modify (buf, 0);
#endif
  }
  END_DO_SET ();
  dc->dc_buf_len = 0;
  dc->dc_buffer = NULL;
  dc->dc_buf_fill = 0;
}


void
dc_itc_append_any (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, caddr_t * inst, state_slot_t * ssl)
{
  data_col_t *dc = (data_col_t *) inst[ssl->ssl_index];
  dtp_t *row = itc->itc_row_data, *xx, *xx2;
  row_ver_t rv = IE_ROW_VERSION (row);
  unsigned short vl1, vl2, offset;
  if ((row[cl->cl_null_flag[rv]] & cl->cl_null_mask[rv]))
    {
      dtp_t n = DV_DB_NULL;
      if (DV_ANY != dc->dc_dtp)
	{
	  dc_append_null (dc);
	  return;
	}
      dc_append_bytes (dc, &n, 1, NULL, 0);
      dc->dc_any_null = 1;
      return;
    }

  VLI;
  if (DV_ANY != dc->dc_dtp)
    dc_heterogenous (dc);
  if (dc->dc_buf_fill + vl1 + vl2 > dc->dc_buf_len)
    {
      int bytes;
      bytes = MAX (dc->dc_buf_len, vl1 + vl2);
      dc_get_buffer (dc, bytes);
    }
  memcpy_16 (dc->dc_buffer + dc->dc_buf_fill, xx, vl1);
  if (vl2)
    memcpy_16 (dc->dc_buffer + dc->dc_buf_fill + vl1, xx2, vl2);
  dc->dc_buffer[dc->dc_buf_fill + vl1 + vl2 - 1] += offset;
  ((db_buf_t *) dc->dc_values)[dc->dc_n_values++] = dc->dc_buffer + dc->dc_buf_fill;
  dc->dc_buf_fill += vl1 + vl2;
}


void
dc_itc_append_string (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, caddr_t * inst, state_slot_t * ssl)
{
  data_col_t *dc = (data_col_t *) inst[ssl->ssl_index];
  dtp_t *row = itc->itc_row_data, *xx, *xx2, *ptr;
  row_ver_t rv = IE_ROW_VERSION (row);
  unsigned short vl1, vl2, offset;
  int hl;
  if ((row[cl->cl_null_flag[rv]] & cl->cl_null_mask[rv]))
    {
      if (dc->dc_nulls)
	{
	  int nth = dc->dc_n_values;
	  int inx = nth / 8;
	  int bit = nth & 7;
	  ((caddr_t *) dc->dc_values)[dc->dc_n_values] = NULL;
	  dc->dc_nulls[inx] |= 1 << bit;
	  dc->dc_n_values++;
	}
      else if (DV_ANY == dc->dc_dtp)
	{
	  dtp_t n = DV_DB_NULL;
	  dc_append_bytes (dc, &n, 1, NULL, 0);
	  dc->dc_any_null = 1;
	}
      else
	GPF_T1 ("dc is not nullable for null column");
      return;
    }

  VLI;
  hl = (vl1 + vl2 < 256) ? 2 : 5;
  dc_reserve_bytes (dc, vl1 + vl2 + hl);
  ptr = ((db_buf_t *) dc->dc_values)[dc->dc_n_values - 1];
  if (2 == hl)
    {
      ptr[0] = DV_SHORT_STRING_SERIAL;
      ptr[1] = vl1 + vl2;
      ptr += 2;
    }
  else
    {
      ptr[0] = DV_STRING;
      LONG_SET_NA (ptr + 1, vl1 + vl2);
      ptr += 5;
    }
  memcpy_16 (ptr, xx, vl1);
  if (vl2)
    memcpy_16 (ptr + vl1, xx2, vl2);
  else
    ptr[vl1 + vl2 - 1] += offset;
}


void
dc_itc_append_wide (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, caddr_t * inst, state_slot_t * ssl)
{
  data_col_t *dc = (data_col_t *) inst[ssl->ssl_index];
  dtp_t *row = itc->itc_row_data, *xx, *xx2, *ptr;
  row_ver_t rv = IE_ROW_VERSION (row);
  unsigned short vl1, vl2, offset;
  int hl;
  if ((row[cl->cl_null_flag[rv]] & cl->cl_null_mask[rv]))
    {
      if (dc->dc_nulls)
	{
	  int nth = dc->dc_n_values;
	  int inx = nth / 8;
	  int bit = nth & 7;
	  ((caddr_t *) dc->dc_values)[dc->dc_n_values] = NULL;
	  dc->dc_nulls[inx] |= 1 << bit;
	  dc->dc_n_values++;
	}
      else if (DV_ANY == dc->dc_dtp)
	{
	  dtp_t n = DV_DB_NULL;
	  dc_append_bytes (dc, &n, 1, NULL, 0);
	}
      else
	GPF_T1 ("dc is not nullable for null column");
      return;
    }

  VLI;
  hl = (vl1 + vl2 < 256) ? 2 : 5;
  dc_reserve_bytes (dc, vl1 + vl2 + hl);
  ptr = ((db_buf_t *) dc->dc_values)[dc->dc_n_values - 1];
  if (2 == hl)
    {
      ptr[0] = DV_WIDE;
      ptr[1] = vl1 + vl2;
      ptr += 2;
    }
  else
    {
      ptr[0] = DV_LONG_WIDE;
      LONG_SET_NA (ptr + 1, vl1 + vl2);
      ptr += 5;
    }
  memcpy_16 (ptr, xx, vl1);
  if (vl2)
    memcpy_16 (ptr + vl1, xx2, vl2);
  else
    ptr[vl1 + vl2 - 1] += offset;
}


void
dc_itc_append_row (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, caddr_t * inst, state_slot_t * ssl)
{
  data_col_t *dc = (data_col_t *) inst[ssl->ssl_index];
  caddr_t row = itc_box_row (itc, buf);
  dc_append_box (dc, row);
  dk_free_box (row);
}


void
dc_itc_delete (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, caddr_t * inst, state_slot_t * ssl)
{
  dbe_key_t *key = itc->itc_insert_key;
  if ((key->key_partition || key->key_is_primary) && itc->itc_ltrx->lt_replicate != REPL_NO_LOG)
    {
      LOCAL_RD (rd);
      page_row_bm (buf, itc->itc_map_pos, &rd, RO_ROW, itc);
      log_delete (itc->itc_ltrx, &rd, LOG_ANY_AS_STRING | (key->key_partition ? LOG_KEY_ONLY : 0));
      rd_free (&rd);
    }
  if (ISO_SERIALIZABLE != itc->itc_isolation)
    {
      int wait = itc_set_lock_on_row (itc, &buf);
      if (NO_WAIT != wait)
	GPF_T1 ("should not have waited on row-wise non serializable delete");
    }
  itc_delete (itc, &buf, itc->itc_insert_key->key_table->tb_any_blobs ? MAYBE_BLOBS : NO_BLOBS);
  if (!itc->itc_insert_key->key_is_bitmap)
    itc->itc_is_on_row = 1;
  itc->itc_bp.bp_is_pos_valid = 0;
}


void
dc_itc_placeholder (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, caddr_t * inst, state_slot_t * ssl)
{
  data_col_t *dc = (data_col_t *) inst[ssl->ssl_index];
  NEW_PLH (pl);
  memcpy_16 (pl, itc, ITC_PLACEHOLDER_BYTES);
  pl->itc_type = ITC_PLACEHOLDER;
  pl->itc_is_on_row = 1;
  itc_register ((it_cursor_t *) pl, buf);
  ((placeholder_t **) dc->dc_values)[dc->dc_n_values++] = pl;
}


long tc_dc_extend;
long tc_dc_extend_values;

void
dc_extend_2 (data_col_t * dc, int ninx)
{
  int elt_sz = dc_elt_size (dc);
  db_buf_t vs = dc->dc_values;
  int next_len;
  if (!vs)
    next_len = MAX (ninx + 1, dc->dc_n_places);
  else
    next_len = MAX (2 * dc->dc_n_places, ninx + 1);
  if (ninx >= dc_max_batch_sz)
    GPF_T1 ("extending dc past max batch size");
  if (next_len > dc_max_batch_sz)
    next_len = dc_max_batch_sz;
  dc->dc_values = (db_buf_t) mp_alloc_box (dc->dc_mp, 8 + elt_sz * next_len, DV_NON_BOX);
  dc->dc_values = (db_buf_t) ALIGN_16 ((ptrlong) dc->dc_values);
  if (vs)
  memcpy_16 (dc->dc_values, vs, elt_sz * dc->dc_n_values);
  dc->dc_org_values = NULL;
  dc->dc_org_nulls = NULL;
  dc->dc_org_places = 0;
  if (dc->dc_nulls)
    {
      int old_null_bytes = box_length (dc->dc_nulls);
      int new_null_bytes = ALIGN_8 (next_len) / 8;
      int n_bytes = ALIGN_8 (dc->dc_n_places) / 8;
      db_buf_t nulls = dc->dc_nulls;
      if (old_null_bytes < new_null_bytes)
	{
	  dc->dc_nulls = (db_buf_t) mp_alloc_box_ni (dc->dc_mp, new_null_bytes, DV_BIN);
	  memcpy_16 (dc->dc_nulls, nulls, n_bytes);
	}
      memzero (dc->dc_nulls + n_bytes, new_null_bytes - n_bytes);
    }
  dc->dc_n_places = next_len;
  dc->dc_min_places = next_len;
  TC (tc_dc_extend);
  tc_dc_extend_values += next_len;
}


void
dc_append_int64 (data_col_t * dc, int64 n)
{
  int64 *ptr;
  DC_CHECK_LEN (dc, dc->dc_n_values);
  ptr = (int64 *) dc->dc_values;
  ptr[dc->dc_n_values++] = n;
}


void
dc_append_float (data_col_t * dc, float n)
{
  float *ptr;
  DC_CHECK_LEN (dc, dc->dc_n_values);
  ptr = (float *) dc->dc_values;
  ptr[dc->dc_n_values++] = n;
}


int
dc_elt_size (data_col_t * dc)
{
  if (DV_DATETIME == dc->dc_dtp)
    return DT_LENGTH;
  if (DV_SINGLE_FLOAT == dc->dc_dtp)
    return sizeof (float);
  if (DV_ANY == dc->dc_dtp || (DCT_BOXES & dc->dc_type))
    return sizeof (caddr_t);
  return sizeof (int64);
}


#define SSL_N_BOX(dtp) \
{ \
  caddr_t  box = inst[box_index]; \
  if (!IS_BOX_POINTER (box) || sizeof (int64) != box_length (box))	\
    { dk_free_tree (box); box = inst[box_index] = dk_alloc_box (sizeof (int64), dtp);} \
  if (val_dc->dc_nulls && DC_IS_NULL(val_dc, row_no)) \
    { box_tag_modify (box, DV_DB_NULL); }	      \
  else \
    { \
      box_tag_modify (box, dtp);		      \
      *(int64*)box = ((int64*)val_dc->dc_values)[row_no]; \
    }\
  return box; \
}


#define SSL_FIXED_STR_BOX(dtp, len)			\
{ \
  caddr_t  box = inst[box_index]; \
  if (!IS_BOX_POINTER (box) || len != box_length (box))			\
    { dk_free_box (box); box = inst[box_index] = dk_alloc_box (len, dtp); } \
  if (val_dc->dc_nulls && DC_IS_NULL(val_dc, row_no)) \
    { box_tag_modify (box, DV_DB_NULL); }	      \
  else \
    { \
      box_tag_modify (box, dtp);		      \
      memcpy_16 (box, val_dc->dc_values + len * row_no, len);	\
    }\
  return box; \
}

caddr_t
sslr_qst_get (caddr_t * inst, state_slot_ref_t * sslr, int row_no)
{
  int step;
  data_col_t *val_dc;
  ssl_index_t box_index;
  if (SSL_REF == sslr->ssl_type)
    {
      box_index = sslr->sslr_box_index;
      val_dc = (data_col_t *) inst[sslr->sslr_index];
      for (step = 0; step < sslr->sslr_distance; step++)
	{
	  int *set_nos = (int *) inst[sslr->sslr_set_nos[step]];
#if 0
	  uint32 fill = QST_INT (inst, sslr->sslr_set_nos[step] + 1);
	  if ((uint32) row_no > fill)
	    GPF_T1 ("access to set beyond present results");
#endif
	  row_no = set_nos[row_no];
	}
    }
  else
    {
      QNCAST (state_slot_t, ssl, sslr);
      box_index = ssl->ssl_box_index;
      val_dc = (data_col_t *) inst[ssl->ssl_index];
    }
  if (!box_index)
    GPF_T1 ("no ssl_box_index");
  switch (val_dc->dc_dtp)
    {
    case DV_ANY:
      {
	caddr_t prev = inst[box_index];
	caddr_t next;
	db_buf_t ptr;
	if ((uint32) row_no >= val_dc->dc_n_values)
	  return NULL;
	ptr = ((db_buf_t *) val_dc->dc_values)[row_no];
	next = box_deserialize_reusing (ptr, prev);
	if (next != prev)
	  {
	    inst[box_index] = next;
	  }
	return next;
      }
    case DV_IRI_ID_8:
    case DV_IRI_ID:
      SSL_N_BOX (DV_IRI_ID);
    case DV_INT64:
    case DV_LONG_INT:
    case DV_SHORT_INT:
      SSL_N_BOX (DV_LONG_INT);
    case DV_DOUBLE_FLOAT:
      SSL_N_BOX (DV_DOUBLE_FLOAT);
    case DV_DATETIME:
    case DV_DATE:
    case DV_TIME:
    case DV_TIMESTAMP:
      SSL_FIXED_STR_BOX (DV_DATETIME, DT_LENGTH);
    case DV_SINGLE_FLOAT:
      SSL_FIXED_STR_BOX (DV_SINGLE_FLOAT, sizeof (float));
    default:
      if (DCT_BOXES & val_dc->dc_type)
	if (val_dc->dc_n_values <= (uint32) row_no)
	  return NULL;
      return ((caddr_t *) val_dc->dc_values)[row_no];
      GPF_T1 ("dc of unsupported dtp for single value qst_get");
    }
  return 0;
}


int64
qst_vec_get_int64 (caddr_t * inst, state_slot_t * ssl, int row_no)
{
  QNCAST (state_slot_ref_t, sslr, ssl);
  int step;
  data_col_t *val_dc;
  if (SSL_REF == sslr->ssl_type)
    {
      val_dc = (data_col_t *) inst[sslr->sslr_index];
      for (step = 0; step < sslr->sslr_distance; step++)
	{
	  int *set_nos = (int *) inst[sslr->sslr_set_nos[step]];
	  row_no = set_nos[row_no];
	}
    }
  else
    {
      QNCAST (state_slot_t, ssl, sslr);
      val_dc = (data_col_t *) inst[ssl->ssl_index];
    }
  switch (val_dc->dc_dtp)
    {
    case DV_IRI_ID_8:
    case DV_IRI_ID:
    case DV_INT64:
    case DV_LONG_INT:
    case DV_SHORT_INT:
      return ((int64 *) val_dc->dc_values)[row_no];
    default:
      GPF_T1 ("expecting an int column for qst_vec_get_int64");
    }
  return 0;
}


int
sslr_set_no (caddr_t * inst, state_slot_t * ssl, int row_no)
{
  QNCAST (state_slot_ref_t, sslr, ssl);
  int step;
  if (SSL_REF == sslr->ssl_type)
    {
      for (step = 0; step < sslr->sslr_distance; step++)
	{
	  int *set_nos = (int *) inst[sslr->sslr_set_nos[step]];
	  row_no = set_nos[row_no];
	}
      return row_no;
    }
  return row_no;
}



void
sslr_n_ref (caddr_t * inst, state_slot_ref_t * sslr, int *sets, int n_sets)
{
  int n, step;
  for (n = 0; n < n_sets - 8; n += 8)
    {
      int s1 = sets[n], s2 = sets[n + 1], s3 = sets[n + 2], s4 = sets[n + 3], s5 = sets[n + 4], s6 = sets[n + 5], s7 =
	  sets[n + 6], s8 = sets[n + 7];
      for (step = 0; step < sslr->sslr_distance; step++)
	{
	  int *set_nos = (int *) inst[sslr->sslr_set_nos[step]];
	  s1 = set_nos[s1];
	  s2 = set_nos[s2];
	  s3 = set_nos[s3];
	  s4 = set_nos[s4];
	  s5 = set_nos[s5];
	  s6 = set_nos[s6];
	  s7 = set_nos[s7];
	  s8 = set_nos[s8];
	}
      sets[n] = s1;
      sets[n + 1] = s2;
      sets[n + 2] = s3;
      sets[n + 3] = s4;
      sets[n + 4] = s5;
      sets[n + 5] = s6;
      sets[n + 6] = s7;
      sets[n + 7] = s8;
    }
  for (n = n; n < n_sets; n++)
    {
      int s1 = sets[n];
      for (step = 0; step < sslr->sslr_distance; step++)
	{
	  int *set_nos = (int *) inst[sslr->sslr_set_nos[step]];
	  s1 = set_nos[s1];
	}
      sets[n] = s1;
    }
}



void
sslr_n_consec_ref (caddr_t * inst, state_slot_ref_t * sslr, int *sets, int set, int n_sets)
{
  int n, step;
  for (n = 0; n <= n_sets - 8; n += 8)
    {
      int s1 = set + n, s2 = set + n + 1, s3 = set + n + 2, s4 = set + n + 3, s5 = set + n + 4, s6 = set + n + 5, s7 =
	  set + n + 6, s8 = set + n + 7;
      for (step = 0; step < sslr->sslr_distance; step++)
	{
	  int *set_nos = (int *) inst[sslr->sslr_set_nos[step]];
	  s1 = set_nos[s1];
	  s2 = set_nos[s2];
	  s3 = set_nos[s3];
	  s4 = set_nos[s4];
	  s5 = set_nos[s5];
	  s6 = set_nos[s6];
	  s7 = set_nos[s7];
	  s8 = set_nos[s8];
	}
      sets[n] = s1;
      sets[n + 1] = s2;
      sets[n + 2] = s3;
      sets[n + 3] = s4;
      sets[n + 4] = s5;
      sets[n + 5] = s6;
      sets[n + 6] = s7;
      sets[n + 7] = s8;
    }
  for (n = n; n < n_sets; n++)
    {
      int s1 = set + n;
      for (step = 0; step < sslr->sslr_distance; step++)
	{
	  int *set_nos = (int *) inst[sslr->sslr_set_nos[step]];
	  s1 = set_nos[s1];
	}
      sets[n] = s1;
    }
}

#define RES_IF_NN(set)		\
{ \
  if (!dc->dc_any_null) { \
    sets[fill++] = set; \
  } else  \
    { \
      if (dc->dc_nulls) \
	{ \
	  if (!DC_IS_NULL (dc, set)) \
	    sets[fill++] = set; \
	} \
      else  \
      { \
	if (DV_DB_NULL != ((db_buf_t*)dc->dc_values)[set][0]) \
	  sets[fill++] = set; \
      } \
    } \
}


int
sslr_nn_ref (caddr_t * inst, state_slot_ref_t * sslr, int *sets, int set, int n_sets)
{
  int n, step, fill = 0;
  data_col_t *dc = QST_BOX (data_col_t *, inst, sslr->ssl_index);
  for (n = 0; n <= n_sets - 8; n += 8)
    {
      int s1 = set + n, s2 = set + n + 1, s3 = set + n + 2, s4 = set + n + 3;
      int s5 = set + n + 4, s6 = set + n + 5, s7 = set + n + 6, s8 = set + n + 7;
      for (step = 0; step < sslr->sslr_distance; step++)
	{
	  int *set_nos = (int *) inst[sslr->sslr_set_nos[step]];
	  s1 = set_nos[s1];
	  s2 = set_nos[s2];
	  s3 = set_nos[s3];
	  s4 = set_nos[s4];
	  s5 = set_nos[s5];
	  s6 = set_nos[s6];
	  s7 = set_nos[s7];
	  s8 = set_nos[s8];
	}
      RES_IF_NN (s1);
      RES_IF_NN (s2);
      RES_IF_NN (s3);
      RES_IF_NN (s4);
      RES_IF_NN (s5);
      RES_IF_NN (s6);
      RES_IF_NN (s7);
      RES_IF_NN (s8);

    }
  for (n = n; n < n_sets; n++)
    {
      int s1 = set + n;
      for (step = 0; step < sslr->sslr_distance; step++)
	{
	  int *set_nos = (int *) inst[sslr->sslr_set_nos[step]];
	  s1 = set_nos[s1];
	}
      RES_IF_NN (s1);
    }
  return fill;
}


int
dc_nn_sets (data_col_t * dc, int *sets, int first_set, int n_sets)
{
  int inx, fill = 0;
  for (inx = first_set; inx < first_set + n_sets; inx++)
    {
      RES_IF_NN (inx);
    }
  return fill;
}


#define VA_8(tgt, src) \
  ((int64*)target_val)[tgt] = ((int64*)source_val)[src]

#define VA_NULL(tgt, src) \
  if (BIT_IS_SET (source_nulls, src)) BIT_SET (target_nulls, tgt);

#define VA_4(tgt, src) \
  ((int32*)target_val)[tgt] = ((int32*)source_val)[src]

#define VA_N(tgt, src) \
  memcpy_16 (target_val + dc_elt_len * (tgt), source_val + dc_elt_len * (src), dc_elt_len)

#define VA_CPY(tgt) \
{ \
  db_buf_t dv = ((db_buf_t*)target_val)[tgt], dv2;	\
  int l; \
  DB_BUF_TLEN (l, dv[0], dv); \
  dv2 = dc_alloc (target_dc, l); \
  memcpy_16 (dv2, dv, l); \
  ((db_buf_t*)target_val)[tgt] = dv2; \
}



void
sslr_dc_copy (caddr_t * inst, state_slot_ref_t * sslr, data_col_t * target_dc, data_col_t * source_dc, int n_sets, int dc_elt_len,
    int copy_anies)
{
  db_buf_t target_val;
  db_buf_t target_nulls = NULL;
  db_buf_t source_nulls = source_dc->dc_nulls;
  db_buf_t source_val = source_dc->dc_values;
  int copy_nulls = 0;
  int n, step;
  DC_CHECK_LEN (target_dc, n_sets - 1);
  if (source_dc->dc_any_null)
    target_dc->dc_any_null = 1;
  if (source_dc->dc_any_null && (DV_DATETIME == source_dc->dc_dtp || (DCT_NUM_INLINE & source_dc->dc_type)))
    {
      dc_ensure_null_bits (target_dc);
      target_nulls = target_dc->dc_nulls;
      memzero (target_nulls, ALIGN_8 (n_sets) / 8);
      copy_nulls = 1;
    }
  if (DV_ANY == target_dc->dc_dtp && DV_ANY != source_dc->dc_dtp)
    dc_convert_empty (target_dc, dtp_canonical[source_dc->dc_dtp]);
  target_val = target_dc->dc_values;
  for (n = 0; n <= n_sets - 8; n += 8)
    {
      int s1 = n, s2 = n + 1, s3 = n + 2, s4 = n + 3, s5 = n + 4, s6 = n + 5, s7 = n + 6, s8 = n + 7;
      for (step = 0; step < sslr->sslr_distance; step++)
	{
	  int *set_nos = (int *) inst[sslr->sslr_set_nos[step]];
	  s1 = set_nos[s1];
	  s2 = set_nos[s2];
	  s3 = set_nos[s3];
	  s4 = set_nos[s4];
	  s5 = set_nos[s5];
	  s6 = set_nos[s6];
	  s7 = set_nos[s7];
	  s8 = set_nos[s8];
	}
      if (source_dc->dc_type & DCT_BOXES)
	{
	  ((caddr_t *) target_val)[n + 0] = box_copy_tree (((caddr_t *) source_dc->dc_values)[s1]);
	  ((caddr_t *) target_val)[n + 1] = box_copy_tree (((caddr_t *) source_dc->dc_values)[s2]);
	  ((caddr_t *) target_val)[n + 2] = box_copy_tree (((caddr_t *) source_dc->dc_values)[s3]);
	  ((caddr_t *) target_val)[n + 3] = box_copy_tree (((caddr_t *) source_dc->dc_values)[s4]);
	  ((caddr_t *) target_val)[n + 4] = box_copy_tree (((caddr_t *) source_dc->dc_values)[s5]);
	  ((caddr_t *) target_val)[n + 5] = box_copy_tree (((caddr_t *) source_dc->dc_values)[s6]);
	  ((caddr_t *) target_val)[n + 6] = box_copy_tree (((caddr_t *) source_dc->dc_values)[s7]);
	  ((caddr_t *) target_val)[n + 7] = box_copy_tree (((caddr_t *) source_dc->dc_values)[s8]);
	}
      else if (8 == dc_elt_len)
	{
	  VA_8 (n, s1);
	  VA_8 (n + 1, s2);
	  VA_8 (n + 2, s3);
	  VA_8 (n + 3, s4);
	  VA_8 (n + 4, s5);
	  VA_8 (n + 5, s6);
	  VA_8 (n + 6, s7);
	  VA_8 (n + 7, s8);
	  if (copy_anies && DV_ANY == target_dc->dc_dtp)
	    {
	      VA_CPY (n);
	      VA_CPY (n + 1);
	      VA_CPY (n + 2);
	      VA_CPY (n + 3);
	      VA_CPY (n + 4);
	      VA_CPY (n + 5);
	      VA_CPY (n + 6);
	      VA_CPY (n + 7);
	    }
	}
      else if (4 == dc_elt_len)
	{
	  VA_4 (n, s1);
	  VA_4 (n + 1, s2);
	  VA_4 (n + 2, s3);
	  VA_4 (n + 3, s4);
	  VA_4 (n + 4, s5);
	  VA_4 (n + 5, s6);
	  VA_4 (n + 6, s7);
	  VA_4 (n + 7, s8);
	}
      else
	{
	  VA_N (n, s1);
	  VA_N (n + 1, s2);
	  VA_N (n + 2, s3);
	  VA_N (n + 3, s4);
	  VA_N (n + 4, s5);
	  VA_N (n + 5, s6);
	  VA_N (n + 6, s7);
	  VA_N (n + 7, s8);
	}
      if (copy_nulls)
	{
	  VA_NULL (n, s1);
	  VA_NULL (n + 1, s2);
	  VA_NULL (n + 2, s3);
	  VA_NULL (n + 3, s4);
	  VA_NULL (n + 4, s5);
	  VA_NULL (n + 5, s6);
	  VA_NULL (n + 6, s7);
	  VA_NULL (n + 7, s8);
	}
    }
  for (n = n; n < n_sets; n++)
    {
      int s1 = n;
      for (step = 0; step < sslr->sslr_distance; step++)
	{
	  int *set_nos = (int *) inst[sslr->sslr_set_nos[step]];
	  s1 = set_nos[s1];
	}
      if (source_dc->dc_type & DCT_BOXES)
	{
	  ((caddr_t *) target_val)[n + 0] = box_copy_tree (((caddr_t *) source_dc->dc_values)[s1]);
	}
      else if (8 == dc_elt_len)
	{
	VA_8 (n, s1);
	  if (copy_anies && DV_ANY == target_dc->dc_dtp)
	    VA_CPY (n);
	}
      else if (4 == dc_elt_len)
	VA_4 (n, s1);
      else
	VA_N (n, s1);
      if (copy_nulls)
	VA_NULL (n, s1);
    }
  target_dc->dc_n_values = n_sets;
}


int64
box_to_int64 (caddr_t box, dtp_t dtp)
{
  switch (DV_TYPE_OF (box))
    {
    case DV_LONG_INT:
      return unbox_inline (box);
    case DV_SINGLE_FLOAT:
      return (int64) unbox_float (box);
    case DV_DOUBLE_FLOAT:
      return (int64) unbox_double (box);
    case DV_NUMERIC:
      {
	int64 i;
	numeric_to_int64 ((numeric_t) box, &i);
	return i;
      }
    default:
      return 0;
    }
}

double
box_to_double (caddr_t box, dtp_t dtp)
{
  switch (DV_TYPE_OF (box))
    {
    case DV_LONG_INT:
      return (double) unbox_inline (box);
    case DV_SINGLE_FLOAT:
      return (double) unbox_float (box);
    case DV_DOUBLE_FLOAT:
      return unbox_double (box);
    case DV_NUMERIC:
      {
	double d;
	numeric_to_double ((numeric_t) box, &d);
	return d;
      }
    default:
      return 0;
    }
}

float
box_to_float (caddr_t box, dtp_t dtp)
{
  switch (DV_TYPE_OF (box))
    {
    case DV_LONG_INT:
      return (float) unbox_inline (box);
    case DV_SINGLE_FLOAT:
      return unbox_float (box);
    case DV_DOUBLE_FLOAT:
      return (float) unbox_double (box);
    case DV_NUMERIC:
      {
	double d;
	numeric_to_double ((numeric_t) box, &d);
	return d;
      }
    default:
      return 0;
    }
}


void
qst_vec_set_copy (caddr_t * inst, state_slot_t * ssl, caddr_t v)
{
  QNCAST (query_instance_t, qi, inst);
  int set = qi->qi_set;
  data_col_t *dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
  dtp_t dtp = DV_TYPE_OF (v);
  DC_CHECK_LEN (dc, set);
  if (DV_DB_NULL == dtp)
    {
      dc_set_null (dc, set);
      return;
    }
  if ((DV_ANY == dc->dc_dtp || DCT_BOXES & dc->dc_type) && dc->dc_n_values < set)
    {
      DC_FILL_TO (dc, int64, set);
    }
  if (DV_ANY == ssl->ssl_sqt.sqt_dtp && DV_ANY != dc->dc_dtp && !(DCT_BOXES & dc->dc_type) && dtp_canonical[dtp] != dc->dc_dtp)
    dc_heterogenous (dc);
  /* value from uninitalized variable */
  if (0 && NULL == v && !(DCT_BOXES & dc->dc_type) && DV_DATETIME == dtp_canonical[dc->dc_dtp])
    dc_heterogenous (dc);
  if ((DCT_NUM_INLINE & dc->dc_type) && DV_SINGLE_FLOAT != dc->dc_dtp)
    {
      dtp_t dtp = DV_TYPE_OF (v);
      if (dtp == dc->dc_dtp)
      ((int64 *) dc->dc_values)[set] = unbox_inline_num (v);
      else if (DV_LONG_INT == dc->dc_dtp)
	((int64 *) dc->dc_values)[set] = box_to_int64 (v, dtp);
      else
	((double *) dc->dc_values)[set] = box_to_double (v, dtp);
      if (dc->dc_nulls)
	DC_CLR_NULL (dc, set);
      if (set >= dc->dc_n_values)
	dc->dc_n_values = set + 1;
    }
  else if (DCT_BOXES & dc->dc_type)
    {
      DC_FILL_TO (dc, int64, set);
      if (set < dc->dc_n_values)
	DC_FREE_BOX (dc, set);
      ((caddr_t *) dc->dc_values)[set] = box_copy_tree (v);
      if (set >= dc->dc_n_values)
	dc->dc_n_values = set + 1;
    }
  else
    {
      dtp_t dtp = dc->dc_dtp;
      if (ssl->ssl_dc_dtp == DV_ANY)
	dtp = DV_ANY;
      switch (dtp)
	{
	case DV_ANY:
	  {
	    int save = dc->dc_n_values;
	    dc->dc_n_values = set;
	    dc_append_box (dc, v);
	    dc->dc_n_values = MAX (save, dc->dc_n_values);
	    break;
	  }
	case DV_DATETIME:
	case DV_DATE:
	case DV_TIME:
	case DV_TIMESTAMP:
	  {
	    static char zero[DT_LENGTH];
	    if (!v && !dc->dc_sqt.sqt_non_null)
	      {
		dc_set_null (dc, set);
		return;
	      }
	    memcpy_dt (dc->dc_values + DT_LENGTH * set, (v ? v : zero));
	  if (dc->dc_nulls)
	    DC_CLR_NULL (dc, set);
	  if (set >= dc->dc_n_values)
	    dc->dc_n_values = set + 1;
	  break;
	  }
	case DV_SINGLE_FLOAT:
	  ((float *) dc->dc_values)[set] = box_to_float (v, DV_TYPE_OF (v));
	  if (dc->dc_nulls)
	    DC_CLR_NULL (dc, set);
	  if (set >= dc->dc_n_values)
	    dc->dc_n_values = set + 1;
	  break;
	default:
	  GPF_T1 ("non- assignable dtp");
	}
    }
}


void
qst_vec_set (caddr_t * inst, state_slot_t * ssl, caddr_t v)
{
  QNCAST (query_instance_t, qi, inst);
  int set = qi->qi_set;
  data_col_t *dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
  dtp_t dtp = DV_TYPE_OF (v);
  DC_CHECK_LEN (dc, set);
  if (DV_DB_NULL == dtp)
    {
      dc_set_null (dc, set);
      dk_free_box (v);
      return;
    }
  if (DV_ANY == ssl->ssl_sqt.sqt_dtp && DV_ANY != dc->dc_dtp && !(DCT_BOXES & dc->dc_type) && dtp_canonical[dtp] != dc->dc_dtp)
    dc_heterogenous (dc);
  if ((DCT_NUM_INLINE & dc->dc_type) && DV_SINGLE_FLOAT != dc->dc_dtp)
    {
      if (dtp == dc->dc_dtp)
      ((int64 *) dc->dc_values)[set] = unbox_inline_num (v);
      else if (DV_LONG_INT == dc->dc_dtp)
	((int64 *) dc->dc_values)[set] = box_to_int64 (v, dtp);
      else
	((double *) dc->dc_values)[set] = box_to_double (v, dtp);
      dk_free_tree (v);
      if (dc->dc_nulls)
	DC_CLR_NULL (dc, set);
      if (set >= dc->dc_n_values)
	dc->dc_n_values = set + 1;
    }
  else if (DCT_BOXES & dc->dc_type)
    {
      DC_FILL_TO (dc, int64, set);
      if (set < dc->dc_n_values)
	DC_FREE_BOX (dc, set);
      ((caddr_t *) dc->dc_values)[set] = v;
      if (set >= dc->dc_n_values)
	dc->dc_n_values = set + 1;
    }
  else
    {
      dtp_t dtp = dc->dc_dtp;
      if (ssl->ssl_dc_dtp == DV_ANY)
	dtp = DV_ANY;
      switch (dtp)
	{
	case DV_ANY:
	  {
	    int save = dc->dc_n_values;
	    DC_FILL_TO (dc, caddr_t, set);
	    dc->dc_n_values = set;
	    dc_append_box (dc, v);
	    dc->dc_n_values = MAX (save, dc->dc_n_values);
	    dk_free_tree (v);
	    break;
	  }
	case DV_DATETIME:
	case DV_DATE:
	case DV_TIME:
	case DV_TIMESTAMP:
	  memcpy_dt (dc->dc_values + DT_LENGTH * set, v);
	  if (dc->dc_nulls)
	    DC_CLR_NULL (dc, set);
	  if (set >= dc->dc_n_values)
	    dc->dc_n_values = set + 1;
	  dk_free_tree (v);
	  break;
	case DV_SINGLE_FLOAT:
	  ((float *) dc->dc_values)[set] = box_to_float (v, DV_TYPE_OF (v));
	  if (dc->dc_nulls)
	    DC_CLR_NULL (dc, set);
	  if (set >= dc->dc_n_values)
	    dc->dc_n_values = set + 1;
	  dk_free_tree (v);
	  break;
	default:
	  GPF_T1 ("non- assignable dtp");
	}
    }
}


void
dc_set_long (data_col_t * dc, int set, boxint lv)
{
  int save = dc->dc_n_values;
  DC_CHECK_LEN (dc, set);
  if (!(DCT_NUM_INLINE & dc->dc_type))
    {
      int is_boxes = DCT_BOXES & dc->dc_type;
      if (dc->dc_n_values > set && is_boxes)
	dk_free_tree (((caddr_t *) dc->dc_values)[set]);
      DC_FILL_TO (dc, ptrlong, set);
      if (is_boxes)
	{
	  ((caddr_t *) dc->dc_values)[set] = box_num (lv);
	  dc->dc_n_values = MAX (dc->dc_n_values, set + 1);
	  return;
	}
    }
  dc->dc_n_values = set;
  if (DCT_NUM_INLINE & dc->dc_type)
    {
      if (DV_LONG_INT == dc->dc_dtp || DV_IRI_ID == dc->dc_dtp)
    dc_append_int64 (dc, lv);
      else if (DV_SINGLE_FLOAT == dc->dc_dtp)
	dc_append_float (dc, (float) lv);
  else
    {
	  double df = (double) lv;
	  dc_append_int64 (dc, *(int64 *) & df);
	}
    }
  else
    {
      caddr_t xx[2], b;
      BOX_AUTO (b, xx, sizeof (boxint), DV_LONG_INT);
      *(int64 *) b = lv;
      dc_append_box (dc, b);
    }
  dc->dc_n_values = MAX (dc->dc_n_values, save);
}


void
dc_set_float (data_col_t * dc, int set, float f)
{
  int save = dc->dc_n_values;
  DC_CHECK_LEN (dc, set);
  if (!(DCT_NUM_INLINE & dc->dc_type))
    {
      if (dc->dc_n_values > set && (DCT_BOXES & dc->dc_type))
	dk_free_tree (((caddr_t *) dc->dc_values)[set]);
      DC_FILL_TO (dc, ptrlong, set);
    }
  dc->dc_n_values = set;
  if (DCT_NUM_INLINE & dc->dc_type)
    {
      if (DV_SINGLE_FLOAT == dc->dc_dtp)
    dc_append_float (dc, f);
      else if (DV_DOUBLE_FLOAT == dc->dc_dtp)
	{
	  double df = (double) f;
	  dc_append_int64 (dc, *(int64 *) & df);
	}
      else
	dc_append_int64 (dc, (int64) f);
    }
  else
    {
      caddr_t xx[3], b;
      BOX_AUTO (b, xx, sizeof (boxint), DV_SINGLE_FLOAT);
      *(float *) b = f;
      dc_append_box (dc, b);
    }
  dc->dc_n_values = MAX (dc->dc_n_values, save);
}

void
dc_set_double (data_col_t * dc, int set, double df)
{
  int save = dc->dc_n_values;
  DC_CHECK_LEN (dc, set);
  if (!(DCT_NUM_INLINE & dc->dc_type))
    {
      if (dc->dc_n_values > set && (DCT_BOXES & dc->dc_type))
	dk_free_tree (((caddr_t *) dc->dc_values)[set]);
      DC_FILL_TO (dc, ptrlong, set);
    }
  dc->dc_n_values = set;
  if (DCT_NUM_INLINE & dc->dc_type)
    {
      if (DV_DOUBLE_FLOAT == dc->dc_dtp)
    dc_append_int64 (dc, *(int64 *) & df);
      else if (DV_SINGLE_FLOAT == dc->dc_dtp)
	dc_append_float (dc, (float) df);
      else
	dc_append_int64 (dc, (int64) df);
    }
  else
    {
      caddr_t xx[3], b;
      BOX_AUTO (b, xx, sizeof (boxint), DV_DOUBLE_FLOAT);
      *(double *) b = df;
      dc_append_box (dc, b);
    }
  dc->dc_n_values = MAX (dc->dc_n_values, save);
}


int
dc_cmp (data_col_t * dc, int64 v1, int64 v2)
{
  db_buf_t dv1 = (db_buf_t) (ptrlong) v1;
  db_buf_t dv2 = (db_buf_t) (ptrlong) v2;
  if (DV_RDF == *dv1 && DV_RDF == *dv2)
    return dv_rdf_dc_compare (dv1, dv2);
  return dv_compare (dv1, dv2, NULL, 0);
}

col_ref_t
col_ref_func (dbe_key_t * key, dbe_column_t * col, state_slot_t * ssl)
{
  /* given a col and a ssl, choose a func to ref the col and add the val to the ssl vec. Consider whether col or ssl is nullable */
  dbe_col_loc_t *bit_cl;
  dtp_t d_dtp = ssl->ssl_dc_dtp ? ssl->ssl_dc_dtp : ssl->ssl_dtp;
  if (DV_ANY == d_dtp)
    {
      switch (col->col_sqt.sqt_dtp)
	{
	case DV_STRING:
	  return dc_itc_append_string;
	case DV_WIDE:
	case DV_LONG_WIDE:
	  return dc_itc_append_wide;
	case DV_ANY:
	  return dc_itc_append_any;
	}
    }
  if (vec_box_dtps[col->col_sqt.sqt_dtp] || dtp_canonical[d_dtp] != dtp_canonical[col->col_sqt.sqt_dtp])
    return dc_itc_append_box;
  switch (col->col_sqt.sqt_dtp)
    {
    case DV_INT64:
    case DV_IRI_ID_8:
      if ((bit_cl = key->key_bit_cl) && bit_cl->cl_col_id == col->col_id)
	return dc_itc_append_bm_value;
      if (col->col_sqt.sqt_non_null)
	return dc_itc_append_int64_nn;
      return dc_itc_append_int64;
    case DV_LONG_INT:
      if ((bit_cl = key->key_bit_cl) && bit_cl->cl_col_id == col->col_id)
	return dc_itc_append_bm_value;
      if (col->col_sqt.sqt_non_null)
	return dc_itc_append_int_nn;
      return dc_itc_append_int;
    case DV_SHORT_INT:
      if ((bit_cl = key->key_bit_cl) && bit_cl->cl_col_id == col->col_id)
	return dc_itc_append_bm_value;
      return dc_itc_append_short;
    case DV_IRI_ID:
      if ((bit_cl = key->key_bit_cl) && bit_cl->cl_col_id == col->col_id)
	return dc_itc_append_bm_value;
      return dc_itc_append_iri32;

    case DV_DATETIME:
    case DV_DATE:
    case DV_TIME:
    case DV_TIMESTAMP:
      return dc_itc_append_datetime;
    case DV_DOUBLE_FLOAT:
      return dc_itc_append_double;
    case DV_SINGLE_FLOAT:
      return dc_itc_append_float;
    default:
      return dc_itc_append_box;
    }
}


dk_hash_t *cl_dc_func_id;
dk_hash_t *cl_id_dc_func;


void
cl_dcf_id (col_ref_t f)
{
  static int id = 0;
  id++;
  sethash ((void *) (ptrlong) id, cl_id_dc_func, (void *) f);
  sethash ((void *) f, cl_dc_func_id, (void *) (ptrlong) id);
}


void
cl_dc_funcs ()
{
  cl_dc_func_id = hash_table_allocate (21);
  cl_id_dc_func = hash_table_allocate (21);
  cl_dcf_id (NULL);
  cl_dcf_id (dc_itc_delete);
  cl_dcf_id (dc_itc_placeholder);


  cl_dcf_id (dc_itc_append_string);
  cl_dcf_id (dc_itc_append_wide);
  cl_dcf_id (dc_itc_append_any);
  cl_dcf_id (dc_itc_append_box);
  cl_dcf_id (dc_itc_append_bm_value);
  cl_dcf_id (dc_itc_append_int64_nn);
  cl_dcf_id (dc_itc_append_int64);
  cl_dcf_id (dc_itc_append_int_nn);
  cl_dcf_id (dc_itc_append_int);
  cl_dcf_id (dc_itc_append_short);
  cl_dcf_id (dc_itc_append_iri32);
  cl_dcf_id (dc_itc_append_datetime);
  cl_dcf_id (dc_itc_append_double);
  cl_dcf_id (dc_itc_append_float);

  cl_dcf_id ((col_ref_t) vc_box_copy);
  cl_dcf_id ((col_ref_t) vc_anynn_iri);
  cl_dcf_id ((col_ref_t) vc_irinn_any);
  cl_dcf_id ((col_ref_t) vc_anynn);
  cl_dcf_id ((col_ref_t) vc_anynn_generic);
  cl_dcf_id ((col_ref_t) vc_generic);
}


dtp_t
sqt_dc_dtp (sql_type_t * sqt)
{
  switch (sqt->sqt_dtp)
    {
    case DV_LONG_INT:
    case DV_SHORT_INT:
    case DV_INT64:
      return DV_LONG_INT;
    case DV_IRI_ID:
    case DV_IRI_ID_8:
      return DV_IRI_ID;
    default:
      return DV_ANY;
    }
}



int
vc_intnn_int (data_col_t * target, data_col_t * source, int row, caddr_t * err_ret)
{
  if (DC_IS_NULL (source, row))
    return 0;
  ((int64 *) target->dc_values)[target->dc_n_values++] = ((int64 *) source->dc_values)[row];
  return 1;
}

int
vc_anynn_iri (data_col_t * target, data_col_t * source, int row, caddr_t * err_ret)
{
  iri_id_t iri;
  dtp_t temp[10];
  if (source->dc_nulls && DC_IS_NULL (source, row))
    return 0;
  iri = ((iri_id_t *) source->dc_values)[row];
  if (iri > 0xffffffff)
    {
      temp[0] = DV_IRI_ID_8;
      INT64_SET_NA (&temp[1], iri);
      dc_append_bytes (target, temp, 9, NULL, 0);
    }
  else
    {
      temp[0] = DV_IRI_ID;
      LONG_SET_NA (&temp[1], iri);
      dc_append_bytes (target, temp, 5, NULL, 0);
    }
  return 1;
}


int
vc_irinn_any (data_col_t * target, data_col_t * source, int row, caddr_t * err_ret)
{
  db_buf_t dv = ((db_buf_t *) source->dc_values)[row];
  iri_id_t iri;
  if (DV_ANY != source->dc_dtp)
    return 0;			/* any dc could have become homogenous but then it has no iris because if it were all iris the conversion func would have been bypassed */
  if (DV_IRI_ID == dv[0])
    iri = (iri_id_t) (uint32) LONG_REF_NA (dv + 1);
  else if (DV_IRI_ID_8 == dv[0])
    iri = INT64_REF_NA (dv + 1);
  else
    return 0;
  ((iri_id_t *) target->dc_values)[target->dc_n_values++] = iri;
  return 1;
}


int
vc_intnn_any (data_col_t * target, data_col_t * source, int row, caddr_t * err_ret)
{
  db_buf_t dv = ((db_buf_t *) source->dc_values)[row];
  int64 i;
  if (DV_ANY != source->dc_dtp)
    return 0;
  if (DV_SHORT_INT == dv[0])
    i = (signed char) dv[1];
  if (DV_LONG_INT == dv[0])
    i = LONG_REF_NA (dv + 1);
  else if (DV_INT64 == dv[0])
    i = INT64_REF_NA (dv + 1);
  else
    return 0;
  ((int64 *) target->dc_values)[target->dc_n_values++] = i;
  return 1;
}


int
vc_anynn_any (data_col_t * target, data_col_t * source, int row, caddr_t * err_ret)
{
  db_buf_t dv = ((db_buf_t *) source->dc_values)[row];
  GPF_T1 ("vc_anynn_any should not be called, does not handle the case of an any that has morphed to typed dc");
  if (DV_DB_NULL == dv[0])
    return 0;
  ((db_buf_t *) target->dc_values)[target->dc_n_values++] = dv;
  return 1;
}


int
dv_rdf_id_from_num (db_buf_t tmp, int64 ro_id)
{
  if (ro_id > INT32_MAX || ro_id < INT32_MIN)
    {
      tmp[0] = DV_RDF_ID_8;
      INT64_SET_NA (&tmp[1], ro_id);
      return 9;
    }
  else
    {
      tmp[0] = DV_RDF_ID;
      LONG_SET_NA (&tmp[1], ro_id);
      return 5;
    }
}


int
vc_anynn (data_col_t * target, data_col_t * source, int row, caddr_t * err_ret)
{
  caddr_t box;
  int64 ro_id;
  int len;
  dtp_t tmp[10];
  if (DCT_BOXES & source->dc_type)
    {
      caddr_t box = ((caddr_t *) source->dc_values)[row];
      dtp_t dtp = DV_TYPE_OF (box);
      if (DV_DB_NULL == dtp)
	return 0;
      if (DV_RDF == dtp && (ro_id = ((rdf_box_t *) box)->rb_ro_id))
	{
	  len = dv_rdf_id_from_num (tmp, ro_id);
	  dc_append_bytes (target, tmp, len, NULL, 0);
	}
      else
	dc_append_box (target, box);
      return 1;
    }
  if (DV_ANY == source->dc_dtp)
    {
      db_buf_t dv = ((db_buf_t *) source->dc_values)[row];
      if (DV_DB_NULL == *dv)
	return 0;
      if (DV_RDF == *dv && (ro_id = rbs_ro_id (dv)))
	{
	  len = dv_rdf_id_from_num (tmp, ro_id);
	  dc_append_bytes (target, tmp, len, NULL, 0);
	  return 1;
	}
      DB_BUF_TLEN (len, *dv, dv);
      dc_append_bytes (target, dv, len, NULL, 0);
      return 1;
    }
  if (source->dc_any_null && DC_IS_NULL (source, row))
    return 0;
  box = dc_box (source, row);
  /* no need to check for rdf type since one like that can only come from an any dc or a box dc */
  dc_append_box (target, box);
  dk_free_tree (box);
  return 1;
}


int
vc_anynn_generic (data_col_t * target, data_col_t * source, int row, caddr_t * err_ret)
{
  dtp_t dtp;
  caddr_t box;
  int box_allocd = 0;
  if (DV_ANY == target->dc_sqt.sqt_col_dtp)
    return vc_anynn (target, source, row, err_ret);
  if (DCT_BOXES & source->dc_type)
    {
      box = ((caddr_t *) source->dc_values)[row];
      if (DV_DB_NULL == DV_TYPE_OF (box))
	return 0;
    }
  else
    {
      if (source->dc_any_null && DC_IS_NULL (source, row))
	return 0;
      box = dc_box (source, row);
      box_allocd = 1;
    }
  dtp = DV_TYPE_OF (box);
  if (dtp != target->dc_sqt.sqt_col_dtp)
    {
      caddr_t data =
	  box_cast_to (NULL, box, DV_TYPE_OF (box), target->dc_sqt.sqt_col_dtp, target->dc_sqt.sqt_precision,
	  target->dc_sqt.sqt_scale, err_ret);
      if (box_allocd)
	dk_free_tree (box);
      if (err_ret[0] != NULL)
	return 0;
      dc_append_box (target, data);
      dk_free_tree (data);
      return 1;
    }
  dc_append_box (target, box);
  if (box_allocd)
    dk_free_tree (box);
  return 1;
}


int
vc_generic (data_col_t * target, data_col_t * source, int row, caddr_t * err_ret)
{
  int prec = target->dc_sqt.sqt_precision, scale = target->dc_sqt.sqt_scale;
  caddr_t box = dc_box (source, row);
  caddr_t box2;
  if (DV_DB_NULL == DV_TYPE_OF (box) && target->dc_sqt.sqt_non_null)
    {
      dk_free_box (box);
      return 0;
    }
  if (DV_NUMERIC == target->dc_dtp)
    {
      prec = NUMERIC_MAX_PRECISION;
      scale = NUMERIC_MAX_SCALE;
    }
  box2 = box_cast_to (NULL, box, DV_TYPE_OF (box), target->dc_dtp, prec, scale, err_ret);
  if (*err_ret)
    {
      dk_free_tree (box);
      return 0;
    }
  dc_append_box (target, box2);
  dk_free_tree (box);
  dk_free_tree (box2);
  return 1;
}


int
vc_box_copy (data_col_t * target, data_col_t * source, int row, caddr_t * err_ret)
{
  caddr_t box = ((caddr_t *) source->dc_values)[row];
  if (DV_DB_NULL == DV_TYPE_OF (box))
    return 0;
  ((caddr_t *) target->dc_values)[target->dc_n_values++] = box_copy_tree (box);
  return 1;
}


dc_val_cast_t
vc_to_any (dtp_t dtp)
{
  switch (dtp)
    {
    case DV_IRI_ID:
      return vc_anynn_iri;
    default:
      return vc_anynn_generic;
    }
}


void
dc_pop_last (data_col_t * dc)
{
  dc->dc_n_values--;
  if (DCT_NUM_INLINE & dc->dc_type)
    return;
  if (DCT_BOXES & dc->dc_type && !(DCT_REF & dc->dc_type))
    dk_free_tree (((caddr_t *) dc->dc_values)[dc->dc_n_values]);
  else if (DV_ANY == dc->dc_dtp)
    {
      dc->dc_buf_fill = ((db_buf_t *) dc->dc_values)[dc->dc_n_values] - dc->dc_buffer;
    }
}


void
qst_set_all (caddr_t * inst, state_slot_t * ssl, caddr_t val)
{
  QNCAST (query_instance_t, qi, inst);
  db_buf_t set_mask = qi->qi_set_mask;
  int set, first_set = 0, n_sets = qi->qi_n_sets;
  if (SSL_VEC != ssl->ssl_type)
    {
      qst_set_over (inst, ssl, val);
      return;
    }
  SET_LOOP qst_set_copy (inst, ssl, val);
  END_SET_LOOP;
}


void
qst_set_null (caddr_t * inst, state_slot_t * ssl)
{
  if (SSL_VEC == ssl->ssl_type)
    {
      QNCAST (query_instance_t, qi, inst);
      data_col_t *dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
      dc_set_null (dc, qi->qi_set);
    }
  else
    qst_set_bin_string (inst, ssl, (db_buf_t) "", 0, DV_DB_NULL);
}


void
dc_set_all_null (data_col_t * dc, int n_sets, db_buf_t set_mask)
{
  int n_bytes = ALIGN_8 (n_sets) / 8, inx;
  DC_CHECK_LEN (dc, n_sets);
  if (dc->dc_nulls)
    {
      if (set_mask)
	{
	  for (inx = 0; inx < n_bytes; inx++)
	    dc->dc_nulls[inx] |= set_mask[inx];
	}
      else
	{
	  memset (dc->dc_nulls, 0xff, n_bytes);
	}
    }
  else if (DCT_BOXES & dc->dc_type)
    {
      int inx;
      DC_FILL_TO (dc, caddr_t, n_sets);
      for (inx = 0; inx < n_sets; inx++)
	{
	  if (IS_SET_MASK (set_mask, inx))
	    ((caddr_t *) dc->dc_values)[inx] = dk_alloc_box (0, DV_DB_NULL);
	}
      dc->dc_n_values = MAX (n_sets, dc->dc_n_values);
    }
  else if (DV_ANY == dc->dc_dtp)
    {
      dtp_t dt = DV_DB_NULL;
      int inx;
      int save = dc->dc_n_values;
      DC_FILL_TO (dc, caddr_t, n_sets);
      for (inx = 0; inx < n_sets; inx++)
	{
	  if (IS_SET_MASK (set_mask, inx))
	    {
	      dc->dc_n_values = inx;
	      dc_append_bytes (dc, &dt, 1, NULL, 0);
	    }
	}
      dc->dc_n_values = MAX (n_sets, save);
    }
  else
    GPF_T1 ("qst set all null to dc that is not nullable");
}


caddr_t
box_mt_copy_tree (caddr_t box)
{
  if (!IS_BOX_POINTER (box))
    return box;
  switch (DV_TYPE_OF (box))
    {
    case DV_RDF:
      {
	int len = box_length (box);
	rdf_bigbox_t *cp = sizeof (rdf_bigbox_t) == len ? rbb_allocate () : (rdf_bigbox_t *) rb_allocate ();
	memcpy_16 (cp, box, len);
	cp->rbb_base.rb_box = box_copy_tree (cp->rbb_base.rb_box);
	cp->rbb_base.rb_ref_count = 1;
	if (cp->rbb_base.rb_chksum_tail)
	  cp->rbb_chksum = box_copy_tree (cp->rbb_chksum);
	return (caddr_t) cp;
      }
    case DV_ARRAY_OF_POINTER:
      {
	int len = BOX_ELEMENTS (box), inx;
	caddr_t *cp = (caddr_t *) dk_alloc_box (len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	for (inx = 0; inx < len; inx++)
	  cp[inx] = box_mt_copy_tree (((caddr_t *) box)[inx]);
	return (caddr_t) cp;
    default:
	return box_copy (box);
      }
    }
}


void
dc_copy (data_col_t * target, data_col_t * source)
{
  int inx, sz = 0;
  if (DV_ANY == target->dc_dtp && DV_ANY != source->dc_dtp)
    dc_convert_empty (target, source->dc_dtp);
  DC_CHECK_LEN (target, source->dc_n_values - 1);
  if (source->dc_nulls)
    {
      if (!target->dc_nulls)
	dc_ensure_null_bits (target);
      memcpy_16_nt (target->dc_nulls, source->dc_nulls, ALIGN_8 (source->dc_n_values) / 8);
      target->dc_any_null = 1;
    }
  target->dc_n_values = source->dc_n_values;
  if (DCT_BOXES == source->dc_type)
    {
      for (inx = 0; inx < source->dc_n_values; inx++)
	((caddr_t *) target->dc_values)[inx] = box_mt_copy_tree (((caddr_t *) source->dc_values)[inx]);
      return;
    }
  if (DV_ANY == source->dc_dtp)
    {
      target->dc_n_values = 0;
      for (inx = 0; inx < source->dc_n_values; inx++)
	{
	  db_buf_t dv = ((db_buf_t *) source->dc_values)[inx];
	  if (dv)
	    {
	      int l;
	      DB_BUF_TLEN (l, dv[0], dv);
	      dc_append_bytes (target, dv, l, NULL, 0);
	    }
	  else
	    ((db_buf_t *) target->dc_values)[target->dc_n_values++] = NULL;
	}
      return;
    }

  if (DCT_NUM_INLINE & source->dc_type)
    sz = DV_SINGLE_FLOAT == source->dc_dtp ? sizeof (float) : sizeof (int64);
  else
    {
      sz = sqt_fixed_length (&source->dc_sqt);
      if (sz <= 0)
	GPF_T1 ("expect fixed length dtp ion dc copy");
    }
  memcpy_16_nt (target->dc_values, source->dc_values, sz * source->dc_n_values);
}


void
dc_assign (caddr_t * inst, state_slot_t * ssl_to, int row_to, state_slot_t * ssl_from, int row_from)
{
  state_slot_t tmp;
  caddr_t box;
  int save;
  data_col_t *target = QST_BOX (data_col_t *, inst, ssl_to->ssl_index);
  data_col_t *source = QST_BOX (data_col_t *, inst, ssl_from->ssl_index);
  QNCAST (query_instance_t, qi, inst);
  if (SSL_REF == ssl_from->ssl_type)
    row_from = sslr_set_no (inst, ssl_from, row_from);
  if (SSL_VEC != ssl_to->ssl_type)
    goto general;
  if ((DCT_BOXES & target->dc_type) || (DCT_BOXES & source->dc_type))
    goto general;
  DC_CHECK_LEN (target, row_to);
  if (!(SSL_VEC == ssl_from->ssl_type || SSL_REF == ssl_from->ssl_type))
    goto general;
  if (DV_ANY == target->dc_dtp)
    {
      DC_FILL_TO (target, caddr_t, row_to);
    }
  if (target->dc_type == source->dc_type && target->dc_dtp == source->dc_dtp)
    {
      if (source->dc_dtp == DV_ANY)
	{
	  db_buf_t dv = ((db_buf_t *) source->dc_values)[row_from];
	  ((db_buf_t *) target->dc_values)[row_to] = dv;
	  if (source->dc_any_null && DV_DB_NULL == *dv)
	    target->dc_any_null = 1;
	}
      else
	{
	  int elt_sz = dc_elt_size (source);
	    memcpy_16 (target->dc_values + row_to * elt_sz, source->dc_values + row_from * elt_sz, elt_sz);
	}
      if (row_to >= target->dc_n_values)
	target->dc_n_values = row_to + 1;
      if (source->dc_nulls && DC_IS_NULL (source, row_from))
	{
	  if (!target->dc_nulls)
	    dc_ensure_null_bits (target);
	  DC_SET_NULL (target, row_to);
	}
      return;
    }
general:
  save = qi->qi_set;
  if (SSL_REF == ssl_from->ssl_type)
    {
      state_slot_t *ssl_from2 = ((state_slot_ref_t *) ssl_from)->sslr_ssl;
      if (ssl_from2->ssl_index != ssl_from->ssl_index)
	{
	  tmp = *ssl_from2;
	  tmp.ssl_index = ssl_from->ssl_index;
	  tmp.ssl_box_index = ssl_from->ssl_box_index;
	  ssl_from = &tmp;
	}
      else
	ssl_from = ssl_from2;
    }
  qi->qi_set = row_from;	/* the indirections are counted, so for a ref use the org ssl */
  box = QST_GET (inst, ssl_from);
  qi->qi_set = row_to;
  qst_set_copy (inst, ssl_to, box);
  qi->qi_set = save;
}


void
dc_heterogenous (data_col_t * dc)
{
  /* change a typed dc into an any, change the values */
  dtp_t tmp[DT_LENGTH + 1];
  int inx, n = dc->dc_n_values;
  switch (dc->dc_dtp)
    {
    case DV_LONG_INT:
      dc->dc_n_values = 0;
      for (inx = 0; inx < n; inx++)
	{
	  dv_from_int (tmp, ((int64 *) dc->dc_values)[inx]);
	  dc_append_bytes (dc, tmp, db_buf_const_length[tmp[0]], NULL, 0);
	}
      break;
    case DV_IRI_ID:
      dc->dc_n_values = 0;
      for (inx = 0; inx < n; inx++)
	{
	  dv_from_iri (tmp, ((int64 *) dc->dc_values)[inx]);
	  dc_append_bytes (dc, tmp, db_buf_const_length[tmp[0]], NULL, 0);
	}
      break;
    case DV_DOUBLE_FLOAT:
      dc->dc_n_values = 0;
      tmp[0] = DV_DOUBLE_FLOAT;
      for (inx = 0; inx < n; inx++)
	{
	  int64 f = ((int64 *) dc->dc_values)[inx];
	  INT64_SET_NA (&tmp[1], f);
	  dc_append_bytes (dc, tmp, sizeof (double) + 1, NULL, 0);
	}
      break;

    case DV_SINGLE_FLOAT:
      dc->dc_n_places /= 2;
      dc->dc_n_values = ALIGN_2 (n) / 2;
      dc->dc_dtp = DV_DOUBLE_FLOAT;
      DC_CHECK_LEN (dc, n);
      tmp[0] = DV_SINGLE_FLOAT;
      for (inx = n - 1; inx >= 0; inx--)
	{
	  int f = ((int32 *) dc->dc_values)[inx];
	  LONG_SET_NA (&tmp[1], f);
	  dc->dc_n_values = inx;
	  dc_append_bytes (dc, tmp, 5, NULL, 0);
	}
      dc->dc_n_values = n;
      break;
    case DV_DATETIME:
      dc->dc_n_places = dc->dc_n_places * DT_LENGTH / sizeof (caddr_t);
      tmp[0] = DV_DATETIME;
      for (inx = 0; inx < n; inx++)
	{
	  memcpy_dt (&tmp[1], dc->dc_values + DT_LENGTH * inx);
	  /*dc_any_trap (tmp); */
	  dc->dc_n_values = inx;
	  dc_append_bytes (dc, tmp, 1 + DT_LENGTH, NULL, 0);
	}
      break;
    default:
      GPF_T1 ("making a typed dc of unsupported type into heterogenous");
    }
  dc->dc_n_values = n;
  if (dc->dc_nulls)
    {
      for (inx = 0; inx < n; inx++)
	{
	  if (DC_IS_NULL (dc, inx))
	    *((db_buf_t *) dc->dc_values)[inx] = DV_DB_NULL;
	}
      dc->dc_org_nulls = dc->dc_nulls;
      dc->dc_nulls = NULL;
    }
  dc->dc_dtp = DV_ANY;
  dc->dc_type = 0;
  dc->dc_sort_cmp = dc_any_cmp;
}


void
dc_convert_empty (data_col_t * dc, dtp_t dtp)
{
  int needed, len, prev_elt_sz, min_places;
  if (dc->dc_dtp == dtp)
    return;
  dtp = dtp_canonical[dtp];
  switch (dtp)
    {
    case DV_LONG_INT:
    case DV_IRI_ID:
    case DV_DATETIME:
    case DV_SINGLE_FLOAT:
    case DV_DOUBLE_FLOAT:
      break;
    default:
      dtp = DV_ANY;
      break;
    }
  prev_elt_sz = dc_elt_size (dc);
  dc->dc_dtp = dtp;
  min_places = dc->dc_min_places ? dc->dc_min_places : (dc->dc_min_places = dc->dc_n_places);
  needed = dc_elt_size (dc) * min_places;
  len = prev_elt_sz * dc->dc_n_places;
  if (len < needed)
    dc->dc_values = (db_buf_t) mp_alloc_box (dc->dc_mp, needed, DV_NON_BOX);
  else if (len > needed)
    dc->dc_n_places = len / dc_elt_size (dc);
  dc_set_flags (dc, &dc->dc_sqt, 0);
}


void
vec_ssl_assign (caddr_t * inst, state_slot_t * ssl_to, state_slot_t * ssl_from)
{
  int sets[ARTM_VEC_LEN];
  int org_sets[ARTM_VEC_LEN];
  QNCAST (query_instance_t, qi, inst);
  int first_set = 0, set1, qi_n_sets = qi->qi_n_sets;
  db_buf_t set_mask = qi->qi_set_mask;
  int set = 0;
  data_col_t *dc_to = QST_BOX (data_col_t *, inst, ssl_to->ssl_index);
  data_col_t *dc_from = QST_BOX (data_col_t *, inst, ssl_from->ssl_index);
  if (SSL_VEC != ssl_to->ssl_type || DCT_BOXES & dc_to->dc_type)
    goto general;

  if (!set_mask && SSL_VEC == ssl_from->ssl_type)
    {
      if (DV_ANY != dc_from->dc_dtp && !dc_to->dc_n_values)
	dc_convert_empty (dc_to, dv_ce_dtp[dc_from->dc_dtp]);
      if (dc_to->dc_dtp == dc_from->dc_dtp && dc_to->dc_type == dc_from->dc_type)
	{
	  int sz = dc_elt_size (dc_from);
	  DC_CHECK_LEN (dc_to, qi_n_sets - 1);
	  memcpy_16 (dc_to->dc_values, dc_from->dc_values, sz * dc_from->dc_n_values);
	  dc_to->dc_n_values = dc_from->dc_n_values;
	  dc_to->dc_any_null = dc_from->dc_any_null;
	  if (dc_from->dc_any_null && DC_HAS_NULL_BITS (dc_from))
	    {
	      dc_ensure_null_bits (dc_to);
	      memcpy_16 (dc_to->dc_nulls, dc_from->dc_nulls, ALIGN_8 (dc_from->dc_n_values) / 8);
	    }
	  return;
	}
      goto general;
    }
  if (SSL_REF == ssl_from->ssl_type)
    {
      if (!set_mask && !dc_to->dc_n_values && DV_ANY != dc_from->dc_dtp)
	{
	  dc_convert_empty (dc_to, dv_ce_dtp[dc_from->dc_dtp]);
	}
      if (dc_to->dc_dtp == dc_from->dc_dtp && dc_to->dc_type == dc_from->dc_type)
	{
	  int last_assigned = 0;
	  int sz = dc_elt_size (dc_from);
	  DC_CHECK_LEN (dc_to, qi_n_sets - 1);
	  if (DV_ANY == dc_to->dc_dtp)
	    {
	      DC_FILL_TO (dc_to, caddr_t, qi->qi_n_sets - 1);
	    }
	  for (set = 0; set < qi_n_sets; set += 256)
	    {
	      int n_sets_1;
	      if (!set_mask)
		{
		  n_sets_1 = MIN (set + 256, qi->qi_n_sets) - set;
		  sslr_n_consec_ref (inst, (state_slot_ref_t *) ssl_from, sets, set, n_sets_1);
		  int_asc_fill (org_sets, n_sets_1, set);
		}
	      else
		{
		  int fill = 0, set1, limit = MIN (set + 256, qi->qi_n_sets);
		  for (set1 = set; set1 < limit; set1++)
		    if (QI_IS_SET (qi, set1))
		      sets[fill++] = set1;
		  n_sets_1 = fill;
		  memcpy_16 (org_sets, sets, n_sets_1 * sizeof (int));
		  sslr_n_ref (inst, (state_slot_ref_t *) ssl_from, sets, n_sets_1);
		}
	      if (n_sets_1)
		last_assigned = org_sets[n_sets_1 - 1];
	      switch (sz)
		{
		case 8:
		  for (set1 = 0; set1 < n_sets_1; set1++)
		    ((int64 *) dc_to->dc_values)[org_sets[set1]] = ((int64 *) dc_from->dc_values)[sets[set1]];
		  break;
		case 4:
		  for (set1 = 0; set1 < n_sets_1; set1++)
		    ((int32 *) dc_to->dc_values)[org_sets[set1]] = ((int32 *) dc_from->dc_values)[sets[set1]];
		  break;
		case DT_LENGTH:
		  for (set1 = 0; set1 < n_sets_1; set1++)
		    memcpy_dt (dc_to->dc_values + DT_LENGTH * org_sets[set1], dc_from->dc_values + DT_LENGTH * sets[set1]);
		  break;
		}
	      if (!dc_from->dc_any_null)
		continue;
	      if (!DC_HAS_NULL_BITS (dc_from))
		continue;
	      dc_ensure_null_bits (dc_to);
	      for (set1 = 0; set1 < n_sets_1; set1++)
		{
		  if (DC_IS_NULL (dc_from, sets[set1]))
		    {
		      DC_SET_NULL (dc_to, org_sets[set1]);
		      dc_to->dc_any_null = 1;
		    }
		}
	    }
	  if (last_assigned >= dc_to->dc_n_values)
	    dc_to->dc_n_values = last_assigned + 1;
	  return;
	}
      goto general;
    }


general:
  {
    int n_sets = qi_n_sets;
    SET_LOOP
    {
      if (ssl_from->ssl_type != SSL_VEC && ssl_from->ssl_type != SSL_REF)
	qst_set_copy (inst, ssl_to, QST_GET (inst, ssl_from));
      else
	dc_assign (inst, ssl_to, qi->qi_set, ssl_from, qi->qi_set);
    }
    END_SET_LOOP;
  }
}


void
vec_qst_set_temp_box (caddr_t * qst, state_slot_t * ssl, caddr_t data)
{
  if (!ssl->ssl_box_index)
    GPF_T1 ("vec/ref  ssl with no box index");
  dk_free_tree (qst[ssl->ssl_box_index]);
  qst[ssl->ssl_box_index] = data;
}

db_buf_t
itcp (it_cursor_t * itc, int ip, int set)
{
  data_col_t *dc = ITC_P_VEC (itc, ip);
  if (!dc)
    return (db_buf_t) itc->itc_search_params[ip];
  return ((db_buf_t *) dc->dc_values)[itc->itc_param_order[set]];
}

int
qi_sets_identical (caddr_t * inst, state_slot_t * ssl)
{
  if (SSL_VEC == ssl->ssl_type || SSL_REF == ssl->ssl_type)
    {
      data_col_t *dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
      if (dc->dc_n_values != 1)
	return 0;
    }
  return 1;
}


void
dcp (data_col_t * dc, int n1, int n2)
{
  int inx;
  if (!IS_BOX_POINTER (dc) || DV_DATA != box_tag (dc))
    {
      printf ("%p Not a dc\n", dc);
      return;
    }
  printf ("dc dtp %d type %d %d values %d places\n", (int) dc->dc_dtp, dc->dc_type, dc->dc_n_values, dc->dc_n_places);
  for (inx = n1; inx < MIN (n2, dc->dc_n_values); inx++)
    {
      if (!((inx - n1) % 10))
	printf (" %d: ", inx);
      if (((DCT_NUM_INLINE & dc->dc_type) || (DV_DATETIME == dtp_canonical[dc->dc_dtp])) && dc->dc_nulls && DC_IS_NULL (dc, inx))
	printf ("NULL\n");
      else if (DCT_BOXES & dc->dc_type)
	sqlo_box_print (((caddr_t *) dc->dc_values)[inx]);
      else if (DV_ANY == dc->dc_dtp)
	{
	  db_buf_t dv = ((db_buf_t *) dc->dc_values)[inx];
	  caddr_t b;
	  if (!IS_BOX_POINTER (dv))
	    {
	      printf ("*** non-pointer dv %d\n", (int) (ptrlong) dv);
	    }
	  else
	    {
	      b = box_deserialize_string ((caddr_t) dv, INT32_MAX, 0);
	      sqlo_box_print (b);
	      dk_free_box (b);
	    }
	}
      else if (DV_SINGLE_FLOAT == dc->dc_dtp)
	printf ("%g\n", ((float *) dc->dc_values)[inx]);
      else if (DV_DOUBLE_FLOAT == dc->dc_dtp)
	printf ("%g\n", ((double *) dc->dc_values)[inx]);
      else if (DCT_NUM_INLINE & dc->dc_type)
	printf (BOXINT_FMT "\n", ((int64 *) dc->dc_values)[inx]);
      else if (DV_DATETIME == dtp_canonical[dc->dc_dtp])
	dt_print ((caddr_t) dc->dc_values + DT_LENGTH * inx);
      else
	printf (" dc type not printable\n");
    }
}


void
ssl_dcp_sm (caddr_t * inst, state_slot_t * ssl, int n1, int n2, int use_sets)
{
  QNCAST (QI, qi, inst);
  int inx2;
  data_col_t *dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
  if (!IS_BOX_POINTER (dc) || DV_DATA != box_tag (dc))
    {
      printf ("%p Not a dc\n", dc);
      return;
    }
  printf ("dc dtp %d type %d %d values %d places\n", (int) dc->dc_dtp, dc->dc_type, dc->dc_n_values, dc->dc_n_places);
  for (inx2 = n1; inx2 < n2; inx2++)
    {
      int inx = inx2;
      if (use_sets)
	{
	  if (!QI_IS_SET (qi, inx))
	    continue;
	  printf ("%d: ", inx2);
	}
      else
	{
      if (!((inx2 - n1) % 10))
	printf (" %d: ", inx2);
	}
      if (SSL_REF == ssl->ssl_type)
	{
	  QNCAST (state_slot_ref_t, sslr, ssl);
	  int step;
	  for (step = 0; step < sslr->sslr_distance; step++)
	    {
	      int *set_nos = QST_BOX (int *, inst, sslr->sslr_set_nos[step]);
	      int n_set_nos = box_length (set_nos) / sizeof (int);
	      if (inx >= n_set_nos)
		{
		  printf ("ref chain out of range\n");
		  goto next;
		}
	      inx = set_nos[inx];
	    }
	}
      if (inx >= dc->dc_n_values)
	{
	  printf ("inx after refs %d is after dc fill", inx);
	  return;
	}
      if (((DCT_NUM_INLINE & dc->dc_type) || (DV_DATETIME == dtp_canonical[dc->dc_dtp])) && dc->dc_nulls && DC_IS_NULL (dc, inx))
	printf ("NULL\n");
      else if (DCT_BOXES & dc->dc_type)
	sqlo_box_print (((caddr_t *) dc->dc_values)[inx]);
      else if (DV_ANY == dc->dc_dtp)
	{
	  db_buf_t dv = ((db_buf_t *) dc->dc_values)[inx];
	  caddr_t b = box_deserialize_string ((caddr_t) dv, INT32_MAX, 0);
	  sqlo_box_print (b);
	  dk_free_box (b);
	}
      else if (DV_SINGLE_FLOAT == dc->dc_dtp)
	printf ("%g\n", ((float *) dc->dc_values)[inx]);
      else if (DV_DOUBLE_FLOAT == dc->dc_dtp)
	printf ("%g\n", ((double *) dc->dc_values)[inx]);
      else if (DCT_NUM_INLINE & dc->dc_type)
	printf (BOXINT_FMT "\n", ((int64 *) dc->dc_values)[inx]);
      else if (DV_DATETIME == dtp_canonical[dc->dc_dtp])
	dt_print ((caddr_t) dc->dc_values + DT_LENGTH * inx);
      else
	printf (" dc type not printable\n");
    next:;
    }
}


void
ssl_dcp (caddr_t * inst, state_slot_t * ssl, int n1, int n2)
{
  ssl_dcp_sm (inst, ssl, n1, n2, 0);
}


void
dcp_nz (data_col_t * dc)
{
  int inx, first = -1, last = -1, n = 0;
  int64 s = 0, v;
  for (inx = 0; inx < dc->dc_n_values; inx++)
    {
      if ((v = (((int64 *) dc->dc_values)[inx])))
	{
	  if (-1 == first)
	    first = inx;
	  last = inx;
	  n++;
	  s += v;
	}
    }
  if (s != n)
    bing ();
  printf ("first %d last %d n %d sum %d\n", first, last, n, (int) s);
}


void
dcp_find (data_col_t * dc, int64 x)
{
  int inx, first = -1, last = -1, n = 0;
  for (inx = 0; inx < dc->dc_n_values; inx++)
    {
      if (x == (((int64 *) dc->dc_values)[inx]))
	{
	  if (-1 == first)
	    first = inx;
	  last = inx;
	  n++;
	}
    }
  printf ("first %d last %d n %d \n", first, last, n);
}

void
anyp (db_buf_t a)
{
  sqlo_box_print (box_deserialize_string ((caddr_t) a, INT32_MAX, 0));
}

void
dc_stats (data_col_t * dc, slice_id_t * slices, slice_id_t slid)
{
  int inx, longest_inx = -1, longest = 0, total = 0;
  if (!(DCT_BOXES & dc->dc_type))
    return;
  for (inx = 0; inx < dc->dc_n_values; inx++)
    {
      caddr_t box;
      int len;
      if (slices && slices[inx] != slid)
	continue;
      box = ((caddr_t *) dc->dc_values)[inx];
      len = box_serial_length (box, 0);
      total += len;
      if (len > longest)
	{
	  longest = len;
	  longest_inx = inx;
	}
    }
  printf ("total %d, longest %d at %d\n", total, longest, longest_inx);
}

void
qst_set_with_ref (caddr_t * inst, state_slot_t * ssl, caddr_t val)
{
  if (SSL_REF == ssl->ssl_type)
    {
      QNCAST (state_slot_ref_t, sslr, ssl);
      QNCAST (QI, qi, inst);
      int save = qi->qi_set;
      int set_no = sslr_set_no (inst, ssl, qi->qi_set);
      state_slot_t *org_ssl = sslr->sslr_ssl;
      if (SSL_VEC != org_ssl->ssl_type || sslr->ssl_index != org_ssl->ssl_index)
	GPF_T1 ("assigning ssl ref where org is not vec or has different ssl index from ref");
      qi->qi_set = set_no;
      qst_set (inst, org_ssl, val);
      qi->qi_set = save;
    }
  else
    qst_set (inst, ssl, val);
}

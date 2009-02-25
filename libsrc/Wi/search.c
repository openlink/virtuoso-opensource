/*
 *  search.c
 *
 *  $Id$
 *
 *  Search
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
#include "sqlfn.h"
#include "arith.h"
#include "multibyte.h"
#include "srvmultibyte.h"
#include "xmlnode.h"
#include "sqlbif.h"
#include "srvstat.h"


short db_buf_const_length[256];

int  itc_random_leaf (it_cursor_t * itc, buffer_desc_t *buf, dp_addr_t * leaf_ret);
int itc_down_rnd_check (it_cursor_t * itc, dp_addr_t leaf);
int itc_up_rnd_check (it_cursor_t * itc, buffer_desc_t ** buf_ret);

void
const_length_init (void)
{
  db_buf_const_length[DV_SHORT_INT] = 2;
  db_buf_const_length[DV_LONG_INT] = 5;
  db_buf_const_length[DV_DB_NULL] = 1;
  db_buf_const_length[DV_SINGLE_FLOAT] = 5;
  db_buf_const_length[DV_DOUBLE_FLOAT] = 9;
  db_buf_const_length[DV_SHORT_STRING] = -1;
  db_buf_const_length[DV_BIN] = -1;
  db_buf_const_length[DV_DATETIME] = DT_LENGTH + 1;
  db_buf_const_length[DV_NUMERIC] = -1;
  db_buf_const_length[DV_WIDE] = -1;
  db_buf_const_length[DV_COMPOSITE] = -1;
  db_buf_const_length[DV_BLOB] = 9;
  db_buf_const_length[DV_BLOB_WIDE] = 9;
}


void
db_buf_length (unsigned char *buf, long *head_ret, long *len_ret)
{
  buffer_desc_t *bd;

  /* Given a char * returns the length of header and the length of data. */
  switch (*buf)
    {
    case DV_BIN:
    case DV_WIDE:
    case DV_SHORT_STRING_SERIAL:
    case DV_SHORT_CONT_STRING:
    case DV_NUMERIC:
    case DV_COMPOSITE:
      *head_ret = 2;
      *len_ret = buf[1];
      break;

    case DV_LONG_STRING:
    case DV_LONG_WIDE:
    case DV_LONG_CONT_STRING:
    case DV_LONG_BIN:
      *head_ret = 5;
      *len_ret = LONG_REF ((buf + 1));
      break;

    case DV_NULL:
    case DV_DB_NULL:
      *head_ret = 1;
      *len_ret = 0;
      break;

    case DV_SHORT_INT:
    case DV_CHARACTER:
      *head_ret = 1;
      *len_ret = 1;
      break;

    case DV_LONG_INT:
    case DV_SINGLE_FLOAT:
    case DV_OBJECT_REFERENCE:
      *head_ret = 1;
      *len_ret = 4;
      break;

    case DV_DOUBLE_FLOAT:
    case DV_OBJECT_AND_CLASS:
    case DV_BLOB:
    case DV_BLOB_WIDE:
    case DV_BLOB_XPER:
    case DV_ROW_EXTENSION:
      *head_ret = 1;
      *len_ret = 8;
      break;

    case DV_C_SHORT:
      *head_ret = 1;
      *len_ret = 2;
      break;

    case DV_ARRAY_OF_LONG:
    case DV_ARRAY_OF_FLOAT:
      if (DV_SHORT_INT == buf[1])
	{
	  *head_ret = 3;
	  *len_ret = (long) (buf[2]) * 4;
	}
      else
	{
	  *head_ret = 6;
	  *len_ret = LONG_REF ((buf + 2)) * 4;
	}
      break;
    case DV_ARRAY_OF_DOUBLE:
      if (DV_SHORT_INT == buf[1])
	{
	  *head_ret = 3;
	  *len_ret = (long) (buf[2]) * 8;
	}
      else
	{
	  *head_ret = 6;
	  *len_ret = LONG_REF ((buf + 2)) * 8;
	}
      break;
    case DV_DATETIME:
      *head_ret = 1;
      *len_ret = DT_LENGTH;
      break;
    case DV_RDF:
      *head_ret = 1;
      *len_ret = rbs_length (buf);
      break;
    default:
      /* Report */
      bd = NULL;
      dbg_page_structure_error (bd, buf);
#if 0 /*obsoleted */
      if (null_bad_dtp)
	{
	  /* Correct situation */
	  *head_ret = 1;
	  *len_ret = 0;
	  if (bd != NULL)
	    {
	      *buf = DV_DB_NULL;
	      bd->bd_is_dirty = 1;
	      log_info ("Page structure problem corrected");
	      return;
	    }
	}
#endif
      STRUCTURE_FAULT;		/* Bad dtp */
    }
}


int
box_serial_length (caddr_t box, dtp_t dtp)
{
  if (0 == dtp)
    dtp = DV_TYPE_OF (box);
  switch (dtp)
    {
    case DV_LONG_INT:
    case DV_SHORT_INT:
      {
	ptrlong n = IS_BOX_POINTER (box) ? *(ptrlong *) box : (ptrlong) box;
	if ((n > -128) && (n < 128))
	  return 2;
	else
	  return 5;
      }
    case DV_LONG_STRING:
      {
	int len = box_length (box);
	return (len > 256 ? len + 4 : len + 1); /* count the trailing 0 incl. in the box length */
      }
    case DV_SINGLE_FLOAT:
      return 5;
    case DV_DOUBLE_FLOAT:
      return 9;
    case DV_DB_NULL:
      return 1;
    default:
      return -1;
    }
}


int pg_insert_key_compare (buffer_desc_t * buf, int pos, it_cursor_t * it);


long  tc_dive_cache_compares;

buffer_desc_t *
itc_dive_cache_check (it_cursor_t * itc)
{
  return NULL;
}


int
itc_col_check_1 (it_cursor_t * itc, search_spec_t * spec, int param_inx)
{
  collation_t * collation;
  int res;
  db_buf_t row = itc->itc_row_data;
  db_buf_t dv1, dv2;
  int off, n1, n2, inx;
  caddr_t param;
  if (spec->sp_cl.cl_null_mask)
    {
      if ((spec->sp_cl.cl_null_mask & itc->itc_row_data[spec->sp_cl.cl_null_flag]))
	{
	  if (itc->itc_search_param_null[param_inx])
	    return DVC_MATCH;
	  else
	    return DVC_LESS;
	}
      else
	{
	  if (itc->itc_search_param_null[param_inx])
	    return DVC_GREATER;
	}
    }
  switch (spec->sp_cl.cl_sqt.sqt_dtp)
    {
    case DV_LONG_INT:
      n1 = LONG_REF (row + spec->sp_cl.cl_pos);
    int_cmp:
      param = itc->itc_search_params[param_inx];
      switch (DV_TYPE_OF (param))
	{
	case DV_LONG_INT:
	  n2 = unbox_inline (param);
	  return NUM_COMPARE (n1, n2);
	case DV_SINGLE_FLOAT:
	  return cmp_double (((float)n1), *(float*) param, DBL_EPSILON);
	case DV_DOUBLE_FLOAT:
	  return cmp_double (((double)n1),  *(double*)param, DBL_EPSILON);
	case DV_NUMERIC:
	  {
	    NUMERIC_VAR (n);
	    numeric_from_int32 ((numeric_t) &n, n1);
	    return (numeric_compare_dvc ((numeric_t) &n, (numeric_t) param));
	  }
	default: 
	  {
	    log_error ("Unexpected param dtp=[%d]", DV_TYPE_OF (param));
	    GPF_T;
	  }
	}

    case DV_SHORT_INT:
      n1 = SHORT_REF (row + spec->sp_cl.cl_pos);
	      goto int_cmp;
    case DV_INT64:
      {
	boxint n2, n1 = INT64_REF (row + spec->sp_cl.cl_pos);
	param = itc->itc_search_params[param_inx];
	switch (DV_TYPE_OF (param))
	  {
	  case DV_LONG_INT:
	    n2 = unbox_inline (param);
	    return NUM_COMPARE (n1, n2);
	  case DV_SINGLE_FLOAT:
	    return cmp_double (((float)n1), *(float*) param, DBL_EPSILON);
	  case DV_DOUBLE_FLOAT:
	    return cmp_double (((double)n1),  *(double*)param, DBL_EPSILON);
	  case DV_NUMERIC:
	    {
	      NUMERIC_VAR (n);
	      numeric_from_int64 ((numeric_t) &n, n1);
	      return (numeric_compare_dvc ((numeric_t) &n, (numeric_t) param));
	    }
	  default: 
	    {
	      log_error ("Unexpected param dtp=[%d]", DV_TYPE_OF (param));
	      GPF_T;
	    }
	  }
      }

    case DV_DATETIME:
    case DV_TIMESTAMP:
    case DV_DATE:
    case DV_TIME:
      n1 = DT_COMPARE_LENGTH;
      dv1 = row + spec->sp_cl.cl_pos;
      dv2 = (db_buf_t) itc->itc_search_params[param_inx];
      for (inx = 0; inx < DT_COMPARE_LENGTH; inx++)
	{
	  if (dv1[inx] == dv2[inx])
	    continue;
	  if (dv1[inx] > dv2[inx])
	    return DVC_GREATER;
	  else
	    return DVC_LESS;
	}
      return DVC_MATCH;

    case DV_NUMERIC:
      {
	NUMERIC_VAR (n);
	numeric_from_buf ((numeric_t) &n, row + spec->sp_cl.cl_pos);
	param = itc->itc_search_params[param_inx];
	if (DV_DOUBLE_FLOAT == DV_TYPE_OF (param))
	  {
	    double d;
	    numeric_to_double ((numeric_t)&n, &d);
	    return cmp_double (d, *(double*) param, DBL_EPSILON);
	  }
	return (numeric_compare_dvc ((numeric_t) &n, (numeric_t) param));
      }
    case DV_SINGLE_FLOAT:
      {
	float flt;
	EXT_TO_FLOAT (&flt, row + spec->sp_cl.cl_pos);
	param = itc->itc_search_params[param_inx];
	switch (DV_TYPE_OF (param))
	  {
	  case DV_SINGLE_FLOAT:
	    return (cmp_double (flt, *(float *) param, FLT_EPSILON));
	  case DV_DOUBLE_FLOAT:
	    return (cmp_double (((double)flt), *(double *) param, DBL_EPSILON));
	  case DV_NUMERIC:
	    {
	      NUMERIC_VAR (n);
	      numeric_from_double ((numeric_t) &n, (double) flt);
	      return (numeric_compare_dvc ((numeric_t)&n, (numeric_t) param));
	    }
	  }
      }
    case DV_DOUBLE_FLOAT:
      {
	double dbl;
	EXT_TO_DOUBLE (&dbl, row + spec->sp_cl.cl_pos);
	/* if the col is double, any arg is cast to double */
	return (cmp_double (dbl, *(double *) itc->itc_search_params[param_inx], DBL_EPSILON));
      }
    case DV_IRI_ID:
      {
	iri_id_t i1 = (iri_id_t)(uint32) LONG_REF (row + spec->sp_cl.cl_pos);
	iri_id_t i2 =  unbox_iri_id (itc->itc_search_params[param_inx]);
	res = NUM_COMPARE (i1, i2);
	return res;
      }
    case DV_IRI_ID_8:
      {
	iri_id_t i1 = (iri_id_t) INT64_REF (row + spec->sp_cl.cl_pos);
	iri_id_t i2 =  unbox_iri_id (itc->itc_search_params[param_inx]);
	res = NUM_COMPARE (i1, i2);
	return res;
      }
    case DV_FIXED_STRING:
      n1 = spec->sp_cl.cl_fixed_len;
	dv1= row + spec->sp_cl.cl_pos;
	goto var_check;
    default:
      n1 = spec->sp_cl.cl_fixed_len;
      if (CL_FIRST_VAR == n1)
	{
	  dbe_key_t * key;
	  if (!itc->itc_row_key_id)
	    {
	      key = itc->itc_insert_key;
	      off = key->key_key_var_start;
	    }
	  else
	    {
	      ITC_REAL_ROW_KEY (itc);
	      key = itc->itc_row_key;
	      off = key->key_row_var_start;
	    }
	  n1 = SHORT_REF (row + key->key_length_area) - off;
	  dv1 = row + off;
	}
      else
	{
	  off = SHORT_REF (row - n1);
	  n1 = SHORT_REF ((row - n1) + 2) - off;
	  dv1 = row + off;
	}
    }
 var_check:
  switch (spec->sp_cl.cl_sqt.sqt_dtp)
    {
    case DV_BIN:
      dv2 = (db_buf_t) itc->itc_search_params[param_inx];
      n2 = box_length (dv2);
      inx = 0;
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
	  if (dv1[inx] < dv2[inx])
	    return DVC_LESS;
	  if (dv1[inx] > dv2[inx])
	    return DVC_GREATER;
	  inx++;
	}
      break;
    case DV_STRING:
      collation = spec->sp_collation;
      dv2 = (db_buf_t) itc->itc_search_params[param_inx];
      n2 = box_length_inline (dv2) - 1;
      inx = 0;
      if (collation)
	{
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
	      if (collation->co_table[(unsigned char)dv1[inx]] <
		  collation->co_table[(unsigned char)dv2[inx]])
		return DVC_LESS;
	      if (collation->co_table[(unsigned char)dv1[inx]] >
		  collation->co_table[(unsigned char)dv2[inx]])
		return DVC_GREATER;
	      inx++;
	    }
	}
      else
	{
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
	      if (dv1[inx] < dv2[inx])
		return DVC_LESS;
	      if (dv1[inx] > dv2[inx])
		return DVC_GREATER;
	      inx++;
	    }
	}
    case DV_WIDE:
    case DV_LONG_WIDE:
      {
	dv2 = (db_buf_t) itc->itc_search_params[param_inx];
	n2 = box_length (dv2) - sizeof (wchar_t);
	return compare_wide_to_utf8 ((caddr_t) dv1, n1, (caddr_t) dv2, n2, spec->sp_collation);
      }
    case DV_ANY:
      dv2 = (db_buf_t) itc->itc_search_params[param_inx];
      return (dv_compare (dv1, dv2, spec->sp_collation));
    default:
      GPF_T1 ("type not supported in comparison");
    }
  return 0;
}

#ifdef MALLOC_DEBUG
it_cursor_t *
dbg_itc_create (const char *file, int line, void * isp, lock_trx_t * trx)
{
  DBG_NEW_VAR (file, line, it_cursor_t, itc);
  ITC_INIT (itc, isp, trx);
  itc->itc_is_allocated = 1;
  return itc;
}
#else
it_cursor_t *
itc_create (void * isp, lock_trx_t * trx)
{
  NEW_VAR (it_cursor_t, itc);
  ITC_INIT (itc, isp, trx);
  itc->itc_is_allocated = 1;
  return itc;
}
#endif

void itc_col_stat_free (it_cursor_t * itc, int upd_col, float est);

void
itc_clear (it_cursor_t * it)
{
  itc_free_owned_params (it);
  if (it->itc_hash_buf)
    {
      /* hash fill buffer, never in the same tree as this itc */
      buffer_desc_t * hb = it->itc_hash_buf;
      page_leave_outside_map (hb);
      it->itc_hash_buf = NULL;
    }
  if (it->itc_buf)
    {
      buffer_desc_t * hb = it->itc_buf;
      page_leave_outside_map (hb);
    }
  if (it->itc_is_registered)
    {
      itc_unregister (it);
    }
  if (it->itc_random_search != RANDOM_SEARCH_OFF && it->itc_st.cols)
    itc_col_stat_free (it, 0, 0);
}


void
itc_free_owned_params (it_cursor_t * itc)
{
  int inx;
  for (inx = 0; inx < itc->itc_owned_search_par_fill; inx++)
    dk_free_tree (itc->itc_owned_search_params[inx]);
  itc->itc_owned_search_par_fill = 0;
}


void
itc_free (it_cursor_t * it)
{
  if (ITC_PLACEHOLDER == it->itc_type)
    {
      dk_free ((caddr_t)it, sizeof (placeholder_t));
      return;
    }
  itc_clear (it);
  if (it->itc_is_allocated)
    dk_free ((caddr_t) it, sizeof (it_cursor_t));
}


int
plh_box_free (caddr_t pl)
{
  itc_unregister ((it_cursor_t *) pl);
  return 0;
}

placeholder_t *
plh_copy (placeholder_t * pl)
{
  return NULL;
#if 0
  NEW_VAR (placeholder_t, new_pl);
  IN_VOLATILE_MAP (pl->itc_tree, pl->itc_page);
  memcpy (new_pl, pl, ITC_PLACEHOLDER_BYTES);
  new_pl->itc_type = ITC_PLACEHOLDER;
  new_pl->itc_is_registered = 0;
  itc_register ((it_cursor_t *) new_pl);
  mutex_leave (&IT_DP_MAP (pl->itc_tree, pl->itc_page)->itm_mtx);
  return new_pl;
#endif
}


placeholder_t *
plh_landed_copy (placeholder_t * pl, buffer_desc_t * buf)
{
  placeholder_t * new_pl = (placeholder_t *) dk_alloc_box (sizeof (placeholder_t), DV_PLACEHOLDER);
  memcpy (new_pl, pl, ITC_PLACEHOLDER_BYTES);
  new_pl->itc_type = ITC_PLACEHOLDER;
  new_pl->itc_is_registered = 0;
  itc_register ((it_cursor_t *) new_pl, buf);
  return new_pl;
}


buffer_desc_t *
itc_set_by_placeholder (it_cursor_t * itc, placeholder_t * pl)
{
  buffer_desc_t *buf;
  if (itc->itc_is_registered)
    {
      GPF_T1 ("not supposed to set a registered itc by placeholder");
      itc_unregister (itc);
    }
  itc->itc_tree = pl->itc_tree;
  buf = pl_enter (pl, itc);
  memcpy (itc, pl, ITC_PLACEHOLDER_BYTES);
  itc->itc_landed = 1;
  itc->itc_is_registered = 0;
  itc->itc_buf_registered = NULL; /* should be set because of tests in itc_register */
  itc->itc_next_on_page = NULL;
  itc->itc_type = ITC_CURSOR;
  ITC_FIND_PL (itc, buf);
  itc->itc_pl = buf->bd_pl;
  itc->itc_position = pl->itc_position;
  /* Set now when in, if it moved while waiting. */
  ITC_LEAVE_MAPS (itc);
  itc->itc_owns_page = 0;
  return buf;
}


int
dv_composite_cmp (db_buf_t dv1, db_buf_t dv2, collation_t * coll)
{
  db_buf_t e1 = dv1 + dv1[1] + 2;
  db_buf_t e2 = dv2 + dv2[1] + 2;
  int rc, len;
  dv1 += 2;
  dv2 += 2;

  for (;;)
    {
      if (dv1 == e1 && dv2 == e2)
	return DVC_MATCH;
      if (dv1 == e1)
	return DVC_LESS;
      if (dv2 == e2)
	return DVC_GREATER;
      rc = dv_compare (dv1, dv2, coll);
      if (rc == DVC_DTP_GREATER)
	return DVC_GREATER;
      if (rc == DVC_DTP_LESS)
	return DVC_LESS;
      if (rc != DVC_MATCH)
	return rc;
      DB_BUF_TLEN (len, dv1[0], dv1);
      dv1 += len;
      DB_BUF_TLEN (len, dv2[0], dv2);
      dv2 += len;
    }

  /*NOTREACHED*/
  return DVC_LESS;
}


dtp_t 
dv_base_type (dtp_t dtp)
{
  switch (dtp)
    {
    case DV_IRI_ID_8: return DV_IRI_ID;
    case DV_SHORT_INT: return DV_LONG_INT;
    case DV_SHORT_STRING_SERIAL: return DV_STRING;
    default: return dtp;
    }
}


int
dv_compare (db_buf_t dv1, db_buf_t dv2, collation_t *collation)
{
  int inx = 0;
  dtp_t dtp1 = *dv1;
  dtp_t dtp2 = *dv2;
  int32 n1 = 0, n2 = 0;			/*not used before set */
  db_buf_t org_dv1 = dv1;
  int64 ln1 = 0, ln2 = 0;


  if (dtp1 == dtp2)
    {
      switch (dtp1)
	{
	case DV_LONG_INT:
	  n1 = LONG_REF_NA (dv1 + 1);
	  n2 = LONG_REF_NA (dv2 + 1);
	  return ((n1 < n2 ? DVC_LESS
		  : (n1 == n2 ? DVC_MATCH
		      : DVC_GREATER)));

	case DV_SHORT_INT:
	  n1 = ((signed char *) dv1)[1];
	  n2 = ((signed char *) dv2)[1];
	  return ((n1 < n2 ? DVC_LESS
		  : (n1 == n2 ? DVC_MATCH
		      : DVC_GREATER)));

	case DV_IRI_ID:
	  {
	    unsigned int32 i1 = LONG_REF_NA (dv1 + 1);
	    unsigned int32 i2 = LONG_REF_NA (dv2 + 1);
	    return ((i1 < i2 ? DVC_LESS
		     : (i1 == i2 ? DVC_MATCH
			: DVC_GREATER)));
	  }
	case DV_SHORT_STRING_SERIAL:
	  n1 = dv1[1];
	  dv1 += 2;

	  n2 = dv2[1];
	  dv2 += 2;

	  if (!collation || collation->co_is_wide)
	    {
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
		  if (dv1[inx] < dv2[inx])
		    return DVC_LESS;
		  if (dv1[inx] > dv2[inx])
		    return DVC_GREATER;
		  inx++;
		}
	    }
	  else
	    {
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
		  if (collation->co_table[dv1[inx]] < collation->co_table[dv2[inx]])
		    return DVC_LESS;
		  if (collation->co_table[dv1[inx]] > collation->co_table[dv2[inx]])
		    return DVC_GREATER;
		  inx++;
		}
	    }
	}
    }
  {
    switch (dtp1)
      {
      case DV_LONG_INT:
	n1 = LONG_REF_NA (dv1 + 1);
	collation = NULL;
	break;
      case DV_SHORT_STRING_SERIAL:
	n1 = dv1[1];
	dtp1 = DV_LONG_STRING;
	dv1 += 2;
	if (collation && collation->co_is_wide)
	  collation = NULL;
	break;
      case DV_WIDE:
	n1 = dv1[1];
	if (dtp2 == DV_SHORT_STRING_SERIAL || dtp2 == DV_LONG_STRING)
	  {
	    collation = NULL;
	    dtp1 = DV_LONG_STRING;
	  }
	else
	  {
	    dtp1 = DV_LONG_WIDE;
	    if (collation && !collation->co_is_wide)
	      {
		collation = NULL;
		dtp1 = DV_LONG_STRING;
	      }
	  }
	dv1 += 2;
	break;
      case DV_SHORT_INT:
	n1 = ((signed char *) dv1)[1];
	dtp1 = DV_LONG_INT;
	collation = NULL;
	break;
      case DV_NULL:
	n1 = 0;
	dtp1 = DV_LONG_INT;
	collation = NULL;
	break;
      case DV_DATETIME:
	dtp1 = DV_BIN;
	n1 = DT_COMPARE_LENGTH;
	collation = NULL;
	dv1++;
	break;
      case DV_LONG_STRING:
	n1 = LONG_REF_NA (dv1 + 1);
	dv1 += 5;
	if (collation && collation->co_is_wide)
	  collation = NULL;
	break;
      case DV_LONG_WIDE:
	n1 = LONG_REF_NA (dv1 + 1);
	dv1 += 5;
	if (dtp2 == DV_SHORT_STRING_SERIAL || dtp2 == DV_LONG_STRING)
	  {
	    collation = NULL;
	    dtp1 = DV_LONG_STRING;
	  }
	else
	  {
	    if (collation && !collation->co_is_wide)
	      {
		collation = NULL;
		dtp1 = DV_LONG_STRING;
	      }
	  }
	break;
      case DV_BIN:
	n1 = dv1[1];
	dv1 += 2;
	collation = NULL;
	break;
      case DV_LONG_BIN:
	dtp1 = DV_BIN;
	n1 = LONG_REF_NA (dv1 + 1);
	dv1 += 5;
	collation = NULL;
	break;

      case DV_IRI_ID:
	ln1 = (iri_id_t) (uint32) LONG_REF_NA (dv1 + 1);
	break;
      case DV_IRI_ID_8:
	dtp1 = DV_IRI_ID;
	ln1 = INT64_REF_NA (dv1 + 1);
	break;
      case DV_RDF: return dv_rdf_compare (dv1, dv2);
      default:
	collation = NULL;
      }

    switch (dtp2)
      {
      case DV_LONG_INT:
	n2 = LONG_REF_NA (dv2 + 1);
	collation = NULL;
	break;
      case DV_SHORT_STRING_SERIAL:
	n2 = dv2[1];
	dtp2 = DV_LONG_STRING;
	dv2 += 2;
	if (collation && collation->co_is_wide)
	  collation = NULL;
	break;
      case DV_WIDE:
	n2 = dv2[1];
	if (dtp1 == DV_SHORT_STRING_SERIAL || dtp1 == DV_LONG_STRING)
	  {
	    collation = NULL;
	    dtp2 = DV_LONG_STRING;
	  }
	else
	  {
	    dtp2 = DV_LONG_WIDE;
	    if (collation && !collation->co_is_wide)
	      {
		collation = NULL;
		dtp2 = DV_LONG_STRING;
	      }
	  }
	dv2 += 2;
	break;
      case DV_SHORT_INT:
	n2 = ((signed char *) dv2)[1];
	dtp2 = DV_LONG_INT;
	collation = NULL;
	break;
      case DV_NULL:
	n2 = 0;
	dtp2 = DV_LONG_INT;
	collation = NULL;
	break;
      case DV_DATETIME:
	dtp2 = DV_BIN;
	n2 = DT_COMPARE_LENGTH;
	dv2++;
	collation = NULL;
	break;
      case DV_LONG_STRING:
	n2 = LONG_REF_NA (dv2 + 1);
	dv2 += 5;
	if (collation && collation->co_is_wide)
	  collation = NULL;
	break;
      case DV_LONG_WIDE:
	n2 = LONG_REF_NA (dv2 + 1);
	dv2 += 5;
	if (dtp1 == DV_SHORT_STRING_SERIAL || dtp1 == DV_LONG_STRING)
	  {
	    collation = NULL;
	    dtp2 = DV_LONG_STRING;
	  }
	else
	  {
	    if (collation && !collation->co_is_wide)
	      {
		collation = NULL;
		dtp2 = DV_LONG_STRING;
	      }
	  }
	break;
      case DV_BIN:
	n2 = dv2[1];
	dv2 += 2;
	collation = NULL;
	break;
      case DV_LONG_BIN:
	dtp2 = DV_BIN;
	n2 = LONG_REF_NA (dv2 + 1);
	dv2 += 5;
	collation = NULL;
	break;

      case DV_IRI_ID:
	ln2 = (iri_id_t) (uint32) LONG_REF_NA (dv2 + 1);
	break;
      case DV_IRI_ID_8:
	dtp2 = DV_IRI_ID;
	ln2 = INT64_REF_NA (dv2 + 1);
	break;
      case DV_RDF: return dv_rdf_compare (org_dv1, dv2);
      default:
	collation = NULL;

      }

    if (dtp1 == dtp2)
      {
	switch (dtp1)
	  {
	  case DV_LONG_INT:
	    return ((n1 < n2 ? DVC_LESS
		    : (n1 == n2 ? DVC_MATCH
			: DVC_GREATER)));
	  case DV_LONG_STRING:
	  case DV_BIN:
	    if (collation)
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
		  if (collation->co_table[(unsigned char)dv1[inx]] <
		      collation->co_table[(unsigned char)dv2[inx]])
		    return DVC_LESS;
		  if (collation->co_table[(unsigned char)dv1[inx]] >
		      collation->co_table[(unsigned char)dv2[inx]])
		    return DVC_GREATER;
		  inx++;
		}
	    else
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
		  if (dv1[inx] < dv2[inx])
		    return DVC_LESS;
		  if (dv1[inx] > dv2[inx])
		    return DVC_GREATER;
		  inx++;
		}

	  case DV_LONG_WIDE:
	    return compare_utf8_with_collation ((caddr_t) dv1, n1, (caddr_t) dv2, n2, collation);
	  case DV_BLOB:
	    return DVC_LESS;
	  case DV_DB_NULL:
	    return DVC_MATCH;
	  case DV_NULL:
	    return DVC_MATCH;
	  case DV_COMPOSITE:
	    return (dv_composite_cmp (dv1, dv2, collation));
	  case DV_IRI_ID:
	    return (NUM_COMPARE ((iri_id_t) ln1, (iri_id_t)ln2));
	  }
      }

    if (IS_NUM_DTP (dtp1) && IS_NUM_DTP (dtp2))
      {
	NUMERIC_VAR (dn1);
	NUMERIC_VAR (dn2);
	dtp1 = dv_ext_to_num (dv1, (caddr_t) & dn1);
	dtp2 = dv_ext_to_num (dv2, (caddr_t) & dn2);
	return dv_num_compare ((numeric_t)dn1, (numeric_t)dn2, dtp1, dtp2);
      }
    /* the types are different and it is not a number to number comparison.
     * Because the range of num dtps is not contiguous, when comparing num to non-num by dtp, consider all nums as ints.
     * could get a < b and b < c and a > c if ,c num and b not num. */
    if (IS_NUM_DTP (dtp1))
      dtp1 = DV_LONG_INT;
    if (IS_NUM_DTP (dtp2))
      dtp2 = DV_LONG_INT;

    if (dtp1 < dtp2)
      return DVC_DTP_LESS;
    else
      return DVC_DTP_GREATER;
  }
}


int
itc_like_any_check (it_cursor_t * itc, db_buf_t dv1, int len1, db_buf_t pattern)
{
  /* for any type columns, like O in rdf, have a special pattern set for type check.  'T<dtp>' where dtp is the DV tag */
  /* since the col is any the pattern is cast to any, meaning it has a dv string and len in places 0 and 1.  T and the dtp in places 2 and 3 */
  if (box_length_inline (pattern) != 5 || pattern[2] != 'T')
    return DVC_LESS;
  if (len1 >= 1 && dv_base_type (dv1[0]) == pattern[3])
    return DVC_MATCH;
  return DVC_LESS;
}


int
itc_like_compare (it_cursor_t * itc, caddr_t pattern, search_spec_t * spec)
{
  char temp[MAX_ROW_BYTES];
  int res, off, st = LIKE_ARG_CHAR, pt = LIKE_ARG_CHAR;
  dtp_t dtp2 = DV_TYPE_OF (pattern), dtp1;
  long len1;
  db_buf_t dv1;
  collation_t *collation = spec->sp_collation;
  ITC_COL (itc, spec->sp_cl, off, len1);
  dv1 = itc->itc_row_data + off;
  dtp1 = spec->sp_cl.cl_sqt.sqt_dtp;
  if (DV_BLOB == dtp1 || DV_BLOB_WIDE == dtp1)
    {
      dtp1 = *dv1;
      if (dtp1 == DV_SHORT_STRING || dtp1 == DV_LONG_STRING || dtp1 == DV_WIDE || dtp1 == DV_LONG_WIDE)
	{
	  dv1++;
	  len1--;
	}
    }
  if (DV_ANY == dtp1 && DV_STRING == dtp2)
    return itc_like_any_check (itc, dv1, len1, (db_buf_t)pattern);

  if (dtp2 != DV_SHORT_STRING && dtp2 != DV_LONG_STRING && dtp2 != DV_WIDE && dtp2 != DV_LONG_WIDE )
    return DVC_LESS;
  switch (dtp2)
    {
    case DV_WIDE:
    case DV_LONG_WIDE:
      pt = LIKE_ARG_WCHAR;
      break;
    }
  switch (dtp1)
    {
    case DV_SHORT_STRING:
      if (collation && collation->co_is_wide)
	collation = NULL;
      break;
    case DV_WIDE:
      st = LIKE_ARG_UTF;
      collation = NULL;
      break;
    case DV_LONG_WIDE:
      st = LIKE_ARG_UTF;
      collation = NULL;
      break;
    case DV_BLOB:
    case DV_BLOB_WIDE:
	{
	  blob_handle_t * bh;
	  caddr_t temp_str; 
	  collation = NULL;
	  bh = bh_from_dv (dv1, itc);
	  blob_check (bh);
	  temp_str = blob_to_string (itc->itc_ltrx, (caddr_t) bh);
	  dk_free_box (bh);
	  res = cmp_like (temp_str, pattern, collation, spec->sp_like_escape, st, pt);
	  dk_free_box (temp_str);
	  return res;
	}
    default:
      return DVC_LESS;
    }
  if (len1 >= MAX_ROW_BYTES)
    GPF_T1 ("string too long in <row> like <pattern>");
  memcpy (temp, dv1, len1);
  temp[len1] = 0;
  res = cmp_like (temp, pattern, collation, spec->sp_like_escape, st, pt);
  return res;
}


/*
   dv_spec_compare.

   compares a db buffer position to a search spec.
   DVC_LESS if position is less
   DVC_MATCH if position is within
   DVC_GREATER if position is greater.
 */


int
itc_compare_spec (it_cursor_t * itc, search_spec_t * spec)
{
  int op = spec->sp_min_op;
  if (op != CMP_NONE)
    {
      int res;
      if (op == CMP_LIKE)
	{
	  return (itc_like_compare (itc, itc->itc_search_params[spec->sp_min], spec));
	}
      res = itc_col_check_1 (itc, spec, spec->sp_min);

      /* The min operation is 1. EQ. 2 GTE, 3 GT */
      if (DVC_NOORDER & res)
	return res & ~DVC_NOORDER; 
      switch (op)
	{
	case CMP_EQ:
	  return res;
	case CMP_GT:
	  if (res != DVC_GREATER)
	    return DVC_LESS;
	  break;
	case CMP_GTE:
	  if (res == DVC_MATCH)
	    return res;
	  if (res == DVC_GREATER);
	  else
	    return DVC_LESS;
	  break;
	default:
	  GPF_T;	 /* Bad min op in search  spec */
	  return 0;	/* dummy */
	}
    }

  /* The lower boundary matches. Now check the upper */
  op = spec->sp_max_op;
  if (op != CMP_NONE)
    {
      int res;
      if (op == CMP_NONE)
	return DVC_MATCH;
      res = itc_col_check_1 (itc, spec, spec->sp_max);
      if (DVC_NOORDER & res)
	return res & ~DVC_NOORDER; 

      switch (op)
	{
	case CMP_LT:
	  if (res == DVC_LESS)
	    return DVC_MATCH;
	  else
	    return DVC_GREATER;
	case CMP_LTE:
	  if (res == DVC_MATCH || res == DVC_LESS)
	    return DVC_MATCH;
	  else
	    return DVC_GREATER;
	default:
	  GPF_T;	 /* Bad max op in search  spec */
	  return 0;	/* dummy */
	}
    }
  return DVC_MATCH;
}




dp_addr_t
leaf_pointer (db_buf_t page, int pos)
{
  if (!SHORT_REF (page + pos + IE_KEY_ID)
      || KI_LEFT_DUMMY == SHORT_REF (page + pos + IE_KEY_ID))
    return (LONG_REF (page + pos + IE_LEAF));
  return 0;
}


/*
   Returns true if the jump made it.
   False if it did not.
   If it made through the cursor is in in the requested mode.
   if it did not make it the cursor will be in somewhere else but the mode
   will be as requested.
 */


int
find_leaf_pointer (buffer_desc_t * buf, dp_addr_t lf, it_cursor_t * it, int * map_pos)
{
  page_map_t * pm = buf->bd_content_map;
  int inx, fill = pm->pm_count;
  db_buf_t page = buf->bd_buffer;
  /* position of entry whose leaf pointer == lf. -1 if none. */
  for (inx = 0; inx < fill; inx++)
    {
      int pos = pm->pm_entries[inx];
      if (lf == LONG_REF (page + pos + IE_LEAF))
	{
	  key_id_t  key_id = SHORT_REF (page + pos + IE_KEY_ID);
	  if (!key_id || KI_LEFT_DUMMY == key_id)
	    {
	      if (map_pos)
		*map_pos = inx;
	      return pos;
	    }
	}
    }
  return -1;
}


int
buf_check_deleted_refs (buffer_desc_t * buf, int do_gpf)
{
#if 0
  dp_addr_t lf;
  db_buf_t page = buf->bd_buffer;
  /* position of entry whose leaf pointer == lf. 0 if none. */
  int pos = SHORT_REF (page + DP_FIRST);
  while (pos)
    {
      lf = leaf_pointer (page, pos, 0);
      if (lf)
	{
	  dp_addr_t remap;
	  if (it_is_free_page (db_main_tree, lf))
	    {
	      log_error ("Ref'd page not free in write, %ld", (long) lf);
	      if (do_gpf)
		GPF_T;
	    }
	  if (buf->bd_space != db_main_tree->it_checkpoint_space)
	    {
	      remap = (dp_addr_t) (unsigned long) gethash (DP_ADDR2VOID (lf),
		  buf->bd_space->isp_remap);
	      if (remap && (remap == DP_DELETED || it_is_free_page (db_main_tree, remap)))
		{
		  log_error ("Writing ref to page whose remap is freed, %ld",
		      (long) lf);
		  if (do_gpf)
		    GPF_T;
		}
	    }
	}
      pos += pg_cont_head_length (page + pos);
      pos = IE_NEXT (page + pos);
    }
#endif
  return 0;
}


void
itc_find_map_pos (it_cursor_t * itc, buffer_desc_t * buf)
{
  page_map_t *pm = buf->bd_content_map;
  int ct = pm->pm_count, inx;
  for (inx = 0; inx < ct; inx++)
    {
      if (pm->pm_entries[inx] == itc->itc_position)
	{
	  itc->itc_map_pos = inx;
	  break;
	}
    }
}


void
itc_prev_entry (it_cursor_t * itc, buffer_desc_t * buf)
{
  /* when reading in descending order */
  page_map_t *pm = buf->bd_content_map;
  if (-1 == itc->itc_map_pos)
    itc_find_map_pos (itc, buf);
  if (0 == itc->itc_map_pos)
    itc->itc_position = 0;
  else
    {
      itc->itc_map_pos--;
      itc->itc_position = pm->pm_entries[itc->itc_map_pos];
    }
}


void
itc_skip_entry (it_cursor_t * itc, db_buf_t page)
{
  if (itc->itc_position)
    itc->itc_position = IE_NEXT (page + itc->itc_position);
  if (!itc->itc_position)
    itc->itc_map_pos = -1;
  else if (-1 != itc->itc_map_pos)
    itc->itc_map_pos++;
}


int
itc_hash_next_page (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  dp_addr_t next = LONG_REF ((*buf_ret)->bd_buffer + DP_OVERFLOW);
  if (!next)
    return DVC_INDEX_END;
  ITC_IN_KNOWN_MAP (itc, itc->itc_page);
  page_leave_inner (*buf_ret);
  ITC_LEAVE_MAP_NC (itc);
  ITC_IN_KNOWN_MAP (itc, next);
  page_wait_access (itc, next, NULL, buf_ret, PA_WRITE, RWG_WAIT_ANY);
  ITC_LEAVE_MAPS (itc);
  itc->itc_position = SHORT_REF ((*buf_ret)->bd_buffer + DP_FIRST);
  itc->itc_page = next;
  return DVC_MATCH;
}


#define ITC_OUT_MAP(itc) itc->itc_ks->ks_out_map


int
itc_row_check (it_cursor_t * itc, buffer_desc_t * buf)
{
  key_source_t *ks;
  /* Check the key id's and non-key columns. */
  /*db_buf_t page = buf->bd_buffer;*/
  search_spec_t *sp;
  key_id_t key = itc->itc_row_key_id;
  dbe_key_t *row_key = NULL;
  if (itc->itc_insert_key && itc->itc_insert_key->key_is_bitmap && !itc->itc_no_bitmap)
    return itc_bm_row_check (itc, buf);
  if (RANDOM_SEARCH_ON == itc->itc_random_search)
    itc->itc_st.n_sample_rows++;
  
  if (key == itc->itc_key_id)
    itc->itc_row_key = itc->itc_insert_key;
  else
	{
	  if (!sch_is_subkey (isp_schema (NULL), key, itc->itc_key_id))
	    return DVC_LESS;	/* Key specified but this ain't it */
      ITC_REAL_ROW_KEY (itc);
      row_key = itc->itc_row_key;
    }


  sp = itc->itc_row_specs;
  if (sp)
    {
      do
	{
	  int op = sp->sp_min_op;
	  search_spec_t sp_auto;

	  if (row_key)
	    {
	      dbe_col_loc_t *cl = key_find_cl (row_key, sp->sp_cl.cl_col_id);
	      if (cl)
		{
		  memcpy (&sp_auto, sp, sizeof (search_spec_t));
		  sp = &sp_auto;
		  sp->sp_cl = *cl;
		}
	      else
		{
		  dbe_column_t * col = sch_id_to_column (wi_inst.wi_schema, sp->sp_cl.cl_col_id);
		  if (col && col->col_default)
		    {
		      if (DVC_CMP_MASK & op)
			{
			  if (0 == (op & cmp_boxes (col->col_default, itc->itc_search_params[sp->sp_min], sp->sp_collation, sp->sp_collation)))
		            return DVC_LESS;
			}
		      else if (op == CMP_LIKE)
			{
			  caddr_t v = itc->itc_search_params[sp->sp_min];
			  int st = LIKE_ARG_CHAR, pt = LIKE_ARG_CHAR;
			  dtp_t rtype = DV_TYPE_OF (v);
			  dtp_t ltype = DV_TYPE_OF (col->col_default);
			  if (DV_WIDE == rtype || DV_LONG_WIDE == rtype)
			    pt = LIKE_ARG_WCHAR;
			  if (DV_WIDE == ltype || DV_LONG_WIDE == ltype)
			    st = LIKE_ARG_WCHAR;
			  if (DVC_MATCH != cmp_like (col->col_default, v, sp->sp_collation, sp->sp_like_escape, st, pt))
			    return DVC_LESS;
			}
		      if (sp->sp_max_op != CMP_NONE
			  && (0 == (sp->sp_max_op & cmp_boxes (col->col_default, itc->itc_search_params[sp->sp_max], 
				sp->sp_collation, sp->sp_collation))))
			return DVC_LESS;
		      goto next_sp;		    
		    }
		  return DVC_LESS;
		}
	    }

	  if (ITC_NULL_CK (itc, sp->sp_cl))
	    return DVC_LESS;
	  if (DVC_CMP_MASK & op)
	    {
	      int res = itc_col_check_1 (itc, sp, sp->sp_min);
	      if (0 == (op & res) || (DVC_NOORDER & res))
		return DVC_LESS;
	    }
	  else if (op == CMP_LIKE)
	    {
	      if (DVC_MATCH != itc_like_compare (itc, itc->itc_search_params[sp->sp_min], sp))
		return DVC_LESS;
	      goto next_sp;
	    }
	  if (sp->sp_max_op != CMP_NONE)
	    {
	      int res = itc_col_check_1 (itc, sp, sp->sp_max);
	      if ((0 == (sp->sp_max_op & res)) || (DVC_NOORDER & res))
		return DVC_LESS;
	    }
	next_sp:
	  sp = sp->sp_next;
	} while (sp);
    }
  ks = itc->itc_ks;
  if (ks)
    {
      if (ks->ks_out_cols)
	{
	  int inx = 0;
	  out_map_t * om = ITC_OUT_MAP (itc);
	  DO_SET (state_slot_t *, ssl, &ks->ks_out_slots)
	    {
	      if (om[inx].om_is_null)
		{
		  if (OM_NULL == om[inx].om_is_null)
		    qst_set_bin_string (itc->itc_out_state, ssl, (db_buf_t) "", 0, DV_DB_NULL);
		  else
		    qst_set (itc->itc_out_state, ssl, itc_box_row (itc, buf->bd_buffer));
		}
	      else
		{
		  if (row_key)
		    {
		      dbe_col_loc_t *cl = key_find_cl (row_key, om[inx].om_cl.cl_col_id);
		      if (!cl)
			{
			  dbe_column_t * col = sch_id_to_column (wi_inst.wi_schema, om[inx].om_cl.cl_col_id);
			  if (col && col->col_default)
			    qst_set (itc->itc_out_state, ssl, box_copy_tree (col->col_default));
			  else
			    qst_set_bin_string (itc->itc_out_state, ssl, (db_buf_t) "", 0, DV_DB_NULL);
			}
		      else
			itc_qst_set_column (itc, cl, itc->itc_out_state, ssl);
		    }
		  else
		    itc_qst_set_column (itc, &om[inx].om_cl, itc->itc_out_state, ssl);
		}
	      inx++;
	    }
	  END_DO_SET();
	}
      if (ks->ks_local_test
	  && !code_vec_run_no_catch (ks->ks_local_test, itc))
	return DVC_LESS;
      if (ks->ks_local_code)
	code_vec_run_no_catch (ks->ks_local_code, itc);
      KS_COUNT (ks, itc->itc_out_state);
      if (ks->ks_setp)
	{
	  KEY_TOUCH (ks->ks_key);
	  if (setp_node_run (ks->ks_setp, itc->itc_out_state, itc->itc_out_state, 0))
	    return DVC_MATCH;
	  else
	    return DVC_LESS;
	}
    }
  KEY_TOUCH (itc->itc_insert_key);
  return DVC_MATCH;
}


int
itc_search (it_cursor_t * it, buffer_desc_t ** buf_ret)
{
  dp_addr_t leaf;
  int res, pos, map_pos = 0;
  int just_landed_match = 0;
  dp_addr_t leaf_from, up;

  if (!it->itc_key_spec.ksp_key_cmp)
    it->itc_key_spec.ksp_key_cmp = SM_READ == it->itc_search_mode ? pg_key_compare : pg_insert_key_compare;
  if (ISO_SERIALIZABLE == it->itc_isolation && SM_INSERT != it->itc_search_mode)
    it->itc_search_mode = SM_READ; /* no exact, must set follow lock to item before match range */
start:
#ifndef NDEBUG
  if (!(*buf_ret)->bd_readers && !(*buf_ret)->bd_is_write)
    GPF_T1 ("buffer not wired occupied in itc_search");
  if (it->itc_page != (*buf_ret)->bd_page)
    {
      /* If itc_page != bd_page, could be the txn was killed and
       * the buf scrapped (bd_page = 0)
       * However, if txn still alive, it's an error */
      CHECK_TRX_DEAD (it, buf_ret, ITC_BUST_THROW);
      GPF_T1 ("Buffer and cursor on different pages");
    }
#endif
  CHECK_TRX_DEAD (it, buf_ret, ITC_BUST_CONTINUABLE);
  leaf = 0;
  it->itc_is_on_row = 0;

  if (!it->itc_landed)
    {
      if (RANDOM_SEARCH_ON == it->itc_random_search)
    {
	  res = itc_random_leaf (it, *buf_ret, &leaf);
	  if (leaf)
	{
	      itc_dive_transit (it, buf_ret, leaf);
	  goto start;
	}
    }
      else if (it->itc_search_mode == SM_READ)
	res = itc_page_split_search (it, buf_ret);
      else
	res = itc_page_insert_search (it, buf_ret);

      itc_try_land (it, buf_ret);
      if (!it->itc_landed)
	{
	  *buf_ret = itc_reset (it);
	  goto start;
	}
      if (!(*buf_ret)->bd_is_write)
	GPF_T1 ("Buffer not on write access after cursor landed");

      if (it->itc_search_mode == SM_INSERT)
	return res;
      /* A read cursor landed on a leaf */
      if (!it->itc_no_bitmap && it->itc_insert_key && it->itc_insert_key->key_is_bitmap)
	it->itc_bp.bp_just_landed = 1;
      if ((ISO_SERIALIZABLE == it->itc_isolation)  /* IvAn: this addded according to Orri's instruction: */ && (DVC_GREATER != res))
	{
	  if (NO_WAIT != itc_serializable_land (it, buf_ret))
	    goto start;
	}
      if (DVC_MATCH == res)
	{
	  just_landed_match = 1;
	  goto start; /* pass through itc_page_search to check locks, row specs etc */
	}
      if (it->itc_search_mode == SM_READ)
	{
	  if (res == DVC_LESS && !it->itc_desc_order)
	    {
	      it->itc_bp.bp_at_end = 1;
	      itc_skip_entry (it, (*buf_ret)->bd_buffer);
	      if (it->itc_position)
		goto start;
	      res = DVC_INDEX_END;
	      goto search_switch;
	    }
	  if (res == DVC_GREATER && it->itc_desc_order)
	    {
	      res = DVC_INDEX_END;
	      goto search_switch;
	    }
	}
      return res;
    }
      else
	{
      if (it->itc_bp.bp_just_landed && RWG_NO_WAIT < itc_bm_land_lock (it, buf_ret)) /* was == RWG_WAIT_SPLIT */
	{
	  page_leave_outside_map (*buf_ret);
	  *buf_ret = itc_reset (it);
	  goto start;
	}
      res = itc_page_search (it, buf_ret, &leaf, just_landed_match);
      just_landed_match = 0;
    }

search_switch:
  switch (res)
    {
    case DVC_INDEX_END:
      {
	it->itc_is_on_row = 0;
	if (it->itc_desc_serial_reset)
	  {
	    /* for convenience, put the reset condition together with index end so as not to check upon every return of itc_page_search */
	    it->itc_desc_serial_landed = 0;
	    it->itc_desc_serial_reset = 0;
	    itc_page_leave (it, *buf_ret);
	    *buf_ret = itc_reset (it);
	    goto start;
	  }
	/* This leaf is DONE. Go up if can't go down. */
	if (leaf)
	  GPF_T1 ("no leaf at index end");

	if (it->itc_tree->it_hi)
	  {
	    if (DVC_MATCH == itc_hash_next_page (it, buf_ret))
	    goto start;
	    return DVC_INDEX_END;
	  }
      up_again:
	if (it->itc_is_vacuum)
	  itc_vacuum_compact (it, *buf_ret);
	up = LONG_REF (((*buf_ret)->bd_buffer) + DP_PARENT);
	/* in principle, the parent link must be read inside the dp's map.  Here we only want to know if it is 0.
	 * The map is not needed for that since aroot can stop being a root only by somebidy changing it, which can't be since this itc is ecl in.
	 * However, non-0 parent links can change due to splits and they must be read and transited atomically in the right map. */
	leaf_from = (*buf_ret)->bd_page;
	if (!up)
	  {
	    ITC_LEAVE_MAPS (it);
	    return DVC_INDEX_END;
	  }
	if (RANDOM_SEARCH_ON == it->itc_random_search)
	  {
	    switch  (itc_up_rnd_check (it, buf_ret))
	      {
	      case DVC_MATCH: 
		goto start;
	      case DVC_INDEX_END:
		return DVC_INDEX_END;
	      }
	  }
	if (DVC_INDEX_END == itc_up_transit (it, buf_ret))
	  return DVC_INDEX_END; /* the non-root became root while waiting for parent, which got popped away by itc_delete_single_leaf.  At end. Return */

	/* This never fails. We're in on the parent node. Where do we go now? */
#ifdef PMN_THREADS
	PROCESS_ALLOW_SCHEDULE ();
#endif

	pos = find_leaf_pointer (*buf_ret, leaf_from, it, &map_pos);
	if (-1 == pos)
	  {
	    dbg_page_map (*buf_ret);
	    GPF_T1 ("up transit to a page w/o corresponding down pointer");
	  }
	it->itc_map_pos = map_pos;
	it->itc_position = pos;
	if (it->itc_desc_order)
	  itc_prev_entry (it, *buf_ret);
	else
	  itc_skip_entry (it, (*buf_ret)->bd_buffer);
	res = itc_page_search (it, buf_ret, &leaf, 0);
	if (res == DVC_GREATER)
	  {
	    it->itc_is_on_row = 0;
	  return DVC_INDEX_END;
	  }
	if (res == DVC_MATCH)
	  {
	    pos = it->itc_position;
	    itc_read_ahead (it, buf_ret);
	    goto search_switch;
	  }
	/* We have come up and are at the right edge. Up again */
	goto up_again;
      }

    case DVC_LESS:
      {
	it->itc_is_on_row = 0;
	if (leaf)
	  {
	    /* Go down on the right edge. */
	      itc_landed_down_transit (it, buf_ret, leaf);
	    goto start;
	  }
	else
	  {
	    GPF_T;		/* Less but no way down on landed search */
	  }
      }
    case DVC_MATCH:
      {
	/* If there's a way down, leaf will have it. */
	if (leaf)
	  {
	    itc_landed_down_transit (it, buf_ret, leaf);
	    goto start;
	  }
	/* must come from itc_page_search.  Any landing must pass via itc_page_search before coming here */
		it->itc_is_on_row = 1;
		if (it->itc_owns_page != it->itc_page
	    && (ISO_REPEATABLE == it->itc_isolation
		|| (PL_EXCLUSIVE == it->itc_lock_mode && it->itc_isolation > ISO_UNCOMMITTED)))
		  {
		    int wait_rc = itc_set_lock_on_row (it, buf_ret);
		    if (wait_rc != NO_WAIT || !it->itc_is_on_row)
	      goto start; /* if waited, must recheck the key, again pass via itc_page_searchh */
      }
	ITC_AGE_TRX (it, 1);
	if (it->itc_search_mode == SM_READ)
	  {
	    /* not in SM_READ_EXACT, where no more fetched */
	    if (it->itc_ks && it->itc_ks->ks_is_last)
	      {
		if (it->itc_desc_order)
		  itc_prev_entry (it, *buf_ret);
		else
		  itc_skip_entry (it, (*buf_ret)->bd_buffer);
		goto start;
	      }
	  }
	return DVC_MATCH;
      }

    case DVC_GREATER:
      {
	if (leaf)
	  GPF_T1 ("no leaf at dvc_greater");
	/* No previous leaf. This is the place, said Brigham. Insert here. */
	it->itc_is_on_row = 0;
	return DVC_GREATER;
      }
    }
  return DVC_LESS;		/* never done */
}


#if 1
#define ITC_CK_POS(itc)
#else
/*not needed */
#define ITC_CK_POS(itc)\
  {if (itc->itc_position && (itc->itc_position < DP_DATA || itc->itc_position > PAGE_SZ - 8)) \
    GPF_T1("itc_position out of range after itc_search"); }
#endif


int
itc_next (it_cursor_t * it, buffer_desc_t ** buf_ret)
{
  key_source_t * ks;
  if (it->itc_is_on_row)
    {
      it->itc_is_on_row = 0;
      if (it->itc_insert_key && it->itc_insert_key->key_is_bitmap)
	{
	  itc_next_bit (it, *buf_ret);
	  if (!it->itc_bp.bp_is_pos_valid)
	    goto skip_bitmap; /* If pos still not valid We are on a non-eaf and must get to a leaf before setting the bitmap stiff, sp dp as if no bm */ 
	  if (it->itc_bp.bp_at_end)
	    {
	      it->itc_bp.bp_new_on_row = 1;
	      if (it->itc_desc_order)
		itc_prev_entry (it, *buf_ret);
	      else
		itc_skip_entry (it, (*buf_ret)->bd_buffer);
	    }
	}
      else 
	{
	  if (it->itc_desc_order)
	    itc_prev_entry (it, *buf_ret);
	  else
	    itc_skip_entry (it, (*buf_ret)->bd_buffer);
	}
    }
 skip_bitmap:
  ks = it->itc_ks;
  if (ks && (ks->ks_local_test || ks->ks_local_code || ks->ks_setp))
    {
      int rc;
      query_instance_t * volatile qi = (query_instance_t *) it->itc_out_state;
      QR_RESET_CTX_T (qi->qi_thread)
	{
	  ITC_FAIL (it)
	    {
	      rc  = itc_search (it, buf_ret);
	      ITC_CK_POS (it);
	    }
	  ITC_FAILED
	    {
	    }
	  END_FAIL_THR (it, qi->qi_thread)
	}
      QR_RESET_CODE
	{
	  POP_QR_RESET;
	  if (RST_ERROR == reset_code)
	    {
	      itc_page_leave (it, *buf_ret);  /* if comes out with deadlock or other txn error, the buffer is left already */
	      qi_check_trx_error (qi, 0);
	    }
	  /* assert for buf */
	  qi_check_buf_writers ();
	  longjmp_splice (qi->qi_thread->thr_reset_ctx, reset_code);
	}
      END_QR_RESET;
      it->itc_desc_serial_landed = 0;
      return rc;
    }
  else
    {
      int rc = itc_search (it, buf_ret);
      it->itc_desc_serial_landed = 0;
            ITC_CK_POS (it);
      return rc;
    }
}

long  tc_desc_serial_reset;
/* control is read committed will show previous committed value Oracle style or wait */
int min_iso_that_waits = ISO_REPEATABLE;


#define IE_IS_LEAF(row, key_id) \
  (0 == key_id || (KI_LEFT_DUMMY == key_id && LONG_REF ((row) + IE_LEAF)))

int
itc_page_search (it_cursor_t * it, buffer_desc_t ** buf_ret, dp_addr_t * leaf_ret,   int skip_first_key_cmp)
{
  db_buf_t page = (*buf_ret)->bd_buffer;
  dp_addr_t leaf = 0;
  key_id_t key_id;
  search_spec_t *sp;
  int res = DVC_LESS, row_check;
  int pos;
  char txn_clear = PS_LOCKS;

  if (it->itc_wst)
    return (itc_text_search (it, buf_ret, leaf_ret));

  if ((*buf_ret)->bd_content_map && !(*buf_ret)->bd_content_map->pm_count) /* cpt rollback can leave empty pages, recover from that */
    {
      it->itc_position = 0;
    }

  if (ISO_UNCOMMITTED == it->itc_isolation)
    txn_clear = PS_OWNED;
  else if (ISO_COMMITTED == it->itc_isolation)
    {
      if (!(*buf_ret)->bd_pl)
	txn_clear = PS_OWNED;
    }
  else if (ISO_REPEATABLE == it->itc_isolation)
    {
      if (!(*buf_ret)->bd_pl)
	{
	  txn_clear = PS_NO_LOCKS;
	}
    }


  while (1)
    {
      if (!it->itc_position)
	{
	  *leaf_ret = 0;
	  return DVC_INDEX_END;
	}
      if (it->itc_position >= PAGE_SZ)
	GPF_T;			/* Link over page end */

      if (PS_LOCKS == txn_clear && !IE_IS_LEAF (page + it->itc_position, SHORT_REF (page + it->itc_position + IE_KEY_ID)))
	{
	  if (it->itc_owns_page != it->itc_page)
	    {
	      if (it->itc_isolation == ISO_SERIALIZABLE
		  || ((it->itc_isolation >= min_iso_that_waits || PL_EXCLUSIVE == it->itc_lock_mode)
		    && ITC_MAYBE_LOCK (itc, it->itc_position)))
		{
		  for (;;)
		    {
		      int wrc = ITC_IS_LTRX (it) ?
			  itc_landed_lock_check (it, buf_ret) : NO_WAIT;
		      if (it->itc_desc_serial_landed && NO_WAIT != wrc)
			{
			  TC (tc_desc_serial_reset);
			  it->itc_desc_serial_reset = 1;
			  return DVC_INDEX_END;
			}
		      if (NO_WAIT != wrc)
			skip_first_key_cmp = 0; /* if waited, must recheck the key even if just landed with a read exact match */
		      if (ISO_SERIALIZABLE == it->itc_isolation
			  || NO_WAIT == wrc)
			break;
		      /* passing this means for a RR cursor that a subsequent itc_set_lock_on_row is
		       * GUARANTEED to be with no wait. Needed not to run itc_row_check side effect twice */
		      wrc = wrc;  /* breakpoint here */
		    }
		  page = (*buf_ret)->bd_buffer;
		  if (0 == it->itc_position)
		    {
		      /* The row may have been deleted during lock wait.
		       * if this was the last row, the itc_position will have been set to 0 */
		      *leaf_ret = 0;
		      return DVC_INDEX_END;
		    }
		}
	    }
	  else
	    txn_clear = PS_OWNED;
	}

      pos = it->itc_position;
      key_id = SHORT_REF (page + pos + IE_KEY_ID);
      if (KI_LEFT_DUMMY == key_id)
	{
	  if (it->itc_desc_order)
	    {
	      /* when going in reverse always descend into the leftmost leaf */
	      leaf = LONG_REF (page + pos + IE_LEAF);
	      if (leaf)
		{
		  *leaf_ret = leaf;
		  return DVC_MATCH;
		}
	    }
	  goto next_row;
	}
#ifdef NEW_HASH
      if (it->itc_tree && it->itc_tree->it_hi &&
	  it->itc_row_key && it->itc_row_key->key_id == KI_TEMP)
	key_id = it->itc_row_key_id = KI_TEMP;
      else
#endif
	it->itc_row_key_id = key_id;
      if (!key_id)
	{
	  leaf = LONG_REF (page + pos + IE_LEAF);
	  it->itc_row_data = page + pos + IE_LP_FIRST_KEY;
	}
      else
	{
	  it->itc_row_data = page + pos + IE_FIRST_KEY;
	  it->itc_at_data_level = 1;
	  leaf = 0;
	}
      if (skip_first_key_cmp)
	{
	  /* if just came, landed with match and read exact mode and there was no wait, this is already checked */
	  skip_first_key_cmp = 0;
	  res = DVC_MATCH;
	}
      else if (it->itc_key_spec.ksp_key_cmp != pg_key_compare 
	  && it->itc_key_spec.ksp_key_cmp != pg_insert_key_compare
	  && it->itc_key_spec.ksp_key_cmp)
	{
	  res = it->itc_key_spec.ksp_key_cmp (*buf_ret, pos, it);
	  if (DVC_GREATER == res)
	    return res;
	}
      else 
	{
	  res = DVC_MATCH;
	  for (sp = it->itc_key_spec.ksp_spec_array; sp; sp = sp->sp_next)
	    {
	      DV_COMPARE_SPEC_W_NULL (res, sp, it);

	      if (res == DVC_MATCH)
		{
		  continue;
		}
	      if (res == DVC_LESS)
		{
		  /*  column is too small.  If there is a leaf, go ther else search at end */
		  if (ITC_NULL_CK(it, sp->sp_cl))
		    {
		      if (!leaf)
			goto next_row;  /* skip a null on the row */
		      break;
		    }
		  break;
		}
	      if (res == DVC_GREATER)
		{
		  *leaf_ret = 0;
		  it->itc_position = pos;
		  return DVC_GREATER;
		}
	    }
	}
      if (!leaf /* MI: if it is a leaf pointer no point to check for lock */
	  && PS_LOCKS == txn_clear && ISO_COMMITTED == it->itc_isolation 
	  && PL_EXCLUSIVE != it->itc_lock_mode 
	  && ISO_REPEATABLE == min_iso_that_waits)
	{
	  if (DVC_MATCH != itc_read_committed_check (it, pos, *buf_ret))
	    goto next_row;
	}
      else if (IE_ISSET (page + pos, IEF_DELETE))
	goto next_row;
      *leaf_ret = leaf;
      /* if go to the leaf even if the compare was less because the leaf can still hold stuff if in desc order.  In asc order the compare never gives dvc_less if the index is not out of order */
      if (leaf)
	return DVC_MATCH;
      if (DVC_MATCH == res)
	{
	  row_check = itc_row_check (it, *buf_ret);
	  if (DVC_GREATER == row_check)
	    return DVC_GREATER;
	  if (DVC_MATCH == row_check)
	    {
	      if (it->itc_ks && it->itc_ks->ks_is_last
		  && (PS_OWNED == txn_clear
		    || (ISO_COMMITTED == it->itc_isolation  && PL_EXCLUSIVE != it->itc_lock_mode)
		    || ISO_SERIALIZABLE == it->itc_isolation))
		{
		  /* A RR or *exckl RC cursor that does not own the page must return to itc_search for the locks.  */
		  goto next_row;
		}
	      return DVC_MATCH;
	    }
	  else
	    goto next_row;
	}
      else if (res == DVC_LESS && !leaf && it->itc_desc_order)
	{
	  return DVC_GREATER;	/* end of search */
	}
      /* Next entry on page */

next_row:

      if (it->itc_insert_key && it->itc_insert_key->key_is_bitmap)
	it->itc_bp.bp_new_on_row = 1;

      if (it->itc_desc_order)
	{
	  itc_prev_entry (it, *buf_ret);
	}
      else
	{
	  it->itc_position = IE_NEXT (page + it->itc_position);
	}
    }
}


int
pg_key_compare (buffer_desc_t * buf, int pos, it_cursor_t * it)
{
  db_buf_t page = buf->bd_buffer;
  search_spec_t *spec = it->itc_key_spec.ksp_spec_array;
  key_id_t key_id = SHORT_REF (page + pos + IE_KEY_ID);
  if (KI_LEFT_DUMMY == key_id)
    {
      it->itc_row_key_id = 0;
      return DVC_LESS;
    }
  it->itc_row_key_id = key_id;
  it->itc_row_data = page + pos + (!key_id ? IE_LP_FIRST_KEY : IE_FIRST_KEY);
  for (;;)
    {
      int res;
      if (!spec)
	{
	  return DVC_MATCH;
	}
      res = itc_compare_spec (it, spec);
      if (spec->sp_is_reverse && DVC_MATCH != res)
	res = res == DVC_GREATER ? DVC_LESS : DVC_GREATER;
      if (res == DVC_MATCH)
	{
	  spec = spec->sp_next;
	  continue;
	}
      return res;
    }

  /*NOTREACHED*/
  return DVC_MATCH;
}


int
itc_page_split_search (it_cursor_t * it, buffer_desc_t ** buf_ret)
{
 new_page:
  {
    dp_addr_t leaf;
    buffer_desc_t * buf = *buf_ret;
  db_buf_t page = buf->bd_buffer;
  int res;
  page_map_t *map = buf->bd_content_map;
  int below = map->pm_count;
  int at_or_above = 0;
  int guess;
  int at_or_above_res = -100;
  key_id_t key_id;
    if (it->itc_dive_mode == PA_READ ? buf->bd_is_write : !buf->bd_is_write)
    GPF_T1 ("split search supposed to be in read mode");
  if (map->pm_count == 0)
    {
      it->itc_position = 0;
      return DVC_GREATER;
    }


  for (;;)
    {
      if ((below - at_or_above) <= 1)
	{
	  if (at_or_above_res == -100)
	    {
	      at_or_above_res = it->itc_key_spec.ksp_key_cmp (buf,
						       map->pm_entries[at_or_above], it);
	    }
	  switch (at_or_above_res)
	    {
	    case DVC_MATCH:
	    case DVC_LESS:
	      {
	      it->itc_position = map->pm_entries[at_or_above];
	      it->itc_map_pos = at_or_above;
	      key_id = SHORT_REF (page + it->itc_position + IE_KEY_ID);
	      if (!key_id || KI_LEFT_DUMMY == key_id)
		  {
		    leaf = LONG_REF (page + map->pm_entries[at_or_above] + IE_LEAF);
		    if (leaf)
		      {
			if (buf->bd_is_ro_cache)
			  {
			    itc_root_cache_enter (it, buf_ret, leaf);
		return at_or_above_res;
	      }
			itc_dive_transit (it, buf_ret, leaf);
			goto new_page;
		      }
		  }
		it->itc_row_key_id = key_id;
		it->itc_row_data = page + it->itc_position + IE_FIRST_KEY;
		it->itc_map_pos = at_or_above;
		return at_or_above_res;
	      }
	    case DVC_GREATER:
	      {
		/* The lower limit, 0 was greater. No way down. */
		it->itc_position = map->pm_entries[at_or_above];
		it->itc_map_pos = at_or_above;
		return DVC_GREATER;
	      }
	    }
	}
      /* OK, we have an interval to search */
      guess = at_or_above + ((below - at_or_above) / 2);
      res = it->itc_key_spec.ksp_key_cmp (buf, map->pm_entries[guess], it);
      switch (res)
	{
	case DVC_LESS:
	  at_or_above = guess;
	  at_or_above_res = res;
	  break;
	case DVC_MATCH:	/* row found, dependent not checked */
	  if (it->itc_desc_order)
	    {
	      at_or_above = guess;
	      at_or_above_res = res;
	    }
	  else
	    {
	      below = guess;
	    }
	  break;

	case DVC_GREATER:
	  below = guess;
	  break;
	default: GPF_T1 ("key_cmp_t can't return that");
	}
	}
    }
}

int
pg_insert_key_compare (buffer_desc_t * buf, int pos, it_cursor_t * it)
{
  db_buf_t page = buf->bd_buffer;
  search_spec_t *spec = it->itc_key_spec.ksp_spec_array;
  key_id_t key_id = SHORT_REF (page + pos + IE_KEY_ID);
  if (KI_LEFT_DUMMY == key_id)
    {
      it->itc_row_key_id = 0;
      return DVC_LESS;
    }
  it->itc_row_key_id = key_id;
  it->itc_row_data = page + pos + (key_id ? IE_FIRST_KEY : IE_LP_FIRST_KEY);
  for (;;)
    {
      int res;
      if (!spec)
	{
	  return DVC_MATCH;
	}
      res = itc_col_check (it, spec, spec->sp_min);
      if (spec->sp_is_reverse && DVC_MATCH != res)
	res = res == DVC_GREATER ? DVC_LESS : DVC_GREATER;
      if (res == DVC_MATCH)
	{
	  spec = spec->sp_next;
	  continue;
	}
      return res;
    }

  /*NOTREACHED*/
  return DVC_MATCH;
}


int
itc_page_insert_search (it_cursor_t * it, buffer_desc_t ** buf_ret)
{
 new_page:
  for (;;)
    {
      dp_addr_t leaf;
      buffer_desc_t * buf = *buf_ret;
  db_buf_t page = buf->bd_buffer;
  int res;
  page_map_t *map = buf->bd_content_map;
  int below = map->pm_count;
  int at_or_above = 0;
  int guess;
  int at_or_above_res = -100;
  key_id_t key_id;
  if (map->pm_count == 0)
    {
      it->itc_position = 0;
      return DVC_GREATER;
    }
  for (;;)
    {
      if ((below - at_or_above) <= 1)
	{
	  if (at_or_above_res == -100)
	    {
		  at_or_above_res = it->itc_key_spec.ksp_key_cmp (buf,
		  map->pm_entries[at_or_above], it);
	    }
	  switch (at_or_above_res)
	    {
	    case DVC_MATCH:
	    case DVC_LESS:
	      {
	      it->itc_position = map->pm_entries[at_or_above];
	      key_id = SHORT_REF (page + it->itc_position + IE_KEY_ID);
	      if (!key_id || KI_LEFT_DUMMY == key_id)
		      {
			leaf = LONG_REF (page + map->pm_entries[at_or_above] + IE_LEAF);
			if (leaf)
			  {
			    if (buf->bd_is_ro_cache)
			      {
				itc_root_cache_enter (it, buf_ret, leaf);
				return at_or_above_res;
			      }
			    itc_dive_transit (it, buf_ret, leaf);
			    goto new_page;
			  }
		      }
		    it->itc_map_pos = at_or_above;
		    it->itc_row_data = page + it->itc_position + IE_FIRST_KEY;
		    it->itc_row_key_id = key_id;
		return at_or_above_res;
	      }
	    case DVC_GREATER:
	      {
		/* The lower limit, 0 was greater. No way down. */
		it->itc_position = map->pm_entries[at_or_above];
		it->itc_map_pos = 0;
		return DVC_GREATER;
	      }
	    }
	}
      /* OK, we have an interval to search */
      guess = at_or_above + ((below - at_or_above) / 2);
	  res = it->itc_key_spec.ksp_key_cmp (buf, map->pm_entries[guess],
	  it);
      switch (res)
	{
	case DVC_LESS:
	  at_or_above = guess;
	  at_or_above_res = res;
	  break;
	case DVC_MATCH:	/* row found, dependent not checked */
	  it->itc_position = map->pm_entries[guess];
	      key_id = SHORT_REF (page + it->itc_position + IE_KEY_ID);
	      if (!key_id)
		{
		  leaf = LONG_REF (page + it->itc_position + IE_LEAF);
		  if (buf->bd_is_ro_cache)
		    {
		      itc_root_cache_enter (it, buf_ret, leaf);
	  return res;
		    }

		  itc_dive_transit (it, buf_ret, leaf);
		  goto new_page;
		}
	      it->itc_map_pos = guess;
	      it->itc_row_key_id = key_id;
	      it->itc_row_data = page + it->itc_position + IE_FIRST_KEY;
	      return res;
	case DVC_GREATER:
	  below = guess;
	  break;
	    default: GPF_T1 ("can't have this res for key_cmp_t");
	}
    }
    }
}


void
itc_from_keep_params (it_cursor_t * it, dbe_key_t * key)
{
  it->itc_insert_key = key;
  it->itc_row_key = key;
  it->itc_row_key_id = key->key_id;
  it->itc_key_id = key->key_id;
  it->itc_tree = key->key_fragments[0]->kf_it;
}


void
itc_clear_stats (it_cursor_t *it)
{
  memset (&(it->itc_st), 0, sizeof (it->itc_st));
}

long dbe_auto_sql_stats;

void
itc_from (it_cursor_t * it, dbe_key_t * key)
{
  itc_free_owned_params (it);
  ITC_START_SEARCH_PARS (it);
  it->itc_search_mode = SM_READ;

  it->itc_insert_key = key;
  it->itc_row_key = key;
  it->itc_row_key_id = key->key_id;
  it->itc_key_id = key->key_id;
  it->itc_tree = key->key_fragments[0]->kf_it;
}


void
itc_from_it (it_cursor_t * itc, index_tree_t * it)
{
  itc_free_owned_params (itc);
  ITC_START_SEARCH_PARS (itc);
  itc->itc_search_mode = SM_READ;
  itc->itc_insert_key = it->it_key;
  itc->itc_row_key = it->it_key;
  if (it->it_key)
    {
      itc->itc_key_id = itc->itc_insert_key->key_id;
      itc->itc_row_key_id = it->it_key->key_id;
    }
  itc->itc_tree = it;
}


long ra_threshold = 10;
long ra_count = 0;
long ra_pages = 0;


int
itc_is_ra_root (it_cursor_t * itc, dp_addr_t dp)
{
  int inx;
/*  int n = MIN (RA_MAX_ROOTS, itc->itc_ra_root_fill); */
  int start = itc->itc_ra_root_fill % RA_MAX_ROOTS;
  for (inx = start - 1; inx >= 0; inx--)
    if (itc->itc_ra_root[inx] == dp)
      return 1;
  if (itc->itc_ra_root_fill > RA_MAX_ROOTS)
    for (inx = RA_MAX_ROOTS - 1; inx >= start; inx--)
      if (itc->itc_ra_root[inx] == dp)
	return 1;
  return 0;
}


int
itc_ra_sibling (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  dp_addr_t up = LONG_REF ((*buf_ret)->bd_buffer + DP_PARENT);
  dp_addr_t leaf;
  buffer_desc_t * buf = *buf_ret;
  dp_addr_t dp_from = buf->bd_page;
  if (!up)
    return DVC_INDEX_END;
  itc_up_transit (itc, buf_ret);
  itc->itc_position = find_leaf_pointer (*buf_ret, dp_from, NULL, NULL);
  if (!itc->itc_position)
    GPF_T1 ("no down pointer in read ahead parent page");
  if (itc->itc_desc_order)
    itc_prev_entry (itc, *buf_ret);
  else
    itc_skip_entry (itc, (*buf_ret)->bd_buffer);
  if (!itc->itc_position)
    return DVC_INDEX_END;
  if (DVC_MATCH != pg_key_compare (*buf_ret, itc->itc_position, itc))
    return DVC_INDEX_END;
  leaf = leaf_pointer ((*buf_ret)->bd_buffer, itc->itc_position);
  if (!leaf)
    return DVC_INDEX_END;
  itc_down_transit (itc, buf_ret, leaf);
  return DVC_MATCH;
}


int
itc_ra_quota (it_cursor_t * itc)
{
  /* do not commit more than 1/3 of available buffers to RA */
  int wanted = RA_MAX_BATCH;
  int avail = main_bufs - wi_inst.wi_n_dirty - mti_reads_queued;
  if (itc->itc_wst)
    wanted = RA_FREE_TEXT_BATCH; /* expected random access profile. Do not schedule long read ahead to keep working set */
  if (avail < 0)
    avail = 10;
  return (MIN (avail / 3, wanted));
}



ra_req_t *
itc_read_ahead1 (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  int quota;
  placeholder_t * pl = NULL;
  int org_pos;
  db_buf_t page = (*buf_ret)->bd_buffer;
  ra_req_t *ra=NULL;
  int pos = itc->itc_position;
  char was_data = itc->itc_at_data_level;

  itc->itc_at_data_level = 0;
  if (itc->itc_n_reads < ra_threshold
      || !was_data
      || itc_is_ra_root (itc, itc->itc_page)
      || !iq_is_on ())
    return NULL;
  quota = itc_ra_quota (itc);
  if (quota < 10)
    return NULL;

  ra= (ra_req_t *) dk_alloc_box(sizeof(ra_req_t),DV_CUSTOM);
  memset (ra, 0, sizeof (*ra));
  ra->ra_nsiblings=1;
  org_pos = pos;

  for (;;)
    {
      itc->itc_ra_root[itc->itc_ra_root_fill % RA_MAX_ROOTS] = (*buf_ret)->bd_page;
      itc->itc_ra_root_fill++;
      while (pos)
	{
	  dp_addr_t leaf = 0;
	  int rc = pg_key_compare (*buf_ret, pos, itc);
	  if (DVC_MATCH == rc)
	    {
	      leaf = leaf_pointer (page, pos);
	      if (leaf)
		{
		  ra->ra_dp[ra->ra_fill] = leaf;

		  ra->ra_fill++;
		  if (ra->ra_fill >= MIN (quota, RA_MAX_BATCH))
		    goto ra_scanned;
		}
	    }
	  else
	    goto ra_scanned;
	  if (itc->itc_desc_order)
	    {
	      itc->itc_position = pos;
	      itc_prev_entry (itc, *buf_ret);
	      pos = itc->itc_position;
	    }
	  else
	    pos = IE_NEXT (page + pos);
	}

      if (itc->itc_n_reads > 200
	  && ra->ra_nsiblings < RA_MAX_ROOTS / 2
	  && ra->ra_fill < RA_MAX_BATCH - 60)
	{
	  if (!pl)
	    {
	      itc->itc_position = org_pos;
	      ITC_LEAVE_MAPS (itc);
	      pl = plh_landed_copy ((placeholder_t *) itc, *buf_ret);
	    }
	  if (DVC_MATCH != itc_ra_sibling (itc, buf_ret))
	    break;
	  ra->ra_nsiblings++;
	  page = (*buf_ret)->bd_buffer;
	  pos = itc->itc_position;
	}
      else
	break;
    }
 ra_scanned:
  if (pl)
    {
      ITC_IN_KNOWN_MAP (itc, (*buf_ret)->bd_page);
      page_leave_inner (*buf_ret);
      ITC_LEAVE_MAP_NC (itc);
      *buf_ret = itc_set_by_placeholder (itc, pl);
      ITC_LEAVE_MAPS (itc);
      itc_unregister_inner ((it_cursor_t *)pl, *buf_ret, 0);
      plh_free (pl);
    }
  else
    itc->itc_position = org_pos;

  return ra;
}




void
itc_read_ahead_blob (it_cursor_t * itc, ra_req_t *ra )
{
  int inx;
  if (!itc || !ra || ra->ra_fill < 2)
    goto fin;

  if (!iq_is_on ())
    {
      goto fin;
    }
  for (inx = 0; inx < ra->ra_fill; inx++)
    {
      buffer_desc_t decoy;
      dp_addr_t phys;
      buffer_desc_t * btmp;
      ITC_IN_KNOWN_MAP (itc, ra->ra_dp[inx]);
      if (!DBS_PAGE_IN_RANGE (itc->itc_tree->it_storage, ra->ra_dp[inx]) 
	  ||dbs_is_free_page (itc->itc_tree->it_storage, ra->ra_dp[inx]) || 0 == ra->ra_dp[inx])
	{
	  log_error ("*** read-ahead of a free or out of range page dp L=%ld, database not necessarily corrupted.",
	       ra->ra_dp[inx]);
	  ITC_LEAVE_MAP_NC (itc);
	  continue;
	}
      btmp = IT_DP_TO_BUF (itc->itc_tree, ra->ra_dp[inx]);
	IT_DP_REMAP (itc->itc_tree, ra->ra_dp[inx], phys);
      if (DP_DELETED == phys)
	{
	  /* between finding the page and here, the page may have been deleted.  OIr reused for sth else. Latter is not dangerous, it will just not be found and will move out with cache replacement */
	  log_error ("Read ahead of page deleted in commit space, LL=%d not dangerous.\n", ra->ra_dp[inx]);
	  ITC_LEAVE_MAP_NC (itc);
	  continue;
	}
      if (!btmp)
	{
	  memset (&decoy, 0, sizeof (decoy));
	  decoy.bd_being_read = 1;
	  decoy.bd_is_write = 1;
	  decoy.bd_page = ra->ra_dp[inx];
	  decoy.bd_tree = itc->itc_tree;
	  sethash (DP_ADDR2VOID (ra->ra_dp[inx]), &IT_DP_MAP (itc->itc_tree, ra->ra_dp[inx])->itm_dp_to_buf, (void*) &decoy);
		      
	  ITC_LEAVE_MAP_NC (itc);
	  btmp = bp_get_buffer (NULL, BP_BUF_IF_AVAIL);
	  ITC_IN_KNOWN_MAP (itc, ra->ra_dp[inx]);
	  remhash (DP_ADDR2VOID (ra->ra_dp[inx]), &IT_DP_MAP (itc->itc_tree, ra->ra_dp[inx])->itm_dp_to_buf);
	  if (!btmp)
	    {
	      page_mark_change (&decoy, 1 + RWG_WAIT_ANY);
	      page_leave_inner (&decoy);
	      ITC_LEAVE_MAP_NC (itc);
	      break;
	    }
	  if (decoy.bd_read_waiting || btmp->bd_write_waiting)
	    TC (tc_read_wait_while_ra_finding_buf);
	  ra->ra_bufs[ra->ra_bfill++] = btmp;

	  if (!ra->ra_dp[inx])
	    GPF_T1 ("Scheduling 0 for read ahead.\n");
	  sethash (DP_ADDR2VOID (ra->ra_dp[inx]), &IT_DP_MAP (itc->itc_tree, ra->ra_dp[inx])->itm_dp_to_buf, (void*) btmp);
	  btmp->bd_page = ra->ra_dp[inx];
	  btmp->bd_physical_page = phys;
	  btmp->bd_tree = itc->itc_tree;
	  btmp->bd_storage = btmp->bd_tree->it_storage;
	  btmp->bd_being_read = 1;
	  btmp->bd_readers = 0;
	  BD_SET_IS_WRITE (btmp, 1);
	  btmp->bd_write_waiting = decoy.bd_write_waiting;
	  btmp->bd_read_waiting = decoy.bd_read_waiting;
	  ITC_LEAVE_MAP_NC (itc);
	  itc->itc_n_reads++;
	  ITC_MARK_READ (itc);
	  DBG_PT_PRINTF ((" SCH RA L=%d P=%d B=%p \n", btmp->bd_page, btmp->bd_physical_page, btmp));
	}
      else
	{
	  ITC_LEAVE_MAP_NC (itc);
	  if (btmp->bd_pool)
	    BUF_TOUCH (btmp); /* make sure won't get replaced if already in */
	  /* check that btmp has bd_pool, because this is nil if the btmp is a decoy in read-ahead */
	}
    }
  ITC_LEAVE_MAPS (itc);
  if (ra->ra_bfill)
    {
      ra_count++;
      ra_pages += ra->ra_bfill;
      if (ra->ra_nsiblings > 1)
	dbg_printf (("RA %d sibling %d pages %d leaves\n", ra->ra_nsiblings, ra->ra_bfill, ra->ra_fill));
      iq_schedule (ra->ra_bufs, ra->ra_bfill);
    }
  ITC_LEAVE_MAPS (itc);
fin:
  if (ra)
    dk_free_box((box_t) ra);
}


void
itc_read_ahead (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  itc_read_ahead_blob (itc, itc_read_ahead1 (itc, buf_ret));
}


extern long tc_bp_get_buffer;
int enable_read_aside = 1;

ra_req_t *
itc_read_aside (it_cursor_t * itc, buffer_desc_t * buf, dp_addr_t dp)
{
  /* take leaves that are not dp.  If all are absent, schedule them all for read ahead */
  dp_addr_t leaves[1000];
  int fill = 0;
  db_buf_t page = buf->bd_buffer;
  ra_req_t *ra=NULL;
  int pos = SHORT_REF (page + DP_FIRST);

  if (tc_bp_get_buffer > main_bufs - 100 || !enable_read_aside)
    return NULL;
  while (pos)
    {
      dp_addr_t leaf = 0;
      leaf = leaf_pointer (page, pos);
      if (leaf && leaf != dp)
	{
	  buffer_desc_t * btmp;
	  ITC_IN_KNOWN_MAP (itc, leaf);
	  if (!DBS_PAGE_IN_RANGE (itc->itc_tree->it_storage, leaf) 
	      ||dbs_is_free_page (itc->itc_tree->it_storage, leaf) || 0 == leaf)
	    {
	      log_error ("*** read-ahead of a free or out of range page dp L=%ld, database not necessarily corrupted.",
			 leaf);
	      ITC_LEAVE_MAP_NC (itc);
	      return NULL;
	    }
	  btmp = IT_DP_TO_BUF (itc->itc_tree, leaf);
	  if (btmp)
	    {
	      ITC_LEAVE_MAP_NC (itc);
	      return NULL;
	    }
	  ITC_LEAVE_MAP_NC (itc);
	  leaves[fill++] = leaf;
	}
      pos = IE_NEXT (page + pos);
    }

  ra= (ra_req_t *) dk_alloc_box(sizeof(ra_req_t),DV_CUSTOM);
  memset (ra, 0, sizeof (*ra));
  memcpy (&ra->ra_dp, leaves, fill * sizeof (dp_addr_t));
  ra->ra_fill = fill;
  return ra;
}

/* random search support */


int 
itc_up_rnd_check (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  if (itc->itc_st.n_sample_rows >= itc->itc_st.sample_size)
    return DVC_INDEX_END;
  itc->itc_st.n_sample_rows++; /* increment here also so as to guarantee termination even if table goes empty during the random scan. */
  itc_page_leave (itc, *buf_ret);
  *buf_ret = itc_reset (itc);
  return DVC_MATCH;
}


void
itc_col_stat_free (it_cursor_t * itc, int upd_col, float est)
{
  dk_hash_iterator_t it;
  id_hash_iterator_t hit;

  dbe_column_t * col;
  col_stat_t * cs;
  caddr_t * data;
  ptrlong * count;
  dk_hash_iterator (&it, itc->itc_st.cols);
  while (dk_hit_next (&it, (void**) &col, (void**) &cs))
    {
      boxint min = 0, max = 0;
      int is_first = 1;
      int is_int = DV_LONG_INT == col->col_sqt.sqt_dtp || DV_INT64 == col->col_sqt.sqt_dtp;
      if (upd_col && (0 == stricmp (col->col_name, "P") || 0 == stricmp (col->col_name, "G")))
	{
	  col->col_stat = cs;
	  is_int = 0;
	}
      else
	{
	  id_hash_iterator (&hit, cs->cs_distinct);
	  while (hit_next (&hit, (caddr_t*) &data, (caddr_t*) &count))
	    {
	      if (is_int)
		{
		  boxint d = unbox (*data);
		  if (is_first)
		    {
		      is_first = 0;
		      min = max = d;
		    }
		  else
		    {
		      if (d > max)
			max = d;
		      if (d < min)
			min = d;
		    }
		}
	      dk_free_tree (*data);
	    }
	  
	}
      if (upd_col)
	{
	  col->col_count = cs->cs_n_values / (float) itc->itc_st.n_sample_rows * est;
	  if (itc->itc_st.n_sample_rows)
	    {
	      /* if n distinct under 2% of samples, assume that this is a flag.  If more distinct, scale pro rata.  */
	      if (cs->cs_distinct->ht_inserts < itc->itc_st.n_sample_rows / 50)
		col->col_n_distinct = cs->cs_distinct->ht_inserts;
	      else 
		col->col_n_distinct = (float)cs->cs_distinct->ht_inserts / (float)itc->itc_st.n_sample_rows * est;
	      col->col_avg_len = cs->cs_len / itc->itc_st.n_sample_rows;
	      if (is_int && !is_first)
		{
		  /* if it is an int then the max distinct is the difference between min and max seen */
		  col->col_min = box_num (min);
		  col->col_max = box_num (max);
		  if (col->col_n_distinct > max - min)
		    col->col_n_distinct = max - min;
		}
	    }
	  else 
	    {
	      col->col_n_distinct = 1;
	      col->col_avg_len = 0; /* no data, use declared prec instead */
	    }
	}
      if (col->col_stat != cs)
	{
	  id_hash_free (cs->cs_distinct);
	  dk_free ((caddr_t) cs, sizeof (col_stat_t));
	}
    }
  hash_table_free (itc->itc_st.cols);
  itc->itc_st.cols = NULL;
}


void
itc_row_col_stat (it_cursor_t * itc, buffer_desc_t * buf)
{
  db_buf_t page = buf->bd_buffer;
  int pos  = itc->itc_position;
  key_id_t key_id = SHORT_REF (page + pos + IE_KEY_ID);
  dbe_key_t * key;
  if (!key_id ||  KI_LEFT_DUMMY == key_id)
    return;
  itc->itc_st.n_sample_rows++;
  itc->itc_row_data = page + pos +  IE_FIRST_KEY;
  itc->itc_row_key_id = key_id;
  itc->itc_row_key = key = sch_id_to_key (wi_inst.wi_schema, key_id);
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      col_stat_t * col_stat;
      caddr_t data = NULL;
      dbe_column_t * current_col;
      int len, off, is_data = 0;
      ptrlong * place;
      dbe_col_loc_t *cl  = key_find_cl (key, col->col_id);
      ITC_COL (itc, (*cl), off, len);
      if (!IS_BLOB_DTP (col->col_sqt.sqt_dtp))
	{
	  data = itc_box_column (itc, page, col->col_id, cl); 
	  is_data = 1;
	}
      current_col = sch_id_to_column (wi_inst.wi_schema, col->col_id);
      /* can be obsolete row, use the corresponding col of the current version of th key */
      col_stat = (col_stat_t *) gethash ((void*) current_col, itc->itc_st.cols);
      if (!col_stat)
	{
	  NEW_VARZ (col_stat_t, cs);
	  sethash ((void*)current_col, itc->itc_st.cols, (void*) cs);
	  cs->cs_distinct = id_hash_allocate (1001, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
	  col_stat = cs;
	}

      if (is_data)
	{
	  if (DV_DB_NULL != DV_TYPE_OF (data))
	    {
	      col_stat->cs_n_values++;
	      col_stat->cs_len += len;
	    }
	  place = (ptrlong *) id_hash_get (col_stat->cs_distinct, (caddr_t) &data);
	  if (place)
	    {
	      (*place)++;
	      dk_free_tree (data);
	    }
	  else
	    {
	      ptrlong one = 1;
	      id_hash_set (col_stat->cs_distinct, (caddr_t) &data, (caddr_t)&one);
	    }
	}
    }
  END_DO_SET();
}

void
itc_page_col_stat (it_cursor_t * itc, buffer_desc_t * buf)
{
  db_buf_t page = buf->bd_buffer;
  int pos = itc->itc_position;
  itc->itc_position = SHORT_REF (page+ DP_FIRST);
  while (itc->itc_position)
    {
      itc_row_col_stat (itc, buf);
      itc->itc_position = IE_NEXT (page + itc->itc_position);
    }
  itc->itc_position = pos;
}


int
itc_page_split_search_1 (it_cursor_t * it, buffer_desc_t * buf,
		       dp_addr_t * leaf_ret)
{
  db_buf_t page = buf->bd_buffer;
  int res;
  page_map_t *map = buf->bd_content_map;
  int below = map->pm_count;
  int at_or_above = 0;
  int guess;
  int at_or_above_res = -100;
  key_id_t key_id;
  if (PA_READ == it->itc_dive_mode ? buf->bd_is_write : !buf->bd_is_write)
    GPF_T1 ("split search supposed to be in read mode");
  if (map->pm_count == 0)
    {
      it->itc_position = 0;
      *leaf_ret = 0;
      return DVC_GREATER;
    }


  for (;;)
    {
      if ((below - at_or_above) <= 1)
	{
	  if (at_or_above_res == -100)
	    {
	      at_or_above_res = pg_key_compare (buf,
						       map->pm_entries[at_or_above], it);
	    }
	  switch (at_or_above_res)
	    {
	    case DVC_MATCH:
	    case DVC_LESS:
	      {
	      it->itc_position = map->pm_entries[at_or_above];
	      it->itc_map_pos = at_or_above;
	      key_id = SHORT_REF (page + it->itc_position + IE_KEY_ID);
	      if (!key_id || KI_LEFT_DUMMY == key_id)
		*leaf_ret = LONG_REF (page + map->pm_entries[at_or_above] + IE_LEAF);
	      else
		*leaf_ret = 0;
		return at_or_above_res;
	      }
	    case DVC_GREATER:
	      {
		/* The lower limit, 0 was greater. No way down. */
		it->itc_position = map->pm_entries[at_or_above];
		it->itc_map_pos = at_or_above;
		*leaf_ret = 0;
		return DVC_GREATER;
	      }
	    }
	}
      /* OK, we have an interval to search */
      guess = at_or_above + ((below - at_or_above) / 2);
      res = pg_key_compare (buf, map->pm_entries[guess],
	  it);
      switch (res)
	{
	case DVC_LESS:
	  at_or_above = guess;
	  at_or_above_res = res;
	  break;
	case DVC_MATCH:	/* row found, dependent not checked */
	  if (it->itc_desc_order)
	    {
	      at_or_above = guess;
	      at_or_above_res = res;
	    }
	  else
	    {
	      below = guess;
	    }
	  break;

	case DVC_GREATER:
	  below = guess;
	  break;
	}
    }
}



int32 inx_rnd_seed;

int 
itc_random_leaf (it_cursor_t * itc, buffer_desc_t *buf, dp_addr_t * leaf_ret)
{
  db_buf_t page = buf->bd_buffer;
  page_map_t * pm = buf->bd_content_map;
  int nth, pos;
  key_id_t key_id;
  if (pm->pm_count )
    nth = sqlbif_rnd (&inx_rnd_seed) % pm->pm_count;
  else 
    return DVC_INDEX_END;
  pos = pm->pm_entries[nth];
  key_id = SHORT_REF (page + pos + IE_KEY_ID);
  *leaf_ret = !key_id ||  key_id == KI_LEFT_DUMMY ? LONG_REF (page + pos + IE_LEAF) : 0;
  itc->itc_position = SHORT_REF (page + DP_FIRST);  /* ret pos at start even if leaf taken is not the first so that itc_sample gets to count all leaves */
    return DVC_MATCH;
}


int
itc_matches_on_page (it_cursor_t * itc, buffer_desc_t * buf, int * leaf_ctr_ret, int * rows_per_bm, dp_addr_t * alt_leaf_ret, int angle)
{
  dp_addr_t leaves[PAGE_DATA_SZ / 8];
  int leaf_fill = 0;
  db_buf_t page = buf->bd_buffer;
  int have_left_leaf = 0, was_left_leaf = 0;
  int pos = itc->itc_position; /* itc is at leftmost match. Nothing at left of the itc */
  int save_pos = itc->itc_position;
  int ctr = 0, leaf_ctr = 0, row_ctr = 0;
  while (pos)
    {
      int res = DVC_MATCH;
      search_spec_t * sp = itc->itc_key_spec.ksp_spec_array;
      key_id_t r_k_id = SHORT_REF (page + pos + IE_KEY_ID);
      itc->itc_row_data = page + pos + (r_k_id ? IE_FIRST_KEY : IE_LP_FIRST_KEY);
      if (KI_LEFT_DUMMY == r_k_id)
	{
	  if (LONG_REF (page + pos + IE_LEAF))
	    {
	      was_left_leaf = have_left_leaf = 1;
	      leaves[leaf_fill++] = LONG_REF (page + pos + IE_LEAF);
	      leaf_ctr++;
	    }
	}
      else 
	{
	  itc->itc_row_key_id = r_k_id;
	  if (r_k_id)
	    itc->itc_row_key = sch_id_to_key (isp_schema (NULL), r_k_id);
	  while (sp)
	    {
	      if (DVC_MATCH != (res = itc_compare_spec (itc, sp)))
		break;
	      sp = sp->sp_next;
	    }
	  if (DVC_MATCH == res)
	    {
	      if (r_k_id)
		{
		  row_ctr++;
		  if (itc->itc_insert_key->key_is_bitmap)
		    {
		      save_pos = itc->itc_position;
		      itc->itc_position = pos;
		      ctr += itc_bm_count (itc, buf);
		      itc->itc_position = save_pos;
		    }
		  else 
		    ctr++;
		}
	      else 
		{
		  dp_addr_t leaf1 = LONG_REF (page + pos + IE_LEAF);
		  leaves[leaf_fill++] = leaf1;
		  if (have_left_leaf)
		    {
		      /* prefer giving the next to leftmost instead of leftmost leaf if leftmost is left dummy.
		       * The leftmost branch can be empty because the leaf with the left dummy never can get deleted */
		      *alt_leaf_ret = leaf1;
		      have_left_leaf = 0;
		    }
		  leaf_ctr++;
		}
	    }
	}
      pos = IE_NEXT (page + pos);
    }
  *leaf_ctr_ret = leaf_ctr;
  if (row_ctr)
    *rows_per_bm = ctr / row_ctr;
  else
    *rows_per_bm = 1;
  if (leaf_ctr && angle != -1)
    {
      /* angle is a measure between 0 to 999.  Scale it to leaf count and pick the leaf */
      int nth = (leaf_ctr * angle) / 1000;
      *alt_leaf_ret = leaves[MIN (nth, leaf_ctr - 1)];
    }
  return ctr;
}


int64
itc_sample_1 (it_cursor_t * it, buffer_desc_t ** buf_ret, int64 * n_leaves_ret, int angle)
{
  dp_addr_t leaf, rnd_leaf;
  int res;
  int ctr  = 0, leaf_ctr = 0, rows_per_bm;
  int64 leaf_estimate = 0;

  it->itc_search_mode = SM_READ;
 start:
  if (!(*buf_ret)->bd_readers && !(*buf_ret)->bd_is_write)
    GPF_T1 ("buffer not wired occupied in itc_search");
  leaf = 0;
  it->itc_is_on_row = 0;

  ITC_LEAVE_MAPS (it);
  if (!(*buf_ret)->bd_content_map)
    {
      log_error ("Suspect index page dp=%d key=%s, probably blob ref'd as index node.", (*buf_ret)->bd_page, it->itc_insert_key->key_name);
      return 0;
    }
  rnd_leaf = 0;
  if (RANDOM_SEARCH_ON == it->itc_random_search)
    res = itc_random_leaf (it, *buf_ret, &rnd_leaf);
  else 
    res = itc_page_split_search_1 (it, *buf_ret, &leaf);
  if (it->itc_st.cols)
    itc_page_col_stat (it, *buf_ret);
  ctr = itc_matches_on_page (it, *buf_ret, &leaf_ctr, &rows_per_bm, &leaf, angle);
  if (leaf_estimate)
    leaf_estimate = (((float)leaf_estimate) - 0.5) * (*buf_ret)->bd_content_map->pm_count * rows_per_bm
+ leaf_ctr;
  else if (leaf_ctr > 1)
    leaf_estimate = leaf_ctr - 1;
  if (rnd_leaf)
    leaf = rnd_leaf;
  switch (res)
    {
    case DVC_LESS:
    case DVC_MATCH:
      {
	if (leaf)
	  {
	    /* Go down on the right edge. */
	    itc_down_transit (it, buf_ret, leaf);
	    if (it->itc_write_waits >= 1000 || it->itc_read_waits >= 1000)
	      {
		/* if the cursor had a wait, a reset or any such thing, the path from top to bottom is not the normal one and the sample must be discarded */
		int old_rnd = it->itc_random_search;
		itc_page_leave (it, *buf_ret);
		it->itc_random_search = RANDOM_SEARCH_ON; /* disable use of root cache by itc_reset */
		*buf_ret = itc_reset (it);
		it->itc_random_search = old_rnd;
		it->itc_read_waits = 0;
		it->itc_write_waits = 0;
		TC (tc_key_sample_reset);
		ctr = leaf_ctr = leaf_estimate = 0;
	      }
	    goto start;
	  }
	break;
      }
    case DVC_GREATER:
    case DVC_INDEX_END:
      {
	break;
      }
    }
  if (n_leaves_ret)
    *n_leaves_ret = leaf_estimate;
 
  return ctr + leaf_estimate;
}


void 
samples_stddev (int64 * samples, int n_samples, float * mean_ret, float * stddev_ret)
{
  int inx;
  float mean = 0, var = 0;
  for (inx = 0; inx < n_samples; inx++)
    mean += (float) samples[inx];
  mean /= n_samples;
  for (inx = 0; inx < n_samples; inx++)
    {
      float d = samples[inx] - mean;
      var += d * d;
    }
  *stddev_ret = sqrt (var / n_samples);
  *mean_ret = mean;
}

#define MAX_SAMPLES 20

int64
itc_sample (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  float mean, stddev;
  int64 samples[MAX_SAMPLES];
  int64 n_leaves, sample, tb_count;
  dbe_table_t * tb = itc->itc_insert_key->key_table;
  int n_samples = 1;
  if (!itc->itc_key_spec.ksp_spec_array)
    return itc_sample_1 (itc, buf_ret, NULL, -1);
  samples[0] = itc_sample_1 (itc, buf_ret, &n_leaves, -1);
  if (!n_leaves)
    return samples[0];
  {
    int angle, step = 248, offset = 5;
    for (;;)
      {
	for (angle = step + offset; angle < 1000; angle += step)
	  {
	    itc_page_leave (itc, *buf_ret);
	    itc->itc_random_search = RANDOM_SEARCH_ON;
	    *buf_ret = itc_reset (itc);
	    itc->itc_random_search = RANDOM_SEARCH_OFF;
	    sample = itc_sample_1 (itc, buf_ret , &n_leaves, angle);
	    tb_count = tb->tb_count == DBE_NO_STAT_DATA ? tb->tb_count_estimate : tb->tb_count;
	    tb_count = MAX (tb_count, 1);
	    if (sample < 0 || sample > tb_count)
	      sample = (tb_count * 3) / 4;
	    samples[n_samples++] = sample;
	    if (n_samples == MAX_SAMPLES)
	      break;
	  }
	samples_stddev (samples, n_samples, &mean, &stddev);
	if (n_samples >  MAX_SAMPLES - 2 || stddev < mean / 3)
	  break;
	offset += step / 5;
	step /= 2;
      }
  }
  return ((int64) mean);
}    


unsigned int64
key_count_estimate  (dbe_key_t * key, int n_samples, int upd_col_stats)
{
  int64 res = 0, sample;
  int n;
  buffer_desc_t * buf;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  ITC_INIT (itc, key->key_fragments[0]->kf_it, NULL);
  itc_clear_stats (itc);
  itc_from (itc, key);
  itc->itc_random_search = RANDOM_SEARCH_ON;
  if (upd_col_stats)
    itc->itc_st.cols = hash_table_allocate (23);
  for (n = 0; n < n_samples; n++)
    {
      itc->itc_random_search = RANDOM_SEARCH_ON; /* disable use of root cache by itc_reset */
      buf = itc_reset (itc);
      sample = itc_sample (itc, &buf);
      if (sample < 0 || sample > 1e12)
	sample = 100000000; /* arbitrary.  If tree badly skewed will return nonsense figures */
      res += sample;
      itc_page_leave (itc, buf);
      if (upd_col_stats)
	{
	  /* if doing cols also, adjust the sample to table size */
	  if (n_samples < 100 && itc->itc_st.n_sample_rows < 0.01 * res / (n + 1))
	    n_samples++;
	}
    }
  if (upd_col_stats)
    itc_col_stat_free (itc, 1, res / n_samples);
  return res / n_samples;
}


int 
key_rdf_lang_id (caddr_t name)
{
  int res;
  int id = 0;
  dbe_table_t * tb = sch_name_to_table (wi_inst.wi_schema, "DB.DBA.RDF_LANGUAGE");
  dbe_key_t * key = tb ? tb->tb_primary_key : NULL;
  dbe_column_t * twobyte_col = key && key->key_parts && key->key_parts->next ? key->key_parts->next->data : NULL;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  buffer_desc_t * buf;
  search_spec_t sp;
  if (!twobyte_col)
    return 0;
  ITC_INIT (itc, key->key_fragments[0]->kf_it, NULL);
  itc_from (itc, key);
  ITC_SEARCH_PARAM (itc, name);
  itc->itc_isolation = ISO_UNCOMMITTED;
  itc->itc_key_spec.ksp_spec_array = &sp;
  itc->itc_key_spec.ksp_key_cmp = NULL;
  memset (&sp, 0, sizeof (sp));
  sp.sp_min_op = CMP_EQ;
  sp.sp_cl = *key_find_cl (key, ((dbe_column_t *) key->key_parts->data)->col_id);
  ITC_FAIL (itc)
    {
      buf = itc_reset (itc);
      res = itc_search (itc, &buf);
      if (DVC_MATCH == res)
	{
	  id = (int) (ptrlong) itc_box_column (itc, buf->bd_buffer, twobyte_col->col_id, NULL);
	}
      itc_page_leave (itc, buf);
    }
	ITC_FAILED
      {
	return 0;
      }
  END_FAIL (itc);
  itc_free (itc);
  return id;
}


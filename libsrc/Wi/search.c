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
#ifndef O12
  db_buf_const_length[DV_G_REF_CLASS] = -1;
#endif
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
#ifndef O12
    case DV_G_REF_CLASS:
    case DV_G_REF:
#endif
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
    default:
      /* Locate buffer with bad page */
      for (bd = wi_inst.wi_bps[0]->bp_first_buffer; bd; bd = bd->bd_prev)
	if (bd->bd_buffer < buf && bd->bd_buffer + PAGE_SZ > buf)
	  break;
      /* Report */
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
#ifdef O12
  return NULL;
#else
  int ign1/*, ign2*/;
  int ct, rc1, rc2;
  buffer_desc_t * buf = NULL;
  dp_addr_t dp, phys;
  index_space_t * isp;
  dbe_key_t * key = itc->itc_insert_key;
  if (!dive_cache_enable)
    return NULL;
  if (! (itc->itc_search_mode == SM_READ_EXACT || itc->itc_search_mode == SM_INSERT))
    return NULL;
  if (!key || !itc->itc_specs)
    return NULL;
  ITC_IN_MAP (itc);
  dp = key->key_last_page;
  if (!dp)
    return NULL;
  if (key->key_n_landings / (key->key_total_last_page_hits | 1) > dive_cache_enable)
    return NULL;

  buf = isp_locate_page (itc->itc_space, dp, &isp, &phys);
  if (!buf
      || !buf->bd_page
      || buf->bd_is_write
      || buf->bd_write_waiting
      || buf->bd_to_bust
      || DPF_INDEX != SHORT_REF (buf->bd_buffer + DP_FLAGS)
      || it_is_free_page (db_main_tree, dp))
    return NULL;
  ct = buf->bd_content_map->pm_count;
  if (ct < 2)
    return NULL;

  TC (tc_dive_cache_compares);

  rc1 = pg_insert_key_compare (buf, buf->bd_content_map->pm_entries[0],
			       itc);
  if (rc1 == DVC_GREATER)
    return NULL;
  rc2 = pg_insert_key_compare (buf, buf->bd_content_map->pm_entries[ct - 1],
			       itc);
  if (rc2 == DVC_LESS)
    return NULL;
  buf->bd_readers++;
  itc->itc_page = buf->bd_page;
  TC (tc_dive_cache_hits);
  return buf;
#endif
}


int
itc_col_check (it_cursor_t * itc, search_spec_t * spec, int param_inx)
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
	  n2 = unbox (param);
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
	default: GPF_T;
	}

    case DV_SHORT_INT:
      n1 = SHORT_REF (row + spec->sp_cl.cl_pos);
	      goto int_cmp;
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
	iri_id_t i1 = (iri_id_t)(unsigned long) LONG_REF (row + spec->sp_cl.cl_pos);
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
	      key = itc->itc_row_key;
	      off = key->key_row_var_start;
	    }
	  n1 = SHORT_REF (row + key->key_length_area) - off;
	  dv1 = row + off;
	}
      else if (n1 > 0)
	GPF_T1 ("fixed length compares should be covered by now");
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
      n2 = box_length (dv2) - 1;
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


buffer_desc_t *
itc_reset (it_cursor_t * it)
{
  /* Enter to root in read mode and return the buffer */
  buffer_desc_t *buf = NULL;

  it->itc_position = 0;
  it->itc_landed = 0;
  it->itc_is_on_row = 0;
  it->itc_nth_seq_page = 0;
  it->itc_n_lock_escalations = 0;
  it->itc_ra_root_fill = 0;
  it->itc_n_reads = 0;
  it->itc_at_data_level = 0;

  ITC_IN_MAP (it);
  itc_unregister (it, INSIDE_MAP);

  it->itc_to_reset = 0;
  it->itc_page = 0;
  if (it->itc_tree->it_hi)
    {
      ITC_IN_MAP (it);
      page_wait_access (it, it->itc_tree->it_hash_first, NULL, NULL, &buf, PA_READ, RWG_WAIT_ANY);
	ITC_LEAVE_MAP (it);
      it->itc_position = SHORT_REF (buf->bd_buffer + DP_FIRST);
      it->itc_page = buf->bd_page;
      it->itc_landed = 1;
	return buf;
    }

  buf = itc_dive_cache_check (it);
  if (buf)
    return buf;
  for (;;)
    {
      dp_addr_t dp, back_link;
      ITC_IN_MAP (it);
      dp = it->itc_space->isp_root;
      page_wait_access (it, dp, NULL, NULL, &buf, PA_READ, RWG_WAIT_KEY);
      if (it->itc_to_reset > RWG_WAIT_KEY)
	continue;
      back_link = LONG_REF (buf->bd_buffer + DP_PARENT);
      if (back_link)
	{
           log_error ("Bad parent link in the tree start page %ld, parent link=%ld."
	       " Please do a dump and restore.",
	       dp, back_link);
	}
      it->itc_page = dp;
      break;
    }
#ifdef NEW_HASH
  itc_hi_source_page_used (it, it->itc_page);
#endif
  ITC_LEAVE_MAP(it);
  return buf;
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
      IN_PAGE_MAP (hb->bd_space->isp_tree);
      page_leave_inner (hb);
      LEAVE_PAGE_MAP (hb->bd_space->isp_tree);
      it->itc_hash_buf = NULL;
    }
  if (it->itc_buf)
    {
      buffer_desc_t * hb = it->itc_buf;
      ITC_IN_MAP (it);
      page_leave_inner (hb);
    }
  if (it->itc_space_registered)
    {
      ITC_IN_MAP (it);
      itc_unregister (it, INSIDE_MAP);
    }
  ITC_LEAVE_MAP (it);
#ifndef O12
  if (it->itc_extension)
    {
      dk_free_box (it->itc_extension);
      it->itc_extension = NULL;
    }
#endif
  if (it->itc_st.cols)
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
  itc_clear (it);
  if (it->itc_is_allocated)
    dk_free ((caddr_t) it, sizeof (it_cursor_t));
}


void
plh_free (placeholder_t * pl)
{
  itc_unregister ((it_cursor_t *) pl, OUTSIDE_MAP);
  dk_free ((caddr_t) pl, sizeof (placeholder_t));
}


placeholder_t *
plh_copy (placeholder_t * pl)
{

  NEW_VAR (placeholder_t, new_pl);
  mutex_enter (pl->itc_space->isp_tree->it_page_map_mtx);
  memcpy (new_pl, pl, ITC_PLACEHOLDER_BYTES);
  new_pl->itc_space_registered = NULL;
  itc_register_cursor ((it_cursor_t *) new_pl, INSIDE_MAP);
  mutex_leave (pl->itc_space->isp_tree->it_page_map_mtx);
  return new_pl;
}


buffer_desc_t *
itc_set_by_placeholder (it_cursor_t * itc, placeholder_t * pl)
{
  buffer_desc_t *buf;
  if (itc->itc_space_registered)
    {
      ITC_IN_MAP (itc);
      itc_unregister (itc, INSIDE_MAP);
      ITC_LEAVE_MAP (itc);
    }
  itc->itc_space = pl->itc_space;
  itc->itc_tree = pl->itc_space->isp_tree;
  for (;;)
    {
      CHECK_TRX_DEAD (itc, NULL, ITC_BUST_CONTINUABLE);
      ITC_IN_MAP (itc); /* check_trx_dead may freeze and return and have itc not in map */
      memcpy (itc, pl, ITC_PLACEHOLDER_BYTES);

      itc->itc_landed = 1;
      itc->itc_space_registered = NULL;
      itc->itc_type = ITC_CURSOR;

      page_wait_access (itc, pl->itc_page, NULL, NULL, &buf, PA_WRITE, RWG_NO_WAIT);
      if (itc->itc_to_reset <= RWG_NO_WAIT)
	break;
      TC (tc_set_by_pl_wait);
    }
  ITC_IN_MAP (itc);
  ITC_FIND_PL (itc, buf);
  itc->itc_position = pl->itc_position;
  /* Set now when in, if it moved while waiting. */
  ITC_LEAVE_MAP (itc);
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
  return DVC_LESS;
}


int
dv_compare (db_buf_t dv1, db_buf_t dv2, collation_t *collation)
{
  int inx = 0;
  dtp_t dtp1 = *dv1;
  dtp_t dtp2 = *dv2;
  int32 n1 = 0, n2 = 0;			/*not used before set */
  int64 ln1, ln2;


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
#ifndef O12
      case DV_G_REF:
	n1 = dv1[1];
	dv1 += 2;
	collation = NULL;
	break;
      case DV_G_REF_CLASS:
	n1 = dv1[1] - 4;
	dv1 += 2;
	dtp1 = DV_G_REF;
	collation = NULL;
	break;
#endif
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
	ln1 = (iri_id_t) (unsigned long) LONG_REF_NA (dv1 + 1);
	break;
      case DV_IRI_ID_8:
	dtp1 = DV_IRI_ID;
	ln1 = INT64_REF_NA (dv1 + 1);
	break;
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
#ifndef O12
      case DV_G_REF:
	n2 = dv2[1];
	dv2 += 2;
	collation = NULL;
	break;
      case DV_G_REF_CLASS:
	n2 = dv2[1] - 4;
	dtp2 = DV_G_REF;
	dv2 += 2;
	collation = NULL;
	break;
#endif
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
	ln2 = (iri_id_t) (unsigned long) LONG_REF_NA (dv2 + 1);
	break;
      case DV_IRI_ID_8:
	dtp2 = DV_IRI_ID;
	ln2 = INT64_REF_NA (dv2 + 1);
	break;

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
#ifndef O12
	  case DV_G_REF:
#endif
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
	dtp_t res_dtp;
	dtp1 = dv_ext_to_num (dv1, (caddr_t) & dn1);
	dtp2 = dv_ext_to_num (dv2, (caddr_t) & dn2);

	n_coerce ((caddr_t) & dn1, (caddr_t) & dn2, dtp1, dtp2, &res_dtp);
	switch (res_dtp)
	  {
	  case DV_SINGLE_FLOAT:
	    return cmp_double (*(float *) &dn1, *(float *) &dn2, FLT_EPSILON);
	  case DV_DOUBLE_FLOAT:
	    return cmp_double (*(double *) &dn1, *(double *) &dn2, DBL_EPSILON);
	  case DV_NUMERIC:
	    return (numeric_compare_dvc ((numeric_t) &dn1, (numeric_t) &dn2));
	  default:
	    GPF_T;		/* Impossible num type combination */
	  }
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
#ifndef O12
    case DV_G_REF_CLASS:
      collation = NULL;
      break;
    case DV_G_REF:
      collation = NULL;
      break;
#endif
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
      res = itc_col_check (itc, spec, spec->sp_min);

      /* The min operation is 1. EQ. 2 GTE, 3 GT */
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
      res = itc_col_check (itc, spec, spec->sp_max);

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
  ITC_IN_MAP (itc);
  page_leave_inner (*buf_ret);
  page_wait_access (itc, next, NULL, NULL, buf_ret, PA_READ, RWG_WAIT_ANY);
  ITC_LEAVE_MAP (itc);
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

  ITC_LEAVE_MAP (itc);
  if (RANDOM_SEARCH_ON == itc->itc_random_search)
    itc->itc_st.n_sample_rows++;
  if (key != itc->itc_key_id)
    {
	{
	  if (!sch_is_subkey (isp_schema (NULL), key, itc->itc_key_id))
	    return DVC_LESS;	/* Key specified but this ain't it */
	  else
	    itc->itc_row_key = row_key = sch_id_to_key (isp_schema (NULL), key);
	}
    }

  sp = itc->itc_row_specs;
  if (sp)
    {
      if (SPEC_NOT_APPLICABLE == sp)
	return DVC_LESS;
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
		return DVC_LESS;
	    }

	  if (ITC_NULL_CK (itc, sp->sp_cl))
	    return DVC_LESS;
	  if (DVC_CMP_MASK & op)
	    {
	      if (0 == (op & itc_col_check (itc, sp, sp->sp_min)))
		return DVC_LESS;
	    }
	  else if (op == CMP_LIKE)
	    {
	      if (DVC_MATCH != itc_like_compare (itc, itc->itc_search_params[sp->sp_min], sp))
		return DVC_LESS;
	      goto next_sp;;
	    }
	  if (sp->sp_max_op != CMP_NONE
	      && (0 == (sp->sp_max_op & itc_col_check (itc, sp, sp->sp_max))))
	    return DVC_LESS;
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
			qst_set_bin_string (itc->itc_out_state, ssl, (db_buf_t) "", 0, DV_DB_NULL);
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
  int res, pos, map_pos;

  dp_addr_t leaf_from, up;

  if (ISO_SERIALIZABLE == it->itc_isolation && SM_INSERT != it->itc_search_mode)
    it->itc_search_mode = SM_READ; /* no exact, must set follow lock to item before match range */
start:
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
  CHECK_TRX_DEAD (it, buf_ret, ITC_BUST_CONTINUABLE);
  leaf = 0;
#ifndef PMN_THREADS
  THREAD_ALLOW_SWITCH ();
#endif
  it->itc_is_on_row = 0;

  ITC_LEAVE_MAP (it);
  if (!it->itc_landed)
    {
      if (RANDOM_SEARCH_ON == it->itc_random_search)
	res = itc_random_leaf (it, *buf_ret, &leaf);
      else if (it->itc_search_mode == SM_READ)
	res = itc_page_split_search (it, *buf_ret, &leaf);
      else
	res = itc_page_insert_search (it, *buf_ret, &leaf);
    }
  else
    {
      res = itc_page_search (it, buf_ret, &leaf);
    }

  if (!it->itc_landed && !leaf)
    {
      itc_try_land (it, buf_ret);
      if (!it->itc_landed)
	{
	  *buf_ret = itc_reset (it);
	  goto start;
	}
      if (!(*buf_ret)->bd_is_write)
	GPF_T1 ("Buffer not on write access after cursor landed");
      if (it->itc_to_reset > RWG_NO_WAIT
	  && (res == DVC_MATCH_COMPLETE || res == DVC_NO_MATCH_COMPLETE))
	/* a rollback while landing could have caused a dirty read by accelerator */
	goto start;

      if (it->itc_search_mode == SM_INSERT)
	return res;
      /* A read cursor landed on a leaf */
      if (ISO_SERIALIZABLE == it->itc_isolation
	  && res == DVC_LESS)
	{
	  if (NO_WAIT != itc_serializable_land (it, buf_ret))
	    goto start;
	}
      if ((ISO_SERIALIZABLE == it->itc_isolation || ISO_COMMITTED == it->itc_isolation)
	  && (DVC_MATCH == res || DVC_MATCH_COMPLETE == res || DVC_NO_MATCH_COMPLETE == res))
	{
	  goto start; /* pass through itc_page_search to check for lock */
	}
      if (it->itc_search_mode == SM_READ)
	{
	  if (res == DVC_LESS)
	    {

	      itc_skip_entry (it, (*buf_ret)->bd_buffer);
	      if (it->itc_position)
		goto start;
	      res = DVC_INDEX_END;
	    }
	  if (res == DVC_MATCH)
	    /* recheck, maybe match not full if non-trailing part
	     * not an equal match */
	    goto start;

	  if (res == DVC_GREATER && it->itc_desc_order)
	    {
	      res = DVC_INDEX_END;
	    }
	}
      else
	{
	  /* SM_READ_EXACT */
	  if (res != DVC_MATCH && res != DVC_MATCH_COMPLETE
	      && res != DVC_NO_MATCH_COMPLETE)
	    return res;
	}
    }

search_switch:
  switch (res)
    {
    case DVC_INDEX_END:
      {
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
	ITC_IN_MAP (it);
	up = LONG_REF (((*buf_ret)->bd_buffer) + DP_PARENT);
	leaf_from = (*buf_ret)->bd_page;
	if (!up)
	  {
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
	itc_up_transit (it, buf_ret);
	/* We're in on the parent node. Where do we go now? */
	ITC_LEAVE_MAP (it);
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
	res = itc_page_search (it, buf_ret, &leaf);
	if (res == DVC_GREATER)
	  return DVC_INDEX_END;
	if (res == DVC_MATCH
	    || res == DVC_MATCH_COMPLETE
	    || res == DVC_NO_MATCH_COMPLETE)
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
	if (leaf)
	  {
	    /* Go down on the right edge. */
	      itc_down_transit (it, buf_ret, leaf);
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
	      itc_down_transit (it, buf_ret, leaf);
	    goto start;
	  }
	else
	  {
	    /* The key value matches. Check key id and other columns */
	    if (!IE_ISSET ((*buf_ret)->bd_buffer + it->itc_position, IEF_DELETE)
		&& itc_row_check (it, *buf_ret) == DVC_MATCH)
	      {
		it->itc_is_on_row = 1;
		if (it->itc_owns_page != it->itc_page
		    && ISO_REPEATABLE == it->itc_isolation)
		  {
		    int wait_rc = itc_set_lock_on_row (it, buf_ret);
		    if (wait_rc != NO_WAIT || !it->itc_is_on_row)
		      goto start;
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
	    else
	      {
		if (it->itc_search_mode == SM_READ_EXACT)
		  return DVC_LESS;
		if (it->itc_desc_order)
		  itc_prev_entry (it, *buf_ret);
		else
		  itc_skip_entry (it, (*buf_ret)->bd_buffer);
		goto start;
	      }
	  }
      }
    case DVC_MATCH_COMPLETE:
    case DVC_NO_MATCH_COMPLETE:
      {
	it->itc_is_on_row = 1;

	if (ISO_REPEATABLE == it->itc_isolation
	    || ISO_SERIALIZABLE == it->itc_isolation)
	  {
	    if (NO_WAIT != itc_set_lock_on_row (it, buf_ret))
	      goto start;
	  }
	if (!it->itc_is_on_row)
	  {
	    goto start;
	  }
	if (DVC_NO_MATCH_COMPLETE == res)
	  goto start;
	pos = it->itc_position;
	if (IE_ISSET ((*buf_ret)->bd_buffer + pos, IEF_DELETE))
	  goto start;

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
	return DVC_GREATER;
      }
    }
  return DVC_LESS;		/* never done */
}


int
itc_next (it_cursor_t * it, buffer_desc_t ** buf_ret)
{
  key_source_t * ks;
  if (it->itc_is_on_row)
    {
      it->itc_is_on_row = 0;
      if (it->itc_desc_order)
	itc_prev_entry (it, *buf_ret);
      else
	itc_skip_entry (it, (*buf_ret)->bd_buffer);
    }
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
      return rc;
    }
  else
    return (itc_search (it, buf_ret));
}


int
itc_page_search (it_cursor_t * it, buffer_desc_t ** buf_ret, dp_addr_t * leaf_ret)
{
  db_buf_t page = (*buf_ret)->bd_buffer;
  dp_addr_t leaf = 0;
  key_id_t key_id;
  search_spec_t *sp;
  int res = DVC_LESS;
  int pos;
  char txn_clear = PS_LOCKS;

  if (ISO_UNCOMMITTED == it->itc_isolation)
    txn_clear = PS_OWNED;
  else if (ISO_COMMITTED == it->itc_isolation)
    {
      if (!it->itc_pl)
	txn_clear = PS_OWNED;
    }
  else if (ISO_REPEATABLE == it->itc_isolation)
    {
      if (!it->itc_pl)
	{
	  txn_clear = PS_NO_LOCKS;
	}
    }

  if (it->itc_wst)
    return (itc_text_search (it, buf_ret, leaf_ret));

  while (1)
    {
      int first_open_passed = 0;

      if (!it->itc_position)
	{
	  *leaf_ret = 0;
	  return DVC_INDEX_END;
	}
      if (it->itc_position >= PAGE_SZ)
	GPF_T;			/* Link over page end */

      if (PS_LOCKS == txn_clear)
	{
	  if (it->itc_owns_page != it->itc_page)
	    {
	      if (it->itc_isolation == ISO_SERIALIZABLE
		  || ITC_MAYBE_LOCK (itc, it->itc_position))
		{
		  for (;;)
		    {
		      int wrc = ITC_IS_LTRX (it) ?
			  itc_landed_lock_check (it, buf_ret) : NO_WAIT;
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
	  if (!it->itc_row_key || it->itc_row_key->key_id != key_id)
	    it->itc_row_key = sch_id_to_key (wi_inst.wi_schema, key_id);
	}

      for (sp = it->itc_specs;; sp = sp->sp_next)
	{
	  if (!sp)
	    break;


	  DV_COMPARE_SPEC_W_NULL (res, sp, it);

	  if (res == DVC_MATCH)
	    {
	      if (sp->sp_min_op != CMP_EQ)
		first_open_passed = 1;
	      continue;
	    }
	  if (res == DVC_LESS)
	    {
	      /* The thing's too small. We want larger, on with the leaf */
	      if (ITC_NULL_CK(it, sp->sp_cl))
		{
		  if (!leaf)
		    goto next_row;  /* skip a null on the row */
		  first_open_passed = 1;
		  break;
		}
	      break;
	    }
	  if (res == DVC_GREATER)
	    {
	      if (first_open_passed)
		{
		  /* Check next row. There's a prior '>' condition that passed
		     There may be matches further of with another value of
		     the prior key part */
		  break;
		}
	      else
		{
		  *leaf_ret = 0;
		  it->itc_position = pos;
		  return DVC_GREATER;
		}
	    }
	}
      if (IE_ISSET (page + pos, IEF_DELETE))
	goto next_row;
      if (!sp ||
	  (leaf && first_open_passed))
	{
	  /* The loop has exhausted all search specs.
	     This means it's a match. */
	  *leaf_ret = leaf;
	  if (!leaf && !sp)
	    {
	      if (DVC_MATCH == itc_row_check (it, *buf_ret))
		{
		  if (it->itc_ks && it->itc_ks->ks_is_last
		      && (PS_OWNED == txn_clear
			  || ISO_SERIALIZABLE == it->itc_isolation))
		    {
		      /* A RR cursor that does not own the page must return to itc_search for the locks. */
		      goto next_row;
		    }
		  return DVC_MATCH_COMPLETE;
		}
	      else
		goto next_row;
	    }
	  else
	    return DVC_MATCH;
	}
      if (res == DVC_LESS && !leaf && it->itc_desc_order && !first_open_passed)
	{
	  return DVC_GREATER;	/* end of search */
	}
      if (res == DVC_LESS && leaf && it->itc_desc_order)
	{
	  *leaf_ret = leaf;
	  return DVC_MATCH;
	  /* if there's a lesser leaf ptr, go down if desc order.
	   * The end is when you hit a lesser leaf */
	}
      /* Next entry on page */

    next_row:

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
  search_spec_t *spec = it->itc_specs;
  key_id_t key_id = SHORT_REF (page + pos + IE_KEY_ID);
  if (KI_LEFT_DUMMY == key_id)
    {
      it->itc_row_key_id = 0;
      return DVC_LESS;
    }
  ITC_SET_ROW_KEY_ID (it, key_id);
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
  return DVC_MATCH;
}


int
itc_page_split_search (it_cursor_t * it, buffer_desc_t * buf,
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
	case DVC_MATCH_COMPLETE:	/* index AND scalar match */
	case DVC_NO_MATCH_COMPLETE:	/* index match, scalar fail */
	  it->itc_position = map->pm_entries[guess];
	  *leaf_ret = 0;
	  return res;

	case DVC_GREATER:
	  below = guess;
	  break;
	}
    }
}

int
pg_insert_key_compare (buffer_desc_t * buf, int pos, it_cursor_t * it)
{
  db_buf_t page = buf->bd_buffer;
  search_spec_t *spec = it->itc_specs;
  key_id_t key_id = SHORT_REF (page + pos + IE_KEY_ID);
  it->itc_row_data = page + pos + IE_FIRST_KEY + (!key_id ? 4 : 0);
  if (KI_LEFT_DUMMY == key_id)
    {
      it->itc_row_key_id = 0;
      return DVC_LESS;
    }
  ITC_SET_ROW_KEY_ID (it, key_id);
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
  return DVC_MATCH;
}


int
itc_page_insert_search (it_cursor_t * it, buffer_desc_t * buf,
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
	      at_or_above_res = pg_insert_key_compare (buf,
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
		it->itc_map_pos = 0;
		*leaf_ret = 0;
		return DVC_GREATER;
	      }
	    }
	}
      /* OK, we have an interval to search */
      guess = at_or_above + ((below - at_or_above) / 2);
      res = pg_insert_key_compare (buf, map->pm_entries[guess],
	  it);
      switch (res)
	{
	case DVC_LESS:
	  at_or_above = guess;
	  at_or_above_res = res;
	  break;
	case DVC_MATCH:	/* row found, dependent not checked */
	  it->itc_position = map->pm_entries[guess];
	  it->itc_map_pos = guess;
	  *leaf_ret = it->itc_row_key_id ? 0 : LONG_REF (page + map->pm_entries[guess] + IE_LEAF);
	  return res;
	case DVC_MATCH_COMPLETE:	/* index AND scalar match */
	case DVC_NO_MATCH_COMPLETE:	/* index match, scalar fail */
	  it->itc_position = map->pm_entries[guess];
	  *leaf_ret = 0;
	  return res;

	case DVC_GREATER:
	  below = guess;
	  break;
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
  it->itc_space = it->itc_tree->it_commit_space;
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
  it->itc_space = it->itc_tree->it_commit_space;
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
  itc->itc_space = it->it_commit_space;
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
	      ITC_LEAVE_MAP (itc);
	      pl = plh_copy ((placeholder_t *) itc);
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
      ITC_IN_MAP (itc);
      page_leave_inner (*buf_ret);
      *buf_ret = itc_set_by_placeholder (itc, pl);
      ITC_LEAVE_MAP (itc);
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

  ITC_IN_MAP (itc);
  if (!iq_is_on ())
    {
      ITC_LEAVE_MAP (itc);
      goto fin;
    }
  for (inx = 0; inx < ra->ra_fill; inx++)
    {
      buffer_desc_t decoy;
      dp_addr_t phys;
      index_space_t * bisp;
      buffer_desc_t * btmp;
      ITC_IN_MAP (itc);
      if (!DBS_PAGE_IN_RANGE (itc->itc_tree->it_storage, ra->ra_dp[inx]) 
	  ||dbs_is_free_page (itc->itc_tree->it_storage, ra->ra_dp[inx]) || 0 == ra->ra_dp[inx])
	{
	  log_error ("*** read-ahead of a free or out of range page dp L=%ld",
	       ra->ra_dp[inx]);
	  continue;
	}
      btmp = isp_locate_page (itc->itc_space, ra->ra_dp[inx],
			      &bisp, &phys);
      if (!btmp)
	{
	  memset (&decoy, 0, sizeof (decoy));
	  decoy.bd_being_read = 1;
	  sethash (DP_ADDR2VOID (ra->ra_dp[inx]), itc->itc_space->isp_dp_to_buf, (void*) &decoy);
	  ITC_LEAVE_MAP (itc);
	  btmp = bp_get_buffer (NULL, BP_BUF_IF_AVAIL);
	  ITC_IN_MAP (itc);
	  remhash (DP_ADDR2VOID (ra->ra_dp[inx]), itc->itc_space->isp_dp_to_buf);
	  if (!btmp)
	    {
	      buf_release_read_waits (&decoy, RWG_WAIT_DECOY);
	      break;
	    }
	  btmp->bd_waiting_read = decoy.bd_waiting_read;
	  if (decoy.bd_waiting_read)
	    TC (tc_read_wait_while_ra_finding_buf);
	  ra->ra_bufs[ra->ra_bfill++] = btmp;

	  if (!ra->ra_dp[inx])
	    GPF_T1 ("Scheduling 0 for read ahead.\n");
	  isp_set_buffer (bisp, ra->ra_dp[inx], phys, btmp);
	  btmp->bd_being_read = 1;
	  btmp->bd_readers = 0;
	  BD_SET_IS_WRITE (btmp, 0);
	  btmp->bd_write_waiting = NULL;
	  itc->itc_n_reads++;
	  ITC_MARK_READ (itc);
	  DBG_PT_PRINTF ((" SCH RA L=%d P=%d B=%p \n", btmp->bd_page, btmp->bd_physical_page, btmp));
	}
      else
	{
	  if (btmp->bd_pool)
	    BUF_TOUCH (btmp); /* make sure won't get replaced if already in */
	  /* check that btmp has bd_pool, because this is nil if the btmp is a decoy in read-ahead */
	}
    }
  ITC_LEAVE_MAP (itc);
  if (ra->ra_bfill)
    {
      ra_count++;
      ra_pages += ra->ra_bfill;
      if (ra->ra_nsiblings > 1)
	dbg_printf (("RA %d sibling %d pages %d leaves\n", ra->ra_nsiblings, ra->ra_bfill, ra->ra_fill));
      iq_schedule (ra->ra_bufs, ra->ra_bfill);
    }
  ITC_LEAVE_MAP (itc);
fin:
  if (ra)
    dk_free_box((box_t) ra);
}


void
itc_read_ahead (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  itc_read_ahead_blob (itc, itc_read_ahead1 (itc, buf_ret));
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



typedef struct col_stat_s 
{
  id_hash_t *	cs_distinct;
  long		cs_len;
  long		cs_n_values;
} col_stat_t;


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
      id_hash_iterator (&hit, cs->cs_distinct);
      while (hit_next (&hit, (caddr_t*) &data, (caddr_t*) &count))
	{
	  dk_free_tree (*data);
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
	    }
	  else 
	    {
	      col->col_n_distinct = 1;
	      col->col_avg_len = 0; /* no data, use declared prec instead */
	    }
	}
      id_hash_free (cs->cs_distinct);
      dk_free ((caddr_t) cs, sizeof (col_stat_t));
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
itc_matches_on_page (it_cursor_t * itc, buffer_desc_t * buf, int * leaf_ctr_ret, dp_addr_t * alt_leaf_ret)
{
  db_buf_t page = buf->bd_buffer;
  int have_left_leaf = 0;
  int pos = itc->itc_position; /* itc is at leftost match. Nothing at left of the itc */
  int ctr = 0, leaf_ctr = 0;
  while (pos)
		{
      int res = DVC_MATCH;
      search_spec_t * sp = itc->itc_specs;
      key_id_t r_k_id = SHORT_REF (page + pos + IE_KEY_ID);
      itc->itc_row_data = page + pos + (r_k_id ? IE_FIRST_KEY : IE_LP_FIRST_KEY);
      if (KI_LEFT_DUMMY == r_k_id)
	{
	  if (LONG_REF (page + pos + IE_LEAF))
	    {
	      have_left_leaf = 1;
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
		ctr++;
	      else 
		{
		  if (have_left_leaf)
		    {
		      /* prefer giving the next to leftmost instead of leftmost leaf if leftmost is left dummy.
		       * The leftmost branch can be empty because the leaf with the left dummy never can get deleted */
		      *alt_leaf_ret = LONG_REF (page + pos + IE_LEAF);
		      have_left_leaf = 0;
    }
		  leaf_ctr++;
		}
	    }
	}
      pos = IE_NEXT (page + pos);
    }
  *leaf_ctr_ret = leaf_ctr;
  return ctr;
}

int64
itc_sample (it_cursor_t * it, buffer_desc_t ** buf_ret)
{
  dp_addr_t leaf, rnd_leaf;
  int res;
  int ctr  = 0, leaf_ctr = 0;
  int64 leaf_estimate = 0;

  it->itc_search_mode = SM_READ;
 start:
  if (!(*buf_ret)->bd_readers && !(*buf_ret)->bd_is_write)
    GPF_T1 ("buffer not wired occupied in itc_search");
  leaf = 0;
  it->itc_is_on_row = 0;

  ITC_LEAVE_MAP (it);
  if (!(*buf_ret)->bd_content_map)
    {
      log_error ("Suspect index page dp=%d key=%s, probably blob ref'd as index node.", (*buf_ret)->bd_page, it->itc_insert_key->key_name);
      return 0;
    }
  rnd_leaf = 0;
  if (RANDOM_SEARCH_ON == it->itc_random_search)
    res = itc_random_leaf (it, *buf_ret, &rnd_leaf);
  else 
    res = itc_page_split_search (it, *buf_ret, &leaf);
  if (it->itc_st.cols)
    itc_page_col_stat (it, *buf_ret);
  ctr = itc_matches_on_page (it, *buf_ret, &leaf_ctr, &leaf);
  if (leaf_estimate)
    leaf_estimate = leaf_estimate * (*buf_ret)->bd_content_map->pm_count + leaf_ctr;
  else if (leaf_ctr > 1)
    leaf_estimate = leaf_ctr - 1;
  if (rnd_leaf)
    leaf = rnd_leaf;
  switch (res)
	{
    case DVC_LESS:
      {
	if (leaf)
	  {
	    /* Go down on the right edge. */
	    itc_down_transit (it, buf_ret, leaf);
	    goto start;
	  }

	break;
      }
    case DVC_MATCH:
      {
	if (leaf)
	    {
	      itc_down_transit (it, buf_ret, leaf);
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
  return ctr + leaf_estimate;
}




unsigned int64
key_count_estimate  (dbe_key_t * key, int n_samples, int upd_col_stats)
{
  int64 res = 0;
  int n;
  buffer_desc_t * buf;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  ITC_INIT (itc, key->key_fragments[0]->kf_it, NULL);
  itc_from (itc, key);
  itc->itc_random_search = RANDOM_SEARCH_ON;
  if (upd_col_stats)
    itc->itc_st.cols = hash_table_allocate (23);
  for (n = 0; n < n_samples; n++)
    {
      buf = itc_reset (itc);
      res += itc_sample (itc, &buf);
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


caddr_t 
key_iri_from_name (caddr_t name)
{
  int res;
  caddr_t iri = NULL;
  dbe_table_t * tb = sch_name_to_table (wi_inst.wi_schema, "DB.DBA.RDF_URL");
  dbe_key_t * key = tb ? tb_name_to_key (tb, "RU_QNAME", 1) : NULL;
  dbe_column_t * iri_col = key && key->key_parts && key->key_parts->next ? key->key_parts->next->data : NULL;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  buffer_desc_t * buf;
  search_spec_t sp;
  if (!iri_col)
    return NULL;
  ITC_INIT (itc, key->key_fragments[0]->kf_it, NULL);
  itc_from (itc, key);
  ITC_SEARCH_PARAM (itc, name);
  itc->itc_isolation = ISO_UNCOMMITTED;
  itc->itc_specs = &sp;
  memset (&sp, 0, sizeof (sp));
  sp.sp_min_op = CMP_EQ;
  sp.sp_cl = *key_find_cl (key, ((dbe_column_t *) key->key_parts->data)->col_id);
  ITC_FAIL (itc)
    {
      buf = itc_reset (itc);
      res = itc_search (itc, &buf);
      if (DVC_MATCH == res)
	{
	  iri = itc_box_column (itc, buf->bd_buffer, iri_col->col_id, NULL);
	}
      itc_page_leave (itc, buf);
    }
	ITC_FAILED
      {
	return NULL;
      }
  END_FAIL (itc);
  itc_free (itc);
  return iri;
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
  itc->itc_specs = &sp;
  memset (&sp, 0, sizeof (sp));
  sp.sp_min_op = CMP_EQ;
  sp.sp_cl = *key_find_cl (key, ((dbe_column_t *) key->key_parts->data)->col_id);
  ITC_FAIL (itc)
    {
      buf = itc_reset (itc);
      res = itc_search (itc, &buf);
      if (DVC_MATCH == res)
	{
	  id = (int) itc_box_column (itc, buf->bd_buffer, twobyte_col->col_id, NULL);
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


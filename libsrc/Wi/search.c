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
 *  Copyright (C) 1998-2019 OpenLink Software
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
#include "sqlfn.h"
#include "arith.h"
#include "multibyte.h"
#include "srvmultibyte.h"
#include "xmlnode.h"
#include "xmltree.h"
#include "sqlbif.h"
#include "srvstat.h"
#include "geo.h"


signed char  db_buf_const_length[256];
dtp_t dtp_canonical[256];
signed char  db_ce_const_length[256];
dtp_t dv_ce_dtp[256];
unsigned char byte_logcount[256];
unsigned int32 byte_bits[256];


int  itc_random_leaf (it_cursor_t * itc, buffer_desc_t *buf, dp_addr_t * leaf_ret);
int itc_down_rnd_check (it_cursor_t * itc, dp_addr_t leaf);
int itc_up_rnd_check (it_cursor_t * itc, buffer_desc_t ** buf_ret);

numeric_t num_int64_max;
numeric_t num_int64_min;


void
const_length_init (void)
{
  int inx;
  db_buf_const_length[DV_SHORT_INT] = 2;
  db_buf_const_length[DV_LONG_INT] = 5;
  db_buf_const_length[DV_INT64] = 9;
  db_buf_const_length[DV_DB_NULL] = 1;
  db_buf_const_length[DV_SINGLE_FLOAT] = 5;
  db_buf_const_length[DV_DOUBLE_FLOAT] = 9;
  db_buf_const_length[DV_SHORT_STRING_SERIAL] = -1;
  db_buf_const_length[DV_BIN] = -1;
  db_buf_const_length[DV_DATETIME] = DT_LENGTH + 1;
  db_buf_const_length[DV_NUMERIC] = -1;
  db_buf_const_length[DV_WIDE] = -1;
  db_buf_const_length[DV_COMPOSITE] = -1;
  db_buf_const_length[DV_BLOB] = DV_BLOB_LEN;
  db_buf_const_length[DV_COL_BLOB_SERIAL] = DV_BLOB_LEN;
  db_buf_const_length[DV_BLOB_WIDE] = DV_BLOB_LEN;
  db_buf_const_length[DV_IRI_ID] = 5;
  db_buf_const_length[DV_IRI_ID_8] = 9;
  db_buf_const_length[DV_RDF_ID] = 5;
  db_buf_const_length[DV_RDF_ID_8] = 9;


  num_int64_max = numeric_allocate ();
  num_int64_min = numeric_allocate ();
  numeric_from_int64 (num_int64_max, INT64_MAX);
  numeric_from_int64 (num_int64_min, INT64_MIN);
  for (inx = 0; inx < 256; inx++)
    dtp_canonical[inx] = inx;
  dtp_canonical[DV_IRI_ID_8] = DV_IRI_ID;
  dtp_canonical[DV_SHORT_INT] = DV_LONG_INT;
  dtp_canonical[DV_INT64] = DV_LONG_INT;
  dtp_canonical[DV_SHORT_STRING_SERIAL] = DV_STRING;
  dtp_canonical[DV_C_STRING] = DV_STRING;
  dtp_canonical[DV_WIDE] = DV_LONG_WIDE;
  dtp_canonical[DV_TIMESTAMP] = DV_DATETIME;
  dtp_canonical[DV_DATE] = DV_DATETIME;
  dtp_canonical[DV_TIME] = DV_DATETIME;
  dtp_canonical[DV_RDF_ID_8] = DV_RDF_ID;
  memcpy (db_ce_const_length, db_buf_const_length, 256);
  for (inx = 0; inx <= MAX_1_BYTE_CE_INX ; inx++)
    db_ce_const_length[inx] = 2;
  for (inx = MAX_1_BYTE_CE_INX  + 1; inx < DV_ANY_FIRST; inx++)
    db_ce_const_length[inx] = 3;
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
    case DV_SYMBOL:
      *head_ret = 5;
      *len_ret = LONG_REF_NA ((buf + 1));
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
    case DV_IRI_ID:
    case DV_RDF_ID:
      *head_ret = 1;
      *len_ret = 4;
      break;

    case DV_DOUBLE_FLOAT:
    case DV_INT64:
    case DV_IRI_ID_8:
    case DV_RDF_ID_8:
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
	  *len_ret = LONG_REF_NA ((buf + 2)) * 4;
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
	  *len_ret = LONG_REF_NA ((buf + 2)) * 8;
	}
      break;
    case DV_ARRAY_OF_POINTER:
      {
	int n, inx;
	db_buf_t ptr;
	if (DV_SHORT_INT == buf[1])
	  {
	    *head_ret = 3;
	    n =  (buf[2]);
	  }
	else
	  {
	    *head_ret = 6;
	    n = LONG_REF_NA ((buf + 2));
	}
	ptr = buf + *head_ret;
	for (inx = 0; inx < n; inx++)
	  {
	    long l, hl;
	    db_buf_length (ptr, &hl, &l);
	    ptr += l +hl;
	  }
	*len_ret = (ptr - buf) - *head_ret;
	break;
      }
    case DV_DATETIME:
      *head_ret = 1;
      *len_ret = DT_LENGTH;
      break;
    case DV_RDF:
      *head_ret = 1;
      *len_ret = rbs_length (buf) - 1;
      break;
    case DV_GEO:
      dv_geo_length (buf, head_ret, len_ret);
      break;
    case DV_BOX_FLAGS:
      db_buf_length (buf + 5, head_ret, len_ret);
      head_ret[0] += 5;
      break;

    case DV_BLOB: case DV_BLOB_BIN: case DV_BLOB_WIDE: case DV_COL_BLOB_SERIAL:
      *head_ret = 1;
      *len_ret = DV_BLOB_LEN - 1;
      break;
    case DV_BLOB_HANDLE: case DV_BLOB_WIDE_HANDLE:
    case DV_OBJECT:
    case DV_XML_ENTITY:
      *len_ret = xte_serialization_len (buf) - 1;
      *head_ret = 1;
      return;
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
  char approx = SERIAL_LENGTH_APPROX == dtp;
  if (dtp <= SERIAL_LENGTH_APPROX)
    dtp = DV_TYPE_OF (box);
  switch (dtp)
    {
#ifdef SIGNAL_DEBUG
    case DV_ERROR_REPORT:
#endif
    case DV_ARRAY_OF_POINTER:
    case DV_LIST_OF_POINTER:
    case DV_ARRAY_OF_XQVAL:
    case DV_XTREE_HEAD:
    case DV_XTREE_NODE:
      {
        int inx, elts = BOX_ELEMENTS (box);
        int len = elts < 128 ? 3 : 6;
        DO_BOX (caddr_t, v, inx, (caddr_t *)box)
          {
            len += box_serial_length (v, 0);
          }
        END_DO_BOX;
        return len;
      }
    case DV_ARRAY_OF_LONG: /* _ROW */
      {
        int elts = box_length (box) / sizeof (ptrlong);
        return (elts < 128 ? 3 : 6) + 4 * elts;
      }
    case DV_ARRAY_OF_LONG_PACKED: /* _ROW */
      {
        ptrlong *valptr = (ptrlong *) box;
        int i, elts = box_length (box) / sizeof (ptrlong);
        int len = elts < 128 ? 3 : 6;
        for (i = elts; i--; /* no step */)
          {
            boxint n = valptr[i];
            len += (((n > -128) && (n < 128)) ? 2 : ((n >= (int64) INT32_MIN && n <= (int64) INT32_MAX) ? 5 : 9));
          }
        return len;
      }
    case DV_ARRAY_OF_DOUBLE: /* _ROW */
      {
        int elts = BOX_ELEMENTS (box);
        return (elts < 128 ? 3 : 6) + 8 * elts;
      }
    case DV_ARRAY_OF_FLOAT: /* _ROW */
      {
        int elts = BOX_ELEMENTS (box);
        return (elts < 128 ? 3 : 6) + 4 * elts;
      }
    case DV_LONG_INT:
    case DV_SHORT_INT:
      {
        boxint n = IS_BOX_POINTER (box) ? *((ptrlong *) box) : (boxint)((ptrlong)box); /* Is it ((ptrlong *) box) or ((boxint *) box) ??? */
        if ((n > -128) && (n < 128))
          return 2;
        else if (n >= (int64) INT32_MIN && n <= (int64) INT32_MAX)
          return 5;
        else
          return 9;
      }
    case DV_STRING:
    case DV_C_STRING:
      {
        int len = box_length (box);
        return (len > 256 ? len + 4 : len + 1); /* count the trailing 0 incl. in the box length */
      }
    case DV_UNAME:
      { /* This is true only for internal Virtuoso serialization! */
        int len = box_length (box);
        return (len > 256 ? len + 4 : len + 1); /* count the trailing 0 incl. in the box length */
      }
    case DV_SINGLE_FLOAT:
      return 5;
    case DV_DOUBLE_FLOAT:
      return 9;
    case DV_DB_NULL:
      return 1;
    case DV_SHORT_CONT_STRING:
    case DV_LONG_CONT_STRING:
      return box_length (box);
    case DV_IRI_ID:
      {
	iri_id_t iid = unbox_iri_id (box);
	return  (iid <= 0xffffffff) ? 5 : 9;
      }
    case DV_NUMERIC:
      return numeric_dv_len ((numeric_t)box);
    case DV_DATETIME:
      return 1 + DT_LENGTH;
    case DV_RDF:
      return rb_serial_length (box);
    case DV_GEO:
      {
        geo_t *g = (geo_t *)box;
        return geo_serial_length (g);
      }
    case DV_WIDE:
      {
        const wchar_t *wstr = (const wchar_t *)box;
        const wchar_t *wide_work = wstr;
        size_t utf8_len, wide_len = box_length (box) / sizeof (wchar_t) - 1;
        virt_mbstate_t state;
        unsigned char mbs[VIRT_MB_CUR_MAX];
        wide_work = wstr;
        memset (&state, 0, sizeof (virt_mbstate_t));
        utf8_len = virt_wcsnrtombs (NULL, &wide_work, wide_len, 0, &state);
        if (((long) utf8_len) < 0)
          GPF_T1("non consistent wide char to multi-byte translation of a buffer");
        return ((utf8_len < 256) ? 2 : 5) + utf8_len;
      }
    default:
      if (approx)
        return box_length (box);
      log_error ("box_serial_len called with dtp %d", (uint32)dtp);
      GPF_T1 ("box_serial_length not supported for data type");
    }
  return 0; /* not reached */
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
  if (!key || !itc->itc_key_spec.ksp_spec_array)
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


#ifdef MALLOC_DEBUG
it_cursor_t *
dbg_itc_create (const char *file, int line, void * isp, lock_trx_t * trx)
{
  it_cursor_t * itc = (it_cursor_t*) DBG_NAME (dk_alloc_box) (DBG_ARGS sizeof (it_cursor_t), DV_ITC);
  ITC_INIT (itc, isp, trx);
  itc->itc_type = ITC_CURSOR;
  itc->itc_is_allocated = 1;
  return itc;
}
#else
it_cursor_t *
itc_create (void * isp, lock_trx_t * trx)
{
  it_cursor_t * itc = (it_cursor_t*)dk_alloc_box (sizeof (it_cursor_t), DV_ITC);
  ITC_INIT (itc, isp, trx);
  itc->itc_type = ITC_CURSOR;
  itc->itc_is_allocated = 1;
  return itc;
}
#endif

void itc_col_stat_free (it_cursor_t * itc, int upd_col, float est);

void
itc_clear (it_cursor_t * it)
{
  itc_free_owned_params (it);
  if (it->itc_local_key_spec)
    {
      key_free_trail_specs (it->itc_key_spec.ksp_spec_array);
      it->itc_local_key_spec = 0;
      it->itc_key_spec.ksp_spec_array = NULL;
    }
  if (RSP_CHANGED == it->itc_hash_row_spec)
    {
      key_free_trail_specs (it->itc_row_specs);
      it->itc_hash_row_spec = 0;
      it->itc_row_specs = NULL;
    }
  if (it->itc_siblings)
    {
      itc_free_box (it, (caddr_t)it->itc_siblings);
      it->itc_siblings = NULL;
    }
  if (it->itc_is_col)
    itc_col_free (it);
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
  if (it->itc_boundary)
    plh_free (it->itc_boundary);
  if (it->itc_is_registered)
    {
      itc_unregister (it);
    }
#ifndef O12
  if (it->itc_extension)
    {
      dk_free_box (it->itc_extension);
      it->itc_extension = NULL;
    }
#endif
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
  if (itc->itc_is_col && itc->itc_anify_fill)
    {
      for (inx = 0; inx < itc->itc_anify_fill; inx += 2)
	dk_free_box (itc->itc_anify_cache[inx + 1]);
      itc->itc_anify_fill = 0;
      dk_free_box (itc->itc_anify_cache);
      itc->itc_anify_cache = NULL;
    }
}


void
itc_free (it_cursor_t * it)
{
  if (it->itc_type != ITC_PLACEHOLDER && it->itc_is_geo_registered && it->itc_tree && it->itc_tree->it_key && it->itc_tree->it_key->key_is_geo)
    itc_geo_unregister (it);
  if (ITC_PLACEHOLDER == it->itc_type)
    {
      plh_free ((placeholder_t *)it);
      return;
    }
  itc_clear (it);
  if (it->itc_is_allocated)
    {
      box_tag_modify (it, DV_CUSTOM);
      dk_free_box ((caddr_t) it);
    }
}


placeholder_t *
plh_allocate ()
{
  NEW_PLH(v);
  return v;
}


void
plh_free (placeholder_t * pl)
{
  itc_unregister ((it_cursor_t *) pl);
  if (pl->itc_type != ITC_PLACEHOLDER || DV_ITC != DV_TYPE_OF (pl)) GPF_T1 ("plh_free applied to non-placeholder");
  box_tag_modify (pl, DV_CUSTOM);
  dk_free_box ((caddr_t) pl);
}

placeholder_t *
plh_copy (placeholder_t * pl)
{
  return NULL;
#if 0
 NEW_PLH (new_pl);
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
  NEW_PLH (new_pl);
  memcpy (new_pl, pl, ITC_PLACEHOLDER_BYTES);
  new_pl->itc_type = ITC_PLACEHOLDER;
  new_pl->itc_is_registered = 0;
  itc_register_nc ((it_cursor_t *) new_pl, buf);
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
  itc->itc_map_pos = pl->itc_map_pos;
  /* Set now when in, if it moved while waiting. */
  ITC_LEAVE_MAPS (itc);
  itc->itc_owns_page = 0;
  return buf;
}


int
dv_composite_cmp (db_buf_t dv1, db_buf_t dv2, collation_t * coll, int64 offset)
{
  db_buf_t tmp[256];
  db_buf_t e1;
  db_buf_t e2;
  int rc, len;
  if (offset)
    {
      uint32 last;
      int l1 = dv1[1];
      memcpy_16 (tmp, dv1, l1);
      dv1 = (db_buf_t)tmp;
      last = LONG_REF_NA (dv1 + l1 - 4);
      LONG_SET_NA (dv1 + l1 - 4, last + offset);
    }
  e1 = dv1 + dv1[1] + 2;
  e2 = dv2 + dv2[1] + 2;
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
      rc = dv_compare (dv1, dv2, coll, 0);
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
void
dv_num_offset (db_buf_t dv, int64 offset, db_buf_t tmp, int sz)
{
  /* with a dv compare with a long offset, the int has the semantic of 64 bit addition, the others have an unsigned 43 bit inc of the last 4 bytes */
  int l;
  dtp_t dtp;
  int64 i = dv_int (dv, &dtp);
  if (DV_LONG_INT == dtp)
    {
      i += offset;
      tmp[0] = DV_INT64;
      INT64_SET_NA (&tmp[1], i);
    }
  else
    {
      DB_BUF_TLEN (l, dv[0], dv);
      if (l > sz)
	l = sz;
      memcpy (tmp, dv, l);
      i = LONG_REF_NA (&tmp[0] + l -4);
      i += offset;
      LONG_SET_NA (&tmp[0] + l - 4, i);
    }
    }


#define offset_t unsigned short
#include "dvcmp.c"
#undef offset_t
#define offset_t int64
#define dv_compare dv_compare_so
#define LONG_OFF
#include "dvcmp.c"
#undef dv_compare
#undef offset_t


int
itc_like_any_check (it_cursor_t * itc, db_buf_t dv1, db_buf_t dv3, row_size_t len1, row_size_t len3, unsigned short offset, db_buf_t pattern)
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
itc_like_compare (it_cursor_t * itc, buffer_desc_t * buf, caddr_t pattern, search_spec_t * spec)
	  {
  char temp[MAX_ROW_BYTES];
  int res, st = LIKE_ARG_CHAR, pt = LIKE_ARG_CHAR;
  dtp_t dtp2 = DV_TYPE_OF (pattern), dtp1;
  row_size_t len1, len3;
  unsigned short offset;
  db_buf_t dv1, dv3;
  collation_t *collation = spec->sp_collation;
  dbe_col_loc_t * cl = &spec->sp_cl;
  if (dtp_is_fixed (cl->cl_sqt.sqt_dtp)) /* if by chance numeric column then no match */
    return DVC_LESS;
  ROW_STR_COL (itc->itc_insert_key, buf, itc->itc_row_data, cl, dv1, len1, dv3, len3, offset);
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
    return itc_like_any_check (itc, dv1, dv3, len1, len3, offset, (db_buf_t)pattern);

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
  if (len1 + len3 >= MAX_ROW_BYTES)
    GPF_T1 ("string too long in <row> like <pattern>");
  memcpy (temp, dv1, len1);
  if (len3)
  memcpy (&temp[len1], dv3, len3);
  temp[len1 + len3 - 1] += offset;
  temp[len1 + len3] = 0;
  res = cmp_like (temp, pattern, collation, spec->sp_like_escape, st, pt);
  return res;
}


int
ce_like_filter (col_pos_t * cpo, int row, dtp_t flags, db_buf_t val, int len, int64 offset, int rl)
{
  char temp[MAX_ROW_BYTES];
  it_cursor_t * itc = cpo->cpo_itc;
  search_spec_t * spec = cpo->cpo_min_spec;
  caddr_t pattern = itc->itc_search_params[spec->sp_min];
  int res, st = LIKE_ARG_CHAR, pt = LIKE_ARG_CHAR;
  dtp_t dtp2 = DV_TYPE_OF (pattern), dtp1;
  row_size_t len1 = len, len3 = 0;
  db_buf_t dv1 = val, dv3 = NULL;
  collation_t *collation = spec->sp_collation;
  uint32 last;
  dtp1 = spec->sp_cl.cl_sqt.sqt_col_dtp;
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
    return itc_like_any_check (cpo->cpo_itc, dv1, dv3, len1, len3, offset, (db_buf_t)pattern);

  if (dtp2 != DV_SHORT_STRING && dtp2 != DV_LONG_STRING && dtp2 != DV_WIDE && dtp2 != DV_LONG_WIDE )
    return DVC_LESS;
  if (CET_CHARS == (flags & CE_DTP_MASK))
    dv1 += len1 > 127 ? 2 : 1;
  else if (CET_ANY == (flags & CE_DTP_MASK))
    {
      if (DV_SHORT_STRING_SERIAL == dv1[0])
	{
	  dv1 += 2;
	  len1 -= 2;
	}
      else if (DV_STRING == dv1[0])
	{
	  dv1 += 5;
	  len1 -= 5;
	}
      else
	return DVC_LESS;
    }
  else
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
  if (len1 + len3 >= MAX_ROW_BYTES)
    GPF_T1 ("string too long in <row> like <pattern>");
  memcpy_16 (temp, dv1, len1);
  if (len3)
    memcpy_16 (&temp[len1], dv3, len3);
  if (offset)
    {
      last = LONG_REF_NA (&temp[len1 + len3 - 4]);
      last += offset;
      LONG_SET_NA (&temp[len1 + len3 - 4], last);
    }
  temp[len1 + len3] = 0;
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
itc_compare_spec (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, search_spec_t * spec)
{
  int op = spec->sp_min_op;
  if (op != CMP_NONE)
    {
      int res;
      if (op == CMP_LIKE)
	{
	  return (itc_like_compare (itc, buf, itc->itc_search_params[spec->sp_min], spec));
	}
      res = page_col_cmp_1 (buf, itc->itc_row_data, cl, itc->itc_search_params[spec->sp_min]);
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
      res = page_col_cmp_1 (buf, itc->itc_row_data, cl, itc->itc_search_params[spec->sp_max]);
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
leaf_pointer (db_buf_t row, dbe_key_t * key)
{
  key_ver_t kv = IE_KEY_VERSION (row);
  if (KV_LEFT_DUMMY == kv)
    return LONG_REF (row + LD_LEAF);
  if (kv)
    return 0;
  return LONG_REF (row + key->key_key_leaf[IE_ROW_VERSION (row)]);
}


int
page_find_leaf (buffer_desc_t * buf, dp_addr_t lf)
{
  page_map_t * pm = buf->bd_content_map;
  dbe_key_t * key = buf->bd_tree->it_key;
  int inx, fill = pm->pm_count;
  db_buf_t page = buf->bd_buffer;
  /* position of entry whose leaf pointer == lf. -1 if none. */
  for (inx = 0; inx < fill; inx++)
    {
      db_buf_t row = page + pm->pm_entries[inx];
      key_ver_t kv = IE_KEY_VERSION (row);
      if (KV_LEAF_PTR == kv)
	{
	  row_ver_t rv = IE_ROW_VERSION (row);
	  if (lf == LONG_REF (row + key->key_key_leaf[rv]))
	    return inx;
	}
      if (KV_LEFT_DUMMY == kv)
	{
	  if (lf == LONG_REF (row + LD_LEAF))
	    return inx;
	}
    }
  return ITC_AT_END;
}


void
itc_prev_entry (it_cursor_t * itc, buffer_desc_t * buf)
{
  /* when reading in descending order */
  if (0 >= itc->itc_map_pos)
    itc->itc_map_pos = ITC_AT_END;
  else
    {
      itc->itc_map_pos--;
    }
}


void
itc_skip_entry (it_cursor_t * itc, buffer_desc_t * buf)
{
  page_map_t * pm = buf->bd_content_map;
  if (ITC_AT_END == itc->itc_map_pos)
    return;
  itc->itc_map_pos++;
  if (itc->itc_map_pos >= pm->pm_count)
    itc->itc_map_pos = ITC_AT_END;
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
  itc->itc_map_pos = DP_DATA + HASH_HEAD_LEN;
  itc->itc_page = next;
  return DVC_MATCH;
}


#define ITC_OUT_MAP(itc) itc->itc_ks->ks_out_map


int
itc_row_check (it_cursor_t * itc, buffer_desc_t * buf)
{
  key_source_t *ks;
  dbe_key_t *row_key = NULL;
  /* Check the key id's and non-key columns. */
  search_spec_t *sp;
  if (itc->itc_batch_size && itc->itc_n_results >= itc->itc_batch_size) GPF_T1 ("batch over end");
  if (itc->itc_insert_key && itc->itc_insert_key->key_is_bitmap && !itc->itc_no_bitmap)
    return itc_bm_row_check (itc, buf);
  if (RANDOM_SEARCH_ON == itc->itc_random_search)
    itc->itc_st.n_sample_rows++;

  if (IE_KEY_VERSION (itc->itc_row_data) == itc->itc_insert_key->key_version)
    itc->itc_row_key = itc->itc_insert_key;
  else
	{
	  ITC_REAL_ROW_KEY (itc);
	  if (!sch_is_subkey (isp_schema (NULL), itc->itc_row_key->key_id, itc->itc_insert_key->key_id))
	    return DVC_LESS;	/* Key specified but this ain't it */
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
	      int res = page_col_cmp_1 (buf, itc->itc_row_data, &sp->sp_cl, itc->itc_search_params[sp->sp_min]);
	      if (0 == (op & res) || (DVC_NOORDER & res))
		return DVC_LESS;
	    }
	  else if (op == CMP_LIKE)
	    {
	      if (DVC_MATCH != itc_like_compare (itc, buf, itc->itc_search_params[sp->sp_min], sp))
		return DVC_LESS;
	      goto next_sp;
	    }
	  if (sp->sp_max_op != CMP_NONE)
	    {
	      int res = page_col_cmp_1 (buf, itc->itc_row_data, &sp->sp_cl, itc->itc_search_params[sp->sp_max]);
	      if (0 == (sp->sp_max_op & res) || (DVC_NOORDER & res))
		return DVC_LESS;
	    }
	next_sp:
	  sp = sp->sp_next;
	} while (sp);
    }
  ks = itc->itc_ks;
  if (ks)
    {
      if (ks->ks_out_slots)
	{
	  int inx = 0;
	  out_map_t * om = ITC_OUT_MAP (itc);
	  DO_SET (state_slot_t *, ssl, &ks->ks_out_slots)
	    {
	      if (ssl->ssl_type == SSL_CONSTANT)
		continue;
	      if (om[inx].om_is_null)
		{
		  if (OM_NULL == om[inx].om_is_null)
		    qst_set_bin_string (itc->itc_out_state, ssl, (db_buf_t) "", 0, DV_DB_NULL);
		  else
		    qst_set (itc->itc_out_state, ssl, itc_box_row (itc, buf));
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
			itc_qst_set_column (itc, buf, cl, itc->itc_out_state, ssl);
		    }
		  else
		    itc_qst_set_column (itc, buf, &om[inx].om_cl, itc->itc_out_state, ssl);
		}
	      inx++;
	    }
	  END_DO_SET();
	}
      if (itc->itc_param_order)
	{
	  QNCAST (query_instance_t, qi, itc->itc_out_state);
	  int * sets = QST_BOX (int *, itc->itc_out_state, ks->ks_ts->src_gen.src_sets);
	  sets[itc->itc_set] = itc->itc_param_order[itc->itc_set];
	  qi->qi_set = itc->itc_set;
	}
      if (ks->ks_local_test
	  && !code_vec_run_no_catch (ks->ks_local_test, itc))
	return DVC_LESS;
      if (ks->ks_local_code)
	code_vec_run_no_catch (ks->ks_local_code, itc);
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

int itc_page_rcf_search (it_cursor_t * itc, buffer_desc_t ** buf_ret, dp_addr_t * leaf_ret);
int itc_col_page_search (it_cursor_t * itc, buffer_desc_t ** buf_ret, dp_addr_t * leaf_ret);

int
itc_sample_row_check (it_cursor_t * itc, buffer_desc_t * buf)
{
  dbe_key_t *row_key = NULL;
  /* Check the key id's and non-key columns. */
  search_spec_t *sp;

#if 0
  if (itc->itc_insert_key && itc->itc_insert_key->key_is_bitmap && !itc->itc_no_bitmap)
    return DVC_LESS;
#endif

  if (IE_KEY_VERSION (itc->itc_row_data) == itc->itc_insert_key->key_version)
    itc->itc_row_key = itc->itc_insert_key;
  else
    {
      ITC_REAL_ROW_KEY (itc);
      if (!sch_is_subkey (isp_schema (NULL), itc->itc_row_key->key_id, itc->itc_insert_key->key_id))
	return DVC_LESS;	/* Key specified but this ain't it */
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
		  if (col)
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
	      int res = page_col_cmp_1 (buf, itc->itc_row_data, &sp->sp_cl, itc->itc_search_params[sp->sp_min]);
	      if (0 == (op & res) || (DVC_NOORDER & res))
		return DVC_LESS;
	    }
	  else if (op == CMP_LIKE)
	    {
	      if (DVC_MATCH != itc_like_compare (itc, buf, itc->itc_search_params[sp->sp_min], sp))
		return DVC_LESS;
	      goto next_sp;
	    }
	  if (sp->sp_max_op != CMP_NONE)
	    {
	      int res = page_col_cmp_1 (buf, itc->itc_row_data, &sp->sp_cl, itc->itc_search_params[sp->sp_max]);
	      if (0 == (sp->sp_max_op & res) || (DVC_NOORDER & res))
		return DVC_LESS;
	    }
	next_sp:
	  sp = sp->sp_next;
	} while (sp);
    }
  return DVC_MATCH;
}


int
itc_search (it_cursor_t * it, buffer_desc_t ** buf_ret)
{
  dp_addr_t leaf;
  int res, pos;
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
      else if (it->itc_split_search_res)
	{
	  res = it->itc_split_search_res;
	  it->itc_split_search_res = 0;
	}
      else if (it->itc_search_mode == SM_READ)
	res = itc_page_split_search (it, buf_ret);
      else
	res = itc_page_insert_search (it, buf_ret);

      if (PA_READ_ONLY != it->itc_dive_mode)
	{
      itc_try_land (it, buf_ret);
      if (!it->itc_landed)
	{
	  *buf_ret = itc_reset (it);
	  goto start;
	}
	}
      else
	{
	  it->itc_landed = 1;
	  it->itc_rows_on_leaves += (*buf_ret)->bd_content_map->pm_count;
	  ITC_MARK_LANDED (it);
	}
      if (PA_READ_ONLY != it->itc_dive_mode && !(*buf_ret)->bd_is_write)
	GPF_T1 ("Buffer not on write access after cursor landed");

      if (it->itc_search_mode == SM_INSERT)
	return res;
      /* A read cursor landed on a leaf */
      if (it->itc_is_col)
	goto start;
      if (!it->itc_no_bitmap && it->itc_insert_key->key_is_bitmap)
	it->itc_bp.bp_just_landed = 1;
      if ((ISO_SERIALIZABLE == it->itc_isolation)  /* IvAn: this added according to Orri's instruction: */ && (DVC_GREATER != res))
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
	      itc_skip_entry (it, *buf_ret);
	      if (it->itc_map_pos != ITC_AT_END)
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
      if (ITC_AT_END == it->itc_map_pos)
	goto at_end;
      if (it->itc_is_col)
	res = itc_col_page_search (it, buf_ret, &leaf);
      else
	res = it->itc_simple_ps
	  ? itc_page_rcf_search (it, buf_ret, &leaf)
	  : itc_page_search (it, buf_ret, &leaf, just_landed_match);
      just_landed_match = 0;
    }

search_switch:
  switch (res)
    {
    case DVC_INDEX_END:
      {
      at_end:
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
	  {
	    if (DVC_MATCH != itc_vacuum_compact (it, buf_ret))
	      return DVC_INDEX_END;
	  }
	up = LONG_REF (((*buf_ret)->bd_buffer) + DP_PARENT);
	/* in principle, the parent link must be read inside the dp's map.  Here we only want to know if it is 0.
	 * The map is not needed for that since aroot can stop being a root only by somebody changing it, which can't be since this itc is ecl in.
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

	pos = page_find_leaf (*buf_ret, leaf_from);
	if (-1 == pos)
	  {
	    dbg_page_map (*buf_ret);
	    GPF_T1 ("up transit to a page w/o corresponding down pointer");
	  }
	it->itc_map_pos = pos;
	if (it->itc_desc_order)
	  itc_prev_entry (it, *buf_ret);
	else
	  itc_skip_entry (it, *buf_ret);
	if (it->itc_is_col)
	  res = itc_col_page_search (it, buf_ret, &leaf);
	else
	res = itc_page_search (it, buf_ret, &leaf, 0);
	if (res == DVC_GREATER)
	  {
	    it->itc_is_on_row = 0;
	    return DVC_INDEX_END;
	  }
	if (res == DVC_MATCH)
	  {
	    pos = it->itc_map_pos;
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
	int lock_after_match;
	if (leaf)
	  {
	    itc_landed_down_transit (it, buf_ret, leaf);
	    goto start;
	  }
	/* must come from itc_page_search.  Any landing must pass via itc_page_search before coming here */
	it->itc_is_on_row = 1;
	lock_after_match = itc_lock_after_match (it);
	if (it->itc_owns_page != it->itc_page
	    && lock_after_match && !it->itc_is_col)
	{
	    int wait_rc = itc_set_lock_on_row (it, buf_ret);
	    if (wait_rc != NO_WAIT || !it->itc_is_on_row)
	      goto start; /* if waited, must recheck the key, again pass via itc_page_search */
	  }
	ITC_AGE_TRX (it, 1);
	if (it->itc_search_mode == SM_READ)
	  {
	    /* not in SM_READ_EXACT, where no more fetched */
	    if (((it->itc_ks && it->itc_ks->ks_is_last)
		|| ITC_VEC_MORE (it))
		&& !it->itc_cl_batch_done && !it->itc_insert_key->key_is_bitmap)
	      {
		if (it->itc_desc_order)
		  itc_prev_entry (it, *buf_ret);
		else
		  {
		    if (it->itc_tree->it_hi)
		      itc_hash_next (it, *buf_ret);
		    else
		      itc_skip_entry (it, *buf_ret);
		  }
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


#if 0
#define ITC_CK_POS(itc, buf)
#else

#define ITC_CK_POS(itc, buf)						\
  {if (!itc->itc_tree->it_hi && ITC_AT_END != itc->itc_map_pos && (itc->itc_map_pos >= (buf)->bd_content_map->pm_count || itc->itc_map_pos < 0)) \
    GPF_T1("itc_position out of range after itc_search"); }
#endif


int
itc_next (it_cursor_t * it, buffer_desc_t ** buf_ret)
{
  key_source_t * ks;
  if (it->itc_is_on_row)
    {
      ITC_MARK_ROW (it);
      it->itc_is_on_row = 0;
      if (it->itc_insert_key->key_is_bitmap)
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
		itc_skip_entry (it, *buf_ret);
	    }
	}
      else  if (it->itc_tree->it_hi)
	itc_hash_next (it, *buf_ret);
      else
	{
	  if (it->itc_desc_order)
	    itc_prev_entry (it, *buf_ret);
	  else
	    itc_skip_entry (it, *buf_ret);
	}
    }
 skip_bitmap:
  ks = it->itc_ks;
  if (ks && (ks->ks_local_test || ks->ks_local_code || ks->ks_setp || ks->ks_qf_output))
    {
      int rc;
      query_instance_t * volatile qi = (query_instance_t *) it->itc_out_state;
      QR_RESET_CTX_T (qi->qi_thread)
	{
	  ITC_FAIL (it)
	    {
	      rc  = itc_search (it, buf_ret);
	      ITC_CK_POS (it, *buf_ret);
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
      ITC_CK_POS (it, *buf_ret);
      return rc;
    }
}

long  tc_desc_serial_reset;
/* control is read committed will show previous committed value Oracle style or wait */
int min_iso_that_waits = ISO_REPEATABLE;


int
itc_hash_next (it_cursor_t * itc, buffer_desc_t * buf)
{
  db_buf_t row;
  int gl;
  row = buf->bd_buffer + itc->itc_map_pos;
  gl = page_gap_length (buf->bd_buffer, itc->itc_map_pos);
  itc->itc_map_pos += gl;
  if (itc->itc_map_pos + HASH_HEAD_LEN >= PAGE_SZ)
    {
      itc->itc_map_pos = ITC_AT_END;
      return DVC_INDEX_END;
    }

  gl = row_length (row, buf->bd_tree->it_key);
  itc->itc_map_pos += ROW_ALIGN (gl) + HASH_HEAD_LEN;
  if (itc->itc_map_pos >= PAGE_SZ)
    {
      itc->itc_map_pos = ITC_AT_END;
      return DVC_INDEX_END;
    }
  return DVC_MATCH;
}


int
itc_hash_page_search (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  int rc;
  buffer_desc_t * buf = *buf_ret;
  db_buf_t page = buf->bd_buffer;
  db_buf_t row;
  for (;;)
    {
      key_ver_t kv;
      if (ITC_AT_END == itc->itc_map_pos)
	return DVC_INDEX_END; /* the next in itc_next can move this to end.  Must not ref the kv, else can get by accident a 1 and think it's a row */
      row = page + itc->itc_map_pos;
      kv = IE_KEY_VERSION (row);
      if (kv!= 1)
	{
	  /* a;all legit kvs are 1.  No migration, subclass, leaf ptrs etc */
	  itc->itc_map_pos = ITC_AT_END;
	  return DVC_INDEX_END;
	}
      itc->itc_row_data = page + itc->itc_map_pos;
      itc->itc_row_key = buf->bd_tree->it_key;
      rc = itc->itc_ks ? itc->itc_ks->ks_row_check (itc, *buf_ret)
	: itc_row_check (itc, *buf_ret);

      if (DVC_GREATER == rc)
	return rc;
      if (itc->itc_batch_size)
	{
	  if (itc->itc_n_results >= itc->itc_batch_size)
	    return DVC_MATCH;
	}
      else if (DVC_MATCH == rc)
	return rc;
      rc = itc_hash_next (itc, buf);
      if (DVC_INDEX_END == rc)
	return rc;
    }
}


int
itc_page_search (it_cursor_t * it, buffer_desc_t ** buf_ret, dp_addr_t * leaf_ret,   int skip_first_key_cmp)
{
  db_buf_t page = (*buf_ret)->bd_buffer, row;
  dp_addr_t leaf = 0;
  key_ver_t kv;
  row_ver_t rv;
  search_spec_t *sp;
  int res = DVC_LESS, row_check;
  char txn_clear = PS_LOCKS;

  if (it->itc_is_col) GPF_T1 ("itc_page_search does not apply for column-wise indices");
  if (it->itc_wst)
    return (itc_text_search (it, buf_ret, leaf_ret));
  if (it->itc_tree->it_hi)
    return itc_hash_page_search (it, buf_ret);
  if (ITC_AT_END == it->itc_map_pos)
    {
      *leaf_ret = 0;
      return DVC_INDEX_END;
    }
  if (it->itc_is_col)
    txn_clear = PS_NO_LOCKS; /* locks for column-wise are checked with the inside row  check */
  else if (ISO_UNCOMMITTED == it->itc_isolation)
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
#ifndef NDEBUG
      if (it->itc_insert_key->key_is_bitmap && it->itc_map_pos >= (*buf_ret)->bd_content_map->pm_count)
	{
	  log_error ("itc_map_pos out of range in page search");
	  it->itc_map_pos = ITC_AT_END;
	}
      if (ITC_AT_END == it->itc_map_pos)
	{
	  *leaf_ret = 0;
	  return DVC_INDEX_END;
	}
      if (it->itc_map_pos >= (*buf_ret)->bd_content_map->pm_count)
	GPF_T1 ("itc_map_pos out of range in page search");
#endif
      if (PS_LOCKS == txn_clear)
	{
	  if (it->itc_owns_page != it->itc_page)
	    {
	      if (it->itc_isolation == ISO_SERIALIZABLE
		  || ((it->itc_isolation >= min_iso_that_waits || PL_EXCLUSIVE == it->itc_lock_mode)
		      && ITC_MAYBE_LOCK (it, it->itc_map_pos)))
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
		  if (ITC_AT_END == it->itc_map_pos)
		    {
		      /* The row may have been deleted during lock wait.
		       * if this was the last row, the itc_position will have been set to at end */
		      *leaf_ret = 0;
		      return DVC_INDEX_END;
		    }
		}
	    }
	  else
	    txn_clear = PS_OWNED;
	}
      if (it->itc_boundary && it->itc_page == it->itc_boundary->itc_page && it->itc_map_pos >= it->itc_boundary->itc_map_pos)
	return DVC_GREATER; /* end of the range of rows to be scanned by this itc.  Used when a range is split over many parallel itcs */

      row = (*buf_ret)->bd_buffer +  (*buf_ret)->bd_content_map->pm_entries[it->itc_map_pos];
      kv = IE_KEY_VERSION (row);
      if (KV_LEFT_DUMMY == kv)
	{
	  if (it->itc_desc_order)
	    {
	      /* when going in reverse always descend into the leftmost leaf */
	      leaf = LONG_REF (row + LD_LEAF);
	      if (leaf)
		{
		  *leaf_ret = leaf;
		  return DVC_MATCH;
		}
	    }
	  goto next_row;
	}
      rv = IE_ROW_VERSION (row);
      if (KV_LEAF_PTR == kv)
	{
	  leaf = LONG_REF (row + it->itc_insert_key->key_key_leaf[rv]);
	  it->itc_row_data = row;
	}
      else
	{
	  it->itc_row_data = row;
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
	       && it->itc_key_spec.ksp_key_cmp != pg_insert_key_compare)
	{
	  res = it->itc_key_spec.ksp_key_cmp (*buf_ret, it->itc_map_pos, it);
	  if (DVC_GREATER == res)
	    return res;
	}
      else
	{
	  dbe_key_t * row_key = it->itc_insert_key->key_versions[kv];
	int nth_part = 0;
	  res = DVC_MATCH;
	  for (sp = it->itc_key_spec.ksp_spec_array; sp; sp = sp->sp_next)
	    {
	      DV_COMPARE_SPEC_W_NULL (res, row_key->key_part_cls[nth_part], sp, it, *buf_ret);

	  if (res == DVC_MATCH)
	    {
	      nth_part++;
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
		  return DVC_GREATER;
		}
	    }
	}
      if (!leaf /* MI: if it is a leaf pointer no point to check for lock */
	  && PS_LOCKS == txn_clear && ISO_COMMITTED == it->itc_isolation
	  && PL_EXCLUSIVE != it->itc_lock_mode
	  && ISO_REPEATABLE == min_iso_that_waits)
	{
	  if (DVC_MATCH != itc_read_committed_check (it, *buf_ret))
	    goto next_row;
	}
      else if (IE_ISSET (row, IEF_DELETE))
	{
	  if (it->itc_bm_insert)
	    {
	      it->itc_is_on_row = 1;
	      return DVC_MATCH;
	    }
	  goto next_row;
	}
	  *leaf_ret = leaf;
      /* if go to the leaf even if the compare was less because the leaf can still hold stuff if in desc order.  In asc order the compare never gives dvc_less if the index is not out of order */
      if (leaf && (DVC_MATCH == res || !it->itc_insert_key->key_is_geo))
	return DVC_MATCH;
      if (DVC_MATCH == res)
	    {
	  row_check = it->itc_ks ? it->itc_ks->ks_row_check (it, *buf_ret)
	    : itc_row_check (it, *buf_ret);
	      if (DVC_GREATER == row_check)
		return DVC_GREATER;
	      if (DVC_MATCH == row_check)
		{
		  if (it->itc_ks && it->itc_ks->ks_is_last && !it->itc_cl_batch_done
		      && (PS_OWNED == txn_clear
		      || (ISO_COMMITTED == it->itc_isolation  && PL_EXCLUSIVE != it->itc_lock_mode)
			  || ISO_SERIALIZABLE == it->itc_isolation))
		    {
		  /* A RR or *exckl RC cursor that does not own the page must return to itc_search for the locks.  */
		      goto next_row;
		    }
		  if (it->itc_cl_results
		      && !itc_lock_after_match (it))
		    {
		      /* A RR or *exckl RC cursor that does not own the page must return to itc_search for the locks.  */
		      goto next_row;
		    }
	      if (ITC_VEC_MORE (it)
		  && !itc_lock_after_match (it))
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
      if (SM_READ_EXACT == it->itc_search_mode)
	return DVC_GREATER;
      if (it->itc_batch_size && it->itc_n_results >= it->itc_batch_size)
	return DVC_MATCH;
      if (it->itc_insert_key->key_is_bitmap)
	it->itc_bp.bp_new_on_row = 1;

      if (it->itc_desc_order)
	{
	  itc_prev_entry (it, *buf_ret);
	  if (ITC_AT_END == it->itc_map_pos)
	    {
	      *leaf_ret = 0;
	      return DVC_INDEX_END;
	    }
	}
      else
	{
	  if (++it->itc_map_pos >= (*buf_ret)->bd_content_map->pm_count)
	    {
	      *leaf_ret = 0;
	      it->itc_map_pos = ITC_AT_END;
	      return DVC_INDEX_END;
	    }
	}
      ITC_MARK_ROW (it);
    }
}

#define RCF_1_FOUND \
  {if (itc->itc_n_sets) { goto next_set; } else return DVC_MATCH;}

#define RCF_1_NOT_FOUND \
  {if (itc->itc_n_sets) goto next_set; else return DVC_GREATER;}


int
itc_page_rcf_search (it_cursor_t * itc, buffer_desc_t ** buf_ret, dp_addr_t * leaf_ret)
{
  buffer_desc_t * buf = *buf_ret;
  db_buf_t row;
  dp_addr_t leaf = 0;
  key_ver_t kv;
  row_ver_t rv;
  search_spec_t *sp;
  int res = DVC_LESS, row_check;
  char txn_clear;
  if (ITC_AT_END == itc->itc_map_pos)
    {
      *leaf_ret = 0;
      return DVC_INDEX_END;
    }
 new_row:
  txn_clear = PS_LOCKS;
  if (!buf->bd_pl)
    txn_clear = PS_OWNED;
  if (SM_READ_EXACT == itc->itc_search_mode)
    {
      itc->itc_row_data = row = BUF_ROW (buf, itc->itc_map_pos);
      if (KV_LEFT_DUMMY == IE_KEY_VERSION (itc->itc_row_data)) GPF_T1 ("read exact hits left edge");
      if (PS_LOCKS == txn_clear)
	{
	  if (DVC_MATCH != itc_read_committed_check (itc, *buf_ret))
	    RCF_1_NOT_FOUND;
	}
      else if (IE_ISSET (row, IEF_DELETE))
	RCF_1_NOT_FOUND;
      row_check = itc->itc_ks->ks_row_check (itc, *buf_ret);
      if (DVC_MATCH == row_check)
	{
	  if (itc->itc_ks->ks_is_last)
	    RCF_1_FOUND;
	  if (ITC_VEC_MORE (itc))
	    goto next_set;
	  return DVC_MATCH;
	}
      else
	RCF_1_NOT_FOUND;
    }


  for (;;)
    {
      if (itc->itc_boundary && itc->itc_page == itc->itc_boundary->itc_page && itc->itc_map_pos >= itc->itc_boundary->itc_map_pos)
	return DVC_GREATER; /* end of the range of rows to be scanned by this itc.  Used when a range is split over many parallel itcs */

      row = buf->bd_buffer +  buf->bd_content_map->pm_entries[itc->itc_map_pos];
      kv = IE_KEY_VERSION (row);
      if (KV_LEFT_DUMMY == kv)
	{
	  if (itc->itc_random_search)
	    goto next_row;
	  if (itc->itc_insert_key->key_is_geo)
	    {
	      if (LONG_REF (row + LD_LEAF)) GPF_T1 ("in geo index, not supposed to have left dummy in a non-leaf position");
	      goto next_row;
	    }

	  /* 
 	   *  In random access one does not hit amatch with a left dummy.  
           *  In seq access can happen if other itc deletes the row and page this is on then this gets relocated to the 
	   *  leaf ptr to the left of the delete, in case whole pages are deleted.
	   *  If so, then take the first branch down from whatever is the next leftmost leaf ptr.  
	   *  If on leaf already, so left dummy does not point down, go to next row 
	   */
	  if (!itc->itc_landed)
	    GPF_T1 ("not supposed to get left dummy in rcf page search");
	  else
	    {
	      *leaf_ret = LONG_REF (row + LD_LEAF);
	      if (!*leaf_ret)
		goto next_row;
	      return DVC_MATCH;
	    }
	}
      rv = IE_ROW_VERSION (row);
      itc->itc_row_data = row;
      if (KV_LEAF_PTR == kv)
	{
	  leaf = LONG_REF (row + itc->itc_insert_key->key_key_leaf[rv]);
	}
      else
	{
	  itc->itc_at_data_level = 1;
	  leaf = 0;
	}

      if (itc->itc_key_spec.ksp_key_cmp != pg_key_compare)
	{
	  res = itc->itc_key_spec.ksp_key_cmp (*buf_ret, itc->itc_map_pos, itc);
	  if (DVC_GREATER == res)
	    goto next_set;
	}
      else
	{
	  dbe_key_t * row_key = itc->itc_insert_key->key_versions[kv];
	int nth_part = 0;
	  res = DVC_MATCH;
	  for (sp = itc->itc_key_spec.ksp_spec_array; sp; sp = sp->sp_next)
	    {
	      DV_COMPARE_SPEC_W_NULL (res, row_key->key_part_cls[nth_part], sp, itc, *buf_ret);

	  if (res == DVC_MATCH)
	    {
	      nth_part++;
	      continue;
	    }
	  if (res == DVC_LESS)
	    {
		  /*  column is too small.  If there is a leaf, go there else search at end */
	      if (ITC_NULL_CK(itc, sp->sp_cl))
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
		  return DVC_GREATER;
		}
	    }
	}
      if (!leaf /* MI: if it is a leaf pointer no point to check for lock */
	  && PS_LOCKS == txn_clear)
	{
	  if (DVC_MATCH != itc_read_committed_check (itc, *buf_ret))
	    goto next_row;
	}
      else if (IE_ISSET (row, IEF_DELETE))
	{
	  goto next_row;
	}
	  *leaf_ret = leaf;
      if (leaf && (DVC_MATCH == res || !itc->itc_insert_key->key_is_geo))
	return DVC_MATCH;
      if (DVC_MATCH == res)
	    {
	      row_check = itc->itc_ks->ks_row_check (itc, *buf_ret);
	      if (DVC_GREATER == row_check)
		return DVC_GREATER;
	      if (DVC_MATCH == row_check)
		{
		  if (itc->itc_ks->ks_is_last)
		      goto next_row;
		  if (ITC_VEC_MORE (itc))
		      goto next_row;
		  return DVC_MATCH;
		}
	      else
		goto next_row;
	    }

next_row:
      itc->itc_bp.bp_new_on_row = 1;
      if (++itc->itc_map_pos >= buf->bd_content_map->pm_count)
	{
	  *leaf_ret = 0;
	  itc->itc_map_pos = ITC_AT_END;
	  return DVC_INDEX_END;
	}
      itc->itc_ltrx->lt_client->cli_activity.da_seq_rows++;
    }
 next_set:
  if (!itc->itc_n_sets)
    return DVC_GREATER;
  res = itc_next_set (itc, buf_ret);
  if (DVC_MATCH != res)
    {
      itc->itc_split_search_res = 0;
      return DVC_GREATER;
    }
  buf = *buf_ret;
  res = itc->itc_split_search_res;
  itc->itc_split_search_res = 0;
  if (SM_READ == itc->itc_search_mode)
    {
      if (DVC_LESS == res)
	{
	  txn_clear = buf->bd_pl ? PS_LOCKS : PS_OWNED;
	  goto next_row;
	}
      goto new_row;
    }
  if (DVC_MATCH == res)
    goto new_row;
  goto next_set;
	}


int
itc_col_page_search (it_cursor_t * itc, buffer_desc_t ** buf_ret, dp_addr_t * leaf_ret)
{
  buffer_desc_t * buf = *buf_ret;
  db_buf_t row;
  dp_addr_t leaf = 0;
  key_ver_t kv;
  row_ver_t rv;
  int res = DVC_LESS, row_check, prev_set;
  char txn_clear;
  if (ITC_AT_END == itc->itc_map_pos)
    {
      *leaf_ret = 0;
      return DVC_INDEX_END;
    }
  if (itc->itc_page != itc->itc_last_checked_page && itc->itc_ks && itc->itc_ks->ks_check)
    {
      itc->itc_last_checked_page =itc->itc_page;
      itc_ce_check (itc, buf, 1);
    }
 new_row:
  txn_clear = PS_LOCKS;
  if (!buf->bd_pl)
    txn_clear = PS_OWNED;
  for (;;)
    {
      if (itc->itc_boundary && itc->itc_page == itc->itc_boundary->itc_page && itc->itc_map_pos >= itc->itc_boundary->itc_map_pos)
	return DVC_GREATER; /* end of the range of rows to be scanned by this itc.  Used when a range is split over many parallel itcs */

      row = buf->bd_buffer +  buf->bd_content_map->pm_entries[itc->itc_map_pos];
      kv = IE_KEY_VERSION (row);
      if (KV_LEFT_DUMMY == kv)
	goto next_row;
      rv = IE_ROW_VERSION (row);
      itc->itc_row_data = row;
      if (KV_LEAF_PTR == kv)
	{
	  leaf = LONG_REF (row + itc->itc_insert_key->key_key_leaf[rv]);
	}
      else
	{
	  itc->itc_at_data_level = 1;
	  leaf = 0;
	}
      res = itc->itc_key_spec.ksp_key_cmp (*buf_ret, itc->itc_map_pos, itc);
      if (DVC_GREATER == res)
	goto next_set;

	  *leaf_ret = leaf;
      if (leaf)
	return DVC_MATCH;
      prev_set = itc->itc_set;
      row_check = itc_col_row_check (itc, buf_ret, leaf_ret);
      buf = *buf_ret;
      if (DVC_GREATER == row_check)
	goto next_set;
      if (itc->itc_set != prev_set)
	itc_set_param_row (itc, itc->itc_set);
      if (DVC_MATCH == row_check)
	return row_check;
    next_row:
      if (++itc->itc_map_pos >= buf->bd_content_map->pm_count)
	    {
	      *leaf_ret = 0;
	  itc->itc_map_pos = ITC_AT_END;
	      return DVC_INDEX_END;
	    }
	}
 next_set:
  if (!itc->itc_n_sets)
    return DVC_GREATER;
  res = itc_next_set (itc, buf_ret);
  if (DVC_MATCH != res)
    {
      itc->itc_split_search_res = 0;
      return DVC_GREATER;
    }
  buf = *buf_ret;
  res = itc->itc_split_search_res;
  itc->itc_split_search_res = 0;
  itc->itc_col_row = COL_NO_ROW;
  itc->itc_landed = 1;
  goto new_row;
}


int
pg_key_compare (buffer_desc_t * buf, int pos, it_cursor_t * it)
{
  db_buf_t page = buf->bd_buffer;
  db_buf_t row;
  search_spec_t *spec = it->itc_key_spec.ksp_spec_array;
  int nth = 0;
  dbe_key_t  * key = it->itc_insert_key;
  key_ver_t kv;

  row = it->itc_row_data = page + buf->bd_content_map->pm_entries[pos];
  kv = IE_KEY_VERSION (row);
  if (KV_LEFT_DUMMY == kv)
    {
      return DVC_LESS;
    }
  if (kv != key->key_version)
    key = key->key_versions[kv];
  for (;;)
    {
      int res;
      if (!spec)
	{
	  return DVC_MATCH;
	}
      res = itc_compare_spec (it, buf, key->key_part_cls[nth], spec);
      if (spec->sp_is_reverse && DVC_MATCH != res)
	res = res == DVC_GREATER ? DVC_LESS : DVC_GREATER;
      if (res == DVC_MATCH)
	{
	  spec = spec->sp_next;
	  nth++;
	  continue;
	}
      return res;
    }

  /*NOTREACHED*/
  return DVC_MATCH;
}

#if defined(__GNUC__) && (__GNUC__ > 3 || (__GNUC__ == 3 && __GNUC_MINOR__ >= 10))
#define PREFETCH \
  guess = (at_or_above + below) / 2; \
  __builtin_prefetch (page + map->pm_entries[guess])
#else
#define PREFETCH \
  guess = (at_or_above + below) / 2
#endif

int
itc_page_split_search (it_cursor_t * it, buffer_desc_t ** buf_ret)
{
 new_page:
  {
    dp_addr_t leaf;
    buffer_desc_t * buf = *buf_ret;
    db_buf_t page = buf->bd_buffer, row;
  int res;
  page_map_t *map = buf->bd_content_map;
  int below = map->pm_count;
  int at_or_above = 0;
  int guess;
  int at_or_above_res = -100;
  key_ver_t kv;
  PREFETCH;
  if (it->itc_dive_mode != PA_WRITE ? buf->bd_is_write : !buf->bd_is_write)
    GPF_T1 ("split search supposed to be in read mode");
  if (map->pm_count == 0)
    {
      it->itc_map_pos = ITC_AT_END;
      return DVC_GREATER;
    }


  for (;;)
    {
      if ((below - at_or_above) <= 1)
	{
	  if (at_or_above_res == -100)
	    {
	      at_or_above_res = it->itc_key_spec.ksp_key_cmp (buf, at_or_above, it);
	    }
	  switch (at_or_above_res)
	    {
	    case DVC_MATCH:
	    case DVC_LESS:
	      {
		it->itc_map_pos = at_or_above;
		row = page + map->pm_entries[at_or_above];
		kv = IE_KEY_VERSION (row);
		if (KV_LEFT_DUMMY == kv)
		  leaf = LONG_REF (row + LD_LEAF);
		else if (KV_LEAF_PTR == kv)
		  leaf = LONG_REF (row + it->itc_insert_key->key_key_leaf[IE_ROW_VERSION (row)]);
		else
		  leaf = 0;
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
		it->itc_row_data = row;
		it->itc_map_pos = at_or_above;
		return at_or_above_res;
	      }
	    case DVC_GREATER:
	      {
		/* The lower limit, 0 was greater. No way down. */
		it->itc_map_pos = at_or_above;
		return DVC_GREATER;
	      }
	    }
	}
      /* OK, we have an interval to search */
      res = it->itc_key_spec.ksp_key_cmp (buf, guess, it);
      switch (res)
	{
	case DVC_LESS:
	  at_or_above = guess;
	  PREFETCH;
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
	  PREFETCH;
	  break;

	case DVC_GREATER:
	  below = guess;
	  PREFETCH;
	  break;
	default: GPF_T1 ("key_cmp_t can't return that");
	}
	}
    }
}

int
pg_insert_key_compare (buffer_desc_t * buf, int pos, it_cursor_t * it)
{
  db_buf_t row = buf->bd_buffer + buf->bd_content_map->pm_entries[pos];
  dbe_key_t * key = it->itc_insert_key;
  search_spec_t *spec = it->itc_key_spec.ksp_spec_array;
  int nth = 0;
  key_ver_t kv = IE_KEY_VERSION (row);
  if (KV_LEFT_DUMMY == kv)
    {
      return DVC_LESS;
    }
  it->itc_row_data = row;
  if (kv != key->key_version)
    key = key->key_versions[kv];

  for (;;)
    {
      int res;
      if (!spec)
	{
	  return DVC_MATCH;
	}
      res = page_col_cmp (buf, it->itc_row_data, key->key_part_cls[nth], it->itc_search_params[spec->sp_min]);
      if (spec->sp_is_reverse && DVC_MATCH != res)
	res = res == DVC_GREATER ? DVC_LESS : DVC_GREATER;
      if (res == DVC_MATCH)
	{
	  nth++;
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
      db_buf_t page = buf->bd_buffer, row;
  int res;
  page_map_t *map = buf->bd_content_map;
  int below = map->pm_count;
  int at_or_above = 0;
  int guess;
  int at_or_above_res = -100;
  key_ver_t kv;
  if (map->pm_count == 0)
    {
      it->itc_map_pos = ITC_AT_END;
      return DVC_GREATER;
    }
  PREFETCH;
  for (;;)
    {
      if ((below - at_or_above) <= 1)
	{
	  if (at_or_above_res == -100)
	    {
		  at_or_above_res = it->itc_key_spec.ksp_key_cmp (buf,
								  at_or_above, it);
	    }
	  switch (at_or_above_res)
	    {
	    case DVC_MATCH:
	    case DVC_LESS:
	      {
		it->itc_map_pos = at_or_above;
		row = page + map->pm_entries[at_or_above];
		kv = IE_KEY_VERSION (row);
		if (KV_LEAF_PTR == kv)
		  leaf = LONG_REF (row + it->itc_insert_key->key_key_leaf[IE_ROW_VERSION (row)]);
		else if (KV_LEFT_DUMMY == kv)
		  leaf = LONG_REF (row + LD_LEAF);
		else
		  leaf = 0;
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
		it->itc_map_pos = at_or_above;
		it->itc_row_data = row;
		return at_or_above_res;
	      }
	    case DVC_GREATER:
	      {
		/* The lower limit, 0 was greater. No way down. */
		it->itc_map_pos = at_or_above;
		return DVC_GREATER;
	      }
	    }
	}
      /* OK, we have an interval to search */
	  res = it->itc_key_spec.ksp_key_cmp (buf, guess, it);
      switch (res)
	{
	case DVC_LESS:
	  at_or_above = guess;
	  PREFETCH;
	  at_or_above_res = res;
	  break;
	case DVC_MATCH:	/* row found, dependent not checked */
	  it->itc_map_pos = guess;
	  row = page + map->pm_entries[guess];
	  kv = IE_KEY_VERSION (row);
	  if (KV_LEAF_PTR == kv)
	    {
	      leaf = LONG_REF (row + it->itc_insert_key->key_key_leaf[IE_ROW_VERSION (row)]);
	      if (buf->bd_is_ro_cache)
		{
		  itc_root_cache_enter (it, buf_ret, leaf);
		  return res;
		}
	      itc_dive_transit (it, buf_ret, leaf);
	      goto new_page;
	    }
	  it->itc_map_pos = guess;
	  it->itc_row_data = row;
	  return res;
	case DVC_GREATER:
	  below = guess;
	  PREFETCH;
	  break;
	    default: GPF_T1 ("can't have this res for key_cmp_t");
	}
    }
    }
}


int
itc_has_slice (it_cursor_t * itc, slice_id_t slice, caddr_t * err_ret)
{
  dbe_key_t * key = itc->itc_insert_key;
  dbe_key_frag_t ** kfs = key->key_fragments;
  if (!key->key_partition || !key->key_partition->kpd_map->clm_is_elastic)
    return 1;
  if (!kfs || BOX_ELEMENTS (kfs) <= slice || !key->key_fragments[slice])
    {
      char msg[200];
      if (err_ret)
	{
	  snprintf (msg, sizeof (msg),  "The key %s does not have slice %d on host %d", key->key_name, slice, local_cll.cll_this_host);
	  *err_ret = srv_make_new_error ("ELASL",  "ELASL", "%s", msg);
	}
      return 0;
    }
  return 1;
}


void
itc_set_tree (it_cursor_t * itc, slice_id_t slice)
{
  dbe_key_t * key = itc->itc_insert_key;
  if (itc->itc_insert_key->key_is_elastic)
    {
      dbe_key_frag_t ** kfs = itc->itc_insert_key->key_fragments;
      if (!kfs || BOX_ELEMENTS (kfs) <= slice || !key->key_fragments[slice])
	{
	  char msg[200];
	  snprintf (msg, sizeof (msg),  "The key %s does not have slice %d on host %d", key->key_name, slice, local_cll.cll_this_host);
	  if (itc->itc_fail_context)
	    {
	      if (itc->itc_ltrx)
		{
		  itc->itc_ltrx->lt_error_detail =  box_string (msg);
		  itc->itc_ltrx->lt_error = LTE_SQL_ERROR;
		}
	      else
		log_error (msg);
	      longjmp_splice (itc->itc_fail_context, RST_DEADLOCK);
	    }
	  else
	    sqlr_new_error ("ELASL",  "ELASL", "%s", msg);
	}
      itc->itc_tree = kfs[slice]->kf_it;
    }
  else
    itc->itc_tree = itc->itc_insert_key->key_fragments[0]->kf_it;
}


void
itc_from_keep_params (it_cursor_t * it, dbe_key_t * key, slice_id_t slice)
{
  it->itc_insert_key = key;
  it->itc_row_key = key;
  itc_set_tree (it, slice);
}


void
itc_clear_stats (it_cursor_t *it)
{
  memset (&(it->itc_st), 0, sizeof (it->itc_st));
}

long dbe_auto_sql_stats;

void
itc_from (it_cursor_t * it, dbe_key_t * key, slice_id_t slice)
{
  itc_free_owned_params (it);
  ITC_START_SEARCH_PARS (it);
  it->itc_search_mode = SM_READ;

  it->itc_insert_key = key;
  it->itc_row_key = key;
  itc_set_tree (it, slice);
}

void
itc_from_any_slice (it_cursor_t * it, dbe_key_t * key)
{
  itc_free_owned_params (it);
  ITC_START_SEARCH_PARS (it);
  it->itc_search_mode = SM_READ;
  it->itc_insert_key = key;
  it->itc_row_key = key;
  it->itc_tree = NULL;
}


void
itc_from_it (it_cursor_t * itc, index_tree_t * it)
{
  itc_free_owned_params (itc);
  ITC_START_SEARCH_PARS (itc);
  itc->itc_search_mode = SM_READ;
  itc->itc_insert_key = it->it_key;
  itc->itc_row_key = it->it_key;
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
  itc->itc_map_pos = page_find_leaf (*buf_ret, dp_from);
  if (ITC_AT_END == itc->itc_map_pos)
    GPF_T1 ("no down pointer in read ahead parent page");
  if (itc->itc_desc_order)
    itc_prev_entry (itc, *buf_ret);
  else
    itc_skip_entry (itc, *buf_ret);
  if (ITC_AT_END == itc->itc_map_pos)
    return DVC_INDEX_END;
  if (DVC_MATCH != pg_key_compare (*buf_ret, itc->itc_map_pos, itc))
    return DVC_INDEX_END;
  leaf = leaf_pointer ((*buf_ret)->bd_buffer + (*buf_ret)->bd_content_map->pm_entries[itc->itc_map_pos], itc->itc_insert_key);
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
  int pos = itc->itc_map_pos;
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
      while (ITC_AT_END != pos)
	{
	  dp_addr_t leaf = 0;
	  int rc = pg_key_compare (*buf_ret, pos, itc);
	  if (DVC_MATCH == rc)
	    {
	      leaf = leaf_pointer ((*buf_ret)->bd_buffer + (*buf_ret)->bd_content_map->pm_entries[pos], itc->itc_insert_key);
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
	      itc->itc_map_pos = pos;
	      itc_prev_entry (itc, *buf_ret);
	      pos = itc->itc_map_pos;
	    }
	  else
	    itc->itc_map_pos = pos;
	  itc_skip_entry (itc, *buf_ret);
	  pos = itc->itc_map_pos;
	}

      if (itc->itc_n_reads > 200
	  && ra->ra_nsiblings < RA_MAX_ROOTS / 2
	  && ra->ra_fill < RA_MAX_BATCH - 60)
	{
	  if (!pl)
	    {
	      itc->itc_map_pos = org_pos;
	      ITC_LEAVE_MAPS (itc);
	      pl = plh_landed_copy ((placeholder_t *) itc, *buf_ret);
	    }
	  if (DVC_MATCH != itc_ra_sibling (itc, buf_ret))
	    break;
	  ra->ra_nsiblings++;
	  page = (*buf_ret)->bd_buffer;
	  pos = itc->itc_map_pos;
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
    itc->itc_map_pos = org_pos;

  return ra;
}


long tc_read_aside;
extern int enable_iq_always;


void
itc_read_ahead_blob (it_cursor_t * itc, ra_req_t *ra, int flags)
{
  static unsigned char batch_id;
  int id_given = 0;
  int inx;
  buffer_pool_t * action_bp = NULL;
  if (!itc || !ra || (ra->ra_fill < 2 && !enable_iq_always))
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
      char btmp_not_decoy = 0;
      ITC_IN_KNOWN_MAP (itc, ra->ra_dp[inx]);
      if (!DBS_PAGE_IN_RANGE (itc->itc_tree->it_storage, ra->ra_dp[inx])
	  ||dbs_may_be_free (itc->itc_tree->it_storage, ra->ra_dp[inx]) || 0 == ra->ra_dp[inx])
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
	  btmp = bp_get_buffer_1 (NULL, &action_bp,  BP_BUF_IF_AVAIL);
	  ITC_IN_KNOWN_MAP (itc, ra->ra_dp[inx]);
	  remhash (DP_ADDR2VOID (ra->ra_dp[inx]), &IT_DP_MAP (itc->itc_tree, ra->ra_dp[inx])->itm_dp_to_buf);
	  if (!btmp)
	    {
	      page_mark_change (&decoy, 1 + RWG_WAIT_ANY);
	      page_leave_inner (&decoy);
	      ITC_LEAVE_MAP_NC (itc);
	      break;
	    }
	  if (!id_given)
	    {
	      id_given = batch_id++;
	      if (!id_given)
		id_given = batch_id++;
	    }
	  btmp->bd_batch_id = id_given;
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
	  if ((RAB_SPECULATIVE & flags))
	    {
	      BUF_TOUCH (btmp);
	      btmp->bdf.r.is_read_aside = 1;
	      btmp->bd_timestamp -= btmp->bd_pool->bp_stat_ts - btmp->bd_pool->bp_bucket_limit[BP_N_BUCKETS - 1];
	    }
	  btmp->bd_write_waiting = decoy.bd_write_waiting;
	  btmp->bd_read_waiting = decoy.bd_read_waiting;
	  ITC_LEAVE_MAP_NC (itc);
	  itc->itc_n_reads++;
	  ITC_MARK_READ (itc);
	  DBG_PT_PRINTF ((" SCH RA L=%d P=%d B=%p \n", btmp->bd_page, btmp->bd_physical_page, btmp));
	}
      else
	{
	  btmp_not_decoy = btmp->bd_pool != NULL;
	  ITC_LEAVE_MAP_NC (itc);
	  /* check that btmp has pool, i.e. is not decoy on stack inside the map.  If checked outside map and btmp on stack and overwritten, will be random content and can corrupt memory */
	  if (btmp_not_decoy && !(RAB_SPECULATIVE & flags))
	    BUF_TOUCH (btmp); /* make sure won't get replaced if already in */
	  if (btmp && (RAB_SPECULATIVE & flags))
	    tc_read_aside--; /* dec the stat for ones already in cache */
	}
    }
  ITC_LEAVE_MAPS (itc);
  if (ra->ra_bfill)
    {
      ra_count++;
      ra_pages += ra->ra_bfill;
      if (ra->ra_nsiblings > 1)
        {
	  dbg_printf (("RA %d sibling %d pages %d leaves\n", ra->ra_nsiblings, ra->ra_bfill, ra->ra_fill));
        }
      iq_schedule (ra->ra_bufs, ra->ra_bfill);
    }
  ITC_LEAVE_MAPS (itc);
fin:
  if (action_bp)
    bp_delayed_stat_action (action_bp);
  if (ra)
    dk_free_box((box_t) ra);
}


void
itc_read_ahead (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  itc_read_ahead_blob (itc, itc_read_ahead1 (itc, buf_ret), 0);
}

int enable_read_aside = 1;
int32 em_ra_window = 1000;
int32 em_ra_threshold = 2;
int32 em_ra_startup_window = 40000;
int32 em_ra_startup_threshold = 0;


int
em_trigger_ra (extent_map_t * em, dp_addr_t ext_dp, uint32 now, int window, int threshold)
{
  ptrlong rh;
  if (main_bufs < 10000)
    return 0;
  if (em == em->em_dbs->dbs_extent_map)
    return 0;
  if (0 == threshold)
    return 1;
  mutex_enter (&em->em_read_history_mtx);
  rh = (ptrlong) gethash (DP_ADDR2VOID(ext_dp), em->em_read_history);
  if (!rh)
    {
      sethash (DP_ADDR2VOID(ext_dp), em->em_read_history, (void*)(ptrlong)(now << 8));
      mutex_leave (&em->em_read_history_mtx);
      return 0;
    }
  if (now - (rh >> 8) > window)
    {
      sethash (DP_ADDR2VOID(ext_dp), em->em_read_history, (void*)(ptrlong)(now << 8));
      mutex_leave (&em->em_read_history_mtx);
      return 0;
    }
  if ((rh & 0xff) < em_ra_threshold)
    {
      sethash (DP_ADDR2VOID(ext_dp), em->em_read_history, (void*)(ptrlong)(rh + 1));
      mutex_leave (&em->em_read_history_mtx);
      return 0;
    }
  remhash (DP_ADDR2VOID(ext_dp), em->em_read_history);
  mutex_leave (&em->em_read_history_mtx);
  return 1;
}

int
em_ext_ra_pages (extent_map_t * em, it_cursor_t * itc, dp_addr_t ext_dp, dp_addr_t * leaves, int max, dp_addr_t except_dp, dk_hash_t * except)
{
  extent_t * ext;
  int fill = 0, inx;
  if (max <= 0)
    return 0;
  mutex_enter (em->em_mtx);
  ext = EM_DP_TO_EXT (em, ext_dp);
  if (!ext)
    {
      mutex_leave (em->em_mtx);
      mutex_enter (em->em_dbs->dbs_extent_map->em_mtx);
      ext = EM_DP_TO_EXT (em->em_dbs->dbs_extent_map, ext_dp);
      if (!ext)
	log_error ("in read aside, ext for dp %d not in the ext map and not in sys ext map ", ext_dp);
      mutex_leave (em->em_dbs->dbs_extent_map->em_mtx);
      return 0;
    }

  mutex_leave (em->em_mtx);
  /* the read of the bits in the ext is outside the em mtx.  The read ahead set is not immutable anyhow between here and read so does not matter, plus there is deadlock possibility if getting a map inside an em mtx */
  for (inx = 0; inx < EXTENT_SZ / BITS_IN_LONG; inx++)
    {
      int b_idx;
      for (b_idx = 0; b_idx < BITS_IN_LONG; b_idx++)
	{
	  dp_addr_t other_dp = ext_dp + (BITS_IN_LONG * inx) + b_idx, phys_dp;
	  int is_allocd = 0;
	  if (except_dp == other_dp)
	    continue;
	  if (except && gethash (DP_ADDR2VOID (other_dp), except))
	    continue;
	  mutex_enter (em->em_mtx);
	  if (0 == (ext->ext_pages[inx] & (1 << b_idx)))
	    ;
	  else if (gethash (DP_ADDR2VOID(other_dp), em->em_uninitialized))
#ifdef DEBUG
	    bing  ()
#endif
		;
	  else
	    is_allocd = 1;
	  mutex_leave (em->em_mtx);
	  if (!is_allocd)
	    continue;
	  ITC_IN_KNOWN_MAP (itc, other_dp);
	  IT_DP_REMAP (itc->itc_tree, other_dp, phys_dp);
	  ITC_LEAVE_MAP_NC (itc);
	  if (phys_dp != other_dp)
	    continue;
	  leaves[fill++] = other_dp;
	  if (fill >= max)
	    return fill;
	}
    }
  return fill;
}

extern long tc_new_page;

ra_req_t *
itc_read_aside (it_cursor_t * itc, buffer_desc_t * buf, dp_addr_t dp)
{
  /* mark the read history of the extent.  If more than so many inside a short time, do the whole extent
  * the buf is the parent of the dp. */
  int window, threshold;
  extent_map_t * em = itc->itc_tree->it_extent_map;
  int fill = 0;
  dp_addr_t leaves[EXTENT_SZ];
  dp_addr_t ext_dp = EXT_ROUND (dp);
  uint32 now;
  ra_req_t *ra=NULL;
  if (disk_reads + tc_new_page < main_bufs)
    {
      threshold = em_ra_startup_threshold;
      window = em_ra_startup_window;
	}
  else
    {
      threshold = em_ra_threshold;
      window = em_ra_window;
    }
  if (!enable_read_aside || em == em->em_dbs->dbs_extent_map)
    return NULL; /* do not apply to the sys ext map */
  now = get_msec_real_time ();
  if (!em_trigger_ra (em, ext_dp, now, window, threshold))
    return NULL;
  fill = em_ext_ra_pages (em, itc, ext_dp, leaves, EXTENT_SZ, dp, NULL);
  if (!fill)
    return NULL;
  tc_read_aside += fill;
  if (itc->itc_ltrx)
    itc->itc_ltrx->lt_client->cli_activity.da_spec_disk_reads += fill;
  ra= (ra_req_t *) dk_alloc_box(sizeof(ra_req_t),DV_CUSTOM);
  memset (ra, 0, sizeof (*ra));
  memcpy (&ra->ra_dp, leaves, fill * sizeof (dp_addr_t));
  ra->ra_fill = fill;
  return ra;
}


void
dbs_timeout_read_history (dbe_storage_t * dbs)
{
  int window = disk_reads < main_bufs ? em_ra_startup_window : em_ra_window;
  int now = approx_msec_real_time (), inx, nth;
  if (wi_inst.wi_checkpoint_atomic)
    return;
  for (nth = 0; 1; nth++)
    {
      index_tree_t * it;
      extent_map_t * em;
      dp_addr_t pages[100];
      int fill = 0;
      IN_TXN;
      it = (index_tree_t *)dk_set_nth (dbs->dbs_trees, nth);
      LEAVE_TXN;
      if (!it)
	return;
      em  = it->it_extent_map;
      if (!em || em == it->it_storage->dbs_extent_map)
	continue;
      mutex_enter (&em->em_read_history_mtx);
      DO_HT (void*, dp, ptrlong, rh, em->em_read_history)
	{
      if (now - (rh >> 8)  > 4 * window)
	{
	  pages[fill++] = (dp_addr_t)((ptrlong)(dp));
	  if (fill >= 100)
	    break;
	}
	}
      END_DO_HT;
      for (inx = 0; inx < fill; inx++)
	remhash (DP_ADDR2VOID (pages[inx]), em->em_read_history);
      mutex_leave (&em->em_read_history_mtx);
    }
}


/* random search support */


int
itc_up_rnd_check (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  if (itc->itc_st.n_sample_rows >= itc->itc_st.sample_size)
    return DVC_INDEX_END;
  if (itc->itc_is_col && itc->itc_rows_selected >= itc->itc_st.sample_size)
    return DVC_INDEX_END;
  itc->itc_st.n_sample_rows++; /* increment here also so as to guarantee termination even if table goes empty during the random scan. */
  itc_page_leave (itc, *buf_ret);
  *buf_ret = itc_reset (itc);
  return DVC_MATCH;
}


caddr_t
col_min_max_trunc (caddr_t val)
{
  int len;
  caddr_t ret = NULL;
  dtp_t dtp = DV_TYPE_OF (val);
  switch (dtp)
    {
    case DV_SINGLE_FLOAT: case DV_DOUBLE_FLOAT: case DV_NUMERIC: 
    case DV_LONG_INT: case DV_DATETIME:
      return val;
    case DV_STRING:
      len = box_length (val);
      if (len >30)
	{
	  ret =  box_n_chars (val, 30);
	  dk_free_tree (val);
	  return ret;
	}
      return val;
	  

    case DV_BLOB_HANDLE:
    case DV_BLOB_WIDE_HANDLE:
    case DV_XML_ENTITY:
    case DV_GEO:
    case DV_OBJECT:
    default:
      dk_free_tree (val);
      return dk_alloc_box (0, DV_DB_NULL);
    }
}

void
col_stat_free (col_stat_t *cs)
{
  id_hash_iterator_t hit;
  caddr_t * data;
  ptrlong * count;
  id_hash_iterator (&hit, cs->cs_distinct);
  while (hit_next (&hit, (caddr_t*) &data, (caddr_t*) &count))
    dk_free_tree (*data);
  id_hash_free (cs->cs_distinct);
  dk_free ((caddr_t) cs, sizeof (col_stat_t));
}

void col_stat_free_ext_int (col_stat_t *cs, boxint *min_ret, boxint *max_ret)
{
  id_hash_iterator_t hit;
  caddr_t * data;
  ptrlong * count;
  int is_first = 1;
  boxint min = 0, max = 0;
  id_hash_iterator (&hit, cs->cs_distinct);
  while (hit_next (&hit, (caddr_t*) &data, (caddr_t*) &count))
    {
      boxint d = unbox (*data);
      if (is_first)
        {
          is_first = 0;
          min = max = d;
        }
      else
        {
          if (d > max) max = d;
          else if (d < min) min = d;
        }
      dk_free_tree (*data);
    }
  id_hash_free (cs->cs_distinct);
  dk_free ((caddr_t) cs, sizeof (col_stat_t));
  min_ret[0] = min;
  max_ret[0] = max;
}

void
col_stat_free_ext_box (col_stat_t *cs, caddr_t *min_box_ret, caddr_t *max_box_ret)
{
  id_hash_iterator_t hit;
  caddr_t * data;
  ptrlong * count;
  int is_first = 1;
  caddr_t min_box = NULL, max_box = NULL;
  id_hash_iterator (&hit, cs->cs_distinct);
  while (hit_next (&hit, (caddr_t*) &data, (caddr_t*) &count))
    {
      if (is_first)
        {
          min_box = *data;
          max_box = box_copy_tree (min_box);
          is_first = 0;
        }
      else
        {
          int low_rc =  cmp_boxes_safe (*data, min_box, NULL, NULL);
          if (DVC_LESS == (~DVC_NOORDER & low_rc))
            {
              dk_free_tree (min_box);
              min_box = *data;
            }
          else 
            {
              int high_rc = cmp_boxes_safe (*data, max_box, NULL, NULL);
              if (DVC_GREATER == (~DVC_NOORDER & high_rc))
                {
                  dk_free_tree (max_box);
                  max_box = *data;
                }
              else 
                dk_free_tree (*data);
            }
        }
    }
  id_hash_free (cs->cs_distinct);
  dk_free ((caddr_t) cs, sizeof (col_stat_t));
  min_box_ret[0] = min_box;
  max_box_ret[0] = max_box;
}


void
itc_col_stat_free (it_cursor_t * itc, int upd_col, float est)
{
  dbe_key_t * key = itc->itc_insert_key;
  dk_hash_iterator_t it;

  dbe_column_t * col;
  col_stat_t * cs;
  if (!itc->itc_st.cols)
    return;
  dk_hash_iterator (&it, itc->itc_st.cols);
  while (dk_hit_next (&it, (void**) &col, (void**) &cs))
    {
      boxint min = 0, max = 0;
      caddr_t minb = NULL, maxb = NULL;
      long last_cs_distinct_inserts = cs->cs_distinct->ht_inserts;
      unsigned long last_cs_distinct_count = cs->cs_distinct->ht_count;
      int64 last_cs_len = cs->cs_len;
      int64 last_cs_n_values = cs->cs_n_values;
      int is_first = 1;
      int is_int = DV_LONG_INT == col->col_sqt.sqt_dtp || DV_INT64 == col->col_sqt.sqt_dtp;
      if (upd_col && (0 == stricmp (col->col_name, "P") || 0 == stricmp (col->col_name, "G")))
        {
          if (NULL != col->col_stat)
            srv_add_background_task (col_stat_free, col->col_stat);
          col->col_stat = cs;
          is_int = 0;
        }
      else
        {
          if (is_int)
            col_stat_free_ext_int (cs, &min, &max);
          else
            col_stat_free_ext_box (cs, &minb, &maxb);
        }
      if (upd_col)
        {
          if (key && !key->key_distinct)
            {
              col->col_count = last_cs_n_values / (float) itc->itc_st.n_sample_rows * est;
              if (CL_RUN_SINGLE_CLUSTER == cl_run_local_only)
                col->col_count *= key_n_partitions (key);
            }
          /* for distinct value count, consider a distinct projection is the col in question is the first, otherwise do not trust one */
          if (itc->itc_st.n_sample_rows && (key && (!key->key_distinct || col == (dbe_column_t*)key->key_parts->data)))
            {
              /* if n distinct under 2% of samples and under 200 values, assume that this is a flag.  If more distinct, scale pro rata.  */
              if (last_cs_distinct_inserts < itc->itc_st.n_sample_rows / 50 && last_cs_distinct_count < 200)
                col->col_n_distinct = last_cs_distinct_inserts;
              else
                col->col_n_distinct = (float)last_cs_distinct_inserts / (float)itc->itc_st.n_sample_rows * est;
              if (CL_RUN_SINGLE_CLUSTER == cl_run_local_only)
                col->col_n_distinct *= key_n_partitions (key);
              col->col_avg_len = last_cs_len / itc->itc_st.n_sample_rows;
              if (is_int && last_cs_distinct_count)
                {
                  /* if it is an int then the max distinct is the difference between min and max seen */
                  dk_free_tree (col->col_min); col->col_min = box_num (min);
                  dk_free_tree (col->col_max); col->col_max = box_num (max);
                  if (col->col_n_distinct > max - min)
                    col->col_n_distinct = MAX (1, max - min);
                }
              if (!is_int)
                {
                  dk_free_tree (col->col_min); col->col_min = col_min_max_trunc (minb); minb = NULL;
                  dk_free_tree (col->col_max); col->col_max = col_min_max_trunc (maxb); maxb = NULL;
                }
            }
          else if (key && !key->key_distinct)
            {
              col->col_n_distinct = 1;
              col->col_avg_len = 0; /* no data, use declared prec instead */
            }
        }
      dk_free_tree (minb);
      dk_free_tree (maxb);
    }
  hash_table_free (itc->itc_st.cols);
  itc->itc_st.cols = NULL;
}

void
cs_new_page (dk_hash_t * cols)
{
  DO_HT (dbe_column_t *, col, col_stat_t *, cs, cols)
    {
      id_hash_iterator_t hit;
      int64 * place;
      caddr_t * p_value;
      id_hash_iterator (&hit, cs->cs_distinct);
      while (hit_next (&hit, &p_value, (caddr_t*)&place))
	{
	  *place &= ~CS_IN_SAMPLE; 
	}
    }
  END_DO_HT;
}



void
itc_n_p_matches_in_col (it_cursor_t * itc, caddr_t * data_col, int * first, int *last)
{
  /* in column wise inx sample can hit a seg with many different values of the 1st key part.  If so, count how many there are. */
  caddr_t param = itc->itc_search_params[0];
  iri_id_t iri = DV_IRI_ID == DV_TYPE_OF (param) ? unbox_iri_id (param) : 0;
  int len = BOX_ELEMENTS (data_col);
  int inx = 0;
  for (inx = 0; inx < len; inx++)
    {
      caddr_t d = data_col[inx];
      if (IS_BOX_POINTER (d) && iri == *(iri_id_t*)d)
	{
	  *first = inx;
	  break;
	}
    }
  if (inx == len)
    {
      *last = *first = 0;
      return;
    }
  for (inx = len - 1; inx >= 0; inx--)
	{
	  caddr_t d = data_col[inx];
	  if (IS_BOX_POINTER (d) && iri == *(iri_id_t*)d)
	    {
	      *last = inx + 1;
	      break;
	    }
	  if (inx == -1)
	    *first = *last = 0;
	}
}


void
itc_row_col_stat (it_cursor_t * itc, buffer_desc_t * buf, int * is_leaf)
{
  int64 ppos;
  int n_data = 1;
  db_buf_t row = BUF_ROW (buf, itc->itc_map_pos);
  dbe_key_t * key = itc->itc_insert_key;
  key_ver_t kv = IE_KEY_VERSION (row);
  int len_limit = -1, first_match = 0;
  if (!kv ||  KV_LEFT_DUMMY == kv)
    return;
  ppos = ((int64)(itc->itc_page) << 16) | itc->itc_map_pos;
  if (!itc->itc_st.visited)
    itc->itc_st.visited = hash_table_allocate (203);
  if (gethash ((void*)ppos, itc->itc_st.visited))
    return;
  sethash ((void*)ppos, itc->itc_st.visited, (void*)1);
  if (!*is_leaf)
    {
      *is_leaf = 1;
      cs_new_page (itc->itc_st.cols);
    }
  itc->itc_row_data = row;
  itc->itc_row_key = itc->itc_insert_key->key_versions[kv];
  DO_SET (dbe_column_t *, col, &itc->itc_row_key->key_parts)
    {
      col_stat_t * col_stat;
      caddr_t * data_col = NULL;
      caddr_t data = NULL;
      dbe_column_t * current_col;
      int len, is_data = 0;
      ptrlong * place;
      dbe_col_loc_t *cl;
      if (key->key_is_col)
	cl = cl_list_find (key->key_row_var, col->col_id);
      else
	cl = key_find_cl (itc->itc_row_key, col->col_id);
      if (!cl)
	continue; /* obsolete row, new key version does not have the col */
      if (!IS_BLOB_DTP (col->col_sqt.sqt_dtp))
	{
	  if (itc->itc_insert_key->key_is_col)
	    {
	      /*if (tlsf_check (THREAD_CURRENT_THREAD->thr_tlsf, 0)) GPF_T1 ("corrupt");*/
	      data_col = itc_box_col_seg (itc, buf, cl);
	      if (col == (dbe_column_t*)itc->itc_insert_key->key_parts->data && 1 == itc->itc_search_par_fill)
		{
		itc_n_p_matches_in_col (itc, data_col, &first_match, &len_limit);
		  if (first_match == len_limit)
		    {
		      dk_free_tree ((caddr_t)data_col);
		      return;
		    }
		}
	    }
	  else  if (key->key_bit_cl && col->col_id == key->key_bit_cl->cl_col_id)
	    {
	      data_col = itc_bm_array (itc, buf);
	      WITH_TLSF (dk_base_tlsf)
		dk_check_tree (data_col);
	      END_WITH_TLSF;
	    }
	  else
	    {
	  data = itc_box_column (itc, buf, col->col_id, cl);
	      if (col == (dbe_column_t*)key->key_parts->data && 1 == itc->itc_search_par_fill && !box_equal (data, itc->itc_search_params[0]))
		{
		  dk_free_tree (data);
		return;
	    }
	    }
	  is_data = 1;
	}
      current_col = sch_id_to_column (wi_inst.wi_schema, col->col_id);
      /* can be obsolete row, use the corresponding col of the current version of the key */
      col_stat = (col_stat_t *) gethash ((void*) current_col, itc->itc_st.cols);
      if (!col_stat)
	{
	  NEW_VARZ (col_stat_t, cs);
	  sethash ((void*)current_col, itc->itc_st.cols, (void*) cs);
	  cs->cs_distinct = id_hash_allocate (1001, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
          id_hash_set_rehash_pct (cs->cs_distinct, 200);
	  col_stat = cs;
	}

      if (is_data)
	{
	  int data_inx;
	  n_data = data_col ? BOX_ELEMENTS (data_col) : 1;
	  if (-1 != len_limit)
	    n_data = MIN (BOX_ELEMENTS (data_col), len_limit);
	  for (data_inx = first_match; data_inx < n_data; data_inx++)
	    {
	      if (data_col)
		{
		  data = data_col[data_inx];
		  data_col[data_inx] = NULL;
		}
	      if (key->key_is_col && dtp_is_fixed (col->col_sqt.sqt_dtp))
		len = 4;
	      else if (cl->cl_fixed_len > 0)
	    len = cl->cl_fixed_len;
	  else
	    len = IS_BOX_POINTER (data) ? box_length (data) : 8;

	  if (DV_DB_NULL != DV_TYPE_OF (data))
	    {
	      col_stat->cs_n_values++;
	      col_stat->cs_len += len;
	    }
	  place = (ptrlong *) id_hash_get (col_stat->cs_distinct, (caddr_t) &data);
	  if (place)
	    {
		  if (!(CS_IN_SAMPLE & *place))
		    *place += CS_IN_SAMPLE | CS_SAMPLE_INC | 1;
		  else
		    (*place)++;
	      dk_free_tree (data);
	    }
	  else
	    {
	      uint64 one = CS_IN_SAMPLE | CS_SAMPLE_INC | 1;
	      id_hash_set (col_stat->cs_distinct, (caddr_t) &data, (caddr_t)&one);
	      /*if (THREAD_CURRENT_THREAD->thr_tlsf->tlsf_total_mapped < 4000000 && tlsf_check (THREAD_CURRENT_THREAD->thr_tlsf, 0)) GPF_T1 ("corrupt");*/
	    }
	}
	  if (data_col)
	    {
#ifdef DK_ALLOC_BOX_DEBUG
	      dk_check_tree_iter (data_col, NULL, NULL);
#endif
	      dk_free_tree ((caddr_t)data_col);
	      data_col = NULL;
	    }
	}
    }
  END_DO_SET();
  itc->itc_st.n_sample_rows += n_data - first_match;
}


void
itc_page_col_stat (it_cursor_t * itc, buffer_desc_t * buf)
    {
  int pos = itc->itc_map_pos;
  int is_leaf = 0;
  if (itc->itc_insert_key->key_is_col)
	{
      int r;
      static  int32 col_seed;
      if (!itc->itc_search_par_fill)
    {
	  key_ver_t kv;
	  db_buf_t row;
	  r = (sqlbif_rnd (&col_seed) & 0x7ffff) % buf->bd_content_map->pm_count;
	  row = BUF_ROW (buf, r);
	  kv= IE_KEY_VERSION (row);
	  if (KV_LEFT_DUMMY == kv)
	    {
	      if (r == buf->bd_content_map->pm_count - 1)
		return;
	      r++;
	    }
	  itc->itc_map_pos = r; /* randomize after first found, else might never hit */
#ifdef MALLOC_DEBUG
	  if (itc->itc_st.n_sample_rows < 100)
	    itc_row_col_stat (itc, buf, &is_leaf);
#else
	  itc_row_col_stat (itc, buf, &is_leaf);
#endif
    }
      else
	{
	  int init_sample = itc->itc_st.n_sample_rows;
	  for (r = itc->itc_map_pos; r < buf->bd_content_map->pm_count; r++)
	    {
	      int prev_sample = itc->itc_st.n_sample_rows;
	      itc->itc_map_pos = r; /* randomize after first found, else might never hit */
#ifdef MALLOC_DEBUG
	      if (itc->itc_st.n_sample_rows > 5)
		break;
#endif
	      itc_row_col_stat (itc, buf, &is_leaf);
	      if (itc->itc_st.n_sample_rows < 1000)
		continue;
	      if (itc->itc_st.n_sample_rows > 1000000 / key_n_partitions (itc->itc_insert_key)
		  || itc->itc_st.n_sample_rows < prev_sample + 1
		  || itc->itc_st.n_sample_rows - init_sample > 40000)
	      break;
	    }
}
}
  else
{
  DO_ROWS (buf, map_pos, row, NULL)
    {
      itc->itc_map_pos = map_pos;
	  itc_row_col_stat (itc, buf, &is_leaf);
    }
  END_DO_ROWS;
    }
  itc->itc_map_pos = pos;
}


int
itc_page_split_search_1 (it_cursor_t * it, buffer_desc_t * buf,
		       dp_addr_t * leaf_ret)
{
  db_buf_t page = buf->bd_buffer, row;
  int res;
  page_map_t *map = buf->bd_content_map;
  int below = map->pm_count;
  int at_or_above = 0;
  int guess;
  int at_or_above_res = -100;
  key_ver_t kv;
  if (PA_WRITE != it->itc_dive_mode ? buf->bd_is_write : !buf->bd_is_write)
    GPF_T1 ("split search supposed to be in read mode");
  if (map->pm_count == 0)
    {
      it->itc_map_pos = ITC_AT_END;
      *leaf_ret = 0;
      return DVC_GREATER;
    }


  for (;;)
    {
      if ((below - at_or_above) <= 1)
	{
	  if (at_or_above_res == -100)
	    {
	      at_or_above_res = pg_key_compare (buf, at_or_above, it);
	    }
	  switch (at_or_above_res)
	    {
	    case DVC_MATCH:
	    case DVC_LESS:
	      {
                row = page + map->pm_entries[at_or_above];
                it->itc_map_pos = at_or_above;
                kv = IE_KEY_VERSION (row);
                if (KV_LEAF_PTR == kv)
                  *leaf_ret = LONG_REF (row + it->itc_insert_key->key_key_leaf[IE_ROW_VERSION (row)]);
                else if (KV_LEFT_DUMMY == kv)
                  *leaf_ret = LONG_REF (row + LD_LEAF);
                else
                  *leaf_ret = 0;
                return at_or_above_res;
	      }
	    case DVC_GREATER:
	      {
		/* The lower limit, 0 was greater. No way down. */
		it->itc_map_pos = at_or_above;
		*leaf_ret = 0;
		return DVC_GREATER;
	      }
	    }
	}
      /* OK, we have an interval to search */
      guess = at_or_above + ((below - at_or_above) / 2);
      res = pg_key_compare (buf, guess, it);
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
  db_buf_t page = buf->bd_buffer, row;
  page_map_t * pm = buf->bd_content_map;
  int nth;
  key_ver_t kv;
  dp_addr_t leaf;
  if (pm->pm_count )
    nth = (uint32)sqlbif_rnd (&inx_rnd_seed) % pm->pm_count;
  else
    {
      log_error ("itc_sample: should not get pages with 0 entries in pm");
      *leaf_ret = 0;
      return DVC_INDEX_END;
    }
  row = page + pm->pm_entries[nth];
  kv = IE_KEY_VERSION (row);
  if (KV_LEAF_PTR == kv)
    leaf = LONG_REF (row + itc->itc_insert_key->key_key_leaf[IE_ROW_VERSION (row)]);
  else if (KV_LEFT_DUMMY == kv)
    leaf = LONG_REF (row + LD_LEAF);
  else
    leaf = 0;
  *leaf_ret =  leaf;
  itc->itc_map_pos = 0;
  return DVC_MATCH;
}


int
itc_matches_on_page (it_cursor_t * itc, buffer_desc_t * buf, int * leaf_ctr_ret, int * rows_per_bm, dp_addr_t * alt_leaf_ret, int angle,
		     int * ends_with_match)
{
  int is_col = itc->itc_insert_key->key_is_col;
  page_map_t * pm = buf->bd_content_map;
  dp_addr_t leaves[PAGE_DATA_SZ / 8];
  int leaf_fill = 0;
  db_buf_t page = buf->bd_buffer;
  int have_left_leaf = 0, was_left_leaf = 0;
  int pos = itc->itc_map_pos; /* itc is at leftmost match. Nothing at left of the itc */
  int save_pos = itc->itc_map_pos;
  int ctr = 0, leaf_ctr = 0, row_ctr = 0, first_row = -1, row_match_ctr = 0;
  *ends_with_match = 0;
  for (pos = pos; pos < pm->pm_count; pos++)
    {
      int res = DVC_MATCH;
      db_buf_t row = page + pm->pm_entries[pos];
      search_spec_t * sp = itc->itc_key_spec.ksp_spec_array;
      key_ver_t r_kv = IE_KEY_VERSION (row);
      itc->itc_row_data = row;
      if (KV_LEFT_DUMMY == r_kv)
	{
	  if (LONG_REF (row + LD_LEAF))
	    {
	      was_left_leaf = have_left_leaf = 1;
	      leaves[leaf_fill++] = LONG_REF (row + LD_LEAF);
	      leaf_ctr++;
	      if (leaf_fill > 1000) bing ();
	    }
	}
      else
	{
	  if (r_kv)
	    itc->itc_row_key = itc->itc_insert_key->key_versions[r_kv];
	  if (itc->itc_geo_op)
	    {
	      res = cmpf_geo (buf, pos, itc);
	    }
	  else 
	    {
	      while (sp)
		{
		  if (DVC_MATCH != (res = itc_compare_spec (itc, buf, key_find_cl (itc->itc_row_key, sp->sp_cl.cl_col_id), sp)))
		    break;
		  sp = sp->sp_next;
		}
	    }
	  if (DVC_GREATER == res)
	    break;
	  if (!r_kv && (!itc->itc_geo_op  || DVC_MATCH == res))
	    {
	      dp_addr_t leaf1 = LONG_REF (row + itc->itc_insert_key->key_key_leaf[IE_ROW_VERSION (row)]);
	      leaves[leaf_fill++] = leaf1;
	      if (leaf_fill > 1000) bing ();
	      if (have_left_leaf)
		{
		  /* prefer giving the next to leftmost instead of leftmost leaf if leftmost is left dummy.
		   * The leftmost branch can be empty because the leaf with the left dummy never can get deleted */
		  *alt_leaf_ret = leaf1;
		  have_left_leaf = 0;
		}
	      leaf_ctr++;
	    }

	  if (DVC_MATCH == res || is_col)
	    {
	      if (r_kv)
		{
		  if (-1 == first_row)
		    first_row = pos;
		  row_ctr++;
		  if (itc->itc_insert_key->key_is_bitmap)
		    {
		      int n_bits;
		      itc->itc_map_pos = pos;
		      n_bits = itc_bm_count (itc, buf);
		      ctr += n_bits;
		      row_match_ctr += n_bits * (DVC_MATCH == itc_sample_row_check (itc, buf));
		      itc->itc_map_pos = save_pos;
		    }
		  else if (is_col)
		    {
		      save_pos = itc->itc_map_pos;
		      itc->itc_map_pos = pos;
		      ctr += itc_col_count (itc, buf, &row_match_ctr);
		      itc->itc_map_pos = save_pos;
		}
	      else
		{
		      ctr++;
		      row_match_ctr += DVC_MATCH == itc_sample_row_check (itc, buf);
		    }
		}
	    }
	}
      if (pos == pm->pm_count - 1)
	*ends_with_match = 1;
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
  else if (itc->itc_geo_op && -1 == angle)
    {
      *alt_leaf_ret = leaf_ctr ? leaves[0] : 0;
    }
  if (ITC_STAT_ANGLE == itc->itc_st.mode && -1 != first_row)
    {
      itc->itc_map_pos = first_row + ((row_ctr * angle) / 1000);
    }
      else
    itc->itc_map_pos = save_pos;
  if (itc->itc_map_pos >= buf->bd_content_map->pm_count)
    {
      bing ();
    }
  if (is_col)
    itc->itc_st.n_rows_sampled = itc->itc_st.rows_in_segs;
  else
    itc->itc_st.n_rows_sampled += ctr;

  itc->itc_st.n_row_spec_matches += row_match_ctr;
  return ctr;
}

int
itc_sample_next (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  /* if landed at end of a page with the hits starting on the next, go one forward */
  int rc;
  itc_try_land (itc, buf_ret);
  if (!itc->itc_landed)
    return -1;
  itc->itc_is_on_row = 1;
  itc->itc_map_pos = (*buf_ret)->bd_content_map->pm_count - 1;
  if (itc->itc_insert_key->key_is_bitmap)
    itc->itc_bp.bp_value = BITNO_MAX;
  ITC_SAVE_ROW_SPECS (itc);
  ITC_NO_ROW_SPECS (itc);
  if (itc->itc_is_col)
    {
      itc->itc_is_col = 0;
      rc = itc_next (itc, buf_ret);
      itc->itc_is_col = 1;
    }
  else 
    rc =  itc_next (itc, buf_ret);
  ITC_RESTORE_ROW_SPECS (itc);
  return rc;
}


int64
itc_sample_1 (it_cursor_t * it, buffer_desc_t ** buf_ret, int64 * n_leaves_ret, int angle)
{
  int is_col = it->itc_insert_key->key_is_col;
  dp_addr_t leaf, rnd_leaf;
  int res, res2, old_rnd, any_leaf_match = 0;
  int level = 0;
  int level_of_single_leaf_match = -1;
  int ctr  = 0, leaf_ctr = 0, rows_per_bm, ends_with_match;
  int64 leaf_estimate = 0;

  if (angle > 980)
    angle = 980;
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
  else if (it->itc_geo_op)
    {
      it->itc_map_pos = 0;
      res = DVC_MATCH;
    }
  else
    res = itc_page_split_search_1 (it, *buf_ret, &leaf);
 make_est:
  if (it->itc_st.cols)
    itc_page_col_stat (it, *buf_ret);
  ctr = itc_matches_on_page (it, *buf_ret, &leaf_ctr, &rows_per_bm, &leaf, angle, &ends_with_match);
  if (level < RA_MAX_ROOTS)
    it->itc_ra_root[level] = leaf_ctr + ctr;
  if (leaf_ctr)
    {
      any_leaf_match = 1;
      if (1 == leaf_ctr && -1 == level_of_single_leaf_match && !leaf_estimate)
	level_of_single_leaf_match = level;
    }
  if (leaf_estimate)
    leaf_estimate = (((float)leaf_estimate) - 0.5) * (*buf_ret)->bd_content_map->pm_count * rows_per_bm + leaf_ctr;
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
	    /* Go down on the left edge. */
	    level++;
	    itc_down_transit (it, buf_ret, leaf);
	    if (it->itc_write_waits > 1000 || (it->itc_read_waits % 10000) >= 1000) /*10000 is the increment for a disk read, do not count this here */
	      goto reset;
	    else
	      goto start;
	  }
	if (ITC_STAT_ANGLE == it->itc_st.mode)
	  break;
	if (DVC_LESS == res && 0 == ctr && it->itc_map_pos == (*buf_ret)->bd_content_map->pm_count - 1 && any_leaf_match)
	  {
	    res2 = itc_sample_next (it, buf_ret);
	    if (-1 == res2)
	      goto reset;
	    if (DVC_MATCH != res2)
		  break;
	    res = DVC_INDEX_END;
	    goto make_est;
	  }
	else if (ends_with_match && it->itc_search_par_fill)
	  {
	    /* the landing page ends with matches, see about next page */
	    res2 = itc_sample_next (it, buf_ret);
	    if (-1 == res2)
	      goto reset;
	    if (DVC_MATCH != res2)
	      break;
	    ctr = ctr + itc_matches_on_page (it, *buf_ret, &leaf_ctr, &rows_per_bm, &leaf, angle, &ends_with_match);
	    if (!ends_with_match)
	      {
		if (n_leaves_ret)
		  *n_leaves_ret = 0;
		return ctr; /* got exact count, all within 2 adjacent pages */
	      }
	    break;
	  }
	else if (!ends_with_match && it->itc_search_par_fill && -1 == angle)
	  {
	    /* if the page does not end with match and we have conditions and this is the leftmost page of matches (angle == -1), then the matches on this page are all there is */
	    if (n_leaves_ret)
	      *n_leaves_ret = 0;
	    return ctr;
	  }
	else
	  break;
	/* if the cursor had a wait, a reset or any such thing, the path from top to bottom is not the normal one and the sample must be discarded */
      reset:
	old_rnd = it->itc_random_search;
	itc_page_leave (it, *buf_ret);
	it->itc_random_search = RANDOM_SEARCH_ON; /* disable use of root cache by itc_reset */
	level = 0;
	level_of_single_leaf_match = -1;
	*buf_ret = itc_reset (it);
	it->itc_random_search = old_rnd;
	it->itc_read_waits = 0;
	it->itc_write_waits = 0;
	TC (tc_key_sample_reset);
	ctr = leaf_ctr = leaf_estimate = 0;
	goto start;
      }
    case DVC_GREATER:
    case DVC_INDEX_END:
      {
	break;
      }
    }
  if (!leaf_estimate && -1 != level_of_single_leaf_match
      && level > level_of_single_leaf_match  - 1)
    leaf_estimate = ctr; /* if seen a leaf ptr with a match up in the tree, guess that there is at least as many down that branch.  Come back to look later */
  if (n_leaves_ret)
    *n_leaves_ret = leaf_estimate;
  if (is_col)
    {
      dbe_key_t * key = it->itc_insert_key;
      if (key->key_rows_in_sampled_segs < 20000000)
	{
	  key->key_rows_in_sampled_segs += it->itc_st.rows_in_segs;
	  key->key_segs_sampled += it->itc_st.segs_sampled;
	}
    }
  if (it->itc_map_pos >= (*buf_ret)->bd_content_map->pm_count)
    it->itc_map_pos = (*buf_ret)->bd_content_map->pm_count - 1;
  if (it->itc_geo_op)
    {
      /* for a geo sample, the estimate is the product of the counts on different levels.  If no match on leaf but matches higher up, return 0 but set leaf ctr so will look in other branches */
      int inx;
      leaf_estimate = 1;
      level = MIN (level, RA_MAX_ROOTS);
      for (inx = 0; inx <= level; inx++)
	{
	  int l = it->itc_ra_root[inx];
	  if (0 == l)
	    {
	      *n_leaves_ret = 1 == leaf_estimate ? 0 : leaf_estimate;
	      return 0;
	    }
	  if (inx == level)
	    *n_leaves_ret = leaf_estimate;
	  leaf_estimate *= l;
	}
      return leaf_estimate;
    }
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
int dbf_max_itc_samples = MAX_SAMPLES;
#define SAMPLES_LIMIT (MIN (MAX_SAMPLES, dbf_max_itc_samples))

int64
itc_local_sample (it_cursor_t * itc)
{
  int64 res;
  buffer_desc_t * buf;
  float mean, stddev;
  int64 samples[MAX_SAMPLES];
  int64 n_leaves, sample, tb_count;
  dbe_key_t * key = itc->itc_insert_key;
  dbe_table_t * tb = key->key_table;
  int n_samples, max_samples = key->key_partition && key->key_partition->kpd_map->clm_is_elastic ? 3 : MAX_SAMPLES;
  max_samples = MIN (max_samples, dbf_max_itc_samples);
  itc->itc_st.n_rows_sampled = 0;
  itc->itc_st.n_row_spec_matches = 0;
  n_samples = 1;
  itc->itc_random_search = RANDOM_SEARCH_ON;
  itc->itc_dive_mode = PA_READ_ONLY;
  buf = itc_reset (itc);
  if (itc->itc_insert_key->key_is_geo)
    {
      dbe_table_t * tb = itc->itc_insert_key->key_table;
      double ar = geo_page_area (itc, buf);
      tb->tb_geo_area = MAX (tb->tb_geo_area, ar);
    }
  if (!itc->itc_key_spec.ksp_spec_array && !itc->itc_geo_op)
    {
      res = itc_sample_1 (itc, &buf, &n_leaves, -1);
      itc_page_leave (itc, buf);
      if (n_leaves < 2 || 1 == dbf_max_itc_samples)
	goto return_res;
      if (itc->itc_row_specs)
	{
	  float row_sel =  itc_row_selectivity (itc, res);
	  if (row_sel > 0.1 && row_sel < 0.9)
	    goto return_res;
	}
      else
	max_samples = MIN (max_samples, 5);
      samples[0] = res;
      goto regular;
    }
  itc->itc_random_search = RANDOM_SEARCH_OFF;
  samples[0] = itc_sample_1 (itc, &buf, &n_leaves, -1);
  itc_page_leave (itc, buf);

  if (!n_leaves)
    {
      res =  samples[0];
      goto return_res;
    }
  regular:
  {
    int angle, step = 248, offset = 5;
    for (;;)
      {
	for (angle = step + offset; angle < 1000; angle += step)
	  {
	    itc->itc_random_search = RANDOM_SEARCH_ON;
	    buf = itc_reset (itc);
	    itc->itc_random_search = RANDOM_SEARCH_OFF;
	    sample = itc_sample_1 (itc, &buf, &n_leaves, angle);
	    itc_page_leave (itc, buf);
	    tb_count = tb->tb_count == DBE_NO_STAT_DATA ? tb->tb_count_estimate : tb->tb_count;
	    tb_count = MAX (tb_count, 1);
	    if (sample < 0 || sample > tb_count)
	      sample = (tb_count * 3) / 4;
	    samples[n_samples++] = sample;
	    if (n_samples >= max_samples)
	      break;
	  }
	samples_stddev (samples, n_samples, &mean, &stddev);
	if (n_samples >  MAX (3, max_samples - 2) || stddev < mean / 3)
	  break;
	offset += step / 5;
	step /= 2;
      }
  }
  if (CL_RUN_SINGLE_CLUSTER == cl_run_local_only && itc->itc_insert_key->key_partition && itc->itc_insert_key->key_partition->kpd_map != clm_replicated)
    mean *= key_n_partitions (itc->itc_insert_key);
  res = ((int64) mean);
 return_res:
  if (itc->itc_st.visited)
    {
      hash_table_free (itc->itc_st.visited);
      itc->itc_st.visited = NULL;
    }
  return res;
}

int enable_exact_p_stat = 0;


int64
itc_sample (it_cursor_t * itc)
{
  int inx;
  itc->itc_n_sets = 0;
  for (inx = 0; inx < itc->itc_search_par_fill; inx++)
    if (DV_DB_NULL == DV_TYPE_OF (itc->itc_search_params[inx]))
      return 0;
  if (enable_exact_p_stat && 1 == itc->itc_search_par_fill && tb_is_rdf_quad (itc->itc_insert_key->key_table) && CL_RUN_SINGLE_CLUSTER != cl_run_local_only
      && 'P' == toupper (((dbe_column_t *)itc->itc_insert_key->key_parts->data)->col_name[0])
      && itc->itc_st.cols)
    {
      int64 res = sqlo_p_stat_query (itc->itc_insert_key->key_table, itc->itc_search_params[0]);
      if (-1 != res)
	{
	  itc->itc_st.cols = (dk_hash_t *) - 1;
	  return res;
	}
    }

    {

      if (itc->itc_insert_key->key_is_elastic && !itc->itc_tree)
	return -1;
    return itc_local_sample (itc);
}
}


unsigned int64
key_count_estimate_slice  (dbe_key_t * key, int n_samples, int upd_col_stats, slice_id_t slice)
{
  int64 res = 0, sample;
  int n;
  int max_samples = (key->key_is_col ? 10 : 100);
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  ITC_INIT (itc, key->key_fragments[0]->kf_it, NULL);
  itc_clear_stats (itc);
  QR_RESET_CTX
    {
      if (!key->key_is_elastic || CL_RUN_CLUSTER != cl_run_local_only)
	itc_from (itc, key, slice);
      else
	itc_from_any_slice (itc, key);
    }
  QR_RESET_CODE
    {
      POP_QR_RESET;
      itc_free (itc);
      return 0;
    }
  END_QR_RESET;
  itc->itc_random_search = RANDOM_SEARCH_ON;
  if (upd_col_stats)
    itc->itc_st.cols = hash_table_allocate (23);
  for (n = 0; n < n_samples; n++)
    {
      itc->itc_random_search = RANDOM_SEARCH_ON; /* disable use of root cache by itc_reset */
      sample = itc_sample (itc);
      if (sample < 0 || sample > 1e12)
	sample = 100000000; /* arbitrary.  If tree badly skewed will return nonsense figures */
      res += sample;
      if (RWG_WAIT_ANY == itc->itc_to_reset)
	{
	  /* error cond like cluster timeout.  Must finish without timing out for each loop */
	  n_samples = n + 1;
	  break;
	}
      if (upd_col_stats)
	{
	  if (0 == n && sample == itc->itc_st.n_sample_rows)
	    {
	      /* short table, all seen on one go */
	      n_samples = 1;
	      break;
	    }
	  /* if doing cols also, adjust the sample to table size */
	  if (n_samples < max_samples && itc->itc_st.n_sample_rows < 0.01 * res / (n + 1))
	    n_samples++;
	}
    }
  if (upd_col_stats)
    itc_col_stat_free (itc, 1, res / n_samples);
  return res / n_samples;
}


unsigned int64
key_count_estimate  (dbe_key_t * key, int n_samples, int upd_col_stats)
{
  float n_local = 0;
  uint64 est = 0;
  if (CL_RUN_SINGLE_CLUSTER  == cl_run_local_only && key->key_is_elastic)
    {
      DO_LOCAL_CSL (csl, key->key_partition->kpd_map)
	{
	  int64 n = key_count_estimate_slice (key, n_samples, upd_col_stats, csl->csl_id);
	  if (n)
	    {
	      n_local++;
	      est += n;
	    }
	}
      END_DO_LOCAL_CSL;
    }
  else
    {
      n_local = 1;
      est =  key_count_estimate_slice (key, n_samples, upd_col_stats, QI_NO_SLICE);
    }
  if (0 == n_local)
    return 1000;
  if (CL_RUN_SINGLE_CLUSTER == cl_run_local_only)
    est *= key_n_partitions (key) / MAX (1, n_local);
  return est;
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
  itc_from (itc, key, QI_NO_SLICE);
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
	  id = (int) (ptrlong) itc_box_column (itc, buf, twobyte_col->col_id, NULL);
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


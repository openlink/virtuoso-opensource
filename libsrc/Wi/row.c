/*
 *  row.c
 *
 *  $Id$
 *
 *  Row Operations.
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

#include "sqlnode.h"
#include "sqlfn.h"
#include "lisprdr.h"
#include "date.h"
#include "datesupp.h"
#include "multibyte.h"
#include "srvmultibyte.h"
#include "bif_xper.h"		/* IvAn/DvBlobXper/001212 Include added */
#include "sqltype.h"
#include "xmltree.h"
#include "xml.h"
#include "sqlbif.h"
#include "security.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "xmlparser_impl.h"
#ifdef __cplusplus
}
#endif



char* __get_column_name (oid_t col_id, dbe_key_t *key);
const char * dv_type_title (int type);

dbe_key_t *
itc_get_row_key (it_cursor_t * itc, buffer_desc_t * buf)
{
  key_ver_t kv = IE_KEY_VERSION (buf->bd_buffer + buf->bd_content_map->pm_entries [itc->itc_map_pos]);
  dbe_key_t * key = buf->bd_tree->it_key;
  return key->key_versions[kv];
}


dbe_col_loc_t *
cl_list_find (dbe_col_loc_t * cl, oid_t col_id)
{
  int inx;
  for (inx = 0; cl[inx].cl_col_id; inx++)
    if (cl[inx].cl_col_id == col_id)
      return (cl+inx);
  return NULL;
}


dbe_col_loc_t *
key_find_cl (dbe_key_t * key, oid_t col)
{
  dbe_col_loc_t * cl = cl_list_find (key->key_key_fixed, col);
  if (cl)
    return cl;
  cl = cl_list_find (key->key_key_var, col);
  if (cl)
    return cl;
  cl = cl_list_find (key->key_row_fixed, col);
  if (cl)
    return cl;
  cl = cl_list_find (key->key_row_var, col);
  if (cl)
    return cl;
  return NULL;
}


dbe_col_loc_t *
itc_col_loc (it_cursor_t * itc, buffer_desc_t * buf, oid_t col_id)
{
  dbe_key_t * key = itc->itc_insert_key;
  db_buf_t row = BUF_ROW (buf, itc->itc_map_pos);
  key_ver_t kv = IE_KEY_VERSION (row);
  dbe_col_loc_t * cl;
  key = key->key_versions[kv];
  cl = key_find_cl (key, col_id);
  return cl;
}


long
itc_long_column (it_cursor_t * itc, buffer_desc_t * buf, oid_t col)
{
  boxint n;
  dtp_t dtp;
  dbe_col_loc_t * cl = itc_col_loc (itc, buf, col);
  caddr_t box;
  if (!cl)
    return 0;
  box = itc_box_column (itc, buf, 0, cl);
  dtp = DV_TYPE_OF (box);
  if (DV_DB_NULL == dtp)
    return 0;
  else if (DV_LONG_INT == dtp)
    {
      n = unbox (box);
      dk_free_box (box);
      return n;
    }
  return 0;
}


caddr_t
itc_box_row (it_cursor_t * itc, buffer_desc_t * buf)
{
  /* return array with key id leading and a copy of each col in layout order */
  int inx = 1;
  dbe_key_t * key = itc->itc_insert_key;
  caddr_t * res;
  db_buf_t row = BUF_ROW (buf, itc->itc_map_pos);
  key_ver_t kv = IE_KEY_VERSION (row);
  key = key->key_versions[kv];
  res = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * (1 + dk_set_length (key->key_parts)), DV_ARRAY_OF_POINTER);
  res[0] = box_num (key->key_id);
  DO_ALL_CL (cl, key)
    {
      res[inx] = page_copy_col (buf, row, cl, NULL);
      inx++;
    }
  END_DO_ALL_CL;
  return (caddr_t) res;
}


caddr_t
blob_ref_check (db_buf_t xx, int len, it_cursor_t * itc, dtp_t col_dtp)
{
  int is_col_blob = DV_COL_BLOB_SERIAL == xx[0];
  if (IS_BLOB_DTP (*xx) || is_col_blob)
    {
      blob_handle_t * bh;
      bh = bh_from_dv (xx, itc);
      if (is_col_blob)
	box_tag_modify (bh, DV_BLOB_HANDLE_DTP_FOR_BLOB_DTP (col_dtp));
      blob_check (bh);
      return ((caddr_t) bh);
    }
  else if (DV_LONG_STRING == *xx)
    {
      caddr_t box;
      /* the length is data + 1 since includes the tag byte in front */
      if (col_dtp != DV_BLOB_BIN)
	{
	  box = dk_alloc_box (len, DV_LONG_STRING);
	  memcpy (box, xx + 1, len - 1);
	  box[len - 1] = 0;
	}
      else
	{
	  box = dk_alloc_box (len - 1, DV_BIN);
	  memcpy (box, xx + 1, len - 1);
	}
      return box;
    }
  else if (DV_LONG_WIDE == *xx || DV_WIDE == *xx)
    {
      return box_utf8_as_wide_char ((caddr_t) xx + 1, NULL, len - 1, 0, DV_LONG_WIDE);
    }
  else if (DV_BIN == *xx)
    { /* GK: from hash fill (hash_cast in specific */
      caddr_t str = dk_alloc_box ((int) len - 1, DV_BIN);
      memcpy (str, xx + 1, (int) len - 1);
      return str;
    }
  else
    GPF_T1 ("place code for returning dv string for inlined blob here.");
  return NULL;
}


caddr_t
itc_box_base_uri_column_impl (it_cursor_t * itc, dbe_key_t * key, dtp_t *row, oid_t xml_col_id)
{
  return NULL;
#ifndef KEYCOMP
  dbe_table_t *tb = key->key_table;
  dbe_column_t *xml_col = NULL;
  caddr_t base_uri_col_name;
  dbe_column_t *base_uri_col;
  caddr_t local_uri;
  /* This is a dirty hack to prevent nested selects with XML columns in the inner result from crashes. */
  if (NULL == tb)
    return NULL;
  DO_SET (dbe_column_t *, col, &tb->tb_primary_key->key_parts)
    {
      if (col->col_id == xml_col_id)
        {
          xml_col = col;
          break;
        }
    }
  END_DO_SET();
  base_uri_col_name = xml_col->col_xml_base_uri;
  if (NULL == base_uri_col_name)
    return NULL;
  base_uri_col = tb_name_to_column (tb, base_uri_col_name);
  if (NULL == base_uri_col)
    return NULL;
  else
    {
      dbe_col_loc_t * base_uri_cl = key_find_cl (key, base_uri_col->col_id);
      int len, off;
      if (ITC_NULL_CK (itc, (*base_uri_cl)))
        return NULL;
     ITC_COL (itc, (*base_uri_cl), off, len);
      switch (base_uri_cl->cl_sqt.sqt_dtp)
        {
        case DV_ANY:
          if (!len)
            return NULL;
          local_uri = box_deserialize_string ((char *)(row + off), len);
          break;
        case DV_STRING:
          local_uri = box_dv_short_nchars ((char *)(row + off), len);
          break;
        default:
          return NULL;
        }
    }
  if (DV_STRING == DV_TYPE_OF (local_uri))
    {
      caddr_t res = dk_alloc_box (11 + strlen (tb->tb_name) + strlen (xml_col->col_name) + strlen (local_uri) + strlen (base_uri_col->col_name), DV_STRING);
      /*            |0              1   */
      /*            |1234567..8..9..0..1*/
      snprintf (res, box_length (res),
	  "virt://%s.%s.%s:%s", tb->tb_name, base_uri_col->col_name, xml_col->col_name, local_uri);
      dk_free_box (local_uri);
      return res;
    }
  dk_free_tree (local_uri);
  return NULL;
#endif
}


caddr_t
itc_box_base_uri_column (it_cursor_t * itc, db_buf_t page, oid_t xml_col_id)
{
#ifndef  KEYCOMP
  dbe_key_t * key = itc->itc_insert_key;
  return itc_box_base_uri_column_impl (itc, key, page + itc->itc_position + IE_FIRST_KEY, xml_col_id);
#endif
  return NULL;
}




caddr_t
itc_box_column (it_cursor_t * itc, buffer_desc_t *buf, oid_t col, dbe_col_loc_t * cl)
{
  if (!cl)
	cl = itc_col_loc (itc, buf, col);
  if (!cl)
    return (dk_alloc_box (0, DV_DB_NULL));
  if (!buf->bd_content_map)
    return page_box_col (itc, buf, itc->itc_row_data, cl); /* can be hash temp */
  return page_box_col (itc, buf, buf->bd_buffer + buf->bd_content_map->pm_entries[itc->itc_map_pos], cl);
}


caddr_t
itc_mp_box_column (it_cursor_t * itc, mem_pool_t * mp, buffer_desc_t *buf, oid_t col, dbe_col_loc_t * cl)
{
  if (!cl)
	cl = itc_col_loc (itc, buf, col);
  if (!cl)
    return (mp_alloc_box (mp, 0, DV_DB_NULL));
  return page_mp_box_col (itc, mp, buf, buf->bd_buffer + buf->bd_content_map->pm_entries[itc->itc_map_pos], cl);
}


#define FXL (cl->cl_fixed_len)

#define FX \
  ROW_FIXED_COL (buf, row, rv, (*cl), xx)

#define VL \
  ROW_STR_COL (buf->bd_tree->it_key->key_versions[IE_KEY_VERSION (row)], buf, row, cl, xx, vl1, xx2, vl2, offset); \
  len = vl1


/* with a hash temp, there is no it_key cause the key may be gone with the query that made the hash creep */
#define VLI \
{ \
  dbe_key_t * key = buf->bd_tree->it_key ? buf->bd_tree->it_key : it->itc_row_key; \
  ROW_STR_COL (key->key_versions[IE_KEY_VERSION (row)], buf, row, cl, xx, vl1, xx2, vl2, offset); \
  len = vl1; \
}

caddr_t
page_box_col (it_cursor_t * itc, buffer_desc_t * buf, db_buf_t row, dbe_col_loc_t * cl)
{
  int len;
  int64 ln;
  caddr_t str;
  unsigned short vl1, vl2, offset;
  row_ver_t rv = IE_ROW_VERSION (row);
  dbe_key_t * row_key = buf->bd_tree->it_key->key_versions[IE_KEY_VERSION (row)];
  db_buf_t xx, xx2;
  dtp_t col_dtp;
  if (row[cl->cl_null_flag[rv]] & cl->cl_null_mask[rv])
    return (dk_alloc_box (0, DV_DB_NULL));

  if (itc && cl == row_key->key_bit_cl && !itc->itc_no_bitmap)
    {
      /* the current bm inx col value is in the itc */
      if (DV_LONG_INT == itc->itc_row_key->key_bit_cl->cl_sqt.sqt_dtp
	  || DV_INT64 == itc->itc_row_key->key_bit_cl->cl_sqt.sqt_dtp)
	return box_num (itc->itc_bp.bp_value);
      else
	return box_iri_id (itc->itc_bp.bp_value);
    }
  col_dtp = cl->cl_sqt.sqt_dtp;
  switch (col_dtp)
    {
    case DV_SHORT_INT:
      len = SHORT_REF (row + cl->cl_pos[rv]);
      return (box_num (len));
    case DV_LONG_INT:
      ROW_INT_COL (buf, row, rv, *cl, LONG_REF, len);
      return (box_num (len));
    case DV_INT64:
            ROW_INT_COL (buf, row, rv, *cl, INT64_REF, ln);
      return (box_num (ln));

    case DV_IRI_ID:
      ROW_INT_COL (buf, row, rv, *cl, LONG_REF, len);
      return box_iri_id ((unsigned long) len);
    case DV_IRI_ID_8:
      ROW_INT_COL (buf, row, rv, *cl, INT64_REF, ln);
      return box_iri_id (ln);
    case DV_OBJECT:
    case DV_ANY:
      VL;
      if (len)
	return (box_deserialize_string ((char *)(xx), len, offset));
      else
	return (box_num (0));
    case DV_STRING:
      VL;
      str = dk_alloc_box ((int) len + vl2 + 1, DV_LONG_STRING);
      memcpy (str, xx, len);
      if (vl2)
      memcpy (str + len, xx2, vl2);
      str[len + vl2 - 1] += offset;
      str[len + vl2] = 0;
      return str;

    case DV_WIDE:
    case DV_LONG_WIDE:
      {
	VL;
	return box_utf8_as_wide_char ((caddr_t) xx, NULL, len, 0, DV_LONG_WIDE);
      }
    case DV_SINGLE_FLOAT:
      FX;
      str = dk_alloc_box (sizeof (float), DV_SINGLE_FLOAT);
      EXT_TO_FLOAT (str, xx);
      return str;
    case DV_DOUBLE_FLOAT:
      FX;
      str = dk_alloc_box (sizeof (double), DV_DOUBLE_FLOAT);
      EXT_TO_DOUBLE (str, xx);
      return str;
    case DV_NUMERIC:
      FX;
      {
	numeric_t num = numeric_allocate ();
	numeric_from_buf (num, xx);
	return ((caddr_t) num);
      }
    case DV_BIN:
    case DV_LONG_BIN:
      {
	VL;
	str = dk_alloc_box ((int) len + vl2, DV_BIN);
	memcpy (str, xx, (int) len);
	memcpy (str + len, xx2, (int) vl2);
	return str;
      }

    case DV_COMPOSITE:
      {
	O12;
	VL;
	str = dk_alloc_box ((int) len + 2, DV_COMPOSITE);
	memcpy (str, xx + 2, (int) len);
	str[0] = (char)(DV_COMPOSITE);
	str[1] = (char)(len);
	return str;
      }

    case DV_BLOB:
      VL;
      {
	caddr_t bh = blob_ref_check (xx, len, itc, col_dtp);
#ifdef BIF_XML
	if (DV_BLOB_XPER_HANDLE == DV_TYPE_OF (bh))
	  {
	    query_instance_t *qi = (query_instance_t *)(itc->itc_out_state);
	    caddr_t val = (caddr_t) xper_entity (qi, bh, NULL, 0, itc_box_base_uri_column (itc, buf->bd_buffer, cl->cl_col_id), NULL /* no enc */, &lh__xany, NULL /* DTD config */, 1);
	    dk_free_box (bh);
	    return val;
	  }
#endif
	if (cl->cl_sqt.sqt_class)
	  {
	    caddr_t res = udt_deserialize_from_blob (bh, itc->itc_ltrx);
	    dk_free_box (bh);
	    return res;
	  }
	if (cl->cl_sqt.sqt_is_xml && itc->itc_out_state)
	  {
	    caddr_t res = xml_deserialize_from_blob (bh, itc->itc_ltrx, itc->itc_out_state, itc_box_base_uri_column (itc, buf->bd_buffer, cl->cl_col_id));
	    dk_free_box (bh);
	    return res;
	  }
	return bh;
      }
    case DV_BLOB_BIN:
    case DV_BLOB_WIDE:
      VL;
      return (blob_ref_check (xx, len, itc, col_dtp));
#ifdef BIF_XML
    case DV_BLOB_XPER:
      VL;
      {
	caddr_t bh = blob_ref_check (xx, len, itc, col_dtp);
        query_instance_t *qi = (query_instance_t *)(itc->itc_out_state);
	caddr_t val = (caddr_t) xper_entity (NULL, bh, NULL, 0, itc_box_base_uri_column (itc, buf->bd_buffer, cl->cl_col_id), NULL /* no enc */, &lh__xany, NULL /* DTD config */, 1);
	dk_free_box (bh);
	return val;
      }
#endif
    case DV_DATETIME:
    case DV_TIMESTAMP:
    case DV_DATE:
    case DV_TIME:
      FX;
      {
	caddr_t res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
	memcpy (res, xx, DT_LENGTH);
	return res;
      }
    case DV_ARRAY_OF_FLOAT:
      VL;
      {
	int inx;
	caddr_t res;
	res = dk_alloc_box (len, cl->cl_sqt.sqt_dtp);
	for (inx = 0; inx < len; inx += 4)
	  ((int32*) res)[inx / 4] = LONG_REF (xx + inx);
	return res;
      }
    case DV_ARRAY_OF_LONG:
      VL;
      {
	int inx;
	caddr_t res;
	res = dk_alloc_box (len / sizeof (int32) * sizeof (ptrlong), cl->cl_sqt.sqt_dtp);
	for (inx = 0; inx < len; inx += 4)
	  ((ptrlong*) res)[inx / 4] = LONG_REF (xx + inx);
	return res;
      }
    case DV_ARRAY_OF_DOUBLE:
      VL;
      {
	int inx;
	caddr_t res;
	res = dk_alloc_box (len, DV_ARRAY_OF_DOUBLE);
	for (inx = 0; inx < len; inx += 8)
	  {
	    EXT_TO_DOUBLE ((res + inx), (xx + inx));
	  }
	return res;
      }
    default:
      GPF_T;			/* Bad column type */
    }
  return NULL;			/*dummy */
}


caddr_t
page_mp_box_col (it_cursor_t * itc, mem_pool_t * mp, buffer_desc_t * buf, db_buf_t row, dbe_col_loc_t * cl)
{
  int len;
  int64 ln;
  caddr_t str;
  unsigned short vl1, vl2, offset;
  row_ver_t rv = IE_ROW_VERSION (row);
  dbe_key_t * row_key = buf->bd_tree->it_key->key_versions[IE_KEY_VERSION (row)];
  db_buf_t xx, xx2;
  if (row[cl->cl_null_flag[rv]] & cl->cl_null_mask[rv])
    return (mp_alloc_box (mp, 0, DV_DB_NULL));

  if (itc && cl == row_key->key_bit_cl && !itc->itc_no_bitmap)
    {
      /* the current bm inx col value is in the itc */
      if (DV_LONG_INT == itc->itc_row_key->key_bit_cl->cl_sqt.sqt_dtp
	  || DV_INT64 == itc->itc_row_key->key_bit_cl->cl_sqt.sqt_dtp)
	return mp_box_num (mp, itc->itc_bp.bp_value);
      else
	return mp_box_iri_id (mp, itc->itc_bp.bp_value);
    }
  switch (cl->cl_sqt.sqt_dtp)
    {
    case DV_SHORT_INT:
      len = SHORT_REF (row + cl->cl_pos[rv]);
      return (mp_box_num (mp, len));
    case DV_LONG_INT:
      ROW_INT_COL (buf, row, rv, *cl, LONG_REF, len);
      return mp_box_num (mp, len);
    case DV_INT64:
            ROW_INT_COL (buf, row, rv, *cl, INT64_REF, ln);
	    return mp_box_num (mp, ln);

    case DV_IRI_ID:
      ROW_INT_COL (buf, row, rv, *cl, LONG_REF, len);
      return mp_box_iri_id (mp, (unsigned long) len);
    case DV_IRI_ID_8:
      ROW_INT_COL (buf, row, rv, *cl, INT64_REF, ln);
      return mp_box_iri_id (mp, ln);
    case DV_STRING:
      VL;
      str = mp_alloc_box (mp, (int) len + vl2 + 1, DV_LONG_STRING);
      memcpy (str, xx, len);
      memcpy (str + len, xx2, vl2);
      str[len + vl2 - 1] += offset;
      str[len + vl2] = 0;
      return str;

    case DV_SINGLE_FLOAT:
      FX;
      str = mp_alloc_box (mp, sizeof (float), DV_SINGLE_FLOAT);
      EXT_TO_FLOAT (str, xx);
      return str;
    case DV_DOUBLE_FLOAT:
      FX;
      str = mp_alloc_box (mp, sizeof (double), DV_DOUBLE_FLOAT);
      EXT_TO_DOUBLE (str, xx);
      return str;
    case DV_NUMERIC:
      FX;
      {
	numeric_t num = mp_numeric_allocate (mp);
	numeric_from_buf (num, xx);
	return ((caddr_t) num);
      }
    case DV_BIN:
    case DV_LONG_BIN:
      {
	VL;
	str = mp_alloc_box (mp, (int) len + vl2, DV_BIN);
	memcpy (str, xx, (int) len);
	memcpy (str + len, xx2, (int) vl2);
	return str;
      }

    case DV_DATETIME:
    case DV_TIMESTAMP:
    case DV_DATE:
    case DV_TIME:
      FX;
      {
	caddr_t res = mp_alloc_box (mp, DT_LENGTH, DV_DATETIME);
	memcpy (res, xx, DT_LENGTH);
	return res;
      }
    case DV_ANY:
      VL;
      return mp_box_deserialize_string (mp, (caddr_t)xx, len, offset);
    default:
      {
	caddr_t box = page_box_col (itc, buf, row, cl);
	mp_trash (mp, box);
	return box;
      }
    }
  return NULL;			/*dummy */
}


void
rd_free_box (row_delta_t * rd, caddr_t v)
{
  if ((db_buf_t) v < rd->rd_temp || (db_buf_t)v > rd->rd_temp + rd->rd_temp_fill)
    dk_free_tree ((caddr_t)v);
}

caddr_t
rd_alloc_box (row_delta_t * rd, int len, dtp_t dtp)
{
  if (rd && rd->rd_temp)
    {
      db_buf_t ptr;
      int fill = rd->rd_temp_fill;
      int bytes = 8 + ALIGN_8 (len);
#if defined(WORDS_BIGENDIAN) && defined(SOLARIS)
      if (0 == fill)
        {
	  fill = (uptrlong) rd->rd_temp % 8;
	  if (fill)
	    fill = 8 - fill;
	  rd->rd_temp_max -= fill;
	  rd->rd_temp_fill += fill;
        }
#endif
      if (fill + bytes > rd->rd_temp_max)
	{
	  rd->rd_allocated = RD_ALLOCATED_VALUES;
	  return dk_alloc_box (len, dtp);
	}
      ptr = rd->rd_temp + fill + 4;
      WRITE_BOX_HEADER(ptr, len, dtp);
      rd->rd_temp_fill += bytes;
      return (caddr_t)rd->rd_temp + fill + 8;
    }
  return dk_alloc_box (len, dtp);
}

#define RD_N_BOX(val) \
{\
  if (!IS_BOX_POINTER (val)) return (caddr_t) (ptrlong)val;		\
    { caddr_t box = rd_alloc_box (rd, sizeof (int64), DV_LONG_INT); *((int64*)box) = val; return box;} \
}

#define RD_IRI_BOX(val) \
  { if (rd && rd->rd_temp_fill + 16 < rd->rd_temp_max) \
      { rd->rd_temp_fill += 16; *(int64*)(rd->rd_temp + rd->rd_temp_fill - 16) = DV_IRI_TAG_WORD_64; *(iri_id_t*)(rd->rd_temp + rd->rd_temp_fill - 8) = val; return (caddr_t)rd->rd_temp + rd->rd_temp_fill - 8;} \
    else \
      { caddr_t box = rd_alloc_box (rd, sizeof (iri_id_t), DV_IRI_ID); *((iri_id_t*)box) = val; return box;}}


caddr_t
page_copy_col (buffer_desc_t * buf, db_buf_t row, dbe_col_loc_t * cl, row_delta_t * rd)
{
  int len;
  int64 ln;
  caddr_t str;
  unsigned short vl1, vl2, offset;
  row_ver_t rv = IE_ROW_VERSION (row);
  db_buf_t xx, xx2;
  if (row[cl->cl_null_flag[rv]] & cl->cl_null_mask[rv])
    return (rd_alloc_box (rd, 0, DV_DB_NULL));
  switch (cl->cl_sqt.sqt_dtp)
    {
    case DV_SHORT_INT:
      len = SHORT_REF (row + cl->cl_pos[rv]);
      RD_N_BOX (len);
    case DV_LONG_INT:
      ROW_INT_COL (buf, row, rv, *cl, LONG_REF, len);
      RD_N_BOX (len);
    case DV_INT64:
      ROW_INT_COL (buf, row, rv, *cl, INT64_REF, ln);
      RD_N_BOX (ln);

    case DV_IRI_ID:
      ROW_INT_COL (buf, row, rv, *cl, (iri_id_t)LONG_REF, ln);
      RD_IRI_BOX (ln);
    case DV_IRI_ID_8:
      ROW_INT_COL (buf, row, rv, *cl, INT64_REF, ln);
      RD_IRI_BOX (ln);
    case DV_OBJECT:
    case DV_ANY:
    case DV_STRING:
    case DV_BLOB:
    case DV_BLOB_BIN:
    case DV_BLOB_WIDE:
    case DV_BLOB_XPER:
    case DV_WIDE:
    case DV_LONG_WIDE:
      {
	VL;
	str = rd_alloc_box (rd, (int) len + vl2 + 1, DV_LONG_STRING);
	memcpy (str, xx, len);
	if (!vl2)
	  {
	    str[len - 1] += offset;
	    str[len] = 0;
	    return str;
	  }
	memcpy (str + len, xx2, vl2);
	str[len + vl2 - 1] += offset;
	str[len + vl2] = 0;
	return str;
      }
    case DV_SINGLE_FLOAT:
      FX;
      str = rd_alloc_box (rd, sizeof (float), DV_SINGLE_FLOAT);
      EXT_TO_FLOAT (str, xx);
      return str;
    case DV_DOUBLE_FLOAT:
      FX;
      str = rd_alloc_box (rd, sizeof (double), DV_DOUBLE_FLOAT);
      EXT_TO_DOUBLE (str, xx);
      return str;
    case DV_NUMERIC:
      FX;
      {
	numeric_t num = (numeric_t) rd_alloc_box (rd, sizeof (struct numeric_s)
						  + NUMERIC_MAX_DATA_BYTES - NUMERIC_PADDING, DV_NUMERIC);
	numeric_from_buf (num, xx);
	return ((caddr_t) num);
      }
    case DV_BIN:
    case DV_LONG_BIN:
      {
	VL;
	str = rd_alloc_box (rd, (int) len + vl2, DV_BIN);
	memcpy (str, xx, (int) len);
	if (vl2)
	memcpy (str + len, xx2, (int) vl2);
	str[len + vl2 - 1] += offset;
	return str;
      }


    case DV_DATETIME:
    case DV_TIMESTAMP:
    case DV_DATE:
    case DV_TIME:
      FX;
      {
	caddr_t res = rd_alloc_box (rd, DT_LENGTH, DV_DATETIME);
	memcpy (res, xx, DT_LENGTH);
	return res;
      }
    default:
      GPF_T;			/* Bad column type */
    }
  return NULL;			/*dummy */
}


void
page_write_col (buffer_desc_t * buf, db_buf_t row, dbe_col_loc_t * cl, dk_session_t * ses, it_cursor_t * itc)
{
  int len;
  int64 ln;
  unsigned short vl1, vl2, offset;
  row_ver_t rv = IE_ROW_VERSION (row);
  db_buf_t xx, xx2;
  if (row[cl->cl_null_flag[rv]] & cl->cl_null_mask[rv])
    {
      session_buffered_write_char (DV_DB_NULL, ses);
      return;
    }
  switch (cl->cl_sqt.sqt_dtp)
    {
    case DV_SHORT_INT:
      len = SHORT_REF (row + cl->cl_pos[rv]);
      print_int (len, ses);
      return;
    case DV_LONG_INT:
      ROW_INT_COL (buf, row, rv, *cl, LONG_REF, len);
      print_int (len, ses);
      return;
    case DV_INT64:
      ROW_INT_COL (buf, row, rv, *cl, INT64_REF, ln);
      print_int (ln, ses);
      return;

    case DV_IRI_ID:
      ROW_INT_COL (buf, row, rv, *cl, (iri_id_t)LONG_REF, ln);
      iri_id_write ((iri_id_t*)&ln, ses);
      return;
    case DV_IRI_ID_8:
      ROW_INT_COL (buf, row, rv, *cl, INT64_REF, ln);
      iri_id_write ((iri_id_t *)&ln, ses);
      return;
    case DV_OBJECT:
    case DV_STRING:
      {
	VL;
	if (vl1 + vl2 > 255)
	  {
	    session_buffered_write_char (DV_LONG_STRING, ses);
	    print_long (vl1 + vl2, ses);
	  }
	else
	  {
	    session_buffered_write_char (DV_SHORT_STRING_SERIAL, ses);
	    session_buffered_write_char (vl1 + vl2, ses);
	  }
	if (offset)
	  {
	    session_buffered_write (ses, (char*)xx, vl1 - 1);
	    session_buffered_write_char (xx[vl1 - 1] + offset, ses);
	  }
	else
	  {
	    session_buffered_write (ses, (char*)xx, vl1);
	    session_buffered_write (ses, (char*)xx2, vl2);
	  }
	return;
      }
    case DV_ANY:
      {
	VL;
	if (offset)
	  {
	    session_buffered_write (ses, (char*)xx, vl1 - 1);
	    session_buffered_write_char (xx[vl1 - 1] + offset, ses);
	  }
	else
	  {
	    session_buffered_write (ses, (char*)xx, vl1);
	    session_buffered_write (ses, (char*)xx2, vl2);
	  }
	return;
      }

    case DV_BLOB:
    case DV_BLOB_BIN:
    case DV_BLOB_WIDE:
    case DV_BLOB_XPER:
    case DV_WIDE:
    case DV_LONG_WIDE:
      {
	caddr_t box =itc_box_column (itc, buf, 0, cl);
	if (cl->cl_sqt.sqt_is_xml && (DKS_TO_CLUSTER & ses->dks_cluster_flags))
	  {
	    session_buffered_write_char (DV_XML_ENTITY, ses);
	    print_long (box_length (box) - 1, ses);
	    if (DV_STRINGP (box))
	      session_buffered_write (ses, box, box_length (box) - 1);
	    else
	      bh_write_out (itc->itc_ltrx, (blob_handle_t *) box, ses);
	  }
	else
	  print_object (box, ses, NULL, NULL);
	dk_free_box (box);
	return;
    }
    case DV_SINGLE_FLOAT:
      {
	float f;
	FX;
	EXT_TO_FLOAT (&f, xx);
	print_float (f, ses);
	return;
      }
    case DV_DOUBLE_FLOAT:
      {
	double d;
	FX;
	EXT_TO_DOUBLE (&d, xx);
	print_double (d, ses);
	return;
      }
    case DV_NUMERIC:
      FX;
      {
	numeric_t num = (numeric_t) dk_alloc_box (sizeof (struct numeric_s)
						  + NUMERIC_MAX_DATA_BYTES - NUMERIC_PADDING, DV_NUMERIC);
	numeric_from_buf (num, xx);
	numeric_serialize (num, ses);
	dk_free_box (num);
	return;
      }
    case DV_BIN:
    case DV_LONG_BIN:
      {
	VL;
	if (vl1 + vl2 > 255)
	  {
	    session_buffered_write_char (DV_LONG_BIN, ses);
	    print_long (vl1 + vl2, ses);
	  }
	else
	  {
	    session_buffered_write_char (DV_BIN, ses);
	    session_buffered_write_char (vl1 + vl2, ses);
	  }
	session_buffered_write (ses, (char*)xx, vl1);
	session_buffered_write (ses, (char*)xx2, vl2);
	return;
      }

 case DV_DATETIME:
    case DV_TIMESTAMP:
    case DV_DATE:
    case DV_TIME:
      FX;
      session_buffered_write_char (DV_DATETIME, ses);
      session_buffered_write (ses, (char*)xx, DT_LENGTH);
      return;
    default:
      GPF_T;			/* Bad column type */
    }
}

caddr_t
box_bin_string (db_buf_t place, size_t len, dtp_t dtp)
{
  caddr_t res = dk_alloc_box (len, dtp);
  memcpy (res, place, len);
  return res;
}


caddr_t
box_varchar_string (db_buf_t place, size_t len, dtp_t dtp)
{
  caddr_t res = dk_alloc_box (len + 1, dtp);
  memcpy (res, place, len);
  res[len] = 0;
  return res;
}


void
qst_set_wide_string (caddr_t * state, state_slot_t * sl, db_buf_t data, int len, dtp_t dtp, int isUTF8)
{

#ifdef QST_DEBUG
  if (sl->ssl_index < QI_FIRST_FREE)
    GPF_T1 ("Invalid SSL in qst_set");
  else if (sl->ssl_type == SSL_CONSTANT)
    GPF_T1 ("Invalid constant SSL in qst_set");
  else
    {
#endif
  caddr_t *place = IS_SSL_REF_PARAMETER (sl->ssl_type)
    ? (caddr_t *) state[sl->ssl_index]
    : (caddr_t *) & state[sl->ssl_index];
  caddr_t old = *place;
  if (IS_BOX_POINTER (old))
    {
      dtp_t old_dtp = box_tag (old);
      if (!isUTF8 && IS_WIDE_STRING_DTP (old_dtp) &&
	  box_length (old) == len + sizeof (wchar_t))
	{
	  box_reuse ((box_t) old, (box_t) data, len + sizeof (wchar_t), dtp);
	}
      else
	{
	  ssl_free_data (sl, old);
	  *place = isUTF8 ?
	    box_utf8_as_wide_char ((caddr_t) data, NULL, len, 0, dtp) :
	    box_wide_char_string ((caddr_t) data, len, dtp);
	}
    }
  else
    *place = isUTF8 ?
      box_utf8_as_wide_char ((caddr_t) data, NULL, len, 0, dtp) :
    box_wide_char_string ((caddr_t) data, len, dtp);
#ifdef QST_DEBUG
    }
#endif
}



void
qst_set_bin_string (caddr_t * state, state_slot_t * sl, db_buf_t data, size_t len, dtp_t dtp)
{
#ifdef QST_DEBUG
  if (sl->ssl_index < QI_FIRST_FREE)
    GPF_T1 ("Invalid SSL in qst_set");
  else if (sl->ssl_type == SSL_CONSTANT)
    GPF_T1 ("Invalid constant SSL in qst_set");
  else
    {
#endif
  caddr_t *place = IS_SSL_REF_PARAMETER (sl->ssl_type)
    ? (caddr_t *) state[sl->ssl_index]
    : (caddr_t *) & state[sl->ssl_index];
  caddr_t old = *place;
  if (IS_BOX_POINTER (old))
    {
      dtp_t old_dtp = box_tag (old);
      if (!IS_STRING_DTP (old_dtp) &&
	  ALIGN_8 (box_length (old)) == ALIGN_8 ((uint32) len))
	{
	  box_reuse ((box_t) old, (box_t) data, len, dtp);
	}
      else
	{
	  ssl_free_data (sl, old);
	  *place = box_bin_string (data, len, dtp);
	}
    }
  else
    {
      *place = box_bin_string (data, len, dtp);
    }
#ifdef QST_DEBUG
    }
#endif
}


void
qst_set_string (caddr_t * state, state_slot_t * sl, db_buf_t data, size_t len, uint32 flags)
{
#ifdef QST_DEBUG
  if (sl->ssl_index < QI_FIRST_FREE)
    GPF_T1 ("Invalid SSL in qst_set");
  else if (sl->ssl_type == SSL_CONSTANT)
    GPF_T1 ("Invalid constant SSL in qst_set");
  else
    {
#endif
  caddr_t *place = IS_SSL_REF_PARAMETER (sl->ssl_type)
    ? (caddr_t *) state[sl->ssl_index]
    : (caddr_t *) & state[sl->ssl_index];
  place[0] = box_dv_short_nchars_reuse ((const char *) data, len, place[0]);
  box_flags (place[0]) = flags;
#ifdef QST_DEBUG
    }
#endif
}


void
qst_set_pref_string (caddr_t * state, state_slot_t * sl, db_buf_t data, size_t len, db_buf_t data2, size_t len2, short offset)
{
#ifdef QST_DEBUG
  if (sl->ssl_index < QI_FIRST_FREE)
    GPF_T1 ("Invalid SSL in qst_set");
  else if (sl->ssl_type == SSL_CONSTANT)
    GPF_T1 ("Invalid constant SSL in qst_set");
  else
    {
#endif
  caddr_t *place = IS_SSL_REF_PARAMETER (sl->ssl_type)
    ? (caddr_t *) state[sl->ssl_index]
    : (caddr_t *) & state[sl->ssl_index];
  place[0] = box_dv_short_nchars_reuse ((const char *) data, len + len2, place[0]);
  if (len2)
    memcpy (*place + len, data2, len2);
  (*place)[len + len2 - 1] += offset;
#ifdef QST_DEBUG
    }
#endif
}


void
qst_set_over (caddr_t * qst, state_slot_t * ssl, caddr_t v)
{
  if (SSL_VEC == ssl->ssl_type)
    {
      qst_vec_set_copy (qst, ssl, v);
      return;
    }
  switch (DV_TYPE_OF (v))
    {
    case DV_STRING:
      qst_set_string (qst, ssl, (db_buf_t)v, box_length (v) - 1, box_flags (v));
      break;
    case DV_LONG_INT:
      qst_set_long (qst, ssl, unbox (v));
      break;
    case DV_DOUBLE_FLOAT:
      qst_set_double (qst, ssl, unbox_double (v));
      break;
    case DV_SINGLE_FLOAT:
      qst_set_float (qst, ssl, unbox_float (v));
      break;
    case DV_IRI_ID:
      {
	caddr_t old = QST_GET (qst, ssl);
	if (IS_BOX_POINTER (old) && DV_IRI_ID == box_tag (old))
	  *(iri_id_t*)old = *(iri_id_t*)v;
	else
	  qst_set_bin_string (qst, ssl, (db_buf_t)v, sizeof (iri_id_t), DV_IRI_ID);
	break;
      }
    case DV_DB_NULL:
      qst_set_bin_string (qst, ssl, 0, 0, DV_DB_NULL);
      break;
    default:
      qst_set (qst, ssl, box_copy_tree (v));
    }
}

void
itc_qst_set_column (it_cursor_t * it, buffer_desc_t * buf, dbe_col_loc_t * cl,
    caddr_t * qst, state_slot_t * target)
{
  float fl;
  double df;
  int32 len;
  iri_id_t ln1;
  dtp_t * row = it->itc_row_data, *xx, *xx2;
  unsigned short vl1, vl2, offset;
  int64 ln;
  row_ver_t rv = IE_ROW_VERSION (row);
  dtp_t col_dtp;

  if ((row[cl->cl_null_flag[rv]] & cl->cl_null_mask[rv]))
    {
      qst_set_bin_string (qst, target, (db_buf_t) "", 0, DV_DB_NULL);
      return;
    }
  col_dtp = cl->cl_sqt.sqt_dtp;
  switch (col_dtp)
    {
    case DV_SHORT_INT:
      len = ((signed short *) (row + cl->cl_pos[rv]))[0];
      qst_set_long (qst, target, (long) len);
      return;
    case DV_LONG_INT:
      ROW_INT_COL (buf, row, rv, (*cl), LONG_REF, len);
      qst_set_long (qst, target, len);
      return;
    case DV_INT64:
      ROW_INT_COL (buf, row, rv, (*cl), INT64_REF, ln);
      qst_set_long (qst, target, ln);
      return;
    case DV_IRI_ID:
      ROW_INT_COL (buf, row, rv, (*cl), LONG_REF, len);
	    ln1 = (iri_id_t) (unsigned long) len;
      qst_set_bin_string (qst, target, (db_buf_t) &ln1, sizeof (iri_id_t), DV_IRI_ID);
      return;
    case DV_IRI_ID_8:
      ROW_INT_COL (buf, row, rv, (*cl), INT64_REF, ln1);
      qst_set_bin_string (qst, target, (db_buf_t) &ln1, sizeof (iri_id_t), DV_IRI_ID);
      return;
    case DV_OBJECT:
    case DV_ANY:
      VLI;
      {
	caddr_t thing = len ? box_deserialize_string ((char *)(xx), len, offset) : box_num (0);
	qst_set (qst, target, thing);
      return;
      }
    case DV_STRING:
      VLI;
      qst_set_pref_string (qst, target, xx, len, xx2, vl2, offset );
      return;
    case DV_SINGLE_FLOAT:
      FX;
      EXT_TO_FLOAT (&fl, xx);
      qst_set_float (qst, target, fl);
      return;
    case DV_DOUBLE_FLOAT:
      FX;
      EXT_TO_DOUBLE (&df, xx);
      qst_set_double (qst, target, df);
      return;
    case DV_NUMERIC:
      FX;
      qst_set_numeric_buf (qst, target, xx);
      return;
    case DV_BIN:
    case DV_LONG_BIN:
      {
	VLI;
	qst_set_bin_string (qst, target, xx, len, DV_BIN);
	return;
      }
    case DV_COMPOSITE:
      {
	O12;
	VLI; /* To eliminate warning :) */
	len = xx[1];
	qst_set_bin_string (qst, target, xx, len + 2, DV_COMPOSITE);
	return;
      }

    case DV_WIDE:
    case DV_LONG_WIDE:
      {
	VLI;
	qst_set_wide_string (qst, target, xx, len, DV_LONG_WIDE, 1);
	return;
      }

    case DV_BLOB:
      VLI;
      {
	caddr_t bh = blob_ref_check (xx, len, it, col_dtp);
#ifdef BIF_XML
	if (DV_BLOB_XPER_HANDLE == DV_TYPE_OF (bh))
	  {
	    caddr_t val = (caddr_t) xper_entity (
	      (query_instance_t *) QST_INSTANCE (qst),
	      bh, NULL, 0, itc_box_base_uri_column_impl (it, it->itc_row_key, row, cl->cl_col_id), NULL /* no enc */, server_default_lh, NULL /* DTD config */, 1 );
	    dk_free_box (bh);
	    qst_set (qst, target, val);
	    return;
	  }
#endif
	if (cl->cl_sqt.sqt_class)
	  {
	    caddr_t res = udt_deserialize_from_blob (bh, it->itc_ltrx);
	    dk_free_box (bh);
	    qst_set (qst, target, res);
	    return;
	  }
	if (cl->cl_sqt.sqt_is_xml && qst)
	  {
	    caddr_t res = xml_deserialize_from_blob (bh, it->itc_ltrx, qst, itc_box_base_uri_column_impl (it, it->itc_row_key, row, cl->cl_col_id));
	    dk_free_box (bh);
	    qst_set (qst, target, res);
	    return;
	  }
	qst_set (qst, target, bh);
	return;
      }

    case DV_BLOB_BIN:
    case DV_BLOB_WIDE:
      VLI;
      {
	caddr_t bh = blob_ref_check (xx, len, it, col_dtp);
	qst_set (qst, target, bh);
	return;
      }

#ifdef BIF_XML
    case DV_BLOB_XPER:
      VLI;
      {
	caddr_t bh = blob_ref_check (xx, len, it, col_dtp);
	caddr_t val = (caddr_t) xper_entity (
	  (query_instance_t *) QST_INSTANCE (qst),
	  bh, NULL, 0, itc_box_base_uri_column_impl (it, it->itc_row_key, row, cl->cl_col_id), NULL /* no enc */, server_default_lh, NULL /* DTD config */, 1 );
	dk_free_box (bh);
	qst_set (qst, target, val);
	return;
      }
#endif
    case DV_DATETIME:
    case DV_TIMESTAMP:
    case DV_DATE:
    case DV_TIME:
      {
	FX;
	qst_set_bin_string (qst, target, xx, DT_LENGTH, DV_DATETIME);
	return;
      }
    case DV_ARRAY_OF_FLOAT:
      VLI;
      {
	int inx;
	caddr_t res;
	res = dk_alloc_box (len, cl->cl_sqt.sqt_dtp);
	for (inx = 0; inx < len; inx += 4)
	  ((int32 *) res)[inx / 4] = LONG_REF (xx + inx);
	qst_set (qst, target, res);
	return;
      }
    case DV_ARRAY_OF_LONG:
      VLI;
      {
	int inx;
	caddr_t res;
	res = dk_alloc_box (len / sizeof (int32) * sizeof (ptrlong), cl->cl_sqt.sqt_dtp);
	for (inx = 0; inx < len; inx += 4)
	  ((ptrlong *) res)[inx / 4] = LONG_REF (xx + inx);
	qst_set (qst, target, res);
	return;
      }
    case DV_ARRAY_OF_DOUBLE:
      VLI;
      {
	int inx;
	caddr_t res;
	res = dk_alloc_box (len, *xx);
	for (inx = 0; inx < len; inx += 8)
	  {
	    EXT_TO_DOUBLE ((res + inx), (xx + inx));
	  }
	qst_set (qst, target, res);
	return;
      }
    default:
      {
	char msg[1024];
	snprintf (msg, sizeof (msg), "Bad col tag, itc_qst_set_columns %d",cl->cl_sqt.sqt_dtp);
	GPF_T1 (msg);
      }
    }
  return;			/*dummy */
}


int64
safe_atoi (const char *data, caddr_t *err_ret)
{
  caddr_t err;
  int64 ret;
  NUMERIC_VAR (n);
  NUMERIC_INIT (n);

  if (NUMERIC_STS_SUCCESS == numeric_from_string ((numeric_t)n, data))
    {
      if (NUMERIC_STS_SUCCESS == numeric_to_int64 ((numeric_t) n, &ret))
	return ret;
    }

  err = srv_make_new_error ("22005", "SR341", "Invalid integer value converting '%.100s'", data);
  if (!err_ret)
    sqlr_resignal (err);
  else
    *err_ret = err;
  return 0;
}


double
safe_atof (const char *data, caddr_t *err_ret)
{
#if 0
  char *end_ptr = NULL;
  double ret;
  int eno_save;
  caddr_t err = NULL;

  if (!data)
    goto error;

  ret = strtod (data, &end_ptr);
  eno_save = errno;
  while (end_ptr && *end_ptr && isspace (*end_ptr))
    end_ptr++;
  if (eno_save == ERANGE || !end_ptr || *end_ptr)
    {
error:
      err = srv_make_new_error ("22023", "SR334", "Invalid floating point value converting '%.100s'",
	  data);
      if (!err_ret)
	sqlr_resignal (err);

      *err_ret = err;
      return 0;
    }
  else
    return ret;
#else
  caddr_t err;
  double ret;
  NUMERIC_VAR (n);
  NUMERIC_INIT (n);

  if (NUMERIC_STS_SUCCESS == numeric_from_string ((numeric_t)n, data))
    {
      if (NUMERIC_STS_SUCCESS == numeric_to_double ((numeric_t) n, &ret))
	return ret;
    }

  err = srv_make_new_error ("22005", "SR334", "Invalid floating point value converting '%.100s'", data);
  if (!err_ret)
    sqlr_resignal (err);
  else
    *err_ret = err;
  return 0;
#endif
}


boxint
box_to_boxint (caddr_t data, dtp_t dtp, oid_t col_id, caddr_t * err_ret, dbe_key_t *key, dtp_t col_dtp)
{
  boxint res;
  switch (dtp)
    {
    case DV_LONG_INT:
    case DV_SHORT_INT:
      res = unbox (data);
      break;
    case DV_SINGLE_FLOAT:
      res =  (boxint) unbox_float (data);
      break;
    case DV_DOUBLE_FLOAT:
      res =  (boxint) unbox_double (data);
      break;
    case DV_STRING:
      res = safe_atoi (data, err_ret);
      break;
    case DV_WIDE:
    case DV_LONG_WIDE:
	{
	  char narrow [512];
	  box_wide_string_as_narrow (data, narrow, 512, NULL);
	  res = safe_atoi (narrow, err_ret);
	  break;
	}
    case DV_NUMERIC:
      {
	numeric_to_int64 ((numeric_t) data, &res);
	break;
      }
    default:
      {
	char * cl_name = __get_column_name (col_id, key);
	/* length of type name is finite */
	*err_ret = srv_make_new_error ("22005", "SR130", "Bad type %.*s of value for numeric column %.*s",
	    MAX_NAME_LEN, dv_type_title (dtp), MAX_NAME_LEN, cl_name);
      return 0;
      }
    }
  if (DV_INT64 == col_dtp)
    return res;
  if (DV_LONG_INT == col_dtp
      && INT32_MAX >= res && INT32_MIN <= res)
    return res;
  else if (INT16_MAX >= res && INT16_MIN <= res)
    return res;
  {
    char * cl_name = __get_column_name (col_id, key);
    *err_ret = srv_make_new_error ("22005", "SR130", "Integer " BOXINT_FMT " does not fit in  column %.*s.", res,
				   MAX_NAME_LEN, cl_name);
    return 0;
  }
}


static double
box_to_double (caddr_t data, dtp_t dtp, oid_t col_id, caddr_t * err_ret, dbe_key_t *key)
{
  switch (dtp)
    {
    case DV_LONG_INT:
    case DV_SHORT_INT:
      return ((double) unbox (data));
    case DV_SINGLE_FLOAT:
      return ((double) unbox_float (data));
    case DV_DOUBLE_FLOAT:
      return (unbox_double (data));
    case DV_STRING:
      return safe_atof (data, err_ret);
    case DV_WIDE:
    case DV_LONG_WIDE:
	{
	  char narrow [512];
	  box_wide_string_as_narrow (data, narrow, 512, NULL);
	  return safe_atof (narrow, err_ret);
	  break;
	}
    case DV_NUMERIC:
      {
	double d;
	numeric_to_double ((numeric_t) data, &d);
	return d;
      }
    default:
      {
	char * cl_name = __get_column_name (col_id, key);
	/* length of type name is finite */
	*err_ret = srv_make_new_error ("22005", "SR130", "Bad type %.*s of value for numeric column %.*s",
	    MAX_NAME_LEN, dv_type_title (dtp), MAX_NAME_LEN, cl_name);
      return 0;
      }
   }
}


void box2anyerr ()
{}


caddr_t
box_to_any_long (caddr_t data, caddr_t * err_ret, int ser_flags)
	  {
  caddr_t str;
  dk_session_t * ses = (dk_session_t*)resource_get (cl_strses_rc);
  ses->dks_cluster_flags = ser_flags;
  CATCH_WRITE_FAIL (ses)
    {
      print_object (data, ses, NULL, NULL);
    }
  FAILED
    {
      resource_store (cl_strses_rc, (void*)ses);
      box2anyerr ();
      *err_ret = srv_make_new_error ("22026", "SR477", "Error serializing the value into an ANY column");
      return NULL;
    }
  END_WRITE_FAIL (ses);
  str = strses_string (ses);
  resource_store (cl_strses_rc, (void*)ses);
  return str;
}

#define BOX_OR_AUTO(n, t) \
  ((ap && n + 16 < ap->ap_size - ap->ap_fill) ? ap_alloc_box (ap, n, t)	\
    : dk_alloc_box (n, t))


#define name  box_to_any_1
#define MP_T auto_pool_t
#define ALLOC(n, dtp)  BOX_OR_AUTO(n, dtp)

#include "box2any.c"

#define name  mp_box_to_any_1
#define MP_T mem_pool_t
#define ALLOC(n, dtp)  mp_alloc_box_ni(ap, n, dtp)

#include "box2any.c"




caddr_t
box_to_any (caddr_t data, caddr_t * err_ret)
{
  if (THR_IS_STACK_OVERFLOW (THREAD_CURRENT_THREAD, &err_ret, (PAGE_DATA_SZ+1000)))
    {
      *err_ret = srv_make_new_error ("42000", "SR483", "Stack Overflow");
      return NULL;
    }
  return box_to_any_1 (data, err_ret, NULL, 0);
}

caddr_t
box_to_shorten_any (caddr_t data, caddr_t * err_ret)
{
  dtp_t data_dtp = DV_TYPE_OF (data);
  size_t data_len;
  if (THR_IS_STACK_OVERFLOW (THREAD_CURRENT_THREAD, &err_ret, (PAGE_DATA_SZ+1500)))
    {
      *err_ret = srv_make_new_error ("42000", "SR483", "Stack Overflow");
      return NULL;
    }
#define BOX_SHORT_ANY_LIMIT (128+1+(BOX_AUTO_OVERHEAD-8))
  if (((DV_STRING == data_dtp) || (DV_WIDE == data_dtp) || (DV_BIN == data_dtp)) &&
    (BOX_SHORT_ANY_LIMIT < (data_len = box_length (data))) )
    {
      caddr_t h = box_md5 (data);
      caddr_t err = NULL;
      caddr_t any = box_to_any (h, &err);
      dk_free_box (h);
      return any;
    }
  return box_to_any_1 (data, err_ret, NULL, 0);
}



#define V_COL_LEN(len) \
      if ((int) (len + *v_fill) > max) \
	{ \
	  *err_ret = srv_make_new_error ("22003", "SR448", "Max row length exceeded"); \
	  return; \
	} \
      *v_fill += len; \


/* the idea is to have the same data casting as in row_set_col.
   to be used in trigger calls, so the update triggers get values
   of the correct data type
 */
caddr_t
row_set_col_cast (caddr_t data, sql_type_t *tsqt, caddr_t *err_ret,
    oid_t col_id, dbe_key_t *key, caddr_t *qst)
{
  dtp_t dtp = DV_TYPE_OF (data);
  caddr_t res = NULL;
  boxint lv;

  if (dtp != tsqt->sqt_dtp && dtp != DV_DB_NULL)
    {
      switch (tsqt->sqt_dtp)
	{
	  case DV_LONG_INT:
	  case DV_SHORT_INT:
	    lv = box_to_boxint (data, dtp, col_id, err_ret, key, DV_SHORT_INT);
	      if (err_ret && *err_ret)
		res = NULL;
	      res = box_num (lv);
	      break;

	  case DV_NUMERIC:
		{
		  NUMERIC_VAR (n);
		  *err_ret = numeric_from_x ((numeric_t)n, data, tsqt->sqt_precision,
		      tsqt->sqt_scale,0, col_id, key);
		  res = (caddr_t) numeric_allocate ();
		  memcpy (res, &n, MIN (box_length (res), sizeof (n)));
		  break;
		}

	  case DV_STRING:
	      if (!IS_STRING_DTP (dtp))
		{
		  res = box_cast_to (qst, data, dtp, DV_LONG_STRING, 0, 0, err_ret);
		}
	      break;

	  case DV_WIDE:
	      if (!IS_WIDE_STRING_DTP (dtp))
		{
		  res = box_cast_to (qst, data, dtp, DV_LONG_WIDE, 0, 0, err_ret);
		}
	      break;

	  case DV_BIN:
	      data = box_cast_to (qst, data, dtp, DV_BIN, 0, 0, err_ret);
	      break;

	  case DV_SINGLE_FLOAT:
		{
		  double df = box_to_double (data, dtp, col_id, err_ret, key);
		  float ft = (float) df;
		  res = box_float (ft);
		  break;
		}
	  case DV_DOUBLE_FLOAT:
		{
		  double df = box_to_double (data, dtp, col_id, err_ret, key);
		  res = box_double (df);
		  break;
		}

	  case DV_DATETIME:
	  case DV_TIME:
	  case DV_DATE:
	  case DV_TIMESTAMP:
	      if (DV_DATETIME != dtp)
		{
		  res = box_cast_to (qst, data, dtp,
		      tsqt->sqt_dtp, 0, 0, err_ret);
		}
	      break;
	}
    }
  return res;
}


void
itc_print_params (it_cursor_t * itc)
{
  int inx;
  printf ("itc %p with params ", itc);
  for (inx = 0; inx < itc->itc_search_par_fill; inx++)
    {
      sqlo_box_print (itc->itc_search_params[inx]);
      if (inx < itc->itc_search_par_fill - 1)
	printf (", ");
    }
  printf ("\n");
}

void
rd_print (row_delta_t * rd)
{
  int inx = 0;
  dbe_key_t * key = rd->rd_key;
  for (inx = 0; inx < key->key_n_significant; inx++)
    {
      sqlo_box_print (rd->rd_values[key->key_part_in_layout_order[inx]]);
      printf ("\n");
    }
}

void
row_insert_cast (row_delta_t * rd, dbe_col_loc_t * cl, caddr_t data,
		 caddr_t * err_ret, db_buf_t old_blob)
{
  it_cursor_t * ins_itc = rd->rd_itc;
  int max = rd->rd_non_comp_max;
  caddr_t blob_box = NULL;
  dbe_key_t * key = rd->rd_key;
  dtp_t blob_temp[DV_BLOB_LEN];
  unsigned short * v_fill = &rd->rd_non_comp_len;
  boxint lv;
  caddr_t str;
  int pos, len;
  dtp_t dtp = DV_TYPE_OF (data);
  caddr_t wide_str = 0;
  if (DV_DB_NULL == dtp)
    {
      if (!cl->cl_null_mask[0])
	{
	  char* cl_name = __get_column_name (cl->cl_col_id, key);
	  if (key->key_table)
	    {
	      *err_ret = srv_make_new_error ("23000", "SR133",
		  "Can not set NULL to not nullable column '%.*s.%.*s'",
		  MAX_NAME_LEN, key->key_table->tb_name, MAX_NAME_LEN, cl_name);
	    }
	  else
	    {
	      *err_ret = srv_make_new_error ("23000", "SR133",
		  "Can not set NULL to not nullable column '%.*s'",
		  MAX_NAME_LEN, cl_name);
	    }
	  return;
	}
      if (key->key_is_col && (DV_ANY == cl->cl_sqt.sqt_col_dtp || IS_BLOB_DTP (cl->cl_sqt.sqt_col_dtp)))
	{
	  caddr_t b = dk_alloc_box (2, DV_STRING);
	  b[0] = DV_DB_NULL;
	  b[1] = 0;
	  ITC_SEARCH_PARAM (ins_itc, b);
	  ITC_OWNS_PARAM (ins_itc, b);
	}
      else
      ITC_SEARCH_PARAM (ins_itc, data);
      if (old_blob && IS_BLOB_DTP (*old_blob))
	{
	  blob_layout_t * old_bl = bl_from_dv (old_blob, rd->rd_itc);
	  blob_log_replace (rd->rd_itc, old_bl);
	  blob_schedule_delayed_delete (rd->rd_itc, old_bl, BL_DELETE_AT_COMMIT);
	}
      return;
    }

  switch (cl->cl_sqt.sqt_col_dtp)
    {
    case DV_LONG_INT:
      lv = box_to_boxint (data, dtp, cl->cl_col_id, err_ret, key, DV_LONG_INT);
      if (err_ret && *err_ret)
	return;
      lv = num_check_prec (lv, cl->cl_sqt.sqt_precision, __get_column_name (cl->cl_col_id, key), err_ret);
      if (err_ret && *err_ret)
	return;
      if (DV_LONG_INT == DV_TYPE_OF (data))
	{
	  ITC_SEARCH_PARAM (ins_itc, data);
	}
      else
	{
	  caddr_t box = box_num (lv);
	  ITC_SEARCH_PARAM (ins_itc, box);
	      ITC_OWNS_PARAM (ins_itc, box);
	}
      break;
    case DV_INT64:
      lv = box_to_boxint (data, dtp, cl->cl_col_id, err_ret, key, DV_INT64);
      if (err_ret && *err_ret)
	return;
      lv = num_check_prec (lv, cl->cl_sqt.sqt_precision, __get_column_name (cl->cl_col_id, key), err_ret);
      if (err_ret && *err_ret)
	return;
      if (DV_LONG_INT == DV_TYPE_OF (data))
	{
	  ITC_SEARCH_PARAM (ins_itc, data);
	}
      else
	{
	  caddr_t box = box_num (lv);
	  ITC_SEARCH_PARAM (ins_itc, box);
	  ITC_OWNS_PARAM (ins_itc, box);
	}
      break;

    case DV_SHORT_INT:
      lv = box_to_boxint (data, dtp, cl->cl_col_id, err_ret, key, DV_SHORT_INT);
      if (err_ret && *err_ret)
	return;
      lv = num_check_prec (lv, cl->cl_sqt.sqt_precision, __get_column_name (cl->cl_col_id, key), err_ret);
      if (err_ret && *err_ret)
	return;
      if (DV_LONG_INT == DV_TYPE_OF (data))
	{
	  ITC_SEARCH_PARAM (ins_itc, (caddr_t)(ptrlong) data);
	}
      else
	{
	  caddr_t box = box_num (lv);
	  ITC_SEARCH_PARAM (ins_itc, box);
	  ITC_OWNS_PARAM (ins_itc, box);
}
      break;

    case DV_IRI_ID:
    case DV_IRI_ID_8:
      {
	iri_id_t iid;
	if (DV_IRI_ID != DV_TYPE_OF (data))
	  {
	    char* cl_name = __get_column_name (cl->cl_col_id, key);
	    if (err_ret)
	      *err_ret = srv_make_new_error ("22005", "SR130", "Bad type %.*s of value for IRI ID column %.*s",
					     MAX_NAME_LEN, dv_type_title (DV_TYPE_OF (data)), MAX_NAME_LEN, cl_name);
	    return;
	  }
	iid = unbox_iri_id (data);
	ITC_SEARCH_PARAM (ins_itc, data);
	if (DV_IRI_ID == cl->cl_sqt.sqt_col_dtp)
	  {
	    /* to don't overflow */
	    if (iid > 0xFFFFFFFF)
	      {
		if (err_ret)
		  *err_ret = srv_make_new_error ("22023", "SR130", "Value for IRI ID column out of range");
		return;
	      }

	  }
	break;

      }
    case DV_NUMERIC:
      {
	NUMERIC_VAR (n);
	*err_ret = numeric_from_x ((numeric_t)n, data, cl->cl_sqt.sqt_precision,
			      cl->cl_sqt.sqt_scale,0, cl->cl_col_id, key);
	if (!*err_ret)
	  {
	    dtp_t tmp[258];
	    numeric_to_dv ( (numeric_t) n, tmp, sizeof (tmp));
	    if (ins_itc)
	      {
		caddr_t n_box = (caddr_t) numeric_allocate ();
		memcpy (n_box, &n, MIN (box_length (n_box), sizeof (n)));
		ITC_SEARCH_PARAM (ins_itc, n_box);
		ITC_OWNS_PARAM (ins_itc, n_box);
	      }
	  }
	return;
      }

    case DV_ANY:
      str = box_to_any_1 (data, err_ret, NULL, rd->rd_any_ser_flags);
      if (err_ret && *err_ret)
	return;
      ITC_OWNS_PARAM (ins_itc, str);
      if ((DV_STRING == (dtp_t)str[0] || DV_SHORT_STRING_SERIAL == (dtp_t)str[0]) && tb_is_rdf_quad (key->key_table))
	{
	  caddr_t err = srv_make_new_error ("42000",  "RDFST", "Inserting a string into O in RDF_QUAD.  RDF box is expected");
	  if (err_ret)
	    *err_ret = err;
	  else
	    sqlr_resignal (err);
	  return;
	}
      goto assign_str;

    case DV_OBJECT:
      udt_can_write_to (&cl->cl_sqt, data, err_ret);
      if (err_ret && *err_ret)
	return;
      str = box_to_any_1 (data, err_ret, NULL, rd->rd_any_ser_flags);
      if (err_ret && *err_ret)
	return;
      ITC_OWNS_PARAM (ins_itc, str);
      goto assign_str;

    case DV_STRING:
      str = data;
      if (!IS_STRING_DTP (dtp))
	{
	  str = box_cast_to (ins_itc->itc_out_state, data, dtp, DV_LONG_STRING, 0, 0, err_ret);
	  ITC_OWNS_PARAM (ins_itc, str);
	  if (*err_ret)
	    return;
	}
    assign_str:
      len = box_length (str) - 1;
      if (cl->cl_sqt.sqt_precision &&
	  len > (long) cl->cl_sqt.sqt_precision)
	{
	  if (key->key_table)
	    {
	      char* cl_name = __get_column_name (cl->cl_col_id, key);
	      *err_ret = srv_make_new_error ("22026", "SR319",
				          "Max column length (%lu) of column '%.*s.%.*s' exceeded",
				          (unsigned long) cl->cl_sqt.sqt_precision,
					  3 * MAX_NAME_LEN, key->key_table->tb_name,
					  MAX_NAME_LEN, cl_name);
	    }
	  else
	    *err_ret = srv_make_new_error ("22026", "SR319",
				        "Max column length (%lu) of temp column  exceeded",
				        (unsigned long) cl->cl_sqt.sqt_precision);
	  return;
	}
      if (len + *v_fill > max)
	{
	  if (key->key_table)
	    {
	      char* cl_name = __get_column_name (cl->cl_col_id, key);
	      *err_ret = srv_make_new_error ("22026", "SR319",
		    "Max row length is exceeded when trying to store a string of %d chars to '%.*s.%.*s'",
		    len, MAX_NAME_LEN * 3, key->key_table->tb_name, MAX_NAME_LEN, cl_name);
	    }
	  else
	    *err_ret =srv_make_new_error ("22026", "SR319",
		  "Max row length is exceeded when trying to store a string of %d chars into a temp col",
		  len);
	  return;
	}
      *v_fill += len;
      if (ins_itc)
	ITC_SEARCH_PARAM (ins_itc, str);
      break;

    case DV_WIDE:
    case DV_LONG_WIDE:
      if (!IS_WIDE_STRING_DTP (dtp))
	{
	  wide_str = box_cast_to (ins_itc->itc_out_state, data, dtp, DV_LONG_WIDE, 0, 0, err_ret);
	  if (ins_itc)
	    ITC_OWNS_PARAM (ins_itc, wide_str);
	  if (*err_ret)
	    return;
	}
      else
	{
	  wide_str = data;
	}
      str = box_wide_as_utf8_char (wide_str, box_length (wide_str) / sizeof (wchar_t) - 1, DV_LONG_STRING);

      len = box_length (str) - 1;
      if (len + *v_fill > max)
	goto IN009;

      *v_fill += len;
      ITC_OWNS_PARAM (ins_itc, str);
      ITC_SEARCH_PARAM (ins_itc, str);
      break;
    case DV_BIN:
      {
	if (dtp != DV_BIN)
	  {
	    data = box_cast_to (ins_itc->itc_out_state, data, dtp, DV_BIN, 0, 0, err_ret);
	    ITC_OWNS_PARAM (ins_itc, data);
	    if (*err_ret)
	      return;
	  }

	len = box_length (data);

	if (len + *v_fill > max)
	  goto IN009;
	*v_fill += len;
	if (ins_itc)
	  ITC_SEARCH_PARAM (ins_itc, data);
      }
      break;
    case DV_SINGLE_FLOAT:
      {
	double df = box_to_double (data, dtp, cl->cl_col_id, err_ret, key);
	float ft = (float) df;
	if (ins_itc)
	  {
	    caddr_t _box_float = box_float (ft);
	    ITC_SEARCH_PARAM (ins_itc, _box_float);
	    ITC_OWNS_PARAM (ins_itc, _box_float);
	  }
	return;
      }

    case DV_DOUBLE_FLOAT:
      {
	double df = box_to_double (data, dtp, cl->cl_col_id, err_ret, key);
	if (ins_itc)
	  {
	    caddr_t _box_double = box_double (df);
	    ITC_SEARCH_PARAM (ins_itc, _box_double);
	    ITC_OWNS_PARAM (ins_itc, _box_double);
	  }
	return;
      }

    case DV_DATE:
      if (DV_DATETIME != dtp)
	{
convert_dt:
	  data = box_cast_to (ins_itc ? ins_itc->itc_out_state : NULL, data, dtp,
	      cl->cl_sqt.sqt_col_dtp, 0, 0, err_ret);
	  if (ins_itc)
	    ITC_OWNS_PARAM (ins_itc, data);
	  if (*err_ret)
	    return;

	  if (ins_itc)
	    {
	      ITC_SEARCH_PARAM (ins_itc, data);
	    }
	  else
	    dk_free_box (data);
	}
      else
	{
	  if (ins_itc)
	    {
	      caddr_t dt_box = box_copy (data);
	      dt_date_round ((char *) dt_box);
	      ITC_SEARCH_PARAM (ins_itc, dt_box);
	      ITC_OWNS_PARAM (ins_itc, dt_box);
	    }
	}
      break;
    case DV_DATETIME:
    case DV_TIME:
      if (DV_DATETIME != dtp)
	goto convert_dt;
      if (ins_itc)
	{
	  caddr_t dt_box = box_copy (data);
	        /*DT_SET_FRACTION (dt_box, 0);*/
      SET_DT_TYPE_BY_DTP (dt_box, cl->cl_sqt.sqt_col_dtp);
      ITC_SEARCH_PARAM (ins_itc, dt_box);
	  ITC_OWNS_PARAM (ins_itc, dt_box);
	}
      break;

    case DV_TIMESTAMP:
      if (DV_DATETIME != dtp)
	goto convert_dt;

      if (ins_itc)
	ITC_SEARCH_PARAM (ins_itc, data);
      break;
    case DV_BLOB:
    case DV_BLOB_BIN:
      {
	int rc;
	blob_layout_t * old_bl = NULL;

	if (cl->cl_sqt.sqt_class)
	  {
	    udt_can_write_to (&cl->cl_sqt, data, err_ret);
	    if (err_ret && *err_ret)
	      return;
	  }
	else if (DV_OBJECT == dtp || DV_REFERENCE == dtp)
	  {
	    char* cl_name;
            xml_entity_t *xe;
	    if (DV_OBJECT != dtp)
	      goto utd_in_blob_error; /* see below */
	    xe = XMLTYPE_TO_ENTITY(data);
	    if (NULL == xe)
	      goto utd_in_blob_error; /* see below */
	    data = (caddr_t) xe;
	    dtp = DV_TYPE_OF(data);
	    goto xmltype_in_blob_ok; /* see below */

utd_in_blob_error:
	    cl_name = __get_column_name (cl->cl_col_id, key);
	    *err_ret = srv_make_new_error ("23000",
		"SR353",
		"Type mismatch inserting user defined type instance "
		"as a blob for column [%.*s]",
		MAX_NAME_LEN, cl_name);
	    return;

xmltype_in_blob_ok: ;
	  }

	if (!data)
	  {
            if (key->key_table)
              {
	        char* cl_name = __get_column_name (cl->cl_col_id, key);
	        *err_ret = srv_make_new_error ("23000", "SR246",
		    "Type mismatch inserting %.*s as a blob for column '%.*s.%.*s'",
		    MAX_NAME_LEN, dv_type_title (dtp), 3 * MAX_NAME_LEN, key->key_table->tb_name,
		    MAX_NAME_LEN, cl_name);
	      }
	    else
	      *err_ret = srv_make_new_error ("23000", "SR246",
		  "Type mismatch inserting %.*s as a blob for temp column",
		  MAX_NAME_LEN, dv_type_title (dtp));
	    return;
	  }

	if (old_blob && IS_BLOB_DTP (*old_blob))
	  old_bl = bl_from_dv (old_blob, ins_itc);
	pos = *v_fill;
	if (cl->cl_sqt.sqt_is_xml && XE_IS_VALID_VALUE_FOR_XML_COL (data))
	  {
	    dk_session_t *strses;
	    int data_are_temp;
	    caddr_t tree1;
	    dtd_t *dtd = NULL;
	    if (DV_XML_ENTITY == dtp)
	      {
	        tree1 = (caddr_t)(((xml_tree_ent_t *)data)->xte_current);
	        dtd = ((xml_tree_ent_t *)data)->xe_doc.xd->xd_dtd;
	        data_are_temp = 0;
	      }
	    else
	      {
		caddr_t volatile charset = (caddr_t)(QST_CHARSET (rd->rd_qst) ? QST_CHARSET (rd->rd_qst) : default_charset);
	        static caddr_t dtd_config = NULL;
		if (NULL == dtd_config)
		  dtd_config = box_dv_short_string ("Validation=DISABLE Include=DISABLE IdCache=ENABLE SignalOnError=ENABLE");
          	tree1 = xml_make_mod_tree ((query_instance_t *) rd->rd_qst, data, err_ret, GE_XML, NULL, CHARSET_NAME (charset, NULL), server_default_lh, dtd_config, &dtd, NULL, NULL);
		if (!tree1)
		  return;
		data_are_temp = 1;
	      }
	    strses = strses_allocate ();
	    xte_serialize_packed ((caddr_t *)tree1, dtd, strses);
	    rc = itc_set_blob_col (ins_itc, blob_temp, (caddr_t)strses, old_bl,
	      old_blob ? BLOB_IN_UPDATE : BLOB_IN_INSERT, &cl->cl_sqt);
	    strses_free (strses);
	    if (data_are_temp)
	      {
	        dk_free_tree (tree1);
	        dtd_free (dtd);
	      }
	  }
	else
	  rc = itc_set_blob_col (ins_itc, blob_temp, data, old_bl,
	    old_blob ? BLOB_IN_UPDATE : BLOB_IN_INSERT, &cl->cl_sqt);
	if (LTE_OK != rc)
	  {
	    char* cl_name;
	    dtp_t dtp;
	    if (-1 == rc)
	      goto null_as_blob_from_client;
	    cl_name = __get_column_name (cl->cl_col_id, key);
	    dtp = (dtp_t)DV_TYPE_OF (data);
	    *err_ret = srv_make_new_error ("23000", "SR246",
		"Error or type mismatch inserting a blob for column [%.*s] from type %.*s",
		MAX_NAME_LEN, cl_name, MAX_NAME_LEN, dv_type_title (dtp));
	  }
      }
      blob_box = box_dv_short_nchars ((caddr_t)blob_temp, DV_BLOB_LEN);
      ITC_SEARCH_PARAM (ins_itc, blob_box);
      ITC_OWNS_PARAM (ins_itc, blob_box);
      *v_fill += DV_BLOB_LEN;
      break;
    case DV_BLOB_WIDE:
      {
	int rc;
	blob_layout_t * old_bl = NULL;

	if (!data)
	  {
	    char* cl_name = __get_column_name (cl->cl_col_id, key);
	    *err_ret = srv_make_new_error ("23000", "SR246",
		"Type mismatch inserting %.*s as a blob for column [%.*s]",
		MAX_NAME_LEN, dv_type_title (dtp), MAX_NAME_LEN, cl_name);
	    return;
	  }
	if (DV_STRING == dtp)
	  {
	    data = box_cast_to (ins_itc->itc_out_state, data, DV_TYPE_OF (data), DV_LONG_WIDE, 0, 0, err_ret);
	    ITC_OWNS_PARAM (ins_itc, data);
	    if (*err_ret)
	      return;
	  }
	else if (DV_OBJECT == dtp || DV_REFERENCE == dtp)
	  {
	    char* cl_name = __get_column_name (cl->cl_col_id, key);
	    *err_ret = srv_make_new_error ("23000",
		"SR353",
		"Type mismatch inserting user defined type instance "
		"as a blob for column [%.*s]",
		MAX_NAME_LEN, cl_name);
	    return;
	  }

	if (old_blob && IS_BLOB_DTP (*old_blob))
	  old_bl = bl_from_dv (old_blob, ins_itc);
	rc = itc_set_blob_col (ins_itc, blob_temp, data, old_bl, old_blob ? BLOB_IN_UPDATE : BLOB_IN_INSERT, &cl->cl_sqt);
	if (LTE_OK != rc)
	  {
	    char* cl_name;
	    dtp_t dtp;
	    if (-1 == rc)
	      goto null_as_blob_from_client;
	    cl_name = __get_column_name (cl->cl_col_id, key);
	    dtp = (dtp_t)DV_TYPE_OF (data);
	    *err_ret = srv_make_new_error ("23000", "SR246",
		"Error or type mismatch inserting a wide blob for column [%.*s] from type %.*s",
		MAX_NAME_LEN, cl_name, MAX_NAME_LEN, dv_type_title (dtp));
	  }
	blob_box = box_dv_short_nchars ((char*)blob_temp, DV_BLOB_LEN);
	ITC_SEARCH_PARAM (ins_itc, blob_box);
	ITC_OWNS_PARAM (ins_itc, blob_box);
	*v_fill += DV_BLOB_LEN;
      }
      break;
    default:
      {
	char* cl_name = __get_column_name (cl->cl_col_id, key);
	const char* dtp_name = dv_type_title (dtp);
	*err_ret = srv_make_new_error ("23000", "SR326",
	    "Column data type %.*s not supported [%.*s]",
	    MAX_NAME_LEN, dtp_name, MAX_NAME_LEN, cl_name);
      }
      break;
    }
  return;
IN009:
  {
    char* cl_name = __get_column_name (cl->cl_col_id, key);
    *err_ret = srv_make_new_error ("22005", "IN009",
        "Max row length of column [%.*s] exceeded",
        MAX_NAME_LEN, cl_name);
    return;
  }
null_as_blob_from_client:
  if (!IS_BLOB_HANDLE_DTP (DV_TYPE_OF (data)))
    GPF_T;
  else
    {
      caddr_t tmp_null = dk_alloc_box (0, DV_DB_NULL);
      ITC_SEARCH_PARAM (ins_itc, tmp_null);
      ITC_OWNS_PARAM (ins_itc, tmp_null);
    }
}

#define MARK_SET_INT(dtp, v)			\
  if (rf->rf_pf_hash && cl->cl_row_version_mask && \
      (rf->rf_pf_hash->pfh_kv == IE_KEY_VERSION (rf->rf_row) ||PFH_KV_ANY == rf->rf_pf_hash->pfh_kv)) \
    { \
      if (PFH_KV_ANY == rf->rf_pf_hash->pfh_kv) \
	rf->rf_pf_hash->pfh_kv = IE_KEY_VERSION (rf->rf_row); \
      pfh_set_##dtp (rf->rf_pf_hash, v, cl->cl_nth, rf->rf_map_pos, (rf->rf_row + cl->cl_pos[rv]) - rf->rf_pf_hash->pfh_page); \
  }

void
row_set_col (row_fill_t * rf, dbe_col_loc_t * cl, caddr_t data)
{
  dbe_key_t * key = rf->rf_key;
  db_buf_t row = rf->rf_row;
  caddr_t str;
  dtp_t rv = IE_ROW_VERSION (row);
  dtp_t dtp = DV_TYPE_OF (data);
  int len;
  int64 vi64;
  iri_id_t ii;
  if (DV_DB_NULL == dtp)
    {
      row[cl->cl_null_flag[rv]] |= cl->cl_null_mask[rv];
      if (cl->cl_fixed_len > 0)
	{
	  memset (row + cl->cl_pos[rv], 0xff, cl->cl_fixed_len); /* *fill null w/ ff just for debug */
	  return;
	}
      else if (CL_FIRST_VAR == cl->cl_pos[rv])
	{
	  SHORT_SET (row + key->key_length_area[rv], rf->rf_fill);
	}
      else
	{
	  SHORT_SET ((row - cl->cl_pos[rv]) + 2, rf->rf_fill);
	}
      return;
    }
  else
    {
      if (cl->cl_null_mask[rv])
	{
	  row[cl->cl_null_flag[rv]] &= ~cl->cl_null_mask[rv];
	}
    }
  switch (cl->cl_sqt.sqt_dtp)
    {
    case DV_LONG_INT:
      LONG_SET (row + cl->cl_pos[rv], len = unbox_inline (data));
      MARK_SET_INT (int, len);
      break;
    case DV_INT64:
      vi64 = unbox_inline (data);
      INT64_SET (row + cl->cl_pos[rv], vi64);
      MARK_SET_INT (int64, vi64);
      break;
    case DV_SHORT_INT:
      SHORT_SET (row + cl->cl_pos[rv], ((short) unbox_inline (data)));
      break;
    case DV_IRI_ID:
      LONG_SET (row + cl->cl_pos[rv], ii = unbox_iri_id (data));
      MARK_SET_INT (int, ii);
      break;
    case DV_IRI_ID_8:
      ii = unbox_iri_id (data);
      INT64_SET (row + cl->cl_pos[rv], ii);
      MARK_SET_INT (int64, ii);
      break;
    case DV_NUMERIC:
      {
	dtp_t tmp[258];
	numeric_to_dv ( (numeric_t) data, tmp, sizeof (tmp));
	memcpy (row + cl->cl_pos[rv], &tmp[1], cl->cl_fixed_len);
	break;
      }

    case DV_ANY:
    case DV_OBJECT:
    case DV_STRING:
    case DV_WIDE:
    case DV_LONG_WIDE:
    case DV_BIN:
    case DV_BLOB: case DV_BLOB_WIDE:
    case DV_BLOB_BIN:

      str = data;
      len = box_length (str) - 1;
      if (DV_BIN == dtp)
	len += 1;
      RF_LARGE_CHECK (rf, rf->rf_fill, len);
      memcpy (row + rf->rf_fill, str, len);
      if (cl->cl_row_version_mask && rf->rf_pf_hash
	  && (rf->rf_pf_hash->pfh_kv == IE_KEY_VERSION (rf->rf_row) || PFH_KV_ANY == rf->rf_pf_hash->pfh_kv))
	{
	  if (PFH_KV_ANY == rf->rf_pf_hash->pfh_kv)
	    rf->rf_pf_hash->pfh_kv = IE_KEY_VERSION (rf->rf_row);
	  pfh_set_var (rf->rf_pf_hash, cl, rf->rf_map_pos, rf->rf_row + rf->rf_fill, len);
	}
      rf->rf_fill += len;
      if (CL_FIRST_VAR == cl->cl_pos[rv])
	SHORT_SET (row + key->key_length_area[rv], rf->rf_fill);
      else
	SHORT_SET ((row - cl->cl_pos[rv]) + 2, rf->rf_fill);
      break;

    case DV_SINGLE_FLOAT:
      {
	double df = unbox_float (data);
	float ft = (float) df;
	FLOAT_TO_EXT (row + cl->cl_pos[rv], &ft);
	return;
      }

    case DV_DOUBLE_FLOAT:
      {
	double df = unbox_double (data);
	DOUBLE_TO_EXT (row + cl->cl_pos[rv], &df);
	return;
      }

    case DV_DATE:
    case DV_DATETIME:
    case DV_TIME:
    case DV_TIMESTAMP:
      memcpy (row + cl->cl_pos[rv], data, DT_LENGTH);
      break;

    default:
      GPF_T1 ("not a settable cl dtp");
    }
  return;
}


void
row_set_prefix (row_fill_t * rf, dbe_col_loc_t * cl, caddr_t value, row_size_t prefix_bytes, unsigned short prefix_ref, dtp_t extra)
{
  db_buf_t row = rf->rf_row;
  row_ver_t rv = IE_ROW_VERSION (row);
  int len = box_length_on_row (value), head = 2;
  ROW_CLR_NULL (row, cl, rv);
  if (prefix_bytes >> COL_OFFSET_SHIFT == 15)
    {
      head = 3;
      prefix_bytes = extra;
      prefix_ref = 0xf000 | prefix_ref;
    }
  else
    {
      prefix_bytes = prefix_bytes & 0xf000;
      prefix_ref = prefix_ref | prefix_bytes;
      prefix_bytes = prefix_bytes >> COL_OFFSET_SHIFT;
      head = 2;
    }
  RF_LARGE_CHECK (rf, rf->rf_fill, len + head - prefix_bytes);
  SHORT_SET_NA (row + rf->rf_fill, prefix_ref);
  if (3 == head)
    row[rf->rf_fill + 2] = extra;
  memcpy (row + rf->rf_fill + head, value + prefix_bytes, len - prefix_bytes);
  rf->rf_fill += len + head - prefix_bytes;
  if (CL_FIRST_VAR == cl->cl_pos[rv])
    SHORT_SET (row + rf->rf_key->key_length_area[rv], rf->rf_fill | COL_VAR_SUFFIX);
  else
    SHORT_SET ((row - cl->cl_pos[rv]) + 2, rf->rf_fill | COL_VAR_SUFFIX);
}


#define IS_STRING_OR_BIN_DTP(d) (IS_STRING_DTP (d) || DV_BIN == dtp)


void
row_insert_cast_temp (row_delta_t * rd, dbe_col_loc_t * cl, caddr_t data,
		      caddr_t * err_ret, db_buf_t old_blob)
{
  /* as if row_insert_cast but store a blob handle by reference, no copy */
  int max = rd->rd_non_comp_max;
  unsigned short * v_fill = &rd->rd_non_comp_len;
  if (IS_BLOB_DTP (cl->cl_sqt.sqt_dtp))
    {
      dtp_t dtp = DV_TYPE_OF (data);
      switch (dtp)
	{
	case DV_BLOB_HANDLE:
	case DV_BLOB_WIDE_HANDLE:
	case DV_BLOB_XPER_HANDLE:
	  {
	    caddr_t box;
	    if (KI_TEMP != rd->rd_key->key_id)
	      GPF_T1 ("putting a blob by ref  into a non temp key");
	    if ((int) (DV_BLOB_LEN + *v_fill) > max)
	      {
		*err_ret = srv_make_new_error ("22026", "SR319",
						"Max row length of column [temp] exceeded");
		return;
	      }
	    if (BH_FROM_CLUSTER ((blob_handle_t*)data))
	      goto general_case;
	    box = dk_alloc_box (DV_BLOB_LEN + 1, DV_STRING);
	    bh_to_dv ((blob_handle_t *) data, (db_buf_t)box, DV_BLOB_DTP_FOR_BLOB_HANDLE_DTP (dtp));
	    rd->rd_non_comp_len += DV_BLOB_LEN;
	    ITC_SEARCH_PARAM (rd->rd_itc, box);
	    ITC_OWNS_PARAM (rd->rd_itc, box);
	    break;
	  }
	case DV_OBJECT:
	case DV_REFERENCE:
	  { /* an LONG <gizmo> object serialization case. That writes a temp blob */
	    row_insert_cast (rd, cl, data, err_ret, old_blob);
	    break;
	  }

	case DV_XML_ENTITY:
	  if (cl->cl_sqt.sqt_is_xml)
	    { /* an LONG XML case. put it in as temp blob if the column is of the right kind */
	      row_insert_cast (rd, cl, data, err_ret, old_blob);
	      break;
	    }
	default:
	  {
	    /* a non-blob is assigned to a blob. will generally be an inlined blob.  Place the dtp at the head */
	    int space = rd->rd_non_comp_max - rd->rd_non_comp_len;
	    dtp_t cdtp = cl->cl_sqt.sqt_dtp;
	    if (IS_INLINEABLE_DTP (cdtp)
		&& (IS_STRING_OR_BIN_DTP (dtp) && box_length (data) <= space))
	      {
		int n_bytes = box_col_len (data);
		caddr_t inl = dk_alloc_box (2 + n_bytes, DV_STRING);
		inl[0] = DV_STRING;
		memcpy (inl + 1, data, n_bytes);
		inl[n_bytes + 1] = 0;
		ITC_SEARCH_PARAM (rd->rd_itc, inl);
		ITC_OWNS_PARAM (rd->rd_itc, inl);
	      }
	    else
	      row_insert_cast (rd, cl, data, err_ret, old_blob);
	    break;
	  }
	}
    }
  else
    {
    general_case:
      row_insert_cast (rd, cl, data, err_ret, old_blob);
    }
}


void
itc_delete_blob_search_pars (it_cursor_t * itc, row_delta_t * rd)
{
  DO_CL (cl, itc->itc_row_key->key_row_var)
    {
      if (IS_BLOB_DTP (cl->cl_sqt.sqt_dtp)
	  && DV_STRING == DV_TYPE_OF (rd->rd_values[cl->cl_nth])
	  && IS_BLOB_DTP (((db_buf_t)rd->rd_values[cl->cl_nth])[0]))
	{
	  blob_layout_t * bl = bl_from_dv ((db_buf_t)rd->rd_values[cl->cl_nth], itc);
	  blob_log_replace (itc, bl);
	  blob_schedule_delayed_delete (itc, bl, BL_DELETE_AT_COMMIT );
	}
    }
  END_DO_CL;
}


int
key_insert (insert_node_t * ins, caddr_t * qst, it_cursor_t * it, ins_key_t * ik)
{
  row_delta_t rd;
  int col_ctr = 0;
  caddr_t err = NULL;
  buffer_desc_t *unq_buf;
  buffer_desc_t **unq_buf_ptr = NULL;
  int inx = 0, rc;
  dbe_key_t * key = ik->ik_key;
  query_instance_t * qi = (query_instance_t *) qst;
  QI_CHECK_STACK (qi, &qst, INS_STACK_MARGIN);
  cl_enlist_ck (it, NULL);
  memset (&rd, 0, sizeof (row_delta_t));
  rd.rd_allocated = RD_AUTO;
  rd.rd_key = key;
  rd.rd_op = RD_INSERT;
  rd.rd_non_comp_len = key->key_row_var_start[0];
  rd.rd_non_comp_max = MAX_ROW_BYTES;
  rd.rd_itc = it;
  rd.rd_qst = qst;
  it->itc_tree = key->key_fragments[0]->kf_it;
  it->itc_key_spec = key->key_insert_spec;
  it->itc_out_state = qst;
  it->itc_non_txn_insert = qi->qi_non_txn_insert;
  itc_free_owned_params (it);
  ITC_START_SEARCH_PARS (it);
  it->itc_search_par_fill = key->key_n_significant;
  if (!key->key_parts)
    sqlr_new_error ("42S11", "SR119", "Key %.300s has 0 parts. Create index probably failed",
	key->key_name);

  DO_CL (cl, key->key_key_fixed)
    {
      caddr_t data = QST_GET (qst, ik->ik_slots[inx]);
      row_insert_cast (&rd, cl, data, &err, NULL);
      if (err)
	break;
      inx++;
    }
  END_DO_CL;
  if (err)
    {
      itc_free_owned_params (it);
      sqlr_resignal (err);
    }
  DO_CL (cl, key->key_key_var)
    {
      caddr_t data = QST_GET (qst, ik->ik_slots[inx]);
      row_insert_cast (&rd, cl, data, &err, NULL);
      if (err)
	break;
      inx++;
    }
  END_DO_CL;
  if (err)
    {
      itc_free_owned_params (it);
      sqlr_resignal (err);
    }

  if (rd.rd_non_comp_len - key->key_row_var_start[0] + key->key_key_var_start[0] > MAX_RULING_PART_BYTES)
    {
      itc_free_owned_params (it);
      sqlr_error ("22026", "Key is too long, index %.300s, ruling part is %d bytes that exceeds %d byte limit",
        key->key_name, (rd.rd_non_comp_len - key->key_row_var_start[0] + key->key_key_var_start[0]), MAX_RULING_PART_BYTES );
    }

  col_ctr = inx;
  if (key->key_is_col)
    {
      dbe_col_loc_t cl;
      int l;
      dk_set_t parts = key->key_parts;
      for (l = 0; l < key->key_n_significant; l++)
	parts = parts->next;
      DO_SET (dbe_column_t *, col, &parts)
	{
	  caddr_t data = QST_GET (qst, ik->ik_slots[col_ctr]);
	  cl.cl_col_id = col->col_id;
	  cl.cl_sqt = col->col_sqt;
	  cl.cl_null_mask[0] = !col->col_sqt.sqt_non_null;
	  row_insert_cast (&rd, &cl, data, &err, NULL);
	  col_ctr++;
	  if (err)
	    {
	      itc_free_owned_params (it);
	      sqlr_resignal (err);
	    }
	}
      END_DO_SET();
    }
  else
    {
  for (inx = 0; key->key_row_fixed[inx].cl_col_id; inx++)
    {
      caddr_t data = QST_GET (qst, ik->ik_slots[col_ctr + inx]);
      row_insert_cast (&rd, &key->key_row_fixed[inx], data, &err, NULL);
      if (err)
	break;
    }
  col_ctr += inx;
  if (err)
    {
      itc_free_owned_params (it);
      sqlr_resignal (err);
    }
      itc_from_keep_params (it, key, qi->qi_client->cli_slice);  /* fragment needs to be known before setting blobs */
  for (inx = 0; key->key_row_var[inx].cl_col_id; inx++)
    {
      caddr_t data;
      if (CI_BITMAP == key->key_row_var[inx].cl_col_id)
	break; /* the bitmap string of a bm inx row is always the last */
      data = QST_GET (qst, ik->ik_slots[col_ctr + inx]);
      row_insert_cast (&rd, &key->key_row_var[inx], data, &err, NULL);
      if (err)
	break;
    }
  if (err)
    {
      itc_free_owned_params (it);
      sqlr_resignal (err);
    }
    }
  rd.rd_values = &it->itc_search_params[key->key_n_significant];
  rd.rd_n_values = it->itc_search_par_fill - key->key_n_significant;
  /* now the cols are in layout order, kf kv rf rv.  Put them now at the head in key order */
  for (inx = 0; inx < key->key_n_significant; inx++)
    {
    it->itc_search_params[inx] = it->itc_search_params[key->key_n_significant + key->key_part_in_layout_order[inx]];
      if (key->key_not_null && DV_DB_NULL == DV_TYPE_OF (it->itc_search_params[inx]))
	{
	  itc_free_owned_params (it);
	  return DVC_LESS;
	}
    }
  if (key->key_is_primary)
    {
      rd_inline (qi, &rd, &err, BLOB_IN_INSERT);
      if (err)
	{
	  itc_free_owned_params (it);
	  sqlr_resignal (err);
	}
      unq_buf_ptr = &unq_buf;
    }
  it->itc_insert_key = key;
  if (key->key_is_bitmap)
    {
      if (!qi->qi_non_txn_insert)
	rd.rd_make_ins_rbe = 1;
      ITC_SAVE_FAIL (it);
      key_bm_insert (it, &rd);
      ITC_RESTORE_FAIL (it);
      itc_free_owned_params (it);
      return DVC_LESS;
    }
  if (KI_TEMP != key->key_id && !qi->qi_non_txn_insert)
    rd.rd_make_ins_rbe = 1;
  if (key->key_is_col)
    {
      key_col_insert (it, &rd, ins);
      rc = DVC_LESS;
    }
  else
  rc = itc_insert_unq_ck (it, &rd, unq_buf_ptr);
  if (DVC_MATCH == rc)
    {
      /* duplicate */
      switch (ins->ins_mode)
	{
	case INS_REPLACING:
	  if (key->key_is_primary)
	    log_insert (it->itc_ltrx, &rd, (ins->ins_key_only ? LOG_KEY_ONLY : 0) | ins->ins_mode
			| (qi->qi_non_txn_insert ? LOG_SYNC : 0));
	  QI_ROW_AFFECTED (QST_INSTANCE (qst));
	  itc_replace_row (it, unq_buf, &rd, qst, 0);
	  itc_free_owned_params (it);
	  return DVC_MATCH;

	case INS_NORMAL:
	case INS_SOFT:

	  /* leave and return */
	  itc_page_leave (it, unq_buf);
	  if (ins->ins_mode == INS_SOFT && key->key_is_primary)
	    {
	      it->itc_map_pos = ITC_AT_END;
	      it->itc_row_key = key;
	      itc_delete_blob_search_pars (it, &rd);
	      log_insert (it->itc_ltrx, &rd, (ins->ins_key_only ? LOG_KEY_ONLY : 0) | ins->ins_mode
			  | (qi->qi_non_txn_insert ? LOG_SYNC : 0));
	    }
	  else
	    if (key->key_table->tb_any_blobs)
	      TRX_POISON (it->itc_ltrx);
	  itc_free_owned_params (it);
	  return DVC_MATCH;
	}
      return DVC_MATCH;
    }

  if (key->key_is_primary || ins->ins_key_only)
    {
      log_insert (it->itc_ltrx, &rd, (ins->ins_key_only ? LOG_KEY_ONLY : 0) | ins->ins_mode
		  | (qi->qi_non_txn_insert ? LOG_SYNC : 0));
    }
  return DVC_LESS;		/* normal insert OK. */
}

#undef image



void
itc_drop_index_slice (it_cursor_t * itc, dbe_key_t * key, slice_id_t slice)
{
  /* this is locally autocommitting, sometimes run in atomic mode.  Preserve the lt_w_id */
  dp_addr_t prev_dp = 0;
  int ctr = 0, rc;
  buffer_desc_t *del_buf;
  int was_col = key->key_is_col;
  itc_from (itc, key, slice);
  itc->itc_lock_mode = PL_EXCLUSIVE;
  itc->itc_isolation = ISO_SERIALIZABLE;
  itc->itc_n_lock_escalations = 100; /* lock pages from the start */
  itc->itc_no_bitmap = 1;
  ITC_FAIL (itc)
  {
    del_buf = itc_reset (itc);
    itc->itc_is_col = 0;
    key->key_is_col = 0; /* the col pages are freed here, the commits will go as for row-wise deleting the entries on leaf pages, all the rest is as for row-wise */
    FAILCK (itc);
    while (DVC_MATCH == itc_next (itc, &del_buf))
      {
	if (key->key_is_col && prev_dp != itc->itc_page)
	  {
	    itc_col_page_free (itc, del_buf, -1);
	  }
	itc_delete (itc, &del_buf, key->key_is_col ? 0 : MAYBE_BLOBS);
	itc->itc_is_on_row = 0;
	ITC_LEAVE_MAPS (itc);
	ctr++;
	if (ctr > 10000 && itc->itc_page != prev_dp)
	  {
	    itc_register (itc, del_buf);
	    itc_page_leave (itc, del_buf);
	    IN_TXN;
	    rc = lt_commit (itc->itc_ltrx, TRX_CONT);
	    LEAVE_TXN;
	    if (LTE_OK != rc)
	      {
		itc_unregister (itc);
		return;
	      }
	    del_buf = page_reenter_excl (itc);
	  }
	prev_dp = itc->itc_page;
      }
    dbg_printf (("Deleted %d keys.\n", ctr));
    itc_page_leave (itc, del_buf);
  }
  ITC_FAILED
  {
    itc->itc_is_col = was_col;
    itc_free (itc);
  }
  END_FAIL (itc);
  itc->itc_is_col = was_col;
}

void
itc_drop_index (it_cursor_t * itc, dbe_key_t * key)
{
    itc_drop_index_slice (itc, key, QI_NO_SLICE);
}


int
key_col_ref_pos (dbe_key_t * key, dbe_column_t * col)
{
  int nth;
  for (nth = 0; key->key_row_var[nth].cl_col_id; nth++)
    {
      if (col->col_id == key->key_row_var[nth].cl_col_id)
	return nth;
    }
  return -1;
}




void
rd_col_change (it_cursor_t * itc, buffer_desc_t * buf, row_delta_t * rd, dbe_column_t * col, int is_drop, buffer_desc_t ** col_buf_ret, caddr_t deflt)
{
  caddr_t * values;
  if (is_drop)
    {
      int nth = key_col_ref_pos (rd->rd_key, col) + rd->rd_key->key_n_significant;
      values = (caddr_t*)dk_alloc_box (box_length (rd->rd_values) - sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      memcpy (values, rd->rd_values, nth * sizeof (caddr_t));
      memcpy (values + nth, rd->rd_values + (1 + nth), box_length (rd->rd_values) - (1 + nth) * sizeof (caddr_t));
      dk_free_box (rd->rd_values);
      rd->rd_values = values;
      rd->rd_n_values--;
    }
  else
    {
      caddr_t ref_str;
      page_map_t * pm;
      int n_rows = itc_rows_in_seg (itc, buf);
      buffer_desc_t * col_buf = *col_buf_ret;
      int len = box_length (deflt) - 1 + 3, fill, nth;
      itc_col_leave (itc, 0);
      if (col_buf && col_buf->bd_content_map->pm_bytes_free < len)
	{
	  page_leave_outside_map (col_buf);
	  col_buf = NULL;
	}
      if (!col_buf)
	*col_buf_ret = col_buf = it_new_col_page (itc->itc_tree, 0, 0, col);
      pm = col_buf->bd_content_map;
      fill = pm->pm_filled_to;
      map_append (col_buf, &col_buf->bd_content_map, fill);
      map_append (col_buf, &col_buf->bd_content_map, n_rows);
      pm = col_buf->bd_content_map;
      pm->pm_bytes_free -= len;
      col_buf->bd_buffer[fill] = CET_ANY | CE_RL;
      SHORT_SET_CA (col_buf->bd_buffer + fill + 1, n_rows);
      memcpy (col_buf->bd_buffer + fill + 3, deflt, box_length (deflt) - 1);
      cs_write_gap (col_buf->bd_buffer + fill + len, PAGE_SZ - (fill + len));
      pm->pm_filled_to += len;
      ref_str = dk_alloc_box (1 + sizeof (dp_addr_t) + CPP_DP, DV_STRING);
      ref_str[0] = DV_BLOB;
      SHORT_SET_NA (ref_str + CPP_FIRST_CE, (pm->pm_count - 2) / 2);
      SHORT_SET_NA (ref_str + CPP_N_CES, 1);
      LONG_SET_NA (ref_str + CPP_DP, col_buf->bd_page);
      nth = key_col_ref_pos (itc->itc_insert_key, col) + rd->rd_key->key_n_significant;
      values = (caddr_t*)dk_alloc_box (box_length (rd->rd_values) + sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      memcpy (values , rd->rd_values, nth * sizeof (caddr_t));
      values[nth] = ref_str;
      if (BOX_ELEMENTS (rd->rd_values) > nth)
	memcpy (values + nth + 1, rd->rd_values + nth, box_length (rd->rd_values) - nth * sizeof (caddr_t));
      dk_free_box ((caddr_t)rd->rd_values);
      rd->rd_values = values;
      rd->rd_n_values = BOX_ELEMENTS (values);
    }
}


dbe_column_t *
key_find_col (dbe_key_t * key, caddr_t find_name, int is_dropped)
{
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      char name[MAX_NAME_LEN + 20];
      char num[30];
      if (is_dropped)
	{
	  int num_len, len = strlen (col->col_name);
	  snprintf (num, sizeof (num), "__%d", (int)col->col_id);
	  num_len = strlen (num);
	  if (num_len > len)
	    continue;
	  if (0 == strncmp (col->col_name + len -
	  num_len, num, num_len))
	    {
	      strncpy (name, col->col_name, sizeof (name));
	      name[len - num_len] = 0;
	      if (0 == CASEMODESTRCMP (name, find_name))
		return col;
	    }
	}
      else if (0 == CASEMODESTRCMP (col->col_name, find_name))
	  return col;
    }
  END_DO_SET();
  return NULL;
}


void
it_key_col_ddl (index_tree_t *it, dbe_key_t * key, dbe_column_t * col, int is_drop)
{
  ce_ins_ctx_t ceic;
  placeholder_t * pl;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  buffer_desc_t * col_buf = NULL;
  buffer_desc_t * buf;
  dp_addr_t prev_dropped = 0;
  caddr_t err = NULL;
  caddr_t deflt = is_drop ? NULL : box_to_any (col->col_default, &err);
  ITC_INIT (itc, NULL, NULL);
  itc_from_it (itc, it);
  itc->itc_insert_key = key;
  itc_col_init (itc);
  ITC_FAIL (itc)
  {
    buf = itc_reset (itc);
    itc->itc_is_col = 0;
    while (DVC_MATCH == itc_next (itc, &buf))
      {
	int r;
	for (;;)
	  {
	    dk_set_t rds = NULL;
	    row_delta_t ** rd_array;
	    page_map_t * pm = buf->bd_content_map;
	    for (r = 0; r < pm->pm_count; r++)
	      {
		db_buf_t row = BUF_ROW (buf, r);
		key_ver_t kv = IE_KEY_VERSION (row);
		if (kv != KV_LEAF_PTR && kv != KV_LEFT_DUMMY && kv != key->key_version)
		  {
		    dbe_key_t * row_key = key->key_versions[kv];
		    NEW_VARZ (row_delta_t, rd);
		    rd->rd_allocated = RD_ALLOCATED;
		    rd->rd_values = (caddr_t*)dk_alloc_box_zero (row_key->key_n_parts * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
		    page_row_bm (buf, r, rd, RO_ROW, NULL);
		    rd->rd_op = RD_UPDATE;
		    rd->rd_map_pos = r;
		    rd->rd_keep_together_pos = r;
		    rd->rd_keep_together_dp = buf->bd_page;
		    itc->itc_map_pos = r;
		    rd_col_change (itc, buf, rd, col, is_drop, &col_buf, deflt);
		    rd->rd_key = key;
		    dk_set_push (&rds, (void*)rd);
		    if (is_drop && buf->bd_page != prev_dropped)
		      {
			int nth = key_col_ref_pos (row_key, col);
			if (-1 == nth)
			  continue;
			itc_col_page_free (itc, buf, nth);
			prev_dropped = buf->bd_page;
		      }
		  }
	      }
	    if (!rds)
	      {
		itc->itc_map_pos = pm->pm_count - 1;
		itc->itc_is_on_row = 1;
		break;
	      }
	    itc->itc_map_pos = pm->pm_count - 1;
	    itc->itc_is_on_row = 1;
	    if (col_buf)
	      page_leave_outside_map (col_buf);
	    col_buf = NULL;
	    pl = plh_landed_copy ((placeholder_t*)itc, buf);
	    rd_array = (row_delta_t**)list_to_array (dk_set_nreverse (rds));
	    ITC_DELTA (itc, buf);
	    memzero (&ceic, sizeof (ceic));
	    itc->itc_top_ceic = &ceic;
	    page_apply (itc, buf, BOX_ELEMENTS (rd_array), rd_array, PA_MODIFY | (is_drop ? PA_SPLIT_UNLIKELY : 0));
	    rd_list_free (rd_array);
	    if (ceic.ceic_mp)
	      mp_free (ceic.ceic_mp);
	    buf = itc_set_by_placeholder (itc, pl);
	    itc_unregister_inner ((it_cursor_t*)pl, buf, 0);
	    plh_free (pl);
	  }
      }
    itc_page_leave (itc, buf);
  }
  ITC_FAILED
    {
    }
  END_FAIL (itc);
  itc->itc_is_col = 1;
  itc_free (itc);
  dk_free_box (deflt);
}


caddr_t
bif_key_col_ddl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dbe_key_t * key = bif_key_arg (qst, args, 0, "key_col_ddl");
  caddr_t col_name = bif_string_arg (qst, args, 2, "key_col_ddl");
  int is_drop = bif_long_arg (qst, args, 3, "key_col_ddl");
  QNCAST (QI, qi, qst);
  caddr_t err;
  dbe_column_t * col = NULL;
  caddr_t log_array;
  if (!key->key_is_col)
    return NULL;
  if (qi->qi_u_id != U_ID_DBA)
    sec_check_dba (qi, "__key_col_ddl");
  if (is_drop)
    {
      int kv;
      for (kv = 0; kv < KEY_MAX_VERSIONS; kv++)
	{
	  dbe_key_t * old = key->key_versions[kv];
	  if (old && (col = key_find_col (old, col_name, 1)))
	    break;
	}
    }
  else
    col = key_find_col (key, col_name, 0);
  if (!col)
    sqlr_new_error ("42000",  "CODDL",  "No col %s in %s", col_name, key->key_name);
  if (key->key_storage->dbs_slices)
    {
      DO_LOCAL_CSL (csl, key->key_partition->kpd_map)
	{
	  cli_set_slice (qi->qi_client, key->key_partition->kpd_map, csl->csl_id,&err);
	  it_key_col_ddl (key->key_fragments[csl->csl_id]->kf_it, key, col, is_drop);
	}
      END_DO_LOCAL_CSL;
      cli_set_slice (qi->qi_client, NULL, QI_NO_SLICE, NULL);
    }
  else
    it_key_col_ddl (key->key_fragments[0]->kf_it, key, col, is_drop);
  log_array = list (5, box_string ("__key_col_ddl (?, ?, ?, ?)"),
			    box_string (key->key_table->tb_name), box_dv_short_string (key->key_name), box_dv_short_string (col_name), box_num (is_drop));
  log_text_array (qi->qi_trx, log_array);
  dk_free_tree (log_array);
  return NULL;
}


caddr_t
numeric_from_x (numeric_t res, caddr_t x, int prec, int scale, char * col_name, oid_t cl_id, dbe_key_t *key)
{
  char text [300];
  NUMERIC_VAR (tnum);
  int rc;
  dtp_t dtp = DV_TYPE_OF (x);
  switch (dtp)
    {
    case DV_LONG_INT:
      rc = numeric_from_int64 ((numeric_t) tnum, (int64) unbox (x));
      break;
    case DV_SINGLE_FLOAT:
      rc = numeric_from_double ((numeric_t) tnum, unbox_float (x));
      break;
    case DV_DOUBLE_FLOAT:
      rc = numeric_from_double ((numeric_t) tnum, unbox_double (x));
      break;
    case DV_NUMERIC:
      rc = numeric_copy ((numeric_t) tnum, (numeric_t) x);
      break;
    case DV_WIDE:
    case DV_LONG_WIDE:
      box_wide_string_as_narrow (x, text, 100, NULL);
      rc = numeric_from_string ((numeric_t) tnum, text);
      break;
    case DV_STRING:
      rc = numeric_from_string ((numeric_t) tnum, x);
      break;
    default:
      {
	if (!col_name)
	  col_name = __get_column_name (cl_id, key);
	return srv_make_new_error
	  ("22018", "SR126",
	   "Can't convert %.*s to numeric", MAX_NAME_LEN, col_name);
      }
    }
  if (rc != NUMERIC_STS_SUCCESS)
    {
      if (!col_name)
	col_name = __get_column_name (cl_id, key);
      return srv_make_new_error
	("22003", "SR127",
	 "Can't convert %.*s to numeric", MAX_NAME_LEN, col_name);
    }
  if (NUMERIC_STS_SUCCESS
      !=  numeric_rescale ((numeric_t) res, (numeric_t) tnum, prec, scale))
    {
      if (!col_name)
	col_name = __get_column_name (cl_id, key);
      return srv_make_new_error
	("22003", "SR128",
	 "Numeric value out of range for %.*s(%d, %d)",
	  MAX_NAME_LEN, col_name, prec, scale);
    }
  return NULL;
}


#define NUM_CNV_CK(rc) \
  if (NUMERIC_STS_SUCCESS != rc) { \
    err = srv_make_new_error ("22003", "SR129", "Numeric value out of range"); \
    if (err_ret) *err_ret = err; \
    else sqlr_resignal (err); \
    return; \
  }

char*
__get_column_name (oid_t col_id, dbe_key_t *key)
{
  if (key &&
      (key->key_id == KI_TEMP ||
       !key->key_table ||
       (key->key_storage && key->key_storage->dbs_type == DBS_TEMP)))
    return "<temporary space column>";
  else
    {
      dbe_column_t * col = (dbe_column_t*)
	  gethash ((void*) (ptrlong) col_id, wi_inst.wi_schema->sc_id_to_col);
      if (!col)
	return "<unknown>";
      return col->col_name;
    }
}


#define IS_TIME_DTP(d) \
	(d == DV_TIMESTAMP_OBJ || d == DV_TIMESTAMP || d == DV_DATE || \
	 d == DV_TIME || d == DV_DATETIME)


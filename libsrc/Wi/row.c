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
#include "lisprdr.h"
#include "date.h"
#include "datesupp.h"
#include "multibyte.h"
#include "srvmultibyte.h"
#include "bif_xper.h"		/* IvAn/DvBlobXper/001212 Include added */
#include "sqltype.h"
#include "xmltree.h"
#include "xml.h"
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
itc_get_row_key (it_cursor_t * it, buffer_desc_t * buf)
{
  int pos = it->itc_position;
  key_id_t key_id = SHORT_REF (buf->bd_buffer + pos + IE_KEY_ID);
  return (sch_id_to_key (isp_schema (NULL), key_id));
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
itc_col_loc (it_cursor_t * itc, db_buf_t page, oid_t col_id)
{
  key_id_t key_id = SHORT_REF (page + itc->itc_position + IE_KEY_ID);
  dbe_key_t * key = sch_id_to_key (wi_inst.wi_schema, key_id);
  dbe_col_loc_t * cl = key_find_cl (key, col_id);
  return cl;
}



long
itc_long_column (it_cursor_t * it, buffer_desc_t * buf, oid_t col)
{
  dbe_col_loc_t * cl = itc_col_loc (it, buf->bd_buffer, col);
  if (!cl)
    return 0;
  if (buf->bd_buffer[it->itc_position + IE_FIRST_KEY + cl->cl_null_flag] & cl->cl_null_mask)
    return 0;
  if (DV_SHORT_INT == cl->cl_sqt.sqt_dtp)
    return (SHORT_REF (buf->bd_buffer + it->itc_position + IE_FIRST_KEY + cl->cl_pos));
  else
    return (LONG_REF (buf->bd_buffer + it->itc_position + IE_FIRST_KEY + cl->cl_pos));
}


caddr_t
itc_box_row (it_cursor_t * itc, db_buf_t page)
{
  int len = row_length (page + itc->itc_position, itc->itc_row_key);
  caddr_t box = dk_alloc_box (len + 1, DV_LONG_STRING);
  memcpy (box, page + itc->itc_position, len);
  box[len] = 0;
  return box;
}


caddr_t
blob_ref_check (db_buf_t xx, int len, it_cursor_t * itc, dtp_t col_dtp)
{
  if (IS_BLOB_DTP (*xx))
    {
      blob_handle_t * bh;
      bh = bh_from_dv (xx, itc);
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


caddr_t itc_box_base_uri_column_impl (it_cursor_t * itc, dbe_key_t * key, dtp_t *row, oid_t xml_col_id)
{
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
}


caddr_t itc_box_base_uri_column (it_cursor_t * itc, db_buf_t page, oid_t xml_col_id)
{
  key_id_t key_id = SHORT_REF (page + itc->itc_position + IE_KEY_ID);
  dbe_key_t * key = sch_id_to_key (wi_inst.wi_schema, key_id);
  return itc_box_base_uri_column_impl (itc, key, page + itc->itc_position + IE_FIRST_KEY, xml_col_id);
}


caddr_t
itc_box_column (it_cursor_t * it, db_buf_t page, oid_t col, dbe_col_loc_t * cl)
{
  db_buf_t xx;
  int len, off;
  caddr_t str;
  dtp_t col_dtp;
  if (!cl)
    cl = itc_col_loc (it, page, col);
  if (!cl)
    return (dk_alloc_box (0, DV_DB_NULL));
  if (ITC_NULL_CK (it, (*cl)))
    return (dk_alloc_box (0, DV_DB_NULL));

  if (cl == it->itc_row_key->key_bit_cl && !it->itc_no_bitmap)
    {
      /* the current bm inx col value is in the itc */
      if (DV_LONG_INT == it->itc_row_key->key_bit_cl->cl_sqt.sqt_dtp
	  || DV_INT64 == it->itc_row_key->key_bit_cl->cl_sqt.sqt_dtp)
	return box_num (it->itc_bp.bp_value);
      else 
	return box_iri_id (it->itc_bp.bp_value);
    }
  ITC_COL (it, (*cl), off, len);
  xx = page + it->itc_position + IE_FIRST_KEY + off;
  col_dtp = cl->cl_sqt.sqt_dtp;
  switch (cl->cl_sqt.sqt_dtp)
    {
    case DV_SHORT_INT:
      len = *((short *) xx);
      return (box_num (len));
    case DV_LONG_INT:
      len = LONG_REF (xx);
      return (box_num (len));
    case DV_INT64:
      return box_num (INT64_REF (xx));
    case DV_IRI_ID:
      return box_iri_id ((unsigned long) LONG_REF (xx));
    case DV_IRI_ID_8:
      return box_iri_id (INT64_REF (xx));
    case DV_OBJECT:
    case DV_ANY:
      if (len)
	return (box_deserialize_string ((char *)(xx), len));
      else
	return (box_num (0));
    case DV_STRING:
      str = dk_alloc_box ((int) len + 1, DV_LONG_STRING);
      memcpy (str, xx, len);
      str[len] = 0;
      return str;

    case DV_WIDE:
    case DV_LONG_WIDE:
      {
	return box_utf8_as_wide_char ((caddr_t) xx, NULL, len, 0, DV_LONG_WIDE);
      }
    case DV_SINGLE_FLOAT:
      str = dk_alloc_box (sizeof (float), DV_SINGLE_FLOAT);
      EXT_TO_FLOAT (str, xx);
      return str;
    case DV_DOUBLE_FLOAT:
      str = dk_alloc_box (sizeof (double), DV_DOUBLE_FLOAT);
      EXT_TO_DOUBLE (str, xx);
      return str;
    case DV_NUMERIC:
      {
	numeric_t num = numeric_allocate ();
	numeric_from_buf (num, xx);
	return ((caddr_t) num);
      }
    case DV_BIN:
    case DV_LONG_BIN:
      {
	str = dk_alloc_box ((int) len, DV_BIN);
	memcpy (str, xx, (int) len);
	return str;
      }

    case DV_COMPOSITE:
      {
	str = dk_alloc_box ((int) len + 2, DV_COMPOSITE);
	memcpy (str, xx + 2, (int) len);
	str[0] = (char)(DV_COMPOSITE);
	str[1] = (char)(len);
	return str;
      }

    case DV_BLOB:
      {
	caddr_t bh = blob_ref_check (xx, len, it, col_dtp);
#ifdef BIF_XML
	if (DV_BLOB_XPER_HANDLE == DV_TYPE_OF (bh))
	  {
	    caddr_t val = (caddr_t) xper_entity (NULL, bh, NULL, 0, itc_box_base_uri_column (it, page, cl->cl_col_id), NULL /* no enc */, &lh__xany, NULL /* DTD config */, 1);
	    dk_free_box (bh);
	    return val;
	  }
#endif
	if (cl->cl_sqt.sqt_class)
	  {
	    caddr_t res = udt_deserialize_from_blob (bh, it->itc_ltrx);
	    dk_free_box (bh);
	    return res;
	  }
	if (cl->cl_sqt.sqt_is_xml && it->itc_out_state)
	  {
	    caddr_t res = xml_deserialize_from_blob (bh, it->itc_ltrx, it->itc_out_state, itc_box_base_uri_column (it, page, cl->cl_col_id));
	    dk_free_box (bh);
	    return res;
	  }
	return bh;
      }
    case DV_BLOB_BIN:
    case DV_BLOB_WIDE:
      return (blob_ref_check (xx, len, it, col_dtp));
#ifdef BIF_XML
    case DV_BLOB_XPER:
      {
	caddr_t bh = blob_ref_check (xx, len, it, col_dtp);
	caddr_t val = (caddr_t) xper_entity (NULL, bh, NULL, 0, itc_box_base_uri_column (it, page, cl->cl_col_id), NULL /* no enc */, &lh__xany, NULL /* DTD config */, 1);
	dk_free_box (bh);
	return val;
      }
#endif
    case DV_DATETIME:
    case DV_TIMESTAMP:
    case DV_DATE:
    case DV_TIME:
      {
	caddr_t res = dk_alloc_box (DT_LENGTH, DV_DATETIME);
	memcpy (res, xx, DT_LENGTH);
	return res;
      }
    case DV_ARRAY_OF_FLOAT:
      {
	int inx;
	caddr_t res;
	res = dk_alloc_box (len, cl->cl_sqt.sqt_dtp);
	for (inx = 0; inx < len; inx += 4)
	  ((int32*) res)[inx / 4] = LONG_REF (xx + inx);
	return res;
      }
    case DV_ARRAY_OF_LONG:
      {
	int inx;
	caddr_t res;
	res = dk_alloc_box (len / sizeof (int32) * sizeof (ptrlong), cl->cl_sqt.sqt_dtp);
	for (inx = 0; inx < len; inx += 4)
	  ((ptrlong*) res)[inx / 4] = LONG_REF (xx + inx);
	return res;
      }
    case DV_ARRAY_OF_DOUBLE:
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
	  ALIGN_4 (box_length (old)) == ALIGN_4 ((uint32) len))
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
qst_set_string (caddr_t * state, state_slot_t * sl, db_buf_t data, size_t len /*, dtp_t dtp*/)
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
#ifdef QST_DEBUG
    }
#endif
}


#define FXO (cl->cl_pos)
#define FXL (cl->cl_fixed_len)
#define VL \
  len = cl->cl_fixed_len; \
  if (CL_FIRST_VAR == len) \
    { \
      dbe_key_t * key = it->itc_row_key; \
      off =  key->key_row_var_start; \
      len = SHORT_REF (row + key->key_length_area) - off; \
    } \
  else \
    { \
      off = SHORT_REF (row - len); \
      len = SHORT_REF (row + 2 - len) - off; \
    } \
  xx = row + off;

#define VL2 \
  len = cl->cl_fixed_len; \
  if (CL_FIRST_VAR == len) \
    { \
      dbe_key_t * key = it->itc_row_key; \
      off =  key->key_key_var_start; \
      len = SHORT_REF (row + key->key_length_area) - off; \
    } \
  else \
    { \
      off = SHORT_REF (row - len); \
      len = SHORT_REF (row + 2 - len) - off; \
    } \
  xx = row + off;

void
itc_qst_set_column (it_cursor_t * it, dbe_col_loc_t * cl,
    caddr_t * qst, state_slot_t * target)
{
  float fl;
  double df;
  int32 len, off;
  iri_id_t ln1;
  dtp_t * row = it->itc_row_data, *xx;
  dtp_t col_dtp;
  if ((row[cl->cl_null_flag] & cl->cl_null_mask))
    {
      qst_set_bin_string (qst, target, (db_buf_t) "", 0, DV_DB_NULL);
      return;
    }
  col_dtp = cl->cl_sqt.sqt_dtp;
  switch (cl->cl_sqt.sqt_dtp)
    {
    case DV_SHORT_INT:
      len = ((signed short *) (row + FXO))[0];
      qst_set_long (qst, target, (long) len);
      return;
    case DV_LONG_INT:
      len = LONG_REF ((row + FXO));
      qst_set_long (qst, target, len);
      return;
    case DV_INT64:
      qst_set_long (qst, target, INT64_REF ((row + FXO)));
      return;
    case DV_IRI_ID:
      ln1 = (iri_id_t) (uint32) LONG_REF ((row + FXO));
      qst_set_bin_string (qst, target, (db_buf_t) &ln1, sizeof (iri_id_t), DV_IRI_ID);
      return;
    case DV_IRI_ID_8:
      ln1 = INT64_REF ((row + FXO));
      qst_set_bin_string (qst, target, (db_buf_t) &ln1, sizeof (iri_id_t), DV_IRI_ID);
      return;
    case DV_OBJECT:
    case DV_ANY:
      VL;
      {
	caddr_t thing = len ? box_deserialize_string ((char *)(xx), len) : box_num (0);
	qst_set (qst, target, thing);
      return;
      }
    case DV_STRING:
      VL;
      qst_set_string (qst, target, xx, len /*, DV_LONG_STRING*/);
      return;
    case DV_SINGLE_FLOAT:
      xx = row + FXO;
      EXT_TO_FLOAT (&fl, xx);
      qst_set_float (qst, target, fl);
      return;
    case DV_DOUBLE_FLOAT:
      xx = row + FXO;
      EXT_TO_DOUBLE (&df, xx);
      qst_set_double (qst, target, df);
      return;
    case DV_NUMERIC:
      qst_set_numeric_buf (qst, target, row + FXO);
      return;
    case DV_BIN:
    case DV_LONG_BIN:
      {
	VL;
	qst_set_bin_string (qst, target, xx, len, DV_BIN);
	return;
      }
    case DV_COMPOSITE:
      {
	O12;
	VL; /* To eliminate warning :) */
	len = xx[1];
	qst_set_bin_string (qst, target, xx, len + 2, DV_COMPOSITE);
	return;
      }

    case DV_WIDE:
    case DV_LONG_WIDE:
      {
	VL;
	qst_set_wide_string (qst, target, xx, len, DV_LONG_WIDE, 1);
	return;
      }

    case DV_BLOB:
      VL;
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
      VL;
      {
	caddr_t bh = blob_ref_check (xx, len, it, col_dtp);
	qst_set (qst, target, bh);
	return;
      }

#ifdef BIF_XML
    case DV_BLOB_XPER:
      VL;
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
	qst_set_bin_string (qst, target, row + FXO, DT_LENGTH, DV_DATETIME);
	return;
      }
    case DV_ARRAY_OF_FLOAT:
      VL;
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
      VL;
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
      VL;
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


caddr_t
box_to_any_1 (caddr_t data, caddr_t * err_ret)
{
  caddr_t box;
  int init, len;
  dtp_t key_image[PAGE_DATA_SZ];
  dk_session_t sesn, *ses = &sesn;
  scheduler_io_data_t io;
  ROW_OUT_SES (sesn, key_image);

  SESSION_SCH_DATA (ses) = &io;
  memset (SESSION_SCH_DATA (ses), 0, sizeof (scheduler_io_data_t));

  init = sesn.dks_out_fill;

  CATCH_WRITE_FAIL (ses)
    {
      print_object (data, &sesn, NULL, NULL);
    }
  FAILED
    {
      *err_ret = srv_make_new_error ("22026", "SR477", "Error serializing the value into an ANY column");
      return NULL;
    }
  END_WRITE_FAIL (ses);

  if (sesn.dks_out_fill > PAGE_DATA_SZ - 10)
    {
      *err_ret = srv_make_new_error ("22026", "SR478", "Value of ANY type column too long");
      return NULL;
    }
  len = sesn.dks_out_fill - init;
  box = dk_alloc_box (len + 1, DV_STRING);
  memcpy (box, &sesn.dks_out_buffer[init], len);
  box[len] = 0;
  return box;
}

caddr_t 
box_to_any (caddr_t data, caddr_t * err_ret)
{
  if (THR_IS_STACK_OVERFLOW (THREAD_CURRENT_THREAD, &err_ret, (PAGE_DATA_SZ+1000)))
    {
      *err_ret = srv_make_new_error ("42000", "SR483", "Stack Overflow");
      return NULL;
    }
  return box_to_any_1 (data, err_ret);
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
      boxint tmp_buf [1+(BOX_SHORT_ANY_LIMIT + BOX_AUTO_OVERHEAD)/sizeof (boxint)];
      caddr_t tmp;
      char *data_tail = data + data_len - 1;
      boxint hi = 0, lo = data_len;
#ifdef DOUBLE_ALIGN
      while (((ptrlong)data_tail) & (sizeof(boxint)-1)) { lo += data_tail[0]; hi += lo; data_tail--; }
      while (data_tail > data) { lo += ((boxint *)data_tail)[0]; hi += lo; data_tail -= sizeof(boxint); }
#else
      while (((ptrlong)data_tail) & 3) { lo += data_tail[0]; hi += lo; data_tail--; }
      while (data_tail > data) { lo += ((uint32 *)data_tail)[0]; hi += lo; data_tail -= 4; }
#endif
      BOX_AUTO (tmp, tmp_buf, BOX_SHORT_ANY_LIMIT, data_dtp);
      memcpy (tmp, data, BOX_SHORT_ANY_LIMIT-17);
      ((boxint *)(tmp + BOX_SHORT_ANY_LIMIT-17))[0] = hi;
      ((boxint *)(tmp + BOX_SHORT_ANY_LIMIT-9))[0] = lo;
      tmp[BOX_SHORT_ANY_LIMIT-1] = '\0';
      return box_to_any_1 (tmp, err_ret);
    }
  return box_to_any_1 (data, err_ret);
}

#define V_COL_LEN(len) \
      if ((int) (len + *v_fill) > max) \
	{ \
	  *err_ret = srv_make_new_error ("22003", "SR448", "Max row length exceeded"); \
	  return; \
	} \
      *v_fill += len; \
      if (CL_FIRST_VAR == cl->cl_fixed_len) \
	SHORT_SET (row + key->key_length_area, *v_fill); \
      else \
	SHORT_SET ((row - cl->cl_fixed_len) + 2, *v_fill);


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
row_set_col (db_buf_t row, dbe_col_loc_t * cl, caddr_t data, int * v_fill, int max,
	     dbe_key_t * key,
	     caddr_t * err_ret, it_cursor_t * ins_itc, db_buf_t old_blob, caddr_t *qst)
{
  row_set_col_1 (row, cl, data, v_fill, max, key, err_ret, ins_itc, old_blob, qst, 0);
}


void
row_set_col_1 (db_buf_t row, dbe_col_loc_t * cl, caddr_t data, int * v_fill, int max,
	     dbe_key_t * key,
	     caddr_t * err_ret, it_cursor_t * ins_itc, db_buf_t old_blob, caddr_t *qst, int allow_shorten_any)
{
  boxint lv;
  caddr_t str;
  int pos = cl->cl_pos, len;
  dtp_t dtp = DV_TYPE_OF (data);
  caddr_t wide_str = 0;
  if (DV_DB_NULL == dtp)
    {
      if (!cl->cl_null_mask)
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
      if (ins_itc)
	ITC_SEARCH_PARAM_NULL (ins_itc);
      row[cl->cl_null_flag] |= cl->cl_null_mask;
      if (old_blob && IS_BLOB_DTP (*old_blob))
	{
	  blob_layout_t * old_bl = bl_from_dv (old_blob, ins_itc);
	  blob_log_replace (ins_itc, old_bl);
	  blob_schedule_delayed_delete (ins_itc, old_bl, BL_DELETE_AT_COMMIT);
	}
      if (cl->cl_fixed_len > 0)
	{
	  memset (row + cl->cl_pos, 0xff, cl->cl_fixed_len); /* *fill null w/ ff just for debug */
	  return;
	}
      else if (CL_FIRST_VAR == cl->cl_fixed_len)
	{
	  SHORT_SET (row + key->key_length_area, *v_fill);
	}
      else
	{
	  SHORT_SET ((row - cl->cl_fixed_len) + 2, *v_fill);
	}
      return;
    }
  else
    {
      if (cl->cl_null_mask)
	row[cl->cl_null_flag] &= ~cl->cl_null_mask;
    }
  switch (cl->cl_sqt.sqt_dtp)
    {
    case DV_LONG_INT:
      lv = box_to_boxint (data, dtp, cl->cl_col_id, err_ret, key, DV_LONG_INT);
      if (err_ret && *err_ret)
	return;
      lv = num_check_prec (lv, cl->cl_sqt.sqt_precision, __get_column_name (cl->cl_col_id, key), err_ret);
      if (err_ret && *err_ret)
	return;
      if (ins_itc)
	{
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
	}
      LONG_SET (row + pos, lv);
      break;
    case DV_INT64:
      lv = box_to_boxint (data, dtp, cl->cl_col_id, err_ret, key, DV_INT64);
      if (err_ret && *err_ret)
	return;
      lv = num_check_prec (lv, cl->cl_sqt.sqt_precision, __get_column_name (cl->cl_col_id, key), err_ret);
      if (err_ret && *err_ret)
	return;
      if (ins_itc)
	{
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
	}
      INT64_SET (row + pos, lv);
      break;

    case DV_SHORT_INT:
      lv = box_to_boxint (data, dtp, cl->cl_col_id, err_ret, key, DV_SHORT_INT);
      if (err_ret && *err_ret)
	return;
      lv = num_check_prec (lv, cl->cl_sqt.sqt_precision, __get_column_name (cl->cl_col_id, key), err_ret);
      if (err_ret && *err_ret)
	return;
      if (ins_itc)
	{
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
	}
      SHORT_SET (row + pos, ((short) lv));
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
	if (ins_itc)
	  ITC_SEARCH_PARAM (ins_itc, data);
	if (DV_IRI_ID_8 == cl->cl_sqt.sqt_dtp)
	  {
	    INT64_SET (row + pos, iid);
	  }
	else 
	  {
	    /* to don't overflow */
	    if (iid <= 0xFFFFFFFF)
	      {
	  LONG_SET (row + pos, iid);
	      }
	    else
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
	    memcpy (row + cl->cl_pos, &tmp[1], cl->cl_fixed_len);
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
      if (allow_shorten_any)
	str = box_to_shorten_any (data, err_ret);
      else
      str = box_to_any (data, err_ret);
      if (err_ret && *err_ret)
	return;
      ITC_OWNS_PARAM (ins_itc, str);
      goto assign_str;

    case DV_OBJECT:
      udt_can_write_to (&cl->cl_sqt, data, err_ret);
      if (err_ret && *err_ret)
	return;
      str = box_to_any (data, err_ret);
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
      memcpy (row + *v_fill, str, len);
      *v_fill += len;
      if (CL_FIRST_VAR == cl->cl_fixed_len)
	SHORT_SET (row + key->key_length_area, *v_fill);
      else
	SHORT_SET ((row - cl->cl_fixed_len) + 2, *v_fill);
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
	  wide_str =  box_copy (data);
	  if (ins_itc)
	    ITC_OWNS_PARAM (ins_itc, wide_str);
	}
      str = box_wide_as_utf8_char (wide_str, box_length (wide_str) / sizeof (wchar_t) - 1, DV_LONG_STRING);

      len = box_length (str) - 1;
      if (len + *v_fill > max)
	goto IN009;

      memcpy (row + *v_fill, str, len);
      *v_fill += len;
      if (CL_FIRST_VAR == cl->cl_fixed_len)
	SHORT_SET (row + key->key_length_area, *v_fill);
      else
	SHORT_SET ((row - cl->cl_fixed_len) + 2, *v_fill);
      if (ins_itc)
	ITC_SEARCH_PARAM (ins_itc, wide_str);
      dk_free_box (str);
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

	memcpy (row + *v_fill, data, len);
	*v_fill += len;

	if (CL_FIRST_VAR == cl->cl_fixed_len)
	  SHORT_SET (row + key->key_length_area, *v_fill);
	else
	  SHORT_SET ((row - cl->cl_fixed_len) + 2, *v_fill);
	if (ins_itc)
	  ITC_SEARCH_PARAM (ins_itc, data);
      }
      break;
    case DV_SINGLE_FLOAT:
      {
	double df = box_to_double (data, dtp, cl->cl_col_id, err_ret, key);
	float ft = (float) df;
	FLOAT_TO_EXT (row + cl->cl_pos, &ft);
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
	DOUBLE_TO_EXT (row + cl->cl_pos, &df);
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
	      cl->cl_sqt.sqt_dtp, 0, 0, err_ret);
	  if (ins_itc)
	    ITC_OWNS_PARAM (ins_itc, data);
	  if (*err_ret)
	    return;
	  memcpy (row + pos, data, DT_LENGTH);
	  if (ins_itc)
	    {
	      ITC_SEARCH_PARAM (ins_itc, data);
	    }
	  else
	    dk_free_box (data);
	}
      else
	{
	  memcpy (row + pos, data, DT_LENGTH);
	  dt_date_round ((char *) (row + pos));
	  if (ins_itc)
	    {
	      caddr_t dt_box = dk_alloc_box (DT_LENGTH, DV_DATETIME);
	      memcpy (dt_box, row + pos, DT_LENGTH);
	      ITC_SEARCH_PARAM (ins_itc, dt_box);
	      ITC_OWNS_PARAM (ins_itc, dt_box);
	    }
	}
      break;
    case DV_DATETIME:
    case DV_TIME:
      if (DV_DATETIME != dtp)
	goto convert_dt;
      memcpy (row + pos, data, DT_LENGTH);
      DT_SET_FRACTION (row + pos, 0);
      SET_DT_TYPE_BY_DTP (row + pos, cl->cl_sqt.sqt_dtp);
      if (ins_itc)
	{
	  caddr_t dt_box = dk_alloc_box (DT_LENGTH, DV_DATETIME);
	  memcpy (dt_box, row + pos, DT_LENGTH);
	  ITC_SEARCH_PARAM (ins_itc, dt_box);
	  ITC_OWNS_PARAM (ins_itc, dt_box);
	}
      break;

    case DV_TIMESTAMP:
      if (DV_DATETIME != dtp)
	goto convert_dt;

      memcpy (row + pos, data, DT_LENGTH);
      SET_DT_TYPE_BY_DTP (row + pos, cl->cl_sqt.sqt_dtp);
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
	V_COL_LEN (DV_BLOB_LEN);

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
		caddr_t volatile charset = (caddr_t)(QST_CHARSET (qst) ? QST_CHARSET (qst) : default_charset);
	        static caddr_t dtd_config = NULL;
		if (NULL == dtd_config)
		  dtd_config = box_dv_short_string ("Validation=DISABLE Include=DISABLE IdCache=ENABLE SignalOnError=ENABLE");
          	tree1 = xml_make_mod_tree ((query_instance_t *) qst, data, err_ret, GE_XML, NULL, CHARSET_NAME (charset, NULL), server_default_lh, dtd_config, &dtd, NULL, NULL);
		if (!tree1)
		  return;
		data_are_temp = 1;
	      }
	    strses = strses_allocate ();
	    xte_serialize_packed ((caddr_t *)tree1, dtd, strses);
	    rc = itc_set_blob_col (ins_itc, &row[pos], (caddr_t)strses, old_bl,
	      old_blob ? BLOB_IN_UPDATE : BLOB_IN_INSERT, &cl->cl_sqt);
	    strses_free (strses);
	    if (data_are_temp)
	      {
	        dk_free_tree (tree1);
	        dtd_free (dtd);
	      }
	  }
	else
	  rc = itc_set_blob_col (ins_itc, &row[pos], data, old_bl,
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
	pos = *v_fill;
	V_COL_LEN (DV_BLOB_LEN);
	rc = itc_set_blob_col (ins_itc, &row[pos], data, old_bl, old_blob ? BLOB_IN_UPDATE : BLOB_IN_INSERT, &cl->cl_sqt);
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
      blob_handle_t *data_bh = (blob_handle_t *)(data);
      caddr_t tmp_null = dk_alloc_box (0, DV_DB_NULL);
      row_set_col_1 (row, cl, tmp_null, v_fill, max, key, err_ret, ins_itc, &row[pos], qst, allow_shorten_any);
      data_bh->bh_page = data_bh->bh_current_page = 0;
      dk_free_box (tmp_null);
   }
  return;
}


void
row_set_col_temp (db_buf_t row, dbe_col_loc_t * cl, caddr_t data, int * v_fill, int max,
		  dbe_key_t * key,
		  caddr_t * err_ret, it_cursor_t * ins_itc, db_buf_t old_blob, caddr_t *qst,
		  int allow_shorten_any)
{
  /* as if row_set_col but store a blob handle by reference, no copy */
  if (IS_BLOB_DTP (cl->cl_sqt.sqt_dtp))
    {
      dtp_t dtp = DV_TYPE_OF (data);
      switch (dtp)
	{
	case DV_BLOB_HANDLE:
	case DV_BLOB_WIDE_HANDLE:
	case DV_BLOB_XPER_HANDLE:
	  {
	    if (KI_TEMP != key->key_id)
	      GPF_T1 ("putting blob ref on non temp key");
	    if ((int) (DV_BLOB_LEN + *v_fill) > max)
	      {
		*err_ret = srv_make_new_error ("22026", "SR319",
						"Max row length of column [temp] exceeded");
		return;
	      }
	    bh_to_dv ((blob_handle_t *) data, row + *v_fill, DV_BLOB_DTP_FOR_BLOB_HANDLE_DTP (dtp));
	    *v_fill += DV_BLOB_LEN;
	    if (CL_FIRST_VAR == cl->cl_fixed_len)
	      SHORT_SET (row + key->key_length_area, *v_fill);
	    else
	      SHORT_SET ((row - cl->cl_fixed_len) + 2, *v_fill);
	    break;
	  }
	case DV_OBJECT:
	case DV_REFERENCE:
	  { /* an LONG <gizmo> object serialization case. That writes a temp blob */
	    row_set_col (row, cl, data, v_fill, max, key, err_ret, ins_itc, old_blob, qst);
	    break;
	  }

	case DV_XML_ENTITY:
	  if (cl->cl_sqt.sqt_is_xml)
	    { /* an LONG XML case. put it in as temp blob if the column is of the right kind */
	      row_set_col (row, cl, data, v_fill, max, key, err_ret, ins_itc, old_blob, qst);
	      break;
	    }
	default:
	  {
	    /* a non-blob is assigned to a blob. will generally be an inlined blob.  Place the dtp at the head and then do as if assigning the corresponding non-blob.
	     * note the v_fill increment, works since it is used to mark the end in row_set_col, not the start.  */
	    dbe_col_loc_t cl2;
	    dtp_t cdtp = cl->cl_sqt.sqt_dtp;
	    cl2 = *cl;
	    /* GK: store as inline only if the space on the row allows it */
	    if ((IS_STRING_DTP (dtp) && box_length (data) - 1 + *v_fill < max) ||
		(IS_WIDE_STRING_DTP (dtp) && box_length (data) - sizeof (wchar_t) + *v_fill < max) ||
		((dtp == DV_BIN || dtp == DV_LONG_BIN) && box_length (data) + *v_fill< max) ||
		((dtp == DV_DB_NULL) && box_length (data) + *v_fill< max)
		)
	      {
		cl2.cl_sqt.sqt_dtp = DV_BLOB == cdtp ? DV_STRING : DV_BLOB_WIDE == cdtp ? DV_WIDE : DV_BIN;
		row[*v_fill] = cl2.cl_sqt.sqt_dtp;
		(*v_fill)++;
	      }
	    row_set_col_1 (row, &cl2, data, v_fill, max, key, err_ret, ins_itc, old_blob, qst, allow_shorten_any);
	    break;
	  }
	}
    }
  else
    row_set_col_1 (row, cl, data, v_fill, max, key, err_ret, ins_itc, old_blob, qst, allow_shorten_any);
}


int
key_insert (insert_node_t * ins, caddr_t * qst, it_cursor_t * it, ins_key_t * ik)
{
  int col_ctr = 0;
  caddr_t err = NULL;
  buffer_desc_t *unq_buf;
  buffer_desc_t **unq_buf_ptr = NULL;
  int inx = 0, rc;
  int ruling_part_bytes;
  union
   {
     dtp_t image_int[MAX_ROW_BYTES];
     double __align_dummy;
   }
  v;
#define image  v.image_int
  dbe_key_t * key = ik->ik_key;
  int v_fill = key->key_row_var_start;
  search_spec_t * sp;
  query_instance_t * qi = (query_instance_t *) qst;

#ifdef VALGRIND
    memset (image, 0, sizeof (image));
#endif

/* The following string temporary fixes bug that was found first time
in database migration. The fix will not work when keys with multiple fragments
are implemented. */
    QI_CHECK_STACK (qi, &qst, INS_STACK_MARGIN);
  it->itc_tree = key->key_fragments[0]->kf_it;

  it->itc_key_spec = key->key_insert_spec;
  it->itc_out_state = qst;
  itc_free_owned_params (it);
  ITC_START_SEARCH_PARS (it);


  if (!key->key_parts)
    sqlr_new_error ("42S11", "SR119", "Key %.300s has 0 parts. Create index probably failed",
	key->key_name);

  SHORT_SET (&image[IE_KEY_ID], key->key_id);
  SHORT_SET (&image[IE_NEXT_IE], 0);
  for (sp = it->itc_key_spec.ksp_spec_array; sp; sp = sp->sp_next)
    {
      caddr_t data = QST_GET (qst, ik->ik_slots[inx]);
      row_set_col (&image[IE_FIRST_KEY], &sp->sp_cl, data, &v_fill, ROW_MAX_DATA, key, &err, it, NULL, qst);
      if (err)
	break;
      inx++;
    }
  if (err)
    {
      itc_free_owned_params (it);
      sqlr_resignal (err);
    }
  ruling_part_bytes = v_fill - key->key_row_var_start + key->key_key_var_start;
  if (ruling_part_bytes > MAX_RULING_PART_BYTES)
    {
      itc_free_owned_params (it);
      sqlr_error ("22026", "Key is too long, index %.300s, ruling part is %d bytes that exceeds %d byte limit",
        key->key_name, ruling_part_bytes, MAX_RULING_PART_BYTES );
    }

  col_ctr = inx;
  for (inx = 0; key->key_row_fixed[inx].cl_col_id; inx++)
    {
      caddr_t data = QST_GET (qst, ik->ik_slots[col_ctr + inx]);
      row_set_col (&image[IE_FIRST_KEY], &key->key_row_fixed[inx], data, NULL, 0, key, &err, it, NULL, qst);
      if (err)
	break;
    }
  col_ctr += inx;
  if (err)
    {
      itc_free_owned_params (it);
      sqlr_resignal (err);
    }
  itc_from_keep_params (it, key);  /* fragment needs to be known before setting blobs */
  for (inx = 0; key->key_row_var[inx].cl_col_id; inx++)
    {
      caddr_t data;
      if (CI_BITMAP == key->key_row_var[inx].cl_col_id)
	break; /* the bitmap string of a bm inx row is always the last */
      data = QST_GET (qst, ik->ik_slots[col_ctr + inx]);
      row_set_col (&image[IE_FIRST_KEY], &key->key_row_var[inx], data, &v_fill,
	  ROW_MAX_DATA, key, &err, it, NULL, qst);
      if (err)
	break;
    }
  if (err)
    {
      itc_free_owned_params (it);
      sqlr_resignal (err);
    }
  if (key->key_is_primary)
    {
      upd_blob_opt (it, image, &err, 1);
      if (err)
	{
	  itc_free_owned_params (it);
	  sqlr_resignal (err);
	}
      unq_buf_ptr = &unq_buf;
    }
  it->itc_insert_key = key;
  /*row_map_print (image, key);*/
  if (key->key_is_bitmap)
    {
      key_bm_insert (it, image);
      itc_free_owned_params (it);
      return DVC_LESS;
    }
  rc = itc_insert_unq_ck (it, &image[0], unq_buf_ptr);
  itc_free_owned_params (it);
  if (DVC_MATCH == rc)
    {
      /* duplicate */
      switch (ins->ins_mode)
	{
	case INS_REPLACING:

	  if (key->key_is_primary)
	    log_insert (it->itc_ltrx, key, image, ins->ins_mode);
	  QI_ROW_AFFECTED (QST_INSTANCE (qst));
	  itc_replace_row (it, unq_buf, &image[0], key, qst);
	  return DVC_MATCH;

	case INS_NORMAL:
	case INS_SOFT:

	  /* leave and return */
	  itc_page_leave (it, unq_buf);
	  if (ins->ins_mode == INS_SOFT && key->key_is_primary)
	    {
	      it->itc_position = 0;
	      it->itc_row_key = key;
	      itc_delete_blobs (it, image);
	      log_insert (it->itc_ltrx, key, image, ins->ins_mode);
	    }
	  else
	    if (key->key_table->tb_any_blobs)
	      TRX_POISON (it->itc_ltrx);
	  return DVC_MATCH;
	}
      return DVC_MATCH;
    }

  if (key->key_is_primary)
    {
      log_insert (it->itc_ltrx, key, image, ins->ins_mode);
    }
  return DVC_LESS;		/* normal insert OK. */
}

#undef image
#undef SR123_FAIL

int
itc_row_insert_1 (it_cursor_t * it, db_buf_t row, buffer_desc_t ** unq_buf,
    int blobs_in_place, int pk_only)
{
  key_id_t key_id;
  dbe_key_t *prime_key;
  dbe_table_t *tb;
  int rc;
  long row_len;

  key_id = SHORT_REF (row + IE_KEY_ID);
  prime_key = sch_id_to_key (wi_inst.wi_schema, key_id);
  if (!prime_key)
    {
      itc_free (it);
#ifdef SR123_FAIL
      GPF_T1("for testing purposes");
#endif
      sqlr_new_error ("42S12", "SR123", "Bad key id %u in row_insert.", (unsigned) key_id);
    }

  row_len = row_length (row, prime_key);
  if (row_len > MAX_ROW_BYTES
      + 2 /* GK: this is needed because there may be rows longer than the new constant in rfwd */)
    sqlr_new_error ("42000", "SR439", "Row too long (%d bytes) in row_insert on key %d (%.100s) of table %.300s",
	(int) row_len, (int) key_id, prime_key->key_name, prime_key->key_table->tb_name);

  dbe_cols_are_valid (row, prime_key, 1);
  tb = prime_key->key_table;
  it->itc_row_key = prime_key;
  it->itc_row_key_id = prime_key->key_id;

  it->itc_key_spec = prime_key->key_insert_spec;
  it->itc_insert_key = prime_key;
  itc_from (it, prime_key);
  itc_insert_row_params (it, row);
  if (!blobs_in_place)
    {
      row_fixup_blob_refs (it, row);
    }

  rc = itc_insert_unq_ck (it, row, unq_buf);
  if (DVC_MATCH == rc && ((ptrlong) UNQ_ALLOW_DUPLICATES != (ptrlong)unq_buf))
    {
      return DVC_MATCH;
    }

  if (pk_only)
    return DVC_LESS;
  DO_SET (dbe_key_t *, ins_key, &tb->tb_keys)
    {
      if (!ins_key->key_is_primary)
	{
	  if (!ins_key->key_fragments)
	    sqlr_new_error ("42000", "SR443", "The key %d [%s] contains no fragments",
			    ins_key->key_id, ins_key->key_name);
	  upd_insert_2nd_key (ins_key, it, prime_key, &row[IE_FIRST_KEY]);
	}
    }
  END_DO_SET ();
  return DVC_LESS;
}


int
itc_row_insert (it_cursor_t * it, db_buf_t row, buffer_desc_t ** unq_buf)
{
  return (itc_row_insert_1 (it, row, unq_buf, 0, 0));
}


void
itc_row_key_insert (it_cursor_t * it, db_buf_t row, dbe_key_t * ins_key)
{
  key_id_t key_id;
  dbe_key_t *prime_key;
  dbe_table_t *tb;
  it->itc_position = 0;
  key_id = SHORT_REF (row + IE_KEY_ID);
  prime_key = sch_id_to_key (isp_schema (NULL), key_id);
  if (!prime_key)
    {
      itc_free (it);
      sqlr_new_error ("42S12", "SR124", "Bad key id in row_insert.");
    }
  tb = prime_key->key_table;
  ins_key = sch_table_key (isp_schema (NULL),
      tb->tb_name, ins_key->key_name, 1);
  /* Take the key of the same name from the table of the ROW.
     Like this the newly inserted key will have the correct id
     in the case the original ins_key is a key of the ROW's super table. */

  if (!ins_key)
    sqlr_new_error ("42S12", "SR125", "key_insert: This table does not have this key.");
  upd_insert_2nd_key (ins_key, it, prime_key, row + IE_FIRST_KEY);
}


void
itc_drop_index (it_cursor_t * it, dbe_key_t * key)
{
  int ctr = 0;
  buffer_desc_t *del_buf;
  itc_from (it, key);
  it->itc_lock_mode = PL_EXCLUSIVE;
  it->itc_isolation = ISO_SERIALIZABLE;
  it->itc_n_lock_escalations = 100; /* lock pages from the start */
  it->itc_no_bitmap = 1;
  ITC_FAIL (it)
  {
    del_buf = itc_reset (it);
    FAILCK (it);
    while (DVC_MATCH == itc_next (it, &del_buf))
      {
	itc_delete (it, &del_buf, NO_BLOBS);
	it->itc_is_on_row = 0;
	ITC_LEAVE_MAPS (it);
	ctr++;
      }
    dbg_printf (("Deleted %d keys.\n", ctr));
    itc_page_leave (it, del_buf);
  }
  ITC_FAILED
  {
    itc_free (it);
  }
  END_FAIL (it);
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
void
row_print_number (caddr_t thing, dk_session_t * ses, dbe_column_t * col,
    caddr_t * err_ret, dtp_t dtp)
{
  int32 tl;
  double td;
  char temp[1000], *pthing;
  caddr_t err = NULL;
  if (IS_NUM_DTP (dtp))
    {
      switch (col->col_sqt.sqt_dtp)
	{
	case DV_SHORT_INT:
	case DV_LONG_INT:
	  {
	    switch (dtp)
	      {
	      case DV_SHORT_INT:
	      case DV_LONG_INT:
		print_int ((long) unbox (thing), ses);
		return;
	      case DV_SINGLE_FLOAT:
		print_int ((long) unbox_float (thing), ses);
		return;
	      case DV_DOUBLE_FLOAT:
		print_int ((long) unbox_double (thing), ses);
		return;
	      case DV_NUMERIC:
		NUM_CNV_CK (numeric_to_int32 ((numeric_t) thing, &tl));
		print_int (tl, ses);
		return;
	      }
	  }
	case DV_SINGLE_FLOAT:
	  {
	    switch (dtp)
	      {
	      case DV_SHORT_INT:
	      case DV_LONG_INT:
		print_float ((float) unbox (thing), ses);
		return;
	      case DV_SINGLE_FLOAT:
		print_float (unbox_float (thing), ses);
		return;
	      case DV_DOUBLE_FLOAT:
		print_float ((float) unbox_double (thing), ses);
		return;
	      case DV_NUMERIC:
		NUM_CNV_CK (numeric_to_double ((numeric_t) thing, &td));
		print_float ((float) td, ses);
		return;
	      }
	  }
	case DV_DOUBLE_FLOAT:
	  {
	    switch (dtp)
	      {
	      case DV_SHORT_INT:
	      case DV_LONG_INT:
		print_double ((double) unbox (thing), ses);
		return;
	      case DV_SINGLE_FLOAT:
		print_double ((double) unbox_float (thing), ses);
		return;
	      case DV_DOUBLE_FLOAT:
		print_double (unbox_double (thing), ses);
		return;
	      case DV_NUMERIC:
		NUM_CNV_CK (numeric_to_double ((numeric_t) thing, &td));
		print_double (td, ses);
		return;
	      }
	  }
	case DV_NUMERIC:
	  {
	    NUMERIC_VAR (n);
	    NUMERIC_INIT (n);
	    err = numeric_from_x ((numeric_t)n, thing, col->col_precision,
		col->col_scale, col->col_name, col->col_id, NULL);
	    if (!err)
	      {
		numeric_serialize ( (numeric_t) n, ses);
		return;
	      }
	    if (!err_ret)
	      sqlr_resignal (err);
	    *err_ret = err;
	  }
	}
      return;
    }

  if (DV_SHORT_STRING != dtp
      && DV_LONG_STRING != dtp &&
      !IS_WIDE_STRING_DTP (dtp))
    {
      err = srv_make_new_error ("22005", "SR130", "Bad value for numeric column %s, dtp = %d.",
	  col->col_name, dtp);
      if (err_ret)
	*err_ret = err;
      else
	sqlr_resignal (err);
      return;
    }
  if (IS_WIDE_STRING_DTP (dtp))
    {
      box_wide_string_as_narrow (thing, temp, 1000, NULL);
      pthing = temp;
    }
  else
    pthing = (char *)thing;
  switch (col->col_sqt.sqt_dtp)
    {
    case DV_LONG_INT:
    case DV_SHORT_INT:
      {
	long n;
	if (1 == sscanf (pthing, "%ld", &n))
	  {
	    print_int (n, ses);
	    return;
	  }
	break;
      }
    case DV_SINGLE_FLOAT:
      {
	float f;
	if (1 == sscanf (pthing, "%f", &f))
	  {
	    print_float (f, ses);
	    return;
	  }
	break;
      }

    case DV_DOUBLE_FLOAT:
      {
	double df;
	if (1 == sscanf (pthing, "%lf", &df))
	  {
	    print_double (df, ses);
	    return;
	  }
	break;
      }
    case DV_NUMERIC:
      {
	NUMERIC_VAR (n);
	NUMERIC_INIT (n);
	err = numeric_from_x ((numeric_t)n, thing, col->col_precision,
	    col->col_scale, col->col_name, col->col_id, NULL);
	if (!err)
	  {
	    numeric_serialize ( (numeric_t) n, ses);
	    return;
	  }
	if (!err_ret)
	  sqlr_resignal (err);
	*err_ret = err;
	return;
      }
    }
  err = srv_make_new_error ("22005", "SR131", "Cannot convert %s to number for column %s",
      thing, col->col_name);
  if (err_ret)
    *err_ret = err;
  else
    sqlr_resignal (err);
}
#define IS_TIME_DTP(d) \
	(d == DV_TIMESTAMP_OBJ || d == DV_TIMESTAMP || d == DV_DATE || \
	 d == DV_TIME || d == DV_DATETIME)

void
row_print_date (caddr_t thing, dk_session_t * ses, dbe_column_t * col,
    caddr_t * err_ret, dtp_t dtp, dtp_t col_dtp)
{
  char dt2[DT_LENGTH];
  caddr_t err;
  const char *str_err = "";

  if (IS_STRING_DTP (dtp) || dtp == DV_DATETIME)
    memcpy (dt2, (thing)?thing:"", DT_LENGTH);
  else
    {
      str_err = "Bad data type";
      goto bad_dtp;
    }

  if (dtp == DV_SHORT_STRING
      || dtp == DV_LONG_STRING)
    {
      dtp = DV_DATETIME;
      if (0 != string_to_dt (thing, dt2, &str_err))
	goto bad_dtp;
    }
  if (dtp == DV_DATETIME)
    {
      if (DV_TIMESTAMP == col_dtp)
	{
	  session_buffered_write_char (DV_DATETIME, ses);
	  session_buffered_write (ses, dt2, DT_LENGTH);
	}
      else if (DV_DATETIME == col_dtp)
	{
	  DT_SET_FRACTION (dt2, 0);
	  session_buffered_write_char (DV_DATETIME, ses);
	  session_buffered_write (ses, dt2, DT_LENGTH);
	}
      else if (DV_DATE == col_dtp)
	{
	  dt_date_round (dt2);
	  session_buffered_write_char (DV_DATETIME, ses);
	  session_buffered_write (ses, dt2, DT_LENGTH);
	}
      else if (col_dtp == DV_TIME)
	{
	  DT_SET_FRACTION (dt2, 0);
	  DT_SET_DT_TYPE (dt2, DT_TYPE_TIME);
	  session_buffered_write_char (DV_DATETIME, ses);
	  session_buffered_write (ses, dt2, DT_LENGTH);
	}
      else
	{
	  str_err = "Bad data sub-type";
	  goto bad_dtp;
	}
      return;
    }
bad_dtp:
  err = srv_make_new_error ("22007", "SR132", "Bad value for date / time column : %s", str_err);
  if (err_ret)
    *err_ret = err;
  else
    sqlr_resignal (err);
}

/*
 *  $Id$
 *
 *  Page and Row Layout, Key Compression
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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
#include "arith.h"





int
str_cmp_2 (db_buf_t dv1, db_buf_t dv2, db_buf_t dv3, int l1, int l2, int l3, unsigned short offset)
{
  int org_l3 = l3;
  unsigned char c1;
  int inx1 = 0, inx2 = 0;
  for (;;)
    {
      if (inx1 == l1)
	{
	  if (l3)
	    {
	      dv1 = dv3;
	      l1 = l3;
	      inx1  = 0;
	      l3 = 0;
	      continue;
	    }
	  else
	    {
	      if (inx2 == l2)
		return DVC_MATCH;
	      return DVC_LESS;
	    }
	}
      else if  (inx2 == l2)
	return DVC_GREATER;
      c1 = dv1[inx1];
      if (inx1 == l1 - 1 && !org_l3)
	c1 += offset;
      if (c1 == dv2[inx2])
	    {
	      inx1++;
	      inx2++;
	      continue;
	    }
      if (c1 < dv2[inx2])
	return DVC_LESS;
      else
	return DVC_GREATER;
    }
}


row_size_t
row_length (db_buf_t  row, dbe_key_t * key)
{
  int len;
  row_ver_t rv = IE_ROW_VERSION (row);
  key_ver_t kv = IE_KEY_VERSION (row);
  if (!kv)
    {
      len = key->key_key_len[rv];
      if (len <= 0)
	len = COL_VAR_LEN_MASK & SHORT_REF (row - len);
    }
  else if (kv == KV_LEFT_DUMMY)
    {
      len = 6;
    }
  else
    {
      dbe_key_t * row_key = NULL;
      if (kv >= KV_LONG_GAP
	  || !(row_key = key->key_versions[kv]))
	{
	  log_error ("row with bad kv in %s", key->key_name);
	  STRUCTURE_FAULT1 ("key with bad key version");
	}
      len = row_key->key_row_len[rv];
      if (len <= 0)
	len = COL_VAR_LEN_MASK & SHORT_REF (row - len);
    }
  if (len < 0 || len > MAX_ROW_BYTES)
    {
      if (key->key_id != KI_TEMP || len > MAX_HASH_TEMP_ROW_BYTES || len < 0)
	STRUCTURE_FAULT1 ("row length out of range");
    }
  return len;
}


void
kc_var_col (dbe_key_t * key, buffer_desc_t * buf, db_buf_t row, dbe_col_loc_t * cl, db_buf_t * p1, row_size_t * l1, db_buf_t * p2, row_size_t* l2, unsigned short * offset)
{
  row_ver_t rv = IE_ROW_VERSION (row);
  int off, len;
  if (rv & cl->cl_row_version_mask)
    {
      int irow = SHORT_REF (row + cl->cl_pos[rv]);
      row = buf->bd_buffer + buf->bd_content_map->pm_entries[irow & ROW_NO_MASK];
      rv = IE_ROW_VERSION (row);
      *offset = ((unsigned short)irow) >> COL_OFFSET_SHIFT;
    }
  else
    *offset = 0;
  len = cl->cl_pos[rv];
  if (CL_FIRST_VAR == len)
    {
      if (key->key_version != IE_KEY_VERSION (row))
	key = key->key_versions[IE_KEY_VERSION (row)];
      off = 0 == IE_KEY_VERSION (row) ? key->key_key_var_start[rv] : key->key_row_var_start[rv];
      len = SHORT_REF (row + key->key_length_area[rv]) - off;
    }
  else
    {
      len = -len;
      off = SHORT_REF (row + len) & COL_VAR_LEN_MASK;
      len = SHORT_REF (row + len + 2) - off;
    }
  if (len & COL_VAR_SUFFIX)
    {
      unsigned short irow;
      short pref_len;
      len &= COL_VAR_LEN_MASK;
      irow = SHORT_REF_NA (row + off);
      pref_len = irow >> COL_OFFSET_SHIFT;
      if (15 == pref_len)
	{
	  *l1 = row[off + 2];
	  *p2 = row + off + 3;
	  *l2 = len - 3;
	}
      else
	{
	  *l1 = pref_len;
	  *p2 = row + off + 2;
	  *l2 = len - 2;
	}
      if ((irow & ROW_NO_MASK) >= buf->bd_content_map->pm_count)
	{
	  log_error ("Row ref %u is out of range %u", irow, buf->bd_content_map->pm_count);
	  GPF_T1 ("prefix row ref out of pm range");
	}
      row = buf->bd_buffer + buf->bd_content_map->pm_entries[irow & ROW_NO_MASK];
      rv = IE_ROW_VERSION (row);
      /* now row is the row ref'd from the org row.  Get the offset of the col to get the prefix.  Note that if the suffix bit is set, it refers to the previous col, not this one.  To make sure that this col which is supposed not top be prefix compressed is not, look at the next word in the length area. */
      if (cl->cl_pos[rv] == CL_FIRST_VAR)
	{
	  off = (0 == IE_KEY_VERSION (row) ? key->key_key_var_start[rv] : key->key_row_var_start[rv]);
	}
      else
	{
	  off = COL_VAR_LEN_MASK & SHORT_REF (row - cl->cl_pos[rv]);
	}
      *p1 = row + off;
    }
  else
    {
      *l1 = len;
      *p1 = row + off;
      *l2 = 0;
    }
}


int
str_delta (db_buf_t str1, db_buf_t str2, int len1, int len2, row_size_t * prefix_ref, unsigned short * delta, unsigned char * extra, int mode)
{
  /* return how many chars of str1 are a prefix of str2.  Return the prefix ref in refix_ret, irow to be ored to that.  If prefix len > 15, set prefix_ret to 0xf000 and extra to the prefix len.  If same len and differ in the last char by less than 16, det delta to be this. */
  dtp_t d;
  int inx = 0;
  if (len1 < 4 || len2 < 3)
    return CC_NONE;
  for (;;)
    {
      if (inx == len1 || inx == len2)
	break;
      if (inx == len1 - 1 && len2 == len1 && CC_OFFSET == mode)
	{
	  if ((d = str2[inx] - str1[inx]) < 16)
	    {
	      *delta = d << COL_OFFSET_SHIFT;
	      return CC_OFFSET;
	    }
	}
      if (str1[inx] != str2[inx])
	break;
      inx++;
    }
  if (inx < 4 || inx < len2 / 2)
    return CC_NONE;
  if (inx < 15)
    {
      *delta = 0;
      *prefix_ref = inx << COL_OFFSET_SHIFT;
      *extra = 0;
      return CC_PREFIX;
    }
  else
    {
      *delta = 0;
      *prefix_ref = 15 << COL_OFFSET_SHIFT;
      *extra = MIN (inx, 255);
      return CC_PREFIX;
    }
}


#define PFH_INT_HASH(i) (((unsigned int)(((i) >> 10) ^ ((i) >> 20))) % PFH_N_WAYS)

resource_t * pfh_rc;

pf_hash_t *
pfh_allocate ()
{
  return (pf_hash_t *) dk_alloc (sizeof (pf_hash_t));
}


void
pfh_free (pf_hash_t * pfh)
{
  dk_free ((caddr_t) pfh, sizeof (pf_hash_t));
}


typedef struct pfe_i_s
{
  short	pff_place;
  short		pff_irow;
  short		pff_next;
} pfe_fixed_t;


short
pfh_int (pf_hash_t * pfh, int32 v, short nth_cl, unsigned short * off_ret)
{
  short nth = PFH_INT_HASH (v);
  short start = pfh->pfh_start[nth_cl][nth];
  short * hash = &pfh->pfh_hash[0];
  while (-1 != start)
    {
      pfe_fixed_t * pff = (pfe_fixed_t*) (hash + start);
      short ref = pff->pff_place;
      unsigned int32 off = v - LONG_REF (pfh->pfh_page + ref);
      if (off < 16)
	{
	  *off_ret = (off << COL_OFFSET_SHIFT) + pff->pff_irow;
	  return CC_OFFSET;
	}
      start = pff->pff_next;
    }
  return CC_NONE;
}


void
pfh_set_int (pf_hash_t * pfh, int32 v, short nth_cl, short irow, short place)
{
  pfe_fixed_t * pff;
  short nth = PFH_INT_HASH (v);
  short start = pfh->pfh_start[nth_cl][nth];
  short * hash = &pfh->pfh_hash[0];
  short next = pfh->pfh_fill;
  if (place & 1) GPF_T1 ("should not have int at odd address");
  if (pfh->pfh_n_cols <= nth_cl)
    return;
  if (next >PFH_N_SHORTS - 3)
    {
      TC (tc_page_fill_hash_overflow);
      return;
    }
  pff = (pfe_fixed_t *) (hash + next);
  pfh->pfh_fill += sizeof (pfe_fixed_t) / sizeof (short);
  pff->pff_next = start;
  pff->pff_irow = irow;
  pff->pff_place = place;
  pfh->pfh_start[nth_cl][nth] = next;
}


short
pfh_int64 (pf_hash_t * pfh, int64 v, short nth_cl, unsigned short * off_ret)
{
  short nth = PFH_INT_HASH (v);
  short start = pfh->pfh_start[nth_cl][nth];
  short * hash = &pfh->pfh_hash[0];
  while (-1 != start)
    {
      pfe_fixed_t * pff = (pfe_fixed_t*) (hash + start);
      short ref = pff->pff_place;
      unsigned int64 off = v - INT64_REF (pfh->pfh_page + ref);
      if (off < 16)
	{
	  *off_ret = (off << COL_OFFSET_SHIFT) + pff->pff_irow;
	  return CC_OFFSET;
	}
      start = pff->pff_next;
    }
  return CC_NONE;
}


void
pfh_set_int64 (pf_hash_t * pfh, int32 v, short nth_cl, short irow, short place)
{
  pfe_fixed_t * pff;
  short nth = PFH_INT_HASH (v);
  short start = pfh->pfh_start[nth_cl][nth];
  short * hash = &pfh->pfh_hash[0];
  short next = pfh->pfh_fill;
  if (place & 1) GPF_T1 ("should not have int at odd address");
  if (pfh->pfh_n_cols <= nth_cl)
    return;
  if (next >PFH_N_SHORTS - 3)
    {
      TC (tc_page_fill_hash_overflow);
      return;
    }
  pff = (pfe_fixed_t *) (hash + next);
  pfh->pfh_fill += sizeof (pfe_fixed_t) / sizeof (short);
  pff->pff_next = start;
  pff->pff_irow = irow;
  pff->pff_place = place;
  pfh->pfh_start[nth_cl][nth] = next;
}


void
pfh_set_var (pf_hash_t * pfh, dbe_col_loc_t * cl, short irow, db_buf_t str, int len)
{
  pfe_var_t * pfv;
  short * hash = &pfh->pfh_hash[0], start;
  short h_len = len;
  short next = pfh->pfh_fill;
  unsigned int32 hinx;
  if (pfh->pfh_n_cols <=cl->cl_nth)
    return;
  if (next >PFH_N_SHORTS - 4)
    {
      TC (tc_page_fill_hash_overflow);
      return;
    }

  if (len < 5)
    return;
  if (DV_ANY == cl->cl_sqt.sqt_dtp)
    h_len = len - 1;
  else
    h_len = MIN (len, 5);
  BYTE_BUFFER_HASH (hinx, str, h_len);
  start = pfh->pfh_start[cl->cl_nth][hinx % PFH_N_WAYS];
  pfv = (pfe_var_t *) (hash + next);
  pfh->pfh_fill += sizeof (pfe_var_t) / sizeof (short);
  pfv->pfv_next = start;
  pfv->pfv_irow = irow;
  pfv->pfv_place = str - pfh->pfh_page;
  pfv->pfv_len = len;
  pfh->pfh_start[cl->cl_nth][hinx % PFH_N_WAYS] = next;
}


short
pfh_var (pf_hash_t * pfh, dbe_col_loc_t * cl, db_buf_t str, int len, unsigned short * prefix_bytes, unsigned short * prefix_ref, dtp_t * extra, int mode)
{
  pfe_var_t * pfv;
  short h_len, start;
  short * hash = &pfh->pfh_hash[0];
  unsigned int32 hinx;

  if (len < 5)
    return CC_NONE;
  if (DV_ANY == cl->cl_sqt.sqt_dtp)
    h_len = len - 1;
  else
    h_len = MIN (len, 5);
  BYTE_BUFFER_HASH (hinx, str, h_len);
  start = pfh->pfh_start[cl->cl_nth][hinx % PFH_N_WAYS];
  if (DV_ANY == cl->cl_sqt.sqt_dtp)
    {
      for (start = start;  -1 != start; start = pfv->pfv_next)
	{
	  db_buf_t col;
	  unsigned short delta;
	  pfv = (pfe_var_t *) (hash + start);
	  if (len != pfv->pfv_len)
	    continue;
	  col = pfh->pfh_page + pfv->pfv_place;
	  if (0 != memcmp (col, str, len - 1))
	    continue;
	  delta = str[h_len] - col[h_len];
	  if (delta < 16 || CC_LAST_BYTE == mode)
	    {
	      switch ((dtp_t) col[0])
		{
		case DV_LONG_INT: case DV_INT64:
		case DV_IRI_ID: case DV_IRI_ID_8:
		case DV_SHORT_STRING_SERIAL:
		case DV_RDF: case DV_RDF_ID: case DV_RDF_ID_8:
		  if (CC_LAST_BYTE == mode)
		    *prefix_ref = pfv->pfv_irow;
		  else
		    *prefix_ref = pfv->pfv_irow | (delta << COL_OFFSET_SHIFT);
		  return CC_OFFSET;
		}
	    }
	}
    }
  else if (DV_STRING == cl->cl_sqt.sqt_dtp)
    {
      for (start = start;  -1 != start; start = pfv->pfv_next)
	{
	  db_buf_t col;
	  int rc;
	  pfv = (pfe_var_t *) (hash + start);
	  col = pfh->pfh_page + pfv->pfv_place;
	  rc = str_delta (col, (db_buf_t) str, pfv->pfv_len, len, prefix_bytes, prefix_ref, extra, mode);
	  if (CC_NONE != rc)
	    {
	      (*prefix_ref) |= pfv->pfv_irow;
	      return rc;
	    }
	}
    }
  return CC_NONE;
}


void
pfh_init (pf_hash_t * pfh, buffer_desc_t * buf)
{
  int last_col = 5;
  if (!pfh)
    return;
  pfh->pfh_fill = 0;
  pfh->pfh_page = buf->bd_buffer;
  pfh->pfh_n_cols = last_col;
  pfh->pfh_kv = PFH_KV_ANY;
  memset (pfh->pfh_start, -1, sizeof (short) * last_col * PFH_N_WAYS);
}


int
box_length_on_row (caddr_t val)
{
  switch (DV_TYPE_OF (val))
    {
    case DV_STRING: return box_length (val) - 1;
    case DV_BIN:
    default: return box_length (val); break;
    }
}

#define not_match_continue { if (first_only) return CC_NONE; else continue;}

int
col_compressed_value (buffer_desc_t * buf, dbe_col_loc_t * cl, int left_of, caddr_t val, row_size_t * prefix_bytes, unsigned short * prefix_ref, unsigned char * extra, int mode, int first_only, key_ver_t kv_wanted)
{
  int delta;
  page_map_t * pm = buf->bd_content_map;
  int irow, dir, start;
  int val_len = 0;
  row_ver_t rv;
  if (CC_NONE == cl->cl_compression)
    return CC_NONE;
  /* if (DV_ANY == cl->cl_sqt.sqt_dtp) return CC_NONE; */
  switch (DV_TYPE_OF (val))
    {
    case DV_STRING: val_len = box_length (val) - 1; break;
    case DV_BIN: val_len = box_length (val); break;
    }
  if (!cl->cl_comp_asc || first_only)
    {
      /* high cardinality leading key part */
      start = left_of - 1;
      dir = -1;
    }
  else
    {
      start = 0;
      dir = 1;
    }
  if (1 == dir)
    first_only = 0;
  if (first_only && start >= 0)
    {
      db_buf_t row = buf->bd_buffer + pm->pm_entries[start];
      if (0 != ((rv = IE_ROW_VERSION (row)) & cl->cl_row_version_mask))
	start = ROW_NO_MASK & SHORT_REF  (row + cl->cl_pos[rv]);
    }
  for (irow = start; irow >= 0 && irow < left_of; irow+= dir)
    {
      db_buf_t row = buf->bd_buffer + pm->pm_entries[irow];
      if (0 == ((rv = IE_ROW_VERSION (row)) & cl->cl_row_version_mask))
	{
	  dbe_key_t * row_key;
	  key_ver_t kv = IE_KEY_VERSION (row);
	  /* there is a value, offset bit is 0  */
	  if (KV_LEFT_DUMMY == kv)
	    {
	      if (-1 == dir)
		return CC_NONE;
	      continue;
	    }

	  if (kv != kv_wanted)
	    continue; /* key versions must be eq for ref to be made */
	  switch (cl->cl_sqt.sqt_dtp)
	    {
	    case DV_LONG_INT:
	      {
		int32 n = LONG_REF (row + cl->cl_pos[rv]);
		int32 offset = unbox_inline (val) - n;
		if (offset >= 0 && offset < 16)
		  {
		    *prefix_ref = irow | offset << COL_OFFSET_SHIFT;
		    return CC_OFFSET;
		  }
		not_match_continue;
	      }
	    case DV_IRI_ID:
	      {
		iri_id_t n = (uint32) LONG_REF (row + cl->cl_pos[rv]);
		iri_id_t offset = unbox_iri_id (val) - n;
		if (offset < 16)
		  {
		    *prefix_ref = irow | offset << COL_OFFSET_SHIFT;
		    return CC_OFFSET;
		  }
		not_match_continue;
	      }
	    case DV_INT64:
	      {
		int64 n = INT64_REF (row + cl->cl_pos[rv]);
		int64 offset = unbox_inline (val) - n;
		if (offset >= 0 && offset < 16)
		  {
		    *prefix_ref = irow | offset << COL_OFFSET_SHIFT;
		    return CC_OFFSET;
		  }
		not_match_continue;
	      }
	    case DV_IRI_ID_8:
	      {
		iri_id_t n = INT64_REF (row + cl->cl_pos[rv]);
		iri_id_t offset = unbox_iri_id (val) - n;
		if (offset < 16)
		  {
		    *prefix_ref = irow | offset << COL_OFFSET_SHIFT;
		    return CC_OFFSET;
		  }
		not_match_continue;
	      }
	    default:
	      {
		db_buf_t col;
		short len, off;
		row_key = buf->bd_tree->it_key->key_versions[kv];
 		KEY_PRESENT_VAR_COL (row_key, row, (*cl), off, len);
		col = row + off;
		if (len & COL_VAR_FLAGS_MASK )
		  not_match_continue;
		switch (cl->cl_sqt.sqt_dtp)
		  {
		  case DV_ANY:
		   if (val_len != len)
		      not_match_continue;
		    if (0 != memcmp (val, col, len - 1))
		      not_match_continue;
		    delta = ((db_buf_t)val)[len - 1] - ((db_buf_t)col)[len - 1]; /*make sure it's unsigned bytes */
		    if (delta < 0 || delta > 15)
		      not_match_continue;
		    switch ((dtp_t) col[0])
		      {
		      case DV_LONG_INT: case DV_INT64:
		      case DV_IRI_ID: case DV_IRI_ID_8:
		      case DV_SHORT_STRING_SERIAL:
		      case DV_RDF:
			*prefix_ref = irow | delta << COL_OFFSET_SHIFT;
			return CC_OFFSET;
		      }
		    not_match_continue;
		  case DV_STRING:
		    {
		      int rc;
		      rc = str_delta (col, (db_buf_t) val, len, val_len, prefix_bytes, prefix_ref, extra, mode);
		      if (CC_NONE == rc)
			not_match_continue;
		      (*prefix_ref) |= irow;
		      return rc;
		    }
		  }
	      }
	    }
	}
    }
  return CC_NONE;
}


void
ck1618 (row_fill_t *rf, caddr_t val, dbe_col_loc_t * cl)
{
  int d;
  page_fill_t * pf;
  if (rf->rf_is_leaf)
    return;
  if (rf->rf_pf_hash && rf->rf_pf_hash->pfh_pf)
    pf = rf->rf_pf_hash->pfh_pf;
  else
    return;
  if (cl->cl_col_id != 1618)
    return;
  if (!pf->pf_dbg)
    {
      pf->pf_dbg = unbox (val);
      return;
    }
  d = pf->pf_dbg - unbox (val);
  pf->pf_dbg = unbox (val);
}

int
page_try_offset (buffer_desc_t * buf, db_buf_t row,
		 int irow, dbe_col_loc_t * cl, caddr_t val,
		 unsigned short * prefix_bytes, unsigned short * prefix_ref, dtp_t * extra, char * was_null, char first_only, row_fill_t * rf)
{
  int rc = -1;
  if (cl->cl_row_version_mask)
    {
      if (DV_DB_NULL == DV_TYPE_OF (val))
	{
	  *was_null = 1;
	  *prefix_ref = 0;
	  IE_ROW_VERSION (row) |= cl->cl_row_version_mask;
	  return CC_OFFSET;
	}
      *was_null = 0;
      if (rf && rf->rf_pf_hash && cl->cl_nth < rf->rf_pf_hash->pfh_n_cols
	  && rf->rf_pf_hash->pfh_kv == IE_KEY_VERSION (rf->rf_row))
	{
	  switch (cl->cl_sqt.sqt_dtp)
	    {
	    case DV_ANY:
	    case DV_STRING:
	      rc =  pfh_var (rf->rf_pf_hash, cl, (db_buf_t) val, box_length (val) - 1, prefix_bytes, prefix_ref, extra, CC_OFFSET);
	      break;
	    case DV_IRI_ID:
	    case DV_LONG_INT:
	      rc = pfh_int (rf->rf_pf_hash, unbox_iri_int64 (val), cl->cl_nth, prefix_ref);
	      break;
	    case DV_IRI_ID_8:
	    case DV_INT64:
	      rc = pfh_int64 (rf->rf_pf_hash, unbox_iri_int64 (val), cl->cl_nth, prefix_ref);
	      break;
	    }
	}
      if (-1 == rc)
	rc = col_compressed_value (buf, cl, irow, val, prefix_bytes, prefix_ref, extra, CC_OFFSET, first_only, IE_KEY_VERSION (row));
      /*ck1618 (rf, val, cl);*/
      if (CC_OFFSET == rc)
	{
	  IE_ROW_VERSION (row) |= cl->cl_row_version_mask;
	  return CC_OFFSET;
	}
      return rc;
    }
  else if (DV_STRING == cl->cl_sqt.sqt_dtp)
    {
      rc = col_compressed_value (buf, cl, irow, val, prefix_bytes, prefix_ref, extra, CC_PREFIX, first_only, IE_KEY_VERSION (row));
      return rc;
    }
  return CC_NONE;
}


void
page_set_values (buffer_desc_t * buf, row_fill_t * rf, dbe_key_t * key,
		 int irow, caddr_t * values,  dp_addr_t leaf)
{
  dbe_col_loc_t * cl;
  dtp_t res[N_COMPRESS_OFFSETS];
  char comp_null[N_COMPRESS_OFFSETS];
  unsigned short prefix_ref[N_COMPRESS_OFFSETS];
  unsigned short prefix_bytes[N_COMPRESS_OFFSETS];
  dtp_t extra[N_COMPRESS_OFFSETS];
  int inx = 0, compressible_inx = 0, val_inx = 0;
  row_ver_t rv;
  short n_comp;
  dk_set_t compressible = leaf == 0 ? (n_comp = key->key_n_row_compressibles, key->key_row_compressibles)
    : (n_comp = key->key_n_key_compressibles, key->key_key_compressibles);
  db_buf_t row = rf->rf_row;
  rf->rf_is_leaf = leaf != 0;
  RF_LARGE_CHECK (rf, 2 + 2 * n_comp, 0);
  if (leaf)
    IE_SET_KEY_VERSION (row, 0);
  else
    IE_SET_KEY_VERSION (row, key->key_version);
  IE_ROW_VERSION (row) = 0;
  if (rf->rf_no_compress)
    {
      memset (&res, CC_NONE, sizeof (res));
    }
  else
    {
      DO_SET (dbe_col_loc_t *, cl, &compressible)
	{
	  char first_only = cl->cl_col_id == ((dbe_column_t *)(key->key_parts->data))->col_id;
	  res[inx] = page_try_offset (buf, rf->rf_row, irow, cl, values[cl->cl_nth], &prefix_bytes[inx], &prefix_ref[inx], &extra[inx], &comp_null[inx], first_only, rf);
	  inx++;
	}
      END_DO_SET();
    }
  rv = IE_ROW_VERSION (row);
  RF_LARGE_CHECK (rf, leaf ? key->key_key_var_start[rv] : key->key_row_var_start[rv], 0);
  if (leaf)
    {
      LONG_SET (row + key->key_key_leaf[rv], leaf);
    }
  inx = 0;
  if (!rf->rf_no_compress)
    {
      DO_SET (dbe_col_loc_t *, cl, &compressible)
	{
	  if (CC_OFFSET == res[inx])
	    SHORT_SET (row + cl->cl_pos[rv], prefix_ref[inx]);
	  inx++;
	}
      END_DO_SET();
    }
  if (!leaf)
    memset (row + key->key_null_flag_start[rv], 0, key->key_null_flag_bytes[rv]);
  for (inx = 0; key->key_key_fixed[inx].cl_col_id; inx++)
    {
      cl = &key->key_key_fixed[inx];
      if (cl->cl_row_version_mask)
	{
	  compressible_inx++;
	  if (CC_OFFSET == res[compressible_inx - 1])
	    {
	      if (comp_null[compressible_inx - 1])
		ROW_SET_NULL (row, cl, rv);
	      else
		ROW_CLR_NULL (row, cl, rv);
	      val_inx++;
	      continue;
	    }
	}
      row_set_col (rf, cl, values[val_inx]);
      val_inx++;
    }
  rf->rf_fill = leaf ? key->key_key_var_start[rv] : key->key_row_var_start[rv];
  RF_LARGE_CHECK (rf, rf->rf_fill, 0);
  for (inx = 0; key->key_key_var[inx].cl_col_id; inx++)
    {
      cl = &key->key_key_var[inx];
      if (cl->cl_row_version_mask)
	{
	  compressible_inx++;
	  if (CC_OFFSET == res[compressible_inx - 1])
	    {
	      if (comp_null[compressible_inx - 1])
		ROW_SET_NULL (row, cl, rv);
	      else
		ROW_CLR_NULL (row, cl, rv);
	      val_inx++;
	      continue;
	    }
	  if (CC_PREFIX == res[compressible_inx - 1])
	    {
	      row_set_prefix (rf, cl, values[val_inx], prefix_bytes[compressible_inx - 1], prefix_ref[compressible_inx - 1], extra[compressible_inx - 1]);
	    }
	  else
	    row_set_col (rf, cl, values[val_inx]);
	}
      else
	{
	  if (CC_PREFIX == page_try_offset (buf, row, irow, cl, values[cl->cl_nth], &prefix_bytes[0], &prefix_ref[0], &extra[0], &comp_null[0], 0, NULL))
	    row_set_prefix (rf, cl, values[val_inx], prefix_bytes[0], prefix_ref[0], extra[0]);
	  else
	    row_set_col (rf, cl, values[val_inx]);
	}
      val_inx++;
    }
  if (leaf)
    {
      LONG_SET (rf->rf_row + key->key_key_leaf[rv], leaf);
      return;
    }
  DO_CL (cl, key->key_row_fixed)
        {
      if (cl->cl_row_version_mask)
	{
	  compressible_inx++;
	  if (CC_OFFSET == res[compressible_inx - 1])
	    {
	      if (comp_null[compressible_inx - 1])
		ROW_SET_NULL (row, cl, rv);
	      else
		ROW_CLR_NULL (row, cl, rv);
	      val_inx++;
	      continue;
	    }
	}
      row_set_col (rf, cl, values[val_inx]);
      val_inx++;
    }
  END_DO_CL;
  DO_CL (cl, key->key_row_var)
    {
      if (cl->cl_row_version_mask)
	{
	  compressible_inx++;
	  if (CC_OFFSET == res[compressible_inx - 1])
	    {
	      if (comp_null[compressible_inx - 1])
		ROW_SET_NULL (row, cl, rv);
	      else
		ROW_CLR_NULL (row, cl, rv);
	      val_inx++;
	      continue;
	    }
	  if (CC_PREFIX == res[compressible_inx - 1])
	    {
	      row_set_prefix (rf, cl, values[val_inx], prefix_bytes[compressible_inx - 1], prefix_ref[compressible_inx - 1], extra[compressible_inx - 1]);
	    }
	  else
	    row_set_col (rf, cl, values[val_inx]);
	}
      else
	{
	  if (CC_NONE != cl->cl_compression
	      && CC_PREFIX == page_try_offset (buf, row, irow, cl, values[cl->cl_nth], &prefix_bytes[0], &prefix_ref[0], &extra[0], &comp_null[0], 0, NULL))
	    row_set_prefix (rf, cl, values[val_inx], prefix_bytes[0], prefix_ref[0], extra[0]);
	  else
	    row_set_col (rf, cl, values[val_inx]);
	}
      val_inx++;
    }
  END_DO_CL;
}


void
page_set_whole_row (buffer_desc_t * buf, row_fill_t * rf, row_delta_t * rd)
{
  if (rf->rf_space < rd->rd_whole_row_len)
    rf->rf_row = rf->rf_large_row;
  memcpy (rf->rf_row, rd->rd_whole_row, rd->rd_whole_row_len);
}


int
buf_row_compare (buffer_desc_t * buf1, int i1, buffer_desc_t * buf2, int i2, int is_assert)
{
  int nth;
  db_buf_t row1 = BUF_ROW (buf1, i1);
  db_buf_t row2 = BUF_ROW (buf2, i2);
  if (KV_LEFT_DUMMY == IE_KEY_VERSION (row1))
    return DVC_LESS;
  DO_BOX (dbe_col_loc_t *, cl, nth, buf1->bd_tree->it_key->key_part_cls)
    {
      caddr_t b = page_copy_col (buf2, row2, cl, NULL);
      int res = page_col_cmp (buf1, row1, cl, b);
      if (DVC_GREATER == res && is_assert)
	{
	  log_error ("Error on key %s, out of order", buf1->bd_tree->it_key->key_name);
	  GPF_T1 ("out of order");
	}
      dk_free_box (b);
      if (res != DVC_MATCH)
	return res;
    }
  END_DO_BOX;
  return DVC_MATCH;
}


void
buf_order_ck (buffer_desc_t * buf)
{
  int inx;
  page_map_t * pm = buf->bd_content_map;
  if (buf->bd_tree->it_key->key_is_geo)
    return; /* key order criteria do not apply */
  for (inx = 0; inx < pm->pm_count - 1; inx++)
    {
      if (DVC_LESS != buf_row_compare (buf, inx, buf, inx + 1, 1))
	GPF_T1 ("insert not in order");
    }
}


#ifndef PAGE_CHECK
#define buf_order_ck(b)
#endif


void
pf_fill_registered (page_fill_t * pf, buffer_desc_t * buf)
{
  int cr_fill = 0, reg_allocd = 0;
  it_cursor_t * cr = buf->bd_registered;
  pl_rlock_table (buf->bd_pl, pf->pf_rls, &pf->pf_rl_fill);
  for (cr = cr; cr; cr = cr->itc_next_on_page)
    {
      pf->pf_registered[cr_fill++] = (placeholder_t *) cr;
      if (!reg_allocd && cr_fill >= MAX_ITCS_ON_PAGE && cr->itc_next_on_page)
	{
	  int ctr = cr_fill;
	  placeholder_t ** reg2;
	  it_cursor_t * cr2;
	  for (cr2 = cr->itc_next_on_page; cr2; cr2 = cr2->itc_next_on_page)
	    ctr++;
	  reg2 = (placeholder_t**)dk_alloc_box (sizeof (caddr_t) * ctr, DV_BIN);
	  memcpy_16 (reg2, pf->pf_registered, sizeof (caddr_t) * cr_fill);
	  pf->pf_registered = reg2;
	  reg_allocd = 1;
	}
    }
  pf->pf_cr_fill = cr_fill;
}


int
page_col_cmp_1 (buffer_desc_t * buf, db_buf_t row, dbe_col_loc_t * cl, caddr_t value)
{
  collation_t * collation;
  int res;
  db_buf_t dv1, dv2, dv3;
  int inx;
  row_size_t l1, l3;
  unsigned short offset;
  int l2;
  boxint n1, n2;
  row_ver_t rv = IE_ROW_VERSION (row);
  if (cl->cl_null_mask[rv])
    {
      if ((cl->cl_null_mask[rv] & row[cl->cl_null_flag[rv]]))
	{
	  if (DV_IS_NULL (value))
	    return DVC_MATCH;
	  else
	    return DVC_LESS;
	}
      else
	{
	  if (DV_IS_NULL (value))
	    return DVC_GREATER;
	}
    }
  switch (cl->cl_sqt.sqt_dtp)
    {
    case DV_LONG_INT:
      ROW_INT_COL (buf, row, rv, *cl, LONG_REF, n1);
    int_cmp:
      switch (DV_TYPE_OF (value))
	{
	case DV_LONG_INT:
	  n2 = unbox_inline (value);
	  return NUM_COMPARE (n1, n2);
	case DV_SINGLE_FLOAT:
	  return cmp_double (((float)n1), *(float*) value, DBL_EPSILON);
	case DV_DOUBLE_FLOAT:
	  return cmp_double (((double)n1),  *(double*)value, DBL_EPSILON);
	case DV_NUMERIC:
	  {
	    NUMERIC_VAR (n);
	    numeric_from_int64 ((numeric_t) &n, n1);
	    return (numeric_compare_dvc ((numeric_t) &n, (numeric_t) value));
	  }
	default:
	  {
	    log_error ("Unexpected param dtp=[%d]", DV_TYPE_OF (value));
	    GPF_T;
	  }
	}

    case DV_SHORT_INT:
      n1 = SHORT_REF (row + cl->cl_pos[rv]);
	      goto int_cmp;
    case DV_INT64:
      ROW_INT_COL (buf, row, rv, *cl, INT64_REF, n1);
      goto int_cmp;

    case DV_DATETIME:
    case DV_TIMESTAMP:
    case DV_DATE:
    case DV_TIME:
      ROW_FIXED_COL (buf, row, rv, *cl, dv1);
      dv2 = (db_buf_t) value;
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
	ROW_FIXED_COL (buf, row, rv, *cl, dv1);
	numeric_from_buf ((numeric_t) &n, dv1);
	if (DV_DOUBLE_FLOAT == DV_TYPE_OF (value))
	  {
	    double d;
	    numeric_to_double ((numeric_t)&n, &d);
	    return cmp_double (d, *(double*) value, DBL_EPSILON);
	  }
	return (numeric_compare_dvc ((numeric_t) &n, (numeric_t) value));
      }
    case DV_SINGLE_FLOAT:
      {
	float flt;
	ROW_FIXED_COL (buf, row, rv, *cl, dv1);
	EXT_TO_FLOAT (&flt, dv1);
	switch (DV_TYPE_OF (value))
	  {
	  case DV_SINGLE_FLOAT:
	    return (cmp_double (flt, *(float *) value, FLT_EPSILON));
	  case DV_DOUBLE_FLOAT:
	    return (cmp_double (((double)flt), *(double *) value, DBL_EPSILON));
	  case DV_NUMERIC:
	    {
	      NUMERIC_VAR (n);
	      numeric_from_double ((numeric_t) &n, (double) flt);
	      return (numeric_compare_dvc ((numeric_t)&n, (numeric_t) value));
	    }
	  }
      }
    case DV_DOUBLE_FLOAT:
      {
	double dbl;
	ROW_FIXED_COL (buf, row, rv, *cl, dv1);
	EXT_TO_DOUBLE (&dbl, dv1);
	/* if the col is double, any arg is cast to double */
	return (cmp_double (dbl, *(double *) value, DBL_EPSILON));
      }
    case DV_IRI_ID:
      {
	iri_id_t i1;
	iri_id_t i2 =  unbox_iri_id (value);
	ROW_INT_COL (buf, row, rv, *cl, (iri_id_t)(uint32)LONG_REF, i1);
	res = NUM_COMPARE (i1, i2);
	return res;
      }
    case DV_IRI_ID_8:
      {
	iri_id_t i1;
	iri_id_t i2 =  unbox_iri_id (value);
	ROW_INT_COL (buf, row, rv, *cl, INT64_REF, i1);
	res = NUM_COMPARE (i1, i2);
	return res;
      }
    default:
      ROW_STR_COL (buf->bd_tree->it_key, buf, row, cl, dv1, l1, dv3, l3, offset);
    }
  switch (cl->cl_sqt.sqt_dtp)
    {
    case DV_BIN:
      dv2 = (db_buf_t) value;
      l2 = box_length (dv2);
      return str_cmp_2 (dv1, dv2, dv3, l1, l2, l3, offset);
    case DV_STRING:
      collation = cl->cl_sqt.sqt_collation;
      dv2 = (db_buf_t) value;
      l2 = box_length_inline (dv2) - 1;
      inx = 0;
      if (collation)
	{
	  while (1)
	    {
              wchar_t xlat1, xlat2;
	      if (inx == l1)
		{
		  if (inx == l2)
		    return DVC_MATCH;
		  else
		    return DVC_LESS;
		}
	      if (inx == l2)
		return DVC_GREATER;
              xlat1 = COLLATION_XLAT_NARROW (collation, (unsigned char)dv1[inx]);
              xlat2 = COLLATION_XLAT_NARROW (collation, (unsigned char)dv2[inx]);
              if (xlat1 < xlat2)
		return DVC_LESS;
	      if (xlat1 > xlat2)
		return DVC_GREATER;
	      inx++;
	    }
	}
      else
	return str_cmp_2 (dv1, dv2, dv3, l1, l2, l3, offset);
    case DV_WIDE:
    case DV_LONG_WIDE:
      {
	/* the param is cast to narrow utf8 */
	dv2 = (db_buf_t) value;
	l2 = box_length (dv2) - 1;
	return  str_cmp_2 (dv1, dv2, dv3, l1, l2, l3, offset);
      }
    case DV_ANY:
      dv2 = (db_buf_t) value;
      return (dv_compare (dv1, dv2, cl->cl_sqt.sqt_collation, offset));
    default:
      GPF_T1 ("type not supported in comparison");
    }
  return 0;
}
#if defined (MTX_DEBUG) | defined (PAGE_TRACE)
#define OFFSET_CK(off) { if ((off) < buf->bd_buffer || (off) > buf->bd_buffer + PAGE_SZ - 2) GPF_T1 ("shift offset out of range");}
#else
#define OFFSET_CK(off)
#endif


extern unsigned char byte_logcount[256];


void
pf_shift_compress (page_fill_t * pf, row_delta_t * rd, int * del_ref_ret)
{
  /* after single insert, change comp refs that ref right of the inserted, move cursors and locks */
  short ref;
  dk_set_t compressible;
  buffer_desc_t * buf = pf->pf_current;
  row_lock_t ** rls = pf->pf_rls;
  int rl_fill = 0;
  page_lock_t * pl = buf->bd_pl;
  page_map_t * pm = buf->bd_content_map;
  int irow, map_pos = rd->rd_map_pos;
  it_cursor_t * reg = buf->bd_registered;
  if (rd->rd_key->key_simple_compress)
    {
      for (irow = map_pos; irow < pm->pm_count; irow++)
	{
	  db_buf_t row = buf->bd_buffer + pm->pm_entries[irow];
	  row_ver_t rv = IE_ROW_VERSION (row);
	  unsigned char n_offset = byte_logcount[rv & 0x1f] * 2 + 2, off;
	  for (off = 2; off < n_offset; off+= 2)
	    {
	      if ((ROW_NO_MASK & (ref = SHORT_REF (row + off))) >= map_pos)
		{
		  OFFSET_CK (row + off);
		  SHORT_SET (row + off, ref + 1);
		}
	    }
	}
    }
  else
    {
      for (irow = map_pos; irow < pm->pm_count; irow++)
	{
	  db_buf_t row = buf->bd_buffer + pm->pm_entries[irow];
	  row_ver_t rv = IE_ROW_VERSION (row);
	  key_ver_t kv = IE_KEY_VERSION (row);
	  dbe_key_t * key = rd->rd_key->key_versions[kv];
	  if (rv)
	    {
	      compressible = kv ? key->key_row_compressibles : key->key_key_compressibles;
	      DO_SET (dbe_col_loc_t *, cl, &compressible)
		{
		  if ((rv & cl->cl_row_version_mask)
		      && (ROW_NO_MASK & (ref = SHORT_REF (row + cl->cl_pos[rv]))) >= rd->rd_map_pos)
		    {
#if 0
		      if (ref == rd->rd_map_pos && del_ref_ret)
			{
			  *del_ref_ret = irow;
			  return;
			}
#endif
		      OFFSET_CK (row + cl->cl_pos[rv]);
		      SHORT_SET (row + cl->cl_pos[rv], ref + 1);
		    }
		}
	      END_DO_SET();
	    }
	  compressible = kv ? key->key_row_pref_compressibles : key->key_key_pref_compressibles;
	  DO_SET (dbe_col_loc_t *, cl, &compressible)
	    {
	      short pos;
	      if ((pos = cl->cl_pos[rv]) < 0)
		{
		  db_buf_t refp = NULL;
		  if (CL_FIRST_VAR == pos)
		    {
		      if (COL_VAR_SUFFIX & SHORT_REF (row + key->key_length_area[rv]))
			refp = row + (kv ? key->key_row_var_start[rv] : key->key_key_var_start[rv]);
		    }
		  else
		    {
		      if (COL_VAR_SUFFIX & SHORT_REF (row + 2 - pos))
			refp = row + (ROW_NO_MASK & SHORT_REF (row - pos));
		    }
		  if (refp)
		    {
		      short ref = SHORT_REF_NA (refp);
#if 0
		      if ((ROW_NO_MASK & ref) == rd->rd_map_pos && del_ref_ret)
			{
			  *del_ref_ret = irow;
			  return;
			}
#endif
		      if((ROW_NO_MASK & ref) >= rd->rd_map_pos)
			{
			  OFFSET_CK (refp);
			  SHORT_SET_NA (refp, ref + 1);
			}
		    }
		}
	    }
	  END_DO_SET();
	}
    }
  while (reg)
    {
      if (reg->itc_map_pos >= rd->rd_map_pos)
	reg->itc_map_pos++;
      reg = reg->itc_next_on_page;
    }
  if (pl)
    {
      int inx;
      for (inx = 0; inx < N_RLOCK_SETS; inx++)
	{
	  row_lock_t ** prev = &pl->pl_rows[inx], *rl;
	  while ((rl = *prev))
	    {
	      if (rl->rl_pos >= rd->rd_map_pos)
		{
		  *prev = rl->rl_next;
		  rls[rl_fill++] = rl;
		  rl->rl_pos+= 1;
		}
	      else
		prev = &rl->rl_next;
	    }
	}
      for (inx = 0; inx < rl_fill; inx++)
	{
	  row_lock_t * rl = rls[inx];
	  rl->rl_next = PL_RLS (pl, rl->rl_pos);
	  PL_RLS (pl, rl->rl_pos) = rl;
	}
    }
}

int
key_col_in_layout_seq_1 (dbe_key_t * key, dbe_column_t * col, int gpf_if_not)
{
  oid_t cid = col->col_id;
  int inx = 0;
  DO_CL (cl, key->key_key_fixed)
    {
      if (cl->cl_col_id == cid)
	return inx;
      inx++;
    }
  END_DO_CL;
  DO_CL (cl, key->key_key_var)
    {
      if (cl->cl_col_id == cid)
	return inx;
      inx++;
    }
  END_DO_CL;
  DO_CL (cl, key->key_row_fixed)
    {
      if (cl->cl_col_id == cid)
	return inx;
      inx++;
    }
  END_DO_CL;
  DO_CL (cl, key->key_row_var)
    {
      if (cl->cl_col_id == cid)
	return inx;
      inx++;
    }
  END_DO_CL;
  if (gpf_if_not)
  GPF_T1 ("asking for a col not in the key of the rd");
  return -1;
}


caddr_t
rd_col (row_delta_t * rd, oid_t cid, int * found)
{
  int inx = 0;
  if (found)
    *found = 1;
  DO_CL (cl, rd->rd_key->key_key_fixed)
    {
      if (cl->cl_col_id == cid)
	return rd->rd_values [inx];
      inx++;
    }
  END_DO_CL;
  DO_CL (cl, rd->rd_key->key_key_var)
    {
      if (cl->cl_col_id == cid)
	return rd->rd_values [inx];
      inx++;
    }
  END_DO_CL;
  DO_CL (cl, rd->rd_key->key_row_fixed)
    {
      if (cl->cl_col_id == cid)
	return rd->rd_values [inx];
      inx++;
    }
  END_DO_CL;
  DO_CL (cl, rd->rd_key->key_row_var)
    {
      if (cl->cl_col_id == cid)
	return rd->rd_values [inx];
      inx++;
    }
  END_DO_CL;
  if (found)
    *found = 0;
  else
    {
      if (rd->rd_key->key_migrate_to)
	{
	  dbe_column_t * col = sch_id_to_column (wi_inst.wi_schema, cid);
	  if (col)
	    return col->col_default;
	}
      GPF_T1 ("asking for a col not in the key of the rd");
    }
  return NULL;
}


void
rd_free (row_delta_t * rd)
{
  int inx;
  if (RD_AUTO == rd->rd_allocated)
    return;
  for (inx = 0; inx < rd->rd_n_values; inx++)
    {
      caddr_t val = rd->rd_values[inx];
      if (((db_buf_t)val < rd->rd_temp || (db_buf_t)val > rd->rd_temp + rd->rd_temp_fill) && COL_UPD_NO_CHANGE != val)
	dk_free_tree (val);
    }
  if (RD_ALLOCATED_VALUES == rd->rd_allocated)
    return;
  dk_free_box ((caddr_t) rd->rd_values);
  dk_free ((caddr_t) rd, sizeof (*rd));
}


void
rd_list_free (row_delta_t ** rds)
{
  int inx;
  DO_BOX (row_delta_t *, rd, inx, rds)
    {
      rd_free (rd);
    }
  END_DO_BOX;
  dk_free_box ((caddr_t) rds);
}


void
page_row_bm (buffer_desc_t * buf, int irow, row_delta_t * rd, int op, it_cursor_t * bm_pl)
{
  int nth = 0;
  dbe_key_t * key;
  db_buf_t row = buf->bd_buffer + buf->bd_content_map->pm_entries[irow];
  key_ver_t kv = IE_KEY_VERSION (row);
  row_ver_t rv = IE_ROW_VERSION (row);
  rd->rd_op = RD_INSERT;
  rd->rd_whole_row = NULL;
  rd->rd_temp_fill = 0;
  rd->rd_key_version = kv;
  if (!kv)
    {
      key = rd->rd_key = buf->bd_tree->it_key;
      rd->rd_leaf = LONG_REF (row + key->key_key_leaf[rv]);
    }
  else if (KV_LEFT_DUMMY == kv)
    {
      rd->rd_non_comp_len = 6;
      rd->rd_copy_of_deleted = 0; /* left dummy never deld  */
      if (RO_LEAF == op)
	rd->rd_leaf = buf->bd_page;
      else
	rd->rd_leaf = LONG_REF (row + LD_LEAF);
      return;
    }
  else
    {
      key = rd->rd_key = buf->bd_tree->it_key->key_versions[kv];
      rd->rd_leaf = 0;
    }
  rd->rd_copy_of_deleted = IE_ISSET (row, IEF_DELETE);
  if (rd->rd_copy_of_deleted && !kv) GPF_T1 ("suspect to have a leaf ptr with deld flag");
  if (!rd->rd_values && RO_LEAF == op && RD_ALLOCATED == rd->rd_allocated)
    rd->rd_values = dk_alloc_box (sizeof (caddr_t) * key->key_n_significant, DV_ARRAY_OF_POINTER);
  else  if (!rd->rd_values && RO_ROW == op && RD_ALLOCATED == rd->rd_allocated)
    rd->rd_values = (caddr_t*) dk_alloc_box_zero ((dk_set_length (key->key_parts) + key->key_is_bitmap) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  else if (!rd->rd_values)
    GPF_T1 ("only an allocd rd for leaf ptr may be w/o values");

  if (KV_LEAF_PTR == kv || RO_LEAF == op)
    {
      rd->rd_copy_of_deleted = 0; /* a leaf ptr does not have copy of deld even if the first of the leaf is an uncommitted deleted row */
      rd->rd_non_comp_len = key->key_key_var_start[0];
    }
  else
    rd->rd_non_comp_len = key->key_row_var_start[0];
  DO_CL (cl, key->key_key_fixed)
    {
      if (bm_pl && cl == key->key_bit_cl)
	{
	  rd->rd_values[nth++] = box_iri_int64 (bm_pl->itc_bp.bp_value, cl->cl_sqt.sqt_dtp);
	}
      else
	rd->rd_values[nth++] = page_copy_col (buf, row, cl, rd);
    }
  END_DO_CL;
  DO_CL (cl, key->key_key_var)
    {
      rd->rd_values[nth++] = page_copy_col (buf, row, cl, rd);
      rd->rd_non_comp_len += box_length_on_row (rd->rd_values[nth - 1]);
    }
  END_DO_CL;
  if (RO_LEAF == op)
    {
      rd->rd_n_values = nth;
      rd->rd_leaf = buf->bd_page;
      return;
    }
  if (KV_LEAF_PTR == kv)
    return;
  DO_CL (cl, key->key_row_fixed)
    {
      rd->rd_values[nth++] = page_copy_col (buf, row, cl, rd);
    }
  END_DO_CL;
  DO_CL (cl, key->key_row_var)
    {
      rd->rd_values[nth++] = page_copy_col (buf, row, cl, rd);
      rd->rd_non_comp_len += box_length_on_row (rd->rd_values[nth - 1]);
    }
  END_DO_CL;
  rd->rd_n_values = nth;
}


void
page_whole_row (buffer_desc_t * buf, int irow, row_delta_t * rd)
{
  db_buf_t row = buf->bd_buffer + buf->bd_content_map->pm_entries[irow];
  key_ver_t kv = IE_KEY_VERSION (row);
  rd->rd_op = RD_INSERT;
  rd->rd_temp_fill = 0;
  rd->rd_key_version = kv;
  if (KV_LEFT_DUMMY == kv)
    {
      rd->rd_non_comp_len = 6;
      rd->rd_copy_of_deleted = 0; /* left dummy never deld  */
	rd->rd_leaf = LONG_REF (row + LD_LEAF);
      rd->rd_whole_row = NULL;
      rd->rd_key = NULL;
      return;
    }
  rd->rd_key = buf->bd_tree->it_key->key_versions[kv];
  rd->rd_whole_row = row;
  rd->rd_whole_row_len = row_length (row, buf->bd_tree->it_key);
}


int
page_reloc_right_leaves (it_cursor_t * itc, buffer_desc_t * buf)
{
  dp_addr_t dp = buf->bd_page;
  int any = 0;
  dp_addr_t leaf;

  DO_ROWS (buf, pos, row, itc->itc_insert_key)
    {
      leaf = leaf_pointer (row, itc->itc_insert_key);
      if (leaf)
	{
	  any = 1;
	  ITC_AGE_TRX (itc, 5);
	  itc_set_parent_link (itc, leaf, dp);
	    }
    }
  END_DO_ROWS;
  return any;
}


void
page_write_gap (db_buf_t ptr, row_size_t  gap)
{
  if ((gap & 1) || (((ptrlong)ptr) & 1))
    GPF_T1 ("writing either odd gap or gap at odd address");
  if (gap < 2)
    return;
  if (gap < 256)
    {
      ptr[0] = KV_GAP;
      ptr[1] = (dtp_t) gap;
    }
  else
    {
      ptr[0] = KV_LONG_GAP;
      ptr[1] = gap >> 8;
      ptr[2] = gap & 0xff;
    }
}


void
pf_rd_move_and_lock (page_fill_t * pf, row_delta_t * rd)
{
  it_cursor_t * itc = pf->pf_itc;
  itc->itc_lock_lt = NO_LOCK_LT;
  if (rd->rd_rl)
    {
      itc->itc_page = pf->pf_current->bd_page;
      itc->itc_map_pos = rd->rd_map_pos;
      itc->itc_pl = pf->pf_current->bd_pl;
      if (!itc->itc_non_txn_insert)
      itc_insert_rl (pf->pf_itc, pf->pf_current, rd->rd_map_pos, rd->rd_rl, RL_NO_ESCALATE);
    }
  if (rd->rd_itc)
    {
      buffer_desc_t * buf = pf->pf_left ? pf->pf_current : pf->pf_org;
      it_cursor_t * registered = rd->rd_keep_together_itcs;
      itc->itc_map_pos = rd->rd_map_pos;
      itc->itc_page = buf->bd_page;
	  /* in reinsert of a uncommitted insert after cpt rb, there can be registered itcs on the row to reinsert.  re-Register them here */
      while (registered)
	{
	  it_cursor_t * next = registered->itc_next_on_page;
	  registered->itc_map_pos = rd->rd_map_pos;
	  registered->itc_page = buf->bd_page;
	  registered->itc_next_on_page = buf->bd_registered;
	  buf->bd_registered = registered;
	  registered->itc_buf_registered = buf;
	  registered->itc_bp.bp_transiting = 0; /* in leaf row split of col key, uses bp transiting and keep together itcs to maintain registered itcs.  This indicates that the move is complete */
	  registered = next;
	}
      if (itc->itc_bm_split_left_side && !itc->itc_bm_split_right_side)
	{
	  /* a bm inx entry split.  Record the right side with a pl so that can move cursors later */
	  buffer_desc_t * left_buf;
	  placeholder_t * left = itc->itc_bm_split_left_side;
	  left_buf = left->itc_buf_registered;
	  if (left_buf != pf->pf_org && left_buf != buf)
	    TC (tc_bm_split_left_separate_but_no_split);
	  itc->itc_bm_split_right_side = plh_landed_copy ((placeholder_t *) itc, buf);
	}
    }
  if (!rd->rd_rl)
    pg_move_lock (itc, pf->pf_rls, pf->pf_rl_fill, rd->rd_keep_together_pos, rd->rd_map_pos,
		  pf->pf_current->bd_pl, (pf->pf_org && pf->pf_org->bd_page != pf->pf_current->bd_page));

  if (pf->pf_cr_fill)
    pg_move_cursors ((it_cursor_t **) pf->pf_registered, pf->pf_cr_fill, pf->pf_org, rd->rd_keep_together_pos,
		     pf->pf_current->bd_page, rd->rd_map_pos, pf->pf_current);
}


row_size_t
row_space_after (buffer_desc_t * buf, short irow)
{
  db_buf_t row = buf->bd_buffer + buf->bd_content_map->pm_entries[irow];
  dbe_key_t * key = buf->bd_tree->it_key->key_versions[IE_KEY_VERSION (row)];
  int len = row_length (row, key);
  int align_gap = (len & 1) ? 1 : 0;
  int end = (row - buf->bd_buffer ) + ROW_ALIGN (len);
  int space;
  if (end <= PAGE_SZ - 2)
    space = page_gap_length (buf->bd_buffer, end);
  else
    space = 0;
  return space + align_gap;
}


int n_ins_1, n_app;
int n_refit;
int n_spacing;


int
row_refit_col (buffer_desc_t * buf, int map_pos, dbe_key_t * key, db_buf_t row, dbe_col_loc_t * cl, db_buf_t bytes, int new_len, int * space_ret)
{
  /* insert the new val if fits.  If If fits, return the space left in space_ret.  If did not fit, return how much extra space is needed in space_ret */
  page_map_t * pm;
  int space = *space_ret, new_gap, row_delta;
  int row_len = row_length (row, key), new_row_len;
  char shift = 0;
  row_ver_t rv = IE_ROW_VERSION (row);
  short off, len;
  pg_check_map (buf);
  if (DV_DB_NULL == DV_TYPE_OF (bytes))
    {
      row[cl->cl_null_flag[rv]] |= cl->cl_null_mask[rv];
      new_len = 0;
    } else if (cl->cl_null_mask[rv])
    row[cl->cl_null_flag[rv]] &= ~cl->cl_null_mask[rv];
  KEY_PRESENT_VAR_COL (key, row, (*cl), off, len);
  if (new_len - len > space)
    {
      *space_ret = new_len - len;
	return 0;
    }
  memmove (row + off + new_len, row + off + len, row_len - (off + len));
  memcpy (row + off, bytes, new_len);
  DO_CL (upd_cl, key->key_row_var)
    {
      if (upd_cl->cl_col_id == cl->cl_col_id)
	shift = 1;
      if (shift
	  && 0 == (rv & upd_cl->cl_row_version_mask))
	{
	  if (CL_FIRST_VAR == upd_cl->cl_pos[rv])
	    {
	      SHORT_SET (row + key->key_length_area[rv], key->key_row_var_start[rv] + new_len);
	    }
	  else
	    {
	      SHORT_SET (row + 2 - upd_cl->cl_pos[rv], SHORT_REF (row + 2 - upd_cl->cl_pos[rv]) + new_len - len);
	    }
	}
    }
  END_DO_CL;
  *space_ret -= new_len - len;
  new_row_len = ROW_ALIGN (row_len + new_len - len);
  row_delta = ROW_ALIGN (new_row_len) - ROW_ALIGN (row_len);
  space &= ~1;
  new_gap = space - row_delta;
  if (new_gap < 0) GPF_T1 ("in place upd gone wrong, negative space left");
  if (new_gap)
    page_write_gap (row + ROW_ALIGN (new_row_len), new_gap);
  pm = buf->bd_content_map;
  pm->pm_bytes_free -= row_delta;
  if (pm->pm_entries[map_pos] + ROW_ALIGN (row_len) == pm->pm_filled_to)
    pm->pm_filled_to += row_delta;
  else if (pm->pm_entries[map_pos] + ROW_ALIGN (row_len) > pm->pm_filled_to)
    GPF_T1 ("in refit col, last row past filled to, not equal to filled to");
  return 1;
}


void
page_row_spacing (buffer_desc_t * buf, short row_gap, short ins_inx, int ins_gap)
{
  /* rewrite the page with gap bytes gaop after all rows.  For the row at ins_inx, the gap is gap + ins_gap.  All the rest is left at the end. */
  short gap = 0;
  int fill = DP_DATA;
  dbe_key_t * key = buf->bd_tree->it_key;
  page_map_t * pm = buf->bd_content_map;
  dtp_t page[PAGE_SZ];
  DO_ROWS (buf, map_pos, row, NULL)
    {
      int len = row_length (row, key);
      len = ROW_ALIGN (len);
      memcpy (&page[fill], row, len);
      if (map_pos == ins_inx)
	gap = row_gap + ins_gap;
      else
	gap = row_gap;
      if (fill + len + gap > PAGE_SZ) GPF_T1 ("respacing goes over end");
      page_write_gap (&page[fill + len], gap);
      pm->pm_entries[map_pos] = fill;
      fill += len + gap;

    }
  END_DO_ROWS;
  fill -= gap;
  pm->pm_filled_to = fill;
  memcpy (buf->bd_buffer + DP_DATA, &page[DP_DATA], fill - DP_DATA);
  if (PAGE_SZ - fill >= 2)
    page_write_gap (buf->bd_buffer + fill, PAGE_SZ - fill);
  pg_check_map (buf);
}


int
pf_rd_refit_1 (page_fill_t * pf, row_delta_t * rd, int recursive)
{
  buffer_desc_t * buf = pf->pf_current;
  page_map_t * pm = buf->bd_content_map;
  db_buf_t row = buf->bd_buffer + pm->pm_entries[rd->rd_map_pos];
  dbe_key_t * key = rd->rd_key->key_versions[IE_KEY_VERSION (row)];
  int inx, rc = 0;
  int space = row_space_after (buf, rd->rd_map_pos), avail, gap;
  if (!buf->bd_is_write || !buf->bd_is_dirty) GPF_T1 ("refit1 for non excl or non dirty buffer");
  for (inx = 0; inx < rd->rd_n_values; inx++)
    {
      if (rd->rd_upd_change[inx])
	{
	  rc = row_refit_col (buf, rd->rd_map_pos, key, row, rd->rd_upd_change[inx], (db_buf_t)rd->rd_values[inx], box_length_on_row (rd->rd_values[inx]), &space);
	  if (!rc)
	    break;
	}
    }
  if (rc)
    {
      n_refit++;
      if (rd->rd_rl)
	itc_insert_rl (pf->pf_itc, buf, rd->rd_map_pos, rd->rd_rl, RL_NO_ESCALATE);
            pg_check_map (buf);
      page_leave_outside_map_chg (buf, RWG_WAIT_DATA);
      return 1;
    }
  /* the cols did not fit.  See if need rearrange or split */
  space = ROW_ALIGN (space);
  /* multiple cols can be updated and each potentially requires a reshuffle if the gap at the end is not long enough.  If so, the page is full enough and can as well split */
    if (space > pm->pm_bytes_free || recursive)
    {
      rd->rd_op = RD_UPDATE;
      return 0;
    }
  avail = pm->pm_bytes_free - space;
  gap = (avail / pm->pm_count) & ~1;
  if (gap < 4)
    {
      rd->rd_op = RD_UPDATE;
      return 0;
    }
  if (gap > 10)
    gap = (gap / 4 * 3) & ~1; /* if not not tight, decrease gap for space for inserts at the end */
  n_spacing++;
  page_row_spacing (buf, gap, rd->rd_map_pos, space);
  rc = pf_rd_refit_1 (pf, rd, 1);
  return rc;
}


int
pf_rd_insert_1 (page_fill_t * pf, row_delta_t * rd)
{
  int len, place;
  dtp_t row_image[MAX_ROW_BYTES];
  row_fill_t rf;
  buffer_desc_t * buf = pf->pf_current;
  page_map_t * pm = buf->bd_content_map;
  if (!buf->bd_is_write || !buf->bd_is_dirty) GPF_T1 ("not in on write in insert_1 ");
  n_ins_1++;
  rf.rf_row = buf->bd_buffer + pm->pm_filled_to;
  rf.rf_large_row = &row_image[0];
  rf.rf_space = PAGE_SZ - pm->pm_filled_to;
  rf.rf_fill = 0;
  rf.rf_pf_hash = NULL;
  rf.rf_no_compress = 0;
  if (KV_LEFT_DUMMY == rd->rd_key_version)
    return 0;
  rf.rf_key = rd->rd_key;
  if (rd->rd_non_comp_len < 200)
    {
      if (pm->pm_n_non_comp)
	rf.rf_no_compress = 1;
      else if (pm->pm_filled_to < PAGE_SZ / 10 * 9)
	rf.rf_no_compress = 1;
    }
  page_set_values (pf->pf_current, &rf, rd->rd_key, rd->rd_map_pos, rd->rd_values, rd->rd_leaf);
  if (rf.rf_row == rf.rf_large_row)
    return 0;

  /* it fit on the page.  Add to map */
  if (rf.rf_no_compress)
    pm->pm_n_non_comp++;
  if (SHORT_REF (buf->bd_buffer + DP_LAST_INSERT) + 1 == rd->rd_map_pos)
    SHORT_SET (buf->bd_buffer + DP_RIGHT_INSERTS, 1 + SHORT_REF (buf->bd_buffer + DP_RIGHT_INSERTS));
  else
    SHORT_SET (buf->bd_buffer + DP_RIGHT_INSERTS, 0);
  SHORT_SET (buf->bd_buffer + DP_LAST_INSERT, rd->rd_map_pos);

  len = row_length (rf.rf_row, rd->rd_key);
  if (len > rf.rf_space) GPF_T1 ("pf_rd_insert_1 overflowed target without splitting the page.");
  if (len != ROW_ALIGN (len))
    rf.rf_row[len] = 0;  /* 0 for compression */
  if (rd->rd_copy_of_deleted)
    {
      if (!wi_inst.wi_is_checkpoint_pending)
	GPF_T1 ("not supposed to in copy of deleted");
      IE_SET_FLAGS (rf.rf_row, IEF_DELETE);
    }
  place = pf->pf_current->bd_content_map->pm_filled_to;
  pf_shift_compress (pf, rd, NULL);
  map_insert_pos (pf->pf_current, &pf->pf_current->bd_content_map, rd->rd_map_pos, pm->pm_filled_to);
  pm = pf->pf_current->bd_content_map;
  pm->pm_filled_to += ROW_ALIGN (len);
  page_write_gap (pf->pf_current->bd_buffer + pm->pm_filled_to, PAGE_SZ - pm->pm_filled_to);
  pm->pm_bytes_free -= ROW_ALIGN (len);
  pf->pf_org = pf->pf_current;
  pf_rd_move_and_lock (pf, rd);
  if (rd->rd_make_ins_rbe && !pf->pf_itc->itc_lock_lt->lt_is_excl)
    lt_rb_insert (pf->pf_itc->itc_lock_lt, pf->pf_current, pf->pf_current->bd_buffer + place);
  buf_order_ck (pf->pf_current);
  pg_check_map (pf->pf_current);
  return 1;
}


long tc_multi_split;
long tc_page_rewrite_overflow;

void
pf_rd_append (page_fill_t * pf, row_delta_t * rd, row_size_t * split_after)
{
  dtp_t row_image[MAX_ROW_BYTES];
  row_fill_t rf;
  page_map_t * pm = pf->pf_current->bd_content_map;
  n_app++;
  rf.rf_row = pf->pf_current->bd_buffer + pm->pm_filled_to;
  rf.rf_large_row = &row_image[0];
  rf.rf_space = PAGE_SZ - pm->pm_filled_to;
  rf.rf_fill = 0;
  rf.rf_no_compress = 0;
  if (KV_LEFT_DUMMY == rd->rd_key_version)
    {
      if (rf.rf_space != PAGE_DATA_SZ) GPF_T1 ("left dummy inserted not at start");
      IE_SET_KEY_VERSION (rf.rf_row, KV_LEFT_DUMMY);
      IE_ROW_VERSION (rf.rf_row) = 0;
      LONG_SET (rf.rf_row + LD_LEAF, rd->rd_leaf);
      pm->pm_entries[0] = DP_DATA;
      pm->pm_count = 1;
      pm->pm_filled_to += 6;
      page_write_gap (pf->pf_current->bd_buffer + pm->pm_filled_to, PAGE_SZ - pm->pm_filled_to);
      pm->pm_bytes_free -= 6;
      pf_rd_move_and_lock (pf, rd);
      return;
    }
  if (rd->rd_key->key_is_col && pf->pf_left && !rd->rd_leaf)
    rd_left_col_refs (pf, rd);
  rf.rf_key = rd->rd_key;
  rf.rf_pf_hash = pf->pf_hash;
  rf.rf_map_pos = rd->rd_map_pos = pm->pm_count;
  if (rd->rd_whole_row)
    page_set_whole_row (pf->pf_current, &rf, rd);
  else
  page_set_values (pf->pf_current, &rf, rd->rd_key, pm->pm_count, rd->rd_values, rd->rd_leaf);
  if (pf->pf_current->bd_content_map->pm_filled_to > *split_after
      || rf.rf_row == rf.rf_large_row)
    {
      /* the item did not fit. Start new page with the insertion */
      buffer_desc_t * extend;
      pf->pf_itc->itc_tree->it_is_single_page = 0;
      if (PA_REWRITE_ONLY == pf->pf_op)
	{
	  TC (tc_page_rewrite_overflow);
	  pf->pf_rewrite_overflow = 1;
	  return;
	}
      if (pf->pf_is_autocompact)
	{
	  extend = buffer_allocate (DPF_INDEX);
	  extend->bd_content_map = pm_get (extend, (PM_SZ_1));
	  pg_map_clear (extend);
	  extend->bd_tree = pf->pf_itc->itc_tree;
	}
      else
	{
	  extend = it_new_page (pf->pf_itc->itc_tree,
				pf->pf_org->bd_page, DPF_INDEX, 0, pf->pf_itc);
	  if (!extend)
	    GPF_T1("Can't get page buffer from it_new_page");
	  if (pf->pf_itc->itc_is_ac)
	    dk_set_push (&pf->pf_itc->itc_ac_non_leaf_splits, (void*)(ptrlong)extend->bd_page);
	  rdbg_printf_2 ((" page L=%d split under L=%d exte L=%d  org ct=%d post ct=%d \n", pf->pf_org->bd_page, LONG_REF (pf->pf_org->bd_buffer + DP_PARENT), extend->bd_page,
			  pf->pf_org->bd_content_map->pm_count, pf->pf_current->bd_content_map->pm_count));
	}
      if (rd->rd_key->key_is_col)
	{
	pf_col_right_edge (pf, rd);
	  if (pf->pf_left) /* first left gets checked at the very end */
	    itc_ce_check (pf->pf_itc, pf->pf_current, 1);
	}

      if (!extend)
        GPF_T1("Can't get page buffer");

      pfh_init (pf->pf_hash, extend);
      /* the row that did not fit went over the gap mark.  Put the gap mark back */
      page_write_gap (pf->pf_current->bd_buffer + pf->pf_current->bd_content_map->pm_filled_to,
		      PAGE_SZ - pf->pf_current->bd_content_map->pm_filled_to);
      *split_after = PAGE_SZ;
      if (pf->pf_org)
	itc_split_lock (pf->pf_itc, pf->pf_org, extend); /* pf_org not sety in autocompact */
      ITC_LEAVE_MAPS (pf->pf_itc);
      if (pf->pf_left)
	{
	  if (!pf->pf_is_autocompact)
	    TC (tc_multi_split);
	  page_reloc_right_leaves (pf->pf_itc, pf->pf_current);
	}
      pf->pf_left = dk_set_conc (pf->pf_left, dk_set_cons ((void*) pf->pf_current, NULL));
      pf->pf_current = extend;
      pf_rd_append (pf, rd, split_after);
    }
  else
    {
      /* it fit on the page.  Add to map */
      int len = row_length (rf.rf_row, rd->rd_key);
      if (len > rf.rf_space) GPF_T1 ("pf_rd_append overflowed target without splitting the page.");
      if (rd->rd_copy_of_deleted)
	IE_SET_FLAGS (rf.rf_row, IEF_DELETE);
      if (len != ROW_ALIGN (len))
	rf.rf_row[len] = 0; /* 0 for compression */
      map_insert_pos (pf->pf_current, &pf->pf_current->bd_content_map, pm->pm_count, pm->pm_filled_to);
      pm = pf->pf_current->bd_content_map;
      pf_rd_move_and_lock (pf, rd);
      if (rd->rd_make_ins_rbe && RD_INSERT == rd->rd_op)
	lt_rb_insert (pf->pf_itc->itc_lock_lt, pf->pf_current, pf->pf_current->bd_buffer + pf->pf_current->bd_content_map->pm_filled_to);
      pm->pm_filled_to += ROW_ALIGN (len);
      page_write_gap (pf->pf_current->bd_buffer + pm->pm_filled_to, PAGE_SZ - pm->pm_filled_to);
      pm->pm_bytes_free -= ROW_ALIGN (len);
    }
}


int
pf_is_single_leaf (page_fill_t * pf)
{
  buffer_desc_t * buf = pf->pf_current;
  db_buf_t row = BUF_ROW (buf, 0);
  dp_addr_t parent = LONG_REF (buf->bd_buffer + DP_PARENT);
  key_ver_t kv = IE_KEY_VERSION (row);
  if (0 == parent)
    return 0;
  if (KV_LEAF_PTR == kv)
    return 1;
  if (KV_LEFT_DUMMY == kv)
    {
      dp_addr_t leaf = LONG_REF (row + LD_LEAF);
      if (leaf)
	return 1;
    }
  return 0;
}


row_delta_t **
pf_rd_list (page_fill_t * pf, char first_affected, dp_addr_t * first_dp_ret, char * del_current)
{
  row_delta_t ** arr;
  dk_set_t res = NULL;
  int is_first = 1;
  *del_current = 0;
  if (!pf->pf_left && 1 == pf->pf_current->bd_content_map->pm_count
      && pf_is_single_leaf (pf))
    {
      NEW_VARZ (row_delta_t, rd);
      rd->rd_allocated = RD_ALLOCATED;
      *first_dp_ret = pf->pf_org->bd_page;
      *del_current = 1;
      page_row (pf->pf_current, 0, rd, RO_ROW);
      /* must be ro_row to get the lp as it is on the row, not the dp of the containing buf */
      rd->rd_op = RD_UPDATE;
      return (row_delta_t **) list (1, rd);
    }

  if (!pf->pf_left && DP_DATA == pf->pf_current->bd_content_map->pm_filled_to)
    {
      NEW_VARZ (row_delta_t, rd);
      rd->rd_allocated = RD_ALLOCATED;
      rd->rd_op = RD_DELETE;
      *first_dp_ret = pf->pf_org->bd_page;
      *del_current = 1;
      return (row_delta_t **) list (1, rd);
    }
  if (!pf->pf_left && !first_affected)
    return NULL;
  DO_SET (buffer_desc_t *, buf, &pf->pf_left)
    {
      if (!is_first || first_affected)
	{
	  NEW_VARZ (row_delta_t, rd);
	  rd->rd_allocated = RD_ALLOCATED;
	  dk_set_append_1 (&res, (void*) rd);
	  page_row (buf, 0, rd, RO_LEAF);
	}
      if (is_first)
	{
	  *first_dp_ret = buf->bd_page;
	  is_first = 0;
	}
    }
  END_DO_SET();
  {
    NEW_VARZ (row_delta_t, rd);
    rd->rd_allocated = RD_ALLOCATED;
    if (is_first)
      *first_dp_ret = pf->pf_current->bd_page;
    dk_set_append_1 (&res, (void*) rd);
    page_row (pf->pf_current, 0, rd, RO_LEAF);
  }
  arr = (row_delta_t **)list_to_array  (res);
  if (first_affected)
    {
      arr[0]->rd_op = RD_UPDATE;
    }
  return arr;
}


void
pl_next_pos (placeholder_t * pl, buffer_desc_t * buf)
{
  /* when pl moves when reg row deleted, go back/fwd and consider page ends */
  if (ITC_AT_END == pl->itc_map_pos)
    return;
  if (pl->itc_desc_order)
    {
      pl->itc_map_pos = pl->itc_map_pos > 0 ? pl->itc_map_pos - 1: ITC_AT_END;
    }
  else
    pl->itc_map_pos++;
}


void
page_reg_past_end (buffer_desc_t * buf)
{
  placeholder_t * pl;
  for (pl = (placeholder_t*)buf->bd_registered; pl; pl = (placeholder_t*)pl->itc_next_on_page)
    {
      if (pl->itc_map_pos >= buf->bd_content_map->pm_count)
	pl->itc_map_pos = ITC_AT_END;
    }
}


void
pg_local_delete_move (page_fill_t * pf, int irow)
{
  /* if reg'd here, move 1 fwd if fwd, 1 else 1 bwd.  If target dp different, re register */
  int inx;
  for (inx = 0; inx < pf->pf_cr_fill; inx++)
    {
      placeholder_t * pl = pf->pf_registered[inx];
      if (!pl)
	continue;
      if (pl->itc_map_pos == irow)
	{
	  pl->itc_is_on_row = 0;
	  if (!pl->itc_desc_order)
	    {
	      pl->itc_map_pos = ITC_DELETED;
	    }
	  else
	    {
	      if (pf->pf_left)
		{
		  if (pl->itc_page != pf->pf_current->bd_page)
		    {
		      itc_unregister_inner ((it_cursor_t*)pl, pl->itc_buf_registered, 1);
		      pl->itc_page = pf->pf_current->bd_page;
		      itc_register ((it_cursor_t *)pl, pf->pf_current);
		    }
		}
	      pl->itc_map_pos = pf->pf_current->bd_content_map->pm_count;
	      pl_next_pos (pl, pl->itc_buf_registered);
	    }
	}
    }
}


void
pg_delete_move_cursors (it_cursor_t * itc, buffer_desc_t * buf_from, int pos_from,
			buffer_desc_t * buf_to, int pos_to)
{
  it_cursor_t *it_list;
  assert (buf_from->bd_is_write && (!buf_to || buf_to->bd_is_write));
  it_list = buf_from->bd_registered;

  while (it_list)
    {
      it_cursor_t *next = it_list->itc_next_on_page;
      if (buf_to)
	{
	  rdbg_printf (("  itc delete move by T=%d moved itc=%x  from L=%d pos=%d to L=%d pos=%d was_on_row=%d \n",
			TRX_NO (itc->itc_ltrx), it_list, it_list->itc_page, it_list->itc_map_pos, buf_to->bd_page, pos_to, it_list->itc_is_on_row));
	  itc_unregister_inner (it_list, buf_from, 1);
	  it_list->itc_page = buf_to->bd_page;
	  it_list->itc_map_pos = pos_to;
	  it_list->itc_is_on_row = 0;
	  itc_register (it_list, buf_to);
	  if (it_list->itc_desc_order)
	    pl_next_pos ((placeholder_t*) it_list, buf_to);
	}
      else
	{
	  if (it_list->itc_page == buf_from->bd_page
	      && it_list->itc_map_pos == pos_from)
	    {
	      rdbg_printf (("  itc delete move inside page by T=%d moved itc=%x  from L=%d pos=%d to L=%d pos=%d was_on_row=%d \n",
			    TRX_NO (itc->itc_ltrx), it_list, it_list->itc_page, it_list->itc_map_pos, buf_from->bd_page, pos_to, it_list->itc_is_on_row));
	      it_list->itc_map_pos = pos_to;
	      if (it_list->itc_desc_order)
		pl_next_pos ((placeholder_t *) it_list, buf_from);
	      it_list->itc_is_on_row = 0;
	    }
	}
      it_list = next;
    }
}

void
pf_release_pl (page_fill_t * pf)
{
  /* if this is commit or rb delta batch, release the org buf's pl.  Do not release others since if split, these come later, being added to the finishing pl */
  buffer_desc_t * buf = pf->pf_left ? (buffer_desc_t *) pf->pf_left->data : pf->pf_current;
  pl_release (buf->bd_pl, pf->pf_itc->itc_ltrx, buf);
}


void
itc_delete_rl_bust (it_cursor_t * itc, int pos)
{
  page_lock_t * pl = itc->itc_pl;
  row_lock_t * rl;
  if (!pl)
    return;
  rl = pl_row_lock_at (itc->itc_pl, pos);
  if (rl)
    rl->rl_pos = ITC_AT_END;
}


int
rd_list_bytes (buffer_desc_t * buf, int n, row_delta_t ** rds, row_size_t * split_after, char * all_ins)
{
  int inx, bytes = 0, ins_offset = 0;
  int n_consec = 0, prev_ins = -2;
  int is_ins = !n ? 0 : 1;
  for (inx = 0; inx < n; inx++)
    {
      row_delta_t * rd = rds[inx];
      switch (rd->rd_op)
	{
	case RD_INSERT:
	  bytes += rd->rd_non_comp_len;
	  if (prev_ins == rd->rd_map_pos - 1)
	    n_consec++;
	  prev_ins = rd->rd_map_pos;
	  break;
	case RD_DELETE:
	  bytes -= row_length (buf->bd_buffer + buf->bd_content_map->pm_entries[rds[inx]->rd_map_pos],
			       buf->bd_tree->it_key);
	  break;
	case RD_UPDATE:
	case RD_UPDATE_LOCAL:
	  bytes -= row_length (buf->bd_buffer + buf->bd_content_map->pm_entries[rds[inx]->rd_map_pos - ins_offset],
			       buf->bd_tree->it_key);
	  bytes += rds[inx]->rd_non_comp_len;
	  break;
    }
      if (RD_INSERT != rd->rd_op)
	is_ins = 0;
      else
	ins_offset++;
    }
  if (bytes > PAGE_SZ * 2 / 3)
    *split_after = PAGE_SZ * 14 / 15;
  else if (is_ins)
    {
      if (n_consec > n / 2)
	*split_after = PAGE_SZ * 14 / 15;
    }
  *all_ins = is_ins;
  return bytes;
}


void
page_apply_parent (buffer_desc_t * buf, page_fill_t * pf, char first_affected, char release_pl, char change, page_apply_frame_t * paf);

void
pf_change_org (page_fill_t * pf)
{
  short org_sz, fill;
  buffer_desc_t * org = pf->pf_org;
  buffer_desc_t * t_buf = pf->pf_left ? (buffer_desc_t*) pf->pf_left->data : pf->pf_current;
  org->bd_pl = t_buf->bd_pl;
  if (org->bd_pl && org->bd_page != org->bd_pl->pl_page)
    GPF_T1 ("bad pl returned to org buf");
  if (t_buf->bd_content_map->pm_count > org->bd_content_map->pm_size)
    {
      int new_sz = PM_SIZE (t_buf->bd_content_map->pm_count);
      map_resize (org, &org->bd_content_map, new_sz);
    }
  org_sz = org->bd_content_map->pm_size;
  memcpy_16 (org->bd_content_map, t_buf->bd_content_map, PM_ENTRIES_OFFSET + t_buf->bd_content_map->pm_count * sizeof (short));
  org->bd_content_map->pm_size = org_sz;
  fill = t_buf->bd_content_map->pm_filled_to + MAX_KV_GAP_BYTES;
  fill = MIN (fill, PAGE_SZ);
  memcpy_16 (org->bd_buffer + DP_DATA, t_buf->bd_buffer + DP_DATA, fill - DP_DATA);
  if (pf->pf_left)
    pf->pf_left->data = (void*) pf->pf_org;
  else
    pf->pf_current = pf->pf_org;
  if (!LONG_REF (org->bd_buffer + DP_KEY_ID)) GPF_T1 ("no key id in jbuffer");
  buf_set_dirty (org);
  if (org->bd_content_map->pm_count)
      pg_check_map (org);
  if (pf->pf_itc->itc_insert_key->key_is_col)
    itc_ce_check (pf->pf_itc, org, 1);
    }


void
pa_page_leave (it_cursor_t * itc, buffer_desc_t * buf, int chg)
{
  if (itc->itc_app_stay_in_buf)
    {
      itc->itc_app_stay_in_buf = ITC_APP_STAYED;
      itc->itc_buf = buf;
      return;
    }
  itc->itc_buf = NULL;
  page_leave_outside_map_chg (buf, chg);
}


#define PF_REG_FREE \
  if (pf.pf_registered != &paf->paf_registered[0]) \
    dk_free_box (pf.pf_registered);


void
page_apply_1 (it_cursor_t * itc, buffer_desc_t * buf, int n_delta, row_delta_t ** delta, int op,
	      page_apply_frame_t * paf)
{
  row_lock_t ** rlocks = paf->paf_rlocks;
  char first_affected = 0, end_insert = 0;
  char change = itc->itc_insert_key->key_is_col ? RWG_WAIT_KEY : RWG_WAIT_NO_CHANGE, hold_taken = 0;
  char all_ins = 0;
  page_map_t * org_pm = buf->bd_content_map;
  row_size_t split_after = PAGE_SZ;
  int bytes_delta = rd_list_bytes (buf, n_delta, delta, &split_after, &all_ins);
  page_fill_t pf;
  buffer_desc_t * t_buf = &paf->paf_buf;
  page_map_t * t_map = &paf->paf_map;
  dtp_t * t_page = paf->paf_page;
  int delta_inx = 0, irow, inx;
  int irow_shift = 0;
  char init_op = op;
  op &= ~PA_SPLIT_UNLIKELY;
  pg_check_map (buf);
  memset (&pf, 0, sizeof (pf));
  pf.pf_rls = &paf->paf_rlocks[0];
  pf.pf_itc = itc;
  pf.pf_op = op;
  if (!LONG_REF (buf->bd_buffer + DP_PARENT))
    it_root_image_invalidate (buf->bd_tree);

  if (all_ins)
    {
      if (buf->bd_content_map->pm_filled_to + bytes_delta < PAGE_SZ)
	{
	  int inx;
	  pf.pf_current = buf;
	  for (inx = 0; inx < n_delta; inx++)
	    {
	      if (!pf_rd_insert_1 (&pf, delta[inx]))
		break;
	    }
	  if (inx == n_delta)
	    {
	      pa_page_leave (itc, buf, RWG_WAIT_KEY);
	    return;
	}
	  if (inx > 0)
	    {
	      page_apply_1 (itc, buf, n_delta - inx, &delta[inx], op, paf);
	      return;
	    }
	}
      else
	{
	  /* could split.  But will not always split if many uncompressed rows.  So if any, rewrite with compress and see again */
	  if (org_pm->pm_n_non_comp > org_pm->pm_count / 20)
	    {
	      /*printf ("L=%d : %d non-comp rows of %d: ", buf->bd_page, org_pm->pm_n_non_comp, org_pm->pm_count);*/
	      page_apply_1 (itc, buf, 0, NULL, PA_REWRITE_ONLY, paf);
	      /*printf (" compress to %d bytes\n", buf->bd_content_map->pm_filled_to);*/
	      /* the rewrite can overflow with prefix compressed strings.  Recompress is not guaranteed not to hit worse.  If this happens, the rewrite does nothing.  So anyway reset the non-comp count */
	      org_pm->pm_n_non_comp = 0;
	      page_apply_1 (itc, buf, n_delta, delta, op, paf);
	      return;
	    }
	}
    }
  if (1 == n_delta && RD_UPDATE_LOCAL == delta[0]->rd_op)
    {
      pf.pf_current = buf;
      if (pf_rd_refit_1 (&pf, delta[0], 0))
	return;
      split_after = PAGE_SZ / 2;
    }
  memset (t_buf, 0, sizeof (buffer_desc_t));
  memset (t_map, 0, PM_ENTRIES_OFFSET);
  BD_SET_IS_WRITE ((t_buf), 1);
  t_buf->bd_content_map = t_map;
  t_buf->bd_tree = buf->bd_tree;
  t_buf->bd_pl = buf->bd_pl;
  t_buf->bd_buffer = t_page;
  t_buf->bd_page = buf->bd_page;
  t_map->pm_filled_to = DP_DATA;
  t_map->pm_bytes_free = PAGE_DATA_SZ;
  t_map->pm_size = PM_MAX_ENTRIES;
  pf.pf_registered = &paf->paf_registered[0];
  pf.pf_org = buf;
  pf.pf_current = t_buf;
  if (op != PA_REWRITE_ONLY)
    pf_fill_registered (&pf, buf);
  if (org_pm->pm_bytes_free < bytes_delta)
    {
      if (!itc->itc_n_pages_on_hold && op != PA_REWRITE_ONLY)
	{
	  itc_hold_pages (itc, buf, DP_INSERT_RESERVE);
	  hold_taken = 1;
	}
      if (PAGE_SZ == split_after && !(PA_SPLIT_UNLIKELY & init_op))
      split_after = SHORT_REF (buf->bd_buffer + DP_RIGHT_INSERTS) > 5 ? (PAGE_SZ /12) * 11 : PAGE_SZ /2;
    }
  {
    row_delta_t * rd = &paf->paf_rd;
    memset (rd, 0, sizeof (row_delta_t));	\
    rd->rd_temp = &paf->paf_rd_temp[0];		\
    rd->rd_temp_max = sizeof (paf->paf_rd_temp);
    rd->rd_values = paf->paf_rd_values;
    rd->rd_allocated = RD_AUTO;
    pf.pf_hash = (pf_hash_t *) resource_get (pfh_rc);
    pfh_init (pf.pf_hash, pf.pf_current);
    pf.pf_hash->pfh_pf = &pf;
    for (irow = 0; irow < org_pm->pm_count || delta_inx < n_delta; irow++)
      {
	if (delta_inx < n_delta && irow == delta[delta_inx]->rd_map_pos - irow_shift)
	  {
	    if (delta_inx < n_delta - 1 &&  delta[delta_inx + 1]->rd_map_pos <= delta[delta_inx]->rd_map_pos) GPF_T1 ("deltas in page apply are in non increasing row number order");
	    switch (delta[delta_inx]->rd_op)
	      {
	      case RD_INSERT:
		irow_shift++;
		change = RWG_WAIT_KEY;
		if (0 == irow && org_pm->pm_count)
		  first_affected = 1;
		pf_rd_append (&pf, delta[delta_inx], &split_after);
		delta_inx++;
		if (SHORT_REF (buf->bd_buffer + DP_LAST_INSERT) + 1 == irow)
		  SHORT_SET (buf->bd_buffer + DP_RIGHT_INSERTS, 1 + SHORT_REF (buf->bd_buffer + DP_RIGHT_INSERTS));
		else
		  SHORT_SET (buf->bd_buffer + DP_RIGHT_INSERTS, 0);
		SHORT_SET (buf->bd_buffer + DP_LAST_INSERT, irow);
		if (irow >= org_pm->pm_count)
		  end_insert = 1;
		irow--;
		break;
	      case RD_DELETE:
		change = RWG_WAIT_KEY;
		if (KV_LEFT_DUMMY == IE_KEY_VERSION (buf->bd_buffer + org_pm->pm_entries[irow]))
		  GPF_T1 ("del of left dummy not done");
		pg_local_delete_move (&pf, irow);
		pg_move_lock (pf.pf_itc, pf.pf_rls, pf.pf_rl_fill, irow, ITC_AT_END,
			      pf.pf_current->bd_pl, pf.pf_left != NULL);
		if (0 == irow)
		  first_affected = 1;
		delta_inx++;
		break;
	      case RD_UPDATE:
	      case RD_UPDATE_LOCAL:
		if (KV_LEFT_DUMMY == IE_KEY_VERSION (buf->bd_buffer + org_pm->pm_entries[irow]) && KV_LEFT_DUMMY != delta[delta_inx]->rd_key_version)
		  GPF_T1 ("upd of left dummy not done");
		change = MAX (change, RWG_WAIT_KEY);
		if (0 == irow && KV_LEFT_DUMMY != delta[delta_inx]->rd_key_version)
		  first_affected = 1;
		pf_rd_append (&pf, delta[delta_inx], &split_after);
		delta_inx++;
		break;
	      }
	  }
	else if (irow < org_pm->pm_count)
	  {
	    if (itc->itc_insert_key->key_no_compression && !itc->itc_insert_key->key_is_col)
	      page_whole_row (buf, irow, rd);
	    else
	    page_row (buf, irow, rd, 0);
	    rd->rd_keep_together_dp = buf->bd_page;
	    rd->rd_keep_together_pos = irow;
	    pf_rd_append (&pf, rd, &split_after);
	    rd_free (rd);
	    if (pf.pf_rewrite_overflow)
	      break; /* if just for compress rewrite and got worse compression than org, return without changing the org */
	  }
	if (irow < -1 || irow >org_pm->pm_count + n_delta + 1) GPF_T1 ("irow out of range");
      }
    resource_store (pfh_rc, (void*)pf.pf_hash);
  }
  if (pf.pf_left)
    {
      if (itc->itc_insert_key->key_is_geo) GPF_T1 ("geo is not supposed to split like other inxes");
      page_reloc_right_leaves (pf.pf_itc, pf.pf_current);
    }
  if (pf.pf_rewrite_overflow)
    {
      PF_REG_FREE;
    return; /* if unsuccessful compress rewrite, return w/o effect */
    }
  /* next for cursors whose row was deld and had no row after it */
  for (inx = 0; inx < pf.pf_cr_fill; inx++)
    if (pf.pf_registered[inx] && ITC_DELETED == pf.pf_registered[inx]->itc_map_pos)
      pf.pf_registered[inx]->itc_map_pos = ITC_AT_END;

  PF_REG_FREE;
  if (pf.pf_left)
      buf_order_ck (pf.pf_current);
  pf_change_org (&pf);
  if (pf.pf_org != pf.pf_current && itc->itc_insert_key->key_is_col)
    itc_ce_check (itc, pf.pf_current, 1);
  page_reg_past_end (pf.pf_org);
  for (inx = 0; inx < pf.pf_rl_fill; inx++)
    {
      if (pf.pf_rls[inx] != NULL)
	{
	  /* a rl cannot exist without belonging to a row, except if it belongs to a deleted row.  rls of deleted rows continue to exist as distinct until the wait queue is done so as to keep lock acquisition order.  Deviating from lock acquisition order makes fake deadlocks in cluster. */
	  if (ITC_AT_END != rlocks[inx]->rl_pos)
	    GPF_T1 ("unmoved non-deleted row lock");
	  PL_RL_ADD (buf->bd_pl, rlocks[inx], ITC_AT_END);
	  buf->bd_pl->pl_n_row_locks++;
	  log_info ("deleted rl kept around for page apply");
	}
    }
  if (pf.pf_left)
    {
      DO_SET (buffer_desc_t *, left2, &pf.pf_left->next)
	{
	  itc_split_lock_waits (pf.pf_itc, buf, left2);
	}
      END_DO_SET();
      itc_split_lock_waits (pf.pf_itc, buf, pf.pf_current);
    }
  if (t_buf->bd_registered) GPF_T1 ("registrations are not supposed to go to the temp buf");
  if (PA_REWRITE_ONLY == op)
    return;
  if (PA_AUTOCOMPACT == op
        || itc->itc_insert_key->key_is_geo
     )
    first_affected = 0;
  page_apply_parent (buf, &pf, first_affected, op, change, paf);
  dk_set_free (pf.pf_left);
  if (hold_taken)
    itc_free_hold (itc);
}


void
page_apply_s (it_cursor_t * itc, buffer_desc_t * buf, int n_delta, row_delta_t ** delta, int op)
{
#if defined (VALGRIND)
  page_apply_frame_t paf = {0};
#else
  page_apply_frame_t paf;
#endif
  page_apply_1 (itc, buf, n_delta, delta, op, &paf);
}


void
page_apply (it_cursor_t * itc, buffer_desc_t * buf, int n_delta, row_delta_t ** delta, int op)
{
  du_thread_t * self = THREAD_CURRENT_THREAD;
#ifdef DEBUG
  if (THR_IS_STACK_OVERFLOW (self, &self, PAGE_SZ + 1000 * sizeof (caddr_t)))
    GPF_T1 ("page_apply called with not enough stack");
#endif
  if (THR_IS_STACK_OVERFLOW (self, &self, sizeof (page_apply_frame_t) + PAGE_SZ + 1000 * sizeof (caddr_t)))
    {
      NEW_VAR (page_apply_frame_t, paf);
      page_apply_1 (itc, buf, n_delta, delta, op, paf);
      dk_free ((caddr_t)paf, sizeof (page_apply_frame_t));
    }
  else
    page_apply_s (itc, buf, n_delta, delta, op);
}


long tc_autocompact_split;


#define rdbg_printf_m(a)
#define pf_printf(a)

int
pf_pop_root (page_fill_t * pf)
{
  buffer_desc_t * leaf_buf;
  buffer_desc_t * buf = pf->pf_current;
  if (1 == buf->bd_content_map->pm_count)
    {
      db_buf_t row = BUF_ROW (buf, 0);
      key_ver_t kv = IE_KEY_VERSION (row);
      dp_addr_t leaf = LONG_REF (row + LD_LEAF);
      if (kv != KV_LEFT_DUMMY
	  && !pf->pf_itc->itc_insert_key->key_is_geo
	  )
	GPF_T1 ("single leaf root page with leaf other than left dummy is not expected");
      if (!leaf)
	return 0;
      itc_set_parent_link (pf->pf_itc, leaf, 0);
      rdbg_printf_m (("Single leaf root popped old root L=%ld new root L=%ld \n", (long)(buf->bd_page), (long)leaf));
      ITC_IN_KNOWN_MAP (pf->pf_itc, leaf);
      pf->pf_itc->itc_tree->it_root = leaf;
      page_wait_access (pf->pf_itc, leaf, NULL, &leaf_buf, PA_WRITE, RWG_WAIT_ANY);
      pg_delete_move_cursors (pf->pf_itc, buf, 0,
			      leaf_buf, 0);

      page_leave_outside_map (leaf_buf);
      ITC_IN_KNOWN_MAP (pf->pf_itc, buf->bd_page);
      pf_printf (("freeing L=%d pop root\n", buf->bd_page));
      pf->pf_itc->itc_ac_parent_deld = 1;
      it_free_page (pf->pf_itc->itc_tree, buf);
      ITC_LEAVE_MAPS (pf->pf_itc);
      return 1;
    }
  return 0;
}


void
page_apply_parent (buffer_desc_t * buf, page_fill_t * pf, char first_affected, char op, char change,
		   page_apply_frame_t * paf)
{
  /* called to modify parent when one or more of 1. first lp change, 2. split 3. page deleted */
  int inx;
  dp_addr_t dp_parent = LONG_REF (buf->bd_buffer + DP_PARENT);
  dp_addr_t first_lp = 0;
  char del_current = 0;
  row_delta_t ** leaves;
  pf->pf_itc->itc_app_stay_in_buf = ITC_APP_LEAVE;
  if (pf->pf_left && !dp_parent)
    first_affected = 2; /* in root split, make lp for left and right, otherwise for right only, unless leftmost of left changed */
  leaves = pf_rd_list (pf, first_affected, &first_lp, &del_current);
  if (!leaves)
    {
      if (PA_RELEASE_PL == op)
	pf_release_pl (pf);
      pg_check_map (buf);
      if (0 == LONG_REF (buf->bd_buffer + DP_PARENT)
	  && pf_pop_root (pf))
	return;
      if (PA_AUTOCOMPACT != op)
	{
	  /* if this is an update of parent in autocompact and there was no split, do not leave, let the caller go ahead with the page */
	  page_leave_outside_map_chg (buf, change);
	}
      return;
    }
  if (!dp_parent)
    {
      buffer_desc_t * root = it_new_page (pf->pf_itc->itc_tree, buf->bd_page, DPF_INDEX, 0, pf->pf_itc);
      if (1 == first_affected) GPF_T1 ("first affected on root not right, should be left dummy");
      if (del_current) GPF_T1 ("not supposed to del root page");
      leaves[0]->rd_op = RD_INSERT; /* the change of first lp is an update except when making new root */
      DO_BOX (row_delta_t *, leaf_rd, inx, leaves)
	{
	  leaf_rd->rd_map_pos = inx;
	}
      END_DO_BOX;
      it_root_image_invalidate (pf->pf_itc->itc_tree);
      ITC_IN_KNOWN_MAP (pf->pf_itc, root->bd_page);
      /* don't set it in the middle of the itc_reset sequence */
      pf->pf_itc->itc_tree->it_root = root->bd_page;
      rdbg_printf (("new root of %s L=%d \n", STR_OR (pf->pf_itc->itc_insert_key->key_name, "temp"), root->bd_page));
      ITC_LEAVE_MAP_NC (pf->pf_itc);
      pf->pf_itc->itc_page = root->bd_page;
      /* set the parent link of the new leaves under the parent.  Set this before recursive page apply because a large insert can make it so all the leaves do not fit on the root and there will be a second split.  This split will set parent links and these must not be altered thereafter */
      LONG_SET (pf->pf_current->bd_buffer + DP_PARENT, root->bd_page);
      DO_SET (buffer_desc_t *, leaf, &pf->pf_left)
	{
	  LONG_SET (leaf->bd_buffer + DP_PARENT, root->bd_page);
	  rdbg_printf (("Set parent of L=%d to new root L=%d\n", leaf->bd_page, root->bd_page));
	}
      END_DO_SET();
      page_apply_1  (pf->pf_itc, root, BOX_ELEMENTS (leaves), leaves, 0, paf);
      DO_SET (buffer_desc_t *, leaf, &pf->pf_left)
	{
	  rdbg_printf (("Set parent of L=%d to new root L=%d\n", leaf->bd_page, root->bd_page));
	  pg_check_map (leaf);
	  page_leave_outside_map_chg (leaf, RWG_WAIT_SPLIT);
	}
      END_DO_SET();
      rdbg_printf (("Set parent of L=%d to new root L=%d\n", pf->pf_current->bd_page, root->bd_page));
      pg_check_map (pf->pf_current);
      
      page_leave_outside_map_chg (pf->pf_current, RWG_WAIT_SPLIT);
      rd_list_free (leaves);
      return;
    }
  else
    {
      int ileaf;
      buffer_desc_t  * parent = itc_write_parent (pf->pf_itc, buf);
      dp_may_compact  (parent->bd_storage, parent->bd_page);
      ileaf = page_find_leaf (parent, first_lp);
      if (-1 == ileaf) GPF_T1 ("can't find leaf on parent in split/del;");
      if (!first_affected && pf->pf_left)
	ileaf++; /* if not first affected and split, ins new leaf to the right of the lp, not over the lp */
      DO_BOX (row_delta_t *, leaf_rd, inx, leaves)
	{
	  leaf_rd->rd_map_pos = ileaf + inx;
	}
      END_DO_BOX;
      if (!del_current && PA_RELEASE_PL == op)
	pf_release_pl (pf);
      DO_SET (buffer_desc_t *, leaf, &pf->pf_left)
	{
	  LONG_SET (leaf->bd_buffer + DP_PARENT, parent->bd_page);
	  pg_check_map (leaf);
	  page_leave_outside_map_chg (leaf, RWG_WAIT_SPLIT);
	}
      END_DO_SET();
      if (del_current)
	{
	  page_lock_t *pl = buf->bd_pl;
	  ITC_IN_TRANSIT (pf->pf_itc, buf->bd_page, parent->bd_page);
	  pg_delete_move_cursors (pf->pf_itc, buf, 0,
				  parent, leaves[0]->rd_map_pos);
	  pl_page_deleted (buf->bd_pl, buf);
	  ITC_LEAVE_MAPS (pf->pf_itc);
	  if (leaves && 1 == BOX_ELEMENTS (leaves) && RD_UPDATE == leaves[0]->rd_op)
	    {
	      /* A page with a single leaf ptr is deld and the single child must get its parent link set to the parent of the present page */
	      itc_set_parent_link (pf->pf_itc, leaves[0]->rd_leaf, parent->bd_page);
	    }
	  ITC_IN_KNOWN_MAP (pf->pf_itc, pf->pf_current->bd_page);
	  page_mark_change (buf, RWG_WAIT_SPLIT);
	  pf_printf (("freeing non-root  L=%d\n", pf->pf_current->bd_page));
	  pf->pf_itc->itc_ac_parent_deld = 1;
	  it_free_page (pf->pf_current->bd_tree, pf->pf_current);
	  ITC_LEAVE_MAP_NC (pf->pf_itc);
	  if (PA_RELEASE_PL == op  && pl)
	    pl_release (pl, pf->pf_itc->itc_ltrx, NULL);
	}
      else
	{
	  LONG_SET (pf->pf_current->bd_buffer + DP_PARENT, parent->bd_page);
	  pg_check_map (pf->pf_current);
	  page_leave_outside_map_chg (pf->pf_current, RWG_WAIT_SPLIT);
	}
      if (PA_AUTOCOMPACT == op)
	TC (tc_autocompact_split);
      pf->pf_itc->itc_page = parent->bd_page;
      page_apply_1 (pf->pf_itc, parent, BOX_ELEMENTS (leaves), leaves, PA_MODIFY, paf);
      rd_list_free (leaves);
    }
}



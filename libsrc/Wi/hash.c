/*
 *  hash.c
 *
 *  $Id$
 *
 *  Hash Index
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
#include "sqlopcod.h"
#include "sqlopcod.h"
#include "sqlpar.h"
#include "arith.h"
#include "sqlbif.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "list2.h"
#include "date.h"
#include "xmltree.h"

#if !defined (NEW_HASH) && !defined (USE_OLD_HASH)
#define USE_OLD_HASH
#endif

#if !defined (OLD_HASH) && defined (USE_OLD_HASH)
#undef USE_OLD_HASH
#endif

#ifdef OLD_HASH
#define HI_INIT_SIZE 509
#else
#define HI_INIT_SIZE 100000
#endif

#ifdef OLD_HASH
#define HI_PAGE_SIZE 4096
#define HE_PER_PAGE (HI_PAGE_SIZE / sizeof (hash_inx_elt_t))
#endif

#ifdef NEW_HASH
#define BKT_ELEM_SIZE (sizeof (dp_addr_t) + sizeof (short))
#define HE_BPTR_PER_PAGE (PAGE_DATA_SZ / BKT_ELEM_SIZE)
#endif

#ifdef OLD_HASH
#define HI_BUCKET(hi, code) \
  (&hi->hi_elements[(((uint32)code) % hi->hi_size) / HE_PER_PAGE][(((uint32)code) % hi->hi_size) % HE_PER_PAGE])
#define HI_EMPTY ((hash_inx_elt_t *)(ptrlong)-1)
#endif

#ifdef NEW_HASH
#define HI_BUCKET_PTR_PAGE(hi, code) \
  (hi->hi_buckets [(((uint32)code) % hi->hi_size) / HE_BPTR_PER_PAGE])
#endif
long hi_end_memcache_size = 100000;

#define set_dbg_fprintf(x)
#define retr_dbg_fprintf(x)

typedef struct hi_memcache_key_s {
  id_hashed_key_t hmk_hash;
  hash_area_t *hmk_ha;
  caddr_t *hmk_data;
  int hmk_var_len;
} hi_memcache_key_t;


id_hashed_key_t hi_memcache_hash (caddr_t p_data)
{
  id_hashed_key_t res = ((hi_memcache_key_t *)p_data)->hmk_hash;
  ID_HASHED_KEY_CHECK(res);
  return res;
}

int hi_memcache_cmp (caddr_t d1, caddr_t d2)
{
  hi_memcache_key_t *hmk1 = (hi_memcache_key_t *)d1;
  hi_memcache_key_t *hmk2 = (hi_memcache_key_t *)d2;
  int idx;
  if (hmk1->hmk_hash != hmk2->hmk_hash)
    return 0;
  DO_BOX_FAST (caddr_t, fld1, idx, hmk1->hmk_data)
    {
      collation_t *cl = hmk1->hmk_ha->ha_key_cols[idx].cl_sqt.sqt_collation;
      caddr_t fld2 = hmk2->hmk_data[idx];
      if (DVC_MATCH != cmp_boxes (fld1, fld2, cl, cl))
	{
	  if ((DV_DB_NULL == DV_TYPE_OF (fld1)) && (DV_DB_NULL == DV_TYPE_OF (fld2)))
	    continue;
	  return 0;
	}
    }
  END_DO_BOX_FAST;
  return 1;
}


#ifdef NEW_HASH
static void
HI_BUCKET_PTR (hash_index_t *hi, uint32 code, it_cursor_t *itc, hash_inx_b_ptr_t *hibp, int mode)
{
  dp_addr_t hi_bucket_page = HI_BUCKET_PTR_PAGE (hi, code);
  unsigned short ofs = (unsigned short) (((code % hi->hi_size) % HE_BPTR_PER_PAGE) * BKT_ELEM_SIZE);
  buffer_desc_t *hb_buf = NULL;
#if defined (NEW_HASH_NEED_ALIGN)
  int32 l_buf;
#endif

#if 0
  if (!hi_bucket_page)
    {
      hb_buf = isp_new_page (itc->itc_tree->it_commit_space, 0, DPF_HASH, 0, 0);
      if (!hb_buf)
	{
	  log_error ("Out of disk space for temp table");
	  itc->itc_ltrx->lt_error = LTE_NO_DISK;
	  itc_bust_this_trx (itc, hb_buf);
	}
      HI_BUCKET_PTR_PAGE (hi, code) = hb_buf->bd_page;
    }
#else
  if (!hi_bucket_page)
    {
      hibp->hibp_page = 0;
      hibp->hibp_pos = 0;
      return;
    }
#endif
  else
    {
      itc->itc_page = hi_bucket_page;
      ITC_IN_MAP (itc);
      page_wait_access (itc, hi_bucket_page, NULL, NULL, &hb_buf, PA_READ, RWG_WAIT_ANY);
    }
#if !defined (NEW_HASH_NEED_ALIGN)
  hibp->hibp_page = LONG_REF (hb_buf->bd_buffer + DP_DATA + ofs);
#else
  memcpy (&l_buf, hb_buf->bd_buffer + DP_DATA + ofs, sizeof (int32));
  hibp->hibp_page = LONG_REF (&l_buf);
#endif
  hibp->hibp_pos = SHORT_REF (hb_buf->bd_buffer + DP_DATA + ofs + sizeof (dp_addr_t));

  page_leave_inner (hb_buf);
  ITC_LEAVE_MAP (itc);
}
#endif


static void
hi_alloc_elements (hash_index_t *hi)
{
#ifdef NEW_HASH
  int he_inx;
#endif
#ifdef OLD_HASH
  int inx;
#endif

#ifdef OLD_HASH
  inx = ((hi->hi_size / HE_PER_PAGE) + 1);
  hi->hi_elements = (hash_inx_elt_t**)
    dk_alloc_box (inx * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  while (inx--)
    {
      hash_inx_elt_t *page = (hash_inx_elt_t *) dk_alloc_box (HI_PAGE_SIZE, DV_CUSTOM);
      memset (page, 0xff, HI_PAGE_SIZE);
      hi->hi_elements [inx] = page;
    }
#endif
#ifdef NEW_HASH
  he_inx = (hi->hi_size / HE_BPTR_PER_PAGE) + 1;
  hi->hi_buckets = (dp_addr_t *)
      dk_alloc_box (he_inx * sizeof (dp_addr_t), DV_CUSTOM);
  memset (hi->hi_buckets, 0, he_inx * sizeof (dp_addr_t));
  hi->hi_source_pages = hash_table_allocate (201);
#endif
}


static hash_index_t *
hi_allocate (int sz, int use_memcache)
{
  NEW_VARZ (hash_index_t, hi);
  if (!sz)
    sz = HI_INIT_SIZE;
  hi->hi_size = sz;
  if (use_memcache)
    {
      hi->hi_memcache = id_hash_allocate ( (sz > HI_INIT_SIZE) ? HI_INIT_SIZE : sz,
	  sizeof (hi_memcache_key_t), sizeof (caddr_t *), hi_memcache_hash, hi_memcache_cmp);
      id_hash_set_rehash_pct (hi->hi_memcache, 120);
    }
  else
    hi_alloc_elements (hi);
  return hi;
}


void
hi_free (hash_index_t * hi)
{
  if (hi->hi_memcache)
    {
      hi_memcache_key_t *key;
      caddr_t **val;
      id_hash_iterator_t hit;
      id_hash_iterator (&hit, hi->hi_memcache);
      while (hit_next (&hit, (caddr_t *)(&key), (caddr_t *)(&val)))
	{
	  dk_free_tree ((caddr_t)(key->hmk_data));
	  dk_free_tree ((box_t) val[0]);
	}
      id_hash_clear (hi->hi_memcache);
      id_hash_free (hi->hi_memcache);
    }
  DO_SET (caddr_t, elt, &hi->hi_pages)
    {
      dk_free_box ((caddr_t) elt);
    }
  END_DO_SET();
  dk_set_free (hi->hi_pages);
#ifdef OLD_HASH
  dk_free_tree ((caddr_t) hi->hi_elements);
#endif
#ifdef NEW_HASH
  dk_free_box ((box_t) hi->hi_buckets);
  if (hi->hi_source_pages)
    hash_table_free (hi->hi_source_pages);
#endif
  dk_free ((caddr_t) hi, sizeof (hash_index_t));
}


#ifdef OLD_HASH
void hi_add (hash_index_t * hi, uint32 code, dp_addr_t dp, int pos);
#endif

#if 0
int
hi_find (hash_index_t * hi, uint32 no, dp_addr_t page, int pos)
{
  hash_inx_elt_t * he = HI_BUCKET (hi, no);
  if (HI_EMPTY != he->he_next)
    {
      while (he)
	{
	  if (he->he_no == no && he->he_page == page && he->he_pos == pos)
	    return 0;
	  he = he->he_next;
	}
    }
  GPF_T;
  return 0;
}
#endif

#ifdef OLD_HASH
static void
hi_rehash (hash_index_t * hi)
{
  hash_index_t * hi2;
  int inx, hinx;
  int new_sz = hash_nextprime (hi->hi_size * 4);
  if (new_sz == hi->hi_size)
    return;
  hi2 = hi_allocate (new_sz, 0 /* When in rehash, memcache is already dead */);
  DO_BOX (hash_inx_elt_t *, he, inx, hi->hi_elements)
    {
      for (hinx = 0; hinx < HE_PER_PAGE; hinx++)
	{
	  hash_inx_elt_t * he2 = &he[hinx];
	  if (HI_EMPTY != he2->he_next)
	    {
	      do {
		hi_add (hi2, he2->he_no, he2->he_page, he2->he_pos);
		he2 = he2->he_next;
	      } while (he2);

	    }
	}
      dk_free_box ((caddr_t) he);
      hi->hi_elements[inx] = NULL;
    }
  END_DO_BOX;
  dk_free_tree ((caddr_t) hi->hi_elements);
  hi->hi_size = hi2->hi_size;
  hi->hi_elements = hi2->hi_elements;
  DO_SET (caddr_t, pg, &hi->hi_pages)
    {
      dk_free_box (pg);
    }
  END_DO_SET();
  dk_set_free (hi->hi_pages);
  hi->hi_pages = hi2->hi_pages;
  hi->hi_page_fill = hi2->hi_page_fill;
  dk_free ((caddr_t) hi2, sizeof (hash_index_t));
}


void
hi_add (hash_index_t * hi, uint32 code, dp_addr_t dp, int pos)
{
  hash_inx_elt_t * he;
  if (hi->hi_count > 4 * hi->hi_size)
    hi_rehash (hi);
  hi->hi_count++;
  he = HI_BUCKET (hi, code);
  if (HI_EMPTY == he->he_next)
    {
      he->he_no = code;
      he->he_next = 0;
      he->he_page = dp;
      he->he_pos = pos;
      set_dbg_fprintf ((stdout, "hi_add:1 in bu: page=%lu next=%p pos=%lu, no=%lu\n",
	  (unsigned long) he->he_page, he->he_next, (unsigned long) he->he_pos, (unsigned long) he->he_no));
      return;
    }
  {
    hash_inx_elt_t * new_he;
    if (!hi->hi_pages
	|| hi->hi_page_fill >= HI_PAGE_SIZE - sizeof (hash_inx_elt_t))
      {
	new_he = (hash_inx_elt_t*) dk_alloc_box (HI_PAGE_SIZE, DV_CUSTOM);
	dk_set_push (&hi->hi_pages, (void*)new_he);
	hi->hi_page_fill = sizeof (hash_inx_elt_t);
      }
    else
      {
	new_he = (hash_inx_elt_t*) (((char*)hi->hi_pages->data) + hi->hi_page_fill);
	hi->hi_page_fill += sizeof (hash_inx_elt_t);
      }
    new_he->he_next = he->he_next;
    he->he_next = new_he;
    new_he->he_no = code;
    new_he->he_page = dp;
    new_he->he_pos = pos;
    set_dbg_fprintf ((stdout, "hi_add:befo bu: page=%lu next=%p pos=%lu, no=%lu before page=%lu next=%p pos=%lu, no=%lu\n",
	(unsigned long) new_he->he_page, new_he->he_next, (unsigned long) new_he->he_pos, (unsigned long) new_he->he_no,
	(unsigned long) new_he->he_next->he_page, new_he->he_next->he_next, (unsigned long) new_he->he_next->he_pos, (unsigned long) new_he->he_next->he_no
	));
  }
}
#endif

#ifdef NEW_HASH
static void
hi_bp_set (hash_index_t * hi, it_cursor_t *itc, uint32 code, dp_addr_t dp, short pos)
{
  dp_addr_t hi_bucket_page = HI_BUCKET_PTR_PAGE (hi, code);
  unsigned short ofs = (unsigned short) (((code % hi->hi_size) % HE_BPTR_PER_PAGE) * BKT_ELEM_SIZE);
  buffer_desc_t *hb_buf;
  int in_map = 0;
#if defined (NEW_HASH_NEED_ALIGN)
  int32 l_buf;
#endif

  hi->hi_count++;
  if (!hi_bucket_page)
    {
      hb_buf = isp_new_page (itc->itc_tree->it_commit_space, 0, DPF_HASH, 0, 0);
      if (!hb_buf)
	{
	  log_error ("Out of disk space for temp table");
	  itc->itc_ltrx->lt_error = LTE_NO_DISK;
	  itc_bust_this_trx (itc, &hb_buf, ITC_BUST_THROW);
	}
      HI_BUCKET_PTR_PAGE (hi, code) = hb_buf->bd_page;
      memset (hb_buf->bd_buffer + DP_DATA, 0, PAGE_DATA_SZ);
      set_dbg_fprintf ((stdout, "hi_bp_set:new bp: page=%lu\n", (unsigned long) hb_buf->bd_page));
    }
  else
    {
      ITC_IN_MAP (itc);
      page_wait_access (itc, hi_bucket_page, NULL, NULL, &hb_buf, PA_WRITE, RWG_WAIT_ANY);
      set_dbg_fprintf ((stdout, "hi_bp_set:old bp: page=%lu\n", (unsigned long) hb_buf->bd_page));
      ITC_IN_MAP (itc);
      in_map = 1;
    }

  set_dbg_fprintf ((stdout, "hi_bp_set:set : page=%lu @ ofs=%lu\n", (unsigned long) dp, (unsigned long) ofs));
#if !defined (NEW_HASH_NEED_ALIGN)
  LONG_SET (hb_buf->bd_buffer + DP_DATA + ofs, dp);
#else
  LONG_SET (&l_buf, dp);
  memcpy (hb_buf->bd_buffer + DP_DATA + ofs, &l_buf, sizeof (int32));
#endif
  SHORT_SET (hb_buf->bd_buffer + DP_DATA + ofs + sizeof (dp_addr_t), pos);
  hb_buf->bd_is_dirty = 1;

  if (in_map)
    {
      page_leave_inner (hb_buf);
      ITC_LEAVE_MAP (itc);
    }
  else
    itc_page_leave (itc, hb_buf);
}
#endif

/* Attention! The value produced by this function may be invalid hash for
use as a hash value for search in id_hash_t: it can be more than 31-bit. */
uint32
key_hash_utf8 (caddr_t _utf8, long _n, uint32 code, collation_t * collation)
{
  long inx1, inx2;
  wchar_t wtmp1;
  virt_mbstate_t state1;
  long rc1;
  memset (&state1, 0, sizeof (virt_mbstate_t));
  inx1 = inx2 = 0;
  while(1)
    {
      uint32 b;
      if (inx1 == _n)
	return code;
      rc1 = (long) virt_mbrtowc (&wtmp1, (unsigned char *) (_utf8 + inx1), _n - inx1, &state1);
      if (rc1 <= 0)
	GPF_T1 ("inconsistent wide char data");
      if (collation)
	b =((wchar_t *)collation->co_table)[wtmp1];
      else
	b = wtmp1;
      code = (code * (b + 3 + inx2)) ^ (code >> 24);
      inx2++;
      inx1 += rc1;
    }
  return code;
}


/* Attention! The value produced by this function may be invalid hash for
use as a hash value for search in id_hash_t: it can be more than 31-bit. */
uint32
key_hash_wide (caddr_t _wide, long * _len, uint32 code, collation_t * collation)
{
  long inx1, _n;

  _len[0] = (long) wide_as_utf8_len (_wide);

  _n = box_length (_wide) / sizeof (wchar_t) - 1;

  for (inx1 = 0; inx1 < _n ;inx1++)
    {
      uint32 b;
      if (collation)
	b = ((wchar_t*)collation->co_table)[((wchar_t*)_wide)[inx1]];
      else
	b = ((wchar_t*)_wide)[inx1];
      code = (code * (b + 3 + inx1)) ^ (code >> 24);
    }
  return code;
}


/* Attention! The value produced by this function may be invalid hash for
use as a hash value for search in id_hash_t: it can be more than 31-bit. */
uint32
key_hash_col (db_buf_t row, dbe_key_t * key, dbe_col_loc_t * cl, uint32 code, int * var_len)
{
  db_buf_t row_data = row + IE_FIRST_KEY;
  int off, len;
  KEY_COL (key, row_data, cl[0], off, len);
  if (cl->cl_fixed_len < 0)
    *var_len += len;
  if (cl->cl_sqt.sqt_dtp == DV_LONG_INT)
    {
      int32 v = LONG_REF (row_data + off);
      if (v)
	code = (code * v) ^ (code >> 23);
      else
	code = code << 2 | code >> 30;
    }
  else if (cl->cl_sqt.sqt_dtp == DV_SHORT_INT)
    {
      int32 v = SHORT_REF (row_data + off);
      if (v)
	code = (code * v) ^ (code >> 23);
      else
	code = code << 2 | code >> 30;
    }
  else
    {
      int inx;
      collation_t * collation = cl->cl_sqt.sqt_collation;
      if (IS_WIDE_STRING_DTP (cl->cl_sqt.sqt_dtp))
	{ /* wide is stored in utf8 */
	  return key_hash_utf8 ((caddr_t) (row_data+off), len, code, collation);
	}
      for (inx = 0; inx < len; inx++)
	{
	  uint32 b;
	  if (collation)
	    b = collation->co_table[row_data[off+inx]];
	  else
	    b = row_data[off + inx];
	  code = (code * (b + 3 + inx)) ^ (code >> 24);
	}
    }
  return code;
}


#define IS_INT_DTP(dtp) \
  (DV_LONG_INT == dtp || DV_SHORT_INT == dtp)

#define CL_INT(cl, row) \
  (DV_SHORT_INT == cl.cl_sqt.sqt_dtp ? (int32) *(short*)(row + cl.cl_pos) \
    : *(int32*)(row + cl.cl_pos))

#define BOX_CMP_LEN(box, dtp, len) \
  switch (dtp) \
    { \
    case DV_DB_NULL: \
      len = 0; \
      break; \
    case DV_DOUBLE_FLOAT: \
    case DV_SINGLE_FLOAT: \
    case DV_BIN: \
    case DV_DATETIME: \
      len = box_length (box); \
      break; \
    case DV_LONG_INT: \
      len = (uint32) sizeof (int32); \
			      break; \
    case DV_STRING: \
      len = box_length (box) - 1; \
				    break; \
    case DV_WIDE: \
    case DV_LONG_WIDE: \
      len = (uint32) wide_as_utf8_len(box); \
      break; \
    case DV_BLOB_HANDLE: case DV_BLOB_WIDE_HANDLE: case DV_BLOB_XPER_HANDLE: \
      len = DV_BLOB_LEN; \
      break; \
    default: \
      len = box_length (box); \
    }


/* Attention! The value produced by this function may be invalid hash for
use in id_hash_t. */
uint32
key_hash_box (caddr_t box, dtp_t dtp, uint32 code, int * var_len, collation_t * collation, dtp_t col_dtp)
{
  int inx2;
  long len;
  if (col_dtp == DV_ANY)
    { /* if it goes to column of type ANY the length to be written is the serialized length */
      caddr_t err = NULL;
      caddr_t any_ser;
      uint32 ret;

      any_ser = box_to_any (box, &err);
      if (err)
	sqlr_resignal (err);
      if (DV_TYPE_OF (any_ser) != DV_STRING)
	GPF_T1 ("any disk image not a string");

      ret = key_hash_box (any_ser, DV_STRING, code, var_len, collation, DV_STRING);
      dk_free_tree (any_ser);
      return ret;
    }
  switch (dtp)
    {
    case DV_DB_NULL:
      return code;
    case DV_BIN:
      len = box_length (box);
      *var_len += len;
      break;
    case DV_DATETIME:
#if 1
      len = DT_COMPARE_LENGTH;
#else
      len = box_length (box);
#endif
      break;
    case DV_DOUBLE_FLOAT:
    case DV_IRI_ID: /* same size, meaning does not matter */
      {
	uint32* flt = (uint32*) box;
	if (flt[1])
	  code = (code * flt[1]) ^ (code >> 23);
	else
	  code = code << 2 | code >> 30;
      } /* fall to next case */
    case DV_SINGLE_FLOAT:
      {
	uint32* flt = (uint32*) box;
	if (flt[0])
	  code = (code * flt[0]) ^ (code >> 23);
	else
	  code = code << 2 | code >> 30;
      }
      return code;
    case DV_LONG_INT:
      {
	int32 v = (int32) unbox (box);
	if (v)
	  code = (code * v) ^ (code >> 23);
	else
	  code = code << 2 | code >> 30;
      }
      return code;
    case DV_STRING:
      len = box_length (box) - 1;
      *var_len += len;
      break;
    case DV_WIDE:
    case DV_LONG_WIDE:
      {
	uint32 ret_code = key_hash_wide (box, &len, code, collation);
      *var_len += len;
	return ret_code;
      }
    case DV_ARRAY_OF_POINTER:
      {
	int inx;
	caddr_t * arr = (caddr_t*) box;
	DO_BOX (caddr_t, x, inx, arr)
	  {
	    int d;
	    code = key_hash_box (x, DV_TYPE_OF (x), code, &d, collation, DV_TYPE_OF (x));
	  }
	END_DO_BOX;
	return code;
      }

    case DV_NUMERIC:
      return (((code << 10) | code >> 22) ^ numeric_hash ((numeric_t) box));
    default:
      sqlr_new_error ("22023", "SR445", "Value type (%s) not suitable for use in a hash index",
	  dv_type_title (dtp));
      len = box_length (box);
      *var_len += len;
    }
  if (collation)
    {
      for (inx2 = 0; inx2 < len; inx2++)
	{
	  uint32 c = (uint32)collation->co_table[(unsigned int) box[inx2]];
	  code = (code * (c + 3 + inx2)) ^ (code >> 24);
	}
    }
  for (inx2 = 0; inx2 < len; inx2++)
    {
      uint32 b = box[inx2];
      code = (code * (b + 3 + inx2)) ^ (code >> 24);
    }
  return code;
}


caddr_t
hash_cast (query_instance_t * qi, hash_area_t * ha, int inx, state_slot_t * ssl, caddr_t data)
{
  caddr_t err = NULL;
  caddr_t * qst = (caddr_t *) qi;
  sql_type_t * sqt = &ha->ha_key_cols[inx].cl_sqt;
  dtp_t dtp = DV_TYPE_OF (data);
  dtp_t target_dtp = sqt->sqt_dtp;
  if (DV_DB_NULL == dtp
      || IS_BLOB_HANDLE_DTP (dtp)
      || DV_ANY == target_dtp
      || sqt->sqt_is_xml)
    return data;
  if (SSL_CONSTANT == ssl->ssl_type)
    GPF_T1 ("constant ssl in hash_cast");
  if (IS_BLOB_DTP (target_dtp))
    target_dtp = DV_BLOB_INLINE_DTP (target_dtp);  /* non blob value for blob col. Will be inlined */
  data = box_cast_to (qst, data, dtp,
		      target_dtp, sqt->sqt_precision, sqt->sqt_scale, &err);
  if (err)
    sqlr_resignal (err);
  qst_set (qst, ssl, data);
  return data;
}


static void
itc_ha_disk_row (it_cursor_t * itc, buffer_desc_t * buf, hash_area_t * ha, caddr_t * qst, index_tree_t * tree,
	    int var_len, uint32 code, unsigned long feed_temp_blobs, caddr_t *hmk_data, caddr_t  *hm_val
#ifdef NEW_HASH
	    ,hash_inx_b_ptr_t *hibp
#else
	    ,void *_hibp
#endif
	    )
{
  caddr_t err = NULL;
  db_buf_t hash_row;
  dbe_key_t * key = ha->ha_key;
  volatile int v_fill = key->key_row_var_start;
  int row_len, key_len;
  int inx;
  int hmk_data_els = ((NULL != hmk_data) ? BOX_ELEMENTS (hmk_data) : 0);
  short hb_fill = itc->itc_hash_buf_fill;
  short hb_prev = itc->itc_hash_buf_prev;
  buffer_desc_t * hash_buf = itc->itc_hash_buf;
#ifdef NEW_HASH
  query_instance_t *qi = (query_instance_t *)qst;
  it_cursor_t * bp_ref_itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_bp_ref_itc);
  unsigned short code_mask;
  hash_inx_b_ptr_t hibp_buf;

  if (!bp_ref_itc)
    {
      index_tree_t * ha_tree = (index_tree_t *) QST_GET_V (qst, ha->ha_tree);
      bp_ref_itc = itc_create (NULL, qi->qi_trx);
      itc_from_it (bp_ref_itc, ha_tree);
      qst_set (qst, ha->ha_bp_ref_itc, (caddr_t) bp_ref_itc);
    }
  if (!hibp)
    {
      HI_BUCKET_PTR (tree->it_hi, code, bp_ref_itc, &hibp_buf, PA_WRITE);
      hibp = &hibp_buf;
    }
#endif

#ifdef _NOT
  FAILCK (itc);
#endif
  key_len = key->key_row_len;
  if (key_len > 0)
    row_len = key_len;
  else
    {
      int var_len_org = var_len;
    try_with_blobs_outlined:

      for (inx = ha->ha_n_keys; ha->ha_key_cols[inx].cl_col_id; inx++)
	{
	  int len;
	  dbe_col_loc_t * cl = &ha->ha_key_cols[inx];
	  state_slot_t * ssl;
	  caddr_t value;
	  dtp_t dtp, target_dtp;
	  if (cl->cl_fixed_len > 0)
	    continue;
	  ssl = ha->ha_slots[inx];
	  target_dtp = cl->cl_sqt.sqt_dtp;
	  if (IS_BLOB_DTP (target_dtp))
	    target_dtp = DV_BLOB_INLINE_DTP (target_dtp);  /* non blob value for blob col. Will be inlined */
	  if (NULL != hmk_data)
	    {
	      caddr_t *value_ptr = ((inx < hmk_data_els) ? hmk_data+inx : hm_val+(inx-hmk_data_els));
	      value = value_ptr[0];
	      qst_set (qst, ssl, box_copy_tree (value));
	      dtp = DV_TYPE_OF (value);
	      if (dtp != target_dtp)
		{
		  value = hash_cast ((query_instance_t *) qst, ha, inx, ssl, QST_GET (qst, ssl));
	          dtp = DV_TYPE_OF (value);
		  /*dk_free_tree (value_ptr[0]);
		  value_ptr[0] = box_copy_tree (value);*/
		}
	    }
	  else
	    {
	      value = QST_GET (qst, ssl);
	      dtp = DV_TYPE_OF (value);
	      if (dtp != target_dtp)
		{
		  value = hash_cast ((query_instance_t *) qst, ha, inx, ssl, value);
	          dtp = DV_TYPE_OF (value);
		}
	    }
	  if (feed_temp_blobs && IS_BLOB_DTP (cl->cl_sqt.sqt_dtp) && !cl->cl_sqt.sqt_is_xml
	      && ! IS_BLOB_HANDLE_DTP (dtp))
	    dtp = DV_BLOB_HANDLE_DTP_FOR_BLOB_DTP (DV_BLOB_DTP_FOR_INLINE_DTP (dtp));

	  if (dtp != DV_DB_NULL &&
	      (cl->cl_sqt.sqt_dtp == DV_ANY ||
	       cl->cl_sqt.sqt_dtp == DV_OBJECT))
	    {
	      caddr_t err = NULL;
	      caddr_t serialized_value = box_to_any (value, &err);
	      if (err != NULL)
		{
		  dk_free_tree (err);
		  BOX_CMP_LEN (value, dtp, len);
		}
	      else
		{
		  BOX_CMP_LEN (serialized_value, DV_STRING, len);
		  dk_free_tree (serialized_value);
		}
	    }
	  else if (cl->cl_sqt.sqt_is_xml && XE_IS_VALID_VALUE_FOR_XML_COL (value))
	    { /* XML entities are outlined */
	      len = DV_BLOB_LEN;
	    }
	  else
	    {
	      BOX_CMP_LEN (value, dtp, len);
	    }
	  if (IS_BLOB_DTP (cl->cl_sqt.sqt_dtp) && !cl->cl_sqt.sqt_is_xml
	      && ! IS_BLOB_HANDLE_DTP (dtp))
	    len++; /* non-blob for a blob col is 1 longer because of the inlined leading tag byte */

	  var_len += len;
	}
      row_len = IE_FIRST_KEY + key->key_row_var_start + var_len;
      if (!feed_temp_blobs && row_len > MAX_ROW_BYTES)
	{
	  var_len = var_len_org;
	  feed_temp_blobs = 1;
	  goto try_with_blobs_outlined;
	}
    }
  row_len = ROW_ALIGN (row_len);
  if (qi->qi_no_cast_error && HA_DISTINCT == ha->ha_op && row_len > MAX_ROW_BYTES)
    return; /* if it is too long, it is considered distinct and not remembered */
  if (!hash_buf
#ifdef OLD_HASH
      || hb_fill + row_len > PAGE_SZ
#endif
#ifdef NEW_HASH
      || hb_fill + row_len + sizeof (dp_addr_t) > PAGE_SZ
#endif
      )
    {
      buffer_desc_t * new_buf = isp_new_page (tree->it_commit_space, 0, DPF_HASH, 0, 0);
      if (!new_buf)
	{
	  log_error ("Out of disk space for temp table");
	  itc->itc_ltrx->lt_error = LTE_NO_DISK;
	  itc_bust_this_trx (itc, &buf, ITC_BUST_THROW);
	}
      if (!tree->it_hash_first)
	tree->it_hash_first = new_buf->bd_page;
      if (hash_buf)
	{
	  LONG_SET (hash_buf->bd_buffer + DP_OVERFLOW, new_buf->bd_page);
	  IN_PAGE_MAP (tree);
	  page_leave_inner (hash_buf);
	  LEAVE_PAGE_MAP (tree);
	}
      hash_buf = new_buf;
      itc->itc_hash_buf = new_buf;
      hb_fill = DP_DATA;
    }
#ifdef NEW_HASH
  if (DP_DATA == hb_fill)
    SHORT_SET (hash_buf->bd_buffer + DP_FIRST, hb_fill + sizeof (dp_addr_t));
  else
    SHORT_SET (hash_buf->bd_buffer + hb_prev + IE_NEXT_IE, hb_fill + sizeof (dp_addr_t));

  LONG_SET (hash_buf->bd_buffer + hb_fill, hibp->hibp_page);
  hb_fill += sizeof (dp_addr_t);
#endif
#ifdef OLD_HASH
  if (DP_DATA == hb_fill)
    SHORT_SET (hash_buf->bd_buffer + DP_FIRST, hb_fill);
  else
    SHORT_SET (hash_buf->bd_buffer + hb_prev + IE_NEXT_IE, hb_fill);
#endif

  itc->itc_hash_buf_prev = hb_fill;
  hash_row = hash_buf->bd_buffer + hb_fill;

  SHORT_SET (hash_row + IE_NEXT_IE, 0);
#ifdef OLD_HASH
  SHORT_SET (hash_row + IE_KEY_ID, -1);
#endif

#ifdef NEW_HASH
  set_dbg_fprintf ((stdout, "itc_ha_disk_row: code %lu next of page=%lu/ofs=%lu is at page=%lu/ofs=%lu code=%lu\n",
      (unsigned long) code,
      (unsigned long) hash_buf->bd_page,
      (unsigned long) hb_fill,
      (unsigned long) hibp->hibp_page,
      (unsigned long) hibp->hibp_pos,
      hibp->hibp_no));
  code_mask = (unsigned short) ((code >> 9) & 0x7);
  code_mask = code_mask << 13;
  SHORT_SET (hash_row + IE_KEY_ID, ((hibp->hibp_pos & 0x1FFF) | code_mask));

  hi_bp_set (tree->it_hi, bp_ref_itc, code, hash_buf->bd_page, hb_fill);
#endif

  hash_row += IE_FIRST_KEY;
  itc_free_owned_params (itc);
  ITC_START_SEARCH_PARS (itc);
  for (inx = 0; ha->ha_key_cols[inx].cl_col_id; inx++)
    {
      state_slot_t * ssl  = ha->ha_slots[inx];
      caddr_t value;
      if (NULL == ssl)
	{
	  int off, len;
	  ITC_COL (itc, ha->ha_cols[inx], off, len);
	  upd_col_copy (ha->ha_key, &ha->ha_key_cols[inx], hash_row, &v_fill, ROW_MAX_DATA,
			&ha->ha_cols[inx], itc->itc_row_data, off, len);
	  goto check_err;
	}
      if (NULL != hmk_data)
	value = ((inx < hmk_data_els) ? hmk_data[inx]: hm_val[inx-hmk_data_els]);
      else
	value = QST_GET (qst, ssl);
/*save_value:*/
      if (feed_temp_blobs)
	row_set_col (hash_row, &ha->ha_key_cols[inx],
	  value, &v_fill, ROW_MAX_DATA,
	  tree->it_key, &err, itc, NULL, qst);
      else
	row_set_col_temp (hash_row, &ha->ha_key_cols[inx],
	  value, &v_fill, ROW_MAX_DATA,
	  tree->it_key, &err, itc, NULL, qst);
check_err:
      if (err)
	sqlr_resignal (err);
    }
  if (row_len - IE_FIRST_KEY != ROW_ALIGN (v_fill))
    {
#if 1 /* debug dump of the values */     
      FILE *dfile = fopen ("hvars_dump.txt", "w");
      if (dfile)
	{
	  fprintf (dfile, "=== variables dump ===\n");
	  for (inx = 0; ha->ha_key_cols[inx].cl_col_id; inx++)
	    {
	      state_slot_t * ssl  = ha->ha_slots[inx];
	      caddr_t value;
	      if (ssl && NULL == hmk_data)
		{
		  value = QST_GET (qst, ssl);
		  fprintf (dfile, "inx=%d\n", inx);
		  dbg_print_box (value, dfile);
		  fprintf (dfile, "\n");
		}
	      else
		{
		  fprintf (dfile, "inx=%d, ssl==NULL or hmk_data != NULL\n", inx);
		}
	    }
	  fprintf (dfile, "=== end dump ===\n");
	  fflush (dfile);
	  fclose (dfile);
	}
#endif      
      log_error ("Incorrect row length in hash space fill : row_len=%d, v_fill=%d", row_len, v_fill);
    GPF_T1 ("Incorrect row length calculation in hash space fill");
    }
#ifdef OLD_HASH
  hi_add (tree->it_hi, code, hash_buf->bd_page, hb_fill);
#endif
  itc->itc_hash_buf_fill = hb_fill + row_len;
}


int
itc_ha_equal (it_cursor_t * itc, hash_area_t * ha, caddr_t * qst, db_buf_t hash_row)
{
  int r_is_null, b_len = 0;
  int inx;
  hash_row += IE_FIRST_KEY;
  for (inx = 0; inx < ha->ha_n_keys; inx++)
    {
      int h_off, h_len, h_is_null;
      dbe_col_loc_t * h_cl = &ha->ha_key_cols[inx];
      KEY_COL (ha->ha_key, hash_row, (*h_cl), h_off, h_len);
      h_is_null = h_cl->cl_null_mask &&
	(0 != (h_cl->cl_null_mask & hash_row[h_cl->cl_null_flag]));
      if (ha->ha_slots[inx])
	{
	  state_slot_t * ssl = ha->ha_slots[inx];
	  caddr_t value = QST_GET (qst, ssl);
	  dtp_t v_dtp = DV_TYPE_OF (value);
	  BOX_CMP_LEN (value, v_dtp, b_len);
	  if (DV_DB_NULL == v_dtp)
	    {
	      if (h_is_null)
		continue; /* null equals null here */
	      else
		return DVC_LESS;
	    }
	  if (h_is_null)
	    return DVC_LESS;
	  if (h_cl->cl_sqt.sqt_dtp == DV_ANY)
	    {
	      caddr_t err = NULL;
	      caddr_t any_val;
	      int ret;
	      any_val = box_to_any (value, &err);
	      if (err)
		{
		  dk_free_tree (err);
		  return DVC_LESS;
		}
	      BOX_CMP_LEN (any_val, DV_STRING, b_len);
	      ret = ((b_len != h_len) || 0 != memcmp (any_val, hash_row + h_off, h_len)) ?
		  1 : 0;
	      dk_free_tree (any_val);
	      if (ret)
		return DVC_LESS;
	      continue;
	    }
	  if (v_dtp == DV_LONG_INT)
	    {
	      if (!IS_INT_DTP (h_cl->cl_sqt.sqt_dtp))
		return 0;
	      if (unbox (value) == CL_INT ((*h_cl), hash_row))
		continue;
	      return 0;
	    }
	  if (v_dtp == DV_IRI_ID)
	    {
	      if (DV_IRI_ID == h_cl->cl_sqt.sqt_dtp)
		{
		  if (unbox_iri_id (value) == (iri_id_t)(unsigned long) LONG_REF(hash_row + h_off))
		    continue;
		  return 0;
		}
	      else if (DV_IRI_ID_8 == h_cl->cl_sqt.sqt_dtp)
		{
		  if (unbox_iri_id (value) == (iri_id_t)INT64_REF(hash_row + h_off))
		    continue;
		  return 0;
		}
	      return 0;
	    }
	  if (IS_WIDE_STRING_DTP(v_dtp))
	    {
	      if (DVC_MATCH == compare_wide_to_utf8 ((caddr_t) (hash_row + h_off),
		    h_len, value, box_length(value) - sizeof (wchar_t),
		    ssl->ssl_sqt.sqt_collation))
		continue;
	      return DVC_LESS;
	    }
	  if (DV_NUMERIC == v_dtp)
	    {
	      NUMERIC_VAR (n2);
	      numeric_from_buf ((numeric_t) &n2, hash_row + h_off);
	      if (0 != numeric_compare ((numeric_t) value, (numeric_t) &n2))
		return DVC_LESS;
	      continue;
	    }
	  if (v_dtp == DV_SINGLE_FLOAT)
	    {
	      float flt;
	      EXT_TO_FLOAT (&flt, hash_row + h_off);
	      if (DVC_MATCH != cmp_double (flt, unbox_float(value), FLT_EPSILON))
		return DVC_LESS;
	      continue;
	    }
	  if (v_dtp == DV_DOUBLE_FLOAT)
	    {
	      double dbl;
	      EXT_TO_DOUBLE (&dbl, hash_row + h_off);
	      if (DVC_MATCH != cmp_double (dbl, unbox_double(value), DBL_EPSILON))
		return DVC_LESS;
	      continue;
	    }
#if 1
	  if (v_dtp == DV_DATETIME)
	    {
	      if (b_len != h_len)
		return DVC_LESS;
	      h_len = DT_COMPARE_LENGTH;
	      if (0 != memcmp (value, hash_row + h_off, h_len))
		return DVC_LESS;
	      continue;
	    }
#endif
	  if ((b_len != h_len) || 0 != memcmp (value, hash_row + h_off, h_len))
	    return DVC_LESS;
	  continue;
	}
      else
	{
	  int r_off, r_len;
	  dbe_col_loc_t * r_cl = &ha->ha_cols[inx];
	  r_is_null = itc->itc_row_data[r_cl->cl_null_flag] & r_cl->cl_null_mask;
	  if (r_is_null && h_is_null)
	    continue;
	  if (r_is_null || h_is_null)
	    return DVC_LESS;
	  ITC_COL (itc, (*r_cl), r_off, r_len);
	  if (h_len != r_len || 0 != memcmp (itc->itc_row_data + r_off, hash_row + h_off, r_len))
	    return DVC_LESS;
	}
    }
  return DVC_MATCH;
}


void
itc_from_it_ha (it_cursor_t * itc, index_tree_t * it, hash_area_t * ha)
{
  itc_from_it (itc, it);
  itc->itc_insert_key = ha->ha_key;
  itc->itc_row_key = ha->ha_key;
  itc->itc_row_key_id = KI_TEMP;
}


#ifdef OLD_HASH
static int
itc_ha_disk_find (it_cursor_t * itc, buffer_desc_t ** ret_buf, int * ret_pos,
	     hash_area_t * ha, caddr_t * qst, hash_inx_elt_t ** he_ret, uint32 code)
{
  it_cursor_t * ref_itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_ref_itc);

  buffer_desc_t * h_buf;
  hash_inx_elt_t * he = *he_ret;
  if (!ref_itc)
    {
      query_instance_t * qi = (query_instance_t *) qst;
      ref_itc = itc_create (NULL, qi->qi_trx);
      itc_from_it_ha (ref_itc, (index_tree_t *) QST_GET_V (qst, ha->ha_tree), ha);
      qst_set (qst, ha->ha_ref_itc, (caddr_t) ref_itc);
    }
  do
    {
      if (he->he_no == code)
	{
	  if (itc && itc->itc_hash_buf
	      && itc->itc_hash_buf->bd_page == he->he_page)
	    h_buf = itc->itc_hash_buf;
	  else
	    {
	      if (ref_itc->itc_page != he->he_page
		  || !ref_itc->itc_buf)
		{
		  ITC_IN_MAP (ref_itc);
		  if (ref_itc->itc_buf)
		    page_leave_inner (ref_itc->itc_buf);
		  page_wait_access (ref_itc, he->he_page, NULL, NULL, &h_buf, HA_DISTINCT == ha->ha_op ? PA_READ : PA_WRITE, RWG_WAIT_ANY);
		  ITC_LEAVE_MAP (ref_itc);
		  ref_itc->itc_buf = h_buf;
		  ret_buf[0] = h_buf;
		}
	      else
		h_buf = ref_itc->itc_buf;
	    }
	  if (DVC_MATCH == itc_ha_equal (itc, ha, qst, h_buf->bd_buffer + he->he_pos))
	    {
	      ret_buf[0] = h_buf;
	      ret_pos[0] = he->he_pos;
	      return 1;
	    }
	}
      he = he->he_next;
      *he_ret = he;
    } while (he);
  ret_pos[0] = 0;
  return 0;
}
#endif
#ifdef NEW_HASH
static int
itc_ha_disk_find_new (it_cursor_t * itc, buffer_desc_t ** ret_buf, int * ret_pos,
	     hash_area_t * ha, caddr_t * qst, uint32 code, dp_addr_t he_page, short he_pos)
{
  it_cursor_t * ref_itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_ref_itc);
  uint32 code_mask;
#ifdef HASH_DEBUG
  dp_addr_t he_prev_pages[2];
  short he_prev_pos[2];
#endif
  int n_in_bucket = 0;

  buffer_desc_t * h_buf;

#ifdef HASH_DEBUG
  memset (he_prev_pages, 0, sizeof (he_prev_pages));
  memset (he_prev_pos, 0, sizeof (he_prev_pos));
#endif
  if (!ref_itc)
    {
      query_instance_t * qi = (query_instance_t *) qst;
      ref_itc = itc_create (NULL, qi->qi_trx);
      itc_from_it_ha (ref_itc, (index_tree_t *) QST_GET_V (qst, ha->ha_tree), ha);
      qst_set (qst, ha->ha_ref_itc, (caddr_t) ref_itc);
    }
  do
    {
      if (itc && itc->itc_hash_buf
	  && itc->itc_hash_buf->bd_page == he_page)
	h_buf = itc->itc_hash_buf;
      else
	{
	  if (ref_itc->itc_page != he_page
	      || !ref_itc->itc_buf)
	    {
	      ITC_IN_MAP (ref_itc);
	      if (ref_itc->itc_buf)
		page_leave_inner (ref_itc->itc_buf);
	      page_wait_access (ref_itc, he_page, NULL, NULL, &h_buf, HA_DISTINCT == ha->ha_op ? PA_READ : PA_WRITE, RWG_WAIT_ANY);
	      ITC_LEAVE_MAP (ref_itc);
	      ref_itc->itc_buf = h_buf;
	      ret_buf[0] = h_buf;
	    }
	  else
	    h_buf = ref_itc->itc_buf;
	}
      code_mask = (SHORT_REF (h_buf->bd_buffer + he_pos + IE_KEY_ID) >> 13) & 0x7;
      code_mask = code_mask << 9;
      if ((code & 0x0E00) == code_mask)
	{
	  if (DVC_MATCH == itc_ha_equal (itc, ha, qst, h_buf->bd_buffer + he_pos))
	    {
	      ret_buf[0] = h_buf;
	      ret_pos[0] = he_pos;
	      return 1;
	    }
	}
#ifdef HASH_DEBUG
      he_prev_pages[1] = he_prev_pages[0];
      he_prev_pages[0] = he_page;
      he_prev_pos[1] = he_prev_pos[0];
      he_prev_pos[0] = he_pos;
#endif
      he_page = LONG_REF (h_buf->bd_buffer + he_pos - sizeof (dp_addr_t));
      he_pos = SHORT_REF (h_buf->bd_buffer + he_pos + IE_KEY_ID) & 0x1FFF;
      n_in_bucket += 1;
    } while (he_page);
  ret_pos[0] = 0;
  return 0;
}
#endif

void
itc_ha_flush_memcache (hash_area_t * ha, caddr_t * qst)
{
  it_cursor_t * itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_insert_itc);
  index_tree_t * tree = (index_tree_t *) QST_GET_V (qst, ha->ha_tree);
  hash_index_t *hi;
  hi_memcache_key_t *key;
  caddr_t **val;
  id_hash_iterator_t hit;
  if (NULL == tree)
    return;
  hi = tree->it_hi;
  if ((NULL == hi) || (NULL == hi->hi_memcache))
    return;
  if (hi->hi_memcache->ht_count >= hi_end_memcache_size)
    hi->hi_size = MAX (hi->hi_size, 4 * hi_end_memcache_size); /* overflowed, more coming */
  else
    hi->hi_size = hi->hi_memcache->ht_count; /* this is all, flushing at end of query */
  hi_alloc_elements (hi);
  id_hash_iterator (&hit, hi->hi_memcache);
  while (hit_next (&hit, (caddr_t *)(&key), (caddr_t *)(&val)))
    {
/* No feeding temp blobs here because they appear only when the ha is the result of a procedure.
For procedures, we have no memcache. */
      itc_ha_disk_row (itc, NULL, ha, qst, tree, key->hmk_var_len, key->hmk_hash, 0, key->hmk_data, val[0], NULL);
      dk_free_tree ((caddr_t)(key->hmk_data));
      dk_free_tree ((box_t) val[0]);
      key->hmk_data = NULL;
      val[0] = NULL;
    }
  id_hash_clear (hi->hi_memcache);
  id_hash_free (hi->hi_memcache);
  hi->hi_memcache = NULL;
}


int itc_ha_feed (itc_ha_feed_ret_t *ret, hash_area_t * ha, caddr_t * qst, unsigned long feed_temp_blobs)
{
  it_cursor_t * itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_insert_itc);
  int var_len = 0;
  query_instance_t * qi = (query_instance_t *) qst;
  uint32 code = HC_INIT;
  int n_keys = ha->ha_n_keys;
  int n_deps = ha->ha_n_deps;
  int inx;
  hash_index_t *hi;
#ifdef OLD_HASH
  hash_inx_elt_t * he;
#endif
#ifdef NEW_HASH
  it_cursor_t * bp_ref_itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_bp_ref_itc);
  hash_inx_b_ptr_t hibp;
#endif
#define MAX_STACK_N_KEYS 0x10
  int keys_on_stack = (n_keys <= MAX_STACK_N_KEYS);
  int do_flush;
  index_tree_t * tree = (index_tree_t *) QST_GET_V (qst, ha->ha_tree);
  if (!tree)
    {
      tree = it_temp_allocate (wi_inst.wi_temp);
      tree->it_hi = hi_allocate ((int) MIN (ha->ha_row_count, (long) INT_MAX),
	  (HA_FILL != ha->ha_op));
      tree->it_key = ha->ha_key;
      tree->it_shared = HI_PRIVATE;
      qst_set (qst, ha->ha_tree, (caddr_t) tree);
    }
  if (!itc)
    {
      itc = itc_create (NULL, qi->qi_trx);
      /* GK: the itc has to be initialized regardless of the feed_temp_blobs,
	 because of the XML entities that are *allways* fed as temp space blobs */
      /*if (feed_temp_blobs)*/
	itc_from_it_ha (itc, tree, ha);
      qst_set (qst, ha->ha_insert_itc, (caddr_t) itc);
    }
#ifdef NEW_HASH
  if (!bp_ref_itc)
    {
      bp_ref_itc = itc_create (NULL, qi->qi_trx);
      itc_from_it (bp_ref_itc, tree);
      qst_set (qst, ha->ha_bp_ref_itc, (caddr_t) bp_ref_itc);
    }
#endif
  ret->ihfr_hi = hi = tree->it_hi;
  for (inx = 0; inx < n_keys; inx++)
    {
      state_slot_t * ssl = ha->ha_slots[inx];
      if (ssl)
	{
	  caddr_t value = QST_GET (qst, ssl);
	  dtp_t dtp = DV_TYPE_OF (value);
	  if (qi->qi_no_cast_error && HA_DISTINCT == ha->ha_op && IS_BLOB_HANDLE_DTP (dtp))
	    return DVC_LESS;
	  if (!ha->ha_allow_nulls && DV_DB_NULL == dtp)
	    return DVC_MATCH;
	  if (dtp != ha->ha_key_cols[inx].cl_sqt.sqt_dtp)
	    {
	      value = hash_cast (qi, ha, inx, ssl, value);
	      dtp = DV_TYPE_OF (value);
	    }
	  code = key_hash_box (value, dtp, code, &var_len, ssl->ssl_sqt.sqt_collation,
	      ha->ha_key_cols[inx].cl_sqt.sqt_dtp);
	}
      else
	{
	  GPF_T;
#if 0
	  dbe_col_loc_t * cl = &ha->ha_cols[inx];
	  if (!ha->ha_allow_nulls && cl->cl_null_mask
	      && row[cl->cl_null_flag] & cl->cl_null_mask)
	    return DVC_MATCH;
	  code = key_hash_col (row, itc->itc_row_key, cl, code, &var_len);
	  keys_on_stack = 0; /* This is because copying will happen anyway */
#endif
	}
    }
  code &= ID_HASHED_KEY_MASK;
  if (hi->hi_memcache)
    {
      caddr_t hmk_data_buf [BOX_AUTO_OVERHEAD / sizeof (caddr_t) + 1 + MAX_STACK_N_KEYS];
      hi_memcache_key_t hmk;
      caddr_t *deps;
      ret->ihfr_memcached = 1;
      hmk.hmk_hash = code;
      hmk.hmk_ha = ha;
      if (keys_on_stack)
	BOX_AUTO((((caddr_t *)(&(hmk.hmk_data)))[0]), hmk_data_buf, n_keys * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      else
        hmk.hmk_data = (caddr_t *)dk_alloc_box (n_keys * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      for (inx = 0; inx < n_keys; inx++)
	{
	  state_slot_t * ssl = ha->ha_slots[inx];
	  if (ssl)
	    {
	      caddr_t value = QST_GET (qst, ssl);
	      hmk.hmk_data[inx] = keys_on_stack ? value : box_copy_tree (value);
	    }
	  else
	    {
	      GPF_T;
#if 0
	      dbe_col_loc_t * cl = &ha->ha_cols[inx];
	      db_buf_t fictive_page_buffer = row - itc->itc_position;
	      hmk.hmk_data[inx] = itc_box_column (itc, fictive_page_buffer, 0 /* it's unused */, cl);
#endif
	    }
	}
      deps = (caddr_t *)id_hash_get (hi->hi_memcache, (caddr_t)(&hmk));
      if (NULL != deps)
	{
	  hi_memcache_key_t * saved_hmk = (hi_memcache_key_t *)(((char *)(deps)) - hi->hi_memcache->ht_key_length);
	  ret->ihfr_hmk_data = saved_hmk->hmk_data;
	  ret->ihfr_deps = (caddr_t *)(deps[0]);
	  if (!keys_on_stack)
	    dk_free_tree ((caddr_t)(hmk.hmk_data));
	  return DVC_MATCH;
	}
      if (keys_on_stack)
	hmk.hmk_data = (caddr_t *) box_copy_tree ((caddr_t) hmk.hmk_data);
      hmk.hmk_var_len = var_len;
      deps = (caddr_t *)dk_alloc_box_zero (n_deps * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      for (inx = 0; inx < n_deps; inx++)
	deps[inx] = box_copy_tree (QST_GET (qst, ha->ha_slots[n_keys+inx]));
      id_hash_set (hi->hi_memcache, (caddr_t)(&hmk), (caddr_t)(&deps));
      /* Now we have the data stored so we can check for overflow */
      if ((!ha->ha_memcache_only) && 
	  ((long) hi->hi_memcache->ht_count) > hi_end_memcache_size
	  )
        do_flush = 1;
      else
	{
          ret->ihfr_hmk_data = hmk.hmk_data;
	  ret->ihfr_deps = deps;
	  return DVC_LESS;
	}
    }
  else
    do_flush = 0; /* no memcache - no flush */

/* Now we start disk-based processing */
  ret->ihfr_memcached = 0;

  itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_insert_itc);
  if (do_flush)
    {
      itc_ha_flush_memcache (ha, qst);
      /* if it is quietcast and len overflows, then maybe the hash is even empty */
      if (HA_FILL == ha->ha_op)
        GPF_T;
      return DVC_LESS;
    }
#ifdef OLD_HASH
      he = HI_BUCKET (hi, code);
#endif
#ifdef NEW_HASH
  HI_BUCKET_PTR (hi, code, bp_ref_itc, &hibp, PA_WRITE);
#endif
  if (HA_FILL != ha->ha_op)
#ifdef USE_OLD_HASH
    if (HI_EMPTY != he->he_next)
#else
    if (hibp.hibp_page)
#endif
      {
#ifdef USE_OLD_HASH
	int rc = itc_ha_disk_find (itc, &(ret->ihfr_disk_buf), &(ret->ihfr_disk_pos), ha, qst, &he, code);
#else
	int rc = itc_ha_disk_find_new (itc, &(ret->ihfr_disk_buf), &(ret->ihfr_disk_pos), ha, qst, code,
	    hibp.hibp_page, hibp.hibp_pos);
#endif
        if (DVC_MATCH == rc)
	  return DVC_MATCH;
      }
#ifdef OLD_HASH
  itc_ha_disk_row (itc, NULL, ha, qst, tree, var_len, code, feed_temp_blobs, NULL, NULL, NULL);
#endif
#ifdef NEW_HASH
  itc_ha_disk_row (itc, NULL, ha, qst, tree, var_len, code, feed_temp_blobs, NULL, NULL, &hibp);
#endif
  ret->ihfr_disk_buf = itc->itc_hash_buf;
  ret->ihfr_disk_pos = itc->itc_hash_buf_prev;
  return DVC_LESS;
}


void
setp_group_row (setp_node_t * setp, caddr_t * qst)
{
  caddr_t err = NULL;
  hash_area_t * ha = setp->setp_ha;
  itc_ha_feed_ret_t ihfr;
  int rc = itc_ha_feed (&ihfr, ha, qst, 0);
  index_tree_t * tree;
  hash_index_t * hi;

  if (DVC_MATCH == rc)
    goto runX_begin; /* see below */

  if (!setp->setp_any_user_aggregate_gos)
    goto run1_no_user_aggregates; /* see below */

  if (ihfr.ihfr_memcached)
    {
      int dep_box_inx = 0;
      DO_SET (gb_op_t *, op, &setp->setp_gb_ops)
	{
	  switch (op->go_op)
	    {
	    default: break;
	    case AMMSC_USER:
	      {
		caddr_t *dep_ptr = ihfr.ihfr_deps + dep_box_inx;
		qst_set (qst, op->go_old_val, NEW_DB_NULL);
		ins_call (op->go_ua_init_setp_call, qst, NULL);
		ins_call (op->go_ua_acc_setp_call, qst, NULL);
	        dk_free_tree (dep_ptr[0]);
	        dep_ptr[0] = box_copy_tree (QST_GET_V (qst, op->go_old_val));
		break;
	      }
	    }
	  dep_box_inx++;
	}
      END_DO_SET();
    }
  else
    {
      int dep_box_inx = 0;
      it_cursor_t * itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_ref_itc);
      itc->itc_position = ihfr.ihfr_disk_pos;
      itc->itc_row_data = ihfr.ihfr_disk_buf->bd_buffer + ihfr.ihfr_disk_pos + IE_FIRST_KEY;
      DO_SET (gb_op_t *, op, &setp->setp_gb_ops)
	{
	  switch (op->go_op)
	    {
	    default: break;
	    case AMMSC_USER:
	      {
		dbe_col_loc_t * cl = &ha->ha_key_cols[ha->ha_n_keys + dep_box_inx];
		if (cl->cl_fixed_len < 0)
		  goto run1_next_disk_col;
		qst_set (qst, op->go_old_val, NEW_DB_NULL);
		ins_call (op->go_ua_init_setp_call, qst, NULL);
		ins_call (op->go_ua_acc_setp_call, qst, NULL);
		row_set_col (ihfr.ihfr_disk_buf->bd_buffer + itc->itc_position + IE_FIRST_KEY,
		  cl, QST_GET_V (qst, op->go_old_val), NULL, 0, ha->ha_key, &err, NULL, NULL, qst);
		break;
	      }
	    }
	run1_next_disk_col: ;
	  dep_box_inx++;
	}
      END_DO_SET();
      buf_set_dirty (ihfr.ihfr_disk_buf);
    }

run1_no_user_aggregates: ;

  if (!setp->setp_any_distinct_gos)
	return;
      /* for the distinct gb cols.
	 that should (?) be further optimized
	 as not to do two hash lookups (1 for
	 the distinct fnref arg and 2 for the
	 group by)
       */
  DO_SET (gb_op_t *, op, &setp->setp_gb_ops)
    {
      if (op->go_distinct_ha)
	{
	  itc_ha_feed_ret_t ihfr;
	  itc_ha_feed (&ihfr, op->go_distinct_ha, qst, 0);
	}
    }
  END_DO_SET ();
  return;

runX_begin: ;

  tree = (index_tree_t *) QST_GET_V (qst, ha->ha_tree);
  hi = tree->it_hi;
  if (ihfr.ihfr_memcached)
    {
      int dep_box_inx = 0;
      DO_SET (gb_op_t *, op, &setp->setp_gb_ops)
	{
	  int rc;
	  dbe_col_loc_t * cl = &ha->ha_key_cols[ha->ha_n_keys + dep_box_inx];
	  caddr_t *dep_ptr = ihfr.ihfr_deps + dep_box_inx;
	  switch (op->go_op)
	    {
	    case AMMSC_MIN:
	    case AMMSC_MAX:
	      {
		state_slot_t * ssl = setp->setp_dependent_box[dep_box_inx];
		caddr_t new_val = QST_GET (qst, ssl);
		if (DV_DB_NULL == DV_TYPE_OF (new_val))
		  goto next_mem_col;
		if (op->go_distinct_ha)
		  {
		    itc_ha_feed_ret_t ihfr;
		    if (DVC_MATCH == itc_ha_feed (&ihfr, op->go_distinct_ha, qst, 0))
		      goto next_mem_col;
		  }
		rc = cmp_boxes (new_val, dep_ptr[0],
		  cl->cl_sqt.sqt_collation, cl->cl_sqt.sqt_collation);
		if (DVC_UNKNOWN == rc
		  || (rc == DVC_LESS && op->go_op == AMMSC_MIN)
		  || (rc == DVC_GREATER && op->go_op == AMMSC_MAX))
		  {
		    dk_free_tree (dep_ptr[0]);
		    dep_ptr[0] = box_copy_tree (new_val);
		  }
		break;
	      }
	    case AMMSC_COUNT:
	    case AMMSC_SUM:
	    case AMMSC_COUNTSUM:
	      {
		state_slot_t * ssl = setp->setp_dependent_box[dep_box_inx];
		caddr_t new_val = QST_GET (qst, ssl);
		qst_set (qst, op->go_old_val, box_copy_tree (dep_ptr[0]));
		if (DV_DB_NULL == DV_TYPE_OF (new_val))
		  goto next_mem_col;
		if (op->go_distinct_ha)
		  {
		    itc_ha_feed_ret_t ihfr;
		    if (DVC_MATCH == itc_ha_feed (&ihfr, op->go_distinct_ha, qst, 0))
		      goto next_mem_col;
		  }
		/* can be null on the row if 1st value was null. Replace w/ new val */
		if (DV_DB_NULL == DV_TYPE_OF (QST_GET_V (qst, op->go_old_val)))
		  {
		    dk_free_tree (dep_ptr[0]);
		    dep_ptr[0] = box_copy_tree (new_val);
		  }
		else
		  {
		    box_add (new_val, QST_GET_V (qst, op->go_old_val), qst, op->go_old_val);
		    dk_free_tree (dep_ptr[0]);
		    dep_ptr[0] = box_copy_tree (QST_GET_V (qst, op->go_old_val));
		  }
		break;
	      }
	    case AMMSC_USER:
	      {
		caddr_t old_val;
		qst_set (qst, op->go_old_val, box_copy_tree (dep_ptr[0]));
		old_val = QST_GET_V (qst, op->go_old_val);
		if (NULL == old_val)
		  {
		    qst_set (qst, op->go_old_val, NEW_DB_NULL);
		    ins_call (op->go_ua_init_setp_call, qst, NULL);
		  }
		else if (DV_DB_NULL == DV_TYPE_OF (old_val))
		  {
		    ins_call (op->go_ua_init_setp_call, qst, NULL);
		  }
		ins_call (op->go_ua_acc_setp_call, qst, NULL);
		old_val = QST_GET_V (qst, op->go_old_val);
		if (NULL == old_val)
		  old_val = box_num_nonull (0);
	        dk_free_tree (dep_ptr[0]);
	        dep_ptr[0] = box_copy_tree (old_val);
		break;
	      }
	    }
	next_mem_col: ;
	  dep_box_inx++;
	}
      END_DO_SET();
    }
  else
    {
      int dep_box_inx = 0;
      it_cursor_t * itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_ref_itc);
      itc->itc_position = ihfr.ihfr_disk_pos;
      itc->itc_row_data = ihfr.ihfr_disk_buf->bd_buffer + ihfr.ihfr_disk_pos + IE_FIRST_KEY;
      DO_SET (gb_op_t *, op, &setp->setp_gb_ops)
	{
	  int rc;
	  dbe_col_loc_t * cl = &ha->ha_key_cols[ha->ha_n_keys + dep_box_inx];
	  if (cl->cl_fixed_len < 0)
	    goto next_disk_col;
	  itc_qst_set_column (itc, cl, qst, op->go_old_val);
	  switch (op->go_op)
	    {
	    case AMMSC_MIN:
	    case AMMSC_MAX:
	      {
		state_slot_t * ssl = setp->setp_dependent_box[dep_box_inx];
		caddr_t new_val = QST_GET (qst, ssl);
		if (DV_DB_NULL == DV_TYPE_OF (new_val))
		  goto next_disk_col;
		if (op->go_distinct_ha)
		  {
		    itc_ha_feed_ret_t ihfr;
		    if (DVC_MATCH == itc_ha_feed (&ihfr, op->go_distinct_ha, qst, 0))
		      goto next_disk_col;
		  }
		rc = cmp_boxes (new_val, QST_GET_V (qst, op->go_old_val),
		  cl->cl_sqt.sqt_collation, cl->cl_sqt.sqt_collation);
		if (DVC_UNKNOWN == rc
		  || (rc == DVC_LESS && op->go_op == AMMSC_MIN)
		  || (rc == DVC_GREATER && op->go_op == AMMSC_MAX))
		  {
		    row_set_col (ihfr.ihfr_disk_buf->bd_buffer + itc->itc_position + IE_FIRST_KEY,
		      cl, new_val, NULL, 0, ha->ha_key, &err, NULL, NULL, qst);
		  }
		break;
	      }
	    case AMMSC_COUNT:
	    case AMMSC_SUM:
	    case AMMSC_COUNTSUM:
	      {
		state_slot_t * ssl = setp->setp_dependent_box[dep_box_inx];
		caddr_t new_val = QST_GET (qst, ssl);
		if (DV_DB_NULL == DV_TYPE_OF (new_val))
		  goto next_disk_col;
		if (op->go_distinct_ha)
		  {
		    itc_ha_feed_ret_t ihfr;
		    if (DVC_MATCH == itc_ha_feed (&ihfr, op->go_distinct_ha, qst, 0))
		      goto next_disk_col;
		  }
		/* can be null on the row if 1st value was null. Replace w/ new val */
		if (DV_DB_NULL == DV_TYPE_OF (QST_GET_V (qst, op->go_old_val)))
		  row_set_col (ihfr.ihfr_disk_buf->bd_buffer + itc->itc_position + IE_FIRST_KEY,
		    cl, new_val, NULL, 0, ha->ha_key, &err, NULL, NULL, qst);
		else
		  {
		    box_add (new_val, QST_GET_V (qst, op->go_old_val), qst, op->go_old_val);
		    row_set_col (ihfr.ihfr_disk_buf->bd_buffer + itc->itc_position + IE_FIRST_KEY,
		      cl, QST_GET_V (qst, op->go_old_val), NULL, 0, ha->ha_key, &err, NULL, NULL, qst);
		  }
		break;
	      }
	    case AMMSC_USER:
	      {
		if (DV_DB_NULL == DV_TYPE_OF (QST_GET_V (qst, op->go_old_val)))
		  ins_call (op->go_ua_init_setp_call, qst, NULL);
		ins_call (op->go_ua_acc_setp_call, qst, NULL);
		row_set_col (ihfr.ihfr_disk_buf->bd_buffer + itc->itc_position + IE_FIRST_KEY,
		  cl, QST_GET_V (qst, op->go_old_val), NULL, 0, ha->ha_key, &err, NULL, NULL, qst);
		break;
	      }
	    }
	next_disk_col: ;
	  dep_box_inx++;
	}
      END_DO_SET();
      buf_set_dirty (ihfr.ihfr_disk_buf);
    }
}


void
setp_order_row (setp_node_t * setp, caddr_t * qst)
{
  query_instance_t * volatile qi = (query_instance_t *) qst;
  caddr_t err = NULL;
  hash_area_t * ha = setp->setp_ha;
  index_tree_t * tree = (index_tree_t *) QST_GET_V (qst, ha->ha_tree);
  it_cursor_t * ins_itc;
  it_cursor_t * itc = NULL;
  dbe_key_t * key = ha->ha_key;
  union
    {
      dtp_t ins_row[MAX_ROW_BYTES];
      double allign_dummy;
    } v;
  int v_fill = key->key_row_var_start;
  int inx;
  db_buf_t row = &v.ins_row[0];

  memset (&v, 0, sizeof (v));
  if (!tree)
    {
      tree = it_temp_allocate (wi_inst.wi_temp);
      tree->it_key = ha->ha_key;
      it_temp_tree (tree);
      qst_set (qst, ha->ha_tree, (caddr_t) tree);
    }
  ins_itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_ref_itc);
  if (!ins_itc)
    {
      ins_itc = itc_create (NULL, qi->qi_trx);
      itc_from_it_ha (ins_itc, tree, ha);
      qst_set (qst, ha->ha_ref_itc, (caddr_t) ins_itc);
      ins_itc->itc_out_state = qst;
    }
  itc_free_owned_params (ins_itc);
  ITC_START_SEARCH_PARS (ins_itc);
  ins_itc->itc_specs = setp->setp_insert_specs;

  SHORT_SET (row + IE_NEXT_IE, 0);
  SHORT_SET (row + IE_KEY_ID, -1);
  row += IE_FIRST_KEY;
  for (inx = 0; ha->ha_key_cols[inx].cl_col_id; inx++)
    {
      state_slot_t * ssl  = ha->ha_slots[inx];
      if (ssl)
	{
	  row_set_col_temp (row, &ha->ha_key_cols[inx], QST_GET (qst, ssl), &v_fill, ROW_MAX_DATA,
		       ha->ha_key, &err, ins_itc, NULL, qst);
	  if (err)
	    sqlr_resignal (err);
	}
      else
	{
	  int off, len;
	  ITC_COL (itc, ha->ha_cols[inx], off, len);
	  upd_col_copy (ha->ha_key, &ha->ha_key_cols[inx], row, &v_fill, ROW_MAX_DATA,
			&ha->ha_cols[inx], itc->itc_row_data, off, len);
	}
    }
  ITC_FAIL (ins_itc)
    {
      int rc;
      rc = itc_insert_unq_ck (ins_itc, &v.ins_row[0], UNQ_SORT);
    }
  ITC_FAILED
    {
      /* this node may be invoked from inside itc_row_check.  If so and there is a trx error, come out as an error, not as RST_DEADLOCK.
       * This will cause itc_next to exit its buffer properly */
      sqlr_resignal (srv_make_trx_error (qi->qi_trx->lt_error, NULL));
    }
  END_FAIL (ins_itc);
}


caddr_t
bif_hash (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int d;
  uint32 code = HC_INIT;
  caddr_t arg = bif_arg (qst, args, 0, "hash");
  return (box_num (key_hash_box (arg, DV_TYPE_OF (arg), code, &d, NULL, DV_TYPE_OF (arg))));
}



caddr_t box_md5 (caddr_t);

caddr_t
bif_md5_box (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_arg (qst, args, 0, "md5_box");
  return (box_md5 (arg));
}


void
hs_outer_output (hash_source_t * hs, caddr_t * qst)
{
  int inx;
  DO_BOX (state_slot_t *, out, inx, hs->hs_out_slots)
    {
      qst_set_bin_string (qst, out, (db_buf_t) "", 0, DV_DB_NULL);
    }
  END_DO_BOX;
  qn_ts_send_output ((data_source_t *) hs, qst, hs->hs_after_join_test);
}


void
hash_source_input (hash_source_t * hs, caddr_t * qst, caddr_t * qst_cont)
{
  int start = 0;
  int any_passed = 0;
  it_cursor_t * ref_itc;
#ifdef NEW_HASH
  it_cursor_t * bp_ref_itc;
  query_instance_t *qi = (query_instance_t *)qst;
#endif
  hash_index_t * hi;
  hash_area_t * ha = hs->hs_ha;

  if (!qst_cont)
    any_passed = 1; /* if this is a 'get more' invocation of the node there must have been at least one match */
  for (;;)
    {
      int inx, pos = 0, rc;
      uint32 code = HC_INIT;
#ifdef OLD_HASH
      hash_inx_elt_t *he = NULL;
#endif
      buffer_desc_t *buf = NULL;
      index_tree_t * it = NULL;
#ifdef NEW_HASH
      hash_inx_b_ptr_t hibp_buf, *hibp = &hibp_buf;
#endif
      if (!qst_cont)
	{
	  start = 0;
	  qst_cont = qn_get_in_state ((data_source_t *) hs, qst);
	  if (!qst_cont)
	    return;
	}
      else
	start = 1;

      it = (index_tree_t *) QST_GET_V (qst, ha->ha_tree);
      ref_itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_ref_itc);
      if (!it)
	return;
#ifdef NEW_HASH
      bp_ref_itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_bp_ref_itc);
      if (!bp_ref_itc)
	{
	  bp_ref_itc = itc_create (NULL, qi->qi_trx);
	  itc_from_it (bp_ref_itc, it);
	  qst_set (qst, ha->ha_bp_ref_itc, (caddr_t) bp_ref_itc);
	}
#endif
      hi = it->it_hi;
      if (start)
	{
	  if (!ref_itc)
	    {
	      query_instance_t * qi = (query_instance_t *) qst;
	      ref_itc = itc_create (NULL, qi->qi_trx);
	      itc_from_it_ha (ref_itc, (index_tree_t *) QST_GET_V (qst, ha->ha_tree), ha);
	      qst_set (qst, ha->ha_ref_itc, (caddr_t) ref_itc);
	    }
	  DO_BOX (state_slot_t *, ref, inx, hs->hs_ref_slots)
	    {
	      int d = 0;
	      dtp_t dtp;
	      caddr_t k = QST_GET (qst, ref);
	      dtp = DV_TYPE_OF (k);
	      if (dtp != DV_DB_NULL && dtp != ha->ha_key_cols[inx].cl_sqt.sqt_dtp)
		{
		  k = hash_cast ((query_instance_t*) qst, ha, inx, ref, k);
		  dtp = DV_TYPE_OF (k);
		}
	      code = key_hash_box (k, dtp, code, &d, ha->ha_key_cols[inx].cl_sqt.sqt_collation,
		  ha->ha_key_cols[inx].cl_sqt.sqt_dtp);
	    }
	  END_DO_BOX;
	  code &= ID_HASHED_KEY_MASK;
#ifdef OLD_HASH
	  he = HI_BUCKET (hi, code);
#endif
#ifdef NEW_HASH
	  HI_BUCKET_PTR (hi, code, bp_ref_itc, hibp, PA_WRITE);
#endif

#ifdef USE_OLD_HASH
	  retr_dbg_fprintf ((stdout, "hs_i:start: page=%lu next=%p pos=%lu, no=%lu\n",
	      (unsigned long) he->he_page, he->he_next, (unsigned long) he->he_pos, (unsigned long) he->he_no));
	  if (HI_EMPTY == he->he_next)
#else
	  retr_dbg_fprintf ((stdout, "hs_i:start: page=%lu pos=%lu, no=%lu\n",
	      (unsigned long) hibp->hibp_page, (unsigned long) hibp->hibp_pos, (unsigned long) hibp->hibp_no));
	  if (!hibp->hibp_page)
#endif
	    {
	      qn_record_in_state ((data_source_t *) hs, qst, NULL);
	      if (hs->hs_is_outer)
		hs_outer_output (hs, qst);
	      return;
	    }
	}
      else
	{
	  if (NULL != hi->hi_memcache)
	    {
#ifdef NEW_HASH
#ifdef OLD_HASH
	      if (qst[hs->hs_current_inx])
		dk_free_box (((caddr_t *) qst[hs->hs_current_inx])[1]);
#endif
	      dk_free_box (qst[hs->hs_current_inx]);
#endif
	      qst[hs->hs_current_inx] = NULL;
	      qn_record_in_state ((data_source_t*) hs, qst, NULL);
	      if (hs->hs_is_outer && !any_passed)
		hs_outer_output (hs, qst);
	      return;
	    }
#if defined (OLD_HASH) && defined (NEW_HASH)
	  he = (hash_inx_elt_t *) ((caddr_t *) qst[hs->hs_current_inx])[0];
	  hibp = (hash_inx_b_ptr_t *) ((caddr_t *) qst[hs->hs_current_inx])[1];
#ifdef USE_OLD_HASH
	  code = he->he_no;
#else
	  code = hibp->hibp_no;
#endif
#elif defined (OLD_HASH)
	  he = (hash_inx_elt_t *) qst[hs->hs_current_inx];
	  code = he->he_no;
#elif defined (NEW_HASH)
	  hibp = (hash_inx_b_ptr_t *) qst[hs->hs_current_inx];
	  code = hibp->hibp_no;
#endif
	}
      if (NULL != hi->hi_memcache)
	{
	  hi_memcache_key_t hmk;
	  caddr_t *deps;
	  int inx;
	  int n_keys = ha->ha_n_keys;
	  hmk.hmk_hash = code;
	  hmk.hmk_ha = ha;
	  hmk.hmk_data = (caddr_t *)dk_alloc_box_zero (n_keys * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  for (inx = 0; inx < n_keys; inx++)
	    {
	      state_slot_t * ref = hs->hs_ref_slots[inx];
	      caddr_t value = QST_GET (qst, ref);
	      dtp_t dtp = DV_TYPE_OF (value);
	      if (DV_DB_NULL == dtp)
		{
		  hmk.hmk_data[inx] = NEW_DB_NULL;
		  continue;
		}
	      if (dtp != DV_DB_NULL && dtp != ha->ha_key_cols[inx].cl_sqt.sqt_dtp)
		{
		  value = hash_cast ((query_instance_t*) qst, ha, inx, ref, value);
		  dtp = DV_TYPE_OF (value);
		}
	      hmk.hmk_data[inx] = box_copy_tree (value);
	    }
	  deps = (caddr_t *)id_hash_get (hi->hi_memcache, (caddr_t)(&hmk));
          dk_free_tree ((caddr_t)(hmk.hmk_data));
	  if (NULL != deps)
	    {
	      hi_memcache_key_t * saved_hmk = (hi_memcache_key_t *)(((char *)(deps)) - hi->hi_memcache->ht_key_length);
	      deps = (caddr_t *)(deps[0]);
	      qn_record_in_state ((data_source_t*) hs, qst, (caddr_t*) NULL);
	      DO_BOX (state_slot_t *, out, inx, hs->hs_out_slots)
		{
		  ptrlong col_idx = hs->hs_out_cols_indexes[inx];
		  caddr_t val;
		  if (col_idx > 0)
		    {
		      if (col_idx > n_keys)
			val = deps[col_idx - n_keys];
		      else
			val = saved_hmk->hmk_data[col_idx];
		      qst_set (qst, out, box_copy_tree (val));
		    }
		}
	    }
	  END_DO_BOX;
	  if (!hs->src_gen.src_after_test || code_vec_run (hs->src_gen.src_after_test, qst))
	    {
	      any_passed = 1;
	      qn_ts_send_output ((data_source_t*) hs, qst, hs->hs_after_join_test);
	    }
	  if (!any_passed && hs->hs_is_outer)
	    hs_outer_output (hs, qst);
          return;
	}

#if 0 && defined (OLD_HASH) && defined (NEW_HASH)
      if (he->he_page != hibp->hibp_page)
	{
	  fprintf (stderr, "1different pages : he_page=%lu next_page=%lu\n",
	      he->he_page, hibp->hibp_page);
	  GPF_T;
	}
#endif
#ifdef USE_OLD_HASH
      rc = itc_ha_disk_find (NULL, &buf, &pos, ha, qst, &he, code);
#else
      rc = itc_ha_disk_find_new (NULL, &buf, &pos, ha, qst, code, hibp->hibp_page, hibp->hibp_pos);
#endif
      if (DVC_MATCH == rc)
	{
#ifdef OLD_HASH
	  hash_inx_elt_t * next_he;
#endif
#ifdef NEW_HASH
	  dp_addr_t next_page_dp;
	  next_page_dp = LONG_REF (buf->bd_buffer + pos - sizeof (dp_addr_t));
#endif

#ifdef OLD_HASH
	  next_he = he->he_next;
	  while (next_he)
	    {
	      if (next_he->he_no == code)
		break;
	      next_he = next_he->he_next;
	    }
#endif
#if 0 && defined (OLD_HASH) && defined (NEW_HASH)
	  if ((next_he && next_he->he_page != next_page_dp) ||
	      (!next_he && next_page_dp))
	    {
	      fprintf (stderr, "2different next pages : he_page=%lu next_page=%lu\n",
		  next_he ? next_he->he_page : 0, next_page_dp);
	      GPF_T;
	    }
#endif

#ifdef USE_OLD_HASH
	  if (next_he)
#else
	  if (next_page_dp)
#endif
	    {
#ifdef NEW_HASH
#ifdef OLD_HASH
	      if (qst[hs->hs_current_inx])
		dk_free_box (((caddr_t *) qst[hs->hs_current_inx])[1]);
#endif
	      dk_free_box (qst[hs->hs_current_inx]);

	      hibp = (hash_inx_b_ptr_t *) dk_alloc_box (sizeof (hash_inx_b_ptr_t), DV_CUSTOM);
	      hibp->hibp_page = next_page_dp;
	      hibp->hibp_pos = SHORT_REF (buf->bd_buffer + pos + IE_KEY_ID) & 0x1FFF;
	      hibp->hibp_no = code;
#endif
#if defined (OLD_HASH) && defined (NEW_HASH)
	      qst[hs->hs_current_inx] = (caddr_t) sc_list (2, next_he, hibp);
#elif defined (OLD_HASH)
	      qst[hs->hs_current_inx] = (caddr_t) next_he;
#elif defined (NEW_HASH)
	      qst[hs->hs_current_inx] = (caddr_t) hibp;
#endif
	    }
	  else
	    {
#ifdef NEW_HASH
#ifdef OLD_HASH
	      if (qst[hs->hs_current_inx])
		dk_free_box (((caddr_t *) qst[hs->hs_current_inx])[1]);
#endif
	      dk_free_box (qst[hs->hs_current_inx]);
#endif
	      qst[hs->hs_current_inx] = (caddr_t) NULL;
	    }
#if defined (OLD_HASH)
	  qn_record_in_state ((data_source_t*) hs, qst, next_he ? qst : (caddr_t*) NULL);
#endif
#if defined (NEW_HASH)
	  qn_record_in_state ((data_source_t*) hs, qst, next_page_dp ? qst : (caddr_t*) NULL);
#endif
	  ref_itc->itc_position = pos;
	  DO_BOX (state_slot_t *, out, inx, hs->hs_out_slots)
	    {
	      ref_itc->itc_row_data = buf->bd_buffer + pos + IE_FIRST_KEY;
	      itc_qst_set_column (ref_itc, &hs->hs_out_cols[inx], qst, out);
	    }
	  END_DO_BOX;
	  ITC_IN_MAP (ref_itc);
	  itc_page_leave (ref_itc, buf);
	  ref_itc->itc_buf = NULL;
	  if (!hs->src_gen.src_after_test || code_vec_run (hs->src_gen.src_after_test, qst))
	    {
	      any_passed = 1;
	      qn_ts_send_output ((data_source_t*) hs, qst, hs->hs_after_join_test);
	    }
#ifdef USE_OLD_HASH
	  if (!next_he)
#else
	  if (!next_page_dp)
#endif
	    {
	      if (!any_passed && hs->hs_is_outer)
		hs_outer_output (hs, qst);
	      return;
	    }
	}
      else
	{
#ifdef NEW_HASH
#ifdef OLD_HASH
	  if (qst[hs->hs_current_inx])
	    dk_free_box (((caddr_t *) qst[hs->hs_current_inx])[1]);
#endif
	  dk_free_box (qst[hs->hs_current_inx]);
#endif
	  qst[hs->hs_current_inx] = NULL;
	  qn_record_in_state ((data_source_t*) hs, qst, NULL);
	  if (ref_itc->itc_buf)
	    {
	      buf = ref_itc->itc_buf;
	      ref_itc->itc_buf = NULL;
	      itc_page_leave (ref_itc, buf);
	    }
	  if (hs->hs_is_outer && !any_passed)
	    hs_outer_output (hs, qst);
	  return;
	}
      qst_cont = NULL;
    }
}



#define IN_HIC \
  mutex_enter (hash_index_cache.hic_mtx)

#define LEAVE_HIC \
  mutex_leave (hash_index_cache.hic_mtx)


int
it_hi_done (index_tree_t * it)
{
  int state = 1;
  if (HI_PRIVATE == it->it_shared)
    return 0;
  IN_HIC;
  it->it_ref_count--;
  if (0 == it->it_ref_count && HI_OK != it->it_shared)
    state = 0;
  LEAVE_HIC;
  return state;
}


void
it_hi_set_sensitive (index_tree_t * it)
{
  hi_signature_t * hsi = it->it_hi_signature;
  int inx, len = box_length ((caddr_t) hsi->hsi_col_ids) / sizeof (oid_t);
  dk_set_t deps;
  for (inx = 0; inx < len; inx++)
    {
      deps = (dk_set_t) gethash ((void*) (ptrlong) hsi->hsi_col_ids[inx], hash_index_cache.hic_col_to_it);
      if (!dk_set_member (deps, (void*) it))
	{
	  if (deps)
	    dk_set_conc (deps, dk_set_cons ((void*) it, NULL));
	  else
	    sethash ((void*) (ptrlong) hsi->hsi_col_ids[inx], hash_index_cache.hic_col_to_it, (void*) dk_set_cons ((void*) it, NULL));
	}
    }
  deps = (dk_set_t) gethash ((void*) unbox (hsi->hsi_super_key), hash_index_cache.hic_pk_to_it);
  dk_set_push (&deps, (void*) it);
  sethash ((void*) unbox (hsi->hsi_super_key), hash_index_cache.hic_pk_to_it, deps);
}


void
it_hi_clear_sensitive (index_tree_t * it)
{
  hi_signature_t * hsi;
  int inx, len;
  dk_set_t deps;

  hsi = it->it_hi_signature;
  len = box_length ((caddr_t) hsi->hsi_col_ids) / sizeof (oid_t);
  for (inx = 0; inx < len; inx++)
    {
      deps = (dk_set_t) gethash ((void*) (ptrlong) hsi->hsi_col_ids[inx], hash_index_cache.hic_col_to_it);
      if (dk_set_member (deps, (void*) it))
	{
	  dk_set_delete (&deps, (void*) it);
	  sethash ((void*) (ptrlong) hsi->hsi_col_ids[inx], hash_index_cache.hic_col_to_it, (void*) deps);
	}
    }
  deps = (dk_set_t) gethash ((void*) unbox (hsi->hsi_super_key), hash_index_cache.hic_pk_to_it);
  dk_set_delete (&deps, (void*) it);
  sethash ((void*) unbox (hsi->hsi_super_key), hash_index_cache.hic_pk_to_it, deps);
}


int
it_hash_wait_access (index_tree_t * it, caddr_t * qst)
{
  query_instance_t * qi = (query_instance_t *) qst;
  if (dk_set_member (qi->qi_trx->lt_hi_delta, (void*) it))
    return HI_PRIVATE; /* this txn has changes to this hi.  Make new one to see changes */
  if (HI_FILL == it->it_shared)
    {
      /* GK: deadlocks with cpt_rollback because lt_threads > 1.
	 Otherwise would have to decrement lt_threads but then
	 the filling transaction getting killed still might never complete
	 filling the hash, hence no recovery. Too complicated.
      du_thread_t * self = THREAD_CURRENT_THREAD;
      if (0 && !qi->qi_trx->lt_locks)
	{
	  dk_set_push (&it->it_waiting_hi_fill, (void*) self);
	  LEAVE_HIC;
	  semaphore_enter (self->thr_sem);
	  IN_HIC;
	  return HI_RETRY;
	}
      else
      */
	return HI_PRIVATE;
    }
  it->it_hi_reuses++;
  return HI_OK;
}


#ifdef NEW_HASH
static void
it_hi_bpages_read_ahead (query_instance_t * qi, index_tree_t * it)
{
  it_cursor_t *itc;
  ra_req_t *ra=NULL;
  int quota, inx, n_pages;
  hash_index_t *hi = it->it_hi;

  itc = itc_create (NULL, qi->qi_trx);
  itc_from_it (itc, it);
  quota = itc_ra_quota (itc);
  if (quota < 10)
    {
      itc_free (itc);
      return;
    }
  quota = MIN (quota, RA_MAX_BATCH);
  ra=(ra_req_t *)dk_alloc_box(sizeof(ra_req_t),DV_CUSTOM);
  memset (ra, 0, sizeof (*ra));
  ra->ra_nsiblings=1;

  n_pages = box_length (hi->hi_buckets) / sizeof (dp_addr_t);
  for (inx = 0; inx < n_pages && ra->ra_fill < quota; inx++)
    {
      if (hi->hi_buckets[inx])
	{
	  ra->ra_dp[ra->ra_fill] = hi->hi_buckets[inx];
	  ra->ra_fill++;
	}
    }

  itc_read_ahead_blob (itc, ra);
  itc_free (itc);
}


static long tc_hi_lock_new_lock = 0;
static long tc_hi_lock_old_dp_no_lock = 0;
static long tc_hi_lock_old_dp_no_lock_deadlock = 0;
static long tc_hi_lock_old_dp_no_lock_put_lock = 0;
static long tc_hi_lock_lock = 0;
static long tc_hi_lock_lock_deadlock = 0;

static void
it_hi_set_page_lock (query_instance_t * qi, it_cursor_t *itc, dp_addr_t dp)
{
  dp_addr_t phys;
  index_space_t * bisp;
  buffer_desc_t *buf;
  page_lock_t *pl;

  ITC_IN_MAP (itc);
  pl = IT_DP_PL (itc->itc_tree, dp);
  buf = isp_locate_page (itc->itc_space, dp, &bisp, &phys);

  itc->itc_page = dp;

  if (!pl && !buf)
    {
 /*     itc->itc_lock_mode = PL_EXCLUSIVE | PL_PAGE_LOCK;*/
      itc_make_pl (itc, NULL);
      PL_SET_FLAG (itc->itc_pl, PL_PAGE_LOCK);
      itc->itc_pl->pl_owner = qi->qi_trx;
      tc_hi_lock_new_lock += 1;
    }
  else if (!pl && buf)
    {
      buf = NULL;
      page_wait_access (itc, itc->itc_page, NULL, NULL, &buf, PA_WRITE, RWG_WAIT_ANY);
      ITC_IN_MAP (itc);
      tc_hi_lock_old_dp_no_lock += 1;
      if (!buf || buf == PF_OF_DELETED)
	{
	  itc->itc_ltrx->lt_error = LTE_DEADLOCK;
	  tc_hi_lock_old_dp_no_lock_deadlock += 1;
	  itc_bust_this_trx (itc, NULL, ITC_BUST_THROW);
	}
      ITC_FIND_PL (itc, buf);
      if (itc->itc_pl)
	goto normal_wait;
      tc_hi_lock_old_dp_no_lock_put_lock += 1;
/*      itc->itc_lock_mode = PL_EXCLUSIVE | PL_PAGE_LOCK;*/
      itc_make_pl (itc, buf);
      PL_SET_FLAG (itc->itc_pl, PL_PAGE_LOCK);
      itc->itc_pl->pl_owner = qi->qi_trx;
      page_leave_inner (buf);
    }
  else if (pl)
    {
      tc_hi_lock_lock += 1;
      page_wait_access (itc, itc->itc_page, NULL, NULL, &buf, PA_WRITE, RWG_WAIT_ANY);
      if (!buf || buf == PF_OF_DELETED)
	{
	  itc->itc_ltrx->lt_error = LTE_DEADLOCK;
	  tc_hi_lock_old_dp_no_lock_deadlock += 1;
	  itc_bust_this_trx (itc, NULL, ITC_BUST_THROW);
	}
      ITC_FIND_PL (itc, buf);
      ITC_IN_MAP (itc);
normal_wait:
 /*     itc->itc_lock_mode = PL_EXCLUSIVE;*/
      itc->itc_page = dp;
      itc->itc_n_lock_escalations = 10; /* arbitrary quantity, will cause the itc to prefer page locks when can */
      itc->itc_position = SHORT_REF (buf->bd_buffer + DP_FIRST);
      itc->itc_is_on_row = 1;
      do
	{
	  key_id_t key_id = SHORT_REF (buf->bd_buffer + itc->itc_position + IE_KEY_ID);
	  if (key_id != 0 && key_id != KI_LEFT_DUMMY)
	    {
	      if (WAIT_RESET == itc_set_lock_on_row (itc, &buf))
		{
		  itc->itc_ltrx->lt_error = LTE_DEADLOCK;
		  tc_hi_lock_lock_deadlock += 1;
		  itc_bust_this_trx (itc, &buf, ITC_BUST_THROW);
		}
	  ITC_IN_MAP (itc);
	  if (itc->itc_pl && PL_IS_PAGE (itc->itc_pl))
	    break;
	    }
	  itc_skip_entry (itc, buf->bd_buffer);
	}
      while (itc->itc_position);
      ITC_IN_MAP (itc);
      page_leave_inner (buf);
    }
}


static void
it_hi_bpages_set_locks (query_instance_t * qi, index_tree_t * it)
{
  hash_index_t *hi;

  hi = it->it_hi;
  if (qi->qi_trx->lt_is_excl
      || (hi->hi_lock_mode == PL_SHARED && hi->hi_isolation < ISO_REPEATABLE))
    return;

  if (hi->hi_source_pages && hi->hi_source_pages->ht_count > 0)
    {
      it_cursor_t itc_auto, *itc = &itc_auto;
      dk_hash_iterator_t hit;
      ptrlong dp, dummy;

      ITC_INIT (itc, NULL, qi->qi_trx);
      itc_from_it (itc, hi->hi_source_tree);
      itc->itc_lock_mode = hi->hi_lock_mode;
      itc->itc_isolation = hi->hi_isolation;
      ITC_IN_MAP (itc);
      dk_hash_iterator (&hit, hi->hi_source_pages);
      ITC_FAIL (itc)
	{
	  while (dk_hit_next (&hit, (void **) &dp, (void **) &dummy))
	    it_hi_set_page_lock (qi, itc, (dp_addr_t)dp);
	}
      ITC_FAILED
	{
	}
      END_FAIL (itc);
      ITC_LEAVE_MAP (itc);
      itc_free (itc);
    }
}
#endif


void
it_hi_filled (query_instance_t * qi, index_tree_t * it, state_slot_t *ins_itc)
{
  caddr_t * qst = (caddr_t*) qi;
  it_cursor_t * itc = (it_cursor_t *) QST_GET_V (qst, ins_itc);
  if (itc)
    {
      /* drop the wire down ref to the last buffer being inserted */
      itc_free (itc);
      qst[ins_itc->ssl_index] = NULL;
    }
  IN_HIC;
  if (it->it_shared == HI_FILL)
    it->it_shared = HI_OK;
  while (it->it_waiting_hi_fill)
    {
      du_thread_t * thr = (du_thread_t *) dk_set_pop (&it->it_waiting_hi_fill);
      semaphore_leave (thr->thr_sem);
    }
  LEAVE_HIC;
}


void
hash_call_fill (fun_ref_node_t * fref, caddr_t * qst, index_tree_t * it)
{
  state_slot_t * volatile ssl = fref->fnr_setp->setp_ha->ha_tree;
  query_instance_t * volatile qi = (query_instance_t *) qst;
  QR_RESET_CTX_T (qi->qi_thread)
    {
      qn_input (fref->fnr_select, qst, qst);
    }
  QR_RESET_CODE
    {
      it_cursor_t * ins_itc = (it_cursor_t *) QST_GET_V (qst, fref->fnr_setp->setp_ha->ha_insert_itc);
      if (ins_itc)
	{
	  itc_free (ins_itc);
	  qst[fref->fnr_setp->setp_ha->ha_insert_itc->ssl_index] = NULL;
	}
      POP_QR_RESET;
      if (it->it_hi_signature)
	it_hi_invalidate (it, 0);  /* DROPS REF COUNT */
      else
	it_temp_free (it);
      ((caddr_t*) qi)[ssl->ssl_index] = NULL;
      longjmp_splice (THREAD_CURRENT_THREAD->thr_reset_ctx, RST_ERROR);
    }
  END_QR_RESET;
  it_hi_filled (qi, it, fref->fnr_setp->setp_ha->ha_insert_itc);
}


int
hic_pop_oldest_it (index_tree_t *calling_it)
{
  id_hash_iterator_t hit;
  void **key;
  index_tree_t **it, *best_it = NULL;

  IN_HIC;
  id_hash_iterator (&hit, hash_index_cache.hic_hashes);
  while (hit_next (&hit, (char **) &key, (char **) &it))
    {
      if (it && *it && *it != calling_it && (*it)->it_shared == HI_OK && !(*it)->it_ref_count &&
	  (!best_it ||
	   (*it)->it_last_used < best_it->it_last_used))
	{
	  best_it = *it;
	}
    }
  if (best_it)
    {
      set_dbg_fprintf (("invalidating hash\n"));
      best_it->it_ref_count++;
      it_hi_invalidate (best_it, 1);
      return 1;
    }
  else
    {
      LEAVE_HIC;
      set_dbg_fprintf (("no hash to free\n"));
      return 0;
    }
}

/*
#ifdef NEW_HASH
#define HA_N_PAGES(ha) \
	(((ha)->ha_row_size + 10) * (ha)->ha_row_count / PAGE_DATA_SZ + HI_INIT_SIZE / HE_BPTR_PER_PAGE + 1)
#else*/
#define HA_N_PAGES(ha) \
	(((ha)->ha_row_size + 10) * (ha)->ha_row_count / PAGE_DATA_SZ)
/*#endif*/

int
hash_temp_reclaim_space (hash_area_t * ha, index_tree_t * it)
{
  dbe_storage_t *dbs = it->it_storage;
  long ha_n_pages = HA_N_PAGES (ha);

  while (((long) dbs->dbs_n_free_pages) - ha_n_pages < 0)
    {
      if (((short) (dbs->dbs_n_pages * 100 / wi_inst.wi_master->dbs_n_pages)) <
	  wi_inst.wi_temp_allocation_pct)
	{
	  set_dbg_fprintf (("pct greater - will not free\n"));
	  return 0;
	}

      if (!hic_pop_oldest_it (it))
	return 0;
    }
  return 1;
}


void
hash_fill_node_input (fun_ref_node_t * fref, caddr_t * inst, caddr_t * qst)
{
  int rc = HI_PRIVATE;
  hi_signature_t * hsi = fref->fnr_hi_signature;
  hash_area_t * ha = fref->fnr_setp->setp_ha;
  state_slot_t * tree_ssl = ha->ha_tree;
  index_tree_t * it = (index_tree_t *) QST_GET_V (qst, tree_ssl);
  query_instance_t *qi = (query_instance_t *)qst;
#ifdef NEW_HASH
  union {
    char hsi_auto_buf [sizeof (hi_signature_t) + 20];
    caddr_t dummy;
  } hsi_auto_union;
  caddr_t hsi_auto;
  char hsi_lock_mode;
#endif

  IN_HIC;
  if (it)
    {
      if (HI_OK == it->it_shared)
	{
	  LEAVE_HIC;
	  qn_send_output ((data_source_t *) fref, qst);
	  return;
	}
      it_temp_free (it);
      qst_set (qst, tree_ssl, NULL);
      it = NULL;
    }

#ifdef NEW_HASH
  BOX_AUTO (hsi_auto, hsi_auto_union.hsi_auto_buf, sizeof (hi_signature_t), DV_ARRAY_OF_POINTER);
  memcpy (hsi_auto, hsi, sizeof (hi_signature_t));
  hsi = (hi_signature_t *) hsi_auto;
  hsi->hsi_isolation = box_num (qi->qi_isolation);
  if (qi->qi_query && qi->qi_query->qr_select_node &&
      qi->qi_query->qr_lock_mode != PL_EXCLUSIVE)
    hsi_lock_mode = qi->qi_lock_mode;
  else
    hsi_lock_mode = PL_EXCLUSIVE;
#endif
  for (;;)
    {
      index_tree_t ** place = (index_tree_t **) id_hash_get (hash_index_cache.hic_hashes, (caddr_t) &hsi);
      if (place)
	{
	  it = *place;
	  rc = it_hash_wait_access (it, qst);
	  if (HI_OK == rc)
	    {
	      it->it_ref_count++;
	      break;
	    }
	  if (HI_RETRY == rc)
	    continue;
	  if (HI_PRIVATE == rc)
	    {
	      it = NULL;
	      break;
	    }
	}
      else
	{
	  it = NULL;
	  rc = HI_FILL;
	  break;
	}
    }
  if (!it)
    {
      index_tree_t *prev_it;
      it = it_temp_allocate (wi_inst.wi_temp);
      it->it_hi = hi_allocate ((int) MIN (ha->ha_row_count, (long) INT_MAX), (HA_FILL != ha->ha_op));
      it->it_key = fref->fnr_setp->setp_ha->ha_key;
#ifdef NEW_HASH
      it->it_hi->hi_isolation = (char) unbox (hsi->hsi_isolation);
      it->it_hi->hi_lock_mode = hsi_lock_mode;
#endif
      if (HI_PRIVATE == rc)
	{
	  it->it_shared = HI_PRIVATE;
	}
      else
	{
	  it->it_shared = HI_FILL;
	  it->it_hi_signature = (hi_signature_t *) box_copy_tree ((caddr_t) hsi);
	  id_hash_set (hash_index_cache.hic_hashes, (caddr_t) &it->it_hi_signature, (caddr_t) &it);
	  it_hi_set_sensitive (it);
	  L2_PUSH (hash_index_cache.hic_first, hash_index_cache.hic_last, it, it_hic_);
	  it->it_ref_count = 1;
	}
      prev_it = (index_tree_t *) qst_get (qst, tree_ssl);
      if (prev_it)
	{
	  it_temp_free (it);
	  QST_GET_V(qst,tree_ssl) = NULL;
	}
      qst_set (qst, tree_ssl, (caddr_t) it);
      LEAVE_HIC;
#ifdef NEW_HASH
      dk_free_box (hsi->hsi_isolation);
      BOX_DONE (hsi_auto, hsi_auto_union.hsi_auto_buf);
#endif
      it->it_last_used = get_msec_real_time ();
      hash_temp_reclaim_space (ha, it);
      hash_call_fill (fref, qst, it);
      it->it_key = NULL;
    }
  else
    {
      LEAVE_HIC;
#ifdef NEW_HASH
      dk_free_box (hsi->hsi_isolation);
      BOX_DONE (hsi_auto, hsi_auto_union.hsi_auto_buf);

      it_hi_bpages_set_locks (qi, it);
      it_hi_bpages_read_ahead (qi, it);
#endif
      qst_set (qst, fref->fnr_setp->setp_ha->ha_tree, (caddr_t) it);
    }
  it->it_last_used = get_msec_real_time ();
  qn_send_output ((data_source_t *) fref, qst);
}


void
it_hi_invalidate (index_tree_t * it, int in_hic)
{
  /* the official function for freeing a shared hi.  The it's ref count must be incremented by the calling thread. If this is == 1 the tree is actually freed, else the last to leave frees */
  hi_signature_t *hic = NULL;
  hic = it->it_hi_signature;
  if (hic)
    {
      if (!in_hic)
	IN_HIC;
      it->it_shared = HI_OBSOLETE;
      id_hash_remove (hash_index_cache.hic_hashes, (caddr_t) &it->it_hi_signature);
      L2_DELETE (hash_index_cache.hic_first, hash_index_cache.hic_last, it, it_hic_);
      it_hi_clear_sensitive (it);
      while (it->it_waiting_hi_fill)
	{
	  du_thread_t * thr = (du_thread_t *) dk_set_pop (&it->it_waiting_hi_fill);
	  semaphore_leave (thr->thr_sem);
	}
      hic = it->it_hi_signature;
      it->it_hi_signature = NULL;
      LEAVE_HIC;
      dk_free_tree ((caddr_t) hic);
    }
  it_temp_free (it);
}


dk_set_t
upd_hi_pre (update_node_t * upd, query_instance_t * qi)
{
  lock_trx_t * lt = qi->qi_trx;
  dk_set_t hi_list;
  int inx;
  if (!lt->lt_upd_hi)
    lt->lt_upd_hi = hash_table_allocate (21);
  hi_list = (dk_set_t) gethash ((void*) (ptrlong) upd->upd_hi_id, lt->lt_upd_hi);
  if (-1 == (ptrlong) hi_list)
    return NULL;

  {
    dk_set_t effect = NULL;
    dk_set_t deps;
    int n_cols;
    IN_HIC;
    if (!upd->upd_cols_param)
      {
	n_cols = BOX_ELEMENTS (upd->upd_col_ids);
	for (inx = 0; inx < n_cols; inx++)
	  {
	    oid_t col_id = upd->upd_col_ids[inx];
	    deps = (dk_set_t) gethash ((void*) (ptrlong) col_id, hash_index_cache.hic_col_to_it);
	    DO_SET (index_tree_t *, it, &deps)
	      {
		dk_set_pushnew (&effect, (void*) it);
	      }
	    END_DO_SET();
	  }
	DO_SET (index_tree_t *, it, &effect)
	  {
	    if (!dk_set_member (lt->lt_hi_delta, (void*) it))
	      {
		dk_set_push (&lt->lt_hi_delta, (void*) -1);
		dk_set_push (&lt->lt_hi_delta, (void*) it);
		it->it_ref_count++;
	      }
	  }
	END_DO_SET();
	dk_set_free (effect);
	effect = (dk_set_t) -1;
	sethash ((void*) (ptrlong) upd->upd_hi_id, lt->lt_upd_hi, (void*) effect);
      }
    LEAVE_HIC;
  }
  return NULL;
}


void
lt_hi_row_change (lock_trx_t * lt, key_id_t key_id, int log_op, db_buf_t log_entry)
{
  dk_set_t effect = NULL;
  IN_HIC;
  effect = (dk_set_t) gethash ((void*)(ptrlong)key_id, hash_index_cache.hic_pk_to_it);
  DO_SET (index_tree_t *, it, &effect)
    {
      if (!dk_set_member (lt->lt_hi_delta, (void*) it))
	{
	  dk_set_push (&lt->lt_hi_delta, (void*) -1);
	  dk_set_push (&lt->lt_hi_delta, (void*) it);
	  it->it_ref_count++;
	}
    }
  END_DO_SET();
  LEAVE_HIC;
}



void
lt_hi_transact (lock_trx_t * lt, int op)
{
  dk_set_t delta = lt->lt_hi_delta;
  for (delta = lt->lt_hi_delta; delta; delta = delta->next->next)
    {
      index_tree_t *it = (index_tree_t*) delta->data;
      if (it)
	{
	  if (it->it_hi_signature)
	    it_hi_invalidate ((index_tree_t*) delta->data, 0);
	  else
	    it_temp_free (it);
	}
    }
  dk_set_free (lt->lt_hi_delta);
  lt->lt_hi_delta = NULL;
  if (lt->lt_upd_hi)
    {
      hash_table_free (lt->lt_upd_hi);
      lt->lt_upd_hi = NULL;
    }
}


void
hic_clear ()
{
  index_tree_t ** p_it;
  caddr_t p_key;
  id_hash_iterator_t hit;

  IN_HIC;

next_pass:
  id_hash_iterator (&hit, hash_index_cache.hic_hashes);
  while (hit_next (&hit, &p_key, (caddr_t*) &p_it))
    {
      index_tree_t * it = *p_it;
      if (!it->it_ref_count)
	{
	  it->it_ref_count++;
	  it_hi_invalidate (it, 1);
	  IN_HIC;
	  goto next_pass;
	}
    }

  LEAVE_HIC;
}


#ifdef NEW_HASH
void
itc_hi_source_page_used (it_cursor_t * itc, dp_addr_t dp)
{
  if (itc->itc_ks && itc->itc_ks->ks_ha && itc->itc_out_state)
    {
      index_tree_t * it = (index_tree_t *) QST_GET_V (itc->itc_out_state, itc->itc_ks->ks_ha->ha_tree);
      if (it->it_hi->hi_source_pages && !gethash (DP_ADDR2VOID (dp), it->it_hi->hi_source_pages))
	{
	  if (itc->itc_tree && !it->it_hi->hi_source_tree)
	    it->it_hi->hi_source_tree = itc->itc_tree;
	  sethash (DP_ADDR2VOID (dp), it->it_hi->hi_source_pages, (void *) (ptrlong) 1);
	}
    }
}
#endif


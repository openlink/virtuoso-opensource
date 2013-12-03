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
#include "mhash.h"

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
#define HI_MAX_SIZE (4000000 * HE_BPTR_PER_PAGE)
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
long hi_end_memcache_size = 1100000;
int enable_mem_hash_join = 1;
long tc_slow_temp_insert;
long tc_slow_temp_lookup;

#define HA_MEMCACHE(ha) \
  (HA_PROC_FILL == ha->ha_op ? 0 : HA_FILL == ha->ha_op ? enable_mem_hash_join : \
   HA_GROUP == ha->ha_op ? 1 : 0)

#define set_dbg_fprintf(x)
#define retr_dbg_fprintf(x)


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
  hash_area_t * ha = hmk2->hmk_ha;
  /* note that hmk1 has a null hmk_ha.  reused hinxes  can outlive the ha, so use the ha of the lookup hmk */
  if (hmk1->hmk_hash != hmk2->hmk_hash)
    return 0;
  for (idx = 0; idx < ha->ha_n_keys; idx++)
    {
      caddr_t fld1 = hmk1->hmk_data[idx];
      collation_t *cl = ha->ha_key_cols[idx].cl_sqt.sqt_collation;
      caddr_t fld2 = hmk2->hmk_data[idx];
      if (DVC_MATCH != cmp_boxes (fld1, fld2, cl, cl))
	{
	  if ((DV_DB_NULL == DV_TYPE_OF (fld1)) && (DV_DB_NULL == DV_TYPE_OF (fld2)))
	    continue;
	  return 0;
	}
    }
  return 1;
}


#ifdef NEW_HASH
void
HI_BUCKET_PTR (hash_index_t *hi, uint32 code, it_cursor_t *itc, hash_inx_b_ptr_t *hibp, int mode)
{
  dp_addr_t hi_bucket_page = HI_BUCKET_PTR_PAGE (hi, code);
  unsigned short ofs = (unsigned short) (((code % hi->hi_size) % HE_BPTR_PER_PAGE) * BKT_ELEM_SIZE);
  buffer_desc_t *hb_buf = NULL;
#if defined (NEW_HASH_NEED_ALIGN)
  int32 l_buf;
#endif

  if (!hi_bucket_page)
    {
      hibp->hibp_page = 0;
      hibp->hibp_pos = 0;
      return;
    }
  else
    {
      itc->itc_page = hi_bucket_page;
      ITC_IN_KNOWN_MAP (itc, hi_bucket_page);
      page_wait_access (itc, hi_bucket_page, NULL, &hb_buf, PA_READ, RWG_WAIT_ANY);
    }
#if !defined (NEW_HASH_NEED_ALIGN)
  hibp->hibp_page = LONG_REF (hb_buf->bd_buffer + DP_DATA + ofs);
#else
  memcpy (&l_buf, hb_buf->bd_buffer + DP_DATA + ofs, sizeof (int32));
  hibp->hibp_page = LONG_REF (&l_buf);
#endif
  hibp->hibp_pos = SHORT_REF (hb_buf->bd_buffer + DP_DATA + ofs + sizeof (dp_addr_t));

  page_leave_outside_map (hb_buf);
}
#endif


index_tree_t *
qst_tree (caddr_t * inst, state_slot_t * ssl, state_slot_t * set_no_ssl)
{
  if (!set_no_ssl || SSL_VEC != ssl->ssl_type)
    return (index_tree_t*)QST_GET (inst, ssl);
  else
    {
      QNCAST (query_instance_t, qi, inst);
      int set = qst_vec_get_int64 (inst, set_no_ssl, qi->qi_set);
      data_col_t * dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
      if (set >= dc->dc_n_values)
	return NULL;
      return ((index_tree_t**)dc->dc_values)[set];
    }
}


void
qst_set_tree (caddr_t * inst, state_slot_t * ssl, state_slot_t * set_no_ssl, index_tree_t * tree)
{
  if (!set_no_ssl || SSL_VEC != ssl->ssl_type)
    qst_set (inst, ssl, (caddr_t)tree);
  else
    {
      QNCAST (query_instance_t, qi, inst);
      int save = qi->qi_set;
      qi->qi_set = qst_vec_get_int64 (inst, set_no_ssl, save);
      qst_vec_set (inst, ssl, (caddr_t)tree);
      qi->qi_set = save;
    }
}


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
  if (!hi->hi_size) GPF_T1 ("0 hi_size is not possible");
  hi->hi_buckets = (dp_addr_t *)
      dk_alloc_box (he_inx * sizeof (dp_addr_t), DV_CUSTOM);
  memset (hi->hi_buckets, 0, he_inx * sizeof (dp_addr_t));
  hi->hi_source_pages = hash_table_allocate (201);
#endif
}


hash_index_t *
hi_allocate (unsigned int32 sz, int use_memcache, hash_area_t * ha)
{
  NEW_VARZ (hash_index_t, hi);
  if ((HA_FILL == ha->ha_op && enable_chash_join && ha->ha_ch_len)
      || (HA_GROUP == ha->ha_op && HI_CHASH == use_memcache && ha->ha_ch_len))
    return hi;
  if (!sz)
    sz = HI_INIT_SIZE;
  hi->hi_size = sz;
  if (HA_DISTINCT == ha->ha_op || (use_memcache && sz < hi_end_memcache_size)
      || ha->ha_memcache_only)
    {
      if (HA_FILL == ha->ha_op || HI_CHASH == use_memcache)
	{
	  hi->hi_pool = mem_pool_alloc ();
	}
      else
	{
	hi->hi_memcache = id_hash_allocate (509,
	    sizeof (hi_memcache_key_t), sizeof (caddr_t *), hi_memcache_hash, hi_memcache_cmp);
	  hi->hi_memcache_from_mp = 0;
	}
      if (hi->hi_memcache)
	id_hash_set_rehash_pct (hi->hi_memcache, 120);
    }
  else
    hi_alloc_elements (hi);
  if (!hi->hi_size) GPF_T1 ("0 size hi is not possible");
  return hi;
}


void
hi_free (hash_index_t * hi)
{
  if (hi->hi_chash)
    {
      cha_free (hi->hi_chash);
      hi->hi_pool = NULL;
      if (hi->hi_thread_cha)
	hash_table_free (hi->hi_thread_cha);
    }
  if (hi->hi_memcache)
    {
      if (hi->hi_pool)
	{
	  mp_free (hi->hi_pool);
	  hi->hi_pool = NULL;
	}
      else if (!hi->hi_memcache_from_mp)
	{
	  hi_memcache_key_t *key;
	  caddr_t **val;
	  id_hash_iterator_t hit;
	  id_hash_iterator (&hit, hi->hi_memcache);
	  while (hit_next (&hit, (caddr_t *)(&key), (caddr_t *)(&val)))
	    {
	      caddr_t * dep = ((caddr_t**) val)[0];
	      dk_free_tree ((caddr_t)(key->hmk_data));
	      while (DV_ARRAY_OF_POINTER == DV_TYPE_OF (dep))
		{
		  int len = BOX_ELEMENTS (dep);
		  caddr_t * next_dep;
		  if (!len)
		    break;
		  next_dep = ((caddr_t**)dep)[len - 1];
		  dep[len - 1] = NULL;
		  dk_free_tree ((box_t) dep);
		  dep = next_dep;
		}
	      dk_free_tree (dep);
	    }
	  id_hash_clear (hi->hi_memcache);
	  id_hash_free (hi->hi_memcache);
	  hi->hi_memcache = NULL;
	}
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
  hi2 = hi_allocate (new_sz, 0, NULL /* When in rehash, memcache is already dead */);
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
#if defined (NEW_HASH_NEED_ALIGN)
  int32 l_buf;
#endif

  hi->hi_count++;
  if (!hi_bucket_page)
    {
      hb_buf = it_new_page (itc->itc_tree, 0, DPF_HASH, 0, 0);
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
      ITC_IN_KNOWN_MAP (itc, hi_bucket_page);
      page_wait_access (itc, hi_bucket_page, NULL, &hb_buf, PA_WRITE, RWG_WAIT_ANY);
      set_dbg_fprintf ((stdout, "hi_bp_set:old bp: page=%lu\n", (unsigned long) hb_buf->bd_page));
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

  page_leave_outside_map (hb_buf);
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

  /*NOTREACHED*/
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

#define CL_INT(cl, row) \
  (DV_SHORT_INT == cl.cl_sqt.sqt_dtp ? (int32) *(short*)(row + cl.cl_pos[0]) \
   : (DV_INT64 == cl.cl_sqt.sqt_dtp ? INT64_REF (row + cl.cl_pos[0]) \
      : LONG_REF (row + cl.cl_pos[0])))

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
key_hash_box (caddr_t box, dtp_t dtp, uint32 code, int * var_len, collation_t * collation, dtp_t col_dtp, int allow_shorten_any)
{
  int inx2;
  long len;
  if (col_dtp == DV_ANY && dtp != DV_DB_NULL)
    { /* if it goes to column of type ANY the length to be written is the serialized length */
      caddr_t err = NULL;
      caddr_t any_ser;
      uint32 ret;
      if (allow_shorten_any)
        any_ser = box_to_shorten_any (box, &err);
      else
        any_ser = box_to_any_1 (box, &err, NULL, DKS_TO_HA_DISK_ROW);
      if (err)
	sqlr_resignal (err);
      if (DV_TYPE_OF (any_ser) != DV_STRING)
	GPF_T1 ("any disk image not a string");

      ret = key_hash_box (any_ser, DV_STRING, code, var_len, collation, DV_STRING, allow_shorten_any);
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
	int64 v64 = unbox (box);
	int32 v = (int32)v64;
	if (v)
	  code = (code * v) ^ (code >> 23);
	else
	  code = code << 2 | code >> 30;
	if (v64 != v)
	  code = code ^ (uint32)(v64 >> 32);
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
	    code = key_hash_box (x, DV_TYPE_OF (x), code, &d, collation, DV_TYPE_OF (x), allow_shorten_any);
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
  MHASH_VAR (code, box, len);
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
  if ((target_dtp == DV_INT64 && dtp == DV_LONG_INT)
      || (DV_IRI_ID_8 == target_dtp && DV_IRI_ID == dtp))
    return data;
  if (DV_DATE == target_dtp && DV_DATETIME == dtp)
    {
      dt_date_round (data);
      return data;
    }
  if (SSL_CONSTANT == ssl->ssl_type)
#ifndef NDEBUG
    GPF_T1 ("constant ssl in hash_cast");
#else
    sqlr_new_error ("42000", ".....", "constant ssl in hash_cast, please report statement compiled");
#endif
  if (IS_BLOB_DTP (target_dtp))
    target_dtp = DV_BLOB_INLINE_DTP (target_dtp);  /* non blob value for blob col. Will be inlined */
  data = box_cast_to (qst, data, dtp,
		      target_dtp, sqt->sqt_precision, sqt->sqt_scale, &err);
  if (err)
    sqlr_resignal (err);
  if (!(SSL_VEC == ssl->ssl_type ||  SSL_REF == ssl->ssl_type))
  qst_set (qst, ssl, data);
  else
    vec_qst_set_temp_box (qst, ssl, data);
  return data;
}

void
hash_row_set_col (row_delta_t * rd, row_fill_t * rf, dbe_col_loc_t *cl, caddr_t value, int feed_temp_blobs)
{
  caddr_t err = NULL;
  rd->rd_itc->itc_search_par_fill = 0;
  rd->rd_non_comp_max = rf->rf_space;
  rd->rd_any_ser_flags = DKS_TO_HA_DISK_ROW ;
  if (!feed_temp_blobs)
    row_insert_cast_temp (rd, cl, value, &err, NULL);
  else
    row_insert_cast (rd, cl, value, &err, NULL);
  if (err)
    sqlr_resignal (err);
  row_set_col (rf, cl, rd->rd_itc->itc_search_params[0]);
  itc_free_owned_params (rd->rd_itc);
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
  int row_len, key_len;
  int inx;
  int hmk_data_els = ((NULL != hmk_data) ? BOX_ELEMENTS (hmk_data) : 0);
  hash_index_t * hi = tree->it_hi;
  short hb_fill = hi->hi_hash_buf_fill;
  buffer_desc_t * hash_buf = itc->itc_hash_buf;
  query_instance_t *qi = (query_instance_t *)qst;
#ifdef NEW_HASH
  it_cursor_t * bp_ref_itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_bp_ref_itc);
  unsigned short code_mask;
  hash_inx_b_ptr_t hibp_buf;
  row_delta_t rd;
  LOCAL_RF (rf, 0, 0, key);
  rf.rf_pf_hash = NULL;
  memset (&rd, 0, sizeof (rd));
  rd.rd_allocated = RD_AUTO;
  rd.rd_itc = itc;
  rd.rd_key = ha->ha_key;
  if (HA_PROC_FILL == ha->ha_op || HA_GROUP == ha->ha_op)
    rd.rd_any_ser_flags = DKS_TO_HA_DISK_ROW;
  TC (tc_slow_temp_insert);
  if (!bp_ref_itc)
    {
      bp_ref_itc = itc_create (NULL, qi->qi_trx);
      qst_set (qst, ha->ha_bp_ref_itc, (caddr_t) bp_ref_itc);
    }
  itc_from_it (bp_ref_itc, tree);
  if (!hibp)
    {
      HI_BUCKET_PTR (tree->it_hi, code, bp_ref_itc, &hibp_buf, PA_WRITE);
      hibp = &hibp_buf;
    }
#endif

  key_len = key->key_row_len[0];
  if (key_len > 0)
    row_len = key_len;
  else
    {
      int var_len_org = var_len;
      rd.rd_non_comp_max = MAX_ROW_BYTES;
      if (THR_IS_STACK_OVERFLOW (THREAD_CURRENT_THREAD, &hm_val, (PAGE_DATA_SZ+2000)))
        sqlr_new_error ("42000", "SR483", "Stack Overflow");
    try_with_blobs_outlined:
      rd.rd_non_comp_len = var_len + key->key_row_var_start[0];
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
	      caddr_t val_copy;
	      caddr_t *value_ptr = ((inx < hmk_data_els) ? hmk_data+inx : hm_val+(inx-hmk_data_els));
	      value = value_ptr[0];
	      if (SSL_VEC == ssl->ssl_type || SSL_REF == ssl->ssl_type)
		vec_qst_set_temp_box (qst, ssl, val_copy = box_copy_tree (value));
	      else
		qst_set (qst, ssl, val_copy = box_copy_tree (value));
	      dtp = DV_TYPE_OF (value);
	      if (dtp != target_dtp)
		{
		  value = hash_cast ((query_instance_t *) qst, ha, inx, ssl, val_copy);
	          dtp = DV_TYPE_OF (value);
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
	  if ((feed_temp_blobs || !IS_INLINEABLE_DTP (cl->cl_sqt.sqt_dtp))
	      && IS_BLOB_DTP (cl->cl_sqt.sqt_dtp) && !cl->cl_sqt.sqt_is_xml
	      && ! IS_BLOB_HANDLE_DTP (dtp) && DV_DB_NULL != dtp)
	    dtp = DV_BLOB_HANDLE_DTP_FOR_BLOB_DTP (DV_BLOB_DTP_FOR_INLINE_DTP (dtp));

	  if (dtp != DV_DB_NULL &&
	      (cl->cl_sqt.sqt_dtp == DV_ANY ||
	       cl->cl_sqt.sqt_dtp == DV_OBJECT))
	    {
	      caddr_t err = NULL;
	      caddr_t serialized_value = box_to_any_1 (value, &err, NULL, rd.rd_any_ser_flags);
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
	      && ! IS_BLOB_HANDLE_DTP (dtp)
	      && DV_DB_NULL != dtp)
	    len++; /* non-blob for a blob col is 1 longer because of the inlined leading tag byte */

	  var_len += len;
	}
      row_len = key->key_row_var_start[0] + var_len;
      if (!feed_temp_blobs && row_len > MAX_ROW_BYTES)
	{
	  var_len = var_len_org;
	  feed_temp_blobs = 1;
	  goto try_with_blobs_outlined;
	}
    }
  rf.rf_fill = key->key_row_var_start[0];
  row_len = ROW_ALIGN (row_len);
  if (row_len > MAX_HASH_TEMP_ROW_BYTES)
    sqlr_new_error ("22023", "SR319", "Max length of a temp row (%d)  exceeded", row_len);

  if (qi->qi_no_cast_error && HA_DISTINCT == ha->ha_op && row_len > MAX_ROW_BYTES)
    return; /* if it is too long, it is considered distinct and not remembered */
  if (itc->itc_hash_buf && itc->itc_hash_buf->bd_page != hi->hi_last_dp)
    {
      it_cursor_t * ref_itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_ref_itc);
      page_leave_outside_map (itc->itc_hash_buf);
      if (hi->hi_last_dp)
	{
	  if (ref_itc && ref_itc->itc_buf && ref_itc->itc_buf->bd_page == hi->hi_last_dp)
	    {
	      itc->itc_hash_buf = ref_itc->itc_buf;
	      ref_itc->itc_buf = NULL;
	    }
	  else
	    {
	      ITC_IN_KNOWN_MAP (itc, hi->hi_last_dp);
	      page_wait_access (itc, hi->hi_last_dp, NULL, &itc->itc_hash_buf, PA_WRITE, RWG_WAIT_ANY);
	      ITC_LEAVE_MAPS (itc);
	    }
	  hash_buf = itc->itc_hash_buf;
	}
      else
	hash_buf = itc->itc_hash_buf = NULL;
    }
  if (!hash_buf
      || hb_fill + row_len + HASH_HEAD_LEN > PAGE_SZ)
    {
      buffer_desc_t * new_buf = it_new_page (tree, 0, DPF_HASH, 0, 0);
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
	  page_leave_outside_map (hash_buf);
	}
      hash_buf = new_buf;
      itc->itc_hash_buf = new_buf;
      hi->hi_last_dp = new_buf->bd_page;
      hb_fill = DP_DATA;
    }
  LONG_SET (hash_buf->bd_buffer + hb_fill, hibp->hibp_page);
  hb_fill += HASH_HEAD_LEN;

  hash_row = hash_buf->bd_buffer + hb_fill;
  IE_ROW_VERSION (hash_row) = 0;
  IE_SET_KEY_VERSION (hash_row, 1);
  memset (hash_row + key->key_null_flag_start[0], 0, key->key_null_flag_bytes[0]);
  rf.rf_row = hash_row;
  rf.rf_space = row_len;

  set_dbg_fprintf ((stdout, "itc_ha_disk_row: code %lu next of page=%lu/ofs=%lu is at page=%lu/ofs=%lu code=%lu\n",
      (unsigned long) code,
      (unsigned long) hash_buf->bd_page,
      (unsigned long) hb_fill,
      (unsigned long) hibp->hibp_page,
      (unsigned long) hibp->hibp_pos,
      hibp->hibp_no));
  code_mask = (unsigned short) ((code >> 9) & 0x7);
  code_mask = code_mask << 13;
  SHORT_SET (hash_row + HH_NEXT_POS - HASH_HEAD_LEN, ((hibp->hibp_pos & 0x1FFF) | code_mask));

  hi_bp_set (tree->it_hi, bp_ref_itc, code, hash_buf->bd_page, hb_fill);
  rd.rd_non_comp_len = key->key_row_var_start[0];
  if (HA_GROUP == ha->ha_op)
    rd.rd_any_ser_flags = 0;
  itc_free_owned_params (itc);
  ITC_START_SEARCH_PARS (itc);
  for (inx = 0; ha->ha_key_cols[inx].cl_col_id; inx++)
    {
      state_slot_t * ssl  = ha->ha_slots[inx];
      caddr_t value;
      if (NULL != hmk_data)
	value = ((inx < hmk_data_els) ? hmk_data[inx]: hm_val[inx-hmk_data_els]);
      else
	value = QST_GET (qst, ssl);
      err = NULL;
      if (inx >= ha->ha_n_keys && HA_GROUP == ha->ha_op)
	rd.rd_any_ser_flags = DKS_TO_HA_DISK_ROW;
      hash_row_set_col (&rd, &rf, &ha->ha_key_cols[inx], value, feed_temp_blobs);

      if (err)
	sqlr_resignal (err);
    }
  if (row_len != ROW_ALIGN (rf.rf_fill))
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
      log_error ("Incorrect row length in hash space fill : row_len=%d, rf_fill=%d", row_len, rf.rf_fill);
      GPF_T1 ("Incorrect row length calculation in hash space fill");
    }
#ifdef OLD_HASH
  hi_add (tree->it_hi, code, hash_buf->bd_page, hb_fill);
#endif
  row_len = ROW_ALIGN (row_len);
  hi->hi_hash_buf_fill = hb_fill + row_len;
  if (hb_fill + row_len + HASH_HEAD_LEN < PAGE_SZ)
    page_write_gap (hash_buf->bd_buffer + hb_fill + row_len + HASH_HEAD_LEN, PAGE_SZ - (hb_fill + row_len + HASH_HEAD_LEN));
}


int
itc_ha_equal (it_cursor_t * itc, hash_area_t * ha, caddr_t * qst, db_buf_t hash_row, int allow_shorten_any)
{
  int b_len = 0;
  int inx;
#ifndef KEYCOMP
  int r_is_null
#endif

  for (inx = 0; inx < ha->ha_n_keys; inx++)
    {
      int h_off, h_len, h_is_null;
      dbe_col_loc_t * h_cl = &ha->ha_key_cols[inx];
      if (h_cl->cl_fixed_len > 0)
	{
	  h_off = h_cl->cl_pos[0];
	  h_len = h_cl->cl_fixed_len;
	}
      else
	KEY_PRESENT_VAR_COL (ha->ha_key, hash_row, (*h_cl), h_off, h_len);
      h_is_null = h_cl->cl_null_mask[0] &&
	(0 != (h_cl->cl_null_mask[0] & hash_row[h_cl->cl_null_flag[0]]));
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
              if (allow_shorten_any)
                any_val = box_to_shorten_any (value, &err);
              else
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
		  if (unbox_iri_id (value) == (iri_id_t)(uint32) LONG_REF(hash_row + h_off))
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
                  ssl->ssl_sqt.sqt_collation ) )
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
	  KEYCOMP;
#ifndef KEYCOMP
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
#endif
	}
    }
  return DVC_MATCH;
}


void
itc_from_it_ha (it_cursor_t * itc, index_tree_t * it, hash_area_t * ha)
{
  if (  itc->itc_tree == it)
    return;

  itc_from_it (itc, it);
  itc->itc_insert_key = ha->ha_key;
  itc->itc_row_key = ha->ha_key;
}

int
itc_ha_disk_find_new (it_cursor_t * itc, buffer_desc_t ** ret_buf, int * ret_pos,
	     hash_area_t * ha, caddr_t * qst, uint32 code, dp_addr_t he_page, short he_pos)
{
  index_tree_t * tree = qst_tree (qst, ha->ha_tree, ha->ha_set_no);
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
      qst_set (qst, ha->ha_ref_itc, (caddr_t) ref_itc);
    }
  itc_from_it_ha (ref_itc, tree, ha);
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
	      if (ref_itc->itc_buf)
		page_leave_outside_map (ref_itc->itc_buf);
	      ITC_IN_KNOWN_MAP (ref_itc, he_page);
	      page_wait_access (ref_itc, he_page, NULL, &h_buf, HA_DISTINCT == ha->ha_op ? PA_READ : PA_WRITE, RWG_WAIT_ANY);
	      ref_itc->itc_buf = h_buf;
	      ret_buf[0] = h_buf;
	    }
	  else
	    h_buf = ref_itc->itc_buf;
	}
      code_mask = (SHORT_REF (h_buf->bd_buffer + he_pos + HH_NEXT_POS - HASH_HEAD_LEN) >> 13) & 0x7;
      code_mask = code_mask << 9;
      if ((code & 0x0E00) == code_mask)
	{
	  if (DVC_MATCH == itc_ha_equal (itc, ha, qst, h_buf->bd_buffer + he_pos, (HA_DISTINCT == ha->ha_op)))
	    {
	      ret_buf[0] = h_buf;
	      ret_pos[0] = he_pos;
	      TC (tc_slow_temp_lookup);
	      return 1;
	    }
	}
#ifdef HASH_DEBUG
      he_prev_pages[1] = he_prev_pages[0];
      he_prev_pages[0] = he_page;
      he_prev_pos[1] = he_prev_pos[0];
      he_prev_pos[0] = he_pos;
#endif
      he_page = LONG_REF (h_buf->bd_buffer + he_pos + HH_NEXT_DP - HASH_HEAD_LEN);
      he_pos = SHORT_REF (h_buf->bd_buffer + he_pos + HH_NEXT_POS - HASH_HEAD_LEN) & 0x1fff;
      n_in_bucket += 1;
    } while (he_page);
  ret_pos[0] = 0;
  return 0;
}


void
mc_print (id_hash_t * memcache)
{
  hi_memcache_key_t *key;
  caddr_t **val;
  id_hash_iterator_t hit;
  if (!memcache)
    {
      printf ("no memcache\n");
      return;
    }
  id_hash_iterator (&hit, memcache);
  while (hit_next (&hit, (caddr_t *)(&key), (caddr_t *)(&val)))
    {
      sqlo_box_print ((caddr_t)key->hmk_data);
      printf (" -> ");
      sqlo_box_print ((caddr_t)val[0]);
    }
}


void
itc_ha_flush_memcache (hash_area_t * ha, caddr_t * qst, int is_in_fill)
{
  it_cursor_t * itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_insert_itc);
  index_tree_t * tree = SETP_HASH_FILL == is_in_fill ? qst_tree (qst, ha->ha_tree, ha->ha_set_no) : (index_tree_t*)qst_get (qst, ha->ha_tree);
  hash_index_t *hi;
  hi_memcache_key_t *key;
  caddr_t **val;
  id_hash_iterator_t hit;
  if (NULL == tree)
    return;
  hi = tree->it_hi;
  if (hi && hi->hi_chash)
    {
      if (SETP_NO_CHASH_FLUSH == is_in_fill)
	return;
      chash_to_memcache (qst, tree, ha);
      if (!itc)
	{
	  itc = itc_create (NULL, NULL);
	  qst_set (qst, ha->ha_insert_itc, (caddr_t) itc);
	}
      itc_from_it_ha (itc, tree, ha);
    }
  if ((NULL == hi) || (NULL == hi->hi_memcache))
    return;
  if (hi->hi_memcache->ht_count >= hi_end_memcache_size)
    hi->hi_size = MAX (hi->hi_size, 4 * hi_end_memcache_size); /* overflowed, more coming */
  else
    hi->hi_size = MAX (1, hi->hi_memcache->ht_count); /* this is all, flushing at end of query */
  if (!itc)
    {
      itc = itc_create (NULL, ((QI*)qst)->qi_trx);
      qst_set (qst, ha->ha_insert_itc, (caddr_t) itc);
      itc_from_it_ha (itc, tree, ha);
    }
  hi_alloc_elements (hi);
  id_hash_iterator (&hit, hi->hi_memcache);
  while (hit_next (&hit, (caddr_t *)(&key), (caddr_t *)(&val)))
    {
/* No feeding temp blobs here because they appear only when the ha is the result of a procedure.
For procedures, we have no memcache. */
      itc_ha_disk_row (itc, NULL, ha, qst, tree, key->hmk_var_len, key->hmk_hash, 0, key->hmk_data, val[0], NULL);
      if (HA_FILL == ha->ha_op)
	{
	  /* a hash join temp may have many dependents */
	  caddr_t * deps = (caddr_t*) *val;
	  while (deps)
	    {
	      caddr_t next;
	      if (!BOX_ELEMENTS (deps))
		break;
	      next = deps[ha->ha_n_deps];
	      if (!next)
		break;
	      deps = (caddr_t *) next;
	      itc_ha_disk_row (itc, NULL, ha, qst, tree, key->hmk_var_len, key->hmk_hash, 0, key->hmk_data, deps, NULL);
	    }
	}
      if (!hi->hi_pool)
	{
	  dk_free_tree ((caddr_t)(key->hmk_data));
	  dk_free_tree ((box_t) val[0]);
	  key->hmk_data = NULL;
	  val[0] = NULL;
	}
    }
  if (!hi->hi_pool)
    {
      id_hash_clear (hi->hi_memcache);
      id_hash_free (hi->hi_memcache);
    }
  else
    {
      mp_free (hi->hi_pool);
      hi->hi_pool = NULL;
    }
  hi->hi_memcache = NULL;
}


void
memcache_read_input (table_source_t * ts, caddr_t * inst, caddr_t * state)
{
  QNCAST (query_instance_t, qi, inst);
  key_source_t * ks = ts->ts_order_ks;
  setp_node_t * setp = ts->ts_order_ks->ks_from_setp;
  int n_results = 0, last_set, batch;
  caddr_t * branch = chash_reader_current_branch (ts, inst, 0);
  index_tree_t * tree = (index_tree_t*)qst_get (branch, setp->setp_ha->ha_tree);
  id_hash_iterator_t * hit;
  hash_index_t * hi = tree->it_hi;
  state_slot_t * ssl;
  int set;
  int n_sets = ts->src_gen.src_prev ? QST_INT (inst, ts->src_gen.src_prev->src_out_fill) : qi->qi_n_sets;
  hi_memcache_key_t *key;
  caddr_t **val;
  data_col_t * set_no_dc = NULL;
  if (ks->ks_set_no_col_ssl || SSL_VEC != setp->setp_ha->ha_tree->ssl_type)
    n_sets = 1;
  if (state)
    {
      QST_INT (inst, ts->clb.clb_nth_set) = 0;
      last_set = QST_INT (inst, ts->clb.clb_nth_set) = 0;
      hit = dk_alloc_box (sizeof (id_hash_iterator_t), DV_BIN);
      qst_set (inst, ks->ks_proc_set_ctr, (caddr_t)hit);
      id_hash_iterator (hit, hi->hi_memcache);
    }
  else
    hit = (id_hash_iterator_t*)qst_get (inst, ks->ks_proc_set_ctr);
  if (ks->ks_set_no_col_ssl)
    set_no_dc = QST_BOX (data_col_t *, inst, ks->ks_set_no_col_ssl->ssl_index);
 next_batch:
  batch = QST_INT (inst, ts->src_gen.src_batch_size);
  n_results = 0;
  ks_vec_new_results (ks, inst, NULL);

  while (hit_next (hit, (caddr_t *)(&key), (caddr_t *)(&val)))
    {
      int inx;
      dk_set_t out_slots = ks->ks_out_slots;
      qi->qi_set = n_results;
      DO_BOX_0 (state_slot_t *, ssl1, inx, setp->setp_keys_box )
	{
	  ssl = (state_slot_t*)out_slots->data;
	  out_slots = out_slots->next;
	  if (hi->hi_pool)
	    qst_set_copy (inst, ssl, key->hmk_data[inx]);
	  else
	    qst_set (inst, ssl, key->hmk_data[inx]);
	  key->hmk_data[inx] = NULL;
	}
      END_DO_BOX;
      DO_BOX_0 (state_slot_t *, ssl1, inx, setp->setp_dependent_box)
	{
	  ssl = (state_slot_t*)out_slots->data;
	  out_slots = out_slots->next;
	  if (hi->hi_pool)
	    qst_set_copy (inst, ssl, val[0][inx]);
	  else
	    qst_set (inst, ssl, val[0][inx]);
	  val[0][inx] = NULL;
	}
      END_DO_BOX;
      if (!hi->hi_pool)
	{
	  dk_free_tree ((caddr_t)(key->hmk_data));
	  dk_free_tree ((box_t) val[0]);
	  key->hmk_data = NULL;
	  val[0] = NULL;
	}

      if (set_no_dc)
	set = ((int64*)set_no_dc->dc_values)[n_results];
      else
	set = 0;
      qn_result ((data_source_t*)ts, inst, set);
      if (++n_results == batch)
	{
	  SRC_IN_STATE (ts, inst) = inst;
	  ts_always_null (ts, inst);				\
	  qn_send_output ((data_source_t*)ts, inst);
	  state = NULL;
	  dc_reset_array (inst, (data_source_t*)ts, ts->src_gen.src_continue_reset, -1);
	  goto next_batch;
	}
    }
  if (!hi->hi_pool)
    {
      id_hash_free (hi->hi_memcache);
      hi->hi_memcache = NULL;
      qst_set (branch, setp->setp_ha->ha_tree, NULL);
    }
  else
    {
      hi->hi_memcache = NULL;
      mp_free (hi->hi_pool);
      hi->hi_pool = NULL;
    }
  SRC_IN_STATE ((data_source_t*)ts, inst) = NULL;
  ts_always_null (ts, inst);
  if (QST_INT (inst, ts->src_gen.src_out_fill))
    qn_ts_send_output ((data_source_t *)ts, inst, ts->ts_after_join_test);
}



extern int32 ha_rehash_pct;


void
ha_rehash_row (hash_area_t * ha, index_tree_t * tree, it_cursor_t * itc, buffer_desc_t * buf)
{
  dk_set_t slots = itc->itc_ks->ks_out_slots;
  unsigned short code_mask;
  db_buf_t row;
  int var_len = 0;
  caddr_t * qst = itc->itc_out_state;
  uint32 code = HC_INIT;
  int n_keys = ha->ha_n_keys;
  int inx;
  hash_index_t *hi;
  it_cursor_t * bp_ref_itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_bp_ref_itc);
  hash_inx_b_ptr_t hibp;

  hi= tree->it_hi;
  for (inx = 0; inx < n_keys; inx++)
    {
      state_slot_t * ssl = (state_slot_t*)slots->data;
      slots = slots->next;
      if (ssl)
	{
	  caddr_t value = QST_GET (qst, ssl);
	  dtp_t dtp = DV_TYPE_OF (value);
	  code = key_hash_box (value, dtp, code, &var_len, ssl->ssl_sqt.sqt_collation,
			       ha->ha_key_cols[inx].cl_sqt.sqt_dtp, (HA_DISTINCT == ha->ha_op));
	  HASH_NUM_SAFE(code);
	}
    }
  code &= ID_HASHED_KEY_MASK;

  HI_BUCKET_PTR (hi, code, bp_ref_itc, &hibp, PA_WRITE);
  row = buf->bd_buffer + itc->itc_map_pos - HASH_HEAD_LEN;
  buf->bd_is_dirty = 1;
  LONG_SET (row + HH_NEXT_DP, hibp.hibp_page);
  code_mask = (unsigned short) ((code >> 9) & 0x7);
  code_mask = code_mask << 13;
  SHORT_SET (row + HH_NEXT_POS, ((hibp.hibp_pos & 0x1FFF) | code_mask));
  hi_bp_set (tree->it_hi, bp_ref_itc, code, buf->bd_page, itc->itc_map_pos);
  tree->it_hi->hi_count--;
}

#define HI_NEXT_SIZE(hi) \
  ((((int64)MAX (100, hi->hi_size)) / 100) * (ha_rehash_pct + 100))



state_slot_t *
ssl_single_state_shadow (state_slot_t * ssl, state_slot_t * tmp_ssl)
{
  if (SSL_VEC == ssl->ssl_type)
    {
      *tmp_ssl = *ssl;
      tmp_ssl->ssl_index = ssl->ssl_box_index;
      tmp_ssl->ssl_type = SSL_COLUMN;
      return tmp_ssl;
    }
  if (SSL_REF == ssl->ssl_type)
    {
      QNCAST (state_slot_ref_t, sslr, ssl);
      *tmp_ssl = *sslr->sslr_ssl;
      tmp_ssl->ssl_index = sslr->sslr_box_index;
      tmp_ssl->ssl_type = SSL_COLUMN;
      return tmp_ssl;
    }
  return ssl;
}


void
ha_rehash (caddr_t * inst, hash_area_t * ha, index_tree_t * it)
{
  buffer_desc_t * buf;
  state_slot_t tmp_ssl[SETP_DISTINCT_MAX_KEYS];
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  it_cursor_t * ref_itc = (it_cursor_t*)QST_GET_V (inst, ha->ha_ref_itc);
  key_source_t ks;
  setp_node_t setp;
  hash_index_t * hi = it->it_hi;
  caddr_t * save = dk_alloc_box (sizeof (caddr_t) * ha->ha_n_keys, DV_ARRAY_OF_POINTER);
  int inx, n_pages;
  it_cursor_t * insert_itc = (it_cursor_t*) QST_GET_V (inst, ha->ha_insert_itc);
  dp_addr_t last_dp = insert_itc->itc_hash_buf->bd_page;
  page_leave_outside_map (insert_itc->itc_hash_buf);
  insert_itc->itc_hash_buf = NULL;
  if (ref_itc && ref_itc->itc_buf)
    {
      page_leave_outside_map (ref_itc->itc_buf);
      ref_itc->itc_buf = NULL;
    }
  memset (&ks, 0, sizeof (ks));
  memset (&setp, 0, sizeof (setp));
  ITC_INIT (itc, NULL, NULL);
  itc_from_it (itc, it);
  for (inx = 0; inx < box_length (hi->hi_buckets) / sizeof (dp_addr_t); inx++)
    {
      dp_addr_t dp = hi->hi_buckets[inx];
      if (dp)
	{
	  ITC_IN_KNOWN_MAP (itc, dp);
	  it_free_dp_no_read (it, dp, DPF_HASH, 0);
	  ITC_LEAVE_MAPS (itc);
	}
    }
  hi->hi_size = HI_NEXT_SIZE (hi);
  dk_free_box (hi->hi_buckets);
  n_pages = (hi->hi_size / HE_BPTR_PER_PAGE) + 1;
  hi->hi_buckets = (dp_addr_t *) dk_alloc_box_zero (n_pages * sizeof (dp_addr_t), DV_CUSTOM);

  ks.ks_row_check = itc_row_check;
  DO_BOX (state_slot_t *, ssl, inx, ha->ha_slots)
    {
      if (inx >= ha->ha_n_keys)
	break;
      ssl = ssl_single_state_shadow (ssl, &tmp_ssl[inx]);
      dk_set_push (&ks.ks_out_slots, (void*)ssl);
      save[inx] = box_copy_tree (QST_GET (inst, ssl));
    }
  END_DO_BOX;
  ks.ks_out_slots = dk_set_nreverse (ks.ks_out_slots);
  setp.setp_ha = ha;

  itc->itc_out_state = inst;
  itc->itc_out_map = (out_map_t*) dk_alloc_box (sizeof (out_map_t) * ha->ha_n_keys, DV_BIN);
  for (inx = 0; inx < ha->ha_n_keys; inx++)
    {
      itc->itc_out_map[inx].om_is_null = 0;
      itc->itc_out_map[inx].om_cl = *key_find_cl (ha->ha_key, inx + 1);
    }
  ks.ks_out_map = itc->itc_out_map;
  ks.ks_row_check = itc_row_check;
  itc->itc_ks = &ks;
  buf = itc_reset (itc);
  ITC_FAIL (itc)
    {
      while (DVC_MATCH == itc_next (itc, &buf))
	{
	  ha_rehash_row (ha, it, itc, buf);
	}
      itc_page_leave (itc, buf);
    }
  ITC_FAILED
    {
      itc_free (itc);
    }
  END_FAIL (itc);
  DO_BOX (state_slot_t *, ssl, inx, ha->ha_slots)
    {
      if (inx >= ha->ha_n_keys)
	break;
      if (SSL_VEC != ssl->ssl_type && SSL_REF != ssl->ssl_type && SSL_IS_REFERENCEABLE (ssl))
      qst_set (inst, ssl, save[inx]);
    }
  END_DO_BOX;
  dk_free_box ((caddr_t)save);
  dk_set_free (ks.ks_out_slots);
  ITC_IN_KNOWN_MAP (insert_itc, last_dp);
  page_wait_access (insert_itc, last_dp, NULL, &insert_itc->itc_hash_buf, PA_WRITE, RWG_WAIT_ANY);
  ITC_LEAVE_MAPS (insert_itc);
}

#define HA_MAX_SZ 262139 /* max prime that can fit n*ha into a box */

int
itc_ha_feed (itc_ha_feed_ret_t *ret, hash_area_t * ha, caddr_t * qst, unsigned long feed_temp_blobs)
{
  hi_memcache_key_t hmk;
  caddr_t hmk_data_buf [(BOX_AUTO_OVERHEAD / sizeof (caddr_t)) + 1 + MAX_STACK_N_KEYS];
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
  int keys_on_stack;
  int do_flush;
  index_tree_t * tree = qst_tree (qst, ha->ha_tree, ha->ha_set_no);
  if (!tree)
    {
      tree = it_temp_allocate (wi_inst.wi_temp);
      tree->it_hi = hi_allocate ((int) MIN (ha->ha_row_count, (long) HA_MAX_SZ),
				 HA_MEMCACHE (ha), ha);
      tree->it_key = ha->ha_key;
      tree->it_shared = HI_PRIVATE;
      qst_set_tree (qst, ha->ha_tree, ha->ha_set_no, tree);
    }
  if (!itc)
    {
      itc = itc_create (NULL, qi->qi_trx);
      /* GK: the itc has to be initialized regardless of the feed_temp_blobs,
	 because of the XML entities that are *always* fed as temp space blobs */
      /*if (feed_temp_blobs)*/
      qst_set (qst, ha->ha_insert_itc, (caddr_t) itc);
    }
  itc_from_it_ha (itc, tree, ha);
  keys_on_stack = NULL != tree->it_hi->hi_memcache;
#ifdef NEW_HASH
  if (!bp_ref_itc)
    {
      bp_ref_itc = itc_create (NULL, qi->qi_trx);
      qst_set (qst, ha->ha_bp_ref_itc, (caddr_t) bp_ref_itc);
    }
  itc_from_it (bp_ref_itc, tree);
#endif
  ret->ihfr_hi = hi = tree->it_hi;
  if (keys_on_stack)
    BOX_AUTO((((caddr_t *)(&(hmk.hmk_data)))[0]), hmk_data_buf, n_keys * sizeof (caddr_t), DV_ARRAY_OF_POINTER);

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
	      ha->ha_key_cols[inx].cl_sqt.sqt_dtp, (HA_DISTINCT == ha->ha_op));
	  HASH_NUM_SAFE (code);
	  if (keys_on_stack)
	    hmk.hmk_data[inx] = value;
	}
      else
	GPF_T;
    }
  code &= ID_HASHED_KEY_MASK;
  if (hi->hi_memcache)
    {
      int next_link;
      caddr_t *deps;
      ret->ihfr_memcached = 1;
      hmk.hmk_hash = code;
      hmk.hmk_ha = ha->ha_org_ha ? ha->ha_org_ha : ha;
      deps = (caddr_t *)id_hash_get (hi->hi_memcache, (caddr_t)(&hmk));
      if (NULL != deps)
	{
	  int next_link = HA_FILL == ha->ha_op ? 1 : 0;

	  hi_memcache_key_t * saved_hmk = (hi_memcache_key_t *)(((char *)(deps)) - hi->hi_memcache->ht_key_length);
	  ret->ihfr_hmk_data = saved_hmk->hmk_data;
	  ret->ihfr_deps = (caddr_t *)(deps[0]);
	  if (next_link)
	    {
	      /*non unq entry in a hash inx dep */
	      caddr_t * new_deps = (caddr_t *)mp_alloc_box (hi->hi_pool, (n_deps + next_link) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	      for (inx = 0; inx < n_deps; inx++)
		new_deps[inx] = mp_full_box_copy_tree (hi->hi_pool, QST_GET (qst, ha->ha_slots[n_keys+inx]));
	      deps = (caddr_t *) (deps[0]); /* the dependent box itself, not its place in the hash */
	      new_deps[n_deps] = deps[n_deps];
	      deps[n_deps] = (caddr_t) new_deps;
	    }
	  return DVC_MATCH;
	}
      next_link = HA_FILL == ha->ha_op ? 1 : 0;
      hmk.hmk_var_len = var_len;
      hmk.hmk_ha = ha->ha_org_ha ? ha->ha_org_ha : ha; /* after the store is done, the hash can be retained and these will be refs to free mem */
      if (hi->hi_pool)
	{
	  hmk.hmk_data = (caddr_t *) mp_full_box_copy_tree (hi->hi_pool, (caddr_t) hmk.hmk_data);
	  deps = (caddr_t *)mp_alloc_box (hi->hi_pool, (n_deps + next_link) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  for (inx = 0; inx < n_deps; inx++)
	    deps[inx] = mp_full_box_copy_tree (hi->hi_pool, QST_GET (qst, ha->ha_slots[n_keys+inx]));
	  if (next_link)
	    deps[n_deps] = NULL;
	  SET_THR_TMP_POOL (hi->hi_pool);
	  t_id_hash_set (hi->hi_memcache, (caddr_t)(&hmk), (caddr_t)(&deps));
	  SET_THR_TMP_POOL (NULL);
	}
      else
	{
	  hmk.hmk_data = (caddr_t *) box_copy_tree ((caddr_t) hmk.hmk_data);
	  deps = (caddr_t *)dk_alloc_box_zero ((n_deps + next_link) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  for (inx = 0; inx < n_deps; inx++)
	    deps[inx] = box_copy_tree (QST_GET (qst, ha->ha_slots[n_keys+inx]));
	  id_hash_set (hi->hi_memcache, (caddr_t)(&hmk), (caddr_t)(&deps));
	}
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
      itc_ha_flush_memcache (ha, qst, SETP_HASH_FILL);
      /* if it is quietcast and len overflows, then maybe the hash is even empty */
      /* if (HA_FILL == ha->ha_op)
	 GPF_T; */
      return DVC_LESS;
    }
#ifdef OLD_HASH
      he = HI_BUCKET (hi, code);
#endif
#ifdef NEW_HASH
  HI_BUCKET_PTR (hi, code, bp_ref_itc, &hibp, PA_WRITE);
#endif
  if (HA_FILL != ha->ha_op && HA_PROC_FILL != ha->ha_op)
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
  ITC_FAIL (itc)
    {
      itc_ha_disk_row (itc, NULL, ha, qst, tree, var_len, code, feed_temp_blobs, NULL, NULL, &hibp);
    }
  ITC_FAILED
  END_FAIL (itc);

  if (ha_rehash_pct &&  hi->hi_count > (hi->hi_size / 100) * ha_rehash_pct
      && HI_NEXT_SIZE (hi) < (int64)HI_MAX_SIZE)
    ha_rehash (qst, ha, tree);
#endif
  ret->ihfr_disk_buf = itc->itc_hash_buf;
  return DVC_LESS;
}


void
setp_print_input (setp_node_t * setp, caddr_t * qst)
{
  printf ("group by ");
  DO_SET (state_slot_t *, ssl, &setp->setp_keys)
    {
      sqlo_box_print (qst_get (qst, ssl));
      printf (" ");
    }
  END_DO_SET();
  printf (" -> ");
  DO_SET (state_slot_t *, ssl, &setp->setp_dependent)
    {
      sqlo_box_print (qst_get (qst, ssl));
      printf (" ");
    }
  END_DO_SET();
  printf ("\n");
}


caddr_t
box_num_always (boxint n)
{
  caddr_t b = dk_alloc_box (sizeof (boxint), DV_LONG_INT);
  *(boxint *)b = n;
  return b;
}

#define AGG_C(dt, op) (((int)dt << 3) + op)
#define code_vec_run_this_set(cv, qst) code_vec_run_1 (cv, qst, CV_THIS_SET_ONLY)

/*code_vec_run_v (cv, qst, 0, -1, -2 - ((QI*)qst)->qi_set, NULL, NULL, 0)*/
void
setp_group_row (setp_node_t * setp, caddr_t * qst)
{
  dtp_t row_image[MAX_ROW_BYTES];
  hash_area_t * ha = setp->setp_ha;
  itc_ha_feed_ret_t ihfr;
  int rc = itc_ha_feed (&ihfr, ha, qst, 0);
  index_tree_t * tree;
  hash_index_t * hi;
  LOCAL_RF (rf, 0, 0, ha->ha_key);
  rf.rf_large_row = &row_image[0];
  /*setp_print_input (setp, qst);*/
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
		if (setp->setp_ignore_ua)
		  break;
		qst_set (qst, op->go_old_val, NEW_DB_NULL);
		code_vec_run_this_set (op->go_ua_init_setp_call, qst);
		code_vec_run_this_set (op->go_ua_acc_setp_call, qst);
	        dk_free_tree (dep_ptr[0]);
	        dep_ptr[0] = QST_GET_V (qst, op->go_old_val);
		QST_GET_V (qst, op->go_old_val) = NULL;
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
      tree = qst_tree (qst, ha->ha_tree, ha->ha_set_no);
      hi = tree->it_hi;
      if (!itc)
	{
	  itc = itc_create (NULL, ((query_instance_t *)qst)->qi_trx);
	  qst_set (qst, ha->ha_ref_itc, (caddr_t) itc);
	}
      itc_from_it_ha (itc, tree, ha);
      itc->itc_map_pos = ihfr.ihfr_disk_pos;
      itc->itc_row_data = ihfr.ihfr_disk_buf->bd_buffer + ihfr.ihfr_disk_pos;
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
		code_vec_run_this_set (op->go_ua_init_setp_call, qst);
		code_vec_run_this_set (op->go_ua_acc_setp_call, qst);
		rf.rf_row = ihfr.ihfr_disk_buf->bd_buffer + itc->itc_map_pos;
		row_set_col (&rf, cl, QST_GET_V (qst, op->go_old_val));
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

  tree = qst_tree (qst, ha->ha_tree, ha->ha_set_no);
  hi = tree->it_hi;
  if (ihfr.ihfr_memcached)
    {
      int dep_box_inx = 0;
      DO_SET (gb_op_t *, op, &setp->setp_gb_ops)
	{
	  int rc, set;
	  dbe_col_loc_t * cl = &ha->ha_key_cols[ha->ha_n_keys + dep_box_inx];
	  caddr_t *dep_ptr = ihfr.ihfr_deps + dep_box_inx;
	  state_slot_t * ssl = setp->setp_dependent_box[dep_box_inx];
	  QNCAST (query_instance_t, qi, qst);
	  data_col_t * dc;
	  if ((SSL_VEC == ssl->ssl_type || SSL_REF == ssl->ssl_type) && !op->go_distinct_ha)
	    {
	      switch (AGG_C (ssl->ssl_dtp, op->go_op))
		{
		case AGG_C (DV_LONG_INT, AMMSC_COUNTSUM):
		case AGG_C (DV_LONG_INT, AMMSC_SUM):
		case AGG_C (DV_LONG_INT, AMMSC_COUNT):
		  dc = QST_BOX (data_col_t *, qst, ssl->ssl_index);
		  set = (SSL_REF == ssl->ssl_type) ? sslr_set_no (qst, ssl, qi->qi_set) : qi->qi_set;
		  if (dc->dc_nulls && DC_IS_NULL (dc, set))
		    goto next_mem_col;
		  if (!IS_BOX_POINTER (*dep_ptr))
		    *dep_ptr = box_num_always (*(ptrlong*)dep_ptr);
		  **(boxint**)dep_ptr += ((int64*)dc->dc_values)[set];
		  goto next_mem_col;
		case AGG_C (DV_DOUBLE_FLOAT, AMMSC_COUNTSUM):
		case AGG_C (DV_DOUBLE_FLOAT, AMMSC_SUM):
		case AGG_C (DV_DOUBLE_FLOAT, AMMSC_COUNT):
		  dc = QST_BOX (data_col_t *, qst, ssl->ssl_index);
		  set = (SSL_REF == ssl->ssl_type) ? sslr_set_no (qst, ssl, qi->qi_set) : qi->qi_set;
		  if (dc->dc_nulls && DC_IS_NULL (dc, set))
		    goto next_mem_col;
		  **(double**)dep_ptr += ((double*)dc->dc_values)[set];
		  goto next_mem_col;
		}
	    }
	  switch (op->go_op)
	    {
	    case AMMSC_MIN:
	    case AMMSC_MAX:
	      {
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
		    if (!hi->hi_pool)
		      {
			dk_free_tree (dep_ptr[0]);
			dep_ptr[0] = box_copy_tree (new_val);
		      }
		    else
		      dep_ptr[0] = mp_full_box_copy_tree (hi->hi_pool, new_val);
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
		  goto next_mem_col;

		if (op->go_distinct_ha)
		  {
		    itc_ha_feed_ret_t ihfr;
		    if (DVC_MATCH == itc_ha_feed (&ihfr, op->go_distinct_ha, qst, 0))
		      goto next_mem_col;
		  }
		/* can be null on the row if 1st value was null. Replace w/ new val */
		if (DV_DB_NULL == DV_TYPE_OF (dep_ptr[0]))
		  {
		    if (!hi->hi_pool)
		      {
			dk_free_tree (dep_ptr[0]);
			dep_ptr[0] = box_copy_tree (new_val);
		      }
		    else
		      dep_ptr[0] = mp_full_box_copy_tree (hi->hi_pool, new_val);
		  }
		else
		  {
		    caddr_t res;
		    res = box_add (new_val, dep_ptr[0], qst, NULL);
		    if (!hi->hi_pool)
		      {
			dk_free_tree (dep_ptr[0]);
			dep_ptr[0] = res;
		      }
		    else
		      {
			int len1 = IS_BOX_POINTER (dep_ptr[0]) ? box_length (dep_ptr[0]) : 0; 
			int len2 = IS_BOX_POINTER (res) ? box_length (res) : 0;
			if (DV_TYPE_OF (dep_ptr[0]) == DV_TYPE_OF (res) && len1 == len2 && len1 > 0)
			  memcpy (dep_ptr[0], res, len1);
			else
			  dep_ptr[0] = mp_full_box_copy_tree (hi->hi_pool, res);
			dk_free_tree (res);
		      }
		  }
		break;
	      }
	    case AMMSC_USER:
	      {
		caddr_t old_val, new_val;
		old_val = QST_GET_V (qst, op->go_old_val) = dep_ptr[0];
		dep_ptr[0] = NULL;
		if (NULL == old_val)
		  {
		    qst_set (qst, op->go_old_val, NEW_DB_NULL);
		    code_vec_run_this_set (op->go_ua_init_setp_call, qst);
		  }
		else if (DV_DB_NULL == DV_TYPE_OF (old_val))
		  {
		    code_vec_run_this_set (op->go_ua_init_setp_call, qst);
		  }
		code_vec_run_this_set (op->go_ua_acc_setp_call, qst);
		new_val = QST_GET_V (qst, op->go_old_val);
		if (NULL == new_val)
		  new_val = box_num_nonull (0);
		dep_ptr[0] = new_val;
		QST_GET_V (qst, op->go_old_val) = NULL;
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
      itc->itc_map_pos = ihfr.ihfr_disk_pos;
      itc->itc_row_data = ihfr.ihfr_disk_buf->bd_buffer + ihfr.ihfr_disk_pos;
      itc_from_it_ha (itc, tree, ha);
      DO_SET (gb_op_t *, op, &setp->setp_gb_ops)
	{
	  int rc;
	  dbe_col_loc_t * cl = &ha->ha_key_cols[ha->ha_n_keys + dep_box_inx];
	  if (cl->cl_fixed_len < 0)
	    goto next_disk_col;
	  itc_qst_set_column (itc, ihfr.ihfr_disk_buf, cl, qst, op->go_old_val);
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
		    rf.rf_row = ihfr.ihfr_disk_buf->bd_buffer + itc->itc_map_pos;
		    row_set_col (&rf, cl, new_val);
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
		  {
		    rf.rf_row = ihfr.ihfr_disk_buf->bd_buffer + itc->itc_map_pos;
		    row_set_col (&rf, cl, new_val);
		  }
		else
		  {
		    box_add (new_val, QST_GET_V (qst, op->go_old_val), qst, op->go_old_val);
		    rf.rf_row = ihfr.ihfr_disk_buf->bd_buffer + itc->itc_map_pos;
		    row_set_col (&rf, cl, QST_GET_V (qst, op->go_old_val));
		  }
		break;
	      }
	    case AMMSC_USER:
	      {
		if (DV_DB_NULL == DV_TYPE_OF (QST_GET_V (qst, op->go_old_val)))
		  code_vec_run_this_set (op->go_ua_init_setp_call, qst);
		code_vec_run_this_set (op->go_ua_acc_setp_call, qst);
		rf.rf_row = ihfr.ihfr_disk_buf->bd_buffer + itc->itc_map_pos;
		row_set_col (&rf, cl, QST_GET_V (qst, op->go_old_val));
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


state_slot_t *
ha_ssl_for_col (hash_area_t * ha, oid_t cid)
{
  int inx;
  for (inx = 0; ha->ha_key_cols[inx].cl_col_id; inx++)
    {
      if (ha->ha_key_cols[inx].cl_col_id == cid)
	return ha->ha_slots[inx];
    }
  return NULL;
}


void
setp_order_row (setp_node_t * setp, caddr_t * qst)
{
  int nth = 0;
  query_instance_t * volatile qi = (query_instance_t *) qst;
  caddr_t err = NULL;
  hash_area_t * ha = setp->setp_ha;
  index_tree_t * tree = qst_tree (qst, ha->ha_tree, ha->ha_set_no);
  it_cursor_t * ins_itc;
  dbe_key_t * key = ha->ha_key;
  int inx;
  LOCAL_RD (rd);
  rd.rd_key = key;
  rd.rd_any_ser_flags = DKS_TO_OBY_KEY;
  if (!tree)
    {
      tree = it_temp_allocate (wi_inst.wi_temp);
      tree->it_key = ha->ha_key;
      if (!it_temp_tree (tree))
	{
	  it_free (tree);
	  sqlr_new_error ("42000", "SR...", "Can't allocate tree for temp space.");
	}
      qst_set_tree (qst, ha->ha_tree, ha->ha_set_no, tree);
    }
  ins_itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_ref_itc);
  if (!ins_itc)
    {
      ins_itc = itc_create (NULL, qi->qi_trx);
      qst_set (qst, ha->ha_ref_itc, (caddr_t) ins_itc);
      ins_itc->itc_out_state = qst;
    }
  ins_itc->itc_ltrx = qi->qi_trx; /* can vary, qi can run on different aq threads */
  itc_from_it_ha (ins_itc, tree, ha);
  rd.rd_itc = ins_itc;
  rd.rd_non_comp_max = MAX_ROW_BYTES;
  rd.rd_non_comp_len = key->key_row_var_start[0];
  itc_free_owned_params (ins_itc);
  ITC_START_SEARCH_PARS (ins_itc);
  ins_itc->itc_search_par_fill = key->key_n_significant;
  ins_itc->itc_key_spec = setp->setp_insert_spec;

  DO_ALL_CL (cl, ha->ha_key)
    {
      state_slot_t * ssl  = ha_ssl_for_col (ha, cl->cl_col_id);
      row_insert_cast_temp (&rd, cl, QST_GET (qst, ssl),
			    &err, NULL);

      if (err)
	sqlr_resignal (err);
      if (nth < key->key_n_significant && rd.rd_non_comp_len - key->key_row_var_start[0] + key->key_key_var_start[0] > MAX_RULING_PART_BYTES)
	sqlr_new_error ("22026", "SR...", "Sorting key too long in order by key, exceeds 1900 bytes.");
      nth++;
	}
  END_DO_ALL_CL;
  for (inx = 0; inx < key->key_n_significant; inx++)
    ins_itc->itc_search_params[inx] = ins_itc->itc_search_params[key->key_n_significant + key->key_part_in_layout_order[inx]];
  rd.rd_values = &ins_itc->itc_search_params[key->key_n_significant];
  ins_itc->itc_write_waits = ins_itc->itc_read_waits = 0;
  ITC_FAIL (ins_itc)
    {
      int rc;
      rc = itc_insert_unq_ck (ins_itc, &rd, UNQ_SORT);
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
  return (box_num (key_hash_box (arg, DV_TYPE_OF (arg), code, &d, NULL, DV_TYPE_OF (arg), 1)));
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
hash_source_input_memcache (hash_source_t * hs, caddr_t * qst, caddr_t * qst_cont)
{
  hi_memcache_key_t hmk;
  caddr_t hmk_data_buf [(BOX_AUTO_OVERHEAD / sizeof (caddr_t)) + 1 + MAX_STACK_N_KEYS];
  caddr_t *deps;
  int inx;
  int any_passed = 0;
  hash_index_t * hi;
  hash_area_t * ha = hs->hs_ha;
  int n_keys = ha->ha_n_keys;
  int n_deps = ha->ha_n_deps;
  index_tree_t * it = NULL;
  it = (index_tree_t *) QST_GET_V (qst, ha->ha_tree);
  if (!it)
    return;
  hi = it->it_hi;
  if (!qst_cont)
    any_passed = 1; /* if this is a 'get more' invocation of the node there must have been at least one match */
  for (;;)
    {
      uint32 code = HC_INIT;
      if (qst_cont)
	{
	  BOX_AUTO((((caddr_t *)(&(hmk.hmk_data)))[0]), hmk_data_buf, n_keys * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  qst[hs->hs_current_inx] = NULL;
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
				   ha->ha_key_cols[inx].cl_sqt.sqt_dtp, (HA_DISTINCT == ha->ha_op));
	      HASH_NUM_SAFE (code);
	      hmk.hmk_data[inx] = k;
	    }
	  END_DO_BOX;
	  code &= ID_HASHED_KEY_MASK;
	  hmk.hmk_hash = code;
	  hmk.hmk_ha = ha;
	  deps = (caddr_t *)id_hash_get (hi->hi_memcache, (caddr_t)(&hmk));

	  if (deps)
	    {
	      hi_memcache_key_t * saved_hmk = (hi_memcache_key_t *)(((char *)(deps)) - hi->hi_memcache->ht_key_length);
	      caddr_t next;
	      deps = (caddr_t *)(deps[0]);
	      next = deps[n_deps];
	      if (!next)
		qn_record_in_state ((data_source_t*) hs, qst, (caddr_t*) NULL);
	      else
		{
		  qn_record_in_state ((data_source_t*) hs, qst, (caddr_t*) qst);
		  qst[hs->hs_current_inx] = next;
		}
	      DO_BOX (state_slot_t *, out, inx, hs->hs_out_slots)
		{
		  ptrlong col_idx = hs->hs_out_cols_indexes[inx];
		  caddr_t val;
		  if (col_idx >= 0)
		    {
		      if (col_idx >= n_keys)
			val = deps[col_idx - n_keys];
		      else
			val = saved_hmk->hmk_data[col_idx];
		      qst_set (qst, out, box_copy_tree (val));
		    }
		}
	      END_DO_BOX;
	      if (!hs->src_gen.src_after_test || code_vec_run (hs->src_gen.src_after_test, qst))
		{
		  any_passed = 1;
		  qn_ts_send_output ((data_source_t*) hs, qst, hs->hs_after_join_test);
		}
	    }
	  if (!any_passed && hs->hs_is_outer)
	    {
	      hs_outer_output (hs, qst);
	      return;
	    }
	}
      else
	{
	  deps = (caddr_t *) qst[hs->hs_current_inx];
	  if (!deps)
	    {
	      qn_record_in_state ((data_source_t*) hs, qst, NULL);
	      if (hs->hs_is_outer && !any_passed)
		hs_outer_output (hs, qst);
	      return;
	    }
	  else
	    {
	      caddr_t next = deps[n_deps];
	      qst[hs->hs_current_inx] = next;
	      qn_record_in_state ((data_source_t*) hs, qst, next ? qst : NULL);
	      DO_BOX (state_slot_t *, out, inx, hs->hs_out_slots)
		{
		  ptrlong col_idx = hs->hs_out_cols_indexes[inx];
		  caddr_t val = NULL;
		  if (col_idx >= n_keys)
		    {
		      val = deps[col_idx - n_keys];
		      qst_set (qst, out, box_copy_tree (val));
		    }
		}
	      END_DO_BOX;
	      if (!hs->src_gen.src_after_test || code_vec_run (hs->src_gen.src_after_test, qst))
		{
		  any_passed = 1;
		  qn_ts_send_output ((data_source_t*) hs, qst, hs->hs_after_join_test);
		}
	    }
	}
      qst_cont = NULL;
    }
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
  if (hs->src_gen.src_sets)
    {
      hash_source_chash_input (hs, qst, qst_cont);
      return;
    }
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
      if (!it)
	return;
      hi = it->it_hi;
      ref_itc = (it_cursor_t *) QST_GET_V (qst, ha->ha_ref_itc);
      if (!it)
	return;
      if (hi->hi_memcache)
	{
	  hash_source_input_memcache (hs, qst, start ? qst : NULL);
	  return;
	}
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
		  ha->ha_key_cols[inx].cl_sqt.sqt_dtp, 0);
	      HASH_NUM_SAFE (code);
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
	  next_page_dp = LONG_REF (buf->bd_buffer + pos + HH_NEXT_DP - HASH_HEAD_LEN);
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
	      hibp->hibp_pos = SHORT_REF (buf->bd_buffer + pos + HH_NEXT_POS - HASH_HEAD_LEN) & 0x1FFF;
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
	  ref_itc->itc_map_pos = pos;
	  ref_itc->itc_row_key = ha->ha_key;
	  DO_BOX (state_slot_t *, out, inx, hs->hs_out_slots)
	    {
	      ref_itc->itc_row_data = buf->bd_buffer + pos;
	      itc_qst_set_column (ref_itc, buf, &hs->hs_out_cols[inx], qst, out);
	    }
	  END_DO_BOX;
	  page_leave_outside_map (buf);
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
	      page_leave_outside_map (buf);
	    }
	  if (hs->hs_is_outer && !any_passed)
	    hs_outer_output (hs, qst);
	  return;
	}
      qst_cont = NULL;
    }
}


int
it_hi_done (index_tree_t * it)
{
  /* true if to be kept */
  int state = 1;
  IN_HIC;
  if (HI_PRIVATE == it->it_shared)
    {
      int rc = --it->it_ref_count;
      if (rc < 0) GPF_T1 ("it neg ref count");
      LEAVE_HIC;
      return 0 != rc;
    }
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
  deps = (dk_set_t) gethash ((void*) unbox_ptrlong (hsi->hsi_super_key), hash_index_cache.hic_pk_to_it);
  dk_set_push (&deps, (void*) it);
  sethash ((void*) unbox_ptrlong (hsi->hsi_super_key), hash_index_cache.hic_pk_to_it, deps);
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
  deps = (dk_set_t) gethash ((void*) unbox_ptrlong (hsi->hsi_super_key), hash_index_cache.hic_pk_to_it);
  dk_set_delete (&deps, (void*) it);
  sethash ((void*) unbox_ptrlong (hsi->hsi_super_key), hash_index_cache.hic_pk_to_it, deps);
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


long tc_hi_lock_new_lock = 0;
long tc_hi_lock_old_dp_no_lock = 0;
long tc_hi_lock_old_dp_no_lock_deadlock = 0;
long tc_hi_lock_old_dp_no_lock_put_lock = 0;
long tc_hi_lock_lock = 0;
long tc_hi_lock_lock_deadlock = 0;


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

  itc_read_ahead_blob (itc, ra, 0);
  itc_free (itc);
}



static void
it_hi_set_page_lock (query_instance_t * qi, it_cursor_t *itc, dp_addr_t dp)
{
  buffer_desc_t *buf;
  page_lock_t *pl;

  ITC_IN_KNOWN_MAP (itc, dp);
  pl = IT_DP_PL (itc->itc_tree, dp);
  buf = IT_DP_TO_BUF (itc->itc_tree, dp);

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
      page_wait_access (itc, itc->itc_page, NULL, &buf, PA_WRITE, RWG_WAIT_ANY);
      ITC_IN_KNOWN_MAP (itc, dp);
      tc_hi_lock_old_dp_no_lock += 1;
      if (!buf || buf == PF_OF_DELETED)
	{
	  itc->itc_ltrx->lt_error = LTE_DEADLOCK;
	  tc_hi_lock_old_dp_no_lock_deadlock += 1;
	  itc_bust_this_trx (itc, NULL, ITC_BUST_THROW);
	}
      ITC_FIND_PL (itc, buf);
      ITC_LEAVE_MAPS (itc);
      if (itc->itc_pl)
	goto normal_wait;
      tc_hi_lock_old_dp_no_lock_put_lock += 1;
/*      itc->itc_lock_mode = PL_EXCLUSIVE | PL_PAGE_LOCK;*/
      itc_make_pl (itc, buf);
      PL_SET_FLAG (itc->itc_pl, PL_PAGE_LOCK);
      itc->itc_pl->pl_owner = qi->qi_trx;
      page_leave_outside_map (buf);
    }
  else if (pl)
    {
      tc_hi_lock_lock += 1;
      page_wait_access (itc, itc->itc_page, NULL, &buf, PA_WRITE, RWG_WAIT_ANY);
      if (!buf || buf == PF_OF_DELETED)
	{
	  itc->itc_ltrx->lt_error = LTE_DEADLOCK;
	  tc_hi_lock_old_dp_no_lock_deadlock += 1;
	  itc_bust_this_trx (itc, NULL, ITC_BUST_THROW);
	}
      ITC_FIND_PL (itc, buf);
      ITC_LEAVE_MAPS (itc);
normal_wait:
 /*     itc->itc_lock_mode = PL_EXCLUSIVE;*/
      itc->itc_page = dp;
      itc->itc_n_lock_escalations = 10; /* arbitrary quantity, will cause the itc to prefer page locks when can */
      itc->itc_is_on_row = 1;
      DO_ROWS (buf, map_pos, row, NULL)
	{
	  key_ver_t kv = IE_KEY_VERSION (row);
	  if (kv != 0 && kv != KV_LEFT_DUMMY)
	    {
	      itc->itc_map_pos = map_pos;
	      if (WAIT_RESET == itc_set_lock_on_row (itc, &buf))
		{
		  itc->itc_ltrx->lt_error = LTE_DEADLOCK;
		  tc_hi_lock_lock_deadlock += 1;
		  itc_bust_this_trx (itc, &buf, ITC_BUST_THROW);
		}
	  if (itc->itc_pl && PL_IS_PAGE (itc->itc_pl))
	    break;
	    }
	  itc->itc_map_pos = map_pos;
	}
      END_DO_ROWS;
      page_leave_outside_map (buf);
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
  int n_sets = fref->src_gen.src_prev ? QST_INT (inst, fref->src_gen.src_prev->src_out_fill) : 1;
  hi_signature_t * hsi = fref->fnr_hi_signature;
  hash_area_t * ha = fref->fnr_setp->setp_ha;
  state_slot_t * tree_ssl = ha->ha_tree;
  index_tree_t * it = (index_tree_t *) QST_GET_V (inst, tree_ssl);
  query_instance_t *qi = (query_instance_t *)inst;
#ifdef NEW_HASH
  union {
    char hsi_auto_buf [sizeof (hi_signature_t) + 20];
    caddr_t dummy;
  } hsi_auto_union;
  caddr_t hsi_auto;
  char hsi_lock_mode;
#endif
  if (fref->src_gen.src_out_fill)
    QST_INT (inst, fref->src_gen.src_out_fill) = n_sets;
  if (enable_chash_join)
    {
      chash_fill_input (fref, inst, qst);
      return;
    }
  IN_HIC;
  if (it)
    {
      if (HI_OK == it->it_shared)
	{
	  LEAVE_HIC;
	  qn_send_output ((data_source_t *) fref, qst);
	  return;
	}
      QST_GET_V (qst, tree_ssl) =  NULL;
  LEAVE_HIC;
      it_temp_free (it);
      sqlr_new_error ("42000", "HT...", "Hash join temp has been marked invalid.  Retry");
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
      it->it_hi = hi_allocate ((int) MIN (ha->ha_row_count, (long) HA_MAX_SZ), HA_MEMCACHE (ha), ha);
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
      if (!it->it_hi->hi_memcache)
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
      hic = it->it_hi_signature;
      /* check a second time inside the mtx.  Otherwise can read a hic that is about to be deld on  another thread */
      if (hic)
	{
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
	  dk_free_tree ((caddr_t) hic);
	}
      LEAVE_HIC;
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


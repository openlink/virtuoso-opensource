/*
 *  Dkbox.c
 *
 *  $Id$
 *
 *  Boxes
 *
 *  A box is a block of memory with a header
 *  containing a 24 bit length and an 8 bit tag.
 *  Boxes start at word boundaries bit the length is in system
 *  so that it does not the logical length of a box does not
 *  have to be a multiple of 4
 *
 *  The tag is an arbitrary application specific field
 *  that can be used to identify the type of box.
 *  Dis Kit uses the DV_ARRAY<xxx> and DV_<xx>_STRING values as tags
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

#include "Dk.h"
#include <assert.h>

/*#define DV_UNAME_UNIT_DEBUG*/
/*#define DV_UNAME_STATS*/

#ifndef DOUBLE_ALIGN
#error boxes must be aligned at 8
#endif

#ifdef _DEBUG
long box_types_alloc[256];	/* implicit zero-fill assumed */
long box_types_free[256];	/* implicit zero-fill assumed */
#endif

/* Hashtable of UNAMEs */

static dk_mutex_t *uname_mutex;


#if 0
#define UNAME_TABLE_SIZE 61
#define UNAME_LOCK_REFCOUNT 16
#else
#define UNAME_TABLE_SIZE 8191
#define UNAME_LOCK_REFCOUNT 256
#endif

typedef struct uname_chain_pair_s
{
  uname_blk_t *	unc_immortals;
  uname_blk_t *	unc_refcounted;
#ifdef DV_UNAME_UNIT_DEBUG
  long unc_count;
  long unc_refcount;
#endif

} uname_chain_pair_t;

static uname_chain_pair_t unames[UNAME_TABLE_SIZE];

uint32
big_endian_box_length (const void *box)
{
  const unsigned char *ptr = (const unsigned char *) box - 4;
  return ptr[0] + ((uint32) ptr[1] << 8) + ((uint32) ptr[2] << 16);
}


#ifdef DV_UNAME_UNIT_DEBUG
static void
box_dv_uname_audit_one (uint32 cpair_idx)
{
  uname_chain_pair_t *cpair;
  long ctr = 0, refctr = 0;
  uint32 hash;
  uname_blk_t *blk;
  cpair_idx = cpair_idx % UNAME_TABLE_SIZE;
  cpair = unames + cpair_idx;
  for (blk = cpair->unc_immortals; NULL != blk; blk = blk->unb_next)
    {
      ctr++;
      refctr += UNAME_LOCK_REFCOUNT;
      if (UNAME_LOCK_REFCOUNT > blk->unb_hdr[UNB_HDR_REFCTR])
	GPF_T1 ("Too small refcount in immortal");
#ifdef MALLOC_DEBUG
      if (DV_UNAME != box_tag (blk->unb_data_ptr))
	GPF_T1 ("non-UNAME in immortal unames");
      /* dk_check_tree_iter (blk->unb_data_ptr, NULL, known); */
      BYTE_BUFFER_HASH (hash, blk->unb_data_ptr, box_length_inline (blk->unb_data_ptr) - 1);
#else
      BYTE_BUFFER_HASH (hash, blk->unb_data, box_length_inline (blk->unb_data) - 1);
#endif
      if ((hash % UNAME_TABLE_SIZE) != cpair_idx)
	GPF_T1 ("Bad hash");
    }
  for (blk = cpair->unc_refcounted; NULL != blk; blk = blk->unb_next)
    {
      ctr++;
      refctr += blk->unb_hdr[UNB_HDR_REFCTR];
      if (0 >= blk->unb_hdr[UNB_HDR_REFCTR])
	GPF_T1 ("Negative refcount");
      if (UNAME_LOCK_REFCOUNT <= blk->unb_hdr[UNB_HDR_REFCTR])
	GPF_T1 ("Big refcount but not immortal");
#ifdef MALLOC_DEBUG
      if (DV_UNAME != box_tag (blk->unb_data_ptr))
	GPF_T1 ("non-UNAME in immortal unames");
      /* dk_check_tree_iter (blk->unb_data_ptr, NULL, known); */
      BYTE_BUFFER_HASH (hash, blk->unb_data_ptr, box_length_inline (blk->unb_data_ptr) - 1);
#else
      BYTE_BUFFER_HASH (hash, blk->unb_data, box_length_inline (blk->unb_data) - 1);
#endif
      if ((hash % UNAME_TABLE_SIZE) != cpair_idx)
	GPF_T1 ("Bad hash");
    }
  if (refctr != cpair->unc_refcount)
    GPF_T1 ("Mismatch in unc_refcount");
  if (ctr != cpair->unc_count)
    GPF_T1 ("Mismatch in unc_count");
}


static void
box_dv_uname_audit_table (void)
{
  uint32 idx;
  for (idx = 0; idx < UNAME_TABLE_SIZE; idx++)
    box_dv_uname_audit_one (idx);
}


#else
#define box_dv_uname_audit_one(CPAIR_IDX)
#define box_dv_uname_audit_table()
#endif

#ifdef MALLOC_DEBUG
#define dk_alloc_mmap(sz) dk_alloc (sz)
#define dk_free_munmap(ptr, sz) dk_free (ptr, sz)
#else

void *
dk_mmap_brk (size_t sz)
{
  return mm_large_alloc (sz);
}

#define dk_alloc_mmap(sz) \
  ((sz) >= box_min_mmap && (sz) < 0xffffff ? (caddr_t) dk_mmap_brk (sz) : dk_alloc (sz))
#define dk_free_munmap(ptr, sz)						\
  ((sz) >= box_min_mmap && (sz) < 0xffffff ? mm_free_sized (ptr, sz) : dk_free (ptr, sz))
#endif


size_t box_min_mmap = (1024 * 100 ) - 8;
#undef dk_alloc_box
box_t
dk_alloc_box (size_t bytes, dtp_t tag)
{
  unsigned char *ptr;
  size_t align_bytes;
#ifdef MALLOC_DEBUG
  if (bytes & ~0xffffff)
    GPF_T1 ("box to allocate is too large");
#endif

  /* This assumes dk_alloc aligns at least at 4 */
#ifdef DOUBLE_ALIGN
  align_bytes = 8 + (IS_STRING_ALIGN_DTP (tag) ? ALIGN_STR (bytes) : ALIGN_8 (bytes));
#else
  align_bytes = 4 + (IS_STRING_ALIGN_DTP (tag) ? ALIGN_STR (bytes) : ALIGN_4 (bytes));
#endif

  ptr = (unsigned char *) dk_alloc_mmap (align_bytes);
  if (!ptr)
    return (box_t) ptr;

#ifdef DOUBLE_ALIGN
  ptr += 4;
#endif

#ifdef _DEBUG
  box_types_alloc[(unsigned) tag]++;
#endif
  WRITE_BOX_HEADER (ptr, bytes, tag);
  return (box_t) ptr;
}


#undef dk_alloc_box_long
box_t
dk_alloc_box_long (size_t bytes, dtp_t tag)
{
  unsigned char *ptr;
  size_t align_bytes;

#ifdef MALLOC_DEBUG
  if (bytes > 1000000000)
    GPF_T1 ("Box over 1G, suspect, assertion in malloc debug mode only");
#endif

  /* This assumes dk_alloc aligns at least at 4 */
#ifdef DOUBLE_ALIGN
  align_bytes = 8 + (IS_STRING_ALIGN_DTP (tag) ? ALIGN_STR (bytes) : ALIGN_8 (bytes));
#else
  align_bytes = 4 + (IS_STRING_ALIGN_DTP (tag) ? ALIGN_STR (bytes) : ALIGN_4 (bytes));
#endif

  ptr = (unsigned char *) dk_alloc_mmap (align_bytes);
  if (!ptr)
    return (box_t) ptr;

#ifdef DOUBLE_ALIGN
  ptr += 4;
#endif

#ifdef _DEBUG
  box_types_alloc[(unsigned) tag]++;
#endif
  if (bytes > 0xffffff)
    bytes = 0xffffff;				 /* safety.  If overflowed, large box would be confused with small, now only the length is off, which is OK if length known elsewhere.  Like in cluster message serialization  */
  WRITE_BOX_HEADER (ptr, bytes, tag);
  return (box_t) ptr;
}


#undef dk_try_alloc_box
box_t
dk_try_alloc_box (size_t bytes, dtp_t tag)
{
  unsigned char *ptr = NULL;
  size_t align_bytes;

#ifdef MALLOC_DEBUG
  if (bytes & ~0xffffff)
    GPF_T1 ("box to allocate is too large");
#endif

  /* This assumes dk_alloc aligns at least at 4 */
#ifdef DOUBLE_ALIGN
  align_bytes = 8 + (IS_STRING_ALIGN_DTP (tag) ? ALIGN_STR (bytes) : ALIGN_8 (bytes));
#else
  align_bytes = 4 + (IS_STRING_ALIGN_DTP (tag) ? ALIGN_STR (bytes) : ALIGN_4 (bytes));
#endif

  if (align_bytes >= box_min_mmap)
    ptr = dk_alloc_mmap (align_bytes);
  else
  ptr = (unsigned char *) dk_try_alloc (align_bytes);
  if (!ptr)
    return (box_t) ptr;

#ifdef _DEBUG
  box_types_alloc[(unsigned) tag]++;
#endif

#ifdef DOUBLE_ALIGN
  ptr += 4;
#endif

  WRITE_BOX_HEADER (ptr, bytes, tag);
  /* memset (ptr, 0, bytes); */
  return (box_t) ptr;
}


#undef dk_alloc_box_zero
box_t
dk_alloc_box_zero (size_t bytes, dtp_t tag)
{
  unsigned char *ptr;
  size_t align_bytes;

  /* This assumes dk_alloc aligns at least at 4 */
#ifdef DOUBLE_ALIGN
  align_bytes = 8 + (IS_STRING_ALIGN_DTP (tag) ? ALIGN_STR (bytes) : ALIGN_8 (bytes));
#else
  align_bytes = 4 + (IS_STRING_ALIGN_DTP (tag) ? ALIGN_STR (bytes) : ALIGN_4 (bytes));
#endif

  ptr = (unsigned char *) dk_alloc_mmap (align_bytes);
  if (!ptr)
    return (box_t) ptr;

#ifdef DOUBLE_ALIGN
  ptr += 4;
#endif

#ifdef _DEBUG
  box_types_alloc[tag]++;
#endif

  WRITE_BOX_HEADER (ptr, bytes, tag);
  memset (ptr, 0, bytes);

  return (box_t) ptr;
}


#ifdef MALLOC_DEBUG
box_t
dbg_dk_alloc_box (DBG_PARAMS size_t bytes, dtp_t tag)
{
  unsigned char *ptr;
  uint32 align_bytes;

  /* This assumes dk_alloc aligns at least at 4 */
#ifdef DOUBLE_ALIGN
  align_bytes = 8 + (IS_STRING_ALIGN_DTP (tag) ? ALIGN_STR (bytes) : ALIGN_8 (bytes));
#else
  align_bytes = 4 + (IS_STRING_ALIGN_DTP (tag) ? ALIGN_STR (bytes) : ALIGN_4 (bytes));
#endif

  ptr = (unsigned char *) dbg_malloc (DBG_ARGS align_bytes);
  if (!ptr)
    return (box_t) ptr;

#ifdef DOUBLE_ALIGN
  ptr += 4;
#endif

#ifdef _DEBUG
  box_types_alloc[tag]++;
#endif

  WRITE_BOX_HEADER (ptr, bytes, tag);
  /* memset (ptr, 0x00, bytes); */

  return (box_t) ptr;
}


box_t
dbg_dk_alloc_box_long (DBG_PARAMS size_t bytes, dtp_t tag)
{
  unsigned char *ptr;
  uint32 align_bytes;

  /* This assumes dk_alloc aligns at least at 4 */
#ifdef DOUBLE_ALIGN
  align_bytes = 8 + (IS_STRING_ALIGN_DTP (tag) ? ALIGN_STR (bytes) : ALIGN_8 (bytes));
#else
  align_bytes = 4 + (IS_STRING_ALIGN_DTP (tag) ? ALIGN_STR (bytes) : ALIGN_4 (bytes));
#endif

  ptr = (unsigned char *) dbg_malloc (DBG_ARGS align_bytes);
  if (!ptr)
    return (box_t) ptr;

#ifdef DOUBLE_ALIGN
  ptr += 4;
#endif

#ifdef _DEBUG
  box_types_alloc[tag]++;
#endif
  if (bytes > 0xffffff)
    bytes = 0xffffff;				 /* safety.  If overflowed, large box would be confused with small, now only the length is off, which is OK if length known elsewhere.  Like in cluster message serialization  */

  WRITE_BOX_HEADER (ptr, bytes, tag);
  /* memset (ptr, 0x00, bytes); */

  return (box_t) ptr;
}


box_t
dbg_dk_try_alloc_box (DBG_PARAMS size_t bytes, dtp_t tag)
{
  unsigned char *ptr;
  uint32 align_bytes;

  /* This assumes dk_alloc aligns at least at 4 */
#ifdef DOUBLE_ALIGN
  align_bytes = 8 + (IS_STRING_ALIGN_DTP (tag) ? ALIGN_STR (bytes) : ALIGN_8 (bytes));
#else
  align_bytes = 4 + (IS_STRING_ALIGN_DTP (tag) ? ALIGN_STR (bytes) : ALIGN_4 (bytes));
#endif

  ptr = (unsigned char *) dbg_malloc (DBG_ARGS align_bytes);
  if (!ptr)
    return (box_t) ptr;

#ifdef DOUBLE_ALIGN
  ptr += 4;
#endif

#ifdef _DEBUG
  box_types_alloc[tag]++;
#endif

  WRITE_BOX_HEADER (ptr, bytes, tag);
  /* memset (ptr, 0x00, bytes); */

  return (box_t) ptr;
}


box_t
dbg_dk_alloc_box_zero (DBG_PARAMS size_t bytes, dtp_t tag)
{
  unsigned char *ptr;
  uint32 align_bytes;

  /* This assumes dk_alloc aligns at least at 4 */
#ifdef DOUBLE_ALIGN
  align_bytes = 8 + (IS_STRING_ALIGN_DTP (tag) ? ALIGN_STR (bytes) : ALIGN_8 (bytes));
#else
  align_bytes = 4 + (IS_STRING_ALIGN_DTP (tag) ? ALIGN_STR (bytes) : ALIGN_4 (bytes));
#endif

  ptr = (unsigned char *) dbg_malloc (DBG_ARGS align_bytes);
  if (!ptr)
    return (box_t) ptr;

#ifdef DOUBLE_ALIGN
  ptr += 4;
#endif

#ifdef _DEBUG
  box_types_alloc[tag]++;
#endif

  WRITE_BOX_HEADER (ptr, bytes, tag);
  memset (ptr, 0x0, bytes);

  return (box_t) ptr;
}
#endif /* MALLOC_DEBUG */


box_destr_f box_destr[256];
box_copy_f box_copier[256];
box_tmp_copy_f box_tmp_copier[256];
char box_can_appear_twice_in_tree[256];


caddr_t
box_non_copiable (caddr_t b)
{
  return NULL;
}


caddr_t
box_copy_non_box (caddr_t b)
{
  GPF_T;
  return NULL;
}


caddr_t
box_mp_copy_non_box (mem_pool_t * mp, caddr_t b)
{
  GPF_T;
  return NULL;
}


void
dk_mem_hooks (dtp_t tag, box_copy_f c, box_destr_f d, int bcatit)
{
  if (box_destr[tag] && d && d != box_destr[tag]) GPF_T1 ("redefining mem hooks");
  box_destr[tag] = d;
  box_copier[tag] = c;
  box_tmp_copier[tag] = NULL;
  box_can_appear_twice_in_tree[tag] = bcatit;
}


void
dk_mem_hooks_2 (dtp_t tag, box_copy_f c, box_destr_f d, int bcatit, box_tmp_copy_f t_c)
{
  if (box_destr[tag] && d && d != box_destr[tag]) GPF_T1 ("redefining mem hooks");
  box_destr[tag] = d;
  box_copier[tag] = c;
  box_can_appear_twice_in_tree[tag] = bcatit;
  box_tmp_copier[tag] = t_c;
}


int
dk_free_box (box_t box)
{
  uint32 len;
  dtp_t *ptr;
  dtp_t tag;

  if (!IS_BOX_POINTER (box))
    return 0;

  ptr = (unsigned char *) box;

  len = box_length_inline (ptr);
  tag = box_tag (ptr);

  switch (tag)
    {
#ifdef MALLOC_DEBUG
    case DV_WIDE:
      if ((len % sizeof (wchar_t)) || (0 != ((wchar_t *)box)[len/sizeof (wchar_t) - 1]))
        GPF_T1 ("Free of a damaged wide string");
#ifdef DOUBLE_ALIGN
      len = ALIGN_8 (len);
#else
      len = ALIGN_4 (len);
#endif
      break;
#endif
    case DV_STRING:
    case DV_C_STRING:
    case DV_SHORT_STRING_SERIAL:
    case DV_SYMBOL:
      len = ALIGN_STR (len);
      break;

    case DV_UNAME:
      {
	uint32 hash;
	uname_chain_pair_t *cpair;
	uname_blk_t *blk;
#ifdef MALLOC_DEBUG
	uname_blk_t **blk_ptr;
	mutex_enter (uname_mutex);
	BYTE_BUFFER_HASH (hash, box, len - 1);
	cpair = unames + (hash % UNAME_TABLE_SIZE);
	for (blk = cpair->unc_immortals; NULL != blk; blk = blk->unb_next)
	  {
	    if (blk->unb_data_ptr != box)
	      continue;
	    mutex_leave (uname_mutex);
	    return 0;
	  }
#ifdef DV_UNAME_UNIT_DEBUG
	cpair->unc_refcount--;
#endif
	for (blk_ptr = &(cpair->unc_refcounted); (NULL != (blk = blk_ptr[0])); blk_ptr = &(blk->unb_next))
	  {
	    if (blk->unb_data_ptr != box)
	      continue;
	    if (0 < (--(blk->unb_hdr[UNB_HDR_REFCTR])))
	      {
		box_dv_uname_audit_one (hash);
		mutex_leave (uname_mutex);
		return 0;
	      }
#ifdef DV_UNAME_UNIT_DEBUG
	    cpair->unc_count--;
#endif
	    blk_ptr[0] = blk->unb_next;
#ifndef DV_UNAME_KEEP_ALL
	    box_tag_modify_impl (box, DV_NULL);
	    dk_free_box (box);
	    dk_free (blk, sizeof (uname_blk_t));
#endif
	    box_dv_uname_audit_one (hash);
	    mutex_leave (uname_mutex);
	    return 0;
	  }
	GPF_T1 ("Can't free broken UNAME");
#else
	blk = UNAME_TO_UNAME_BLK (box);
	if (UNAME_LOCK_REFCOUNT <= blk->unb_hdr[UNB_HDR_REFCTR])
	  return 0;
	mutex_enter (uname_mutex);
#ifdef DV_UNAME_UNIT_DEBUG
	unames[blk->unb_hdr[UNB_HDR_HASH] % UNAME_TABLE_SIZE].unc_refcount--;
#endif
	if ((UNAME_LOCK_REFCOUNT <= blk->unb_hdr[UNB_HDR_REFCTR]) ||
	    (0 < (--(blk->unb_hdr[UNB_HDR_REFCTR]))))
	  {
	    box_dv_uname_audit_one (blk->unb_hdr[UNB_HDR_HASH]);
	    mutex_leave (uname_mutex);
	    return 0;
	  }
	hash = blk->unb_hdr[UNB_HDR_HASH];
	cpair = unames + (hash % UNAME_TABLE_SIZE);
#ifdef DV_UNAME_UNIT_DEBUG
	cpair->unc_count--;
#endif
	if (blk == cpair->unc_refcounted)
	  cpair->unc_refcounted = blk->unb_next;
	else
	  {
	    uname_blk_t *prev_in_chain = cpair->unc_refcounted;
	    while (prev_in_chain->unb_next != blk)
	      prev_in_chain = prev_in_chain->unb_next;
	    prev_in_chain->unb_next = blk->unb_next;
	  }
#ifndef DV_UNAME_KEEP_ALL
	dk_free (blk, sizeof (uname_blk_t) + (len - sizeof (ptrlong)));
#endif
	box_dv_uname_audit_one (hash);
	mutex_leave (uname_mutex);
#endif
	return 0;
      }

    case DV_REFERENCE:
      return 0;

    case TAG_FREE:
      GPF_T1 ("Double free");

    case TAG_BAD:
      GPF_T1 ("free of box marked bad");

    default:
      if (box_destr[tag])
	if (0 != box_destr[tag] (box))
	  return 0;
#ifdef DOUBLE_ALIGN
      len = ALIGN_8 (len);
#else
      len = ALIGN_4 (len);
#endif
    }

#ifndef NDEBUG
  ptr[-1] = TAG_FREE;
#endif

#ifdef DOUBLE_ALIGN
#ifdef MALLOC_DEBUG
  if (len >= 0xffffff)
    {
      dbg_free (__FILE__, __LINE__, ptr - 8);
      return 0;
    }
#endif
  dk_free_munmap (ptr - 8, len + 8);
#else
  dk_free_munmap (ptr - 4, len + 4);
#endif
#ifdef _DEBUG
  box_types_free[tag]++;
#endif
  return (0);
}


void
dkbox_terminate_module (void)
{
  int uname_cpair_ctr;
  for (uname_cpair_ctr = UNAME_TABLE_SIZE; uname_cpair_ctr--; /* no step */ )
    {
      uname_chain_pair_t *cpair = unames + uname_cpair_ctr;
      while (NULL != cpair->unc_immortals)
	{
	  uname_blk_t *first_imm = cpair->unc_immortals;
	  cpair->unc_immortals = first_imm->unb_next;
	  first_imm->unb_hdr[UNB_HDR_REFCTR] = 1;
	  first_imm->unb_next = cpair->unc_refcounted;
	  cpair->unc_refcounted = first_imm;
	}
      while (NULL != cpair->unc_refcounted)
	{
	  cpair->unc_refcounted->unb_hdr[UNB_HDR_REFCTR] = 1;
#ifdef MALLOC_DEBUG
	  dk_free_box (cpair->unc_refcounted->unb_data_ptr);
#else
	  dk_free_box (cpair->unc_refcounted->unb_data);
#endif
	}
    }
}

#if defined (WIN32) || defined (SOLARIS)
#define __builtin_prefetch(m)
#endif

int
dk_free_tree (box_t box)
{
  uint32 len;
  dtp_t *ptr;
  dtp_t tag;

  if (!IS_BOX_POINTER (box))
    return 0;

  ptr = (unsigned char *) box;

  len = box_length_inline (ptr);
  tag = box_tag (ptr);

  switch (tag)
    {
#ifdef MALLOC_DEBUG
    case DV_WIDE:
      if ((len % sizeof (wchar_t)) || (0 != ((wchar_t *)box)[len/sizeof (wchar_t) - 1]))
        GPF_T1 ("Free of a tree with a damaged wide string");
#ifdef DOUBLE_ALIGN
      len = ALIGN_8 (len);
#else
      len = ALIGN_4 (len);
#endif
      break;
#endif
    case DV_STRING:
    case DV_C_STRING:
    case DV_SHORT_STRING_SERIAL:
    case DV_SYMBOL:
      len = ALIGN_STR (len);
      break;

    case DV_ARRAY_OF_POINTER:
    case DV_LIST_OF_POINTER:
    case DV_ARRAY_OF_XQVAL:
    case DV_XTREE_HEAD:
    case DV_XTREE_NODE:
      {
	uint32 count = len / sizeof (box_t), inx = 0;
	box_t *obj = (box_t *) box;
	if (count > 3)
	  {
	    for (inx = 0; inx < count - 3; inx += 2)
	      {
		__builtin_prefetch (obj[inx + 2]);
		__builtin_prefetch (obj[inx + 3]);
		dk_free_tree (obj[inx]);
		dk_free_tree (obj[inx + 1]);
	      }
	  }
	for (inx = inx; inx < count; inx++)
	  dk_free_tree (obj[inx]);
#ifdef MALLOC_DEBUG
	if (len != ALIGN_4 (len))
	  GPF_T;
#endif
	break;
      }

    case DV_UNAME:
      dk_free_box (box);
      return 0;

    case DV_REFERENCE:
      return 0;

#ifndef NDEBUG
    case TAG_FREE:
      GPF_T1 ("Double free");

    case TAG_BAD:
      GPF_T1 ("Free of box marked bad");
#endif

    default:
      if (box_destr[tag])
	if (0 != box_destr[tag] (box))
	  return 0;
#ifdef DOUBLE_ALIGN
      len = ALIGN_8 (len);
#else
      len = ALIGN_4 (len);
#endif
    }

#ifndef NDEBUG
  ptr[-1] = TAG_FREE;
#endif

#ifdef DOUBLE_ALIGN
  dk_free_munmap (ptr - 8, len + 8);
#else
  dk_free_munmap (ptr - 4, len + 4);
#endif
#ifdef _DEBUG
  box_types_free[tag]++;
#endif

  return (0);

}


void
box_reuse (caddr_t box, ccaddr_t data, size_t len, dtp_t dtp)
{
  dk_alloc_box_assert (box);
  box_tag_modify (box, dtp);
  ((dtp_t *) box)[-4] = (dtp_t) (len & 0xff);
  ((dtp_t *) box)[-3] = (dtp_t) (len >> 8);
  ((dtp_t *) box)[-2] = (dtp_t) (len >> 16);
  if (DV_STRING == dtp) len --; /* the length of string box is always +1 but actual data is one char less */
  if (box != data)
  memcpy (box, data, len);
}


#ifdef DK_ALLOC_BOX_DEBUG
void
dk_check_tree_iter (box_t box, box_t parent, dk_hash_t * known)
{
  uint32 count;
  dtp_t tag;
  if (!IS_BOX_POINTER (box))
    return;
  dk_alloc_box_assert (box);
  tag = box_tag (box);
  if ((DV_UNAME == tag) || (DV_REFERENCE == tag))
    return;
  if (TAG_FREE == tag)
    GPF_T1 ("Tree contains a pointer to a freed box");
  if (TAG_BAD == tag)
    GPF_T1 ("Tree contains a pointer to a box marked bad");
  if (!box_can_appear_twice_in_tree[tag])
    {
      box_t other_parent = gethash (box, known);
      if (NULL != other_parent)
	GPF_T;
      sethash (box, known, parent);
    }
  if (IS_NONLEAF_DTP (tag))
    {
      box_t *obj = (box_t *) box;
      for (count = box_length (box) / sizeof (box_t); count; count--)
	dk_check_tree_iter (*obj++, box, known);
    }
  return;
}


void
dk_check_tree (box_t box)
{
  dk_hash_t *known = hash_table_allocate (4096);
  dk_check_tree_iter (box, BADBEEF_BOX, known);
  hash_table_free (known);
}

void
dk_check_tree_heads_iter (box_t box, box_t parent, dk_hash_t * known, int count_of_sample_children)
{
  uint32 count;
  dtp_t tag;
  if (!IS_BOX_POINTER (box))
    return;
  dk_alloc_box_assert (box);
  tag = box_tag (box);
  if ((DV_UNAME == tag) || (DV_REFERENCE == tag))
    return;
  if (TAG_FREE == tag)
    GPF_T1 ("Tree contains a pointer to a freed box");
  if (TAG_BAD == tag)
    GPF_T1 ("Tree contains a pointer to a box marked bad");
  if (tag < FIRST_DV_DTP)
    GPF_T1 ("Tree contains a pointer to a Box with weird tag");
  if (!box_can_appear_twice_in_tree[tag])
    {
      box_t other_parent = gethash (box, known);
      if (NULL != other_parent)
	GPF_T;
      sethash (box, known, parent);
    }
  if (IS_NONLEAF_DTP (tag))
    {
      box_t *obj = (box_t *) box;
      count = box_length (box) / sizeof (box_t);
      if (count > count_of_sample_children)
        count = count_of_sample_children;
      for (/* no init*/; count; count--)
	dk_check_tree_heads_iter (*obj++, box, known, count_of_sample_children);
    }
  return;
}

void dk_check_tree_heads (box_t box, int count_of_sample_children)
{
  dk_hash_t *known = hash_table_allocate (4096);
  dk_check_tree_heads_iter (box, BADBEEF_BOX, known, count_of_sample_children);
  hash_table_free (known);
}

void
dk_check_domain_of_connectivity_iter (box_t box, box_t parent, dk_hash_t * known)
{
  uint32 count;
  dtp_t tag;
  box_t other_parent;
  if (!IS_BOX_POINTER (box))
    return;
  dk_alloc_box_assert (box);
  tag = box_tag (box);
  if ((DV_UNAME == tag) || (DV_REFERENCE == tag))
    return;
  if (TAG_FREE == tag)
    GPF_T1 ("Domain of connectivity contains a pointer to a freed box");
  if (TAG_BAD == tag)
    GPF_T1 ("Domain of connectivity contains a pointer to a box marked bad");
  if (IS_NONLEAF_DTP (tag))
    {
      box_t *obj = (box_t *) box;
      for (count = box_length (box) / sizeof (box_t); count; count--)
	dk_check_domain_of_connectivity_iter (*obj++, box, known);
    }
  other_parent = gethash (box, known);
  if (NULL != other_parent)
    return;
  sethash (box, known, parent);
  return;
}


void
dk_check_domain_of_connectivity (box_t box)
{
  dk_hash_t *known = hash_table_allocate (4096);
  dk_check_domain_of_connectivity_iter (box, BADBEEF_BOX, known);
  hash_table_free (known);
}
#endif

/*
 * Free the box.
 * If the box is an array of pointer, free all number boxes
 * DV_LONG_INT referenced from it.
 */
int
dk_free_box_and_numbers (box_t box)
{
  if (IS_BOX_POINTER (box))
    {
      unsigned int tag = box_tag (box);	/* TAMMI mty */
      if (tag == TAG_FREE)
	return (0);
      if (IS_NONLEAF_DTP (tag))
	{
	  unsigned int n, tg;	/* TAMMI mty 2 below */
	  unsigned int length = box_length ((caddr_t) box) / sizeof (caddr_t);
	  /* box_tag (box) = TAG_BEING_FREED; */
	  for (n = 0; n < length; n++)
	    {
	      caddr_t data = ((caddr_t *) box)[n];
	      if (IS_BOX_POINTER (data) &&
		  ((tg = box_tag (data)) == DV_LONG_INT ||
		    tg == DV_C_STRING ||
		    tg == DV_DOUBLE_FLOAT ||
		    tg == DV_SINGLE_FLOAT))
		dk_free_box (data);
	    };
	  dk_free_box (box);
	}
      else
	dk_free_box (box);
    };
  return (0);
}


int
dk_free_box_and_int_boxes (box_t box)
{
  uint32 count;
  dtp_t tag;

  if (!IS_BOX_POINTER (box))
    return 0;

  tag = box_tag (box);
  if (IS_NONLEAF_DTP (tag))
    {
      box_t *obj = (box_t *) box;
      for (count = BOX_ELEMENTS (box); count; count--)
	{
	  if (IS_BOX_POINTER (*obj) && box_tag (*obj) == DV_LONG_INT)
	    dk_free_box (*obj);
	  obj++;
	}
    }

  dk_free_box (box);

  return 0;
}


/* Number Boxes */

boxint
unbox (ccaddr_t box)
{
  if (!IS_BOX_POINTER (box))
    return (boxint) (ptrlong) box;

  if (box_tag (box) == DV_LONG_INT)
    return *(boxint *) box;

  return (boxint) (ptrlong) box;
}


ptrlong
unbox_ptrlong (ccaddr_t box)
{
  if (!IS_BOX_POINTER (box))
    return (ptrlong) box;

  if (box_tag (box) == DV_LONG_INT)
    {
      boxint bi = *(boxint *) box;
#ifdef DEBUG
      if ((sizeof (ptrlong) < sizeof (boxint)))
	{
	  boxint upper_bits = bi >> (8 * sizeof (ptrlong));
	  if ((0 != upper_bits) && (-1 != upper_bits))
	    GPF_T1 ("ptrlong overflow in unbox_ptrlong");
	}
#endif
      return bi;
    }
  return (boxint) ((ptrlong) box);
}


int64
unbox_int64 (ccaddr_t box)
{
  if (!IS_BOX_POINTER (box))
    return (int64) (ptrlong) box;

  if (box_tag (box) == DV_LONG_INT)
    return *(boxint *) box;
  return (ptrlong) box;
}


box_t
DBG_NAME (box_num) (DBG_PARAMS boxint n)
{
  box_t *box;
  if (!IS_BOXINT_POINTER (n))
    return (box_t) (ptrlong) n;
  box = (box_t *) DBG_NAME (dk_alloc_box) (DBG_ARGS sizeof (boxint), DV_LONG_INT);
  *(boxint *) box = n;
  return (box_t) (ptrlong) box;
}


box_t
DBG_NAME (box_num_nonull) (DBG_PARAMS boxint n)
{
  box_t *box;
  if (n && !IS_BOXINT_POINTER (n))
    return (box_t) (ptrlong) n;
  box = (box_t *) DBG_NAME (dk_alloc_box) (DBG_ARGS sizeof (boxint), DV_LONG_INT);
  *(boxint *) box = n;
  return (box_t) box;
}


box_t
DBG_NAME (box_iri_id) (DBG_PARAMS int64 n)
{
  iri_id_t * box = (iri_id_t*) DBG_NAME (dk_alloc_box) (DBG_ARGS sizeof (iri_id_t), DV_IRI_ID);
  *box = n;
  return (caddr_t) box;
}




/*
 * Box a null-terminated string into a
 * DV_<XX>_STRING tagged box
 */
#undef box_string

box_t
DBG_NAME (box_string) (DBG_PARAMS const char *string)
{
  uint32 len;
  box_t box;

  if (!string)
    return NULL;

  len = (uint32) strlen (string) + 1;
  box = DBG_NAME (dk_alloc_box) (DBG_ARGS len, DV_C_STRING);
  memcpy (box, string, len);

  return box;
}


box_t
DBG_NAME (box_copy) (DBG_PARAMS cbox_t box)
{
  dtp_t tag;
  uint32 len;
  box_t copy;

  if (!IS_BOX_POINTER (box))
    return (box_t) box;

  tag = box_tag (box);
  switch (tag)
    {
    case DV_WIDE:
#ifdef MALLOC_DEBUG
      len = box_length (box);
      if ((len % sizeof (wchar_t)) || (0 != ((wchar_t *)box)[len/sizeof (wchar_t) - 1]))
        GPF_T1 ("Copy of a damaged wide string");
      break;
#endif
    case DV_STRING:
    case DV_ARRAY_OF_POINTER:
    case DV_LIST_OF_POINTER:
    case DV_ARRAY_OF_XQVAL:
    case DV_XTREE_HEAD:
    case DV_XTREE_NODE:
      break;

    case DV_UNAME:
      {
	uint32 hash;
	uname_chain_pair_t *cpair;
	uname_blk_t *blk;
#ifdef MALLOC_DEBUG
	uname_blk_t **blk_ptr;
	len = box_length (box) - 1;
	BYTE_BUFFER_HASH (hash, box, len);
	cpair = unames + (hash % UNAME_TABLE_SIZE);
	mutex_enter (uname_mutex);
	for (blk = cpair->unc_immortals; NULL != blk; blk = blk->unb_next)
	  {
	    if (blk->unb_data_ptr == box)
	      {
		mutex_leave (uname_mutex);
		return box;
	      }
	  }
#ifdef DV_UNAME_UNIT_DEBUG
	cpair->unc_refcount++;
#endif
	for (blk_ptr = &cpair->unc_refcounted; (NULL != (blk = blk_ptr[0])); blk_ptr = &(blk->unb_next))
	  {
	    if (blk->unb_data_ptr != box)
	      continue;
	    if (UNAME_LOCK_REFCOUNT <= (++(blk->unb_hdr[UNB_HDR_REFCTR])))
	      {
		blk_ptr[0] = blk->unb_next;
		blk->unb_next = cpair->unc_immortals;
		cpair->unc_immortals = blk;
		blk->unb_hdr[UNB_HDR_REFCTR] = UNAME_LOCK_REFCOUNT;
	      }
	    box_dv_uname_audit_one (hash);
	    mutex_leave (uname_mutex);
	    return box;
	  }
	GPF_T1 ("Can't copy broken UNAME");
#else
	blk = UNAME_TO_UNAME_BLK (box);
	if (UNAME_LOCK_REFCOUNT <= blk->unb_hdr[UNB_HDR_REFCTR])
	  return (box_t) box;
#ifdef DV_UNAME_UNIT_DEBUG
	unames[blk->unb_hdr[UNB_HDR_HASH] % UNAME_TABLE_SIZE].unc_refcount++;
#endif
	mutex_enter (uname_mutex);
	if (UNAME_LOCK_REFCOUNT <= blk->unb_hdr[UNB_HDR_REFCTR])
	  {
	    /* See if it is already immortal inside the mtx.  Else two threads can decide to make it immortal one after the other and the second gpfs cause the uname is no longer in the refcounted list */
	    mutex_leave (uname_mutex);
	    return (box_t) box;
	  }

	if (UNAME_LOCK_REFCOUNT > (++(blk->unb_hdr[UNB_HDR_REFCTR])))
	  {
	    box_dv_uname_audit_one (blk->unb_hdr[UNB_HDR_HASH]);
	    mutex_leave (uname_mutex);
	    return (box_t) box;
	  }
	hash = blk->unb_hdr[UNB_HDR_HASH];
	cpair = unames + (hash % UNAME_TABLE_SIZE);
	if (blk == cpair->unc_refcounted)
	  cpair->unc_refcounted = blk->unb_next;
	else
	  {
	    uname_blk_t *prev_in_chain = cpair->unc_refcounted;
	    while (prev_in_chain->unb_next != blk)
	      prev_in_chain = prev_in_chain->unb_next;
	    prev_in_chain->unb_next = blk->unb_next;
	  }
	blk->unb_next = cpair->unc_immortals;
	cpair->unc_immortals = blk;
	box_dv_uname_audit_one (hash);
	mutex_leave (uname_mutex);
#endif
	return (box_t) box;
      }

    case DV_REFERENCE:
      return (box_t) box;

#ifndef NDEBUG
    case TAG_FREE:
      GPF_T1 ("Copy of a freed box");

    case TAG_BAD:
      GPF_T1 ("Copy of a box marked bad");
#endif

    default:
#ifdef MALLOC_DEBUG
      if (tag < FIRST_DV_DTP)
        GPF_T1 ("Copy of a box with weird tag");
#endif
      if (box_copier[tag])
	return (box_copier[tag] ((caddr_t) box));
    }
  len = box_length (box);
  copy = DBG_NAME (dk_alloc_box) (DBG_ARGS len, tag);
  box_flags (copy) = box_flags (box);
  memcpy (copy, box, (uint32) len);
  return copy;
}


box_t DBG_NAME (box_copy_tree) (DBG_PARAMS cbox_t box)
{
  uint32 inx, len;
  box_t *copy;
  dtp_t tag;

  if (!IS_BOX_POINTER (box))
    return (box_t) box;

  tag = box_tag (box);
  switch (tag)
    {
#ifdef MALLOC_DEBUG
    case DV_WIDE:
      len = box_length (box);
      if ((len % sizeof (wchar_t)) || (0 != ((wchar_t *)box)[len/sizeof (wchar_t) - 1]))
        GPF_T1 ("Copy of a tree with a damaged wide string");
      break;
#endif
    case DV_ARRAY_OF_POINTER:
    case DV_LIST_OF_POINTER:
    case DV_ARRAY_OF_XQVAL:
    case DV_XTREE_HEAD:
    case DV_XTREE_NODE:
      len = box_length (box);
      copy = (box_t *) DBG_NAME (dk_alloc_box) (DBG_ARGS len, tag);
      len /= sizeof (box_t);
      if (len > 1)
	{
	  for (inx = 0; inx < len - 1; inx++)
	    {
	      __builtin_prefetch (((box_t*)box)[inx + 1]);
	      copy[inx] = DBG_NAME (box_copy_tree) (DBG_ARGS ((box_t *) box)[inx]);
	    }
	copy[inx] = DBG_NAME (box_copy_tree) (DBG_ARGS ((box_t *) box)[inx]);
	}
      else if (len)
        {
          copy[0] = DBG_NAME (box_copy_tree) (DBG_ARGS ((box_t *) box)[0]);
        }
      return (box_t) copy;

    case DV_UNAME:
/* TBD later: macroexpand */
      return box_copy (box);

    case DV_REFERENCE:
      return (box_t) box;

#ifndef NDEBUG
    case TAG_FREE:
      GPF_T1 ("Copy of a freed box");

    case TAG_BAD:
      GPF_T1 ("Copy of a box marked bad");

#endif
    default:
#ifdef MALLOC_DEBUG
      if (tag < FIRST_DV_DTP)
        GPF_T1 ("Copy of a box with weird tag");
#endif
      if (box_copier[tag])
	return (box_copier[tag] ((caddr_t) box));
    }
  len = box_length (box);
  copy = (box_t *) DBG_NAME (dk_alloc_box) (DBG_ARGS len, tag);
  box_flags (copy) = box_flags (box);
  memcpy (copy, box, (uint32) len);
  return (box_t) copy;
}


#ifdef NO_DK_MALLOC_RESERVE
box_t
DBG_NAME (box_try_copy) (DBG_PARAMS cbox_t box, box_t stub)
{
  box_t copy;

  if (!IS_BOX_POINTER (box))
    return box;
  if (DK_ALLOC_ON_RESERVE)
    return stub;
  copy = DBG_NAME (box_copy) (DBG_ARGS box);
  if (!DK_ALLOC_ON_RESERVE)
    return copy;
  DBG_NAME (dk_free_box) (DBG_ARGS copy);
  return stub;
}


box_t
DBG_NAME (box_try_copy_tree) (DBG_PARAMS box_t box, box_t stub)
{
  uint32 inx, len;
  box_t *copy;
  dtp_t tag;

  if (!IS_BOX_POINTER (box))
    return (box_t) box;

  if (DK_ALLOC_ON_RESERVE)
    return stub;

  tag = box_tag (box);
  switch (tag)
    {
    case DV_ARRAY_OF_POINTER:
    case DV_LIST_OF_POINTER:
    case DV_ARRAY_OF_XQVAL:
    case DV_XTREE_HEAD:
    case DV_XTREE_NODE:
      len = box_length (box);
      copy = DBG_NAME (dk_try_alloc_box) (DBG_ARGS len, tag);
      if (NULL == copy)
	return stub;
      len /= sizeof (box_t);
      for (inx = 0; inx < len; inx++)
	{
	  copy[inx] = DBG_NAME (box_try_copy_tree) (DBG_ARGS ((box_t *) box)[inx], BADBEEF_BOX);
	  if (BADBEEF_BOX == copy[inx])
	    {
	      uint32 inx1;
	      for (inx1 = 0; inx1 < inx; inx1++)
		DBG_NAME (dk_free_tree) (DBG_ARGS copy[inx1]);
	      DBG_NAME (dk_free_box) (DBG_ARGS copy);
	      return stub;
	    }
	}
      return (box_t) copy;

    case DV_UNAME:
      return box_copy (box);

    case DV_REFERENCE:
      return (box_t) box;

#ifndef NDEBUG
    case TAG_FREE:
      GPF_T1 ("Copy of a freed box");

    case TAG_BAD:
      GPF_T1 ("Copy of a box marked bad");
#endif

    default:
#ifdef MALLOC_DEBUG
      if (tag < FIRST_DV_DTP)
        GPF_T1 ("Copy of a box with weird tag");
#endif
      if (box_copier[tag])
	return (box_copier[tag] (box));
    }
  len = box_length (box);
  copy = DBG_NAME (dk_alloc_box) (DBG_ARGS len, tag);
  box_flags (copy) = box_flags (box);
  memcpy (copy, box, (uint32) len);
  return (box_t) copy;
}


#else

box_t
DBG_NAME (box_try_copy) (DBG_PARAMS cbox_t box, box_t stub)
{
  return DBG_NAME (box_copy) (DBG_ARGS box);
}


box_t
DBG_NAME (box_try_copy_tree) (DBG_PARAMS cbox_t box, box_t stub)
{
  return DBG_NAME (box_copy_tree) (DBG_ARGS box);
}
#endif


box_t
DBG_NAME (box_dv_short_string) (DBG_PARAMS const char *string)
{
  uint32 len;
  box_t box;

  if (!string)
    return NULL;

  len = (uint32) strlen (string) + 1;
  box = DBG_NAME (dk_alloc_box) (DBG_ARGS len, DV_SHORT_STRING);
  memcpy (box, string, len);

  return box;
}


rdf_box_t *
rb_allocate (void)
{
  rdf_box_t *rb = (rdf_box_t *) dk_alloc_box_zero (sizeof (rdf_bigbox_t), DV_RDF);
  rb->rb_ref_count = 1;
  return rb;
}


rdf_bigbox_t *
rbb_allocate (void)
{
  rdf_bigbox_t *rbb = (rdf_bigbox_t *) dk_alloc_box_zero (sizeof (rdf_bigbox_t), DV_RDF);
  rbb->rbb_base.rb_ref_count = 1;
  return rbb;
}


caddr_t
rbb_from_id (int64 n)
{
  rdf_bigbox_t * rbb = rbb_allocate ();
  rbb->rbb_base.rb_ro_id = n;
  rbb->rbb_base.rb_is_outlined = 1;
#if 0
  rbb->rbb_base.rb_type = RDF_BOX_ILL_TYPE;
  rbb->rbb_base.rb_lang = RDF_BOX_ILL_LANG;
#else
  rbb->rbb_base.rb_type = RDF_BOX_DEFAULT_TYPE;
  rbb->rbb_base.rb_lang = RDF_BOX_DEFAULT_LANG;
#endif
  rbb->rbb_box_dtp = DV_STRING;
  return (caddr_t)rbb;
}


void
rdf_box_audit_impl (rdf_box_t * rb)
{
  if (0 >= rb->rb_ref_count)
    GPF_T1 ("RDF box has nonpositive reference count");
#ifdef RDF_DEBUG
  if ((0 == rb->rb_ro_id) && (0 == rb->rb_is_complete))
    GPF_T1 ("RDF box is too incomplete");
#endif
  if (rb->rb_type < RDF_BOX_MIN_TYPE) GPF_T1 ("rb type out pof range");
  if (rb->rb_is_complete)
    rb_dt_lang_check(rb);
}


box_t
DBG_NAME (box_dv_short_nchars) (DBG_PARAMS const char *buf, size_t buf_len)
{
  caddr_t box;
  box = DBG_NAME (dk_alloc_box) (DBG_ARGS (uint32) (buf_len + 1), DV_SHORT_STRING);
  memcpy (box, buf, buf_len);
  box[buf_len] = '\0';
  return box;
}


box_t
DBG_NAME (box_dv_short_nchars_reuse) (DBG_PARAMS const char *buf, size_t buf_len, box_t replace)
{
  caddr_t res;
  size_t res_size = buf_len + 1;
  size_t aligned_res_size = ALIGN_STR (res_size);
  if ((DV_STRING == DV_TYPE_OF (replace)) && (ALIGN_STR (box_length (replace)) == aligned_res_size))
    {
      box_reuse (replace, (box_t) buf, res_size, DV_SHORT_STRING);
      ((caddr_t) replace)[buf_len] = '\0';
      return replace;
    }
  res = DBG_NAME (dk_alloc_box) (DBG_ARGS res_size, DV_SHORT_STRING);
  memcpy (res, buf, buf_len);
  res[buf_len] = '\0';
  dk_free_tree (replace);
  return res;
}


box_t
DBG_NAME (box_dv_short_substr) (DBG_PARAMS ccaddr_t str, int n1, int n2)
{
  int lstr = (int) (box_length (str)) - 1;
  int lres;
  char *res;
  if (n2 > lstr)
    n2 = lstr;
  lres = n2 - n1;
  if (lres <= 0)
    return (DBG_NAME (box_dv_short_string) (DBG_ARGS ""));
  res = DBG_NAME (dk_alloc_box) (DBG_ARGS lres + 1, DV_SHORT_STRING);
  memcpy (res, ((const char *) str) + n1, lres);
  res[lres] = 0;
  return res;
}


box_t
DBG_NAME (box_dv_short_concat) (DBG_PARAMS ccaddr_t box1, ccaddr_t box2)
{
  int len1 = box_length (box1) - 1;	/* Excluding trailing '\0' */
  int len2 = box_length (box2);	/* Including trailing '\0' */
  char *res = DBG_NAME (dk_alloc_box) (DBG_ARGS len1 + len2, DV_SHORT_STRING);
  memcpy (res, box1, len1);
  memcpy (res + len1, box2, len2);
  return res;
}


box_t
DBG_NAME (box_dv_short_strconcat) (DBG_PARAMS const char *str1, const char *str2)
{
  int len1 = strlen (str1);	/* Excluding trailing '\0' */
  int len2 = strlen (str2) + 1;	/* Including trailing '\0' */
  char *res = DBG_NAME (dk_alloc_box) (DBG_ARGS len1 + len2, DV_SHORT_STRING);
  memcpy (res, str1, len1);
  memcpy (res + len1, str2, len2);
  return res;
}


box_t
DBG_NAME (box_dv_wide_nchars) (DBG_PARAMS const wchar_t *buf, size_t buf_wchar_count)
{
  wchar_t *box;
  box = (wchar_t *)DBG_NAME (dk_alloc_box) (DBG_ARGS (uint32) ((buf_wchar_count + 1) * sizeof (wchar_t)), DV_WIDE);
  memcpy (box, buf, buf_wchar_count * sizeof (wchar_t));
  box[buf_wchar_count] = (wchar_t)'\0';
  return (box_t)box;
}


caddr_t
DBG_NAME (box_vsprintf) (DBG_PARAMS size_t buflen_eval, const char *format, va_list tail)
{
  char *tmpbuf;
  int res_len;
  caddr_t res;
  if (buflen_eval > 0xffff)
    buflen_eval = 0xffff;
  tmpbuf = (char *) dk_alloc (buflen_eval + 1);
  res_len = vsnprintf (tmpbuf, buflen_eval, format, tail);
  if (res_len < 0)
#ifdef DEBUG
    GPF_T1 ("formatting error in box_vsprintf");
#else
    res_len = 0;
#endif
  res = DBG_NAME (box_dv_short_nchars) (DBG_ARGS tmpbuf, MIN ((size_t) res_len, buflen_eval));
  dk_free (tmpbuf, buflen_eval + 1);
  return res;
}


#ifdef MALLOC_DEBUG
const char *box_sprintf_impl_file = "???";
int box_sprintf_impl_line;
#endif

caddr_t
box_sprintf_impl (size_t buflen_eval, const char *format, ...)
{
  va_list tail;
  caddr_t res;
  va_start (tail, format);
#ifdef MALLOC_DEBUG
  res = dbg_box_vsprintf (box_sprintf_impl_file, box_sprintf_impl_line, buflen_eval, format, tail);
#else
  res = box_vsprintf (buflen_eval, format, tail);
#endif
  va_end (tail);
  return res;
}


#ifdef MALLOC_DEBUG
box_sprintf_track_t *
box_sprintf_track (const char *file, int line)
{
  static box_sprintf_track_t ret = { box_sprintf_impl };
  box_sprintf_impl_file = file;
  box_sprintf_impl_line = line;
  return &ret;
}
#endif


box_t
DBG_NAME (box_double) (DBG_PARAMS double d)
{
  double *box = (double *) DBG_NAME (dk_alloc_box) (DBG_ARGS sizeof (double), DV_DOUBLE_FLOAT);
  *box = d;
  return (box_t) box;
}


box_t
DBG_NAME (box_float) (DBG_PARAMS float d)
{
  float *box = (float *) DBG_NAME (dk_alloc_box) (DBG_ARGS sizeof (float), DV_SINGLE_FLOAT);
  *box = d;
  return (box_t) box;
}


box_hash_cmp_func_t dtp_cmp_func[256];
box_hash_cmp_func_t dtp_strong_cmp_func[256];

void
dtp_set_cmp (dtp_t dtp, box_hash_cmp_func_t f)
{
  dtp_cmp_func[dtp] = f;
}

void
dtp_set_strong_cmp (dtp_t dtp, box_hash_cmp_func_t f)
{
  dtp_strong_cmp_func[dtp] = f;
}

int
box_equal (cbox_t b1, cbox_t b2)
{
  uint32 l1, l2;
  dtp_t b1_tag, b2_tag;
  boxint b1_long_val = 0, b2_long_val = 0;

  if (b1 == b2)
    return 1;

  if (!IS_BOX_POINTER (b1))
    {
      b1_tag = DV_LONG_INT;
      b1_long_val = (boxint) (ptrlong) b1;
    }
  else
    {
      b1_tag = box_tag (b1);
      if (b1_tag == DV_LONG_INT)
	b1_long_val = *(boxint *) b1;
    }

  if (!IS_BOX_POINTER (b2))
    {
      b2_tag = DV_LONG_INT;
      b2_long_val = (boxint) (ptrlong) b2;
    }
  else
    {
      b2_tag = box_tag (b2);
      if (b2_tag == DV_LONG_INT)
	b2_long_val = *(boxint *) b2;
    }
  if ((b1_tag == DV_RDF || b2_tag == DV_RDF) && dtp_cmp_func[DV_RDF])
    return dtp_cmp_func[DV_RDF] (b1, b2);
  if (b1_tag == DV_LONG_INT || b2_tag == DV_LONG_INT)
    {
      if (b1_tag != b2_tag)
	return 0;
      return b1_long_val == b2_long_val;
    }
  if (b1_tag == b2_tag && dtp_cmp_func[b1_tag])
    return dtp_cmp_func[b1_tag] (b1, b2);
  l1 = box_length (b1);
  l2 = box_length (b2);
  if (l1 != l2)
    return 0;

  if (IS_NONLEAF_DTP (b1_tag) && IS_NONLEAF_DTP (b2_tag))
    {
      uint32 inx;
      l1 /= sizeof (caddr_t);
      for (inx = 0; inx < l1; inx++)
	{
	  if (!box_equal (((box_t *) b1)[inx], ((box_t *) b2)[inx]))
	    return 0;
	}
      return 1;
    }
  memcmp_8 (b1, b2, l1, neq);
  return 1;
 neq:
  return 0;
  /*return (memcmp (b1, b2, l1) ? 0 : 1); */
}


int
box_strong_equal (cbox_t b1, cbox_t b2)
{
  uint32 l1, l2;
  dtp_t b1_tag, b2_tag;
  boxint b1_long_val = 0, b2_long_val = 0;

  if (b1 == b2)
    return 1;

  if (!IS_BOX_POINTER (b1))
    {
      b1_tag = DV_LONG_INT;
      b1_long_val = (boxint) (ptrlong) b1;
    }
  else
    {
      b1_tag = box_tag (b1);
      if (b1_tag == DV_LONG_INT)
	b1_long_val = *(boxint *) b1;
    }

  if (!IS_BOX_POINTER (b2))
    {
      b2_tag = DV_LONG_INT;
      b2_long_val = (boxint) (ptrlong) b2;
    }
  else
    {
      b2_tag = box_tag (b2);
      if (b2_tag == DV_LONG_INT)
	b2_long_val = *(boxint *) b2;
    }
  if (b1_tag == DV_RDF || b2_tag == DV_RDF)
    {
      if (b1_tag != DV_RDF || b2_tag != DV_RDF)
        return 0;
    }
  if (b1_tag == DV_LONG_INT || b2_tag == DV_LONG_INT)
    {
      if (b1_tag != b2_tag)
	return 0;
      return b1_long_val == b2_long_val;
    }
  if (b1_tag == b2_tag && dtp_strong_cmp_func[b1_tag])
    return dtp_strong_cmp_func[b1_tag] (b1, b2);
  l1 = box_length (b1);
  l2 = box_length (b2);
  if (l1 != l2)
    return 0;
  if (IS_NONLEAF_DTP (b1_tag) && IS_NONLEAF_DTP (b2_tag))
    {
      uint32 inx;
      l1 /= sizeof (caddr_t);
      for (inx = 0; inx < l1; inx++)
	{
	  if (!box_strong_equal (((box_t *) b1)[inx], ((box_t *) b2)[inx]))
	    return 0;
	}
      return 1;
    }
  memcmp_8 (b1, b2, l1, neq);
  return 1;
 neq:
  return 0;
}


#ifndef NDEBUG
void
dk_debug_dump_box (FILE * outfd, box_t box, int lvl)
{
  size_t count;
  box_t *arr;
  ptrlong *larr;
  double *darr;
  float *farr;
  dtp_t tag;

  fprintf (outfd, "%*.*s", lvl, lvl, "");

  if (!IS_POINTER (box))
    {
      fprintf (outfd, "immediate number " BOXINT_FMT "\n", unbox (box));
      return;
    }
  if (box == NULL)
    {
      fprintf (outfd, "NULL\n");
      return;
    }

  tag = box_tag (box);
  switch (tag)
    {
    case TAG_FREE:
      fprintf (outfd, "TAG_FREE\n");
      break;

    case DV_NULL:
      fprintf (outfd, "DV_NULL\n");
      break;

    case DV_STRING:
      fprintf (outfd, "DV_SHORT_STRING '%s'\n", (char *) box);
      break;

    case DV_C_STRING:
      fprintf (outfd, "DV_C_STRING '%s'\n", (char *) box);
      break;

    case DV_LONG_INT:
      fprintf (outfd, "DV_LONG_INT %ld\n", *(long *) box);
      break;

    case DV_SHORT_INT:
      fprintf (outfd, "DV_SHORT_INT %ld\n", *(long *) box);
      break;

    case DV_SINGLE_FLOAT:
      fprintf (outfd, "DV_SINGLE_FLOAT %f\n", (double) (*(float *) box));
      break;

    case DV_DOUBLE_FLOAT:
      fprintf (outfd, "DV_DOUBLE_FLOAT %f\n", *(double *) box);
      break;

    case DV_CHARACTER:
      fprintf (outfd, "DV_CHARACTER '%c'\n", *(char *) box);
      break;

    case DV_ARRAY_OF_POINTER:
      fprintf (outfd, "DV_ARRAY_OF_POINTER\n");
      count = BOX_ELEMENTS (box);
      arr = (box_t *) box;
      while (count--)
	dk_debug_dump_box (outfd, *arr++, lvl + 2);
      break;

    case DV_ARRAY_OF_LONG_PACKED:
      fprintf (outfd, "DV_ARRAY_OF_LONG_PACKED\n");
      count = BOX_ELEMENTS (box);
      larr = (ptrlong *) box;
      while (count--)
	fprintf (outfd, "%*.*s, %ld\n", lvl + 2, lvl + 2, "", *larr++);
      break;

    case DV_ARRAY_OF_FLOAT:
      fprintf (outfd, "DV_ARRAY_OF_FLOAT\n");
      count = BOX_ELEMENTS (box);
      farr = (float *) box;
      while (count--)
	fprintf (outfd, "%*.*s%f\n", lvl + 2, lvl + 2, "", (double) *farr++);
      break;

    case DV_ARRAY_OF_DOUBLE:
      fprintf (outfd, "DV_ARRAY_OF_DOUBLE\n");
      count = BOX_ELEMENTS (box);
      darr = (double *) box;
      while (count--)
	fprintf (outfd, "%*.*s%f\n", lvl + 2, lvl + 2, "", *darr++);
      break;

    case DV_ARRAY_OF_LONG:
      fprintf (outfd, "DV_ARRAY_OF_LONG\n");
      count = BOX_ELEMENTS (box);
      larr = (ptrlong *) box;
      while (count--)
	fprintf (outfd, "%*.*s%ld\n", lvl + 2, lvl + 2, "", *larr++);
      break;

    case DV_LIST_OF_POINTER:
      fprintf (outfd, "DV_LIST_OF_POINTER\n");
      count = BOX_ELEMENTS (box);
      arr = (box_t *) box;
      while (count--)
	dk_debug_dump_box (outfd, *arr++, lvl + 2);
      break;

    case DV_ARRAY_OF_XQVAL:
      fprintf (outfd, "DV_ARRAY_OF_XQVAL\n");
      count = BOX_ELEMENTS (box);
      arr = (box_t *) box;
      while (count--)
	dk_debug_dump_box (outfd, *arr++, lvl + 2);
      break;

    case DV_XTREE_HEAD:
      fprintf (outfd, "DV_XTREE_HEAD\n");
      count = BOX_ELEMENTS (box);
      arr = (box_t *) box;
      while (count--)
	dk_debug_dump_box (outfd, *arr++, lvl + 2);
      break;

    case DV_XTREE_NODE:
      fprintf (outfd, "DV_XTREE_NODE\n");
      count = BOX_ELEMENTS (box);
      arr = (box_t *) box;
      while (count--)
	dk_debug_dump_box (outfd, *arr++, lvl + 2);
      break;
    }
}
#endif


#ifdef dk_alloc_box_assert
#undef dk_alloc_box_assert
#endif
void
dk_alloc_box_assert (box_t box)
{
  if (TAG_FREE == box_tag (box))
    GPF_T1 ("Tree contains a pointer to a freed box");
#ifdef DOUBLE_ALIGN
  dk_alloc_assert (((char *) (box)) - 8);
#else
  dk_alloc_assert (((char *) (box)) - 4);
#endif
}


char *
DBG_NAME (box_dv_ubuf) (DBG_PARAMS size_t buf_strlen)
{
#ifdef MALLOC_DEBUG
  caddr_t uname;
  buf_strlen++;
  uname = DBG_NAME (dk_alloc_box) (DBG_ARGS buf_strlen, DV_NULL);
  box_tag_modify_impl (uname, DV_UNAME);
  return uname;
#else
  uname_blk_t *blk;
  caddr_t uname;
  caddr_t hd;
  buf_strlen++;
  blk = (uname_blk_t *) DK_ALLOC (sizeof (uname_blk_t) + (buf_strlen - sizeof (ptrlong)));
  uname = blk->unb_data;
  hd = uname - 4;
  WRITE_BOX_HEADER (hd, buf_strlen, DV_UNAME);
  return uname;
#endif
}


char *
DBG_NAME (box_dv_ubuf_or_null) (DBG_PARAMS size_t buf_strlen)
{
#ifdef MALLOC_DEBUG
  caddr_t uname;
  buf_strlen++;
  uname = DBG_NAME (dk_try_alloc_box) (DBG_ARGS buf_strlen, DV_NULL);
  if (NULL == uname)
    return NULL;
  box_tag_modify_impl (uname, DV_UNAME);
  return uname;
#else
  uname_blk_t *blk;
  caddr_t uname;
  caddr_t hd;
  buf_strlen++;
  blk = (uname_blk_t *) dk_try_alloc (sizeof (uname_blk_t) + (buf_strlen - sizeof (ptrlong)));
  if (NULL == blk)
    return NULL;
  uname = blk->unb_data;
  hd = uname - 4;
  WRITE_BOX_HEADER (hd, buf_strlen, DV_UNAME);
  return uname;
#endif
}


box_t
DBG_NAME (box_dv_uname_from_ubuf) (DBG_PARAMS char *text)
{
  uint32 hash;
  char *uname;
  size_t boxlen = box_length (text);
  uname_blk_t *blk, *old_persistent_chain_head;
  uname_chain_pair_t *cpair;
#ifdef DEBUG
  if (strlen (text) != boxlen - 1)
    GPF_T1 ("text length of a uname does not match its buffer size");
#endif
  BYTE_BUFFER_HASH (hash, text, boxlen - 1);
  cpair = unames + (hash % UNAME_TABLE_SIZE);
  old_persistent_chain_head = cpair->unc_immortals;
  for (blk = old_persistent_chain_head; NULL != blk; blk = blk->unb_next)
    {
      if ((blk->unb_hdr[UNB_HDR_HASH] != hash))
	continue;
#ifdef MALLOC_DEBUG
      uname = blk->unb_data_ptr;
#else
      uname = blk->unb_data;
#endif
      if (0 == memcmp (uname, text, boxlen))
	goto return_old_uname;
    }
  /* If not found, we should add some or increase a refcounter */
  mutex_enter (uname_mutex);
  /* This loop almost never runs: other thread puts probably same word into persistent */
  for (blk = cpair->unc_immortals; old_persistent_chain_head != blk; blk = blk->unb_next)
    {
      if ((blk->unb_hdr[UNB_HDR_HASH] != hash))
	continue;
#ifdef MALLOC_DEBUG
      uname = blk->unb_data_ptr;
#else
      uname = blk->unb_data;
#endif
      if (0 == memcmp (uname, text, boxlen))
	{
	  mutex_leave (uname_mutex);
	  goto return_old_uname;
	}
    }
#ifdef DV_UNAME_UNIT_DEBUG
  cpair->unc_refcount++;
#endif
  for (blk = cpair->unc_refcounted; NULL != blk; blk = blk->unb_next)
    {
      if ((blk->unb_hdr[UNB_HDR_HASH] != hash))
	continue;
#ifdef MALLOC_DEBUG
      uname = blk->unb_data_ptr;
#else
      uname = blk->unb_data;
#endif
      if (0 != memcmp (uname, text, boxlen))
	continue;
      if (UNAME_LOCK_REFCOUNT <= (++(blk->unb_hdr[UNB_HDR_REFCTR])))
	{					 /* Uname is popular enough to become immortal */
	  if (blk == cpair->unc_refcounted)
	    cpair->unc_refcounted = blk->unb_next;
	  else
	    {
	      uname_blk_t *prev_in_chain = cpair->unc_refcounted;
	      while (prev_in_chain->unb_next != blk)
		prev_in_chain = prev_in_chain->unb_next;
	      prev_in_chain->unb_next = blk->unb_next;
	    }
	  blk->unb_next = cpair->unc_immortals;
	  cpair->unc_immortals = blk;
	}
      box_dv_uname_audit_one (hash);
      mutex_leave (uname_mutex);
      goto return_old_uname;
    }
#ifdef DV_UNAME_UNIT_DEBUG
  cpair->unc_count++;
#endif
#ifdef MALLOC_DEBUG
  blk = (uname_blk_t *) DK_ALLOC (sizeof (uname_blk_t));
  blk->unb_data_ptr = text;
  {
    char *hd = ((char *) (blk->unb_hdr + UNB_HDR_BOXHEAD));
    WRITE_BOX_HEADER (hd, boxlen, DV_UNAME);
  }
#else
  blk = UNAME_TO_UNAME_BLK (text);
#endif
  blk->unb_next = cpair->unc_refcounted;
  cpair->unc_refcounted = blk;
  blk->unb_hdr[UNB_HDR_HASH] = hash;
  blk->unb_hdr[UNB_HDR_REFCTR] = 1;
  box_dv_uname_audit_one (hash);
  mutex_leave (uname_mutex);
  return text;

return_old_uname:
#ifdef MALLOC_DEBUG
  box_tag_modify_impl (text, DV_NULL);
  dk_free_box (text);
#else
  DK_FREE (UNAME_TO_UNAME_BLK (text), sizeof (uname_blk_t) + boxlen - sizeof (ptrlong));
#endif
  box_dv_uname_audit_one (hash);
  return (box_t) uname;
}


box_t
DBG_NAME (box_dv_uname_nchars) (DBG_PARAMS const char *text, size_t len)
{
  uint32 hash;
  char *uname;
  uname_blk_t *blk, *old_persistent_chain_head;
  uname_chain_pair_t *cpair;
  uint32 boxhead[2];
  boxhead[0] = 0;
  boxhead[1] = 0;
  BYTE_BUFFER_HASH (hash, text, len);
  {
    size_t bytes = len + 1;
    char *hd = ((char *) (&boxhead[1]));
    WRITE_BOX_HEADER (hd, bytes, DV_UNAME);
  }
  cpair = unames + (hash % UNAME_TABLE_SIZE);
  old_persistent_chain_head = cpair->unc_immortals;
  for (blk = old_persistent_chain_head; NULL != blk; blk = blk->unb_next)
    {
      if ((blk->unb_hdr[UNB_HDR_HASH] != hash))
	continue;
      if ((blk->unb_hdr[UNB_HDR_BOXHEAD] != boxhead[1]))
	continue;
#ifdef MALLOC_DEBUG
      uname = blk->unb_data_ptr;
#else
      uname = blk->unb_data;
#endif
      if (0 == memcmp (uname, text, len))
	return (box_t) uname;
    }
  /* If not found, we should add some or increase a refcounter */
  mutex_enter (uname_mutex);
  /* This loop almost never runs: other thread puts probably same word into persistent */
  for (blk = cpair->unc_immortals; old_persistent_chain_head != blk; blk = blk->unb_next)
    {
      if ((blk->unb_hdr[UNB_HDR_HASH] != hash))
	continue;
      if ((blk->unb_hdr[UNB_HDR_BOXHEAD] != boxhead[1]))
	continue;
#ifdef MALLOC_DEBUG
      uname = blk->unb_data_ptr;
#else
      uname = blk->unb_data;
#endif
      if (0 == memcmp (uname, text, len))
	{
	  box_dv_uname_audit_one (hash);
	  mutex_leave (uname_mutex);
	  return (box_t) uname;
	}
    }
#ifdef DV_UNAME_UNIT_DEBUG
  cpair->unc_refcount++;
#endif
  for (blk = cpair->unc_refcounted; NULL != blk; blk = blk->unb_next)
    {
      if ((blk->unb_hdr[UNB_HDR_HASH] != hash))
	continue;
      if ((blk->unb_hdr[UNB_HDR_BOXHEAD] != boxhead[1]))
	continue;
#ifdef MALLOC_DEBUG
      uname = blk->unb_data_ptr;
#else
      uname = blk->unb_data;
#endif
      if (0 != memcmp (uname, text, len))
	continue;
      if (UNAME_LOCK_REFCOUNT <= (++(blk->unb_hdr[UNB_HDR_REFCTR])))
	{					 /* Uname is popular enough to become immortal */
	  if (blk == cpair->unc_refcounted)
	    cpair->unc_refcounted = blk->unb_next;
	  else
	    {
	      uname_blk_t *prev_in_chain = cpair->unc_refcounted;
	      while (prev_in_chain->unb_next != blk)
		prev_in_chain = prev_in_chain->unb_next;
	      prev_in_chain->unb_next = blk->unb_next;
	    }
	  blk->unb_next = cpair->unc_immortals;
	  cpair->unc_immortals = blk;
	}
      box_dv_uname_audit_one (hash);
      mutex_leave (uname_mutex);
      return (box_t) uname;
    }
#ifdef DV_UNAME_UNIT_DEBUG
  cpair->unc_count++;
#endif
#ifdef MALLOC_DEBUG
  blk = (uname_blk_t *) DK_ALLOC (sizeof (uname_blk_t));
  uname = blk->unb_data_ptr = DBG_NAME (dk_alloc_box) (DBG_ARGS len + 1, DV_NULL);
  box_tag_modify_impl (uname, DV_UNAME);
#else
  blk = (uname_blk_t *) DK_ALLOC (sizeof (uname_blk_t) + (len + 1 - sizeof (ptrlong)));
  uname = blk->unb_data;
#endif
  blk->unb_next = cpair->unc_refcounted;
  cpair->unc_refcounted = blk;
  blk->unb_hdr[UNB_HDR_HASH] = hash;
  blk->unb_hdr[UNB_HDR_REFCTR] = 1;
  blk->unb_hdr[UNB_HDR_BOXFLAGS] = boxhead[0];
  blk->unb_hdr[UNB_HDR_BOXHEAD] = boxhead[1];
  memcpy (uname, text, len);
  uname[len] = '\0';
  box_dv_uname_audit_one (hash);
  mutex_leave (uname_mutex);
  return (box_t) uname;
}


void
box_dv_uname_make_immortal (caddr_t tree)
{
  size_t len;
  uint32 hash;
  uname_chain_pair_t *cpair;
  uname_blk_t *blk;
#ifdef MALLOC_DEBUG
  uname_blk_t **blk_ptr;
#endif
  switch (DV_TYPE_OF (tree))
    {
    case DV_UNAME:
      /*printf ("\nUNAME %s is about to become immortal", tree);*/
      mutex_enter (uname_mutex);
#ifdef MALLOC_DEBUG
      len = box_length (tree) - 1;
      BYTE_BUFFER_HASH (hash, tree, len);
      cpair = unames + (hash % UNAME_TABLE_SIZE);
      for (blk = cpair->unc_immortals; NULL != blk; blk = blk->unb_next)
	{
	  if (blk->unb_data_ptr == tree)
	    {
	      mutex_leave (uname_mutex);
	      return;
	    }
	}
      for (blk_ptr = &cpair->unc_refcounted; (NULL != (blk = blk_ptr[0])); blk_ptr = &(blk->unb_next))
	{
	  if (blk->unb_data_ptr == tree)
	    {
	      blk_ptr[0] = blk->unb_next;
	      blk->unb_next = cpair->unc_immortals;
	      cpair->unc_immortals = blk;
#ifdef DV_UNAME_UNIT_DEBUG
	      cpair->unc_refcount += (UNAME_LOCK_REFCOUNT - blk->unb_hdr[UNB_HDR_REFCTR]);
#endif
	      blk->unb_hdr[UNB_HDR_REFCTR] = UNAME_LOCK_REFCOUNT;
	      box_dv_uname_audit_one (hash);
	      mutex_leave (uname_mutex);
	      return;
	    }
	}
      GPF_T1 ("Can't make broken UNAME immortal");
#else
      blk = UNAME_TO_UNAME_BLK (tree);
      if (UNAME_LOCK_REFCOUNT <= blk->unb_hdr[UNB_HDR_REFCTR])
	{
	  mutex_leave (uname_mutex);
	  return;
	}
      hash = blk->unb_hdr[UNB_HDR_HASH];
      cpair = unames + (hash % UNAME_TABLE_SIZE);
#ifdef DV_UNAME_UNIT_DEBUG
      cpair->unc_refcount += (UNAME_LOCK_REFCOUNT - blk->unb_hdr[UNB_HDR_REFCTR]);
#endif
      if (blk == cpair->unc_refcounted)
	cpair->unc_refcounted = blk->unb_next;
      else
	{
	  uname_blk_t *prev_in_chain = cpair->unc_refcounted;
	  while (prev_in_chain->unb_next != blk)
	    prev_in_chain = prev_in_chain->unb_next;
	  prev_in_chain->unb_next = blk->unb_next;
	}
      blk->unb_next = cpair->unc_immortals;
      cpair->unc_immortals = blk;
      blk->unb_hdr[UNB_HDR_REFCTR] = UNAME_LOCK_REFCOUNT;
      box_dv_uname_audit_one (hash);
      mutex_leave (uname_mutex);
#endif
      return;

    case DV_ARRAY_OF_POINTER:
    case DV_ARRAY_OF_XQVAL:
      len = BOX_ELEMENTS (tree);
      while (len-- > 0)
	{
	  caddr_t sub = ((caddr_t *) tree)[len];
	  switch (DV_TYPE_OF (sub))
	    {
	    case DV_UNAME:
	    case DV_ARRAY_OF_POINTER:
	    case DV_ARRAY_OF_XQVAL:
	      box_dv_uname_make_immortal (sub);
	    }
	}
      break;

    default:
      break;
    }
}


void
box_dv_uname_make_immortal_all (void)
{
  uname_chain_pair_t *cpair;
#ifdef DV_UNAME_STATS
  int total_immortals = 0, total_refcounted = 0;
  FILE *stats = fopen ("unames.txt", "wt");
  mutex_enter (uname_mutex);
  for (cpair = unames + UNAME_TABLE_SIZE; unames <= --cpair; /* no step */ )
    {
      int chainlen;
      uname_blk_t *blk;
/* Write refcounted */
      blk = cpair->unc_refcounted;
      chainlen = 0;
      while (NULL != blk)
	{
#ifdef MALLOC_DEBUG
	  fprintf (stats, "_uname_,_R_,%s,%ld,0x%08x\n", blk->unb_data_ptr, (long) (blk->unb_hdr[UNB_HDR_REFCTR]), blk->unb_hdr[UNB_HDR_HASH]);
#else
	  fprintf (stats, "_uname_,_R_,%s,%ld,0x%08x\n", blk->unb_data, (long) (blk->unb_hdr[UNB_HDR_REFCTR]), blk->unb_hdr[UNB_HDR_HASH]);
#endif
	  total_refcounted++;
	  chainlen++;
	  blk = blk->unb_next;
	}
      if (NULL != cpair->unc_refcounted)
	fprintf (stats, "_chain_,_R_,0x%p,%d,0x%04x\n", cpair, chainlen, cpair - unames);
/* Write immortals */
      blk = cpair->unc_immortals;
      chainlen = 0;
      while (NULL != blk)
	{
#ifdef MALLOC_DEBUG
	  fprintf (stats, "_uname_,_I_,%s,%ld,0x%08x\n", blk->unb_data_ptr, (long) (blk->unb_hdr[UNB_HDR_REFCTR]), blk->unb_hdr[UNB_HDR_HASH]);
#else
	  fprintf (stats, "_uname_,_I_,%s,%ld,0x%08x\n", blk->unb_data, (long) (blk->unb_hdr[UNB_HDR_REFCTR]), blk->unb_hdr[UNB_HDR_HASH]);
#endif
	  total_immortals++;
	  chainlen++;
	  blk = blk->unb_next;
	}
      if (NULL != cpair->unc_immortals)
	fprintf (stats, "_chain_,_I_,0x%p,%d,0x%04x\n", cpair, chainlen, cpair - unames);
    }
  fprintf (stats, "_total_,_R_,,%d,\n", total_refcounted);
  fprintf (stats, "_total_,_I_,,%d,\n", total_immortals);
  fclose (stats);
  mutex_leave (uname_mutex);
#endif
  mutex_enter (uname_mutex);
  for (cpair = unames + UNAME_TABLE_SIZE; unames <= --cpair; /* no step */ )
    {
      uname_blk_t *blk = cpair->unc_refcounted;
      while (NULL != blk)
	{
	  uname_blk_t *nxt = blk->unb_next;
#ifdef DV_UNAME_UNIT_DEBUG
	  cpair->unc_refcount += (UNAME_LOCK_REFCOUNT - blk->unb_hdr[UNB_HDR_REFCTR]);
#endif
	  blk->unb_hdr[UNB_HDR_REFCTR] = UNAME_LOCK_REFCOUNT;
	  blk->unb_next = cpair->unc_immortals;
	  cpair->unc_immortals = blk;
	  blk = nxt;
	}
      cpair->unc_refcounted = NULL;
    }
  box_dv_uname_audit_table ();
  mutex_leave (uname_mutex);
}


box_t
DBG_NAME (box_dv_uname_string) (DBG_PARAMS const char *string)
{
  return DBG_NAME (box_dv_uname_nchars) (DBG_ARGS string, strlen (string));
}


box_t
DBG_NAME (box_dv_uname_substr) (DBG_PARAMS ccaddr_t str, int n1, int n2)
{
  int lstr = (int) (box_length (str)) - 1;
  int lres;
  if (n2 > lstr)
    n2 = lstr;
  lres = n2 - n1;
  if (lres <= 0)
    return uname___empty;
  return DBG_NAME (box_dv_uname_nchars) (DBG_ARGS ((char *) str) + n1, lres);
}


caddr_t
box_mem_wrapper_copy_hook (caddr_t mw_arg)
{
  dk_mem_wrapper_t *mw = (dk_mem_wrapper_t *) (mw_arg);
  if (mw->dmw_copy)
    return (caddr_t) (mw->dmw_copy (mw->dmw_data[0]));
  return NULL;
}


int
box_mem_wrapper_destr_hook (caddr_t mw_arg)
{
  dk_mem_wrapper_t *mw = (dk_mem_wrapper_t *) (mw_arg);
  if (mw->dmw_free)
    mw->dmw_free (mw->dmw_data[0]);
  return 0;
}


caddr_t uname___empty;

void
dk_box_initialize (void)
{
  static int dk_box_is_initialized = 0;
  if (dk_box_is_initialized)
    return;
  dk_box_is_initialized = 1;
  dk_mem_hooks (DV_MEM_WRAPPER, box_mem_wrapper_copy_hook, box_mem_wrapper_destr_hook, 0);
#ifdef MALLOC_DEBUG
  dk_mem_hooks_2 (DV_NON_BOX, box_copy_non_box, NULL, 0, box_mp_copy_non_box);
#endif
  dk_mem_hooks (DV_RBUF,  box_non_copiable, rbuf_free_cb, 0);
  uname_mutex = mutex_allocate ();
  if (NULL == uname_mutex)
    GPF_T;
  uname___empty = box_dv_uname_nchars ("", 0);
  box_dv_uname_make_immortal (uname___empty);
#ifndef DV_UNAME_STATS
#ifdef DEBUG
  /* Uname trick is... well, a trick. If broken, it will cause never-catch errors. Thus check it always. */
  {
    int ctr;
    caddr_t *list1 = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * UNAME_TABLE_SIZE * 2, DV_ARRAY_OF_POINTER);
    caddr_t *list2 = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * UNAME_TABLE_SIZE * 2, DV_ARRAY_OF_POINTER);
    for (ctr = UNAME_TABLE_SIZE * 2; ctr--; /* no step */ )
      {						 /* alloc 1 */
	char buf[20];
	sprintf (buf, "uname%d", ctr);
	list1[ctr] = box_dv_uname_string (buf);
      }
    for (ctr = UNAME_TABLE_SIZE * 2; ctr--; /* no step */ )
      {						 /* alloc 2a */
	char buf[20];
	sprintf (buf, "uname%d", ctr);
	list2[ctr] = box_dv_uname_string (buf);
      }
    for (ctr = UNAME_TABLE_SIZE * 2; ctr--; /* no step */ )
      {
	if (list1[ctr] != list2[ctr])
	  GPF_T;
      }
    for (ctr = UNAME_TABLE_SIZE * 2; ctr--; /* no step */ )
      {						 /* alloc 3 */
	list2[ctr] = box_copy (list1[ctr]);
      }
    for (ctr = UNAME_TABLE_SIZE * 2; ctr--; /* no step */ )
      {
	if (list1[ctr] != list2[ctr])
	  GPF_T;
      }
    for (ctr = UNAME_TABLE_SIZE * 2; ctr--; /* no step */ )
      {						 /* free 3 */
	dk_free_box (list2[ctr]);
      }
    for (ctr = UNAME_TABLE_SIZE * 2; ctr--; /* no step */ )
      {
	char buf[20];
	sprintf (buf, "uname%d", ctr);
	if (strcmp (list1[ctr], buf))
	  GPF_T;
      }
    for (ctr = UNAME_TABLE_SIZE * 2; ctr--; /* no step */ )
      {						 /* free 2a */
	dk_free_box (list2[ctr]);
      }
    for (ctr = UNAME_TABLE_SIZE * 2; ctr--; /* no step */ )
      {
	char buf[20];
	sprintf (buf, "uname%d", ctr);
	if (strcmp (list1[ctr], buf))
	  GPF_T;
      }

    for (ctr = UNAME_TABLE_SIZE * 2; ctr--; /* no step */ )
      {
	box_dv_uname_make_immortal (list1[ctr]);
      }
    for (ctr = UNAME_TABLE_SIZE * 2; ctr--; /* no step */ )
      {						 /* no effect */
	dk_free_box (list2[ctr]);
      }
    for (ctr = UNAME_TABLE_SIZE * 2; ctr--; /* no step */ )
      {						 /* no effect */
	dk_free_box (list2[ctr]);
      }
    for (ctr = UNAME_TABLE_SIZE * 2; ctr--; /* no step */ )
      {						 /* no effect */
	dk_free_box (list2[ctr]);
      }

    for (ctr = UNAME_TABLE_SIZE * 2; ctr--; /* no step */ )
      {
	char buf[20];
	sprintf (buf, "uname%d", ctr);
	list2[ctr] = box_dv_uname_string (buf);
      }
    for (ctr = UNAME_TABLE_SIZE * 2; ctr--; /* no step */ )
      {						 /* alloc 2b */
	if (list1[ctr] != list2[ctr])
	  GPF_T;
      }
    for (ctr = UNAME_TABLE_SIZE * 2; ctr--; /* no step */ )
      {						 /* free 2b */
	dk_free_box (list2[ctr]);
      }
    for (ctr = UNAME_TABLE_SIZE * 2; ctr--; /* no step */ )
      {						 /* free 1 */
	dk_free_box (list1[ctr]);
      }
  }
#endif
#endif
}


/* Original signatures should exist for EXE-EXPORTed functions */
#ifdef MALLOC_DEBUG
/*
#undef dk_alloc_box
box_t dk_alloc_box (uint32 bytes, dtp_t type) { return dbg_dk_alloc_box (__FILE__, __LINE__, bytes, type); }
#undef dk_try_alloc_box
box_t dk_try_alloc_box (size_t bytes, dtp_t type) { return dbg_dk_try_alloc_box (__FILE__, __LINE__, bytes, type); }
#undef dk_alloc_box_zero
box_t dk_alloc_box_zero (size_t bytes, dtp_t type) { return dbg_dk_alloc_box_zero (__FILE__, __LINE__, bytes, type); }
*/
#undef box_string
box_t
box_string (const char *string)
{
  return dbg_box_string (__FILE__, __LINE__, string);
}


#undef box_dv_short_string
box_t
box_dv_short_string (const char *string)
{
  return dbg_box_dv_short_string (__FILE__, __LINE__, string);
}


#undef box_dv_short_nchars
box_t
box_dv_short_nchars (const char *buf, size_t buf_len)
{
  return dbg_box_dv_short_nchars (__FILE__, __LINE__, buf, buf_len);
}


#undef box_dv_short_nchars_reuse
box_t
box_dv_short_nchars_reuse (const char *buf, size_t buf_len, box_t replace)
{
  return dbg_box_dv_short_nchars_reuse (__FILE__, __LINE__, buf, buf_len, replace);
}


#undef box_dv_short_substr
box_t
box_dv_short_substr (ccaddr_t box, int n1, int n2)
{
  return dbg_box_dv_short_substr (__FILE__, __LINE__, box, n1, n2);
}


#undef box_dv_short_concat
box_t
box_dv_short_concat (ccaddr_t box1, ccaddr_t box2)
{
  return dbg_box_dv_short_concat (__FILE__, __LINE__, box1, box2);
}


#undef box_dv_short_strconcat
box_t
box_dv_short_strconcat (const char *str1, const char *str2)
{
  return dbg_box_dv_short_strconcat (__FILE__, __LINE__, str1, str2);
}


#undef box_copy
box_t
box_copy (cbox_t box)
{
  return dbg_box_copy (__FILE__, __LINE__, box);
}


#undef box_copy_tree
box_t
box_copy_tree (cbox_t box)
{
  return dbg_box_copy_tree (__FILE__, __LINE__, box);
}


#undef box_num
box_t
box_num (boxint n)
{
  return dbg_box_num (__FILE__, __LINE__, n);
}


#undef box_num_nonull
box_t
box_num_nonull (boxint n)
{
  return dbg_box_num_nonull (__FILE__, __LINE__, n);
}


#undef box_iri_id
box_t
box_iri_id (int64 n)
{
  return dbg_box_iri_id (__FILE__, __LINE__, n);
}


#undef box_dv_ubuf
char *
box_dv_ubuf (size_t buf_strlen)
{
  return dbg_box_dv_ubuf (__FILE__, __LINE__, buf_strlen);
}


#undef box_dv_ubuf_or_null
char *
box_dv_ubuf_or_null (size_t buf_strlen)
{
  return dbg_box_dv_ubuf_or_null (__FILE__, __LINE__, buf_strlen);
}


#undef box_dv_uname_from_ubuf
box_t
box_dv_uname_from_ubuf (char *ubuf)
{
  return dbg_box_dv_uname_from_ubuf (__FILE__, __LINE__, ubuf);
}


#undef box_dv_uname_string
box_t
box_dv_uname_string (const char *string)
{
  return dbg_box_dv_uname_string (__FILE__, __LINE__, string);
}


#undef box_dv_uname_nchars
box_t
box_dv_uname_nchars (const char *buf, size_t buf_len)
{
  return dbg_box_dv_uname_nchars (__FILE__, __LINE__, buf, buf_len);
}


#undef box_dv_uname_substr
box_t
box_dv_uname_substr (ccaddr_t box, int n1, int n2)
{
  return dbg_box_dv_uname_substr (__FILE__, __LINE__, box, n1, n2);
}


#undef box_double
box_t
box_double (double d)
{
  return dbg_box_double (__FILE__, __LINE__, d);
}


#undef box_float
box_t
box_float (float d)
{
  return dbg_box_float (__FILE__, __LINE__, d);
}


#undef box_dv_wide_nchars
box_t
box_dv_wide_nchars (const wchar_t *buf, size_t buf_wchar_count)
{
  return dbg_box_dv_wide_nchars (__FILE__, __LINE__, buf, buf_wchar_count);
}


#undef box_vsprintf
caddr_t
box_vsprintf (size_t buflen_eval, const char *format, va_list tail)
{
  return dbg_box_vsprintf (__FILE__, __LINE__, buflen_eval, format, tail);
}


#undef box_sprintf
caddr_t
box_sprintf (size_t buflen_eval, const char *format, ...)
{
  va_list tail;
  caddr_t res;
  va_start (tail, format);
  res = dbg_box_vsprintf (__FILE__, __LINE__, buflen_eval, format, tail);
  va_end (tail);
  return res;
}
#endif

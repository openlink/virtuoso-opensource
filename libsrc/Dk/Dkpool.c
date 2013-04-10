/*
 *  Dkpool.c
 *
 *  $Id$
 *
 *  Temp memory pool for objects that should be allocated one by one but freed
 *  together.
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

#include "Dk.h"
#ifdef HAVE_SYS_MMAN_H
#include <sys/mman.h>
#endif
#undef log
#include "math.h"


void
mp_free_reuse (mem_pool_t * mp)
{
  if (mp->mp_large_reuse)
    {
      int inx;
      DO_BOX (resource_t *, rc, inx, mp->mp_large_reuse)
	{
	  if (rc)
	    {
	      free (rc->rc_items);
	      free (rc);
	    }
	}
      END_DO_BOX;
      dk_free_box ((caddr_t)mp->mp_large_reuse);
    }
}


#ifdef MP_MAP_CHECK
dk_hash_t * mp_registered;
dk_mutex_t mp_reg_mtx;

void
mp_register (mem_pool_t * mp)
{
  if (!mp_registered)
    {
      mp_registered = hash_table_allocate (101);
      mp_registered->ht_rehash_threshold = 2;
      dk_mutex_init (&mp_reg_mtx, MUTEX_TYPE_SHORT);
    }
  mutex_enter (&mp_reg_mtx);
  sethash ((void*)mp, mp_registered, (void*)1);
  mutex_leave (&mp_reg_mtx);
}


void
mp_unregister (mem_pool_t * mp)
{
  mutex_enter (&mp_reg_mtx);
  remhash ((void*)mp, mp_registered);
  mutex_leave (&mp_reg_mtx);
}

int
mp_map_count ()
{
  int ctr = 0;
  size_t sz = 0;
  DO_HT (mem_pool_t *, mp, ptrlong,  ign, mp_registered)
    {
      ctr += mp->mp_large.ht_count;
      DO_HT (void*, ptr, size_t, b_sz, &mp->mp_large)
	sz += b_sz;
      END_DO_HT;
    }
  END_DO_HT;
  printf ("%d maps in mps, %ld bytes\n", ctr, sz);
  return ctr;
}


#else
#define mp_register(mp)
#define mp_unregister(mp)
#endif

void mp_free_all_large (mem_pool_t * mp);

#define DBG_MP_ALLOC_BOX(mp,len,tag) DBG_NAME(mp_alloc_box) (DBG_ARGS (mp), (len), (tag))
#define DBG_T_ALLOC_BOX(len,tag) DBG_NAME(t_alloc_box) (DBG_ARGS (len), (tag))

void
mp_uname_free (const void *k, void *data)
{
#ifdef DEBUG
  caddr_t box = (caddr_t)k;
  if (DV_UNAME == box_tag (box))
    {
      int len = box_length (box) - 1;
      ptrlong qchk = ((len > 0) ? (box[0] | len) : 1);
      if (data != (void *) qchk)
	GPF_T1 ("mp_uname_free(): bad checksum");
    }
#endif
  dk_free_box ((box_t) k);
}


#ifdef LACERATED_POOL

#if defined (DEBUG) || defined (MALLOC_DEBUG)
mem_pool_t *
dbg_mem_pool_alloc (const char *file, int line)
#else
mem_pool_t *
mem_pool_alloc (void)
#endif
{
  NEW_VARZ (mem_pool_t, mp);
  mp->mp_size = 0x100;
  mp->mp_allocs = (caddr_t *) DK_ALLOC (sizeof (caddr_t) * mp->mp_size);
  mp->mp_unames = hash_table_allocate (11);
  hash_table_init (&mp->mp_large, 121);
  mp->mp_large.ht_rehash_threshold = 2;
  mp_register (mp);
#if defined (DEBUG) || defined (MALLOC_DEBUG)
  mp->mp_alloc_file = (char *) file;
  mp->mp_alloc_line = line;
#endif
  return mp;
}


void
mp_free (mem_pool_t * mp)
{
#ifdef MALLOC_DEBUG
  if (mp->mp_box_to_dc)
    hash_table_free (mp->mp_box_to_dc);
#endif
  DO_SET (caddr_t, box, &mp->mp_trash)
  {
    dk_free_tree (box);
  }
  END_DO_SET ();
  while (mp->mp_fill)
    {
      caddr_t buf;
      const char *err;
      mp->mp_fill -= 1;
      buf = mp->mp_allocs[mp->mp_fill];
      err = dbg_find_allocation_error (buf, mp);
      if (NULL != err)
	GPF_T1 (err);
      dbg_freep (__FILE__, __LINE__, buf, mp);
    }
  maphash (mp_uname_free, mp->mp_unames);
  hash_table_free (mp->mp_unames);
  dk_free ((caddr_t) mp->mp_allocs, mp->mp_size * sizeof (caddr_t));
  mp_free_all_large (mp);
  mp_free_reuse (mp);
  mp_unregister (mp);
  dk_free ((caddr_t) mp, sizeof (mem_pool_t));
}

#ifdef MALLOC_DEBUG
void
mp_check (mem_pool_t * mp)
{
  int fill;
  if (!mp)
    return;
  fill = mp->mp_fill;
  while (fill)
    {
      caddr_t buf;
      const char *err;
      fill -= 1;
      buf = mp->mp_allocs[fill];
      err = dbg_find_allocation_error (buf, mp);
      if (NULL != err)
	GPF_T1 (err);
    }
}
#endif

void
mp_alloc_box_assert (mem_pool_t * mp, caddr_t box)
{
#ifdef DOUBLE_ALIGN
  const char *err = dbg_find_allocation_error (box - 8, mp);
#else
  char *err = dbg_find_allocation_error (box - 4, mp);
#endif
  if (NULL != err)
    GPF_T1 (err);
}


#else




#if defined (DEBUG) || defined (MALLOC_DEBUG)
mem_pool_t *
dbg_mem_pool_alloc (const char *file, int line)
#else
mem_pool_t *
mem_pool_alloc (void)
#endif
{
  NEW_VARZ (mem_pool_t, mp);
  mp->mp_block_size = ALIGN_8 ((mp_block_size));
  hash_table_init (&mp->mp_large, 121);
  mp->mp_large.ht_rehash_threshold = 2;
  mp->mp_unames = DBG_NAME (hash_table_allocate) (DBG_ARGS 11);
  mp_register (mp);
#if defined (DEBUG) || defined (MALLOC_DEBUG)
  mp->mp_alloc_file = (char *) file;
  mp->mp_alloc_line = line;
#endif
  return mp;
}

extern size_t mp_large_min;
size_t mp_block_size = 4096 * 20;


void
mp_free (mem_pool_t * mp)
{
  mem_block_t *mb = mp->mp_first, *next;
  DO_SET (caddr_t, box, &mp->mp_trash)
  {
    dk_free_tree (box);
  }
  END_DO_SET ();
  while (mb)
    {
      next = mb->mb_next;
      if (mb->mb_size < mp_large_min)
      dk_free ((caddr_t) mb, mb->mb_size);
      mb = next;
    }
  maphash (mp_uname_free, mp->mp_unames);
  hash_table_free (mp->mp_unames);
  mp_free_reuse (mp);
  mp_free_all_large (mp);
  mp_unregister (mp);
  dk_free ((caddr_t) mp, sizeof (mem_pool_t));
}


size_t
mp_size (mem_pool_t * mp)
{
  size_t sz = 0;
  mem_block_t *mb = mp->mp_first, *next;
  while (mb)
    {
      next = mb->mb_next;
      sz += mb->mb_size;
      mb = next;
    }
  return sz;
}
#endif

size_t mp_large_min = 80000;

caddr_t
DBG_NAME (mp_alloc_box) (DBG_PARAMS mem_pool_t * mp, size_t len1, dtp_t dtp)
{
  dtp_t *ptr;
  size_t len, hlen;
  int bh_len;
  caddr_t new_alloc;
#ifndef LACERATED_POOL
  mem_block_t *mb = NULL, *f;
#endif

  if (DV_NON_BOX  == dtp && len1 > mp_large_min)
    return mp_large_alloc (mp, len1);
  else if (len1 > mp_large_min)
    {
      ptr =  mp_large_alloc (mp, len1 + 8);
      ptr += 4;
      WRITE_BOX_HEADER (ptr, len1, dtp);
      memzero (ptr, len1);
      return (caddr_t)ptr;
    }
#ifdef LACERATED_POOL
#ifdef DOUBLE_ALIGN
  len = ALIGN_8 (len1 + 8);
#else
  len = ALIGN_4 (len1 + 4);
#endif
  new_alloc = DBG_NAME (mallocp) (DBG_ARGS len, mp);
  mp->mp_bytes += len;
  if (mp->mp_fill >= mp->mp_size)
    {
      caddr_t *newallocs;
      mp->mp_size *= 2;
      newallocs = (caddr_t *) dk_alloc (sizeof (caddr_t) * mp->mp_size);
      memcpy (newallocs, mp->mp_allocs, sizeof (caddr_t) * mp->mp_fill);
      dk_free (mp->mp_allocs, (mp->mp_size / 2) * sizeof (caddr_t));
      mp->mp_allocs = newallocs;
    }
  mp->mp_allocs[mp->mp_fill] = new_alloc;
  mp->mp_fill += 1;
#ifdef DOUBLE_ALIGN
  ptr = new_alloc + 4;
#else
  ptr = new_alloc;
#endif
#else
  bh_len = (dtp != DV_NON_BOX ? 8 : 0);
  len = ALIGN_8 (len1 + bh_len);
  mb = NULL;
  f = mp->mp_first;
  hlen = ALIGN_8 ((sizeof (mem_block_t)));	/* we can have a doubles so structure also must be aligned */
  if (!f || f->mb_size - f->mb_fill < len)
    {
      if (len > mp->mp_block_size - hlen)
	{
	  mb = (mem_block_t *) dk_alloc (hlen + len);
	  mb->mb_size = len + hlen;
	  mb->mb_fill = hlen;
	  if (f)
	    {
	      mb->mb_next = f->mb_next;
	      f->mb_next = mb;
	    }
	  else
	    {
	      mb->mb_next = NULL;
	      mp->mp_first = mb;
	    }
	  mp->mp_bytes += mb->mb_size;
	}
      else
	{
	  if (mp->mp_block_size < mp_large_min)
	    {
	  mb = (mem_block_t *) dk_alloc (mp->mp_block_size);
	      mp->mp_bytes += mb->mb_size;
	    }
	  else
	    mb = (mem_block_t *)mp_large_alloc (mp, mp->mp_block_size);
	  mb->mb_size = mp->mp_block_size;
	  mb->mb_fill = hlen;
	  mb->mb_next = mp->mp_first;
	  mp->mp_first = mb;
	}
    }
  else
    mb = f;
  ptr = ((dtp_t *) mb) + mb->mb_fill + (bh_len / 2);
  mb->mb_fill += len;
#endif
#ifndef LACERATED_POOL
  if (bh_len)
    {
#endif
      if (DV_NON_BOX != dtp)
	{
      WRITE_BOX_HEADER (ptr, len1, dtp);
	}
#ifndef LACERATED_POOL
    }
#endif
  if (DV_NON_BOX != dtp)
  memset (ptr, 0, len1);
  return ((caddr_t) ptr);
}


caddr_t
DBG_NAME (mp_box_string) (DBG_PARAMS mem_pool_t * mp, const char *str)
{
  size_t len;
  caddr_t box;
  if (!str)
    return 0;
  len = strlen (str);
  box = DBG_MP_ALLOC_BOX (mp, len + 1, DV_SHORT_STRING);
  memcpy (box, str, len);
  box[len] = 0;
  return box;
}


box_t
DBG_NAME (mp_box_dv_short_nchars) (DBG_PARAMS mem_pool_t * mp, const char *buf, size_t buf_len)
{
  box_t box;
  box = DBG_MP_ALLOC_BOX (mp, buf_len + 1, DV_SHORT_STRING);
  memcpy (box, buf, buf_len);
  ((char *) box)[buf_len] = '\0';
  return box;
}


caddr_t
DBG_NAME (mp_box_substr) (DBG_PARAMS mem_pool_t * mp, ccaddr_t str, int n1, int n2)
{
  int lstr = (int) (box_length (str)) - 1;
  int lres;
  char *res;
  if (n2 > lstr)
    n2 = lstr;
  lres = n2 - n1;
  if (lres <= 0)
    return (DBG_NAME (mp_box_string) (DBG_ARGS mp, ""));
  res = DBG_NAME (mp_alloc_box) (DBG_ARGS mp, lres + 1, DV_SHORT_STRING);
  memcpy (res, str + n1, lres);
  res[lres] = 0;
  return res;
}


caddr_t DBG_NAME (mp_box_dv_uname_string) (DBG_PARAMS mem_pool_t * mp, const char *str)
{
  size_t len;
  caddr_t box;
#ifdef DEBUG
  ptrlong qchk, qv;
#endif
  if (!str)
    return 0;
  len = strlen (str);
  box = box_dv_uname_nchars (str, len);
#ifdef DEBUG
  qchk = ((len > 0) ? (str[0] | len) : 1);
  qv = gethash (box, mp->mp_unames);
  if (qv)
    {
      if (qv != qchk)
	GPF_T1 ("mp_box_dv_uname_string: dead hash table");
      dk_free_box (box);			 /* free extra copy */
    }
  else
    sethash (box, mp->mp_unames, (void *)qchk);
#else
  if (gethash (box, mp->mp_unames))
    dk_free_box (box);				 /* free extra copy */
  else
    sethash (box, mp->mp_unames, (void *)((ptrlong) 1));
#endif
  return box;
}


box_t
DBG_NAME (mp_box_dv_uname_nchars) (DBG_PARAMS mem_pool_t * mp, const char *buf, size_t buf_len)
{
  caddr_t box;
#ifdef DEBUG
  ptrlong qchk, qv;
#endif
  box = box_dv_uname_nchars (buf, buf_len);
#ifdef DEBUG
  qchk = ((buf_len > 0) ? (buf[0] | buf_len) : 1);
  qv = gethash (box, mp->mp_unames);
  if (qv)
    {
      if (qv != qchk)
	GPF_T1 ("mp_box_dv_uname_nchars: dead hash table");
      dk_free_box (box);			 /* free extra copy */
    }
  else
    sethash (box, mp->mp_unames, (void *)qchk);
#else
  if (gethash (box, mp->mp_unames))
    dk_free_box (box);				 /* free extra copy */
  else
    sethash (box, mp->mp_unames, (void *)((ptrlong) 1));
#endif
  return box;
}


extern box_copy_f box_copier[256];
extern box_tmp_copy_f box_tmp_copier[256];


caddr_t
DBG_NAME (mp_box_copy) (DBG_PARAMS mem_pool_t * mp, caddr_t box)
{
  dtp_t dtp;
  if (!IS_BOX_POINTER (box))
    return box;
  dtp = box_tag (box);
  switch (dtp)
    {
    case DV_UNAME:
      if (!gethash (box, mp->mp_unames))
	{
#ifdef DEBUG
	  int len = box_length (box) - 1;
	  ptrlong qchk = ((len > 0) ? (box[0] | len) : 1);
	  sethash (box_copy (box), mp->mp_unames, qchk);
#else
	  sethash (box_copy (box), mp->mp_unames, (void *) (ptrlong) 1);
#endif
	}
      return box;

    case DV_REFERENCE:
      return box;

    case DV_XPATH_QUERY:
      return box;

#ifdef MALLOC_DEBUG
    case DV_WIDE:
      {
        int len = box_length (box);
        if ((len % sizeof (wchar_t)) || (0 != ((wchar_t *)box)[len/sizeof (wchar_t) - 1]))
          GPF_T1 ("mp_box_copy of a damaged wide string");
        /* no break */
      }
#endif
    default:
      {
	caddr_t cp;
	if (box_copier[dtp])
	  {
	    if (box_tmp_copier[dtp])
	      return box_tmp_copier[dtp] (mp, box);
	    cp = box_copy (box);
	    mp_set_push (mp, &mp->mp_trash, (void*)cp);
	    return cp;
	  }
	{
#ifdef MALLOC_DEBUG
	  cp = mp_alloc_box (mp, box_length (box), box_tag (box));
	  box_flags (cp) = box_flags (box);
	  memcpy (cp, box, box_length (box));
	  return cp;
#else
	  int align_len = ALIGN_8 (box_length (box));
	  MP_BYTES (cp, mp, 8 + align_len);
	  cp = ((char *) cp) + 8;
	  ((int64 *) cp)[-1] = ((int64 *) box)[-1];
#ifdef DOUBLE_ALIGN
	  if (align_len < 64)
	    {
	      int inx;
	      for (inx = 0; inx < align_len / 8; inx++)
		((int64 *) cp)[inx] = ((int64 *) box)[inx];
	    }
	  else
#endif
	    memcpy (cp, box, box_length (box));
	  return cp;
#endif
	}
      }
    }
}


caddr_t
DBG_NAME (mp_box_copy_tree) (DBG_PARAMS mem_pool_t * mp, caddr_t box)
{
  dtp_t dtp;
  if (!IS_BOX_POINTER (box))
    return box;
  dtp = box_tag (box);
  if (IS_NONLEAF_DTP (dtp))
    {
      int inx, len = BOX_ELEMENTS (box);
      caddr_t *cp = (caddr_t *) DBG_NAME (mp_box_copy) (DBG_ARGS mp, box);
      for (inx = 0; inx < len; inx++)
	cp[inx] = DBG_NAME (mp_box_copy_tree) (DBG_ARGS mp, cp[inx]);
      return ((caddr_t) cp);
    }
  if (DV_UNAME == dtp)
    {
      if (!gethash (box, mp->mp_unames))
	{
#ifdef DEBUG
	  int len = box_length (box) - 1;
	  ptrlong qchk = ((len > 0) ? (box[0] | len) : 1);
	  sethash (box_copy (box), mp->mp_unames, (void *)qchk);
#else
	  sethash (box_copy (box), mp->mp_unames, (void *)((ptrlong) 1));
#endif
	}
      return box;
    }
  return box;
}


caddr_t
DBG_NAME (mp_full_box_copy_tree) (DBG_PARAMS mem_pool_t * mp, caddr_t box)
{
  dtp_t dtp;
  caddr_t *cp;
  if (!IS_BOX_POINTER (box))
    return box;
  dtp = box_tag (box);
  switch (dtp)
    {
    case DV_UNAME:
      if (!gethash (box, mp->mp_unames))
	{
#ifdef DEBUG
	  int len = box_length (box) - 1;
	  ptrlong qchk = ((len > 0) ? (box[0] | len) : 1);
	  sethash (box_copy (box), mp->mp_unames, (void *)qchk);
#else
	  sethash (box_copy (box), mp->mp_unames, (void *)((ptrlong) 1));
#endif
	}
      return box;

    case DV_REFERENCE:
      return box;

    case DV_XPATH_QUERY:
      return box;
    }
  cp = (caddr_t *) DBG_NAME (mp_box_copy) (DBG_ARGS mp, box);
  if (IS_NONLEAF_DTP (dtp))
    {
      int inx, len = BOX_ELEMENTS (box);
      for (inx = 0; inx < len; inx++)
	cp[inx] = DBG_NAME (mp_full_box_copy_tree) (DBG_ARGS mp, cp[inx]);
    }
  return (caddr_t) cp;
}


caddr_t *
mp_list (mem_pool_t * mp, long n, ...)
{
  caddr_t *box;
  va_list ap;
  int inx;
  va_start (ap, n);
  box = (caddr_t *) mp_alloc_box (mp, sizeof (caddr_t) * n, DV_ARRAY_OF_POINTER);
  for (inx = 0; inx < n; inx++)
    {
      box[inx] = va_arg (ap, caddr_t);
      if (IS_BOX_POINTER (box[inx]))
	if (0 == box_tag (box[inx]))
	  GPF_T1 ("copy tree of non box");	 /* dereference to see it is something */
    }
  va_end (ap);
  return ((caddr_t *) box);
}


caddr_t
DBG_NAME (mp_box_num) (DBG_PARAMS mem_pool_t * mp, boxint n)
{
  caddr_t box;
  if (!IS_POINTER (n))
    return (box_t) (ptrlong) n;

  MP_INT (box, mp, n, DV_INT_TAG_WORD);
  return box;
}


caddr_t
DBG_NAME (t_box_num) (DBG_PARAMS boxint n)
{
  box_t *box;

  if (!IS_BOXINT_POINTER (n))
    return (box_t) (ptrlong) n;

  box = (box_t *) DBG_T_ALLOC_BOX (sizeof (boxint), DV_LONG_INT);
  *(boxint *) box = n;

  return (caddr_t) box;
}


caddr_t
DBG_NAME (t_box_num_and_zero) (DBG_PARAMS boxint n)
{
  box_t *box;

  if (!IS_BOXINT_POINTER (n) && n != 0)
    return (box_t) (ptrlong) n;

  box = (box_t *) DBG_T_ALLOC_BOX (sizeof (boxint), DV_LONG_INT);
  *(boxint *) box = n;

  return (caddr_t) box;
}


caddr_t
DBG_NAME (mp_box_iri_id) (DBG_PARAMS mem_pool_t * mp, iri_id_t n)
{
  caddr_t box;
  MP_INT (box, mp, n, DV_IRI_TAG_WORD);
  return box;
}


caddr_t
DBG_NAME (mp_box_double) (DBG_PARAMS mem_pool_t * mp, double n)
{
  caddr_t box;
  MP_DOUBLE (box, mp, n, DV_DOUBLE_TAG_WORD);
  return box;
}


caddr_t
DBG_NAME (mp_box_float) (DBG_PARAMS mem_pool_t * mp, float n)
{
  caddr_t box;
  MP_FLOAT (box, mp, n, DV_FLOAT_TAG_WORD);
  return box;
}


caddr_t
DBG_NAME (t_box_iri_id) (DBG_PARAMS int64 n)
{
  iri_id_t *box = (iri_id_t *) DBG_T_ALLOC_BOX (sizeof (iri_id_t), DV_IRI_ID);
  *box = n;
  return (caddr_t) box;
}


box_t
DBG_NAME (t_box_double) (DBG_PARAMS double d)
{
  double *box = (double *) DBG_T_ALLOC_BOX (sizeof (double), DV_DOUBLE_FLOAT);
  *box = d;
  return (box_t) box;
}


box_t
DBG_NAME (t_box_float) (DBG_PARAMS float d)
{
  float *box = (float *) DBG_T_ALLOC_BOX (sizeof (float), DV_SINGLE_FLOAT);
  *box = d;
  return (box_t) box;
}


#ifdef MALLOC_DEBUG
caddr_t *
t_list_impl (long n, ...)
{
  mem_pool_t *mp = THR_TMP_POOL;
  caddr_t *box;
  va_list ap;
  int inx;
  va_start (ap, n);
  box = (caddr_t *) dbg_mp_alloc_box (mp->mp_list_alloc_file, mp->mp_list_alloc_line, mp, sizeof (caddr_t) * n, DV_ARRAY_OF_POINTER);
  for (inx = 0; inx < n; inx++)
    {
      caddr_t child = va_arg (ap, caddr_t);
      if (IS_BOX_POINTER (child))
	mp_alloc_box_assert (THR_TMP_POOL, child);
      box[inx] = child;
    }
  va_end (ap);
  return ((caddr_t *) box);
}


t_list_impl_ptr_t
t_list_cock (const char *file, int line)
{
  mem_pool_t *mp = THR_TMP_POOL;
  mp->mp_list_alloc_file = file;
  mp->mp_list_alloc_line = line;
  return t_list_impl;
}


#else
caddr_t *
t_list (long n, ...)
{
  caddr_t *box;
  va_list ap;
  int inx;
  va_start (ap, n);
  box = (caddr_t *) t_alloc_box (sizeof (caddr_t) * n, DV_ARRAY_OF_POINTER);
  for (inx = 0; inx < n; inx++)
    {
      caddr_t child = va_arg (ap, caddr_t);
      box[inx] = child;
    }
  va_end (ap);
  return ((caddr_t *) box);
}
#endif

caddr_t *
t_list_nc (long n, ...)
{
  caddr_t *box;
  va_list ap;
  int inx;
  va_start (ap, n);
  box = (caddr_t *) t_alloc_box (sizeof (caddr_t) * n, DV_ARRAY_OF_POINTER);
  for (inx = 0; inx < n; inx++)
    {
      caddr_t child = va_arg (ap, caddr_t);
      box[inx] = child;
    }
  va_end (ap);
  return ((caddr_t *) box);
}

caddr_t *
t_list_concat_tail (caddr_t list, long n, ...)
{
  caddr_t *res;
  va_list ap;
  int old_elems = BOX_ELEMENTS_0 (list);
  int inx;
#ifdef DEBUG
  if ((NULL != list) && (DV_ARRAY_OF_POINTER != DV_TYPE_OF (list)) && (DV_ARRAY_OF_LONG != DV_TYPE_OF (list)))
    GPF_T1 ("Bad type of first arg of t_list_concat_tail()");
#endif
  va_start (ap, n);
  res = (caddr_t *) t_alloc_box ((old_elems + n) * sizeof (caddr_t), (NULL == list) ? DV_ARRAY_OF_POINTER : box_tag (list));
  memcpy (res, list, old_elems * sizeof (caddr_t));
  for (inx = 0; inx < n; inx++)
    {
      res[old_elems + inx] = va_arg (ap, caddr_t);
    }
  va_end (ap);
#ifdef MALLOC_DEBUG
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (res))
    {
      for (inx = old_elems + n; inx--; /* no step */ )
	{
	  if (IS_BOX_POINTER (res[inx]))
	    mp_alloc_box_assert (THR_TMP_POOL, res[inx]);
	}
    }
#endif
  return ((caddr_t *) res);
}


caddr_t *
t_list_concat (caddr_t list1, caddr_t list2)
{
  caddr_t res;
  size_t len1, len2;
  if (NULL == list1)
    return (caddr_t *) list2;
  if (NULL == list2)
    return (caddr_t *) list1;
  len1 = box_length (list1);
  len2 = box_length (list2);
  res = t_alloc_box (len1 + len2, box_tag (list1));
  memcpy (res, list1, len1);
  memcpy (res + len1, list2, len2);
  return (caddr_t *) res;
}


caddr_t *
t_list_remove_nth (caddr_t list, int pos)
{
  int len = BOX_ELEMENTS_INT (list);
  caddr_t *res;
  if ((pos < 0) || (pos >= len))
    GPF_T1 ("t_list_remove_nth (): bad index");
  res = (caddr_t *) t_alloc_box ((len - 1) * sizeof (ptrlong), box_tag (list));
  memcpy (res, list, pos * sizeof (ptrlong));
  memcpy (res + pos, ((caddr_t *) list) + pos + 1, (len - (pos + 1)) * sizeof (ptrlong));
  return res;
}


caddr_t *
t_list_insert_before_nth (caddr_t list, caddr_t new_item, int pos)
{
  int len = BOX_ELEMENTS_INT (list);
  caddr_t *res;
  if ((pos < 0) || (pos > len))
    GPF_T1 ("t_list_insert_before_nth (): bad index");
  res = (caddr_t *) t_alloc_box ((len + 1) * sizeof (ptrlong), box_tag (list));
  memcpy (res, list, pos * sizeof (ptrlong));
  res[pos] = new_item;
  memcpy (res + pos + 1, ((caddr_t *) list) + pos, (len - pos) * sizeof (ptrlong));
  return res;
}


caddr_t *
t_list_insert_many_before_nth (caddr_t list, caddr_t * new_items, int ins_count, int pos)
{
  int len = BOX_ELEMENTS_INT (list);
  caddr_t *res;
  if ((pos < 0) || (pos > len))
    GPF_T1 ("t_list_insert_before_nth (): bad index");
  res = (caddr_t *) t_alloc_box ((len + ins_count) * sizeof (ptrlong), box_tag (list));
  memcpy (res, list, pos * sizeof (ptrlong));
  memcpy (res + pos, new_items, ins_count * sizeof (ptrlong));
  memcpy (res + pos + ins_count, ((caddr_t *) list) + pos, (len - pos) * sizeof (ptrlong));
  return res;
}


caddr_t *
t_sc_list (long n, ...)
{
  caddr_t *box;
  va_list ap;
  int inx;
  va_start (ap, n);
  box = (caddr_t *) t_alloc_box (sizeof (caddr_t) * n, DV_ARRAY_OF_LONG);
  for (inx = 0; inx < n; inx++)
    {
      caddr_t child = va_arg (ap, caddr_t);
      box[inx] = child;
    }
  va_end (ap);
  return ((caddr_t *) box);
}


void
DBG_NAME (mp_set_push) (DBG_PARAMS mem_pool_t * mp, dk_set_t * set, void *elt)
{
  s_node_t *s;
  MP_BYTES (s, mp, sizeof (s_node_t));
  s->data = elt;
  s->next = *set;
  *set = s;
}


dk_set_t
DBG_NAME (t_cons) (DBG_PARAMS void *car, dk_set_t cdr)
{
  mem_pool_t * mp = THR_TMP_POOL;
  s_node_t *s;
  MP_BYTES (s, mp, sizeof (s_node_t));
  s->data = car;
  s->next = cdr;
  return s;
}


void
DBG_NAME (t_set_push) (DBG_PARAMS dk_set_t * set, void *elt)
{
  *set = DBG_NAME (t_cons) (DBG_ARGS elt, *set);
}


void *
DBG_NAME (t_set_pop) (DBG_PARAMS s_node_t ** set)
{
  if (*set)
    {
      void *item;
      s_node_t *old = *set;
      *set = old->next;
      item = old->data;

      return item;
    }

  return NULL;
}


int
DBG_NAME (t_set_pushnew) (DBG_PARAMS s_node_t ** set, void *item)
{
  if (!dk_set_member (*set, item))
    {
      s_node_t *newn = (s_node_t *) t_alloc_box (sizeof (s_node_t), DV_NON_BOX);
      newn->next = *set;
      newn->data = item;
      *set = newn;
      return 1;
    }
  return 0;
}


int
DBG_NAME (t_set_push_new_string) (DBG_PARAMS s_node_t ** set, char *item)
{
  if (0 > dk_set_position_of_string (*set, item))
    {
      s_node_t *newn = (s_node_t *) t_alloc_box (sizeof (s_node_t), DV_NON_BOX);
      newn->next = *set;
      newn->data = item;
      *set = newn;
      return 1;
    }
  return 0;
}


dk_set_t
DBG_NAME (t_set_union) (DBG_PARAMS dk_set_t s1, dk_set_t s2)
{
  dk_set_t un = s2;
  DO_SET (caddr_t, elt, &s1)
  {
    if (!dk_set_member (s2, elt))
      DBG_NAME (t_set_push) (DBG_ARGS & un, elt);
  }
  END_DO_SET ();
  return un;
}


dk_set_t
DBG_NAME (t_set_intersect) (DBG_PARAMS dk_set_t s1, dk_set_t s2)
{
  dk_set_t un = NULL;
  DO_SET (caddr_t, elt, &s1)
  {
    if (dk_set_member (s2, elt))
      DBG_NAME (t_set_push) (DBG_ARGS & un, elt);
  }
  END_DO_SET ();
  return un;
}


dk_set_t
DBG_NAME (t_set_diff) (DBG_PARAMS dk_set_t s1, dk_set_t s2)
{
  dk_set_t un = NULL;
  DO_SET (caddr_t, elt, &s1)
  {
    if (!dk_set_member (s2, elt))
      DBG_NAME (t_set_push) (DBG_ARGS & un, elt);
  }
  END_DO_SET ();
  return un;
}


caddr_t *
DBG_NAME (t_list_to_array) (DBG_PARAMS s_node_t * set)
{
  caddr_t *array;
  uint32 len;
  uint32 inx;

  len = dk_set_length (set);
  array = (caddr_t *) DBG_T_ALLOC_BOX (len * sizeof (void *), DV_ARRAY_OF_POINTER);
  inx = 0;

  DO_SET (caddr_t, elt, &set)
  {
    array[inx++] = elt;
  }
  END_DO_SET ();

  return array;
}


caddr_t *
DBG_NAME (t_revlist_to_array) (DBG_PARAMS s_node_t * set)
{
  caddr_t *array;
  uint32 len;
  uint32 inx;
  inx = len = dk_set_length (set);
  array = (caddr_t *) DBG_T_ALLOC_BOX (len * sizeof (void *), DV_ARRAY_OF_POINTER);
  DO_SET (caddr_t, elt, &set)
  {
    array[--inx] = elt;
  }
  END_DO_SET ();
  return array;
}


int
DBG_NAME (t_set_delete) (DBG_PARAMS dk_set_t * set, void *item)
{
  s_node_t *node = *set;
  dk_set_t *previous = set;
  while (node)
    {
      if (node->data == item)
	{
	  *previous = node->next;
	  return 1;
	}
      previous = &(node->next);
      node = node->next;
    }
  return 0;
}


dk_set_t
DBG_NAME (t_set_copy) (DBG_PARAMS dk_set_t s)
{
  dk_set_t r = NULL;
  dk_set_t *last = &r;
  while (s)
    {
      dk_set_t n = (dk_set_t) DBG_T_ALLOC_BOX (sizeof (s_node_t), DV_NON_BOX);
      *last = n;
      n->data = s->data;
      n->next = NULL;
      last = &n->next;
      s = s->next;
    }
  return r;
}


#ifdef MALLOC_DEBUG
void
mp_check_tree (mem_pool_t * mp, box_t box)
{
  uint32 count;
  dtp_t tag;
  if (!IS_BOX_POINTER (box))
    return;
  mp_alloc_box_assert (mp, (caddr_t) box);
  tag = box_tag (box);
  if (IS_NONLEAF_DTP (tag))
    {
      box_t *obj = (box_t *) box;
      for (count = box_length ((caddr_t) box) / sizeof (caddr_t); count; count--)
	mp_check_tree (mp, *obj++);
    }
}
#endif

caddr_t
t_box_vsprintf (size_t buflen_eval, const char *format, va_list tail)
{
  char *tmpbuf;
  int res_len;
  caddr_t res;
  buflen_eval &= 0xFFFFFF;
  tmpbuf = (char *) dk_alloc (buflen_eval);
  res_len = vsnprintf (tmpbuf, buflen_eval, format, tail);
  if (res_len >= buflen_eval)
    GPF_T;
  res = t_box_dv_short_nchars (tmpbuf, res_len);
  dk_free (tmpbuf, buflen_eval);
  return res;
}


caddr_t
t_box_sprintf (size_t buflen_eval, const char *format, ...)
{
  va_list tail;
  caddr_t res;
  va_start (tail, format);
  res = t_box_vsprintf (buflen_eval, format, tail);
  va_end (tail);
  return res;
}


void
mp_trash (mem_pool_t * mp, caddr_t box)
{
  mp_set_push (mp, &mp->mp_trash, (void *) box);
}


caddr_t
mp_alloc_box_ni (mem_pool_t * mp, int len, dtp_t dtp)
{
#ifdef MALLOC_DEBUG
  return mp_alloc_box (mp, len, dtp);
#else
  caddr_t box;
  if (DV_NON_BOX == dtp)
    {
      MP_BYTES (box, mp, len);
      return box;
    }
  MP_BYTES (box, mp, 8 + len);
  box += 4;
  WRITE_BOX_HEADER (box, len, dtp);
  return box;
#endif
}


caddr_t
ap_alloc_box (auto_pool_t * ap, int len, dtp_t dtp)
{
  caddr_t ptr = ap->ap_area + ap->ap_fill + 4;
  WRITE_BOX_HEADER (ptr, len, dtp);
  ap->ap_fill += ALIGN_8 (len) + 8;
#ifndef NDEBUG
  if (ap->ap_fill > ap->ap_size)
    GPF_T1 ("exceed size of auto_pool_t");
#endif
  return ptr;
}


caddr_t
ap_box_num (auto_pool_t * ap, int64 n)
{
  caddr_t box;
  if (!IS_BOXINT_POINTER (n))
    return (caddr_t) (ptrlong) n;
  box = ap_alloc_box (ap, sizeof (int64), DV_LONG_INT);
  *(int64 *) box = n;
  return box;
}


caddr_t
ap_box_iri_id (auto_pool_t * ap, int64 n)
{
  caddr_t box;
  box = ap_alloc_box (ap, sizeof (int64), DV_IRI_ID);
  *(int64 *) box = n;
  return box;
}


caddr_t *
ap_list (auto_pool_t * apool, long n, ...)
{
  caddr_t *box;
  va_list ap;
  int inx;
  va_start (ap, n);
  box = (caddr_t *) ap_alloc_box (apool, sizeof (caddr_t) * n, DV_ARRAY_OF_POINTER);
  for (inx = 0; inx < n; inx++)
    {
      box[inx] = va_arg (ap, caddr_t);
    }
  va_end (ap);
  return ((caddr_t *) box);
}

#if defined (DEBUG) || defined (MALLOC_DEBUG)
#undef mem_pool_alloc
mem_pool_t *mem_pool_alloc (void) { return dbg_mem_pool_alloc (__FILE__, __LINE__); }
#endif

#ifdef MALLOC_DEBUG
#undef mp_alloc_box
caddr_t mp_alloc_box (mem_pool_t * mp, size_t len, dtp_t dtp) { return dbg_mp_alloc_box (__FILE__, __LINE__, mp, len, dtp); }
#undef mp_box_string
caddr_t mp_box_string (mem_pool_t * mp, const char *str) { return dbg_mp_box_string (__FILE__, __LINE__, mp, str); }
#undef mp_box_substr
caddr_t mp_box_substr (mem_pool_t * mp, ccaddr_t str, int n1, int n2) { return dbg_mp_box_substr (__FILE__, __LINE__, mp, str, n1, n2); }
#undef mp_box_dv_short_nchars
box_t mp_box_dv_short_nchars (mem_pool_t * mp, const char *str, size_t len) { return dbg_mp_box_dv_short_nchars (__FILE__, __LINE__, mp, str, len); }
#undef mp_box_dv_uname_string
caddr_t mp_box_dv_uname_string (mem_pool_t * mp, const char *str) { return dbg_mp_box_dv_uname_string (__FILE__, __LINE__, mp, str); }
#undef mp_box_dv_uname_nchars
box_t mp_box_dv_uname_nchars (mem_pool_t * mp, const char *str, size_t len) { return dbg_mp_box_dv_uname_nchars (__FILE__, __LINE__, mp, str, len); }
#undef mp_box_copy
caddr_t mp_box_copy (mem_pool_t * mp, caddr_t box) { return dbg_mp_box_copy (__FILE__, __LINE__, mp, box); }
#undef mp_box_copy_tree
caddr_t mp_box_copy_tree (mem_pool_t * mp, caddr_t box) { return dbg_mp_box_copy_tree (__FILE__, __LINE__, mp, box); }
#undef mp_full_box_copy_tree
caddr_t mp_full_box_copy_tree (mem_pool_t * mp, caddr_t box) { return dbg_mp_full_box_copy_tree (__FILE__, __LINE__, mp, box); }
#undef mp_box_num
caddr_t mp_box_num (mem_pool_t * mp, boxint num) { return dbg_mp_box_num (__FILE__, __LINE__, mp, num); }
#undef mp_box_iri_id
caddr_t mp_box_iri_id (mem_pool_t * mp, iri_id_t num) { return dbg_mp_box_iri_id (__FILE__, __LINE__, mp, num); }
#undef mp_box_double
caddr_t mp_box_double (mem_pool_t * mp, double num) { return dbg_mp_box_double (__FILE__, __LINE__, mp, num); }
#undef mp_box_float
caddr_t mp_box_float (mem_pool_t * mp, float num) { return dbg_mp_box_float (__FILE__, __LINE__, mp, num); }
#endif


/* large allocs */

size_t mp_large_in_use;
size_t mp_max_large_in_use;
size_t mp_max_cache = 10000000;
size_t mp_large_warn_threshold;
dk_mutex_t mp_large_g_mtx;
size_t mp_mmap_min = 80000;
size_t mm_page_sz = 4096;
int mm_n_large_sizes;
#define N_LARGE_SIZES 30
size_t mm_sizes[N_LARGE_SIZES];
du_thread_t * mm_after_failed_unmap;
dk_mutex_t map_fail_mtx;
dk_hash_t mm_failed_unmap;
resource_t * mm_rc[N_LARGE_SIZES];
int32 mm_uses[N_LARGE_SIZES + 1];
int mp_local_rc_sz = 1;
size_t mp_large_reserved;
size_t mp_max_large_reserved;
size_t mp_large_reserve_limit;
dk_mutex_t mp_reserve_mtx;


size_t
mm_next_size (size_t n, int * nth)
{
  size_t *last = &mm_sizes[mm_n_large_sizes - 1];
  size_t *base = mm_sizes;

  if (!mm_n_large_sizes || n > *last)
    {
      *nth = -1;
      return n;
    }
  while (last >= base)
    {
      size_t *p = &base[(int) ((last - base) >> 1)];
      int64 res = (int64) n - *p;

      if (res == 0)
	{
	  *nth = p - &mm_sizes[0];
	  return n;
	}
      if (res < 0)
	last = p - 1;
      else
	base = p + 1;
    }
  *nth = (last - &mm_sizes[0]) + 1;
  return last[1];
}


void
mm_cache_init (size_t sz, size_t min, size_t max, int steps, float step)
{
  float m = 1;
  int inx;
  if (steps > N_LARGE_SIZES)
    steps = N_LARGE_SIZES;
  if (!mp_large_g_mtx.mtx_handle)
    dk_mutex_init (&mp_large_g_mtx, MUTEX_TYPE_SHORT);
  dk_mutex_init (&mp_reserve_mtx, MUTEX_TYPE_SHORT);
  mm_n_large_sizes = steps;
  for (inx = 0; inx < steps; inx++)
    {
      mm_sizes[inx] = _RNDUP (((int64)(min * m)), 4096);
      m *= step;
      mm_rc[inx] = resource_allocate (20, NULL, NULL, NULL, NULL);
      mm_rc[inx]->rc_item_time = (uint32*)malloc (sizeof (int32) * mm_rc[inx]->rc_size);
      memzero (mm_rc[inx]->rc_item_time, sizeof (int32) * mm_rc[inx]->rc_size);
      mm_rc[inx]->rc_max_size = MAX (2, sz / (mm_sizes[inx] * 2));
    }
  dk_mutex_init (&map_fail_mtx, MUTEX_TYPE_SHORT);
  hash_table_init (&mm_failed_unmap, 23);
}


#ifdef MP_MAP_CHECK

dk_mutex_t mp_mmap_mark_mtx;
dk_pool_4g_t * dk_pool_map[256 * 256];
int dk_pool_map_inited;

void
mp_mmap_mark (void * __ptr, size_t sz, int flag)
{
  int64 ptr = (int64)__ptr;
  size_t off, off2;
  dk_pool_4g_t * map;
  int map_off = ptr >> 32;
  if (!dk_pool_map_inited)
    {
      dk_mutex_init (&mp_mmap_mark_mtx, MUTEX_TYPE_SHORT);
      dk_pool_map_inited = 1;
    }
  mutex_enter (&mp_mmap_mark_mtx);
  map = dk_pool_map[map_off];
  if (!flag && !map) GPF_T1 ("freeing mmap mark where no mapping");
  if (!map)
    {
      map = dk_pool_map[map_off] = dk_alloc (sizeof (dk_pool_4g_t));
      memzero (map, sizeof (dk_pool_4g_t));
    }
  ptr &= 0xffffffff;
  off2 = 0;
  for (off = 0; off < sz; off += 4096)
    {
      int64 pg = ptr + off2;
      unsigned char m;
      int byte;
      if (pg > 0xffffffff)
	{
	  off2 = pg = ptr = 0;
	  map_off++;
	  map = dk_pool_map[map_off];
	  if (!flag && !map) GPF_T1 ("freeing mmap mark where no mapping");
	  if (!map)
	    {
	      map = dk_pool_map[map_off] = dk_alloc (sizeof (dk_pool_4g_t));
	      memzero (map, sizeof (dk_pool_4g_t));
	    }
	}
      m = 1 << ((pg >> 12) & 0x7);
      byte = pg >> 15;
	if (flag)
	  {
	    if (map->bits[byte] & m) GPF_T1 ("setting allocd bit for pool page twice");
	    map->bits[byte] |= m;
	  }
	else
	  {
	    if (!(map->bits[byte] & m)) GPF_T1 ("resetting a pool allocd bit which is not set");
	    map->bits[byte] &= ~m;
	  }
	off2 += 4096;
    }
  mutex_leave (&mp_mmap_mark_mtx);
}


void
mp_check_not_in_pool (int64 __ptr)
{
  dk_pool_4g_t * map;
  if (!dk_pool_map_inited)
    return;
  mutex_enter (&mp_mmap_mark_mtx);
  map = dk_pool_map[__ptr >> 32];
  if (map && map->bits[((uint32)__ptr) >> 15] & (1 << (((((uint32)__ptr) >> 12) & 0x7))))
    GPF_T1 ("Freeing address in mem pool, do not confuse these with mallocd");
    mutex_leave (&mp_mmap_mark_mtx);
}


void
mp_by_address (uint64 ptr)
{
  int inx;  DO_HT (mem_pool_t *, mp, ptrlong, ign, mp_registered)
    {
      DO_HT (ptrlong, start, size_t, sz, &mp->mp_large)
	{
	  if (ptr >= start && ptr < start + sz)
	    {
	      printf ("Address %p is %ld bytes inside map starting at %p of size %ld\n", (void*)ptr, ptr - start, (void*)start, sz);
	    }
	}
      END_DO_HT;
    }
  END_DO_HT;
  for (inx = mm_n_large_sizes - 1; inx >= 0; inx--)
    {
      resource_t * rc = mm_rc[inx];
      int fill = rc->rc_fill, inx2;
      for (inx2 = 0; inx2 < fill; inx2++)
	{
	  int64 start = rc->rc_items[inx2];
	  if (ptr >= start && ptr < start + mm_sizes[inx])
	    {
	      printf ("Address %x is %ld bytes indes arc cached block start %p size %ld\n", (void*)ptr, ptr - start, (void*)start, mm_sizes[inx]);
	      return;
	    }
	}
    }
}

int
mp_list_marks (int first, int n_print)
{
  unsigned int inx, inx2, bit;
  int n_printed = 0, ctr = 0;
  int64 first_addr = 0;
  for (inx = 0; inx < sizeof (dk_pool_map) / sizeof (caddr_t); inx++)

    {
      dk_pool_4g_t * map = dk_pool_map[inx];
      if (map)
	{
	  for (inx2 = 0; inx2 <sizeof (dk_pool_4g_t); inx2++)
	    {
	      unsigned char byte = map->bits[inx2];
	      if (!byte)
		continue;
	      for (bit = 0; bit < 8; bit++)
		{
		  if (byte & (1 << bit))
		    {
		      if (!first_addr)
			first_addr = ((long)inx << 32) + (inx << 15) + (bit << 12);
		      ctr++;
		    }
		  else
		    {
		      if (first_addr)
			{
			  if (n_printed >= first && n_printed < n_print + first)
			    {
			      int64 last_addr = ((long)inx << 32) + ((long)inx << 15) + (bit << 12);
			      printf ("0x%p - 0x%p - %ld pages\n", (last_addr - first_addr) >> 12);
			    }
			  n_printed++;
			  first_addr = 0;
			}
		    }
		}
	    }
	}
    }
  return ctr;
}


void
mp_mark_check ()
{
}


#else
#define mp_mmap_mark(ptr, sz, f)
#endif

void mm_cache_clear ();


void *
mp_mmap (size_t sz)
{
#ifdef HAVE_SYS_MMAN_H
  void * ptr;
  int retries = 0;
  if (sz < mp_mmap_min)
    return malloc (sz);
  for (;;)
    {
  ptr = mmap (NULL, sz, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (MAP_FAILED == ptr || !ptr)
    {
      log_error ("mmap failed with %d", errno);
	  mm_cache_clear ();
	  retries++;
	  if (retries > 3)
      GPF_T1 ("could not allocate memory with mmap");
	  continue;
    }
  mp_mmap_mark (ptr, sz, 1);
  return ptr;
    }
#else
  return malloc (sz);
#endif
}


void
mp_munmap (void* ptr, size_t sz)
{
#ifdef HAVE_SYS_MMAN_H
  if (!ptr) GPF_T1 ("munmap of null");
  if (sz < mp_mmap_min)
    free (ptr);
  else
    {
      int rc;
      /* mark freeing before the free and if free fails remark as allocd.  Else concurrent alloc on different thread can get the just freed thing and it will see the allocd bits set */
      mp_mmap_mark (ptr, sz, 0);
      rc = munmap (ptr, sz);
      if (-1 == rc)
	{
	  mp_mmap_mark (ptr, sz, 1);
	  if (ENOMEM == errno)
	    {
	      int nth = -1;
	      *(long*)ptr = 0; /*verify it is still mapped */
	      mutex_enter (&map_fail_mtx);
	      log_error ("munmap failed with ENOMEM, should increase sysctl v,vm.max_map_count.  May also try lower VectorSize ini setting, e.g. 1000");
	      sethash (ptr, &mm_failed_unmap, (void*)sz);
	      mutex_leave (&map_fail_mtx);
	      mm_cache_clear ();
	      return;
	    }
	  log_error ("munmap failed with %d", errno);
	  GPF_T1 ("munmap failed");
	}
    }
#else
  free (ptr);
#endif
}


#define MM_FREE_BATCH 100

size_t
mm_free_n  (int nth, size_t target_bytes, int age_limit, uint32 now)
{
  size_t total_freed = 0;
  int inx, fill;
  resource_t * rc = mm_rc[nth];
  void * to_free[MM_FREE_BATCH];
  do
    {
      int inx2;
      fill = 0;
      mutex_enter (rc->rc_mtx);
      for (inx2 = 0; inx2 < rc->rc_fill; inx2++)
	{
	  if (now - rc->rc_item_time[inx2] >= age_limit)
	    {
	      to_free[fill] = rc->rc_items[rc->rc_fill - fill - 1];
	      fill++;
	      if (fill >= MM_FREE_BATCH)
		break;
	      total_freed += mm_sizes[nth];
	      if (total_freed >= target_bytes)
		break;
	    }
	}
      rc->rc_fill -= fill;
      memmove_16 (rc->rc_item_time, &rc->rc_item_time[fill], rc->rc_fill * sizeof (uint32));
      mutex_leave (rc->rc_mtx);
      /* free from the recently returned but shift the times down so that the older blocks get a younger */
      for (inx = 0; inx < fill; inx++)
	mp_munmap (to_free[inx], mm_sizes[nth]);
    } while (MM_FREE_BATCH == fill);
  return total_freed;
}



size_t
mm_cache_trim (size_t target_sz, int age_limit, int old_only)
{
  int inx;
  float old_ratio;
  uint32 now = approx_msec_real_time ();
  size_t bytes = 0, old_total = 0, total_freed = 0;
  size_t old_bytes[N_LARGE_SIZES];
  size_t to_free;
  memzero (&old_bytes, sizeof (old_bytes));
  for (inx = mm_n_large_sizes - 1; inx >= 0; inx--)
    {
      resource_t * rc = mm_rc[inx];
      int fill = rc->rc_fill;
      bytes += mm_sizes[inx] * fill;
    }
  if (bytes <= target_sz)
    return 0;
  for (inx = 0; inx < mm_n_large_sizes; inx++)
    {
      int inx2;
      resource_t * rc = mm_rc[inx];
      int fill = rc->rc_fill;
      uint32 * times = rc->rc_item_time;
      for (inx2 = 0; inx2 < fill; inx2++)
	{
	  if (now - times[inx] >= age_limit)
	    {
	      old_bytes[inx] += mm_sizes[inx];
	      old_total += mm_sizes[inx];
	    }
	}
    }
  if (bytes < target_sz)
    return 0;
  to_free = bytes - target_sz;
  old_ratio = to_free >= old_total ? 1.0 : (float) to_free / (float)old_total;
  for (inx = 0; inx < mm_n_large_sizes; inx++)
    {
      total_freed += mm_free_n (inx, old_bytes[inx] * old_ratio, age_limit, now);
    }
  if (total_freed >= to_free || old_only)
    return total_freed;
  to_free -= total_freed;
  bytes -= total_freed;
  old_ratio = (float)to_free / (float)bytes;
  for (inx = 0; inx < mm_n_large_sizes; inx++)
    {
      total_freed += mm_free_n (inx, old_bytes[inx] * old_ratio, 0, now);
    }
  return total_freed;
}



void*
mm_large_alloc (size_t sz)
{
  int nth;
  size_t sz2 = mm_next_size (sz, &nth);
  void * ptr;
  if (-1 == nth)
    {
      mm_uses[mm_n_large_sizes]++;
      return mp_mmap (sz2);
    }
  ptr = resource_get (mm_rc[nth]);
  if (!ptr)
    ptr = mp_mmap (sz2);
  mm_uses[nth]++;
  return ptr;
}


void
mp_warn (mem_pool_t * mp)
{
}


void *
mp_large_alloc (mem_pool_t * mp, size_t sz)
{
  void * ptr;
  if (mp->mp_large_reuse)
    {
      int nth = -1;
      mm_next_size (sz, &nth);
      if (-1 != nth && nth < mm_n_large_sizes && mp->mp_large_reuse[nth])
	{
	  ptr = resource_get (mp->mp_large_reuse[nth]);
	  if (ptr)
	    return ptr;
	}
    }
  mp->mp_bytes += sz;
  if (mp->mp_max_bytes && mp->mp_bytes > mp->mp_max_bytes)
    mp_warn (mp);
  mutex_enter (&mp_large_g_mtx);
  mp_large_in_use += sz;
  if (mp_large_in_use > mp_max_large_in_use)
    {
      mp_max_large_in_use = mp_large_in_use;
      if (mp_large_in_use > mp_large_warn_threshold)
	mp_warn (mp);
    }
  mutex_leave (&mp_large_g_mtx);
  ptr = mm_large_alloc (sz);
  sethash (ptr, &mp->mp_large, (void*)sz);
  return ptr;
}

void
mm_free_sized (void* ptr, size_t sz)
{
  int nth;
  size_t sz2 = mm_next_size (sz, &nth);
  if (-1 == nth || !resource_store_timed (mm_rc[nth], ptr))
    mp_munmap (ptr, sz2);
}


void
mp_free_large (mem_pool_t * mp, void * ptr)
{
  size_t sz = (size_t)gethash (ptr, &mp->mp_large);
  GPF_T1 ("mp_free_large not in use");
  if (!sz)
    {
      ptr = (void*) (((char*)ptr) - 8);
      sz = (size_t)gethash (ptr, &mp->mp_large);
      if (!sz)
	GPF_T1 ("mp free large of non allocated");
    }
  remhash (ptr, &mp->mp_large);
  mutex_enter (&mp_large_g_mtx);
  mp_large_in_use -= sz;
  mutex_leave (&mp_large_g_mtx);
  mp->mp_bytes -= sz;
  mm_free_sized (ptr, sz);
}

void
mp_free_all_large (mem_pool_t * mp)
{
  size_t total = 0;
  DO_HT (void*, ptr, size_t, sz, &mp->mp_large)
    {
      total += sz;
      mm_free_sized (ptr, sz);
    }
  END_DO_HT;
  mutex_enter (&mp_large_g_mtx);
  mp_large_in_use -= total;
  mutex_leave (&mp_large_g_mtx);
  if (mp->mp_reserved)
    {
      mutex_enter (&mp_reserve_mtx);
      mp_large_reserved -= mp->mp_reserved;
      mutex_leave (&mp_reserve_mtx);
    }
  hash_table_destroy (&mp->mp_large);
}

void
mp_large_report ()
{
  uint32 now = approx_msec_real_time ();
  int inx;
  int64 bytes = 0;
  for (inx = 0; inx < mm_n_large_sizes; inx++)
    {
      int inx2, max_age = 0, min_age = INT32_MAX, age_sum = 0;
      resource_t * rc = mm_rc[inx];
      int fill = rc->rc_fill;
      for (inx2 = 0; inx2 < fill; inx2++)
	{
	  int age = now - rc->rc_item_time[inx2];
	  if (age > max_age)
	    max_age = age;
	  if (age < min_age)
	    min_age = age;
	  age_sum += age;
	}
      printf ("size %d fill %d max %d  gets %d stores %d full %d empty %d ages %d/%d/%d\n", mm_sizes[inx], rc->rc_fill, rc->rc_size, rc->rc_gets, rc->rc_stores, rc->rc_n_full, rc->rc_n_empty,
	      fill ? min_age : 0, fill ? age_sum / fill : 0, max_age);
      bytes += mm_sizes[inx] * rc->rc_fill;
    }
  printf ("total %Ld in reserve\n", bytes);
}


int
mp_reuse_large (mem_pool_t * mp, void * ptr)
{
  int nth = -1;
  size_t sz = (size_t)gethash (ptr, &mp->mp_large);
  if (!sz)
    return 0;
  mm_next_size (sz, &nth);
  if (-1 == nth || nth >= mm_n_large_sizes)
    return 0;
  if (!mp->mp_large_reuse)
    mp->mp_large_reuse = (resource_t **)dk_alloc_box_zero (sizeof (caddr_t) * mm_n_large_sizes, DV_CUSTOM);
  if (!mp->mp_large_reuse[nth])
    mp->mp_large_reuse[nth] = resource_allocate_primitive (mp_local_rc_sz, 0);
  if (!resource_store (mp->mp_large_reuse[nth], ptr))
    {
      remhash (ptr, &mp->mp_large);
      mp->mp_bytes -= sz;
      mutex_enter (&mp_large_g_mtx);
      mp_large_in_use -= sz;
      mutex_leave (&mp_large_g_mtx);
      mm_free_sized (ptr, sz);
    }
  return 1;
}


int 
mp_reserve (mem_pool_t * mp, size_t inc)
{
  int ret = 0;
  mutex_enter (&mp_reserve_mtx);
  if (mp_large_reserved + inc < mp_large_reserve_limit)
    {
      mp_large_reserved += inc;
      mp->mp_reserved += inc;
      if (mp_max_large_reserved < mp_large_reserved)
	mp_max_large_reserved = mp_large_reserved;
      ret = 1;
    }
  mutex_leave (&mp_reserve_mtx);
  return ret;
}


void
mp_comment (mem_pool_t * mp, char * str1, char * str2)
{
#ifndef NDEBUG
  int len1 = (str1 ? strlen (str1) : 0);
  int len2 = (str2 ? strlen (str2) : 0);
  caddr_t c = mp_alloc_box (mp, len1 + len2 + 1, DV_NON_BOX);
  int fill = 0;
  if (str1)
    {
      memcpy (c, str1, len1);
      fill = len1;
    }
  if (str2)
    {
      memcpy (c + fill, str2, len2);
    }
  c[len1 + len2] = 0;
  mp->mp_comment = c;
#endif
}


typedef struct ptr_and_sz_s
{
  uptrlong	ps_ptr;
  uint32	ps_n_pages;
} ptr_and_size_t;


int
ps_compare (const void *s1, const void *s2)
{
  uptrlong p1 = ((ptr_and_size_t*)s1)->ps_ptr;
  uptrlong p2 = ((ptr_and_size_t*)s2)->ps_ptr;
  return p1 < p2 ? -1 : p1 == p2 ? 0 : 1;
}

int
munmap_ck (void* ptr, size_t sz)
{
  int rc;
  /* mark freeing before the free and if free fails remark as allocd.  Else concurrent alloc on different thread can get the just freed thing and it will see the allocd bits set */
  mp_mmap_mark  (ptr, sz, 0);
  rc = munmap (ptr, sz);
  if (0 != rc)
    mp_mmap_mark  (ptr, sz, 1);

  if (0 == rc || (-1 == rc && ENOMEM == errno))
    return rc;
  log_error ("munmap failed with errno %d ptr %p sz %ld", errno, ptr, sz);
  GPF_T1 ("munmap failed with other than ENOMEM");
  return -1;
}


int
mm_unmap_asc (ptr_and_size_t * maps, int low, int high)
{
  int inx;
  int rc = munmap_ck ((void*)maps[low].ps_ptr, maps[low].ps_n_pages * mm_page_sz);
  if (-1 == rc)
    return 0;
  maps[low].ps_ptr = 0;
  for (inx = low + 1; inx < high; inx++)
    {
      if (0 == munmap_ck ((void*)maps[inx].ps_ptr, maps[inx].ps_n_pages * mm_page_sz))
	maps[inx].ps_ptr = 0;
    }
  return 1;
}

int
mm_unmap_desc (ptr_and_size_t * maps, int low, int high)
{
  int inx;
  int rc = munmap_ck ((void*)maps[high - 1].ps_ptr, maps[high - 1].ps_n_pages * mm_page_sz);
  if (-1 == rc)
    return 0;
  maps[high - 1].ps_ptr = 0;
  for (inx = high - 2; inx >=  low; inx--)
    {
      if (0 == munmap_ck ((void*)maps[inx].ps_ptr, maps[inx].ps_n_pages * mm_page_sz))
	maps[inx].ps_ptr = 0;
    }
  return 1;
}

void
mm_unmap_contiguous (ptr_and_size_t * maps, int n_maps)
{
  int inx;
  for (inx = 0; inx < n_maps; inx++)
    {
      int inx2;
      uptrlong pt = maps[inx].ps_ptr + mm_page_sz * maps[inx].ps_n_pages;;
      for (inx2 = inx + 1; inx2 < n_maps; inx2++)
	{
	  if (maps[inx2].ps_ptr != pt)
	    break;
	  pt += maps[inx].ps_n_pages * mm_page_sz;
    }
      if (!mm_unmap_asc (maps, inx, inx2) && inx2 - inx > 1)
	mm_unmap_desc (maps, inx, inx2);
      inx = inx2 - 1;
    }
  for (inx = 0; inx < n_maps; inx++)
    {
      int nth = -1;
      if (maps[inx].ps_ptr)
	{
	  void * ptr = (void*)maps[inx].ps_ptr;
	  size_t sz = maps[inx].ps_n_pages * mm_page_sz;
	  mm_next_size (sz, &nth);
	  if (!(-1 != nth &&  nth < mm_n_large_sizes
		&& resource_store_timed (mm_rc[nth], (void*)ptr)))
	    sethash (ptr, &mm_failed_unmap, (void*)sz);
	}
    }
}

void
mm_cache_clear ()
{
  int inx;
  ptr_and_size_t * maps;
  int n_maps;
  int max_maps, map_fill = 0;
  mutex_enter (&map_fail_mtx);
  n_maps = mm_failed_unmap.ht_count;
  for (inx = mm_n_large_sizes - 1; inx >= 0; inx--)
    {
      resource_t * rc = mm_rc[inx];
      n_maps += rc->rc_fill;
    }
  max_maps = n_maps + 1000;
  maps = (ptr_and_size_t*)dk_alloc (sizeof (ptr_and_size_t) * max_maps);
  DO_HT (uptrlong, ptr, size_t, sz, &mm_failed_unmap)
    {
      maps[map_fill].ps_ptr = ptr;
      maps[map_fill].ps_n_pages = sz / mm_page_sz;
      map_fill++;
    }
  END_DO_HT;
  clrhash (&mm_failed_unmap);
  for (inx = 0; inx < mm_n_large_sizes; inx++)
    {
      int rc_sz = mm_sizes[inx] / mm_page_sz;
      int inx2;
      resource_t * rc = mm_rc[inx];
      int fill;
      mutex_enter (rc->rc_mtx);
      fill = rc->rc_fill;
      for (inx2 = 0; inx2 < fill; inx2++)
	{
	  maps[map_fill].ps_ptr = (uptrlong)rc->rc_items[inx2];
	  maps[map_fill].ps_n_pages = rc_sz;
	  map_fill++;
	  if (map_fill == max_maps)
	    {
	      memmove (rc->rc_items, &rc->rc_items[inx2 + 1], sizeof (void*) * (fill - inx2));
	      rc->rc_fill -= (inx2 + 1);
	      mutex_leave (rc->rc_mtx);
	      goto all_filled;
	    }
	}
      rc->rc_fill = 0;
      mutex_leave (rc->rc_mtx);
    }
 all_filled:
  qsort (maps, map_fill, sizeof (ptr_and_size_t), ps_compare);
  mm_unmap_contiguous (maps, map_fill);
  dk_free ((caddr_t)maps, -1);
  mutex_leave (&map_fail_mtx);
}

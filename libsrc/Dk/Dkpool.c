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

#define DBG_MP_ALLOC_BOX(mp,len,tag) DBG_NAME(mp_alloc_box) (DBG_ARGS (mp), (len), (tag))
#define DBG_T_ALLOC_BOX(len,tag) DBG_NAME(t_alloc_box) (DBG_ARGS (len), (tag))

void
mp_uname_free (const void *k, void *data)
{
#ifdef DEBUG
  caddr_t box = k;
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
#if defined (DEBUG) || defined (MALLOC_DEBUG)
  mp->mp_alloc_file = (char *) file;
  mp->mp_alloc_line = line;
#endif
  return mp;
}


void
mp_free (mem_pool_t * mp)
{
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
  DO_SET (caddr_t, box, &mp->mp_trash)
  {
    dk_free_tree (box);
  }
  END_DO_SET ();
  dk_set_free (mp->mp_trash);
  dk_free ((caddr_t) mp->mp_allocs, mp->mp_size * sizeof (caddr_t));
  dk_free ((caddr_t) mp, sizeof (mem_pool_t));
}


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
  mp->mp_block_size = ALIGN_8 ((4096 * 8));
  mp->mp_unames = DBG_NAME (hash_table_allocate) (DBG_ARGS 11);
#if defined (DEBUG) || defined (MALLOC_DEBUG)
  mp->mp_alloc_file = (char *) file;
  mp->mp_alloc_line = line;
#endif
  return mp;
}


void
mp_free (mem_pool_t * mp)
{
  mem_block_t *mb = mp->mp_first, *next;
  while (mb)
    {
      next = mb->mb_next;
      dk_free ((caddr_t) mb, mb->mb_size);
      mb = next;
    }
  maphash (mp_uname_free, mp->mp_unames);
  hash_table_free (mp->mp_unames);
  DO_SET (caddr_t, box, &mp->mp_trash)
  {
    dk_free_tree (box);
  }
  END_DO_SET ();
  dk_set_free (mp->mp_trash);

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

caddr_t
DBG_NAME (mp_alloc_box) (DBG_PARAMS mem_pool_t * mp, size_t len1, dtp_t dtp)
{
  dtp_t *ptr;
#ifdef LACERATED_POOL
#ifdef DOUBLE_ALIGN
  size_t len = ALIGN_8 (len1 + 8);
#else
  size_t len = ALIGN_4 (len1 + 4);
#endif
  caddr_t new_alloc = DBG_NAME (mallocp) (DBG_ARGS len, mp);
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
  int bh_len = (dtp != DV_NON_BOX ? 8 : 0);
  size_t len = ALIGN_8 (len1 + bh_len);
  mem_block_t *mb = NULL;
  mem_block_t *f = mp->mp_first;
  size_t hlen = ALIGN_8 ((sizeof (mem_block_t)));	/* we can have a doubles so structure also must be aligned */
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
	  mb = (mem_block_t *) dk_alloc (mp->mp_block_size);
	  mb->mb_size = mp->mp_block_size;
	  mb->mb_fill = hlen;
	  mb->mb_next = mp->mp_first;
	  mp->mp_first = mb;
	  mp->mp_bytes += mb->mb_size;
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
      WRITE_BOX_HEADER (ptr, len1, dtp);
#ifndef LACERATED_POOL
    }
#endif
  memset (ptr, 0, len1);
  return ((caddr_t) ptr);
}

caddr_t
mp_alloc_sized (mem_pool_t * mp, size_t len1)
{
#ifdef LACERATED_POOL
  return mp_alloc_box (mp, len1, DV_NON_BOX);
#else
  dtp_t *ptr;
  size_t len = ALIGN_8 (len1);
  mem_block_t *mb = NULL;
  mem_block_t *f = mp->mp_first;
  size_t hlen = ALIGN_8 ((sizeof (mem_block_t)));	/* we can have a doubles so structure also must be aligned */
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
	  mb = (mem_block_t *) dk_alloc (mp->mp_block_size);
	  mb->mb_size = mp->mp_block_size;
	  mb->mb_fill = hlen;
	  mb->mb_next = mp->mp_first;
	  mp->mp_first = mb;
	  mp->mp_bytes += mb->mb_size;
	}
    }
  else
    mb = f;
  ptr = ((dtp_t *) mb) + mb->mb_fill;
  mb->mb_fill += len;
  memset (ptr, 0, len1);
  return ((caddr_t) ptr);
#endif
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
    sethash (box, mp->mp_unames, qchk);
#else
  if (gethash (box, mp->mp_unames))
    dk_free_box (box);				 /* free extra copy */
  else
    sethash (box, mp->mp_unames, (void *) (ptrlong) 1);
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
    sethash (box, mp->mp_unames, qchk);
#else
  if (gethash (box, mp->mp_unames))
    dk_free_box (box);				 /* free extra copy */
  else
    sethash (box, mp->mp_unames, (void *) (ptrlong) 1);
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
	    dk_set_push (&mp->mp_trash, (void*)cp);
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
	  sethash (box_copy (box), mp->mp_unames, qchk);
#else
	  sethash (box_copy (box), mp->mp_unames, (void *) (ptrlong) 1);
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
  s_node_t *s = (s_node_t *) DBG_NAME (mp_alloc_box) (DBG_ARGS mp, sizeof (s_node_t), DV_NON_BOX);
  s->data = elt;
  s->next = *set;
  *set = s;
}


dk_set_t
DBG_NAME (t_cons) (DBG_PARAMS void *car, dk_set_t cdr)
{
  s_node_t *s = (s_node_t *) t_alloc_box (sizeof (s_node_t), DV_NON_BOX);
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
mp_check_tree_iter (mem_pool_t * mp, box_t box, box_t parent, dk_hash_t **known_ptr)
{
  uint32 count;
  dtp_t tag;
  mp_alloc_box_assert (mp, (caddr_t) box);
  tag = box_tag (box);
  if (IS_NONLEAF_DTP (tag))
    {
      box_t *obj = (box_t *) box;
      for (count = box_length ((caddr_t) box) / sizeof (caddr_t); count; count--)
        {
          if (IS_BOX_POINTER (*obj))
            {
              if (*obj >= parent)
                {
                  if (NULL == known_ptr[0])
                    known_ptr[0] = hash_table_allocate (101);
                  if (gethash (*obj, known_ptr[0]))
                    return;
                  sethash (*obj, known_ptr[0], box);
                }
              else if (NULL != known_ptr[0])
                {
                  if (gethash (*obj, known_ptr[0]))
                    return;
                  sethash (*obj, known_ptr[0], box);
                }
              mp_check_tree_iter (mp, *obj, box, known_ptr);
            }
          obj++;
        }
    }
}


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
      dk_hash_t *known = NULL;
      for (count = box_length ((caddr_t) box) / sizeof (caddr_t); count; count--)
        {
          if (IS_BOX_POINTER (*obj))
            mp_check_tree_iter (mp, *obj, box, &known);
          obj++;
        }
      if (NULL != known)
        hash_table_free (known);
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
  dk_set_push (&mp->mp_trash, (void *) box);
}


caddr_t
mp_alloc_box_ni (mem_pool_t * mp, int len, dtp_t dtp)
{
#ifdef MALLOC_DEBUG
  return mp_alloc_box (mp, len, dtp);
#else
  caddr_t box;
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
#endif
